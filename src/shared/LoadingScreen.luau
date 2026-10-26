-- The loading screen, at golden hour (the owner's pick between a too-busy and a too-plain version): a warm sunset
-- sky, the sun low over the hills turning slowly in its halo with soft rays fanning out, three clouds drifting by,
-- hazy far hills with a small windmill, near hills in warm green running down to the bottom with faint mowed stripes,
-- a big tree framing each side and a flower bush in each bottom corner. In the middle: the drawn MOW A LAWN logo on
-- a soft glow (drop shadow, a few sparkles), and the loading bar: the HUD's wooden groove, mowed stripes filling it
-- from the left, tall grass growing out of the rest, a push mower riding the edge throwing clippings with the
-- percentage above it. Under it one line that changes every couple of seconds, and your face and name top left.
-- Self-contained (no client modules): the boot script in ReplicatedFirst uses it on arrival, client/Loading before a
-- teleport. Pictures come from IconIds; anything missing is drawn as a plain shape or left out.
-- Progress: LoadingScreen.setProgress(gui, 0..1, cap); between calls it creeps forward on its own up to `cap`, so it
-- never sits still and never runs ahead of the real loading. fadeOut fills it to 100% first.
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

-- the bar, in the 1280 x 720 stage: the wooden frame and the groove inside it
local BAR = { x = 240, y = 562, w = 800, h = 92 }
local BAR_SLICE, BAR_SRC = Rect.new(90, 60, 934, 105), Vector2.new(1024, 165)
local BAR_FACE = { 47, 52, 49, 44 }

local LINES = {
	"Sharpening the blades",
	"Watering the lawn",
	"Tip: rare grass glows - cut it first!",
	"Waking up the critters",
	"Tip: bigger bags mean fewer trips to the shredder",
	"Counting the clovers",
	"Tip: the Hold upgrade lets you keep the button down",
	"Fuelling the mowers",
	"Tip: equip pets for a team boost",
	"Oiling the windmill",
}

-------------------------------------------------------------------------------------------------------------
-- builders
-------------------------------------------------------------------------------------------------------------
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

-- a picture of a known pixel size, `h` tall, standing with its bottom centre at (x, y), warmed by the evening light
local GOLD_TINT = Color3.fromRGB(255, 226, 196)
local function standing(parent: Instance, key: string, src: Vector2, h: number, x: number, y: number): ImageLabel?
	if not IconIds[key] then
		return nil
	end
	local i = img(parent, key, UDim2.fromOffset(h * src.X / src.Y, h), UDim2.fromOffset(x, y), Vector2.new(0.5, 1))
	i.ImageColor3 = GOLD_TINT
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

-- a 9-slice picture (the HUD's wooden bar) at w x h; returns it and the scale its border is drawn at
local function sliced(parent: Instance, key: string, w: number, h: number, slice: Rect, src: Vector2, boost: number?): (GuiObject, number)
	local k = math.min(w / src.X, h / src.Y) * (boost or 1)
	k = math.min(k, h / (slice.Min.Y + src.Y - slice.Max.Y), w / (slice.Min.X + src.X - slice.Max.X))
	if IconIds[key] then
		local i = img(parent, key, UDim2.fromOffset(w, h), UDim2.new(), Vector2.zero)
		i.ScaleType = Enum.ScaleType.Slice
		i.SliceCenter = slice
		i.SliceScale = k
		return i, k
	end
	local f = frame(parent, UDim2.fromOffset(w, h), UDim2.new(), Color3.fromRGB(196, 128, 60), math.floor(h / 2))
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = INK
	s.Parent = f
	return f, k
end

-- an outlined cluster of ellipses (the far and near hills): an ink copy a little bigger underneath, the colour on
-- top, so overlapping shapes join into one silhouette with a single outline; lit from above
local function hills(parent: Instance, shapes: { { number } }, color: Color3, top: Color3, ink: number)
	for pass = 1, 2 do
		for _, e in shapes do
			local grow = if pass == 1 then ink * 2 else 0
			local f = frame(parent, UDim2.fromOffset(e[3] + grow, e[4] + grow), UDim2.fromOffset(e[1], e[2]), if pass == 1 then INK else WHITE)
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
			if pass == 2 then
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.3, color), ColorSequenceKeypoint.new(1, color) })
				g.Rotation = 90
				g.Parent = f
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the countryside (a 1280 x 720 world scaled to cover the screen)
-------------------------------------------------------------------------------------------------------------
type Scene = { scale: UIScale, sun: GuiObject, rays: GuiObject?, clouds: { { f: GuiObject, speed: number } } }
local function scene(group: Instance): Scene
	local sky = frame(group, UDim2.fromScale(1, 1), UDim2.new(), WHITE)
	sky.Name = "Sky"
	local sg = Instance.new("UIGradient")
	sg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 120, 214)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(250, 170, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 214, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 236, 180)),
	})
	sg.Rotation = 90
	sg.Parent = sky
	local world = frame(group, UDim2.fromOffset(1280, 720), UDim2.fromScale(0.5, 0.5), WHITE)
	world.Name = "Scene"
	world.AnchorPoint = Vector2.new(0.5, 0.5)
	world.BackgroundTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Parent = world

	-- the low evening sun, right of the logo, with soft rays fanning out and a warm halo
	local SUN = Vector2.new(1060, 330)
	local rays: GuiObject? = nil
	if IconIds.ui_rays then
		local r = img(world, "ui_rays", UDim2.fromOffset(900, 900), UDim2.fromOffset(SUN.X, SUN.Y))
		r.ScaleType = Enum.ScaleType.Stretch
		r.ImageColor3 = Color3.fromRGB(255, 236, 190)
		r.ImageTransparency = 0.82
		rays = r
	end
	local halo = img(world, "glow_soft", UDim2.fromOffset(476, 476), UDim2.fromOffset(SUN.X, SUN.Y))
	halo.ScaleType = Enum.ScaleType.Stretch
	halo.ImageColor3 = Color3.fromRGB(255, 200, 120)
	halo.ImageTransparency = 0.05
	local sun = img(world, "bg_sun", UDim2.fromOffset(170, 170), UDim2.fromOffset(SUN.X, SUN.Y))
	sun.ImageColor3 = Color3.fromRGB(255, 220, 170)
	if not IconIds.bg_sun then
		sun.BackgroundTransparency = 0
		sun.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
		sun.Size = UDim2.fromOffset(110, 110)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = sun
	end

	-- clouds: { picture, x, y, height, speed } - the smaller (further) ones drift slower
	local clouds = {}
	for _, c in {
		{ "bg_cloud", 140, 196, 104, 6 },
		{ "bg_cloud2", 930, 250, 64, 3.5 },
		{ "bg_cloud2", 520, 40, 44, 2.4 },
	} do
		if IconIds[c[1]] then
			local src = if c[1] == "bg_cloud" then Vector2.new(768, 439) else Vector2.new(768, 391)
			local f = img(world, c[1], UDim2.fromOffset(c[4] * src.X / src.Y, c[4]), UDim2.fromOffset(c[2], c[3]))
			if c[4] < 60 then
				f.ImageTransparency = 0.15 -- far away: a touch hazier
			end
			table.insert(clouds, { f = f, speed = c[5] })
		end
	end

	-- far hills, hazy blue-green, then the near hills in fresh green running down to the bottom of the screen, with a
	-- hint of mowed stripes fading in toward the front
	hills(world, { { 150, 496, 660, 240 }, { 640, 480, 760, 220 }, { 1120, 498, 680, 250 }, { 1500, 504, 560, 210 } }, Color3.fromRGB(170, 160, 150), Color3.fromRGB(226, 196, 170), 3)
	-- a little windmill on the far hills, in the haze
	local mill = standing(world, "bg_windmill", Vector2.new(603, 768), 150, 1150, 470)
	if mill then
		mill.ImageTransparency = 0.1
	end
	hills(world, { { -60, 566, 780, 240 }, { 740, 556, 860, 230 }, { 1400, 570, 720, 240 } }, Color3.fromRGB(110, 170, 70), Color3.fromRGB(200, 214, 110), 4)
	local ground = frame(world, UDim2.fromOffset(2400, 300), UDim2.fromOffset(-560, 600), Color3.fromRGB(110, 170, 70))
	ground.Name = "Ground"
	for i = 0, 2400 / 110 do
		local stripe = frame(ground, UDim2.fromOffset(55, 300), UDim2.fromOffset(i * 110, 0), Color3.fromRGB(130, 184, 80))
		stripe.Name = "Stripe"
		local sg2 = Instance.new("UIGradient")
		sg2.Rotation = 90
		sg2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.4), NumberSequenceKeypoint.new(1, 0.3) })
		sg2.Parent = stripe
	end
	-- a big tree framing each side, a flower bush in each bottom corner
	standing(world, "bg_tree", Vector2.new(642, 768), 330, 92, 640)
	standing(world, "bg_tree2", Vector2.new(649, 768), 250, 1205, 650)
	standing(world, "bg_bush2", Vector2.new(768, 670), 120, 180, 720)
	standing(world, "bg_bush", Vector2.new(768, 586), 110, 1100, 722)
	-- soft dark edges and a darker bottom, so the bar and the writing read
	for _, side in { 0, 1 } do
		local v = frame(group, UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(side * 0.78, 0), Color3.fromRGB(34, 18, 8))
		local vg = Instance.new("UIGradient")
		vg.Transparency = NumberSequence.new(if side == 0 then 0.75 else 1, if side == 0 then 1 else 0.75)
		vg.Parent = v
	end
	local shade = frame(group, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(30, 20, 8))
	local sh = Instance.new("UIGradient")
	sh.Rotation = 90
	sh.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.5) })
	sh.Parent = shade
	return { scale = scale, sun = sun, rays = rays, clouds = clouds }
