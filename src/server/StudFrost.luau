--!strict
-- STUD FROST (7 Nov 2026; owner on the redone farm, swamp and lookout: "Top, doe de volgende"). The frost isle's
-- chalet (forge_lm_frost) rebuilt from studded bricks, measured off square-on pictures of the mesh (front, sides,
-- top; a stud = 26.4 pixels):
--   a snowy ground; the chalet on a dark stone footing: cream plaster walls between dark timbers, warm arched windows
--   a steep A-frame roof: blue slate under thick snow (bare in a patch on each side), rounded snow lips along every
--   edge, icicles hanging from the eaves
--   the front gable in timber and plaster: a tie beam, braces, a tall pointed window glowing warm, a blue gem in a
--   timber diamond above it and another at the apex
--   a porch: posts, a small snowy gable roof with a timber X and a gem, a snowy lean-to beside it, the door, a window,
--   a wall lantern, low railings with snow on their posts, wooden steps
--   a stone chimney with a snow cap; a cluster of tall ice crystals behind the left side; a stone pillar with a gem;
--   two skis and poles leaning by the porch; snowy pines round about; drifts, a stone footing, chimney smoke and a
--   light snowfall (owner: "Meer details en mooier")
-- Model space as the mesh's: front to -Z, the pivot at the bottom middle. StudFrost.build(K) fills a StudKit.
local StudKit = require(script.Parent.StudKit)

type Kit = StudKit.Kit
local C = Color3.fromRGB
local V = Vector3.new
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local StudFrost = {}

local SNOW = { C(218, 230, 248), C(204, 218, 242) }
local PLASTER = C(206, 190, 160)
local TIMBER = { C(80, 48, 28), C(66, 40, 24) }
local SLATE = { C(100, 124, 176), C(88, 110, 160) }
local STONE = { C(100, 100, 106), C(86, 86, 94) }
local STONES = { C(104, 104, 112), C(88, 88, 98), C(116, 114, 122) }
local STEP = { C(92, 60, 38), C(80, 52, 32) }
local WARM = C(255, 196, 110)
local GEM = C(70, 170, 255)
local ICE = C(70, 186, 246)
local ICE_HI = C(150, 222, 255)
local ICICLE = C(206, 234, 252)
local PINE = { C(40, 76, 50), C(32, 64, 42) }
local BARK = C(84, 56, 36)
local SKI = C(40, 62, 116)
local DARK = C(40, 40, 52)

local RX = -0.45 -- the ridge
local SPAN = 7.75 -- the snow's eave from the ridge
local EAVE, APEX = 9.0, 20.6 -- the snow's outer line
local RZ0, RZ1 = -6.0, 8.9 -- the roof's ends
local HX0, HX1, HZ0, HZ1 = -5.6, 5.0, -5.6, 8.6 -- the walls
local FOOT = 3.2 -- the footing's top, the floor

-- a downward icicle (two wedges) hanging from `at`
local function icicle(K: Kit, at: Vector3, len: number, k: number)
	K:prism("Icicle", CFrame.new(at) * CFrame.Angles(0, k * 0.7, math.pi), 0.22, 0.42, len, ICICLE)
end

-- a rounded snow lip (a cylinder) from a to b
local function lip(K: Kit, a: Vector3, b: Vector3, d: number)
	local dir = b - a
	K:rod("SnowLip", d, dir.Magnitude + d * 0.3, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), SNOW[1])
end

-- a smooth rounded lump (drifts, snow on posts and sills): a sphere mesh stretched to `size`
local function blob(K: Kit, name: string, size: Vector3, cf: CFrame, col: Color3): Part
	local p = K:brick(name, size, cf, col, true)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- a stone footing: a dark core with stones in staggered courses on its four faces
