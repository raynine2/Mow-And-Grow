-- SHOP window (R): hanging wooden category signs on the left (Featured, Passes, Tools, Mowers, Gems), the gem
-- counter with a green + under them, and big dark banner cards on the right with tags, an art area and green
-- Robux buttons. Buying goes through the usual remotes: State.fire("Prompt", "product"/"pass", key) for Robux,
-- State.fire("Buy", "mower", id) for gem mowers. Nothing here has a random result.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local ShopWindow = {}
local C = UI.colors
local W = UI.wood

local CATEGORIES = {
	{ id = "Featured", icon = "star" },
	{ id = "Passes", icon = "news" },
	{ id = "Tools", icon = "scissors" },
	{ id = "Mowers", icon = "pushmower" },
	{ id = "Gems", icon = "gem" },
}
local PASS_ICON = { DoubleCoins = "coin", DoubleGems = "gem", BigBag = "backpack", VIP = "star" }
local PASS_COLOR = {
	DoubleCoins = Color3.fromRGB(230, 160, 30),
	DoubleGems = Color3.fromRGB(60, 150, 240),
	BigBag = Color3.fromRGB(150, 100, 60),
	VIP = Color3.fromRGB(170, 80, 220),
}
local GREEN = Color3.fromRGB(70, 200, 80)
local BLUE = Color3.fromRGB(60, 150, 240)
local TAG_COLOR = { EXCLUSIVE = Color3.fromRGB(255, 140, 30), NEW = Color3.fromRGB(70, 200, 80), OWNED = Color3.fromRGB(120, 120, 130), BEST = Color3.fromRGB(230, 60, 80) }

type Price = { text: string, icon: string?, enabled: boolean, onClick: () -> (), gift: boolean? }
type Banner = { title: string, desc: string, icon: string, color: Color3, tags: { string }?, prices: { Price } }

-------------------------------------------------------------------------------------------------------------
-- drawing
-------------------------------------------------------------------------------------------------------------
local function pill(parent: Instance, text: string, color: Color3, pos: UDim2, width: number): Frame
	local p = UI.frame({ size = UDim2.fromOffset(width, 30), pos = pos, color = color, parent = parent, radius = 15, outline = 3, name = "Pill" })
	UI.gradient(p, color)
	UI.text(p, text, UDim2.new(1, -14, 1, -8), { pos = UDim2.fromOffset(7, 4), stroke = 2 })
	return p
end

-- A green price button with an icon on the left (the R$ hex for Robux), grey when it can't be bought.
local function priceButton(parent: Instance, p: Price, pos: UDim2): TextButton
	local b = UI.button(parent, p.text, if p.enabled then GREEN else W.grey, UDim2.fromOffset(200, 56), function()
		if p.enabled then
			p.onClick()
		end
	end, { pos = pos, name = "Price" })
	if p.icon then
		local label = b:FindFirstChild("Label") :: TextLabel
		label.Size = UDim2.new(1, -60, 1, -14)
		label.Position = UDim2.fromOffset(52, 4)
		UI.icon(b, p.icon, 38, UDim2.fromOffset(10, 6))
	end
	UI.raise(b, 4)
	return b
end

local function giftButton(parent: Instance, pos: UDim2)
	local b = UI.button(parent, "", BLUE, UDim2.fromOffset(56, 56), function()
		UI.toast("Gifting is coming soon!", "yellow")
	end, { pos = pos, name = "Gift" })
	UI.icon(b, "gift", 40, UDim2.fromOffset(8, 5))
	UI.raise(b, 4)
end

