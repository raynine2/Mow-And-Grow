-- Boss fights, made epic (client only; client/Fx's boss handlers call in here):
--   intro    a 3 s cinematic when a boss wakes: the camera swoops to a low hero angle, the boss climbs out of the
--            ground in a burst of dust, letterbox bars, a big title card, a roar with screen shake. Any key skips.
--   HP bar   big Chop A Forest style bar at the top centre, with a white "damage taken" chunk that drains behind.
--   hits     a big impact (HitFx "bossHit") where your blow lands, white flash, camera kick, damage numbers.
--   slams    a pulsing ring that fills up before the slam, then dust, flying dirt and a shock ring.
--   death    freeze + white flash + FOV punch, the boss swells, flashes and pops, then "BOSS DEFEATED!" + confetti
--            with your reward underneath.
-- Every effect is cosmetic: errors are caught, and the intro always gives the camera and controls back (on finish,
-- skip, death, error, or after a timeout).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local HitFx = require(script.Parent.HitFx)
local Confetti = require(script.Parent.Confetti)
local CameraView = require(script.Parent.CameraView)

local BossFx = {}
-- Fx plugs in its Humanoid.CameraOffset shake (power, seconds) here.
BossFx.shake = nil :: ((number, number) -> ())?

local player = Players.LocalPlayer
local C = UI.colors
local BASE_FOV = 70 -- HitFx's kick returns to this too
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 236, 110)
local ORANGE = Color3.fromRGB(255, 128, 30)

local folder = Instance.new("Folder")
folder.Name = "BossFx"
folder.Parent = workspace

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Run fn, warn instead of breaking anything if it errors.
local function try(label: string, fn: (...any) -> (), ...: any): boolean
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[BossFx] " .. label .. ": " .. tostring(err))
	end
	return ok
end

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.05 then f.Unit else Vector3.new(0, 0, -1)
end

local function bossModel(): Model?
	-- the boss revamp (26 Oct) draws the boss in workspace.BossView (client/BossView)
	local view = workspace:FindFirstChild("BossView")
	local m = view and view:FindFirstChildOfClass("Model")
	if m then
		return m
	end
	local world = workspace:FindFirstChild("World")
	local holder = world and world:FindFirstChild("Boss")
	return holder and holder:FindFirstChildOfClass("Model")
end

-- The zone of a boss, from its zone number or its name.
local function zoneOf(name: string?, z: number?): number
	if z and Config.ZONES[z] then
		return z
	end
	for i, zd in Config.ZONES do
		if zd.boss.name == name then
			return i
		end
	end
	return 1
end

local function bossColor(z: number): Color3
	return Config.ZONES[z].boss.color
end

local function dirtColor(z: number): Color3
	return Config.ZONES[z].ground or Color3.fromRGB(150, 110, 70)
end

local function easeInOut(k: number): number
	return if k < 0.5 then 4 * k * k * k else 1 - (-2 * k + 2) ^ 3 / 2
end

local function easeOutBack(k: number): number
	local c1, c3 = 1.4, 2.4
	return 1 + c3 * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
end

-------------------------------------------------------------------------------------------------------------
-- screens: a full-screen layer (letterbox, flashes) and a 1280x720 scaled layer (HP bar, title cards)
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
local cine = screen("BossFxCinema", 6)
local hud = screen("BossFxHud", 7)
local hudScale = Instance.new("UIScale")
hudScale.Parent = hud
local function rescale()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	hudScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.5)
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

local function overlay(color: Color3, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 5
	f.Parent = cine
	return f
end
local flashFrame = overlay(WHITE, "Flash")
local hurtFrame = overlay(Color3.fromRGB(255, 40, 40), "Hurt")

-- A full-screen flash that fades out.
local function screenFlash(frame: Frame, strength: number, time: number)
	frame.BackgroundTransparency = 1 - strength
	tween(frame, time, { BackgroundTransparency = 1 })
end

local function bar(top: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = if top then "LetterboxTop" else "LetterboxBottom"
	f.Size = UDim2.fromScale(1, 0.12)
	f.Position = if top then UDim2.fromScale(0, -0.12) else UDim2.fromScale(0, 1)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = cine
	return f
end
local barTop, barBottom = bar(true), bar(false)
local function letterbox(on: boolean)
	barTop.Visible = true
	barBottom.Visible = true
	local time = if on then 0.35 else 0.3
	tween(barTop, time, { Position = UDim2.fromScale(0, if on then 0 else -0.12) })
	tween(barBottom, time, { Position = UDim2.fromScale(0, if on then 0.88 else 1) })
end

-------------------------------------------------------------------------------------------------------------
-- title cards: kicker pill, a huge two-tone name with a thick outline, a line under it; punches in, shakes
-------------------------------------------------------------------------------------------------------------
local function twoTone(label: TextLabel, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.52, top),
		ColorSequenceKeypoint.new(0.56, bottom),
		ColorSequenceKeypoint.new(1, UI.shade(bottom, 0.9)),
	})
	g.Rotation = 90
	g.Parent = label