local function stoneBlock(K: Kit, x0: number, z0: number, x1: number, z1: number, y0: number, y1: number)
	K:box("FootingCore", x0 + 0.1, y0, z0 + 0.1, x1 - 0.1, y1, z1 - 0.1, STONE[2], true)
	local courses = math.max(1, math.round((y1 - y0) / 0.68))
	local ch = (y1 - y0) / courses
	local faces = { { V(x0, 0, z0), V(x1, 0, z0), -Z }, { V(x1, 0, z1), V(x0, 0, z1), Z }, { V(x0, 0, z1), V(x0, 0, z0), -X }, { V(x1, 0, z0), V(x1, 0, z1), X } }
	for fi, f in faces do
		local a, b, out = f[1], f[2], f[3]
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		for c = 0, courses - 1 do
			local y = y0 + (c + 0.5) * ch
			local pos = if c % 2 == 0 then 0 else -0.6
			local k = 0
			while pos < len - 0.05 do
				local w = 1.2 + ((fi + c + k) % 3) * 0.15
				local s0, s1 = math.max(pos, 0), math.min(pos + w, len)
				if s1 - s0 > 0.15 then
					local mid = a + dir * ((s0 + s1) / 2) + out * 0.08 + V(0, y, 0)
					K:brick("Stone", V(s1 - s0 - 0.06, ch - 0.06, 0.3), CFrame.lookAt(mid, mid + out), STONES[(fi + c + k) % 3 + 1])
				end
				pos += w
				k += 1
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the ground, the footing, the walls
-------------------------------------------------------------------------------------------------------------
local function ground(K: Kit)
	K:ring("Snow", V(0, 0, 0), 28, 12.6, 0, 1.0, 12.6, { SNOW[2] }, nil, true)
	K:ring("SnowTop", V(0, 0, 0), 28, 12.2, 1.0, 0.2, 12.2, { SNOW[1] })
	-- a lumpy rounded edge: drifts all the way round, hanging a little over the disc
	for i = 0, 19 do
		local a = (i + ((i * 7) % 3) * 0.2) / 20 * math.pi * 2
		local r = 12.0 + ((i * 5) % 4) * 0.25
		local w = 3.4 + ((i * 3) % 4) * 0.5
		local h = 0.9 + ((i * 11) % 3) * 0.25
		blob(K, "SnowDrift", V(2.4, h, w), CFrame.new(math.cos(a) * r, 0.95, math.sin(a) * r) * CFrame.Angles(0, -a, 0), SNOW[i % 2 + 1])
	end
	-- drifts banked against the footing, and loose lumps
	for _, d in { { HX0 - 0.4, -3.5, 1 }, { HX0 - 0.4, 0.5, 1 }, { HX0 - 0.4, 4.5, 1 }, { HX0 - 0.4, 8.0, 1 }, { HX1 + 0.4, -3.0, 1 }, { HX1 + 0.4, 7.2, 1 }, { -3.5, HZ1 + 0.4, 0 }, { 0.5, HZ1 + 0.4, 0 }, { 3.5, HZ1 + 0.4, 0 }, { 5.7, -9.0, 0 }, { -5.3, -9.0, 0 } } do
		blob(K, "SnowDrift", if d[3] == 1 then V(1.8, 1.5, 3.2) else V(3.2, 1.5, 1.8), CFrame.new(d[1], 1.35, d[2]), SNOW[1])
	end
	for i, l in { { -7.0, -9.8, 1.6 }, { 9.0, -9.4, 1.4 }, { -11.0, 5.0, 1.3 }, { 3.6, 11.0, 1.5 }, { -3.4, -11.2, 1.0 }, { 4.8, -11.0, 1.1 }, { -6.4, 10.4, 1.2 } } do
		blob(K, "SnowLump", V(l[3] * 1.6, l[3] * 0.7, l[3] * 1.3), CFrame.new(l[1], 1.2, l[2]) * CFrame.Angles(0, i, 0), SNOW[i % 2 + 1])
	end
end

