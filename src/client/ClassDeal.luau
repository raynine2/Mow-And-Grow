-- The class stand, as Chop A Forest's v2 card deal (window "Classes", opened by the stand's prompt or pad), full
-- screen over the 3D class room (client/ClassRoom: your avatar on a turning rune circle, candles, sparkles):
--   top: CL*SSES, NEW CARDS IN timer + bar, gems   left: VS YOUR CLASS, RESTOCK / LUCKY RESTOCK (Robux)
--   right: the picked class's big card (stars, picture, perks, quote, odds, gems / Robux), glowing in its rarity
--   bottom: STOCK / OWNED tabs and a row of tall cards, each with its % chance to be in a deal (odds shown because
--   the restocks are paid random items). A new deal flips the cards over one by one; a Legendary or rarer card in
--   the new deal gets a full-screen reveal, and buying a class gets "IS YOURS!" + confetti.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Confetti = require(script.Parent.Confetti)

local ClassDeal = {}
local C = UI.colors
local W = UI.wood
local player = Players.LocalPlayer

local BIG_REVEAL = { Legendary = true, Mythic = true, Secret = true }
local STATS = {
	{ key = "power", label = "Power", pct = true },
	{ key = "speed", label = "Walk speed", pct = true },
	{ key = "sell", label = "Sell price", pct = true },
	{ key = "luck", label = "Mutation luck", pct = true },
	{ key = "carry", label = "Carry", pct = false },
}
local STAT_ICON = { power = "upgrade", speed = "clover", sell = "coin", luck = "clover", carry = "backpack" }

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
	if deal and deal.window == w and deal.ids then
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
local NAVY = Color3.fromRGB(30, 20, 58)
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

-- soft dark edges so the panels read over the room (they reach past the 1280 x 720 box on wide screens)
for _, side in { { 0, 0 }, { 1, 180 } } do
	local v = UI.frame({ size = UDim2.new(0, 900, 2, 0), pos = UDim2.new(side[1], if side[1] == 0 then -480 else 480, 0.5, 0), anchor = Vector2.new(side[1], 0.5), color = Color3.fromRGB(8, 4, 18), parent = holder, radius = 0, outline = 0, name = "Shade" })
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.55, 0.5), NumberSequenceKeypoint.new(1, 1) })
	g.Rotation = side[2]
	g.Parent = v
end
local floorShade = UI.frame({ size = UDim2.new(3, 0, 0, 300), pos = UDim2.new(0.5, 0, 1, 40), anchor = Vector2.new(0.5, 1), color = Color3.fromRGB(8, 4, 18), parent = holder, radius = 0, outline = 0, name = "FloorShade" })
local fg = Instance.new("UIGradient")
fg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
fg.Rotation = 90
fg.Parent = floorShade

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
titleBox.Position = UDim2.fromOffset(640, 6)
titleBox.AnchorPoint = Vector2.new(0.5, 0)
titleBox.Parent = holder
UI.text(titleBox, "CL", UDim2.fromOffset(170, 80), { pos = UDim2.fromOffset(28, 0), align = Enum.TextXAlignment.Right, stroke = 5 })
UI.text(titleBox, "SSES", UDim2.fromOffset(190, 80), { pos = UDim2.fromOffset(238, 0), align = Enum.TextXAlignment.Left, stroke = 5 })
-- the A: a glowing gold four-point sparkle
local titleGlow = Instance.new("ImageLabel")
titleGlow.BackgroundTransparency = 1
titleGlow.Image = Tex.Glow
titleGlow.ImageColor3 = Color3.fromRGB(255, 200, 80)
titleGlow.ImageTransparency = 0.25
titleGlow.Size = UDim2.fromOffset(110, 110)
titleGlow.Position = UDim2.fromOffset(218, 42)
titleGlow.AnchorPoint = Vector2.new(0.5, 0.5)
titleGlow.Parent = titleBox
local titleStar = Instance.new("ImageLabel")
titleStar.BackgroundTransparency = 1
titleStar.Image = "rbxassetid://104095913007401" -- chunky gold sparkle, Store Icons/ClassArt/UISpark.png
titleStar.Size = UDim2.fromOffset(64, 64)
titleStar.Position = UDim2.fromOffset(218, 42)
titleStar.AnchorPoint = Vector2.new(0.5, 0.5)
titleStar.Parent = titleBox
TweenService:Create(titleGlow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.6, Size = UDim2.fromOffset(90, 90) }):Play()
TweenService:Create(titleStar, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(54, 54), Rotation = 15 }):Play()

