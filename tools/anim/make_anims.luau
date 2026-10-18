-- Builds Mow A Lawn's R15 character animations as Roblox KeyframeSequences, all from code.
--
--   lune run tools/anim/make_anims.luau            -- writes assets/anims/<name>.rbxm + <name>.json + rig.json
--   blender -b -P tools/anim/preview_anim.py       -- renders assets/previews/anim_<name>.png to check them
--   python3 tools/upload_models.py --anims         -- uploads the .rbxm files, writes src/shared/AnimIds.luau
--
-- How a Roblox animation is stored: KeyframeSequence > Keyframe (Time) > Pose "HumanoidRootPart" > Pose
-- "LowerTorso" > Pose "UpperTorso" > ... Each Pose is named after a body part and nested under the pose of the part
-- it hangs from. Its CFrame becomes the Motor6D.Transform of the joint that holds that part (Pose "LowerTorso" drives
-- the "Root" motor, "RightUpperLeg" drives "RightHip", ...), so it is a rotation (and for the root, a small offset)
-- about the joint, in the parent part's axes: X = right, Y = up, -Z = forward.
--
-- Sign guide (degrees): hip/shoulder +X swings the limb forward, knee -X bends it, elbow +X bends it, ankle +X lifts
-- the toes, waist/neck -X leans forward, +Y turns left, +Z tips the top towards the character's left. A right
-- arm/leg moves outwards with +Z, a left one with -Z.
--
-- The motions are designed as curves (key values at points of the cycle, joined by smooth splines, with delays on
-- the arms and head for follow-through) and baked to a keyframe every 1/30 s with Linear easing, so Roblox plays back
-- exactly the designed curves. Walk and run are grounded: after posing, the whole body is moved up or down so the
-- lowest foot touches the floor (the run adds a little hang time on top).
--
-- Walk and run are both 0.72 s and start on the right foot. The stock Animate script plays them together and
-- cross-fades by speed: at WalkSpeed 16 and above (everything in this game) only RUN shows, sped up by speed/12.8,
-- so it is the main "walking" animation (0.58 s per cycle at speed 16). WALK shows below speed 6.4 (gamepad
-- half-tilt), and the two blend in between - equal lengths keep their feet in step while blending.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local FPS = 30
local OUT = "assets/anims"

