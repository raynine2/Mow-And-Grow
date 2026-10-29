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

put("CampProps.1", [====[-- The area camps' models (owner, 29 Oct: "remake every zone hub except 1 ... if ur going to add or make stuff use
-- blender"), made in Blender: tools/blender/camp/models.py, written here by tools/blender/camp/build.py (Blender's
-- Python, bpy). Every shape is one native part (Block, Wedge, Cylinder, Ball), so nothing needs uploading.
-- DON'T EDIT THE DATA BY HAND: change models.py and run build.py (the rest of this file is its template,
-- tools/blender/camp/CampProps.template.luau).
--
-- A model's text: "m" lists its materials ("<Kind>__<RRGGBB or @role>[__T<percent>]"; Kind "Mark" is an invisible
-- marker part named after it, e.g. Smoke, Lamp, SignFace), "g name x y z" its groups (parts client/CampLife moves:
-- a windmill's sails, a gnome's arms; the pivot in the model's own studs), then one line per part: shape (b block,
-- w wedge, c cylinder, s ball; upper case when turned), size x y z, position x y z, [turn x y z in degrees,
-- CFrame.fromOrientation], material number, [group number]. The model's front faces -Z (the CFrame's LookVector).
local MaterialService = game:GetService("MaterialService")

local CampProps = {}

-- A theme's role: { kind (a material name, or nil to keep the model's), colour }.
export type Roles = { [string]: { any } }
export type PlaceOpts = { scale: number?, roles: Roles?, collide: boolean?, name: string?, atomic: boolean? }

-- the world's voxel textures (server/VoxelKit): MaterialVariants in the place; plain materials without them
local VOXEL: { [string]: { any } } = {
	VLog = { "MowVoxelLog", Enum.Material.Wood },
	VStone = { "MowVoxelStone1", Enum.Material.Cobblestone },
	VPlank = { "MowVoxelPlanks", Enum.Material.WoodPlanks },
	VRoof = { "MowVoxelRoof", Enum.Material.RoofShingles },
	VMetal = { "MowVoxelMetal3", Enum.Material.CorrodedMetal },
}
local hasVariant: { [string]: boolean } = {}
local function variant(name: string): boolean
	if hasVariant[name] == nil then
		hasVariant[name] = MaterialService:FindFirstChild(name, true) ~= nil
	end
	return hasVariant[name]
end

