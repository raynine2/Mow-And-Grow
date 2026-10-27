-- Rarer = cooler (owner, 27 Oct: "make the rarer ones look cooler so people would want to get these more and would
-- want to wait for the cool ones"). Client-side and cosmetic only:
--   1. CLASS AURAS. Every class has its own aura, matching what the class is (player attribute "Class", set by
--      server/ClassPerks), and the rarer the class the bigger and cooler it gets (owner, 27 Oct):
--        Weed Puller        Common     dirt and torn-up weeds kicked up behind you as you walk
--        Gardener           Uncommon   leaves drifting round you, little flowers popping up where you step
--        Groundskeeper      Rare       a ring of clipped topiary cubes marching round you, a rake's sweep, twinkles
--        Lawn Baron         Rare       gold coins circling and glinting, a gold rim, a glitter trail
--        Hedge Reaper       Epic       a spectral scythe circling you, dark wisps, whirling leaves, claw marks
--        Mower Specialist   Epic       a saw blade spinning under you, clippings spraying, sparks, exhaust puffs
--        Grass Titan        Legendary  rock chunks orbiting, a stone crown, glowing cracks, dust, an outline
--        Ultimate Gardener  Legendary  a golden vine halo, a sunflower sigil, gold blooms and pollen, an outline
--        Lawn Legend        Mythic     crimson blades orbiting, a petal storm, a heartbeat, fire that grows
--                                      with your Hot Streak, an outline
--        Goat Man           Secret     starlight spiral horns, a galaxy, planets, grass streaming in to be eaten,
--                                      a rainbow ring, outline and trail
--      Timeline: it forms with a burst (spawn, equip), idles (everything turns, bobs, breathes), and the ground
--      pieces dim while you run (the trail takes over) and in boss fights (so the attack warnings stay readable).
--      Far-away auras are parked (no-lag rule), and everything is anchored, non-colliding and can't be hit by rays.
--   2. PETS. On top of client/PetFollow's own sparkles / ring / trail: Epic pets glow, Legendary ones get a gold
--      halo and light, Mythic ones motes circling them, Secret ones a colour-shifting halo and stardust.
--   3. RARE RESTOCKS. A banner drops in when a Legendary / Mythic / Secret class is in the stock, and a chip counts
--      down until it goes. Nothing says when the next one comes (owner, 27 Oct: no guarantees).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local FX = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local BFX = require(Shared:WaitForChild("BossFxIds")) :: { [string]: string }
local Sound = require(script.Parent.Sound)

local RarityFx = {}

local player = Players.LocalPlayer
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local VIEW = 140 -- auras further than this from the camera are parked
local WHITE = Color3.new(1, 1, 1)

local folder = Instance.new("Folder")
folder.Name = "RarityFx"
folder.Parent = workspace

-------------------------------------------------------------------------------------------------------------
-- building blocks
-------------------------------------------------------------------------------------------------------------
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function piece(parent: Instance, size: Vector3, color: Color3?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = size
	p.Material = Enum.Material.Neon
	p.Color = color or WHITE
	p.Transparency = transparency or 1
	p.Parent = parent
	return p
end

-- an invisible flat part with a texture on top (and underneath when `both`, for halos seen from below)
local function flat(parent: Instance, size: number, tex: string, color: Color3, transparency: number, both: boolean?): (Part, { Decal })
	local p = piece(parent, Vector3.new(size, 0.05, size))
	local list = {}
	for _, face in if both then { Enum.NormalId.Top, Enum.NormalId.Bottom } else { Enum.NormalId.Top } do
		local d = Instance.new("Decal")
		d.Face = face
		d.Texture = tex
		d.Color3 = color
		d.Transparency = transparency
		d.Parent = p
		table.insert(list, d)
	end
	return p, list
end

local function seq(...: Color3): ColorSequence
	local cs = { ... }
	if #cs == 1 then
		return ColorSequence.new(cs[1])
	end
	local kps = {}
	for i, c in cs do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#cs - 1), c))
	end
	return ColorSequence.new(kps)
end

-- Brightness (beams, trails, particles) lifts them over daylight and into the bloom; set safely
local function bright(inst: Instance, b: number)
	pcall(function()
		(inst :: any).Brightness = b
	end)
end

type EmitOpts = {
	tex: string,
	colors: ColorSequence,
	rate: number,
	life: { number },
	speed: { number },
	size: number,
	grow: boolean?, -- twinkle: 0 -> size -> 0 instead of size -> 0
	accel: Vector3?,
	drag: number?,
	spin: number?,
	dir: Enum.NormalId?,
	spread: number?,
	shape: Enum.ParticleEmitterShape?,
	light: number?,
	bright: number?,
}
local function emitter(parent: Instance, o: EmitOpts): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex
	e.Color = o.colors
	e.Rate = o.rate
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.Size = if o.grow
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, o.size), NumberSequenceKeypoint.new(1, 0) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * 0.15) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.spin or 0), o.spin or 0)
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(o.spread or 15, o.spread or 15)
	e.Shape = o.shape or Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.LightEmission = o.light or 0.6
	e.LightInfluence = 0
	bright(e, o.bright or 1.6)
	e.Parent = parent
	return e
end

local function trail(part: BasePart, a: Vector3, b: Vector3, colors: ColorSequence, life: number, light: number?): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = a
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = b
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = colors
	t.Lifetime = life
	t.MinLength = 0.05
	t.LightEmission = light or 0.5
	t.LightInfluence = 0
	t.FaceCamera = true
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	bright(t, 1.8)
	t.Parent = part
	return t
end

-- A glowing ring of camera-facing beams round `holder`'s centre, flat in its XZ plane: decals wash out in daylight,
-- bright beams don't. `dashed`: every fourth segment faint, so you can see it turn. Returns the beams and attachments.
local function beamRing(holder: BasePart, r: number, width: number, colors: ColorSequence, brightness: number, transparency: number, n: number?, dashed: boolean?): ({ Beam }, { Attachment })
	local count = n or 18
	local atts = {}
	for i = 0, count - 1 do
		local th = i / count * math.pi * 2
		local at = Instance.new("Attachment")
		at.Position = Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
		at.Parent = holder
		atts[i + 1] = at
	end
	local beams = {}
	for i = 1, count do
		local b = Instance.new("Beam")
		b.Attachment0 = atts[i]
		b.Attachment1 = atts[i % count + 1]
		b.FaceCamera = true
		b.Width0 = width
		b.Width1 = width
		b.Color = colors
		b.LightEmission = 0.3 -- (additive washes out to white on sunny ground; this keeps the colour)
		b.LightInfluence = 0
		local tr = if dashed and i % 4 == 0 then 0.75 else transparency
		b.Transparency = NumberSequence.new(tr)
		b:SetAttribute("Base", tr)
		b.Segments = 1
		bright(b, brightness * 0.35) -- (any brighter and the bloom bleaches the colour to white)
		b.Parent = holder
		beams[i] = b
	end
	return beams, atts
end

