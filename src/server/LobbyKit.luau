-- The pieces of the Chop A Forest lobby, built from parts and matched to the reference screenshots (21 Oct 2026):
-- blocky voxel trees (pines of stacked turned blocks, lime oaks of tumbled leaf cubes, white birches), roofed
-- stalls with a plank sign, lanterns and a shopkeeper, roofed leaderboards with an emblem, the event notice
-- board, the log lodge players spawn on, the garage with its barn doors open, and the backyard with the garden.
-- LobbyBuilder places them; LobbyBoards fills the leaderboards; client/LobbyFX adds the ambient effects.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local LobbyPads = require(script.Parent.LobbyPads)

local LobbyKit = {}

local rgb = Color3.fromRGB
local shade = PropKit.shade

local WOOD = rgb(150, 98, 58)
local DARK_WOOD = rgb(92, 58, 34)
local LIGHT_WOOD = rgb(196, 140, 86)
local LOG = rgb(196, 142, 84)
local LOG_END = rgb(232, 196, 138)
local SHINGLE = rgb(126, 72, 52)
local BOARD = rgb(60, 38, 24)
local STONE = rgb(128, 128, 132)
local SIGN_STROKE = rgb(64, 30, 12)
local ROOF_MAT = Enum.Material.RoofShingles
LobbyKit.SHINGLE = SHINGLE

-------------------------------------------------------------------------------------------------------------
-- basics
-------------------------------------------------------------------------------------------------------------
local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?, material: Enum.Material?): Part
	return PropKit.part({ size = size, cf = cf, color = color, parent = parent, name = name, material = material or Enum.Material.WoodPlanks })
end

-- decoration: no collisions, raycasts or touches (and no shadow when `noShadow`)
local function deco(p: BasePart, noShadow: boolean?): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if noShadow then
		p.CastShadow = false
	end
	return p
end
LobbyKit.deco = deco

-- A cylinder lying along `cf`'s X axis (Roblox cylinders run along X).
local function log(parent: Instance, length: number, radius: number, cf: CFrame, color: Color3, name: string?): Part
	return PropKit.part({ size = Vector3.new(length, radius * 2, radius * 2), cf = cf, color = color, parent = parent, name = name or "Log", shape = Enum.PartType.Cylinder, material = Enum.Material.Wood })
end

-- A standing cylinder, `cf` = its middle.
local function post(parent: Instance, height: number, radius: number, cf: CFrame, color: Color3, name: string?): Part
	return log(parent, height, radius, cf * CFrame.Angles(0, 0, math.rad(90)), color, name or "Post")
end

-- A log along X with light end rings, like the cabins' log walls.
local function cabinLog(parent: Instance, length: number, radius: number, cf: CFrame, ends: boolean?): Part
	local p = log(parent, length, radius, cf, LOG, "Log")
	if ends ~= false then
		for side = -1, 1, 2 do
			deco(log(parent, 0.12, radius * 0.86, cf * CFrame.new(side * (length / 2 + 0.03), 0, 0), LOG_END, "LogEnd"), true)
		end
	end
	return p
end

local function ball(parent: Instance, d: number, cf: CFrame, color: Color3, name: string?, material: Enum.Material?): Part
	return PropKit.part({ size = Vector3.one * d, cf = cf, color = color, parent = parent, name = name or "Ball", shape = Enum.PartType.Ball, material = material or Enum.Material.SmoothPlastic })
end

local function tag(inst: Instance, name: string, attrs: { [string]: any }?)
	CollectionService:AddTag(inst, name)
	for k, v in attrs or {} do
		inst:SetAttribute(k, v)
	end
end
LobbyKit.tag = tag

-- An invisible anchor (FX spots, prompt holders).
local function spot(parent: Instance, cf: CFrame, size: Vector3, name: string): Part
	local p = PropKit.part({ size = size, cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = name })
	deco(p, true)
	return p
end
LobbyKit.spot = spot

-- Big sign text: Luckiest Guy with an orange gradient and a thick brown outline on a part's front face.
local function signText(part: BasePart, text: string, colors: { Color3 }?, pps: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 16
	gui.LightInfluence = 0.1
	gui.Brightness = 1.5
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.9, 0.8)
	l.Position = UDim2.fromScale(0.05, 0.1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	local c = colors or { rgb(255, 222, 96), rgb(255, 126, 30) }
	g.Color = ColorSequence.new(c[1], c[2])
	g.Rotation = 90
	g.Parent = l
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = SIGN_STROKE
	s.Parent = l
	l.Parent = gui
	return l
end
LobbyKit.signText = signText

-- A dark plank board with a lighter frame and orange text. `at` = its middle, the text faces at.LookVector.
function LobbyKit.plankSign(parent: Instance, at: CFrame, w: number, h: number, text: string, colors: { Color3 }?): Part
	local board = block(parent, Vector3.new(w, h, 0.5), at, BOARD, "Sign")
	for _, e in { { 0, h / 2, w + 0.5, 0.45 }, { 0, -h / 2, w + 0.5, 0.45 }, { w / 2, 0, 0.45, h }, { -w / 2, 0, 0.45, h } } do
		deco(block(parent, Vector3.new(e[3], e[4], 0.65), at * CFrame.new(e[1], e[2], 0), LIGHT_WOOD, "SignTrim", Enum.Material.Wood), true)
	end
	signText(board, text, colors)
	return board
end

-- A gabled roof on `base` (its middle at the eave height; the ridge runs along base's X axis): two slabs
-- `length` long and `half` deep each way, sloping at `pitch` degrees, a ridge beam, and triangle gable boards at
-- local x = each of `gables` (spanning `gableHalf` each way). Returns the ridge height above base.
local function gableRoof(parent: Instance, base: CFrame, length: number, half: number, pitch: number, color: Color3, gables: { number }?, gableHalf: number?, gableColor: Color3?): number
	local p = math.rad(pitch)
	local rise = math.tan(p) * half
	local slab = half / math.cos(p) + 0.3
	for side = -1, 1, 2 do
		local cf = base * CFrame.new(0, rise / 2 + 0.25, side * half / 2) * CFrame.Angles(side * p, 0, 0)
		block(parent, Vector3.new(length, 0.5, slab), cf, color, "Roof", ROOF_MAT)
	end
	deco(block(parent, Vector3.new(length + 0.3, 0.6, 0.9), base * CFrame.new(0, rise + 0.4, 0), DARK_WOOD, "Ridge", Enum.Material.Wood))
	local gh = gableHalf or half
	local gRise = math.tan(p) * gh
	for _, x in gables or {} do
		for side = -1, 1, 2 do
			-- a wedge is tall at its +Z end: the front half as it is, the back half turned round
			local w = Instance.new("WedgePart")
			w.Size = Vector3.new(0.6, gRise, gh)
			w.CFrame = base * CFrame.new(x, gRise / 2, side * gh / 2) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
			w.Color = gableColor or LOG
			w.Material = Enum.Material.WoodPlanks
			w.Anchored = true
			w.TopSurface = Enum.SurfaceType.Smooth
			w.BottomSurface = Enum.SurfaceType.Smooth
			w.Name = "Gable"
			w.Parent = parent
		end
	end
	return rise
end
LobbyKit.gableRoof = gableRoof

-- A hanging lantern (cf = its middle): a glowing core between two dark caps, with a warm light when `light`.
function LobbyKit.lantern(parent: Instance, cf: CFrame, light: boolean?): Part
	local metal = rgb(44, 38, 34)
	deco(block(parent, Vector3.new(1.1, 0.3, 1.1), cf * CFrame.new(0, 0.7, 0), metal, "LanternCap", Enum.Material.Metal), true)
	deco(block(parent, Vector3.new(1.1, 0.25, 1.1), cf * CFrame.new(0, -0.65, 0), metal, "LanternCap", Enum.Material.Metal), true)
	deco(block(parent, Vector3.new(0.15, 1, 0.15), cf * CFrame.new(0, 1.3, 0), metal, "LanternHook", Enum.Material.Metal), true)
	local core = block(parent, Vector3.new(0.75, 1.05, 0.75), cf, rgb(255, 206, 110), "LanternCore", Enum.Material.Neon)
	deco(core, true)
	if light then
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 196, 120)
		l.Range = 12
		l.Brightness = 1.3
		l.Shadows = false
		l.Parent = core
		tag(core, "LobbyLantern")
	end
	return core
end

-------------------------------------------------------------------------------------------------------------
-- trees
-------------------------------------------------------------------------------------------------------------
local OAK_LEAVES = { rgb(126, 178, 54), rgb(108, 162, 44), rgb(144, 190, 66), rgb(96, 150, 42) }
local PINE_LEAVES = { rgb(38, 100, 52), rgb(46, 114, 60), rgb(32, 88, 46) }
local TRUNK = rgb(112, 74, 46)
local BIRCH = rgb(238, 234, 226)

local function leaf(m: Instance, size: Vector3, cf: CFrame, color: Color3, far: boolean?): Part
	local p = block(m, size, cf, color, "Leaves", Enum.Material.Grass)
	deco(p, far)
	return p
end

local function trunk(m: Instance, w: number, h: number, pos: Vector3, color: Color3, far: boolean?, spin: number): Part
	local t = block(m, Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, spin, 0), color, "Trunk", Enum.Material.Wood)
	if far then
		deco(t, true)
	end
	return t