end

type Card = { root: Frame, scale: UIScale, sub: TextLabel }
local function titleCard(kicker: string, title: string, sub: string, y: number, kickerColor: Color3): Card
	local root = Instance.new("Frame")
	root.Name = "BossTitle"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, y)
	root.Size = UDim2.fromOffset(1000, 200)
	root.Parent = hud
	-- a dark slanted band behind, sliding in from the left
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.new(-0.4, 0, 0, 100)
	band.Size = UDim2.new(1.15, 0, 0, 108)
	band.Rotation = -2.5
	band.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
	band.BackgroundTransparency = 0.25
	band.BorderSizePixel = 0
	band.Parent = root
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.1),
		NumberSequenceKeypoint.new(0.82, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band
	tween(band, 0.28, { Position = UDim2.new(0.5, 0, 0, 100) }, Enum.EasingStyle.Quart)
	-- kicker pill
	local pill = UI.frame({ size = UDim2.fromOffset(230, 36), pos = UDim2.new(0.5, 0, 0, 22), anchor = Vector2.new(0.5, 0.5), color = kickerColor, parent = root, radius = 18, outline = 3 })
	UI.gradient(pill, kickerColor)
	UI.text(pill, kicker, UDim2.new(1, -20, 1, -8), { pos = UDim2.fromOffset(10, 4), stroke = 2.5 })
	-- the name
	local name = UI.text(root, title, UDim2.new(1, 0, 0, 104), { pos = UDim2.fromOffset(0, 48), stroke = 6 })
	name.TextColor3 = WHITE
	twoTone(name, GOLD, ORANGE)
	name.Rotation = -4
	tween(name, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back)
	local subLabel = UI.text(root, sub, UDim2.new(1, 0, 0, 32), { pos = UDim2.fromOffset(0, 156), stroke = 3 })
	-- punch in: big and see-through, slams down to size
	local sc = Instance.new("UIScale")
	sc.Scale = 2.3
	sc.Parent = root
	tween(sc, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
	return { root = root, scale = sc, sub = subLabel }
end

local function shakeCard(card: Card, power: number, time: number)
	local start = os.clock()
	local base = card.root.Position
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local left = 1 - (os.clock() - start) / time
		if left <= 0 or not card.root.Parent then
			conn:Disconnect()
			if card.root.Parent then
				card.root.Position = base
			end
			return
		end
		local p = power * left
		card.root.Position = base + UDim2.fromOffset(rand(-p, p), rand(-p, p))
	end)
end

local function fadeCard(card: Card, after: number)
	task.delay(after, function()
		if not card.root.Parent then
			return
		end
		local info = 0.3
		for _, d in card.root:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, info, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, info, { Transparency = 1 })
			elseif d:IsA("Frame") then
				tween(d, info, { BackgroundTransparency = 1 })
			elseif d:IsA("ImageLabel") then
				tween(d, info, { ImageTransparency = 1, BackgroundTransparency = 1 })
			end
		end
		tween(card.scale, info, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(card.root, info + 0.05)
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the boss HP bar (top centre)
-------------------------------------------------------------------------------------------------------------
local HP_SHOWN = UDim2.new(0.5, 0, 0, 10)
local HP_HIDDEN = UDim2.new(0.5, 0, 0, -110)
local hpRoot = Instance.new("Frame")
hpRoot.Name = "BossHp"
hpRoot.BackgroundTransparency = 1
hpRoot.AnchorPoint = Vector2.new(0.5, 0)
hpRoot.Position = HP_HIDDEN
hpRoot.Size = UDim2.fromOffset(620, 78)
hpRoot.Visible = false
hpRoot.Parent = hud
local hpName = UI.text(hpRoot, "", UDim2.new(1, 0, 0, 32), { stroke = 3.5 })
twoTone(hpName, WHITE, Color3.fromRGB(255, 220, 150))
local hpTrack = UI.frame({ size = UDim2.new(1, 0, 0, 38), pos = UDim2.fromOffset(0, 36), color = Color3.fromRGB(28, 22, 36), parent = hpRoot, radius = 11, outline = 4 })
local hpInner = Instance.new("Frame")
hpInner.BackgroundTransparency = 1
hpInner.Position = UDim2.fromOffset(4, 4)
hpInner.Size = UDim2.new(1, -8, 1, -8)
hpInner.Parent = hpTrack
local hpLag = UI.frame({ size = UDim2.fromScale(1, 1), color = WHITE, parent = hpInner, radius = 8, outline = 0, name = "Lag" })
local hpFill = UI.frame({ size = UDim2.fromScale(1, 1), color = WHITE, parent = hpInner, radius = 8, outline = 0, name = "Fill" })
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new(Color3.fromRGB(220, 38, 38), Color3.fromRGB(255, 150, 40))
fillGrad.Parent = hpFill
local shine = UI.frame({ size = UDim2.new(1, -6, 0.38, 0), pos = UDim2.fromOffset(3, 2), color = WHITE, parent = hpFill, radius = 6, outline = 0, transparency = 0.72, name = "Shine" })
shine.ZIndex = 2
local hpHitFlash = UI.frame({ size = UDim2.fromScale(1, 1), color = WHITE, parent = hpFill, radius = 8, outline = 0, transparency = 1, name = "HitFlash" })
hpHitFlash.ZIndex = 3
for _, x in { 0.25, 0.5, 0.75 } do
	local tick = UI.frame({ size = UDim2.new(0, 3, 1, 0), pos = UDim2.fromScale(x, 0), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(28, 22, 36), parent = hpInner, radius = 0, outline = 0, transparency = 0.45, name = "Tick" })
	tick.ZIndex = 4
end
-- the phase marker at 50% (the rage form starts there): a gold notch over the bar, gone in phase 2
local phaseMark = UI.frame({ size = UDim2.new(0, 6, 1, 14), pos = UDim2.new(0.5, 0, 0, -7), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(255, 214, 60), parent = hpInner, radius = 3, outline = 2, name = "PhaseMark" })
phaseMark.ZIndex = 6
local function setPhase(phase: number)
	local rage = phase >= 2
	phaseMark.Visible = not rage
	fillGrad.Color = if rage then ColorSequence.new(Color3.fromRGB(150, 10, 30), Color3.fromRGB(255, 40, 40)) else ColorSequence.new(Color3.fromRGB(220, 38, 38), Color3.fromRGB(255, 150, 40))
end
local hpText = UI.text(hpTrack, "", UDim2.new(1, -16, 1, -8), { pos = UDim2.fromOffset(8, 4), stroke = 2.5 })
hpText.ZIndex = 5

local hp = { name = "", value = 0, max = 1, ratio = 1, lag = 1, lastHit = 0, shown = false, avg = 0 }

local function showBar(on: boolean)
	if hp.shown == on then
		return
	end
	hp.shown = on
	if on then
		hpRoot.Visible = true
		hpRoot.Position = HP_HIDDEN
		tween(hpRoot, 0.45, { Position = HP_SHOWN }, Enum.EasingStyle.Back)
	else
		tween(hpRoot, 0.35, { Position = HP_HIDDEN }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.36, function()
			if not hp.shown then
				hpRoot.Visible = false
			end
		end)
	end
end

local function jolt()
	hpHitFlash.BackgroundTransparency = 0.25
	tween(hpHitFlash, 0.18, { BackgroundTransparency = 1 })
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local left = 1 - (os.clock() - start) / 0.16
		if left <= 0 then
			conn:Disconnect()
			hpTrack.Position = UDim2.fromOffset(0, 36)
			return
		end
		hpTrack.Position = UDim2.fromOffset(rand(-4, 4) * left, 36 + rand(-3, 3) * left)
	end)
end

-- Show this boss's HP. HP only goes down during a fight, so an older (higher) value never undoes a newer one.
local function setHp(name: string, value: number, max: number)
	if name ~= hp.name or max ~= hp.max then
		hp.name, hp.max, hp.value, hp.ratio, hp.lag, hp.avg = name, max, value, 1, 1, 0
		hpName.Text = name:upper()
	end
	value = math.min(value, hp.value)
	local ratio = math.clamp(value / math.max(max, 1), 0, 1)
	if ratio < hp.ratio - 1e-5 then
		hp.lastHit = os.clock()
		tween(hpFill, 0.08, { Size = UDim2.fromScale(ratio, 1) })
		if hp.shown then
			jolt()
		end
	else
		hpFill.Size = UDim2.fromScale(ratio, 1)
	end
	hp.value, hp.ratio = value, ratio
	hpText.Text = Format.short(math.ceil(value)) .. " / " .. Format.short(max)
end

-- the white chunk waits a moment after the last hit, then drains down to the fill
RunService.RenderStepped:Connect(function(dt)
	if not hpRoot.Visible or hp.lag <= hp.ratio then
		return
	end
	if os.clock() - hp.lastHit > 0.4 then
		hp.lag = math.max(hp.ratio, hp.lag + (hp.ratio - hp.lag) * (1 - math.exp(-dt * 7)) - dt * 0.02)
	end
	hpLag.Size = UDim2.fromScale(hp.lag, 1)
end)

local intro = { active = false }

State.on("world", function(w)
	try("world", function()
		if w.mode == "Run" and w.boss then
			setHp(w.boss.name, w.boss.hp, w.boss.max)
			setPhase(w.boss.phase or 1)
			if not intro.active and not BossFx.cinematic and w.boss.state ~= "intro" then
				showBar(true)
			end
		elseif hp.shown then
			showBar(false)
		end
	end)
end)

-------------------------------------------------------------------------------------------------------------
-- damage numbers
-------------------------------------------------------------------------------------------------------------
local function damageNumber(pos: Vector3, amount: number, big: boolean)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.WorldPosition = pos
	local g = Instance.new("BillboardGui")
	g.Size = if big then UDim2.fromOffset(260, 92) else UDim2.fromOffset(170, 60)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 220
	g.Adornee = a
	g.Parent = a
	local label = UI.text(g, "-" .. Format.short(math.floor(amount * 10 + 0.5) / 10) .. (if big then "!" else ""), UDim2.fromScale(1, 1), { stroke = if big then 4.5 else 3.5 })
	if big then
		twoTone(label, Color3.fromRGB(255, 245, 120), ORANGE)
	end
	label.Rotation = if big then rand(-12, 12) else rand(-6, 6)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = label
	tween(sc, 0.09, { Scale = if big then 1.35 else 1.2 })
	task.delay(0.09, function()
		tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	local drift = rand(-1.6, 1.6)
	tween(g, 0.85, { StudsOffset = Vector3.new(drift, if big then 3.6 else 2.8, 0) })
	task.delay(0.5, function()
		tween(label, 0.3, { TextTransparency = 1 })
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			tween(st, 0.3, { Transparency = 1 })
		end
	end)
	Debris:AddItem(a, 0.9)
end

-- Fast auto tools add up into one number every few frames instead of a stack of them.
local pending = { amount = 0, big = false, pos = Vector3.zero, scheduled = false, last = 0 }
local function flushNumber()
	pending.scheduled = false
	if pending.amount > 0 then
		damageNumber(pending.pos, pending.amount, pending.big)
		pending.last = os.clock()
	end
	pending.amount, pending.big = 0, false
end
local function queueNumber(pos: Vector3, amount: number, big: boolean)
	if not pending.scheduled and os.clock() - pending.last > 0.08 then
		damageNumber(pos, amount, big)
		pending.last = os.clock()
		return
	end
	pending.amount += amount
	pending.big = pending.big or big
	pending.pos = pos
	if not pending.scheduled then
		pending.scheduled = true
		task.delay(0.08, flushNumber)
	end
end

-------------------------------------------------------------------------------------------------------------
-- hits
-------------------------------------------------------------------------------------------------------------
-- Where your blow lands: the side of the boss facing you, on the ground under it (HitFx raises it to hand height).
local function hitPoint(model: Model): (Vector3, Vector3)
	local cf, size = model:GetBoundingBox()
	local c = Vector3.new(cf.Position.X, 0, cf.Position.Z)
	local root = myRoot()
	if not root then
		return c, cf.Position
	end
	local to = Vector3.new(root.Position.X, 0, root.Position.Z) - c
	local r = math.min(math.min(size.X, size.Z) * 0.4, math.max(0, to.Magnitude - 3))
	return c + flat(to) * r, cf.Position
end

local lastHitFx = 0
function BossFx.hit(d)
	local m = bossModel()
	local z = zoneOf(hp.name, State.world and State.world.boss and State.world.boss.z)
	local pos, mid = d.pos, d.pos
	if m then
		pos, mid = hitPoint(m)
	end
	if d.hp and d.max then
		setHp(if hp.name ~= "" then hp.name else Config.ZONES[z].boss.name, d.hp, d.max)
	end
	local now = os.clock()
	if now - lastHitFx > 0.09 then
		lastHitFx = now
		HitFx.play("bossHit", pos, bossColor(z), true, m)
	end
	-- a big hit: a good chunk of the bar, or much more than your usual hit
	local amount = d.amount or 0
	local big = amount >= hp.max * 0.05 or (hp.avg > 0 and amount >= hp.avg * 1.8)
	hp.avg = if hp.avg > 0 then hp.avg * 0.85 + amount * 0.15 else amount
	local eye = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position.Y or 5
	local at = Vector3.new(pos.X, math.min(eye + 1.5, mid.Y), pos.Z) + Vector3.new(rand(-1.5, 1.5), rand(0, 1.5), rand(-1.5, 1.5))
	queueNumber(at, amount, big)
	if big and BossFx.shake then
		BossFx.shake(3, 0.15)
	end
end

-------------------------------------------------------------------------------------------------------------
-- telegraph and slam
-------------------------------------------------------------------------------------------------------------
local RING_SPAN = 2.56 -- the ring texture's ring sits at 0.78 of its half-size: an image 2.56 R wide draws radius R

-- A flat square on the ground carrying a SurfaceGui (the canvas covers `size` studs).
local function groundCanvas(pos: Vector3, size: number, pixels: number): (Part, SurfaceGui)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(size, 0.05, size)
	p.CFrame = CFrame.new(pos.X, pos.Y + 0.15, pos.Z)
	p.Parent = folder
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(pixels, pixels)
	g.LightInfluence = 0
	g.Brightness = 1.4
	g.Adornee = p
	g.Parent = p
	return p, g
end

local function circle(parent: Instance, size: number, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(size, size)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

local function ringImage(parent: Instance, size: number, color: Color3, transparency: number): GuiObject
	if FxIds.ring then
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(size, size)
		img.BackgroundTransparency = 1
		img.Image = FxIds.ring
		img.ImageColor3 = color
		img.ImageTransparency = transparency
		img.Parent = parent
		return img
	end
	-- no texture yet: an outlined circle at the ring's radius
	local f = circle(parent, size / RING_SPAN * 2, color, 1)
	local s = Instance.new("UIStroke")
	s.Thickness = 10
	s.Color = color
	s.Transparency = transparency
	s.Parent = f
	return f
end

local function setRingAlpha(o: GuiObject, transparency: number)
	if o:IsA("ImageLabel") then
		o.ImageTransparency = transparency
	else
		local s = o:FindFirstChildOfClass("UIStroke")
		if s then
			s.Transparency = transparency
		end
	end
end

-- The warning: a red zone that fills from the centre, its rim pulsing faster and faster, rings closing in.
function BossFx.telegraph(d)
	local r, delay = d.radius, math.max(d.delay or 1.4, 0.2)
	local size = r * RING_SPAN
	local part, g = groundCanvas(d.pos, size, 512)
	local inner = 1 / RING_SPAN * 2 -- the zone's diameter as a fraction of the canvas
	circle(g, inner, Color3.fromRGB(255, 70, 60), 0.72)
	local fill = circle(g, 0.02, Color3.fromRGB(255, 45, 35), 0.38)
	tween(fill, delay, { Size = UDim2.fromScale(inner, inner) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local rim = ringImage(g, 1, Color3.fromRGB(255, 60, 50), 0.1)
	-- two rings closing in on the rim
	for i = 0, 1 do
		task.delay(delay * 0.42 * i, function()
			if not part.Parent then
				return
			end
			local ring = ringImage(g, 1.7, Color3.fromRGB(255, 225, 215), 1)
			local time = delay * 0.55
			tween(ring, time, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local start = os.clock()
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function()
				local k = (os.clock() - start) / time
				if k >= 1 or not ring.Parent then
					conn:Disconnect()
					ring:Destroy()
					return
				end
				setRingAlpha(ring, 1 - math.sin(k * math.pi) * 0.75)
			end)
		end)
	end
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if not part.Parent then
			conn:Disconnect()
			return
		end
		local k = math.clamp(t / delay, 0, 1)
		-- pulse: speeds up as the slam comes; goes hot white in the last moment
		local pulse = 0.5 + 0.5 * math.sin(t * (10 + 26 * k))
		setRingAlpha(rim, 0.05 + 0.4 * pulse * (1 - k * 0.6))
		rim.Size = UDim2.fromScale(1 + 0.025 * pulse, 1 + 0.025 * pulse)
		if k > 0.82 then
			fill.BackgroundColor3 = Color3.fromRGB(255, 45, 35):Lerp(Color3.fromRGB(255, 235, 220), (k - 0.82) / 0.18)
		end
	end)
	Debris:AddItem(part, delay + 0.06)
end

-- A flat ring that races out along the ground and fades.
local function shockRing(pos: Vector3, radius: number, color: Color3, time: number)
	local part, g = groundCanvas(pos + Vector3.new(0, 0.05, 0), 2, 256)
	local ring = ringImage(g, 1, color, 0)
	local full = radius * RING_SPAN
	tween(part, time, { Size = Vector3.new(full, 0.05, full) }, Enum.EasingStyle.Quart)
	task.delay(time * 0.35, function()
		if ring.Parent then
			if ring:IsA("ImageLabel") then
				tween(ring, time * 0.65, { ImageTransparency = 1 })
			else
				local s = ring:FindFirstChildOfClass("UIStroke")
				if s then
					tween(s, time * 0.65, { Transparency = 1 })
				end
			end
		end
	end)
	Debris:AddItem(part, time + 0.05)
end

function BossFx.slam(d)
	local z = zoneOf(hp.name, State.world and State.world.boss and State.world.boss.z)
	local dirt = dirtColor(z)
	HitFx.play("bossSlam", d.pos, dirt, false)
	-- dust kicked up all round the rim
	local n = 9
	local off = math.random() * math.pi * 2
	for i = 1, n do
		local a = off + i / n * math.pi * 2
		local p = d.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * d.radius * rand(0.75, 0.95)
		HitFx.play("bossSlamDust", p, dirt, false)
	end
	shockRing(d.pos, d.radius * 1.35, Color3.fromRGB(255, 248, 225), 0.45)
	task.delay(0.06, shockRing, d.pos, d.radius * 0.9, UI.shade(dirt, 1.5), 0.4)
end

-- You got hit by a slam: a red flash round the screen.
function BossFx.knock()
	screenFlash(hurtFrame, 0.35, 0.4)
end

-------------------------------------------------------------------------------------------------------------
-- intro cinematic
-------------------------------------------------------------------------------------------------------------
local INTRO_LENGTH = 2.9
local INTRO_TIMEOUT = 5 -- whatever happens, the camera and controls are back by now

local controls: any = nil
local function getControls(): any
	if controls then
		return controls
	end
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			controls = ((require :: any)(module)):GetControls()
		end
	end)
	return controls
end

local function bossCard(name: string, z: number): Card
	local card = titleCard(("ZONE %d BOSS"):format(z), name:upper(), "Dodge the red circles!", 0.72, C.red or Color3.fromRGB(230, 60, 60))
	Sound.play("slam")
	return card
end

-- Dust and dirt round the boss's feet as it climbs out.
local function riseDust(centre: Vector3, radius: number, dirt: Color3)
	local n = 5
	local off = math.random() * math.pi * 2
	for i = 1, n do
		local a = off + i / n * math.pi * 2
		HitFx.play("bossRise", centre + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * rand(0.5, 0.8), dirt, false)
	end
end

local function waitForModel(timeout: number): Model?
	local deadline = os.clock() + timeout
	local m = bossModel()
	while not m and os.clock() < deadline do
		task.wait(0.05)
		m = bossModel()
	end
	return m
end

type Shot = { p0: Vector3, look0: Vector3, swoopEnd: Vector3, hero: Vector3, look: Vector3 }

-- The camera's path: swoop up and over to a spot in front of the boss, push in low while it rises, swoop back.
local function shotAt(s: Shot, t: number, back: CFrame): (Vector3, Vector3)
	if t < 1 then
		local k = easeInOut(t)
		local mid = s.p0:Lerp(s.swoopEnd, 0.5) + Vector3.new(0, 14, 0)
		local a, b = s.p0:Lerp(mid, k), mid:Lerp(s.swoopEnd, k)
		return a:Lerp(b, k), s.look0:Lerp(s.look, easeInOut(math.min(1, t / 0.85)))
	elseif t < 2.4 then
		local k = (t - 1) / 1.4
		return s.swoopEnd:Lerp(s.hero, 1 - (1 - k) ^ 2), s.look
	end
	local k = easeInOut(math.clamp((t - 2.4) / (INTRO_LENGTH - 2.4), 0, 1))
	return s.hero:Lerp(back.Position, k), s.look:Lerp(back.Position + back.LookVector * 30, k)
end

function BossFx.intro(d)
	local z = zoneOf(d.name, d.z)
	if d.hp and d.max then
		setHp(d.name, d.hp, d.max)
	end
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = myRoot()
	if intro.active or not cam or not hum or hum.Health <= 0 or not root or (root.Position - d.pos).Magnitude > 450 or cam.CameraType ~= Enum.CameraType.Custom then
		-- no cinematic (far away, dead, already in one): just the card and the roar
		local card = bossCard(d.name, z)
		Sound.play("roar")
		if BossFx.shake then
			BossFx.shake(6, 1)
		end
		shakeCard(card, 8, 0.5)
		fadeCard(card, 2.4)
		return
	end
	intro.active = true
	showBar(false)
	local saved = { cf = cam.CFrame, rootPos = root.Position, hud = UI.gui.Enabled }
	local finished = false
	local conns: { RBXScriptConnection } = {}
	local model: Model? = nil
	local basePivot: CFrame? = nil
	local card: Card? = nil

	local function backCFrame(): CFrame
		local r = myRoot()
		return saved.cf + (if r then r.Position - saved.rootPos else Vector3.zero)
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		pcall(function()
			RunService:UnbindFromRenderStep("BossIntro")
		end)
		for _, c in conns do
			c:Disconnect()
		end
		try("restore boss", function()
			local m, pivot = model, basePivot
			if m and pivot and m.Parent then
				m:PivotTo(pivot)
			end
		end)
		try("restore camera", function()
			cam.CFrame = backCFrame()
			cam.FieldOfView = BASE_FOV
			cam.CameraType = Enum.CameraType.Custom
		end)
		pcall(function()
			local c = getControls()
			if c then
				c:Enable()
			end
		end)
		UI.gui.Enabled = saved.hud
		letterbox(false)
		if card then
			fadeCard(card, 0.5)
		end
		intro.active = false
		if State.world and State.world.boss then
			showBar(true)
		end
	end
	task.delay(INTRO_TIMEOUT, finish)

	local ok = try("intro", function()
		model = waitForModel(1)
		if finished then
			return
		end
		local centre = Vector3.new(d.pos.X, 0, d.pos.Z)
		local height, width = 18, 12
		if model then
			local _, size = model:GetBoundingBox()
			height, width = size.Y, math.max(size.X, size.Z)
			basePivot = model:GetPivot()
			model:PivotTo((basePivot :: CFrame) - Vector3.new(0, height + 2, 0))
		end
		-- a low hero angle in front of the boss (it faces -Z, toward the hub), leaning toward your side
		local toYou = flat(root.Position - centre)
		local dir = flat(Vector3.new(0, 0, -2) + toYou)
		local dist = math.max(height * 1.1, 22)
		local look = centre + Vector3.new(0, height * 0.55, 0)
		local hero = centre + dir * dist + Vector3.new(0, 2.6, 0)
		local shot: Shot = {
			p0 = saved.cf.Position,
			look0 = saved.cf.Position + saved.cf.LookVector * 30,
			swoopEnd = hero + dir * 12 + Vector3.new(0, 8, 0),
			hero = hero,
			look = look,
		}
		local c = getControls()
		if c then
			c:Disable()
		end
		cam.CameraType = Enum.CameraType.Scriptable
		UI.gui.Enabled = false
		letterbox(true)
		Sound.play("whoosh")
		local t0 = os.clock()
		table.insert(conns, UserInputService.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if os.clock() - t0 > 0.6 and (kind == Enum.UserInputType.Keyboard or kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 or kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.Gamepad1) then
				finish()
			end
		end))
		table.insert(conns, hum.Died:Connect(finish))
		local dirt = dirtColor(z)
		local beats = { rise = false, roar = false, out = false, dust = 0 }
		local function step()
			local t = os.clock() - t0
			if t >= INTRO_LENGTH then
				finish()
				return
			end
			-- story beats
			if t >= 0.95 and not beats.rise then
				beats.rise = true
				Sound.play("slam")
			end
			if beats.dust < 4 and t >= 0.95 + beats.dust * 0.3 then
				beats.dust += 1
				riseDust(centre, width * 0.5, dirt)
			end
			if t >= 1.15 and not beats.roar then
				beats.roar = true
				Sound.play("roar")
				card = bossCard(d.name, z)
				shakeCard(card :: Card, 10, 0.7)
			end
			if t >= 2.4 and not beats.out then
				beats.out = true
				letterbox(false)
				if card then
					fadeCard(card, 0.1)
				end
			end
			-- the boss climbs out (overshoots a little and settles), shuddering
			local m, pivot = model, basePivot
			if m and pivot and m.Parent then
				local k = math.clamp((t - 0.95) / 0.95, 0, 1)
				local y = -(height + 2) * (1 - easeOutBack(k))
				local j = if k > 0 and k < 1 then 0.25 else 0
				m:PivotTo(pivot + Vector3.new(rand(-j, j), y, rand(-j, j)))
			end
			-- camera: path + rumble while it rises + a big shake and FOV punch on the roar
			local pos, at = shotAt(shot, t, backCFrame())
			local rumble = if t > 0.95 and t < 1.9 then 0.12 else 0
			local roar = if t > 1.15 then math.max(0, 1 - (t - 1.15) / 0.9) else 0
			local s = rumble + roar * 0.7
			pos += Vector3.new(rand(-s, s), rand(-s, s), rand(-s, s))
			cam.CFrame = CFrame.lookAt(pos, at)
			cam.FieldOfView = BASE_FOV - 10 * roar * roar
		end
		RunService:BindToRenderStep("BossIntro", Enum.RenderPriority.Camera.Value + 1, function()
			if finished then
				return
			end
			if not try("intro step", step) then
				finish()
			end
		end)
	end)
	if not ok then
		finish()
	end
end

-------------------------------------------------------------------------------------------------------------
-- death
-------------------------------------------------------------------------------------------------------------
local death = { at = -100, card = nil :: Card?, reward = nil :: any, shown = false }

local function rewardLine(card: Card, d)
	local row = Instance.new("Frame")
	row.Name = "Reward"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 194)
	row.Size = UDim2.fromOffset(520, 48)
	row.Parent = card.root
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 26)
	list.Parent = row
	local function chip(order: number, icon: (Instance, number, UDim2?) -> GuiObject, text: string, color: Color3)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(220, 48)
		f.LayoutOrder = order
		f.Parent = row
		icon(f, 44, UDim2.fromOffset(0, 2))
		UI.text(f, text, UDim2.fromOffset(170, 40), { pos = UDim2.fromOffset(50, 4), align = Enum.TextXAlignment.Left, color = color, stroke = 3 })
		UI.bounce(f)
	end
	chip(1, UI.coinIcon, "+" .. Format.short(d.coins or 0), C.yellow or GOLD)
	chip(2, UI.gemIcon, "+" .. tostring(d.gems or 0), C.purple or Color3.fromRGB(190, 120, 255))
	Sound.play("purchase")
	State.emit("flyCoins", 10)
