-- The classes' gimmicks on screen (server/ClassPerks sends "classFx"). Each class's gimmick looks like the class
-- (owner, 27 Oct: "every class UNIQUE ... its OWN GIMMICK that MATCHES THEIR CLASS"), and its name pops up. Revamped
-- 31 Oct (owner: "revamp all the effects of every class ... the higher the rarity, the higher and more detailed the
-- quality"): the ground flashes glow now (unlit SurfaceGuis: decals all but vanish on sunny grass), each gimmick
-- uses its class's own aura textures (client/ClassAuras), and the rarer the class the more layers it has:
--   rootRip    Weed Puller        (Common)    the clump yanked out: a soil sigil flash, dirt and roots flung, a pop
--   tidy       Groundskeeper      (Rare)      a chalk-lined mown circle flashes, a rake sweep goes round, leaves in
--   courier    Lawn Baron         (Rare)      a gold coin sigil flash, a fountain of coins, banknotes, "COURIER +123"
--   reapWave   Hedge Reaper       (Epic)      the bramble sigil bursts out, two pale crescents race out, hedge leaves
--                                                 and mint souls fly
--   turboDeck  Mower Specialist   (Epic)      riding a mower: a saw ring under the deck, flame jets, sparks (client)
--   stomp      Grass Titan        (Legendary) the rune circle cracks open, a shockwave, rock shards, dust, a shake
--   midas      Ultimate Gardener  (Legendary) a sunburst flash, light pillars on the clump, gold sparkles and petals
--   hotStreak  Lawn Legend        (Mythic)    every 20% of the streak: a flare of fire, a ring, embers, the word (client)
--   graze      Goat Man           (Secret)    grass pulled in to be eaten, turning gold (cheap: every 0.75 s), and
--                                             every 4th bite a little gold ring
-- (The Gardener's Green Thumb has no effect here: the server moves the bundles.) Nothing plays for gimmicks over
-- 120 studs from your camera; phones and Potato Mode get flat rings instead of beam shockwaves and skip extra layers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Format = require(Shared:WaitForChild("Format"))
local FX = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local BFX = require(Shared:WaitForChild("BossFxIds")) :: { [string]: string }
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
-- the class auras' VFX Forge bursts play through client/FilmVfx (it loads the plugin's Emit Module); nil if it's missing
local FilmVfx = nil
pcall(function()
	FilmVfx = require(script.Parent:WaitForChild("FilmVfx", 5) :: ModuleScript)
end)

local ClassFx = {}
local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "ClassFx"
folder.Parent = workspace

-- (the same textures as client/ClassAuras)
local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end
local T = {
	sigSoil = id(112624269165978),
	sigLawn = id(115704817613902),
	sigCoin = id(124502312757293),
	sigThorn = id(134297845587848),
	sigRune = id(117798502139772),
	sigSun = id(99680872451783),
	sigRose = id(130056990010328),
	saw = id(99657883820812),
	galaxy = id(98177835238703),
	coin = id(128871336135848),
	bill = id(87996651325429),
	flame = id(121208167011523),
	wisp = id(126327675942159),
	ringCrisp = id(98405192233320),
	flash = id(87243885184203),
	crescent = id(127095313671439),
	glint = id(93030574875002),
	streak = id(81969979283442),
	stripBody = id(73446398119013),
	vineStrip = id(89987547908830),
}

local WHITE = Color3.new(1, 1, 1)
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local lite = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
pcall(function()
	local Potato = require(script.Parent:WaitForChild("Potato", 5) :: ModuleScript) :: any
	local phone = lite
	lite = phone or Potato.on == true
	Potato.changed(function(on)
		lite = phone or on == true
	end)
end)

local function part(size: Vector3, cf: CFrame, color: Color3, transparency: number?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0
	p.Parent = folder
	return p
end

-- turn `p` about its own Y axis by `turns` full turns over `ti` (a CFrame tween only ever turns the short way, so a
-- full turn would be no turn at all): tweens a number and places the part as it changes
local function spinTween(p: BasePart, turns: number, ti: TweenInfo)
	local base = p.CFrame
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(x)
		p.CFrame = CFrame.new(p.Position) * (base - base.Position) * CFrame.Angles(0, x * math.pi * 2, 0)
	end)
	v.Parent = p
	TweenService:Create(v, ti, { Value = turns }):Play()
end

-- a glowing image on the ground at `pos` growing from `from` to `to` studs across and fading, turning `spin` turns
-- (a SurfaceGui that ignores the light and is over-bright, so it reads on sunny grass)
local function spread(pos: Vector3, tex: string, color: Color3, from: number, to: number, time: number, spin: number?, glow: number?, start: number?)
	local p = part(Vector3.new(from, 0.05, from), CFrame.new(pos + Vector3.new(0, 0.35, 0)), WHITE, 1)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.LightInfluence = 0
	g.Brightness = glow or 2
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(512, 512)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = tex
	img.ImageColor3 = color
	img.ImageTransparency = start or 0
	img.Parent = g
	g.Parent = p
	local ti = TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(p, ti, { Size = Vector3.new(to, 0.05, to) }):Play()
	if spin and spin ~= 0 then
		spinTween(p, spin, ti)
	end
	TweenService:Create(img, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 }):Play()
	Debris:AddItem(p, time + 0.1)
