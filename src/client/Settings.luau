-- SETTINGS (owner, 27 Oct: "you're able to turn Mythic and Legendary off in settings"): a gear button in the
-- top-left HUD (where the Potato button was; owner 28 Oct: Potato lives in here now) opens a small panel:
--   * Potato Mode (the same switch as the potato button)
--   * Legendary in-stock alerts, Mythic in-stock alerts: the big pulsing "IN STOCK" banner client/RarityFx drops in
--     for those rarities (a Secret class always shows it)
-- The alert choices are saved in the profile (server/Lobby "Setting": alertLegendary / alertMythic -> data.alerts) and
-- mirrored on the player as the attributes AlertLegendary / AlertMythic (false = off) for client/RarityFx. A click
-- sets the attribute at once, so it also works in a run (where only this session remembers it).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Potato = require(script.Parent.Potato)

local Settings = {}

local player = Players.LocalPlayer
local C = UI.colors
local OFF = Color3.fromRGB(120, 110, 130)
local ROWS = {
	{ key = "potato", label = "Potato Mode (low graphics)" },
	{ key = "alertLegendary", label = "Legendary in-stock alerts", attr = "AlertLegendary" },
	{ key = "alertMythic", label = "Mythic in-stock alerts", attr = "AlertMythic" },
}

local function isOn(row): boolean
	if row.key == "potato" then
		return Potato.on == true
	end
	return player:GetAttribute(row.attr) ~= false
end

-- the saved alert choices arrive with the profile (only until the player clicks: after that the click decides)
local touched: { [string]: boolean } = {}
local function fromData(d)
	local a = d and d.alerts
	for _, row in ROWS do
		if row.attr and not touched[row.key] then
			local v = if type(a) == "table" then a[row.key] else nil
			player:SetAttribute(row.attr, if v == false then false else nil)
		end
	end
end
State.on("data", fromData)
if State.data then
	fromData(State.data)
end

task.spawn(function()
	local hud = UI.gui:WaitForChild("Hud", 30)
	local potato = hud and hud:WaitForChild("Potato", 30)
	if not hud or not potato or not potato:IsA("GuiObject") then
		return
	end
	-- the gear, the same size as the potato button, just right of it
	local holder = Instance.new("Frame")
	holder.Name = "Settings"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(84, 74)
	holder.Parent = hud
	local function follow()
		holder.Position = potato.Position -- (the potato button is hidden: the gear takes its spot)
	end
	follow()
	potato:GetPropertyChangedSignal("Position"):Connect(follow)

	local panel = UI.frame({ size = UDim2.fromOffset(330, 40 + #ROWS * 46), pos = UDim2.fromOffset(0, 80), color = Color3.fromRGB(34, 22, 66), parent = holder, radius = 14, outline = 3, name = "Panel" })
	panel.Visible = false
	panel.ZIndex = 20
	UI.text(panel, "SETTINGS", UDim2.new(1, -20, 0, 26), { pos = UDim2.fromOffset(12, 6), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 205, 80), stroke = 2 }).ZIndex = 21
	local buttons: { [string]: TextButton } = {}
	local function paint()
		for _, row in ROWS do
			local b = buttons[row.key]
			if b then
				local on = isOn(row)
				UI.setButton(b, if on then "ON" else "OFF", if on then C.green else OFF)
			end
		end
	end
	for i, row in ROWS do
		local y = 36 + (i - 1) * 46
		local t = UI.text(panel, row.label, UDim2.new(1, -110, 0, 24), { pos = UDim2.fromOffset(14, y + 9), align = Enum.TextXAlignment.Left, stroke = 1.5 })
		t.ZIndex = 21
		local b = UI.button(panel, "ON", C.green, UDim2.fromOffset(78, 38), function()
			if row.key == "potato" then
				Potato.toggle()
				UI.toast(if Potato.on then "🥔 Potato Mode ON: low graphics, smoother on slow devices" else "Potato Mode OFF: full graphics", if Potato.on then "green" else nil)
			else
				local on = not isOn(row)
				touched[row.key] = true
				player:SetAttribute(row.attr, if on then nil else false)
				State.fire("Setting", row.key, on)
				UI.toast((if row.key == "alertLegendary" then "Legendary" else "Mythic") .. " in-stock alerts " .. (if on then "ON" else "OFF"), if on then "green" else nil)
			end
			paint()
		end, { pos = UDim2.new(1, -12, 0, y + 2), anchor = Vector2.new(1, 0), name = "Toggle_" .. row.key })
		b.ZIndex = 22
		buttons[row.key] = b
	end
	paint()
	Potato.changed(function()
		paint()
	end)

	local gear = UI.button(holder, "⚙️", Color3.fromRGB(110, 90, 160), UDim2.fromOffset(50, 50), function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			paint()
			local sc = panel:FindFirstChild("Open") :: UIScale?
			if not sc then
				sc = Instance.new("UIScale")
			end
			sc = sc :: UIScale
			sc.Name = "Open"
			sc.Scale = 0.85
			sc.Parent = panel
			TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end, { pos = UDim2.fromOffset(42, 0), anchor = Vector2.new(0.5, 0), name = "GearButton" })
	local _ = gear
	UI.text(holder, "SETTINGS", UDim2.fromOffset(84, 20), { pos = UDim2.fromOffset(0, 52), stroke = 2 })
	-- any window opening closes the panel
	UI.onWindowChanged.Event:Connect(function()
		panel.Visible = false
	end)
end)

return Settings
