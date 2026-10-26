-- The boss arenas dressed for the area they stand in (the owner, 26 Oct: "make the models fit with each other and
-- the world"; then, after ForgeGUI ran out of credits: "use everything" that was made).
-- The arenas were themed after their bosses (hedge, golf bunker, pumpkin...), so a swamp ring stood in the snow of
-- Frost Peaks and a golf sand pit in Blossom Garden. Now each arena takes its area's look from shared/Zones:
--   * the floor, rim and skirt in the area's ground and rock colours and textures (like RunWorld.texturedGround)
--   * the area's ForgeGUI wall section on every wall segment, stretched to the segment so they join up, and its
--     ForgeGUI pillar on every joint (none at the entrance: the gateway's pillars stand there)
--   * the area's ForgeGUI gateway over the entrance, fitted to the gap
--   * the area's ForgeGUI decorations and its own voxel bushes, rocks and grass clumps (server/VoxelModels) round the
--     inside of the wall
-- (the models: SET below, ids in shared/ForgeModelIds). Where a model is missing (ForgeGUI didn't deliver it, or it
-- isn't loaded) the same piece is built from chunky blocks in the area's colours instead, each block a shade off
-- its neighbours like the voxel trees: a fence or block wall with the area's trim (flowers, wheat, petals, moss,
-- glowing mushrooms, snow and icicles, lava seams, star crystals), block pillars, a block gateway whose towers
-- stand on the wall's ends, and a block ring round the summon pad.
-- Everything is decoration: no collisions, no queries (BossArena's invisible colliders, gate bars, pad and ramp
-- do the work and don't change).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)
local VoxelModels = require(script.Parent.VoxelModels)
local Models = require(script.Parent.Models)

local ArenaDress = {}

local C = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local U = 1.5 -- the block size (the voxel trees' cubes are about this big)

export type Spec = {
	kind: string, -- "fence" or "wall"
	main: { Color3 }, -- the wall's / fence's blocks
	cap: Color3, -- the wall's top row / the fence's rails
	base: Color3, -- the strip of ground blocks at the wall's foot
	trim: { Color3 }, -- small cubes dotted along it (flowers, petals, moss...)
	glow: Color3?, -- neon bits (lava seams, runes, crystals, mushrooms)
	topper: Color3, -- the block on top of each pillar
	topperNeon: boolean?,
	icicles: boolean?,
	stakes: boolean?, -- uneven, slightly leaning fence posts (the swamp)
	ears: boolean?, -- tall wheat ears leaning on the fence
}

local SPEC: { [string]: Spec } = {
	meadow = { kind = "fence", main = { C(250, 250, 244), C(236, 236, 228) }, cap = C(244, 244, 236), base = C(72, 170, 46), trim = { C(255, 214, 40), C(255, 255, 255), C(255, 120, 150) }, topper = C(255, 214, 40) },
	wheat = { kind = "fence", main = { C(178, 120, 62), C(160, 104, 52) }, cap = C(196, 136, 72), base = C(236, 186, 74), trim = { C(255, 214, 96), C(250, 196, 70), C(226, 160, 52) }, topper = C(255, 200, 70), ears = true },
	blossom = { kind = "wall", main = { C(246, 236, 222), C(236, 224, 208), C(250, 242, 232) }, cap = C(110, 104, 112), base = C(255, 196, 222), trim = { C(255, 150, 200), C(255, 196, 226), C(255, 120, 190) }, topper = C(255, 120, 200) },
	pine = { kind = "wall", main = { C(118, 128, 124), C(100, 112, 108), C(132, 140, 134) }, cap = C(66, 140, 74), base = C(46, 129, 100), trim = { C(79, 177, 141), C(56, 160, 125) }, glow = C(64, 230, 170), topper = C(64, 210, 160), topperNeon = true },
	swamp = { kind = "fence", main = { C(78, 60, 46), C(64, 50, 38), C(90, 70, 52) }, cap = C(70, 54, 40), base = C(78, 126, 45), trim = { C(107, 155, 49), C(82, 138, 41) }, glow = C(190, 120, 255), topper = C(190, 120, 255), topperNeon = true, stakes = true },
	frost = { kind = "wall", main = { C(176, 222, 250), C(156, 210, 246), C(196, 232, 252) }, cap = C(248, 252, 255), base = C(236, 246, 255), trim = { C(220, 244, 255) }, glow = C(70, 225, 255), topper = C(90, 230, 255), topperNeon = true, icicles = true },
	ember = { kind = "wall", main = { C(58, 50, 58), C(44, 38, 44), C(70, 60, 66) }, cap = C(36, 30, 36), base = C(74, 62, 70), trim = { C(255, 120, 50) }, glow = C(255, 110, 40), topper = C(255, 140, 50), topperNeon = true },
	isles = { kind = "wall", main = { C(124, 96, 220), C(110, 84, 204), C(140, 112, 232) }, cap = C(255, 200, 70), base = C(150, 120, 255), trim = { C(120, 240, 255), C(255, 150, 240) }, glow = C(120, 240, 255), topper = C(255, 220, 90), topperNeon = true },
}

-- the ForgeGUI models for each area (shared/ForgeModelIds; nil = built from blocks). The meadow has the voxel ones.
local SET: { [string]: { wall: string?, post: string?, gate: string?, props: { string } } } = {
	meadow = { wall = "vwall_meadow", post = nil, gate = "varena_meadow", props = {} },
	wheat = { wall = "awall_wheat", post = nil, gate = "arena_cornfield", props = {} },
	blossom = { wall = "awall_blossom", post = nil, gate = "arena_sakura", props = {} },
	pine = { wall = "awall_pine", post = "apost_pine", gate = "arena_ruins", props = {} },
	swamp = { wall = "awall_swamp", post = "apost_swamp", gate = "arena_swamp", props = { "aprop_swamp1", "aprop_swamp2" } },
	frost = { wall = "awall_frost", post = "apost_frost", gate = nil, props = { "aprop_frost2" } },
	ember = { wall = "awall_ember", post = "apost_ember", gate = "arena_ember", props = { "aprop_ember2" } },
	isles = { wall = "awall_starlight", post = "apost_starlight", gate = "arena_starlight", props = {} },
}

local function loaded(name: string?): string?
	return if name and Models.has("forge_" .. name) then name else nil
end

-- A ForgeGUI model stretched to exactly `size` (width, height, depth: the wall sections must meet end to end),
-- standing on `cf` with its front toward cf.LookVector, no collisions.
local function placeBox(name: string, parent: Instance, cf: CFrame, size: Vector3): Model?
	local m = Models.placeForge(name, parent, CFrame.new(), { width = size.X }, true)
	if not m then
		return nil
	end
	local body = m:FindFirstChildWhichIsA("MeshPart", true)
	if body then
		local have = m:GetExtentsSize()
		local k = Vector3.new(size.X / have.X, size.Y / have.Y, size.Z / have.Z)
		-- the mesh is turned about Y only (Models.prepareForge): its own X runs along the model's X or its Z
		local alongX = math.abs(body.CFrame.RightVector.X) > 0.7
		local kx, kz = if alongX then k.X else k.Z, if alongX then k.Z else k.X
		body.Size = Vector3.new(body.Size.X * kx, body.Size.Y * k.Y, body.Size.Z * kz)
		body.CFrame = CFrame.new(body.Position.X * k.X, body.Size.Y / 2, body.Position.Z * k.Z) * body.CFrame.Rotation
		body.CanQuery = false
	end
	m:PivotTo(cf)
	return m
end

-- How tall / deep a wall section comes out when stretched to width w: its own shape, kept in sensible bounds.
local function wallSize(name: string, w: number): Vector3?
	local probe = Models.placeForge(name, workspace, CFrame.new(0, -500, 0), { width = w }, true)
	if not probe then
		return nil
	end
	local s = probe:GetExtentsSize()
	probe:Destroy()
	return Vector3.new(w, math.clamp(s.Y, 5.5, 8), math.clamp(s.Z, 1.6, 3.2))
end

export type Look = {
	id: string,
	floor: Color3,
	floorMat: Enum.Material,
	rim: Color3,
	rimMat: Enum.Material,
	accent: Color3,
	spec: Spec,
	wall: string?,
	post: string?,
	gate: string?,
	props: { string },
}

-- The look of area z's arena, or nil when the area has none (BossArena then uses its boss themes).
function ArenaDress.look(z: number): Look?
	local zone = Zones.list[z]
	local spec = zone and SPEC[zone.id]
	if not zone or not spec then
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
		spec = spec,
		wall = loaded(SET[zone.id].wall),
		post = loaded(SET[zone.id].post),
		gate = loaded(SET[zone.id].gate),
		props = SET[zone.id].props,
	}
end

-- The skirt under the floor: the area's ground, darker, with the dirt texture of the world's terrace sides.
function ArenaDress.skirtColor(look: Look): Color3
	return look.floor:Lerp(Color3.new(0, 0, 0), 0.28)
end

-------------------------------------------------------------------------------------------------------------
-- blocks
-------------------------------------------------------------------------------------------------------------
-- A block: decoration only (no collisions, no queries, no touches). Small ones cast no shadow (cheaper).
local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = "Block"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 3
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = mat or SP
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = parent
	return p
end

-- one of the colours, a shade lighter or darker (the voxel trees' look)
local function shade(list: { Color3 }, rng: Random): Color3
	local c = list[rng:NextInteger(1, #list)]
	local k = rng:NextNumber(-0.06, 0.06)
	return if k > 0 then c:Lerp(Color3.new(1, 1, 1), k) else c:Lerp(Color3.new(0, 0, 0), -k)
end

-- A row of blocks from x0 to x1 (along the section's X) at height y, in runs of 1 to 3 blocks of one shade.
local function row(f: Instance, at: CFrame, x0: number, x1: number, y: number, h: number, d: number, z: number, colors: { Color3 }, rng: Random)
	local x = x0
	while x < x1 - 0.05 do
		local w = math.min(U * rng:NextInteger(1, 3), x1 - x)
		block(f, Vector3.new(w, h, d), at * CFrame.new(x + w / 2, y + h / 2, z), shade(colors, rng))
		x += w
	end
end

-- small cubes dotted along the section at height y, on its inner face (-Z is into the arena)
local function dots(f: Instance, at: CFrame, w: number, y: number, z: number, n: number, colors: { Color3 }, rng: Random, s: number?, mat: Enum.Material?)
	for _ = 1, n do
		local size = (s or 0.7) * rng:NextNumber(0.85, 1.2)
		block(f, Vector3.one * size, at * CFrame.new(rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), y + size / 2, z), shade(colors, rng), mat)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the wall
-------------------------------------------------------------------------------------------------------------
-- One wall section on `at` (on the rim at floor height, LookVector into the arena), `w` wide, about 6 tall.
local function section(f: Instance, at: CFrame, w: number, s: Spec, rng: Random)
	local x0, x1 = -w / 2, w / 2
	-- the strip of ground blocks along the foot (turf, wheat, snow...)
	row(f, at, x0, x1, 0, U * 0.6, U * 2.2, -0.2, { s.base }, rng)
	if s.kind == "fence" then
		-- posts / stakes and two rails
		local n = 6
		for i = 0, n - 1 do
			local x = x0 + (i + 0.5) * w / n
			local h = if s.stakes then U * rng:NextNumber(3.2, 4.4) else U * 3.6
			local tilt = if s.stakes then CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.1, 0.1)) else CFrame.identity
			block(f, Vector3.new(U * 0.7, h, U * 0.6), at * CFrame.new(x, h / 2, 0) * tilt, shade(s.main, rng))
			if not s.stakes then
				-- a pointed picket: a smaller block on top
				block(f, Vector3.new(U * 0.4, U * 0.35, U * 0.5), at * CFrame.new(x, h + U * 0.17, 0), shade(s.main, rng))
			end
		end
		for _, y in { U * 1.2, U * 2.6 } do
			row(f, at, x0, x1, y, U * 0.45, U * 0.4, -U * 0.45, { s.cap }, rng)
		end
		-- flowers / wheat ears / reeds at the foot, and glowing mushrooms in the swamp
		dots(f, at, w, U * 0.6, -U * 0.9, 5, s.trim, rng, 0.8)
		if s.ears then
			-- wheat: tall ears leaning on the fence
			for _ = 1, 3 do
				local x = rng:NextNumber(x0 + 1, x1 - 1)
				block(f, Vector3.new(U * 0.35, U * 2.2, U * 0.35), at * CFrame.new(x, U * 1.7, -U * 0.8) * CFrame.Angles(0.12, 0, rng:NextNumber(-0.2, 0.2)), shade(s.trim, rng))
			end
		end
		if s.glow then
			dots(f, at, w, U * 0.6, -U * 0.95, 2, { s.glow }, rng, 0.6, NEON)
		end
		return
	end
	-- a block wall: 3 rows of staggered blocks, then the cap row overhanging both faces
	for r = 0, 2 do
		row(f, at, x0, x1, U * 0.6 + r * U * 1.1, U * 1.1, U * 1.3, 0, s.main, rng)
	end
	local capY = U * 0.6 + 3 * U * 1.1
	row(f, at, x0, x1, capY, U * 0.6, U * 1.9, 0, { s.cap }, rng)
	if s.glow and s.kind == "wall" then
		-- glowing seams / runes on the inner face
		for _ = 1, 2 do
			local x = rng:NextNumber(x0 + 1.5, x1 - 1.5)
			block(f, Vector3.new(U * rng:NextNumber(0.6, 1.6), U * 0.18, 0.15), at * CFrame.new(x, U * 0.6 + rng:NextInteger(1, 2) * U * 1.1, -U * 0.66), s.glow, NEON)
		end
	end
	if s.icicles then
		for _ = 1, 4 do
			local h = U * rng:NextNumber(0.5, 1.1)
			block(f, Vector3.new(U * 0.3, h, U * 0.3), at * CFrame.new(rng:NextNumber(x0 + 0.5, x1 - 0.5), capY - h / 2, -U * 0.85), s.glow or s.cap, SP)
		end
	end
	-- moss / petals / snow lumps / embers on the cap
	dots(f, at, w, capY + U * 0.6, rng:NextNumber(-0.4, 0.4), 4, s.trim, rng, 0.75, if s.glow and s.trim[1] == s.glow then NEON else nil)
end

-- A pillar on a joint: a plinth, a stack of blocks, a cap and the area's topper.
local function pillar(f: Instance, at: CFrame, h: number, s: Spec, rng: Random)
	local colors = if s.kind == "fence" then { s.cap } else s.main
	block(f, Vector3.new(U * 2.3, U * 0.6, U * 2.3), at * CFrame.new(0, U * 0.3, 0), shade({ s.base }, rng))
	local y = U * 0.6
	local seg = (h - U * 1.6) / 3
	for i = 0, 2 do
		local wv = U * (1.7 - i * 0.05)
		block(f, Vector3.new(wv, seg, wv), at * CFrame.new(0, y + seg / 2, 0) * CFrame.Angles(0, (i % 2) * 0.06, 0), shade(colors, rng))
		y += seg
	end
	block(f, Vector3.new(U * 2.1, U * 0.5, U * 2.1), at * CFrame.new(0, y + U * 0.25, 0), shade({ s.cap }, rng))
	local t = block(f, Vector3.new(U * 0.9, U * 0.9, U * 0.9), at * CFrame.new(0, y + U * 0.5 + U * 0.45, 0) * CFrame.Angles(0, math.rad(45), 0), s.topper, if s.topperNeon then NEON else SP)
	t.Name = "Topper"
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

local function rimAt(ctx: Ctx, a: number, rad: number): CFrame
	local c = ctx.centre
	local pos = c + Vector3.new(math.sin(a), 0, math.cos(a)) * rad
	return CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
end

-- the area's decorations: its ForgeGUI ones on every third spot, its voxel bushes, rocks and clumps
-- (server/VoxelModels names) on the rest
local function props(ctx: Ctx, f: Instance, rng: Random)
	local id = ctx.look.id
	local forge = {}
	for _, n in ctx.look.props do
		if loaded(n) then
			table.insert(forge, n)
		end
	end
	local list = { "Bush_" .. id, "Rock_" .. id, "Clump_" .. id .. "_1", "Bush_" .. id, "Rock_" .. id .. "_big", "Clump_" .. id .. "_2" }
	local spots = 14
	for s = 0, spots - 1 do
		local t = (s + 0.5) / spots
		-- none within 40 degrees of the entrance
		if math.min(t, 1 - t) * 360 < 40 then
			continue
		end
		if #forge > 0 and s % 3 == 0 then
			local fname = forge[(s // 3) % #forge + 1]
			local at = rimAt(ctx, ctx.yaw0 + t * 2 * math.pi, ctx.r - 6.5) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0)
			local m = Models.placeForge(fname, f, at, { height = rng:NextNumber(5.5, 7.5), width = 9, depth = 8 }, true)
			if m then
				m.Name = "Prop"
				continue
			end
		end
		local name = list[s % #list + 1]
		local size = VoxelModels.size(name)
		if not size or not VoxelModels.has(name) then
			continue
		end
		-- about 4 to 6 studs tall, against the wall
		local k = math.min(rng:NextNumber(4, 6) / size.Y, 8 / math.max(size.X, size.Z))
		local depth = math.max(size.X, size.Z) * k
		local at = rimAt(ctx, ctx.yaw0 + t * 2 * math.pi + rng:NextNumber(-0.03, 0.03), ctx.r - 2.2 - depth / 2)
		local m = VoxelModels.place(f, name, at.Position, { scale = k, yaw = rng:NextNumber(0, 2 * math.pi), shadow = true })
		if m then
			m.Name = "Prop"
		end
	end
end

-- The wall sections, the pillars between them and the props inside (the area's look). Returns false when the area
-- has no look (BossArena then builds its part walls).
function ArenaDress.wall(ctx: Ctx): boolean
	local s = ctx.look.spec
	local folder = Instance.new("Folder")
	folder.Name = "Dress"
	folder.Parent = ctx.model
	local rng = Random.new(ctx.segs * 31 + #ctx.look.id * 7)
	-- sections: every segment but the two either side of the entrance (BossArena's gap); a touch wider than the
	-- segment so neighbours meet on the curve
	local look = ctx.look
	local size = look.wall and wallSize(look.wall, ctx.segW + 0.4)
	for i = 1, ctx.segs - 2 do
		local a = ctx.yaw0 + (i + 0.5) / ctx.segs * 2 * math.pi
		local at = rimAt(ctx, a, ctx.r)
		local m = size and placeBox(look.wall :: string, folder, at, size)
		if m then
			m.Name = "WallSection"
		else
			section(folder, at, ctx.segW + 0.3, s, rng)
		end
	end
	-- pillars on the joints (the two at the entrance are the gateway's): the area's ForgeGUI pillar, block ones with
	-- the block wall, none for a ForgeGUI wall without its pillar (its sections have their own ends)
	local postH = if size then size.Y * 1.45 else U * 5.4
	for j = 2, ctx.segs - 2 do
		local at = rimAt(ctx, ctx.yaw0 + j / ctx.segs * 2 * math.pi, ctx.r)
		if look.post then
			local m = Models.placeForge(look.post, folder, at, { height = postH, width = 4.2, depth = 4.2 }, true)
			if m then
				m.Name = "WallPillar"
			end
		elseif not size then
			pillar(folder, at, postH, s, rng)
		end
	end
	props(ctx, folder, rng)
	return true
end

-- The gateway over the entrance: two block towers standing exactly on the wall's two ends either side of the gap,
-- a lintel across, the area's trim and a glowing crest. Returns the model (BossArena floats the boss name over it).
function ArenaDress.gate(ctx: Ctx): Model
	local s = ctx.look.spec
	if ctx.look.gate then
		-- the area's ForgeGUI gateway, its pillars on the wall's ends (the gap is about 2r sin(2pi/segs) wide)
		local gatePos = ctx.centre + ctx.facing * ctx.r
		local gap = 2 * ctx.r * math.sin(2 * math.pi / ctx.segs)
		local g = Models.placeForge(ctx.look.gate, ctx.model, CFrame.lookAt(gatePos, gatePos + ctx.facing), { width = gap + 4, height = 26 }, true)
		if g then
			g.Name = "ArenaGate"
			return g
		end
	end
	local m = Instance.new("Model")
	m.Name = "ArenaGate"
	local rng = Random.new(ctx.segs * 17 + #ctx.look.id)
	local ends = {}
	for _, j in { 1, ctx.segs - 1 } do
		table.insert(ends, rimAt(ctx, ctx.yaw0 + j / ctx.segs * 2 * math.pi, ctx.r))
	end
	local H = 15
	local colors = if s.kind == "fence" then { s.cap, s.main[1] } else s.main
	for _, at in ends do
		block(m, Vector3.new(U * 3.4, U * 0.8, U * 3.4), at * CFrame.new(0, U * 0.4, 0), shade({ s.base }, rng))
		local y = U * 0.8
		local n = 5
		local seg = (H - y) / n
		for i = 0, n - 1 do
			local wv = U * (2.8 - (i % 2) * 0.2)
			block(m, Vector3.new(wv, seg, wv), at * CFrame.new(0, y + seg / 2, 0), shade(colors, rng))
			y += seg
		end
		-- the area's trim up the tower's inner face
		dots(m, at, U * 2.4, U * 1, -U * 1.45, 3, s.trim, rng, 0.8)
	end
	-- the lintel: from tower to tower, two rows, then a crest of blocks rising to the middle
	local a, b = ends[1].Position, ends[2].Position
	local mid = (a + b) / 2
	local span = (b - a).Magnitude + U * 3.4
	local across = CFrame.fromMatrix(mid, (b - a).Unit, Vector3.yAxis) -- X runs tower to tower
	row(m, across, -span / 2, span / 2, H, U * 1.1, U * 2.6, 0, { s.cap }, rng)
	row(m, across, -span / 2 + U, span / 2 - U, H + U * 1.1, U * 0.9, U * 2.2, 0, colors, rng)
	for i = -2, 2 do
		local h = U * (1.2 - math.abs(i) * 0.3)
		block(m, Vector3.new(U * 1.2, h, U * 1.2), across * CFrame.new(i * U * 1.6, H + U * 2 + h / 2, 0), shade(colors, rng))
	end
	local crest = block(m, Vector3.new(U * 1.3, U * 1.3, U * 1.3), across * CFrame.new(0, H + U * 2 + U * 1.2 + U * 0.65, 0) * CFrame.Angles(0, 0, math.rad(45)), s.topper, NEON)
	crest.Name = "Crest"
	-- glowing blocks along the lintel's inner and outer faces
	for side = -1, 1, 2 do
		for i = -3, 3, 2 do
			block(m, Vector3.new(U * 0.5, U * 0.5, 0.2), across * CFrame.new(i * U * 1.8, H + U * 0.55, side * U * 1.32), ctx.look.accent, NEON)
		end
	end
	m.Parent = ctx.model
	return m
end

-- A ring of blocks round the summon pad, sunk so only a low step shows, with four corner blocks carrying the area's
-- glow (the pad itself and how it's read are BossArena's / server/Boss's).
function ArenaDress.altar(ctx: Ctx, padPos: Vector3)
	local s = ctx.look.spec
	local m = Instance.new("Model")
	m.Name = "SummonAltar"
	local rng = Random.new(91)
	local n = 16
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		local pos = padPos + Vector3.new(math.sin(a), 0, math.cos(a)) * 7.6
		local cf = CFrame.lookAt(pos, padPos)
		block(m, Vector3.new(3.1, 0.7, 1.6), cf * CFrame.new(0, 0.35, 0), shade({ ctx.look.rim, ctx.look.rim:Lerp(Color3.new(1, 1, 1), 0.15) }, rng))
	end
	for i = 0, 3 do
		local a = (i + 0.5) / 4 * 2 * math.pi
		local pos = padPos + Vector3.new(math.sin(a), 0, math.cos(a)) * 9.2
		block(m, Vector3.new(U * 1.4, U * 1.6, U * 1.4), CFrame.new(pos + Vector3.new(0, U * 0.8, 0)) * CFrame.Angles(0, a, 0), shade(s.main, rng))
		block(m, Vector3.new(U * 0.8, U * 0.8, U * 0.8), CFrame.new(pos + Vector3.new(0, U * 1.6 + U * 0.4, 0)) * CFrame.Angles(0, a + math.rad(45), 0), s.topper, if s.topperNeon then NEON else SP)
	end
	m.Parent = ctx.model
end

return ArenaDress
