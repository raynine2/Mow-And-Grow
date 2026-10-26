-- The class stand, as Chop A Forest's v2 card deal (window "Classes", opened by the stand's prompt or pad), full
-- screen over the 3D class room (client/ClassRoom: your avatar on a turning rune circle, candles, sparkles):
--   top: CL*SSES, NEW CARDS IN timer + bar, gems   left: VS YOUR CLASS, RESTOCK / LUCKY RESTOCK (Robux)
--   right: the picked class's big card (stars, picture, perks, quote, odds, gems / Robux), glowing in its rarity
--   bottom: STOCK / OWNED tabs and a row of tall cards, each with its % chance to be in a deal (odds shown because
--   the restocks are paid random items). A new deal flips the cards over one by one; a Legendary or rarer card in
--   the new deal gets a full-screen reveal, and buying a class gets "IS YOURS!" + confetti.
-- Themed as the GARDENERS' GUILD (22 Oct 2026, the owner's pick; it was a space theme): cork notice boards in honey-
-- wood frames, the big card a pinned parchment notice with a wax seal in its rarity colour, the timer a chalkboard
-- ("FRESH STOCK IN"), face-down cards as kraft envelopes with the guild crest, fireflies instead of stars. Each
-- piece falls back to the old look while its ForgeGUI picture isn't uploaded. (The 3D room behind is unchanged.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Policy = require(ReplicatedStorage.MowALawn:WaitForChild("Policy"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Confetti = require(script.Parent.Confetti)
local Skin = require(script.Parent.Skin)

local ClassDeal = {}
local C = UI.colors
local W = UI.wood
local player = Players.LocalPlayer

local BIG_REVEAL = { Legendary = true, Mythic = true, Secret = true }
local SHINE = { Epic = true, Legendary = true, Mythic = true, Secret = true }
local STATS = {
	{ key = "power", label = "Mow power", pct = true },
	{ key = "speed", label = "Walk speed", pct = true },
	{ key = "sell", label = "Sell price", pct = true },
	{ key = "luck", label = "Mutation luck", pct = true },
	{ key = "carry", label = "Bundles carried", pct = false },
}
local STAT_ICON = { power = "upgrade", speed = "stopwatch", sell = "coin", luck = "clover", carry = "backpack" }

local function statText(s, v: number?): string
	if not v or v == 0 then
		return "-"
	end
	return if s.pct then "+" .. math.floor(v * 100 + 0.5) .. "%" else "+" .. v
end

local function pctText(x: number?): string
	local p = (x or 0) * 100
	if p >= 10 then
		return string.format("%d%%", math.floor(p + 0.5))
	end
	return string.format("%.1f%%", p)
end

-- The stock this player sees: a Restock bought this window, otherwise the booth's stock.
local function currentStock(d): ({ string }, boolean)
	local w = Config.stockWindow()
	local deal = d and d.classDeal
	if deal and Config.dealActive(deal) and deal.ids then
		return deal.ids, deal.lucky == true
	end
	return Config.classStock(w), false
end

-------------------------------------------------------------------------------------------------------------
-- layout: full screen (1280 x 720) over the 3D class room (client/ClassRoom), like Chop A Forest's class screen
-------------------------------------------------------------------------------------------------------------
local VFX = require(ReplicatedStorage:WaitForChild("VFXLib"))
local ClassRoom = require(script.Parent.ClassRoom)
local Tex = VFX.Assets.Tex
local NAVY = Color3.fromRGB(18, 14, 48)
local GOLD = Color3.fromRGB(255, 200, 80)
local STAR_IMG = "rbxassetid://97457865936415" -- white 5-point star with a navy outline (tinted), Store Icons/ClassArt/UIStar.png
local RARITY_STARS = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local STRIPED = { Epic = true, Legendary = true, Mythic = true, Secret = true } -- hazard stripes on the big card
-- Secret cards are prismatic (Chop A Forest's Exclusive look) instead of their near-black colour
local PRISM = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 70, 230)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(240, 80, 200)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(70, 200, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 230, 140)),
})
-- SPACE THEME. Panels are deep-space glass (violet to near-black, a few stars inside) with a slowly turning
-- energy rim (cyan -> violet -> pink); rarity rims turn too (Legendary gold shimmer, Mythic/Secret rainbow), per
-- the UI-motion notes: gradient drift / rotation 4-6 s Linear, shine sweep 0.8 s then rest, slow 12-20 s rays.
local ENERGY = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(160, 120, 255)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 120, 220)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 220, 255)),
})
local GOLD_SHIMMER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 250, 200)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 40)),
})
local RAINBOW = ColorSequence.new({ -- first colour = last colour, so the turn never seams
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 180, 60)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(240, 255, 90)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 160)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(80, 200, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(170, 110, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 120)),
})
local spinners: { UIGradient } = {} -- turned every frame while the screen is open (one full turn per 5 s)
local function energyRim(g: GuiObject, thickness: number?, seq: ColorSequence?): UIStroke
	local s = g:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Thickness = thickness or s.Thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = g
	local gr = s:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gr.Color = seq or ENERGY
	gr.Parent = s
	table.insert(spinners, gr)
	return s
end
-- deep-space glass: a violet-to-black fill with a sprinkle of tiny stars inside
local starRng = Random.new(77)
local function glass(g: GuiObject, top: Color3?, bottom: Color3?, stars: number?)
	g.BackgroundColor3 = Color3.new(1, 1, 1)
	local gr = g:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gr.Color = ColorSequence.new(top or Color3.fromRGB(40, 26, 92), bottom or Color3.fromRGB(10, 8, 30))
	gr.Rotation = 90
	gr.Parent = g
	g.BackgroundTransparency = 0.06
	for _ = 1, stars or 8 do
		local d = Instance.new("Frame")
		d.Name = "Star"
		d.BorderSizePixel = 0
		d.BackgroundColor3 = Color3.new(1, 1, 1)
		local sz = starRng:NextInteger(2, 3)
		d.Size = UDim2.fromOffset(sz, sz)
		d.Position = UDim2.fromScale(starRng:NextNumber(0.04, 0.96), starRng:NextNumber(0.06, 0.94))
		d.BackgroundTransparency = starRng:NextNumber(0.35, 0.75)
		UI.corner(d, 2)
		d.Parent = g
		TweenService:Create(d, TweenInfo.new(starRng:NextNumber(0.9, 1.8), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, starRng:NextNumber(0, 1.5)), { BackgroundTransparency = 0.95 }):Play()
	end
end
-- GARDENERS' GUILD look
local GUILD = Skin.has("ui_cork")
local WOOD_INK = Color3.fromRGB(58, 32, 14)
local TAB_OFF = if GUILD then Color3.fromRGB(150, 96, 50) else Color3.fromRGB(110, 70, 190)
-- turn a drawn glass panel into a cork notice board in a wooden frame (keeps its size and children)
local function corkBoard(g: GuiObject, w: number, h: number, rim: number?)
	if not GUILD then
		return
	end
	g.BackgroundTransparency = 1
	local st = g:FindFirstChildOfClass("UIStroke")
	if st then
		st.Enabled = false
	end
	local gr = g:FindFirstChildOfClass("UIGradient")
	if gr then
		gr.Enabled = false
	end
	for _, k in g:GetChildren() do
		if k.Name == "Star" then
			k:Destroy()
		end
	end
	local art = Skin.frame(g, "ui_cork", Vector2.new(w, h), { name = "Cork", maxScale = rim or 0.24 })
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = 0
end
-- the HUD's wooden plate under a small box (the gem counter)
local function plateBox(g: GuiObject, w: number, h: number)
	if not GUILD or not Skin.has("ui_plate") then
		return
	end
	corkBoard(g, w, h) -- (clears the glass)
	local cork = g:FindFirstChild("Cork")
	if cork then
		cork:Destroy()
	end
	local art = Skin.frame(g, "ui_plate", Vector2.new(w, h), { name = "Plate" })
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = 0
end

-- TRADING CARDS (22 Oct 2026, the owner's pick): every class is a collectible card. The frame's material shows the
-- rarity (honey wood, leafy green, blue enamel, amethyst, gold, ruby roses, black obsidian with a rainbow edge), the
-- picture fills the card inside a slim frame (after the owner's note that the first version hid it), the name rides
-- a ribbon in the rarity colour across the top, the odds sit on a seal at the lower right and the price hangs off the
-- bottom on a pill. Sold-out cards are greyed, not blacked out. Face down a card shows the guild's green back.
-- Epic and rarer cards catch a foil glint every few seconds. Without the pictures the drawn cards stay.
local CARD_KEY = { Common = "card_common", Uncommon = "card_uncommon", Rare = "card_rare", Epic = "card_epic", Legendary = "card_legendary", Mythic = "card_mythic", Secret = "card_secret" }
local TRADING = Skin.has("card_common") and Skin.has("card_ribbon")
local function ribbonTint(rarity: string): Color3
	if rarity == "Common" then
		return Color3.fromRGB(236, 226, 206)
	elseif rarity == "Secret" then
		return Color3.fromRGB(74, 70, 96)
	end
	return Config.RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
end
-- the rarity's frame behind everything else in `g`; returns it and the insets of its cream inside (l, t, r, b)
local function cardFrame(g: GuiObject, rarity: string, w: number, h: number, maxScale: number?): (GuiObject, { number })
	local art, face = Skin.frame(g, CARD_KEY[rarity] or "card_common", Vector2.new(w, h), { name = "CardFrame", maxScale = maxScale })
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = 0
	local l, t = face.Position.X.Offset, face.Position.Y.Offset
	return art, { l, t, -face.Size.X.Offset - l, -face.Size.Y.Offset - t }
end
-- a name ribbon in the rarity's colour, centred on `pos`
local function nameRibbon(parent: Instance, text: string, rarity: string, w: number, h: number, pos: UDim2, stroke: number?): (GuiObject, TextLabel)
	local r, face = Skin.frame(parent, "card_ribbon", Vector2.new(w, h), { name = "Ribbon", pos = pos, anchor = Vector2.new(0.5, 0.5), tint = ribbonTint(rarity) })
	r.ZIndex = 3
	local t = UI.text(face, text, UDim2.fromScale(1, 1), { stroke = stroke or 1.5, name = "Name" })
	return r, t
end
-- each class's card picture (the trading-card pass, 23 Oct 2026): a tall one for the cards (cc_<Id>, 360 x 480) and a
-- wide one for the big card and the toast (cw_<Id>, 560 x 290), each the class's emblem on a backdrop in its
-- rarity colour; the older scene_<Id> pictures stand in while they're missing
local function cardPic(id: string): string
	return Config.ICONS["cc_" .. id] or Config.ICONS["scene_" .. id] or ""
end
local function widePic(id: string): string
	return Config.ICONS["cw_" .. id] or Config.ICONS["scene_" .. id] or ""
end
-- dress a card picture: an ink outline and a glossy highlight over its top-left corner, like light on a printed card
local function dressPicture(art: GuiObject, rc: Color3, radius: number)
	local corner = art:FindFirstChildOfClass("UICorner") or UI.corner(art, radius)
	;(corner :: UICorner).CornerRadius = UDim.new(0, radius)
	UI.stroke(art, if radius > 8 then 3 else 2, Color3.fromRGB(58, 32, 14))
	local _ = rc -- (the card pictures carry their own rarity backdrop and shading)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BorderSizePixel = 0
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.Size = UDim2.fromScale(1, 1)
	UI.corner(gloss, radius)
	local gg = Instance.new("UIGradient")
	gg.Rotation = 40
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(0.3, 0.84), NumberSequenceKeypoint.new(0.31, 1), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = gloss
	gloss.Parent = art
end
-- a foil glint that sweeps across `g` every few seconds
local function foil(g: GuiObject, radius: number)
	local f = Instance.new("Frame")
	f.Name = "Foil"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 6
	UI.corner(f, radius)
	local gr = Instance.new("UIGradient")
	gr.Rotation = 30
	gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) })
	gr.Offset = Vector2.new(-1, 0)
	gr.Parent = f
	f.Parent = g
	TweenService:Create(gr, TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 2.6 + math.random() * 1.5), { Offset = Vector2.new(1, 0) }):Play()
