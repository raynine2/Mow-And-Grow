-- The lobby's party pads, built like Chop A Forest's: a long wooden deck with four bays, each bay a glowing neon
-- frame on the planks with soft wisps rising off it (green while open, blue while a party is starting), a roofed
-- sign behind it with a painting of the lawn, one big word (SOLO / PARTY) and an OPEN / STARTING tag, and one short
-- line ("0/4", "starting in 3") floating above. Lanterns stand between the bays.
-- Also the glowing floor frames used in front of the lobby's stalls (LobbyPads.glow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)

local LobbyPads = {}

local OPEN = Color3.fromRGB(80, 255, 95)
local BUSY = Color3.fromRGB(40, 210, 255)
local CREAM = Color3.fromRGB(255, 240, 205)
local DARK_WOOD = Color3.fromRGB(92, 58, 34)
local WOOD = Color3.fromRGB(150, 98, 58)
local LIGHT_WOOD = Color3.fromRGB(196, 140, 86)
local ROOF = Color3.fromRGB(120, 66, 38)
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string, material: Enum.Material?): Part
	local p = PropKit.part({ size = size, cf = cf, color = color, parent = parent, name = name, material = material or Enum.Material.WoodPlanks })
	return p
end

local function deco(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-------------------------------------------------------------------------------------------------------------
-- glowing floor frame
-------------------------------------------------------------------------------------------------------------
export type Glow = { setColor: (Color3) -> (), parts: { BasePart } }

-- A neon frame `w` x `d` studs lying on the floor at `cf` (its top face at cf's height): bright strips, a soft
-- tinted fill, a light, and flame-like wisps rising along every edge.
-- The generated world's calm version: a raised studded brick border in the colour (no neon, light or flames).
local function calmFrame(parent: Instance, cf: CFrame, w: number, d: number, color: Color3): Glow
	local m = Instance.new("Model")
	m.Name = "PadFrame"
	local t = 0.8
	local strips: { BasePart } = {}
	for _, e in {
		{ Vector3.new(0, 0, d / 2 - t / 2), Vector3.new(w, 0, t) },
		{ Vector3.new(0, 0, -d / 2 + t / 2), Vector3.new(w, 0, t) },
		{ Vector3.new(w / 2 - t / 2, 0, 0), Vector3.new(t, 0, d - 2 * t) },
		{ Vector3.new(-w / 2 + t / 2, 0, 0), Vector3.new(t, 0, d - 2 * t) },
	} do
		local strip = block(m, Vector3.new(e[2].X, 0.4, e[2].Z), cf * CFrame.new(e[1] + Vector3.new(0, 0.2, 0)), PropKit.shade(color, 0.85), "Strip", Enum.Material.Plastic)
		strip.TopSurface = Enum.SurfaceType.Studs
		deco(strip)
		table.insert(strips, strip)
	end
	m.Parent = parent
	local function setColor(c: Color3)
		for _, p in strips do
			p.Color = PropKit.shade(c, 0.85)
		end
	end
	return { setColor = setColor, parts = table.clone(strips) }
end

-- The classes lodge's pad, a little patch of night sky in the paving: a midnight-blue studded border with gold
-- star studs at the corners, a deep indigo inside sprinkled with tiny glowing stars, and a small ringed planet.
-- Named "PadFrame" like the calm frames (the paving stones' tops are at 0.32, so it all sits just above them).
function LobbyPads.space(parent: Instance, cf: CFrame, w: number, d: number): Glow
	local m = Instance.new("Model")
	m.Name = "PadFrame"
	local NIGHT = Color3.fromRGB(34, 36, 92)
	local SKY = Color3.fromRGB(26, 20, 64)
	local GOLD = Color3.fromRGB(255, 214, 90)
	local t = 0.8
	local strips: { BasePart } = {}
	for _, e in {
		{ Vector3.new(0, 0, d / 2 - t / 2), Vector3.new(w, 0, t) },
		{ Vector3.new(0, 0, -d / 2 + t / 2), Vector3.new(w, 0, t) },
		{ Vector3.new(w / 2 - t / 2, 0, 0), Vector3.new(t, 0, d - 2 * t) },
		{ Vector3.new(-w / 2 + t / 2, 0, 0), Vector3.new(t, 0, d - 2 * t) },
	} do
		local strip = block(m, Vector3.new(e[2].X, 0.4, e[2].Z), cf * CFrame.new(e[1] + Vector3.new(0, 0.2, 0)), NIGHT, "Strip", Enum.Material.Plastic)
		strip.TopSurface = Enum.SurfaceType.Studs
		deco(strip)
		table.insert(strips, strip)
	end
	-- the night sky inside the border (just above the paving stones)
	local sky = block(m, Vector3.new(w - 2 * t, 0.06, d - 2 * t), cf * CFrame.new(0, 0.36, 0), SKY, "Sky", Enum.Material.SmoothPlastic)
	deco(sky)
	-- gold star studs on the corners (a square turned 45 degrees)
	for _, c in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local at = Vector3.new(c.X * (w / 2 - t / 2), 0.44, c.Z * (d / 2 - t / 2))
		local star = block(m, Vector3.new(0.75, 0.1, 0.75), cf * CFrame.new(at) * CFrame.Angles(0, math.rad(45), 0), GOLD, "CornerStar", Enum.Material.Neon)
		deco(star)
	end
	-- tiny stars scattered over the sky (the same pattern every time)
	local rng = Random.new(1969)
	local tints = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 240, 180), Color3.fromRGB(170, 220, 255) }
	for i = 1, math.floor(w * d / 7) do
		local x = rng:NextNumber(-(w / 2 - t - 0.4), w / 2 - t - 0.4)
		local z = rng:NextNumber(-(d / 2 - t - 0.4), d / 2 - t - 0.4)
		local s = if i % 5 == 0 then 0.32 else 0.18
		local star = block(m, Vector3.new(s, 0.04, s), cf * CFrame.new(x, 0.4, z) * CFrame.Angles(0, math.rad(45), 0), tints[i % #tints + 1], "Star", Enum.Material.Neon)
		deco(star)
	end
	-- a small ringed planet near one end
	local px = w / 2 - t - 1.6
	local planet = block(m, Vector3.new(0.05, 1.5, 1.5), cf * CFrame.new(px, 0.41, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 150, 90), "Planet", Enum.Material.SmoothPlastic)
	planet.Shape = Enum.PartType.Cylinder
	deco(planet)
	local ring = block(m, Vector3.new(2.6, 0.03, 0.22), cf * CFrame.new(px, 0.43, 0) * CFrame.Angles(0, math.rad(-25), 0), Color3.fromRGB(255, 220, 160), "Ring", Enum.Material.Neon)
	deco(ring)
	m.Parent = parent
	return { setColor = function(_c: Color3) end, parts = table.clone(strips) }
end

function LobbyPads.glow(parent: Instance, cf: CFrame, w: number, d: number, color: Color3): Glow
	if Config.WORLD_GEN then
		return calmFrame(parent, cf, w, d, color)
	end
	local m = Instance.new("Model")
	m.Name = "GlowFrame"
	local strips: { BasePart } = {}
	local halos: { BasePart } = {}
	local emitters: { ParticleEmitter } = {}
	local t = 0.55 -- strip width
	local edges = {
		{ Vector3.new(0, 0, d / 2 - t / 2), Vector3.new(w, 0, t) },
		{ Vector3.new(0, 0, -d / 2 + t / 2), Vector3.new(w, 0, t) },
		{ Vector3.new(w / 2 - t / 2, 0, 0), Vector3.new(t, 0, d - 2 * t) },
		{ Vector3.new(-w / 2 + t / 2, 0, 0), Vector3.new(t, 0, d - 2 * t) },
	}
	for _, e in edges do
		local strip = block(m, Vector3.new(e[2].X, 0.14, e[2].Z), cf * CFrame.new(e[1] + Vector3.new(0, 0.07, 0)), color, "Strip", Enum.Material.Neon)
		deco(strip)
		table.insert(strips, strip)
		-- a wider faint halo under the strip, so it glows into the planks
		local halo = block(m, Vector3.new(e[2].X + 1.2, 0.05, e[2].Z + 1.2), cf * CFrame.new(e[1] + Vector3.new(0, 0.03, 0)), color, "Halo", Enum.Material.Neon)
		halo.Transparency = 0.72
		deco(halo)
		table.insert(halos, halo)
		-- wisps rising off the edge
		local src = block(m, Vector3.new(e[2].X, 0.1, math.max(e[2].Z, 0.1)), cf * CFrame.new(e[1] + Vector3.new(0, 0.1, 0)), color, "WispSource", Enum.Material.SmoothPlastic)
		src.Transparency = 1
		deco(src)
		local fx = Instance.new("ParticleEmitter")
		fx.Name = "Wisps"
		fx.Texture = FIRE
		fx.Color = ColorSequence.new(color)
		fx.LightEmission = 1
		fx.LightInfluence = 0
		fx.EmissionDirection = Enum.NormalId.Top
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.4, 1.3), NumberSequenceKeypoint.new(1, 0) })
		fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1) })
		fx.Lifetime = NumberRange.new(0.55, 0.9)
		fx.Speed = NumberRange.new(1.6, 3)
		fx.SpreadAngle = Vector2.new(6, 6)
		fx.Rotation = NumberRange.new(-15, 15)
		fx.Rate = math.max(e[2].X, e[2].Z) * 2.2
		fx.Parent = src
		table.insert(emitters, fx)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Texture = SPARKLE
		sparks.Color = ColorSequence.new(color)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.Transparency = NumberSequence.new(0.2, 1)
		sparks.Lifetime = NumberRange.new(0.8, 1.4)
		sparks.Speed = NumberRange.new(1.5, 3.5)
		sparks.SpreadAngle = Vector2.new(20, 20)
		sparks.Rate = math.max(e[2].X, e[2].Z) * 0.35
		sparks.Parent = src
		table.insert(emitters, sparks)
	end
	-- the soft tinted fill and a light that washes the floor in the colour
	local fill = block(m, Vector3.new(w - 2 * t, 0.04, d - 2 * t), cf * CFrame.new(0, 0.02, 0), color, "Fill", Enum.Material.Neon)
	fill.Transparency = 0.9
	deco(fill)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.max(w, d) * 0.9
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = fill
	m.Parent = parent
	local function setColor(c: Color3)
		for _, p in strips do
			p.Color = c
		end
		for _, p in halos do
			p.Color = c
		end
		fill.Color = c
		light.Color = c
		for _, e in emitters do
			e.Color = ColorSequence.new(c)
		end
	end
	local all = table.clone(strips)
	return { setColor = setColor, parts = all }
