-- DEV panel: cheats for testing (infinite cash, every tool, max everything, spawn / kill the area's boss, clear or
-- open areas, skip to night). Only shows for players the server marked IsDev (everyone in Studio; live servers:
-- Config.ADMINS or the game's owner). Open with F2 or the red DEV button. The server checks every request again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local DevPanel = {}
local C = UI.colors
local player = Players.LocalPlayer

local RED = Color3.fromRGB(220, 60, 60)
local BUTTONS = {
	{ "INFINITE CASH", "infCash", C.green },
	{ "+1M COINS", "coins", C.green },
	{ "+100K GEMS", "gems", Color3.fromRGB(80, 160, 255) },
	{ "ALL TOOLS", "tools", C.yellow },
	{ "MAX EVERYTHING", "maxAll", C.yellow },
	{ "SPAWN BOSS", "boss", RED },
	{ "KILL BOSS", "killBoss", RED },
	{ "BOSSES ON/OFF", "bossesOn", RED },
	{ "CLEAR AREA", "clear", Color3.fromRGB(150, 90, 220) },
	{ "NEXT AREA", "nextArea", Color3.fromRGB(150, 90, 220) },
	{ "OPEN ALL AREAS", "allAreas", Color3.fromRGB(150, 90, 220) },
	{ "DAY / NIGHT", "night", Color3.fromRGB(60, 70, 140) },
	{ "FIND A GNOME", "gnome", Color3.fromRGB(230, 180, 40) },
	{ "ALMOST CLEAR", "almost", Color3.fromRGB(150, 90, 220) },
	{ "CUT ONE CLUMP", "cutOne", Color3.fromRGB(150, 90, 220) },
}
-- a free egg of every kind in Config.EGGS (hatched by the server with the normal hatch show)
for _, egg in Config.EGGS do
	table.insert(BUTTONS, { "GIVE " .. egg.name:upper(), "egg", egg.color, egg.id })
end

local built = false
local function build()
	if built then
		return
	end
	built = true
	local w = UI.window("Dev", "Dev", nil, { size = Vector2.new(780, 620), grid = Vector2.new(220, 78) })
	for i, b in BUTTONS do
		local btn = UI.button(w.list, b[1], b[3], UDim2.fromOffset(220, 78), function()
			State.fire("Dev", b[2], b[4])
		end, { name = b[2] })
		btn.LayoutOrder = i
	end

	local open = UI.button(UI.gui, "DEV", RED, UDim2.fromOffset(96, 46), function()
		UI.open("Dev")
	end, { pos = UDim2.new(0, 16, 0.5, if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 176 else 120), name = "DevButton" }) -- (under the gem counter, not on its icon)
	open.ZIndex = 5

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			UI.open("Dev")
		end
	end)
end

if player:GetAttribute("IsDev") == true then
	build()
end
player:GetAttributeChangedSignal("IsDev"):Connect(function()
	if player:GetAttribute("IsDev") == true then
		build()
	end
end)

return DevPanel