-- a bright ring that grows out from `pos` and fades (formation bursts, heartbeats); sizes are diameters
local function pulse(pos: Vector3, from: number, to: number, color: Color3, time: number, start: number?)
	local h = piece(folder, Vector3.new(0.2, 0.05, 0.2))
	h.CFrame = CFrame.new(pos + Vector3.new(0, 0.18, 0))
	local n = 22
	local s0 = start or 0.1
	local beams, atts = beamRing(h, from / 2, 0.4, ColorSequence.new(color), 3, s0, n, false)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / time)
		local r = (from + (to - from) * (1 - (1 - k) ^ 4)) / 2
		for i, at in atts do
			local th = (i - 1) / n * math.pi * 2
			at.Position = Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
		end
		local tr = NumberSequence.new(s0 + (1 - s0) * k)
		for _, b in beams do
			b.Transparency = tr
		end
		if k >= 1 then
			conn:Disconnect()
			h:Destroy()
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the five auras. Each builder fills `a` (its parts and how they move) and returns it; step() places everything.
-------------------------------------------------------------------------------------------------------------
-- Every frame a mover gets the frame `f`: t (clock), feet (ground point under the player, world-aligned),
-- head (the top of the head), root (HumanoidRootPart CFrame), yaw (the player's facing, yaw only), calm (1 standing,
-- 0 running), ground (how strong the ground pieces show: calm, dimmer in boss fights).
type Frame = { t: number, feet: Vector3, head: Vector3, headCF: CFrame, root: CFrame, yaw: CFrame, calm: number, ground: number, hue: number, player: Player? }
type Mover = { part: BasePart, at: (Frame) -> CFrame, body: boolean } -- body: hidden in your own first-person view
type Fade = { decal: Decal?, part: BasePart?, beam: Beam?, base: number } -- a ground piece that dims with calm/ground
type Aura = {
	model: Model,
	body: Model, -- the pieces round the body (orbiters, halos, particle boxes): left out of your own first-person view
	bodyHidden: boolean,
	movers: { Mover },
	fades: { Fade },
	emitters: { { e: ParticleEmitter, rate: number, run: boolean } }, -- run: only while you're moving
	hueDecals: { Decal }, -- Secret: decals that cycle through the rainbow
	hueBeams: { Beam }, -- Secret: beams that cycle through the rainbow
	hueOutline: Highlight?,
	light: PointLight?,
	lightBase: number,
	beat: number?, -- seconds between heartbeats (Mythic, Secret)
	nextBeat: number,
	color: Color3,
	rank: number,
	tick: ((Aura, Frame) -> ())?,
	lastGround: number,
	outline: Highlight?, -- its Adornee is set to the character when the aura goes on
}

local function newAura(rank: number, color: Color3): Aura
	local m = Instance.new("Model")
	m.Name = "Aura"
	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = m
	return {
		model = m,
		body = body,
		bodyHidden = false,
		movers = {},
		fades = {},
		emitters = {},
		hueDecals = {},
		hueBeams = {},
		hueOutline = nil,
		light = nil,
		lightBase = 0,
		beat = nil,
		nextBeat = 0,
		color = color,
		rank = rank,
		tick = nil,
		lastGround = -1,
		outline = nil,
	}
end

local function move(a: Aura, part: BasePart, at: (Frame) -> CFrame)
	table.insert(a.movers, { part = part, at = at, body = part:IsDescendantOf(a.body) })
end

local function fades(a: Aura, decals: { Decal }, ground: boolean)
	if not ground then
		return
	end
	for _, d in decals do
		table.insert(a.fades, { decal = d, part = nil, base = d.Transparency })
	end
end

local function addEmitter(a: Aura, e: ParticleEmitter, run: boolean?)
	table.insert(a.emitters, { e = e, rate = e.Rate, run = run == true })
	if run then
		e.Rate = 0
	end
end

-- a ground decal turning at `spin` rad/s (0 = still), breathing a little
local function groundDisc(a: Aura, size: number, tex: string, color: Color3, transparency: number, spin: number, lift: number?)
	local p, ds = flat(a.model, size, tex, color, transparency)
	fades(a, ds, true)
	local y = lift or 0.1
	move(a, p, function(f)
		return CFrame.new(f.feet + Vector3.new(0, y, 0)) * CFrame.Angles(0, f.t * spin, 0)
	end)
	return p, ds
end

-- a bright beam ring on the ground turning at `spin` rad/s (`dashed` shows the turn)
local function groundRing(a: Aura, r: number, width: number, color: Color3 | ColorSequence, brightness: number, transparency: number, spin: number, dashed: boolean?, lift: number?): (BasePart, { Beam })
	local h = piece(a.model, Vector3.new(0.2, 0.05, 0.2))
	local cs = if typeof(color) == "Color3" then ColorSequence.new(color :: Color3) else color :: ColorSequence
	local beams = beamRing(h, r, width, cs, brightness, transparency, if r > 3 then 24 else 18, dashed)
	for _, b in beams do
		table.insert(a.fades, { beam = b, base = b:GetAttribute("Base") :: number })
	end
	local y = lift or 0.15
	move(a, h, function(f)
		return CFrame.new(f.feet + Vector3.new(0, y, 0)) * CFrame.Angles(0, f.t * spin, 0)
	end)
	return h, beams
end

-- a glowing outline round the whole character (Legendary and up; left out of your own first-person view)
local function outline(a: Aura, color: Color3, transparency: number): Highlight
	local h = Instance.new("Highlight")
	h.Name = "Outline"
	h.FillTransparency = 0.92
	h.FillColor = color
	h.OutlineColor = color:Lerp(WHITE, 0.25)
	h.OutlineTransparency = transparency
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = a.body
	a.outline = h
	return h
end

-- an invisible box round the body that particles come out of
local function bodyBox(a: Aura, size: Vector3, yOff: number): Part
	local p = piece(a.body, size)
	move(a, p, function(f)
		return CFrame.new(f.root.Position + Vector3.new(0, yOff, 0))
	end)
	return p
end

-- an invisible flat plate at your feet facing where you face: carries the running trail
local function feetTrail(a: Aura, colors: ColorSequence)
	local p = piece(a.model, Vector3.new(0.2, 0.2, 0.2))
	trail(p, Vector3.new(-0.85, 0.15, 0), Vector3.new(0.85, 0.15, 0), colors, 0.55, 0.9)
	move(a, p, function(f)
		return CFrame.new(f.feet) * f.yaw
	end)
end

local function light(a: Aura, color: Color3, brightness: number, range: number)
	local parent = piece(a.model, Vector3.new(0.2, 0.2, 0.2))
	move(a, parent, function(f)
		return CFrame.new(f.root.Position)
	end)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	a.light = l
	a.lightBase = brightness
end

-------------------------------------------------------------------------------------------------------------
-- the ten class auras (owner, 27 Oct: "every class UNIQUE ... the vfx should be different for each but still match
-- the aesthetic of the class, becoming cooler and more cool the rarer the class is")
-------------------------------------------------------------------------------------------------------------
local DIRT = rgb(120, 82, 52)
local LEAF = rgb(96, 170, 60)
local GOLD = rgb(255, 196, 60)

-- a ring of small pieces round a point, turning (orbiters): `make(i)` builds piece i, `at(f, i, th)` places it
local function ringOf(a: Aura, n: number, make: (number) -> BasePart, at: (Frame, number, number) -> CFrame, speed: number)
	for i = 1, n do
		local p = make(i)
		local off = (i - 1) / n * math.pi * 2
		move(a, p, function(f)
			return at(f, i, off + f.t * speed)
		end)
	end
end

-- WEED PULLER (Common): dirt and torn-up weeds kicked up behind you as you walk; nothing at all standing still
local function buildWeedPuller(): Aura
	local a = newAura(RANK.Common, DIRT)
	local base = piece(a.model, Vector3.new(1.4, 0.2, 1.4))
	move(a, base, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.1, 0)) * f.yaw
	end)
	addEmitter(a, emitter(base, { tex = BFX.sand, colors = seq(rgb(150, 105, 64), DIRT), rate = 12, life = { 0.4, 0.7 }, speed = { 3, 6 }, size = 0.35, accel = Vector3.new(0, -30, 0), spread = 35, light = 0, bright = 1 }), true)
	addEmitter(a, emitter(base, { tex = BFX.strand, colors = seq(LEAF, rgb(70, 120, 40)), rate = 4, life = { 0.5, 0.8 }, speed = { 4, 7 }, size = 0.5, accel = Vector3.new(0, -25, 0), spin = 300, spread = 40, light = 0, bright = 1 }), true)
	return a
end

-- GARDENER (Uncommon): leaves drifting round you on a breeze, little flowers popping up where you step
local function buildGardener(): Aura
	local a = newAura(RANK.Uncommon, LEAF)
	groundDisc(a, 4.5, BFX.glow, LEAF, 0.72, 0)
	local body = bodyBox(a, Vector3.new(4, 3.5, 4), -0.3)
	addEmitter(a, emitter(body, { tex = BFX.leaf, colors = seq(rgb(150, 215, 90), LEAF), rate = 3, life = { 2, 3 }, speed = { 0.3, 0.8 }, size = 0.45, accel = Vector3.new(0, -0.5, 0), drag = 1, spin = 120, spread = 180, light = 0, bright = 1.2 }))
	local base = piece(a.model, Vector3.new(1.2, 0.2, 1.2))
	move(a, base, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.1, 0))
	end)
	addEmitter(a, emitter(base, { tex = BFX.petal, colors = seq(rgb(255, 150, 200), rgb(255, 230, 120), WHITE), rate = 6, life = { 0.6, 1 }, speed = { 1.5, 3 }, size = 0.4, accel = Vector3.new(0, -6, 0), spin = 200, spread = 50, light = 0.2 }), true)
	return a
