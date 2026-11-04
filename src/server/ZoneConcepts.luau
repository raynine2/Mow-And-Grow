-- Concept slices for remaking the zones (owner, 4 Nov: "work a bit more on the zones i feel they are still slacking
-- maybe we can remake it? like not enitre zones or maybe make some consepts"). NOT part of the game: nothing
-- requires this module. Each concept is a 176 x 176 stud diorama of one zone, built the way the vault's
-- "Zone and Biome Art Direction" and "World Composition and Set Dressing" notes ask:
--   * a one-line identity, one shape bias, one accent colour and a "not this" list per zone (CONCEPTS below);
--   * landform first: a shaped valley with a cliff, water and terraces instead of even noise, rock strata on
--     every cliff face, a path from the gate to the zone's hero;
--   * the hero (tallest and brightest thing) framed from the gate; mowable lawns as clear, framed fields;
--   * foliage in clumps of odd numbers with a long tail of sizes, dense at the edges, never in rows;
--   * two or three small story spots ("what happened here?") on the path.
-- Only native parts (and server/CampProps, which is native parts too), so the same code runs in Lune for a
-- Blender preview (tools/concepts) and in Studio:
--   require(<a copy of ServerScriptService.MowALawn>.ZoneConcepts).build(workspace)   -- Workspace.ConceptLab
local CampProps = require(script.Parent.CampProps)

local ZoneConcepts = {}

local C = Color3.fromRGB
local CELL = 4 -- ground voxel, studs
local N = 44 -- cells per side (176 studs)
local HALF = N * CELL / 2
local FLOOR = -16 -- bottom of the diorama
local STEP = 2 -- terrace step

ZoneConcepts.SIZE = N * CELL
-- In Studio the groves can use the game's own tree meshes: { oak = { MeshPart }, pine = ..., dead = ... } (set
-- before building; the hero oak is always built here). Without it, trees are built from blocks.
ZoneConcepts.trees = nil :: { [string]: { BasePart } }?
local TREE_H = { oak = 24, pine = 28, dead = 18 } -- a mesh tree's height at scale 1
-- where each concept is built (far from the lobby at +3000 and the run world at +-820)
ZoneConcepts.ORIGIN = {
	meadow = Vector3.new(-4000, 0, 0),
	frost = Vector3.new(-4000, 0, 320),
	ember = Vector3.new(-4000, 0, 640),
}

-------------------------------------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------------------------------------
local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, o: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if o then
		if o.studs then
			p.TopSurface = Enum.SurfaceType.Studs
		end
		if o.shape then
			p.Shape = o.shape
		end
		if o.t then
			p.Transparency = o.t
		end
		if o.ghost then
			p.CanCollide = false
			p.CanQuery = false
		end
		if o.noshadow then
			p.CastShadow = false
		end
		if o.name then
			p.Name = o.name
		end
	end
	p.Parent = parent
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function hash2(i: number, j: number): number
	local h = (i * 374761393 + j * 668265263) % 2147483647
	h = (h * (h % 1000 + 1103515245) + 12345) % 2147483647
	return (h % 100000) / 100000
end

-- smooth value noise in [0, 1]
local function vnoise(x: number, z: number): number
	local i, j = math.floor(x), math.floor(z)
	local fx, fz = x - i, z - j
	fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
	local a, b = hash2(i, j), hash2(i + 1, j)
	local c, d = hash2(i, j + 1), hash2(i + 1, j + 1)
	return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fz
end

local function segDist(px: number, pz: number, ax: number, az: number, bx: number, bz: number): (number, number)
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local t = if l2 > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0, 1) else 0
	local qx, qz = ax + dx * t, az + dz * t
	return math.sqrt((px - qx) ^ 2 + (pz - qz) ^ 2), t
end

-- distance to a polyline { {x, z}, ... }
local function lineDist(px: number, pz: number, pts: { { number } }): number
	local best = math.huge
	for k = 1, #pts - 1 do
		local d = segDist(px, pz, pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2])
		best = math.min(best, d)
	end
	return best
end

-- how far along a polyline (in studs from its start) its closest point to (px, pz) is
local function arcAt(px: number, pz: number, pts: { { number } }): number
	local best, at, run = math.huge, 0, 0
	for k = 1, #pts - 1 do
		local ax, az, bx, bz = pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local d, t = segDist(px, pz, ax, az, bx, bz)
		if d < best then
			best, at = d, run + t * len
		end
		run += len
	end
	return at
end