end

-- each class's picture: its card art (Config.ICONS class_<Id>, a fist gripping the class's tool)
local CLASS_ART = setmetatable({}, { __index = function(_, id)
	return "class_" .. id
end }) :: { [string]: string }
local QUOTES = {
	WeedPuller = "Bare hands, a sunhat and a whole lawn to get through.",
	Gardener = "Snip, snip - the hedges never stood a chance.",
	Groundskeeper = "Every blade in its place, every bag a bit fuller.",
	LawnBaron = "Grass is money, and the Baron sells it dear.",
	HedgeReaper = "It finds the shiny clumps first.",
	MowerSpecialist = "Loud, fast, and through the grass before it knows.",
	GrassTitan = "One swing, a whole field lies down.",
	UltimateGardener = "Fast hands, fat bags, rich pockets.",
	LawnLegend = "They say the lawn grows back out of fear.",
	GoatMan = "Nobody mows like the Goat. Nobody.",
}

local holder = Instance.new("Frame")
holder.Name = "ClassDeal"
holder.BackgroundTransparency = 1
holder.Size = UDim2.fromOffset(1280, 720)
holder.Position = UDim2.fromScale(0.5, 0.5)
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Visible = false
holder.ZIndex = 10
holder.Parent = UI.gui
-- the class screen is a full-screen scene: it keeps filling the screen even though the rest of the UI is drawn a bit
-- smaller (Config.UI_SIZE scales the whole MowALawnGui)
do
	local fill = Instance.new("UIScale")
	fill.Name = "Fill"
	fill.Scale = 1 / (UI.size or Config.UI_SIZE or 1)
	fill.Parent = holder
end

-- soft dark edges so the panels read over the room (they reach past the 1280 x 720 box on wide screens)
for _, side in { { 0, 0 }, { 1, 180 } } do
	local v = UI.frame({ size = UDim2.new(0, 900, 2, 0), pos = UDim2.new(side[1], if side[1] == 0 then -480 else 480, 0.5, 0), anchor = Vector2.new(side[1], 0.5), color = if GUILD then Color3.fromRGB(14, 9, 3) else Color3.fromRGB(4, 2, 14), parent = holder, radius = 0, outline = 0, name = "Shade" })
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.55, 0.5), NumberSequenceKeypoint.new(1, 1) })
	g.Rotation = side[2]
	g.Parent = v
end
local floorShade = UI.frame({ size = UDim2.new(3, 0, 0, 300), pos = UDim2.new(0.5, 0, 1, 40), anchor = Vector2.new(0.5, 1), color = if GUILD then Color3.fromRGB(16, 10, 4) else Color3.fromRGB(8, 4, 18), parent = holder, radius = 0, outline = 0, name = "FloorShade" })
local fg = Instance.new("UIGradient")
fg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
fg.Rotation = 90
fg.Parent = floorShade

-- Chop A Forest's class screen is drawn smaller than our other windows: each block keeps its layout and is scaled
-- down round its anchor to that screen's size and spot.
local function shrink(g: GuiObject, s: number): GuiObject
	UI.scaleBase(g, s) -- through UI's juice, so the hover grow / click squash / breath scale round this size
	return g
end

-- Chop A Forest's open, measured off a 120 fps capture: every block slides in from its own edge with a Back
-- overshoot (~10% past, then settles) - top drops 140 px, left comes 310 px, right 330 px, bottom rises 190 px,
-- starting 0 / 0.03 / 0.08 / 0.11 s in, ~0.5 s each. Nothing pops or squashes.
local OPEN = {
	top = { dx = 0, dy = -140, delay = 0, time = 0.52 },
	left = { dx = -310, dy = 0, delay = 0.03, time = 0.5 },
	right = { dx = 330, dy = 0, delay = 0.08, time = 0.48 },
	bottom = { dx = 0, dy = 190, delay = 0.11, time = 0.55 },
}
local slideIns: { { obj: GuiObject, home: UDim2, side: string } } = {}
local slideDone = 0 -- os.clock() when the last slide lands (the big card's float waits for it)
local function slideFrom(obj: GuiObject, side: string)
	table.insert(slideIns, { obj = obj, home = obj.Position, side = side })
end
local function playSlideIns()
	for _, s in slideIns do
		local o = OPEN[s.side]
		s.obj.Position = s.home + UDim2.fromOffset(o.dx, o.dy)
		TweenService:Create(s.obj, TweenInfo.new(o.time, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, o.delay), { Position = s.home }):Play()
	end
	slideDone = os.clock() + 0.7
end

-- Roblox's own Robux icon: the private-use glyph U+E002 that Roblox's fonts draw as the current Robux mark
local function robuxGlyph(parent: Instance, size: number, pos: UDim2, anchor: Vector2?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Robux"
	t.BackgroundTransparency = 1
	t.Text = utf8.char(0xE002)
	t.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Size = UDim2.fromOffset(size, size)
	t.Position = pos
	t.AnchorPoint = anchor or Vector2.zero
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(20, 30, 60)
	s.Transparency = 0.2
	s.Parent = t
	t.Parent = parent
	return t
end

-- twinkling sparkles round the screen
local function twinkle(parent: Instance, pos: UDim2, size: number, color: Color3)
	local s = Instance.new("ImageLabel")
	s.Name = "Twinkle"
	s.BackgroundTransparency = 1
	s.Image = Tex.Star4
	s.ImageColor3 = color
	s.Size = UDim2.fromOffset(size, size)
	s.Position = pos
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.ZIndex = 5
	s.Parent = parent
	local t = TweenService:Create(s, TweenInfo.new(0.9 + math.random() * 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.85, Size = UDim2.fromOffset(size * 0.5, size * 0.5), Rotation = 45 })
	t:Play()
	return s
end

-- the title: CL + a gold star + SSES
local titleBox = Instance.new("Frame")
titleBox.BackgroundTransparency = 1
titleBox.Size = UDim2.fromOffset(420, 80)
titleBox.Position = UDim2.fromOffset(610, 64)
titleBox.AnchorPoint = Vector2.new(0.5, 0)
titleBox.Parent = holder
shrink(titleBox, 0.62)
for _, t in {
	-- (a clear gap either side of the crest in the middle: it used to sit on the L and the first S)
	UI.text(titleBox, "CL", UDim2.fromOffset(170, 80), { pos = UDim2.fromOffset(-10, 0), align = Enum.TextXAlignment.Right, stroke = 5 }),
	UI.text(titleBox, "SSES", UDim2.fromOffset(190, 80), { pos = UDim2.fromOffset(260, 0), align = Enum.TextXAlignment.Left, stroke = 5 }),
} do
	local g = Instance.new("UIGradient") -- starlight: white fading to a pale cosmic blue (guild: cream to gold)
	g.Color = if GUILD then ColorSequence.new(Color3.fromRGB(255, 250, 230), Color3.fromRGB(255, 205, 90)) else ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 205, 255))
	g.Rotation = 90
	g.Parent = t
	local st = t:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = if GUILD then WOOD_INK else Color3.fromRGB(16, 10, 44)
	end
end
-- the A: a glowing gold four-point sparkle
local titleGlow = Instance.new("ImageLabel")
titleGlow.BackgroundTransparency = 1
titleGlow.Image = Tex.Glow
titleGlow.ImageColor3 = Color3.fromRGB(255, 200, 80)
titleGlow.ImageTransparency = 0.25
titleGlow.Size = UDim2.fromOffset(110, 110)
titleGlow.Position = UDim2.fromOffset(210, 42)
titleGlow.AnchorPoint = Vector2.new(0.5, 0.5)
titleGlow.Parent = titleBox
local titleStar = Instance.new("ImageLabel")
titleStar.BackgroundTransparency = 1
titleStar.Image = "rbxassetid://104095913007401" -- chunky gold sparkle, Store Icons/ClassArt/UISpark.png
titleStar.Size = UDim2.fromOffset(64, 64)
titleStar.Position = UDim2.fromOffset(210, 42)
titleStar.AnchorPoint = Vector2.new(0.5, 0.5)
titleStar.Parent = titleBox
if GUILD and Skin.has("guild_crest") then
	-- the A is the guild's crest
	titleStar.Image = Config.ICONS.guild_crest
	titleStar.ScaleType = Enum.ScaleType.Fit
	titleStar.Size = UDim2.fromOffset(84, 76)
	titleGlow.ImageColor3 = Color3.fromRGB(255, 230, 150)
end
-- (the star holds still - in Chop A Forest only the timer's moon moves up here)

-- NEW CARDS IN (rocket crest, label, big time, gradient bar) - same layout as the Chop A Forest pill, rocket instead of the moon
local TIMER_INK = if GUILD then Color3.fromRGB(16, 26, 20) else Color3.fromRGB(16, 9, 34)
local timerPill = UI.frame({ size = UDim2.fromOffset(280, 66), pos = UDim2.fromOffset(621, 112), anchor = Vector2.new(1, 0), color = Color3.fromRGB(70, 44, 124), parent = holder, radius = 16, outline = 4, name = "Timer" })
do
	local st = timerPill:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = TIMER_INK
		st.Thickness = 4
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 175))
	g.Rotation = 90
	g.Parent = timerPill
	-- a soft top highlight, like the reference's lighter upper half
	local hi = Instance.new("Frame")
	hi.Name = "Highlight"
	hi.BorderSizePixel = 0
	hi.BackgroundColor3 = Color3.new(1, 1, 1)
	hi.BackgroundTransparency = 0.9
	hi.Size = UDim2.new(1, -12, 0.42, 0)
	hi.Position = UDim2.fromOffset(6, 4)
	hi.Parent = timerPill
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 11)
	hc.Parent = hi
end
local timerMoon = Instance.new("ImageLabel") -- (kept the name: the rocket crest)
timerMoon.Name = "RocketCrest"
timerMoon.BackgroundTransparency = 1
timerMoon.Image = "rbxassetid://102986510663506"
timerMoon.ScaleType = Enum.ScaleType.Fit
timerMoon.Size = UDim2.fromOffset(104, 104)
timerMoon.Position = UDim2.fromOffset(-56, -22)
timerMoon.ZIndex = 5
timerMoon.Parent = timerPill
UI.breathe(timerMoon, 0.03, 2 * math.pi / 1.05) -- the crest pulses +-3% about once a second
local timerLabel = UI.text(timerPill, if GUILD then "FRESH STOCK IN" else "NEW CARDS IN", UDim2.fromOffset(130, 22), { pos = UDim2.fromOffset(52, 9), align = Enum.TextXAlignment.Left, stroke = 2 })
local timerText = UI.text(timerPill, "5:00", UDim2.fromOffset(96, 36), { pos = UDim2.new(1, -12, 0, 2), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, stroke = 3 })
for _, t in { timerLabel, timerText } do
	local s = t:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = TIMER_INK
	end
end
local timerTrack = UI.frame({ size = UDim2.new(1, -64, 0, 14), pos = UDim2.fromOffset(50, 41), color = Color3.fromRGB(24, 14, 48), parent = timerPill, radius = 7, outline = 2 })
do
	local st = timerTrack:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = TIMER_INK
		st.Thickness = 2
	end
