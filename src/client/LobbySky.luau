--!strict
-- THE LOBBY'S SKY COMES ALIVE (7 Nov; owner: "the horizon is empty and boring add some cool stuff like a ufo flying or
-- a bosses flying across with cool anims to make it feel alive", then "use fx from the pack to implement more stuff and
-- make it way more often"). Client side only, lobby only, paused while a film has the camera. Three lanes at once:
--   * BIG SHOWS back to back (a second or two apart), in turn:
--       the SAUCER  out of a portal, over a far isle, a magic circle and a pillar of light, its beam lifts a square of
--                   lawn up into its belly, then it dives into a portal and the portal shuts in a flash;
--       a BOSS      tears out of a red rift, sweeps across the sky in its corruption (an orb of it riding along),
--                   banks, bobs, does a barrel roll, roars (lightning, a shockwave, a void ring) and dives into a black
--                   hole;
--       the CHASE   a boss flees with the saucer on its tail zapping it with lightning, the boss rolls clear;
--       a DUEL      two bosses fly at each other over the north rim and clash three times (crossed slashes, bursts,
--                   lightning), then both tear off through rifts;
--       a BLACK HOLE opens in the sky, a vortex of leaves and petals swirls into it, a boss gets sucked in spinning,
--                   then it collapses in a white flash;
--       an AWAKENING a magic circle and a pillar of light on a far isle, a boss rises out of it, roars and flies off
--                   through a portal;
--   * SHOOTING STARS and now and then a METEOR striking a far isle (every half second to a second);
--   * a far-off boss PATROL always circling high over the horizon in its glow, swapped through a rift now and then.
-- The pack's effects (client/PackFx, ReplicatedStorage.PackVFX) do the magic; with the pack off the shows still play,
-- just plainer. Paths are arcs round the island at 150-200 studs (the rim is at ~100), mostly across the north sky
-- the spawn looks at.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local Pack = require(script.Parent.PackFx) :: any

local LobbySky = {}

