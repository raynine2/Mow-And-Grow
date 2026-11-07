--!strict
-- STUD SWAMP (7 Nov 2026; owner on the first stud isles: "very very bad make them way more accurate and pleasing to
-- look at", then on the redone farm: "Top, doe de volgende"). The swamp isle's hut (forge_lm_swamp) rebuilt from
-- studded bricks, measured off square-on pictures of the mesh (front, sides, back, top; a stud = 26.4 pixels):
--   a round teal pond with a muddy rim and lily pads; a plank deck on round log stilts bound with rope
--   the hut on the deck's back half: plank walls that lean out (wider at the top), an arched door with a porthole,
--   scalloped trim under the front plate, a gable with a round green window, a steep thatched roof with moss down
--   its ridge and leafy clumps on it, a straw fringe, chunky barge beams crossing over the ridge at both ends
--   four green lanterns (one from a gallows post at the front), a ladder down to a little dock, a rowboat with oars,
--   a giant lily pad on posts with a rope, cattails and long grass, floating spore bubbles
-- Model space as the mesh's: front to -Z, the pivot at the bottom middle. StudSwamp.build(K) fills a StudKit.
local StudKit = require(script.Parent.StudKit)

type Kit = StudKit.Kit
local C = Color3.fromRGB
local V = Vector3.new
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local StudSwamp = {}

local PLANK = { C(124, 88, 52), C(108, 76, 44) }
local DARK = C(74, 44, 24)
local BEAM = { C(140, 88, 46), C(122, 76, 40) }
local DECK = { C(134, 86, 46), C(116, 72, 38) }
local LOG = { C(108, 70, 40), C(92, 58, 32) }
local ROPE = C(176, 146, 80)
local THATCH = { C(192, 142, 50), C(178, 128, 44), C(186, 136, 48) }
local MOSS = { C(114, 140, 44), C(96, 120, 38) }
local LEAF = { C(108, 162, 42), C(88, 140, 34) }
local GLOW = C(176, 240, 150)
local CAP = C(70, 50, 22)
local WINDOW = C(150, 214, 136)
local WATER = C(52, 128, 96)
local MUD = C(48, 52, 32)
local RIM = { C(66, 98, 74), C(58, 88, 66) }
local PAD = { C(118, 176, 40), C(102, 156, 34) }
local CATTAIL = C(118, 58, 26)
local STEM = C(98, 142, 40)
local GRASS = { C(98, 164, 42), C(80, 140, 32) }
local BOAT = { C(128, 80, 42), C(108, 66, 34) }
local SCALLOP = C(150, 92, 40)
local BUBBLE = C(212, 236, 224)

-- the hut: its walls lean out from the bottom (at the sill) to the top plate
local HB = { x0 = -4.95, x1 = 2.22, z0 = 2.5, z1 = 11.2, y = 9.0 }
local HT = { x0 = -5.76, x1 = 3.57, z0 = 1.9, z1 = 12.0, y = 15.3 }
local DECK_Y = 8.13
local RX = -1.3 -- the ridge (X)
local APEX = 20.6 -- the thatch's top
local SPAN = 7.3 -- the eave's reach out from the ridge
local EAVE = 13.2
local RZ0, RZ1 = 0.4, 12.4 -- the roof's ends

-- a round log from a to b
local function log(K: Kit, name: string, a: Vector3, b: Vector3, d: number, col: Color3): Part
	local dir = b - a
	local up = if math.abs(dir.Unit.Y) > 0.99 then X else Y
	return K:rod(name, d, dir.Magnitude, CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0), col)
end

-- a rope binding round an upright log
local function binding(K: Kit, at: Vector3, d: number)
	K:cyl("Rope", d + 0.24, 0.32, at, ROPE)
end

-------------------------------------------------------------------------------------------------------------
-- the pond
-------------------------------------------------------------------------------------------------------------
local PC = V(0.4, 0, 0.1)

local function pond(K: Kit)
	K:ring("Mud", PC, 28, 13.0, 0.75, 0.45, 13.0, { MUD })
	K:ring("Water", PC, 28, 12.8, 1.15, 0.6, 12.8, { WATER }, nil, true)
	K:ring("Rim", PC, 28, 13.3, 0.9, 0.93, 0.55, RIM, nil, true)
end

