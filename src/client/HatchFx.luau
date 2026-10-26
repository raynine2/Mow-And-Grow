-- The egg hatch, in 3D (the owner's brief, claude.ai project doc claude/hatch-revamp-brief.md).
-- The camera holds still and the world behind goes soft and dark; real 3D eggs (Blender egg_garden / egg_golden from
-- shared/PartModels) drop in with a squash, wobble harder and faster while 2-3 cracks open glowing in the rarity
-- colour (Legendary and up fake you out: the glow starts Epic purple and jumps to gold), swell, then burst: shell
-- shards fly and fall, grass clippings and stars spray, a VFX Forge shockwave rolls out, the camera shakes, and the
-- critter jumps out, spins once and idles on rays in its colour under a chunky name + rarity banner (NEW! the first
-- time). Rarer = bigger: Legendary gets a gold double shockwave and big rays, Secret a full cinematic (the world goes
-- dark, a rainbow burst). The Golden Egg throws gold sparks and coins. 3 / 10 eggs stand in a row and crack together.
-- Click to skip (only when nothing Legendary or better is inside), click again to close. Phones get fewer effects.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local PartBuild = require(Shared:WaitForChild("PartBuild"))
local okIcons, IconIds = pcall(require, Shared:FindFirstChild("IconIds"))
local okFx, FxIds = pcall(require, Shared:FindFirstChild("FxIds"))
local VFXLib = ReplicatedStorage:FindFirstChild("VFXLib")
local okAssets, Assets = pcall(function()
	return require((VFXLib :: Instance):WaitForChild("Assets"))
end)
local okForge, Forge = pcall(function()
	return require((VFXLib :: Instance):WaitForChild("Forge"))
end)
local modules = script.Parent
local PetFollow = require(modules:WaitForChild("PetFollow"))
local Sound = require(modules:WaitForChild("Sound"))
local Confetti = require(modules:WaitForChild("Confetti"))

local HatchFx = {}
HatchFx.busy = false
HatchFx.timeScale = 1 -- tests: slow the hatch down to look at it frame by frame

local TEX = if okAssets and type(Assets) == "table" then Assets.Tex else {}
local ICONS = if okIcons and type(IconIds) == "table" then IconIds else {}
local FX = if okFx and type(FxIds) == "table" then FxIds else {}
local RAYS = (Config.ICONS and Config.ICONS.ui_rays ~= "" and Config.ICONS.ui_rays) or ICONS.ui_rays or TEX.VS_Starburst
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FEW = if MOBILE then 0.5 else 1

local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local BIG = 5 -- Legendary and up: no skipping, fake-out, gold shockwave
local DIST = 13 -- studs from the camera to the eggs
local GOLD = Color3.fromRGB(255, 196, 50)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(250, 240, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 230, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
})

-- timeline (seconds): drop, land, wobble + cracks, swell, burst, reveal
local T = { land = 0.4, wobble = 0.7, crack = { 1.15, 1.7, 2.2 }, swell = 2.35, burst = 2.55, click = 3.2 }
-- The wobble comes in kicks (seconds after T.wobble, strength), not a steady shake: the egg sits still between
-- them, the gaps get shorter and the kicks harder (timing: wide spacing reads calm, tight spacing reads urgent).
-- A kick lands just before each crack, so the kick is what cracks it.
local KICKS = {
	{ 0.0, 0.35 },
	{ 0.4, 0.55 },
	{ 0.62, 0.45 },
	{ 0.95, 0.75 },
	{ 1.12, 0.6 },
	{ 1.26, 0.85 },
	{ 1.38, 0.8 },
	{ 1.5, 1 },
	{ 1.58, 0.9 },
}

local function rarityColor(r: string, t: number?): Color3
	if r == "Secret" then
		local h = ((t or os.clock()) * 0.35) % 1
		return Color3.fromHSV(h, 0.75, 1)
	end
	return Config.RARITY_COLORS[r] or Color3.new(1, 1, 1)
end

