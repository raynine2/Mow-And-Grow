-- GEM UPGRADES (the GEMS stall), like Chop A Forest's: "Forever upgrades" (the gem perks) as four tall blue cards
-- (LV n/max, a big picture, now > next, level pips, the gem price), and "Get gems" (the gem packs, Robux) below.
-- Takes over the "Perks" window that client/Windows used to draw as a plain grid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local GemUpgrades = {}
local C = UI.colors

local BLUE = Color3.fromRGB(40, 130, 240)
local NAVY = Color3.fromRGB(16, 40, 100)
local PERK = {
	sell = { icon = "coin", what = "cash per bundle" },
	bundle = { icon = "bundle", what = "double bundle chance" },
	luck = { icon = "clover", what = "mutation chance" },
	gem = { icon = "gem", what = "gems from grass" },
}
local PACKS = { -- the gem products, with Chop A Forest's ribbons
	{ key = "Gems150", gems = 1 },
	{ key = "Gems500", gems = 2 },
	{ key = "Gems1500", gems = 3, tag = "POPULAR" },
	{ key = "Gems5000", gems = 4, tag = "BEST VALUE" },
}

local w = UI.window("Perks", "Gem Upgrades", nil, { gems = true, size = Vector2.new(1000, 600) })
w.list.Visible = false -- laid out below
local P = w.panel
local title = w.title :: TextLabel
title.Position = UDim2.fromOffset(60, -70)
UI.icon(w.frame, "gem", 92, UDim2.fromOffset(-30, -76)).ZIndex = 9