local C = Color3.fromRGB
local CENTRE = Vector3.new(0, 0, 4)
local folder: Folder? = nil
local low = false
pcall(function()
	local VFX = require(ReplicatedStorage:WaitForChild("VFXLib", 5) :: any)
	low = VFX.Budget.IsLow()
end)
-- the far isles (server/SkyIsland's ISLES): angle, distance, height of the island's top
local ISLES = { { 38, 190, 12 }, { -38, 190, 18 }, { 74, 205, -2 }, { -74, 205, 4 }, { 112, 210, 28 }, { -112, 210, 22 } }

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function easeIn(t: number): number
	return t * t * t
end

-- A point on the circle round the island: `a` degrees from north (+ to the left as you face north from the spawn).
local function ring(a: number, r: number, y: number): Vector3
	local t = math.rad(a)
	return CENTRE + Vector3.new(math.sin(t) * r, y, math.cos(t) * r)
end

local function isleTop(i: number): Vector3
	local s = ISLES[i]
	local p = ring(s[1], s[2], s[3] + 40)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(p, Vector3.new(0, -90, 0), rp)
	return if hit then hit.Position else ring(s[1], s[2], s[3])
end

local function part(parent: Instance, size: Vector3, color: Color3, mat: Enum.Material?, tr: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- (Studio: the Workspace attribute SkyTest = true keeps the shows going under a scripted camera, to film them)
local function free(): boolean
	local cam = workspace.CurrentCamera
	if workspace:GetAttribute("SkyTest") == true then
		return State.mode == "Lobby"
	end
	return State.mode == "Lobby" and cam ~= nil and cam.CameraType ~= Enum.CameraType.Scriptable
end

-- A pack effect (forced past the pack's cap: these are the shows' big moments); nil when the pack is off.
local function fx(name: string, at: CFrame | Vector3, scale: number, color: Color3?, force: boolean?): any
	local ok, m = pcall(Pack.play, name, at, { scale = scale, color = color, force = force ~= false })
	return if ok then m else nil
end

-- A pack effect that stays on (an aura riding on something): move it with .move(cf), end it with .stop().
local function aura(name: string, at: CFrame, scale: number, color: Color3?): any
	local ok, h = pcall(Pack.loop, name, at, { scale = scale, color = color, locked = true })
	if ok and h then
		return h
	end
	return { move = function(_: CFrame) end, stop = function(_: number?) end }
end

-- Runs `step(t, e)` every frame for `dur` seconds (t from 0 to 1); stops early when the lobby goes away.
local function play(dur: number, step: (number, number) -> ())
	local t0 = os.clock()
	while true do
		local e = os.clock() - t0
		if e >= dur or State.mode ~= "Lobby" then
			break
		end
		step(e / dur, e)
		RunService.RenderStepped:Wait()
	end
	step(1, dur)
end

local function flash(at: Vector3, r: number, color: Color3)
	local f = folder
	if not f then
		return
	end
	local p = part(f, Vector3.one * 2, color, Enum.Material.Neon, 0)
	p.Shape = Enum.PartType.Ball
	p.CFrame = CFrame.new(at)
	TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.one * r * 2, Transparency = 1 }):Play()
	task.delay(0.6, function()
		p:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the saucer
-------------------------------------------------------------------------------------------------------------
type Saucer = { model: Model, root: Part, lights: { BasePart }, beam: Beam, beamEnd: Attachment, trail: Trail }

local CELL = 2.2 -- (seen in Studio at 1.1: a dot behind the trees at 200 studs)
local HULL = C(78, 86, 102)
local HULL_TOP = C(150, 160, 178)
local S = 2 -- sizes below are the 1.1-cell saucer's, times this

local function disc(m: Model, root: Part, r: number, y: number, h: number, color: Color3, mat: Enum.Material?, tr: number?)
	r *= S
	y *= S
	h *= S
	local n = math.floor(r / CELL)
	for i = -n, n - 1 do
		local x = (i + 0.5) * CELL
		local half = math.floor(math.sqrt(math.max(r * r - x * x, 0)) / CELL) * CELL
		if half > 0 then
			local k = if i % 2 == 0 then 1.04 else 0.96
			local c = Color3.new(math.min(1, color.R * k), math.min(1, color.G * k), math.min(1, color.B * k))
			local p = part(m, Vector3.new(CELL, h, half * 2), c, mat, tr)
			p.CFrame = root.CFrame * CFrame.new(x, y, 0)
		end
	end
end

local function buildSaucer(): Saucer
	local m = Instance.new("Model")
	m.Name = "SkySaucer"
	local root = part(m, Vector3.one, C(0, 0, 0), nil, 1)
	root.Name = "Root"
	root.CFrame = CFrame.new(0, -500, 0)
	m.PrimaryPart = root
	disc(m, root, 5.5, -2.2, 0.8, C(56, 60, 72))
	disc(m, root, 9.5, -1.4, 1.0, HULL)
	disc(m, root, 13.2, -0.5, 1.0, HULL)
	local rim = part(m, Vector3.new(0.5 * S, 27.4 * S, 27.4 * S), C(70, 235, 255), Enum.Material.Neon)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = root.CFrame * CFrame.new(0, 0.15 * S, 0) * CFrame.Angles(0, 0, math.rad(90))
	disc(m, root, 12.4, 0.65, 1.0, HULL_TOP)
	disc(m, root, 9.4, 1.6, 0.9, HULL_TOP)
	disc(m, root, 6.2, 2.45, 0.8, C(214, 170, 60))
	disc(m, root, 5.2, 3.4, 1.1, C(150, 230, 255), Enum.Material.Glass, 0.45)
	disc(m, root, 3.8, 4.5, 1.1, C(150, 230, 255), Enum.Material.Glass, 0.45)
	disc(m, root, 2.2, 5.4, 0.8, C(150, 230, 255), Enum.Material.Glass, 0.45)
	local head = part(m, Vector3.new(1.6, 1.8, 1.4) * S, C(120, 230, 90))
	head.CFrame = root.CFrame * CFrame.new(0, 3.9 * S, 0)
	for _, sx in { -0.4, 0.4 } do
		local eye = part(m, Vector3.new(0.45, 0.6, 0.2) * S, C(10, 10, 14))
		eye.CFrame = root.CFrame * CFrame.new(sx * S, 4.1 * S, -0.72 * S)
	end
	local lights = {}
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local l = part(m, Vector3.new(1, 0.7, 1) * S, C(255, 70, 200), Enum.Material.Neon)
		l.CFrame = root.CFrame * CFrame.new(math.sin(a) * 12.8 * S, -0.3 * S, math.cos(a) * 12.8 * S)
		table.insert(lights, l)
	end
	local glow = part(m, Vector3.new(0.3, 9, 9) * S, C(255, 90, 220), Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.CFrame = root.CFrame * CFrame.new(0, -2.7 * S, 0) * CFrame.Angles(0, 0, math.rad(90))
	local light = Instance.new("PointLight")
	light.Color = C(255, 120, 230)
	light.Range = 40
	light.Brightness = 2
	light.Parent = glow
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -2.8 * S, 0)
	a0.Parent = root
	local beamEnd = Instance.new("Attachment")
	beamEnd.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = beamEnd
	beam.Width0 = 7 * S
	beam.Width1 = 24 * S
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(C(130, 245, 255))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.65) })
	beam.Segments = 2
	beam.Enabled = false
	beam.Parent = root
	local t0 = Instance.new("Attachment")
	t0.Position = Vector3.new(-11 * S, 0, 0)
	t0.Parent = root
	local t1 = Instance.new("Attachment")
	t1.Position = Vector3.new(11 * S, 0, 0)
	t1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = t0
	trail.Attachment1 = t1
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(C(90, 240, 255), C(255, 80, 220))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = root
	m.Parent = folder
	return { model = m, root = root, lights = lights, beam = beam, beamEnd = beamEnd, trail = trail }