end

-- GROUNDSKEEPER (Rare): everything neat. A ring of little clipped topiary cubes marching round you, a rake's sweep
-- going round the lawn under you, a twinkle of "all tidy"
local function buildGroundskeeper(): Aura
	local blue = Config.RARITY_COLORS.Rare
	local a = newAura(RANK.Rare, blue)
	groundDisc(a, 6, BFX.glow, LEAF, 0.6, 0)
	groundRing(a, 2.6, 0.18, seq(LEAF, blue, LEAF), 2.5, 0.1, 0.25, true)
	-- the topiary: eight neat little green cubes, in step
	ringOf(a, 8, function()
		local c = piece(a.model, Vector3.new(0.5, 0.5, 0.5), rgb(70, 150, 60), 0)
		c.Material = Enum.Material.Grass
		return c
	end, function(f, i, th)
		local hop = math.max(0, math.sin(f.t * 4 + i * 0.8)) * 0.25
		return CFrame.new(f.feet + Vector3.new(math.cos(th) * 2.6, 0.3 + hop, math.sin(th) * 2.6)) * CFrame.Angles(0, -th, 0)
	end, 0.4)
	-- the rake's sweep: a curved swoosh going round, fading behind
	local sweep = piece(a.model, Vector3.new(0.2, 0.05, 0.2))
	local s0 = Instance.new("Attachment")
	s0.Position = Vector3.new(1.2, 0, 0)
	s0.Parent = sweep
	local s1 = Instance.new("Attachment")
	s1.Position = Vector3.new(0, 0, 2.2)
	s1.Parent = sweep
	local bm = Instance.new("Beam")
	bm.Attachment0 = s0
	bm.Attachment1 = s1
	bm.CurveSize0 = 1.4
	bm.CurveSize1 = -0.4
	bm.Width0, bm.Width1 = 0.05, 0.6
	bm.FaceCamera = true
	bm.Segments = 12
	bm.Color = seq(WHITE, rgb(190, 240, 160))
	bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	bm.LightEmission = 0.4
	bright(bm, 1.2)
	bm.Parent = sweep
	move(a, sweep, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, -f.t * 2.2, 0)
	end)
	local body = bodyBox(a, Vector3.new(2.6, 4, 2.6), 0)
	addEmitter(a, emitter(body, { tex = FX.flare, colors = seq(WHITE, blue), rate = 2, life = { 0.35, 0.55 }, speed = { 0, 0 }, size = 0.9, grow = true, spin = 90 }))
	return a
end

-- LAWN BARON (Rare): money. Gold coins circling you, spinning and glinting, a gold rim on the ground, a trail of
-- glitter when you stroll
local function buildLawnBaron(): Aura
	local a = newAura(RANK.Rare, GOLD)
	groundDisc(a, 6, BFX.glow, GOLD, 0.6, 0)
	groundRing(a, 2.7, 0.2, seq(GOLD, rgb(255, 240, 170), GOLD), 2.5, 0.05, 0.3, true)
	ringOf(a, 6, function()
		local c = piece(a.body, Vector3.new(0.14, 0.8, 0.8), rgb(240, 180, 40), 0)
		c.Shape = Enum.PartType.Cylinder
		c.Material = Enum.Material.Metal
		c.Reflectance = 0.3
		return c
	end, function(f, i, th)
		local y = 0.4 + 0.35 * math.sin(f.t * 2 + i)
		return CFrame.new(f.root.Position + Vector3.new(math.cos(th) * 2.3, y, math.sin(th) * 2.3)) * CFrame.Angles(0, f.t * 5 + i, 0)
	end, 1.3)
	local body = bodyBox(a, Vector3.new(4.5, 3, 4.5), 0.4)
	addEmitter(a, emitter(body, { tex = FX.flare, colors = seq(WHITE, GOLD), rate = 4, life = { 0.3, 0.5 }, speed = { 0, 0 }, size = 0.7, grow = true, spin = 120 }))
	feetTrail(a, seq(rgb(255, 240, 170), GOLD))
	return a
end

-- HEDGE REAPER (Epic): a spectral scythe floating round you, blade first, dark wisps curling off the ground, torn
-- leaves whirling, claw marks turning on the lawn
local function buildHedgeReaper(): Aura
	local purple = Config.RARITY_COLORS.Epic
	local dark = rgb(60, 20, 90)
	local a = newAura(RANK.Epic, purple)
	groundDisc(a, 7, BFX.glow, purple, 0.55, 0)
	groundDisc(a, 5.2, FX.slash, rgb(200, 150, 255), 0.35, 0.6, 0.14)
	groundRing(a, 3.2, 0.24, seq(purple, dark, purple), 3, 0.05, -0.4, true)
	-- the scythe: a glowing haft and a curved blade (a bent beam), circling slowly behind your shoulder
	local scythe = piece(a.body, Vector3.new(0.22, 4.4, 0.22), rgb(120, 70, 180), 0)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 2.1, 0)
	top.Parent = scythe
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, 1.2, -2.6)
	tip.Parent = scythe
	local blade = Instance.new("Beam")
	blade.Attachment0 = top
	blade.Attachment1 = tip
	blade.CurveSize0 = 1.6
	blade.CurveSize1 = 0.4
	blade.Width0, blade.Width1 = 1.3, 0.05
	blade.FaceCamera = true
	blade.Segments = 14
	blade.Color = seq(rgb(230, 210, 255), purple)
	blade.Transparency = NumberSequence.new(0.05)
	blade.LightEmission = 0.5
	bright(blade, 1.6)
	blade.Parent = scythe
	trail(scythe, Vector3.new(0, 2, 0), Vector3.new(0, 1.2, -2.4), seq(purple, dark), 0.35)
	move(a, scythe, function(f)
		local th = f.t * 0.9
		local pos = f.root.Position + Vector3.new(math.cos(th) * 2.4, 0.6 + 0.25 * math.sin(f.t * 1.7), math.sin(th) * 2.4)
		return CFrame.lookAt(pos, pos + Vector3.new(-math.sin(th), 0, math.cos(th))) * CFrame.Angles(math.rad(-20), 0, math.rad(15))
	end)
	-- wisps and leaves
	local base = piece(a.model, Vector3.new(4, 0.2, 4))
	move(a, base, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.2, 0))
	end)
	addEmitter(a, emitter(base, { tex = BFX.smoke, colors = seq(purple, dark), rate = 4, life = { 1.2, 1.8 }, speed = { 0.8, 1.6 }, size = 1.4, accel = Vector3.new(0, 0.5, 0), drag = 0.5, spin = 40, light = 0.3, bright = 1 }))
	local body = bodyBox(a, Vector3.new(4.5, 4, 4.5), 0)
	addEmitter(a, emitter(body, { tex = BFX.leaf, colors = seq(rgb(80, 60, 110), rgb(60, 110, 50)), rate = 4, life = { 1.4, 2 }, speed = { 1.5, 3 }, size = 0.45, drag = 0.8, spin = 360, spread = 180, light = 0, bright = 1 }))
	feetTrail(a, seq(purple, dark))
	return a
end

