-- WELCOME BACK (owner, 28 Oct: runs save offline so people come back). Two things:
--   * the popup when server/Offline paid you for time away (Fx "offline"): how long you were gone, the coins that
--     went into your saved run and the gems, and in the lobby a CONTINUE RUN button (solo, your saved run)
--   * in the lobby, while you have a saved run: a green CONTINUE RUN button at the bottom of the screen, so the saved
--     run is one click away (party runs still start from the PARTY bays)
-- CONTINUE fires "Party" "load" (server/Lobby: a solo run from your save).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Format"))
local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config")) :: any
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)

local WelcomeBack = {}

local C = UI.colors
local GOLD = Color3.fromRGB(255, 205, 80)

local function away(mins: number): string
	if mins >= 60 then
		local h = mins // 60
		local m = mins % 60
		return if m > 0 then ("%dh %dm"):format(h, m) else ("%dh"):format(h)
	end
	return ("%dm"):format(mins)
end

local function continueRun()
	State.fire("Party", "load")
end

-------------------------------------------------------------------------------------------------------------
-- the popup
-------------------------------------------------------------------------------------------------------------
local popup: GuiObject? = nil
local function closePopup()
	local p = popup
	popup = nil
	if p then
		TweenService:Create(p, TweenInfo.new(0.18), { Position = p.Position + UDim2.fromOffset(0, 30) }):Play()
		task.delay(0.18, function()
			p:Destroy()
		end)
	end
end

-- (4 Nov, owner: "match this ui with what we have") Drawn with the game's own kit (client/Skin): the grass-galaxy
-- panel the big windows use, the coins and gems on the HUD's own counter plates with the big icon over the left end,
-- the kit's green button. (It was a plain navy box with a gold line and flat dark rows.)
local W = 460
local function amountRow(parent: Instance, y: number, icon: string, text: string)
	local row = Instance.new("Frame")
	row.Name = "Row_" .. icon
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(320, 72)
	row.Position = UDim2.new(0.5, 0, 0, y)
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Parent = parent
	local plate, face = Skin.frame(row, "ui_plate", Vector2.new(270, 60), { pos = UDim2.fromOffset(44, 6), name = "Plate" })
	local t = UI.text(face, text, UDim2.new(1, -46, 1, -4), { pos = UDim2.fromOffset(42, 2), align = Enum.TextXAlignment.Left, stroke = 3.5 })
	t.ZIndex = plate.ZIndex + 2
	local ic = UI.icon(row, icon, 72, UDim2.fromOffset(0, 0))
	ic.ZIndex = plate.ZIndex + 3
end

local function showPopup(d)
	closePopup()
	local inRun = State.isRun()
	local rows = (if (d.coins or 0) > 0 then 1 else 0) + (if (d.gems or 0) > 0 then 1 else 0)
	local H = 214 + rows * 78
	local f = Instance.new("Frame")
	f.Name = "WelcomeBack"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(W, H)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	popup = f
	local panel = Skin.frame(f, "ui_sign", Vector2.new(W, H), { name = "Panel", maxScale = 0.5 })
	panel.Size = UDim2.fromScale(1, 1)
	UI.text(f, "WELCOME BACK!", UDim2.new(1, -60, 0, 50), { pos = UDim2.fromOffset(30, 26), color = GOLD, stroke = 4 })
	UI.text(f, ("Your lawn kept growing while you were away (%s%s)."):format(away(d.mins or 0), if d.capped then ", max" else ""), UDim2.new(1, -90, 0, 40), { pos = UDim2.fromOffset(45, 78), stroke = 2, textSize = 18 })
	local y = 124
	if (d.coins or 0) > 0 then
		amountRow(f, y, "coin", "+" .. Format.commas(d.coins))
		y += 78
	end
	if (d.gems or 0) > 0 then
		amountRow(f, y, "gem", "+" .. Format.commas(d.gems))
		y += 78
	end
	if not inRun then
		-- the coins are in the saved run: CONTINUE takes you straight there
		UI.button(f, "CONTINUE RUN", C.green, UDim2.fromOffset(220, 56), function()
			closePopup()
			continueRun()
		end, { pos = UDim2.new(0.5, -6, 1, -30), anchor = Vector2.new(1, 1), name = "Continue" })
		UI.button(f, "LATER", Color3.fromRGB(120, 110, 140), UDim2.fromOffset(150, 56), function()
			closePopup()
		end, { pos = UDim2.new(0.5, 6, 1, -30), anchor = Vector2.new(0, 1), name = "Later" })
	else
		UI.button(f, "NICE!", C.green, UDim2.fromOffset(210, 56), function()
			closePopup()
		end, { pos = UDim2.new(0.5, 0, 1, -30), anchor = Vector2.new(0.5, 1), name = "Ok" })
	end
	-- over the HUD: lift every piece by the same amount (keeps their order: icon over plate, text over face)
	f.ZIndex = 60
	for _, k in f:GetDescendants() do
		if k:IsA("GuiObject") then
			k.ZIndex += 60
		end
	end
	f.Parent = UI.gui
	local sc = Instance.new("UIScale")
	sc.Scale = 0.6
	sc.Parent = f
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

