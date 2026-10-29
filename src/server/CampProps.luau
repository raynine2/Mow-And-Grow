-- The area camps' models (owner, 29 Oct: "remake every zone hub except 1 ... if ur going to add or make stuff use
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
b .9 2.55 .2 -2.23 4.9 -5.18 10
b .9 2.55 .2 -5.67 4.9 -5.18 10
b 2.5 .6 .75 -3.95 3.08 -5.62 3
b 2.3 .22 .6 -3.95 3.46 -5.62 11
b .45 .42 .45 -3.22 3.68 -5.62 12
b .45 .42 .45 -3.95 3.68 -5.62 12
b .45 .42 .45 -4.68 3.68 -5.62 12
b 2.8 3 .25 3.95 4.9 -5.12 3
b 2.2 2.4 .2 3.95 4.9 -5.22 6
b .18 2.4 .22 3.95 4.9 -5.32 3
b 2.2 .18 .22 3.95 5 -5.32 3
b 3.1 .25 .6 3.95 3.58 -5.32 3
b .9 2.55 .2 5.67 4.9 -5.18 10
b .9 2.55 .2 2.23 4.9 -5.18 10
b 2.5 .6 .75 3.95 3.08 -5.62 3
b 2.3 .22 .6 3.95 3.46 -5.62 11
b .45 .42 .45 4.68 3.68 -5.62 12
b .45 .42 .45 3.95 3.68 -5.62 12
b .45 .42 .45 3.22 3.68 -5.62 12
b .25 2.8 2.6 -6.62 4.9 -.6 3
b .2 2.2 2 -6.72 4.9 -.6 6
b .22 2.2 .18 -6.82 4.9 -.6 3
b .22 .18 2 -6.82 5 -.6 3
b .6 .25 2.9 -6.82 3.68 -.6 3
b .2 2.35 .9 -6.68 4.9 -2.22 10
b .2 2.35 .9 -6.68 4.9 1.02 10
b .25 2.8 2.6 6.62 4.9 -.6 3
b .2 2.2 2 6.72 4.9 -.6 6
b .22 2.2 .18 6.82 4.9 -.6 3
b .22 .18 2 6.82 5 -.6 3
b .6 .25 2.9 6.82 3.68 -.6 3
b .2 2.35 .9 6.68 4.9 1.02 10
b .2 2.35 .9 6.68 4.9 -2.22 10
b 2.6 2.8 .25 2.5 4.9 5.12 3
b 2 2.2 .2 2.5 4.9 5.22 6
b .18 2.2 .22 2.5 4.9 5.32 3
b 2 .18 .22 2.5 5 5.32 3
b 2.9 .25 .6 2.5 3.68 5.32 3
b .9 2.35 .2 .88 4.9 5.18 10
b .9 2.35 .2 4.12 4.9 5.18 10
b 1.9 7.2 1.9 -4.1 10.4 2.8 9
b 2.4 .5 2.4 -4.1 14.1 2.8 9
b 1.2 .12 1.2 -4.1 14.36 2.8 13
b .5 .5 .5 -4.1 14.8 2.8 14
b .4 .4 .4 2.55 5.9 -5.7 15
C 3.2 .9 .9 7.6 .45 1.5 -90 -90 0 16
C 3.2 .9 .9 7.6 .45 .55 -90 -90 0 16
C 3.2 .9 .9 7.6 .45 -.4 -90 -90 0 16
C 3.2 .9 .9 7.6 1.3 1 -90 -90 0 16
C 3.2 .9 .9 7.6 1.3 .05 -90 -90 0 16
C 3.2 .9 .9 7.6 2.1 .55 -90 -90 0 16
b 3 .3 .9 -4 1.45 -6.3 3
b .3 1.3 .8 -5.2 .65 -6.3 3
b .3 1.3 .8 -2.8 .65 -6.3 3
]=],
	camp_igloo = [=[
m Snow__F0F6FC Snow__D6E2F0 SmoothPlastic__222E46 Ice__@goods1
s 9.2 9.2 9.2 0 .3 0 1
C .2 9 9 0 1.45 0 0 180 90 2
C .2 7.44 7.44 0 3 0 0 180 90 2
C 3.2 3.2 3.2 0 .55 -4.3 -90 -90 0 1
C .2 2.3 2.3 0 .55 -5.92 -90 -90 0 3
C .5 1 1 0 4.95 0 0 180 90 2
b 1.3 .85 1 3.6 .42 -3.4 4
B 1.17 .77 .9 4.4 .38 -2.4 0 25 0 4
B 1.04 .68 .8 4 1.14 -2.9 0 50 0 4
]=],
	camp_noticeboard = [=[
m VLog__@wood VPlank__@board WoodPlanks__@trim VRoof__@roof VRoof__@roof2 SmoothPlastic__FAF6E6 SmoothPlastic__DC3228 SmoothPlastic__FFEC96 SmoothPlastic__FFCDDC SmoothPlastic__C8E6FF
b .6 6 .6 -2.45 3 0 1
b .6 6 .6 2.45 3 0 1
b 4.4 3 .35 0 3.9 0 2
b 4.8 .3 .45 0 5.5 0 3
b 4.8 .3 .45 0 2.3 0 3
B 6 .35 1.59 0 6.32 -.66 -48.8 0 0 4
B 6 .35 1.59 0 6.32 .66 48.8 0 0 4
b 6.25 .5 1 0 7.28 0 5
B 1.05 1.25 .06 -1.35 4.5 -.21 0 0 -6 6
b .16 .16 .12 -1.35 5 -.27 7
B 1.05 1.25 .06 .1 4.7 -.21 0 0 4 8
b .16 .16 .12 .1 5.2 -.27 7
B 1.05 1.25 .06 1.4 4.4 -.21 0 0 -8 9
b .16 .16 .12 1.4 4.9 -.27 7
B 1.05 1.25 .06 -.7 3.2 -.21 0 0 7 10
b .16 .16 .12 -.7 3.7 -.27 7
B 1.05 1.25 .06 .9 3.1 -.21 0 0 -3 6
b .16 .16 .12 .9 3.6 -.27 7
]=],
	camp_pavilion = [=[
m VStone__@base VPlank__@wood SmoothPlastic__@post Mark__Lamp WoodPlanks__@trim ClayRoofTiles__@roof VRoof__@roof2 Metal__E6BE5A
b 10.4 1.2 10.4 0 .6 0 1
b 9.6 .3 9.6 0 1.35 0 2
b 3.6 .6 1.3 0 .3 -5.8 1
b 3.6 .6 .9 0 .9 -5.55 1
b 1.2 .5 1.2 -3.9 1.75 3.9 1
b .8 6.4 .8 -3.9 4.7 3.9 3
b .3 .3 .3 -3.2 7 3.2 4
b 1.2 .5 1.2 -3.9 1.75 -3.9 1
b .8 6.4 .8 -3.9 4.7 -3.9 3
b .3 .3 .3 -3.2 7 -3.2 4
b 1.2 .5 1.2 3.9 1.75 3.9 1
b .8 6.4 .8 3.9 4.7 3.9 3
b .3 .3 .3 3.2 7 3.2 4
b 1.2 .5 1.2 3.9 1.75 -3.9 1
b .8 6.4 .8 3.9 4.7 -3.9 3
b .3 .3 .3 3.2 7 -3.2 4
b 8.6 .6 .6 0 8 -3.9 3
b 8.6 .6 .6 3.9 8 0 3
b 7 .3 .3 3.9 3.6 0 5
b 7 .25 .3 3.9 2.6 0 5
b 8.6 .6 .6 0 8 3.9 3
b 7 .3 .3 0 3.6 3.9 5
b 7 .25 .3 0 2.6 3.9 5
b 8.6 .6 .6 -3.9 8 0 3
b 7 .3 .3 -3.9 3.6 0 5
b 7 .25 .3 -3.9 2.6 0 5
b 12.4 .5 12.4 0 8.55 0 6
b 12.7 .25 12.7 0 8.42 0 7
b 10.27 .5 10.27 0 9.05 0 6
b 8.13 .5 8.13 0 9.55 0 6
b 6 .5 6 0 10.05 0 6
B 1.2 .45 1.2 -5.9 9 5.9 0 45 0 6
B 1.2 .45 1.2 -5.9 9 -5.9 0 45 0 6
B 1.2 .45 1.2 5.9 9 5.9 0 45 0 6
B 1.2 .45 1.2 5.9 9 -5.9 0 45 0 6
b 4.2 .9 4.2 0 10.6 0 3
b 6.4 .48 6.4 0 11.24 0 6
b 6.7 .25 6.7 0 11.12 0 7
b 4.87 .48 4.87 0 11.71 0 6
b 3.33 .48 3.33 0 12.19 0 6
b 1.8 .48 1.8 0 12.66 0 6
C 1.4 .44 .44 0 13.4 0 0 180 90 8
s .76 .76 .76 0 14.2 0 8
]=],
	camp_scarecrow = [=[
m VLog__@wood Fabric__7896BE Fabric__C8503C Fabric__E8C45A Fabric__D6B88C SmoothPlastic__1E1A18 Fabric__8C643C
b .5 6.6 .5 0 3.3 0 1
b 4.8 .42 .42 0 4.7 0 1
b 1.9 2.1 .9 0 4 -.05 2
B .6 .6 .1 .45 3.6 -.52 0 0 -12 3
b 1.5 .75 .75 -1.6 4.7 -.05 2
B .6 .5 .5 -2.55 4.62 -.05 0 0 20 4
b 1.5 .75 .75 1.6 4.7 -.05 2
B .6 .5 .5 2.55 4.62 -.05 0 0 -20 4
b 1.5 .6 .6 0 2.75 -.05 4
b 1.25 1.25 1.1 0 5.8 -.05 5
b .22 .22 .08 -.28 5.95 -.62 6
b .22 .22 .08 .28 5.95 -.62 6
b .7 .1 .08 0 5.5 -.62 6
C .16 2.1 2.1 0 6.5 -.05 0 180 90 7
C .9 1.16 1.16 0 6.95 -.05 0 180 90 7
]=],
	camp_signpost = [=[
m VStone__@base VLog__@wood WoodPlanks__@trim VPlank__@board
g Arrow1 0 7.1 0
g Arrow2 0 5.75 0
g Arrow3 0 4.4 0
b 1.5 .6 1.5 0 .3 0 1
b .75 7.4 .75 0 4.3 0 2
b 1.05 .4 1.05 0 8.2 0 3
b 3.9 1.05 .32 2.3 7.1 0 4 1
W .32 .53 .75 4.62 7.36 0 0 -90 0 4 1
W .32 .53 .75 4.62 6.84 0 0 -90 180 4 1
b 3.9 1.05 .32 2.3 5.75 0 4 2
W .32 .53 .75 4.62 6.01 0 0 -90 0 4 2
W .32 .53 .75 4.62 5.49 0 0 -90 180 4 2
b 3.9 1.05 .32 2.3 4.4 0 4 3
W .32 .53 .75 4.62 4.66 0 0 -90 0 4 3
W .32 .53 .75 4.62 4.14 0 0 -90 180 4 3
]=],
	camp_snowman = [=[
m Snow__F4F8FC SmoothPlastic__1E1E22 Wood__6E4C32 SmoothPlastic__F0781E Fabric__@cloth Fabric__28282E
s 3.3 3.3 3.3 0 1.4 0 1
s 2.4 2.4 2.4 0 3.55 0 1
s 1.76 1.76 1.76 0 5.15 0 1
s .24 .24 .24 -.3 5.35 -.78 2
C 1.87 .18 .18 -1.75 4.35 -.1 -54 82.4 90 3
s .24 .24 .24 .3 5.35 -.78 2
C 1.87 .18 .18 1.75 4.35 -.1 -54 -82.4 90 3
C .95 .26 .26 0 5.11 -1.27 -85.8 180 -90 4
s .28 .28 .28 0 3.3 -1.17 2
s .28 .28 .28 0 3.9 -1.1 2
C .38 1.96 1.96 0 4.48 0 0 180 90 5
B .45 1.1 .2 .5 4 -.85 0 0 -10 5
C .14 1.64 1.64 0 5.95 0 0 180 90 6
C 1 1.12 1.12 0 6.5 0 0 180 90 6
]=],
	camp_telescope = [=[
m VStone__@base Metal__D6AA50 WoodPlanks__@wood SmoothPlastic__@scope Neon__96E6FF Neon__@accent
g Scope 0 5 0
C 1 6.8 6.8 0 .5 0 0 180 90 1
C .25 7.2 7.2 0 1.12 0 0 180 90 2
b 2.4 .5 1.1 0 .25 -3.7 1
C 3.62 .34 .34 0 2.8 -.85 -28 180 90 3
C 3.62 .34 .34 -.74 2.8 .43 -28 -60 90 3
C 3.62 .34 .34 .74 2.8 .43 -28 60 90 3
C .8 .96 .96 0 4.6 0 0 180 90 2
C 5.95 1.1 1.1 0 5.35 -.3 -65.2 0 90 4 1
C 1.54 1.44 1.44 0 6.69 -3.2 -65.1 0 90 4 1
C .09 1.24 1.24 0 7.05 -3.96 -63.4 0 90 5 1
C .77 .4 .4 0 3.94 2.75 -65.4 0 -90 2 1
C .22 1.2 1.2 0 4.73 1.05 -63.4 0 90 2 1
C .22 1.2 1.2 0 5.6 -.84 -63.4 0 90 2 1
C 2.6 .8 .8 2.3 2.4 1.6 0 180 90 2
s 1.4 1.4 1.4 2.3 4.3 1.6 6
]=],
	camp_tent = [=[
m Fabric__@cloth Fabric__F0E8D6 Fabric__40322A VLog__@wood Fabric__D2BE96 Fabric__@accent Mark__Lamp
B 5.47 .16 7 1.52 2.24 0 0 0 -56.6 1
B .6 .18 7.04 2.65 .59 0 0 0 -56.6 2
B 5.47 .16 7 -1.52 2.24 0 0 0 56.6 1
B .6 .18 7.04 -2.65 .59 0 0 0 56.6 2
W .14 4.4 2.9 1.45 2.2 3.45 0 -90 0 1
W .14 4.4 2.9 -1.45 2.2 3.45 0 90 0 1
W .14 4.4 2.9 1.45 2.2 -3.15 0 -90 0 3
W .14 4.4 2.9 -1.45 2.2 -3.15 0 90 0 3
W .16 4.4 2.9 -1.45 2.2 -3.5 0 90 0 1
C 7.6 .28 .28 0 4.52 0 -90 90 0 4
C 4.85 .3 .3 0 2.42 3.75 0 0 90 4
B .08 .08 5.13 0 2.41 4.9 -63.3 180 0 5
b .25 .5 .25 0 .2 6.1 4
C 4.85 .3 .3 0 2.42 -3.75 0 0 90 4
B .08 .08 5.13 0 2.41 -4.9 -63.3 0 0 5
b .25 .5 .25 0 .2 -6.1 4
b 1.5 .45 3.4 .75 .23 -.4 6
b .3 .3 .3 0 4.1 -3.75 7
]=],
	camp_watchtower = [=[
m VStone__@base VLog__@wood WoodPlanks__@trim VPlank__@wood VRoof__@roof VRoof__@roof2 Fabric__@cloth Mark__Lamp
g Flag 0 22.4 0
b 1.4 .6 1.4 -3.2 .3 3.2 1
C 16.73 .84 .84 -2.85 8.85 2.85 -3.4 -45 90 2
b 1.4 .6 1.4 -3.2 .3 -3.2 1
C 16.73 .84 .84 -2.85 8.85 -2.85 -3.4 -135 90 2
b 1.4 .6 1.4 3.2 .3 3.2 1
C 16.73 .84 .84 2.85 8.85 2.85 -3.4 45 90 2
b 1.4 .6 1.4 3.2 .3 -3.2 1
C 16.73 .84 .84 2.85 8.85 -2.85 -3.4 135 90 2
B .32 .32 10.96 .15 6.15 -2.9 58 93 0 2
B .36 .36 5.9 0 6.2 -2.95 0 90 0 2
B .3 .3 6.6 0 13.6 -3.3 0 90 0 3
B .25 .25 6.6 0 12.9 -3.3 0 90 0 3
B .32 .32 10.96 2.9 6.15 .15 58 3 0 2
b .36 .36 5.9 2.95 6.2 0 2
b .3 .3 6.6 3.3 13.6 0 3
b .25 .25 6.6 3.3 12.9 0 3
B .32 .32 10.96 -.15 6.15 2.9 58 -87 0 2
B .36 .36 5.9 0 6.2 2.95 0 -90 0 2
B .3 .3 6.6 0 13.6 3.3 0 -90 0 3
B .25 .25 6.6 0 12.9 3.3 0 -90 0 3
B .32 .32 10.96 -2.9 6.15 -.15 58 -177 0 2
B .36 .36 5.9 -2.95 6.2 0 0 -180 0 2
B .3 .3 6.6 -3.3 13.6 0 0 -180 0 3
B .25 .25 6.6 -3.3 12.9 0 0 -180 0 3
b 7.4 .5 7.4 0 12.2 0 4
b 9.2 .65 9.2 0 17.33 0 5
b 9.5 .25 9.5 0 17.12 0 6
b 6.8 .65 6.8 0 17.98 0 5
b 4.4 .65 4.4 0 18.62 0 5
b 2 .65 2 0 19.27 0 5
C 3.6 .24 .24 0 21 0 0 180 90 2
b 2.2 1.3 .1 1.1 22.1 0 7 1
B .22 .22 12.23 -.65 6.1 -3.47 86 180 0 2
B .22 .22 12.23 .65 6.1 -3.47 86 180 0 2
b 1.5 .18 .18 0 1.2 -3.82 3
b 1.5 .18 .18 0 2.8 -3.7 3
b 1.5 .18 .18 0 4.4 -3.59 3
b 1.5 .18 .18 0 6 -3.48 3
b 1.5 .18 .18 0 7.6 -3.37 3
b 1.5 .18 .18 0 9.2 -3.26 3
b 1.5 .18 .18 0 10.8 -3.15 3
b .3 .3 .3 2.6 13.9 -2.6 8
]=],
	camp_well = [=[
m VStone__@stone VStone__@base Glass__@water__T10 VLog__@wood VRoof__@roof VRoof__@roof2 WoodPlanks__8C6442 Fabric__D2BE96 Metal__3C3A38
b 2.2 2.3 .85 0 1.15 -2.15 1
b 2.35 .4 1.05 0 2.5 -2.2 2
B 2.2 2.3 .85 1.52 1.15 -1.52 0 -45 0 1
B 2.35 .4 1.05 1.56 2.5 -1.56 0 -45 0 2
B 2.2 2.3 .85 2.15 1.15 0 0 -90 0 1
B 2.35 .4 1.05 2.2 2.5 0 0 -90 0 2
B 2.2 2.3 .85 1.52 1.15 1.52 0 -135 0 1
B 2.35 .4 1.05 1.56 2.5 1.56 0 -135 0 2
B 2.2 2.3 .85 0 1.15 2.15 0 180 0 1
B 2.35 .4 1.05 0 2.5 2.2 0 180 0 2
B 2.2 2.3 .85 -1.52 1.15 1.52 0 135 0 1
B 2.35 .4 1.05 -1.56 2.5 1.56 0 135 0 2
B 2.2 2.3 .85 -2.15 1.15 0 0 90 0 1
B 2.35 .4 1.05 -2.2 2.5 0 0 90 0 2
B 2.2 2.3 .85 -1.52 1.15 -1.52 0 45 0 1
B 2.35 .4 1.05 -1.56 2.5 -1.56 0 45 0 2
C .2 3.8 3.8 0 1.5 0 0 180 90 3
b .6 4.6 .6 -2.25 5 0 4
b .6 4.6 .6 2.25 5 0 4
B 5.8 .4 2.87 0 7.9 -1.21 -41.4 0 0 5
B 5.8 .4 2.87 0 7.9 1.21 41.4 0 0 5
b 6.05 .5 1 0 9.18 0 6
C 5.2 .4 .4 0 5.9 0 -90 0 0 4
b .25 1.1 .25 2.75 5.45 0 7
b .25 .25 .9 2.75 4.95 -.35 7
b .09 2.3 .09 .35 4.7 0 8
C .75 .96 .96 .35 3.2 0 0 180 90 7
C .12 1 1 .35 3.4 0 0 180 90 9
]=],
	camp_windmill = [=[
m VStone__@base Plaster__@tower WoodPlanks__@trim WoodPlanks__@door Glass__@glass VRoof__@roof VRoof__@roof2 Wood__5C402E Fabric__@sail
g Rotor 0 15 -3.5
b 8.6 .8 8.6 0 .4 0 1
b 7.4 4.4 7.4 0 3 0 2
B 6.36 4.4 6.36 0 3 0 0 45 0 2
b 7.7 .4 7.7 0 5.2 0 3
b 6.6 4 6.6 0 7.2 0 2
B 5.68 4 5.68 0 7.2 0 0 45 0 2
b 6.9 .4 6.9 0 9.2 0 3
b 5.8 3.8 5.8 0 11.1 0 2
B 4.99 3.8 4.99 0 11.1 0 0 45 0 2
b 6.1 .4 6.1 0 13 0 3
b 5 3.2 5 0 14.6 0 2
B 4.3 3.2 4.3 0 14.6 0 0 45 0 2
b 5.3 .4 5.3 0 16.2 0 3
b 2.7 4.4 .4 0 3 -3.65 3
b 2 3.8 .4 0 2.7 -3.8 4
b 1.6 1.9 .3 0 7.2 -3.35 3
b 1.1 1.4 .3 0 7.2 -3.45 5
b 1.6 1.9 .3 0 11 -2.95 3
b 1.1 1.4 .3 0 11 -3.05 5
B 6.8 .5 4.75 0 17.46 -1.83 -46 0 0 6
B 6.8 .5 4.75 0 17.46 1.83 46 0 0 6
b 7.05 .5 1 0 19.67 0 7
w .6 2.8 2.7 -2.6 17.6 -1.35 2
W .6 2.8 2.7 -2.6 17.6 1.35 0 -180 0 2
w .6 2.8 2.7 2.6 17.6 -1.35 2
W .6 2.8 2.7 2.6 17.6 1.35 0 -180 0 2
C 1.3 1.5 1.5 0 15 -3.6 -90 -90 0 8 1
B .45 .45 8.6 1.47 19.04 -4.2 70 -90 0 8 1
B .18 .2 6.4 2.01 19.8 -4.25 70 -90 0 8 1
B .18 .2 6.4 4.17 19.01 -4.25 70 -90 0 8 1
B 2.3 6.2 .12 3.09 19.41 -4.3 0 0 -20 9 1
B .45 .45 8.6 4.04 13.53 -4.2 -20 -90 0 8 1
B .18 .2 6.4 4.8 12.99 -4.25 -20 -90 0 8 1
B .18 .2 6.4 4.01 10.83 -4.25 -20 -90 0 8 1
B 2.3 6.2 .12 4.41 11.91 -4.3 0 0 -110 9 1
B .45 .45 8.6 -1.47 10.96 -4.2 -70 90 0 8 1
B .18 .2 6.4 -2.01 10.2 -4.25 -70 90 0 8 1
B .18 .2 6.4 -4.17 10.99 -4.25 -70 90 0 8 1
B 2.3 6.2 .12 -3.09 10.59 -4.3 0 0 160 9 1
B .45 .45 8.6 -4.04 16.47 -4.2 20 90 0 8 1
B .18 .2 6.4 -4.8 17.01 -4.25 20 90 0 8 1
B .18 .2 6.4 -4.01 19.17 -4.25 20 90 0 8 1
B 2.3 6.2 .12 -4.41 18.09 -4.3 0 0 70 9 1
]=],
	critter_chicken = [=[
m SmoothPlastic__FABE28 SmoothPlastic__E2DED6 SmoothPlastic__F8F6F0 SmoothPlastic__DC3228 SmoothPlastic__181616
g Head 0 1.1 -.35
b .12 .46 .12 -.18 .23 0 1
b .12 .46 .72 -.45 .82 .05 2
b .12 .46 .12 .18 .23 0 1
b .12 .46 .72 .45 .82 .05 2
b .8 .75 1.1 0 .82 0 3
W .55 .6 .5 0 1.12 .7 0 -180 0 3
b .5 .55 .5 0 1.42 -.5 3 1
w .2 .18 .3 0 1.38 -.88 1 1
b .12 .26 .38 0 1.8 -.48 4 1
b .12 .22 .12 0 1.2 -.8 4 1
b .06 .1 .1 -.26 1.5 -.6 5 1
b .06 .1 .1 .26 1.5 -.6 5 1
]=],
	critter_frog = [=[
m SmoothPlastic__5AB446 SmoothPlastic__C8E696 SmoothPlastic__FAFAF5 SmoothPlastic__181616
b 1 .55 1.1 0 .4 0 1
b .8 .1 .9 0 .12 -.05 2
b .9 .42 .6 0 .55 -.6 1
s .4 .4 .4 -.28 .82 -.65 3
b .12 .14 .06 -.28 .84 -.84 4
b .36 .3 .85 -.58 .18 .25 1
b .22 .35 .3 -.42 .18 -.55 1
s .4 .4 .4 .28 .82 -.65 3
b .12 .14 .06 .28 .84 -.84 4
b .36 .3 .85 .58 .18 .25 1
b .22 .35 .3 .42 .18 -.55 1
]=],
	critter_koi = [=[
m SmoothPlastic__FA7828 SmoothPlastic__FAF8F0 SmoothPlastic__181616
b .5 .4 1.2 0 .2 0 1
b .42 .36 .42 0 .2 -.78 2
W .08 .5 .6 -.14 .2 .85 0 160 0 1
W .08 .5 .6 .14 .2 .85 0 -160 0 1
B .35 .06 .22 -.38 .1 -.35 0 -25 0 1
b .05 .08 .08 -.22 .26 -.88 3
B .35 .06 .22 .38 .1 -.35 0 25 0 1
b .05 .08 .08 .22 .26 -.88 3
b .3 .05 .35 .06 .42 -.1 2
b .22 .05 .25 -.08 .42 .35 3
]=],
	critter_lizard = [=[
m SmoothPlastic__D64628 SmoothPlastic__FAB45A SmoothPlastic__181616 Neon__FFA03C
b .62 .36 1.25 0 .3 0 1
b .5 .08 1.1 0 .1 0 2
b .52 .32 .62 0 .32 -.88 1
b .4 .26 .8 0 .24 .98 1
b .24 .18 .8 0 .18 1.72 1
B .5 .16 .18 -.48 .14 -.4 0 -20 0 1
B .5 .16 .18 -.48 .14 .4 0 20 0 1
b .06 .1 .1 -.27 .42 -1 3
B .5 .16 .18 .48 .14 -.4 0 20 0 1
B .5 .16 .18 .48 .14 .4 0 -20 0 1
b .06 .1 .1 .27 .42 -1 3
b .2 .06 .2 -.05 .5 -.3 4
b .2 .06 .2 .05 .5 .15 4
b .2 .06 .2 -.05 .5 .6 4
]=],
	critter_owl = [=[
m SmoothPlastic__8C6446 SmoothPlastic__E8D6B0 SmoothPlastic__E29632 Neon__FFD23C SmoothPlastic__181616
g Head 0 1.35 0
b 1 1.2 .9 0 .75 0 1
b .7 .85 .1 0 .7 -.46 2
b .14 1 .8 -.55 .75 .05 1
b .25 .12 .3 -.22 .08 -.2 3
b .14 1 .8 .55 .75 .05 1
b .25 .12 .3 .22 .08 -.2 3
b 1.1 .8 .95 0 1.75 0 1 1
b .9 .62 .1 0 1.72 -.48 2 1
s .34 .34 .34 -.22 1.8 -.52 4 1
b .1 .12 .06 -.22 1.8 -.68 5 1
W .2 .22 .26 -.38 2.25 0 0 -180 0 1 1
s .34 .34 .34 .22 1.8 -.52 4 1
b .1 .12 .06 .22 1.8 -.68 5 1
w .2 .22 .26 .38 2.25 0 1 1
w .14 .2 .18 0 1.6 -.58 3 1
]=],
	critter_penguin = [=[
m SmoothPlastic__242630 SmoothPlastic__F6F6F4 SmoothPlastic__FA9628
g armL -.5 1.3 0
g armR .5 1.3 0
b 1 1.4 .9 0 .85 0 1
b .76 1.15 .1 0 .8 -.46 2
b .86 .66 .8 0 1.85 0 1
b .14 .14 .06 -.2 1.95 -.42 2
b .32 .12 .45 -.25 .06 -.2 3
B .14 .95 .5 -.57 .9 0 0 0 10 1 1
b .14 .14 .06 .2 1.95 -.42 2
b .32 .12 .45 .25 .06 -.2 3
B .14 .95 .5 .57 .9 0 0 0 -10 1 2
w .22 .2 .3 0 1.82 -.52 3
]=],
}