-------------------------------------------------------------------------------------------------------------
-- R15 rig (standard blocky R15 at scale 1). c0 = joint position on the parent part, c1 = on the part itself
-- (Motor6D C0 / C1, both unrotated). Leg chain from hip to sole adds up to the R15 HipHeight of 2 studs, and the
-- HumanoidRootPart's centre sits HipHeight + 1 = 3 studs above the floor. `box` is only for the preview:
-- {width, height, depth, centre y, centre z} in the part's own space.
-------------------------------------------------------------------------------------------------------------
local RIG = {
	{ part = "LowerTorso", parent = "HumanoidRootPart", c0 = { 0, -1, 0 }, c1 = { 0, -0.2, 0 }, box = { 2, 0.4, 1, 0, 0 } },
	{ part = "UpperTorso", parent = "LowerTorso", c0 = { 0, 0.2, 0 }, c1 = { 0, -0.8, 0 }, box = { 2, 1.6, 1, 0, 0 } },
	{ part = "Head", parent = "UpperTorso", c0 = { 0, 0.8, 0 }, c1 = { 0, -0.5, 0 }, box = { 1.25, 1.25, 1.25, 0.12, 0 } },
	{ part = "LeftUpperArm", parent = "UpperTorso", c0 = { -1, 0.563, 0 }, c1 = { 0.5, 0.394, 0 }, box = { 0.9, 0.9, 0.9, 0.02, 0 } },
	{ part = "LeftLowerArm", parent = "LeftUpperArm", c0 = { 0, -0.334, 0 }, c1 = { 0, 0.259, 0 }, box = { 0.85, 0.82, 0.85, -0.12, 0 } },
	{ part = "LeftHand", parent = "LeftLowerArm", c0 = { 0, -0.501, 0 }, c1 = { 0, 0.125, 0 }, box = { 0.8, 0.45, 0.8, -0.05, 0 } },
	{ part = "RightUpperArm", parent = "UpperTorso", c0 = { 1, 0.563, 0 }, c1 = { -0.5, 0.394, 0 }, box = { 0.9, 0.9, 0.9, 0.02, 0 } },
	{ part = "RightLowerArm", parent = "RightUpperArm", c0 = { 0, -0.334, 0 }, c1 = { 0, 0.259, 0 }, box = { 0.85, 0.82, 0.85, -0.12, 0 } },
	{ part = "RightHand", parent = "RightLowerArm", c0 = { 0, -0.501, 0 }, c1 = { 0, 0.125, 0 }, box = { 0.8, 0.45, 0.8, -0.05, 0 } },
	{ part = "LeftUpperLeg", parent = "LowerTorso", c0 = { -0.5, -0.2, 0 }, c1 = { 0, 0.421, 0 }, box = { 0.92, 0.95, 0.92, 0.0, 0 } },
	{ part = "LeftLowerLeg", parent = "LeftUpperLeg", c0 = { 0, -0.401, 0 }, c1 = { 0, 0.379, 0 }, box = { 0.86, 0.93, 0.86, -0.08, 0 } },
	{ part = "LeftFoot", parent = "LeftLowerLeg", c0 = { 0, -0.547, 0 }, c1 = { 0, 0.102, 0 }, box = { 0.86, 0.3, 1.15, 0, -0.12 } },
	{ part = "RightUpperLeg", parent = "LowerTorso", c0 = { 0.5, -0.2, 0 }, c1 = { 0, 0.421, 0 }, box = { 0.92, 0.95, 0.92, 0.0, 0 } },
	{ part = "RightLowerLeg", parent = "RightUpperLeg", c0 = { 0, -0.401, 0 }, c1 = { 0, 0.379, 0 }, box = { 0.86, 0.93, 0.86, -0.08, 0 } },
	{ part = "RightFoot", parent = "RightLowerLeg", c0 = { 0, -0.547, 0 }, c1 = { 0, 0.102, 0 }, box = { 0.86, 0.3, 1.15, 0, -0.12 } },
}
local ROOT_HEIGHT = 3
-- heel and toe of the sole, in foot space (used to keep the feet on the floor)
local SOLE = { { 0, -0.15, 0.45 }, { 0, -0.15, -0.69 } }

-------------------------------------------------------------------------------------------------------------
-- poses: { [part] = { x, y, z (degrees), px, py, pz (studs) } }
-------------------------------------------------------------------------------------------------------------
type Joint = { x: number, y: number, z: number, px: number, py: number, pz: number }
type Pose = { [string]: Joint }

local function newPose(): Pose
	local p = {}
	for _, j in RIG do
		p[j.part] = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }
	end
	return p
end

local function set(p: Pose, part: string, x: number?, y: number?, z: number?)
	local j = p[part]
	j.x, j.y, j.z = x or j.x, y or j.y, z or j.z
end

local function rad(d: number): number
	return d * math.pi / 180
end

local function transform(j: Joint)
	return CFrame.new(j.px, j.py, j.pz) * CFrame.Angles(rad(j.x), rad(j.y), rad(j.z))
end

local function v3cf(t: { number })
	return CFrame.new(t[1], t[2], t[3])
end

-- world CFrame of every part, root standing at ROOT_HEIGHT
local function fk(p: Pose): { [string]: any }
	local cf = { HumanoidRootPart = CFrame.new(0, ROOT_HEIGHT, 0) }
	for _, j in RIG do
		cf[j.part] = cf[j.parent] * v3cf(j.c0) * transform(p[j.part]) * v3cf(j.c1):Inverse()
	end
	return cf
end

local function lowestSole(p: Pose): number
	local cf = fk(p)
	local low = math.huge
	for _, foot in { "LeftFoot", "RightFoot" } do
		for _, s in SOLE do
			low = math.min(low, (cf[foot] * v3cf(s)).Position.Y)
		end
	end
	return low
end

-- Move the body so the lowest foot rests on the floor, then lift it by `air` studs.
local function ground(p: Pose, air: number?)
	p.LowerTorso.py -= lowestSole(p)
	p.LowerTorso.py += air or 0