end

-- "BOSS DEFEATED!" with the boss's name, confetti, and the reward when it's here.
local function defeatedCard(name: string)
	local card = titleCard("VICTORY", "BOSS DEFEATED!", name:upper(), 0.36, C.green or Color3.fromRGB(80, 210, 80))
	death.card = card
	shakeCard(card, 6, 0.35)
	Sound.play("victory")
	Confetti.burst(150)
	task.delay(0.5, Confetti.burst, 90)
	if death.reward then
		rewardLine(card, death.reward)
	end
	-- gone before the server's "zone open" banner (3 s after the kill)
	fadeCard(card, 1.6)
end

-- A copy of the boss (the server deletes the real one) holds still, flashes, swells and pops.
local function popModel(model: Model, color: Color3, onPop: (Vector3) -> ())
	local cf, size = model:GetBoundingBox()
	local mid = cf.Position
	local copy = model:Clone()
	for _, x in copy:GetDescendants() do
		if x:IsA("BasePart") then
			x.Anchored = true
			x.CanCollide = false
			x.CanQuery = false
		elseif x:IsA("BillboardGui") or x:IsA("Highlight") then
			x:Destroy()
		end
	end
	copy.PrimaryPart = nil
	copy.WorldPivot = CFrame.new(mid.X, mid.Y - size.Y / 2, mid.Z)
	local h = Instance.new("Highlight")
	h.FillColor = WHITE
	h.FillTransparency = 0
	h.OutlineColor = color
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = copy
	copy.Parent = folder
	-- hide the real one here
	for _, x in model:GetDescendants() do
		if x:IsA("BasePart") then
			x.LocalTransparencyModifier = 1
		elseif x:IsA("BillboardGui") then
			x.Enabled = false
		end
	end
	local base = copy:GetPivot()
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local ok = try("pop", function()
			local t = os.clock() - start
			if t >= 0.85 or not copy.Parent then
				conn:Disconnect()
				copy:Destroy()
				onPop(mid)
				return
			end
			if t < 0.32 then
				-- frozen in a white flash
				h.FillTransparency = 0.05
				return
			end
			local k = (t - 0.32) / 0.53
			local j = 0.15 + k * 0.6
			h.FillTransparency = if math.floor(t * 16) % 2 == 0 then 0.05 else 0.6
			copy:ScaleTo(1 + 0.32 * k * k)
			copy:PivotTo(base * CFrame.new(rand(-j, j), 0, rand(-j, j)))
		end)
		if not ok then
			conn:Disconnect()
			copy:Destroy()
		end
	end)
