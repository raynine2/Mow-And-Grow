-- The boss arenas dressed for the area they stand in, in the detailed voxel look of the camp's Tool Shop and Garage
-- (owner, 27 Oct: "do the same for every boss arena ... don't make it overlap"). Built from blocks with the pixel
-- log and stone textures (server/VoxelKit); no stretched meshes any more, so nothing pokes through anything:
--   * the wall runs as straight sections from joint to joint round the ring, each on a stone plinth, with a post
--     on every joint, so the pieces meet exactly on the curve
--   * each area its own wall: log rails and flower planters (meadow), a board fence with hay (wheat), a white
--     plaster wall with a tiled cap and blossom bushes (blossom), a log palisade (pine), crooked stakes with
--     purple lanterns (swamp), frosted stone with snow and icicles (frost), basalt with glowing seams and braziers
--     (ember), violet stone with a gold cap and crystals (isles)
--   * a gatehouse over the entrance: two towers just outside the gap (so the gate bars never cut into them), a
--     heavy lintel, banners in the area's colour, torches
--   * props round the inside of the wall in the area's style, none near the entrance; a stone ring round the
--     summon pad
-- Everything is decoration: no collisions, no queries (BossArena's invisible colliders, gate bars, pad and ramp do
-- the work). The floor, rim and skirt colours come from the area's palette (look / skirtColor, used by BossArena).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)
local VoxelKit = require(script.Parent.VoxelKit)

local ArenaDress = {}

local C = Color3.fromRGB
local K = VoxelKit.C
local part, jitter, chop = VoxelKit.part, VoxelKit.jitter, VoxelKit.chop
local PH = 1.6 -- the plinth's height above the floor

export type Theme = {
	kind: string, -- the wall: "rails", "boards", "plaster", "palisade", "stakes", "blocks"
	stone: Color3, -- tint of the plinth / stone
	wood: Color3?, -- tint of logs and stakes
	board: Color3?,
	timber: Color3,
	roof: Color3, -- the towers' roofs (and the plaster wall's tiles)
	cap: Color3?, -- the block walls' top course
	capMat: Enum.Material?,
	glow: Color3?, -- lanterns, crystals, seams, fire
	top: string, -- what stands on each post: "lantern", "tile", "point", "swamp", "snow", "brazier", "crystal"
	props: { string },
	leaf: Color3?,
	flowers: { Color3 }?,
	seams: boolean?,
	icicles: boolean?,
}

local FLOWERS = { C(210, 96, 110), C(232, 212, 120), C(236, 236, 230), C(160, 110, 190), C(226, 140, 90) }

local THEME: { [string]: Theme } = {
	meadow = { kind = "rails", stone = C(214, 214, 202), wood = K.log, timber = K.timber, roof = C(118, 64, 52), top = "lantern", props = { "barrels", "planter", "crates", "bush", "planter" }, leaf = C(70, 140, 60), flowers = FLOWERS },
	wheat = { kind = "boards", stone = C(224, 212, 188), board = C(176, 130, 82), timber = C(112, 80, 54), wood = K.log, roof = C(140, 84, 50), top = "lantern", props = { "hay", "barrels", "hay", "crates", "hay" } },
	blossom = { kind = "plaster", stone = C(222, 216, 212), timber = C(78, 56, 48), roof = C(76, 82, 100), top = "tile", props = { "stoneLantern", "blossom", "stoneLantern", "blossom", "blossom" }, leaf = C(255, 168, 208), flowers = { C(255, 255, 255), C(255, 214, 230) } },
	pine = { kind = "palisade", stone = C(186, 196, 190), wood = C(214, 188, 162), timber = C(84, 62, 46), roof = C(70, 96, 70), top = "point", props = { "logs", "rocks", "stump", "rocks", "logs" }, leaf = C(52, 110, 68) },
	swamp = { kind = "stakes", stone = C(150, 170, 140), wood = C(140, 122, 104), timber = C(62, 50, 40), roof = C(62, 76, 54), glow = C(190, 120, 255), top = "swamp", props = { "mushrooms", "stump", "mushrooms", "barrels", "stump" }, leaf = C(90, 140, 60) },
	frost = { kind = "blocks", stone = C(206, 230, 248), cap = C(244, 250, 255), capMat = Enum.Material.Snow, timber = C(90, 96, 110), roof = C(226, 238, 250), glow = C(110, 220, 255), top = "snow", props = { "crystals", "rocks", "snow", "crystals", "rocks" }, icicles = true },
	ember = { kind = "blocks", stone = C(100, 88, 96), cap = C(64, 56, 62), timber = C(50, 42, 46), roof = C(64, 56, 62), glow = C(255, 112, 40), top = "brazier", props = { "brazier", "rocks", "crystals", "rocks", "brazier" }, seams = true },
	isles = { kind = "blocks", stone = C(176, 156, 236), cap = C(226, 186, 92), capMat = Enum.Material.Metal, timber = C(90, 74, 130), roof = C(120, 96, 200), glow = C(120, 240, 255), top = "crystal", props = { "crystals", "rocks", "stoneLantern", "crystals", "rocks" } },
}

