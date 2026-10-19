-- Every menu, in Chop A Forest's style (wooden boards, blue cards, brown popups):
--   Store (R): Robux tab + Gem Perks tab        Upgrades (TAB, run): Upgrades tab + Stats tab
--   ToolView: popup for a tool on the cabin wall Mowers (run garage) / Garage (lobby)
--   Classes: full-screen class shop             Rewards: daily + group popup
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Windows = {}
local C = UI.colors
local W = UI.wood

local function data()
	return State.data
end

local function perkText(c): { string }
	local parts = {}
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
-- STORE (R): Robux + Gem Perks
-------------------------------------------------------------------------------------------------------------
local STORE_TABS = { { label = "Robux", window = "Store" }, { label = "Gem Perks", window = "Perks" } }
local store = UI.window("Store", "Robux", nil, { tabs = STORE_TABS, grid = Vector2.new(250, 250), gems = true })
local PRODUCT_ICON = { Gems150 = "gem", Gems500 = "gem", Gems1500 = "gem", Gems5000 = "gem", TrialMower = "pushmower", RocketMower = "pushmower", ClassLawnLegend = "clover", ClassGoatMan = "clover" }
local PASS_ICON = { DoubleCoins = "coin", DoubleGems = "gem", BigBag = "backpack", VIP = "clover" }
store.refresh = function()
	local d = data()
	UI.clear(store.list)
	if not d then
		return
	end
	local order = 0
	for _, key in Config.PASS_ORDER do
		local p = Config.PASSES[key]
		order += 1
		local owned = d.passes[key]
		UI.blueCard(store.list, order, {
			title = p.name,
			sub = p.desc,
			icon = PASS_ICON[key],
			price = if owned then "OWNED" else "R$ " .. p.robux,
			enabled = not owned,
			color = Color3.fromRGB(255, 170, 40),
			onClick = function()
				if not owned then
					State.fire("Prompt", "pass", key)
				end
			end,
		})
	end
	for _, key in Config.PRODUCT_ORDER do
		local p = Config.PRODUCTS[key]
		local show = true
		if p.mower == "TrialMower" then
			show = State.isRun()
		elseif p.class then
			show = table.find(d.classes, p.class) == nil
		elseif p.mower then
			show = table.find(d.mowers, p.mower) == nil
		end
		if show then
			order += 1
			UI.blueCard(store.list, order, {
				title = p.name,
				sub = if p.gems then "Classes, perks and mowers" elseif p.mower == "TrialMower" then "A fast mower for this run" else "Yours forever",
				icon = PRODUCT_ICON[key],
				price = "R$ " .. p.robux,
				enabled = true,
				onClick = function()
					State.fire("Prompt", "product", key)
				end,
			})
		end
	end
end

local PERK_ICON = { sell = "coin", luck = "clover", gem = "gem", bundle = "bundle" }
local perks = UI.window("Perks", "Gem Perks", nil, { tabs = STORE_TABS, grid = Vector2.new(330, 220), gems = true })
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
local RUN_TABS = { { label = "Upgrades", window = "Upgrades" }, { label = "Stats", window = "Stats" }, { label = "Index", window = "Index" } }
local UPGRADE_ICON = { swing = "hands", grasp = "bundle", power = "upgrade", speed = "clover", sell = "coin" }
local CARD = Vector2.new(250, 200)

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

local upgrades = UI.window("Upgrades", "Upgrades", nil, { tabs = RUN_TABS })
upgrades.refresh = function()
	local d = data()
	UI.clear(upgrades.list)
	if not d or not d.run then
		return
	end
	local order = 0
	for _, section in Config.UPGRADE_SECTIONS do
		order += 1
		local title = if section == "Tool" then "Tool - " .. (Config.TOOLS[d.run.tool] or Config.TOOLS[1]).name else section
		UI.heading(upgrades.list, order, title)
		order += 1
		local row = cardRow(upgrades.list, order, 0)
		for i, u in Config.UPGRADES do
			if u.section == section then
				local level = d.run.upgrades[u.id] or 0
				local maxed = level >= u.max
				local cost = if maxed then 0 else Config.upgradeCost(u.id, level)
				UI.blueCard(cardSlot(row, i), 1, {
					title = u.name,
					sub = u.desc,
					icon = UPGRADE_ICON[u.id],
					level = level,
					max = u.max,
					price = if maxed then "MAX" else "$" .. Format.short(cost),
					enabled = not maxed and d.run.coins >= cost,
					color = Color3.fromRGB(70, 190, 90),
					onClick = function()
						State.fire("Buy", "upgrade", u.id)
					end,
				})
			end
		end
	end
	moneyLine(upgrades.list, 99, "Your money: $" .. Format.commas(d.run.coins))
