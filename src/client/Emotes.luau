-- (5 Nov) EMOTES (owner: "A button / key (G) with 6 silly emotes: grass sneeze, lawn dance, flex, sleep, chicken,
-- plus a toot-like 'leaf blower' puff"; kids 8-14, "make your friends laugh"). Config.EMOTES has the list and tuning.
--   * G (D-pad up on a gamepad, the EMOTE button on a phone) opens a wheel of 6; click / tap one, press 1-6, or point
--     the left stick and press A. G again, B, or a click in the middle closes it.
--   * The server checks it (server/Emotes: a real id, the cooldown, alive, on foot, no boss fight) and tells every
--     client (player, id, server start time). Every client then poses that character here, by code, every frame after
--     the animations (PreSimulation, like client/RiderPose): Motor6D.Transform is local to each screen, so each
--     screen does it. No uploaded animations. The pose blends in over 0.2 s and out over 0.3 s.
--   * Moving (walking faster than Config.EMOTES.moveCancel, jumping, sitting, dying) cancels it on every screen: each
--     client watches the character itself, so there's no "stop" message.
--   * Your own emote in first person: client/CameraView steps the camera out to a short third-person view while it
--     plays (CameraView.emoteView) and back in after.
--   * Not while seated (mowers), in a boss fight (BossHP attribute), a film (client/Film.playing, or any script that
--     holds the camera) or the egg hatch (client/HatchFx.busy).
--   * Sounds: existing Config.SOUNDS keys, pitched; particles skipped in Potato Mode and halved on phones (PhonePerf);
--     the words are client/Fx.popWord.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local FxTex = require(ReplicatedStorage.MowALawn:WaitForChild("FxTex")) :: { [string]: string }
local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)
local Device = require(script.Parent.Device)
local PhonePerf = require(script.Parent.PhonePerf)
local Potato = require(script.Parent.Potato)
local CameraView = require(script.Parent.CameraView)

local Emotes = {}
local E = Config.EMOTES
if not E or E.on == false then
	return Emotes
end

local player = Players.LocalPlayer
local BY_ID: { [string]: any } = {}
for _, e in E.list do
	BY_ID[e.id] = e
end

-------------------------------------------------------------------------------------------------------------
-- pose helpers
-------------------------------------------------------------------------------------------------------------
type Joint = any
type Pose = { [string]: CFrame }
type Ctx = { drop: number }

local JOINT_NAMES = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
}

