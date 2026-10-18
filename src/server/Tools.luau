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
	elseif def.id == "PushMower" or def.id == "LaserMower" then
		-- push bar in the hand, deck on the ground in front
		tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-20), 0, 0)
		piece(tool, handle, Vector3.new(0.3, 0.3, 3.6), CFrame.new(0, -1.1, -2) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(50, 50, 60))
		piece(tool, handle, Vector3.new(2.8, 1.2, 2.6), CFrame.new(0, -2.6, -4), c, def.id == "LaserMower")
		piece(tool, handle, Vector3.new(3, 0.3, 2.8), CFrame.new(0, -2.0, -4), Color3.fromRGB(40, 40, 45))
	elseif def.id == "WeedWhacker" then
		piece(tool, handle, Vector3.new(0.25, 0.25, 4.5), CFrame.new(0, -0.6, -2.4) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(60, 60, 70))
		piece(tool, handle, Vector3.new(1.2, 0.8, 1.2), CFrame.new(0, -2.1, -4.3), c)
		piece(tool, handle, Vector3.new(2.6, 0.1, 0.2), CFrame.new(0, -2.6, -4.3), Color3.fromRGB(255, 255, 255))
	elseif def.id == "MegaScythe" then
		piece(tool, handle, Vector3.new(0.3, 0.3, 5), CFrame.new(0, 0, -2.6), Color3.fromRGB(70, 50, 90))
		piece(tool, handle, Vector3.new(0.2, 0.6, 3.6), CFrame.new(1.6, 0, -5) * CFrame.Angles(0, math.rad(-80), 0), c, true)
	end
end

function Tools.build(def): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.CanBeDropped = false
	tool.ToolTip = if def.kind == "auto" then "Cuts grass around you" else "Click to cut grass"
	tool:SetAttribute("ToolId", def.id)
	tool:SetAttribute("Kind", def.kind)
	buildModel(tool, def)
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
