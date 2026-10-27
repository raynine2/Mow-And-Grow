-- The camp's Tool Shop and Garage, built from blocks in the world's voxel look (owner, 27 Oct: "the house and the
-- normal garage is bugged and i dont like the design ... remake it in voxel style that we have but not too much,
-- fitting and interactable to go inside"). They replace the Blender log_cabin and garage_shed in the run camp.
--
-- Square logs in chunky pieces with a little colour play, interlocking log ends at the corners, a stepped block
-- roof in the windmill's red, stone footings, lit windows with shutters and flower boxes. Both are walk-in:
-- the shop has a wide double door that swings open when someone comes near, the garage a roll-up door that rolls
-- up. The doors don't collide, so they never trap anyone. Everything else (the tool displays, prompts, the mower
-- spawn, the gas pump) is still placed by RunBuilder, in the same spots as before.
--
-- Coordinates are in the building's own space: `at` is RunBuilder's spot for it (where the old model stood),
-- front = at.LookVector (-Z), y = 0 is the ground.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Models = require(script.Parent.Models)

local CampBuildings = {}
CampBuildings.ON = true

local ROW = 1.6 -- one log
local T = 1.4 -- wall thickness

local C = {
	log = { Color3.fromRGB(160, 104, 62), Color3.fromRGB(146, 92, 54) }, -- by row, so the rows read as logs
	logEnd = Color3.fromRGB(206, 162, 106),
	dark = Color3.fromRGB(92, 58, 36),
	stone = Color3.fromRGB(134, 132, 126),
	roof = Color3.fromRGB(162, 66, 50),
	ridge = Color3.fromRGB(116, 44, 34),
	plank = Color3.fromRGB(186, 134, 84),
	shutter = Color3.fromRGB(56, 124, 100),
	glass = Color3.fromRGB(255, 212, 140),
	tile = Color3.fromRGB(150, 150, 146),
	metal = Color3.fromRGB(190, 196, 202),
	stripe = Color3.fromRGB(240, 196, 40),
}

type Ctx = { parent: Instance, at: CFrame, rng: Random }

