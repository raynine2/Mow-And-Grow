--!strict
-- STUD ISLES (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar ... super hoog kwaliteit", "Moet meer
-- accuraat zijn en donkerder", "Ga verder dan"). The seven landmarks on the lobby's floating isles (forge_lm_<kind>)
-- rebuilt from studded bricks (server/StudKit) to their own layouts, from pictures of each from its front:
--   wheat     a red gambrel barn with white trim, a silo with a blue dome and a ladder, a shed, hay bales, a scarecrow
--   swamp     a plank hut on stilts over a lily pond: a mossy roof, round windows, hanging green lanterns, a ladder,
--             a dock, a rowboat with an oar, cattails
--   pine      a log lookout tower: four braced legs on stones, a railed platform, a cabin, a green roof with a little
--             pine on top, a ladder, a lantern, mushrooms
-- Front to -Z, the pivot at the bottom middle (as the meshes'). StudIsles.build(kind, parent, pivot) -> the Model.
local StudKit = require(script.Parent.StudKit)

local StudIsles = {}

type Kit = StudKit.Kit
local C = Color3.fromRGB
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local WHITE = C(236, 230, 214)
local ROPE = C(196, 164, 110)
local LOG = { C(122, 82, 50), C(100, 66, 40) }
local PLANK = { C(140, 96, 60), C(120, 80, 50) }
local STONE = { C(132, 126, 118), C(110, 104, 98) }
local LEAF = { C(70, 140, 58), C(56, 118, 48), C(86, 156, 66) }

-- two-tone courses one stud tall between (x0, z0) and (x1, z1), from y0 to y1
local function courses(K: Kit, name: string, x0: number, z0: number, x1: number, z1: number, y0: number, y1: number, cols: { Color3 })
	local y = y0
	local k = 0
	while y < y1 - 0.01 do
		local h = math.min(1, y1 - y)
		K:box(name, x0, y, z0, x1, y + h, z1, cols[k % #cols + 1])
		y += h
		k += 1
	end
end

-- a white-framed window on a face (`cf`: its middle, -Z out), w x h, four panes of `glass`
local function window(K: Kit, cf: CFrame, w: number, h: number, glass: Color3, frame: Color3?)
	local fr = frame or WHITE
	K:brick("Glass", Vector3.new(w, h, 0.2), cf * CFrame.new(0, 0, -0.1), glass, true)
	for k = -1, 1, 2 do
		K:brick("Frame", Vector3.new(0.4, h + 0.4, 0.4), cf * CFrame.new(k * (w / 2 + 0.2), 0, -0.2), fr)
		K:brick("Frame", Vector3.new(w + 0.8, 0.4, 0.4), cf * CFrame.new(0, k * (h / 2 + 0.2), -0.2), fr)
	end
	K:brick("Bar", Vector3.new(w, 0.18, 0.25), cf * CFrame.new(0, 0, -0.2), fr, true)
	K:brick("Bar", Vector3.new(0.18, h, 0.25), cf * CFrame.new(0, 0, -0.2), fr, true)
end

-- an X brace in a rectangle (`cf` its middle on a face, -Z out)
local function xbrace(K: Kit, cf: CFrame, w: number, h: number, col: Color3)
	local len = math.sqrt(w * w + h * h)
	local a = math.atan2(h, w)
	K:brick("Brace", Vector3.new(len - 0.3, 0.35, 0.25), cf * CFrame.Angles(0, 0, a), col, true)
	K:brick("Brace", Vector3.new(len - 0.3, 0.35, 0.25), cf * CFrame.new(0, 0, -0.03) * CFrame.Angles(0, 0, -a), col, true)
end

-- a hanging lantern: a little cap, glowing glass, a ring
local function lantern(K: Kit, at: Vector3, col: Color3, hangTo: number?)
	if hangTo and hangTo > at.Y + 0.8 then
		K:box("LanternChain", at.X - 0.06, at.Y + 0.8, at.Z - 0.06, at.X + 0.06, hangTo, at.Z + 0.06, C(60, 50, 40), true)
	end
	K:box("LanternCap", at.X - 0.45, at.Y + 0.55, at.Z - 0.45, at.X + 0.45, at.Y + 0.8, at.Z + 0.45, C(60, 50, 40), true)
	K:glow("LanternGlass", Vector3.new(0.7, 1.1, 0.7), CFrame.new(at), col, 7)
	K:box("LanternBase", at.X - 0.4, at.Y - 0.7, at.Z - 0.4, at.X + 0.4, at.Y - 0.55, at.Z + 0.4, C(60, 50, 40), true)
end

-------------------------------------------------------------------------------------------------------------
-- WHEAT: the barn
-------------------------------------------------------------------------------------------------------------
local RED = { C(178, 46, 40), C(160, 38, 34) }
local NAVY = { C(40, 52, 92), C(32, 42, 76) }
local GOLD = { C(222, 170, 70), C(204, 150, 56) }
local GREY = C(150, 152, 158)

local function silo(K: Kit, c: Vector3)
	local r = 3
	for k = 0, 18 do
		local band = k % 5 == 4
		K:ring(if band then "SiloBand" else "Silo", c, 12, if band then r + 0.12 else r, k, 1, 1, if band then { GREY } else RED)
	end
	K:cyl("SiloCore", r * 2 - 1.6, 19, c + Vector3.new(0, 9.5, 0), RED[2])
	K:ring("SiloRim", c, 12, r + 0.3, 19, 0.5, 0.8, { GREY })
	K:dome("SiloDome", c, 12, r + 0.1, 0.5, 19.5, 23.4, 6, { C(54, 96, 168), C(44, 80, 146) }, true)
	K:ball("SiloTop", 0.8, c + Vector3.new(0, 23.7, 0), GREY)
	-- the ladder up its front-right
	local f = CFrame.new(c) * CFrame.Angles(0, math.rad(-20), 0) * CFrame.new(0, 0, -(r + 0.35))
	for k = -1, 1, 2 do
		K:brick("LadderRail", Vector3.new(0.25, 18, 0.25), f * CFrame.new(k * 0.6, 11, 0), C(80, 100, 150), true)
	end
	for y = 2.5, 19.5, 1 do
		K:brick("LadderRung", Vector3.new(1.2, 0.18, 0.18), f * CFrame.new(0, y, 0), C(80, 100, 150), true)
	end
end

local function barn(K: Kit)
	local x0, x1, zf, zb = -7, 5, -5, 11
	local cx, zc, len = (x0 + x1) / 2, (zf + zb) / 2, zb - zf
	local EAVE, BREAK, RIDGE = 6.4, 11.4, 14.8
	local W, WB = (x1 - x0) / 2, 4
	-- walls, red clapboard
	courses(K, "Wall", x0, zf, x1, zf + 1, 0, EAVE, RED)
	courses(K, "Wall", x0, zb - 1, x1, zb, 0, EAVE, RED)
	courses(K, "Wall", x0, zf + 1, x0 + 1, zb - 1, 0, EAVE, RED)
	courses(K, "Wall", x1 - 1, zf + 1, x1, zb - 1, 0, EAVE, RED)
	K:box("Core", x0 + 1, 0, zf + 1, x1 - 1, EAVE, zb - 1, RED[2])
	-- the gambrel's solid: a box with steep wedges either side, the gable prism on top (red, so the gable ends read)
	K:box("Gambrel", cx - WB, EAVE, zf, cx + WB, BREAK, zb, RED[1])
	for s = -1, 1, 2 do
		K:wedge("Gambrel", Vector3.new(len, BREAK - EAVE, W - WB), CFrame.new(cx + s * (WB + (W - WB) / 2), (EAVE + BREAK) / 2, zc) * CFrame.Angles(0, s * -math.pi / 2, 0), RED[1])
	end
	K:prism("Gambrel", CFrame.new(cx, BREAK, zc) * CFrame.Angles(0, math.pi / 2, 0), len, WB * 2, RIDGE - BREAK, RED[2])
	-- the roof: navy rows on the four slopes, white bargeboards
	for s = -1, 1, 2 do
		-- (on the solid's own line, carried on past the wall: no gap under the eave)
		local steep = (BREAK - EAVE) / (W - WB)
		K:slope(Vector3.new(cx + s * (W + 0.6), EAVE - 0.6 * steep, zc), Z, -s * X, BREAK - EAVE + 0.6 * steep, W + 0.6 - WB, -len / 2 - 0.5, len / 2 + 0.5, NAVY[1], NAVY[2], WHITE)
		K:slope(Vector3.new(cx + s * WB, BREAK, zc), Z, -s * X, RIDGE - BREAK, WB, -len / 2 - 0.5, len / 2 + 0.5, NAVY[2], NAVY[1], WHITE)
	end
	K:box("RidgeCap", cx - 0.5, RIDGE - 0.05, zf - 0.5, cx + 0.5, RIDGE + 0.5, zb + 0.5, NAVY[2], true)
	-- white corner boards and the band at the eaves
	for _, c in { { x0, zf }, { x1, zf }, { x0, zb }, { x1, zb } } do
		K:box("Corner", c[1] - 0.35, 0, c[2] - 0.35, c[1] + 0.35, EAVE, c[2] + 0.35, WHITE)
	end
	K:box("Band", x0 - 0.2, EAVE - 0.4, zf - 0.25, x1 + 0.2, EAVE, zf + 0.1, WHITE)
	-- the big doors: white frame, two leaves each with an X, a beam over them
	local df = CFrame.new(cx, 0, zf - 0.15)
	K:brick("DoorFrame", Vector3.new(7.4, 0.5, 0.4), df * CFrame.new(0, 5.6, 0), WHITE)
	for k = -1, 1, 2 do
		K:brick("DoorFrame", Vector3.new(0.45, 5.6, 0.4), df * CFrame.new(k * 3.5, 2.8, 0), WHITE)
		local leaf = df * CFrame.new(k * 1.7, 2.75, 0.05)
		K:brick("Door", Vector3.new(3.2, 5.3, 0.25), leaf, RED[2])
		K:brick("DoorFrame", Vector3.new(3.2, 0.35, 0.3), leaf * CFrame.new(0, 2.5, -0.1), WHITE, true)
		K:brick("DoorFrame", Vector3.new(3.2, 0.35, 0.3), leaf * CFrame.new(0, -2.5, -0.1), WHITE, true)
		K:brick("DoorFrame", Vector3.new(0.35, 5.3, 0.3), leaf * CFrame.new(k * 1.45, 0, -0.1), WHITE, true)
		xbrace(K, leaf * CFrame.new(0, 0, -0.2), 2.8, 4.8, WHITE)
	end
	K:brick("DoorFrame", Vector3.new(0.4, 5.3, 0.35), df * CFrame.new(0, 2.75, -0.15), WHITE, true)
	-- the hayloft door, with its X
	local hl = CFrame.new(cx, 8.9, zf - 0.15)
	K:brick("Loft", Vector3.new(2.8, 2.8, 0.25), hl, RED[2])
	for k = -1, 1, 2 do
		K:brick("LoftFrame", Vector3.new(0.35, 3.2, 0.35), hl * CFrame.new(k * 1.55, 0, -0.1), WHITE)
		K:brick("LoftFrame", Vector3.new(3.4, 0.35, 0.35), hl * CFrame.new(0, k * 1.55, -0.1), WHITE)
	end
	xbrace(K, hl * CFrame.new(0, 0, -0.2), 2.6, 2.6, WHITE)
	-- a cupola on the ridge
	K:box("Cupola", cx - 1, RIDGE - 0.6, zc - 1, cx + 1, RIDGE + 1.6, zc + 1, WHITE)
	K:prism("CupolaRoof", CFrame.new(cx, RIDGE + 1.6, zc) * CFrame.Angles(0, math.pi / 2, 0), 2.8, 2.8, 1.2, NAVY[1])
	-- the lean-to on the left (-X), its window
	local lx0 = x0 - 3.6
	courses(K, "Wall", lx0, -2, x0, 8, 0, 4.2, RED)
	K:wedge("LeanTo", Vector3.new(10, 1.4, 3.6), CFrame.new(lx0 + 1.8, 4.9, 3) * CFrame.Angles(0, math.pi / 2, 0), RED[2])
	K:slope(Vector3.new(lx0 - 0.5, 4.0, 3), Z, X, 1.6, 4.1, -5.5, 5.5, NAVY[1], NAVY[2], WHITE)
	window(K, CFrame.new(lx0 + 1.8, 2.4, -2.1), 1.6, 1.6, C(60, 80, 110))
	K:box("Corner", lx0 - 0.3, 0, -2.3, lx0 + 0.3, 4.2, -1.7, WHITE)
end

local function shed(K: Kit)
	-- the little shed in front of the silo: white trim, a white door, a navy roof
	local x0, x1, z0, z1 = 6.6, 10.6, -5.2, -1.2
	courses(K, "Wall", x0, z0, x1, z1, 0, 4.4, RED)
	K:wedge("Shed", Vector3.new(x1 - x0, 1, z1 - z0), CFrame.new((x0 + x1) / 2, 4.9, (z0 + z1) / 2), RED[2])
	K:slope(Vector3.new((x0 + x1) / 2, 4.2, z0 - 0.5), X, Z, 1.2, 4.6, -2.4, 2.4, NAVY[1], NAVY[2], WHITE)
	local d = CFrame.new((x0 + x1) / 2, 1.8, z0 - 0.15)
	K:brick("ShedDoor", Vector3.new(1.8, 3.4, 0.25), d, WHITE)
	K:brick("ShedDoor", Vector3.new(1.3, 1.2, 0.2), d * CFrame.new(0, 0.7, -0.15), RED[2], true)
	for _, c in { x0, x1 } do
		K:box("Corner", c - 0.3, 0, z0 - 0.3, c + 0.3, 4.4, z0 + 0.3, WHITE)
	end
end

local function hay(K: Kit)
	local function bale(cf: CFrame)
		K:brick("Hay", Vector3.new(2.3, 1.2, 1.3), cf, GOLD[1])
		for k = -1, 1, 2 do
			K:brick("Twine", Vector3.new(0.18, 1.25, 1.35), cf * CFrame.new(k * 0.55, 0, 0), C(150, 104, 52), true)
		end
	end
	local base = CFrame.new(0.4, 0.6, -8.6) * CFrame.Angles(0, math.rad(6), 0)
	for i = -1, 1 do
		bale(base * CFrame.new(i * 2.35, 0, 0))
	end
	bale(base * CFrame.new(-1.2, 1.2, 0.1) * CFrame.Angles(0, math.rad(-8), 0))
	bale(base * CFrame.new(1.2, 1.2, -0.1) * CFrame.Angles(0, math.rad(5), 0))
	bale(base * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.rad(90), 0))
	-- a round bale beside them
	K:rod("RoundBale", 2.4, 1.8, CFrame.new(-3.6, 1.2, -9.4) * CFrame.Angles(0, math.rad(80), 0), GOLD[2])
end

local function scarecrow(K: Kit)
	local at = Vector3.new(-12.2, 0, -5.4)
	local cf = CFrame.new(at) * CFrame.Angles(0, math.rad(-25), 0)
	K:brick("Post", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(0, 3.5, 0), LOG[1])
	K:brick("Arms", Vector3.new(4.4, 0.4, 0.4), cf * CFrame.new(0, 4.9, 0), LOG[1])
	K:brick("Coat", Vector3.new(1.7, 2.3, 1), cf * CFrame.new(0, 4.1, 0), C(130, 86, 52))
	K:brick("Sleeves", Vector3.new(3.4, 0.8, 0.8), cf * CFrame.new(0, 4.9, 0), C(118, 76, 46))
	K:brick("Patch", Vector3.new(0.6, 0.6, 0.1), cf * CFrame.new(0.4, 3.6, -0.55), C(90, 120, 160), true)
	for k = -1, 1, 2 do
		K:brick("Straw", Vector3.new(0.6, 0.5, 0.5), cf * CFrame.new(k * 2.05, 4.85, 0), GOLD[1])
	end
	K:ball("Head", 1.3, cf * CFrame.new(0, 6, 0), C(214, 190, 146))
	K:cyl("HatBrim", 2.1, 0.15, cf * CFrame.new(0, 6.55, 0), C(110, 72, 42))
	K:cyl("Hat", 1.1, 0.8, cf * CFrame.new(0, 6.95, 0), C(110, 72, 42))
end

local function wheat(K: Kit)
	barn(K)
	silo(K, Vector3.new(9.6, 0, 1.6))
	shed(K)
	hay(K)
	scarecrow(K)
end

-------------------------------------------------------------------------------------------------------------
-- SWAMP: the hut on stilts
-------------------------------------------------------------------------------------------------------------
local POND = { C(70, 122, 70), C(58, 104, 60) }
local PAD = { C(96, 164, 70), C(80, 146, 60) }
local MOSS = { C(98, 120, 56), C(84, 104, 48) }
local LANTERN = C(150, 255, 150)

local function swamp(K: Kit)
	-- the pond's ground: an uneven mat of studded greens, lily pads on it
	local mats = { { -9, -6, 10, 12 }, { -6, -10, 9, -5 }, { 7, -4, 11, 8 }, { -11, 1, -8, 9 } }
	for i, r in mats do
		K:box("Pond", r[1], 0, r[2], r[3], 1, r[4], POND[i % 2 + 1])
	end
	for _, p in { { -7.6, -8, 2.6 }, { 6, -7.8, 2 }, { -10, 4.5, 2.2 }, { 9.2, 6, 1.8 }, { 2.5, -9.2, 1.6 } } do
		K:cyl("LilyPad", p[3], 0.2, Vector3.new(p[1], 1.1, p[2]), PAD[1])
	end
	-- the stilts, rope-wrapped, the deck on them
	local DY = 6.6
	for _, s in { { -4.6, -4.6 }, { 4.6, -4.6 }, { -4.6, 6 }, { 4.6, 6 }, { 0, 6 } } do
		K:rod("Stilt", 0.9, DY - 0.5, CFrame.new(s[1], (DY + 1) / 2, s[2]) * CFrame.Angles(0, 0, math.pi / 2), LOG[2])
		K:cyl("Rope", 1.05, 0.4, Vector3.new(s[1], DY - 1.4, s[2]), ROPE)
	end
	for i = 0, 5 do
		local z0 = -5.6 + i * 2.1
		K:box("Deck", -5.6, DY, z0, 5.6, DY + 0.5, z0 + 2.05, PLANK[i % 2 + 1])
	end
	K:box("DeckBeam", -5.8, DY - 0.5, -5.8, 5.8, DY, -5.3, LOG[1])
	-- the hut: plank walls in two tones, a door with a round window, a round window in the gable
	local w0, w1, d0, d1, TOP = -3.6, 3.6, -1.6, 6.2, DY + 5.8
	courses(K, "HutWall", w0, d0, w1, d0 + 0.8, DY + 0.5, TOP, PLANK)
	courses(K, "HutWall", w0, d1 - 0.8, w1, d1, DY + 0.5, TOP, PLANK)
	courses(K, "HutWall", w0, d0, w0 + 0.8, d1, DY + 0.5, TOP, PLANK)
	courses(K, "HutWall", w1 - 0.8, d0, w1, d1, DY + 0.5, TOP, PLANK)
	for _, x in { w0, w1 } do
		K:rod("CornerLog", 0.8, TOP - DY - 0.5, CFrame.new(x, (DY + 0.5 + TOP) / 2, d0) * CFrame.Angles(0, 0, math.pi / 2), LOG[2])
	end
	local door = CFrame.new(0, DY + 2.4, d0 - 0.15)
	K:brick("HutDoor", Vector3.new(2.2, 3.8, 0.25), door, C(110, 70, 42))
	K:brick("DoorFrame", Vector3.new(2.8, 0.4, 0.4), door * CFrame.new(0, 2.05, -0.1), LOG[2])
	K:cyl("Porthole", 0.9, 0.15, door * CFrame.new(0, 0.7, -0.2) * CFrame.Angles(math.pi / 2, 0, 0), C(150, 220, 170))
	K:ball("DoorKnob", 0.3, door * CFrame.new(0.75, -0.3, -0.25), C(200, 160, 70))
	-- the steep mossy roof, its gables
	local RIDGE = TOP + 6.2
	K:prism("HutGable", CFrame.new(0, TOP, (d0 + d1) / 2) * CFrame.Angles(0, math.pi / 2, 0), d1 - d0, w1 - w0, RIDGE - TOP, PLANK[2])
	local pitch = (RIDGE - TOP) / w1
	for s = -1, 1, 2 do
		K:slope(Vector3.new(s * (w1 + 1.3), TOP - 1.3 * pitch, (d0 + d1) / 2), Z, -s * X, RIDGE - TOP + 1.3 * pitch, w1 + 1.3, -(d1 - d0) / 2 - 0.9, (d1 - d0) / 2 + 0.6, MOSS[1], MOSS[2])
	end
	K:rod("RidgeLog", 0.8, d1 - d0 + 2, CFrame.new(0, RIDGE + 0.3, (d0 + d1) / 2) * CFrame.Angles(0, math.pi / 2, 0), LOG[2])
	K:cyl("GableWindow", 1.5, 0.2, CFrame.new(0, TOP + 2.2, d0 - 0.2) * CFrame.Angles(math.pi / 2, 0, 0), C(150, 220, 170))
	K:cyl("GableWindowRing", 1.9, 0.15, CFrame.new(0, TOP + 2.2, d0 - 0.12) * CFrame.Angles(math.pi / 2, 0, 0), LOG[2])
	-- the chimney log sticking up through the ridge, rope-bound
	K:rod("ChimneyLog", 1.4, 5, CFrame.new(0.4, RIDGE + 1.6, d0 + 1) * CFrame.Angles(0, 0, math.pi / 2 - math.rad(8)), LOG[1])
	K:cyl("Rope", 1.55, 0.35, CFrame.new(0.55, RIDGE + 2.6, d0 + 1), ROPE)
	-- green lanterns: two under the eaves, one on the post's arm
	lantern(K, Vector3.new(w0 - 0.7, TOP - 3.2, d0 - 0.6), LANTERN, TOP - 1.2 * pitch)
	lantern(K, Vector3.new(w1 + 0.7, TOP - 3.2, d0 - 0.6), LANTERN, TOP - 1.2 * pitch)
	K:rod("LanternPost", 0.6, 7.5, CFrame.new(-5.2, DY + 3.75, -5) * CFrame.Angles(0, 0, math.pi / 2), LOG[2])
	K:brick("LanternArm", Vector3.new(2.4, 0.45, 0.45), CFrame.new(-6.3, DY + 7.1, -5), LOG[2])
	lantern(K, Vector3.new(-7.1, DY + 5.6, -5), LANTERN, DY + 6.9)
	-- the rope rail round the deck's front
	for _, x in { -5.2, -2.4, 2.4, 5.2 } do
		K:rod("RailPost", 0.4, 2.2, CFrame.new(x, DY + 1.6, -5.3) * CFrame.Angles(0, 0, math.pi / 2), LOG[2])
	end
	K:brick("RailRope", Vector3.new(2.8, 0.2, 0.2), CFrame.new(-3.8, DY + 2.2, -5.3), ROPE, true)
	K:brick("RailRope", Vector3.new(2.8, 0.2, 0.2), CFrame.new(3.8, DY + 2.2, -5.3), ROPE, true)
	-- the ladder down to the dock, the dock
	local lad = CFrame.new(0, (DY + 1) / 2, -6.4) * CFrame.Angles(math.rad(14), 0, 0)
	for k = -1, 1, 2 do
		K:brick("LadderRail", Vector3.new(0.3, DY + 0.4, 0.3), lad * CFrame.new(k * 0.75, 0, 0), LOG[2], true)
	end
	for y = -2.4, 2.4, 1.1 do
		K:brick("LadderRung", Vector3.new(1.5, 0.22, 0.22), lad * CFrame.new(0, y, 0), LOG[1], true)
	end
	for i = 0, 3 do
		local z0 = -8 - i * 1.2
		K:box("Dock", -1.6, 1, z0 - 1.15, 1.6, 1.4, z0, PLANK[i % 2 + 1])
	end
	for _, p in { { -1.6, -12.8 }, { 1.6, -12.8 } } do
		K:rod("DockPost", 0.5, 2.2, CFrame.new(p[1], 1.6, p[2]) * CFrame.Angles(0, 0, math.pi / 2), LOG[2])
	end
	-- the rowboat at the front-left, an oar in it
	local boat = CFrame.new(-6.4, 1.3, -9.4) * CFrame.Angles(0, math.rad(-30), 0)
	K:brick("BoatHull", Vector3.new(2.2, 0.6, 4.6), boat, PLANK[2])
	for k = -1, 1, 2 do
		K:brick("BoatSide", Vector3.new(0.3, 0.9, 4.4), boat * CFrame.new(k * 1.05, 0.55, 0), PLANK[1])
		K:wedge("BoatBow", Vector3.new(2.2, 1.2, 1.2), boat * CFrame.new(0, 0.3, k * 2.8) * CFrame.Angles(0, if k > 0 then 0 else math.pi, 0) * CFrame.Angles(0, 0, math.pi), PLANK[2])
	end
	K:brick("BoatSeat", Vector3.new(2, 0.25, 0.8), boat * CFrame.new(0, 0.6, 0), PLANK[1])
	K:brick("Oar", Vector3.new(0.25, 0.25, 5), boat * CFrame.new(0.5, 1.2, 0.6) * CFrame.Angles(math.rad(20), math.rad(15), 0), LOG[1], true)
	-- cattails and reeds
	for _, c in { { 7, -2, 5 }, { 8, -1, 6.4 }, { 6.4, -0.4, 4.6 }, { -8.6, 6, 5.4 }, { -9.4, 5, 4.4 }, { 8.6, 7, 5 } } do
		K:brick("Reed", Vector3.new(0.18, c[3], 0.18), CFrame.new(c[1], 1 + c[3] / 2, c[2]), C(80, 130, 60), true)
		K:brick("Cattail", Vector3.new(0.45, 1.1, 0.45), CFrame.new(c[1], 1 + c[3] - 0.4, c[2]), C(130, 76, 44), true)
	end
	for _, c in { { 7.6, -1.6 }, { -9, 5.4 } } do
		for k = -2, 2 do
			K:wedge("Grass", Vector3.new(0.2, 2.6, 0.8), CFrame.new(c[1] + k * 0.35, 2.3, c[2]) * CFrame.Angles(0, k * 0.5, 0), LEAF[(k + 3) % 3 + 1])
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- PINE: the lookout tower
-------------------------------------------------------------------------------------------------------------
local PINE = { C(46, 104, 70), C(36, 88, 60), C(56, 118, 80) }
local ROOF_G = { C(60, 98, 60), C(50, 84, 52) }

local function pine(K: Kit)
	local PY = 13 -- the platform
	-- the legs: four splayed logs on stone footings, rope-bound, X-braced on every side
	local feet = { { -3.8, -3.8 }, { 3.8, -3.8 }, { 3.8, 3.8 }, { -3.8, 3.8 } }
	local tops = { { -3, -3 }, { 3, -3 }, { 3, 3 }, { -3, 3 } }
	for i = 1, 4 do
		local a = Vector3.new(feet[i][1], 0.8, feet[i][2])
		local b = Vector3.new(tops[i][1], PY, tops[i][2])
		local mid = (a + b) / 2
		K:box("Footing", a.X - 0.9, 0, a.Z - 0.9, a.X + 0.9, 0.9, a.Z + 0.9, STONE[i % 2 + 1])
		K:brick("Leg", Vector3.new(0.9, (b - a).Magnitude, 0.9), CFrame.lookAt(mid, mid + (b - a)) * CFrame.Angles(math.pi / 2, 0, 0), LOG[1], true)
		for _, h in { 4.5, 9.5 } do
			local p = a:Lerp(b, (h - 0.8) / (PY - 0.8))
			K:cyl("Rope", 1.05, 0.45, p, ROPE)
		end
	end
	for i = 1, 4 do
		local j = i % 4 + 1
		for _, band in { { 1.4, 7 }, { 7, PY - 0.4 } } do
			local function at(k: number, h: number): Vector3
				local f = (h - 0.8) / (PY - 0.8)
				return Vector3.new(feet[k][1], 0.8, feet[k][2]):Lerp(Vector3.new(tops[k][1], PY, tops[k][2]), f)
			end
			for _, pair in { { at(i, band[1]), at(j, band[2]) }, { at(j, band[1]), at(i, band[2]) } } do
				local mid = (pair[1] + pair[2]) / 2
				local d = pair[2] - pair[1]
				K:brick("Brace", Vector3.new(0.45, d.Magnitude, 0.45), CFrame.lookAt(mid, mid + d) * CFrame.Angles(math.pi / 2, 0, 0), LOG[2], true)
			end
		end
	end
	-- the platform, its log ends sticking out
	for i = 0, 4 do
		local z0 = -5 + i * 2
		K:box("Platform", -5, PY, z0, 5, PY + 0.6, z0 + 2, PLANK[i % 2 + 1])
	end
	for _, s in { { -5.2, 0, X }, { 5.2, 0, X }, { 0, -5.2, Z }, { 0, 5.2, Z } } do
		local along = s[3] :: Vector3
		K:rod("BeamLog", 0.7, 11.4, CFrame.new(s[1], PY - 0.2, s[2]) * (if along == Z then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity), LOG[2])
	end
	-- the rail round its edge
	for _, p in { { -4.7, -4.7 }, { 4.7, -4.7 }, { 4.7, 4.7 }, { -4.7, 4.7 }, { -1.6, -4.7 }, { 1.6, -4.7 } } do
		K:rod("RailPost", 0.4, 1.8, CFrame.new(p[1], PY + 1.5, p[2]) * CFrame.Angles(0, 0, math.pi / 2), LOG[1])
	end
	for _, r in { { 0, -4.7, X, 9.4 }, { -4.7, 0, Z, 9.4 }, { 4.7, 0, Z, 9.4 } } do
		local along = r[3] :: Vector3
		K:rod("Rail", 0.32, r[4], CFrame.new(r[1], PY + 2.2, r[2]) * (if along == Z then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity), LOG[1])
	end
	-- the cabin: log walls (logs laid round it), two windows, its door at the back
	local c0, c1, TOP = -3.2, 3.2, PY + 4.6
	for k = 0, 7 do
		local y = PY + 0.6 + k * 0.5 + 0.25
		local col = LOG[k % 2 + 1]
		for _, s in { -1, 1 } do
			K:rod("WallLog", 0.55, 7.2, CFrame.new(0, y, s * c1) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), col)
			K:rod("WallLog", 0.55, 7.2, CFrame.new(s * c1, y, 0) * CFrame.Angles(0, math.pi / 2, 0), col)
		end
	end
	K:box("CabinCore", c0 + 0.2, PY + 0.6, c0 + 0.2, c1 - 0.2, TOP, c1 - 0.2, LOG[2])
	window(K, CFrame.new(-1.3, PY + 2.7, c0 - 0.3), 1.6, 1.4, C(40, 46, 56), LOG[2])
	window(K, CFrame.new(1.3, PY + 2.7, c0 - 0.3), 1.6, 1.4, C(40, 46, 56), LOG[2])
	window(K, CFrame.new(c0 - 0.3, PY + 2.7, 0) * CFrame.Angles(0, math.pi / 2, 0), 1.6, 1.4, C(40, 46, 56), LOG[2])
	-- the lantern on its right corner
	K:brick("LanternArm", Vector3.new(1.6, 0.35, 0.35), CFrame.new(-4.2, TOP - 0.6, -3.4), LOG[2])
	lantern(K, Vector3.new(-4.8, TOP - 1.8, -3.4), C(255, 196, 110))
	-- the green roof: a low stepped pyramid with an overhang, a second tier
	for k, half in { 6.4, 5.4, 4.4, 3.4, 2.3, 1.3 } do
		K:box("Roof", -half, TOP + (k - 1) * 0.45, -half, half, TOP + k * 0.45, half, ROOF_G[k % 2 + 1])
	end
	-- the eave's log ends at the corners
	for _, c in { { -6.2, -6.2 }, { 6.2, -6.2 }, { 6.2, 6.2 }, { -6.2, 6.2 } } do
		K:ball("RoofKnot", 0.6, Vector3.new(c[1], TOP + 0.2, c[2]), LOG[2])
	end
	-- the little pine on top: a trunk, four tiers of boughs, a tip
	local ty = TOP + 2.7
	K:brick("PineTrunk", Vector3.new(0.7, 2, 0.7), CFrame.new(0, ty + 0.6, 0), LOG[2])
	local tiers = { { 3.6, 1.4 }, { 2.9, 1.3 }, { 2.2, 1.2 }, { 1.4, 1.1 } }
	local y = ty + 1
	for i, t in tiers do
		K:dome("Bough", Vector3.zero, 8, t[1], t[1] * 0.45, y, y + t[2], 2, { PINE[i % 3 + 1], PINE[(i + 1) % 3 + 1] })
		y += t[2] * 0.75
	end
	K:brick("PineTip", Vector3.new(0.5, 1.2, 0.5), CFrame.new(0, y + 0.5, 0), PINE[3])
	-- the ladder up the front, mushrooms at the foot
	local lad = CFrame.new(0, PY / 2 + 0.3, -5.6) * CFrame.Angles(math.rad(-6), 0, 0)
	for k = -1, 1, 2 do
		K:brick("LadderRail", Vector3.new(0.3, PY + 1.2, 0.3), lad * CFrame.new(k * 0.8, 0, 0), LOG[1], true)
	end
	for yy = -PY / 2 + 0.8, PY / 2 - 0.2, 1 do
		K:brick("LadderRung", Vector3.new(1.6, 0.22, 0.22), lad * CFrame.new(0, yy, 0), LOG[2], true)
	end
	for _, m in { { -1.4, -2.6, 1 }, { -2.2, -2.2, 0.7 }, { 1.2, -1.8, 0.8 } } do
		K:cyl("MushroomStem", m[3] * 0.4, m[3] * 0.8, Vector3.new(m[1], m[3] * 0.4, m[2]), C(236, 226, 206))
		K:cyl("MushroomCap", m[3] * 1.1, m[3] * 0.35, Vector3.new(m[1], m[3] * 0.95, m[2]), C(206, 96, 50))
	end
end

-------------------------------------------------------------------------------------------------------------
local BUILDERS: { [string]: (Kit) -> () } = {
	wheat = wheat,
	swamp = swamp,
	pine = pine,
}

function StudIsles.has(kind: string): boolean
	return BUILDERS[kind] ~= nil
end

function StudIsles.build(kind: string, parent: Instance, pivot: CFrame): Model?
	local fn = BUILDERS[kind]
	if not fn then
		return nil
	end
	local K = StudKit.new("StudIsle_" .. kind, pivot)
	fn(K)
	return K:finish(parent)
end

return StudIsles
