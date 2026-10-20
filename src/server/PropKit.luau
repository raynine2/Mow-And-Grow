-- Building helpers for the Chop A Forest look: smooth low-poly blocks, soft grass, chunky textured props.
-- (Studs are opt-in with `studs = true`.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Models = require(script.Parent.Models)

local PropKit = {}

local OUTLINE = Config.UI.outline

function PropKit.folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

type PartOpts = {
	size: Vector3,
	cf: CFrame,
	color: Color3,
	parent: Instance,
	name: string?,
	studs: boolean?, -- studded top (default false)
	collide: boolean?,
	anchored: boolean?,
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
}

function PropKit.part(o: PartOpts): Part
	local p = Instance.new("Part")
	p.Name = o.name or "Brick"
	p.Size = o.size
	p.CFrame = o.cf
	p.Color = o.color
	p.Anchored = if o.anchored == nil then true else o.anchored
	p.CanCollide = if o.collide == nil then true else o.collide
	p.Material = o.material or Enum.Material.Plastic
	p.Transparency = o.transparency or 0
	if o.shape then
		p.Shape = o.shape
	end
	p.TopSurface = if o.studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = o.parent
	return p
end

-- A plain block (optionally with a material).
function PropKit.brick(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?, material: Enum.Material?): Part
	return PropKit.part({ size = size, cf = cf, color = color, parent = parent, name = name, material = material })
end

PropKit.GRASS_GREEN = Color3.fromRGB(88, 158, 44)
PropKit.TRUNK = Color3.fromRGB(115, 62, 44)
PropKit.BIRCH = Color3.fromRGB(232, 228, 220)
PropKit.LEAVES = Color3.fromRGB(46, 112, 36)

-- Chop A Forest tree (matched to the official trailer): a thick, tall, square reddish-brown trunk with wood
-- grain, four slanted root buttresses, a couple of branches, and a big high canopy of leafy cubes.
-- `lite` builds a cheap far-away version (trunk + 3 leaf blocks) for the forest backdrop.
type TreeOpts = { leaf: Color3?, trunk: Color3?, birch: boolean?, lite: boolean?, bricks: boolean? } -- bricks: never the model (its leaves are a texture that can't be recoloured)
function PropKit.forestTree(parent: Instance, pos: Vector3, scale: number, opts: TreeOpts?): Model
	local o = opts or {}
	local rng = Random.new(math.floor(pos.X * 7.3 + pos.Z * 13.1))
	-- the Blender tree when it's uploaded (accent trees get their leaves recoloured)
	local modelName = if o.birch then "birch" elseif o.lite and Models.has("oak_small") and rng:NextNumber() < 0.3 then "oak_small" else "oak"
	local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local placed = if o.bricks then nil else Models.place(modelName, parent, CFrame.new(pos) * spin, scale * rng:NextNumber(0.92, 1.08))
	if placed then
		if o.leaf and o.leaf ~= PropKit.LEAVES then
			for _, part in placed:GetDescendants() do
				if part:IsA("BasePart") and part.Material == Enum.Material.Grass then
					part.Color = PropKit.shade(o.leaf, part.Color.G / PropKit.LEAVES.G)
				end
			end
		end
		return placed
	end
	local m = Instance.new("Model")
	m.Name = "Tree"
	local s = scale
	local tc = o.trunk or (if o.birch then PropKit.BIRCH else PropKit.shade(PropKit.TRUNK, rng:NextNumber(0.92, 1.08)))
	local lc = o.leaf or PropKit.LEAVES
	local w = 4 * s * rng:NextNumber(0.9, 1.1)
	local h = 24 * s * rng:NextNumber(0.88, 1.12)
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	local trunk = PropKit.brick(m, Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0), tc, "Trunk", Enum.Material.Wood)
	if o.lite then
		for i = 0, 2 do
			local size = 12 * s * rng:NextNumber(0.9, 1.15)
			local off = CFrame.Angles(0, i * 2.1, 0) * CFrame.new(3.5 * s, 0, 0)
			local leafPart = PropKit.brick(m, Vector3.new(size, size * 0.75, size), base * CFrame.new(0, h + 1 * s, 0) * off, PropKit.shade(lc, 0.9 + i * 0.06), "Leaves", Enum.Material.Grass)
			leafPart.CanCollide = false
		end
		m.Parent = parent
		return m
	end
	if o.birch then
		for i = 1, 4 do
			local y = h * (0.15 + i * 0.17) + rng:NextNumber(-1, 1)
			PropKit.brick(m, Vector3.new(w * 0.45, 0.5, w + 0.05), base * CFrame.new(rng:NextNumber(-0.6, 0.6), y, 0) * CFrame.Angles(0, (i % 2) * math.pi / 2, 0), Color3.fromRGB(40, 38, 40), "BirchMark", Enum.Material.SmoothPlastic)
		end
	end
	-- root buttresses: slanted slabs on each side, wide at the ground
	local rootColor = PropKit.shade(tc, 0.92)
	for i = 0, 3 do
		local side = base * CFrame.Angles(0, i * math.pi / 2 + rng:NextNumber(-0.25, 0.25), 0)
		local root = PropKit.brick(m, Vector3.new(w * 0.42, 3.4 * s, w * 0.95), side * CFrame.new(0, 1.2 * s, w * 0.62) * CFrame.Angles(math.rad(-38), 0, 0), rootColor, "Root", Enum.Material.Wood)
		root.CanCollide = false
		local toe = PropKit.brick(m, Vector3.new(w * 0.36, 0.9 * s, w * 0.7), side * CFrame.new(0, 0.4 * s, w * 1.05), rootColor, "RootToe", Enum.Material.Wood)
		toe.CanCollide = false
	end
	-- branches reaching up into the canopy
	for i = 0, 1 do
		local a = i * math.pi + rng:NextNumber(-0.5, 0.5)
		local br = PropKit.brick(m, Vector3.new(w * 0.32, 8 * s, w * 0.32), base * CFrame.Angles(0, a, 0) * CFrame.new(w * 0.9, h * 0.8, 0) * CFrame.Angles(0, 0, math.rad(-42)), tc, "Branch", Enum.Material.Wood)
		br.CanCollide = false
	end
	-- canopy: a centre block, a ring of blocks around it, and a few on top, all slightly turned
	local clumps = { { Vector3.new(0, 2, 0), 10 } }
	for i = 0, 5 do
		local a = i * math.pi / 3 + rng:NextNumber(-0.3, 0.3)
		table.insert(clumps, { Vector3.new(math.cos(a) * 5, rng:NextNumber(-1.2, 1.2), math.sin(a) * 5), rng:NextNumber(6, 7.5) })
	end
	for i = 0, 2 do
		local a = i * 2.1 + rng:NextNumber(-0.4, 0.4)
		table.insert(clumps, { Vector3.new(math.cos(a) * 2.5, rng:NextNumber(4.5, 6), math.sin(a) * 2.5), rng:NextNumber(5, 6.5) })
	end
	for i, c in clumps do
		local size = c[2] * s
		local cf = base * CFrame.new(c[1] * s + Vector3.new(0, h, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 1.5), rng:NextNumber(-0.2, 0.2))
		local shadeK = 0.86 + ((i * 37) % 5) * 0.05
		local leafPart = PropKit.brick(m, Vector3.new(size, size * 0.8, size), cf, PropKit.shade(lc, shadeK), "Leaves", Enum.Material.Grass)
		leafPart.CanCollide = false
	end
	m.PrimaryPart = trunk
	m.Parent = parent
	return m
end

-- A dense forest filling a rectangle (x0..x1, z0..z1) on a jittered grid. Trees closer than `detailDist` to
-- the line x = 0 are fully detailed; the rest use the cheap version. A few birches and coloured trees mixed in,
-- like the trailer.
type ForestOpts = { spacing: number?, seed: number?, scale: number?, leaf: Color3?, detailDist: number?, detailRadius: number?, accents: { Color3 }? }
function PropKit.forest(parent: Instance, x0: number, x1: number, z0: number, z1: number, opts: ForestOpts?)
	local o = opts or {}
	local spacing = o.spacing or 20
	local rng = Random.new(o.seed or 1)
	local accents = o.accents or { Color3.fromRGB(190, 45, 40), Color3.fromRGB(230, 140, 35), Color3.fromRGB(215, 120, 170) }
	local x = x0
	local row = 0
	while x <= x1 do
		local z = z0 + (if row % 2 == 0 then 0 else spacing / 2)
		while z <= z1 do
			local px = x + rng:NextNumber(-spacing * 0.3, spacing * 0.3)
			local pz = z + rng:NextNumber(-spacing * 0.3, spacing * 0.3)
			local roll = rng:NextNumber()
			local leaf = o.leaf
			if roll < 0.05 then
				leaf = accents[rng:NextInteger(1, #accents)]
			end
			local lite = if o.detailRadius then Vector2.new(px, pz).Magnitude > o.detailRadius else math.abs(px) > (o.detailDist or 70)
			PropKit.forestTree(parent, Vector3.new(px, 0, pz), (o.scale or 1) * rng:NextNumber(0.85, 1.15), { leaf = leaf, birch = roll > 0.88, lite = lite })
			z += spacing
		end
		x += spacing
		row += 1
	end
end

-- Stump left behind on cleared ground.
function PropKit.stump(parent: Instance, pos: Vector3, scale: number)
	local w = 4 * scale
	PropKit.brick(parent, Vector3.new(w, 1.6 * scale, w), CFrame.new(pos + Vector3.new(0, 0.8 * scale, 0)), PropKit.TRUNK, "Stump", Enum.Material.Wood)
	-- (rings on top)
	PropKit.brick(parent, Vector3.new(w - 0.3, 0.1, w - 0.3), CFrame.new(pos + Vector3.new(0, 1.6 * scale + 0.05, 0)), Color3.fromRGB(225, 185, 130), "Rings", Enum.Material.WoodPlanks)
end

-- Snowy low-poly mountain far in the background.
function PropKit.mountain(parent: Instance, pos: Vector3, scale: number)
	-- the Blender mountain is as big as the brick one at the same scale (60 across, ~62 high)
	local spin = CFrame.Angles(0, math.rad((pos.X * 13 + pos.Z * 7) % 360), 0)
	local placed = Models.place("mountain", parent, CFrame.new(pos) * spin, scale, true)
	if placed then
		for _, part in placed:GetDescendants() do
			if part:IsA("BasePart") then
				part.CastShadow = false
				part.CanQuery = false
			end
		end
		return
	end
	local m = Instance.new("Model")
	m.Name = "Mountain"
	local layers = 5
	for i = 0, layers - 1 do
		local w = (60 - i * 11) * scale
		local h = 14 * scale
		local snow = i >= layers - 2
		local p = PropKit.brick(m, Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(0, h / 2 + i * h * 0.85, 0)) * CFrame.Angles(0, math.rad(45 + i * 9), 0), if snow then Color3.fromRGB(240, 245, 250) else Color3.fromRGB(120, 130, 145), "Rock", if snow then Enum.Material.Snow else Enum.Material.Slate)
		p.CanCollide = false
		p.CastShadow = false
	end
	m.Parent = parent
end

function PropKit.cylinder(parent: Instance, radius: number, height: number, cf: CFrame, color: Color3): Part
	-- Roblox cylinders run along X; rotate so the flat faces point up.
	return PropKit.part({
		size = Vector3.new(height, radius * 2, radius * 2),
		cf = cf * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		parent = parent,
		shape = Enum.PartType.Cylinder,
		studs = false,
		name = "Cylinder",
	})
end

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
PropKit.shade = shade

-- Round-ish bush made of two bricks.
function PropKit.bush(parent: Instance, pos: Vector3, scale: number, color: Color3?)
	local c = color or Color3.fromRGB(60, 170, 60)
	PropKit.brick(parent, Vector3.new(4, 2.4, 4) * scale, CFrame.new(pos + Vector3.new(0, 1.2 * scale, 0)), c, "Bush")
	PropKit.brick(parent, Vector3.new(2.6, 1.4, 2.6) * scale, CFrame.new(pos + Vector3.new(0, 3.1 * scale, 0)), shade(c, 1.1), "Bush")
end

-- Big bubbly text label: on a part face (SurfaceGui) or floating (BillboardGui).
local function styleLabel(label: TextLabel, color: Color3)
	label.BackgroundTransparency = 1
	label.Font = Config.UI.font
	label.TextScaled = true
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.Parent = label
end

function PropKit.surfaceText(part: BasePart, text: string, color: Color3?, face: Enum.NormalId?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Text = text
	styleLabel(label, color or Color3.new(1, 1, 1))
	label.Parent = gui
	return label
end

function PropKit.billboard(adornee: Instance, text: string, color: Color3?, size: Vector2?, offset: Vector3?, maxDist: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	local s = size or Vector2.new(12, 3)
	gui.Size = UDim2.fromScale(s.X, s.Y)
	gui.StudsOffsetWorldSpace = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDist or 200
	gui.Adornee = if adornee:IsA("BasePart") or adornee:IsA("Model") or adornee:IsA("Attachment") then adornee :: any else nil
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	styleLabel(label, color or Color3.new(1, 1, 1))
	label.Parent = gui
	return label
end

-- A sign board with text on its front.
function PropKit.sign(parent: Instance, cf: CFrame, size: Vector3, text: string, bg: Color3, fg: Color3?): Part
	local board = PropKit.part({ size = size, cf = cf, color = bg, parent = parent, name = "Sign" })
	PropKit.brick(parent, Vector3.new(size.X + 0.8, 0.8, size.Z + 0.4), cf * CFrame.new(0, size.Y / 2 + 0.4, 0), shade(bg, 0.75), "SignTrim")
	PropKit.surfaceText(board, text, fg)
	return board
end

-- A proximity prompt the client uses to open a window (attribute "Window").
function PropKit.prompt(part: BasePart, actionText: string, objectText: string, window: string?, distance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	if window then
		p:SetAttribute("Window", window)
	end
	p.Parent = part
	return p
end

-- A market stall: studded counter, striped awning, title sign and a prompt that opens `window`.
function PropKit.stall(parent: Instance, cf: CFrame, title: string, color: Color3, window: string?, stripe: Color3?): Model
	local m = Instance.new("Model")
	m.Name = title
	local white = stripe or Color3.fromRGB(255, 255, 255)
	local counter = PropKit.brick(m, Vector3.new(12, 4, 5), cf * CFrame.new(0, 2, 0), color, "Counter")
	PropKit.brick(m, Vector3.new(12.6, 0.8, 5.6), cf * CFrame.new(0, 4.4, 0), shade(color, 0.8), "CounterTop")
	for _, x in { -5.5, 5.5 } do
		PropKit.brick(m, Vector3.new(0.8, 6, 0.8), cf * CFrame.new(x, 7.8, 1.8), Color3.fromRGB(240, 240, 240), "Post")
	end
	-- striped awning
	for i = 0, 5 do
		local c = if i % 2 == 0 then color else white
		PropKit.brick(m, Vector3.new(2.2, 0.8, 7), cf * CFrame.new(-5.5 + i * 2.2, 11.2, 0.6) * CFrame.Angles(math.rad(-12), 0, 0), c, "Awning")
	end
	local sign = PropKit.sign(m, cf * CFrame.new(0, 13.6, -0.2), Vector3.new(11, 2.6, 0.8), title, shade(color, 0.85))
	sign.Name = "TitleSign"
	PropKit.prompt(counter, "Open", title, window)
	m.PrimaryPart = counter
	m.Parent = parent
	return m
end

-- Flat round pad on the ground (party pads, sell rings).
function PropKit.pad(parent: Instance, pos: Vector3, radius: number, color: Color3, label: string?): Part
	local ring = PropKit.cylinder(parent, radius + 0.8, 0.5, CFrame.new(pos + Vector3.new(0, 0.25, 0)), shade(color, 0.7))
	ring.Name = "PadRing"
	ring.CanCollide = false
	local pad = PropKit.cylinder(parent, radius, 0.7, CFrame.new(pos + Vector3.new(0, 0.35, 0)), color)
	pad.Name = "Pad"
	pad.CanCollide = false
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.15
	if label then
		local holder = PropKit.part({ size = Vector3.new(1, 1, 1), cf = CFrame.new(pos + Vector3.new(0, 1, 0)), color = color, parent = parent, transparency = 1, collide = false, name = "PadLabel" })
		holder.CanQuery = false
		PropKit.billboard(holder, label, Color3.new(1, 1, 1), Vector2.new(10, 2.5), Vector3.new(0, 4, 0), 120)
	end
	return pad
end

-- A row of fence bricks from a to b (on the ground).
function PropKit.fence(parent: Instance, a: Vector3, b: Vector3, color: Color3?, height: number?)
	local c = color or Color3.fromRGB(255, 255, 255)
	local h = height or 3
	local dir = b - a
	local len = dir.Magnitude
	local cf = CFrame.lookAt(a + dir / 2, b) * CFrame.new(0, h / 2, 0)
	PropKit.brick(parent, Vector3.new(0.8, 0.8, len), cf * CFrame.new(0, h / 2 - 0.6, 0), c, "Rail")
	PropKit.brick(parent, Vector3.new(0.8, 0.8, len), cf * CFrame.new(0, -h / 2 + 1.0, 0), c, "Rail")
	local posts = math.max(2, math.floor(len / 6) + 1)
	for i = 0, posts - 1 do
		local t = i / (posts - 1)
		PropKit.brick(parent, Vector3.new(1, h, 1), CFrame.new(a:Lerp(b, t) + Vector3.new(0, h / 2, 0)), c, "Post")
	end
end

-- Invisible wall that keeps players inside the map.
function PropKit.wall(parent: Instance, size: Vector3, cf: CFrame): Part
	local w = PropKit.part({ size = size, cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, studs = false, name = "InvisibleWall" })
	w.CanQuery = false
	return w
end

-- Invisible solid box, for Blender models placed without mesh collisions (cabin walls, machine bodies).
-- `at` is the model's CFrame; centre/size are in the model's own studs (before `scale`).
function PropKit.collider(parent: Instance, at: CFrame, centre: Vector3, size: Vector3, scale: number?): Part
	local s = scale or 1
	local c = PropKit.wall(parent, size * s, at * CFrame.new(centre * s))
	c.Name = "Collider"
	return c
end

-- Text on the blank face of a Blender sign (the face looks toward the model's front, -Z). `centre` and `size`
-- (width, height) are in the model's own studs; the text sits a hair in front of the face.
function PropKit.facePanel(parent: Instance, at: CFrame, centre: Vector3, size: Vector2, text: string, color: Color3?, scale: number?): TextLabel
	local s = scale or 1
	local panel = PropKit.part({
		size = Vector3.new(size.X * s, size.Y * s, 0.05),
		cf = at * CFrame.new(centre * s + Vector3.new(0, 0, -0.04)),
		color = Color3.new(1, 1, 1),
		parent = parent,
		transparency = 1,
		collide = false,
		studs = false,
		name = "SignText",
	})
	panel.CanQuery = false
	local label = PropKit.surfaceText(panel, text, color)
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	return label
end

-- Blender log cabin (shops). The mesh has no collisions; these boxes (in the model's studs) make the walls
-- solid but keep the 5-wide door open. The room inside is x -11.9..11.9, z -2.5..9.5 (back wall's inner face
-- at z 9.5, side walls' at x +-11.9), floor top at 0.5; the porch runs to z -11.9.
local CABIN_WALLS = {
	{ Vector3.new(0, 0.25, -1), Vector3.new(26.8, 0.5, 21.6) }, -- floor and porch
	{ Vector3.new(0, 6, 10.2), Vector3.new(26.8, 12, 1.4) }, -- back
	{ Vector3.new(12.65, 6, 3.5), Vector3.new(1.5, 12, 14.8) }, -- sides
	{ Vector3.new(-12.65, 6, 3.5), Vector3.new(1.5, 12, 14.8) },
	{ Vector3.new(7.95, 6, -3.2), Vector3.new(10.9, 12, 1.4) }, -- front, both sides of the door
	{ Vector3.new(-7.95, 6, -3.2), Vector3.new(10.9, 12, 1.4) },
	{ Vector3.new(0, 10, -3.2), Vector3.new(5, 4.2, 1.4) }, -- over the door
}

-- Places a cabin at `at` (front = at.LookVector). Returns false if the model isn't uploaded.
function PropKit.cabin(parent: Instance, at: CFrame, scale: number): boolean
	if not Models.place("log_cabin", parent, at, scale, true) then
		return false
	end
	for _, c in CABIN_WALLS do
		PropKit.collider(parent, at, c[1], c[2], scale)
	end
	-- a warm lamp under the roof so the room isn't dark
	local lamp = PropKit.part({ size = Vector3.one, cf = at * CFrame.new(Vector3.new(0, 8, 3.5) * scale), color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = "CabinLamp" })
	lamp.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Range = 22 * scale
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = lamp
	return true
end

-- A plank sign hung on the front edge of a cabin's porch roof.
function PropKit.cabinSign(parent: Instance, at: CFrame, scale: number, text: string, color: Color3): Part
	local sign = PropKit.part({
		size = Vector3.new(14, 3, 0.6) * scale,
		cf = at * CFrame.new(Vector3.new(0, 10.4, -12.3) * scale),
		color = Color3.fromRGB(110, 70, 42),
		parent = parent,
		name = "CabinSign",
		material = Enum.Material.WoodPlanks,
	})
	PropKit.surfaceText(sign, text, color)
	return sign
end

-- A fence line from a to b made of the Blender fence model (8 studs a piece, front facing `facing`), or the
-- brick fence when the model isn't uploaded.
function PropKit.fenceRow(parent: Instance, a: Vector3, b: Vector3, facing: Vector3?)
	if not Models.has("fence") then
		PropKit.fence(parent, a, b, Color3.fromRGB(150, 105, 65), 3.6)
		return
	end
	local dir = b - a
	local n = math.max(1, math.floor(dir.Magnitude / 8 + 0.5))
	local along = dir.Unit
	local f = facing or along:Cross(Vector3.yAxis)
	for i = 0, n - 1 do
		local p = a + along * (dir.Magnitude * (i + 0.5) / n)
		-- the fence runs along its X axis, so facing f (sideways to the line) lays it along the line
		Models.place("fence", parent, CFrame.lookAt(p, p + f), dir.Magnitude / n / 8, true)
	end
end


-------------------------------------------------------------------------------------------------------------
-- forest edge and small props (the run map)
-------------------------------------------------------------------------------------------------------------
local PINE = Color3.fromRGB(38, 102, 58)

local function noTouch(p: BasePart, shadow: boolean?)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if shadow == false then
		p.CastShadow = false
	end
end

-- A blocky pine like the dark wall of pines round Chop A Forest's map: a trunk and stacked, turned leaf blocks
-- that get smaller toward the tip. `height` studs tall; `far` = no shadows (cheap, for the back rows).
function PropKit.pine(parent: Instance, pos: Vector3, height: number, far: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "Pine"
	local rng = Random.new(math.floor(pos.X * 3.7 + pos.Z * 11.3))
	local trunkH = height * 0.22
	local trunk = PropKit.brick(m, Vector3.new(height * 0.07, trunkH, height * 0.07), CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)), Color3.fromRGB(96, 62, 38), "Trunk", Enum.Material.Wood)
	noTouch(trunk, not far)
	local layers = 4
	local y = trunkH * 0.75
	local leaf = PropKit.shade(PINE, rng:NextNumber(0.85, 1.12))
	for i = 0, layers - 1 do
		local k = 1 - i / layers
		local w = height * (0.42 * k + 0.08)
		local h = (height - trunkH * 0.75) / layers * 1.15
		local layer = PropKit.brick(m, Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, math.rad(i * 37 + rng:NextNumber(0, 20)), 0), PropKit.shade(leaf, 0.92 + i * 0.05), "Leaves", Enum.Material.Grass)
		noTouch(layer, not far)
		y += h * 0.82
	end
	local tip = PropKit.brick(m, Vector3.new(height * 0.06, height * 0.1, height * 0.06), CFrame.new(pos + Vector3.new(0, y + height * 0.04, 0)), PropKit.shade(leaf, 1.15), "Tip", Enum.Material.Grass)
	noTouch(tip, not far)
	m.Parent = parent
	return m
end

-- A palm: a leaning, segmented trunk and a crown of drooping fronds.
function PropKit.palm(parent: Instance, pos: Vector3, height: number): Model
	local m = Instance.new("Model")
	m.Name = "Palm"
	local rng = Random.new(math.floor(pos.X * 5.1 + pos.Z * 2.3))
	local lean = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local cf = CFrame.new(pos) * lean
	local seg = 5
	local top = cf
	for i = 0, seg - 1 do
		local h = height / seg
		top = cf * CFrame.Angles(math.rad(i * 3.5), 0, 0) * CFrame.new(0, h * (i + 0.5), 0)
		local piece = PropKit.brick(m, Vector3.new(1.4 - i * 0.12, h * 1.05, 1.4 - i * 0.12), top, PropKit.shade(Color3.fromRGB(150, 108, 66), 0.9 + (i % 2) * 0.12), "Trunk", Enum.Material.Wood)
		noTouch(piece)
	end
	local crown = top * CFrame.new(0, height / seg / 2, 0)
	for i = 0, 6 do
		local f = PropKit.brick(m, Vector3.new(1.6, 0.3, height * 0.42), crown * CFrame.Angles(0, i * math.pi * 2 / 7, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -height * 0.18), PropKit.shade(Color3.fromRGB(56, 150, 52), 0.9 + (i % 3) * 0.06), "Frond", Enum.Material.Grass)
		noTouch(f)
	end
	m.Parent = parent
	return m
end

-- A little bunch of flowers (stems and coloured heads).
function PropKit.flowers(parent: Instance, pos: Vector3, color: Color3?)
	local rng = Random.new(math.floor(pos.X * 7 + pos.Z * 13))
	local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(170, 120, 255), Color3.fromRGB(255, 255, 255) }
	for _ = 1, rng:NextInteger(4, 7) do
		local p = pos + Vector3.new(rng:NextNumber(-1.4, 1.4), 0, rng:NextNumber(-1.4, 1.4))
		local h = rng:NextNumber(0.8, 1.5)
		noTouch(PropKit.brick(parent, Vector3.new(0.15, h, 0.15), CFrame.new(p + Vector3.new(0, h / 2, 0)), Color3.fromRGB(70, 150, 50), "Stem", Enum.Material.Grass), false)
		noTouch(PropKit.brick(parent, Vector3.new(0.5, 0.3, 0.5), CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), color or colors[rng:NextInteger(1, #colors)], "Petals", Enum.Material.SmoothPlastic), false)
	end
end

-- A red mushroom with white spots.
function PropKit.mushroom(parent: Instance, pos: Vector3, scale: number)
	local s = scale
	noTouch(PropKit.brick(parent, Vector3.new(0.6, 1.2, 0.6) * s, CFrame.new(pos + Vector3.new(0, 0.6 * s, 0)), Color3.fromRGB(240, 230, 210), "Stalk", Enum.Material.SmoothPlastic), false)
	noTouch(PropKit.brick(parent, Vector3.new(1.6, 0.6, 1.6) * s, CFrame.new(pos + Vector3.new(0, 1.4 * s, 0)), Color3.fromRGB(220, 50, 45), "Cap", Enum.Material.SmoothPlastic), false)
	for i = 0, 2 do
		local a = i * 2.1
		noTouch(PropKit.brick(parent, Vector3.new(0.3, 0.1, 0.3) * s, CFrame.new(pos + Vector3.new(math.cos(a) * 0.45 * s, 1.72 * s, math.sin(a) * 0.45 * s)), Color3.new(1, 1, 1), "Spot", Enum.Material.SmoothPlastic), false)
	end
end

-- A fallen, mossy trunk lying on the ground.
function PropKit.fallenLog(parent: Instance, pos: Vector3, length: number, yaw: number)
	local cf = CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, math.rad(90), 0)
	local log = PropKit.cylinder(parent, 0.95, length, cf * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(118, 78, 48))
	log.Material = Enum.Material.Wood
	log.Name = "FallenLog"
	local moss = PropKit.brick(parent, Vector3.new(length * 0.6, 0.3, 1.2), cf * CFrame.new(0, 0.85, 0), Color3.fromRGB(80, 140, 60), "Moss", Enum.Material.Grass)
	noTouch(moss)
end

return PropKit
