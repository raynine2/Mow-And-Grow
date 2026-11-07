--!strict
-- STUD WHEAT (7 Nov 2026; owner on the first stud isles: "Those are very very bad make them way more accurate and
-- pleasing to look at"). The wheat isle's farm (forge_lm_wheat) rebuilt from studded bricks, measured off square-on
-- pictures of the mesh from the front, both sides, the back and the top (a stud = 26.4 pixels):
--   a red gambrel barn (its roof flares out at the eaves) with white trim: sliding doors with an X on each leaf, a
--   hayloft door, a window, a cupola with a rooster weathervane; a lean-to with a porch down its left side; windows
--   with little awnings down its right
--   a tall red silo of upright staves, steel bands, a ribbed steel dome, a ladder up its front and a shed at its foot
--   (a door with a heart in it)
--   a wooden water tower behind the barn: four splayed legs, cross braces, dark boards between them, a deck, a
--   banded tank, a steel cone roof, a downpipe
--   hay bales in a stack, a round bale, a barrel, a scarecrow in a hat
-- Model space as the mesh's: front to -Z, the pivot at the bottom middle (the hay stands on it; the barn's floor is
-- 1.35 higher, as in the mesh). StudWheat.build(K) fills a StudKit.
local StudKit = require(script.Parent.StudKit)

type Kit = StudKit.Kit
local C = Color3.fromRGB
local V = Vector3.new
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local StudWheat = {}

local RED = { C(156, 28, 24), C(140, 24, 20) } -- the barn's boards
local RED_DARK = C(112, 18, 16)
local SILO = { C(172, 40, 24), C(156, 34, 20) }
local TRIM = C(236, 224, 196)
local ROOF = { C(30, 34, 64), C(25, 28, 54) }
local CHAR = { C(40, 42, 50), C(34, 36, 44) } -- the silo shed's roof
local STEEL = { C(120, 136, 162), C(104, 120, 148) }
local BAND = C(146, 156, 172)
local WOOD = { C(176, 98, 40), C(156, 84, 34) }
local TANK = { C(166, 90, 38), C(146, 76, 30) }
local DARKWOOD = C(124, 70, 34)
local IRON = C(46, 42, 40)
local STONE = { C(88, 82, 78), C(74, 69, 66) }
local GLASS = C(30, 34, 46)
local SLATE = C(40, 40, 48)
local HAY = { C(240, 152, 26), C(224, 138, 22) }
local STRAP = C(126, 76, 30)
local BURLAP = C(156, 90, 38)
local BURLAP_DARK = C(124, 70, 30)
local HAT = C(176, 104, 40)
local HEAD = C(184, 118, 62)
local BRONZE = C(92, 62, 40)

-------------------------------------------------------------------------------------------------------------
-- the barn's measurements
-------------------------------------------------------------------------------------------------------------
local BX = -1.05 -- its middle (X)
local HW = 5.4 -- half its width, to the boards' face
local ZF, ZB = -6.4, 8.15 -- front and back wall faces
local B0 = 1.35 -- its floor
local EAVE = 8.1 -- the side walls' top (under the roof's flare)
local RZF, RZB = -7.0, 8.95 -- the roof's ends
-- the gable's outline from the front, the roof's outer edge: (out from the middle, height), eave tip to ridge
local OUT = { Vector2.new(6.27, 7.95), Vector2.new(5.06, 9.25), Vector2.new(3.28, 13.55), Vector2.new(0, 15.65) }
local TILE = 0.35 -- the roof tiles' thickness

local function cross2(a: Vector2, b: Vector2): number
	return a.X * b.Y - a.Y * b.X
end

