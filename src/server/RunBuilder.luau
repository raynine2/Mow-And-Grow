-- Builds a run's map: the hub (shredder, tool shop, upgrades, garage, gas pump) and the 5 zones along one road.
-- Grass patches are spawned by Field; this file only builds the static world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)
local Environment = require(script.Parent.Environment)

local RunBuilder = {}

local HALF_WIDTH = 50 -- the map is 100 studs wide
local HUB_START = -80

local function fieldLength(): number
	return Config.GRID.rows * Config.GRID.tile
end

local function hub(world: Instance, info)
	local m = PropKit.folder("Hub", world)
	-- ground: studded orange bricks like the lobby
	for x = -2, 1 do
		for z = 0, 3 do
			local c = if (x + z) % 2 == 0 then Color3.fromRGB(255, 165, 80) else Color3.fromRGB(235, 130, 60)
			PropKit.brick(m, Vector3.new(25, 2, 25), CFrame.new(x * 25 + 12.5, -1, HUB_START + z * 25 + 12.5), c, "HubGround")
		end
	end
	Environment.spawn(m, CFrame.new(0, 0.5, -68))

	-- Giant Grass Shredder
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

	-- shops
	PropKit.stall(m, CFrame.new(28, 0, -55) * CFrame.Angles(0, math.rad(90), 0), "TOOL SHOP", Color3.fromRGB(255, 80, 80), "Tools")
	PropKit.stall(m, CFrame.new(28, 0, -30) * CFrame.Angles(0, math.rad(90), 0), "UPGRADES", Color3.fromRGB(60, 165, 255), "Upgrades")
	PropKit.stall(m, CFrame.new(-28, 0, -70) * CFrame.Angles(0, math.rad(-90), 0), "GARAGE", Color3.fromRGB(160, 95, 255), "Mowers")
	PropKit.stall(m, CFrame.new(0, 0, -78) * CFrame.Angles(0, math.rad(180), 0), "STORE", Color3.fromRGB(255, 110, 190), "Store")
	info.garageSpawn = CFrame.new(-12, 2, -70) * CFrame.Angles(0, math.rad(0), 0)
	PropKit.pad(m, Vector3.new(-12, 0, -70), 5, Color3.fromRGB(160, 95, 255), "MOWER SPAWN")
end

-- Gas pump: prompt refuels your mower if it's parked nearby.
local function gasPump(parent: Instance, pos: Vector3, info)
	local cf = CFrame.new(pos)
	local red = Color3.fromRGB(240, 60, 60)
	local body = PropKit.brick(parent, Vector3.new(3, 6, 2.4), cf * CFrame.new(0, 3, 0), red, "GasPump")
	PropKit.brick(parent, Vector3.new(3.4, 1, 2.8), cf * CFrame.new(0, 6.5, 0), Color3.fromRGB(255, 255, 255), "PumpTop")
	PropKit.brick(parent, Vector3.new(2, 1.4, 0.4), cf * CFrame.new(0, 4.6, -1.3), Color3.fromRGB(40, 40, 50), "PumpScreen")
	PropKit.brick(parent, Vector3.new(0.5, 2.4, 0.5), cf * CFrame.new(1.8, 3, 0), Color3.fromRGB(30, 30, 35), "Hose")
	PropKit.billboard(body, "GAS", Color3.fromRGB(255, 230, 80), Vector2.new(5, 2), Vector3.new(0, 5, 0), 120)
	local prompt = PropKit.prompt(body, "Refuel", "Gas Pump", nil, 14)
	prompt:SetAttribute("Pump", true)
	table.insert(info.pumps, { pos = pos, prompt = prompt })
end

local ZONE_TREES = {
	Color3.fromRGB(80, 190, 70),
	Color3.fromRGB(60, 170, 80),
	Color3.fromRGB(255, 170, 40),
	Color3.fromRGB(60, 140, 120),
	Color3.fromRGB(30, 120, 50),
}