end

function BossFx.down(d)
	local z = zoneOf(d.name, d.z)
	local color = bossColor(z)
	death.at, death.card, death.reward = os.clock(), nil, nil
	setHp(d.name or hp.name, 0, hp.max)
	task.delay(1.4, function()
		if not (State.world and State.world.boss) then
			showBar(false)
		end
	end)
	-- the killing blow: freeze, flash, FOV punch, colours drain for a moment
	State.emit("hitstop", 0.3)
	screenFlash(flashFrame, 0.7, 0.35)
	Sound.play("hit")
	local cam = workspace.CurrentCamera
	if cam and not intro.active and cam.CameraType == Enum.CameraType.Custom then
		CameraView.kick(12)
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "BossFxGrade"
		grade.Saturation = -0.6
		grade.Contrast = 0.2
		grade.Brightness = 0.06
		grade.Parent = cam
		task.delay(0.3, function()
			tween(grade, 0.35, { Saturation = 0, Contrast = 0, Brightness = 0 })
		end)
		Debris:AddItem(grade, 0.7)
	end
	local function onPop(mid: Vector3)
		HitFx.play("bossDeath", mid, color, false)
		screenFlash(flashFrame, 0.85, 0.5)
		Sound.play("slam")
		if BossFx.shake then
			BossFx.shake(10, 0.7)
		end
		task.delay(0.25, function()
			try("defeated card", defeatedCard, d.name or hp.name)
		end)
	end
	local m = bossModel()
	if m then
		popModel(m, color, onPop)
	else
		task.delay(0.6, onPop, d.pos + Vector3.new(0, 8, 0))
	end
end

-- The personal reward. Shown under "BOSS DEFEATED!" when that card is (about to be) up; returns false otherwise
-- so Fx shows its usual banner.
function BossFx.reward(d): boolean
	if os.clock() - death.at > 2.5 then
		return false
	end
	death.reward = d
	if death.card and death.card.root.Parent then
		rewardLine(death.card, d)
	end
	return true
end

-- for client/BossCine (the revamp's cutscenes): the bar, the title cards, the letterbox, the defeated card
BossFx.cinematic = false
BossFx.showBar = showBar
BossFx.setPhase = setPhase
BossFx.titleCard = titleCard
BossFx.fadeCard = fadeCard
BossFx.shakeCard = shakeCard
BossFx.letterbox = letterbox
BossFx.defeatedCard = defeatedCard
BossFx.screenFlash = function(color: Color3, strength: number, time: number)
	screenFlash(overlay(color, "Flash"), strength, time)
end
BossFx.resetHp = function()
	hp.name = ""
end

return BossFx
