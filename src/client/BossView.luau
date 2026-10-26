-- The boss on screen (client only; the server only sends where it stands and what it does). Built from the Blender
-- model (ReplicatedStorage.BossModels.<rig>) and its rig (shared/BossRigs): every MeshPart follows its group's
-- idle clip (the designer's "idle" / "idle_rage" motion: breathing, swaying cape leaves, orbiting bees, a circling
-- crow...), and on top of that a springy whole-body pose makes it feel alive (owner's brief: very alive, organic):
--   anticipation (leans back and rises before a hit), a fast strike that overshoots, a slump while it's open,
--   squash and stretch, turning to face its target, leaps in an arc, flinches when you hit it, the rage
--   transformation (staggers, kneels, the rage parts sprout one by one with a small overshoot, colours shift,
--   roars) and the death wilt. The springs are tuned heavy: damping 0.5-0.7 at 1-2 Hz.
-- client/BossVfx, BossCine and BossHud read positions from here (BossView.attWorld, BossView.cframe).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local BossRig = require(Shared:WaitForChild("BossRig"))
local BossMoves = require(Shared:WaitForChild("BossMoves"))

local BossView = {}

type Part = {
	part: BasePart,
	group: string,
	mat: string,
	rage: boolean,
	c: Vector3, -- rest centre (scaled model space)
	rx: Vector3, -- rest axes
	ry: Vector3,
	rz: Vector3,
	size: Vector3,
	grow: number, -- 0..1+ (rage sprout), 1 = full size
	lastSize: Vector3,
	pin: boolean, -- part of the ground platform: stays where the boss first stood (owner, 26 Oct)
}

type Spring = { x: number, v: number, target: number, f: number, d: number }

local view: any = nil -- the boss being shown
local folder = Instance.new("Folder")
folder.Name = "BossView"
folder.Parent = workspace

local function now(): number
	return workspace:GetServerTimeNow()
end

local function spring(x: number, f: number, d: number): Spring
	return { x = x, v = 0, target = x, f = f, d = d }
end

local function stepSpring(s: Spring, dt: number)
	-- semi-implicit damped spring: f = frequency (Hz), d = damping ratio
	local w = 2 * math.pi * s.f
	local a = -2 * s.d * w * s.v - w * w * (s.x - s.target)
	s.v += a * dt
	s.x += s.v * dt
end

local function hex(h: string): Color3
	local ok, c = pcall(Color3.fromHex, h)
	return if ok then c else Color3.new(1, 0, 1)
end

-------------------------------------------------------------------------------------------------------------
-- building
-------------------------------------------------------------------------------------------------------------
local function applyLook(v, p: Part, rage: boolean)
	local looks = v.rig.looks[p.mat]
	local lk = looks and (if rage then looks.r else looks.n)
	if not lk then
		return
	end
	p.part.Color = hex(lk.c)
	pcall(function()
		p.part.Material = (Enum.Material :: any)[lk.m]
	end)
	p.part.Transparency = if p.rage and not v.rageShown then 1 else (lk.t or 0)
end

local function build(rigName: string, scale: number): any?
	local rig = BossRig.load(rigName)
	local models = ReplicatedStorage:FindFirstChild("BossModels")
	local template = models and models:FindFirstChild(rigName)
	if not rig or not template then
		warn("[BossView] missing rig or model: " .. rigName)
		return nil
	end
	local model = template:Clone() :: Model
	model.Name = "Boss_" .. rigName
	model:ScaleTo(scale)
	local pivot = model:GetPivot()
	local byName: { [string]: any } = {}
	for _, info in rig.parts do
		byName[info.n] = info
	end
	local parts: { Part } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local info = byName[d.Name]
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = true
			if info then
				local rel = pivot:ToObjectSpace(d.CFrame)
				-- the ground platform (dirt disc, flowers, reeds, pumpkins, lantern ...) stays put while the boss
				-- moves (owner, 26 Oct): flat or wide pieces of the static group, or ones off to the side
				local c, sz = info.c or { 0, 0, 0 }, info.s or { 0, 0, 0 }
				local top = c[2] + sz[2] / 2
				local wide = math.max(sz[1], sz[3])
				local side = math.sqrt(c[1] * c[1] + c[3] * c[3])
				local pin = info.g == "root" and not info.rage and (top <= 0.9 or wide >= 5 or side >= 2)
				table.insert(parts, {
					part = d,
					group = info.g,
					mat = info.mat,
					rage = info.rage == true,
					c = rel.Position,
					rx = rel.XVector,
					ry = rel.YVector,
					rz = rel.ZVector,
					size = d.Size,
					grow = if info.rage then 0 else 1,
					lastSize = d.Size,
					pin = pin,
				})
			end
		end
	end
	-- the attachment points, in scaled model space
	local atts: { [string]: { g: string, p: Vector3 } } = {}
	for _, a in rig.atts do
		if not atts[a.n] then
			atts[a.n] = { g = a.g, p = Vector3.new(a.p[1], a.p[2], a.p[3]) * scale }
		end
	end
	local groups: { string } = {}
	for g in rig.groups do
		table.insert(groups, g)
	end
	local v = {
		rigName = rigName,
		rig = rig,
		model = model,
		parts = parts,
		atts = atts,
		groups = groups,
		scale = scale,
		height = (rig.bounds[2][2] or 7) * scale,
		cf = CFrame.new(),
		yaw = 0,
		pos = Vector3.zero,
		rageShown = false,
		clip = "idle",
		clipBlend = 0, -- 0 = idle clip, 1 = rage clip
		clipT = math.random() * 3,
		deltas = {} :: { [string]: { number } },
		-- the whole-body pose springs (heavy body: damping 0.55 at 1.6 Hz; quick bits faster)
		pitch = spring(0, 1.7, 0.55), -- lean forward (+) / back (-), radians
		roll = spring(0, 1.6, 0.5),
		twist = spring(0, 1.4, 0.6),
		squash = spring(1, 2.4, 0.42), -- height factor (width = 1/sqrt)
		lift = spring(0, 1.8, 0.6), -- studs up
		fwd = spring(0, 1.8, 0.6), -- studs forward
		size = spring(1, 2.2, 0.5), -- whole-model scale (intros / death)
		shake = 0, -- studs of jitter, decays
		action = nil :: any,
		leap = nil :: any,
		openUntil = 0,
		alpha = 1,
	}
	for _, p in parts do
		applyLook(v, p, false)
	end
	model.Parent = folder
	return v
end

-------------------------------------------------------------------------------------------------------------
-- actions: a short timeline that sets the pose springs' targets (the springs give the overshoot and follow-
-- through); t is seconds since the action started. Each returns true while running.
-------------------------------------------------------------------------------------------------------------
local ACTIONS: { [string]: (any, number, any) -> boolean } = {}

