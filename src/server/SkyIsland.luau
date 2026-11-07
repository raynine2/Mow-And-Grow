--!strict
-- THE LOBBY AS A FLOATING ISLAND (7 Nov 2026; owner: "remake starting lobby its bad and needs to be better DEEP
-- RESEARCH OTHER LOBBIES WITH VOXEL STYLE AND MAKE IT GOOD LIKE THEIRS AND USE REFERENCE PICS". Asked what was bad, he
-- picked "cluttered", "looks cheap" and "unclear layout"; for the look, "a floating island".)
-- From the research (Minecraft Dungeons' camp, Hypixel / CubeCraft / The Hive hubs, Tower Defense Simulator's
-- elevators, Chop A Forest, voxel artists on 80.lv):
--   * You spawn facing the ONE hero (the ForgeGUI windmill), the start between you and it: the five pads in one arc at
--     its foot, all the same piece with one sign style (server/LandsBuilder's tested pads).
--   * The two stations FLANK the start, like the merchants either side of Dungeons' mission table: CLASSES (the blue
--     house) on the right, the GARAGE on the left, each on its own lobe of the island, fronts to the middle.
--   * The free rewards next to the spawn (left), a fountain mirroring them (right); GRASS CUT and BEST TIMES at the
--     plaza's sides, turned to the spawn.
--   * Clear middle, busy rims: a mown lawn in stripes running to the windmill, walks only where people go; trees in
--     clusters of three sizes on low mounds round the rim, cherry pink only where the eye should land.
--   * The edge is a drop to the sky: the island's underside is half the build (a stepped, uneven cone of grass, dirt,
--     then darker and darker stone), two waterfalls pour off the back, voxel clouds drift below.
--   * The turn-around test: behind the spawn a lookout at the rim faces the starlight observatory on a high island
--     of its own; round the horizon the seven other run areas float as small islands, each with its ForgeGUI landmark.
-- Lobby space: y = 0 the island's top, +Z north (spawn to windmill), +X to your LEFT as you face the windmill.
-- Every working piece (pads, stations, boards, spawn) is the same as before, so server/Lobby needs nothing new.
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local VM = require(script.Parent.VoxelModels)
local Environment = require(script.Parent.Environment)
local LobbyKit = require(script.Parent.LobbyKit)
local Layout = require(script.Parent.LobbyLayout)
local Ground = require(script.Parent.Ground)

local SkyIsland = {}
SkyIsland.ON = true

