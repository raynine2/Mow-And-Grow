-- The loading screen. Over the ForgeGUI meadow painting (or a deep green-to-blue sky until it has loaded): the
-- drawn MOW A LAWN logo (ForgeGUI, grass growing out of the letters) popping in on a soft warm glow with a drop
-- shadow and a few twinkling sparkles, and the progress bar is a strip of tall grass that a little push mower mows
-- from left to right as the game loads, clippings flying, the mowed part in light/dark lawn stripes, the percentage
-- riding above the mower. Under it a pill with a line that changes every couple of seconds (tips and silly jobs:
-- "Sharpening the blades..."), and your avatar's face and name in the corner.
-- Self-contained (no client modules): the boot script in ReplicatedFirst uses it on arrival, client/Loading before a
-- teleport. Pictures come from IconIds; anything not loaded yet simply isn't drawn (the shapes still work).
-- Progress: LoadingScreen.setProgress(gui, 0..1); between calls it creeps forward on its own up to `cap`, so it
-- never sits still and never runs ahead of the real loading.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local IconIds = require(script.Parent:WaitForChild("IconIds")) :: { [string]: string }
local gameName = "Mow A Lawn"
pcall(function()
	gameName = (require(script.Parent:WaitForChild("Config")) :: any).GAME_NAME or gameName
end)

local LoadingScreen = {}

local WHITE = Color3.fromRGB(250, 250, 252)
local INK = Color3.fromRGB(58, 32, 14) -- the art's dark-brown outline
local FONT = Enum.Font.FredokaOne
local LANE_W, LANE_H = 760, 74
local LANE_X, LANE_Y = 640 - LANE_W / 2, 548 -- the lane's top-left in the 1280 x 720 stage

local LINES = {
	"Sharpening the blades",
	"Watering the lawn",
	"Tip: rare grass glows - cut it first!",
	"Waking up the critters",
	"Tip: bigger bags mean fewer trips to the shredder",
	"Counting the clovers",
	"Tip: Hold upgrade = keep the button down to keep cutting",
	"Fuelling the mowers",
	"Tip: equip pets in the Pets window for a team boost",
	"Raking the paths",
}

local function img(parent: Instance, key: string, size: UDim2, pos: UDim2, anchor: Vector2?): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = key
	i.BackgroundTransparency = 1
	i.Image = IconIds[key] or ""
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = size
	i.Position = pos
	i.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	i.Parent = parent
	return i
end

