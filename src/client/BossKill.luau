-- BossKill (29 Oct; owner, 22:49: "also fix the light and use real fx from fx", of the summon pad's neon pillar; 22:50:
-- "make when the boss defeated make it more climatic like it has to be there needs to be dopamine when killing it").
-- Listens to the same boss events as client/BossCine and plays on top of it, without changing it:
--   * the summon pad (bossReady): BossCine's neon cylinder is hidden (LocalTransparencyModifier, on this screen only)
--     and a real light pillar stands in its place: two scrolling light beams with the films' pillar texture
--     (FilmVFX.GoldPillar's), motes streaming up it, rings pulsing out over the ground, a glow at its foot, a flare at
--     the top, a light, all in the area's colour. It is parented to BossCine's part, so it goes when that goes.
--   * the kill (bossDeath, ~3 s of the boss reeling): the killing blow lands on an anime impact frame (white; black
--     with white speed lines and FINISH! in our title style; the area's colour), the colours punch up, a heartbeat
--     thumps faster and faster while it reels, then at the pop: a white flash, a boom, shockwave rings over the
--     ground, a burst of light (the films' SunBreak, GoldPillar, three fireworks, a confetti pop), gold coins spraying
--     out and raining down, confetti from both sides, and gold rays turning behind BOSS DEFEATED!.
-- Far from the fight (over 300 studs) only the world effects play. Phones and Potato Mode get fewer coins and
-- particles (FilmVfx.budget()). Cosmetic only, every step wrapped in pcall.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local BossMoves = require(Shared:WaitForChild("BossMoves"))
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local FilmVfx = require(script.Parent.FilmVfx)
local Confetti = require(script.Parent.Confetti)

local BossKill = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(12, 10, 18)
local GOLD = Color3.fromRGB(255, 236, 110)
local ORANGE = Color3.fromRGB(255, 140, 30)
local INK = Color3.fromRGB(30, 25, 45)
local FONT = (Config.UI and Config.UI.font) or Enum.Font.FredokaOne
-- the films' VFX Forge textures (ReplicatedStorage.FilmVFX: GoldPillar's beam and rings, its glow and motes)
local TEX = {
	pillar = "rbxassetid://106542030103669",
	ring = "rbxassetid://89007417158215",
	glow = "rbxassetid://108494962291607",
	mote = "rbxassetid://87871024708004",
	star = "rbxassetid://104954625098154",
}

local function try(label: string, fn: (...any) -> (), ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[BossKill] " .. label .. ": " .. tostring(err))
	end
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function zoneColor(z: number?): Color3
	local ok, c = pcall(function()
		return Color3.fromHex(BossMoves.get(z).ring or "FFE66E")
	end)
	return if ok and typeof(c) == "Color3" then c else GOLD
end

local function budget(): number
	local ok, b = pcall(FilmVfx.budget)
	return if ok and type(b) == "number" then b else 1
end

local function seq(points: { { number } }): NumberSequence
	local k = {}
	for _, p in points do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(k)
end

local function screen(name: string, order: number): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.None
	g.DisplayOrder = order
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = player:WaitForChild("PlayerGui")
	return g
end

local function fill(parent: Instance, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	local any = e :: any
	for k, v in props do
		any[k] = v
	end
	e.Parent = parent
	return e
end

local function myDistance(pos: Vector3): number
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then (root.Position - pos).Magnitude else math.huge
end

-------------------------------------------------------------------------------------------------------------
-- the summon pad's light pillar
-------------------------------------------------------------------------------------------------------------
local function pillarBeam(host: BasePart, a0: Attachment, a1: Attachment, width: number, speed: number, length: number, alpha: number, color: Color3, glow: number)
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = TEX.pillar
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = length
	b.TextureSpeed = speed
	b.Width0 = width
	b.Width1 = width * 0.7
	b.FaceCamera = true
	b.LightEmission = glow
	b.LightInfluence = 0
	b.Segments = 24
	b.Color = ColorSequence.new(color)
	b.Transparency = seq({ { 0, alpha }, { 0.65, alpha + (1 - alpha) * 0.35 }, { 1, 1 } })
	b.Parent = host
end

local function pillarParticles(host: BasePart, foot: Attachment, top: Attachment, color: Color3)
	local b = budget()
	local light = color:Lerp(WHITE, 0.45)
	-- motes streaming up from the pad (the host is a flat 7x7 slab: they leave its top face)
	emitter(host, {
		Texture = TEX.mote,
		Color = ColorSequence.new(light),
		EmissionDirection = Enum.NormalId.Top,
		Rate = math.max(6, 34 * b),
		Lifetime = NumberRange.new(2.4, 4),
		Speed = NumberRange.new(26, 54),
		SpreadAngle = Vector2.new(6, 6),
		Size = seq({ { 0, 0.9 }, { 0.7, 0.6 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }),
	})
	-- rings pulsing out flat over the ground
	emitter(foot, {
		Texture = TEX.ring,
		Color = ColorSequence.new(color),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Rate = 0.9,
		Lifetime = NumberRange.new(1.6),
		Size = seq({ { 0, 3 }, { 1, 26 } }),
		Transparency = seq({ { 0, 0.15 }, { 1, 1 } }),
	})
	-- a glow round its foot, a flare at the top
	emitter(foot, {
		Texture = TEX.glow,
		Color = ColorSequence.new(color),
		Speed = NumberRange.new(0),
		Rate = 5,
		Lifetime = NumberRange.new(1),
		Size = seq({ { 0, 12 }, { 1, 16 } }),
		Transparency = seq({ { 0, 0.55 }, { 1, 1 } }),
	})
	emitter(top, {
		Texture = TEX.glow,
		Color = ColorSequence.new(light),
		Speed = NumberRange.new(0),
		Rate = 3,
		Lifetime = NumberRange.new(1.4),
		Size = seq({ { 0, 30 }, { 1, 40 } }),
		Transparency = seq({ { 0, 0.45 }, { 1, 1 } }),
	})
	emitter(top, {
		Texture = TEX.star,
		Color = ColorSequence.new(WHITE),
		Speed = NumberRange.new(0),
		Rate = 1.5,
		Lifetime = NumberRange.new(0.9),
		Rotation = NumberRange.new(0, 90),
		Size = seq({ { 0, 0 }, { 0.3, 18 }, { 1, 0 } }),
	})
end

local function pillar(old: BasePart, pos: Vector3, color: Color3)
	old.LocalTransparencyModifier = 1
	local host = Instance.new("Part")
	host.Name = "SummonPillar"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.new(7, 1, 7)
	host.CFrame = CFrame.new(pos)
	local foot = Instance.new("Attachment")
	foot.Position = Vector3.new(0, 0.6, 0)
	foot.Parent = host
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 260, 0)
	top.Parent = host
	-- (checked against a bright midday sky: fully additive light washed out to white there, so the outer glow is
	-- mostly painted on and the core only partly additive: it keeps the area's colour)
	pillarBeam(host, foot, top, 22, 0.6, 70, 0.3, color, 0.25) -- the soft outer glow
	pillarBeam(host, foot, top, 7, 1.7, 32, 0, color:Lerp(WHITE, 0.2), 0.8) -- the bright core
	pillarParticles(host, foot, top, color)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 40
	light.Brightness = 3
	light.Parent = host
	host.Parent = old -- (goes with BossCine's beam)
end

local function onReady(d: any)
	local t0 = os.clock()
	local old = workspace:FindFirstChild("SummonBeam")
	while not old and os.clock() - t0 < 2 do
		task.wait(0.1)
		old = workspace:FindFirstChild("SummonBeam")
	end
	if old and old:IsA("BasePart") and not old:FindFirstChild("SummonPillar") and typeof(d.pos) == "Vector3" then
		pillar(old, d.pos, zoneColor(d.z))
	end
end

-------------------------------------------------------------------------------------------------------------
-- the kill: the impact frame, the colour punch, the heartbeat
-------------------------------------------------------------------------------------------------------------
-- white speed lines through the middle of the screen (each frame is two opposite rays: clear in the middle)
local function speedLines(parent: Instance, color: Color3): Frame
	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundTransparency = 1
	box.Parent = parent
	for i = 1, 16 do
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.new(2.4, 0, 0, math.random(4, 16))
		l.Rotation = i * (180 / 16) + math.random(-5, 5)
		l.BackgroundColor3 = color
		l.BorderSizePixel = 0
		local g = Instance.new("UIGradient")
		g.Transparency = seq({ { 0, 0 }, { 0.3, 0 }, { 0.43, 1 }, { 0.57, 1 }, { 0.7, 0 }, { 1, 0 } })
		g.Parent = l
		l.Parent = box
	end
	return box
end

-- "FINISH!" in our title style: gold to orange, a heavy outline. (Roblox draws text at most 100 px, scaled to fit
-- or not, so it is set at 100 and the UIScale makes it big: ~1/4 of the screen's height at rest.)
local function slamText(parent: Instance): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.47)
	t.Size = UDim2.fromOffset(460, 110)
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.Text = "FINISH!"
	t.TextSize = 100
	t.TextColor3 = WHITE
	t.Rotation = -6
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 252, 214)),
		ColorSequenceKeypoint.new(0.35, GOLD),
		ColorSequenceKeypoint.new(0.75, ORANGE),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 96, 20)),
	})
	g.Parent = t
	local s = Instance.new("UIStroke")
	s.Thickness = 7
	s.Color = INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	local sc = Instance.new("UIScale")
	sc.Scale = 4.2
	sc.Parent = t
	t.Parent = parent
	return t
