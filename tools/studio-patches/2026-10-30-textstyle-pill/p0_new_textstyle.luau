-- Creates client/TextStyle in Studio (a new ModuleScript, exactly git's text). Run in Edit mode.
local src = [=====[
-- Every text in our UI style (owner, 30 Oct: "i feel like u could use the text from our ui style so please do that
-- for every text"). Our style is the films' name cards and title card (client/IntroUi) and every UI.text: Fredoka One
-- (Config.UI.font), the dark outline (Config.UI.outline) as a UIStroke about 8% of the letters' height, and big
-- headlines in the title card's two tones, gold over orange.
--
-- Every TextLabel / TextButton / TextBox in the player's screens (PlayerGui) and in the world (SurfaceGuis and
-- BillboardGuis in Workspace: the generated signs, the saved place's gate and hub signs, anything added later):
--   * the font becomes Fredoka One
--   * the outline: a text with none gets ours (if its words are light, it isn't a see-through ghost copy and it isn't
--     only emoji); a near-black outline it already has turns into ours; a coloured one (a glow, a rarity) is kept, and
--     so is every thickness. Ours fades with its text (a UIStroke doesn't follow TextTransparency by itself).
--   * headlines: one big line in capitals (34+ px, or a quarter of its sign), white, not a number readout and not a
--     button's label, gets the title card's gradient; a gold-over-orange gradient a sign already wears (the old sign
--     style) is swapped for the title card's
-- Left alone: Roblox's own guis in PlayerGui (touch controls, proximity prompts, the old chat; CoreGui is never
-- touched), anything with the attribute KeepFont = true on it or on a parent, handwriting and brush lettering (the
-- party journal, the photo caption, the anime credits' brush headings: PatrickHand, PermanentMarker), monospace (the
-- dev tools), and texts with Roblox's private-use icon glyphs (the Robux mark only draws in Builder Sans).
--
-- Cheap: only the PlayerGui and Workspace DescendantAdded events (a class-name lookup per new instance), each text
-- styled once, a frame after it appears (so the code that made it has set its font and colours first), at most
-- BATCH a frame. Only texts given our outline or a headline gradient keep listeners, and those hold them weakly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local TextStyle = {}

local FONT = Config.UI.font
local FAMILY = Font.fromEnum(FONT).Family
local OUTLINE = Config.UI.outline
local GOLD = Color3.fromRGB(255, 236, 110)
local ORANGE = Color3.fromRGB(255, 140, 30)
-- the title card's gradient (client/IntroUi title): gold, a hard line just under the middle, orange going darker
TextStyle.TITLE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, GOLD),
	ColorSequenceKeypoint.new(0.52, GOLD),
	ColorSequenceKeypoint.new(0.56, ORANGE),
	ColorSequenceKeypoint.new(1, Color3.new(ORANGE.R * 0.85, ORANGE.G * 0.85, ORANGE.B * 0.85)),
})
-- the opt-out: KeepFont = true on a text, or on any frame / gui / model above it
TextStyle.KEEP = "KeepFont"

local OUTLINE_NAME = "TextStyleOutline"
local TITLE_NAME = "TextStyleTitle"
local OUTLINE_PER_PX = 0.08 -- outline thickness per pixel of letter height (UI.text: 2.5 on a 30 px line)
local OUTLINE_MIN, OUTLINE_MAX, OUTLINE_DEFAULT = 1, 6, 2.5
local HEADLINE_PX = 34 -- how tall a line must be (layout pixels) to count as a headline; on a sign: a quarter of it
local HEADLINE_SHARE = 0.25
local BATCH = 300 -- texts styled per frame at most
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }
-- (Font families matched by name: Enum.Font.Code is Inconsolata, RobotoMono has "Mono")
local KEEP_FAMILIES = { "PatrickHand", "PermanentMarker", "Inconsolata", "Mono", "SourceCode" }
local ROBLOX_GUIS = { TouchGui = true, ProximityPrompts = true, BubbleChat = true, Chat = true, Freecam = true, RbxCameraUI = true }
local WEAK_K = { __mode = "k" }
local WEAK_V = { __mode = "v" }

local done: { [Instance]: boolean } = setmetatable({}, WEAK_K) :: any

local function keptFamily(family: string): boolean
	for _, name in KEEP_FAMILIES do
		if string.find(family, name, 1, true) then
			return true
		end
	end
	return false
end

-- Roblox's private-use icon glyphs, U+E000-U+F8FF (UTF-8: EE xx xx, or EF 80-A3 xx); the Robux mark is U+E002
local function hasIcon(s: string): boolean
	return string.find(s, "\238") ~= nil or string.find(s, "\239[\128-\163]") ~= nil