export type Look = {
	id: string,
	floor: Color3,
	floorMat: Enum.Material,
	rim: Color3,
	rimMat: Enum.Material,
	accent: Color3,
	theme: Theme,
}

-- The look of area z's arena, or nil when the area has none (BossArena then uses its boss themes).
function ArenaDress.look(z: number): Look?
	local zone = Zones.list[z]
	local theme = zone and THEME[zone.id]
	if not zone or not theme then
		return nil
	end
	local p = zone.palette
	return {
		id = zone.id,
		floor = p.ground,
		floorMat = if zone.id == "frost" then Enum.Material.Snow elseif zone.id == "ember" then Enum.Material.Basalt else Enum.Material.Grass,
		rim = p.rock,
		rimMat = if zone.id == "frost" then Enum.Material.Glacier else Enum.Material.Slate,
		accent = p.accent,
		theme = theme,
	}
end

-- The skirt under the floor: the area's ground, darker, with the dirt texture of the world's terrace sides.
function ArenaDress.skirtColor(look: Look): Color3
	return look.floor:Lerp(Color3.new(0, 0, 0), 0.28)
end

export type Ctx = {
	model: Model,
	centre: Vector3,
	r: number,
	facing: Vector3,
	segs: number,
	segW: number,
	yaw0: number,
	look: Look,
}

-------------------------------------------------------------------------------------------------------------
-- geometry: joints on the rim, straight sections between them
-------------------------------------------------------------------------------------------------------------
local function jointAngle(ctx: Ctx, j: number): number
	return ctx.yaw0 + j / ctx.segs * 2 * math.pi
end

local function rimPoint(ctx: Ctx, a: number, rad: number): Vector3
	return ctx.centre + Vector3.new(math.sin(a), 0, math.cos(a)) * rad
end

-- A frame on the rim at angle a: X along the ring (toward bigger angles), -Z into the arena, y = floor top.
local function rimFrame(ctx: Ctx, a: number, rad: number): CFrame
	local pos = rimPoint(ctx, a, rad)
	local tangent = Vector3.new(math.cos(a), 0, -math.sin(a))
	local out = Vector3.new(math.sin(a), 0, math.cos(a))
	return CFrame.fromMatrix(pos, tangent, Vector3.yAxis, out)
end

