--!strict
-- MAYOR THISTLEWICK for the films (client/Intro, client/Ending): his voxel sculpture (shared/MayorShape, made by
-- tools/blender/voxel/mayor.py; built by shared/SculptKit) hung on a rig of invisible parts and Motor6Ds (R15 names
-- for the body joints), animated here by hand:
--   * poses eased by springs with a little overshoot, so every move lands with some life in it;
--   * breathing, a slow weight shift, blinking, darting eyes, eyebrows for his moods;
--   * his jaw and moustache moving as he talks (from a voice's loudness, or in made-up syllables);
--   * his head, then his chest, then his eyes turning to whatever he looks at;
--   * his coat tails and his medal swinging after him;
--   * turning on the spot with little steps, hopping for joy, crouching.
--
--   local m = MayorRig.new(parent, feet, opts)   feet: where his soles stand, facing his front; opts: { lite, scale }
--   m.update(dt)            every frame
--   m.act(name)             a pose (see POSES): "idle", "proud", "worried", "sigh", "present", "point", "cheer",
--                           "shock", "tipHat", "talk", "wave", "laugh", "fist", "cower", "lookOut", "clasp"
--   m.mood(name)            his face: "neutral", "happy", "worried", "sad", "surprised", "stern", "scared"
--   m.look(target)          head and eyes follow a Vector3, a BasePart or a function returning a Vector3 (nil: ahead)
--   m.speak(level)          drive his jaw from a function returning 0..1 (a voice's loudness); nil to stop
--   m.chatter(seconds)      talk without a voice for a while
--   m.turn(dir, time)       turn on the spot to face a flat direction
--   m.hop(height)           a little jump
--   m.hatPop(height)        his top hat blown up off his head, spinning, and landing back on it
--   m.crouch(amount)        bend the knees (0..1), e.g. cowering
--   m.closeEyes(on)         eyes shut (content, or wincing) until opened again
--   m.face() / m.eyes()     world points to frame close-ups on
--   m.destroy()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local SculptKit = require(Shared:WaitForChild("SculptKit"))
local Shape = require(Shared:WaitForChild("MayorShape")) :: any
local Potato = require(script.Parent.Potato)

local MayorRig = {}

local D = math.rad

-- the body joints get R15's names (anything that knows R15 finds them); the rest are named after their group
local JOINT_NAME: { [string]: string } = {
	LowerTorso = "Root", UpperTorso = "Waist", Head = "Neck",
	RightUpperArm = "RightShoulder", RightLowerArm = "RightElbow", RightHand = "RightWrist",
	LeftUpperArm = "LeftShoulder", LeftLowerArm = "LeftElbow", LeftHand = "LeftWrist",
	RightUpperLeg = "RightHip", RightLowerLeg = "RightKnee", RightFoot = "RightAnkle",
	LeftUpperLeg = "LeftHip", LeftLowerLeg = "LeftKnee", LeftFoot = "LeftAnkle",
}

-- pose keys -> groups
local KEY: { [string]: string } = {
	Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head",
	RShoulder = "RightUpperArm", RElbow = "RightLowerArm", RWrist = "RightHand",
	LShoulder = "LeftUpperArm", LElbow = "LeftLowerArm", LWrist = "LeftHand",
	RHip = "RightUpperLeg", RKnee = "RightLowerLeg", RAnkle = "RightFoot",
	LHip = "LeftUpperLeg", LKnee = "LeftLowerLeg", LAnkle = "LeftFoot",
	Hat = "Hat", Jaw = "Jaw", Stache = "Stache", BrowL = "BrowL", BrowR = "BrowR",
}

-- the rest pose (degrees, CFrame.Angles order): arms hanging a little out from his round middle, a jaunty hat
local A_POSE = 12
local REST: { [string]: Vector3 } = {
	LeftUpperArm = Vector3.new(0, 0, -A_POSE),
	RightUpperArm = Vector3.new(0, 0, A_POSE),
	LeftLowerArm = Vector3.new(8, 0, 0),
	RightLowerArm = Vector3.new(8, 0, 0),
	Hat = Vector3.new(0, 0, -5),
}

-- springs by joint: natural frequency (rad/s) and damping ratio (under 1: a little overshoot)
local SPRING: { [string]: { number } } = {
	LowerTorso = { 8, 0.8 }, UpperTorso = { 9, 0.7 }, Head = { 11, 0.68 },
	RightUpperArm = { 11, 0.6 }, LeftUpperArm = { 11, 0.6 }, RightLowerArm = { 13, 0.62 }, LeftLowerArm = { 13, 0.62 },
	RightHand = { 15, 0.7 }, LeftHand = { 15, 0.7 },
	RightUpperLeg = { 12, 0.85 }, LeftUpperLeg = { 12, 0.85 }, RightLowerLeg = { 12, 0.85 }, LeftLowerLeg = { 12, 0.85 },
	RightFoot = { 12, 0.85 }, LeftFoot = { 12, 0.85 },
	Hat = { 10, 0.5 }, BrowL = { 18, 0.7 }, BrowR = { 18, 0.7 }, Stache = { 22, 0.4 },
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- R joints mirrored onto L (x kept, y and z flipped)
local function sym(t: { [string]: Vector3 }): { [string]: Vector3 }
	local out = table.clone(t)
	for k, a in t do
		if string.sub(k, 1, 1) == "R" then
			local rest = string.sub(k, 2)
			if rest == "Shoulder" or rest == "Elbow" or rest == "Wrist" or rest == "Hip" or rest == "Knee" or rest == "Ankle" then
				out["L" .. rest] = Vector3.new(a.X, -a.Y, -a.Z)
			end
		end
	end
	return out
end

local function with(base: { [string]: Vector3 }, extra: { [string]: Vector3 }): { [string]: Vector3 }
	local out = table.clone(base)
	for k, a in extra do
		out[k] = a
	end
	return out
end

-- POSES (degrees). Checked in tools/blender/voxel/mayor_preview.py, which has the same table.
local POSES: { [string]: { [string]: Vector3 } } = {
	idle = sym({ RShoulder = v(4, 0, 2), RElbow = v(10, 0, 0) }),
	proud = with(sym({ RShoulder = v(16, 30, 14), RElbow = v(52, 0, 0), RWrist = v(0, 0, -20) }), { Waist = v(6, 0, 0), Neck = v(9, 0, 0), Root = v(2, 0, 0) }),
	worried = with(sym({ RShoulder = v(32, -14, -4), RElbow = v(72, 18, 0), RWrist = v(0, 0, 10) }), { Waist = v(-5, 0, 0), Neck = v(-12, 0, 0) }),
	clasp = with(sym({ RShoulder = v(26, -20, -6), RElbow = v(64, 22, 0), RWrist = v(0, 0, 14) }), { Waist = v(-2, 0, 0), Neck = v(-4, 0, 0) }),
	sigh = with(sym({ RShoulder = v(2, 0, -4), RElbow = v(6, 0, 0) }), { Waist = v(-8, 0, 0), Neck = v(-18, 0, 0), Root = v(-2, 0, 0) }),
	present = with(sym({ RShoulder = v(34, 0, 52), RElbow = v(24, 0, 0), RWrist = v(0, -20, 0) }), { Waist = v(4, 0, 0), Neck = v(6, 0, 0) }),
	point = {
		RShoulder = v(92, -8, 4), RElbow = v(4, 0, 0), RWrist = v(0, 0, 0),
		LShoulder = v(-12, 0, -16), LElbow = v(30, 0, 0), Waist = v(0, -18, 0), Neck = v(4, -10, 0), Root = v(0, -6, 0),
	},
	cheer = with(sym({ RShoulder = v(14, 0, 150), RElbow = v(22, 0, 0) }), { Neck = v(14, 0, 0), Waist = v(5, 0, 0) }),
	shock = with(sym({ RShoulder = v(38, 0, 62), RElbow = v(96, 0, 0), RWrist = v(0, 0, 20) }), { Root = v(7, 0, 0), Neck = v(10, 0, 0) }),
	tipHat = { RShoulder = v(150, -20, 16), RElbow = v(40, 0, 0), LShoulder = v(6, 0, -4), LElbow = v(16, 0, 0), Neck = v(-6, -8, 4), Hat = v(-18, 0, 6) },
	talk = { RShoulder = v(38, 10, 30), RElbow = v(62, 0, 0), RWrist = v(0, -30, 0), LShoulder = v(10, 0, -6), LElbow = v(24, 0, 0), Neck = v(-3, 6, 3) },
	wave = { RShoulder = v(10, 0, 140), RElbow = v(30, 0, 0), LShoulder = v(6, 0, -4), LElbow = v(14, 0, 0), Neck = v(4, 0, -4) },
	laugh = with(sym({ RShoulder = v(16, 30, 14), RElbow = v(52, 0, 0), RWrist = v(0, 0, -20) }), { Waist = v(8, 0, 0), Neck = v(16, 0, 0), Root = v(3, 0, 0) }),
	fist = { RShoulder = v(30, 20, 34), RElbow = v(118, 0, 0), RWrist = v(0, 0, 0), LShoulder = v(4, 0, -6), LElbow = v(14, 0, 0), Neck = v(6, 0, 0), Waist = v(4, 8, 0) },
	cower = with(sym({ RShoulder = v(60, -10, 30), RElbow = v(110, 0, 0), RWrist = v(0, 0, 10) }), { Waist = v(-10, 0, 0), Neck = v(-14, 0, 0), Root = v(-4, 0, 0) }),
	lookOut = with(sym({ RShoulder = v(-22, 85, 6), RElbow = v(75, 0, 0) }), { Waist = v(2, 0, 0), Neck = v(4, 0, 0) }), -- hands behind his back
}

-- MOODS: the brows' tilt (degrees: + raises the inner end of the left brow) and lift (studs), the moustache's curl
local MOODS: { [string]: { tilt: number, lift: number, stache: number, blink: number } } = {
	neutral = { tilt = 0, lift = 0, stache = 0, blink = 3.4 },
	happy = { tilt = -3, lift = 0.035, stache = 6, blink = 3.0 },
	worried = { tilt = 16, lift = 0.03, stache = -3, blink = 2.4 },
	sad = { tilt = 22, lift = 0.01, stache = -6, blink = 2.8 },
	surprised = { tilt = 0, lift = 0.09, stache = 3, blink = 6 },
	stern = { tilt = -16, lift = -0.03, stache = 0, blink = 4 },
	scared = { tilt = 18, lift = 0.075, stache = -4, blink = 1.4 },
}

type Joint = {
	name: string,
	motor: Motor6D,
	base: CFrame,
	angle: Vector3,
	vel: Vector3,
	pos: Vector3, -- (a translation, studs: brows, the hat, the root)
	posVel: Vector3,
	w: number,
	z: number,
}

export type Mayor = {
	model: Model,
	head: BasePart,
	root: CFrame,
	scale: number,
	update: (dt: number) -> (),
	act: (name: string) -> (),
	mood: (name: string) -> (),
	look: (target: any) -> (),
	speak: (level: (() -> number)?) -> (),
	chatter: (seconds: number) -> (),
	turn: (dir: Vector3, time: number?) -> (),
	hop: (height: number?) -> (),
	hatPop: (height: number?) -> (),
	crouch: (amount: number) -> (),
	closeEyes: (on: boolean) -> (),
	face: () -> Vector3,
	eyes: () -> Vector3,
	destroy: () -> (),
}

local HAT_POP = 0.9 -- seconds the hat is in the air (m.hatPop)

local function lite(): boolean
	return Potato.on or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

-- smooth noise in -1..1 (one octave of value noise on a line)
local function wobble(t: number, seed: number): number
	return math.noise(t, seed * 7.31, 0.5) * 2
end

-- the leg angles that lower the hips by d (studs, at scale 1) with the feet kept flat where they are
local THIGH, SHIN = 0.62, 0.58
local function legBend(d: number): (number, number, number)
	local reach = math.clamp(THIGH + SHIN - d, 0.5, THIGH + SHIN)
	local a = math.deg(math.acos(math.clamp(reach / (THIGH + SHIN), -1, 1)))
	return a, -2 * a, a
end

local function springStep(x: number, vel: number, target: number, w: number, z: number, dt: number): (number, number)
	local acc = w * w * (target - x) - 2 * z * w * vel
	vel += acc * dt
	return x + vel * dt, vel
end

function MayorRig.new(parent: Instance, feet: CFrame, opts: { lite: boolean?, scale: number? }?): Mayor
	local scale = (opts and opts.scale) or 1
	local useLite = if opts and opts.lite ~= nil then opts.lite else lite()
	local groups = if useLite then Shape.LITE else Shape.FULL
	local palette = Shape.PALETTE

	local model = Instance.new("Model")
	model.Name = "MayorThistlewick"
	local byName: { [string]: any } = {}
	for _, g in groups do
		byName[g.name] = g
	end
	local rootGroup = byName.LowerTorso
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.one * 0.5
	hrp.Transparency = 1
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.CanQuery = false
	hrp.CanTouch = false
	hrp.CFrame = feet * CFrame.new(rootGroup.pivot * scale)
	hrp.Parent = model
	model.PrimaryPart = hrp

	local parts: { [string]: BasePart } = {}
	local joints: { [string]: Joint } = {}
	local order: { Joint } = {}
	local modelPivot: { [string]: Vector3 } = {}
	local tagFns = {
		glass = function(p: BasePart)
			p.Material = Enum.Material.Glass
			p.Transparency = 0.6
			p.Reflectance = 0.15
			p.CastShadow = false
		end,
	}
	for _, g in groups do
		local holder = Instance.new("Part")
		holder.Name = g.name
		holder.Size = Vector3.one * 0.2
		holder.Transparency = 1
		holder.Anchored = false
		holder.Massless = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		local parentPart: BasePart = if g.parent then parts[g.parent] else hrp
		local restAngles = REST[g.name] or Vector3.zero
		local base = if g.parent
			then CFrame.new(g.pivot * scale) * CFrame.Angles(D(restAngles.X), D(restAngles.Y), D(restAngles.Z))
			else CFrame.identity
		modelPivot[g.name] = (if g.parent then modelPivot[g.parent] else Vector3.zero) + g.pivot
		holder.CFrame = parentPart.CFrame * base
		local motor = Instance.new("Motor6D")
		motor.Name = JOINT_NAME[g.name] or g.name
		motor.Part0 = parentPart
		motor.Part1 = holder
		motor.C0 = base
		motor.C1 = CFrame.identity
		motor.Parent = holder
		holder.Parent = model
		parts[g.name] = holder
		SculptKit.fill(holder, holder.CFrame, g, palette, scale, { tags = tagFns })
		local sp = SPRING[g.name] or { 10, 0.7 }
		local j: Joint = {
			name = g.name, motor = motor, base = base,
			angle = Vector3.zero, vel = Vector3.zero, pos = Vector3.zero, posVel = Vector3.zero,
			w = sp[1], z = sp[2],
		}
		joints[g.name] = j
		table.insert(order, j)
	end
	-- the lids are hidden until he blinks
	local lids = parts.Lids
	local eyeParts: { BasePart } = {}
	local lidParts: { BasePart } = {}
	for _, name in { "Eyes", "Pupils" } do
		local h = parts[name]
		if h then
			for _, p in h:GetChildren() do
				if p:IsA("BasePart") then
					table.insert(eyeParts, p)
				end
			end
		end
	end
	if lids then
		for _, p in lids:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
				table.insert(lidParts, p)
			end
		end
	end
	model.Parent = parent

	local head = parts.Head
	local headPivot = modelPivot.Head or Vector3.new(0, 4.3, 0)
	local faceLocal = ((Shape.FACE :: Vector3) - headPivot) * scale
	local eyesLocal = (Vector3.new(0, 5.48, -0.95) - headPivot) * scale

	-------------------------------------------------------------------------------------------------------------
	-- state
	-------------------------------------------------------------------------------------------------------------
	local t = 0
	local pose = POSES.idle
	local poseName = "idle"
	local moodDef = MOODS.neutral
	local lookAt: any = nil
	local level: (() -> number)? = nil
	local chatterUntil = 0
	local jawOpen = 0
	local yaw = 0
	local turnFrom, turnTo, turnStart, turnLen = 0, 0, -1, 1
	local hopStart, hopHeight = -10, 0
	local crouchAmt, crouchNow = 0, 0
	local nextBlink = 1.5 + math.random() * 2
	local blinkUntil = 0
	local blinking = false
	local eyesShut = false
	local saccade = Vector2.zero
	local nextSaccade = 1
	local pupilOff = Vector2.zero
	local lookYaw, lookPitch = 0, 0
	local tailAngle = { L = Vector3.zero, R = Vector3.zero }
	local tailVel = { L = Vector3.zero, R = Vector3.zero }
	local lastHipPos: Vector3? = nil
	local lastHipVel = Vector3.zero
	local medal = Vector3.zero
	local medalVel = Vector3.zero
	local beatAt, beatPow = 0, 0
	local hatPopAt, hatPopHeight = -10, 0
	local hatSpin = Vector3.zero

	local function setBlink(on: boolean)
		if blinking == on then
			return
		end
		blinking = on
		for _, p in eyeParts do
			p.Transparency = if on then 1 else 0
		end
		for _, p in lidParts do
			p.Transparency = if on then 0 else 1
		end
	end

	-- where he's looking, in the world (nil: straight ahead)
	local function lookPoint(): Vector3?
		local target = lookAt
		if target == nil then
			return nil
		end
		if typeof(target) == "Vector3" then
			return target
		elseif typeof(target) == "Instance" and target:IsA("BasePart") then
			return target.Position
		elseif type(target) == "function" then
			local ok, p = pcall(target)
			if ok and typeof(p) == "Vector3" then
				return p
			end
		end
		return nil
	end

	-------------------------------------------------------------------------------------------------------------
	-- the frame
	-------------------------------------------------------------------------------------------------------------
	local function update(dt: number)
		dt = math.clamp(dt, 0, 1 / 20)
		t += dt
		local yawBefore = yaw

		-- the feet's frame: turning on the spot, hopping, crouching
		if turnStart >= 0 then
			local k = math.clamp((t - turnStart) / turnLen, 0, 1)
			local e = if k < 0.5 then 4 * k * k * k else 1 - (-2 * k + 2) ^ 3 / 2
			yaw = turnFrom + (turnTo - turnFrom) * e
			if k >= 1 then
				turnStart = -1
			end
		end
		crouchNow += (crouchAmt - crouchNow) * math.min(1, dt * 8)
		local hopK = (t - hopStart) / 0.8
		local lift, squat = 0, crouchNow * 0.35
		if hopK >= 0 and hopK < 1 then
			if hopK < 0.18 then
				squat += math.sin(hopK / 0.18 * math.pi * 0.5) * 0.22
			elseif hopK < 0.6 then
				local a = (hopK - 0.18) / 0.42
				lift = math.sin(a * math.pi) * hopHeight
				squat += (1 - a) * 0.1
			elseif hopK < 0.78 then
				squat += math.sin((hopK - 0.6) / 0.18 * math.pi) * 0.2
			end
		end
		local rootCf = feet * CFrame.Angles(0, yaw, 0) * CFrame.new((rootGroup.pivot :: Vector3) * scale + Vector3.new(0, (lift - squat) * scale, 0))
		hrp.CFrame = rootCf

		-- the pose's targets, plus the layers on top
		local target: { [string]: Vector3 } = {}
		for k, a in pose do
			local g = KEY[k]
			if g then
				target[g] = a
			end
		end
		local function addT(g: string, a: Vector3)
			target[g] = (target[g] or Vector3.zero) + a
		end
		-- breathing and a slow weight shift
		local breath = math.sin(t * 1.7)
		addT("UpperTorso", v(breath * 1.1, wobble(t * 0.23, 2) * 2, 0))
		addT("LowerTorso", v(0, wobble(t * 0.17, 1) * 2.5, wobble(t * 0.21, 3) * 1.3))
		addT("Head", v(-breath * 0.6 + wobble(t * 0.4, 4) * 1.5, 0, wobble(t * 0.33, 5) * 2))
		addT("RightUpperArm", v(0, 0, breath * 0.8))
		addT("LeftUpperArm", v(0, 0, -breath * 0.8))
		-- knees bent for a squat or a crouch, feet kept flat
		if squat > 0.001 then
			local h, k, a = legBend(squat)
			for _, side in { "Right", "Left" } do
				addT(side .. "UpperLeg", v(h, 0, 0))
				addT(side .. "LowerLeg", v(k, 0, 0))
				addT(side .. "Foot", v(a, 0, 0))
			end
		end
		if lift > 0.05 then -- tucked in the air
			for _, side in { "Right", "Left" } do
				addT(side .. "UpperLeg", v(18, 0, 0))
				addT(side .. "LowerLeg", v(-30, 0, 0))
				addT(side .. "Foot", v(14, 0, 0))
			end
		end
		-- little steps while turning
		if turnStart >= 0 then
			local k = math.clamp((t - turnStart) / turnLen, 0, 1)
			local step = math.sin(k * math.pi * 2)
			local side = if step > 0 then "Right" else "Left"
			local s = math.abs(step)
			addT(side .. "UpperLeg", v(16 * s, 0, 0))
			addT(side .. "LowerLeg", v(-28 * s, 0, 0))
			addT(side .. "Foot", v(12 * s, 0, 0))
		end
		-- pose-specific motion
		if poseName == "wave" then
			addT("RightLowerArm", v(0, 0, math.sin(t * 9) * 26))
		elseif poseName == "laugh" then
			local b = math.abs(math.sin(t * 11))
			addT("UpperTorso", v(b * 5, 0, 0))
			addT("Head", v(b * 4, 0, 0))
		elseif poseName == "cheer" then
			local p = math.sin(t * 8)
			addT("RightUpperArm", v(0, 0, p * 10))
			addT("LeftUpperArm", v(0, 0, -p * 10))
		elseif poseName == "fist" then
			addT("RightLowerArm", v(math.max(0, math.sin(t * 7)) * 18, 0, 0))
		elseif poseName == "shock" or poseName == "cower" then
			addT("UpperTorso", v(0, math.sin(t * 31) * 1.2, 0)) -- (trembling)
		end
		-- talking: a voice's loudness or made-up syllables move the jaw; beats nod the head and (in "talk") the arm
		local amp = 0
		if level then
			local ok, a = pcall(level)
			amp = if ok and type(a) == "number" then math.clamp(a, 0, 1) else 0
		elseif t < chatterUntil then
			local syl = math.sin(t * 13) * 0.5 + 0.5
			amp = math.clamp(syl * (0.6 + 0.4 * math.noise(t * 3, 9.1)), 0, 1)
		end
		jawOpen += (amp - jawOpen) * math.min(1, dt * (if amp > jawOpen then 30 else 14))
		if poseName == "cheer" or poseName == "shock" or poseName == "laugh" then
			jawOpen = math.max(jawOpen, if poseName == "laugh" then 0.5 + 0.5 * math.abs(math.sin(t * 11)) else 0.85)
		end
		if amp > 0.55 and t - beatAt > 0.35 then
			beatAt, beatPow = t, amp
		end
		local beat = beatPow * math.exp(-(t - beatAt) * 6)
		addT("Head", v(-beat * 5, 0, 0))
		if poseName == "talk" then
			addT("RightUpperArm", v(beat * 14, 0, beat * 6))
			addT("RightLowerArm", v(beat * 10, 0, 0))
		end
		-- the face: brows by mood, the moustache curling with it and riding the jaw
		local m = moodDef
		target.BrowL = (target.BrowL or Vector3.zero) + v(0, 0, m.tilt)
		target.BrowR = (target.BrowR or Vector3.zero) + v(0, 0, -m.tilt)
		target.Stache = (target.Stache or Vector3.zero) + v(m.stache + jawOpen * 5, 0, 0)
		local surprise = if poseName == "shock" then 0.06 else 0
		local browLift = (m.lift + surprise + jawOpen * 0.01) * scale

		-- looking at something: the head turns most of the way, the chest a little, the eyes the rest
		local lp = lookPoint()
		local wantYaw, wantPitch = 0, 0
		if lp then
			local headPos = head.Position
			local rel = rootCf:VectorToObjectSpace(lp - headPos)
			local flat = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
			wantYaw = math.deg(math.atan2(-rel.X, -rel.Z))
			wantPitch = math.deg(math.atan2(rel.Y, math.max(flat, 0.01)))
			wantYaw = math.clamp(wantYaw, -80, 80)
			wantPitch = math.clamp(wantPitch, -35, 30)
		end
		lookYaw += (wantYaw - lookYaw) * math.min(1, dt * 6)
		lookPitch += (wantPitch - lookPitch) * math.min(1, dt * 6)
		addT("Head", v(lookPitch * 0.7, lookYaw * 0.62, 0))
		addT("UpperTorso", v(0, lookYaw * 0.22, 0))

		-- springs toward the targets
		for _, j in order do
			local name = j.name
			if name == "Jaw" or name == "TailL" or name == "TailR" or name == "Medal" or name == "Eyes" or name == "Pupils" or name == "Lids" then
				continue
			end
			local goal = target[name] or Vector3.zero
			local ax, vx = springStep(j.angle.X, j.vel.X, goal.X, j.w, j.z, dt)
			local ay, vy = springStep(j.angle.Y, j.vel.Y, goal.Y, j.w, j.z, dt)
			local az, vz = springStep(j.angle.Z, j.vel.Z, goal.Z, j.w, j.z, dt)
			j.angle = Vector3.new(ax, ay, az)
			j.vel = Vector3.new(vx, vy, vz)
		end
		-- translations: the brows lift, the hat lifts off for a tip, the moustache rides the jaw
		local function moveTo(j: Joint?, goal: Vector3, w: number, z: number)
			if not j then
				return
			end
			local px, pvx = springStep(j.pos.X, j.posVel.X, goal.X, w, z, dt)
			local py, pvy = springStep(j.pos.Y, j.posVel.Y, goal.Y, w, z, dt)
			local pz, pvz = springStep(j.pos.Z, j.posVel.Z, goal.Z, w, z, dt)
			j.pos = Vector3.new(px, py, pz)
			j.posVel = Vector3.new(pvx, pvy, pvz)
		end
		moveTo(joints.BrowL, v(0, browLift, 0), 20, 0.7)
		moveTo(joints.BrowR, v(0, browLift, 0), 20, 0.7)
		moveTo(joints.Hat, v(0, if poseName == "tipHat" then 0.32 * scale else 0, if poseName == "tipHat" then -0.12 * scale else 0), 12, 0.55)
		-- the hat blown off his head (m.hatPop): up, two spins, and back down onto it
		local hp = t - hatPopAt
		if hp >= 0 and hp < HAT_POP and joints.Hat then
			local k = hp / HAT_POP
			joints.Hat.pos = v(0, 4 * hatPopHeight * k * (1 - k) * scale, -0.25 * math.sin(k * math.pi) * scale)
			joints.Hat.posVel = Vector3.zero
			hatSpin = v(math.sin(k * math.pi * 2) * 25, k * 720, math.sin(k * math.pi) * 20)
		else
			hatSpin = Vector3.zero
		end
		moveTo(joints.Stache, v(0, jawOpen * 0.03 * scale, 0), 24, 0.45)
		local jaw = joints.Jaw
		if jaw then
			jaw.angle = Vector3.new(-jawOpen * 17, 0, 0)
		end

		-- the coat tails and the medal swing after the body (a damped pendulum pushed by the hips' motion)
		local hipPos = parts.LowerTorso.Position
		local hipVel = if lastHipPos then (hipPos - lastHipPos) / math.max(dt, 1e-3) else Vector3.zero
		local hipAcc = (hipVel - lastHipVel) / math.max(dt, 1e-3)
		lastHipPos, lastHipVel = hipPos, hipVel
		local localAcc = rootCf:VectorToObjectSpace(hipAcc) / math.max(scale, 0.1)
		local yawRate = math.deg(yaw - yawBefore) / math.max(dt, 1e-3)
		local swayIn = Vector3.new(math.clamp(localAcc.Z * 2.2 - localAcc.Y * 0.8, -60, 60), 0, math.clamp(-localAcc.X * 2.2 + yawRate * 0.12, -40, 40))
		for _, side in { "L", "R" } do
			local a, vel = tailAngle[side], tailVel[side]
			local rest = Vector3.new(wobble(t * 0.7, if side == "L" then 11 else 12) * 2, 0, 0)
			local acc = (rest - a) * 64 - vel * 3.2 + swayIn * 6
			vel += acc * dt
			a += vel * dt
			a = Vector3.new(math.clamp(a.X, -35, 50), 0, math.clamp(a.Z, -30, 30))
			tailAngle[side], tailVel[side] = a, vel
		end
		do
			local twist = joints.UpperTorso.vel.Y + joints.LowerTorso.vel.Y
			local acc = (Vector3.zero - medal) * 90 - medalVel * 3.5 + Vector3.new(localAcc.Z * 6 - joints.UpperTorso.vel.X * 0.6, 0, -localAcc.X * 6 - twist * 0.25)
			medalVel += acc * dt
			medal += medalVel * dt
			medal = Vector3.new(math.clamp(medal.X, -45, 45), 0, math.clamp(medal.Z, -35, 35))
		end

		-- blinking (sometimes twice), and the eyes darting about
		if eyesShut then
			setBlink(true)
			blinkUntil = t + 0.15
		elseif not blinking and t >= nextBlink then
			setBlink(true)
			blinkUntil = t + 0.11
		elseif blinking and t >= blinkUntil then
			setBlink(false)
			nextBlink = t + (if math.random() < 0.18 then 0.2 else m.blink * (0.6 + math.random() * 0.8))
		end
		if t >= nextSaccade then
			saccade = Vector2.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.35)
			nextSaccade = t + 0.7 + math.random() * 2.2
		end
		local eyeX = math.clamp((wantYaw - lookYaw * 0.84) / 30, -1, 1)
		local eyeY = math.clamp((wantPitch - lookPitch * 0.7) / 25, -1, 1)
		local want = Vector2.new(-eyeX, eyeY) * 0.8 + saccade
		pupilOff += (want - pupilOff) * math.min(1, dt * 25)

		-- write the joints
		for _, j in order do
			local name = j.name
			local a = j.angle
			local extra = j.pos
			if name == "TailL" or name == "TailR" then
				a = tailAngle[if name == "TailL" then "L" else "R"]
			elseif name == "Medal" then
				a = medal
			elseif name == "Pupils" then
				a = Vector3.zero
				extra = Vector3.new(math.clamp(pupilOff.X, -1, 1) * 0.04, math.clamp(pupilOff.Y, -1, 1) * 0.03, 0) * scale
			elseif name == "Eyes" or name == "Lids" then
				continue
			elseif name == "Hat" then
				a += hatSpin
			end
			j.motor.C0 = j.base * CFrame.new(extra) * CFrame.Angles(D(a.X), D(a.Y), D(a.Z))
		end
	end

	-------------------------------------------------------------------------------------------------------------
	-- the API
	-------------------------------------------------------------------------------------------------------------
	local self: Mayor
	self = {
		model = model,
		head = head,
		root = feet,
		scale = scale,
		update = update,
		act = function(name: string)
			local p = POSES[name]
			if not p then
				return
			end
			pose, poseName = p, name
			if name == "point" or name == "present" or name == "cheer" or name == "shock" or name == "fist" then
				-- a kick on the way in: the springs overshoot a little more
				for _, j in order do
					j.vel *= 1.15
				end
			end
		end,
		mood = function(name: string)
			moodDef = MOODS[name] or MOODS.neutral
		end,
		look = function(target: any)
			lookAt = target
		end,
		speak = function(fn: (() -> number)?)
			level = fn
		end,
		chatter = function(seconds: number)
			chatterUntil = t + seconds
		end,
		turn = function(dir: Vector3, time: number?)
			local flat = Vector3.new(dir.X, 0, dir.Z)
			if flat.Magnitude < 0.01 then
				return
			end
			local localDir = feet:VectorToObjectSpace(flat.Unit)
			local goal = math.atan2(-localDir.X, -localDir.Z)
			-- the short way round
			local diff = (goal - yaw + math.pi) % (2 * math.pi) - math.pi
			turnFrom, turnTo, turnStart, turnLen = yaw, yaw + diff, t, math.max(time or 0.8, 0.05)
		end,
		hop = function(height: number?)
			hopStart, hopHeight = t, height or 0.6
		end,
		hatPop = function(height: number?)
			hatPopAt, hatPopHeight = t, height or 2.4
		end,
		crouch = function(amount: number)
			crouchAmt = math.clamp(amount, 0, 1)
		end,
		closeEyes = function(on: boolean)
			eyesShut = on
		end,
		face = function(): Vector3
			return head.CFrame:PointToWorldSpace(faceLocal)
		end,
		eyes = function(): Vector3
			return head.CFrame:PointToWorldSpace(eyesLocal)
		end,
		destroy = function()
			model:Destroy()
		end,
	}
	update(0)
	return self
end

-- Which level of detail a new Mayor gets by default (the light one on phones and in Potato Mode).
MayorRig.lite = lite

return MayorRig