end

-- a bright ring of beams growing out from `pos` (shockwaves); sizes are diameters
local function ringWave(pos: Vector3, from: number, to: number, color: Color3, time: number, width: number?)
	if lite then
		spread(pos, T.ringCrisp, color, from, to, time, 0, 2, 0.1)
		return
	end
	local h = part(Vector3.new(0.2, 0.05, 0.2), CFrame.new(pos + Vector3.new(0, 0.4, 0)), WHITE, 1)
	local n = 24
	local atts = {}
	for i = 1, n do
		local at = Instance.new("Attachment")
		at.Parent = h
		atts[i] = at
	end
	local beams = {}
	for i = 1, n do
		local b = Instance.new("Beam")
		b.Attachment0 = atts[i]
		b.Attachment1 = atts[i % n + 1]
		b.FaceCamera = true
		b.Width0 = width or 0.5
		b.Width1 = width or 0.5
		b.Color = ColorSequence.new(color)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Segments = 1
		pcall(function()
			(b :: any).Brightness = 3
		end)
		b.Parent = h
		beams[i] = b
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / time)
		local r = (from + (to - from) * (1 - (1 - k) ^ 4)) / 2
		for i, at in atts do
			local th = (i - 1) / n * math.pi * 2
			at.Position = Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
		end
		local tr = NumberSequence.new(k)
		local w = (width or 0.5) * (1 - k * 0.6)
		for _, b in beams do
			b.Transparency = tr
			b.Width0 = w
			b.Width1 = w
		end
		if k >= 1 then
			conn:Disconnect()
			h:Destroy()
		end
	end)
end

type Burst = { tex: string, colors: { Color3 }, n: number, life: { number }, speed: { number }, size: number, grav: number?, spread: number?, spin: number?, light: number?, drag: number?, grow: boolean?, flip: boolean?, upright: boolean?, box: Vector3?, inward: boolean? }
-- one burst of particles from a small box at `pos`
local function burst(pos: Vector3, o: Burst)
	local h = part(o.box or Vector3.new(1, 0.4, 1), CFrame.new(pos + Vector3.new(0, 0.5, 0)), WHITE, 1)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = o.tex
	local kps = {}
	for i, c in o.colors do
		table.insert(kps, ColorSequenceKeypoint.new(if #o.colors == 1 then 0 else (i - 1) / (#o.colors - 1), c))
	end
	if #kps == 1 then
		table.insert(kps, ColorSequenceKeypoint.new(1, o.colors[1]))
	end
	e.Color = ColorSequence.new(kps)
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.SpreadAngle = Vector2.new(o.spread or 45, o.spread or 45)
	e.Acceleration = Vector3.new(0, o.grav or -30, 0)
	e.Drag = o.drag or 0.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.spin or 200), o.spin or 200)
	e.Size = if o.grow
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, o.size), NumberSequenceKeypoint.new(1, 0) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * 0.3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = o.light or 0
	e.LightInfluence = if (o.light or 0) > 0 then 0 else 1
	pcall(function()
		(e :: any).Brightness = if (o.light or 0) > 0 then 2.4 else 1
	end)
	e.EmissionDirection = Enum.NormalId.Top
	if o.flip then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	if o.upright then
		e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	end
	if o.inward then
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	end
	e.Parent = h
	e:Emit(if lite then math.ceil(o.n * 0.5) else o.n)
	Debris:AddItem(h, o.life[2] + 0.2)
