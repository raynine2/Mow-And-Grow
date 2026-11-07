--!strict
-- STUD ISLES (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar ... super hoog kwaliteit", "Moet meer
-- accuraat zijn en donkerder", "Ga verder dan"). The seven landmarks on the lobby's floating isles (forge_lm_<kind>)
-- rebuilt from studded bricks (server/StudKit) to their own layouts, from pictures of each from its front:
--   wheat     a red gambrel barn with white trim, a silo with a blue dome and a ladder, a shed, hay bales, a scarecrow
--   swamp     a plank hut on stilts over a lily pond: a mossy roof, round windows, hanging green lanterns, a ladder,
--             a dock, a rowboat with an oar, cattails
--   pine      a log lookout tower: four braced legs on stones, a railed platform, a cabin, a green roof with a little
--             pine on top, a ladder, a lantern, mushrooms
--   frost     a snowy chalet: a steep snowy roof, a timber gable with a big glowing window and blue gems, a porch,
--             a chimney, ice crystals with skis leaning on them, snowy pines
--   ember     a forge in a dark stepped volcano: lava cracks and a crater, smoke, an arched furnace mouth with fire,
--             iron plates, a shield with a gold hammer, an anvil, a great glowing blade with a chain, bellows
--   blossom   an octagonal gazebo on a round cream plinth: columns, arches, a two-tier pink roof with upturned
--             tips, roses climbing, a little fountain in front with roses round it
--   starlight an observatory: a stepped blue-tiled base with stairs, star posts and crystal torches, a stone tower
--             with blue arched windows, banners and gold stars, a gold-railed deck, a ribbed blue dome open at the
--             front with a telescope, floating crystals
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
	local mats = { { -9, -6, 10, 12 }, { -6, -10, 9, -5 }, { 7, -4, 11, 8 }, { -11, 1, -8, 9 }, { -8, -8, -5, -5 }, { -10, -4, -8, 1 }, { 9, -7, 11, -4 }, { -6, 12, 7, 13.5 }, { 10, 8, 12, 11 } }
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
	-- the rowboat at the front-left: a hull pointed at both ends (two flat wedges each end, keel on the centre line),
	-- dark inside under the gunwale, a seat, an oar across it
	local boat = CFrame.new(-6.6, 1.45, -9.6) * CFrame.Angles(0, math.rad(-30), 0)
	local BH, HALF, BOW = 0.9, 1.1, 1.5
	K:brick("BoatHull", Vector3.new(HALF * 2, BH, 3), boat, PLANK[2])
	for _, e in { 1, -1 } do
		local endCf = boat * CFrame.Angles(0, if e > 0 then 0 else math.pi, 0) * CFrame.new(0, 0, -1.5 - BOW / 2)
		K:wedge("BoatBow", Vector3.new(BH, HALF, BOW), endCf * CFrame.new(-HALF / 2, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), PLANK[2])
		K:wedge("BoatBow", Vector3.new(BH, HALF, BOW), endCf * CFrame.new(HALF / 2, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2), PLANK[2])
	end
	K:brick("BoatInside", Vector3.new(HALF * 2 - 0.5, 0.1, 2.8), boat * CFrame.new(0, BH / 2 + 0.01, 0), C(70, 46, 30), true)
	K:brick("BoatGunwale", Vector3.new(HALF * 2 + 0.1, 0.18, 3.1), boat * CFrame.new(0, BH / 2 - 0.25, 0), PLANK[1], true)
	K:brick("BoatSeat", Vector3.new(HALF * 2 - 0.2, 0.22, 0.7), boat * CFrame.new(0, BH / 2 + 0.05, 0.3), PLANK[1], true)
	K:brick("Oar", Vector3.new(0.22, 0.22, 4.6), boat * CFrame.new(0.4, BH / 2 + 0.3, -0.2) * CFrame.Angles(math.rad(8), math.rad(18), 0), LOG[1], true)
	K:brick("OarBlade", Vector3.new(0.6, 0.12, 1.1), boat * CFrame.new(0.4, BH / 2 + 0.3, -0.2) * CFrame.Angles(math.rad(8), math.rad(18), 0) * CFrame.new(0, 0, 2.6), LOG[1], true)
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
	for _, s in { { -5.2, 0, Z }, { 5.2, 0, Z }, { 0, -5.2, X }, { 0, 5.2, X } } do
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
	lantern(K, Vector3.new(-4.8, TOP - 1.8, -3.4), C(236, 150, 70), TOP - 0.6)
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
	local tiers = { { 3.8, 1.4 }, { 3, 1.3 }, { 2.2, 1.2 }, { 1.4, 1.1 } }
	local y = ty + 0.2
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
-- shared bits for the next four
-------------------------------------------------------------------------------------------------------------
-- a crystal: a tall block with a ridged tip, standing on `base` (its bottom middle, tilted as given)
local function crystal(K: Kit, base: CFrame, w: number, h: number, col: Color3, hi: Color3)
	K:brick("Crystal", Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0), col, true)
	K:prism("CrystalTip", base * CFrame.new(0, h, 0), w, w, w * 1.1, col)
	K:brick("CrystalShine", Vector3.new(w * 0.25, h * 0.7, 0.1), base * CFrame.new(-w * 0.2, h * 0.55, -w / 2 - 0.02), hi, true)
end