-- The straight section from joint j to joint j+1: its frame (at the chord's middle) and length.
local function sectionFrame(ctx: Ctx, j: number): (CFrame, number)
	local a, b = rimPoint(ctx, jointAngle(ctx, j), ctx.r), rimPoint(ctx, jointAngle(ctx, j + 1), ctx.r)
	local mid = (a + b) / 2
	local x = (b - a).Unit
	return CFrame.fromMatrix(mid, x, Vector3.yAxis, x:Cross(Vector3.yAxis)), (b - a).Magnitude
end

-------------------------------------------------------------------------------------------------------------
-- wall sections (f: the section's frame, L: its length, k: its index)
-------------------------------------------------------------------------------------------------------------
local function plinth(parent: Instance, f: CFrame, L: number, t: Theme, rng: Random)
	for _, piece in chop(rng, -L / 2 - 0.05, L / 2 + 0.05, 2.4, 4.2) do
		local dip = rng:NextNumber(0, 0.15)
		local len = piece[2] - piece[1]
		part(parent, "Plinth", f * CFrame.new((piece[1] + piece[2]) / 2, (PH - dip - 3) / 2, 0), Vector3.new(len - 0.04, PH - dip + 3, 2.8), jitter(rng, t.stone, 0.06), "stone")
	end
end

local SECTION: { [string]: (Instance, CFrame, number, Theme, Random, number) -> () } = {}

SECTION.rails = function(parent, f, L, t, rng, k)
	for _, y in { 2.7, 4.2 } do
		VoxelKit.log(parent, f * CFrame.new(0, PH + y - 1.6, 0), L + 0.3, 0.75, 0.75, jitter(rng, t.wood :: Color3, 0.05))
	end
	part(parent, "RailPost", f * CFrame.new(0, PH + 1.9, 0), Vector3.new(0.9, 3.8, 0.9), jitter(rng, t.wood :: Color3, 0.05), "log")
	if k % 2 == 0 then
		VoxelKit.planter(parent, f * CFrame.new(rng:NextNumber(-3, 3), 0, -2.4), 5, t.flowers :: { Color3 }, rng)
	end
end

SECTION.boards = function(parent, f, L, t, rng, k)
	local n = math.floor(L / 1.05)
	for i = 0, n - 1 do
		local h = 4.6 + rng:NextNumber(-0.25, 0.25)
		part(parent, "Board", f * CFrame.new(-L / 2 + (i + 0.5) * L / n, PH + h / 2, 0), Vector3.new(L / n - 0.06, h, 0.35), jitter(rng, t.board :: Color3, 0.07))
	end
	for _, y in { 1.0, 3.6 } do
		part(parent, "Batten", f * CFrame.new(0, PH + y, 0.32), Vector3.new(L + 0.1, 0.45, 0.28), t.timber)
		part(parent, "Batten", f * CFrame.new(0, PH + y, -0.32), Vector3.new(L + 0.1, 0.45, 0.28), t.timber)
	end
	if k % 3 == 0 then
		VoxelKit.hay(parent, f * CFrame.new(rng:NextNumber(-3, 3), 0, -2.8) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), rng)
	end
end

SECTION.plaster = function(parent, f, L, t, rng, k)
	part(parent, "Plaster", f * CFrame.new(0, PH + 2.3, 0), Vector3.new(L + 0.1, 4.6, 1.8), jitter(rng, C(238, 230, 218), 0.02))
	for _, y in { 0.25, 4.35 } do
		part(parent, "Beam", f * CFrame.new(0, PH + y, 0), Vector3.new(L + 0.2, 0.5, 2.0), t.timber)
	end
	for _, x in { -L / 3, L / 3 } do
		part(parent, "Stud", f * CFrame.new(x, PH + 2.3, 0), Vector3.new(0.45, 4.1, 2.0), t.timber)
	end
	part(parent, "Tiles", f * CFrame.new(0, PH + 4.85, 0), Vector3.new(L + 0.6, 0.45, 3.4), jitter(rng, t.roof, 0.04))
	part(parent, "Tiles", f * CFrame.new(0, PH + 5.3, 0), Vector3.new(L + 0.6, 0.45, 2.2), jitter(rng, t.roof, 0.04))
	part(parent, "TileRidge", f * CFrame.new(0, PH + 5.65, 0), Vector3.new(L + 0.6, 0.35, 0.9), t.roof:Lerp(Color3.new(0, 0, 0), 0.25))
	if k % 2 == 1 then
		VoxelKit.bush(parent, f * CFrame.new(rng:NextNumber(-4, 4), 0, 3.4), t.leaf :: Color3, rng, t.flowers)
	end
end

SECTION.palisade = function(parent, f, L, t, rng, _k)
	local n = math.floor(L / 1.3)
	for i = 0, n - 1 do
		local h = 6.6 + rng:NextNumber(-0.6, 0.6)
		local x = -L / 2 + (i + 0.5) * L / n
		local wood = jitter(rng, t.wood :: Color3, 0.06)
		part(parent, "Stake", f * CFrame.new(x, PH + h / 2, 0), Vector3.new(L / n - 0.08, h, 1.15), wood, "log")
		part(parent, "StakePoint", f * CFrame.new(x, PH + h + 0.3, 0), Vector3.new(0.7, 0.6, 0.7), wood:Lerp(Color3.new(0, 0, 0), 0.15), "log")
	end
	part(parent, "Binding", f * CFrame.new(0, PH + 4.4, -0.7), Vector3.new(L, 0.5, 0.3), t.timber)
	part(parent, "Binding", f * CFrame.new(0, PH + 1.6, 0.7), Vector3.new(L, 0.5, 0.3), t.timber)
	for _ = 1, 2 do
		part(parent, "Moss", f * CFrame.new(rng:NextNumber(-L / 2 + 1, L / 2 - 1), PH + 0.15, rng:NextNumber(-1, 1)), Vector3.new(rng:NextNumber(1, 2), 0.3, 0.9), jitter(rng, t.leaf :: Color3, 0.1), Enum.Material.Grass)
	end
end

SECTION.stakes = function(parent, f, L, t, rng, k)
	local n = math.floor(L / 1.7)
	for i = 0, n - 1 do
		local h = rng:NextNumber(4.2, 6.4)
		local tilt = CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.09, 0.09))
		part(parent, "Stake", f * CFrame.new(-L / 2 + (i + 0.5) * L / n, PH + h / 2 - 0.2, 0) * tilt, Vector3.new(0.95, h, 0.95), jitter(rng, t.wood :: Color3, 0.08), "log")
	end
	for _, y in { 1.6, 3.4 } do
		part(parent, "Plank", f * CFrame.new(0, PH + y, -0.6) * CFrame.Angles(0, 0, rng:NextNumber(-0.03, 0.03)), Vector3.new(L, 0.5, 0.25), jitter(rng, t.timber, 0.1))
	end
	part(parent, "Moss", f * CFrame.new(rng:NextNumber(-2, 2), PH + 0.15, 0), Vector3.new(L * 0.6, 0.3, 2.9), jitter(rng, t.leaf :: Color3, 0.08), Enum.Material.Grass)
	if k % 3 == 0 then
		for i = 1, 3 do
			local base = f * CFrame.new(rng:NextNumber(-4, 4), 0, -2.4 - i * 0.3)
			local h = rng:NextNumber(0.5, 1.1)
			part(parent, "MushroomStem", base * CFrame.new(0, h / 2, 0), Vector3.new(0.28, h, 0.28), C(220, 214, 200))
			part(parent, "MushroomCap", base * CFrame.new(0, h + 0.15, 0), Vector3.new(0.9, 0.3, 0.9), t.glow :: Color3, Enum.Material.Neon)
		end
	end
end