end

-- a flash of light at `pos` (a short-lived point light)
local function flashLight(pos: Vector3, color: Color3, brightness: number, range: number, time: number)
	local h = part(Vector3.one * 0.2, CFrame.new(pos + Vector3.new(0, 2, 0)), WHITE, 1)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = h
	TweenService:Create(l, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(h, time + 0.1)
end

-- the gimmick's name popping up over the spot (gradient text in the class's colours, a punch-in and a float)
local function word(pos: Vector3, text: string, color: Color3, color2: Color3?)
	if text == "" then
		return
	end
	local a = part(Vector3.one * 0.2, CFrame.new(pos + Vector3.new(0, 5, 0)), WHITE, 1)
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(260, 58)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 120
	g.Parent = a
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = WHITE
	t.Rotation = math.random(-6, 6)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(color2 or color:Lerp(WHITE, 0.45), color)
	grad.Rotation = 90
	grad.Parent = t
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = rgb(30, 20, 10)
	st.Parent = t
	t.Parent = g
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = g
	TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(a, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = a.CFrame + Vector3.new(0, 4, 0) }):Play()
	task.delay(0.8, function()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(a, 1.2)
end

local function near(pos: Vector3, dist: number): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude < dist
end

-- a short camera shake when the camera is close (strength in degrees)
-- (applied after the camera scripts each frame, so it never drifts your aim)
local shakes = 0
local function shake(pos: Vector3, strength: number)
	if not near(pos, 25) then
		return
	end
	shakes += 1
	local name = "ClassFxShake" .. shakes
	local i = 0
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		i += 1
		local cam = workspace.CurrentCamera
		if i > 6 or not cam then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = (7 - i) / 6
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * strength * k), math.rad((math.random() - 0.5) * strength * k), 0)
	end)
end

-------------------------------------------------------------------------------------------------------------
-- each class's gimmick
-------------------------------------------------------------------------------------------------------------
local LOOK: { [string]: (Vector3, number, any) -> () } = {}