end

-- Ankle angles that keep both soles level with the floor (pitch and roll).
local function flatFeet(p: Pose)
	for _, side in { "Left", "Right" } do
		local hip, knee, ankle = p[side .. "UpperLeg"], p[side .. "LowerLeg"], p[side .. "Foot"]
		ankle.x = -(p.LowerTorso.x + hip.x + knee.x)
		ankle.z = -(p.LowerTorso.z + hip.z + knee.z)
	end
end

-------------------------------------------------------------------------------------------------------------
-- curves
-------------------------------------------------------------------------------------------------------------
-- A looping curve through { {phase, value}, ... } (phases 0..1, sorted), as a smooth Catmull-Rom spline.
local function loop(keys: { { number } }): (number) -> number
	local n = #keys
	local function get(k: number): (number, number)
		local wrap = math.floor((k - 1) / n)
		local key = keys[(k - 1) % n + 1]
		return key[1] + wrap, key[2]
	end
	return function(phase: number): number
		local ph = phase % 1
		local i = n
		for k = 1, n do
			if keys[k][1] <= ph then
				i = k
			end
		end
		local p0, v0 = get(i - 1)
		local p1, v1 = get(i)
		local p2, v2 = get(i + 1)
		local p3, v3 = get(i + 2)
		if ph < p1 then
			ph += 1
		end
		local h = p2 - p1
		local s = (ph - p1) / h
		local m1 = (v2 - v0) / (p2 - p0) * h
		local m2 = (v3 - v1) / (p3 - p1) * h
		local s2, s3 = s * s, s * s * s
		return (2 * s3 - 3 * s2 + 1) * v1 + (s3 - 2 * s2 + s) * m1 + (-2 * s3 + 3 * s2) * v2 + (s3 - s2) * m2
	end
end

local function wave(phase: number, cycles: number?): number
	return math.cos(2 * math.pi * phase * (cycles or 1))
end

local function swave(phase: number, cycles: number?): number
	return math.sin(2 * math.pi * phase * (cycles or 1))
end

local EASE = {
	linear = function(s: number): number
		return s
	end,
	inOut = function(s: number): number
		return if s < 0.5 then 4 * s * s * s else 1 - (-2 * s + 2) ^ 3 / 2
	end,
	out = function(s: number): number
		return 1 - (1 - s) ^ 3
	end,
	-- overshoots a little and settles: the "pop" of a cartoon pose
	backOut = function(s: number): number
		local c = 1.3
		return 1 + (c + 1) * (s - 1) ^ 3 + c * (s - 1) ^ 2
	end,
}

-------------------------------------------------------------------------------------------------------------
-- shared pieces
-------------------------------------------------------------------------------------------------------------
-- Relaxed standing pose: arms a little away from the body, soft elbows and knees.
local function rest(p: Pose)
	set(p, "RightUpperArm", 2, 0, 6)
	set(p, "LeftUpperArm", 2, 0, -6)
	set(p, "RightLowerArm", 10)
	set(p, "LeftLowerArm", 10)
	set(p, "RightUpperLeg", 2)
	set(p, "LeftUpperLeg", 2)
	set(p, "RightLowerLeg", -4)
	set(p, "LeftLowerLeg", -4)
	flatFeet(p)
end

-- Head keeps looking where the body is going: undo most of the torso's turn and tilt.
local function steadyHead(p: Pose, amount: number)
	local lt, ut = p.LowerTorso, p.UpperTorso
	p.Head.x += -(lt.x + ut.x) * amount
	p.Head.y += -(lt.y + ut.y) * amount
	p.Head.z += -(lt.z + ut.z) * amount
end

-- hip and knee angles, and the foot's pitch against the floor (+ = toes up, 0 = flat); the ankle is worked out
type Leg = { hip: (number) -> number, knee: (number) -> number, foot: (number) -> number }

