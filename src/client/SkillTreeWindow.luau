-- SKILL TREE (owner, 30 Oct: "an skill tree like chop a forest for every weapon ... when u max the skill tree for
-- said weapon make it gold so its like u earned something ... use the ui we already have here"; then: the pips are
-- bought with the run's coins and reset every run, MASTERED stays for good, and the trees replace the Upgrades
-- window's "Tool" section). Chop A Forest's Upgrades window, ours, in client/GemUpgrades' look: one weapon a page (the
-- arrows, or the row of weapons along the bottom), its three skills as cards with level pips, and the picked skill's
-- details (what it does, now > next, the price in coins, a big BUY) on the right.
--   * Only your best weapon learns (a weapon you've moved on from says OLD WEAPON); one you don't own in this run is
--     LOCKED; in the lobby every page says skills are bought in a run.
--   * A weapon MASTERED once (every pip full in some run) has a gold page (GOLD -> ORANGE like our titles) with a crown
--     and a MASTERED ribbon in every run after, even at 0 pips, and a "★ MASTERED" mark on its tile here and on its
--     hotbar slot (client/Hud's hotbar, marked from here: Hud is not changed). The first time gets a banner, confetti
--     and a gold burst (server/SkillTrees sends "skillMastered" only then).
-- The numbers are shared/SkillTrees (Config.SKILL_TREES); server/SkillTrees checks every buy, this only draws.
-- Opened with K or the SKILLS button: a badge in client/Hud's side column on a computer (added from here), a small
-- button beside the SETTINGS gear on a phone or tablet (the side column is full there: Roblox's jump button sits
-- under it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Confetti = require(script.Parent.Confetti)
local Fx = require(script.Parent.Fx)
local MenuFX = require(script.Parent.MenuFX)

local SkillTreeWindow = {}
local Tree = Config.SKILL_TREES
if type(Tree) ~= "table" then
	-- (a half-done copy into a place whose shared/Config lacks the SKILL_TREES line: no window, nothing else breaks)
	warn("[SkillTreeWindow] Config.SKILL_TREES is missing (shared/Config needs its require line): no skill trees")
	return SkillTreeWindow
end
local C = UI.colors
local W = UI.wood
local player = Players.LocalPlayer

local BLUE = Color3.fromRGB(40, 130, 240)
local NAVY = Color3.fromRGB(16, 40, 100)
local GOLD = Color3.fromRGB(255, 236, 110)
local ORANGE = Color3.fromRGB(255, 140, 30)
local AMBER = Color3.fromRGB(255, 196, 40) -- MAX / MASTERED buttons and ribbons
local GREY = Color3.fromRGB(110, 116, 132)
local MINT = Color3.fromRGB(150, 255, 120) -- bonus numbers on the blue cards, prices you can pay
local SHORT = Color3.fromRGB(255, 120, 110) -- a price you can't pay yet
local DIM = Color3.fromRGB(196, 200, 214) -- a price that isn't for now (lobby, locked, old weapon)
-- the title style (client/IntroUi's title card): gold on top, a sharp step to orange
local TITLE_GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, GOLD),
	ColorSequenceKeypoint.new(0.52, GOLD),
	ColorSequenceKeypoint.new(0.56, ORANGE),
	ColorSequenceKeypoint.new(1, UI.shade(ORANGE, 0.85)),
})
-- the insides of the cards: blue, gold once mastered (for good), grey while locked
type Theme = { top: Color3, bottom: Color3, base: Color3, box: Color3, rays: Color3, value: Color3 }
local THEME: { [string]: Theme } = {
	normal = { top = Color3.fromRGB(110, 190, 255), bottom = Color3.fromRGB(30, 100, 220), base = BLUE, box = Color3.fromRGB(20, 50, 130), rays = Color3.fromRGB(200, 235, 255), value = MINT },
	gold = { top = GOLD, bottom = ORANGE, base = AMBER, box = Color3.fromRGB(150, 70, 0), rays = Color3.fromRGB(255, 250, 215), value = Color3.new(1, 1, 1) },
	locked = { top = Color3.fromRGB(150, 156, 170), bottom = Color3.fromRGB(80, 86, 102), base = GREY, box = Color3.fromRGB(40, 44, 56), rays = Color3.fromRGB(205, 205, 215), value = Color3.fromRGB(215, 215, 225) },
}

-- the weapons with a tree, in shop order; and which one an icon is (client/Hud's hotbar names its icons by key)
local ORDER = {}
local BY_ICON: { [string]: string } = {}
for _, t in Config.TOOLS do
	local tree = Tree.tree(t.id)
	if tree then
		table.insert(ORDER, t)
		BY_ICON[tree.icon] = t.id
	end
end

-------------------------------------------------------------------------------------------------------------
-- the player's trees (State.data.skills, from server/SkillTrees.view: { inRun, best, trees = { [toolId] = { levels,
-- owned (this run), mastered (for good) } } }) and the run's coins (State.data.run.coins)
-------------------------------------------------------------------------------------------------------------
local function allOf(d)
	local all = d and d.skills
	return if type(all) == "table" and type(all.trees) == "table" then all else nil
end

local function toolView(d, id: string)
	local all = allOf(d)
	local v = all and all.trees[id]
	if type(v) == "table" then
		return v
	end
	return { owned = false, mastered = false, levels = {} }
end