-------------------------------------------------------------------------------------------------------------
-- blocks
-------------------------------------------------------------------------------------------------------------
local function jitter(rng: Random, c: Color3, amt: number): Color3
	local k = 1 + (rng:NextNumber() * 2 - 1) * amt
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function blockAt(ctx: Ctx, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = ctx.at * cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = ctx.parent
	return p
end

local function block(ctx: Ctx, name: string, centre: Vector3, size: Vector3, color: Color3, material: Enum.Material?): Part
	return blockAt(ctx, name, CFrame.new(centre), size, color, material)
end

-- Decoration: no collisions, no queries, no shadow on small bits.
local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- [a, b] split into pieces between minL and maxL long (the last one never shorter than minL).
local function chop(rng: Random, a: number, b: number, minL: number, maxL: number): { { number } }
	local out = {}
	local x = a
	while b - x > 0.01 do
		local len = math.min(rng:NextNumber(minL, maxL), b - x)
		if b - (x + len) < minL then
			len = b - x
		end
		table.insert(out, { x, x + len })
		x += len
	end
	return out
end

-- [a, b] without the holes (each { from, to }).
local function subtract(a: number, b: number, holes: { { number } }): { { number } }
	local out = { { a, b } }
	for _, h in holes do
		local next = {}
		for _, s in out do
			if h[2] <= s[1] or h[1] >= s[2] then
				table.insert(next, s)
			else
				if h[1] > s[1] then
					table.insert(next, { s[1], h[1] })
				end
				if h[2] < s[2] then
					table.insert(next, { h[2], s[2] })
				end
			end
		end
		out = next
	end
	return out
end

-- One row of logs along X (axis "x", at z = fixed) or along Z (axis "z", at x = fixed), from a to b minus holes.
local function logRun(ctx: Ctx, axis: string, fixed: number, y: number, a: number, b: number, holes: { { number } }, h: number, color: Color3)
	for _, s in subtract(a, b, holes) do
		if s[2] - s[1] > 0.05 then
			for _, piece in chop(ctx.rng, s[1], s[2], 2.2, 5.5) do
				local mid, len = (piece[1] + piece[2]) / 2, piece[2] - piece[1]
				local c = jitter(ctx.rng, color, 0.06)
				if axis == "x" then
					block(ctx, "Log", Vector3.new(mid, y, fixed), Vector3.new(len, h, T), c)
				else
					block(ctx, "Log", Vector3.new(fixed, y, mid), Vector3.new(T, h, len), c)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- a log box: four walls with interlocking corners
-------------------------------------------------------------------------------------------------------------
-- box = { x = outer half-width, z0 = front outer z, z1 = back outer z, floor = floor top, rows = number of logs }
-- holes(wall, row) -> { { from, to } } for "front", "back", "left" (-X), "right" (+X)
type Box = { x: number, z0: number, z1: number, floor: number, rows: number }

local function logBox(ctx: Ctx, box: Box, holes: (string, number) -> { { number } })
	local xw, zf, zb = box.x - T / 2, box.z0 + T / 2, box.z1 - T / 2
	for r = 0, box.rows - 1 do
		local y = box.floor + r * ROW + ROW / 2
		local base = C.log[r % 2 + 1]
		local long = r % 2 == 0 -- even rows: the front and back logs run through the corners and stick out
		local xa = if long then -box.x else -box.x + T
		local za, zb2 = if long then box.z0 + T else box.z0, if long then box.z1 - T else box.z1
		logRun(ctx, "x", zf, y, xa, -xa, holes("front", r), ROW, base)
		logRun(ctx, "x", zb, y, xa, -xa, holes("back", r), ROW, base)
		logRun(ctx, "z", -xw, y, za, zb2, holes("left", r), ROW, base)
		logRun(ctx, "z", xw, y, za, zb2, holes("right", r), ROW, base)
		-- the log ends past the corner, lighter (end grain)
		local stick = 0.8
		for _, sx in { -1, 1 } do
			for _, zz in { zf, zb } do
				if long then
					block(ctx, "LogEnd", Vector3.new(sx * (box.x + stick / 2), y, zz), Vector3.new(stick, ROW - 0.1, T - 0.1), jitter(ctx.rng, C.logEnd, 0.05))
				end
			end
			if not long then
				for _, sz in { -1, 1 } do
					local z = if sz < 0 then box.z0 - stick / 2 else box.z1 + stick / 2
					block(ctx, "LogEnd", Vector3.new(sx * xw, y, z), Vector3.new(T - 0.1, ROW - 0.1, stick), jitter(ctx.rng, C.logEnd, 0.05))
				end
			end
		end
	end
end

-- A stone footing under the walls (down into the ground so a slope never shows a gap) and a plank floor.
local function footing(ctx: Ctx, box: Box, floorColor: Color3, plankAlongZ: boolean)
	local top = box.floor
	local d = 3
	local zc, zl = (box.z0 + box.z1) / 2, box.z1 - box.z0
	for _, piece in chop(ctx.rng, -box.x - 0.3, box.x + 0.3, 2.5, 4.5) do
		for _, z in { box.z0 + 0.4, box.z1 - 0.4 } do
			local s = Vector3.new(piece[2] - piece[1], top + d, T + 0.6)
			block(ctx, "Footing", Vector3.new((piece[1] + piece[2]) / 2, (top - d) / 2, z), s, jitter(ctx.rng, C.stone, 0.07), Enum.Material.Slate)
		end
	end
	for _, piece in chop(ctx.rng, box.z0 + 1, box.z1 - 1, 2.5, 4.5) do
		for _, sx in { -1, 1 } do
			local s = Vector3.new(T + 0.6, top + d, piece[2] - piece[1])
			block(ctx, "Footing", Vector3.new(sx * (box.x - 0.4), (top - d) / 2, (piece[1] + piece[2]) / 2), s, jitter(ctx.rng, C.stone, 0.07), Enum.Material.Slate)
		end
	end
	-- the fill under the floor (unseen) and the planks on top
	block(ctx, "FloorFill", Vector3.new(0, (top - 0.4 - d) / 2, zc), Vector3.new(box.x * 2 - 1, top - 0.4 + d, zl - 1), C.stone)
	local w = 2
	if plankAlongZ then
		for x = -box.x + T, box.x - T - 0.01, w do
			local wx = math.min(w, box.x - T - x)
			block(ctx, "Plank", Vector3.new(x + wx / 2, top - 0.2, zc), Vector3.new(wx, 0.4, zl - 2 * T), jitter(ctx.rng, floorColor, 0.05))
		end
	else
		for _, piece in chop(ctx.rng, box.z0 + T, box.z1 - T, 2.2, 3.6) do
			for _, half in { -1, 1 } do
				local wx = box.x - T
				block(ctx, "Tile", Vector3.new(half * wx / 2, top - 0.2, (piece[1] + piece[2]) / 2), Vector3.new(wx - 0.08, 0.4, piece[2] - piece[1] - 0.08), jitter(ctx.rng, floorColor, 0.05), Enum.Material.Slate)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- stepped roof (ridge along X when alongX, else along Z) with log-filled gables
-------------------------------------------------------------------------------------------------------------
-- roof = { top = wall top y, a0/a1 = eaves across the ridge, b = half-length along the ridge (overhang included),
--          steps, rise, gables = the two gable walls' centre lines }
type Roof = { top: number, a0: number, a1: number, b: number, steps: number, rise: number, gables: { number }, alongX: boolean }

local function roofStrip(ctx: Ctx, roof: Roof, y: number, a: number, b: number, color: Color3, name: string)
	for _, piece in chop(ctx.rng, -roof.b, roof.b, 3, 5.5) do
		local len, mid = piece[2] - piece[1], (piece[1] + piece[2]) / 2
		local c = jitter(ctx.rng, color, 0.07)
		if roof.alongX then
			block(ctx, name, Vector3.new(mid, y, (a + b) / 2), Vector3.new(len, roof.rise, b - a), c)
		else
			block(ctx, name, Vector3.new((a + b) / 2, y, mid), Vector3.new(b - a, roof.rise, len), c)
		end
	end
end

local function steppedRoof(ctx: Ctx, roof: Roof)
	local run = (roof.a1 - roof.a0) / 2 / roof.steps
	for i = 0, roof.steps - 1 do
		local y = roof.top + i * roof.rise + roof.rise / 2
		local tone = if i % 2 == 0 then C.roof else C.roof:Lerp(C.ridge, 0.25)
		roofStrip(ctx, roof, y, roof.a0 + i * run, roof.a0 + (i + 1) * run, tone, "Roof")
		roofStrip(ctx, roof, y, roof.a1 - (i + 1) * run, roof.a1 - i * run, tone, "Roof")
		-- the gable logs between the two strips of this step
		local g0, g1 = roof.a0 + (i + 1) * run, roof.a1 - (i + 1) * run
		if g1 - g0 > 0.2 then
			for _, at in roof.gables do
				if roof.alongX then
					logRun(ctx, "z", at, y, g0, g1, {}, roof.rise, C.log[i % 2 + 1])
				else
					logRun(ctx, "x", at, y, g0, g1, {}, roof.rise, C.log[i % 2 + 1])
				end
			end
		end
	end
	local mid = (roof.a0 + roof.a1) / 2
	roofStrip(ctx, roof, roof.top + roof.steps * roof.rise + roof.rise / 2, mid - run * 0.75, mid + run * 0.75, C.ridge, "Ridge")
end

-------------------------------------------------------------------------------------------------------------
-- windows, flower boxes, lamps
-------------------------------------------------------------------------------------------------------------
-- A window in a wall: `cf` is the middle of the hole on the wall's centre line, its -Z facing out.
local function window(ctx: Ctx, cf: CFrame, w: number, h: number, flowers: boolean)
	local f = 0.45
	local depth = T + 0.3
	local function part(name: string, off: Vector3, size: Vector3, color: Color3, mat: Enum.Material?)
		return blockAt(ctx, name, cf * CFrame.new(off), size, color, mat)
	end
	part("WindowFrame", Vector3.new(0, h / 2 + f / 2, 0), Vector3.new(w + 2 * f, f, depth), C.dark)
	part("WindowSill", Vector3.new(0, -h / 2 - f / 2, -0.15), Vector3.new(w + 2 * f + 0.4, f, depth + 0.3), C.dark)
	for _, sx in { -1, 1 } do
		part("WindowFrame", Vector3.new(sx * (w / 2 + f / 2), 0, 0), Vector3.new(f, h, depth), C.dark)
		local shutter = part("Shutter", Vector3.new(sx * (w / 2 + f + w / 4), 0, -T / 2 - 0.2), Vector3.new(w / 2 - 0.2, h, 0.3), jitter(ctx.rng, C.shutter, 0.05))
		deco(shutter)
		deco(part("ShutterBar", Vector3.new(sx * (w / 2 + f + w / 4), 0, -T / 2 - 0.4), Vector3.new(w / 2 - 0.6, 0.35, 0.12), C.shutter:Lerp(Color3.new(0, 0, 0), 0.25)))
	end
	local glass = part("WindowGlass", Vector3.zero, Vector3.new(w, h, 0.2), C.glass, Enum.Material.SmoothPlastic)
	glass.Transparency = 0.35
	deco(part("Mullion", Vector3.new(0, 0, -0.15), Vector3.new(0.3, h, 0.2), C.dark))
	deco(part("Mullion", Vector3.new(0, 0, -0.15), Vector3.new(w, 0.3, 0.2), C.dark))
	if flowers then
		local boxY = -h / 2 - f - 0.45
		part("FlowerBox", Vector3.new(0, boxY, -T / 2 - 0.55), Vector3.new(w + 0.4, 0.8, 1.0), jitter(ctx.rng, C.dark:Lerp(C.plank, 0.4), 0.05))
		local colors = { Color3.fromRGB(240, 80, 90), Color3.fromRGB(255, 214, 60), Color3.fromRGB(250, 140, 200), Color3.fromRGB(255, 255, 255) }
		local n = math.floor(w / 1.1)
		for i = 1, n do
			local x = -w / 2 + (i - 0.5) * w / n
			local leafy = i % 2 == 0
			local color = if leafy then Color3.fromRGB(70, 150, 60) else colors[ctx.rng:NextInteger(1, #colors)]
			local s = if leafy then 0.7 else 0.55
			deco(part(if leafy then "Leaf" else "Flower", Vector3.new(x, boxY + 0.4 + s / 2, -T / 2 - 0.55), Vector3.one * s, color))
		end
	end
end

local function lamp(ctx: Ctx, name: string, centre: Vector3, range: number, brightness: number)
	local p = deco(block(ctx, name, centre, Vector3.one, Color3.new(1, 1, 1)))
	p.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 232, 200)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	return p
end

-- A block lantern hanging from a chain (warm glass, no neon: the hub's bloom blows neon up).
local function hangingLantern(ctx: Ctx, top: Vector3, drop: number, brightness: number?)
	deco(block(ctx, "Chain", top - Vector3.new(0, drop / 2, 0), Vector3.new(0.15, drop, 0.15), C.dark))
	local y = top.Y - drop
	deco(block(ctx, "LanternCap", Vector3.new(top.X, y - 0.2, top.Z), Vector3.new(1.1, 0.4, 1.1), C.dark))
	local core = deco(block(ctx, "LanternGlass", Vector3.new(top.X, y - 0.95, top.Z), Vector3.new(0.8, 1.1, 0.8), Color3.fromRGB(255, 190, 90), Enum.Material.SmoothPlastic))
	core.Transparency = 0.1
	deco(block(ctx, "LanternBase", Vector3.new(top.X, y - 1.6, top.Z), Vector3.new(1.0, 0.25, 1.0), C.dark))
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 206, 140)
	l.Range = 12
	l.Brightness = brightness or 0.45
	l.Shadows = false
	l.Parent = core
end

local function smoke(ctx: Ctx, at: Vector3)
	local spot = deco(block(ctx, "ChimneySmoke", at, Vector3.one, Color3.new(1, 1, 1)))
	spot.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235), Color3.fromRGB(190, 190, 195))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 4
	e.Speed = NumberRange.new(2, 3)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = Vector3.new(1.2, 0.4, 0.8)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Parent = spot
end

-- Chop A Forest's sign style text on the -Z face of `part`.
local function signText(part: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.4
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 222, 96), Color3.fromRGB(255, 126, 30))
	grad.Rotation = 90
	grad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 36, 16)
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