end

-------------------------------------------------------------------------------------------------------------
-- the logo on its glow, with a drop shadow and sparkles
-------------------------------------------------------------------------------------------------------------
local LOGO = Vector2.new(690, 456) -- (the picture is 955 x 631)
local LOGO_AT = Vector2.new(640, 248)
local SPARKLES = { { 310, 120, 40 }, { 1006, 336, 44 }, { 742, 34, 26 } }
type Title = { logo: GuiObject, shadow: GuiObject?, pop: UIScale, glows: { ImageLabel }, sparkles: { ImageLabel } }
local function title(stage: Frame): Title
	local glows = {}
	for _, gl in { { 1060, 660, Color3.fromRGB(255, 232, 150), 0.25 }, { 640, 400, Color3.new(1, 1, 1), 0.45 } } do
		local g = img(stage, "glow_soft", UDim2.fromOffset(gl[1], gl[2]), UDim2.fromOffset(LOGO_AT.X, LOGO_AT.Y))
		g.ScaleType = Enum.ScaleType.Stretch
		g.ImageColor3 = gl[3]
		g.ImageTransparency = gl[4]
		table.insert(glows, g)
	end
	local logo: GuiObject
	local shadow: GuiObject? = nil
	if IconIds.logo then
		local s = img(stage, "logo", UDim2.fromOffset(LOGO.X, LOGO.Y), UDim2.fromOffset(LOGO_AT.X + 8, LOGO_AT.Y + 12))
		s.Name = "LogoShadow"
		s.ImageColor3 = Color3.fromRGB(16, 30, 10)
		s.ImageTransparency = 0.5
		Instance.new("UIScale").Parent = s
		shadow = s
		logo = img(stage, "logo", UDim2.fromOffset(LOGO.X, LOGO.Y), UDim2.fromOffset(LOGO_AT.X, LOGO_AT.Y))
	else
		local t = text(stage, string.upper(gameName), UDim2.fromOffset(900, 150), UDim2.fromOffset(LOGO_AT.X, LOGO_AT.Y), 9)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 250, 120))
		g.Rotation = 90
		g.Parent = t
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
	return { logo = logo, shadow = shadow, pop = pop, glows = glows, sparkles = sparkles }