-- Weed Puller (Common): yanked out by the roots
LOOK.rootRip = function(pos)
	local dirt = rgb(120, 82, 52)
	spread(pos, T.sigSoil, rgb(215, 160, 100), 2, 7, 0.45, 0.15, 1.8)
	burst(pos, { tex = BFX.sand, colors = { rgb(160, 115, 70), dirt }, n = 26, life = { 0.5, 0.9 }, speed = { 10, 18 }, size = 0.55, grav = -45, spread = 35 })
	burst(pos, { tex = BFX.strand, colors = { rgb(150, 110, 70), rgb(100, 70, 45) }, n = 8, life = { 0.7, 1.1 }, speed = { 12, 20 }, size = 1.1, grav = -40, spread = 30, spin = 500 })
	burst(pos, { tex = BFX.leaf, colors = { rgb(110, 180, 60) }, n = 8, life = { 0.8, 1.2 }, speed = { 8, 14 }, size = 0.6, grav = -20, spread = 50 })
	-- the clump itself pops up out of the ground, spinning, and drops
	local clod = part(Vector3.new(0.9, 0.7, 0.9), CFrame.new(pos + Vector3.new(0, 0.4, 0)), rgb(105, 72, 44), 0, Enum.Material.Slate)
	local top = part(Vector3.new(1, 0.25, 1), clod.CFrame * CFrame.new(0, 0.45, 0), rgb(96, 168, 70), 0, Enum.Material.Grass)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = clod, top
	weld.Parent = clod
	top.Anchored = false
	local apex = clod.CFrame + Vector3.new(0, 4, 0)
	TweenService:Create(clod, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = apex * CFrame.Angles(2.4, 1.2, 0) }):Play()
	task.delay(0.3, function()
		TweenService:Create(clod, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = apex - Vector3.new(0, 4.4, 0), Transparency = 1 }):Play()
		TweenService:Create(top, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(clod, 0.7)
	Debris:AddItem(top, 0.7)
	ringWave(pos, 1, 6, rgb(220, 170, 110), 0.4, 0.35)
	word(pos, "ROOT RIP!", rgb(220, 160, 100), rgb(255, 230, 180))
	if near(pos, 60) then
		Sound.play("slam", 0.05, 0.5)
	end
end

-- Groundskeeper (Rare): swept tidy
LOOK.tidy = function(pos, r)
	local green = rgb(160, 230, 120)
	local chalk = rgb(235, 255, 240) -- (the pitch's chalk lines; the class's colours, not the Rare rarity's blue)
	spread(pos, T.sigLawn, chalk, 2, r * 1.6, 0.55, 0.12, 2)
	-- the rake's sweep: a curved swoosh going once round the spot
	local h = part(Vector3.new(0.2, 0.05, 0.2), CFrame.new(pos + Vector3.new(0, 0.4, 0)), WHITE, 1)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(r * 0.25, 0, 0)
	a0.Parent = h
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, r * 0.55)
	a1.Parent = h
	local bm = Instance.new("Beam")
	bm.Attachment0, bm.Attachment1 = a0, a1
	bm.CurveSize0, bm.CurveSize1 = r * 0.4, -r * 0.1
	bm.Width0, bm.Width1 = 0.1, 1.4
	bm.FaceCamera = true
	bm.Segments = 14
	bm.Color = ColorSequence.new(WHITE, chalk)
	bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.05) })
	bm.LightEmission = 1
	bm.LightInfluence = 0
	pcall(function()
		(bm :: any).Brightness = 2.5
	end)
	bm.Parent = h
	spinTween(h, -1, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	Debris:AddItem(h, 0.6)
	-- leaves gathered in to the middle, then a crisp "all tidy" twinkle
	burst(pos, { tex = BFX.leaf, colors = { green, rgb(100, 170, 60) }, n = 14, life = { 0.45, 0.55 }, speed = { 6, 9 }, size = 0.55, grav = 0, drag = 0, spin = 300, inward = true, box = Vector3.new(r * 1.4, 0.6, r * 1.4) })
	task.delay(0.4, function()
		burst(pos, { tex = T.glint, colors = { WHITE, chalk }, n = 10, life = { 0.4, 0.7 }, speed = { 2, 6 }, size = 1.1, grav = 0, spread = 80, grow = true, light = 1, flip = true })
		ringWave(pos, 1, r * 1.2, WHITE, 0.35, 0.25)
	end)
	word(pos, "TIDY UP!", green, WHITE)
end

-- Lawn Baron (Rare): the bag sold itself
LOOK.courier = function(pos, _r, d)
	local gold = rgb(255, 196, 60)
	spread(pos, T.sigCoin, gold, 2, 9, 0.6, 0.25, 2)
	for i = 1, (if lite then 6 else 10) do
		local c = part(Vector3.new(0.15, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(240, 180, 40), 0, Enum.Material.Metal)
		c.Shape = Enum.PartType.Cylinder
		c.Reflectance = 0.3
		local ang = i / 10 * math.pi * 2
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang)) * (2.5 + math.random() * 2)
		local up = c.CFrame + out * 0.5 + Vector3.new(0, 3.5 + math.random() * 1.5, 0)
		TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = up * CFrame.Angles(math.pi * 3, 0, 0) }):Play()
		task.delay(0.35, function()
			TweenService:Create(c, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up + out * 0.5 - Vector3.new(0, 4, 0), Transparency = 1 }):Play()
		end)
		Debris:AddItem(c, 0.9)
	end
	burst(pos + Vector3.new(0, 2, 0), { tex = T.glint, colors = { WHITE, gold }, n = 14, life = { 0.3, 0.6 }, speed = { 3, 8 }, size = 1.2, grav = 0, spread = 90, grow = true, light = 1, flip = true })
	burst(pos + Vector3.new(0, 3, 0), { tex = T.bill, colors = { WHITE }, n = 8, life = { 1.2, 1.8 }, speed = { 5, 9 }, size = 0.7, grav = -5, spread = 70, drag = 2, spin = 200 })
	flashLight(pos, gold, 3, 14, 0.5)
	word(pos, if d and d.coins then "COURIER +" .. Format.short(d.coins) else "COURIER!", gold, rgb(255, 245, 190))
	if near(pos, 60) then
		Sound.play("sell", 0.05, 0.6)
	end