end

-------------------------------------------------------------------------------------------------------------
-- the sign behind a bay
-------------------------------------------------------------------------------------------------------------
local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, stroke: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = Config.UI.font
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = stroke or 3
	s.Color = Color3.fromRGB(58, 34, 18)
	s.Parent = l
	l.Parent = parent
	return l
end

local function frame(parent: Instance, size: UDim2, pos: UDim2, color: Color3, radius: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

-- A little painting of the lawn: sky, a dark tree line, and a field full of grass clumps.
local function painting(parent: Instance)
	local art = frame(parent, UDim2.fromScale(0.88, 0.46), UDim2.fromScale(0.06, 0.05), Color3.fromRGB(150, 210, 255), 10)
	art.ClipsDescendants = true
	local sky = Instance.new("UIGradient")
	sky.Color = ColorSequence.new(Color3.fromRGB(120, 195, 255), Color3.fromRGB(225, 245, 255))
	sky.Rotation = 90
	sky.Parent = art
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(70, 42, 22)
	stroke.Parent = art
	-- tree line
	local rng = Random.new(3)
	for i = 0, 13 do
		local h = rng:NextNumber(0.18, 0.3)
		local tree = frame(art, UDim2.fromScale(0.11, h), UDim2.fromScale(i * 0.075 - 0.03, 0.42 - h * 0.5), Color3.fromRGB(38, 110 + (i % 3) * 14, 52), 40)
		tree.ZIndex = 2
	end
	-- the field
	local field = frame(art, UDim2.fromScale(1, 0.48), UDim2.fromScale(0, 0.52), Color3.fromRGB(110, 205, 70))
	field.ZIndex = 3
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(140, 225, 90), Color3.fromRGB(70, 170, 50))
	g.Rotation = 90
	g.Parent = field
	-- rows of clumps, smaller further back
	for row = 0, 3 do
		local y = 0.08 + row * 0.24
		local s = 0.05 + row * 0.03
		local n = 12 - row * 2
		for i = 0, n - 1 do
			local x = (i + (row % 2) * 0.5) / n
			local clump = frame(field, UDim2.fromScale(s, s * 2.2), UDim2.fromScale(x - s / 2, y - s * 0.6), Color3.fromRGB(60, 160 + row * 12, 50), 30)
			clump.ZIndex = 4
			local tip = frame(clump, UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.25, 0.05), Color3.fromRGB(150, 235, 90), 20)
			tip.ZIndex = 5
		end
	end