local function easeOutBack(x: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

-------------------------------------------------------------------------------------------------------------
-- little builders
-------------------------------------------------------------------------------------------------------------
local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "HatchPart"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A flat picture facing the camera (a thin invisible part with a decal on its camera side).
local function billboardPlane(parent: Instance, size: number, texture: string, color: Color3, transparency: number): (Part, Decal)
	local p = part(parent, Vector3.new(size, size, 0.05), color)
	p.Transparency = 1
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Back
	d.Texture = texture
	d.Color3 = color
	d.Transparency = transparency
	d.Parent = p
	return p, d
end

-- Rays behind the eggs: a camera-facing image on a BillboardGui, so it always faces you; the eggs still hide it.
local function rayBoard(parent: Instance, texture: string): (Part, ImageLabel)
	local p = part(parent, Vector3.one, Color3.new(1, 1, 1))
	p.Transparency = 1
	local g = Instance.new("BillboardGui")
	g.Adornee = p
	g.LightInfluence = 0
	g.Size = UDim2.fromOffset(0, 0)
	g.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = texture
	img.ImageTransparency = 1
	img.Parent = g
	return p, img
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- The egg model: the Blender one, or a plain smooth egg if it isn't there.
local function eggModel(eggId: string, color: Color3): Model
	local m = PartBuild.get(if eggId == "GoldenEgg" then "egg_golden" else "egg_garden")
	if m then
		return m
	end
	m = Instance.new("Model")
	for _, s in { { 1.5, 1.55, 1.55 }, { 1.32, 1.9, 1.9 } } do
		local p = part(m, Vector3.new(s[1] * 2, s[2] * 2, s[1] * 2), color, Enum.Material.SmoothPlastic, "AnimShell")
		p.CFrame = CFrame.new(0, s[3], 0)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	m.WorldPivot = CFrame.new()
	return m
end

-- the egg's outline at height y (egg studs, before scaling): same numbers as tools/blender/models/_eggkit.py
local function eggRadius(y: number): number
	local r1 = 1.5 * math.sqrt(math.max(0, 1 - ((y - 1.55) / 1.55) ^ 2))
	local r2 = 1.32 * math.sqrt(math.max(0, 1 - ((y - 1.9) / 1.9) ^ 2))
	return math.max(r1, r2)
end

local function surfacePoint(az: number, y: number, out: number): Vector3
	-- az 0 = the front (-Z, toward the camera)
	local r = eggRadius(y) + out
	return Vector3.new(math.sin(az) * r, y, -math.cos(az) * r)
end

-- crack paths (egg studs): two runs down the front, then the break line round it
local CRACKS = {
	{ { -0.15, 3.35 }, { 0.05, 3.0 }, { -0.2, 2.7 }, { 0.1, 2.4 }, { -0.05, 2.15 } },
	{ { 0.55, 3.0 }, { 0.75, 2.75 }, { 0.6, 2.45 }, { 0.85, 2.2 } },
	{ { -1.2, 2.1 }, { -0.9, 2.3 }, { -0.6, 2.05 }, { -0.3, 2.3 }, { 0, 2.05 }, { 0.3, 2.3 }, { 0.6, 2.05 }, { 0.9, 2.3 }, { 1.2, 2.1 } },
}

-------------------------------------------------------------------------------------------------------------
-- one egg on the stage
-------------------------------------------------------------------------------------------------------------
type Piece = { part: BasePart, rel: CFrame, mesh: SpecialMesh?, shell: boolean }
type Egg = {
	index: number,
	pet: any,
	rank: number,
	fresh: boolean,
	golden: boolean,
	scale: number,
	home: CFrame, -- the egg's resting base (bottom centre), facing the camera
	model: Model,
	pieces: { Piece },
	cracks: { Piece },
	crackStage: number,
	glow: PointLight,
	shellColor: Color3,
	shellMat: Enum.Material,
	fx: Part,
	burst: boolean,
	petModel: Model?,
	petPieces: { Piece },
	halo: Part?,
	haloDecal: Decal?,
	delay: number,
}

local function capture(model: Model, origin: CFrame): { Piece }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local mesh = d:FindFirstChildOfClass("SpecialMesh")
			table.insert(list, { part = d, rel = origin:ToObjectSpace(d.CFrame), mesh = mesh, shell = d.Name == "AnimShell" })
		end
	end
	return list
end

-- Place the egg: `cf` = its base, sx / sy = squash (x and z / y).
local function poseEgg(e: Egg, cf: CFrame, sx: number, sy: number)
	local k = Vector3.new(sx, sy, sx)
	for _, p in e.pieces do
		local pos = p.rel.Position * k
		p.part.CFrame = cf * CFrame.new(pos) * p.rel.Rotation
		if p.shell and p.mesh then
			p.mesh.Scale = k
		end
	end
	for _, p in e.cracks do
		p.part.CFrame = cf * CFrame.new(p.rel.Position * k) * p.rel.Rotation
	end
end

local function addCrack(e: Egg, stage: number, color: Color3)
	local path = CRACKS[stage]
	if not path then
		return
	end
	local s = e.scale
	for i = 1, #path - 1 do
		local a = surfacePoint(path[i][1], path[i][2], 0.03) * s
		local b = surfacePoint(path[i + 1][1], path[i + 1][2], 0.03) * s
		local seg = part(e.model, Vector3.new(0.1 * s, 0.1 * s, (b - a).Magnitude + 0.06 * s), color, Enum.Material.Neon, "Crack")
		seg.Transparency = 0.15
		table.insert(e.cracks, { part = seg, rel = CFrame.lookAt((a + b) / 2, b), shell = false })
	end
end

local function tintCracks(e: Egg, color: Color3)
	for _, c in e.cracks do
		c.part.Color = color
	end
	e.glow.Color = color
end

-------------------------------------------------------------------------------------------------------------
-- the stage: frozen camera, blurred world, rays, light
-------------------------------------------------------------------------------------------------------------
type Stage = {
	cam: Camera,
	camCF: CFrame,
	oldType: Enum.CameraType,
	hide: { Instance },
	signs: { BillboardGui },
	raysAt: CFrame,
	folder: Folder,
	rays: Part,
	raysDecal: ImageLabel,
	rays2: Part,
	rays2Decal: ImageLabel,
	dof: DepthOfFieldEffect,
	cc: ColorCorrectionEffect,
	gui: ScreenGui,
	shake: number,
	tier: number,
	color: Color3,
	eggs: { Egg },
	t: number,
	speed: number,
	revealed: boolean,
	closing: boolean,
}

local function stageAt(s: Stage, x: number, y: number, z: number): CFrame
	return s.camCF * CFrame.new(x, y, -z)
end

local function buildStage(): Stage
	local cam = workspace.CurrentCamera
	local folder = Instance.new("Folder")
	folder.Name = "HatchFx"
	folder.Parent = cam
	local s = {} :: Stage
	s.cam = cam
	s.camCF = cam.CFrame
	s.oldType = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	s.folder = folder
	-- the world behind stays as it is, just out of focus (depth of field keeps the eggs sharp)
	-- your own character would stand between the camera and the eggs: hide it while the hatch plays
	s.hide = {}
	-- world signs and name tags (e.g. your own VIP tag) would float over the eggs: switch them off meanwhile
	s.signs = {}
	for _, g in workspace:GetDescendants() do
		if g:IsA("BillboardGui") and g.Enabled then
			g.Enabled = false
			table.insert(s.signs, g)
		end
	end
	local char = Players.LocalPlayer.Character
	if char then
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(s.hide, d)
			end
		end
	end
	s.dof = Instance.new("DepthOfFieldEffect")
	s.dof.Name = "HatchDOF"
	s.dof.FocusDistance = DIST
	s.dof.InFocusRadius = 6
	s.dof.NearIntensity = 0
	s.dof.FarIntensity = 0
	s.dof.Parent = Lighting
	s.cc = Instance.new("ColorCorrectionEffect")
	s.cc.Name = "HatchGrade"
	s.cc.Parent = Lighting
	TweenService:Create(s.dof, TweenInfo.new(0.35), { FarIntensity = 0.75 }):Play()
	-- rays behind the eggs (hidden until a crack lights them)
	s.rays, s.raysDecal = rayBoard(folder, RAYS)
	s.rays2, s.rays2Decal = rayBoard(folder, TEX.VS_Starburst or RAYS)
	-- a soft key light so the eggs read well day or night
	local key = part(folder, Vector3.one, Color3.new(1, 1, 1), nil, "KeyLight")
	key.Transparency = 1
	key.CFrame = stageAt(s, 1, 0.5, DIST - 4)
	local l = Instance.new("PointLight")
	l.Brightness = 0.8
	l.Range = 7
	l.Color = Color3.fromRGB(255, 246, 230)
	l.Parent = key
	s.gui = Instance.new("ScreenGui")
	s.gui.Name = "HatchGui"
	s.gui.IgnoreGuiInset = true
	s.gui.DisplayOrder = 60
	s.gui.ResetOnSpawn = false
	s.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	s.shake = 0
	s.eggs = {}
	s.t = 0
	s.speed = 1
	s.revealed = false
	s.closing = false
	return s
end

-------------------------------------------------------------------------------------------------------------
-- the burst
-------------------------------------------------------------------------------------------------------------
local function shockwave(s: Stage, at: CFrame, color: Color3, size: number, duration: number)
	local fx = Instance.new("Model")
	fx.Name = "HatchRing"
	fx:SetAttribute("EffectDuration", NumberRange.new(duration, duration + 0.05))
	fx:SetAttribute("Decal_StartTransparency", 0.05)
	fx:SetAttribute("Decal_EndTransparency", 1)
	local a = billboardPlane(fx, 1.5, TEX.RingShock or TEX.RingThin or RAYS, color, 0.05)
	a.Name = "Start"
	a.CFrame = at
	local b = billboardPlane(fx, size, TEX.RingShock or TEX.RingThin or RAYS, color, 1)
	b.Name = "End"
	b.CFrame = at
	fx.Parent = ReplicatedStorage
	local ok = okForge and type(Forge) == "table" and Forge.Emit and pcall(Forge.Emit, fx)
	if not ok then
		-- no Forge: the same ring by hand
		local p = a:Clone()
		p.Parent = s.folder
		local d = p:FindFirstChildOfClass("Decal") :: Decal
		TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = b.Size }):Play()
		TweenService:Create(d, TweenInfo.new(duration), { Transparency = 1 }):Play()
		task.delay(duration + 0.05, p.Destroy, p)
	end
	task.delay(duration + 0.5, fx.Destroy, fx)
