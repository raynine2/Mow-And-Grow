-- First-person hands, like Chop A Forest's: your avatar's OWN arms (copies of its arm parts, with its skin and
-- shirt sleeves) held up from the bottom corners of the screen, holding the current tool. Each frame they're laid
-- out to where the hands should be (idle sway, walk bob, a swing on every hit, jabs with bare hands, a buzz for auto
-- tools). Only this client sees them.
-- Every avatar's arms are shrunk to the same thickness (bulky packages and scaled rigs would fill the screen), turned
-- knuckles-up, and the upper arm stretches back to the screen corner so there's never a floating stump. Brick
-- fists in the avatar's colours are the fallback for a rig without arms.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local State = require(script.Parent.State)

local ViewModel = {}
local player = Players.LocalPlayer

local SKIN = Color3.fromRGB(204, 142, 105) -- until the avatar's colours are known
local WOOD = Color3.fromRGB(205, 160, 100)
local STEEL = Color3.fromRGB(205, 210, 220)
local DARK = Color3.fromRGB(45, 45, 55)

local root = Instance.new("Model")
root.Name = "ViewModel"

-- Proportions. The arm and tool pieces below are drawn at their old (big) size and shrunk by HAND / TOOL; the poses
-- are pulled toward the camera by DIST. A fist ends up ~13 degrees across: clearly there, never in the way, and
-- close enough that it doesn't dip into grass clumps and walls.
local HAND = 0.55
local TOOL = 0.62
local DIST = 0.66
local function scaled(cf: CFrame, k: number): CFrame
	return CFrame.new(cf.Position * k) * cf.Rotation
end

