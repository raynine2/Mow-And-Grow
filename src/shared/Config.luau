-- Mow A Lawn: every number and every piece of content lives here.
-- Systems read from this table, so new content starts with a new entry here.

local Config = {}

Config.GAME_NAME = "Mow A Lawn"
Config.GROUP_ID = 96047379 -- Atlas Interactive Inc (group reward)
Config.ADMINS = { 1994267229 }

-- Studio only: which mode a test server starts in ("Lobby" or "Run").
-- The Workspace attribute ForceMode overrides this.
Config.STUDIO_MODE = "Lobby"

-- The ground: "Blender" = the ground_* models (server/GroundMesh), "Terrain" = Roblox Terrain (server/Ground).
-- Terrain for now: the ground models need a mesh upload, and as native parts they'd be thousands of wedges.
-- Blender falls back to Terrain by itself while its models aren't uploaded.
Config.GROUND = "Terrain"

Config.SAVE_KEY = "MowALawn_v1"
Config.SCHEMA = 1

-------------------------------------------------------------------------------------------------------------
-- Tools: bought in order with run coins, reset every run.
-- kind "swing": click to hit the nearest `targets` patches within `radius`.
-- kind "auto":  cuts every patch within `radius` each tick while equipped.
-------------------------------------------------------------------------------------------------------------
Config.TICK = 0.25 -- seconds between auto-cut ticks
Config.TOOLS = {
	{ id = "Hands", name = "Bare Hands", cost = 0, kind = "swing", damage = 1, cooldown = 0.45, radius = 5, targets = 1, color = Color3.fromRGB(255, 205, 160) },
	{ id = "Scissors", name = "Garden Scissors", cost = 150, kind = "swing", damage = 3, cooldown = 0.4, radius = 6, targets = 2, color = Color3.fromRGB(255, 80, 80) },
	{ id = "Sickle", name = "Sickle", cost = 1500, kind = "swing", damage = 12, cooldown = 0.45, radius = 8, targets = 4, color = Color3.fromRGB(190, 190, 205) },
	{ id = "PushMower", name = "Push Mower", cost = 12000, kind = "auto", damage = 30, radius = 6, color = Color3.fromRGB(255, 140, 30) },
	{ id = "WeedWhacker", name = "Weed Whacker", cost = 90000, kind = "auto", damage = 140, radius = 9, color = Color3.fromRGB(60, 200, 80) },
	{ id = "MegaScythe", name = "Mega Scythe", cost = 400000, kind = "swing", damage = 2500, cooldown = 0.5, radius = 13, targets = 12, color = Color3.fromRGB(150, 90, 255) },
	{ id = "LaserMower", name = "Laser Mower", cost = 1500000, kind = "auto", damage = 4000, radius = 11, color = Color3.fromRGB(60, 230, 255) },
}
Config.BOSS_TOOL_MULT = 1 -- tool damage multiplier against bosses

-------------------------------------------------------------------------------------------------------------
-- Run upgrades (coins, Tab menu). Bought one level at a time, reset every run.
-------------------------------------------------------------------------------------------------------------
-- `section` groups them in the upgrades window (Hands / Tool / Gear). Carry comes from bags (Config.BAGS); the old
-- "carry" upgrade is gone, but levels bought before still count (Config.LEGACY_CARRY_PER bundles each).
Config.UPGRADE_SECTIONS = { "Hands", "Tool", "Gear" }
Config.UPGRADES = {
	-- like Chop A Forest's first purchase: until you own it, every swing is a click
	{ id = "hold", section = "Hands", name = "Hold", desc = "Hold the button to keep cutting", per = 1, base = 20, growth = 1, max = 1 },
	{ id = "swing", section = "Hands", name = "Swing Speed", desc = "-6% time between swings", per = 0.06, base = 30, growth = 2.6, max = 10 },
	{ id = "grasp", section = "Hands", name = "Grasp", desc = "+1.5 studs pickup reach", per = 1.5, base = 60, growth = 2.5, max = 10 },
	{ id = "power", section = "Tool", name = "Power", desc = "+20% cutting power", per = 0.20, base = 100, growth = 3.2, max = 10 },
	{ id = "speed", section = "Gear", name = "Walk Speed", desc = "+6% walk speed", per = 0.06, base = 250, growth = 3.0, max = 10 },
	{ id = "sell", section = "Gear", name = "Shredder Boost", desc = "+15% coins per bundle", per = 0.15, base = 300, growth = 3.4, max = 10 },
}
Config.LEGACY_CARRY_PER = 3

-------------------------------------------------------------------------------------------------------------
-- Loot: a cut patch drops its bundle on the ground (and sometimes a free gem). Only you can pick up yours: walk
-- within your Grasp reach and it flies into your bag. Bundles on the ground count toward your bag, so you can't
-- cut more than you can carry.
-------------------------------------------------------------------------------------------------------------
Config.LOOT = {
	grasp = 7, -- base pickup reach in studs (+ Grasp upgrades, x the Leaf Vacuum)
	maxOnGround = 60, -- per player, whatever their bag size
	spread = 2.5, -- how far from the patch a drop lands
}
Config.GEM_DROP = { chance = 0.035, min = 1, max = 3 } -- per cut patch, before Gem Value / 2x Gems