-- NEW CARDS IN (moon, label, time, bar)
local timerPill = UI.frame({ size = UDim2.fromOffset(280, 66), pos = UDim2.fromOffset(628, 92), anchor = Vector2.new(1, 0), color = NAVY, parent = holder, radius = 16, outline = 4, name = "Timer" })
;(timerPill:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(110, 70, 190)
UI.gradient(timerPill, NAVY)
UI.icon(timerPill, "moon", 70, UDim2.fromOffset(-30, -8)).ZIndex = 3
UI.text(timerPill, "NEW CARDS IN", UDim2.fromOffset(130, 22), { pos = UDim2.fromOffset(52, 8), align = Enum.TextXAlignment.Left, stroke = 1.5 })
local timerText = UI.text(timerPill, "5:00", UDim2.fromOffset(80, 32), { pos = UDim2.new(1, -12, 0, 4), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, stroke = 2.5 })
local timerTrack = UI.frame({ size = UDim2.new(1, -66, 0, 12), pos = UDim2.fromOffset(52, 42), color = Color3.fromRGB(56, 40, 86), parent = timerPill, radius = 6, outline = 0 })
local timerFill = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(220, 100, 255), parent = timerTrack, radius = 6, outline = 0 })
UI.gradient(timerFill, Color3.fromRGB(220, 100, 255))