end

local stats = UI.window("Stats", "Stats", nil, { tabs = RUN_TABS })
stats.refresh = function()
	local d = data()
	UI.clear(stats.list)
	if not d then
		return
	end
	local rows = {
		{ "upgrade", "Power", string.format("x%.2f", d.power) },
		{ "backpack", "Carry", if d.endless then "ENDLESS" else tostring(d.carryMax) },
		{ "bundle", "Pickup reach", string.format("%.1f studs", d.grasp or 0) },
		{ "hands", "Swing time", string.format("x%.2f", d.swing or 1) },
		{ "clover", "Mutation Luck", string.format("x%.2f", d.luck) },
		{ "coin", "Sell Price", string.format("x%.2f", d.sell) },
		{ "bundle", "Grass cut", Format.commas(d.stats.cut) },
		{ "gem", "Runs finished", tostring(d.stats.runs) },
		{ "lock", "Bosses beaten", tostring(d.stats.bosses) },
		{ "stats", "Best run", if (d.bestTime or 0) > 0 then Format.clock(d.bestTime) else "-" },
	}
	for i, r in rows do
		UI.popupRow(stats.list, i, r[1], r[2], r[3], Color3.new(1, 1, 1)).Size = UDim2.new(1, -20, 0, 56)
	end
end

-- INDEX: every grass type x mutation; the ones you've collected show their colour, the rest a lock.
local index = UI.window("Index", "Index", nil, { tabs = RUN_TABS, gems = true })
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
			local color = if got then (m.color or zone.grass[1]) else Color3.fromRGB(60, 52, 48)
			local cell = UI.frame({ size = UDim2.fromOffset(118, 92), color = color, parent = row, radius = 12, outline = 3 })
			cell.LayoutOrder = i
			UI.gradient(cell, color)
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
		icon = "backpack",
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
	UI.icon(toolView.list, TOOL_ICON[def.id] or "coin", 110).LayoutOrder = 1
	local desc = UI.text(toolView.list, TOOL_DESC[def.id] or "", UDim2.new(1, -20, 0, 60), { color = Color3.new(1, 1, 1), stroke = 2, textSize = 24 })
	desc.LayoutOrder = 2
	local kind = if def.kind == "auto" then "Cuts around you" else ("Cuts %d patch%s per swing"):format(def.targets, if def.targets > 1 then "es" else "")
	UI.popupRow(toolView.list, 3, "upgrade", "Damage " .. Format.short(def.damage), kind, Color3.new(1, 1, 1))
	moneyLine(toolView.list, 4, "Your money: $" .. Format.commas(d.run.coins))
	local owned = index <= d.run.tool
	local nextUp = index == d.run.tool + 1
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
		UI.setButton(toolView.action, "BUY " .. Config.TOOLS[index - 1].name:upper() .. " FIRST", W.grey)
		toolView.onAction = function() end
	end
end

-------------------------------------------------------------------------------------------------------------
-- MOWERS (run garage) and GARAGE (lobby)
-------------------------------------------------------------------------------------------------------------
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
		UI.blueCard(mowers.list, i, { title = m.name, sub = mowerSub(m), icon = "pushmower", price = price, enabled = enabled, color = color, onClick = action })
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
				icon = "pushmower",
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
local rewards = UI.popupWindow("Rewards", "Free Rewards", "Free gems for supporting us!")
rewards.refresh = function()
	local d = data()
	UI.clear(rewards.list)
	if not d then
		return
	end
	local ready = d.dailyIn <= 0
	UI.popupRow(rewards.list, 1, "gem", "Daily reward +" .. Config.DAILY_GEMS, if ready then "READY" else Format.clock(d.dailyIn), if ready then C.green else Color3.new(1, 1, 1))
	UI.popupRow(rewards.list, 2, "clover", "Join the group +" .. Config.GROUP_GEMS, if d.groupClaimed then "DONE" else "JOIN", if d.groupClaimed then C.green else C.yellow)
	local big = UI.text(rewards.list, "+" .. Config.DAILY_GEMS, UDim2.new(1, 0, 0, 60), { color = Color3.new(1, 1, 1), stroke = 3 })
	big.LayoutOrder = 3
	if ready then
		UI.setButton(rewards.action, "CLAIM DAILY", C.green)
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
		local nextTool = d and d.run and Config.TOOLS[d.run.tool + 1]
		viewTool = if nextTool then nextTool.id else Config.TOOLS[#Config.TOOLS].id
		task.defer(function()
			UI.open("ToolView")
		end)
	end
end)

State.on("data", function()
	UI.refreshOpen()
end)

function Windows.open(name: string)
	UI.open(name)
end

return Windows