end

local saucer: Saucer? = nil
local function getSaucer(): Saucer
	if not saucer or not saucer.model.Parent then
		saucer = buildSaucer()
	end
	return saucer :: Saucer
end

local function hideSaucer(s: Saucer)
	s.beam.Enabled = false
	s.trail.Enabled = false
	s.model:PivotTo(CFrame.new(0, -600, 0))
end

local function placeSaucer(s: Saucer, pos: Vector3, heading: Vector3, tilt: number, e: number, spin: number)
	local flat = Vector3.new(heading.X, 0, heading.Z)
	local look = if flat.Magnitude > 0.01 then CFrame.lookAt(pos, pos + flat) else CFrame.new(pos)
	s.model:PivotTo(look * CFrame.Angles(math.rad(-tilt), 0, 0) * CFrame.Angles(0, e * spin, 0))
	local lead = math.floor(e * 14) % #s.lights
	for i, l in s.lights do
		local d = (i - lead) % #s.lights
		l.Color = if d < 3 then C(255, 240, 120) elseif i % 2 == 0 then C(255, 70, 200) else C(70, 235, 255)
	end
end

local function lawnChunk(at: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "StolenLawn"
	local dirt = part(m, Vector3.new(12, 4, 12), C(132, 94, 60))
	dirt.CFrame = CFrame.new(at)
	local top = part(m, Vector3.new(12.4, 1.4, 12.4), C(92, 178, 54))
	top.CFrame = CFrame.new(at + Vector3.new(0, 2.6, 0))
	local rng = Random.new()
	for _ = 1, 14 do
		local b = part(m, Vector3.new(0.8, rng:NextNumber(1.6, 3.6), 0.8), C(106, 196, 62))
		b.CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-5, 5), 3.8, rng:NextNumber(-5, 5)))
	end
	m.PrimaryPart = dirt
	m.Parent = folder
	return m
end

