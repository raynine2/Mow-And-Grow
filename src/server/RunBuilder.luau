-- Builds a run's map: the hub (shredder, tool shop, upgrades, garage, gas pump) and the 5 zones along one road.
-- Grass patches are spawned by Field; this file only builds the static world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local Environment = require(script.Parent.Environment)
local Ground = require(script.Parent.Ground)
local GroundMesh = require(script.Parent.GroundMesh)

local RunBuilder = {}

local HALF_WIDTH = 50 -- the map is 100 studs wide
local HUB_START = -80
local FLOOR_Y = 0 -- top of the ground (Terrain)

local function fieldLength(): number
	return Config.GRID.rows * Config.GRID.tile
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
	PropKit.facePanel(parent, cf, Vector3.new(0, 0.82, -0.57), Vector2.new(5.4, 1.5), "$" .. Format.commas(tool.cost), Color3.fromRGB(120, 255, 90), s)
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

local function toolShop(m: Instance, info)
	local shop = PropKit.folder("TOOL SHOP", m)
	local pos = Vector3.new(24, FLOOR_Y, -40)
	local at = CFrame.lookAt(pos, pos - Vector3.xAxis)
	if not PropKit.cabin(shop, at, 1) then
		PropKit.stall(m, CFrame.new(28, 0, -55) * CFrame.Angles(0, math.rad(90), 0), "TOOL SHOP", Color3.fromRGB(255, 80, 80), "Tools")
		return
	end
	PropKit.cabinSign(shop, at, 1, "TOOL SHOP", Color3.fromRGB(255, 120, 70))
	for i = 2, #Config.TOOLS do
		local spot = FRAME_SPOTS[i - 1]
		if spot then
			toolFrame(shop, at, Config.TOOLS[i], spot)
		end
	end
	-- the Guide arrow points just outside the door ("Counter" looks out of the door)
	promptSpot(shop, at * CFrame.new(0, 2, -6), "Counter")
	-- a lantern at the door
	Models.place("lantern_post", shop, at * CFrame.new(5, 0.5, -10.6), 0.8, true)
end

-- The Bag Stand (bag_stand model): a striped market stall by the spawn. The three bag tiers stand on its stumps,
-- the Bottomless Sack sits on the counter and the Leaf Vacuum leans beside it. Its prompt opens the Bags window.
local function bagStand(m: Instance)
	local stand = PropKit.folder("BAG STAND", m)
	local pos = Vector3.new(28, FLOOR_Y, -68)
	local at = CFrame.lookAt(pos, pos - Vector3.xAxis) -- facing the path from the spawn
	if not Models.place("bag_stand", stand, at, 1, true) then
		PropKit.stall(stand, at, "BAGS", Color3.fromRGB(90, 190, 90), "Bags")
		return
	end
	PropKit.facePanel(stand, at, Vector3.new(0, 10.6, 0.9), Vector2.new(9.4, 2.2), "BAGS & GEAR", Color3.fromRGB(255, 240, 200))
	PropKit.collider(stand, at, Vector3.new(0, 3.7, 0.7), Vector3.new(14, 7.4, 3))
	-- the bags on their stumps (model studs: stump tops at y 2, z -4.5), each with its price in front
	for i, bag in Config.BAGS do
		local x = ({ -5, 0, 5 })[i]
		if x then
			PropKit.collider(stand, at, Vector3.new(x, 1, -4.5), Vector3.new(2.7, 2, 2.7))
			Models.place(bag.model, stand, at * CFrame.new(x, 2, -4.5), 1.1, true)
			PropKit.facePanel(stand, at, Vector3.new(x, 1, -5.85), Vector2.new(2.6, 0.9), "$" .. Format.short(bag.cost), Color3.fromRGB(120, 255, 90))
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
	PropKit.billboard(body, "GAS", Color3.fromRGB(255, 230, 80), Vector2.new(5, 2), Vector3.new(0, 5, 0), 120)
	local prompt = PropKit.prompt(body, "Refuel", "Gas Pump", nil, 14)
	prompt:SetAttribute("Pump", true)
	table.insert(info.pumps, { pos = pos, prompt = prompt })
end