end

local function impactFrame(color: Color3)
	local g = screen("BossKillImpact", 50)
	local bg = fill(g, WHITE, 0)
	local lines = speedLines(g, WHITE)
	lines.Visible = false
	local text = slamText(g)
	text.Visible = false
	Sound.playAt("slam", 0.55, 0.9)
	Sound.playAt("punch", 0.7, 0.7)
	task.wait(0.05)
	-- black, white lines, FINISH! slams in
	bg.BackgroundColor3 = BLACK
	lines.Visible = true
	text.Visible = true
	local sc = text:FindFirstChildOfClass("UIScale") :: UIScale
	local stroke = text:FindFirstChildOfClass("UIStroke") :: UIStroke
	local k = g.AbsoluteSize.Y / 720 -- (the screen's height against a 720p screen)
	sc.Scale = 4.2 * k
	tween(sc, 0.14, { Scale = 1.7 * k }, Enum.EasingStyle.Back)
	task.wait(0.12)
	-- the area's colour, dark lines
	bg.BackgroundColor3 = color:Lerp(WHITE, 0.15)
	for _, l in lines:GetChildren() do
		local f = l :: Frame
		f.BackgroundColor3 = BLACK
	end
	task.wait(0.1)
	-- out
	tween(bg, 0.3, { BackgroundTransparency = 1 })
	for _, l in lines:GetChildren() do
		tween(l, 0.2, { BackgroundTransparency = 1 })
	end
	tween(sc, 0.5, { Scale = 2.1 * k })
	tween(text, 0.45, { TextTransparency = 1 })
	tween(stroke, 0.45, { Transparency = 1 })
	Debris:AddItem(g, 0.6)
end

local function colourPunch(color: Color3, len: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BossKillPunch"
	cc.Contrast = 0.35
	cc.Saturation = 0.5
	cc.Brightness = 0.06
	cc.TintColor = WHITE:Lerp(color, 0.2)
	cc.Parent = Lighting
	tween(cc, len, { Contrast = 0, Saturation = 0, Brightness = 0, TintColor = WHITE }, Enum.EasingStyle.Sine)
	Debris:AddItem(cc, len + 0.2)
end

-- the heartbeat while it reels: the edges of the screen throb in its colour, faster and faster
local function heartbeat(len: number, color: Color3)
	local g = screen("BossKillPulse", 5)
	local edge = fill(g, color, 1)
	local grad = Instance.new("UIGradient")
	grad.Transparency = seq({ { 0, 0 }, { 0.22, 0.85 }, { 0.5, 1 }, { 0.78, 0.85 }, { 1, 0 } })
	grad.Parent = edge
	local t, gap = 0.45, 0.5
	while t < len - 0.45 do
		task.wait(gap)
		t += gap
		gap = math.max(0.18, gap * 0.78)
		edge.BackgroundTransparency = 0.35
		tween(edge, gap * 0.8, { BackgroundTransparency = 1 })
		Sound.playAt("slam", 0.4, 0.35)
	end
	Debris:AddItem(g, 0.5)
end

-------------------------------------------------------------------------------------------------------------
-- the pop
-------------------------------------------------------------------------------------------------------------
local function flash()
	local g = screen("BossKillFlash", 49)
	local f = fill(g, WHITE, 0.05)
	tween(f, 0.55, { BackgroundTransparency = 1 })
	Debris:AddItem(g, 0.7)
end

local function shockwaves(pos: Vector3, color: Color3, size: number)
	local host = Instance.new("Part")
	host.Name = "BossKillWave"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.new(1, 1, 1)
	host.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
	host.Parent = workspace
	local a = Instance.new("Attachment")
	a.Parent = host
	for i, c in { WHITE, color, GOLD } do
		local e = emitter(a, {
			Texture = TEX.ring,
			Color = ColorSequence.new(c),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.01),
			Rate = 0,
			Lifetime = NumberRange.new(0.7 + i * 0.15),
			Size = seq({ { 0, 4 }, { 1, size * (1 + i * 0.25) } }),
			Transparency = seq({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		})
		task.delay((i - 1) * 0.12, function()
			e:Emit(1)
		end)
	end
	local light = Instance.new("PointLight")
	light.Color = color:Lerp(WHITE, 0.4)
	light.Range = 60
	light.Brightness = 6
	light.Parent = host
	tween(light, 1.4, { Brightness = 0 })
	Debris:AddItem(host, 2)
end

local function coins(pos: Vector3, n: number)
	for _ = 1, n do
		local c = Instance.new("Part")
		c.Name = "BossKillCoin"
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.35, 1.9, 1.9)
		c.Color = GOLD
		c.Material = Enum.Material.Neon
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		local a = math.random() * math.pi * 2
		local sp = 18 + math.random() * 34
		c.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 2, 4 + math.random() * 4, math.sin(a) * 2))
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		c.AssemblyLinearVelocity = Vector3.new(math.cos(a) * sp, 70 + math.random() * 50, math.sin(a) * sp)
		c.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
		c.Parent = workspace
		task.delay(2.8 + math.random() * 0.6, function()
			if c.Parent then
				tween(c, 0.4, { Transparency = 1, Size = c.Size * 0.4 })
			end
		end)
		Debris:AddItem(c, 4)
	end
