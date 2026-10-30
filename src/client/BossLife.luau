-- client/BossLife (30 Oct, owner: "the bosses are very stiff and dont do alot they are just a statue fix it"): a
-- life of their own for the ForgeGUI bosses (rig.solid). The first ones were body and ground disc in one mesh on
-- another account, so nothing could move by itself; the owner then asked for moving arms too ("ik heb het ook over
-- de armen"), so the bosses are being remade on our own account cut into pieces (a jointed boss: head, arms, body,
-- disc; see "jointed bosses" below). client/BossView moves the whole model for the moves (rears back, strikes,
-- leaps ...). On top of that, every frame:
--   * it breathes: the body swells and settles (quicker and shakier in its rage)
--   * it is never quite still: a slow sway from side to side and back to front
--   * it walks: when the server moves or turns it (server/Boss: between moves it prowls towards a fighter) it rocks
--     from one side of its disc to the other, leaning into the way it goes, with a thud and a puff of dust each
--     time a side comes down (the bog slime hops along instead)
--   * it watches the fighter nearest to it, turning its bulk towards them
--   * every few seconds between moves it does something: growls, looks round, stomps, shakes itself, hops - each
--     boss in its own way (FEEL)
--   * a hit makes it shudder (a big one makes it cry out)
--   * a jointed boss also swings its arms as it walks, raises its fists over its head before a hit and slams them
--     down, throws them wide to roar, turns its head to watch you, and keeps its disc flat on the ground
-- Every lean rocks a one-piece model on its disc's rim (BossLife.rim) so the disc never sinks into the floor or floats.
-- BossView calls BossLife.step(v, dt) every frame for a rig.solid boss and adds what it returns to its pose.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local FxIds = require(Shared:WaitForChild("BossFxIds"))

local BossLife = {}

local TAU = 2 * math.pi

-- How each boss carries itself (by rig):
--   fidgets: how often it picks each thing to do between moves (FIDGETS below)
--   waddle: how far it rocks per step (radians); stride: steps per second at a walk; hop: it hops along instead
--   breath: breaths per second; sway: how far it sways standing (radians); twitch: small nervous jerks (0 = none)
--   voice: its growl's pitch (lower = bigger)
local DEFAULT = { fidgets = { look = 2, growl = 2, stomp = 1 }, waddle = 0.1, stride = 1.4, breath = 0.32, sway = 0.04, twitch = 0, voice = 0.9 }
local FEEL: { [string]: any } = {
	-- the Dandelion King: proud, looks round his valley, a royal growl
	dandelion = { fidgets = { look = 3, growl = 2, shake = 1, stomp = 1 }, waddle = 0.09, stride = 1.5, breath = 0.32, sway = 0.035, twitch = 0, voice = 0.95 },
	-- the Harvest Reaper: a scarecrow that twitches and jerks its head round
	harvest = { fidgets = { look = 3, shake = 2, growl = 1 }, waddle = 0.11, stride = 1.7, breath = 0.28, sway = 0.05, twitch = 0.7, voice = 1.1 },
	-- the sakura spirit: light on its feet, sways a lot
	sakura = { fidgets = { look = 3, growl = 1, shake = 1, hop = 1 }, waddle = 0.07, stride = 1.5, breath = 0.27, sway = 0.045, twitch = 0, voice = 1.15 },
	-- the bramble golem: heavy, stomps
	bramble = { fidgets = { stomp = 3, growl = 2, look = 1 }, waddle = 0.13, stride = 1.2, breath = 0.34, sway = 0.03, twitch = 0, voice = 0.8 },
	-- the bog slime: wobbles, hops
	bog = { fidgets = { hop = 3, shake = 2, growl = 1 }, waddle = 0.05, stride = 1.6, hop = true, breath = 0.45, sway = 0.03, twitch = 0, voice = 0.75 },
	-- the bunker beast (the Frost Thornback): heavy, stomps and snorts
	bunker = { fidgets = { stomp = 2, growl = 2, shake = 1 }, waddle = 0.12, stride = 1.25, breath = 0.33, sway = 0.03, twitch = 0, voice = 0.85 },
	-- the hollow one: creepy, jerky
	hollow = { fidgets = { shake = 2, look = 2, growl = 2 }, waddle = 0.1, stride = 1.4, breath = 0.3, sway = 0.05, twitch = 0.9, voice = 0.9 },
	-- the jungle titan: the biggest and slowest, the ground shakes
	jungle = { fidgets = { stomp = 3, growl = 2, look = 1 }, waddle = 0.12, stride = 1.1, breath = 0.3, sway = 0.03, twitch = 0, voice = 0.7 },
}
BossLife.FEEL = FEEL

