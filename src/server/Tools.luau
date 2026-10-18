-- Hand tools (Bare Hands -> Laser Mower). The player only holds their best tool.
-- Swing tools hit when clicked; auto tools cut around you every tick while equipped (see Run).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PlayerData = require(script.Parent.PlayerData)

local Tools = {}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function piece(tool: Tool, handle: BasePart, size: Vector3, offset: CFrame, color: Color3, neon: boolean?)
	local p = Instance.new("Part")
	p.Name = "Piece"
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = handle.CFrame * offset
	weld(p, handle)
	p.Parent = tool
	return p
end

-- Simple brick models for each tool. The handle is what the hand grips.
local function buildModel(tool: Tool, def)
	if def.id == "Hands" then
		tool.RequiresHandle = false
		return
	end
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 1.6)
	handle.Color = Color3.fromRGB(60, 50, 45)
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	local c = def.color
	local grey = Color3.fromRGB(200, 200, 215)
	if def.id == "Scissors" then
		handle.Color = c
		piece(tool, handle, Vector3.new(0.3, 0.2, 2.2), CFrame.new(0.15, 0, -1.8) * CFrame.Angles(0, math.rad(6), 0), grey)
		piece(tool, handle, Vector3.new(0.3, 0.2, 2.2), CFrame.new(-0.15, 0, -1.8) * CFrame.Angles(0, math.rad(-6), 0), grey)
	elseif def.id == "Sickle" then
		handle.Color = Color3.fromRGB(140, 90, 50)
		piece(tool, handle, Vector3.new(0.2, 0.3, 1.6), CFrame.new(0, 0, -1.4), grey)
		piece(tool, handle, Vector3.new(0.2, 0.3, 1.6), CFrame.new(0.7, 0, -2.4) * CFrame.Angles(0, math.rad(-60), 0), grey)
		piece(tool, handle, Vector3.new(0.2, 0.3, 1.2), CFrame.new(1.4, 0, -2.0) * CFrame.Angles(0, math.rad(-120), 0), grey)
	elseif def.id == "WeedWhacker" then
		piece(tool, handle, Vector3.new(0.25, 0.25, 4.5), CFrame.new(0, -0.6, -2.4) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(60, 60, 70))
		piece(tool, handle, Vector3.new(1.2, 0.8, 1.2), CFrame.new(0, -2.1, -4.3), c)
		piece(tool, handle, Vector3.new(2.6, 0.1, 0.2), CFrame.new(0, -2.6, -4.3), Color3.fromRGB(255, 255, 255))
	elseif def.id == "MegaScythe" then
		piece(tool, handle, Vector3.new(0.3, 0.3, 5), CFrame.new(0, 0, -2.6), Color3.fromRGB(70, 50, 90))
		piece(tool, handle, Vector3.new(0.2, 0.6, 3.6), CFrame.new(1.6, 0, -5) * CFrame.Angles(0, math.rad(-80), 0), c, true)
	end
end

-- Push mowers don't sit in the hand: while equipped, a mower is attached in front of the character on the
-- ground (deck, wheels, push bar up to the hands), so it always lines up whatever the animation does.
local PUSH_MOWERS = { PushMower = true, LaserMower = true }

local function attachPushMower(char: Model, def)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or char:FindFirstChild("PushMowerModel") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "PushMowerModel"
	-- ground is HipHeight + half the root part below the root's centre (R15)
	local groundY = -(hum.HipHeight + root.Size.Y / 2)
	local base = root.CFrame * CFrame.new(0, groundY, -3.4)
	local dark = Color3.fromRGB(40, 40, 48)
	local laser = def.id == "LaserMower"
	local function add(size: Vector3, cf: CFrame, color: Color3, name: string, neon: boolean?, cyl: boolean?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if cyl then
			p.Shape = Enum.PartType.Cylinder
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = root
		w.Parent = p
		p.Parent = model
		return p
	end
	add(Vector3.new(3.2, 1, 2.8), base * CFrame.new(0, 0.9, 0), def.color, "Deck", laser)
	add(Vector3.new(2.2, 0.8, 1.6), base * CFrame.new(0, 1.8, 0.2), dark, "Motor")
	add(Vector3.new(0.6, 0.5, 0.6), base * CFrame.new(0.6, 2.4, 0.2), Color3.fromRGB(230, 60, 60), "Cap")
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1, 1 } do
			add(Vector3.new(0.5, 0.9, 0.9), base * CFrame.new(x, 0.45, z), dark, "Wheel", false, true)
		end
	end
	-- push bar from the back of the deck up to the hands
	for _, x in { -0.9, 0.9 } do
		add(Vector3.new(0.25, 0.25, 3.2), base * CFrame.new(x, 2.2, 2.4) * CFrame.Angles(math.rad(-38), 0, 0), dark, "Bar")
	end
	add(Vector3.new(2.2, 0.3, 0.3), base * CFrame.new(0, 3.2, 3.6), def.color, "Grip")
	if laser then
		add(Vector3.new(3, 0.2, 0.2), base * CFrame.new(0, 0.3, -1.4), Color3.fromRGB(120, 255, 255), "Laser", true)
	end
	model.Parent = char
end

local function detachPushMower(char: Model?)
	local m = char and char:FindFirstChild("PushMowerModel")
	if m then
		m:Destroy()
	end
end

function Tools.build(def): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.CanBeDropped = false
	tool.ToolTip = if def.kind == "auto" then "Cuts grass around you" else "Click to cut grass"
	tool:SetAttribute("ToolId", def.id)
	tool:SetAttribute("Kind", def.kind)
	if PUSH_MOWERS[def.id] then
		tool.RequiresHandle = false
		tool.Equipped:Connect(function()
			local char = tool.Parent
			if char and char:IsA("Model") then
				attachPushMower(char, def)
			end
		end)
		tool.Unequipped:Connect(function()
			-- the tool is back in the backpack now; find the character through the player
			local backpack = tool.Parent
			local player = backpack and backpack.Parent
			if player and player:IsA("Player") then
				detachPushMower(player.Character)
			end
		end)
		tool.Destroying:Connect(function()
			for _, p in game:GetService("Players"):GetPlayers() do
				if p.Character and not p.Character:FindFirstChildOfClass("Tool") then
					detachPushMower(p.Character)
				end
			end
		end)
	else
		buildModel(tool, def)
	end
	return tool
end

-- Make sure the player holds exactly their best tool.
function Tools.give(player: Player)
	local data = PlayerData.get(player)
	if not data or not data.run then
		return
	end
	local def = Config.TOOLS[data.run.tool] or Config.TOOLS[1]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	if not backpack then
		return
	end
	local has = false
	for _, container in { backpack, char } do
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("ToolId") then
					if t:GetAttribute("ToolId") == def.id then
						has = true
					else
						t:Destroy()
					end
				end
			end
		end
	end
	if not has then
		local tool = Tools.build(def)
		tool.Parent = backpack
		-- equip the new tool straight away
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:EquipTool(tool)
		end
	end
end

-- The tool the player is holding right now (its def), or nil.
function Tools.equipped(player: Player)
	local char = player.Character
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end
	local id = tool:GetAttribute("ToolId")
	for _, def in Config.TOOLS do
		if def.id == id then
			return def, tool
		end
	end
	return nil
end

-- Play the default "slash" arm swing (the stock Animate script listens for this).
function Tools.slash(tool: Tool)
	local v = Instance.new("StringValue")
	v.Name = "toolanim"
	v.Value = "Slash"
	v.Parent = tool
	task.delay(0.3, function()
		v:Destroy()
	end)
end

return Tools
