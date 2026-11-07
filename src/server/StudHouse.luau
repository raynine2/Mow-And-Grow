--!strict
-- STUD HOUSE (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar ... maak het super hoog kwaliteit", then
-- of the windmill "Top, zet hem erin en doe de rest"). The ForgeGUI cottages (forge_house_blue: the lobby's CLASSES
-- house; forge_house_red) built again from studded bricks: a stone footing, clapboard walls in two tones with white
-- corner boards, a stepped tiled roof with a front cross-gable on the left and a dormer on the right, a porch with
-- white posts and its own little gable over the door, shuttered windows with flower boxes, a chimney, a climbing rose
-- and potted plants. Same footprint and height as the mesh (19 wide, 21 deep with the porch, 23 tall), front to -Z.
-- StudHouse.build(parent, pivot, look?) -> the Model (pivot: the bottom middle, LookVector = the front).
local StudHouse = {}

local C = Color3.fromRGB

export type Look = {
	wall: Color3,
	wallShade: Color3,
	roof: Color3,
	roofDark: Color3,
	shutter: Color3,
	door: Color3,
}

StudHouse.LOOKS = {
	blue = { wall = C(238, 200, 98), wallShade = C(224, 184, 84), roof = C(42, 62, 118), roofDark = C(34, 50, 98), shutter = C(52, 118, 176), door = C(178, 42, 46) },
	red = { wall = C(238, 226, 206), wallShade = C(222, 208, 186), roof = C(168, 52, 44), roofDark = C(140, 40, 34), shutter = C(70, 118, 74), door = C(64, 96, 150) },
} :: { [string]: Look }

local TRIM = C(244, 240, 230)
local STONE = C(152, 140, 122)
local STONE_DARK = C(126, 114, 100)
local WOOD = C(152, 102, 64)
local WOOD_DARK = C(124, 82, 52)
local GLASS = C(58, 86, 124)
local BRASS = C(212, 170, 76)
local LEAF = C(70, 146, 58)
local LEAF_DARK = C(52, 120, 46)
local POT = C(186, 96, 60)
local ROSE = { C(232, 64, 84), C(255, 120, 150), C(214, 40, 64) }

local STUDS = Enum.SurfaceType.Studs
local INLET = Enum.SurfaceType.Inlet

local model: Model = nil :: any
local origin = CFrame.identity
local look: Look = StudHouse.LOOKS.blue
local count = 0

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

-- a box from corner (x0, y0, z0) to (x1, y1, z1), in the house's own space
local function box(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3): Part
	return brick(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color)
end

