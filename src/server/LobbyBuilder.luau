-- Builds the lobby plaza: party pads, class booth, perks, rewards chest, garage, store, trees and fences.
-- Returns the handles the Lobby system needs (pads, stock board).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)
local Environment = require(script.Parent.Environment)

local LobbyBuilder = {}


local function ground(world: Instance)
	-- soft grass everywhere, a wooden deck plaza in the middle, gravel paths to the pads and stalls
	PropKit.brick(world, Vector3.new(420, 2, 420), CFrame.new(0, -1, 0), PropKit.GRASS_GREEN, "Grass", Enum.Material.Grass)
	PropKit.brick(world, Vector3.new(120, 0.4, 120), CFrame.new(0, 0.2, -5), Color3.fromRGB(196, 150, 100), "Deck", Enum.Material.WoodPlanks)
	PropKit.brick(world, Vector3.new(124, 0.3, 124), CFrame.new(0, 0.15, -5), Color3.fromRGB(150, 105, 65), "DeckEdge", Enum.Material.Wood)
	PropKit.brick(world, Vector3.new(14, 0.3, 50), CFrame.new(0, 0.15, -80), Color3.fromRGB(170, 160, 145), "Path", Enum.Material.Pebble)
	-- keep players in
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local pos = Vector3.new(side[1] * 100, 20, side[2] * 100)
		local wallSize = if side[1] ~= 0 then Vector3.new(2, 40, 200) else Vector3.new(200, 40, 2)
		PropKit.wall(world, wallSize, CFrame.new(pos))
	end
end

local function decor(world: Instance)
	-- a thick forest ring around the plaza, plus mountains far behind
	local trees = PropKit.folder("Trees", world)
	local rng = Random.new(7)
	for ring = 0, 2 do
		local r = 84 + ring * 16
		local count = 22 + ring * 6
		for i = 0, count - 1 do
			local t = (i + rng:NextNumber(-0.3, 0.3)) / count * math.pi * 2
			local rr = r + rng:NextNumber(-4, 4)
			PropKit.forestTree(trees, Vector3.new(math.cos(t) * rr, 0, math.sin(t) * rr), rng:NextNumber(1.1, 1.6))
		end
	end
	for i = 0, 7 do
		local t = i / 8 * math.pi * 2 + 0.3
		PropKit.mountain(world, Vector3.new(math.cos(t) * 330, -2, math.sin(t) * 330), rng:NextNumber(1.6, 2.4))
	end
	-- fence around the plaza edge
	local fence = PropKit.folder("Fence", world)
	local brown = Color3.fromRGB(150, 105, 65)
	local e = 62
	PropKit.fence(fence, Vector3.new(-e, 0, -e - 5), Vector3.new(-8, 0, -e - 5), brown)
	PropKit.fence(fence, Vector3.new(8, 0, -e - 5), Vector3.new(e, 0, -e - 5), brown)
end

local function arch(world: Instance)
	local m = PropKit.folder("TitleArch", world)
	local z = -40
	for _, x in { -22, 22 } do
		PropKit.brick(m, Vector3.new(5, 22, 5), CFrame.new(x, 11, z), PropKit.TRUNK, "Pillar", Enum.Material.Wood)
		PropKit.brick(m, Vector3.new(6.4, 2, 6.4), CFrame.new(x, 22.5, z), PropKit.LEAVES, "PillarCap", Enum.Material.Grass)
	end
	local beam = PropKit.sign(m, CFrame.new(0, 19, z), Vector3.new(36, 6, 2), Config.GAME_NAME:upper(), Color3.fromRGB(80, 200, 80), Color3.fromRGB(255, 230, 80))
	beam.Name = "TitleBeam"
	-- little lawnmower mascot on top: body, handle, wheels
	local mo = CFrame.new(0, 23.4, z)
	PropKit.brick(m, Vector3.new(6, 2.2, 4), mo, Color3.fromRGB(255, 80, 70), "MowerBody")
	PropKit.brick(m, Vector3.new(0.6, 4, 0.6), mo * CFrame.new(-1.8, 2.4, 1.6) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(60, 60, 70), "Handle")
	PropKit.brick(m, Vector3.new(0.6, 4, 0.6), mo * CFrame.new(1.8, 2.4, 1.6) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(60, 60, 70), "Handle")
	for _, wx in { -2.6, 2.6 } do
		for _, wz in { -1.4, 1.4 } do
			PropKit.cylinder(m, 0.9, 0.6, mo * CFrame.new(wx, -1, wz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 45))
		end
	end
end

