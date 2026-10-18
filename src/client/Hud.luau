-- The always-on screen: gems, coins, bag, zone progress / boss bar, fuel, side buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Hud = {}
local C = UI.colors
local player = Players.LocalPlayer

local root = Instance.new("Frame")
root.Name = "Hud"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = UI.gui

local function pill(pos: UDim2, anchor: Vector2, width: number, color: Color3)
	local f = UI.frame({ size = UDim2.fromOffset(width, 52), pos = pos, anchor = anchor, color = color, parent = root, radius = 26, outline = 3.5 })
	UI.gradient(f, color)
	return f
end

-------------------------------------------------------------------------------------------------------------
-- currencies (top-left)
-------------------------------------------------------------------------------------------------------------
local gemPill = pill(UDim2.fromOffset(20, 20), Vector2.zero, 210, C.purple)
UI.gemIcon(gemPill, 44, UDim2.fromOffset(6, 4))
local gemText = UI.text(gemPill, "0", UDim2.new(1, -64, 1, -12), { pos = UDim2.fromOffset(56, 6), align = Enum.TextXAlignment.Left })

local classText = UI.text(root, "", UDim2.fromOffset(320, 26), { pos = UDim2.fromOffset(26, 78), align = Enum.TextXAlignment.Left, color = C.yellow })
local studioText = UI.text(root, "STUDIO TEST: saves are off", UDim2.fromOffset(320, 22), { pos = UDim2.fromOffset(26, 106), align = Enum.TextXAlignment.Left, color = C.orange })
studioText.Visible = false

-------------------------------------------------------------------------------------------------------------
-- run: coins + bag (bottom-left)
-------------------------------------------------------------------------------------------------------------
local coinPill = pill(UDim2.new(0, 20, 1, -150), Vector2.zero, 260, C.green)
UI.coinIcon(coinPill, 40, UDim2.fromOffset(7, 6))
local coinText = UI.text(coinPill, "0", UDim2.new(1, -64, 1, -12), { pos = UDim2.fromOffset(56, 6), align = Enum.TextXAlignment.Left })

local bag = UI.frame({ size = UDim2.fromOffset(260, 46), pos = UDim2.new(0, 20, 1, -88), color = C.dark, parent = root, radius = 23, outline = 3.5, name = "Bag" })
local bagFill = UI.frame({ size = UDim2.new(0, 0, 1, 0), color = Color3.fromRGB(150, 220, 80), parent = bag, radius = 23, outline = 0, name = "Fill" })
UI.gradient(bagFill, Color3.fromRGB(150, 220, 80))
UI.bundleIcon(bag, 34, UDim2.fromOffset(10, 11))
local bagText = UI.text(bag, "0 / 5", UDim2.new(1, -60, 1, -10), { pos = UDim2.fromOffset(52, 5), align = Enum.TextXAlignment.Left })
bagText.ZIndex = 3

-------------------------------------------------------------------------------------------------------------
-- top centre: zone progress or boss HP
-------------------------------------------------------------------------------------------------------------
local zoneBar = UI.frame({ size = UDim2.fromOffset(520, 64), pos = UDim2.new(0.5, 0, 0, 18), anchor = Vector2.new(0.5, 0), color = C.dark, parent = root, radius = 16, outline = 3.5, name = "ZoneBar" })
local zoneTitle = UI.text(zoneBar, "", UDim2.new(1, -20, 0, 28), { pos = UDim2.fromOffset(10, 4) })
local zoneTrack = UI.frame({ size = UDim2.new(1, -24, 0, 20), pos = UDim2.fromOffset(12, 36), color = Color3.fromRGB(25, 22, 35), parent = zoneBar, radius = 10, outline = 0 })
local zoneFill = UI.frame({ size = UDim2.fromScale(0, 1), color = C.green, parent = zoneTrack, radius = 10, outline = 0 })
local zoneFillGrad = UI.gradient(zoneFill, C.green)
local zoneCount = UI.text(zoneTrack, "", UDim2.fromScale(1, 1), { stroke = 2 })
zoneCount.ZIndex = 3

