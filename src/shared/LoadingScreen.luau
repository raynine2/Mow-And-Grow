-- The loading screen (like Chop A Forest's): the world dimmed behind it (or a deep green-to-blue sky while
-- there's nothing to show yet), a big white cartoon of a cut grass stump with a pair of garden shears chopping
-- at it, your avatar's face in a white ring with your name, and "Loading.." with ticking dots.
-- Built from UI shapes only (no uploaded images), so it works before anything else has loaded: the boot script
-- in ReplicatedFirst uses it on arrival, client/Loading uses it before a teleport.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LoadingScreen = {}

local WHITE = Color3.fromRGB(250, 250, 252)
local INK = Color3.fromRGB(34, 36, 46)
local RING = Color3.fromRGB(200, 204, 214)
local FONT = Enum.Font.FredokaOne

local function box(parent: Instance, size: UDim2, pos: UDim2, color: Color3, radius: number?, stroke: number?, rot: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = if radius >= 1 then UDim.new(0, radius) else UDim.new(radius, 0)
		c.Parent = f
	end
	if stroke and stroke > 0 then
		local s = Instance.new("UIStroke")
		s.Thickness = stroke
		s.Color = INK
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
	end
	f.Parent = parent
	return f
end

local function ring(parent: Instance, size: UDim2, pos: UDim2, color: Color3, thickness: number): Frame
	local f = box(parent, size, pos, color, 0.5)
	f.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.Parent = f
	return f
end

local function text(parent: Instance, t: string, size: UDim2, pos: UDim2, stroke: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = t
	l.TextScaled = true
	l.TextColor3 = WHITE
	local s = Instance.new("UIStroke")
	s.Thickness = stroke
	s.Color = INK
	s.Transparency = 0.25
	s.Parent = l
	l.Parent = parent
	return l
end

-- The cut grass stump: a white trunk with root feet, a ring-marked cut top with a few short blades still
-- standing on it, and little motion ticks over it.
local function stump(parent: Instance)
	for side = -1, 1, 2 do
		box(parent, UDim2.fromScale(0.2, 0.13), UDim2.fromScale(0.5 + side * 0.27, 0.86), WHITE, 0.4, 5, side * 25)
	end
	box(parent, UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.5, 0.64), WHITE, 0.18, 6)
	-- bark lines
	for _, x in { 0.36, 0.5, 0.63 } do
		box(parent, UDim2.fromScale(0.018, 0.22), UDim2.fromScale(x, 0.7), RING, 0.5)
	end
	-- the cut top and its rings
	local top = box(parent, UDim2.fromScale(0.68, 0.24), UDim2.fromScale(0.5, 0.4), WHITE, 0.5, 6)
	ring(top, UDim2.fromScale(0.66, 0.6), UDim2.fromScale(0.5, 0.5), RING, 3)
	ring(top, UDim2.fromScale(0.34, 0.3), UDim2.fromScale(0.5, 0.5), RING, 3)
	-- short cut blades poking up at the edge of the top
	for i, x in { 0.27, 0.36, 0.66, 0.74 } do
		box(parent, UDim2.fromScale(0.035, 0.1), UDim2.fromScale(x, 0.31 - (i % 2) * 0.02), WHITE, 0.5, 4, (x - 0.5) * 50)
	end
	-- motion ticks
	for i, a in { -30, 0, 30 } do
		box(parent, UDim2.fromScale(0.025, 0.08), UDim2.fromScale(0.4 + (i - 1) * 0.1, 0.18 + math.abs(a) / 400), WHITE, 0.5, 0, a)
	end
end

-- Garden shears, standing up beside the stump: two crossed blades and two ring handles.
local function shears(parent: Instance): Frame
	local pivot = box(parent, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.5, 0.5), WHITE)
	pivot.BackgroundTransparency = 1
	for side = -1, 1, 2 do
		local arm = box(pivot, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.5, 0.5), WHITE)
		arm.BackgroundTransparency = 1
		arm.Rotation = side * 9
		box(arm, UDim2.fromScale(0.2, 0.5), UDim2.fromScale(0.5, 0.28), WHITE, 0.5, 5) -- blade
		box(arm, UDim2.fromScale(0.08, 0.3), UDim2.fromScale(0.5, 0.62), WHITE, 0.5, 4) -- handle bar
		local grip = box(arm, UDim2.fromScale(0.42, 0.18), UDim2.fromScale(0.5 + side * 0.12, 0.84), WHITE, 0.5, 5)
		box(grip, UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.5, 0.5), INK, 0.5).BackgroundTransparency = 0.85
	end
	box(pivot, UDim2.fromScale(0.12, 0.06), UDim2.fromScale(0.5, 0.52), RING, 0.5, 4) -- the bolt
	return pivot