end

-- Shell shards: curved bits of the egg's shell that fly out, spin and fall (moved by hand, no physics).
local function shards(s: Stage, e: Egg, centre: CFrame)
	local n = math.floor(12 * FEW)
	local list = {}
	for i = 1, n do
		local w = (0.5 + math.random() * 0.5) * e.scale
		local p = part(s.folder, Vector3.new(w, w * 0.32, w * 0.8), e.shellColor, e.shellMat, "Shard")
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		local ang = (i / n) * math.pi * 2 + math.random() * 0.4
		local dir = centre:VectorToWorldSpace(Vector3.new(math.cos(ang), math.sin(ang) * 0.8 + 0.5, -0.4 - math.random() * 0.6))
		table.insert(list, {
			p = p,
			pos = centre.Position + dir * 0.6 * e.scale,
			vel = dir * (10 + math.random() * 8) * e.scale,
			rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14,
		})
	end
	local age = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		age += dt
		for _, b in list do
			b.vel += Vector3.new(0, -46 * e.scale, 0) * dt
			b.pos += b.vel * dt
			b.rot *= CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
			b.p.CFrame = CFrame.new(b.pos) * b.rot
			if age > 0.7 then
				b.p.Transparency = clamp01((age - 0.7) / 0.5)
			end
		end
		if age > 1.25 then
			conn:Disconnect()
			for _, b in list do
				b.p:Destroy()
			end
		end
	end)
