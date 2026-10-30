-- UPGRADES (TAB in a run), remade in the grass-galaxy style (30 Oct, owner: "remake the ui / revamp so its not an
-- exact copy ... grass galaxy theme mix ... use forge gui", with a picture of Chop A Forest's upgrades screen as the
-- layout to follow, not to copy; and: the weapon skill trees go in here, a page a weapon, instead of their own SKILLS
-- window). Takes over the "Upgrades" window client/Windows drew as a pegboard of hanging tags.
--
-- The board, two by two, with a pager down its right edge:
--   * top left and bottom left: the run's upgrade sections (Config.UPGRADE_SECTIONS: Hands, Gear), each a starry
--     glass box with a ribbon title and its upgrades as glass cards: the picture, the level as glowing dots (one bar
--     for a one-step upgrade), the name, and the price under the card (green when you can pay it, red when not, gold
--     MAX when it's full)
--   * top right, one page at a time (the pager's arrows): every weapon's skill tree (shared/SkillTrees: three skills
--     of five pips, bought with the run's coins). Only the best weapon of the run learns; one you don't own this run is
--     LOCKED, one you've moved past says OLD; a weapon MASTERED for good has a gold ribbon and a crown. Sections that
--     don't fit on the left (the ride-on mowers' once they unlock) are pages there too.
--   * bottom right: the picked card big, with what it does, its level and BUY.
-- Picking a card selects it (a glowing frame); BUY sends the same "Buy" / "Skill" requests as before (the server
-- checks and charges). The window rebuilds on every refresh and keeps the picked card and the page.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Windows = require(script.Parent.Windows)

local UpgradesWindow = {}
local C = UI.colors
local Tree = if type(Config.SKILL_TREES) == "table" then Config.SKILL_TREES else nil
local player = Players.LocalPlayer

local SIZE = Vector2.new(1040, 610)
local PANEL = SIZE - Vector2.new(40, 40) -- the board's inside (UI.window: 20 px in from its edge)
local GAP = 16
local PAGER_W = 78
local BOX = Vector2.new(math.floor((PANEL.X - PAGER_W - GAP * 4) / 2), 236)
local ROW_Y = { 30, 30 + BOX.Y + 36 }
local CARD_H = 152
local GOLD = Color3.fromRGB(255, 205, 60)
local RED = Color3.fromRGB(255, 96, 96)
local CYAN = Color3.fromRGB(110, 220, 255)
local DOT_ON = Color3.fromRGB(150, 240, 80)
local DOT_OFF = Color3.fromRGB(52, 36, 104)
local WEAPON_BLUE = Color3.fromRGB(80, 170, 255)

-- each section's ribbon colour and picture
local SECTION = {
	Hands = { color = Color3.fromRGB(255, 150, 50), icon = "hands" },
	Tool = { color = WEAPON_BLUE, icon = "scissors" },
	Gear = { color = Color3.fromRGB(110, 210, 70), icon = "up_speed" },
	Mower = { color = WEAPON_BLUE, icon = "pushmower" },
}
local ICON = {
	hold = "hands", swing = "up_swing", grasp = "up_grasp", power = "up_power", speed = "up_speed", sell = "up_sell",
	deck = "mower_tractor", engine = "mower_rocket", fuelsaver = "mower_rusty",
}

local function icon(key: string?): string
	local id = key and Config.ICONS and Config.ICONS[key]
	if id and id ~= "" then
		return key :: string
	end
	return "upgrade"
end

local w = UI.window("Upgrades", "Upgrades", nil, { tabs = Windows.RUN_TABS, size = SIZE })
w.list.Visible = false
local panel = w.panel :: Frame

local holder = Instance.new("Frame")
holder.Name = "Galaxy"
holder.BackgroundTransparency = 1
holder.Size = UDim2.fromScale(1, 1)
holder.Parent = panel
w.pop = { holder }

-------------------------------------------------------------------------------------------------------------
-- the weapons' trees (State.data.skills, from server/SkillTrees.view: { inRun, best, trees = { [toolId] = { levels,
-- owned (this run), mastered (for good) } } })
-------------------------------------------------------------------------------------------------------------
local WEAPONS = {}
if Tree then
	for _, t in Config.TOOLS do
		if Tree.tree(t.id) then
			table.insert(WEAPONS, t)
		end
	end
