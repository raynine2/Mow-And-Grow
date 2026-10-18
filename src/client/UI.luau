-- UI kit: bright flat panels, thick dark outlines, bubbly font, bouncy buttons.
-- Everything is laid out at 1280x720 and scaled with a UIScale, so phones and PCs get the same layout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Sound = require(script.Parent.Sound)

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
		Sound.play("click")
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

-------------------------------------------------------------------------------------------------------------
-- icons: uploaded images when Config.ICONS has an id, otherwise a drawn stand-in
-------------------------------------------------------------------------------------------------------------
local function circle(parent: Instance, size: UDim2, pos: UDim2, color: Color3, outline: number?): Frame
	local f = UI.frame({ size = size, pos = pos, anchor = Vector2.new(0.5, 0.5), color = color, parent = parent, radius = 999, outline = outline or 0 })
	return f
end

function UI.icon(parent: Instance, key: string, size: number, pos: UDim2?, anchor: Vector2?): GuiObject
	local id = Config.ICONS and Config.ICONS[key]
	if id and id ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon_" .. key
		img.BackgroundTransparency = 1
		img.Image = id
		img.Size = UDim2.fromOffset(size, size)
		img.Position = pos or UDim2.new()
		img.AnchorPoint = anchor or Vector2.zero
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = parent
		return img
	end
	local holder = Instance.new("Frame")
	holder.Name = "Icon_" .. key
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Position = pos or UDim2.new()
	holder.AnchorPoint = anchor or Vector2.zero
	holder.Parent = parent
	local c = UDim2.fromScale(0.5, 0.5)
	if key == "coin" then
		local o = circle(holder, UDim2.fromScale(0.92, 0.92), c, Color3.fromRGB(240, 170, 30), 2.5)
		UI.gradient(o, Color3.fromRGB(255, 200, 50))
		circle(holder, UDim2.fromScale(0.58, 0.58), c, Color3.fromRGB(255, 215, 80), 0)
		circle(holder, UDim2.fromScale(0.36, 0.36), c, Color3.fromRGB(235, 160, 30), 0)
	elseif key == "gem" then
		local light = Color3.fromRGB(150, 220, 255)
		UI.frame({ size = UDim2.fromScale(0.9, 0.34), pos = UDim2.fromScale(0.05, 0.16), color = light, parent = holder, radius = 6, outline = 2.5 })
		local body = UI.frame({ size = UDim2.fromScale(0.6, 0.46), pos = UDim2.fromScale(0.2, 0.46), color = Color3.fromRGB(60, 160, 245), parent = holder, radius = 10, outline = 2.5 })
		UI.gradient(body, Color3.fromRGB(70, 170, 250))
		UI.frame({ size = UDim2.fromScale(0.2, 0.12), pos = UDim2.fromScale(0.2, 0.24), color = Color3.new(1, 1, 1), parent = holder, radius = 4, outline = 0 }).BackgroundTransparency = 0.2
	elseif key == "bundle" then
		local b = UI.frame({ size = UDim2.fromScale(0.92, 0.6), pos = UDim2.fromScale(0.04, 0.22), color = Color3.fromRGB(120, 200, 70), parent = holder, radius = 8, outline = 2.5 })
		UI.gradient(b, Color3.fromRGB(130, 210, 75))
		for _, x in { 0.28, 0.62 } do
			UI.frame({ size = UDim2.fromScale(0.12, 1), pos = UDim2.fromScale(x, 0), color = Color3.fromRGB(200, 140, 60), parent = b, radius = 0, outline = 0 })
		end
	elseif key == "backpack" then
		local bag = UI.frame({ size = UDim2.fromScale(0.78, 0.78), pos = UDim2.fromScale(0.11, 0.18), color = Color3.fromRGB(150, 95, 55), parent = holder, radius = 10, outline = 2.5 })
		UI.gradient(bag, Color3.fromRGB(160, 102, 58))
		UI.frame({ size = UDim2.fromScale(0.5, 0.18), pos = UDim2.fromScale(0.25, 0.06), color = Color3.fromRGB(120, 75, 42), parent = holder, radius = 6, outline = 2 })
		UI.frame({ size = UDim2.fromScale(0.6, 0.3), pos = UDim2.fromScale(0.2, 0.55), color = Color3.fromRGB(125, 78, 44), parent = holder, radius = 6, outline = 2 })
		UI.frame({ size = UDim2.fromScale(0.14, 0.14), pos = UDim2.fromScale(0.43, 0.5), color = Color3.fromRGB(230, 180, 60), parent = holder, radius = 3, outline = 0 })
	elseif key == "basket" then
		local b = UI.frame({ size = UDim2.fromScale(0.84, 0.5), pos = UDim2.fromScale(0.08, 0.42), color = Color3.fromRGB(225, 60, 60), parent = holder, radius = 8, outline = 2.5 })
		UI.gradient(b, Color3.fromRGB(235, 70, 70))
		UI.frame({ size = UDim2.fromScale(0.56, 0.4), pos = UDim2.fromScale(0.22, 0.1), color = Color3.fromRGB(0, 0, 0), parent = holder, radius = 999, outline = 0 }).BackgroundTransparency = 1
		local handle = UI.frame({ size = UDim2.fromScale(0.56, 0.44), pos = UDim2.fromScale(0.22, 0.08), color = Color3.new(1, 1, 1), parent = holder, radius = 999, outline = 3 })
		handle.BackgroundTransparency = 1
		local hs = handle:FindFirstChildOfClass("UIStroke") :: UIStroke
		hs.Color = Color3.fromRGB(80, 90, 110)
		hs.Thickness = 4
	elseif key == "upgrade" then
		local shaft = UI.frame({ size = UDim2.fromScale(0.34, 0.5), pos = UDim2.fromScale(0.33, 0.45), color = Color3.fromRGB(90, 205, 60), parent = holder, radius = 4, outline = 2.5 })
		UI.gradient(shaft, Color3.fromRGB(100, 215, 70))
		for i = 0, 3 do
			local w = 0.82 - i * 0.2
			UI.frame({ size = UDim2.fromScale(w, 0.1), pos = UDim2.fromScale((1 - w) / 2, 0.36 - i * 0.09), color = Color3.fromRGB(100, 215, 70), parent = holder, radius = 3, outline = 0 })
		end
	elseif key == "lock" then
		local body = UI.frame({ size = UDim2.fromScale(0.7, 0.5), pos = UDim2.fromScale(0.15, 0.42), color = Color3.fromRGB(245, 175, 40), parent = holder, radius = 6, outline = 2.5 })
		UI.gradient(body, Color3.fromRGB(250, 185, 50))
		local shackle = UI.frame({ size = UDim2.fromScale(0.5, 0.5), pos = UDim2.fromScale(0.25, 0.1), color = Color3.new(1, 1, 1), parent = holder, radius = 999, outline = 3 })
		shackle.BackgroundTransparency = 1
		shackle.ZIndex = 0
	elseif key == "clover" then
		for _, p in { { 0.3, 0.3 }, { 0.7, 0.3 }, { 0.3, 0.7 }, { 0.7, 0.7 } } do
			circle(holder, UDim2.fromScale(0.46, 0.46), UDim2.fromScale(p[1], p[2]), Color3.fromRGB(70, 185, 60), 2)
		end
	elseif key == "leaf" then
		local l = UI.frame({ size = UDim2.fromScale(1, 0.56), pos = UDim2.fromScale(0, 0.22), color = Color3.fromRGB(110, 185, 60), parent = holder, radius = 999, outline = 2.5 })
		UI.gradient(l, Color3.fromRGB(120, 195, 65))
		UI.frame({ size = UDim2.fromScale(0.8, 0.08), pos = UDim2.fromScale(0.1, 0.46), color = Color3.fromRGB(70, 130, 40), parent = holder, radius = 2, outline = 0 })
	else
		circle(holder, UDim2.fromScale(0.85, 0.85), c, Color3.fromRGB(200, 200, 210), 2.5)
	end
	return holder