end
local timerFill = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.new(1, 1, 1), parent = timerTrack, radius = 7, outline = 0 })
do
	local g = Instance.new("UIGradient") -- purple to pink, left to right (guild: fresh green to gold)
	g.Color = if GUILD then ColorSequence.new(Color3.fromRGB(110, 210, 70), Color3.fromRGB(255, 210, 70)) else ColorSequence.new(Color3.fromRGB(140, 80, 255), Color3.fromRGB(255, 105, 215))
	g.Parent = timerFill
	local shine = Instance.new("Frame") -- glossy strip along the top of the fill
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.6
	shine.Size = UDim2.new(1, -8, 0, 3)
	shine.Position = UDim2.fromOffset(4, 2)
	shine.Parent = timerFill
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = shine
end
if GUILD and Skin.has("ui_chalk") then
	-- a little chalkboard: the wood-framed slate behind, chalk-white writing, a basket of fresh stock as the crest
	timerPill.BackgroundTransparency = 1
	;(timerPill:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
	;(timerPill:FindFirstChildOfClass("UIGradient") :: UIGradient).Enabled = false
	local hi = timerPill:FindFirstChild("Highlight")
	if hi then
		(hi :: GuiObject).Visible = false
	end
	local slate = Skin.frame(timerPill, "ui_chalk", Vector2.new(280, 66), { name = "Chalk", maxScale = 0.12 })
	slate.Size = UDim2.new(1, 16, 1, 16)
	slate.Position = UDim2.fromOffset(-8, -8)
	slate.ZIndex = 0
	if (Config.ICONS.basket or "") ~= "" then
		timerMoon.Image = Config.ICONS.basket
		timerMoon.Size = UDim2.fromOffset(90, 90)
		timerMoon.Position = UDim2.fromOffset(-50, -14)
	end
	timerLabel.TextColor3 = Color3.fromRGB(236, 240, 226)
	timerText.TextColor3 = Color3.fromRGB(255, 244, 200)
	timerTrack.BackgroundColor3 = Color3.fromRGB(20, 32, 26)
end
shrink(timerPill, 0.66)

-- gems, with a + that opens the shop
local gemBox = UI.frame({ size = UDim2.fromOffset(240, 66), pos = UDim2.fromOffset(638, 112), color = NAVY, parent = holder, radius = 16, outline = 4, name = "Gems" })
glass(gemBox, nil, nil, 5)
energyRim(gemBox, 3)
plateBox(gemBox, 240, 66)
shrink(gemBox, 0.66)
UI.icon(gemBox, "gem", 62, UDim2.fromOffset(-6, 2)).ZIndex = 3
local gemText = UI.text(gemBox, "0", UDim2.fromOffset(110, 34), { pos = UDim2.fromOffset(64, 6), align = Enum.TextXAlignment.Left, stroke = 2.5 })
UI.text(gemBox, "gems", UDim2.fromOffset(60, 18), { pos = UDim2.fromOffset(64, 40), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(190, 180, 220), stroke = 1 })
local plus = UI.button(gemBox, "+", C.green, UDim2.fromOffset(48, 48), function()
	UI.open("Store")
end, { pos = UDim2.new(1, -10, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "More" })
plus.ZIndex = 4
local closeBtn = shrink(UI.closeButton(holder, UDim2.fromOffset(156, 70), function()
	UI.close()
end), 0.6)
slideFrom(titleBox, "top")
slideFrom(timerPill, "top")
slideFrom(gemBox, "top")
slideFrom(closeBtn, "top")

-- VS YOUR CLASS
local vs = UI.frame({ size = UDim2.fromOffset(360, 272), pos = UDim2.fromOffset(118, 124), color = Color3.new(1, 1, 1), parent = holder, radius = 18, outline = 4, name = "VsCard" })
glass(vs, Color3.fromRGB(46, 28, 104), Color3.fromRGB(12, 8, 34), 14)
energyRim(vs, 4)
corkBoard(vs, 360, 272, 0.2)
if GUILD then
	Skin.pushpin(vs, UDim2.new(1, -24, 0, 16), 30) -- (in the corner, clear of the title)
end
shrink(vs, 0.667)
slideFrom(vs, "left")
local vsTitle = UI.text(vs, "VS YOUR CLASS", UDim2.fromOffset(240, 28), { pos = UDim2.fromOffset(16, 10), align = Enum.TextXAlignment.Left, color = GOLD, stroke = 2 })
local vsNames = UI.text(vs, "", UDim2.new(1, -32, 0, 18), { pos = UDim2.fromOffset(16, 38), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(190, 180, 220), stroke = 1 })
local vsRows = Instance.new("Frame")
vsRows.BackgroundTransparency = 1
vsRows.Size = UDim2.new(1, -28, 0, 172) -- up to five rows, like Chop A Forest's
vsRows.Position = UDim2.fromOffset(14, 62)
vsRows.Parent = vs
local vsLayout = Instance.new("UIListLayout")
vsLayout.Padding = UDim.new(0, 4)
vsLayout.SortOrder = Enum.SortOrder.LayoutOrder
vsLayout.Parent = vsRows
local vsQuote = UI.text(vs, "", UDim2.new(1, -32, 0, 30), { pos = UDim2.fromOffset(16, 236), align = Enum.TextXAlignment.Left, stroke = 1.5, textSize = 14 })
vsQuote.Font = Enum.Font.FredokaOne
if GUILD and Skin.has("ui_cork") then
	-- everything inside the cork, clear of the wooden rim (it overlapped the rim before)
	vsTitle.Position = UDim2.fromOffset(28, 24)
	vsTitle.Size = UDim2.fromOffset(220, 26)
	vsNames.Position = UDim2.fromOffset(28, 50)
	vsNames.Size = UDim2.new(1, -56, 0, 16)
	vsRows.Position = UDim2.fromOffset(26, 72)
	vsRows.Size = UDim2.new(1, -52, 0, 150)
	vsLayout.Padding = UDim.new(0, 2)
	vsQuote.Position = UDim2.fromOffset(28, 226)
	vsQuote.Size = UDim2.new(1, -56, 0, 24)
	vsQuote.TextSize = 12
end

-- RESTOCK / LUCKY RESTOCK: a big glossy button with an icon, a title, a line and a dark Robux chip
local function restockButton(y: number, color: Color3, title: string, line: string, productKey: string, lucky: boolean): TextButton
	local p = Config.PRODUCTS[productKey]
	local b = UI.button(holder, "", color, UDim2.fromOffset(360, 52), function()
		State.fire("Prompt", "product", productKey)
	end, { pos = UDim2.fromOffset(118, y), name = productKey })
	local z = b.ZIndex + 1
	if lucky then
		UI.icon(b, "clover", 40, UDim2.fromOffset(12, 4)).ZIndex = z
	else
		local ring = UI.frame({ size = UDim2.fromOffset(30, 30), pos = UDim2.fromOffset(16, 9), color = Color3.new(1, 1, 1), parent = b, radius = 999, outline = 5, name = "Ring" })
		ring.BackgroundTransparency = 1
		ring.ZIndex = z
		local s = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		s.Color = Color3.new(1, 1, 1)
		local head = UI.frame({ size = UDim2.fromOffset(11, 11), pos = UDim2.fromOffset(26, 3), color = Color3.new(1, 1, 1), parent = b, radius = 2, outline = 0, name = "Arrow" })
		head.Rotation = 45
		head.ZIndex = z
	end
	UI.text(b, title, UDim2.fromOffset(if lucky then 132 else 190, 26), { pos = UDim2.fromOffset(60, 3), align = Enum.TextXAlignment.Left, stroke = 3 }).ZIndex = z
	UI.text(b, line, UDim2.fromOffset(200, 15), { pos = UDim2.fromOffset(60, 30), align = Enum.TextXAlignment.Left, stroke = 1.5 }).ZIndex = z
	if lucky then
		local tagBox = UI.frame({ size = UDim2.fromOffset(58, 22), pos = UDim2.fromOffset(194, 6), color = Color3.new(1, 1, 1), parent = b, radius = 13, outline = 2, name = "Luck" })
		tagBox.Rotation = -6
		tagBox.ZIndex = z
		local t = UI.text(tagBox, "x3 LUCK", UDim2.new(1, -6, 1, -4), { pos = UDim2.fromOffset(3, 2), color = Color3.fromRGB(40, 120, 40), stroke = 0 })
		t.ZIndex = z + 1
	end
	local chip = UI.frame({ size = UDim2.fromOffset(74, 38), pos = UDim2.new(1, -8, 0.5, -3), anchor = Vector2.new(1, 0.5), color = UI.shade(color, 0.45), parent = b, radius = 12, outline = 2, name = "Price" })
	chip.ZIndex = z
	robuxGlyph(chip, 24, UDim2.fromOffset(8, 7)).ZIndex = z + 1
	UI.text(chip, tostring(if p then p.robux else 0), UDim2.new(1, -38, 1, -10), { pos = UDim2.fromOffset(34, 5), stroke = 2 }).ZIndex = z + 1
	shrink(b, 0.667)
	return b
end
local restocks = {
	restockButton(312, Color3.fromRGB(50, 140, 245), "RESTOCK", "Deal new cards now", "ClassRestock", false),
	restockButton(354, Color3.fromRGB(70, 190, 80), "LUCKY RESTOCK", "Rare cards 3x more likely", "ClassLuckyRestock", true),
}
for _, b in restocks do
	slideFrom(b, "left")
	-- a restock deals random cards for Robux: hidden until Roblox's policy says paid random items are allowed here
	b.Visible = false
end
task.spawn(function()
	if Policy.paidRandomOk() then
		for _, b in restocks do
			b.Visible = true
		end
	end
end)

-- the picked class's big card (right)
local cardGlow = Instance.new("ImageLabel")
cardGlow.Name = "CardGlow"
cardGlow.BackgroundTransparency = 1
cardGlow.Image = Tex.Glow
cardGlow.ImageTransparency = 0.15
cardGlow.Size = UDim2.fromOffset(494, 646)
cardGlow.Position = UDim2.fromOffset(992, 282)
cardGlow.AnchorPoint = Vector2.new(0.5, 0.5)
cardGlow.Parent = holder
TweenService:Create(cardGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.45, Size = UDim2.fromOffset(456, 608) }):Play()
local detail = UI.frame({ size = UDim2.fromOffset(310, 460), pos = UDim2.fromOffset(1139, 64), anchor = Vector2.new(1, 0), color = W.blue, parent = holder, radius = 20, outline = 6, name = "Detail" })
local detailStroke = detail:FindFirstChildOfClass("UIStroke") :: UIStroke
local detailGrad = UI.gradient(detail, W.blue)
shrink(detail, 0.95)
-- the rarity rim turns (Legendary gold shimmer, Mythic / Secret rainbow); refresh switches it on per card
local detailRimGrad = Instance.new("UIGradient")
detailRimGrad.Enabled = false
detailRimGrad.Parent = detailStroke
table.insert(spinners, detailRimGrad)
-- a shine sweeps across the card every 3 s (0.8 s Linear, then rests)
local cardShine = Instance.new("Frame")
cardShine.Name = "Shine"
cardShine.BorderSizePixel = 0
cardShine.BackgroundColor3 = Color3.new(1, 1, 1)
cardShine.Size = UDim2.fromScale(1, 1)
cardShine.ZIndex = 20
UI.corner(cardShine, 20)
cardShine.Parent = detail
local shineGrad = Instance.new("UIGradient")
shineGrad.Rotation = 25
shineGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.72), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) })
shineGrad.Offset = Vector2.new(-1, 0)
shineGrad.Parent = cardShine
task.spawn(function()
	while true do
		shineGrad.Offset = Vector2.new(-1, 0)
		if holder.Visible then
			TweenService:Create(shineGrad, TweenInfo.new(0.8, Enum.EasingStyle.Linear), { Offset = Vector2.new(1, 0) }):Play()
		end
		task.wait(3)
	end
end)
local parch: ImageLabel? = nil
local seal: GuiObject? = nil
if GUILD and Skin.has("ui_parch") and not TRADING then
	-- a pinned parchment notice; the rarity shows in its header band, a faint tint and the wax seal
	detail.BackgroundTransparency = 1
	detailGrad.Enabled = false
	detailStroke.Transparency = 1
	local art = Skin.frame(detail, "ui_parch", Vector2.new(310, 460), { name = "Parchment", maxScale = 0.3 })
	art.Size = UDim2.new(1, 12, 1, 12)
	art.Position = UDim2.fromOffset(-6, -6)
	art.ZIndex = 0
	parch = art :: ImageLabel
	Skin.pushpin(detail, UDim2.new(0.5, 0, 0, 2), 34)
	if Skin.has("wax_seal") then
		local w = UI.icon(detail, "wax_seal", 70, UDim2.new(1, 14, 0, 196), Vector2.new(1, 0.5))
		w.Rotation = 14
		w.ZIndex = 22
		seal = w
	end
end
-- the big trading card: the picked class's rarity frame (rebuilt by refresh when the rarity changes)
local detailFrame: GuiObject? = nil
local detailRarity = ""
if TRADING then
	detail.BackgroundTransparency = 1
	detailGrad.Enabled = false
	detailStroke.Transparency = 1