-- MOWER SPECIALIST (Epic): a mower deck. A saw blade spinning flat under you with glowing teeth, clippings spraying
-- out behind when you move, sparks off the blade, exhaust puffs off your back
local function buildMowerSpecialist(): Aura
	local orange = rgb(255, 140, 40)
	local steel = rgb(190, 200, 210)
	local a = newAura(RANK.Epic, orange)
	groundDisc(a, 6.5, BFX.glow, orange, 0.65, 0)
	groundDisc(a, 4.6, FX.ring, steel, 0.15, 7)
	groundDisc(a, 1.6, FX.ring, steel, 0.3, 7)
	ringOf(a, 12, function()
		local t = Instance.new("WedgePart")
		t.Anchored = true
		t.CanCollide = false
		t.CanQuery = false
		t.CanTouch = false
		t.CastShadow = false
		t.Size = Vector3.new(0.08, 0.35, 0.55)
		t.Material = Enum.Material.Neon
		t.Color = orange
		t.Parent = a.model
		table.insert(a.fades, { part = t, base = 0 })
		return t
	end, function(f, _i, th)
		local pos = f.feet + Vector3.new(math.cos(th) * 2.35, 0.1, math.sin(th) * 2.35)
		return CFrame.lookAt(pos, pos + Vector3.new(-math.sin(th), 0, math.cos(th))) * CFrame.Angles(0, 0, math.rad(90))
	end, 7)
	-- clippings out the back, sparks off the rim, exhaust puffs
	local back = piece(a.model, Vector3.new(1.6, 0.3, 0.4))
	move(a, back, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.35, 0)) * f.yaw * CFrame.new(0, 0, 1.2)
	end)
	local clip = emitter(back, { tex = BFX.strand, colors = seq(rgb(140, 220, 90), LEAF), rate = 22, life = { 0.4, 0.7 }, speed = { 8, 14 }, size = 0.45, accel = Vector3.new(0, -25, 0), spin = 400, spread = 30, dir = Enum.NormalId.Back, light = 0, bright = 1 })
	addEmitter(a, clip, true)
	local rim = piece(a.model, Vector3.new(4.6, 0.2, 4.6))
	move(a, rim, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.2, 0))
	end)
	addEmitter(a, emitter(rim, { tex = FX.spark, colors = seq(rgb(255, 230, 150), orange), rate = 5, life = { 0.2, 0.4 }, speed = { 4, 8 }, size = 0.3, accel = Vector3.new(0, -30, 0), spread = 70 }))
	local pipe = piece(a.body, Vector3.new(0.3, 0.3, 0.3))
	move(a, pipe, function(f)
		return f.root * CFrame.new(0.6, 1.4, 0.7)
	end)
	addEmitter(a, emitter(pipe, { tex = BFX.smoke, colors = seq(rgb(120, 120, 125), rgb(70, 70, 75)), rate = 2.5, life = { 0.8, 1.3 }, speed = { 1.5, 2.5 }, size = 0.9, accel = Vector3.new(0, 2, 0), spread = 15, light = 0, bright = 1 }))
	feetTrail(a, seq(orange, rgb(90, 90, 95)))
	return a
end

-- GRASS TITAN (Legendary): the earth answers. Rock chunks orbiting you, a crown of floating stones, the ground
-- cracked and glowing under your feet, dust rising, a green-gold outline
local function buildGrassTitan(): Aura
	local moss = rgb(140, 220, 70)
	local glowc = rgb(200, 255, 120)
	local a = newAura(RANK.Legendary, moss)
	groundDisc(a, 8, BFX.glow, moss, 0.5, 0)
	groundRing(a, 3.8, 0.3, seq(DIRT, moss, DIRT), 3, 0.05, 0.12, true)
	-- the cracks: jagged glowing lines running out from your feet, flickering
	local rng = Random.new(7)
	for i = 1, 9 do
		local ang = (i - 1) / 9 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local len = rng:NextNumber(1.4, 2.6)
		local start = rng:NextNumber(0.8, 1.4)
		local kink = rng:NextNumber(-0.35, 0.35)
		local c = piece(a.model, Vector3.new(0.14, 0.05, len), glowc, 0.05)
		move(a, c, function(f)
			local th = ang + kink
			local mid = f.feet + Vector3.new(math.cos(th) * (start + len / 2), 0.08, math.sin(th) * (start + len / 2))
			return CFrame.lookAt(mid, f.feet + Vector3.new(0, 0.08, 0))
		end)
		table.insert(a.fades, { part = c, base = 0.05 })
	end
	-- six rock chunks orbiting at different heights, tumbling: two slabs of slate crossed into a rough lump, with a
	-- glowing green crystal stuck in each
	for i = 1, 6 do
		local sz = 0.55 + (i % 3) * 0.2
		local rock = piece(a.body, Vector3.new(sz, sz * 0.7, sz * 0.9), rgb(92, 86, 80), 0)
		rock.Material = Enum.Material.Slate
		local lump = piece(a.body, Vector3.new(sz * 0.75, sz * 0.75, sz * 0.6), rgb(104, 98, 90), 0)
		lump.Material = Enum.Material.Slate
		local gem = piece(a.body, Vector3.new(sz * 0.22, sz * 0.5, sz * 0.22), glowc, 0)
		local off = (i - 1) / 6 * math.pi * 2
		local function rockAt(f: Frame): CFrame
			local th = off + f.t * 0.55
			local y = -0.8 + (i % 3) * 0.9 + 0.3 * math.sin(f.t * 1.3 + i)
			return CFrame.new(f.root.Position + Vector3.new(math.cos(th) * 3.2, y, math.sin(th) * 3.2)) * CFrame.Angles(f.t * 0.8 + i, f.t * 0.6 + i * 2, i)
		end
		move(a, rock, rockAt)
		move(a, lump, function(f)
			return rockAt(f) * CFrame.new(sz * 0.12, sz * 0.1, 0) * CFrame.Angles(0.7, 0.5, 0.3)
		end)
		move(a, gem, function(f)
			return rockAt(f) * CFrame.new(0, sz * 0.38, 0) * CFrame.Angles(0.3, 0, 0.25)
		end)
	end
	-- the stone crown: six pebbles turning over your head
	ringOf(a, 6, function()
		local p = piece(a.body, Vector3.new(0.35, 0.3, 0.35), rgb(130, 125, 115), 0)
		p.Material = Enum.Material.Slate
		return p
	end, function(f, i, th)
		return CFrame.new(f.head + Vector3.new(math.cos(th) * 0.9, 0.7 + 0.08 * math.sin(f.t * 3 + i), math.sin(th) * 0.9)) * CFrame.Angles(f.t + i, 0, 0)
	end, 1)
	local crownGlow = flat(a.body, 2.6, BFX.glow, glowc, 0.55, true)
	move(a, crownGlow, function(f)
		return CFrame.new(f.head + Vector3.new(0, 0.7, 0))
	end)
	local base = piece(a.model, Vector3.new(4, 0.2, 4))
	move(a, base, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.2, 0))
	end)
	addEmitter(a, emitter(base, { tex = BFX.sand, colors = seq(rgb(170, 140, 100), DIRT), rate = 6, life = { 1, 1.6 }, speed = { 0.6, 1.4 }, size = 0.6, accel = Vector3.new(0, 0.6, 0), drag = 0.8, spin = 60, light = 0, bright = 1 }))
	addEmitter(a, emitter(base, { tex = FX.spark, colors = seq(glowc, moss), rate = 4, life = { 0.8, 1.3 }, speed = { 1.5, 3 }, size = 0.35, grow = true, spread = 20 }))
	light(a, moss, 1.3, 12)
	outline(a, moss, 0.3)
	feetTrail(a, seq(glowc, DIRT))
	return a
end

