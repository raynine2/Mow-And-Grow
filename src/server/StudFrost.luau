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
--   two skis leaning by the porch; snowy pines round about
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

-------------------------------------------------------------------------------------------------------------
-- the ground, the footing, the walls
-------------------------------------------------------------------------------------------------------------
local function ground(K: Kit)
	K:ring("Snow", V(0, 0, 0), 28, 12.6, 0, 1.0, 12.6, { SNOW[2] }, nil, true)
	K:ring("SnowTop", V(0, 0, 0), 28, 12.2, 1.0, 0.2, 12.2, { SNOW[1] })
end

local function walls(K: Kit)
	K:box("Footing", HX0 - 0.25, 1.2, HZ0 - 0.25, HX1 + 0.25, FOOT, HZ1 + 0.25, STONE[1])
	K:box("FootingCap", HX0 - 0.35, FOOT - 0.25, HZ0 - 0.35, HX1 + 0.35, FOOT, HZ1 + 0.35, STONE[2], true)
	K:box("Walls", HX0, FOOT, HZ0, HX1, 12.0, HZ1, PLASTER)
	-- the front under the tie beam is dark boards (the porch's back wall)
	K:box("FrontBoards", HX0, FOOT, HZ0 - 0.04, HX1, 10.7, HZ0 + 0.3, TIMBER[2])
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
		end
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
	local z = z0 + 0.3
	local k = 0
	while z < z1 - 0.2 do
		local len = (0.5 + ((k * 7) % 5) * 0.32) * lipD
		icicle(K, e + Z * z - V(0, lipD * 0.4, 0) + u * 0.1, len, k)
		z += 0.55
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
	K:box("PorchFooting", 3.0, 1.2, PZ0 - 0.2, 5.4, FOOT, PZ1, STONE[1])
	K:box("PorchFooting", -4.9, 1.2, PZ0 - 0.2, -0.8, FOOT, PZ1, STONE[1])
	K:box("PorchFloor", -4.9, FOOT - 0.3, PZ0, 5.4, FOOT, PZ1, STEP[1])
	-- steps
	for k = 0, 3 do
		K:box("Step", -0.6, 1.2, -11.0 + k * 0.42, 2.9, 1.7 + k * 0.5, PZ0, STEP[k % 2 + 1])
		K:box("StepSnow", -0.75, 1.2, -11.0 + k * 0.42 - 0.05, -0.45, 1.85 + k * 0.5, PZ0, SNOW[1], true)
	end
	-- posts
	for _, x in { 4.3, -1.2, -4.6 } do
		K:box("PorchPost", x - 0.28, FOOT, PZ0 + 0.1, x + 0.28, PEAVE + 0.1, PZ0 + 0.66, TIMBER[1])
	end
	-- railings with snow on their posts
	for _, run in { { 4.3, 3.0 }, { -1.2, -4.6 } } do
		K:box("Rail", math.min(run[1], run[2]), 4.1, PZ0 + 0.25, math.max(run[1], run[2]), 4.35, PZ0 + 0.5, TIMBER[2], true)
		for _, x in run do
			K:box("RailPost", x - 0.3, FOOT, PZ0 + 0.08, x + 0.3, 4.4, PZ0 + 0.68, TIMBER[2])
			K:box("PostSnow", x - 0.4, 4.4, PZ0, x + 0.4, 4.75, PZ0 + 0.76, SNOW[1], true)
		end
	end
	-- the door and the window in the front wall
	local z = HZ0 - 0.06
	K:box("Door", -0.9, FOOT, z - 0.15, 1.6, 6.9, z, TIMBER[2])
	for _, x in { -0.3, 0.35, 1.0 } do
		K:box("DoorPlank", x - 0.03, FOOT + 0.1, z - 0.2, x + 0.03, 6.8, z - 0.15, C(60, 38, 22), true)
	end
	K:box("DoorFrame", -1.15, FOOT, z - 0.3, 1.85, 7.2, z - 0.12, TIMBER[1], true)
	K:ball("DoorKnob", 0.2, V(1.25, 4.9, z - 0.3), DARK)
	K:glow("PorchWindow", V(2.4, 2.2, 0.1), CFrame.new(-3.1, 5.25, z - 0.05), WARM, nil, true)
	K:box("PorchWindowFrame", -4.4, 4.0, z - 0.25, -1.8, 4.2, z, TIMBER[1], true)
	K:box("PorchWindowFrame", -4.4, 6.35, z - 0.25, -1.8, 6.55, z, TIMBER[1], true)
	K:box("PorchWindowFrame", -3.2, 4.1, z - 0.2, -3.0, 6.45, z, TIMBER[1], true)
	-- the wall lantern on the left post
	local lp = V(4.3, 5.9, PZ0 - 0.25)
	K:box("LanternTop", lp.X - 0.32, lp.Y + 0.4, lp.Z - 0.32, lp.X + 0.32, lp.Y + 0.55, lp.Z + 0.32, DARK, true)
	K:glow("Lantern", V(0.45, 0.7, 0.45), CFrame.new(lp), WARM, 9, true)
	K:box("LanternBase", lp.X - 0.28, lp.Y - 0.5, lp.Z - 0.28, lp.X + 0.28, lp.Y - 0.35, lp.Z + 0.28, DARK, true)
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
	local lx0, lx1 = -4.95, PRX - PSPAN + 0.3
	K:box("LeanTo", lx0, 7.9, zl, lx1, 8.3, zh, TIMBER[2], true)
	K:box("LeanToSnow", lx0 - 0.1, 8.3, zl - 0.1, lx1, 8.85, zh, SNOW[1], true)
	lip(K, V(lx0, 8.55, zl), V(lx1, 8.55, zl), 0.75)
	for i = 0, 4 do
		icicle(K, V(lx0 + 0.35 + i * 0.6, 8.2, zl), 0.45 + (i % 2) * 0.35, i)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the chimney, the crystals, the pillar, the skis, the pines
-------------------------------------------------------------------------------------------------------------
local function chimney(K: Kit)
	local c = V(1.8, 0, 1.8)
	local y = 12.0
	local k = 0
	while y < 20.4 do
		K:box("Chimney", c.X - 1.2, y, c.Z - 1.25, c.X + 1.2, math.min(y + 0.7, 20.4), c.Z + 1.25, STONE[k % 2 + 1])
		y += 0.7
		k += 1
	end
	K:box("ChimneyBand", c.X - 1.35, 20.4, c.Z - 1.4, c.X + 1.35, 21.0, c.Z + 1.4, TIMBER[1])
	K:box("ChimneySnow", c.X - 1.5, 21.0, c.Z - 1.55, c.X + 1.5, 21.5, c.Z + 1.55, SNOW[1], true)
	K:cyl("ChimneySnow", 2.0, 0.3, c + V(0, 21.6, 0), SNOW[2])
	K:box("ChimneyPot", c.X - 0.75, 21.5, c.Z - 0.75, c.X + 0.75, 22.6, c.Z + 0.75, DARK)
	K:box("ChimneyHole", c.X - 0.45, 22.3, c.Z - 0.45, c.X + 0.45, 22.65, c.Z + 0.45, C(16, 16, 20), true)
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
	iceFinish(K)
end

return StudFrost
