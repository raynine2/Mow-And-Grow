-- FUNNY MOMENTS (5 Nov, owner: "make your friends laugh"). Three harmless gags, decided here and drawn by every
-- client (client/Funny). Nothing here hurts, costs or takes anything: no damage, no coins, no bundles, no sale.
--   squash: a felled clump's top lands on a player (server/Field's fell -> Field.onFell): flat like a pancake for a
--           moment, stars round the head, BONK!, can't walk, then springs back up (Fx "funnySquash").
--   bonk:   a hand-tool swing that struck nothing but is aimed at another player in reach (server/Run's onSwing):
--           a tiny nudge their own client applies (Fx "funnyNudge" to them; they own their physics), a squeak and
--           a word for everyone (Fx "funnyBonk").
--   spit:   jumping into a Giant Grass Shredder's hopper: the machine gulps you (held inside, hidden), rumbles and
--           spits you out of the chute in a big arc onto safe ground in front of it (Fx "funnySpit"; the arc is
--           "funnyLaunch" to the victim's client).
-- Never during a boss fight (a fighter, or near an arena while a boss is up), a film or the ending (Run's `busy`),
-- or on a mower. All tuning is Config.FUNNY. No new remotes: everything goes out on "Fx".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local Field = require(script.Parent.Field)
local Boss = require(script.Parent.Boss)
local BossArena = require(script.Parent.BossArena)
local BossFighters = require(script.Parent.BossFighters)
local Mowers = require(script.Parent.Mowers)

local Funny = {}

local CFG = Config.FUNNY
local busyFn: ((Player) -> boolean)? = nil
local padList: { any } = {}
local started = false

-- per player: until when they're flat / inside a shredder / can't be bonked, and their cooldowns
local squashedUntil: { [Player]: number } = {}
local squashReady: { [Player]: number } = {}
local spitting: { [Player]: boolean } = {}
local spitReady: { [Player]: number } = {}
local bonkImmune: { [Player]: number } = {}
local pairReady: { [Player]: { [Player]: number } } = {}

local function rootOf(p: Player): BasePart?
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humOf(p: Player): Humanoid?
	local c = p.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Can this player be part of a gag right now? (alive, on foot, not in a film, the ending or a boss fight)
local function free(p: Player): boolean
	local root, hum = rootOf(p), humOf(p)
	if not root or not hum or hum.Health <= 0 or hum.Sit or root.Anchored then
		return false
	end
	if busyFn and busyFn(p) then
		return false
	end
	if p:GetAttribute("Downed") then
		return false
	end
	if Boss.alive() and (BossFighters.isFighter(p) or BossArena.near(root.Position, 12)) then
		return false
	end
	if Mowers.driving(p) then
		return false
	end
	local now = os.clock()
	return not spitting[p] and (squashedUntil[p] or 0) < now
end

-- Rays and boxes that ignore every character (and anything that doesn't collide).
local function worldParams(): (RaycastParams, OverlapParams)
	local chars = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = chars
	rp.RespectCanCollide = true
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = chars
	op.RespectCanCollide = true
	return rp, op
end

-------------------------------------------------------------------------------------------------------------
-- squash
-------------------------------------------------------------------------------------------------------------
-- A clump at `base` (its foot) falls along `dir`: its top lands `height` away. Who's under it?
local function under(base: Vector3, dir: Vector3, height: number, radius: number): { Player }
	local c = CFG.squash
	local hit = {}
	for _, p in Players:GetPlayers() do
		local root = rootOf(p)
		if root and free(p) and os.clock() >= (squashReady[p] or 0) then
			local rel = root.Position - base
			if math.abs(rel.Y) <= c.upDown then
				local along = flat(rel):Dot(dir)
				local side = (flat(rel) - dir * along).Magnitude
				if along >= height * c.from and along <= height + radius and side <= radius + c.width then
					table.insert(hit, p)
				end
			end
		end
	end
	return hit
end

local function onFell(p: any)
	local c = CFG.squash
	if not c.on then
		return
	end
	local height = tonumber(p.height) or 0
	local spot = p.spot :: CFrame?
	local dir = p.fallDir :: Vector3?
	if height < c.minHeight or not spot or not dir then
		return
	end
	local base = spot.Position
	local radius = tonumber(p.radius) or 1.5
	dir = flat(dir :: Vector3)
	if (dir :: Vector3).Magnitude < 0.1 then
		return
	end
	dir = (dir :: Vector3).Unit
	-- the top comes down at the end of the fall (Field.FALL_TIME; the cutter's client may hold it a hair longer)
	task.wait((Field.FALL_TIME or 0.7) * 0.9)
	local hit = under(base, dir :: Vector3, height, radius)
	if #hit == 0 then
		return
	end
	local now = os.clock()
	local ids = {}
	for _, v in hit do
		squashedUntil[v] = now + c.time
		squashReady[v] = now + c.cooldown
		table.insert(ids, v.UserId)
	end
	Net.all("Fx", "funnySquash", { ids = ids, time = c.time, pos = base + (dir :: Vector3) * height * 0.7 })
end

-------------------------------------------------------------------------------------------------------------
-- bonk
-------------------------------------------------------------------------------------------------------------
-- Is the ground `edge` studs on from `pos` there, and not much lower? (no nudge toward a drop or the void)
local function safeAhead(pos: Vector3, dir: Vector3): boolean
	local c = CFG.bonk
	local rp = worldParams()
	local here = workspace:Raycast(pos, Vector3.new(0, -12, 0), rp)
	if not here then
		return false
	end
	local ahead = pos + dir * c.edge
	local there = workspace:Raycast(ahead + Vector3.new(0, 4, 0), Vector3.new(0, -(16 + c.drop), 0), rp)
	return there ~= nil and there.Position.Y >= here.Position.Y - c.drop
end

-- The swing hit no grass, boss or crawler: is a friend standing where it was aimed? Returns true if one got bonked.
function Funny.bonk(attacker: Player, aim: Vector3, toolRadius: number): boolean
	local c = CFG.bonk
	if not c.on or not started or not free(attacker) then
		return false
	end
	local root = rootOf(attacker)
	if not root then
		return false
	end
	local look = flat(aim)
	look = if look.Magnitude > 0.1 then look.Unit else flat(root.CFrame.LookVector).Unit
	local reach = toolRadius + c.reach
	local minDot = math.cos(math.rad(c.cone))
	local now = os.clock()
	local best, bestD = nil, math.huge
	for _, p in Players:GetPlayers() do
		local r = p ~= attacker and rootOf(p)
		if r then
			local rel = r.Position - root.Position
			local d = flat(rel).Magnitude
			if d <= reach and d < bestD and math.abs(rel.Y) <= c.upDown and (d < 0.5 or flat(rel).Unit:Dot(look) >= minDot) then
				best, bestD = p, d
			end
		end
	end
	if not best then
		return false
	end
	local victim = best :: Player
	local byVictim = pairReady[attacker]
	if not byVictim then
		byVictim = {}
		pairReady[attacker] = byVictim
	end
	if now < (byVictim[victim] or 0) or now < (bonkImmune[victim] or 0) or not free(victim) then
		return false
	end
	byVictim[victim] = now + c.pairCooldown
	bonkImmune[victim] = now + c.immune
	local vr = rootOf(victim) :: BasePart
	local away = flat(vr.Position - root.Position)
	away = if away.Magnitude > 0.1 then away.Unit else look
	local i = math.random(1, #c.words)
	Net.all("Fx", "funnyBonk", {
		pos = vr.Position + Vector3.new(0, 2.5, 0),
		by = attacker.UserId,
		to = victim.UserId,
		word = c.words[i],
		color = c.wordColors[i] or c.wordColors[1],
	})
	if safeAhead(vr.Position, away) then
		Net.send(victim, "Fx", "funnyNudge", { vel = away * c.speed + Vector3.new(0, c.hop, 0) })
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- shredder spit-out
-------------------------------------------------------------------------------------------------------------
-- A real shredder pad: its hopper mouth and coin tray stand apart (the generated world's drop-off pads put the
-- "mouth" straight above the pad: no machine, no hopper).
local function machineOf(pad: any): (Vector3?, Vector3?, Vector3?)
	local mouth, out, pos = pad.mouth, pad.out, pad.pos
	if typeof(mouth) ~= "Vector3" or typeof(out) ~= "Vector3" or typeof(pos) ~= "Vector3" then
		return nil, nil, nil
	end
	if flat(out - mouth).Magnitude < 3 then
		return nil, nil, nil
	end
	return mouth, out, pos
end

-- Where to land in front of the chute: on ground about as high as the pad's, with room to stand, off the sell pad,
-- and a clear line from the chute. nil: no safe spot (they just pop out at the chute).
local function landing(pad: any, start: Vector3, away: Vector3): Vector3?
	local c = CFG.spit
	local rp, op = worldParams()
	local floorY = pad.pos.Y
	for _, ang in { 0, 25, -25, 50, -50 } do
		local dir = CFrame.Angles(0, math.rad(ang), 0):VectorToWorldSpace(away)
		for _, d in c.land do
			local at = start + dir * d
			local ground = workspace:Raycast(Vector3.new(at.X, floorY + 10, at.Z), Vector3.new(0, -22, 0), rp)
			if ground and ground.Normal.Y > 0.7 and math.abs(ground.Position.Y - floorY) <= 4 then
				local spot = ground.Position
				local offPad = flat(spot - pad.pos).Magnitude > (pad.radius or 7) + 2.5
				local room = #workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 3.2, 0)), Vector3.new(3, 5, 3), op) == 0
				local clear = workspace:Raycast(start, spot + Vector3.new(0, 3, 0) - start, rp) == nil
				if offPad and room and clear then
					return spot
				end
			end
		end
	end
	return nil
end

local function spit(p: Player, pad: any, mouth: Vector3, out: Vector3)
	local c = CFG.spit
	local char = p.Character
	local root = rootOf(p)
	if not char or not root then
		return
	end
	spitting[p] = true
	spitReady[p] = os.clock() + c.cooldown
	local away = flat(out - mouth).Unit
	local start = out + away * 2.2 + Vector3.new(0, 2.6, 0)
	local ok, err = pcall(function()
		-- gulp: held inside the hopper (every client hides them)
		root.Anchored = true
		char:PivotTo(CFrame.lookAt(mouth + Vector3.new(0, 1, 0), mouth + Vector3.new(0, 1, 0) + away))
		Net.all("Fx", "funnySpit", { phase = "gulp", id = p.UserId, mouth = mouth, out = out, time = c.gulpTime })
		task.wait(c.gulpTime)
		if p.Character ~= char or not root.Parent then
			return
		end
		local to = landing(pad, start, away)
		char:PivotTo(CFrame.lookAt(start, start + away))
		root.Anchored = false
		Net.send(p, "Fx", "funnyLaunch", { from = start, to = to, apex = c.apex })
		Net.all("Fx", "funnySpit", {
			phase = "spit",
			id = p.UserId,
			mouth = mouth,
			out = out,
			to = to or start,
			word = c.words[math.random(1, #c.words)],
		})
	end)
	-- whatever happened, never leave anyone stuck in the machine
	if root.Parent and root.Anchored then
		root.Anchored = false
	end
	if not ok then
		warn("[Funny] spit: " .. tostring(err))
	end
	task.delay(1.5, function()
		spitting[p] = nil
	end)
end

local function spitTick()
	local c = CFG.spit
	if not c.on then
		return
	end
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local root = rootOf(p)
		if root and now >= (spitReady[p] or 0) and free(p) then
			for _, pad in padList do
				local mouth, out, pos = machineOf(pad)
				if mouth and out and pos then
					local pos3 = root.Position
					local inReach = flat(pos3 - mouth).Magnitude <= c.reach
					if inReach and pos3.Y >= (pos :: Vector3).Y + c.rise and pos3.Y <= mouth.Y + c.above then
						task.spawn(spit, p, pad, mouth, out)
						break
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- start (server/Run.start): `busy(player)` says when a film or the ending holds them; `pads` is the run's
-- info.sellPads (MapStore moves its numbers with the machines, in place)
-------------------------------------------------------------------------------------------------------------
function Funny.start(opts: { busy: ((Player) -> boolean)?, pads: { any }? })
	busyFn = opts.busy
	padList = opts.pads or {}
	if started then
		return
	end
	started = true
	Field.onFell = function(p: any)
		local ok, err = pcall(onFell, p)
		if not ok then
			warn("[Funny] squash: " .. tostring(err))
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok, err = pcall(spitTick)
			if not ok then
				warn("[Funny] shredder: " .. tostring(err))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		squashedUntil[p] = nil
		squashReady[p] = nil
		spitting[p] = nil
		spitReady[p] = nil
		bonkImmune[p] = nil
		pairReady[p] = nil
		for _, t in pairReady do
			t[p] = nil
		end
	end)
end

return Funny