-------------------------------------------------------------------------------------------------------------
-- doors that open when someone comes near
-------------------------------------------------------------------------------------------------------------
-- Each mover is kept relative to its group's sensor part, so the doors still work after the saved map moved the
-- building (MapStore moves every part of a piece together).
type Mover = { part: BasePart, closed: CFrame, open: CFrame, closedSize: Vector3?, openSize: Vector3? }
type Group = { sensor: BasePart, radius: number, movers: { Mover }, isOpen: boolean }
local groups: { Group } = {}
local running = false

local function anyoneNear(pos: Vector3, r: number): boolean
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - pos).Magnitude < r then
			return true
		end
	end
	return false
end

local function setOpen(g: Group, open: boolean)
	g.isOpen = open
	local info = TweenInfo.new(if open then 0.45 else 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, m in g.movers do
		local goal: { [string]: any } = { CFrame = g.sensor.CFrame * (if open then m.open else m.closed) }
		if m.closedSize and m.openSize then
			goal.Size = if open then m.openSize else m.closedSize
		end
		TweenService:Create(m.part, info, goal):Play()
	end
end

local function startDoors()
	if running or not RunService:IsRunning() then
		return
	end
	running = true
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, g in groups do
				if g.sensor:IsDescendantOf(workspace) then
					local near = anyoneNear(g.sensor.Position, g.radius)
					if near ~= g.isOpen then
						setOpen(g, near)
					end
				end
			end
		end
	end)