local function zone(world: Instance, z: number, info)
	local def = Config.ZONES[z]
	local m = PropKit.folder("Zone" .. z, world)
	local zs = Config.zoneStartZ(z)
	local len = fieldLength()
	local groundLen = Config.ZONE_SPACING
	-- ground runs from just before the gate to the next zone's gate
	PropKit.brick(m, Vector3.new(HALF_WIDTH * 2, 2, groundLen), CFrame.new(0, -1, zs - 10 + groundLen / 2), def.ground, "ZoneGround")
	-- dark soil bed under the grass
	PropKit.brick(m, Vector3.new(Config.GRID.cols * Config.GRID.tile + 2, 0.4, len + 2), CFrame.new(0, 0.1, zs + len / 2), PropKit.shade(def.ground, 0.75), "Soil")

	-- zone sign
	PropKit.sign(m, CFrame.new(-38, 7, zs - 6) * CFrame.Angles(0, math.rad(-150), 0), Vector3.new(16, 4, 1), def.name, def.grass[1], Color3.new(1, 1, 1))

	-- gate (zones 2+): closed until the previous boss falls
	if z > 1 then
		local gate = Instance.new("Model")
		gate.Name = "Gate" .. z
		local gz = zs - 16
		local wall = PropKit.brick(gate, Vector3.new(HALF_WIDTH * 2, 14, 2), CFrame.new(0, 7, gz), Color3.fromRGB(120, 85, 50), "GateWall")
		for x = -45, 45, 10 do
			PropKit.brick(gate, Vector3.new(2, 16, 3), CFrame.new(x, 8, gz), Color3.fromRGB(95, 65, 40), "GatePost")
		end
		PropKit.surfaceText(wall, "LOCKED: beat the " .. Config.ZONES[z - 1].boss.name, Color3.fromRGB(255, 230, 80))
		gate.Parent = m
		info.gates[z] = gate
	end

	-- trees along both sides
	local rng = Random.new(z * 31)
	for side = -1, 1, 2 do
		for i = 0, 6 do
			local pz = zs - 10 + i * 16 + rng:NextNumber(-3, 3)
			local px = side * (HALF_WIDTH - 6 + rng:NextNumber(-2, 2))
			local scale = (1.2 + z * 0.25) * rng:NextNumber(0.85, 1.15)
			PropKit.coneTree(m, Vector3.new(px, 0, pz), scale, ZONE_TREES[z])
		end
	end

	-- small theme props
	if z == 2 then
		local flag = PropKit.brick(m, Vector3.new(0.5, 9, 0.5), CFrame.new(38, 4.5, zs + 30), Color3.fromRGB(255, 255, 255), "FlagPole")
		PropKit.brick(m, Vector3.new(0.2, 2.4, 3.4), CFrame.new(38, 7.8, zs + 31.7), Color3.fromRGB(255, 70, 70), "Flag")
		PropKit.brick(m, Vector3.new(10, 0.4, 14), CFrame.new(38, 0.2, zs + 55), Color3.fromRGB(240, 220, 160), "SandTrap")
		flag.Name = "FlagPole"
	elseif z == 3 then
		for i = 0, 3 do
			PropKit.brick(m, Vector3.new(5, 4, 4), CFrame.new(-38, 2, zs + 10 + i * 14), Color3.fromRGB(235, 190, 70), "HayBale")
		end
	elseif z == 4 then
		for side = -1, 1, 2 do
			local pool = PropKit.brick(m, Vector3.new(10, 0.6, 50), CFrame.new(side * 38, 0.3, zs + 36), Color3.fromRGB(60, 160, 200), "SwampWater")
			pool.Material = Enum.Material.Glass
			pool.Transparency = 0.25
		end
	elseif z == 5 then
		for _, x in { -40, 40 } do
			PropKit.coneTree(m, Vector3.new(x, 0, zs + 40), 3.4, Color3.fromRGB(20, 110, 40))
		end
	end

	gasPump(m, Vector3.new(36, 0, zs - 8), info)
end

function RunBuilder.build()
	local world = Environment.apply()
	local info = { world = world, gates = {}, pumps = {} }
	hub(world, info)
	gasPump(world, Vector3.new(14, 0, -40), info)
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
	return info
end

-- Centre of patch (col, row) of a zone, at ground level.
function RunBuilder.patchPosition(z: number, col: number, row: number): Vector3
	local t = Config.GRID.tile
	local x = -Config.GRID.cols * t / 2 + (col - 0.5) * t
	local zz = Config.zoneStartZ(z) + (row - 0.5) * t
	return Vector3.new(x, 0.3, zz)
end

function RunBuilder.zoneCentre(z: number): Vector3
	return Vector3.new(0, 0, Config.zoneStartZ(z) + fieldLength() / 2)
end

return RunBuilder
