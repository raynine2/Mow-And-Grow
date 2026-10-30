-- Installs BossOmen (git's exact text, 21473 1554448062) into game.StarterPlayer.StarterPlayerScripts.MowALawnClient. Run in Edit mode.
local src = [======[
-- BossOmen (30 Oct; owner: "make better fx with boss spawning to make it feel more scary etc use forge gui"): the
-- dread when a boss wakes and the hit when it roars, on top of client/BossCine's camera work and BossFx's cards.
--   BossOmen.awake(d)   a boss woke (Fx bossReady; d.z, d.pos = its summon pad, d.name): the colour drains and the
--                       light goes red, the screen's edges bleed dark with glowing veins, a heartbeat thumps twice, a
--                       huge thorn-lidded eye opens over everything, stares and snaps shut, then the warning banner
--                       slams in (BOSS AWAKE / the name / "stand on the pad"). On the pad a summoning circle of thorns
--                       turns under a crackling dark beam with smoke and sparks rising. True when it played (BossCine
--                       then skips its old beam and card).
--   BossOmen.roar(z, short?)  the roar in the intro cutscene: anime impact frames (white speed lines on black, red
--                       ones, a white flash) and a dark pulse at the screen's edges.
--   BossOmen.clear()    the fight starts: the circle and the beam go.
-- Pictures (shared/IconIds): omen_eye, omen_banner, omen_ring, omen_beam made with ForgeGUI; omen_vignette and
-- omen_lines drawn by tools/omen_textures.py. Sounds: licensed library audio only (Config.FILM_SOUNDS: APM and Pro
-- Sound Effects). Client-only and cosmetic: every step is pcall'd, fewer particles in Potato Mode and on phones.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local BossOmen = {}
local player = Players.LocalPlayer

local FONT = (Config.UI and Config.UI.font) or Enum.Font.FredokaOne
local BLOOD = Color3.fromRGB(220, 24, 48)
local EMBER = Color3.fromRGB(255, 86, 110)

local function icon(key: string): string?
	local id = Config.ICONS and Config.ICONS[key]
	return if id and id ~= "" then id else nil
end

local function particleId(key: string): string
	local ok, ids = pcall(function()
		return require(ReplicatedStorage.MowALawn:WaitForChild("BossFxIds", 2)) :: any
	end)
	return if ok and ids and ids[key] then ids[key] else ""
end

-- 1 on a PC, less in Potato Mode and on phones
local function budget(): number
	local ok, k = pcall(function()
		local Potato = require(script.Parent:WaitForChild("Potato", 2)) :: any
		if Potato and Potato.on then
			return 0.35
		end
		local PhonePerf = require(script.Parent:WaitForChild("PhonePerf", 2)) :: any
		if PhonePerf and PhonePerf.on then
			return 0.55
		end
		return 1
	end)
	return if ok and type(k) == "number" then k else 1
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function try(label: string, fn: (...any) -> (), ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[BossOmen] " .. label .. ": " .. tostring(err))
	end
end

-- a licensed film sound (Config.FILM_SOUNDS), faded out after `stopAfter` seconds when given
local function sfx(key: string, vol: number?, speed: number?, stopAfter: number?)
	local defs = (Config :: any).FILM_SOUNDS
	local def = defs and defs[key]
	if not def or not def.id or def.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Omen_" .. key
	s.SoundId = def.id
	s.Volume = (def.volume or 0.5) * (vol or 1)
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	if stopAfter then
		task.delay(math.max(0, stopAfter - 0.35), function()
			if s.Parent then
				tween(s, 0.35, { Volume = 0 })
			end
		end)
		Debris:AddItem(s, stopAfter + 0.1)
	else
		Debris:AddItem(s, (def.len or 8) + 0.5)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the screens
-------------------------------------------------------------------------------------------------------------
local function screen(name: string, order: number): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = order
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = player:WaitForChild("PlayerGui")
	return g
end
local dread = screen("BossOmen", 8) -- over the HUD and BossFx's cards (7)
local impactGui = screen("BossOmenImpact", 60) -- the impact frames cover everything for a blink

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

-- the size the banner is drawn at: 1 on a 1280 x 720 screen
local function uiScale(): number
	local vp = viewport()
	return math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.25)
end

local function label(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3, strokeT: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Font = FONT
	l.Text = t
	l.TextScaled = true
	l.TextColor3 = color
	l:SetAttribute("KeepInk", true) -- (client/TextStyle: keep our colours)
	local s = Instance.new("UIStroke")
	s.Thickness = strokeT
	s.Color = Color3.fromRGB(16, 2, 8)
	s.Parent = l
	l.Parent = parent
	return l
end

local function fadeAll(root: Instance, time: number)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, time, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, time, { Transparency = 1 })
		elseif d:IsA("ImageLabel") then
			tween(d, time, { ImageTransparency = 1 })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			tween(d, time, { BackgroundTransparency = 1 })
		end
	end
	if root:IsA("ImageLabel") then
		tween(root, time, { ImageTransparency = 1 })
	end
	Debris:AddItem(root, time + 0.1)
end

local token = 0

-- the colour drains, the light goes red; back after `hold`
local function grade(hold: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local old = cam:FindFirstChild("BossOmenGrade")
	if old then
		old:Destroy()
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BossOmenGrade"
	cc.Parent = cam
	tween(cc, 0.5, { Saturation = -0.55, Contrast = 0.18, Brightness = -0.06, TintColor = Color3.fromRGB(255, 196, 200) })
	task.delay(hold, function()
		if cc.Parent then
			tween(cc, 1.4, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, Enum.EasingStyle.Sine)
			Debris:AddItem(cc, 1.5)
		end
	end)
end

-- the screen's edges bleed dark with veins; a heartbeat squeezes them in twice
local function vignette(hold: number): ImageLabel?
	local id = icon("omen_vignette")
	if not id then
		return nil
	end
	local v = Instance.new("ImageLabel")
	v.Name = "Vignette"
	v.BackgroundTransparency = 1
	v.Image = id
	v.ScaleType = Enum.ScaleType.Stretch
	v.ImageTransparency = 1
	v.AnchorPoint = Vector2.new(0.5, 0.5)
	v.Position = UDim2.fromScale(0.5, 0.5)
	v.Size = UDim2.fromScale(1.12, 1.12)
	v.Parent = dread
	for i, at in { 0, 0.55 } do
		task.delay(at, function()
			if not v.Parent then
				return
			end
			v.Size = UDim2.fromScale(1, 1)
			v.ImageTransparency = if i == 1 then 0.05 else 0
			tween(v, 0.42, { Size = UDim2.fromScale(1.05, 1.05), ImageTransparency = 0.28 }, Enum.EasingStyle.Quad)
		end)
	end
	task.delay(hold, function()
		if v.Parent then
			tween(v, 1.3, { ImageTransparency = 1, Size = UDim2.fromScale(1.15, 1.15) }, Enum.EasingStyle.Sine)
			Debris:AddItem(v, 1.4)
		end
	end)
	return v
end

-- the eye: opens from a slit in the middle of the screen, stares (a creep forward, two darts), snaps shut
local function eye(openAt: number, shutAt: number, my: number)
	local id = icon("omen_eye")
	if not id then
		return
	end
	local vp = viewport()
	local h = math.floor(vp.Y * 0.5)
	local w = math.floor(h * 1024 / 792)
	local holder = Instance.new("Frame")
	holder.Name = "Eye"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromOffset(w, h)
	holder.Parent = dread
	local glowId = icon("glow_soft")
	local glow: ImageLabel? = nil
	if glowId then
		glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.Image = glowId
		glow.ImageColor3 = BLOOD
		glow.ImageTransparency = 1
		glow.ScaleType = Enum.ScaleType.Stretch
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromScale(1.9, 1.5)
		glow.Parent = holder
	end
	-- the lid: a clipping frame that grows from a slit to the full eye
	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.BackgroundTransparency = 1
	lid.ClipsDescendants = true
	lid.AnchorPoint = Vector2.new(0.5, 0.5)
	lid.Position = UDim2.fromScale(0.5, 0.5)
	lid.Size = UDim2.fromOffset(w, 0)
	lid.Parent = holder
	local img = Instance.new("ImageLabel")
	img.Name = "Iris"
	img.BackgroundTransparency = 1
	img.Image = id
	img.ImageTransparency = 0.12
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromOffset(w, h)
	img.Parent = lid
	local sc = Instance.new("UIScale")
	sc.Scale = 0.86
	sc.Parent = holder
	task.delay(openAt, function()
		if my ~= token or not holder.Parent then
			return
		end
		sfx("growl", 1, 0.8)
		tween(lid, 0.32, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Quart)
		if glow then
			tween(glow, 0.5, { ImageTransparency = 0.35 })
		end
		tween(sc, shutAt - openAt, { Scale = 1.06 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		-- it looks about: two quick darts, then straight at you
		for i, dx in { -0.035, 0.03, 0 } do
			task.delay(0.45 + i * 0.32, function()
				if img.Parent then
					tween(img, 0.09, { Position = UDim2.fromScale(0.5 + dx, 0.5) }, Enum.EasingStyle.Quad)
				end
			end)
		end
	end)
	task.delay(shutAt, function()
		if not holder.Parent then
			return
		end
		tween(lid, 0.09, { Size = UDim2.fromOffset(w, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if glow then
			tween(glow, 0.25, { ImageTransparency = 1 })
		end
		Debris:AddItem(holder, 0.4)
	end)
end

-- BOSS AWAKE on the thorned banner, slammed in and shaken, gone after `hold`
local function banner(name: string, hold: number, my: number)
	local id = icon("omen_banner")
	local root = Instance.new("Frame")
	root.Name = "Banner"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.27)
	root.Size = UDim2.fromOffset(780, 250)
	root.Parent = dread
	local sc = Instance.new("UIScale")
	sc.Scale = uiScale() * 2.4
	sc.Parent = root
	local plate = Instance.new("ImageLabel")
	plate.Name = "Plate"
	plate.BackgroundTransparency = 1
	plate.Image = id or ""
	plate.ScaleType = Enum.ScaleType.Fit
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromOffset(780, 242)
	plate.ImageTransparency = 0.3
	plate.Parent = root
	tween(plate, 0.2, { ImageTransparency = 0 })
	local kicker = label(root, "BOSS AWAKE", UDim2.fromOffset(300, 34), UDim2.fromScale(0.5, 0.25), EMBER, 3)
	local nameL = label(root, string.upper(name), UDim2.fromOffset(560, 76), UDim2.fromScale(0.5, 0.53), Color3.new(1, 1, 1), 5)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 226, 230)),
		ColorSequenceKeypoint.new(0.56, Color3.fromRGB(255, 120, 136)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 60)),
	})
	g.Parent = nameL
	local sub = label(root, "Stand on the glowing pad in its arena to fight!", UDim2.fromOffset(620, 28), UDim2.new(0.5, 0, 1, 14), Color3.fromRGB(255, 220, 226), 2.5)
	sub.TextTransparency = 1
	tween(sub, 0.4, { TextTransparency = 0 })
	-- slam: big and see-through down to size, then a shake that dies out
	tween(sc, 0.26, { Scale = uiScale() }, Enum.EasingStyle.Back)
	kicker.Rotation = -3
	tween(kicker, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back)
	task.delay(0.24, function()
		local start = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local left = 1 - (os.clock() - start) / 0.5
			if left <= 0 or not root.Parent then
				conn:Disconnect()
				if root.Parent then
					root.Position = UDim2.fromScale(0.5, 0.27)
				end
				return
			end
			local p = 9 * left
			root.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * p, 0.27, math.random(-100, 100) / 100 * p)
		end)
	end)
	-- the kicker breathes red while it's up
	task.spawn(function()
		while root.Parent and my == token do
			tween(kicker, 0.45, { TextColor3 = BLOOD }, Enum.EasingStyle.Sine)
			task.wait(0.45)
			if not root.Parent then
				break
			end
			tween(kicker, 0.45, { TextColor3 = EMBER }, Enum.EasingStyle.Sine)
			task.wait(0.45)
		end
	end)
	task.delay(hold, function()
		if root.Parent then
			tween(sc, 0.35, { Scale = uiScale() * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			fadeAll(root, 0.35)
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the circle and the beam on the summon pad
-------------------------------------------------------------------------------------------------------------
local pad: Model? = nil

function BossOmen.clear()
	if pad then
		local m = pad
		pad = nil
		for _, d in m:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			elseif d:IsA("Beam") then
				tween(d, 0.4, { Width0 = 0, Width1 = 0 } :: any)
			elseif d:IsA("ImageLabel") then
				tween(d, 0.5, { ImageTransparency = 1 })
			end
		end
		Debris:AddItem(m, 2.5)
	end
end

local function groundAt(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {}
	if player.Character then
		table.insert(ex, player.Character)
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else pos
end

local function emitter(parent: Instance, tex: string, color: ColorSequence, rate: number, size: NumberSequence, speed: NumberRange, life: NumberRange, light: number)
	if tex == "" then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex
	e.Color = color
	e.Rate = rate
	e.Size = size
	e.Speed = speed
	e.Lifetime = life
	e.LightEmission = light
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Parent = parent
end

local function summon(pos: Vector3, tint: Color3)
	BossOmen.clear()
	local k = budget()
	local ground = groundAt(pos)
	local m = Instance.new("Model")
	m.Name = "BossOmenPad"
	pad = m -- (the circle's loops run while this is the pad)
	-- the circle: an unlit picture on the ground, turning, with a red glow under it
	local disc = Instance.new("Part")
	disc.Name = "Circle"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Transparency = 1
	disc.Size = Vector3.new(26, 0.2, 26)
	disc.CFrame = CFrame.new(ground + Vector3.new(0, 0.35, 0))
	disc.Parent = m
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.LightInfluence = 0
	sg.Brightness = 2.2
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(512, 512)
	sg.Parent = disc
	local glowId = icon("glow_soft")
	if glowId then
		local under = Instance.new("ImageLabel")
		under.Name = "Glow"
		under.BackgroundTransparency = 1
		under.Image = glowId
		under.ImageColor3 = BLOOD
		under.ImageTransparency = 0.3
		under.Size = UDim2.fromScale(1, 1)
		under.Parent = sg
		task.spawn(function()
			while under.Parent and pad == m do
				tween(under, 0.6, { ImageTransparency = 0.05 }, Enum.EasingStyle.Sine)
				task.wait(0.6)
				tween(under, 0.6, { ImageTransparency = 0.45 }, Enum.EasingStyle.Sine)
				task.wait(0.6)
			end
		end)
	end
	local ringId = icon("omen_ring")
	if ringId then
		local ring = Instance.new("ImageLabel")
		ring.Name = "Ring"
		ring.BackgroundTransparency = 1
		ring.Image = ringId
		ring.ImageTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(0.2, 0.2)
		ring.Parent = sg
		tween(ring, 0.9, { Size = UDim2.fromScale(0.94, 0.94), ImageTransparency = 0 }, Enum.EasingStyle.Back)
		task.spawn(function()
			while ring.Parent and pad == m do
				ring.Rotation = (ring.Rotation + RunService.Heartbeat:Wait() * 14) % 360
			end
		end)
	end
	-- the beam: two textured beams up into the sky, the core brighter, the texture streaming upward
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.2, 0)
	a0.Parent = disc
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 220, 0)
	a1.Parent = disc
	local beamTex = icon("omen_beam") or particleId("glow")
	for i, spec in { { w0 = 11, w1 = 4, c0 = Color3.new(1, 1, 1), c1 = Color3.fromRGB(214, 170, 255), t0 = 0, t1 = 0.7, speed = 1.4 }, { w0 = 3.5, w1 = 1.2, c0 = EMBER, c1 = EMBER, t0 = 0.1, t1 = 0.85, speed = 2.2 } } do
		local b = Instance.new("Beam")
		b.Name = "Beam" .. i
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = beamTex
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 46
		b.TextureSpeed = spec.speed
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = 0
		b.Width1 = 0
		b.Color = ColorSequence.new(spec.c0, spec.c1)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.t0), NumberSequenceKeypoint.new(0.7, (spec.t0 + spec.t1) / 2), NumberSequenceKeypoint.new(1, 1) })
		b.Parent = disc
		tween(b, 0.6, { Width0 = spec.w0, Width1 = spec.w1 } :: any, Enum.EasingStyle.Back)
	end
	-- smoke and sparks rising from the circle
	local smoke = particleId("smoke")
	local spark = particleId("spark")
	emitter(disc, smoke, ColorSequence.new(Color3.fromRGB(40, 6, 30), Color3.fromRGB(90, 20, 120)), 14 * k, NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }), NumberRange.new(3, 7), NumberRange.new(2.5, 4), 0)
	emitter(disc, spark, ColorSequence.new(EMBER, BLOOD), 22 * k, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }), NumberRange.new(10, 22), NumberRange.new(1, 2), 1)
	m.Parent = workspace
	-- (tint: the area's colour on the outer glow of the core)
	local core = disc:FindFirstChild("Beam2") :: Beam?
	if core then
		core.Color = ColorSequence.new(EMBER, tint:Lerp(EMBER, 0.5))
	end
end

-------------------------------------------------------------------------------------------------------------
function BossOmen.awake(d): boolean
	if not (icon("omen_banner") and icon("omen_eye")) then
		return false
	end
	token += 1
	local my = token
	try("summon", summon, d.pos, BLOOD)
	try("grade", grade, 3.6)
	try("vignette", vignette, 3.9)
	sfx("demonSwell", 0.9)
	sfx("heartbeat", 1.1, 1.25, 2.4)
	try("eye", eye, 0.35, 2.15, my)
	task.delay(2.2, function()
		if my ~= token then
			return
		end
		sfx("impact", 0.8)
		sfx("growl2", 0.9, 0.85)
		pcall(function()
			(require(script.Parent.Sound) :: any).play("roar", 0.05, 0.8)
		end)
		try("banner", banner, d.name or "The boss", 3.4, my)
		-- the camera jolts with the slam (client/BossVfx's shake, when it has one)
		pcall(function()
			local BossVfx = require(script.Parent.BossVfx) :: any
			if BossVfx.shake then
				BossVfx.shake(7, 0.5)
			end
		end)
	end)
	return true
end

-- the roar's impact frames: a negative (white speed lines on black), a red one, a white flash
function BossOmen.roar(_z: number?, short: boolean?)
	local lines = icon("omen_lines")
	if not lines then
		return
	end
	try("roar", function()
		local f = Instance.new("Frame")
		f.Name = "Impact"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.Size = UDim2.fromScale(1, 1)
		f.Parent = impactGui
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = lines
		img.ScaleType = Enum.ScaleType.Stretch
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1.1, 1.1)
		img.Parent = f
		local step = if short then 0.05 else 0.07
		task.delay(step, function()
			img.ImageColor3 = BLOOD
			img.Size = UDim2.fromScale(1.25, 1.25)
			img.Rotation = 4
		end)
		task.delay(step * 2, function()
			img.Visible = false
			f.BackgroundColor3 = Color3.new(1, 1, 1)
			tween(f, if short then 0.18 else 0.3, { BackgroundTransparency = 1 })
			Debris:AddItem(f, 0.4)
		end)
		if not short then
			vignette(0.9)
		end
	end)
end

return BossOmen
]======]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "21473 1554448062" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.StarterPlayer.StarterPlayerScripts.MowALawnClient
local old = folder:FindFirstChild("BossOmen")
if old then
	local now = hashOf(old.Source)
	if now == "21473 1554448062" then
		return "BossOmen is already this version: " .. now
	end
	local known = {  }
	if not known[now] then
		return "NOT CHANGED: BossOmen is there but is " .. now .. " (not a version this replaces)"
	end
	old.Source = src
	return "BossOmen updated: " .. hashOf(old.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "BossOmen"
m.Source = src
m.Parent = folder
return "BossOmen installed: " .. hashOf(m.Source)
