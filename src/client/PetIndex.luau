-- The INDEX tab of the PETS window, like Chop A Forest's pet index: the eggs on the left (All Pets, then each egg,
-- with how many of its critters you've found), the critters grouped by rarity in the middle (black silhouettes
-- until you've hatched one), and the picked critter's big card on the right with where to hatch it and the odds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local State = require(script.Parent.State)
local PetsWindow = require(script.Parent.PetsWindow)

local PetIndex = {}
local C = UI.colors
local W = UI.wood
local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local win = UI.window("PetIndex", "Pets", nil, { tabs = PetsWindow.TABS, gems = false, size = Vector2.new(860, 560) })
win.frame.Position = UDim2.new(0.5, -160, 0.55, 0)
win.frame:SetAttribute("ReachRight", 336) -- (the big card, for a phone's layout: client/UI touchFit)
win.list.Visible = false -- this tab lays itself out
local P = win.panel

local function pillHeader(parent: Instance, text: string, color: Color3, icon: string, pos: UDim2, width: number): TextLabel
	return Skin.pill(parent, text, color, icon, pos - UDim2.fromOffset(0, 3), width)
end

UI.section(P, UDim2.fromOffset(204, 470), UDim2.fromOffset(18, 46))
pillHeader(P, "Eggs", W.tabWood, PetsWindow.eggIcon(Config.EGGS[1]), UDim2.fromOffset(60, 28), 130)
local eggList = Instance.new("Frame")
eggList.BackgroundTransparency = 1
eggList.Size = UDim2.fromOffset(188, 420)
eggList.Position = UDim2.fromOffset(26, 82)
eggList.ZIndex = 4
eggList.Parent = P
local eggLayout = Instance.new("UIListLayout")
eggLayout.Padding = UDim.new(0, 10)
eggLayout.SortOrder = Enum.SortOrder.LayoutOrder
eggLayout.Parent = eggList

UI.section(P, UDim2.fromOffset(570, 470), UDim2.fromOffset(234, 46))
local gridTitle = pillHeader(P, "All Pets", C.orange, "paw", UDim2.fromOffset(420, 28), 200)
local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Size = UDim2.fromOffset(552, 420)
scroll.Position = UDim2.fromOffset(244, 84)
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = W.frameEdge
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.ZIndex = 4
scroll.Parent = P
local sl = Instance.new("UIListLayout")
sl.Padding = UDim.new(0, 8)
sl.SortOrder = Enum.SortOrder.LayoutOrder
sl.Parent = scroll

local card = PetsWindow.bigCard(win.frame)
local hatchList = Instance.new("Frame")
hatchList.BackgroundTransparency = 1
hatchList.Size = UDim2.new(1, -16, 1, -12)
hatchList.Position = UDim2.fromOffset(8, 6)
hatchList.Parent = card.info

local filter: string? = nil -- nil = All Pets, else an egg id
local picked: string? = nil

-- How often an egg hatches this critter: "1 in 9.1".
local function oneIn(egg, petId: string, luck: number): string?
	for _, r in Config.eggOdds(egg, luck) do
		if r[1] == petId and r[2] > 0 then
			local n = 1 / r[2]
			return if n >= 100 then ("1 in %d"):format(math.floor(n + 0.5)) else ("1 in %.1f"):format(n)
		end
	end
	return nil
end

local function petsOf(eggId: string?): { any }
	local list = {}
	if eggId then
		local egg = Config.egg(eggId)
		for _, r in (egg and egg.pets) or {} do
			local p = Config.pet(r[1])
			if p then
				table.insert(list, p)
			end
		end
	else
		list = table.clone(Config.PETS)
	end
	return list
end

local function eggButton(order: number, text: string, sub: string, icon: string, active: boolean, onClick: () -> ())
	local color = if active then C.orange else W.tabWood
	local b = UI.button(eggList, "", color, UDim2.new(1, 0, 0, 62), onClick, { name = "Egg" .. order })
	b.LayoutOrder = order
	UI.icon(b, icon, 50, UDim2.fromOffset(4, 4))
	UI.text(b, text, UDim2.new(1, -66, 0, 26), { pos = UDim2.fromOffset(60, 6), align = Enum.TextXAlignment.Left, stroke = 2 })
	UI.text(b, sub, UDim2.new(1, -66, 0, 18), { pos = UDim2.fromOffset(60, 34), align = Enum.TextXAlignment.Left, color = W.cream, stroke = 1.5 })
	UI.raise(b, 5)
end

win.refresh = function()
	local d = State.data
	if not d then
		return
	end
	local found: { [string]: boolean } = {}
	for _, e in d.pets or {} do
		found[e.id] = true
	end
	local function count(list): number
		local n = 0
		for _, p in list do
			if found[p.id] then
				n += 1
			end
		end
		return n
	end

	-- the eggs
	UI.clear(eggList)
	local all = petsOf(nil)
	eggButton(0, "All Pets", ("%d/%d found"):format(count(all), #all), "paw", filter == nil, function()
		filter = nil
		win.refresh()
	end)
	for i, egg in Config.EGGS do
		local list = petsOf(egg.id)
		eggButton(i, egg.name, ("%d/%d found"):format(count(list), #list), PetsWindow.eggIcon(egg), filter == egg.id, function()
			filter = egg.id
			win.refresh()
		end)
	end

	-- the critters, by rarity
	local egg = filter and Config.egg(filter)
	gridTitle.Text = if egg then egg.name else "All Pets"
	UI.clear(scroll)
	local list = petsOf(filter)
	picked = picked or (list[1] and list[1].id)
	local order = 0
	for _, rarity in ORDER do
		local group = {}
		for _, p in list do
			if p.rarity == rarity then
				table.insert(group, p)
			end
		end
		if #group == 0 then
			continue
		end
		local rc = Config.RARITY_COLORS[rarity]
		order += 1
		-- the rarity's ribbon
		local chip = Instance.new("Frame")
		chip.Name = "Head" .. rarity
		chip.BackgroundTransparency = 1
		chip.Size = UDim2.fromOffset(200, 36)
		chip.LayoutOrder = order
		chip.Parent = scroll
		local _r, rface = Skin.frame(chip, "ui_ribbon", Vector2.new(200, 36), { name = "Ribbon", boost = 1.2, tint = rc })
		UI.text(rface, ("%s %d/%d"):format(string.upper(rarity), count(group), #group), UDim2.new(1, 0, 1, 0), { stroke = 2 })
		order += 1
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, -10, 0, 0)
		row.LayoutOrder = order
		row.Parent = scroll
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(96, 104)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = row
		for i, p in group do
			local has = found[p.id] == true
			local cell = Skin.tile(if has then rc else UI.shade(rc, 0.55), p.id == picked, Vector2.new(96, 104))
			cell.Name = "Pet_" .. p.id
			cell.LayoutOrder = i
			local vp = PetsWindow.petView(cell, p.look, 76, UDim2.new(0.5, 0, 0, 2), Vector2.new(0.5, 0))
			if not has then
				vp.ImageColor3 = Color3.new(0, 0, 0)
			end
			UI.text(cell, if has then p.name else "???", UDim2.new(1, -8, 0, 22), { pos = UDim2.fromOffset(4, 74), stroke = 2, textSize = 13 })
			cell.MouseButton1Click:Connect(function()
				picked = p.id
				win.refresh()
			end)
			cell.Parent = row
		end
	end

	-- the big card: where to hatch it, and how often
	local p = picked and Config.pet(picked)
	local has = p ~= nil and found[p.id] == true
	PetsWindow.fillCard(card, p, has)
	card.empty.Text = "Pick a critter"
	card.stateText.Text = if has then "FOUND" else "NOT FOUND"
	card.state.BackgroundColor3 = if has then C.green else Color3.fromRGB(70, 70, 82)
	UI.clear(hatchList)
	if p then
		UI.text(hatchList, "HATCH IT FROM", UDim2.new(1, 0, 0, 22), { pos = UDim2.fromOffset(4, 2), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 200, 70), stroke = 2 })
		local y = 28
		for _, e in Config.EGGS do
			local odds = oneIn(e, p.id, d.hatchLuck or 1)
			if odds then
				UI.icon(hatchList, PetsWindow.eggIcon(e), 26, UDim2.fromOffset(2, y))
				UI.text(hatchList, e.name, UDim2.new(0.6, -30, 0, 24), { pos = UDim2.fromOffset(32, y + 1), align = Enum.TextXAlignment.Left, stroke = 2 })
				UI.text(hatchList, odds, UDim2.new(0.4, 0, 0, 24), { pos = UDim2.new(1, -4, 0, y + 1), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = Color3.fromRGB(255, 220, 90), stroke = 2 })
				y += 30
			end
		end
	end
end

return PetIndex
