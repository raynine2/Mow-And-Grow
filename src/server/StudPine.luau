--!strict
-- STUD PINE (7 Nov 2026; owner on the redone farm and swamp: "Top, doe de volgende"). The pine isle's lookout
-- (forge_lm_pine) rebuilt from studded bricks, measured off square-on pictures of the mesh (front, sides, top; a stud
-- = 28.3 pixels): a lookout built round a big pine:
--   the pine's trunk up the middle (faceted, bark stripes), a mossy mound round its foot with orange mushrooms
--   four splayed log legs on rocks, rope-bound, two tiers of cross braces and a log across on every side
--   a deck on two layers of beams (their cut ends showing), a log railing open where the ladder comes up
--   a log cabin on the deck: a door, rows of green window panes down both sides, corner logs
--   a green plank roof (four sloping faces to a raised top with turned-up edges), a stovepipe
--   a lantern on an arm out over the front, the pine's crown in three drooping tiers above the roof
--   a long ladder up the front from the ground
-- Model space as the mesh's: front to -Z, the pivot at the bottom middle. StudPine.build(K) fills a StudKit.
local StudKit = require(script.Parent.StudKit)

type Kit = StudKit.Kit
local C = Color3.fromRGB
local V = Vector3.new
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local StudPine = {}

local LOGS = { C(120, 80, 44), C(102, 68, 38) }
local BARK = { C(102, 64, 38), C(88, 54, 32) }
local CABIN = { C(126, 84, 50), C(110, 72, 44) }
local DECK = { C(122, 82, 48), C(106, 70, 42) }
local CUT = C(196, 160, 110)
local ROOF = { C(42, 88, 50), C(36, 76, 44) }
local ROOF_EDGE = C(30, 64, 36)
local PINE = { C(56, 100, 48), C(46, 86, 40) }
local PINE_DARK = C(30, 56, 28)
local ROPE = C(170, 140, 80)
local STONE = { C(112, 100, 86), C(96, 86, 74) }
local MOSS = { C(76, 96, 40), C(64, 82, 34) }
local IVY = { C(80, 130, 50), C(66, 112, 42) }
local CAP = C(220, 110, 40)
local STEM = C(226, 214, 186)
local GLASS = C(44, 96, 80)
local DOOR = C(96, 58, 30)
local LANTERN = C(40, 76, 52)
local FLAME = C(255, 150, 60)
local PIPE = C(60, 52, 48)

local CX, CZ = -0.45, 0.88 -- the pine and the tower round it
local DECK_Y = 12.5

-- a round log from a to b
local function log(K: Kit, name: string, a: Vector3, b: Vector3, d: number, col: Color3): Part
	local dir = b - a
	local up = if math.abs(dir.Unit.Y) > 0.99 then X else Y
	return K:rod(name, d, dir.Magnitude, CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0), col)
end