local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- An arm is a list of {part, offset from the hand's CFrame}. `role` says which avatar colour it takes:
-- "arm" (the forearm: LowerArm), "hand" (the fist: Hand), "shade" (finger creases: the hand a bit darker).
type Piece = { part: BasePart, offset: CFrame, role: string? }
local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
-- `side` 1 = right, -1 = left (the thumb sits on the inside).
local function arm(side: number): { Piece }
	local pieces = {}
	local function add(size: Vector3, offset: CFrame, role: string)
		table.insert(pieces, { part = part(root, size * HAND, SKIN), offset = scaled(offset, HAND), role = role })
	end
	add(Vector3.new(1.35, 1.35, 3.2), CFrame.new(0, -0.05, 2.1), "arm") -- forearm back toward the camera
	add(Vector3.new(1.6, 1.5, 1.55), CFrame.new(0, 0, 0), "hand") -- the fist
	add(Vector3.new(1.62, 0.42, 0.5), CFrame.new(0, 0.4, -0.58), "shade") -- top row of knuckles
	add(Vector3.new(1.62, 0.42, 0.5), CFrame.new(0, -0.08, -0.62), "hand") -- curled fingers
	add(Vector3.new(1.62, 0.36, 0.45), CFrame.new(0, -0.5, -0.56), "shade") -- bottom row
	add(Vector3.new(0.5, 0.55, 1.05), CFrame.new(-0.78 * side, 0.15, -0.15), "hand") -- thumb
	add(Vector3.new(1.55, 1.55, 1.2), CFrame.new(0, -0.05, 4.2), "sleeve") -- the cuff of the sleeve
	add(Vector3.new(1.7, 1.7, 3), CFrame.new(0, -0.05, 6.3), "sleeve") -- the sleeve, out of view
	return pieces
end
local rightArm = arm(1)
local leftArm = arm(-1)

-- A soft light just in front of the camera, so the hands are lit the same everywhere (they're tiny and close,
-- and the world's light alone leaves them dark on their camera side).
local lamp = part(root, Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1))
lamp.Name = "HandLight"
lamp.Transparency = 1
local handLight = Instance.new("PointLight")
handLight.Color = Color3.fromRGB(255, 240, 220)
handLight.Brightness = 1.4 -- (was 5: light sleeves and skin burned to flat white and filled the bottom of the screen)
handLight.Range = 4.5 -- reaches the hands, not the ground below them
handLight.Shadows = false
handLight.Parent = lamp

-- The avatar's own colours: R15 hands / lower arms, R6 arms, else Body Colors.
local function avatarColors(char: Model): (Color3?, Color3?, Color3?)
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local lower = char:FindFirstChild("RightLowerArm") or hand
	-- the sleeve: the torso's colour when it differs from the skin and there's no shirt texture over it (a shirt's
	-- colours can't be read, so a shirt gets a friendly blue)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local shirt = if torso and torso:IsA("BasePart") and not char:FindFirstChildOfClass("Shirt") then torso.Color else nil
	if shirt and hand and hand:IsA("BasePart") and shirt == hand.Color then
		shirt = nil
	end
	if hand and hand:IsA("BasePart") and lower and lower:IsA("BasePart") then
		return hand.Color, lower.Color, shirt
	end
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		return bc.RightArmColor3, bc.RightArmColor3, nil
	end
	return nil, nil, nil
end

local lastSkin: Color3? = nil
local function paintArms(handColor: Color3, armColor: Color3, sleeveColor: Color3?)
	local sleeve = sleeveColor or Color3.fromRGB(70, 130, 220)
	for _, pieces in { rightArm, leftArm } do
		for _, pc in pieces do
			pc.part.Color = if pc.role == "sleeve" then sleeve
				elseif pc.role == "arm" then armColor
				elseif pc.role == "shade" then shade(handColor, 0.88)
				else handColor
		end
	end
end

-- The avatar's look loads after the character spawns (and can change), so check its colours now and then.
task.spawn(function()
	while true do
		local char = player.Character
		if char then
			local handColor, armColor, sleeveColor = avatarColors(char)
			if handColor and armColor and handColor ~= lastSkin then
				lastSkin = handColor
				paintArms(handColor, armColor, sleeveColor)
			end
		end
		task.wait(1)
	end
end)

-- tool models, keyed by tool id; offsets are from the right hand
local tools: { [string]: { Piece } } = {}
local function tool(id: string, build: (add: (Vector3, CFrame, Color3, Enum.Material?) -> Part) -> ())
	local pieces = {}
	build(function(size, offset, color, material)
		local p = part(root, size * TOOL, color, material)
		table.insert(pieces, { part = p, offset = scaled(offset, TOOL) })
		return p
	end)
	tools[id] = pieces
end
tool("Scissors", function(add)
	add(Vector3.new(0.5, 0.9, 0.5), CFrame.new(0.15, 0, 0), Color3.fromRGB(230, 60, 60))
	add(Vector3.new(0.18, 0.12, 2.4), CFrame.new(0.05, 0.1, -1.5) * CFrame.Angles(0, math.rad(5), 0), STEEL, Enum.Material.Metal)
	add(Vector3.new(0.18, 0.12, 2.4), CFrame.new(0.25, 0.1, -1.5) * CFrame.Angles(0, math.rad(-5), 0), STEEL, Enum.Material.Metal)
end)
tool("Sickle", function(add)
	add(Vector3.new(0.35, 0.35, 1.8), CFrame.new(0, 0, -0.6), WOOD, Enum.Material.Wood)
	add(Vector3.new(0.15, 0.35, 1.5), CFrame.new(0, 0.1, -2.1), STEEL, Enum.Material.Metal)
	add(Vector3.new(0.15, 0.35, 1.4), CFrame.new(-0.55, 0.1, -3.0) * CFrame.Angles(0, math.rad(55), 0), STEEL, Enum.Material.Metal)
	add(Vector3.new(0.15, 0.35, 1.1), CFrame.new(-1.4, 0.1, -3.1) * CFrame.Angles(0, math.rad(115), 0), STEEL, Enum.Material.Metal)
end)
tool("PushMower", function(add)
	-- a push bar running down and away; the mower deck itself is on the ground in the world
	add(Vector3.new(3.2, 0.3, 0.3), CFrame.new(-1.2, 0, -0.2), Color3.fromRGB(255, 140, 30))
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(0, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(-2.4, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
end)
tool("WeedWhacker", function(add)
	add(Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 0, 0), Color3.fromRGB(60, 200, 80))
	add(Vector3.new(0.22, 0.22, 5), CFrame.new(0, -1.1, -2.8) * CFrame.Angles(math.rad(25), 0, 0), DARK)
	add(Vector3.new(1, 0.6, 1), CFrame.new(0, -2.2, -5.1), Color3.fromRGB(60, 200, 80))
	local line = add(Vector3.new(2.6, 0.08, 0.12), CFrame.new(0, -2.55, -5.1), Color3.new(1, 1, 1))
	line:SetAttribute("Spin", true)
end)
tool("MegaScythe", function(add)
	add(Vector3.new(0.35, 0.35, 5), CFrame.new(0, 0, -1.8), Color3.fromRGB(80, 55, 100), Enum.Material.Wood)
	add(Vector3.new(0.18, 0.6, 3.4), CFrame.new(-1.5, 0.2, -4.2) * CFrame.Angles(0, math.rad(80), 0), Color3.fromRGB(170, 110, 255), Enum.Material.Neon)
end)
tool("LaserMower", function(add)
	add(Vector3.new(3.2, 0.3, 0.3), CFrame.new(-1.2, 0, -0.2), Color3.fromRGB(60, 230, 255), Enum.Material.Neon)
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(0, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
	add(Vector3.new(0.25, 0.25, 4), CFrame.new(-2.4, -1, -2) * CFrame.Angles(math.rad(35), 0, 0), DARK)
end)

-- Blender tool models (uploaded ones), held at their grip (their origin); working end points forward
local TOOL_MODEL = { Scissors = "tool_scissors", Sickle = "tool_sickle", WeedWhacker = "tool_whacker", MegaScythe = "tool_scythe" }
local heldModel: Model? = nil
local heldId: string? = nil
local function modelFor(id: string?): Model?
	if id == heldId then
		return heldModel
	end
	if heldModel then
		heldModel:Destroy()
		heldModel = nil
	end
	heldId = id
	local folder = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = folder and id and TOOL_MODEL[id] and folder:FindFirstChild(TOOL_MODEL[id])
	if template and template:IsA("Model") then
		local m = template:Clone()
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
			end
		end
		m:ScaleTo(TOOL)
		m.Parent = root
		heldModel = m
	end
	return heldModel
end

-- First-person push mower: Roblox fades your whole character out in first person, mower included, so you'd push
-- thin air. Instead a local copy of the mower you're pushing (server/Tools puts it on the character) rides low in
-- front of the view, its push bar in your fists. Its grip (the top of the bar) is found from its shape, so the
-- Blender mower and the brick fallback both line up.
local PUSH_SCALE = 0.42
local PUSH_TILT = math.rad(38) -- nose tipped up a little, so you look down onto the deck
type PushCopy = { model: Model, src: Instance, grip: Vector3, width: number }
local push: PushCopy? = nil

local function pushCopyFor(char: Model): PushCopy?
	local src = char:FindFirstChild("PushMowerModel")
	if push and push.src == src and push.model.Parent then
		return push
	end
	if push then
		push.model:Destroy()
		push = nil
	end
	if not (src and src:IsA("Model")) then
		return nil
	end
	local was = src.Archivable
	src.Archivable = true
	local m = src:Clone()
	src.Archivable = was
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.LocalTransparencyModifier = 0
			d:SetAttribute("VT", d.Transparency)
		elseif d:IsA("Constraint") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	m:ScaleTo(m:GetScale() * (root:GetAttribute("PushScale") :: number? or PUSH_SCALE))
	-- the grip: the highest point of the mower (the top of its push bar), and how wide the bar is up there
	local piv = m:GetPivot()
	local corners: { Vector3 } = {}
	local topY = -math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and (d:GetAttribute("VT") :: number) < 1 then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local c = piv:PointToObjectSpace(d.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
						table.insert(corners, c)
						topY = math.max(topY, c.Y)
					end
				end
			end
		end
	end
	local zSum, n, xMin, xMax = 0, 0, math.huge, -math.huge
	for _, c in corners do
		if c.Y > topY - 0.35 then
			zSum += c.Z
			n += 1
			xMin = math.min(xMin, c.X)
			xMax = math.max(xMax, c.X)
		end
	end
	if n == 0 then
		m:Destroy()
		return nil
	end
	m.Parent = root
	push = { model = m, src = src, grip = Vector3.new((xMin + xMax) / 2, topY - 0.12, zSum / n), width = math.max(0.6, xMax - xMin) }
	return push
end

local function showPush(p: PushCopy?, visible: boolean)
	if not p then
		return
	end
	for _, d in p.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if visible then (d:GetAttribute("VT") :: number? or 0) else 1
		end
	end
end

-- Blender gardening-glove hands (hand_right / hand_left), when uploaded, replace the brick arms. Their origin is
-- the grip in the fist, the same spot as the brick glove's centre. The server loads models after the client
-- starts, so keep looking until they're there.
local function handModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = folder and folder:FindFirstChild(name)
	if not (template and template:IsA("Model")) then
		return nil
	end
	local m = template:Clone()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	m.Parent = root
	return m
end
-- (the Blender glove models aren't used any more: the fists are the avatar's own colours, like Chop A Forest)
local handR: Model? = nil
local handL: Model? = nil
local _ = handModel

-------------------------------------------------------------------------------------------------------------
-- the real arms
-------------------------------------------------------------------------------------------------------------
-- Avatars now use physics joints (AnimationConstraint) whose C0 can't be set, and a joint aimed from here would
-- lag a frame behind the camera. So, like most first-person games, we copy the avatar's own arm parts (meshes,
-- skin colour, shirt) into a little model with a Humanoid (so the shirt still draws on them) and place the copies
-- in front of the camera every frame. The real arms stay hidden by Roblox's first-person fade as usual.
type ArmSet = { model: Model, right: { BasePart }, left: { BasePart }, char: Model, size: { [BasePart]: Vector3 } }
local arms: ArmSet? = nil
local nextArmBuild = 0
-- where the shoulders sit relative to the camera: low and a little behind, so the arms come up from the corners
-- (Chop A Forest's arms are chunky and close: they fill the bottom corners and the fists sit low, near the middle)
-- (owner, 28 Oct: "the hands dont cover the screen as much" in Chop A Forest: the shoulders sit far behind the
-- fists now, so the arms run straight back out of view and only the fists show, low and wide; was (1.75, -2.7, 0.2))
local SHOULDER_R = Vector3.new(2.5, -3.0, 2.5)
local SHOULDER_L = Vector3.new(-2.5, -3.0, 2.5)
local ARM_WIDTH = 0.7 -- how thick the arms are in view (studs, at ~2.4 studs away; was 0.82, a bit much on screen)
local KEEP = { SpecialMesh = true, SurfaceAppearance = true, Decal = true, Texture = true }

local function copyPart(src: Instance): BasePart?
	if not src:IsA("BasePart") then
		return nil
	end
	local was = src.Archivable
	src.Archivable = true
	local p = src:Clone()
	src.Archivable = was
	for _, d in p:GetChildren() do
		if not KEEP[d.ClassName] then
			d:Destroy()
		end
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Transparency = 1
	p.LocalTransparencyModifier = 0
	return p
end

local function buildArms(char: Model): ArmSet?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local model = Instance.new("Model")
	model.Name = "Arms"
	local h = Instance.new("Humanoid")
	h.RigType = hum.RigType
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.BreakJointsOnDeath = false
	h.EvaluateStateMachine = false
	h.Parent = model
	local shirt = char:FindFirstChildOfClass("Shirt")
	if shirt then
		shirt:Clone().Parent = model
	end
	local set: ArmSet = { model = model, right = {}, left = {}, char = char, size = {} }
	for _, side in { "Right", "Left" } do
		local list = if side == "Right" then set.right else set.left
		local names = if r15 then { side .. "UpperArm", side .. "LowerArm", side .. "Hand" } else { side .. " Arm" }
		for _, n in names do
			local src = char:FindFirstChild(n)
			local part = src and copyPart(src)
			if not part then
				model:Destroy()
				return nil
			end
			part.Parent = model
			table.insert(list, part)
		end
	end
	-- the same thickness for every avatar: the forearm (R15) or arm (R6) ARM_WIDTH studs across
	local ref = set.right[math.min(2, #set.right)]
	local k = ARM_WIDTH / math.max(0.2, math.min(ref.Size.X, ref.Size.Z))
	for _, list in { set.right, set.left } do
		for _, part in list do
			part.Size *= k
			for _, d in part:GetChildren() do
				if d:IsA("SpecialMesh") then
					d.Scale *= k
				end
			end
			set.size[part] = part.Size
		end
	end
	model.Parent = root
	return set
end

-- The arm copies for the current character (rebuilt when it changes or its look finishes loading).
local function armsFor(char: Model): ArmSet?
	local a = arms
	if a and a.char == char and a.model.Parent then
		return a
	end
	if a then
		a.model:Destroy()
		arms = nil
	end
	if os.clock() < nextArmBuild then
		return nil
	end
	nextArmBuild = os.clock() + 1
	arms = buildArms(char)
	return arms
end

player.CharacterAppearanceLoaded:Connect(function()
	if arms then
		arms.model:Destroy()
		arms = nil
	end
	nextArmBuild = 0
end)

-- Lay one arm out: the hand's centre on `target`, the forearm behind it, and the upper arm (or R6's one-piece arm)
-- stretched back to the shoulder point off the screen's corner. Knuckles up, the fists rolled a little inward.
local function poseArm(set: ArmSet, parts: { BasePart }, shoulder: Vector3, target: Vector3, cam: Camera, side: number)
	local toward = target - shoulder
	local d = if toward.Magnitude > 0.01 then toward.Unit else cam.CFrame.LookVector
	local up = cam.CFrame.UpVector
	up -= d * up:Dot(d)
	if up.Magnitude < 0.01 then
		up = d:Cross(cam.CFrame.RightVector)
	end
	up = CFrame.fromAxisAngle(d, math.rad(-22) * side):VectorToWorldSpace(up.Unit)
	local yAxis = -d -- each part's top points back toward the shoulder
	local xAxis = yAxis:Cross(up) -- and its back (+Z) points up: knuckles up
	local n = #parts
	local edge = target -- the front end of the next part to place
	for i = n, 1, -1 do
		local part = parts[i]
		local base = set.size[part] or part.Size
		local len = base.Y
		if i == 1 then
			-- reach all the way back to the shoulder, so the arm runs off the screen
			len = math.max(base.Y, (edge - shoulder):Dot(d) + 0.3)
			if part.Size.Y ~= len then
				part.Size = Vector3.new(base.X, len, base.Z)
			end
		end
		local centre
		if i == n and n > 1 then
			centre = target -- the hand
		elseif n == 1 then
			centre = target - d * (len / 2 - base.X * 0.5) -- R6: the arm's end is the fist
		else
			centre = edge - d * (len / 2) * 0.92
		end
		part.CFrame = CFrame.fromMatrix(centre, xAxis, yAxis)
		part.Transparency = 0
		edge = centre - d * (len / 2)
	end
end

-- where the hands rest, relative to the camera
-- fists a little further off and tipped up, so you see the knuckles and the forearms run down to the screen's
-- bottom corners (like Chop A Forest), not the flat tops of the forearms
-- (with the real arms only the position matters: the arm points from the shoulder at it)
-- (28 Oct: lower and wider, at the bottom of the screen like Chop A Forest's, so the middle of the view stays clear;
-- was (1.2, -1.6, -3.6) / (-1.25, -1.65, -3.65))
local REST_R = scaled(CFrame.new(2.15, -2.3, -3.3) * CFrame.Angles(math.rad(24), math.rad(14), 0), DIST)
local REST_L = scaled(CFrame.new(-2.2, -2.35, -3.35) * CFrame.Angles(math.rad(20), math.rad(-14), 0), DIST)
local PUSH_R = scaled(CFrame.new(1.25, -1.7, -2.6) * CFrame.Angles(math.rad(-25), 0, 0), DIST)
local PUSH_L = scaled(CFrame.new(-1.25, -1.7, -2.6) * CFrame.Angles(math.rad(-25), 0, 0), DIST)
local TWO_HANDED = { PushMower = true, LaserMower = true, WeedWhacker = true, MegaScythe = true }

local stepPhase = 0
local swayYaw, swayPitch = 0, 0
local lastCamRot: CFrame? = nil
local lastFrame: number? = nil

local swingStart = -10
local SWING_TIME = 0.32
local punchSide = 1 -- bare hands alternate: 1 = right, -1 = left
State.on("swing", function()
	swingStart = os.clock()
	punchSide = -punchSide
end)
-- Hit-stop: the swing freezes for a few frames on contact, which sells the weight of the blow.
local frozenUntil = 0
local recoilAt = -10
State.on("hitstop", function(duration: number)
	local now = os.clock()
	frozenUntil = now + duration
	swingStart += duration -- resume exactly where it stopped
	recoilAt = now + duration -- then the hand bounces back off the clump
end)

-- After a hit lands: the hand knocks back toward you and up a little, then springs back (a damped spring).
local function recoilOffset(now: number): CFrame
	local u = now - recoilAt
	if u < 0 or u > 0.45 then
		return CFrame.new()
	end
	local r = math.exp(-u * 10) * math.cos(u * 20)
	return CFrame.new(0, 0.1 * r, 0.5 * r) * CFrame.Angles(math.rad(12 * r), 0, 0)
end

-- A jab: cock the fist back, whip it forward (speeding up into the hit), a corkscrew turn of the wrist as it
-- lands just past the target, settle, hold, come back. `side` mirrors it for the left hand. Contact is at
-- t = 0.34 (HitFx's STRIKE_DELAY / SWING_TIME).
local function punchOffset(t: number, side: number): CFrame
	local wind = CFrame.new(0.2 * side, -0.2, 0.6) * CFrame.Angles(math.rad(-18), math.rad(-8 * side), math.rad(8 * side))
	local over = CFrame.new(-0.68 * side, 0.45, -2.05) * CFrame.Angles(math.rad(12), math.rad(14 * side), math.rad(-26 * side))
	local strike = CFrame.new(-0.6 * side, 0.4, -1.8) * CFrame.Angles(math.rad(10), math.rad(12 * side), math.rad(-20 * side))
	if t < 0.16 then
		local k = t / 0.16
		return CFrame.new():Lerp(wind, 1 - (1 - k) * (1 - k))
	elseif t < 0.34 then
		local k = (t - 0.16) / 0.18
		return wind:Lerp(over, k * k)
	elseif t < 0.44 then
		local k = (t - 0.34) / 0.1
		return over:Lerp(strike, 1 - (1 - k) * (1 - k))
	elseif t < 0.52 then
		return strike
	end
	local k = (t - 0.52) / 0.48
	return strike:Lerp(CFrame.new(), k * k * (3 - 2 * k))
end

-- The other fist while one punches: drawn in and down a touch (the body turning into the punch).
local function guardOffset(t: number, side: number): CFrame
	local e = math.sin(math.pi * math.clamp(t, 0, 1))
	return CFrame.new(0.08 * side * e, -0.06 * e, 0.3 * e) * CFrame.Angles(math.rad(-8 * e), 0, 0)
end

local function equippedId(): string?
	local char = player.Character
	local t = char and char:FindFirstChildOfClass("Tool")
	return t and t:GetAttribute("ToolId") :: string?
end

local function inFirstPerson(): boolean
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local cam = workspace.CurrentCamera
	if not head or not cam then
		return false
	end
	return (cam.CFrame.Position - head.Position).Magnitude < 2
end

local function hideAll()
	handLight.Enabled = false
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
	if push then
		push.model:Destroy()
		push = nil
	end
end

local function place(pieces: { Piece }, base: CFrame)
	for _, pc in pieces do
		pc.part.CFrame = base * pc.offset
		pc.part.Transparency = 0
	end
end

local function placeHand(model: Model?, pieces: { Piece }, cf: CFrame)
	if not model then
		place(pieces, cf)
		return
	end
	for _, pc in pieces do
		pc.part.Transparency = 1
	end
	model:PivotTo(cf)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 0
		end
	end
end

-- swing curve, like Chop A Forest's: cock the tool high on the right, then whip it down and right across the
-- screen to the lower left (speeding up into the hit at t = 0.34, HitFx's STRIKE_DELAY / SWING_TIME), hang there a
-- beat, and come back.
local SWING_WIND = CFrame.new(0.55, 0.85, 0.45) * CFrame.Angles(math.rad(48), math.rad(-14), math.rad(18))
local SWING_HIT = CFrame.new(-1.15, -0.55, -0.7) * CFrame.Angles(math.rad(-58), math.rad(30), math.rad(-34))
local SWING_END = CFrame.new(-1.6, -0.95, -0.55) * CFrame.Angles(math.rad(-72), math.rad(38), math.rad(-42))
local function swingOffset(t: number): CFrame
	if t < 0.2 then
		local k = t / 0.2
		return CFrame.new():Lerp(SWING_WIND, 1 - (1 - k) * (1 - k))
	elseif t < 0.34 then
		local k = (t - 0.2) / 0.14
		return SWING_WIND:Lerp(SWING_HIT, k * k)
	elseif t < 0.46 then
		local k = (t - 0.34) / 0.12
		return SWING_HIT:Lerp(SWING_END, 1 - (1 - k) * (1 - k))
	end
	local k = (t - 0.46) / 0.54
	return SWING_END:Lerp(CFrame.new(), k * k * (3 - 2 * k))
end

-- The server-side tool in our own hand: hidden in first person (it would poke through the camera), shown in third.
-- Only the character's Tools are walked, not the whole character.
local function realTools(char: Model, modifier: number)
	for _, tool in char:GetChildren() do
		if tool:IsA("Tool") then
			for _, d in tool:GetDescendants() do
				if d:IsA("BasePart") and d.LocalTransparencyModifier ~= modifier then
					d.LocalTransparencyModifier = modifier
				end
			end
		end
	end
end

local thirdPerson = false
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not cam or not hum or hum.Health <= 0 or hum.SeatPart or not inFirstPerson() then
		-- hide the first-person hands once, not every frame (that walked every view model each frame)
		if not thirdPerson then
			thirdPerson = true
			hideAll()
		end
		-- third person: show the real tool in the character's hand again (not while a film hides the characters:
		-- client/IntroCast's CastHidden)
		if char and not player:GetAttribute("CastHidden") then
			realTools(char, 0)
		end
		return
	end
	thirdPerson = false
	if root.Parent ~= cam then
		root.Parent = cam
	end
	local t = os.clock()
	-- (tuning: set Tune = true on the ViewModel model in a playtest and the HandX/Y/Z and ShX/Y/Z attributes move
	-- the fists and shoulders live)
	if root:GetAttribute("Tune") then
		local hx, hy, hz = root:GetAttribute("HandX") :: number? or 2.15, root:GetAttribute("HandY") :: number? or -2.3, root:GetAttribute("HandZ") :: number? or -3.3
		REST_R = scaled(CFrame.new(hx, hy, hz) * CFrame.Angles(math.rad(24), math.rad(14), 0), DIST)
		REST_L = scaled(CFrame.new(-hx - 0.05, hy - 0.05, hz - 0.05) * CFrame.Angles(math.rad(20), math.rad(-14), 0), DIST)
		local sx, sy, sz = root:GetAttribute("ShX") :: number? or 2.5, root:GetAttribute("ShY") :: number? or -3.0, root:GetAttribute("ShZ") :: number? or 2.5
		SHOULDER_R = Vector3.new(sx, sy, sz)
		SHOULDER_L = Vector3.new(-sx, sy, sz)
	end
	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = if rootPart then Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude else 0
	local walk = math.clamp(speed / 16, 0, 1.4)
	local dt = math.min(0.1, t - (lastFrame or t))
	lastFrame = t
	-- step rhythm: the hands bob in a figure-eight with your steps, and breathe a little when standing
	if walk > 0.05 then
		stepPhase += dt * (5.5 + speed * 0.3)
	end
	local bob = CFrame.new(math.sin(stepPhase) * 0.07 * walk, -math.abs(math.cos(stepPhase)) * 0.09 * walk + math.sin(t * 1.6) * 0.03, 0)
		* CFrame.Angles(0, 0, math.sin(stepPhase) * 0.02 * walk)
	-- sway: the hands lag behind your mouse look (a spring toward the turn speed), so they feel weighty
	local rel = (lastCamRot or cam.CFrame.Rotation):ToObjectSpace(cam.CFrame.Rotation)
	lastCamRot = cam.CFrame.Rotation
	local rx, ry = rel:ToEulerAnglesYXZ()
	if dt > 0 then
		local k = math.min(1, dt * 12)
		swayYaw += (math.clamp(-ry / dt * 0.012, -0.14, 0.14) - swayYaw) * k
		swayPitch += (math.clamp(-rx / dt * 0.012, -0.1, 0.1) - swayPitch) * k
	end
	local sway = CFrame.new(swayYaw * 1.4, swayPitch * 1.2, 0) * CFrame.Angles(swayPitch, swayYaw, swayYaw * 0.6)
	local base = cam.CFrame * bob * sway
	lamp.CFrame = cam.CFrame * CFrame.new(0, 0.5, -1.2) -- above the hands: lights the tops you see
	handLight.Enabled = not player:GetAttribute("Potato")

	local id = equippedId()
	local twoHanded = id ~= nil and TWO_HANDED[id] == true
	local auto = id == "PushMower" or id == "LaserMower" or id == "WeedWhacker"
	local buzz = if auto then CFrame.new((math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.03, 0) else CFrame.new()

	-- during a hit-stop, hold the pose the swing had when it froze
	-- (swingStart was pushed back by the freeze, so frozenUntil - swingStart is the pose it froze at)
	local st = (math.min(t, frozenUntil) - swingStart) / SWING_TIME
	if t >= frozenUntil then
		st = (t - swingStart) / SWING_TIME
	end
	local recoil = scaled(recoilOffset(t), DIST)
	local swing = if st >= 0 and st <= 1 and not auto then scaled(swingOffset(st), DIST) * recoil else CFrame.new()

	local rightCf, leftCf
	local pushing = if id == "PushMower" or id == "LaserMower" then pushCopyFor(char) else nil
	if not pushing and push then
		push.model:Destroy()
		push = nil
	end
	if pushing then
		-- the mower rides low in front of you, its bar between the fists; it rumbles while it runs and rocks with
		-- your steps
		-- (attributes on the ViewModel model override these, for tuning in a playtest)
		local hands = base * scaled(CFrame.new(0, root:GetAttribute("PushY") :: number? or -2.5, root:GetAttribute("PushZ") :: number? or -3.6), DIST) * buzz
		local rock = CFrame.Angles(math.sin(stepPhase * 2) * 0.015 * walk, 0, math.sin(stepPhase) * 0.02 * walk)
		local gripCf = CFrame.new(hands.Position) * cam.CFrame.Rotation * rock * CFrame.Angles(math.rad(root:GetAttribute("PushTilt") :: number? or math.deg(PUSH_TILT)), 0, 0)
		pushing.model:PivotTo(gripCf * CFrame.new(-pushing.grip))
		showPush(pushing, true)
		local half = math.min(pushing.width * 0.42, 0.75)
		rightCf = gripCf * CFrame.new(half, 0, 0)
		leftCf = gripCf * CFrame.new(-half, 0, 0)
	elseif id == "PushMower" or id == "LaserMower" then
		rightCf = base * PUSH_R * buzz
		leftCf = base * PUSH_L * buzz
	elseif id == "MegaScythe" then
		-- the reaper's grip: one fist low on the right, the shaft standing up past it and the blade hooked over the
		-- top of the view; a swing whips the whole scythe down and across (the swing turns it about the fist)
		local tilt = root:GetAttribute("ReaperTilt") :: number? or 36
		local reaperPos = scaled(CFrame.new(root:GetAttribute("ReaperX") :: number? or 1.15, root:GetAttribute("ReaperY") :: number? or -1.9, -3.2), DIST)
		local reaperRot = CFrame.Angles(math.rad(tilt), math.rad(-8), math.rad(root:GetAttribute("ReaperRoll") :: number? or 34))
		local sway = CFrame.Angles(0, 0, math.sin(t * 1.3) * 0.02)
		rightCf = base * reaperPos * swing * reaperRot * sway
		leftCf = base * REST_L * scaled(guardOffset(math.clamp(st, 0, 1), -1), DIST)
	elseif twoHanded then
		rightCf = base * REST_R * swing * buzz
		leftCf = rightCf * CFrame.new(-1.3 * DIST, -0.2 * DIST, 0.9 * DIST)
	elseif id == "Hands" then
		-- bare hands: left and right jabs in turn, the other fist stays up like a boxer
		local active = st >= 0 and st <= 1
		local jab = if active then scaled(punchOffset(st, punchSide), DIST) * recoil else CFrame.new()
		local guard = if active then scaled(guardOffset(st, -punchSide), DIST) else CFrame.new()
		rightCf = base * REST_R * (if punchSide == 1 then jab else guard)
		leftCf = base * REST_L * (if punchSide == -1 then jab else guard)
	else
		rightCf = base * REST_R * swing
		leftCf = base * REST_L
	end
	local set = armsFor(char)
	if set then
		-- the real arms: hide the brick fists and lay the avatar's own arms out to the fist spots
		for _, pieces in { rightArm, leftArm } do
			for _, pc in pieces do
				pc.part.Transparency = 1
			end
		end
		for _, m in { handR, handL } do
			if m then
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.Transparency = 1
					end
				end
			end
		end
		poseArm(set, set.right, cam.CFrame:PointToWorldSpace(SHOULDER_R), rightCf.Position, cam, 1)
		poseArm(set, set.left, cam.CFrame:PointToWorldSpace(SHOULDER_L), leftCf.Position, cam, -1)
	else
		placeHand(handR, rightArm, rightCf)
		placeHand(handL, leftArm, leftCf)
	end

	local held = modelFor(id)
	if held then
		held:PivotTo(rightCf * CFrame.new(0, 0.1 * HAND, -0.2 * HAND))
		for _, part in held:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
	end
	for toolId, pieces in tools do
		if toolId == id and not held and not pushing then
			local grip = if id == "PushMower" or id == "LaserMower" then rightCf * CFrame.new(0, 0, -0.1 * HAND) else rightCf * CFrame.new(0, 0, -0.3 * HAND)
			for _, pc in pieces do
				local cf = grip * pc.offset
				if pc.part:GetAttribute("Spin") then
					cf = cf * CFrame.Angles(0, t * 40, 0)
				end
				pc.part.CFrame = cf
				pc.part.Transparency = 0
			end
		else
			for _, pc in pieces do
				pc.part.Transparency = 1
			end
		end
	end

	-- the server-side tool in our own hand would poke through the camera; hide it locally
	realTools(char, 1)
end)

return ViewModel