end

type SignHandles = { pill: TextLabel, pillBox: Frame, number: TextLabel }

-- The roofed sign at `at` (front = at.LookVector, standing on the deck): two posts, a gabled shingle roof, a
-- framed board with the painting and the texts.
-- where the ForgeGUI booth's chalkboard is, as fractions of the booth's box: width, height, centre height, and
-- how far in front of the middle its face is (measured in Studio on the model)
local BOOTH_FACE = { w = 0.62, h = 0.2, y = 0.25, z = 0.42 }

local function sign(parent: Instance, at: CFrame, title: string, sub: string, maxText: string): SignHandles
	local m = Instance.new("Model")
	m.Name = "PartySign"
	local W, H, Y = 11, 9.5, 6.4 -- board width, height, centre height
	local board: BasePart
	-- the ForgeGUI party booth (owner, 26 Oct: "remake the lobby boards with forgegui"), the face on its chalkboard
	local booth = Models.placeForge("partybooth", m, at * CFrame.new(0, 0, 0.5), { width = W + 1 }, false)
	if booth then
		booth.Name = "Booth"
		local _, bsize = booth:GetBoundingBox()
		local fw, fh = bsize.X * BOOTH_FACE.w, bsize.Y * BOOTH_FACE.h
		board = block(m, Vector3.new(fw, fh, 0.1), at * CFrame.new(0, bsize.Y * BOOTH_FACE.y, 0.5 - bsize.Z * BOOTH_FACE.z), DARK_WOOD, "Board", Enum.Material.SmoothPlastic)
		board.Transparency = 1
		board.CanCollide = false
	else
		-- posts and a lower crossbar
		for _, x in { -W / 2 - 0.3, W / 2 + 0.3 } do
			block(m, Vector3.new(0.9, Y + H / 2 + 1.6, 0.9), at * CFrame.new(x, (Y + H / 2 + 1.6) / 2, 0.5), DARK_WOOD, "Post", Enum.Material.Wood)
		end
		-- the board and its frame
		board = block(m, Vector3.new(W, H, 0.5), at * CFrame.new(0, Y, 0.5), DARK_WOOD, "Board", Enum.Material.WoodPlanks)
		for _, e in { { 0, H / 2, W + 0.6, 0.6 }, { 0, -H / 2, W + 0.6, 0.6 }, { W / 2, 0, 0.6, H }, { -W / 2, 0, 0.6, H } } do
			local trim = block(m, Vector3.new(e[3], e[4], 0.8), at * CFrame.new(e[1], Y + e[2], 0.45), LIGHT_WOOD, "Trim", Enum.Material.Wood)
			trim.CanCollide = false
		end
		-- gabled roof: two slanted shingle slabs and a ridge beam
		local roofY = Y + H / 2 + 1.4
		for side = -1, 1, 2 do
			local slab = block(m, Vector3.new(W / 2 + 1.6, 0.5, 4.2), at * CFrame.new(side * (W / 4 + 0.55), roofY + 0.9, 0.5) * CFrame.Angles(0, 0, math.rad(-side * 22)), ROOF, "Roof", Enum.Material.WoodPlanks)
			slab.CanCollide = false
		end
		block(m, Vector3.new(0.7, 0.7, 4.6), at * CFrame.new(0, roofY + 2.15, 0.5), DARK_WOOD, "Ridge", Enum.Material.Wood).CanCollide = false
		block(m, Vector3.new(W + 1.2, 1.3, 0.6), at * CFrame.new(0, roofY - 0.2, 0.4), WOOD, "Eave", Enum.Material.Wood).CanCollide = false
	end
	-- the face
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 26
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.LightInfluence = 0.6
	gui.Parent = board
	-- the board's front faces at.LookVector: Front of a part is its -Z, and the part's CFrame is `at` turned
	-- the same way, so the face looks where the sign looks
	local bg = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(245, 222, 170))
	local paper = Instance.new("UIGradient")
	paper.Color = ColorSequence.new(Color3.fromRGB(250, 232, 186), Color3.fromRGB(226, 194, 140))
	paper.Rotation = 90
	paper.Parent = bg
	painting(bg)
	-- one big word (SOLO / PARTY) and the state pill under it; nothing else, so it reads at a glance
	local number = label(bg, title, UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.53), CREAM, 4)
	local pillBox = frame(bg, UDim2.fromScale(0.6, 0.13), UDim2.fromScale(0.2, 0.81), OPEN, 16)
	local ps = Instance.new("UIStroke")
	ps.Thickness = 2
	ps.Color = Color3.fromRGB(30, 60, 40)
	ps.Parent = pillBox
	local pill = label(pillBox, "OPEN", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1), Color3.new(1, 1, 1), 1.5)
	m.Parent = parent
	return { pill = pill, pillBox = pillBox, number = number }