end

-- Old helpers kept for callers (now drawn through UI.icon).
function UI.coinIcon(parent: Instance, size: number, pos: UDim2?): GuiObject
	return UI.icon(parent, "coin", size, pos)
end
function UI.gemIcon(parent: Instance, size: number, pos: UDim2?): GuiObject
	return UI.icon(parent, "gem", size, pos)
end
function UI.bundleIcon(parent: Instance, size: number, pos: UDim2?): GuiObject
	return UI.icon(parent, "bundle", size, pos)
end

-------------------------------------------------------------------------------------------------------------
-- wooden boards (Chop A Forest style): orange-brown frame, tan plank panel, leaves on the corners
-------------------------------------------------------------------------------------------------------------
local WOOD = {
	frame = Color3.fromRGB(214, 128, 60),
	frameEdge = Color3.fromRGB(96, 54, 26),
	plank = Color3.fromRGB(242, 210, 158),
	plankLine = Color3.fromRGB(222, 184, 128),
	inset = Color3.fromRGB(178, 128, 82),
	tab = Color3.fromRGB(216, 172, 112),
	tabActive = Color3.fromRGB(118, 214, 58),
	blue = Color3.fromRGB(64, 156, 250),
	blueEdge = Color3.fromRGB(24, 70, 150),
	purple = Color3.fromRGB(170, 70, 235),
	grey = Color3.fromRGB(160, 160, 168),
	red = Color3.fromRGB(222, 64, 52),
	brownText = Color3.fromRGB(110, 62, 30),
}
UI.wood = WOOD