SECTION.blocks = function(parent, f, L, t, rng, _k)
	local ch = 1.45
	for c = 0, 2 do
		local off = if c % 2 == 0 then 0 else 1.1
		for _, piece in chop(rng, -L / 2 - off, L / 2 + 1.1 - off, 2.0, 4.4) do
			local a, b = math.max(piece[1], -L / 2 - 0.05), math.min(piece[2], L / 2 + 0.05)
			if b - a > 0.3 then
				part(parent, "Stone", f * CFrame.new((a + b) / 2, PH + c * ch + ch / 2, 0), Vector3.new(b - a - 0.05, ch - 0.05, 2.4), jitter(rng, t.stone, 0.07), "stone")
			end
		end
		if t.seams and c > 0 then
			part(parent, "Seam", f * CFrame.new(0, PH + c * ch, 0), Vector3.new(L, 0.12, 2.42), t.glow :: Color3, Enum.Material.Neon)
		end
	end
	local top = PH + 3 * ch
	part(parent, "Cap", f * CFrame.new(0, top + 0.3, 0), Vector3.new(L + 0.2, 0.6, 2.8), jitter(rng, t.cap :: Color3, 0.04), t.capMat or "stone")
	if t.capMat == Enum.Material.Snow then
		for _ = 1, 3 do
			local s = rng:NextNumber(0.8, 1.6)
			part(parent, "Snow", f * CFrame.new(rng:NextNumber(-L / 2 + 1, L / 2 - 1), top + 0.6 + s * 0.25, rng:NextNumber(-0.6, 0.6)), Vector3.new(s * 1.6, s * 0.5, s), t.cap :: Color3, Enum.Material.Snow)
		end
	end
	if t.icicles then
		for _ = 1, 4 do
			local len = rng:NextNumber(0.6, 1.6)
			local ice = part(parent, "Icicle", f * CFrame.new(rng:NextNumber(-L / 2 + 0.5, L / 2 - 0.5), top - len / 2, 1.3), Vector3.new(0.3, len, 0.3), C(200, 236, 255), Enum.Material.Ice)
			ice.Transparency = 0.2
		end
	end
	if t.top == "crystal" and rng:NextNumber() < 0.5 then
		VoxelKit.crystals(parent, f * CFrame.new(rng:NextNumber(-4, 4), top + 0.6, 0), t.glow :: Color3, rng, 2)
	end
end

-------------------------------------------------------------------------------------------------------------
-- posts on the joints (jf: the joint's frame)
-------------------------------------------------------------------------------------------------------------
local WOOD_KINDS = { rails = true, boards = true, palisade = true, stakes = true }

local function post(parent: Instance, jf: CFrame, t: Theme, rng: Random, lit: boolean)
	local wood = WOOD_KINDS[t.kind]
	local H = if t.kind == "palisade" then 8.4 elseif t.kind == "blocks" then 7.2 else 6.4
	part(parent, "PostFoot", jf * CFrame.new(0, (PH + 0.4 - 3) / 2, 0), Vector3.new(3.2, PH + 0.4 + 3, 3.2), jitter(rng, t.stone, 0.05), "stone")
	if wood then
		local w = if t.kind == "palisade" then 2.0 else 1.5
		local tint = if t.kind == "stakes" then t.wood :: Color3 else (t.wood or K.log) :: Color3
		part(parent, "Post", jf * CFrame.new(0, PH + 0.4 + (H - PH - 0.4) / 2, 0), Vector3.new(w, H - PH - 0.4, w), jitter(rng, tint, 0.05), "log")
		if t.kind == "palisade" then
			part(parent, "PostPoint", jf * CFrame.new(0, H + 0.4, 0), Vector3.new(1.3, 0.8, 1.3), jitter(rng, tint, 0.05), "log")
			part(parent, "PostPoint", jf * CFrame.new(0, H + 1.0, 0), Vector3.new(0.6, 0.5, 0.6), jitter(rng, tint, 0.05), "log")
		else
			part(parent, "PostCap", jf * CFrame.new(0, H + 0.2, 0), Vector3.new(w + 0.5, 0.4, w + 0.5), t.timber)
		end
	elseif t.kind == "plaster" then
		part(parent, "Post", jf * CFrame.new(0, (PH + H) / 2 + 0.2, 0), Vector3.new(1.4, H - PH, 1.4), t.timber)
	else
		part(parent, "Post", jf * CFrame.new(0, (PH + H) / 2 + 0.2, 0), Vector3.new(2.6, H - PH, 2.6), jitter(rng, t.stone, 0.05), "stone")
		part(parent, "PostCap", jf * CFrame.new(0, H + 0.45, 0), Vector3.new(3.1, 0.5, 3.1), jitter(rng, t.cap or t.stone, 0.04), t.capMat or "stone")
	end
	local top = jf * CFrame.new(0, H + 0.7, 0)
	if t.top == "lantern" then
		VoxelKit.lantern(parent, top * CFrame.new(0, -0.3, 0), lit)
	elseif t.top == "tile" then
		VoxelKit.pyramid(parent, top * CFrame.new(0, -0.6, 0), 2.8, 2, 0.45, t.roof, rng)
	elseif t.top == "swamp" then
		part(parent, "LanternArm", top * CFrame.new(0, -0.3, -0.9), Vector3.new(0.3, 0.3, 1.8), t.timber)
		VoxelKit.lantern(parent, top * CFrame.new(0, -0.45, -1.6), lit, t.glow, true)
	elseif t.top == "snow" then
		part(parent, "Snow", top * CFrame.new(0, 0.05, 0), Vector3.new(2.9, 0.5, 2.9), t.cap :: Color3, Enum.Material.Snow)
		if lit then
			VoxelKit.crystals(parent, top * CFrame.new(0, 0.3, 0), t.glow :: Color3, rng, 2, true)
		end
	elseif t.top == "brazier" then
		VoxelKit.cylinder(parent, "Brazier", top * CFrame.new(0, -0.2, 0), 0.8, 2.2, K.iron)
		local coals = part(parent, "Coals", top * CFrame.new(0, 0.62, 0), Vector3.new(1.5, 0.2, 1.5), t.glow :: Color3, Enum.Material.Neon)
		if lit then
			VoxelKit.fire(coals, t.glow)
		end
	elseif t.top == "crystal" then
		local c = part(parent, "FloatCrystal", top * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)), Vector3.one * 1.1, t.glow :: Color3, Enum.Material.Neon)
		if lit then
			VoxelKit.light(c, 12, 0.6, t.glow)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- props round the inside of the wall