end

-- gold rays turning slowly behind BOSS DEFEATED! (BossFx's card sits at 36% down the screen, DisplayOrder 7)
local function rays()
	local g = screen("BossKillRays", 6)
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.36)
	box.Size = UDim2.fromScale(0.62, 0.62)
	box.SizeConstraint = Enum.SizeConstraint.RelativeXX
	box.BackgroundTransparency = 1
	box.Parent = g
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = box
	local glow = Instance.new("ImageLabel")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.6, 0.6)
	glow.BackgroundTransparency = 1
	glow.Image = TEX.glow
	glow.ImageColor3 = GOLD
	glow.ImageTransparency = 0.35
	glow.Parent = group
	-- (checked on screen: wide, strong rays covered the whole picture; thin ones round the card read as a halo)
	for i = 1, 12 do
		local r = Instance.new("Frame")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Size = UDim2.fromScale(1, 0.03)
		r.Rotation = i * 15
		r.BackgroundColor3 = if i % 2 == 0 then GOLD else ORANGE
		r.BorderSizePixel = 0
		local gr = Instance.new("UIGradient")
		gr.Transparency = seq({ { 0, 1 }, { 0.15, 0.85 }, { 0.4, 0.45 }, { 0.5, 0.4 }, { 0.6, 0.45 }, { 0.85, 0.85 }, { 1, 1 } })
		gr.Parent = r
		r.Parent = group
	end
	tween(group, 0.35, { GroupTransparency = 0.45 })
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		box.Rotation = t * 14
		if t > 4.2 then
			conn:Disconnect()
			g:Destroy()
		end
	end)
	task.delay(3.6, function()
		if group.Parent then
			tween(group, 0.5, { GroupTransparency = 1 })
		end
	end)