local C = Color3.fromRGB
local terrain = workspace.Terrain
local SINK = 2 -- (smooth terrain draws its surface 2 studs above a fill's top: server/Ground)

local SPAWN = Vector3.new(0, 0, -50)
local HERO = Vector3.new(0, 0, 60)
local PAD_R = 36 -- the pads' arc round the windmill's middle
local WALK_R = PAD_R + 11 -- the curved walk in front of them
local WALK_ARC = 60
local CLASSES = Vector3.new(-62, 0, 24)
local GARAGE = Vector3.new(62, 0, 24)
local FORE = 16.5 -- a station's round forecourt, this far in front of its middle
local FOUNTAIN = Vector3.new(-26, 0, -50)
local LOOKOUT = Vector3.new(0, 0, -94)
local PADS = { -- (degrees from the axis, + to the left as you face the windmill; pad 1 is SOLO for the guide arrow)
	{ a = 0, kind = "solo" },
	{ a = 24, kind = "party" },
	{ a = -24, kind = "party" },
	{ a = -48, kind = "party" },
	{ a = 48, kind = "continue" },
}
-- the island: overlapping round lobes, each with its own stepped underside (depth below the 8-stud grass slab; the
-- saved map keeps terrain down to y = -120: server/MapStore). Seen in Studio: shallower, the union of the cones read
-- as a flat pancake with lumps; deep ones make the inverted cone of a floating island, the plaza's the deepest point.
local LOBES = {
	{ x = 0, z = 0, r = 72, depth = 92 }, -- the plaza
	{ x = 0, z = -60, r = 46, depth = 58 }, -- the spawn, the rewards and the fountain
	{ x = 0, z = 64, r = 50, depth = 74 }, -- the windmill and the pads
	{ x = -62, z = 26, r = 32, depth = 46 }, -- classes
	{ x = 62, z = 26, r = 32, depth = 46 }, -- the garage
	{ x = -50, z = -18, r = 26, depth = 36 }, -- the sides by the spawn
	{ x = 50, z = -18, r = 26, depth = 36 },
	{ x = -38, z = 94, r = 26, depth = 40 }, -- the back corners, the waterfalls
	{ x = 38, z = 94, r = 26, depth = 40 },
}
-- the run areas round the horizon (angle from north, + to the left), and the observatory behind the spawn
local ISLES = {
	{ lm = "lm_wheat", tree = "wheat", a = 38, d = 190, y = 10, r = 22, mat = Enum.Material.Sand },
	{ lm = "lm_blossom", tree = "blossom", a = -38, d = 190, y = 16, r = 22, mat = Enum.Material.Limestone },
	{ lm = "lm_pine", tree = "pine", a = 74, d = 205, y = -4, r = 24, mat = Enum.Material.Slate },
	{ lm = "lm_swamp", tree = "swamp", a = -74, d = 205, y = 2, r = 24, mat = Enum.Material.Mud },
	{ lm = "lm_frost", tree = "frost", a = 112, d = 210, y = 26, r = 22, mat = Enum.Material.Snow },
	{ lm = "lm_ember", tree = "ember", a = -112, d = 210, y = 20, r = 22, mat = Enum.Material.CrackedLava },
	{ lm = "lm_starlight", tree = "isles", a = 180, d = 215, y = 42, r = 26, mat = Enum.Material.Pavement, big = true },
}

-- where server/LobbyBuilder's stations stand (set at build time: server/LandsBuilder sets its own when it loads)
local function setLayout()
	Layout.SPAWN = SPAWN
	Layout.REWARDS = { pos = Vector3.new(-FOUNTAIN.X + 6.6, 0, FOUNTAIN.Z) }
	-- (seen in Studio at (48, -16): from the spawn they stood right in front of the garage and classes) out to the
	-- spawn's sides
	Layout.GRASS_CUT = { pos = Vector3.new(40, 0, -30) }
	Layout.BEST_TIMES = { pos = Vector3.new(-40, 0, -30) }
end

local count = 0
local function tick()
	count += 1
	if count % 250 == 0 then
		task.wait()
	end
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	tick()
	return p
end

local function ghost(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function folder(parent: Instance, name: string): Folder
	return PropKit.folder(name, parent)
end

-- A point on the circle round the windmill, `a` degrees off the axis toward the spawn.
local function arc(a: number, r: number): Vector3
	local t = math.rad(a)
	return HERO + Vector3.new(math.sin(t) * r, 0, -math.cos(t) * r)
end

local function inIsland(x: number, z: number, grow: number): boolean
	for _, l in LOBES do
		local dx, dz = x - l.x, z - l.z
		if dx * dx + dz * dz <= (l.r + grow) * (l.r + grow) then
			return true
		end
	end
	return false
end

-- The island's edge along the ray from (0, 0, 4) at `deg` degrees (0 = north, + to the left): how far out it is.
local MID = Vector3.new(0, 0, 4)
local function rimAt(deg: number): number
	local d = Vector3.new(math.sin(math.rad(deg)), 0, math.cos(math.rad(deg)))
	local last = 0
	for t = 0, 160, 1 do
		local p = MID + d * t
		if inIsland(p.X, p.Z, 0) then
			last = t
		end
	end
	return last
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundY(x: number, z: number, from: number?): number
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local top = from or 60
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -top - 80, 0), groundParams)
	return if hit and hit.Material ~= Enum.Material.Water then hit.Position.Y else 0
end

