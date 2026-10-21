-- The always-on screen, laid out like Chop A Forest:
--   left: big coin + gem counters   bottom-left: backpack "3/5"     bottom: tool hotbar
--   right: round wooden badge buttons (run: SHOP R, UPGRADES TAB; lobby: PETS P, SHOP R, STATS TAB, NEWS J)
--   top-left: quest tracker         top-centre: day / night bar (ReplicatedStorage DayPhase/DayLeft/DayLength)
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

-------------------------------------------------------------------------------------------------------------
-- currencies (left, middle)
-------------------------------------------------------------------------------------------------------------
local function counter(y: number, icon: string)
	local f = Instance.new("Frame")
	f.Name = "Counter_" .. icon
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(320, 76)
	f.Position = UDim2.new(0, 14, 0.5, y)
	f.Parent = root
	UI.icon(f, icon, 74, UDim2.fromOffset(0, 1))
	local t = UI.text(f, "0", UDim2.fromOffset(236, 60), { pos = UDim2.fromOffset(84, 8), align = Enum.TextXAlignment.Left, stroke = 4 })
	return f, t
end
local coinBox, coinText = counter(-96, "coin")
local gemBox, gemText = counter(-10, "gem")

-------------------------------------------------------------------------------------------------------------
-- backpack (bottom-left)
-------------------------------------------------------------------------------------------------------------
local bag = Instance.new("Frame")
bag.Name = "Backpack"
bag.BackgroundTransparency = 1
bag.Size = UDim2.fromOffset(260, 96)
bag.Position = UDim2.new(0, 14, 1, -108)
bag.Parent = root
UI.icon(bag, "backpack", 92, UDim2.fromOffset(0, 0))
local bagText = UI.text(bag, "0/5", UDim2.fromOffset(160, 56), { pos = UDim2.fromOffset(98, 20), align = Enum.TextXAlignment.Left, stroke = 4 })

-------------------------------------------------------------------------------------------------------------
-- quest tracker (top-left, under Roblox's buttons)
-------------------------------------------------------------------------------------------------------------
local quest = Instance.new("Frame")
quest.Name = "Quest"
quest.BackgroundTransparency = 1
quest.Size = UDim2.fromOffset(300, 100)
quest.Position = UDim2.fromOffset(22, 74)
quest.Parent = root
local questNum = UI.text(quest, "QUEST 1/8", UDim2.fromOffset(200, 18), { align = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 170, 60), stroke = 1.5 })
local questTitle = UI.text(quest, "", UDim2.fromOffset(300, 28), { pos = UDim2.fromOffset(0, 18), align = Enum.TextXAlignment.Left, stroke = 2 })
local questTrack = UI.frame({ size = UDim2.fromOffset(240, 14), pos = UDim2.fromOffset(0, 52), color = Color3.fromRGB(30, 30, 34), parent = quest, radius = 7, outline = 0 })
questTrack.BackgroundTransparency = 0.25
local questFill = UI.frame({ size = UDim2.fromScale(0, 1), color = C.green, parent = questTrack, radius = 7, outline = 0 })
local questCount = UI.text(questTrack, "0/1", UDim2.fromScale(1, 1.2), { stroke = 1.5 })
questCount.ZIndex = 3
local questHint = UI.text(quest, "", UDim2.fromOffset(300, 18), { pos = UDim2.fromOffset(0, 72), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(225, 225, 230), stroke = 1 })

-------------------------------------------------------------------------------------------------------------
-- run info (top-right): timer, zone, progress / boss bar
-------------------------------------------------------------------------------------------------------------
local info = Instance.new("Frame")
info.Name = "RunInfo"
info.BackgroundTransparency = 1
info.Size = UDim2.fromOffset(330, 200)
info.Position = UDim2.new(1, -18, 0, 54)
info.AnchorPoint = Vector2.new(1, 0)
info.Parent = root
local timerText = UI.text(info, "0:00", UDim2.fromOffset(200, 44), { pos = UDim2.new(1, 0, 0, 0), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, stroke = 3.5 })
local watch = UI.icon(info, "stopwatch", 42, UDim2.new(1, -206, 0, 1))
local zoneText = UI.text(info, "", UDim2.fromOffset(280, 32), { pos = UDim2.new(1, 0, 0, 46), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, stroke = 3 })
local pin = UI.icon(info, "pin", 30, UDim2.new(1, -290, 0, 47))
local areaText = UI.text(info, "AREA 1/8", UDim2.fromOffset(200, 24), { pos = UDim2.new(1, 0, 0, 80), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = Color3.fromRGB(255, 186, 60), stroke = 2.5 })
local track = UI.frame({ size = UDim2.fromOffset(300, 34), pos = UDim2.new(1, 0, 0, 108), anchor = Vector2.new(1, 0), color = Color3.fromRGB(25, 25, 30), parent = info, radius = 10, outline = 3 })
track.BackgroundTransparency = 0.15
local fill = UI.frame({ size = UDim2.fromScale(0, 1), color = C.green, parent = track, radius = 10, outline = 0 })
local fillGrad = UI.gradient(fill, C.green)
local trackText = UI.text(track, "0% cleared", UDim2.new(1, -10, 1, -8), { pos = UDim2.fromOffset(5, 4), stroke = 2 })
trackText.ZIndex = 3
local nextText = UI.text(info, "", UDim2.fromOffset(330, 24), { pos = UDim2.new(1, 0, 0, 148), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = Color3.fromRGB(235, 235, 240), stroke = 2 })
local _ = watch

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

