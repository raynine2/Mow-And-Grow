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
Zones.BOUNDS = { minX = -820, maxX = 820, minZ = -820, maxZ = 860 }
Zones.COAST = 770 -- past this distance from the middle it's open sea
Zones.WORLD_CENTER = Vector2.new(14, 54)

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
	radius = 124,
	base = 0,
	amp = 0,
	palette = {
		ground = C(236, 214, 150),
		ground2 = C(224, 198, 128),
		rock = C(150, 140, 120),
		grass = { C(72, 172, 47) },
		rare = C(255, 220, 60),
		accent = C(85, 198, 53),
	},
}

Zones.list = {
	{
		id = "meadow",
		name = "Sunny Meadow",
		center = Vector2.new(30, 338),
		radius = 205,
		base = 4,
		amp = 8,
		freq = 1 / 1.35 / 70,
		price = 0,
		gate = "open", -- from the village: an open slope, no gate
		landmark = { kind = "windmill", at = Vector2.new(94, 405), height = 44 },
		ambient = "pollen",
		grassName = "Meadow Tuft",
		palette = {
			ground = C(69, 175, 46),
			ground2 = C(53, 160, 37),
			rock = C(105, 129, 90),
			grass = { C(71, 191, 39), C(93, 203, 55), C(48, 169, 34) },
			rare = C(255, 214, 40),
			accent = C(84, 202, 53),
		},
		lighting = { clock = 17.4, ambient = C(96, 128, 140), outdoor = C(112, 146, 160), brightness = 2, tint = C(240, 255, 236), saturation = 0.32, contrast = 0.2, fog = C(150, 210, 235), haze = 1, density = 0.3, sunRays = 0.06, bloom = 1.1 },
	},
	{
		id = "wheat",
		name = "Golden Wheat Hills",
		center = Vector2.new(-373, 265),
		radius = 197,
		base = 14,
		amp = 18,
		freq = 1 / 1.35 / 60,
		price = 250,
		gate = "bridge", -- a broken wooden bridge over the Sparkle River gorge
		landmark = { kind = "silo", at = Vector2.new(-432, 230), height = 52 },
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
		lighting = { clock = 18, ambient = C(150, 110, 90), outdoor = C(170, 124, 96), brightness = 2, tint = C(255, 230, 200), saturation = 0.32, contrast = 0.2, fog = C(255, 190, 130), haze = 1.2, density = 0.32, sunRays = 0.1, bloom = 1.1 },
	},
	{
		id = "blossom",
		name = "Blossom Garden",
		center = Vector2.new(-446, -111),
		radius = 189,
		base = 10,
		amp = 12,
		freq = 1 / 1.35 / 55,
		price = 2500,
		gate = "barrier", -- a stone arch closed by a pink magic barrier
		landmark = { kind = "cherry", at = Vector2.new(-486, -135), height = 58 },
		ambient = "petals",
		grassName = "Petal Tuft",
		palette = {
			ground = C(106, 184, 93),
			ground2 = C(255, 196, 222),
			rock = C(190, 160, 170),
			grass = { C(255, 150, 200), C(255, 196, 226), C(255, 255, 255) },
			rare = C(255, 40, 200),
			accent = C(255, 120, 200),
		},
		lighting = { clock = 18.6, ambient = C(150, 104, 150), outdoor = C(170, 118, 170), brightness = 1.9, tint = C(255, 226, 244), saturation = 0.34, contrast = 0.2, fog = C(255, 170, 220), haze = 1, density = 0.3, sunRays = 0.06, bloom = 1.2 },
	},
	{
		id = "pine",
		name = "Misty Pine Forest",
		center = Vector2.new(-256, -429),
		radius = 192,
		base = 2,
		amp = 10,
		freq = 1 / 1.35 / 65,
		price = 15000,
		gate = "rockslide", -- a mountain pass blocked by fallen boulders
		landmark = { kind = "elderpine", at = Vector2.new(-284, -473), height = 84 },
		ambient = "fireflies",
		grassName = "Fern",
		palette = {
			ground = C(46, 129, 100),
			ground2 = C(36, 114, 89),
			rock = C(96, 112, 110),
			grass = { C(56, 160, 125), C(79, 177, 141), C(54, 150, 108) },
			rare = C(133, 219, 89),
			accent = C(64, 189, 144),
		},
		lighting = { clock = 19.8, ambient = C(70, 120, 120), outdoor = C(80, 140, 135), brightness = 1.7, tint = C(210, 250, 236), saturation = 0.3, contrast = 0.22, fog = C(90, 170, 160), haze = 1.6, density = 0.38, sunRays = 0, bloom = 1.2 },
	},
	{
		id = "swamp",
		name = "Bubble Swamp",
		center = Vector2.new(151, -462),
		radius = 197,
		base = -4,
		amp = 4,
		freq = 1 / 1.35 / 40,
		price = 80000,
		gate = "ropebridge", -- a rope bridge over the swamp creek that weaves itself back together
		landmark = { kind = "mushroomhut", at = Vector2.new(189, -513), height = 46 },
		ambient = "bubbles",
		grassName = "Cattail",
		palette = {
			ground = C(78, 126, 45),
			ground2 = C(66, 110, 39),
			rock = C(90, 84, 100),
			grass = { C(107, 155, 49), C(82, 138, 41), C(170, 140, 220) },
			rare = C(200, 120, 255),
			accent = C(180, 120, 255),
		},
		lighting = { clock = 20.2, ambient = C(100, 90, 150), outdoor = C(116, 100, 170), brightness = 1.7, tint = C(226, 236, 214), saturation = 0.32, contrast = 0.22, fog = C(120, 150, 110), haze = 2, density = 0.4, sunRays = 0, bloom = 1.3 },
	},
	{
		id = "frost",
		name = "Frost Peaks",
		center = Vector2.new(470, -213),
		radius = 197,
		base = 24,
		amp = 14,
		freq = 1 / 1.35 / 60,
		price = 400000,
		gate = "icewall", -- a frozen cave entrance; the ice wall melts and shatters
		landmark = { kind = "icespire", at = Vector2.new(513, -256), height = 96 },
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
		lighting = { clock = 20.6, ambient = C(96, 120, 190), outdoor = C(110, 136, 210), brightness = 1.8, tint = C(210, 228, 255), saturation = 0.32, contrast = 0.2, fog = C(110, 150, 255), haze = 1, density = 0.32, sunRays = 0, bloom = 1.2 },
	},
	{
		id = "ember",
		name = "Ember Ash Fields",
		center = Vector2.new(440, 219),
		radius = 197,
		base = 14,
		amp = 10,
		freq = 1 / 1.35 / 55,
		price = 2000000,
		gate = "obsidian", -- an obsidian bridge that rises out of a lava river
		landmark = { kind = "volcano", at = Vector2.new(500, 256), height = 90 },
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
		lighting = { clock = 19.6, ambient = C(150, 80, 70), outdoor = C(170, 90, 76), brightness = 1.8, tint = C(255, 210, 190), saturation = 0.34, contrast = 0.22, fog = C(255, 110, 60), haze = 2, density = 0.38, sunRays = 0, bloom = 1.3 },
	},
	{
		id = "isles",
		name = "Starlight Isles",
		center = Vector2.new(238, 602),
		radius = 167,
		base = 40,
		amp = 6,
		freq = 1 / 1.35 / 40,
		price = 10000000,
		gate = "stones", -- a portal arch; glowing stepping stones rise up to the floating islands
		floating = true,
		landmark = { kind = "floatrock", at = Vector2.new(270, 634), height = 70 },
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
		lighting = { clock = 21.2, ambient = C(120, 96, 180), outdoor = C(140, 112, 200), brightness = 1.9, tint = C(236, 220, 255), saturation = 0.35, contrast = 0.18, fog = C(170, 130, 255), haze = 1, density = 0.3, sunRays = 0, bloom = 1.3 },
	},
}

-- Gate kinds: what blocks the way into a zone until the zone before it is mowed bare (Chop A Forest's rule; `price`
-- above is unused), and how it opens.
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