-------------------------------------------------------------------------------------------------------------
local PROP: { [string]: (Instance, CFrame, Theme, Random, boolean) -> () } = {}
PROP.barrels = function(p, cf, _t, rng)
	VoxelKit.barrel(p, cf * CFrame.new(-1.3, 0, 0), 2.6, rng)
	VoxelKit.barrel(p, cf * CFrame.new(0.9, 0, 0.6), 2.3, rng)
	VoxelKit.crate(p, cf * CFrame.new(0.4, 0.9, -1.8) * CFrame.Angles(0, 0.3, 0), 1.8, rng)
end
PROP.crates = function(p, cf, _t, rng)
	VoxelKit.crate(p, cf * CFrame.new(-1, 1.1, 0) * CFrame.Angles(0, 0.1, 0), 2.2, rng)
	VoxelKit.crate(p, cf * CFrame.new(1.3, 0.9, 0.3) * CFrame.Angles(0, -0.2, 0), 1.8, rng)
	VoxelKit.crate(p, cf * CFrame.new(-0.8, 2.2 + 0.8, 0.1) * CFrame.Angles(0, 0.35, 0), 1.6, rng)
end
PROP.planter = function(p, cf, t, rng)
	VoxelKit.planter(p, cf, 4, t.flowers or FLOWERS, rng)
	VoxelKit.bush(p, cf * CFrame.new(0, 0, 1.6), t.leaf or K.leaf, rng)
end
PROP.bush = function(p, cf, t, rng)
	VoxelKit.bush(p, cf, t.leaf or K.leaf, rng, t.flowers)
end
PROP.blossom = function(p, cf, t, rng)
	VoxelKit.bush(p, cf, t.leaf or K.leaf, rng, t.flowers)
	VoxelKit.bush(p, cf * CFrame.new(2.2, 0, 0.8), (t.leaf or K.leaf):Lerp(Color3.new(1, 1, 1), 0.2), rng)
end
PROP.hay = function(p, cf, _t, rng)
	VoxelKit.hay(p, cf * CFrame.new(-1.6, 0, 0), rng)
	VoxelKit.hay(p, cf * CFrame.new(1.6, 0, 0.2) * CFrame.Angles(0, 0.15, 0), rng)
	VoxelKit.hay(p, cf * CFrame.new(0, 1.6, 0.1) * CFrame.Angles(0, -0.1, 0), rng)
end
PROP.rocks = function(p, cf, t, rng)
	VoxelKit.rocks(p, cf, t.stone, rng, 4)
end
PROP.logs = function(p, cf, t, rng)
	for row = 0, 2 do
		for i = 0, 2 - row do
			local log = part(p, "PileLog", cf * CFrame.new((i - (2 - row) / 2) * 1.05, 0.5 + row * 0.9, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(4, 1, 1), jitter(rng, t.wood or K.log, 0.08), "log")
			log.Shape = Enum.PartType.Cylinder
		end
	end
end
PROP.stump = function(p, cf, t, rng)
	VoxelKit.cylinder(p, "Stump", cf, 1.4, 2.4, jitter(rng, t.wood or K.log, 0.06), "log")
	VoxelKit.cylinder(p, "StumpTop", cf * CFrame.new(0, 1.4, 0), 0.06, 2.0, C(196, 160, 112))
	part(p, "Moss", cf * CFrame.new(0.6, 1.45, 0.2), Vector3.new(1.2, 0.25, 0.9), t.leaf or K.leaf, Enum.Material.Grass)
end
PROP.mushrooms = function(p, cf, t, rng, lit)
	local first: BasePart? = nil
	for _ = 1, 5 do
		local base = cf * CFrame.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.2, 1.2))
		local h = rng:NextNumber(0.7, 2.2)
		part(p, "MushroomStem", base * CFrame.new(0, h / 2, 0), Vector3.new(0.4, h, 0.4), C(220, 214, 200))
		local cap = part(p, "MushroomCap", base * CFrame.new(0, h + 0.2, 0), Vector3.new(h * 0.9 + 0.4, 0.4, h * 0.9 + 0.4), t.glow or C(255, 120, 200), Enum.Material.Neon)
		first = first or cap
	end
	if lit and first then
		VoxelKit.light(first, 12, 0.6, t.glow)
	end