-- ULTIMATE GARDENER (Legendary): the golden gardener. A golden vine halo with leaves, a sunflower sigil turning under
-- you, gold flowers blooming up round your feet, golden pollen in the air, a gold outline
local function buildUltimateGardener(): Aura
	local hot = rgb(255, 236, 150)
	local a = newAura(RANK.Legendary, GOLD)
	groundDisc(a, 8, BFX.glow, GOLD, 0.45, 0)
	groundDisc(a, 6.6, FX.burst, hot, 0.7, 0.25)
	groundRing(a, 3.75, 0.3, seq(hot, GOLD, hot), 3.5, 0, -0.2, true)
	-- the sunflower: twelve gold petals laid round the sigil, opening and closing a little
	for i = 1, 12 do
		local p, ds = flat(a.model, 1.3, BFX.petal, GOLD, 0.05)
		fades(a, ds, true)
		local ang = (i - 1) / 12 * math.pi * 2
		move(a, p, function(f)
			local th = ang + f.t * 0.2
			local d = 2.3 + 0.15 * math.sin(f.t * 1.5)
			return CFrame.new(f.feet + Vector3.new(math.cos(th) * d, 0.12, math.sin(th) * d)) * CFrame.Angles(0, -th - math.pi / 2, 0)
		end)
	end
	-- the vine halo: a gold ring wearing six little leaves
	local halo = piece(a.body, Vector3.new(0.2, 0.05, 0.2))
	beamRing(halo, 0.95, 0.18, seq(hot, GOLD, hot), 5, 0, 20, false)
	local function haloAt(f: Frame): CFrame
		return CFrame.new(f.head + Vector3.new(0, 0.75 + 0.08 * math.sin(f.t * 2.2), 0)) * f.yaw * CFrame.Angles(math.rad(-14), f.t * 0.8, 0)
	end
	move(a, halo, haloAt)
	for i = 1, 6 do
		local leaf = flat(a.body, 0.55, BFX.leaf, rgb(150, 220, 80), 0, true)
		local ang = (i - 1) / 6 * math.pi * 2
		move(a, leaf, function(f)
			return haloAt(f) * CFrame.new(math.cos(ang) * 0.95, 0, math.sin(ang) * 0.95) * CFrame.Angles(0, -ang, math.rad(30))
		end)
	end
	local haloGlow = flat(a.body, 3, BFX.glow, GOLD, 0.45, true)
	move(a, haloGlow, haloAt)
	-- blooming at your feet, pollen in the air
	local base = piece(a.model, Vector3.new(3, 0.2, 3))
	move(a, base, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.2, 0))
	end)
	addEmitter(a, emitter(base, { tex = BFX.petal, colors = seq(WHITE, hot, GOLD), rate = 8, life = { 1, 1.6 }, speed = { 2, 4 }, size = 0.5, accel = Vector3.new(0, -2, 0), drag = 1, spin = 200, spread = 25 }))
	local body = bodyBox(a, Vector3.new(5, 4.5, 5), 0)
	addEmitter(a, emitter(body, { tex = BFX.dot, colors = seq(hot, GOLD), rate = 10, life = { 1.5, 2.5 }, speed = { 0.1, 0.4 }, size = 0.2, grow = true, spread = 180 }))
	light(a, GOLD, 1.4, 12)
	outline(a, GOLD, 0.3)
	feetTrail(a, seq(hot, GOLD))
	return a
end

-- LAWN LEGEND (Mythic): the champion. Three crimson blades orbiting you, a petal storm, a heartbeat that shakes the
-- ground, a crimson outline, and flames at your feet that grow with your Hot Streak
local function buildLawnLegend(): Aura
	local color = Config.RARITY_COLORS.Mythic
	local a = newAura(RANK.Mythic, color)
	local pink = rgb(255, 150, 190)
	local deep = rgb(170, 20, 60)
	groundDisc(a, 8.5, BFX.glow, color, 0.42, 0)
	groundDisc(a, 6.4, FX.burst, deep, 0.62, 0.15)
	groundRing(a, 3.9, 0.34, seq(pink, color, deep, color, pink), 3.5, 0, 0.3, true)
	groundRing(a, 2.6, 0.24, pink, 3.5, 0.1, -0.55, true)
	for i = 0, 2 do
		local b = piece(a.body, Vector3.new(0.26, 0.8, 2), color, 0)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = b
		trail(b, Vector3.new(0, 0.32, 0), Vector3.new(0, -0.32, 0), seq(pink, color, deep), 0.55)
		local off = i / 3 * math.pi * 2
		move(a, b, function(f)
			local th = f.t * 1.9 + off
			local pos = f.root.Position + Vector3.new(math.cos(th) * 2.6, -0.3 + 0.35 * math.sin(f.t * 2.4 + off), math.sin(th) * 2.6)
			return CFrame.lookAt(pos, pos + Vector3.new(-math.sin(th), 0, math.cos(th))) * CFrame.Angles(0, 0, math.rad(35))
		end)
	end
	local body = bodyBox(a, Vector3.new(5, 4, 5), 0)
	addEmitter(a, emitter(body, { tex = BFX.petal, colors = seq(pink, color, WHITE), rate = 8, life = { 2, 3 }, speed = { 0.4, 1.4 }, size = 0.45, accel = Vector3.new(0, -0.7, 0), drag = 1.2, spin = 160, spread = 180, light = 0.5, bright = 1.5 }))
	local base = piece(a.model, Vector3.new(2.4, 0.2, 2.4))
	move(a, base, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.3, 0))
	end)
	local burst = emitter(base, { tex = BFX.petal, colors = seq(pink, color), rate = 0, life = { 0.6, 1 }, speed = { 8, 14 }, size = 0.5, drag = 3, spin = 200, spread = 80, light = 0.5 })
	-- the streak's fire: a low flicker standing still, roaring up as the streak builds (player attribute ClassStreak)
	local fire = emitter(base, { tex = BFX.flame, colors = seq(rgb(255, 220, 120), rgb(255, 90, 40), deep), rate = 3, life = { 0.4, 0.8 }, speed = { 2, 4 }, size = 0.9, accel = Vector3.new(0, 4, 0), spread = 15, light = 1, bright = 1.5 })
	light(a, color, 1.5, 12)
	outline(a, color, 0.1)
	feetTrail(a, seq(pink, color, deep))
	a.beat = 2.8
	a.tick = function(self: Aura, f: Frame)
		local streak = if f.player then (f.player :: Player):GetAttribute("ClassStreak") else nil
		local k = math.clamp((tonumber(streak) or 0) / 60, 0, 1)
		fire.Rate = 3 + k * 30
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 + k * 1.2), NumberSequenceKeypoint.new(1, 0.1) })
		if f.t < self.nextBeat then
			return
		end
		self.nextBeat = f.t + (self.beat :: number)
		if f.ground > 0.3 then
			pulse(f.feet, 2, 12, color, 0.8, 0.05)
			burst:Emit(10)
		end
		local l = self.light
		if l then
			l.Brightness = self.lightBase * 2.4
			TweenService:Create(l, TweenInfo.new(0.5), { Brightness = self.lightBase }):Play()
		end
	end
	return a
end