local function saucerShow()
	local s = getSaucer()
	local which = if math.random() < 0.5 then 1 else 2
	local ground = isleTop(which)
	local side = if which == 1 then 1 else -1
	local start = ring(side * 120, 200, 120)
	local hover = Vector3.new(ground.X, ground.Y + 60, ground.Z) + (CENTRE - Vector3.new(ground.X, 0, ground.Z)).Unit * 20
	local exit = ring(-side * 60, 230, 150)
	-- out of a portal
	fx("Portal", CFrame.lookAt(start, hover), 3.2, C(90, 240, 255))
	task.wait(0.35)
	flash(start, 22, C(140, 250, 255))
	play(5.5, function(t, e)
		local k = easeOut(t)
		local pos = start:Lerp(hover, k) + Vector3.new(0, math.sin(k * math.pi) * 22, 0)
		placeSaucer(s, pos, hover - start, 16 * (1 - k), e, 1.6)
	end)
	-- the magic circle and the pillar on the isle, the beam, the lawn going up
	fx("MagicCircle", CFrame.new(ground + Vector3.new(0, 1, 0)), 3, C(90, 240, 255))
	fx("LightPillar", ground, 2.4, C(130, 245, 255))
	s.beamEnd.WorldPosition = ground
	s.beam.Enabled = true
	local chunk = lawnChunk(ground + Vector3.new(0, 2, 0))
	play(4.2, function(t, e)
		local pos = hover + Vector3.new(math.sin(e * 3) * 1.2, math.sin(e * 2) * 2, 0)
		placeSaucer(s, pos, CENTRE - pos, 3 * math.sin(e * 2.5), e + 6, 2.4)
		s.beam.Width1 = (24 + math.sin(e * 9) * 3) * S
		local up = ease(math.clamp((t - 0.12) / 0.8, 0, 1))
		local cp = ground:Lerp(pos - Vector3.new(0, 8, 0), up)
		chunk:PivotTo(CFrame.new(cp + Vector3.new(0, 2, 0)) * CFrame.Angles(0, e * 1.8, math.sin(e * 3) * 0.2))
	end)
	chunk:Destroy()
	s.beam.Enabled = false
	fx("PinkBurst", hover - Vector3.new(0, 6, 0), 4, C(255, 120, 230))
	-- dive into a portal, which shuts in a flash
	local gate = CFrame.lookAt(exit, exit + (exit - hover))
	fx("Portal", gate, 3.4, C(255, 90, 220))
	s.trail.Enabled = true
	play(1.8, function(t, e)
		local k = easeIn(t)
		local pos = hover:Lerp(exit, k) + Vector3.new(0, math.sin(t * math.pi) * 18, 0)
		placeSaucer(s, pos, exit - hover, 24 * t, e + 11, 2.4 + t * 12)
	end)
	hideSaucer(s)
	fx("WhiteFlash", exit, 1.4, C(255, 160, 240))
	fx("RingBurst", CFrame.lookAt(exit, CENTRE), 5, C(255, 90, 220))
end

-------------------------------------------------------------------------------------------------------------
-- the bosses
-------------------------------------------------------------------------------------------------------------
local BOSS_GLOW: { [string]: Color3 } = {
	dandelion_king = C(255, 214, 60),
	frost_thornback = C(140, 220, 255),
	harvest_maw = C(255, 150, 60),
	sakura_snapjaw = C(255, 140, 200),
	bramble_brute = C(150, 220, 80),
	bog_strangler = C(120, 200, 140),
	hollow_harvest = C(255, 120, 40),
	jungle_titan = C(80, 230, 200),
}

type Boss = { model: Model, size: Vector3, lift: number, glow: Color3, core: Part, orb: any }