-- the gem box: blue, with a green + that opens the shop
local gemBox = w.frame:FindFirstChild("GemBox") :: GuiObject?
if gemBox then
	if gemBox:IsA("Frame") then
		-- (the drawn box; the ForgeGUI wooden plate keeps its own look)
		gemBox.Size = UDim2.fromOffset(250, 60)
		gemBox.BackgroundColor3 = Color3.fromRGB(30, 70, 170)
		;(gemBox:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(10, 26, 70)
		UI.gradient(gemBox, Color3.fromRGB(34, 80, 190))
	else
		gemBox.Size = UDim2.fromOffset(250, 60)
	end
	local plus = UI.button(gemBox, "+", C.green, UDim2.fromOffset(46, 46), function()
		UI.open("Store")
	end, { pos = UDim2.new(1, -8, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "More" })
	UI.raise(plus, 8)
end

local function pillHeader(parent: Instance, text: string, color: Color3, icon: string, pos: UDim2, width: number)
	local pill = UI.frame({ size = UDim2.fromOffset(width, 40), pos = pos, anchor = Vector2.new(0.5, 0), color = color, parent = parent, radius = 12, outline = 3, name = "Header" })
	UI.gradient(pill, color)
	UI.icon(pill, icon, 56, UDim2.fromOffset(-24, -10))
	UI.text(pill, text, UDim2.new(1, -48, 1, -10), { pos = UDim2.fromOffset(40, 5), stroke = 2.5 })
	UI.raise(pill, 6)
end

-- Forever upgrades
UI.section(P, UDim2.fromOffset(920, 308), UDim2.fromOffset(20, 44))
pillHeader(P, "Forever upgrades", BLUE, "star", UDim2.fromOffset(480, 24), 250)
local perkRow = Instance.new("Frame")
perkRow.BackgroundTransparency = 1
perkRow.Size = UDim2.fromOffset(900, 272)
perkRow.Position = UDim2.fromOffset(30, 72)
perkRow.ZIndex = 4
perkRow.Parent = P
local pl = Instance.new("UIListLayout")
pl.FillDirection = Enum.FillDirection.Horizontal
pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
pl.Padding = UDim.new(0, 18)
pl.SortOrder = Enum.SortOrder.LayoutOrder
pl.Parent = perkRow

-- Get gems
UI.section(P, UDim2.fromOffset(920, 176), UDim2.fromOffset(20, 374))
pillHeader(P, "Get gems", C.green, "gem", UDim2.fromOffset(480, 354), 200)
local packRow = Instance.new("Frame")
packRow.BackgroundTransparency = 1
packRow.Size = UDim2.fromOffset(900, 140)
packRow.Position = UDim2.fromOffset(30, 404)
packRow.ZIndex = 4
packRow.Parent = P
local kl = Instance.new("UIListLayout")
kl.FillDirection = Enum.FillDirection.Horizontal
kl.HorizontalAlignment = Enum.HorizontalAlignment.Center
kl.Padding = UDim.new(0, 16)
kl.SortOrder = Enum.SortOrder.LayoutOrder
kl.Parent = packRow

local function pct(v: number): string
	return ("+%d%%"):format(math.floor(v * 100 + 0.5))
end

local function perkCard(order: number, p, d)
	local level = d.perks[p.id] or 0
	local max = #p.costs
	local cost = p.costs[level + 1]
	local info = PERK[p.id] or { icon = "upgrade", what = p.desc }
	local card = UI.frame({ size = UDim2.fromOffset(206, 262), color = BLUE, parent = perkRow, radius = 18, outline = 4, name = "Perk_" .. p.id })
	card.LayoutOrder = order
	;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = NAVY
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(110, 190, 255), Color3.fromRGB(30, 100, 220))
	g.Rotation = 90
	g.Parent = card
	-- a soft glow behind the picture
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://125552447014366"
	glow.ImageColor3 = Color3.fromRGB(200, 235, 255)
	glow.ImageTransparency = 0.3
	glow.Size = UDim2.fromOffset(170, 150)
	glow.Position = UDim2.new(0.5, 0, 0, 62)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Parent = card
	local lv = UI.frame({ size = UDim2.fromOffset(78, 30), pos = UDim2.fromOffset(10, -14), color = Color3.fromRGB(20, 30, 70), parent = card, radius = 10, outline = 3, name = "Level" })
	UI.text(lv, ("LV %d/%d"):format(level, max), UDim2.new(1, -8, 1, -8), { pos = UDim2.fromOffset(4, 4), stroke = 1.5 })
	UI.icon(card, info.icon, 86, UDim2.new(0.5, 0, 0, 18), Vector2.new(0.5, 0))
	UI.text(card, string.upper(p.name), UDim2.new(1, -16, 0, 28), { pos = UDim2.fromOffset(8, 108), stroke = 3 })
	local box = UI.frame({ size = UDim2.new(1, -24, 0, 56), pos = UDim2.fromOffset(12, 140), color = Color3.fromRGB(20, 50, 130), parent = card, radius = 10, outline = 0, name = "Info" })
	box.BackgroundTransparency = 0.25
	UI.text(box, info.what, UDim2.new(1, -10, 0, 18), { pos = UDim2.fromOffset(5, 5), color = Color3.fromRGB(200, 220, 255), stroke = 1 })
	local now, nxt = level * p.per, math.min(level + 1, max) * p.per
	UI.text(box, if cost then ("%s  ▶  %s"):format(pct(now), pct(nxt)) else pct(now) .. "  MAX", UDim2.new(1, -10, 0, 26), { pos = UDim2.fromOffset(5, 25), color = Color3.fromRGB(150, 255, 120), stroke = 2 })
	UI.pips(card, level, max, UDim2.new(0.5, 0, 0, 204), 170)
	local can = cost ~= nil and d.gems >= cost
	local b = UI.button(card, if cost then Format.commas(cost) else "MAX", if can then Color3.fromRGB(60, 150, 250) else Color3.fromRGB(150, 155, 170), UDim2.fromOffset(150, 48), function()
		State.fire("Buy", "perk", p.id)
	end, { pos = UDim2.new(0.5, 0, 1, 22), anchor = Vector2.new(0.5, 1), name = "Buy" })
	if cost then
		UI.icon(b, "gem", 30, UDim2.new(0, 12, 0.5, -3), Vector2.new(0, 0.5))
	end
	UI.raise(b, 6)
end

local function packCard(order: number, pack)
	local p = Config.PRODUCTS[pack.key]
	if not p then
		return
	end
	local card = UI.frame({ size = UDim2.fromOffset(196, 128), color = Color3.fromRGB(26, 60, 150), parent = packRow, radius = 16, outline = 4, name = pack.key })
	card.LayoutOrder = order
	;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = NAVY
	UI.gradient(card, Color3.fromRGB(34, 74, 170))
	for i = 1, pack.gems do -- a little pile: more gems for a bigger pack
		local ic = UI.icon(card, "gem", 46 - i * 2, UDim2.fromOffset(6 + (i - 1) * 16, 8 + ((i + 1) % 2) * 8))
		ic.ZIndex = 3 + i
	end
	UI.text(card, Format.commas(p.gems), UDim2.fromOffset(110, 32), { pos = UDim2.fromOffset(78, 10), align = Enum.TextXAlignment.Left, stroke = 3 })
	UI.text(card, "gems", UDim2.fromOffset(80, 18), { pos = UDim2.fromOffset(80, 42), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(190, 210, 250), stroke = 1 })
	local b = UI.button(card, tostring(p.robux), C.green, UDim2.new(1, -20, 0, 46), function()
		State.fire("Prompt", "product", pack.key)
	end, { pos = UDim2.new(0.5, 0, 1, -10), anchor = Vector2.new(0.5, 1), name = "Buy" })
	UI.icon(b, "robux", 28, UDim2.new(0, 14, 0.5, -3), Vector2.new(0, 0.5))
	UI.raise(b, 6)
	if pack.tag then
		local r = UI.ribbon(card, pack.tag, if pack.tag == "POPULAR" then Color3.fromRGB(255, 170, 40) else Color3.fromRGB(255, 200, 60))
		r.Position = UDim2.fromOffset(70, -22) -- on the top edge, clear of the amount
		r.Rotation = -6
	end
end

w.refresh = function()
	local d = State.data
	UI.clear(perkRow)
	UI.clear(packRow)
	if not d then
		return
	end
	for i, p in Config.PERKS do
		perkCard(i, p, d)
	end
	for i, pack in PACKS do
		packCard(i, pack)
	end
end

return GemUpgrades
