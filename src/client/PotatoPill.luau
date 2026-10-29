-- The Potato Mode pill in Roblox's top bar (owner, 30 Oct: "make our patato mode ui exactly like this"): a dark round
-- pill reading "Potato: OFF" / "Potato: ON" in the top-bar row, just right of Roblox's own buttons (the Roblox menu,
-- chat ...), drawn the way Roblox draws those: the same height and line, black at 0.3 transparency (times the player's
-- own "Background transparency" setting, as Roblox does), fully round, Builder Sans Bold in white, a light wash under
-- the mouse and a dark one while pressed. Clicking or tapping it switches Potato Mode (client/Potato), and it follows
-- the switch wherever it's flipped (the SETTINGS panel too).
--
-- Where it sits: GuiService.TopbarInset is the free part of the top-bar row (Roblox measures it from the right edge
-- of its last button). The sizes are Roblox's own (CoreScripts TopBar/Constants: a 58 px bar whose 44 px buttons rest
-- 2 px above its bottom, 12 px apart; UIBlox's dark theme for the colours), scaled with the bar's real height, so the
-- pill lines up on a computer, a phone and a console. On a phone the free part starts after Roblox's buttons, so the
-- pill never covers them; if the row is too narrow for it, or Roblox's top bar is hidden, the pill hides (Potato Mode
-- is still in SETTINGS). Studio's phone preview (client/Device) puts it beside the preview's drawn top bar.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Device = require(script.Parent.Device)
local Potato = require(script.Parent.Potato)
local UI = require(script.Parent.UI)

local PotatoPill = {}

local player = Players.LocalPlayer