-- GOAT MAN (Secret): the cosmic goat. Spiral horns of starlight curling off your head, a galaxy turning under you,
-- planets on tilted orbits, grass streaming in to be eaten, a rainbow ring, outline and trail
local COSMIC = { rgb(150, 90, 255), rgb(90, 220, 255), rgb(255, 110, 220), rgb(255, 220, 110) }
local function buildGoatMan(): Aura
	local violet, cyan, pink, gold = COSMIC[1], COSMIC[2], COSMIC[3], COSMIC[4]
	local a = newAura(RANK.Secret, violet)
	groundDisc(a, 9.5, BFX.glow, violet, 0.38, 0)
	groundDisc(a, 2.6, BFX.glow, WHITE, 0.1, 0, 0.14)
	local _, outer = groundRing(a, 4.3, 0.34, violet, 3.5, 0, 0.25, true)
	for _, b in outer do
		table.insert(a.hueBeams, b)
	end
	-- the galaxy: three spiral arms of camera-facing beams on a turning plate
	local plate = piece(a.model, Vector3.new(0.2, 0.05, 0.2))
	move(a, plate, function(f)
		return CFrame.new(f.feet + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, -f.t * 0.45, 0)
	end)
	local armColors = { seq(WHITE, cyan, violet), seq(WHITE, pink, violet), seq(WHITE, gold, pink) }
	for arm = 0, 2 do
		local prev: Attachment? = nil
		for k = 0, 6 do
			local r = 0.5 + k * 0.6
			local th = arm / 3 * math.pi * 2 + k * 0.42
			local at = Instance.new("Attachment")
			at.Position = Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
			at.Parent = plate
			if prev then
				local bm = Instance.new("Beam")
				bm.Attachment0 = prev
				bm.Attachment1 = at
				bm.FaceCamera = true
				bm.Width0 = 0.6 - (k - 1) * 0.075
				bm.Width1 = 0.6 - k * 0.075
				bm.Color = armColors[arm + 1]
				bm.LightEmission = 0.3
				bm.LightInfluence = 0
				local tr = 0.05 + k * 0.08
				bm.Transparency = NumberSequence.new(tr)
				bm.Segments = 2
				bright(bm, 1.6)
				bm.Parent = plate
				table.insert(a.fades, { beam = bm, base = tr })
			end
			prev = at
		end
	end
	-- the horns: two spirals of starlight balls curling back off the head, violet at the root to gold at the tip
	for side = -1, 1, 2 do
		for k = 0, 9 do
			local u = k / 9
			local size = 0.62 - u * 0.42
			local b = piece(a.body, Vector3.new(size, size, size), violet:Lerp(gold, u), 0)
			b.Shape = Enum.PartType.Ball
			move(a, b, function(f)
				-- a ram's horn: up and back off the crown, then curling round and down past the ear
				local th = u * math.pi * 1.6
				local rel = Vector3.new(side * (0.45 + 0.9 * math.sin(th) + u * 0.5), 0.35 + 0.8 * math.sin(th * 0.75) - u * 0.5, 0.25 + 1.0 * (1 - math.cos(th)))
				return f.headCF * CFrame.new(rel)
			end)
		end
		local tip = piece(a.body, Vector3.new(0.3, 0.3, 0.3))
		emitter(tip, { tex = FX.spark, colors = seq(WHITE, gold), rate = 6, life = { 0.3, 0.6 }, speed = { 0, 0.4 }, size = 0.5, grow = true, spread = 180 })
		move(a, tip, function(f)
			local th = math.pi * 1.6
			return f.headCF * CFrame.new(side * (0.45 + 0.9 * math.sin(th) + 0.5), 0.35 + 0.8 * math.sin(th * 0.75) - 0.5, 0.25 + 1.0 * (1 - math.cos(th)))
		end)
	end
	-- three planets on tilted orbits; the big one wears a ring
	local planets = {
		{ size = 0.85, color = cyan, r = 2.6, speed = 1.7, tilt = CFrame.Angles(math.rad(20), 0, math.rad(10)), y = 0.6 },
		{ size = 0.65, color = pink, r = 3.1, speed = -2.4, tilt = CFrame.Angles(math.rad(-25), 0, math.rad(-15)), y = 0 },
		{ size = 1.1, color = gold, r = 3.6, speed = 1.1, tilt = CFrame.Angles(0, 0, math.rad(28)), y = 0.3 },
	}
	for i, pl in planets do
		local b = piece(a.body, Vector3.new(pl.size, pl.size, pl.size), pl.color, 0)
		b.Shape = Enum.PartType.Ball
		trail(b, Vector3.new(0, pl.size * 0.4, 0), Vector3.new(0, -pl.size * 0.4, 0), seq(pl.color, violet), 0.6)
		emitter(b, { tex = FX.spark, colors = seq(WHITE, pl.color), rate = 5, life = { 0.3, 0.6 }, speed = { 0, 0.5 }, size = 0.45, grow = true, spread = 180, shape = Enum.ParticleEmitterShape.Sphere })
		local function at(f: Frame): CFrame
			local th = f.t * pl.speed + i * 2.1
			local rel = pl.tilt * Vector3.new(math.cos(th) * pl.r, 0, math.sin(th) * pl.r)
			return CFrame.new(f.root.Position + Vector3.new(0, pl.y, 0) + rel)
		end
		move(a, b, at)
		if i == 3 then
			local ringPart = piece(a.body, Vector3.new(0.2, 0.05, 0.2))
			beamRing(ringPart, 1.05, 0.14, seq(gold:Lerp(WHITE, 0.4)), 3, 0.1, 14, false)
			move(a, ringPart, function(f)
				return at(f) * CFrame.Angles(math.rad(25), f.t * 0.6, math.rad(15))
			end)
		end
	end
	-- a rainbow ring floating over the horns
	local h1 = piece(a.body, Vector3.new(0.2, 0.05, 0.2))
	for _, b in beamRing(h1, 1.25, 0.16, seq(violet), 5, 0, 20, true) do
		table.insert(a.hueBeams, b)
	end
	move(a, h1, function(f)
		return CFrame.new(f.head + Vector3.new(0, 1.15 + 0.1 * math.sin(f.t * 2), 0)) * CFrame.Angles(math.rad(-12), f.t, 0)
	end)
	-- grass streaming in from all round to be eaten, and stardust
	local body = bodyBox(a, Vector3.new(6, 5, 6), 0)
	local eat = emitter(body, { tex = BFX.strand, colors = seq(rgb(150, 230, 90), LEAF), rate = 8, life = { 0.6, 0.8 }, speed = { -6, -4 }, size = 0.4, spin = 300, spread = 180, shape = Enum.ParticleEmitterShape.Sphere, light = 0.2 })
	addEmitter(a, eat)
	addEmitter(a, emitter(body, { tex = FX.spark, colors = seq(cyan, violet, pink, gold, WHITE), rate = 12, life = { 1.4, 2.4 }, speed = { 0.1, 0.5 }, size = 0.42, grow = true, spin = 60, spread = 180 }))
	light(a, violet, 1.6, 13)
	a.hueOutline = outline(a, violet, 0.2)
	feetTrail(a, seq(pink, gold, cyan, violet))
	a.beat = 3.2
	a.tick = function(self: Aura, f: Frame)
		if f.t < self.nextBeat then
			return
		end
		self.nextBeat = f.t + (self.beat :: number)
		if f.ground > 0.3 then
			pulse(f.feet, 2, 14, Color3.fromHSV(f.hue, 0.8, 1), 1, 0.05)
		end
	end
	return a
end

local BUILD: { [string]: () -> Aura } = {
	WeedPuller = buildWeedPuller,
	Gardener = buildGardener,
	Groundskeeper = buildGroundskeeper,
	LawnBaron = buildLawnBaron,
	HedgeReaper = buildHedgeReaper,
	MowerSpecialist = buildMowerSpecialist,
	GrassTitan = buildGrassTitan,
	UltimateGardener = buildUltimateGardener,
	LawnLegend = buildLawnLegend,
	GoatMan = buildGoatMan,
}

-------------------------------------------------------------------------------------------------------------
-- auras on players
-------------------------------------------------------------------------------------------------------------
type Worn = { aura: Aura, char: Model, root: BasePart, hum: Humanoid, head: BasePart?, player: Player?, calm: number, parked: boolean }
local worn: { [any]: Worn } = {} -- by player (or by model for RarityFx.preview)

local function drop(p: any)
	local w = worn[p]
	if w then
		w.aura.model:Destroy()
		worn[p] = nil
	end
end


-- the formation: a ring bursting out, the aura's particles in a rush, a chime when it's near you
local function form(w: Worn)
	local a = w.aura
	local feet = w.root.Position - Vector3.new(0, 2.7, 0)
	pulse(feet, 1, 6 + a.rank * 1.6, a.color, 0.7 + a.rank * 0.08, 0)
	if a.rank >= RANK.Legendary then
		pulse(feet, 1, 4 + a.rank, WHITE, 0.5, 0.2)
	end
	for _, em in a.emitters do
		em.e:Emit(math.floor(em.rate * 1.5) + 4)
	end
	local cam = workspace.CurrentCamera
	if a.rank >= RANK.Rare and cam and (cam.CFrame.Position - w.root.Position).Magnitude < 60 then
		Sound.play(if a.rank >= RANK.Mythic then "reveal" else "rareChime", 0.05, if w.player == player then 0.8 else 0.4)
	end
end

-- put class `classId`'s aura on `char` (keyed by `key`: the player, or the model itself for a preview)
local function attach(key: any, char: Model, classId: any, p: Player?)
	drop(key)
	local build = if type(classId) == "string" then BUILD[classId] else nil
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not build or not char or not root or not hum then
		return
	end
	local aura = (build :: () -> Aura)()
	aura.model.Name = char.Name .. "_Aura"
	if aura.outline then
		aura.outline.Adornee = char
	end
	aura.model.Parent = folder
	local w: Worn = { aura = aura, char = char, root = root, hum = hum, head = char:FindFirstChild("Head") :: BasePart?, player = p, calm = 1, parked = false }
	worn[key] = w
	task.defer(form, w)