-- The class booth has a big board that the Lobby system updates with the current stock.
local function classBooth(world: Instance)
	local m = PropKit.stall(world, CFrame.new(-55, 0, -5) * CFrame.Angles(0, math.rad(-90), 0), "CLASSES", Color3.fromRGB(160, 95, 255), "Classes")
	local board = PropKit.part({
		size = Vector3.new(16, 9, 1),
		cf = CFrame.new(-62, 9, -5) * CFrame.Angles(0, math.rad(-90), 0),
		color = Color3.fromRGB(60, 40, 110),
		parent = m,
		name = "StockBoard",
	})
	local label = PropKit.surfaceText(board, "Classes in stock", Color3.new(1, 1, 1))
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function rewardsChest(world: Instance)
	local m = Instance.new("Model")
	m.Name = "FreeRewards"
	local cf = CFrame.new(55, 0, -5) * CFrame.Angles(0, math.rad(90), 0)
	local gold = Color3.fromRGB(255, 205, 50)
	local pink = Color3.fromRGB(255, 120, 150)
	local base = PropKit.brick(m, Vector3.new(10, 5, 7), cf * CFrame.new(0, 2.5, 0), gold, "ChestBase")
	PropKit.brick(m, Vector3.new(10.4, 3, 7.4), cf * CFrame.new(0, 6.5, 0), PropKit.shade(gold, 1.05), "ChestLid")
	PropKit.brick(m, Vector3.new(10.6, 1, 7.6), cf * CFrame.new(0, 5.2, 0), pink, "ChestBand")
	PropKit.brick(m, Vector3.new(1.6, 2, 0.6), cf * CFrame.new(0, 4.6, -3.8), pink, "Lock")
	local ring = PropKit.pad(world, (cf * CFrame.new(0, 0, 0)).Position, 8, gold)
	ring.Transparency = 0.5
	PropKit.billboard(base, "FREE REWARDS", Color3.fromRGB(255, 230, 80), Vector2.new(14, 3), Vector3.new(0, 8, 0))
	PropKit.prompt(base, "Open", "Free Rewards", "Rewards")
	m.Parent = world
end

local function garage(world: Instance)
	local cf = CFrame.new(55, 0, 25) * CFrame.Angles(0, math.rad(90), 0)
	local m = Instance.new("Model")
	m.Name = "Garage"
	local wall = Color3.fromRGB(80, 160, 255)
	PropKit.brick(m, Vector3.new(18, 10, 1), cf * CFrame.new(0, 5, 6), wall, "Back")
	PropKit.brick(m, Vector3.new(1, 10, 12), cf * CFrame.new(-8.5, 5, 0), wall, "Side")
	PropKit.brick(m, Vector3.new(1, 10, 12), cf * CFrame.new(8.5, 5, 0), wall, "Side")
	PropKit.brick(m, Vector3.new(19, 1.2, 13), cf * CFrame.new(0, 10.6, 0), PropKit.shade(wall, 0.8), "Roof")
	local sign = PropKit.sign(m, cf * CFrame.new(0, 13, -6), Vector3.new(14, 3, 0.8), "GARAGE", Color3.fromRGB(255, 140, 40))
	sign.Name = "GarageSign"
	-- a display mower on a turntable
	local floor = PropKit.cylinder(m, 5, 0.6, cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(230, 230, 240))
	PropKit.brick(m, Vector3.new(5, 2.4, 7), cf * CFrame.new(0, 2, 0), Color3.fromRGB(255, 200, 40), "DisplayMower")
	PropKit.brick(m, Vector3.new(2.2, 2.4, 2), cf * CFrame.new(0, 4.2, 1.2), Color3.fromRGB(50, 50, 60), "DisplaySeat")
	PropKit.prompt(floor, "Open", "Garage", "Garage")
	m.Parent = world
end

local function partyArea(world: Instance)
	local pads = {}
	PropKit.sign(world, CFrame.new(15, 9, 62), Vector3.new(30, 5, 1.5), "START A RUN", Color3.fromRGB(80, 200, 80), Color3.fromRGB(255, 255, 255))
	local defs = {
		{ kind = "solo", pos = Vector3.new(-30, 0, 40), color = Color3.fromRGB(80, 200, 80), label = "SOLO" },
		{ kind = "party", pos = Vector3.new(0, 0, 40), color = Color3.fromRGB(60, 165, 255), label = "PARTY" },
		{ kind = "party", pos = Vector3.new(30, 0, 40), color = Color3.fromRGB(160, 95, 255), label = "PARTY" },
		{ kind = "party", pos = Vector3.new(60, 0, 40), color = Color3.fromRGB(255, 110, 190), label = "PARTY" },
	}
	for i, d in defs do
		PropKit.pad(world, d.pos, 7, d.color)
		local holder = PropKit.part({ size = Vector3.new(1, 1, 1), cf = CFrame.new(d.pos + Vector3.new(0, 1, 0)), color = d.color, parent = world, transparency = 1, collide = false, name = "PadInfo" .. i })
		holder.CanQuery = false
		local label = PropKit.billboard(holder, d.label, Color3.new(1, 1, 1), Vector2.new(12, 4), Vector3.new(0, 6, 0), 150)
		table.insert(pads, { kind = d.kind, pos = d.pos, radius = 7, label = label, title = d.label })
	end
	return pads
end

function LobbyBuilder.build()
	local world = Environment.apply()
	ground(world)
	decor(world)
	arch(world)
	Environment.spawn(world, CFrame.new(0, 0.5, -62))
	local stockLabel = classBooth(world)
	PropKit.stall(world, CFrame.new(-55, 0, 25) * CFrame.Angles(0, math.rad(-90), 0), "GEM PERKS", Color3.fromRGB(60, 165, 255), "Perks")
	PropKit.stall(world, CFrame.new(0, 0, -10), "STORE", Color3.fromRGB(255, 110, 190), "Store")
	rewardsChest(world)
	garage(world)
	local pads = partyArea(world)
	return { world = world, stockLabel = stockLabel, pads = pads }
end

return LobbyBuilder
