-- Every menu: Tools, Upgrades, Mowers (run) and Classes, Perks, Garage, Rewards (lobby), Store (both).
-- Each window rebuilds its cards from State.data when it opens or the data changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Windows = {}
local C = UI.colors
local GREY = Color3.fromRGB(150, 150, 160)

local function data()
	return State.data
end

local function perkText(c): string
	local parts = {}
	if c.power then
		table.insert(parts, "+" .. math.floor(c.power * 100) .. "% Power")
	end
	if c.speed then
		table.insert(parts, "+" .. math.floor(c.speed * 100) .. "% Speed")
	end
	if c.sell then
		table.insert(parts, "+" .. math.floor(c.sell * 100) .. "% Sell")
	end
	if c.luck then
		table.insert(parts, "+" .. math.floor(c.luck * 100) .. "% Luck")
	end
	if c.carry then
		table.insert(parts, "+" .. c.carry .. " Carry")
	end
	return table.concat(parts, ", ")
end

local function info(list: Instance, order: number, text: string, color: Color3?)
	local t = UI.text(list, text, UDim2.new(1, 0, 0, 34), { color = color or C.dark, stroke = 0 })
	t.LayoutOrder = order
	return t
end

-------------------------------------------------------------------------------------------------------------
-- RUN: tools
-------------------------------------------------------------------------------------------------------------
local tools = UI.window("Tools", "TOOL SHOP", C.red)
tools.refresh = function()
	local d = data()
	UI.clear(tools.list)
	if not d or not d.run then
		return
	end
	for i, t in Config.TOOLS do
		local desc = if t.kind == "auto"
			then ("Cuts everything around you. %s damage"):format(Format.short(t.damage))
			else ("Click to cut %d patch%s. %s damage"):format(t.targets, if t.targets > 1 then "es" else "", Format.short(t.damage))
		local text, color, action = "LOCKED", GREY, function() end
		if i <= d.run.tool then
			text, color = if i == d.run.tool then "EQUIPPED" else "OWNED", GREY
		elseif i == d.run.tool + 1 then
			text = "$" .. Format.short(t.cost)
			color = if d.run.coins >= t.cost then C.green else C.orange
			action = function()
				State.fire("Buy", "tool", t.id)
			end
		end
		UI.card(tools.list, i, t.color, t.name, desc, text, color, action)
	end
end

-------------------------------------------------------------------------------------------------------------
-- RUN: upgrades (also Tab)
-------------------------------------------------------------------------------------------------------------
local upgrades = UI.window("Upgrades", "UPGRADES", C.blue)
upgrades.refresh = function()
	local d = data()
	UI.clear(upgrades.list)
	if not d or not d.run then
		return
	end
	for i, u in Config.UPGRADES do
		local level = d.run.upgrades[u.id] or 0
		local text, color, action = "MAX", GREY, function() end
		if level < u.max then
			local cost = Config.upgradeCost(u.id, level)
			text = "$" .. Format.short(cost)
			color = if d.run.coins >= cost then C.green else C.orange
			action = function()
				State.fire("Buy", "upgrade", u.id)
			end
		end
		UI.card(upgrades.list, i, C.blue, ("%s  Lv %d/%d"):format(u.name, level, u.max), u.desc, text, color, action)
	end
	info(upgrades.list, 99, "Upgrades last until the run ends.")
end

-------------------------------------------------------------------------------------------------------------
-- RUN: mowers (garage)
-------------------------------------------------------------------------------------------------------------
local function mowerDesc(m): string
	return ("Speed %d, cut radius %d, %s damage, %d fuel"):format(m.speed, m.radius, Format.short(m.damage), m.fuel)
end

