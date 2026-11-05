-- ANIME FX (Films v2, 5 Nov 2026): the new films' 2D layer, drawn into the films' ScreenGui (client/IntroUi) under
-- its letterbox bars and SKIP button, after the owner's reference cutscenes (Roblox anime cutscenes: bracketed
-- subtitles, a big name card, white slash frames, speed lines, impact frames that flatten the picture to black and
-- white for a frame or two, whiteouts, the title slammed in on the beat). Our own shapes, words and colours only.
--   AnimeFx.sub(text, life?)                 a subtitle, "[like this]"
--   AnimeFx.card(name, title, color?, life?) a character's name card (RAYAN / OWNER OF THE VALLEY)
--   AnimeFx.slash(angle, opts?)              a white cut across the screen for a frame or two
--   AnimeFx.cut(at, from, to, color?, size?) a crescent where a blade passes (pinned to a world point, over the picture)
--   AnimeFx.cutScreen(at, from, to, color?, core?) the same crescent across the whole frame (an ultimate)
--   AnimeFx.hit(at, color?, size?, big?)     a hit: a star bursting into a ring, needles, a flare, a streak (pinned)
--   AnimeFx.lines(color?, alpha?) -> stop()  radial speed lines (at the screen's middle, or opts.at, a world point)
--   AnimeFx.impact(subjects, style, opts?)   an impact frame: the subjects as flat silhouettes from the film's camera
--                                            on a flat colour, the picture stuck meanwhile; style "ink" (black on
--                                            white), "neg" (white on black), "red", "gold", "pink", or "strobe"
--                                            (several of them in turn, the biggest hits only)
--   AnimeFx.cover(color, alpha, time?)       a flat cover over the picture (whiteouts, blackouts), eased
--   AnimeFx.logo()                           the game's logo slammed in (the opening's title)
--   AnimeFx.word(big, small?, color?)        a big word alone on black ("YOU."), a line under it
--   AnimeFx.clear()
-- "Reduce camera shake" (CalmCamera) gets single soft frames instead of strobes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local IntroUi = require(script.Parent.IntroUi)
local Film = require(script.Parent.Film)

