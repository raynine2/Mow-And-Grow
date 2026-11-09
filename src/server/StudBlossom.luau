--!strict
-- STUD BLOSSOM (7 Nov 2026; owner on the forge: "Perfect", after "Top, doe de volgende" at the chalet's level of
-- detail). The blossom isle's pagoda gazebo (forge_lm_blossom) rebuilt from studded bricks, measured off square-on
-- pictures of the mesh (front, +X side, top; a stud = 26.4 pixels):
--   a hexagonal gazebo (centre 3.3 behind the pivot, corners to +-X): a lawn edged with rose hedges, a cream-rimmed
--   floor, two steps down the front face, six cream columns on plinths with roses climbing them, shallow arches and
--   a lintel between their tops, wooden brackets under the eaves, a balustrade round five faces with stone balls and
--   red lanterns at the front corners
--   three pink tiled roofs (hexagonal, curved, the corners turned up and tipped in cream, cream ribs down the hips)
--   on two little drums with posts, a gold finial
--   the cherry tree behind it: a dark trunk curling up through the back, branches out both ways, a crown of studded
--   pink blocks (as the mesh's, flat-ish, standing behind the gazebo; on the isle the island's own voxel tree hides
--   most of it, as it does the mesh's)
--   a round stone plaza in front: a pool with a fountain on a pedestal, rose beds either side, posts with balls
-- Model space as the mesh's: front to -Z, the pivot at the bottom middle. StudBlossom.build(K) fills a StudKit.
local StudKit = require(script.Parent.StudKit)

type Kit = StudKit.Kit
local C = Color3.fromRGB
local V = Vector3.new
local Y = Vector3.yAxis

local StudBlossom = {}

local CREAM = { C(226, 212, 192), C(206, 190, 170) }
local FLOOR = C(196, 166, 146)
local ROOF = { C(206, 52, 98), C(186, 40, 84) }
local DRUM = C(126, 62, 70)
local BRACKET = C(150, 74, 30)
local GOLD = C(214, 150, 60)
local LAWN = { C(62, 104, 42), C(50, 88, 34) }
local LEAF = { C(52, 96, 40), C(68, 114, 48) }
local ROSE = { C(212, 36, 76), C(232, 76, 116), C(186, 28, 62) }
local WHITE = C(232, 234, 236)
local WATER = C(76, 164, 228)
local TRUNK = { C(70, 40, 40), C(56, 30, 32) }
local BLOSSOM = { C(236, 150, 196), C(222, 118, 176), C(204, 96, 156), C(246, 182, 214) }
local LANTERN = C(226, 70, 58)

-------------------------------------------------------------------------------------------------------------
-- the hexagon: centre GC, corner i at angle i * 60 degrees (corner 0 to +X; 4 and 5 are the front corners)
-------------------------------------------------------------------------------------------------------------
local GC = V(0, 0, 3.3)

local function corner(r: number, i: number, y: number): Vector3
	local a = i * math.pi / 3
	return V(GC.X + r * math.cos(a), y, GC.Z + r * math.sin(a))
end

-- outward (horizontal) from the middle toward a point
local function outward(p: Vector3): Vector3
	return V(p.X - GC.X, 0, p.Z - GC.Z).Unit
end

local function blob(K: Kit, name: string, size: Vector3, cf: CFrame, col: Color3): Part
	local p = K:brick(name, size, cf, col, true)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- an upright disc (a cylinder mesh): `at` its middle, radius r, h tall
local function disc(K: Kit, name: string, at: Vector3, r: number, h: number, col: Color3): Part
	local p = K:brick(name, V(h, r * 2, r * 2), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), col, true)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Cylinder
	m.Parent = p
	return p
end

-- a round bar from a to b, d thick (a cylinder), with a ball on its far end so bends look smooth
local function limb(K: Kit, name: string, a: Vector3, b: Vector3, d: number, col: Color3)
	local dir = b - a
	local up = if math.abs(dir.Unit.Y) > 0.95 then Vector3.zAxis else Y
	K:rod(name, d, dir.Magnitude, CFrame.fromMatrix((a + b) / 2, dir.Unit, up:Cross(dir.Unit).Unit), col)
	K:ball(name, d, b, col)
end