-- The garage: an open wooden bay (party booth model) where your mower spawns, with a gas pump beside it.
local function garageBay(m: Instance, info)
	local pos = Vector3.new(-30, FLOOR_Y, -64)
	local at = CFrame.lookAt(pos, pos + Vector3.xAxis)
	local g = PropKit.folder("Garage", m)
	if Models.place("party_booth", g, at, 1.1, true) then
		PropKit.facePanel(g, at, Vector3.new(0, 7, 5.93), Vector2.new(10.4, 4), "GARAGE", Color3.fromRGB(255, 150, 50), 1.1)
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
	gasPump(g, (at * CFrame.new(10, 0, -6)).Position, info, Vector3.xAxis)
end

-------------------------------------------------------------------------------------------------------------
-- hub
-------------------------------------------------------------------------------------------------------------
-- The Giant Grass Shredder (Blender model) with its log-framed sell pad in front of the hopper.
local function shredder(m: Instance, info): boolean
	local s = PropKit.folder("Shredder", m)
	local pos = Vector3.new(-24, FLOOR_Y, -36)
	local at = CFrame.lookAt(pos, pos - Vector3.xAxis) -- drum toward the spawn, hopper toward the yard
	if not Models.place("shredder", s, at, 1.15, true) then
		return false
	end
	PropKit.collider(s, at, Vector3.new(0, 5, -0.7), Vector3.new(7.8, 10, 14.5), 1.15)
	info.shredderMouth = (at * CFrame.new(Vector3.new(0.3, 8.8, 4.8) * 1.15)).Position
	info.shredderOut = (at * CFrame.new(Vector3.new(0, 1.2, -8.6) * 1.15)).Position
	local padAt = at * CFrame.new(0, 0, 16.5)
	local sellPos = padAt.Position
	if Models.place("sell_pad", s, padAt, 1, true) then
		PropKit.collider(s, padAt, Vector3.new(0, 0.41, 0), Vector3.new(13, 0.82, 13))
	else
		PropKit.pad(s, sellPos, 6, Color3.fromRGB(80, 220, 80))
	end
	local holder = promptSpot(s, CFrame.new(sellPos + Vector3.new(0, 1, 0)), "SellLabel")
	PropKit.billboard(holder, "DROP BUNDLES", Color3.fromRGB(255, 230, 80), Vector2.new(12, 2.6), Vector3.new(0, 5, 0), 120)
	info.sellPos = sellPos
	info.sellRadius = 7
	-- the 2X COINS board next to the machine (opens the store)
	local signAt = CFrame.lookAt(Vector3.new(-38, FLOOR_Y, -50), Vector3.new(-6, FLOOR_Y, -68))
	if Models.place("start_sign", s, signAt, 0.45, true) then
		PropKit.facePanel(s, signAt, Vector3.new(0, 9.3, -0.62), Vector2.new(27, 4), "2X COINS", Color3.fromRGB(255, 214, 60), 0.45)
		PropKit.facePanel(s, signAt, Vector3.new(0, 6.1, -0.62), Vector2.new(27, 1.5), "BUY!", Color3.fromRGB(120, 255, 90), 0.45)
		PropKit.prompt(promptSpot(s, signAt * CFrame.new(0, 3, -1.5), "CoinsSign"), "Open", "2x Coins", "Store", 10)
	end
	return true
end

local function hub(world: Instance, info)
	local m = PropKit.folder("Hub", world)
	-- ground: grass with a dirt yard around the cabin and the machines, and a worn path out to the first field
	-- (Terrain version; the Blender ground_hub model has the same layout)
	if not info.meshGround then
		Ground.fill(0, HUB_START + 50, 100, 100, Enum.Material.Grass)
		Ground.patch(0, -48, 92, 56, Enum.Material.Ground, 3)
		Ground.path(Vector3.new(0, 0, -30), Vector3.new(0, 0, 26), 10, Enum.Material.Ground, 4)
		Ground.patch(-8, -36, 16, 16, Enum.Material.Mud, 6) -- trodden mud at the sell pad
	end
	Environment.spawn(m, CFrame.lookAt(Vector3.new(0, 0.8, -68), Vector3.new(0, 0.8, 0)))
	toolShop(m, info)
	bagStand(m)
	-- fences along the hub's sides
	PropKit.fenceRow(m, Vector3.new(-48, 0, -78), Vector3.new(-48, 0, 14), Vector3.xAxis)
	PropKit.fenceRow(m, Vector3.new(48, 0, -78), Vector3.new(48, 0, 14), -Vector3.xAxis)
	garageBay(m, info)
	if shredder(m, info) then
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
	local sign = PropKit.sign(s, base * CFrame.new(0, 6, -5.2), Vector3.new(12, 3, 0.6), "SHREDDER", Color3.fromRGB(80, 200, 80))
	sign.Name = "ShredderSign"
	local sellPos = (base * CFrame.new(0, 0, -13)).Position
	PropKit.pad(s, sellPos, 6, Color3.fromRGB(80, 220, 80), "SELL BUNDLES")
	info.sellPos = sellPos
	info.sellRadius = 7
	info.shredderMouth = mouth.Position
	info.shredderOut = (base * CFrame.new(0, 1, -9)).Position
	body:SetAttribute("Shredder", true)
