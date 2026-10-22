-- The screen side of the run's opening cutscene (client/Intro): letterbox bars, a fade to and from black, the
-- lower-third name cards, the Mayor's speech box with typed-out text, the old-film look of the flashback, the
-- big title card and the SKIP button. Everything lives in its own ScreenGui above the HUD, which Intro hides
-- while the cutscene plays.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sound = require(script.Parent.Sound)
local UI = require(script.Parent.UI)

local IntroUi = {}
local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 236, 110)
local ORANGE = Color3.fromRGB(255, 140, 30)
local GREEN = Color3.fromRGB(110, 220, 70)
local BAR = 0.11 -- letterbox bar height (share of the screen)

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function fadeAll(root: Instance, time: number)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			tween(d, time, { TextTransparency = 1, BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, time, { Transparency = 1 })
		elseif d:IsA("Frame") then
			tween(d, time, { BackgroundTransparency = 1 })
		end
	end
end

local gui: ScreenGui? = nil
local layer: Frame? = nil -- the 1280x720 scaled layer (cards, speech, skip)
local barTop: Frame? = nil
local barBottom: Frame? = nil
local cover: Frame? = nil
local film: Frame? = nil
local speech: { root: Frame, name: TextLabel, text: TextLabel }? = nil
local typing = 0 -- bumps to stop an older typewriter

local function screen(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "IntroCinema"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 20
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = player:WaitForChild("PlayerGui")
	return g
end

local function plain(parent: Instance, name: string, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

-- Dark edges and a warm wash for the flashback (no image assets: four gradient bands).
local function buildFilm(parent: Instance): Frame
	local f = plain(parent, "Film", BLACK, 1, 2)
	f.Visible = false
	local function edge(name: string, size: UDim2, pos: UDim2, rotation: number)
		local e = plain(f, name, Color3.fromRGB(40, 22, 8), 0, 2)
		e.Size = size
		e.Position = pos
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = e
	end
	edge("Left", UDim2.fromScale(0.28, 1), UDim2.fromScale(0, 0), 0)
	edge("Right", UDim2.fromScale(0.28, 1), UDim2.fromScale(0.72, 0), 180)
	edge("Top", UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0), 90)
	edge("Bottom", UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0.66), -90)
	local label = Instance.new("TextLabel")
	label.Name = "LongAgo"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.new(0.05, 0, BAR + 0.04, 0)
	label.Size = UDim2.fromScale(0.5, 0.08)
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.Text = "Long ago..."
	label.ZIndex = 3
	label.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(60, 34, 12)
	s.Parent = label
	return f
end

local function buildSpeech(parent: Instance)
	local root = UI.frame({ size = UDim2.fromOffset(780, 104), pos = UDim2.new(0.5, 0, 1, -98), anchor = Vector2.new(0.5, 1), color = Color3.fromRGB(28, 22, 36), parent = parent, radius = 18, outline = 3, name = "Speech", transparency = 0.12 })
	root.Visible = false
	local plate = UI.frame({ size = UDim2.fromOffset(270, 38), pos = UDim2.fromOffset(26, -20), color = ORANGE, parent = root, radius = 12, outline = 3, name = "Plate" })
	UI.gradient(plate, ORANGE)
	local name = UI.text(plate, "", UDim2.new(1, -16, 1, -8), { pos = UDim2.fromOffset(8, 4), stroke = 2.5 })
	local text = UI.text(root, "", UDim2.new(1, -48, 1, -34), { pos = UDim2.fromOffset(24, 24), stroke = 2.5, align = Enum.TextXAlignment.Left })
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextScaled = false
	text.TextSize = 30
	text.TextWrapped = true
	speech = { root = root, name = name, text = text }
end

-- Build the screen. `onSkip` runs when SKIP is pressed.
function IntroUi.open(onSkip: () -> ())
	IntroUi.close()
	local g = screen()
	gui = g
	cover = plain(g, "Cover", BLACK, 0, 10)
	film = buildFilm(g)
	local function bar(top: boolean): Frame
		local f = plain(g, if top then "BarTop" else "BarBottom", BLACK, 0, 4)
		f.Size = UDim2.fromScale(1, BAR)
		f.Position = if top then UDim2.fromScale(0, -BAR) else UDim2.fromScale(0, 1)
		return f
	end
	barTop, barBottom = bar(true), bar(false)
	local l = Instance.new("Frame")
	l.Name = "Layer"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.Size = UDim2.fromOffset(1280, 720)
	l.ZIndex = 5
	l.Parent = g
	local sc = Instance.new("UIScale")
	sc.Parent = l
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		sc.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.45, 1.6)
		l.Size = UDim2.fromOffset(vp.X / sc.Scale, vp.Y / sc.Scale)
	end
	rescale()
	local cam = workspace.CurrentCamera
	if cam then
		local conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		l.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end
	layer = l
	buildSpeech(l)
	local skip = UI.button(l, "SKIP  >>", Color3.fromRGB(70, 70, 86), UDim2.fromOffset(150, 48), onSkip, { pos = UDim2.new(1, -24, 1, -18), anchor = Vector2.new(1, 1), name = "IntroSkip" })
	skip.ZIndex = 8