end

local function play(name: string, at: Vector3, opts: { [string]: any })
	try(name, function()
		FilmVfx.play(name, at, opts)
	end)
end

local function finale(pos: Vector3, color: Color3, size: number, near: boolean)
	local b = budget()
	if near then
		try("flash", flash)
		try("rays", rays)
		try("confetti", Confetti.burst, math.floor(170 * math.max(0.4, b)))
	end
	Sound.playAt("bhPop", 0.6, 0.9)
	Sound.play("rareChime", 0, 0.7)
	try("waves", shockwaves, pos, color, 40 * size)
	try("coins", coins, pos, math.floor(40 * b))
	-- (checked on screen: at 1.6x the sun-break's glow washed the whole picture out for over a second, hiding the
	-- fireworks and the coins: smaller and higher, it reads as a burst of light over the spot)
	play("SunBreak", pos + Vector3.new(0, 14 * size, 0), { scale = size * 0.7 })
	play("GoldPillar", pos, { scale = size * 1.2, hold = 2.5 })
	play("ConfettiPop", pos + Vector3.new(0, 8 * size, 0), { scale = size * 1.4 })
	for i, c in { GOLD, color, ORANGE } do
		task.delay(0.15 * i, function()
			local a = i * 2.1
			play("Firework", pos + Vector3.new(math.cos(a) * 10 * size, 18 * size, math.sin(a) * 10 * size), { scale = size * 1.3, color = c })
			Sound.playAt("burst", 0.8 + i * 0.12, 0.5)
		end)
	end