-- A big dark banner card: title, tag pills, description, price row, and the item's art on the right.
local function banner(list: Instance, order: number, o: Banner)
	local base = UI.shade(o.color, 0.42)
	local card = UI.frame({ size = UDim2.new(1, -16, 0, 196), color = base, parent = list, radius = 18, outline = 4, name = "Banner" })
	;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(30, 20, 14)
	card.LayoutOrder = order
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(o.color, 0.62), UI.shade(o.color, 0.22))
	g.Rotation = 20
	g.Parent = card
	-- the art area: a glow and the big icon
	local art = UI.frame({ size = UDim2.fromOffset(200, 164), pos = UDim2.new(1, -16, 0.5, 0), anchor = Vector2.new(1, 0.5), color = UI.shade(o.color, 0.9), transparency = 0.55, parent = card, radius = 999, outline = 0, name = "Art" })
	UI.icon(art, o.icon, 130, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.raise(art, 3)
	UI.text(card, string.upper(o.title), UDim2.new(1, -260, 0, 50), { pos = UDim2.fromOffset(20, 12), align = Enum.TextXAlignment.Left, stroke = 4 })
	local x = 20
	for _, tag in o.tags or {} do
		local width = 26 + #tag * 13
		pill(card, tag, TAG_COLOR[tag] or C.green, UDim2.fromOffset(x, 66), width)
		x += width + 8
	end
	UI.text(card, o.desc, UDim2.new(1, -260, 0, 24), { pos = UDim2.fromOffset(20, if o.tags and #o.tags > 0 then 102 else 70), align = Enum.TextXAlignment.Left, color = W.cream, stroke = 2 })
	x = 20
	for _, p in o.prices do
		priceButton(card, p, UDim2.new(0, x, 1, -70))
		x += 210
		if p.gift then
			giftButton(card, UDim2.new(0, x, 1, -70))
			x += 66
		end
	end
	return card
end

-------------------------------------------------------------------------------------------------------------
-- what each category sells
-------------------------------------------------------------------------------------------------------------
local function robux(key: string, owned: boolean?): Price
	local p = Config.PRODUCTS[key]
	return {
		text = if owned then "OWNED" else Format.commas(p.robux),
		icon = if owned then nil else "robux",
		enabled = not owned,
		gift = not owned,
		onClick = function()
			State.fire("Prompt", "product", key)
		end,
	}
end

local function passBanner(d, key: string): Banner
	local p = Config.PASSES[key]
	local owned = d.passes[key] == true
	return {
		title = p.name,
		desc = p.desc,
		icon = PASS_ICON[key] or "star",
		color = PASS_COLOR[key] or C.green,
		tags = if owned then { "OWNED" } else { "FOREVER" },
		prices = {
			{
				text = if owned then "OWNED" else Format.commas(p.robux),
				icon = if owned then nil else "robux",
				enabled = not owned,
				gift = not owned,
				onClick = function()
					State.fire("Prompt", "pass", key)
				end,
			},
		},
	}
end

local function classBanners(d, out: { Banner })
	for _, key in Config.PRODUCT_ORDER do
		local p = Config.PRODUCTS[key]
		if p.class and not table.find(d.classes, p.class) then
			local c = Config.class(p.class) :: any
			table.insert(out, {
				title = p.name,
				desc = if c then (c.rarity .. " class - yours forever") else "Yours forever",
				icon = "clover",
				color = if c and Config.RARITY_COLORS[c.rarity] then Config.RARITY_COLORS[c.rarity] else Color3.fromRGB(230, 120, 40),
				tags = { "EXCLUSIVE" },
				prices = { robux(key) },
			})
		end
	end
end

local function mowerBanner(d, m): Banner?
	local owned = table.find(d.mowers, m.id) ~= nil
	local stats = ("Power %s  -  Speed %d  -  Fuel %d"):format(Format.short(m.damage), m.speed, m.fuel)
	if m.currency == "gems" then
		return {
			title = m.name,
			desc = stats,
			icon = "pushmower",
			color = m.color,
			tags = if owned then { "OWNED" } else nil,
			prices = {
				{
					text = if owned then "OWNED" else Format.commas(m.price),
					icon = if owned then nil else "gem",
					enabled = not owned and d.gems >= m.price,
					onClick = function()
						State.fire("Buy", "mower", m.id)
					end,
				},
			},
		}
	elseif m.currency == "robux" then
		return { title = m.name, desc = stats, icon = "pushmower", color = m.color, tags = if owned then { "OWNED" } else { "NEW" }, prices = { robux(m.product, owned) } }
	elseif m.currency == "trial" and State.isRun() then
		return { title = m.name, desc = stats .. "  -  this run only", icon = "pushmower", color = m.color, tags = { "BEST" }, prices = { robux(m.product) } }
	end
	return nil
end

local CONTENT: { [string]: (any) -> { Banner } } = {}
CONTENT.Featured = function(d)
	local out = {}
	classBanners(d, out)
	local rocket = Config.mower("RocketMower")
	if rocket and not table.find(d.mowers, rocket.id) then
		table.insert(out, mowerBanner(d, rocket) :: Banner)
	end
	if not d.passes.VIP then
		table.insert(out, passBanner(d, "VIP"))
	end
	return out
end
CONTENT.Passes = function(d)
	local out = {}
	for _, key in Config.PASS_ORDER do
		table.insert(out, passBanner(d, key))
	end
	return out
end
CONTENT.Tools = function(d)
	local out = {}
	local trial = Config.mower("TrialMower")
	if trial and State.isRun() then
		table.insert(out, mowerBanner(d, trial) :: Banner)
	end
	table.insert(out, {
		title = "The Tool Shop",
		desc = "Scissors, sickles and mowers are sold for coins at the Tool Shop cabin in every run.",
		icon = "scissors",
		color = Color3.fromRGB(150, 100, 60),
		prices = {},
	})
	return out
end
CONTENT.Mowers = function(d)
	local out = {}
	for _, m in Config.MOWERS do
		local b = mowerBanner(d, m)
		if b then
			table.insert(out, b)
		end
	end
	return out
end
CONTENT.Gems = function(_d)
	local out = {}
	for i, key in { "Gems150", "Gems500", "Gems1500", "Gems5000" } do
		local p = Config.PRODUCTS[key]
		table.insert(out, {
			title = p.name,
			desc = "For classes, perks and mowers",
			icon = "gem",
			color = Color3.fromRGB(40, 140 + i * 15, 230),
			tags = if i == 4 then { "BEST" } else nil,
			prices = { robux(key) },
		})
	end
	return out
end

-------------------------------------------------------------------------------------------------------------
-- the window
-------------------------------------------------------------------------------------------------------------
-- A wooden sign hanging from the rope, with two pegs; the open category is orange.
local function sign(parent: Instance, i: number, cat, active: boolean, onClick: () -> ()): TextButton
	local color = if active then W.tabOn else W.tabWood
	local b = Instance.new("TextButton")
	b.Name = "Sign_" .. cat.id
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Size = UDim2.fromOffset(200, 62)
	b.Position = UDim2.fromOffset(18, 28 + (i - 1) * 84)
	b.Rotation = if i % 2 == 0 then 1.5 else -1.5
	UI.corner(b, 12)
	UI.stroke(b, 3, if active then Color3.fromRGB(150, 60, 10) else W.frameEdge)
	UI.grain(b, color, 4)
	for _, x in { 38, 162 } do
		UI.frame({ size = UDim2.fromOffset(12, 12), pos = UDim2.fromOffset(x - 6, 6), color = Color3.fromRGB(70, 44, 24), parent = b, radius = 999, outline = 0, name = "Peg" })
	end
	UI.icon(b, cat.icon, 42, UDim2.fromOffset(12, 12))
	UI.text(b, string.upper(cat.id), UDim2.new(1, -72, 1, -22), { pos = UDim2.fromOffset(60, 12), color = if active then Color3.new(1, 1, 1) else W.cream, stroke = 2.5 })
	UI.raise(b, 4)
	b.MouseButton1Click:Connect(function()
		UI.bounce(b)
		onClick()
	end)
	b.Parent = parent
	return b
end

local function ropes(parent: Instance)
	for _, x in { 56, 180 } do
		local r = UI.frame({ size = UDim2.fromOffset(5, 28 + 4 * 84 + 20), pos = UDim2.fromOffset(x, 0), color = Color3.fromRGB(196, 160, 100), parent = parent, radius = 2, outline = 2, name = "Rope" })
		;(r:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(110, 80, 40)
		r.ZIndex = 2
	end
end

function ShopWindow.build()
	local w = UI.window("Store", "Shop", nil, { size = Vector2.new(1100, 620) })
	w.list.Visible = false
	local panel = w.panel :: Frame
	local current = "Featured"

	local signs = Instance.new("Frame")
	signs.Name = "Signs"
	signs.BackgroundTransparency = 1
	signs.Size = UDim2.fromOffset(236, 460)
	signs.Parent = panel
	ropes(signs)

	-- gems + a green plus that jumps to the GEMS signs
	local gemBox = UI.section(panel, UDim2.fromOffset(210, 64), UDim2.fromOffset(16, 486), Color3.fromRGB(60, 36, 20))
	UI.icon(gemBox, "gem", 42, UDim2.fromOffset(10, 11))
	local gemText = UI.text(gemBox, "0", UDim2.new(1, -124, 1, -20), { pos = UDim2.fromOffset(58, 10), align = Enum.TextXAlignment.Left, stroke = 2.5 })

	local list = Instance.new("ScrollingFrame")
	list.Name = "Banners"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromOffset(1060 - 252 - 12, 580 - 24)
	list.Position = UDim2.fromOffset(252, 12)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = W.frameEdge
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 3
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = list

	w.refresh = function()
		local d = State.data
		for _, c in signs:GetChildren() do
			if c.Name:match("^Sign_") then
				c:Destroy()
			end
		end
		for i, cat in CATEGORIES do
			sign(signs, i, cat, cat.id == current, function()
				current = cat.id
				list.CanvasPosition = Vector2.zero
				w.refresh()
			end)
		end
		UI.clear(list)
		if not d then
			return
		end
		gemText.Text = Format.commas(d.gems or 0)
		local items = CONTENT[current](d)
		for i, b in items do
			banner(list, i, b)
		end
		if #items == 0 then
			UI.text(list, "You own everything here. Thank you!", UDim2.new(1, -40, 0, 40), { color = W.brownText, stroke = 0 })
		end
	end
	UI.button(gemBox, "+", GREEN, UDim2.fromOffset(48, 48), function()
		current = "Gems"
		w.refresh()
	end, { pos = UDim2.new(1, -8, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "Plus" })
	return w
end

return ShopWindow