local function findJoints(char: Model): { [string]: Joint }?
	local j = {}
	for name, partName in JOINT_NAMES do
		local part = char:FindFirstChild(partName)
		local m = part and part:FindFirstChild(name)
		if not (m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint"))) then
			return nil -- not an R15 body
		end
		j[name] = m
	end
	return j
end

-- degrees, in the joint's own frame. Right arm: +Z raises it out to the side, +X swings it forward; elbows and knees
-- bend about X (+ elbow forward, - knee back); waist / neck: -X leans / looks down, +X back / up. (Checked in Lune.)
local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end
local I = CFrame.identity

-- the same joint on the other side: reflected across the body's middle (X flips)
local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- a whole pose done the other way round (left <-> right)
local function mirrorPose(p: Pose): Pose
	local out = {}
	for name, cf in p do
		local other = if name:sub(1, 4) == "Left" then "Right" .. name:sub(5) elseif name:sub(1, 5) == "Right" then "Left" .. name:sub(6) else name
		out[other] = mirror(cf)
	end
	return out
end

local function lerpPose(a: Pose, b: Pose, k: number): Pose
	if k <= 0 then
		return a
	elseif k >= 1 then
		return b
	end
	local out = {}
	for name in JOINT_NAMES do
		local ca, cb = a[name], b[name]
		if ca or cb then
			out[name] = (ca or I):Lerp(cb or I, k)
		end
	end
	return out
end

-- the right side as given, the left side mirrored from it
local function both(p: Pose, side: string, cf: CFrame)
	p["Right" .. side] = cf
	p["Left" .. side] = mirror(cf)
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end
local function wave(t: number, hz: number): number
	return math.sin(2 * math.pi * hz * t)
end

-------------------------------------------------------------------------------------------------------------
-- the six emotes: each gives a pose for `t` seconds in (joints left out stand straight)
-------------------------------------------------------------------------------------------------------------
local POSES: { [string]: (t: number, ctx: Ctx) -> Pose } = {}

-- Grass sneeze: the head tips back and the chest fills ("ah... AH..."), then ACHOO: head and chest snap forward,
-- the arms fly back, a little hop forward, then a dazed head shake.
function POSES.sneeze(t: number): Pose
	local snap = smooth((t - 0.95) / 0.1)
	local decay = if t > 1.05 then math.exp(-(t - 1.05) * 2.2) else 1
	local blast = snap * decay
	local windup = smooth(t / 1.0) * (1 - snap)
	local ah = wave(t, 3) * 4 * windup
	local shake = if t > 1.3 then wave(t, 4.5) * 16 * math.clamp((t - 1.3) * 3, 0, 1) else 0
	local p: Pose = {
		Neck = A(25 * windup + ah - 35 * blast, shake, 0),
		Waist = A(12 * windup - 30 * blast, 0, 0),
		Root = CFrame.new(0, 0, -0.25 * blast) * A(-6 * blast, 0, 0),
	}
	both(p, "Shoulder", A(-10 * windup - 35 * blast, 0, 20 * windup + 25 * blast))
	both(p, "Elbow", A(20 * windup + 30 * blast, 0, 0))
	return p
end

-- Lawn dance: a disco point with one arm (up, then down across), the other hand on the hip, hips swinging, knees
-- bopping on the beat; halfway through it swaps sides.
local function discoPose(t: number): Pose
	local b = t * 2 -- beats (2 a second)
	local sw = math.sin(math.pi * b)
	local dip = 0.5 - 0.5 * math.cos(2 * math.pi * b)
	local up = 0.5 - 0.5 * math.cos(math.pi * b)
	local p: Pose = {
		Root = CFrame.new(0.3 * sw, -0.25 * dip, 0) * A(0, 10 * sw, 8 * sw),
		Waist = A(0, -8 * sw, -10 * sw),
		Neck = A(8 * dip - 4, 0, 10 * sw),
		RightShoulder = A(40, 0, -30):Lerp(A(0, 0, 150), up),
		RightElbow = A(10 * (1 - up), 0, 0),
		LeftShoulder = mirror(A(-10, 0, 45)),
		LeftElbow = mirror(A(0, 0, -100)),
	}
	both(p, "Hip", A(25 * dip, 0, 0))
	both(p, "Knee", A(-50 * dip, 0, 0))
	both(p, "Ankle", A(25 * dip, 0, 0))
	return p
end
function POSES.dance(t: number): Pose
	local len = BY_ID.dance.len
	local p = discoPose(t)
	return lerpPose(p, mirrorPose(p), smooth((t - (len / 2 - 0.15)) / 0.3))
end

-- Flex: a double-biceps pose with the chest out, a tremble of effort, then a turn to show off the side.
function POSES.flex(t: number): Pose
	local into = smooth((t - 0.1) / 0.3)
	local trem = wave(t, 14) * 3 * into
	local side = smooth((t - 1.2) / 0.3)
	local p: Pose = {
		Waist = A(8 * into, 25 * side, 0),
		Neck = A(-6 * into, -15 * side, 0),
		Root = CFrame.new(0, -0.15 * into, 0) * A(0, -10 * side, 0),
	}
	both(p, "Shoulder", A(0, 0, 15):Lerp(A(0, 0, 90) * A(0, -90, 0), into) * A(0, 0, trem * 0.5))
	both(p, "Elbow", A(30, 0, 0):Lerp(A(110, 0, 0), into) * A(trem, 0, 0))
	both(p, "Hip", A(10 * into, 0, 10 * into))
	both(p, "Knee", A(-20 * into, 0, 0))
	both(p, "Ankle", A(10 * into, 0, -10 * into))
	return p
end

-- Sleep: a big yawn and stretch, then down onto your back, hands behind the head, one knee up, breathing.
function POSES.sleep(t: number, ctx: Ctx): Pose
	local yawn = smooth(t / 0.3) * (1 - smooth((t - 0.6) / 0.3))
	local down = smooth((t - 0.7) / 0.6)
	local breathe = wave(t, 0.6)
	local stand: Pose = {
		Neck = A(25 * yawn, 0, 0),
		Waist = A(10 * yawn, 0, 0),
	}
	both(stand, "Shoulder", A(0, 0, 165 * yawn))
	both(stand, "Elbow", A(20 * yawn, 0, 0))
	local lie: Pose = {
		Root = CFrame.new(0, -ctx.drop, 0) * A(90, 0, 0),
		Waist = A(3 * breathe, 0, 0),
		Neck = A(-10, 20, 0),
		RightHip = A(40, 0, 0),
		RightKnee = A(-75, 0, 0),
		RightAnkle = A(30, 0, 0),
		LeftHip = mirror(A(5, 0, 5)),
		LeftKnee = A(-5, 0, 0),
	}
	both(lie, "Shoulder", A(160, 0, 25))
	both(lie, "Elbow", A(110, 0, 0))
	return lerpPose(stand, lie, down)
end

-- Chicken: hands in the armpits flapping like wings, the head bobbing and pecking, stepping on the spot.
local function chickenLeg(p: Pose, side: string, k: number)
	p[side .. "Hip"] = A(40 * k, 0, 0)
	p[side .. "Knee"] = A(-70 * k, 0, 0)
	p[side .. "Ankle"] = A(30 * k, 0, 0)
end
function POSES.chicken(t: number): Pose
	local into = smooth(t / 0.25)
	local flap = 0.5 + 0.5 * wave(t, 5)
	local bob = wave(t, 3)
	local peck = math.max(0, wave(t, 3)) ^ 3
	local step = wave(t, 1.5)
	local p: Pose = {
		Waist = A((-15 - 20 * peck) * into, 0, 0),
		Neck = A((15 * bob - 15 * peck) * into, 0, 0),
		Root = CFrame.new(0, (-0.15 + 0.12 * math.abs(step)) * into, 0),
	}
	both(p, "Shoulder", A(0, 0, (30 + 35 * flap) * into) * A(0, -90 * into, 0))
	both(p, "Elbow", A(150 * into, 0, 0))
	chickenLeg(p, "Right", math.max(0, step) * into)
	chickenLeg(p, "Left", math.max(0, -step) * into)
	return p
end

-- Leaf blower: bend over, peek back over your shoulder, PFFT (a jolt, arms flung out), then fan the air behind you
-- and shake your head.
function POSES.blower(t: number): Pose
	local bend = smooth(t / 0.5) * (1 - 0.6 * smooth((t - 1.8) / 0.6))
	local puff = smooth((t - 0.85) / 0.06) * math.exp(-math.max(0, t - 0.95) * 5)
	local fan = smooth((t - 1.15) / 0.25)
	local p: Pose = {
		Waist = A(-35 * bend + 8 * puff, 0, 0),
		Neck = A(20 * bend, -60 * bend * (1 - fan) + 20 * wave(t, 3) * fan, 0),
		Root = CFrame.new(0, -0.1 * bend + 0.25 * puff, 0.25 * bend - 0.3 * puff) * A(-5 * bend - 10 * puff, 0, 0),
	}
	-- hands on the knees, flung out on the puff
	both(p, "Shoulder", A(45 * bend, 0, 10 + 60 * puff))
	both(p, "Elbow", A(10 * bend, 0, 0))
	-- then the right hand fans the air behind you
	p.RightShoulder = (p.RightShoulder :: CFrame):Lerp(A(-40, 0, 20 + 25 * wave(t, 4)), fan)
	p.RightElbow = (p.RightElbow :: CFrame):Lerp(A(30 + 20 * wave(t, 4), 0, 0), fan)
	both(p, "Hip", A(20 * bend, 0, 0))
	both(p, "Knee", A(-30 * bend, 0, 0))
	both(p, "Ankle", A(10 * bend, 0, 0))
	return p
end

-------------------------------------------------------------------------------------------------------------
-- effects: particles, words, sounds
-------------------------------------------------------------------------------------------------------------
local fxModule: any = nil
local function popWord(pos: Vector3, text: string, color: Color3)
	if fxModule == nil then
		local ok, m = pcall(require, script.Parent:FindFirstChild("Fx"))
		fxModule = if ok and type(m) == "table" then m else false
	end
	if fxModule and fxModule.popWord then
		pcall(fxModule.popWord, pos, text, color)
	end
end

type Burst = { tex: string, colors: { Color3 }, count: number, speed: NumberRange, spread: number, dir: Enum.NormalId, size: number, life: NumberRange, accel: Vector3?, drag: number? }
local function burst(part: BasePart?, offset: CFrame, b: Burst)
	if not part or Potato.on then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "EmoteFx"
	a.CFrame = offset
	a.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Texture = b.tex
	e.Color = if #b.colors > 1 then ColorSequence.new(b.colors[1], b.colors[2]) else ColorSequence.new(b.colors[1])
	e.LightInfluence = 0.4
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, b.size), NumberSequenceKeypoint.new(0.7, b.size * 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = b.life
	e.Speed = b.speed
	e.SpreadAngle = Vector2.new(b.spread, b.spread)
	e.EmissionDirection = b.dir
	e.Acceleration = b.accel or Vector3.new(0, -25, 0)
	e.Drag = b.drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-240, 240)
	e.Rate = 0
	e.Parent = a
	e:Emit(math.max(1, math.floor(b.count * (if PhonePerf.on then 0.5 else 1))))
	Debris:AddItem(a, 3)