-- gems, with a + that opens the shop
local gemBox = UI.frame({ size = UDim2.fromOffset(240, 66), pos = UDim2.fromOffset(652, 92), color = NAVY, parent = holder, radius = 16, outline = 4, name = "Gems" })
;(gemBox:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(110, 70, 190)
UI.gradient(gemBox, NAVY)
UI.icon(gemBox, "gem", 62, UDim2.fromOffset(-6, 2)).ZIndex = 3
local gemText = UI.text(gemBox, "0", UDim2.fromOffset(110, 34), { pos = UDim2.fromOffset(64, 6), align = Enum.TextXAlignment.Left, stroke = 2.5 })
UI.text(gemBox, "gems", UDim2.fromOffset(60, 18), { pos = UDim2.fromOffset(64, 40), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(190, 180, 220), stroke = 1 })
local plus = UI.button(gemBox, "+", C.green, UDim2.fromOffset(48, 48), function()
	UI.open("Store")
end, { pos = UDim2.new(1, -10, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "More" })
plus.ZIndex = 4
UI.closeButton(holder, UDim2.fromOffset(112, 30), function()
	UI.close()
end)

-- VS YOUR CLASS
local vs = UI.frame({ size = UDim2.fromOffset(360, 214), pos = UDim2.fromOffset(40, 112), color = NAVY, parent = holder, radius = 18, outline = 4, name = "VsCard" })
;(vs:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = GOLD
local vsGrad = Instance.new("UIGradient")
vsGrad.Color = ColorSequence.new(Color3.fromRGB(56, 32, 100), Color3.fromRGB(24, 14, 46))
vsGrad.Rotation = 90
vsGrad.Parent = vs
UI.text(vs, "VS YOUR CLASS", UDim2.fromOffset(240, 28), { pos = UDim2.fromOffset(16, 10), align = Enum.TextXAlignment.Left, color = GOLD, stroke = 2 })
local vsNames = UI.text(vs, "", UDim2.new(1, -32, 0, 18), { pos = UDim2.fromOffset(16, 38), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(190, 180, 220), stroke = 1 })
local vsRows = Instance.new("Frame")
vsRows.BackgroundTransparency = 1
vsRows.Size = UDim2.new(1, -28, 0, 108)
vsRows.Position = UDim2.fromOffset(14, 62)
vsRows.Parent = vs
local vsLayout = Instance.new("UIListLayout")
vsLayout.Padding = UDim.new(0, 4)
vsLayout.SortOrder = Enum.SortOrder.LayoutOrder
vsLayout.Parent = vsRows
local vsQuote = UI.text(vs, "", UDim2.new(1, -32, 0, 30), { pos = UDim2.fromOffset(16, 176), align = Enum.TextXAlignment.Left, stroke = 1.5, textSize = 14 })
vsQuote.Font = Enum.Font.FredokaOne

-- RESTOCK / LUCKY RESTOCK: a big glossy button with an icon, a title, a line and a dark Robux chip
local function restockButton(y: number, color: Color3, title: string, line: string, productKey: string, lucky: boolean): TextButton
	local p = Config.PRODUCTS[productKey]
	local b = UI.button(holder, "", color, UDim2.fromOffset(360, 74), function()
		State.fire("Prompt", "product", productKey)
	end, { pos = UDim2.fromOffset(40, y), name = productKey })
	local z = b.ZIndex + 1
	if lucky then
		UI.icon(b, "clover", 52, UDim2.fromOffset(10, 10)).ZIndex = z
	else
		local ring = UI.frame({ size = UDim2.fromOffset(40, 40), pos = UDim2.fromOffset(16, 16), color = Color3.new(1, 1, 1), parent = b, radius = 999, outline = 5, name = "Ring" })
		ring.BackgroundTransparency = 1
		ring.ZIndex = z
		local s = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		s.Color = Color3.new(1, 1, 1)
		local head = UI.frame({ size = UDim2.fromOffset(14, 14), pos = UDim2.fromOffset(30, 4), color = Color3.new(1, 1, 1), parent = b, radius = 2, outline = 0, name = "Arrow" })
		head.Rotation = 45
		head.ZIndex = z
	end
	UI.text(b, title, UDim2.fromOffset(if lucky then 132 else 190, 30), { pos = UDim2.fromOffset(72, 9), align = Enum.TextXAlignment.Left, stroke = 3 }).ZIndex = z
	UI.text(b, line, UDim2.fromOffset(200, 18), { pos = UDim2.fromOffset(72, 42), align = Enum.TextXAlignment.Left, stroke = 1.5 }).ZIndex = z
	if lucky then
		local tagBox = UI.frame({ size = UDim2.fromOffset(62, 24), pos = UDim2.fromOffset(206, 12), color = Color3.new(1, 1, 1), parent = b, radius = 13, outline = 2, name = "Luck" })
		tagBox.Rotation = -6
		tagBox.ZIndex = z
		local t = UI.text(tagBox, "x3 LUCK", UDim2.new(1, -6, 1, -4), { pos = UDim2.fromOffset(3, 2), color = Color3.fromRGB(40, 120, 40), stroke = 0 })
		t.ZIndex = z + 1
	end
	local chip = UI.frame({ size = UDim2.fromOffset(78, 44), pos = UDim2.new(1, -10, 0.5, -3), anchor = Vector2.new(1, 0.5), color = UI.shade(color, 0.45), parent = b, radius = 12, outline = 2, name = "Price" })
	chip.ZIndex = z
	UI.icon(chip, "robux", 24, UDim2.fromOffset(8, 10)).ZIndex = z + 1
	UI.text(chip, tostring(if p then p.robux else 0), UDim2.new(1, -40, 1, -12), { pos = UDim2.fromOffset(36, 6), stroke = 2 }).ZIndex = z + 1
	return b
end
restockButton(338, Color3.fromRGB(50, 140, 245), "RESTOCK", "Deal new cards now", "ClassRestock", false)
restockButton(422, Color3.fromRGB(70, 190, 80), "LUCKY RESTOCK", "Rare cards 3x more likely", "ClassLuckyRestock", true)
UI.text(holder, "Every card shows its chance to be dealt", UDim2.fromOffset(300, 18), { pos = UDim2.fromOffset(372, 520), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(200, 190, 225), stroke = 1 })

-- the picked class's big card (right)
local cardGlow = Instance.new("ImageLabel")
cardGlow.Name = "CardGlow"
cardGlow.BackgroundTransparency = 1
cardGlow.Image = Tex.Glow
cardGlow.ImageTransparency = 0.15
cardGlow.Size = UDim2.fromOffset(520, 680)
cardGlow.Position = UDim2.fromOffset(1092, 286)
cardGlow.AnchorPoint = Vector2.new(0.5, 0.5)
cardGlow.Parent = holder
TweenService:Create(cardGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.45, Size = UDim2.fromOffset(480, 640) }):Play()
local detail = UI.frame({ size = UDim2.fromOffset(310, 460), pos = UDim2.fromOffset(1248, 56), anchor = Vector2.new(1, 0), color = W.blue, parent = holder, radius = 20, outline = 6, name = "Detail" })
local detailStroke = detail:FindFirstChildOfClass("UIStroke") :: UIStroke
local detailGrad = UI.gradient(detail, W.blue)
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
header.BackgroundTransparency = 0.82
local detName = UI.text(header, "", UDim2.new(1, -16, 0, 40), { pos = UDim2.fromOffset(8, 2), stroke = 3.5 })
local starRow = Instance.new("Frame")
starRow.BackgroundTransparency = 1
starRow.Size = UDim2.fromOffset(196, 26)
starRow.Position = UDim2.new(0.5, 0, 0, 44)
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
local artPanel = UI.frame({ size = UDim2.new(1, -36, 0, 122), pos = UDim2.fromOffset(18, 106), color = Color3.fromRGB(120, 180, 255), parent = detail, radius = 14, outline = 4, name = "Art" })
artPanel.ClipsDescendants = true
;(artPanel:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(30, 20, 50)
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
local rarityPill = UI.frame({ size = UDim2.fromOffset(150, 30), pos = UDim2.new(0.5, 0, 0, 212), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(30, 20, 50), parent = detail, radius = 15, outline = 3, name = "Rarity" })
;(rarityPill:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.new(1, 1, 1)
local rarityText = UI.text(rarityPill, "", UDim2.new(1, -10, 1, -6), { pos = UDim2.fromOffset(5, 3), stroke = 1.5 })
local detState = UI.text(detail, "", UDim2.new(1, -24, 0, 0), { pos = UDim2.fromOffset(12, 0), stroke = 1.5 })
detState.Visible = false
local perkRows = Instance.new("Frame")
perkRows.BackgroundTransparency = 1
perkRows.Size = UDim2.new(1, -36, 0, 90)
perkRows.Position = UDim2.fromOffset(18, 250)
perkRows.Parent = detail
local perkLayout = Instance.new("UIListLayout")
perkLayout.Padding = UDim.new(0, 4)
perkLayout.SortOrder = Enum.SortOrder.LayoutOrder
perkLayout.Parent = perkRows
local detQuote = UI.text(detail, "", UDim2.new(1, -36, 0, 30), { pos = UDim2.fromOffset(18, 340), stroke = 1.5, textSize = 13 })
local detOdds = UI.text(detail, "", UDim2.new(1, -28, 0, 18), { pos = UDim2.fromOffset(14, 370), stroke = 1.5, textSize = 13 })
local gemBtn = UI.button(detail, "BUY", C.purple, UDim2.fromOffset(134, 52), function() end, { pos = UDim2.new(0, 16, 1, -16), anchor = Vector2.new(0, 1), name = "GemBuy" })
local robuxBtn = UI.button(detail, "R$ 0", C.green, UDim2.fromOffset(134, 52), function() end, { pos = UDim2.new(1, -16, 1, -16), anchor = Vector2.new(1, 1), name = "RobuxBuy" })
local gemIcon = UI.icon(gemBtn, "gem", 32, UDim2.new(0, 10, 0.5, -3), Vector2.new(0, 0.5))
local robuxIcon = UI.icon(robuxBtn, "robux", 28, UDim2.new(0, 12, 0.5, -3), Vector2.new(0, 0.5))
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
;(innerFrame:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(255, 245, 230)
;(innerFrame:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0.3
for _, p in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
	local dia = UI.frame({ size = UDim2.fromOffset(13, 13), pos = UDim2.fromScale(p[1], p[2]), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(255, 226, 160), parent = innerFrame, radius = 2, outline = 2 })
	dia.Rotation = 45
end

-- STOCK / OWNED tabs and the card carousel
local tab = "stock"
local stockTab = UI.button(holder, "STOCK", C.orange, UDim2.fromOffset(140, 46), function() end, { pos = UDim2.fromOffset(40, 506), name = "StockTab" })
local ownedTab = UI.button(holder, "OWNED", Color3.fromRGB(110, 70, 190), UDim2.fromOffset(180, 46), function() end, { pos = UDim2.fromOffset(190, 506), name = "OwnedTab" })
UI.icon(stockTab, "moon", 38, UDim2.new(0, 2, 0.5, -3), Vector2.new(0, 0.5))
;(stockTab:FindFirstChild("Label") :: TextLabel).Position = UDim2.fromOffset(22, 3)
local ownedTick = UI.frame({ size = UDim2.fromOffset(28, 28), pos = UDim2.new(0, 8, 0.5, -3), anchor = Vector2.new(0, 0.5), color = Color3.fromRGB(60, 200, 90), parent = ownedTab, radius = 999, outline = 2, name = "Tick" })
;(ownedTick:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.new(1, 1, 1)
for _, b in { { 5, 11, 8, 4, 45 }, { 10, 6, 14, 4, -50 } } do
	local bar = UI.frame({ size = UDim2.fromOffset(b[3], b[4]), pos = UDim2.fromOffset(b[1] + 2, b[2] + 5), color = Color3.new(1, 1, 1), parent = ownedTick, radius = 2, outline = 0 })
	bar.Rotation = b[5]
end
local ownedChip = UI.frame({ size = UDim2.fromOffset(30, 28), pos = UDim2.new(1, -8, 0.5, -3), anchor = Vector2.new(1, 0.5), color = Color3.fromRGB(30, 20, 50), parent = ownedTab, radius = 8, outline = 0, name = "Count" })
local ownedCount = UI.text(ownedChip, "1", UDim2.new(1, -6, 1, -6), { pos = UDim2.fromOffset(3, 3), stroke = 1.5 })
local row = Instance.new("ScrollingFrame")
row.Name = "Cards"
row.BackgroundTransparency = 1
row.BorderSizePixel = 0
row.Size = UDim2.fromOffset(1220, 170)
row.Position = UDim2.fromOffset(30, 552)
row.ScrollBarThickness = 6
row.ScrollingDirection = Enum.ScrollingDirection.X
row.AutomaticCanvasSize = Enum.AutomaticSize.X
row.CanvasSize = UDim2.new()
row.ClipsDescendants = false
row.Parent = holder
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 8)
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
	if picked then
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.Image = Tex.Glow
		glow.ImageColor3 = rc
		glow.ImageTransparency = 0.2
		glow.Size = UDim2.fromOffset(200, 240)
		glow.Position = UDim2.fromOffset(56, 86)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Parent = slot
	end
	local b = Instance.new("TextButton")
	b.Name = "Card"
	b.Text = ""
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = UDim2.fromOffset(56, 16) -- room above for the chance chip
	b.Size = UDim2.fromOffset(104, 140)
	b.BackgroundColor3 = rc
	b.ClipsDescendants = false
	UI.corner(b, 14)
	UI.stroke(b, if picked then 4 else 3, if picked then Color3.new(1, 1, 1) else UI.shade(rc, 0.35))
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(UI.shade(rc, 0.85), UI.shade(rc, 0.38))
	bg.Rotation = 90
	bg.Parent = b
	-- the card's picture, full bleed (Config.ICONS.scene_<Id>)
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundColor3 = UI.shade(rc, 1.2)
	art.Image = Config.ICONS["scene_" .. c.id] or ""
	art.ScaleType = Enum.ScaleType.Crop
	art.Size = UDim2.new(1, -10, 0, 74)
	art.Position = UDim2.fromOffset(5, 5)
	UI.corner(art, 10)
	art.Parent = b
	local nameBar = UI.frame({ size = UDim2.new(1, -12, 0, 24), pos = UDim2.fromOffset(6, 82), color = Color3.fromRGB(20, 14, 36), parent = b, radius = 6, outline = 0, name = "NameBar" })
	nameBar.BackgroundTransparency = 0.35
	UI.text(nameBar, c.name, UDim2.new(1, -6, 1, -4), { pos = UDim2.fromOffset(3, 2), stroke = 1.5 })
	local equipped = owned and d.class == c.id
	local state = if owned then (if equipped then "EQUIPPED" else "YOURS") elseif c.gems <= 0 then "FREE" elseif inStock then Format.short(c.gems) else "SOLD OUT"
	local pillColor = if equipped then Color3.fromRGB(255, 196, 40) elseif owned then C.green elseif inStock then Color3.fromRGB(80, 200, 70) else Color3.fromRGB(44, 38, 60)
	local pill = UI.frame({ size = UDim2.new(1, -12, 0, 26), pos = UDim2.new(0.5, 0, 1, -6), anchor = Vector2.new(0.5, 1), color = pillColor, parent = b, radius = 8, outline = 2 })
	UI.gradient(pill, pillColor)
	local gemPrice = not owned and inStock and c.gems > 0
	if gemPrice then
		UI.icon(pill, "gem", 20, UDim2.fromOffset(8, 3))
	end
	UI.text(pill, state, UDim2.new(1, if gemPrice then -36 else -8, 1, -6), { pos = UDim2.fromOffset(if gemPrice then 30 else 4, 3), stroke = 1.5 })
	local chance = Config.CLASS_CHANCE[c.id]
	if chance and chance > 0 then
		local chip = UI.frame({ size = UDim2.fromOffset(48, 22), pos = UDim2.new(1, 6, 0, -10), anchor = Vector2.new(1, 0), color = Color3.fromRGB(22, 14, 40), parent = b, radius = 7, outline = 2, name = "Chance" })
		UI.text(chip, pctText(chance), UDim2.new(1, -4, 1, -4), { pos = UDim2.fromOffset(2, 2), stroke = 1 })
	end
	if not inStock and not owned and tab == "stock" then
		local shade = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(10, 6, 20), parent = b, radius = 14, outline = 0, name = "Dim" })
		shade.BackgroundTransparency = 0.45
	end
	-- the face-down side, shown while the cards are being dealt
	local back = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(90, 50, 170), parent = b, radius = 14, outline = 3, name = "Back" })
	UI.gradient(back, Color3.fromRGB(95, 55, 175))
	local q = Instance.new("ImageLabel")
	q.BackgroundTransparency = 1
	q.Image = Tex.Star4
	q.ImageColor3 = Color3.fromRGB(255, 210, 250)
	q.Size = UDim2.fromOffset(56, 56)
	q.Position = UDim2.fromScale(0.5, 0.5)
	q.AnchorPoint = Vector2.new(0.5, 0.5)
	q.Parent = back
	back.Visible = false
	if picked then
		local grow = Instance.new("UIScale")
		grow.Scale = 1.06
		grow.Parent = b
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

-- Turn the cards over one at a time, left to right ("DEALING").
local function dealAnimation(ids: { string })
	local list = {}
	for _, c in Config.CLASSES do
		local b = cardsByClass[c.id]
		if b and table.find(ids, c.id) then
			table.insert(list, b)
		end
	end
	for _, b in list do
		(b:FindFirstChild("Back") :: GuiObject).Visible = true
	end
	timerText.Text = "DEALING"
	for i, b in list do
		task.delay(0.25 + (i - 1) * 0.15, function()
			if not b.Parent then
				return
			end
			local full = b.Size
			local close = TweenService:Create(b, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(0, full.Y.Offset) })
			close:Play()
			close.Completed:Wait()
			local back = b:FindFirstChild("Back") :: GuiObject?
			if back then
				back.Visible = false
			end
			Sound.play("click")
			TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full }):Play()
		end)
	end
