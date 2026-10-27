-- The CLASSES stand as a black hole (the owner, 26 Oct: "an interactable black hole where you jump in, then you
-- have the menu"). Built by RunBuilder.classesKiosk in the run's camp when Config.CLASSES_BLACK_HOLE is on.
--
-- What's here (server, so Studio's Edit mode shows it too) - the client (client/BlackHole) makes it move:
--   * (off since 27 Oct, BlackHole.GROUND) a crater torn up by the hole: basalt slabs buckled in over a violet glow (some still carrying their turf),
--     an inner ring sinking into a swirling abyss, a light column up into the hole, crystal clusters with energy
--     streams curving up into it, glowing cracks over the ground, chunks of meadow floating round it
--   * the black hole floating over the well (its middle HOLE_Y studs up, out of reach unless you jump): a pitch
--     black event horizon, a camera-facing halo with the bright photon ring and the lensed glow of the disk behind
--     (like Interstellar's Gargantua), a tilted accretion disk of three layered spirals (violet outside, hot orange,
--     a white-gold inner ring), a jet up the axis, sparks falling in from all round, mist and twinkles in the
--     disk, bits of grass lifted off the well, a violet light and a low swirling hum
--   * "CLASSES / JUMP IN!" floating above, and a prompt in front for anyone who can't jump (phones, pads)
-- Jumping into it (or the prompt) pulls you in and opens the Classes window (the space class room); closing it
-- throws you back out the front. All of that is client/BlackHole; a parked player hides inside the horizon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)

local BlackHole = {}

-- sizes (studs, in the stand's own space: `at` is the floor in the middle, its -Z the front)
BlackHole.HOLE_Y = 10 -- the middle of the hole above the floor
BlackHole.RADIUS = 3.4 -- the event horizon (a parked avatar fits inside)
BlackHole.DISK = 12 -- the accretion disk's outer radius
BlackHole.TILT = 14 -- the disk's tilt (degrees, about the stand's X axis)
-- The whole stand is built at the sizes above, then scaled by this (the owner, 27 Oct: "a bit smaller"); the
-- client reads the scaled sizes from the Singularity's / chunks' attributes, so it follows.
BlackHole.SCALE = 0.75
-- The crater on the ground under it (slabs, abyss, light column, crystals, spires, cracks): off since the owner,
-- 27 Oct: "remove the ground bit". The hole, its disk and the floating chunks stay.
BlackHole.GROUND = false

local TEX = {
	glow = "rbxassetid://125552447014366",
	ringThin = "rbxassetid://115339930898563",
	ring = "rbxassetid://12403112662",
	spiral = "rbxassetid://8210105100",
	spark = "rbxassetid://83908233620100",
	star = "rbxassetid://116900531496449",
	rune = "rbxassetid://77040958169773",
	noise = "rbxassetid://108571432956915",
}
BlackHole.TEX = TEX


