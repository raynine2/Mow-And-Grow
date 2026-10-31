-- Hand tools (Bare Hands -> Laser Mower). The player only holds their best tool.
-- Swing tools hit when clicked; auto tools cut around you every tick while equipped (see Run).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PlayerData = require(script.Parent.PlayerData)
local Models = require(script.Parent.Models)

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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = handle.CFrame * offset
	weld(p, handle)
	p.Parent = tool
	return p
end

-- The Blender model the first-person hands hold (client/ViewModel) and the shop shows: the tool in your hand looks
-- the same zoomed in and zoomed out (owner, 27 Oct: the scissors were a different model up close). Held at its
-- grip (the model's origin), working end forward, like the brick version it covers.
local HELD_MODEL = { Scissors = "tool_scissors", Sickle = "tool_sickle", WeedWhacker = "tool_whacker", MegaScythe = "tool_scythe" }
local HELD_SCALE = 0.85

local function dressWithModel(tool: Tool, handle: BasePart, id: string)
	local name = HELD_MODEL[id]
	local m = name and Models.place(name, tool, handle.CFrame, HELD_SCALE, true)
	if not m then
		return -- not loaded: the brick version stays
	end
	m.Name = "HeldModel"
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(m) then
			d.Transparency = 1 -- the bricks stay as the grip and the scythe's trail anchor, unseen
		end
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			weld(p, handle)
		end
	end
	-- (31 Oct, owner: "when i hit there are random white things above me") a held model with its own swing-trail
	-- spots (server/Models FORGE_TOOLS `trail`: the ForgeGUI scythe's blade) carries the swing trail there, not on
	-- the hidden brick blade out beside it
	local t0, t1 = m:FindFirstChild("TrailA", true), m:FindFirstChild("TrailB", true)
	local trail = tool:FindFirstChild("ReapTrail", true)
	if trail and trail:IsA("Trail") and t0 and t0:IsA("Attachment") and t1 and t1:IsA("Attachment") then
		trail.Attachment0 = t0
		trail.Attachment1 = t1
	end
end

-- Simple brick models for each tool (covered by the Blender model when it's loaded). The handle is what the hand
-- grips.
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
		local blade = piece(tool, handle, Vector3.new(0.2, 0.6, 3.6), CFrame.new(1.6, 0, -5) * CFrame.Angles(0, math.rad(-80), 0), c, true)
		-- held like the Grim Reaper: the shaft stands straight up out of the fist (a third of the way up it), the
		-- blade hooked forward over your head
		tool.Grip = CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, 0, 1.2) * CFrame.Angles(math.rad(-80), 0, 0)
		-- a soft violet streak off the blade, only while it swings (Tools.slash turns it on)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0, 1.7)
		a0.Parent = blade
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0, -1.7)
		a1.Parent = blade
		local trail = Instance.new("Trail")
		trail.Name = "ReapTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.2
		trail.LightEmission = 0.7
		trail.LightInfluence = 0
		trail.Color = ColorSequence.new(Color3.fromRGB(235, 200, 255), Color3.fromRGB(150, 80, 255))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = blade
	end
	dressWithModel(tool, handle, def.id)
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
	-- ground is HipHeight + half the root part below the root's centre (R15)
	local groundY = -(hum.HipHeight + root.Size.Y / 2)
	local base = root.CFrame * CFrame.new(0, groundY, -3.4)
	local placed = Models.place(if def.id == "LaserMower" then "tool_lasermower" else "tool_pushmower", char, base)
	if placed then
		placed.Name = "PushMowerModel"
		Models.weldTo(placed, root)
		return
	end
	local model = Instance.new("Model")
	model.Name = "PushMowerModel"
	local dark = Color3.fromRGB(40, 40, 48)
	local laser = def.id == "LaserMower"
	local function add(size: Vector3, cf: CFrame, color: Color3, name: string, neon: boolean?, cyl: boolean?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Smooth
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

local function toolIndex(id: any): number?
	for i, def in Config.TOOLS do
		if def.id == id then
			return i
		end
	end
	return nil
end

-- The tool lent to a first-timer until their first sale (data.run.loaner, Config.FIRST_TIMER), as its index, or nil
-- (none, or they own it by now).
local function loanIndex(data): number?
	local i = data.run.loaner and toolIndex(data.run.loaner)
	return if i and i > data.run.tool then i else nil
end

-- Make sure the player has every tool they own this run, once each (the hotbar shows them all). A tool that is
-- new (just bought, or the best one after a respawn) is equipped straight away. A first-timer's loaned tool comes
-- on top (tagged Loaner) and goes again when the loan ends; then they hold their best own tool.
function Tools.give(player: Player)
	local data = PlayerData.get(player)
	if not data or not data.run then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	if not backpack then
		return
	end
	-- a PERMANENT (Robux) tool lifts the run's best tool up to it, from the first second of every run
	for id in data.tools or {} do
		local i = toolIndex(id)
		if i and i > data.run.tool then
			data.run.tool = i
			PlayerData.changed(player)
		end
	end
	local best = math.clamp(data.run.tool, 1, #Config.TOOLS)
	local loan = loanIndex(data)
	local have: { [number]: Tool } = {}
	local lent: Tool? = nil
	for _, container in { backpack, char } do
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("ToolId") then
					local i = toolIndex(t:GetAttribute("ToolId"))
					if t:GetAttribute("Loaner") then
						if i and i == loan and not lent then
							lent = t
						else
							-- the loan is over (or they bought their own): a push mower comes off the character too
							-- (it's still held while it's destroyed, so its own clean-up can't tell)
							if PUSH_MOWERS[t:GetAttribute("ToolId")] and t.Parent == char then
								detachPushMower(char)
							end
							t:Destroy()
						end
					elseif not i or i > best or have[i] then
						t:Destroy()
					else
						have[i] = t
					end
				end
			end
		end
	end
	local newBest: Tool? = nil
	for i = 1, best do
		if not have[i] then
			local tool = Tools.build(Config.TOOLS[i])
			tool.Parent = backpack
			have[i] = tool
			if i == best then
				newBest = tool
			end
		end
	end
	if loan and not lent then
		local tool = Tools.build(Config.TOOLS[loan])
		tool:SetAttribute("Loaner", true)
		tool.ToolTip = "On loan until your first sale"
		tool.Parent = backpack
		newBest = tool
	end
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and not newBest and not char:FindFirstChildOfClass("Tool") then
		newBest = have[best] -- (a loan just ended: hold your own best tool)
	end
	if newBest and hum then
		hum:EquipTool(newBest)
	end
end

-- The tool the player is holding right now (its def), or nil. Only tools they own count.
function Tools.equipped(player: Player)
	local char = player.Character
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end
	local i = toolIndex(tool:GetAttribute("ToolId"))
	local data = PlayerData.get(player)
	if not i or not data or not data.run then
		return nil
	end
	if i > data.run.tool and not (tool:GetAttribute("Loaner") and i == loanIndex(data)) then
		return nil
	end
	return require(script.Parent.SkillTrees).boost(player, Config.TOOLS[i], tool), tool -- (30 Oct) with its skill tree
end

-- Play the default "slash" arm swing (the stock Animate script listens for this).
function Tools.slash(tool: Tool)
	local trail = tool:FindFirstChild("ReapTrail", true) :: Trail?
	if trail then
		trail.Enabled = true
		task.delay(0.4, function()
			trail.Enabled = false
		end)
	end
	local v = Instance.new("StringValue")
	v.Name = "toolanim"
	v.Value = "Slash"
	v.Parent = tool
	task.delay(0.3, function()
		v:Destroy()
	end)
end

return Tools