end

-- A lime oak: a straight brown trunk under a lumpy canopy of tumbled leaf cubes.
function LobbyKit.oak(parent: Instance, pos: Vector3, s: number, far: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "Oak"
	local rng = Random.new(math.floor(pos.X * 7.1 + pos.Z * 3.3))
	local h = 13 * s * rng:NextNumber(0.85, 1.15)
	m.PrimaryPart = trunk(m, 2.2 * s, h + 2, pos, shade(TRUNK, rng:NextNumber(0.9, 1.1)), far, rng:NextNumber(0, 1.5))
	local top = pos + Vector3.new(0, h + 3 * s, 0)
	for i = 1, if far then 4 else 9 do
		local a = i * 2.4
		local r = if i == 1 then 0 else rng:NextNumber(2.5, 5.2) * s
		local off = Vector3.new(math.cos(a) * r, rng:NextNumber(-2.5, 3) * s, math.sin(a) * r)
		local size = rng:NextNumber(5.5, 8.5) * s * (if far then 1.35 else 1)
		local cf = CFrame.new(top + off) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 1.6), rng:NextNumber(-0.6, 0.6))
		leaf(m, Vector3.one * size, cf, OAK_LEAVES[rng:NextInteger(1, #OAK_LEAVES)], far)
	end
	m.Parent = parent
	return m
end

-- A dark pine: a short trunk and stacked tiers of turned blocks (two per tier, 45 degrees apart), a few blocks
-- poking out of the sides, and a small tip.
function LobbyKit.pine(parent: Instance, pos: Vector3, s: number, far: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "Pine"
	local rng = Random.new(math.floor(pos.X * 3.7 + pos.Z * 11.3))
	local H = 30 * s * rng:NextNumber(0.85, 1.2)
	local trunkH = H * 0.2
	m.PrimaryPart = trunk(m, 1.8 * s, trunkH + 2, pos, rgb(96, 62, 38), far, 0)
	local tiers = if far then 3 else 5
	local tierH = (H - trunkH) / tiers
	local color = PINE_LEAVES[rng:NextInteger(1, #PINE_LEAVES)]
	local y = trunkH
	for i = 0, tiers - 1 do
		local k = 1 - i / tiers
		local wd = H * 0.42 * k + 2.5 * s
		local hh = tierH * 1.25
		local cf = CFrame.new(pos + Vector3.new(0, y + hh / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.6), 0)
		leaf(m, Vector3.new(wd, hh, wd), cf, shade(color, 0.92 + i * 0.04), far)
		if not far then
			leaf(m, Vector3.new(wd * 0.82, hh * 0.8, wd * 0.82), cf * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, hh * 0.15, 0), shade(color, 1 + i * 0.04), far)
			if i < 3 then
				local a = rng:NextNumber(0, math.pi * 2)
				local bit = wd * 0.32
				leaf(m, Vector3.one * bit, CFrame.new(pos + Vector3.new(math.cos(a) * wd * 0.5, y + hh * rng:NextNumber(0.2, 0.6), math.sin(a) * wd * 0.5)) * CFrame.Angles(0, a, 0), shade(color, 0.86), far)
			end
		end
		y += tierH
	end
	leaf(m, Vector3.new(2 * s, 3 * s, 2 * s), CFrame.new(pos + Vector3.new(0, y + 1.2 * s, 0)) * CFrame.Angles(0, 0.4, 0), shade(color, 1.15), far)
	m.Parent = parent
	return m
end

-- A birch: a tall white trunk with black marks and a small lime canopy up high.
function LobbyKit.birch(parent: Instance, pos: Vector3, s: number, far: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "Birch"
	local rng = Random.new(math.floor(pos.X * 5.3 + pos.Z * 9.7))
	local h = 20 * s * rng:NextNumber(0.9, 1.15)
	local w = 1.5 * s
	local spin = rng:NextNumber(0, 1.5)
	m.PrimaryPart = trunk(m, w, h + 2, pos, BIRCH, far, spin)
	if not far then
		for i = 1, 3 do
			local y = h * (0.2 + i * 0.18)
			deco(block(m, Vector3.new(w + 0.06, 0.35, w * 0.5), CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, spin + i, 0), rgb(40, 38, 40), "BirchMark", Enum.Material.SmoothPlastic), true)
		end
	end
	local top = pos + Vector3.new(0, h + 2 * s, 0)
	for i = 1, if far then 3 else 5 do
		local a = i * 2.2
		local r = if i == 1 then 0 else rng:NextNumber(1.8, 3.2) * s
		local size = rng:NextNumber(4, 6) * s
		leaf(m, Vector3.one * size, CFrame.new(top + Vector3.new(math.cos(a) * r, rng:NextNumber(-1.5, 2) * s, math.sin(a) * r)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 1.6), rng:NextNumber(-0.5, 0.5)), OAK_LEAVES[rng:NextInteger(1, #OAK_LEAVES)], far)
	end
	m.Parent = parent
	return m
end

-- A thick forest round the box x0..x1, z0..z1 (the fenced lobby): a tree every ~11 studs from `gap` studs out
-- to `near` (detailed), then a thinner, cheap, shadowless ring out to `far`. Pines, oaks and some birches.
function LobbyKit.forest(parent: Instance, box: { x0: number, x1: number, z0: number, z1: number }, opts: { seed: number?, gap: number?, near: number?, far: number?, skip: ((number, number) -> boolean)? }?)
	local o = opts or {}
	local rng = Random.new(o.seed or 5)
	local SP = 11
	local gap, near, far = o.gap or 4, o.near or 46, o.far or 120
	for gx = box.x0 - far, box.x1 + far, SP do
		for gz = box.z0 - far, box.z1 + far, SP do
			local x = gx + rng:NextNumber(-SP * 0.4, SP * 0.4)
			local z = gz + rng:NextNumber(-SP * 0.4, SP * 0.4)
			local dx = math.max(box.x0 - x, x - box.x1, 0)
			local dz = math.max(box.z0 - z, z - box.z1, 0)
			local d = math.sqrt(dx * dx + dz * dz)
			local roll = rng:NextNumber()
			local s = rng:NextNumber(0.9, 1.3)
			local thin = rng:NextNumber()
			if d < gap or d > far or (o.skip and o.skip(x, z)) then
				continue
			end
			local isFar = d > near
			if isFar and thin > 0.42 then
				continue
			end
			local pos = Vector3.new(x, 0, z)
			if roll < 0.42 then
				LobbyKit.pine(parent, pos, s, isFar)
			elseif roll < 0.86 then
				LobbyKit.oak(parent, pos, s, isFar)
			else
				LobbyKit.birch(parent, pos, s, isFar)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- people and small props
-------------------------------------------------------------------------------------------------------------
-- A blocky shopkeeper (anchored parts, R6 proportions) standing at `cf` (feet), facing cf.LookVector.
function LobbyKit.vendor(parent: Instance, cf: CFrame, shirt: Color3, hat: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "Vendor"
	local skin = rgb(234, 186, 148)
	local function piece(size: Vector3, at: Vector3, color: Color3, name: string, material: Enum.Material?): Part
		local p = PropKit.part({ size = size, cf = cf * CFrame.new(at), color = color, parent = m, name = name, material = material or Enum.Material.SmoothPlastic })
		deco(p)
		return p
	end
	piece(Vector3.new(2, 2, 1), Vector3.new(0, 1, 0), rgb(48, 72, 124), "Legs")
	local torso = piece(Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), shirt, "Torso", Enum.Material.Fabric)
	-- plaid: darker bands across the shirt
	for _, y in { 2.55, 3.35 } do
		piece(Vector3.new(2.04, 0.22, 1.04), Vector3.new(0, y, 0), shade(shirt, 0.62), "Plaid", Enum.Material.Fabric)
	end
	piece(Vector3.new(0.22, 2.04, 1.04), Vector3.new(0.45, 3, 0), shade(shirt, 0.62), "Plaid", Enum.Material.Fabric)
	for _, x in { -1.5, 1.5 } do
		piece(Vector3.new(1, 2, 1), Vector3.new(x, 3, 0), shirt, "Arm", Enum.Material.Fabric)
	end
	local head = piece(Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), skin, "Head")
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	piece(Vector3.new(1.5, 0.55, 0.35), Vector3.new(0, 4.12, -0.55), rgb(110, 62, 34), "Beard")
	piece(Vector3.new(1.75, 0.7, 1.4), Vector3.new(0, 5.2, 0), hat or rgb(200, 60, 50), "Beanie", Enum.Material.Fabric)
	m.PrimaryPart = torso
	m.Parent = parent
	return m
end

-- A treasure chest (cf = bottom middle, front = LookVector): a blue body, a round lid, gold bands and a lock.
function LobbyKit.chest(parent: Instance, cf: CFrame, body: Color3?): Part
	local c = body or rgb(58, 120, 226)
	local gold = rgb(255, 198, 54)
	local m = Instance.new("Model")
	m.Name = "Chest"
	deco(block(m, Vector3.new(3, 1.8, 2), cf * CFrame.new(0, 0.9, 0), c, "Body"))
	deco(log(m, 3, 1, cf * CFrame.new(0, 1.8, 0), shade(c, 1.12), "Lid"))
	for _, x in { -1.05, 1.05 } do
		deco(block(m, Vector3.new(0.32, 1.84, 2.06), cf * CFrame.new(x, 0.9, 0), gold, "Band", Enum.Material.SmoothPlastic))
		deco(log(m, 0.32, 1.05, cf * CFrame.new(x, 1.8, 0), gold, "Band"))
	end
	local lock = deco(block(m, Vector3.new(0.65, 0.75, 0.2), cf * CFrame.new(0, 1.65, -1.04), gold, "Lock", Enum.Material.SmoothPlastic))
	m.Parent = parent
	return lock :: Part
end

-- A barrel (cf = bottom middle): staves and two dark hoops.
function LobbyKit.barrel(parent: Instance, cf: CFrame, s: number?)
	local k = s or 1
	post(parent, 3 * k, 1.1 * k, cf * CFrame.new(0, 1.5 * k, 0), rgb(150, 96, 52), "Barrel").Material = Enum.Material.WoodPlanks
	for _, y in { 0.7, 2.3 } do
		deco(post(parent, 0.22 * k, 1.16 * k, cf * CFrame.new(0, y * k, 0), rgb(54, 48, 46), "Hoop"), true)
	end
end

-- A pumpkin (cf = bottom middle).
function LobbyKit.pumpkin(parent: Instance, cf: CFrame, s: number?)
	local k = s or 1
	local p = ball(parent, 1.6 * k, cf * CFrame.new(0, 0.7 * k, 0), rgb(255, 128, 26), "Pumpkin")
	p.Size = Vector3.new(1.8, 1.4, 1.8) * k
	deco(p)
	deco(block(parent, Vector3.new(0.2, 0.45, 0.2) * k, cf * CFrame.new(0, 1.55 * k, 0), rgb(86, 120, 40), "Stem", Enum.Material.SmoothPlastic))
end

-- A stack of logs lying end-on toward cf.LookVector (cf = bottom middle): 3, 2 and 1 logs.
function LobbyKit.logPile(parent: Instance, cf: CFrame, length: number?, r: number?)
	local len, rad = length or 5, r or 0.9
	local row = 0
	for n = 3, 1, -1 do
		for i = 0, n - 1 do
			local x = (i - (n - 1) / 2) * rad * 2.05
			cabinLog(parent, len, rad, cf * CFrame.new(x, rad + row * rad * 1.75, 0) * CFrame.Angles(0, math.rad(90), 0))
		end
		row += 1
	end
end

-------------------------------------------------------------------------------------------------------------
-- stalls
-------------------------------------------------------------------------------------------------------------
export type Stall = { model: Model, at: CFrame, W: number, D: number, H: number }

-- A roofed wooden stall like Chop A Forest's CLASSES / GEMS / REWARDS booths. `at` = the middle of its floor, the
-- open front = at.LookVector (local -Z): a counter (unless counter = false), plank back and side walls, log
-- corner posts, a gabled shingle roof in `roof`, the plank sign standing on the roof's front and two lanterns.
function LobbyKit.stall(parent: Instance, at: CFrame, title: string, roof: Color3, opts: { width: number?, counter: boolean?, lights: boolean? }?): Stall
	local o = opts or {}
	local m = Instance.new("Model")
	m.Name = "Stall"
	local W, D, H = o.width or 14, 8, 8.5
	local function L(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	block(m, Vector3.new(W + 1, 0.7, D + 1), L(0, 0.35, 0), WOOD, "Floor")
	for _, x in { -W / 2, W / 2 } do
		for _, z in { -D / 2, D / 2 } do
			post(m, H + 0.6, 0.55, L(x, (H + 0.6) / 2, z), LOG)
		end
	end
	block(m, Vector3.new(W, H, 0.5), L(0, H / 2, D / 2 - 0.1), WOOD, "Back")
	for _, x in { -W / 2, W / 2 } do
		block(m, Vector3.new(0.5, H, D), L(x, H / 2, 0), shade(WOOD, 0.9), "Side")
	end
	if o.counter ~= false then
		block(m, Vector3.new(W - 1.2, 3.4, 1.6), L(0, 2.4, -D / 2 + 1.2), LIGHT_WOOD, "Counter")
		block(m, Vector3.new(W - 0.6, 0.4, 2.2), L(0, 4.3, -D / 2 + 1.2), DARK_WOOD, "CounterTop", Enum.Material.Wood)
		for _, x in { -W / 2 + 1.7, W / 2 - 1.7 } do
			deco(cabinLog(m, 2.4, 0.5, L(x, 1.3, -D / 2 + 0.6) * CFrame.Angles(0, math.rad(90), 0)))
		end
	end
	-- the roof, overhanging the front
	local half = D / 2 + 1.6
	local roofAt = L(0, H + 0.2, -0.4)
	local rise = gableRoof(m, roofAt, W + 2, half, 24, roof, { -W / 2, W / 2 }, D / 2, shade(WOOD, 0.85))
	-- the sign stands on the front slab
	local signW = math.min(W * 0.8, 11)
	LobbyKit.plankSign(m, roofAt * CFrame.new(0, rise * 0.55 + 1.8, -half * 0.3), signW, 3, title)
	for _, x in { -signW / 3, signW / 3 } do
		deco(block(m, Vector3.new(0.35, 2.2, 0.35), roofAt * CFrame.new(x, rise * 0.55 - 0.3, -half * 0.3 + 0.4), DARK_WOOD, "SignPost", Enum.Material.Wood), true)
	end
	for _, x in { -W / 2, W / 2 } do
		LobbyKit.lantern(m, L(x, H - 2, -D / 2 - 0.9), o.lights ~= false and x > 0)
		deco(block(m, Vector3.new(0.25, 0.25, 1.1), L(x, H - 0.4, -D / 2 - 0.4), DARK_WOOD, "LanternArm", Enum.Material.Wood), true)
	end
	m.Parent = parent
	return { model = m, at = at, W = W, D = D, H = H }
end

-- The glowing pad in front of a stall (or anywhere): a LobbyPads glow frame tagged so client/LobbyFX can play a
-- burst (and open `window`) when you step on it.
-- `claim`: stepping on the pad claims that reward straight away (e.g. "daily") instead of opening `window`.
function LobbyKit.padZone(parent: Instance, cf: CFrame, w: number, d: number, color: Color3, window: string?, claim: string?)
	local glow = LobbyPads.glow(parent, cf, w, d, color)
	local frame = parent:FindFirstChild("GlowFrame")
	for _, c in parent:GetChildren() do
		-- (the calm WORLD_GEN pads are "PadFrame"s; only a claim pad acts as a zone there)
		local name = c.Name == "GlowFrame" or (claim ~= nil and c.Name == "PadFrame")
		if name and not CollectionService:HasTag(c, "LobbyPadZone") then
			frame = c
		end
	end
	if frame then
		tag(frame, "LobbyPadZone", { Window = window, Color = color, Claim = claim })
	end
	return glow
end

-------------------------------------------------------------------------------------------------------------
-- leaderboards
-------------------------------------------------------------------------------------------------------------
export type BoardRow = { frame: Frame, rank: TextLabel, icon: ImageLabel, name: TextLabel, value: TextLabel }
export type Board = { key: string, rows: { BoardRow }, part: BasePart }

local RANK_COLORS = { rgb(246, 190, 50), rgb(198, 206, 218), rgb(218, 140, 74) }

local function text(parent: Instance, s: string, size: UDim2, pos: UDim2, color: Color3, align: Enum.TextXAlignment?, name: string?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name or "Text"
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = Config.UI.font
	l.TextScaled = true
	l.Text = s
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = rgb(40, 22, 10)
	st.Parent = l
	l.Parent = parent
	return l
end

local function row(parent: Instance, y: number, h: number, color: Color3, alpha: number, name: string): BoardRow
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha
	f.Size = UDim2.fromScale(0.94, h)
	f.Position = UDim2.fromScale(0.03, y)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.25, 0)
	c.Parent = f
	f.Parent = parent
	local rank = text(f, "", UDim2.fromScale(0.13, 0.8), UDim2.fromScale(0.01, 0.1), Color3.new(1, 1, 1), nil, "Rank")
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundColor3 = rgb(70, 50, 36)
	icon.BackgroundTransparency = 0.3
	icon.Size = UDim2.fromScale(0.1, 0.84)
	icon.Position = UDim2.fromScale(0.15, 0.08)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = icon
	local ic = Instance.new("UICorner")
	ic.CornerRadius = UDim.new(1, 0)
	ic.Parent = icon
	icon.Parent = f
	local nameL = text(f, "", UDim2.fromScale(0.44, 0.72), UDim2.fromScale(0.27, 0.14), Color3.new(1, 1, 1), Enum.TextXAlignment.Left, "PlayerName")
	local value = text(f, "", UDim2.fromScale(0.26, 0.72), UDim2.fromScale(0.72, 0.14), Color3.new(1, 1, 1), Enum.TextXAlignment.Right, "Value")
	return { frame = f, rank = rank, icon = icon, name = nameL, value = value }
end

-- The rows of a leaderboard face, filling `gui` from y0 to y1 (fractions): 8 rows (gold, silver, bronze, then
-- the rest; hidden until LobbyBoards fills them), a YOU row (client/LobbyFX fills it) and ALL TIME.
function LobbyKit.rows(gui: Instance, y0: number, y1: number): { BoardRow }
	local span = y1 - y0
	local step = span * 0.096
	local rows: { BoardRow } = {}
	for i = 1, 8 do
		local r = row(gui, y0 + (i - 1) * step, step * 0.9, RANK_COLORS[i] or Color3.new(1, 1, 1), if i <= 3 then 0 else 0.9, "Row" .. i)
		r.rank.Text = "#" .. i
		r.frame.Visible = false
		table.insert(rows, r)
	end
	local you = row(gui, y0 + 8 * step + step * 0.1, step * 0.95, rgb(255, 226, 120), 0.75, "You")
	local ys = Instance.new("UIStroke")
	ys.Thickness = 3
	ys.Color = rgb(255, 214, 80)
	ys.Parent = you.frame
	you.rank.Text = "-"
	text(gui, "ALL TIME", UDim2.fromScale(0.5, step * 0.6), UDim2.fromScale(0.25, y0 + 9 * step + step * 0.15), rgb(230, 210, 170), nil, "Footer")
	return rows
end

-- Turns an existing board's text face (a PropKit.facePanel label) into leaderboard rows: the label is hidden, the
-- rows go into its SurfaceGui and the panel part is tagged "LobbyBoard" with `key` for LobbyBoards.
function LobbyKit.boardFace(label: TextLabel, key: string)
	label.Visible = false
	local gui = label.Parent :: Instance
	LobbyKit.rows(gui, 0.01, 0.99)
	tag(gui.Parent :: Instance, "LobbyBoard", { Key = key })
end

-- A roofed leaderboard like Chop A Forest's (at = its foot, front = LookVector): two log posts, a little shingle
-- roof with a round emblem on top, and a dark board listing 8 rows (gold, silver, bronze, then the rest), a YOU
-- row (client/LobbyFX fills it per player) and ALL TIME. LobbyBoards fills the rows; the board part is tagged
-- "LobbyBoard" with its Key.
function LobbyKit.board(parent: Instance, at: CFrame, title: string, key: string, emblem: string): Board
	local m = Instance.new("Model")
	m.Name = "Board"
	local W, H, Y0 = 11, 13.5, 2.4
	local function L(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	local postH = Y0 + H + 2.4
	for _, x in { -W / 2 - 0.75, W / 2 + 0.75 } do
		post(m, postH, 0.75, L(x, postH / 2, 0.2), LOG)
		deco(block(m, Vector3.new(2, 0.8, 2), L(x, 0.4, 0.2), STONE, "Footing", Enum.Material.Slate), true)
	end
	local board = block(m, Vector3.new(W, H, 0.6), L(0, Y0 + H / 2, 0.2), BOARD, "Board")
	for _, e in { { 0, H / 2, W + 0.6, 0.6 }, { 0, -H / 2, W + 0.6, 0.6 }, { W / 2, 0, 0.6, H }, { -W / 2, 0, 0.6, H } } do
		deco(block(m, Vector3.new(e[3], e[4], 0.8), L(e[1], Y0 + H / 2 + e[2], 0.15), LIGHT_WOOD, "Trim", Enum.Material.Wood), true)
	end
	local roofAt = L(0, Y0 + H + 0.9, 0.2)
	local rise = gableRoof(m, roofAt, W + 3.4, 2.2, 28, SHINGLE)
	-- the emblem: a gold disc with a picture, standing on the ridge
	local disc = roofAt * CFrame.new(0, rise + 1.9, -0.3)
	deco(log(m, 0.45, 1.6, disc * CFrame.Angles(0, math.rad(90), 0), rgb(232, 170, 40), "Emblem"))
	deco(log(m, 0.5, 1.25, disc * CFrame.Angles(0, math.rad(90), 0), rgb(246, 214, 120), "EmblemFace"))
	local face = spot(m, disc * CFrame.new(0, 0, -0.27), Vector3.new(2.4, 2.4, 0.05), "EmblemIcon")
	local eg = Instance.new("SurfaceGui")
	eg.Face = Enum.NormalId.Front
	eg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	eg.PixelsPerStud = 40
	eg.LightInfluence = 0
	eg.Parent = face
	local el = Instance.new("TextLabel")
	el.BackgroundTransparency = 1
	el.Size = UDim2.fromScale(0.86, 0.86)
	el.Position = UDim2.fromScale(0.07, 0.07)
	el.TextScaled = true
	el.Text = emblem
	el.Parent = eg

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.15
	gui.Brightness = 1.3
	gui.Parent = board
	text(gui, title, UDim2.fromScale(0.9, 0.075), UDim2.fromScale(0.05, 0.02), rgb(255, 238, 200), nil, "Title")
	local rows = LobbyKit.rows(gui, 0.11, 0.89)
	tag(board, "LobbyBoard", { Key = key })
	m.Parent = parent
	return { key = key, rows = rows, part = board }
end

-------------------------------------------------------------------------------------------------------------
-- the event notice board
-------------------------------------------------------------------------------------------------------------
-- The roofed notice board for the next event (at = its foot, front = LookVector): a purple roof with pumpkins,
-- a log pile beside it, the poster, a floating "??? ARRIVES IN" countdown (client/LobbyFX counts down to the
-- holder's EndsAt), and two prompts: J "Read the news" and E "Get Notified" (the client asks for notifications).
function LobbyKit.eventBoard(parent: Instance, at: CFrame, ev: { title: string, name: string, startsAt: number, dateText: string })
	local m = Instance.new("Model")
	m.Name = "EventBoard"
	local W, H, Y0 = 12, 7.6, 2.4
	local purple = rgb(112, 56, 176)
	local function L(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	local postH = Y0 + H + 1.8
	for _, x in { -W / 2 - 0.6, W / 2 + 0.6 } do
		post(m, postH, 0.6, L(x, postH / 2, 0.2), DARK_WOOD)
	end
	local board = block(m, Vector3.new(W, H, 0.5), L(0, Y0 + H / 2, 0.2), BOARD, "Poster")
	for _, e in { { 0, H / 2, W + 0.5, 0.5 }, { 0, -H / 2, W + 0.5, 0.5 } } do
		deco(block(m, Vector3.new(e[3], e[4], 0.7), L(e[1], Y0 + H / 2 + e[2], 0.15), purple, "Trim", Enum.Material.Wood), true)
	end
	local roofAt = L(0, Y0 + H + 0.6, 0.2)
	local rise = gableRoof(m, roofAt, W + 2.6, 2.2, 26, purple)
	for _, x in { -W / 2 - 0.4, W / 2 + 0.4 } do
		LobbyKit.pumpkin(m, roofAt * CFrame.new(x, rise * 0.3 + 0.2, -0.2), 0.8)
	end
	-- the poster
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.15
	gui.Brightness = 1.3
	gui.Parent = board
	local paper = Instance.new("Frame")
	paper.BorderSizePixel = 0
	paper.BackgroundColor3 = rgb(44, 26, 58)
	paper.Size = UDim2.fromScale(0.96, 0.92)
	paper.Position = UDim2.fromScale(0.02, 0.04)
	paper.Parent = gui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = paper
	local banner = Instance.new("TextLabel")
	banner.BackgroundTransparency = 1
	banner.Size = UDim2.fromScale(0.7, 0.3)
	banner.Position = UDim2.fromScale(0.04, 0.04)
	banner.Font = Enum.Font.LuckiestGuy
	banner.TextScaled = true
	banner.Text = "🎃 " .. ev.title
	banner.TextColor3 = Color3.new(1, 1, 1)
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(rgb(255, 210, 80), rgb(255, 120, 20))
	bg.Rotation = 90
	bg.Parent = banner
	local bs = Instance.new("UIStroke")
	bs.Thickness = 3
	bs.Color = rgb(30, 10, 30)
	bs.Parent = banner
	banner.Parent = paper
	text(paper, ev.dateText, UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.75, 0.08), rgb(255, 150, 60), nil, "Date")
	text(paper, ev.name .. " arrives " .. ev.dateText, UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.4), Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	text(paper, "Something is coming to the forest...", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.57), rgb(220, 200, 255), Enum.TextXAlignment.Left)
	text(paper, "Get notified when it starts! 🦇", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.75), rgb(255, 214, 90), Enum.TextXAlignment.Left)

	-- the countdown floating above
	local holder = spot(m, roofAt * CFrame.new(0, rise + 6.5, 0), Vector3.one, "Countdown")
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(18, 5)
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.Parent = holder
	local top = text(bb, ev.name .. " ARRIVES IN", UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0), rgb(214, 140, 255), nil, "Heading")
	top.Font = Enum.Font.LuckiestGuy
	local count = text(bb, "", UDim2.fromScale(1, 0.58), UDim2.fromScale(0, 0.4), Color3.new(1, 1, 1), nil, "Time")
	count.Font = Enum.Font.LuckiestGuy
	local cg = Instance.new("UIGradient")
	cg.Color = ColorSequence.new(rgb(255, 214, 90), rgb(255, 128, 30))
	cg.Rotation = 90
	cg.Parent = count
	tag(holder, "LobbyCountdown", { EndsAt = ev.startsAt })

	-- the two prompts
	local news = spot(m, L(-2, 3, -1.5), Vector3.one, "NewsPrompt")
	local p1 = PropKit.prompt(news, "Read the news", ev.title, "News", 12)
	p1.KeyboardKeyCode = Enum.KeyCode.J
	p1.GamepadKeyCode = Enum.KeyCode.ButtonY
	local notify = spot(m, L(2, 3, -1.5), Vector3.one, "NotifyPrompt")
	local p2 = PropKit.prompt(notify, "Get Notified", ev.name, nil, 12)
	p2:SetAttribute("Notify", true)

	-- logs piled beside it, pumpkins and a lantern; the FX spots (bats, mist)
	LobbyKit.logPile(m, L(W / 2 + 4, 0, 0.5) * CFrame.Angles(0, math.rad(90), 0), 4.5, 0.9)
	for i, x in { -W / 2 - 1.5, -1, W / 2 + 1.2 } do
		LobbyKit.pumpkin(m, L(x, 0, -2.2 - (i % 2)), 0.9 + (i % 2) * 0.3)
	end
	tag(spot(m, roofAt * CFrame.new(0, rise + 2, 0), Vector3.one, "BatSpot"), "LobbyFX", { Kind = "bats" })
	tag(spot(m, L(0, 0.6, -1.5), Vector3.new(W + 4, 1, 4), "MistSpot"), "LobbyFX", { Kind = "mist" })
	m.Parent = parent
	return { holder = holder, board = board }
end

-------------------------------------------------------------------------------------------------------------
-- the lodge (spawn) and the garage
-------------------------------------------------------------------------------------------------------------
-- A window on a log wall (cf = its middle, facing out): frame, glass, cross bars and open shutters.
local function window(parent: Instance, cf: CFrame, w: number, h: number)
	deco(block(parent, Vector3.new(w + 0.8, h + 0.8, 0.35), cf, LIGHT_WOOD, "WindowFrame", Enum.Material.Wood))
	local glass = deco(block(parent, Vector3.new(w, h, 0.2), cf * CFrame.new(0, 0, -0.12), rgb(168, 212, 236), "Glass", Enum.Material.Glass), true)
	glass.Transparency = 0.15
	deco(block(parent, Vector3.new(0.25, h, 0.3), cf * CFrame.new(0, 0, -0.2), LIGHT_WOOD, "Bar", Enum.Material.Wood), true)
	deco(block(parent, Vector3.new(w, 0.25, 0.3), cf * CFrame.new(0, 0, -0.2), LIGHT_WOOD, "Bar", Enum.Material.Wood), true)
	for side = -1, 1, 2 do
		deco(block(parent, Vector3.new(w * 0.55, h + 0.6, 0.3), cf * CFrame.new(side * (w / 2 + 0.4 + w * 0.27), 0, -0.25) * CFrame.Angles(0, side * math.rad(18), 0), DARK_WOOD, "Shutter"), true)
	end
end

-- The log lodge players spawn on (like Chop A Forest's cabin): `centre` = middle of its footprint, the front and
-- its porch face +Z. Log walls with light log ends, windows with shutters, a shingle roof, a stone chimney, a
-- porch deck with a roof and rails, a side DOOR (on +X) with steps. Returns where to put the spawn.
function LobbyKit.lodge(parent: Instance, centre: Vector3): CFrame
	local m = Instance.new("Model")
	m.Name = "Lodge"
	local W, D, R = 46, 26, 1
	local base = 1.2
	local logs = 7
	local wallTop = base + logs * 2 * R
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(centre + Vector3.new(x, y, z))
	end
	block(m, Vector3.new(W + 1.5, base, D + 1.5), at(0, base / 2, 0), STONE, "Foundation", Enum.Material.Slate)
	block(m, Vector3.new(W - 1, wallTop - base, D - 1), at(0, (wallTop + base) / 2, 0), shade(LOG, 0.7), "Inside", Enum.Material.Wood)
	for i = 0, logs - 1 do
		local y = base + R + i * 2 * R
		for side = -1, 1, 2 do
			cabinLog(m, W + 2.6, R, at(0, y, side * D / 2))
			cabinLog(m, D + 2.6, R, at(side * W / 2, y + R * 0.5, 0) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
	-- windows on the front and the back, the front door
	for _, x in { -14, 14 } do
		window(m, at(x, 8.5, D / 2 + R + 0.1) * CFrame.Angles(0, math.pi, 0), 4, 4)
		window(m, at(x, 8.5, -D / 2 - R - 0.1), 4, 4)
	end
	block(m, Vector3.new(5.2, 8, 0.4), at(0, base + 4, D / 2 + R + 0.15), LIGHT_WOOD, "Door")
	deco(block(m, Vector3.new(6.2, 9, 0.3), at(0, base + 4.4, D / 2 + R + 0.02), DARK_WOOD, "DoorFrame", Enum.Material.Wood))
	-- roof and chimney
	local roofAt = at(0, wallTop, 0) * CFrame.Angles(0, 0, 0)
	gableRoof(m, roofAt, W + 5, D / 2 + 3, 30, SHINGLE, { -W / 2, W / 2 }, D / 2 + R, LOG)
	block(m, Vector3.new(4.5, 30, 4.5), at(-W / 2 + 6, 15, -3), STONE, "Chimney", Enum.Material.Slate)
	deco(block(m, Vector3.new(5.2, 0.8, 5.2), at(-W / 2 + 6, 30.4, -3), shade(STONE, 0.8), "ChimneyCap", Enum.Material.Slate))
	-- the porch: deck, steps, rails, a roof on log posts
	local deckH = 1.6
	local pd = 11
	local pz = D / 2 + R + pd / 2
	block(m, Vector3.new(W - 4, deckH, pd), at(0, deckH / 2, pz), WOOD, "Porch")
	for i = 1, 2 do
		block(m, Vector3.new(10, deckH * (1 - i / 3), 1.4), at(0, deckH * (1 - i / 3) / 2, D / 2 + R + pd + i * 1.4 - 0.7), WOOD, "Step")
	end
	for _, x in { -(W / 2 - 2.5), W / 2 - 2.5 } do
		post(m, 11, 0.7, at(x, deckH + 5.5, D / 2 + R + pd - 0.8), LOG)
		-- side rails only: the front stays open so the view from the spawn is clear
		deco(log(m, pd - 1, 0.3, at(x, deckH + 2.6, pz - 0.4) * CFrame.Angles(0, math.rad(90), 0), LOG, "Rail"))
	end
	local porchRoof = block(m, Vector3.new(W - 2, 0.5, pd + 1.6), at(0, deckH + 11.2, pz) * CFrame.Angles(math.rad(-10), 0, 0), SHINGLE, "PorchRoof", ROOF_MAT)
	porchRoof.CanCollide = true
	deco(log(m, W - 2, 0.5, at(0, deckH + 10.5, D / 2 + R + pd - 0.8), LOG, "Beam"))
	for _, x in { -6.5, 6.5 } do
		LobbyKit.lantern(m, at(x, deckH + 7.5, D / 2 + R + 0.9), x < 0)
	end
	-- the side door with its DOOR sign, steps, tools leaning on the wall, a lantern
	local sx = W / 2 + R + 0.15
	block(m, Vector3.new(0.4, 8, 5), at(sx, base + 4, 3), LIGHT_WOOD, "SideDoor")
	deco(block(m, Vector3.new(0.3, 9, 6.2), at(sx - 0.12, base + 4.4, 3), DARK_WOOD, "DoorFrame", Enum.Material.Wood))
	LobbyKit.plankSign(m, CFrame.lookAt((at(sx + 0.4, base + 10.4, 3)).Position, (at(sx + 5, base + 10.4, 3)).Position), 5.6, 2.2, "DOOR")
	for i = 1, 3 do
		block(m, Vector3.new(1.4, base * (1 - (i - 1) / 3) + 0.2, 6), at(sx + 0.4 + i * 1.4 - 0.7, (base * (1 - (i - 1) / 3) + 0.2) / 2, 3), WOOD, "Step")
	end
	LobbyKit.lantern(m, at(sx + 1, base + 8, -1), true)
	-- an axe and a shovel against the wall
	deco(block(m, Vector3.new(0.3, 4.4, 0.3), at(sx + 0.9, 2.4, 7.2) * CFrame.Angles(0, 0, math.rad(-10)), LIGHT_WOOD, "Handle", Enum.Material.Wood))
	deco(block(m, Vector3.new(0.25, 0.9, 1.2), at(sx + 1.25, 4.4, 7.4), rgb(180, 50, 40), "AxeHead", Enum.Material.Metal))
	deco(block(m, Vector3.new(0.3, 4.4, 0.3), at(sx + 0.9, 2.4, 8.6) * CFrame.Angles(0, 0, math.rad(-8)), LIGHT_WOOD, "Handle", Enum.Material.Wood))
	deco(block(m, Vector3.new(0.2, 1.4, 1), at(sx + 1.2, 0.9, 8.6), rgb(150, 150, 156), "ShovelHead", Enum.Material.Metal))
	m.Parent = parent
	return at(0, deckH - 0.45, D / 2 + R + pd - 4)
end

-- The garage (Chop A Forest's GARAGE): a big log barn whose gable end faces at.LookVector, an opening with both
-- barn doors swung out, a mower parked inside under two hanging lamps, the GARAGE sign on the gable, and a
-- yellow pad in front (opens the Garage window). `at` = middle of its footprint.
function LobbyKit.garage(parent: Instance, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Garage"
	local W, D, R = 26, 24, 1 -- W across the front (local X), D deep (local Z, front at -Z)
	local base = 1
	local logs = 6
	local wallTop = base + logs * 2 * R
	local open = 14
	local function L(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	block(m, Vector3.new(W + 1.5, base, D + 1.5), L(0, base / 2, 0), STONE, "Foundation", Enum.Material.Slate)
	block(m, Vector3.new(W - 2, 0.2, D - 2), L(0, base + 0.1, 0), rgb(150, 146, 140), "Floor", Enum.Material.Concrete)
	for i = 0, logs - 1 do
		local y = base + R + i * 2 * R
		-- side walls run front to back, their log ends showing at the front
		for side = -1, 1, 2 do
			cabinLog(m, D + 2.6, R, L(side * W / 2, y, 0) * CFrame.Angles(0, math.rad(90), 0))
		end
		cabinLog(m, W + 2.6, R, L(0, y + R * 0.5, D / 2))
		-- the front wall, both sides of the opening
		local seg = (W - open) / 2
		for side = -1, 1, 2 do
			cabinLog(m, seg + 1.3, R, L(side * (open / 2 + seg / 2 + 0.65), y + R * 0.5, -D / 2))
		end
	end
	-- plank lining so the room inside reads as walls
	block(m, Vector3.new(W - 1.2, wallTop - base, 0.3), L(0, (wallTop + base) / 2, D / 2 - 1.1), shade(WOOD, 0.8), "Lining")
	for side = -1, 1, 2 do
		block(m, Vector3.new(0.3, wallTop - base, D - 1.2), L(side * (W / 2 - 1.1), (wallTop + base) / 2, 0), shade(WOOD, 0.8), "Lining")
	end
	-- over the opening, the roof and its gables (front and back)
	cabinLog(m, open + 2, R, L(0, wallTop - R, -D / 2), false)
	local roofAt = L(0, wallTop, 0) * CFrame.Angles(0, math.rad(90), 0)
	gableRoof(m, roofAt, D + 4, W / 2 + 2.5, 35, SHINGLE, { -D / 2, D / 2 }, W / 2 + R, LOG)
	LobbyKit.plankSign(m, L(0, wallTop + 4.2, -D / 2 - 0.9), 14, 3.4, "GARAGE")
	-- the barn doors, swung out
	for side = -1, 1, 2 do
		local hinge = L(side * open / 2, base, -D / 2 - R - 0.2)
		local swing = hinge * CFrame.Angles(0, side * math.rad(-62), 0)
		local door = block(m, Vector3.new(open / 2, wallTop - base - 2.4, 0.5), swing * CFrame.new(side * open / 4, (wallTop - base - 2.4) / 2, 0), WOOD, "BarnDoor")
		deco(block(m, Vector3.new(open / 2 * 1.25, 0.5, 0.2), door.CFrame * CFrame.new(0, 0, -0.32) * CFrame.Angles(0, 0, math.rad(side * 50)), LIGHT_WOOD, "Brace", Enum.Material.Wood), true)
		deco(block(m, Vector3.new(open / 2, 0.5, 0.2), door.CFrame * CFrame.new(0, (wallTop - base - 2.4) / 2 - 0.6, -0.32), LIGHT_WOOD, "Brace", Enum.Material.Wood), true)
	end
	-- the mower inside and two hanging lamps
	local inside = L(0, base + 0.2, 1) * CFrame.Angles(0, math.pi, 0)
	if not Models.place("mower_tractor", m, inside, 1.7, true) then
		block(m, Vector3.new(6, 3, 8), inside * CFrame.new(0, 1.5, 0), rgb(255, 200, 40), "DisplayMower", Enum.Material.SmoothPlastic)
	end
	for _, x in { -4, 4 } do
		LobbyKit.lantern(m, L(x, wallTop - 2.2, -2), x > 0)
	end
	LobbyKit.barrel(m, L(W / 2 + 2.6, 0, -D / 2 - 1.5))
	m.Parent = parent
	return m
end

-------------------------------------------------------------------------------------------------------------
-- backyard and garden
-------------------------------------------------------------------------------------------------------------
-- The chopping stump with an axe stuck in it, on a ring of trodden dirt.
function LobbyKit.chopStump(parent: Instance, pos: Vector3)
	deco(post(parent, 0.1, 4, CFrame.new(pos + Vector3.new(0, 0.05, 0)), rgb(116, 82, 54), "DirtRing"), true).Material = Enum.Material.Ground
	post(parent, 2.2, 1.4, CFrame.new(pos + Vector3.new(0, 1.1, 0)), rgb(140, 92, 52), "Stump")
	deco(post(parent, 0.1, 1.25, CFrame.new(pos + Vector3.new(0, 2.25, 0)), LOG_END, "Rings"), true)
	local axe = CFrame.new(pos + Vector3.new(0.2, 2.6, 0)) * CFrame.Angles(0, 0.6, math.rad(-35))
	deco(block(parent, Vector3.new(0.3, 3.4, 0.3), axe * CFrame.new(0, 1.5, 0), LIGHT_WOOD, "AxeHandle", Enum.Material.Wood))
	deco(block(parent, Vector3.new(0.3, 0.9, 1.3), axe * CFrame.new(0, -0.1, 0.3), rgb(170, 170, 176), "AxeHead", Enum.Material.Metal))
end

-- A red wheelbarrow (cf = where it stands, the handles toward -Z).
function LobbyKit.wheelbarrow(parent: Instance, cf: CFrame)
	local red = rgb(196, 52, 44)
	deco(block(parent, Vector3.new(2.6, 1.1, 3.2), cf * CFrame.new(0, 1.5, 0.4) * CFrame.Angles(math.rad(-8), 0, 0), red, "Tray", Enum.Material.Metal))
	deco(log(parent, 0.4, 0.7, cf * CFrame.new(0, 0.7, 2.2), rgb(40, 38, 38), "Wheel"))
	for _, x in { -0.9, 0.9 } do
		deco(block(parent, Vector3.new(0.25, 0.25, 4.4), cf * CFrame.new(x, 1.1, -0.6) * CFrame.Angles(math.rad(-10), 0, 0), LIGHT_WOOD, "Handle", Enum.Material.Wood))
		deco(block(parent, Vector3.new(0.25, 1.1, 0.25), cf * CFrame.new(x, 0.55, -0.6), LIGHT_WOOD, "Leg", Enum.Material.Wood))
	end
end

-- A plank outhouse (cf = foot, door toward LookVector).
function LobbyKit.outhouse(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Outhouse"
	block(m, Vector3.new(4.4, 8, 4.4), cf * CFrame.new(0, 4, 0), shade(WOOD, 1.05), "Shed")
	block(m, Vector3.new(5.4, 0.5, 5.6), cf * CFrame.new(0, 8.5, 0.2) * CFrame.Angles(math.rad(8), 0, 0), SHINGLE, "Roof", ROOF_MAT)
	deco(block(m, Vector3.new(3, 6.6, 0.2), cf * CFrame.new(0, 3.5, -2.25), LIGHT_WOOD, "Door"))
	deco(block(m, Vector3.new(0.6, 0.6, 0.1), cf * CFrame.new(0, 5.8, -2.37), rgb(40, 28, 20), "Moon"), true)
	m.Parent = parent
end

-- A clothes line: two T posts, a rope and plaid shirts and red overalls hanging on it (cf = middle, along X).
function LobbyKit.clothesline(parent: Instance, cf: CFrame, length: number)
	for side = -1, 1, 2 do
		deco(block(parent, Vector3.new(0.4, 6, 0.4), cf * CFrame.new(side * length / 2, 3, 0), LIGHT_WOOD, "LinePost", Enum.Material.Wood))
		deco(block(parent, Vector3.new(0.3, 0.3, 1.6), cf * CFrame.new(side * length / 2, 5.8, 0), LIGHT_WOOD, "LineArm", Enum.Material.Wood))
	end
	deco(block(parent, Vector3.new(length, 0.08, 0.08), cf * CFrame.new(0, 5.7, 0), rgb(235, 230, 220), "Rope", Enum.Material.Fabric), true)
	local clothes = { rgb(40, 110, 70), rgb(205, 40, 40), rgb(196, 50, 40), rgb(50, 70, 150) }
	for i, c in clothes do
		local x = -length / 2 + length * i / (#clothes + 1)
		local long = i == 2
		local h = if long then 3.6 else 2.2
		deco(block(parent, Vector3.new(1.8, h, 0.15), cf * CFrame.new(x, 5.6 - h / 2, 0), c, "Shirt", Enum.Material.Fabric))
		deco(block(parent, Vector3.new(1.84, 0.25, 0.18), cf * CFrame.new(x, 5.6 - h * 0.35, 0), shade(c, 0.55), "Plaid", Enum.Material.Fabric), true)
		if not long then
			for _, sx in { -1.15, 1.15 } do
				deco(block(parent, Vector3.new(0.5, 1.4, 0.15), cf * CFrame.new(x + sx, 5.0, 0), c, "Sleeve", Enum.Material.Fabric), true)
			end
		end
	end
end

-- A scarecrow in a plaid shirt with a straw hat (cf = foot).
function LobbyKit.scarecrow(parent: Instance, cf: CFrame)
	deco(block(parent, Vector3.new(0.4, 6.5, 0.4), cf * CFrame.new(0, 3.25, 0), LIGHT_WOOD, "Pole", Enum.Material.Wood))
	deco(block(parent, Vector3.new(5, 0.35, 0.35), cf * CFrame.new(0, 4.6, 0), LIGHT_WOOD, "Arms", Enum.Material.Wood))
	local blue = rgb(52, 66, 150)
	deco(block(parent, Vector3.new(2, 2.2, 0.9), cf * CFrame.new(0, 4.1, 0), blue, "Shirt", Enum.Material.Fabric))
	deco(block(parent, Vector3.new(4.4, 0.8, 0.8), cf * CFrame.new(0, 4.6, 0), blue, "Sleeves", Enum.Material.Fabric))
	deco(block(parent, Vector3.new(2.04, 0.2, 0.94), cf * CFrame.new(0, 4.4, 0), shade(blue, 0.6), "Plaid", Enum.Material.Fabric), true)
	deco(ball(parent, 1.6, cf * CFrame.new(0, 5.9, 0), rgb(224, 196, 120), "Head", Enum.Material.Fabric))
	deco(post(parent, 0.15, 1.6, cf * CFrame.new(0, 6.6, 0), rgb(196, 160, 80), "HatBrim"))
	deco(post(parent, 0.7, 0.75, cf * CFrame.new(0, 6.95, 0), rgb(196, 160, 80), "HatTop"))
end

-- The vegetable garden: a raised planter with cabbages and staked tomato plants, the scarecrow, a clothes line,
-- barrels and a little GARDEN sign. `at` = middle of the planter, its long side along X.
function LobbyKit.garden(parent: Instance, at: CFrame)
	local m = Instance.new("Model")
	m.Name = "Garden"
	local W, D = 16, 6
	for side = -1, 1, 2 do
		block(m, Vector3.new(W + 1, 1, 0.5), at * CFrame.new(0, 0.5, side * D / 2), WOOD, "Planter")
		block(m, Vector3.new(0.5, 1, D), at * CFrame.new(side * W / 2, 0.5, 0), WOOD, "Planter")
	end
	deco(block(m, Vector3.new(W - 0.4, 0.8, D - 0.4), at * CFrame.new(0, 0.45, 0), rgb(84, 56, 38), "Soil", Enum.Material.Ground))
	for i = 0, 3 do
		local x = -W / 2 + 2.5 + i * 3.6
		deco(ball(m, 1.6, at * CFrame.new(x, 1.3, 1.3), rgb(110, 176, 70), "Cabbage", Enum.Material.Grass))
		deco(block(m, Vector3.new(0.2, 3, 0.2), at * CFrame.new(x + 1.6, 2.4, -1.3), LIGHT_WOOD, "Stake", Enum.Material.Wood), true)
		deco(block(m, Vector3.new(1.2, 2.2, 1.2), at * CFrame.new(x + 1.6, 2.1, -1.3) * CFrame.Angles(0, 0.6, 0), rgb(70, 140, 60), "Plant", Enum.Material.Grass))
		for _, y in { 2.4, 1.6 } do
			deco(ball(m, 0.45, at * CFrame.new(x + 1.6 + 0.45, y, -1.3 - 0.5), rgb(236, 120, 40), "Tomato"), true)
		end
	end
	LobbyKit.scarecrow(m, at * CFrame.new(-W / 2 + 2, 0, -D / 2 - 3))
	LobbyKit.clothesline(m, at * CFrame.new(1, 0, -D / 2 - 7), 12)
	LobbyKit.plankSign(m, at * CFrame.new(W / 2 - 2, 2.6, D / 2 + 0.7) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-15), 0, 0), 3.6, 1.3, "GARDEN", { rgb(255, 246, 210), rgb(240, 210, 150) })
	deco(block(m, Vector3.new(0.25, 2.2, 0.25), at * CFrame.new(W / 2 - 2, 1.1, D / 2 + 0.85), DARK_WOOD, "SignPost", Enum.Material.Wood), true)
	LobbyKit.barrel(m, at * CFrame.new(W / 2 + 3, 0, 1))
	LobbyKit.barrel(m, at * CFrame.new(W / 2 + 3.4, 0, -2), 0.85)
	m.Parent = parent
	return m
end

-- Fallen leaves and a few flower clumps scattered over the grass in a box (x0..x1, z0..z1), skipping `skip`.
function LobbyKit.litter(parent: Instance, x0: number, x1: number, z0: number, z1: number, count: number, seed: number, skip: ((number, number) -> boolean)?)
	local rng = Random.new(seed)
	local colors = { rgb(236, 168, 48), rgb(226, 120, 36), rgb(246, 206, 70), rgb(200, 96, 40) }
	for _ = 1, count do
		local x, z = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
		local c = colors[rng:NextInteger(1, #colors)]
		local s = rng:NextNumber(0.5, 0.9)
		if skip and skip(x, z) then
			continue
		end
		deco(block(parent, Vector3.new(s, 0.06, s * 0.6), CFrame.new(x, 0.05, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), c, "Leaf", Enum.Material.SmoothPlastic), true)
	end
end

return LobbyKit