local lobbyHint = UI.text(root, "Walk onto a pad to start a run!", UDim2.fromOffset(620, 34), { pos = UDim2.new(0.5, 0, 0, 22), anchor = Vector2.new(0.5, 0), color = C.yellow, stroke = 3 })

-------------------------------------------------------------------------------------------------------------
-- fuel (bottom centre, while driving)
-------------------------------------------------------------------------------------------------------------
local fuel = UI.frame({ size = UDim2.fromOffset(300, 40), pos = UDim2.new(0.5, 0, 1, -30), anchor = Vector2.new(0.5, 1), color = C.dark, parent = root, radius = 20, outline = 3, name = "Fuel" })
local fuelFill = UI.frame({ size = UDim2.fromScale(1, 1), color = C.orange, parent = fuel, radius = 20, outline = 0 })
UI.gradient(fuelFill, C.orange)
local fuelText = UI.text(fuel, "FUEL", UDim2.new(1, -16, 1, -8), { pos = UDim2.fromOffset(8, 4) })
fuelText.ZIndex = 3
fuel.Visible = false

-------------------------------------------------------------------------------------------------------------
-- party start button (lobby, when you host a pad)
-------------------------------------------------------------------------------------------------------------
local startBtn = UI.button(root, "START NOW", C.green, UDim2.fromOffset(240, 66), function()
	State.fire("Party", "start")
end, { pos = UDim2.new(0.5, 0, 1, -40), anchor = Vector2.new(0.5, 1), name = "StartNow" })
startBtn.Visible = false
local function updateHost()
	startBtn.Visible = State.mode == "Lobby" and player:GetAttribute("PartyHost") == true
end
player:GetAttributeChangedSignal("PartyHost"):Connect(updateHost)

-------------------------------------------------------------------------------------------------------------
-- side buttons
-------------------------------------------------------------------------------------------------------------
local side = Instance.new("Frame")
side.Name = "SideButtons"
side.BackgroundTransparency = 1
side.Size = UDim2.fromOffset(150, 420)
side.Position = UDim2.new(1, -20, 0.5, 0)
side.AnchorPoint = Vector2.new(1, 0.5)
side.Parent = root
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 12)
sideLayout.VerticalAlignment = Enum.VerticalAlignment.Center
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
sideLayout.Parent = side

local function sideButtons(mode: string)
	UI.clear(side)
	local defs = if mode == "Run"
		then {
			{ "TOOLS", C.red, "Tools" },
			{ "UPGRADES", C.blue, "Upgrades" },
			{ "MOWERS", C.purple, "Mowers" },
			{ "STORE", C.pink, "Store" },
		}
		else {
			{ "CLASSES", C.purple, "Classes" },
			{ "PERKS", C.blue, "Perks" },
			{ "GARAGE", C.orange, "Garage" },
			{ "REWARDS", C.yellow, "Rewards" },
			{ "STORE", C.pink, "Store" },
		}
	for i, d in defs do
		local b = UI.button(side, d[1], d[2], UDim2.fromOffset(150, 58), function()
			UI.open(d[3])
		end)
		b.LayoutOrder = i
	end
end