-- points along a polyline every `step` studs
local function along(pts: { { number } }, step: number): { { number } }
	local out = {}
	for k = 1, #pts - 1 do
		local ax, az, bx, bz = pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local n = math.max(1, math.floor(len / step))
		for s = 0, n - 1 do
			local t = s / n
			table.insert(out, { ax + (bx - ax) * t, az + (bz - az) * t, math.atan2(bx - ax, bz - az) })
		end
	end
	local last = pts[#pts]
	table.insert(out, { last[1], last[2], 0 })
	return out
end

local function snap(h: number): number
	return math.floor(h / STEP + 0.5) * STEP
end

local function jitter(c: Color3, rng: Random, amt: number): Color3
	local k = 1 + rng:NextNumber(-amt, amt)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-------------------------------------------------------------------------------------------------------------
-- the ground: a voxel height field with strata on every cliff face and a cut-away diorama edge
-------------------------------------------------------------------------------------------------------------
export type Kind = { top: { Color3 }, side: { Color3 }, mat: Enum.Material?, studs: boolean? }
export type Ground = {
	origin: Vector3,
	h: { { number } },
	kind: { { string } },
	at: (x: number, z: number) -> (number, string),
}

-- cell (i, j) -> its centre in the slice's own studs
local function cellXZ(i: number, j: number): (number, number)
	return (i - 0.5) * CELL - HALF, (j - 0.5) * CELL - HALF
end

local function groundTops(gf: Instance, g: Ground, kinds: { [string]: Kind })
	-- merge runs of equal (height, kind, shade) along x into one top slab
	for j = 1, N do
		local i = 1
		while i <= N do
			local h, k = g.h[i][j], g.kind[i][j]
			local kd = kinds[k]
			local shade = 1 + math.floor(hash2(i // 2, j // 2 + 77) * #kd.top)
			local i2 = i
			while i2 + 1 <= N and g.h[i2 + 1][j] == h and g.kind[i2 + 1][j] == k and 1 + math.floor(hash2((i2 + 1) // 2, j // 2 + 77) * #kd.top) == shade do
				i2 += 1
			end
			local x0 = (i - 1) * CELL - HALF
			local w = (i2 - i + 1) * CELL
			local z = (j - 0.5) * CELL - HALF
			part(gf, Vector3.new(w, 1.2, CELL), CFrame.new(g.origin + Vector3.new(x0 + w / 2, h - 0.6, z)), kd.top[shade], kd.mat, { studs = kd.studs, name = "Top" })
			i = i2 + 1
		end
	end
end

-- the sides: only where a neighbour is lower (or at the diorama's edge), in 4-stud strata bands that line up
-- across cells, so every cliff shows the same layers
local function groundSides(gf: Instance, g: Ground, kinds: { [string]: Kind })
	for i = 1, N do
		for j = 1, N do
			local h = g.h[i][j]
			local low = h
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local ni, nj = i + d[1], j + d[2]
				local nh = if ni >= 1 and ni <= N and nj >= 1 and nj <= N then g.h[ni][nj] else FLOOR
				low = math.min(low, nh)
			end
			if low < h then
				local kd = kinds[g.kind[i][j]]
				local x, z = cellXZ(i, j)
				local top = h - 1.2
				local y = top
				while y > low + 0.01 do
					local band = math.floor((y - 0.01) / 4)
					local y0 = math.max(low, band * 4)
					local col = kd.side[1 + (band % #kd.side)]
					-- the first band under the top is the soil lip: the top colour, darker
					if y == top and #kd.side > 0 then
						col = kd.top[1]:Lerp(Color3.new(0, 0, 0), 0.22)
						y0 = math.max(low, top - 0.8)
					end
					part(gf, Vector3.new(CELL, y - y0, CELL), CFrame.new(g.origin + Vector3.new(x, (y + y0) / 2, z)), col, kd.mat, { name = "Side" })
					y = y0
				end
			end
		end
	end
end

local function buildGround(root: Instance, origin: Vector3, at: (number, number) -> (number, string), kinds: { [string]: Kind }): Ground
	local g: Ground = { origin = origin, h = {}, kind = {}, at = at }
	for i = 1, N do
		g.h[i], g.kind[i] = {}, {}
		for j = 1, N do
			local x, z = cellXZ(i, j)
			local h, k = at(x, z)
			g.h[i][j], g.kind[i][j] = h, k
		end
	end
	local gf = folder(root, "Ground")
	groundTops(gf, g, kinds)
	groundSides(gf, g, kinds)
	return g
end

-- the ground's top at a point of the slice (its own studs)
local function topAt(g: Ground, x: number, z: number): number
	local i = math.clamp(math.floor((x + HALF) / CELL) + 1, 1, N)
	local j = math.clamp(math.floor((z + HALF) / CELL) + 1, 1, N)
	return g.h[i][j]
end

local function kindAt(g: Ground, x: number, z: number): string
	local i = math.clamp(math.floor((x + HALF) / CELL) + 1, 1, N)
	local j = math.clamp(math.floor((z + HALF) / CELL) + 1, 1, N)
	return g.kind[i][j]
end

-- a world CFrame standing on the ground at (x, z), turned `yaw` radians
local function on(g: Ground, x: number, z: number, yaw: number?, lift: number?): CFrame
	return CFrame.new(g.origin + Vector3.new(x, topAt(g, x, z) + (lift or 0), z)) * CFrame.Angles(0, yaw or 0, 0)
end

-------------------------------------------------------------------------------------------------------------
-- kit: grass clumps, trees, hedges, fences, stones, water
-------------------------------------------------------------------------------------------------------------
-- the game's grass clumps (server/GrassStyle's look: 1 x 1 toy bricks, studs on top, tallest in the middle)
local SPOTS = {}
for x = -2, 2 do
	for z = -2, 2 do
		local d = math.sqrt(x * x + z * z)
		if d <= 2.3 then
			table.insert(SPOTS, { x = x, z = z, d = d })
		end
	end
end
table.sort(SPOTS, function(a, b)
	return a.d < b.d
end)

export type ClumpStyle = { shades: { Color3 }, top: Color3?, top2: Color3?, topNeon: boolean?, topChance: number?, bricks: { number }, count: number, width: number }

local function clump(parent: Instance, cf: CFrame, st: ClumpStyle, rng: Random)
	local yaw = cf * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	for k = 1, math.min(st.count, #SPOTS) do
		local s = SPOTS[k]
		if k > 5 and rng:NextNumber() < 0.2 then
			continue
		end
		local edge = s.d / 2.3
		local bricks = math.max(st.bricks[1] - 1, math.floor(rng:NextNumber(st.bricks[1], st.bricks[2] + 0.99) * (1 - edge * 0.4)))
		local h = bricks * 1.2
		local cell = Vector3.new(s.x * st.width, 0, s.z * st.width)
		part(parent, Vector3.new(st.width, h, st.width), yaw * CFrame.new(cell + Vector3.new(0, h / 2, 0)), st.shades[rng:NextInteger(1, #st.shades)], Enum.Material.Plastic, { studs = true, ghost = true, noshadow = k > 4, name = "Stick" })
		if st.top and rng:NextNumber() < (st.topChance or 0.5) then
			local w = st.width * 1.15
			local col = if st.top2 and rng:NextNumber() < 0.4 then st.top2 else st.top
			part(parent, Vector3.new(w, 1.2, w), yaw * CFrame.new(cell + Vector3.new(0, h + 0.6, 0)), col, if st.topNeon then Enum.Material.Neon else Enum.Material.Plastic, { studs = true, ghost = true, noshadow = true, name = "Head" })
		end
	end
end

-- a lawn: clumps on a jittered grid inside `inside(x, z)`, on the ground
local function lawn(parent: Instance, g: Ground, inside: (number, number) -> boolean, box: { number }, st: ClumpStyle, rng: Random, gap: number?)
	local f = folder(parent, "Lawn")
	local step = gap or 3.6
	local x = box[1]
	while x <= box[3] do
		local z = box[2]
		while z <= box[4] do
			local px, pz = x + rng:NextNumber(-1, 1), z + rng:NextNumber(-1, 1)
			if inside(px, pz) then
				clump(f, on(g, px, pz), st, rng)
			end
			z += step
		end
		x += step
	end
end

-- a voxel tree from blocks. kind: "oak" (round), "pine" (tiers), "dead" (charred, glowing tips)
export type TreeLook = { trunk: Color3, leaves: { Color3 }, snow: Color3?, tip: Color3? }

local function oak(parent: Instance, cf: CFrame, s: number, look: TreeLook, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Oak"
	local th = 7 * s
	part(m, Vector3.new(2.2 * s, th, 2.2 * s), cf * CFrame.new(0, th / 2, 0), look.trunk, Enum.Material.Wood)
	-- roots
	for a = 0, 3 do
		local r = cf * CFrame.Angles(0, a * math.pi / 2 + 0.4, 0) * CFrame.new(0, 0.5 * s, 1.5 * s)
		part(m, Vector3.new(1.2 * s, 1 * s, 1.6 * s), r, look.trunk:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Wood)
	end
	-- the canopy: a big middle cube and a few smaller ones round it, stepped like voxels
	local top = th
	local blocks = { { 0, 2.4, 0, 9 }, { 3.4, 1.2, 1, 6 }, { -3, 1.6, -1.6, 6.4 }, { 0.8, 4.6, -1, 6 }, { -1, 0.6, 3.6, 5.4 }, { 1.4, 0.4, -3.8, 5 } }
	for b, v in blocks do
		if b > 3 and rng:NextNumber() < 0.25 then
			continue
		end
		local sz = v[4] * s * rng:NextNumber(0.92, 1.08)
		local col = jitter(look.leaves[1 + (b % #look.leaves)], rng, 0.05)
		part(m, Vector3.new(sz, sz * 0.8, sz), cf * CFrame.new(v[1] * s, top + v[2] * s, v[3] * s) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), col, Enum.Material.Plastic, { studs = true })
	end
	m.Parent = parent
	return m
end

local function pine(parent: Instance, cf: CFrame, s: number, look: TreeLook, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Pine"
	local th = 4 * s
	part(m, Vector3.new(1.6 * s, th, 1.6 * s), cf * CFrame.new(0, th / 2, 0), look.trunk, Enum.Material.Wood)
	local y = th - 0.6 * s
	local w = 9 * s
	local tier = 0
	while w > 1.6 * s do
		local h = 2.6 * s
		local col = jitter(look.leaves[1 + (tier % #look.leaves)], rng, 0.04)
		local turn = CFrame.Angles(0, (tier % 2) * math.pi / 4, 0)
		part(m, Vector3.new(w, h, w), cf * CFrame.new(0, y + h / 2, 0) * turn, col, Enum.Material.Plastic, { studs = true })
		if look.snow then
			part(m, Vector3.new(w * 0.86, 0.6 * s, w * 0.86), cf * CFrame.new(0, y + h + 0.3 * s, 0) * turn, look.snow, Enum.Material.Plastic, { studs = true })
		end
		y += h * 0.82
		w *= 0.74
		tier += 1
	end
	part(m, Vector3.new(1.2 * s, 2 * s, 1.2 * s), cf * CFrame.new(0, y + 1 * s, 0), look.snow or look.leaves[1], Enum.Material.Plastic)
	m.Parent = parent
	return m
end

local function deadTree(parent: Instance, cf: CFrame, s: number, look: TreeLook, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Charred"
	local th = 9 * s
	local lean = cf * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
	part(m, Vector3.new(1.8 * s, th, 1.8 * s), lean * CFrame.new(0, th / 2, 0), look.trunk, Enum.Material.Basalt)
	for b = 1, 4 do
		local a = b * 1.7 + rng:NextNumber(-0.3, 0.3)
		local y = th * (0.45 + b * 0.12)
		local len = (5 - b * 0.6) * s
		local br = lean * CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(55))
		part(m, Vector3.new(len, 0.9 * s, 0.9 * s), br * CFrame.new(len / 2, 0, 0), look.trunk, Enum.Material.Basalt)
		if look.tip then
			part(m, Vector3.new(0.9 * s, 0.9 * s, 0.9 * s), br * CFrame.new(len, 0, 0), look.tip, Enum.Material.Neon, { noshadow = true })
		end
	end
	m.Parent = parent
	return m
end

-- a cluster of trees round (x, z): one big, a couple of mid, a few small (odd numbers, long-tail sizes)
local function grove(parent: Instance, g: Ground, x: number, z: number, r: number, n: number, kind: string, look: TreeLook, rng: Random, big: number?)
	local placed = {}
	local tries = 0
	while #placed < n and tries < n * 12 do
		tries += 1
		local a, d = rng:NextNumber(0, 2 * math.pi), r * math.sqrt(rng:NextNumber())
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		local ok = math.abs(px) < HALF - 3 and math.abs(pz) < HALF - 3
		for _, q in placed do
			if (q[1] - px) ^ 2 + (q[2] - pz) ^ 2 < 36 then
				ok = false
			end
		end
		local k = kindAt(g, px, pz)
		if ok and k ~= "path" and k ~= "water" and k ~= "bed" and k ~= "lava" then
			table.insert(placed, { px, pz })
			local s = (big or 1) * (if #placed == 1 then 1.25 elseif #placed <= 3 then 0.95 else rng:NextNumber(0.6, 0.8))
			local cf = on(g, px, pz, rng:NextNumber(0, math.pi * 2))
			local kit = ZoneConcepts.trees and ZoneConcepts.trees[kind]
			if kit and #kit > 0 then
				local t = kit[rng:NextInteger(1, #kit)]:Clone()
				local hgt = TREE_H[kind] * s
				t.Size = t.Size * (hgt / t.Size.Y)
				t.CFrame = cf * CFrame.new(0, hgt / 2 - 0.4, 0)
				t.Anchored = true
				t.CanCollide = false
				t.Parent = parent
			elseif kind == "pine" then
				pine(parent, cf, s, look, rng)
			elseif kind == "dead" then
				deadTree(parent, cf, s, look, rng)
			else
				oak(parent, cf, s, look, rng)
			end
		end
	end
end

-- stepping stones along a path polyline
local function stones(parent: Instance, g: Ground, pts: { { number } }, cols: { Color3 }, rng: Random, width: number?)
	local f = folder(parent, "Path")
	local w = width or 5
	for _, p in along(pts, 2.4) do
		for side = -1, 1, 2 do
			if rng:NextNumber() < 0.85 then
				local off = side * w / 4 + rng:NextNumber(-0.4, 0.4)
				local px, pz = p[1] + math.cos(p[3]) * off, p[2] - math.sin(p[3]) * off
				local sz = rng:NextNumber(1.5, 2)
				part(f, Vector3.new(sz, 0.4, sz * rng:NextNumber(0.85, 1.1)), on(g, px, pz, p[3] + rng:NextNumber(-0.25, 0.25), 0.16 + rng:NextNumber(0, 0.1)), cols[rng:NextInteger(1, #cols)], Enum.Material.Slate, { name = "Stone" })
			end
		end
	end
end

-- a low clipped hedge from a to b (voxel blocks with a slightly lighter top)
local function hedge(parent: Instance, g: Ground, ax: number, az: number, bx: number, bz: number, col: Color3, rng: Random, height: number?)
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local yaw = math.atan2(bx - ax, bz - az)
	local n = math.max(1, math.floor(len / 3))
	local h = height or 3
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local x, z = ax + (bx - ax) * t, az + (bz - az) * t
		local hh = h + rng:NextNumber(-0.2, 0.3)
		part(parent, Vector3.new(2.6, hh, len / n + 0.3), on(g, x, z, yaw, hh / 2), jitter(col, rng, 0.05), Enum.Material.Plastic, { studs = true, name = "Hedge" })
	end
end

-- a white picket fence from a to b
local function picket(parent: Instance, g: Ground, ax: number, az: number, bx: number, bz: number, col: Color3)
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local yaw = math.atan2(bx - ax, bz - az)
	local n = math.max(1, math.floor(len / 1.2))
	for k = 0, n do
		local t = k / n
		local x, z = ax + (bx - ax) * t, az + (bz - az) * t
		local base = on(g, x, z, yaw)
		part(parent, Vector3.new(0.5, 3, 0.25), base * CFrame.new(0, 1.5, 0), col, Enum.Material.SmoothPlastic, { name = "Picket" })
		part(parent, Vector3.new(0.36, 0.36, 0.25), base * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(45)), col, Enum.Material.SmoothPlastic, { name = "Picket" })
	end
	for _, y in { 1, 2.2 } do
		local mid = on(g, (ax + bx) / 2, (az + bz) / 2, yaw, y)
		part(parent, Vector3.new(0.2, 0.3, len), mid * CFrame.new(-0.22, 0, 0), col, Enum.Material.SmoothPlastic, { name = "Rail" })
	end
end

-- a flat water surface over a lake bed (one slab per run of water cells, so it never covers dry ground)
local function waterSheet(parent: Instance, g: Ground, isWater: (string) -> boolean, level: number, col: Color3, mat: Enum.Material, t: number)
	local f = folder(parent, "Water")
	for j = 1, N do
		local i = 1
		while i <= N do
			if isWater(g.kind[i][j]) then
				local i2 = i
				while i2 + 1 <= N and isWater(g.kind[i2 + 1][j]) do
					i2 += 1
				end
				local x0 = (i - 1) * CELL - HALF
				local w = (i2 - i + 1) * CELL
				local z = (j - 0.5) * CELL - HALF
				part(f, Vector3.new(w, 0.6, CELL), CFrame.new(g.origin + Vector3.new(x0 + w / 2, level - 0.3, z)), col, mat, { t = t, ghost = true, noshadow = true, name = "Surface" })
				i = i2 + 1
			else
				i += 1
			end
		end
	end
end

local function rock(parent: Instance, cf: CFrame, s: number, col: Color3, rng: Random, mat: Enum.Material?)
	for k = 1, 3 do
		local sz = s * (if k == 1 then 1 else rng:NextNumber(0.45, 0.7))
		local off = if k == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-0.8, 0.8) * s, 0, rng:NextNumber(-0.8, 0.8) * s)
		part(parent, Vector3.new(sz * 1.3, sz, sz), cf * CFrame.new(off + Vector3.new(0, sz * 0.38, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)), jitter(col, rng, 0.06), mat or Enum.Material.Slate, { name = "Rock" })
	end
end

local function flowers(parent: Instance, g: Ground, x: number, z: number, r: number, cols: { Color3 }, n: number, rng: Random)
	for _ = 1, n do
		local a, d = rng:NextNumber(0, math.pi * 2), r * math.sqrt(rng:NextNumber())
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		local cf = on(g, px, pz, rng:NextNumber(0, 3))
		part(parent, Vector3.new(0.3, 1.2, 0.3), cf * CFrame.new(0, 0.6, 0), C(70, 150, 60), Enum.Material.Plastic, { ghost = true, noshadow = true, name = "Stem" })
		part(parent, Vector3.new(0.9, 0.5, 0.9), cf * CFrame.new(0, 1.35, 0), cols[rng:NextInteger(1, #cols)], Enum.Material.Plastic, { ghost = true, noshadow = true, studs = true, name = "Flower" })
	end
end

local function sign(parent: Instance, cf: CFrame, text: string, board: Color3, ink: Color3)
	part(parent, Vector3.new(0.5, 3.6, 0.5), cf * CFrame.new(0, 1.8, 0), board:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Wood)
	local b = part(parent, Vector3.new(4.6, 1.6, 0.3), cf * CFrame.new(0, 3.4, -0.3), board, Enum.Material.WoodPlanks, { name = "Board" })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 40
	sg.Parent = b
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = ink
	l.Parent = sg
end

-------------------------------------------------------------------------------------------------------------
-- the concepts' briefs (vault: "Zone and Biome Art Direction", section 1)
-------------------------------------------------------------------------------------------------------------
ZoneConcepts.BRIEFS = {
	meadow = {
		title = "Sunny Meadow: the back gardens",
		identity = "A sunny valley of back gardens nobody has mowed in years.",
		shape = "Round and bottom-heavy: clipped hedges, round crowns, soft terraces.",
		colour = "Fresh greens, white pickets, one accent: dandelion yellow.",
		light = "Clear morning sun, crisp shadows.",
		hero = "The great oak on the hill, with a tree house and a tyre swing.",
		notThis = "No rows of the same tree, no flat single-colour ground, no blue or purple.",
	},
	frost = {
		title = "Frost Peaks: the frozen falls",
		identity = "A high ice valley under a frozen waterfall; the ice glows blue.",
		shape = "Tall, thin and faceted: cliffs, ice spires, narrow snowy pines.",
		colour = "White and pale blue, deep blue shadows, one accent: glowing cyan.",
		light = "Cold bright noon, blue haze.",
		hero = "The frozen waterfall with the great ice crystal on top.",
		notThis = "No green grass, no warm colours except the camp's fire.",
	},
	ember = {
		title = "Ember Ash Fields: the glowing rifts",
		identity = "A cooling volcanic plain; danger glows from below.",
		shape = "Sharp, tilted, broken: basalt columns, leaning spires, cracked plates.",
		colour = "Near-black stone, ash grey, one accent: lava orange.",
		light = "Low warm evening light, red bounce, thick haze.",
		hero = "The volcano at the back, its crater glowing.",
		notThis = "No green, no blue light, no round friendly shapes.",
	},
}

-------------------------------------------------------------------------------------------------------------
-- Concept A: Sunny Meadow, the back gardens
-------------------------------------------------------------------------------------------------------------
local M = {
	-- the gate is at the front (-z); the path winds to the great oak on the hill at the back left
	path = { { 2, -92 }, { -2, -66 }, { 8, -44 }, { 0, -22 }, { -8, 0 }, { -8, 18 }, { -18, 32 }, { -34, 42 }, { -44, 50 } },
	picnicPath = { { 8, -44 }, { 18, -48 } },
	creek = { { -32, 28 }, { -8, 18 }, { 12, 4 }, { 26, -8 } },
	bridge = { -8, 18 },
	pond = { 40, -22, 22, 15 }, -- x, z, rx, rz
	hill = { -50, 58 },
	lawn1 = { -36, -42, 21 }, -- round lawn in a hedge ring
	bridgeAt = 0,
}
M.bridgeAt = arcAt(M.bridge[1], M.bridge[2], M.path)

local MEADOW_KINDS: { [string]: Kind } = {
	grass = { top = { C(98, 190, 64), C(92, 183, 60), C(103, 195, 67) }, side = { C(128, 92, 60), C(114, 82, 54), C(146, 136, 120) }, studs = true },
	path = { top = { C(206, 170, 116), C(196, 160, 108) }, side = { C(128, 92, 60), C(114, 82, 54) }, mat = Enum.Material.SmoothPlastic },
	shore = { top = { C(222, 204, 156), C(210, 192, 146) }, side = { C(128, 92, 60), C(114, 82, 54) }, mat = Enum.Material.SmoothPlastic },
	bed = { top = { C(96, 120, 84) }, side = { C(110, 84, 58) }, mat = Enum.Material.SmoothPlastic },
	creek = { top = { C(120, 132, 100) }, side = { C(128, 92, 60), C(114, 82, 54) }, mat = Enum.Material.SmoothPlastic },
}

local function meadowAt(x: number, z: number): (number, string)
	-- terraces rising toward the back, their edges wandering so no step is a straight line
	local w = (vnoise(x / 26 + 3, 7.1) - 0.5) * 18
	local h = math.clamp(math.floor((z + w + 10) / 18), 0, 4) * STEP
	-- the great oak's hill: a round plateau with a stepped side (its cliff shows the strata)
	local dh = math.sqrt((x - M.hill[1]) ^ 2 + (z - M.hill[2]) ^ 2) + (vnoise(x / 9, z / 9) - 0.5) * 7
	if dh < 26 then
		h = math.max(h, 16)
	elseif dh < 31 then
		h = math.max(h, 12)
	elseif dh < 35 then
		h = math.max(h, 10)
	end
	-- a low ridge at the back right that frames the shed's terrace
	if x > 50 and z > 56 then
		h = math.max(h, 10)
	end
	local kind = "grass"
	-- the pond in the front right, sandy all round
	local e = ((x - M.pond[1]) / M.pond[3]) ^ 2 + ((z - M.pond[2]) / M.pond[4]) ^ 2
	if e < 1 then
		return -4, "bed"
	elseif e < 1.3 then
		kind = "shore"
	end
	-- the creek from the hill's foot down the terraces to the pond
	if lineDist(x, z, M.creek) < 2.6 then
		return h - 2, "creek"
	end
	if lineDist(x, z, M.path) < 3.2 then
		-- past the bridge the path climbs to the oak in 2-stud steps, cut into the hill where it's steeper
		local s = arcAt(x, z, M.path) - M.bridgeAt
		if s > 0 then
			h = math.min(h, snap(2 + s * 0.3))
		end
		kind = "path"
	elseif lineDist(x, z, M.picnicPath) < 2.4 then
		kind = "path"
	end
	return h, kind
end

-- water in the creek: a sheet on each cell and a little fall wherever it steps down
local function creekWater(parent: Instance, g: Ground)
	local f = folder(parent, "Creek")
	local col = C(84, 176, 222)
	for i = 1, N do
		for j = 1, N do
			if g.kind[i][j] == "creek" then
				local x, z = cellXZ(i, j)
				local h = g.h[i][j]
				part(f, Vector3.new(CELL, 0.5, CELL), CFrame.new(g.origin + Vector3.new(x, h + 1.2, z)), col, Enum.Material.Glass, { t = 0.35, ghost = true, noshadow = true, name = "Water" })
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local ni, nj = i + d[1], j + d[2]
					if ni >= 1 and ni <= N and nj >= 1 and nj <= N and g.kind[ni][nj] == "creek" and g.h[ni][nj] < h then
						local drop = h - g.h[ni][nj]
						local ex, ez = x + d[1] * CELL / 2, z + d[2] * CELL / 2
						local size = if d[1] ~= 0 then Vector3.new(0.6, drop + 0.2, CELL) else Vector3.new(CELL, drop + 0.2, 0.6)
						part(f, size, CFrame.new(g.origin + Vector3.new(ex, h + 1.45 - drop / 2, ez)), C(200, 236, 255), Enum.Material.Glass, { t = 0.25, ghost = true, noshadow = true, name = "Fall" })
					end
				end
			end
		end
	end
end

-- the hero: the great oak with a tree house and a tyre swing
local function greatOak(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "Hero")
	local cf = on(g, M.hill[1], M.hill[2], math.rad(30))
	-- the hero gets the most detail: a thick trunk with root flares and branches, and a lumpy crown of many
	-- blocks (one big core, smaller ones bulging out of it) instead of a few giant cubes
	local leaves = { C(70, 168, 56), C(86, 184, 62), C(60, 150, 50), C(96, 194, 70) }
	local bark = C(122, 84, 52)
	part(f, Vector3.new(6, 26, 6), cf * CFrame.new(0, 13, 0), bark, Enum.Material.Wood)
	for k = 0, 5 do
		local a = k / 6 * 2 * math.pi + 0.3
		part(f, Vector3.new(2.6, 2.4, 4.4), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.1, 3.8) * CFrame.Angles(math.rad(-18), 0, 0), bark:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Wood)
	end
	for k = 1, 5 do
		local a = k / 5 * 2 * math.pi + 0.5
		local br = cf * CFrame.new(0, 20 + k * 1.2, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(32))
		part(f, Vector3.new(12, 2, 2), br * CFrame.new(6, 0, 0), bark, Enum.Material.Wood)
	end
	part(f, Vector3.new(26, 16, 26), cf * CFrame.new(0, 34, 0) * CFrame.Angles(0, 0.4, 0), leaves[1], Enum.Material.Plastic, { studs = true })
	for k = 1, 26 do
		local a = k * 2.399 -- golden angle: an even spread round the crown
		local up = (k / 26) * 1.6 - 0.7
		local r = 16 * math.sqrt(math.max(0.05, 1 - up * up * 0.6))
		local sz = rng:NextNumber(7, 11.5) * (1 - math.abs(up) * 0.25)
		local p = cf * CFrame.new(math.cos(a) * r, 34 + up * 9, math.sin(a) * r)
		part(f, Vector3.new(sz, sz * 0.78, sz), p * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), jitter(leaves[1 + k % #leaves], rng, 0.05), Enum.Material.Plastic, { studs = true })
	end
	local wood, roof = C(176, 124, 78), C(196, 66, 54)
	local deckY = 16
	-- deck round the trunk, a little hut on it, a rope ladder down the front
	part(f, Vector3.new(12, 0.8, 12), cf * CFrame.new(0, deckY, 0), wood, Enum.Material.WoodPlanks)
	for _, c in { { -5.6, -5.6 }, { 5.6, -5.6 }, { -5.6, 5.6 }, { 5.6, 5.6 } } do
		part(f, Vector3.new(0.6, 2.4, 0.6), cf * CFrame.new(c[1], deckY + 1.6, c[2]), wood:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood)
	end
	part(f, Vector3.new(11.6, 0.4, 0.4), cf * CFrame.new(0, deckY + 2.6, -5.6), wood, Enum.Material.Wood)
	part(f, Vector3.new(6, 4.4, 5), cf * CFrame.new(2.6, deckY + 2.6, 2.4), C(232, 214, 168), Enum.Material.WoodPlanks)
	part(f, Vector3.new(7, 1.2, 6.4), cf * CFrame.new(2.6, deckY + 5.3, 2.4) * CFrame.Angles(0, 0, math.rad(4)), roof, Enum.Material.Plastic, { studs = true })
	part(f, Vector3.new(1.8, 2.6, 0.2), cf * CFrame.new(2.6, deckY + 1.7, -0.15), C(80, 52, 36), Enum.Material.Wood)
	for k = 0, 6 do
		part(f, Vector3.new(2, 0.3, 0.3), cf * CFrame.new(-2.6, deckY - 1 - k * 1.9, -6.2), wood, Enum.Material.Wood)
	end
	for _, x in { -3.5, -1.7 } do
		part(f, Vector3.new(0.15, deckY - 0.4, 0.15), cf * CFrame.new(x, deckY / 2, -6.2), C(200, 180, 130), Enum.Material.Fabric)
	end
	-- the tyre swing from the low branch on the right
	local arm = cf * CFrame.new(11, 22, -2)
	part(f, Vector3.new(9, 1.6, 1.6), cf * CFrame.new(6.6, 22, -2), C(112, 78, 48), Enum.Material.Wood)
	part(f, Vector3.new(0.15, 16, 0.15), arm * CFrame.new(0, -8, 0), C(200, 180, 130), Enum.Material.Fabric)
	part(f, Vector3.new(0.9, 3, 3), arm * CFrame.new(0, -17.2, 0) * CFrame.Angles(0, math.rad(90), 0), C(40, 40, 44), Enum.Material.Rubber, { shape = Enum.PartType.Cylinder })
end

local function picnic(parent: Instance, g: Ground)
	local f = folder(parent, "Picnic")
	local cf = on(g, 20, -50, math.rad(-20), 0.1)
	for a = 0, 3 do
		for b = 0, 3 do
			local red = (a + b) % 2 == 0
			part(f, Vector3.new(1.4, 0.1, 1.4), cf * CFrame.new((a - 1.5) * 1.4, 0, (b - 1.5) * 1.4), if red then C(220, 62, 58) else C(250, 246, 240), Enum.Material.Fabric)
		end
	end
	part(f, Vector3.new(1.8, 1.2, 1.2), cf * CFrame.new(1.2, 0.6, 1.4), C(196, 150, 88), Enum.Material.Fabric) -- the basket
	part(f, Vector3.new(0.2, 1, 1.4), cf * CFrame.new(1.2, 1.5, 1.4), C(160, 116, 64), Enum.Material.Wood)
	part(f, Vector3.new(1, 0.1, 1), cf * CFrame.new(-1.2, 0.1, -0.8), C(255, 255, 255), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	part(f, Vector3.new(0.5, 0.7, 0.5), cf * CFrame.new(-0.2, 0.15, -1.6) * CFrame.Angles(0, 0, math.rad(90)), C(80, 150, 220), Enum.Material.SmoothPlastic) -- a cup knocked over
	part(f, Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(0.4, 0.45, 0.6), C(220, 40, 40), Enum.Material.Plastic, { shape = Enum.PartType.Ball }) -- an apple
end

local function shed(parent: Instance, g: Ground)
	local f = folder(parent, "Shed")
	local cf = on(g, 66, 66, math.rad(200))
	local wall, trim = C(120, 150, 170), C(240, 236, 226)
	part(f, Vector3.new(9, 6, 7), cf * CFrame.new(0, 3, 0), wall, Enum.Material.WoodPlanks)
	part(f, Vector3.new(10.4, 0.6, 4.6), cf * CFrame.new(0, 6.9, -1.8) * CFrame.Angles(math.rad(-24), 0, 0), C(86, 92, 98), Enum.Material.Plastic, { studs = true })
	part(f, Vector3.new(10.4, 0.6, 4.6), cf * CFrame.new(0, 6.9, 1.8) * CFrame.Angles(math.rad(24), 0, 0), C(86, 92, 98), Enum.Material.Plastic, { studs = true })
	part(f, Vector3.new(2.6, 4.6, 0.3), cf * CFrame.new(-2, 2.3, -3.6) * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(1.2, 0, 0), C(86, 120, 140), Enum.Material.WoodPlanks) -- the door, ajar
	part(f, Vector3.new(2.8, 0.3, 0.2), cf * CFrame.new(-2, 4.75, -3.55), trim, Enum.Material.SmoothPlastic)
	part(f, Vector3.new(2, 1.6, 0.2), cf * CFrame.new(2.4, 3.6, -3.55), C(200, 230, 245), Enum.Material.Glass, { t = 0.2 })
	-- the old push mower left out in the rain, and a wheelbarrow of clippings
	local mw = cf * CFrame.new(-4, 0, -7) * CFrame.Angles(0, math.rad(25), 0)
	part(f, Vector3.new(2.4, 0.9, 2.6), mw * CFrame.new(0, 0.9, 0), C(178, 62, 46), Enum.Material.CorrodedMetal)
	for _, x in { -1.25, 1.25 } do
		for _, z in { -0.9, 0.9 } do
			part(f, Vector3.new(0.3, 0.9, 0.9), mw * CFrame.new(x, 0.45, z), C(30, 30, 30), Enum.Material.Rubber, { shape = Enum.PartType.Cylinder })
		end
	end
	part(f, Vector3.new(0.2, 0.2, 3.6), mw * CFrame.new(-0.7, 2.2, 2.3) * CFrame.Angles(math.rad(40), 0, 0), C(60, 60, 60), Enum.Material.Metal)
	part(f, Vector3.new(0.2, 0.2, 3.6), mw * CFrame.new(0.7, 2.2, 2.3) * CFrame.Angles(math.rad(40), 0, 0), C(60, 60, 60), Enum.Material.Metal)
	part(f, Vector3.new(1.8, 0.25, 0.25), mw * CFrame.new(0, 3.3, 3.6), C(30, 30, 30), Enum.Material.Rubber)
	local wb = cf * CFrame.new(4.6, 0, -7.4) * CFrame.Angles(0, math.rad(-30), 0)
	part(f, Vector3.new(2.6, 1.2, 3.4), wb * CFrame.new(0, 1.4, 0), C(90, 150, 70), Enum.Material.Metal)
	part(f, Vector3.new(2.2, 0.8, 3), wb * CFrame.new(0, 2.2, 0), C(110, 190, 70), Enum.Material.Plastic, { studs = true })
	part(f, Vector3.new(0.4, 1.2, 1.2), wb * CFrame.new(0, 0.6, -2), C(30, 30, 30), Enum.Material.Rubber, { shape = Enum.PartType.Cylinder })
end

local function washingLine(parent: Instance, g: Ground)
	local f = folder(parent, "Washing")
	local a, b = Vector3.new(14, 0, 70), Vector3.new(36, 0, 74)
	local ya, yb = topAt(g, a.X, a.Z), topAt(g, b.X, b.Z)
	for _, p in { { a, ya }, { b, yb } } do
		part(f, Vector3.new(0.5, 6, 0.5), CFrame.new(g.origin + p[1] + Vector3.new(0, p[2] + 3, 0)), C(150, 110, 70), Enum.Material.Wood)
	end
	local pa, pb = g.origin + a + Vector3.new(0, ya + 5.6, 0), g.origin + b + Vector3.new(0, yb + 5.6, 0)
	local len = (pb - pa).Magnitude
	part(f, Vector3.new(0.12, 0.12, len), CFrame.lookAt((pa + pb) / 2, pb), C(240, 240, 240), Enum.Material.Fabric)
	local cols = { C(255, 255, 255), C(120, 180, 240), C(250, 214, 80), C(255, 255, 255), C(240, 130, 150) }
	for k, col in cols do
		local t = (k - 0.5) / #cols
		local at = pa:Lerp(pb, t)
		part(f, Vector3.new(0.1, 3.2, 3), CFrame.lookAt(at - Vector3.new(0, 1.6, 0), at - Vector3.new(0, 1.6, 0) + (pb - pa)) * CFrame.Angles(0, math.rad(90), 0), col, Enum.Material.Fabric)
	end
end

local function gardenGate(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "Gate")
	local cf = on(g, 2, -82)
	local white, rose, leaf = C(246, 244, 238), C(220, 50, 70), C(70, 150, 60)
	for _, x in { -3.4, 3.4 } do
		part(f, Vector3.new(0.9, 8, 0.9), cf * CFrame.new(x, 4, 0), white, Enum.Material.SmoothPlastic)
	end
	for k = -3, 3 do
		local a = k / 3 * math.rad(70)
		part(f, Vector3.new(1.4, 0.7, 1.1), cf * CFrame.new(math.sin(a) * 3.6, 8 + math.cos(a) * 1.6, 0) * CFrame.Angles(0, 0, -a), white, Enum.Material.SmoothPlastic)
	end
	for _ = 1, 26 do
		local a = rng:NextNumber(-1.3, 1.3)
		local p = cf * CFrame.new(math.sin(a) * 3.8, 7.6 + math.cos(a) * 2 + rng:NextNumber(-1.4, 0.6), rng:NextNumber(-0.7, 0.7))
		part(f, Vector3.new(0.9, 0.9, 0.9), p, if rng:NextNumber() < 0.45 then rose else leaf, Enum.Material.Plastic, { studs = true, ghost = true })
	end
	picket(f, g, -28, -84, -5, -84, white)
	picket(f, g, 9, -84, 32, -84, white)
	flowers(f, g, -16, -80, 6, { C(250, 210, 50), C(220, 50, 70), C(255, 255, 255) }, 22, rng)
	flowers(f, g, 20, -80, 6, { C(250, 210, 50), C(220, 50, 70), C(255, 255, 255) }, 22, rng)
	sign(f, cf * CFrame.new(-6.5, 0, -1.4) * CFrame.Angles(0, math.rad(15), 0), "SUNNY MEADOW", C(200, 150, 90), C(60, 40, 24))
end

-- a bench looking over the pond, and a birdbath by the path
local function restSpot(parent: Instance, g: Ground)
	local f = folder(parent, "Bench")
	local at = Vector3.new(22, 0, -2)
	local to = Vector3.new(M.pond[1], 0, M.pond[2])
	local cf = on(g, at.X, at.Z, math.atan2(-(to.X - at.X), -(to.Z - at.Z)))
	local wood, iron = C(186, 128, 76), C(54, 58, 60)
	for k = 0, 2 do
		part(f, Vector3.new(5, 0.25, 0.5), cf * CFrame.new(0, 1.7, -0.5 + k * 0.6), wood, Enum.Material.WoodPlanks)
	end
	for k = 0, 1 do
		part(f, Vector3.new(5, 0.5, 0.25), cf * CFrame.new(0, 2.5 + k * 0.7, 1.15) * CFrame.Angles(math.rad(-12), 0, 0), wood, Enum.Material.WoodPlanks)
	end
	for _, x in { -2.2, 2.2 } do
		part(f, Vector3.new(0.3, 1.7, 1.9), cf * CFrame.new(x, 0.85, 0.1), iron, Enum.Material.Metal)
	end
	local b = on(g, -8, -36)
	local stone = C(214, 208, 196)
	part(f, Vector3.new(1.4, 2.6, 1.4), b * CFrame.new(0, 1.3, 0), stone, Enum.Material.Slate)
	part(f, Vector3.new(0.8, 3.4, 3.4), b * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, 0, math.rad(90)), stone, Enum.Material.Slate, { shape = Enum.PartType.Cylinder })
	part(f, Vector3.new(0.2, 2.8, 2.8), b * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(90)), C(110, 190, 230), Enum.Material.Glass, { shape = Enum.PartType.Cylinder, t = 0.2 })
	part(f, Vector3.new(0.6, 0.5, 0.9), b * CFrame.new(1.2, 3.65, 0.2), C(70, 130, 220), Enum.Material.Plastic) -- a bluebird
	part(f, Vector3.new(0.4, 0.4, 0.4), b * CFrame.new(1.2, 3.95, -0.3), C(70, 130, 220), Enum.Material.Plastic)
	part(f, Vector3.new(0.2, 0.15, 0.3), b * CFrame.new(1.2, 3.9, -0.6), C(250, 180, 50), Enum.Material.Plastic)
end

local function meadowLawns(parent: Instance, g: Ground, rng: Random)
	local st = { shades = { C(48, 160, 64), C(62, 180, 74), C(38, 140, 58) }, bricks = { 3, 7 }, count = 14, width = 1 }
	local cx, cz, r = M.lawn1[1], M.lawn1[2], M.lawn1[3]
	lawn(parent, g, function(x, z)
		return (x - cx) ^ 2 + (z - cz) ^ 2 < r * r and kindAt(g, x, z) == "grass"
	end, { cx - r, cz - r, cx + r, cz + r }, st, rng, 4)
	-- the hedge ring round lawn 1, open toward the path and the back
	local hedgeCol = C(54, 132, 52)
	local segs = 22
	for k = 0, segs - 1 do
		local a0, a1 = k / segs * 2 * math.pi, (k + 1) / segs * 2 * math.pi
		local mid = (a0 + a1) / 2
		local gap = math.abs(math.cos(mid) - 1) < 0.25 or math.abs(math.sin(mid) - 1) < 0.12
		if not gap then
			hedge(parent, g, cx + math.cos(a0) * (r + 3), cz + math.sin(a0) * (r + 3), cx + math.cos(a1) * (r + 3), cz + math.sin(a1) * (r + 3), hedgeCol, rng)
		end
	end
	-- lawn 2: the long field on the middle terrace, a picket fence along its front
	lawn(parent, g, function(x, z)
		return x > 6 and x < 54 and z > 26 and z < 52 and kindAt(g, x, z) == "grass"
	end, { 6, 26, 54, 52 }, st, rng, 4)
	picket(parent, g, 6, 23, 26, 23, C(246, 244, 238))
	picket(parent, g, 34, 23, 54, 23, C(246, 244, 238))
	sign(parent, on(g, 30, 21), "KEEP OFF THE GRASS", C(240, 236, 226), C(200, 40, 40))
	-- lawn 3: the patch beyond the pond
	lawn(parent, g, function(x, z)
		return x > 54 and x < 84 and z > -84 and z < -44 and kindAt(g, x, z) == "grass"
	end, { 54, -84, 84, -44 }, st, rng, 4)
end

local function pondLife(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "PondLife")
	local level = -1
	for _ = 1, 9 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.2, 0.8)
		local x, z = M.pond[1] + math.cos(a) * M.pond[3] * d, M.pond[2] + math.sin(a) * M.pond[4] * d
		local pad = CFrame.new(g.origin + Vector3.new(x, level + 0.05, z)) * CFrame.Angles(0, 0, math.rad(90))
		part(f, Vector3.new(0.12, rng:NextNumber(1.8, 2.6), rng:NextNumber(1.8, 2.6)), pad, C(70, 150, 60), Enum.Material.Plastic, { shape = Enum.PartType.Cylinder, ghost = true })
		if rng:NextNumber() < 0.4 then
			part(f, Vector3.new(0.7, 0.5, 0.7), CFrame.new(g.origin + Vector3.new(x, level + 0.35, z)), C(255, 170, 200), Enum.Material.Plastic, { ghost = true })
		end
	end
	-- reeds at the far bank, rocks at the near one
	for _ = 1, 14 do
		local a = rng:NextNumber(-0.6, 1.2)
		local x, z = M.pond[1] + math.cos(a) * (M.pond[3] + 1), M.pond[2] + math.sin(a) * (M.pond[4] + 1)
		local h = rng:NextNumber(2.4, 4.2)
		part(f, Vector3.new(0.3, h, 0.3), on(g, x, z, 0, h / 2 - 1), C(96, 150, 60), Enum.Material.Plastic, { ghost = true })
		if rng:NextNumber() < 0.4 then
			part(f, Vector3.new(0.45, 1, 0.45), on(g, x, z, 0, h - 0.6), C(110, 70, 40), Enum.Material.Fabric, { ghost = true })
		end
	end
	for k = 1, 4 do
		local a = math.pi + k * 0.35
		rock(f, on(g, M.pond[1] + math.cos(a) * (M.pond[3] + 2), M.pond[2] + math.sin(a) * (M.pond[4] + 2)), rng:NextNumber(1.4, 2.6), C(150, 150, 146), rng)
	end
end

local function footbridge(parent: Instance, g: Ground)
	local f = folder(parent, "Bridge")
	local x, z = M.bridge[1], M.bridge[2]
	local y = math.max(topAt(g, x, z - 6), topAt(g, x, z + 6))
	local cf = CFrame.new(g.origin + Vector3.new(x, y, z))
	local wood = C(170, 120, 74)
	for k = -4, 4 do
		local lift = (1 - (k / 4) ^ 2) * 1.2
		part(f, Vector3.new(4.6, 0.4, 1.1), cf * CFrame.new(0, lift + 0.2, k * 1.2), wood:Lerp(Color3.new(0, 0, 0), (k % 2) * 0.06), Enum.Material.WoodPlanks)
	end
	for _, sx in { -2.4, 2.4 } do
		for _, k in { -4, 0, 4 } do
			part(f, Vector3.new(0.4, 2.4, 0.4), cf * CFrame.new(sx, (1 - (k / 4) ^ 2) * 1.2 + 1.2, k * 1.2), wood, Enum.Material.Wood)
		end
		part(f, Vector3.new(0.3, 0.3, 10), cf * CFrame.new(sx, 2.6, 0), wood, Enum.Material.Wood)
	end
end

function ZoneConcepts.meadow(root: Instance, origin: Vector3, seed: number?)
	local rng = Random.new(seed or 11)
	local m = Instance.new("Model")
	m.Name = "A Meadow - the back gardens"
	m.Parent = root
	local g = buildGround(m, origin, meadowAt, MEADOW_KINDS)
	waterSheet(m, g, function(k)
		return k == "bed"
	end, -1, C(70, 168, 220), Enum.Material.Glass, 0.3)
	creekWater(m, g)
	stones(m, g, M.path, { C(232, 222, 200), C(218, 206, 182), C(240, 232, 214) }, rng)
	stones(m, g, M.picnicPath, { C(232, 222, 200), C(218, 206, 182) }, rng, 4)
	footbridge(m, g)
	greatOak(m, g, rng)
	local trees = folder(m, "Trees")
	local look = { trunk = C(126, 88, 56), leaves = { C(82, 176, 60), C(98, 190, 68), C(70, 160, 54) } }
	grove(trees, g, 70, 74, 14, 5, "oak", look, rng)
	grove(trees, g, -74, -72, 14, 5, "oak", look, rng)
	grove(trees, g, 80, -16, 8, 3, "oak", look, rng)
	grove(trees, g, -80, 6, 9, 3, "oak", look, rng)
	grove(trees, g, 18, 82, 10, 3, "oak", look, rng, 0.9)
	grove(trees, g, -20, 80, 8, 3, "oak", look, rng, 0.85)
	meadowLawns(m, g, rng)
	pondLife(m, g, rng)
	picnic(m, g)
	shed(m, g)
	washingLine(m, g)
	restSpot(m, g)
	gardenGate(m, g, rng)
	-- dandelions (the zone's accent) and flower clumps along the path's edges
	local fl = folder(m, "Flowers")
	for _, p in along(M.path, 9) do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		flowers(fl, g, p[1] + math.cos(p[3]) * 5 * side, p[2] - math.sin(p[3]) * 5 * side, 1.6, { C(250, 210, 50), C(255, 255, 255) }, 5, rng)
	end
	local tufts = folder(m, "Tufts")
	for _ = 1, 160 do
		local x, z = rng:NextNumber(-84, 84), rng:NextNumber(-84, 84)
		if kindAt(g, x, z) == "grass" then
			local cf = on(g, x, z, rng:NextNumber(0, 3))
			part(tufts, Vector3.new(1, rng:NextNumber(0.5, 1.1), 1), cf, C(70, 160, 52), Enum.Material.Plastic, { studs = true, ghost = true, noshadow = true })
			part(tufts, Vector3.new(1, rng:NextNumber(0.4, 0.8), 1), cf * CFrame.new(0.9, 0, 0.5), C(80, 172, 58), Enum.Material.Plastic, { studs = true, ghost = true, noshadow = true })
		end
	end
	-- three garden gnomes keeping watch (the game's Golden Gnome hunt)
	for _, p in { { -12, -54, 200 }, { 52, 30, 160 }, { 58, -58, 120 } } do
		CampProps.place("camp_gnome", m, on(g, p[1], p[2], math.rad(p[3])), {
			scale = 0.5,
			roles = { skin = { nil, C(255, 204, 170) }, beard = { nil, C(244, 240, 232) }, coat = { nil, C(60, 110, 200) }, pants = { nil, C(70, 70, 80) }, hat = { nil, C(220, 50, 50) } },
		})
	end
	return m
end

-------------------------------------------------------------------------------------------------------------
-- Concept B: Frost Peaks, the frozen falls
-------------------------------------------------------------------------------------------------------------
local F = {
	path = { { -2, -92 }, { -6, -64 }, { -18, -40 }, { -30, -18 }, { -34, 4 }, { -34, 24 } },
	bridgePath = { { -6, -64 }, { 20, -50 }, { 40, -36 }, { 56, -30 }, { 70, -24 } },
	crevasse = { { 50, -92 }, { 46, -50 }, { 52, -10 }, { 64, 30 }, { 72, 60 } },
	bridge = { 47, -33 },
	lake = { 2, 4, 30, 20 }, -- x, z, rx, rz
	fall = { 0, 40 }, -- foot of the frozen waterfall (x, z of the cliff face)
	crystal = { 14, 70 },
	stairs = { { -34, 24 }, { -34, 50 }, { -22, 53 }, { -22, 64 }, { -10, 70 }, { 4, 70 } },
}

local FROST_KINDS: { [string]: Kind } = {
	snow = { top = { C(242, 247, 253), C(230, 239, 250), C(248, 251, 255) }, side = { C(112, 130, 162), C(94, 112, 146), C(128, 146, 176) }, studs = true },
	path = { top = { C(198, 214, 232), C(188, 206, 226) }, side = { C(152, 172, 198), C(130, 150, 180) }, mat = Enum.Material.SmoothPlastic },
	bed = { top = { C(70, 112, 152) }, side = { C(130, 150, 180) }, mat = Enum.Material.SmoothPlastic },
	deep = { top = { C(52, 72, 112) }, side = { C(96, 118, 152), C(80, 100, 136) }, mat = Enum.Material.SmoothPlastic },
}

local function frostAt(x: number, z: number): (number, string)
	local w = (vnoise(x / 18 + 9, 2.3) - 0.5) * 12
	-- terraces up from the snowfield, then the back cliff in three ledges
	local h = math.clamp(math.floor((z + w + 30) / 16), 0, 3) * STEP
	local back = z + w * 0.6
	if back > 64 then
		h = 34
	elseif back > 54 then
		h = 24
	elseif back > 45 then
		h = 14
	end
	-- the left plateau (the crystal field), its edge jagged
	local px = x + 40 + (vnoise(z / 10, 4.4) - 0.5) * 10
	if px < 0 and z > -56 and z < 34 then
		h = math.max(h, 10)
	end
	-- the igloo camp's shelf beyond the crevasse
	if x > 60 and z > -40 and z < 30 then
		h = math.max(h, 6)
	end
	local kind = "snow"
	local e = ((x - F.lake[1]) / F.lake[3]) ^ 2 + ((z - F.lake[2]) / F.lake[4]) ^ 2
	if e < 1 then
		return -3, "bed"
	end
	if lineDist(x, z, F.crevasse) < 4.2 + vnoise(z / 8, 1) * 2 then
		return FLOOR + 4, "deep"
	end
	-- carved steps up the cliff beside the falls
	if lineDist(x, z, F.stairs) < 3 then
		return math.clamp(snap(arcAt(x, z, F.stairs) * 0.55), 0, 34), "path"
	end
	if lineDist(x, z, F.path) < 3.2 or lineDist(x, z, F.bridgePath) < 3 then
		kind = "path"
	end
	return h, kind
end

-- the hero: a frozen waterfall down the cliff into the lake, the great crystal on the cliff top
local function frozenFalls(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "Hero")
	local ice, iceDeep = C(196, 236, 255), C(140, 206, 246)
	local fx, fz = F.fall[1], F.fall[2]
	-- columns of ice from the top lip down to the lake, each a stack of blocks that narrows like an icicle
	for k = -4, 4 do
		local x = fx + k * 2.4 + rng:NextNumber(-0.4, 0.4)
		local zf = fz + rng:NextNumber(-1, 1)
		local top = 34 + rng:NextNumber(0, 1.5)
		local bottom = -1 + rng:NextNumber(0, 2)
		local y = top
		local wdt = 3 - math.abs(k) * 0.18
		while y > bottom do
			local hgt = rng:NextNumber(2.5, 5)
			local z = zf + (34 - y) * -0.42 + rng:NextNumber(-0.5, 0.5) -- leans out toward the lake as it falls
			part(f, Vector3.new(wdt, hgt, wdt * 0.9), CFrame.new(g.origin + Vector3.new(x, y - hgt / 2, z)), if rng:NextNumber() < 0.35 then iceDeep else ice, Enum.Material.Ice, { t = 0.12 })
			y -= hgt * 0.92
			wdt = math.max(1.2, wdt * rng:NextNumber(0.92, 1.04))
		end
	end
	-- the frozen pool at its foot, mounded and glowing
	for _ = 1, 9 do
		local a, d = rng:NextNumber(0, math.pi), rng:NextNumber(2, 9)
		local s = rng:NextNumber(2, 4)
		part(f, Vector3.new(s, s * 0.7, s), CFrame.new(g.origin + Vector3.new(fx + math.cos(a) * d * 1.4, -0.4 + s * 0.2, fz - 18 + math.sin(a) * d * 0.5)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), ice, Enum.Material.Ice, { t = 0.1 })
	end
	-- the great crystal: a cluster round a tall glowing core, tilted outward
	local base = CFrame.new(g.origin + Vector3.new(F.crystal[1], 34, F.crystal[2]))
	local core = C(90, 230, 255)
	part(f, Vector3.new(4.4, 34, 4.4), base * CFrame.new(0, 16, 0) * CFrame.Angles(0, math.rad(45), 0), core, Enum.Material.Neon)
	part(f, Vector3.new(7, 32, 7), base * CFrame.new(0, 15, 0) * CFrame.Angles(0, math.rad(45), 0), C(170, 236, 255), Enum.Material.Glass, { t = 0.45 })
	part(f, Vector3.new(4, 4, 4), base * CFrame.new(0, 33, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), core, Enum.Material.Neon)
	for k = 1, 7 do
		local a = k / 7 * 2 * math.pi + rng:NextNumber(-0.2, 0.2)
		local hgt = rng:NextNumber(8, 18)
		local tilt = CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(rng:NextNumber(18, 32)), 0, 0)
		local c = base * CFrame.new(math.cos(a) * 3, 0, math.sin(a) * 3) * tilt
		part(f, Vector3.new(2.6, hgt, 2.6), c * CFrame.new(0, hgt / 2, 0) * CFrame.Angles(0, math.rad(45), 0), if k % 2 == 0 then core else C(150, 220, 255), if k % 2 == 0 then Enum.Material.Neon else Enum.Material.Glass, { t = if k % 2 == 0 then 0 else 0.2 })
	end
end

local function iceFishing(parent: Instance, g: Ground)
	local f = folder(parent, "IceFishing")
	local cf = CFrame.new(g.origin + Vector3.new(14, -0.4, -4)) * CFrame.Angles(0, math.rad(-30), 0)
	part(f, Vector3.new(0.1, 2.6, 2.6), cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), C(30, 60, 100), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	part(f, Vector3.new(1.2, 1, 1.2), cf * CFrame.new(2.6, 0.5, 0.6), C(150, 100, 60), Enum.Material.Wood) -- stool
	part(f, Vector3.new(0.12, 0.12, 5), cf * CFrame.new(1.6, 1.6, -1) * CFrame.Angles(math.rad(-30), math.rad(40), 0), C(100, 70, 50), Enum.Material.Wood) -- the rod
	part(f, Vector3.new(0.05, 2.4, 0.05), cf * CFrame.new(0.2, 1, -2.2), C(240, 240, 240), Enum.Material.Fabric)
	part(f, Vector3.new(1.1, 1.2, 1.1), cf * CFrame.new(-1.8, 0.6, 1.4), C(120, 130, 140), Enum.Material.Metal, { shape = Enum.PartType.Cylinder }) -- bucket
	part(f, Vector3.new(0.4, 0.5, 1.4), cf * CFrame.new(-2.6, 0.25, -0.2) * CFrame.Angles(0, math.rad(60), 0), C(230, 140, 60), Enum.Material.Plastic) -- a fish that got away
end

local function frostLawns(parent: Instance, g: Ground, rng: Random)
	local st = { shades = { C(150, 206, 248), C(120, 186, 240), C(176, 222, 255) }, top = C(236, 248, 255), topChance = 0.35, bricks = { 3, 7 }, count = 14, width = 1 }
	lawn(parent, g, function(x, z)
		local d = ((x + 6) / 34) ^ 2 + ((z + 66) / 16) ^ 2
		return d < 1 and kindAt(g, x, z) == "snow"
	end, { -40, -84, 28, -48 }, st, rng, 4)
	lawn(parent, g, function(x, z)
		return x < -50 and x > -84 and z > -46 and z < 26 and kindAt(g, x, z) == "snow" and topAt(g, x, z) >= 10
	end, { -84, -46, -50, 26 }, st, rng, 4)
end

-- tall thin crystals in clumps on the left plateau: the zone's shape language at small scale
local function crystalField(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "Crystals")
	for _, c in { { -46, -30 }, { -44, 18 }, { -82, 30 }, { -60, -50 } } do
		local n = rng:NextInteger(3, 5)
		for k = 1, n do
			local a = rng:NextNumber(0, 2 * math.pi)
			local x, z = c[1] + math.cos(a) * rng:NextNumber(0, 3), c[2] + math.sin(a) * rng:NextNumber(0, 3)
			local hgt = if k == 1 then rng:NextNumber(9, 12) else rng:NextNumber(3, 7)
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), rng:NextNumber(0, 3), math.rad(rng:NextNumber(-22, 22)))
			local glow = k == 1 or rng:NextNumber() < 0.3
			part(f, Vector3.new(1.8, hgt, 1.8), on(g, x, z) * tilt * CFrame.new(0, hgt / 2 - 0.5, 0), if glow then C(100, 228, 255) else C(170, 226, 255), if glow then Enum.Material.Neon else Enum.Material.Glass, { t = if glow then 0 else 0.15 })
		end
	end
end

local function iceBridge(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "IceBridge")
	local x, z = F.bridge[1], F.bridge[2]
	local y = math.max(topAt(g, x - 9, z), topAt(g, x + 9, z))
	local cf = CFrame.new(g.origin + Vector3.new(x, y, z)) * CFrame.Angles(0, math.rad(80), 0)
	for k = -6, 6 do
		local lift = (1 - (k / 6) ^ 2) * 2.4
		part(f, Vector3.new(5, 0.8, 1.6), cf * CFrame.new(0, lift, k * 1.5), if k % 2 == 0 then C(190, 232, 255) else C(160, 214, 246), Enum.Material.Ice, { t = 0.1 })
	end
	for k = -6, 6, 2 do
		local lift = (1 - (k / 6) ^ 2) * 2.4
		for _, sx in { -2.4, 2.4 } do
			part(f, Vector3.new(0.6, rng:NextNumber(1, 1.8), 0.6), cf * CFrame.new(sx, lift + 1, k * 1.5), C(220, 244, 255), Enum.Material.Ice, { t = 0.1 })
		end
	end
end

function ZoneConcepts.frost(root: Instance, origin: Vector3, seed: number?)
	local rng = Random.new(seed or 23)
	local m = Instance.new("Model")
	m.Name = "B Frost - the frozen falls"
	m.Parent = root
	local g = buildGround(m, origin, frostAt, FROST_KINDS)
	-- the lake frozen over: walkable ice
	local lake = folder(m, "Lake")
	waterSheet(lake, g, function(k)
		return k == "bed"
	end, -0.3, C(172, 218, 246), Enum.Material.Ice, 0.12)
	for _, d in lake:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = true
		end
	end
	frozenFalls(m, g, rng)
	stones(m, g, F.path, { C(170, 186, 206), C(156, 172, 194), C(186, 200, 218) }, rng)
	stones(m, g, F.bridgePath, { C(170, 186, 206), C(156, 172, 194) }, rng, 4)
	iceBridge(m, g, rng)
	local trees = folder(m, "Trees")
	local look = { trunk = C(96, 70, 54), leaves = { C(44, 104, 96), C(56, 122, 108), C(36, 90, 84) }, snow = C(246, 250, 255) }
	grove(trees, g, -62, 56, 14, 5, "pine", look, rng, 1.1)
	grove(trees, g, 46, 60, 12, 5, "pine", look, rng, 1.05)
	grove(trees, g, 78, 80, 8, 3, "pine", look, rng, 0.9)
	grove(trees, g, -80, -76, 10, 5, "pine", look, rng)
	grove(trees, g, 32, -78, 9, 3, "pine", look, rng, 0.9)
	grove(trees, g, -24, 84, 8, 3, "pine", look, rng, 0.8)
	frostLawns(m, g, rng)
	crystalField(m, g, rng)
	iceFishing(m, g)
	-- the camp across the ice bridge: an igloo, a snowman, a sled
	local roles = { base = { "Snow", C(236, 244, 252) }, stone = { "Ice", C(200, 228, 250) }, accent = { nil, C(255, 255, 255) }, wood = { nil, C(150, 110, 80) }, cloth = { nil, C(72, 132, 212) }, coat = { nil, C(62, 112, 192) }, hat = { nil, C(60, 60, 70) }, door = { nil, C(72, 112, 172) }, glass = { "Neon", C(255, 222, 156) } }
	CampProps.place("camp_igloo", m, on(g, 72, -4, math.rad(250)), { roles = roles })
	CampProps.place("camp_snowman", m, on(g, 66, 14, math.rad(220)), { roles = roles })
	CampProps.place("camp_snowman", m, on(g, -12, -74, math.rad(160)), { roles = roles, scale = 0.8 })
	local sled = on(g, 64, -14, math.rad(20))
	part(m, Vector3.new(2.2, 0.4, 4.4), sled * CFrame.new(0, 0.9, 0), C(200, 60, 50), Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		part(m, Vector3.new(0.2, 0.3, 5), sled * CFrame.new(sx, 0.3, 0.2), C(60, 60, 70), Enum.Material.Metal)
	end
	return m
end

-------------------------------------------------------------------------------------------------------------
-- Concept C: Ember Ash Fields, the glowing rifts
-------------------------------------------------------------------------------------------------------------
local E = {
	path = { { 4, -92 }, { 6, -64 }, { 0, -40 }, { 8, -16 }, { 18, 6 }, { 24, 22 } },
	branch = { { 0, -40 }, { -14, -32 }, { -30, -18 }, { -46, -10 }, { -60, -4 } },
	river = { { 16, 34 }, { -4, 16 }, { -14, -6 }, { -26, -24 }, { -50, -52 }, { -72, -66 }, { -96, -78 } },
	bridge = { -25, -22.4 },
	volcano = { 30, 60 },
	flow = { { 28, 54 }, { 22, 44 }, { 16, 34 } }, -- from the crater's lip down the cone into the river
	cracks = { { { -8, -60 }, { -20, -44 }, { -24, -32 } }, { { 30, -70 }, { 16, -52 }, { 6, -46 } }, { { 40, -10 }, { 26, 0 }, { 14, 4 } } },
}

local EMBER_KINDS: { [string]: Kind } = {
	-- (in Studio's dusk light the first, near-black ground read as one murky sheet: the floor is lifted to an ash
	-- grey so the walkable ground, the path and the glow stay apart; vault: "walkable versus decorative")
	ash = { top = { C(108, 96, 96), C(98, 88, 88), C(116, 104, 102) }, side = { C(66, 58, 62), C(78, 66, 68), C(124, 72, 54) }, studs = true },
	path = { top = { C(160, 142, 128), C(148, 132, 120) }, side = { C(66, 58, 62), C(78, 66, 68) }, mat = Enum.Material.SmoothPlastic },
	lava = { top = { C(40, 30, 30) }, side = { C(40, 30, 30), C(70, 34, 26) }, mat = Enum.Material.SmoothPlastic },
}

local function emberAt(x: number, z: number): (number, string)
	local h = 0
	-- the left shelf (the ash field) and the right shelf (the miners' camp), their edges broken
	local lx = x + 40 + (vnoise(z / 7, 3.3) - 0.5) * 8
	if lx < 0 and z > -40 and z < 46 then
		h = 6
	end
	local rx = x - 38 + (vnoise(z / 7, 8.1) - 0.5) * 10
	if rx > 0 and z > -64 and z < 22 then
		h = 10
	end
	-- the volcano: a stepped cone with a crater of lava
	local dv = math.sqrt((x - E.volcano[1]) ^ 2 + (z - E.volcano[2]) ^ 2) + (vnoise(x / 9, z / 9) - 0.5) * 12
	local cone = snap(46 - dv * 1.25)
	if dv < 7 then
		return 36, "lava"
	end
	h = math.max(h, cone)
	if cone > 0 and lineDist(x, z, E.flow) < 2.6 then
		return h - 2, "lava"
	end
	-- the lava river from the volcano's foot to the front left
	if lineDist(x, z, E.river) < 4.6 then
		return h - 6, "lava"
	end
	local kind = "ash"
	if lineDist(x, z, E.path) < 3.2 then
		kind = "path"
	elseif lineDist(x, z, E.branch) < 2.8 then
		h = math.min(h, snap(math.max(0, arcAt(x, z, E.branch) - 38) * 0.5))
		kind = "path"
	end
	return h, kind
end

local function lavaSurface(parent: Instance, g: Ground)
	local f = folder(parent, "Lava")
	local hot, crust = C(255, 120, 30), C(52, 38, 36)
	local rng = Random.new(5)
	for i = 1, N do
		for j = 1, N do
			if g.kind[i][j] == "lava" then
				local x, z = cellXZ(i, j)
				local y = g.h[i][j] + 3.4
				part(f, Vector3.new(CELL, 0.6, CELL), CFrame.new(g.origin + Vector3.new(x, y - 0.3, z)), hot, Enum.Material.Neon, { ghost = true, noshadow = true, name = "Lava" })
				if rng:NextNumber() < 0.28 then
					local s = rng:NextNumber(1.2, 2.4)
					part(f, Vector3.new(s, 0.5, s * 0.8), CFrame.new(g.origin + Vector3.new(x + rng:NextNumber(-1, 1), y + 0.1, z + rng:NextNumber(-1, 1))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), crust, Enum.Material.Basalt, { ghost = true })
				end
				-- lava falls where the river steps down
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local ni, nj = i + d[1], j + d[2]
					if ni >= 1 and ni <= N and nj >= 1 and nj <= N and g.kind[ni][nj] == "lava" and g.h[ni][nj] < g.h[i][j] then
						local drop = g.h[i][j] - g.h[ni][nj]
						local size = if d[1] ~= 0 then Vector3.new(0.8, drop, CELL) else Vector3.new(CELL, drop, 0.8)
						part(f, size, CFrame.new(g.origin + Vector3.new(x + d[1] * CELL / 2, y - drop / 2, z + d[2] * CELL / 2)), C(255, 160, 50), Enum.Material.Neon, { ghost = true, noshadow = true, name = "LavaFall" })
					end
				end
			end
		end
	end
end

-- a basalt column: three turned blocks make a six-sided prism
local function column(parent: Instance, cf: CFrame, w: number, hgt: number, col: Color3)
	for k = 0, 2 do
		part(parent, Vector3.new(w * 0.58, hgt, w), cf * CFrame.new(0, hgt / 2, 0) * CFrame.Angles(0, k * math.pi / 3, 0), col, Enum.Material.Basalt, { name = "Column" })
	end
	part(parent, Vector3.new(w * 0.5, 0.3, w * 0.86), cf * CFrame.new(0, hgt + 0.1, 0), col:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Basalt)
end

local function columns(parent: Instance, g: Ground, x: number, z: number, r: number, n: number, tall: number, rng: Random)
	local f = folder(parent, "Basalt")
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10)))
	for k = 1, n do
		local a, d = rng:NextNumber(0, 2 * math.pi), r * math.sqrt(rng:NextNumber())
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		if kindAt(g, px, pz) == "ash" then
			local hgt = tall * (if k <= 2 then rng:NextNumber(0.85, 1) else rng:NextNumber(0.3, 0.7))
			column(f, on(g, px, pz, rng:NextNumber(0, 1), -0.5) * lean, rng:NextNumber(2.2, 3.4), hgt, jitter(C(62, 56, 66), rng, 0.12))
		end
	end
end

local function cracks(parent: Instance, g: Ground)
	local f = folder(parent, "Cracks")
	for _, line in E.cracks do
		for _, p in along(line, 1.6) do
			part(f, Vector3.new(0.45, 0.12, 1.9), on(g, p[1], p[2], p[3], 0.03), C(255, 110, 30), Enum.Material.Neon, { ghost = true, noshadow = true, name = "Crack" })
		end
	end
end

local function obsidianBridge(parent: Instance, g: Ground)
	local f = folder(parent, "Bridge")
	local x, z = E.bridge[1], E.bridge[2]
	local yaw = math.atan2(-16, 14) -- along the branch path
	local y = math.min(topAt(g, x - math.sin(yaw) * 11, z - math.cos(yaw) * 11), topAt(g, x + math.sin(yaw) * 11, z + math.cos(yaw) * 11))
	local cf = CFrame.new(g.origin + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw, 0)
	for k = -5, 5 do
		local lift = (1 - (k / 5) ^ 2) * 2
		part(f, Vector3.new(5.4, 1, 1.9), cf * CFrame.new(0, lift, k * 1.8), C(28, 24, 34), Enum.Material.Glass)
		part(f, Vector3.new(5.6, 0.12, 0.2), cf * CFrame.new(0, lift + 0.52, k * 1.8 + 0.9), C(255, 130, 40), Enum.Material.Neon, { ghost = true })
	end
	for _, sx in { -2.9, 2.9 } do
		for _, k in { -5, 5 } do
			part(f, Vector3.new(1, 3.6, 1), cf * CFrame.new(sx, 2.2, k * 1.8), C(36, 30, 40), Enum.Material.Glass)
			part(f, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(sx, 4.3, k * 1.8), C(255, 140, 50), Enum.Material.Neon)
		end
	end
end

local function minersCamp(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "Miners")
	local cf = on(g, 62, -30, math.rad(-100))
	local metal = C(70, 66, 70)
	-- rails into the rock, a cart of glowing ore at their end
	for k = -3, 3 do
		part(f, Vector3.new(3.2, 0.3, 0.6), cf * CFrame.new(0, 0.15, k * 2), C(96, 70, 52), Enum.Material.Wood)
	end
	for _, sx in { -1, 1 } do
		part(f, Vector3.new(0.3, 0.3, 14), cf * CFrame.new(sx, 0.45, 0), metal, Enum.Material.Metal)
	end
	part(f, Vector3.new(2.8, 2, 3.6), cf * CFrame.new(0, 1.9, 3), C(84, 78, 80), Enum.Material.CorrodedMetal)
	for _ = 1, 6 do
		part(f, Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(rng:NextNumber(-0.9, 0.9), 3.1, 3 + rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0), C(255, 140, 40), Enum.Material.Neon)
	end
	for _, sx in { -1.2, 1.2 } do
		for _, z in { 1.8, 4.2 } do
			part(f, Vector3.new(0.4, 0.9, 0.9), cf * CFrame.new(sx, 0.9, z), C(40, 36, 38), Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		end
	end
	-- a pickaxe left in a rock, and a lantern
	rock(f, cf * CFrame.new(5, 0, -3), 2.6, C(70, 62, 66), rng, Enum.Material.Basalt)
	part(f, Vector3.new(0.3, 4, 0.3), cf * CFrame.new(5, 3.4, -3) * CFrame.Angles(math.rad(20), 0, math.rad(-15)), C(120, 86, 56), Enum.Material.Wood)
	part(f, Vector3.new(3, 0.4, 0.4), cf * CFrame.new(5.5, 5.2, -2.4) * CFrame.Angles(math.rad(20), 0, math.rad(-15)), metal, Enum.Material.Metal)
	part(f, Vector3.new(0.3, 4.6, 0.3), cf * CFrame.new(-4, 2.3, 4), C(80, 60, 44), Enum.Material.Wood)
	part(f, Vector3.new(1, 1.2, 1), cf * CFrame.new(-4, 4.2, 4), C(255, 170, 70), Enum.Material.Neon)
end

local function volcanoTop(parent: Instance, g: Ground, rng: Random)
	local f = folder(parent, "Hero")
	local cf = CFrame.new(g.origin + Vector3.new(E.volcano[1], 36, E.volcano[2]))
	-- the crater's rim: broken teeth round the glowing lake, and a glow above it
	for k = 1, 11 do
		local a = k / 11 * 2 * math.pi
		local hgt = rng:NextNumber(3, 7)
		part(f, Vector3.new(4, hgt, 3), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, hgt / 2 - 0.5, 8.5) * CFrame.Angles(math.rad(rng:NextNumber(-14, 8)), 0, 0), jitter(C(52, 44, 48), rng, 0.1), Enum.Material.Basalt)
	end
	part(f, Vector3.new(10, 1, 10), cf * CFrame.new(0, 3.6, 0), C(255, 150, 50), Enum.Material.Neon, { t = 0.6, ghost = true, noshadow = true })
end

local function emberLawns(parent: Instance, g: Ground, rng: Random)
	local st = { shades = { C(64, 52, 58), C(80, 64, 70) }, top = C(255, 120, 40), topNeon = true, topChance = 0.22, bricks = { 3, 6 }, count = 13, width = 1 }
	lawn(parent, g, function(x, z)
		return x < -40 and x > -84 and z > -30 and z < 40 and kindAt(g, x, z) == "ash" and topAt(g, x, z) == 6
	end, { -84, -30, -40, 40 }, st, rng, 4)
	lawn(parent, g, function(x, z)
		local d = ((x - 40) / 30) ^ 2 + ((z + 78) / 10) ^ 2
		return d < 1 and kindAt(g, x, z) == "ash"
	end, { 10, -88, 70, -68 }, st, rng, 4)
end

function ZoneConcepts.ember(root: Instance, origin: Vector3, seed: number?)
	local rng = Random.new(seed or 37)
	local m = Instance.new("Model")
	m.Name = "C Ember - the glowing rifts"
	m.Parent = root
	local g = buildGround(m, origin, emberAt, EMBER_KINDS)
	lavaSurface(m, g)
	volcanoTop(m, g, rng)
	stones(m, g, E.path, { C(184, 164, 150), C(170, 152, 140), C(196, 176, 160) }, rng)
	stones(m, g, E.branch, { C(184, 164, 150), C(170, 152, 140) }, rng, 4)
	obsidianBridge(m, g)
	cracks(m, g)
	columns(m, g, 48, -40, 9, 9, 18, rng)
	columns(m, g, 44, 10, 7, 7, 14, rng)
	columns(m, g, -70, 60, 12, 11, 22, rng)
	columns(m, g, -10, 46, 6, 5, 12, rng)
	columns(m, g, 74, 70, 10, 7, 16, rng)
	local trees = folder(m, "Trees")
	local look = { trunk = C(34, 30, 34), leaves = {}, tip = C(255, 120, 40) }
	grove(trees, g, -60, -78, 10, 3, "dead", look, rng)
	grove(trees, g, 72, -84, 8, 3, "dead", look, rng, 0.8)
	grove(trees, g, -82, 20, 6, 3, "dead", look, rng)
	emberLawns(m, g, rng)
	minersCamp(m, g, rng)
	-- vents: little stepped mounds breathing glow
	for _, v in { { -36, 20 }, { 30, -40 }, { -64, -20 } } do
		local cf = on(g, v[1], v[2])
		part(m, Vector3.new(5, 1.4, 5), cf * CFrame.new(0, 0.7, 0), C(60, 50, 54), Enum.Material.Basalt)
		part(m, Vector3.new(3.4, 1.2, 3.4), cf * CFrame.new(0, 2, 0), C(54, 44, 48), Enum.Material.Basalt)
		part(m, Vector3.new(1.6, 0.3, 1.6), cf * CFrame.new(0, 2.7, 0), C(255, 140, 40), Enum.Material.Neon)
	end
	return m
end

-------------------------------------------------------------------------------------------------------------
-- build them all into Workspace.ConceptLab (replacing an old one)
-------------------------------------------------------------------------------------------------------------
function ZoneConcepts.build(parent: Instance?, only: string?): Folder
	local into = parent or workspace
	local old = into:FindFirstChild("ConceptLab")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ConceptLab"
	for _, id in { "meadow", "frost", "ember" } do
		local fn = (ZoneConcepts :: any)[id]
		if fn and (only == nil or only == id) then
			fn(root, ZoneConcepts.ORIGIN[id])
		end
	end
	root.Parent = into
	return root
end

return ZoneConcepts