end

local function doorGroup(ctx: Ctx, sensorLocal: CFrame, radius: number): (Group, CFrame)
	local sensor = deco(blockAt(ctx, "DoorSensor", sensorLocal, Vector3.one, Color3.new(1, 1, 1)))
	sensor.Transparency = 1
	local g: Group = { sensor = sensor, radius = radius, movers = {}, isOpen = false }
	table.insert(groups, g)
	startDoors()
	return g, sensorLocal:Inverse()
end

-------------------------------------------------------------------------------------------------------------
-- the Tool Shop
-------------------------------------------------------------------------------------------------------------
-- The room inside matches the old cabin's (the displays RunBuilder puts in stand where they stood): back wall's
-- inner face at z 14.3, floor at 0.75, the pedestals at x +-9.
local SHOP: Box = { x = 19, z0 = -5, z1 = 15.7, floor = 0.75, rows = 8 }
local SHOP_DOOR = 4.5 -- half-width
local SHOP_WIN = { front = { -12, 12 }, side = 5.35, w = 6, sideW = 5 }

local function shopHoles(wall: string, r: number): { { number } }
	local out = {}
	if wall == "front" then
		if r <= 5 then
			table.insert(out, { -SHOP_DOOR, SHOP_DOOR })
		end
		if r >= 2 and r <= 4 then
			for _, x in SHOP_WIN.front do
				table.insert(out, { x - SHOP_WIN.w / 2, x + SHOP_WIN.w / 2 })
			end
		end
	elseif (wall == "left" or wall == "right") and r >= 2 and r <= 4 then
		table.insert(out, { SHOP_WIN.side - SHOP_WIN.sideW / 2, SHOP_WIN.side + SHOP_WIN.sideW / 2 })
	end
	return out
end

