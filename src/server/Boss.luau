-- Boss fights (the owner's boss brief, 26 Oct: claude.ai project doc `claude/boss-revamp-brief.md`).
-- Mow an area bare and its boss wakes in its arena (server/BossArena): the summon pad lights up, and standing on it
-- starts the fight. The server runs the whole fight; clients only draw it (client/BossView, BossVfx, BossCine,
-- BossHud), timed by workspace:GetServerTimeNow() stamps:
--   intro   7-8 s cinematic the first time on a server, 2.5 s after (everyone voting skips it); the gate stays
--           open for BossMoves.JOIN_WINDOW s after the summon, then closes until the fight ends
--   fight   moves from shared/BossMoves, each with a ground warning; slams, sweeps and leaps leave the boss open
--           for a punish window (weak spot glows, x2.5 damage). Hand tools hurt it; mowers park outside.
--   rage    at 50% HP: ~5 s cutscene (it can't be hurt), roar shockwave, rage form, 2 more moves, faster warnings
--   dying   ~3 s cutscene, then the rewards (server/Run) and the gate opens
--   wipe    every fighter down or gone: the boss heals and goes back to sleep; try again from the pad
-- Round 2 (owner, 26 Oct): projectiles (lob), lingering hazards, minion adds (they pop to a hand-tool hit or
-- two), a difficulty curve per area (BossMoves.curve), juice boxes on every punish window, pets chip in, the
-- phase-2 cutscene freezes everyone, everyone left in the area is pulled in when the gate closes, and a no-hit
-- bonus (Boss.onDefeated's third argument).
-- The state is mirrored on ReplicatedStorage.MowALawnBoss (attributes) for late joiners and the HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.MowALawn.Config)
local BossMoves = require(ReplicatedStorage.MowALawn.BossMoves)
local BossRig = require(ReplicatedStorage.MowALawn.BossRig)
local Net = require(script.Parent.Net)
local BossArena = require(script.Parent.BossArena)
local BossFighters = require(script.Parent.BossFighters)
local PlayerData = require(script.Parent.PlayerData)

local Boss = {}
Boss.difficulty = Config.DIFFICULTY.Normal -- (29 Oct) set by server/Run from the party's pick

Boss.onDefeated = nil :: ((number, { [Player]: number }, { [Player]: boolean }) -> ())?
Boss.onChanged = nil :: (() -> ())?

type Fight = {
	z: number,
	token: number,
	def: any, -- Config.ZONES[z].boss
	moves: any, -- BossMoves entry
	arena: any,
	rig: string,
	scale: number,
	bodyR: number,
	cf: CFrame, -- where it stands (on the floor) and faces
	home: CFrame,
	hp: number,
	maxHp: number,
	phase: number,
	state: string, -- intro | fight | rage | dying
	alive: boolean,
	openUntil: number, -- os.clock(): punish window
	damageBy: { [Player]: number },
	votes: { [Player]: boolean },
	skipped: boolean,
	lastMove: string?,
	curve: any, -- BossMoves.curve(z)
	hazards: { any },
	adds: { Add },
	movers: { any }, -- moving things (shared/BossMoves moverShapes)
	pillars: { { pos: Vector3, r: number, part: BasePart, untilT: number } },
	hidden: boolean, -- dug in (Shell Ambush): can't be hit
}

type Add = { part: BasePart, hp: number, biteAt: number, born: number, speed: number, ai: string, life: number, blast: number, every: number, nextShot: number, armed: boolean }

local current: Fight? = nil
local token = 0
local ready: { [number]: boolean } = {} -- area cleared, pad lit
local beaten: { [number]: boolean } = {}
local seenIntro: { [number]: boolean } = {}
local rng = Random.new()

local mirror = Instance.new("Configuration")
mirror.Name = "MowALawnBoss"
mirror.Parent = ReplicatedStorage

local function now(): number
	return workspace:GetServerTimeNow()
end

local function changed()
	if Boss.onChanged then
		Boss.onChanged()
	end
end

local function publish(f: Fight?)
	if not f then
		mirror:SetAttribute("Active", false)
		mirror:SetAttribute("State", nil)
		return
	end
	mirror:SetAttribute("Active", true)
	mirror:SetAttribute("Z", f.z)
	mirror:SetAttribute("Rig", f.rig)
	mirror:SetAttribute("Name", f.def.name)
	mirror:SetAttribute("Title", f.moves.title)
	mirror:SetAttribute("State", f.state)
	mirror:SetAttribute("Phase", f.phase)
	mirror:SetAttribute("Hp", math.ceil(f.hp))
	mirror:SetAttribute("MaxHp", math.ceil(f.maxHp))
	mirror:SetAttribute("Cf", f.cf)
	mirror:SetAttribute("Home", f.home)
	mirror:SetAttribute("Scale", f.scale)
end

-------------------------------------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(p: Player): BasePart?
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- standing fighters on the arena floor
local function targets(f: Fight): { Player }
	local out = {}
	for _, p in BossFighters.list() do
		local root = rootOf(p)
		if root and BossFighters.standing(p) and BossArena.inside(f.z, root.Position, 2) then
			table.insert(out, p)
		end
	end
	return out
end

local function alive(f: Fight): boolean
	return current == f and f.alive and f.token == token
end

-- still fighting (not ended, not in its death cutscene)
local function live(f: Fight): boolean
	return alive(f) and f.state ~= "dying"
end

-- wait `t` seconds of fight time; false if the fight ended meanwhile
local function hold(f: Fight, t: number): boolean
	local untilT = os.clock() + t
	while os.clock() < untilT do
		task.wait(math.min(0.1, untilT - os.clock()))
		if not live(f) then
			return false
		end
	end
	return live(f)
end

local function face(f: Fight, pos: Vector3)
	local p = f.cf.Position
	local d = flat(pos - p)
	if d.Magnitude > 1 then
		f.cf = CFrame.lookAt(p, p + d.Unit)
		mirror:SetAttribute("Cf", f.cf)
	end
end

-- clamp a point onto the arena floor, `keep` studs inside the wall
local function onFloor(f: Fight, pos: Vector3, keep: number): Vector3
	local c = f.arena.centre
	local d = flat(pos - c)
	local maxD = f.arena.radius - keep
	if d.Magnitude > maxD then
		d = d.Unit * maxD
	end
	return Vector3.new(c.X + d.X, c.Y, c.Z + d.Z)
end

-------------------------------------------------------------------------------------------------------------
-- hits on players: every move draws shapes on the floor; at their land time the server checks who stands in them
-- (the geometry is shared with the client: BossMoves.inShape)
-------------------------------------------------------------------------------------------------------------
type Shape = { type: string, pos: Vector3, land: number, [string]: any }

local function R(f: Fight): number
	return f.arena.radius
end

local function C(f: Fight): Vector3
	return f.arena.centre
end

local function dirTo(f: Fight, pos: Vector3): Vector3
	local d = flat(pos - f.cf.Position)
	return if d.Magnitude > 0.5 then d.Unit else f.cf.LookVector
end

-- turn a flat direction by `a` radians (same sense as BossMoves' beams: dir = (sin a, 0, cos a))
local function rot(v: Vector3, a: number): Vector3
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c + v.Z * s, 0, v.Z * c - v.X * s)
end

local function angleOf(v: Vector3): number
	return math.atan2(v.X, v.Z)
end

-- where the line through `p` along `dir` crosses the arena wall (`keep` studs inside it): back end, front end
local function chord(f: Fight, p: Vector3, dir: Vector3, keep: number): (Vector3?, Vector3?)
	local c = C(f)
	local r = R(f) - keep
	local o = flat(p - c)
	local b = o:Dot(dir)
	local disc = b * b - (o:Dot(o) - r * r)
	if disc <= 0 then
		return nil, nil
	end
	local sq = math.sqrt(disc)
	local base = Vector3.new(p.X, c.Y, p.Z)
	return base + dir * (-b - sq), base + dir * (-b + sq)
end

local function strike(f: Fight, s: Shape, kind: string)
	local dmg = math.floor((BossMoves.DAMAGE[kind] or 25) * f.curve.damage + 0.5)
	for _, p in BossFighters.list() do
		local root = rootOf(p)
		local y = if root then root.Position.Y - f.arena.centre.Y else 0
		if root and math.abs(y) < 14 and not ((s :: any).jump and y > BossMoves.JUMP_CLEAR) and BossMoves.inShape(s, root.Position) then
			BossFighters.hit(p, dmg, s.pos)
		end
	end
end

-- a patch of floor that keeps hurting for `life` s (hazards, slime / ember pools, fire trails); `sink`: sand that
-- only hurts (and throws you out) once you've stood in it too long
local function addHazard(f: Fight, pos: Vector3, r: number, life: number, sink: boolean?)
	table.insert(f.hazards, {
		pos = pos,
		r = r,
		untilT = os.clock() + life,
		dmg = math.max(1, math.floor((if sink then BossMoves.DAMAGE.sink else BossMoves.DAMAGE.hazard) * f.curve.damage + 0.5)),
		sink = sink,
		inside = {},
	})
end

-- send the warning, then land every shape at its time (shapes that land later land one after another)
local function play(f: Fight, move: any, shapes: { Shape }, extra: { [string]: any }?): boolean
	local t0 = now()
	local msg = { kind = move.kind, name = move.name, at = t0, shapes = shapes, phase = f.phase, cf = f.cf, pose = move.pose, punish = move.punish }
	for k, v in extra or {} do
		msg[k] = v
	end
	Net.all("Fx", "bossMove", msg)
	table.sort(shapes, function(a, b)
		return a.land < b.land
	end)
	for _, s in shapes do
		local left = s.land - (now() - t0)
		if left > 0 and not hold(f, left) then
			return false
		end
		if not live(f) then
			return false
		end
		if f.state ~= "fight" then
			return false -- a minion's spit / blast still in the air when the rage cutscene starts
		end
		strike(f, s, move.kind)
		if move.pool or move.life then
			addHazard(f, s.pos, (s.r :: number) * 0.9, move.pool or move.life, move.kind == "sink")
		end
	end
	return true
end

-- moving things (BossMoves.moverShapes): registered here, checked every 0.05 s by moverStep
local function runMovers(f: Fight, move: any, list: { any }, extra: { [string]: any }?, waitAll: boolean?): boolean
	local t0 = now()
	local last, first = 0, math.huge
	for _, m in list do
		m.t0 = t0 + (m.delay or 0)
		m.delay = nil
		local dur = BossMoves.moverDur(m)
		last = math.max(last, m.t0 - t0 + dur)
		first = math.min(first, m.t0 - t0)
		table.insert(f.movers, { m = m, dur = dur, hit = {}, kind = move.kind })
	end
	local msg = { kind = move.kind, name = move.name, at = t0, shapes = {}, movers = list, phase = f.phase, cf = f.cf, pose = move.pose, punish = move.punish }
	for k, v in extra or {} do
		msg[k] = v
	end
	Net.all("Fx", "bossMove", msg)
	return hold(f, if waitAll then last else math.min(last, first + 1.2))
end

local function punish(f: Fight)
	local len = f.curve.punish
	f.openUntil = os.clock() + len
	mirror:SetAttribute("OpenUntil", now() + len)
	Net.all("Fx", "bossOpen", { at = now(), len = len })
	-- a juice box falls out each time it's stunned open (owner, round 2)
	if Config.BOSS_HEAL.onPunish then
		BossFighters.shedHeals(1)
	end
	hold(f, len)
end

-- an invisible marker part the clients dress (mounds, reaper marks)
local function fxFolder(f: Fight): Instance
	local folder = f.arena.model:FindFirstChild("BossFx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BossFx"
		folder.Parent = f.arena.model
	end
	return folder
end

local function marker(f: Fight, name: string, pos: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.new(pos)
	part:SetAttribute("Zone", f.z)
	part.Parent = fxFolder(f)
	return part
end

-- the Jungle Titan's stone pillars: real walls for `life` s (cover from its gaze)
local function raisePillar(f: Fight, pos: Vector3, r: number, life: number)
	local h = 18
	local top = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local p = Instance.new("Part")
	p.Name = "BossPillar"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(h, r * 2, r * 2)
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = false
	p.Material = Enum.Material.Slate
	p.Color = Color3.fromRGB(122, 130, 108)
	p.CFrame = top - Vector3.new(0, h + 0.5, 0)
	local band = Instance.new("Part")
	band.Name = "Rune"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(1.2, r * 2 + 0.3, r * 2 + 0.3)
	band.Anchored = true
	band.CanCollide = false
	band.CanQuery = false
	band.Material = Enum.Material.Neon
	band.Color = Color3.fromRGB(63, 255, 208)
	local bandAt = CFrame.new(h * 0.18, 0, 0)
	band.CFrame = p.CFrame * bandAt
	band.Parent = p
	p.Parent = fxFolder(f)
	local ti = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(p, ti, { CFrame = top }):Play()
	TweenService:Create(band, ti, { CFrame = top * bandAt }):Play()
	table.insert(f.pillars, { pos = pos, r = r, part = p, untilT = os.clock() + life })
	task.delay(life, function()
		if p.Parent then
			local down = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(p, down, { CFrame = top - Vector3.new(0, h + 0.5, 0) }):Play()
			TweenService:Create(band, down, { CFrame = (top - Vector3.new(0, h + 0.5, 0)) * bandAt }):Play()
			Debris:AddItem(p, 0.7)
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the moves: every boss has its own five (shared/BossMoves). Each returns true if it ran to the end; then the
-- fight loop opens the boss up if the move has `punish`.
-------------------------------------------------------------------------------------------------------------
local MOVES: { [string]: (Fight, any, Player, number) -> boolean } = {}

-- circles round the players, one after another (lob, hazard, sink, mines)
local function scatter(f: Fight, move: any, tele: number, extra: number): { Shape }
	local list = targets(f)
	local shapes = {}
	for i = 1, move.count do
		local p = list[(i - 1) % math.max(1, #list) + 1]
		local root = p and rootOf(p)
		local base = if root then root.Position else f.arena.centre
		local off = if i <= #list then Vector3.zero else Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
		if root and i > #list then
			off += flat(root.AssemblyLinearVelocity) * 0.35
		end
		table.insert(shapes, { type = "circle", pos = onFloor(f, base + off, 5), r = move.radius, land = tele + extra + (i - 1) * (move.every or 0.2) } :: Shape)
	end
	return shapes
end

local function pick(list: { Player }, i: number): BasePart?
	local p = list[(i - 1) % math.max(1, #list) + 1]
	return p and rootOf(p)
end

-- Dandelion King ---------------------------------------------------------------------------------------------
MOVES.slam = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	return play(f, move, { { type = "circle", pos = onFloor(f, root.Position, 4), r = move.radius, land = tele } :: Shape })
end

-- seed puffs float across the arena in lanes; stand in a gap (the 2nd wave's lanes sit in the 1st wave's gaps)
MOVES.drift = function(f, move, _target, tele)
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.sin(a), 0, math.cos(a))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local list = {}
	for w = 0, move.waves - 1 do
		local off0 = (w % 2) * move.gap / 2 + rng:NextNumber(-2, 2)
		for k = -7, 7 do
			local off = off0 + k * move.gap
			if math.abs(off) < R(f) - 4 then
				local s, e = chord(f, C(f) + side * off, dir, 1)
				if s and e then
					table.insert(list, { type = "line", pts = { s, e }, speed = move.speed, r = move.r, look = move.look, delay = tele + w * 1.8 })
				end
			end
		end
	end
	return runMovers(f, move, list)
end

-- a + of strips through the boss (sometimes an x)
MOVES.cross = function(f, move, target, tele)
	local root = rootOf(target)
	if root then
		face(f, root.Position)
	end
	local base = f.cf.LookVector
	local off = if rng:NextNumber() < 0.5 then 0 else math.pi / 4
	local shapes = {}
	for k = 0, 3 do
		-- (owner, 29 Oct: "you cant jump over the line attack that the first boss lights up") a well-timed jump clears it
		table.insert(shapes, { type = "strip", pos = f.cf.Position, dir = rot(flat(base).Unit, off + k * math.pi / 2), length = R(f) * 2, width = move.width, land = tele + 0.2, jump = true } :: Shape)
	end
	return play(f, move, shapes)
end

-- a pollen beam turns round the boss: walk round ahead of it
MOVES.beam = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	local sign = if rng:NextNumber() < 0.5 then 1 else -1
	local a = angleOf(dirTo(f, root.Position)) - sign * 0.5
	-- (29 Oct) the beam runs low along the floor: jump it as it sweeps past (jump = true, like the sand waves)
	local m = { type = "beam", o = f.cf.Position, a0 = a, w = sign * move.speed, len = R(f) * 2, width = move.width, dur = move.turn / move.speed, look = move.look, rehit = 0.9, delay = tele, jump = true }
	return runMovers(f, move, { m }, nil, true)
end

-- Hive Keeper -------------------------------------------------------------------------------------------------
-- rows of thorn hedge burst up across the arena, one after another going outwards, each with one gap
MOVES.hedges = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	local dir = dirTo(f, root.Position)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local shapes = {}
	for k = 0, move.rows - 1 do
		local a, b = chord(f, f.cf.Position + dir * (f.bodyR + 9 + k * 14), side, 2)
		if a and b then
			local len = (b - a).Magnitude
			local land = tele + k * move.step
			if len <= move.gap + 4 then
				continue
			end
			local g0 = rng:NextNumber(len * 0.12, math.max(len * 0.12, len * 0.88 - move.gap))
			if g0 > 1 then
				table.insert(shapes, { type = "strip", pos = a, dir = side, length = g0, width = move.width, land = land } :: Shape)
			end
			local rest = len - g0 - move.gap
			if rest > 1 then
				table.insert(shapes, { type = "strip", pos = a + side * (g0 + move.gap), dir = side, length = rest, width = move.width, land = land } :: Shape)
			end
		end
	end
	return play(f, move, shapes)
end

-- three punches stepping out at you
MOVES.combo = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	local dir = dirTo(f, root.Position)
	local shapes = {}
	for k = 1, move.hits do
		local d = f.bodyR + move.radius * 0.6 + (k - 1) * move.radius * 1.6
		table.insert(shapes, { type = "circle", pos = onFloor(f, f.cf.Position + dir * d, 4), r = move.radius, land = tele + (k - 1) * move.step } :: Shape)
	end
	return play(f, move, shapes)
end

-- floor hazards: land like a barrage, then stay
MOVES.hazard = function(f, move, _target, tele)
	local shapes = scatter(f, move, tele, 0)
	face(f, shapes[1].pos)
	return play(f, move, shapes, { life = move.life, look = move.look })
end

-- pollen fills the arena: only the flowers are safe
MOVES.safe = function(f, move, _target, tele)
	local c = C(f)
	local a0 = rng:NextNumber(0, math.pi * 2)
	local safes = {}
	for k = 1, move.spots do
		local a = a0 + (k - 1) / move.spots * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local d = rng:NextNumber(24, R(f) - move.r - 8)
		local pos = c + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		if flat(pos - f.cf.Position).Magnitude < f.bodyR + move.r + 2 then
			pos = c - Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		end
		table.insert(safes, { pos = pos, r = move.r })
	end
	return play(f, move, { { type = "safe", pos = c, r = R(f), safes = safes, land = tele + move.extra } :: Shape })
end

-- Sand-Trap Shell ---------------------------------------------------------------------------------------------
-- giant golf balls roll out at the players and bounce off the wall once
MOVES.roll = function(f, move, target, tele)
	local root = rootOf(target)
	if root then
		face(f, root.Position)
	end
	local list = targets(f)
	local movers = {}
	for k = 1, move.count do
		local pr = pick(list, k)
		local dir = if pr then dirTo(f, pr.Position) else f.cf.LookVector
		if k > #list then
			dir = rot(dir, rng:NextNumber(-0.7, 0.7))
		end
		local p0 = onFloor(f, f.cf.Position + dir * (f.bodyR + 2), move.r + 2)
		local _, wall = chord(f, p0, dir, move.r + 1)
		local pts = { p0 }
		if wall then
			table.insert(pts, wall)
			local n = flat(C(f) - wall).Unit
			local d2 = dir - 2 * dir:Dot(n) * n
			local _, far = chord(f, wall + d2 * 0.5, d2, move.r + 1)
			if far then
				table.insert(pts, far)
			end
		end
		table.insert(movers, { type = "line", pts = pts, speed = move.speed, r = move.r, look = move.look, ghost = true, delay = tele + (k - 1) * 0.35 })
	end
	return runMovers(f, move, movers)
end

-- sand waves roll out from the boss: jump over them
MOVES.wave = function(f, move, _target, tele)
	local movers = {}
	for k = 0, move.waves - 1 do
		table.insert(movers, { type = "wave", o = f.cf.Position, r0 = f.bodyR * 0.8, speed = move.speed, band = move.band, rmax = R(f) * 2.1, jump = true, delay = tele + k * move.every })
	end
	return runMovers(f, move, movers)
end

-- the rake swipes everything in front
MOVES.cone = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	return play(f, move, { { type = "sector", pos = f.cf.Position, dir = dirTo(f, root.Position), r = f.bodyR * 0.5 + move.r, half = math.rad(move.angle / 2), inner = 0, land = tele + 0.1 } :: Shape })
end

-- sand traps: harmless to walk through, but stand in one too long and it throws you
MOVES.sink = function(f, move, _target, tele)
	local shapes = scatter(f, move, tele, 0)
	face(f, shapes[1].pos)
	return play(f, move, shapes, { life = move.life, look = move.look, sink = true })
end

-- it digs in, a mound chases a player under the floor, and it bursts out where the mound stops
MOVES.burrow = function(f, move, target, _tele)
	Net.all("Fx", "bossMove", { kind = "burrow", name = move.name, at = now(), shapes = {}, phase = f.phase, cf = f.cf, pose = "burrow" })
	if not hold(f, 0.8) then
		return false
	end
	f.hidden = true
	local pos = f.cf.Position
	local mound = marker(f, "BossMound", pos)
	local untilT = os.clock() + move.chase
	while os.clock() < untilT do
		local dt = task.wait(0.05)
		if not live(f) then
			mound:Destroy()
			f.hidden = false
			return false
		end
		local r = rootOf(target)
		if not r or not BossFighters.standing(target) then
			local alt = targets(f)[1]
			if alt then
				target = alt
				r = rootOf(alt)
			end
		end
		if r then
			local d = flat(r.Position - pos)
			if d.Magnitude > 0.3 then
				pos = onFloor(f, pos + d.Unit * math.min(d.Magnitude, 21 * dt), f.bodyR * 0.6 + 3)
			end
			mound.CFrame = CFrame.new(pos)
		end
	end
	mound:Destroy()
	local to = CFrame.lookAt(pos, pos + flat(f.cf.LookVector).Unit)
	f.cf = to
	mirror:SetAttribute("Cf", f.cf)
	local ok = play(f, move, { { type = "circle", pos = pos, r = move.radius, land = 1.0 } :: Shape }, { pose = "erupt", to = to })
	f.hidden = false
	return ok
end

-- Scarecrow ---------------------------------------------------------------------------------------------------
-- three pitchfork tines stab out in a fan
MOVES.fan = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	local dir = dirTo(f, root.Position)
	local shapes = {}
	for k = 1, move.tines do
		local d = rot(dir, math.rad(move.spread) * (k - (move.tines + 1) / 2))
		table.insert(shapes, { type = "strip", pos = f.cf.Position + d * (f.bodyR * 0.4), dir = d, length = move.length, width = move.width, land = tele + 0.1 } :: Shape)
	end
	return play(f, move, shapes)
end

-- crows swoop across the whole arena in straight lines (through where the players stood)
MOVES.dive = function(f, move, _target, tele)
	local list = targets(f)
	local movers = {}
	for k = 1, move.count do
		local pr = if k <= #list * 2 then pick(list, k) else nil
		local through = if pr then pr.Position else C(f) + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local s, e = chord(f, through, dir, -6)
		if s and e then
			table.insert(movers, { type = "line", pts = { s, e }, speed = move.speed, r = move.r, look = move.look, ghost = true, delay = tele + (k - 1) * move.every })
		end
	end
	return runMovers(f, move, movers)
end

-- slow projectiles: the warning circles show at once, the shots leave the boss `flight` s before each lands
MOVES.lob = function(f, move, _target, tele)
	local shapes = scatter(f, move, tele, (move.flight or 1) * 0.5)
	face(f, shapes[1].pos)
	return play(f, move, shapes, { flight = move.flight or 1, ammo = move.ammo, from = move.from, pool = move.pool })
end

-- fires start near the players and spread
MOVES.spread = function(f, move, _target, tele)
	local list = targets(f)
	local movers = {}
	for k = 1, move.count do
		local pr = pick(list, k)
		local base = if pr then pr.Position + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)) else C(f) + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
		table.insert(movers, { type = "grow", pos = onFloor(f, base, 6), r0 = move.r0, r1 = move.r1, grow = move.grow, dur = move.life, look = move.look, tick = true, delay = tele + (k - 1) * 0.4 })
	end
	return runMovers(f, move, movers)
end

-- crop circles: bands round the boss, every other one, then the others
MOVES.rings = function(f, move, _target, tele)
	local shapes = {}
	for k = 0, move.bands * 2 - 1 do
		local inner = f.bodyR + 2 + k * move.band
		table.insert(shapes, { type = "ring", pos = f.cf.Position, inner = inner, outer = inner + move.band, land = tele + (k % 2) * 1.1 } :: Shape)
	end
	return play(f, move, shapes)
end

-- Sakura ------------------------------------------------------------------------------------------------------
MOVES.spiral = function(f, move, _target, tele)
	local a0 = rng:NextNumber(0, math.pi * 2)
	local turn = if rng:NextNumber() < 0.5 then 0.55 else -0.55
	local shapes = {}
	for arm = 0, move.arms - 1 do
		for k = 0, move.count - 1 do
			local a = a0 + arm * 2 * math.pi / move.arms + k * turn
			local d = f.bodyR + 5 + k * 6
			table.insert(shapes, { type = "circle", pos = onFloor(f, f.cf.Position + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d), 3), r = move.r, land = tele + k * move.step } :: Shape)
		end
	end
	return play(f, move, shapes, { ammo = move.ammo, flight = 0.5 })
end

MOVES.sweep = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	local dir = f.cf.LookVector
	local start = f.cf.Position + dir * (f.bodyR * 0.4)
	return play(f, move, { { type = "strip", pos = start, dir = dir, length = move.length + f.bodyR * 0.6, width = move.width, land = tele + 0.1 } :: Shape }, { twist = 0.55 })
end

-- lantern wisps circle the boss and spiral outwards
MOVES.orbit = function(f, move, _target, tele)
	local m = { type = "orbit", o = f.cf.Position, n = move.n, a0 = rng:NextNumber(0, math.pi * 2), w = move.spin * (if rng:NextNumber() < 0.5 then 1 else -1), r0 = f.bodyR + 4, r1 = R(f) + 6, dur = move.dur, r = move.r, look = move.look, rehit = 1, delay = tele }
	return runMovers(f, move, { m })
end

MOVES.ring = function(f, move, _target, tele)
	return play(f, move, { { type = "ring", pos = f.cf.Position, inner = f.bodyR + move.inner, outer = f.bodyR + move.outer, land = tele + 0.25 } :: Shape })
end

MOVES.leap = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	local land = onFloor(f, root.Position, f.bodyR * 0.7 + 4)
	face(f, land)
	local from = f.cf
	-- the boss is in the air for the last 0.9 s of the warning (client/BossView arcs it), then stands where it lands
	local to = CFrame.lookAt(land, land + f.cf.LookVector)
	task.delay(math.max(0, tele + 0.45 - 0.9), function()
		if live(f) then
			f.cf = to
		end
	end)
	local ok = play(f, move, { { type = "circle", pos = land, r = move.radius, land = tele + 0.45 } :: Shape }, { from = from, to = to, air = 0.9 })
	if ok then
		f.cf = to
		mirror:SetAttribute("Cf", f.cf)
	end
	return ok
end

-- Bog ---------------------------------------------------------------------------------------------------------
-- a checkerboard of geysers: one colour, then the other
MOVES.grid = function(f, move, _target, tele)
	local c = C(f)
	local r = R(f) - 2
	local size = move.tile
	local yaw = rng:NextNumber(0, math.pi / 2)
	local cf = CFrame.Angles(0, yaw, 0)
	local first = rng:NextInteger(0, 1)
	local n = math.ceil(r / size)
	local shapes = {}
	for i = -n, n do
		for j = -n, n do
			local w = cf:VectorToWorldSpace(Vector3.new(i * size, 0, j * size))
			local pos = c + w
			if w.Magnitude <= r - size * 0.3 and flat(pos - f.cf.Position).Magnitude > f.bodyR * 0.8 then
				table.insert(shapes, { type = "square", pos = pos, size = size, yaw = yaw, land = tele + ((i + j + first) % 2) * move.gap } :: Shape)
			end
		end
	end
	return play(f, move, shapes)
end

-- a slime blob hops after a player, leaving puddles
MOVES.bounce = function(f, move, target, tele)
	local from: Vector3? = nil
	for k = 1, move.hops do
		local r = rootOf(target)
		if not r or not BossFighters.standing(target) then
			local alt = targets(f)[1]
			if not alt then
				return false
			end
			target = alt
			r = rootOf(alt)
		end
		local rp = r :: BasePart
		local pos = onFloor(f, rp.Position + flat(rp.AssemblyLinearVelocity) * 0.25, 4)
		if k == 1 then
			face(f, pos)
		end
		local land = if k == 1 then tele else move.hop
		local ok = play(f, move, { { type = "circle", pos = pos, r = move.r, land = land } :: Shape }, {
			ammo = move.ammo,
			pool = move.pool,
			flight = if k == 1 then math.min(1.0, tele) else move.hop * 0.95,
			fromPos = from,
			pose = if k == 1 then move.pose else "none",
			big = true,
		})
		if not ok then
			return false
		end
		from = pos + Vector3.new(0, 1, 0)
	end
	return true
end

-- vines burst up under every player, again and again: keep moving
MOVES.stalk = function(f, move, _target, tele)
	for k = 1, move.times do
		local shapes = {}
		for _, p in targets(f) do
			local r = rootOf(p)
			if r then
				table.insert(shapes, { type = "circle", pos = onFloor(f, r.Position, 3), r = move.r, land = if k == 1 then tele else move.step } :: Shape)
			end
		end
		if #shapes == 0 or not play(f, move, shapes, { pose = if k == 1 then move.pose else "none" }) then
			return false
		end
	end
	return true
end

-- the bog floods in from the wall; only the middle round the boss stays dry
MOVES.tide = function(f, move, _target, tele)
	local o = f.cf.Position
	local m = { type = "tide", o = o, rmax = R(f) + flat(o - C(f)).Magnitude + 2, rmin = f.bodyR + move.keep, tin = move.tin, hold = move.hold, tout = move.tout, tick = true, delay = tele }
	return runMovers(f, move, { m }, nil, true)
end

-- Harvest Reaper ----------------------------------------------------------------------------------------------
-- the scythe sweeps an arc across the front, slice by slice
MOVES.swing = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	local dir = dirTo(f, root.Position)
	local arc = math.rad(move.arc)
	local slice = arc / move.slices
	local side = if rng:NextNumber() < 0.5 then 1 else -1
	local shapes = {}
	for k = 1, move.slices do
		local mid = side * (-arc / 2 + (k - 0.5) * slice)
		table.insert(shapes, { type = "sector", pos = f.cf.Position, dir = rot(dir, mid), r = f.bodyR * 0.5 + move.r, half = slice / 2, inner = 0, land = tele + (k - 1) * move.step } :: Shape)
	end
	return play(f, move, shapes, { twist = 0.9 * side })
end

-- pumpkin bombs land round the players and blow after a fuse
MOVES.mines = function(f, move, _target, tele)
	local shapes = scatter(f, move, tele, move.flight + move.fuse)
	face(f, shapes[1].pos)
	return play(f, move, shapes, { flight = move.flight, ammo = move.ammo, fuse = move.fuse })
end

-- it charges through a player and leaves a trail of fire
MOVES.dash = function(f, move, target, tele)
	local root = rootOf(target) :: BasePart
	face(f, root.Position)
	local dir = dirTo(f, root.Position)
	local from = f.cf
	local start = from.Position
	local dest = onFloor(f, start + dir * (flat(root.Position - start).Magnitude + move.over), f.bodyR * 0.7 + 4)
	local len = flat(dest - start).Magnitude
	local to = CFrame.lookAt(dest, dest + dir)
	task.delay(math.max(0, tele - 0.3), function()
		if live(f) then
			f.cf = to
			mirror:SetAttribute("Cf", f.cf)
		end
	end)
	local ok = play(f, move, { { type = "strip", pos = start, dir = dir, length = len + f.bodyR * 0.5, width = move.width, land = tele } :: Shape }, { from = from, to = to, air = 0.3 })
	if ok then
		f.cf = to
		mirror:SetAttribute("Cf", f.cf)
		for d = 0, len, 7 do
			addHazard(f, start + dir * d, move.width * 0.45, move.trail)
		end
		Net.all("Fx", "bossTrail", { from = start, dir = dir, len = len, width = move.width, life = move.trail })
	end
	return ok
end

-- a reaper's mark follows one player, locks, then blows: run out of it
MOVES.mark = function(f, move, target, tele)
	local root = rootOf(target)
	if not root then
		return false
	end
	face(f, root.Position)
	local mark = marker(f, "BossMark", onFloor(f, root.Position, 2))
	mark:SetAttribute("R", move.r)
	Net.all("Fx", "bossMove", { kind = "mark", name = move.name, at = now(), shapes = {}, phase = f.phase, cf = f.cf, pose = move.pose })
	local untilT = os.clock() + tele + move.follow
	while os.clock() < untilT do
		task.wait(0.05)
		if not live(f) then
			mark:Destroy()
			return false
		end
		local r = rootOf(target)
		if r and BossFighters.standing(target) then
			mark.CFrame = CFrame.new(onFloor(f, r.Position, 2))
		end
	end
	local pos = mark.Position
	mark:Destroy()
	return play(f, move, { { type = "circle", pos = pos, r = move.r, land = move.lock } :: Shape }, { pose = "strike" })
end

-- Jungle Titan ------------------------------------------------------------------------------------------------
-- cracks shoot out in six directions, then six more in between
MOVES.star = function(f, move, _target, tele)
	local a0 = rng:NextNumber(0, math.pi * 2)
	local shapes = {}
	for w = 0, 1 do
		for k = 0, move.arms - 1 do
			local a = a0 + k * 2 * math.pi / move.arms + w * math.pi / move.arms
			table.insert(shapes, { type = "strip", pos = f.cf.Position, dir = Vector3.new(math.sin(a), 0, math.cos(a)), length = R(f) * 2, width = move.width, land = tele + 0.15 + w * move.second } :: Shape)
		end
	end
	return play(f, move, shapes)
end

-- rune meteors rain all over the arena (one on every player)
MOVES.meteors = function(f, move, _target, tele)
	local c = C(f)
	local list = targets(f)
	local shapes = {}
	for k = 1, move.count do
		local pr = if k <= #list then rootOf(list[k]) else nil
		local pos
		if pr then
			pos = pr.Position
		else
			local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * (R(f) - 6)
			pos = c + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		end
		table.insert(shapes, { type = "circle", pos = onFloor(f, pos, 4), r = move.radius, land = tele + 0.3 + rng:NextNumber(0, move.spread) } :: Shape)
	end
	return play(f, move, shapes, { ammo = move.ammo, flight = 1.1, sky = true })
end

-- stone pillars burst up (don't stand there) and stay as walls
MOVES.pillars = function(f, move, _target, tele)
	local c = C(f)
	local a0 = rng:NextNumber(0, math.pi * 2)
	local shapes = {}
	for k = 1, move.count do
		local a = a0 + (k - 1) / move.count * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local d = rng:NextNumber(24, R(f) - 12)
		local pos = c + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		if flat(pos - f.cf.Position).Magnitude < f.bodyR + move.r + 6 then
			pos = c - Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		end
		table.insert(shapes, { type = "circle", pos = pos, r = move.r + 1.5, land = tele } :: Shape)
	end
	local ok = play(f, move, shapes)
	if ok then
		for _, s in shapes do
			raisePillar(f, s.pos, move.r, move.stay)
		end
	end
	return ok
end

-- rune lasers lock onto every player, then fire: side-step
MOVES.laser = function(f, move, _target, _tele)
	for shot = 1, move.shots do
		local list = targets(f)
		if #list == 0 then
			return false
		end
		local ids = {}
		for _, p in list do
			table.insert(ids, p.UserId)
		end
		Net.all("Fx", "bossAim", { at = now(), len = move.aim, ids = ids, from = f.cf.Position, width = move.width })
		if not hold(f, move.aim) then
			return false
		end
		local shapes = {}
		for _, p in list do
			local r = rootOf(p)
			if r then
				table.insert(shapes, { type = "strip", pos = f.cf.Position, dir = dirTo(f, r.Position), length = R(f) * 2.2, width = move.width, land = 0.45 } :: Shape)
			end
		end
		if #shapes == 0 then
			return false
		end
		face(f, f.cf.Position + shapes[1].dir * 10)
		if not play(f, move, shapes, { laser = true, punish = shot == move.shots }) then
			return false
		end
	end
	return true
end

-- its eye fills the arena with light: only the shadows behind the pillars are safe
MOVES.gaze = function(f, move, target, tele)
	local standing = 0
	for _, p in f.pillars do
		if p.untilT > os.clock() + move.charge + 0.5 then
			standing += 1
		end
	end
	if standing < 2 then
		local pm = { kind = "pillars", name = "Stone Pillars", count = 3, r = 4, stay = 9, pose = "stomp" }
		for _, m in f.moves.moves do
			if m.kind == "pillars" then
				pm = m
			end
		end
		if not MOVES.pillars(f, pm, target, math.max(1.1, tele * 0.8)) then
			return false
		end
	end
	local from = f.cf.Position
	local shadows = {}
	for _, p in f.pillars do
		local d = flat(p.pos - from)
		if p.untilT > os.clock() + move.charge and d.Magnitude > 1 then
			local dir = d.Unit
			table.insert(shadows, { pos = p.pos - dir * (p.r * 0.5), dir = dir, length = R(f) * 2.2, width = p.r * 2 + 1 })
		end
	end
	return play(f, move, { { type = "safe", pos = C(f), r = R(f) + 4, shadows = shadows, land = move.charge } :: Shape }, { gaze = true })
end

-------------------------------------------------------------------------------------------------------------
-- minions (the Dandelion King's seedlings, the Hive Keeper's bees, the Bog's spitting sprouts, the Reaper's
-- exploding jack-o'-minions): invisible parts the clients dress (client/BossAdds); Boss.hitAdds pops them
--   chase: run after you and bite | homing: fly at you, sting once and pop | turret: sit and spit slime at you
--   boom: run at you, stop, flash, explode
-------------------------------------------------------------------------------------------------------------
local function spawnAdds(f: Fight, move: any, target: Player, tele: number, ai: string): boolean
	local root = rootOf(target)
	if root then
		face(f, root.Position)
	end
	local n = math.min(move.count, 8 - #f.adds)
	if n <= 0 then
		return false
	end
	local shapes = {}
	local a0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, n do
		local a = a0 + (i - 1) / n * math.pi * 2
		local base = if ai == "turret" then C(f) else f.cf.Position
		local d = if ai == "turret" then rng:NextNumber(28, R(f) - 12) else f.bodyR + 7
		local pos = onFloor(f, base + Vector3.new(math.cos(a), 0, math.sin(a)) * d, 5)
		table.insert(shapes, { type = "circle", pos = pos, r = 3.5, land = tele + (i - 1) * 0.12 } :: Shape)
	end
	-- the circles only show where they come out: nobody gets hurt by them
	Net.all("Fx", "bossMove", { kind = "adds", name = move.name, at = now(), shapes = shapes, phase = f.phase, cf = f.cf, minion = move.minion, pose = move.pose or "stomp" })
	if not hold(f, shapes[#shapes].land) then
		return false
	end
	local folder = f.arena.model:FindFirstChild("Adds") or Instance.new("Folder")
	folder.Name = "Adds"
	folder.Parent = f.arena.model
	for _, s in shapes do
		local part = Instance.new("Part")
		part.Name = "BossAdd"
		part.Size = Vector3.new(3, 3, 3)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = CFrame.new(s.pos + Vector3.new(0, 1.5, 0))
		part:SetAttribute("Look", move.minion or "seedling")
		part:SetAttribute("Zone", f.z)
		part.Parent = folder
		local speed = if ai == "homing" then move.speed or 12 elseif ai == "boom" then 10 + f.z * 0.5 elseif ai == "turret" then 0 else 9 + f.z * 0.7
		table.insert(f.adds, {
			part = part,
			hp = move.hp or 2,
			biteAt = os.clock() + 0.8,
			born = os.clock(),
			speed = speed,
			ai = ai,
			life = move.life or 30,
			blast = move.blast or 7,
			every = move.every or 2.4,
			nextShot = os.clock() + 1.2 + rng:NextNumber(0, 0.8),
			armed = false,
		})
	end
	return true
end

MOVES.adds = function(f, move, target, tele)
	return spawnAdds(f, move, target, tele, move.ai or "chase")
end

MOVES.homing = function(f, move, target, tele)
	return spawnAdds(f, move, target, tele, "homing")
end

MOVES.turrets = function(f, move, target, tele)
	return spawnAdds(f, move, target, tele, "turret")
end

local function clearAdds(f: Fight)
	for _, a in f.adds do
		if a.part.Parent then
			a.part:Destroy()
		end
	end
	table.clear(f.adds)
	table.clear(f.hazards)
	table.clear(f.movers)
	for _, p in f.pillars do
		if p.part.Parent then
			p.part:Destroy()
		end
	end
	table.clear(f.pillars)
	local fx = f.arena.model and f.arena.model:FindFirstChild("BossFx")
	if fx then
		fx:ClearAllChildren()
	end
	f.hidden = false
end

-- the nearest standing fighter to `pos`
local function nearestFighter(pos: Vector3): (BasePart?, number)
	local best, bestD = nil, math.huge
	for _, p in BossFighters.list() do
		local root = rootOf(p)
		if root and BossFighters.standing(p) then
			local d = flat(root.Position - pos).Magnitude
			if d < bestD then
				best, bestD = root, d
			end
		end
	end
	return best, bestD
end

local function popAdd(a: Add, burrow: boolean?)
	if a.part.Parent then
		Net.all("Fx", "bossAddPop", { pos = a.part.Position, look = a.part:GetAttribute("Look"), burrow = burrow })
		a.part:Destroy()
	end
end

local function stepAdds(f: Fight, t: number, dt: number)
	for i = #f.adds, 1, -1 do
		local a = f.adds[i]
		if not a.part.Parent or t - a.born > a.life then
			popAdd(a, true)
			table.remove(f.adds, i)
			continue
		end
		if a.armed or t < a.biteAt - 0.6 then
			continue -- about to blow / still popping out / recovering from a bite
		end
		local best, bestD = nearestFighter(a.part.Position)
		if not best then
			continue
		end
		local from = a.part.Position
		local owner = Players:GetPlayerFromCharacter(best.Parent)
		if a.ai == "turret" then
			if t >= a.nextShot and bestD < R(f) * 1.6 then
				a.nextShot = t + a.every
				local aim = onFloor(f, best.Position + flat(best.AssemblyLinearVelocity) * 0.4, 3)
				task.spawn(play, f, { kind = "turrets", name = "Spit" }, { { type = "circle", pos = aim, r = 5, land = 1.1 } :: Shape }, { ammo = "bubble", flight = 1.0, fromPos = from + Vector3.new(0, 1.5, 0), pose = "none" })
			end
			continue
		end
		if a.ai == "homing" and bestD <= 3.2 then
			if owner then
				BossFighters.hit(owner, math.floor(BossMoves.DAMAGE.homing * f.curve.damage + 0.5), from)
			end
			popAdd(a)
			table.remove(f.adds, i)
			continue
		end
		if a.ai == "boom" and bestD <= 5 then
			a.armed = true
			local at = Vector3.new(from.X, f.arena.centre.Y, from.Z)
			task.spawn(function()
				play(f, { kind = "boom", name = "Boom" }, { { type = "circle", pos = at, r = a.blast, land = 0.9 } :: Shape }, { pose = "none" })
				popAdd(a)
			end)
			continue
		end
		if a.ai == "chase" and bestD <= 3.4 and t >= a.biteAt then
			a.biteAt = t + 1.6
			if owner then
				BossFighters.hit(owner, math.floor(BossMoves.DAMAGE.adds * f.curve.damage + 0.5), from, true)
				Net.all("Fx", "bossAddBite", { pos = from })
			end
		elseif bestD > 2.6 then
			local to = flat(best.Position - from)
			local step = math.min(bestD - 2.4, a.speed * dt)
			local nextPos = onFloor(f, from + to.Unit * step, 3)
			a.part.CFrame = CFrame.lookAt(Vector3.new(nextPos.X, from.Y, nextPos.Z), Vector3.new(best.Position.X, from.Y, best.Position.Z))
		end
	end
end

local function stepHazards(f: Fight, t: number)
	for i = #f.hazards, 1, -1 do
		local h = f.hazards[i]
		if t > h.untilT then
			table.remove(f.hazards, i)
			continue
		end
		for _, p in BossFighters.list() do
			local root = rootOf(p)
			local isIn = root and BossFighters.standing(p) and flat(root.Position - h.pos).Magnitude <= h.r and math.abs(root.Position.Y - h.pos.Y) < 10
			if h.sink then
				-- sand: only after standing in it ~1.2 s (two ticks)
				if isIn then
					h.inside[p] = (h.inside[p] or 0) + 1
					if h.inside[p] >= 2 then
						h.inside[p] = 0
						BossFighters.hit(p, h.dmg, h.pos)
					end
				else
					h.inside[p] = nil
				end
			elseif isIn then
				BossFighters.hit(p, h.dmg, h.pos, true)
			end
		end
	end
end

-- the moving things: who's touching them right now (waves can be jumped)
local function stepMovers(f: Fight)
	local t = now()
	local floorY = f.arena.centre.Y
	for i = #f.movers, 1, -1 do
		local mv = f.movers[i]
		local m = mv.m
		local age = t - m.t0
		if age > mv.dur + 0.1 then
			table.remove(f.movers, i)
			continue
		end
		local shapes = BossMoves.moverShapes(m, age)
		if #shapes == 0 then
			continue
		end
		for _, p in BossFighters.list() do
			local root = rootOf(p)
			if not root or not BossFighters.standing(p) or (mv.hit[p] or 0) > os.clock() then
				continue
			end
			local y = root.Position.Y - floorY
			if y > 14 or y < -6 or (m.jump and y > BossMoves.JUMP_CLEAR) then
				continue
			end
			for _, s in shapes do
				if BossMoves.inShape(s, root.Position) then
					local dmg = math.max(1, math.floor((BossMoves.DAMAGE[mv.kind] or 15) * f.curve.damage + 0.5))
					BossFighters.hit(p, dmg, s.pos, m.tick)
					mv.hit[p] = os.clock() + (if m.tick then BossMoves.HAZARD_TICK elseif m.rehit then m.rehit else 1e9)
					break
				end
			end
		end
	end
end

-- hazards hurt, minions chase and bite, moving things hit (every 0.05 s while the fight runs)
local function hazardLoop(f: Fight)
	local nextTick = 0
	while live(f) do
		local dt = task.wait(0.05)
		local t = os.clock()
		if not live(f) or f.state ~= "fight" then
			continue
		end
		if t >= nextTick then
			nextTick = t + BossMoves.HAZARD_TICK
			stepHazards(f, t)
		end
		stepAdds(f, t, dt)
		stepMovers(f)
	end
	clearAdds(f)
end

-- pets chip in (owner, round 2): a small slice of the boss's HP per equipped pet each second
local function petLoop(f: Fight)
	local chip = Config.BOSS_PET_CHIP
	while live(f) do
		if not hold(f, chip.every) then
			break
		end
		if f.state ~= "fight" then
			continue
		end
		for _, p in BossFighters.list() do
			local data = PlayerData.get(p)
			local pets = if data and data.petsOn then #data.petsOn else 0
			local root = rootOf(p)
			if pets > 0 and root and BossFighters.standing(p) and BossArena.inside(f.z, root.Position, 0) then
				Boss.damage(p, f.maxHp * chip.perPet * pets * chip.every, true)
			end
		end
	end
end

local function pickMove(f: Fight): any
	local pool = {}
	for _, m in f.moves.moves do
		table.insert(pool, { m = m, w = if f.phase == 2 then 0.7 else 1 })
	end
	if f.phase == 2 then
		for _, m in f.moves.moves2 do
			table.insert(pool, { m = m, w = 1.4 })
		end
	end
	local total = 0
	for _, e in pool do
		if e.m.name == f.lastMove then
			e.w *= 0.15 -- rarely the same move twice in a row
		end
		total += e.w
	end
	local roll = rng:NextNumber() * total
	for _, e in pool do
		roll -= e.w
		if roll <= 0 then
			return e.m
		end
	end
	return pool[1].m
end

-------------------------------------------------------------------------------------------------------------
-- phases
-------------------------------------------------------------------------------------------------------------
local function setState(f: Fight, state: string, len: number?)
	f.state = state
	mirror:SetAttribute("StateAt", now())
	mirror:SetAttribute("StateLen", len or 0)
	publish(f)
	changed()
end

local function reset(f: Fight, why: string)
	if current ~= f then
		return
	end
	f.alive = false
	current = nil
	token += 1
	clearAdds(f)
	Net.all("Fx", "bossReset", { z = f.z, why = why })
	pcall(function()
		require(script.Parent.Analytics).event("BossWipe", f.z, why) -- (29 Oct) where fights are lost
	end)
	BossFighters.stop()
	BossArena.setGate(f.z, false)
	BossArena.setPad(f.z, "ready")
	publish(nil)
	changed()
end

local function defeat(f: Fight)
	setState(f, "dying", BossMoves.DEATH_TIME)
	Net.all("Fx", "bossDeath", { z = f.z, at = now(), len = BossMoves.DEATH_TIME, cf = f.cf, line = f.moves.lines.death, name = f.def.name })
	clearAdds(f)
	Net.all("Fx", "bossAddsClear", {})
	local snapshot = table.clone(f.damageBy)
	local noHit = BossFighters.noHit()
	task.delay(BossMoves.DEATH_TIME, function()
		if current ~= f then
			return
		end
		f.alive = false
		current = nil
		token += 1
		beaten[f.z] = true
		BossFighters.stop()
		BossArena.setGate(f.z, false)
		BossArena.setPad(f.z, "done")
		BossArena.dropWall(f.z, true) -- (29 Oct) the invisible wall sinks away
		publish(nil)
		if Boss.onDefeated then
			Boss.onDefeated(f.z, snapshot, noHit)
		end
		changed()
	end)
end

local function rage(f: Fight)
	setState(f, "rage", BossMoves.RAGE_TIME)
	f.phase = 2
	f.openUntil = 0
	publish(f)
	Net.all("Fx", "bossRage", { z = f.z, at = now(), len = BossMoves.RAGE_TIME, cf = f.cf, line = f.moves.lines.rage, title = f.moves.rageTitle })
	-- everyone is frozen where they stand for the cutscene (owner, round 2); minions and hazards go
	clearAdds(f)
	Net.all("Fx", "bossAddsClear", {})
	BossFighters.freeze(true)
	local ok = hold(f, BossMoves.RAGE_TIME)
	BossFighters.freeze(false)
	if ok then
		-- the roar's shockwave knocks everyone back as the fight resumes
		for _, p in BossFighters.list() do
			local root = rootOf(p)
			if root and BossFighters.standing(p) then
				BossFighters.stun(p, f.cf.Position, 1.8)
			end
		end
		BossFighters.shedHeals(1 + math.floor(#BossFighters.list() / 2))
		setState(f, "fight")
	end
end

-- (30 Oct, owner: "the bosses are very stiff and dont do alot they are just a statue") between moves the boss
-- doesn't stand there: it gets its breath back, then turns to one of the fighters and stalks towards them (stopping
-- short of them), so the next move comes from somewhere new. client/BossLife rocks it from side to side as it goes.
-- It stays put while it's open, underground, or while something it set going (a beam, a ring) still runs.
local function prowl(f: Fight, t: number): boolean
	local P = (Config :: any).BOSS_PROWL
	if not P then
		return hold(f, t)
	end
	local untilT = os.clock() + t
	if not hold(f, math.min(t, P.pause)) then
		return false
	end
	local list = targets(f)
	local prey: Player? = if #list > 0 then list[rng:NextInteger(1, #list)] else nil
	local speed = P.speed * f.moves.height / 40
	local last = os.clock()
	while os.clock() < untilT do
		task.wait(math.min(0.15, math.max(0.01, untilT - os.clock())))
		if not live(f) then
			return false
		end
		local dt = os.clock() - last
		last = os.clock()
		local root = prey and rootOf(prey)
		if root and f.state == "fight" and not f.hidden and #f.movers == 0 and os.clock() >= f.openUntil and BossFighters.standing(prey :: Player) then
			local pos = f.cf.Position
			local to = flat(root.Position - pos)
			local gap = to.Magnitude - (f.bodyR + P.keep)
			if gap > 0.5 then
				local dir = to.Unit
				local nextPos = onFloor(f, pos + dir * math.min(speed * dt, gap), f.bodyR * 0.7 + 4)
				f.cf = CFrame.lookAt(nextPos, nextPos + dir)
				mirror:SetAttribute("Cf", f.cf)
			else
				face(f, root.Position)
			end
		end
	end
	return live(f)
end

local function fightLoop(f: Fight)
	local nextHeal = os.clock() + Config.BOSS_HEAL.every
	while live(f) do
		if f.state == "fight" then
			local list = targets(f)
			if #list > 0 then
				local move = pickMove(f)
				f.lastMove = move.name
				local tele = if f.phase == 2 then f.curve.tele2 else f.curve.tele
				local ok, done = pcall(MOVES[move.kind] or MOVES.slam, f, move, list[rng:NextInteger(1, #list)], tele)
				if not ok then
					warn("[Boss] " .. move.name .. ": " .. tostring(done))
				elseif done == true and move.punish and live(f) then
					punish(f)
				end
				if not live(f) then
					break
				end
				if f.state == "fight" and f.phase == 1 and f.hp <= f.maxHp * BossMoves.RAGE_AT then
					rage(f)
				elseif f.state == "fight" then
					prowl(f, f.curve.gap * (if f.phase == 2 then 0.6 else 1) * rng:NextNumber(0.85, 1.25))
				end
			else
				hold(f, 0.3)
			end
			if os.clock() >= nextHeal and f.state == "fight" then
				nextHeal = os.clock() + Config.BOSS_HEAL.every
				BossFighters.shedHeals(if #BossFighters.list() >= 3 then 2 else 1)
			end
		else
			hold(f, 0.2)
		end
	end
end

-- watch for a wipe (everyone down or gone) while the fight runs
local function wipeWatch(f: Fight)
	local since: number? = nil
	while live(f) do
		task.wait(0.5)
		if f.state == "fight" or f.state == "rage" then
			if BossFighters.wiped() then
				since = since or os.clock()
				if os.clock() - since > 1.5 then
					reset(f, "wipe")
					return
				end
			else
				since = nil
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- public
-------------------------------------------------------------------------------------------------------------
function Boss.setup(_parent: Instance)
	Net.on("Boss", 4, function(player: Player, action: any)
		local f = current
		if action ~= "skip" or not f or f.state ~= "intro" or f.skipped then
			return
		end
		f.votes[player] = true
		-- everyone in the arena must vote
		local inside = BossArena.playersInside(f.z)
		local yes = 0
		for _, p in inside do
			if f.votes[p] then
				yes += 1
			end
		end
		Net.all("Fx", "bossSkipVotes", { yes = yes, need = #inside })
		if #inside > 0 and yes >= #inside then
			f.skipped = true
		end
	end)
end

function Boss.state()
	local f = current
	if not f or not f.alive then
		return nil
	end
	return { name = f.def.name, hp = f.hp, max = f.maxHp, z = f.z, phase = f.phase, state = f.state }
end

-- (29 Oct, the bug sweep) Whether area z is mowed and its boss waits on the summon pad: awake and not fought yet, or
-- waiting again after the party went down. (server/Run's world state: the HUD's area card says so.)
function Boss.waiting(z: number): boolean
	return ready[z] == true and not beaten[z] and (current == nil or current.z ~= z)
end

-- Area z is mowed: its boss wakes and the summon pad lights up (once per run).
function Boss.ready(z: number)
	if beaten[z] or ready[z] then
		return
	end
	local arena = BossArena.get(z)
	if not arena then
		-- no arena (it failed to build): fight where it always was
		ready[z] = true
		Boss.spawn(z)
		return
	end
	ready[z] = true
	BossArena.setPad(z, "ready")
	Net.all("Fx", "bossReady", { z = z, pos = arena.padPos, name = Config.ZONES[z].boss.name })
	changed() -- (29 Oct) the HUD's area card says the boss is waiting
	task.spawn(function()
		local stood: { [Player]: number } = {}
		while ready[z] and not beaten[z] do
			task.wait(0.2)
			if not current then
				for _, p in Players:GetPlayers() do
					local root = rootOf(p)
					local on = root and flat(root.Position - arena.padPos).Magnitude <= 7 and math.abs(root.Position.Y - arena.padPos.Y) < 7
					if on then
						stood[p] = (stood[p] or 0) + 0.2
						if stood[p] >= BossMoves.SUMMON_HOLD then
							table.clear(stood)
							Boss.spawn(z)
							break
						end
					else
						stood[p] = nil
					end
				end
			end
		end
	end)
end

function Boss.spawn(z: number)
	if current or beaten[z] then
		return
	end
	local arena = BossArena.get(z)
	local moves = BossMoves.get(z)
	local def = Config.ZONES[z].boss
	local rig = BossRig.load(moves.rig)
	local height = if rig then rig.bounds[2][2] else 7
	local scale = moves.height / math.max(1, height)
	local footR = if rig then math.max(rig.bounds[2][1], rig.bounds[2][3]) else 4
	local home = if arena then arena.bossSpot else CFrame.new(Config.zoneCentre(z))
	token += 1
	local f: Fight = {
		z = z,
		token = token,
		def = def,
		moves = moves,
		arena = arena or { centre = home.Position, radius = 60, facing = home.LookVector, entry = home.Position, model = workspace },
		rig = moves.rig,
		scale = scale,
		bodyR = footR * scale * 0.62,
		cf = home,
		home = home,
		hp = 1,
		maxHp = 1,
		phase = 1,
		state = "intro",
		alive = true,
		openUntil = 0,
		damageBy = {},
		votes = {},
		skipped = false,
		curve = BossMoves.curve(z),
		hazards = {},
		adds = {},
		movers = {},
		pillars = {},
		hidden = false,
	}
	local base = (Config.BOSS_HP and Config.BOSS_HP[z]) or def.hp
	-- (owner, 29 Oct) the run's difficulty (server/Run sets Boss.difficulty): more HP, harder hits, faster attacks
	local D = Boss.difficulty
	base = math.floor(base * D.hp + 0.5)
	f.curve.damage *= D.dmg
	f.curve.tele = math.max(0.75, f.curve.tele * D.speed)
	f.curve.tele2 = math.max(0.65, f.curve.tele2 * D.speed)
	f.curve.gap *= D.speed
	f.maxHp = base
	f.hp = base
	current = f
	if arena then
		BossArena.setPad(z, "busy")
	end
	local first = not seenIntro[z]
	seenIntro[z] = true
	local introLen = if first then BossMoves.INTRO_FIRST else BossMoves.INTRO_AGAIN
	BossFighters.begin(f.arena, BossArena.playersInside(z))
	setState(f, "intro", introLen)
	Net.all("Fx", "bossIntro", {
		z = z,
		rig = f.rig,
		name = def.name,
		title = moves.title,
		line = moves.lines.intro,
		cf = f.cf,
		scale = scale,
		at = now(),
		len = introLen,
		first = first,
		arena = f.arena.centre,
		facing = f.arena.facing,
	})
	changed()
	-- the join window: walkers-in become fighters; then the gate closes and the HP is set for the party
	task.spawn(function()
		local closeAt = os.clock() + BossMoves.JOIN_WINDOW
		while alive(f) and os.clock() < closeAt do
			for _, p in BossArena.playersInside(z) do
				BossFighters.add(p)
			end
			task.wait(0.25)
		end
		if not alive(f) then
			return
		end
		-- everyone else still out in this area is pulled in before the gate shuts (owner, round 2)
		for _, p in Players:GetPlayers() do
			local root = rootOf(p)
			if root and Config.zoneAt(root.Position) == z and not BossArena.inside(z, root.Position, 2) then
				BossArena.pullIn(z, p)
				BossFighters.add(p)
			end
		end
		BossArena.setGate(z, true)
		local n = math.clamp(#BossFighters.list(), 1, #Config.BOSS_PARTY_HP)
		local done = f.maxHp - f.hp
		f.maxHp = math.floor(base * Config.BOSS_PARTY_HP[n])
		f.hp = math.max(1, f.maxHp - done)
		publish(f)
		changed()
	end)
	-- the intro, then the fight
	task.spawn(function()
		local endAt = os.clock() + introLen
		while alive(f) and os.clock() < endAt and not f.skipped do
			task.wait(0.1)
		end
		if not alive(f) then
			return
		end
		if f.skipped then
			Net.all("Fx", "bossSkip", { z = z })
		end
		setState(f, "fight")
		task.spawn(wipeWatch, f)
		task.spawn(hazardLoop, f)
		task.spawn(petLoop, f)
		fightLoop(f)
	end)
end

-- Is `pos` close enough to hit the boss with reach `reach`?
function Boss.inReach(pos: Vector3, reach: number): boolean
	local f = current
	if not f or not f.alive or f.state ~= "fight" or f.hidden then
		return false
	end
	local d = flat(pos - f.cf.Position).Magnitude
	return d <= f.bodyR + reach + 2 and math.abs(pos.Y - f.cf.Position.Y) < 40
end

function Boss.damage(player: Player, amount: number, pet: boolean?)
	local f = current
	if not f or not f.alive or f.state ~= "fight" or amount <= 0 then
		return
	end
	if not BossFighters.standing(player) or f.hidden then
		return
	end
	local weak = not pet and os.clock() < f.openUntil
	if weak then
		amount *= BossMoves.WEAK_MULT
	end
	-- phase 1 stops at the rage line: the rest waits for the cutscene
	local floor = if f.phase == 1 then f.maxHp * BossMoves.RAGE_AT else 0
	f.hp = math.max(floor, f.hp - amount)
	f.damageBy[player] = (f.damageBy[player] or 0) + amount
	mirror:SetAttribute("Hp", math.ceil(f.hp))
	if not pet then
		Net.send(player, "Fx", "bossHit", { pos = f.cf.Position + Vector3.new(0, f.moves.height * 0.45, 0), amount = amount, hp = f.hp, max = f.maxHp, weak = weak })
	end
	changed()
	if f.hp <= 0 then
		defeat(f)
	elseif f.phase == 1 and f.hp <= floor then
		-- the fight loop starts the rage at the end of the current move; make it quick
		f.openUntil = 0
	end
end

-- A hand-tool swing at `pos` with reach `reach`: knocks a hit off every minion in reach (true if any).
function Boss.hitAdds(player: Player, pos: Vector3, reach: number): boolean
	local f = current
	if not f or not f.alive or #f.adds == 0 or not BossFighters.standing(player) then
		return false
	end
	local any = false
	for i = #f.adds, 1, -1 do
		local a = f.adds[i]
		if a.part.Parent and flat(a.part.Position - pos).Magnitude <= reach + 3 then
			any = true
			a.hp -= 1
			if a.hp <= 0 then
				Net.all("Fx", "bossAddPop", { pos = a.part.Position, look = a.part:GetAttribute("Look") })
				a.part:Destroy()
				table.remove(f.adds, i)
			else
				a.biteAt = math.max(a.biteAt, os.clock() + 0.5)
				Net.all("Fx", "bossAddHit", { pos = a.part.Position })
			end
		end
	end
	return any
end

-- Where the boss stands and its max HP (the old boss-crate guns).
function Boss.info(): (Vector3?, number)
	local f = current
	if not f or not f.alive then
		return nil, 0
	end
	return f.cf.Position, f.maxHp
end

function Boss.alive(): boolean
	return current ~= nil and current.alive
end

function Boss.stun(player: Player, from: Vector3)
	BossFighters.stun(player, from)
end

function Boss.beaten(z: number): boolean
	return beaten[z] == true
end

-- (29 Oct) A run loading (or a dev jump) past area z: its boss counts as beaten, its pad says BEATEN and its
-- arena's invisible wall is gone, as it was when the boss fell.
function Boss.markBeaten(z: number)
	if beaten[z] or (current and current.z == z) then
		return
	end
	beaten[z] = true
	ready[z] = nil
	BossArena.setGate(z, false)
	BossArena.setPad(z, "done")
	BossArena.dropWall(z, false)
end

-- Studio / dev panel helpers: ready <z> (light the pad) | to <z> (put the player on the pad) | fight <z> (start now)
-- | rage (HP to the rage line) | hurt <fraction of max HP> | kill | wipe (as if everyone went down)
function Boss.dev(cmd: string, a: any, player: Player?)
	local f = current
	if cmd == "ready" then
		beaten[a] = nil
		ready[a] = nil
		Boss.ready(a)
	elseif cmd == "to" then
		local arena = BossArena.get(a)
		local root = player and rootOf(player)
		if arena and root then
			root.CFrame = CFrame.new(arena.padPos + arena.facing * 9 + Vector3.new(0, 4, 0))
		end
	elseif cmd == "fight" then
		beaten[a] = nil
		Boss.spawn(a)
	elseif f and cmd == "rage" then
		f.hp = math.min(f.hp, f.maxHp * BossMoves.RAGE_AT)
		publish(f)
	elseif f and cmd == "hurt" then
		local floor = if f.phase == 1 then f.maxHp * BossMoves.RAGE_AT else 0
		f.hp = math.max(floor, f.hp - f.maxHp * (tonumber(a) or 0.1))
		publish(f)
		if f.hp <= 0 and f.state == "fight" then
			defeat(f)
		end
	elseif f and cmd == "kill" then
		f.hp = 0
		publish(f)
		defeat(f)
	elseif f and cmd == "wipe" then
		reset(f, "wipe")
	end
	changed()
end

return Boss