local function walls(K: Kit)
	stoneBlock(K, HX0 - 0.25, HZ0 - 0.25, HX1 + 0.25, HZ1 + 0.25, 1.0, FOOT - 0.25)
	K:box("FootingCap", HX0 - 0.35, FOOT - 0.25, HZ0 - 0.35, HX1 + 0.35, FOOT, HZ1 + 0.35, STONE[2], true)
	K:box("Walls", HX0, FOOT, HZ0, HX1, 12.0, HZ1, PLASTER)
	-- the front under the tie beam is dark boards (the porch's back wall)
	local nb = 14
	local bw = (HX1 - HX0) / nb
	for i = 0, nb - 1 do
		local x = HX0 + i * bw
		K:box("FrontBoards", x + 0.02, FOOT, HZ0 - 0.04 - (i % 2) * 0.04, x + bw - 0.02, 10.7, HZ0 + 0.3, if i % 2 == 0 then TIMBER[2] else C(74, 46, 28))
	end
	-- timbers: corner and mid posts down both long sides, a sill and a plate
	for _, x in { HX0, HX1 } do
		for _, z in { HZ0, -1.2, 3.4, HZ1 } do
			K:box("Post", x - 0.25, FOOT, z - 0.25, x + 0.25, 11.5, z + 0.25, TIMBER[1])
		end
		K:box("Sill", x - 0.22, FOOT, HZ0, x + 0.22, FOOT + 0.35, HZ1, TIMBER[2])
		K:box("Plate", x - 0.22, 8.4, HZ0, x + 0.22, 8.8, HZ1, TIMBER[2])
	end
	-- warm arched windows down both sides
	for _, side in { -1, 1 } do
		local x = if side < 0 then HX0 else HX1
		for _, z in { 1.1, 6.0 } do
			local f = CFrame.lookAt(V(x, 5.6, z), V(x + side, 5.6, z))
			K:glow("Window", V(1.2, 2.0, 0.12), f * CFrame.new(0, 0, -0.04), WARM, nil, true)
			K:rod("WindowArch", 1.2, 0.12, f * CFrame.new(0, 1.0, -0.04) * CFrame.Angles(0, math.pi / 2, 0), WARM).Material = Enum.Material.SmoothPlastic
			for _, e in { -1, 1 } do
				K:brick("WindowFrame", V(0.22, 2.5, 0.22), f * CFrame.new(e * 0.71, 0.15, -0.1), TIMBER[2], true)
			end
			K:brick("WindowSill", V(1.7, 0.22, 0.35), f * CFrame.new(0, -1.1, -0.15), TIMBER[2], true)
			K:brick("WindowBar", V(0.1, 2.4, 0.12), f * CFrame.new(0, 0.2, -0.1), TIMBER[2], true)
			K:brick("WindowBar", V(1.2, 0.1, 0.12), f * CFrame.new(0, 0.15, -0.1), TIMBER[2], true)
			K:brick("Lintel", V(1.9, 0.3, 0.3), f * CFrame.new(0, 1.78, -0.12), TIMBER[1], true)
			blob(K, "SillSnow", V(1.7, 0.36, 0.5), f * CFrame.new(0, -0.92, -0.22), SNOW[1])
		end
		-- an X brace in the windowless panel at the front
		local out = V(side, 0, 0)
		local p0, p1 = V(x, FOOT + 0.4, HZ0 + 0.3) + out * 0.1, V(x, 8.4, -1.5) + out * 0.1
		K:beam("Brace", p0, p1, 0.3, 0.2, TIMBER[2], out, true)
		K:beam("Brace", V(x, FOOT + 0.4, -1.5) + out * 0.12, V(x, 8.4, HZ0 + 0.3) + out * 0.12, 0.3, 0.2, TIMBER[2], out, true)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the roof: slate, snow (bare in a patch), lips, icicles
-------------------------------------------------------------------------------------------------------------
local SNOW_T, TILE_T = 0.9, 0.35

-- One snowy roof slope: the snow's outer line runs from the eave (rx + s * span, eave) up to (rx, apex), from z0 to
-- z1; slate under the snow (bare where `bare(row, seg)` says), a rounded lip along the eave and icicles under it
local function snowSlope(K: Kit, rx: number, s: number, span: number, eave: number, apex: number, z0: number, z1: number, snowT: number, tileT: number, rows: number, segs: number, bare: (number, number) -> boolean, lipD: number)
	local rise, run = apex - eave, span
	local L = math.sqrt(rise * rise + run * run)
	local u = V(-s * run, rise, 0).Unit
	local n = u:Cross(Z)
	if n.Y < 0 then
		n = -n
	end
	local r = Z
	if r:Cross(n):Dot(u) < 0 then
		r = -r
	end
	local outer = V(rx + s * span, eave, 0)
	local slate = outer - n * (snowT + tileT)
	local zc = (z0 + z1) / 2
	K:slope(slate + Z * zc, Z, -s * X, rise, run, z0 - zc, z1 - zc, SLATE[1], SLATE[2], nil, tileT)
	local step = L / rows
	local sl = (z1 - z0) / segs
	local base = outer - n * snowT
	for k = 0, rows - 1 do
		for j = 0, segs - 1 do
			if not bare(k, j) then
				local zm = z0 + (j + 0.5) * sl
				local pos = base + Z * zm + u * ((k + 0.5) * step) + n * (snowT / 2)
				local bump = ((k * 3 + j * 5) % 4) * 0.05
				K:brick("RoofSnow", V(sl + 0.05, snowT + bump, step + 0.05), CFrame.fromMatrix(pos, r, n, u), SNOW[1], true)
			end
		end
	end
	local e = outer - n * (lipD * 0.3)
	lip(K, e + Z * z0, e + Z * z1, lipD)
	-- the snow drooping over the eave in lumps, icicles under them, long and short
	local z = z0 + 0.15
	local k = 0
	while z < z1 - 0.3 do
		local w = math.min(0.8 + ((k * 5) % 3) * 0.3, z1 - z)
		local at = e + Z * (z + w / 2)
		blob(K, "SnowDroop", V(lipD * 0.85, lipD * (0.7 + (k % 3) * 0.12), w + 0.3), CFrame.new(at - V(0, lipD * 0.3, 0)), SNOW[1])
		local len = (0.45 + ((k * 7) % 6) * 0.28) * lipD * (if k % 4 == 1 then 1.5 else 1)
		icicle(K, at - V(0, lipD * 0.62, 0), len, k)
		if k % 2 == 0 then
			icicle(K, e + Z * (z + 0.1) - V(0, lipD * 0.55, 0), len * 0.55, k + 3)
		end
		z += w
		k += 1
	end
end

local function roofSide(K: Kit, s: number)
	snowSlope(K, RX, s, SPAN, EAVE, APEX, RZ0, RZ1, SNOW_T, TILE_T, 8, 8, function(k: number, j: number): boolean
		local patch = k >= 2 and k <= 5 and j >= 2 and j <= 5 and not ((k == 2 or k == 5) and (j == 2 or j == 5))
		-- (the -X side's patch reaches up under the ridge, as on the mesh)
		return patch or (s < 0 and k == 6 and j >= 1 and j <= 3)
	end, 1.15)
end

local function roof(K: Kit)
	roofSide(K, 1)
	roofSide(K, -1)
	-- lips up the gable edges, front and back, and along the ridge
	for _, z in { RZ0, RZ1 } do
		for _, s in { -1, 1 } do
			lip(K, V(RX + s * (SPAN - 0.2), EAVE - 0.2, z), V(RX, APEX - 0.35, z), 1.1)
		end
	end
	lip(K, V(RX, APEX - 0.35, RZ0), V(RX, APEX - 0.35, RZ1), 1.2)
	-- the bargeboards: a dark timber band just under the slate along each gable edge
	local rise = APEX - EAVE
	local L = math.sqrt(rise * rise + SPAN * SPAN)
	local off = SNOW_T + TILE_T + 0.42
	for _, z in { RZ0 + 0.22, RZ1 - 0.22 } do
		for _, s in { -1, 1 } do
			local nx, ny = s * rise / L, SPAN / L
			local a = V(RX + s * SPAN - nx * off + s * 0.3, EAVE - ny * off - 0.3 * rise / SPAN, z)
			local t = 1 - (rise / L * off) / SPAN
			local b = V(RX + s * SPAN * (1 - t) - nx * off, EAVE + rise * t - ny * off, z)
			K:beam("Barge", a, b, 0.85, 0.45, TIMBER[1], Z, true)
		end
	end
	-- lumps of snow drooping off the front gable's edges
	for _, s in { -1, 1 } do
		for i = 1, 6 do
			local f = i / 7
			local p = V(RX + s * (SPAN - 0.2) * (1 - f), EAVE - 0.2 + (APEX - 0.15 - EAVE) * f, RZ0 - 0.1)
			blob(K, "SnowDroop", V(1.05, 0.8, 0.9), CFrame.new(p - V(0, 0.45, 0)), SNOW[(i % 2) + 1])
		end
	end
	-- a few icicles off the front gable's lips
	for i, f in { 0.25, 0.4, 0.58, 0.75 } do
		for _, s in { -1, 1 } do
			local p = V(RX + s * (SPAN - 0.2) * (1 - f), EAVE - 0.2 + (APEX - EAVE) * f, RZ0)
			icicle(K, p - V(0, 0.6, 0), 0.6 + (i % 2) * 0.4, i)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the front gable
-------------------------------------------------------------------------------------------------------------
local function diamond(K: Kit, at: Vector3, size: number)
	local cf = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 4)
	K:brick("GemFrame", V(size, size, 0.2), cf, TIMBER[1], true)
	K:brick("GemFrame", V(size * 0.62, size * 0.62, 0.24), cf * CFrame.new(0, 0, -0.04), PLASTER, true)
	local g = K:brick("Gem", V(size * 0.42, size * 0.42, 0.3), cf * CFrame.new(0, 0, -0.08), GEM, true)
	g.Material = Enum.Material.Neon
	g.Color = C(40, 110, 220)
	local l = Instance.new("PointLight")
	l.Color = C(80, 160, 255)
	l.Range = 5
	l.Brightness = 0.8
	l.Parent = g
end

local function frontGable(K: Kit)
	local z = HZ0 - 0.05
	-- the plaster triangle above the walls, up under the roof
	-- (the slate's underside: 2.25 under the snow's line)
	local slope = (APEX - EAVE) / SPAN
	local underTop = APEX - 2.25
	local half = (underTop - 11.9) / slope
	K:tri("GablePlaster", V(RX - half, 11.9, z), V(RX + half, 11.9, z), V(RX, underTop - 0.05, z), PLASTER, V(RX, 14, z + 1), 0.3)
	K:tri("GablePlaster", V(RX - half, 11.9, HZ1 + 0.05), V(RX + half, 11.9, HZ1 + 0.05), V(RX, underTop - 0.05, HZ1 + 0.05), PLASTER, V(RX, 14, HZ1 - 1), 0.3)
	-- the tie beam, two posts up from it, braces
	K:box("TieBeam", HX0 - 0.5, 10.7, z - 0.35, HX1 + 0.6, 11.2, z, TIMBER[1])
	for _, x in { 2.7, -3.15 } do
		local top = underTop - 0.1 - math.abs(x - RX) * slope
		K:box("GablePost", x - 0.25, 11.2, z - 0.3, x + 0.25, top, z, TIMBER[2])
	end
	K:beam("Brace", V(2.45, 13.0, z - 0.15), V(1.1, 11.2, z - 0.15), 0.3, 0.25, TIMBER[2], Z, true)
	K:beam("Brace", V(-2.9, 13.0, z - 0.15), V(-1.6, 11.2, z - 0.15), 0.3, 0.25, TIMBER[2], Z, true)
	-- the tall pointed window, warm, with its tracery
	local wz = z - 0.12
	local bw = K:glow("BigWindow", V(1.95, 1.75, 0.12), CFrame.new(RX, 12.15, wz), WARM, 7, true)
	;(bw:FindFirstChildOfClass("PointLight") :: PointLight).Brightness = 0.6
	K:tri("BigWindow", V(RX - 0.975, 13.02, wz), V(RX + 0.975, 13.02, wz), V(RX, 13.95, wz), WARM, V(RX, 13.2, wz + 1), 0.12)
	for _, e in { -1, 1 } do
		K:box("WindowFrame", RX + e * 1.1 - 0.15, 11.2, wz - 0.12, RX + e * 1.1 + 0.15, 13.05, wz, TIMBER[2], true)
		K:beam("WindowFrame", V(RX + e * 1.1, 13.0, wz - 0.06), V(RX, 14.1, wz - 0.06), 0.3, 0.15, TIMBER[2], Z, true)
		K:beam("Tracery", V(RX, 12.6, wz - 0.08), V(RX + e * 0.75, 13.3, wz - 0.08), 0.12, 0.1, TIMBER[2], Z, true)
	end
	K:box("Tracery", RX - 0.06, 11.25, wz - 0.12, RX + 0.06, 12.6, wz - 0.02, TIMBER[2], true)
	K:box("WindowSill", RX - 1.4, 11.15, wz - 0.4, RX + 1.4, 11.4, wz, TIMBER[1], true)
	blob(K, "SillSnow", V(2.6, 0.36, 0.55), CFrame.new(RX, 11.48, wz - 0.22), SNOW[1])
	-- the gems: one in a timber diamond over the window, one at the apex
	diamond(K, V(RX, 15.0, z - 0.2), 1.25)
	diamond(K, V(RX, 18.2, z - 0.2), 1.5)
end

-------------------------------------------------------------------------------------------------------------
-- the porch
-------------------------------------------------------------------------------------------------------------
local PZ0, PZ1 = -9.4, HZ0 -- the porch's front and back
local PRX, PEAVE, PAPEX, PSPAN = 1.0, 7.6, 10.5, 3.6 -- (the porch roof's snow line)

local function porch(K: Kit)
	stoneBlock(K, 3.0, PZ0 - 0.2, 5.4, PZ1, 1.0, FOOT - 0.3)
	stoneBlock(K, -4.9, PZ0 - 0.2, -0.8, PZ1, 1.0, FOOT - 0.3)
	K:box("PorchFloor", -4.9, FOOT - 0.3, PZ0, 5.4, FOOT, PZ1, STEP[1])
	-- steps
	for k = 0, 3 do
		K:box("Step", -0.6, 1.2, -11.0 + k * 0.42, 2.9, 1.7 + k * 0.5, PZ0, STEP[k % 2 + 1])
		-- snow drifted into the ends of each step
		for _, x in { -0.45, 2.75 } do
			blob(K, "StepSnow", V(0.7, 0.4, 0.55), CFrame.new(x, 1.72 + k * 0.5, -10.8 + k * 0.42), SNOW[(k % 2) + 1])
		end
	end
	blob(K, "SnowDrift", V(1.4, 0.9, 1.6), CFrame.new(-0.85, 1.4, -10.7), SNOW[1])
	-- posts
	for _, x in { 4.3, -1.2, -4.6 } do
		K:box("PorchPost", x - 0.28, FOOT, PZ0 + 0.1, x + 0.28, PEAVE + 0.1, PZ0 + 0.66, TIMBER[1])
	end
	-- railings with snow on their posts
	for _, run in { { 4.3, 3.0 }, { -1.2, -4.6 } } do
		local x0, x1 = math.min(run[1], run[2]), math.max(run[1], run[2])
		K:box("Rail", x0, 4.1, PZ0 + 0.25, x1, 4.35, PZ0 + 0.5, TIMBER[2], true)
		K:box("RailSnow", x0, 4.35, PZ0 + 0.22, x1, 4.47, PZ0 + 0.53, SNOW[1], true)
		local x = x0 + 0.55
		while x < x1 - 0.4 do
			K:box("Baluster", x - 0.08, FOOT, PZ0 + 0.3, x + 0.08, 4.1, PZ0 + 0.45, TIMBER[1], true)
			x += 0.45
		end
		for _, px in run do
			K:box("RailPost", px - 0.3, FOOT, PZ0 + 0.08, px + 0.3, 4.4, PZ0 + 0.68, TIMBER[2])
			blob(K, "PostSnow", V(0.95, 0.6, 0.95), CFrame.new(px, 4.55, PZ0 + 0.38), SNOW[1])
		end
	end
	-- knee braces from the posts up to the beams, the lean-to's front beam
	local zp = PZ0 + 0.38
	for _, b in { { 4.0, 3.2, 6.9 }, { -0.95, 0.0, 6.9 }, { -1.45, -2.3, 7.3 }, { -4.35, -3.5, 7.55 } } do
		K:beam("KneeBrace", V(b[1], b[3] - 0.95, zp), V(b[2], b[3], zp), 0.24, 0.24, TIMBER[2], Z, true)
	end
	K:box("LeanToBeam", -4.95, 7.5, PZ0 + 0.1, -2.3, 7.9, PZ0 + 0.66, TIMBER[1])
	-- the door and the window in the front wall
	local z = HZ0 - 0.06
	K:box("Door", -0.9, FOOT, z - 0.15, 1.6, 6.9, z, TIMBER[2])
	for _, x in { -0.3, 0.35, 1.0 } do
		K:box("DoorPlank", x - 0.03, FOOT + 0.1, z - 0.2, x + 0.03, 6.9 + math.sqrt(1.25 * 1.25 - (x - 0.35) ^ 2) - 0.12, z - 0.15, C(60, 38, 22), true)
	end
	-- the door's arched top, its frame round the arch, iron straps
	K:rod("DoorArch", 2.5, 0.15, CFrame.new(0.35, 6.9, z - 0.075) * CFrame.Angles(0, math.pi / 2, 0), TIMBER[2])
	for _, x in { -1.15, 1.6 } do
		K:box("DoorFrame", x, FOOT, z - 0.32, x + 0.25, 6.9, z - 0.1, TIMBER[1], true)
	end
	for i = 0, 5 do
		local a0, a1 = i / 6 * math.pi, (i + 1) / 6 * math.pi
		K:beam("DoorFrame", V(0.35 + math.cos(a0) * 1.38, 6.9 + math.sin(a0) * 1.38, z - 0.2), V(0.35 + math.cos(a1) * 1.38, 6.9 + math.sin(a1) * 1.38, z - 0.2), 0.28, 0.22, TIMBER[1], Z, true)
	end
	for _, y in { 4.1, 6.2 } do
		K:box("DoorStrap", -0.9, y - 0.09, z - 0.24, 0.3, y + 0.09, z - 0.17, DARK, true)
	end
	K:ball("DoorKnob", 0.22, V(1.2, 4.9, z - 0.3), C(190, 150, 70))
	K:glow("PorchWindow", V(2.4, 2.2, 0.1), CFrame.new(-3.1, 5.25, z - 0.05), WARM, nil, true)
	K:box("PorchWindowFrame", -4.4, 4.0, z - 0.25, -1.8, 4.2, z, TIMBER[1], true)
	K:box("PorchWindowFrame", -4.4, 6.35, z - 0.25, -1.8, 6.55, z, TIMBER[1], true)
	K:box("PorchWindowFrame", -3.2, 4.1, z - 0.2, -3.0, 6.45, z, TIMBER[1], true)
	-- the lantern hanging off a bracket on the left post
	local lp = V(4.3, 5.95, PZ0 - 0.6)
	K:box("LanternArm", 4.22, 6.9, PZ0 - 0.75, 4.38, 7.05, PZ0 + 0.2, DARK, true)
	K:cyl("LanternHook", 0.06, 0.45, lp + V(0, 0.75, 0), DARK)
	K:cone("LanternRoof", lp + V(0, 0.47, 0), 0.45, 0.32, 4, { DARK }, 0.08)
	K:box("LanternTop", lp.X - 0.36, lp.Y + 0.35, lp.Z - 0.36, lp.X + 0.36, lp.Y + 0.47, lp.Z + 0.36, DARK, true)
	K:glow("Lantern", V(0.5, 0.75, 0.5), CFrame.new(lp), WARM, 9, true)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K:box("LanternPost", lp.X + sx * 0.3 - 0.05, lp.Y - 0.4, lp.Z + sz * 0.3 - 0.05, lp.X + sx * 0.3 + 0.05, lp.Y + 0.35, lp.Z + sz * 0.3 + 0.05, DARK, true)
		end
	end
	K:box("LanternBase", lp.X - 0.34, lp.Y - 0.52, lp.Z - 0.34, lp.X + 0.34, lp.Y - 0.4, lp.Z + 0.34, DARK, true)
end

local function porchRoof(K: Kit)
	local zl, zh = PZ0 - 0.3, PZ1 + 0.2
	local snowT, tileT = 0.5, 0.3
	for _, s in { -1, 1 } do
		snowSlope(K, PRX, s, PSPAN, PEAVE, PAPEX, zl, zh, snowT, tileT, 4, 6, function(k: number, j: number): boolean
			-- (slate shows in a patch high on the -X side, as on the mesh)
			return s < 0 and k >= 2 and j >= 1 and j <= 3
		end, 0.75)
		lip(K, V(PRX + s * PSPAN, PEAVE - 0.1, zl), V(PRX, PAPEX - 0.25, zl), 0.75)
	end
	lip(K, V(PRX, PAPEX - 0.25, zl), V(PRX, PAPEX - 0.25, zh), 0.8)
	-- the gable face: plaster under the slate, a tie beam, a timber X, a gem
	local rise = PAPEX - PEAVE
	local L = math.sqrt(rise * rise + PSPAN * PSPAN)
	local drop = (snowT + tileT) * L / PSPAN
	local top = PAPEX - drop - 0.05
	local half = (top - PEAVE + 0.4) * PSPAN / rise
	local fz = zl + 0.2
	K:tri("PorchGable", V(PRX - half, PEAVE - 0.4, fz), V(PRX + half, PEAVE - 0.4, fz), V(PRX, top, fz), PLASTER, V(PRX, 8, fz + 1), 0.25)
	K:box("PorchTie", PRX - PSPAN + 0.3, PEAVE - 0.75, fz - 0.35, PRX + PSPAN - 0.3, PEAVE - 0.3, fz, TIMBER[1])
	for _, e in { -1, 1 } do
		K:beam("PorchTruss", V(PRX + e * 1.9, PEAVE - 0.3, fz - 0.15), V(PRX - e * 0.6, top - 0.6, fz - 0.15), 0.28, 0.2, TIMBER[2], Z, true)
		local nx, ny = e * rise / L, PSPAN / L
		local off = snowT + tileT + 0.3
		K:beam("PorchBarge", V(PRX + e * PSPAN - nx * off, PEAVE - ny * off, fz - 0.05), V(PRX - nx * off * 0.2, PAPEX - ny * off - 0.3, fz - 0.05), 0.55, 0.35, TIMBER[1], Z, true)
	end
	diamond(K, V(PRX, PEAVE + 0.6, fz - 0.15), 0.8)
	-- the snowy lean-to beside it (to -X)
	-- the snowy lean-to beside it (to -X), sloping down from the wall to the front
	local lx0, lx1 = -4.95, PRX - PSPAN + 0.3
	local yf, yb = 8.0, 9.3
	local d = V(0, yb - yf, zh - zl).Unit
	local nrm = V(0, d.Z, -d.Y)
	local mid = V((lx0 + lx1) / 2, (yf + yb) / 2, (zl + zh) / 2)
	local len = (V(0, yb, zh) - V(0, yf, zl)).Magnitude
	K:brick("LeanTo", V(lx1 - lx0, 0.35, len), CFrame.fromMatrix(mid, X, nrm), TIMBER[2], true)
	K:brick("LeanToSnow", V(lx1 - lx0 + 0.2, 0.5, len), CFrame.fromMatrix(mid + nrm * 0.42, X, nrm), SNOW[1], true)
	lip(K, V(lx0 - 0.1, yf + 0.3, zl), V(lx1, yf + 0.3, zl), 0.75)
	for i = 0, 4 do
		local x = lx0 + 0.25 + i * 0.58
		blob(K, "SnowDroop", V(0.75, 0.6, 0.7), CFrame.new(x, yf + 0.05, zl - 0.05), SNOW[1])
		icicle(K, V(x, yf - 0.15, zl), 0.45 + (i % 3) * 0.3, i)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the chimney, the crystals, the pillar, the skis, the pines
-------------------------------------------------------------------------------------------------------------
local function chimney(K: Kit)
	local c = V(1.8, 0, 1.8)
	K:box("ChimneyCore", c.X - 1.15, 12.0, c.Z - 1.2, c.X + 1.15, 15.0, c.Z + 1.2, STONE[2], true)
	stoneBlock(K, c.X - 1.2, c.Z - 1.25, c.X + 1.2, c.Z + 1.25, 15.0, 20.4)
	K:box("ChimneyBand", c.X - 1.4, 20.4, c.Z - 1.45, c.X + 1.4, 21.0, c.Z + 1.45, TIMBER[1])
	K:box("ChimneySnow", c.X - 1.5, 21.0, c.Z - 1.55, c.X + 1.5, 21.3, c.Z + 1.55, SNOW[2], true)
	blob(K, "ChimneySnow", V(3.3, 0.8, 3.4), CFrame.new(c + V(0, 21.35, 0)), SNOW[1])
	K:box("ChimneyPot", c.X - 0.75, 21.4, c.Z - 0.75, c.X + 0.75, 22.6, c.Z + 0.75, DARK)
	local hole = K:box("ChimneyHole", c.X - 0.45, 22.3, c.Z - 0.45, c.X + 0.45, 22.65, c.Z + 0.45, C(16, 16, 20), true)
	-- a thin curl of smoke
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ChimneySmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(C(222, 226, 234), C(184, 190, 202))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
	smoke.Lifetime = NumberRange.new(4, 6)
	smoke.Rate = 2.5
	smoke.Speed = NumberRange.new(1.2, 2)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = Vector3.new(0.5, 0.15, 0.2)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = hole
end

local function crystal(K: Kit, base: Vector3, h: number, r: number, lean: Vector3)
	local up = (Y * h + lean).Unit
	local top = base + up * h
	local n = 6
	local shaft = base:Lerp(top, 0.72)
	local side = up:Cross(X).Unit
	local fwd = up:Cross(side).Unit
	local function ring(c: Vector3, rr: number, i: number): Vector3
		local a = i / n * math.pi * 2
		return c + (side * math.cos(a) + fwd * math.sin(a)) * rr
	end
	for i = 0, n - 1 do
		local name = if i % 2 == 0 then "Crystal" else "CrystalHi"
		K:quad(name, ring(base, r, i), ring(base, r, i + 1), ring(shaft, r * 0.8, i + 1), ring(shaft, r * 0.8, i), ICE, base:Lerp(top, 0.4), 0.2)
		K:tri(name, ring(shaft, r * 0.8, i), ring(shaft, r * 0.8, i + 1), top, ICE, base:Lerp(top, 0.6), 0.2)
	end
end

local function crystals(K: Kit)
	for _, c in {
		{ 5.8, 2.0, 3.5, 22.3, 1.45, -0.4, 0.2 },
		{ 7.6, 0.9, 4.0, 16.0, 1.05, 0.9, -0.5 },
		{ 8.9, 3.0, 3.0, 12.0, 0.95, 1.2, 0.4 },
		{ 4.2, 3.4, 6.0, 12.0, 0.85, -0.8, 0.3 },
		{ 6.6, 4.7, 3.0, 10.5, 0.95, 0.4, 1.2 },
		{ 8.4, 5.6, 2.0, 7.0, 0.8, 0.9, 0.8 },
		{ 5.6, -0.6, 4.0, 8.5, 0.75, 0.2, -1.0 },
		{ 9.6, 1.4, 2.0, 6.0, 0.7, 1.0, 0.0 },
		{ 4.8, 5.6, 3.0, 9.0, 1.0, -0.6, 1.0 },
		{ 7.2, 3.0, 3.0, 13.5, 1.2, 0.5, 0.2 },
		{ 9.8, 4.2, 2.0, 8.5, 0.9, 1.1, 0.6 },
		{ 6.8, -1.6, 3.0, 6.5, 0.8, 0.5, -1.1 },
	} do
		crystal(K, V(c[1], c[3], c[2]), c[4], c[5] * 1.45, V(c[6], 0, c[7]))
	end
	-- small shards round its foot, a drift, a cold light inside the cluster
	for _, sh in { { 4.6, -1.5, 2.2, 0.45, -0.6, -0.8 }, { 9.9, -0.8, 2.6, 0.5, 0.9, -0.5 }, { 10.6, 3.3, 1.8, 0.4, 1.0, 0.3 }, { 5.2, 6.8, 2.4, 0.5, -0.4, 0.9 }, { 8.9, 6.6, 1.6, 0.4, 0.7, 0.8 } } do
		crystal(K, V(sh[1], 1.1, sh[2]), sh[3], sh[4], V(sh[5], 0, sh[6]))
	end
	blob(K, "SnowDrift", V(5.5, 1.6, 7.5), CFrame.new(7.3, 1.5, 2.4), SNOW[1])
	local core = K:brick("CrystalLight", V(0.4, 0.4, 0.4), CFrame.new(7.0, 6.0, 2.0), ICE, true)
	core.Transparency = 1
	core.CanCollide = false
	core.CanQuery = false
	core.CastShadow = false
	local glow = Instance.new("PointLight")
	glow.Color = C(110, 200, 255)
	glow.Range = 16
	glow.Brightness = 1.4
	glow.Parent = core
	-- the pillar with a gem facing out
	local p = V(9.1, 0, 0.2)
	K:box("Pillar", p.X - 0.95, 1.2, p.Z - 0.95, p.X + 0.95, 7.7, p.Z + 0.95, STONE[2])
	K:box("PillarBase", p.X - 1.2, 1.2, p.Z - 1.2, p.X + 1.2, 2.2, p.Z + 1.2, STONE[1])
	K:cyl("PillarSnow", 2.3, 0.45, p + V(0, 7.9, 0), SNOW[1])
	K:ball("PillarSnow", 1.6, p + V(0, 8.15, 0), SNOW[2])
	local g = CFrame.lookAt(V(p.X + 0.98, 5.4, p.Z), V(p.X + 2, 5.4, p.Z)) * CFrame.Angles(0, 0, math.pi / 4)
	K:brick("GemFrame", V(1.3, 1.3, 0.2), g, DARK, true)
	local gem = K:brick("Gem", V(0.85, 0.85, 0.3), g * CFrame.new(0, 0, -0.06), GEM, true)
	gem.Material = Enum.Material.Neon
	gem.Color = C(40, 110, 220)
	blob(K, "SnowDrift", V(3.0, 0.9, 3.0), CFrame.new(p.X, 1.5, p.Z), SNOW[1])
end

local function skis(K: Kit)
	for i, x in { 7.0, 8.3 } do
		local base = V(x, 1.2, -7.6 + i * 0.15)
		local cf = CFrame.new(base) * CFrame.Angles(math.rad(-9), math.rad(6 - i * 10), 0)
		K:brick("Ski", V(0.68, 5.8, 0.12), cf * CFrame.new(0, 2.9, 0), SKI, true)
		K:wedge("SkiTip", V(0.68, 0.6, 0.35), cf * CFrame.new(0, 6.05, -0.12) * CFrame.Angles(0, math.pi, 0), SKI, true)
		K:brick("SkiEdge", V(0.8, 5.8, 0.08), cf * CFrame.new(0, 2.9, 0.08), DARK, true)
		for _, y in { 1.6, 3.4, 5.0 } do
			K:brick("SkiMark", V(0.28, 0.28, 0.05), cf * CFrame.new(0, y, -0.08) * CFrame.Angles(0, 0, math.pi / 4), SNOW[1], true)
		end
		K:brick("Binding", V(0.62, 0.5, 0.3), cf * CFrame.new(0, 2.6, -0.18), DARK, true)
	end
	-- the poles beside them, a drift at their foot
	for i, x in { 6.2, 9.1 } do
		local base = V(x, 1.2, -7.3)
		local top = base + V(if i == 1 then 0.35 else -0.35, 4.6, 0.6)
		K:beam("SkiPole", base, top, 0.12, 0.12, DARK, X, true)
		K:cyl("PoleBasket", 0.45, 0.06, base + (top - base).Unit * 0.75, C(60, 70, 96))
		K:ball("PoleGrip", 0.3, top, SKI)
	end
	blob(K, "SnowDrift", V(4.2, 0.9, 1.8), CFrame.new(7.6, 1.3, -7.4), SNOW[1])
end

local function snowyPine(K: Kit, at: Vector3, h: number)
	K:cyl("PineTrunk", 0.55, h * 0.25, at + V(0, 1.2 + h * 0.125, 0), BARK)
	local tiers = math.max(3, math.floor(h / 1.7))
	for t = 0, tiers - 1 do
		local f = t / tiers
		local y = 1.2 + h * 0.16 + f * h * 0.72
		local r = (1 - f * 0.8) * h * 0.25
		K:cone("Pine", at + V(0, y, 0), r, h * 0.2, 8, PINE, 0.2)
		K:cone("PineSnow", at + V(0, y + h * 0.07, 0), r * 0.8, h * 0.14, 8, SNOW, 0.15)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2 + t * 0.7
			local tip = at + V(math.cos(a) * r * 0.8, y + h * 0.02, math.sin(a) * r * 0.8)
			blob(K, "PineSnow", V(r * 0.55, h * 0.028, r * 0.32), CFrame.new(tip) * CFrame.Angles(0, -a, 0), SNOW[1])
		end
	end
	K:cone("PineTop", at + V(0, 1.2 + h * 0.85, 0), h * 0.06, h * 0.15, 6, SNOW, 0.12)
end

local function pines(K: Kit)
	for _, p in { { 10.3, 5.4, 8.6 }, { -8.9, -2.6, 11.8 }, { -10.6, 1.8, 7.3 }, { -8.4, 3.0, 6.4 }, { -9.4, -7.4, 5.0 } } do
		snowyPine(K, V(p[1], 0, p[2]), p[3])
	end
end

-- the ice: bright faceted blue, a little shine; the icicles glassy
local function iceFinish(K: Kit)
	for _, p in K.model:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Crystal" or p.Name == "CrystalHi") then
			-- (ice keeps its own bright colour, not shaded by the tone)
			p.Material = Enum.Material.SmoothPlastic
			p.Color = if p.Name == "CrystalHi" then ICE_HI else ICE
			p.Reflectance = 0.15
		elseif p:IsA("BasePart") and p.Name == "Icicle" then
			p.Material = Enum.Material.Glass
			p.Transparency = 0.1
		end
	end
end

-- a light snowfall over the isle
local function snowfall(K: Kit)
	local sky = K:brick("SnowfallSky", V(24, 0.2, 24), CFrame.new(0, 27, 1), SNOW[1], true)
	sky.Transparency = 1
	sky.CanCollide = false
	sky.CanQuery = false
	sky.CanTouch = false
	sky.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Snowfall"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission = 0.3
	e.Size = NumberSequence.new(0.2, 0.12)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(9, 12)
	e.Rate = 9
	e.Speed = NumberRange.new(1.8, 2.6)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0.25, 0, 0.1)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = sky
end

function StudFrost.build(K: Kit)
	ground(K)
	walls(K)
	roof(K)
	frontGable(K)
	porch(K)
	porchRoof(K)
	chimney(K)
	crystals(K)
	skis(K)
	pines(K)
	snowfall(K)
	iceFinish(K)
end

return StudFrost
