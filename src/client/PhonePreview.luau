-- Studio's phone preview (client/Device: the Workspace attribute PhonePreview): draws, over the game, where a
-- phone's own bits would be, at a phone's proportions (the phone's height fills Studio's screen):
--   * Roblox's top bar (its buttons sit in the top-left corner)
--   * the thumbstick (where it rests, and the bottom-left area where a thumb starts it) and the jump button
--   * the notch and rounded corners of an iPhone held sideways, and the home bar along the bottom
--   * a 44-point square: Apple's smallest comfortable button, to hold buttons against
-- Nothing here takes clicks, and none of it exists outside Studio.
local Players = game:GetService("Players")

local Device = require(script.Parent.Device)

local PhonePreview = {}

if not Device.preview then
	return PhonePreview
end

local phone = Device.previewScreen :: Vector2
local gui = Instance.new("ScreenGui")
gui.Name = "PhonePreview"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Active = false
root.Parent = gui

local function box(name: string, color: Color3, alpha: number, round: boolean?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha
	f.BorderSizePixel = 0
	f.Active = false
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
	end
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 2
	s.Transparency = 0.2
	s.Parent = f
	f.Parent = root
	return f
end

local function label(parent: Instance, text: string, size: number)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.TextSize = size
	t.TextWrapped = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Parent = parent
end

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 70, 70)
local BLUE = Color3.fromRGB(80, 170, 255)

local topbar = box("TopBar", WHITE, 0.85)
local stickZone = box("ThumbstickArea", BLUE, 0.9)
local stick = box("Thumbstick", BLUE, 0.55, true)
local jump = box("Jump", BLUE, 0.55, true)
local notchL = box("NotchLeft", RED, 0.82)
local notchR = box("NotchRight", RED, 0.82)
local homeBar = box("HomeBar", RED, 0.82)
local tap = box("Tap44", Color3.fromRGB(255, 220, 60), 0.6)
local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.Size = UDim2.fromOffset(520, 18)
info.AnchorPoint = Vector2.new(0.5, 1)
info.Position = UDim2.new(0.5, 0, 1, -2)
info.Font = Enum.Font.GothamBold
info.TextSize = 13
info.TextColor3 = WHITE
info.TextStrokeTransparency = 0.3
info.Parent = root
label(stickZone, "", 12)
label(stick, "MOVE", 14)
label(jump, "JUMP", 14)
label(tap, "44pt", 13)

local function layout()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local k = Device.previewScale() -- Studio pixels per phone point
	local W, H = vp.X, vp.Y
	local function place(f: Frame, x: number, y: number, w: number, h: number)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
	end
	-- (Roblox's numbers for a small touch screen: TouchJump and DynamicThumbstick)
	place(topbar, 0, 0, 210 * k, Device.topInset())
	place(stickZone, 0, H / 3, W * 0.4, H * 2 / 3)
	place(stick, 66 * k - 37 * k, H - 56 * k - 37 * k, 74 * k, 74 * k)
	place(jump, W - 95 * k, H - 90 * k, 70 * k, 70 * k)
	place(notchL, 0, 0, 47 * k, H)
	place(notchR, W - 47 * k, 0, 47 * k, H)
	place(homeBar, 0, H - 21 * k, W, 21 * k)
	place(tap, W / 2 - 22 * k, H / 3, 44 * k, 44 * k)
	info.Text = ("PHONE PREVIEW %dx%d   1 pt = %.2f px   (a real %dx%d phone is %d px wider each side)"):format(phone.X, phone.Y, k, phone.X, phone.Y, math.max(0, math.floor((phone.X * k - W) / 2)))
end
layout()
local cam = workspace.CurrentCamera
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

return PhonePreview