end

-- The one short floating line above a bay: "0/4", "Starting in 3"... (`bottom` is kept for the callers; it is the
-- same label).
local function statusTag(parent: Instance, pos: Vector3): (TextLabel, TextLabel)
	local holder = PropKit.part({ size = Vector3.one, cf = CFrame.new(pos), color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = "PadStatus" })
	holder.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 1.8)
	gui.LightInfluence = 0.6
	gui.MaxDistance = 140
	gui.Parent = holder
	local line = label(gui, "0/4", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), CREAM, 2.5)
	return line, line
end

-------------------------------------------------------------------------------------------------------------
-- the START A RUN board
-------------------------------------------------------------------------------------------------------------
-- A big plank board hanging from a beam between two tall log posts, high over the row (at = its middle, front
-- = at.LookVector): a gold title with a thick brown outline and a cream line under it.
function LobbyPads.startBoard(parent: Instance, at: CFrame, title: string, subtitle: string)
	local m = Instance.new("Model")
	m.Name = "StartBoard"
	local W, H = 40, 9.5
	local y = at.Position.Y
	-- posts from the ground up past the board, and the beam across them
	for _, x in { -W / 2 - 2, W / 2 + 2 } do
		local base = at * CFrame.new(x, -y, 1)
		local post = PropKit.cylinder(m, 1.15, y + H / 2 + 4, base * CFrame.new(0, (y + H / 2 + 4) / 2, 0), DARK_WOOD)
		post.Material = Enum.Material.Wood
		post.Name = "Post"
		local cap = PropKit.cylinder(m, 1.45, 0.8, base * CFrame.new(0, y + H / 2 + 4.2, 0), LIGHT_WOOD)
		cap.Material = Enum.Material.Wood
		cap.CanCollide = false
	end
	local beam = PropKit.cylinder(m, 0.9, W + 8, at * CFrame.new(0, H / 2 + 2.6, 1) * CFrame.Angles(0, 0, math.rad(90)), WOOD)
	beam.Material = Enum.Material.Wood
	beam.CanCollide = false
	-- chains
	for _, x in { -W / 3, W / 3 } do
		local chain = block(m, Vector3.new(0.3, 2.4, 0.3), at * CFrame.new(x, H / 2 + 1.3, 0.8), Color3.fromRGB(70, 70, 76), "Chain", Enum.Material.Metal)
		deco(chain)
	end
	-- the board with a lighter frame
	local board = block(m, Vector3.new(W, H, 0.8), at, Color3.fromRGB(104, 62, 34), "Board", Enum.Material.WoodPlanks)
	board.CanCollide = false
	for _, e in { { 0, H / 2, W + 1, 0.9 }, { 0, -H / 2, W + 1, 0.9 }, { W / 2, 0, 0.9, H }, { -W / 2, 0, 0.9, H } } do
		deco(block(m, Vector3.new(e[3], e[4], 1.1), at * CFrame.new(e[1], e[2], 0.05), Color3.fromRGB(150, 96, 54), "Trim", Enum.Material.Wood))
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 14 -- low enough that the title can grow past Roblox's 100 px TextScaled cap
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.LightInfluence = 0.6
	gui.Parent = board
	-- just the title, big and clean (the pads' signs say the rest)
	label(gui, title, UDim2.fromScale(0.88, 0.74), UDim2.fromScale(0.06, 0.13), PropKit.TITLE, 5)
	m.Parent = parent
end

-------------------------------------------------------------------------------------------------------------
-- the deck with four bays
-------------------------------------------------------------------------------------------------------------
export type PadDef = {
	kind: string,
	pos: Vector3,
	radius: number,
	label: TextLabel,
	title: string,
	show: (state: string, count: number, left: number?, who: string?, limit: number?) -> (),
}

-- Builds the row with its middle at `centre`, the bays facing `facing` (toward where players come from).
function LobbyPads.build(parent: Instance, centre: Vector3, facing: Vector3): { PadDef }
	local m = PropKit.folder("PartyPads", parent)
	local back = CFrame.lookAt(centre, centre + facing)
	local BAY, GAP, DEPTH, DECK_H = 13, 3, 13, 0.5
	local count = 4
	local span = count * BAY + (count + 1) * GAP
	-- the deck: planks, a darker skirt, and a log along the front edge
	local deck = block(m, Vector3.new(span, DECK_H, DEPTH + 2), back * CFrame.new(0, DECK_H / 2, 0), WOOD, "Deck", Enum.Material.WoodPlanks)
	deck.Name = "Deck"
	block(m, Vector3.new(span + 0.4, 0.35, DEPTH + 2.4), back * CFrame.new(0, 0.12, 0), DARK_WOOD, "Skirt", Enum.Material.Wood)
	local log = PropKit.cylinder(m, 0.55, span + 1, back * CFrame.new(0, 0.45, -(DEPTH + 2) / 2 - 0.3) * CFrame.Angles(0, 0, math.rad(90)), LIGHT_WOOD)
	log.Material = Enum.Material.Wood
	log.Name = "FrontLog"
	-- the back rail behind the signs
	PropKit.fenceRow(m, (back * CFrame.new(-span / 2, DECK_H, DEPTH / 2 + 4)).Position, (back * CFrame.new(span / 2, DECK_H, DEPTH / 2 + 4)).Position, -facing)

	local defs: { PadDef } = {}
	for i = 1, count do
		-- bay 1 (SOLO) on the left as players look at the row
		local x = span / 2 - GAP - BAY / 2 - (i - 1) * (BAY + GAP)
		local bay = back * CFrame.new(x, DECK_H, -0.6)
		local pos = bay.Position
		local solo = i == 1
		local kind = if solo then "solo" else "party"
		local maxN = if solo then 1 else Config.PARTY_MAX
		local glow = LobbyPads.glow(m, bay, BAY - 0.6, DEPTH - 2.6, OPEN)
		-- the guide arrow points new players at the first bay ("PadInfo1")
		local marker = PropKit.part({ size = Vector3.one, cf = CFrame.new(pos + Vector3.new(0, 1, 0)), color = OPEN, parent = m, transparency = 1, collide = false, name = "PadInfo" .. i })
		marker.CanQuery = false
		local handles = sign(m, back * CFrame.new(x, DECK_H, DEPTH / 2 + 1.3), if solo then "SOLO" else "PARTY", "", "")
		local top = statusTag(m, (back * CFrame.new(x, DECK_H + 17.5, DEPTH / 2 + 1.3)).Position)
		-- lanterns between the bays, at the front
		if i < count then
			local lx = x - BAY / 2 - GAP / 2
			local lp = (back * CFrame.new(lx, DECK_H, -DEPTH / 2 + 0.2)).Position
			if not Models.place("lantern_post", m, CFrame.lookAt(lp, lp + facing), 0.75, true) then
				block(m, Vector3.new(0.6, 4, 0.6), CFrame.new(lp + Vector3.new(0, 2, 0)), DARK_WOOD, "LanternPost", Enum.Material.Wood)
			end
			-- a low rail running back from the lantern, splitting the bays
			local a = (back * CFrame.new(lx, DECK_H, -DEPTH / 2 + 1.4)).Position
			local b = (back * CFrame.new(lx, DECK_H, DEPTH / 2 - 0.6)).Position
			PropKit.fenceRow(m, a, b, (back.RightVector))
		end
		local state = ""
		local def: PadDef = {
			kind = kind,
			pos = pos,
			radius = BAY / 2 - 0.4,
			label = top,
			title = if solo then "SOLO" else "PARTY",
			show = function(newState: string, n: number, left: number?, who: string?, limit: number?)
				-- "open": nobody on it; "creating": someone is picking the party settings; "starting": counting
				-- down; "teleporting". `limit` is the party size the host picked.
				local cap = limit or maxN
				if newState == "open" then
					top.Text = ("%d/%d"):format(n, cap)
				elseif newState == "creating" then
					top.Text = (who or "Someone") .. " is setting up"
				elseif newState == "starting" then
					top.Text = ("%d/%d  -  starting in %d"):format(n, cap, left or 0)
				else
					top.Text = "Teleporting..."
				end
				if newState ~= state then
					state = newState
					local busy = newState ~= "open"
					local c = if busy then BUSY else OPEN
					glow.setColor(c)
					handles.pillBox.BackgroundColor3 = c
					handles.pill.Text = if newState == "open" then "OPEN" elseif newState == "creating" then "SETTING UP" elseif newState == "starting" then "STARTING" else "GO!"
				end
			end,
		}
		def.show("open", 0, nil)
		table.insert(defs, def)
	end
	return defs
end

return LobbyPads