-- an arc of bricks round `c` (radius r, t thick, h tall from y0) from angle a0 to a1 (radians, x = cos, z = sin)
local function arcWall(K: Kit, name: string, c: Vector3, r: number, y0: number, h: number, t: number, a0: number, a1: number, n: number, col: Color3)
	for k = 0, n - 1 do
		local a = a0 + (a1 - a0) * (k + 0.5) / n
		local w = 2 * r * math.sin((a1 - a0) / n / 2) + 0.06
		local p = c + V(math.cos(a) * r, y0 + h / 2, math.sin(a) * r)
		K:brick(name, V(w, h, t), CFrame.lookAt(p, p + V(math.cos(a), 0, math.sin(a))), col, true)
	end
end

local function rose(K: Kit, at: Vector3, d: number, k: number)
	K:ball("Rose", d, at, ROSE[k % 3 + 1])
	K:brick("RoseLeaf", V(d * 0.9, d * 0.35, d * 0.9), CFrame.new(at - V(0, d * 0.35, 0)) * CFrame.Angles(0, k * 0.7, 0), LEAF[k % 2 + 1], true)
end

-------------------------------------------------------------------------------------------------------------
-- the ground: lawn, floor, steps, rose hedges
-------------------------------------------------------------------------------------------------------------
local FLOOR_R, FLOOR_Y = 9.8, 1.6

local function ground(K: Kit)
	local mid0, mid1 = V(GC.X, 0.4, GC.Z), V(GC.X, FLOOR_Y, GC.Z)
	for i = 0, 5 do
		K:tri("Lawn", mid0, corner(11.2, i, 0.4), corner(11.2, i + 1, 0.4), LAWN[2], V(GC.X, 0, GC.Z), 0.4)
		K:tri("Floor", mid1, corner(FLOOR_R, i, FLOOR_Y), corner(FLOOR_R, i + 1, FLOOR_Y), FLOOR, V(GC.X, 0.4, GC.Z), FLOOR_Y - 0.4)
		-- a cream rim round the floor's edge
		local a, b = corner(FLOOR_R + 0.12, i, FLOOR_Y - 0.25), corner(FLOOR_R + 0.12, i + 1, FLOOR_Y - 0.25)
		K:beam("FloorRim", a, b, 0.55, 0.3, CREAM[1], outward((a + b) / 2), true)
	end
	-- two steps down the front face (between the front corners)
	K:box("Step", -4.9, 0.4, -5.95, 4.9, 1.2, -5.1, CREAM[1])
	K:box("Step", -4.9, 0.4, -6.7, 4.9, 0.8, -5.9, CREAM[2])
	-- rose hedges round the other five faces, roses along their tops
	for i = 0, 5 do
		if i ~= 4 then
			local a, b = corner(10.45, i, 0.95), corner(10.45, i + 1, 0.95)
			K:beam("Hedge", a, b, 1.2, 1.1, LAWN[1], Y)
			for k = 0, 6 do
				local p = a + (b - a) * ((k + 0.5) / 7) + V(0, 0.75, 0) + outward((a + b) / 2) * (if k % 2 == 0 then 0.35 else -0.2)
				rose(K, p, 0.7, i + k)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the gazebo: columns, arches, lintel, brackets, balustrade, lanterns
-------------------------------------------------------------------------------------------------------------
local COL_R, COL_TOP = 6.7, 9.6

local function columns(K: Kit)
	for i = 0, 5 do
		local p = corner(COL_R, i, 0)
		K:box("ColumnBase", p.X - 0.7, FLOOR_Y, p.Z - 0.7, p.X + 0.7, 2.6, p.Z + 0.7, CREAM[2])
		K:box("ColumnBase", p.X - 0.6, 2.6, p.Z - 0.6, p.X + 0.6, 2.85, p.Z + 0.6, CREAM[1], true)
		K:cyl("Column", 0.95, COL_TOP - 0.35 - 2.85, p + V(0, (2.85 + COL_TOP - 0.35) / 2, 0), CREAM[1])
		K:box("ColumnCap", p.X - 0.65, COL_TOP - 0.35, p.Z - 0.65, p.X + 0.65, COL_TOP, p.Z + 0.65, CREAM[2], true)
		-- the lintel to the next column, and a shallow arch under it
		local q = corner(COL_R, i + 1, 0)
		local n = outward((p + q) / 2)
		K:beam("Lintel", p + V(0, COL_TOP + 0.25, 0), q + V(0, COL_TOP + 0.25, 0), 0.5, 0.55, CREAM[1], n, true)
		local m, d = (p + q) / 2, (q - p).Unit
		local R, cy = 3.6, 5.7
		local prev: Vector3? = nil
		for k = 0, 6 do
			local th = math.rad(-52 + 104 * k / 6)
			local pt = m + d * (R * math.sin(th)) + V(0, cy + R * math.cos(th), 0)
			if prev then
				K:beam("Arch", prev, pt, 0.35, 0.4, CREAM[2], n, true)
			end
			prev = pt
		end
		-- a wooden bracket under the eave, out from the column's top
		local o = outward(p)
		K:box("BracketBlock", p.X - 0.35, COL_TOP, p.Z - 0.35, p.X + 0.35, COL_TOP + 0.45, p.Z + 0.35, BRACKET, true)
		K:beam("Bracket", p + V(0, COL_TOP + 0.2, 0), p + o * 1.1 + V(0, COL_TOP + 1.0, 0), 0.32, 0.4, BRACKET, Y, true)
	end