end
PROP.crystals = function(p, cf, t, rng, lit)
	VoxelKit.crystals(p, cf, t.glow or C(120, 240, 255), rng, 5, lit)
	VoxelKit.rocks(p, cf * CFrame.new(1.2, 0, 1), t.stone, rng, 2)
end
PROP.snow = function(p, cf, t, rng)
	for _ = 1, 4 do
		local s = rng:NextNumber(1.2, 2.6)
		part(p, "SnowMound", cf * CFrame.new(rng:NextNumber(-1.5, 1.5), s * 0.25, rng:NextNumber(-1, 1)), Vector3.new(s * 1.5, s * 0.5, s * 1.2), t.cap or C(244, 250, 255), Enum.Material.Snow)
	end
end
PROP.brazier = function(p, cf, t, rng, lit)
	part(p, "BrazierFoot", cf * CFrame.new(0, 0.6, 0), Vector3.new(2.2, 1.2, 2.2), jitter(rng, t.stone, 0.05), "stone")
	part(p, "BrazierPost", cf * CFrame.new(0, 2.0, 0), Vector3.new(0.8, 1.6, 0.8), K.iron)
	VoxelKit.cylinder(p, "Brazier", cf * CFrame.new(0, 2.8, 0), 0.8, 2.4, K.iron)
	local coals = part(p, "Coals", cf * CFrame.new(0, 3.62, 0), Vector3.new(1.7, 0.2, 1.7), t.glow or C(255, 110, 40), Enum.Material.Neon)
	VoxelKit.fire(coals, t.glow)
	local _ = lit
end
PROP.stoneLantern = function(p, cf, t, rng, lit)
	local s = t.stone
	part(p, "LanternFoot", cf * CFrame.new(0, 0.3, 0), Vector3.new(2.2, 0.6, 2.2), jitter(rng, s, 0.05), "stone")
	part(p, "LanternPost", cf * CFrame.new(0, 1.6, 0), Vector3.new(0.9, 2.0, 0.9), jitter(rng, s, 0.05), "stone")
	part(p, "LanternShelf", cf * CFrame.new(0, 2.75, 0), Vector3.new(1.8, 0.3, 1.8), jitter(rng, s, 0.05), "stone")
	local box = part(p, "LanternLight", cf * CFrame.new(0, 3.4, 0), Vector3.new(1.1, 1.0, 1.1), t.glow or K.lamp, Enum.Material.Neon)
	box.Transparency = 0.2
	VoxelKit.pyramid(p, cf * CFrame.new(0, 3.9, 0), 2.4, 2, 0.4, s:Lerp(Color3.new(0, 0, 0), 0.2), rng)
	if lit then
		VoxelKit.light(box, 14, 0.6, t.glow)
	end
end