local recent: { string } = {}
local function pickBoss(scale: number): Boss?
	local src = ReplicatedStorage:FindFirstChild("VoxelBosses")
	if not src then
		return nil
	end
	local list = {}
	for _, c in src:GetChildren() do
		if c:IsA("Model") and not c.Name:find("_enraged$") and not table.find(recent, c.Name) then
			table.insert(list, c)
		end
	end
	if #list == 0 then
		table.clear(recent)
		return pickBoss(scale)
	end
	local pick = list[math.random(1, #list)]
	table.insert(recent, pick.Name)
	if #recent > 4 then
		table.remove(recent, 1)
	end
	local m = pick:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("AnimationController") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	m:ScaleTo(m:GetScale() * scale)
	local box, size = m:GetBoundingBox()
	local lift = m:GetPivot().Position.Y - box.Position.Y
	m.Parent = folder
	local glow = BOSS_GLOW[pick.Name] or C(200, 120, 255)
	local core = part(m, Vector3.one, glow, nil, 1)
	core.Name = "SkyCore"
	core.CFrame = box
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 50
	light.Brightness = 2
	light.Parent = core
	-- its corruption riding along
	local orb = aura("CorruptOrb", box, size.Magnitude / 22, glow)
	if not Pack.on() and not low then
		local em = Instance.new("ParticleEmitter")
		em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		em.Rate = 40
		em.Lifetime = NumberRange.new(0.8, 1.4)
		em.Speed = NumberRange.new(2, 6)
		em.SpreadAngle = Vector2.new(180, 180)
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0) })
		em.Color = ColorSequence.new(glow, C(170, 80, 255))
		em.LightEmission = 1
		em.Parent = core
	end
	return { model = m, size = size, lift = lift, glow = glow, core = core, orb = orb }
end

local function dropBoss(b: Boss)
	b.orb.stop(0.5)
	b.model:Destroy()
end