local function shopDoors(ctx: Ctx)
	local zc = SHOP.z0 + T / 2
	local top = SHOP.floor + 6 * ROW
	local h = top - SHOP.floor
	-- the frame
	for _, sx in { -1, 1 } do
		block(ctx, "DoorFrame", Vector3.new(sx * (SHOP_DOOR + 0.3), SHOP.floor + h / 2, zc), Vector3.new(0.6, h, T + 0.4), C.dark)
	end
	block(ctx, "DoorFrame", Vector3.new(0, top + 0.3, zc), Vector3.new(2 * SHOP_DOOR + 1.2, 0.6, T + 0.4), C.dark)
	-- two leaves hinged at the frame, swinging in
	local g, inv = doorGroup(ctx, CFrame.new(0, SHOP.floor + 3, zc), 13)
	local lw = SHOP_DOOR - 0.05
	for _, sx in { -1, 1 } do
		local hinge = CFrame.new(sx * SHOP_DOOR, SHOP.floor + h / 2, zc)
		local swing = CFrame.Angles(0, math.rad(if sx < 0 then -100 else 100), 0)
		local bits = {
			{ "DoorLeaf", CFrame.new(-sx * lw / 2, 0, 0), Vector3.new(lw, h - 0.1, 0.35), jitter(ctx.rng, Color3.fromRGB(124, 78, 46), 0.04) },
			{ "DoorBrace", CFrame.new(-sx * lw / 2, h / 2 - 1.6, -0.25), Vector3.new(lw - 0.4, 0.5, 0.2), C.dark },
			{ "DoorBrace", CFrame.new(-sx * lw / 2, -h / 2 + 1.6, -0.25), Vector3.new(lw - 0.4, 0.5, 0.2), C.dark },
			{ "DoorWindow", CFrame.new(-sx * lw / 2, h / 2 - 3.2, -0.1), Vector3.new(lw - 1.6, 1.8, 0.3), C.glass },
			{ "DoorHandle", CFrame.new(-sx * (lw - 0.5), -0.3, -0.35), Vector3.new(0.25, 0.9, 0.25), Color3.fromRGB(226, 176, 74) },
		}
		for _, b in bits do
			local closed = hinge * b[2]
			local p = deco(blockAt(ctx, b[1], closed, b[3], b[4]))
			if b[1] == "DoorWindow" then
				p.Transparency = 0.3
			end
			table.insert(g.movers, { part = p, closed = inv * closed, open = inv * hinge * swing * b[2] })
		end
	end
end

local function shopPorch(ctx: Ctx)
	local z0, z1 = -11.5, SHOP.z0
	local y = SHOP.floor
	block(ctx, "PorchBase", Vector3.new(0, (y - 0.4 - 3) / 2, (z0 + z1) / 2), Vector3.new(22, y - 0.4 + 3, z1 - z0), C.stone, Enum.Material.Slate)
	for z = z0, z1 - 0.01, 1.3 do
		local wz = math.min(1.3, z1 - z)
		for _, piece in chop(ctx.rng, -11, 11, 3, 6) do
			block(ctx, "PorchPlank", Vector3.new((piece[1] + piece[2]) / 2, y - 0.2, z + wz / 2), Vector3.new(piece[2] - piece[1] - 0.06, 0.4, wz - 0.08), jitter(ctx.rng, C.plank, 0.06))
		end
	end
	block(ctx, "Step", Vector3.new(0, 0.2 - 1.5, z0 - 0.6), Vector3.new(10, 3.4, 1.2), jitter(ctx.rng, C.stone, 0.05), Enum.Material.Slate)
	-- posts, rails and the porch roof
	local pz, top = z0 + 0.6, y + 6 * ROW
	for _, sx in { -1, 1 } do
		block(ctx, "PorchPost", Vector3.new(sx * 10.4, (y + top) / 2, pz), Vector3.new(1, top - y, 1), C.dark)
		block(ctx, "Rail", Vector3.new(sx * 7.7, y + 2.6, pz), Vector3.new(4.4, 0.4, 0.4), C.dark)
		block(ctx, "Rail", Vector3.new(sx * 10.4, y + 2.6, (pz + z1) / 2), Vector3.new(0.4, 0.4, z1 - pz), C.dark)
		for i = 1, 2 do
			deco(block(ctx, "Baluster", Vector3.new(sx * (10.4 - i * 1.6), y + 1.3, pz), Vector3.new(0.4, 2.6, 0.4), C.dark:Lerp(C.plank, 0.3)))
			deco(block(ctx, "Baluster", Vector3.new(sx * 10.4, y + 1.3, pz + i * 2), Vector3.new(0.4, 2.6, 0.4), C.dark:Lerp(C.plank, 0.3)))
		end
	end
	for _, piece in chop(ctx.rng, -12, 12, 3, 5.5) do
		block(ctx, "PorchRoof", Vector3.new((piece[1] + piece[2]) / 2, top + 0.5, (z0 - 0.7 + z1) / 2), Vector3.new(piece[2] - piece[1], 1, z1 - z0 + 0.7), jitter(ctx.rng, C.roof, 0.07))
	end
	block(ctx, "PorchTrim", Vector3.new(0, top - 0.25, z0 - 0.2), Vector3.new(24, 0.5, 0.6), C.dark)
	hangingLantern(ctx, Vector3.new(0, top, (z0 + z1) / 2), 1.2)
	return top + 1
end