local function coinsOf(d): number
	local run = d and d.run
	return if type(run) == "table" then tonumber(run.coins) or 0 else 0
end

local function isBest(d, id: string): boolean
	local all = allOf(d)
	return all ~= nil and all.best == id
end

local function inRun(d): boolean
	local all = allOf(d)
	return all ~= nil and all.inRun == true
end

-- every weapon's pips this run, for the one-full-tree-a-run rule
local function runSkills(d)
	local rs = {}
	for _, def in ORDER do
		rs[def.id] = toolView(d, def.id).levels
	end
	return rs
end

-- The next pip of a skill: (coins, can buy it now, why not: "lobby" | "locked" | "max" | "past" | "oneARun" |
-- "coins"), by the same rule the server buys with (shared/SkillTrees.check).
local function nextPip(d, id: string, skillId: string): (number?, boolean, string?)
	local v = toolView(d, id)
	local ok, why, price = Tree.check(id, skillId, {
		levels = v.levels,
		owned = v.owned == true,
		best = isBest(d, id),
		coins = coinsOf(d),
		runSkills = runSkills(d),
		inRun = inRun(d),
	})
	return price, ok, why
end

-- How many of a weapon's skills could take a pip right now (only ever the best weapon's).
local function affordable(d, id: string): number
	local n = 0
	for _, sk in Tree.TREES[id].skills do
		local _, can = nextPip(d, id, sk.id)
		if can then
			n += 1
		end
	end
	return n
end

-------------------------------------------------------------------------------------------------------------
-- the window
-------------------------------------------------------------------------------------------------------------
local w = UI.window("SkillTree", "Skill Tree", nil, { size = Vector2.new(1000, 600) })
w.list.Visible = false -- laid out below
local P = w.panel
local title = w.title :: TextLabel
title.Position = UDim2.fromOffset(60, -70)
UI.icon(w.frame, "star", 92, UDim2.fromOffset(-30, -76)).ZIndex = 9