end

local function balustrade(K: Kit)
	local R = FLOOR_R - 0.35
	for i = 0, 5 do
		local a, b = corner(R, i, 0), corner(R, i + 1, 0)
		if i ~= 4 then
			K:beam("Rail", a + V(0, 1.75, 0), b + V(0, 1.75, 0), 0.4, 0.25, CREAM[2], Y, true)
			K:beam("Rail", a + V(0, 3.45, 0), b + V(0, 3.45, 0), 0.45, 0.28, CREAM[1], Y, true)
			local len = (b - a).Magnitude
			local nb = math.floor((len - 1.0) / 0.55)
			for k = 1, nb do
				local p = a + (b - a) * (0.5 + (k - 0.5) * (len - 1.0) / nb) / len
				K:cyl("Baluster", 0.3, 1.5, p + V(0, 2.6, 0), CREAM[1])
				K:ball("Baluster", 0.42, p + V(0, 2.45, 0), CREAM[1])
			end
		end
		-- a post at every corner with a stone ball, a red lantern at the front corners instead
		local c = corner(R, i, 0)
		if i == 4 or i == 5 then
			K:box("LanternPost", c.X - 0.35, FLOOR_Y, c.Z - 0.35, c.X + 0.35, 2.9, c.Z + 0.35, CREAM[2])
			local lamp = K:box("Lantern", c.X - 0.38, 2.9, c.Z - 0.38, c.X + 0.38, 3.6, c.Z + 0.38, LANTERN, true)
			lamp.Material = Enum.Material.Neon
			lamp.Color = LANTERN
			K:box("LanternCap", c.X - 0.5, 3.6, c.Z - 0.5, c.X + 0.5, 3.8, c.Z + 0.5, CREAM[1], true)
			K:ball("LanternTop", 0.35, c + V(0, 3.95, 0), CREAM[1])
		else
			K:box("RailPost", c.X - 0.33, FLOOR_Y, c.Z - 0.33, c.X + 0.33, 3.75, c.Z + 0.33, CREAM[2])
			K:ball("RailBall", 0.55, c + V(0, 4.0, 0), CREAM[1])
		end
	end
end

-- roses climbing a column (on its outer side), with a vine and a few hanging off its top
local function climbingRoses(K: Kit, i: number)
	local p = corner(COL_R, i, 0)
	local o = outward(p)
	local side = V(-o.Z, 0, o.X)
	for k = 0, 6 do
		local y = 3.3 + k * 0.95
		local s = (if k % 2 == 0 then 0.3 else -0.3)
		rose(K, p + o * 0.55 + side * s + V(0, y, 0), 0.75 - (k % 3) * 0.08, i + k)
	end
	for k = 0, 3 do
		local a = p + o * 0.5 + side * (if k % 2 == 0 then 0.45 else -0.45) + V(0, 3.0 + k * 1.6, 0)
		local b = p + o * 0.5 + side * (if k % 2 == 0 then -0.45 else 0.45) + V(0, 3.0 + (k + 1) * 1.6, 0)
		K:beam("Vine", a, b, 0.14, 0.12, LEAF[1], o, true)
	end
	for k = 0, 1 do
		rose(K, p + o * 1.05 + side * (k * 0.8 - 0.4) + V(0, COL_TOP - 0.6 - k * 0.5, 0), 0.6, i + k + 3)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the roofs: hexagonal, in rings from the eave up; the eave's middles sag, its corners turn up
