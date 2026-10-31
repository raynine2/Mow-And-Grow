-- Every menu, in Chop A Forest's style (wooden boards, blue cards, brown popups):
--   Store (R): client/ShopWindow                Perks: gem perks
--   Upgrades (TAB, run) + Stats (client/StatsWindow) + Index
--   ToolView: popup for a tool on the cabin wall Mowers (run garage) / Garage (lobby)
--   Classes: full-screen class shop             Rewards: daily + group popup       News: client/NewsWindow
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local Sound = require(script.Parent.Sound)
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local State = require(script.Parent.State)
local GnomeHunt = require(script.Parent.GnomeHunt) -- (27 Oct) gnome pictures for the Index's gnome shelf

local Windows = {}
local C = UI.colors
local W = UI.wood

local function data()
	return State.data
end

local function perkText(c): { string }
	local parts = {}
	local gim = Config.CLASS_GIMMICK and Config.CLASS_GIMMICK[c.id]
	if gim then
		table.insert(parts, "★ " .. gim.name .. ": " .. gim.text)
	end
	if c.power then
		table.insert(parts, "+" .. math.floor(c.power * 100) .. "% Power")
	end
	if c.speed then
		table.insert(parts, "+" .. math.floor(c.speed * 100) .. "% Walk Speed")
	end
	if c.sell then
		table.insert(parts, "+" .. math.floor(c.sell * 100) .. "% Sell Price")
	end
	if c.luck then
		table.insert(parts, "+" .. math.floor(c.luck * 100) .. "% Mutation Luck")
	end
	if c.carry then
		table.insert(parts, "+" .. c.carry .. " Carry")
	end
	return parts
end

local function moneyLine(list: Instance, order: number, text: string)
	local t = UI.text(list, text, UDim2.new(1, -20, 0, 34), { color = Color3.new(1, 1, 1), stroke = 2.5 })
	t.LayoutOrder = order
	return t
end

-------------------------------------------------------------------------------------------------------------
-- PERKS: gem perks, bought one level at a time (the Store itself is client/ShopWindow)
-------------------------------------------------------------------------------------------------------------
local PERK_ICON = { sell = "coin", luck = "clover", gem = "gem", bundle = "bundle" }
local perks = UI.window("Perks", "Perks", nil, { grid = Vector2.new(330, 220), gems = true })
perks.refresh = function()
	local d = data()
	UI.clear(perks.list)
	if not d then
		return
	end
	for i, p in Config.PERKS do
		local level = d.perks[p.id] or 0
		local cost = p.costs[level + 1]
		UI.blueCard(perks.list, i, {
			title = p.name,
			sub = p.desc,
			icon = PERK_ICON[p.id],
			level = level,
			max = #p.costs,
			price = if cost then tostring(cost) else "MAX",
			priceIcon = if cost then "gem" else nil,
			enabled = cost ~= nil and d.gems >= cost,
			onClick = function()
				State.fire("Buy", "perk", p.id)
			end,
		})
	end
end

-------------------------------------------------------------------------------------------------------------
-- UPGRADES (TAB, run): Upgrades (Hands / Tool / Gear sections) + Stats + Index
-------------------------------------------------------------------------------------------------------------
local RUN_TABS = {
	{ label = "Upgrades", window = "Upgrades", icon = "upgrade", runOnly = true },
	{ label = "Stats", window = "Stats", icon = "chart" },
	{ label = "Index", window = "Index", icon = "news" },
}
Windows.RUN_TABS = RUN_TABS
local UPGRADE_ICON = { hold = "hands", swing = "hands", grasp = "bundle", power = "upgrade", speed = "clover", sell = "coin" }
-- the garden-shed pictures (ForgeGUI, 22 Oct) once they're uploaded
for id, key in { hold = "up_hold", swing = "up_swing", grasp = "up_grasp", power = "up_power", speed = "up_speed", sell = "up_sell" } do
	if (Config.ICONS[key] or "") ~= "" then
		UPGRADE_ICON[id] = key
	end
end
local CARD = Vector2.new(250, 244) -- a hanging tag: the hook and twine on top, the tag, the level blades and the price
local INK = Color3.fromRGB(92, 52, 22) -- burnt-into-the-wood brown

-- A row of fixed-size cards under a heading (the window lists sections top to bottom).
local function cardRow(list: Instance, order: number, count: number): Frame
	local row = Instance.new("Frame")
	row.Name = "CardRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -10, 0, CARD.Y)
	row.LayoutOrder = order
	row.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 16)
	layout.Parent = row
	local _ = count
	return row
end

local function cardSlot(row: Frame, order: number): Frame
	local slot = Instance.new("Frame")
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	slot.LayoutOrder = order
	slot.Parent = row
	return slot
end

