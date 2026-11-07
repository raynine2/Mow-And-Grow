--!strict
-- THE LOBBY'S SKY COMES ALIVE (7 Nov; owner: "the horizon is empty and boring add some cool stuff like a ufo flying or
-- a bosses flying across with cool anims to make it feel alive"). Client side only, lobby only, one show at a time,
-- a few seconds apart, never while a film has the camera:
--   * THE SAUCER: a voxel war-saucer (gunmetal hull, cyan rim, chasing lights, an alien in its glass dome) glides in
--     over the wheat isle, hovers, drops its tractor beam and lifts a square of lawn up into its belly (the lore: aliens
--     steal lawns), then zips off with a trail and a flash of light.
--   * A BOSS FLY-BY: one of the eight voxel bosses (ReplicatedStorage.VoxelBosses), big, sweeps across the sky in a
--     glow of corruption: it faces where it flies, banks into the curve, bobs and sways, and halfway does a barrel roll
--     and a roar (a pulse and a ring of light).
--   * THE CHASE: a boss flees across the sky with the saucer on its tail, its beam on the boss; the boss rolls clear.
-- The paths are arcs round the island at 230-320 studs, mostly across the north sky the spawn looks at.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)

local LobbySky = {}

local C = Color3.fromRGB
local CENTRE = Vector3.new(0, 0, 4)
local folder: Folder? = nil
local low = false
pcall(function()
	local VFX = require(ReplicatedStorage:WaitForChild("VFXLib", 5) :: any)
	low = VFX.Budget.IsLow()
end)

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

local function free(): boolean
	local cam = workspace.CurrentCamera
	return State.mode == "Lobby" and cam ~= nil and cam.CameraType ~= Enum.CameraType.Scriptable
end

-- Runs `step(t)` every frame for `dur` seconds (t from 0 to 1); stops early when the lobby goes away.
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

-- A ring of light that grows and fades at `cf` (a flash, a roar).
local function shock(cf: CFrame, r: number, color: Color3)
	local f = folder
	if not f then
		return
	end
	local p = part(f, Vector3.new(0.6, 2, 2), color, Enum.Material.Neon, 0.1)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(0.3, r * 2, r * 2), Transparency = 1 }):Play()
	task.delay(1, function()
		p:Destroy()
	end)
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
type Saucer = { model: Model, root: Part, lights: { BasePart }, beam: Beam, beamEnd: Attachment, trail: Trail, glow: BasePart }

local CELL = 1.1
local HULL = C(78, 86, 102)
local HULL_TOP = C(150, 160, 178)