local function pad(K: Kit, x: number, z: number, d: number, y: number, turn: number, k: number)
	local c = CFrame.new(x, y, z) * CFrame.Angles(0, turn, 0)
	K:cyl("LilyPad", d, 0.16, c, PAD[k % 2 + 1])
	-- the notch: a wedge of water laid over it
	local a = (c * CFrame.new(0, 0.09, 0)).Position
	local b = (c * CFrame.new(d / 2 + 0.02, 0.09, -d * 0.16)).Position
	local e = (c * CFrame.new(d / 2 + 0.02, 0.09, d * 0.16)).Position
	K:tri("PadNotch", a, b, e, WATER, a - V(0, 1, 0), 0.03)
end

local function lilyPads(K: Kit)
	local list = {
		{ 2.9, -1.7, 2.8 },
		{ 5.9, -11.2, 3.6 },
		{ 11.2, -4.6, 1.9 },
		{ 11.4, -0.7, 3.3 },
		{ 9.8, 2.9, 3.1 },
		{ 8.9, 6.7, 3.3 },
		{ -11.6, -4.9, 3.0 },
		{ -9.4, -9.4, 2.4 },
		{ -6.0, 6.5, 2.2 },
	}
	for i, p in list do
		pad(K, p[1], p[2], p[3], 1.8, i * 1.7, i)
	end
end

-- the giant lily pad on posts, a rope round its front
local BP = V(6.3, 0, -4.4)

local function bigPad(K: Kit)
	local top = 3.45
	K:ring("PadFrame", BP, 14, 4.2, 3.0, 0.4, 0.5, LOG)
	pad(K, BP.X, BP.Z, 8.6, top, 0.4, 1)
	K:cyl("PadRim", 8.75, 0.12, V(BP.X, top - 0.1, BP.Z), PAD[2])
	for i = 0, 5 do
		local a = 0.4 + 0.6 + i * 0.85
		local p = BP + V(math.cos(a) * 2.2, top + 0.1, math.sin(a) * 2.2)
		K:brick("Vein", V(3.8, 0.04, 0.12), CFrame.new(p) * CFrame.Angles(0, -a, 0), PAD[2], true)
	end
	local posts = {}
	for i = 0, 6 do
		local a = math.rad(-150 + i * 50)
		local p = BP + V(math.cos(a) * 4.35, 0, math.sin(a) * 4.35)
		local tall = if i % 2 == 0 then 4.5 else 3.9
		log(K, "PadPost", V(p.X, 1.0, p.Z), V(p.X, tall, p.Z), 0.62, LOG[i % 2 + 1])
		if i % 2 == 0 then
			K:ball("PostKnob", 0.62, V(p.X, tall, p.Z), LOG[1])
			binding(K, V(p.X, 3.3, p.Z), 0.62)
		end
		table.insert(posts, V(p.X, 3.85, p.Z))
	end
	-- the rope swags between the posts round the front
	for i = 1, #posts - 1 do
		local a, b = posts[i], posts[i + 1]
		local m = (a + b) / 2 - V(0, 0.3, 0)
		K:beam("RopeSwag", a, m, 0.12, 0.12, ROPE, nil, true)
		K:beam("RopeSwag", m, b, 0.12, 0.12, ROPE, nil, true)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the deck on its stilts, the ladder, the dock
-------------------------------------------------------------------------------------------------------------
local function deck(K: Kit)
	local posts = { { 3.3, 1.3, 1.5 }, { 3.3, 5.9, 1.3 }, { 3.3, 10.6, 1.4 }, { -7.9, 1.3, 1.5 }, { -7.9, 5.9, 1.3 }, { -7.9, 10.6, 1.4 }, { -2.3, 1.3, 1.2 }, { -2.3, 10.6, 1.2 } }
	for i, p in posts do
		log(K, "Stilt", V(p[1], 1.0, p[2]), V(p[1], 7.6, p[2]), p[3], LOG[i % 2 + 1])
		binding(K, V(p[1], 5.7, p[2]), p[3])
		if p[2] < 2 then
			binding(K, V(p[1], 3.1, p[2]), p[3])
		end
	end
	-- beams: along X under the front, middle and back, along Z down both sides (their ends stick out)
	for _, z in { 1.3, 5.9, 10.6 } do
		K:box("Beam", -9.55, 7.0, z - 0.32, 4.85, 7.62, z + 0.32, BEAM[2])
	end
	for _, x in { 3.3, -7.9 } do
		K:box("Beam", x - 0.32, 7.0, -0.1, x + 0.32, 7.62, 12.6, BEAM[2])
	end
	-- the planks, studded, a little ragged at the ends
	local n = 12
	local w = (12.3 - 0.2) / n
	for i = 0, n - 1 do
		local z = 0.2 + i * w
		local j = ((i * 7) % 5 - 2) * 0.12
		K:box("Plank", -9.2 + j, 7.62, z + 0.02, 4.46 - j * 0.6, DECK_Y, z + w - 0.02, DECK[i % 2 + 1])
	end