end

local function skillsOf(d)
	local all = d and d.skills
	return if type(all) == "table" and type(all.trees) == "table" then all else nil
end

local function treeView(d, id: string)
	local all = skillsOf(d)
	local v = all and all.trees[id]
	if type(v) == "table" then
		return v
	end
	return { owned = false, mastered = false, levels = {} }
end

local function nextPip(d, id: string, skillId: string): (number?, boolean, string?)
	local v = treeView(d, id)
	local all = skillsOf(d)
	local run = {}
	for _, t in WEAPONS do
		run[t.id] = treeView(d, t.id).levels
	end
	local ok, why, price = Tree.check(id, skillId, {
		levels = v.levels,
		owned = v.owned == true,
		best = all ~= nil and all.best == id,
		coins = (d and d.run and d.run.coins) or 0,
		runSkills = run,
		inRun = all ~= nil and all.inRun == true,
	})
	return price, ok, why
end

-------------------------------------------------------------------------------------------------------------
-- small pieces
-------------------------------------------------------------------------------------------------------------
local function glassBox(parent: Instance, pos: Vector2, size: Vector2, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(pos.X, pos.Y)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.Parent = parent
	if Skin.has("gg_inset") then
		local art = Skin.frame(f, "gg_inset", size, { name = "Art", maxScale = 0.42 })
		art.Size = UDim2.fromScale(1, 1)
	else
		local bg = UI.frame({ size = UDim2.fromScale(1, 1), color = C.night, parent = f, radius = 18, outline = 3, name = "Art" })
		;(bg:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = C.leaf
	end
	return f
end

-- the ribbon title across a box's top edge, its picture on the left end
local function ribbon(box: Frame, text: string, color: Color3, pic: string, crown: boolean?)
	local width = math.min(BOX.X - 90, 110 + #text * 24)
	local r = Instance.new("Frame")
	r.Name = "Ribbon"
	r.BackgroundTransparency = 1
	r.Size = UDim2.fromOffset(width, 50)
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.new(0.5, 10, 0, 0)
	r.Parent = box
	local face: GuiObject = r
	if Skin.has("gg_ribbon") then
		local _art, f = Skin.frame(r, "gg_ribbon", Vector2.new(width, 50), { name = "Art", tint = color, maxScale = 0.34 })
		face = f
	else
		face = UI.frame({ size = UDim2.fromScale(1, 1), color = color, parent = r, radius = 12, outline = 3, name = "Art" })
	end
	UI.text(face, string.upper(text), UDim2.new(1, -36, 1, 0), { pos = UDim2.fromOffset(30, 0), stroke = 3, name = "Title" })
	local ic = UI.icon(r, pic, 64, UDim2.new(0, -18, 0.5, 0), Vector2.new(0, 0.5))
	ic.Rotation = -8
	if crown then
		local cr = UI.icon(r, "crown", 40, UDim2.new(1, 6, 0, -14), Vector2.new(1, 0))
		cr.Rotation = 12
	end
	UI.raise(r, 6)
end

-- level dots (one bar for a single-step upgrade); `width` is the row's width
local function levelRow(parent: Instance, level: number, max: number, pos: UDim2, width: number, dim: boolean?, gold: boolean?): Frame
	local row = Instance.new("Frame")
	row.Name = "Level"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = pos
	row.Parent = parent
	local on = if gold then GOLD else DOT_ON
	if max <= 1 then
		row.Size = UDim2.fromOffset(width, 16)
		local bar = UI.frame({ size = UDim2.fromScale(1, 1), color = DOT_OFF, parent = row, radius = 999, outline = 2, name = "Bar" })
		;(bar:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = C.outline
		if level >= 1 and not dim then
			local fill = UI.frame({ size = UDim2.fromScale(1, 1), color = on, parent = bar, radius = 999, outline = 0, name = "Fill" })
			UI.gradient(fill, on)
		end
		return row
	end
	local gap = 4
	local d = math.clamp(math.floor((width - gap * (max - 1)) / max), 8, 17)
	row.Size = UDim2.fromOffset(d * max + gap * (max - 1), d)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for i = 1, max do
		local lit = i <= level and not dim
		local dot = UI.frame({ size = UDim2.fromOffset(d, d), color = if lit then on else DOT_OFF, parent = row, radius = 999, outline = 2, name = "Dot" })
		dot.LayoutOrder = i
		;(dot:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = C.outline
		if lit then
			local shine = UI.frame({ size = UDim2.new(0.5, 0, 0.36, 0), pos = UDim2.fromScale(0.2, 0.12), color = Color3.new(1, 1, 1), parent = dot, radius = 999, outline = 0, name = "Shine" })
			shine.BackgroundTransparency = 0.45
		end
	end
	return row
end

local function glassCard(parent: Instance, size: Vector2, name: string, tint: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.Parent = parent
	if Skin.has("gg_card") then
		local art = Skin.frame(f, "gg_card", size, { name = "Art", maxScale = 0.3, tint = tint })
		art.Size = UDim2.fromScale(1, 1)
	else
		local art = UI.frame({ size = UDim2.fromScale(1, 1), color = C.glass, parent = f, radius = 18, outline = 3, name = "Art" })
		;(art:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = C.leaf
	end
	return f
end

-- an arrow made of two bars (no font glyph needed): up or down
local function chevron(parent: Instance, up: boolean, color: Color3)
	for _, side in { -1, 1 } do
		local bar = UI.frame({ size = UDim2.fromOffset(26, 9), color = color, parent = parent, radius = 999, outline = 2, name = "Chevron" })
		;(bar:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = C.outline
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, side * 8, 0.5, -3)
		bar.Rotation = (if up then 1 else -1) * side * 40
	end
end

-------------------------------------------------------------------------------------------------------------
-- what the cards are
-------------------------------------------------------------------------------------------------------------
-- One card's worth: an upgrade of a section, or a skill of a weapon.
type Item = {
	key: string, -- unique in the window
	kind: string, -- "upgrade" | "skill"
	id: string, -- the upgrade id / the skill id
	tool: string?, -- the weapon (skills)
	name: string,
	desc: string,
	pic: string,
	level: number,
	max: number,
	cost: number?, -- the next level's coins (nil when there's none)
	can: boolean, -- buyable right now
	why: string?, -- why not: "max" | "locked" | "past" | "lobby" | "oneARun" | "coins" | "soon"
	section: string, -- what the details box calls its group
	gold: boolean?, -- a mastered weapon's skill
	now: string?, -- "+64%" (skills)
	nxt: string?,
}

local function upgradeItems(section: string, d, locked: boolean): { Item }
	local out = {}
	local money = d.run.coins or 0
	for _, u in Config.UPGRADES do
		if u.section == section then
			local level = (d.run.upgrades and d.run.upgrades[u.id]) or 0
			local maxed = level >= u.max
			local cost = if maxed or locked then nil else Config.upgradeCost(u.id, level)
			local why = if locked then "soon" elseif maxed then "max" elseif money < (cost or 0) then "coins" else nil
			table.insert(out, {
				key = "u_" .. u.id,
				kind = "upgrade",
				id = u.id,
				name = u.name,
				desc = if locked then "Coming in a future update" else u.desc,
				pic = icon(ICON[u.id]),
				level = level,
				max = u.max,
				cost = cost,
				can = why == nil,
				why = why,
				section = section,
			})
		end
	end
	return out
end

local function skillItems(def, d): { Item }
	local out = {}
	local v = treeView(d, def.id)
	for _, sk in Tree.tree(def.id).skills do
		local level = Tree.level(v.levels, sk.id)
		local price, can, why = nextPip(d, def.id, sk.id)
		local stat = Tree.STATS[sk.id]
		table.insert(out, {
			key = "s_" .. def.id .. "_" .. sk.id,
			kind = "skill",
			id = sk.id,
			tool = def.id,
			name = sk.name,
			desc = sk.desc,
			pic = icon(stat and stat.icon),
			level = level,
			max = Tree.PIPS,
			cost = price,
			can = can,
			why = why,
			section = def.name .. " skills",
			gold = v.mastered == true,
			now = Tree.text(sk.id, level) .. " " .. (stat and stat.what or ""),
			nxt = if level < Tree.PIPS then Tree.text(sk.id, level + 1) else nil,
		})
	end
	return out
end

-- the word under a card that can't be bought, and its colour
local function statusOf(it: Item): (string?, Color3?)
	if it.why == "max" then
		return "MAX", GOLD
	elseif it.why == "soon" then
		return "SOON", CYAN
	elseif it.why == "locked" then
		return "LOCKED", C.dimText
	elseif it.why == "past" then
		return "OLD WEAPON", C.dimText
	elseif it.why == "lobby" then
		return "IN A RUN", C.dimText
	elseif it.why == "oneARun" then
		return "NEXT RUN", C.dimText
	end
	return nil, nil
end

-------------------------------------------------------------------------------------------------------------
-- building
-------------------------------------------------------------------------------------------------------------
local picked: string? = nil -- the picked card's key
local page = 1 -- the top-right box's page
local pageSetFor: string? = nil -- the run the page was chosen for (a new run starts at its best weapon again)
local details: Frame? = nil
local selectFrames: { [string]: GuiObject } = {}
local items: { [string]: Item } = {}

local function setPicked(key: string)
	picked = key
	for k, frame in selectFrames do
		frame.Visible = k == key
	end
end

local fillDetails: (Item?) -> ()

local function card(box: Frame, it: Item, x: number, size: Vector2)
	local dim = it.why == "soon" or it.why == "locked"
	local f = glassCard(box, size, "Card_" .. it.key, if it.gold then Color3.fromRGB(255, 226, 150) elseif dim then Color3.fromRGB(150, 150, 170) else nil)
	f.Position = UDim2.fromOffset(x, 36)
	-- the picked card's glowing frame (under the art)
	local glow = UI.frame({ size = UDim2.new(1, 12, 1, 12), pos = UDim2.fromOffset(-6, -6), color = if it.gold then GOLD else C.leaf, parent = f, radius = 26, outline = 3, name = "Picked" })
	glow.BackgroundTransparency = 0.55
	;(glow:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.new(1, 1, 1)
	glow.Visible = false
	selectFrames[it.key] = glow
	if dim then
		UI.icon(f, "lock", 56, UDim2.new(0.5, 0, 0, 22), Vector2.new(0.5, 0))
	else
		local pic = UI.icon(f, it.pic, math.min(72, size.X - 40), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
		Skin.bob(pic, 2.5, 1.4 + (#it.key % 4) * 0.2)
	end
	levelRow(f, it.level, it.max, UDim2.new(0.5, 0, 0, 96), size.X - 30, dim, it.gold)
	UI.text(f, it.name, UDim2.new(1, -14, 0, 22), { pos = UDim2.fromOffset(7, 118), stroke = 2.5, name = "Name" })
	-- the price under the card, or why there's none
	local price = Instance.new("Frame")
	price.Name = "Price_" .. it.key
	price.BackgroundTransparency = 1
	price.Size = UDim2.fromOffset(size.X + 20, 30)
	price.Position = UDim2.fromOffset(x - 10, 36 + size.Y + 4)
	price.Parent = box
	local word, color = statusOf(it)
	if word then
		UI.text(price, word, UDim2.fromScale(1, 1), { color = color, stroke = 3 })
	elseif it.cost then
		UI.icon(price, "coin", 26, UDim2.new(0.5, -4, 0.5, 0), Vector2.new(1, 0.5))
		UI.text(price, Format.short(it.cost), UDim2.new(0.5, 0, 1, 0), { pos = UDim2.new(0.5, 0, 0, 0), align = Enum.TextXAlignment.Left, color = if it.can then DOT_ON else RED, stroke = 3 })
	end
	-- the whole card is a button
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.Parent = f
	Skin.press(hit, f)
	hit.MouseButton1Click:Connect(function()
		UI.bounce(f)
		Sound.play("click")
		setPicked(it.key)
		fillDetails(it)
	end)
	UI.raise(f, 4)
	glow.ZIndex = 3
	hit.ZIndex = 20
end

local function cardsIn(box: Frame, list: { Item })
	local n = math.max(#list, 1)
	local cw = math.min(132, math.floor((BOX.X - 30 - (n - 1) * 12) / n))
	local total = cw * n + (n - 1) * 12
	local x0 = math.floor((BOX.X - total) / 2)
	for j, it in list do
		items[it.key] = it
		card(box, it, x0 + (j - 1) * (cw + 12), Vector2.new(cw, CARD_H))
	end
end

-- try to buy the picked card's next level; says why not if it can't be
local function buy(it: Item, big: GuiObject)
	if it.can then
		if it.kind == "skill" then
			State.fire("Skill", it.tool, it.id)
		else
			State.fire("Buy", "upgrade", it.id)
		end
		Skin.burst(big, 10, if it.gold then GOLD else C.leaf)
		return
	end
	Sound.play("denied")
	if it.why == "coins" and it.cost then
		local have = (State.data and State.data.run and State.data.run.coins) or 0
		UI.toast(("%s more coins needed"):format(Format.commas(math.ceil(it.cost - have))), "red")
	elseif it.why == "locked" then
		UI.toast("Buy this weapon in the run to open its skills!", "red")
	elseif it.why == "past" then
		UI.toast("Only your best weapon learns skills: this one is done for the run.", "red")
	elseif it.why == "oneARun" then
		UI.toast("One weapon can be maxed a run: this last pip waits for the next run.", "red")
	elseif it.why == "soon" then
		UI.toast(Config.MOWERS_LOCKED_TEXT or "Coming soon!", "yellow")
	elseif it.why == "max" then
		UI.toast(it.name .. " is maxed!", "yellow")
	end
end

fillDetails = function(it: Item?)
	local box = details
	if not box then
		return
	end
	for _, c in box:GetChildren() do
		if c.Name ~= "Art" then
			c:Destroy()
		end
	end
	if not it then
		UI.text(box, "Pick an upgrade", UDim2.new(1, -40, 0, 40), { pos = UDim2.fromOffset(20, BOX.Y / 2 - 20), color = C.dimText })
		return
	end
	local dim = it.why == "soon" or it.why == "locked"
	-- left: the card, big
	local big = glassCard(box, Vector2.new(168, 200), "Big", if it.gold then Color3.fromRGB(255, 226, 150) else nil)
	big.Position = UDim2.fromOffset(20, 24)
	if dim then
		UI.icon(big, "lock", 84, UDim2.new(0.5, 0, 0, 28), Vector2.new(0.5, 0))
	else
		local pic = UI.icon(big, it.pic, 104, UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0))
		Skin.bob(pic, 3, 1.6)
	end
	levelRow(big, it.level, it.max, UDim2.new(0.5, 0, 0, 136), 136, dim, it.gold)
	UI.text(big, it.name, UDim2.new(1, -16, 0, 26), { pos = UDim2.fromOffset(8, 160), stroke = 2.5 })
	Skin.sparkles(big, 0.7, if it.gold then GOLD else nil)
	UI.raise(big, 4)
	-- right: what it is
	local x = 204
	local right = BOX.X - x - 18
	UI.text(box, it.section, UDim2.fromOffset(right, 24), { pos = UDim2.fromOffset(x, 20), color = C.dimText, stroke = 2 })
	UI.text(box, string.upper(it.name), UDim2.fromOffset(right, 44), { pos = UDim2.fromOffset(x, 44), stroke = 4, name = "Headline" })
	UI.text(box, it.desc, UDim2.fromOffset(right, 40), { pos = UDim2.fromOffset(x, 88), color = C.starText, stroke = 2, textSize = 18 })
	local lv
	if dim then
		lv = ""
	elseif it.kind == "skill" then
		-- (what it gives now, and after the next pip)
		lv = ("Lv %d/%d   %s"):format(it.level, it.max, it.now or "") .. (if it.nxt then "  >  " .. it.nxt else "")
	elseif it.max > 1 then
		lv = ("Level %d / %d"):format(it.level, it.max)
	else
		lv = if it.level >= 1 then "Owned" else "Not owned yet"
	end
	UI.text(box, lv, UDim2.fromOffset(right, 26), { pos = UDim2.fromOffset(x, 130), color = if it.gold then GOLD else DOT_ON, stroke = 2.5 })
	-- BUY (or why not)
	local word = statusOf(it)
	local label, color
	if word then
		label, color = if it.why == "max" then "MAXED" else word, if it.why == "max" then GOLD else UI.wood.grey
	else
		label, color = "BUY  " .. Format.short(it.cost or 0), if it.can then C.green else UI.wood.grey
	end
	local btn = UI.button(box, label, color, UDim2.fromOffset(right, 58), function()
		buy(it, big)
	end, { pos = UDim2.fromOffset(x, 160), name = "Buy" })
	if not word then
		local lab = btn:FindFirstChild("Label") :: TextLabel
		lab.Size = UDim2.new(1, -60, 1, -18)
		lab.Position = UDim2.fromOffset(48, 3)
		UI.icon(btn, "coin", 34, UDim2.new(0, 18, 0.5, -4), Vector2.new(0, 0.5))
	end
	UI.raise(btn, 6)
	local money = (State.data and State.data.run and State.data.run.coins) or 0
	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	coins.BackgroundTransparency = 1
	coins.Size = UDim2.fromOffset(right, 26)
	coins.Position = UDim2.fromOffset(x, 222)
	coins.Parent = box
	UI.text(coins, "Your coins:", UDim2.new(0.55, 0, 1, 0), { align = Enum.TextXAlignment.Right, color = C.dimText, stroke = 2 })
	UI.icon(coins, "coin", 24, UDim2.new(0.55, 6, 0.5, 0), Vector2.new(0, 0.5))
	UI.text(coins, Format.commas(money), UDim2.new(0.45, -36, 1, 0), { pos = UDim2.new(0.55, 34, 0, 0), align = Enum.TextXAlignment.Left, color = DOT_ON, stroke = 2.5 })
end

-- The top-right box's pages: every weapon's tree, then the sections that don't fit on the left.
type Page = { kind: string, def: any?, section: string?, locked: boolean? }
local function pagesOf(d, extra: { { name: string, locked: boolean } }): { Page }
	local list: { Page } = {}
	if skillsOf(d) then
		for _, def in WEAPONS do
			table.insert(list, { kind = "weapon", def = def })
		end
	end
	for _, s in extra do
		table.insert(list, { kind = "section", section = s.name, locked = s.locked })
	end
	return list
end

-- the page a run opens on: the best weapon of the run (else the one in your hand)
local function homePage(d, pages: { Page }): number
	local all = skillsOf(d)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local held = tool and tool:GetAttribute("ToolId")
	local want = (all and all.best) or held
	for i, p in pages do
		if p.kind == "weapon" and p.def.id == want then
			return i
		end
	end
	return 1
end

local function pager(pages: { Page })
	local x = GAP * 3 + BOX.X * 2
	local col = Instance.new("Frame")
	col.Name = "Pager"
	col.BackgroundTransparency = 1
	col.Position = UDim2.fromOffset(x, ROW_Y[1] - 8)
	col.Size = UDim2.fromOffset(PAGER_W, ROW_Y[2] + BOX.Y - ROW_Y[1] + 8)
	col.Parent = holder
	local back = glassBox(col, Vector2.new(0, 0), Vector2.new(PAGER_W, col.Size.Y.Offset), "Track")
	back.Size = UDim2.fromScale(1, 1)
	local n = #pages
	local function turn(step: number)
		page = ((page - 1 + step) % n) + 1
		picked = "page" -- (the new page's first card)
		w.refresh()
	end
	local up = UI.button(col, "", Color3.fromRGB(110, 80, 200), UDim2.fromOffset(PAGER_W - 14, 70), function()
		turn(-1)
	end, { pos = UDim2.fromOffset(7, 8), name = "Up" })
	chevron(up, true, Color3.new(1, 1, 1))
	local down = UI.button(col, "", C.green, UDim2.fromOffset(PAGER_W - 14, 70), function()
		turn(1)
	end, { pos = UDim2.new(0, 7, 1, -78), name = "Down" })
	chevron(down, false, Color3.new(1, 1, 1))
	-- a leaf a page (bright for this one), and "2/7"
	local dots = Instance.new("Frame")
	dots.Name = "Dots"
	dots.BackgroundTransparency = 1
	dots.AnchorPoint = Vector2.new(0.5, 0.5)
	dots.Position = UDim2.new(0.5, 0, 0.5, -16)
	dots.Size = UDim2.fromOffset(40, math.min(n, 8) * 26)
	dots.Parent = col
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = dots
	for i = 1, math.min(n, 8) do
		local lf = UI.icon(dots, "leaf", 24, nil)
		lf.LayoutOrder = i
		lf.Rotation = -20
		if i ~= page and lf:IsA("ImageLabel") then
			lf.ImageTransparency = 0.6
		end
	end
	UI.text(col, ("%d/%d"):format(page, n), UDim2.fromOffset(PAGER_W, 30), { pos = UDim2.new(0, 0, 1, -116), stroke = 3, name = "Count" })
	UI.raise(col, 4)
	up.ZIndex, down.ZIndex = 8, 8
end

w.refresh = function()
	local d = State.data
	for _, c in holder:GetChildren() do
		c:Destroy()
	end
	table.clear(selectFrames)
	table.clear(items)
	details = nil
	if not d or not d.run then
		return
	end
	-- the sections: the first two on the left, the rest (and the locked mowers) as pages on the right
	local left, extra = {}, {}
	for _, s in Config.UPGRADE_SECTIONS do
		local entry = { name = s, locked = false }
		if #left < 2 then
			table.insert(left, entry)
		else
			table.insert(extra, entry)
		end
	end
	if Config.MOWERS_LOCKED and not table.find(Config.UPGRADE_SECTIONS, "Mower") then
		table.insert(extra, { name = "Mower", locked = true })
	end
	local pages = pagesOf(d, extra)
	local runKey = tostring(d.run.started or d.run.id or "run")
	if pageSetFor ~= runKey then
		pageSetFor = runKey
		page = homePage(d, pages)
	end
	page = math.clamp(page, 1, math.max(#pages, 1))
	local first: string? = nil
	local pageFirst: string? = nil
	local leftSlots = { Vector2.new(GAP, ROW_Y[1]), Vector2.new(GAP, ROW_Y[2]) }
	for i, s in left do
		local box = glassBox(holder, leftSlots[i], BOX, "Section_" .. s.name)
		local look = SECTION[s.name] or SECTION.Gear
		local list = upgradeItems(s.name, d, s.locked)
		cardsIn(box, list)
		first = first or (list[1] and list[1].key)
		local title = if s.name == "Tool" then "Tool - " .. (Config.TOOLS[d.run.tool] or Config.TOOLS[1]).name else s.name
		ribbon(box, title, look.color, look.icon)
	end
	local p = pages[page]
	if p then
		local box = glassBox(holder, Vector2.new(GAP * 2 + BOX.X, ROW_Y[1]), BOX, "Page")
		if p.kind == "weapon" then
			local def = p.def
			local v = treeView(d, def.id)
			local list = skillItems(def, d)
			cardsIn(box, list)
			pageFirst = list[1] and list[1].key
			local tree = Tree.tree(def.id)
			ribbon(box, def.name, if v.mastered then GOLD else WEAPON_BLUE, icon(tree and tree.icon), v.mastered == true)
			if v.mastered then
				local tag = UI.text(box, "★ MASTERED", UDim2.fromOffset(160, 24), { pos = UDim2.new(1, -170, 0, 10), color = GOLD, stroke = 2.5, align = Enum.TextXAlignment.Right })
				tag.ZIndex = 8
			end
		else
			local section = p.section :: string
			local look = SECTION[section] or SECTION.Gear
			local list = upgradeItems(section, d, p.locked == true)
			cardsIn(box, list)
			pageFirst = list[1] and list[1].key
			ribbon(box, section, look.color, look.icon)
		end
		if #pages > 1 then
			pager(pages)
		end
	end
	local det = glassBox(holder, Vector2.new(GAP * 2 + BOX.X, ROW_Y[2] - 6), Vector2.new(BOX.X, BOX.Y + 14), "Details")
	details = det
	local key = if picked == "page" then (pageFirst or first) elseif picked and items[picked] then picked else first
	if key then
		setPicked(key)
	end
	fillDetails(if key then items[key] else nil)
end

-- Open the window on a weapon's page (K, and server notes that point at the skills).
function UpgradesWindow.openSkills(toolId: string?)
	local d = State.data
	local all = skillsOf(d)
	local want = toolId or (all and all.best)
	if d and d.run and want then
		pageSetFor = tostring(d.run.started or d.run.id or "run")
		for i, p in pagesOf(d, {}) do
			if p.kind == "weapon" and p.def.id == want then
				page = i
				picked = "page"
			end
		end
	end
	UI.open("Upgrades")
end

-- the picked card's glow breathes
task.spawn(function()
	while true do
		task.wait(0.05)
		local t = os.clock()
		for _, g in selectFrames do
			if g.Visible then
				g.BackgroundTransparency = 0.5 + 0.15 * math.sin(t * 4)
			end
		end
	end
end)

return UpgradesWindow
