--!strict
-- STUD WINDMILL (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar. Maar laat het eerst zien en maak het
-- super hoog kwaliteit dus echt perfect ... niet sloppy"). The lobby's windmill (the ForgeGUI mesh forge_windmill)
-- built again from studded bricks, like a toy-brick set: an eight-sided tower narrowing as it rises (white plaster
-- between dark timber posts and beams) on a stone footing, an arched door in a stone surround, small arched windows
-- with flower boxes, a plank balcony with a rail on brackets, a stepped red roof cone with a cap and a spire, and four
-- latticed sails with canvas. Same footprint, height and colours as the mesh (104 studs, front to -Z).
-- StudWindmill.build(parent, pivot) -> the Model (pivot: the bottom middle, LookVector = the front).
local StudWindmill = {}

-- (7 Nov, owner, of the stud house: "Moet meer accuraat zijn en donkerder doe dat bij elke het moet niet zo bright
-- zijn") every stud-built ForgeGUI model is drawn a shade darker than its palette: plastic with studs reads far
-- brighter in the game's light than the painted meshes did. Config.STUD_FORGE.tone (1 = the palette as written).
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
-- (15:48, owner: "Donkerder, zoals origineel", "Hij is beetje te licht") the mesh's darker tones: grey plaster between
-- near-black timber, a deep red roof, a dark stone footing
local PAL = {
	stone = C(112, 108, 104),
	stoneDark = C(88, 85, 84),
	plaster = C(204, 197, 184),
	plasterShade = C(190, 182, 170),
	timber = C(52, 35, 27),
	timberLight = C(88, 60, 42),
	plank = C(112, 76, 50),
	plankDark = C(96, 64, 42),
	roof = C(150, 44, 36),
	roofDark = C(124, 34, 28),
	cap = C(48, 50, 60),
	trim = C(170, 152, 122),
	trimDark = C(150, 134, 106),
	door = C(84, 54, 36),
	glass = C(36, 46, 64),
	canvas = C(220, 214, 202),
	sack = C(206, 188, 152),
	sackDark = C(184, 166, 132),
	shutter = C(70, 48, 34),
	leaf = C(74, 152, 62),
	leafDark = C(58, 128, 50),
	flowerA = C(255, 122, 152),
	flowerB = C(255, 208, 76),
	flowerC = C(170, 120, 255),
	brass = C(212, 170, 76),
}

local STUDS = Enum.SurfaceType.Studs
local INLET = Enum.SurfaceType.Inlet
local TAN = math.tan(math.rad(22.5))
local COS = math.cos(math.rad(22.5))
local EIGHTH = math.pi / 4

-- the build in progress
local model: Model = nil :: any
local origin = CFrame.identity
local count = 0

-- one studded brick (studs on top and the sides, an inlet under it), `cf` in the windmill's own space
local function brick(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = origin * cf
	p.Color = toned(color)
	p.Material = Enum.Material.Plastic
	p.TopSurface = STUDS
	p.FrontSurface = STUDS
	p.BackSurface = STUDS
	p.LeftSurface = STUDS
	p.RightSurface = STUDS
	p.BottomSurface = INLET
	p.Parent = parent or model
	count += 1
	return p
end

local function wedge(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = origin * cf
	p.Color = toned(color)
	p.Material = Enum.Material.Plastic
	p.TopSurface = STUDS
	p.FrontSurface = STUDS
	p.BackSurface = STUDS
	p.LeftSurface = STUDS
	p.RightSurface = STUDS
	p.BottomSurface = INLET
	p.Parent = parent or model
	count += 1
	return p
end

-- the frame of side i (0 = the front, counting round to the left): its outer face's middle at height y, apothem a;
-- in it, X runs along the side and -Z points out
local function face(i: number, a: number, y: number): CFrame
	return CFrame.Angles(0, i * EIGHTH, 0) * CFrame.new(0, y, -a)
end

-- a course of eight side bricks, outer faces at apothem a, from y to y + h, `thick` deep (`skip`: sides left out)
local function ring(name: string, y: number, h: number, a: number, thick: number, color: Color3 | { Color3 }, skip: { [number]: boolean }?)
	local s = 2 * a * TAN
	for i = 0, 7 do
		if not (skip and skip[i]) then
			local col = if typeof(color) == "Color3" then color else color[i % #color + 1]
			brick(name, Vector3.new(s, h, thick), face(i, a - thick / 2, y + h / 2), col)
		end
	end
end

-- the timber posts on the eight corners, from y to y + h (w across), standing a little proud of apothem a
local function posts(name: string, y: number, h: number, a: number, w: number, color: Color3)
	local r = a / COS
	for i = 0, 7 do
		local cf = CFrame.Angles(0, i * EIGHTH + EIGHTH / 2, 0) * CFrame.new(0, y + h / 2, -(r - w * 0.3))
		brick(name, Vector3.new(w, h, w), cf, color)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the tower
-------------------------------------------------------------------------------------------------------------
-- (sizes from the mesh: its filler Core, a stack of rings inside it, is 21 across at the foot and 19 at the tower's
-- bottom, 17 under the balcony)
local FOOT_A = 22 -- the stone footing
local DB = 3 -- the footing's top: the tower and the door stand on it
local LOW_A = 19 -- the tower's apothem at the bottom, kept up to the door's top
local DOOR_TOP = 15
local TOP = 56 -- the tower's top, where the roof sits
local DOOR_W, DOOR_H = 7, 11

-- the tower's apothem at height y (straight to the door's top, then narrowing to 14.5 at the top)
local function towerA(y: number): number
	if y <= DOOR_TOP then
		return LOW_A
	end
	return LOW_A - (y - DOOR_TOP) / (TOP - DOOR_TOP) * 4.5
end

local function footing()
	-- two stone courses, each side its own stone in two tones, the upper one stepped in
	ring("Footing", 0, 1.5, FOOT_A, 4, { PAL.stone, PAL.stoneDark })
	ring("Footing", 1.5, DB - 1.5, FOOT_A - 1, 3.5, { PAL.stoneDark, PAL.stone })
	-- the floor inside (covered, keeps the middle solid)
	brick("Core", Vector3.new(22, DB, 22), CFrame.new(0, DB / 2, 0), PAL.stoneDark)
	-- a step up to the door
	brick("Step", Vector3.new(DOOR_W + 4, 1.5, 2.5), face(0, FOOT_A + 1.25, 0.75), PAL.stone)
end

local function walls()
	local y = DB
	while y < TOP do
		local h = math.min(4, TOP - y)
		local a = towerA(y + h / 2)
		-- the front side's lowest three courses are the door's: built round the door below
		local skip = if y < DOOR_TOP then { [0] = true } else nil
		ring("Wall", y, h, a, 2.5, if (math.floor((y - DB) / 4)) % 2 == 0 then PAL.plaster else PAL.plasterShade, skip)
		posts("Post", y, h, a, 1.4, PAL.timber)
		y += h
	end
	-- the timber beams round the tower: the sill, two belts and the top plate
	for _, by in { DB, DOOR_TOP, 24, 44, TOP - 0.8 } do
		ring("Beam", by - 0.4, 0.8, towerA(by) + 0.35, 1, PAL.timber)
	end
	-- the inside, so nothing shows through a gap
	brick("Core", Vector3.new(15, TOP - DB, 15), CFrame.new(0, (DB + TOP) / 2, 0), PAL.plasterShade) -- (inside the narrowest course)
end

-- the arched door in the front side: jambs, the wall over it, a stone surround with a stepped arch and a keystone,
-- a plank door set back with its iron bands and a ring pull
local function door()
	local a = LOW_A
	local s = 2 * a * TAN
	local side = (s - DOOR_W) / 2
	for k = -1, 1, 2 do
		brick("Wall", Vector3.new(side, DOOR_TOP - DB, 2.5), face(0, a - 1.25, (DB + DOOR_TOP) / 2) * CFrame.new(k * (DOOR_W / 2 + side / 2), 0, 0), PAL.plaster)
	end
	brick("Wall", Vector3.new(DOOR_W, DOOR_TOP - DB - DOOR_H, 2.5), face(0, a - 1.25, (DB + DOOR_H + DOOR_TOP) / 2), PAL.plaster)
	-- the stone surround (proud of the wall)
	local out = 0.5
	for k = -1, 1, 2 do
		brick("Arch", Vector3.new(1.2, DOOR_H - 2, 1.4), face(0, a + out, DB + (DOOR_H - 2) / 2) * CFrame.new(k * (DOOR_W / 2 + 0.6), 0, 0.2), PAL.trim)
		-- the arch's shoulders, stepping in
		brick("Arch", Vector3.new(1.6, 1, 1.4), face(0, a + out, DB + DOOR_H - 1.5) * CFrame.new(k * (DOOR_W / 2 + 0.2), 0, 0.2), PAL.trimDark)
		brick("Arch", Vector3.new(1.8, 1, 1.4), face(0, a + out, DB + DOOR_H - 0.5) * CFrame.new(k * (DOOR_W / 2 - 0.6), 0, 0.2), PAL.trim)
		brick("Arch", Vector3.new(1.6, 1, 1.4), face(0, a + out, DB + DOOR_H + 0.5) * CFrame.new(k * (DOOR_W / 2 - 1.8), 0, 0.2), PAL.trimDark)
	end
	brick("Keystone", Vector3.new(2, 1.6, 1.6), face(0, a + out, DB + DOOR_H + 1.1) * CFrame.new(0, 0, 0.1), PAL.trim)
	-- the door, set back, in four planks
	local plank = DOOR_W / 4
	for k = 0, 3 do
		local x = -DOOR_W / 2 + plank / 2 + k * plank
		local tall = DOOR_H - (if k == 0 or k == 3 then 1.4 else 0.6)
		brick("Door", Vector3.new(plank - 0.05, tall, 0.6), face(0, a - 1.2, DB + tall / 2) * CFrame.new(x, 0, 0), if k % 2 == 0 then PAL.door else PAL.timberLight)
	end
	for _, by in { DB + 2.2, DB + 7 } do
		brick("DoorBand", Vector3.new(DOOR_W - 0.4, 0.4, 0.3), face(0, a - 0.85, by), PAL.cap)
	end
	brick("DoorRing", Vector3.new(0.6, 0.6, 0.4), face(0, a - 0.7, DB + 4.6) * CFrame.new(1.9, 0, 0), PAL.brass)
end

-- a small arched window on side i at height y (w wide, h tall): a timber frame, dark glass with a cross bar, an arched
-- top in two steps, a sill; `box` adds a flower box under it
local function window(i: number, y: number, w: number, h: number, box: boolean)
	local a = towerA(y) + 0.2
	local f = face(i, a, y)
	brick("WindowGlass", Vector3.new(w, h, 0.4), f * CFrame.new(0, 0, 0.1), PAL.glass)
	for k = -1, 1, 2 do
		brick("WindowFrame", Vector3.new(0.6, h, 0.7), f * CFrame.new(k * (w / 2 + 0.3), 0, -0.05), PAL.timber)
	end
	brick("WindowFrame", Vector3.new(w + 1.2, 0.6, 0.7), f * CFrame.new(0, -h / 2 - 0.3, -0.05), PAL.timber)
	-- the arch: two steps of frame over the glass
	brick("WindowGlass", Vector3.new(w - 1, 0.8, 0.4), f * CFrame.new(0, h / 2 + 0.4, 0.1), PAL.glass)
	for k = -1, 1, 2 do
		brick("WindowFrame", Vector3.new(0.9, 0.8, 0.7), f * CFrame.new(k * (w / 2 - 0.15), h / 2 + 0.4, -0.05), PAL.timber)
	end
	brick("WindowFrame", Vector3.new(w - 0.6, 0.6, 0.7), f * CFrame.new(0, h / 2 + 1.1, -0.05), PAL.timber)
	-- the cross bar
	brick("WindowBar", Vector3.new(w, 0.3, 0.5), f * CFrame.new(0, 0.2, 0), PAL.timber)
	brick("WindowBar", Vector3.new(0.3, h, 0.5), f, PAL.timber)
	-- (15:48, owner: "Meer details") a shutter open on each side, two battens across it
	local sw = w / 2 + 0.2
	for k = -1, 1, 2 do
		local sh = f * CFrame.new(k * (w / 2 + 0.6 + sw / 2), 0.4, -0.25)
		brick("Shutter", Vector3.new(sw, h + 0.8, 0.4), sh, PAL.shutter)
		for _, by in { -h / 4, h / 4 + 0.4 } do
			brick("ShutterBatten", Vector3.new(sw - 0.3, 0.4, 0.3), sh * CFrame.new(0, by, -0.3), PAL.timber)
		end
	end
	if box then
		local b = f * CFrame.new(0, -h / 2 - 1.2, -0.7)
		brick("FlowerBox", Vector3.new(w + 1.6, 1.2, 1.4), b, PAL.plank)
		brick("FlowerBox", Vector3.new(w + 1.6, 0.3, 1.5), b * CFrame.new(0, -0.45, 0), PAL.timber)
		-- leaves along it, flowers between
		local n = math.max(3, math.floor(w + 1))
		for k = 0, n - 1 do
			local x = -(w + 0.8) / 2 + (k + 0.5) * (w + 0.8) / n
			brick("Leaves", Vector3.new(0.9, 0.6, 0.9), b * CFrame.new(x, 0.9, (k % 2) * 0.3 - 0.15), if k % 2 == 0 then PAL.leaf else PAL.leafDark)
			if k % 2 == 1 or n <= 3 then
				local col = ({ PAL.flowerA, PAL.flowerB, PAL.flowerC })[(k % 3) + 1]
				brick("Flower", Vector3.new(0.7, 0.7, 0.7), b * CFrame.new(x, 1.45, -0.1), col)
			end
		end
	end
end

-- (15:48, "Meer details") half-timbering on the four diagonal sides (no windows there): in every panel between the
-- beams two braces rising from its bottom corners to meet at its top middle, as on the mesh
local function braces(i: number, y0: number, y1: number)
	local a = towerA((y0 + y1) / 2)
	local s = 2 * a * TAN - 1.6 -- (between the corner posts)
	local h = y1 - y0 - 0.9 -- (between the beams)
	local f = face(i, a + 0.25, (y0 + y1) / 2)
	local len = math.sqrt((s / 2) ^ 2 + h ^ 2)
	local tilt = math.atan2(h, s / 2)
	for k = -1, 1, 2 do
		brick("Brace", Vector3.new(len, 0.8, 0.6), f * CFrame.new(k * s / 4, 0, if k < 0 then 0 else -0.04) * CFrame.Angles(0, 0, -k * tilt), PAL.timber)
	end
end

-- flour sacks on the footing left of the door, a crate on the right
local function doorstep()
	local ledge = LOW_A + 1 -- (the footing's ledge in front of the wall is 2 studs deep)
	local f = face(0, ledge, DB)
	local function sack(x: number, y: number, yaw: number, roll: number, col: Color3)
		local cf = f * CFrame.new(x, y + 1.1, 0) * CFrame.Angles(0, math.rad(yaw), math.rad(roll))
		brick("Sack", Vector3.new(1.8, 2.2, 1.5), cf, col)
		brick("SackTie", Vector3.new(0.8, 0.5, 0.8), cf * CFrame.new(0, 1.3, 0), PAL.sackDark)
		brick("SackTie", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 1.7, 0), PAL.timber)
	end
	sack(-6.1, 0, 8, 0, PAL.sack)
	sack(-7.9, 0, -12, 0, PAL.sackDark)
	sack(-7, 2.1, 20, 14, PAL.sack)
	local c = f * CFrame.new(6.5, 1.1, 0) * CFrame.Angles(0, math.rad(-6), 0)
	brick("Crate", Vector3.new(2.2, 2.2, 2.0), c, PAL.plank)
	for _, e in { 0.95, -0.95 } do
		brick("CrateEdge", Vector3.new(2.4, 0.3, 2.1), c * CFrame.new(0, e, 0), PAL.timber)
	end
	for k = -1, 1, 2 do
		brick("CrateEdge", Vector3.new(0.3, 2.2, 2.1), c * CFrame.new(k * 0.95, 0, 0), PAL.timber)
	end
	-- apples in it
	for k = 0, 2 do
		local apple = brick("Apple", Vector3.new(0.7, 0.7, 0.7), c * CFrame.new(-0.55 + k * 0.55, 1.3, (k % 2) * 0.35 - 0.15), Color3.fromRGB(200, 50, 44))
		apple.Shape = Enum.PartType.Ball
	end
end

-------------------------------------------------------------------------------------------------------------
-- the balcony
-------------------------------------------------------------------------------------------------------------
local DECK_Y = 31
local DECK_A = 24.5

local function balcony()
	local inner = towerA(DECK_Y)
	-- the deck: planks round the tower in two tones, a darker edge beam
	ring("Deck", DECK_Y, 1, DECK_A, DECK_A - inner + 0.5, { PAL.plank, PAL.plankDark })
	ring("DeckEdge", DECK_Y - 0.6, 0.6, DECK_A + 0.2, 1, PAL.timber)
	-- the brackets under it: a timber strut from the wall out to the deck's edge on every corner
	local r0 = inner / COS
	local r1 = (DECK_A - 1) / COS
	for i = 0, 7 do
		local ang = i * EIGHTH + EIGHTH / 2
		local len = r1 - r0
		local cf = CFrame.Angles(0, ang, 0) * CFrame.new(0, DECK_Y - 2.5, -(r0 + len / 2))
		-- a wedge turned over: its full face up under the deck, tall against the wall, thin at the edge
		wedge("Bracket", Vector3.new(0.9, 5, len), cf * CFrame.Angles(0, 0, math.pi), PAL.timber)
	end
	-- the rail: posts on the corners and in each side's middle, a top rail and a middle rail
	local railA = DECK_A - 0.6
	posts("RailPost", DECK_Y + 1, 4, railA, 0.9, PAL.timber)
	for i = 0, 7 do
		brick("RailPost", Vector3.new(0.7, 4, 0.7), face(i, railA - 0.35, DECK_Y + 3), PAL.timber)
	end
	ring("Rail", DECK_Y + 4.4, 0.6, railA + 0.1, 0.8, PAL.timberLight)
	ring("Rail", DECK_Y + 2.4, 0.4, railA - 0.05, 0.5, PAL.timberLight)
end

-------------------------------------------------------------------------------------------------------------
-- the roof
-------------------------------------------------------------------------------------------------------------
local ROOF_Y = TOP
local ROOF_STEPS = 17
local ROOF_A = 21

local function roof()
	-- the eave beam, then the cone in rows of tiles, each row a little in from the one under it
	ring("Eave", ROOF_Y - 0.6, 0.8, ROOF_A + 0.2, 2, PAL.timber)
	for k = 0, ROOF_STEPS - 1 do
		local a = ROOF_A - k * ((ROOF_A - 1.6) / (ROOF_STEPS - 1))
		local thick = math.min(a, 3.2)
		ring("Roof", ROOF_Y + k * 2, 2, a, thick, if k % 2 == 0 then PAL.roof else PAL.roofDark)
	end
	-- (15:48, "Meer details") a bracket under the eave on every corner, from the wall up to the roof's edge
	local r0 = towerA(TOP) / COS
	local r1 = (ROOF_A - 0.6) / COS
	for i = 0, 7 do
		local len = r1 - r0
		local cf = CFrame.Angles(0, i * EIGHTH + EIGHTH / 2, 0) * CFrame.new(0, ROOF_Y - 2.4, -(r0 + len / 2))
		wedge("EaveBracket", Vector3.new(0.8, 3.2, len), cf * CFrame.Angles(0, 0, math.pi), PAL.timber)
	end
	-- the cap: two dark octagons, a spire and a brass finial
	local top = ROOF_Y + ROOF_STEPS * 2
	ring("Cap", top, 1.2, 2.4, 2.4, PAL.cap)
	ring("Cap", top + 1.2, 1, 1.5, 1.5, PAL.cap)
	brick("Spire", Vector3.new(0.6, 10, 0.6), CFrame.new(0, top + 2.2 + 5, 0), PAL.cap)
	local ball = brick("Finial", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, top + 12.6, 0), PAL.brass)
	ball.Shape = Enum.PartType.Ball
	-- a weather vane on the spire: an arrow with a tail fin
	local vane = CFrame.new(0, top + 9.6, 0) * CFrame.Angles(0, math.rad(30), 0)
	brick("Vane", Vector3.new(5.2, 0.3, 0.3), vane, PAL.cap)
	wedge("Vane", Vector3.new(0.3, 0.9, 1.2), vane * CFrame.new(3, 0, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(90), 0, 0), PAL.brass)
	brick("Vane", Vector3.new(1.4, 1.2, 0.15), vane * CFrame.new(-2.4, 0.3, 0), PAL.brass)
end

-------------------------------------------------------------------------------------------------------------
-- the sails
-------------------------------------------------------------------------------------------------------------
local HUB_Y = 70
local HUB_Z = -20 -- well in front of the roof, so the lower sails clear the tower by ~3 studs
local ARM = 30 -- (turning, its lowest tip stays clear over the balcony rail: 70 - 30 = 40 > 36)

local function sails(): Model
	local m = Instance.new("Model")
	m.Name = "Sails"
	m.Parent = model
	-- the axle out of the roof and the hub on it
	-- (the roof's front at the hub's height: the axle runs from there, a collar where it leaves the tiles)
	local roofFront = ROOF_A - ((HUB_Y - ROOF_Y) / 2) * ((ROOF_A - 1.6) / (ROOF_STEPS - 1))
	local axleLen = roofFront + HUB_Z + 1.5
	brick("Axle", Vector3.new(1.8, 1.8, -axleLen + 3), CFrame.new(0, HUB_Y, (HUB_Z - roofFront + 1.5) / 2), PAL.cap, m)
	brick("AxleCollar", Vector3.new(2.6, 2.6, 0.8), CFrame.new(0, HUB_Y, -(roofFront + 0.3)), PAL.timber, m)
	local hub = CFrame.new(0, HUB_Y, HUB_Z - 0.6)
	for k = 0, 1 do
		brick("Hub", Vector3.new(4.4, 4.4, 1.6), hub * CFrame.Angles(0, 0, k * EIGHTH), PAL.cap, m)
	end
	local cap = brick("HubCap", Vector3.new(2.2, 2.2, 2.2), hub * CFrame.new(0, 0, -1.1), PAL.brass, m)
	cap.Shape = Enum.PartType.Ball
	for s = 0, 3 do
		-- an arm: X along the arm, Y across it, -Z out of the front
		local arm = hub * CFrame.Angles(0, 0, math.rad(45) + s * math.pi / 2)
		brick("Spar", Vector3.new(ARM, 1, 0.9), arm * CFrame.new(ARM / 2, 0, -0.3), PAL.timber, m)
		-- the sail on one side of the spar: canvas behind a lattice of laths, an outer rail
		local from, to = 6, ARM - 0.5
		local width = 6.2
		local len = to - from
		local mid = (from + to) / 2
		brick("Canvas", Vector3.new(len, width, 0.3), arm * CFrame.new(mid, width / 2 + 0.5, 0.1), PAL.canvas, m)
		brick("SailRail", Vector3.new(len + 0.4, 0.6, 0.6), arm * CFrame.new(mid, width + 0.7, -0.35), PAL.timberLight, m)
		local laths = 8
		for k = 0, laths do
			local x = from + k * len / laths
			brick("Lath", Vector3.new(0.5, width + 0.8, 0.5), arm * CFrame.new(x, width / 2 + 0.6, -0.45), PAL.timberLight, m)
		end
		brick("Lath", Vector3.new(len, 0.4, 0.45), arm * CFrame.new(mid, width / 2 + 0.5, -0.5), PAL.timberLight, m)
	end
	-- (15:48, owner: "Wieken laten draaien") every client turns them about the axle (client/SpinSails); they don't
	-- collide (only the clients move them)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	m:SetAttribute("SpinHub", origin * hub)
	m:SetAttribute("SpinSpeed", 0.35)
	game:GetService("CollectionService"):AddTag(m, "SpinSails")
	return m
end

-------------------------------------------------------------------------------------------------------------
function StudWindmill.build(parent: Instance, pivot: CFrame): Model
	model = Instance.new("Model")
	model.Name = "StudWindmill"
	origin = pivot
	count = 0
	footing()
	walls()
	door()
	-- the windows: two small ones flanking the door, one over the door's beam, the big one over the balcony with
	-- flowers, and one on each side up high
	window(1, 10, 3, 4, true)
	window(7, 10, 3, 4, true)
	window(0, 21, 3.2, 4.2, false)
	window(0, 39.5, 4.2, 5.2, true)
	window(2, 21, 3, 4, false)
	window(6, 21, 3, 4, false)
	window(2, 46, 2.8, 3.6, false)
	window(6, 46, 2.8, 3.6, false)
	window(4, 21, 3.2, 4.2, true)
	window(4, 46, 2.8, 3.6, false)
	for _, i in { 1, 3, 5, 7 } do
		for _, span in { { DOOR_TOP, 24 }, { 24, DECK_Y }, { DECK_Y + 1, 44 }, { 44, TOP - 0.8 } } do
			braces(i, span[1], span[2])
		end
	end
	doorstep()
	balcony()
	roof()
	sails()
	model:SetAttribute("Bricks", count)
	model.PrimaryPart = nil
	model:SetAttribute("StudBuilt", true) -- (server/StudLook leaves it as built)
	model.WorldPivot = pivot
	model.Parent = parent
	return model
end

return StudWindmill