local BAR = 58 -- the top bar height Roblox's numbers are for (TopBarHeight)
local BUTTON = 44 -- its buttons' height (TopBarButtonHeight)
local UNDER = 2 -- a button's bottom sits this far above the bar's bottom (TopBarButtonPadding)
local GAP = 12 -- from Roblox's last button: the gap Roblox leaves between its own (TopBarPadding)
local SIDE = 14 -- room each side of the words inside the pill (8 when the row is tight)
local TEXT_SIZE = 16
local FONT = Enum.Font.BuilderSansBold -- Roblox's UI font (its top bar's labels use this one)
local BACK = Color3.new(0, 0, 0) -- BackgroundUIContrast: black, 0.3 transparent
local BACK_ALPHA = 0.3
local HOVER, HOVER_ALPHA = Color3.new(1, 1, 1), 0.9 -- BackgroundOnHover: white at 0.9
local PRESS, PRESS_ALPHA = Color3.new(0, 0, 0), 0.7 -- BackgroundOnPress: black at 0.7
local WIDEST = "Potato: OFF" -- (the pill is as wide as its longer words, so it doesn't jump when switched)

local gui = Instance.new("ScreenGui")
gui.Name = "PotatoPill"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- (up into the top bar's row)
gui.ScreenInsets = Enum.ScreenInsets.None -- (the whole screen: TopbarInset counts from its left edge)
-- over the HUD and windows (0), the rare-stock banners (6) and the boss screens (8); under the party board (50),
-- hatching and the class hole (60) and the loading screen (999+). The films hide it (client/IntroUi).
gui.DisplayOrder = 30
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("KeepFont", true) -- (client/TextStyle leaves it in Roblox's font)

-- this gui's top-left corner, in the screen pixels TopbarInset is measured in
local origin = Instance.new("Frame")
origin.Name = "Origin"
origin.BackgroundTransparency = 1
origin.BorderSizePixel = 0
origin.Size = UDim2.fromOffset(0, 0)
origin.Parent = gui

local pill = Instance.new("TextButton")
pill.Name = "Pill"
pill.AutoButtonColor = false
pill.Text = ""
pill.BackgroundColor3 = BACK
pill.BorderSizePixel = 0
pill.Visible = false
pill:SetAttribute("Hover", true) -- (client/UI's button hook doesn't grow it under the mouse: Roblox's don't grow)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = pill
pill.Parent = gui

-- the hover / press wash over the background, under the words
local wash = Instance.new("Frame")
wash.Name = "Wash"
wash.BorderSizePixel = 0
wash.BackgroundTransparency = 1
wash.Size = UDim2.fromScale(1, 1)
wash.ZIndex = 1
local washCorner = Instance.new("UICorner")
washCorner.CornerRadius = UDim.new(1, 0)
washCorner.Parent = wash
wash.Parent = pill

local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = FONT
label.TextSize = TEXT_SIZE
label.TextColor3 = Color3.new(1, 1, 1)
label.TextXAlignment = Enum.TextXAlignment.Center
label.TextYAlignment = Enum.TextYAlignment.Center
label.Text = WIDEST
label.ZIndex = 2
label.Parent = pill

local function paint()
	label.Text = if Potato.on then "Potato: ON" else "Potato: OFF"
end

-- Roblox: the background's transparency times the player's preferred transparency (Settings: Background transparency)
local function paintBack()
	local ok, k = pcall(function()
		return GuiService.PreferredTransparency
	end)
	pill.BackgroundTransparency = BACK_ALPHA * (if ok and type(k) == "number" then k else 1)
end

local function setWash(state: string)
	if state == "press" then
		wash.BackgroundColor3 = PRESS
		wash.BackgroundTransparency = PRESS_ALPHA
	elseif state == "hover" then
		wash.BackgroundColor3 = HOVER
		wash.BackgroundTransparency = HOVER_ALPHA
	else
		wash.BackgroundTransparency = 1
	end
end

-- our own day / night bar (client/Hud, top centre) shares the row: on a narrow phone the pill stops short of it
local dayBar: GuiObject? = nil

-- Size and place it in the top-bar row (again whenever the row changes: the chat opening, the screen turning ...).
local function layout()
	local inset = GuiService.TopbarInset
	local left, top, right, bar = inset.Min.X, inset.Min.Y, inset.Max.X, inset.Height
	local cam = workspace.CurrentCamera
	if Device.preview then
		-- (Studio's phone preview: beside the phone's top bar as client/PhonePreview draws it)
		local s = Device.previewScale()
		left, top, bar = 210 * s, 0, 58 * s
		right = if cam then cam.ViewportSize.X else left + 400
	end
	local day = dayBar
	if day and day.Visible and day.AbsoluteSize.X > 0 then
		right = math.min(right, day.AbsolutePosition.X - 8)
	end
	if bar < 20 then
		pill.Visible = false -- (Roblox's top bar is hidden, or not measured yet)
		return
	end
	local k = bar / BAR
	local h, under
	if bar <= 40 then
		h, under = bar - 4, 0 -- (Roblox's old 36 px bar: 32 px buttons resting on its bottom)
	else
		h, under = math.floor(BUTTON * k + 0.5), UNDER * k
	end
	local size = math.max(12, math.floor(TEXT_SIZE * k + 0.5))
	label.TextSize = size
	local words = TextService:GetTextSize(WIDEST, size, FONT, Vector2.new(10000, 10000)).X
	local gap = GAP * k
	local room = right - left - gap
	local w = math.max(h, math.ceil(words + 2 * SIDE * k))
	if w > room then
		w = math.max(h, math.ceil(words + 2 * 8 * k))
	end
	if w > room then
		pill.Visible = false -- (no room beside Roblox's buttons: never on top of them)
		return
	end
	local x = left + gap - origin.AbsolutePosition.X
	pill.Size = UDim2.fromOffset(w, h)
	pill.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(top + bar - under - h + 0.5))
	pill.Visible = true
end

-- hover and press, like Roblox's buttons (GuiState covers mouse, touch and gamepad; older clients: mouse events)
local hasState = pcall(function()
	pill:GetPropertyChangedSignal("GuiState"):Connect(function()
		local s = pill.GuiState
		setWash(if s == Enum.GuiState.Press then "press" elseif s == Enum.GuiState.Hover then "hover" else "idle")
	end)
end)
if not hasState then
	pill.MouseEnter:Connect(function()
		setWash("hover")
	end)
	pill.MouseLeave:Connect(function()
		setWash("idle")
	end)
	pill.MouseButton1Down:Connect(function()
		setWash("press")
	end)
	pill.MouseButton1Up:Connect(function()
		setWash("hover")
	end)
end

pill.Activated:Connect(function()
	Potato.toggle()
	paint()
	UI.toast(if Potato.on then "🥔 Potato Mode ON: low graphics, smoother on slow devices" else "Potato Mode OFF: full graphics", if Potato.on then "green" else nil)
end)

-- switched anywhere else (SETTINGS, the saved choice arriving): the words follow at once
player:GetAttributeChangedSignal("Potato"):Connect(paint)
Potato.changed(function()
	paint()
end)

GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
origin:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
pcall(function()
	GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(paintBack)
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

task.spawn(function()
	local hud = UI.gui:WaitForChild("Hud", 30)
	local d = hud and hud:WaitForChild("DayBar", 30)
	if d and d:IsA("GuiObject") then
		dayBar = d
		for _, prop in { "Visible", "AbsolutePosition", "AbsoluteSize" } do
			d:GetPropertyChangedSignal(prop):Connect(layout)
		end
		layout()
	end
end)

paint()
paintBack()
gui.Parent = player:WaitForChild("PlayerGui")
layout()
task.defer(layout) -- (once the gui has been laid out, so the origin's position is known)

PotatoPill.gui = gui
PotatoPill.button = pill

return PotatoPill
