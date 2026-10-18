-- Building helpers for the chunky, studded-brick look (bright plastic bricks, stepped cone trees, striped stalls).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)

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
	studs: boolean?, -- studded top (default true)
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
	p.TopSurface = if o.studs == false then Enum.SurfaceType.Smooth else Enum.SurfaceType.Studs
	p.BottomSurface = if o.studs == false then Enum.SurfaceType.Smooth else Enum.SurfaceType.Inlet
	p.Parent = o.parent
	return p
end

-- A plain studded brick.
function PropKit.brick(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string?): Part
	return PropKit.part({ size = size, cf = cf, color = color, parent = parent, name = name })
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

-- Stepped "cone" tree made of shrinking studded bricks.
function PropKit.coneTree(parent: Instance, pos: Vector3, scale: number, leaf: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "ConeTree"
	local leafColor = leaf or Color3.fromRGB(70, 180, 70)
	local trunkH = 3 * scale
	PropKit.brick(m, Vector3.new(1.6, trunkH, 1.6) * Vector3.new(scale, 1, scale), CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)), Color3.fromRGB(130, 85, 50), "Trunk")
	local y = trunkH
	local tiers = 4
	for i = 1, tiers do
		local w = (7 - i * 1.4) * scale
		local h = 1.6 * scale
		PropKit.brick(m, Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(0, y + h / 2, 0)), shade(leafColor, 1 - (i - 1) * 0.06), "Leaves")
		y += h
	end
	PropKit.brick(m, Vector3.new(0.9, 1.2, 0.9) * scale, CFrame.new(pos + Vector3.new(0, y + 0.6 * scale, 0)), shade(leafColor, 0.8), "Top")
	m.Parent = parent
	return m
end

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

return PropKit