type Mat = { kind: string, col: string, t: number }
type Spec = { mats: { Mat }, groups: { { name: string, pivot: Vector3 } }, parts: { { any } } }
local specs: { [string]: Spec } = {}

local function decode(name: string): Spec?
	local cached = specs[name]
	if cached then
		return cached
	end
	local text = DATA[name]
	if not text then
		return nil
	end
	local s: Spec = { mats = {}, groups = {}, parts = {} }
	for line in string.gmatch(text, "[^\n]+") do
		local f = string.split(line, " ")
		local tag = f[1]
		if tag == "m" then
			for i = 2, #f do
				local bits = string.split(f[i], "__")
				table.insert(s.mats, { kind = bits[1], col = bits[2], t = if bits[3] then (tonumber(string.sub(bits[3], 2)) or 0) / 100 else 0 })
			end
		elseif tag == "g" then
			table.insert(s.groups, { name = f[2], pivot = Vector3.new(tonumber(f[3]) or 0, tonumber(f[4]) or 0, tonumber(f[5]) or 0) })
		else
			local n = table.create(#f - 1)
			for i = 2, #f do
				n[i - 1] = tonumber(f[i]) or 0
			end
			table.insert(s.parts, { tag, n })
		end
	end
	specs[name] = s
	return s
end

function CampProps.has(name: string): boolean
	return DATA[name] ~= nil
end

-- The materials of a model with `roles` filled in.
local function resolve(spec: Spec, roles: Roles): { any }
	local out = {}
	for i, mt in spec.mats do
		local kind, col = mt.kind, mt.col
		if kind == "Mark" then
			out[i] = { mark = col }
			continue
		end
		local color = Color3.new(1, 1, 1)
		if string.sub(col, 1, 1) == "@" then
			local r = roles[string.sub(col, 2)]
			if r then
				color = r[2] or color
				if r[1] then
					kind = r[1]
				end
			end
		else
			color = Color3.fromHex(col)
		end
		local material, variantName = nil, nil
		local v = VOXEL[kind]
		if v then
			material = v[2]
			variantName = if variant(v[1]) then v[1] else nil
		else
			local ok, m = pcall(function()
				return (Enum.Material :: any)[kind]
			end)
			material = if ok and m then m else Enum.Material.Plastic
		end
		out[i] = { material = material, variant = variantName, color = color, t = mt.t }
	end
	return out
end

local SHAPE = { b = Enum.PartType.Block, c = Enum.PartType.Cylinder, s = Enum.PartType.Ball }

-- Build model `name` at `cf` (its ground point, front toward cf.LookVector) into `parent`. Decoration (no
-- collisions) unless opts.collide. Parts of a group get the attribute G = the group's name; the model gets
-- "Pivot_<group>" (its pivot in the model's studs) and NParts. nil when there's no such model.
function CampProps.place(name: string, parent: Instance, cf: CFrame, opts: PlaceOpts?): Model?
	local o = opts or {}
	local spec = decode(name)
	if not spec then
		return nil
	end
	local k = o.scale or 1
	local mats = resolve(spec, o.roles or {})
	local model = Instance.new("Model")
	model.Name = o.name or name
	if o.atomic then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	local n = 0
	for _, p in spec.parts do
		local tag: string, v = p[1], p[2]
		local low = string.lower(tag)
		local rx, ry, rz, mi, gi = 0, 0, 0, v[7], v[8]
		if tag ~= low then
			rx, ry, rz, mi, gi = v[7], v[8], v[9], v[10], v[11]
		end
		local mt = mats[mi]
		local part: BasePart
		if low == "w" then
			part = Instance.new("WedgePart")
		else
			local pp = Instance.new("Part")
			pp.Shape = SHAPE[low] or Enum.PartType.Block
			part = pp
		end
		local size = Vector3.new(v[1], v[2], v[3]) * k
		part.Size = size
		part.CFrame = cf * CFrame.new(v[4] * k, v[5] * k, v[6] * k) * CFrame.fromOrientation(math.rad(rx), math.rad(ry), math.rad(rz))
		part.Anchored = true
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if mt and mt.mark then
			part.Name = mt.mark
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		else
			part.Name = "P"
			part.Material = mt.material
			if mt.variant then
				part.MaterialVariant = mt.variant
			end
			part.Color = mt.color
			part.Transparency = mt.t
			local big = math.max(size.X, size.Y, size.Z) >= 1.6
			part.CanCollide = o.collide == true and big
			part.CanQuery = o.collide == true and big
			part.CastShadow = big
		end
		if gi and spec.groups[gi] then
			part:SetAttribute("G", spec.groups[gi].name)
		end
		part.Parent = model
		n += 1
	end
	for _, g in spec.groups do
		model:SetAttribute("Pivot_" .. g.name, g.pivot * k)
	end
	model:SetAttribute("NParts", n)
	model.WorldPivot = cf
	model.Parent = parent
	return model
end

-- The marker parts called `name` in a placed model (Smoke, Lamp, SignFace, Hand ...).
function CampProps.markers(model: Instance, name: string): { BasePart }
	local out = {}
	for _, d in model:GetChildren() do
		if d.Name == name and d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Turn group `g` of a placed model about its pivot by `rot` (in the model's own axes), e.g. a signpost's arrow.
function CampProps.turnGroup(model: Model, g: string, rot: CFrame)
	local pivot = model:GetAttribute("Pivot_" .. g)
	if typeof(pivot) ~= "Vector3" then
		return
	end
	local at = model:GetPivot() * CFrame.new(pivot)
	local move = at * rot * at:Inverse()
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("G") == g then
			d.CFrame = move * d.CFrame
		end
	end
end

return CampProps