local function ghost(parent: Instance, name: string, size: Vector3, cf: CFrame, shape: Enum.PartType?): Part
	local p = PropKit.part({ size = size, cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = name, shape = shape })
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function image(parent: Instance, name: string, tex: string, scale: number, color: Color3, transparency: number, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = tex
	i.ImageColor3 = color
	i.ImageTransparency = transparency
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	i.Size = UDim2.fromScale(scale, scale)
	i.ZIndex = z
	i.Parent = parent
	return i
end

local function seq(...): ColorSequence
	local args = { ... }
	local keys = {}
	for i = 1, #args, 2 do
		table.insert(keys, ColorSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return ColorSequence.new(keys)
end

local function nseq(...): NumberSequence
	local args = { ... }
	local keys = {}
	for i = 1, #args, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- the ground under it: a crater torn up by the hole. Basalt slabs buckled in towards the middle over a violet
-- glow (the light shows through the gaps), some still carrying their turf; an inner ring of slabs sinking into a
-- swirling abyss; crystal clusters on the rim with energy streams curving up into the hole; a soft light column
-- from the abyss to the hole; glowing cracks running out over the ground; chunks of meadow floating round it
-- (client/BlackHole orbits them and sends gravity pulses in over the ground).
local BASALT = { Color3.fromRGB(46, 43, 52), Color3.fromRGB(57, 53, 63), Color3.fromRGB(38, 36, 44), Color3.fromRGB(63, 58, 68) } -- (charcoal with a hint of violet: the glow does the colour)
local TURF = Color3.fromRGB(88, 158, 44)
local DIRT = Color3.fromRGB(116, 82, 52)
local ROOTS = Color3.fromRGB(92, 72, 58)
local CRYSTAL = { Color3.fromRGB(170, 120, 255), Color3.fromRGB(110, 220, 255), Color3.fromRGB(255, 140, 220) }

local function block(k: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = PropKit.part({ size = size, cf = cf, color = color, parent = k, name = name, material = material, collide = collide == true })
	p.CastShadow = false
	if not collide then
		p.CanQuery = false
		p.CanTouch = false
	end
	return p
end

-- a ring of slabs round the middle, each tipped down towards it (`tip` degrees), turf on some
local function slabRing(k: Instance, at: CFrame, rng: Random, count: number, radius: number, size: Vector3, tip: NumberRange, lift: number, turf: number)
	for i = 1, count do
		local a = (i + rng:NextNumber(-0.25, 0.25)) / count * math.pi * 2
		local r = radius + rng:NextNumber(-0.35, 0.35)
		local s = size * Vector3.new(rng:NextNumber(0.9, 1.15), rng:NextNumber(0.85, 1.2), rng:NextNumber(0.9, 1.1))
		local pos = at * Vector3.new(math.cos(a) * r, lift + rng:NextNumber(0, 0.25), math.sin(a) * r)
		local face = CFrame.lookAt(pos, Vector3.new(at.X, pos.Y, at.Z))
		local cf = face * CFrame.Angles(-math.rad(rng:NextNumber(tip.Min, tip.Max)), 0, math.rad(rng:NextNumber(-6, 6)))
		local slab = block(k, "Slab", s, cf, BASALT[rng:NextInteger(1, #BASALT)], Enum.Material.Basalt, true)
		slab.TopSurface = Enum.SurfaceType.Studs
		if rng:NextNumber() < turf then
			local t = block(k, "Turf", Vector3.new(s.X * 0.92, 0.3, s.Z * rng:NextNumber(0.5, 0.8)), cf * CFrame.new(0, s.Y / 2 + 0.14, s.Z * 0.12), TURF, Enum.Material.Grass)
			t.TopSurface = Enum.SurfaceType.Studs
		end
	end
end

-- the ground part: the crater of slabs, the abyss and its swirl, the light column, crystals, spires and cracks
local function ground(k: Instance, at: CFrame, rng: Random)
	-- the glow under everything (shows between the slabs) and the abyss in the middle
	local glow = PropKit.cylinder(k, 7.6, 0.1, at * CFrame.new(0, 0.08, 0), Color3.fromRGB(120, 70, 255))
	glow.Name = "UnderGlow"
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	local abyss = PropKit.cylinder(k, 4.1, 0.14, at * CFrame.new(0, 0.12, 0), Color3.new(0, 0, 0))
	abyss.Name = "Abyss"
	abyss.Material = Enum.Material.Neon
	local floorPad = PropKit.part({ size = Vector3.new(8, 0.3, 8), cf = at * CFrame.new(0, 0.05, 0), color = Color3.new(0, 0, 0), parent = k, transparency = 1, name = "AbyssFloor" })
	floorPad.CanQuery = false
	-- the slabs: the outer ring tipped in a little (some with turf still on), the inner ring sinking steeply
	slabRing(k, at, rng, 15, 6.4, Vector3.new(3.1, 1.5, 2.7), NumberRange.new(12, 28), 0.4, 0.6)
	slabRing(k, at, rng, 11, 4.55, Vector3.new(2.3, 0.9, 1.9), NumberRange.new(26, 36), 0.05, 0)
	-- the swirl in the abyss (client/BlackHole turns its layers)
	local well = ghost(k, "Well", Vector3.new(8.6, 0.05, 8.6), at * CFrame.new(0, 0.21, 0))
	local sg = Instance.new("SurfaceGui")
	sg.Name = "WellGui"
	sg.Face = Enum.NormalId.Top
	sg.LightInfluence = 0
	sg.Brightness = 2.6
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = well
	image(sg, "Glow", TEX.glow, 0.9, Color3.fromRGB(90, 40, 220), 0.3, 1)
	image(sg, "Vortex", TEX.spiral, 0.95, Color3.fromRGB(150, 90, 255), 0.05, 2)
	image(sg, "Vortex2", TEX.spiral, 0.6, Color3.fromRGB(120, 230, 255), 0.25, 3)
	image(sg, "Rune", TEX.rune, 1, Color3.fromRGB(200, 170, 255), 0.35, 4)
	image(sg, "Ring", TEX.ringThin, 0.34, Color3.fromRGB(255, 240, 255), 0.1, 5)
	local up = Instance.new("PointLight")
	up.Name = "Uplight"
	up.Color = Color3.fromRGB(140, 90, 255)
	up.Brightness = 1
	up.Range = 12
	up.Shadows = false
	up.Parent = well
	-- motes lifted out of the abyss, and grit off the rim
	emitter(well, "Lift", {
		Texture = TEX.star,
		Color = seq(0, Color3.fromRGB(150, 230, 110), 0.5, Color3.fromRGB(200, 170, 255), 1, Color3.new(1, 1, 1)),
		Size = nseq(0, 0.3, 1, 0.08),
		Transparency = nseq(0, 1, 0.15, 0.15, 0.85, 0.3, 1, 1),
		Lifetime = NumberRange.new(1.6, 2.1),
		Rate = 16,
		Speed = NumberRange.new(2.5, 3.5),
		Acceleration = Vector3.new(0, 1.6, 0),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		LightEmission = 0.7,
	})
	local rim = ghost(k, "Rim", Vector3.new(16, 0.1, 16), at * CFrame.new(0, 1.2, 0))
	emitter(rim, "Grit", {
		Color = seq(0, Color3.fromRGB(70, 60, 95), 1, Color3.fromRGB(110, 90, 150)),
		Size = nseq(0, 0.22, 1, 0.1),
		Transparency = nseq(0, 1, 0.1, 0, 0.8, 0, 1, 1),
		Lifetime = NumberRange.new(1.8, 2.6),
		Rate = 7,
		Speed = NumberRange.new(1.5, 3),
		Acceleration = Vector3.new(0, 2.2, 0),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		LightInfluence = 1,
	})
	-- the light column from the abyss up into the hole
	local base = Instance.new("Attachment")
	base.Name = "ColumnBase"
	base.Position = Vector3.new(0, 0.3, 0)
	base.Parent = well
	local top = Instance.new("Attachment")
	top.Name = "ColumnTop"
	top.WorldPosition = (at * CFrame.new(0, BlackHole.HOLE_Y - BlackHole.RADIUS * 0.85, 0)).Position
	top.Parent = well
	for i, spec in { { 7.5, 4, TEX.glow, 0.2, 0.72 }, { 5, 2.6, TEX.noise, -1.2, 0.55 } } do
		local b = Instance.new("Beam")
		b.Name = "Column" .. i
		b.Attachment0 = base
		b.Attachment1 = top
		b.Width0 = spec[1]
		b.Width1 = spec[2]
		b.Texture = spec[3]
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureSpeed = spec[4]
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = seq(0, Color3.fromRGB(150, 100, 255), 1, Color3.fromRGB(170, 230, 255))
		b.Transparency = nseq(0, 1, 0.25, spec[5], 0.85, spec[5], 1, 1)
		b.Parent = well
	end
	-- crystal clusters on the rim, each with an energy stream curving up into the hole
	for n, deg in { 35, 155, 275 } do
		local a = math.rad(deg)
		local foot = at * CFrame.new(math.cos(a) * 7.7, 0.4, math.sin(a) * 7.7)
		local out = CFrame.lookAt(foot.Position, at * Vector3.new(math.cos(a) * 20, 0.4, math.sin(a) * 20))
		for j, spec in { { Vector3.new(0.75, 3.2, 0.75), -28, 0 }, { Vector3.new(0.6, 2.2, 0.6), -40, 55 }, { Vector3.new(0.5, 1.6, 0.5), -18, -60 } } do
			local cf = out * CFrame.Angles(0, math.rad(spec[3]), 0) * CFrame.Angles(math.rad(spec[2]), 0, 0) * CFrame.new(0, spec[1].Y / 2 - 0.2, 0) * CFrame.Angles(0, math.rad(45), 0)
			block(k, "Crystal", spec[1], cf, CRYSTAL[(n + j) % #CRYSTAL + 1], Enum.Material.Neon)
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "StreamFrom"
		a0.WorldCFrame = CFrame.fromMatrix(foot.Position + Vector3.new(0, 2.6, 0), Vector3.yAxis, Vector3.new(math.cos(a), 0, math.sin(a)))
		a0.Parent = well
		local a1 = Instance.new("Attachment")
		a1.Name = "StreamTo"
		local into = at * Vector3.new(math.cos(a) * 1.4, BlackHole.HOLE_Y - BlackHole.RADIUS * 0.8, math.sin(a) * 1.4)
		a1.WorldCFrame = CFrame.fromMatrix(into, Vector3.yAxis, Vector3.new(math.cos(a), 0, math.sin(a)))
		a1.Parent = well
		local b = Instance.new("Beam")
		b.Name = "Stream"
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.CurveSize0 = 4
		b.CurveSize1 = 3
		b.Segments = 24
		b.Width0 = 0.7
		b.Width1 = 0.25
		b.Texture = TEX.noise
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureSpeed = 2.2
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = seq(0, CRYSTAL[n], 1, Color3.fromRGB(255, 245, 255))
		b.Transparency = nseq(0, 0.6, 0.3, 0.15, 1, 0.5)
		b.Parent = well
	end
	-- three jagged basalt spires on the rim, leaning out as if the ground burst up round the hole
	for _, deg in { 95, 215, 335 } do
		local a = math.rad(deg + rng:NextNumber(-8, 8))
		local foot = at * CFrame.new(math.cos(a) * 8.3, 0, math.sin(a) * 8.3)
		local out = CFrame.lookAt(foot.Position, at * Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30))
		local lean = out * CFrame.Angles(-math.rad(rng:NextNumber(12, 20)), 0, math.rad(rng:NextNumber(-8, 8)))
		local h1 = rng:NextNumber(3.4, 4.4)
		local low = block(k, "Spire", Vector3.new(2.4, h1, 2.2), lean * CFrame.new(0, h1 / 2 - 0.4, 0), BASALT[rng:NextInteger(1, #BASALT)], Enum.Material.Basalt, true)
		local h2 = rng:NextNumber(2.2, 3)
		local upper = lean * CFrame.new(0.15, h1 - 0.5, 0.1) * CFrame.Angles(0, math.rad(rng:NextNumber(20, 40)), math.rad(rng:NextNumber(-12, 12)))
		block(k, "Spire", Vector3.new(1.5, h2, 1.4), upper * CFrame.new(0, h2 / 2, 0), BASALT[rng:NextInteger(1, #BASALT)], Enum.Material.Basalt, true)
		block(k, "SpireTip", Vector3.new(0.8, 1.1, 0.8), upper * CFrame.new(-0.1, h2 + 0.45, 0) * CFrame.Angles(0, 0.6, 0.2), BASALT[3], Enum.Material.Basalt)
		-- turf still clinging to the lower block, and a glowing seam up its face
		local t = block(k, "Turf", Vector3.new(2.5, 0.35, 1.2), lean * CFrame.new(0, h1 - 0.25, 0.55), TURF, Enum.Material.Grass)
		t.TopSurface = Enum.SurfaceType.Studs
		local seam = block(k, "Seam", Vector3.new(0.18, h1 * 0.8, 0.1), lean * CFrame.new(rng:NextNumber(-0.5, 0.5), h1 / 2 - 0.3, -1.12), Color3.fromRGB(170, 115, 255), Enum.Material.Neon)
		seam.Transparency = 0.1
		low.TopSurface = Enum.SurfaceType.Studs
	end
	-- glowing cracks running out over the ground
	for i = 1, 7 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / 7 * math.pi * 2 + 0.2
		local p0 = Vector3.new(math.cos(a) * 7.4, 0.07, math.sin(a) * 7.4)
		local kink = a + rng:NextNumber(-0.25, 0.25)
		local p1 = Vector3.new(math.cos(kink) * 9.6, 0.07, math.sin(kink) * 9.6)
		local end2 = kink + rng:NextNumber(-0.3, 0.3)
		local p2 = Vector3.new(math.cos(end2) * rng:NextNumber(11, 12.5), 0.07, math.sin(end2) * rng:NextNumber(11, 12.5))
		for j, seg in { { p0, p1, 0.32 }, { p1, p2, 0.2 } } do
			local m = (seg[1] + seg[2]) / 2
			local len = (seg[2] - seg[1]).Magnitude + seg[3]
			local c = block(k, "Crack", Vector3.new(seg[3], 0.12, len), at * CFrame.lookAt(m, seg[2]), Color3.fromRGB(160, 105, 255), Enum.Material.Neon)
			c.Transparency = if j == 1 then 0.1 else 0.35
		end
	end
end

local function crater(k: Instance, at: CFrame)
	local rng = Random.new(1969)
	if BlackHole.GROUND then
		ground(k, at, rng)
	end
	-- chunks of meadow floating round it (client/BlackHole orbits them: OrbitR / OrbitA / OrbitY)
	for i = 1, 8 do
		local s = rng:NextNumber(1.2, 2.8)
		local m = Instance.new("Model")
		m.Name = "Chunk"
		local r = rng:NextNumber(7.5, 9.5)
		local a = (i - 1) / 8 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local y = rng:NextNumber(3, 8)
		local home = at * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.3), rng:NextNumber(-0.4, 0.4))
		local dirt = block(m, "Dirt", Vector3.new(s, s * 0.7, s), home, DIRT, Enum.Material.Ground)
		local grass = block(m, "Grass", Vector3.new(s * 1.04, s * 0.22, s * 1.04), home * CFrame.new(0, s * 0.45, 0), TURF, Enum.Material.Grass)
		grass.TopSurface = Enum.SurfaceType.Studs
		block(m, "Roots", Vector3.new(s * 0.6, s * 0.5, s * 0.55), home * CFrame.new(s * 0.08, -s * 0.55, -s * 0.05), ROOTS, Enum.Material.Ground)
		if i % 2 == 0 then
			block(m, "Tuft", Vector3.new(0.18, s * 0.5, 0.18), home * CFrame.new(-s * 0.2, s * 0.8, s * 0.15) * CFrame.Angles(0, 0, 0.3), Color3.fromRGB(120, 190, 60), Enum.Material.Grass)
		end
		m.PrimaryPart = dirt
		m:SetAttribute("OrbitR", r)
		m:SetAttribute("OrbitA", a)
		m:SetAttribute("OrbitY", y)
		m:SetAttribute("Turn", (home - home.Position))
		m.Parent = k
	end
end

-- the hole itself, round its middle `c` (the disk tilted in `tilt`)
local function hole(k: Instance, c: CFrame, tilt: CFrame)
	local core = ghost(k, "Singularity", Vector3.new(1, 1, 1), c)
	core:SetAttribute("BlackHole", true)
	core:SetAttribute("Radius", BlackHole.RADIUS)
	core:SetAttribute("Disk", BlackHole.DISK)
	core:SetAttribute("Tilt", BlackHole.TILT)
	core:SetAttribute("HoleY", BlackHole.HOLE_Y)
	-- the event horizon: flat black whatever the light (black Neon isn't shaded), a parked player hidden inside
	local horizon = PropKit.part({
		size = Vector3.one * BlackHole.RADIUS * 2,
		cf = c,
		color = Color3.new(0, 0, 0),
		parent = k,
		name = "Horizon",
		collide = false,
		shape = Enum.PartType.Ball,
		material = Enum.Material.Neon,
	})
	horizon.CanQuery = false
	horizon.CanTouch = false
	horizon.CastShadow = false
	-- the halo (always faces you): soft violet glow, the lensed far side of the disk, the photon ring
	local lens = Instance.new("BillboardGui")
	lens.Name = "Lens"
	lens.Size = UDim2.fromScale(17, 17) -- (studs)
	lens.LightInfluence = 0
	lens.Brightness = 2.4
	lens.MaxDistance = 400
	lens.ResetOnSpawn = false
	lens.Parent = core
	image(lens, "Halo", TEX.glow, 1, Color3.fromRGB(120, 70, 255), 0.25, 1)
	image(lens, "Swirl", TEX.spiral, 0.86, Color3.fromRGB(190, 120, 255), 0.45, 2)
	image(lens, "Arc", TEX.ring, 0.62, Color3.fromRGB(255, 170, 110), 0.15, 3)
	image(lens, "Photon", TEX.ringThin, 0.47, Color3.fromRGB(255, 244, 225), 0, 4)
	-- the accretion disk: three spirals and a hot inner ring, seen from above and below
	local disk = ghost(k, "Disk", Vector3.new(BlackHole.DISK * 2, 0.05, BlackHole.DISK * 2), tilt)
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Disk" .. face.Name
		sg.Face = face
		sg.LightInfluence = 0
		sg.Brightness = 2.2
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.Parent = disk
		image(sg, "Haze", TEX.glow, 1.05, Color3.fromRGB(110, 60, 230), 0.4, 1)
		image(sg, "Outer", TEX.spiral, 1, Color3.fromRGB(160, 100, 255), 0.15, 2)
		image(sg, "Mid", TEX.spiral, 0.72, Color3.fromRGB(255, 150, 90), 0.1, 3)
		image(sg, "Inner", TEX.ringThin, 0.5, Color3.fromRGB(255, 236, 200), 0, 4)
		image(sg, "Hot", TEX.ring, 0.42, Color3.fromRGB(255, 200, 140), 0.2, 5)
	end
	-- mist and twinkles in the disk
	emitter(disk, "Mist", {
		Texture = TEX.glow,
		Color = seq(0, Color3.fromRGB(120, 70, 255), 1, Color3.fromRGB(255, 120, 200)),
		Size = nseq(0, 5, 1, 8),
		Transparency = nseq(0, 1, 0.3, 0.82, 0.7, 0.85, 1, 1),
		Lifetime = NumberRange.new(3, 4.5),
		Rate = 3,
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(30, 60),
		LightEmission = 0.7,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	emitter(disk, "Twinkle", {
		Texture = TEX.star,
		Color = seq(0, Color3.fromRGB(255, 240, 210), 1, Color3.fromRGB(170, 220, 255)),
		Size = nseq(0, 0, 0.3, 0.45, 1, 0),
		Transparency = nseq(0, 0.1, 1, 0.3),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 10,
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 90),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	-- sparks falling in from all round (a sphere shell emitting inward)
	local shell = ghost(k, "Infall", Vector3.one * 26, c, Enum.PartType.Ball)
	emitter(shell, "Infall", {
		Texture = TEX.spark,
		Color = seq(0, Color3.fromRGB(150, 210, 255), 0.6, Color3.fromRGB(190, 130, 255), 1, Color3.fromRGB(255, 240, 255)),
		Size = nseq(0, 0.12, 0.5, 0.3, 1, 0.05),
		Squash = nseq(0, -2, 1, -3),
		Transparency = nseq(0, 1, 0.2, 0.15, 0.85, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.95, 1.05),
		Rate = 34,
		Speed = NumberRange.new(9.5, 10.5),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		LightEmission = 1,
	})
	-- the jet up the axis
	local up = tilt.UpVector
	local a0 = Instance.new("Attachment")
	a0.Name = "JetBase"
	a0.WorldPosition = c.Position + up * (BlackHole.RADIUS * 0.9)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Name = "JetTip"
	a1.WorldPosition = c.Position + up * 15
	a1.Parent = core
	for i, w in { 1.6, 0.7 } do
		local b = Instance.new("Beam")
		b.Name = "Jet" .. i
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = if i == 1 then TEX.noise else TEX.glow
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureSpeed = if i == 1 then 1.6 else 0.6
		b.TextureLength = 1
		b.Width0 = w
		b.Width1 = w * 0.15
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 2
		b.Color = seq(0, Color3.fromRGB(140, 230, 255), 1, Color3.fromRGB(170, 110, 255))
		b.Transparency = nseq(0, 1, 0.12, if i == 1 then 0.35 else 0.1, 0.7, 0.6, 1, 1)
		b.Parent = core
	end
	-- light and sound
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = Color3.fromRGB(160, 110, 255)
	light.Brightness = 0.8 -- (soft: stronger turns the rock and the paving blue)
	light.Range = 18
	light.Shadows = false
	light.Parent = core
	local def = Config.SOUNDS.bhHum
	if def and def.id ~= "" then
		local hum = Instance.new("Sound")
		hum.Name = "Hum"
		hum.SoundId = def.id
		hum.Volume = def.volume or 0.4
		hum.Looped = true
		hum.RollOffMode = Enum.RollOffMode.InverseTapered
		hum.RollOffMinDistance = 10
		hum.RollOffMaxDistance = 70
		hum.Playing = true
		hum.Parent = core
	end
end

-- the sign over it (always faces you)
local function sign(k: Instance, at: CFrame)
	local spot = ghost(k, "SignSpot", Vector3.new(1, 1, 1), at * CFrame.new(0, BlackHole.HOLE_Y + 8.4, 0))
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sign"
	bb.Size = UDim2.fromScale(11, 3.6) -- (studs)
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.ResetOnSpawn = false
	bb.Parent = spot
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.66)
	title.Font = Enum.Font.LuckiestGuy
	title.Text = "CLASSES"
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = bb
	local grad = Instance.new("UIGradient")
	grad.Color = seq(0, Color3.fromRGB(255, 255, 255), 0.55, Color3.fromRGB(214, 190, 255), 1, Color3.fromRGB(150, 110, 255))
	grad.Rotation = 90
	grad.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(36, 18, 80)
	stroke.Thickness = 3
	stroke.Parent = title
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0.2, 0.66)
	sub.Size = UDim2.fromScale(0.6, 0.32)
	sub.Font = Enum.Font.LuckiestGuy
	sub.Text = "JUMP IN!"
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(140, 235, 255)
	sub.Parent = bb
	local s2 = Instance.new("UIStroke")
	s2.Color = Color3.fromRGB(20, 30, 70)
	s2.Thickness = 2
	s2.Parent = sub
end

-- Shrink everything built in `m` by k about `at`. Model:ScaleTo covers parts, beams, particles, sounds and the
-- GUIs; lights and the sizes the client reads from attributes are done here.
local function shrink(m: Model, at: CFrame, k: number)
	m.WorldPivot = at
	m:ScaleTo(k)
	for _, d in m:GetDescendants() do
		if d:IsA("Light") then
			(d :: any).Range *= k
		end
		for _, name in { "Radius", "Disk", "HoleY", "OrbitR", "OrbitY" } do
			local v = d:GetAttribute(name)
			if type(v) == "number" then
				d:SetAttribute(name, v * k)
			end
		end
	end
end

-- Build the stand into folder `k` at `at` (the floor in the middle, facing -Z). Returns the hole's middle.
function BlackHole.build(k: Instance, at: CFrame): CFrame
	-- (built in a model so it can be scaled as one, then moved into `k` as before)
	local m = Instance.new("Model")
	crater(m, at)
	local c = at * CFrame.new(0, BlackHole.HOLE_Y, 0)
	local tilt = c * CFrame.Angles(math.rad(BlackHole.TILT), 0, 0)
	hole(m, c, tilt)
	sign(m, at)
	-- the prompt in front (for phones, pads and anyone who'd rather not jump); no Window: client/BlackHole
	-- plays the pull-in first, then opens Classes
	local spot = ghost(m, "Mouth", Vector3.new(2, 2, 2), at * CFrame.new(0, 3, -6.6))
	local p = PropKit.prompt(spot, "Jump in", "Classes", nil, 11)
	p:SetAttribute("BlackHole", true)
	local scale = BlackHole.SCALE
	if scale ~= 1 then
		m.Parent = workspace -- (ScaleTo wants it in the world)
		shrink(m, at, scale)
		c = at * CFrame.new(0, BlackHole.HOLE_Y * scale, 0)
	end
	for _, child in m:GetChildren() do
		child.Parent = k
	end
	m:Destroy()
	return c
end

return BlackHole
