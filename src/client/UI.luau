-- UI kit: bright flat panels, thick dark outlines, bubbly font, bouncy buttons.
-- Everything is laid out at 1280x720 and scaled with a UIScale, so phones and PCs get the same layout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local UI = {}
local C = Config.UI
UI.colors = C

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "MowALawnGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
UI.gui = gui

local scale = Instance.new("UIScale")
scale.Parent = gui
local function rescale()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.5)
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

function UI.shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

function UI.corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
	return c
end

function UI.stroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or C.outline
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Light-to-dark vertical gradient on a filled frame (the "soft top light" look).
function UI.gradient(parent: Instance, color: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(color, 1.15), UI.shade(color, 0.85))
	g.Rotation = 90
	g.Parent = parent
	return g
end

type FrameProps = { size: UDim2, pos: UDim2?, anchor: Vector2?, color: Color3?, parent: Instance, name: string?, transparency: number?, radius: number?, outline: number? }
function UI.frame(p: FrameProps): Frame
	local f = Instance.new("Frame")
	f.Name = p.name or "Frame"
	f.Size = p.size
	f.Position = p.pos or UDim2.new()
	f.AnchorPoint = p.anchor or Vector2.zero
	f.BackgroundColor3 = p.color or C.panel
	f.BackgroundTransparency = p.transparency or 0
	f.BorderSizePixel = 0
	if p.radius ~= 0 then
		UI.corner(f, p.radius)
	end
	if p.outline ~= 0 then
		UI.stroke(f, p.outline)
	end
	f.Parent = p.parent
	return f
end

-- Outlined bubbly text.
function UI.text(parent: Instance, text: string, size: UDim2, props: { pos: UDim2?, anchor: Vector2?, color: Color3?, align: Enum.TextXAlignment?, stroke: number?, name: string?, textSize: number? }?): TextLabel
	local o = props or {}
	local t = Instance.new("TextLabel")
	t.Name = o.name or "Text"
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = o.pos or UDim2.new()
	t.AnchorPoint = o.anchor or Vector2.zero
	t.Font = C.font
	t.Text = text
	t.TextColor3 = o.color or Color3.new(1, 1, 1)
	t.TextXAlignment = o.align or Enum.TextXAlignment.Center
	if o.textSize then
		t.TextSize = o.textSize
		t.TextWrapped = true
	else
		t.TextScaled = true
	end
	local s = Instance.new("UIStroke")
	s.Thickness = o.stroke or 2.5
	s.Color = C.outline
	s.Parent = t
	t.Parent = parent
	return t
end

local function bounce(obj: GuiObject)
	local sc = obj:FindFirstChild("Bounce") :: UIScale?
	if not sc then
		local n = Instance.new("UIScale")
		n.Name = "Bounce"
		n.Parent = obj
		sc = n
	end
	local s = sc :: UIScale
	s.Scale = 0.88
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
UI.bounce = bounce

-- Chunky button with a darker "lip" underneath, gradient fill and outline.
function UI.button(parent: Instance, text: string, color: Color3, size: UDim2, onClick: () -> (), props: { pos: UDim2?, anchor: Vector2?, name: string? }?): TextButton
	local o = props or {}
	local b = Instance.new("TextButton")
	b.Name = o.name or "Button"
	b.Size = size
	b.Position = o.pos or UDim2.new()
	b.AnchorPoint = o.anchor or Vector2.zero
	b.BackgroundColor3 = color
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	UI.corner(b, 10)
	UI.stroke(b, 3)
	UI.gradient(b, color)
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.Size = UDim2.new(1, 0, 0, 6)
	lip.Position = UDim2.new(0, 0, 1, -6)
	lip.BackgroundColor3 = UI.shade(color, 0.6)
	lip.BorderSizePixel = 0
	lip.ZIndex = b.ZIndex
	UI.corner(lip, 6)
	lip.Parent = b
	local label = UI.text(b, text, UDim2.new(1, -12, 1, -12), { pos = UDim2.fromOffset(6, 3), name = "Label" })
	label.ZIndex = b.ZIndex + 1
	b.MouseButton1Click:Connect(function()
		bounce(b)
		onClick()
	end)
	b.Parent = parent
	return b
end

function UI.setButton(b: TextButton, text: string, color: Color3?)
	local label = b:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
	if color then
		b.BackgroundColor3 = color
		local g = b:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = ColorSequence.new(UI.shade(color, 1.15), UI.shade(color, 0.85))
		end
		local lip = b:FindFirstChild("Lip") :: Frame?
		if lip then
			lip.BackgroundColor3 = UI.shade(color, 0.6)
		end
	end
end

-- Small drawn icons (no emoji fonts needed).
function UI.coinIcon(parent: Instance, size: number, pos: UDim2?): Frame
	local f = UI.frame({ size = UDim2.fromOffset(size, size), pos = pos, color = C.yellow, parent = parent, radius = size, outline = 2.5, name = "CoinIcon" })
	UI.gradient(f, C.yellow)
	UI.frame({ size = UDim2.fromScale(0.45, 0.45), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = UI.shade(C.yellow, 0.8), parent = f, radius = size, outline = 0 })
	return f
end