-------------------------------------------------------------------------------------------------------------
-- sizes (the mesh: 19 x 23.3 x 21.3; its filler HouseCore boxes sit inside these walls)
-------------------------------------------------------------------------------------------------------------
local FOOT = 2 -- the stone footing's top
local EAVE = 13 -- the walls' top
local MX = 9 -- the main block: x -MX..MX
local MZ0, MZ1 = -6, 7 -- and z
local WX0, WX1 = 1.5, 9 -- the cross-gable wing on the left, standing forward (flush with the main block's end)
local WZ = -8.5 -- its front
local DOOR_X = -1.4

-- clapboard: courses one stud tall in two tones, from y0 to y1, on a wall from (x0, z0) to (x1, z1) (axis-aligned,
-- `t` thick, the outer face at the given line)
local function clap(name: string, x0: number, z0: number, x1: number, z1: number, y0: number, y1: number)
	local y = y0
	local k = 0
	while y < y1 - 0.01 do
		local h = math.min(1, y1 - y)
		box(name, x0, y, z0, x1, y + h, z1, if k % 2 == 0 then look.wall else look.wallShade)
		y += h
		k += 1
	end
end

-- a stepped gable wall (the triangle under a roof's end): courses narrowing by `inset` per `stepH`, centred on c,
-- from half-width `half` at y0, in the plane z0..z1 (along X) or x0..x1 (along Z)
local function gableX(name: string, c: number, half: number, y0: number, stepH: number, inset: number, z0: number, z1: number)
	local k = 0
	local hw = half
	while hw > 0.4 do
		box(name, c - hw, y0 + k * stepH, z0, c + hw, y0 + (k + 1) * stepH, z1, if k % 2 == 0 then look.wall else look.wallShade)
		hw -= inset
		k += 1
	end
end

local function gableZ(name: string, c: number, half: number, y0: number, stepH: number, inset: number, x0: number, x1: number)
	local k = 0
	local hw = half
	while hw > 0.4 do
		box(name, x0, y0 + k * stepH, c - hw, x1, y0 + (k + 1) * stepH, c + hw, if k % 2 == 0 then look.wall else look.wallShade)
		hw -= inset
		k += 1
	end
end

-- a stepped tiled roof: layers `stepH` tall, each `inset` narrower each side; ridge along X (spanning z c-half..c+half,
-- x from a to b) or along Z. Each layer is a strip on either side (the roof is a shell over the walls) and a ridge cap.
local function roofX(name: string, c: number, half: number, a: number, b: number, y0: number, stepH: number, inset: number, frontB: number?, trimEnds: boolean?)
	-- (frontB: the front slope stops there instead of at b, where a wing's roof takes over)
	local k = 0
	local hw = half
	local function strip(x0: number, x1: number, z0: number, z1: number, col: Color3)
		box(name, x0, y0 + k * stepH, z0, x1, y0 + (k + 1) * stepH, z1, col)
		if trimEnds then
			-- white bargeboards: the strip's ends faced in trim
			box("Barge", x0 - 0.3, y0 + k * stepH, z0, x0, y0 + (k + 1) * stepH, z1, TRIM)
			box("Barge", x1, y0 + k * stepH, z0, x1 + 0.3, y0 + (k + 1) * stepH, z1, TRIM)
		end
	end
	while hw > inset * 1.2 do
		local col = if k % 2 == 0 then look.roof else look.roofDark
		local w = inset + 0.8
		strip(a, frontB or b, c - hw, c - hw + w, col)
		strip(a, b, c + hw - w, c + hw, col)
		hw -= inset
		k += 1
	end
	strip(a, b, c - hw, c + hw, if k % 2 == 0 then look.roof else look.roofDark)
	return y0 + (k + 1) * stepH
end

local function roofZ(name: string, c: number, half: number, a: number, b: number, y0: number, stepH: number, inset: number, trimFront: boolean?)
	local k = 0
	local hw = half
	local function strip(x0: number, x1: number, col: Color3)
		box(name, x0, y0 + k * stepH, a, x1, y0 + (k + 1) * stepH, b, col)
		if trimFront then
			box("Barge", x0, y0 + k * stepH, a - 0.3, x1, y0 + (k + 1) * stepH, a, TRIM)
		end
	end
	while hw > inset * 1.2 do
		local col = if k % 2 == 0 then look.roof else look.roofDark
		local w = inset + 0.8
		strip(c - hw, c - hw + w, col)
		strip(c + hw - w, c + hw, col)
		hw -= inset
		k += 1
	end
	strip(c - hw, c + hw, if k % 2 == 0 then look.roof else look.roofDark)
	return y0 + (k + 1) * stepH
end

-- a window on a wall facing -Z at its outer face z (or facing +X/-X with `side`): white frame, glass in four panes,
-- shutters with slats, a sill; `flowers` adds a box of flowers under it
local function window(cf: CFrame, w: number, h: number, flowers: boolean, shutters: boolean?)
	brick("WindowGlass", Vector3.new(w, h, 0.3), cf * CFrame.new(0, 0, 0.1), GLASS)
	for k = -1, 1, 2 do
		brick("WindowFrame", Vector3.new(0.5, h + 1, 0.6), cf * CFrame.new(k * (w / 2 + 0.25), 0, -0.1), TRIM)
	end
	brick("WindowFrame", Vector3.new(w + 1, 0.5, 0.6), cf * CFrame.new(0, h / 2 + 0.25, -0.1), TRIM)
	brick("WindowSill", Vector3.new(w + 1.6, 0.4, 0.9), cf * CFrame.new(0, -h / 2 - 0.2, -0.25), TRIM)
	brick("WindowBar", Vector3.new(w, 0.25, 0.4), cf, TRIM)
	brick("WindowBar", Vector3.new(0.25, h, 0.4), cf, TRIM)
	local sw = w * 0.4
	for k = -1, 1, 2 do
		if shutters == false then
			break
		end
		local s = cf * CFrame.new(k * (w / 2 + 0.5 + sw / 2), 0, -0.15)
		brick("Shutter", Vector3.new(sw, h + 0.6, 0.35), s, look.shutter)
		for j = -1, 1 do
			brick("ShutterSlat", Vector3.new(sw - 0.3, 0.2, 0.2), s * CFrame.new(0, j * h / 3.4, -0.25), C(40, 92, 140))
		end
	end
	if flowers then
		local b = cf * CFrame.new(0, -h / 2 - 1, -0.7)
		brick("FlowerBox", Vector3.new(w + 1.2, 0.9, 1.1), b, TRIM)
		local n = math.max(3, math.floor(w + 1.5))
		for k = 0, n - 1 do
			local x = -(w + 0.6) / 2 + (k + 0.5) * (w + 0.6) / n
			brick("Leaves", Vector3.new(0.8, 0.5, 0.8), b * CFrame.new(x, 0.7, 0), if k % 2 == 0 then LEAF else LEAF_DARK)
			local f = brick("Flower", Vector3.new(0.55, 0.55, 0.55), b * CFrame.new(x + 0.15, 1.15, -0.15), ROSE[k % 3 + 1])
			f.Shape = Enum.PartType.Ball
		end
	end
end

-- a face's frame: on the plane z = z0 looking out to -Z, centred at x, y
local function front(x: number, y: number, z0: number): CFrame
	return CFrame.new(x, y, z0)
end

-------------------------------------------------------------------------------------------------------------
local function footing()
	-- the main block's and the wing's footing in two-tone stones, the porch's deck
	local stones = 0
	for _, r in { { -MX - 0.5, MZ0 - 0.5, MX + 0.5, MZ1 + 0.5 }, { WX0, WZ - 0.5, WX1 + 0.5, MZ0 } } do
		local x0, z0, x1, z1 = r[1], r[2], r[3], r[4]
		-- along the front and back in 3-stud stones, the sides in one
		local x = x0
		while x < x1 - 0.01 do
			local w = math.min(3, x1 - x)
			box("Footing", x, 0, z0, x + w, FOOT, z0 + 1.2, if stones % 2 == 0 then STONE else STONE_DARK)
			box("Footing", x, 0, z1 - 1.2, x + w, FOOT, z1, if stones % 2 == 1 then STONE else STONE_DARK)
			x += w
			stones += 1
		end
		box("Footing", x0, 0, z0 + 1.2, x0 + 1.2, FOOT, z1 - 1.2, STONE)
		box("Footing", x1 - 1.2, 0, z0 + 1.2, x1, FOOT, z1 - 1.2, STONE_DARK)
		box("FootingCore", x0 + 1.2, 0, z0 + 1.2, x1 - 1.2, FOOT - 0.2, z1 - 1.2, STONE_DARK)
	end
	-- the porch: a plank deck in front of the door, steps down to the ground
	box("Porch", DOOR_X - 3.2, FOOT - 0.6, -10, DOOR_X + 2.4, FOOT, MZ0, WOOD)
	box("PorchEdge", DOOR_X - 3.2, FOOT - 0.9, -10.3, DOOR_X + 2.4, FOOT - 0.3, -10, WOOD_DARK)
	box("Step", DOOR_X - 1.6, 0.67, -11.2, DOOR_X + 1.6, 1.33, -10, WOOD)
	box("Step", DOOR_X - 1.6, 0, -12.4, DOOR_X + 1.6, 0.67, -11.2, WOOD_DARK)
	-- stone piers under the porch's front
	for _, x in { DOOR_X - 2.8, DOOR_X + 2 } do
		box("Pier", x - 0.6, 0, -10.3, x + 0.6, FOOT - 0.6, -9.1, STONE_DARK)
	end
end

local function walls()
	local t = 1.2
	-- the main block: front (beside the wing), back, the two ends
	clap("Wall", -MX, MZ0, WX0, MZ0 + t, FOOT, EAVE)
	clap("Wall", -MX, MZ1 - t, MX, MZ1, FOOT, EAVE)
	clap("Wall", -MX, MZ0, -MX + t, MZ1, FOOT, EAVE)
	clap("Wall", MX - t, MZ0, MX, MZ1, FOOT, EAVE)
	-- the wing: its front and its two short sides
	clap("Wall", WX0, WZ, WX1, WZ + t, FOOT, EAVE)
	clap("Wall", WX0, WZ, WX0 + t, MZ0 + t, FOOT, EAVE)
	clap("Wall", WX1 - t, WZ, WX1, MZ0 + t, FOOT, EAVE)
	-- the inside, filled (the mesh's HouseCore boxes stand here)
	box("Core", -MX + t, FOOT, MZ0 + t, MX - t, EAVE + 2, MZ1 - t, look.wallShade)
	-- white corner boards and the band under the eaves
	for _, c in { { -MX, MZ0 }, { -MX, MZ1 }, { MX, MZ1 }, { WX0, WZ }, { WX1, WZ } } do
		box("Corner", c[1] - 0.45, FOOT, c[2] - 0.45, c[1] + 0.45, EAVE, c[2] + 0.45, TRIM)
	end
	box("Band", -MX - 0.3, EAVE - 0.6, MZ0 - 0.3, WX0, EAVE, MZ0 + 0.2, TRIM)
	box("Band", WX0 - 0.3, EAVE - 0.6, WZ - 0.3, WX1 + 0.3, EAVE, WZ + 0.2, TRIM)
	box("Band", -MX - 0.3, FOOT, MZ0 - 0.35, WX0, FOOT + 0.4, MZ0 + 0.2, TRIM)
	box("Band", WX0, FOOT, WZ - 0.35, WX1 + 0.3, FOOT + 0.4, WZ + 0.2, TRIM)
end

local function roofs()
	-- the main roof: ridge along X, eaves overhanging front and back
	local mainTop = roofX("Roof", (MZ0 + MZ1) / 2, (MZ1 - MZ0) / 2 + 1.4, -MX - 1.2, MX + 1, EAVE, 1.05, 1, WX0 + 0.2, true)
	-- its gable ends: stepped wall triangles under it at both ends
	gableZ("Gable", (MZ0 + MZ1) / 2, (MZ1 - MZ0) / 2 - 0.4, EAVE, 1.05, 1, -MX, -MX + 1.2)
	gableZ("Gable", (MZ0 + MZ1) / 2, (MZ1 - MZ0) / 2 - 0.4, EAVE, 1.05, 1, MX - 1.2, MX)
	-- the wing's steeper roof, ridge along Z, running back into the main roof
	local wc = (WX0 + WX1) / 2
	roofZ("Roof", wc, (WX1 - WX0) / 2 + 1, WZ - 1.2, (MZ0 + MZ1) / 2, EAVE, 1.6, 1, true)
	gableX("Gable", wc, (WX1 - WX0) / 2 - 0.4, EAVE, 1.6, 1, WZ, WZ + 1.2)
	-- the gable's white bargeboards: a stepped trim line just inside the roof's front edge
	return mainTop
end

local function dormer()
	local x0, x1 = -7.6, -3
	local zf = -5.2 -- (far enough down the slope that its walls stand clear of the tiles)
	local y0 = 15.2
	clap("Dormer", x0, zf, x1, zf + 4, y0, y0 + 3.6)
	box("Corner", x0 - 0.3, y0, zf - 0.3, x0 + 0.3, y0 + 3.6, zf + 0.3, TRIM)
	box("Corner", x1 - 0.3, y0, zf - 0.3, x1 + 0.3, y0 + 3.6, zf + 0.3, TRIM)
	roofZ("DormerRoof", (x0 + x1) / 2, (x1 - x0) / 2 + 0.8, zf - 0.8, zf + 4.5, y0 + 3.6, 1, 1, true)
	gableX("DormerGable", (x0 + x1) / 2, (x1 - x0) / 2 - 0.4, y0 + 3.6, 1, 1, zf, zf + 0.8)
	-- its window (no shutters: too narrow)
	local cf = front((x0 + x1) / 2, y0 + 1.8, zf - 0.2)
	brick("WindowGlass", Vector3.new(2.4, 2.4, 0.3), cf * CFrame.new(0, 0, 0.1), GLASS)
	brick("WindowFrame", Vector3.new(3.2, 0.4, 0.5), cf * CFrame.new(0, 1.4, 0), TRIM)
	brick("WindowFrame", Vector3.new(3.2, 0.4, 0.5), cf * CFrame.new(0, -1.4, 0), TRIM)
	brick("WindowBar", Vector3.new(0.25, 2.4, 0.4), cf, TRIM)
	brick("WindowBar", Vector3.new(2.4, 0.25, 0.4), cf, TRIM)
end

local function porch()
	-- two white posts, a beam, a little gable roof over the door
	for _, x in { DOOR_X - 2.6, DOOR_X + 1.8 } do
		box("PorchPost", x - 0.45, FOOT, -9.9, x + 0.45, 9.6, -9, TRIM)
		box("PorchPostBase", x - 0.6, FOOT, -10.05, x + 0.6, FOOT + 0.8, -8.85, TRIM)
	end
	box("PorchBeam", DOOR_X - 3.1, 9.6, -10.1, DOOR_X + 2.3, 10.2, -8.8, TRIM)
	local pc = DOOR_X - 0.4
	roofZ("PorchRoof", pc, 3.4, -10.9, MZ0 + 0.3, 10.2, 0.9, 1, true)
	gableX("PorchGable", pc, 2.4, 10.2, 0.9, 1, -10.2, -9.6)
	-- a white bracket in the gable
	box("PorchTrim", pc - 0.2, 10.2, -10.35, pc + 0.2, 12, -10.15, TRIM)
end

local function door()
	local cf = front(DOOR_X, FOOT + 3.4, MZ0 - 0.15)
	brick("Door", Vector3.new(3, 6.8, 0.4), cf, look.door)
	for k = -1, 1, 2 do
		brick("DoorFrame", Vector3.new(0.5, 7.3, 0.6), cf * CFrame.new(k * 1.75, 0.25, -0.1), TRIM)
	end
	brick("DoorFrame", Vector3.new(4, 0.6, 0.6), cf * CFrame.new(0, 3.75, -0.1), TRIM)
	brick("DoorGlass", Vector3.new(1.8, 1.4, 0.3), cf * CFrame.new(0, 1.9, -0.15), GLASS)
	brick("DoorPanel", Vector3.new(1.8, 2.2, 0.25), cf * CFrame.new(0, -1.4, -0.2), C(150, 32, 36))
	local knob = brick("DoorKnob", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(-1, 0, -0.35), BRASS)
	knob.Shape = Enum.PartType.Ball
	-- a lamp? (owner, 7 Nov: "delete the lanterns") none; a house number plate instead
	brick("Plate", Vector3.new(0.9, 0.6, 0.2), cf * CFrame.new(0, 4.55, -0.25), BRASS)
end

local function chimney(top: number)
	local x, z = -5.2, 3.6
	for k = 0, math.floor((top + 2.5 - (EAVE + 2)) / 1.2) do
		local y = EAVE + 2 + k * 1.2
		box("Chimney", x - 1.3, y, z - 1.3, x + 1.3, y + 1.2, z + 1.3, if k % 2 == 0 then STONE else STONE_DARK)
	end
	local cy = EAVE + 2 + (math.floor((top + 2.5 - (EAVE + 2)) / 1.2) + 1) * 1.2
	box("ChimneyCap", x - 1.6, cy, z - 1.6, x + 1.6, cy + 0.6, z + 1.6, STONE_DARK)
	box("ChimneyPot", x - 0.6, cy + 0.6, z - 0.6, x + 0.6, cy + 1.6, z + 0.6, POT)
end

-- a rose climbing the right front corner, pots by the steps
local function garden()
	local leaves = {
		{ -9.4, 0, -7.2, 2.2, 3, 1.8 },
		{ -9.6, 3, -7, 1.8, 2.6, 1.6 },
		{ -9.3, 5.6, -6.9, 1.6, 2.4, 1.4 },
		{ -9.5, 8, -7, 1.4, 2.2, 1.2 },
		{ -8.2, 9.6, -7.1, 1.6, 1.4, 1.2 },
		{ -10, 1.5, -5.6, 1.4, 2, 1.4 },
	}
	for i, l in leaves do
		box("Rose", l[1] - l[4] / 2, l[2], l[3] - l[6] / 2, l[1] + l[4] / 2, l[2] + l[5], l[3] + l[6] / 2, if i % 2 == 0 then LEAF else LEAF_DARK)
		for j = 0, 1 do
			local f = brick("RoseBloom", Vector3.new(0.6, 0.6, 0.6), CFrame.new(l[1] + (j - 0.5) * l[4] * 0.6, l[2] + l[5] * (0.35 + j * 0.4), l[3] - l[6] / 2 - 0.1), ROSE[(i + j) % 3 + 1])
			f.Shape = Enum.PartType.Ball
		end
	end
	for _, x in { DOOR_X - 3.6, DOOR_X + 2.8 } do
		box("Pot", x - 0.7, 0, -11.9, x + 0.7, 1.1, -10.5, POT)
		box("PotRim", x - 0.85, 1.1, -12.05, x + 0.85, 1.4, -10.35, C(166, 82, 50))
		box("PotPlant", x - 0.9, 1.4, -12.1, x + 0.9, 2.6, -10.3, LEAF)
		box("PotPlant", x - 0.5, 2.6, -11.7, x + 0.5, 3.3, -10.7, LEAF_DARK)
	end
end

-------------------------------------------------------------------------------------------------------------
function StudHouse.build(parent: Instance, pivot: CFrame, which: string?): Model
	model = Instance.new("Model")
	model.Name = "StudHouse"
	origin = pivot
	look = StudHouse.LOOKS[which or "blue"] or StudHouse.LOOKS.blue
	count = 0
	footing()
	walls()
	local top = roofs()
	dormer()
	porch()
	door()
	-- the windows: one each side of the door, the wing's on both floors, one on each end
	window(front(-6.3, FOOT + 4.4, MZ0 - 0.2), 2.2, 3.4, true)
	window(front((WX0 + WX1) / 2, FOOT + 4.4, WZ - 0.2), 3, 3.6, true)
	window(front((WX0 + WX1) / 2, EAVE + 2.2, WZ - 0.2), 1.8, 2.4, false, false)
	window(CFrame.new(-MX - 0.2, FOOT + 5, 0.5) * CFrame.Angles(0, math.rad(90), 0), 2.6, 3.4, false)
	window(CFrame.new(MX + 0.2, FOOT + 5, 0.5) * CFrame.Angles(0, math.rad(-90), 0), 2.6, 3.4, false)
	chimney(top)
	garden()
	model:SetAttribute("Bricks", count)
	model.WorldPivot = pivot
	model.Parent = parent
	return model
end

return StudHouse
