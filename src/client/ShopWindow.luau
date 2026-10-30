-- SHOP window (R): a stack of seed packets on the left (Featured, Passes, Tools, Mowers, Gems), the gem counter
-- plate with a green + under them, and wood-rimmed banner cards on the right (mowed-lawn stripes, ribbon tag, the
-- item's picture bobbing on a glow, shine sweeps, sparkles on the special ones, chunky green price buttons). Now
-- and then a little mower drives along the grass at the bottom of the board.
-- Buying goes through the usual remotes: State.fire("Prompt", "product"/"pass", key) for Robux, State.fire("Buy",
-- "mower", id) for gem mowers. Nothing here has a random result.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)

local ShopWindow = {}
local C = UI.colors
local W = UI.wood

local CATEGORIES = {
	{ id = "Featured", icon = "star" },
	{ id = "Passes", icon = "ticket" },
	{ id = "Tools", icon = "scissors" },
	{ id = "Mowers", icon = "pushmower" },
	{ id = "Gems", icon = "gem" },
}
-- the ForgeGUI pictures (assets/icons): a pass, a mower, a gem pack
local PASS_ICON = { BigBag = "sack", DoubleCoins = "x2coins", DoubleClippings = "x2clip", DoubleGems = "x2gems", VIP = "crown", HatchLuck = "hatchluck", SuperHatchLuck = "superhatch" }
local MOWER_ICON = { RustyRider = "mower_rusty", TurboTractor = "mower_tractor", GoldenZeroTurn = "mower_zeroturn", MonsterMulcher = "mower_mulcher", TrialMower = "mower_trial", RocketMower = "mower_rocket" }
local GEM_ICON = { "gempile", "gempouch", "gemchest", "gemmountain" }
local GREEN = Color3.fromRGB(70, 200, 80)
local BLUE = Color3.fromRGB(60, 150, 240)
local TAG_COLOR = {
	EXCLUSIVE = Color3.fromRGB(255, 140, 30),
	NEW = Color3.fromRGB(70, 200, 80),
	OWNED = Color3.fromRGB(150, 150, 160),
	BEST = Color3.fromRGB(230, 60, 80),
	FOREVER = Color3.fromRGB(80, 170, 255),
	POPULAR = Color3.fromRGB(255, 120, 170),
	SOON = Color3.fromRGB(60, 200, 255), -- (30 Oct: the locked ride-on mowers)
	SUPER = Color3.fromRGB(255, 190, 40),
	["BEST VALUE"] = Color3.fromRGB(230, 60, 80),
}
-- tags that make a banner sparkle
local SHINY = { EXCLUSIVE = true, NEW = true, BEST = true, POPULAR = true, SUPER = true, ["BEST VALUE"] = true }

type Price = { text: string, icon: string?, enabled: boolean, onClick: () -> (), gift: boolean? }
type Banner = { title: string, desc: string, icon: string, color: Color3, tags: { string }?, prices: { Price } }