end

local function ladderDock(K: Kit)
	-- the ladder from the deck's front down to the dock
	for _, x in { -0.4, -2.7 } do
		K:beam("LadderRail", V(x, 8.0, 0.25), V(x, 3.9, -1.05), 0.26, 0.26, BEAM[1], X)
	end
	for k = 1, 4 do
		local f = k / 5
		local p = V(-1.55, 8.0 + (3.9 - 8.0) * f, 0.25 + (-1.05 - 0.25) * f)
		K:rod("Rung", 0.2, 2.5, CFrame.new(p), BEAM[2])
	end
	-- the dock
	for _, p in { { -3.0, -1.6 }, { 1.5, -1.6 }, { -3.0, -5.6 }, { 1.5, -5.6 } } do
		log(K, "DockPost", V(p[1], 1.0, p[2]), V(p[1], 4.35, p[2]), 0.62, LOG[1])
		binding(K, V(p[1], 3.15, p[2]), 0.62)
	end
	for _, x in { -3.0, 1.5 } do
		K:box("DockBeam", x - 0.25, 3.1, -6.1, x + 0.25, 3.5, -1.1, BEAM[2])
	end
	for i = 0, 4 do
		local z = -6.0 + i * 0.96
		local j = ((i * 3) % 4 - 1.5) * 0.15
		K:box("DockPlank", -3.45 + j, 3.5, z + 0.03, 1.95 + j, 3.95, z + 0.93, DECK[i % 2 + 1])
	end
	K:box("DockPlank", -2.6, 3.45, -7.0, -0.65, 3.9, -6.05, DECK[2])
	K:box("DockPlank", -0.3, 3.45, -6.95, 1.9, 3.9, -6.05, DECK[1])
end

-------------------------------------------------------------------------------------------------------------
-- the hut
-------------------------------------------------------------------------------------------------------------
-- upright boards fanning out across a leaning wall: bottom corners bl..br, top corners tl..tr, studs out
local function wallFan(K: Kit, bl: Vector3, br: Vector3, tl: Vector3, tr: Vector3, n: number, out: Vector3)
	local w = math.max((br - bl).Magnitude, (tr - tl).Magnitude) / n + 0.05
	for i = 0, n - 1 do
		local f = (i + 0.5) / n
		local a = bl:Lerp(br, f) - out * 0.2
		local b = tl:Lerp(tr, f) - out * 0.2
		K:beam("Boards", a, b, w, 0.4, PLANK[i % 2 + 1], out)
	end
end

local FRONT_OUT = V(0, -0.095, -1).Unit
local BACK_OUT = V(0, -0.095, 1).Unit
local RIGHT_OUT = V(1, -0.214, 0).Unit
local LEFT_OUT = V(-1, -0.129, 0).Unit