-- How far the moves lean and squash a one-piece boss (29 Oct it was 0.35 and 0.5 so the disc stayed flat on the
-- floor; now it rocks on the disc's rim, so it can rear back and throw itself into a hit)
BossLife.SOFT = 0.6
BossLife.SQUASH = 0.7

-- 0 before a, rises to 1 by b, holds until c, back to 0 by d (smooth)
local function env(u: number, a: number, b: number, c: number, d: number): number
	if u <= a or u >= d then
		return 0
	elseif u < b then
		local k = (u - a) / (b - a)
		return k * k * (3 - 2 * k)
	elseif u <= c then
		return 1
	end
	local k = (d - u) / (d - c)
	return k * k * (3 - 2 * k)
end

-- What it does between moves: f(u, side) -> pitch (+ = leans forward), roll (+ = rocks onto its -X side), twist,
-- lift (studs at the usual scale), squash (+ = taller), jump (studs: the whole boss, disc and all, leaves the
-- floor). `len` s long; `hit` = when it comes down (a thud and dust), `voice` = when it growls.
-- A jointed boss (its arms and head move: BossLife.setup) also plays `limbs(u, side)` -> its left and right arm's
-- swing (radians, + = forward and up), how far both arms spread out, the head's turn and its nod (+ = down).
local FIDGETS: { [string]: any } = {
	-- rears back, then leans in low and rumbles at you (arms thrown wide, head up for the roar)
	growl = {
		len = 1.9,
		voice = 0.4,
		f = function(u: number, _side: number)
			local back, lean = env(u, 0, 0.35, 0.4, 0.62), env(u, 0.42, 0.62, 1.35, 1.9)
			local shiver = math.sin(u * 34) * 0.022 * env(u, 0.55, 0.7, 1.3, 1.6)
			return -0.1 * back + 0.15 * lean, shiver, shiver * 0.6, 0.4 * back, 0.05 * back - 0.06 * lean, 0
		end,
		limbs = function(u: number, _side: number)
			local back, lean = env(u, 0, 0.35, 0.4, 0.62), env(u, 0.42, 0.62, 1.35, 1.9)
			local arms = 0.9 * back + 0.5 * lean
			return arms, arms, 0.7 * lean + 0.3 * back, 0, -0.35 * back + 0.2 * lean
		end,
	},
	-- turns its bulk to one side, peers, then to the other (a jointed boss turns its head instead)
	look = {
		len = 2.6,
		f = function(u: number, side: number)
			local one, other = env(u, 0, 0.5, 0.9, 1.3), env(u, 1.2, 1.7, 2.1, 2.6)
			return 0.05 * env(u, 0, 0.4, 2.1, 2.6), 0.025 * side * (one - other), 0.42 * side * (one - other), 0, 0, 0
		end,
		limbs = function(u: number, side: number)
			local one, other = env(u, 0, 0.5, 0.9, 1.3), env(u, 1.2, 1.7, 2.1, 2.6)
			return 0.1 * (one + other), 0.1 * (one + other), 0, 0.55 * side * (one - other), 0.12 * (one + other)
		end,
	},
	-- lifts one side high and slams it down (a jointed boss raises both fists and pounds the ground)
	stomp = {
		len = 1.35,
		hit = 0.47,
		f = function(u: number, side: number)
			local up, slam = env(u, 0, 0.36, 0.38, 0.47), env(u, 0.45, 0.5, 0.62, 1.1)
			return -0.03 * up + 0.06 * slam, 0.13 * side * up, 0.04 * side * up, 0.9 * up, 0.06 * up - 0.13 * slam, 0
		end,
		limbs = function(u: number, _side: number)
			local up, slam = env(u, 0, 0.36, 0.38, 0.47), env(u, 0.45, 0.5, 0.62, 1.1)
			return 2.3 * up + 0.5 * slam, 2.3 * up + 0.5 * slam, 0.25 * up, 0, -0.2 * up + 0.3 * slam
		end,
	},
	-- shakes itself like a wet dog (arms flailing)
	shake = {
		len = 1.25,
		f = function(u: number, _side: number)
			local e = env(u, 0, 0.15, 0.8, 1.25)
			return 0.02 * e, 0.09 * math.sin(u * TAU * 4.6) * e, 0.06 * math.sin(u * TAU * 4.6 + 1.1) * e, 0.2 * e, 0.03 * e, 0
		end,
		limbs = function(u: number, _side: number)
			local e = env(u, 0, 0.15, 0.8, 1.25)
			local w = math.sin(u * TAU * 4.6)
			return 0.5 * w * e, -0.5 * w * e, 0.45 * e, 0.3 * math.sin(u * TAU * 4.6 + 0.6) * e, 0
		end,
	},
	-- crouches, jumps, lands (arms flung up in the air)
	hop = {
		len = 1.2,
		hit = 0.72,
		f = function(u: number, _side: number)
			local crouch = env(u, 0, 0.2, 0.24, 0.32)
			local air = if u > 0.3 and u < 0.72 then math.sin((u - 0.3) / 0.42 * math.pi) else 0
			local land = env(u, 0.7, 0.76, 0.84, 1.15)
			return 0.06 * crouch - 0.05 * air + 0.07 * land, 0, 0, 0, -0.13 * crouch + 0.1 * air - 0.16 * land, 3.2 * air
		end,
		limbs = function(u: number, _side: number)
			local air = if u > 0.3 and u < 0.72 then math.sin((u - 0.3) / 0.42 * math.pi) else 0
			local land = env(u, 0.7, 0.76, 0.84, 1.15)
			return 2 * air, 2 * air, 0.5 * air + 0.3 * land, 0, -0.25 * air + 0.25 * land
		end,
	},
}
BossLife.FIDGETS = FIDGETS

-------------------------------------------------------------------------------------------------------------
-- its sounds and dust (an attachment in the Terrain that follows it; gone with its model)
-------------------------------------------------------------------------------------------------------------
local function sfxGroup(): SoundGroup?
	local g = SoundService:FindFirstChild("MowALawnSfx")
	return if g and g:IsA("SoundGroup") then g else nil
end

local function makeSound(parent: Instance, key: string, volume: number, speed: number): Sound?
	local def = (Config :: any).FILM_SOUNDS and (Config :: any).FILM_SOUNDS[key]
	if not def or not def.id or def.id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Life_" .. key
	s.SoundId = def.id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 30
	s.RollOffMaxDistance = 260
	s.SoundGroup = sfxGroup()
	s.Parent = parent
	return s
end

local function makeDust(parent: Instance, S: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "StepDust"
	e.Texture = FxIds.smoke or ""
	e.Color = ColorSequence.new(Color3.fromRGB(182, 162, 126), Color3.fromRGB(138, 126, 104))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * S), NumberSequenceKeypoint.new(1, 5.5 * S) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.6, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(5 * S, 10 * S)
	e.SpreadAngle = Vector2.new(80, 80)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 1.5 * S, 0)
	e.Drag = 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Rate = 0
	e.Parent = parent
	return e
