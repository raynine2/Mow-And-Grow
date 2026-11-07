--!strict
-- STUD HOUSE (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar ... maak het super hoog kwaliteit", then
-- of the first try "Moet meer accuraat zijn en donkerder", "Ik vind de huis niet echt mooi het is niet echt accuraat").
-- The ForgeGUI cottage (forge_house_blue: the lobby's CLASSES house; forge_house_red in the run) rebuilt from studded
-- bricks to the mesh's own shape, measured from straight-on pictures of it:
--   * an L: a tall gable wing on the left running front to back (its ridge front-back), the main block on the right
--     with its ridge left-right, both ridges at 21.4; walls to 12.2 on a stone footing to 2.6; a white belt at 9.6
--   * the roofs smooth like toy roof tiles: rows of navy shingles lying on the slopes (each row's lower edge proud),
--     the valleys where the roofs meet worked out row by row, white bargeboards up every gable edge, ridge caps
--   * a gable dormer on the main roof's front, a stone chimney behind it
--   * a porch in the middle with white columns on stone piers, its own little gable with a white truss, wooden steps
--   * the door, red with four panes; windows with blue shutters, white headers and flower boxes; the gable window
--   * roses climbing the right front corner and round onto the side, terracotta pots by the steps
-- Front to -Z. StudHouse.build(parent, pivot, look?) -> the Model (pivot: the bottom middle, LookVector = the front).
local StudHouse = {}

-- (owner: "donkerder ... het moet niet zo bright zijn", for every stud model) every colour x Config.STUD_FORGE.tone
local TONE = (function(): number
	local ok, cfg = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("MowALawn"):WaitForChild("Config")) :: any
	end)
	local t = ok and type(cfg.STUD_FORGE) == "table" and tonumber(cfg.STUD_FORGE.tone) or nil
	return math.clamp(t or 0.85, 0.4, 1)
end)()
local function toned(c: Color3): Color3
	return Color3.new(c.R * TONE, c.G * TONE, c.B * TONE)
end

local C = Color3.fromRGB

export type Look = {
	wall: Color3,
	wallShade: Color3,
	roof: Color3,
	roofDark: Color3,
	shutter: Color3,
	slat: Color3,
	door: Color3,
	doorPanel: Color3,
}

StudHouse.LOOKS = {
	blue = {
		wall = C(240, 206, 112),
		wallShade = C(228, 192, 98),
		roof = C(48, 70, 140),
		roofDark = C(38, 56, 118),
		shutter = C(52, 116, 170),
		slat = C(40, 96, 146),
		door = C(170, 36, 40),
		doorPanel = C(146, 28, 32),
	},
	red = {
		wall = C(238, 228, 208),
		wallShade = C(224, 212, 190),
		roof = C(160, 50, 42),
		roofDark = C(134, 40, 34),
		shutter = C(70, 122, 78),
		slat = C(56, 102, 64),
		door = C(56, 92, 146),
		doorPanel = C(44, 76, 124),
	},
} :: { [string]: Look }

local TRIM = C(236, 230, 214)
local GLASS = C(44, 96, 170)
local STONE = { C(142, 128, 112), C(120, 108, 96), C(156, 142, 124), C(108, 98, 88) }
local CHIMNEY = { C(136, 120, 106), C(114, 100, 88) }
local CAP = C(172, 162, 150)
local WOOD = C(150, 96, 58)
local WOOD_DARK = C(122, 76, 46)
local BRASS = C(212, 170, 76)
local LEAF = { C(66, 136, 56), C(52, 114, 46), C(80, 150, 64) }
local ROSE = { C(232, 76, 100), C(214, 54, 80), C(246, 120, 140) }
local CREAM = C(246, 238, 210)
local POT = C(188, 98, 58)
local POT_RIM = C(168, 84, 50)

local STUDS = Enum.SurfaceType.Studs
local INLET = Enum.SurfaceType.Inlet
local SMOOTH = Enum.SurfaceType.Smooth

local model: Model = nil :: any
local origin = CFrame.identity
local look: Look = StudHouse.LOOKS.blue
local count = 0