-- Bags: bought in order at the Bag Stand in the hub (coins, reset every run). The Bottomless Sack game pass
-- (Config.PASSES.BigBag) makes your bag endless.
Config.BAGS = {
	{ id = "Satchel", name = "Grass Satchel", model = "bag_satchel", cost = 175, carry = 5 },
	{ id = "Backpack", name = "Clipping Backpack", model = "bag_backpack", cost = 750, carry = 15 },
	{ id = "Expedition", name = "Expedition Pack", model = "bag_hiker", cost = 9000, carry = 40 },
}
Config.ENDLESS_CARRY = 9999 -- what "endless" means in numbers (the HUD shows it as a big infinity sign)

-- The Leaf Vacuum: gear from the Bag Stand. Owned for the run, works on its own (no need to hold it).
Config.VACUUM = { name = "Leaf Vacuum", cost = 1000, graspMult = 3 }

-- The Index: every grass type x mutation you've collected. A new one pays gems once.
Config.INDEX_GEMS = 5

function Config.upgrade(id: string)
	for _, u in Config.UPGRADES do
		if u.id == id then
			return u
		end
	end
	return nil
end

function Config.upgradeCost(id: string, level: number): number
	local u = Config.upgrade(id)
	if not u then
		return math.huge
	end
	return math.floor(u.base * u.growth ^ level)
end

-------------------------------------------------------------------------------------------------------------
-- Areas (zones), like Chop A Forest's woods: fenced fields that open one after another. Mow every clump in the
-- newest area and the next one unlocks (its gates sink into the ground). Clumps are "grass trees": you chop one
-- down, it falls over and breaks into `drops` bundles, and its stubble stays until the whole area is cleared.
-- Clumps stand 7-14 studs tall like trees (`scale` x their model, `spacing` studs apart); later areas are tougher.
-- model: the clump model (default "tuft_" .. style); tint: recolour it (flat colour instead of its texture).
-------------------------------------------------------------------------------------------------------------
Config.BASE_CARRY = 5
Config.BOSSES = false -- true: clearing an area wakes its boss, and the boss opens the next area (the old way)

Config.ZONES = {
	{
		name = "Backyard Lawn", grassName = "Lawn Grass", style = "lawn", hp = 3, value = 2, drops = 1, height = 2,
		spacing = 11, scale = 4.0,
		grass = { Color3.fromRGB(110, 210, 70), Color3.fromRGB(90, 195, 60) },
		ground = Color3.fromRGB(150, 110, 70),
		boss = { name = "Dandelion King", hp = 400, color = Color3.fromRGB(255, 220, 40), every = 4.5, radius = 9, gems = 10, coins = 150 },
	},
	{
		name = "Flower Meadow", grassName = "Meadow Grass", style = "meadow", model = "tuft_golf", hp = 12, value = 8, drops = 1, height = 2.2,
		spacing = 11.5, scale = 6.3, tint = Color3.fromRGB(150, 215, 95),
		grass = { Color3.fromRGB(150, 215, 95), Color3.fromRGB(130, 200, 80) },
		ground = Color3.fromRGB(120, 160, 70),
		boss = { name = "Thorn Bush", hp = 2000, color = Color3.fromRGB(40, 140, 60), every = 4.2, radius = 9, gems = 15, coins = 600 },
	},
	{
		name = "Golf Course", grassName = "Golf Grass", style = "golf", hp = 50, value = 30, drops = 1, height = 2.5,
		spacing = 12.5, scale = 7.2,
		grass = { Color3.fromRGB(70, 200, 90), Color3.fromRGB(55, 180, 75) },
		ground = Color3.fromRGB(235, 215, 150),
		boss = { name = "Thorn Bush", hp = 6000, color = Color3.fromRGB(40, 140, 60), every = 4, radius = 10, gems = 20, coins = 2000 },
	},
	{
		name = "Wheat Farm", grassName = "Wheat", style = "wheat", hp = 150, value = 55, drops = 1, height = 5,
		spacing = 8, scale = 4.0,
		grass = { Color3.fromRGB(240, 200, 80), Color3.fromRGB(225, 180, 60) },
		ground = Color3.fromRGB(140, 95, 55),
		boss = { name = "Venus Flytrap", hp = 90000, color = Color3.fromRGB(200, 40, 70), every = 3.6, radius = 11, gems = 35, coins = 25000 },
	},
	{
		name = "Blossom Garden", grassName = "Blossom Grass", style = "blossom", model = "tuft_lawn", hp = 600, value = 200, drops = 2, height = 2.5,
		spacing = 13.5, scale = 5.1, tint = Color3.fromRGB(255, 160, 205),
		grass = { Color3.fromRGB(255, 160, 205), Color3.fromRGB(240, 130, 185) },
		ground = Color3.fromRGB(120, 170, 80),
		boss = { name = "Venus Flytrap", hp = 300000, color = Color3.fromRGB(200, 40, 70), every = 3.5, radius = 11, gems = 45, coins = 80000 },
	},
	{
		name = "Swamp Reeds", grassName = "Reeds", style = "reeds", hp = 2500, value = 750, drops = 2, height = 6.5,
		spacing = 12, scale = 4.6,
		grass = { Color3.fromRGB(80, 150, 100), Color3.fromRGB(60, 130, 90) },
		ground = Color3.fromRGB(70, 100, 85),
		boss = { name = "Swamp Vine", hp = 1200000, color = Color3.fromRGB(90, 70, 140), every = 3.3, radius = 12, gems = 55, coins = 300000 },
	},
	{
		name = "Autumn Prairie", grassName = "Prairie Grass", style = "prairie", model = "tuft_wheat", hp = 6000, value = 1600, drops = 2, height = 6,
		spacing = 9.5, scale = 5.1, tint = Color3.fromRGB(235, 120, 45),
		grass = { Color3.fromRGB(235, 120, 45), Color3.fromRGB(215, 95, 40) },
		ground = Color3.fromRGB(150, 110, 60),
		boss = { name = "Swamp Vine", hp = 4000000, color = Color3.fromRGB(90, 70, 140), every = 3.1, radius = 13, gems = 65, coins = 1000000 },
	},
	{
		name = "Mega Jungle", grassName = "Jungle Bush", style = "jungle", hp = 60000, value = 8000, drops = 4, height = 8,
		spacing = 21, scale = 6.0,
		grass = { Color3.fromRGB(30, 160, 60), Color3.fromRGB(20, 130, 50) },
		ground = Color3.fromRGB(90, 70, 45),
		boss = { name = "Jungle Titan", hp = 15000000, color = Color3.fromRGB(20, 90, 40), every = 3, radius = 14, gems = 80, coins = 4000000 },
	},
}
Config.BOSS_HP_PER_EXTRA_PLAYER = 0.6 -- +60% boss HP for every party member after the first
Config.RUN_COMPLETE_GEMS = 150

