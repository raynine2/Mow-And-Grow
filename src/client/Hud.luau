-- The always-on screen, laid out like Chop A Forest:
--   left: big coin + gem counters   bottom-left: backpack "3/5"     bottom: tool hotbar
--   right: round wooden badge buttons (run: SHOP R, UPGRADES TAB; lobby: PETS P, SHOP R, STATS TAB, NEWS J)
--   top-left: quest tracker, and the Potato Mode button beside it
--   top-centre: day / night bar (ReplicatedStorage DayPhase/DayLeft/DayLength)
--   top-right: run timer, area name, AREA n/8, % cleared and the next area (or the boss bar during a fight)
--   centre: a small crosshair in a run while the camera is in first person
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Skin = require(script.Parent.Skin)
local Potato = require(script.Parent.Potato)

local Hud = {}
local C = UI.colors
local player = Players.LocalPlayer

-- our own hotbar replaces Roblox's backpack bar
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local root = Instance.new("Frame")
root.Name = "Hud"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = UI.gui

-- HUD pieces hidden because an open window covers them (see onWindowChanged below), each with the visibility it
-- gets back when the window closes. Code that shows or hides a HUD piece goes through show(), so a piece that
-- changes while it's tucked away (the hotbar filling, the quest finishing) comes back in the right state.
local tucked: { [GuiObject]: boolean } = {}
local function show(h: GuiObject, on: boolean)
	if tucked[h] ~= nil then
		tucked[h] = on
	else
		h.Visible = on
	end
end

-------------------------------------------------------------------------------------------------------------
-- currencies (left, middle)
-------------------------------------------------------------------------------------------------------------
-- A wooden plate with the big icon overlapping its left end and the number on it; a light streak sweeps across
-- it now and then. Gems get a green "+" that opens the gem shop.
local function counter(y: number, icon: string, plus: boolean?)
	local f = Instance.new("Frame")
	f.Name = "Counter_" .. icon
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(300, 78)
	f.Position = UDim2.new(0, 10, 0.5, y)
	f.Parent = root
	local plate, face = Skin.frame(f, "ui_plate", Vector2.new(250, 62), { pos = UDim2.fromOffset(40, 8), name = "Plate" })
	Skin.shine(face, 5, if icon == "gem" then 2.5 else 0)
	local t = UI.text(face, "0", UDim2.new(1, -46, 1, -4), { pos = UDim2.fromOffset(42, 2), align = Enum.TextXAlignment.Left, stroke = 3.5 })
	t.ZIndex = plate.ZIndex + 2
	local ic = UI.icon(f, icon, 78, UDim2.fromOffset(0, 0))
	ic.ZIndex = plate.ZIndex + 3
	if plus then
		local p = UI.button(f, "+", C.green, UDim2.fromOffset(40, 40), function()
			UI.open("Store")
		end, { pos = UDim2.fromOffset(278, 18), name = "Plus" })
		p.ZIndex = plate.ZIndex + 3
		Skin.press(p)
	end
	return f, t, ic
end
local coinBox, coinText, coinIcon = counter(-56, "coin")
local gemBox, gemText, gemIcon = counter(30, "gem", true)

-------------------------------------------------------------------------------------------------------------
-- backpack (bottom-left)
-------------------------------------------------------------------------------------------------------------
local bag = Instance.new("Frame")
bag.Name = "Backpack"
bag.BackgroundTransparency = 1
bag.Size = UDim2.fromOffset(250, 100)
bag.Position = UDim2.new(0, 10, 1, -110)
bag.Parent = root
local bagFace = select(2, Skin.frame(bag, "ui_plate", Vector2.new(190, 60), { pos = UDim2.fromOffset(52, 26), name = "Plate" }))
local bagText = UI.text(bagFace, "0/5", UDim2.new(1, -50, 1, -4), { pos = UDim2.fromOffset(46, 2), align = Enum.TextXAlignment.Left, stroke = 3.5 })
local bagIcon = UI.icon(bag, "backpack", 96, UDim2.fromOffset(0, 0))
bagIcon.ZIndex = 3
Skin.bob(bagIcon, 2, 1.6)

