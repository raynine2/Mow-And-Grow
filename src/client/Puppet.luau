-- PUPPET (Films v2, 5 Nov 2026; owner: "make my model rayan poep hoof the owner of town", and the films rebuilt "like an
-- anime fight"): avatars acted by code. A live game can only play animations uploaded to the owner's account, so the
-- films' people are posed here instead. A puppet is a copy of an R15 character with its joints taken out and every
-- part anchored; each frame its parts are placed by forward kinematics from the joints' own offsets (an
-- AnimationConstraint's two attachments, or a Motor6D's C0 / C1), so any R15 body works (blocky, Rthro, the owner's).
-- Poses are snappy on purpose (anime timing: hold a strong pose, snap to the next in a few frames).
--   Puppet.new(model, opts?) -> Puppet     the model is cloned (opts.name, opts.parent)
--   pup.root = CFrame                        where it stands (its HumanoidRootPart; the film moves this)
--   pup:pose(pose, time?, ease?)             blend to a pose (Puppet.POSES[name] or a table: joint = Vector3 degrees,
--                                            and `hip` = Vector3 studs, the body's offset from the root) over `time`
--   pup:walk(weight, rate?, style?)          a walk cycle on top (weight 0 = off; rate = cycles a second)
--   pup:look(point?, amount?)                the head (and a little the chest) turned to a point in the world
--   pup:update(dt)                           place everything (every frame, with the film's dt)
--   pup:part(name) / pup:grip(side) -> CFrame  a body part, a hand's grip point (for props)
--   pup:show(on) / pup:ghost(color, alpha, life) / pup:destroy()
local TweenService = game:GetService("TweenService")

local Puppet = {}

local rad = math.rad
local ORDER = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist",
	"LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle",
}
Puppet.JOINTS = ORDER
local ZERO = Vector3.zero

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-------------------------------------------------------------------------------------------------------------
-- poses (degrees per joint; +X always swings forward: a limb forward, the body (Root, Waist) bowing, the head nodding
-- down; Z swings a right limb out (a left one with -Z) and tilts the head; Y twists (+ to its left); knees bend with
-- -X, elbows with +X). Joints a pose doesn't name go back to rest.
-------------------------------------------------------------------------------------------------------------
local P = {}
P.rest = {}
-- (rh / lh: where a reaching wrist goes, in the chest's space: x right, y up, -z ahead; the shoulders sit at
-- (+-0.85, 0.56, 0) and an arm reaches about 1.6. rpole / lpole: the way the elbow points.)
P.stand = { -- relaxed, weight on one leg
	LeftShoulder = v(2, 0, -6), RightShoulder = v(2, 0, 6), LeftElbow = v(8, 0, 0), RightElbow = v(8, 0, 0),
	LeftHip = v(2, 0, -2), RightHip = v(-2, 4, 3), RightKnee = v(-4, 0, 0), Waist = v(0, 0, 1),
}
P.cool = { -- the hero stance: chin up, chest out, arms loose
	Waist = v(-4, 0, 0), Neck = v(-6, 0, 0),
	LeftShoulder = v(-4, 0, -10), RightShoulder = v(-4, 0, 10), LeftElbow = v(12, 0, 0), RightElbow = v(12, 0, 0),
	LeftHip = v(0, -6, -5), RightHip = v(0, 6, 5),
}
-- Rayan with the shears resting on his right shoulder (his right hand by his shoulder, the blades behind him)
P.shoulder = {
	Waist = v(-3, -6, 0), Neck = v(-4, 8, 0),
	rh = v(0.75, 0.75, -0.75), rpole = v(1, -1, 0.3),
	LeftShoulder = v(4, 0, -8), LeftElbow = v(10, 0, 0),
	LeftHip = v(0, -5, -4), RightHip = v(0, 5, 4),
}
-- dragging the closed shears behind him in his right hand
P.drag = {
	Waist = v(-2, 8, 0), Neck = v(-3, -6, 0),
	rh = v(1.05, -0.95, 0.55), rpole = v(1, 0, -1),
	LeftShoulder = v(6, 0, -8), LeftElbow = v(12, 0, 0),
}
-- two hands on the handles, shears open wide in front (the snip about to close)
P.snipOpen = {
	Waist = v(4, 18, 0), Neck = v(-8, -14, 0),
	rh = v(1.2, -0.05, -1.05), lh = v(-1.2, -0.05, -1.05), rpole = v(1, -1, 0.5), lpole = v(-1, -1, 0.5),
	LeftHip = v(28, 0, -8), LeftKnee = v(-34, 0, 0), RightHip = v(-22, 0, 8), RightKnee = v(-16, 0, 0),
	hip = v(0, -0.45, 0),
}
-- the snip closed: hands together, thrust through
P.snipShut = {
	Waist = v(10, -26, 0), Neck = v(-12, 22, 0),
	rh = v(0.2, 0.05, -1.5), lh = v(-0.2, 0.05, -1.5), rpole = v(1, -1, 0.3), lpole = v(-1, -1, 0.3),
	LeftHip = v(34, 0, -10), LeftKnee = v(-40, 0, 0), RightHip = v(-26, 0, 10), RightKnee = v(-20, 0, 0),
	hip = v(0, -0.6, 0.2),
}
-- in the air, shears open overhead (a leaping snip)
P.leapOpen = {
	Waist = v(-16, 0, 0), Neck = v(-14, 0, 0),
	rh = v(0.95, 1.75, -0.45), lh = v(-0.95, 1.75, -0.45), rpole = v(1, 0, 1), lpole = v(-1, 0, 1),
	LeftHip = v(40, 0, -10), LeftKnee = v(-90, 0, 0), RightHip = v(-10, 0, 10), RightKnee = v(-60, 0, 0),
}
-- landed low after a cut, one knee down, shears out to the side
P.landCut = {
	Waist = v(26, -20, 0), Neck = v(-26, 18, 0),
	rh = v(2.0, -0.1, -0.5), rpole = v(0, -1, 1), lh = v(-0.55, -1.25, -0.9), lpole = v(-1, 0, 1),
	LeftHip = v(70, 0, -14), LeftKnee = v(-80, 0, 0), RightHip = v(-10, 0, 16), RightKnee = v(-100, 0, 0), RightAnkle = v(40, 0, 0),
	hip = v(0, -1.55, 0),
}
-- blocked: the blade stopped, arms jarred back
P.jolt = {
	Waist = v(-16, 10, 0), Neck = v(-14, -10, 0),
	rh = v(0.6, 0.45, -0.95), lh = v(-0.45, 0.4, -0.95), rpole = v(1, -1, 0), lpole = v(-1, -1, 0),
	LeftHip = v(-10, 0, -6), RightHip = v(16, 0, 6), RightKnee = v(-20, 0, 0),
}
-- knocked flying: back arched, limbs trailing
P.flung = {
	Root = v(-30, 0, 10), Waist = v(-24, 0, 0), Neck = v(-30, 0, 0),
	RightShoulder = v(120, 0, 70), RightElbow = v(30, 0, 0),
	LeftShoulder = v(100, 0, -80), LeftElbow = v(40, 0, 0),
	LeftHip = v(30, 0, -10), LeftKnee = v(-50, 0, 0), RightHip = v(-10, 0, 14), RightKnee = v(-30, 0, 0),
}
-- getting up out of the wreck: one knee down, a hand on it
P.kneel = {
	Waist = v(30, 0, 0), Neck = v(-10, 0, 0),
	RightShoulder = v(10, 0, 20), RightElbow = v(20, 0, 0),
	lh = v(-0.45, -1.35, -0.85), lpole = v(-1, 0, 1),
	LeftHip = v(80, 0, -6), LeftKnee = v(-80, 0, 0), RightHip = v(-10, 0, 10), RightKnee = v(-100, 0, 0), RightAnkle = v(30, 0, 0),
	hip = v(0, -1.5, 0),
}
-- the neck crack: head tipped to one side, then the other
P.crackL = { Waist = v(-2, 0, 0), Neck = v(0, 0, 26), LeftShoulder = v(2, 0, -8), RightShoulder = v(2, 0, 8), LeftElbow = v(10, 0, 0), RightElbow = v(10, 0, 0), LeftHip = v(0, -5, -4), RightHip = v(0, 5, 4) }
P.crackR = { Waist = v(-2, 0, 0), Neck = v(0, 0, -26), LeftShoulder = v(2, 0, -8), RightShoulder = v(2, 0, 8), LeftElbow = v(10, 0, 0), RightElbow = v(10, 0, 0), LeftHip = v(0, -5, -4), RightHip = v(0, 5, 4) }
-- the ultimate's stance: low and wide, turned, both hands at the right hip, the shears level and open
P.ultStance = {
	Waist = v(14, 40, 0), Neck = v(-14, -38, 0),
	rh = v(1.15, -0.85, 0.35), lh = v(0.35, -0.75, -0.55), rpole = v(1, 0, 1), lpole = v(-0.5, -1, 0),
	LeftHip = v(46, 0, -22), LeftKnee = v(-62, 0, 0), RightHip = v(-20, 0, 26), RightKnee = v(-40, 0, 0),
	hip = v(0, -1.2, 0),
}
-- the ultimate's follow-through: turned right round, the shears shut level out to the left
P.ultCut = {
	Waist = v(10, -56, 0), Neck = v(-10, 48, 0),
	rh = v(-0.55, -0.3, -1.3), lh = v(-1.35, -0.35, -0.6), rpole = v(1, -1, 0), lpole = v(-1, -1, 0),
	LeftHip = v(30, 0, -26), LeftKnee = v(-40, 0, 0), RightHip = v(-30, 0, 26), RightKnee = v(-36, 0, 0),
	hip = v(0, -1.0, 0),
}
-- crushed under the blow: braced, arms up over his head
P.brace = {
	Waist = v(20, 0, 0), Neck = v(-30, 0, 0),
	rh = v(0.55, 1.6, -0.55), lh = v(-0.55, 1.6, -0.55), rpole = v(1, 0, 0), lpole = v(-1, 0, 0),
	LeftHip = v(30, 0, -14), LeftKnee = v(-60, 0, 0), RightHip = v(-6, 0, 14), RightKnee = v(-50, 0, 0),
	hip = v(0, -1.0, 0),
}
-- THE PLAYER: the superhero landing (one knee down, one fist on the ground, the other arm back)
P.heroLand = {
	Waist = v(38, 0, 0), Neck = v(-30, 0, 0),
	rh = v(0.55, -1.5, -0.75), rpole = v(1, 0, 1),
	lh = v(-1.35, -0.45, 0.75), lpole = v(-1, -1, 0),
	LeftHip = v(70, 0, -10), LeftKnee = v(-70, 0, 0), RightHip = v(-20, 0, 18), RightKnee = v(-110, 0, 0), RightAnkle = v(40, 0, 0),
	hip = v(0, -1.6, 0),
}
-- standing up out of the landing, head up
P.heroRise = {
	Waist = v(6, 0, 0), Neck = v(-12, 0, 0),
	RightShoulder = v(4, 0, 12), RightElbow = v(20, 0, 0),
	LeftShoulder = v(4, 0, -12), LeftElbow = v(20, 0, 0),
	LeftHip = v(10, 0, -8), LeftKnee = v(-14, 0, 0), RightHip = v(-8, 0, 8), RightKnee = v(-10, 0, 0),
	hip = v(0, -0.2, 0),
}
-- the wind-up: right fist pulled right back, left arm out front aiming, body coiled
P.windup = {
	Waist = v(8, 50, 0), Neck = v(-8, -46, 0),
	rh = v(1.05, 0.35, 0.95), rpole = v(1, -0.4, 1),
	lh = v(-0.25, 0.45, -1.45), lpole = v(-1, -1, 0),
	LeftHip = v(40, 0, -20), LeftKnee = v(-40, 0, 0), RightHip = v(-30, 0, 16), RightKnee = v(-30, 0, 0),
	hip = v(0, -0.7, 0.3),
}
-- the punch: right arm thrown dead straight, body turned through, front knee bent, left fist back at the hip
P.punch = {
	Waist = v(14, -38, 0), Neck = v(-12, 34, 0),
	rh = v(0.55, 0.55, -2.4), rpole = v(1, -1, 0),
	lh = v(-0.8, -0.25, 0.55), lpole = v(-1, -0.3, 1),
	LeftHip = v(46, 0, -22), LeftKnee = v(-46, 0, 0), RightHip = v(-40, 0, 20), RightKnee = v(-10, 0, 0),
	hip = v(0, -0.8, -0.6),
}
-- looking up at something (hands loose)
P.lookUp = {
	Waist = v(-10, 0, 0), Neck = v(-30, 0, 0),
	LeftShoulder = v(4, 0, -8), RightShoulder = v(4, 0, 8), LeftElbow = v(10, 0, 0), RightElbow = v(10, 0, 0),
}
-- one hand up, catching something above and ahead (the copy catches the blade)
P.catch = {
	Waist = v(-6, 20, 0), Neck = v(-16, -10, 0),
	rh = v(0.45, 1.5, -1.0), rpole = v(1, 0, 0.5), RightWrist = v(-20, 0, 0),
	LeftShoulder = v(0, 0, -10), LeftElbow = v(12, 0, 0),
	LeftHip = v(4, -6, -6), RightHip = v(-4, 6, 6),
}
-- holding the shears up in one hand, looking at them
P.inspect = {
	Waist = v(-4, 10, 0), Neck = v(-6, -14, 0),
	rh = v(0.4, 0.35, -1.25), rpole = v(1, -1, 0),
	LeftShoulder = v(0, 0, -8), LeftElbow = v(10, 0, 0),
}
-- the realm opened: shears raised high in one hand
P.raise = {
	Waist = v(-10, 0, 0), Neck = v(-20, 0, 0),
	rh = v(0.6, 2.0, -0.25), rpole = v(1, 0, 0),
	LeftShoulder = v(10, 0, -30), LeftElbow = v(20, 0, 0),
	LeftHip = v(0, 0, -8), RightHip = v(0, 0, 8),
}
-- thrown back, sliding on the ground on his back
P.down = {
	Root = v(-80, 0, 0), Waist = v(-10, 0, 0), Neck = v(20, 0, 0),
	RightShoulder = v(40, 0, 60), LeftShoulder = v(30, 0, -70), RightElbow = v(30, 0, 0), LeftElbow = v(20, 0, 0),
	LeftHip = v(30, 0, -10), LeftKnee = v(-50, 0, 0), RightHip = v(10, 0, 10), RightKnee = v(-20, 0, 0),
	hip = v(0, -2.2, 0),
}
Puppet.POSES = P

-------------------------------------------------------------------------------------------------------------
-- easing
-------------------------------------------------------------------------------------------------------------
local EASE: { [string]: (number) -> number } = {
	linear = function(k)
		return k
	end,
	out = function(k)
		return 1 - (1 - k) ^ 3
	end,
	inn = function(k)
		return k * k * k
	end,
	inOut = function(k)
		return if k < 0.5 then 4 * k * k * k else 1 - (-2 * k + 2) ^ 3 / 2
	end,
	snap = function(k) -- (anime: almost all of the move in the first third, a little settle after)
		return 1 - (1 - k) ^ 6
	end,
	back = function(k) -- (overshoots a little and settles)
		local c1, c3 = 1.9, 2.9
		return 1 + c3 * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
	end,
}
Puppet.EASE = EASE

-------------------------------------------------------------------------------------------------------------
-- building
-------------------------------------------------------------------------------------------------------------
type Joint = { name: string, parent: BasePart, child: BasePart, c0: CFrame, c1: CFrame, c1inv: CFrame }
type Stuck = { part: BasePart, base: BasePart, rel: CFrame }

local function stripScripts(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Animator") or d:IsA("ForceField") or d:IsA("Sound") or d:IsA("TouchTransmitter") then
			d:Destroy()
		end
	end
end

-- The joints of an R15 body: AnimationConstraints first (the avatar joint upgrade), then Motor6Ds.
local function readJoints(m: Model): { [string]: Joint }
	local found: { [string]: Joint } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent and a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
				found[d.Name] = { name = d.Name, parent = a0.Parent :: BasePart, child = a1.Parent :: BasePart, c0 = a0.CFrame, c1 = a1.CFrame, c1inv = a1.CFrame:Inverse() }
			end
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") and not found[d.Name] and d.Part0 and d.Part1 then
			found[d.Name] = { name = d.Name, parent = d.Part0 :: BasePart, child = d.Part1 :: BasePart, c0 = d.C0, c1 = d.C1, c1inv = d.C1:Inverse() }
		end
	end
	return found
end

export type Puppet = any

-- Make a puppet from a character model (it's cloned; the original isn't touched).
function Puppet.new(source: Model, opts: { name: string?, parent: Instance? }?): Puppet
	local o = opts or {}
	local was = source.Archivable
	source.Archivable = true
	local m = source:Clone()
	source.Archivable = was
	m.Name = o.name or ("Puppet_" .. source.Name)
	stripScripts(m)
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		hum.EvaluateStateMachine = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.NameDisplayDistance = 0
		hum.HealthDisplayDistance = 0
		hum.PlatformStand = true
	end
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(hrp, "Puppet: no HumanoidRootPart")
	local found = readJoints(m)
	-- (joints in an order where every parent is placed before its children)
	local joints: { Joint } = {}
	local placed: { [BasePart]: boolean } = { [hrp] = true }
	local left = {}
	for _, j in found do
		table.insert(left, j)
	end
	for _ = 1, 20 do
		local again = {}
		for _, j in left do
			if placed[j.parent] then
				table.insert(joints, j)
				placed[j.child] = true
			else
				table.insert(again, j)
			end
		end
		left = again
		if #left == 0 then
			break
		end
	end
	-- everything else stuck to the body (accessories by their welds, anything else as it stands now)
	local stuck: { Stuck } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Weld") or d:IsA("Motor6D") and not found[d.Name] then
			local w = d :: any
			local p0, p1 = w.Part0, w.Part1
			if p0 and p1 then
				-- Part0.CFrame * C0 == Part1.CFrame * C1
				if placed[p1] and not placed[p0] then
					table.insert(stuck, { part = p0, base = p1, rel = w.C1 * w.C0:Inverse() })
					placed[p0] = true
				elseif placed[p0] and not placed[p1] then
					table.insert(stuck, { part = p1, base = p0, rel = w.C0 * w.C1:Inverse() })
					placed[p1] = true
				end
			end
		elseif d:IsA("WeldConstraint") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 then
				if placed[p1] and not placed[p0] then
					table.insert(stuck, { part = p0, base = p1, rel = p1.CFrame:ToObjectSpace(p0.CFrame) })
					placed[p0] = true
				elseif placed[p0] and not placed[p1] then
					table.insert(stuck, { part = p1, base = p0, rel = p0.CFrame:ToObjectSpace(p1.CFrame) })
					placed[p1] = true
				end
			end
		elseif d:IsA("RigidConstraint") then
			-- (an accessory on a character in the world: AccessoryRigidConstraint, its two attachments held together)
			local a0, a1 = d.Attachment0, d.Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if a0 and a1 and p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				if placed[p1] and not placed[p0] then
					table.insert(stuck, { part = p0, base = p1, rel = a1.CFrame * a0.CFrame:Inverse() })
					placed[p0] = true
				elseif placed[p0] and not placed[p1] then
					table.insert(stuck, { part = p1, base = p0, rel = a0.CFrame * a1.CFrame:Inverse() })
					placed[p1] = true
				end
			end
		end
	end
	-- take the joints out, anchor everything
	for _, d in m:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("AnimationConstraint") or d:IsA("RigidConstraint") or d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") then
			d:Destroy()
		end
	end
	local parts: { BasePart } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if placed[d] then
				table.insert(parts, d)
			else
				d.Transparency = 1 -- (something loose we can't place: hidden)
			end
		end
	end
	m.PrimaryPart = hrp

	local self: any = {}
	self.model = m
	self.root = hrp.CFrame
	self.hrp = hrp
	self.angles = {} :: { [string]: Vector3 }
	self.hip = ZERO
	self.t = 0
	-- the blend
	self.from = {} :: { [string]: Vector3 }
	self.to = {} :: { [string]: Vector3 }
	self.hipFrom, self.hipTo = ZERO, ZERO
	self.blendT0, self.blendLen = 0, 0
	self.ease = EASE.out
	-- the walk
	self.walkW, self.walkWTo, self.walkRate, self.walkPhase = 0, 0, 1.6, 0
	self.walkStyle = "calm"
	self.walkArms = true
	-- the look
	self.lookAt = nil :: Vector3?
	self.lookAmt = 0
	self.lookW = 0
	-- the shake (a hit: the body jolts)
	self.jolt = 0
	for _, name in ORDER do
		self.angles[name] = ZERO
		self.from[name] = ZERO
		self.to[name] = ZERO
	end
	local byName: { [string]: BasePart } = {}
	for _, p in parts do
		byName[p.Name] = p
	end
	self.byName = byName
	self.joints = joints
	-- the arms' chains, for reaching (a pose's rh / lh: where the wrist goes)
	self.arms = {}
	for _, side in { "Right", "Left" } do
		local sh, el, wr = found[side .. "Shoulder"], found[side .. "Elbow"], found[side .. "Wrist"]
		if sh and el and wr then
			local b1 = el.c0.Position - sh.c1.Position
			local b2 = wr.c0.Position - el.c1.Position
			self.arms[side] = {
				sh = sh, el = el, wr = wr,
				l1 = b1.Magnitude, l2 = b2.Magnitude,
				b1 = b1.Unit, b2 = b2.Unit,
				-- the reach: from (where it was) to (where it's going), its weight eased the same way
				from = ZERO, to = ZERO, w = 0, wFrom = 0, wTo = 0,
				pole = if side == "Right" then v(1.2, -1, 1) else v(-1.2, -1, 1),
				poleFrom = ZERO, poleTo = ZERO,
				now = ZERO, -- (where the wrist was last frame, in the chest's space)
			}
		end
	end
	self.stuck = stuck
	self.parts = parts
	self.world = {} :: { [BasePart]: CFrame }
	self.cfs = table.create(#parts, CFrame.identity)
	self.shown = true
	m.Parent = o.parent or workspace
	return setmetatable(self, { __index = Puppet })
end

-------------------------------------------------------------------------------------------------------------
-- acting
-------------------------------------------------------------------------------------------------------------
-- Blend to `pose` (a name in POSES or a table) over `time` seconds of film time, eased (`ease`: a name in EASE).
function Puppet.pose(self: any, pose: any, time: number?, ease: string?)
	local p = if type(pose) == "string" then P[pose] else pose
	assert(p, "Puppet: no pose " .. tostring(pose))
	for _, name in ORDER do
		self.from[name] = self.angles[name]
		self.to[name] = p[name] or ZERO
	end
	self.hipFrom = self.hip
	self.hipTo = p.hip or ZERO
	self.blendT0 = self.t
	self.blendLen = time or 0
	self.ease = EASE[ease or "out"] or EASE.out
	for side, a in self.arms do
		local want = if side == "Right" then p.rh else p.lh
		local pole = if side == "Right" then p.rpole else p.lpole
		a.from = if a.w > 0.01 then a.cur or a.now else a.now
		a.to = want or a.from
		a.wFrom = a.w
		a.wTo = if want then 1 else 0
		a.poleFrom = a.poleNow or a.pole
		a.poleTo = pole or a.pole
	end
	if (time or 0) <= 0 then
		for _, name in ORDER do
			self.angles[name] = self.to[name]
		end
		self.hip = self.hipTo
		for _, a in self.arms do
			a.w = a.wTo
			a.cur = a.to
			a.poleNow = a.poleTo
		end
	end
end

-- Two-bone reach: the upper and lower arm placed so the wrist is at `target` (world), the elbow toward `pole`.
local function orient(bLocal: Vector3, bWorld: Vector3, hinge: Vector3): CFrame
	local xL = (Vector3.xAxis - bLocal * Vector3.xAxis:Dot(bLocal)).Unit
	local zL = xL:Cross(bLocal)
	local zW = hinge:Cross(bWorld)
	return CFrame.fromMatrix(Vector3.zero, hinge, bWorld, zW) * CFrame.fromMatrix(Vector3.zero, xL, bLocal, zL):Inverse()
end

local function reach(a: any, shoulder: Vector3, target: Vector3, pole: Vector3): (CFrame, CFrame)
	local d = target - shoulder
	local dist = math.clamp(d.Magnitude, 0.05, a.l1 + a.l2 - 0.001)
	local dir = if d.Magnitude > 1e-4 then d.Unit else Vector3.new(0, -1, 0)
	local perp = pole - dir * pole:Dot(dir)
	if perp.Magnitude < 1e-3 then
		perp = Vector3.new(0, -1, 0) - dir * (-dir.Y)
		if perp.Magnitude < 1e-3 then
			perp = Vector3.zAxis
		end
	end
	perp = perp.Unit
	local cosA = math.clamp((a.l1 * a.l1 + dist * dist - a.l2 * a.l2) / (2 * a.l1 * dist), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local elbow = shoulder + dir * (a.l1 * cosA) + perp * (a.l1 * sinA)
	local wrist = shoulder + dir * dist
	local bone = (elbow - shoulder).Unit
	local fore = (wrist - elbow)
	fore = if fore.Magnitude > 1e-4 then fore.Unit else bone
	local hinge = perp:Cross(dir).Unit
	local upper = CFrame.new(shoulder) * orient(a.b1, bone, hinge) * CFrame.new(-a.sh.c1.Position)
	local lower = CFrame.new(elbow) * orient(a.b2, fore, hinge) * CFrame.new(-a.el.c1.Position)
	return upper, lower
end

-- The walk cycle on top of the pose (`weight` 0..1, eased in over a quarter second), `rate` cycles a second,
-- `style`: "calm" (the default), "cool" (a slow, loose swagger) or "stalk" (heavy, deliberate); `arms` false keeps
-- the pose's arms (something held).
function Puppet.walk(self: any, weight: number, rate: number?, style: string?, arms: boolean?)
	self.walkWTo = weight
	if rate then
		self.walkRate = rate
	end
	if style then
		self.walkStyle = style
	end
	self.walkArms = arms ~= false
end

-- How far a walk cycle carries it: studs a second at the current rate (move the root by this).
function Puppet.stride(self: any): number
	local legs = 2.3 -- (a blocky body's leg)
	local amp = if self.walkStyle == "cool" then 22 else 26
	return 2 * 2 * legs * math.sin(rad(amp)) * self.walkRate
end

function Puppet.look(self: any, point: Vector3?, amount: number?)
	self.lookAt = point
	self.lookAmt = amount or 1
end

function Puppet.shake(self: any, amount: number)
	self.jolt = math.max(self.jolt, amount)
end

function Puppet.part(self: any, name: string): BasePart?
	return self.byName[name]
end

-- A hand's grip point (where a held thing's handle goes), as it stands this frame.
function Puppet.grip(self: any, side: string): CFrame
	local hand = self.byName[side .. "Hand"] :: BasePart?
	if not hand then
		return self.root
	end
	local att = hand:FindFirstChild(side .. "GripAttachment") :: Attachment?
	local cf = self.world[hand] or hand.CFrame
	return if att then cf * att.CFrame else cf * CFrame.new(0, -hand.Size.Y / 2, 0)
end

function Puppet.show(self: any, on: boolean)
	if on == self.shown then
		return
	end
	self.shown = on
	for _, p in self.parts do
		p.LocalTransparencyModifier = if on then 0 else 1
	end
	for _, d in self.model:GetDescendants() do
		if d:IsA("Decal") then
			d.LocalTransparencyModifier = if on then 0 else 1
		end
	end
end

-- An afterimage: a flat glowing copy of the body as it stands now, fading over `life`.
function Puppet.ghost(self: any, color: Color3, alpha: number?, life: number?, parent: Instance?): Model
	local g = Instance.new("Model")
	g.Name = "Afterimage"
	for _, p in self.parts do
		if p.Transparency < 1 and p ~= self.hrp then
			local c = p:Clone()
			for _, d in c:GetChildren() do
				if not d:IsA("SpecialMesh") then
					d:Destroy()
				end
			end
			if c:IsA("MeshPart") then
				(c :: MeshPart).TextureID = ""
			end
			c.Material = Enum.Material.Neon
			c.Color = color
			c.Transparency = alpha or 0.55
			c.CastShadow = false
			c.Parent = g
			TweenService:Create(c, TweenInfo.new(life or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end
	g.Parent = parent or self.model.Parent
	task.delay((life or 0.35) + 0.05, function()
		g:Destroy()
	end)
	return g
end

local function walkPose(phase: number, style: string): ({ [string]: Vector3 }, Vector3)
	local s, c = math.sin(phase), math.cos(phase)
	local amp = if style == "cool" then 22 else 26
	local arm = if style == "cool" then 12 else if style == "stalk" then 8 else 20
	local knee = if style == "stalk" then 40 else 48
	local swingL = math.max(0, c) -- (a leg swings through while its hip angle is rising)
	local swingR = math.max(0, -c)
	local out = {
		LeftHip = v(s * amp, 0, 0),
		RightHip = v(-s * amp, 0, 0),
		LeftKnee = v(-(swingL ^ 1.4) * knee - 6, 0, 0),
		RightKnee = v(-(swingR ^ 1.4) * knee - 6, 0, 0),
		LeftAnkle = v(math.max(0, -s) * 14 - swingL * 10, 0, 0),
		RightAnkle = v(math.max(0, s) * 14 - swingR * 10, 0, 0),
		LeftShoulder = v(-s * arm, 0, 0),
		RightShoulder = v(s * arm, 0, 0),
		LeftElbow = v(8 + math.max(0, -s) * 10, 0, 0),
		RightElbow = v(8 + math.max(0, s) * 10, 0, 0),
		Waist = v(if style == "stalk" then 4 else 0, s * (if style == "cool" then 7 else 5), 0),
		Root = v(0, -s * 3, s * (if style == "cool" then 3 else 1.5)),
	}
	local bob = -0.16 * (s * s) + (if style == "stalk" then -0.08 else 0)
	return out, v(0, bob, 0)
end

-- Place everything for this frame; `dt` is the film's (slow motion slows the acting too).
function Puppet.update(self: any, dt: number)
	self.t += dt
	-- the blend between poses
	local k = if self.blendLen <= 0 then 1 else math.clamp((self.t - self.blendT0) / self.blendLen, 0, 1)
	local e = self.ease(k)
	local angles = self.angles
	for _, name in ORDER do
		angles[name] = self.from[name]:Lerp(self.to[name], e)
	end
	self.hip = self.hipFrom:Lerp(self.hipTo, e)
	local hip = self.hip
	-- the walk
	self.walkW += (self.walkWTo - self.walkW) * math.min(1, dt * 7)
	local final = angles
	if self.walkW > 0.01 then
		self.walkPhase += dt * self.walkRate * math.pi * 2
		local wp, bob = walkPose(self.walkPhase, self.walkStyle)
		local w = self.walkW
		final = {}
		for _, name in ORDER do
			local add = wp[name]
			if add and not self.walkArms and (string.find(name, "Shoulder") or string.find(name, "Elbow")) then
				add = nil
			end
			final[name] = if add then angles[name]:Lerp(add + (if name == "Waist" or name == "Root" then angles[name] else ZERO), w) else angles[name]
		end
		hip = hip:Lerp(bob, w)
	end
	-- breathing (a little, always)
	local br = math.sin(self.t * 1.9) * 1.2
	-- the look: the head (and some chest) turned to a point
	local lookYaw, lookPitch = 0, 0
	local la = self.lookAt
	self.lookW += ((if la then self.lookAmt else 0) - self.lookW) * math.min(1, dt * 6)
	if la and self.lookW > 0.01 then
		local chest = self.root * CFrame.new(hip) * CFrame.new(0, 1.5, 0)
		local rel = chest:PointToObjectSpace(la)
		lookYaw = math.clamp(math.deg(math.atan2(-rel.X, -rel.Z)), -75, 75) * self.lookW
		lookPitch = math.clamp(math.deg(math.atan2(rel.Y, math.sqrt(rel.X * rel.X + rel.Z * rel.Z))), -40, 50) * self.lookW
	end
	-- a jolt (being hit)
	local j = self.jolt
	self.jolt = math.max(0, j - dt * 4)
	local world = self.world
	local root = self.root
	world[self.hrp] = root
	for _, jt in self.joints do
		local a = final[jt.name] or ZERO
		local x, y, z = a.X, a.Y, a.Z
		local body = jt.name == "Root" or jt.name == "Waist" or jt.name == "Neck"
		if jt.name == "Waist" then
			x += br * 0.5 - lookPitch * 0.15
			y += lookYaw * 0.25
		elseif jt.name == "Neck" then
			x -= lookPitch * 0.85 + br * 0.3
			y += lookYaw * 0.75
		end
		if j > 0 then
			x += (math.random() - 0.5) * j * 16
			z += (math.random() - 0.5) * j * 10
		end
		if body then
			x = -x -- (+X bows the body in a pose; a joint's own +X tips it back)
		end
		local T = CFrame.Angles(rad(x), rad(y), rad(z))
		if jt.name == "Root" then
			T = CFrame.new(hip) * T
		end
		world[jt.child] = world[jt.parent] * jt.c0 * T * jt.c1inv
	end
	-- reaching arms (a pose's rh / lh): blended in over the FK arm by the reach's weight
	local chestPart = self.byName.UpperTorso
	local chest = chestPart and world[chestPart]
	if chest then
		for side, a in self.arms do
			a.w = a.wFrom + (a.wTo - a.wFrom) * e
			a.cur = a.from:Lerp(a.to, e)
			a.poleNow = a.poleFrom:Lerp(a.poleTo, e)
			if a.w > 0.001 then
				local shoulder = (chest * a.sh.c0).Position
				local tgt = chest * a.cur
				local upper, lower = reach(a, shoulder, tgt, chest:VectorToWorldSpace(a.poleNow))
				local wa = final[side .. "Wrist"] or ZERO
				local hand = lower * a.wr.c0 * CFrame.Angles(rad(wa.X), rad(wa.Y), rad(wa.Z)) * a.wr.c1inv
				local ua, la, hp = a.sh.child, a.el.child, a.wr.child
				if a.w >= 0.999 then
					world[ua], world[la], world[hp] = upper, lower, hand
				else
					world[ua] = world[ua]:Lerp(upper, a.w)
					world[la] = world[la]:Lerp(lower, a.w)
					world[hp] = world[hp]:Lerp(hand, a.w)
				end
			end
			a.now = chest:PointToObjectSpace((world[a.el.child] * a.wr.c0).Position)
		end
	end
	for _, s in self.stuck do
		local b = world[s.base]
		if b then
			world[s.part] = b * s.rel
		end
	end
	local cfs = self.cfs
	for i, p in self.parts do
		cfs[i] = world[p] or root
	end
	workspace:BulkMoveTo(self.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

function Puppet.destroy(self: any)
	self.model:Destroy()
end

return Puppet