end

local GREENS = { Color3.fromRGB(150, 230, 90), Color3.fromRGB(70, 160, 50) }
local LEAVES = { Color3.fromRGB(240, 170, 60), Color3.fromRGB(150, 190, 70) }
local FX: { [string]: { { at: number, fn: (char: Model) -> () } } } = {
	sneeze = {
		{ at = 1.0, fn = function(char)
			local head = char:FindFirstChild("Head") :: BasePart?
			local o = CFrame.new(0, -0.1, -0.6)
			burst(head, o, { tex = FxTex.blade or "", colors = GREENS, count = 26, speed = NumberRange.new(14, 26), spread = 22, dir = Enum.NormalId.Front, size = 0.45, life = NumberRange.new(0.6, 1.1) })
			burst(head, o, { tex = FxTex.puff or "", colors = { Color3.fromRGB(200, 240, 170) }, count = 6, speed = NumberRange.new(6, 10), spread = 15, dir = Enum.NormalId.Front, size = 1.4, life = NumberRange.new(0.3, 0.5), accel = Vector3.zero, drag = 4 })
		end },
	},
	flex = {
		{ at = 0.45, fn = function(char)
			local chest = char:FindFirstChild("UpperTorso") :: BasePart?
			burst(chest, CFrame.new(0, 0.6, 0), { tex = FxTex.star or "", colors = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 190, 40) }, count = 12, speed = NumberRange.new(4, 9), spread = 180, dir = Enum.NormalId.Top, size = 0.6, life = NumberRange.new(0.5, 0.9), accel = Vector3.new(0, 2, 0) })
		end },
		{ at = 1.3, fn = function(char)
			local chest = char:FindFirstChild("UpperTorso") :: BasePart?
			burst(chest, CFrame.new(0, 0.6, 0), { tex = FxTex.star or "", colors = { Color3.fromRGB(255, 240, 160) }, count = 6, speed = NumberRange.new(3, 6), spread = 180, dir = Enum.NormalId.Top, size = 0.5, life = NumberRange.new(0.4, 0.7), accel = Vector3.zero })
		end },
	},
	chicken = {
		{ at = 0.25, fn = function(char)
			local chest = char:FindFirstChild("UpperTorso") :: BasePart?
			burst(chest, CFrame.new(0, 0, 0), { tex = FxTex.petal or "", colors = { Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 210) }, count = 8, speed = NumberRange.new(3, 7), spread = 180, dir = Enum.NormalId.Top, size = 0.4, life = NumberRange.new(0.8, 1.3), accel = Vector3.new(0, -4, 0), drag = 3 })
		end },
	},
	blower = {
		{ at = 0.9, fn = function(char)
			local hips = char:FindFirstChild("LowerTorso") :: BasePart?
			local o = CFrame.new(0, -0.1, 0.6)
			burst(hips, o, { tex = FxTex.puff or "", colors = { Color3.fromRGB(235, 225, 200), Color3.fromRGB(200, 215, 170) }, count = 7, speed = NumberRange.new(4, 8), spread = 30, dir = Enum.NormalId.Back, size = 2.2, life = NumberRange.new(0.6, 0.9), accel = Vector3.new(0, 1, 0), drag = 3 })
			burst(hips, o, { tex = FxTex.leaf or "", colors = LEAVES, count = 18, speed = NumberRange.new(10, 18), spread = 35, dir = Enum.NormalId.Back, size = 0.45, life = NumberRange.new(0.8, 1.4), accel = Vector3.new(0, -12, 0) })
		end },
	},
}

