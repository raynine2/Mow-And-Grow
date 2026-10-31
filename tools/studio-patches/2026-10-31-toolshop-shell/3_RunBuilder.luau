-- Installs RunBuilder (git's exact text, 57175 1066027528) into game.ServerScriptService.MowALawn. Run in Edit mode.
local src = [======[
-- Builds a run's map: ONE continuous world like Chop A Forest's (see Config.MAP), a 3 x 3 grid of fenced plots.
-- The hub (shredder, tool shop, bag stand, garage, gas pump) is the middle plot of the south row; the eight areas
-- fill the rest, each with its own ground and props, and every fence two plots share has a gate in the middle.
-- A second shredder (the drop-off) stands in the middle of the first area. A forest belt and a ring of snowy
-- mountains close the world off.
-- Grass patches are spawned by Field (positions from RunBuilder.patches); this file builds the static world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local CampBuildings = require(script.Parent.CampBuildings)
local ShopRoom = require(script.Parent.ShopRoom)
local ShopShell = require(script.Parent.ShopShell) -- (30 Oct evening) the ForgeGUI cabin round the Tool Shop
local Environment = require(script.Parent.Environment)
local Ground = require(script.Parent.Ground)
local Landmarks = require(script.Parent.Landmarks)

local RunBuilder = {}

local FLOOR_Y = 0 -- top of the ground (Terrain)

-- Where the hub's buildings stand (position, and the point their front looks toward). The plot map's yard, or,
-- in the generated world (Config.WORLD_GEN), the village laid out as a little main street: the walk runs north
-- from the spawn to the fountain, the tool shop and the garage on its west side facing it, the bag stand and the
-- shredder (its sell pad toward the walk) on the east side.
local SPOT = {
	toolShop = { Vector3.new(24, FLOOR_Y, -40), Vector3.new(0, FLOOR_Y, -40) },
	bagStand = { Vector3.new(28, FLOOR_Y, -68), Vector3.new(0, FLOOR_Y, -68) },
	garage = { Vector3.new(-30, FLOOR_Y, -64), Vector3.new(0, FLOOR_Y, -64) },
	shredder = { Vector3.new(-24, FLOOR_Y, -36), Vector3.new(-48, FLOOR_Y, -36) }, -- drum toward the spawn
	coinsSign = { Vector3.new(-38, FLOOR_Y, -50), Vector3.new(-6, FLOOR_Y, -68) },
	spawn = Vector3.new(0, 0.8, -68),
}
if Config.WORLD_GEN then
	SPOT = {
		toolShop = { Vector3.new(-34, FLOOR_Y, -46), Vector3.new(0, FLOOR_Y, -46) },
		bagStand = { Vector3.new(32, FLOOR_Y, -48), Vector3.new(0, FLOOR_Y, -48) },
		garage = { Vector3.new(-34, FLOOR_Y, -14), Vector3.new(0, FLOOR_Y, -14) },
		shredder = { Vector3.new(40, FLOOR_Y, -14), Vector3.new(80, FLOOR_Y, -14) }, -- sell pad (behind it) toward the walk
		coinsSign = { Vector3.new(42, FLOOR_Y, 4), Vector3.new(0, FLOOR_Y, 4) },
		spawn = Vector3.new(0, 0.8, -74),
	}
end
local function spotAt(name: string): CFrame
	local s = SPOT[name]
	return CFrame.lookAt(s[1], s[2])
end

-- An invisible part to hang a prompt on.
local function promptSpot(parent: Instance, cf: CFrame, name: string): Part
	local p = PropKit.part({ size = Vector3.new(2, 2, 2), cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = name })
	p.CanQuery = false
	return p
end

-------------------------------------------------------------------------------------------------------------
-- tool shop: a log cabin with every tool in a frame on its walls (like Chop A Forest's axe wall)
-------------------------------------------------------------------------------------------------------------
local TOOL_MODEL = {
	Scissors = "tool_scissors",
	Sickle = "tool_sickle",
	PushMower = "tool_pushmower",
	WeedWhacker = "tool_whacker",
	MegaScythe = "tool_scythe",
	LaserMower = "tool_lasermower",
}
-- where each frame hangs in the cabin's room (cabin studs): four on the back wall, one on each side wall
local FRAME_SPOTS = {
	{ Vector3.new(9, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(3, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(-3, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(-9, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(11.77, 1.7, 7.3), 90, 0.66 },
	{ Vector3.new(-11.77, 1.7, 7.3), -90, 0.66 },
}
-- hand tools hang across the pegs: their length (model Z) along the board, flat side out
local HANG = CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90))

local function toolFrame(parent: Instance, cabinAt: CFrame, tool, spot)
	local s = spot[3]
	local cf = cabinAt * CFrame.new(spot[1]) * CFrame.Angles(0, math.rad(spot[2]), 0)
	if not Models.place("tool_wall_frame", parent, cf, s, true) then
		PropKit.brick(parent, Vector3.new(6, 5, 0.3) * s, cf * CFrame.new(Vector3.new(0, 3.6, 0) * s), Color3.fromRGB(232, 176, 112), "ToolBoard", Enum.Material.WoodPlanks)
		PropKit.brick(parent, Vector3.new(5.4, 1.6, 0.4) * s, cf * CFrame.new(Vector3.new(0, 0.8, -0.3) * s), Color3.fromRGB(62, 42, 30), "PriceBoard", Enum.Material.Wood)
	end
	PropKit.facePanel(parent, cf, Vector3.new(0, 0.82, -0.57), Vector2.new(5.4, 1.5), "$" .. Format.commas(tool.cost), PropKit.PRICE, s)
	local onFloor = tool.id == "PushMower" or tool.id == "LaserMower"
	local name = TOOL_MODEL[tool.id]
	if onFloor then
		-- mowers stand on the cabin floor in front of their frame
		Models.place(name, parent, cf * CFrame.new(0, -1.2, -3.6 * s), 0.85, true)
	else
		local target = cf * CFrame.new(Vector3.new(0, 3.9, -0.85) * s)
		local m = Models.place(name, parent, target * HANG, 1, true)
		if m then
			local _, size = m:GetBoundingBox()
			local fit = 4.2 * s / math.max(size.X, size.Y, size.Z)
			if fit < 1 then
				m:ScaleTo(fit)
			end
			local box = m:GetBoundingBox()
			m:PivotTo(m:GetPivot() + (target.Position - box.Position))
		end
	end
	local prompt = PropKit.prompt(promptSpot(parent, cf * CFrame.new(0, 3.5 * s, -1.5), "ToolFrame"), "View", tool.name, "ToolView", 7)
	prompt:SetAttribute("Item", tool.id)
end

-- The roomy version (Config.SHOP_SCALE): the cabin 1.5x as big, the four hand tools on the back wall each in a
-- bigger frame with a carved name plaque above it, the two push mowers on display pedestals (shop_pedestal, with
-- a name + price plaque) on the floor. Every display is a Folder "ToolDisplay" (ToolId attribute) so the client
-- (client/ShopDisplays) can colour it by owned / affordable / locked and spin the tool when you walk up.
local SHOP_SCALE = 1.5
local WALL_TOOLS = { "Scissors", "Sickle", "WeedWhacker", "MegaScythe" }
local FLOOR_TOOLS = { PushMower = -9, LaserMower = 9 }

local function toolDef(id: string)
	for _, t in Config.TOOLS do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- Text on a face (the part's -Z side), lit softly; returns the label so the client can recolour it.
local function plaqueText(parent: Instance, cf: CFrame, size: Vector2, text: string, color: Color3, name: string): TextLabel
	local p = PropKit.part({ size = Vector3.new(size.X, size.Y, 0.05), cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, studs = false, name = name })
	p.CanQuery = false
	local label = PropKit.surfaceText(p, text, color)
	label.Size = UDim2.fromScale(0.92, 0.86)
	label.Position = UDim2.fromScale(0.04, 0.07)
	return label
end

-- A little brass-rimmed status lamp (the client tints its glass: green owned, yellow affordable, grey locked).
local function statusLamp(parent: Instance, cf: CFrame)
	local rim = PropKit.cylinder(parent, 0.34, 0.12, cf * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(226, 176, 74))
	rim.Name = "StatusRim"
	rim.CanCollide = false
	rim.CanQuery = false
	local glass = PropKit.part({ size = Vector3.new(0.42, 0.42, 0.42), cf = cf * CFrame.new(0, 0, -0.05), color = Color3.fromRGB(150, 150, 150), parent = parent, collide = false, studs = false, name = "StatusLamp", shape = Enum.PartType.Ball })
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.15
	glass.CanQuery = false
end

local function wallDisplay(shop: Instance, at: CFrame, tool, x: number)
	local d = PropKit.folder("ToolDisplay", shop)
	d:SetAttribute("ToolId", tool.id)
	local S = SHOP_SCALE
	local cf = at * CFrame.new(x, 0.75, 9.35 * S) * CFrame.Angles(0, 0, 0)
	local fs = 1.05
	local base = cf * CFrame.new(0, 1.2, 0)
	if not Models.place("tool_wall_frame", d, base, fs, true) then
		PropKit.brick(d, Vector3.new(6, 5, 0.3) * fs, base * CFrame.new(Vector3.new(0, 3.6, 0) * fs), Color3.fromRGB(232, 176, 112), "ToolBoard", Enum.Material.WoodPlanks)
	end
	-- the price on the frame's price board
	local price = PropKit.facePanel(d, base, Vector3.new(0, 0.82, -0.57), Vector2.new(5.4, 1.5), "$" .. Format.commas(tool.cost), PropKit.PRICE, fs)
	price.Parent.Name = "PriceText"
	statusLamp(d, base * CFrame.new(Vector3.new(2.4, 0.82, -0.75) * fs))
	-- the name plaque above the frame
	local plaqueAt = base * CFrame.new(0, 6.9 * fs, -0.05)
	if Models.place("shop_plaque", d, plaqueAt, 0.95, true) then
		plaqueText(d, plaqueAt * CFrame.new(0, 0, -0.38 * 0.95), Vector2.new(4.4, 1.15), tool.name:upper(), PropKit.TITLE, "NameText")
	else
		PropKit.facePanel(d, plaqueAt, Vector3.zero, Vector2.new(5, 1.3), tool.name:upper(), PropKit.TITLE)
	end
	-- the tool across the pegs
	local target = base * CFrame.new(Vector3.new(0, 3.9, -0.85) * fs)
	-- (30 Oct) the Mega Scythe's blade now stands out from its shaft (server/PartModels/tool_scythe): it lies flat on
	-- the board, the shaft across it and the blade up, a bit bigger than the rest (the top tool, $300,000)
	local scythe = tool.id == "MegaScythe"
	local m = Models.place(TOOL_MODEL[tool.id], d, target * (if scythe then CFrame.Angles(0, math.rad(90), 0) else HANG), 1, true)
	if m then
		local _, size = m:GetBoundingBox()
		local fit = (if scythe then 5.2 else 4.4) * fs / math.max(size.X, size.Y, size.Z)
		if fit < 1 then
			m:ScaleTo(fit)
		end
		local box = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (target.Position - box.Position))
		m:SetAttribute("DisplayItem", true)
	end
	-- a small warm picture light over each frame (soft: the room shouldn't glare)
	local lampAt = base * CFrame.new(0, 6.0 * fs, -1.2)
	local lamp = PropKit.part({ size = Vector3.new(1.4, 0.3, 0.5), cf = lampAt, color = Color3.fromRGB(70, 46, 30), parent = d, collide = false, studs = false, name = "PictureLamp" })
	lamp.Material = Enum.Material.Wood
	local bulb = PropKit.part({ size = Vector3.new(1.1, 0.12, 0.3), cf = lampAt * CFrame.new(0, -0.18, 0), color = Color3.fromRGB(255, 226, 170), parent = d, collide = false, studs = false, name = "PictureBulb" })
	bulb.Material = Enum.Material.Neon
	bulb.Transparency = 0.35
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 70
	light.Brightness = 0.9
	light.Range = 9
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Parent = bulb
	local prompt = PropKit.prompt(promptSpot(d, base * CFrame.new(0, 3.5 * fs, -1.5), "ToolFrame"), "View", tool.name, "ToolView", 8)
	prompt:SetAttribute("Item", tool.id)
end

local function floorDisplay(shop: Instance, at: CFrame, tool, x: number)
	local d = PropKit.folder("ToolDisplay", shop)
	d:SetAttribute("ToolId", tool.id)
	local S = SHOP_SCALE
	local cf = at * CFrame.new(x, 0.75, 4.2 * S)
	local top = 1.66
	if Models.place("shop_pedestal", d, cf, 1, true) then
		PropKit.collider(d, cf, Vector3.new(0, 0.85, 0), Vector3.new(6.4, 1.7, 6.4))
		-- the slanted plaque at the front: name on top, price under it
		local board = cf * CFrame.new(0, 1.55, -4.2) * CFrame.Angles(math.rad(28), 0, 0)
		plaqueText(d, board * CFrame.new(0, 0.3, -0.13), Vector2.new(3.1, 0.7), tool.name:upper(), PropKit.TITLE, "NameText")
		local price = plaqueText(d, board * CFrame.new(0, -0.38, -0.13), Vector2.new(3.1, 0.6), "$" .. Format.commas(tool.cost), PropKit.PRICE, "PriceText")
		local _ = price
		statusLamp(d, board * CFrame.new(1.45, -0.38, -0.14))
	else
		PropKit.cylinder(d, 3, 1.6, cf * CFrame.new(0, 0.8, 0), Color3.fromRGB(150, 96, 56))
		top = 1.6
	end
	local m = Models.place(TOOL_MODEL[tool.id], d, cf * CFrame.new(0, top, 0.3) * CFrame.Angles(0, math.rad(if x < 0 then -25 else 25), 0), 0.78, true)
	if m then
		m:SetAttribute("DisplayItem", true)
	end
	local prompt = PropKit.prompt(promptSpot(d, cf * CFrame.new(0, 3, -2.5), "ToolFrame"), "View", tool.name, "ToolView", 8)
	prompt:SetAttribute("Item", tool.id)
end

local function toolShop(m: Instance, info)
	local shop = PropKit.folder("TOOL SHOP", m)
	local at = spotAt("toolShop")
	local S = SHOP_SCALE
	-- the piece the saved map lines this unit up by (MapStore: first unique part path, alphabetically)
	local anchor = promptSpot(shop, at, "0Anchor")
	local _ = anchor
	-- the voxel log shop (server/CampBuildings, owner 27 Oct), else the Blender cabin
	local voxel = CampBuildings.ON and CampBuildings.shop(shop, at, Config.HUB_SIGNS)
	if not voxel and not PropKit.cabin(shop, at, S) then
		PropKit.stall(m, CFrame.new(28, 0, -55) * CFrame.Angles(0, math.rad(90), 0), "TOOL SHOP", Color3.fromRGB(255, 80, 80), "Tools")
		return
	end
	if Config.HUB_SIGNS and not voxel then
		PropKit.cabinSign(shop, at, S, "TOOL SHOP", PropKit.TITLE)
	end
	if voxel and CampBuildings.ROOM and ShopRoom.ON then
		-- (30 Oct) Chop A Forest's shop layout: every tool on a board, the Mega Scythe on the spotlight board, the
		-- fireplace, the table, the yard (server/ShopRoom)
		ShopRoom.build(shop, at, Config.HUB_SIGNS)
	else
		for i, id in WALL_TOOLS do
			local t = toolDef(id)
			if t then
				wallDisplay(shop, at, t, (i - 2.5) * 8.4)
			end
		end
		for id, x in FLOOR_TOOLS do
			local t = toolDef(id)
			if t then
				floorDisplay(shop, at, t, x)
			end
		end
	end
	-- (30 Oct evening, owner: "the house at spawn feels a bit idk"; picked: remake it with ForgeGUI, keep the room)
	-- the ForgeGUI cabin round the log lodge (server/ShopShell); the lodge is the room inside it
	if voxel then
		ShopShell.dress(shop, at)
	end
	-- the Guide arrow points just outside the door ("Counter" looks out of the door)
	promptSpot(shop, at * CFrame.new(0, 2, -6 * S), "Counter")
	-- a lantern at the door (the voxel shop has its own two)
	if not voxel then
		Models.place("lantern_post", shop, at * CFrame.new(5 * S, 0.75, -10.6 * S), 0.9, true)
	end
	local _ = FRAME_SPOTS
	local _ = toolFrame
end

-- The ForgeGUI bag stand (fitted into the old stall's box: 10.9 wide, front at z -4.4, its table about y 3). The
-- bag tiers and the Bottomless Sack stand on stumps in a row in front of it, each tier with its price.
local function forgeBagStand(stand: Instance, at: CFrame)
	PropKit.collider(stand, at, Vector3.new(0, 5, -2.25), Vector3.new(10.8, 10, 4.2))
	local stump = Color3.fromRGB(122, 84, 52)
	local function onStump(x: number): CFrame
		PropKit.cylinder(stand, 1.2, 1.6, at * CFrame.new(x, 0.8, -6.8), stump).Name = "Stump"
		return at * CFrame.new(x, 1.6, -6.8)
	end
	for i, bag in Config.BAGS do
		local x = ({ -6, -2, 2 })[i]
		if x then
			Models.place(bag.model, stand, onStump(x), 0.75, true)
			PropKit.facePanel(stand, at, Vector3.new(x, 0.75, -8.05), Vector2.new(2.4, 0.85), "$" .. Format.short(bag.cost), PropKit.PRICE)
		end
	end
	Models.place("bag_infinite", stand, onStump(6), 0.55, true)
	Models.place("tool_vacuum", stand, at * CFrame.new(-7.6, 0, -2), 0.8, true)
	PropKit.prompt(promptSpot(stand, at * CFrame.new(0, 3, -9), "BagCounter"), "Shop", "Bags & Gear", "Bags", 12)
end

-- The Bag Stand (bag_stand model): a striped market stall by the spawn. The three bag tiers stand on its stumps,
-- the Bottomless Sack sits on the counter and the Leaf Vacuum leans beside it. Its prompt opens the Bags window.
local function bagStand(m: Instance)
	local stand = PropKit.folder("BAG STAND", m)
	local at = spotAt("bagStand") -- facing the walk
	if not Models.place("bag_stand", stand, at, 1, true) then
		PropKit.stall(stand, at, "BAGS", Color3.fromRGB(90, 190, 90), "Bags")
		return
	end
	if Models.isForge("bag_stand") then
		forgeBagStand(stand, at)
		return
	end
	if Config.HUB_SIGNS then
		PropKit.facePanel(stand, at, Vector3.new(0, 10.6, 0.9), Vector2.new(9.4, 2.2), "BAGS & GEAR", PropKit.TITLE)
	end
	PropKit.collider(stand, at, Vector3.new(0, 3.7, 0.7), Vector3.new(14, 7.4, 3))
	-- the bags on their stumps (model studs: stump tops at y 2, z -4.5), each with its price in front
	for i, bag in Config.BAGS do
		local x = ({ -5, 0, 5 })[i]
		if x then
			PropKit.collider(stand, at, Vector3.new(x, 1, -4.5), Vector3.new(2.7, 2, 2.7))
			Models.place(bag.model, stand, at * CFrame.new(x, 2, -4.5), 1.1, true)
			PropKit.facePanel(stand, at, Vector3.new(x, 1, -5.85), Vector2.new(2.6, 0.9), "$" .. Format.short(bag.cost), PropKit.PRICE)
		end
	end
	Models.place("bag_infinite", stand, at * CFrame.new(0, 3.53, -0.6), 0.75, true)
	Models.place("tool_vacuum", stand, at * CFrame.new(-8.6, 2.65, -1), 0.8, true)
	PropKit.prompt(promptSpot(stand, at * CFrame.new(0, 3, -7.5), "BagCounter"), "Shop", "Bags & Gear", "Bags", 12)
end

-- Gas pump: prompt refuels your mower if it's parked nearby. `facing` is where its front looks.
local function gasPump(parent: Instance, pos: Vector3, info, facing: Vector3?)
	local cf = CFrame.lookAt(pos, pos + (facing or -Vector3.zAxis))
	local body: BasePart
	if Models.place("gas_pump", parent, cf, 1.1, true) then
		body = PropKit.collider(parent, cf, Vector3.new(0, 3, 0), Vector3.new(3.2, 6.2, 2.8), 1.1)
		body.Name = "GasPump"
	else
		local red = Color3.fromRGB(240, 60, 60)
		body = PropKit.brick(parent, Vector3.new(3, 6, 2.4), cf * CFrame.new(0, 3, 0), red, "GasPump")
		PropKit.brick(parent, Vector3.new(3.4, 1, 2.8), cf * CFrame.new(0, 6.5, 0), Color3.fromRGB(255, 255, 255), "PumpTop")
		PropKit.brick(parent, Vector3.new(2, 1.4, 0.4), cf * CFrame.new(0, 4.6, -1.3), Color3.fromRGB(40, 40, 50), "PumpScreen")
	end
	if Config.HUB_SIGNS then
		PropKit.billboard(body, "GAS", PropKit.TEXT, Vector2.new(5, 2), Vector3.new(0, 5, 0), 120)
	end
	local prompt = PropKit.prompt(body, "Refuel", "Gas Pump", nil, 14)
	prompt:SetAttribute("Pump", true)
	table.insert(info.pumps, { pos = pos, prompt = prompt })
end

-- The garage: a log garage in the Tool Shop's style (Blender garage_shed) where your mower spawns, open at the
-- front with the roll-up door rolled up, with a gas pump beside it. Falls back to the old open bay.
local function garageShed(g: Instance, at: CFrame): boolean
	-- the voxel log garage with its roll-up door (server/CampBuildings, owner 27 Oct)
	if CampBuildings.ON and CampBuildings.garage(g, at) then
		promptSpot(g, at, "0Anchor") -- lines the saved map's garage up with this one (MapStore)
		return true
	end
	if not Models.place("garage_shed", g, at, 1, true) then
		return false
	end
	promptSpot(g, at, "0Anchor") -- lines the saved map's garage up with this one (MapStore)
	PropKit.collider(g, at, Vector3.new(0, 5, 7.4), Vector3.new(15.4, 10, 1.4))
	for _, x in { -6.9, 6.9 } do
		PropKit.collider(g, at, Vector3.new(x, 5, 0.4), Vector3.new(1.3, 10, 16))
	end
	-- the two roof slabs are solid too (owner, 27 Oct: you could hop up from the pump, walk into the roof and fall
	-- through it)
	for _, d in g:GetDescendants() do
		if d:IsA("BasePart") and d.Size.X > 5 and d.Size.Z > 10 and d.Size.Y < 1 then
			local tilt = math.deg(math.acos(math.clamp(math.abs(d.CFrame.UpVector.Y), 0, 1)))
			if tilt > 15 and tilt < 60 then
				d.CanCollide = true
			end
		end
	end
	plaqueText(g, at * CFrame.new(0, 11.0, -7.27), Vector2.new(7.0, 1.6), "GARAGE", PropKit.TITLE, "SignText")
	-- the lamp under the roof (soft and warm)
	local lamp = promptSpot(g, at * CFrame.new(0, 7.9, 1), "LampGlow")
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 220, 170)
	l.Brightness = 0.6
	l.Range = 12
	l.Parent = lamp
	return true
end

local function garageBay(m: Instance, info)
	local at = spotAt("garage")
	local pos = at.Position
	local g = PropKit.folder("Garage", m)
	if garageShed(g, at) then
		-- built above
	elseif Models.place("party_booth", g, at, 1.1, true) then
		if Config.HUB_SIGNS then
			PropKit.facePanel(g, at, Vector3.new(0, 7, 5.93), Vector2.new(10.4, 4), "GARAGE", PropKit.TITLE, 1.1)
		end
		for _, x in { -7.2, 7.2 } do
			PropKit.collider(g, at, Vector3.new(x, 5, 6.6), Vector3.new(1.4, 10, 1.4), 1.1)
			PropKit.collider(g, at, Vector3.new(x, 1.2, 0), Vector3.new(0.8, 2.4, 14), 1.1)
		end
		PropKit.collider(g, at, Vector3.new(0, 1.2, 7), Vector3.new(14, 2.4, 0.8), 1.1)
	else
		PropKit.stall(g, CFrame.new(-28, 0, -70) * CFrame.Angles(0, math.rad(-90), 0), "GARAGE", Color3.fromRGB(160, 95, 255), "Mowers")
		PropKit.pad(g, pos, 5, Color3.fromRGB(160, 95, 255), "MOWER SPAWN")
	end
	PropKit.prompt(promptSpot(g, at * CFrame.new(0, 3, -8.5), "GaragePrompt"), "Open", "Garage", "Mowers", 12)
	info.garageSpawn = at * CFrame.new(0, 2, 0)
	-- beside the voxel garage the pump stands a little further out (CampBuildings.PUMP)
	gasPump(g, (at * (if CampBuildings.ON then CampBuildings.PUMP else CFrame.new(10, 0, -6))).Position, info, Vector3.xAxis)
end

-------------------------------------------------------------------------------------------------------------
-- hub
-------------------------------------------------------------------------------------------------------------
-- A Giant Grass Shredder (Blender model) at `at` (drum toward at.LookVector) with its log-framed sell pad in
-- front of the hopper. Every shredder is a sell spot (info.sellPads); the first one is the hub's.
-- The ForgeGUI shredder's gear and crank are on its -X side: turned a quarter so they face the sell pad, where you
-- stand (owner, 27 Oct: "rotate the machine to the right spot where you stand"; it stood side-on to the pad).
local SHREDDER_TURN = CFrame.Angles(0, math.rad(90), 0)

local function shredderAt(parent: Instance, info, at: CFrame, name: string): boolean
	local s = PropKit.folder(name, parent)
	local forge = Models.isForge("shredder")
	local machine = if forge then at * SHREDDER_TURN else at -- (the pad stays where it was: `at`)
	if not Models.place("shredder", s, machine, 1.15, true) then
		s:Destroy()
		return false
	end
	-- the ForgeGUI shredder (9 wide, 8.5 deep, its hopper on top) or the older Blender one
	PropKit.collider(s, machine, if forge then Vector3.new(0, 5, -1.55) else Vector3.new(0, 5, -0.7), if forge then Vector3.new(9, 10, 8.4) else Vector3.new(7.8, 10, 14.5), 1.15)
	local mouth = (machine * CFrame.new((if forge then Vector3.new(0, 9.5, -1) else Vector3.new(0.3, 8.8, 4.8)) * 1.15)).Position
	local out = (machine * CFrame.new((if forge then Vector3.new(0, 1.2, -6.6) else Vector3.new(0, 1.2, -8.6)) * 1.15)).Position
	local padAt = at * CFrame.new(0, 0, 16.5)
	local sellPos = padAt.Position
	if Models.place("sell_pad", s, padAt, 1, true) then
		PropKit.collider(s, padAt, Vector3.new(0, 0.41, 0), Vector3.new(13, 0.82, 13))
	else
		PropKit.pad(s, sellPos, 6, Color3.fromRGB(80, 220, 80))
	end
	local holder = promptSpot(s, CFrame.new(sellPos + Vector3.new(0, 1, 0)), "SellLabel")
	if Config.HUB_SIGNS then
		PropKit.billboard(holder, "DROP BUNDLES", PropKit.TEXT, Vector2.new(12, 2.6), Vector3.new(0, 5, 0), 120)
	end
	info.sellPads = info.sellPads or {}
	table.insert(info.sellPads, { pos = sellPos, radius = 7, mouth = mouth, out = out })
	if not info.sellPos then
		info.sellPos = sellPos
		info.sellRadius = 7
		info.shredderMouth = mouth
		info.shredderOut = out
	end
	return true
end

local function shredder(m: Instance, info): boolean
	if not shredderAt(m, info, spotAt("shredder"), "Shredder") then
		return false
	end
	local s = m:FindFirstChild("Shredder") :: Instance
	-- the 2X COINS board next to the machine (opens the store)
	local signAt = spotAt("coinsSign")
	if Config.HUB_SIGNS and Models.place("start_sign", s, signAt, 0.45, true) then
		PropKit.facePanel(s, signAt, Vector3.new(0, 9.3, -0.62), Vector2.new(27, 4), "2X COINS", PropKit.TITLE, 0.45)
		PropKit.facePanel(s, signAt, Vector3.new(0, 6.1, -0.62), Vector2.new(27, 1.5), "BUY!", PropKit.PRICE, 0.45)
		PropKit.prompt(promptSpot(s, signAt * CFrame.new(0, 3, -1.5), "CoinsSign"), "Open", "2x Coins", "Store", 10)
	end
	return true
end

local function classesKiosk(m: Instance, at: CFrame)
	local k = PropKit.folder("CLASSES", m)
	promptSpot(k, at, "0Anchor")
	if Config.CLASSES_BLACK_HOLE then
		require(script.Parent.BlackHole).build(k, at)
		return
	end
	if not Models.place("classes_kiosk", k, at, 1, true) then
		k:Destroy()
		PropKit.stall(m, at, "CLASSES", Color3.fromRGB(160, 95, 255), "Classes")
		return
	end
	-- solid: the platform steps, the counter arc, the observatory, the pillars
	PropKit.collider(k, at, Vector3.new(0, 0.65, 0), Vector3.new(12.4, 1.3, 12.4))
	PropKit.collider(k, at, Vector3.new(0, 2.6, -3.3), Vector3.new(9.4, 2.6, 2.4))
	PropKit.collider(k, at, Vector3.new(0, 3, 3.4), Vector3.new(6, 3.4, 6))
	for _, x in { -5.2, 5.2 } do
		PropKit.collider(k, at, Vector3.new(x, 5.9, 0.6), Vector3.new(0.9, 9.2, 0.9))
	end
	-- the sign on the arch
	local sign = plaqueText(k, at * CFrame.new(0, 11.2, 0.25), Vector2.new(7.2, 1.6), "CLASSES", Color3.fromRGB(214, 190, 255), "SignText")
	sign.Font = Enum.Font.LuckiestGuy
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 150, 255))
	grad.Rotation = 90
	grad.Parent = sign
	-- where the hologram floats (client/ClassHolo builds it), and the counter prompt
	local holo = promptSpot(k, at * CFrame.new(0, 4.15, -0.6), "HoloLens")
	holo:SetAttribute("ClassHolo", true)
	PropKit.prompt(promptSpot(k, at * CFrame.new(0, 3, -5.6), "Counter"), "Browse", "Classes", "Classes", 12)
	-- the lamps on their posts and the projector glow (soft)
	for _, x in { -6.2, 6.2 } do
		local p = promptSpot(k, at * CFrame.new(x, 3.7, -2.6), "LampGlow")
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 230, 180)
		l.Brightness = 0.7
		l.Range = 8
		l.Parent = p
	end
end

local function hub(world: Instance, info)
	local m = PropKit.folder("Hub", world)
	-- ground: grass with a dirt yard around the cabin and the machines, and a worn path out to the first field
	-- (Terrain version; the Blender ground_hub model has the same layout)
	if not info.meshGround then
		Ground.patch(0, -48, 92, 56, Enum.Material.Ground, 3)
		Ground.patch(-8, -36, 16, 16, Enum.Material.Mud, 6) -- trodden mud at the sell pad
	end
	Environment.spawn(m, CFrame.lookAt(SPOT.spawn, SPOT.spawn + Vector3.zAxis * 10))
	toolShop(m, info)
	bagStand(m)
	if Config.WORLD_GEN then
		-- the class stand (gems): a black hole you jump into (server/BlackHole), or with CLASSES_BLACK_HOLE off a
		-- little space observatory (classes_kiosk) whose projector shows the deal as a hologram (client/ClassHolo).
		-- Either opens the card deal (client/ClassDeal).
		local at = Vector3.new(-24, FLOOR_Y, 12)
		classesKiosk(m, CFrame.lookAt(at, Vector3.new(0, FLOOR_Y, 12)))
	end
	garageBay(m, info)
	if shredder(m, info) then
		info.shredderUnit = m:FindFirstChild("Shredder") -- a working piece: its sell pad follows it (server/MapStore)
		return
	end

	-- Giant Grass Shredder (brick version, used until the Blender model is uploaded)
	local s = PropKit.folder("Shredder", m)
	local base = CFrame.new(-28, 0, -45) * CFrame.Angles(0, math.rad(-90), 0)
	local orange = Color3.fromRGB(255, 140, 40)
	local body = PropKit.brick(s, Vector3.new(14, 10, 10), base * CFrame.new(0, 5, 0), orange, "ShredderBody")
	PropKit.brick(s, Vector3.new(15, 1.4, 11), base * CFrame.new(0, 10.6, 0), PropKit.shade(orange, 0.8), "ShredderRim")
	-- hopper (stepped funnel)
	for i = 0, 2 do
		local w = 12 + i * 2.4
		PropKit.brick(s, Vector3.new(w, 1.6, 8 + i * 2), base * CFrame.new(0, 12 + i * 1.6, 0), PropKit.shade(Color3.fromRGB(255, 205, 50), 1 - i * 0.05), "Hopper")
	end
	local mouth = PropKit.brick(s, Vector3.new(10, 0.6, 6), base * CFrame.new(0, 16.6, 0), Color3.fromRGB(35, 30, 40), "Mouth")
	mouth.Name = "ShredderMouth"
	-- teeth rollers
	for _, x in { -2.5, 2.5 } do
		local roller = PropKit.cylinder(s, 1.4, 9, base * CFrame.new(x, 16.2, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(180, 180, 195))
		roller.Name = "Roller"
		roller:SetAttribute("Spin", 6)
	end
	-- coin chute
	PropKit.brick(s, Vector3.new(4, 3, 4), base * CFrame.new(0, 1.5, -6.5), Color3.fromRGB(60, 60, 70), "Chute")
	PropKit.brick(s, Vector3.new(6, 1, 3), base * CFrame.new(0, 0.5, -9), Color3.fromRGB(255, 205, 50), "CoinTray")
	local sign = PropKit.sign(s, base * CFrame.new(0, 6, -5.2), Vector3.new(12, 3, 0.6), "SHREDDER", Color3.fromRGB(80, 200, 80), PropKit.TEXT)
	sign.Name = "ShredderSign"
	local sellPos = (base * CFrame.new(0, 0, -13)).Position
	PropKit.pad(s, sellPos, 6, Color3.fromRGB(80, 220, 80), "SELL BUNDLES")
	info.sellPos = sellPos
	info.sellRadius = 7
	info.shredderMouth = mouth.Position
	info.shredderOut = (base * CFrame.new(0, 1, -9)).Position
	info.sellPads = info.sellPads or {}
	table.insert(info.sellPads, 1, { pos = sellPos, radius = 7, mouth = info.shredderMouth, out = info.shredderOut })
	body:SetAttribute("Shredder", true)
	info.shredderUnit = s
end

-- The hub's buildings (tool shop, bag stand, garage + pump, shredder, spawn) around (0, 0, -48), for another map
-- to use (server/RunWorld puts them in the generated world's village). Set info.meshGround to skip the Terrain.
RunBuilder.hub = hub
RunBuilder.gasPump = gasPump -- (server/Outposts: a pump in every area's camp)

-------------------------------------------------------------------------------------------------------------
-- the world: a 3 x 3 grid of fenced plots, like Chop A Forest's woods (see Config.MAP)
-------------------------------------------------------------------------------------------------------------
local M = Config.MAP
local HALF = M.cell / 2
local HUB = Config.zoneCentre(0)
local COLS, ROWS = 3, 3
local MIN_X = HUB.X + (1 - M.hubCell[1]) * M.cell - HALF
local MAX_X = HUB.X + (COLS - M.hubCell[1]) * M.cell + HALF
local MIN_Z = HUB.Z + (1 - M.hubCell[2]) * M.cell - HALF
local MAX_Z = HUB.Z + (ROWS - M.hubCell[2]) * M.cell + HALF
local MID = Vector3.new((MIN_X + MAX_X) / 2, 0, (MIN_Z + MAX_Z) / 2)
local FENCE_H = 26 -- the invisible wall over every fence, so nobody hops into a locked area

-- Each area's ground: its own Terrain material, so its own colour (Ground.COLORS), inside a grassy verge.
local AREA_GROUND = {
	lawn = Enum.Material.Grass,
	meadow = Enum.Material.LeafyGrass,
	golf = Enum.Material.Pavement,
	wheat = Enum.Material.Sandstone,
	blossom = Enum.Material.Limestone,
	reeds = Enum.Material.Mud,
	prairie = Enum.Material.Sand,
	jungle = Enum.Material.Slate,
}
local PATH_HALF = 4 -- half a dirt path's width

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
end

-- Distance from p to the segment a-b, on the ground.
local function segDist(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local len2 = ab:Dot(ab)
	local t = if len2 > 0 then math.clamp(ap:Dot(ab) / len2, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

-------------------------------------------------------------------------------------------------------------
-- an area's plan: what stands where (same every time, so the grass and the props agree)
-------------------------------------------------------------------------------------------------------------
-- keepouts: spots kept free of grass (the way in through every gate, the drop-off, the landmark, props,
-- clearings); paths: winding dirt paths from every gate to the area's heart (its landmark, or the drop-off);
-- groves: spots where the grass grows thicker.
type Keepout = { pos: Vector3, r: number, kind: string, face: Vector3? }
type Plan = { keepouts: { Keepout }, paths: { { Vector3 } }, groves: { { pos: Vector3, r: number } } }
local planCache: { [number]: Plan } = {}

local function plan(z: number): Plan
	local cached = planCache[z]
	if cached then
		return cached
	end
	local def = Config.ZONES[z]
	local style = def.style
	local c = Config.zoneCentre(z)
	local rng = Random.new(z * 3571 + 11)
	local list: { Keepout } = {}
	local paths: { { Vector3 } } = {}
	local function add(pos: Vector3, r: number, kind: string, face: Vector3?)
		table.insert(list, { pos = pos, r = r, kind = kind, face = face })
	end
	local function onPath(p: Vector3, extra: number): boolean
		for _, line in paths do
			for i = 1, #line - 1 do
				if segDist(p, line[i], line[i + 1]) < PATH_HALF + extra then
					return true
				end
			end
		end
		return false
	end
	local function free(p: Vector3, r: number): boolean
		if math.abs(p.X - c.X) > HALF - M.margin - r or math.abs(p.Z - c.Z) > HALF - M.margin - r then
			return false
		end
		for _, k in list do
			if (p - k.pos).Magnitude < k.r + r + 4 then
				return false
			end
		end
		return not onPath(p, r)
	end
	-- the way in through every gate
	local entries: { Vector3 } = {}
	for _, g in Config.gates() do
		if g.a == z or g.b == z then
			local into = flat(c - g.pos)
			add(g.pos + into * 9, 11, "gate")
			table.insert(entries, g.pos + into * 1)
		end
	end
	-- the landmark, 18-45 studs from the middle, facing the way most people come in
	local lr = Landmarks.RADIUS[style] or 12
	local entry = Config.gateInto(z)
	local comeFrom = if entry then entry.pos else c - Vector3.zAxis * HALF
	local landmark = c
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(18, 45)
		if (M.dropOff ~= z or (p - c).Magnitude > 25 + lr + 6) and free(p, lr) then
			landmark = p
			break
		end
	end
	local face = flat(comeFrom - landmark)
	add(landmark, lr, "landmark", face)
	local heart = landmark + face * (lr * 0.85)
	if M.dropOff == z then
		add(c, 25, "dropoff")
		heart = c + flat(comeFrom - c) * 22
	end
	-- winding paths: a curve from every entry to the heart, bowing a little to one side
	local function curve(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local side = flat(b - a):Cross(Vector3.yAxis)
		local ctrl = (a + b) / 2 + side * len * rng:NextNumber(-0.3, 0.3)
		local n = math.max(3, math.ceil(len / 5))
		local pts = {}
		for i = 0, n do
			local t = i / n
			local p = a:Lerp(ctrl, t):Lerp(ctrl:Lerp(b, t), t)
			table.insert(pts, Vector3.new(p.X, 0, p.Z))
		end
		table.insert(paths, pts)
	end
	for _, e in entries do
		curve(e, heart)
	end
	if M.dropOff == z then
		curve(heart, landmark + face * (lr * 0.85)) -- and on to the landmark
	end
	-- the area's own props
	local function scatter(n: number, r: number, kind: string)
		local placed, tries = 0, 0
		while placed < n and tries < n * 40 do
			tries += 1
			local p = c + Vector3.new(rng:NextNumber(-HALF, HALF), 0, rng:NextNumber(-HALF, HALF))
			if free(p, r) then
				add(p, r, kind)
				placed += 1
			end
		end
	end
	if style == "golf" then
		scatter(4, 9, "sand")
	elseif style == "meadow" then
		scatter(4, 6, "birch")
		scatter(6, 3, "flowers")
	elseif style == "wheat" then
		scatter(4, 5, "hay")
		scatter(1, 8, "haystack")
	elseif style == "blossom" then
		scatter(5, 7, "blossomtree")
		scatter(4, 3, "flowers")
	elseif style == "reeds" then
		scatter(1, 13, "pond")
	elseif style == "prairie" then
		scatter(4, 7, "autumntree")
		scatter(2, 5, "hay")
	elseif style == "jungle" then
		scatter(5, 9, "bigtree")
		scatter(4, 4, "palm")
	end
	-- two small clearings with something to find in them, and little things all over
	scatter(2, rng:NextNumber(8, 12), "clearing")
	local small = { "rock", "bush", "flowers", "mushroom", "fallenlog", "stump", "log" }
	if style == "jungle" or style == "reeds" then
		small = { "mushroom", "mushroom", "fallenlog", "bush", "rock", "stump" }
	elseif style == "meadow" or style == "blossom" then
		small = { "flowers", "flowers", "bush", "rock", "mushroom", "stump" }
	end
	for i = 1, 14 do
		scatter(1, 3, small[(i % #small) + 1])
	end
	-- groves: where the grass stands thicker
	local groves = {}
	for _ = 1, 3 do
		local p = c + Vector3.new(rng:NextNumber(-HALF + 30, HALF - 30), 0, rng:NextNumber(-HALF + 30, HALF - 30))
		table.insert(groves, { pos = p, r = rng:NextNumber(20, 30) })
	end
	local result: Plan = { keepouts = list, paths = paths, groves = groves }
	planCache[z] = result
	return result
end

-------------------------------------------------------------------------------------------------------------
-- the grass: scattered naturally (Poisson disc), thicker in groves, never on paths or props
-------------------------------------------------------------------------------------------------------------
export type PatchSpot = { cf: CFrame, scale: number }
local patchCache: { [number]: { PatchSpot } } = {}
function RunBuilder.patches(z: number): { PatchSpot }
	local cached = patchCache[z]
	if cached then
		return cached
	end
	local def = Config.ZONES[z]
	local pl = plan(z)
	local c = Config.zoneCentre(z)
	local s = def.spacing or 14
	local r0 = s * 0.72 -- the closest two clumps may stand (a bit closer in a grove)
	local rng = Random.new(z * 7919)
	local lo = HALF - M.margin - s * 0.3
	local function radiusAt(p: Vector3): number
		for _, g in pl.groves do
			if (p - g.pos).Magnitude < g.r then
				return r0 * 0.78
			end
		end
		return r0
	end
	local function blocked(p: Vector3): boolean
		if math.abs(p.X - c.X) > lo or math.abs(p.Z - c.Z) > lo then
			return true
		end
		for _, k in pl.keepouts do
			local d = p - k.pos
			if d.X * d.X + d.Z * d.Z < (k.r + s * 0.45) ^ 2 then
				return true
			end
		end
		for _, line in pl.paths do
			for i = 1, #line - 1 do
				if segDist(p, line[i], line[i + 1]) < PATH_HALF + s * 0.4 then
					return true
				end
			end
		end
		return false
	end
	-- a grid of buckets so "is anything too close" only looks nearby
	local cellSize = r0 * 0.78 / math.sqrt(2)
	local grid: { [number]: { Vector3 } } = {}
	local function key(p: Vector3): (number, number)
		return math.floor((p.X - c.X + HALF) / cellSize), math.floor((p.Z - c.Z + HALF) / cellSize)
	end
	local function tooClose(p: Vector3, r: number): boolean
		local gx, gz = key(p)
		local reach = math.ceil(r / cellSize)
		for x = gx - reach, gx + reach do
			for zz = gz - reach, gz + reach do
				local b = grid[x * 4096 + zz]
				if b then
					for _, q in b do
						local dx, dz = q.X - p.X, q.Z - p.Z
						if dx * dx + dz * dz < r * r then
							return true
						end
					end
				end
			end
		end
		return false
	end
	local points: { Vector3 } = {}
	local active: { Vector3 } = {}
	local function accept(p: Vector3)
		table.insert(points, p)
		table.insert(active, p)
		local gx, gz = key(p)
		local k = gx * 4096 + gz
		grid[k] = grid[k] or {}
		table.insert(grid[k], p)
	end
	local function grow()
		while #active > 0 do
			local i = rng:NextInteger(1, #active)
			local from = active[i]
			local r = radiusAt(from)
			local found = false
			for _ = 1, 24 do
				local a = rng:NextNumber(0, math.pi * 2)
				local d = rng:NextNumber(r, r * 1.9)
				local p = from + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				if not blocked(p) and not tooClose(p, radiusAt(p)) then
					accept(p)
					found = true
					break
				end
			end
			if not found then
				table.remove(active, i)
			end
		end
	end
	-- seed from a coarse sweep so every pocket between paths and props fills up
	local step = r0 * 1.5
	local x = -lo
	while x <= lo do
		local zz = -lo
		while zz <= lo do
			local p = c + Vector3.new(x + rng:NextNumber(-0.3, 0.3) * step, 0, zz + rng:NextNumber(-0.3, 0.3) * step)
			if not blocked(p) and not tooClose(p, radiusAt(p)) then
				accept(p)
				grow()
			end
			zz += step
		end
		x += step
	end
	local list: { PatchSpot } = {}
	for _, p in points do
		local grove = radiusAt(p) < r0
		table.insert(list, {
			cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
			scale = (def.scale or 2) * rng:NextNumber(0.86, 1.12) * (if grove then 1.06 else 1),
		})
	end
	patchCache[z] = list
	return list
end

-- A straight fence from a to b (the wooden fence model) with an invisible wall over it. `out` is sideways to it.
local function fenceLine(parent: Instance, a: Vector3, b: Vector3, out: Vector3)
	local len = (b - a).Magnitude
	if len < 1 then
		return
	end
	PropKit.fenceRow(parent, a, b, out)
	local mid = (a + b) / 2 + Vector3.new(0, FENCE_H / 2, 0)
	PropKit.wall(parent, Vector3.new(len + 0.6, FENCE_H, 1.6), CFrame.lookAt(mid, mid + out)).Name = "FenceWall"
end

-- The fences: every shared edge gets a gate in the middle (closed until both sides are open), and the outside
-- edge of the world is one long fence.
local function fences(world: Instance, info)
	local f = PropKit.folder("Fences", world)
	local gatesFolder = PropKit.folder("Gates", world)
	local w = M.gateWidth
	for _, g in Config.gates() do
		local out = g.along:Cross(Vector3.yAxis)
		fenceLine(f, g.pos - g.along * HALF, g.pos - g.along * (w / 2), out)
		fenceLine(f, g.pos + g.along * (w / 2), g.pos + g.along * HALF, out)
		-- lanterns either side of the opening, on the side you come from
		local back = Config.zoneCentre(g.a) - g.pos
		back = Vector3.new(back.X, 0, back.Z).Unit
		for side = -1, 1, 2 do
			local p = g.pos + g.along * side * (w / 2 + 2.5) + back * 2.5
			Models.place("lantern_post", f, CFrame.lookAt(p, p + back), 0.8, true)
		end
		-- the gate itself: its front looks back toward the side you come from
		local model = Instance.new("Model")
		model.Name = ("Gate%d_%d"):format(g.b, g.a)
		local gateAt = CFrame.lookAt(g.pos, g.pos + back)
		local scale = w / 16
		local need = Config.ZONES[g.b - 1]
		local text = if need then "LOCKED\nMow the " .. need.name else "LOCKED"
		if Models.place("gate", model, gateAt, scale, true) then
			PropKit.facePanel(model, gateAt, Vector3.new(0, 5.3, -2.3), Vector2.new(15.6, 4), text, PropKit.TEXT, scale)
		else
			local logColor = Color3.fromRGB(125, 80, 50)
			for x = -w / 2 + 1.5, w / 2 - 1.5, 3 do
				local hgt = 11 + ((x * 7) % 3)
				local log = PropKit.cylinder(model, 1.5, hgt, gateAt * CFrame.new(x, hgt / 2, 0), PropKit.shade(logColor, 0.95))
				log.Material = Enum.Material.Wood
				log.Name = "GateLog"
			end
			local sign = PropKit.brick(model, Vector3.new(w + 2, 4.2, 0.6), gateAt * CFrame.new(0, 6.5, -2.3), Color3.fromRGB(200, 160, 105), "GateSign", Enum.Material.WoodPlanks)
			PropKit.surfaceText(sign, text, PropKit.TEXT)
		end
		local up = g.pos + Vector3.new(0, FENCE_H / 2, 0)
		PropKit.wall(model, Vector3.new(w + 2, FENCE_H, 2), CFrame.lookAt(up, up + back)).Name = "GateWall"
		model.Parent = gatesFolder
		table.insert(info.gates, { a = g.a, b = g.b, model = model })
	end
	local corners = { Vector3.new(MIN_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MAX_Z), Vector3.new(MIN_X, 0, MAX_Z) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local mid = (a + b) / 2
		fenceLine(f, a, b, (mid - MID).Unit)
	end
end

-- A wooden arch over the gate you walk into area z through, with the area's name on a board hanging from it
-- (readable over the closed gate) and a little roof in the area's colour.
local function areaArch(parent: Instance, z: number)
	local g = Config.gateInto(z)
	if not g then
		return
	end
	local def = Config.ZONES[z]
	local back = flat(Config.zoneCentre(g.a) - g.pos) -- toward the side you come from
	local at = CFrame.lookAt(g.pos, g.pos + back)
	local w = M.gateWidth + 3
	local H = 16
	local wood = Color3.fromRGB(120, 78, 46)
	for _, x in { -w / 2, w / 2 } do
		local post = PropKit.cylinder(parent, 0.9, H, at * CFrame.new(x, H / 2, 0), wood)
		post.Material = Enum.Material.Wood
		post.Name = "ArchPost"
	end
	local beam = PropKit.brick(parent, Vector3.new(w + 3, 1.2, 1.4), at * CFrame.new(0, H - 0.4, 0), PropKit.shade(wood, 1.15), "ArchBeam", Enum.Material.Wood)
	beam.CanCollide = false
	local accent = def.tint or def.grass[1]
	for side = -1, 1, 2 do
		local roof = PropKit.brick(parent, Vector3.new(w / 2 + 2.4, 0.5, 3.2), at * CFrame.new(side * (w / 4 + 0.6), H + 1.1, 0) * CFrame.Angles(0, 0, math.rad(-side * 18)), PropKit.shade(accent, 0.8), "ArchRoof", Enum.Material.WoodPlanks)
		roof.CanCollide = false
	end
	local board = PropKit.brick(parent, Vector3.new(w - 2, 3.4, 0.5), at * CFrame.new(0, H - 3, -0.2), Color3.fromRGB(96, 60, 34), "ArchSign", Enum.Material.WoodPlanks)
	board.CanCollide = false
	for _, x in { -w / 3, w / 3 } do
		local chain = PropKit.brick(parent, Vector3.new(0.2, 1.4, 0.2), at * CFrame.new(x, H - 0.9, -0.2), Color3.fromRGB(70, 70, 76), "Chain", Enum.Material.Metal)
		chain.CanCollide = false
	end
	local label = PropKit.surfaceText(board, def.name, PropKit.TEXT)
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.Position = UDim2.fromScale(0.03, 0.07)
end

-- Every area's fences are lined on the inside with its own trees, so you can tell the woods apart at a glance
-- (Chop A Forest: oak wood, birch grove, pines, cherry, autumn...). Gates are left clear.
local function fenceTrees(parent: Instance, z: number)
	local def = Config.ZONES[z]
	local style = def.style
	local c = Config.zoneCentre(z)
	local rng = Random.new(z * 911)
	local gatesHere = {}
	for _, g in Config.gates() do
		if g.a == z or g.b == z then
			table.insert(gatesHere, g.pos)
		end
	end
	local step = if style == "wheat" then 10 else 15
	local inset = 6.5
	local n = 0
	for _, edge in { { Vector3.xAxis, Vector3.zAxis }, { Vector3.xAxis, -Vector3.zAxis }, { Vector3.zAxis, Vector3.xAxis }, { Vector3.zAxis, -Vector3.xAxis } } do
		local along, out = edge[1], edge[2]
		local t = -HALF + 8
		while t <= HALF - 8 do
			local p = c + along * t + out * (HALF - inset)
			local nearGate = false
			for _, gp in gatesHere do
				if (Vector3.new(gp.X, 0, gp.Z) - p).Magnitude < 16 then
					nearGate = true
				end
			end
			if not nearGate then
				n += 1
				local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				local s = rng:NextNumber(0.85, 1.1)
				if style == "lawn" then
					if not Models.place("oak_small", parent, CFrame.new(p) * spin, 0.62 * s, true) then
						PropKit.forestTree(parent, p, 0.55 * s)
					end
				elseif style == "meadow" then
					if not Models.place("birch", parent, CFrame.new(p) * spin, 0.6 * s, true) then
						PropKit.forestTree(parent, p, 0.6 * s, { birch = true })
					end
				elseif style == "golf" then
					if n % 2 == 0 then
						PropKit.forestTree(parent, p, 0.5 * s, { leaf = Color3.fromRGB(70, 160, 70), bricks = true })
					else
						Models.place("bush", parent, CFrame.new(p) * spin, 1.7 * s, true)
					end
				elseif style == "wheat" then
					if not Models.place("hay_bale", parent, CFrame.new(p) * spin, 1.1, true) then
						PropKit.brick(parent, Vector3.new(4, 3.6, 4), CFrame.new(p + Vector3.new(0, 1.8, 0)) * spin, Color3.fromRGB(235, 190, 70), "HayBale", Enum.Material.Fabric)
					end
				elseif style == "blossom" then
					PropKit.forestTree(parent, p, 0.58 * s, { leaf = if n % 3 == 0 then Color3.fromRGB(255, 205, 225) else Color3.fromRGB(255, 160, 200), bricks = true })
				elseif style == "reeds" then
					PropKit.forestTree(parent, p, 0.6 * s, { leaf = Color3.fromRGB(70, 128, 96), trunk = Color3.fromRGB(80, 64, 50), bricks = true })
				elseif style == "prairie" then
					local leaves = { Color3.fromRGB(235, 120, 40), Color3.fromRGB(215, 60, 45), Color3.fromRGB(240, 180, 50) }
					PropKit.forestTree(parent, p, 0.6 * s, { leaf = leaves[(n % 3) + 1], bricks = true })
				elseif style == "jungle" then
					if n % 2 == 0 then
						PropKit.palm(parent, p, 15 * s)
					elseif not Models.place("jungle_tree", parent, CFrame.new(p) * spin, 0.62 * s, true) then
						PropKit.forestTree(parent, p, 0.7 * s, { leaf = Color3.fromRGB(20, 95, 38) })
					end
				end
				if n % 12 == 0 then
					task.wait()
				end
			end
			t += step
		end
	end
end

-- One area: its arch, fence trees, dirt paths, landmark and props (on the plan's keep-out spots).
local function areaProps(world: Instance, z: number, info)
	local m = PropKit.folder("Zone" .. z, world)
	local def = Config.ZONES[z]
	local pl = plan(z)
	areaArch(m, z)
	fenceTrees(m, z)
	for i, line in pl.paths do
		for j = 1, #line - 1 do
			Ground.path(line[j], line[j + 1], PATH_HALF * 2, Enum.Material.Ground, z * 100 + i * 10 + j)
		end
	end
	for _, k in pl.keepouts do
		local at = CFrame.new(k.pos) * CFrame.Angles(0, math.rad((k.pos.X * 13 + k.pos.Z * 7) % 360), 0)
		if k.kind == "landmark" then
			Landmarks.build(m, def.style, CFrame.lookAt(k.pos, k.pos + (k.face or Vector3.zAxis)))
		elseif k.kind == "sand" then
			Ground.disc(k.pos.X, k.pos.Z, k.r - 1, Enum.Material.Salt)
		elseif k.kind == "hay" or k.kind == "haystack" then
			if not Models.place("hay_bale", m, at, if k.kind == "haystack" then 1.4 else 1) then
				PropKit.brick(m, Vector3.new(4, 3.6, 4), at * CFrame.new(0, 1.8, 0), Color3.fromRGB(235, 190, 70), "HayBale")
			end
		elseif k.kind == "pond" then
			Ground.water(k.pos.X, k.pos.Z, k.r * 1.5, k.r * 1.1, 3)
		elseif k.kind == "bigtree" then
			if not Models.place("jungle_tree", m, at, 1.2, true) then
				PropKit.forestTree(m, k.pos, 1.9, { leaf = Color3.fromRGB(20, 95, 38) })
			end
		elseif k.kind == "palm" then
			PropKit.palm(m, k.pos, 18)
		elseif k.kind == "blossomtree" then
			PropKit.forestTree(m, k.pos, 0.75, { leaf = Color3.fromRGB(255, 170, 210), bricks = true })
		elseif k.kind == "autumntree" then
			PropKit.forestTree(m, k.pos, 0.8, { leaf = if (k.pos.X + k.pos.Z) % 2 < 1 then Color3.fromRGB(235, 120, 40) else Color3.fromRGB(215, 60, 45), bricks = true })
		elseif k.kind == "birch" then
			PropKit.forestTree(m, k.pos, 0.75, { birch = true })
		elseif k.kind == "rock" then
			Models.place("rock", m, at, 1.4)
		elseif k.kind == "bush" then
			Models.place("bush", m, at, 1.2, true)
		elseif k.kind == "stump" then
			if not Models.place("stump", m, at, 1, true) then
				PropKit.stump(m, k.pos, 0.6)
			end
		elseif k.kind == "log" then
			Models.place("log", m, at, 1.2, true)
		elseif k.kind == "flowers" then
			PropKit.flowers(m, k.pos)
		elseif k.kind == "mushroom" then
			PropKit.mushroom(m, k.pos, 1.3)
			PropKit.mushroom(m, k.pos + Vector3.new(1.2, 0, 0.6), 0.8)
		elseif k.kind == "fallenlog" then
			PropKit.fallenLog(m, k.pos, 7, math.rad((k.pos.X * 31) % 180))
		elseif k.kind == "clearing" then
			-- a little sunny clearing: a fallen trunk to sit on, flowers and mushrooms round it
			PropKit.fallenLog(m, k.pos + Vector3.new(0, 0, 1.5), 7, math.rad((k.pos.Z * 17) % 180))
			PropKit.flowers(m, k.pos + Vector3.new(-3, 0, -2))
			PropKit.flowers(m, k.pos + Vector3.new(3.5, 0, -1))
			PropKit.mushroom(m, k.pos + Vector3.new(-1, 0, -4), 1)
		elseif k.kind == "dropoff" then
			-- Chop A Forest's far-off shredder: sell here instead of walking all the way back to the hub
			Ground.disc(k.pos.X, k.pos.Z, k.r - 2, Enum.Material.Ground)
			local machine = k.pos - Vector3.xAxis * 8
			if shredderAt(m, info, CFrame.lookAt(machine, machine - Vector3.xAxis), "DropOff") then
				local holder = promptSpot(m, CFrame.new(machine + Vector3.new(0, 1, 0)), "DropOffLabel")
				PropKit.billboard(holder, "DROP-OFF", PropKit.TEXT, Vector2.new(10, 2.4), Vector3.new(0, 15, 0), 220)
			end
			gasPump(m, k.pos + Vector3.new(4, 0, 15), info, Vector3.zAxis)
		end
	end
	if Config.BOSSES then
		local arena = Config.zoneCentre(z)
		Ground.disc(arena.X, arena.Z, 12, Enum.Material.Ground)
	end
end

-- The hub's yard: dirt paths from the spawn to its three gates, a few trees and hay in the corners.
local function hubYard(world: Instance)
	local m = PropKit.folder("HubYard", world)
	Ground.path(Vector3.new(0, 0, -64), HUB + Vector3.new(0, 0, HALF + 3), 12, Enum.Material.Ground, 4)
	for _, side in { -1, 1 } do
		Ground.path(HUB + Vector3.new(side * 40, 0, -2), HUB + Vector3.new(side * (HALF + 3), 0, 0), 11, Enum.Material.Ground, 5 + side)
	end
	local rng = Random.new(5)
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		for i = 1, 3 do
			local p = HUB + Vector3.new(corner.X * (HALF - 14 - i * 9), 0, corner.Z * (HALF - 12 - rng:NextNumber(0, 16)))
			PropKit.forestTree(m, p, rng:NextNumber(0.8, 1.05), { birch = i == 2 })
		end
		Models.place("hay_bale", m, CFrame.new(HUB + Vector3.new(corner.X * (HALF - 40), 0, corner.Z * (HALF - 22))), 1, true)
	end
end

-- How far a point is outside the play fence (0 inside).
local function outside(x: number, z: number): number
	local dx = math.max(MIN_X - x, 0, x - MAX_X)
	local dz = math.max(MIN_Z - z, 0, z - MAX_Z)
	return math.sqrt(dx * dx + dz * dz)
end

-- Gentle hills rolling away outside the fence (the forest grows over them).
local function hills()
	local rng = Random.new(41)
	for i = 0, 25 do
		local side = i % 4
		local t = rng:NextNumber(-0.5, 0.5)
		local r = rng:NextNumber(28, 55)
		local d = r + rng:NextNumber(8, 70)
		local x, zz
		if side == 0 then
			x, zz = MID.X + t * (MAX_X - MIN_X), MAX_Z + d
		elseif side == 1 then
			x, zz = MID.X + t * (MAX_X - MIN_X), MIN_Z - d
		elseif side == 2 then
			x, zz = MAX_X + d, MID.Z + t * (MAX_Z - MIN_Z)
		else
			x, zz = MIN_X - d, MID.Z + t * (MAX_Z - MIN_Z)
		end
		Ground.hill(x, zz, r, rng:NextNumber(8, 22), Enum.Material.Grass)
	end
end

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include
local function groundY(x: number, z: number): number
	groundRay.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -260, 0), groundRay)
	return if hit then hit.Position.Y - 0.3 else 0
end

-- The forest all round the outside fence, a real wall of trees: a mixed edge (oaks, birches, pines) and deep
-- rows of tall blocky pines behind it, standing on the hills; then the snowy mountains.
local function horizon(world: Instance)
	local f = PropKit.folder("Forest", world)
	local rng = Random.new(77)
	local n = 0
	-- the mixed edge, right outside the fence
	local step = 12
	for x = MIN_X - 46, MAX_X + 46, step do
		for z = MIN_Z - 46, MAX_Z + 46, step do
			local px, pz = x + rng:NextNumber(-4, 4), z + rng:NextNumber(-4, 4)
			local d = outside(px, pz)
			if d > 7 and d <= 44 then
				local pos = Vector3.new(px, groundY(px, pz), pz)
				local pick = rng:NextNumber()
				local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
				if pick < 0.38 then
					PropKit.pine(f, pos, rng:NextNumber(22, 34), false)
				else
					local name = if pick < 0.5 then "birch" elseif pick < 0.7 then "oak_small" else "oak"
					if not Models.place(name, f, cf, rng:NextNumber(0.95, 1.35), true) then
						PropKit.forestTree(f, pos, rng:NextNumber(1, 1.3), { lite = true, birch = name == "birch" })
					end
				end
				n += 1
				if n % 50 == 0 then
					task.wait()
				end
			end
		end
	end
	-- the deep pine wall
	step = 17
	for x = MIN_X - 135, MAX_X + 135, step do
		for z = MIN_Z - 135, MAX_Z + 135, step do
			local px, pz = x + rng:NextNumber(-5, 5), z + rng:NextNumber(-5, 5)
			local d = outside(px, pz)
			if d > 44 and d <= 135 then
				PropKit.pine(f, Vector3.new(px, groundY(px, pz), pz), rng:NextNumber(28, 46), d > 70)
				n += 1
				if n % 50 == 0 then
					task.wait()
				end
			end
		end
	end
	local reach = math.max(MAX_X - MIN_X, MAX_Z - MIN_Z) / 2
	-- far-off peaks peeking over the pine wall (smaller and further than before, so they read as a horizon)
	for i = 0, 23 do
		local a = (i + rng:NextNumber(-0.2, 0.2)) / 24 * 2 * math.pi
		local r = reach + rng:NextNumber(330, 420)
		PropKit.mountain(world, MID + Vector3.new(math.sin(a) * r, -6, math.cos(a) * r), rng:NextNumber(2.2, 3.1))
	end
end

function RunBuilder.build()
	local world = Environment.apply()
	local info = { world = world, gates = {}, pumps = {}, sellPads = {}, meshGround = false }

	-- the ground: grass everywhere, each area's own coloured field inside a grassy verge, hills outside
	Ground.fill(MID.X, MID.Z, (MAX_X - MIN_X) + 300, (MAX_Z - MIN_Z) + 300, Enum.Material.Grass)
	for z, def in Config.ZONES do
		local mat = AREA_GROUND[def.style] or Enum.Material.Grass
		if mat ~= Enum.Material.Grass then
			local c = Config.zoneCentre(z)
			Ground.fill(c.X, c.Z, M.cell - 10, M.cell - 10, mat)
		end
	end
	hills()

	hub(world, info)
	hubYard(world)
	fences(world, info)
	for z = 1, #Config.ZONES do
		areaProps(world, z, info)
		task.wait()
	end
	-- the surface exactly at y = 0 where everything stands (hills are left as they are)
	Ground.flatten(MID.X, MID.Z, math.max(MAX_X - MIN_X, MAX_Z - MIN_Z) / 2 + 150)
	horizon(world)
	return info
end

-- Area z's middle (the boss arena when bosses are on, see Config.BOSSES). Kept 90 studs from the camp when the
-- camp is in that area (server/RunWorld.moveVillageToCamp).
function RunBuilder.zoneCentre(z: number): Vector3
	local c = Config.zoneCentre(z)
	local w = workspace:FindFirstChild("World")
	local camp = w and w:GetAttribute("CampCenter")
	if typeof(camp) == "Vector3" and Vector2.new(c.X - camp.X, c.Z - camp.Z).Magnitude < 90 then
		local away = Vector3.new(c.X - camp.X, 0, c.Z - camp.Z)
		away = if away.Magnitude > 1 then away.Unit else ((w :: Instance):GetAttribute("CampFacing") or Vector3.zAxis) :: Vector3
		local spot = camp + away * 90
		local ground = w and w:FindFirstChild("Ground")
		if ground then
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { ground }
			local hit = workspace:Raycast(Vector3.new(spot.X, 300, spot.Z), Vector3.new(0, -600, 0), rp)
			if hit then
				return hit.Position
			end
		end
		return Vector3.new(spot.X, c.Y, spot.Z)
	end
	return c
end

return RunBuilder
]======]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "57175 1066027528" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.ServerScriptService.MowALawn
local old = folder:FindFirstChild("RunBuilder")
if old then
	local now = hashOf(old.Source)
	if now == "57175 1066027528" then
		return "RunBuilder is already this version: " .. now
	end
	local known = { ["56808 461202846"] = true }
	if not known[now] then
		return "NOT CHANGED: RunBuilder is there but is " .. now .. " (not a version this replaces)"
	end
	old.Source = src
	return "RunBuilder updated: " .. hashOf(old.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "RunBuilder"
m.Source = src
m.Parent = folder
return "RunBuilder installed: " .. hashOf(m.Source)