end

local function sprays(e: Egg, color: Color3, tier: number)
	local att = Instance.new("Attachment")
	att.Parent = e.fx
	local grass = emitter(att, {
		Texture = FX.splinter or TEX.Spark,
		Color = ColorSequence.new(Color3.fromRGB(120, 210, 70), Color3.fromRGB(70, 150, 50)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45 * e.scale), NumberSequenceKeypoint.new(1, 0.3 * e.scale) }),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(10 * e.scale, 18 * e.scale),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -22 * e.scale, 0),
		Drag = 1.6,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-260, 260),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	})
	grass:Emit(math.floor((18 + tier * 4) * FEW))
	local leaves = grass:Clone()
	leaves.Color = ColorSequence.new(Color3.fromRGB(60, 140, 50), Color3.fromRGB(150, 200, 70))
	leaves.Size = NumberSequence.new(0.7 * e.scale)
	leaves.Acceleration = Vector3.new(0, -9 * e.scale, 0)
	leaves.Lifetime = NumberRange.new(1.6, 2.4)
	leaves.Parent = att
	leaves:Emit(math.floor((6 + tier * 2) * FEW))
	local stars = emitter(att, {
		Texture = TEX.Star4 or TEX.Spark or "rbxasset://textures/particles/sparkles_main.dds",
		Color = if tier >= RANK.Secret then RAINBOW else ColorSequence.new(Color3.new(1, 1, 1), color),
		LightEmission = 0.7,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 * e.scale), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(8 * e.scale, 16 * e.scale),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
	})
	stars:Emit(math.floor((10 + tier * 6) * FEW))
	if e.golden then
		local coins = emitter(att, {
			Texture = ICONS.coin or TEX.Dollar or TEX.Spark,
			Size = NumberSequence.new(0.6 * e.scale),
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(12 * e.scale, 20 * e.scale),
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -40 * e.scale, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-200, 200),
		})
		coins:Emit(math.floor(16 * FEW))
		local sparks = stars:Clone()
		sparks.Texture = TEX.Spark or sparks.Texture
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), GOLD)
		sparks.Parent = att
		sparks:Emit(math.floor(24 * FEW))
	end
end

local function flash(s: Stage, color: Color3, strength: number)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	f.BackgroundTransparency = 1 - strength
	f.ZIndex = 1
	f.Parent = s.gui
	TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.delay(0.5, f.Destroy, f)
end

local function sfx(id: string?, volume: number, pitch: number?)
	if not id or id == "" then
		return
	end
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Volume = volume
	snd.PlaybackSpeed = pitch or 1
	snd.Parent = game:GetService("SoundService")
	snd:Play()
	task.delay(6, snd.Destroy, snd)
end