-- a snowy little pine: a trunk and three stepped tiers, white caps on each
local function snowPine(K: Kit, at: Vector3, s: number)
	K:brick("PineTrunk", Vector3.new(0.5 * s, 1.2 * s, 0.5 * s), CFrame.new(at + Vector3.new(0, 0.6 * s, 0)), LOG[2])
	local y = at.Y + 1 * s
	for i, r in { 1.7, 1.3, 0.9, 0.5 } do
		K:dome("Bough", Vector3.new(at.X, 0, at.Z), 8, r * s, r * s * 0.5, y, y + 1.1 * s, 2, { PINE[i % 3 + 1], PINE[(i + 1) % 3 + 1] })
		K:ring("Snow", Vector3.new(at.X, 0, at.Z), 8, r * s * 0.6, y + 1.05 * s, 0.25 * s, r * s * 0.6, { C(238, 244, 252) })
		y += 0.85 * s
	end
end

-------------------------------------------------------------------------------------------------------------
-- FROST: the snowy chalet
-------------------------------------------------------------------------------------------------------------
local SNOW = { C(238, 244, 252), C(218, 230, 244) }
local TIMBER = { C(78, 48, 34), C(64, 40, 28) }
local PLASTER = C(232, 222, 200)
local ICE = C(96, 176, 246)
local ICE_HI = C(196, 236, 255)
local AMBER = C(255, 186, 96)
local GEM = C(70, 160, 255)