end

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function nearBlack(c: Color3): boolean
	return math.max(c.R, c.G, c.B) <= 0.35
end

local function white(c: Color3): boolean
	return c.R >= 0.92 and c.G >= 0.92 and c.B >= 0.92
end

-- One short line in capitals with a few letters: "AREA CLEARED!", "SHOP", "TIMBER!" (not "1.2K", "3:05", "x5", a
-- sentence, rich text, or words with emoji in them, which a gradient would tint).
local function headline(s: string): boolean
	if s == "" or #s > 80 or string.find(s, "\n") or string.find(s, "%l") or string.find(s, "[\240-\244]") then
		return false
	end
	local n = utf8.len(s)
	if not n or n > 28 then
		return false
	end
	local _, letters = string.gsub(s, "%a", "")
	local _, digits = string.gsub(s, "%d", "")
	return letters >= 3 and digits <= 2
end

-- the old sign style's gradient: gold at the top going to orange at the bottom
local function warmTitle(g: UIGradient): boolean
	local keys = g.Color.Keypoints
	local top, bottom = keys[1].Value, keys[#keys].Value
	local r = g.Rotation % 360
	return r > 80 and r < 100
		and top.R >= 0.85 and top.G >= 0.7 and top.B <= 0.6
		and bottom.R >= 0.75 and bottom.G >= 0.3 and bottom.G <= 0.65 and bottom.B <= 0.35
end

-- How tall its letters are, in its own gui's pixels before any UIScale (0 = can't tell yet).
local function letterHeight(t: any, layer: Instance): number
	if not t.TextScaled then
		return t.TextSize
	end
	local size: UDim2 = t.Size
	if size.Y.Scale == 0 and size.Y.Offset > 0 then
		return math.min(size.Y.Offset, 100) -- (TextScaled letters stop at 100 px)
	end
	if layer:IsA("BillboardGui") then
		return 0 -- (its pixels change with the distance)
	end
	local h = t.AbsoluteSize.Y
	if h > 1 and layer:IsA("ScreenGui") then
		local sc = layer:FindFirstChildOfClass("UIScale")
		if sc and sc.Scale > 0.05 then
			h /= sc.Scale
		end
	end
	return math.min(h, 100)
end

local function thickness(h: number): number
	if h <= 0 then
		return OUTLINE_DEFAULT
	end
	return math.clamp(math.floor(h * OUTLINE_PER_PX * 2 + 0.5) / 2, OUTLINE_MIN, OUTLINE_MAX)
end