end

-- Hedge Reaper (Epic): two scythe crescents racing out, souls torn loose
LOOK.reapWave = function(pos, r)
	-- (hedge green, bramble dark, pale steel and mint ghost-light: the reaper's colours, not the Epic rarity's purple)
	local hedge = rgb(45, 135, 60)
	local soul = rgb(124, 255, 208)
	local pale = rgb(225, 240, 232)
	spread(pos, T.sigThorn, rgb(150, 235, 170), 2, r * 2.2, 0.55, -0.5, 2.2)
	spread(pos, FX.slash, pale, 2, r * 2.2, 0.45, 0.6, 2.4)
	task.delay(0.08, function()
		spread(pos, FX.slash, soul, 2, r * 1.8, 0.45, -0.5, 2.4)
	end)
	ringWave(pos, 2, r * 2.1, soul, 0.5, 0.6)
	task.delay(0.1, function()
		ringWave(pos, 2, r * 1.6, rgb(150, 235, 140), 0.45, 0.3)
	end)
	burst(pos + Vector3.new(0, 2.5, 0), { tex = T.crescent, colors = { WHITE, soul }, n = 3, life = { 0.3, 0.35 }, speed = { 0, 0 }, size = r * 0.9, grav = 0, spread = 0, spin = 0, light = 1, flip = true })
	burst(pos, { tex = BFX.smoke, colors = { rgb(30, 70, 40), rgb(8, 24, 12) }, n = 10, life = { 0.8, 1.2 }, speed = { 3, 6 }, size = 2, grav = 1, spread = 80, drag = 1.5, light = 0.3 })
	burst(pos, { tex = T.wisp, colors = { WHITE, soul, hedge }, n = 10, life = { 0.6, 1 }, speed = { 6, 10 }, size = 1.2, grav = 6, spread = 70, drag = 2, light = 1, upright = true })
	burst(pos, { tex = BFX.leaf, colors = { rgb(140, 220, 110), hedge }, n = 12, life = { 0.8, 1.2 }, speed = { 10, 16 }, size = 0.5, grav = -12, spread = 85, spin = 500 })
	flashLight(pos, soul, 3, 16, 0.5)
	word(pos, "REAP WAVE!", soul, WHITE)
	if near(pos, 60) then
		Sound.play("slice", 0.05, 0.7)
	end
end

-- Grass Titan (Legendary): the ground answers
LOOK.stomp = function(pos, r)
	local moss = rgb(140, 220, 70)
	local glow = rgb(150, 255, 120)
	spread(pos, T.sigRune, rgb(180, 255, 160), 3, r * 2, 0.7, 0.05, 2.4)
	spread(pos, FX.burst, moss, 2, r * 1.2, 0.35, 0, 2)
	ringWave(pos, 2, r * 2.3, glow, 0.5, 0.8)
	task.delay(0.08, function()
		ringWave(pos, 2, r * 1.6, rgb(220, 200, 150), 0.45, 0.5)
	end)
	burst(pos, { tex = BFX.sand, colors = { rgb(180, 150, 110), rgb(120, 90, 60) }, n = 30, life = { 0.7, 1.2 }, speed = { 8, 16 }, size = 1.2, grav = -12, spread = 80, drag = 1.5 })
	burst(pos, { tex = T.streak, colors = { WHITE, glow }, n = 14, life = { 0.4, 0.7 }, speed = { 14, 22 }, size = 1.2, grav = -10, spread = 20, light = 1 })
	for i = 1, (if lite then 5 else 9) do
		local ang = i / 9 * math.pi * 2 + math.random() * 0.4
		local s = 0.6 + math.random() * 0.6
		local shard = part(Vector3.new(s, s * 1.3, s), CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), rgb(115, 108, 98), 0, Enum.Material.Slate)
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang)) * (r * 0.4 + math.random() * 2)
		local apex = shard.CFrame + out * 0.5 + Vector3.new(0, 4 + math.random() * 2, 0)
		TweenService:Create(shard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = apex * CFrame.Angles(2, 1, 0) }):Play()
		task.delay(0.3, function()
			TweenService:Create(shard, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = apex + out * 0.5 - Vector3.new(0, 5, 0), Transparency = 1 }):Play()
		end)
		Debris:AddItem(shard, 0.75)
	end
	flashLight(pos, glow, 4, 18, 0.6)
	word(pos, "TITAN STOMP!", rgb(200, 255, 120), WHITE)
	if near(pos, 60) then
		Sound.play("slam", 0.05, 0.8)
	end
	shake(pos, 1.6)