-- `key` if its picture is uploaded, else `fallback` (a new picture can be waiting for Roblox's check)
local function pic(key: string?, fallback: string): string
	if key and (Config.ICONS[key] or "") ~= "" then
		return key
	end
	return fallback
end

-------------------------------------------------------------------------------------------------------------
-- drawing
-------------------------------------------------------------------------------------------------------------
-- A chunky price button with an icon on the left (the R$ glyph for Robux, a gem for gems), grey when it can't be
-- bought.
local function priceButton(parent: Instance, p: Price, pos: UDim2): TextButton
	local b = UI.button(parent, p.text, if p.enabled then GREEN else W.grey, UDim2.fromOffset(204, 54), function()
		if p.enabled then
			p.onClick()
		else
			Sound.play("denied")
		end
	end, { pos = pos, name = "Price" })
	if p.icon then
		local label = b:FindFirstChild("Label") :: TextLabel
		label.Size = UDim2.new(1, -62, 1, -18)
		label.Position = UDim2.fromOffset(52, 3)
		UI.icon(b, p.icon, 40, UDim2.fromOffset(12, 3))
	end
	UI.raise(b, 4)
	return b
end

local function giftButton(parent: Instance, pos: UDim2)
	local b = UI.button(parent, "", BLUE, UDim2.fromOffset(58, 54), function()
		UI.toast("Gifting is coming soon!", "yellow")
	end, { pos = pos, name = "Gift" })
	UI.icon(b, pic("gift", "gift"), 46, UDim2.new(0.5, 0, 0.5, -4), Vector2.new(0.5, 0.5))
	UI.raise(b, 4)
end

-- A banner card: the ForgeGUI wood-rimmed card with the item's colour inside, its picture floating on a glow on
-- the right, the title, a line about it, the price buttons and a ribbon tag. Rare ones sparkle; all of them shine.
local BANNER = Vector2.new(770, 204)
local function banner(list: Instance, order: number, o: Banner)
	local slot = Instance.new("Frame")
	slot.Name = "Banner"
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(BANNER.X, BANNER.Y)
	slot.LayoutOrder = order
	slot.Parent = list
	local _card, face = Skin.frame(slot, "ui_pcard", BANNER, { name = "Card", boost = 1.25 })
	-- the coloured inside, clipped to the card's rounded window
	local inner = UI.frame({ size = UDim2.fromScale(1, 1), color = o.color, parent = face, radius = 12, outline = 0, name = "Inner" })
	inner.ClipsDescendants = true
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(o.color, 1.2), UI.shade(o.color, 0.5))
	g.Rotation = 20
	g.Parent = inner
	-- freshly mowed stripes across the card, like a lawn after the mower went up and down it
	Skin.stripes(inner)
	for i, d in { 250, 180 } do
		local glow = UI.frame({ size = UDim2.fromOffset(d, d), pos = UDim2.new(1, -118, 0.5, 0), anchor = Vector2.new(0.5, 0.5), color = Color3.new(1, 1, 1), parent = inner, radius = 999, outline = 0, name = "Glow" })
		glow.BackgroundTransparency = if i == 1 then 0.86 else 0.74
	end
	local art = UI.icon(inner, o.icon, 150, UDim2.new(1, -118, 0.5, 2), Vector2.new(0.5, 0.5))
	Skin.bob(art, 4, 1.4 + (order % 3) * 0.2)
	Skin.shine(inner, 5, 0.4 + order * 0.35, 12)
	-- words and buttons sit on the face (not clipped, so a hovered button can grow past the edge)
	UI.text(face, string.upper(o.title), UDim2.new(1, -270, 0, 44), { pos = UDim2.fromOffset(18, 8), align = Enum.TextXAlignment.Left, stroke = 4 })
	UI.text(face, o.desc, UDim2.new(1, -270, 0, 24), { pos = UDim2.fromOffset(20, 54), align = Enum.TextXAlignment.Left, color = W.cream, stroke = 2 })
	local x = 18
	for _, p in o.prices do
		priceButton(face, p, UDim2.new(0, x, 1, -62))
		x += 214
		if p.gift then
			giftButton(face, UDim2.new(0, x, 1, -62))
			x += 68
		end
	end
	local tag = o.tags and o.tags[1]
	if tag then
		UI.ribbon(slot, tag, TAG_COLOR[tag] or C.green)
		if SHINY[tag] then
			Skin.sparkles(inner, 0.4, Color3.fromRGB(255, 244, 170))
		end
	end
	return slot
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
		icon = pic(PASS_ICON[key], "backpack"),
		color = p.color or C.green,
		tags = if owned then { "OWNED" } else { p.tag or "FOREVER" },
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
				icon = pic("class_" .. p.class, "clover"),
				color = if c and Config.RARITY_COLORS[c.rarity] then Config.RARITY_COLORS[c.rarity] else Color3.fromRGB(230, 120, 40),
				tags = { "EXCLUSIVE" },
				prices = { robux(key) },
			})
		end
	end
end