-------------------------------------------------------------------------------------------------------------
-- the island (Roblox terrain, as the runs' ground)
-------------------------------------------------------------------------------------------------------------
local function terrainLook()
	for prop, v in { Decoration = true, GrassLength = 0.3 } do
		pcall(function()
			(terrain :: any)[prop] = v
		end)
	end
	local colours = {
		[Enum.Material.Grass] = C(80, 164, 48), -- the lawn
		[Enum.Material.LeafyGrass] = C(132, 204, 72), -- its lighter mown stripes (seen in Studio: closer, they didn't show)
		[Enum.Material.Ground] = C(132, 94, 60), -- dirt under the grass lip, under the walks
		[Enum.Material.Sandstone] = C(168, 124, 82), -- the first band of rock
		[Enum.Material.Rock] = C(122, 112, 104), -- grey stone
		[Enum.Material.Basalt] = C(78, 70, 74), -- dark stone at the bottom
		[Enum.Material.Sand] = C(214, 178, 92), -- the wheat isle
		[Enum.Material.Limestone] = C(226, 168, 190), -- the blossom isle's petals
		[Enum.Material.Slate] = C(54, 116, 60), -- the pine isle
		[Enum.Material.Mud] = C(86, 98, 66), -- the swamp isle
		[Enum.Material.Snow] = C(236, 244, 255), -- the frost isle
		[Enum.Material.CrackedLava] = C(255, 106, 40), -- the ember isle
		[Enum.Material.Pavement] = C(120, 132, 200), -- the observatory's isle
	}
	for mat, col in colours do
		terrain:SetMaterialColor(mat, col)
	end
end

local function layerMat(f: number): Enum.Material
	if f < 0.14 then
		return Enum.Material.Ground
	elseif f < 0.42 then
		return Enum.Material.Sandstone
	elseif f < 0.74 then
		return Enum.Material.Rock
	end
	return Enum.Material.Basalt
end

-- A stepped, uneven cone under a disc whose grass top is at `top`: 4-stud layers, each a little narrower (a lip of
-- grass overhangs the first), drifting off-centre the deeper it goes, with lumps round the lower ones.
local function underside(x: number, z: number, r: number, top: number, depth: number, rng: Random)
	local T = 4
	local n = math.max(2, math.floor(depth / T))
	local ox, oz = 0, 0
	for k = 1, n do
		local f = k / n
		local rk = r * (1 - f) ^ 0.85 - 1.2
		if rk < 2 then
			break
		end
		ox += rng:NextNumber(-1.2, 1.2)
		oz += rng:NextNumber(-1.2, 1.2)
		local y = top - 8 - (k - 0.5) * T - SINK
		terrain:FillCylinder(CFrame.new(x + ox, y, z + oz), T, rk, layerMat(f))
		if f > 0.25 and rk > 6 then
			for _ = 1, 3 do
				local a = rng:NextNumber(0, math.pi * 2)
				local lr = rng:NextNumber(2.5, math.min(7, rk * 0.4))
				terrain:FillBall(Vector3.new(x + ox + math.sin(a) * rk * 0.8, y - lr * 0.4, z + oz + math.cos(a) * rk * 0.8), lr, layerMat(math.min(1, f + 0.15)))
			end
		end
	end
	-- a hanging tip or two under the deepest layer
	for _ = 1, 2 do
		local tx, tz = x + ox + rng:NextNumber(-r * 0.15, r * 0.15), z + oz + rng:NextNumber(-r * 0.15, r * 0.15)
		terrain:FillBall(Vector3.new(tx, top - 8 - depth - SINK + 2, tz), math.max(2, r * 0.12), Enum.Material.Basalt)
	end
end

local function island()
	local rng = Random.new(7117)
	for _, l in LOBES do
		terrain:FillCylinder(CFrame.new(l.x, -4 - SINK, l.z), 8, l.r, Enum.Material.Grass)
	end
	task.wait()
	for _, l in LOBES do
		underside(l.x, l.z, l.r, 0, l.depth, rng)
		task.wait()
	end
end

-- Mown stripes, 8 studs wide, running from the spawn to the windmill (the game's own signature; leading lines to the
-- hero): the lawn's top cells turn LeafyGrass every other stripe. Walks and dirt painted later cover them.
local function stripes()
	local region = Region3.new(Vector3.new(-128, -8, -128), Vector3.new(128, 4, 128)):ExpandToGrid(4)
	local mats, occ = terrain:ReadVoxels(region, 4)
	local size = mats.Size
	local x0 = region.CFrame.Position.X - region.Size.X / 2
	for ix = 1, size.X do
		local cx = x0 + (ix - 0.5) * 4
		if math.floor((cx + 4) / 8) % 2 == 0 then
			for iz = 1, size.Z do
				for iy = 1, size.Y do
					if mats[ix][iy][iz] == Enum.Material.Grass and (iy == size.Y or mats[ix][iy + 1][iz] == Enum.Material.Air) then
						mats[ix][iy][iz] = Enum.Material.LeafyGrass
					end
				end
			end
		end
	end
	terrain:WriteVoxels(region, 4, mats, occ)
end

-------------------------------------------------------------------------------------------------------------
-- walks
-------------------------------------------------------------------------------------------------------------
local function walkAreas(): { any }
	local function v2(p: Vector3): Vector2
		return Vector2.new(p.X, p.Z)
	end
	local cFore = Vector2.new(CLASSES.X + FORE, CLASSES.Z)
	local gFore = Vector2.new(GARAGE.X - FORE, GARAGE.Z)
	return {
		{ kind = "disc", c = v2(SPAWN), r = 10, medallion = true },
		{ kind = "disc", c = cFore, r = 6.5 },
		{ kind = "disc", c = gFore, r = 6.5 },
		{ kind = "seg", a = v2(SPAWN), b = v2(arc(0, WALK_R)), w = 10 },
		{ kind = "arc", c = v2(HERO), r = WALK_R, w = 7, a0 = -WALK_ARC, a1 = WALK_ARC },
		{ kind = "seg", a = cFore, b = v2(arc(-WALK_ARC, WALK_R)), w = 6 },
		{ kind = "seg", a = gFore, b = v2(arc(WALK_ARC, WALK_R)), w = 6 },
		-- the rewards stall's apron (left of the spawn) and the fountain's (right), each with a short walk
		{ kind = "disc", c = Vector2.new(-FOUNTAIN.X, FOUNTAIN.Z), r = 9 },
		{ kind = "seg", a = Vector2.new(SPAWN.X + 9, SPAWN.Z), b = Vector2.new(-FOUNTAIN.X - 8.5, FOUNTAIN.Z), w = 5 },
		{ kind = "disc", c = v2(FOUNTAIN), r = 9 },
		{ kind = "seg", a = Vector2.new(SPAWN.X - 9, SPAWN.Z), b = Vector2.new(FOUNTAIN.X + 8.5, FOUNTAIN.Z), w = 5 },
		-- the lookout behind the spawn, at the rim
		{ kind = "seg", a = Vector2.new(SPAWN.X, SPAWN.Z - 9), b = v2(LOOKOUT), w = 6 },
		{ kind = "disc", c = v2(LOOKOUT), r = 7.5 },
	}
end

local function walkDirt()
	for _, a in walkAreas() do
		if a.kind == "disc" then
			Ground.disc(a.c.X, a.c.Y, a.r + 0.9, Enum.Material.Ground)
		elseif a.kind == "seg" then
			local A, B = a.a :: Vector2, a.b :: Vector2
			local mid = (A + B) / 2
			local y = -4 - SINK
			terrain:FillBlock(CFrame.lookAt(Vector3.new(mid.X, y, mid.Y), Vector3.new(B.X, y, B.Y)), Vector3.new(a.w + 1.6, 8, (B - A).Magnitude + 1.2), Enum.Material.Ground)
		else
			for t = a.a0, a.a1, 1 do
				local p = arc(t, a.r)
				Ground.disc(p.X, p.Z, a.w / 2 + 0.8, Enum.Material.Ground)
			end
		end
	end
end

local function covers(x: number, z: number, grow: number): boolean
	return require(script.Parent.LobbyPaving).covers(walkAreas(), Vector2.new(x, z), grow)
end

-------------------------------------------------------------------------------------------------------------
-- trees, bushes, lamps
-------------------------------------------------------------------------------------------------------------
-- What must stay clear of trees: the stations, the pads and the hero's front, the boards, the views.
local KEEP = {
	{ p = HERO, r = 30 },
	{ p = CLASSES, r = 20 },
	{ p = GARAGE, r = 20 },
	{ p = Vector3.new(40, 0, -30), r = 12 },
	{ p = Vector3.new(-40, 0, -30), r = 12 },
	{ p = Vector3.new(-FOUNTAIN.X + 6.6, 0, FOUNTAIN.Z), r = 15 },
	{ p = FOUNTAIN, r = 13 },
	{ p = LOOKOUT, r = 14 },
}
local function kept(p: Vector3, room: number): boolean
	for _, k in KEEP do
		if (Vector3.new(p.X, 0, p.Z) - k.p).Magnitude < k.r + room then
			return true
		end
	end
	return covers(p.X, p.Z, room + 2)
end

local function tree(parent: Instance, kind: string, foot: Vector3, scale: number, rng: Random)
	local name = "Tree_" .. kind .. "_" .. rng:NextInteger(1, 3)
	if not VM.has(name) then
		name = "Tree_meadow_" .. rng:NextInteger(1, 3)
	end
	local s = scale * 0.75
	local y = groundY(foot.X, foot.Z, foot.Y + 40) - 0.3
	local at = Vector3.new(foot.X, y, foot.Z)
	VM.place(parent, name, at, { scale = s, yaw = rng:NextInteger(0, 3) * math.pi / 2 })
	VM.blocker(parent, Vector3.new(4.8 * s, 20 * s, 4.8 * s), CFrame.new(at + Vector3.new(0, 10 * s, 0)))
end

-- Clusters of three round the rim (a big tree and two smaller), on low mounds, mirrored left and right so the
-- edge reads as planted. Pines at the back behind the windmill, cherry pink only where the eye should land (either
-- side of the windmill, behind the two stations); the south rim stays low (bushes) so the lookout sees the sky.
local function rimTrees(world: Instance)
	local f = folder(world, "RimTrees")
	local rng = Random.new(2611)
	local step = 15
	for deg = 0, 180, step do
		local r = rimAt(deg)
		for _, side in { 1, -1 } do
			local a = deg * side
			if not (side == -1 and (deg == 0 or deg == 180)) then
				local t = math.rad(a)
				local dir = Vector3.new(math.sin(t), 0, math.cos(t))
				local c = MID + dir * (r - 13)
				local south = deg > 112 -- (seen in Studio: a big tree by the fountain crowded the spawn; low there)
				if not kept(c, 6) then
					if south then
						local bush = if (deg // step) % 2 == 0 then "Bush_meadow" else "Bush_blossom"
						VM.place(f, bush, Vector3.new(c.X, groundY(c.X, c.Z), c.Z), { scale = 0.75, yaw = t, collide = true })
					else
						Ground.hill(c.X, c.Z, 7.5, 2.2, Enum.Material.Grass)
						local kind = if deg <= 30 then "pine" elseif (deg == 45 or deg == 105) then "blossom" else "meadow"
						local local_rng = Random.new(deg * 31 + 7) -- (the same cluster on both sides)
						local right = dir:Cross(Vector3.yAxis)
						tree(f, kind, c, 1.35, local_rng)
						tree(f, kind, c + right * 5.5 - dir * 3, 1.0, local_rng)
						tree(f, if kind == "pine" then "meadow" else kind, c - right * 5 - dir * 2.5, 0.8, local_rng)
					end
				end
			end
		end
		task.wait()
	end
	-- the rise behind the windmill: a taller backdrop of pines on a long hill
	Ground.hill(0, 104, 16, 5, Enum.Material.Grass)
	for _, x in { -12, 0, 12 } do
		tree(f, "pine", Vector3.new(x, 0, 104 - math.abs(x) * 0.3), if x == 0 then 1.9 else 1.5, rng)
	end
end

-- The made things, in pairs about the axis: lamps along the walk to the pads and between the pads, flowering bushes
-- where the axis meets the curved walk, bushes round the stations' feet (seating the smooth ForgeGUI buildings in
-- the voxel world), a fountain mirroring the rewards stall, benches and a fence at the lookout.
local function lamp(parent: Instance, p: Vector3, look: Vector3)
	if not Models.place("lantern_post", parent, CFrame.lookAt(p, Vector3.new(look.X, p.Y, look.Z)), 0.9, true) then
		VM.place(parent, "S_lantern_post", p, { collide = true })
	end
end

local function dressing(world: Instance)
	local f = folder(world, "Dressing")
	for _, z in { -36, -18, 0 } do
		for _, sx in { -1, 1 } do
			lamp(f, Vector3.new(sx * 7.6, 0, z), Vector3.new(0, 0, z))
		end
	end
	for _, a in { -36, -12, 12, 36 } do
		lamp(f, arc(a, WALK_R + 5.6), arc(a, WALK_R))
	end
	for _, sx in { -1, 1 } do
		VM.place(f, "Bush_blossom", Vector3.new(sx * 13, 0, 8), { scale = 0.5, yaw = math.pi / 2, collide = true })
		VM.place(f, "Bush_blossom", Vector3.new(sx * 13, 0, -40), { scale = 0.45, yaw = math.pi / 2, collide = true })
	end
	-- the stations' feet: bushes at the back corners and the sides, never in front of a door
	for _, st in { { p = CLASSES, front = 1 }, { p = GARAGE, front = -1 } } do
		for _, off in { { -13, -12 }, { -13, 12 }, { -4, -14 }, { -4, 14 } } do
			local p = st.p + Vector3.new(off[1] * st.front, 0, off[2])
			VM.place(f, if math.abs(off[2]) == 14 then "Bush_meadow" else "Bush_blossom", p, { scale = 0.6, yaw = 0, collide = true })
		end
	end
	-- the fountain, mirroring the rewards stall, with butterflies (client/LobbyFX)
	local g = folder(world, "FountainGarden")
	local fm = Models.placeForge("fountain", g, CFrame.lookAt(FOUNTAIN, Vector3.new(SPAWN.X, 0, SPAWN.Z)), { width = 9 }, false)
	local top = FOUNTAIN + Vector3.new(0, 4, 0)
	if fm then
		local box, size = fm:GetBoundingBox()
		top = Vector3.new(FOUNTAIN.X, box.Position.Y + size.Y / 2 - 0.6, FOUNTAIN.Z)
	end
	LobbyKit.tag(LobbyKit.spot(g, CFrame.new(top), Vector3.new(1, 1, 1), "FountainFX"), "LobbyFX", { Kind = "fountain", Color = C(170, 225, 255) })
	LobbyKit.tag(LobbyKit.spot(g, CFrame.new(FOUNTAIN + Vector3.new(0, 3, 0)), Vector3.new(16, 4, 16), "Butterflies"), "LobbyFX", { Kind = "butterflies", Color = C(255, 214, 90) })
	-- (seen in Studio, turned round at the spawn: the lawn to the lookout was bare) lamps in pairs along its walk,
	-- flowering bushes and low hedges either side, so the back has its own picture: the walk, then the observatory
	for _, z in { -64, -78 } do
		for _, sx in { -1, 1 } do
			lamp(f, Vector3.new(sx * 5.4, 0, z), Vector3.new(0, 0, z))
		end
	end
	for _, sx in { -1, 1 } do
		for k, off in { { 14, -70 }, { 22, -80 }, { 11, -86 }, { 26, -66 } } do
			local p = Vector3.new(sx * off[1], 0, off[2])
			VM.place(f, if k % 2 == 1 then "Bush_blossom" else "Bush_meadow", p, { scale = if k == 1 then 0.62 else 0.5, yaw = k, collide = true })
		end
	end
	-- the lookout: two benches facing out to the observatory's island, a fence along the rim side
	local lk = folder(world, "Lookout")
	for _, sx in { -1, 1 } do
		local p = LOOKOUT + Vector3.new(sx * 3.4, 0, 1.5)
		VM.place(lk, "Prop_bench", p, { yaw = math.pi, collide = true })
	end
	for _, a in { -50, -25, 0, 25, 50 } do
		local t = math.rad(a)
		local p = LOOKOUT + Vector3.new(math.sin(t) * 9, 0, -math.cos(t) * 9)
		VM.place(lk, "S_fence", p, { yaw = t, collide = true })
	end
end

-------------------------------------------------------------------------------------------------------------
-- the edge: waterfalls, clouds, the far isles, the walls
-------------------------------------------------------------------------------------------------------------
local WATER = C(118, 206, 255)

local function emitter(parent: BasePart, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightEmission = 0.3
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
end

-- A pond on the back lobe spilling over the rim: a short run of water to the edge, then a sheet falling in stacked
-- voxel slabs (wider as it falls) with spray running down it and mist where it meets the clouds.
local function waterfall(world: Instance, lobe: any, deg: number)
	local f = folder(world, "Waterfall")
	local t = math.rad(deg)
	local dir = Vector3.new(math.sin(t), 0, math.cos(t))
	local rim = Vector3.new(lobe.x, 0, lobe.z) + dir * lobe.r
	local pond = Vector3.new(lobe.x, 0, lobe.z) + dir * (lobe.r * 0.45)
	Ground.water(pond.X, pond.Z, 11, 11, 3)
	local look = CFrame.lookAt(pond, rim)
	local len = (rim - pond).Magnitude - 5
	local run = block(f, "Stream", Vector3.new(6.5, 0.4, len), look * CFrame.new(0, 0.15, -5.5 - len / 2), WATER, Enum.Material.Glass)
	run.Transparency = 0.25
	ghost(run)
	local edge = CFrame.lookAt(rim + dir * 2.6, rim + dir * 4)
	local y = 0
	local k = 0
	while y > -104 do
		local h = 6
		local w = 6.5 + k * 0.3
		local s = block(f, "Fall", Vector3.new(w, h, 1.4), edge * CFrame.new(math.sin(k * 1.7) * 0.4, y - h / 2, -k * 0.12), WATER, Enum.Material.Glass)
		s.Transparency = 0.18 + (k % 2) * 0.08
		ghost(s)
		y -= h
		k += 1
	end
	local lip = block(f, "Foam", Vector3.new(7.2, 0.8, 1.8), edge * CFrame.new(0, 0.1, 0), C(240, 250, 255))
	ghost(lip)
	local spray = block(f, "Spray", Vector3.new(5, 1, 1), edge * CFrame.new(0, -1, -0.8), Color3.new(1, 1, 1))
	spray.Transparency = 1
	ghost(spray)
	emitter(spray, {
		Rate = 26,
		Lifetime = NumberRange.new(2.2, 3),
		Speed = NumberRange.new(4, 8),
		Acceleration = Vector3.new(0, -30, 0),
		SpreadAngle = Vector2.new(6, 6),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 4.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(C(235, 248, 255)),
		EmissionDirection = Enum.NormalId.Bottom,
	})
	local mist = block(f, "Mist", Vector3.new(12, 2, 8), edge * CFrame.new(0, -100, -8), Color3.new(1, 1, 1))
	mist.Transparency = 1
	ghost(mist)
	emitter(mist, {
		Rate = 6,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
	})
end

-- A cloud: a cluster of soft white balls on a flatter base, the skybox's painted clouds in 3D. (Seen in Studio: the
-- first try, white boxes stacked like voxels, read as foam blocks floating about.)
local function cloud(parent: Instance, at: Vector3, size: number, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Cloud"
	local n = rng:NextInteger(5, 8)
	for i = 1, n do
		local t = (i - 1) / math.max(1, n - 1)
		local x = (t - 0.5) * size * 1.1 + rng:NextNumber(-size * 0.08, size * 0.08)
		local r = size * (0.22 + 0.2 * math.sin(t * math.pi)) * rng:NextNumber(0.85, 1.15)
		local p = block(m, "Puff", Vector3.new(r * 2, r * 1.5, r * 2), CFrame.new(at + Vector3.new(x, r * 0.3, rng:NextNumber(-size * 0.15, size * 0.15))), C(255, 255, 255))
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.06
		ghost(p)
	end
	-- the flat underside, a touch greyer
	local base = block(m, "Puff", Vector3.new(size * 1.3, size * 0.18, size * 0.6), CFrame.new(at - Vector3.new(0, size * 0.02, 0)), C(232, 238, 250))
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, 0, math.rad(90))
	base.Size = Vector3.new(size * 0.16, size * 1.25, size * 1.25)
	base.Transparency = 0.1
	ghost(base)
	m.Parent = parent
end

local function clouds(world: Instance)
	local f = folder(world, "Clouds")
	local rng = Random.new(919)
	-- a sea of clouds far under the island (the void below reads as sky high above the ground, not as nothing)
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local d = rng:NextNumber(40, 300)
		cloud(f, Vector3.new(math.sin(a) * d, rng:NextNumber(-150, -122), math.cos(a) * d), rng:NextNumber(46, 80), rng)
	end
	-- a few drifting between the isles, below the rim
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4 + rng:NextNumber(-0.2, 0.2)
		local d = rng:NextNumber(130, 250)
		cloud(f, Vector3.new(math.sin(a) * d, rng:NextNumber(-60, -30), math.cos(a) * d), rng:NextNumber(26, 40), rng)
	end
end

-- Roots and vines hanging from under the grass lip all round (dirt-brown and leafy green, voxel-thin).
local function roots(world: Instance)
	local f = folder(world, "Roots")
	local rng = Random.new(4040)
	for deg = 0, 356, 6 do
		local r = rimAt(deg) - 1.5
		local t = math.rad(deg + rng:NextNumber(-2, 2))
		local p = MID + Vector3.new(math.sin(t) * r, 0, math.cos(t) * r)
		local len = rng:NextNumber(5, 15)
		local green = rng:NextNumber() < 0.45
		local col = if green then C(70, 132, 52) else C(104, 74, 48)
		local root = block(f, "Root", Vector3.new(0.8, len, 0.8), CFrame.new(p.X, -8 - len / 2 + 1, p.Z), col, Enum.Material.Grass)
		ghost(root)
		if green and len > 9 then
			local tip = block(f, "Root", Vector3.new(1.4, 1.4, 1.4), CFrame.new(p.X, -8 - len + 1, p.Z), C(96, 168, 70), Enum.Material.Grass)
			ghost(tip)
		end
	end
end

-- The run areas as small floating islands round the horizon, each with its ForgeGUI landmark and a few of its trees;
-- the observatory's (behind the spawn) bigger and higher.
local function isles(world: Instance)
	local f = folder(world, "Isles")
	local rng = Random.new(5150)
	for _, s in ISLES do
		local t = math.rad(s.a)
		local c = MID + Vector3.new(math.sin(t) * s.d, s.y, math.cos(t) * s.d)
		terrain:FillCylinder(CFrame.new(c.X, c.Y - 3 - SINK, c.Z), 6, s.r, s.mat)
		underside(c.X, c.Z, s.r, c.Y + 2, s.r * 1.2, rng)
		task.wait()
		local top = groundY(c.X, c.Z, c.Y + 20)
		local isle = folder(f, s.tree)
		local face = CFrame.lookAt(Vector3.new(c.X, top, c.Z), Vector3.new(MID.X, top, MID.Z))
		local h = if s.big then 36 else 26
		Models.placeForge(s.lm, isle, face, { height = h, width = h * 1.1, depth = h * 1.1 }, false)
		local out = (Vector3.new(c.X, 0, c.Z) - MID).Unit
		local right = out:Cross(Vector3.yAxis)
		for k = -1, 1 do
			local p = Vector3.new(c.X, top, c.Z) + out * (s.r * 0.55) + right * (k * s.r * 0.45)
			tree(isle, s.tree, p, if k == 0 then 1.2 else 0.9, rng)
		end
	end
end

-- Invisible walls a few studs in from the rim all round (you can walk to the edge and look down, not fall).
local function bounds(world: Instance)
	local f = folder(world, "Bounds")
	local pts = {}
	for deg = 0, 357, 3 do
		local r = rimAt(deg) - 3
		local t = math.rad(deg)
		table.insert(pts, MID + Vector3.new(math.sin(t) * r, 0, math.cos(t) * r))
	end
	for i, a in pts do
		local b = pts[i % #pts + 1]
		local len = (b - a).Magnitude
		if len > 0.2 then
			local wall = block(f, "Bound", Vector3.new(2, 90, len + 1.2), CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 30, 0), Color3.new(1, 1, 1))
			wall.Transparency = 1
			wall.CastShadow = false
			wall.CanQuery = false
			wall.CanTouch = false
		end
	end
end

-------------------------------------------------------------------------------------------------------------
function SkyIsland.build()
	local world = Environment.apply()
	if not Ground.locked and not Ground.keepTerrain then
		terrain:Clear() -- (a saved map's terrain is already in place; a bake clears just the lobby's box)
	end
	require(script.Parent.WorldGen).lighting()
	terrainLook()
	if not Ground.locked then
		island()
		stripes()
		walkDirt()
		task.wait()
		Ground.flatten(0, 4, 136)
	end
	require(script.Parent.LobbyPaving).lay(world, walkAreas())
	local kit = require(script.Parent.LandsBuilder).kit
	setLayout()
	local list = {}
	for _, p in PADS do
		table.insert(list, { pos = arc(p.a, PAD_R), toward = SPAWN, kind = p.kind })
	end
	local padDefs = kit.pads(world, list)
	kit.hero(world, HERO, SPAWN)
	local stockLabel, dummy = kit.classes(world, CLASSES, Vector3.xAxis, SPAWN)
	kit.garage(world, GARAGE, -Vector3.xAxis)
	local B = require(script.Parent.LobbyBuilder).stations
	B.rewards(world)
	kit.goldBays(world)
	local leaderLabel = B.leaderboard(world)
	local bestLabel = B.bestTimes(world)
	dressing(world)
	if not Ground.locked then
		rimTrees(world)
		for _, w in { { lobe = LOBES[8], deg = -40 }, { lobe = LOBES[9], deg = 40 } } do
			waterfall(world, w.lobe, w.deg)
		end
		isles(world)
	end
	clouds(world)
	if not Ground.locked then
		roots(world)
	end
	bounds(world)
	local sp = SPAWN + Vector3.new(0, 0.8, 0)
	Environment.spawn(world, CFrame.lookAt(sp, sp + Vector3.zAxis)) -- looking north at the pads and the windmill
	LobbyKit.tag(LobbyKit.spot(world, CFrame.new(0, 10, 0), Vector3.new(110, 14, 90), "Motes"), "LobbyFX", { Kind = "motes" })
	return { world = world, stockLabel = stockLabel, leaderLabel = leaderLabel, bestLabel = bestLabel, pads = padDefs, mannequin = dummy }
end

return SkyIsland