local mowers = UI.window("Mowers", "GARAGE", C.purple)
mowers.refresh = function()
	local d = data()
	UI.clear(mowers.list)
	if not d or not d.run then
		return
	end
	for i, m in Config.MOWERS do
		local text, color, action = "", GREY, function() end
		local spawn = function()
			State.fire("SpawnMower", m.id)
			UI.close()
		end
		if m.currency == "coins" then
			if table.find(d.run.mowers, m.id) then
				text, color, action = "SPAWN", C.purple, spawn
			else
				text = "$" .. Format.short(m.price)
				color = if d.run.coins >= m.price then C.green else C.orange
				action = function()
					State.fire("Buy", "mower", m.id)
					UI.close()
				end
			end
		elseif m.currency == "trial" then
			if d.run.trial then
				text, color, action = "SPAWN", C.purple, spawn
			else
				local p = Config.PRODUCTS[m.product]
				text, color = "R$ " .. p.robux, C.pink
				action = function()
					State.fire("Prompt", "product", m.product)
				end
			end
		else
			if table.find(d.mowers, m.id) then
				text, color, action = "SPAWN", C.purple, spawn
			elseif m.currency == "gems" then
				text = "LOBBY ONLY"
			else
				local p = Config.PRODUCTS[m.product]
				text, color = "R$ " .. p.robux, C.pink
				action = function()
					State.fire("Prompt", "product", m.product)
				end
			end
		end
		local tag = if m.currency == "coins" then " (this run)" elseif m.currency == "trial" then " (1 run)" else ""
		UI.card(mowers.list, i, m.color, m.name .. tag, mowerDesc(m), text, color, action)
	end
	info(mowers.list, 99, "Mowers burn fuel while driving. Refuel at a gas pump.")
end

-------------------------------------------------------------------------------------------------------------
-- LOBBY: classes
-------------------------------------------------------------------------------------------------------------
local classes = UI.window("Classes", "CLASSES", C.purple)
local stockLine: TextLabel? = nil
local function stockNow(): ({ string }, number)
	local now = workspace:GetServerTimeNow()
	local window = math.floor(now / Config.STOCK_WINDOW)
	return Config.classStock(window), Config.STOCK_WINDOW - (now % Config.STOCK_WINDOW)
end
classes.refresh = function()
	local d = data()
	UI.clear(classes.list)
	if not d then
		return
	end
	local stock, left = stockNow()
	stockLine = info(classes.list, 0, "Restock in " .. Format.clock(left), C.purple)
	for i, c in Config.CLASSES do
		local owned = table.find(d.classes, c.id) ~= nil
		local text, color, action = "NOT IN STOCK", GREY, function() end
		if owned then
			if d.class == c.id then
				text = "EQUIPPED"
			else
				text, color = "EQUIP", C.green
				action = function()
					State.fire("EquipClass", c.id)
				end
			end
		elseif table.find(stock, c.id) then
			text = Format.short(c.gems) .. " GEMS"
			color = if d.gems >= c.gems then C.purple else C.orange
			action = function()
				State.fire("Buy", "class", c.id)
			end
		elseif c.product then
			local p = Config.PRODUCTS[c.product]
			text, color = "R$ " .. p.robux, C.pink
			action = function()
				State.fire("Prompt", "product", c.product)
			end
		end
		UI.card(classes.list, i, Config.RARITY_COLORS[c.rarity], c.name .. "  (" .. c.rarity .. ")", perkText(c), text, color, action)
	end