local function frost(K: Kit)
	-- the snow mat it stands on, a little uneven
	for i, r in { { -9, -7, 9, 8 }, { -7, -9.5, 7, -7 }, { -10.5, -4, -9, 6 }, { 9, -5, 10.5, 5 }, { -6, 8, 6, 9.5 } } do
		K:box("SnowMat", r[1], 0, r[2], r[3], 0.8, r[4], SNOW[i % 2 + 1])
	end
	-- the chalet: stone footing, dark timber frame, plaster between
	local x0, x1, z0, z1, B, TOP = -4.6, 5.4, -4, 7, 0.8, 7.4
	local cx = (x0 + x1) / 2
	K:box("Footing", x0 - 0.3, B, z0 - 0.3, x1 + 0.3, B + 1.2, z1 + 0.3, STONE[2])
	K:box("Walls", x0, B + 1.2, z0, x1, TOP, z1, PLASTER)
	for _, x in { x0, (x0 + cx) / 2 - 0.5, (cx + x1) / 2 + 0.5, x1 } do
		K:box("Timber", x - 0.35, B + 1.2, z0 - 0.3, x + 0.35, TOP, z0 + 0.1, TIMBER[1])
	end
	K:box("Timber", x0 - 0.3, TOP - 0.6, z0 - 0.35, x1 + 0.3, TOP, z0 + 0.1, TIMBER[2])
	K:box("Timber", x0 - 0.3, B + 3.6, z0 - 0.3, x1 + 0.3, B + 4.1, z0 + 0.1, TIMBER[2])
	-- the steep roof, snow on it, its gable: plaster crossed by timber, the big glowing window, the blue gems
	local RIDGE = TOP + 9.6
	local half = (x1 - x0) / 2
	K:prism("Gable", CFrame.new(cx, TOP, (z0 + z1) / 2) * CFrame.Angles(0, math.pi / 2, 0), z1 - z0, x1 - x0, RIDGE - TOP, PLASTER)
	local pitch = (RIDGE - TOP) / half
	for s = -1, 1, 2 do
		K:slope(Vector3.new(cx + s * (half + 1.4), TOP - 1.4 * pitch, (z0 + z1) / 2), Z, -s * X, RIDGE - TOP + 1.4 * pitch, half + 1.4, -(z1 - z0) / 2 - 1.2, (z1 - z0) / 2 + 0.6, SNOW[1], SNOW[2], TIMBER[1])
	end
	K:box("RidgeSnow", cx - 0.7, RIDGE - 0.2, z0 - 1.2, cx + 0.7, RIDGE + 0.6, z1 + 0.6, SNOW[1], true)
	-- the gable's timber: a king post, two braces
	K:box("Timber", cx - 0.3, TOP, z0 - 0.35, cx + 0.3, RIDGE - 1.2, z0 - 0.05, TIMBER[1])
	for s = -1, 1, 2 do
		local a = Vector3.new(cx + s * (half - 0.8), TOP + 0.3, z0 - 0.2)
		local b = Vector3.new(cx + s * 0.4, TOP + 6, z0 - 0.2)
		local mid = (a + b) / 2
		local d = b - a
		K:brick("Timber", Vector3.new(d.Magnitude, 0.5, 0.3), CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), TIMBER[1], true)
	end
	-- the big window in the gable, glowing warm, in a timber frame with mullions
	local wcf = CFrame.new(cx, TOP + 2.8, z0 - 0.25)
	K:glow("WindowGlow", Vector3.new(3, 3.4, 0.2), wcf, AMBER, 12)
	for k = -1, 1, 2 do
		K:brick("WindowFrame", Vector3.new(0.4, 3.8, 0.4), wcf * CFrame.new(k * 1.7, 0, -0.15), TIMBER[1])
	end
	K:brick("WindowFrame", Vector3.new(3.8, 0.4, 0.4), wcf * CFrame.new(0, 1.9, -0.15), TIMBER[1])
	K:brick("WindowFrame", Vector3.new(3.8, 0.4, 0.4), wcf * CFrame.new(0, -1.9, -0.15), TIMBER[1])
	K:brick("Mullion", Vector3.new(0.25, 3.4, 0.3), wcf * CFrame.new(0, 0, -0.15), TIMBER[2], true)
	K:brick("Mullion", Vector3.new(3, 0.25, 0.3), wcf * CFrame.new(0, 0.3, -0.15), TIMBER[2], true)
	-- the blue gems: one over the window, one at the peak
	for _, gy in { TOP + 5.4, RIDGE - 1.8 } do
		K:glow("Gem", Vector3.new(0.9, 0.9, 0.3), CFrame.new(cx, gy, z0 - 0.4) * CFrame.Angles(0, 0, math.rad(45)), GEM, 6)
		K:brick("GemSetting", Vector3.new(1.3, 1.3, 0.2), CFrame.new(cx, gy, z0 - 0.28) * CFrame.Angles(0, 0, math.rad(45)), TIMBER[1], true)
	end
	-- the porch: a little snowy gable on two posts over the door, the door, steps, stone pillars with snow caps
	local pz = z0 - 3.4
	for _, x in { cx - 2.2, cx + 2.2 } do
		K:box("PorchPost", x - 0.35, B, pz - 0.35, x + 0.35, B + 4.6, pz + 0.35, TIMBER[1])
	end
	K:box("PorchBeam", cx - 2.6, B + 4.6, pz - 0.4, cx + 2.6, B + 5.1, z0, TIMBER[2])
	K:prism("PorchGable", CFrame.new(cx, B + 5.1, (pz + z0) / 2) * CFrame.Angles(0, math.pi / 2, 0), z0 - pz + 0.4, 5.2, 2.2, PLASTER)
	for s = -1, 1, 2 do
		K:slope(Vector3.new(cx + s * 3.3, B + 5.1 - 0.7 * (2.2 / 2.6), (pz + z0) / 2), Z, -s * X, 2.2 + 0.7 * (2.2 / 2.6), 3.3, -(z0 - pz) / 2 - 0.8, (z0 - pz) / 2 + 0.2, SNOW[1], SNOW[2], TIMBER[1])
	end
	local door = CFrame.new(cx, B + 2.3, z0 - 0.15)
	K:brick("Door", Vector3.new(2.4, 3.8, 0.25), door, TIMBER[2])
	K:brick("DoorPlank", Vector3.new(0.15, 3.6, 0.1), door * CFrame.new(-0.4, 0, -0.15), TIMBER[1], true)
	K:brick("DoorPlank", Vector3.new(0.15, 3.6, 0.1), door * CFrame.new(0.4, 0, -0.15), TIMBER[1], true)
	K:ball("DoorKnob", 0.3, door * CFrame.new(0.8, 0, -0.25), C(212, 170, 76))
	for i = 0, 2 do
		K:box("Step", cx - 1.6, B + i * 0.4 - 0.4, pz - 1.4 - (2 - i) * 0.9, cx + 1.6, B + i * 0.4, pz - 1.4 - (1 - i) * 0.9, TIMBER[(i % 2) + 1])
	end
	for _, x in { cx - 2.6, cx + 2.6 } do
		K:box("Pillar", x - 0.7, B, pz - 2.8, x + 0.7, B + 1.6, pz - 1.4, STONE[1])
		K:box("PillarSnow", x - 0.8, B + 1.6, pz - 2.9, x + 0.8, B + 1.95, pz - 1.3, SNOW[1], true)
	end
	-- the chimney on the left slope, a lantern by the door
	K:box("Chimney", x1 - 2.6, TOP + 2, 3, x1 - 1, RIDGE + 1.4, 4.6, STONE[1])
	K:box("ChimneyCap", x1 - 2.8, RIDGE + 1.4, 2.8, x1 - 0.8, RIDGE + 1.8, 4.8, TIMBER[2])
	K:box("ChimneySnow", x1 - 2.8, RIDGE + 1.8, 2.8, x1 - 0.8, RIDGE + 2.1, 4.8, SNOW[1], true)
	lantern(K, Vector3.new(cx - 2.2, B + 3.6, pz - 0.6), AMBER, B + 4.6)
	-- the ice crystals on the left front, skis leaning on them
	local ic = CFrame.new(x1 + 2.4, B, -2)
	crystal(K, ic * CFrame.Angles(math.rad(-6), 0, math.rad(-4)), 1.8, 11, ICE, ICE_HI)
	crystal(K, ic * CFrame.new(1.4, 0, 0.6) * CFrame.Angles(math.rad(4), 0, math.rad(-14)), 1.3, 8, ICE, ICE_HI)
	crystal(K, ic * CFrame.new(-1, 0, 0.9) * CFrame.Angles(math.rad(-4), 0, math.rad(12)), 1.2, 7, ICE, ICE_HI)
	crystal(K, ic * CFrame.new(0.6, 0, -1.2) * CFrame.Angles(math.rad(-16), 0, math.rad(-8)), 1, 5, ICE, ICE_HI)
	crystal(K, ic * CFrame.new(-0.3, 0, 2) * CFrame.Angles(math.rad(10), 0, math.rad(4)), 1.1, 9, ICE, ICE_HI)
	for k = 0, 1 do
		local ski = CFrame.new(x1 + 1 + k * 0.8, B + 2.4, -4.4) * CFrame.Angles(math.rad(-14), 0, math.rad(-6 + k * 4))
		K:brick("Ski", Vector3.new(0.5, 4.8, 0.2), ski, C(60, 120, 200), true)
		K:brick("SkiTip", Vector3.new(0.5, 0.6, 0.2), ski * CFrame.new(0, 2.6, -0.2) * CFrame.Angles(math.rad(-30), 0, 0), C(60, 120, 200), true)
	end
	K:box("SnowPile", x1 + 0.4, B, -5.2, x1 + 2.6, B + 0.8, -3.8, SNOW[1])
	-- snowy pines on the right front
	snowPine(K, Vector3.new(x0 - 2.4, B, -2.6), 1.6)
	snowPine(K, Vector3.new(x0 - 3.6, B, 0.4), 1.1)