-------------------------------------------------------------------------------------------------------------
-- the reveal: the critter jumps out, spins once and idles; banner under it
-------------------------------------------------------------------------------------------------------------
local function banner(s: Stage, e: Egg, screen: Vector2, k: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(320 * k, 120 * k)
	holder.Position = UDim2.fromOffset(screen.X, screen.Y)
	holder.ZIndex = 5
	holder.Parent = s.gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	local def = e.pet
	local color = rarityColor(def.rarity)
	local font = (Config.UI and Config.UI.font) or Enum.Font.FredokaOne
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 46 * k)
	name.Font = font
	name.Text = def.name
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.ZIndex = 6
	name.Parent = holder
	local ns = Instance.new("UIStroke")
	ns.Thickness = 3.5 * k
	ns.Color = Color3.fromRGB(30, 22, 18)
	ns.Parent = name
	-- the chunky rarity banner
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.new(0.5, 0, 0, 50 * k)
	plate.Size = UDim2.fromOffset(230 * k, 50 * k)
	plate.BackgroundColor3 = if def.rarity == "Secret" then Color3.new(1, 1, 1) else color
	plate.ZIndex = 6
	plate.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14 * k)
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4 * k
	stroke.Color = Color3.fromRGB(30, 22, 18)
	stroke.Parent = plate
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	if def.rarity == "Secret" then
		grad.Color = RAINBOW
		grad.Rotation = 0
	else
		grad.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.15))
	end
	grad.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Font = font
	label.Text = string.upper(def.rarity)
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 7
	label.Parent = plate
	local ls = Instance.new("UIStroke")
	ls.Thickness = 3 * k
	ls.Color = Color3.fromRGB(30, 22, 18)
	ls.Parent = label
	if e.fresh then
		local new = Instance.new("TextLabel")
		new.AnchorPoint = Vector2.new(0.5, 0.5)
		new.Position = UDim2.new(1, -6 * k, 0, 4 * k)
		new.Size = UDim2.fromOffset(78 * k, 30 * k)
		new.Rotation = 12
		new.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
		new.Font = font
		new.Text = "NEW!"
		new.TextScaled = true
		new.TextColor3 = Color3.new(1, 1, 1)
		new.ZIndex = 8
		new.Parent = plate
		local nc = Instance.new("UICorner")
		nc.CornerRadius = UDim.new(1, 0)
		nc.Parent = new
		local nst = Instance.new("UIStroke")
		nst.Thickness = 2.5 * k
		nst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		nst.Color = Color3.new(1, 1, 1)
		nst.Parent = new
		TweenService:Create(new, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 4 }):Play()
	end
	-- pop in; Legendary+ slams in from big
	local big = e.rank >= BIG
	scale.Scale = if big then 2.2 else 0
	TweenService:Create(scale, TweenInfo.new(if big then 0.28 else 0.38, if big then Enum.EasingStyle.Quad else Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if def.rarity == "Secret" then
		task.spawn(function()
			while holder.Parent do
				grad.Offset = Vector2.new(math.sin(os.clock() * 1.5) * 0.4, 0)
				task.wait()
			end
		end)
	end
end

local function revealPet(s: Stage, e: Egg)
	local def = e.pet
	local m = PetFollow.build(def.look)
	local bsCF, bsSize = m:GetBoundingBox()
	local want = 3.6 * e.scale * (1 + (e.rank - 1) * 0.06)
	m:ScaleTo(want / math.max(bsSize.X, bsSize.Y, bsSize.Z, 0.1))
	bsCF = m:GetBoundingBox()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	m.Parent = s.folder
	e.petModel = m
	e.petPieces = capture(m, bsCF)
	-- soft glow behind it in its colour
	local color = rarityColor(def.rarity)
	local halo, hd = billboardPlane(s.folder, 7 * e.scale, TEX.Glow or RAYS, color, 0.62)
	e.halo, e.haloDecal = halo, hd
end

-------------------------------------------------------------------------------------------------------------
-- per-frame
-------------------------------------------------------------------------------------------------------------
local function updateEgg(s: Stage, e: Egg, t: number)
	if e.burst then
		return
	end
	local h = e.home
	local tl = t - e.delay
	local up = Vector3.zero
	local sx, sy = 1, 1
	local rot = CFrame.identity
	if tl < T.land then
		local a = clamp01(tl / T.land)
		up = Vector3.new(0, (1 - a * a) * 6 * e.scale, 0)
		sy, sx = 1.08, 0.94 -- stretched while falling
	elseif tl < T.wobble then
		-- squash on landing, then settle with a little overshoot
		local a = clamp01((tl - T.land) / (T.wobble - T.land))
		local q = math.sin(a * math.pi) * (1 - a * 0.4)
		sy, sx = 1 - 0.24 * q + 0.05 * math.sin(a * math.pi * 2), 1 + 0.16 * q
	elseif tl < T.swell then
		-- the kicks: each one a quick rock that dies away, with a hop and a squash as it starts
		local w = tl - T.wobble
		local a = clamp01(w / (T.swell - T.wobble))
		local roll, pitch, lift, squash = 0, 0, 0, 0
		for i, k in KICKS do
			local d = w - k[1]
			if d >= 0 and d < 0.9 then
				local side = if i % 2 == 0 then -1 else 1
				local decay = math.exp(-d * 6.5)
				roll += math.sin(d * math.pi * 2 * 4.2) * decay * k[2] * math.rad(22) * side
				pitch += math.sin(d * math.pi * 2 * 2.6) * decay * k[2] * math.rad(6)
				if d < 0.16 then
					lift += math.sin(d / 0.16 * math.pi) * k[2] * 0.3
				end
				squash += math.exp(-d * 14) * k[2]
			end
		end
		-- between kicks only a faint tremble, which grows as it gets close
		local tremble = math.sin(tl * 70) * math.rad(0.6 + 1.4 * a)
		rot = CFrame.Angles(pitch, 0, roll + tremble)
		up = Vector3.new(0, lift * e.scale, 0)
		sy = 1 - 0.08 * squash + 0.04 * lift
		sx = 1 + 0.05 * squash
	else
		-- swell fast, then hold almost still for a beat: the calm right before the pop makes the pop land
		local a = clamp01((tl - T.swell) / 0.09)
		local e2 = 1 - (1 - a) ^ 3
		sx, sy = 1 + 0.12 * e2, 1 + 0.1 * e2
		rot = CFrame.Angles(0, 0, math.sin(tl * 90) * math.rad(0.8))
	end
	poseEgg(e, h * CFrame.new(up) * rot, sx, sy)
end

local function updatePet(s: Stage, e: Egg, t: number)
	if not e.petModel then
		return
	end
	local tl = math.max(0, t - T.burst - e.delay)
	-- the pop, timed like a jump: shoot up fast, hang at the top, drop, squash on landing, settle
	local POP = { up = 0.16, hang = 0.3, down = 0.14, land = 0.3 }
	local top = 2.6 * e.scale
	local hop, sy = 0, 1
	local landAt = POP.up + POP.hang + POP.down
	local done = landAt + POP.land
	if tl < POP.up then
		local a = tl / POP.up
		hop = top * (1 - (1 - a) ^ 2) -- fast out, easing into the top
		sy = 1 + 0.18 * (1 - a) -- stretched on the way up
	elseif tl < POP.up + POP.hang then
		local a = (tl - POP.up) / POP.hang
		hop = top + math.sin(a * math.pi) * 0.25 * e.scale -- floats a little at the top
	elseif tl < landAt then
		local a = (tl - POP.up - POP.hang) / POP.down
		hop = top * (1 - a * a) -- falls faster and faster
		sy = 1 + 0.12 * a
	elseif tl < done then
		local a = (tl - landAt) / POP.land
		sy = 1 - 0.22 * math.exp(-a * 5) * math.cos(a * math.pi * 2.2) -- squash, bounce back, settle
	end
	-- grows in fast with a small overshoot; turns once, done by the top so it faces you while it hangs
	local grow = easeOutBack(clamp01(tl / (POP.up + 0.12)))
	local spin = (1 - (1 - clamp01(tl / (POP.up + 0.14))) ^ 3) * math.pi * 2
	local after = tl - done
	local idle = if after > 0 then math.sin(after * 2.4) * 0.18 * e.scale * math.min(1, after * 2) else 0
	local sway = if after > 0 then math.sin(after * 1.3) * math.rad(10) * math.min(1, after) else 0
	local base = e.home * CFrame.new(0, 1.7 * e.scale + hop + idle, 0) * CFrame.Angles(0, spin + sway, 0)
	local k = math.max(grow, 0.05)
	local scaleV = Vector3.new(k / math.sqrt(sy), k * sy, k / math.sqrt(sy))
	local a = clamp01(tl / done)
	for _, p in e.petPieces do
		p.part.CFrame = base * CFrame.new(p.rel.Position * scaleV) * p.rel.Rotation
		if a < 1 and not p.part:GetAttribute("Size0") then
			p.part:SetAttribute("Size0", p.part.Size)
		end
		local s0 = p.part:GetAttribute("Size0")
		if typeof(s0) == "Vector3" then
			p.part.Size = s0 * k
		end
	end
	if e.halo and e.haloDecal then
		local pulse = 1 + math.sin(t * 3) * 0.06
		local sz = 7 * e.scale * pulse * math.min(1, a * 1.5)
		e.halo.Size = Vector3.new(sz, sz, 0.05)
		e.halo.CFrame = s.camCF * CFrame.new((s.camCF:PointToObjectSpace(e.home.Position + Vector3.new(0, 1.7 * e.scale, 0))) + Vector3.new(0, 0, -1.5))
		if e.rank >= RANK.Secret then
			e.haloDecal.Color3 = rarityColor("Secret", t)
		end
	end
end

local function updateStage(s: Stage, dt: number)
	local t = s.t
	-- rays: fade in with the cracks, spin, bigger for rarer
	local glowA = clamp01((t - T.crack[1]) / 1.2)
	local raysOn = if s.revealed then 1 else glowA * 0.5
	local size = 22 + s.tier * 3 + (if s.revealed and s.tier >= BIG then 14 else 0)
	local board = s.rays:FindFirstChildOfClass("BillboardGui") :: BillboardGui
	board.Size = UDim2.new(size, 0, size, 0)
	s.rays.CFrame = s.raysAt
	s.raysDecal.Rotation = math.deg(t * (0.25 + s.tier * 0.05))
	s.raysDecal.ImageTransparency = 1 - raysOn * math.min(0.9, 0.35 + s.tier * 0.08)
	local board2 = s.rays2:FindFirstChildOfClass("BillboardGui") :: BillboardGui
	board2.Size = UDim2.new(size * 0.7, 0, size * 0.7, 0)
	s.rays2.CFrame = s.raysAt * CFrame.new(0, 0, -0.2)
	s.rays2Decal.Rotation = -math.deg(t * 0.4)
	s.rays2Decal.ImageTransparency = 1 - raysOn * (0.3 + s.tier * 0.05)
	local col = if s.tier >= RANK.Secret then rarityColor("Secret", t) else s.color
	s.raysDecal.ImageColor3 = col
	s.rays2Decal.ImageColor3 = col:Lerp(Color3.new(1, 1, 1), 0.4)
	-- camera shake (decays)
	s.shake = math.max(0, s.shake - dt * 2.6)
	local j = s.shake * s.shake
	s.cam.CFrame = s.camCF * CFrame.Angles((math.random() - 0.5) * 0.03 * j, (math.random() - 0.5) * 0.03 * j, (math.random() - 0.5) * 0.02 * j)
end

-------------------------------------------------------------------------------------------------------------
-- main
-------------------------------------------------------------------------------------------------------------
local function layout(n: number): { { x: number, y: number, scale: number } }
	local out = {}
	local rows = if n > 5 then 2 else 1
	local perRow = math.ceil(n / rows)
	local scale = if n == 1 then 1.5 elseif rows == 1 then 0.85 else 0.68
	local gap = if n == 1 then 0 elseif rows == 1 then 4.6 else 3.7
	for i = 1, n do
		local row = (i - 1) // perRow
		local col = (i - 1) % perRow
		local inRow = math.min(perRow, n - row * perRow)
		local x = (col - (inRow - 1) / 2) * gap
		local y = if rows == 1 then -2.4 * scale else (if row == 0 then 0.6 else -4.0)
		table.insert(out, { x = x, y = y, scale = scale })
	end
	return out
end

local function makeEggs(s: Stage, eggDef, ids: { string }, fresh: { boolean }?)
	local spots = layout(#ids)
	for i, id in ids do
		local def = Config.pet(id)
		if not def then
			continue
		end
		local sp = spots[i]
		local golden = eggDef.id == "GoldenEgg"
		local m = eggModel(eggDef.id, eggDef.color)
		m:ScaleTo(sp.scale)
		m.Parent = s.folder
		local home = stageAt(s, sp.x, sp.y, DIST) * CFrame.Angles(0, math.pi, 0)
		local shellColor, shellMat = eggDef.color, Enum.Material.SmoothPlastic
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "AnimShell" then
				shellColor, shellMat = d.Color, d.Material
				break
			end
		end
		local fxPart = part(s.folder, Vector3.one, Color3.new(1, 1, 1), nil, "EggFx")
		fxPart.Transparency = 1
		fxPart.CFrame = home * CFrame.new(0, 1.9 * sp.scale, 0)
		local glow = Instance.new("PointLight")
		glow.Brightness = 0
		glow.Range = 8 * sp.scale
		glow.Parent = fxPart
		local e: Egg = {
			index = i,
			pet = def,
			rank = RANK[def.rarity] or 1,
			fresh = fresh ~= nil and fresh[i] == true,
			golden = golden,
			scale = sp.scale,
			home = home,
			model = m,
			pieces = capture(m, m:GetPivot()),
			cracks = {},
			crackStage = 0,
			glow = glow,
			shellColor = shellColor,
			shellMat = shellMat,
			fx = fxPart,
			burst = false,
			petModel = nil,
			petPieces = {},
			halo = nil,
			haloDecal = nil,
			delay = (i - 1) * 0.05,
		}
		poseEgg(e, home * CFrame.new(0, 6 * sp.scale, 0), 1, 1)
		table.insert(s.eggs, e)
	end
end

-- the colour a crack shows at `stage`: the real one, except Legendary+ starts as an Epic fake-out
local function crackColor(e: Egg, stage: number, t: number): Color3
	if e.rank >= BIG and stage < 3 then
		return Config.RARITY_COLORS.Epic
	end
	return rarityColor(e.pet.rarity, t)
end

local function doCrack(s: Stage, stage: number)
	local pitch = 0.9 + stage * 0.15
	Sound.playAt("chip", pitch, 0.9)
	for _, e in s.eggs do
		local c = crackColor(e, stage, s.t)
		addCrack(e, stage, c)
		if stage == 3 and e.rank >= BIG then
			-- fake-out: the purple glow jumps to the real colour with a jolt
			tintCracks(e, c)
			s.shake = math.max(s.shake, 0.7)
		end
		e.glow.Color = c
		e.glow.Brightness = stage * 0.7
	end
	if stage == 3 and s.tier >= BIG then
		Sound.play("slam")
		flash(s, s.color, 0.35)
	end
end

local function doBurst(s: Stage)
	local tier = s.tier
	Sound.play("burst")
	if tier >= BIG then
		local boom = okAssets and type(Assets) == "table" and Assets.Sfx and Assets.Sfx.Boom
		sfx(if type(boom) == "string" then boom elseif type(boom) == "number" then "rbxassetid://" .. boom else nil, 0.7)
	end
	for _, e in s.eggs do
		e.burst = true
		local centre = e.home * CFrame.new(0, 1.9 * e.scale, 0)
		local color = rarityColor(e.pet.rarity, s.t)
		shards(s, e, centre)
		sprays(e, color, e.rank)
		local ringAt = s.camCF * CFrame.new(s.camCF:PointToObjectSpace(centre.Position))
		shockwave(s, ringAt, if e.golden then GOLD else color, (10 + e.rank * 2) * e.scale, 0.55)
		if e.rank >= BIG then
			task.delay(0.12, shockwave, s, ringAt, GOLD:Lerp(color, 0.4), (18 + e.rank * 3) * e.scale, 0.8)
		end
		if e.rank >= RANK.Secret then
			for k, c in { Color3.fromRGB(255, 80, 90), Color3.fromRGB(80, 230, 120), Color3.fromRGB(70, 160, 255) } do
				task.delay(0.1 + k * 0.1, shockwave, s, ringAt, c, 26 * e.scale, 0.9)
			end
		end
		e.model:Destroy()
		e.glow.Brightness = 2
		TweenService:Create(e.glow, TweenInfo.new(1.2), { Brightness = 0.25 }):Play()
		revealPet(s, e)
	end
	s.shake = 0.6 + tier * 0.12
	flash(s, s.color, if tier >= BIG then 0.45 else 0.25)
	-- the sting, by the best rarity in the batch
	if tier >= BIG then
		Sound.play("victory")
		Sound.play("rareChime")
		Confetti.burst(math.floor(70 * FEW))
	elseif tier >= RANK.Epic then
		Sound.play("reveal")
		Confetti.burst(math.floor(35 * FEW))
	elseif tier >= RANK.Rare then
		Sound.play("reveal")
	else
		Sound.play("upgrade")
	end
	s.revealed = true
	-- the banners, once the critters have landed
	task.delay(0.35, function()
		if s.closing then
			return
		end
		local vp = s.cam.ViewportSize
		local k = (vp.Y / 720) * (if #s.eggs == 1 then 1 elseif #s.eggs <= 5 then 0.62 else 0.48)
		for _, e in s.eggs do
			local below = e.home.Position + Vector3.new(0, -0.3 * e.scale, 0)
			local sp = s.cam:WorldToViewportPoint(below)
			banner(s, e, Vector2.new(sp.X, sp.Y + (if #s.eggs > 5 and e.index <= 5 then -6 else 6) * k), k)
		end
	end)
end

local function close(s: Stage, onDone: (() -> ())?)
	if s.closing then
		return
	end
	s.closing = true
	for _, d in s.hide do
		(d :: any).LocalTransparencyModifier = 0
	end
	for _, g in s.signs do
		g.Enabled = true
	end
	TweenService:Create(s.dof, TweenInfo.new(0.3), { FarIntensity = 0 }):Play()
	TweenService:Create(s.cc, TweenInfo.new(0.3), { Brightness = 0, Saturation = 0, Contrast = 0 }):Play()
	for _, g in s.gui:GetChildren() do
		if g:IsA("GuiObject") then
			local sc = g:FindFirstChildOfClass("UIScale")
			if sc then
				TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
			end
		end
	end
	task.delay(0.3, function()
		s.folder:Destroy()
		s.dof:Destroy()
		s.cc:Destroy()
		s.gui:Destroy()
		s.cam.CameraType = s.oldType
		s.cam.CFrame = s.camCF
		HatchFx.busy = false
		if onDone then
			onDone()
		end
	end)
end

-- The rays sit just behind the eggs, facing the camera.
local RAYS_DEPTH = DIST + 1.5

-- Play the hatch. `fresh[i]` = pet i is new to this player (NEW! badge). `onDone` runs after it closes.
function HatchFx.play(eggId: string, ids: { string }, fresh: { boolean }?, onDone: (() -> ())?)
	local eggDef = Config.egg(eggId)
	if not eggDef or #ids == 0 then
		if onDone then
			onDone()
		end
		return
	end
	HatchFx.busy = true
	local s = buildStage()
	makeEggs(s, eggDef, ids, fresh)
	local best, bestEgg = 0, nil
	for _, e in s.eggs do
		if e.rank > best then
			best, bestEgg = e.rank, e
		end
	end
	s.tier = best
	s.raysAt = stageAt(s, 0, 0.4, RAYS_DEPTH)
	s.color = if bestEgg then rarityColor(bestEgg.pet.rarity) else Color3.new(1, 1, 1)
	if eggDef.id == "GoldenEgg" and best < BIG then
		s.color = GOLD
	end
	local secret = best >= RANK.Secret
	-- Secret: everything waits a beat longer in the dark before the burst
	local hold = if secret then 0.9 elseif best >= BIG then 0.3 else 0
	local burstAt = T.burst + hold
	local clickAt = T.click + hold + (if best >= BIG then 0.6 else 0)
	local stage, burst, ticks = 0, false, 0
	local conn, input
	-- click: skip ahead (only without a Legendary+ inside), or close once revealed
	-- (a gamepad's A button works too: the HUD is hidden during the hatch, so there's nothing else to press)
	input = UserInputService.InputBegan:Connect(function(io)
		local pad = io.UserInputType == Enum.UserInputType.Gamepad1 and io.KeyCode == Enum.KeyCode.ButtonA
		if io.UserInputType ~= Enum.UserInputType.MouseButton1 and io.UserInputType ~= Enum.UserInputType.Touch and not pad then
			return
		end
		if s.t >= clickAt then
			conn:Disconnect()
			input:Disconnect()
			close(s, onDone)
		elseif not burst and best < BIG then
			s.speed = 5
		end
	end)
	conn = RunService.RenderStepped:Connect(function(dt)
		s.t += dt * s.speed * HatchFx.timeScale
		if not s.closing then
			for _, d in s.hide do
				(d :: any).LocalTransparencyModifier = 1
			end
		end
		local t = s.t
		-- a tick on every kick, higher and louder as they get harder
		local kick = KICKS[ticks + 1]
		if kick and t - T.wobble >= kick[1] then
			ticks += 1
			Sound.playAt("click", 0.8 + kick[2] * 0.9, 0.45 + kick[2] * 0.45)
		end
		while stage < 3 and t >= T.crack[stage + 1] do
			stage += 1
			doCrack(s, stage)
		end
		if secret and t > T.swell - 0.4 and not burst then
			-- the world dims for the Secret
			s.cc.Brightness = math.max(-0.35, s.cc.Brightness - dt * 0.4)
		end
		if not burst then
			for _, e in s.eggs do
				-- the hold (Legendary+ / Secret) keeps it trembling at full swell
				updateEgg(s, e, math.min(t, T.burst - 0.02))
				if t > T.burst - 0.02 and t < burstAt then
					local jit = math.rad(4) * math.sin(t * 90)
					poseEgg(e, e.home * CFrame.Angles(0, 0, jit), 1.12, 1.1)
				end
				if secret and stage >= 3 then
					tintCracks(e, rarityColor(e.pet.rarity, t))
				end
			end
		end
		if not burst and t >= burstAt then
			burst = true
			s.speed = 1
			doBurst(s)
			if secret then
				TweenService:Create(s.cc, TweenInfo.new(1.4), { Brightness = 0, Saturation = 0.15 }):Play()
			end
		end
		if burst then
			for _, e in s.eggs do
				updatePet(s, e, t - (burstAt - T.burst))
			end
		end
		updateStage(s, dt)
	end)
end

return HatchFx
