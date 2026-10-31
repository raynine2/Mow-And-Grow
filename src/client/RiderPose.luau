-- (owner, 29 Oct: "change the seat animation of the mowers to be organic and different so the player actually fits in
-- the mower aswell instead of bugging through the roof or floating instead of sitting") Everyone riding a mower is
-- posed by code here, every frame, on every client (Motor6D.Transform is local, so nothing goes over the network and
-- nothing is uploaded). It runs after the animations each frame (PreSimulation), so it replaces the stock sit.
--  * fits the seat: the hips are lowered/raised until the thighs rest on that mower's cushion, whatever the avatar's
--    size; the feet find the floor with a ray and the knees bend to reach it (two-bone IK)
--  * each mower has its own stance (shared/MowerSeats): hunched on the Rusty Rider, proud on the tractor, laid back on
--    the zero-turn's lap bars, leaning into the Mulcher, tucked in like a racer on the Rocket
--  * hands on the wheel (IK) and the wheel turns with the turn (the server hangs it on a "Steer" motor)
--  * alive: leans into turns, rocks back when it speeds up and forward when it brakes, bounces on a spring over bumps,
--    the engine buzzes through the seat, the head stays level and looks into the turn
-- (29 Oct, owner: "real 2-hand scythe", "check every weapon hold") The same IK puts the free hand on two-handed tools
-- held on foot, as everyone else sees you (third person): up the Mega Scythe's snath (wherever on it is nearest the
-- shoulder, never closer than a hand's width to the other fist) and on the Weed Whacker's front loop handle. It rides
-- along through the swings, so they read as two-handed too.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MowerSeats = require(ReplicatedStorage.MowALawn.MowerSeats)
local PhonePerf = require(script.Parent.PhonePerf)
local ViewAnims = require(script.Parent.ViewAnims)
local WeaponAnimIds = require(ReplicatedStorage.MowALawn.WeaponAnimIds) :: { [string]: string }
local AnimIds = require(ReplicatedStorage.MowALawn.AnimIds) :: { [string]: string }

local RiderPose = {}

local FAR = if PhonePerf.on then 90 else 160 -- studs: riders further than this from the camera keep the stock sit

-- (an avatar's joints are Motor6Ds or, with Roblox's newer avatar joints, AnimationConstraints: both have C0, C1 and
-- Transform, and sit in their Part1)
type Joint = any
type Joints = { [string]: Joint }
type Rider = {
	char: Model,
	hum: Humanoid,
	joints: Joints,
	model: Model?,
	spec: MowerSeats.Spec?,
	floor: { number }?,
	steer: number,
	roll: number,
	pitch: number,
	bounce: number,
	bounceV: number,
	lastVy: number,
	lastFwd: number,
	accel: number,
	phase: number,
	steerMotor: Motor6D?,
	hidden: { BasePart },
	listed: boolean,
}

local riders: { [Model]: Rider } = {}

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

local function findJoints(char: Model): Joints?
	local j: Joints = {}
	for name, partName in JOINT_NAMES do
		local part = char:FindFirstChild(partName)
		local m = part and part:FindFirstChild(name)
		if not (m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint"))) then
			return nil -- not an R15 body: leave it to the stock sit
		end
		j[name] = m
	end
	return j
end

-- where Part1 ends up with this Transform
local function place(part0: CFrame, m: Joint, t: CFrame): CFrame
	return part0 * m.C0 * t * m.C1:Inverse()
end

-- Turn joint `m` so its Part1 ends up with world rotation `rot` (position comes from the joint).
local function aim(part0: CFrame, m: Joint, rot: CFrame): CFrame
	local t = ((part0 * m.C0).Rotation:Inverse() * rot * m.C1.Rotation).Rotation
	m.Transform = t
	return place(part0, m, t)
end

-- The world rotation that takes local bone axis `a` (with local hinge axis `hingeLocal`) onto world direction `d`
-- with the hinge along `h`.
local function frameFor(a: Vector3, hingeLocal: Vector3, d: Vector3, h: Vector3): CFrame
	local b = (hingeLocal - a * hingeLocal:Dot(a)).Unit
	local h2 = (h - d * h:Dot(d))
	if h2.Magnitude < 1e-4 then
		h2 = d:Cross(Vector3.yAxis)
		if h2.Magnitude < 1e-4 then
			h2 = Vector3.xAxis
		end
	end
	h2 = h2.Unit
	local world = CFrame.fromMatrix(Vector3.zero, d, h2, d:Cross(h2))
	local loc = CFrame.fromMatrix(Vector3.zero, a, b, a:Cross(b))
	return world * loc:Inverse()
end

-- Two-bone IK: from the joint at `rootPos` reach `target` with bones `l1`, `l2`, bending toward `pole`.
-- Returns the middle joint's position and the reached end.
local function solve(rootPos: Vector3, target: Vector3, l1: number, l2: number, pole: Vector3): (Vector3, Vector3)
	local dv = target - rootPos
	local dist = math.clamp(dv.Magnitude, math.abs(l1 - l2) + 0.05, l1 + l2 - 0.02)
	local dir = if dv.Magnitude > 1e-4 then dv.Unit else Vector3.new(0, -1, 0)
	local cosA = math.clamp((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local side = pole - dir * pole:Dot(dir)
	side = if side.Magnitude > 1e-4 then side.Unit else dir:Cross(Vector3.xAxis).Unit
	local mid = rootPos + dir * (l1 * cosA) + side * (l1 * sinA)
	return mid, rootPos + dir * dist
end

-- One limb: upper bone joint `j1` on `part0`, middle joint `j2`, end joint `j3`. `bend`: +1 arms (the hinge is the
-- bone's +X), -1 legs. `endRot`: the end part's world rotation (nil: straight on from the middle bone).
-- (30 Oct, owner: "don't make the inspect break my arm, that movement isn't organic") `maxWrist`: the most (degrees)
-- the end part may bend off the line of the middle bone; past it the end is turned back toward the bone (a twist
-- about the bone stays as asked: a forearm turns over freely, a wrist doesn't fold)
local function limb(part0: CFrame, j1: Joint, j2: Joint, j3: Joint, target: Vector3, pole: Vector3, bend: number, endRot: CFrame?, toHand: boolean?, maxWrist: number?)
	local a1 = j2.C0.Position - j1.C1.Position
	-- (arms reach with the middle of the fist, not the wrist)
	local a2 = if toHand then j3.C0.Position - j3.C1.Position - j2.C1.Position else j3.C0.Position - j2.C1.Position
	local l1, l2 = a1.Magnitude, a2.Magnitude
	local rootPos = (part0 * j1.C0).Position
	local mid, tip = solve(rootPos, target, l1, l2, pole)
	local d1 = (mid - rootPos).Unit
	local d2 = (tip - mid).Unit
	local h = d1:Cross(d2) * bend
	if h.Magnitude < 1e-3 then
		local p = pole - d1 * pole:Dot(d1)
		h = p:Cross(d1) * bend
	end
	local upper = aim(part0, j1, frameFor(a1.Unit, Vector3.xAxis, d1, h))
	local lower = aim(upper, j2, frameFor(a2.Unit, Vector3.xAxis, d2, h))
	if endRot then
		if maxWrist then
			local u, f = endRot.UpVector, lower.UpVector
			local angle = math.acos(math.clamp(u:Dot(f), -1, 1))
			local limit = math.rad(maxWrist)
			local axis = u:Cross(f)
			if angle > limit and axis.Magnitude > 1e-4 then
				endRot = CFrame.fromAxisAngle(axis.Unit, angle - limit) * endRot
			end
		end
		aim(lower, j3, endRot)
	else
		j3.Transform = CFrame.identity
	end
end

local function exp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- The floor under each foot (model space), found once per mower.
local function floors(rider: Rider, origin: CFrame, spec: MowerSeats.Spec): { number }
	if rider.floor then
		return rider.floor
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { rider.model :: Model }
	local out = {}
	for i, side in { -1, 1 } do
		local from = origin * Vector3.new(side * spec.feet.x, spec.cushion + 0.2, spec.feet.z)
		local hit = workspace:Raycast(from, -origin.UpVector * 3, params)
		out[i] = if hit then math.clamp(origin:PointToObjectSpace(hit.Position).Y, spec.cushion - 1.6, spec.cushion - 0.2) else spec.cushion - 0.6
	end
	rider.floor = out
	return out
end

local hideGear: (Rider, CFrame, number) -> ()
local showGear: (Rider) -> ()

local STYLE = {
	-- how much each stance moves: bounce, lean-in, look-around
	hunch = { bounce = 1.2, lean = 1.0, look = 0.8, buzz = 1.4 },
	proud = { bounce = 0.9, lean = 0.7, look = 1.0, buzz = 1.0 },
	chill = { bounce = 0.8, lean = 0.8, look = 1.2, buzz = 0.8 },
	beast = { bounce = 1.3, lean = 1.1, look = 0.7, buzz = 1.6 },
	comfy = { bounce = 0.9, lean = 0.8, look = 1.0, buzz = 0.9 },
	racer = { bounce = 0.7, lean = 1.5, look = 0.6, buzz = 1.2 },
}

local function pose(rider: Rider, dt: number, now: number)
	local spec = rider.spec :: MowerSeats.Spec
	local model = rider.model :: Model
	local body = model.PrimaryPart
	local j = rider.joints
	local hrp = rider.hum.RootPart
	if not body or not hrp then
		return
	end
	local style = STYLE[spec.style] or STYLE.proud
	local origin = body.CFrame * CFrame.new(0, -1.2, 0)

	-- the ride: turn rate, speed, speeding up, bumps
	local up = origin.UpVector
	local vel = body.AssemblyLinearVelocity
	local yawRate = body.AssemblyAngularVelocity:Dot(up)
	local fwd = vel:Dot(origin.LookVector)
	local speed = math.abs(fwd)
	local accel = (fwd - rider.lastFwd) / math.max(dt, 1 / 240)
	rider.lastFwd = fwd
	rider.accel += (math.clamp(accel, -80, 80) - rider.accel) * exp(6, dt)
	local vy = vel:Dot(up)
	local ay = (vy - rider.lastVy) / math.max(dt, 1 / 240)
	rider.lastVy = vy

	rider.steer += (math.clamp(yawRate * 0.55, -1.05, 1.05) - rider.steer) * exp(9, dt)
	local rollWant = math.clamp(yawRate * (0.05 + speed * 0.003), -0.24, 0.24) * style.lean
	rider.roll += (rollWant - rider.roll) * exp(5, dt)
	local pitchWant = math.clamp(rider.accel * 0.006, -0.14, 0.14)
	rider.pitch += (pitchWant - rider.pitch) * exp(5, dt)
	-- the spring in the seat: kicked by the mower's bumps, plus the road at speed
	local kick = math.clamp(ay, -120, 120) * 0.0016 + math.sin(now * 9.3 + rider.phase) * speed * 0.0009 * style.bounce
	rider.bounceV += (-170 * rider.bounce - 13 * rider.bounceV) * dt - kick
	rider.bounce = math.clamp(rider.bounce + rider.bounceV * dt, -0.14, 0.12)
	local buzz = math.sin(now * 41 + rider.phase) * 0.012 * style.buzz * (0.6 + math.min(speed / 30, 1))
	local breathe = math.sin(now * 1.7 + rider.phase) * 0.012

	-- the hips: lean, turn lean and rock, then lowered until the thighs rest on the cushion
	local lean = -math.rad(spec.lean) + rider.pitch
	local rootRot = CFrame.Angles(lean + breathe * 0.5, rider.steer * 0.08, rider.roll)
	local rootM = j.Root
	local lt0 = place(hrp.CFrame, rootM, rootRot)
	local hipM = j.LeftHip
	local hipY = origin:PointToObjectSpace((lt0 * hipM.C0).Position).Y
	local thigh = (hipM.Parent :: BasePart).Size.Z / 2
	local dy = (spec.cushion + thigh - 0.06) - hipY + rider.bounce + buzz
	-- (the lift is along the mower's up, written in the joint's own frame)
	local lift = (hrp.CFrame * rootM.C0):VectorToObjectSpace(up * dy)
	rootM.Transform = CFrame.new(lift) * rootRot
	local lt = place(hrp.CFrame, rootM, rootM.Transform)

	-- the chest twists a little with the wheel and leans with the turn; the head stays level and looks into it
	local waistT = CFrame.Angles(breathe, rider.steer * 0.12, rider.roll * 0.35)
	j.Waist.Transform = waistT
	local ut = place(lt, j.Waist, waistT)
	j.Neck.Transform = CFrame.Angles(-(lean + breathe) * 0.75, rider.steer * 0.3 * style.look, -rider.roll * 1.1)

	-- hands
	local leftT, rightT
	local wheel = spec.wheel
	if wheel then
		local n = Vector3.xAxis:Cross(wheel.u)
		local function rim(deg: number): Vector3
			local a = math.rad(deg) + rider.steer
			return origin * (wheel.c + (Vector3.xAxis * math.cos(a) + wheel.u * math.sin(a)) * wheel.r + n * 0.06)
		end
		rightT = rim(wheel.grip)
		leftT = rim(180 - wheel.grip)
		local sm = rider.steerMotor
		if sm and sm.Parent then
			sm.Transform = CFrame.Angles(0, 0, rider.steer)
		end
	else
		local g = spec.grips :: { Vector3 }
		-- zero-turn: push one bar, pull the other to turn
		local push = rider.steer * 0.12
		leftT = origin * (g[1] + Vector3.new(0, 0, push))
		rightT = origin * (g[2] - Vector3.new(0, 0, push))
	end
	local function arm(side: string, target: Vector3, s: number)
		-- elbows out and down; the fist carries straight on from the forearm
		local pole = origin:VectorToWorldSpace(Vector3.new(s * spec.elbows, -0.8, 0.35))
		limb(ut, j[side .. "Shoulder"], j[side .. "Elbow"], j[side .. "Wrist"], target, pole, 1, nil, true)
	end
	arm("Left", leftT, -1)
	arm("Right", rightT, 1)

	-- legs: feet on the floor, knees up and a little out
	local fl = floors(rider, origin, spec)
	local function leg(side: string, s: number, floorY: number)
		local ankle = j[side .. "Ankle"]
		local footPart = ankle.Parent :: BasePart
		local ankleY = floorY + footPart.Size.Y / 2 + ankle.C1.Position.Y
		local target = origin * Vector3.new(s * spec.feet.x, ankleY, spec.feet.z + rider.bounce * 0.5)
		local pole = origin:VectorToWorldSpace(Vector3.new(s * spec.knees, 0.7, -1))
		local footRot = origin.Rotation * CFrame.Angles(0, -s * 0.12, 0)
		limb(lt, j[side .. "Hip"], j[side .. "Knee"], ankle, target, pole, -1, footRot)
	end
	leg("Left", -1, fl[1])
	leg("Right", 1, fl[2])
	-- (looked up again twice a second: a tool can be equipped mid-ride)
	if not rider.listed or math.floor(now * 2) ~= math.floor((now - dt) * 2) then
		rider.listed = true
		showGear(rider)
		hideGear(rider, origin, spec.cushion)
	else
		for _, d in rider.hidden do
			d.LocalTransparencyModifier = 1
		end
	end
end

-- While riding, the tool in your hand and the vacuum's hose (it hangs to the ground from your hip) would poke through
-- the mower: hide them on this screen only, and show them again when you get off.
function hideGear(rider: Rider, origin: CFrame, cushion: number)
	local list = rider.hidden
	table.clear(list)
	local tool = rider.char:FindFirstChildOfClass("Tool")
	if tool then
		for _, d in tool:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
				table.insert(list, d)
			end
		end
	end
	local vac = rider.char:FindFirstChild("VacuumPack")
	if vac then
		for _, d in vac:GetDescendants() do
			if d:IsA("BasePart") and origin:PointToObjectSpace(d.Position).Y < cushion then
				d.LocalTransparencyModifier = 1
				table.insert(list, d)
			end
		end
	end
end

function showGear(rider: Rider)
	for _, d in rider.hidden do
		if d.Parent then
			d.LocalTransparencyModifier = 0
		end
	end
	table.clear(rider.hidden)
end

-- Two-handed tools: where the left hand holds on, in the tool's Handle space (measured from the models, 29 Oct):
-- a fixed handle (`at`), or anywhere along a shaft from `from` to `to` (the end nearest the right fist first).
-- (30 Oct, owner: "still looks like a torch", then research + an LLM council) `rest`: how the tool is carried while
-- no swing plays, in the root part's space (X right, Y up, -Z ahead): where the right fist is, the way the shaft runs
-- from it toward the head and the way the blade stands out from the head. Both arms are laid out to it here, over
-- Animate's arm-straight-out tool pose (the torch), and the left hand takes `restLeft` (handle space) on the shaft.
-- The Mega Scythe at rest: carried at port arms, the grim reaper's way: the right fist low in front of the right
-- hip, the snath rising from it across the chest, the left fist on it in front of the left breast, the head up past
-- the left shoulder and the blade hooked forward over it, its edge down
type Rest = { fist: Vector3, dir: Vector3, blade: Vector3 }
type Grip = { at: Vector3?, from: Vector3?, to: Vector3?, rest: Rest?, restLeft: Vector3?, follow: { string }? }
local SECOND_GRIP: { [string]: Grip } = {
	MegaScythe = {
		from = Vector3.new(0, 0, 0.2),
		to = Vector3.new(0, 0, -3.2), -- the snath above the fist
		-- (30 Oct, owner: "I'm holding it like I'm looking at it instead of using it as a weapon": over the shoulder the
		-- snath stood up in front of your face and the blade arched over it, like a trophy) now held in a low guard,
		-- ready to reap: the snath points ahead and to the left from the right hip, the head out in front at chest
		-- height and the blade hanging from it down toward the grass, edge in
		-- (30 Oct, owner: "now match the third person pov with the animation you just put in") held the way the first-
		-- person scythe is (client/ViewModel HOLD_DIR / HOLD_UP, Rivals' hold): the right fist in front of the right
		-- hip, the snath running out to the left and ahead, rising a little, the left fist far up it near the head, and
		-- the blade coming back from the head flat and level toward your front, edge forward. `follow`: the swings
		-- (client/ViewAnims ReapF / ReapB / ReapBig) move it here too, from the same keys
		rest = { fist = Vector3.new(0.45, -0.2, -0.75), dir = Vector3.new(-0.837, 0.149, -0.526), blade = Vector3.new(0.547, 0.204, -0.812) },
		restLeft = Vector3.new(0, 0, -0.9), -- (as far up the snath as the left arm reaches)
		follow = { "ReapF", "ReapB", "ReapBig", "InspectScythe", "InspectScytheBaton", "InspectScytheToss" },
	},
	WeedWhacker = { at = Vector3.new(0, 0.75, -1.27) }, -- the front loop handle
}
local holders: { [Model]: Joints | false } = {}
local restWeight: { [Model]: number } = {}

-- (30 Oct) which first-person clip a body's swing track is (by its name, or else its uploaded id)
local CLIP_OF: { [string]: string } = {}
for _, map in { WeaponAnimIds, AnimIds } do
	for key, id in map do
		if type(key) == "string" and key:sub(1, 4) == "mow_" then
			CLIP_OF[id] = key:sub(5)
		end
	end
end
local FOLLOW_MOVE = 0.3 -- studs per first-person unit the fist moves (the view's big drops would sink it into the floor)
local FPS = 60
-- (30 Oct) the inspects other players are playing (server/Main passes each one on), by when they started
local othersInspect: { [Player]: { name: string, at: number } } = {}
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("MowALawnRemotes", 30)
	local remote = remotes and remotes:WaitForChild("Inspect", 30)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(who: any, name: any)
			if typeof(who) == "Instance" and who:IsA("Player") and type(name) == "string" and ViewAnims.CLIPS[name] then
				othersInspect[who] = { name = name, at = os.clock() }
			end
		end)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	othersInspect[p] = nil
end)

-- (the body's own swing track, client/BodyAnims: it plays in third person too, holds on the hit-stop, and is what
-- everyone else sees; then an inspect: yours from client/ViewAnims, anyone else's as server/Main passed it on)
local function followed(hum: Humanoid, names: { string }, player: Player?): (string?, number)
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, tr in animator:GetPlayingAnimationTracks() do
			local name = if table.find(names, tr.Name) then tr.Name else tr.Animation and CLIP_OF[tr.Animation.AnimationId]
			if name and table.find(names, name) then
				return name, tr.TimePosition * FPS
			end
		end
	end
	if player == Players.LocalPlayer then
		local name, frame = ViewAnims.playing("R")
		if name and table.find(names, name) then
			return name, frame
		end
	elseif player then
		local ins = othersInspect[player]
		if ins and table.find(names, ins.name) then
			local clip = ViewAnims.CLIPS[ins.name]
			local frame = (os.clock() - ins.at) * FPS * ViewAnims.inspectRate("MegaScythe")
			if clip and frame < clip.len then
				return ins.name, frame
			end
			othersInspect[player] = nil
		end
	end
	return nil, 0
end

-- how much of a swing is playing on this body (0..1): the swings are one-shot tracks over Action2 (client/BodyAnims)
local SWING_PRIORITY = { [Enum.AnimationPriority.Action2] = true, [Enum.AnimationPriority.Action3] = true, [Enum.AnimationPriority.Action4] = true }
local function swinging(hum: Humanoid): number
	local animator = hum:FindFirstChildOfClass("Animator")
	local m = 0
	if animator then
		for _, tr in animator:GetPlayingAnimationTracks() do
			if not tr.Looped and SWING_PRIORITY[tr.Priority] then
				m = math.max(m, tr.WeightCurrent)
			end
		end
	end
	return m
end

-- The left hand onto a two-handed tool's second grip, after this frame's animation (the right hand's grip is worked
-- out from this frame's joints, so the left hand never lags it).
local function holdTwoHanded(char: Model, hum: Humanoid, tool: Tool, grip: Grip, dt: number, player: Player?)
	local j = holders[char]
	if not j then
		j = findJoints(char) -- (not cached until the body has all its joints)
		if not j then
			return
		end
		holders[char] = j
	end
	local hrp = hum.RootPart
	local hand = char:FindFirstChild("RightHand")
	local weld = hand and hand:FindFirstChild("RightGrip")
	if not hrp or not weld or not weld:IsA("JointInstance") or weld.Part1 ~= tool:FindFirstChild("Handle") then
		return
	end
	local lt = place(hrp.CFrame, j.Root, j.Root.Transform)
	local ut = place(lt, j.Waist, j.Waist.Transform)
	-- at rest (no swing playing; it eases in and out over ~0.15 s) the right arm carries the tool the `rest` way
	local rw = 0
	local rest = grip.rest
	if rest then
		local goal = if grip.follow then 1 else 1 - swinging(hum)
		local was = restWeight[char] or goal
		rw = was + (goal - was) * math.min(1, dt * 14)
		restWeight[char] = rw
		if rw > 0.01 then
			-- (RestFist / RestDir / RestBlade attributes on the tool override these, for tuning in a playtest)
			local fistAt = tool:GetAttribute("RestFist") :: Vector3? or rest.fist
			local d = hrp.CFrame:VectorToWorldSpace(tool:GetAttribute("RestDir") :: Vector3? or rest.dir).Unit
			local b = hrp.CFrame:VectorToWorldSpace(tool:GetAttribute("RestBlade") :: Vector3? or rest.blade)
			b = (b - d * b:Dot(d)).Unit
			local rot = CFrame.lookAt(Vector3.zero, d, b) -- the handle: -Z up the shaft to the head, +Y the blade
			local fist = hrp.CFrame:PointToWorldSpace(fistAt)
			if grip.follow then
				-- a swing: the same keys as the first-person one, about the fist in the body's axes (the body turn B
				-- about the middle of the body, the scythe R about the fist, T spins the blade round the snath)
				local name, frame = followed(hum, grip.follow, player)
				if name then
					local r = ViewAnims.sample(name, "R", frame)
					local bp = ViewAnims.sample(name, "B", frame)
					local tp = ViewAnims.sample(name, "T", frame)
					local axes = hrp.CFrame.Rotation
					if r then
						local move = r.p * FOLLOW_MOVE
						local local0 = fistAt + Vector3.new(move.X, math.max(move.Y, -0.7), move.Z)
						fist = hrp.CFrame:PointToWorldSpace(local0)
						rot = axes * CFrame.Angles(math.rad(r.r.X), math.rad(r.r.Y), math.rad(r.r.Z)) * axes:Inverse() * rot
					end
					if bp then
						local turn = axes * CFrame.Angles(math.rad(bp.r.X), math.rad(bp.r.Y), math.rad(bp.r.Z)) * axes:Inverse()
						fist = hrp.Position + turn:VectorToWorldSpace(fist - hrp.Position)
						rot = turn * rot
					end
					if tp then
						rot = rot * CFrame.Angles(0, 0, math.rad(tp.r.Z))
					end
				end
			end
			local handleGoal = rot + (fist - rot:VectorToWorldSpace(weld.C1.Position))
			local handGoal = handleGoal * weld.C1 * weld.C0:Inverse()
			local s0, e0, w0 = j.RightShoulder.Transform, j.RightElbow.Transform, j.RightWrist.Transform
			-- (30 Oct) the elbow goes where the forearm would carry on from the hand (up its own axis), so the wrist
			-- stays nearly straight; what's left over is capped at 25 degrees (the hand, and so the scythe, gives
			-- way a little instead)
			local foreLen = (j.RightWrist.C0.Position - j.RightWrist.C1.Position - j.RightElbow.C1.Position).Magnitude
			local idealElbow = handGoal.Position + handGoal.UpVector * (foreLen + 0.3)
			local shoulderPos = (ut * j.RightShoulder.C0).Position
			local pole = (idealElbow - shoulderPos) + hrp.CFrame:VectorToWorldSpace(Vector3.new(0.2, -0.3, 0))
			limb(ut, j.RightShoulder, j.RightElbow, j.RightWrist, handGoal.Position, pole, 1, handGoal.Rotation, true, 25)
			if rw < 1 then
				local e = rw * rw * (3 - 2 * rw)
				j.RightShoulder.Transform = s0:Lerp(j.RightShoulder.Transform, e)
				j.RightElbow.Transform = e0:Lerp(j.RightElbow.Transform, e)
				j.RightWrist.Transform = w0:Lerp(j.RightWrist.Transform, e)
			end
		end
	end
	local ua = place(ut, j.RightShoulder, j.RightShoulder.Transform)
	local la = place(ua, j.RightElbow, j.RightElbow.Transform)
	local rh = place(la, j.RightWrist, j.RightWrist.Transform)
	local handle = rh * weld.C0 * weld.C1:Inverse()
	local target: Vector3
	if grip.at then
		target = handle * grip.at
	else
		local a, b = handle * (grip.from :: Vector3), handle * (grip.to :: Vector3)
		local ab = b - a
		local shoulder = (ut * j.LeftShoulder.C0).Position
		target = a + ab * math.clamp((shoulder - a):Dot(ab) / ab:Dot(ab), 0, 1)
	end
	if grip.restLeft and rw > 0 then
		target = target:Lerp(handle * (tool:GetAttribute("RestLeft") :: Vector3? or grip.restLeft), rw) -- at rest: one fixed place on the shaft
	end
	-- out of reach (the grip holds it out to one side, a swing flings it far from the free hand): the hand lets go,
	-- fading back to the animation's arm over the last quarter of an arm's length
	local reach = (j.LeftElbow.C0.Position - j.LeftShoulder.C1.Position).Magnitude
		+ (j.LeftWrist.C0.Position - j.LeftWrist.C1.Position - j.LeftElbow.C1.Position).Magnitude
	local d = (target - (ut * j.LeftShoulder.C0).Position).Magnitude
	local w = math.clamp((reach * 1.25 - d) / (reach * 0.25), 0, 1)
	if w <= 0 then
		return
	end
	local s0, e0, w0 = j.LeftShoulder.Transform, j.LeftElbow.Transform, j.LeftWrist.Transform
	local pole = hrp.CFrame:VectorToWorldSpace(Vector3.new(-0.8, -0.7, 0.2))
	limb(ut, j.LeftShoulder, j.LeftElbow, j.LeftWrist, target, pole, 1, nil, true)
	if w < 1 then
		w = w * w * (3 - 2 * w)
		j.LeftShoulder.Transform = s0:Lerp(j.LeftShoulder.Transform, w)
		j.LeftElbow.Transform = e0:Lerp(j.LeftElbow.Transform, w)
		j.LeftWrist.Transform = w0:Lerp(j.LeftWrist.Transform, w)
	end
end

local function riderFor(char: Model, hum: Humanoid): Rider?
	local r = riders[char]
	local seat = hum.SeatPart
	local model = seat and seat.Parent
	local spec = model and model:IsA("Model") and seat.Name == "Seat" and MowerSeats.get(model:GetAttribute("Rider") :: string?)
	if not spec then
		if r then
			showGear(r)
			riders[char] = nil
		end
		return nil
	end
	if r and r.model == model then
		return r
	end
	if r then
		showGear(r)
	end
	local joints = findJoints(char)
	if not joints then
		return nil
	end
	local steerMotor: Motor6D? = nil
	for _, d in (model :: Model):GetDescendants() do
		if d:IsA("Motor6D") and d.Name == "Steer" then
			steerMotor = d
			break
		end
	end
	r = {
		char = char,
		hum = hum,
		joints = joints,
		model = model :: Model,
		spec = spec,
		floor = nil,
		steer = 0,
		roll = 0,
		pitch = 0,
		bounce = 0,
		bounceV = 0,
		lastVy = 0,
		lastFwd = 0,
		accel = 0,
		phase = math.random() * 10,
		steerMotor = steerMotor,
		hidden = {},
		listed = false,
	}
	riders[char] = r
	return r
end

local function step(dt: number)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and hum and hum.SeatPart and hum.Health > 0 then
			local root = hum.RootPart
			if root and (root.Position - camPos).Magnitude < FAR then
				local r = riderFor(char, hum)
				if r then
					local ok, err = pcall(pose, r, dt, now)
					if not ok then
						warn("[RiderPose] " .. tostring(err))
						showGear(r)
						riders[char] = nil
					end
				end
			end
		elseif char and riders[char] then
			local r = riders[char]
			riders[char] = nil
			showGear(r)
			if r.steerMotor and r.steerMotor.Parent then
				r.steerMotor.Transform = CFrame.identity
			end
		end
		-- on foot with a two-handed tool (not you in first person: your body is hidden then)
		if char and hum and not hum.SeatPart and hum.Health > 0 then
			local tool = char:FindFirstChildOfClass("Tool")
			local grip = tool and SECOND_GRIP[tool:GetAttribute("ToolId") :: string]
			local head = char:FindFirstChild("Head") :: BasePart?
			local root = hum.RootPart
			if grip and head and head.LocalTransparencyModifier < 0.5 and root and (root.Position - camPos).Magnitude < FAR then
				local ok, err = pcall(holdTwoHanded, char, hum, tool :: Tool, grip, dt, p)
				if not ok then
					warn("[RiderPose] " .. tostring(err))
					holders[char] = false
				end
			end
		end
	end
	for char in riders do
		if not char.Parent then
			riders[char] = nil
		end
	end
	for char in holders do
		if not char.Parent then
			holders[char] = nil
			restWeight[char] = nil
		end
	end
end

RunService.PreSimulation:Connect(step)

return RiderPose