end

local function wear(p: Player)
	local char = p.Character
	if not char then
		drop(p)
		return
	end
	attach(p, char, p:GetAttribute("Class"), p)
end

-- Class `classId`'s aura on any rig (a shop preview, a showcase, a test dummy): returns a function that takes it off.
function RarityFx.preview(char: Model, classId: string): () -> ()
	attach(char, char, classId, nil)
	return function()
		drop(char)
	end
end

local function watchPlayer(p: Player)
	p:GetAttributeChangedSignal("Class"):Connect(function()
		wear(p)
	end)
	p.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		char:WaitForChild("Humanoid", 10)
		wear(p)
	end)
	if p.Character then
		task.spawn(wear, p)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(drop)
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end

-------------------------------------------------------------------------------------------------------------
-- pets: extra glow-ups on top of client/PetFollow's own effects
-------------------------------------------------------------------------------------------------------------
type PetGlow = { model: Model, root: BasePart, halo: BasePart?, hueBeams: { Beam } }
local petGlows: { PetGlow } = {}

local function petLookup(name: string)
	local id = string.match(name, "_([%w]+)$")
	return id and Config.pet(id) or nil
end

local function glowPet(m: Model)
	if m:GetAttribute("RarityFx") then
		return
	end
	local def = petLookup(m.Name)
	local root = m.PrimaryPart
	local rank = def and RANK[def.rarity] or 0
	if not def or not root or rank < RANK.Epic then
		return
	end
	m:SetAttribute("RarityFx", true)
	local color = if def.rarity == "Secret" then COSMIC[1] else Config.RARITY_COLORS[def.rarity] or WHITE
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = if rank >= RANK.Legendary then 1.1 else 0.6
	l.Range = if rank >= RANK.Legendary then 7 else 5
	l.Shadows = false
	l.Parent = root
	local g: PetGlow = { model = m, root = root, halo = nil, hueBeams = {} }
	if rank >= RANK.Legendary then
		local halo = piece(m, Vector3.new(0.2, 0.05, 0.2))
		halo.Name = "RarityHalo"
		local beams = beamRing(halo, 0.55, 0.12, seq(color:Lerp(WHITE, 0.35)), 4, 0, 14, false)
		g.halo = halo
		if def.rarity == "Secret" then
			g.hueBeams = beams
		end
	end
	if rank >= RANK.Mythic then
		emitter(root, { tex = FX.spark, colors = if def.rarity == "Secret" then seq(COSMIC[2], COSMIC[1], COSMIC[3], COSMIC[4]) else seq(WHITE, color), rate = if def.rarity == "Secret" then 7 else 4, life = { 0.8, 1.4 }, speed = { 0.2, 0.6 }, size = 0.28, grow = true, shape = Enum.ParticleEmitterShape.Sphere, spread = 180, spin = 90 })
	end
	table.insert(petGlows, g)
end

local function watchPets(f: Instance)
	f.ChildAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(glowPet, d)
		end
	end)
	for _, d in f:GetChildren() do
		if d:IsA("Model") then
			glowPet(d)
		end
	end