local function hutWalls(K: Kit)
	local b, t = HB, HT
	K:box("Core", b.x0 + 0.4, b.y, b.z0 + 0.4, b.x1 - 0.4, t.y, b.z1 - 0.4, DARK, true)
	wallFan(K, V(b.x0, b.y, b.z0), V(b.x1, b.y, b.z0), V(t.x0, t.y, t.z0), V(t.x1, t.y, t.z0), 9, FRONT_OUT)
	wallFan(K, V(b.x0, b.y, b.z1), V(b.x1, b.y, b.z1), V(t.x0, t.y, t.z1), V(t.x1, t.y, t.z1), 9, BACK_OUT)
	wallFan(K, V(b.x1, b.y, b.z0), V(b.x1, b.y, b.z1), V(t.x1, t.y, t.z0), V(t.x1, t.y, t.z1), 10, RIGHT_OUT)
	wallFan(K, V(b.x0, b.y, b.z0), V(b.x0, b.y, b.z1), V(t.x0, t.y, t.z0), V(t.x0, t.y, t.z1), 10, LEFT_OUT)
	-- corner posts up the four leaning edges
	for _, c in { { b.x0, b.z0, t.x0, t.z0 }, { b.x1, b.z0, t.x1, t.z0 }, { b.x0, b.z1, t.x0, t.z1 }, { b.x1, b.z1, t.x1, t.z1 } } do
		K:beam("CornerPost", V(c[1], b.y - 0.3, c[2]), V(c[3], t.y + 0.1, c[4]), 0.55, 0.55, BEAM[2], Z)
	end
	-- the sill under them, the top plate over them
	K:box("Sill", b.x0 - 0.45, DECK_Y, b.z0 - 0.45, b.x1 + 0.45, b.y + 0.05, b.z1 + 0.45, BEAM[1])
	log(K, "TopPlate", V(t.x1 + 0.6, 15.2, t.z0 - 0.25), V(t.x0 - 0.6, 15.2, t.z0 - 0.25), 0.6, BEAM[1])
	log(K, "TopPlate", V(t.x1 + 0.6, 15.2, t.z1 + 0.25), V(t.x0 - 0.6, 15.2, t.z1 + 0.25), 0.6, BEAM[1])
	-- the scalloped trim under the front plate
	K:box("ScallopBoard", -4.2, 14.6, t.z0 - 0.33, 2.4, 14.95, t.z0 - 0.08, SCALLOP)
	for x = -3.9, 2.15, 0.62 do
		K:rod("Scallop", 0.58, 0.2, CFrame.new(x, 14.62, t.z0 - 0.2) * CFrame.Angles(0, math.pi / 2, 0), SCALLOP)
	end
	-- a window in the right wall
	local wc = V(b.x1 + (t.x1 - b.x1) * 0.48 + 0.08, 12.0, 6.4)
	local wf = CFrame.lookAt(wc, wc + RIGHT_OUT)
	K:brick("SideWindow", V(2.0, 2.2, 0.1), wf, C(28, 26, 22), true)
	for _, e in { -1, 1 } do
		K:brick("WindowFrame", V(0.25, 2.6, 0.2), wf * CFrame.new(e * 1.1, 0, -0.08), BEAM[1], true)
		K:brick("WindowFrame", V(2.45, 0.25, 0.2), wf * CFrame.new(0, e * 1.2, -0.08), BEAM[1], true)
	end
	K:brick("WindowBar", V(0.14, 2.2, 0.14), wf * CFrame.new(0, 0, -0.06), BEAM[1], true)
	K:brick("WindowBar", V(2.0, 0.14, 0.14), wf * CFrame.new(0, 0, -0.06), BEAM[1], true)
end

-- a round window: green glass, a ring of short beams, a cross
local function porthole(K: Kit, cf: CFrame, d: number)
	local g = K:rod("Porthole", d, 0.14, cf * CFrame.Angles(0, math.pi / 2, 0), WINDOW)
	g.Material = Enum.Material.SmoothPlastic
	local r = d / 2 + 0.12
	for i = 0, 9 do
		local a0, a1 = i / 10 * math.pi * 2, (i + 1) / 10 * math.pi * 2
		local p = (cf * CFrame.new(math.cos(a0) * r, math.sin(a0) * r, -0.08)).Position
		local q = (cf * CFrame.new(math.cos(a1) * r, math.sin(a1) * r, -0.08)).Position
		K:beam("PortholeRim", p, q, 0.26, 0.2, BEAM[1], cf.LookVector, true)
	end
	K:brick("PortholeBar", V(d, 0.12, 0.1), cf * CFrame.new(0, 0, -0.1), BEAM[1], true)
	K:brick("PortholeBar", V(0.12, d, 0.1), cf * CFrame.new(0, 0, -0.1), BEAM[1], true)
end

local function door(K: Kit)
	local h = 11.1
	local zw = HB.z0 + (h - HB.y) / (HT.y - HB.y) * (HT.z0 - HB.z0)
	local c = V(-1.65, h, zw)
	local f = CFrame.lookAt(c, c + FRONT_OUT)
	-- the planks (a box and a disc for the arch), the arched frame, the porthole, a knob
	K:brick("Door", V(2.85, 3.1, 0.22), f * CFrame.new(0, -0.15, -0.1), DARK)
	K:rod("DoorArch", 2.85, 0.22, f * CFrame.new(0, 1.4, -0.1) * CFrame.Angles(0, math.pi / 2, 0), DARK)
	for _, k in { -0.7, 0, 0.7 } do
		K:brick("DoorPlank", V(0.06, 4.3, 0.05), f * CFrame.new(k, 0.3, -0.22), C(52, 30, 16), true)
	end
	for _, e in { -1, 1 } do
		K:brick("DoorPost", V(0.3, 3.2, 0.3), f * CFrame.new(e * 1.57, -0.2, -0.15), BEAM[1], true)
	end
	for i = 0, 5 do
		local a0, a1 = i / 6 * math.pi, (i + 1) / 6 * math.pi
		local p = (f * CFrame.new(math.cos(a0) * 1.57, 1.4 + math.sin(a0) * 1.57, -0.15)).Position
		local q = (f * CFrame.new(math.cos(a1) * 1.57, 1.4 + math.sin(a1) * 1.57, -0.15)).Position
		K:beam("DoorArchFrame", p, q, 0.3, 0.3, BEAM[1], f.LookVector, true)
	end
	porthole(K, f * CFrame.new(-0.1, 0.7, -0.25), 1.2)
	K:ball("DoorKnob", 0.22, f * CFrame.new(0.9, -0.4, -0.25), CAP)
	-- the doorstep on the deck
	K:box("Step", -3.0, DECK_Y, zw - 0.9, -0.3, DECK_Y + 0.3, zw - 0.1, BEAM[2])