-- One layer of the lens: a disc of radius `r` made of rows of cells, `h` tall at height `y` (the voxel grain: rows
-- alternate a hair lighter and darker).
local function disc(m: Model, root: Part, r: number, y: number, h: number, color: Color3, mat: Enum.Material?, tr: number?)
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
	-- the lens, bottom to top
	disc(m, root, 5.5, -2.2, 0.8, C(56, 60, 72))
	disc(m, root, 9.5, -1.4, 1.0, HULL)
	disc(m, root, 13.2, -0.5, 1.0, HULL)
	local rim = part(m, Vector3.new(0.5, 27.4, 27.4), C(70, 235, 255), Enum.Material.Neon)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = root.CFrame * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	disc(m, root, 12.4, 0.65, 1.0, HULL_TOP)
	disc(m, root, 9.4, 1.6, 0.9, HULL_TOP)
	disc(m, root, 6.2, 2.45, 0.8, C(214, 170, 60)) -- the gold collar
	-- the dome and its alien
	disc(m, root, 5.2, 3.4, 1.1, C(150, 230, 255), Enum.Material.Glass, 0.45)
	disc(m, root, 3.8, 4.5, 1.1, C(150, 230, 255), Enum.Material.Glass, 0.45)
	disc(m, root, 2.2, 5.4, 0.8, C(150, 230, 255), Enum.Material.Glass, 0.45)
	local head = part(m, Vector3.new(1.6, 1.8, 1.4), C(120, 230, 90))
	head.CFrame = root.CFrame * CFrame.new(0, 3.9, 0)
	for _, sx in { -0.4, 0.4 } do
		local eye = part(m, Vector3.new(0.45, 0.6, 0.2), C(10, 10, 14))
		eye.CFrame = root.CFrame * CFrame.new(sx, 4.1, -0.72)
	end
	-- the chasing rim lights and the belly glow
	local lights = {}
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local l = part(m, Vector3.new(1, 0.7, 1), C(255, 70, 200), Enum.Material.Neon)
		l.CFrame = root.CFrame * CFrame.new(math.sin(a) * 12.8, -0.3, math.cos(a) * 12.8)
		table.insert(lights, l)
	end
	local glow = part(m, Vector3.new(0.3, 9, 9), C(255, 90, 220), Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.CFrame = root.CFrame * CFrame.new(0, -2.7, 0) * CFrame.Angles(0, 0, math.rad(90))
	-- the beam (off until it hovers) and the zip trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -2.8, 0)
	a0.Parent = root
	local beamEnd = Instance.new("Attachment")
	beamEnd.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = beamEnd
	beam.Width0 = 7
	beam.Width1 = 24
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(C(130, 245, 255))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.7) })
	beam.Segments = 2
	beam.Enabled = false
	beam.Parent = root
	local t0 = Instance.new("Attachment")
	t0.Position = Vector3.new(-11, 0, 0)
	t0.Parent = root
	local t1 = Instance.new("Attachment")
	t1.Position = Vector3.new(11, 0, 0)
	t1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = t0
	trail.Attachment1 = t1
	trail.Lifetime = 0.45
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(C(90, 240, 255), C(255, 80, 220))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = root
	-- every cell keeps its place on the saucer (PivotTo moves the lot)
	m.Parent = folder
	return { model = m, root = root, lights = lights, beam = beam, beamEnd = beamEnd, trail = trail, glow = glow }
end

local saucer: Saucer? = nil
local function getSaucer(): Saucer
	if not saucer or not saucer.model.Parent then
		saucer = buildSaucer()
	end
	return saucer :: Saucer
end

-- The saucer at `pos`, spinning, tilted toward where it's heading; its rim lights chasing round.
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

-- A square of lawn (dirt, a grass top, a few blades) that rises up the beam.
local function lawnChunk(at: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "StolenLawn"
	local dirt = part(m, Vector3.new(7, 2.4, 7), C(132, 94, 60))
	dirt.CFrame = CFrame.new(at)
	local top = part(m, Vector3.new(7.2, 0.9, 7.2), C(92, 178, 54))
	top.CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0))
	local rng = Random.new()
	for _ = 1, 10 do
		local b = part(m, Vector3.new(0.5, rng:NextNumber(1, 2.4), 0.5), C(106, 196, 62))
		b.CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-3, 3), 2.4, rng:NextNumber(-3, 3)))
	end
	m.PrimaryPart = dirt
	m.Parent = folder
	return m
end