local function sideLeaf(parent: Instance, pos: UDim2, rot: number, size: number)
	local l = UI.frame({ size = UDim2.fromOffset(size, size * 0.55), pos = pos, anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(110, 200, 70), parent = parent, radius = 999, outline = 2, name = "Leaf" })
	l.Rotation = rot
	;(l:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(40, 90, 30)
	UI.gradient(l, Color3.fromRGB(110, 200, 70))
	return l
end

-- A round wooden badge: grained disc, a ring, two leaves on top, the icon, a dark key badge and the name.
local function roundButton(label: string, icon: string, key: string, window: string, order: number)
	local b = Instance.new("TextButton")
	b.Name = label
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(108, 108)
	b.LayoutOrder = order
	b.Parent = side
	local wood = Color3.fromRGB(196, 124, 62)
	local disc = UI.frame({ size = UDim2.fromOffset(88, 88), pos = UDim2.fromOffset(10, 2), color = wood, parent = b, radius = 999, outline = 4, name = "Disc" })
	;(disc:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(90, 50, 22)
	UI.grain(disc, wood, 40)
	local inner = UI.frame({ size = UDim2.fromOffset(70, 70), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(240, 208, 156), parent = disc, radius = 999, outline = 3, name = "Inner" })
	;(inner:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(140, 84, 40)
	UI.icon(inner, icon, 64, UDim2.fromScale(0.5, 0.46), Vector2.new(0.5, 0.5))
	sideLeaf(b, UDim2.fromOffset(20, 10), -40, 30)
	sideLeaf(b, UDim2.fromOffset(34, 2), -10, 22)
	local badge = UI.frame({ size = UDim2.fromOffset(if #key > 1 then 44 else 30, 28), pos = UDim2.fromOffset(104, 64), anchor = Vector2.new(1, 0), color = Color3.fromRGB(36, 30, 26), parent = b, radius = 8, outline = 2, name = "Key" })
	UI.text(badge, key, UDim2.new(1, -6, 1, -6), { pos = UDim2.fromOffset(3, 3), stroke = 1 })
	UI.text(b, label, UDim2.fromOffset(120, 26), { pos = UDim2.new(0.5, 0, 0, 86), anchor = Vector2.new(0.5, 0), stroke = 3 })
	UI.raise(b, 2)
	b.MouseButton1Click:Connect(function()
		UI.bounce(b)
		Sound.play("click")
		UI.open(window)
	end)
	return b
end

local function sideButtons(mode: string)
	UI.clear(side)
	roundButton("PETS", "paw", "P", "Pets", 0)
	roundButton("SHOP", "basket", "R", "Store", 1)
	if mode == "Run" then
		roundButton("UPGRADES", "upgrade", "TAB", "Upgrades", 2)
		side.Size = UDim2.fromOffset(120, 2 * 118)
	else
		roundButton("STATS", "clipboard", "TAB", "Stats", 2)
		roundButton("NEWS", "newspaper", "J", "News", 4)
		side.Size = UDim2.fromOffset(120, 4 * 118)
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

local rings: { [Tool]: Frame } = {}
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
		hotbar.Visible = #tools > 0
		if key ~= shownKey then
			shownKey = key
			UI.clear(hotbar)
			table.clear(rings)
			hotbar.Size = UDim2.fromOffset(math.max(1, #tools) * 88, 80)
			for i, t in tools do
				local b = Instance.new("TextButton")
				b.Name = "Slot" .. i
				b.Text = ""
				b.AutoButtonColor = false
				b.BackgroundTransparency = 1
				b.Size = UDim2.fromOffset(80, 80)
				b.LayoutOrder = i
				b.Parent = hotbar
				local ring = UI.frame({ size = UDim2.fromOffset(72, 72), pos = UDim2.fromOffset(4, 4), color = Color3.fromRGB(40, 30, 24), parent = b, radius = 16, outline = 3, name = "Ring" })
				ring.BackgroundTransparency = 0.25
				local grow = Instance.new("UIScale")
				grow.Name = "Grow"
				grow.Parent = ring
				UI.icon(ring, TOOL_ICON[t:GetAttribute("ToolId")] or "coin", 56, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
				local num = UI.frame({ size = UDim2.fromOffset(24, 24), pos = UDim2.fromOffset(0, 0), color = Color3.fromRGB(36, 30, 26), parent = b, radius = 999, outline = 2, name = "Num" })
				UI.text(num, tostring(i), UDim2.new(1, -6, 1, -6), { pos = UDim2.fromOffset(3, 3), stroke = 1 })
				num.ZIndex = 3
				UI.clicky(b)
				b.MouseButton1Click:Connect(function()
					toggleTool(i)
				end)
				rings[t] = ring
			end
		end
		local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
		for t, ring in rings do
			local on = t == held
			local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color = if on then C.yellow else C.outline
			stroke.Thickness = if on then 4 else 3
			local grow = ring:FindFirstChild("Grow") :: UIScale?
			if grow then
				grow.Scale = if on then 1.12 else 1
			end
		end
		slotName.Text = if held then held.Name else ""
	end
end)

-------------------------------------------------------------------------------------------------------------
-- fuel (above the hotbar, while driving) + party start button (lobby)
-------------------------------------------------------------------------------------------------------------
local fuel = UI.frame({ size = UDim2.fromOffset(300, 36), pos = UDim2.new(0.5, 0, 1, -110), anchor = Vector2.new(0.5, 1), color = C.dark, parent = root, radius = 18, outline = 3, name = "Fuel" })
local fuelFill = UI.frame({ size = UDim2.fromScale(1, 1), color = C.orange, parent = fuel, radius = 18, outline = 0 })
UI.gradient(fuelFill, C.orange)
local fuelText = UI.text(fuel, "FUEL", UDim2.new(1, -16, 1, -8), { pos = UDim2.fromOffset(8, 4) })
fuelText.ZIndex = 3
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
	local t = TweenService:Create(v, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = to })
	t.Completed:Connect(function()
		label.Text = pre .. Format.commas(to)
		v:Destroy()
	end)
	t:Play()
end

local currentMode = ""
local function applyMode(mode: string)
	if mode == currentMode then
		return
	end
	currentMode = mode
	local isRun = mode == "Run"
	coinBox.Visible = isRun
	bag.Visible = isRun
	info.Visible = isRun
	quest.Visible = isRun
	sideButtons(mode)
	updateHost()
	Sound.music(if isRun then "musicRun" else "musicLobby")
end

State.on("data", function(d)
	applyMode(d.mode)
	if d.gems ~= shownGems then
		countTo(gemText, shownGems, d.gems)
		if d.gems > shownGems then
			UI.bounce(gemBox)
		end
		shownGems = d.gems
	end
	UI.setGems(d.gems)
	if d.run then
		if d.run.coins ~= shownCoins then
			countTo(coinText, shownCoins, d.run.coins)
			if d.run.coins > shownCoins then
				UI.bounce(coinBox)
			end
			shownCoins = d.run.coins
		end
		-- bundles still lying on the ground count toward the bag too (they're reserved for you)
		local full = not d.endless and d.run.carry + (d.run.ground or 0) >= d.carryMax
		bagText.Text = if d.endless then d.run.carry .. "/∞" else d.run.carry .. "/" .. d.carryMax
		bagText.TextColor3 = if full then C.red else Color3.new(1, 1, 1)
		local q = d.run.quest
		quest.Visible = q ~= nil
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
UI.onWindowChanged.Event:Connect(function(name)
	windowOpen = name ~= nil
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
day.Size = UDim2.fromOffset(300, 48)
day.Position = UDim2.new(0.5, 0, 0, 10)
day.AnchorPoint = Vector2.new(0.5, 0)
day.Visible = false
day.Parent = root
local dayTrack = UI.frame({ size = UDim2.fromOffset(250, 30), pos = UDim2.fromOffset(44, 9), color = Color3.fromRGB(25, 25, 30), parent = day, radius = 15, outline = 3, name = "Track" })
dayTrack.BackgroundTransparency = 0.2
local dayFill = UI.frame({ size = UDim2.fromScale(1, 1), color = DAY, parent = dayTrack, radius = 15, outline = 0, name = "Fill" })
local dayGrad = UI.gradient(dayFill, DAY)
local dayText = UI.text(dayTrack, "", UDim2.new(1, -12, 1, -6), { pos = UDim2.fromOffset(6, 3), stroke = 2 })
dayText.ZIndex = 3
local dayIcon = Instance.new("Frame")
dayIcon.BackgroundTransparency = 1
dayIcon.Size = UDim2.fromOffset(48, 48)
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
				UI.icon(dayIcon, if night then "moon" else "sun", 48, UDim2.new())
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

applyMode(State.mode)

function Hud.root()
	return root
end

local _ = Config
return Hud