end

-- Ultimate Gardener (Legendary): a golden clump revealed
LOOK.midas = function(pos)
	local gold = rgb(255, 205, 40)
	local goldL = rgb(255, 240, 170)
	spread(pos, T.sigSun, gold, 2, 10, 0.7, 0.3, 2.4)
	-- pillars of light coming down on the clump
	local h = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), WHITE, 1)
	local beams = {}
	for i = 1, 3 do
		local th = i / 3 * math.pi * 2
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(math.cos(th) * 0.6, 18, math.sin(th) * 0.6)
		a0.Parent = h
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(math.cos(th) * 1.2, 0.3, math.sin(th) * 1.2)
		a1.Parent = h
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera = true
		b.Width0, b.Width1 = 1.6, 3.4
		b.Color = ColorSequence.new(goldL, gold)
		b.Texture = T.stripBody
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureSpeed = -1
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0.2) })
		pcall(function()
			(b :: any).Brightness = 2.5
		end)
		b.Parent = h
		beams[i] = b
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.8 do
			local k = (os.clock() - t0) / 0.8
			local tr = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35 + 0.65 * k), NumberSequenceKeypoint.new(1, 0.2 + 0.8 * k) })
			for _, b in beams do
				b.Transparency = tr
			end
			task.wait()
		end
		h:Destroy()
	end)
	burst(pos, { tex = T.glint, colors = { WHITE, gold }, n = 22, life = { 0.6, 1.1 }, speed = { 4, 10 }, size = 0.9, grav = -4, spread = 60, grow = true, light = 1, flip = true })
	burst(pos, { tex = BFX.petal, colors = { WHITE, gold }, n = 12, life = { 0.8, 1.3 }, speed = { 5, 9 }, size = 0.5, grav = -6, spread = 70, drag = 1.5, light = 0.5 })
	ringWave(pos, 1, 9, gold, 0.5, 0.5)
	flashLight(pos, gold, 4, 18, 0.7)
	word(pos, "MIDAS TOUCH!", gold, rgb(255, 250, 210))
	if near(pos, 60) then
		Sound.play("rareChime", 0.05, 0.7)
	end
end

-- Goat Man (Secret): grass pulled in to be eaten, turning to gold; every 4th bite a little gold ring (gold, grass and
-- wool white: the G.O.A.T.'s colours, not the Secret rarity's)
local bites = 0
LOOK.graze = function(pos, r)
	local h = part(Vector3.new(r * 1.6, 0.6, r * 1.6), CFrame.new(pos + Vector3.new(0, 0.4, 0)), WHITE, 1)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = BFX.strand
	e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(185, 255, 140)), ColorSequenceKeypoint.new(0.6, rgb(255, 210, 90)), ColorSequenceKeypoint.new(1, rgb(255, 245, 210)) })
	e.Lifetime = NumberRange.new(0.35, 0.45)
	e.Speed = NumberRange.new(0.5, 1)
	e.Size = NumberSequence.new(0.45, 0.1)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.LightEmission = 0.6
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.Parent = h
	e:Emit(6)
	Debris:AddItem(h, 0.6)
	bites += 1
	if bites % 4 == 0 and not lite and near(pos, 90) then
		ringWave(pos, 1, r * 1.5, rgb(255, 205, 70), 0.4, 0.3)
	end
end