end

-------------------------------------------------------------------------------------------------------------
-- the loading bar: the HUD's wooden groove, mowed stripes filling it, tall grass growing out of the rest
-------------------------------------------------------------------------------------------------------------
type Bar = { gx: number, gy: number, gw: number, gh: number, fill: Frame, uncut: Frame, grass: Frame, mower: GuiObject, plate: GuiObject, pct: TextLabel }
local function bar(stage: Frame): Bar
	local holder = frame(stage, UDim2.fromOffset(BAR.w, BAR.h), UDim2.fromOffset(BAR.x, BAR.y), WHITE)
	holder.Name = "Bar"
	holder.BackgroundTransparency = 1
	local wood, k = sliced(holder, "ui_bar", BAR.w, BAR.h, BAR_SLICE, BAR_SRC)
	wood.Name = "Wood"
	local gx, gy = BAR.x + BAR_FACE[1] * k, BAR.y + BAR_FACE[2] * k
	local gw, gh = BAR.w - (BAR_FACE[1] + BAR_FACE[3]) * k, BAR.h - (BAR_FACE[2] + BAR_FACE[4]) * k
	-- mowed: short lawn in stripes, with a glossy top, rounded like the groove
	local fill = frame(stage, UDim2.fromOffset(0, gh), UDim2.fromOffset(gx, gy), Color3.fromRGB(116, 200, 66), math.floor(gh / 2))
	fill.Name = "Mowed"
	fill.ClipsDescendants = true
	for i = 0, math.ceil(gw / 34) do
		local s = frame(fill, UDim2.fromOffset(17, gh), UDim2.fromOffset(i * 34, 0), Color3.fromRGB(150, 222, 88))
		s.Name = "Stripe"
	end
	local gloss = frame(fill, UDim2.new(1, -16, 0.24, 0), UDim2.new(0, 8, 0.12, 0), Color3.new(1, 1, 1), 99)
	gloss.BackgroundTransparency = 0.7
	-- uncut: tall grass from the mower to the end, growing up out of the groove over the frame's top edge
	local reach = 52 -- how far the grass stands above the groove
	local uncut = frame(stage, UDim2.fromOffset(gw, gh + reach), UDim2.fromOffset(gx, gy - reach), WHITE)
	uncut.Name = "Uncut"
	uncut.BackgroundTransparency = 1
	uncut.ClipsDescendants = true
	local grass = frame(uncut, UDim2.fromOffset(gw, gh + reach), UDim2.new(), WHITE)
	grass.BackgroundTransparency = 1
	frame(grass, UDim2.fromOffset(gw, gh - 6), UDim2.fromOffset(0, reach + 3), Color3.fromRGB(64, 140, 44), math.floor(gh / 2)).Name = "Roots"
	if IconIds.ui_grass then
		local th = gh + reach - 2
		local tw = math.floor(th * 921 / 271)
		for x = -16, gw, tw - 22 do
			img(grass, "ui_grass", UDim2.fromOffset(tw, th), UDim2.fromOffset(x, gh + reach), Vector2.new(0, 1))
		end
	end
	-- the mower (the picture faces left, so it's drawn mirrored to drive right)
	local mower: GuiObject
	if IconIds.pushmower then
		local m = img(stage, "pushmower", UDim2.fromOffset(122, 118), UDim2.fromOffset(gx, gy + gh + 4), Vector2.new(0.56, 1))
		m.ImageRectOffset = Vector2.new(512, 0)
		m.ImageRectSize = Vector2.new(-512, 495)
		mower = m
	else
		mower = frame(stage, UDim2.fromOffset(64, 46), UDim2.fromOffset(gx, gy + gh), Color3.fromRGB(230, 70, 60), 12)
		mower.AnchorPoint = Vector2.new(0.5, 1)
	end
	-- the percentage, riding above the mower
	local plate = frame(stage, UDim2.fromOffset(100, 36), UDim2.fromOffset(gx, gy - 100), WHITE)
	plate.Name = "Percent"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.BackgroundTransparency = 1
	local pct = text(plate, "0%", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), 3)
	return { gx = gx, gy = gy, gw = gw, gh = gh, fill = fill, uncut = uncut, grass = grass, mower = mower, plate = plate, pct = pct }
