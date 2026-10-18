-- First-person hands, like the Chop A Forest trailer: chunky grey sleeves, big red blocky gloves holding the
-- current tool. Idle sway, walk bob, a swing on every hit, a buzz for auto tools. Drawn only on this client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local State = require(script.Parent.State)

local ViewModel = {}
local player = Players.LocalPlayer

local SLEEVE = Color3.fromRGB(95, 95, 108)
local GLOVE = Color3.fromRGB(232, 72, 68)
local WOOD = Color3.fromRGB(205, 160, 100)
local STEEL = Color3.fromRGB(205, 210, 220)
local DARK = Color3.fromRGB(45, 45, 55)

local root = Instance.new("Model")
root.Name = "ViewModel"

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

-- An arm is a list of {part, offset from the hand's CFrame}.
type Piece = { part: BasePart, offset: CFrame }
local function arm(): { Piece }
	local pieces = {}
	local function add(size: Vector3, offset: CFrame, color: Color3)
		table.insert(pieces, { part = part(root, size, color), offset = offset })
	end
	add(Vector3.new(1.05, 1.05, 3), CFrame.new(0, 0, 1.9), SLEEVE) -- sleeve back toward the camera
	add(Vector3.new(1.3, 1.25, 1.3), CFrame.new(0, 0, 0), GLOVE) -- glove
	add(Vector3.new(1.34, 0.32, 1.1), CFrame.new(0, 0.5, -0.2), Color3.fromRGB(205, 55, 52)) -- knuckle ridge
	add(Vector3.new(1.36, 0.3, 0.32), CFrame.new(0, 0.1, -0.66), Color3.fromRGB(205, 55, 52)) -- finger line
	add(Vector3.new(0.45, 0.5, 0.9), CFrame.new(-0.62, -0.1, -0.1), GLOVE) -- thumb
	return pieces
end
local rightArm = arm()
local leftArm = arm()

-- tool models, keyed by tool id; offsets are from the right hand
local tools: { [string]: { Piece } } = {}
local function tool(id: string, build: (add: (Vector3, CFrame, Color3, Enum.Material?) -> Part) -> ())
	local pieces = {}
	build(function(size, offset, color, material)
		local p = part(root, size, color, material)
		table.insert(pieces, { part = p, offset = offset })
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
local handR: Model? = nil
local handL: Model? = nil
local lastHandLook = 0

-- where the hands rest, relative to the camera
local REST_R = CFrame.new(1.55, -1.45, -2.4) * CFrame.Angles(math.rad(8), math.rad(8), 0)
local REST_L = CFrame.new(-1.6, -1.6, -2.6) * CFrame.Angles(math.rad(5), math.rad(-8), 0)
local PUSH_R = CFrame.new(1.25, -1.7, -2.2) * CFrame.Angles(math.rad(-25), 0, 0)
local PUSH_L = CFrame.new(-1.25, -1.7, -2.2) * CFrame.Angles(math.rad(-25), 0, 0)
local TWO_HANDED = { PushMower = true, LaserMower = true, WeedWhacker = true, MegaScythe = true }

local swingStart = -10
local SWING_TIME = 0.32
local punchSide = 1 -- bare hands alternate: 1 = right, -1 = left
State.on("swing", function()
	swingStart = os.clock()
	punchSide = -punchSide
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
	local bob = CFrame.new(math.sin(t * 8) * 0.06 * walk, math.abs(math.cos(t * 8)) * 0.1 * walk + math.sin(t * 1.6) * 0.03, 0)
	local base = cam.CFrame * bob

	local id = equippedId()
	local twoHanded = id ~= nil and TWO_HANDED[id] == true
	local auto = id == "PushMower" or id == "LaserMower" or id == "WeedWhacker"
	local buzz = if auto then CFrame.new((math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.03, 0) else CFrame.new()

	local st = (t - swingStart) / SWING_TIME
	local swing = if st >= 0 and st <= 1 and not auto then swingOffset(st) else CFrame.new()

	local rightCf, leftCf
	if id == "PushMower" or id == "LaserMower" then
		rightCf = base * PUSH_R * buzz
		leftCf = base * PUSH_L * buzz
	elseif twoHanded then
		rightCf = base * REST_R * swing * buzz
		leftCf = rightCf * CFrame.new(-1.3, -0.2, 0.9)
	elseif id == "Hands" then
		-- bare hands: left and right jabs in turn, the other fist stays up like a boxer
		local jab = if st >= 0 and st <= 1 then punchOffset(st, punchSide) else CFrame.new()
		rightCf = base * REST_R * (if punchSide == 1 then jab else CFrame.new())
		leftCf = base * REST_L * (if punchSide == -1 then jab else CFrame.new())
	else
		rightCf = base * REST_R * swing
		leftCf = base * REST_L
	end
	if os.clock() - lastHandLook > 1 and not (handR and handL) then
		lastHandLook = os.clock()
		handR = handR or handModel("hand_right")
		handL = handL or handModel("hand_left")
	end
	placeHand(handR, rightArm, rightCf)
	placeHand(handL, leftArm, leftCf)

	local held = modelFor(id)
	if held then
		held:PivotTo(rightCf * CFrame.new(0, 0.1, -0.2))
		for _, part in held:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
	end
	for toolId, pieces in tools do
		if toolId == id and not held then
			local grip = if id == "PushMower" or id == "LaserMower" then rightCf * CFrame.new(0, 0, -0.1) else rightCf * CFrame.new(0, 0, -0.5)
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