-- A plank panel: tan with faint horizontal plank lines.
function UI.planks(parent: Instance, size: UDim2, pos: UDim2?, color: Color3?, radius: number?): Frame
	local f = UI.frame({ size = size, pos = pos, color = color or WOOD.plank, parent = parent, radius = radius or 14, outline = 0, name = "Planks" })
	f.ClipsDescendants = true
	for i = 1, 7 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = WOOD.plankLine
		line.Size = UDim2.new(1, 0, 0, 2)
		line.Position = UDim2.fromScale(0, i / 8)
		line.Parent = f
	end
	return f
end

-- Decorative leaf on a board corner.
local function leaf(parent: Instance, pos: UDim2, size: number)
	local l = UI.icon(parent, "leaf", size, pos, Vector2.new(0.5, 0.5))
	l.ZIndex = 5
	for _, d in l:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 5
		end
	end
end

-- Red square close button.
function UI.closeButton(parent: Instance, pos: UDim2, onClick: () -> ()): TextButton
	local b = UI.button(parent, "X", WOOD.red, UDim2.fromOffset(62, 62), onClick, { pos = pos, anchor = Vector2.new(1, 0), name = "Close" })
	b.ZIndex = 6
	return b
end

-- Small "level" pips row, like the dark leaf dots under each perk.
function UI.pips(parent: Instance, level: number, max: number, pos: UDim2, width: number)
	local row = Instance.new("Frame")
	row.Name = "Pips"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(width, 16)
	row.Position = pos
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	local pipW = math.clamp(math.floor((width - (max - 1) * 6) / max), 10, 30)
	for i = 1, max do
		local p = UI.frame({ size = UDim2.fromOffset(pipW, 14), color = if i <= level then Color3.fromRGB(120, 220, 70) else Color3.fromRGB(30, 50, 30), parent = row, radius = 999, outline = 0 })
		p.LayoutOrder = i
	end
	return row
end

-------------------------------------------------------------------------------------------------------------
-- windows: one open at a time
-------------------------------------------------------------------------------------------------------------
local windows: { [string]: any } = {}
local openName: string? = nil
UI.onWindowChanged = Instance.new("BindableEvent")

type WindowOpts = { tabs: { { label: string, window: string, icon: string? } }?, grid: Vector2?, gems: boolean? }

