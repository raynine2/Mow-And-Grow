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
	{ "PLAY OPENING", "playOpening", Color3.fromRGB(255, 170, 40) }, -- (this client only: client/Intro.preview)
	{ "PLAY ENDING", "playEnding", Color3.fromRGB(255, 70, 150) }, -- (this client only: client/Ending.preview)
	{ "MAYOR VOICE", "mayorVoice", Color3.fromRGB(170, 110, 255) }, -- (this client only: client/Babble's voices)
}

-- The Mayor's voice, tried out (owner, 28 Oct): the next of client/Babble's voices, saying two of his lines. It
-- stays picked on this device for the films (PLAY OPENING / PLAY ENDING) until the game restarts; the one the owner
-- likes goes into Config.FILM.babble.
local function nextVoice(btn: TextButton)
	local Babble = require(script.Parent.Babble)
	local name = Babble.cycle()
	local label = btn:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = "VOICE: " .. Babble.label(name)
	end
	UI.toast("Mayor voice: " .. Babble.label(name) .. " (just on this device)", "purple")
	Babble.prepare()
	task.spawn(function()
		local t0 = os.clock()
		while not Babble.ready() and os.clock() - t0 < 3 do
			task.wait(0.1)
		end
		Babble.line("Mowers! At LAST, you've come!")
		task.wait(2.4)
		Babble.line("Mow it ALL... and save our valley!")
	end)
end
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
		local btn: TextButton
		btn = UI.button(w.list, b[1], b[3], UDim2.fromOffset(220, 78), function()
			if b[2] == "mayorVoice" then
				nextVoice(btn)
				return
			elseif b[2] == "playEnding" then
				-- the ending film, credits and end screen, played right here without finishing the run
				UI.close()
				require(script.Parent.Ending).preview()
				return
			elseif b[2] == "playOpening" then
				UI.close()
				require(script.Parent.Intro).preview()
				return
			end
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
