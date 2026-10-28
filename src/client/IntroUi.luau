-- The screen side of the films (client/Intro, client/Ending): letterbox bars (cut to the cinema's 2.35:1 shape), a
-- fade to and from black, the lower-third name cards, subtitles (the speaker's name over the line, shown whole and
-- quietly, like a film's; no typing blips), the narrator's lines, small captions ("LONG AGO..."), the old-film look
-- of a flashback, the big title card and the SKIP button. Everything lives in its own ScreenGui above the HUD, which
-- the films hide while they play. Sound is the films' own (client/FilmAudio): nothing here makes a noise.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local IntroUi = {}
local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 236, 110)
local ORANGE = Color3.fromRGB(255, 140, 30)
local GREEN = Color3.fromRGB(110, 220, 70)
local BAR = 0.11 -- letterbox bar height (share of the screen; set to the 2.35:1 shape of the screen in open)
local SUB_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local NAME_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local TALE_FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)

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
local speech: { root: Frame, name: TextLabel, text: TextLabel, back: Frame }? = nil
local tale: TextLabel? = nil
local typing = 0 -- bumps to stop an older typewriter

-- The game's other screens (stock alerts, boss bars, dev tools) are hidden while a film plays and come back after;
-- the films' own screens (and the one that frees the mouse for SKIP) stay.
local KEEP = {
	IntroCinema = true, FilmPicture = true, GlitchFx = true, WorldTwoTitle = true, EndingSnapshot = true,
	EndCredits = true, MowConfetti = true, MowFreeMouse = true,
}
local hiddenGuis: { [ScreenGui]: RBXScriptConnection } = {}
local guiAdded: RBXScriptConnection? = nil

local function hideOthers(on: boolean)
	if not on then
		if guiAdded then
			guiAdded:Disconnect()
			guiAdded = nil
		end
		for g, conn in hiddenGuis do
			conn:Disconnect()
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenGuis)
		return
	end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local function hide(g: Instance)
		if g:IsA("ScreenGui") and not KEEP[g.Name] and g.Enabled and not hiddenGuis[g] then
			g.Enabled = false
			-- (whatever turns it back on mid-film is turned off again)
			hiddenGuis[g] = g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if g.Enabled then
					g.Enabled = false
				end
			end)
		end
	end
	for _, g in pg:GetChildren() do
		hide(g)
	end
	if not guiAdded then
		guiAdded = pg.ChildAdded:Connect(hide)
	end
end

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

-- the subtitles: the speaker's name (small, gold, spaced out) over the line (white, on a soft dark band)
local function buildSpeech(parent: Instance)
	local root = Instance.new("Frame")
	root.Name = "Subtitles"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -108)
	root.Size = UDim2.fromOffset(980, 96)
	root.Visible = false
	root.Parent = parent
	local back = Instance.new("Frame")
	back.Name = "Band"
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, 0)
	back.Size = UDim2.new(1, 0, 0, 62)
	back.BackgroundColor3 = BLACK
	back.BackgroundTransparency = 1
	back.BorderSizePixel = 0
	back.Parent = root
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = back
	local name = Instance.new("TextLabel")
	name.Name = "Speaker"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -64)
	name.Size = UDim2.new(1, 0, 0, 22)
	name.FontFace = NAME_FONT
	name.TextSize = 17
	name.TextColor3 = GOLD
	name.Text = ""
	name.Parent = root
	local ns = Instance.new("UIStroke")
	ns.Thickness = 1.5
	ns.Transparency = 0.3
	ns.Parent = name
	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Position = UDim2.new(0.5, 0, 1, -6)
	text.Size = UDim2.new(1, -40, 0, 54)
	text.FontFace = SUB_FONT
	text.TextSize = 28
	text.TextWrapped = true
	text.TextColor3 = WHITE
	text.Text = ""
	text.Parent = root
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Transparency = 0.25
	ts.Parent = text
	speech = { root = root, name = name, text = text, back = back }
	-- the narrator: centred, a storybook italic
	local t = Instance.new("TextLabel")
	t.Name = "Narration"
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 1)
	t.Position = UDim2.new(0.5, 0, 1, -112)
	t.Size = UDim2.fromOffset(1000, 80)
	t.FontFace = TALE_FONT
	t.TextSize = 32
	t.TextWrapped = true
	t.TextColor3 = Color3.fromRGB(255, 246, 228)
	t.TextTransparency = 1
	t.Text = ""
	t.Parent = parent
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = Color3.fromRGB(40, 24, 10)
	st.Transparency = 1
	st.Parent = t
	tale = t