-- A wooden board window. `opts.tabs` adds tabs across the top (the current one is green); `opts.grid` lays the
-- content out as a grid of cards of that cell size; `opts.gems` shows the gem counter box.
function UI.window(name: string, title: string, _color: Color3?, opts: WindowOpts?)
	local o = opts or {}
	local holder = Instance.new("Frame")
	holder.Name = name .. "Window"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(900, 560)
	holder.Position = UDim2.fromScale(0.5, 0.54)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	holder.ZIndex = 10
	holder.Parent = gui
	local board = UI.frame({ size = UDim2.fromScale(1, 1), color = WOOD.frame, parent = holder, radius = 26, outline = 5, name = "Board" })
	;(board:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = WOOD.frameEdge
	UI.gradient(board, WOOD.frame)
	local panel = UI.planks(board, UDim2.new(1, -28, 1, -28), UDim2.fromOffset(14, 14))
	UI.stroke(panel, 2, Color3.fromRGB(160, 100, 52))
	leaf(holder, UDim2.fromOffset(18, 548), 74)
	leaf(holder, UDim2.fromOffset(888, 520), 64)
	leaf(holder, UDim2.fromOffset(470, 6), 58)

	-- tabs (or a single title tab)
	local tabs = o.tabs or { { label = title, window = name } }
	for i, t in tabs do
		local active = t.window == name
		local b = UI.button(holder, string.upper(t.label), if active then WOOD.tabActive else WOOD.tab, UDim2.fromOffset(230, 58), function()
			if not active then
				UI.open(t.window)
			end
		end, { pos = UDim2.fromOffset(24 + (i - 1) * 244, -30), name = "Tab" .. i })
		b.ZIndex = 6
		if not active then
			local label = b:FindFirstChild("Label") :: TextLabel
			label.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	local w = { name = name, frame = holder, panel = panel }
	if o.gems then
		local box = UI.frame({ size = UDim2.fromOffset(200, 56), pos = UDim2.new(1, -88, 0, -28), anchor = Vector2.new(1, 0), color = WOOD.tab, parent = holder, radius = 10, outline = 3, name = "GemBox" })
		box.ZIndex = 6
		UI.icon(box, "gem", 42, UDim2.fromOffset(10, 7)).ZIndex = 7
		local t = UI.text(box, "0", UDim2.new(1, -66, 1, -12), { pos = UDim2.fromOffset(58, 6), align = Enum.TextXAlignment.Left, name = "Count" })
		t.ZIndex = 7
		w.gemText = t
	end
	UI.closeButton(holder, UDim2.new(1, 10, 0, -28), function()
		UI.close()
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, -60, 1, -84)
	list.Position = UDim2.fromOffset(30, 52)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = WOOD.frameEdge
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 3
	if o.grid then
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(o.grid.X, o.grid.Y)
		grid.CellPadding = UDim2.fromOffset(18, 18)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = list
	else
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 12)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = list
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = list
	list.Parent = panel
	w.list = list
	w.refresh = function() end
	windows[name] = w
	return w
end

-- A smaller brown popup board (like Chop A Forest's GROUP REWARD panel): big title, orange subtitle, a line,
-- a content area (w.list) and a big green action button (w.action, hidden until used).
function UI.popupWindow(name: string, title: string, sub: string?)
	local holder = Instance.new("Frame")
	holder.Name = name .. "Popup"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(500, 560)
	holder.Position = UDim2.fromScale(0.5, 0.53)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	holder.ZIndex = 10
	holder.Parent = gui
	local board = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(196, 150, 104), parent = holder, radius = 22, outline = 5, name = "Board" })
	;(board:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = WOOD.frameEdge
	UI.gradient(board, Color3.fromRGB(200, 154, 108))
	leaf(holder, UDim2.fromOffset(40, 16), 70)
	leaf(holder, UDim2.fromOffset(470, 500), 70)
	local titleLabel = UI.text(holder, string.upper(title), UDim2.new(1, -60, 0, 60), { pos = UDim2.fromOffset(30, 34), stroke = 4, color = Color3.new(1, 1, 1) })
	local subLabel = UI.text(holder, sub and string.upper(sub) or "", UDim2.new(1, -80, 0, 28), { pos = UDim2.fromOffset(40, 96), stroke = 2, color = Color3.fromRGB(255, 200, 60) })
	UI.frame({ size = UDim2.new(1, -100, 0, 4), pos = UDim2.fromOffset(50, 132), color = Color3.new(1, 1, 1), parent = holder, radius = 2, outline = 0 })
	UI.closeButton(holder, UDim2.new(1, -10, 0, 12), function()
		UI.close()
	end)
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -60, 1, -250)
	list.Position = UDim2.fromOffset(30, 148)
	list.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local action = UI.button(holder, "DONE", C.green, UDim2.fromOffset(260, 66), function() end, { pos = UDim2.new(0.5, 0, 1, -24), anchor = Vector2.new(0.5, 1), name = "Action" })
	local w = { name = name, frame = holder, list = list, action = action, title = titleLabel, sub = subLabel, onAction = nil :: (() -> ())? }
	action.MouseButton1Click:Connect(function()
		if w.onAction then
			w.onAction()
		end
	end)
	w.refresh = function() end
	windows[name] = w
	return w
