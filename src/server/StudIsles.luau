--!strict
-- STUD ISLES (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar ... super hoog kwaliteit", "Moet meer
-- accuraat zijn en donkerder", "Ga verder dan"). The seven landmarks on the lobby's floating isles (forge_lm_<kind>)
-- rebuilt from studded bricks (server/StudKit) to their own layouts, from pictures of each from its front:
--   wheat     the farm, in server/StudWheat (redone 7 Nov from measurements after the owner's "very very bad")
--   swamp     the stilt hut, in server/StudSwamp (redone 7 Nov from measurements)
--   pine      the lookout round a pine, in server/StudPine (redone 7 Nov from measurements)
--   frost     the snowy chalet, in server/StudFrost (redone 7 Nov from measurements)
--   ember     the forge in the volcano, in server/StudEmber (redone 7 Nov from measurements)
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

-- a hanging lantern: a little cap, glowing glass, a ring (warm ones soft, the swamp's green ones neon)
local LANTERN_NEON = C(150, 255, 150)
local function lantern(K: Kit, at: Vector3, col: Color3, hangTo: number?)
	if hangTo and hangTo > at.Y + 0.8 then
		K:box("LanternChain", at.X - 0.06, at.Y + 0.8, at.Z - 0.06, at.X + 0.06, hangTo, at.Z + 0.06, C(60, 50, 40), true)
	end
	K:box("LanternCap", at.X - 0.45, at.Y + 0.55, at.Z - 0.45, at.X + 0.45, at.Y + 0.8, at.Z + 0.45, C(60, 50, 40), true)
	K:glow("LanternGlass", Vector3.new(0.7, 1.1, 0.7), CFrame.new(at), col, 7, col ~= LANTERN_NEON)
	K:box("LanternBase", at.X - 0.4, at.Y - 0.7, at.Z - 0.4, at.X + 0.4, at.Y - 0.55, at.Z + 0.4, C(60, 50, 40), true)
end

-------------------------------------------------------------------------------------------------------------
-- WHEAT: the farm, in its own module (server/StudWheat), measured off square-on pictures of the mesh
-------------------------------------------------------------------------------------------------------------
local function wheat(K: Kit)
	require(script.Parent.StudWheat).build(K)
end

-------------------------------------------------------------------------------------------------------------
-- SWAMP: the hut on stilts, in its own module (server/StudSwamp), measured off square-on pictures of the mesh
-------------------------------------------------------------------------------------------------------------
local function swamp(K: Kit)
	require(script.Parent.StudSwamp).build(K)
end

-------------------------------------------------------------------------------------------------------------
-- PINE: the lookout tower, in its own module (server/StudPine), measured off square-on pictures of the mesh
-------------------------------------------------------------------------------------------------------------
local function pine(K: Kit)
	require(script.Parent.StudPine).build(K)
end

-------------------------------------------------------------------------------------------------------------
-- FROST: the snowy chalet, in its own module (server/StudFrost), measured off square-on pictures of the mesh
-------------------------------------------------------------------------------------------------------------
local function frost(K: Kit)
	require(script.Parent.StudFrost).build(K)
end

-------------------------------------------------------------------------------------------------------------
-- EMBER: the forge in the volcano, in its own module (server/StudEmber), measured off square-on pictures of the mesh
-------------------------------------------------------------------------------------------------------------
local function ember(K: Kit)
	require(script.Parent.StudEmber).build(K)
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
	K:cyl("RoofBand", R * 1.05, 0.6, c + Vector3.new(0, y0 + 3.1, 0), CREAM[1])
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

-- a four-point gold sparkle (as the mesh's stars) facing out along `cf`'s -Z: four triangular points round a diamond
local function star(K: Kit, cf: CFrame, s: number)
	local w, h, t = 0.7 * s, 1.1 * s, 0.3 * s
	for k = 0, 3 do
		local p = cf * CFrame.Angles(0, 0, k * math.pi / 2)
		K:wedge("StarPoint", Vector3.new(t, h, w / 2), p * CFrame.new(-w / 4, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), GOLDEN[1], true)
		K:wedge("StarPoint", Vector3.new(t, h, w / 2), p * CFrame.new(w / 4, h / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), GOLDEN[1], true)
	end
	K:brick("StarHeart", Vector3.new(w * 0.95, w * 0.95, t * 1.3), cf * CFrame.Angles(0, 0, math.rad(45)), GOLDEN[2], true)
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