end

local ZONE_TREES = {
	Color3.fromRGB(46, 112, 36),
	Color3.fromRGB(52, 120, 40),
	Color3.fromRGB(200, 120, 35),
	Color3.fromRGB(45, 100, 75),
	Color3.fromRGB(28, 92, 34),
}


local function zone(world: Instance, z: number, info)
	local def = Config.ZONES[z]
	local m = PropKit.folder("Zone" .. z, world)
	local zs = Config.zoneStartZ(z)
	local groundLen = Config.ZONE_SPACING
	-- the zone's ground (Terrain, from just before its gate to the next one): a lush meadow, golden-soil wheat
	-- field, muddy swamp or leafy jungle floor under the clumps
	-- (Terrain version; the Blender ground_<style> model has the same layout, plus its hills, sand and water)
	if not info.meshGround then
		local terrainMat = ({ lawn = Enum.Material.Grass, golf = Enum.Material.Grass, wheat = Enum.Material.Ground, reeds = Enum.Material.Mud, jungle = Enum.Material.LeafyGrass })[def.style] or Enum.Material.Grass
		Ground.fill(0, zs - 10 + groundLen / 2, HALF_WIDTH * 2 + 220, groundLen, Enum.Material.Grass)
		if terrainMat ~= Enum.Material.Grass then
			Ground.patch(0, zs + Config.GRID.rows * Config.GRID.tile / 2, HALF_WIDTH * 2 - 4, Config.GRID.rows * Config.GRID.tile + 10, terrainMat, z)
		end
	end

	-- zone sign (a plank board on two posts, turned toward the road)
	local signAt = CFrame.new(-36, 0, zs - 6) * CFrame.Angles(0, math.rad(-150), 0)
	if Models.place("start_sign", m, signAt, 0.55, true) then
		PropKit.facePanel(m, signAt, Vector3.new(0, 9.0, -0.62), Vector2.new(27, 4.6), def.name, Color3.fromRGB(255, 240, 200), 0.55)
	else
		PropKit.sign(m, CFrame.new(-38, 7, zs - 6) * CFrame.Angles(0, math.rad(-150), 0), Vector3.new(16, 4, 1), def.name, def.grass[1], Color3.new(1, 1, 1))
	end

	-- gate (zones 2+): closed until the previous boss falls
	if z > 1 then
		local gate = Instance.new("Model")
		gate.Name = "Gate" .. z
		local gz = zs - 16
		local gateAt = CFrame.lookAt(Vector3.new(0, 0, gz), Vector3.new(0, 0, gz - 1))
		if Models.place("gate", gate, gateAt, 1, true) then
			PropKit.facePanel(gate, gateAt, Vector3.new(0, 5.3, -2.3), Vector2.new(15.6, 4), "LOCKED\nBeat the " .. Config.ZONES[z - 1].boss.name, Color3.fromRGB(255, 235, 120))
			PropKit.wall(gate, Vector3.new(HALF_WIDTH * 2, 30, 2), CFrame.new(0, 15, gz)).Name = "GateWall"
			gate.Parent = m
			info.gates[z] = gate
		end
	end
	if z > 1 and not info.gates[z] then
		local gate = Instance.new("Model")
		gate.Name = "Gate" .. z
		local gz = zs - 16
		-- log palisade: a row of upright logs with pointed tops, two cross beams and a hanging sign
		local logColor = Color3.fromRGB(125, 80, 50)
		for x = -HALF_WIDTH + 1.5, HALF_WIDTH - 1.5, 3 do
			local hgt = 11 + ((x * 7) % 3)
			local log = PropKit.cylinder(gate, 1.5, hgt, CFrame.new(x, hgt / 2, gz), PropKit.shade(logColor, 0.9 + ((x * 3) % 4) * 0.04))
			log.Material = Enum.Material.Wood
			log.Name = "GateLog"
			local tip = PropKit.brick(gate, Vector3.new(2.1, 2.1, 2.1), CFrame.new(x, hgt + 0.2, gz) * CFrame.Angles(math.rad(45), 0, math.rad(45)), PropKit.shade(logColor, 0.85), "GateTip", Enum.Material.Wood)
			tip.CanCollide = false
		end
		for _, y in { 3.5, 8.5 } do
			PropKit.brick(gate, Vector3.new(HALF_WIDTH * 2, 1.2, 1), CFrame.new(0, y, gz - 1.6), PropKit.shade(logColor, 0.75), "GateBeam", Enum.Material.WoodPlanks)
		end
		local sign = PropKit.brick(gate, Vector3.new(22, 4.2, 0.6), CFrame.new(0, 6.5, gz - 2.3), Color3.fromRGB(200, 160, 105), "GateSign", Enum.Material.WoodPlanks)
		PropKit.surfaceText(sign, "LOCKED: beat the " .. Config.ZONES[z - 1].boss.name, Color3.fromRGB(255, 235, 120))
		PropKit.wall(gate, Vector3.new(HALF_WIDTH * 2, 30, 2), CFrame.new(0, 15, gz)).Name = "GateWall"
		gate.Parent = m
		info.gates[z] = gate
	end

	-- dense forest on both sides of the field (the field is a clearing, like the trailer)
	local fieldHalf = Config.GRID.cols * Config.GRID.tile / 2
	local scale = 0.95 + z * 0.08
	local leaf = ZONE_TREES[z]
	PropKit.forest(m, fieldHalf + 10, 130, zs - 6, zs + Config.ZONE_SPACING - 14, { seed = z * 101, leaf = leaf, scale = scale, detailDist = 62 })
	PropKit.forest(m, -130, -(fieldHalf + 10), zs - 6, zs + Config.ZONE_SPACING - 14, { seed = z * 211, leaf = leaf, scale = scale, detailDist = 62 })
	-- rolling hills beyond the side forests
	if not info.meshGround then
		local hillRng = Random.new(z * 17)
		for side = -1, 1, 2 do
			Ground.hill(side * hillRng:NextNumber(175, 210), zs + hillRng:NextNumber(10, 100), hillRng:NextNumber(50, 75), hillRng:NextNumber(14, 26))
		end
	end

	-- small theme props
	if z == 2 then
		-- the flag on the putting green (the green and the sand trap are part of ground_golf)
		local flagAt = if info.meshGround then CFrame.new(34, 0, zs + 28) else CFrame.new(46, 0, zs + 30)
		if not Models.place("golf_flag", m, flagAt * CFrame.Angles(0, math.rad(-120), 0), 1, true) then
			local flag = PropKit.brick(m, Vector3.new(0.5, 9, 0.5), flagAt * CFrame.new(0, 4.5, 0), Color3.fromRGB(255, 255, 255), "FlagPole")
			PropKit.brick(m, Vector3.new(0.2, 2.4, 3.4), flagAt * CFrame.new(0, 7.8, 1.7), Color3.fromRGB(255, 70, 70), "Flag")
			flag.Name = "FlagPole"
		end
		if not info.meshGround then
			Ground.patch(46.5, zs + 55, 6, 16, Enum.Material.Sand, 9) -- a sand trap
		end
	elseif z == 3 then
		for i = 0, 3 do
			local at = CFrame.new(-46.5, 0, zs + 10 + i * 22) * CFrame.Angles(0, math.rad(i * 23), 0)
			if not Models.place("hay_bale", m, at, 1) then
				PropKit.brick(m, Vector3.new(4, 3.6, 4), at * CFrame.new(0, 1.8, 0), Color3.fromRGB(235, 190, 70), "HayBale")
			end
		end
	elseif z == 4 then
		if not info.meshGround then
			for side = -1, 1, 2 do
				Ground.water(side * 46.5, zs + 48, 6, 72, 3) -- real water channels along the swamp's edges
			end
		end
	elseif z == 5 then
		for i, x in { -47, 47 } do
			local at = CFrame.new(x, 0, zs + 40) * CFrame.Angles(0, math.rad(i * 70), 0)
			if not Models.place("jungle_tree", m, at, 1, true) then
				PropKit.forestTree(m, Vector3.new(x, 0, zs + 40), 1.9, { leaf = Color3.fromRGB(20, 95, 38) })
			end
		end
	end

	gasPump(m, Vector3.new(36, 0, zs - 8), info)