end
slideFrom(detail, "right")
slideFrom(cardGlow, "right")
-- hazard stripes along the top and the bottom (Epic and rarer)
local stripes: { Frame } = {}
for _, y in { 8, 448 } do
	local band = UI.frame({ size = UDim2.new(1, -24, 0, if y > 100 then 8 else 14), pos = UDim2.fromOffset(12, y), color = Color3.fromRGB(30, 26, 34), parent = detail, radius = 4, outline = 0, name = "Stripes" })
	band.ClipsDescendants = true
	for i = 0, 15 do
		local s = UI.frame({ size = UDim2.fromOffset(9, 40), pos = UDim2.fromOffset(i * 19 - 6, -12), color = Color3.fromRGB(255, 205, 40), parent = band, radius = 0, outline = 0 })
		s.Rotation = 35
	end
	table.insert(stripes, band)
end
local header = UI.frame({ size = UDim2.new(1, -36, 0, 74), pos = UDim2.fromOffset(18, 26), color = Color3.new(1, 1, 1), parent = detail, radius = 12, outline = 0, name = "Header" })
header.BackgroundTransparency = if parch then 0.05 else 0.82
local detName = UI.text(header, "", UDim2.new(1, -16, 0, 40), { pos = UDim2.fromOffset(8, 2), stroke = 3.5 })
-- (trading card: the name rides a ribbon across the top of the card, wider than the card)
local detRibbon: GuiObject? = nil
if TRADING then
	header.BackgroundTransparency = 1
	local r = Skin.frame(header, "card_ribbon", Vector2.new(304, 64), { name = "Ribbon", pos = UDim2.new(0.5, 0, 0, 22), anchor = Vector2.new(0.5, 0.5) })
	r.ZIndex = 0
	detRibbon = r
	detName.Size = UDim2.new(1, -44, 0, 30)
	detName.Position = UDim2.fromOffset(22, 3)
end
local starRow = Instance.new("Frame")
starRow.BackgroundTransparency = 1
starRow.Size = UDim2.fromOffset(196, 26)
starRow.Position = UDim2.new(0.5, 0, 0, if TRADING then 48 else 44)
starRow.AnchorPoint = Vector2.new(0.5, 0)
starRow.Parent = header
local starIcons: { ImageLabel } = {}
for i = 1, 7 do
	local s = Instance.new("ImageLabel")
	s.BackgroundTransparency = 1
	s.Image = STAR_IMG
	s.Size = UDim2.fromOffset(26, 26)
	s.Position = UDim2.fromOffset((i - 1) * 28, 0)
	s.Parent = starRow
	table.insert(starIcons, s)