State.on("fx", function(kind: string, d: any)
	if kind ~= "classFx" or type(d) ~= "table" then
		return
	end
	local look = LOOK[d.kind]
	if not look or typeof(d.pos) ~= "Vector3" or not near(d.pos, 120) then
		return -- (nothing for gimmicks far from your camera)
	end
	local ok, err = pcall(look, d.pos, d.r or 6, d)
	if not ok then
		warn("[ClassFx]", d.kind, err)
	end
	-- and its VFX Forge burst (ReplicatedStorage.AuraVFX.Fx_<kind>, built by BuildAuraVfx); the Goat Man's graze
	-- fires every 0.75 s, so its burst only every 4th bite and never on phones or in Potato Mode
	if FilmVfx and (d.kind ~= "graze" or (not lite and bites % 4 == 0)) then
		pcall(FilmVfx.play, "Fx_" .. d.kind, d.pos)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- the gimmicks the server doesn't send: drawn here from what every client can see
-------------------------------------------------------------------------------------------------------------
-- Lawn Legend (Mythic), Hot Streak: every 20% of the streak (player attribute ClassStreak, 0..60) a crimson flare
local CRIM = rgb(225, 35, 45)
local conns: { [Player]: { RBXScriptConnection } } = {}
local function keep(p: Player, c: RBXScriptConnection)
	conns[p] = conns[p] or {}
	table.insert(conns[p], c)
end
local function watchStreak(p: Player)
	local last = tonumber(p:GetAttribute("ClassStreak")) or 0
	keep(p, p:GetAttributeChangedSignal("ClassStreak"):Connect(function()
		local v = tonumber(p:GetAttribute("ClassStreak")) or 0
		local step = math.floor(v / 20)
		local lastStep = math.floor(last / 20)
		last = v
		if step <= lastStep or step < 1 or p:GetAttribute("Class") ~= "LawnLegend" then
			return
		end
		-- lihfolk-ignore: findfirstchild-chain (nil-checked on the next line)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not near(root.Position, 90) then
			return
		end
		local feet = root.Position - Vector3.new(0, 2.7, 0)
		spread(feet, T.sigSun, rgb(255, 120, 40), 2, 8 + step * 2, 0.6, -0.3, 2.4)
		ringWave(feet, 2, 10 + step * 3, CRIM, 0.5, 0.6)
		burst(feet, { tex = T.flame, colors = { rgb(255, 230, 160), CRIM, rgb(150, 10, 40) }, n = 10 + step * 4, life = { 0.5, 0.8 }, speed = { 6, 12 }, size = 2, grav = 6, spread = 30, light = 1, flip = true })
		burst(feet, { tex = T.glint, colors = { rgb(255, 230, 150), rgb(255, 120, 30) }, n = 14, life = { 0.6, 1 }, speed = { 8, 14 }, size = 0.6, grav = 4, spread = 80, drag = 2, light = 1, flip = true })
		flashLight(feet, CRIM, 3 + step, 16, 0.5)
		word(feet, "HOT STREAK +" .. tostring(step * 20) .. "%", rgb(255, 120, 40), rgb(255, 220, 160))
		if FilmVfx then
			pcall(FilmVfx.play, "Fx_hotStreak", feet)
		end
		if near(feet, 60) then
			Sound.play("rareChime", 0.05, 0.5)
		end
	end))
end

-- Mower Specialist (Epic), Turbo Deck: while one rides a mower, a hot saw ring under the deck, flame jets, sparks
type Turbo = { model: Model, ring: Part, jets: { ParticleEmitter }, sparks: ParticleEmitter, root: BasePart }
local turbos: { [Player]: Turbo } = {}
local function stopTurbo(p: Player)
	local t = turbos[p]
	if t then
		t.ring:Destroy()
		for _, j in t.jets do
			j:Destroy()
		end
		t.sparks:Destroy()
		turbos[p] = nil
	end
end
local function startTurbo(p: Player, seat: BasePart)
	stopTurbo(p)
	local model = seat:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end
	local root = model.PrimaryPart or seat
	local ring = part(Vector3.new(7, 0.05, 7), root.CFrame, WHITE, 1)
	ring.Name = "TurboDeck"
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.LightInfluence = 0
	g.Brightness = 1.8
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(512, 512)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = T.saw
	img.ImageColor3 = rgb(255, 170, 80)
	img.ImageTransparency = 0.25
	img.Parent = g
	g.Parent = ring
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = T.streak
	sparks.Color = ColorSequence.new(rgb(255, 245, 200), rgb(255, 150, 50))
	sparks.Lifetime = NumberRange.new(0.2, 0.35)
	sparks.Speed = NumberRange.new(10, 16)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Size = NumberSequence.new(0.4, 0.05)
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Rate = if lite then 8 else 18
	sparks.EmissionDirection = Enum.NormalId.Back
	sparks.Parent = ring
	local jets = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "ExhaustTip" then
			local j = Instance.new("ParticleEmitter")
			j.Texture = T.flame
			j.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			j.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			j.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 240, 200)), ColorSequenceKeypoint.new(0.5, rgb(255, 140, 40)), ColorSequenceKeypoint.new(1, rgb(150, 50, 20)) })
			j.Lifetime = NumberRange.new(0.25, 0.4)
			j.Speed = NumberRange.new(3, 5)
			j.SpreadAngle = Vector2.new(8, 8)
			j.Size = NumberSequence.new(0.9, 0.2)
			j.LightEmission = 1
			j.LightInfluence = 0
			j.Rate = if lite then 10 else 22
			j.EmissionDirection = Enum.NormalId.Top
			j.Parent = d
			table.insert(jets, j)
		end
	end
	turbos[p] = { model = model, ring = ring, jets = jets, sparks = sparks, root = root }
	local pos = root.Position
	if near(pos, 60) then
		ringWave(pos - Vector3.new(0, 1, 0), 2, 12, rgb(255, 150, 50), 0.45, 0.6)
		burst(pos, { tex = T.streak, colors = { WHITE, rgb(255, 150, 50) }, n = 16, life = { 0.25, 0.4 }, speed = { 12, 20 }, size = 0.6, grav = -30, spread = 70, light = 1 })
		word(pos, "TURBO DECK!", rgb(255, 160, 60), rgb(255, 235, 190))
	end