-- one brick, `cf` in the house's own space; `smooth`: no studs (roof tiles, glass)
local function brick(name: string, size: Vector3, cf: CFrame, color: Color3, smooth: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = origin * cf
	p.Color = toned(color)
	p.Material = Enum.Material.Plastic
	local s = if smooth then SMOOTH else STUDS
	p.TopSurface = s
	p.FrontSurface = s
	p.BackSurface = s
	p.LeftSurface = s
	p.RightSurface = s
	p.BottomSurface = if smooth then SMOOTH else INLET
	p.Parent = model
	count += 1
	return p
end

local function box(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, smooth: boolean?): Part
	return brick(name, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, smooth)
end

local function ball(name: string, d: number, pos: Vector3, color: Color3): Part
	local p = brick(name, Vector3.one * d, CFrame.new(pos), color, true)
	p.Shape = Enum.PartType.Ball
	return p
end

-- an attic wedge (the solid under a roof slope, its triangle ends the gables, studded): `cf` its middle, `size` as a
-- WedgePart's (X along the ridge, Y the rise, Z the run, tall at +Z)
local function wedge(name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = origin * cf
	p.Color = toned(color)
	p.Material = Enum.Material.Plastic
	p.LeftSurface = STUDS
	p.RightSurface = STUDS
	p.BackSurface = STUDS
	p.TopSurface = SMOOTH
	p.FrontSurface = SMOOTH
	p.BottomSurface = INLET
	p.Parent = model
	count += 1
	return p
end

-------------------------------------------------------------------------------------------------------------
-- the measurements (studs; the mesh is 19 wide, 23.3 tall)
-------------------------------------------------------------------------------------------------------------
local FOOT = 2.6 -- the stone footing's top
local BELT0, BELT1 = 9.6, 10.2 -- the white belt between the floors
local WALL = 12.2 -- the walls' top
local HX, HZ = 9, 6.8 -- the walls: x -HX..HX, z -HZ..HZ
local RIDGE = 21.4
local EAVE_Y = 11.8 -- the roofs' lower edges
-- the main roof: ridge along X at z 0, eaves at z +-MAIN_EAVE
local MAIN_EAVE = 7.6
local MAIN_TAN = (RIDGE - EAVE_Y) / MAIN_EAVE
local MAIN_END = -9.6 -- its right end (0.6 past the wall)
-- the wing: x WX0..HX, ridge along Z at x WC, eaves at x WC +- WING_EAVE
local WX0 = -0.8
local WC = (WX0 + HX) / 2 -- 4.1
local WING_EAVE = (HX - WX0) / 2 + 0.8
local WING_TAN = (RIDGE - EAVE_Y) / WING_EAVE
local WING_ZEND = 7.6
-- the dormer on the main roof's front
local DC, DHALF = -4.7, 2.4 -- its middle and half width
local DFACE = -6.6 -- its front
local DRIDGE = 19.2
local D_EAVE, D_RUN = 15.8, 2.9
-- the porch
local PC = 0.2 -- its middle (and the door's)
local PFRONT = -9.9
local P_EAVE, P_RUN, P_RIDGE = 8.9, 3.6, 11.6

-- the main roof's height at z, the wing's at x, the dormer's at x
local function mainY(z: number): number
	return RIDGE - math.abs(z) * MAIN_TAN
end
local function mainZ(y: number): number -- how far from its ridge the main roof is at height y
	return (RIDGE - y) / MAIN_TAN
end
local function wingX(y: number): number -- how far from the wing's ridge its roof is at height y
	return (RIDGE - y) / WING_TAN
end

-------------------------------------------------------------------------------------------------------------
-- the roofs: shingle rows on a slope
-------------------------------------------------------------------------------------------------------------
type Slope = {
	r: Vector3, -- along the ridge
	p0: Vector3, -- a point on the eave line (its r-coordinate 0)
	rise: number,
	run: number, -- the eave's horizontal distance to the ridge (signed through `inward`)
	inward: Vector3, -- horizontal, from the eave toward the ridge
	segs: (number) -> { { number } }, -- the r-intervals the row at height y covers
	ends: { number }?, -- r-coordinates where a bargeboard runs up the slope
	fascia: { number }?, -- a white fascia along the eave between these r-coordinates
	color: Color3?,
}

local ROW_T = 0.5 -- a shingle row's thickness
local TILT = math.rad(4) -- each row's lower edge lifted

local function frame(s: Slope): (Vector3, Vector3, Vector3, number)
	local L = math.sqrt(s.rise * s.rise + s.run * s.run)
	local u = (s.inward * s.run + Vector3.new(0, s.rise, 0)).Unit
	local n = u:Cross(s.r)
	if n.Y < 0 then
		n = -n
	end
	local rr = s.r
	if rr:Cross(n):Dot(u) < 0 then
		rr = -rr
	end
	return u, n, rr, L
end

local function slope(s: Slope)
	local u, n, rr, L = frame(s)
	local rows = math.max(2, math.ceil(L / 1.4))
	local step = L / rows
	local w = step + 0.35
	for k = 0, rows - 1 do
		local sd = (k + 0.5) * step
		local y = s.p0.Y + u.Y * sd
		for _, seg in s.segs(y) do
			local a, b = seg[1], seg[2]
			if b - a > 0.3 then
				local pos = s.p0 + s.r * ((a + b) / 2) + u * sd + n * (ROW_T / 2)
				local cf = CFrame.fromMatrix(pos, rr, n, u) * CFrame.new(0, 0, w / 2) * CFrame.Angles(TILT, 0, 0) * CFrame.new(0, 0, -w / 2)
				local col = s.color or (if k % 2 == 0 then look.roof else look.roofDark)
				brick("Shingles", Vector3.new(b - a, ROW_T, w), cf, col, true)
			end
		end
	end
	-- white bargeboards up the gable edges, a fascia along the eave
	for _, e in s.ends or {} do
		local pos = s.p0 + s.r * e + u * (L / 2) + n * (ROW_T + 0.05)
		brick("Barge", Vector3.new(0.35, 0.8, L + 0.5), CFrame.fromMatrix(pos, rr, n, u), TRIM, true)
	end
	if s.fascia then
		local a, b = s.fascia[1], s.fascia[2]
		local pos = s.p0 + s.r * ((a + b) / 2) + u * 0.15 + n * (ROW_T * 0.5)
		brick("Fascia", Vector3.new(b - a, 0.85, 0.35), CFrame.fromMatrix(pos, rr, n, u), TRIM, true)
	end
end

local X = Vector3.xAxis
local Z = Vector3.zAxis

local function roofs()
	-- the main roof: its rows run from the right end to the valley with the wing (plus a little, under the wing's)
	local function mainSegs(y: number): { { number } }
		return { { MAIN_END, WC - wingX(y) + 0.45 } }
	end
	slope({ r = X, p0 = Vector3.new(0, EAVE_Y, -MAIN_EAVE), rise = RIDGE - EAVE_Y, run = MAIN_EAVE, inward = Z, segs = mainSegs, ends = { MAIN_END - 0.18 }, fascia = { MAIN_END, WC - WING_EAVE } })
	slope({ r = X, p0 = Vector3.new(0, EAVE_Y, MAIN_EAVE), rise = RIDGE - EAVE_Y, run = MAIN_EAVE, inward = -Z, segs = mainSegs, ends = { MAIN_END - 0.18 }, fascia = { MAIN_END, WC - WING_EAVE } })
	-- the wing: its right slope only where the main roof isn't above it; its left slope the whole length
	slope({
		r = Z,
		p0 = Vector3.new(WC - WING_EAVE, EAVE_Y, 0),
		rise = RIDGE - EAVE_Y,
		run = WING_EAVE,
		inward = X,
		segs = function(y: number)
			local zm = mainZ(y)
			return { { -WING_ZEND, -zm + 0.45 }, { zm - 0.45, WING_ZEND } }
		end,
		ends = { -WING_ZEND - 0.18, WING_ZEND + 0.18 },
	})
	slope({
		r = Z,
		p0 = Vector3.new(WC + WING_EAVE, EAVE_Y, 0),
		rise = RIDGE - EAVE_Y,
		run = WING_EAVE,
		inward = -X,
		segs = function(_y: number)
			return { { -WING_ZEND, WING_ZEND } }
		end,
		ends = { -WING_ZEND - 0.18, WING_ZEND + 0.18 },
		fascia = { -WING_ZEND, WING_ZEND },
	})
	-- ridge caps
	box("RidgeCap", MAIN_END - 0.1, RIDGE - 0.05, -0.55, WC, RIDGE + 0.55, 0.55, look.roofDark, true)
	box("RidgeCap", WC - 0.55, RIDGE - 0.05, -WING_ZEND - 0.1, WC + 0.55, RIDGE + 0.6, WING_ZEND + 0.1, look.roofDark, true)
end

-------------------------------------------------------------------------------------------------------------
-- the solid parts: footing, walls, attics
-------------------------------------------------------------------------------------------------------------
local rng = Random.new(1107)

-- a row of stones along X (or Z) from a to b, its outer face at `out`, `t` thick, from y0 to y1
local function stones(alongX: boolean, a: number, b: number, out: number, t: number, y0: number, y1: number, offset: number)
	local p = a
	local first = true
	while p < b - 0.05 do
		local len = math.min(if first then offset else rng:NextNumber(1.6, 2.8), b - p)
		first = false
		local col = STONE[rng:NextInteger(1, #STONE)]
		if alongX then
			box("Stone", p, y0, out, p + len - 0.08, y1 - 0.06, out + t, col)
		else
			box("Stone", out, y0, p, out + t, y1 - 0.06, p + len - 0.08, col)
		end
		p += len
	end
end

local function footing()
	local fx, fz = HX + 0.3, HZ + 0.3
	for row, ys in { { 0, 1.3 }, { 1.3, FOOT } } do
		local off = if row == 1 then 1.4 else 2.3
		stones(true, -fx, fx, -fz, 1.2, ys[1], ys[2], off)
		stones(true, -fx, fx, fz - 1.2, 1.2, ys[1], ys[2], off + 0.6)
		stones(false, -fz + 1.2, fz - 1.2, -fx, 1.2, ys[1], ys[2], off + 0.3)
		stones(false, -fz + 1.2, fz - 1.2, fx - 1.2, 1.2, ys[1], ys[2], off)
	end
	box("FootingCore", -fx + 1.2, 0, -fz + 1.2, fx - 1.2, FOOT - 0.06, fz - 1.2, STONE[2])
end

-- clapboard courses one stud tall in two tones
local function clap(x0: number, z0: number, x1: number, z1: number, y0: number, y1: number)
	local y = y0
	local k = 0
	while y < y1 - 0.01 do
		local h = math.min(1, y1 - y)
		box("Wall", x0, y, z0, x1, y + h, z1, if k % 2 == 0 then look.wall else look.wallShade)
		y += h
		k += 1
	end
end

local function walls()
	local t = 1
	clap(-HX, -HZ, HX, -HZ + t, FOOT, WALL) -- the front
	clap(-HX, HZ - t, HX, HZ, FOOT, WALL) -- the back
	clap(-HX, -HZ + t, -HX + t, HZ - t, FOOT, WALL) -- the right end
	clap(HX - t, -HZ + t, HX, HZ - t, FOOT, WALL) -- the left end
	box("Core", -HX + t, FOOT, -HZ + t, HX - t, WALL, HZ - t, look.wallShade)
	-- the white belt, corner boards, and the frieze under the main roof's eaves and the wing's left eave
	box("Belt", -HX - 0.2, BELT0, -HZ - 0.2, HX + 0.2, BELT1, -HZ + 0.1, TRIM)
	box("Belt", -HX - 0.2, BELT0, HZ - 0.1, HX + 0.2, BELT1, HZ + 0.2, TRIM)
	box("Belt", -HX - 0.2, BELT0, -HZ + 0.1, -HX + 0.1, BELT1, HZ - 0.1, TRIM)
	box("Belt", HX - 0.1, BELT0, -HZ + 0.1, HX + 0.2, BELT1, HZ - 0.1, TRIM)
	for _, c in { { -HX, -HZ }, { HX, -HZ }, { -HX, HZ }, { HX, HZ } } do
		box("Corner", c[1] - 0.35, FOOT, c[2] - 0.35, c[1] + 0.35, WALL, c[2] + 0.35, TRIM)
	end
	box("Frieze", -HX - 0.2, WALL, -HZ - 0.2, WX0, WALL + 0.6, -HZ + 0.5, TRIM)
	box("Frieze", -HX - 0.2, WALL, HZ - 0.5, WX0, WALL + 0.6, HZ + 0.2, TRIM)
	box("Frieze", HX - 0.5, WALL, -HZ - 0.2, HX + 0.2, WALL + 0.6, HZ + 0.2, TRIM)
end

local function attics()
	-- the main block's: a box to the roof plane at the walls, then a wedge each side up to the ridge
	local yw = mainY(HZ)
	box("Attic", -HX, WALL, -HZ, WC, yw, HZ, look.wallShade)
	local len = WC + HX
	local h = RIDGE - yw
	wedge("Attic", Vector3.new(len, h, HZ), CFrame.new((WC - HX) / 2, yw + h / 2, -HZ / 2), look.wall)
	wedge("Attic", Vector3.new(len, h, HZ), CFrame.new((WC - HX) / 2, yw + h / 2, HZ / 2) * CFrame.Angles(0, math.pi, 0), look.wall)
	-- the wing's: the same along Z (its front and back triangles are the big gables)
	local half = (HX - WX0) / 2
	local ywg = RIDGE - half * WING_TAN
	box("Attic", WX0, WALL, -HZ, HX, ywg, HZ, look.wall)
	local hg = RIDGE - ywg
	wedge("Attic", Vector3.new(HZ * 2, hg, half), CFrame.new(WX0 + half / 2, ywg + hg / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), look.wall)
	wedge("Attic", Vector3.new(HZ * 2, hg, half), CFrame.new(HX - half / 2, ywg + hg / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), look.wall)
	-- a white king post at the top of each gable
	box("KingPost", WC - 0.2, RIDGE - 2.8, -HZ - 0.3, WC + 0.2, RIDGE - 0.3, -HZ, TRIM)
	box("KingPost", WC - 0.2, RIDGE - 2.8, HZ, WC + 0.2, RIDGE - 0.3, HZ + 0.3, TRIM)
	box("KingPost", -HX - 0.3, RIDGE - 2.8, -0.2, -HX, RIDGE - 0.3, 0.2, TRIM)
end

-------------------------------------------------------------------------------------------------------------
-- windows and the door (`cf` on a wall's face, its -Z pointing out)
-------------------------------------------------------------------------------------------------------------
local function window(cf: CFrame, w: number, h: number, shutters: boolean, flowers: boolean)
	brick("Glass", Vector3.new(w, h, 0.2), cf * CFrame.new(0, 0, -0.1), GLASS, true)
	for k = -1, 1, 2 do
		brick("Frame", Vector3.new(0.45, h + 0.4, 0.45), cf * CFrame.new(k * (w / 2 + 0.22), 0, -0.22), TRIM)
	end
	brick("Sill", Vector3.new(w + 1, 0.4, 0.8), cf * CFrame.new(0, -h / 2 - 0.2, -0.4), TRIM)
	brick("Header", Vector3.new(w + 1.3, 0.6, 0.75), cf * CFrame.new(0, h / 2 + 0.3, -0.37), TRIM)
	brick("HeaderCap", Vector3.new(w + 1.7, 0.25, 0.95), cf * CFrame.new(0, h / 2 + 0.72, -0.47), TRIM, true)
	brick("Bar", Vector3.new(w, 0.2, 0.3), cf * CFrame.new(0, 0, -0.25), TRIM, true)
	brick("Bar", Vector3.new(0.2, h, 0.3), cf * CFrame.new(0, 0, -0.25), TRIM, true)
	if shutters then
		local sw = w * 0.5 + 0.1
		for k = -1, 1, 2 do
			local s = cf * CFrame.new(k * (w / 2 + 0.5 + sw / 2), 0, -0.18)
			brick("Shutter", Vector3.new(sw, h + 0.3, 0.3), s, look.shutter)
			for j = -1, 1 do
				brick("Slat", Vector3.new(sw - 0.3, 0.18, 0.12), s * CFrame.new(0, j * h / 3.3, -0.2), look.slat, true)
			end
		end
	end
	if flowers then
		local b = cf * CFrame.new(0, -h / 2 - 0.85, -0.75)
		brick("FlowerBox", Vector3.new(w + 1.1, 0.9, 1), b, TRIM)
		local n = math.max(3, math.floor(w + 1.5))
		for k = 0, n - 1 do
			local x = -(w + 0.5) / 2 + (k + 0.5) * (w + 0.5) / n
			brick("Leaves", Vector3.new(0.85, 0.5, 0.75), b * CFrame.new(x, 0.65, 0.05 * ((k % 2) * 2 - 1)), LEAF[k % 2 + 1])
			local bl = brick("Bloom", Vector3.one * 0.5, b * CFrame.new(x + 0.12, 1.05, -0.12), CREAM, true)
			bl.Shape = Enum.PartType.Ball
		end
	end
end

local function door()
	local cf = CFrame.new(PC, FOOT + 2.4, -HZ)
	brick("Door", Vector3.new(2.4, 4.8, 0.3), cf * CFrame.new(0, 0, -0.15), look.door)
	for i = 0, 3 do
		local gx, gy = (i % 2 - 0.5) * 0.95, 1.55 - math.floor(i / 2) * 0.95
		brick("DoorPane", Vector3.new(0.8, 0.8, 0.15), cf * CFrame.new(gx, gy, -0.35), GLASS, true)
	end
	for k = -1, 1, 2 do
		brick("DoorPanel", Vector3.new(0.85, 1.7, 0.12), cf * CFrame.new(k * 0.5, -1.2, -0.33), look.doorPanel, true)
		brick("DoorFrame", Vector3.new(0.45, 5.2, 0.5), cf * CFrame.new(k * 1.43, 0.2, -0.25), TRIM)
	end
	brick("DoorFrame", Vector3.new(3.4, 0.5, 0.55), cf * CFrame.new(0, 2.65, -0.27), TRIM)
	local knob = brick("Knob", Vector3.one * 0.4, cf * CFrame.new(0.8, -0.1, -0.45), BRASS, true)
	knob.Shape = Enum.PartType.Ball
end

-------------------------------------------------------------------------------------------------------------
-- the dormer, the porch, the chimney
-------------------------------------------------------------------------------------------------------------
local function dormer()
	local x0, x1 = DC - DHALF, DC + DHALF
	local base = mainY(DFACE) - 2.6 -- (well into the main roof)
	local tan = (DRIDGE - D_EAVE) / D_RUN
	local yw = D_EAVE + (D_RUN - DHALF) * tan -- the roof plane at its walls
	local back = -mainZ(DRIDGE) + 0.6
	clap(x0, DFACE, x1, back, base, yw)
	local h = DRIDGE - yw
	wedge("DormerAttic", Vector3.new(back - DFACE, h, DHALF), CFrame.new(DC - DHALF / 2, yw + h / 2, (DFACE + back) / 2) * CFrame.Angles(0, math.pi / 2, 0), look.wall)
	wedge("DormerAttic", Vector3.new(back - DFACE, h, DHALF), CFrame.new(DC + DHALF / 2, yw + h / 2, (DFACE + back) / 2) * CFrame.Angles(0, -math.pi / 2, 0), look.wall)
	for _, x in { x0, x1 } do
		box("Corner", x - 0.3, mainY(DFACE), DFACE - 0.3, x + 0.3, yw, DFACE + 0.3, TRIM)
	end
	local dsegs = function(y: number)
		return { { DFACE - 0.6, -mainZ(y) + 0.45 } }
	end
	slope({ r = Z, p0 = Vector3.new(DC - D_RUN, D_EAVE, 0), rise = DRIDGE - D_EAVE, run = D_RUN, inward = X, segs = dsegs, ends = { DFACE - 0.78 } })
	slope({ r = Z, p0 = Vector3.new(DC + D_RUN, D_EAVE, 0), rise = DRIDGE - D_EAVE, run = D_RUN, inward = -X, segs = dsegs, ends = { DFACE - 0.78 } })
	box("RidgeCap", DC - 0.45, DRIDGE - 0.05, DFACE - 0.7, DC + 0.45, DRIDGE + 0.5, -mainZ(DRIDGE), look.roofDark, true)
	-- its window: white frame, four panes, no shutters (as on the mesh)
	window(CFrame.new(DC, mainY(DFACE) + 1.85, DFACE), 2.1, 2.5, false, false)
end

local function porch()
	-- the stone base and deck, the piers, the steps
	box("PorchBase", PC - 3.2, 0, PFRONT, PC + 3.2, FOOT - 0.4, -HZ, STONE[2])
	for k = 0, 4 do
		local z0 = PFRONT + k * (HZ - (-PFRONT)) / -5
		local z1 = PFRONT + (k + 1) * (HZ - (-PFRONT)) / -5
		box("Deck", PC - 3.3, FOOT - 0.4, math.min(z0, z1), PC + 3.3, FOOT, math.max(z0, z1), if k % 2 == 0 then WOOD else WOOD_DARK)
	end
	for _, x in { PC - 2.4, PC + 2.4 } do
		box("Pier", x - 0.65, 0, -9.95, x + 0.65, FOOT - 0.4, -8.65, STONE[1])
		box("ColumnBase", x - 0.55, FOOT, -9.85, x + 0.55, FOOT + 0.5, -8.75, TRIM)
		box("Column", x - 0.38, FOOT + 0.5, -9.68, x + 0.38, 8.1, -8.92, TRIM)
		box("ColumnCap", x - 0.5, 8.1, -9.8, x + 0.5, 8.6, -8.8, TRIM)
	end
	for i, s in { { 0, 0.87, -12.3 }, { 0.87, 1.73, -11.5 }, { 1.73, FOOT - 0.4, -10.7 } } do
		box("Step", PC - 1.9, s[1], s[3], PC + 1.9, s[2], PFRONT, if i % 2 == 1 then WOOD else WOOD_DARK)
	end
	-- the beam over the columns, the gable over it with a white truss, its roof
	box("PorchBeam", PC - 2.9, 8.6, -9.8, PC + 2.9, 9.4, -8.8, TRIM)
	local tan = (P_RIDGE - P_EAVE) / P_RUN
	local half = 2.9
	local yb = P_EAVE + (P_RUN - half) * tan
	local hh = P_RIDGE - yb
	for k = -1, 1, 2 do
		wedge("PorchGable", Vector3.new(0.4, hh, half), CFrame.new(PC + k * half / 2, yb + hh / 2, PFRONT + 0.15) * CFrame.Angles(0, -k * math.pi / 2, 0), CREAM)
	end
	box("PorchTruss", PC - 0.18, 9.4, PFRONT - 0.15, PC + 0.18, P_RIDGE - 0.4, PFRONT + 0.05, TRIM)
	box("PorchTruss", PC - 1.3, 10.25, PFRONT - 0.15, PC + 1.3, 10.55, PFRONT + 0.05, TRIM)
	local psegs = function(_y: number)
		return { { PFRONT - 0.5, -HZ + 0.2 } }
	end
	slope({ r = Z, p0 = Vector3.new(PC - P_RUN, P_EAVE, 0), rise = P_RIDGE - P_EAVE, run = P_RUN, inward = X, segs = psegs, ends = { PFRONT - 0.68 } })
	slope({ r = Z, p0 = Vector3.new(PC + P_RUN, P_EAVE, 0), rise = P_RIDGE - P_EAVE, run = P_RUN, inward = -X, segs = psegs, ends = { PFRONT - 0.68 } })
	box("RidgeCap", PC - 0.4, P_RIDGE - 0.05, PFRONT - 0.6, PC + 0.4, P_RIDGE + 0.45, -HZ + 0.2, look.roofDark, true)
end

local function chimney()
	local cx, cz = -5.6, 1.2
	local y = mainY(cz + 1.3) - 1
	local k = 0
	while y < 22.4 do
		local h = math.min(1.2, 22.4 - y)
		box("Chimney", cx - 1.3, y, cz - 1.3, cx + 1.3, y + h, cz + 1.3, CHIMNEY[k % 2 + 1])
		y += h
		k += 1
	end
	box("ChimneyCap", cx - 1.6, 22.4, cz - 1.6, cx + 1.6, 23, cz + 1.6, CAP)
	box("ChimneyTop", cx - 1.1, 23, cz - 1.1, cx + 1.1, 23.4, cz + 1.1, CHIMNEY[2])
end

-------------------------------------------------------------------------------------------------------------
-- the roses and the pots
-------------------------------------------------------------------------------------------------------------
local function roses()
	-- up the right front corner
	local y = 0.3
	local i = 0
	while y < 10.4 do
		local h = rng:NextNumber(1.2, 1.8)
		local w = rng:NextNumber(1.3, 2)
		box("Rose", -HX - 0.9, y, -HZ - 0.9 + rng:NextNumber(-0.2, 0.2), -HX - 0.9 + w, y + h, -HZ - 0.15, LEAF[i % 3 + 1])
		ball("RoseBloom", 0.55, Vector3.new(-HX - 0.4 + rng:NextNumber(0, w - 0.6), y + h * 0.6, -HZ - 1), ROSE[i % 3 + 1])
		y += h * 0.85
		i += 1
	end
	-- and round onto the right side, lower as it goes back
	local z = -HZ + 0.4
	while z < -0.6 do
		local top = 10.2 - (z + HZ) * 1.2
		local w = rng:NextNumber(1, 1.5)
		box("Rose", -HX - 0.8, 0.3, z, -HX - 0.15, math.max(1.5, top), z + w, LEAF[i % 3 + 1])
		for j = 0, 1 do
			ball("RoseBloom", 0.55, Vector3.new(-HX - 0.85, rng:NextNumber(1, math.max(1.6, top - 0.4)), z + w * (0.3 + j * 0.4)), ROSE[(i + j) % 3 + 1])
		end
		z += w
		i += 1
	end
end

local function pots()
	for _, x in { PC + 3.6, PC - 4.1 } do
		box("Pot", x - 0.6, 0, -11.6, x + 0.6, 1.1, -10.4, POT)
		box("PotRim", x - 0.75, 1.1, -11.75, x + 0.75, 1.4, -10.25, POT_RIM)
		ball("Shrub", 1.7, Vector3.new(x, 2.1, -11), LEAF[1])
		ball("Shrub", 1, Vector3.new(x + 0.3, 2.9, -11.2), LEAF[3])
	end
end

-------------------------------------------------------------------------------------------------------------
function StudHouse.build(parent: Instance, pivot: CFrame, which: string?): Model
	model = Instance.new("Model")
	model.Name = "StudHouse"
	origin = pivot
	look = StudHouse.LOOKS[which or "blue"] or StudHouse.LOOKS.blue
	count = 0
	rng = Random.new(1107)
	footing()
	walls()
	attics()
	roofs()
	dormer()
	porch()
	door()
	-- the windows, where the mesh has them: one under the wing's gable and one right of the door, both with shutters
	-- and flowers; the gable window with shutters; two at the back
	window(CFrame.new(6, 6.6, -HZ), 2.4, 3.4, true, true)
	window(CFrame.new(-5.3, 6.6, -HZ), 2.4, 3.4, true, true)
	window(CFrame.new(WC, 14.6, -HZ), 2.4, 3.2, true, false)
	window(CFrame.new(-5, 6.6, HZ) * CFrame.Angles(0, math.pi, 0), 2.4, 3.4, true, false)
	window(CFrame.new(5, 6.6, HZ) * CFrame.Angles(0, math.pi, 0), 2.4, 3.4, true, false)
	chimney()
	roses()
	pots()
	model:SetAttribute("Bricks", count)
	model:SetAttribute("StudBuilt", true) -- (server/StudLook leaves it as built)
	model.WorldPivot = pivot
	model.Parent = parent
	return model
end

return StudHouse