-------------------------------------------------------------------------------------------------------------
-- updates
-------------------------------------------------------------------------------------------------------------
local shownGems, shownCoins = 0, 0
local function countTo(label: TextLabel, from: number, to: number)
	if from == to then
		label.Text = Format.short(to)
		return
	end
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(function(x)
		label.Text = Format.short(x)
	end)
	local t = TweenService:Create(v, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = to })
	t.Completed:Connect(function()
		label.Text = Format.short(to)
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
	coinPill.Visible = isRun
	bag.Visible = isRun
	zoneBar.Visible = isRun
	lobbyHint.Visible = not isRun
	sideButtons(mode)
	updateHost()
end

State.on("data", function(d)
	applyMode(d.mode)
	if d.gems ~= shownGems then
		countTo(gemText, shownGems, d.gems)
		if d.gems > shownGems then
			UI.bounce(gemPill)
		end
		shownGems = d.gems
	end
	local c = Config.class(d.class)
	classText.Text = "Class: " .. (if c then c.name else "?")
	studioText.Visible = d.dryRun
	if d.run then
		if d.run.coins ~= shownCoins then
			countTo(coinText, shownCoins, d.run.coins)
			if d.run.coins > shownCoins then
				UI.bounce(coinPill)
			end
			shownCoins = d.run.coins
		end
		local ratio = math.clamp(d.run.carry / math.max(1, d.carryMax), 0, 1)
		bagFill.Size = UDim2.new(ratio, 0, 1, 0)
		bagFill.BackgroundColor3 = if ratio >= 1 then C.red else Color3.fromRGB(150, 220, 80)
		local g = bagFill:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = ColorSequence.new(UI.shade(bagFill.BackgroundColor3, 1.15), UI.shade(bagFill.BackgroundColor3, 0.85))
		end
		bagText.Text = d.run.carry .. " / " .. d.carryMax .. (if ratio >= 1 then "  FULL!" else "")
	end
	if d.mode == "Lobby" then
		lobbyHint.Text = if d.run then ("Saved run: Zone %d. Step on a pad to continue!"):format(d.run.zone) else "Walk onto a pad to start a run!"
	end
end)

State.on("world", function(w)
	if w.mode ~= "Run" or w.loading then
		return
	end
	if w.boss then
		zoneTitle.Text = w.boss.name:upper()
		zoneTitle.TextColor3 = C.red
		zoneFill.BackgroundColor3 = C.red
		zoneFillGrad.Color = ColorSequence.new(UI.shade(C.red, 1.15), UI.shade(C.red, 0.85))
		zoneFill.Size = UDim2.fromScale(math.clamp(w.boss.hp / w.boss.max, 0, 1), 1)
		zoneCount.Text = Format.short(w.boss.hp) .. " / " .. Format.short(w.boss.max)
	else
		zoneTitle.Text = ("ZONE %d/%d: %s"):format(w.zone, w.zones, w.name:upper())
		zoneTitle.TextColor3 = Color3.new(1, 1, 1)
		zoneFill.BackgroundColor3 = C.green
		zoneFillGrad.Color = ColorSequence.new(UI.shade(C.green, 1.15), UI.shade(C.green, 0.85))
		zoneFill.Size = UDim2.fromScale(math.clamp(w.cut / w.total, 0, 1), 1)
		zoneCount.Text = if w.cut >= w.total then "BOSS INCOMING!" else (w.cut .. " / " .. w.total .. " cut")
	end
end)

State.on("notify", function(text, color)
	UI.toast(text, color)
end)

-- fuel gauge, driven by the Drive module
State.on("driving", function(model: Model?)
	fuel.Visible = model ~= nil
end)
State.on("fuel", function(f: number, max: number)
	local ratio = if max > 0 then math.clamp(f / max, 0, 1) else 0
	fuelFill.Size = UDim2.fromScale(math.max(ratio, 0.02), 1)
	fuelFill.BackgroundColor3 = if ratio < 0.2 then C.red else C.orange
	fuelText.Text = if f <= 0 then "OUT OF GAS! Refuel at a pump" else ("FUEL %d / %d"):format(math.ceil(f), max)
end)

-- shake the bag when it's full
State.on("fx", function(kind)
	if kind == "bagFull" then
		local base = UDim2.new(0, 20, 1, -88)
		for i = 1, 6 do
			bag.Position = base + UDim2.fromOffset(if i % 2 == 0 then 6 else -6, 0)
			task.wait(0.04)
		end
		bag.Position = base
	end
end)

applyMode(State.mode)

function Hud.root()
	return root
end

return Hud