-- A boss with its middle at `mid` heading along `dir`: facing it, banked, rolled, bobbing and swaying.
local function placeBoss(b: Boss, mid: Vector3, dir: Vector3, bank: number, roll: number, e: number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local face = if flat.Magnitude > 0.01 then CFrame.lookAt(mid, mid + flat) else CFrame.new(mid)
	local cf = face * CFrame.new(0, math.sin(e * 2.3) * 3, 0) * CFrame.Angles(math.sin(e * 2.3 + 1) * 0.08, math.sin(e * 1.7) * 0.12, math.rad(bank) + roll)
	b.model:PivotTo(cf * CFrame.new(0, b.lift, 0))
	b.core.CFrame = cf
	b.orb.move(cf)
end

-- The roar: lightning, a shockwave and a void ring round it.
local function roar(b: Boss, at: Vector3, toward: Vector3)
	local k = b.size.Magnitude / 30
	fx("Bolt", at, 1.2 * k, b.glow)
	fx("Shock", at, 4 * k, b.glow)
	fx("VoidRing", CFrame.lookAt(at, toward), 1.6 * k, b.glow)
	fx("RingBurst", CFrame.lookAt(at, toward), 3 * k, b.glow)
	flash(at, b.size.Magnitude * 0.35, b.glow)
end

-- A boss sweeps along an arc (`a0` to `a1` degrees, radius `r`, height `y`), rolls at 45-60% and roars at 62%.
local function bossPass(b: Boss, a0: number, a1: number, r: number, y: number, dur: number, onT: ((number, Vector3) -> ())?)
	local roared = false
	local sign = if a1 < a0 then 1 else -1
	play(dur, function(t, e)
		local a = a0 + (a1 - a0) * t
		local h = y + math.sin(t * math.pi) * 18
		local pos = ring(a, r, h)
		local dir = ring(a + (a1 - a0) * 0.01, r, h) - pos
		local rt = math.clamp((t - 0.45) / 0.15, 0, 1)
		placeBoss(b, pos, dir, -14 * sign, ease(rt) * math.pi * 2 * sign, e)
		if t > 0.62 and not roared then
			roared = true
			roar(b, pos, CENTRE)
		end
		if onT then
			onT(t, pos)
		end
	end)
end

local function bossShow()
	local b = pickBoss(4)
	if not b then
		return
	end
	local sign = if math.random() < 0.5 then 1 else -1
	local a0, a1 = 110 * sign, -110 * sign
	local r, y = 175, 78
	local from = ring(a0, r, y)
	fx("RedRift", CFrame.lookAt(from, CENTRE), 3, b.glow)
	fx("PurpleBurst", from, 3)
	bossPass(b, a0, a1, r, y, 13)
	local to = ring(a1, r, y)
	fx("BlackHole", to, 2.4, b.glow)
	-- into the black hole, spinning
	play(1.2, function(t, e)
		local pos = to
		local cf = CFrame.new(pos) * CFrame.Angles(0, e * 9, 0)
		b.model:PivotTo(cf * CFrame.new(0, b.lift * (1 - t), 0) * CFrame.new(0, -t * 8, 0))
		b.core.CFrame = cf
		b.orb.move(cf)
	end)
	fx("WhiteFlash", to, 1.2, b.glow)
	dropBoss(b)
end

-- The chase: the boss flees, the saucer behind it zapping it with lightning; the boss rolls clear.
local function chaseShow()
	local b = pickBoss(3.6)
	if not b then
		return
	end
	local s = getSaucer()
	s.trail.Enabled = true
	local sign = if math.random() < 0.5 then 1 else -1
	local a0, a1 = -120 * sign, 120 * sign
	local zaps = { 0.18, 0.3, 0.42 }
	local nextZap = 1
	bossPass(b, a0, a1, 170, 72, 12, function(t, bossPos)
		local lag = 16 + math.sin(t * 9) * 2
		local a = a0 + (a1 - a0) * t - lag * (if a1 > a0 then 1 else -1)
		local pos = ring(a, 182, 104 + math.sin(t * math.pi) * 14 + math.sin(t * 20) * 2)
		placeSaucer(s, pos, bossPos - pos, 12, t * 12, 3)
		local beamOn = t > 0.12 and t < 0.45
		s.beam.Enabled = beamOn
		if beamOn then
			s.beamEnd.WorldPosition = bossPos
		end
		if zaps[nextZap] and t >= zaps[nextZap] then
			nextZap += 1
			fx("Bolt", bossPos, 1.4, C(120, 240, 255))
			fx("BigBurst", bossPos, 3, C(120, 240, 255))
		end
	end)
	fx("SpeedLines", ring(a1, 170, 80), 6)
	dropBoss(b)
	hideSaucer(s)
end

-- The duel: two bosses fly at each other over the north rim and clash three times, then tear off through rifts.
local function duelShow()
	local a = pickBoss(3.4)
	local b = pickBoss(3.4)
	if not a or not b then
		if a then
			dropBoss(a)
		end
		if b then
			dropBoss(b)
		end
		return
	end
	local mid = ring(math.random(-25, 25), 165, 92)
	local across = (mid - CENTRE).Unit:Cross(Vector3.yAxis)
	local function pos(side: number, gap: number, e: number): Vector3
		return mid + across * side * gap + Vector3.new(0, math.sin(e * 2 + side) * 4, 0)
	end
	fx("Rift", CFrame.lookAt(pos(1, 90, 0), mid), 3, a.glow)
	fx("Rift", CFrame.lookAt(pos(-1, 90, 0), mid), 3, b.glow)
	for clash = 1, 3 do
		-- rush in
		play(1.3, function(t, e)
			local gap = 90 - easeIn(t) * 80
			if clash > 1 then
				gap = 40 - easeIn(t) * 30
			end
			placeBoss(a, pos(1, gap, e), -across, 0, 0, e)
			placeBoss(b, pos(-1, gap, e), across, 0, 0, e)
		end)
		local hit = mid + Vector3.new(0, 4, 0)
		fx("SlashX", CFrame.lookAt(hit, CENTRE), 4, a.glow)
		fx("BigBurst", hit, 4, b.glow)
		fx("Bolt", hit, 1.3, C(255, 255, 255))
		fx("Shock", hit, 6, a.glow)
		flash(hit, 16, C(255, 255, 255))
		-- knocked apart, spinning
		play(0.9, function(t, e)
			local gap = 10 + easeOut(t) * 30
			placeBoss(a, pos(1, gap, e), -across, 0, t * math.pi * 2, e)
			placeBoss(b, pos(-1, gap, e), across, 0, -t * math.pi * 2, e)
		end)
	end
	-- both tear off through rifts
	local ra, rb = pos(1, 120, 0) + Vector3.new(0, 30, 0), pos(-1, 120, 0) + Vector3.new(0, 30, 0)
	fx("RedRift", CFrame.lookAt(ra, mid), 3, a.glow)
	fx("RedRift", CFrame.lookAt(rb, mid), 3, b.glow)
	play(1.4, function(t, e)
		local k = easeIn(t)
		placeBoss(a, pos(1, 40, e):Lerp(ra, k), across, 0, 0, e)
		placeBoss(b, pos(-1, 40, e):Lerp(rb, k), -across, 0, 0, e)
	end)
	fx("PurpleBurst", ra, 3)
	fx("PurpleBurst", rb, 3)
	dropBoss(a)
	dropBoss(b)
end

-- A black hole opens in the sky; leaves and petals swirl into it, a boss gets sucked in spinning; it collapses.
local function blackHoleShow()
	local at = ring(math.random(-50, 50), 200, 130)
	local hole = aura("BlackHole", CFrame.lookAt(at, CENTRE), 3)
	local vortex = aura("WindVortex", CFrame.lookAt(at, CENTRE) * CFrame.Angles(math.rad(90), 0, 0), 2.4, C(200, 140, 255))
	fx("Leaves", at + Vector3.new(30, -20, 0), 3, nil, false)
	fx("Petals", at + Vector3.new(-30, -20, 0), 4, nil, false)
	local b = pickBoss(3.2)
	task.wait(0.8)
	if b then
		local start = at + (CENTRE - at).Unit * 70 + Vector3.new(60, -40, 0)
		play(4, function(t, e)
			local k = easeIn(t)
			local spiral = CFrame.Angles(0, t * 9, 0) * CFrame.new(0, 0, 60 * (1 - k))
			local p = start:Lerp(at, k)
			local pos = (CFrame.new(p) * spiral).Position
			placeBoss(b, pos, at - pos, 30, t * 14, e)
		end)
		dropBoss(b)
	else
		task.wait(4)
	end
	hole.stop(0.6)
	vortex.stop(0.6)
	fx("WhiteFlash", at, 1.6)
	fx("RingBurst", CFrame.lookAt(at, CENTRE), 6, C(200, 140, 255))
	fx("Shock", at, 8, C(200, 140, 255))
end

-- An awakening on a far isle: a magic circle and a pillar of light, a boss rises out of it, roars, flies off.
local function awakeningShow()
	local i = math.random(1, #ISLES)
	local ground = isleTop(i)
	local b = pickBoss(3.4)
	if not b then
		return
	end
	fx("MagicCircle", CFrame.new(ground + Vector3.new(0, 1, 0)), 3.4, b.glow)
	fx("LightPillar", ground, 3, b.glow)
	fx("GroundRing", ground, 4, b.glow)
	local top = ground + Vector3.new(0, 50, 0)
	play(2.6, function(t, e)
		local pos = ground:Lerp(top, easeOut(t))
		placeBoss(b, pos, CENTRE - pos, 0, 0, e)
	end)
	roar(b, top, CENTRE)
	task.wait(0.4)
	local out = top + (top - CENTRE).Unit * 40 + Vector3.new(0, 70, 0)
	fx("Portal", CFrame.lookAt(out, top), 3, b.glow)
	play(1.6, function(t, e)
		local pos = top:Lerp(out, easeIn(t))
		placeBoss(b, pos, out - top, 0, t * math.pi, e)
	end)
	fx("WhiteFlash", out, 1, b.glow)
	dropBoss(b)
end

-------------------------------------------------------------------------------------------------------------
-- shooting stars, meteors, the far patrol
-------------------------------------------------------------------------------------------------------------
local function shootingStar()
	local a = math.random(-160, 160)
	local from = ring(a, math.random(220, 320), math.random(170, 260))
	local dir = Vector3.new(math.random() - 0.5, -0.35, math.random() - 0.5).Unit
	local to = from + dir * math.random(90, 160)
	local f = folder
	if not f then
		return
	end
	local p = part(f, Vector3.one * 1.6, C(255, 250, 220), Enum.Material.Neon)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.35
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.Color = ColorSequence.new(C(255, 250, 220), C(160, 200, 255))
	tr.Transparency = NumberSequence.new(0, 1)
	tr.Parent = p
	p.CFrame = CFrame.new(from)
	local tw = TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to) })
	tw:Play()
	tw.Completed:Once(function()
		fx("Star", to, 4, nil, false)
		p.Transparency = 1
		task.delay(0.4, function()
			p:Destroy()
		end)
	end)