-- Puts one leg cycle on both legs (left half a cycle behind), with the pelvis lean taken out of the hips.
local function legs(p: Pose, phase: number, leg: Leg, splay: number)
	for side, offset in { Right = 0, Left = 0.5 } do
		local ph = phase + offset
		local out = if side == "Right" then splay else -splay
		set(p, side .. "UpperLeg", leg.hip(ph) - p.LowerTorso.x, 0, out - p.LowerTorso.z)
		set(p, side .. "LowerLeg", -leg.knee(ph))
		set(p, side .. "Foot", leg.foot(ph) - leg.hip(ph) + leg.knee(ph), 0, -out)
	end
end

-------------------------------------------------------------------------------------------------------------
-- WALK  (phase 0 = right heel down in front; 0.1 down; 0.25 passing; 0.37 up; 0.5 left heel down)
-------------------------------------------------------------------------------------------------------------
local WALK_LEG: Leg = {
	hip = loop({ { 0, 27 }, { 0.12, 19 }, { 0.3, 1 }, { 0.5, -19 }, { 0.6, -22 }, { 0.72, -3 }, { 0.85, 22 }, { 0.93, 29 } }),
	knee = loop({ { 0, 3 }, { 0.1, 32 }, { 0.25, 8 }, { 0.4, 2 }, { 0.55, 26 }, { 0.66, 54 }, { 0.76, 60 }, { 0.88, 22 }, { 0.96, 2 } }),
	foot = loop({ { 0, 18 }, { 0.08, 0 }, { 0.26, 0 }, { 0.38, -16 }, { 0.46, -24 }, { 0.53, -30 }, { 0.6, -42 }, { 0.68, -40 }, { 0.78, -18 }, { 0.88, 0 }, { 0.95, 14 } }),
}

local function walk(t: number, length: number): Pose
	local ph = t / length
	local p = newPose()
	-- pelvis: turns with the forward leg, sways over the standing foot
	local lt = p.LowerTorso
	lt.x = -2
	lt.y = 7 * wave(ph)
	lt.z = 2.5 * swave(ph)
	lt.px = 0.06 * swave(ph)
	legs(p, ph, WALK_LEG, 2)
	-- chest: counter-twists (shoulders against hips), dips forward on each down, bobs back up
	set(p, "UpperTorso", -5 - 2.5 * wave(ph - 0.1, 2), -15 * wave(ph - 0.04), -3 * swave(ph - 0.05))
	-- head: steady, with a small late nod
	set(p, "Head", 2 * wave(ph - 0.2, 2))
	steadyHead(p, 0.8)
	-- arms: opposite to the legs; elbows and hands trail behind the shoulder (follow-through)
	for side, offset in { Right = 0, Left = 0.5 } do
		local a = ph + offset
		local s = if side == "Right" then 1 else -1
		set(p, side .. "UpperArm", 4 - 34 * wave(a - 0.05), 0, s * (7 + 2 * swave(a - 0.1)))
		set(p, side .. "LowerArm", 22 + 15 * wave(a - 0.63))
		set(p, side .. "Hand", 8 * wave(a - 0.75))
	end
	ground(p)
	return p
end

-------------------------------------------------------------------------------------------------------------
-- RUN  (phase 0 = right foot lands; 0.08 squash on it; 0.32 push off; 0.32-0.5 in the air; 0.5 left lands)
-------------------------------------------------------------------------------------------------------------
local RUN_LEG: Leg = {
	hip = loop({ { 0, 26 }, { 0.08, 16 }, { 0.2, -8 }, { 0.32, -34 }, { 0.42, -28 }, { 0.55, 4 }, { 0.68, 46 }, { 0.8, 52 }, { 0.92, 34 } }),
	knee = loop({ { 0, 16 }, { 0.08, 32 }, { 0.15, 34 }, { 0.24, 20 }, { 0.32, 8 }, { 0.42, 60 }, { 0.52, 108 }, { 0.64, 104 }, { 0.78, 66 }, { 0.9, 26 } }),
	foot = loop({ { 0, 8 }, { 0.06, 0 }, { 0.18, 0 }, { 0.26, -18 }, { 0.32, -48 }, { 0.42, -85 }, { 0.52, -125 }, { 0.64, -100 }, { 0.76, -45 }, { 0.86, -8 }, { 0.94, 10 } }),
}