-- GARDEN SHED. The board is a pegboard wall (a brown panel with rows of peg holes) and every upgrade hangs on it as
-- a wooden tool tag on a twine loop, swaying a little: its picture, what it does, its level as grass blades
-- (grown green ones for the levels you have) and a painted price button.
local function pegboard(panel: Instance)
	local board = UI.frame({ size = UDim2.new(1, -8, 1, -8), pos = UDim2.fromOffset(4, 4), color = Color3.fromRGB(178, 120, 66), parent = panel, radius = 16, outline = 3, name = "Pegboard" })
	;(board:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(110, 66, 30)
	UI.gradient(board, Color3.fromRGB(190, 130, 72))
	board.ZIndex = 1
	board.ClipsDescendants = true
	local holes = Instance.new("Frame")
	holes.Name = "Holes"
	holes.BackgroundTransparency = 1
	holes.Size = UDim2.new(1, 0, 1, 0)
	holes.Parent = board
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(9, 9)
	grid.CellPadding = UDim2.fromOffset(37, 37)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Parent = holes
	for _ = 1, 20 * 12 do
		local h = UI.frame({ size = UDim2.fromOffset(9, 9), color = Color3.fromRGB(96, 58, 28), parent = holes, radius = 999, outline = 0 })
		h.BackgroundTransparency = 0.25
		h.ZIndex = 1
	end
end

local function shedCard(slot: Frame, u, level: number, cost: number, enabled: boolean)
	local maxed = level >= u.max
	local tag = Instance.new("Frame")
	tag.Name = "Tag"
	tag.BackgroundTransparency = 1
	tag.Size = UDim2.new(1, -10, 1, -26)
	tag.Position = UDim2.fromOffset(5, 24)
	tag.Parent = slot
	local art, face = Skin.frame(tag, "ui_tag", Vector2.new(CARD.X - 10, CARD.Y - 26), { name = "Art", maxScale = 0.3 })
	art.Size = UDim2.fromScale(1, 1)
	if Skin.has("hook") then
		local hook = UI.icon(slot, "hook", 46, UDim2.new(0.5, 0, 0, -4), Vector2.new(0.5, 0))
		hook.ZIndex = 6
	end
	local pad = face.Position.X.Offset
	UI.text(tag, string.upper(u.name), UDim2.new(1, -pad * 2, 0, 28), { pos = UDim2.fromOffset(pad, face.Position.Y.Offset - 4), color = INK, stroke = 0 })
	UI.text(tag, u.desc, UDim2.new(1, -pad * 2, 0, 18), { pos = UDim2.fromOffset(pad, face.Position.Y.Offset + 24), color = Color3.fromRGB(140, 90, 50), stroke = 0 })
	local pic = UI.icon(tag, UPGRADE_ICON[u.id] or "upgrade", 60, UDim2.new(0.5, 0, 0, face.Position.Y.Offset + 44), Vector2.new(0.5, 0))
	Skin.bob(pic, 3, 1.5 + (#u.id % 3) * 0.3)
	if u.max > 1 then
		Skin.blades(tag, level, u.max, UDim2.new(0.5, 0, 1, -92), 176)
	end
	local price = if maxed then "MAX" else "$" .. Format.short(cost)
	local color = if maxed then Color3.fromRGB(255, 196, 40) elseif enabled then C.green else W.grey
	local btn = UI.button(tag, price, color, UDim2.fromOffset(176, 46), function()
		if not maxed then
			State.fire("Buy", "upgrade", u.id)
		end
	end, { pos = UDim2.new(0.5, 0, 1, -16), anchor = Vector2.new(0.5, 1), name = "Price" })
	btn.ZIndex += 2
	if maxed then
		Skin.sparkles(tag, 0.6)
	end
	Skin.swing(tag, 1.1, 1.3 + (#u.id % 4) * 0.15)
end

local upgrades = UI.window("Upgrades", "Upgrades", nil, { tabs = RUN_TABS, size = Vector2.new(940, 580) })
pegboard(upgrades.panel)
upgrades.refresh = function()
	local d = data()
	UI.clear(upgrades.list)
	if not d or not d.run then
		return
	end
	local order = 0
	for _, section in Config.UPGRADE_SECTIONS do
		order += 1
		local title = if section == "Tool" then "Tool - " .. (Config.TOOLS[Config.bestTool(d.run, d.tools)] or Config.TOOLS[1]).name else section
		UI.heading(upgrades.list, order, title)
		order += 1
		local row = cardRow(upgrades.list, order, 0)
		for i, u in Config.UPGRADES do
			if u.section == section then
				local level = d.run.upgrades[u.id] or 0
				local maxed = level >= u.max
				local cost = if maxed then 0 else Config.upgradeCost(u.id, level)
				shedCard(cardSlot(row, i), u, level, cost, not maxed and d.run.coins >= cost)
			end
		end
	end
	moneyLine(upgrades.list, 99, "Your money: $" .. Format.commas(d.run.coins))
	moneyLine(upgrades.list, 100, "Weapon upgrades: SKILLS (K). Every weapon has its own tree") -- (30 Oct) client/SkillTreeWindow
end

-- INDEX: every grass type x mutation; the ones you've collected show their colour, the rest a lock.
local index = UI.window("Index", "Stats", nil, { tabs = RUN_TABS }) -- no gem box: it would cover the third tab
index.refresh = function()
	local d = data()
	UI.clear(index.list)
	if not d then
		return
	end
	local found = {}
	for _, key in d.index or {} do
		found[key] = true
	end
	local total, have = 0, 0
	local order = 0
	for z, zone in Config.ZONES do
		order += 1
		UI.heading(index.list, order, zone.grassName)
		order += 1
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -10, 0, 96)
		row.LayoutOrder = order
		row.Parent = index.list
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		for i, m in Config.MUTATIONS do
			total += 1
			local got = found[z .. ":" .. m.id] == true
			if got then
				have += 1
			end
			local color = if got then (m.color or zone.grass[1]) elseif C.theme == "galaxy" then Color3.fromRGB(70, 48, 140) else Color3.fromRGB(60, 52, 48)
			local cell = UI.frame({ size = UDim2.fromOffset(118, 92), color = color, parent = row, radius = 12, outline = 3 })
			cell.LayoutOrder = i
			UI.gradient(cell, color)
			if Skin.has("ui_button") then
				cell.BackgroundTransparency = 1
				;(cell:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
				Skin.frame(cell, "ui_button", Vector2.new(118, 92), { name = "Art", boost = 1.4, tint = color })
				if got and m.id ~= "None" then
					Skin.sparkles(cell, 1.2, UI.shade(color, 1.5))
				end
			end
			if got then
				UI.icon(cell, "bundle", 40, UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
			else
				UI.icon(cell, "lock", 34, UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
			end
			UI.text(cell, if got then (if m.id == "None" then "Normal" else m.id) else "???", UDim2.new(1, -8, 0, 26), { pos = UDim2.fromOffset(4, 60), stroke = 2 })
		end
	end
	local line = moneyLine(index.list, 0, ("Collected %d / %d  -  +%d gems for each new one"):format(have, total, Config.INDEX_GEMS))
	line.LayoutOrder = 0
	Windows.gnomeShelf(index.list, d, -10)
end

-- GOLDEN GNOMES (27 Oct, the gnome hunt: server/Gnomes): a shelf of every gnome at the top of the Index; the ones
-- you've found in colour with how many, the rest dark silhouettes. Uses LayoutOrder `order` .. `order` + 2.
function Windows.gnomeShelf(list: Instance, d, order: number)
	local G = Config.GNOMES
	local got = d.gnomes or {}
	local have = 0
	for _, g in G.list do
		if (got[g.id] or 0) > 0 then
			have += 1
		end
	end
	UI.heading(list, order, ("Golden Gnomes  %d / %d"):format(have, #G.list))
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -10, 0, 112)
	row.LayoutOrder = order + 1
	row.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for i, g in G.list do
		local n = got[g.id] or 0
		local color = if n > 0 then (if g.diamond then Color3.fromRGB(120, 200, 235) else Color3.fromRGB(232, 172, 44)) elseif C.theme == "galaxy" then Color3.fromRGB(70, 48, 140) else Color3.fromRGB(110, 94, 80)
		local cell = UI.frame({ size = UDim2.fromOffset(76, 108), color = color, parent = row, radius = 12, outline = 3 })
		cell.LayoutOrder = i
		UI.gradient(cell, color)
		GnomeHunt.view(cell, g.id, 74, UDim2.new(0.5, 0, 0, 2), Vector2.new(0.5, 0), n == 0)
		local label = if n > 0 then (g.name:gsub(" Gnome$", "")) else "???"
		UI.text(cell, label, UDim2.new(1, -6, 0, 24), { pos = UDim2.fromOffset(3, 78), stroke = 2, textSize = 17 })
		if n > 1 then
			UI.text(cell, "x" .. n, UDim2.fromOffset(40, 22), { pos = UDim2.new(1, -4, 0, 4), anchor = Vector2.new(1, 0), stroke = 2, textSize = 18, align = Enum.TextXAlignment.Right })
		end
	end
	local note = if have >= #G.list then "You found every gnome!"
		else ("Gnomes hide at the foot of the grass in every area. Find all %d: +%d gems!"):format(#G.list, G.setGems)
	local line = moneyLine(list, 0, note)
	line.LayoutOrder = order + 2
end

-------------------------------------------------------------------------------------------------------------
-- BAGS (run, the Bag Stand): bag tiers in order, the Leaf Vacuum, and the Bottomless Sack game pass
-------------------------------------------------------------------------------------------------------------
local bags = UI.window("Bags", "Bags & Gear", nil, { grid = Vector2.new(250, 250) })
bags.refresh = function()
	local d = data()
	UI.clear(bags.list)
	if not d or not d.run then
		return
	end
	local bag = d.run.bag or 0
	for i, b in Config.BAGS do
		local price, enabled, action = "OWNED", false, function() end
		if i == bag + 1 then
			price, enabled = "$" .. Format.short(b.cost), d.run.coins >= b.cost
			action = function()
				State.fire("Buy", "bag", b.id)
			end
		elseif i > bag + 1 then
			price = "BUY " .. string.upper(Config.BAGS[i - 1].name) .. " FIRST"
		end
		UI.blueCard(bags.list, i, { title = b.name, sub = ("+%d bundles carried"):format(b.carry), icon = "backpack", price = price, enabled = enabled, color = Color3.fromRGB(70, 190, 90), onClick = action })
	end
	local vac = Config.VACUUM
	UI.blueCard(bags.list, 10, {
		title = vac.name,
		sub = ("Picks up loot from %dx farther"):format(vac.graspMult),
		icon = "bundle",
		price = if d.run.vacuum then "OWNED" else "$" .. Format.short(vac.cost),
		enabled = not d.run.vacuum and d.run.coins >= vac.cost,
		color = Color3.fromRGB(255, 150, 50),
		onClick = function()
			if not d.run.vacuum then
				State.fire("Buy", "vacuum", "Vacuum")
			end
		end,
	})
	local sack = Config.PASSES.BigBag
	local ownsSack = d.passes and d.passes.BigBag
	UI.blueCard(bags.list, 11, {
		title = sack.name,
		sub = sack.desc,
		icon = if (Config.ICONS.sack or "") ~= "" then "sack" else "backpack",
		price = if ownsSack then "OWNED" else "R$ " .. sack.robux,
		enabled = not ownsSack,
		color = Color3.fromRGB(140, 90, 255),
		onClick = function()
			if not ownsSack then
				State.fire("Prompt", "pass", "BigBag")
			end
		end,
	})
end

-------------------------------------------------------------------------------------------------------------
-- TOOL VIEW: the popup you get from a tool hanging on the cabin wall
-------------------------------------------------------------------------------------------------------------
local toolView = UI.popupWindow("ToolView", "Tool", "")
local viewTool = "Scissors"
local TOOL_DESC = {
	Hands = "Pull the grass out by hand. Slow, but free!",
	Scissors = "Snip 2 patches at once. Your first real tool.",
	Sickle = "A wide swing that cuts 4 patches at a time.",
	PushMower = "Mows everything around you while you walk. No clicking!",
	WeedWhacker = "Spins through thick grass in a big circle.",
	MegaScythe = "A giant glowing blade that clears 12 patches per swing.",
	LaserMower = "The ultimate mower. Lasers. Need we say more?",
}
local TOOL_ICON = { Hands = "hands", Scissors = "scissors", Sickle = "sickle", PushMower = "pushmower", WeedWhacker = "whacker", MegaScythe = "scythe", LaserMower = "lasermower" }
-- (owner, 29 Oct: "make the weapons be able to be bought by robux just like how you buy it with coins but make an
-- extra option for buy weapon for only this run and also buy weapon permanently. the coins buy button sits
-- inbetween these 2 robux options") [R$ THIS RUN] [BUY $coins] [R$ FOREVER]. The Robux products are
-- Config.PRODUCTS.ToolOnce<id> / ToolForever<id> (server/Monetization grants them; a forever weapon lifts every
-- run's weapon to it from the start). The price shown is the product's real price on Roblox, read once.
local MarketplaceService = game:GetService("MarketplaceService")
local livePrice: { [number]: number } = {}
local function priceOf(key: string): number?
	local p = Config.PRODUCTS[key]
	if not p then
		return nil
	end
	local cached = livePrice[p.id]
	if cached then
		return cached
	end
	if p.id ~= 0 and livePrice[p.id] == nil then
		livePrice[p.id] = p.robux -- (asked once; the Config price until Roblox answers)
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.id, Enum.InfoType.Product)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				livePrice[p.id] = info.PriceInRobux
				if toolView.frame.Visible then
					toolView.refresh()
				end
			end
		end)
	end
	return p.robux
end
local ROBUX_BLUE = Color3.fromRGB(64, 156, 250)
local function robuxButton(name: string, pos: UDim2): TextButton
	local b = UI.button(toolView.frame, "", ROBUX_BLUE, UDim2.fromOffset(140, 66), function() end, { pos = pos, anchor = Vector2.new(0.5, 1), name = name })
	local label = b:FindFirstChild("Label") :: TextLabel?
	if label then
		label.RichText = true
	end
	-- (over the popup's corner daisy, which sits on ZIndex 5)
	b.ZIndex = 6
	for _, g in b:GetDescendants() do
		if g:IsA("GuiObject") then
			g.ZIndex = 6
		end
	end
	return b
end
local onceBtn, foreverBtn
local function robuxButtons(def, owned: boolean, d)
	if not onceBtn then
		-- the coin button in the middle, a Robux button either side of it
		toolView.action.Size = UDim2.fromOffset(170, 66)
		onceBtn = robuxButton("RobuxRun", UDim2.new(0.5, -165, 1, -24))
		foreverBtn = robuxButton("RobuxForever", UDim2.new(0.5, 165, 1, -24))
		onceBtn.MouseButton1Click:Connect(function()
			if onceBtn:GetAttribute("Key") then
				State.fire("Prompt", "product", onceBtn:GetAttribute("Key"))
			else
				Sound.play("denied")
			end
		end)
		foreverBtn.MouseButton1Click:Connect(function()
			if foreverBtn:GetAttribute("Key") then
				State.fire("Prompt", "product", foreverBtn:GetAttribute("Key"))
			else
				Sound.play("denied")
			end
		end)
	end
	local onceKey, foreverKey = def.once, def.forever
	local has = onceKey ~= nil and Config.PRODUCTS[onceKey] ~= nil
	onceBtn.Visible = has
	foreverBtn.Visible = has
	if not has then
		toolView.action.Size = UDim2.fromOffset(260, 66) -- Bare Hands: just the one button
		return
	end
	toolView.action.Size = UDim2.fromOffset(170, 66)
	local foreverOwned = table.find(d.tools or {}, def.id) ~= nil
	if owned then
		UI.setButton(onceBtn, "OWNED", W.grey)
		onceBtn:SetAttribute("Key", nil)
	else
		UI.setButton(onceBtn, ("R$ %s\nTHIS RUN"):format(Format.commas(priceOf(onceKey) or 0)), ROBUX_BLUE)
		onceBtn:SetAttribute("Key", onceKey)
	end
	if foreverOwned then
		UI.setButton(foreverBtn, "OWNED\nFOREVER", W.grey)
		foreverBtn:SetAttribute("Key", nil)
	else
		UI.setButton(foreverBtn, ("R$ %s\nFOREVER"):format(Format.commas(priceOf(foreverKey) or 0)), Color3.fromRGB(150, 90, 255))
		foreverBtn:SetAttribute("Key", foreverKey)
	end
end

State.on("openFor", function(window, item)
	if window == "ToolView" and type(item) == "string" then
		viewTool = item
	end
end)
toolView.refresh = function()
	local d = data()
	UI.clear(toolView.list)
	local index, def = 1, Config.TOOLS[1]
	for i, t in Config.TOOLS do
		if t.id == viewTool then
			index, def = i, t
		end
	end
	toolView.title.Text = string.upper(def.name)
	toolView.sub.Text = "$" .. Format.commas(def.cost)
	if not d or not d.run then
		return
	end
	-- the tool bobbing in front of a slow sunburst
	local pic = Instance.new("Frame")
	pic.Name = "Pic"
	pic.BackgroundTransparency = 1
	pic.Size = UDim2.fromOffset(160, 120)
	pic.LayoutOrder = 1
	pic.Parent = toolView.list
	Skin.rays(pic, Color3.fromRGB(255, 220, 120), 150, nil, 12)
	local toolIc = UI.icon(pic, TOOL_ICON[def.id] or "coin", 110, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	Skin.bob(toolIc, 3, 1.5)
	local desc = UI.text(toolView.list, TOOL_DESC[def.id] or "", UDim2.new(1, -20, 0, 60), { color = Color3.new(1, 1, 1), stroke = 2, textSize = 24 })
	desc.LayoutOrder = 2
	local kind = if def.kind == "auto" then "Cuts around you" else ("Cuts %d patch%s per swing"):format(def.targets, if def.targets > 1 then "es" else "")
	UI.popupRow(toolView.list, 3, "upgrade", "Damage " .. Format.short(def.damage), kind, Color3.new(1, 1, 1))
	moneyLine(toolView.list, 4, "Your money: $" .. Format.commas(d.run.coins))
	-- (29 Oct) owned: up the coin ladder, or bought with Robux on its own; next: the next coin buy (Config.nextToolIndex)
	local owned = Config.ownsTool(d.run, d.tools, index)
	local nextUp = index == Config.nextToolIndex(d.run, d.tools)
	if owned then
		UI.setButton(toolView.action, "OWNED", W.grey)
		toolView.onAction = function()
			UI.close()
		end
	elseif nextUp then
		local can = d.run.coins >= def.cost
		UI.setButton(toolView.action, "BUY $" .. Format.short(def.cost), if can then C.green else W.grey)
		toolView.onAction = function()
			State.fire("Buy", "tool", def.id)
		end
	else
		local first = Config.TOOLS[Config.nextToolIndex(d.run, d.tools) or (index - 1)] or Config.TOOLS[index - 1]
		UI.setButton(toolView.action, "BUY " .. first.name:upper() .. " FIRST", W.grey)
		toolView.onAction = function() end
	end
	robuxButtons(def, owned, d)
end

-------------------------------------------------------------------------------------------------------------
-- MOWERS (run garage) and GARAGE (lobby)
-------------------------------------------------------------------------------------------------------------
-- each mower's own ForgeGUI picture (the push mower until it's uploaded)
local MOWER_ICON = { RustyRider = "mower_rusty", TurboTractor = "mower_tractor", GoldenZeroTurn = "mower_zeroturn", MonsterMulcher = "mower_mulcher", TrialMower = "mower_trial", RocketMower = "mower_rocket" }
local function mowerIcon(m): string
	local key = MOWER_ICON[m.id]
	return if key and (Config.ICONS[key] or "") ~= "" then key else "pushmower"
end

local function mowerSub(m): string
	return ("Speed %d  -  Radius %d  -  %d fuel"):format(m.speed, m.radius, m.fuel)
end

local mowers = UI.window("Mowers", "Garage", nil, { grid = Vector2.new(250, 250), gems = true })
mowers.refresh = function()
	local d = data()
	UI.clear(mowers.list)
	if not d or not d.run then
		return
	end
	for i, m in Config.MOWERS do
		local price, enabled, action, color = "", false, function() end, nil
		local spawn = function()
			State.fire("SpawnMower", m.id)
			UI.close()
		end
		if m.currency == "coins" then
			if table.find(d.run.mowers, m.id) then
				price, enabled, action = "SPAWN", true, spawn
			else
				price, enabled = "$" .. Format.short(m.price), d.run.coins >= m.price
				action = function()
					State.fire("Buy", "mower", m.id)
					UI.close()
				end
			end
		elseif m.currency == "trial" then
			if d.run.trial then
				price, enabled, action = "SPAWN", true, spawn
			else
				price, enabled, color = "R$ " .. Config.PRODUCTS[m.product].robux, true, Color3.fromRGB(255, 170, 40)
				action = function()
					State.fire("Prompt", "product", m.product)
				end
			end
		elseif table.find(d.mowers, m.id) then
			price, enabled, action = "SPAWN", true, spawn
		elseif m.currency == "gems" then
			price = "LOBBY"
		else
			price, enabled, color = "R$ " .. Config.PRODUCTS[m.product].robux, true, Color3.fromRGB(255, 170, 40)
			action = function()
				State.fire("Prompt", "product", m.product)
			end
		end
		UI.blueCard(mowers.list, i, { title = m.name, sub = mowerSub(m), icon = mowerIcon(m), price = price, enabled = enabled, color = color, onClick = action })
	end
end

local garage = UI.window("Garage", "Garage", nil, { grid = Vector2.new(250, 250), gems = true })
garage.refresh = function()
	local d = data()
	UI.clear(garage.list)
	if not d then
		return
	end
	local n = 0
	for _, m in Config.MOWERS do
		if m.currency == "gems" or m.currency == "robux" then
			n += 1
			local owned = table.find(d.mowers, m.id) ~= nil
			local price, enabled, action = "OWNED", false, function() end
			if not owned and m.currency == "gems" then
				price, enabled = tostring(m.price), d.gems >= m.price
				action = function()
					State.fire("Buy", "mower", m.id)
				end
			elseif not owned then
				price, enabled = "R$ " .. Config.PRODUCTS[m.product].robux, true
				action = function()
					State.fire("Prompt", "product", m.product)
				end
			end
			UI.blueCard(garage.list, n, {
				title = m.name,
				sub = mowerSub(m),
				icon = mowerIcon(m),
				price = price,
				priceIcon = if not owned and m.currency == "gems" then "gem" else nil,
				enabled = enabled,
				onClick = action,
			})
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- REWARDS (lobby): daily + group, like the GROUP REWARD board
-------------------------------------------------------------------------------------------------------------
local rewards = UI.popupWindow("Rewards", "Free Rewards", "Come back every day for bigger rewards!")
rewards.frame.Size = UDim2.fromOffset(500, 620) -- room for the calendar, the streak line and two rows above the button

-- The 7-day ladder (server/Daily): claimed days ticked, today's glowing, the rest waiting; day 7 is the big one.
local function dayCard(parent: Instance, i: number, gems: number, state: string, size: Vector2, pos: Vector2)
	local colors = { claimed = Color3.fromRGB(110, 200, 90), today = C.yellow, later = Color3.fromRGB(150, 116, 84) }
	local f = UI.frame({ size = UDim2.fromOffset(size.X, size.Y), pos = UDim2.fromOffset(pos.X, pos.Y), color = colors[state], parent = parent, radius = 12, outline = 3, name = "Day" .. i })
	UI.gradient(f, colors[state])
	local big = i == #Config.DAILY_STREAK
	local art: GuiObject? = nil
	if Skin.has("ui_button") then
		-- the tinted ForgeGUI button art as the day's tile; today's turns on rays and sparkles
		f.BackgroundTransparency = 1
		;(f:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
		if state == "today" then
			Skin.rays(f, Color3.fromRGB(255, 240, 150), size.X * 1.6, nil, 10)
		end
		art = Skin.frame(f, "ui_button", size, { name = "Art", boost = 1.4, tint = colors[state] })
	end
	UI.text(f, "DAY " .. i, UDim2.new(1, -8, 0, 20), { pos = UDim2.fromOffset(4, 4), stroke = 2 })
	local gem = UI.icon(f, if big and (Config.ICONS.gemchest or "") ~= "" then "gemchest" else "gem", if big then 44 else 28, UDim2.new(0.5, 0, 0, if big then 20 else 25), Vector2.new(0.5, 0))
	if state ~= "claimed" then
		Skin.bob(gem, 2, 2 + i * 0.2)
	end
	UI.text(f, "+" .. gems, UDim2.new(1, -8, 0, 20), { pos = UDim2.new(0, 4, 1, -26), stroke = 2 })
	if state == "claimed" then
		local tick = UI.text(f, "✓", UDim2.fromOffset(30, 30), { pos = UDim2.new(1, 4, 0, -10), anchor = Vector2.new(1, 0), color = Color3.new(1, 1, 1), stroke = 3 })
		tick.Rotation = 10
	elseif state == "today" then
		if art then
			Skin.sparkles(f, 0.35)
		else
			local glow = Instance.new("UIStroke")
			glow.Color = Color3.fromRGB(255, 255, 210)
			glow.Thickness = 3
			glow.Parent = f
		end
		UI.breathe(f, 0.04, 4)
	elseif art then
		(art :: ImageLabel).ImageTransparency = 0.3
	else
		f.BackgroundTransparency = 0.25
	end
	return f
end

rewards.refresh = function()
	local d = data()
	UI.clear(rewards.list)
	if not d then
		return
	end
	-- the timers count down here between snapshots (an idle lobby player gets no new state to refresh them)
	local elapsed = os.clock() - State.dataAt
	local v = table.clone(d.daily or { ready = d.dailyIn <= 0, wait = d.dailyIn, day = 1, streak = 0, claimedToday = false })
	if not v.ready and (v.wait or 0) > 0 then
		v.wait = math.max(0, v.wait - elapsed)
		v.ready = v.wait <= 0
	end
	-- the calendar: days 1-4 on top, 5-6 and the big day 7 below
	local cal = Instance.new("Frame")
	cal.Name = "Calendar"
	cal.BackgroundTransparency = 1
	cal.Size = UDim2.fromOffset(440, 176)
	cal.LayoutOrder = 1
	cal.Parent = rewards.list
	for i, gems in Config.DAILY_STREAK do
		local done = if v.claimedToday then i <= v.day else i < v.day
		local state = if done then "claimed" elseif i == v.day and v.ready then "today" else "later"
		if i <= 4 then
			dayCard(cal, i, gems, state, Vector2.new(104, 80), Vector2.new((i - 1) * 112, 0))
		elseif i < #Config.DAILY_STREAK then
			dayCard(cal, i, gems, state, Vector2.new(104, 80), Vector2.new((i - 5) * 112, 92))
		else
			dayCard(cal, i, gems, state, Vector2.new(216, 80), Vector2.new(224, 92))
		end
	end
	local line = if v.ready then ("🔥 %d day streak  ·  Day %d is ready!"):format(v.streak, v.day)
		else ("🔥 %d day streak  ·  Next reward in %s"):format(v.streak, Format.clock(v.wait))
	local streak = UI.text(rewards.list, line, UDim2.new(1, 0, 0, 30), { color = Color3.new(1, 1, 1), stroke = 2.5 })
	streak.LayoutOrder = 2
	local free = table.clone(d.freeGems or { ready = false, wait = 0, gems = Config.FREE_GEMS.gems })
	if not free.ready and (free.wait or 0) > 0 then
		free.wait = math.max(0, free.wait - elapsed)
		free.ready = free.wait <= 0
	end
	local freeText = if free.ready then "READY" else Format.clock(free.wait)
	local freeRow = UI.popupRow(rewards.list, 3, "gem", ("Free gems every 6 hours +%d"):format(free.gems), freeText, if free.ready then C.green else C.yellow)
	local freeLabel: TextLabel? = nil
	for _, c in freeRow:GetChildren() do
		if c:IsA("TextLabel") and c.Text == freeText then
			freeLabel = c
		end
	end
	-- ticked every second while the window is open: the countdowns move, and a timer reaching 0 redraws it
	rewards.tick = function()
		local e = os.clock() - State.dataAt
		local dailyWait = (d.daily and d.daily.wait) or d.dailyIn or 0
		local freeWait = (d.freeGems and d.freeGems.wait) or 0
		local dailyLeft = math.max(0, dailyWait - e)
		local freeLeft = math.max(0, freeWait - e)
		-- (only a countdown that was running can run out: a 0 the server sent doesn't redraw every second)
		if (not v.ready and dailyWait > 0 and dailyLeft <= 0) or (not free.ready and freeWait > 0 and freeLeft <= 0) then
			rewards.refresh()
			return
		end
		if not v.ready then
			streak.Text = ("🔥 %d day streak  ·  Next reward in %s"):format(v.streak, Format.clock(dailyLeft))
		end
		if freeLabel and not free.ready then
			freeLabel.Text = Format.clock(freeLeft)
		end
	end
	UI.popupRow(rewards.list, 4, "clover", "Join the group +" .. Config.GROUP_GEMS, if d.groupClaimed then "DONE" else "JOIN", if d.groupClaimed then C.green else C.yellow)
	if v.ready then
		UI.setButton(rewards.action, "CLAIM DAY " .. v.day, C.green)
		rewards.onAction = function()
			State.fire("Claim", "daily")
		end
	elseif free.ready then
		UI.setButton(rewards.action, ("CLAIM +%d GEMS"):format(free.gems), C.green)
		rewards.onAction = function()
			State.fire("Claim", "daily")
		end
	elseif not d.groupClaimed then
		UI.setButton(rewards.action, "CLAIM GROUP", C.green)
		rewards.onAction = function()
			State.fire("Claim", "group")
		end
	else
		UI.setButton(rewards.action, "DONE", C.green)
		rewards.onAction = function()
			UI.close()
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- CLASSES (lobby): full-screen class shop - list on the left, details in the middle, perks on the right
-------------------------------------------------------------------------------------------------------------
local classes = UI.window("Classes", "Classes", nil, {})
classes.frame.Size = UDim2.fromOffset(1220, 660)
classes.frame.Position = UDim2.fromScale(0.5, 0.52)
local board = classes.frame:FindFirstChild("Board") :: Frame
board.BackgroundColor3 = Color3.fromRGB(28, 26, 44)
board:FindFirstChildOfClass("UIGradient"):Destroy()
board.BackgroundTransparency = 0.12
local panel = classes.panel :: Frame
panel.Visible = false
classes.title.Visible = false
for _, d in classes.frame:GetChildren() do
	if d.Name:match("^Tab") or d.Name:match("^Icon_") then
		d:Destroy()
	end
end
local leftList = Instance.new("ScrollingFrame")
leftList.BackgroundTransparency = 1
leftList.BorderSizePixel = 0
leftList.Size = UDim2.fromOffset(340, 560)
leftList.Position = UDim2.fromOffset(28, 84)
leftList.ScrollBarThickness = 6
leftList.AutomaticCanvasSize = Enum.AutomaticSize.Y
leftList.CanvasSize = UDim2.new()
leftList.Parent = board
local leftLayout = Instance.new("UIListLayout")
leftLayout.Padding = UDim.new(0, 12)
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Parent = leftList
UI.text(board, "CLASSES", UDim2.fromOffset(200, 40), { pos = UDim2.fromOffset(30, 18), align = Enum.TextXAlignment.Left, stroke = 3 })
local restockText = UI.text(board, "", UDim2.fromOffset(200, 36), { pos = UDim2.fromOffset(170, 20), align = Enum.TextXAlignment.Right, stroke = 2.5 })
UI.text(board, "Classes restock every 5 minutes - buy with gems", UDim2.fromOffset(340, 18), { pos = UDim2.fromOffset(30, 58), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(200, 200, 215), stroke = 1 })
local midName = UI.text(board, "", UDim2.fromOffset(480, 70), { pos = UDim2.fromOffset(610, 70), anchor = Vector2.new(0.5, 0), stroke = 4 })
local midRarity = UI.text(board, "", UDim2.fromOffset(300, 28), { pos = UDim2.fromOffset(610, 140), anchor = Vector2.new(0.5, 0), stroke = 2 })
local midStock = UI.text(board, "", UDim2.fromOffset(360, 22), { pos = UDim2.fromOffset(610, 170), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(210, 210, 225), stroke = 1.5 })
local midIconHolder = Instance.new("Frame")
midIconHolder.BackgroundTransparency = 1
midIconHolder.Size = UDim2.fromOffset(220, 220)
midIconHolder.Position = UDim2.fromOffset(500, 210)
midIconHolder.Parent = board
local robuxBtn = UI.button(board, "", Color3.fromRGB(255, 120, 200), UDim2.fromOffset(240, 48), function() end, { pos = UDim2.fromOffset(610, 470), anchor = Vector2.new(0.5, 0), name = "RobuxBuy" })
local buyBtn = UI.button(board, "BUY", Color3.fromRGB(235, 235, 240), UDim2.fromOffset(260, 52), function() end, { pos = UDim2.fromOffset(610, 530), anchor = Vector2.new(0.5, 0), name = "GemBuy" })
UI.button(board, "BACK", W.red, UDim2.fromOffset(180, 50), function()
	UI.close()
end, { pos = UDim2.fromOffset(610, 594), anchor = Vector2.new(0.5, 0), name = "Back" })
local rightTitle = UI.text(board, "", UDim2.fromOffset(330, 50), { pos = UDim2.fromOffset(860, 70), align = Enum.TextXAlignment.Left, stroke = 3 })
local rightTag = UI.frame({ size = UDim2.fromOffset(120, 28), pos = UDim2.fromOffset(860, 124), color = C.green, parent = board, radius = 8, outline = 0 })
local rightTagText = UI.text(rightTag, "", UDim2.new(1, -8, 1, -6), { pos = UDim2.fromOffset(4, 3), stroke = 1.5 })
local rightPrice = UI.text(board, "", UDim2.fromOffset(160, 24), { pos = UDim2.fromOffset(990, 126), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(210, 210, 225), stroke = 1 })
UI.text(board, "PERKS", UDim2.fromOffset(200, 26), { pos = UDim2.fromOffset(860, 176), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(200, 200, 215), stroke = 1.5 })
local perkList = Instance.new("Frame")
perkList.BackgroundTransparency = 1
perkList.Size = UDim2.fromOffset(330, 300)
perkList.Position = UDim2.fromOffset(860, 210)
perkList.Parent = board
local perkLayout = Instance.new("UIListLayout")
perkLayout.Padding = UDim.new(0, 8)
perkLayout.Parent = perkList

local selected = Config.DEFAULT_CLASS
local function stockNow(): ({ string }, number)
	local now = workspace:GetServerTimeNow()
	return Config.classStock(math.floor(now / Config.STOCK_WINDOW)), Config.STOCK_WINDOW - (now % Config.STOCK_WINDOW)
end

classes.refresh = function()
	local d = data()
	if not d then
		return
	end
	local stock, left = stockNow()
	restockText.Text = Format.clock(left)
	UI.clear(leftList)
	for i, c in Config.CLASSES do
		local owned = table.find(d.classes, c.id) ~= nil
		local inStock = table.find(stock, c.id) ~= nil
		local rc = Config.RARITY_COLORS[c.rarity]
		local card = Instance.new("TextButton")
		card.Text = ""
		card.AutoButtonColor = false
		card.Size = UDim2.new(1, -12, 0, 104)
		card.BackgroundColor3 = rc
		card.LayoutOrder = i
		UI.corner(card, 14)
		UI.stroke(card, if c.id == selected then 4 else 3, if c.id == selected then Color3.new(1, 1, 1) else UI.shade(rc, 0.45))
		UI.gradient(card, rc)
		UI.icon(card, "clover", 70, UDim2.fromOffset(12, 17))
		UI.text(card, c.name, UDim2.new(1, -110, 0, 38), { pos = UDim2.fromOffset(96, 14), align = Enum.TextXAlignment.Left, stroke = 3 })
		local state = if owned then (if d.class == c.id then "EQUIPPED" else "OWNED") elseif inStock then tostring(c.gems) .. " GEMS" else "SOLD OUT"
		local pill = UI.frame({ size = UDim2.fromOffset(140, 30), pos = UDim2.fromOffset(110, 60), color = if owned then C.green elseif inStock then Color3.fromRGB(40, 40, 60) else Color3.fromRGB(70, 70, 80), parent = card, radius = 8, outline = 0 })
		pill.BackgroundTransparency = 0.15
		UI.text(pill, state, UDim2.new(1, -8, 1, -6), { pos = UDim2.fromOffset(4, 3), stroke = 1.5 })
		card.MouseButton1Click:Connect(function()
			selected = c.id
			classes.refresh()
		end)
		card.Parent = leftList
	end
	local c = Config.class(selected) :: any
	local rc = Config.RARITY_COLORS[c.rarity]
	local owned = table.find(d.classes, c.id) ~= nil
	local inStock = table.find(stock, c.id) ~= nil
	midName.Text = c.name
	midName.TextColor3 = UI.shade(rc, 1.3)
	midRarity.Text = string.upper(c.rarity)
	midRarity.TextColor3 = rc
	midStock.Text = (if inStock then "IN STOCK" else "SOLD OUT") .. "  -  restock " .. Format.clock(left)
	UI.clear(midIconHolder)
	UI.icon(midIconHolder, "clover", 200, UDim2.fromOffset(10, 10))
	rightTitle.Text = c.name
	rightTag.BackgroundColor3 = rc
	rightTagText.Text = string.upper(c.rarity)
	rightPrice.Text = if c.gems > 0 then c.gems .. " gems" else "free"
	UI.clear(perkList)
	perkLayout.Parent = perkList
	for _, line in perkText(c) do
		UI.text(perkList, line, UDim2.new(1, 0, 0, 30), { align = Enum.TextXAlignment.Left, stroke = 2 })
	end
	robuxBtn.Visible = c.product ~= nil and not owned
	if c.product then
		UI.setButton(robuxBtn, "R$ " .. Config.PRODUCTS[c.product].robux)
	end
	if owned then
		UI.setButton(buyBtn, if d.class == c.id then "EQUIPPED" else "EQUIP", C.green)
	elseif inStock then
		UI.setButton(buyBtn, "BUY  " .. c.gems .. " GEMS", if d.gems >= c.gems then C.purple else W.grey)
	else
		UI.setButton(buyBtn, "SOLD OUT", W.grey)
	end
end
buyBtn.MouseButton1Click:Connect(function()
	local d = data()
	if not d then
		return
	end
	if table.find(d.classes, selected) then
		State.fire("EquipClass", selected)
	else
		State.fire("Buy", "class", selected)
	end
end)
robuxBtn.MouseButton1Click:Connect(function()
	local c = Config.class(selected)
	if c and c.product then
		State.fire("Prompt", "product", c.product)
	end
end)
task.spawn(function()
	while true do
		task.wait(1)
		if UI.isOpen("Classes") then
			local _, left = stockNow()
			restockText.Text = Format.clock(left)
			if left >= Config.STOCK_WINDOW - 1 then
				classes.refresh()
			end
		end
	end
end)

-- the old "Tools" stall opens the next tool you can buy
local _ = UI.popupWindow("Tools", "Tool Shop", "")
State.on("openFor", function(window)
	if window == "Tools" then
		local d = data()
		local ni = d and d.run and Config.nextToolIndex(d.run, d.tools)
		local nextTool = ni and Config.TOOLS[ni]
		viewTool = if nextTool then nextTool.id else Config.TOOLS[#Config.TOOLS].id
		task.defer(function()
			UI.open("ToolView")
		end)
	end
end)

State.on("data", function()
	UI.refreshOpen()
end)

task.spawn(function()
	while true do
		task.wait(1)
		if UI.isOpen("Rewards") and rewards.tick then
			pcall(rewards.tick)
		end
	end
end)

function Windows.open(name: string)
	UI.open(name)
end

-- the bigger menus live in their own modules
require(script.Parent.StatsWindow).build(RUN_TABS)
require(script.Parent.ShopWindow).build()
require(script.Parent.NewsWindow).build()
require(script.Parent.DevPanel) -- F2 / DEV button, for devs only

return Windows