-- The shop's badge on the porch roof: a scythe crossed with a sickle in blocks on a round-ish wooden board (no
-- words: Config.HUB_SIGNS is off, "the buildings speak for themselves").
local function shopBadge(ctx: Ctx, base: number, z: number, withSign: boolean)
	local cy = base + 2.0
	local board = block(ctx, "Badge", Vector3.new(0, cy, z), Vector3.new(if withSign then 15 else 5.6, 4.0, 0.6), C.dark)
	block(ctx, "Badge", Vector3.new(0, cy, z + 0.05), Vector3.new(if withSign then 15.8 else 6.4, 3.2, 0.5), C.dark)
	if withSign then
		signText(board, "TOOL SHOP")
		return
	end
	local face = CFrame.new(0, cy, z - 0.4)
	local handle = Color3.fromRGB(196, 140, 80)
	local blade = Color3.fromRGB(214, 222, 228)
	for _, sx in { -1, 1 } do
		local tilt = face * CFrame.Angles(0, 0, math.rad(sx * 40))
		deco(blockAt(ctx, "BadgeHandle", tilt, Vector3.new(0.45, 3.6, 0.3), handle))
		-- a scythe blade off the top of each handle, curving out and down
		deco(blockAt(ctx, "BadgeBlade", tilt * CFrame.new(-sx * 0.95, 1.6, 0), Vector3.new(1.9, 0.55, 0.3), blade))
		deco(blockAt(ctx, "BadgeBlade", tilt * CFrame.new(-sx * 1.9, 1.2, 0), Vector3.new(0.55, 0.7, 0.3), blade))
		deco(blockAt(ctx, "BadgeGrip", tilt * CFrame.new(0, -0.4, -0.05), Vector3.new(0.75, 0.35, 0.3), C.dark))
	end
end

local function shopInside(ctx: Ctx)
	local y = SHOP.floor
	local zi0, zi1 = SHOP.z0 + T, SHOP.z1 - T
	-- a runner rug down the aisle
	deco(block(ctx, "Rug", Vector3.new(0, y + 0.05, (zi0 + zi1) / 2 - 1), Vector3.new(6, 0.1, zi1 - zi0 - 4), Color3.fromRGB(128, 46, 42)))
	deco(block(ctx, "Rug", Vector3.new(0, y + 0.07, (zi0 + zi1) / 2 - 1), Vector3.new(4.4, 0.1, zi1 - zi0 - 5.6), Color3.fromRGB(178, 132, 62)))
	deco(block(ctx, "Rug", Vector3.new(0, y + 0.09, (zi0 + zi1) / 2 - 1), Vector3.new(3.6, 0.1, zi1 - zi0 - 6.4), Color3.fromRGB(128, 46, 42)))
	-- tie beams across the room at the wall top
	local top = y + SHOP.rows * ROW
	for _, z in { 1.5, 9.5 } do
		block(ctx, "Beam", Vector3.new(0, top - 0.4, z), Vector3.new(SHOP.x * 2 - 2 * T, 0.8, 0.9), C.dark)
		hangingLantern(ctx, Vector3.new(0, top - 0.8, z), 1.6)
	end
	lamp(ctx, "CabinLamp", Vector3.new(0, 9, 5.35), 20, 0.45)
	-- a crate pile and a barrel in the front corners
	local cz = zi0 + 1.6
	block(ctx, "Crate", Vector3.new(-15.6, y + 1.1, cz), Vector3.new(2.2, 2.2, 2.2), jitter(ctx.rng, C.plank, 0.08))
	block(ctx, "Crate", Vector3.new(-15.6, y + 2.2 + 0.8, cz + 0.2), Vector3.new(1.6, 1.6, 1.6), jitter(ctx.rng, C.plank, 0.08))
	block(ctx, "Crate", Vector3.new(-13.2, y + 0.8, cz - 0.1), Vector3.new(1.6, 1.6, 1.6), jitter(ctx.rng, C.plank, 0.08))
	block(ctx, "Barrel", Vector3.new(15.6, y + 1.3, cz), Vector3.new(2, 2.6, 2), Color3.fromRGB(120, 76, 44))
	for _, dy in { -0.8, 0.8 } do
		deco(block(ctx, "Hoop", Vector3.new(15.6, y + 1.3 + dy, cz), Vector3.new(2.15, 0.25, 2.15), Color3.fromRGB(70, 70, 76)))
	end
end

