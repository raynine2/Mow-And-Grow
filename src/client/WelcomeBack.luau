-- WELCOME BACK (owner, 28 Oct: runs save offline so people come back). Two things:
--   * the popup when server/Offline paid you for time away (Fx "offline"): how long you were gone, the coins that
--     went into your saved run and the gems, and in the lobby a CONTINUE RUN button (solo, your saved run)
--   * in the lobby, while you have a saved run: a green CONTINUE RUN button at the bottom of the screen, so the saved
--     run is one click away (party runs still start from the PARTY bays)
-- CONTINUE fires "Party" "load" (server/Lobby: a solo run from your save).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Format"))
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

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

local function showPopup(d)
	closePopup()
	local inRun = State.isRun()
	local f = UI.frame({ size = UDim2.fromOffset(440, 290), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(34, 22, 66), parent = UI.gui, radius = 22, outline = 4, name = "WelcomeBack" })
	f.ZIndex = 60
	popup = f
	local st = f:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = GOLD
	end
	local function z(g: GuiObject)
		g.ZIndex = 61
		for _, k in g:GetDescendants() do
			if k:IsA("GuiObject") then
				k.ZIndex = 62
			end
		end
	end
	z(UI.text(f, "WELCOME BACK!", UDim2.new(1, -30, 0, 50), { pos = UDim2.fromOffset(15, 14), color = GOLD, stroke = 4 }))
	z(UI.text(f, ("Your lawn kept growing while you were away (%s%s)."):format(away(d.mins or 0), if d.capped then ", max" else ""), UDim2.new(1, -40, 0, 44), { pos = UDim2.fromOffset(20, 66), stroke = 1.5, textSize = 18 }))
	local y = 118
	if (d.coins or 0) > 0 then
		local row = UI.frame({ size = UDim2.new(1, -60, 0, 44), pos = UDim2.fromOffset(30, y), color = Color3.fromRGB(20, 12, 44), parent = f, radius = 12, outline = 0, name = "Coins" })
		z(row)
		local ic = UI.icon(row, "coin", 34, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
		ic.ZIndex = 62
		z(UI.text(row, "+" .. Format.commas(d.coins) .. " coins", UDim2.new(1, -60, 1, -10), { pos = UDim2.fromOffset(52, 5), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 225, 110), stroke = 2 }))
		y += 50
	end
	if (d.gems or 0) > 0 then
		local row = UI.frame({ size = UDim2.new(1, -60, 0, 44), pos = UDim2.fromOffset(30, y), color = Color3.fromRGB(20, 12, 44), parent = f, radius = 12, outline = 0, name = "Gems" })
		z(row)
		local ic = UI.icon(row, "gem", 34, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
		ic.ZIndex = 62
		z(UI.text(row, "+" .. Format.commas(d.gems) .. " gems", UDim2.new(1, -60, 1, -10), { pos = UDim2.fromOffset(52, 5), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(150, 230, 255), stroke = 2 }))
		y += 50
	end
	f.Size = UDim2.fromOffset(440, y + 74)
	if not inRun then
		-- the coins are in the saved run: CONTINUE takes you straight there
		local go = UI.button(f, "CONTINUE RUN", C.green, UDim2.fromOffset(220, 52), function()
			closePopup()
			continueRun()
		end, { pos = UDim2.new(0.5, -6, 1, -14), anchor = Vector2.new(1, 1), name = "Continue" })
		z(go)
		local later = UI.button(f, "LATER", Color3.fromRGB(120, 110, 140), UDim2.fromOffset(150, 52), function()
			closePopup()
		end, { pos = UDim2.new(0.5, 6, 1, -14), anchor = Vector2.new(0, 1), name = "Later" })
		z(later)
	else
		local ok = UI.button(f, "NICE!", C.green, UDim2.fromOffset(200, 52), function()
			closePopup()
		end, { pos = UDim2.new(0.5, 0, 1, -14), anchor = Vector2.new(0.5, 1), name = "Ok" })
		z(ok)
	end
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
			showPopup(d)
		end)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- the lobby's CONTINUE RUN button
-------------------------------------------------------------------------------------------------------------
local cont = UI.button(UI.gui, "▶ CONTINUE RUN", C.green, UDim2.fromOffset(260, 56), function()
	continueRun()
end, { pos = UDim2.new(0.5, 0, 1, -118), anchor = Vector2.new(0.5, 1), name = "ContinueRun" })
cont.Visible = false
local contArea = UI.text(cont, "", UDim2.new(1, -20, 0, 16), { pos = UDim2.new(0.5, 0, 1, 2), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(220, 255, 210), stroke = 1.5 })
local windowOpen = false
local function refresh()
	local d = State.data
	local run = d and d.run
	local show = run ~= nil and not State.isRun() and not windowOpen
	cont.Visible = show
	if show then
		contArea.Text = "Your saved run · Area " .. tostring(run.zone or 1)
	end
end
State.on("data", refresh)
UI.onWindowChanged.Event:Connect(function(name)
	windowOpen = name ~= nil
	refresh()
end)
refresh()

return WelcomeBack
