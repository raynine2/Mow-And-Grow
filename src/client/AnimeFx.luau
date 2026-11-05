-- ANIME FX (Films v2, 5 Nov 2026): the new films' 2D layer, drawn into the films' ScreenGui (client/IntroUi) under
-- its letterbox bars and SKIP button, after the owner's reference cutscenes (Roblox anime cutscenes: bracketed
-- subtitles, a big name card, white slash frames, speed lines, impact frames that flatten the picture to black and
-- white for a frame or two, whiteouts, the title slammed in on the beat). Our own shapes, words and colours only.
--   AnimeFx.sub(text, life?)                 a subtitle, "[like this]"
--   AnimeFx.card(name, title, color?, life?) a character's name card (RAYAN / OWNER OF THE VALLEY)
--   AnimeFx.slash(angle, opts?)              a white cut across the screen for a frame or two
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
-- subtitles: one at a time, bottom middle, just over the bottom bar
-------------------------------------------------------------------------------------------------------------
local lastSub: TextLabel? = nil
function AnimeFx.sub(text: string, life: number?)
	local g = gui()
	if not g then
		return
	end
	if lastSub and lastSub.Parent then
		local old = lastSub
		tween(old, 0.08, { TextTransparency = 1 })
		task.delay(0.1, function()
			old:Destroy()
		end)
	end
	local bar = IntroUi.bar()
	local t = label(g, "[" .. text .. "]", Enum.Font.GothamBold, WHITE, Z_TEXT)
	t.Name = "Sub"
	t.AnchorPoint = Vector2.new(0.5, 1)
	t.Position = UDim2.fromScale(0.5, 1 - bar - 0.025)
	t.Size = UDim2.fromScale(0.8, 0.05)
	t.TextTransparency = 1
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 34
	lim.MinTextSize = 14
	lim.Parent = t
	local st = stroke(t, 2.2)
	st.Transparency = 1
	tween(t, 0.1, { TextTransparency = 0 })
	tween(st, 0.1, { Transparency = 0 })
	lastSub = t
	local hold = life or math.clamp(0.9 + #text * 0.05, 1.2, 3.2)
	task.delay(hold, function()
		if t.Parent then
			tween(t, 0.25, { TextTransparency = 1 })
			tween(st, 0.25, { Transparency = 1 })
		end
	end)
	keep(t, hold + 0.3)
end

-------------------------------------------------------------------------------------------------------------
-- the name card: a dark band slams across on a slant, the name in huge letters drives in from the right, the title
-- under it in gold; a white cut runs along the band as it lands
-------------------------------------------------------------------------------------------------------------
function AnimeFx.card(name: string, title: string, color: Color3?, life: number?)
	local g = gui()
	if not g then
		return
	end
	local c = color or GOLD
	local hold = life or 1.9
	local root = Instance.new("Frame")
	root.Name = "NameCard"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Z_TEXT
	root.Parent = g
	-- the band
	local band = frame(root, "Band", Color3.fromRGB(10, 8, 14), 0.08, Z_TEXT)
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Size = UDim2.fromScale(1.6, 0.26)
	band.Position = UDim2.fromScale(-0.9, 0.62)
	band.Rotation = -7
	local edgeTop = frame(band, "EdgeTop", c, 0, Z_TEXT)
	edgeTop.Size = UDim2.new(1, 0, 0, 4)
	local edgeBot = frame(band, "EdgeBottom", c, 0, Z_TEXT)
	edgeBot.Size = UDim2.new(1, 0, 0, 4)
	edgeBot.Position = UDim2.new(0, 0, 1, -4)
	-- the name
	local big = label(root, string.upper(name), Enum.Font.GothamBlack, WHITE, Z_TEXT + 1)
	big.AnchorPoint = Vector2.new(0, 0.5)
	big.Size = UDim2.fromScale(0.62, 0.17)
	big.Position = UDim2.fromScale(1.2, 0.585)
	big.Rotation = -7
	big.TextXAlignment = Enum.TextXAlignment.Left
	stroke(big, 3)
	local small = label(root, string.upper(title), Enum.Font.PermanentMarker, c, Z_TEXT + 1)
	small.AnchorPoint = Vector2.new(0, 0.5)
	small.Size = UDim2.fromScale(0.5, 0.06)
	small.Position = UDim2.fromScale(1.3, 0.69)
	small.Rotation = -7
	small.TextXAlignment = Enum.TextXAlignment.Left
	stroke(small, 2)
	-- in: band sweeps, name drives in, title a beat later
	tween(band, 0.16, { Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Quart)
	tween(big, 0.2, { Position = UDim2.fromScale(0.16, 0.585) }, Enum.EasingStyle.Back)
	task.delay(0.1, function()
		tween(small, 0.22, { Position = UDim2.fromScale(0.2, 0.69) }, Enum.EasingStyle.Quart)
	end)
	task.delay(0.15, function()
		if root.Parent then
			AnimeFx.slash(-7, { y = 0.62, life = 0.12, width = 0.012 })
		end
	end)
	-- a slow drift while it holds, then out to the left
	tween(big, hold, { Position = UDim2.fromScale(0.12, 0.585) }, Enum.EasingStyle.Linear)
	task.delay(hold, function()
		if root.Parent then
			tween(band, 0.18, { Position = UDim2.fromScale(2.2, 0.62) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			tween(big, 0.16, { Position = UDim2.fromScale(-0.8, 0.585), TextTransparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			tween(small, 0.16, { Position = UDim2.fromScale(-0.7, 0.69), TextTransparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		end
	end)
	keep(root, hold + 0.3)
end

-------------------------------------------------------------------------------------------------------------
-- a slash: a long white blade of light across the screen at `angle` degrees, through (0.5, opts.y), shown for a
-- frame or two and gone (opts: y, life, width, color, x)
-------------------------------------------------------------------------------------------------------------
function AnimeFx.slash(angle: number, opts: any?)
	local g = gui()
	if not g then
		return
	end
	local o = opts or {}
	local life = o.life or 0.09
	local f = frame(g, "Slash", o.color or WHITE, 0, Z_PICTURE)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(o.x or 0.5, o.y or 0.5)
	f.Size = UDim2.fromScale(0.05, o.width or 0.03)
	f.Rotation = angle
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.15),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.82, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = f
	-- (the blade tapers: thinner at the ends)
	local core = frame(f, "Core", WHITE, 0, Z_PICTURE)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(1, 0.35)
	tween(f, life * 0.4, { Size = UDim2.fromScale(2.4, o.width or 0.03) }, Enum.EasingStyle.Quart)
	task.delay(life * 0.5, function()
		if f.Parent then
			tween(f, life * 0.6, { BackgroundTransparency = 1, Size = UDim2.fromScale(2.6, 0.002) })
			tween(core, life * 0.6, { BackgroundTransparency = 1 })
		end
	end)
	keep(f, life + 0.05)
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
		local t = label(root, "MOW A LAWN", Enum.Font.GothamBlack, Color3.fromRGB(255, 230, 120), Z_TEXT + 1)
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
-- a word on its own (the finale's YOU.), a line under it
-------------------------------------------------------------------------------------------------------------
function AnimeFx.word(big: string, small: string?, color: Color3?): Frame?
	local g = gui()
	if not g then
		return nil
	end
	local root = frame(g, "Word", BLACK, 0, Z_TEXT)
	local t = label(root, big, Enum.Font.GothamBlack, color or WHITE, Z_TEXT + 1)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.46)
	t.Size = UDim2.fromScale(0.7, 0.22)
	t.TextTransparency = 1
	tween(t, 0.06, { TextTransparency = 0 })
	if small then
		local s = label(root, small, Enum.Font.GothamBold, Color3.fromRGB(200, 196, 214), Z_TEXT + 1)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5, 0.62)
		s.Size = UDim2.fromScale(0.6, 0.045)
		s.TextTransparency = 1
		task.delay(0.9, function()
			if s.Parent then
				tween(s, 0.5, { TextTransparency = 0 })
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