local function set(v, pitch: number?, squash: number?, lift: number?, fwd: number?, twist: number?, roll: number?)
	if pitch then
		v.pitch.target = pitch
	end
	if squash then
		v.squash.target = squash
	end
	if lift then
		v.lift.target = lift * v.scale / 5
	end
	if fwd then
		v.fwd.target = fwd * v.scale / 5
	end
	if twist then
		v.twist.target = twist
	end
	if roll then
		v.roll.target = roll
	end
end

local function rest(v)
	set(v, 0, 1, 0, 0, 0, 0)
end

-- a hit that lands at `a.land` (slam / sweep): rear back 70% of the warning, snap down on the frame, slump if open
ACTIONS.strike = function(v, t, a)
	local land = a.land
	if t < land * 0.7 then
		local k = t / (land * 0.7)
		set(v, -0.22 * k, 1 + 0.1 * k, 1.5 * k, -1 * k, (a.twist or 0) * -k)
	elseif t < land - 0.1 then
		set(v, -0.26, 1.12, 2, -1.2, -(a.twist or 0)) -- the held telegraph
		v.shake = math.max(v.shake, 0.08 * v.scale / 5)
	elseif t < land + 0.25 then
		-- accelerate into contact: the springs are kicked so the last frames move the most
		v.pitch.v += (0.45 - v.pitch.x) * 20 * (1 / 60)
		set(v, 0.34, 0.84, -1, 3, a.twist or 0)
	elseif t < land + (a.open or 0) then
		set(v, 0.24, 0.88, -1.5, 2, (a.twist or 0) * 0.5, 0.05) -- stuck: slumped forward, weak spot low
	elseif t < land + (a.open or 0) + 0.8 then
		rest(v)
	else
		return false
	end
	return true
end