end

-------------------------------------------------------------------------------------------------------------
-- EMBER: the forge in the volcano
-------------------------------------------------------------------------------------------------------------
local ROCK = { C(56, 50, 56), C(70, 62, 68), C(46, 42, 48) }
local LAVA = C(255, 112, 32)
local IRON = { C(74, 76, 86), C(58, 60, 70) }
local RIVET = C(150, 150, 160)
local BRASS = C(222, 170, 60)

local function ember(K: Kit)
	-- the stepped dark base
	K:ring("Base", Vector3.zero, 12, 11.5, 0, 0.9, 3, { ROCK[3], ROCK[1] })
	K:cyl("BaseCore", 18, 0.9, Vector3.new(0, 0.45, 0), ROCK[3])
	-- the mound: a stepped cone of dark rock, a crater with lava, smoke over it
	K:dome("Mound", Vector3.new(0, 0, 1.5), 12, 9.4, 2.4, 0.9, 17.5, 12, ROCK, false)
	K:glow("Crater", Vector3.new(3.6, 0.3, 3.6), CFrame.new(0, 17.4, 1.5), LAVA, 14)
	for i, p in { { 0, 19.4, 1.5, 3.2 }, { 1.2, 21.4, 1.1, 2.6 }, { -0.8, 22.8, 1.9, 2.2 }, { 0.6, 24.4, 1.4, 1.6 } } do
		local puff = K:ball("Smoke", p[4], Vector3.new(p[1], p[2], p[3]), if i % 2 == 0 then C(220, 220, 226) else C(196, 196, 204))
		puff.CanCollide = false
	end
	-- lava running down its face in cracks
	for _, run in { { -30, 15, 4 }, { 25, 14.5, 3 }, { -70, 12, 2 }, { 75, 13, 1.5 }, { 160, 14, 3 } } do
		local ang = math.rad(run[1])
		local function at(y: number): Vector3
			local r = 9.4 + (2.4 - 9.4) * ((y - 0.9) / (17.5 - 0.9)) + 0.25
			return Vector3.new(math.sin(ang) * r, y, 1.5 - math.cos(ang) * r)
		end
		local a, b = at(run[3]), at(run[2])
		local mid = (a + b) / 2
		local d = b - a
		K:glow("Lava", Vector3.new(0.35, d.Magnitude, 0.3), CFrame.lookAt(mid, mid + d) * CFrame.Angles(math.pi / 2, 0, 0), LAVA)
	end
	-- the furnace front: a stone face with an arched mouth, fire in it, iron plates either side
	local fz = -7.4
	K:box("FurnaceFace", -4.6, 0.9, fz, 4.6, 10.4, fz + 3, ROCK[2])
	K:box("FurnaceMouth", -1.8, 0.9, fz - 0.05, 1.8, 5.6, fz + 1.6, C(30, 22, 22))
	K:glow("Fire", Vector3.new(3, 2.2, 0.4), CFrame.new(0, 2.2, fz + 1.2), LAVA, 16)
	K:glow("FireGlow", Vector3.new(2.2, 1.2, 0.3), CFrame.new(0, 3.6, fz + 1.3), C(255, 170, 70))
	-- the arch: stepped stones over the mouth
	for k, st in { { 2.2, 5.6 }, { 1.7, 6.3 }, { 1, 6.9 } } do
		K:box("Arch", -st[1] - 0.8, st[2] - 0.7, fz - 0.4, -st[1] + 0.4, st[2], fz + 0.4, ROCK[k % 2 + 1])
		K:box("Arch", st[1] - 0.4, st[2] - 0.7, fz - 0.4, st[1] + 0.8, st[2], fz + 0.4, ROCK[k % 2 + 1])
	end
	K:box("Keystone", -0.7, 6.4, fz - 0.5, 0.7, 7.6, fz + 0.4, ROCK[2])
	for s = -1, 1, 2 do
		local plate = CFrame.new(s * 3.3, 4.4, fz - 0.35)
		K:brick("IronPlate", Vector3.new(1.6, 6.8, 0.4), plate, IRON[1])
		for _, y in { -2.8, 2.8 } do
			K:ball("Rivet", 0.35, plate * CFrame.new(0, y, -0.25), RIVET)
		end
	end
	-- the shield over the mouth with a gold hammer on it
	local sh = CFrame.new(0, 9, fz - 0.5)
	K:brick("Shield", Vector3.new(2.8, 2.2, 0.4), sh, IRON[1])
	K:wedge("ShieldTip", Vector3.new(2.8, 1, 0.4), sh * CFrame.new(0, -1.6, 0) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, 0, 0), IRON[1])
	K:brick("ShieldRim", Vector3.new(3.2, 0.35, 0.5), sh * CFrame.new(0, 1.2, 0), IRON[2])
	K:brick("Hammer", Vector3.new(0.35, 2, 0.2), sh * CFrame.new(0, -0.2, -0.3), BRASS, true)
	K:brick("HammerHead", Vector3.new(1.4, 0.7, 0.3), sh * CFrame.new(0, 0.7, -0.35), BRASS, true)
	-- steps up to the mouth
	for i = 0, 1 do
		K:box("Step", -2.4, 0.9 + i * 0.5 - 0.5, fz - 2.2 + i * 0.9, 2.4, 0.9 + i * 0.5, fz - 1.3 + i * 0.9, ROCK[i + 1])
	end
	-- the anvil on its block, front left
	local an = CFrame.new(3.6, 0.9, fz - 3) * CFrame.Angles(0, math.rad(-10), 0)
	K:brick("AnvilBlock", Vector3.new(2.2, 1.4, 1.8), an * CFrame.new(0, 0.7, 0), ROCK[2])
	K:brick("AnvilFoot", Vector3.new(1.6, 0.5, 1.2), an * CFrame.new(0, 1.65, 0), IRON[2], true)
	K:brick("AnvilWaist", Vector3.new(0.9, 0.7, 0.8), an * CFrame.new(0, 2.25, 0), IRON[2], true)
	K:brick("AnvilTop", Vector3.new(2.2, 0.6, 1.1), an * CFrame.new(0.1, 2.9, 0), IRON[1], true)
	K:wedge("AnvilHorn", Vector3.new(1.1, 0.6, 1.2), an * CFrame.new(-1.6, 2.9, 0) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(0, 0, 0), IRON[1], true)
	-- the great blade on the right, its edge glowing, a chain from it
	local bl = CFrame.new(-6.2, 0.9, fz + 1.6) * CFrame.Angles(0, math.rad(15), math.rad(-8))
	K:brick("BladePost", Vector3.new(1, 3.4, 1), bl * CFrame.new(0, 1.7, 0.6), LOG[1])
	K:brick("BladeGuard", Vector3.new(2.6, 0.6, 1.2), bl * CFrame.new(0, 3.6, 0), IRON[2])
	K:brick("BladeGrip", Vector3.new(0.7, 1.6, 0.7), bl * CFrame.new(0, 2.5, 0), C(80, 50, 34))
	local seg = { { 0, 4, 2.4, 3.2, 0 }, { 0.3, 6.9, 2.6, 3, -8 }, { 0.9, 9.6, 2.6, 2.8, -18 }, { 1.8, 11.9, 2.2, 2.2, -32 } }
	for i, b in seg do
		local cf = bl * CFrame.new(-b[1], b[2], 0) * CFrame.Angles(0, 0, math.rad(b[5]))
		K:brick("Blade", Vector3.new(b[3], b[4], 0.45), cf, IRON[(i % 2) + 1], true)
		K:glow("BladeEdge", Vector3.new(0.3, b[4] + 0.2, 0.5), cf * CFrame.new(-b[3] / 2 - 0.1, 0, 0), LAVA)
	end
	for i = 0, 5 do
		local p = Vector3.new(-5.2 + i * 1, 3.4 - math.sin(i / 5 * math.pi) * 1.6, fz - 0.7)
		K:brick("Chain", Vector3.new(0.7, 0.35, 0.35), CFrame.new(p) * CFrame.Angles(i % 2 * math.pi / 2, 0, 0), IRON[2], true)
	end
	-- the bellows on the left, leather on wood, iron bands, its nozzle
	local bw = CFrame.new(6.8, 2.8, fz + 2.2) * CFrame.Angles(0, math.rad(-30), math.rad(80))
	K:rod("Bellows", 3.6, 2.4, bw, C(120, 72, 44))
	for k = -1, 1, 2 do
		K:rod("BellowsBand", 3.8, 0.3, bw * CFrame.new(k * 0.9, 0, 0), IRON[2])
	end
	K:rod("Nozzle", 0.7, 2.4, CFrame.new(6.2, 1.4, fz + 0.6) * CFrame.Angles(0, math.rad(60), 0), IRON[1])
	-- a beam leaning on the left of the face
	K:brick("Beam", Vector3.new(1, 6.5, 1), CFrame.new(5.4, 4.6, fz + 0.6) * CFrame.Angles(0, 0, math.rad(8)), LOG[1])
	K:brick("BeamBand", Vector3.new(1.15, 0.35, 1.15), CFrame.new(5.6, 6.6, fz + 0.6) * CFrame.Angles(0, 0, math.rad(8)), IRON[2], true)