-- Does a text with no outline get ours?
local function wantsOutline(t: any, text: string): boolean
	if t:IsA("TextButton") and text == "" then
		return false -- (a button that's only a clickable box: its words are a label of their own)
	end
	if text ~= "" and not string.find(text, "%w") then
		return false -- (only emoji or symbols)
	end
	local tt = t.TextTransparency
	if tt > 0.01 and tt < 0.99 then
		return false -- (a see-through layer: a glitch's colour ghost, a watermark)
	end
	return luminance(t.TextColor3) >= 0.35 -- (dark words on a light card or paper stay as they are)
end

-- Our outline fades with its text (a text faded out would otherwise leave its outline hanging in the air), and gives
-- way to an outline the text's own code adds later. Held weakly, so a text dropped without Destroy can still go.
local function follow(t: any, stroke: UIStroke, base: number)
	local ref = setmetatable({ t = t, s = stroke }, WEAK_V)
	local function sync()
		local tt, s = ref.t, ref.s
		if tt and s and s.Parent == tt then
			s.Transparency = math.max(base, tt.TextTransparency)
		end
	end
	sync()
	t:GetPropertyChangedSignal("TextTransparency"):Connect(sync)
	t.ChildAdded:Connect(function(c)
		local s = ref.s
		if s and c ~= s and c:IsA("UIStroke") then
			s:Destroy()
		end
	end)
end

-- A big label gets the title gradient while it reads as a headline in white (its words and colour can change later),
-- and loses it to a gradient its own code adds.
local function watchTitle(t: TextLabel)
	local ref = setmetatable({ t = t }, WEAK_V)
	local function refresh()
		local l = ref.t
		if not l then
			return
		end
		local mine: Instance? = nil
		local theirs = false
		for _, c in l:GetChildren() do
			if c:IsA("UIGradient") then
				if c.Name == TITLE_NAME then
					mine = c
				else
					theirs = true
				end
			end
		end
		if theirs then
			if mine then
				mine:Destroy()
			end
			return
		end
		local want = white(l.TextColor3) and headline(l.Text)
		if mine then
			(mine :: UIGradient).Enabled = want
		elseif want then
			local g = Instance.new("UIGradient")
			g.Name = TITLE_NAME
			g.Color = TextStyle.TITLE
			g.Rotation = 90
			g.Parent = l
		end
	end
	refresh()
	t:GetPropertyChangedSignal("Text"):Connect(refresh)
	t:GetPropertyChangedSignal("TextColor3"):Connect(refresh)
	t.ChildAdded:Connect(function(c)
		if c:IsA("UIGradient") and c.Name ~= TITLE_NAME then
			refresh()
		end
	end)
end

-- What a text is drawn in: its gui (nil = not drawn, or one to leave alone) and whether it's a button's label.
local function placeOf(t: Instance): (Instance?, boolean)
	local layer: Instance? = nil
	local inButton = false
	local o: Instance? = t
	while o and o ~= game do
		if o:GetAttribute(TextStyle.KEEP) == true then
			return nil, false
		end
		if o ~= t and o:IsA("GuiButton") then
			inButton = true
		end
		if not layer and o:IsA("LayerCollector") then
			layer = o
			local up = o.Parent
			if ROBLOX_GUIS[o.Name] and up and up:IsA("PlayerGui") then
				return nil, false
			end
		end
		o = o.Parent
	end
	return layer, inButton
end

local function style(t: any)
	if done[t] or not t.Parent then
		return
	end
	local layer, inButton = placeOf(t)
	if not layer then
		return
	end
	done[t] = true
	local text: string = t.Text
	local family = t.FontFace.Family
	if keptFamily(family) or hasIcon(text) then
		return
	end
	-- the font
	if family ~= FAMILY then
		t.Font = FONT
	end
	local stroke: UIStroke? = nil
	local gradient: UIGradient? = nil
	for _, c in t:GetChildren() do
		if not stroke and c:IsA("UIStroke") then
			stroke = c
		elseif not gradient and c:IsA("UIGradient") then
			gradient = c
		end
	end
	-- the outline
	local h = letterHeight(t, layer)
	local base = if t.TextStrokeTransparency < 1 then t.TextStrokeTransparency else 0
	if stroke then
		if stroke.Name == OUTLINE_NAME then
			follow(t, stroke, base) -- (a copy of a text we outlined)
		elseif stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual and nearBlack(stroke.Color) then
			stroke.Color = OUTLINE
		end
	elseif wantsOutline(t, text) then
		local s = Instance.new("UIStroke")
		s.Name = OUTLINE_NAME
		s.Color = OUTLINE
		s.Thickness = thickness(h)
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
		follow(t, s, base)
	end
	-- the headline gradient
	if gradient and gradient.Name ~= TITLE_NAME then
		if warmTitle(gradient) then
			gradient.Color = TextStyle.TITLE
		end
	elseif t:IsA("TextLabel") and not inButton then
		local bigLine = h >= HEADLINE_PX or (not layer:IsA("ScreenGui") and t.Size.Y.Scale >= HEADLINE_SHARE)
		if bigLine or gradient then
			watchTitle(t)
		end
	end
end

-- the queue: styled a frame after they appear, BATCH a frame
local queue: { [number]: Instance } = {}
local first, last = 1, 0
local running = false
local warned = 0

local function work()
	local n = 0
	while first <= last do
		local t = queue[first]
		queue[first] = nil
		first += 1
		local ok, err = pcall(style, t)
		if not ok and warned < 3 then
			warned += 1
			warn("[TextStyle] " .. tostring(err))
		end
		n += 1
		if n >= BATCH then
			n = 0
			task.wait()
		end
	end
	running = false
end

local function push(d: Instance)
	if TEXT_CLASSES[d.ClassName] and not done[d] then
		last += 1
		queue[last] = d
		if not running then
			running = true
			task.defer(work)
		end
	end
end

-- everything already there, a slice at a time (the world can hold a great many instances)
local function scan(root: Instance)
	for i, d in root:GetDescendants() do
		push(d)
		if i % 4000 == 0 then
			task.wait()
		end
	end
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
playerGui.DescendantAdded:Connect(push)
workspace.DescendantAdded:Connect(push)
task.spawn(scan, playerGui)
task.spawn(scan, workspace)

return TextStyle
]=====]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "12264 1639211097" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.StarterPlayer.StarterPlayerScripts.MowALawnClient
if folder:FindFirstChild("TextStyle") then
	return "TextStyle is already there: " .. hashOf(folder.TextStyle.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "TextStyle"
m.Source = src
m.Parent = folder
return "TextStyle installed: " .. hashOf(m.Source)