local function frame(parent: Instance, size: UDim2, pos: UDim2, color: Color3, radius: number?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function text(parent: Instance, t: string, size: UDim2, pos: UDim2, stroke: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = t
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	local s = Instance.new("UIStroke")
	s.Thickness = stroke
	s.Color = INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = l
	l.Parent = parent
	return l
end

-- the title: the drawn logo (or big chunky letters while it isn't uploaded) on a soft warm glow, with a drop shadow,
-- and sparkles twinkling around it
local LOGO = Vector2.new(660, 436) -- (the picture is 955 x 631)
local SPARKLES = { { 318, 112, 40 }, { 968, 96, 34 }, { 1010, 318, 46 }, { 262, 330, 30 }, { 740, 30, 26 }, { 520, 418, 24 } }
type Title = { logo: GuiObject, pop: UIScale, glows: { ImageLabel }, sparkles: { ImageLabel } }
local function title(stage: Frame): Title
	local glows = {}
	for _, gl in { { 1040, 640, Color3.fromRGB(255, 226, 140), 0.3 }, { 620, 380, Color3.new(1, 1, 1), 0.5 } } do
		local g = img(stage, "glow_soft", UDim2.fromOffset(gl[1], gl[2]), UDim2.fromOffset(640, 236))
		g.ScaleType = Enum.ScaleType.Stretch
		g.ImageColor3 = gl[3]
		g.ImageTransparency = gl[4]
		table.insert(glows, g)
	end
	local logo: GuiObject
	if IconIds.logo then
		local shadow = img(stage, "logo", UDim2.fromOffset(LOGO.X, LOGO.Y), UDim2.fromOffset(648, 248))
		shadow.Name = "LogoShadow"
		shadow.ImageColor3 = Color3.fromRGB(20, 30, 10)
		shadow.ImageTransparency = 0.55
		logo = img(stage, "logo", UDim2.fromOffset(LOGO.X, LOGO.Y), UDim2.fromOffset(640, 236))
		-- (the shadow follows the logo's pop and breath: its own scale is set to the same value each frame)
		Instance.new("UIScale").Parent = shadow
	else
		local t = text(stage, string.upper(gameName), UDim2.fromOffset(900, 150), UDim2.fromOffset(640, 230), 9)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 250, 120))
		g.Rotation = 90
		g.Parent = t
		t.Rotation = -3
		logo = t
	end
	local pop = Instance.new("UIScale")
	pop.Scale = 0.35
	pop.Parent = logo
	local sparkles = {}
	for i, sp in SPARKLES do
		local s = img(stage, "sparkle", UDim2.fromOffset(sp[3], sp[3]), UDim2.fromOffset(sp[1], sp[2]))
		s.ImageColor3 = if i % 2 == 0 then Color3.fromRGB(255, 240, 170) else Color3.new(1, 1, 1)
		table.insert(sparkles, s)
	end
	return { logo = logo, pop = pop, glows = glows, sparkles = sparkles }
end

-- the lane: uncut tall grass on the right of the mower, mowed stripes on the left of it
type Lane = { mowed: Frame, uncut: Frame, grass: Frame, mower: GuiObject, pct: TextLabel }
local function lane(stage: Frame): Lane
	-- the soil it all stands on
	local soil = frame(stage, UDim2.fromOffset(LANE_W + 24, 30), UDim2.fromOffset(LANE_X - 12, LANE_Y + LANE_H - 18), Color3.fromRGB(110, 70, 36), 15)
	local ss = Instance.new("UIStroke")
	ss.Thickness = 4
	ss.Color = INK
	ss.Parent = soil
	-- mowed: a short lawn with light and dark stripes, revealed as the mower goes
	local mowed = frame(stage, UDim2.fromOffset(0, 26), UDim2.fromOffset(LANE_X, LANE_Y + LANE_H - 32), Color3.fromRGB(120, 205, 70))
	mowed.Name = "Mowed"
	mowed.ClipsDescendants = true
	for i = 0, math.ceil(LANE_W / 38) do
		local stripe = frame(mowed, UDim2.fromOffset(19, 26), UDim2.fromOffset(i * 38, 0), Color3.fromRGB(150, 226, 92))
		stripe.Name = "Stripe"
	end
	-- uncut: the ForgeGUI grass strip tiled across the lane (a green bar if it isn't there)
	local uncut = frame(stage, UDim2.fromOffset(LANE_W, LANE_H), UDim2.fromOffset(LANE_X, LANE_Y), WHITE)
	uncut.Name = "Uncut"
	uncut.BackgroundTransparency = 1
	uncut.ClipsDescendants = true
	local grass = frame(uncut, UDim2.fromOffset(LANE_W, LANE_H), UDim2.fromOffset(0, 0), WHITE)
	grass.BackgroundTransparency = 1
	if IconIds.ui_grass then
		local tw = math.floor(LANE_H * 921 / 271)
		for x = -10, LANE_W, tw - 18 do
			img(grass, "ui_grass", UDim2.fromOffset(tw, LANE_H), UDim2.fromOffset(x, 0), Vector2.zero)
		end
	else
		frame(grass, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 1, -40), Color3.fromRGB(70, 170, 60), 10)
	end
	-- the mower, facing right (the picture faces left, so it's drawn mirrored)
	local mower: GuiObject
	if IconIds.pushmower then
		local m = img(stage, "pushmower", UDim2.fromOffset(108, 104), UDim2.fromOffset(LANE_X, LANE_Y + LANE_H - 6), Vector2.new(0.55, 1))
		m.ImageRectOffset = Vector2.new(512, 0)
		m.ImageRectSize = Vector2.new(-512, 495)
		mower = m
	else
		mower = frame(stage, UDim2.fromOffset(60, 44), UDim2.fromOffset(LANE_X, LANE_Y + LANE_H - 6), Color3.fromRGB(230, 70, 60), 12)
		mower.AnchorPoint = Vector2.new(0.5, 1)
	end
	local pct = text(stage, "0%", UDim2.fromOffset(96, 34), UDim2.fromOffset(LANE_X, LANE_Y - 50), 3.5)
	return { mowed = mowed, uncut = uncut, grass = grass, mower = mower, pct = pct }
end

-- a little grass clipping flying out behind the mower
local function clipping(stage: Frame, at: Vector2)
	local c = frame(stage, UDim2.fromOffset(math.random(6, 10), math.random(10, 16)), UDim2.fromOffset(at.X, at.Y), Color3.fromRGB(90 + math.random(0, 60), 190 + math.random(0, 50), 60))
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Rotation = math.random(0, 180)
	local vx, vy = -math.random(60, 180), -math.random(120, 260)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.9 or not c.Parent then
			conn:Disconnect()
			c:Destroy()
			return
		end
		c.Position = UDim2.fromOffset(at.X + vx * t, at.Y + vy * t + 520 * t * t)
		c.Rotation += 9
		c.BackgroundTransparency = math.max(0, t - 0.5) * 2.5
	end)
end

export type Screen = { gui: ScreenGui, group: CanvasGroup, bg: Frame }

-- Build the screen for `player` (not parented). It animates until it's destroyed.
function LoadingScreen.build(player: Player?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "MowALawnLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("Progress", 0.04)
	gui:SetAttribute("Cap", 0.3)
	local group = Instance.new("CanvasGroup")
	group.Name = "Group"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Parent = gui
	-- the sky, then the meadow painting over it once loaded, then a soft darkening toward the bottom
	local bg = Instance.new("Frame")
	bg.Name = "Backdrop"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(70, 150, 220), Color3.fromRGB(40, 110, 60))
	grad.Rotation = 90
	grad.Parent = bg
	bg.Parent = group
	-- (a square as wide as the screen, hung from the top: the sky, the trees and the windmill show, the painting's own
	-- big mower stays down out of the way behind the lane)
	local painting = img(group, "scene_lawn", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0))
	painting.Name = "Painting"
	painting.ScaleType = Enum.ScaleType.Crop
	local shade = frame(group, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(16, 30, 12))
	shade.Name = "Shade"
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.2) })
	sg.Parent = shade

	-- everything else on a 1280 x 720 stage, fitted to the screen
	local stage = frame(group, UDim2.fromOffset(1280, 720), UDim2.fromScale(0.5, 0.5), WHITE)
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.BackgroundTransparency = 1
	local fit = Instance.new("UIScale")
	fit.Parent = stage
	local function refit()
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		fit.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.3, 2)
		local side = math.max(vp.X, vp.Y)
		painting.Size = UDim2.fromOffset(side, side)
		painting.Position = UDim2.new(0.5, 0, 0, -0.03 * side)
	end
	refit()

	local T = title(stage)
	local L = lane(stage)
	-- the changing line, in a dark see-through pill under the lane
	local linePill = frame(stage, UDim2.fromOffset(600, 42), UDim2.fromOffset(640, LANE_Y + LANE_H + 44), Color3.fromRGB(30, 20, 8), 21)
	linePill.AnchorPoint = Vector2.new(0.5, 0.5)
	linePill.BackgroundTransparency = 0.4
	local line = text(linePill, LINES[1] .. "...", UDim2.new(1, -40, 0, 26), UDim2.fromScale(0.5, 0.5), 2)

	-- you, bottom left, on the same kind of pill
	local youPill = frame(stage, UDim2.fromOffset(290, 64), UDim2.fromOffset(28, 630), Color3.fromRGB(30, 20, 8), 32)
	youPill.BackgroundTransparency = 0.4
	local face = frame(stage, UDim2.fromOffset(76, 76), UDim2.fromOffset(22, 624), WHITE, 38)
	local fs = Instance.new("UIStroke")
	fs.Thickness = 4
	fs.Color = INK
	fs.Parent = face
	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.AnchorPoint = Vector2.new(0.5, 0.5)
	photo.Position = UDim2.fromScale(0.5, 0.5)
	photo.Size = UDim2.new(1, -10, 1, -10)
	photo.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
	photo.Parent = face
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = photo
	local name = text(stage, if player then player.DisplayName else "", UDim2.fromOffset(200, 28), UDim2.fromOffset(108, 662), 2.5)
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.TextXAlignment = Enum.TextXAlignment.Left
	if player then
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and photo.Parent then
				photo.Image = image
			end
		end)
	end

	-- fetch the pictures first, ahead of the rest of the game (they show as soon as they arrive)
	task.spawn(function()
		local list = {}
		for _, k in { "logo", "scene_lawn", "glow_soft", "ui_grass", "pushmower", "sparkle" } do
			if IconIds[k] then
				table.insert(list, IconIds[k])
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)

	-- animation
	local start = os.clock()
	local shown = 0
	local lineIndex, lineAt = 1, start
	local lastClip = 0
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		if not gui.Parent and os.clock() - start > 5 then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		refit()
		-- progress: creep toward the cap on its own, jump toward what we're told
		local target = gui:GetAttribute("Progress") :: number? or 0
		local cap = gui:GetAttribute("Cap") :: number? or 1
		if target < cap then
			target = math.min(cap, target + dt * 0.035)
			gui:SetAttribute("Progress", target)
		end
		local was = shown
		shown += (target - shown) * math.min(1, dt * 4)
		local x = LANE_W * shown
		L.mowed.Size = UDim2.fromOffset(x, 26)
		L.uncut.Position = UDim2.fromOffset(LANE_X + x, LANE_Y)
		L.uncut.Size = UDim2.fromOffset(LANE_W - x, LANE_H)
		L.grass.Position = UDim2.fromOffset(-x, 0)
		local bump = math.abs(math.sin(t * 18)) * 3
		L.mower.Position = UDim2.fromOffset(LANE_X + x, LANE_Y + LANE_H - 6 - bump)
		L.mower.Rotation = math.sin(t * 9) * 2
		L.pct.Position = UDim2.fromOffset(LANE_X + x, LANE_Y - 56 - bump)
		L.pct.Text = ("%d%%"):format(math.floor(shown * 100 + 0.5))
		if shown - was > 0.0004 and t - lastClip > 0.05 then
			lastClip = t
			clipping(stage, Vector2.new(LANE_X + x - 20, LANE_Y + LANE_H - 20))
		end
		-- the logo pops in (Back ease over 0.7 s), then breathes and rocks a little; the glow pulses; sparkles twinkle
		local k = math.clamp(t / 0.7, 0, 1)
		local back = 1 + 2.2 * (k - 1) ^ 3 + 1.2 * (k - 1) ^ 2 -- 0 -> overshoot -> 1
		local scale = (0.35 + 0.65 * back) * (1 + 0.015 * math.sin(t * 2.2))
		T.pop.Scale = scale
		T.logo.Rotation = math.sin(t * 1.3) * 1.2
		local shadow = stage:FindFirstChild("LogoShadow") :: ImageLabel?
		if shadow then
			(shadow:FindFirstChildOfClass("UIScale") :: UIScale).Scale = scale
			shadow.Rotation = T.logo.Rotation
		end
		for i, g in T.glows do
			local base = if i == 1 then Vector2.new(1040, 640) else Vector2.new(620, 380)
			local pulse = 1 + 0.04 * math.sin(t * 1.7 + i)
			g.Size = UDim2.fromOffset(base.X * pulse * math.min(1, k * 1.4), base.Y * pulse * math.min(1, k * 1.4))
		end
		for i, s in T.sparkles do
			local ph = (t * 0.8 + i * 0.37) % 1.6 -- each one flashes for ~0.6 s, then rests
			local a = if ph < 0.6 then math.sin(ph / 0.6 * math.pi) else 0
			local sz = SPARKLES[i][3] * (0.4 + 0.6 * a)
			s.Size = UDim2.fromOffset(sz, sz)
			s.ImageTransparency = 1 - a
			s.Rotation = t * 40 + i * 30
		end
		-- the changing line, with ticking dots
		if t - lineAt > 2.6 then
			lineAt = t
			lineIndex = lineIndex % #LINES + 1
		end
		local dots = string.rep(".", 1 + math.floor(t * 2.5) % 3)
		local l = LINES[lineIndex]
		line.Text = if string.sub(l, 1, 4) == "Tip:" then l else l .. dots
	end)
	gui.Destroying:Connect(function()
		conn:Disconnect()
	end)
	return gui
