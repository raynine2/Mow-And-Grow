local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	buf = Instance.new("Folder")
	buf.Name = "ClaudePatchBuf"
	buf.Parent = ss
end
local bad = {}
local function put(name, text, want)
	if hashOf(text) ~= want then
		table.insert(bad, name .. " garbled")
		return
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
end

put("CampDress.1", [====[-- The area camps, remade bigger and alive (owner, 29 Oct: "remake every zone hub except 1 to make it a bit bigger
-- and ... make it feel more alive and not so boring; if ur going to add or make stuff use blender"). server/Outposts
-- lays the paved plaza (now 24 studs round the drop-off pad), the SHOP and UPGRADES stalls, the gas pump and the
-- benches; this dresses it, with the Blender models in server/CampProps (tools/blender/camp):
--   * on the plaza: an entrance arch with the camp's name, a signpost whose arrows point at the boss arena, the next
--     area and the spawn camp, a notice board, a well, a market cart with the area's goods, banners, lamp posts;
--   * round it (on the ground, levelled with a stone footing, stepping stones from the plaza): a house with smoke
--     from its chimney, a camp corner with two tents and a fire, the area's own landmark and its animals:
--       Golden Wheat Hills: windmill, chicken run, scarecrow, hay; Blossom Garden: pavilion with paper lanterns, koi
--       pond; Misty Pine Forest: watchtower, owls, log pile; Bubble Swamp: the house on stilts, a pond with a jetty,
--       a rowing boat and frogs; Frost Peaks: igloo, snowman, penguins, snow on the roofs; Ember Ash Fields: forge
--       with bellows, embers and lava, fire salamanders; Starlight Isles: telescope, floating crystals, wisps;
--   * people: gnome villagers, two by the stalls, one walking round, one by the fire, one at work by the landmark;
--   * the air: the area's drifting pollen / petals / mist / fireflies / snow / embers / sparkles.
-- Everything is decoration (only the buildings collide). What moves is tagged for client/CampLife, which animates it
-- near you (windmill sails, banners, the telescope, critters, villagers who look at you, wave and talk).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local FxIds = require(ReplicatedStorage.MowALawn.FxIds) :: { [string]: string }
local CampProps = require(script.Parent.CampProps)
local VoxelKit = require(script.Parent.VoxelKit)

local CampDress = {}

CampDress.RADIUS = 36 -- the whole camp: no grass grows inside (World attribute HubR<z>, RunWorld.patches)

local part = VoxelKit.part
local C = VoxelKit.C
local UP = Vector3.yAxis

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-------------------------------------------------------------------------------------------------------------
-- each area's colours for the models' "@roles" (server/CampProps): { material or nil, colour }; false = left out
-------------------------------------------------------------------------------------------------------------
local BASE_ROLES = {
	trim = { nil, rgb(236, 228, 214) },
	roof = { "VRoof", rgb(110, 74, 56) },
	roof2 = { "VRoof", rgb(86, 56, 42) },
	base = { nil, rgb(230, 222, 205) },
	stone = { nil, rgb(200, 196, 188) },
	door = { nil, rgb(120, 70, 40) },
	glass = { "Glass", rgb(190, 220, 240) },
	board = { nil, rgb(196, 140, 88) },
	wood = { nil, rgb(176, 124, 78) },
	skin = { nil, rgb(255, 204, 170) },
	beard = { nil, rgb(244, 240, 232) },
	tower = { "Plaster", rgb(244, 238, 226) },
	post = { nil, rgb(200, 50, 60) },
	sail = { nil, rgb(246, 240, 226) },
	water = { nil, rgb(70, 150, 200) },
	scope = { nil, rgb(44, 48, 96) },
	snowcap = false,
}
local AREA_ROLES: { [string]: { [string]: any } } = {
	wheat = {
		wall = { "WoodPlanks", rgb(178, 62, 48) }, cloth = { nil, rgb(226, 128, 44) }, accent = { nil, rgb(250, 206, 60) },
		goods1 = { nil, rgb(232, 196, 90) }, goods2 = { nil, rgb(236, 128, 34) }, flower = { nil, rgb(250, 200, 60) },
		coat = { nil, rgb(200, 64, 52) }, pants = { nil, rgb(64, 96, 166) }, hat = { nil, rgb(226, 190, 110) },
	},
	blossom = {
		wall = { "Plaster", rgb(248, 242, 238) }, trim = { nil, rgb(150, 92, 76) }, roof = { "ClayRoofTiles", rgb(226, 112, 152) },
		roof2 = { "ClayRoofTiles", rgb(190, 84, 120) }, base = { nil, rgb(236, 220, 216) }, door = { nil, rgb(176, 70, 92) },
		glass = { "Glass", rgb(255, 222, 236) }, cloth = { nil, rgb(240, 120, 170) }, accent = { nil, rgb(255, 250, 250) },
		goods1 = { nil, rgb(255, 150, 200) }, goods2 = { nil, rgb(255, 250, 244) }, flower = { nil, rgb(255, 140, 190) },
		coat = { nil, rgb(236, 136, 178) }, pants = { nil, rgb(120, 80, 110) }, hat = { nil, rgb(232, 210, 150) },
		board = { nil, rgb(150, 92, 76) },
	},
	pine = {
		wall = { "VLog", rgb(170, 132, 104) }, trim = { nil, rgb(92, 66, 48) }, roof = { "VRoof", rgb(74, 112, 74) },
		roof2 = { "VRoof", rgb(56, 88, 58) }, base = { nil, rgb(196, 198, 192) }, door = { nil, rgb(96, 64, 44) },
		glass = { "Neon", rgb(255, 214, 150) }, cloth = { nil, rgb(64, 124, 84) }, accent = { nil, rgb(200, 64, 52) },
		goods1 = { nil, rgb(150, 105, 70) }, goods2 = { nil, rgb(96, 146, 76) }, flower = { nil, rgb(186, 130, 226) },
		coat = { nil, rgb(190, 54, 44) }, pants = { nil, rgb(76, 64, 54) }, hat = { nil, rgb(190, 54, 44) },
		beard = { nil, rgb(132, 88, 56) }, wood = { nil, rgb(150, 110, 80) },
	},
	swamp = {
		wall = { "WoodPlanks", rgb(130, 112, 82) }, trim = { nil, rgb(82, 66, 48) }, roof = { "Fabric", rgb(160, 140, 80) },
		roof2 = { "Fabric", rgb(130, 112, 62) }, base = { nil, rgb(146, 146, 126) }, stone = { nil, rgb(150, 150, 130) },
		door = { nil, rgb(92, 72, 52) }, glass = { "Neon", rgb(196, 255, 150) }, cloth = { nil, rgb(112, 142, 62) },
		accent = { nil, rgb(176, 255, 146) }, board = { nil, rgb(112, 92, 62) }, goods1 = { nil, rgb(204, 64, 64) },
		goods2 = { nil, rgb(152, 92, 204) }, flower = { nil, rgb(190, 120, 255) }, coat = { nil, rgb(240, 200, 44) },
		pants = { nil, rgb(64, 84, 64) }, hat = { nil, rgb(240, 200, 44) }, beard = { nil, rgb(206, 206, 196) },
		wood = { nil, rgb(132, 104, 74) }, water = { nil, rgb(74, 110, 80) },
	},
	frost = {
		wall = { "VLog", rgb(232, 216, 192) }, trim = { nil, rgb(104, 74, 54) }, roof = { "VRoof", rgb(94, 106, 128) },
		roof2 = { "VRoof", rgb(74, 84, 104) }, base = { nil, rgb(214, 226, 240) }, stone = { nil, rgb(206, 218, 232) },
		door = { nil, rgb(72, 112, 172) }, glass = { "Neon", rgb(255, 222, 156) }, cloth = { nil, rgb(72, 132, 212) },
		accent = { nil, rgb(255, 255, 255) }, board = { nil, rgb(124, 92, 72) }, goods1 = { "Ice", rgb(170, 220, 255) },
		goods2 = { nil, rgb(240, 245, 250) }, flower = { nil, rgb(150, 200, 255) }, coat = { nil, rgb(62, 112, 192) },
		pants = { nil, rgb(52, 62, 84) }, hat = { nil, rgb(232, 232, 242) }, snowcap = { "Snow", rgb(246, 250, 255) },
		water = { nil, rgb(120, 180, 230) },
	},
	ember = {
		wall = { "VStone", rgb(118, 106, 104) }, trim = { nil, rgb(64, 44, 34) }, roof = { "VMetal", rgb(96, 86, 86) },
		roof2 = { "VMetal", rgb(70, 62, 62) }, base = { "Basalt", rgb(78, 70, 72) }, stone = { nil, rgb(110, 100, 100) },
		door = { nil, rgb(112, 52, 32) }, glass = { "Neon", rgb(255, 150, 70) }, cloth = { nil, rgb(204, 72, 42) },
		accent = { nil, rgb(255, 156, 72) }, board = { nil, rgb(92, 62, 42) }, goods1 = { "Neon", rgb(255, 122, 42) },
		goods2 = { nil, rgb(82, 78, 80) }, flower = { "Neon", rgb(255, 102, 42) }, coat = { nil, rgb(122, 72, 42) },
		pants = { nil, rgb(62, 52, 52) }, hat = { nil, rgb(64, 54, 54) }, beard = { nil, rgb(92, 62, 42) },
		wood = { nil, rgb(120, 90, 66) }, water = { nil, rgb(60, 96, 120) },
	},
	isles = {
		wall = { "Plaster", rgb(222, 212, 250) }, trim = { nil, rgb(232, 192, 92) }, roof = { "ClayRoofTiles", rgb(84, 64, 166) },
		roof2 = { "ClayRoofTiles", rgb(64, 48, 132) }, base = { nil, rgb(184, 174, 224) }, stone = { nil, rgb(170, 160, 214) },
		door = { nil, rgb(92, 62, 152) }, glass = { "Neon", rgb(150, 230, 255) }, cloth = { nil, rgb(112, 82, 222) },
		accent = { nil, rgb(255, 222, 122) }, board = { nil, rgb(92, 72, 142) }, goods1 = { "Neon", rgb(150, 230, 255) },
		goods2 = { nil, rgb(202, 162, 255) }, flower = { "Neon", rgb(150, 230, 255) }, coat = { nil, rgb(72, 52, 152) },
		pants = { nil, rgb(52, 42, 92) }, hat = { nil, rgb(72, 52, 152) }, scope = { nil, rgb(52, 46, 120) },
	},
}

local function rolesFor(id: string): { [string]: any }
	local r = table.clone(BASE_ROLES)
	for k, v in AREA_ROLES[id] or AREA_ROLES.wheat do
		r[k] = v
	end
	return r
end

-- a few villagers' outfits per area (coat, pants, hat): the first is the area's own
local OUTFITS: { [string]: { { Color3 } } } = {
	wheat = { { rgb(84, 140, 196), rgb(150, 110, 70), rgb(226, 190, 110) }, { rgb(236, 220, 160), rgb(64, 96, 166), rgb(200, 64, 52) } },
	blossom = { { rgb(255, 250, 244), rgb(176, 70, 92), rgb(240, 120, 170) }, { rgb(150, 200, 120), rgb(120, 80, 110), rgb(255, 196, 220) } },
	pine = { { rgb(64, 124, 84), rgb(76, 64, 54), rgb(236, 220, 160) }, { rgb(150, 110, 80), rgb(64, 84, 64), rgb(64, 124, 84) } },
	swamp = { { rgb(112, 142, 62), rgb(92, 72, 52), rgb(152, 92, 204) }, { rgb(204, 64, 64), rgb(64, 84, 64), rgb(240, 200, 44) } },
]====], "8987 1927689954")
return "part 5/13 (CampDress.1): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