-------------------------------------------------------------------------------------------------------------
-- quest tracker (top-left, under Roblox's buttons)
-------------------------------------------------------------------------------------------------------------
local quest = Instance.new("Frame")
quest.Name = "Quest"
quest.BackgroundTransparency = 1
quest.Size = UDim2.fromOffset(330, 136)
quest.Position = UDim2.fromOffset(14, 66)
quest.Parent = root
-- a cream card in a wooden frame: scroll icon, "QUEST 2/8", the goal, a candy progress bar and a hint
local questFace = select(2, Skin.frame(quest, "ui_card", Vector2.new(330, 136), { name = "Card" }))
local BROWN = Color3.fromRGB(110, 62, 30)
local questIcon = UI.icon(quest, "quest", 58, UDim2.fromOffset(-6, -14))
questIcon.ZIndex = 4
Skin.bob(questIcon, 2, 1.3)
local questNum = UI.text(questFace, "QUEST 1/8", UDim2.new(1, -40, 0, 18), { pos = UDim2.fromOffset(40, 0), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 160, 40), stroke = 2 })
local questTitle = UI.text(questFace, "", UDim2.new(1, -4, 0, 26), { pos = UDim2.fromOffset(2, 20), align = Enum.TextXAlignment.Left, color = BROWN, stroke = 0 })
;(questTitle:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
local _, questFill, questCount = Skin.bar(questFace, Vector2.new(250, 30), C.green, { pos = UDim2.fromOffset(0, 48), name = "Bar" })
local questHint = UI.text(questFace, "", UDim2.new(1, -4, 0, 16), { pos = UDim2.fromOffset(2, 80), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(140, 96, 60), stroke = 0 })
;(questHint:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false

-------------------------------------------------------------------------------------------------------------
-- Potato Mode (top-left, beside the quest card): low graphics for slow devices (client/Potato), saved
-------------------------------------------------------------------------------------------------------------
local POTATO_OFF = Color3.fromRGB(150, 120, 90)
local potato = Instance.new("Frame")
potato.Name = "Potato"
potato.BackgroundTransparency = 1
potato.Size = UDim2.fromOffset(84, 74)
potato.Position = UDim2.fromOffset(14 + 330 + 10, 66)
potato.Parent = root
local potatoButton = UI.button(potato, "🥔", POTATO_OFF, UDim2.fromOffset(50, 50), function()
	Potato.toggle()
	UI.toast(if Potato.on then "🥔 Potato Mode ON: low graphics, smoother on slow devices" else "Potato Mode OFF: full graphics", if Potato.on then "green" else nil)
end, { pos = UDim2.fromOffset(42, 0), anchor = Vector2.new(0.5, 0), name = "PotatoButton" })
Skin.press(potatoButton)
local potatoText = UI.text(potato, "POTATO OFF", UDim2.fromOffset(84, 20), { pos = UDim2.fromOffset(0, 52), stroke = 2 })
local function showPotato(on: boolean)
	UI.setButton(potatoButton, "🥔", if on then C.green else POTATO_OFF)
	potatoText.Text = if on then "POTATO ON" else "POTATO OFF"
	potatoText.TextColor3 = if on then C.green else Color3.new(1, 1, 1)
end
showPotato(Potato.on)
Potato.changed(showPotato)

-------------------------------------------------------------------------------------------------------------
-- run info (top-right): timer, zone, progress / boss bar
-------------------------------------------------------------------------------------------------------------
local info = Instance.new("Frame")
info.Name = "RunInfo"
info.BackgroundTransparency = 1
info.Size = UDim2.fromOffset(320, 176)
info.Position = UDim2.new(1, -14, 0, 54)
info.AnchorPoint = Vector2.new(1, 0)
info.Parent = root
-- the timer floats above a cream card that holds the area name, AREA n/8, the cleared bar and what's next
local timerText = UI.text(info, "0:00", UDim2.fromOffset(150, 42), { pos = UDim2.new(1, -6, 0, 0), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, stroke = 3.5 })
local watch = UI.icon(info, "stopwatch", 46, UDim2.new(1, -156, 0, -2))
Skin.bob(watch, 1.5, 3)
local infoFace = select(2, Skin.frame(info, "ui_card", Vector2.new(320, 132), { pos = UDim2.fromOffset(0, 44), name = "Card" }))
local pin = UI.icon(infoFace, "pin", 34, UDim2.fromOffset(-2, -4))
local zoneText = UI.text(infoFace, "", UDim2.new(1, -150, 0, 26), { pos = UDim2.fromOffset(36, 0), align = Enum.TextXAlignment.Left, color = BROWN, stroke = 0 })
;(zoneText:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
local areaText = UI.text(infoFace, "AREA 1/8", UDim2.fromOffset(120, 18), { pos = UDim2.new(1, 0, 0, 4), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = Color3.fromRGB(255, 160, 40), stroke = 2 })
local _, fill, trackText = Skin.bar(infoFace, Vector2.new(250, 34), C.green, { pos = UDim2.fromOffset(0, 30), name = "Bar" })
local fillGrad = fill:FindFirstChildOfClass("UIGradient") :: UIGradient
local nextText = UI.text(infoFace, "", UDim2.new(1, -4, 0, 18), { pos = UDim2.fromOffset(2, 70), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(140, 96, 60), stroke = 0 })
;(nextText:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false

-- Keep clear of Roblox's own screen bits, which don't shrink with our UIScale: the quest scroll sits just below the
-- top bar (Roblox logo, menu, chat) and the run card steps left of the player list (top-right on a computer).
local function dodgeCoreUi()
	local sc = UI.gui:FindFirstChildOfClass("UIScale")
	local s = if sc then sc.Scale else 1
	local inset = game:GetService("GuiService"):GetGuiInset().Y
	quest.Position = UDim2.fromOffset(14, math.max(66, (inset + 2) / s + 14))
	potato.Position = UDim2.fromOffset(14 + 330 + 10, quest.Position.Y.Offset)
	local listOn = false
	pcall(function()
		listOn = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
	end)
	local list = if listOn and not UserInputService.TouchEnabled then 190 / s else 0
	info.Position = UDim2.new(1, -14 - list, 0, 54)
end
dodgeCoreUi()
local uiScale = UI.gui:FindFirstChildOfClass("UIScale")
if uiScale then
	uiScale:GetPropertyChangedSignal("Scale"):Connect(dodgeCoreUi)
end

-------------------------------------------------------------------------------------------------------------
-- round side buttons (right) with key badges
-------------------------------------------------------------------------------------------------------------
local side = Instance.new("Frame")
side.Name = "SideButtons"
side.BackgroundTransparency = 1
side.Size = UDim2.fromOffset(120, 260)
side.Position = UDim2.new(1, -16, 0.5, 30)
side.AnchorPoint = Vector2.new(1, 0.5)
side.Parent = root
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 10)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Parent = side

-- A log-slice badge (ui_badge art, leaves and clover drawn in) with the icon bobbing on its face, a light streak
-- sweeping across now and then, a dark key tag, the name below and a red dot for "something new".
local sideDots: { [string]: Frame } = {}
local function roundButton(label: string, icon: string, key: string, window: string, order: number)
	local b = Instance.new("TextButton")
	b.Name = label
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(112, 116)
	b.LayoutOrder = order
	b.Parent = side
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = b
	local badge, face = Skin.frame(body, "ui_badge", Vector2.new(98, 96), { pos = UDim2.fromOffset(7, 0), stretch = false, name = "Badge" })
	local _ = badge
	Skin.shine(face, 6, order * 0.7)
	local ic = UI.icon(face, icon, 58, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	Skin.bob(ic, 2, 2.2)
	local tag = UI.frame({ size = UDim2.fromOffset(if #key > 1 then 44 else 30, 28), pos = UDim2.fromOffset(110, 2), anchor = Vector2.new(1, 0), color = Color3.fromRGB(58, 34, 16), parent = body, radius = 8, outline = 2.5, name = "Key" })
	;(tag:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(28, 16, 8)
	UI.gradient(tag, Color3.fromRGB(70, 42, 20))
	UI.text(tag, key, UDim2.new(1, -6, 1, -6), { pos = UDim2.fromOffset(3, 3), stroke = 1.5 })
	UI.text(body, label, UDim2.fromOffset(124, 26), { pos = UDim2.new(0.5, 0, 0, 86), anchor = Vector2.new(0.5, 0), stroke = 3.5 })
	sideDots[window] = Skin.dot(body, UDim2.fromOffset(16, 14))
	Skin.press(b, body)
	b.MouseButton1Click:Connect(function()
		Sound.play("click")
		UI.open(window)
	end)
	return b
end
-- Other code can light a side button's dot (the News window when there's unread news, for example).
function Hud.setDot(window: string, on: boolean)
	local d = sideDots[window]
	if d then
		d.Visible = on
	end
end

local function sideButtons(mode: string)
	UI.clear(side)
	roundButton("PETS", "paw", "P", "Pets", 0)
	roundButton("SHOP", "basket", "R", "Store", 1)
	if mode == "Run" then
		roundButton("UPGRADES", "upgrade", "TAB", "Upgrades", 2)
		side.Size = UDim2.fromOffset(124, 2 * 126)
	else
		roundButton("STATS", "clipboard", "TAB", "Stats", 2)
		roundButton("NEWS", "newspaper", "J", "News", 4)
		side.Size = UDim2.fromOffset(124, 4 * 126)
	end
end

-------------------------------------------------------------------------------------------------------------
-- hotbar (bottom centre): every tool you own this run, in shop order; press 1-7 or click to equip / unequip
-------------------------------------------------------------------------------------------------------------
local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.BackgroundTransparency = 1
hotbar.Size = UDim2.fromOffset(90, 80)
hotbar.Position = UDim2.new(0.5, 0, 1, -12)
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Parent = root
local hotLayout = Instance.new("UIListLayout")
hotLayout.FillDirection = Enum.FillDirection.Horizontal
hotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotLayout.Padding = UDim.new(0, 8)
hotLayout.Parent = hotbar
local slotName = UI.text(root, "", UDim2.fromOffset(260, 20), { pos = UDim2.new(0.5, 0, 1, -116), anchor = Vector2.new(0.5, 0), stroke = 2 })

local TOOL_ICON = { Hands = "hands", Scissors = "scissors", Sickle = "sickle", PushMower = "pushmower", WeedWhacker = "whacker", MegaScythe = "scythe", LaserMower = "lasermower" }
local TOOL_ORDER = {}
for i, def in Config.TOOLS do
	TOOL_ORDER[def.id] = i
end

-- The tools you hold or carry, in shop order.
local function ownedTools(): { Tool }
	local list = {}
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") and (t:GetAttribute("ToolId") or t:GetAttribute("GunId")) then
					table.insert(list, t)
				end
			end
		end
	end
	-- the boss-crate gun goes last
	table.sort(list, function(a, b)
		return (TOOL_ORDER[a:GetAttribute("ToolId")] or 99) < (TOOL_ORDER[b:GetAttribute("ToolId")] or 99)
	end)
	return list
end

-- Equip slot `index` (or put it away if it's already in your hand). No index = your best tool.
local function toggleTool(index: number?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local tools = ownedTools()
	local want = if index then tools[index] else tools[#tools]
	if not want then
		return
	end
	if want.Parent == char then
		hum:UnequipTools()
	else
		hum:EquipTool(want)
	end
end

-- One hotbar slot: a wooden tile, and a gold tile that takes over (with sparkles and a grow) while it's held.
type Slot = { wood: GuiObject, gold: GuiObject, grow: UIScale, on: boolean, stop: (() -> ())? }
local function buildSlot(i: number, t: Tool): Slot
	local b = Instance.new("TextButton")
	b.Name = "Slot" .. i
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(84, 84)
	b.LayoutOrder = i
	b.Parent = hotbar
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = b
	local grow = Instance.new("UIScale")
	grow.Name = "Grow"
	grow.Parent = body
	local wood = Skin.frame(body, "ui_tile", Vector2.new(78, 80), { pos = UDim2.fromOffset(3, 2), stretch = false, name = "Wood" })
	local gold = Skin.frame(body, "ui_tile_gold", Vector2.new(78, 80), { pos = UDim2.fromOffset(3, 2), stretch = false, name = "Gold" })
	gold.Visible = false
	local ic = UI.icon(body, TOOL_ICON[t:GetAttribute("ToolId")] or "coin", 56, UDim2.fromScale(0.5, 0.47), Vector2.new(0.5, 0.5))
	ic.ZIndex = 3
	local num = UI.frame({ size = UDim2.fromOffset(26, 26), pos = UDim2.fromOffset(-2, -4), color = Color3.fromRGB(58, 34, 16), parent = body, radius = 999, outline = 2.5, name = "Num" })
	;(num:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(28, 16, 8)
	UI.text(num, tostring(i), UDim2.new(1, -6, 1, -6), { pos = UDim2.fromOffset(3, 3), stroke = 1.5 })
	num.ZIndex = 4
	Skin.press(b, body)
	b.MouseButton1Click:Connect(function()
		Sound.play("click")
		toggleTool(i)
	end)
	return { wood = wood, gold = gold, grow = grow, on = false }
end

local function setHeld(slot: Slot, on: boolean)
	if slot.on == on then
		return
	end
	slot.on = on
	slot.wood.Visible = not on
	slot.gold.Visible = on
	TweenService:Create(slot.grow, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if on then 1.14 else 1 }):Play()
	if slot.stop then
		slot.stop()
		slot.stop = nil
	end
	if on then
		Skin.burst(slot.gold, 5)
		slot.stop = Skin.sparkles(slot.gold, 0.7)
	end
end

local slots: { [Tool]: Slot } = {}
local shownKey = ""
task.spawn(function()
	while true do
		task.wait(0.25)
		local tools = ownedTools()
		local ids = {}
		for _, t in tools do
			table.insert(ids, t:GetAttribute("ToolId") or t:GetAttribute("GunId"))
		end
		local key = table.concat(ids, ",")
		show(hotbar, #tools > 0)
		if key ~= shownKey then
			shownKey = key
			for _, s in slots do
				if s.stop then
					s.stop()
				end
			end
			UI.clear(hotbar)
			table.clear(slots)
			hotbar.Size = UDim2.fromOffset(math.max(1, #tools) * 92, 84)
			for i, t in tools do
				slots[t] = buildSlot(i, t)
			end
		end
		local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
		for t, s in slots do
			setHeld(s, t == held)
		end
		slotName.Text = if held then held.Name else ""
	end
end)

-------------------------------------------------------------------------------------------------------------
-- fuel (above the hotbar, while driving) + party start button (lobby)
-------------------------------------------------------------------------------------------------------------
local fuel, fuelFill, fuelText = Skin.bar(root, Vector2.new(320, 42), C.orange, { pos = UDim2.new(0.5, 0, 1, -124), anchor = Vector2.new(0.5, 1), name = "Fuel" })
fuelText.Text = "FUEL"
fuel.Visible = false

local startBtn = UI.button(root, "START NOW", C.green, UDim2.fromOffset(240, 62), function()
	State.fire("Party", "start")
end, { pos = UDim2.new(0.5, 0, 1, -30), anchor = Vector2.new(0.5, 1), name = "StartNow" })
startBtn.Visible = false
local function updateHost()
	startBtn.Visible = State.mode == "Lobby" and player:GetAttribute("PartyHost") == true
end
player:GetAttributeChangedSignal("PartyHost"):Connect(updateHost)

-------------------------------------------------------------------------------------------------------------
-- updates
-------------------------------------------------------------------------------------------------------------
local shownGems, shownCoins = 0, 0
local function countTo(label: TextLabel, from: number, to: number, prefix: string?)
	local pre = prefix or ""
	if from == to then
		label.Text = pre .. Format.commas(to)
		return
	end
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(function(x)
		label.Text = pre .. Format.commas(x)
	end)
	local t = TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = to })
	t.Completed:Connect(function()
		label.Text = pre .. Format.commas(to)
		v:Destroy()
	end)
	t:Play()
end

-- a gain: the icon pops, the plate glints and the amount floats up off it
local gemsSeen, bagWasFull = false, false
local function gained(box: GuiObject, icon: GuiObject, text: string, color: Color3)
	UI.bounce(icon)
	Skin.floatText(box, text, color)
	Skin.burst(icon, 3)
end

local currentMode = ""
local function applyMode(mode: string)
	if mode == currentMode then
		return
	end
	currentMode = mode
	local isRun = mode == "Run"
	show(coinBox, isRun)
	show(bag, isRun)
	show(info, isRun)
	show(quest, isRun)
	sideButtons(mode)
	updateHost()
	Sound.music(if isRun then "musicRun" else "musicLobby")
end

State.on("data", function(d)
	applyMode(d.mode)
	if d.gems ~= shownGems then
		countTo(gemText, shownGems, d.gems)
		if d.gems > shownGems and gemsSeen then
			gained(gemBox, gemIcon, "+" .. Format.short(d.gems - shownGems), Color3.fromRGB(110, 210, 255))
		end
		shownGems = d.gems
	end
	gemsSeen = true
	UI.setGems(d.gems)
	if d.run then
		if d.run.coins ~= shownCoins then
			countTo(coinText, shownCoins, d.run.coins)
			if d.run.coins > shownCoins and shownCoins > 0 then
				gained(coinBox, coinIcon, "+" .. Format.short(d.run.coins - shownCoins), Color3.fromRGB(255, 220, 70))
			end
			shownCoins = d.run.coins
		end
		-- bundles still lying on the ground count toward the bag too (they're reserved for you)
		local full = not d.endless and d.run.carry + (d.run.ground or 0) >= d.carryMax
		bagText.Text = if d.endless then d.run.carry .. "/∞" else d.run.carry .. "/" .. d.carryMax
		bagText.TextColor3 = if full then C.red else Color3.new(1, 1, 1)
		if full ~= bagWasFull and bagIcon:IsA("ImageLabel") then
			bagWasFull = full
			TweenService:Create(bagIcon, TweenInfo.new(0.25), { ImageColor3 = if full then Color3.fromRGB(255, 150, 140) else Color3.new(1, 1, 1) }):Play()
		end
		local q = d.run.quest
		show(quest, q ~= nil)
		if q then
			questNum.Text = ("QUEST %d/%d"):format(q.index, q.total)
			questTitle.Text = q.title
			questHint.Text = q.hint or ""
			questFill.Size = UDim2.fromScale(math.clamp(q.progress / math.max(1, q.goal), 0, 1), 1)
			questCount.Text = ("%s/%s"):format(Format.short(q.progress), Format.short(q.goal))
		end
	end
end)

-- the timer shows your own run time (server/Run counts it); it ticks here between updates
local runTime, runTimeAt = -1, 0
State.on("data", function(d)
	if d.run and d.run.time then
		runTime, runTimeAt = d.run.time, os.clock()
	end
end)
State.on("world", function(w)
	if w.mode ~= "Run" or w.loading then
		return
	end
	zoneText.Text = w.name
	local zones = w.zones or #Config.ZONES
	areaText.Text = ("AREA %d/%d"):format(w.zone or 1, zones)
	local nextZone = Config.ZONES[(w.zone or 1) + 1]
	nextText.Text = if (w.zone or 1) >= zones or not nextZone then "Last area!" else "Mow it all to open " .. nextZone.name
	if w.boss then
		-- the boss's health has its own big bar at the top (BossFx); this corner just says what's on
		fill.BackgroundColor3 = C.red
		fillGrad.Color = ColorSequence.new(UI.shade(C.red, 1.15), UI.shade(C.red, 0.85))
		fill.Size = UDim2.fromScale(1, 1)
		trackText.Text = "BOSS FIGHT!"
	else
		fill.BackgroundColor3 = C.green
		fillGrad.Color = ColorSequence.new(UI.shade(C.green, 1.15), UI.shade(C.green, 0.85))
		local pct = w.cut / math.max(1, w.total)
		fill.Size = UDim2.fromScale(math.clamp(pct, 0, 1), 1)
		trackText.Text = string.format("%.1f%% cleared", pct * 100)
	end
	pin.Visible = true
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		if currentMode == "Run" and runTime >= 0 then
			timerText.Text = Format.clock(runTime + math.min(os.clock() - runTimeAt, 5))
		end
	end
end)

State.on("notify", function(text, color)
	UI.toast(text, color)
end)

State.on("driving", function(model: Model?)
	fuel.Visible = model ~= nil
end)
State.on("fuel", function(f: number, max: number)
	local ratio = if max > 0 then math.clamp(f / max, 0, 1) else 0
	fuelFill.Size = UDim2.fromScale(math.max(ratio, 0.02), 1)
	fuelFill.BackgroundColor3 = if ratio < 0.2 then C.red else C.orange
	fuelText.Text = if f <= 0 then "OUT OF GAS! Refuel at a pump" else ("FUEL %d / %d"):format(math.ceil(f), max)
end)

State.on("fx", function(kind, d)
	if kind == "bagFull" then
		if (d.ground or 0) > 0 and State.data and State.data.run and State.data.run.carry < State.data.carryMax then
			UI.notice("Pick up your bundles!", "Walk over the bundles on the ground to fill your bag", "bundle")
		else
			UI.notice("Your backpack is full!", "Walk onto the sell pad to sell your bundles", "backpack")
		end
		local base = bag.Position
		for i = 1, 6 do
			bag.Position = base + UDim2.fromOffset(if i % 2 == 0 then 6 else -6, 0)
			task.wait(0.04)
		end
		bag.Position = base
	elseif kind == "locked" then
		UI.notice(d.title, d.sub, "lock")
	elseif kind == "quest" then
		UI.notice("Quest complete!", d.title .. "   +$" .. Format.short(d.reward), "coin")
	end
end)

-------------------------------------------------------------------------------------------------------------
-- keys: R = shop, P = pets, TAB = upgrades (run) / stats (lobby), J = news, 1-7 = tools
-------------------------------------------------------------------------------------------------------------
local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven }
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		UI.open("Store")
	elseif input.KeyCode == Enum.KeyCode.P then
		UI.open("Pets")
	elseif input.KeyCode == Enum.KeyCode.Tab then
		UI.open(if currentMode == "Run" then "Upgrades" else "Stats")
	elseif input.KeyCode == Enum.KeyCode.J then
		UI.open("News")
	else
		local n = table.find(NUMBER_KEYS, input.KeyCode)
		if n then
			toggleTool(n)
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- crosshair (screen centre): a ring with a dot, in a run while the camera is in first person
-------------------------------------------------------------------------------------------------------------
local cross = Instance.new("Frame")
cross.Name = "Crosshair"
cross.BackgroundTransparency = 1
cross.Size = UDim2.fromOffset(26, 26)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Visible = false
cross.Parent = root
UI.corner(cross, 999)
UI.stroke(cross, 2.5, Color3.new(1, 1, 1)).Transparency = 0.15
UI.frame({ size = UDim2.fromOffset(6, 6), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.new(1, 1, 1), parent = cross, radius = 999, outline = 0, name = "Dot" })
local windowOpen = false
-- HUD pieces that would poke out from under an open window (the gem counter beside the Pets board, the quest card
-- under a wide one) step aside while it's open and come back when it closes. The side buttons stay: they switch
-- windows.
local function untuck()
	for h, on in tucked do
		h.Visible = on
	end
	table.clear(tucked)
end
UI.onWindowChanged.Event:Connect(function(name)
	windowOpen = name ~= nil
	untuck()
	if not name then
		return
	end
	task.defer(function()
		local w = UI.gui:FindFirstChild(name .. "Window") or UI.gui:FindFirstChild(name .. "Popup")
		if not w or not w:IsA("GuiObject") then
			return
		end
		-- the board's own rectangle at full size (it pops in from smaller and slides up from 40 px lower, so undo
		-- its bounce scale and reach a bit further up)
		local k = 1
		for _, bs in w:GetChildren() do
			if bs:IsA("UIScale") and bs.Scale > 0.05 then
				k *= bs.Scale
			end
		end
		local centre = w.AbsolutePosition + w.AbsoluteSize * w.AnchorPoint
		local full = w.AbsoluteSize / k
		local a0 = centre - full * w.AnchorPoint - Vector2.new(30, 70)
		local a1 = a0 + full + Vector2.new(60, 100)
		for _, h in root:GetChildren() do
			if h:IsA("GuiObject") and h.Visible and h.Name ~= "SideButtons" and h.AbsoluteSize.X > 0 then
				local b0, b1 = h.AbsolutePosition, h.AbsolutePosition + h.AbsoluteSize
				if a0.X < b1.X and b0.X < a1.X and a0.Y < b1.Y and b0.Y < a1.Y then
					h.Visible = false
					tucked[h] = true
				end
			end
		end
	end)
end)
RunService.RenderStepped:Connect(function()
	local show = false
	if currentMode == "Run" and not windowOpen then
		local cam = workspace.CurrentCamera
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		show = cam ~= nil and head ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.5
	end
	if cross.Visible ~= show then
		cross.Visible = show
	end
end)

-------------------------------------------------------------------------------------------------------------
-- day / night bar (top centre): ReplicatedStorage attributes DayPhase ("day"/"night"), DayLeft and DayLength
-- (seconds). Hidden until they exist; it counts down here between attribute updates.
-------------------------------------------------------------------------------------------------------------
local DAY = Color3.fromRGB(255, 205, 50)
local NIGHT = Color3.fromRGB(70, 110, 230)
local day = Instance.new("Frame")
day.Name = "DayBar"
day.BackgroundTransparency = 1
day.Size = UDim2.fromOffset(300, 52)
day.Position = UDim2.new(0.5, 0, 0, 10)
day.AnchorPoint = Vector2.new(0.5, 0)
day.Visible = false
day.Parent = root
local _, dayFill, dayText = Skin.bar(day, Vector2.new(256, 40), DAY, { pos = UDim2.fromOffset(40, 6), name = "Track" })
local dayGrad = dayFill:FindFirstChildOfClass("UIGradient") :: UIGradient
local dayIcon = Instance.new("Frame")
dayIcon.BackgroundTransparency = 1
dayIcon.Size = UDim2.fromOffset(56, 56)
dayIcon.ZIndex = 3
dayIcon.Parent = day
local dayLeft, dayLeftAt, shownPhase = 0, os.clock(), ""
local function readDayLeft()
	dayLeft, dayLeftAt = tonumber(ReplicatedStorage:GetAttribute("DayLeft")) or 0, os.clock()
end
ReplicatedStorage:GetAttributeChangedSignal("DayLeft"):Connect(readDayLeft)
readDayLeft()
task.spawn(function()
	while true do
		task.wait(0.25)
		local phase = ReplicatedStorage:GetAttribute("DayPhase")
		local length = tonumber(ReplicatedStorage:GetAttribute("DayLength"))
		local has = type(phase) == "string" and ReplicatedStorage:GetAttribute("DayLeft") ~= nil and length ~= nil and length > 0
		day.Visible = has
		if has then
			local night = phase == "night"
			if phase ~= shownPhase then
				shownPhase = phase
				local color = if night then NIGHT else DAY
				dayFill.BackgroundColor3 = color
				dayGrad.Color = ColorSequence.new(UI.shade(color, 1.15), UI.shade(color, 0.85))
				UI.clear(dayIcon)
				local sky = UI.icon(dayIcon, if night then "moon" else "sun", 56, UDim2.new())
				Skin.popIn(sky)
			end
			local left = math.max(0, dayLeft - (os.clock() - dayLeftAt))
			dayFill.Size = UDim2.fromScale(math.clamp(left / (length :: number), 0.03, 1), 1)
			local secs = math.ceil(left)
			dayText.Text = if secs >= 60 then ("%dm %02ds"):format(secs // 60, secs % 60) else secs .. "s"
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- flying icons: what you earn flies into its counter (world first, then the HUD)
-------------------------------------------------------------------------------------------------------------
local function fly(icon: GuiObject, from: Vector2, target: GuiObject, delay: number)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Parent = UI.gui
	icon.ZIndex = 30
	local sc = (UI.gui:FindFirstChildOfClass("UIScale") :: UIScale).Scale
	local to = target.AbsolutePosition + target.AbsoluteSize / 2
	icon.Position = UDim2.fromOffset(from.X / sc, from.Y / sc)
	icon.Visible = false
	task.delay(delay, function()
		icon.Visible = true
		local mid = from:Lerp(to, 0.5) + Vector2.new(math.random(-80, 80), -math.random(40, 120))
		local t1 = TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(mid.X / sc, mid.Y / sc) })
		t1:Play()
		t1.Completed:Wait()
		local t2 = TweenService:Create(icon, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(to.X / sc, to.Y / sc) })
		t2:Play()
		t2.Completed:Wait()
		icon:Destroy()
		UI.bounce(target)
	end)
end

local function screenPoint(world: Vector3): Vector2?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local p, onScreen = cam:WorldToViewportPoint(world)
	if not onScreen then
		return nil
	end
	return Vector2.new(p.X, p.Y)
end

-- loot picked up off the ground (client/LootFx): bundles fly into the bag, gems into the gem counter
State.on("lootPicked", function(pos: Vector3, kind: string, amount: number?)
	local from = screenPoint(pos + Vector3.new(0, 1, 0))
	if not from then
		return
	end
	if kind == "gem" then
		for i = 1, math.clamp(amount or 1, 1, 5) do
			fly(UI.icon(UI.gui, "gem", 30), from + Vector2.new(math.random(-12, 12), 0), gemBox, (i - 1) * 0.05)
		end
	elseif bag.Visible then
		fly(UI.icon(UI.gui, "bundle", 30), from, bag, 0)
	end
end)

State.on("flyCoins", function(count: number)
	if not coinBox.Visible then
		return
	end
	local cam = workspace.CurrentCamera
	local centre = if cam then cam.ViewportSize / 2 else Vector2.new(640, 360)
	for i = 1, count do
		fly(UI.icon(UI.gui, "coin", 32), centre + Vector2.new(math.random(-60, 60), math.random(-30, 30)), coinBox, (i - 1) * 0.04)
	end
end)

-- gems from a big reward (the daily streak) burst from the middle of the screen into the gem counter
State.on("flyGems", function(count: number)
	local cam = workspace.CurrentCamera
	local centre = if cam then cam.ViewportSize / 2 else Vector2.new(640, 360)
	for i = 1, count do
		fly(UI.icon(UI.gui, "gem", 30), centre + Vector2.new(math.random(-60, 60), math.random(-30, 30)), gemBox, (i - 1) * 0.04)
	end
end)

applyMode(State.mode)

function Hud.root()
	return root
end

local _ = Config
return Hud