-- a faceted frustum round an upright axis: radius r0 at y0 to r1 at y1, n facets
local function frustum(K: Kit, name: string, c: Vector3, r0: number, r1: number, y0: number, y1: number, n: number, cols: { Color3 })
	local inside = c + V(0, (y0 + y1) / 2, 0)
	for i = 0, n - 1 do
		local a0, a1 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
		local p0 = c + V(math.cos(a0) * r0, y0, math.sin(a0) * r0)
		local p1 = c + V(math.cos(a1) * r0, y0, math.sin(a1) * r0)
		local q1 = c + V(math.cos(a1) * r1, y1, math.sin(a1) * r1)
		local q0 = c + V(math.cos(a0) * r1, y1, math.sin(a0) * r1)
		K:quad(name, p0, p1, q1, q0, cols[i % #cols + 1], inside, 0.3)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the pine: trunk, the moss at its foot, mushrooms, ivy, its crown
-------------------------------------------------------------------------------------------------------------
local function pine(K: Kit)
	local c = V(CX, 0, CZ)
	frustum(K, "Trunk", c, 2.8, 2.05, 0.3, 12.0, 12, BARK)
	frustum(K, "Trunk", c, 2.05, 1.0, 12.0, 19.9, 12, BARK)
	frustum(K, "Moss", c, 4.1, 2.75, 0, 1.9, 16, MOSS)
	-- ivy leaves up the trunk
	for i = 0, 9 do
		local a = i * 2.4
		local y = 3.2 + i * 0.85
		local r = 2.8 - (y - 0.3) / 11.7 * 0.75 + 0.05
		local p = c + V(math.cos(a) * r, y, math.sin(a) * r)
		K:brick("Ivy", V(0.55, 0.45, 0.12), CFrame.lookAt(p, p + V(math.cos(a), 0, math.sin(a))) * CFrame.Angles(0, 0, a), IVY[i % 2 + 1], true)
	end
	-- the crown in three tiers, each a cone with a drooping scalloped edge and a dark underside
	for t, tier in { { 19.2, 3.95, 1.9 }, { 20.5, 3.3, 1.9 }, { 21.8, 2.6, 1.8 }, { 23.0, 1.9, 1.7 }, { 24.2, 1.2, 1.8 } } do
		local base, r, h = tier[1], tier[2], tier[3]
		local n = 14
		K:cone("Crown", c + V(0, base, 0), r, h, n, { PINE[t % 2 + 1], PINE[(t + 1) % 2 + 1] }, 0.25)
		K:cyl("CrownUnder", r * 1.6, 0.2, c + V(0, base - 0.05, 0), PINE_DARK)
		for i = 0, n - 1 do
			local a0, a1 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
			local am = (a0 + a1) / 2
			local p = c + V(math.cos(a0) * r, base, math.sin(a0) * r)
			local q = c + V(math.cos(a1) * r, base, math.sin(a1) * r)
			local tip = c + V(math.cos(am) * (r + 0.45), base - 0.5 - (i % 3) * 0.12, math.sin(am) * (r + 0.45))
			K:tri("CrownTip", p, q, tip, PINE[(i + t) % 2 + 1], c + V(0, base + 2, 0), 0.2)
		end
	end
end

local function mushrooms(K: Kit)
	for i, m in { { 4.9, -4.9, 0.95 }, { 2.5, -4.3, 0.7 }, { 4.6, -1.6, 0.8 }, { -4.9, -4.8, 0.85 }, { 3.6, 6.2, 0.9 }, { -1.5, -3.6, 0.6 } } do
		local p = V(m[1], 0, m[2])
		local s = m[3]
		K:cyl("MushroomStem", 0.26 * s, 0.75 * s, p + V(0, 0.38 * s, 0), STEM)
		K:cyl("MushroomCap", 0.95 * s, 0.16 * s, p + V(0, 0.8 * s, 0), CAP)
		K:cyl("MushroomCap", 0.62 * s, 0.16 * s, p + V(0, 0.94 * s, 0), CAP)
		K:ball("MushroomSpot", 0.13 * s, p + V(0.2 * s, 1.0 * s, 0.1 * s), STEM)
		K:ball("MushroomSpot", 0.1 * s, p + V(-0.15 * s, 1.0 * s, -0.15 * s), STEM)
		if i % 2 == 0 then
			K:brick("Fern", V(0.9, 0.08, 0.35), CFrame.new(p + V(0.4, 0.25, 0.3)) * CFrame.Angles(0, i, 0.4), IVY[1], true)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the legs, their braces, the rocks they stand on
-------------------------------------------------------------------------------------------------------------
local LEG_TOP, LEG_BOT = 11.4, 1.2

local function legAt(sx: number, sz: number, y: number): Vector3
	local f = (LEG_TOP - y) / (LEG_TOP - LEG_BOT)
	return V(CX + sx * (3.2 + 1.3 * f), y, CZ + sz * (3.2 + 1.2 * f))
end

local function legs(K: Kit)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local top, bot = legAt(sx, sz, LEG_TOP), legAt(sx, sz, LEG_BOT)
			log(K, "Leg", bot - V(0, 0.2, 0), top, 1.15, LOGS[1])
			local dir = (top - bot).Unit
			for _, y in { 10.9, 7.4, 6.2, 2.2 } do
				local p = legAt(sx, sz, y)
				log(K, "Rope", p - dir * 0.2, p + dir * 0.2, 1.38, ROPE)
			end
			-- the rock under it
			local r = legAt(sx, sz, 0) + V(sx * 0.15, 0, sz * 0.15)
			K:brick("Rock", V(1.9, 1.0, 1.8), CFrame.new(r + V(0, 0.5, 0)) * CFrame.Angles(0, sx * sz * 0.35, 0), STONE[1])
			K:brick("Rock", V(1.4, 0.5, 1.3), CFrame.new(r + V(0, 1.2, 0)) * CFrame.Angles(0, sx * sz * 0.35 + 0.4, 0), STONE[2])
		end
	end
	-- each side: two tiers of X braces, a log across between them
	local sides = { { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } }
	for _, s in sides do
		local out = V((s[1] + s[3]) / 2, 0, (s[2] + s[4]) / 2).Unit * 0.5
		local function at(k: number, y: number): Vector3
			return (if k == 1 then legAt(s[1], s[2], y) else legAt(s[3], s[4], y)) + out
		end
		for _, t in { { 10.6, 6.6 }, { 5.7, 2.8 } } do
			log(K, "Brace", at(1, t[1]), at(2, t[2]), 0.55, LOGS[2])
			log(K, "Brace", at(2, t[1]) + out * 0.3, at(1, t[2]) + out * 0.3, 0.55, LOGS[2])
		end
		log(K, "CrossLog", at(1, 6.25) + out * 0.2, at(2, 6.25) + out * 0.2, 0.62, LOGS[1])
	end
end

-------------------------------------------------------------------------------------------------------------
-- the deck, its railing, the ladder
-------------------------------------------------------------------------------------------------------------
local DX0, DX1, DZ0, DZ1 = -5.1, 4.4, -3.9, 6.0

local function logEnd(K: Kit, at: Vector3, axis: Vector3, d: number)
	log(K, "CutEnd", at - axis * 0.03, at + axis * 0.03, d * 0.92, CUT)
end

local function platform(K: Kit)
	for _, x in { 3.7, -0.3, -4.2 } do
		log(K, "Joist", V(x, 11.3, DZ0 - 0.3), V(x, 11.3, DZ1 + 0.3), 0.62, LOGS[2])
		logEnd(K, V(x, 11.3, DZ0 - 0.31), Z, 0.62)
	end
	for _, z in { -2.4, 0.9, 4.1 } do
		log(K, "Beam", V(DX0 - 0.35, 11.85, z), V(DX1 + 0.35, 11.85, z), 0.62, LOGS[1])
		logEnd(K, V(DX0 - 0.36, 11.85, z), X, 0.62)
		logEnd(K, V(DX1 + 0.36, 11.85, z), X, 0.62)
	end
	local n = 10
	local w = (DZ1 - DZ0) / n
	for i = 0, n - 1 do
		local z = DZ0 + i * w
		local j = ((i * 3) % 4 - 1.5) * 0.1
		K:box("DeckBoard", DX0 + j, 12.0, z + 0.02, DX1 + j * 0.5, DECK_Y, z + w - 0.02, DECK[i % 2 + 1])
	end
	-- the railing: posts, two rails, open at the front where the ladder comes up
	local posts = { { 4.0, -3.5 }, { 2.4, -3.5 }, { -0.2, -3.5 }, { -2.4, -3.5 }, { -4.7, -3.5 }, { 4.0, 1.0 }, { -4.7, 1.0 }, { 4.0, 5.6 }, { -4.7, 5.6 }, { -0.3, 5.6 } }
	for _, p in posts do
		log(K, "RailPost", V(p[1], DECK_Y, p[2]), V(p[1], 14.2, p[2]), 0.45, LOGS[1])
	end
	local runs = { { 4.0, -3.5, 2.4, -3.5 }, { -0.2, -3.5, -4.7, -3.5 }, { 4.0, -3.5, 4.0, 5.6 }, { -4.7, -3.5, -4.7, 5.6 }, { 4.0, 5.6, -4.7, 5.6 } }
	for _, r in runs do
		for _, y in { 13.85, 13.15 } do
			log(K, "Rail", V(r[1], y, r[2]), V(r[3], y, r[4]), 0.3, LOGS[2])
		end
	end
end

local function ladder(K: Kit)
	local z0, z1, y0, y1 = -6.25, -3.6, 0.2, 13.7
	for _, x in { 0.25, 1.95 } do
		log(K, "LadderRail", V(x, y0, z0), V(x, y1, z1), 0.3, LOGS[1])
	end
	local y = 0.9
	while y < 12.4 do
		local f = (y - y0) / (y1 - y0)
		local z = z0 + (z1 - z0) * f
		log(K, "Rung", V(0.0, y, z), V(2.2, y, z), 0.2, LOGS[2])
		for _, x in { 0.25, 1.95 } do
			K:ball("Lashing", 0.32, V(x, y, z), ROPE)
		end
		y += 0.8
	end
end

-------------------------------------------------------------------------------------------------------------
-- the cabin, its roof, the stovepipe, the lantern
-------------------------------------------------------------------------------------------------------------
local HX0, HX1, HZ0, HZ1 = -3.4, 2.4, -2.7, 4.4
local WALL_TOP = 16.0

local function cabin(K: Kit)
	-- log courses, studded, alternating
	local k = 0
	local y = DECK_Y
	while y < WALL_TOP - 0.01 do
		local col = CABIN[k % 2 + 1]
		local t = 0.5
		K:box("Course", HX0, y, HZ0, HX1, y + 0.5, HZ0 + t, col)
		K:box("Course", HX0, y, HZ1 - t, HX1, y + 0.5, HZ1, col)
		K:box("Course", HX0, y, HZ0 + t, HX0 + t, y + 0.5, HZ1 - t, CABIN[(k + 1) % 2 + 1])
		K:box("Course", HX1 - t, y, HZ0 + t, HX1, y + 0.5, HZ1 - t, CABIN[(k + 1) % 2 + 1])
		y += 0.5
		k += 1
	end
	for _, x in { HX0, HX1 } do
		for _, z in { HZ0, HZ1 } do
			log(K, "CornerLog", V(x, DECK_Y, z), V(x, WALL_TOP + 0.2, z), 0.6, LOGS[1])
		end
	end
	-- the door
	local d = CFrame.new(-0.5, 0, HZ0 - 0.05)
	K:brick("Door", V(1.5, 2.6, 0.12), d * CFrame.new(0, DECK_Y + 1.3, 0), DOOR)
	for _, e in { -1, 1 } do
		K:brick("DoorFrame", V(0.2, 2.8, 0.2), d * CFrame.new(e * 0.85, DECK_Y + 1.4, -0.05), LOGS[2], true)
	end
	K:brick("DoorFrame", V(1.9, 0.2, 0.2), d * CFrame.new(0, DECK_Y + 2.75, -0.05), LOGS[2], true)
	for _, x in { -0.25, 0.25 } do
		K:brick("DoorPlank", V(0.04, 2.5, 0.04), d * CFrame.new(x, DECK_Y + 1.3, -0.08), C(70, 40, 20), true)
	end
	K:ball("DoorKnob", 0.16, d * CFrame.new(0.5, DECK_Y + 1.2, -0.1), PIPE)
	-- a row of green panes down each side
	for _, side in { -1, 1 } do
		local x = if side < 0 then HX0 else HX1
		local f = CFrame.lookAt(V(x, 14.8, 0.85), V(x + side, 14.8, 0.85))
		K:brick("Panes", V(4.6, 1.15, 0.1), f * CFrame.new(0, 0, -0.02), GLASS, true)
		K:brick("PaneFrame", V(5.0, 0.2, 0.18), f * CFrame.new(0, 0.67, -0.06), LOGS[2], true)
		K:brick("PaneFrame", V(5.0, 0.2, 0.18), f * CFrame.new(0, -0.67, -0.06), LOGS[2], true)
		for i = 0, 6 do
			K:brick("PaneBar", V(0.14, 1.15, 0.14), f * CFrame.new(-2.3 + i * 0.767, 0, -0.06), LOGS[2], true)
		end
	end
	-- a small window in the front, right of the door
	local wf = CFrame.lookAt(V(1.25, 14.9, HZ0), V(1.25, 14.9, HZ0 - 1))
	K:brick("Panes", V(1.1, 0.9, 0.1), wf * CFrame.new(0, 0, -0.02), GLASS, true)
	K:brick("PaneBar", V(0.12, 0.9, 0.14), wf * CFrame.new(0, 0, -0.05), LOGS[2], true)
end

local function roof(K: Kit)
	local e = { x0 = -4.85, x1 = 3.5, z0 = -3.6, z1 = 5.7, y = 16.1 }
	local t = { x0 = -2.9, x1 = 1.6, z0 = -1.4, z1 = 3.3, y = 17.5 }
	local inside = V(CX, 15, CZ)
	K:quad("Roof", V(e.x0, e.y, e.z0), V(e.x1, e.y, e.z0), V(t.x1, t.y, t.z0), V(t.x0, t.y, t.z0), ROOF[1], inside, 0.35)
	K:quad("Roof", V(e.x0, e.y, e.z1), V(e.x1, e.y, e.z1), V(t.x1, t.y, t.z1), V(t.x0, t.y, t.z1), ROOF[1], inside, 0.35)
	K:quad("Roof", V(e.x0, e.y, e.z0), V(e.x0, e.y, e.z1), V(t.x0, t.y, t.z1), V(t.x0, t.y, t.z0), ROOF[2], inside, 0.35)
	K:quad("Roof", V(e.x1, e.y, e.z0), V(e.x1, e.y, e.z1), V(t.x1, t.y, t.z1), V(t.x1, t.y, t.z0), ROOF[2], inside, 0.35)
	-- plank seams running down the four faces
	for i = 1, 5 do
		local f = i / 6
		local a = V(e.x0 + (e.x1 - e.x0) * f, e.y + 0.04, e.z0 - 0.02)
		local b = V(t.x0 + (t.x1 - t.x0) * f, t.y + 0.04, t.z0 - 0.02)
		K:beam("Seam", a, b, 0.07, 0.06, ROOF_EDGE, (b - a):Cross(X).Unit, true)
		local a2 = V(e.x0 + (e.x1 - e.x0) * f, e.y + 0.04, e.z1 + 0.02)
		local b2 = V(t.x0 + (t.x1 - t.x0) * f, t.y + 0.04, t.z1 + 0.02)
		K:beam("Seam", a2, b2, 0.07, 0.06, ROOF_EDGE, (b2 - a2):Cross(X).Unit, true)
	end
	-- the eave's edge boards, turned up at the corners
	K:box("Eave", e.x0 - 0.1, e.y - 0.3, e.z0 - 0.1, e.x1 + 0.1, e.y + 0.02, e.z0 + 0.15, ROOF_EDGE, true)
	K:box("Eave", e.x0 - 0.1, e.y - 0.3, e.z1 - 0.15, e.x1 + 0.1, e.y + 0.02, e.z1 + 0.1, ROOF_EDGE, true)
	K:box("Eave", e.x0 - 0.1, e.y - 0.3, e.z0, e.x0 + 0.15, e.y + 0.02, e.z1, ROOF_EDGE, true)
	K:box("Eave", e.x1 - 0.15, e.y - 0.3, e.z0, e.x1 + 0.1, e.y + 0.02, e.z1, ROOF_EDGE, true)
	for _, c in { { e.x0, e.z0 }, { e.x1, e.z0 }, { e.x0, e.z1 }, { e.x1, e.z1 } } do
		local p = V(c[1], e.y + 0.15, c[2])
		local out = V(c[1] - CX, 0, c[2] - CZ).Unit
		K:beam("EaveTip", p - out * 0.2, p + out * 0.45 + V(0, 0.45, 0), 0.3, 0.2, ROOF_EDGE, Y, true)
	end
	-- the raised top with its turned-up rim
	K:box("RoofTop", t.x0, t.y - 0.1, t.z0, t.x1, 18.15, t.z1, ROOF[2])
	K:box("TopRim", t.x0 - 0.12, 18.05, t.z0 - 0.12, t.x1 + 0.12, 18.35, t.z0 + 0.12, ROOF_EDGE, true)
	K:box("TopRim", t.x0 - 0.12, 18.05, t.z1 - 0.12, t.x1 + 0.12, 18.35, t.z1 + 0.12, ROOF_EDGE, true)
	K:box("TopRim", t.x0 - 0.12, 18.05, t.z0, t.x0 + 0.12, 18.35, t.z1, ROOF_EDGE, true)
	K:box("TopRim", t.x1 - 0.12, 18.05, t.z0, t.x1 + 0.12, 18.35, t.z1, ROOF_EDGE, true)
	for _, c in { { t.x0, t.z0 }, { t.x1, t.z0 }, { t.x0, t.z1 }, { t.x1, t.z1 } } do
		K:box("TopHorn", c[1] - 0.15, 18.2, c[2] - 0.15, c[1] + 0.15, 18.6, c[2] + 0.15, ROOF_EDGE, true)
	end
	-- the stovepipe
	K:cyl("Stovepipe", 0.36, 1.6, V(-3.6, 17.2, -2.6), PIPE)
	K:cyl("StovepipeCap", 0.5, 0.18, V(-3.6, 18.05, -2.6), PIPE)
end

local function lantern(K: Kit)
	-- an arm out over the front from the cabin's corner, the lantern under its end
	log(K, "LanternArm", V(-3.5, 16.25, -2.5), V(-3.95, 16.25, -5.35), 0.42, LOGS[1])
	log(K, "Rope", V(-3.9, 16.25, -5.0), V(-3.88, 16.25, -4.75), 0.55, ROPE)
	local top = V(-3.9, 15.35, -4.85)
	K:cyl("LanternHook", 0.06, 0.9, top + V(0, 0.45, 0), PIPE)
	K:cone("LanternRoof", top - V(0, 0.15, 0), 0.5, 0.42, 6, { LANTERN }, 0.1)
	K:box("LanternTop", top.X - 0.45, top.Y - 0.3, top.Z - 0.45, top.X + 0.45, top.Y - 0.15, top.Z + 0.45, LANTERN, true)
	K:glow("LanternGlass", V(0.68, 0.95, 0.68), CFrame.new(top - V(0, 0.8, 0)), FLAME, 10, true)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K:box("LanternPost", top.X + sx * 0.38 - 0.06, top.Y - 1.3, top.Z + sz * 0.38 - 0.06, top.X + sx * 0.38 + 0.06, top.Y - 0.3, top.Z + sz * 0.38 + 0.06, LANTERN, true)
		end
	end
	K:box("LanternBase", top.X - 0.45, top.Y - 1.45, top.Z - 0.45, top.X + 0.45, top.Y - 1.28, top.Z + 0.45, LANTERN, true)
end

function StudPine.build(K: Kit)
	pine(K)
	mushrooms(K)
	legs(K)
	platform(K)
	ladder(K)
	cabin(K)
	roof(K)
	lantern(K)
end

return StudPine