end
-- the picture: a bright panel with turning rays, a glow and the class's tool
local artPanel = UI.frame({ size = UDim2.new(1, -36, 0, 100), pos = UDim2.fromOffset(18, 106), color = Color3.fromRGB(120, 180, 255), parent = detail, radius = 14, outline = 4, name = "Art" })
artPanel.ClipsDescendants = true
;(artPanel:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if GUILD then WOOD_INK else Color3.fromRGB(30, 20, 50)
local raysBox = Instance.new("Frame")
raysBox.BackgroundTransparency = 1
raysBox.Size = UDim2.fromOffset(420, 420)
raysBox.Position = UDim2.fromScale(0.5, 0.5)
raysBox.AnchorPoint = Vector2.new(0.5, 0.5)
raysBox.Parent = artPanel
for i = 0, 7 do
	local r = Instance.new("Frame")
	r.BorderSizePixel = 0
	r.BackgroundColor3 = Color3.new(1, 1, 1)
	r.BackgroundTransparency = 0.7
	r.Size = UDim2.new(0, 34, 1, 0)
	r.Position = UDim2.fromScale(0.5, 0.5)
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Rotation = i * 22.5
	r.Parent = raysBox
end
TweenService:Create(raysBox, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
local artGlow = Instance.new("ImageLabel")
artGlow.BackgroundTransparency = 1
artGlow.Image = Tex.Glow
artGlow.Size = UDim2.fromOffset(220, 220)
artGlow.Position = UDim2.fromScale(0.5, 0.5)
artGlow.AnchorPoint = Vector2.new(0.5, 0.5)
artGlow.Parent = artPanel
local artHolder = Instance.new("Frame")
artHolder.BackgroundTransparency = 1
artHolder.Size = UDim2.fromScale(1, 1)
artHolder.Parent = artPanel
twinkle(artPanel, UDim2.fromScale(0.82, 0.22), 30, Color3.new(1, 1, 1))
twinkle(artPanel, UDim2.fromScale(0.16, 0.7), 22, Color3.new(1, 1, 1))
local rarityPill = UI.frame({ size = UDim2.fromOffset(150, 30), pos = UDim2.new(0.5, 0, 0, 192), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(30, 20, 50), parent = detail, radius = 15, outline = 3, name = "Rarity" })
;(rarityPill:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.new(1, 1, 1)
local rarityText = UI.text(rarityPill, "", UDim2.new(1, -10, 1, -6), { pos = UDim2.fromOffset(5, 3), stroke = 1.5 })
local detState = UI.text(detail, "", UDim2.new(1, -24, 0, 0), { pos = UDim2.fromOffset(12, 0), stroke = 1.5 })
detState.Visible = false
local perkRows = Instance.new("Frame")
perkRows.BackgroundTransparency = 1
perkRows.Size = UDim2.new(1, -36, 0, 126)
perkRows.Position = UDim2.fromOffset(18, 224)
perkRows.Parent = detail
local perkLayout = Instance.new("UIListLayout")
perkLayout.Padding = UDim.new(0, 3)
perkLayout.SortOrder = Enum.SortOrder.LayoutOrder
perkLayout.Parent = perkRows
local detQuote = UI.text(detail, "", UDim2.new(1, -36, 0, 26), { pos = UDim2.fromOffset(18, 350), stroke = 1.5, textSize = 12 })
local detOdds = UI.text(detail, "", UDim2.new(1, -28, 0, 16), { pos = UDim2.fromOffset(14, 376), stroke = 1.5, textSize = 12 })
if TRADING then
	-- written on the card's cream: dark ink, no outline
	for _, t in { detQuote, detOdds } do
		t.TextColor3 = Color3.fromRGB(92, 58, 30)
		;(t:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
	end
	-- the picture gets half again as much room; the quote goes (the VS box shows it), the odds stay
	artPanel.Size = UDim2.new(1, -44, 0, 128)
	artPanel.Position = UDim2.fromOffset(22, 102)
	rarityPill.Position = UDim2.new(0.5, 0, 0, 216)
	perkRows.Position = UDim2.fromOffset(24, 250)
	perkRows.Size = UDim2.new(1, -48, 0, 120)
	perkLayout.Padding = UDim.new(0, 2)
	detQuote.Visible = false
	detOdds.Position = UDim2.fromOffset(24, 372)
	detOdds.Size = UDim2.new(1, -48, 0, 16)
end
local gemBtn = UI.button(detail, "BUY", C.purple, UDim2.fromOffset(134, 48), function() end, { pos = UDim2.new(0, 16, 1, -14), anchor = Vector2.new(0, 1), name = "GemBuy" })
local robuxBtn = UI.button(detail, "R$ 0", C.green, UDim2.fromOffset(134, 48), function() end, { pos = UDim2.new(1, -16, 1, -14), anchor = Vector2.new(1, 1), name = "RobuxBuy" })
if TRADING then
	-- (a touch slimmer, so the bigger picture and the stats fit above them)
	for _, btn in { gemBtn, robuxBtn } do
		btn.Size = UDim2.fromOffset(128, 44)
		btn.Position = UDim2.new(btn.Position.X.Scale, if btn.Position.X.Scale > 0 then -24 else 24, 1, -24) -- (inside the frame)
	end
end
local gemIcon = UI.icon(gemBtn, "gem", 32, UDim2.new(0, 10, 0.5, -3), Vector2.new(0, 0.5))
local robuxIcon = robuxGlyph(robuxBtn, 28, UDim2.new(0, 12, 0.5, -3), Vector2.new(0, 0.5))
robuxIcon.ZIndex = robuxBtn.ZIndex + 1
-- a green tick in a white ring for EQUIPPED
local tick = UI.frame({ size = UDim2.fromOffset(30, 30), pos = UDim2.new(0, 14, 0.5, -3), anchor = Vector2.new(0, 0.5), color = Color3.fromRGB(60, 200, 90), parent = gemBtn, radius = 999, outline = 3, name = "Tick" })
;(tick:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.new(1, 1, 1)
for _, b in { { 6, 12, 9, 4, 45 }, { 12, 6, 16, 4, -50 } } do
	local bar = UI.frame({ size = UDim2.fromOffset(b[3], b[4]), pos = UDim2.fromOffset(b[1] + 2, b[2] + 6), color = Color3.new(1, 1, 1), parent = tick, radius = 2, outline = 0 })
	bar.Rotation = b[5]
end
-- the thin white inner frame with diamond corners (Chop A Forest's card border)
local innerFrame = UI.frame({ size = UDim2.new(1, -16, 1, -16), pos = UDim2.fromOffset(8, 8), color = Color3.new(1, 1, 1), parent = detail, radius = 14, outline = 2, name = "Inner" })
innerFrame.BackgroundTransparency = 1
innerFrame.Visible = parch == nil and not TRADING -- (the parchment and the trading card have their own edges)
;(innerFrame:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(255, 245, 230)
;(innerFrame:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0.3
for _, p in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
	local dia = UI.frame({ size = UDim2.fromOffset(13, 13), pos = UDim2.fromScale(p[1], p[2]), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(255, 226, 160), parent = innerFrame, radius = 2, outline = 2 })
	dia.Rotation = 45
end

-- STOCK / OWNED tabs and the card carousel
local tab = "stock"
local stockTab = UI.button(holder, "STOCK", C.orange, UDim2.fromOffset(140, 46), function() end, { pos = UDim2.fromOffset(133, 454), name = "StockTab" })
local ownedTab = UI.button(holder, "OWNED", TAB_OFF, UDim2.fromOffset(180, 46), function() end, { pos = UDim2.fromOffset(231, 454), name = "OwnedTab" })
shrink(stockTab, 0.667)
shrink(ownedTab, 0.667)
slideFrom(stockTab, "bottom")
slideFrom(ownedTab, "bottom")
UI.icon(stockTab, if GUILD and (Config.ICONS.basket or "") ~= "" then "basket" else "moon", 38, UDim2.new(0, 2, 0.5, -3), Vector2.new(0, 0.5))
;(stockTab:FindFirstChild("Label") :: TextLabel).Position = UDim2.fromOffset(22, 3)
local ownedTick = UI.frame({ size = UDim2.fromOffset(28, 28), pos = UDim2.new(0, 8, 0.5, -3), anchor = Vector2.new(0, 0.5), color = Color3.fromRGB(60, 200, 90), parent = ownedTab, radius = 999, outline = 2, name = "Tick" })
;(ownedTick:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.new(1, 1, 1)
for _, b in { { 5, 11, 8, 4, 45 }, { 10, 6, 14, 4, -50 } } do
	local bar = UI.frame({ size = UDim2.fromOffset(b[3], b[4]), pos = UDim2.fromOffset(b[1] + 2, b[2] + 5), color = Color3.new(1, 1, 1), parent = ownedTick, radius = 2, outline = 0 })
	bar.Rotation = b[5]
end
local ownedChip = UI.frame({ size = UDim2.fromOffset(30, 28), pos = UDim2.new(1, -8, 0.5, -3), anchor = Vector2.new(1, 0.5), color = if GUILD then Color3.fromRGB(70, 42, 20) else Color3.fromRGB(30, 20, 50), parent = ownedTab, radius = 8, outline = 0, name = "Count" })
local ownedCount = UI.text(ownedChip, "1", UDim2.new(1, -6, 1, -6), { pos = UDim2.fromOffset(3, 3), stroke = 1.5 })
local row = Instance.new("ScrollingFrame")
row.Name = "Cards"
row.BackgroundTransparency = 1
row.BorderSizePixel = 0
row.Size = UDim2.fromOffset(1220, 170)
row.AnchorPoint = Vector2.new(0.5, 0)
row.Position = UDim2.fromOffset(636, 503)
shrink(row, 0.9)
row.ScrollBarThickness = 6
row.ScrollingDirection = Enum.ScrollingDirection.X
row.AutomaticCanvasSize = Enum.AutomaticSize.X
row.CanvasSize = UDim2.new()
row.ClipsDescendants = false
row.Parent = holder
slideFrom(row, "bottom")
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 2)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
rowLayout.Parent = row

-------------------------------------------------------------------------------------------------------------
-- state + refresh
-------------------------------------------------------------------------------------------------------------
local selected: string? = nil
local lastDealKey: string? = nil
local lastOwned: { [string]: boolean }? = nil
local cardsByClass: { [string]: GuiObject } = {}

-- A tall card in the carousel: rarity-coloured, the class's picture on a light panel, its name, and a pill with the
-- price (gems), EQUIPPED (gold), YOURS or SOLD OUT; its chance to be dealt in the corner; the picked one glows.
local function card(c, order: number, d, stock: { string }): GuiObject
	local owned = table.find(d.classes, c.id) ~= nil
	local inStock = table.find(stock, c.id) ~= nil
	local rc = if c.rarity == "Secret" then Color3.fromRGB(150, 80, 220) else Config.RARITY_COLORS[c.rarity]
	local picked = c.id == selected
	local slot = Instance.new("Frame")
	slot.Name = "Slot_" .. c.id
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(112, 162)
	slot.LayoutOrder = order
	slot.Parent = row
	-- Epic and rarer cards in the deal shine: slow gold rays turning behind them (Chop A Forest's rare-card shine)
	if inStock and not owned and SHINE[c.rarity] then
		local rays = Instance.new("Frame")
		rays.Name = "Shine"
		rays.BackgroundTransparency = 1
		rays.Size = UDim2.fromOffset(170, 170)
		rays.Position = UDim2.fromOffset(56, if picked then 70 else 86)
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Parent = slot
		for i = 0, 5 do
			local r = Instance.new("Frame")
			r.BorderSizePixel = 0
			r.BackgroundColor3 = Color3.fromRGB(255, 214, 90)
			r.Size = UDim2.new(0, 22, 1, 0)
			r.Position = UDim2.fromScale(0.5, 0.5)
			r.AnchorPoint = Vector2.new(0.5, 0.5)
			r.Rotation = i * 30
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) })
			g.Rotation = 90
			g.Parent = r
			r.Parent = rays
		end
		TweenService:Create(rays, TweenInfo.new(360 / 28, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
	end
	if picked then
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.Image = Tex.Glow
		glow.ImageColor3 = rc
		glow.ImageTransparency = 0.2
		glow.Size = UDim2.fromOffset(200, 240)
		glow.Position = UDim2.fromOffset(56, 70)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Parent = slot
	end
	local b = Instance.new("TextButton")
	b.Name = "Card"
	b.Text = ""
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0.5, 0)
	-- room above for the chance chip; the picked card sits 16 px higher than the rest (Chop A Forest's)
	local baseY = if picked then 0 else 16
	b:SetAttribute("BaseY", baseY)
	b.Position = UDim2.fromOffset(56, baseY)
	b.Size = UDim2.fromOffset(104, 140)
	b.BackgroundColor3 = rc
	b.ClipsDescendants = false
	UI.corner(b, 14)
	local rim = UI.stroke(b, if picked then 4 else 3, if picked then Color3.new(1, 1, 1) else UI.shade(rc, 0.35))
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(UI.shade(rc, 0.85), UI.shade(rc, 0.38))
	bg.Rotation = 90
	bg.Parent = b
	-- a trading card: the rarity's frame instead of the coloured box (its cream inside is `inset`)
	local inset = { 6, 6, 6, 6 }
	if TRADING then
		b.BackgroundTransparency = 1
		rim.Enabled = false
		bg.Enabled = false
		local _, ins = cardFrame(b, c.rarity, 104, 140, 0.11) -- (a slim border, so the picture gets the room)
		inset = ins
	end
	-- the card's picture, full bleed (Config.ICONS.scene_<Id>)
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundColor3 = UI.shade(rc, 1.2)
	art.Image = if TRADING then cardPic(c.id) else Config.ICONS["scene_" .. c.id] or ""
	art.ScaleType = Enum.ScaleType.Crop
	art.Size = UDim2.new(1, -10, 0, 74)
	art.Position = UDim2.fromOffset(5, 5)
	UI.corner(art, 10)
	art.Parent = b
	if TRADING then
		-- the picture fills the whole card inside the frame; the name rides a ribbon across the top
		art.Size = UDim2.new(1, -(inset[1] + inset[3]), 1, -(inset[2] + inset[4]))
		art.Position = UDim2.fromOffset(inset[1], inset[2])
		dressPicture(art, rc, 6)
		local _, nm = nameRibbon(b, c.name, c.rarity, 118, 36, UDim2.fromOffset(52, inset[2] + 4), 1.5)
		nm.Size = UDim2.new(1, 0, 1, -4)
		if not inStock and not owned and tab == "stock" then
			art.ImageColor3 = Color3.fromRGB(185, 185, 185) -- sold out: a little darker, but still easy to see
		end
	else
		local nameBar = UI.frame({ size = UDim2.new(1, -12, 0, 24), pos = UDim2.fromOffset(6, 82), color = if GUILD then Color3.fromRGB(60, 36, 16) else Color3.fromRGB(20, 14, 36), parent = b, radius = 6, outline = 0, name = "NameBar" })
		nameBar.BackgroundTransparency = 0.35
		UI.text(nameBar, c.name, UDim2.new(1, -6, 1, -4), { pos = UDim2.fromOffset(3, 2), stroke = 1.5 })
	end
	local equipped = owned and d.class == c.id
	local state = if owned then (if equipped then "EQUIPPED" else "YOURS") elseif c.gems <= 0 then "FREE" else Format.short(c.gems) -- out of stock: still its price, the card dimmed
	local pillColor = if equipped then Color3.fromRGB(255, 196, 40) elseif owned then C.green elseif inStock then Color3.fromRGB(80, 200, 70) else Color3.fromRGB(34, 28, 58)
	local pill = UI.frame({ size = UDim2.new(1, -12, 0, 26), pos = UDim2.new(0.5, 0, 1, -6), anchor = Vector2.new(0.5, 1), color = pillColor, parent = b, radius = 8, outline = 2 })
	if TRADING then
		-- hanging off the bottom of the card
		pill.Size = UDim2.fromOffset(84, 24)
		pill.Position = UDim2.new(0.5, 0, 1, 8)
		pill.ZIndex = 4
	end
	UI.gradient(pill, pillColor)
	local gemPrice = not owned and c.gems > 0
	if gemPrice then
		UI.icon(pill, "gem", 20, UDim2.fromOffset(8, 3))
	end
	UI.text(pill, state, UDim2.new(1, if gemPrice then -36 else -8, 1, -6), { pos = UDim2.fromOffset(if gemPrice then 30 else 4, 3), stroke = 1.5 })
	local chance = Config.CLASS_CHANCE[c.id]
	if chance and chance > 0 then
		local chip = UI.frame({ size = UDim2.fromOffset(48, 22), pos = UDim2.new(1, 6, 0, -10), anchor = Vector2.new(1, 0), color = Color3.fromRGB(22, 14, 40), parent = b, radius = 7, outline = 2, name = "Chance" })
		if GUILD and Skin.has("wax_seal") then
			-- the odds on a wax seal in the card's rarity colour
			chip.Size = UDim2.fromOffset(50, 50)
			chip.Position = UDim2.new(1, 14, 0, -18)
			chip.BackgroundTransparency = 1
			;(chip:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
			local w = UI.icon(chip, "wax_seal", 50, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			if w:IsA("ImageLabel") then
				w.ImageColor3 = UI.shade(rc, 0.9)
			end
			UI.text(chip, pctText(chance), UDim2.new(0.8, 0, 0.4, 0), { pos = UDim2.fromScale(0.1, 0.3), stroke = 1.5 })
		else
			UI.text(chip, pctText(chance), UDim2.new(1, -4, 1, -4), { pos = UDim2.fromOffset(2, 2), stroke = 1 })
		end
		if TRADING then
			-- (on a trading card the seal sits on the lower right corner, clear of the name ribbon)
			chip.AnchorPoint = Vector2.new(0.5, 0.5)
			chip.Position = UDim2.new(1, -18, 1, -30) -- (inside the card, so the next card in the row can't cover it)
			chip.ZIndex = 5
			for _, k in chip:GetChildren() do
				if k:IsA("ImageLabel") then
					k.Size = UDim2.fromOffset(42, 42)
				end
			end
		end
	end
	if not inStock and not owned and tab == "stock" then
		local shade = UI.frame({ size = UDim2.fromScale(1, 1), color = if GUILD then Color3.fromRGB(24, 14, 4) else Color3.fromRGB(10, 6, 20), parent = b, radius = 14, outline = 0, name = "Dim" })
		shade.BackgroundTransparency = if TRADING then 0.8 else 0.45
		shade.ZIndex = 5
	elseif TRADING and SHINE[c.rarity] then
		foil(b, 12)
	end
	-- the face-down side, shown while the cards are being dealt: deep purple, a glowing moon, the class's name
	local back = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.new(1, 1, 1), parent = b, radius = 14, outline = 3, name = "Back" })
	back.ZIndex = 8
	;(back:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if GUILD then Color3.fromRGB(110, 70, 36) else Color3.fromRGB(150, 110, 230)
	local bgr = Instance.new("UIGradient")
	-- on white, the real colours (guild: a kraft-paper envelope)
	bgr.Color = if GUILD then ColorSequence.new(Color3.fromRGB(214, 168, 110), Color3.fromRGB(160, 112, 62)) else ColorSequence.new(Color3.fromRGB(104, 62, 196), Color3.fromRGB(58, 30, 120))
	bgr.Rotation = 90
	bgr.Parent = back
	local moonGlow = Instance.new("ImageLabel")
	moonGlow.BackgroundTransparency = 1
	moonGlow.Image = Tex.Glow
	moonGlow.ImageColor3 = Color3.fromRGB(200, 170, 255)
	moonGlow.ImageTransparency = 0.35
	moonGlow.Size = UDim2.fromOffset(84, 84)
	moonGlow.Position = UDim2.new(0.5, 0, 0, 46)
	moonGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	moonGlow.ZIndex = 9
	moonGlow.Parent = back
	local moon = UI.icon(back, if GUILD and Skin.has("guild_crest") then "guild_crest" else "moon", if GUILD then 58 else 40, UDim2.new(0.5, 0, 0, 46), Vector2.new(0.5, 0.5))
	if GUILD then
		moonGlow.ImageColor3 = Color3.fromRGB(255, 230, 160)
	end
	moon.ZIndex = 10
	local backName = UI.text(back, c.name, UDim2.new(1, -10, 0, 30), { pos = UDim2.fromOffset(5, 80), stroke = 1.5, textSize = 13 })
	backName.ZIndex = 10
	if TRADING and Skin.has("card_back") then
		-- the guild's green card back
		back.BackgroundTransparency = 1
		;(back:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
		bgr.Enabled = false
		moonGlow.Visible = false
		moon.Visible = false
		backName.Visible = false
		local face = UI.icon(back, "card_back", 140, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		face.Size = UDim2.fromScale(1, 1)
		face.ZIndex = 9
		if face:IsA("ImageLabel") then
			face.ScaleType = Enum.ScaleType.Stretch
		end
	end
	back.Visible = false
	if picked then
		local grow = Instance.new("UIScale")
		grow.Scale = 1.06
		grow.Parent = b
	end
	if GUILD and not TRADING then
		Skin.pushpin(b, UDim2.new(0.5, 0, 0, 2), 18)
	end
	UI.clicky(b)
	b.MouseButton1Click:Connect(function()
		selected = c.id
		ClassDeal.refresh()
	end)
	b.Parent = slot
	cardsByClass[c.id] = b
	return b
end

-- A new deal, timed off Chop A Forest at 120 fps:
--   * every card you don't own turns face down at once (moon backs), the timer reads DEALING
--   * a hop wave runs along the backs for 1.4 s: each card lifts 7 px and drops (0.3 s up, 0.3 s rest),
--     the next card 0.075 s later, so a ripple keeps travelling left to right
--   * then the cards turn over one at a time, left to right, 0.1 - 0.4 s apart: the face swaps in at once,
--     22 px high and at 90% size, and settles into place over 0.25 s (sine out); a rare one's gold rays come on
-- Returns how long it all takes.
local WAVE_TIME, WAVE_LAG, WAVE_PERIOD, WAVE_LIFT = 1.4, 0.075, 0.6, 7
local dealingUntil = 0
local dealWave: RBXScriptConnection? = nil
local function flipUp(b: GuiObject, i: number)
	if not b.Parent then
		return
	end
	local back = b:FindFirstChild("Back") :: GuiObject?
	if back then
		back.Visible = false
	end
	local chip = b:FindFirstChild("Chance") :: GuiObject?
	if chip then
		chip.Visible = true
	end
	local slot = b.Parent :: GuiObject
	local shine = slot:FindFirstChild("Shine") :: GuiObject?
	if shine then
		shine.Visible = true
		Sound.play("purchase")
	end
	local baseY = (b:GetAttribute("BaseY") :: number?) or 16
	b.Position = UDim2.fromOffset(56, baseY - 22)
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(b, info, { Position = UDim2.fromOffset(56, baseY) }):Play()
	UI.dropIn(b, 0.9, 0.25) -- 90% -> its own size, through UI's juice so it keeps the picked card's 1.06
	Sound.playAt("click", 0.95 + i * 0.04)
end
local function dealAnimation(_ids: { string }): number
	local d = State.data
	local list: { GuiObject } = {}
	for _, c in Config.CLASSES do
		local b = cardsByClass[c.id]
		if b and b:FindFirstChild("Back") and not (d and table.find(d.classes, c.id)) then
			table.insert(list, b)
		end
	end
	for _, b in list do
		(b:FindFirstChild("Back") :: GuiObject).Visible = true
		local chip = b:FindFirstChild("Chance") :: GuiObject?
		if chip then
			chip.Visible = false -- the backs carry no odds chip
		end
		local shine = (b.Parent :: Instance):FindFirstChild("Shine") :: GuiObject?
		if shine then
			shine.Visible = false
		end
	end
	timerText.Text = "DEALING"
	if dealWave then
		dealWave:Disconnect()
	end
	local t0 = os.clock()
	dealWave = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for i, b in list do
			local back = b:FindFirstChild("Back") :: GuiObject?
			if not (back and back.Visible) then
				continue
			end
			local baseY = (b:GetAttribute("BaseY") :: number?) or 16
			local lift = 0
			if t < WAVE_TIME then
				local ph = ((t - (i - 1) * WAVE_LAG) / WAVE_PERIOD) % 1 -- 0..1 through this card's cycle
				if ph < 0.5 then
					lift = math.sin(ph * 2 * math.pi) * WAVE_LIFT -- up and back down in the first half
				end
			end
			b.Position = UDim2.fromOffset(56, baseY - lift)
		end
	end)
	local at, last = WAVE_TIME, WAVE_TIME
	for i, b in list do
		task.delay(at, function()
			flipUp(b, i)
		end)
		last = at
		at += 0.1 + math.random() * 0.3
	end
	local total = last + 0.1 -- the rare reveal comes 0.1 s after the last card turns
	dealingUntil = os.clock() + total + 0.3 -- the timer reads DEALING (bar near empty) until the deal is done
	task.delay(total, function()
		if dealWave then
			dealWave:Disconnect()
			dealWave = nil
		end
	end)
	return total
end

-- The banner that drops in at the top when a rare card is dealt (Chop A Forest's "... is IN STOCK at the class
-- stand!"): it comes down from off screen with a Back overshoot (~12 px past) in 0.32 s, as the backs go down.
local stockToastFrame: Frame? = nil
local function stockToast(c)
	if stockToastFrame then
		stockToastFrame:Destroy()
	end
	local rc = if c.rarity == "Secret" then Color3.fromRGB(200, 110, 255) else Config.RARITY_COLORS[c.rarity]
	local f = UI.frame({ size = UDim2.fromOffset(360, 68), pos = UDim2.new(0.5, 0, 0, -110), anchor = Vector2.new(0.5, 0), color = if GUILD then Color3.fromRGB(44, 28, 14) else Color3.fromRGB(24, 16, 30), parent = UI.gui, radius = 10, outline = 2, name = "StockToast" })
	;(f:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(230, 170, 60)
	f.BackgroundTransparency = 0.05
	f.ZIndex = 70
	stockToastFrame = f
	local art = Instance.new("ImageLabel")
	art.BackgroundColor3 = UI.shade(rc, 0.8)
	art.Image = widePic(c.id)
	art.ScaleType = Enum.ScaleType.Crop
	art.Size = UDim2.fromOffset(118, 44)
	art.Position = UDim2.fromOffset(-6, 4)
	art.ZIndex = 71
	UI.corner(art, 6)
	art.Parent = f
	local hex = string.format("#%02x%02x%02x", math.floor(rc.R * 255), math.floor(rc.G * 255), math.floor(rc.B * 255))
	local line = UI.text(f, ('<font color="%s">%s</font> is IN STOCK at the class stand!'):format(hex, c.name), UDim2.new(1, -128, 0, 36), { pos = UDim2.fromOffset(120, 4), align = Enum.TextXAlignment.Left, stroke = 1.5 })
	line.RichText = true
	line.TextWrapped = true
	line.ZIndex = 71
	local left = Config.STOCK_WINDOW - (workspace:GetServerTimeNow() % Config.STOCK_WINDOW)
	local sub = UI.text(f, string.upper(c.rarity) .. " · restocks in " .. Format.clock(left), UDim2.new(1, -128, 0, 16), { pos = UDim2.fromOffset(120, 44), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(220, 210, 240), stroke = 1.2 })
	sub.ZIndex = 71
	TweenService:Create(f, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 18) }):Play()
	task.delay(10, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -110) }):Play()
			task.wait(0.32)
			f:Destroy()
		end
	end)
end

-- The reveal's "umph" (the owner's hatch brief, same hype for classes): a shockwave ring (two for Legendary+, gold
-- then the rarity colour), stars bursting out of the card, and a short shake of the whole reveal.
local REVEAL_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local function revealBurst(root: GuiObject, c, cx: number, cy: number)
	local rc = Config.RARITY_COLORS[c.rarity] or Color3.new(1, 1, 1)
	local rank = REVEAL_RANK[c.rarity] or 1
	local big = rank >= 5
	local ringImg = Config.ICONS.ring or ""
	for k = 1, if big then 2 else 1 do
		local ring = Instance.new("ImageLabel")
		ring.Name = "Shockwave"
		ring.BackgroundTransparency = 1
		ring.Image = ringImg
		ring.ImageColor3 = if k == 1 and big then GOLD else rc
		ring.ImageTransparency = 0.15
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromOffset(cx, cy)
		ring.Size = UDim2.fromOffset(120, 120)
		ring.ZIndex = 62
		ring.Parent = root
		local info = TweenInfo.new(if big then 0.75 else 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, (k - 1) * 0.16)
		local size = if big then 1100 else 760
		TweenService:Create(ring, info, { Size = UDim2.fromOffset(size, size), ImageTransparency = 1 }):Play()
	end
	-- stars bursting out of the card
	for k = 1, if big then 26 else 14 do
		local star = Instance.new("ImageLabel")
		star.BackgroundTransparency = 1
		star.Image = STAR_IMG
		star.ImageColor3 = if c.rarity == "Secret" then Color3.fromHSV(math.random(), 0.6, 1) elseif k % 3 == 0 then Color3.new(1, 1, 1) else rc:Lerp(Color3.new(1, 1, 1), 0.25)
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromOffset(cx, cy)
		local sz = math.random(16, if big then 40 else 30)
		star.Size = UDim2.fromOffset(sz, sz)
		star.Rotation = math.random(0, 360)
		star.ZIndex = 63
		star.Parent = root
		local a = (k / (if big then 26 else 14)) * math.pi * 2 + math.random() * 0.4
		local dist = math.random(220, if big then 480 else 340)
		local t = 0.55 + math.random() * 0.35
		TweenService:Create(star, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(cx + math.cos(a) * dist, cy + math.sin(a) * dist * 0.8),
			Rotation = star.Rotation + math.random(-200, 200),
			ImageTransparency = 1,
			Size = UDim2.fromOffset(sz * 0.4, sz * 0.4),
		}):Play()
	end
	-- a short shake, harder for the rare ones
	local amp = if big then 16 else 8
	local base = root.Position
	task.spawn(function()
		local t0 = os.clock()
		while root.Parent and os.clock() - t0 < 0.35 do
			local k = 1 - (os.clock() - t0) / 0.35
			root.Position = base + UDim2.fromOffset((math.random() - 0.5) * 2 * amp * k, (math.random() - 0.5) * 2 * amp * k)
			RunService.RenderStepped:Wait()
		end
		if root.Parent then
			root.Position = base
		end
	end)
end

-- The charge-up before a reveal: the card appears face down on a dark screen, glows through in the rarity colour
-- and shakes harder and faster while rising ticks play; Legendary and up fake you out (the glow starts Epic purple
-- and jumps to the real colour with a ping). Rarer = longer. Then the reveal flashes in over it.
local CHARGE = { Common = 0.35, Uncommon = 0.4, Rare = 0.6, Epic = 0.75, Legendary = 1.05, Mythic = 1.2, Secret = 1.5 }
local function charge(c, onDone: () -> ())
	local rc = Config.RARITY_COLORS[c.rarity] or Color3.new(1, 1, 1)
	local rank = REVEAL_RANK[c.rarity] or 1
	local fake = rank >= 5
	local dur = CHARGE[c.rarity] or 0.5
	local root = Instance.new("Frame")
	root.Name = "ClassCharge"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(1280, 720)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.ZIndex = 59
	root.Parent = UI.gui
	local tint = UI.frame({ size = UDim2.fromScale(4, 4), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = if GUILD then Color3.fromRGB(28, 18, 6) else Color3.fromRGB(22, 6, 42), parent = root, radius = 0, outline = 0, name = "Tint" })
	tint.BackgroundTransparency = 1
	TweenService:Create(tint, TweenInfo.new(0.2), { BackgroundTransparency = 0.15 }):Play()
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = Config.ICONS.glow_soft or ""
	glow.ImageColor3 = if fake then Config.RARITY_COLORS.Epic else rc
	glow.ImageTransparency = 0.7
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromOffset(640, 336)
	glow.Size = UDim2.fromOffset(260, 330)
	glow.ZIndex = 60
	glow.Parent = root
	local back = UI.frame({ size = UDim2.fromOffset(174, 240), pos = UDim2.fromOffset(640, 336), anchor = Vector2.new(0.5, 0.5), color = NAVY, parent = root, radius = 14, outline = 4, name = "Back" })
	back.ZIndex = 61
	local stroke = back:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = glow.ImageColor3
	local mark = UI.text(back, "?", UDim2.fromScale(1, 1), { stroke = 3, color = Color3.fromRGB(235, 225, 255) })
	mark.TextScaled = true
	mark.ZIndex = 62
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = back
	TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sound.play("whoosh")
	local t0 = os.clock()
	local nextTick = 0.18
	local faked = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local p = math.clamp(t / dur, 0, 1)
		-- shake harder and faster as it charges
		local amp = 2 + 14 * p * p
		local freq = 10 + 26 * p
		back.Rotation = math.sin(t * freq) * amp
		back.Position = UDim2.fromOffset(640 + math.sin(t * freq * 1.3) * amp * 0.4, 336)
		glow.ImageTransparency = 0.7 - 0.55 * p
		local gs = 1 + 0.35 * p + math.sin(t * 20) * 0.03 * p
		glow.Size = UDim2.fromOffset(260 * gs, 330 * gs)
		if t >= nextTick and p < 1 then
			Sound.playAt("rareChime", 0.7 + p * 0.9, 0.18)
			nextTick += math.max(0.08, 0.22 - 0.14 * p)
		end
		if fake and not faked and p >= 0.7 then
			faked = true
			glow.ImageColor3 = rc
			stroke.Color = rc
			sc.Scale = 1.12
			TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			Sound.playAt("rareChime", 1.9, 0.4)
		end
		if p >= 1 then
			conn:Disconnect()
			onDone()
			task.delay(0.08, function()
				root:Destroy()
			end)
		end
	end)
end

-- The full-screen reveal, timed off Chop A Forest at 120 fps:
--   0.00 s  a white flash (90%) over everything, fading out linearly in 0.5 s onto a dark purple dim (85%)
--           the card pops from 30% size: Back out over 0.65 s (peaks ~107% at 0.37 s, settles by 0.65 s)
--           16 gold rays behind it fade in from 0.15 s and turn 28 degrees a second
--   2.30 s  the card shrinks straight down to nothing in place (linear, 0.43 s) while the dim, the rays and the
--           words fade out (linear, 0.5 s); the avatar flashes the card's colour
local function reveal(c, line: string, confetti: boolean)
	local rc = Config.RARITY_COLORS[c.rarity]
	local root = Instance.new("Frame")
	root.Name = "ClassReveal"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(1280, 720)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.ZIndex = 60
	root.Parent = UI.gui
	local fades: { { inst: Instance, prop: string } } = {}
	local tint = UI.frame({ size = UDim2.fromScale(4, 4), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = if GUILD then Color3.fromRGB(28, 18, 6) else Color3.fromRGB(22, 6, 42), parent = root, radius = 0, outline = 0, name = "Tint" })
	tint.BackgroundTransparency = 0.15
	table.insert(fades, { inst = tint, prop = "BackgroundTransparency" })
	local CX, CY = 640, 336 -- the card's centre in the 1280 x 720 screen
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.Size = UDim2.fromOffset(860, 860)
	rays.Position = UDim2.fromOffset(CX, CY)
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Parent = root
	local rayBars: { Frame } = {}
	for i = 0, 7 do -- 8 bars through the centre = 16 rays
		local r = Instance.new("Frame")
		r.BorderSizePixel = 0
		r.BackgroundColor3 = if c.rarity == "Secret" then Color3.fromHSV(i / 8, 0.55, 1) else rc:Lerp(Color3.fromRGB(255, 236, 170), 0.3)
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(0, 64, 1, 0)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Rotation = i * 22.5
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 0.9), NumberSequenceKeypoint.new(0.4, 0.35), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(0.78, 0.9), NumberSequenceKeypoint.new(1, 1) })
		g.Rotation = 90
		g.Parent = r
		r.Parent = rays
		table.insert(rayBars, r)
		TweenService:Create(r, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.15), { BackgroundTransparency = 0.35 }):Play()
		table.insert(fades, { inst = r, prop = "BackgroundTransparency" })
	end
	local spin = TweenService:Create(rays, TweenInfo.new(360 / 28, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	spin:Play()
	local big = UI.frame({ size = UDim2.fromOffset(174, 240), pos = UDim2.fromOffset(CX, CY), anchor = Vector2.new(0.5, 0.5), color = rc, parent = root, radius = 14, outline = 4, name = "Card" })
	;(big:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(235, 225, 255)
	if c.rarity == "Secret" then
		big.BackgroundColor3 = Color3.new(1, 1, 1)
		local pg = Instance.new("UIGradient")
		pg.Color = PRISM
		pg.Rotation = 45
		pg.Parent = big
	else
		UI.gradient(big, rc)
	end
	local pic = Instance.new("ImageLabel")
	pic.Name = "Art"
	pic.BackgroundColor3 = UI.shade(rc, 1.2)
	pic.Image = if TRADING then cardPic(c.id) else Config.ICONS["scene_" .. c.id] or ""
	pic.ScaleType = Enum.ScaleType.Crop
	pic.Size = UDim2.new(1, -24, 0, 120)
	pic.Position = UDim2.fromOffset(12, 12)
	UI.corner(pic, 8)
	pic.Parent = big
	local bigName = UI.text(big, (string.split(c.name, " "))[1], UDim2.new(1, -16, 0, 30), { pos = UDim2.fromOffset(8, 140), stroke = 2.5 })
	if TRADING then
		-- the same trading card as in the row, drawn big
		big.BackgroundTransparency = 1
		;(big:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
		local g = big:FindFirstChildOfClass("UIGradient")
		if g then
			g.Enabled = false
		end
		bigName.Visible = false
		local _, ins = cardFrame(big, c.rarity, 174, 240, 0.18)
		pic.Size = UDim2.new(1, -(ins[1] + ins[3]), 1, -(ins[2] + ins[4]))
		pic.Position = UDim2.fromOffset(ins[1], ins[2])
		dressPicture(pic, rc, 10)
		nameRibbon(big, c.name, c.rarity, 200, 60, UDim2.fromOffset(87, ins[2] + 8), 2)
		local label = UI.text(big, string.upper(c.rarity), UDim2.new(1, -40, 0, 20), { pos = UDim2.new(0, 20, 1, -(ins[4] + 28)), color = Color3.new(1, 1, 1):Lerp(rc, 0.35), stroke = 2.5 })
		label.ZIndex = 4
		foil(big, 14)
	end
	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = big
	TweenService:Create(pop, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local nameText = UI.text(root, string.upper(c.name), UDim2.fromOffset(700, 40), { pos = UDim2.fromOffset(CX, 498), anchor = Vector2.new(0.5, 0), stroke = 4 })
	local lineText = UI.text(root, line, UDim2.fromOffset(600, 22), { pos = UDim2.fromOffset(CX, 538), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(255, 214, 70), stroke = 2.5 })
	for _, t in { nameText, lineText } do
		table.insert(fades, { inst = t, prop = "TextTransparency" })
		local st = t:FindFirstChildOfClass("UIStroke")
		if st then
			table.insert(fades, { inst = st, prop = "Transparency" })
		end
	end
	local flash = UI.frame({ size = UDim2.fromScale(4, 4), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.new(1, 1, 1), parent = root, radius = 0, outline = 0, name = "Flash" })
	flash.ZIndex = 80
	flash.BackgroundTransparency = 0.1
	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { BackgroundTransparency = 1 }):Play()
	Sound.play("reveal")
	if confetti then
		Confetti.burst(90)
	end
	revealBurst(root, c, CX, CY)
	task.delay(2.3, function()
		TweenService:Create(pop, TweenInfo.new(0.43, Enum.EasingStyle.Linear), { Scale = 0.1 }):Play()
		local out = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
		for _, f in fades do
			TweenService:Create(f.inst, out, { [f.prop] = 1 }):Play()
		end
		ClassRoom.pulse(rc, confetti)
		task.wait(0.43)
		big.Visible = false
		task.wait(0.1)
		spin:Cancel()
		root:Destroy()
	end)
end

local function setTab(t: string)
	tab = t
	UI.setButton(stockTab, "STOCK", if t == "stock" then C.orange else TAB_OFF)
	ClassDeal.refresh()
end
stockTab.MouseButton1Click:Connect(function()
	setTab("stock")
end)
ownedTab.MouseButton1Click:Connect(function()
	setTab("owned")
end)

function ClassDeal.refresh()
	local d = State.data
	if not d then
		return
	end
	local stock, lucky = currentStock(d)
	gemText.Text = Format.commas(d.gems)
	UI.setButton(ownedTab, "OWNED", if tab == "owned" then C.orange else TAB_OFF)
	ownedCount.Text = tostring(#d.classes)
	if not selected then
		selected = stock[1] or d.class
	end

	-- a new deal (restock bought, or the 5 minutes ran out)? pick its best rare card before drawing
	local key = Config.stockWindow() .. ":" .. table.concat(stock, ",")
	local newDeal = lastDealKey ~= nil and key ~= lastDealKey and UI.isOpen("Classes") and tab == "stock"
	lastDealKey = key
	local best = nil
	if newDeal then
		for _, id in stock do
			local sc = Config.class(id)
			if sc and BIG_REVEAL[sc.rarity] and not table.find(d.classes, id) then
				if not best or sc.gems > best.gems then
					best = sc
				end
			end
		end
	end

	-- the card row
	UI.clear(row)
	table.clear(cardsByClass)
	for i, c in Config.CLASSES do
		local owned = table.find(d.classes, c.id) ~= nil
		if tab == "owned" and not owned then
			continue
		end
		if tab == "stock" and c.gems <= 0 and not owned then
			continue
		end
		card(c, i, d, stock)
	end
	if tab == "owned" then
		-- the empty slot after your cards (Chop A Forest's "Buy more when they're in STOCK")
		local slot = Instance.new("Frame")
		slot.Name = "BuyMore"
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(112, 162)
		slot.LayoutOrder = 999
		slot.Parent = row
		local ph = UI.frame({ size = UDim2.fromOffset(104, 140), pos = UDim2.fromOffset(56, 16), anchor = Vector2.new(0.5, 0), color = if GUILD then Color3.fromRGB(70, 44, 22) else Color3.fromRGB(30, 20, 56), parent = slot, radius = 14, outline = 3, name = "Empty" })
		ph.BackgroundTransparency = 0.15
		;(ph:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if GUILD then Color3.fromRGB(170, 120, 70) else Color3.fromRGB(100, 70, 160)
		local plusRing = UI.frame({ size = UDim2.fromOffset(38, 38), pos = UDim2.fromScale(0.5, 0.3), anchor = Vector2.new(0.5, 0.5), color = if GUILD then Color3.fromRGB(110, 70, 36) else Color3.fromRGB(50, 34, 90), parent = ph, radius = 999, outline = 2, name = "Plus" })
		;(plusRing:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if GUILD then Color3.fromRGB(240, 210, 160) else Color3.fromRGB(190, 170, 230)
		UI.text(plusRing, "+", UDim2.new(1, -4, 1, -4), { pos = UDim2.fromOffset(2, 0), stroke = 1.5 })
		UI.text(ph, "Buy more when they're in STOCK", UDim2.new(1, -12, 0, 40), { pos = UDim2.fromOffset(6, 74), stroke = 1.5, textSize = 14 })
	end

	-- the picked class
	local c = Config.class(selected or d.class) or Config.class(Config.DEFAULT_CLASS)
	local rc = Config.RARITY_COLORS[c.rarity]
	local owned = table.find(d.classes, c.id) ~= nil
	local inStock = table.find(stock, c.id) ~= nil
	detail.BackgroundColor3 = rc
	detailGrad.Color = if c.rarity == "Secret" then PRISM else ColorSequence.new(UI.shade(rc, 1.15), UI.shade(rc, 0.7))
	detailGrad.Rotation = if c.rarity == "Secret" then 45 else 90
	if c.rarity == "Secret" then
		detail.BackgroundColor3 = Color3.new(1, 1, 1)
		rc = Color3.fromRGB(200, 110, 255) -- glow, stroke and art panel in prism purple
	end
	detailStroke.Color = UI.shade(rc, 1.5)
	if c.rarity == "Mythic" or c.rarity == "Secret" then
		detailStroke.Color = Color3.new(1, 1, 1)
		detailRimGrad.Color = RAINBOW
		detailRimGrad.Enabled = true
	elseif c.rarity == "Legendary" then
		detailStroke.Color = Color3.new(1, 1, 1)
		detailRimGrad.Color = GOLD_SHIMMER
		detailRimGrad.Enabled = true
	else
		detailRimGrad.Enabled = false
	end
	rarityPill.BackgroundColor3 = UI.shade(rc, 0.45)
	rarityText.Text = string.upper(c.rarity) .. (if d.class == c.id then " · EQUIPPED" else "")
	detName.Text = c.name
	detState.Text = if owned then "YOURS" elseif inStock then "IN STOCK" .. (if lucky then " (LUCKY DEAL)" else "") else "SOLD OUT"
	local stars = RARITY_STARS[c.rarity] or 1
	for i, s in starIcons do
		s.ImageColor3 = if i <= stars then Color3.fromRGB(255, 205, 50) else Color3.fromRGB(70, 60, 84)
	end
	UI.clear(artHolder)
	local pic = Instance.new("ImageLabel")
	pic.Name = "Scene"
	pic.BackgroundTransparency = 1
	pic.Image = widePic(c.id)
	pic.ScaleType = Enum.ScaleType.Crop
	pic.Size = UDim2.fromScale(1, 1)
	UI.corner(pic, 12)
	pic.Parent = artHolder
	artPanel.BackgroundColor3 = UI.shade(rc, 1.25)
	artGlow.ImageColor3 = UI.shade(rc, 1.4)
	cardGlow.ImageColor3 = rc
	for _, s in stripes do
		s.Visible = STRIPED[c.rarity] == true and parch == nil and not TRADING
	end
	if TRADING then
		if detailRarity ~= c.rarity then
			detailRarity = c.rarity
			if detailFrame then
				detailFrame:Destroy()
			end
			detailFrame = cardFrame(detail, c.rarity, 310, 460, 0.22)
		end
		detailStroke.Transparency = 1
		if detRibbon and detRibbon:IsA("ImageLabel") then
			detRibbon.ImageColor3 = ribbonTint(c.rarity)
		end
	end
	if parch then
		parch.ImageColor3 = Color3.new(1, 1, 1):Lerp(rc, 0.16)
		header.BackgroundColor3 = UI.shade(rc, 0.85)
		detailStroke.Transparency = if detailRimGrad.Enabled then 0 else 1
		if seal and seal:IsA("ImageLabel") then
			seal.ImageColor3 = UI.shade(rc, 0.95)
		end
	end
	detQuote.Text = '"' .. (QUOTES[c.id] or "") .. '"'
	ClassRoom.setAura(rc)
	UI.clear(perkRows)
	perkLayout.Parent = perkRows
	local n = 0
	for _, s in STATS do
		local v = (c :: any)[s.key]
		if v and v ~= 0 and n < 5 then -- every stat it has (rarer classes have more of them)
			n += 1
			local r = UI.frame({ size = UDim2.new(1, 0, 0, 22), color = if parch or TRADING then Color3.fromRGB(96, 60, 30) else Color3.fromRGB(14, 10, 30), parent = perkRows, radius = 7, outline = 0, name = "Perk" })
			r.BackgroundTransparency = 0.4
			r.LayoutOrder = n
			UI.icon(r, STAT_ICON[s.key], 18, UDim2.fromOffset(5, 2))
			UI.text(r, s.label, UDim2.new(1, -110, 1, -6), { pos = UDim2.fromOffset(32, 3), align = Enum.TextXAlignment.Left, stroke = 1.5 })
			local pill = UI.frame({ size = UDim2.fromOffset(62, 20), pos = UDim2.new(1, -4, 0.5, 0), anchor = Vector2.new(1, 0.5), color = Color3.fromRGB(40, 150, 60), parent = r, radius = 6, outline = 0, name = "Value" })
			UI.gradient(pill, Color3.fromRGB(50, 170, 70))
			UI.text(pill, statText(s, v), UDim2.new(1, -6, 1, -4), { pos = UDim2.fromOffset(3, 2), color = Color3.fromRGB(190, 255, 160), stroke = 1.5 })
		end
	end
	local chance, luckyChance = Config.CLASS_CHANCE[c.id] or 0, Config.CLASS_CHANCE_LUCKY[c.id] or 0
	if c.gems <= 0 then
		detOdds.Text = "Everyone starts with this class"
	elseif inStock and not owned then
		detOdds.Text = "Gone at the next restock!"
	else
		detOdds.Text = ("Costs %s gems - %s chance it's in the next deal (Lucky Restock: %s)"):format(Format.commas(c.gems), pctText(chance), pctText(luckyChance))
	end
	local product = c.product and Config.PRODUCTS[c.product]
	robuxBtn.Visible = product ~= nil and not owned
	if product then
		UI.setButton(robuxBtn, Format.commas(product.robux))
	end
	gemIcon.Visible = not owned and inStock
	tick.Visible = owned
	local btnH = if TRADING then 44 else 48
	if owned then
		gemBtn.Size = UDim2.new(1, if TRADING then -48 else -32, 0, btnH)
		UI.setButton(gemBtn, if d.class == c.id then "EQUIPPED" else "EQUIP", Color3.fromRGB(40, 180, 90))
	else
		gemBtn.Size = if product then UDim2.fromOffset(if TRADING then 128 else 134, btnH) else UDim2.new(1, if TRADING then -48 else -32, 0, btnH)
		if inStock then
			UI.setButton(gemBtn, Format.commas(c.gems), if d.gems >= c.gems then Color3.fromRGB(150, 90, 245) else W.grey)
		else
			UI.setButton(gemBtn, "SOLD OUT", W.grey)
		end
	end
	local _ = robuxIcon

	-- VS YOUR CLASS
	local mine = Config.class(d.class) or Config.class(Config.DEFAULT_CLASS)
	vsNames.Text = if mine.id == c.id then mine.name .. " is equipped" else mine.name .. "  →  " .. c.name
	UI.clear(vsRows)
	vsLayout.Parent = vsRows
	local shown = 0
	for _, s in STATS do
		local a, b = (mine :: any)[s.key], (c :: any)[s.key]
		if (a and a ~= 0) or (b and b ~= 0) then
			shown += 1
			if shown > 5 then
				break
			end
			local better = (b or 0) > (a or 0)
			local r = UI.frame({ size = UDim2.new(1, 0, 0, if GUILD then 28 else 30), color = if GUILD then Color3.fromRGB(96, 60, 30) else Color3.fromRGB(40, 30, 92), parent = vsRows, radius = 8, outline = 0, name = "Row" })
			r.BackgroundTransparency = 0.45
			r.LayoutOrder = shown
			UI.icon(r, STAT_ICON[s.key], 24, UDim2.fromOffset(6, 4))
			UI.text(r, s.label, UDim2.new(0.5, -36, 1, -10), { pos = UDim2.fromOffset(36, 5), align = Enum.TextXAlignment.Left, stroke = 1.5 })
			UI.text(r, statText(s, a) .. "  →", UDim2.fromOffset(78, 22), { pos = UDim2.new(1, -84, 0, 5), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = Color3.fromRGB(190, 180, 210), stroke = 1.5 })
			UI.text(r, statText(s, b), UDim2.fromOffset(70, 22), { pos = UDim2.new(1, -8, 0, 5), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = if better then Color3.fromRGB(150, 255, 120) else Color3.new(1, 1, 1), stroke = 1.5 })
		end
	end
	vsQuote.Text = '"' .. (QUOTES[c.id] or "") .. '"'

	-- the new deal flips the cards over; a Legendary or rarer card gets a full-screen reveal
	if newDeal then
		local took = dealAnimation(stock)
		if best then
			local shown = best
			stockToast(shown)
			task.delay(took, function()
				if not UI.isOpen("Classes") then
					return
				end
				-- the big card switches to it under the flash
				selected = shown.id
				ClassDeal.refresh()
				charge(shown, function()
					reveal(shown, string.upper(shown.rarity) .. " IN STOCK!", false)
				end)
			end)
		end
	end

	-- a class you just bought: "IS YOURS!" + confetti
	local ownedNow = {}
	for _, id in d.classes do
		ownedNow[id] = true
	end
	if lastOwned and UI.isOpen("Classes") then
		for id in ownedNow do
			if not lastOwned[id] then
				local nc = Config.class(id)
				if nc then
					charge(nc, function()
						reveal(nc, "IS YOURS!", true)
					end)
				end
			end
		end
	end
	lastOwned = ownedNow
end

gemBtn.MouseButton1Click:Connect(function()
	local d = State.data
	if not d or not selected then
		return
	end
	if table.find(d.classes, selected) then
		State.fire("EquipClass", selected)
	else
		State.fire("Buy", "class", selected)
	end
end)
robuxBtn.MouseButton1Click:Connect(function()
	local c = selected and Config.class(selected)
	if c and c.product then
		State.fire("Prompt", "product", c.product)
	end
end)

-- the timer, and the 5-minute restock while the window is open
task.spawn(function()
	while true do
		task.wait(0.5)
		if UI.isOpen("Classes") then
			local now = workspace:GetServerTimeNow()
			local left = Config.STOCK_WINDOW - (now % Config.STOCK_WINDOW)
			if os.clock() < dealingUntil then
				timerText.Text = "DEALING"
				timerFill.Size = UDim2.fromScale(0.04, 1)
			else
				timerText.Text = Format.clock(left)
				timerFill.Size = UDim2.fromScale(math.clamp(left / Config.STOCK_WINDOW, 0, 1), 1)
			end
			local key = Config.stockWindow() .. ":" .. table.concat((currentStock(State.data)), ",")
			if key ~= lastDealKey then
				ClassDeal.refresh()
			end
		end
	end
end)

-- Windows refreshes the open window on every data update (a restock, a purchase); the avatar only reloads on open
-- the big card floats +-1.3 px (a 3.5 s sine) once it has slid in, like Chop A Forest's
do
	local detailHome, glowHome = detail.Position, cardGlow.Position
	RunService.RenderStepped:Connect(function()
		if holder.Visible and os.clock() > slideDone then
			local y = math.sin(os.clock() * 2 * math.pi / 3.5) * 1.3
			detail.Position = detailHome + UDim2.fromOffset(0, y)
			cardGlow.Position = glowHome + UDim2.fromOffset(0, y)
		end
	end)
end

-- the energy / rarity rims turn while the screen is open (5 s a turn)
RunService.RenderStepped:Connect(function()
	if holder.Visible then
		local r = (os.clock() * 72) % 360
		for _, g in spinners do
			g.Rotation = r
		 end
	end
end)
-- tiny stars twinkling in the open space round the panels
for _, p in { { 60, 70, 18 }, { 400, 40, 12 }, { 860, 34, 16 }, { 1230, 60, 14 }, { 1250, 330, 12 }, { 30, 330, 14 }, { 520, 470, 10 }, { 790, 450, 12 }, { 1200, 690, 16 }, { 60, 690, 12 }, { 640, 30, 10 }, { 1010, 30, 12 } } do
	twinkle(holder, UDim2.fromOffset(p[1], p[2]), p[3], if GUILD then Color3.fromRGB(255, 236, 150) else Color3.fromRGB(220, 225, 255)) -- (guild: fireflies)
end

UI.register("Classes", { frame = holder, refresh = ClassDeal.refresh, pop = {}, custom = true }) -- its own open (slide-ins), no pop / squash / slide from UI.open
-- the 3D class room behind the window while it's open (the HUD steps aside, like Chop A Forest's full screen)
-- the dev-only overlays (VFX LAB toggle, DEV button) step aside too, and come back as they were
local devHidden: { [Instance]: boolean } = {}
local wasClasses = false
UI.onWindowChanged.Event:Connect(function(name)
	-- only when the class screen opens or closes (other things, e.g. the egg hatch, hide the HUD too)
	local hud = UI.gui:FindFirstChild("Hud")
	if hud and hud:IsA("GuiObject") and (name == "Classes") ~= wasClasses then
		hud.Visible = name ~= "Classes"
	end
	wasClasses = name == "Classes"
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local lab = pg and pg:FindFirstChild("VFXLabUI")
	local devButton = UI.gui:FindFirstChild("DevButton")
	if name == "Classes" then
		if lab and lab:IsA("ScreenGui") and devHidden[lab] == nil then
			devHidden[lab] = lab.Enabled
			lab.Enabled = false
		end
		if devButton and devButton:IsA("GuiObject") and devHidden[devButton] == nil then
			devHidden[devButton] = devButton.Visible
			devButton.Visible = false
		end
	else
		for inst, was in devHidden do
			if inst:IsA("ScreenGui") then
				inst.Enabled = was
			elseif inst:IsA("GuiObject") then
				inst.Visible = was
			end
		end
		table.clear(devHidden)
	end
	if name == "Classes" then
		local d = State.data
		local c = Config.class(selected or (d and d.class) or Config.DEFAULT_CLASS)
		ClassRoom.show(if c then Config.RARITY_COLORS[c.rarity] else nil)
		playSlideIns()
	else
		ClassRoom.hide()
	end
end)

return ClassDeal