local function mowerBanner(d, m): Banner?
	local owned = table.find(d.mowers, m.id) ~= nil
	local icon = pic(MOWER_ICON[m.id], "pushmower")
	local stats = ("Power %s  -  Speed %d  -  Fuel %d"):format(Format.short(m.damage), m.speed, m.fuel)
	if Config.MOWERS_LOCKED then
		-- (30 Oct: the ride-on mowers are locked for the release, shared/Config MOWERS_LOCKED: shown, not sold)
		return {
			title = m.name,
			desc = "Coming in a future update",
			icon = icon,
			color = m.color,
			tags = { "SOON" },
			prices = { { text = "🔒 SOON", enabled = false, onClick = function() end } },
		}
	end
	if m.currency == "gems" then
		return {
			title = m.name,
			desc = stats,
			icon = icon,
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
		return { title = m.name, desc = stats, icon = icon, color = m.color, tags = if owned then { "OWNED" } else { "NEW" }, prices = { robux(m.product, owned) } }
	elseif m.currency == "trial" and State.isRun() then
		return { title = m.name, desc = stats .. "  -  this run only", icon = icon, color = m.color, tags = { "BEST" }, prices = { robux(m.product) } }
	end
	return nil
end

local CONTENT: { [string]: (any) -> { Banner } } = {}
CONTENT.Featured = function(d)
	local out = {}
	classBanners(d, out)
	local rocket = Config.mower("RocketMower")
	if rocket and not table.find(d.mowers, rocket.id) and not Config.MOWERS_LOCKED then
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
	if trial and State.isRun() and not Config.MOWERS_LOCKED then
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
			icon = pic(GEM_ICON[i], "gem"),
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
-- The categories are seed packets in a stack, each its own colour: the open one is bright, slides out a little,
-- sparkles and its picture bobs; the others are pale until you pick them. (30 Oct, owner: "fix broken ui": they
-- stand straight and in line now, not tilted every other way, and every name is the same size.)
local PACKET = Vector2.new(214, 76)
local PACKET_GAP = 84
local CAT_COLOR = {
	Featured = Color3.fromRGB(255, 196, 60),
	Passes = Color3.fromRGB(176, 120, 245),
	Tools = Color3.fromRGB(240, 150, 70),
	Mowers = Color3.fromRGB(245, 96, 86),
	Gems = Color3.fromRGB(80, 176, 255),
}
local function sign(parent: Instance, i: number, cat, active: boolean, onClick: () -> ()): TextButton
	local color = CAT_COLOR[cat.id] or C.green
	local b = Instance.new("TextButton")
	b.Name = "Sign_" .. cat.id
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(PACKET.X, PACKET.Y)
	-- (the top one starts well below the board's wooden rim, which used to cover its top edge)
	b.Position = UDim2.fromOffset(if active then 18 else 6, 32 + (i - 1) * PACKET_GAP)
	local _art, face = Skin.frame(b, "ui_packet", PACKET, { name = "Art", boost = 1.3, tint = if active then color else color:Lerp(Color3.new(1, 1, 1), 0.5) })
	local icon = UI.icon(b, cat.icon, 56, UDim2.new(0, 14, 0.5, -2), Vector2.new(0, 0.5))
	-- (one size for every name: as big as the longest, FEATURED, fits; it scales with the window on every screen)
	UI.text(face, string.upper(cat.id), UDim2.new(1, -48, 1, -4), { pos = UDim2.fromOffset(46, 2), textSize = 27, stroke = if active then 3 else 2.5, color = if active then Color3.new(1, 1, 1) else Color3.fromRGB(255, 252, 240) })
	UI.raise(b, 4)
	if active then
		Skin.bob(icon, 3, 2.4)
		Skin.sparkles(b, 0.6)
	end
	Skin.press(b)
	b.MouseButton1Click:Connect(onClick)
	b.Parent = parent
	return b
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

	-- gems on the HUD's wooden plate + a green plus that jumps to the GEMS packet
	local gemBox, gemFace = Skin.frame(panel, "ui_plate", Vector2.new(214, 62), { pos = UDim2.fromOffset(18, 488), name = "GemBox" })
	local gemIcon = UI.icon(gemBox, "gem", 66, UDim2.fromOffset(-14, -2))
	Skin.bob(gemIcon, 2, 2)
	Skin.shine(gemFace, 4.5, 1, 999)
	local gemText = UI.text(gemFace, "0", UDim2.new(1, -86, 1, -4), { pos = UDim2.fromOffset(36, 2), align = Enum.TextXAlignment.Left, stroke = 2.5 })

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
				if current == cat.id then
					return
				end
				current = cat.id
				list.CanvasPosition = Vector2.zero
				w.refresh()
				UI.popIn(list)
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
	UI.button(gemBox, "+", GREEN, UDim2.fromOffset(50, 50), function()
		current = "Gems"
		list.CanvasPosition = Vector2.zero
		w.refresh()
		UI.popIn(list)
	end, { pos = UDim2.new(1, -4, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "Plus" })
	-- the banners pop in one after another when the window opens
	w.pop = { list }

	-- now and then a little mower putters along the grass at the bottom of the board, spitting clippings
	local lane = Instance.new("Frame")
	lane.Name = "MowerLane"
	lane.BackgroundTransparency = 1
	lane.Size = UDim2.new(1, 0, 0, 70)
	lane.Position = UDim2.new(0, 0, 1, 22) -- ride along the grass strip, below the cards
	lane.AnchorPoint = Vector2.new(0, 1)
	lane.ZIndex = 8
	lane.ClipsDescendants = false
	lane.Parent = w.frame
	task.spawn(function()
		while w.frame.Parent do
			task.wait(6 + math.random() * 6)
			if w.frame.Visible then
				local m = UI.icon(lane, "pushmower", 46, UDim2.new(1, 30, 1, 0), Vector2.new(0.5, 1))
				m.ZIndex = 9
				local drive = TweenService:Create(m, TweenInfo.new(5, Enum.EasingStyle.Linear), { Position = UDim2.new(0, -30, 1, 0) })
				local rock = TweenService:Create(m, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 4 })
				m.Rotation = -4
				drive:Play()
				rock:Play()
				task.spawn(function()
					while m.Parent do
						Skin.burst(m, 1, Color3.fromRGB(130, 220, 80))
						task.wait(0.2)
					end
				end)
				drive.Completed:Wait()
				rock:Cancel()
				m:Destroy()
			end
		end
	end)
	return w
end

return ShopWindow