end

function RunBuilder.build()
	local world = Environment.apply()
	local info = { world = world, gates = {}, pumps = {}, meshGround = GroundMesh.run(world, HUB_START, HALF_WIDTH) }
	hub(world, info)
	for z = 1, #Config.ZONES do
		zone(world, z, info)
	end
	-- walls: sides and the far end
	local lastZ = Config.zoneStartZ(#Config.ZONES) + Config.ZONE_SPACING
	local length = lastZ - HUB_START
	for side = -1, 1, 2 do
		PropKit.wall(world, Vector3.new(2, 60, length), CFrame.new(side * HALF_WIDTH, 30, HUB_START + length / 2))
	end
	PropKit.wall(world, Vector3.new(HALF_WIDTH * 2, 60, 2), CFrame.new(0, 30, HUB_START))
	PropKit.wall(world, Vector3.new(HALF_WIDTH * 2, 60, 2), CFrame.new(0, 30, lastZ - 20))
	-- mountains on the horizon and a forest wall behind the hub
	local rng = Random.new(5)
	for i = 0, 9 do
		local side = if i % 2 == 0 then -1 else 1
		PropKit.mountain(world, Vector3.new(side * rng:NextNumber(220, 300), -2, HUB_START + i * 70), rng:NextNumber(1.6, 2.6))
	end
	PropKit.mountain(world, Vector3.new(0, -2, lastZ + 200), 3)
	-- forest around the hub too
	PropKit.forest(world, -130, 130, HUB_START - 70, HUB_START - 10, { seed = 7, detailDist = 70 })
	PropKit.forest(world, 52, 130, HUB_START, 18, { seed = 8, detailDist = 62 })
	PropKit.forest(world, -130, -52, HUB_START, 18, { seed = 9, detailDist = 62 })
	-- grass all around the hub too, with hills behind it (ground_hub has these)
	if not info.meshGround then
		Ground.fill(0, HUB_START - 40, 320, 130, Enum.Material.Grass)
		Ground.fill(-110, HUB_START + 50, 120, 100, Enum.Material.Grass)
		Ground.fill(110, HUB_START + 50, 120, 100, Enum.Material.Grass)
		for i = -2, 2 do
			Ground.hill(i * 70, HUB_START - 150, 70, 20 + (i % 2) * 8)
		end
	end
	return info
end

-- Centre of patch (col, row) of a zone, at ground level.
-- Each patch sits in its own cell, nudged by a fixed per-patch amount (the same patch always lands on the same
-- spot, so saved runs and hit tests agree).
local patchCache: { [number]: Vector3 } = {}
function RunBuilder.patchPosition(z: number, col: number, row: number): Vector3
	local key = (z * 1000 + row) * 1000 + col
	local cached = patchCache[key]
	if cached then
		return cached
	end
	local t = Config.GRID.tile
	local j = (Config.GRID.jitter or 0) * t
	local rng = Random.new(z * 100003 + row * 1009 + col * 31)
	-- every other row shifted by a quarter cell, so the rows don't line up
	local stagger = if row % 2 == 0 then t * 0.25 else -t * 0.25
	local x = -Config.GRID.cols * t / 2 + (col - 0.5) * t + stagger + rng:NextNumber(-j, j)
	local zz = Config.zoneStartZ(z) + (row - 0.5) * t + rng:NextNumber(-j, j)
	local pos = Vector3.new(x, 0, zz)
	patchCache[key] = pos
	return pos
end

function RunBuilder.zoneCentre(z: number): Vector3
	return Vector3.new(0, 0, Config.zoneStartZ(z) + fieldLength() / 2)
end

return RunBuilder
