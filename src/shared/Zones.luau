-- The world of Mow And Grow: a spawn village in the middle and eight zones spiralling out from it, each a valley
-- of studded voxel terraces ringed by rock, joined to the next by ONE gate (a broken bridge, a magic barrier, a
-- rockslide...). Everything about a zone lives here: where it is, how high, its colours, grass, gate, landmark,
-- price and lighting. server/WorldGen builds the map from this; the game systems read the same table.
--
-- Coordinates are studs, x east and z south (Roblox world space); `center` is a Vector2 (x, z).
-- Adding a zone: add an entry here (and a gate kind for the way in), then rebuild the map.
local Zones = {}

Zones.CELL = 8 -- the voxel grid: one ground column per 8 x 8 studs
Zones.STEP = 2 -- terraces rise in 2-stud steps (a player walks up one without jumping)
Zones.FLOOR = -24 -- bottom of every ground column
Zones.SEA = -6 -- sea and gorge water surface
Zones.BOUNDS = { minX = -600, maxX = 600, minZ = -600, maxZ = 640 }
Zones.COAST = 560 -- past this distance from the middle it's open sea
Zones.WORLD_CENTER = Vector2.new(10, 40)

export type Palette = {
	ground: Color3, -- terrace colour A
	ground2: Color3, -- terrace colour B (every other level)
	rock: Color3, -- the rim of rock around the zone
	grass: { Color3 }, -- 2-3 close shades for the grass sticks
	rare: Color3, -- rare grass glow
	accent: Color3, -- neon trim on the gate and pads (the NEXT zone's colour on a gate)
}

export type Lighting = {
	clock: number, -- ClockTime
	ambient: Color3,
	outdoor: Color3,
	brightness: number,
	tint: Color3, -- ColorCorrection.TintColor
	saturation: number,
	contrast: number,
	fog: Color3, -- Atmosphere.Color
	haze: number, -- Atmosphere.Haze
	density: number, -- Atmosphere.Density
	sunRays: number, -- SunRays.Intensity (0 = off)
	bloom: number, -- Bloom.Intensity
}

local C = Color3.fromRGB

Zones.village = {
	name = "Spawn Village",
	center = Vector2.new(0, 0),
	radius = 92,
	base = 0,
	amp = 0,
	palette = {
		ground = C(236, 214, 150),
		ground2 = C(224, 198, 128),
		rock = C(150, 140, 120),
		grass = { C(120, 200, 70) },
		rare = C(255, 220, 60),
		accent = C(140, 230, 80),
	},
}

Zones.list = {
	{
		id = "meadow",
		name = "Sunny Meadow",
		center = Vector2.new(22, 250),
		radius = 152,
		base = 4,
		amp = 8,
		freq = 1 / 70,
		price = 0,
		gate = "open", -- from the village: an open slope, no gate
		landmark = { kind = "windmill", at = Vector2.new(70, 300), height = 44 },
		ambient = "pollen",
		grassName = "Meadow Tuft",
		palette = {
			ground = C(118, 204, 70),
			ground2 = C(98, 186, 58),
			rock = C(132, 150, 110),
			grass = { C(126, 222, 64), C(150, 236, 82), C(96, 196, 56) },
			rare = C(255, 214, 40),
			accent = C(140, 235, 80),
		},
		lighting = { clock = 14, ambient = C(110, 120, 110), outdoor = C(150, 150, 140), brightness = 3, tint = C(255, 252, 240), saturation = 0.25, contrast = 0.08, fog = C(200, 230, 255), haze = 0.6, density = 0.25, sunRays = 0.12, bloom = 0.7 },
	},
	{
		id = "wheat",
		name = "Golden Wheat Hills",
		center = Vector2.new(-276, 196),
		radius = 146,
		base = 14,
		amp = 18,
		freq = 1 / 60,
		price = 250,
		gate = "bridge", -- a broken wooden bridge over the Sparkle River gorge
		landmark = { kind = "silo", at = Vector2.new(-320, 170), height = 52 },
		ambient = "dust",
		grassName = "Wheat Stalk",
		palette = {
			ground = C(236, 186, 74),
			ground2 = C(222, 166, 58),
			rock = C(170, 130, 90),
			grass = { C(250, 204, 82), C(255, 224, 120), C(226, 168, 54) },
			rare = C(255, 250, 200),
			accent = C(255, 200, 70),
		},
		lighting = { clock = 16.6, ambient = C(130, 110, 90), outdoor = C(170, 140, 110), brightness = 2.8, tint = C(255, 238, 205), saturation = 0.25, contrast = 0.1, fog = C(255, 220, 170), haze = 1.2, density = 0.3, sunRays = 0.15, bloom = 0.75 },
	},
	{
		id = "blossom",
		name = "Blossom Garden",
		center = Vector2.new(-330, -82),
		radius = 140,
		base = 10,
		amp = 12,
		freq = 1 / 55,
		price = 2500,
		gate = "barrier", -- a stone arch closed by a pink magic barrier
		landmark = { kind = "cherry", at = Vector2.new(-360, -100), height = 58 },
		ambient = "petals",
		grassName = "Petal Tuft",
		palette = {
			ground = C(150, 214, 120),
			ground2 = C(255, 196, 222),
			rock = C(190, 160, 170),
			grass = { C(255, 150, 200), C(255, 196, 226), C(255, 255, 255) },
			rare = C(255, 40, 200),
			accent = C(255, 120, 200),
		},
		lighting = { clock = 13, ambient = C(130, 110, 125), outdoor = C(170, 150, 165), brightness = 2.9, tint = C(255, 236, 246), saturation = 0.28, contrast = 0.06, fog = C(255, 214, 236), haze = 0.9, density = 0.28, sunRays = 0.1, bloom = 0.8 },
	},
	{
		id = "pine",
		name = "Misty Pine Forest",
		center = Vector2.new(-190, -318),
		radius = 142,
		base = 2,
		amp = 10,
		freq = 1 / 65,
		price = 15000,
		gate = "rockslide", -- a mountain pass blocked by fallen boulders
		landmark = { kind = "elderpine", at = Vector2.new(-210, -350), height = 84 },
		ambient = "fireflies",
		grassName = "Fern",
		palette = {
			ground = C(64, 150, 104),
			ground2 = C(52, 132, 92),
			rock = C(96, 112, 110),
			grass = { C(78, 186, 130), C(104, 206, 150), C(54, 150, 108) },
			rare = C(190, 255, 120),
			accent = C(90, 220, 150),
		},
		lighting = { clock = 9.5, ambient = C(90, 110, 110), outdoor = C(110, 140, 135), brightness = 2.2, tint = C(225, 248, 240), saturation = 0.18, contrast = 0.1, fog = C(170, 210, 200), haze = 2.2, density = 0.42, sunRays = 0.05, bloom = 0.8 },
	},
	{
		id = "swamp",
		name = "Bubble Swamp",
		center = Vector2.new(112, -342),
		radius = 146,
		base = -4,
		amp = 4,
		freq = 1 / 40,
		price = 80000,
		gate = "ropebridge", -- a rope bridge over the swamp creek that weaves itself back together
		landmark = { kind = "mushroomhut", at = Vector2.new(140, -380), height = 46 },
		ambient = "bubbles",
		grassName = "Cattail",
		palette = {
			ground = C(112, 146, 62),
			ground2 = C(96, 128, 54),
			rock = C(90, 84, 100),
			grass = { C(150, 180, 70), C(120, 160, 60), C(170, 140, 220) },
			rare = C(200, 120, 255),
			accent = C(180, 120, 255),
		},
		lighting = { clock = 18.2, ambient = C(100, 100, 120), outdoor = C(120, 120, 140), brightness = 2.2, tint = C(232, 245, 222), saturation = 0.22, contrast = 0.12, fog = C(160, 190, 140), haze = 2.6, density = 0.45, sunRays = 0, bloom = 0.9 },
	},
	{
		id = "frost",
		name = "Frost Peaks",
		center = Vector2.new(348, -158),
		radius = 146,
		base = 24,
		amp = 14,
		freq = 1 / 60,
		price = 400000,
		gate = "icewall", -- a frozen cave entrance; the ice wall melts and shatters
		landmark = { kind = "icespire", at = Vector2.new(380, -190), height = 96 },
		ambient = "snow",
		grassName = "Frost Crystal",
		palette = {
			ground = C(236, 246, 255),
			ground2 = C(206, 230, 250),
			rock = C(120, 150, 190),
			grass = { C(220, 244, 255), C(170, 220, 255), C(255, 255, 255) },
			rare = C(60, 230, 255),
			accent = C(70, 225, 255),
		},
		lighting = { clock = 20.4, ambient = C(90, 110, 160), outdoor = C(110, 130, 190), brightness = 1.6, tint = C(215, 232, 255), saturation = 0.3, contrast = 0.14, fog = C(150, 180, 255), haze = 1.4, density = 0.35, sunRays = 0, bloom = 1 },
	},
	{
		id = "ember",
		name = "Ember Ash Fields",
		center = Vector2.new(326, 162),
		radius = 146,
		base = 14,
		amp = 10,
		freq = 1 / 55,
		price = 2000000,
		gate = "obsidian", -- an obsidian bridge that rises out of a lava river
		landmark = { kind = "volcano", at = Vector2.new(370, 190), height = 90 },
		ambient = "embers",
		grassName = "Ember Grass",
		palette = {
			ground = C(74, 62, 70),
			ground2 = C(60, 50, 58),
			rock = C(44, 36, 42),
			grass = { C(60, 52, 56), C(255, 120, 50), C(255, 176, 60) },
			rare = C(255, 220, 80),
			accent = C(255, 110, 40),
		},
		lighting = { clock = 18.9, ambient = C(130, 80, 70), outdoor = C(150, 90, 70), brightness = 2, tint = C(255, 220, 200), saturation = 0.3, contrast = 0.15, fog = C(255, 140, 90), haze = 2.4, density = 0.4, sunRays = 0, bloom = 1 },
	},
	{
		id = "isles",
		name = "Starlight Isles",
		center = Vector2.new(176, 446),
		radius = 124,
		base = 40,
		amp = 6,
		freq = 1 / 40,
		price = 10000000,
		gate = "stones", -- a portal arch; glowing stepping stones rise up to the floating islands
		floating = true,
		landmark = { kind = "floatrock", at = Vector2.new(200, 470), height = 70 },
		ambient = "sparkles",
		grassName = "Star Crystal",
		palette = {
			ground = C(150, 120, 255),
			ground2 = C(124, 96, 236),
			rock = C(90, 70, 150),
			grass = { C(190, 150, 255), C(120, 240, 255), C(255, 150, 240) },
			rare = C(255, 255, 255),
			accent = C(190, 120, 255),
		},
		lighting = { clock = 21.5, ambient = C(110, 90, 160), outdoor = C(130, 110, 190), brightness = 1.8, tint = C(236, 222, 255), saturation = 0.32, contrast = 0.12, fog = C(170, 140, 255), haze = 1.2, density = 0.32, sunRays = 0, bloom = 1 },
	},
}

-- Gate kinds: what blocks the way into a zone until it's bought, and how it opens.
--   chasm = true: the way in crosses a gorge (water or lava at the bottom; falling in sends you back)
Zones.GATES = {
	open = { chasm = false, label = "" },
	bridge = { chasm = true, bottom = "water", label = "BROKEN BRIDGE" },
	barrier = { chasm = false, label = "MAGIC BARRIER" },
	rockslide = { chasm = false, label = "ROCKSLIDE" },
	ropebridge = { chasm = true, bottom = "water", label = "ROPE BRIDGE" },
	icewall = { chasm = false, label = "FROZEN CAVE" },
	obsidian = { chasm = true, bottom = "lava", label = "LAVA RIVER" },
	stones = { chasm = true, bottom = "sea", label = "STAR PORTAL" },
}

-- The region (village = 0, zones 1..n) and its def.
function Zones.region(i: number)
	return if i == 0 then Zones.village else Zones.list[i]
end

-- How far `p` is inside region i, as a fraction of its (wobbly) radius: < 1 inside, > 1 outside.
function Zones.normDist(i: number, p: Vector2): number
	local r = Zones.region(i)
	local d = p - r.center
	local a = math.atan2(d.Y, d.X)
	local wob = 1 + 0.11 * math.sin(3 * a + i * 1.7) + 0.06 * math.sin(5 * a + i * 2.9) + 0.04 * math.sin(8 * a + i)
	return d.Magnitude / (r.radius * wob)
end

-- Which region `p` is in (0 = village, 1..n = zone, nil = outside every region), and how deep inside.
function Zones.regionAt(p: Vector2): (number?, number)
	local best, bestD = nil, math.huge
	for i = 0, #Zones.list do
		local d = Zones.normDist(i, p)
		if d < bestD then
			best, bestD = i, d
		end
	end
	if bestD > 1 then
		return nil, bestD
	end
	return best, bestD
end

-- The zone a world position is in (1..n), 0 for the village, nil outside.
function Zones.zoneAt(pos: Vector3): number?
	return (Zones.regionAt(Vector2.new(pos.X, pos.Z)))
end

return Zones