end

-- Full-screen reveal: white flash, a dark overlay in the rarity colour, the card in front of turning rays.
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
	local tint = UI.frame({ size = UDim2.fromScale(4, 4), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = UI.shade(rc, 0.3), parent = root, radius = 0, outline = 0, name = "Tint" })
	tint.BackgroundTransparency = 0.15
	local rays = Instance.new("Frame")
	rays.BackgroundTransparency = 1
	rays.Size = UDim2.fromOffset(620, 620)
	rays.Position = UDim2.fromScale(0.5, 0.46)
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Parent = root
	for i = 0, 11 do
		local r = Instance.new("Frame")
		r.BorderSizePixel = 0
		r.BackgroundColor3 = UI.shade(rc, 1.4)
		r.BackgroundTransparency = 0.4
		r.Size = UDim2.new(0, 46, 1, 0)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Rotation = i * 15
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Rotation = 90
		g.Parent = r
		r.Parent = rays
	end
	TweenService:Create(rays, TweenInfo.new(10, Enum.EasingStyle.Linear), { Rotation = 360 }):Play()
	local halo = Instance.new("ImageLabel")
	halo.BackgroundTransparency = 1
	halo.Image = Tex.Glow
	halo.ImageColor3 = if c.rarity == "Secret" then Color3.fromRGB(220, 120, 255) else UI.shade(rc, 1.3)
	halo.Size = UDim2.fromOffset(520, 620)
	halo.Position = UDim2.fromScale(0.5, 0.46)
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Parent = root
	local big = UI.frame({ size = UDim2.fromOffset(240, 310), pos = UDim2.fromScale(0.5, 0.46), anchor = Vector2.new(0.5, 0.5), color = rc, parent = root, radius = 18, outline = 5, name = "Card" })
	;(big:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.new(1, 1, 1)
	if c.rarity == "Secret" then
		big.BackgroundColor3 = Color3.new(1, 1, 1)
		local pg = Instance.new("UIGradient")
		pg.Color = PRISM
		pg.Rotation = 45
		pg.Parent = big
	else
		UI.gradient(big, rc)
	end
	UI.text(big, c.name, UDim2.new(1, -20, 0, 50), { pos = UDim2.fromOffset(10, 12), stroke = 3 })
	UI.icon(big, CLASS_ART[c.id], 190, UDim2.fromScale(0.5, 0.58), Vector2.new(0.5, 0.5))
	UI.text(root, string.upper(c.name), UDim2.fromOffset(700, 66), { pos = UDim2.new(0.5, 0, 0.46, 170), anchor = Vector2.new(0.5, 0), stroke = 5 })
	UI.text(root, line, UDim2.fromOffset(600, 42), { pos = UDim2.new(0.5, 0, 0.46, 236), anchor = Vector2.new(0.5, 0), color = UI.shade(rc, 1.35), stroke = 3.5 })
	local flash = UI.frame({ size = UDim2.fromScale(4, 4), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.new(1, 1, 1), parent = root, radius = 0, outline = 0, name = "Flash" })
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	UI.bounce(big)
	Sound.play("reveal")
	if confetti then
		Confetti.burst(90)
	end
	task.delay(2.3, function()
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
				TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
			end
		end
		task.wait(0.4)
		root:Destroy()
	end)
end

local function setTab(t: string)
	tab = t
	UI.setButton(stockTab, "STOCK", if t == "stock" then C.orange else Color3.fromRGB(110, 70, 190))
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
	UI.setButton(ownedTab, "OWNED", if tab == "owned" then C.orange else Color3.fromRGB(110, 70, 190))
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
		if best then
			selected = best.id
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
		local ph = UI.frame({ size = UDim2.fromOffset(104, 140), pos = UDim2.fromOffset(56, 16), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(30, 20, 56), parent = slot, radius = 14, outline = 3, name = "Empty" })
		ph.BackgroundTransparency = 0.15
		;(ph:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(100, 70, 160)
		local plusRing = UI.frame({ size = UDim2.fromOffset(38, 38), pos = UDim2.fromScale(0.5, 0.3), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(50, 34, 90), parent = ph, radius = 999, outline = 2, name = "Plus" })
		;(plusRing:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(190, 170, 230)
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
	pic.Image = Config.ICONS["scene_" .. c.id] or ""
	pic.ScaleType = Enum.ScaleType.Crop
	pic.Size = UDim2.fromScale(1, 1)
	UI.corner(pic, 12)
	pic.Parent = artHolder
	artPanel.BackgroundColor3 = UI.shade(rc, 1.25)
	artGlow.ImageColor3 = UI.shade(rc, 1.4)
	cardGlow.ImageColor3 = rc
	for _, s in stripes do
		s.Visible = STRIPED[c.rarity] == true
	end
	detQuote.Text = '"' .. (QUOTES[c.id] or "") .. '"'
	ClassRoom.setAura(rc)
	UI.clear(perkRows)
	perkLayout.Parent = perkRows
	local n = 0
	for _, s in STATS do
		local v = (c :: any)[s.key]
		if v and v ~= 0 and n < 3 then -- the top three (VS YOUR CLASS compares them all)
			n += 1
			local r = UI.frame({ size = UDim2.new(1, 0, 0, 26), color = Color3.fromRGB(20, 14, 34), parent = perkRows, radius = 8, outline = 0, name = "Perk" })
			r.BackgroundTransparency = 0.45
			r.LayoutOrder = n
			UI.icon(r, STAT_ICON[s.key], 22, UDim2.fromOffset(4, 2))
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
	if owned then
		gemBtn.Size = UDim2.new(1, -32, 0, 54)
		UI.setButton(gemBtn, if d.class == c.id then "EQUIPPED" else "EQUIP", Color3.fromRGB(40, 180, 90))
	else
		gemBtn.Size = if product then UDim2.fromOffset(134, 52) else UDim2.new(1, -32, 0, 54)
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
			if shown > 3 then
				break
			end
			local better = (b or 0) > (a or 0)
			local r = UI.frame({ size = UDim2.new(1, 0, 0, 32), color = Color3.fromRGB(16, 10, 32), parent = vsRows, radius = 8, outline = 0, name = "Row" })
			r.BackgroundTransparency = 0.25
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
		dealAnimation(stock)
		if best then
			local shown = best
			task.delay(0.25 + #stock * 0.15 + 0.2, function()
				reveal(shown, string.upper(shown.rarity) .. " IN STOCK!", false)
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
					reveal(nc, "IS YOURS!", true)
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
			if timerText.Text ~= "DEALING" or left < Config.STOCK_WINDOW - 2 then
				timerText.Text = Format.clock(left)
			end
			timerFill.Size = UDim2.fromScale(math.clamp(left / Config.STOCK_WINDOW, 0, 1), 1)
			local key = Config.stockWindow() .. ":" .. table.concat((currentStock(State.data)), ",")
			if key ~= lastDealKey then
				ClassDeal.refresh()
			end
		end
	end
end)

-- Windows refreshes the open window on every data update (a restock, a purchase); the avatar only reloads on open
UI.register("Classes", { frame = holder, refresh = ClassDeal.refresh, pop = { row } })
-- the 3D class room behind the window while it's open (the HUD steps aside, like Chop A Forest's full screen)
UI.onWindowChanged.Event:Connect(function(name)
	local hud = UI.gui:FindFirstChild("Hud")
	if hud and hud:IsA("GuiObject") then
		hud.Visible = name ~= "Classes"
	end
	if name == "Classes" then
		local d = State.data
		local c = Config.class(selected or (d and d.class) or Config.DEFAULT_CLASS)
		ClassRoom.show(if c then Config.RARITY_COLORS[c.rarity] else nil)
	else
		ClassRoom.hide()
	end
end)

return ClassDeal