-- the outline moved `d` in from the roof's outer edge (the roof's underside at d = TILE)
local function inset(d: number): { Vector2 }
	local lines = {}
	for i = 1, #OUT - 1 do
		local t = (OUT[i + 1] - OUT[i]).Unit
		table.insert(lines, { OUT[i] + Vector2.new(-t.Y, t.X) * d, t })
	end
	local pts = { lines[1][1] }
	for i = 1, #lines - 1 do
		local p1, t1, p2, t2 = lines[i][1], lines[i][2], lines[i + 1][1], lines[i + 1][2]
		table.insert(pts, p1 + t1 * (cross2(p2 - p1, t2) / cross2(t1, t2)))
	end
	local p, t = lines[#lines][1], lines[#lines][2]
	table.insert(pts, p + t * (-p.X / t.X))
	return pts
end

-- the outline's height `u` out from the middle
local function heightAt(pts: { Vector2 }, u: number): number
	if u >= pts[1].X then
		return pts[1].Y
	end
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if u <= a.X and u >= b.X then
			return a.Y + (b.Y - a.Y) * (a.X - u) / (a.X - b.X)
		end
	end
	return pts[#pts].Y
end

-- upright boards on a wall, one stud each, alternating reds, studs out. `face`: a CFrame on the wall's face, its X
-- along the wall, -Z out; boards from x0 to x1 (in its X), y0 up to top(x) for each board
local function boards(K: Kit, face: CFrame, x0: number, x1: number, y0: number, top: (number) -> number, cols: { Color3 }?)
	local n = math.max(1, math.round(x1 - x0))
	local w = (x1 - x0) / n
	local cs = cols or RED
	for i = 0, n - 1 do
		local a = x0 + i * w
		local h = math.min(top(a), top(a + w)) - y0
		if h > 0.05 then
			K:brick("Boards", V(w + 0.02, h, 0.4), face * CFrame.new(a + w / 2, y0 + h / 2, 0.2), cs[i % #cs + 1])
		end
	end
end

-- a white-framed window on a face (`cf` its middle, -Z out), w x h, glass split by bars
local function window(K: Kit, cf: CFrame, w: number, h: number, bars: number?)
	K:brick("Glass", V(w, h, 0.12), cf * CFrame.new(0, 0, -0.04), GLASS, true)
	local f = 0.22
	for k = -1, 1, 2 do
		K:brick("Frame", V(f, h + f * 2, 0.22), cf * CFrame.new(k * (w / 2 + f / 2), 0, -0.1), TRIM, true)
		K:brick("Frame", V(w + f * 2, f, 0.22), cf * CFrame.new(0, k * (h / 2 + f / 2), -0.1), TRIM, true)
	end
	K:brick("Bar", V(w, 0.12, 0.16), cf * CFrame.new(0, 0, -0.08), TRIM, true)
	if (bars or 2) > 1 then
		K:brick("Bar", V(0.12, h, 0.16), cf * CFrame.new(0, 0, -0.08), TRIM, true)
	end
end

-- an X of two white bars inside a w x h rectangle (`cf` its middle on a face, -Z out)
local function xbrace(K: Kit, cf: CFrame, w: number, h: number, bw: number)
	for k = -1, 1, 2 do
		local a = (cf * CFrame.new(-w / 2, k * -h / 2, 0)).Position
		local b = (cf * CFrame.new(w / 2, k * h / 2, 0)).Position
		K:beam("Brace", a, b, bw, 0.12, TRIM, -cf.LookVector, true)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the barn
-------------------------------------------------------------------------------------------------------------
local function barnWalls(K: Kit)
	K:box("Core", BX - HW + 0.4, B0, ZF + 0.4, BX + HW - 0.4, EAVE + 0.4, ZB - 0.4, RED_DARK, true)
	local flat = function(_: number): number
		return EAVE
	end
	-- the two long sides (their own frames: X along the wall, -Z out)
	boards(K, CFrame.lookAt(V(BX + HW, 0, (ZF + ZB) / 2), V(BX + HW + 1, 0, (ZF + ZB) / 2)), -(ZB - ZF) / 2, (ZB - ZF) / 2, B0, flat)
	boards(K, CFrame.lookAt(V(BX - HW, 0, (ZF + ZB) / 2), V(BX - HW - 1, 0, (ZF + ZB) / 2)), -(ZB - ZF) / 2, (ZB - ZF) / 2, B0, flat)
	-- front and back up to the belt
	local belt = function(_: number): number
		return 8.15
	end
	boards(K, CFrame.lookAt(V(BX, 0, ZF), V(BX, 0, ZF - 1)), -HW, HW, B0, belt)
	boards(K, CFrame.lookAt(V(BX, 0, ZB), V(BX, 0, ZB + 1)), -HW, HW, B0, belt)
	-- the stone footing round the bottom, the corner boards on their stone blocks
	K:box("Footing", BX - HW - 0.12, B0, ZF - 0.12, BX + HW + 0.12, B0 + 0.45, ZB + 0.12, STONE[1])
	for _, sx in { -1, 1 } do
		for _, z in { ZF, ZB } do
			local cz = z + (if z == ZF then 0.125 else -0.125)
			K:box("Corner", BX + sx * (HW - 0.125) - 0.225, B0, cz - 0.225, BX + sx * (HW - 0.125) + 0.225, EAVE, cz + 0.225, TRIM)
			K:box("CornerStone", BX + sx * (HW - 0.125) - 0.33, B0, cz - 0.33, BX + sx * (HW - 0.125) + 0.33, B0 + 0.65, cz + 0.33, STONE[2])
		end
	end
	-- the white belt across both ends
	for _, z in { ZF, ZB } do
		local s = if z == ZF then -1 else 1
		K:box("Belt", BX - HW - 0.25, 7.75, z, BX + HW + 0.25, 8.15, z + s * 0.2, TRIM, true)
	end
end

-- a gable end: the red face above the belt, battens, the white bargeboards under the roof's edge
local function gable(K: Kit, z: number, out: number)
	local fill = inset(TILE + 0.05)
	-- clip the fill's foot to the wall line
	local p1, p2 = fill[1], fill[2]
	local hw = p1.Y + (p2.Y - p1.Y) * (p1.X - HW) / (p1.X - p2.X)
	local rows = { Vector2.new(HW, 7.9), Vector2.new(HW, hw) }
	for i = 2, #fill do
		table.insert(rows, fill[i])
	end
	local inside = V(BX, 10, z - out)
	local function pt(u: number, h: number): Vector3
		return V(BX + u, h, z)
	end
	for i = 1, #rows - 1 do
		local lo, hi = rows[i], rows[i + 1]
		if hi.X > 0.01 then
			K:quad("Gable", pt(-lo.X, lo.Y), pt(lo.X, lo.Y), pt(hi.X, hi.Y), pt(-hi.X, hi.Y), RED[1], inside, 0.4)
		else
			K:tri("Gable", pt(-lo.X, lo.Y), pt(lo.X, lo.Y), pt(0, hi.Y), RED[1], inside, 0.4)
		end
	end
	-- battens, one a stud, up to the trim
	local trimIn = inset(TILE + 0.5)
	for u = -5, 5 do
		local top = heightAt(trimIn, math.abs(u) + 0.1)
		if top > 8.4 then
			K:box("Batten", BX + u - 0.08, 8.15, z + out * 0.06, BX + u + 0.08, top, z, RED_DARK, true)
		end
	end
	-- bargeboards: under the tiles' edge, both sides, eave to ridge
	local mid = inset(TILE + 0.25)
	local zb = if out < 0 then RZF + 0.12 else RZB - 0.12
	for _, s in { -1, 1 } do
		for i = 1, #mid - 1 do
			local a, b = mid[i], mid[i + 1]
			local ext = (b - a).Unit * 0.22
			local pa, pb = a - ext, b + (if i == #mid - 1 then Vector2.zero else ext)
			K:beam("Barge", V(BX + s * pa.X, pa.Y, zb - out * 0.17), V(BX + s * pb.X, pb.Y, zb - out * 0.17), 0.46, 0.34, TRIM, Z, true)
		end
	end
end

local function barnRoof(K: Kit)
	local under = inset(TILE)
	local zc = (RZF + RZB) / 2
	for _, s in { -1, 1 } do
		for i = 1, #under - 1 do
			local a, b = under[i], under[i + 1]
			-- the deck under the tiles (no light through the seams)
			local inside = V(BX, 9, zc)
			K:quad("Deck", V(BX + s * a.X, a.Y, RZF), V(BX + s * b.X, b.Y, RZF), V(BX + s * b.X, b.Y, RZB), V(BX + s * a.X, a.Y, RZB), ROOF[2], inside, 0.3)
			K:slope(V(BX + s * a.X, a.Y, zc), Z, -s * X, b.Y - a.Y, a.X - b.X, RZF - zc, RZB - zc, ROOF[1], ROOF[2], nil, TILE)
		end
		-- the white fascia along the eave
		local e = OUT[1]
		K:box("Fascia", BX + s * (e.X - 0.05) - 0.15, e.Y - 0.32, RZF, BX + s * (e.X - 0.05) + 0.15, e.Y + 0.02, RZB, TRIM, true)
	end
	local top = OUT[#OUT]
	K:box("Ridge", BX - 0.35, top.Y - 0.3, RZF - 0.02, BX + 0.35, top.Y + 0.12, RZB + 0.02, ROOF[2], true)
	gable(K, ZF, -1)
	gable(K, ZB, 1)
end

local function barnDoors(K: Kit)
	local f = CFrame.lookAt(V(BX, 0, ZF), V(BX, 0, ZF - 1)) -- X along the front (+X world), -Z out
	-- the frame: posts and the header
	for _, k in { -1, 1 } do
		K:brick("DoorPost", V(0.42, 6.66 - B0, 0.34), f * CFrame.new(k * 3.0, (B0 + 6.66) / 2, -0.17), TRIM)
	end
	K:brick("DoorHeader", V(7.25, 0.46, 0.4), f * CFrame.new(0, 6.89, -0.2), TRIM)
	-- two leaves, each with a white edge and an X
	for _, k in { -1, 1 } do
		local leaf = f * CFrame.new(k * 1.4, (B0 + 6.6) / 2, -0.12)
		local lh = 6.6 - B0
		K:brick("DoorLeaf", V(2.78, lh, 0.24), leaf, RED[2])
		for _, e in { -1, 1 } do
			K:brick("DoorEdge", V(2.78, 0.3, 0.12), leaf * CFrame.new(0, e * (lh / 2 - 0.15), -0.17), TRIM, true)
			K:brick("DoorEdge", V(0.3, lh, 0.12), leaf * CFrame.new(e * 1.24, 0, -0.17), TRIM, true)
		end
		xbrace(K, leaf * CFrame.new(0, 0, -0.2), 2.2, lh - 0.6, 0.28)
		K:brick("Handle", V(0.1, 0.8, 0.12), f * CFrame.new(k * 0.32, 3.9, -0.42), IRON, true)
		for _, hy in { 2.3, 5.6 } do
			K:brick("Hinge", V(0.55, 0.18, 0.06), f * CFrame.new(k * 2.55, hy, -0.4), IRON, true)
		end
	end
	-- the hayloft door
	local loft = f * CFrame.new(0, 9.8, -0.1)
	K:brick("Loft", V(3.0, 2.5, 0.2), loft, RED[2])
	for _, e in { -1, 1 } do
		K:brick("LoftFrame", V(0.3, 3.11, 0.24), loft * CFrame.new(e * 1.65, 0, -0.12), TRIM, true)
		K:brick("LoftFrame", V(3.6, 0.3, 0.24), loft * CFrame.new(0, e * 1.405, -0.12), TRIM, true)
		for _, hy in { -0.85, 0.85 } do
			K:brick("Hinge", V(0.16, 0.36, 0.06), loft * CFrame.new(e * 1.5, hy, -0.27), IRON, true)
		end
	end
	xbrace(K, loft * CFrame.new(0, 0, -0.14), 2.9, 2.5, 0.26)
	-- the window high in the gable
	window(K, f * CFrame.new(0, 13.0, -0.05), 1.2, 1.45, 1)
end

-- the right (+X) side: two windows with little navy awnings
local function barnSide(K: Kit)
	local x = BX + HW
	for _, z in { 5.8, -4.9 } do
		local cf = CFrame.lookAt(V(x, 4.0, z), V(x + 1, 4.0, z))
		window(K, cf * CFrame.new(0, 0, -0.02), 1.15, 1.4)
		K:wedge("Awning", V(1.9, 0.45, 0.85), cf * CFrame.new(0, 1.42, -0.45), ROOF[1])
		for _, k in { -1, 1 } do
			K:beam("AwningArm", (cf * CFrame.new(k * 0.85, 0.85, -0.02)).Position, (cf * CFrame.new(k * 0.85, 1.2, -0.75)).Position, 0.12, 0.12, TRIM, nil, true)
		end
	end
end

local function cupola(K: Kit)
	local c = V(BX, 0, -0.4)
	K:box("Cupola", c.X - 1.0, 14.9, c.Z - 1.0, c.X + 1.0, 16.85, c.Z + 1.0, RED[1])
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K:box("CupolaCorner", c.X + sx * 1.0 - 0.14, 14.9, c.Z + sz * 1.0 - 0.14, c.X + sx * 1.0 + 0.14, 16.85, c.Z + sz * 1.0 + 0.14, TRIM, true)
		end
	end
	for i = 0, 3 do
		local cf = CFrame.new(c.X, 16.15, c.Z) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -1.02)
		K:brick("Louvre", V(0.85, 0.6, 0.08), cf, GLASS, true)
		K:brick("Sill", V(1.1, 0.12, 0.16), cf * CFrame.new(0, -0.36, -0.04), TRIM, true)
	end
	-- a navy pyramid roof, the spire, the weathervane and its rooster
	K:box("CupolaEave", c.X - 1.42, 16.85, c.Z - 1.42, c.X + 1.42, 17.0, c.Z + 1.42, ROOF[2], true)
	local apex = V(c.X, 18.35, c.Z)
	local corners = { V(-1.42, 17.0, -1.42), V(1.42, 17.0, -1.42), V(1.42, 17.0, 1.42), V(-1.42, 17.0, 1.42) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		K:tri("CupolaRoof", V(c.X + a.X, a.Y, c.Z + a.Z), V(c.X + b.X, b.Y, c.Z + b.Z), apex, ROOF[1 + i % 2], V(c.X, 17.3, c.Z), 0.2)
	end
	K:cyl("Spire", 0.12, 1.5, V(c.X, 19.05, c.Z), BRONZE)
	K:ball("SpireKnob", 0.26, V(c.X, 18.45, c.Z), BRONZE)
	for _, d in { X, Z } do
		K:brick("VaneArm", V(0.07, 0.07, 1.6), CFrame.lookAt(V(c.X, 19.35, c.Z), V(c.X, 19.35, c.Z) + d), BRONZE, true)
		for _, e in { -1, 1 } do
			local p = V(c.X, 19.35, c.Z) + d * e * 0.82
			K:brick("VaneTip", V(0.2, 0.2, 0.05), CFrame.lookAt(p, p + d:Cross(Y)) * CFrame.Angles(0, 0, math.pi / 4), BRONZE, true)
		end
	end
	-- the rooster faces +X, side on to the front
	local r = CFrame.new(c.X, 20.15, c.Z)
	K:brick("Rooster", V(0.6, 0.38, 0.26), r, BRONZE, true)
	K:ball("Rooster", 0.36, r * CFrame.new(0.26, 0.08, 0), BRONZE)
	K:ball("Rooster", 0.24, r * CFrame.new(0.38, 0.42, 0), BRONZE)
	K:brick("RoosterNeck", V(0.14, 0.32, 0.12), r * CFrame.new(0.34, 0.26, 0) * CFrame.Angles(0, 0, -0.3), BRONZE, true)
	K:brick("Comb", V(0.16, 0.12, 0.05), r * CFrame.new(0.38, 0.57, 0), C(150, 40, 30), true)
	K:wedge("Beak", V(0.05, 0.08, 0.14), r * CFrame.new(0.55, 0.4, 0) * CFrame.Angles(0, -math.pi / 2, 0), C(170, 130, 50), true)
	K:wedge("Tail", V(0.14, 0.62, 0.42), r * CFrame.new(-0.36, 0.3, 0) * CFrame.Angles(0, -math.pi / 2, 0), BRONZE, true)
	K:brick("RoosterLeg", V(0.06, 0.3, 0.06), r * CFrame.new(0, -0.32, 0), BRONZE, true)
end

-------------------------------------------------------------------------------------------------------------
-- the lean-to down the left (-X) side, a porch along its outside
-------------------------------------------------------------------------------------------------------------
local LX0, LX = BX - HW, -11.0 -- the barn's wall, the lean-to's outer wall
local LZF, LZB = -6.1, 4.8
local L0 = 1.4
local LR = { x0 = -12.2, h0 = 5.38, x1 = LX0, h1 = 7.3, z0 = -6.85, z1 = 5.3 } -- its roof's outer line

local function leanRoofAt(x: number): number -- the roof's underside at x
	return LR.h0 + (LR.h1 - LR.h0) * (x - LR.x0) / (LR.x1 - LR.x0) - TILE - 0.05
end

local function leanTo(K: Kit)
	K:box("Core", LX + 0.4, L0, LZF + 0.4, LX0, leanRoofAt(LX + 0.4), LZB - 0.4, RED_DARK, true)
	-- boards: the outer wall, the front and back ends up under the roof
	local outerTop = leanRoofAt(LX) - 0.05
	boards(K, CFrame.lookAt(V(LX, 0, (LZF + LZB) / 2), V(LX - 1, 0, (LZF + LZB) / 2)), -(LZB - LZF) / 2, (LZB - LZF) / 2, L0, function(_: number): number
		return outerTop
	end)
	local front = CFrame.lookAt(V((LX + LX0) / 2, 0, LZF), V((LX + LX0) / 2, 0, LZF - 1)) -- its X runs to +X world
	local half = (LX0 - LX) / 2
	boards(K, front, -half, half, L0, function(a: number): number
		return leanRoofAt((LX + LX0) / 2 + a) - 0.1
	end)
	local back = CFrame.lookAt(V((LX + LX0) / 2, 0, LZB), V((LX + LX0) / 2, 0, LZB + 1)) -- its X runs to -X world
	boards(K, back, -half, half, L0, function(a: number): number
		return leanRoofAt((LX + LX0) / 2 - a) - 0.1
	end)
	K:box("Footing", LX - 0.12, L0, LZF - 0.12, LX0, L0 + 0.45, LZB + 0.12, STONE[1])
	for _, z in { LZF, LZB } do
		local cz = z + (if z == LZF then 0.12 else -0.12)
		K:box("Corner", LX - 0.1, L0, cz - 0.2, LX + 0.3, outerTop, cz + 0.2, TRIM)
	end
	-- windows: two on the outside, one on each end
	for _, z in { -3.6, 1.4 } do
		window(K, CFrame.lookAt(V(LX, 3.95, z), V(LX - 1, 3.95, z)) * CFrame.new(0, 0, -0.02), 1.2, 1.3)
	end
	window(K, CFrame.lookAt(V(-8.5, 4.05, LZF), V(-8.5, 4.05, LZF - 1)) * CFrame.new(0, 0, -0.02), 1.15, 1.5)
	window(K, CFrame.lookAt(V(-8.5, 4.3, LZB), V(-8.5, 4.3, LZB + 1)) * CFrame.new(0, 0, -0.02), 1.1, 1.3)
	-- the roof
	local zc = (LR.z0 + LR.z1) / 2
	local u0, u1 = LR.h0 - TILE, LR.h1 - TILE
	K:quad("Deck", V(LR.x0, u0, LR.z0), V(LR.x1, u1, LR.z0), V(LR.x1, u1, LR.z1), V(LR.x0, u0, LR.z1), ROOF[2], V(-9, 3, zc), 0.3)
	K:slope(V(LR.x0, u0, zc), Z, X, u1 - u0, LR.x1 - LR.x0, LR.z0 - zc, LR.z1 - zc, ROOF[1], ROOF[2], nil, TILE)
	K:box("Fascia", LR.x0 - 0.05, LR.h0 - 0.42, LR.z0, LR.x0 + 0.25, LR.h0 - 0.05, LR.z1, TRIM, true)
	for _, z in { LR.z0 + 0.12, LR.z1 - 0.12 } do
		K:beam("Barge", V(LR.x0, u0 - 0.2, z), V(LR.x1, u1 - 0.2, z), 0.4, 0.3, TRIM, Z, true)
	end
end

local function porch(K: Kit)
	local px = -11.65
	local beamTop = leanRoofAt(px)
	K:box("PorchBeam", px - 0.2, beamTop - 0.32, LR.z0 + 0.3, px + 0.2, beamTop, LR.z1 - 0.6, TRIM, true)
	for _, z in { -5.95, -0.97, 3.7 } do
		K:box("PorchPost", px - 0.19, L0 + 0.3, z - 0.19, px + 0.19, beamTop - 0.32, z + 0.19, TRIM, true)
		K:box("PostStone", px - 0.3, L0 - 0.1, z - 0.3, px + 0.3, L0 + 0.3, z + 0.3, STONE[2])
		-- curved knee braces (two pieces each) out to the beam
		for _, d in { -1, 1 } do
			if z + d * 1.1 > LR.z0 + 0.4 and z + d * 1.1 < LR.z1 - 0.6 then
				local y0 = beamTop - 1.15
				local p0 = V(px, y0, z + d * 0.19)
				local p1 = V(px, y0 + 0.55, z + d * 0.55)
				local p2 = V(px, beamTop - 0.32, z + d * 1.15)
				K:beam("Knee", p0, p1, 0.16, 0.14, TRIM, X, true)
				K:beam("Knee", p1, p2, 0.16, 0.14, TRIM, X, true)
			end
		end
	end
end

local function barrel(K: Kit)
	local c = V(-7.7, 1.45, -6.95)
	K:cyl("Barrel", 1.05, 1.5, c + V(0, 0.75, 0), DARKWOOD)
	K:cyl("BarrelBelly", 1.15, 0.9, c + V(0, 0.75, 0), DARKWOOD)
	for _, y in { 0.3, 1.2 } do
		K:cyl("BarrelHoop", 1.13, 0.1, c + V(0, y, 0), IRON)
	end
	K:cyl("BarrelLid", 0.9, 0.06, c + V(0, 1.52, 0), C(130, 80, 40))
end

-------------------------------------------------------------------------------------------------------------
-- the silo and its shed
-------------------------------------------------------------------------------------------------------------
local SC = V(10.45, 0, 1.36)
local SR = 3.69
local S0 = 1.55

local function silo(K: Kit)
	K:ring("SiloFoot", SC, 24, SR + 0.08, S0, 0.85, 0.6, { WOOD[2], C(140, 74, 30) })
	local segs = { { 2.4, 8.05 }, { 8.35, 12.45 }, { 12.75, 16.35 }, { 16.65, 19.75 } }
	for i, s in segs do
		K:ring("Staves", SC, 24, SR, s[1], s[2] - s[1], 0.8, SILO)
		if i < #segs then
			K:ring("Band", SC, 24, SR + 0.07, s[2], 0.3, 0.32, { BAND }, nil, true)
		end
	end
	K:cyl("SiloCore", (SR - 0.75) * 2, 19.75 - S0, SC + V(0, (S0 + 19.75) / 2, 0), SILO[2])
	K:ring("Rim", SC, 24, SR + 0.16, 19.72, 0.32, 0.45, { BAND }, nil, true)
	K:cyl("DomeFloor", (SR - 0.2) * 2, 0.3, SC + V(0, 19.9, 0), STEEL[2])
	K:facetDome("Dome", SC + V(0, 19.98, 0), SR + 0.05, 3.5, 16, 4, STEEL, 0.25)
	K:cyl("DomeCap", 0.95, 0.35, SC + V(0, 23.55, 0), BAND)
	K:ball("DomeKnob", 0.5, SC + V(0, 23.75, 0), BAND)
	-- the ladder up its front, from the shed's roof over the rim
	local lz = SC.Z - SR - 0.4
	for _, dx in { -0.56, 0.56 } do
		local x = SC.X + 0.05 + dx
		K:box("LadderRail", x - 0.09, 6.9, lz - 0.09, x + 0.09, 20.3, lz + 0.09, BAND, true)
		K:beam("LadderHook", V(x, 20.22, lz), V(x, 20.75, lz + 0.55), 0.18, 0.18, BAND, X, true)
		K:beam("LadderHook", V(x, 20.75, lz + 0.55), V(x, 20.55, lz + 1.0), 0.18, 0.18, BAND, X, true)
		for _, y in { 10.2, 14.6, 18.6 } do
			K:box("LadderStay", x - 0.06, y - 0.06, lz, x + 0.06, y + 0.06, lz + 0.45, BAND, true)
		end
	end
	for y = 7.45, 19.9, 0.62 do
		K:rod("Rung", 0.13, 1.12, CFrame.new(SC.X + 0.05, y, lz), BAND)
	end
end

local function siloShed(K: Kit)
	local x0, x1, zf, zb = 8.25, 11.2, -4.5, -1.6
	local r0, r1 = -4.9, -1.3 -- the roof runs back into the silo
	local hf, hb = 5.9, 7.25 + (2.0 - 1.3) / 2.9 * 1.35 -- its outer line, front and back
	local function under(z: number): number
		return hf + (hb - hf) * (z - r0) / (r1 - r0) - TILE - 0.05
	end
	K:box("Core", x0 + 0.4, S0, zf + 0.4, x1 - 0.4, under(zf + 0.4), zb, RED_DARK, true)
	local mid = (x0 + x1) / 2
	boards(K, CFrame.lookAt(V(mid, 0, zf), V(mid, 0, zf - 1)), -(x1 - x0) / 2, (x1 - x0) / 2, S0, function(_: number): number
		return 5.65
	end)
	for _, side in { -1, 1 } do
		local x = if side < 0 then x0 else x1
		local cf = CFrame.lookAt(V(x, 0, (zf + zb) / 2), V(x + side, 0, (zf + zb) / 2))
		boards(K, cf, -(zb - zf) / 2, (zb - zf) / 2, S0, function(a: number): number
			-- this frame's X runs to -Z on the left (-X) side and to +Z on the right
			local z = (zf + zb) / 2 + (if side < 0 then -a else a)
			return under(z) - 0.05
		end)
		K:box("Corner", x - 0.18, S0, zf - 0.18, x + 0.18, 5.65, zf + 0.18, TRIM)
	end
	K:box("Footing", x0 - 0.1, S0, zf - 0.1, x1 + 0.1, S0 + 0.38, zb, STONE[1])
	K:box("Plate", x0 - 0.12, 5.65, zf - 0.14, x1 + 0.12, 5.95, zf + 0.1, TRIM, true)
	-- the roof, sloping to the front
	K:quad("Deck", V(x0 - 0.25, under(r0) + 0.05, r0), V(x1 + 0.25, under(r0) + 0.05, r0), V(x1 + 0.25, under(r1) + 0.05, r1), V(x0 - 0.25, under(r1) + 0.05, r1), CHAR[2], V(mid, 3, -3), 0.25)
	K:slope(V(mid, under(r0) + 0.05, r0), X, Z, hb - hf, r1 - r0, -(x1 - x0) / 2 - 0.25, (x1 - x0) / 2 + 0.25, CHAR[1], CHAR[2], nil, TILE)
	for _, x in { x0 - 0.18, x1 + 0.18 } do
		K:beam("Barge", V(x, under(r0) - 0.15, r0), V(x, under(r1) - 0.15, r1), 0.36, 0.28, TRIM, X, true)
	end
	-- the door, a heart cut in it
	local d = CFrame.lookAt(V(9.9, 0, zf), V(9.9, 0, zf - 1))
	K:brick("DoorFrame", V(1.75, 0.25, 0.2), d * CFrame.new(0, 4.68, -0.1), TRIM, true)
	for _, k in { -1, 1 } do
		K:brick("DoorFrame", V(0.24, 4.68 - S0, 0.2), d * CFrame.new(k * 0.76, (S0 + 4.68) / 2, -0.1), TRIM, true)
	end
	K:brick("ShedDoor", V(1.28, 4.55 - S0, 0.18), d * CFrame.new(0, (S0 + 4.55) / 2, -0.06), DARKWOOD)
	for _, k in { -0.32, 0.32 } do
		K:brick("Plank", V(0.05, 4.4 - S0, 0.04), d * CFrame.new(k, (S0 + 4.4) / 2, -0.17), C(70, 40, 20), true)
	end
	local heart = d * CFrame.new(0, 3.95, -0.17)
	K:brick("Heart", V(0.3, 0.3, 0.05), heart * CFrame.Angles(0, 0, math.pi / 4), C(26, 18, 14), true)
	for _, k in { -1, 1 } do
		K:ball("Heart", 0.25, heart * CFrame.new(k * 0.1, 0.13, 0.02), C(26, 18, 14))
	end
	K:ball("Knob", 0.14, d * CFrame.new(0.42, 3.0, -0.2), IRON)
	window(K, CFrame.lookAt(V(x0, 4.15, -3.15), V(x0 - 1, 4.15, -3.15)) * CFrame.new(0, 0, -0.02), 0.8, 0.8)
end

-------------------------------------------------------------------------------------------------------------
-- the water tower
-------------------------------------------------------------------------------------------------------------
local TC = V(-7.55, 0, 10.0)
local T_TOP, T_BOT = 14.15, 1.35
local function legOff(y: number): number
	return 1.8 + (T_TOP - y) / (T_TOP - T_BOT) * 1.05
end

local function towerLegs(K: Kit)
	local signs = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for _, s in signs do
		K:beam("Leg", TC + V(s[1] * 1.8, T_TOP, s[2] * 1.8), TC + V(s[1] * 2.85, T_BOT, s[2] * 2.85), 0.62, 0.62, WOOD[1], Y)
	end
	-- each face: dark boards, two tiers of cross braces, beams across
	for i = 1, 4 do
		local a, b = signs[i], signs[i % 4 + 1]
		local outward = V(a[1] + b[1], 0, a[2] + b[2]).Unit
		local function at(s: { number }, y: number, inset: number): Vector3
			local o = legOff(y) - inset
			return TC + V(s[1] * o, y, s[2] * o)
		end
		K:quad("Boards", at(a, 13.9, 0.3), at(b, 13.9, 0.3), at(b, 4.6, 0.3), at(a, 4.6, 0.3), SLATE, TC + V(0, 9, 0), 0.15)
		for _, y in { 10.5, 5.6 } do
			K:beam("CrossBeam", at(a, y, 0) + outward * 0.1, at(b, y, 0) + outward * 0.1, 0.4, 0.4, WOOD[2], outward)
		end
		for _, t in { { 13.9, 10.5 }, { 10.5, 5.6 } } do
			K:beam("Brace", at(a, t[1], 0) + outward * 0.32, at(b, t[2], 0) + outward * 0.32, 0.32, 0.22, WOOD[1], outward, true)
			K:beam("Brace", at(b, t[1], 0) + outward * 0.36, at(a, t[2], 0) + outward * 0.36, 0.32, 0.22, WOOD[1], outward, true)
		end
	end
end

local function towerTop(K: Kit)
	-- the deck, its rim, the joists' ends under it
	K:box("Deck", TC.X - 2.8, T_TOP, TC.Z - 2.8, TC.X + 2.8, T_TOP + 0.5, TC.Z + 2.8, WOOD[2])
	for _, s in { -1, 1 } do
		K:box("DeckRim", TC.X - 2.85, T_TOP + 0.5, TC.Z + s * 2.85 - 0.15, TC.X + 2.85, 15.07, TC.Z + s * 2.85 + 0.15, WOOD[1], true)
		K:box("DeckRim", TC.X + s * 2.85 - 0.15, T_TOP + 0.5, TC.Z - 2.85, TC.X + s * 2.85 + 0.15, 15.07, TC.Z + 2.85, WOOD[1], true)
	end
	for _, o in { -1.8, 0, 1.8 } do
		K:box("Joist", TC.X - 3.05, T_TOP - 0.4, TC.Z + o - 0.18, TC.X + 3.05, T_TOP, TC.Z + o + 0.18, WOOD[1])
		K:box("Joist", TC.X + o - 0.18, T_TOP - 0.4, TC.Z - 3.05, TC.X + o + 0.18, T_TOP, TC.Z + 3.05, WOOD[1])
	end
	-- the tank: staves, two steel bands
	K:ring("Tank", TC, 16, 2.42, 15.07, 19.16 - 15.07, 0.7, TANK)
	K:cyl("TankCore", (2.42 - 0.6) * 2, 19.16 - 15.07, TC + V(0, (15.07 + 19.16) / 2, 0), TANK[2])
	for _, y in { 16.05, 18.03 } do
		K:ring("TankBand", TC, 16, 2.5, y, 0.3, 0.3, { BAND }, nil, true)
	end
	-- the cone roof, its lip and knob
	K:ring("ConeLip", TC, 16, 2.82, 19.06, 0.16, 0.5, { STEEL[2] }, nil, true)
	K:cone("Cone", TC + V(0, 19.2, 0), 2.92, 2.1, 16, STEEL, 0.2)
	K:cyl("ConeCap", 0.42, 0.25, TC + V(0, 21.3, 0), BAND)
	K:ball("ConeKnob", 0.42, TC + V(0, 21.5, 0), BAND)
	-- the downpipe down its left side
	local px, pz = TC.X - 2.78, TC.Z - 0.1
	K:rod("Pipe", 0.36, 0.5, CFrame.new(px + 0.25, 17.7, pz), STEEL[1])
	K:ball("PipeElbow", 0.42, V(px, 17.7, pz), STEEL[1])
	K:cyl("Pipe", 0.36, 17.7 - 13.55, V(px, (17.7 + 13.55) / 2, pz), STEEL[1])
	K:cyl("PipeMouth", 0.46, 0.2, V(px, 13.5, pz), STEEL[2])
end

-------------------------------------------------------------------------------------------------------------
-- hay, the scarecrow
-------------------------------------------------------------------------------------------------------------
-- a bale: `cf` its middle, L long along cf's X, h tall, w wide; two straps round it
local function bale(K: Kit, cf: CFrame, L: number, h: number, w: number, k: number)
	K:brick("Hay", V(L, h, w), cf, HAY[k % 2 + 1])
	for _, e in { -1, 1 } do
		K:brick("Strap", V(0.16, h + 0.04, w + 0.04), cf * CFrame.new(e * L / 4, 0, 0), STRAP, true)
	end
end

local function hay(K: Kit)
	local yaw = function(d: number): CFrame
		return CFrame.Angles(0, math.rad(d), 0)
	end
	bale(K, CFrame.new(0.425, 0.85, -12.05) * yaw(-3), 2.25, 1.7, 1.9, 1)
	bale(K, CFrame.new(2.675, 0.85, -12.05) * yaw(2), 2.15, 1.7, 1.9, 2)
	bale(K, CFrame.new(0.475, 0.85, -10.15) * yaw(2), 2.15, 1.7, 1.9, 2)
	bale(K, CFrame.new(2.675, 0.85, -10.15) * yaw(-2), 2.15, 1.7, 1.9, 1)
	bale(K, CFrame.new(2.35, 0.85, -8.17) * yaw(95), 2.05, 1.7, 2.1, 1)
	bale(K, CFrame.new(1.6, 2.57, -11.05) * yaw(-4), 3.6, 1.74, 2.1, 2)
	bale(K, CFrame.new(2.47, 2.57, -8.8) * yaw(98), 2.15, 1.74, 2.05, 1)
	-- the round bale, its end to the front
	local rb = CFrame.new(-2.25, 1.3, -10.25) * CFrame.Angles(0, math.rad(75), 0)
	K:rod("RoundBale", 2.6, 2.9, rb, HAY[2])
	for _, e in { -1, 1 } do
		K:rod("Strap", 2.66, 0.16, rb * CFrame.new(e * 0.75, 0, 0), STRAP)
	end
	K:rod("BaleEnd", 1.9, 2.94, rb, HAY[1])
	K:rod("BaleEnd", 1.1, 2.98, rb, HAY[2])
end

local function scarecrow(K: Kit)
	local at = V(-12.4, 0, -7.7)
	local cf = CFrame.lookAt(at, at + V(0.7, 0, -0.7))
	K:brick("Post", V(0.34, 4.3, 0.34), cf * CFrame.new(0, 2.15, 0.2), DARKWOOD)
	K:brick("CrossBar", V(4.3, 0.26, 0.26), cf * CFrame.new(0, 3.55, 0.2), DARKWOOD)
	for _, k in { -1, 1 } do
		K:brick("Leg", V(0.4, 0.75, 0.42), cf * CFrame.new(k * 0.3, 1.25, 0), BURLAP_DARK)
		K:brick("Straw", V(0.46, 0.28, 0.46), cf * CFrame.new(k * 0.3, 0.85, 0), HAY[1])
		K:brick("Sleeve", V(1.55, 0.55, 0.55), cf * CFrame.new(k * 1.05, 3.55, 0), BURLAP)
		K:brick("Straw", V(0.5, 0.45, 0.45), cf * CFrame.new(k * 1.98, 3.55, 0), HAY[1])
		K:brick("Straw", V(0.18, 0.18, 0.5), cf * CFrame.new(k * 2.3, 3.7, 0) * CFrame.Angles(0, 0, k * 0.5), HAY[2], true)
	end
	K:brick("Coat", V(1.25, 2.1, 0.78), cf * CFrame.new(0, 2.85, 0), BURLAP)
	K:brick("CoatHem", V(1.45, 0.32, 0.92), cf * CFrame.new(0, 1.75, 0), BURLAP_DARK)
	K:brick("Rope", V(1.3, 0.18, 0.84), cf * CFrame.new(0, 2.4, 0), C(170, 140, 90), true)
	K:brick("Patch", V(0.36, 0.36, 0.04), cf * CFrame.new(-0.28, 3.05, -0.41), C(150, 60, 40), true)
	K:brick("Collar", V(0.9, 0.22, 0.6), cf * CFrame.new(0, 3.95, 0), HAY[1])
	K:ball("Head", 1.14, cf * CFrame.new(0, 4.45, 0), HEAD)
	for _, k in { -1, 1 } do
		K:brick("Eye", V(0.18, 0.18, 0.05), cf * CFrame.new(k * 0.22, 4.55, -0.55), C(30, 22, 16), true)
	end
	K:brick("Mouth", V(0.5, 0.07, 0.05), cf * CFrame.new(0, 4.22, -0.53), C(30, 22, 16), true)
	for _, k in { -0.16, 0, 0.16 } do
		K:brick("Stitch", V(0.05, 0.18, 0.05), cf * CFrame.new(k, 4.22, -0.54), C(30, 22, 16), true)
	end
	local hat = cf * CFrame.new(0, 5.02, 0) * CFrame.Angles(math.rad(-6), 0, math.rad(5))
	K:cyl("HatBrim", 2.2, 0.13, hat, HAT)
	K:cyl("Hat", 1.08, 0.72, hat * CFrame.new(0, 0.42, 0), HAT)
	K:cyl("HatBand", 1.12, 0.16, hat * CFrame.new(0, 0.16, 0), C(70, 40, 20))
end

function StudWheat.build(K: Kit)
	barnWalls(K)
	barnRoof(K)
	barnDoors(K)
	barnSide(K)
	cupola(K)
	leanTo(K)
	porch(K)
	barrel(K)
	silo(K)
	siloShed(K)
	towerLegs(K)
	towerTop(K)
	hay(K)
	scarecrow(K)
end

return StudWheat