local function runPose(ph: number): Pose
	local p = newPose()
	local lt = p.LowerTorso
	lt.x = -6
	lt.y = 10 * wave(ph)
	lt.z = 3 * swave(ph)
	lt.px = 0.08 * swave(ph)
	legs(p, ph, RUN_LEG, 3)
	-- leaning into it; the chest loads forward on each landing
	set(p, "UpperTorso", -12 - 4 * wave(ph - 0.1, 2), -22 * wave(ph - 0.04), -3.5 * swave(ph - 0.06))
	set(p, "Head", 3 * wave(ph - 0.22, 2))
	steadyHead(p, 0.85)
	-- arms pump hard, elbows bent, fists snapping through a beat late
	for side, offset in { Right = 0, Left = 0.5 } do
		local a = ph + offset
		local s = if side == "Right" then 1 else -1
		set(p, side .. "UpperArm", -2 - 54 * wave(a - 0.04), 0, s * (13 + 4 * swave(a - 0.1)))
		set(p, side .. "LowerArm", 52 + 24 * wave(a - 0.62))
		set(p, side .. "Hand", 10 * wave(a - 0.72))
	end
	return p
end

-- On the ground the lowest foot is pinned to the floor; in the air (push-off to landing) the body follows a hop
-- arc from where it left the ground to where it lands.
local RUN_FLIGHT = { 0.32, 0.5 }
local RUN_HOP = 0.2
local function run(t: number, length: number): Pose
	local ph = (t / length) % 1
	local p = runPose(ph)
	local lift = -lowestSole(p)
	local step = if ph >= 0.5 then 0.5 else 0
	local a, b = RUN_FLIGHT[1] + step, RUN_FLIGHT[2] + step
	if ph > a and ph < b then
		local s = (ph - a) / (b - a)
		local from, to = -lowestSole(runPose(a)), -lowestSole(runPose(b))
		lift = math.max(lift, from + (to - from) * s + RUN_HOP * math.sin(math.pi * s))
	end
	p.LowerTorso.py += lift
	return p
end

-------------------------------------------------------------------------------------------------------------
-- IDLE  (3 s: two breaths, a slow weight shift side to side)
-------------------------------------------------------------------------------------------------------------
local function idleBase(t: number, length: number): Pose
	local ph = t / length
	local p = newPose()
	rest(p)
	local breath = swave(ph, 2) -- chest up at +1
	local shift = swave(ph) -- weight on the right at +1
	local lt = p.LowerTorso
	lt.px = 0.07 * shift
	lt.z = 1.6 * shift
	-- legs stay planted under a moving pelvis: lean them against the shift, bend the free knee
	local lean = math.deg(math.asin(lt.px / 2))
	for side, s in { Right = 1, Left = -1 } do
		local knee = 5 - 3.5 * shift * s
		set(p, side .. "UpperLeg", knee * 0.5 + 1, 0, -lt.z - lean)
		set(p, side .. "LowerLeg", -knee)
	end
	flatFeet(p)
	set(p, "UpperTorso", -1.5 + 1.8 * breath, 2 * swave(ph + 0.15), -1.3 * shift)
	set(p, "Head", 1 - 1.2 * swave(ph - 0.06, 2), 3 * swave(ph + 0.3), 1.5 * swave(ph - 0.1))
	for side, s in { Right = 1, Left = -1 } do
		local b = swave(ph - 0.05, 2)
		set(p, side .. "UpperArm", 3 + 1.5 * b, 0, s * (6 + 2 * b))
		set(p, side .. "LowerArm", 12 + 3 * swave(ph - 0.1, 2))
		set(p, side .. "Hand", 4 + 2 * swave(ph - 0.15, 2))
	end
	ground(p)
	return p
end

-- Variant the Animate script mixes in now and then: a look to the left, then to the right.
local LOOK = { { 0, 0 }, { 0.12, 0 }, { 0.28, 48 }, { 0.46, 44 }, { 0.6, -42 }, { 0.78, -38 }, { 0.92, 0 } }
local function idleLook(t: number, length: number): Pose
	local p = idleBase(t, 3)
	local ph = t / length
	local look = 0
	for i = 1, #LOOK - 1 do
		local a, b = LOOK[i], LOOK[i + 1]
		if ph >= a[1] and ph <= b[1] then
			look = a[2] + (b[2] - a[2]) * EASE.inOut((ph - a[1]) / (b[1] - a[1]))
		end
	end
	p.Head.y += look * 0.75
	p.Head.z += look * 0.08
	p.UpperTorso.y += look * 0.25
	p.Head.x += math.abs(look) * 0.06 -- chin up a touch while looking around
	return p