-- The Tool Shop at `at`. `withSign`: a TOOL SHOP board on the porch roof (else a crossed-tools badge).
function CampBuildings.shop(parent: Instance, at: CFrame, withSign: boolean?): boolean
	local ctx: Ctx = { parent = parent, at = at, rng = Random.new(2710) }
	footing(ctx, SHOP, C.plank, true)
	logBox(ctx, SHOP, shopHoles)
	for _, x in SHOP_WIN.front do
		window(ctx, CFrame.new(x, SHOP.floor + 2 * ROW + 1.5 * ROW, SHOP.z0 + T / 2), SHOP_WIN.w, 3 * ROW, true)
	end
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(sx * (SHOP.x - T / 2), SHOP.floor + 3.5 * ROW, SHOP_WIN.side) * CFrame.Angles(0, math.rad(-90 * sx), 0)
		window(ctx, cf, SHOP_WIN.sideW, 3 * ROW, true)
	end
	shopDoors(ctx)
	local top = SHOP.floor + SHOP.rows * ROW
	steppedRoof(ctx, { top = top, a0 = SHOP.z0 - 2, a1 = SHOP.z1 + 2, b = SHOP.x + 1.6, steps = 7, rise = 1, gables = { -(SHOP.x - T / 2), SHOP.x - T / 2 }, alongX = true })
	-- the chimney: stone blocks up the outside of the right gable wall, behind its window
	local n = 17
	for i = 0, n - 1 do
		local s = if i < 3 then 3.2 elseif i == n - 1 then 3.0 else 2.5
		block(ctx, "Chimney", Vector3.new(SHOP.x + 1.3, -0.5 + i * 1.4 + 0.7, 11.2), Vector3.new(s, 1.4, s), jitter(ctx.rng, C.stone, 0.09), Enum.Material.Slate)
	end
	smoke(ctx, Vector3.new(SHOP.x + 1.3, -0.5 + n * 1.4 + 1, 11.2))
	local porchTop = shopPorch(ctx)
	shopBadge(ctx, porchTop, -11.2, withSign == true)
	shopInside(ctx)
	-- a lantern post at each front corner of the porch, the lantern hanging toward the steps
	for _, sx in { -1, 1 } do
		Models.place("lantern_post", parent, at * CFrame.new(sx * 13.2, 0, -12.6) * CFrame.Angles(0, math.rad(sx * 90), 0), 0.9, true)
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the Garage
-------------------------------------------------------------------------------------------------------------
-- The mower spawns in the middle (RunBuilder: at * (0, 2, 0)) and the gas pump stands at x 10, so the garage
-- keeps inside x +-7.8 (+0.8 for the log ends).
local GARAGE: Box = { x = 7.8, z0 = -8.2, z1 = 8.6, floor = 0.4, rows = 6 }
local GARAGE_DOOR_ROWS = 5 -- the opening's height in logs
local RAISED = 2.0 -- the work deck along the back: its top, and where it starts
local PLATFORM_Z = 4.0

local function garageHoles(wall: string, r: number): { { number } }
	if wall == "front" and r < GARAGE_DOOR_ROWS then
		return { { -GARAGE.x + T, GARAGE.x - T } }
	elseif (wall == "left" or wall == "right") and r >= 2 and r <= 3 then
		return { { -2, 2 } }
	end
	return {}
end

local function rollUpDoor(ctx: Ctx)
	local w = 2 * (GARAGE.x - T)
	local bottom, top = GARAGE.floor, GARAGE.floor + GARAGE_DOOR_ROWS * ROW
	local z = GARAGE.z0 + T - 0.35
	-- the drum box under the header
	block(ctx, "DoorDrum", Vector3.new(0, top - 0.45, z + 0.25), Vector3.new(w, 0.9, 1.1), C.dark)
	local g, inv = doorGroup(ctx, CFrame.new(0, 3, GARAGE.z0), 15)
	-- metal slats that all roll up into the drum
	local h = top - 0.9 - bottom
	local n = 6
	local sh = h / n
	local slatOpen = CFrame.new(0, top - 0.95, z)
	for i = 0, n - 1 do
		local closed = CFrame.new(0, bottom + (i + 0.5) * sh, z)
		local tone = if i % 2 == 0 then C.metal else C.metal:Lerp(Color3.new(0, 0, 0), 0.12)
		local slat = deco(blockAt(ctx, "RollDoor", closed, Vector3.new(w, sh - 0.08, 0.25), tone, Enum.Material.Metal))
		table.insert(g.movers, { part = slat, closed = inv * closed, open = inv * slatOpen, closedSize = slat.Size, openSize = Vector3.new(w, 0.1, 0.25) })
	end
	local barClosed = CFrame.new(0, bottom + 0.25, z - 0.1)
	local barOpen = CFrame.new(0, top - 1.1, z - 0.1)
	local bar = deco(blockAt(ctx, "RollDoorBar", barClosed, Vector3.new(w, 0.5, 0.35), C.stripe))
	table.insert(g.movers, { part = bar, closed = inv * barClosed, open = inv * barOpen })
	-- the door frame
	for _, sx in { -1, 1 } do
		block(ctx, "DoorFrame", Vector3.new(sx * (GARAGE.x - T - 0.25), (bottom + top) / 2, GARAGE.z0 + T / 2 - 0.1), Vector3.new(0.5, top - bottom, T + 0.4), C.dark)
	end
	block(ctx, "DoorFrame", Vector3.new(0, top + 0.25, GARAGE.z0 + T / 2 - 0.1), Vector3.new(w + 1, 0.5, T + 0.4), C.dark)
end