end

-- Build the screen. `onSkip` runs when SKIP is pressed.
function IntroUi.open(onSkip: () -> ())
	IntroUi.close()
	local g = screen()
	gui = g
	local cam0 = workspace.CurrentCamera
	local vp0 = if cam0 then cam0.ViewportSize else Vector2.new(1280, 720)
	BAR = math.clamp((1 - (vp0.X / math.max(vp0.Y, 1)) / 2.35) / 2, 0.05, 0.13)
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
	skip.Modal = true -- (frees the mouse in first person from the first black frame, so SKIP can always be clicked)
	hideOthers(true)
end

function IntroUi.close()
	hideOthers(false)
	typing += 1
	if gui then
		gui:Destroy()
	end
	gui, layer, barTop, barBottom, cover, film, speech, tale = nil, nil, nil, nil, nil, nil, nil, nil
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
	task.delay(life or 2.6, function()
		if root.Parent then
			tween(root, 0.35, { Position = UDim2.new(0, -560, BAR, 18) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.4, function()
				root:Destroy()
			end)
		end
	end)
end

-- A subtitle: `who` over `line`, shown whole with a soft fade and rise (no sound: a voice, if there is one, is the
-- film's). `life`: seconds until it fades by itself (default: it stays until the next line or hush).
function IntroUi.say(who: string, line: string, life: number?)
	local sp = speech
	if not sp then
		return
	end
	typing += 1
	local mine = typing
	sp.root.Visible = true
	sp.name.Text = string.upper(who)
	sp.text.Text = line
	for _, l in { sp.name, sp.text } do
		l.TextTransparency = 1
		tween(l, 0.22, { TextTransparency = 0 })
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = 1
			tween(st, 0.22, { Transparency = 0.25 })
		end
	end
	sp.back.BackgroundTransparency = 1
	tween(sp.back, 0.25, { BackgroundTransparency = 0.35 })
	sp.text.Position = UDim2.new(0.5, 0, 1, 2)
	tween(sp.text, 0.3, { Position = UDim2.new(0.5, 0, 1, -6) }, Enum.EasingStyle.Quart)
	if life then
		task.delay(life, function()
			if typing == mine then
				IntroUi.hush()
			end
		end)
	end
end

-- The narrator (a storybook voice over the pictures): a centred italic line that fades in and, after `life`, out.
function IntroUi.narrate(line: string, life: number?)
	local t = tale
	if not t then
		return
	end
	typing += 1
	if speech then
		speech.root.Visible = false
	end
	t.Text = line
	t.TextTransparency = 1
	local st = t:FindFirstChildOfClass("UIStroke")
	tween(t, 0.6, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
	if st then
		st.Transparency = 1
		tween(st, 0.6, { Transparency = 0.4 }, Enum.EasingStyle.Sine)
	end
	local mine = typing
	task.delay(life or 3.5, function()
		if t.Parent and typing == mine then
			tween(t, 0.6, { TextTransparency = 1 }, Enum.EasingStyle.Sine)
			if st then
				tween(st, 0.6, { Transparency = 1 }, Enum.EasingStyle.Sine)
			end
		end
	end)
end

-- A small caption at the top left, letter-spaced ("LONG AGO...", "PRESENT DAY"), fading in and out.
function IntroUi.caption(text: string, life: number?)
	local l = layer
	if not l then
		return
	end
	local c = Instance.new("TextLabel")
	c.Name = "Caption"
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(0, 0)
	c.Position = UDim2.new(0, 48, BAR, 26)
	c.Size = UDim2.fromOffset(600, 34)
	c.FontFace = NAME_FONT
	c.TextSize = 22
	c.TextXAlignment = Enum.TextXAlignment.Left
	c.TextColor3 = Color3.fromRGB(255, 244, 226)
	c.TextTransparency = 1
	c.Text = string.gsub(string.upper(text), "(.)", "%1 ")
	c.ZIndex = 6
	c.Parent = l
	local st = Instance.new("UIStroke")
	st.Thickness = 1.5
	st.Transparency = 1
	st.Parent = c
	tween(c, 0.8, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
	tween(st, 0.8, { Transparency = 0.4 }, Enum.EasingStyle.Sine)
	task.delay(life or 3, function()
		if c.Parent then
			tween(c, 0.8, { TextTransparency = 1 }, Enum.EasingStyle.Sine)
			tween(st, 0.8, { Transparency = 1 }, Enum.EasingStyle.Sine)
			task.delay(0.85, function()
				c:Destroy()
			end)
		end
	end)
end

function IntroUi.hush()
	typing += 1
	local sp = speech
	if sp then
		for _, l in { sp.name, sp.text } do
			tween(l, 0.2, { TextTransparency = 1 })
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then
				tween(st, 0.2, { Transparency = 1 })
			end
		end
		tween(sp.back, 0.2, { BackgroundTransparency = 1 })
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
	-- a shockwave ring bursting out from behind the name as it lands
	task.delay(0.2, function()
		if not root.Parent then
			return
		end
		local ring = Instance.new("Frame")
		ring.Name = "Shockwave"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.new(0.5, 0, 0, 112)
		ring.Size = UDim2.fromOffset(120, 120)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 6
		ring.Parent = root
		UI.corner(ring, 999)
		local edge = Instance.new("UIStroke")
		edge.Thickness = 10
		edge.Color = GOLD
		edge.Parent = ring
		tween(ring, 0.55, { Size = UDim2.fromOffset(1300, 1300) }, Enum.EasingStyle.Quart)
		tween(edge, 0.55, { Transparency = 1, Thickness = 2 }, Enum.EasingStyle.Quad)
		task.delay(0.6, function()
			ring:Destroy()
		end)
	end)
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

-- A guardian's name slamming in for the roll call (client/Intro): a pill ("GUARDIAN 3 OF 8") in its colour, its
-- name huge in two tones, its title under it. Low in the frame (the boss fills the top), gone after `life`.
function IntroUi.bossCard(kicker: string, name: string, title: string, color: Color3, life: number)
	local l = layer
	if not l then
		return
	end
	local root = Instance.new("Frame")
	root.Name = "BossCard"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, 0, 1 - BAR, -112)
	root.Size = UDim2.fromOffset(1000, 170)
	root.ZIndex = 7
	root.Parent = l
	local pill = UI.frame({ size = UDim2.fromOffset(260, 34), pos = UDim2.new(0.5, 0, 0, 18), anchor = Vector2.new(0.5, 0.5), color = color, parent = root, radius = 16, outline = 3 })
	UI.gradient(pill, color)
	UI.text(pill, kicker, UDim2.new(1, -20, 1, -8), { pos = UDim2.fromOffset(10, 4), stroke = 2.5 })
	local big = UI.text(root, name, UDim2.new(1, 0, 0, 88), { pos = UDim2.fromOffset(0, 38), stroke = 6 })
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(0.56, color),
		ColorSequenceKeypoint.new(1, UI.shade(color, 0.8)),
	})
	g.Rotation = 90
	g.Parent = big
	big.Rotation = -4
	tween(big, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
	UI.text(root, title, UDim2.new(1, 0, 0, 34), { pos = UDim2.fromOffset(0, 128), stroke = 3.5 })
	local sc = Instance.new("UIScale")
	sc.Scale = 1.9
	sc.Parent = root
	tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(life, function()
		if root.Parent then
			fadeAll(root, 0.12)
			task.delay(0.15, function()
				root:Destroy()
			end)
		end
	end)
end

return IntroUi