end
task.spawn(function()
	local f = workspace:WaitForChild("PetFollowers", 30)
	if f then
		watchPets(f)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- every frame
-------------------------------------------------------------------------------------------------------------
local parts: { BasePart } = {}
local cfs: { CFrame } = {}
local frame: Frame = { t = 0, feet = Vector3.zero, head = Vector3.zero, headCF = CFrame.identity, root = CFrame.identity, yaw = CFrame.identity, calm = 1, ground = 1, hue = 0, player = nil }

local function stepAura(w: Worn, dt: number, camPos: Vector3)
	local a = w.aura
	local root = w.root
	if not root.Parent or not w.char.Parent then
		return
	end
	local far = (root.Position - camPos).Magnitude > VIEW
	if far ~= w.parked then
		w.parked = far
		a.model.Parent = if far then nil else folder
	end
	if far then
		return
	end
	local hum = w.hum
	local v = root.AssemblyLinearVelocity
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 6
	w.calm += ((if moving then 0 else 1) - w.calm) * math.min(1, dt * 4)
	local hip = if hum.RigType == Enum.HumanoidRigType.R6 then 2 else hum.HipHeight
	local rcf = root.CFrame
	local look = rcf.LookVector
	frame.root = rcf
	-- (0.3 over the contact point: the village's paving and the terraces aren't flat, and lower pieces sank into them)
	frame.feet = rcf.Position - Vector3.new(0, root.Size.Y / 2 + hip - 0.3, 0)
	local head = w.head
	frame.head = if head and head.Parent then head.Position + Vector3.new(0, head.Size.Y / 2, 0) else rcf.Position + Vector3.new(0, 2.5, 0)
	frame.headCF = if head and head.Parent then head.CFrame else rcf * CFrame.new(0, 2, 0)
	frame.player = w.player
	frame.yaw = CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
	frame.calm = w.calm
	local fighting = w.player ~= nil and (w.player :: Player):GetAttribute("BossHP") ~= nil
	frame.ground = (0.25 + 0.75 * w.calm) * (if fighting then 0.35 else 1)
	-- your own aura in first person: the orbiters, halos and particle boxes would sit in your face, so only the
	-- ground pieces, the light and the trail show (everyone else sees all of it)
	local firstPerson = w.player == player and (camPos - frame.head).Magnitude < 2.5
	if firstPerson ~= a.bodyHidden then
		a.bodyHidden = firstPerson
		a.body.Parent = if firstPerson then nil else a.model
	end
	for _, m in a.movers do
		if not (m.body and firstPerson) then
			table.insert(parts, m.part)
			table.insert(cfs, m.at(frame))
		end
	end
	-- ground pieces dim while running / fighting (only written when it changes)
	if math.abs(frame.ground - a.lastGround) > 0.03 then
		a.lastGround = frame.ground
		local k = frame.ground
		for _, fd in a.fades do
			local tr = 1 - (1 - fd.base) * k
			if fd.part then
				fd.part.Transparency = tr
			elseif fd.decal then
				fd.decal.Transparency = tr
			elseif fd.beam then
				fd.beam.Transparency = NumberSequence.new(tr)
			end
		end
		for _, em in a.emitters do
			em.e.Rate = em.rate * (if fighting then 0.5 else 1) * (if em.run then math.clamp(1 - frame.calm, 0, 1) else 1)
		end
	end
	if #a.hueBeams > 0 or #a.hueDecals > 0 then
		local c = Color3.fromHSV(frame.hue, 0.8, 1)
		local c2 = Color3.fromHSV((frame.hue + 0.33) % 1, 0.8, 1)
		local cs = ColorSequence.new(c, c2)
		for _, b in a.hueBeams do
			b.Color = cs
		end
		for _, d in a.hueDecals do
			d.Color3 = c
		end
		if a.light then
			a.light.Color = c
		end
		if a.hueOutline then
			a.hueOutline.OutlineColor = c
			a.hueOutline.FillColor = c2
		end
	end
	if a.tick then
		a.tick(a, frame)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	frame.t = t
	frame.hue = (t * 0.12) % 1
	table.clear(parts)
	table.clear(cfs)
	for _, w in worn do
		stepAura(w, dt, camPos)
	end
	-- pet halos bob over their heads
	for i = #petGlows, 1, -1 do
		local g = petGlows[i]
		if not g.model.Parent then
			-- parked by PetFollow (Parent = nil, the root still in it) or destroyed (the root's Parent gone too)
			if g.root.Parent == nil then
				table.remove(petGlows, i)
			end
		elseif g.halo then
			table.insert(parts, g.halo)
			local top = g.root.Position + Vector3.new(0, g.root.Size.Y / 2 + 0.9 + 0.08 * math.sin(t * 2.4 + i), 0)
			table.insert(cfs, CFrame.new(top) * CFrame.Angles(math.rad(-10), t * 1.1, 0))
			if #g.hueBeams > 0 then
				local cs = ColorSequence.new(Color3.fromHSV(frame.hue, 0.8, 1))
				for _, b in g.hueBeams do
					b.Color = cs
				end
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- rare restocks: the banner and the countdown chip
-------------------------------------------------------------------------------------------------------------
local BIG = RANK.Legendary
local stockCache: { [number]: { string } } = {}
local function stockOf(window: number): { string }
	local s = stockCache[window]
	if not s then
		s = Config.classStock(window)
		stockCache[window] = s
	end
	return s
end

-- the best class in a window's stock, if it's Legendary or better
local function bestIn(window: number)
	local best, bestRank = nil, 0
	for _, id in stockOf(window) do
		local c = Config.class(id)
		local r = c and RANK[c.rarity] or 0
		if c and r >= BIG and r > bestRank then
			best, bestRank = c, r
		end
	end
	return best
end

local gui = Instance.new("ScreenGui")
gui.Name = "RareStock"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function rarityColor(rarity: string): Color3
	return if rarity == "Secret" then COSMIC[1] else Config.RARITY_COLORS[rarity] or WHITE
end

local function label(parent: Instance, text: string, size: number, color: Color3, pos: UDim2, sz: UDim2): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.Position = pos
	t.Size = sz
	t.AnchorPoint = Vector2.new(0.5, 0)
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = rgb(20, 12, 30)
	st.Parent = t
	t.Parent = parent
	return t
end

-- a moving gradient: gold shimmer for Legendary, crimson for Mythic, the rainbow for Secret
local function shimmer(parent: GuiObject, rarity: string): UIGradient
	local g = Instance.new("UIGradient")
	if rarity == "Secret" then
		g.Color = seq(COSMIC[2], COSMIC[1], COSMIC[3], COSMIC[4], COSMIC[2])
	else
		local c = rarityColor(rarity)
		g.Color = seq(c, c:Lerp(WHITE, 0.75), c)
	end
	g.Parent = parent
	return g
end

-- the chip: in stock (rarity colour, counting down) or the next one coming (quiet)
local chip = Instance.new("Frame")
chip.Name = "Chip"
chip.AnchorPoint = Vector2.new(0.5, 0)
chip.Position = UDim2.new(0.5, 0, 0, 6)
chip.Size = UDim2.fromOffset(500, 56) -- (owner, 27 Oct: twice as big, and it pulses: the most exciting thing on screen)
chip.BackgroundColor3 = rgb(22, 14, 36)
chip.BackgroundTransparency = 0.15
chip.Visible = false
chip.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = chip
end
local chipStroke = Instance.new("UIStroke")
chipStroke.Thickness = 3
chipStroke.Color = WHITE
chipStroke.Parent = chip
local chipGrad = Instance.new("UIGradient")
chipGrad.Parent = chipStroke
local chipText = label(chip, "", 32, WHITE, UDim2.fromScale(0.5, 0), UDim2.fromScale(1, 1))
chipText.TextYAlignment = Enum.TextYAlignment.Center
;(chipText:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
-- the pulse (a UIScale breathing 1 -> 1.08), sized down on narrow screens so it never covers a phone's top bar
do
	local pulse = Instance.new("UIScale")
	pulse.Name = "Pulse"
	pulse.Parent = chip
	local cam = workspace.CurrentCamera
	local base = if cam then math.clamp(cam.ViewportSize.X / 1100, 0.6, 1) else 1
	pulse.Scale = base
	TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = base * 1.08 }):Play()
end

local banner: Frame? = nil
-- The "IN STOCK" banner, on the game's own hanging wooden sign (ui_banner, like the first-run coach card) instead of
-- a dark neon pill (owner, 27 Oct: "make the UI fitting"): the class's picture on the left, "AT THE CLASSES STAND"
-- in yellow, the title in the rarity's shimmer, then the class, its gimmick and the time left.
local function showBanner(c, left: number)
	if banner then
		banner:Destroy()
	end
	local UI = require(script.Parent.UI)
	local Skin = require(script.Parent.Skin)
	local W, H = 540, 132
	local f = Instance.new("Frame")
	f.Name = "Banner"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Size = UDim2.fromOffset(W, H)
	f.Position = UDim2.new(0.5, 0, 0, -H - 30)
	f.BackgroundTransparency = 1
	f.Parent = gui
	banner = f
	do
		-- the same size on every screen as the rest of the interface (narrow phones get it smaller)
		local cam = workspace.CurrentCamera
		local sc = Instance.new("UIScale")
		sc.Scale = if cam then math.clamp(cam.ViewportSize.X / 1100, 0.6, 1) else 1
		sc.Parent = f
	end
	local _, face = Skin.frame(f, "ui_banner", Vector2.new(W, H), { name = "Sign" })
	local icon = if Config.ICONS and Config.ICONS["cc_" .. c.id] then "cc_" .. c.id else "card_" .. string.lower(c.rarity)
	local pic = UI.icon(face, icon, 76, UDim2.new(0, 6, 0.5, 0), Vector2.new(0, 0.5))
	Skin.popIn(pic, 0.25)
	UI.text(face, "AT THE CLASSES STAND", UDim2.fromOffset(240, 18), { pos = UDim2.fromOffset(92, 2), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 220, 90), stroke = 2 })
	local title = UI.text(face, string.upper(c.rarity) .. " CLASS IN STOCK!", UDim2.new(1, -98, 0, 34), { pos = UDim2.fromOffset(92, 20), align = Enum.TextXAlignment.Left, stroke = 3.5 })
	local tg = shimmer(title, c.rarity)
	local gim = Config.CLASS_GIMMICK and Config.CLASS_GIMMICK[c.id]
	local sub = c.name .. (if gim then "  ·  " .. gim.name else "") .. "  ·  gone in " .. Format.clock(left)
	local subText = UI.text(face, sub, UDim2.new(1, -100, 0, 24), { pos = UDim2.fromOffset(92, 56), align = Enum.TextXAlignment.Left, stroke = 2 })
	subText.TextScaled = true
	local subMax = Instance.new("UITextSizeConstraint")
	subMax.MaxTextSize = 21
	subMax.Parent = subText
	-- drop in with a bounce, shimmer for a while, then go back up
	TweenService:Create(f, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 40) }):Play()
	Sound.play(if RANK[c.rarity] >= RANK.Mythic then "reveal" else "rareChime", 0, 0.8)
	task.delay(0.15, function()
		Sound.play("whoosh", 0.05, 0.6)
	end)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not f.Parent then
			conn:Disconnect()
			return
		end
		tg.Offset = Vector2.new(((os.clock() - t0) * 0.6) % 2 - 1, 0)
	end)
	task.delay(7, function()
		if banner ~= f then
			return
		end
		TweenService:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -H - 30) }):Play()
		task.delay(0.45, function()
			f:Destroy()
			if banner == f then
				banner = nil
			end
		end)
	end)
end

local shownFor = -1
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		local window = math.floor(now / Config.STOCK_WINDOW)
		local left = Config.STOCK_WINDOW - (now % Config.STOCK_WINDOW)
		local c = bestIn(window)
		-- SETTINGS (client/Settings): Legendary / Mythic alerts can be switched off; a Secret always shows
		if c and c.rarity ~= "Secret" and player:GetAttribute("Alert" .. c.rarity) == false then
			c = nil
		end
		if c then
			if shownFor ~= window and left > 20 then
				shownFor = window
				showBanner(c, left)
			end
			local rc = rarityColor(c.rarity)
			-- (the chip is hidden for now: the owner, 27 Oct "remove this for now"; true brings it back)
			chip.Visible = false
			chipText.Text = "★ " .. string.upper(c.rarity) .. " IN STOCK  " .. Format.clock(left)
			chipText.TextColor3 = rc:Lerp(WHITE, 0.4)
			chipStroke.Color = WHITE
			if c.rarity == "Secret" then
				chipGrad.Color = seq(COSMIC[2], COSMIC[1], COSMIC[3], COSMIC[4])
			else
				chipGrad.Color = seq(rc, rc:Lerp(WHITE, 0.6), rc)
			end
			chipGrad.Offset = Vector2.new(((os.clock() * 0.5) % 2) - 1, 0)
			chip.BackgroundTransparency = 0.1
		else
			chip.Visible = false
		end
		task.wait(0.25)
	end
end)

return RarityFx