function UI.gemIcon(parent: Instance, size: number, pos: UDim2?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "GemIcon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Position = pos or UDim2.new()
	holder.Parent = parent
	local f = UI.frame({ size = UDim2.fromScale(0.72, 0.72), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = C.purple, parent = holder, radius = 4, outline = 2.5 })
	f.Rotation = 45
	UI.gradient(f, C.purple)
	return holder
end

function UI.bundleIcon(parent: Instance, size: number, pos: UDim2?): Frame
	local f = UI.frame({ size = UDim2.fromOffset(size, size * 0.7), pos = pos, color = Color3.fromRGB(150, 220, 80), parent = parent, radius = 4, outline = 2.5, name = "BundleIcon" })
	UI.frame({ size = UDim2.new(0.22, 0, 1, 0), pos = UDim2.fromScale(0.39, 0), color = C.yellow, parent = f, radius = 0, outline = 0 })
	return f
end

-------------------------------------------------------------------------------------------------------------
-- windows: one open at a time
-------------------------------------------------------------------------------------------------------------
local windows: { [string]: any } = {}
local openName: string? = nil
UI.onWindowChanged = Instance.new("BindableEvent")

function UI.window(name: string, title: string, color: Color3)
	local frame = UI.frame({ size = UDim2.fromOffset(660, 460), pos = UDim2.fromScale(0.5, 0.52), anchor = Vector2.new(0.5, 0.5), color = C.panel, parent = gui, radius = 18, outline = 4, name = name .. "Window" })
	frame.Visible = false
	frame.ZIndex = 10
	local header = UI.frame({ size = UDim2.new(1, 0, 0, 64), color = color, parent = frame, radius = 18, outline = 0, name = "Header" })
	UI.gradient(header, color)
	-- square off the header's bottom corners
	UI.frame({ size = UDim2.new(1, 0, 0, 18), pos = UDim2.new(0, 0, 1, -18), color = UI.shade(color, 0.86), parent = header, radius = 0, outline = 0 })
	UI.text(header, title, UDim2.new(1, -140, 0, 46), { pos = UDim2.fromOffset(24, 9), align = Enum.TextXAlignment.Left, stroke = 3, name = "Title" })
	local w = { name = name, frame = frame, header = header }
	UI.button(frame, "X", C.red, UDim2.fromOffset(52, 52), function()
		UI.close()
	end, { pos = UDim2.new(1, -14, 0, -14), anchor = Vector2.new(0.5, 0.5), name = "Close" })
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, -32, 1, -88)
	list.Position = UDim2.fromOffset(16, 76)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = C.outline
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = list
	list.Parent = frame
	w.list = list
	w.refresh = function() end
	windows[name] = w
	return w
end

function UI.open(name: string)
	if openName == name then
		UI.close()
		return
	end
	UI.close()
	local w = windows[name]
	if not w then
		return
	end
	openName = name
	w.frame.Visible = true
	w.refresh()
	bounce(w.frame)
	UI.onWindowChanged:Fire(name)
end

function UI.close()
	if openName and windows[openName] then
		windows[openName].frame.Visible = false
	end
	openName = nil
	UI.onWindowChanged:Fire(nil)
end

function UI.isOpen(name: string): boolean
	return openName == name
end

function UI.refreshOpen()
	if openName and windows[openName] then
		windows[openName].refresh()
	end
end

-- A row card inside a window list: colour strip, title, description, and a button on the right.
function UI.card(list: Instance, order: number, color: Color3, title: string, desc: string, buttonText: string, buttonColor: Color3, onClick: () -> ())
	local card = UI.frame({ size = UDim2.new(1, 0, 0, 84), color = Color3.new(1, 1, 1), parent = list, radius = 14, outline = 3, name = "Card" })
	card.LayoutOrder = order
	local strip = UI.frame({ size = UDim2.new(0, 14, 1, 0), color = color, parent = card, radius = 14, outline = 0 })
	strip.Name = "Strip"
	UI.text(card, title, UDim2.new(1, -230, 0, 34), { pos = UDim2.fromOffset(28, 8), align = Enum.TextXAlignment.Left, color = UI.shade(color, 0.95), name = "Title" })
	local d = UI.text(card, desc, UDim2.new(1, -230, 0, 30), { pos = UDim2.fromOffset(28, 44), align = Enum.TextXAlignment.Left, color = C.dark, stroke = 0, name = "Desc" })
	d.TextScaled = true
	local btn = UI.button(card, buttonText, buttonColor, UDim2.fromOffset(170, 58), onClick, { pos = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "Action" })
	return card, btn
end

function UI.clear(list: Instance)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- toasts (top centre, max 3)
-------------------------------------------------------------------------------------------------------------
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.BackgroundTransparency = 1
toastHolder.Size = UDim2.fromOffset(720, 200)
toastHolder.Position = UDim2.new(0.5, 0, 0, 110)
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.ZIndex = 50
toastHolder.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastHolder

function UI.toast(text: string, colorName: string?)
	local color = (C :: any)[colorName or "yellow"] or C.yellow
	local kids = {}
	for _, k in toastHolder:GetChildren() do
		if k:IsA("TextLabel") then
			table.insert(kids, k)
		end
	end
	if #kids >= 3 then
		kids[1]:Destroy()
	end
	local t = UI.text(toastHolder, text, UDim2.fromOffset(700, 40), { color = color, stroke = 3 })
	t.ZIndex = 50
	bounce(t)
	task.delay(3.2, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local s = t:FindFirstChildOfClass("UIStroke")
			if s then
				TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
			task.wait(0.45)
			t:Destroy()
		end
	end)
end

return UI