local DATA: { [string]: string } = {
	camp_arch = [=[
m VStone__@base VLog__@wood Mark__Lamp VRoof__@roof VRoof__@roof2 Metal__3A3838 VPlank__@board WoodPlanks__@trim Mark__SignFace Fabric__@cloth Fabric__@accent
g BanL -8 10.2 0
g BanR 8 10.2 0
b 2.5 1.6 2.5 -6.6 .8 0 1
b 1.5 9.8 1.5 -6.6 6.5 0 2
B .7 .7 3.47 -5.3 8.15 0 41.5 -90 0 2
b .4 .4 .4 -6.6 6.2 -1.25 3
b 2.5 1.6 2.5 6.6 .8 0 1
b 1.5 9.8 1.5 6.6 6.5 0 2
B .7 .7 3.47 5.3 8.15 0 41.5 90 0 2
b .4 .4 .4 6.6 6.2 -1.25 3
b 17.2 1.4 1.4 0 10.9 0 2
b 13.2 1 1 0 9.4 0 2
B 18 .45 2.05 0 12.13 -.88 -45 0 0 4
B 18 .45 2.05 0 12.13 .88 45 0 0 4
b 18.25 .5 1 0 13.29 0 5
b .14 .8 .14 -3.4 8.55 0 6
b .14 .8 .14 3.4 8.55 0 6
b 8.6 2.2 .4 0 7.1 0 7
b 9 2.6 .3 0 7.1 .02 8
b 8.2 1.8 .46 0 7.1 0 9
b 1.7 3.8 .14 -8 8.3 0 10 1
b 1.7 .4 .16 -8 9.7 0 11 1
B .75 .75 .16 -8 8 0 0 0 -45 11 1
W .14 .7 .85 -8.43 6.05 0 90 90 0 10 1
W .14 .7 .85 -7.57 6.05 0 90 -90 0 10 1
b 1.7 3.8 .14 8 8.3 0 10 2
b 1.7 .4 .16 8 9.7 0 11 2
B .75 .75 .16 8 8 0 0 0 -45 11 2
W .14 .7 .85 7.57 6.05 0 90 90 0 10 2
W .14 .7 .85 8.43 6.05 0 90 -90 0 10 2
]=],
	camp_banner = [=[
m VStone__@base VLog__@wood Metal__E6BE5A Fabric__@cloth Fabric__@accent
g Cloth 0 9.4 -.3
b 1.3 .5 1.3 0 .25 0 1
C 9.6 .48 .48 0 5.3 0 0 180 90 2
s .84 .84 .84 0 10.4 0 3
C 2.9 .26 .26 0 9.45 -.3 0 180 180 2
b 2.5 4.4 .12 0 7.2 -.32 4 1
b 2.5 .45 .14 0 8.85 -.33 5 1
B 1.05 1.05 .14 0 7.3 -.34 0 0 -45 5 1
W .12 .9 1.25 -.62 4.55 -.32 90 90 0 4 1
W .12 .9 1.25 .62 4.55 -.32 90 -90 0 4 1
]=],
	camp_boat = [=[
m WoodPlanks__@wood WoodPlanks__@accent Wood__503A28 Wood__AA8056
b 2 .3 5 0 .15 .3 1
B .28 1.1 5.4 -1.2 .7 .4 0 0 14 1
B .3 .25 5.42 -1.28 1.05 .4 0 0 14 2
B .3 1.1 1.88 -.62 .77 -2.9 4.6 -41.8 0 1
B .28 1.1 5.4 1.2 .7 .4 0 0 -14 1
B .3 .25 5.42 1.28 1.05 .4 0 0 -14 2
B .3 1.1 1.88 .62 .77 -2.9 4.6 41.8 0 1
b 2.7 1.1 .3 0 .7 3.05 1
b 2.4 .2 .6 0 .95 1.6 3
b 2.4 .2 .6 0 .95 -.8 3
C 3.81 .18 .18 -.5 1.08 .1 -87.7 177 -90 4
B .12 .5 1.1 -.38 1 -2.1 0 0 -90 4
C 3.81 .18 .18 .5 1.08 .1 -87.7 -177 -90 4
B .12 .5 1.1 .38 1 -2.1 0 0 -90 4
]=],
	camp_cart = [=[
m VPlank__@wood Wood__5A3E2C Metal__3C3A38 Fabric__@cloth Fabric__F0E8D6 SmoothPlastic__@goods1 SmoothPlastic__@goods2
b 3.6 .4 6 0 2 0 1
b .3 1.2 6 -1.95 2.7 0 1
C .35 2.9 2.9 -2.3 1.45 .8 0 180 180 2
C .55 .84 .84 -2.42 1.45 .8 0 180 180 3
B .3 .3 3.46 -1.05 1.5 -4.65 -16.8 -5.2 0 2
b .25 3.6 .25 -1.75 4.1 2.75 2
b .25 3 .25 -1.75 3.8 -2.75 2
b .3 1.2 6 1.95 2.7 0 1
C .35 2.9 2.9 2.3 1.45 .8 0 180 180 2
C .55 .84 .84 2.42 1.45 .8 0 180 180 3
B .3 .3 3.46 1.05 1.5 -4.65 -16.8 5.2 0 2
b .25 3.6 .25 1.75 4.1 2.75 2
b .25 3 .25 1.75 3.8 -2.75 2
b 3.9 1.2 .3 0 2.7 3.1 1
b 3.9 .8 .3 0 2.5 -3.1 1
C 4.4 .3 .3 0 1.45 .8 -90 0 0 3
b .4 1.9 .4 0 .95 -2.5 2
b 2.2 .3 .3 0 1 -6.3 2
B 4.4 .25 6.6 0 5.9 0 -5 0 0 4
B 4.42 .27 1.1 0 5.76 1.6 -5 0 0 5
B 4.42 .27 1.1 0 6.04 -1.6 -5 0 0 5
B 1.2 1.08 1.2 -.8 2.8 1.8 0 -20 0 6
B 1.1 .99 1.1 .8 2.75 1.9 0 3 0 7
B 1 .9 1 -.7 2.7 0 0 -14 0 7
B 1.15 1.03 1.15 .85 2.78 -.2 0 9 0 6
B 1 .9 1 0 2.7 -1.8 0 -8 0 6
B .9 .81 .9 -.1 3.6 1 0 15 0 6
]=],
	camp_forge = [=[
m VStone__@stone SmoothPlastic__1E1816 Neon__FF7828 Mark__Embers Mark__Smoke Leather__6E462C Metal__343234 VLog__@wood VPlank__@wood Glass__3C6078__T10 VMetal__@roof
g Bellows -3.3 1 0
b 6 3 4 0 1.5 0 1
b 2.8 1.5 .3 0 1.7 -2.05 2
b 2.4 .5 .34 0 1.15 -2.08 3
b 1 .4 .4 0 1.6 -1.6 4
b 5 1.6 3.6 0 3.8 0 1
b 3.6 1.4 2.6 0 5.3 0 1
b 2.2 7 2.2 0 9.5 0 1
b 2.8 .5 2.8 0 13.2 0 1
b .5 .5 .5 0 13.9 0 5
W 1.4 .5 2 -3.9 1.25 0 0 90 0 6 1
W 1.4 .5 2 -3.9 .75 0 0 -90 180 6 1
C .4 .36 .36 -3.1 1 0 -90 0 0 7
C 1.6 1.9 1.9 3.4 .8 -3.4 0 180 90 8
b .9 .45 .7 3.4 1.82 -3.4 7
b 1.9 .6 .85 3.4 2.35 -3.4 7
W .85 .45 .6 4.75 2.42 -3.4 0 -90 0 7
b 2.8 1 1.3 -3.4 .5 -3.4 9
b 2.4 .12 .9 -3.4 .98 -3.4 10
b 8.4 .3 .9 0 .15 3 3
b 8.6 .5 .35 0 .25 3.6 1
b 8.6 .5 .35 0 .25 2.4 1
b .35 3.4 .35 5.6 1.7 1.3 8
b .35 3.4 .35 5.6 1.7 -1.3 8
b .3 .3 3 5.6 3 0 8
b .16 1.6 .16 5.75 2.1 .8 8
b .5 .32 .3 5.75 1.3 .8 7
b .16 1.6 .16 5.75 2.1 0 8
b .5 .32 .3 5.75 1.3 0 7
b .16 1.6 .16 5.75 2.1 -.8 8
b .5 .32 .3 5.75 1.3 -.8 7
b .5 6 .5 .6 3 -5.2 8
b .5 6 .5 5.4 3 -5.2 8
B 6.6 .35 3.6 3 6 -4.1 16 0 0 11
]=],
	camp_gnome = [=[
m Fabric__@pants Leather__3E2C22 Fabric__@coat Leather__34261E Metal__F0C85A SmoothPlastic__@skin Mark__Hand SmoothPlastic__F09682 SmoothPlastic__191618 SmoothPlastic__@beard Fabric__@hat
g legL -.36 1.15 0
g legR .36 1.15 0
g armL -.98 2.3 0
g armR .98 2.3 0
g Head 0 2.45 0
b .56 .85 .6 -.36 .78 0 1 1
b .66 .42 .98 -.36 .21 -.13 2 1
b .56 .85 .6 .36 .78 0 1 2
b .66 .42 .98 .36 .21 -.13 2 2
b 1.6 1.3 1.15 0 1.8 0 3
b 1.66 .26 1.21 0 1.36 0 4
b .42 .32 .12 0 1.36 -.63 5
b .46 1.05 .52 -1.02 1.85 0 3 3
s .58 .58 .58 -1.02 1.2 -.06 6 3
b .46 1.05 .52 1.02 1.85 0 3 4
s .58 .58 .58 1.02 1.2 -.06 6 4
b .2 .2 .2 1.02 1.1 -.1 7 4
b 1.15 .95 1.05 0 2.92 0 6 5
s .46 .46 .46 0 2.85 -.6 8 5
b .15 .2 .06 -.27 3.08 -.54 9 5
b .15 .2 .06 .27 3.08 -.54 9 5
b 1.22 .85 .55 0 2.38 -.42 10 5
b .8 .45 .45 0 1.88 -.48 10 5
C .2 1.48 1.48 0 3.47 0 0 180 90 11 5
C .42 1.24 1.24 0 3.76 0 0 180 90 11 5
C .42 1.01 1.01 0 4.19 0 0 180 90 11 5
C .42 .78 .78 0 4.61 0 0 180 90 11 5
C .42 .55 .55 0 5.04 0 0 180 90 11 5
s .34 .34 .34 0 5.3 0 11 5
]=],
	camp_house = [=[
m VStone__@base VPlank__@wall WoodPlanks__@trim VRoof__@roof VRoof__@roof2 Glass__@glass WoodPlanks__@door Metal__E6BE5A VStone__@stone WoodPlanks__@accent LeafyGrass__508C3C SmoothPlastic__@flower SmoothPlastic__28221E Mark__Smoke Mark__Lamp VLog__@wood
b 14.2 1 11.2 0 .5 0 1
b 13 7 .8 0 4.5 -4.6 2
b 13 7 .8 0 4.5 4.6 2
b .8 7 8.4 -6.1 4.5 0 2
b .8 7 8.4 6.1 4.5 0 2
b 1.1 7.2 1.1 -6.2 4.6 4.7 3
b 1.1 7.2 1.1 -6.2 4.6 -4.7 3
b 1.1 7.2 1.1 6.2 4.6 4.7 3
b 1.1 7.2 1.1 6.2 4.6 -4.7 3
b 13.3 .5 .3 0 1.25 -5.05 3
b 13.3 .5 .3 0 1.25 5.05 3
b .3 .5 10.3 -6.55 1.25 0 3
b .3 .5 10.3 6.55 1.25 0 3
b 13.3 .5 .3 0 7.75 -5.05 3
b 13.3 .5 .3 0 7.75 5.05 3
b .3 .5 10.3 -6.55 7.75 0 3
b .3 .5 10.3 6.55 7.75 0 3
B 14.8 .55 8.32 0 10.12 -3.19 -43.8 0 0 4
B 14.9 .16 .45 0 8.87 -5.01 -43.8 0 0 5
B 14.9 .16 .45 0 10.24 -3.58 -43.8 0 0 5
B 14.9 .16 .45 0 11.61 -2.15 -43.8 0 0 5
B 14.8 .55 8.32 0 10.12 3.19 43.8 0 0 4
B 14.9 .16 .45 0 8.87 5.01 43.8 0 0 5
B 14.9 .16 .45 0 10.24 3.58 43.8 0 0 5
B 14.9 .16 .45 0 11.61 2.15 43.8 0 0 5
b 15.05 .5 1 0 13.51 0 5
w .8 4.8 5 -6.1 10.4 -2.5 2
W .8 4.8 5 -6.1 10.4 2.5 0 -180 0 2
b .3 1.7 1.7 -6.45 9.7 0 3
b .25 1.15 1.15 -6.55 9.7 0 6
w .8 4.8 5 6.1 10.4 -2.5 2
W .8 4.8 5 6.1 10.4 2.5 0 -180 0 2
b .3 1.7 1.7 6.45 9.7 0 3
b .25 1.15 1.15 6.55 9.7 0 6
b 3.4 5.7 .5 0 3.85 -5.05 3
b 2.6 5.1 .4 0 3.55 -5.2 7
b .14 5.1 .42 -.45 3.55 -5.22 3
b .14 5.1 .42 .45 3.55 -5.22 3
s .4 .4 .4 .85 3.5 -5.45 8
b 4.2 .5 1.5 0 .75 -6 9
B 4.8 .35 2.6 0 7.25 -6.25 -18 0 0 4
B .3 .3 2.17 -2 6.43 -5.95 28.9 0 0 3
B .3 .3 2.17 2 6.43 -5.95 28.9 0 0 3
b 2.8 3 .25 -3.95 4.9 -5.12 3
b 2.2 2.4 .2 -3.95 4.9 -5.22 6
b .18 2.4 .22 -3.95 4.9 -5.32 3
b 2.2 .18 .22 -3.95 5 -5.32 3
b 3.1 .25 .6 -3.95 3.58 -5.32 3
]====], "8997 1255004561")
return "part 1/13 (CampProps.1): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