local function props(ctx: Ctx, parent: Instance, t: Theme, rng: Random)
	local spots = 12
	local lights = 0
	for s = 0, spots - 1 do
		local u = (s + 0.5) / spots
		-- none within 45 degrees of the entrance (the gate, the ramp and the way in stay clear)
		if math.min(u, 1 - u) * 360 < 45 then
			continue
		end
		local a = ctx.yaw0 + u * 2 * math.pi + rng:NextNumber(-0.04, 0.04)
		local cf = CFrame.lookAt(rimPoint(ctx, a, ctx.r - 6.5), Vector3.new(ctx.centre.X, ctx.centre.Y, ctx.centre.Z)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		local kind = t.props[s % #t.props + 1]
		local lit = lights < 4 and (kind == "crystals" or kind == "mushrooms" or kind == "stoneLantern" or kind == "brazier")
		if lit then
			lights += 1
		end
		PROP[kind](parent, cf, t, rng, lit)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the wall
-------------------------------------------------------------------------------------------------------------
-- The wall sections, the posts on the joints and the props inside. Returns false when the area has no look
-- (BossArena then builds its part walls).
function ArenaDress.wall(ctx: Ctx): boolean
	local t = ctx.look.theme
	local folder = Instance.new("Folder")
	folder.Name = "Dress"
	folder.Parent = ctx.model
	local rng = Random.new(ctx.segs * 31 + #ctx.look.id * 7)
	-- sections between joints 1 and segs-1 (the two either side of the facing direction are the entrance)
	local build = SECTION[t.kind]
	for j = 1, ctx.segs - 2 do
		local f, L = sectionFrame(ctx, j)
		plinth(folder, f, L, t, rng)
		build(folder, f, L, t, rng, j)
	end
	-- posts on the joints between sections (the gatehouse towers stand on joints 1 and segs-1)
	for j = 2, ctx.segs - 2 do
		post(folder, rimFrame(ctx, jointAngle(ctx, j), ctx.r), t, rng, j % 3 == 0)
	end
	props(ctx, folder, t, rng)
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the gatehouse
-------------------------------------------------------------------------------------------------------------
local TW = 5.4 -- a tower's width
local TH = 12 -- its body's top

-- One tower standing on `tf` (X along the ring, -Z into the arena).
local function tower(m: Instance, tf: CFrame, t: Theme, rng: Random)
	part(m, "TowerBase", tf * CFrame.new(0, (3.2 - 3) / 2, 0), Vector3.new(TW + 0.4, 3.2 + 3, TW + 0.4), jitter(rng, t.stone, 0.05), "stone")
	if WOOD_KINDS[t.kind] then
		-- log walls with the corners interlocking, like the shop
		local tint = (t.wood or K.log) :: Color3
		for row = 0, 5 do
			local y = 3.2 + row * 1.45 + 0.7
			local long = row % 2 == 0
			for _, s in { -1, 1 } do
				VoxelKit.log(m, tf * CFrame.new(0, y, s * (TW / 2 - 0.5)), if long then TW + 0.8 else TW - 1.0, 1.3, 1.0, jitter(rng, tint, 0.05))
				VoxelKit.log(m, tf * CFrame.new(s * (TW / 2 - 0.5), y, 0) * CFrame.Angles(0, math.rad(90), 0), if long then TW - 1.0 else TW + 0.8, 1.3, 1.0, jitter(rng, tint, 0.05))
			end
		end
		part(m, "TowerFloor", tf * CFrame.new(0, TH, 0), Vector3.new(TW + 1.2, 0.5, TW + 1.2), t.timber)
		VoxelKit.pyramid(m, tf * CFrame.new(0, TH + 0.25, 0), TW + 1.6, 4, 0.75, t.roof, rng)
	elseif t.kind == "plaster" then
		part(m, "TowerWall", tf * CFrame.new(0, 3.2 + (TH - 3.2) / 2, 0), Vector3.new(TW - 0.4, TH - 3.2, TW - 0.4), C(238, 230, 218))
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(m, "TowerPost", tf * CFrame.new(sx * (TW / 2 - 0.3), 3.2 + (TH - 3.2) / 2, sz * (TW / 2 - 0.3)), Vector3.new(0.7, TH - 3.2, 0.7), t.timber)
			end
		end
		part(m, "TowerBand", tf * CFrame.new(0, 7.4, 0), Vector3.new(TW, 0.5, TW), t.timber)
		VoxelKit.pyramid(m, tf * CFrame.new(0, TH, 0), TW + 2.6, 4, 0.7, t.roof, rng)
	else
		for row = 0, 5 do
			local y = 3.2 + row * 1.45 + 0.72
			part(m, "TowerStone", tf * CFrame.new(0, y, 0) * CFrame.Angles(0, (row % 2) * math.rad(90), 0), Vector3.new(TW - 0.1, 1.4, TW - 0.3 - (row % 2) * 0.2), jitter(rng, t.stone, 0.07), "stone")
			if t.seams and row > 0 then
				part(m, "Seam", tf * CFrame.new(0, 3.2 + row * 1.45, 0), Vector3.new(TW - 0.05, 0.12, TW - 0.05), t.glow :: Color3, Enum.Material.Neon)
			end
		end
		part(m, "TowerCap", tf * CFrame.new(0, TH + 0.3, 0), Vector3.new(TW + 0.6, 0.6, TW + 0.6), jitter(rng, t.cap or t.stone, 0.04), t.capMat or "stone")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(m, "Merlon", tf * CFrame.new(sx * (TW / 2 - 0.4), TH + 1.2, sz * (TW / 2 - 0.4)), Vector3.new(1.3, 1.2, 1.3), jitter(rng, t.stone, 0.06), "stone")
			end
		end
		if t.top == "crystal" or t.top == "snow" then
			VoxelKit.crystals(m, tf * CFrame.new(0, TH + 0.6, 0), t.glow :: Color3, rng, 3, true)
		elseif t.top == "brazier" then
			local coals = part(m, "Coals", tf * CFrame.new(0, TH + 0.7, 0), Vector3.new(2, 0.2, 2), t.glow :: Color3, Enum.Material.Neon)
			VoxelKit.fire(coals, t.glow, 1.4)
		end
	end
	-- a torch on the tower's outer face, beside the way in
	local torch = tf * CFrame.new(0, 7.2, TW / 2 + 0.35)
	part(m, "TorchBracket", torch, Vector3.new(0.3, 0.9, 0.7), K.iron)
	local flame = part(m, "TorchHead", torch * CFrame.new(0, 0.7, 0.25), Vector3.new(0.5, 0.5, 0.5), t.glow or C(255, 140, 60), Enum.Material.Neon)
	VoxelKit.fire(flame, t.glow, 0.6)
end

-- The gateway over the entrance: towers on both sides of the gap, a lintel across with banners. Returns the
-- model (BossArena floats the boss name over it).
function ArenaDress.gate(ctx: Ctx): Model
	local t = ctx.look.theme
	local m = Instance.new("Model")
	m.Name = "ArenaGate"
	local rng = Random.new(ctx.segs * 17 + #ctx.look.id)
	local ends = {}
	for _, j in { 1, ctx.segs - 1 } do
		local jf = rimFrame(ctx, jointAngle(ctx, j), ctx.r)
		-- a little away from the gap, so the gate bars (BossArena) never cut into the tower
		local away = if j == 1 then 1.3 else -1.3
		local tf = jf * CFrame.new(away, 0, 0)
		tower(m, tf, t, rng)
		table.insert(ends, tf)
	end
	local a, b = ends[1].Position, ends[2].Position
	local mid = (a + b) / 2
	local x = (b - a).Unit
	local lf = CFrame.fromMatrix(mid, x, Vector3.yAxis, x:Cross(Vector3.yAxis))
	local span = (b - a).Magnitude
	local stone = t.kind == "blocks"
	-- (its underside at 11.25: the gate bars, 11 tall, slide up under it)
	part(m, "Lintel", lf * CFrame.new(0, TH, 0), Vector3.new(span, 1.5, 2.4), if stone then jitter(rng, t.stone, 0.05) else t.timber, if stone then "stone" else nil)
	part(m, "Lintel", lf * CFrame.new(0, TH + 1.15, 0), Vector3.new(span - 1.4, 0.8, 1.8), if stone then jitter(rng, t.cap or t.stone, 0.04) else t.timber:Lerp(Color3.new(1, 1, 1), 0.1), if stone then t.capMat or "stone" else nil)
	if not stone then
		part(m, "LintelRoof", lf * CFrame.new(0, TH + 1.8, 0), Vector3.new(span - 1, 0.5, 3.2), jitter(rng, t.roof, 0.04))
	end
	-- banners in the area's colour hanging from the lintel, inside and out (between the gate bars' slots)
	for _, side in { -1, 1 } do
		for _, sx in { -1, 1 } do
			local bx = sx * (span / 2 - 6)
			part(m, "BannerRod", lf * CFrame.new(bx, TH - 0.9, side * 1.3), Vector3.new(3.0, 0.2, 0.2), K.iron)
			part(m, "Banner", lf * CFrame.new(bx, TH - 3.3, side * 1.3), Vector3.new(2.6, 4.6, 0.12), ctx.look.accent, Enum.Material.Fabric)
			part(m, "BannerHem", lf * CFrame.new(bx, TH - 5.65, side * 1.32), Vector3.new(2.6, 0.3, 0.14), ctx.look.accent:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric)
		end
	end
	m.Parent = ctx.model
	return m
end

-- A ring of stone round the summon pad, sunk so only a low step shows, with a lantern / crystal / brazier on four
-- short pillars (the pad itself and how it's read are BossArena's / server/Boss's).
function ArenaDress.altar(ctx: Ctx, padPos: Vector3)
	local t = ctx.look.theme
	local m = Instance.new("Model")
	m.Name = "SummonAltar"
	local rng = Random.new(91)
	local n = 18
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		local pos = padPos + Vector3.new(math.sin(a), 0, math.cos(a)) * 7.8
		part(m, "AltarStone", CFrame.lookAt(pos, padPos) * CFrame.new(0, 0.3, 0), Vector3.new(2.85, 0.6, 1.8), jitter(rng, t.stone, 0.07), "stone")
	end
	for i = 0, 3 do
		local a = (i + 0.5) / 4 * 2 * math.pi
		local pos = padPos + Vector3.new(math.sin(a), 0, math.cos(a)) * 9.6
		local base = CFrame.new(pos) * CFrame.Angles(0, a, 0)
		part(m, "AltarPillar", base * CFrame.new(0, 1.1, 0), Vector3.new(1.6, 2.2, 1.6), jitter(rng, t.stone, 0.06), "stone")
		part(m, "AltarCap", base * CFrame.new(0, 2.35, 0), Vector3.new(2.0, 0.3, 2.0), jitter(rng, t.cap or t.stone, 0.04), t.capMat or "stone")
		if t.top == "crystal" or t.top == "snow" then
			VoxelKit.crystals(m, base * CFrame.new(0, 2.5, 0), t.glow :: Color3, rng, 2, i % 2 == 0)
		elseif t.top == "brazier" then
			local coals = part(m, "Coals", base * CFrame.new(0, 2.6, 0), Vector3.new(1.2, 0.2, 1.2), t.glow :: Color3, Enum.Material.Neon)
			VoxelKit.fire(coals, t.glow, 0.7)
		else
			VoxelKit.lantern(m, base * CFrame.new(0, 2.5, 0), i % 2 == 0, t.glow)
		end
	end
	m.Parent = ctx.model
end

return ArenaDress