State.on("fx", function(kind, d)
	if kind == "offline" then
		-- (not over the run's fly-over intro: wait for it to finish, up to a minute)
		task.spawn(function()
			local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local t0 = os.clock()
			while os.clock() - t0 < 60 do
				local intro = pg and pg:FindFirstChild("IntroCinema")
				if not (intro and intro:IsA("ScreenGui") and intro.Enabled) then
					break
				end
				task.wait(0.5)
			end
			-- (9 Nov, owner: "maak dit rustiger") a calm card over the hotbar for a few seconds, nothing to click
			-- away (the lobby's CONTINUE RUN card below already takes you to the run); showPopup stays for later
			local _ = showPopup
			local parts = {}
			if (d.coins or 0) > 0 then
				table.insert(parts, "+" .. Format.short(d.coins) .. " coins")
			end
			if (d.gems or 0) > 0 then
				table.insert(parts, "+" .. Format.commas(d.gems) .. " gems")
			end
			if #parts > 0 then
				UI.notice("WELCOME BACK!", table.concat(parts, "  ·  ") .. " while you were away", "coin", 5)
			end
		end)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- the lobby's CONTINUE RUN button
-------------------------------------------------------------------------------------------------------------
-- (owner, 4 Nov, of the plain green button: "fix ui use ui we have") a card in the grass-galaxy kit like the Saved
-- Runs card: the title, the run's area, and the green button inside it
local cont, contFace = Skin.frame(UI.gui, "ui_sign", Vector2.new(310, 150), { pos = UDim2.new(0.5, 0, 1, -104), anchor = Vector2.new(0.5, 1), name = "ContinueRun", maxScale = 0.5 })
cont.Visible = false
local contTitle = UI.text(contFace, "YOUR SAVED RUN", UDim2.new(1, -8, 0, 26), { pos = UDim2.new(0.5, 0, 0, 2), anchor = Vector2.new(0.5, 0), color = GOLD, stroke = 2.5 })
contTitle.Name = "Title"
local contArea = UI.text(contFace, "", UDim2.new(1, -12, 0, 18), { pos = UDim2.new(0.5, 0, 0, 30), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(220, 255, 210), stroke = 1.5 })
local contBtn = UI.button(contFace, "▶ CONTINUE RUN", C.green, UDim2.new(1, -6, 0, 54), function()
	continueRun()
end, { pos = UDim2.new(0.5, 0, 1, -2), anchor = Vector2.new(0.5, 1), name = "Go" })
contBtn.ZIndex = 3
local function refresh()
	local d = State.data
	local run = d and d.run
	-- (3 Nov: asks UI itself. A flag kept from the window events missed the News board that opens by itself as you
	-- join, when it opened before this module loaded: the button stood on top of the board)
	local show = run ~= nil and not State.isRun() and not UI.anyOpen()
	cont.Visible = show
	if show then
		local z = run.zone or 1
		local def = Config.ZONES[z]
		contArea.Text = "Area " .. tostring(z) .. (if def and def.name then " · " .. def.name else "")
	end
end
State.on("data", refresh)
UI.onWindowChanged.Event:Connect(refresh)
refresh()

return WelcomeBack