local function saucerShow()
	local s = getSaucer()
	local start = ring(105, 330, 105)
	local hover = ring(36, 200, 72) -- over the wheat isle (server/SkyIsland's ISLES)
	local isleTop = ring(36, 190, 12)
	local exit = ring(-125, 430, 160)
	s.trail.Enabled = false
	-- glide in, slowing down, wobbling
	play(7, function(t, e)
		local k = easeOut(t)
		local pos = start:Lerp(hover, k) + Vector3.new(0, math.sin(e * 2.2) * 2.5 * (1 - k) + (1 - k) * 18 * math.sin(k * math.pi), 0)
		placeSaucer(s, pos, hover - start, 14 * (1 - k), e, 1.6)
	end)
	-- hover, beam down, lift a square of lawn up into its belly
	s.beamEnd.WorldPosition = isleTop
	s.beam.Enabled = true
	local chunk = lawnChunk(isleTop + Vector3.new(0, 1.2, 0))
	play(4.5, function(t, e)
		local pos = hover + Vector3.new(math.sin(e * 3) * 0.8, math.sin(e * 2) * 1.2, 0)
		placeSaucer(s, pos, Vector3.new(1, 0, 0), 3 * math.sin(e * 2.5), e + 7, 2.4)
		s.beam.Width1 = 24 + math.sin(e * 9) * 3
		local up = ease(math.clamp((t - 0.15) / 0.8, 0, 1))
		local cp = isleTop:Lerp(pos - Vector3.new(0, 4, 0), up)
		chunk:PivotTo(CFrame.new(cp + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, e * 1.8, math.sin(e * 3) * 0.2))
		s.beamEnd.WorldPosition = if up < 0.95 then cp else isleTop
	end)
	chunk:Destroy()
	s.beam.Enabled = false
	flash(hover - Vector3.new(0, 3, 0), 7, C(130, 245, 255))
	-- zip off, faster and faster, its trail streaking
	s.trail.Enabled = true
	play(2.4, function(t, e)
		local k = easeIn(t)
		local pos = hover:Lerp(exit, k) + Vector3.new(0, math.sin(t * math.pi) * 25, 0)
		placeSaucer(s, pos, exit - hover, 22 * t, e + 12, 2.4 + t * 10)
	end)
	flash(exit, 16, C(255, 120, 230))
	s.trail.Enabled = false
	s.model:PivotTo(CFrame.new(0, -600, 0))
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

type Boss = { model: Model, size: Vector3, lift: number, glow: Color3 }

local lastBoss = ""
local function pickBoss(): Boss?
	local src = ReplicatedStorage:FindFirstChild("VoxelBosses")
	if not src then
		return nil
	end
	local list = {}
	for _, c in src:GetChildren() do
		if c:IsA("Model") and not c.Name:find("_enraged$") and c.Name ~= lastBoss then
			table.insert(list, c)
		end
	end
	if #list == 0 then
		return nil
	end
	local pick = list[math.random(1, #list)]
	lastBoss = pick.Name
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
	m:ScaleTo(m:GetScale() * 2.4)
	local box, size = m:GetBoundingBox()
	-- the pivot's height over the model's middle (so the middle follows the path)
	local lift = m:GetPivot().Position.Y - box.Position.Y
	m.Parent = folder
	local glow = BOSS_GLOW[pick.Name] or C(200, 120, 255)
	-- its corruption: glitchy motes streaming off it, in its own colour and purple
	local core = part(m, Vector3.one, glow, nil, 1)
	core.Name = "SkyCore"
	core.CFrame = box
	if not low then
		local em = Instance.new("ParticleEmitter")
		em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		em.Rate = 40
		em.Lifetime = NumberRange.new(0.8, 1.4)
		em.Speed = NumberRange.new(2, 6)
		em.SpreadAngle = Vector2.new(180, 180)
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
		em.Color = ColorSequence.new(glow, C(170, 80, 255))
		em.LightEmission = 1
		em.LockedToPart = false
		em.Parent = core
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Rate = 14
		smoke.Lifetime = NumberRange.new(1, 1.8)
		smoke.Speed = NumberRange.new(0.5, 1.5)
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size.Y * 0.35), NumberSequenceKeypoint.new(1, size.Y * 0.7) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		smoke.Color = ColorSequence.new(C(120, 60, 200))
		smoke.LightEmission = 0.4
		smoke.LockedToPart = false
		smoke.Parent = core
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = core
	return { model = m, size = size, lift = lift, glow = glow }
end

-- A boss at `mid` heading along `dir`: facing it, banked by `bank` degrees, rolled by `roll`, bobbing, swaying,
-- its pivot moved so its middle is where the path is.
local function placeBoss(b: Boss, mid: Vector3, dir: Vector3, bank: number, roll: number, e: number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local face = if flat.Magnitude > 0.01 then CFrame.lookAt(mid, mid + flat) else CFrame.new(mid)
	local sway = math.sin(e * 1.7) * 0.12
	local bob = math.sin(e * 2.3) * 2.2
	local cf = face * CFrame.new(0, bob, 0) * CFrame.Angles(math.sin(e * 2.3 + 1) * 0.08, sway, math.rad(bank) + roll)
	b.model:PivotTo(cf * CFrame.new(0, b.lift, 0))
	local core = b.model:FindFirstChild("SkyCore") :: BasePart?
	if core then
		core.CFrame = cf
	end
end

-- A boss sweeps across the sky along an arc (`a0` to `a1` degrees, radius `r`, height `y`), rolls and roars halfway.
local function bossPass(b: Boss, a0: number, a1: number, r: number, y: number, dur: number, onT: ((number, Vector3) -> ())?)
	local roared = false
	play(dur, function(t, e)
		local a = a0 + (a1 - a0) * t
		local h = y + math.sin(t * math.pi) * 14
		local pos = ring(a, r, h)
		local ahead = ring(a + (a1 - a0) * 0.01, r, h)
		local dir = ahead - pos
		local bank = if a1 < a0 then -14 else 14
		-- the barrel roll from 45% to 60% of the way, the roar right after
		local rt = math.clamp((t - 0.45) / 0.15, 0, 1)
		local roll = ease(rt) * math.pi * 2 * (if a1 < a0 then 1 else -1)
		placeBoss(b, pos, dir, bank, roll, e)
		if t > 0.62 and not roared then
			roared = true
			shock(CFrame.lookAt(pos, pos + dir), b.size.Magnitude * 1.2, b.glow)
			flash(pos, b.size.Magnitude * 0.35, b.glow)
		end
		if onT then
			onT(t, pos)
		end
	end)
end

local function bossShow()
	local b = pickBoss()
	if not b then
		return
	end
	local leftToRight = math.random() < 0.5
	local a0, a1 = if leftToRight then 115 else -115, if leftToRight then -115 else 115
	bossPass(b, a0, a1, 265, 78, 17)
	b.model:Destroy()
end

-- The chase: a boss flees, the saucer on its tail with its beam on the boss; the boss rolls clear and the saucer gives up.
local function chaseShow()
	local b = pickBoss()
	if not b then
		return
	end
	local s = getSaucer()
	s.trail.Enabled = true
	s.beam.Enabled = false
	local a0, a1 = -120, 120
	local beamOn = false
	bossPass(b, a0, a1, 250, 70, 15, function(t, bossPos)
		local lag = 13 + math.sin(t * 9) * 2
		local a = a0 + (a1 - a0) * t - lag
		local pos = ring(a, 262, 70 + 22 + math.sin(t * math.pi) * 14 + math.sin(t * 20) * 1.5)
		local ahead = ring(a + 1, 262, 70)
		placeSaucer(s, pos, ahead - pos, 12, t * 15, 3)
		-- the beam on the boss until it rolls clear
		local want = t > 0.12 and t < 0.47
		if want ~= beamOn then
			beamOn = want
			s.beam.Enabled = want
		end
		if want then
			s.beamEnd.WorldPosition = bossPos
		end
	end)
	s.beam.Enabled = false
	s.trail.Enabled = false
	b.model:Destroy()
	s.model:PivotTo(CFrame.new(0, -600, 0))
end

-------------------------------------------------------------------------------------------------------------
local SHOWS = { saucerShow, bossShow, chaseShow, bossShow }

local function loop()
	task.wait(5)
	local i = math.random(1, #SHOWS)
	local f = Instance.new("Folder")
	f.Name = "LobbySky"
	f.Parent = workspace
	folder = f
	while State.mode == "Lobby" do
		if free() then
			local ok, err = pcall(SHOWS[i])
			if not ok then
				warn("[LobbySky] " .. tostring(err))
			end
			-- (the saucer is kept between shows; everything else goes)
			for _, c in f:GetChildren() do
				if not (saucer and c == saucer.model) then
					c:Destroy()
				end
			end
			i = i % #SHOWS + 1
			task.wait(if low then 14 else math.random(5, 9))
		else
			task.wait(2)
		end
	end
	f:Destroy()
	folder = nil
	saucer = nil
end

task.spawn(function()
	-- (the player's character first: no point flying things before anyone can see them)
	local player = Players.LocalPlayer
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	if State.mode == "Lobby" then
		loop()
	end
end)

return LobbySky