-------------------------------------------------------------------------------------------------------------
-- rings: { r, y at the corners, y at the middles of the sides }, eave first
local function hexRoof(K: Kit, rings: { { number } }, tipD: number)
	local inside = V(GC.X, rings[#rings][2] - 3, GC.Z)
	for k = 1, #rings - 1 do
		local r0, r1 = rings[k], rings[k + 1]
		for i = 0, 5 do
			local A, B = corner(r0[1], i, r0[2]), corner(r0[1], i + 1, r0[2])
			local A1, B1 = corner(r1[1], i, r1[2]), corner(r1[1], i + 1, r1[2])
			local M = (A + B) / 2 + V(0, r0[3] - r0[2], 0)
			local M1 = (A1 + B1) / 2 + V(0, r1[3] - r1[2], 0)
			local col = ROOF[(k + i) % 2 + 1]
			K:quad("Roof", A, M, M1, A1, col, inside, 0.3)
			K:quad("Roof", M, B, B1, M1, col, inside, 0.3)
			-- a darker line along the bottom of each ring of tiles
			K:beam("RoofLine", A + (M - A) * 0.02 + V(0, 0.17, 0), M + V(0, 0.17, 0), 0.12, 0.05, C(150, 28, 66), Y, true)
			K:beam("RoofLine", M + V(0, 0.17, 0), B + (M - B) * 0.02 + V(0, 0.17, 0), 0.12, 0.05, C(150, 28, 66), Y, true)
		end
	end
	-- cream trim along the eaves, cream ribs down the hips, turned-up tips at the corners
	local e = rings[1]
	for i = 0, 5 do
		local A, B = corner(e[1] + 0.05, i, e[2] - 0.15), corner(e[1] + 0.05, i + 1, e[2] - 0.15)
		local M = (A + B) / 2 + V(0, e[3] - e[2], 0)
		K:beam("EaveTrim", A, M, 0.3, 0.35, CREAM[1], outward(M), true)
		K:beam("EaveTrim", M, B, 0.3, 0.35, CREAM[1], outward(M), true)
		for k = 1, #rings - 1 do
			local a, b = corner(rings[k][1], i, rings[k][2] + 0.2), corner(rings[k + 1][1], i, rings[k + 1][2] + 0.2)
			K:beam("Rib", a, b, 0.28, 0.25, CREAM[1], Y, true)
		end
		local tip = corner(e[1], i, e[2])
		local o = outward(tip)
		K:beam("RoofTip", tip, tip + o * tipD * 0.8 + V(0, tipD * 0.7, 0), 0.3, 0.3, CREAM[1], Y, true)
		K:ball("RoofTip", tipD * 0.55, tip + o * tipD * 0.8 + V(0, tipD * 0.75, 0), CREAM[2])
	end
end

-- a little drum between two roofs: a dark core, posts at the corners, a cream band at the top
local function drum(K: Kit, r: number, y0: number, y1: number)
	local mid = V(GC.X, y1, GC.Z)
	for i = 0, 5 do
		K:tri("Drum", mid, corner(r - 0.3, i, y1), corner(r - 0.3, i + 1, y1), DRUM, V(GC.X, y0, GC.Z), y1 - y0)
		local p = corner(r, i, 0)
		K:box("DrumPost", p.X - 0.22, y0, p.Z - 0.22, p.X + 0.22, y1, p.Z + 0.22, CREAM[1], true)
		local a, b = corner(r + 0.02, i, y1 - 0.15), corner(r + 0.02, i + 1, y1 - 0.15)
		K:beam("DrumBand", a, b, 0.3, 0.25, CREAM[2], outward((a + b) / 2), true)
		local a2, b2 = corner(r + 0.02, i, y0 + 0.3), corner(r + 0.02, i + 1, y0 + 0.3)
		K:beam("DrumRail", a2, b2, 0.22, 0.2, CREAM[2], outward((a2 + b2) / 2), true)
	end
end

local function roofs(K: Kit)
	hexRoof(K, { { 8.7, 11.45, 10.85 }, { 6.9, 11.65, 11.45 }, { 5.0, 12.05, 12.0 }, { 3.0, 12.5, 12.5 } }, 0.7)
	drum(K, 3.0, 12.4, 14.0)
	-- two roses on the drum's front
	for _, x in { 0.9, -1.1 } do
		rose(K, V(x, 12.7, GC.Z - 2.75), 0.75, 2)
	end
	hexRoof(K, { { 4.4, 14.85, 14.3 }, { 3.0, 15.05, 14.95 }, { 1.85, 15.4, 15.4 } }, 0.5)
	drum(K, 1.8, 15.3, 16.75)
	hexRoof(K, { { 2.75, 17.6, 17.15 }, { 1.6, 18.1, 18.0 }, { 0.5, 19.25, 19.25 } }, 0.4)
	-- the cream band at the top and the gold finial
	K:cyl("Finial", 1.0, 0.3, V(GC.X, 19.4, GC.Z), CREAM[1])
	K:ball("Finial", 0.65, V(GC.X, 19.85, GC.Z), GOLD)
	K:cone("Finial", V(GC.X, 20.0, GC.Z), 0.32, 2.1, 6, { GOLD, C(196, 130, 48) }, 0.1)
	K:cyl("Finial", 0.5, 0.15, V(GC.X, 20.5, GC.Z), GOLD)
end

-------------------------------------------------------------------------------------------------------------
-- the cherry tree behind it
-------------------------------------------------------------------------------------------------------------
local function tree(K: Kit)
	local trunk = { { V(0.8, 0.4, 10.0), 2.4 }, { V(1.4, 3.5, 9.9), 2.0 }, { V(0.4, 6.5, 9.7), 1.8 }, { V(-0.6, 9.0, 9.4), 1.6 }, { V(-0.4, 11.8, 9.0), 1.45 } }
	for i = 1, #trunk - 1 do
		limb(K, "Trunk", trunk[i][1], trunk[i + 1][1], trunk[i + 1][2], TRUNK[i % 2 + 1])
	end
	local branches = {
		{ V(-0.4, 11.8, 9.0), V(2.5, 13.2, 8.6), V(5.5, 14.8, 8.0), V(8.5, 16.0, 7.6) },
		{ V(-0.4, 11.8, 9.0), V(-3.0, 13.0, 8.6), V(-6.0, 14.6, 8.0), V(-9.0, 15.4, 7.6) },
		{ V(-0.4, 11.8, 9.0), V(0.3, 14.5, 8.6), V(0.8, 17.5, 8.0) },
		{ V(-0.6, 9.0, 9.4), V(-3.5, 10.5, 9.0), V(-7.0, 11.2, 8.3), V(-9.5, 10.6, 7.8) },
		{ V(-0.6, 9.0, 9.4), V(3.5, 10.0, 9.0), V(6.5, 9.6, 8.4), V(8.6, 8.4, 7.8) },
	}
	for bi, br in branches do
		for i = 1, #br - 1 do
			limb(K, "Branch", br[i], br[i + 1], 1.0 - i * 0.2, TRUNK[(bi + i) % 2 + 1])
		end
	end
	-- the crown: studded pink blocks on a grid inside its lobes (front view), a little ragged at the edges, lighter
	-- toward the top, a second layer behind where it's thick
	local lobes = {
		{ 9.8, 15.2, 3.6, 3.0 }, { 6.8, 18.6, 3.6, 2.9 }, { 1.2, 20.6, 4.6, 2.4 }, { -5.6, 18.6, 4.0, 2.7 },
		{ -8.6, 11.9, 4.0, 2.4 }, { 9.2, 7.9, 2.0, 1.5 }, { -8.8, 16.6, 1.8, 1.7 }, { 1.0, 17.2, 3.4, 1.6 },
	}
	local STEP = 1.35
	local function noise(x: number, y: number): number
		local v = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
		return v - math.floor(v)
	end
	for gx = -13.5, 14.0, STEP do
		for gy = 6.2, 23.6, STEP do
			local u = math.huge
			for _, l in lobes do
				u = math.min(u, ((gx - l[1]) / l[3]) ^ 2 + ((gy - l[2]) / l[4]) ^ 2)
			end
			local n1, n2, n3 = noise(gx, gy), noise(gy, gx), noise(gx + 3.1, gy - 1.7)
			if u < 0.72 + 0.4 * n1 then
				local s = 1.35 + 0.5 * n2
				local tone = math.clamp((gy - 7) / 15, 0, 1)
				local col = if n3 > 0.8 then BLOSSOM[3] elseif tone > 0.6 then BLOSSOM[(n2 > 0.5) and 4 or 1] elseif tone > 0.3 then BLOSSOM[(n2 > 0.5) and 1 or 2] else BLOSSOM[(n2 > 0.5) and 2 or 3]
				K:brick("Blossom", V(s, s, s), CFrame.new(gx + (n3 - 0.5) * 0.3, gy, 7.0 + (n3 - 0.5) * 1.2), col)
				if u < 0.55 then
					K:brick("Blossom", V(s, s, s), CFrame.new(gx + 0.5, gy - 0.4, 8.3 + (n1 - 0.5) * 0.6), BLOSSOM[(n1 > 0.5) and 2 or 3])
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the plaza in front: pool, fountain, rose beds, posts
-------------------------------------------------------------------------------------------------------------
local F = V(0, 0, -9.5)

local function plaza(K: Kit)
	disc(K, "Plaza", F + V(0, 0.2, 0), 5.6, 0.4, CREAM[2])
	arcWall(K, "PlazaRim", F, 5.65, 0, 0.65, 0.45, math.rad(170), math.rad(370), 16, CREAM[1])
	-- the pool: a cream rim, the water, the fountain on a pedestal in the middle
	arcWall(K, "PoolRim", F, 2.85, 0.4, 0.85, 0.45, 0, math.pi * 2, 14, CREAM[1])
	disc(K, "Water", F + V(0, 0.95, 0), 2.65, 0.15, WATER)
	disc(K, "Fountain", F + V(0, 1.9, 0), 1.05, 2.0, WHITE)
	disc(K, "Fountain", F + V(0, 3.05, 0), 1.25, 0.35, WHITE)
	local top = disc(K, "FountainWater", F + V(0, 3.24, 0), 1.0, 0.06, WATER)
	top.Material = Enum.Material.SmoothPlastic
	K:cyl("Spout", 0.4, 0.8, F + V(0, 3.6, 0), WHITE)
	K:ball("Spout", 0.6, F + V(0, 4.05, 0), WHITE)
	K:cyl("Jet", 0.18, 0.5, F + V(0, 4.55, 0), C(200, 232, 250))
	-- rose beds either side of the pool, posts with stone balls round it
	for _, s in { -1, 1 } do
		for k, a in { -30, 0, 30 } do
			local ang = math.rad(if s > 0 then a else 180 - a)
			local p = F + V(math.cos(ang) * 4.15, 0.75, math.sin(ang) * 4.15)
			blob(K, "RoseBed", V(1.9, 0.9, 1.5), CFrame.lookAt(p, p + V(math.cos(ang), 0, math.sin(ang))), LAWN[1])
			for j = 0, 2 do
				rose(K, p + V((j - 1) * 0.55 * math.sin(ang), 0.45 + (j % 2) * 0.1, -(j - 1) * 0.55 * math.cos(ang)), 0.62, k + j)
			end
		end
	end
	for _, a in { -50, -130, 50, 130 } do
		local p = F + V(math.cos(math.rad(a)) * 3.45, 0, math.sin(math.rad(a)) * 3.45)
		K:box("PlazaPost", p.X - 0.25, 0.4, p.Z - 0.25, p.X + 0.25, 1.45, p.Z + 0.25, CREAM[1])
		K:ball("PlazaBall", 0.5, p + V(0, 1.7, 0), CREAM[2])
	end
end

-- a few rose petals drifting down in front of the columns
local function petals(K: Kit)
	for k, p in { V(4.6, 6.2, -3.6), V(2.4, 4.4, -3.9), V(-4.2, 7.4, -3.4), V(-2.6, 5.0, -4.1), V(6.4, 4.0, -1.8), V(-6.6, 5.6, -1.6), V(1.0, 8.2, -3.8), V(-1.4, 6.8, -4.4) } do
		K:brick("Petal", V(0.32, 0.08, 0.26), CFrame.new(p) * CFrame.Angles(k * 0.7, k * 1.3, k * 0.4), ROSE[k % 2 + 1], true)
	end
end

function StudBlossom.build(K: Kit)
	ground(K)
	columns(K)
	balustrade(K)
	for _, i in { 0, 3, 4, 5 } do
		climbingRoses(K, i)
	end
	roofs(K)
	tree(K)
	plaza(K)
	petals(K)
end

return StudBlossom