local AnimeFx = {}
local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 200, 70)
local PINK = Color3.fromRGB(255, 40, 170)
local TEX_LINES = "rbxassetid://110976543463529" -- (the game's radial speed lines)
local TEX_GLOW = "rbxassetid://125552447014366"
local Z_PICTURE = 3 -- under the letterbox bars (4)
local Z_TEXT = 6 -- over them, under SKIP (8) and the black cover (10)

local live: { Instance } = {}
local FxIds = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxIds")) :: any

local function calm(): boolean
	return player:GetAttribute("CalmCamera") == true
end

local function gui(): ScreenGui?
	return IntroUi.gui()
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function frame(parent: Instance, name: string, color: Color3, alpha: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, font: Enum.Font, color: Color3, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.Font = font
	t.TextColor3 = color
	t.TextScaled = true
	t.ZIndex = z
	t.Parent = parent
	return t
end

local function stroke(parent: Instance, thick: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thick
	s.Color = color or BLACK
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Parent = parent
	return s
end

local function keep(i: Instance, life: number)
	table.insert(live, i)
	task.delay(life, function()
		local k = table.find(live, i)
		if k then
			table.remove(live, k)
		end
		i:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------------------
-- (round 2, owner 5 Nov: "i dont like the text pop up i feel like its very sloppy please take inspiration from jjk")
-- The films' type, after the clean, hard typography of jujutsu anime cards: a high-contrast serif for what's said and
-- for names, small spaced capitals under a thin rule, a stamped seal with one character, and everything in and out on
-- a cut (no bouncing, no sliding across the screen). Our own words and marks.
-------------------------------------------------------------------------------------------------------------
local SERIF_BOLD = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local SERIF_BLACK = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)
local SANS = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local SANS_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local CRIMSON = Color3.fromRGB(214, 30, 52)

-- "OWNER" -> "O W N E R" with thin spaces (tracked capitals)
local function tracked(text: string): string
	local out = string.gsub(text, "([%w%p])", "%1\u{2009}")
	return (string.gsub(out, "\u{2009}$", ""))
end

local function typeLabel(parent: Instance, text: string, font: Font, color: Color3, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.FontFace = font
	t.TextColor3 = color
	t.TextScaled = true
	t.ZIndex = z
	t.Parent = parent
	return t
end

-------------------------------------------------------------------------------------------------------------
-- subtitles: one at a time, bottom middle, just over the bottom bar: white serif in brackets, a hairline of black
-- round it and a soft shadow; *starred* words in crimson. In on a quick fade, out on a quick fade.
-------------------------------------------------------------------------------------------------------------
local lastSub: Frame? = nil
function AnimeFx.sub(text: string, life: number?)
	local g = gui()
	if not g then
		return
	end
	if lastSub and lastSub.Parent then
		lastSub:Destroy()
	end
	local bar = IntroUi.bar()
	local root = Instance.new("Frame")
	root.Name = "Sub"
	root:SetAttribute("KeepFont", true) -- (client/TextStyle leaves the films' own type alone)
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.fromScale(0.5, 1 - bar - 0.02)
	root.Size = UDim2.fromScale(0.86, 0.06)
	root.ZIndex = Z_TEXT
	root.Parent = g
	local rich = string.gsub(text, "%*(.-)%*", '<font color="#D61E34">%1</font>')
	local body = '<font color="#B8B4C4">[</font> ' .. rich .. ' <font color="#B8B4C4">]</font>'
	local shadow = typeLabel(root, string.gsub(body, '<font color="#%x+">', '<font color="#000000">'), SERIF_BOLD, BLACK, Z_TEXT)
	shadow.RichText = true
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.new(0, 2, 0, 3)
	shadow.TextTransparency = 1
	local t = typeLabel(root, body, SERIF_BOLD, WHITE, Z_TEXT + 1)
	t.RichText = true
	t.Size = UDim2.fromScale(1, 1)
	t.TextTransparency = 1
	for _, l in { t, shadow } do
		local lim = Instance.new("UITextSizeConstraint")
		lim.MaxTextSize = 30
		lim.MinTextSize = 14
		lim.Parent = l
	end
	local st = stroke(t, 1.2)
	st.Transparency = 1
	tween(t, 0.12, { TextTransparency = 0 })
	tween(st, 0.12, { Transparency = 0.2 })
	tween(shadow, 0.12, { TextTransparency = 0.55 })
	lastSub = root
	local hold = life or math.clamp(0.9 + #text * 0.05, 1.2, 3.2)
	task.delay(hold, function()
		if root.Parent then
			tween(t, 0.2, { TextTransparency = 1 })
			tween(st, 0.2, { Transparency = 1 })
			tween(shadow, 0.2, { TextTransparency = 1 })
		end
	end)
	keep(root, hold + 0.25)
end

-- a seal: a square stamp in `color` with one character, pressed in (it lands from a little bigger, hard)
local function seal(parent: Instance, mark: string, color: Color3, pos: UDim2, size: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Seal"
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	f.Size = UDim2.fromScale(size, size)
	f.ZIndex = z
	f.Parent = parent
	local inner = Instance.new("UIStroke")
	inner.Color = color:Lerp(BLACK, 0.35)
	inner.Thickness = 3
	inner.Parent = f
	local lum = color.R * 0.3 + color.G * 0.59 + color.B * 0.11
	local t = typeLabel(f, mark, SANS_BOLD, if lum > 0.6 then Color3.fromRGB(28, 16, 10) else WHITE, z + 1)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.8, 0.8)
	local sc = Instance.new("UIScale")
	sc.Scale = 1.4
	sc.Parent = f
	tween(sc, 0.08, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	return f
end

-- a thin rule that draws itself from the left
local function rule(parent: Instance, color: Color3, pos: UDim2, width: number, z: number, delay: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Rule"
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Position = pos
	f.Size = UDim2.new(0, 0, 0, 2)
	f.ZIndex = z
	f.Parent = parent
	task.delay(delay or 0, function()
		if f.Parent then
			tween(f, 0.28, { Size = UDim2.new(width, 0, 0, 2) }, Enum.EasingStyle.Quart)
		end
	end)
	return f
end

-- a name revealed left to right (a hard edge sweeping across it)
local function reveal(t: TextLabel, time: number)
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.49, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Offset = Vector2.new(-0.5, 0)
	grad.Parent = t
	tween(grad, time, { Offset = Vector2.new(0.5, 0) }, Enum.EasingStyle.Quart)
end

-------------------------------------------------------------------------------------------------------------
-- the name card: a dark wash from the left, a seal stamped in, the name in a heavy serif revealed left to right, a
-- thin rule drawing under it, the title in small spaced capitals; on a cut it's gone. `mark`: the seal's character.
-------------------------------------------------------------------------------------------------------------
function AnimeFx.card(name: string, title: string, color: Color3?, life: number?, mark: string?)
	local g = gui()
	if not g then
		return
	end
	local c = color or GOLD
	local hold = life or 1.9
	local root = Instance.new("Frame")
	root.Name = "NameCard"
	root:SetAttribute("KeepFont", true)
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Z_TEXT
	root.Parent = g
	-- (a soft dark pool behind the type, no hard edges: the glow texture, black)
	local wash = Instance.new("ImageLabel")
	wash.Name = "Wash"
	wash.BackgroundTransparency = 1
	wash.Image = FxIds.glow
	wash.ImageColor3 = BLACK
	wash.ImageTransparency = 0.2
	wash.AnchorPoint = Vector2.new(0.5, 0.5)
	wash.Position = UDim2.fromScale(0.3, 0.62)
	wash.Size = UDim2.fromScale(1.0, 0.62)
	wash.ZIndex = Z_TEXT
	wash.Parent = root
	seal(root, mark or string.sub(name, 1, 1), c, UDim2.fromScale(0.105, 0.6), 0.13, Z_TEXT + 2)
	local big = typeLabel(root, tracked(string.upper(name)), SERIF_BLACK, WHITE, Z_TEXT + 2)
	big.AnchorPoint = Vector2.new(0, 0.5)
	big.Position = UDim2.fromScale(0.17, 0.585)
	big.Size = UDim2.fromScale(0.6, 0.115)
	big.TextXAlignment = Enum.TextXAlignment.Left
	reveal(big, 0.16)
	rule(root, c, UDim2.fromScale(0.172, 0.655), 0.4, Z_TEXT + 2, 0.08)
	local small = typeLabel(root, tracked(string.upper(title)), SANS, Color3.fromRGB(226, 222, 232), Z_TEXT + 2)
	small.AnchorPoint = Vector2.new(0, 0.5)
	small.Position = UDim2.fromScale(0.172, 0.695)
	small.Size = UDim2.fromScale(0.42, 0.032)
	small.TextXAlignment = Enum.TextXAlignment.Left
	small.TextTransparency = 1
	task.delay(0.16, function()
		if small.Parent then
			tween(small, 0.18, { TextTransparency = 0 })
		end
	end)
	-- (a slow push while it holds, then gone on a cut)
	tween(big, hold, { Position = UDim2.fromScale(0.178, 0.585) }, Enum.EasingStyle.Linear)
	keep(root, hold)
end

-------------------------------------------------------------------------------------------------------------
-- (round 2, owner 5 Nov: "i dont feel like ur using good fx on some parts like the slash ... look at the video look
-- how they did it") The reference's FX are flat, hard, bright shapes laid over the picture: a white wedge across the
-- whole frame for two frames where a blade cuts (Sukuna Raid 18.25), a crescent of white over a coloured one at the
-- cut, a star that bursts into a ring where a hit lands, a long flare streak. The textures are the game's own
-- (shared/FxIds, assets/fx).
-------------------------------------------------------------------------------------------------------------
local RECT_BLADE = { 92, 2, 72, 251 } -- (the blade texture's shape: a long wedge, its point up)
local RECT_SLASH = { 34, 72, 444, 216 } -- (the crescent)

-- a wedge across the screen through (x, y) (scale), pointing along `angle` degrees, `thick` and `len` scale of the
-- picture's height / width
local function wedge(g: Instance, x: number, y: number, angle: number, thick: number, len: number, color: Color3, z: number): ImageLabel
	local abs = (g :: any).AbsoluteSize :: Vector2
	local im = Instance.new("ImageLabel")
	im.Name = "Wedge"
	im.BackgroundTransparency = 1
	im.Image = FxIds.blade
	im.ImageRectOffset = Vector2.new(RECT_BLADE[1], RECT_BLADE[2])
	im.ImageRectSize = Vector2.new(RECT_BLADE[3], RECT_BLADE[4])
	im.ScaleType = Enum.ScaleType.Stretch
	im.ImageColor3 = color
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.Position = UDim2.fromScale(x, y)
	im.Size = UDim2.fromOffset(math.max(abs.Y * thick, 2), abs.X * len)
	im.Rotation = angle + 90
	im.ZIndex = z
	im.Parent = g
	return im
end

-- A slash across the screen: a long hard white wedge at `angle` degrees through (0.5, opts.y), a thin sliver along
-- it, for a couple of frames, gone without a fade (opts: y, x, life, width, color)
function AnimeFx.slash(angle: number, opts: any?)
	local g = gui()
	if not g then
		return
	end
	local o = opts or {}
	local life = math.max(o.life or 0.07, 0.05)
	local w = (o.width or 0.03) * 3.2
	local c = o.color or WHITE
	local root = Instance.new("Frame")
	root.Name = "Slash"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Z_PICTURE
	root.Parent = g
	local x, y = o.x or 0.5, o.y or 0.5
	local main = wedge(root, x, y, angle, w, 1.5, c, Z_PICTURE)
	local r = math.rad(angle + 90)
	local off = 0.045 + w * 0.6
	wedge(root, x + math.cos(r) * off * 0.6, y + math.sin(r) * off, angle, w * 0.16, 1.1, c, Z_PICTURE)
	wedge(root, x - math.cos(r) * off * 0.9, y - math.sin(r) * off * 1.4, angle, w * 0.08, 0.8, c, Z_PICTURE)
	-- (it shoots across: from short to full length in a frame)
	local full = main.Size
	main.Size = UDim2.fromOffset(full.X.Offset, full.Y.Offset * 0.55)
	tween(main, 0.03, { Size = full }, Enum.EasingStyle.Linear)
	keep(root, life)
end

-- A smear: the reference's slash frame, three hard white wedges across most of the frame for a couple of frames.
-- `angle` degrees, `side` 1 or -1 (which way their points go).
function AnimeFx.smear(angle: number, side: number?, color: Color3?)
	local g = gui()
	if not g then
		return
	end
	local root = Instance.new("Frame")
	root.Name = "Smear"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Z_PICTURE
	root.Parent = g
	local a = angle + (if (side or 1) > 0 then 0 else 180)
	local r = math.rad(a + 90)
	local c = color or WHITE
	for i, spec in { { 0, 0.34, 1.7 }, { 0.2, 0.1, 1.3 }, { -0.17, 0.05, 1.0 } } do
		wedge(root, 0.5 + math.cos(r) * spec[1] * 0.6, 0.5 + math.sin(r) * spec[1], a, spec[2], spec[3], c, Z_PICTURE + i)
	end
	keep(root, 0.07)
end

-------------------------------------------------------------------------------------------------------------
-- world FX: flat shapes pinned to points in the world but drawn over the picture (in the films' gui, under the bars),
-- so a body or the grass never hides them. A pin follows its point every frame; its pieces are sized in studs where
-- the point is. (A BillboardGui with AlwaysOnTop would be the same thing, but Studio doesn't draw those at all, and a
-- depth-tested one is lost inside the bodies it's meant to be over: tested 5 Nov.)
-------------------------------------------------------------------------------------------------------------
local UNIT = 100 -- (pieces are sized in hundredths of a stud: a UDim's offset is a whole number)
type Pin = { root: Frame, scale: UIScale, at: Vector3 }
local pins: { Pin } = {}
local pinning = false

local function placePins()
	local cam = workspace.CurrentCamera
	for i = #pins, 1, -1 do
		local p = pins[i]
		if not p.root.Parent then
			table.remove(pins, i)
		elseif cam then
			local s = cam:WorldToViewportPoint(p.at)
			if s.Z < 0.3 then
				p.root.Visible = false
			else
				p.root.Visible = true
				p.root.Position = UDim2.fromOffset(s.X, s.Y)
				p.scale.Scale = cam.ViewportSize.Y / (2 * s.Z * math.tan(math.rad(cam.FieldOfView) / 2)) / UNIT
			end
		end
	end
	if #pins == 0 and pinning then
		pinning = false
		RunService:UnbindFromRenderStep("AnimeFxPins")
	end
end

-- an empty pin at a world point for `life` seconds (nil if the films' gui isn't up)
local function pin(at: Vector3, life: number): Frame?
	local g = gui()
	if not g then
		return nil
	end
	local root = Instance.new("Frame")
	root.Name = "Pin"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(0, 0)
	root.ZIndex = Z_PICTURE
	local sc = Instance.new("UIScale")
	sc.Parent = root
	root.Parent = g
	table.insert(pins, { root = root, scale = sc, at = at })
	if not pinning then
		pinning = true
		RunService:BindToRenderStep("AnimeFxPins", Enum.RenderPriority.Last.Value, placePins)
	end
	placePins()
	keep(root, life)
	return root
end

-- `x` by `y` studs (a pin's piece)
local function studs(x: number, y: number): UDim2
	return UDim2.fromOffset(math.floor(x * UNIT + 0.5), math.floor(y * UNIT + 0.5))
end

-- an image on a pin, `x` by `y` studs, turned `rot` degrees; a higher z is drawn over a lower one
local function piece(root: Frame, image: string, rect: { number }?, x: number, y: number, color: Color3, rot: number, z: number): ImageLabel
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency = 1
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.Position = UDim2.fromScale(0.5, 0.5)
	im.Size = studs(x, y)
	im.Image = image
	if rect then
		im.ImageRectOffset = Vector2.new(rect[1], rect[2])
		im.ImageRectSize = Vector2.new(rect[3], rect[4])
	end
	im.ImageColor3 = color
	im.Rotation = rot
	im.ZIndex = z
	im.Parent = root
	return im
end

-- the angle (degrees, on screen) of the line from p0 to p1 as the camera sees it now
local function screenAngle(p0: Vector3, p1: Vector3): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 0
	end
	local a = cam:WorldToViewportPoint(p0)
	local b = cam:WorldToViewportPoint(p1)
	return math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
end
AnimeFx.screenAngle = screenAngle

-- A cut where a blade passes: a white crescent over a coloured one, along the blade's path from `from` to `to` (world)
-- as the camera sees it, `size` studs across; it snaps open in a frame and thins away.
function AnimeFx.cut(at: Vector3, from: Vector3, to: Vector3, color: Color3?, size: number?)
	local s = size or 9
	local rot = screenAngle(from, to)
	local h = RECT_SLASH[4] / RECT_SLASH[3]
	local root = pin(at, 0.32)
	if not root then
		return
	end
	local glow = piece(root, FxIds.slash, RECT_SLASH, s * 1.3, s * 1.3 * h * 1.25, color or GOLD, rot, 1)
	local core = piece(root, FxIds.slash, RECT_SLASH, s * 0.55, s * h * 0.4, WHITE, rot, 2)
	glow.ImageTransparency = 0.1
	tween(core, 0.035, { Size = studs(s, s * h) }, Enum.EasingStyle.Linear)
	task.delay(0.09, function()
		tween(core, 0.16, { Size = studs(s * 1.15, s * h * 0.05) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(core, 0.16, { ImageTransparency = 0.6 })
		tween(glow, 0.2, { Size = studs(s * 1.5, s * h * 0.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(glow, 0.2, { ImageTransparency = 1 })
	end)
end

-- A cut across the whole frame (an ultimate): cut()'s crescent wider than the picture, flattened, through the world
-- point `at` along `from` -> `to` as the camera sees it, drawn over the picture's covers (a whiteout); `core` its middle
-- (white, or ink over a whiteout). (Tested in Studio: the world-sized crescent of ONE SNIP, 70 studs, was far bigger
-- than the frame from a lens close to him, and never seen.)
function AnimeFx.cutScreen(at: Vector3, from: Vector3, to: Vector3, color: Color3?, core: Color3?)
	local g = gui()
	local cam = workspace.CurrentCamera
	if not g or not cam then
		return
	end
	local vs = cam.ViewportSize
	local sp = cam:WorldToViewportPoint(at)
	local y = if sp.Z > 0 then math.clamp(sp.Y / math.max(vs.Y, 1), 0.25, 0.75) else 0.5
	local rot = screenAngle(from, to)
	local h = RECT_SLASH[4] / RECT_SLASH[3] * 0.45
	local root = Instance.new("Frame")
	root.Name = "CutScreen"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Z_PICTURE
	root.Parent = g
	local w = vs.X * 1.3
	local function arc(k: number, color3: Color3, z: number): ImageLabel
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.Image = FxIds.slash
		im.ImageRectOffset = Vector2.new(RECT_SLASH[1], RECT_SLASH[2])
		im.ImageRectSize = Vector2.new(RECT_SLASH[3], RECT_SLASH[4])
		im.ScaleType = Enum.ScaleType.Stretch
		im.ImageColor3 = color3
		im.AnchorPoint = Vector2.new(0.5, 0.5)
		im.Position = UDim2.fromScale(0.5, y)
		im.Size = UDim2.fromOffset(w * k, w * h * k)
		im.Rotation = rot
		im.ZIndex = z
		im.Parent = root
		return im
	end
	local glow = arc(1.08, color or GOLD, 1)
	local mid = arc(0.6, core or WHITE, 2)
	tween(mid, 0.04, { Size = UDim2.fromOffset(w, w * h) }, Enum.EasingStyle.Linear)
	task.delay(0.1, function()
		tween(mid, 0.2, { Size = UDim2.fromOffset(w * 1.1, w * h * 0.06) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(glow, 0.26, { Size = UDim2.fromOffset(w * 1.2, w * h * 0.12), ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	keep(root, 0.4)
end

-- radial needles (the reference's hit spikes): `n` thin hard wedges shooting out from a pin's point and gone
local function needles(root: Frame, s: number, color: Color3, n: number, z: number)
	for i = 1, n do
		local len = s * (1.1 + math.random() * 0.9)
		local w = s * (0.07 + math.random() * 0.06)
		local arm = Instance.new("Frame")
		arm.BackgroundTransparency = 1
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Position = UDim2.fromScale(0.5, 0.5)
		arm.Size = studs(len * 2.4, len * 2.4)
		arm.Rotation = (i - 1) * 360 / n + math.random(-16, 16)
		arm.ZIndex = z
		arm.Parent = root
		local nd = Instance.new("ImageLabel")
		nd.BackgroundTransparency = 1
		nd.Image = FxIds.blade
		nd.ImageRectOffset = Vector2.new(RECT_BLADE[1], RECT_BLADE[2])
		nd.ImageRectSize = Vector2.new(RECT_BLADE[3], RECT_BLADE[4])
		nd.ScaleType = Enum.ScaleType.Stretch
		nd.ImageColor3 = color
		nd.AnchorPoint = Vector2.new(0.5, 1)
		nd.Position = UDim2.new(0.5, 0, 0.5, -math.floor(s * 0.18 * UNIT))
		nd.Size = studs(w, len * 0.3)
		nd.Parent = arm
		tween(nd, 0.06, { Size = studs(w, len) }, Enum.EasingStyle.Quart)
		task.delay(0.07, function()
			tween(nd, 0.13, { Size = studs(w * 0.3, len * 1.15), ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
end

-- A hit: a white star that bursts into a ring (the impact flipbook) over a flash of colour, needles shooting out of it,
-- a flare and a long streak through it. `size` studs; `big`: more and longer needles.
function AnimeFx.hit(at: Vector3, color: Color3?, size: number?, big: boolean?)
	local s = size or 5
	local c = color or GOLD
	local root = pin(at, 0.3)
	if not root then
		return
	end
	local bloom = piece(root, FxIds.glow, nil, s * 1.6, s * 1.6, c, 0, 1)
	bloom.ImageTransparency = 0.25
	tween(bloom, 0.18, { Size = studs(s * 2.6, s * 2.6), ImageTransparency = 1 })
	needles(root, if big then s * 1.3 else s * 0.85, c:Lerp(WHITE, 0.45), if big then 9 else 5, 2)
	local streak = piece(root, FxIds.glow, nil, s * 7, s * 0.32, c, 0, 3)
	tween(streak, 0.25, { Size = studs(s * 10, s * 0.06) }, Enum.EasingStyle.Quad)
	tween(streak, 0.25, { ImageTransparency = 1 })
	local flare = piece(root, FxIds.flare, nil, s * 1.6, s * 1.6, c:Lerp(WHITE, 0.5), 0, 4)
	tween(flare, 0.14, { Size = studs(s * 2.4, s * 2.4) })
	tween(flare, 0.16, { ImageTransparency = 1 })
	local star = piece(root, FxIds.impact, { 0, 0, 256, 256 }, s, s, WHITE, math.random(0, 359), 5)
	task.spawn(function()
		for i = 1, 11 do
			task.wait(0.022)
			if not star.Parent then
				return
			end
			star.ImageRectOffset = Vector2.new((i % 4) * 256, math.floor(i / 4) * 256)
		end
	end)
end

-- A technique's title card: the picture darkened, a big seal at the left, the name in a heavy tracked serif between two
-- thin rules, the line under it in small spaced capitals; in and out on cuts. `mark`: the seal's character.
function AnimeFx.technique(name: string, sub: string, color: Color3?, life: number?, mark: string?)
	local g = gui()
	if not g then
		return
	end
	local c = color or Color3.fromRGB(255, 214, 90)
	local hold = life or 0.9
	local root = frame(g, "Technique", BLACK, 0.42, Z_TEXT)
	root:SetAttribute("KeepFont", true)
	seal(root, mark or string.sub(name, 1, 1), c, UDim2.fromScale(0.2, 0.47), 0.2, Z_TEXT + 2)
	local big = typeLabel(root, tracked(string.upper(name)), SERIF_BLACK, WHITE, Z_TEXT + 2)
	big.AnchorPoint = Vector2.new(0, 0.5)
	big.Position = UDim2.fromScale(0.29, 0.45)
	big.Size = UDim2.fromScale(0.56, 0.14)
	big.TextXAlignment = Enum.TextXAlignment.Left
	reveal(big, 0.12)
	rule(root, c, UDim2.fromScale(0.29, 0.365), 0.5, Z_TEXT + 2, 0)
	rule(root, c, UDim2.fromScale(0.29, 0.535), 0.5, Z_TEXT + 2, 0.05)
	local small = typeLabel(root, tracked(string.upper(sub)), SANS, Color3.fromRGB(226, 222, 232), Z_TEXT + 2)
	small.AnchorPoint = Vector2.new(0, 0.5)
	small.Position = UDim2.fromScale(0.29, 0.585)
	small.Size = UDim2.fromScale(0.45, 0.034)
	small.TextXAlignment = Enum.TextXAlignment.Left
	keep(root, hold)
end

-------------------------------------------------------------------------------------------------------------
-- speed lines (the radial picture, jittering every frame so they rush), until stop()
-------------------------------------------------------------------------------------------------------------
function AnimeFx.lines(color: Color3?, alpha: number?, at: Vector3?): () -> ()
	local g = gui()
	if not g then
		return function() end
	end
	local im = Instance.new("ImageLabel")
	im.Name = "SpeedLines"
	im.BackgroundTransparency = 1
	im.Image = TEX_LINES
	im.ImageColor3 = color or WHITE
	im.ImageTransparency = alpha or 0.35
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.SizeConstraint = Enum.SizeConstraint.RelativeXX
	im.Size = UDim2.fromScale(2.4, 2.4)
	im.Position = UDim2.fromScale(0.5, 0.5)
	im.ZIndex = Z_PICTURE
	im.Parent = g
	table.insert(live, im)
	local on = true
	task.spawn(function()
		while on and im.Parent do
			im.Rotation = math.random(0, 359)
			local s = 2.3 + math.random() * 0.3
			im.Size = UDim2.fromScale(s, s)
			if at then
				local cam = workspace.CurrentCamera
				if cam then
					local sp = cam:WorldToViewportPoint(at)
					local vs = cam.ViewportSize
					im.Position = UDim2.fromScale(sp.X / math.max(vs.X, 1), sp.Y / math.max(vs.Y, 1))
				end
			end
			task.wait(0.045)
		end
	end)
	return function()
		on = false
		if im.Parent then
			tween(im, 0.12, { ImageTransparency = 1 })
			task.delay(0.15, function()
				im:Destroy()
			end)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- impact frames
-------------------------------------------------------------------------------------------------------------
local STYLES: { [string]: { bg: Color3, ink: Color3, lines: Color3 } } = {
	ink = { bg = WHITE, ink = BLACK, lines = BLACK },
	neg = { bg = BLACK, ink = WHITE, lines = WHITE },
	red = { bg = Color3.fromRGB(214, 24, 40), ink = BLACK, lines = BLACK },
	gold = { bg = Color3.fromRGB(255, 186, 40), ink = BLACK, lines = Color3.fromRGB(255, 246, 214) },
	pink = { bg = PINK, ink = BLACK, lines = WHITE },
	dark = { bg = Color3.fromRGB(14, 8, 20), ink = Color3.fromRGB(255, 226, 240), lines = PINK },
}
AnimeFx.STYLES = STYLES

-- Flat copies of the subjects (every part white neon, no textures), for the silhouettes.
local function silhouettes(subjects: { Instance? }, vp: ViewportFrame)
	for _, s in subjects do
		if s and s.Parent then
			local ok, c = pcall(function()
				local was = s.Archivable
				s.Archivable = true
				local copy = s:Clone()
				s.Archivable = was
				return copy
			end)
			if ok and c then
				for _, d in c:GetDescendants() do
					if d:IsA("BasePart") then
						if d.Transparency < 0.95 and d.LocalTransparencyModifier < 0.95 then
							d.Color = WHITE
							d.Material = Enum.Material.Neon
							d.Transparency = 0
							if d:IsA("MeshPart") then
								d.TextureID = ""
							end
						end
					elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("Clothing") or d:IsA("ShirtGraphic") then
						d:Destroy()
					end
				end
				c.Parent = vp
			end
		end
	end
end

local lastImpact = -math.huge

-- An impact frame; `subjects` are models or parts in the world (seen from the film's camera as it is now); opts:
-- hold (seconds, default 0.12), at (a world point the lines burst from), states (for "strobe": a list of styles),
-- shake (studs of jolt to the frame).
function AnimeFx.impact(subjects: { Instance? }, style: string, opts: any?): boolean
	local o = opts or {}
	local g = gui()
	local cam = workspace.CurrentCamera
	if not g or not cam then
		return false
	end
	local now = os.clock()
	if now - lastImpact < 0.25 then
		return false
	end
	lastImpact = now
	if calm() then
		Film.flash(WHITE, 0.35, 0.3)
		return false
	end
	local states: { string } = if style == "strobe" then (o.states or { "ink", "neg", "red", "neg", "ink" }) else { style }
	local per = o.per or (if style == "strobe" then 0.06 else (o.hold or 0.12) / #states)
	local hold = per * #states
	local root = frame(g, "Impact", WHITE, 0, Z_PICTURE)
	root.ClipsDescendants = true
	-- where the lines burst from
	local centre = UDim2.fromScale(0.5, 0.5)
	local at = o.at
	if not at then
		local first = subjects[1]
		if first and first:IsA("Model") then
			at = first:GetPivot().Position
		elseif first and first:IsA("BasePart") then
			at = first.Position
		end
	end
	if at then
		local sp, onScreen = cam:WorldToViewportPoint(at)
		if onScreen then
			local vs = cam.ViewportSize
			centre = UDim2.fromScale(sp.X / math.max(vs.X, 1), sp.Y / math.max(vs.Y, 1))
		end
	end
	local lines = Instance.new("ImageLabel")
	lines.Name = "Lines"
	lines.BackgroundTransparency = 1
	lines.Image = TEX_LINES
	lines.AnchorPoint = Vector2.new(0.5, 0.5)
	lines.SizeConstraint = Enum.SizeConstraint.RelativeXX
	lines.Size = UDim2.fromScale(2.4, 2.4)
	lines.Position = centre
	lines.ZIndex = Z_PICTURE
	lines.Parent = root
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Silhouettes"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = WHITE
	vp.LightColor = WHITE
	vp.ZIndex = Z_PICTURE
	vp.Parent = root
	local vcam = Instance.new("Camera")
	vcam.CFrame = cam.CFrame
	vcam.FieldOfView = cam.FieldOfView
	vcam.Parent = vp
	vp.CurrentCamera = vcam
	silhouettes(subjects, vp)
	local function show(i: number)
		local s = STYLES[states[i]] or STYLES.ink
		root.BackgroundColor3 = s.bg
		vp.ImageColor3 = s.ink
		lines.ImageColor3 = s.lines
		lines.ImageTransparency = 0.1
		lines.Rotation = math.random(0, 359)
		local j = o.shake or 10
		root.Position = UDim2.fromOffset(math.random(-j, j), math.random(-j, j))
	end
	show(1)
	Film.freeze(hold)
	for i = 2, #states do
		task.delay(per * (i - 1), function()
			if root.Parent then
				show(i)
			end
		end)
	end
	keep(root, hold)
	return true
end

-------------------------------------------------------------------------------------------------------------
-- covers: a flat colour over the picture (under the bars), eased to `alpha` (0 = solid) over `time`
-------------------------------------------------------------------------------------------------------------
local covers: { [string]: Frame } = {}
function AnimeFx.cover(color: Color3, alpha: number, time: number?, key: string?)
	local g = gui()
	if not g then
		return
	end
	local k = key or "Cover"
	local f = covers[k]
	if not f or not f.Parent then
		f = frame(g, "AnimeCover_" .. k, color, 1, Z_PICTURE)
		covers[k] = f
		table.insert(live, f)
	end
	assert(f)
	if (time or 0) <= 0 then
		f.BackgroundColor3 = color
		f.BackgroundTransparency = alpha
	else
		f.BackgroundColor3 = color
		tween(f, time or 0.3, { BackgroundTransparency = alpha }, Enum.EasingStyle.Sine)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the title: the game's logo (the loading screen's) slams in from big, a shock ring and sparkles; it holds
-------------------------------------------------------------------------------------------------------------
function AnimeFx.logo(): Frame?
	local g = gui()
	if not g then
		return nil
	end
	local ids = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("IconIds")) :: any
	local root = Instance.new("Frame")
	root.Name = "Title"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Z_TEXT
	root.Parent = g
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = ids.glow_soft or TEX_GLOW
	glow.ImageColor3 = Color3.fromRGB(255, 214, 120)
	glow.ImageTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.47)
	glow.SizeConstraint = Enum.SizeConstraint.RelativeYY
	glow.Size = UDim2.fromScale(1.5, 1.1)
	glow.ZIndex = Z_TEXT
	glow.Parent = root
	local logo: GuiObject
	if ids.logo then
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.Image = ids.logo
		im.ScaleType = Enum.ScaleType.Fit
		im.ImageTransparency = 1
		logo = im
	else
		local t = label(root, "MOW A LAWN", Enum.Font.FredokaOne, Color3.fromRGB(255, 230, 120), Z_TEXT + 1)
		stroke(t, 6)
		t.TextTransparency = 1
		logo = t
	end
	logo.Name = "Logo"
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.fromScale(0.5, 0.47)
	logo.SizeConstraint = Enum.SizeConstraint.RelativeYY
	logo.Size = UDim2.fromScale(1.15 * 2.2, 0.76 * 2.2)
	logo.ZIndex = Z_TEXT + 1
	logo.Parent = root
	-- the slam (0.12 s), a flash, a ring
	tween(logo, 0.12, { Size = UDim2.fromScale(1.15, 0.76) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	if logo:IsA("ImageLabel") then
		tween(logo, 0.08, { ImageTransparency = 0 })
	elseif logo:IsA("TextLabel") then
		tween(logo, 0.08, { TextTransparency = 0 })
	end
	task.delay(0.12, function()
		if not root.Parent then
			return
		end
		Film.shake(0.5, 2.4)
		Film.flash(WHITE, 0.5, 0.35)
		tween(glow, 0.3, { ImageTransparency = 0.25 })
		local ring = Instance.new("Frame")
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.47)
		ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
		ring.Size = UDim2.fromScale(0.3, 0.3)
		ring.ZIndex = Z_TEXT
		ring.Parent = root
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring
		local st = stroke(ring, 10, Color3.fromRGB(255, 236, 170))
		tween(ring, 0.5, { Size = UDim2.fromScale(2.2, 2.2) }, Enum.EasingStyle.Quart)
		tween(st, 0.5, { Transparency = 1, Thickness = 1 })
		-- a slow push in while it holds
		tween(logo, 3.5, { Size = UDim2.fromScale(1.15 * 1.06, 0.76 * 1.06) }, Enum.EasingStyle.Sine)
	end)
	table.insert(live, root)
	return root
end

-------------------------------------------------------------------------------------------------------------
-- a word on its own (the finale's THE FINAL FIGHT): black, the title in a heavy tracked serif, a rule drawing under it,
-- the line under that in small spaced capitals a beat later
-------------------------------------------------------------------------------------------------------------
function AnimeFx.word(big: string, small: string?, color: Color3?): Frame?
	local g = gui()
	if not g then
		return nil
	end
	local c = color or CRIMSON
	local root = frame(g, "Word", BLACK, 0, Z_TEXT)
	root:SetAttribute("KeepFont", true)
	local t = typeLabel(root, tracked(string.upper(big)), SERIF_BLACK, WHITE, Z_TEXT + 1)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.45)
	t.Size = UDim2.fromScale(0.72, 0.13)
	reveal(t, 0.2)
	local r = rule(root, c, UDim2.fromScale(0.5, 0.535), 0.3, Z_TEXT + 1, 0.15)
	r.AnchorPoint = Vector2.new(0.5, 0)
	if small then
		local s = typeLabel(root, tracked(string.upper(small)), SANS, Color3.fromRGB(200, 196, 214), Z_TEXT + 1)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5, 0.59)
		s.Size = UDim2.fromScale(0.4, 0.036)
		s.TextTransparency = 1
		task.delay(0.8, function()
			if s.Parent then
				tween(s, 0.4, { TextTransparency = 0 })
			end
		end)
	end
	table.insert(live, root)
	return root
end

function AnimeFx.clear()
	for _, i in live do
		if i.Parent then
			i:Destroy()
		end
	end
	table.clear(live)
	table.clear(covers)
	lastSub = nil
	lastImpact = -math.huge
end

return AnimeFx