end

-- the fight is on (not a film, not the intro): only then does it watch people and fidget
local mirror: Instance? = nil
local function fighting(): boolean
	if not mirror then
		mirror = ReplicatedStorage:FindFirstChild("MowALawnBoss")
		if not mirror then
			return false
		end
	end
	local m = mirror :: Instance
	return m:GetAttribute("Active") == true and m:GetAttribute("State") == "fight"
end

local function start(v: any): any
	local b = v.rig.bounds and v.rig.bounds[2] or { 3.5, 7, 3.5 }
	local S = v.scale / 5
	local feel = FEEL[v.rigName] or DEFAULT
	local att = Instance.new("Attachment")
	att.Name = "BossLife"
	att.WorldPosition = v.pos
	att.Parent = workspace.Terrain
	local L = {
		feel = feel,
		S = S,
		rimR = math.max(b[1], b[3]) * v.scale * 0.85, -- the disc's radius (a little inside the model's bounds)
		seed = math.random() * 10,
		t = 0,
		lastPos = v.pos,
		lastYaw = v.yaw,
		speed = 0,
		turn = 0,
		gait = 0,
		phase = 0,
		breath = math.random() * TAU,
		idle = 0,
		alive = 1,
		look = 0,
		lookV = 0,
		lookWant = 0,
		lookAt = 0,
		fid = nil :: string?,
		fidT = 0,
		fidSide = 1,
		fidVoice = false,
		fidHit = false,
		nextFid = 1.5 + math.random() * 2,
		jerkR = 0,
		jerkT = 0,
		nextJerk = 1 + math.random() * 2,
		quake = 0,
		hurtAt = 0,
		att = att,
		dust = makeDust(att, S),
		thud = makeSound(att, "thud", 0.55, 0.55),
		growl = makeSound(att, "growl", 0.5, feel.voice),
		growl2 = makeSound(att, "growl2", 0.45, feel.voice * 1.05),
		-- a jointed boss's limbs: springs for the arms' swing, their spread, the head's turn and nod, and this
		-- frame's turn of each limb (BossLife.turn)
		armL = { x = 0, v = 0 },
		armR = { x = 0, v = 0 },
		spread = { x = 0, v = 0 },
		headYaw = { x = 0, v = 0 },
		headNod = { x = 0, v = 0 },
		turns = {} :: { [string]: CFrame },
		out = {
			soft = if v.limbs then 1 else BossLife.SOFT,
			squash = if v.limbs then 0.85 else BossLife.SQUASH,
			sy = 1,
			pitch = 0,
			roll = 0,
			twist = 0,
			lift = 0,
			jump = 0,
		},
	}
	v.life = L
	v.model.Destroying:Connect(function()
		att:Destroy()
	end)
	return L
