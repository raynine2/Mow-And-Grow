-- First-person hands, like Chop A Forest's: chunky brick arms in your avatar's skin colour (a cuff in its shirt /
-- torso colour) held up from the bottom corners of the screen, holding the current tool. Each frame they're laid
-- out to where the hands should be (idle sway, walk bob, a swing on every hit, jabs with bare hands, a buzz for auto
-- tools). Only this client sees them.
-- (They used to be copies of the avatar's own arm meshes, but avatar bodies vary too much - bulky packages,
-- scaled rigs - and came out huge and glitchy; simple bricks always have the same, right proportions.)
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
local HAND = 0.42
local TOOL = 0.5
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
handLight.Brightness = 1.6
handLight.Range = 5
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
type ArmSet = { model: Model, right: { BasePart }, left: { BasePart }, char: Model }
local arms: ArmSet? = nil
local nextArmBuild = 0
-- where the shoulders sit relative to the camera: low and a little behind, so the arms come up from the corners
local SHOULDER_R = Vector3.new(2, -2.5, 0.4)
local SHOULDER_L = Vector3.new(-2, -2.5, 0.4)
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
	local set: ArmSet = { model = model, right = {}, left = {}, char = char }
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

-- Lay one arm (upper arm, forearm, hand) in a straight line from the shoulder so the hand's centre lands on
-- `target`. The back of the hand faces up; for R6 the one-piece arm ends at the target.
local function poseArm(parts: { BasePart }, shoulder: Vector3, target: Vector3, cam: Camera, side: number)
	local toward = target - shoulder
	local d = if toward.Magnitude > 0.01 then toward.Unit else cam.CFrame.LookVector
	local up = cam.CFrame.UpVector
	up -= d * up:Dot(d)
	if up.Magnitude < 0.01 then
		up = d:Cross(cam.CFrame.RightVector)
	end
	local xAxis = up.Unit * side
	local yAxis = -d
	local at = target
	if #parts == 1 then
		at -= d * math.max(0, parts[1].Size.Y / 2 - 0.5)
	end
	for i = #parts, 1, -1 do
		local part = parts[i]
		local half = part.Size.Y / 2
		if i ~= #parts then
			at -= d * half * 0.9
		end
		part.CFrame = CFrame.fromMatrix(at, xAxis, yAxis)
		part.Transparency = 0
		at -= d * half * 0.9
	end
end

-- where the hands rest, relative to the camera
-- fists a little further off and tipped up, so you see the knuckles and the forearms run down to the screen's
-- bottom corners (like Chop A Forest), not the flat tops of the forearms
-- (with the real arms only the position matters: the arm points from the shoulder at it)
local REST_R = scaled(CFrame.new(1.55, -1.45, -4.1) * CFrame.Angles(math.rad(24), math.rad(14), 0), DIST)
local REST_L = scaled(CFrame.new(-1.6, -1.55, -4.2) * CFrame.Angles(math.rad(20), math.rad(-14), 0), DIST)
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
State.on("hitstop", function(duration: number)
	local now = os.clock()
	frozenUntil = now + duration
	swingStart += duration -- resume exactly where it stopped
end)

-- A jab: pull back a touch, snap forward and in toward the middle of the view, hold, come back.
-- `side` mirrors it for the left hand.
local function punchOffset(t: number, side: number): CFrame
	local wind = CFrame.new(0.12 * side, -0.12, 0.4) * CFrame.Angles(math.rad(-14), 0, 0)
	local strike = CFrame.new(-0.6 * side, 0.4, -1.8) * CFrame.Angles(math.rad(10), math.rad(12 * side), math.rad(-8 * side))
	if t < 0.16 then
		return CFrame.new():Lerp(wind, t / 0.16)
	elseif t < 0.36 then
		local k = (t - 0.16) / 0.2
		return wind:Lerp(strike, 1 - (1 - k) * (1 - k))
	elseif t < 0.48 then
		return strike
	end
	local k = (t - 0.48) / 0.52
	return strike:Lerp(CFrame.new(), k * k * (3 - 2 * k))
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

-- swing curve: wind up, chop down and across, recover
local function swingOffset(t: number): CFrame
	if t < 0.25 then
		local k = t / 0.25
		return CFrame.new(0.2 * k, 0.5 * k, 0.3 * k) * CFrame.Angles(math.rad(35 * k), math.rad(-10 * k), 0)
	elseif t < 0.5 then
		local k = (t - 0.25) / 0.25
		return CFrame.new(0.2 - 1.2 * k, 0.5 - 1.3 * k, 0.3 - 1 * k) * CFrame.Angles(math.rad(35 - 95 * k), math.rad(-10 + 30 * k), math.rad(-25 * k))
	else
		local k = (t - 0.5) / 0.5
		local e = 1 - (1 - k) * (1 - k)
		return CFrame.new(-1 * (1 - e), -0.8 * (1 - e), -0.7 * (1 - e)) * CFrame.Angles(math.rad(-60 * (1 - e)), math.rad(20 * (1 - e)), math.rad(-25 * (1 - e)))
	end
end

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not cam or not hum or hum.Health <= 0 or hum.SeatPart or not inFirstPerson() then
		hideAll()
		-- third person: show the real tool in the character's hand again
		if char then
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") and d.LocalTransparencyModifier ~= 0 and d:FindFirstAncestorOfClass("Tool") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
		return
	end
	if root.Parent ~= cam then
		root.Parent = cam
	end
	local t = os.clock()
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
	lamp.CFrame = cam.CFrame * CFrame.new(0, 0.3, -0.6)
	handLight.Enabled = true

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
	local swing = if st >= 0 and st <= 1 and not auto then scaled(swingOffset(st), DIST) else CFrame.new()

	local rightCf, leftCf
	if id == "PushMower" or id == "LaserMower" then
		rightCf = base * PUSH_R * buzz
		leftCf = base * PUSH_L * buzz
	elseif twoHanded then
		rightCf = base * REST_R * swing * buzz
		leftCf = rightCf * CFrame.new(-1.3 * DIST, -0.2 * DIST, 0.9 * DIST)
	elseif id == "Hands" then
		-- bare hands: left and right jabs in turn, the other fist stays up like a boxer
		local jab = if st >= 0 and st <= 1 then scaled(punchOffset(st, punchSide), DIST) else CFrame.new()
		rightCf = base * REST_R * (if punchSide == 1 then jab else CFrame.new())
		leftCf = base * REST_L * (if punchSide == -1 then jab else CFrame.new())
	else
		rightCf = base * REST_R * swing
		leftCf = base * REST_L
	end
	local set = nil :: ArmSet? -- (the avatar-arm copies are off: see the top of this file)
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
		poseArm(set.right, cam.CFrame:PointToWorldSpace(SHOULDER_R), rightCf.Position, cam, 1)
		poseArm(set.left, cam.CFrame:PointToWorldSpace(SHOULDER_L), leftCf.Position, cam, -1)
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
		if toolId == id and not held then
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
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Tool") then
			d.LocalTransparencyModifier = 1
		end
	end
end)

return ViewModel