end

-------------------------------------------------------------------------------------------------------------
-- pose-to-pose (jump, cheer): keys { time, ease, function(p) ... end, air }
-------------------------------------------------------------------------------------------------------------
type Key = { t: number, ease: string, build: (Pose) -> (), air: number? }

local function keyed(keys: { Key }, grounded: boolean): (number) -> Pose
	local built = {}
	for i, k in keys do
		local p = newPose()
		k.build(p)
		built[i] = p
	end
	return function(t: number): Pose
		local i = 1
		while i < #keys and keys[i + 1].t <= t do
			i += 1
		end
		local j = math.min(i + 1, #keys)
		local s = if j == i then 0 else (t - keys[i].t) / (keys[j].t - keys[i].t)
		s = EASE[keys[j].ease](math.clamp(s, 0, 1))
		local a, b = built[i], built[j]
		local p = newPose()
		for part, joint in p do
			for _, c in { "x", "y", "z", "px", "py", "pz" } do
				local va, vb = (a[part] :: any)[c], (b[part] :: any)[c]
				;(joint :: any)[c] = va + (vb - va) * s
			end
		end
		if grounded then
			local airA, airB = keys[i].air or 0, keys[j].air or 0
			ground(p, airA + (airB - airA) * s)
		end
		return p
	end
end

local function both(p: Pose, part: string, x: number, y: number, z: number)
	set(p, "Right" .. part, x, y, z)
	set(p, "Left" .. part, x, -y, -z)
end

-- JUMP: plays from take-off for ~0.3 s, then the Animate script fades to FALL
local jumpKeys = keyed({
	{ t = 0, ease = "linear", build = function(p)
		p.LowerTorso.x = -6
		set(p, "UpperTorso", -12)
		set(p, "Head", 8)
		both(p, "UpperLeg", 34, 0, 3)
		both(p, "LowerLeg", -52, 0, 0)
		both(p, "Foot", 14, 0, 0)
		both(p, "UpperArm", -42, 0, 10)
		both(p, "LowerArm", 22, 0, 0)
	end },
	{ t = 0.13, ease = "backOut", build = function(p)
		p.LowerTorso.x = 2
		set(p, "UpperTorso", 6)
		set(p, "Head", 6)
		set(p, "RightUpperLeg", 58, 0, 4)
		set(p, "RightLowerLeg", -84)
		set(p, "RightFoot", 12)
		set(p, "LeftUpperLeg", -14, 0, -3)
		set(p, "LeftLowerLeg", -12)
		set(p, "LeftFoot", -38)
		both(p, "UpperArm", 140, 0, 44)
		both(p, "LowerArm", 18, 0, 0)
		both(p, "Hand", 10, 0, 0)
	end },
	{ t = 0.5, ease = "inOut", build = function(p)
		set(p, "UpperTorso", 4)
		set(p, "Head", 6)
		set(p, "RightUpperLeg", 36, 0, 4)
		set(p, "RightLowerLeg", -56)
		set(p, "RightFoot", -6)
		set(p, "LeftUpperLeg", -6, 0, -3)
		set(p, "LeftLowerLeg", -30)
		set(p, "LeftFoot", -22)
		both(p, "UpperArm", 108, 0, 56)
		both(p, "LowerArm", 28, 0, 0)
		both(p, "Hand", 8, 0, 0)
	end },
}, false)

-- FALL: arms up in a V with a little flail, legs bent and slowly pedalling (loops)
local function fall(t: number, length: number): Pose
	local ph = t / length
	local p = newPose()
	set(p, "UpperTorso", 4 + 2 * swave(ph, 2))
	set(p, "Head", 6 - 2 * swave(ph - 0.1, 2))
	for side, s in { Right = 1, Left = -1 } do
		local o = if s > 0 then 0 else 0.5
		set(p, side .. "UpperArm", 104 + 12 * swave(ph * 2 + o), 0, s * (58 + 9 * swave(ph * 2 + o - 0.12)))
		set(p, side .. "LowerArm", 28 + 12 * swave(ph * 2 + o - 0.2))
		set(p, side .. "Hand", 10 * swave(ph * 2 + o - 0.3))
		local hip = (if s > 0 then 32 else -4) + 9 * swave(ph + o)
		set(p, side .. "UpperLeg", hip, 0, s * 4)
		set(p, side .. "LowerLeg", -((if s > 0 then 52 else 34) + 12 * swave(ph + o + 0.15)))
		set(p, side .. "Foot", -16 + 6 * swave(ph + o + 0.25))
	end
	return p
end

-- CHEER: crouch, jump with both arms up, land, two fist pumps, settle (the stock "/e cheer" emote slot)
local function crouch(p: Pose, depth: number)
	p.LowerTorso.x = -depth * 0.15
	both(p, "UpperLeg", depth * 0.6, 0, 3)
	both(p, "LowerLeg", -depth, 0, 0)
	flatFeet(p)
end

local cheerKeys = keyed({
	{ t = 0, ease = "linear", build = rest },
	{ t = 0.2, ease = "inOut", build = function(p)
		crouch(p, 34)
		set(p, "UpperTorso", -12)
		set(p, "Head", -4)
		both(p, "UpperArm", -32, 0, 14)
		both(p, "LowerArm", 30, 0, 0)
	end },
	{ t = 0.38, ease = "backOut", air = 0.7, build = function(p)
		set(p, "UpperTorso", 8)
		set(p, "Head", 12)
		both(p, "UpperArm", 166, 0, 30)
		both(p, "LowerArm", 8, 0, 0)
		both(p, "Hand", -10, 0, 0)
		both(p, "UpperLeg", 26, 0, 4)
		both(p, "LowerLeg", -50, 0, 0)
		both(p, "Foot", -24, 0, 0)
	end },
	{ t = 0.58, ease = "inOut", build = function(p)
		crouch(p, 30)
		set(p, "UpperTorso", -8)
		set(p, "Head", 6)
		both(p, "UpperArm", 150, 0, 40)
		both(p, "LowerArm", 20, 0, 0)
	end },
	{ t = 0.8, ease = "backOut", build = function(p)
		crouch(p, 8)
		set(p, "UpperTorso", 4, 12, 2)
		set(p, "Head", 8, -6)
		set(p, "RightUpperArm", 172, 0, 14)
		set(p, "RightLowerArm", 16)
		set(p, "LeftUpperArm", 30, 0, -10)
		set(p, "LeftLowerArm", 96)
	end },
	{ t = 0.98, ease = "inOut", build = function(p)
		crouch(p, 14)
		set(p, "UpperTorso", -2, 10, 2)
		set(p, "Head", 2, -5)
		set(p, "RightUpperArm", 124, 0, 18)
		set(p, "RightLowerArm", 70)
		set(p, "LeftUpperArm", 26, 0, -10)
		set(p, "LeftLowerArm", 100)
	end },
	{ t = 1.16, ease = "backOut", build = function(p)
		crouch(p, 8)
		set(p, "UpperTorso", 5, 12, 2)
		set(p, "Head", 10, -6)
		set(p, "RightUpperArm", 176, 0, 12)
		set(p, "RightLowerArm", 10)
		set(p, "LeftUpperArm", 30, 0, -10)
		set(p, "LeftLowerArm", 96)
	end },
	{ t = 1.42, ease = "inOut", build = function(p)
		rest(p)
		crouch(p, 10)
		set(p, "UpperTorso", -2)
		both(p, "UpperArm", 8, 0, 8)
		both(p, "LowerArm", 16, 0, 0)
	end },
	{ t = 1.7, ease = "inOut", build = rest },
}, true)

-------------------------------------------------------------------------------------------------------------
-- the animation list
-------------------------------------------------------------------------------------------------------------
type Anim = { name: string, length: number, loop: boolean, priority: any, fps: number, endKey: boolean, pose: (number, number) -> Pose }

local ANIMS: { Anim } = {
	{ name = "idle", length = 3, loop = true, priority = Enum.AnimationPriority.Idle, fps = 20, endKey = true, pose = idleBase },
	{ name = "idle_look", length = 3, loop = true, priority = Enum.AnimationPriority.Idle, fps = 20, endKey = true, pose = idleLook },
	{ name = "walk", length = 0.72, loop = true, priority = Enum.AnimationPriority.Movement, fps = FPS, endKey = true, pose = walk },
	{ name = "run", length = 0.72, loop = true, priority = Enum.AnimationPriority.Movement, fps = FPS, endKey = true, pose = run },
	-- no "End" keyframe on jump: the Animate script would restart it there
	{ name = "jump", length = 0.5, loop = false, priority = Enum.AnimationPriority.Movement, fps = FPS, endKey = false, pose = function(t)
		return jumpKeys(t)
	end },
	{ name = "fall", length = 0.8, loop = true, priority = Enum.AnimationPriority.Movement, fps = FPS, endKey = false, pose = fall },
	-- "End" on cheer tells the Animate script the emote is over and it goes back to idle
	{ name = "cheer", length = 1.7, loop = false, priority = Enum.AnimationPriority.Action, fps = FPS, endKey = true, pose = function(t)
		return cheerKeys(t)
	end },
}

-------------------------------------------------------------------------------------------------------------
-- bake to instances + JSON
-------------------------------------------------------------------------------------------------------------
local function round(v: number): number
	return math.floor(v * 10000 + 0.5) / 10000
end

local function bake(anim: Anim)
	local seq = Instance.new("KeyframeSequence")
	seq.Name = anim.name
	seq.Loop = anim.loop
	seq.Priority = anim.priority
	seq.AuthoredHipHeight = 2
	local frames = math.floor(anim.length * anim.fps + 0.5)
	local json = { name = anim.name, length = anim.length, loop = anim.loop, keyframes = {} }
	for f = 0, frames do
		local t = anim.length * f / frames
		-- a loop's last frame repeats its first, so it joins up exactly
		local pose = anim.pose(if anim.loop and f == frames then 0 else t, anim.length)
		local kf = Instance.new("Keyframe")
		kf.Time = round(t)
		if f == frames and anim.endKey then
			kf.Name = "End"
		end
		local rootPose = Instance.new("Pose")
		rootPose.Name = "HumanoidRootPart"
		rootPose.Weight = 1
		rootPose.Parent = kf
		local made = { HumanoidRootPart = rootPose }
		local poses = {}
		for _, j in RIG do
			local cf = transform(pose[j.part])
			local inst = Instance.new("Pose")
			inst.Name = j.part
			inst.CFrame = cf
			inst.Weight = 1
			inst.EasingStyle = Enum.PoseEasingStyle.Linear
			inst.EasingDirection = Enum.PoseEasingDirection.InOut
			inst.Parent = made[j.parent]
			made[j.part] = inst
			local comps = { cf:GetComponents() }
			for i, v in comps do
				comps[i] = round(v)
			end
			poses[j.part] = comps
		end
		kf.Parent = seq
		table.insert(json.keyframes, { t = round(t), poses = poses })
	end
	return seq, json
end

local only = {}
for _, a in process.args do
	only[a] = true
end
if not fs.isDir(OUT) then
	fs.writeDir(OUT)
end
local rig = { root_height = ROOT_HEIGHT, sole = SOLE, joints = RIG }
fs.writeFile(OUT .. "/rig.json", serde.encode("json", rig, true))
for _, anim in ANIMS do
	if next(only) == nil or only[anim.name] then
		local seq, json = bake(anim)
		fs.writeFile(OUT .. "/" .. anim.name .. ".rbxm", roblox.serializeModel({ seq }))
		fs.writeFile(OUT .. "/" .. anim.name .. ".json", serde.encode("json", json))
		print(("%-10s %.2f s  %3d keyframes  %s"):format(anim.name, anim.length, #json.keyframes, if anim.loop then "loop" else "once"))
	end
end