-- the sunken box behind the cards, then one see-through layer per part (each rebuilt on its own)
UI.section(P, UDim2.fromOffset(928, 392), UDim2.fromOffset(16, 70))
local function layer(name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = P
	return f
end
local headerL = layer("Header", 4)
local infoL = layer("Info", 4)
local cardsL = layer("Cards", 4)
local detailL = layer("Detail", 4)
local stripL = layer("Weapons", 4)
local lockL = layer("Locked", 7)
w.pop = { cardsL, stripL } -- (UI.open pops these in)

local page = 1 -- index into ORDER
local picked: { [string]: string } = {} -- [toolId] = the skill whose details show
local lastKey = "" -- what the page was drawn for (the coins alone only update the number)
local coinLabel: TextLabel? = nil
local wasOpen = false
local openedOnce = false
local upgraded = false -- a pip was bought while open: a burst round your character when it closes
local celebrating: { [string]: boolean } = {} -- just mastered: the gold page bursts when it shows
local bumped: { tool: string, skill: string }? = nil -- the card whose pip was just bought

-- A white gradient-ready look turned gold (an ImageLabel's art or a drawn frame).
local function goldify(obj: Instance?, seq: ColorSequence?)
	if not obj or not obj:IsA("GuiObject") then
		return
	end
	if obj:IsA("ImageLabel") then
		obj.ImageColor3 = Color3.new(1, 1, 1)
	else
		obj.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	local g = obj:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	g.Color = seq or ColorSequence.new(GOLD, ORANGE)
	g.Rotation = 90
	g.Parent = obj
end

-- The inside of a card or of the details: the theme's gradient, mowed stripes, turning rays behind the picture.
local function cardInside(face: Frame, theme: Theme, raysSize: number, raysY: number)
	local inner = UI.frame({ size = UDim2.fromScale(1, 1), color = theme.base, parent = face, radius = 10, outline = 0, name = "Inner" })
	inner.ClipsDescendants = true
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(theme.top, theme.bottom)
	g.Rotation = 90
	g.Parent = inner
	Skin.stripes(inner, 5, 70)
	Skin.rays(inner, theme.rays, raysSize, UDim2.new(0.5, 0, 0, raysY), 20)
	return inner
end

-- "(coin) 1,300": the coin and the number in a row, centred in `parent`.
local function priceRow(parent: Instance, coins: number, h: number, color: Color3)
	local row = Instance.new("Frame")
	row.Name = "Price"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local ic = UI.icon(row, "coin", h, nil, nil)
	ic.LayoutOrder = 1
	local t = UI.text(row, Format.commas(coins), UDim2.fromOffset(0, h), { color = color, stroke = 2, textSize = math.floor(h * 0.8) })
	t.TextWrapped = false
	t.AutomaticSize = Enum.AutomaticSize.X
	t.LayoutOrder = 2
	return row
end

-- The colour of a price: green if you can buy it, red if only the coins are short, pale if it isn't for now.
local function priceColor(can: boolean, why: string?): Color3
	if can then
		return MINT
	elseif why == "coins" or why == "oneARun" then
		return SHORT
	end
	return DIM
end

-- the arrows: the weapon before / after (round the ends)
local function turn(step: number)
	page = (page - 1 + step) % #ORDER + 1
	lastKey = ""
	w.refresh()
end
local prevButton = UI.button(P, "◀", W.tabOn, UDim2.fromOffset(70, 54), function()
	turn(-1)
end, { pos = UDim2.fromOffset(18, 8), name = "Prev" })
UI.raise(prevButton, 5)
local nextButton = UI.button(P, "▶", W.tabOn, UDim2.fromOffset(70, 54), function()
	turn(1)
end, { pos = UDim2.new(1, -18, 0, 8), anchor = Vector2.new(1, 0), name = "Next" })
UI.raise(nextButton, 5)

-------------------------------------------------------------------------------------------------------------
-- the parts of a page
-------------------------------------------------------------------------------------------------------------
-- The weapon's name on a pill between the arrows (gold with a crown when mastered). (The window's title is left
-- alone: client/TextStyle, in another session's work, gives every big headline the title gradient.)
local function buildHeader(def, v, theme: Theme)
	UI.clear(headerL)
	Skin.pill(headerL, string.upper(def.name), theme.base, Tree.tree(def.id).icon, UDim2.fromOffset(300, 13), 360)
	if v.mastered then
		goldify(headerL:FindFirstChild("Header"))
		local crown = UI.icon(headerL, "crown", 66, UDim2.fromOffset(632, -2))
		crown.Rotation = 14
		crown.ZIndex = 8
		Skin.bob(crown, 3, 2)
	end
end

-- What the page says about the weapon in this run: a headline and a hint.
local function pageNote(d, def, v): (string, string, Color3)
	local have, total = Tree.pips(def.id, v.levels)
	local gold = "★ Mastered for good: it stays gold in every run."
	if not inRun(d) then
		return "BOUGHT IN A RUN", if v.mastered then gold else "Skills cost a run's coins and reset when it ends.", if v.mastered then GOLD else W.cream
	elseif not v.owned then
		return "LOCKED", ("Buy the %s in this run to train it."):format(def.name), W.cream
	elseif have >= total then
		return "MAXED!", "Every skill maxed this run. ★ Mastered for good!", GOLD
	elseif not isBest(d, def.id) then
		return "OLD WEAPON", "Only your best weapon learns: this tree is done for this run.", W.cream
	elseif Tree.fullCount(runSkills(d)) >= Tree.MAX_FULL_PER_RUN then
		return "ONE MAXED A RUN", "You've maxed a weapon this run: all but this tree's last pip.", W.cream
	elseif v.mastered then
		return "★ MASTERED", "Gold for good. Its pips are new each run: buy them again!", GOLD
	end
	return "THIS RUN", ("Pips cost coins and reset every run. Max all %d to master it!"):format(total), W.cream
end

-- The run's coins (a plate with a coin), what this weapon can do this run, and the tree's pips as a bar.
local function buildInfo(d, def, v)
	UI.clear(infoL)
	local plate, face = Skin.frame(infoL, "ui_plate", Vector2.new(200, 48), { pos = UDim2.fromOffset(64, 80), name = "Coins" })
	local amount = UI.text(face, Format.commas(coinsOf(d)), UDim2.new(1, -36, 1, -4), { pos = UDim2.fromOffset(30, 2), align = Enum.TextXAlignment.Left, stroke = 3 })
	amount.ZIndex = plate.ZIndex + 2
	coinLabel = amount
	local coin = UI.icon(infoL, "coin", 58, UDim2.fromOffset(34, 74))
	coin.ZIndex = plate.ZIndex + 3
	local head, hint, hintColor = pageNote(d, def, v)
	UI.text(infoL, head, UDim2.fromOffset(370, 22), { pos = UDim2.fromOffset(282, 80), align = Enum.TextXAlignment.Left, color = if v.mastered then GOLD else Color3.fromRGB(255, 186, 60), stroke = 2.5 })
	UI.text(infoL, hint, UDim2.fromOffset(370, 20), { pos = UDim2.fromOffset(282, 104), align = Enum.TextXAlignment.Left, color = hintColor, stroke = 1.5 })
	local have, total = Tree.pips(def.id, v.levels)
	local _bar, fill, label = Skin.bar(infoL, Vector2.new(262, 44), if v.owned then C.green else GREY, { pos = UDim2.fromOffset(666, 80), name = "Pips" })
	fill.Size = UDim2.fromScale(math.clamp(have / math.max(1, total), 0, 1), 1)
	label.Text = if have >= total then "MAXED!" elseif v.mastered then ("★ %d / %d PIPS"):format(have, total) else ("%d / %d PIPS"):format(have, total)
	if v.mastered then
		goldify(fill)
	end
end

-- The price of a card's next pip at its foot (MAXED once full).
local function costTag(card: GuiObject, d, def, sk)
	local price, can, why = nextPip(d, def.id, sk.id)
	local tag = UI.frame({ size = UDim2.fromOffset(150, 34), pos = UDim2.new(0.5, 0, 0, 244), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(14, 22, 48), parent = card, radius = 999, outline = 0, name = "Cost" })
	tag.BackgroundTransparency = 0.35
	if why == "max" or not price then
		UI.text(tag, "MAXED", UDim2.new(1, -10, 1, -8), { pos = UDim2.fromOffset(5, 4), color = GOLD, stroke = 2 })
		return
	end
	priceRow(tag, price, 24, priceColor(can, why))
end

-- One skill card: the level ribbon, its picture on rays, its name, what it does now, the pips and the next price.
local function buildCard(i: number, d, def, sk, v, theme: Theme)
	local stat = Tree.STATS[sk.id]
	local level = Tree.level(v.levels, sk.id)
	local card = Instance.new("TextButton")
	card.Name = "Skill_" .. sk.id
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundTransparency = 1
	card.Size = UDim2.fromOffset(196, 316)
	card.Position = UDim2.fromOffset(30 + (i - 1) * 212, 134)
	card.LayoutOrder = i
	card.Parent = cardsL
	local _art, face = Skin.frame(card, "ui_pcard", Vector2.new(196, 316), { name = "Art", maxScale = 0.21 })
	cardInside(face, theme, 210, 62)
	local maxed = level >= Tree.PIPS
	local lv = Skin.frame(card, "ui_ribbon", Vector2.new(100, 30), { pos = UDim2.fromOffset(-14, -10), name = "Level", boost = 1.2, tint = if maxed then AMBER else NAVY })
	lv.Rotation = -8
	UI.text(lv, if maxed then "MAX" else ("LV %d/%d"):format(level, Tree.PIPS), UDim2.new(1, -30, 1, -10), { pos = UDim2.fromOffset(15, 2), stroke = 1.5 })
	local pic = UI.icon(card, stat.icon, 84, UDim2.new(0.5, 0, 0, 22), Vector2.new(0.5, 0))
	Skin.bob(pic, 3, 1.6 + i * 0.2)
	UI.text(card, string.upper(sk.name), UDim2.new(1, -30, 0, 26), { pos = UDim2.fromOffset(15, 112), stroke = 3 })
	local box = UI.frame({ size = UDim2.new(1, -36, 0, 58), pos = UDim2.fromOffset(18, 144), color = theme.box, parent = card, radius = 10, outline = 0, name = "Info" })
	box.BackgroundTransparency = 0.25
	UI.text(box, stat.what, UDim2.new(1, -10, 0, 18), { pos = UDim2.fromOffset(5, 5), color = Color3.fromRGB(220, 230, 255), stroke = 1 })
	UI.text(box, Tree.text(sk.id, level), UDim2.new(1, -10, 0, 28), { pos = UDim2.fromOffset(5, 25), color = theme.value, stroke = 2 })
	local pips = UI.pips(card, level, Tree.PIPS, UDim2.new(0.5, 0, 0, 214), 160)
	if v.mastered then
		for _, p in pips:GetChildren() do
			if p:IsA("Frame") then
				p.BackgroundColor3 = GOLD
			end
		end
	end
	costTag(card, d, def, sk)
	if picked[def.id] == sk.id then
		local ring = UI.frame({ size = UDim2.new(1, 12, 1, 12), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.new(1, 1, 1), parent = card, radius = 20, outline = 4, name = "Picked" })
		ring.BackgroundTransparency = 1
		local st = ring:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = if v.mastered then Color3.fromRGB(255, 250, 220) else Color3.new(1, 1, 1)
		end
	end
	if v.mastered then
		Skin.sparkles(card, 0.9, Color3.fromRGB(255, 245, 190))
	end
	Skin.press(card)
	card.MouseButton1Click:Connect(function()
		picked[def.id] = sk.id
		lastKey = ""
		w.refresh()
	end)
	return card
end

-- Try to buy the next pip (the server checks it all again; this only saves a pointless request and says why not).
local function tryBuy(def, sk)
	local d = State.data
	local price, can, why = nextPip(d, def.id, sk.id)
	if can then
		State.fire("Skill", def.id, sk.id)
		return
	end
	Sound.play("denied")
	if why == "lobby" then
		UI.toast("Weapon skills are bought in a run, with its coins.", "red")
	elseif why == "locked" then
		UI.toast(("Buy the %s in this run to open its skill tree!"):format(def.name), "red")
	elseif why == "past" then
		UI.toast(("Only your best weapon learns skills: the %s's tree is done for this run."):format(def.name), "red")
	elseif why == "max" then
		UI.toast(sk.name .. " is maxed!", "yellow")
	elseif why == "oneARun" then
		UI.toast("One weapon can be maxed a run: this last pip waits for the next run.", "red")
	elseif why == "coins" and price then
		UI.toast(("%s more coins needed"):format(Format.commas(math.ceil(price - coinsOf(d)))), "red")
	end
end

-- What the big button says for the picked skill's next pip.
type Look = { text: string, color: Color3 }
local BUTTON: { [string]: Look } = {
	lobby = { text = "IN A RUN", color = W.grey },
	locked = { text = "LOCKED", color = W.grey },
	past = { text = "OLD WEAPON", color = W.grey },
	max = { text = "MAXED", color = AMBER },
	oneARun = { text = "ONE A RUN", color = W.grey },
	coins = { text = "BUY", color = W.grey },
}

-- The picked skill, big: what it does, now > next, the price and BUY (or IN A RUN / LOCKED / OLD WEAPON / MAXED).
local function buildDetail(d, def, v, theme: Theme)
	UI.clear(detailL)
	local sk = Tree.skill(def.id, picked[def.id]) or Tree.tree(def.id).skills[1]
	local stat = Tree.STATS[sk.id]
	local level = Tree.level(v.levels, sk.id)
	local holder = Instance.new("Frame")
	holder.Name = "Details"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(264, 316)
	holder.Position = UDim2.fromOffset(666, 134)
	holder.Parent = detailL
	local _art, face = Skin.frame(holder, "ui_pcard", Vector2.new(264, 316), { name = "Art", maxScale = 0.21 })
	cardInside(face, theme, 240, 58)
	local pic = UI.icon(holder, stat.icon, 92, UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
	Skin.bob(pic, 3, 1.4)
	UI.text(holder, string.upper(sk.name), UDim2.new(1, -40, 0, 26), { pos = UDim2.fromOffset(20, 104), stroke = 3 })
	UI.text(holder, sk.desc, UDim2.new(1, -44, 0, 34), { pos = UDim2.fromOffset(22, 131), color = Color3.fromRGB(232, 240, 255), stroke = 1.5, textSize = 16 })
	-- what it does now, and with the next pip
	local box = UI.frame({ size = UDim2.new(1, -44, 0, 50), pos = UDim2.fromOffset(22, 167), color = theme.box, parent = holder, radius = 10, outline = 0, name = "Values" })
	box.BackgroundTransparency = 0.25
	UI.text(box, stat.what, UDim2.new(1, -12, 0, 16), { pos = UDim2.fromOffset(6, 4), color = Color3.fromRGB(220, 230, 255), stroke = 1 })
	local now = Tree.text(sk.id, level)
	local values = if level >= Tree.PIPS then now .. "  MAX" else ("%s  ▶  %s"):format(now, Tree.text(sk.id, level + 1))
	UI.text(box, values, UDim2.new(1, -12, 0, 26), { pos = UDim2.fromOffset(6, 20), color = theme.value, stroke = 2 })
	local price, can, why = nextPip(d, def.id, sk.id)
	if price then
		local slot = Instance.new("Frame")
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.new(1, -40, 0, 28)
		slot.Position = UDim2.fromOffset(20, 220)
		slot.Parent = holder
		priceRow(slot, price, 28, priceColor(can, why))
	end
	local look: Look = if can then { text = "BUY", color = C.green } else BUTTON[why or ""] or BUTTON.coins
	local b = UI.button(holder, look.text, look.color, UDim2.fromOffset(200, 48), function()
		tryBuy(def, sk)
	end, { pos = UDim2.new(0.5, 0, 1, -18), anchor = Vector2.new(0.5, 1), name = "Buy" })
	UI.raise(b, 6)
	if v.mastered then
		UI.ribbon(holder, "MASTERED", AMBER)
	end
end

-- A "★ MASTERED" tag along the foot of a tile (the window's weapon row, the HUD's hotbar).
local function masteredTag(parent: GuiObject, width: number, y: number, z: number): Frame
	local tag = UI.frame({ size = UDim2.fromOffset(width, 18), pos = UDim2.new(0.5, 0, 1, y), anchor = Vector2.new(0.5, 1), color = AMBER, parent = parent, radius = 999, outline = 2, name = "Mastered" })
	goldify(tag)
	tag.ZIndex = z
	local t = UI.text(tag, "★ MASTERED", UDim2.new(1, -6, 1, -2), { pos = UDim2.fromOffset(3, 1), stroke = 1.5, textSize = 12 })
	t.ZIndex = z + 1
	return tag
end

-- Every weapon along the bottom: gold with a crown and "★ MASTERED" when mastered (for good), blue when owned in
-- this run, a lock when not, a red dot when a pip is ready.
local function buildStrip(d)
	UI.clear(stripL)
	local size, gap = 68, 12
	local x0 = 480 - (#ORDER * size + (#ORDER - 1) * gap) / 2
	for i, def in ORDER do
		local v = toolView(d, def.id)
		local tile = Skin.tile(if v.mastered then AMBER elseif v.owned then BLUE else GREY, i == page, Vector2.new(size, size))
		tile.Name = "Weapon_" .. def.id
		tile.Position = UDim2.fromOffset(x0 + (i - 1) * (size + gap), 480)
		tile.LayoutOrder = i
		tile.Parent = stripL
		if v.mastered then
			goldify(tile:FindFirstChild("Art"))
		end
		local ic = UI.icon(tile, Tree.tree(def.id).icon, 50, UDim2.fromScale(0.5, 0.46), Vector2.new(0.5, 0.5))
		if not v.owned then
			if ic:IsA("ImageLabel") then
				ic.ImageTransparency = 0.45
			end
			UI.icon(tile, "lock", 28, UDim2.new(1, 4, 1, 4), Vector2.new(1, 1))
		end
		if v.mastered then
			local crown = UI.icon(tile, "crown", 32, UDim2.new(1, 8, 0, -12), Vector2.new(1, 0))
			crown.Rotation = 14
			masteredTag(tile, 78, 12, tile.ZIndex + 3)
		end
		local dot = Skin.dot(tile, UDim2.fromOffset(6, 6), 18)
		dot.Visible = affordable(d, def.id) > 0
		tile.MouseButton1Click:Connect(function()
			page = i
			lastKey = ""
			w.refresh()
		end)
	end
end

-- A dark sheet over the cards when the page's weapon can't learn here: in the lobby (skills are bought in a run), or
-- not owned in this run (LOCKED, Chop A Forest's look). A mastered weapon's sheet says so in gold.
local function buildLock(d, def, v)
	UI.clear(lockL)
	local lobby = not inRun(d)
	if v.owned and not lobby then
		return
	end
	local f = UI.frame({ size = UDim2.fromOffset(624, 316), pos = UDim2.fromOffset(28, 134), color = if v.mastered then Color3.fromRGB(60, 34, 6) else Color3.fromRGB(20, 22, 34), parent = lockL, radius = 18, outline = 0, name = "Locked" })
	f.BackgroundTransparency = 0.3
	local icon = UI.icon(f, if lobby then "coin" else "lock", 100, UDim2.new(0.5, 0, 0, 40), Vector2.new(0.5, 0))
	Skin.bob(icon, 3, 1.5)
	local head = UI.text(f, if lobby then "IN A RUN" else "LOCKED", UDim2.fromOffset(420, 58), { pos = UDim2.new(0.5, 0, 0, 146), anchor = Vector2.new(0.5, 0), stroke = 4 })
	if v.mastered then
		local g = Instance.new("UIGradient")
		g.Color = TITLE_GOLD
		g.Rotation = 90
		g.Parent = head
	end
	local sub = if lobby then "Skills are bought with a run's coins, and reset when it ends" else ("Buy the %s in this run to train its skills"):format(def.name)
	UI.text(f, sub, UDim2.new(1, -60, 0, 26), { pos = UDim2.new(0.5, 0, 0, 208), anchor = Vector2.new(0.5, 0), color = W.cream, stroke = 2 })
	if v.mastered then
		UI.text(f, "★ MASTERED for good: gold in every run", UDim2.new(1, -60, 0, 26), { pos = UDim2.new(0.5, 0, 0, 242), anchor = Vector2.new(0.5, 0), color = GOLD, stroke = 2 })
	end
end

-------------------------------------------------------------------------------------------------------------
-- drawing it
-------------------------------------------------------------------------------------------------------------
-- What a page shows apart from the coin number: rebuilt only when this changes.
local function pageKey(d): string
	local parts = { tostring(page), tostring(inRun(d)), tostring(allOf(d) and allOf(d).best) }
	for _, def in ORDER do
		local v = toolView(d, def.id)
		table.insert(parts, def.id .. (if v.owned then "o" else "-") .. (if v.mastered then "m" else "-") .. (picked[def.id] or ""))
		for _, sk in Tree.TREES[def.id].skills do
			local _, can, why = nextPip(d, def.id, sk.id)
			table.insert(parts, Tree.level(v.levels, sk.id) .. (if can then "+" else "") .. (why or ""))
		end
	end
	return table.concat(parts, "|")
end

-- The skill to show first: the first one that isn't maxed.
local function firstOpen(def, v): string
	local skills = Tree.tree(def.id).skills
	for _, sk in skills do
		if Tree.level(v.levels, sk.id) < Tree.PIPS then
			return sk.id
		end
	end
	return skills[1].id
end

-- Opening the window shows the weapon in your hand, or (the first time) your best one this run.
local function pickPage(d)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local held = tool and tool:GetAttribute("ToolId")
	local first = not openedOnce
	openedOnce = true
	local best = allOf(d) and allOf(d).best
	for i, def in ORDER do
		if def.id == held then
			page = i
			return
		end
	end
	if first then
		for i, def in ORDER do
			if def.id == best then
				page = i
			end
		end
	end
end

local function rebuild(d)
	local def = ORDER[page]
	local v = toolView(d, def.id)
	local theme = if v.mastered then THEME.gold elseif v.owned then THEME.normal else THEME.locked
	if not Tree.skill(def.id, picked[def.id]) then
		picked[def.id] = firstOpen(def, v)
	end
	buildHeader(def, v, theme)
	buildInfo(d, def, v)
	UI.clear(cardsL)
	for i, sk in Tree.tree(def.id).skills do
		buildCard(i, d, def, sk, v, theme)
	end
	buildDetail(d, def, v, theme)
	buildStrip(d)
	buildLock(d, def, v)
	-- a pip just bought: its card bounces with a burst of sparkles; a tree just mastered: every card bursts gold
	local b = bumped
	if b and b.tool == def.id then
		bumped = nil
		local card = cardsL:FindFirstChild("Skill_" .. b.skill) :: GuiObject?
		if card then
			UI.bounce(card)
			Skin.burst(card, 10, if v.mastered then GOLD else nil)
		end
	end
	if celebrating[def.id] and v.mastered then
		celebrating[def.id] = nil
		for _, card in cardsL:GetChildren() do
			if card:IsA("GuiObject") then
				UI.bounce(card)
				Skin.burst(card, 14, GOLD)
			end
		end
	end
end

w.refresh = function()
	local d = State.data
	if not wasOpen then
		pickPage(d)
		lastKey = ""
	end
	local key = pageKey(d)
	local label = coinLabel
	if key == lastKey and label and label.Parent then
		label.Text = Format.commas(coinsOf(d))
		return
	end
	lastKey = key
	rebuild(d)
end

UI.onWindowChanged.Event:Connect(function(name)
	local open = name == "SkillTree"
	if wasOpen and not open and upgraded then
		upgraded = false
		local v = toolView(State.data, ORDER[page].id)
		MenuFX.atCharacter(if v.mastered then GOLD else BLUE, true)
	end
	wasOpen = open
end)

-------------------------------------------------------------------------------------------------------------
-- the first time a weapon is mastered: a gold banner (the title style, punched in with a shockwave), confetti,
-- fanfare (server/SkillTrees sends "skillMastered" only that once; maxing it again in a later run doesn't)
-------------------------------------------------------------------------------------------------------------
local banner: Frame? = nil
local function goldBanner(text: string, sub: string)
	if banner then
		banner:Destroy()
	end
	local root = Instance.new("Frame")
	root.Name = "MasteredBanner"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.26)
	root.Size = UDim2.fromOffset(1000, 190)
	root.ZIndex = 45
	root.Parent = UI.gui
	banner = root
	local crown = UI.icon(root, "crown", 96, UDim2.new(0.5, 0, 0, -44), Vector2.new(0.5, 0))
	crown.ZIndex = 46
	Skin.bob(crown, 4, 2.4)
	local name = UI.text(root, text, UDim2.new(1, 0, 0, 104), { pos = UDim2.fromOffset(0, 46), stroke = 6 })
	name.ZIndex = 46
	local g = Instance.new("UIGradient")
	g.Color = TITLE_GOLD
	g.Rotation = 90
	g.Parent = name
	name.Rotation = -5
	TweenService:Create(name, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	local s = UI.text(root, sub, UDim2.new(1, 0, 0, 36), { pos = UDim2.fromOffset(0, 152), stroke = 3.5 })
	s.ZIndex = 46
	local sc = Instance.new("UIScale")
	sc.Scale = 2.2
	sc.Parent = root
	TweenService:Create(sc, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(0.2, function()
		if not root.Parent then
			return
		end
		local ring = Instance.new("Frame")
		ring.Name = "Shockwave"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.new(0.5, 0, 0, 98)
		ring.Size = UDim2.fromOffset(120, 120)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 44
		ring.Parent = root
		UI.corner(ring, 999)
		local edge = Instance.new("UIStroke")
		edge.Thickness = 10
		edge.Color = GOLD
		edge.Parent = ring
		TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quart), { Size = UDim2.fromOffset(1300, 1300) }):Play()
		TweenService:Create(edge, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Transparency = 1, Thickness = 2 }):Play()
		task.delay(0.6, function()
			ring:Destroy()
		end)
	end)
	task.delay(4.2, function()
		if not root.Parent then
			return
		end
		local fade = TweenInfo.new(0.35)
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, fade, { Transparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, fade, { ImageTransparency = 1 }):Play()
			end
		end
		task.wait(0.4)
		root:Destroy()
		if banner == root then
			banner = nil
		end
	end)
end

local function celebrate(toolId: string)
	local def = nil
	for i, t in ORDER do
		if t.id == toolId then
			def = t
			page = i
		end
	end
	if not def then
		return
	end
	celebrating[toolId] = true
	lastKey = ""
	goldBanner(string.upper(def.name) .. " MASTERED!", "Every skill maxed: your " .. def.name .. " is gold for good!")
	Sound.play("victory")
	Confetti.burst(160)
	task.delay(0.7, Confetti.burst, 110)
	MenuFX.atCharacter(GOLD, true)
end

State.on("fx", function(kind: string, p: any)
	if kind == "skillPip" and type(p) == "table" and type(p.tool) == "string" and type(p.skill) == "string" then
		bumped = { tool = p.tool, skill = p.skill }
		upgraded = true
		lastKey = ""
	elseif kind == "skillMastered" and type(p) == "table" and type(p.tool) == "string" then
		celebrate(p.tool)
	elseif kind == "skillHarvest" and type(p) == "table" and typeof(p.pos) == "Vector3" then
		-- a Harvest skill dropped one more bundle
		Fx.floatText(p.pos, "+1 BUNDLE", MINT, 0.75)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- the "★ MASTERED" tag on a mastered weapon's slot in client/Hud's hotbar (Hud rebuilds its slots when the tools
-- change: Hud.Hotbar.SlotN.Body.Icon_<key>, the key being the tree's icon; the tag goes with the slot)
-------------------------------------------------------------------------------------------------------------
local function markHotbar()
	local hud = UI.gui:FindFirstChild("Hud")
	local hotbar = hud and hud:FindFirstChild("Hotbar")
	if not hotbar then
		return
	end
	for _, slot in hotbar:GetChildren() do
		local body = slot:FindFirstChild("Body")
		if body and body:IsA("GuiObject") then
			local id = nil
			for _, c in body:GetChildren() do
				local key = string.match(c.Name, "^Icon_(.+)$")
				id = id or (key and BY_ICON[key])
			end
			local want = id ~= nil and toolView(State.data, id).mastered == true
			local tag = body:FindFirstChild("Mastered")
			if want and not tag then
				masteredTag(body, 80, 6, 6)
			elseif tag and not want then
				tag:Destroy()
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the SKILLS button, K, and the red dot / note when your best weapon can learn something
-------------------------------------------------------------------------------------------------------------
local SIDE_STEP = 126 -- one badge in client/Hud's side column (116 tall, 10 apart)
local badge: GuiButton? = nil -- in the side column (computer)
local touchButton: Frame? = nil -- beside the SETTINGS gear (phone, tablet)
local dot: Frame? = nil
local anyReady = false

local function openWindow()
	UI.open("SkillTree")
end

-- The log-slice badge client/Hud's side buttons wear (Hud's roundButton), with a K key tag.
local function sideBadge(): TextButton
	local b = Instance.new("TextButton")
	b.Name = "SKILLS"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(112, 116)
	b.LayoutOrder = 3 -- (after UPGRADES / STATS; NEWS is 4)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = b
	local _badgeArt, face = Skin.frame(body, "ui_badge", Vector2.new(98, 96), { pos = UDim2.fromOffset(7, 0), stretch = false, name = "Badge" })
	Skin.shine(face, 20, 13)
	UI.icon(face, "star", 58, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local tag = UI.frame({ size = UDim2.fromOffset(30, 28), pos = UDim2.fromOffset(110, 2), anchor = Vector2.new(1, 0), color = Color3.fromRGB(58, 34, 16), parent = body, radius = 8, outline = 2.5, name = "Key" })
	local st = tag:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = Color3.fromRGB(28, 16, 8)
	end
	UI.gradient(tag, Color3.fromRGB(70, 42, 20))
	UI.text(tag, "K", UDim2.new(1, -6, 1, -6), { pos = UDim2.fromOffset(3, 3), stroke = 1.5 })
	UI.text(body, "SKILLS", UDim2.fromOffset(124, 26), { pos = UDim2.new(0.5, 0, 0, 86), anchor = Vector2.new(0.5, 0), stroke = 3.5 })
	dot = Skin.dot(body, UDim2.fromOffset(16, 14))
	;(dot :: Frame).Visible = anyReady
	Skin.press(b, body)
	b.MouseButton1Click:Connect(function()
		Sound.play("click")
		openWindow()
	end)
	return b
end

-- The small round button beside the SETTINGS gear (the same size as the gear, its name under it).
local function gearSideButton(hud: Instance): Frame
	local holder = Instance.new("Frame")
	holder.Name = "SkillsButton"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(84, 74)
	holder.Parent = hud
	local b = UI.button(holder, "", AMBER, UDim2.fromOffset(50, 50), openWindow, { pos = UDim2.fromOffset(42, 0), anchor = Vector2.new(0.5, 0), name = "SkillsButton" })
	local ic = UI.icon(b, "star", 38, UDim2.fromScale(0.5, 0.45), Vector2.new(0.5, 0.5))
	ic.ZIndex = b.ZIndex + 2
	UI.text(holder, "SKILLS", UDim2.fromOffset(84, 20), { pos = UDim2.fromOffset(0, 52), stroke = 2 })
	dot = Skin.dot(holder, UDim2.fromOffset(64, 4), 18)
	;(dot :: Frame).Visible = anyReady
	return holder
end

-- Put the button where it belongs (Hud rebuilds its side column when the mode changes, so this runs again then).
local function placeButton()
	local hud = UI.gui:FindFirstChild("Hud")
	local side = hud and hud:FindFirstChild("SideButtons")
	if not hud or not side or not side:IsA("GuiObject") then
		return
	end
	-- (Hud puts the column at the top, anchored by its top, on touch screens)
	local touch = UI.touch == true or side.AnchorPoint.Y < 0.25
	if touch then
		if badge then
			badge:Destroy()
			badge = nil
		end
		if not touchButton or not touchButton.Parent then
			touchButton = gearSideButton(hud)
		end
		local nextTo = hud:FindFirstChild("Settings") or hud:FindFirstChild("Potato")
		if touchButton and nextTo and nextTo:IsA("GuiObject") then
			local want = nextTo.Position + UDim2.fromOffset(90, 0)
			if touchButton.Position ~= want then
				touchButton.Position = want
			end
		end
		return
	end
	if touchButton then
		touchButton:Destroy()
		touchButton = nil
	end
	if not badge or badge.Parent ~= side then
		local b = sideBadge()
		b.Parent = side
		badge = b
	end
	-- the column is sized for Hud's own buttons: one step more for this one
	local n = 0
	for _, c in side:GetChildren() do
		if c:IsA("GuiButton") then
			n += 1
		end
	end
	local want = UDim2.new(side.Size.X.Scale, side.Size.X.Offset, 0, n * SIDE_STEP)
	if side.Size ~= want then
		side.Size = want
	end
end

task.spawn(function()
	local hud = UI.gui:WaitForChild("Hud", 60)
	local side = hud and hud:WaitForChild("SideButtons", 60)
	if not side then
		return
	end
	local function later()
		task.defer(placeButton)
	end
	side.ChildRemoved:Connect(later)
	side.ChildAdded:Connect(later)
	side:GetPropertyChangedSignal("Size"):Connect(later)
	side:GetPropertyChangedSignal("AnchorPoint"):Connect(later)
	placeButton()
	local hotbar = (hud :: Instance):WaitForChild("Hotbar", 10)
	if hotbar then
		hotbar.ChildAdded:Connect(function()
			task.defer(markHotbar)
		end)
	end
	-- (the SETTINGS gear appears a moment later and moves with the screen: keep beside it)
	while true do
		task.wait(1)
		placeButton()
		markHotbar()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.K then
		openWindow()
	end
end)

-- The red dot on the button while your best weapon can learn something, and a note the first time it can (once a
-- weapon: coins come in all the time, so the dot does the rest).
local noted: { [string]: boolean } = {}
local seenData = false
local lastNote = 0
State.on("data", function(d)
	local any = false
	for _, def in ORDER do
		local now = affordable(d, def.id) > 0
		any = any or now
		if seenData and now and not noted[def.id] and os.clock() - lastNote > 20 and not UI.isOpen("SkillTree") then
			noted[def.id] = true
			lastNote = os.clock()
			UI.toast(("★ Your %s can learn a skill! %s"):format(def.name, if UI.touch then "Tap SKILLS" else "Press K"), "yellow")
		end
	end
	seenData = true
	anyReady = any
	if dot then
		dot.Visible = any
	end
	markHotbar()
end)

return SkillTreeWindow