end

function IntroUi.close()
	typing += 1
	if gui then
		gui:Destroy()
	end
	gui, layer, barTop, barBottom, cover, film, speech = nil, nil, nil, nil, nil, nil, nil
end

function IntroUi.letterbox(on: boolean, time: number?)
	local t = time or 0.5
	if barTop and barBottom then
		tween(barTop, t, { Position = UDim2.fromScale(0, if on then 0 else -BAR) }, Enum.EasingStyle.Quart)
		tween(barBottom, t, { Position = UDim2.fromScale(0, if on then 1 - BAR else 1) }, Enum.EasingStyle.Quart)
	end
end

-- Fade the black cover: to = 0 (black) or 1 (clear).
function IntroUi.fade(to: number, time: number)
	if cover then
		tween(cover, time, { BackgroundTransparency = to }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
end

-- A quick white flash (a cut into or out of the flashback).
function IntroUi.flash(strength: number, time: number)
	local g = gui
	if not g then
		return
	end
	local f = plain(g, "Flash", WHITE, 1 - strength, 9)
	tween(f, time, { BackgroundTransparency = 1 })
	task.delay(time + 0.05, function()
		f:Destroy()
	end)
end

-- The flashback's old-film edges and caption; they flicker a little while shown.
function IntroUi.film(on: boolean)
	local f = film
	if not f then
		return
	end
	f.Visible = on
	if not on then
		return
	end
	task.spawn(function()
		while f.Parent and f.Visible do
			f.BackgroundTransparency = 0.88 + math.random() * 0.1
			task.wait(0.06)
		end
	end)
end

-- A name card sliding in at the top left (under the letterbox bar, clear of the speech box): a coloured stripe, a big title, a small line under it.
function IntroUi.lowerThird(title: string, sub: string, color: Color3?, life: number?)
	local l = layer
	if not l then
		return
	end
	local root = Instance.new("Frame")
	root.Name = "LowerThird"
	root.BackgroundTransparency = 1
	root.Position = UDim2.new(0, -520, BAR, 18)
	root.Size = UDim2.fromOffset(520, 110)
	root.Parent = l
	local stripe = UI.frame({ size = UDim2.fromOffset(10, 92), pos = UDim2.fromOffset(40, 8), color = color or GREEN, parent = root, radius = 4, outline = 0, name = "Stripe" })
	stripe.ZIndex = 6
	local t = UI.text(root, title, UDim2.fromOffset(460, 58), { pos = UDim2.fromOffset(62, 4), stroke = 5, align = Enum.TextXAlignment.Left, name = "Title" })
	t.ZIndex = 6
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(WHITE, color or GREEN)
	g.Rotation = 90
	g.Parent = t
	local s = UI.text(root, sub, UDim2.fromOffset(460, 30), { pos = UDim2.fromOffset(64, 66), stroke = 3, align = Enum.TextXAlignment.Left, name = "Sub" })
	s.ZIndex = 6
	tween(root, 0.45, { Position = UDim2.new(0, 0, BAR, 18) }, Enum.EasingStyle.Back)
	Sound.play("whoosh", 0.1, 0.25)
	task.delay(life or 2.6, function()
		if root.Parent then
			tween(root, 0.35, { Position = UDim2.new(0, -560, BAR, 18) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.4, function()
				root:Destroy()
			end)
		end
	end)
end

-- The speech box: `who` on the name plate, `line` typed out letter by letter with little ticks.
function IntroUi.say(who: string, line: string, cps: number?)
	local sp = speech
	if not sp then
		return
	end
	typing += 1
	local mine = typing
	sp.root.Visible = true
	sp.name.Text = who
	sp.text.Text = line
	sp.text.MaxVisibleGraphemes = 0
	local sc = sp.root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	sc.Parent = sp.root
	sc.Scale = 0.9
	tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	local rate = cps or 40
	task.spawn(function()
		local shown = 0
		local total = utf8.len(line) or #line
		local start = os.clock()
		while shown < total and typing == mine and sp.root.Parent do
			RunService.RenderStepped:Wait()
			local n = math.min(total, math.floor((os.clock() - start) * rate))
			if n > shown then
				if math.floor(n / 3) > math.floor(shown / 3) then
					Sound.playAt("chip", 1.7 + math.random() * 0.5, 0.08)
				end
				shown = n
				sp.text.MaxVisibleGraphemes = n
			end
		end
		if typing == mine then
			sp.text.MaxVisibleGraphemes = -1
		end
	end)
end

function IntroUi.hush()
	typing += 1
	if speech then
		speech.root.Visible = false
	end
end

-- The title card: a kicker pill, the game's name huge in two tones, a line under it. Punches in and shakes.
function IntroUi.title(kicker: string, title: string, sub: string): (number) -> ()
	local l = layer
	if not l then
		return function(_: number) end
	end
	local root = Instance.new("Frame")
	root.Name = "TitleCard"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.42)
	root.Size = UDim2.fromOffset(1100, 240)
	root.ZIndex = 7
	root.Parent = l
	local pill = UI.frame({ size = UDim2.fromOffset(300, 40), pos = UDim2.new(0.5, 0, 0, 22), anchor = Vector2.new(0.5, 0.5), color = GREEN, parent = root, radius = 18, outline = 3 })
	UI.gradient(pill, GREEN)
	UI.text(pill, kicker, UDim2.new(1, -20, 1, -8), { pos = UDim2.fromOffset(10, 4), stroke = 2.5 })
	local name = UI.text(root, title, UDim2.new(1, 0, 0, 132), { pos = UDim2.fromOffset(0, 46), stroke = 7 })
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.52, GOLD),
		ColorSequenceKeypoint.new(0.56, ORANGE),
		ColorSequenceKeypoint.new(1, UI.shade(ORANGE, 0.85)),
	})
	g.Rotation = 90
	g.Parent = name
	name.Rotation = -5
	tween(name, 0.32, { Rotation = 0 }, Enum.EasingStyle.Back)
	UI.text(root, sub, UDim2.new(1, 0, 0, 36), { pos = UDim2.fromOffset(0, 186), stroke = 3.5 })
	local sc = Instance.new("UIScale")
	sc.Scale = 2.4
	sc.Parent = root
	tween(sc, 0.26, { Scale = 1 }, Enum.EasingStyle.Back)
	-- shake for a moment after it lands
	task.delay(0.22, function()
		local start = os.clock()
		while root.Parent and os.clock() - start < 0.45 do
			local p = 10 * (1 - (os.clock() - start) / 0.45)
			root.Position = UDim2.new(0.5, (math.random() - 0.5) * p * 2, 0.42, (math.random() - 0.5) * p * 2)
			RunService.RenderStepped:Wait()
		end
		if root.Parent then
			root.Position = UDim2.fromScale(0.5, 0.42)
		end
	end)
	return function(time: number)
		if root.Parent then
			fadeAll(root, time)
			tween(sc, time, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(time + 0.05, function()
				root:Destroy()
			end)
		end
	end
end

return IntroUi