end

-- How far along loading is (0..1); `cap` is how far it may creep on its own before the next real step.
function LoadingScreen.setProgress(gui: ScreenGui, p: number, cap: number?)
	local now = gui:GetAttribute("Progress") :: number? or 0
	gui:SetAttribute("Progress", math.max(now, p))
	gui:SetAttribute("Cap", math.max(p, cap or p))
end

-- Called once the world exists behind it. The painting covers the world anyway, so this only matters while the
-- painting hasn't loaded: then the plain sky turns into a dimmed view of the world.
function LoadingScreen.dim(gui: ScreenGui, alpha: number?)
	local painting = gui:FindFirstChild("Painting", true) :: ImageLabel?
	if painting and painting.IsLoaded then
		return
	end
	local bg = gui:FindFirstChild("Backdrop", true) :: Frame?
	if bg then
		TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = alpha or 0.35, BackgroundColor3 = Color3.fromRGB(10, 14, 20) }):Play()
		local grad = bg:FindFirstChildOfClass("UIGradient")
		if grad then
			grad.Enabled = false
		end
	end
end

-- Fill the bar to 100%, then fade it all out and destroy it.
function LoadingScreen.fadeOut(gui: ScreenGui, time: number?)
	LoadingScreen.setProgress(gui, 1, 1)
	local group = gui:FindFirstChild("Group") :: CanvasGroup?
	if not group then
		gui:Destroy()
		return
	end
	task.delay(0.45, function()
		local t = TweenService:Create(group, TweenInfo.new(time or 0.6, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
		t:Play()
		t.Completed:Connect(function()
			gui:Destroy()
		end)
	end)
end

return LoadingScreen