end

-------------------------------------------------------------------------------------------------------------
-- BLOSSOM: the gazebo
-------------------------------------------------------------------------------------------------------------
local CREAM = { C(232, 220, 196), C(214, 200, 174) }
local PINK = { C(214, 70, 108), C(190, 56, 92) }
local ROSE_RED = { C(220, 40, 70), C(250, 110, 140), C(196, 30, 56) }
local WATER = C(70, 160, 230)

local function roses(K: Kit, at: Vector3, h: number, r: number)
	for k = 0, math.floor(h / 0.9) do
		local a = k * 1.9
		local p = at + Vector3.new(math.cos(a) * r, k * 0.9 + 0.4, math.sin(a) * r)
		K:brick("RoseLeaves", Vector3.new(0.8, 0.7, 0.8), CFrame.new(p) * CFrame.Angles(0, a, 0), LEAF[k % 2 + 1])
		K:ball("Rose", 0.5, p + Vector3.new(math.cos(a) * 0.35, 0.25, math.sin(a) * 0.35), ROSE_RED[k % 3 + 1])
	end
end

local function blossom(K: Kit)
	local c = Vector3.new(0, 0, 3)
	-- the round plinth in two cream tiers, steps down at the front
	K:ring("Plinth", c, 12, 7.6, 0, 0.8, 2, CREAM)
	K:ring("Plinth", c, 12, 6.8, 0.8, 0.8, 2, { CREAM[2], CREAM[1] })
	K:cyl("PlinthCore", 12, 1.6, c + Vector3.new(0, 0.8, 0), CREAM[2])
	K:cyl("Floor", 12.4, 0.2, c + Vector3.new(0, 1.7, 0), C(150, 104, 70))
	for i = 0, 1 do
		K:box("Step", -2.2, i * 0.8, c.Z - 8.6 + i * 0.9, 2.2, (i + 1) * 0.8, c.Z - 7.4 + i * 0.4, CREAM[i + 1])
	end
	for s = -1, 1, 2 do
		K:box("StepWall", s * 2.2 - 0.4, 0, c.Z - 8.7, s * 2.2 + 0.4, 2.3, c.Z - 6.2, CREAM[1])
		K:ball("StepBall", 0.7, Vector3.new(s * 2.2, 2.6, c.Z - 8.3), CREAM[1])
	end
	-- eight columns, arches between their tops, a low rail (open at the front)
	local R, CTOP = 5.2, 9.2
	for i = 0, 7 do
		local a = (i + 0.5) * math.pi / 4
		local p = c + Vector3.new(math.sin(a) * R, 0, -math.cos(a) * R)
		K:box("ColumnBase", p.X - 0.55, 1.8, p.Z - 0.55, p.X + 0.55, 2.4, p.Z + 0.55, CREAM[2])
		K:cyl("Column", 0.75, CTOP - 2.4, p + Vector3.new(0, (2.4 + CTOP) / 2, 0), CREAM[1])
		K:box("ColumnCap", p.X - 0.6, CTOP, p.Z - 0.6, p.X + 0.6, CTOP + 0.5, p.Z + 0.6, CREAM[2])
		if i ~= 7 and i ~= 0 then
			-- the rail between this column and the next (not across the entrance)
			local a2 = (i + 1.5) * math.pi / 4
			local q = c + Vector3.new(math.sin(a2) * R, 0, -math.cos(a2) * R)
			if i ~= 7 then
				local mid = (p + q) / 2
				local d = q - p
				K:brick("Rail", Vector3.new(d.Magnitude - 0.7, 0.35, 0.35), CFrame.lookAt(mid + Vector3.new(0, 3.6, 0), mid + Vector3.new(0, 3.6, 0) + d) * CFrame.Angles(0, math.pi / 2, 0), CREAM[1], true)
			end
		end
	end
	K:ring("Arches", c, 8, R + 0.45, CTOP + 0.5, 0.9, 0.9, CREAM)
	K:ring("ArchTrim", c, 8, R + 0.55, CTOP + 1.4, 0.3, 1, { C(222, 186, 110) }, nil, true)
	-- the roof: a wide pink tier with upturned corners, a smaller one on top, a gold finial
	local y0 = CTOP + 1.7
	K:dome("Roof", c, 8, R + 2.2, R * 0.55, y0, y0 + 2.6, 4, PINK, false)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local tip = c + Vector3.new(math.sin(a) * (R + 2.7), y0 + 0.4, -math.cos(a) * (R + 2.7))
		K:wedge("RoofTip", Vector3.new(0.8, 0.9, 1.2), CFrame.lookAt(tip, tip + Vector3.new(math.sin(a), 0, -math.cos(a))) * CFrame.Angles(0, math.pi, 0), PINK[2], true)
		K:ball("RoofTipBall", 0.4, tip + Vector3.new(math.sin(a) * 0.5, 0.6, -math.cos(a) * 0.5), C(222, 186, 110))
	end
	K:cyl("RoofBand", R * 1.3, 0.8, c + Vector3.new(0, y0 + 3, 0), CREAM[1])
	K:dome("RoofTop", c, 8, R * 0.85, 0.5, y0 + 3.4, y0 + 5.6, 4, PINK, false)
	K:cyl("FinialBase", 0.7, 0.6, c + Vector3.new(0, y0 + 5.9, 0), C(222, 186, 110))
	K:ball("Finial", 0.9, c + Vector3.new(0, y0 + 6.6, 0), C(222, 186, 110))
	-- roses climbing the front columns, bushes round the plinth
	for _, i in { 0, 7, 1, 6 } do
		local a = (i + 0.5) * math.pi / 4
		roses(K, c + Vector3.new(math.sin(a) * R, 1.8, -math.cos(a) * R), CTOP - 2.4, 0.55)
	end
	for _, b in { { -6.8, -2.8 }, { 6.6, -2.4 }, { -7.2, 4 }, { 7, 6 } } do
		K:box("Bush", b[1] - 0.9, 0, b[2] - 0.9, b[1] + 0.9, 1.4, b[2] + 0.9, LEAF[1])
		for k = 0, 2 do
			K:ball("Rose", 0.5, Vector3.new(b[1] - 0.5 + k * 0.5, 1.5, b[2] - 0.9), ROSE_RED[k + 1])
		end
	end
	-- the little fountain in front, on its own round step, roses round it
	local f = Vector3.new(1.4, 0, -9.6)
	K:ring("FountainStep", f, 12, 3.6, 0, 0.5, 1, CREAM)
	K:cyl("FountainStepCore", 6.4, 0.5, f + Vector3.new(0, 0.25, 0), CREAM[2])
	K:ring("Basin", f, 12, 2.6, 0.5, 1, 0.6, { C(240, 236, 228) })
	K:cyl("Water", 4.2, 0.2, f + Vector3.new(0, 1.2, 0), WATER)
	K:cyl("Spout", 0.8, 2, f + Vector3.new(0, 2, 0), C(240, 236, 228))
	K:cyl("Bowl", 1.8, 0.4, f + Vector3.new(0, 2.9, 0), C(240, 236, 228))
	K:cyl("BowlWater", 1.4, 0.15, f + Vector3.new(0, 3.1, 0), WATER)
	K:cyl("Jet", 0.4, 1.4, f + Vector3.new(0, 3.8, 0), C(190, 230, 255))
	for k = 0, 9 do
		local a = k * math.pi / 5
		local p = f + Vector3.new(math.cos(a) * 3.3, 0.7, math.sin(a) * 3.3)
		K:brick("RoseLeaves", Vector3.new(0.7, 0.5, 0.7), CFrame.new(p), LEAF[k % 2 + 1])
		K:ball("Rose", 0.45, p + Vector3.new(0, 0.35, 0), ROSE_RED[k % 3 + 1])
	end