end

-- a gable end above a top plate: boards under the roof's line, a fill behind, (front) a round window
local function gable(K: Kit, z: number, out: number, withWindow: boolean)
	local base, top = 15.45, APEX - 0.95
	local half = (top - base) / 0.99
	local inside = V(RX, 17, z - out)
	K:tri("GableFill", V(RX - half, base, z), V(RX + half, base, z), V(RX, top, z), PLANK[2], inside, 0.3)
	local n = math.floor(half * 2 / 0.75)
	local w = half * 2 / n
	local face = CFrame.lookAt(V(RX, 0, z), V(RX, 0, z + out))
	for i = 0, n - 1 do
		local u0 = -half + i * w
		local u1 = u0 + w
		local hgt = top - math.max(math.abs(u0), math.abs(u1)) * 0.99 - 0.12
		if hgt > base + 0.1 then
			K:brick("GableBoard", V(w + 0.02, hgt - base, 0.35), face * CFrame.new(u0 + w / 2, (base + hgt) / 2, 0.17), PLANK[i % 2 + 1])
		end
	end
	if withWindow then
		porthole(K, CFrame.lookAt(V(RX, 17.0, z), V(RX, 17.0, z + out)) * CFrame.new(0, 0, -0.05), 2.1)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the thatched roof
-------------------------------------------------------------------------------------------------------------
-- one side's thatch in rows from the eave up (moss on the top rows), a straw fringe, a leafy clump
local function thatch(K: Kit, s: number)
	local th = 0.6
	local rise, run = APEX - EAVE, SPAN
	local L = math.sqrt(rise * rise + run * run)
	local u = V(-s * run, rise, 0).Unit
	local n = u:Cross(Z)
	if n.Y < 0 then
		n = -n
	end
	local p0 = V(RX + s * SPAN, EAVE, 0) - n * th
	local r = Z
	if r:Cross(n):Dot(u) < 0 then
		r = -r
	end
	local rows = 8
	local step = L / rows
	local w = step + 0.4
	local segs = 8
	local sl = (RZ1 - RZ0) / segs
	for k = 0, rows - 1 do
		for j = 0, segs - 1 do
			local zc = RZ0 + (j + 0.5) * sl
			local jit = ((k * 5 + j * 3) % 7 - 3) * 0.03
			local pos = p0 + Z * zc + u * ((k + 0.5) * step + jit) + n * (th / 2 + jit * 0.5)
			local cf = CFrame.fromMatrix(pos, r, n, u) * CFrame.new(0, 0, w / 2) * CFrame.Angles(math.rad(5 + jit * 40), 0, 0) * CFrame.new(0, 0, -w / 2)
			local col = if k >= rows - 2 then MOSS[(k + j) % 2 + 1] else THATCH[(k + j) % #THATCH + 1]
			K:brick("Thatch", V(sl + 0.06, th, w), cf, col, true)
		end
	end
	-- moss dripping down the middle of the slope
	local mid = p0 + Z * 6.4 + u * (L * 0.62) + n * (th + 0.02)
	K:brick("MossDrip", V(2.2, 0.08, L * 0.55), CFrame.fromMatrix(mid, r, n, u), MOSS[1], true)
	-- the fringe of straw along the eave
	local z = RZ0 + 0.1
	local k = 0
	while z < RZ1 do
		local hang = 0.45 + (k * 37 % 5) * 0.12
		K:brick("Fringe", V(0.16, hang, 0.24), CFrame.new(RX + s * (SPAN - 0.05), EAVE - 0.75 - hang / 2, z) * CFrame.Angles(0, 0, s * 0.18), THATCH[k % 2 + 1], true)
		z += 0.42
		k += 1
	end
	-- a clump of big leaves lying on the slope
	for ci, zl in { 4.2, 8.6 } do
		local cc = p0 + Z * zl + u * (L * (0.38 + ci * 0.06)) + n * (th + 0.1)
		for i = 0, 10 do
			local a = i * 0.62
			local d = 0.3 + (i % 3) * 0.45
			local p = cc + (r * math.cos(a) + u * math.sin(a)) * d
			local lf = CFrame.fromMatrix(p, r, n, u) * CFrame.Angles(0, a * 1.3, 0) * CFrame.Angles(math.rad(12), 0, 0)
			K:brick("Leaf", V(1.25, 0.1, 1.9), lf, LEAF[i % 2 + 1], true)
		end
	end
end

-- chunky beams up both gable edges, crossing over the ridge, moss round the crossing
local function bargeBeams(K: Kit, z: number)
	local slope = (APEX - EAVE) / SPAN
	for _, s in { -1, 1 } do
		local a = V(RX + s * (SPAN + 0.35), EAVE - 0.15, z)
		local b = V(RX - s * 1.1, APEX + 1.1 * slope + 0.3, z)
		K:beam("BargeBeam", a, b, 0.75, 0.7, BEAM[1], Z)
	end
	K:rod("MossBand", 1.3, 0.9, CFrame.new(RX, APEX + 0.25, z) * CFrame.Angles(0, math.pi / 2, 0), MOSS[1])
	K:ball("RopeKnot", 0.55, V(RX, APEX - 0.35, z + (if z < 5 then -0.45 else 0.45)), LOG[2])
end

local function roof(K: Kit)
	thatch(K, 1)
	thatch(K, -1)
	K:brick("RidgeMoss", V(1.1, 1.1, RZ1 - RZ0 + 0.3), CFrame.new(RX, APEX - 0.25, (RZ0 + RZ1) / 2) * CFrame.Angles(0, 0, math.pi / 4), MOSS[2], true)
	bargeBeams(K, RZ0 - 0.15)
	bargeBeams(K, RZ1 + 0.15)
	gable(K, HT.z0, -1, true)
	gable(K, HT.z1, 1, false)
	-- the posts propping the right eave, front and back
	for _, z in { 2.3, 11.6 } do
		K:beam("EavePost", V(3.4, DECK_Y, z), V(5.1, EAVE + 0.2, z), 0.5, 0.5, LOG[1], Z)
	end
end

-------------------------------------------------------------------------------------------------------------
-- lanterns, the gallows post, vines, bubbles
-------------------------------------------------------------------------------------------------------------
local function lantern(K: Kit, hook: Vector3, drop: number)
	local top = hook - V(0, drop, 0)
	K:cyl("LanternChain", 0.08, drop, hook - V(0, drop / 2, 0), CAP)
	K:cyl("LanternCap", 0.95, 0.22, top - V(0, 0.11, 0), CAP)
	local g = K:cyl("Lantern", 1.3, 1.6, top - V(0, 0.95, 0), GLOW)
	local bulge = K:cyl("Lantern", 1.5, 0.8, top - V(0, 0.95, 0), GLOW)
	bulge.Material = Enum.Material.SmoothPlastic
	bulge.Color = GLOW
	g.Material = Enum.Material.SmoothPlastic
	g.Color = GLOW
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		K:brick("LanternRib", V(0.1, 1.5, 0.1), CFrame.new(top - V(0, 0.95, 0) + V(math.cos(a) * 0.72, 0, math.sin(a) * 0.72)), CAP, true)
	end
	local l = Instance.new("PointLight")
	l.Color = GLOW
	l.Range = 9
	l.Brightness = 0.9
	l.Parent = g
	K:cyl("LanternCap", 0.9, 0.2, top - V(0, 1.78, 0), CAP)
end

local function lights(K: Kit)
	lantern(K, V(5.6, EAVE - 0.4, 4.9), 0.7)
	lantern(K, V(2.1, 14.55, 1.2), 1.4)
	lantern(K, V(-5.0, 14.55, 1.2), 2.4)
	-- the gallows post at the deck's front corner, its arm out over the water, its lantern
	local px, pz = -7.4, 0.7
	log(K, "GallowsPost", V(px, 7.6, pz), V(px, 18.6, pz), 0.85, LOG[1])
	binding(K, V(px, 12.5, pz), 0.85)
	binding(K, V(px, 8.9, pz), 0.85)
	log(K, "GallowsArm", V(px, 17.55, pz + 0.6), V(px, 17.55, -4.5), 0.55, LOG[2])
	K:beam("GallowsBrace", V(px, 16.0, pz), V(px, 17.4, pz - 1.5), 0.3, 0.3, LOG[2], X)
	lantern(K, V(px, 17.3, -3.0), 1.6)
end

local function vines(K: Kit)
	local list = { { 3.6, 15.0, 1.8, 4.6 }, { 4.6, 13.4, 3.6, 3.2 }, { 4.7, 13.4, 5.6, 4.2 }, { 4.7, 13.3, 7.2, 3.0 }, { 4.6, 13.3, 9.0, 3.8 }, { -5.9, 15.0, 1.7, 2.6 } }
	for i, v in list do
		K:brick("Vine", V(0.14, v[4], 0.14), CFrame.new(v[1], v[2] - v[4] / 2, v[3]) * CFrame.Angles(0, 0, (i % 3 - 1) * 0.06), LEAF[i % 2 + 1], true)
		K:brick("VineLeaf", V(0.35, 0.08, 0.3), CFrame.new(v[1], v[2] - v[4] + 0.1, v[3]) * CFrame.Angles(0.4, i, 0), LEAF[1], true)
	end
end

local function bubbles(K: Kit)
	local list = {
		{ 5.2, 17.4, 11.7, 1.4 },
		{ 10.0, 16.4, 8.0, 1.0 },
		{ 7.6, 12.4, 10.1, 0.7 },
		{ 7.4, 10.6, 7.6, 0.6 },
		{ 6.0, 9.4, 9.8, 0.9 },
		{ -12.0, 13.1, -2.1, 1.0 },
		{ 1.9, 14.3, -0.6, 0.8 },
		{ -5.9, 11.4, -2.6, 0.85 },
		{ -3.7, 2.4, 5.7, 1.5 },
		{ 6.3, 2.3, 3.8, 1.1 },
		{ -4.6, 13.7, -0.4, 0.7 },
	}
	for _, b in list do
		K:ball("Bubble", b[4], V(b[1], b[2], b[3]), BUBBLE)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the rowboat and its oars
-------------------------------------------------------------------------------------------------------------
local BOAT_X = -4.0
-- sections from the bow back: z, half-width at the gunwale, the gunwale's height, the keel's height
local HULL = {
	{ -13.9, 0.05, 3.1, 1.3 },
	{ -13.0, 1.3, 2.85, 0.6 },
	{ -11.8, 2.2, 2.65, 0.25 },
	{ -10.2, 2.65, 2.55, 0.1 },
	{ -8.4, 2.7, 2.55, 0.1 },
	{ -6.9, 2.45, 2.65, 0.3 },
	{ -5.9, 2.1, 2.8, 0.65 },
}

local function hullPoints(sec: { number }, side: number): (Vector3, Vector3, Vector3)
	local z, hw, hg, hk = sec[1], sec[2], sec[3], sec[4]
	local g = V(BOAT_X + side * hw, hg, z)
	local c = V(BOAT_X + side * hw * 0.62, hk + (hg - hk) * 0.33, z)
	local k = V(BOAT_X, hk, z)
	return g, c, k
end

local function boat(K: Kit)
	for i = 1, #HULL - 1 do
		local a, b = HULL[i], HULL[i + 1]
		local inside = V(BOAT_X, (a[3] + a[4]) / 2 + 0.9, (a[1] + b[1]) / 2)
		for _, s in { -1, 1 } do
			local ga, ca, ka = hullPoints(a, s)
			local gb, cb, kb = hullPoints(b, s)
			K:quad("Hull", ga, gb, cb, ca, BOAT[1], inside, 0.18)
			K:quad("Hull", ca, cb, kb, ka, BOAT[2], inside, 0.18)
			K:beam("Gunwale", ga + V(0, 0.08, 0), gb + V(0, 0.08, 0), 0.24, 0.24, DARK, Y, true)
		end
	end
	-- the transom at the back
	local last = HULL[#HULL]
	local gl, cl, k = hullPoints(last, -1)
	local gr, cr = hullPoints(last, 1)
	local back = V(BOAT_X, last[3], last[1] - 1)
	K:quad("Transom", gl, gr, cr, cl, BOAT[2], back, 0.2)
	K:quad("Transom", cl, cr, k, k, BOAT[2], back, 0.2)
	-- seats, a floor, the stem post with a ring
	for _, z in { -11.0, -8.0 } do
		K:box("Thwart", BOAT_X - 2.3, 1.85, z - 0.35, BOAT_X + 2.3, 2.1, z + 0.35, BOAT[1])
	end
	K:box("Floor", BOAT_X - 1.0, 0.55, -12.4, BOAT_X + 1.0, 0.75, -6.4, DARK, true)
	K:beam("Stem", V(BOAT_X, 0.9, -13.75), V(BOAT_X, 4.2, -14.15), 0.36, 0.36, DARK, X)
	K:rod("StemRing", 0.5, 0.12, CFrame.new(BOAT_X, 3.6, -14.3) * CFrame.Angles(0, 0, 0), ROPE)
	-- one oar across the boat, its blade out over the water; one leaning up out of it
	local function oar(a: Vector3, b: Vector3)
		log(K, "Oar", a, b, 0.2, BEAM[1])
		local dir = (b - a).Unit
		K:brick("OarBlade", V(0.75, 0.1, 1.5), CFrame.lookAt(b + dir * 0.55, b + dir * 2) * CFrame.Angles(0, 0, 0.3), BEAM[1], true)
	end
	oar(V(-3.5, 2.85, -9.4), V(1.6, 2.1, -11.0))
	oar(V(-3.6, 5.5, -7.4), V(1.4, 1.95, -9.9))
end

-------------------------------------------------------------------------------------------------------------
-- cattails and grass
-------------------------------------------------------------------------------------------------------------
local function cattail(K: Kit, base: Vector3, h: number, head: number, lean: Vector3)
	local top = base + V(0, h, 0) + lean
	log(K, "CattailStem", base, top, 0.18, STEM)
	local dir = (top - base).Unit
	local hc = top - dir * (head / 2 + 0.45)
	log(K, "Cattail", hc - dir * head / 2, hc + dir * head / 2, 0.62, CATTAIL)
	K:ball("Cattail", 0.62, hc - dir * head / 2, CATTAIL)
	K:ball("Cattail", 0.62, hc + dir * head / 2, CATTAIL)
	log(K, "CattailTip", top - dir * 0.45, top + dir * 0.4, 0.1, STEM)
end

local function blade(K: Kit, base: Vector3, tip: Vector3, w: number, k: number)
	local out = V(tip.X - base.X, 0, tip.Z - base.Z)
	local up = tip.Y - base.Y
	local p1 = base + out * 0.1 + V(0, up * 0.5, 0)
	local p2 = base + out * 0.45 + V(0, up * 0.88, 0)
	local p3 = base + out + V(0, up * 0.7, 0)
	local side = out:Cross(Y)
	if side.Magnitude < 0.01 then
		side = X
	end
	K:beam("Grass", base, p1, w, 0.08, GRASS[k % 2 + 1], side.Unit, true)
	K:beam("Grass", p1, p2, w * 0.8, 0.08, GRASS[k % 2 + 1], side.Unit, true)
	K:beam("Grass", p2, p3, w * 0.55, 0.08, GRASS[(k + 1) % 2 + 1], side.Unit, true)
end

local function reeds(K: Kit)
	cattail(K, V(8.0, 1.6, 8.5), 10.6, 2.5, V(0.1, 0, 0))
	cattail(K, V(8.5, 1.6, 8.0), 8.4, 2.0, V(0.4, 0, -0.2))
	cattail(K, V(-10.1, 1.6, -2.7), 10.4, 2.8, V(-0.2, 0, 0))
	cattail(K, V(-9.6, 1.6, -0.8), 9.0, 2.2, V(0.3, 0, 0.2))
	local k = 0
	for _, g in { { 8.0, 8.4, 1 }, { -9.9, -1.8, -1 } } do
		local b = V(g[1], 1.7, g[2])
		for i = 0, 5 do
			local a = i * 1.05 + 0.3
			local len = 4.5 + (i % 3) * 1.4
			local out = V(math.cos(a), 0, math.sin(a)) * (2.4 + (i % 2) * 1.4)
			blade(K, b + out * 0.15, b + out + V(0, len, 0), 0.75 + (i % 2) * 0.2, k)
			k += 1
		end
	end
end

function StudSwamp.build(K: Kit)
	pond(K)
	lilyPads(K)
	bigPad(K)
	deck(K)
	ladderDock(K)
	hutWalls(K)
	door(K)
	roof(K)
	lights(K)
	vines(K)
	bubbles(K)
	boat(K)
	reeds(K)
end

return StudSwamp