end
local function watchSeat(p: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local function check()
		local seat = hum.SeatPart
		if seat and p:GetAttribute("Class") == "MowerSpecialist" and seat:IsA("VehicleSeat") then
			startTurbo(p, seat)
		else
			stopTurbo(p)
		end
	end
	hum:GetPropertyChangedSignal("SeatPart"):Connect(check)
	check()
end
RunService.Heartbeat:Connect(function()
	for p, t in turbos do
		if not t.root.Parent then
			stopTurbo(p)
		else
			local cf = t.root.CFrame
			local look = cf.LookVector
			local yaw = math.atan2(-look.X, -look.Z)
			local y = cf.Position.Y - t.root.Size.Y / 2 + 0.15
			t.ring.CFrame = CFrame.new(cf.Position.X, y, cf.Position.Z) * CFrame.Angles(0, yaw + os.clock() * 12, 0)
		end
	end
end)

local function watchPlayer(p: Player)
	watchStreak(p)
	keep(p, p.CharacterAdded:Connect(function(char)
		watchSeat(p, char)
	end))
	if p.Character then
		task.spawn(watchSeat, p, p.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	stopTurbo(p)
	for _, c in conns[p] or {} do
		c:Disconnect()
	end
	conns[p] = nil
end)
for _, p in Players:GetPlayers() do
	task.spawn(watchPlayer, p)
end

-- the Grass Titan's stomp: a jump that lands
local function watch(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local jumped = false
	hum.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Jumping then
			jumped = true
		elseif new == Enum.HumanoidStateType.Landed then
			if jumped and State.data and State.data.class == "GrassTitan" then
				State.fire("ClassAct", "stomp")
			end
			jumped = false
		elseif new == Enum.HumanoidStateType.Seated or new == Enum.HumanoidStateType.Swimming then
			jumped = false
		end
	end)
end
if player.Character then
	task.spawn(watch, player.Character)
end
player.CharacterAdded:Connect(watch)

ClassFx.LOOK = LOOK -- (for previews / tests)
return ClassFx