end

local function voice(L: any, hurt: boolean?)
	local s = if hurt or math.random() < 0.5 then L.growl2 or L.growl else L.growl or L.growl2
	if s then
		s.PlaybackSpeed = L.feel.voice * (0.92 + math.random() * 0.16) * (if hurt then 1.12 else 1)
		s.TimePosition = 0
		s:Play()
	end
end

-- a side of the disc comes down: dust off its rim (and a little at the front) and a deep thud
local function footfall(v: any, L: any, side: number, strength: number)
	local cf = CFrame.new(v.pos) * CFrame.Angles(0, v.yaw, 0)
	local att = L.att
	att.WorldPosition = (cf * CFrame.new(side * L.rimR * 0.8, 0.5, 0)).Position
	L.dust:Emit(math.floor(6 + 6 * strength))
	att.WorldPosition = (cf * CFrame.new(-side * L.rimR * 0.4, 0.5, -L.rimR * 0.5)).Position
	L.dust:Emit(math.floor(3 + 3 * strength))
	att.WorldPosition = v.pos + Vector3.new(0, v.height * 0.45, 0)
	local s = L.thud
	if s then
		s.Volume = 0.3 + 0.35 * math.min(strength, 1.3)
		s.PlaybackSpeed = 0.5 + math.random() * 0.1
		s.TimePosition = 0
		s:Play()
	end
end

-- how far to turn (radians, from where the server faces it) to look at the fighter nearest to it
local function lookTowards(v: any): number
	local best: Vector3? = nil
	local bestD = 120
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			local d = (r.Position - v.pos).Magnitude
			if d < bestD then
				best, bestD = r.Position, d
			end
		end
	end
	if not best then
		return 0
	end
	local dir = (best :: Vector3) - v.pos
	local want = math.atan2(-dir.X, -dir.Z)
	return math.clamp((want - v.yaw + math.pi) % TAU - math.pi, -0.75, 0.75)
end