end

-------------------------------------------------------------------------------------------------------------
-- STARLIGHT: the observatory
-------------------------------------------------------------------------------------------------------------
local WALLSTONE = { C(206, 204, 210), C(186, 184, 192) }
local BLUE = { C(44, 64, 158), C(34, 52, 130) }
local GOLDEN = { C(226, 178, 64), C(204, 156, 48) }
local SKYGEM = C(110, 180, 255)

-- a five-point star (two thin boxes crossed twice, a ball) facing out along `cf`'s -Z
local function star(K: Kit, cf: CFrame, s: number)
	for k = 0, 4 do
		K:wedge("Star", Vector3.new(0.25 * s, 1.1 * s, 0.6 * s), cf * CFrame.Angles(0, 0, k * math.pi * 2 / 5) * CFrame.new(0, 0.55 * s, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), GOLDEN[1], true)
	end
	K:ball("StarHeart", 0.6 * s, cf, GOLDEN[2])
end

local function starlight(K: Kit)
	local c = Vector3.zero
	-- the two stepped base tiers in blue tiles with a stone edge, stairs at the front
	K:ring("BaseEdge", c, 16, 15, 0, 2, 2, WALLSTONE)
	K:cyl("BaseCore", 27, 2, Vector3.new(0, 1, 0), BLUE[2])
	K:cyl("BaseTop", 27.2, 0.2, Vector3.new(0, 2.05, 0), BLUE[1])
	K:ring("Tier", c, 16, 12.2, 2, 2.4, 2, WALLSTONE)
	K:cyl("TierCore", 21, 2.4, Vector3.new(0, 3.2, 0), WALLSTONE[2])
	for i = 0, 3 do
		K:box("Stair", -3.4, i * 1.1, -15.8 + i * 1.2, 3.4, (i + 1) * 1.1, -11.6, WALLSTONE[i % 2 + 1])
	end
	for s = -1, 1, 2 do
		K:box("StairWall", s * 3.4 - 0.8, 0, -16, s * 3.4 + 0.8, 4.8, -11.6, WALLSTONE[1])
		star(K, CFrame.new(s * 3.4, 6, -15.2), 1.1)
		-- blue crystal torches on gold stands either side
		local t = Vector3.new(s * 6.6, 4.4, -10.6)
		K:cyl("TorchStand", 0.5, 2.4, t + Vector3.new(0, 1.2, 0), GOLDEN[2])
		K:cyl("TorchBowl", 1.3, 0.5, t + Vector3.new(0, 2.6, 0), GOLDEN[1])
		K:glow("TorchCrystal", Vector3.new(0.6, 1.4, 0.6), CFrame.new(t + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, math.rad(45), 0), SKYGEM, 8)
	end
	-- the tower: stone courses, a gold band, blue arched windows, the door with its star
	local R, T0, T1 = 9, 4.4, 22
	for k = 0, math.floor((T1 - T0) / 1.5) - 1 do
		K:ring("Tower", c, 16, R, T0 + k * 1.5, 1.5, 1.6, if k % 2 == 0 then WALLSTONE else { WALLSTONE[2], WALLSTONE[1] })
	end
	K:cyl("TowerCore", (R - 1.4) * 2, T1 - T0, Vector3.new(0, (T0 + T1) / 2, 0), WALLSTONE[2])
	K:ring("GoldBand", c, 16, R + 0.25, 15.6, 0.6, 0.8, GOLDEN, nil, true)
	K:ring("Cornice", c, 16, R + 0.7, T1 - 0.2, 1, 1.6, WALLSTONE)
	local function arched(cf: CFrame, w: number, h: number, isDoor: boolean)
		K:brick("Opening", Vector3.new(w, h, 0.3), cf, if isDoor then BLUE[2] else BLUE[1], true)
		K:brick("OpeningTop", Vector3.new(w * 0.65, 0.8, 0.3), cf * CFrame.new(0, h / 2 + 0.4, 0), if isDoor then BLUE[2] else BLUE[1], true)
		for k = -1, 1, 2 do
			K:brick("Frame", Vector3.new(0.4, h, 0.4), cf * CFrame.new(k * (w / 2 + 0.2), 0, -0.1), GOLDEN[1], true)
			K:brick("Frame", Vector3.new(w * 0.35, 0.4, 0.4), cf * CFrame.new(k * w * 0.36, h / 2 + 0.2, -0.1), GOLDEN[1], true)
		end
		K:brick("Frame", Vector3.new(w * 0.7, 0.4, 0.4), cf * CFrame.new(0, h / 2 + 1, -0.1), GOLDEN[1], true)
	end
	local function onWall(ang: number, y: number): CFrame
		return CFrame.Angles(0, math.rad(ang), 0) * CFrame.new(0, y, -(R + 0.1))
	end
	arched(onWall(0, T0 + 2.6), 3, 5.2, true)
	star(K, onWall(0, T0 + 3.2) * CFrame.new(0, 0, -0.35), 0.8)
	for _, a in { -55, 55, 125, -125, 180 } do
		arched(onWall(a, T0 + 6), 1.8, 3.6, false)
	end
	for _, a in { -25, 25 } do
		arched(onWall(a, 13.4), 1.6, 3, false)
	end
	star(K, onWall(0, 18.2) * CFrame.new(0, 0, -0.4), 1.6)
	for _, a in { -40, 40, 140, -140 } do
		star(K, onWall(a, 18.6) * CFrame.new(0, 0, -0.4), 0.8)
	end
	-- blue banners with gold trim, and the swags between them
	for _, a in { -55, 55 } do
		local b = onWall(a, 16.2)
		K:brick("Banner", Vector3.new(1.6, 4.4, 0.2), b * CFrame.new(0, 0, -0.3), BLUE[2], true)
		K:brick("BannerTrim", Vector3.new(1.8, 0.3, 0.25), b * CFrame.new(0, 2.2, -0.35), GOLDEN[1], true)
		K:wedge("BannerTail", Vector3.new(0.2, 0.9, 0.8), b * CFrame.new(-0.4, -2.6, -0.3) * CFrame.Angles(0, math.pi / 2, math.pi), BLUE[2], true)
		K:wedge("BannerTail", Vector3.new(0.2, 0.9, 0.8), b * CFrame.new(0.4, -2.6, -0.3) * CFrame.Angles(0, -math.pi / 2, math.pi), BLUE[2], true)
		star(K, b * CFrame.new(0, 0.6, -0.45), 0.5)
	end
	for _, a in { -28, 28 } do
		K:brick("Swag", Vector3.new(4.6, 1, 0.3), onWall(a, 17.6) * CFrame.new(0, 0, -0.3), BLUE[1], true)
	end
	-- the gold railing round the top, the dome in blue segments with gold ribs, open at the front
	K:cyl("Deck", (R + 0.9) * 2, 0.4, Vector3.new(0, T1 + 0.8, 0), WALLSTONE[1])
	for i = 0, 23 do
		local a = i * math.pi / 12
		K:cyl("RailPost", 0.3, 1.8, Vector3.new(math.sin(a) * (R + 0.4), T1 + 1.9, -math.cos(a) * (R + 0.4)), GOLDEN[1])
	end
	K:ring("RailTop", c, 24, R + 0.6, T1 + 2.8, 0.3, 0.4, GOLDEN, nil, true)
	local D0 = T1 + 1
	local DR = R - 1.6
	local open = { [0] = true, [1] = true, [15] = true, [14] = true }
	for k = 0, 9 do
		local f = k / 10
		local r = DR * math.cos(f * math.pi / 2)
		if r < 0.6 then
			break
		end
		K:ring("Dome", c, 16, r, D0 + k * DR / 10 * 1.1, DR / 10 * 1.1, math.min(r, 1.6), if k % 2 == 0 then BLUE else { BLUE[2], BLUE[1] }, if k < 8 then open else nil, true)
	end
	for _, a in { 45, 90, 135, 180, 225, 270, 315 } do
		for k = 0, 8 do
			local f = k / 9
			local r = DR * math.cos(f * math.pi / 2) + 0.15
			local cf = CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, D0 + f * DR * 1.1, -r)
			K:brick("Rib", Vector3.new(0.35, DR * 1.1 / 9 + 0.15, 0.3), cf, GOLDEN[1], true)
		end
	end
	for _, a in { 90, 270 } do
		star(K, CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, D0 + 3.6, -(DR + 0.2)), 0.9)
	end
	-- the telescope, pointing up out of the slot, white and gold with a blue lens
	local scope = CFrame.new(0, D0 + 2.4, -1.5) * CFrame.Angles(math.rad(40), 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	K:rod("Scope", 2.2, 7.5, scope * CFrame.new(1.8, 0, 0), C(236, 234, 228))
	K:rod("ScopeBand", 2.5, 0.5, scope * CFrame.new(5.4, 0, 0), GOLDEN[1])
	K:rod("ScopeBand", 2.4, 0.4, scope * CFrame.new(0.6, 0, 0), GOLDEN[1])
	K:glow("Lens", Vector3.new(0.2, 1.7, 1.7), scope * CFrame.new(5.75, 0, 0), SKYGEM, 6).Shape = Enum.PartType.Cylinder
	K:rod("ScopeTail", 1.4, 2.4, scope * CFrame.new(-2.8, 0, 0), C(80, 70, 70))
	K:box("ScopeMount", -1.2, D0 - 0.2, -2.8, 1.2, D0 + 2, -0.4, C(80, 70, 70))
	K:cyl("ScopeGear", 2.2, 0.3, CFrame.new(1.3, D0 + 1.4, -1.6) * CFrame.Angles(0, 0, math.pi / 2), GOLDEN[2])
	-- floating crystals either side
	for _, p in { { -14.6, 9, -4 }, { 15, 7, -2 }, { -15.8, 14, 2 }, { 14.2, 12.5, 5 } } do
		local cf = CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, math.rad(p[1] * 7), math.rad(10))
		K:brick("FloatRock", Vector3.new(1.6, 1, 1.6), cf * CFrame.new(0, -0.7, 0), C(80, 70, 110))
		K:prism("FloatCrystal", cf * CFrame.new(0, -0.2, 0), 1, 1, 1.4, GOLDEN[1])
	end
end

-------------------------------------------------------------------------------------------------------------
local BUILDERS: { [string]: (Kit) -> () } = {
	wheat = wheat,
	swamp = swamp,
	pine = pine,
	frost = frost,
	ember = ember,
	blossom = blossom,
	starlight = starlight,
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