end

local function meteor()
	local i = math.random(1, #ISLES)
	local ground = isleTop(i)
	local from = ground + Vector3.new(math.random(-80, 80), 160, math.random(-80, 80))
	local f = folder
	if not f then
		return
	end
	local rock = part(f, Vector3.one * 5, C(255, 140, 60), Enum.Material.Neon)
	local trail = aura("Orb", CFrame.new(from), 3, C(255, 140, 60))
	play(1.1, function(t)
		local p = from:Lerp(ground, easeIn(t))
		rock.CFrame = CFrame.new(p) * CFrame.Angles(t * 6, t * 4, 0)
		trail.move(CFrame.new(p))
	end)
	trail.stop(0.4)
	rock:Destroy()
	fx("Explosion", ground, 0.22, C(255, 150, 70), false)
	fx("Rocks", ground, 2.5, nil, false)
	fx("GoldBurst", ground + Vector3.new(0, 6, 0), 2, C(255, 160, 80), false)
end

-- The patrol: one boss always circling high and far, in its glow; swapped through a rift every 30-45 s.
local function patrol()
	while State.mode == "Lobby" do
		if not free() then
			task.wait(2)
			continue
		end
		local b = pickBoss(3)
		if not b then
			return
		end
		local a = math.random(0, 359)
		local dirSign = if math.random() < 0.5 then 1 else -1
		local r, y = 300, 150
		fx("Rift", CFrame.lookAt(ring(a, r, y), CENTRE), 3, b.glow)
		local life = math.random(30, 45)
		play(life, function(t, e)
			local ang = a + dirSign * e * 6
			local pos = ring(ang, r, y + math.sin(e * 0.7) * 12)
			local dir = ring(ang + dirSign, r, y) - ring(ang, r, y)
			placeBoss(b, pos, dir, -18 * dirSign, 0, e)
		end)
		local endAng = a + dirSign * life * 6
		fx("Rift", CFrame.lookAt(ring(endAng, r, y), CENTRE), 3, b.glow)
		fx("PurpleBurst", ring(endAng, r, y), 3)
		dropBoss(b)
		task.wait(1)
	end
end

local function sparkle()
	while State.mode == "Lobby" do
		if free() then
			if math.random() < 0.18 then
				task.spawn(meteor)
			else
				shootingStar()
			end
		end
		task.wait(if low then math.random(20, 35) / 10 else math.random(5, 12) / 10)
	end
end

-------------------------------------------------------------------------------------------------------------
local SHOWS = { saucerShow, bossShow, duelShow, chaseShow, awakeningShow, blackHoleShow }

local function shuffled(): { () -> () }
	local list = table.clone(SHOWS)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function shows()
	while State.mode == "Lobby" do
		for _, show in shuffled() do
			if State.mode ~= "Lobby" then
				break
			end
			while not free() and State.mode == "Lobby" do
				task.wait(1)
			end
			local ok, err = pcall(show)
			if not ok then
				warn("[LobbySky] " .. tostring(err))
			end
			if saucer then
				hideSaucer(saucer)
			end
			task.wait(if low then 6 else math.random(6, 16) / 10)
		end
	end
end

local function start()
	local f = Instance.new("Folder")
	f.Name = "LobbySky"
	f.Parent = workspace
	folder = f
	task.wait(3)
	task.spawn(sparkle)
	if not low then
		task.spawn(patrol)
	end
	shows()
	f:Destroy()
	folder = nil
	saucer = nil
end

task.spawn(function()
	local player = Players.LocalPlayer
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	if State.mode == "Lobby" then
		start()
	end
end)

return LobbySky