end

-- A plank row inside a popup: icon, text, and an optional tick box / value on the right.
function UI.popupRow(list: Instance, order: number, icon: string?, text: string, right: string?, rightColor: Color3?)
	local row = UI.frame({ size = UDim2.new(1, -10, 0, 58), color = Color3.fromRGB(176, 128, 84), parent = list, radius = 8, outline = 2, name = "Row" })
	;(row:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(120, 80, 45)
	row.LayoutOrder = order
	local x = 14
	if icon then
		UI.icon(row, icon, 40, UDim2.fromOffset(12, 9))
		x = 62
	end
	UI.text(row, string.upper(text), UDim2.new(1, -x - 110, 1, -16), { pos = UDim2.fromOffset(x, 8), align = Enum.TextXAlignment.Left, stroke = 2 })
	if right then
		UI.text(row, right, UDim2.fromOffset(100, 40), { pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, color = rightColor or C.green, stroke = 2 })
	end
	return row
end

function UI.setGems(amount: number)
	for _, w in windows do
		if w.gemText then
			w.gemText.Text = tostring(amount)
		end
	end
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
	Sound.play("whoosh")
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

-- A section heading inside a window (dark brown inset bar).
function UI.heading(list: Instance, order: number, text: string)
	local bar = UI.frame({ size = UDim2.new(1, -10, 0, 44), color = WOOD.inset, parent = list, radius = 10, outline = 0, name = "Heading" })
	bar.LayoutOrder = order
	UI.text(bar, string.upper(text), UDim2.new(1, -20, 1, -10), { pos = UDim2.fromOffset(10, 5) })
	return bar
end

type CardOpts = {
	title: string,
	sub: string?,
	icon: string?,
	level: number?,
	max: number?,
	price: string,
	priceIcon: string?,
	enabled: boolean,
	color: Color3?,
	onClick: () -> (),
}
-- The blue perk/upgrade card: title, small subtitle, icon, level pips and a price button (purple when you can buy).
function UI.blueCard(list: Instance, order: number, o: CardOpts)
	local base = o.color or WOOD.blue
	local card = UI.frame({ size = UDim2.fromScale(1, 1), color = base, parent = list, radius = 16, outline = 4, name = "Card" })
	;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = UI.shade(base, 0.45)
	card.LayoutOrder = order
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(base, 1.18), UI.shade(base, 0.82))
	g.Rotation = 90
	g.Parent = card
	UI.text(card, string.upper(o.title), UDim2.new(1, -20, 0, 34), { pos = UDim2.fromOffset(10, 8), stroke = 3 })
	if o.sub then
		UI.text(card, o.sub, UDim2.new(1, -24, 0, 20), { pos = UDim2.fromOffset(12, 42), stroke = 1.5 })
	end
	if o.icon then
		UI.icon(card, o.icon, 54, UDim2.new(0.5, 0, 0, 66), Vector2.new(0.5, 0))
	end
	if o.max and o.max > 0 then
		UI.pips(card, o.level or 0, o.max, UDim2.new(0.5, 0, 1, -76), 220)
	end
	local btn = UI.button(card, o.price, if o.enabled then WOOD.purple else WOOD.grey, UDim2.fromOffset(200, 46), function()
		o.onClick()
	end, { pos = UDim2.new(0.5, 0, 1, -12), anchor = Vector2.new(0.5, 1), name = "Price" })
	if o.priceIcon then
		local label = btn:FindFirstChild("Label") :: TextLabel
		label.Size = UDim2.new(1, -50, 1, -12)
		label.Position = UDim2.fromOffset(44, 3)
		UI.icon(btn, o.priceIcon, 28, UDim2.fromOffset(16, 8)).ZIndex = btn.ZIndex + 1
	end
	return card, btn