-------------------------------------------------------------------------------------------------------------
-- playing emotes (anyone's, on this screen)
-------------------------------------------------------------------------------------------------------------
type Active = {
	who: Player,
	char: Model,
	hum: Humanoid,
	joints: { [string]: Joint },
	e: any,
	t0: number,
	cancelAt: number?,
	fired: { [any]: boolean },
	last: { [string]: CFrame },
	ctx: Ctx,
	mine: boolean,
}
local active: { [Player]: Active } = {}
Emotes.playing = false -- your own emote is playing (others may read it)

local function finish(a: Active)
	if active[a.who] == a then
		active[a.who] = nil
	end
	-- joints no animation drives would keep the last pose: stand them straight
	for name, j in a.joints do
		if j.Parent and j.Transform == a.last[name] then
			j.Transform = I
		end
	end
	if a.mine then
		Emotes.playing = false
		CameraView.emoteView(false)
	end
end

local function start(who: Player, id: string, serverAt: number)
	local e = BY_ID[id]
	local char = who.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = hum and hum.RootPart
	if not e or not char or not hum or not root then
		return
	end
	local joints = findJoints(char)
	if not joints then
		return
	end
	local late = math.clamp(workspace:GetServerTimeNow() - serverAt, 0, 1)
	local old = active[who]
	if old then
		finish(old)
	end
	local a: Active = {
		who = who,
		char = char,
		hum = hum,
		joints = joints,
		e = e,
		t0 = os.clock() - late,
		cancelAt = nil,
		fired = {},
		last = {},
		ctx = { drop = math.max(1, hum.HipHeight + root.Size.Y / 2 - 0.5) },
		mine = who == player,
	}
	active[who] = a
	if a.mine then
		Emotes.playing = true
		CameraView.emoteView(true)
	end
end

local function near(a: Active, camPos: Vector3): number?
	local root = a.hum.RootPart
	if not root then
		return nil
	end
	local d = (root.Position - camPos).Magnitude
	return if d < (E.range or 140) then d else nil
end

-- this frame's sounds, words and particles (each once, not after a cancel)
local function cues(a: Active, t: number, dist: number)
	local vol = if a.mine then 1 else math.clamp(1 - dist / (E.range or 140), 0.15, 0.8)
	for _, s in a.e.sfx or {} do
		if not a.fired[s] and t >= s.at then
			a.fired[s] = true
			if t < s.at + 0.3 then
				Sound.playAt(s.key, s.pitch or 1, (s.volume or 1) * vol)
			end
		end
	end
	local head = a.char:FindFirstChild("Head") :: BasePart?
	for _, w in a.e.words or {} do
		if not a.fired[w] and t >= w.at then
			a.fired[w] = true
			if head and t < w.at + 0.3 then
				popWord(head.Position + Vector3.new(0, 1, 0), w.text, a.e.color)
			end
		end
	end
	for _, f in FX[a.e.id] or {} do
		if not a.fired[f] and t >= f.at then
			a.fired[f] = true
			if t < f.at + 0.3 then
				f.fn(a.char)
			end
		end
	end
end

local function shouldCancel(a: Active, t: number): boolean
	local hum = a.hum
	local root = hum.RootPart
	if not a.char.Parent or not root or hum.Health <= 0 or hum.SeatPart or hum.Sit then
		return true
	end
	if t < 0.3 then
		return false
	end
	local v = root.AssemblyLinearVelocity
	if Vector3.new(v.X, 0, v.Z).Magnitude > (E.moveCancel or 5) then
		return true
	end
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then
		return true
	end
	-- your own: the moment you push the stick (before the body picks up speed)
	return a.mine and hum.MoveDirection.Magnitude > 0.3
end

local function apply(a: Active, t: number, w: number)
	local pose = POSES[a.e.id](t, a.ctx)
	for name, j in a.joints do
		-- (what the animations put there this frame; a joint no animation drives still holds what we wrote last
		-- frame, and counts as standing straight)
		local base = if j.Transform == a.last[name] then I else j.Transform
		local want = pose[name] or I
		local cf = if w >= 1 then want else base:Lerp(want, w)
		j.Transform = cf
		a.last[name] = cf
	end
end

local function step()
	if next(active) == nil then
		return
	end
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local now = os.clock()
	for _, a in active do
		local t = now - a.t0
		local len = a.e.len or 3
		if not a.cancelAt and shouldCancel(a, t) then
			a.cancelAt = now
		end
		local wC = if a.cancelAt then 1 - (now - a.cancelAt) / 0.2 else 1
		if t >= len or wC <= 0 or not a.char.Parent then
			finish(a)
			continue
		end
		local w = math.min(smooth(t / 0.2), smooth((len - t) / 0.3), smooth(wC))
		local dist = near(a, camPos)
		if dist then
			local ok, err = pcall(apply, a, t, w)
			if not ok then
				warn("[Emotes] " .. tostring(err))
				finish(a)
				continue
			end
			if not a.cancelAt then
				cues(a, t, dist)
			end
		end
	end
end
RunService.PreSimulation:Connect(step)

Players.PlayerRemoving:Connect(function(p)
	local a = active[p]
	if a then
		finish(a)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- asking for one
-------------------------------------------------------------------------------------------------------------
local remote: RemoteEvent? = nil
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("MowALawnRemotes", 30)
	local r = remotes and remotes:WaitForChild("Emote", 30)
	if r and r:IsA("RemoteEvent") then
		remote = r
		r.OnClientEvent:Connect(function(who: any, id: any, at: any)
			if typeof(who) == "Instance" and who:IsA("Player") and type(id) == "string" and type(at) == "number" then
				start(who, id, at)
			end
		end)
	end
end)

-- modules loaded lazily (both are already loaded by other client code; nil if they're missing)
local lazy: { [string]: any } = {}
local function mod(name: string): any
	if lazy[name] == nil then
		local inst = script.Parent:FindFirstChild(name)
		local ok, m = false, nil
		if inst then
			ok, m = pcall(require, inst)
		end
		lazy[name] = if ok and type(m) == "table" then m else false
	end
	return lazy[name] or nil
end

-- why you can't emote right now (nil: you can)
local function blocked(): string?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not hum.RootPart then
		return "dead"
	end
	if hum.SeatPart or hum.Sit then
		return "seated"
	end
	if player:GetAttribute("BossHP") ~= nil then
		return "boss"
	end
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType == Enum.CameraType.Scriptable then
		return "camera" -- a film, the fly-over or a boss cutscene has the camera
	end
	local Film = mod("Film")
	if Film and Film.playing then
		return "film"
	end
	local HatchFx = mod("HatchFx")
	if HatchFx and HatchFx.busy then
		return "hatch"
	end
	return nil
end

local sentAt = -math.huge
local function cooldownLeft(): number
	return math.max(0, (E.cooldown or 4) - (os.clock() - sentAt))
end

local function ask(id: string): boolean
	if blocked() or cooldownLeft() > 0 or not remote then
		Sound.play("denied")
		return false
	end
	sentAt = os.clock()
	remote:FireServer(id)
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the wheel
-------------------------------------------------------------------------------------------------------------
local wheel = Instance.new("Frame")
wheel.Name = "EmoteWheel"
wheel.BackgroundTransparency = 1
wheel.Size = UDim2.fromOffset(400, 400)
wheel.Position = UDim2.fromScale(0.5, 0.5)
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.ZIndex = 50
wheel.Visible = false
wheel.Parent = UI.gui

local hub = UI.frame({ size = UDim2.fromOffset(150, 150), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(40, 30, 20), transparency = 0.2, parent = wheel, radius = 75, outline = 3, name = "Hub" })
UI.text(hub, "EMOTES", UDim2.new(0.8, 0, 0, 34), { pos = UDim2.new(0.5, 0, 0.5, -10), anchor = Vector2.new(0.5, 0.5), stroke = 2.5 })
local hubHint = UI.text(hub, if Device.touch then "tap to close" else "G to close", UDim2.new(0.8, 0, 0, 20), { pos = UDim2.new(0.5, 0, 0.5, 22), anchor = Vector2.new(0.5, 0.5), stroke = 1.5, color = Color3.fromRGB(230, 220, 200) })
-- (a Modal button: in first person the mouse is set free while the wheel is open)
local closer = Instance.new("TextButton")
closer.Name = "Close"
closer.Text = ""
closer.BackgroundTransparency = 1
closer.Size = UDim2.fromScale(1, 1)
closer.Modal = true
closer.Parent = hub

local slots: { { button: TextButton, scale: UIScale } } = {}
local selected = 0

local function highlight(i: number)
	selected = i
	for k, s in slots do
		s.scale.Scale = if k == i then 1.15 else 1
	end
end

local close: () -> ()

local function pick(i: number)
	local e = E.list[i]
	if not e then
		return
	end
	if ask(e.id) then
		Sound.play("click")
		close()
	end
end

local RADIUS = 135
for i, e in E.list do
	local ang = math.rad(-90 + (i - 1) * 360 / #E.list)
	local b = Instance.new("TextButton")
	b.Name = e.id
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(112, 112)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, math.cos(ang) * RADIUS, 0.5, math.sin(ang) * RADIUS)
	b.BackgroundColor3 = UI.shade(e.color, 0.75)
	b.BorderSizePixel = 0
	b.Parent = wheel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	UI.stroke(b, 3)
	UI.gradient(b, e.color)
	local sc = Instance.new("UIScale")
	sc.Parent = b
	UI.text(b, e.name, UDim2.new(0.86, 0, 0, 30), { pos = UDim2.fromScale(0.5, 0.55), anchor = Vector2.new(0.5, 0.5), stroke = 2.5 })
	if not Device.touch then
		UI.text(b, tostring(i), UDim2.fromOffset(26, 26), { pos = UDim2.new(0.5, 0, 0, 10), anchor = Vector2.new(0.5, 0), stroke = 2, color = Color3.fromRGB(255, 240, 200) })
	end
	b.MouseEnter:Connect(function()
		highlight(i)
	end)
	b.MouseButton1Click:Connect(function()
		pick(i)
	end)
	slots[i] = { button = b, scale = sc }
end

local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
local stickConn: RBXScriptConnection? = nil
local hintConn: RBXScriptConnection? = nil

-- while the wheel is open: 1-6 pick (and don't reach the hotbar), the left stick points, A picks, B closes
local function pickAction(_, state: Enum.UserInputState, input: InputObject)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local n = table.find(NUMBER_KEYS, input.KeyCode)
	if n then
		pick(n)
	elseif input.KeyCode == Enum.KeyCode.ButtonA then
		if selected > 0 then
			pick(selected)
		end
	elseif input.KeyCode == Enum.KeyCode.ButtonB then
		close()
	end
	return Enum.ContextActionResult.Sink
end

local function open()
	if wheel.Visible then
		return
	end
	wheel.Visible = true
	highlight(0)
	Sound.play("click")
	local keys = table.clone(NUMBER_KEYS)
	table.insert(keys, Enum.KeyCode.ButtonA)
	table.insert(keys, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("MowEmotePick", pickAction, false, Enum.ContextActionPriority.High.Value, table.unpack(keys))
	stickConn = UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.5 then
			-- (the stick's Y is up; the wheel's first slot is at the top, going clockwise)
			local ang = math.deg(math.atan2(-input.Position.Y, input.Position.X)) + 90
			highlight(math.floor(((ang % 360) / (360 / #E.list)) + 0.5) % #E.list + 1)
		end
	end)
	hintConn = RunService.Heartbeat:Connect(function()
		local left = cooldownLeft()
		hubHint.Text = if left > 0 then ("wait %d"):format(math.ceil(left)) elseif Device.touch then "tap to close" else "G to close"
	end)
end

function close()
	if not wheel.Visible then
		return
	end
	wheel.Visible = false
	ContextActionService:UnbindAction("MowEmotePick")
	if stickConn then
		stickConn:Disconnect()
		stickConn = nil
	end
	if hintConn then
		hintConn:Disconnect()
		hintConn = nil
	end
end

closer.MouseButton1Click:Connect(function()
	close()
end)

function Emotes.toggle()
	if wheel.Visible then
		close()
	elseif not blocked() then
		open()
	else
		Sound.play("denied")
	end
end

-- G, D-pad up, and on a phone ContextActionService's own touch button (like client/Sprint's SPRINT)
ContextActionService:BindAction("MowEmote", function(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		Emotes.toggle()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
ContextActionService:SetTitle("MowEmote", "EMOTE")
ContextActionService:SetPosition("MowEmote", UDim2.new(1, -170, 1, -230))

-- the wheel goes away when you can't emote any more (got on a mower, a film started ...)
task.spawn(function()
	while true do
		task.wait(0.25)
		if wheel.Visible and blocked() then
			close()
		end
	end
end)

return Emotes
