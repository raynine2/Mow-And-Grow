--!strict
-- STUD WINDMILL (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar. Maar laat het eerst zien en maak het
-- super hoog kwaliteit dus echt perfect ... niet sloppy"). The lobby's windmill (the ForgeGUI mesh forge_windmill)
-- built again from studded bricks, like a toy-brick set: an eight-sided tower narrowing as it rises (white plaster
-- between dark timber posts and beams) on a stone footing, an arched door in a stone surround, small arched windows
-- with flower boxes, a plank balcony with a rail on brackets, a stepped red roof cone with a cap and a spire, and four
-- latticed sails with canvas. Same footprint, height and colours as the mesh (104 studs, front to -Z).
-- StudWindmill.build(parent, pivot) -> the Model (pivot: the bottom middle, LookVector = the front).
local StudWindmill = {}

local C = Color3.fromRGB
local PAL = {
	stone = C(160, 154, 144),
	stoneDark = C(128, 122, 114),
	plaster = C(236, 231, 218),
	plasterShade = C(222, 215, 200),
	timber = C(82, 55, 40),
	timberLight = C(124, 84, 56),
	plank = C(150, 104, 68),
	plankDark = C(132, 90, 58),
	roof = C(178, 56, 44),
	roofDark = C(150, 44, 36),
	cap = C(54, 56, 66),
	trim = C(206, 178, 132),
	trimDark = C(184, 156, 112),
	door = C(102, 66, 42),
	glass = C(44, 58, 80),
	canvas = C(242, 238, 228),
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
	p.Color = color
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
	p.Color = color
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
local FOOT_A = 15 -- the stone footing
local LOW_A = 13 -- the tower's apothem at the bottom, kept for the first 12 studs (the door's courses)
local DOOR_W, DOOR_H = 6, 10

-- the tower's apothem at height y (straight to 14, then narrowing to 10 at 60)
local function towerA(y: number): number
	if y <= 14 then
		return LOW_A
	end
	return LOW_A - (y - 14) / (60 - 14) * 3
end

local function footing()
	-- two stone courses, each side its own stone in two tones, the upper one stepped in
	ring("Footing", 0, 1.2, FOOT_A, 4, { PAL.stone, PAL.stoneDark })
	ring("Footing", 1.2, 0.8, FOOT_A - 0.8, 3, { PAL.stoneDark, PAL.stone })
	-- the floor inside (covered, keeps the middle solid)
	brick("Core", Vector3.new(15, 2, 15), CFrame.new(0, 1, 0), PAL.stoneDark)
	-- a step up to the door
	brick("Step", Vector3.new(DOOR_W + 3, 0.8, 3), face(0, FOOT_A + 1.5, 0.4), PAL.stone)
end

local function walls()
	local y = 2
	while y < 60 do
		local h = math.min(4, 60 - y)
		local a = towerA(y + h / 2)
		-- the front side's lowest three courses are the door's: built round the door below
		local skip = if y < 14 then { [0] = true } else nil
		ring("Wall", y, h, a, 2, if (math.floor((y - 2) / 4)) % 2 == 0 then PAL.plaster else PAL.plasterShade, skip)
		posts("Post", y, h, a, 1.4, PAL.timber)
		y += h
	end
	-- the timber beams round the tower: the sill, two belts and the top plate
	for _, by in { 2, 14, 26, 46, 59.2 } do
		ring("Beam", by - 0.4, 0.8, towerA(by) + 0.35, 1, PAL.timber)
	end
	-- the inside, so nothing shows through a gap
	brick("Core", Vector3.new(11, 58, 11), CFrame.new(0, 31, 0), PAL.plasterShade) -- (inside the narrowest course)
end

-- the arched door in the front side: jambs, the wall over it, a stone surround with a stepped arch and a keystone,
-- a plank door set back with its iron bands and a ring pull
local function door()
	local a = LOW_A
	local s = 2 * a * TAN
	local side = (s - DOOR_W) / 2
	for k = -1, 1, 2 do
		brick("Wall", Vector3.new(side, 12, 2), face(0, a - 1, 8) * CFrame.new(k * (DOOR_W / 2 + side / 2), 0, 0), PAL.plaster)
	end
	brick("Wall", Vector3.new(DOOR_W, 2, 2), face(0, a - 1, 2 + DOOR_H + 1), PAL.plaster)
	-- the stone surround (proud of the wall)
	local out = 0.5
	for k = -1, 1, 2 do
		brick("Arch", Vector3.new(1.2, DOOR_H - 2, 1.4), face(0, a + out, 2 + (DOOR_H - 2) / 2) * CFrame.new(k * (DOOR_W / 2 + 0.6), 0, 0.2), PAL.trim)
		-- the arch's shoulders, stepping in
		brick("Arch", Vector3.new(1.6, 1, 1.4), face(0, a + out, 2 + DOOR_H - 1.5) * CFrame.new(k * (DOOR_W / 2 + 0.2), 0, 0.2), PAL.trimDark)
		brick("Arch", Vector3.new(1.8, 1, 1.4), face(0, a + out, 2 + DOOR_H - 0.5) * CFrame.new(k * (DOOR_W / 2 - 0.6), 0, 0.2), PAL.trim)
		brick("Arch", Vector3.new(1.6, 1, 1.4), face(0, a + out, 2 + DOOR_H + 0.5) * CFrame.new(k * (DOOR_W / 2 - 1.8), 0, 0.2), PAL.trimDark)
	end
	brick("Keystone", Vector3.new(2, 1.6, 1.6), face(0, a + out, 2 + DOOR_H + 1.1) * CFrame.new(0, 0, 0.1), PAL.trim)
	-- the door, set back, in four planks
	for k = 0, 3 do
		local x = -DOOR_W / 2 + 0.75 + k * 1.5
		local tall = DOOR_H - (if k == 0 or k == 3 then 1.4 else 0.6)
		brick("Door", Vector3.new(1.45, tall, 0.6), face(0, a - 1.2, 2 + tall / 2) * CFrame.new(x, 0, 0), if k % 2 == 0 then PAL.door else PAL.timberLight)
	end
	for _, by in { 4.2, 8.6 } do
		brick("DoorBand", Vector3.new(DOOR_W - 0.4, 0.4, 0.3), face(0, a - 0.85, by), PAL.cap)
	end
	brick("DoorRing", Vector3.new(0.6, 0.6, 0.4), face(0, a - 0.7, 6.4) * CFrame.new(1.6, 0, 0), PAL.brass)
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

-------------------------------------------------------------------------------------------------------------
-- the balcony
-------------------------------------------------------------------------------------------------------------
local DECK_Y = 34
local DECK_A = 18.5

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
local ROOF_Y = 60
local ROOF_STEPS = 13

local function roof()
	-- the eave beam, then the cone in rows of tiles, each row a little in from the one under it
	ring("Eave", ROOF_Y - 0.6, 0.8, 14.2, 2, PAL.timber)
	for k = 0, ROOF_STEPS - 1 do
		local a = 14 - k * (12.6 / (ROOF_STEPS - 1))
		local thick = math.min(a, 3.2)
		ring("Roof", ROOF_Y + k * 2, 2, a, thick, if k % 2 == 0 then PAL.roof else PAL.roofDark)
	end
	-- the cap: two dark octagons, a spire and a brass finial
	local top = ROOF_Y + ROOF_STEPS * 2
	ring("Cap", top, 1.2, 2.2, 2.2, PAL.cap)
	ring("Cap", top + 1.2, 1, 1.4, 1.4, PAL.cap)
	brick("Spire", Vector3.new(0.6, 7, 0.6), CFrame.new(0, top + 2.2 + 3.5, 0), PAL.cap)
	local ball = brick("Finial", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, top + 9.6, 0), PAL.brass)
	ball.Shape = Enum.PartType.Ball