local function pick(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = math.random() * total
	for name, w in weights do
		roll -= w
		if roll <= 0 then
			return name
		end
	end
	return next(weights) :: string
end

-------------------------------------------------------------------------------------------------------------
-- per frame
-------------------------------------------------------------------------------------------------------------
-- walking: rocks from one side of the disc to the other (or hops), a thud and dust each time it comes down.
-- Returns pitch, roll, twist, lift, squash, jump (a hop takes the disc along).
local function walk(v: any, L: any, dt: number, g: number): (number, number, number, number, number, number)
	local F = L.feel
	local before = math.sin(L.phase)
	L.phase += dt * F.stride * (0.7 + 0.4 * math.min(g, 1)) * math.pi -- a step is half a cycle
	local s = math.sin(L.phase)
	local down = (1 - math.abs(s)) ^ 6 -- the moment it lands
	if (before < 0) ~= (s < 0) and g > 0.3 then
		footfall(v, L, if before > 0 then 1 else -1, 0.5 + 0.5 * math.min(g, 1))
	end
	if F.hop then
		local air = math.abs(s)
		return 0.05 * g, 0.03 * s * g, 0, 0, 0.08 * air * g - 0.14 * down * g, 2.4 * L.S * air * g
	end
	local pitch = 0.07 * g + 0.02 * math.sin(2 * L.phase) * g -- leans into it, nods with each step
	-- (a jointed boss rocks less: it has a disc of its own that stays flat, and its arms swing instead)
	local rock = if v.limbs then 0.45 else 1
	return pitch, F.waddle * s * g * rock, 0.05 * math.cos(L.phase) * g, 0, -0.05 * down * g, 0
end

-- between moves: picks something to do every few seconds and plays it
local function fidget(v: any, L: any, dt: number, k: number, canStart: boolean): (number, number, number, number, number, number)
	if not L.fid then
		if not canStart or L.t < L.nextFid then
			return 0, 0, 0, 0, 0, 0
		end
		L.fid = pick(L.feel.fidgets)
		L.fidT = 0
		L.fidSide = if math.random() < 0.5 then -1 else 1
		L.fidVoice = false
		L.fidHit = false
	end
	local def = FIDGETS[L.fid]
	L.fidT += dt
	local u = L.fidT
	if def.voice and not L.fidVoice and u >= def.voice then
		L.fidVoice = true
		voice(L)
	end
	if def.hit and not L.fidHit and u >= def.hit then
		L.fidHit = true
		footfall(v, L, L.fidSide, 1.2)
	end
	if u >= def.len or k < 0.3 then
		L.fid = nil
		L.nextFid = L.t + 2.2 + math.random() * 3.3
		return 0, 0, 0, 0, 0, 0
	end
	local p, r, t, l, s, j = def.f(u, L.fidSide)
	if v.limbs and def.limbs then
		-- a jointed boss turns its head to look round, not its whole bulk
		if L.fid == "look" then
			t *= 0.25
		end
		local al, ar, sp, hy, hn = def.limbs(u, L.fidSide)
		L.fArmL, L.fArmR, L.fSpread, L.fHeadYaw, L.fHeadNod = al * k, ar * k, sp * k, hy * k, hn * k
	end
	return p * k, r * k, t * k, l * L.S * k, s * k, j * L.S * k
end

-------------------------------------------------------------------------------------------------------------
-- jointed bosses (30 Oct, owner: "ik heb het ook over de armen bv die bewegen niet"): ForgeGUI copies of the
-- bosses on our own account, cut into pieces with Studio's segment_mesh. Each piece has a `Limb` attribute: head,
-- armL, armR (the boss's own left and right; its left is -X, it faces -Z), body or base. BossView turns each limb
-- about its joint (BossLife.turn), carries the base along flat (BossLife.flatCf) and moves the eyes and other
-- points with their limb (BossLife.attPoint).
-------------------------------------------------------------------------------------------------------------
-- a spring towards `want` (f Hz, d damping): the arms and head follow through and settle like heavy limbs
local function follow(s: any, want: number, dt: number, f: number, d: number): number
	local w = TAU * f
	s.v += (-2 * d * w * s.v - w * w * (s.x - want)) * dt
	s.x += s.v * dt
	return s.x
end

-- what the arms and head do this frame (radians): the moves pose them through the body's lean (rears back: fists
-- go up over its head; throws itself forward: they slam down), walking swings them, breathing lifts them a little,
-- a hit jolts them, the head watches the nearest fighter, and the fidgets add their own
local function limbs(v: any, L: any, dt: number, g: number, idle: number, alive: number, b: number)
	local F = L.feel
	local act = v.action and v.action.name
	local P = v.pitch.x -- the moves' lean (- = rearing back, + = thrown forward)
	local pose = if P < 0 then -P * 8.5 else P * 1.6
	local roar = math.max(0, v.squash.x - 1.06) * 4 -- stretched tall for a roar: arms thrown wide
	local swing = if F.hop then 0 else 0.55 * math.sin(L.phase) * math.min(g, 1)
	local dead = if act == "death" then 1 else 0
	local armBase = 0.12 + 0.05 * b * idle
	local wantL = armBase + pose + swing + (L.fArmL or 0) - 0.3 * dead
	local wantR = armBase + pose - swing + (L.fArmR or 0) - 0.3 * dead
	local wantSpread = 0.06 + 0.04 * b * idle + roar + (L.fSpread or 0) + 0.35 * L.quake
	-- the head: the nearest fighter (a jointed boss turns its head more than its body), a nod per step, down when it dies
	local wantYaw = L.lookWant * idle * alive * 0.75 + (L.fHeadYaw or 0) + (L.jerkT or 0) * 2
	local wantNod = 0.06 * math.sin(2 * L.phase) * math.min(g, 1) - P * 0.8 + (L.fHeadNod or 0) - 0.25 * L.quake + 0.6 * dead
	L.fArmL, L.fArmR, L.fSpread, L.fHeadYaw, L.fHeadNod = 0, 0, 0, 0, 0
	local aL = follow(L.armL, math.clamp(wantL, -0.8, 2.9), dt, 2.6, 0.55)
	local aR = follow(L.armR, math.clamp(wantR, -0.8, 2.9), dt, 2.6, 0.55)
	local sp = follow(L.spread, math.clamp(wantSpread, -0.1, 1.2), dt, 2.2, 0.6)
	local hy = follow(L.headYaw, math.clamp(wantYaw, -0.9, 0.9), dt, 1.6, 0.6)
	local hn = follow(L.headNod, math.clamp(wantNod, -0.6, 0.7), dt, 2, 0.6)
	local T = L.turns
	-- + about X swings an arm forward and up (it faces -Z); its left arm spreads out towards -X
	T.armL = CFrame.Angles(aL, 0, -sp)
	T.armR = CFrame.Angles(aR, 0, sp)
	T.head = CFrame.Angles(-hn, hy, 0)
end

function BossLife.step(v: any, dt: number): any
	local L = v.life or start(v)
	local o = L.out
	local F = L.feel
	dt = math.max(dt, 1 / 240)
	L.t += dt
	local t = L.t
	local act = v.action and v.action.name
	local quiet = act == "death" or act == "burrow"
	local fight = fighting()
	-- idle: no move running; alive: not dying or underground (both fade so nothing snaps)
	local idleWant = if act == nil then 1 else 0
	L.idle += (idleWant - L.idle) * math.min(1, dt * (if idleWant > L.idle then 1.5 else 6))
	L.alive += ((if quiet then 0 else 1) - L.alive) * math.min(1, dt * 3)
	local idle, alive = L.idle, L.alive

	-- how it's moving: the server walks and turns it (BossView eases it there)
	local pos = v.pos
	local moved = Vector3.new(pos.X - L.lastPos.X, 0, pos.Z - L.lastPos.Z).Magnitude
	if moved > 6 * L.S or v.leap then
		moved = 0 -- a jump to a new spot or a leap through the air, not a walk
	end
	L.lastPos = pos
	local turned = math.abs((v.yaw - L.lastYaw + math.pi) % TAU - math.pi)
	L.lastYaw = v.yaw
	local k5 = math.min(1, dt * 5)
	L.speed += (moved / dt - L.speed) * k5
	L.turn += (turned / dt + math.abs(L.lookV) - L.turn) * k5
	local gaitWant = if act == nil then math.clamp(L.speed / (5 * L.S) + L.turn * 0.8, 0, 1.25) else 0
	L.gait += (gaitWant - L.gait) * math.min(1, dt * (if gaitWant > L.gait then 4 else 2.5))
	local g = L.gait * alive

	local pitch, roll, twist, lift, sy, jump = 0, 0, 0, 0, 1, 0
	if g > 0.01 then
		local p, r, tw, l, s, j = walk(v, L, dt, g)
		pitch, roll, twist, lift, sy, jump = pitch + p, roll + r, twist + tw, lift + l, sy * (1 + s), jump + j
	end

	-- breathing (quicker, deeper and with a tremble in its rage)
	local rage = v.clip == "rage"
	L.breath += dt * F.breath * (if rage then 1.7 else 1) * TAU
	local b = math.sin(L.breath)
	sy *= 1 + b * (if rage then 0.045 else 0.032) * (0.5 + 0.5 * idle) * alive
	pitch -= b * 0.018 * idle * alive
	if rage then
		roll += math.sin(t * 23) * 0.008 * alive
		twist += math.sin(t * 19 + 1.3) * 0.006 * alive
	end

	-- standing: never quite still
	local calm = idle * alive * (1 - math.min(g, 1))
	local sd = L.seed
	roll += F.sway * calm * (math.sin(t * 0.43 * TAU + sd) * 0.7 + math.sin(t * 0.19 * TAU + sd * 2) * 0.3)
	pitch += F.sway * 0.6 * calm * math.sin(t * 0.31 * TAU + sd * 3)
	twist += F.sway * 0.8 * calm * math.sin(t * 0.13 * TAU + sd * 4)
	if F.twitch > 0 and calm > 0.5 and t >= L.nextJerk then
		L.nextJerk = t + 0.8 + math.random() * 2.2
		L.jerkR = (math.random() * 2 - 1) * 0.07 * F.twitch
		L.jerkT = (math.random() * 2 - 1) * 0.09 * F.twitch
	end
	local jd = math.exp(-dt * 9)
	L.jerkR *= jd
	L.jerkT *= jd
	roll += L.jerkR
	twist += L.jerkT

	-- it watches the nearest fighter (a slow, heavy turn with a little overshoot)
	if t >= L.lookAt then
		L.lookAt = t + 0.3
		L.lookWant = if fight and idle * alive > 0.5 then lookTowards(v) else 0
	end
	local w = TAU * 0.8
	-- (a jointed boss turns its body a little and its head the rest: BossLife's limbs)
	local bodyLook = if v.limbs then 0.4 else 1
	L.lookV += (-2 * 0.55 * w * L.lookV - w * w * (L.look - L.lookWant * idle * alive * bodyLook)) * dt
	L.look += L.lookV * dt
	twist += L.look

	-- something to do between moves
	local fp, fr, ft, fl, fs, fj = fidget(v, L, dt, idle * alive, fight and idle > 0.95 and g < 0.2 and alive > 0.9)
	pitch, roll, twist, lift, sy, jump = pitch + fp, roll + fr, twist + ft, lift + fl + fj, sy * (1 + fs), jump + fj

	-- a hit: it shudders
	if L.quake > 0.001 then
		roll += math.sin(t * 37) * 0.045 * L.quake
		twist += math.sin(t * 29 + 0.7) * 0.03 * L.quake
		L.quake *= math.exp(-dt * 4)
	end

	-- a jointed boss's arms and head
	if v.limbs then
		limbs(v, L, dt, g, idle, alive, b)
	end

	o.pitch, o.roll, o.twist, o.lift, o.sy, o.jump = pitch, roll, twist, lift + jump, sy, jump
	L.att.WorldPosition = pos + Vector3.new(0, v.height * 0.45, 0) -- its voice comes from its chest
	return o
end

-- How far to lift it so a model leaning `pitch` and `roll` (radians) rests on its disc's rim, not through the floor.
function BossLife.rim(v: any, pitch: number, roll: number): number
	local L = v.life
	if not L or v.limbs then
		return 0 -- (a jointed boss's disc is a piece of its own and stays flat)
	end
	local tilt = math.min(math.sqrt(pitch * pitch + roll * roll), 0.7)
	return L.rimR * math.sin(tilt) * v.size.x
end

-- The moves crouch a boss by lowering it a little (made for the old jointed models): a one-piece model would push
-- its disc into the floor, so small dips are let go (the squash already shows the crouch). Going right under the
-- ground (burrowing, rising out of it, a cameo) still sinks it, smoothly.
function BossLife.dip(v: any, lift: number): number
	if lift >= 0 then
		return lift
	end
	local h = math.max(v.height, 1)
	local k = math.clamp((-lift - 0.1 * h) / (0.25 * h), 0, 1)
	return lift * k * k * (3 - 2 * k)
end

-- Where a limb turns, from its rest box in model space: an arm at its shoulder (near its top, towards the body),
-- the head at its neck (near its bottom), anything else about its middle.
local function jointOf(limb: string, c: Vector3, ext: Vector3): Vector3
	if limb == "armL" or limb == "armR" then
		local inward = if c.X < 0 then 1 else -1
		return Vector3.new(c.X + inward * ext.X * 0.22, c.Y + ext.Y * 0.3, c.Z)
	elseif limb == "head" then
		return Vector3.new(c.X, c.Y - ext.Y * 0.38, c.Z)
	end
	return c
end

-- BossView built a boss: if its pieces carry `Limb`s it's a jointed boss (v.limbs): each limb gets its joint, the
-- base is carried flat, and the body leans about its hips (v.hip: the top of the disc).
function BossLife.setup(v: any)
	local hip, any = 0, false
	for _, p in v.parts do
		if p.limb then
			any = true
			-- the piece's extent along the model's axes (its rest axes may be turned)
			local s = p.size
			p.ext = Vector3.new(
				math.abs(p.rx.X) * s.X + math.abs(p.ry.X) * s.Y + math.abs(p.rz.X) * s.Z,
				math.abs(p.rx.Y) * s.X + math.abs(p.ry.Y) * s.Y + math.abs(p.rz.Y) * s.Z,
				math.abs(p.rx.Z) * s.X + math.abs(p.ry.Z) * s.Y + math.abs(p.rz.Z) * s.Z
			)
			-- its joint: a `Joint` attachment in the piece (found where the limb touches the body when the model was
			-- made), or a guess from its box
			local att = p.part:FindFirstChild("Joint")
			if att and att:IsA("Attachment") then
				local q = att.Position
				p.joint = p.c + p.rx * q.X + p.ry * q.Y + p.rz * q.Z
			else
				p.joint = jointOf(p.limb, p.c, p.ext)
			end
			if p.limb == "base" then
				p.flat = true
				hip = math.max(hip, p.c.Y + p.ext.Y * 0.3)
			end
		end
	end
	if any then
		v.limbs = true
		v.hip = hip
	end
end

-- A limb's rest pose (centre and axes, model space) turned about its joint by this frame's turn.
function BossLife.turn(v: any, p: any): (Vector3, Vector3, Vector3, Vector3)
	local L = v.life
	local R = L and L.turns[p.limb]
	if not R then
		return p.c, p.rx, p.ry, p.rz
	end
	local j = p.joint
	return j + R:VectorToWorldSpace(p.c - j), R:VectorToWorldSpace(p.rx), R:VectorToWorldSpace(p.ry), R:VectorToWorldSpace(p.rz)
end

-- A jointed boss's disc: under it wherever it goes (in the air with it when it hops, down with it when it sinks
-- into the ground), never leaning or squashing. `base`: where the boss stands (BossView's placement).
function BossLife.flatCf(v: any, p: any, base: CFrame): CFrame
	local sz = v.size.x
	local want = p.size * sz
	if (want - p.lastSize).Magnitude > 0.004 * p.size.Magnitude then
		p.part.Size = want
		p.lastSize = want
	end
	local L = v.life
	local lift = math.min(BossLife.dip(v, v.lift.x), 0) + (if L then L.out.jump else 0)
	return base * CFrame.new(0, lift, 0) * CFrame.fromMatrix(p.c * sz, p.rx, p.ry, p.rz)
end

-- A point of the rig (an eye, the mouth ...) on a jointed boss, model space after its limb's turn and the overlay
-- (`g`: the columns of its group's pose, as BossView works them out). The point follows the piece it sits in.
function BossLife.attPoint(v: any, a: any, g: { Vector3 }): Vector3
	local p = a.p
	if a.limb == nil then
		a.limb = false
		for _, want in { "head", "armL", "armR" } do
			for _, q in v.parts do
				if q.limb == want and q.ext then
					local d = p - q.c
					local e = q.ext * 0.55
					if math.abs(d.X) <= e.X and math.abs(d.Y) <= e.Y and math.abs(d.Z) <= e.Z then
						a.limb = q
						break
					end
				end
			end
			if a.limb then
				break
			end
		end
	end
	local q = a.limb
	local L = v.life
	if q and L then
		local R = L.turns[q.limb]
		if R then
			p = q.joint + R:VectorToWorldSpace(p - q.joint)
		end
	end
	local hip = v.hip or 0
	return g[1] * p.X + g[2] * (p.Y - hip) + g[3] * p.Z + g[4] + Vector3.new(0, hip, 0)
end

-- A blow landed (big: a weak-spot hit): it shudders, and now and then cries out.
function BossLife.flinch(v: any, big: boolean)
	local L = v.life
	if not L then
		return
	end
	L.quake = math.max(L.quake, if big then 1 else 0.45)
	if big and L.t >= L.hurtAt then
		L.hurtAt = L.t + 2.5
		if math.random() < 0.6 then
			voice(L, true)
		end
	end
end

return BossLife