end

-- a grass clipping flying out behind the mower
local function clipping(stage: Frame, at: Vector2)
	local c = frame(stage, UDim2.fromOffset(math.random(6, 10), math.random(10, 16)), UDim2.fromOffset(at.X, at.Y), Color3.fromRGB(90 + math.random(0, 60), 190 + math.random(0, 50), 60))
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Rotation = math.random(0, 180)
	local vx, vy = -math.random(60, 180), -math.random(140, 280)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.9 or not c.Parent then
			conn:Disconnect()
			c:Destroy()
			return
		end
		c.Position = UDim2.fromOffset(at.X + vx * t, at.Y + vy * t + 560 * t * t)
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

	local S = scene(group)
	-- everything else on a 1280 x 720 stage fitted inside the screen
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
		S.scale.Scale = math.max(vp.X / 1280, vp.Y / 720) -- the countryside covers the whole screen
	end
	refit()

	local T = title(stage)
	local B = bar(stage)
	-- the changing line under the bar
	local line = text(stage, LINES[1] .. "...", UDim2.fromOffset(640, 26), UDim2.fromOffset(640, BAR.y + BAR.h + 30), 2.5)

	-- you, small in the bottom-left corner: your face in a white ring and your name (top-left sat under Roblox's
	-- menu button)
	local face = frame(stage, UDim2.fromOffset(54, 54), UDim2.fromOffset(24, 642), WHITE, 27)
	local fs = Instance.new("UIStroke")
	fs.Thickness = 3
	fs.Color = INK
	fs.Parent = face
	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.AnchorPoint = Vector2.new(0.5, 0.5)
	photo.Position = UDim2.fromScale(0.5, 0.5)
	photo.Size = UDim2.new(1, -8, 1, -8)
	photo.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
	photo.Parent = face
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = photo
	local name = text(stage, if player then player.DisplayName else "", UDim2.fromOffset(220, 24), UDim2.fromOffset(90, 669), 2.5)
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

	-- fetch the pictures first, ahead of the rest of the game (each shows as soon as it arrives)
	task.spawn(function()
		local list = {}
		for _, key in { "logo", "glow_soft", "bg_sun", "bg_cloud", "bg_cloud2", "ui_rays", "bg_windmill", "bg_tree", "bg_tree2", "bg_bush", "bg_bush2", "ui_bar", "ui_grass", "pushmower", "sparkle" } do
			if IconIds[key] then
				table.insert(list, IconIds[key])
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
		-- the sky: the sun turns slowly, the clouds drift right and come round again
		S.sun.Rotation = t * 4
		if S.rays then
			S.rays.Rotation = -t * 2.5
		end
		for _, c in S.clouds do
			local x = c.f.Position.X.Offset + c.speed * dt
			if x > 1460 then
				x = -260
			end
			c.f.Position = UDim2.fromOffset(x, c.f.Position.Y.Offset)
		end
		-- progress: creep toward the cap on its own, ease toward what we're told
		local target = gui:GetAttribute("Progress") :: number? or 0
		local cap = gui:GetAttribute("Cap") :: number? or 1
		if target < cap then
			target = math.min(cap, target + dt * 0.035)
			gui:SetAttribute("Progress", target)
		end
		local was = shown
		shown += (target - shown) * math.min(1, dt * 4)
		local x = B.gw * shown
		B.fill.Size = UDim2.fromOffset(math.max(x, if shown > 0.01 then B.gh else 0), B.gh)
		B.uncut.Position = UDim2.fromOffset(B.gx + x, B.uncut.Position.Y.Offset)
		B.uncut.Size = UDim2.fromOffset(math.max(0, B.gw - x), B.uncut.Size.Y.Offset)
		B.grass.Position = UDim2.fromOffset(-x, 0)
		local bump = math.abs(math.sin(t * 16)) * 3
		B.mower.Position = UDim2.fromOffset(B.gx + x, B.gy + B.gh + 4 - bump)
		B.mower.Rotation = math.sin(t * 8) * 2
		B.plate.Position = UDim2.fromOffset(B.gx + x, B.gy - 100 + math.sin(t * 3) * 3)
		B.pct.Text = ("%d%%"):format(math.floor(shown * 100 + 0.5))
		if shown - was > 0.0004 and t - lastClip > 0.05 then
			lastClip = t
			clipping(stage, Vector2.new(B.gx + x - 26, B.gy + 4))
		end
		-- the logo pops in (Back ease over 0.7 s), then breathes and rocks a little; the glow pulses; sparkles twinkle
		local k = math.clamp(t / 0.7, 0, 1)
		local back = 1 + 2.2 * (k - 1) ^ 3 + 1.2 * (k - 1) ^ 2 -- 0 -> a little past 1 -> 1
		local scale = (0.35 + 0.65 * back) * (1 + 0.015 * math.sin(t * 2.2))
		T.pop.Scale = scale
		T.logo.Rotation = math.sin(t * 1.3) * 1.2
		if T.shadow then
			(T.shadow:FindFirstChildOfClass("UIScale") :: UIScale).Scale = scale
			T.shadow.Rotation = T.logo.Rotation
		end
		for i, g in T.glows do
			local size = if i == 1 then Vector2.new(1060, 660) else Vector2.new(640, 400)
			local pulse = (1 + 0.04 * math.sin(t * 1.7 + i)) * math.min(1, k * 1.4)
			g.Size = UDim2.fromOffset(size.X * pulse, size.Y * pulse)
		end
		for i, s in T.sparkles do
			local ph = (t * 0.8 + i * 0.37) % 1.6 -- each flashes for ~0.6 s, then rests
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
		local l = LINES[lineIndex]
		line.Text = if string.sub(l, 1, 4) == "Tip:" then l else l .. string.rep(".", 1 + math.floor(t * 2.5) % 3)
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

-- (Used to dim the backdrop once the world existed behind it; the drawn countryside covers the world now. Kept for
-- the callers.)
function LoadingScreen.dim(_gui: ScreenGui, _alpha: number?) end

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