-- many drops: rears up and shakes while they fall
ACTIONS.volley = function(v, t, a)
	if t < 0.5 then
		set(v, -0.3, 1.14, 2)
	elseif t < a.land then
		set(v, -0.2 + math.sin(t * 9) * 0.05, 1.08, 1.5, 0, math.sin(t * 5) * 0.15)
		v.shake = math.max(v.shake, 0.05 * v.scale / 5)
	elseif t < a.land + 0.6 then
		rest(v)
	else
		return false
	end
	return true
end

-- a stomp round itself: crouches, springs up, slams down
ACTIONS.stomp = function(v, t, a)
	local land = a.land
	if t < land - 0.35 then
		set(v, 0.05, 0.8, -1)
	elseif t < land - 0.05 then
		set(v, -0.1, 1.2, 4)
	elseif t < land + 0.4 then
		set(v, 0.08, 0.78, -1.2)
	elseif t < land + 1 then
		rest(v)
	else
		return false
	end
	return true
end

-- a leap: crouch (anticipation), stretch in the air, squash on landing, slump while open
ACTIONS.leap = function(v, t, a)
	local airAt = a.land - a.air
	if t < airAt then
		set(v, 0.12, 0.78, -1, 0)
	elseif t < a.land then
		set(v, -0.15, 1.18, 0, 0)
	elseif t < a.land + 0.3 then
		set(v, 0.2, 0.74, -1.4, 0)
	elseif t < a.land + (a.open or 0) then
		set(v, 0.22, 0.9, -1.2, 1.5, 0, -0.05)
	elseif t < a.land + (a.open or 0) + 0.8 then
		rest(v)
	else
		return false
	end
	return true
end

-- the rage transformation (client/BossCine films it): stagger, kneel, sprout, roar, settle
ACTIONS.rage = function(v, t, _a)
	if t < 1 then
		set(v, -0.3, 1.05, 0, -2, 0, math.sin(t * 7) * 0.12)
	elseif t < 2.2 then
		set(v, 0.32, 0.76, -2, 1, 0, math.sin(t * 11) * 0.05)
		v.shake = math.max(v.shake, 0.06 * v.scale / 5)
	elseif t < 3.3 then
		BossView.sprout(t - 2.2)
		set(v, 0.15, 0.85, -1)
		v.shake = math.max(v.shake, 0.1 * v.scale / 5)
	elseif t < 4.3 then
		BossView.sprout(2)
		set(v, -0.4, 1.18, 3, -1)
		v.shake = math.max(v.shake, 0.22 * v.scale / 5)
	elseif t < 5.2 then
		rest(v)
	else
		return false
	end
	return true
end

-- death: freezes, reels, wilts down and shrinks away
ACTIONS.death = function(v, t, a)
	local len = a.len or 3.2
	if t < 0.5 then
		set(v, -0.25, 1.06, 1, -1, 0, 0.1)
		v.shake = math.max(v.shake, 0.15 * v.scale / 5)
	elseif t < len - 0.7 then
		local k = (t - 0.5) / (len - 1.2)
		set(v, 0.25 + 0.4 * k, 0.9 - 0.25 * k, -6 * k, 2 * k, 0, math.sin(t * 3) * 0.12 * (1 - k))
		v.shake = math.max(v.shake, 0.06 * (1 - k) * v.scale / 5)
	else
		v.size.target = 0.02
		v.size.f = 2.5
		v.size.d = 0.9
	end
	return t < len + 0.5
end

-- digs into the floor and stays under (Shell Ambush) until "erupt"
ACTIONS.burrow = function(v, t, a)
	if t < 0.8 then
		set(v, 0.25, 0.8, 0)
		v.lift.target = -v.height * 1.1 * (t / 0.8)
		v.shake = math.max(v.shake, 0.12 * v.scale / 5)
	else
		v.lift.target = -v.height * 1.1
	end
	return t < (a.len or 4)
end

-- bursts out of the floor at `a.land`
ACTIONS.erupt = function(v, t, a)
	local land = a.land or 1
	if t < land - 0.45 then
		v.lift.x = math.min(v.lift.x, -v.height * 1.05)
		v.lift.target = -v.height * 1.05
		v.shake = math.max(v.shake, 0.1 * v.scale / 5)
	elseif t < land + 0.4 then
		v.lift.target = 0
		set(v, -0.2, 1.2)
	elseif t < land + (a.open or 0) + 0.3 then
		set(v, 0.22, 0.86, nil, 1, 0, 0.05)
	elseif t < land + (a.open or 0) + 1 then
		rest(v)
	else
		return false
	end
	return true