end

local function onDeath(d: any)
	local len = if type(d.len) == "number" then d.len else 3
	local at = if type(d.at) == "number" then d.at else workspace:GetServerTimeNow()
	local left = math.max(1, len - (workspace:GetServerTimeNow() - at))
	local pos = if typeof(d.cf) == "CFrame" then d.cf.Position else nil
	if not pos then
		return
	end
	local mirror = ReplicatedStorage:FindFirstChild("MowALawnBoss")
	local scale = mirror and mirror:GetAttribute("Scale")
	local size = math.clamp((if type(scale) == "number" then scale else 5) / 2.5, 1.2, 3)
	local color = zoneColor(d.z)
	local near = myDistance(pos) < 300
	if near then
		task.spawn(try, "impact", impactFrame, color)
		try("punch", colourPunch, color, left + 1.2)
		task.spawn(try, "heartbeat", heartbeat, left, color)
	end
	task.delay(math.max(0, left - 0.4), try, "finale", finale, pos, color, size, near)
end

State.on("fx", function(kind: string, payload: any)
	if kind == "bossReady" then
		try("ready", onReady, payload)
	elseif kind == "bossDeath" then
		try("death", onDeath, payload)
	end
end)

-- for testing in Studio: BossKill.test(pos, z) plays the kill at a spot
function BossKill.test(pos: Vector3, z: number?)
	onDeath({ z = z or 1, at = workspace:GetServerTimeNow(), len = 3, cf = CFrame.new(pos) })
end

function BossKill.testPillar(pos: Vector3, z: number?)
	local p = Instance.new("Part")
	p.Name = "SummonBeam"
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0.5
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	onReady({ pos = pos, z = z or 1 })
	return p
end

return BossKill