end
task.spawn(function()
	while true do
		task.wait(1)
		if UI.isOpen("Classes") and stockLine and stockLine.Parent then
			local _, left = stockNow()
			stockLine.Text = "Restock in " .. Format.clock(left)
			if left >= Config.STOCK_WINDOW - 1 then
				classes.refresh() -- new stock
			end
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- LOBBY: gem perks
-------------------------------------------------------------------------------------------------------------
local perks = UI.window("Perks", "GEM PERKS", C.blue)
perks.refresh = function()
	local d = data()
	UI.clear(perks.list)
	if not d then
		return
	end
	for i, p in Config.PERKS do
		local level = d.perks[p.id] or 0
		local cost = p.costs[level + 1]
		local text, color, action = "MAX", GREY, function() end
		if cost then
			text = cost .. " GEMS"
			color = if d.gems >= cost then C.purple else C.orange
			action = function()
				State.fire("Buy", "perk", p.id)
			end
		end
		UI.card(perks.list, i, C.blue, ("%s  Lv %d/%d"):format(p.name, level, #p.costs), p.desc, text, color, action)
	end
	info(perks.list, 99, "Perks are permanent and work in every run.")
end

-------------------------------------------------------------------------------------------------------------
-- LOBBY: garage (permanent mowers)
-------------------------------------------------------------------------------------------------------------
local garage = UI.window("Garage", "GARAGE", C.orange)
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
			local text, color, action = "OWNED", GREY, function() end
			if not owned then
				if m.currency == "gems" then
					text = Format.short(m.price) .. " GEMS"
					color = if d.gems >= m.price then C.purple else C.orange
					action = function()
						State.fire("Buy", "mower", m.id)
					end
				else
					local p = Config.PRODUCTS[m.product]
					text, color = "R$ " .. p.robux, C.pink
					action = function()
						State.fire("Prompt", "product", m.product)
					end
				end
			end
			UI.card(garage.list, n, m.color, m.name, mowerDesc(m), text, color, action)
		end
	end
	info(garage.list, 99, "Owned forever. Spawn them from the Garage inside a run.")
end

-------------------------------------------------------------------------------------------------------------
-- LOBBY: free rewards
-------------------------------------------------------------------------------------------------------------
local rewards = UI.window("Rewards", "FREE REWARDS", C.yellow)
rewards.refresh = function()
	local d = data()
	UI.clear(rewards.list)
	if not d then
		return
	end
	local ready = d.dailyIn <= 0
	UI.card(rewards.list, 1, C.purple, "Daily Gems", ("+%d gems every 6 hours"):format(Config.DAILY_GEMS), if ready then "CLAIM" else Format.clock(d.dailyIn), if ready then C.green else GREY, function()
		if ready then
			State.fire("Claim", "daily")
		end
	end)
	UI.card(rewards.list, 2, C.blue, "Join the Group", ("Join Atlas Interactive Inc for +%d gems"):format(Config.GROUP_GEMS), if d.groupClaimed then "CLAIMED" else "CLAIM", if d.groupClaimed then GREY else C.green, function()
		if not d.groupClaimed then
			State.fire("Claim", "group")
		end
	end)
	info(rewards.list, 99, "Finish a run and beat bosses for even more gems!")
end

-------------------------------------------------------------------------------------------------------------
-- BOTH: Robux store
-------------------------------------------------------------------------------------------------------------
local store = UI.window("Store", "STORE", C.pink)
store.refresh = function()
	local d = data()
	UI.clear(store.list)
	if not d then
		return
	end
	local order = 0
	info(store.list, order, "GAME PASSES", C.pink)
	for _, key in Config.PASS_ORDER do
		local p = Config.PASSES[key]
		order += 1
		local owned = d.passes[key]
		UI.card(store.list, order, C.yellow, p.name, p.desc, if owned then "OWNED" else "R$ " .. p.robux, if owned then GREY else C.pink, function()
			if not owned then
				State.fire("Prompt", "pass", key)
			end
		end)
	end
	order += 1
	info(store.list, order, "ITEMS", C.pink)
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
			local desc = if p.gems then "Spend on classes, perks and mowers" elseif p.class then "Owned forever" elseif p.mower == "TrialMower" then "A fast mower for this run only" else "Owned forever"
			UI.card(store.list, order, if p.gems then C.purple else C.orange, p.name, desc, "R$ " .. p.robux, C.pink, function()
				State.fire("Prompt", "product", key)
			end)
		end
	end
end

State.on("data", function()
	UI.refreshOpen()
end)

function Windows.open(name: string)
	UI.open(name)
end

return Windows