end

-- turns with its beam (Crown Spin): leans out, wobbles
ACTIONS.spin = function(v, t, a)
	local land = a.land or 1
	if t < land then
		set(v, -0.15, 1.1, 1.5)
	elseif t < land + (a.len or 5) then
		set(v, 0.12, 0.95, 0, 1, 0, math.sin(t * 6) * 0.08)
		v.shake = math.max(v.shake, 0.03 * v.scale / 5)
	elseif t < land + (a.len or 5) + 0.8 then
		rest(v)
	else
		return false
	end
	return true
end

-- stares its target down (lasers, the Titan's gaze): leans in, trembles, recoils when it fires
ACTIONS.aim = function(v, t, a)
	local land = a.land or 1
	if t < land then
		set(v, 0.15, 1.05, 1, 1.5)
		v.shake = math.max(v.shake, 0.05 * v.scale / 5 * math.min(1, t / land))
	elseif t < land + 0.35 then
		set(v, -0.3, 1.1, 1, -2)
	elseif t < land + (a.open or 0) + 0.3 then
		set(v, 0.22, 0.88, -1.2, 1.5, 0, 0.05)
	elseif t < land + (a.open or 0) + 1 then
		rest(v)
	else
		return false
	end
	return true
end

-- a charge (Hellfire Dash): crouches low, shoots forward, skids
ACTIONS.dash = function(v, t, a)
	local land = a.land or 1
	if t < land - 0.3 then
		set(v, 0.3, 0.8, -1, -1.5)
	elseif t < land then
		set(v, 0.45, 0.9, 0, 3)
	elseif t < land + 0.4 then
		set(v, -0.2, 1.05, 0, 1)
	elseif t < land + (a.open or 0) then
		set(v, 0.22, 0.9, -1.2, 1.5, 0, -0.05)
	elseif t < land + (a.open or 0) + 0.8 then
		rest(v)
	else
		return false
	end
	return true
end

-- the intro: rises out of the ground (or blooms from nothing) with an overshoot, then a roar
ACTIONS.intro = function(v, t, a)
	local len = a.len or 8
	local kind = a.kind or "rise"
	local riseEnd = math.min(len * 0.45, 3.4)
	if kind == "burst" or kind == "bloom" then
		if t < 0.3 then
			v.size.x = 0.05
			v.size.target = 0.05
		elseif t < riseEnd then
			v.size.target = 1
		end
		set(v, 0, if t < riseEnd then 0.9 else 1)
	else
		if t < 0.05 then
			v.lift.x = -v.height * 1.05
		end
		if t < riseEnd then
			v.lift.target = -v.height * 1.05 * (1 - t / riseEnd)
			v.shake = math.max(v.shake, 0.12 * v.scale / 5)
			if kind == "surface" then
				v.roll.target = math.sin(t * 4) * 0.1
			end
		elseif t < riseEnd + 0.4 then
			v.lift.target = 0
			v.roll.target = 0
		end
	end
	if t >= riseEnd + 0.4 and t < riseEnd + 1.2 then
		set(v, 0.12, 0.84) -- gathers breath
	elseif t >= riseEnd + 1.2 and t < len - 0.6 then
		set(v, -0.32, 1.15, 2, -1) -- the roar
		v.shake = math.max(v.shake, 0.18 * v.scale / 5)
	elseif t >= len - 0.6 then
		rest(v)
	end
	return t < len + 0.4
end

-- The critters react: "intro" or "rage", for `len` s.
function BossView.critters(kind: string, len: number)
	if view and len > 0.5 then
		view.crit = { kind = kind, start = os.clock(), len = len }
	end
end

function BossView.act(name: string, args: any?)
	if not view then
		return
	end
	view.action = { name = name, start = os.clock(), args = args or {} }
end

-------------------------------------------------------------------------------------------------------------
-- the rage parts sprout one by one over `k` = 0..1 s (each grows from its own middle with a small overshoot)
-------------------------------------------------------------------------------------------------------------
function BossView.sprout(k: number)
	local v = view
	if not v then
		return
	end
	if not v.rageShown then
		v.rageShown = true
		for _, p in v.parts do
			applyLook(v, p, true)
		end
		v.clip = "rage"
	end
	local list = v.rageList
	if not list then
		list = {}
		for _, p in v.parts do
			if p.rage then
				table.insert(list, p)
			end
		end
		v.rageList = list
	end
	local n = #list
	for i, p in list do
		local start = (i - 1) / math.max(1, n) * 0.75
		local u = math.clamp((k - start) / 0.3, 0, 1)
		-- ease out back: 0 -> 1.12 -> 1
		local s = 1.7
		local e = 1 + (s + 1) * (u - 1) ^ 3 + s * (u - 1) ^ 2
		p.grow = if u <= 0 then 0 else e
	end
end

-- straight to the rage form (late joiners, skipped cutscenes)
function BossView.rageNow()
	BossView.sprout(2)
end

-------------------------------------------------------------------------------------------------------------
-- per frame
-------------------------------------------------------------------------------------------------------------
local cfs: { CFrame } = {}
local list: { BasePart } = {}
local tmp = table.create(12, 0)
local tmp2 = table.create(12, 0)

-- the boss's world CFrame (feet), with the leap arc
local function placement(v, dt: number): CFrame
	local lp = v.leap
	if lp then
		local t = now() - lp.start
		if t >= lp.len + 0.05 then
			v.leap = nil
			v.pos = lp.to.Position
		else
			local u = math.clamp(t / lp.len, 0, 1)
			local p = lp.from.Position:Lerp(lp.to.Position, u)
			local h = lp.height * 4 * u * (1 - u)
			v.pos = p + Vector3.new(0, h, 0)
		end
	end
	-- turn towards the target facing (a quick but soft spring)
	local target = v.targetCf or v.cf
	if not v.leap then
		v.pos = v.pos:Lerp(target.Position, math.min(1, dt * 6))
	end
	local look = target.LookVector
	local want = math.atan2(-look.X, -look.Z)
	local diff = (want - v.yaw + math.pi) % (2 * math.pi) - math.pi
	v.yaw += diff * math.min(1, dt * 4.5)
	return CFrame.new(v.pos) * CFrame.Angles(0, v.yaw, 0)
end

-- The critters on the models (gnome, bees, crows, butterflies) react in the cutscenes (owner, round 2): returns a
-- turn about the boss's middle and a shift (model space, studs) for group g.
local CRITTERS = {
	gnome = "gnome",
	bee_ = "bee",
	crow_flying = "crow",
	butterfly_ = "butterfly",
}
local function critterKind(g: string): string?
	for prefix, kind in CRITTERS do
		if string.sub(g, 1, #prefix) == prefix then
			return kind
		end
	end
	return nil
end

local function critter(v, g: string): (number, Vector3)
	local c = v.crit
	local kind = critterKind(g)
	if not c or not kind then
		return 0, Vector3.zero
	end
	local t = os.clock() - c.start
	if t > c.len then
		v.crit = nil
		return 0, Vector3.zero
	end
	local u = t / c.len
	local S = v.scale
	local seed = (#g * 1.7) % 3
	local function bell(a: number, b: number): number -- 0 -> 1 -> 0 between a and b (u)
		if u <= a or u >= b then
			return 0
		end
		local k = (u - a) / (b - a)
		return math.sin(k * math.pi) ^ 0.6
	end
	if kind == "gnome" then
		-- runs off to the side as the king rises (or rages), peeks back at the end
		local away = if c.kind == "rage" then bell(0.02, 0.98) else bell(0.05, 0.85)
		local hop = math.abs(math.sin(t * 14)) * 0.35 * away
		return 0, Vector3.new(away * 5.5 * S, hop * S, away * 2 * S)
	elseif kind == "bee" then
		-- the swarm spins out wide and fast round the boss, then settles back
		local k = if c.kind == "rage" then bell(0.0, 1.0) else bell(0.1, 0.9)
		return t * 5 * k, Vector3.new(0, (math.sin(t * 6 + seed) * 0.8 + 1.2) * k * S, 0)
	elseif kind == "crow" then
		-- flaps up and away in fright, circles, comes back down
		local k = bell(0.0, 1.0)
		return t * 2.2 * k, Vector3.new(0, 6 * k * S, 0)
	else
		-- butterflies scatter up and out, flutter, return
		local k = bell(0.0, 1.0)
		return t * 1.4 * k, Vector3.new(math.sin(t * 9 + seed) * 0.4 * k * S, (3 + math.sin(t * 7 + seed)) * k * S, 0)
	end
end

local function step(dt: number)
	local v = view
	if not v or not v.model.Parent then
		return
	end
	dt = math.min(dt, 1 / 20)
	-- action timeline
	local a = v.action
	if a then
		local fn = ACTIONS[a.name]
		if not fn or not fn(v, os.clock() - a.start, a.args) then
			v.action = nil
			rest(v)
		end
	end
	for _, s in { v.pitch, v.roll, v.twist, v.squash, v.lift, v.fwd, v.size } do
		stepSpring(s, dt)
	end
	v.shake = math.max(0, v.shake - dt * 0.6 * v.scale / 5)
	-- clips: idle / rage, cross-faded
	v.clipT += dt
	local want = if v.clip == "rage" then 1 else 0
	v.clipBlend += math.clamp(want - v.clipBlend, -dt / 0.6, dt / 0.6)
	local base = placement(v, dt)
	-- the overlay: about the feet, squash keeps the volume
	local sy = v.squash.x
	local sxz = 1 / math.sqrt(math.max(0.3, sy))
	local sz = v.size.x
	local jitter = if v.shake > 0 then Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * v.shake * 2 else Vector3.zero
	local overlay = CFrame.new(Vector3.new(0, v.lift.x, -v.fwd.x) + jitter)
		* CFrame.Angles(-v.pitch.x, v.twist.x, v.roll.x)
	local O = overlay
	local ox, oy, oz = O.XVector * sxz * sz, O.YVector * sy * sz, O.ZVector * sxz * sz
	local op = O.Position
	-- per group: G = overlay * clip delta (affine, translation in studs)
	local G: { [string]: { Vector3 } } = {}
	local clips = v.rig.clips
	for _, g in v.groups do
		local d = BossRig.sample(clips.idle, g, v.clipT, tmp)
		if v.clipBlend > 0 then
			local r = BossRig.sample(clips.rage, g, v.clipT, tmp2)
			local k = v.clipBlend
			for i = 1, 12 do
				d[i] = d[i] + (r[i] - d[i]) * k
			end
		end
		-- columns of the clip's 3x3 and its translation (scaled to studs)
		local cx = Vector3.new(d[1], d[5], d[9])
		local cy = Vector3.new(d[2], d[6], d[10])
		local cz = Vector3.new(d[3], d[7], d[11])
		local ct = Vector3.new(d[4], d[8], d[12]) * v.scale
		-- overlay applied after: column' = O3 * column
		local function o3(c: Vector3): Vector3
			return ox * c.X + oy * c.Y + oz * c.Z
		end
		local col = { o3(cx), o3(cy), o3(cz), o3(ct) + op }
		if v.crit then
			local yaw, off = critter(v, g)
			if yaw ~= 0 then
				local R = CFrame.Angles(0, yaw, 0)
				col = { R:VectorToWorldSpace(col[1]), R:VectorToWorldSpace(col[2]), R:VectorToWorldSpace(col[3]), R:VectorToWorldSpace(col[4]) }
			end
			col[4] += off
		end
		G[g] = col
	end
	-- the static parts (the ground disc and whatever no clip moves) stay put under the boss: no lean, no squash
	G.root = G.root or { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis, Vector3.zero }
	v.G = G
	local n = 0
	local home = v.home or base
	for _, p in v.parts do
		local g = G[p.group]
		if p.pin then
			n += 1
			list[n] = p.part
			cfs[n] = home * CFrame.fromMatrix(p.c, p.rx, p.ry, p.rz)
		elseif g and p.grow > 0.001 then
			local ax, ay, az, at = g[1], g[2], g[3], g[4]
			local c = p.c
			local centre = ax * c.X + ay * c.Y + az * c.Z + at
			local x = ax * p.rx.X + ay * p.rx.Y + az * p.rx.Z
			local y = ax * p.ry.X + ay * p.ry.Y + az * p.ry.Z
			local z = ax * p.rz.X + ay * p.rz.Y + az * p.rz.Z
			local lx, ly, lz = x.Magnitude, y.Magnitude, z.Magnitude
			local size = Vector3.new(p.size.X * lx, p.size.Y * ly, p.size.Z * lz) * p.grow
			if (size - p.lastSize).Magnitude > 0.004 * p.size.Magnitude then
				p.part.Size = size
				p.lastSize = size
			end
			local ux = x / lx
			local uz = ux:Cross(y).Unit
			local uy = uz:Cross(ux)
			n += 1
			list[n] = p.part
			cfs[n] = base * CFrame.fromMatrix(centre, ux, uy, uz)
		elseif p.grow <= 0.001 and p.lastSize.Magnitude > 0 then
			p.part.Size = Vector3.one * 0.01
			p.lastSize = Vector3.zero
		end
	end
	for i = n + 1, #list do
		list[i] = nil
		cfs[i] = nil
	end
	workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	v.base = base
end

RunService.RenderStepped:Connect(function(dt)
	local ok, err = pcall(step, dt)
	if not ok and view then
		warn("[BossView] " .. tostring(err))
		view.errors = (view.errors or 0) + 1
		if view.errors > 20 then
			BossView.hide()
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- public
-------------------------------------------------------------------------------------------------------------
-- Show the boss `rig` standing at `cf` (feet, facing) at `scale`.
function BossView.show(rig: string, cf: CFrame, scale: number)
	if view and view.rigName == rig and math.abs(view.scale - scale) < 0.01 then
		view.targetCf = cf
		return view
	end
	BossView.hide()
	local v = build(rig, scale)
	if not v then
		return nil
	end
	v.cf = cf
	v.targetCf = cf
	v.pos = cf.Position
	local look = cf.LookVector
	v.yaw = math.atan2(-look.X, -look.Z)
	v.home = CFrame.new(cf.Position) * CFrame.Angles(0, v.yaw, 0)
	view = v
	return v
end

function BossView.hide()
	if view then
		view.model:Destroy()
		view = nil
	end
end

function BossView.get(): any
	return view
end

-- the server moved / turned it
function BossView.setTarget(cf: CFrame)
	if view then
		view.targetCf = cf
	end
end

-- a leap from -> to, in the air from server time `start` for `len` s
function BossView.leap(from: CFrame, to: CFrame, start: number, len: number, height: number?)
	if view then
		local dist = (to.Position - from.Position).Magnitude
		view.leap = { from = from, to = to, start = start, len = len, height = height or math.clamp(dist * 0.45, 8, 30) }
		view.targetCf = to
	end
end

-- where the ground platform stays (late joiners: the boss may have moved off it)
function BossView.setHome(cf: CFrame)
	if view then
		local look = cf.LookVector
		view.home = CFrame.new(cf.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
	end
end

-- jump straight to a spot (it was underground: the Shell Ambush)
function BossView.teleport(cf: CFrame)
	if view then
		view.leap = nil
		view.targetCf = cf
		view.pos = cf.Position
	end
end

-- a flinch when a blow lands (bigger on a weak-spot hit)
function BossView.flinch(big: boolean)
	local v = view
	if not v then
		return
	end
	v.pitch.v -= if big then 1.6 else 0.7
	v.squash.v -= if big then 1.2 else 0.5
	v.shake = math.max(v.shake, (if big then 0.2 else 0.08) * v.scale / 5)
end

-- the world position of an attachment point (att_eye, att_scepter_core ...), following its group
function BossView.attWorld(name: string): Vector3?
	local v = view
	if not v or not v.base or not v.G then
		return nil
	end
	local a = v.atts[name]
	if not a then
		return nil
	end
	local g = v.G[a.g] or v.G[next(v.G) :: string]
	if not g then
		return nil
	end
	local p = a.p
	return v.base * (g[1] * p.X + g[2] * p.Y + g[3] * p.Z + g[4])
end

-- every point of a name (att_eye, att_eye_2, att_eye_3 ...)
function BossView.attAll(prefix: string): { string }
	local out = {}
	local v = view
	if v then
		for n in v.atts do
			if n == prefix or n:sub(1, #prefix + 1) == prefix .. "_" then
				table.insert(out, n)
			end
		end
		table.sort(out)
	end
	return out
end

function BossView.cframe(): CFrame?
	return view and view.base
end

function BossView.height(): number
	return if view then view.height else 0
end

-- the weak spot's attachment for this rig
function BossView.weakName(z: number): string
	return BossMoves.get(z).weak
end

return BossView