end

export type Screen = { gui: ScreenGui, group: CanvasGroup, bg: Frame }

-- Build the screen for `player` (not parented). The dots tick and the shears chop until it's destroyed.
function LoadingScreen.build(player: Player?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "MowALawnLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local group = Instance.new("CanvasGroup")
	group.Name = "Group"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Parent = gui
	local bg = Instance.new("Frame")
	bg.Name = "Backdrop"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(46, 74, 104), Color3.fromRGB(30, 62, 44))
	grad.Rotation = 90
	grad.Parent = bg
	bg.Parent = group
	-- the picture
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.42)
	art.Size = UDim2.fromScale(0.34, 0.34)
	art.SizeConstraint = Enum.SizeConstraint.RelativeYY
	art.BackgroundTransparency = 1
	art.Parent = group
	local stumpFrame = box(art, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.36, 0.6), WHITE)
	stumpFrame.BackgroundTransparency = 1
	stump(stumpFrame)
	local shearHolder = box(art, UDim2.fromScale(0.36, 0.78), UDim2.fromScale(0.78, 0.4), WHITE)
	shearHolder.BackgroundTransparency = 1
	local tool = shears(shearHolder)
	-- the player
	local face = box(group, UDim2.fromScale(0.085, 0.085), UDim2.fromScale(0.5, 0.78), WHITE, 0.5)
	face.SizeConstraint = Enum.SizeConstraint.RelativeYY
	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.AnchorPoint = Vector2.new(0.5, 0.5)
	photo.Position = UDim2.fromScale(0.5, 0.5)
	photo.Size = UDim2.fromScale(0.88, 0.88)
	photo.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
	photo.Parent = face
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = photo
	text(group, if player then player.DisplayName else "", UDim2.fromScale(0.3, 0.03), UDim2.fromScale(0.5, 0.85), 1.5)
	local loading = text(group, "Loading..", UDim2.fromScale(0.4, 0.055), UDim2.fromScale(0.5, 0.92), 2)
	if player then
		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and photo.Parent then
				photo.Image = img
			end
		end)
	end
	-- animation: the shears snip and bob, the dots tick
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not gui.Parent and os.clock() - start > 5 then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		tool.Rotation = 8 * math.sin(t * 5)
		shearHolder.Position = UDim2.fromScale(0.78, 0.4 + 0.015 * math.sin(t * 2.5))
		loading.Text = "Loading" .. string.rep(".", 1 + math.floor(t * 2.5) % 3)
	end)
	gui.Destroying:Connect(function()
		conn:Disconnect()
	end)
	return gui
end

-- Let the world show through, dimmed (call once the world exists behind it).
function LoadingScreen.dim(gui: ScreenGui, alpha: number?)
	local bg = gui:FindFirstChild("Backdrop", true) :: Frame?
	if bg then
		TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = alpha or 0.35, BackgroundColor3 = Color3.fromRGB(10, 14, 20) }):Play()
		local grad = bg:FindFirstChildOfClass("UIGradient")
		if grad then
			grad.Enabled = false
		end
	end
end

-- Fade it all out, then destroy it.
function LoadingScreen.fadeOut(gui: ScreenGui, time: number?)
	local group = gui:FindFirstChild("Group") :: CanvasGroup?
	if not group then
		gui:Destroy()
		return
	end
	local t = TweenService:Create(group, TweenInfo.new(time or 0.6, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
	t:Play()
	t.Completed:Connect(function()
		gui:Destroy()
	end)
end

return LoadingScreen