end

-- A row card for lists (classes list, store items): plank row with a colour strip, title, text, button.
function UI.card(list: Instance, order: number, color: Color3, title: string, desc: string, buttonText: string, buttonColor: Color3, onClick: () -> ())
	local card = UI.frame({ size = UDim2.new(1, -10, 0, 86), color = Color3.fromRGB(250, 228, 190), parent = list, radius = 14, outline = 3, name = "Card" })
	;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(150, 95, 50)
	card.LayoutOrder = order
	UI.frame({ size = UDim2.new(0, 14, 1, 0), color = color, parent = card, radius = 14, outline = 0, name = "Strip" })
	UI.text(card, title, UDim2.new(1, -240, 0, 34), { pos = UDim2.fromOffset(28, 8), align = Enum.TextXAlignment.Left, color = Color3.new(1, 1, 1), name = "Title" })
	local d = UI.text(card, desc, UDim2.new(1, -240, 0, 28), { pos = UDim2.fromOffset(28, 46), align = Enum.TextXAlignment.Left, color = WOOD.brownText, stroke = 0, name = "Desc" })
	d.TextScaled = true
	local btn = UI.button(card, buttonText, buttonColor, UDim2.fromOffset(180, 58), onClick, { pos = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "Action" })
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
-- toasts: small notes at the top, and the dark "locked" toast at the bottom (one at a time)
-------------------------------------------------------------------------------------------------------------
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.BackgroundTransparency = 1
toastHolder.Size = UDim2.fromOffset(720, 200)
toastHolder.Position = UDim2.new(0.5, 0, 0, 120)
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.ZIndex = 50
toastHolder.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastHolder

local function fadeOut(root: Instance, after: number)
	task.delay(after, function()
		if not root.Parent then
			return
		end
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
		end
		if root:IsA("Frame") then
			TweenService:Create(root, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
		task.wait(0.4)
		root:Destroy()
	end)
end

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
	local t = UI.text(toastHolder, text, UDim2.fromOffset(700, 38), { color = color, stroke = 3 })
	t.ZIndex = 50
	bounce(t)
	fadeOut(t, 3)
end

local currentNotice: Frame? = nil
-- Dark rounded notice at the bottom centre with an icon, an orange title and a white line under it.
function UI.notice(title: string, sub: string?, icon: string?)
	if currentNotice then
		currentNotice:Destroy()
	end
	local f = UI.frame({ size = UDim2.fromOffset(470, if sub then 78 else 54), pos = UDim2.new(0.5, 0, 1, -118), anchor = Vector2.new(0.5, 1), color = Color3.fromRGB(32, 28, 26), parent = gui, radius = 10, outline = 2, name = "Notice" })
	f.BackgroundTransparency = 0.12
	;(f:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(80, 70, 60)
	f.ZIndex = 45
	currentNotice = f
	local x = 16
	if icon then
		UI.icon(f, icon, 34, UDim2.fromOffset(14, if sub then 8 else 10)).ZIndex = 46
		x = 56
	end
	local t = UI.text(f, title, UDim2.new(1, -x - 14, 0, 32), { pos = UDim2.fromOffset(x, 6), align = Enum.TextXAlignment.Center, color = Color3.fromRGB(255, 170, 50), stroke = 2 })
	t.ZIndex = 46
	if sub then
		local s = UI.text(f, sub, UDim2.new(1, -28, 0, 26), { pos = UDim2.fromOffset(14, 44), color = Color3.new(1, 1, 1), stroke = 1.5 })
		s.ZIndex = 46
	end
	bounce(f)
	fadeOut(f, 2.6)
end

return UI