-- (old straight-road layout; only the unused Blender ground sheets in server/GroundMesh still read these)
Config.ZONE_SPACING = 120
Config.FIRST_ZONE_Z = 30
function Config.zoneStartZ(zone: number): number
	return Config.FIRST_ZONE_Z + (zone - 1) * Config.ZONE_SPACING
end

-------------------------------------------------------------------------------------------------------------
-- The run map: ONE continuous world like Chop A Forest's, a 3 x 3 grid of square fenced plots. The hub (spawn,
-- tool shop, shredder, bag stand, garage) is the middle plot of the south row and the areas fill the other eight,
-- opening outward from the hub: the first right in front of it, the next two beside it, then the middle row's
-- sides, then the far row. Every two plots that touch share a fence with a gate in the middle, and a gate opens
-- once both of its plots are open. A forest belt and snowy mountains close the world off.
-- Grid cells are { col, row }: col 1..3 runs west to east (-X to +X), row 1..3 south to north (-Z to +Z).
-------------------------------------------------------------------------------------------------------------
Config.MAP = {
	cell = 180, -- one plot's side, fence to fence
	hubCell = { 2, 1 },
	hubCentre = Vector3.new(0, 0, -48), -- the middle of the hub plot (the hub buildings are built around it)
	cells = { { 2, 2 }, { 3, 1 }, { 1, 1 }, { 3, 2 }, { 1, 2 }, { 2, 3 }, { 3, 3 }, { 1, 3 } }, -- area z's plot
	gateWidth = 20, -- the opening in a shared fence
	margin = 13, -- no grass this close to a fence (each area's signature trees line the inside of its fences)
	dropOff = 1, -- the second shredder stands in the middle of this area (Chop A Forest's far-off shredder)
}

local function cellOf(z: number): { number }
	return if z <= 0 then Config.MAP.hubCell else Config.MAP.cells[z]
end

-- The middle of area z's plot (z = 0: the hub), on the ground.
function Config.zoneCentre(z: number): Vector3
	local M = Config.MAP
	local c = cellOf(z)
	return M.hubCentre + Vector3.new((c[1] - M.hubCell[1]) * M.cell, 0, (c[2] - M.hubCell[2]) * M.cell)
end

-- Half the side of a plot.
function Config.zoneHalf(): number
	return Config.MAP.cell / 2
end

-- Which area a point is in: 0 = the hub, 1..n = an area, -1 = outside the map.
function Config.zoneAt(pos: Vector3): number
	local M = Config.MAP
	local col = math.floor((pos.X - M.hubCentre.X) / M.cell + 0.5) + M.hubCell[1]
	local row = math.floor((pos.Z - M.hubCentre.Z) / M.cell + 0.5) + M.hubCell[2]
	if col == M.hubCell[1] and row == M.hubCell[2] then
		return 0
	end
	for z, c in M.cells do
		if c[1] == col and c[2] == row then
			return z
		end
	end
	return -1
end

-- Every gate: a shared fence between two plots that touch. { a, b } are the areas on each side (0 = the hub,
-- a < b), pos is the gate's middle on the ground and along the direction the fence runs. A gate is open once
-- area b is unlocked.
export type Gate = { a: number, b: number, pos: Vector3, along: Vector3 }
local gateList: { Gate }? = nil
function Config.gates(): { Gate }
	if gateList then
		return gateList
	end
	local list: { Gate } = {}
	local ids = { 0 }
	for z = 1, #Config.MAP.cells do
		table.insert(ids, z)
	end
	for i = 1, #ids do
		for j = i + 1, #ids do
			local a, b = ids[i], ids[j]
			local ca, cb = cellOf(a), cellOf(b)
			local dc, dr = cb[1] - ca[1], cb[2] - ca[2]
			if math.abs(dc) + math.abs(dr) == 1 then
				local mid = (Config.zoneCentre(a) + Config.zoneCentre(b)) / 2
				table.insert(list, { a = math.min(a, b), b = math.max(a, b), pos = mid, along = if dc ~= 0 then Vector3.zAxis else Vector3.xAxis })
			end
		end
	end
	gateList = list
	return list
end

-- The gate you walk through into area z: the one from the most recently opened neighbour.
function Config.gateInto(z: number): Gate?
	local best: Gate? = nil
	for _, g in Config.gates() do
		if g.b == z and (best == nil or g.a > best.a) then
			best = g
		end
	end
	return best
end

-- Where that gate is, on the ground.
function Config.gatePos(z: number): Vector3
	local g = Config.gateInto(z)
	return if g then g.pos else Config.zoneCentre(z)
end

-- A spot just inside area z, past its gate.
function Config.zoneEntry(z: number): Vector3
	local g = Config.gateInto(z)
	if not g then
		return Config.zoneCentre(z)
	end
	local into = Config.zoneCentre(z) - g.pos
	return g.pos + into.Unit * 10
end

-------------------------------------------------------------------------------------------------------------
-- The generated world (server/WorldGen from shared/Zones): a village in the middle and eight valleys around
-- it, each behind one gate. When WORLD_GEN is on, runs play there (server/RunWorld) and the map helpers above
-- answer for it: Config zone z is Zones.list[z], the hub is the village (its buildings south of the fountain),
-- and gate positions come from attributes WorldGen puts on Workspace.World (GatePos<z>, GateEntry<z>).
-------------------------------------------------------------------------------------------------------------
Config.WORLD_GEN = true

do
	local Zones = require(script.Parent.Zones)
	local plotCentre, plotAt, plotGates, plotEntry = Config.zoneCentre, Config.zoneAt, Config.gates, Config.zoneEntry
	local HUB = Vector3.new(0, 0, -48)

	local function genWorld(): Instance?
		local w = workspace:FindFirstChild("World")
		return if w and w:GetAttribute("GatePos2") ~= nil then w else nil
	end

	function Config.zoneCentre(z: number): Vector3
		if not Config.WORLD_GEN then
			return plotCentre(z)
		end
		local def = Zones.list[z]
		if z <= 0 or not def then
			return HUB
		end
		return Vector3.new(def.center.X, def.base, def.center.Y)
	end

	function Config.zoneAt(pos: Vector3): number
		if not Config.WORLD_GEN then
			return plotAt(pos)
		end
		return Zones.zoneAt(pos) or -1
	end

	function Config.gates(): { Gate }
		local w = Config.WORLD_GEN and genWorld()
		if not w then
			return plotGates()
		end
		local list: { Gate } = {}
		for z = 1, #Zones.list do
			local pos = w:GetAttribute("GatePos" .. z)
			if typeof(pos) == "Vector3" then
				table.insert(list, { a = z - 1, b = z, pos = pos, along = Vector3.xAxis })
			end
		end
		return list
	end

	function Config.zoneEntry(z: number): Vector3
		local w = Config.WORLD_GEN and genWorld()
		local entry = w and w:GetAttribute("GateEntry" .. z)
		if typeof(entry) == "Vector3" then
			return entry
		end
		return plotEntry(z)
	end
end

-------------------------------------------------------------------------------------------------------------
-- World look: lighting and post-processing (shared/Look applies it). `base` is the lobby and the hub; the
-- server sets it at start. In a run the client (client/ZoneMood) blends toward each zone's mood as you walk,
-- so a mood only lists what it changes. Colours are Color3, the rest numbers; everything here can be blended.
-------------------------------------------------------------------------------------------------------------
Config.LOOK = {
	-- set once by the server (not blended): an afternoon sun for long, soft shadows; built-in clouds
	clockTime = 15.2,
	latitude = 38,
	shadowSoftness = 0.25,
	envDiffuse = 0.75,
	envSpecular = 0.35,
	sunSize = 16, -- Sky.SunAngularSize (bigger, warmer sun for the glare)
	bloomSize = 26,
	bloomThreshold = 1.4, -- only HDR-bright things bloom (sun, neon, glare)
	dof = { focus = 60, radius = 70, far = 0.1 }, -- very soft blur far away only
	clouds = { cover = 0.42, density = 0.32, color = Color3.fromRGB(255, 255, 255) }, -- soft high streaks
	wind = Vector3.new(4, 0, 3), -- workspace.GlobalWind: drifts the clouds and the floating pollen
	base = {
		brightness = 2.7,
		exposure = 0.05,
		ambient = Color3.fromRGB(118, 112, 128),
		outdoorAmbient = Color3.fromRGB(168, 162, 170),
		colorShiftTop = Color3.fromRGB(255, 244, 222),
		saturation = 0.24,
		contrast = 0.1,
		ccBrightness = 0.015,
		tint = Color3.fromRGB(255, 251, 242),
		-- a saturated cartoon-blue sky with a pale, hazy band at the horizon (Chop A Forest's sky)
		atmoDensity = 0.3,
		atmoOffset = 0.25,
		atmoColor = Color3.fromRGB(214, 232, 255),
		atmoDecay = Color3.fromRGB(86, 136, 232),
		atmoGlare = 0.15,
		atmoHaze = 1.0,
		bloomIntensity = 0.55,
		raysIntensity = 0.05,
		raysSpread = 0.55,
	},
	-- Night in a run (server/DayNight turns the clock; client/ZoneMood blends this in as the sun goes down):
	-- deep blue light, stars and the moon in the sky.
	night = {
		brightness = 1.1,
		exposure = -0.05,
		ambient = Color3.fromRGB(58, 66, 110),
		outdoorAmbient = Color3.fromRGB(74, 88, 150),
		colorShiftTop = Color3.fromRGB(120, 140, 220),
		saturation = 0.08,
		contrast = 0.12,
		ccBrightness = 0.02,
		tint = Color3.fromRGB(196, 210, 255),
		atmoDensity = 0.32,
		atmoOffset = 0.2,
		atmoColor = Color3.fromRGB(70, 92, 160),
		atmoDecay = Color3.fromRGB(26, 36, 92),
		atmoGlare = 0,
		atmoHaze = 1.2,
		bloomIntensity = 0.8,
		raysIntensity = 0,
		raysSpread = 0.55,
	},
	day = { length = 480, nightLength = 240, dawn = 6.5, dusk = 18 }, -- seconds of day and night, sun times
	moods = {
		-- fresh green-gold
		lawn = {
			tint = Color3.fromRGB(252, 255, 236),
			saturation = 0.28,
			atmoColor = Color3.fromRGB(212, 232, 214),
			atmoDecay = Color3.fromRGB(140, 185, 165),
			colorShiftTop = Color3.fromRGB(255, 246, 215),
		},
		-- soft spring morning: light haze, a touch of warmth
		meadow = {
			tint = Color3.fromRGB(255, 252, 232),
			saturation = 0.32,
			atmoColor = Color3.fromRGB(225, 236, 214),
			atmoDecay = Color3.fromRGB(160, 195, 160),
			colorShiftTop = Color3.fromRGB(255, 240, 210),
			atmoHaze = 1.4,
		},
		-- pink blossom light: rosy air, gentle bloom
		blossom = {
			tint = Color3.fromRGB(255, 240, 246),
			saturation = 0.3,
			colorShiftTop = Color3.fromRGB(255, 225, 235),
			atmoColor = Color3.fromRGB(250, 222, 236),
			atmoDecay = Color3.fromRGB(215, 160, 190),
			atmoGlare = 0.4,
			atmoHaze = 1.5,
			bloomIntensity = 0.7,
		},
		-- late autumn sun: deep orange, long haze
		prairie = {
			tint = Color3.fromRGB(255, 228, 196),
			saturation = 0.34,
			contrast = 0.14,
			colorShiftTop = Color3.fromRGB(255, 196, 130),
			outdoorAmbient = Color3.fromRGB(190, 160, 135),
			atmoDensity = 0.32,
			atmoColor = Color3.fromRGB(250, 210, 165),
			atmoDecay = Color3.fromRGB(215, 130, 80),
			atmoGlare = 0.7,
			atmoHaze = 1.9,
			bloomIntensity = 0.7,
			raysIntensity = 0.12,
		},
		-- bright and clean: clearer air, crisp contrast
		golf = {
			tint = Color3.fromRGB(248, 252, 255),
			contrast = 0.13,
			ccBrightness = 0.03,
			atmoDensity = 0.22,
			atmoHaze = 0.6,
			atmoGlare = 0.15,
			atmoColor = Color3.fromRGB(215, 232, 255),
			bloomIntensity = 0.5,
		},
		-- warm golden afternoon
		wheat = {
			tint = Color3.fromRGB(255, 236, 205),
			saturation = 0.3,
			colorShiftTop = Color3.fromRGB(255, 212, 150),
			outdoorAmbient = Color3.fromRGB(185, 165, 145),
			atmoDensity = 0.3,
			atmoColor = Color3.fromRGB(255, 226, 182),
			atmoDecay = Color3.fromRGB(225, 165, 110),
			atmoGlare = 0.65,
			atmoHaze = 1.7,
			bloomIntensity = 0.7,
			raysIntensity = 0.1,
		},
		-- misty teal swamp
		reeds = {
			tint = Color3.fromRGB(222, 245, 242),
			saturation = 0.1,
			contrast = 0.05,
			ccBrightness = 0,
			ambient = Color3.fromRGB(105, 128, 128),
			outdoorAmbient = Color3.fromRGB(145, 168, 165),
			colorShiftTop = Color3.fromRGB(225, 245, 240),
			atmoDensity = 0.44,
			atmoOffset = 0.06,
			atmoColor = Color3.fromRGB(172, 214, 208),
			atmoDecay = Color3.fromRGB(90, 140, 140),
			atmoGlare = 0.1,
			atmoHaze = 2.6,
			raysIntensity = 0.03,
		},
		-- deep green, humid haze, god-rays through the canopy
		jungle = {
			brightness = 2.5,
			tint = Color3.fromRGB(228, 255, 226),
			saturation = 0.32,
			contrast = 0.15,
			ccBrightness = -0.02,
			ambient = Color3.fromRGB(95, 125, 95),
			outdoorAmbient = Color3.fromRGB(140, 170, 135),
			colorShiftTop = Color3.fromRGB(240, 255, 210),
			atmoDensity = 0.42,
			atmoOffset = 0.1,
			atmoColor = Color3.fromRGB(175, 212, 165),
			atmoDecay = Color3.fromRGB(60, 112, 72),
			atmoGlare = 0.45,
			atmoHaze = 2.2,
			bloomIntensity = 0.65,
			raysIntensity = 0.2,
			raysSpread = 0.8,
		},
	} :: { [string]: { [string]: any } },
}

-------------------------------------------------------------------------------------------------------------
-- Quests: the onboarding chain shown top-left during a run (like Chop A Forest's "QUEST 3/8").
-- event = what counts: cut (patches), sell (bundles sold), tool (best tool index reached), carry (backpack
-- levels), zone (zones cleared), boss (bosses beaten), mower (a ride-on mower bought or spawned).
-------------------------------------------------------------------------------------------------------------
Config.QUESTS = {
	{ title = "Cut 10 grass", hint = "Look at a clump and click to chop it", event = "cut", goal = 10, reward = 20 },
	{ title = "Sell your bundles", hint = "Walk onto the sell pad", event = "sell", goal = 5, reward = 40 },
	{ title = "Buy the Scissors in the cabin", hint = "They're on the wall inside the cabin", event = "tool", goal = 2, reward = 25 },
	{ title = "Buy a bag at the Bag Stand", hint = "It's by the spawn, next to the tool shop", event = "bag", goal = 1, reward = 100 },
	{ title = "Cut 60 grass", hint = "Keep mowing the Backyard Lawn", event = "cut", goal = 60, reward = 150 },
	{ title = "Mow the whole Backyard Lawn", hint = "Every last patch!", event = "zone", goal = 1, reward = 250 },
	{ title = "Mow the whole Flower Meadow", hint = "Its gate opened when you cleared the lawn", event = "zone", goal = 1, reward = 300 },
	{ title = "Get a ride-on mower", hint = "Buy one at the Garage", event = "mower", goal = 1, reward = 500 },
}

-------------------------------------------------------------------------------------------------------------
-- Mutations: rolled when a patch is first hit (hidden until then). Luck multiplies every non-None weight.
-------------------------------------------------------------------------------------------------------------
Config.MUTATIONS = {
	{ id = "None", weight = 860, mult = 1, gems = 0 },
	{ id = "Golden", weight = 80, mult = 2, gems = 1, color = Color3.fromRGB(255, 205, 40) },
	{ id = "Rainbow", weight = 35, mult = 3, gems = 2, color = Color3.fromRGB(255, 110, 200) },
	{ id = "Diamond", weight = 15, mult = 5, gems = 4, color = Color3.fromRGB(120, 230, 255) },
	{ id = "Toxic", weight = 7, mult = 7, gems = 8, color = Color3.fromRGB(150, 255, 40) },
	{ id = "Galaxy", weight = 3, mult = 10, gems = 20, color = Color3.fromRGB(130, 70, 255) },
}

function Config.mutation(id: string)
	for _, m in Config.MUTATIONS do
		if m.id == id then
			return m
		end
	end
	return Config.MUTATIONS[1]
end

function Config.rollMutation(rng: Random, luck: number): string
	local total = 0
	for _, m in Config.MUTATIONS do
		total += if m.id == "None" then m.weight else m.weight * luck
	end
	local pick = rng:NextNumber() * total
	for _, m in Config.MUTATIONS do
		pick -= if m.id == "None" then m.weight else m.weight * luck
		if pick <= 0 then
			return m.id
		end
	end
	return "None"
end

-------------------------------------------------------------------------------------------------------------
-- Classes: bought with gems from the lobby booth (stock rolls every 5 min), owned forever, one equipped.
-------------------------------------------------------------------------------------------------------------
Config.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 90),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 110),
	Secret = Color3.fromRGB(40, 40, 50),
}
Config.CLASSES = {
	{ id = "WeedPuller", name = "Weed Puller", rarity = "Common", gems = 0, power = 0.05 },
	{ id = "Gardener", name = "Gardener", rarity = "Uncommon", gems = 180, power = 0.10, carry = 1 },
	{ id = "Groundskeeper", name = "Groundskeeper", rarity = "Rare", gems = 270, carry = 2, sell = 0.10 },
	{ id = "LawnBaron", name = "Lawn Baron", rarity = "Rare", gems = 330, sell = 0.30 },
	{ id = "HedgeReaper", name = "Hedge Reaper", rarity = "Epic", gems = 500, power = 0.20, luck = 0.25 },
	{ id = "MowerSpecialist", name = "Mower Specialist", rarity = "Epic", gems = 800, power = 0.35, speed = 0.10 },
	{ id = "GrassTitan", name = "Grass Titan", rarity = "Legendary", gems = 1000, power = 0.60, carry = 2 },
	{ id = "UltimateGardener", name = "Ultimate Gardener", rarity = "Legendary", gems = 1600, power = 0.50, speed = 0.20, sell = 0.25 },
	{ id = "LawnLegend", name = "Lawn Legend", rarity = "Mythic", gems = 2700, power = 1.0, speed = 0.25, sell = 0.50, luck = 0.50, carry = 3, product = "ClassLawnLegend" },
	{ id = "GoatMan", name = "Goat Man", rarity = "Secret", gems = 4000, power = 2.0, speed = 0.35, sell = 1.0, luck = 1.0, carry = 5, product = "ClassGoatMan" },
}
Config.DEFAULT_CLASS = "WeedPuller"
Config.STOCK_WINDOW = 300 -- seconds between booth restocks
Config.STOCK_SLOTS = 4
Config.STOCK_WEIGHTS = { Uncommon = 40, Rare = 30, Epic = 15, Legendary = 8, Mythic = 4, Secret = 1 }

function Config.class(id: string)
	for _, c in Config.CLASSES do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- The booth stock for a 5-minute window. Same seed on every server, so every lobby shows the same stock.
function Config.classStock(window: number): { string }
	local rng = Random.new(window * 7919 + 13)
	local pool = {}
	for _, c in Config.CLASSES do
		local w = Config.STOCK_WEIGHTS[c.rarity]
		if w then
			table.insert(pool, { id = c.id, weight = w })
		end
	end
	local stock = {}
	for _ = 1, Config.STOCK_SLOTS do
		local total = 0
		for _, p in pool do
			total += p.weight
		end
		if total <= 0 then
			break
		end
		local pick = rng:NextNumber() * total
		for i, p in pool do
			pick -= p.weight
			if pick <= 0 then
				table.insert(stock, p.id)
				table.remove(pool, i)
				break
			end
		end
	end
	return stock
end

-------------------------------------------------------------------------------------------------------------
-- Gem perks (lobby): permanent, bought one level at a time with gems.
-------------------------------------------------------------------------------------------------------------
Config.PERKS = {
	{ id = "sell", name = "Sell Value", desc = "+10% coins per level", per = 0.10, costs = { 25, 60, 140, 300, 600 } },
	{ id = "bundle", name = "Bigger Bundle", desc = "+10% chance of a double bundle", per = 0.10, costs = { 40, 90, 200, 400, 800 } },
	{ id = "luck", name = "Mutation Luck", desc = "+20% mutation luck per level", per = 0.20, costs = { 40, 90, 200, 400, 800 } },
	{ id = "gem", name = "Gem Value", desc = "+10% gems per level", per = 0.10, costs = { 50, 120, 260, 520, 1000 } },
}

function Config.perk(id: string)
	for _, p in Config.PERKS do
		if p.id == id then
			return p
		end
	end
	return nil
end

-------------------------------------------------------------------------------------------------------------
-- Ride-on mowers: cut while you drive and burn fuel (1 per second of driving).
-- currency "coins": bought in a run, lost when the run ends. "gems"/"robux": owned forever.
-- "trial": a Robux mower that lasts one run.
-------------------------------------------------------------------------------------------------------------
Config.MOWERS = {
	{ id = "RustyRider", name = "Rusty Rider", currency = "coins", price = 500, damage = 6, radius = 6, speed = 30, fuel = 60, color = Color3.fromRGB(200, 90, 50) },
	{ id = "TurboTractor", name = "Turbo Tractor", currency = "coins", price = 40000, damage = 120, radius = 9, speed = 38, fuel = 90, color = Color3.fromRGB(60, 170, 255) },
	{ id = "GoldenZeroTurn", name = "Golden Zero-Turn", currency = "gems", price = 900, damage = 400, radius = 10, speed = 42, fuel = 120, color = Color3.fromRGB(255, 200, 40) },
	{ id = "MonsterMulcher", name = "Monster Mulcher", currency = "gems", price = 2500, damage = 3000, radius = 12, speed = 46, fuel = 150, color = Color3.fromRGB(150, 60, 220) },
	{ id = "TrialMower", name = "Trial Mower", currency = "trial", product = "TrialMower", damage = 800, radius = 11, speed = 44, fuel = 140, color = Color3.fromRGB(255, 80, 160) },
	{ id = "RocketMower", name = "Rocket Mower", currency = "robux", product = "RocketMower", damage = 2000, radius = 12, speed = 50, fuel = 200, color = Color3.fromRGB(255, 70, 40) },
}
Config.FUEL_PRICE_PER_ZONE = { 2, 4, 10, 30, 90, 250, 700, 2000 } -- coins per fuel point, by the run's current zone

function Config.mower(id: string)
	for _, m in Config.MOWERS do
		if m.id == id then
			return m
		end
	end
	return nil
end

-------------------------------------------------------------------------------------------------------------
-- Rewards
-------------------------------------------------------------------------------------------------------------
Config.DAILY_GEMS = 35
Config.DAILY_COOLDOWN = 6 * 3600
Config.GROUP_GEMS = 100

-------------------------------------------------------------------------------------------------------------
-- Lobby parties
-------------------------------------------------------------------------------------------------------------
Config.PARTY_MAX = 4
Config.PARTY_COUNTDOWN = 15
Config.SOLO_COUNTDOWN = 3

-------------------------------------------------------------------------------------------------------------
-- Robux. Fill in the ids after creating them on the Creator Dashboard; an id of 0 shows "coming soon".
-- No paid item here has a random result. If one is ever added, give it `paidRandom = true` and show odds.
-------------------------------------------------------------------------------------------------------------
Config.PRODUCTS = {
	Gems150 = { id = 0, robux = 49, gems = 150, name = "150 Gems" },
	Gems500 = { id = 0, robux = 149, gems = 500, name = "500 Gems" },
	Gems1500 = { id = 0, robux = 399, gems = 1500, name = "1,500 Gems" },
	Gems5000 = { id = 0, robux = 999, gems = 5000, name = "5,000 Gems" },
	TrialMower = { id = 0, robux = 25, mower = "TrialMower", name = "Trial Mower (this run)" },
	RocketMower = { id = 0, robux = 499, mower = "RocketMower", name = "Rocket Mower" },
	ClassLawnLegend = { id = 0, robux = 799, class = "LawnLegend", name = "Lawn Legend class" },
	ClassGoatMan = { id = 0, robux = 1499, class = "GoatMan", name = "Goat Man class" },
}
Config.PRODUCT_ORDER = { "Gems150", "Gems500", "Gems1500", "Gems5000", "TrialMower", "RocketMower", "ClassLawnLegend", "ClassGoatMan" }

Config.PASSES = {
	DoubleCoins = { id = 0, robux = 299, name = "2x Coins", desc = "Double coins from the shredder" },
	DoubleGems = { id = 0, robux = 399, name = "2x Gems", desc = "Double gems from everything" },
	BigBag = { id = 0, robux = 149, name = "Bottomless Sack", desc = "Carry as many bundles as you like" },
	VIP = { id = 0, robux = 249, name = "VIP", desc = "+15% power, +15% sell, VIP tag" },
}
Config.PASS_ORDER = { "DoubleCoins", "DoubleGems", "BigBag", "VIP" }

function Config.productByAssetId(assetId: number)
	if assetId == 0 then
		return nil, nil
	end
	for key, p in Config.PRODUCTS do
		if p.id == assetId then
			return key, p
		end
	end
	return nil, nil
end

-------------------------------------------------------------------------------------------------------------
-- Sounds. LICENSED AUDIO ONLY: Roblox-owned assets or the engine's built-in rbxasset sounds.
-- id = "" means silent. gap = minimum seconds between plays, pitch = base playback speed.
-------------------------------------------------------------------------------------------------------------
Config.SOUNDS = {
	-- All Roblox-owned (creator "Roblox", user 1), checked on the Creator Store API on 18 Oct 2026.
	cut = { id = "rbxassetid://12222200", volume = 0.35, pitch = 1.1, gap = 0.06 }, -- swoosh.wav
	chip = { id = "rbxassetid://12222140", volume = 0.2, pitch = 1.2, gap = 0.08 }, -- snap.wav
	reveal = { id = "rbxassetid://17208327798", volume = 0.55 }, -- Roblox GUI - Aura
	sell = { id = "rbxassetid://127645268874265", volume = 0.5, gap = 0.2 }, -- CoinTransfer_01
	purchase = { id = "rbxassetid://17208380755", volume = 0.5 }, -- Roblox GUI - Purchase
	upgrade = { id = "rbxassetid://10066947742", volume = 0.45 }, -- RBLX UI Purchase (SFX)
	denied = { id = "rbxassetid://17208353912", volume = 0.4, gap = 0.6 }, -- Roblox GUI - Negative
	click = { id = "rbxassetid://15675059323", volume = 0.35, gap = 0.05 }, -- Roblox_UI_Bright_Click
	whoosh = { id = "rbxassetid://15675024286", volume = 0.35, gap = 0.1 }, -- Roblox_UI_Whoosh_01
	warn = { id = "rbxassetid://15675028888", volume = 0.35 }, -- Roblox_UI_Whoosh_02
	slam = { id = "rbxassetid://12221984", volume = 0.6, pitch = 0.7 }, -- collide.wav
	hit = { id = "rbxassetid://12222046", volume = 0.35, gap = 0.08 }, -- hit.wav
	hurt = { id = "rbxasset://sounds/ouch.ogg", volume = 0.5 }, -- engine built-in
	roar = { id = "rbxassetid://9120031442", volume = 0.45, pitch = 1.25 }, -- Thunder With Lion Roar (pitched up)
	victory = { id = "rbxassetid://12222253", volume = 0.6 }, -- victory.wav
	engine = { id = "", volume = 0.3 }, -- Roblox has no mower/engine loop; silent until a licensed one is found
	musicLobby = { id = "rbxassetid://15930255433", volume = 0.35 }, -- Roblox_RetroFluteMusic_01
	musicRun = { id = "rbxassetid://130053244401794", volume = 0.3 }, -- TutorialMusic_01
}

-------------------------------------------------------------------------------------------------------------
-- UI icons: image asset ids (rbxassetid://...) of icons rendered in Blender (tools/blender) and uploaded.
-- "" = use the drawn stand-in from client/UI.luau.
-------------------------------------------------------------------------------------------------------------
Config.ICONS = {
	coin = "", gem = "", bundle = "", backpack = "", basket = "", upgrade = "", lock = "", clover = "", leaf = "",
	stats = "", hands = "", scissors = "", sickle = "", pushmower = "", whacker = "", scythe = "", lasermower = "",
}
for name, id in require(script.Parent.IconIds) :: { [string]: string } do
	Config.ICONS[name] = id
end

-------------------------------------------------------------------------------------------------------------
-- Look (bubbly UI on Chop A Forest style wooden boards)
-------------------------------------------------------------------------------------------------------------
Config.UI = {
	font = Enum.Font.FredokaOne,
	outline = Color3.fromRGB(30, 25, 45),
	green = Color3.fromRGB(80, 210, 80),
	yellow = Color3.fromRGB(255, 205, 50),
	orange = Color3.fromRGB(255, 140, 40),
	red = Color3.fromRGB(255, 80, 80),
	blue = Color3.fromRGB(60, 165, 255),
	purple = Color3.fromRGB(160, 95, 255),
	pink = Color3.fromRGB(255, 110, 190),
	panel = Color3.fromRGB(255, 245, 225),
	dark = Color3.fromRGB(45, 40, 65),
}

-------------------------------------------------------------------------------------------------------------
-- News (the NEWS window): newest last. `id` counts up; a player who hasn't seen the newest id gets the window
-- once in the lobby. `time` is a UTC unix time, `icon` a UI icon key.
-------------------------------------------------------------------------------------------------------------
Config.NEWS = {
	{
		id = 1,
		title = "Mow And Grow",
		update = "LAUNCH",
		time = 1792324800, -- 18 Oct 2026
		icon = "clover",
		desc = "The lawn has gone wild. Grab your hands and start mowing!",
		bullets = {
			"Cut grass, carry the bundles and shred them for coins",
			"Tools from Bare Hands to the Laser Mower",
			"Ride-on mowers, bags, the Leaf Vacuum and upgrades",
			"Hidden mutations: Golden, Rainbow, Diamond, Toxic and Galaxy",
			"Classes and gem perks that you keep forever",
		},
	},
	{
		id = 2,
		title = "The Big Rebuild",
		update = "UPDATE 1",
		time = 1792504800, -- 20 Oct 2026
		icon = "star",
		desc = "A whole new map, tree-sized grass and a brand new lobby.",
		bullets = {
			"8 fenced areas that open one after another",
			"Grass clumps stand like trees: aim, chop, watch them fall",
			"Bundles land where a clump falls",
			"New Hold upgrade: keep the button down to keep chopping",
			"A second shredder in the middle of the map",
			"New lobby: glowing party pads and a big START A RUN board",
			"New menus, stats and this news board",
		},
	},
}

return Config