end

-------------------------------------------------------------------------------------------------------------
-- the sails
-------------------------------------------------------------------------------------------------------------
local HUB_Y = 67
local HUB_Z = -12.6 -- in front of the roof
local ARM = 34

local function sails(): Model
	local m = Instance.new("Model")
	m.Name = "Sails"
	m.Parent = model
	-- the axle out of the roof and the hub on it
	brick("Axle", Vector3.new(1.6, 1.6, 4), CFrame.new(0, HUB_Y, HUB_Z + 1.6), PAL.cap, m)
	local hub = CFrame.new(0, HUB_Y, HUB_Z - 0.6)
	for k = 0, 1 do
		brick("Hub", Vector3.new(3.4, 3.4, 1.4), hub * CFrame.Angles(0, 0, k * EIGHTH), PAL.cap, m)
	end
	local cap = brick("HubCap", Vector3.new(1.6, 1.6, 1.6), hub * CFrame.new(0, 0, -0.9), PAL.brass, m)
	cap.Shape = Enum.PartType.Ball
	for s = 0, 3 do
		-- an arm: X along the arm, Y across it, -Z out of the front
		local arm = hub * CFrame.Angles(0, 0, math.rad(45) + s * math.pi / 2)
		brick("Spar", Vector3.new(ARM, 1, 0.9), arm * CFrame.new(ARM / 2, 0, -0.3), PAL.timber, m)
		-- the sail on one side of the spar: canvas behind a lattice of laths, an outer rail
		local from, to = 6, ARM - 0.5
		local width = 5.6
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
	window(1, 9, 2.4, 3.2, true)
	window(7, 9, 2.4, 3.2, true)
	window(0, 20, 2.6, 3.4, false)
	window(0, 41, 3.4, 4.4, true)
	window(2, 30, 2.4, 3.4, false)
	window(6, 30, 2.4, 3.4, false)
	window(2, 50, 2.2, 3, false)
	window(6, 50, 2.2, 3, false)
	window(4, 22, 2.6, 3.4, true)
	balcony()
	roof()
	sails()
	model:SetAttribute("Bricks", count)
	model.PrimaryPart = nil
	model.WorldPivot = pivot
	model.Parent = parent
	return model
end

return StudWindmill