local function garageInside(ctx: Ctx)
	local y = GARAGE.floor
	local zb = GARAGE.z1 - T
	-- yellow bay lines on the floor and a ramp lip out front
	for _, sx in { -1, 1 } do
		deco(block(ctx, "BayLine", Vector3.new(sx * 4.6, y + 0.03, -0.5), Vector3.new(0.35, 0.06, 12), C.stripe))
	end
	block(ctx, "Apron", Vector3.new(0, 0.1 - 1, GARAGE.z0 - 0.8), Vector3.new(2 * GARAGE.x, 2.2, 1.6), jitter(ctx.rng, C.tile, 0.05), Enum.Material.Slate)
	-- a raised plank deck along the back (the camp's grass terrace rises under the back of the garage), with
	-- the workbench and a pegboard of block tools on the back wall
	local deckZ = PLATFORM_Z
	block(ctx, "WorkDeck", Vector3.new(0, (RAISED - 0.3 - 0.6) / 2, (deckZ + zb) / 2), Vector3.new(2 * (GARAGE.x - T), RAISED - 0.3 + 0.6, zb - deckZ), C.dark)
	for _, piece in chop(ctx.rng, -GARAGE.x + T, GARAGE.x - T, 2.5, 4.5) do
		block(ctx, "DeckPlank", Vector3.new((piece[1] + piece[2]) / 2, RAISED - 0.15, (deckZ + zb) / 2), Vector3.new(piece[2] - piece[1] - 0.06, 0.3, zb - deckZ), jitter(ctx.rng, C.plank, 0.06))
	end
	local bz = zb - 1.1
	local by = RAISED
	block(ctx, "Workbench", Vector3.new(-2.5, by + 2.6, bz), Vector3.new(6, 0.5, 2), jitter(ctx.rng, C.plank, 0.05))
	for _, sx in { -1, 1 } do
		block(ctx, "BenchLeg", Vector3.new(-2.5 + sx * 2.6, by + 1.2, bz), Vector3.new(0.5, 2.4, 1.6), C.dark)
	end
	deco(block(ctx, "Vise", Vector3.new(-4.8, by + 3.2, bz - 0.4), Vector3.new(0.8, 0.7, 0.9), Color3.fromRGB(60, 90, 160)))
	deco(block(ctx, "Pegboard", Vector3.new(-2.5, by + 5.4, zb - 0.1), Vector3.new(6.4, 3.4, 0.2), Color3.fromRGB(206, 170, 120)))
	local tools = {
		{ -4.6, Vector3.new(0.3, 2.2, 0.2), Color3.fromRGB(150, 156, 164) },
		{ -3.6, Vector3.new(0.4, 1.6, 0.2), Color3.fromRGB(210, 60, 50) },
		{ -2.4, Vector3.new(0.3, 2.4, 0.2), Color3.fromRGB(196, 140, 80) },
		{ -1.3, Vector3.new(0.5, 1.2, 0.2), Color3.fromRGB(240, 196, 40) },
		{ -0.4, Vector3.new(0.3, 2.0, 0.2), Color3.fromRGB(150, 156, 164) },
	}
	for _, t in tools do
		deco(block(ctx, "PegTool", Vector3.new(t[1], by + 5.4, zb - 0.3), t[2], t[3]))
	end
	-- a stack of tyres and an oil drum
	for i = 0, 2 do
		local cf = CFrame.new(4.2, RAISED + 0.35 + i * 0.78, bz - 0.3) * CFrame.Angles(0, 0, math.rad(90))
		local tyre = blockAt(ctx, "Tyre", cf, Vector3.new(0.7, 2.6, 2.6), Color3.fromRGB(40, 40, 44))
		tyre.Shape = Enum.PartType.Cylinder
		if i == 2 then
			local hub = deco(blockAt(ctx, "TyreHub", cf, Vector3.new(0.74, 1.3, 1.3), Color3.fromRGB(150, 156, 164)))
			hub.Shape = Enum.PartType.Cylinder
		end
	end
	local drum = blockAt(ctx, "OilDrum", CFrame.new(5.2, y + 1.3, -5.6) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(2.6, 1.8, 1.8), Color3.fromRGB(196, 54, 44))
	drum.Shape = Enum.PartType.Cylinder
	-- the light
	local top = y + GARAGE.rows * ROW
	hangingLantern(ctx, Vector3.new(0, top, 0.5), 1.4)
	lamp(ctx, "LampGlow", Vector3.new(0, top - 2, 1), 14, 0.35)
end

-- The Garage at `at` (the mower spawns in the middle, the open front faces at.LookVector).
function CampBuildings.garage(parent: Instance, at: CFrame): boolean
	local ctx: Ctx = { parent = parent, at = at, rng = Random.new(2711) }
	footing(ctx, GARAGE, C.tile, false)
	logBox(ctx, GARAGE, garageHoles)
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(sx * (GARAGE.x - T / 2), GARAGE.floor + 3 * ROW, 0) * CFrame.Angles(0, math.rad(-90 * sx), 0)
		window(ctx, cf, 4, 2 * ROW, false)
	end
	rollUpDoor(ctx)
	local top = GARAGE.floor + GARAGE.rows * ROW
	steppedRoof(ctx, { top = top, a0 = -GARAGE.x - 1.6, a1 = GARAGE.x + 1.6, b = (GARAGE.z1 - GARAGE.z0) / 2 + 1.4, steps = 6, rise = 1, gables = { GARAGE.z0 + T / 2, GARAGE.z1 - T / 2 }, alongX = false })
	-- the GARAGE board on the front gable
	local sign = block(ctx, "SignBoard", Vector3.new(0, top + 1.6, GARAGE.z0 - 0.15), Vector3.new(7.4, 2, 0.4), C.dark)
	block(ctx, "SignBoard", Vector3.new(0, top + 1.6, GARAGE.z0 + 0.05), Vector3.new(8, 2.6, 0.3), C.dark:Lerp(C.plank, 0.25))
	signText(sign, "GARAGE")
	garageInside(ctx)
	return true
end

return CampBuildings
