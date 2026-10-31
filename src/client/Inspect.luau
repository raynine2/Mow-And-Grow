-- (owner, 29 Oct: "make an inspect animation for every weapon ... make the Keybind for it now "Y" on pc and a small
-- button on mobile ... make it so you can spam the animation") Inspect whatever you're holding, in first person:
--   * Y on a keyboard (L3, pressing the left stick in, on a gamepad); on a phone the eye button just above the jump
--     button, shown only while you hold something in first person
--   * pressing it again restarts the inspect at once (CS2 style); a swing or shot, switching item or getting on a
--     mower cancels it (client/ViewAnims and client/ViewModel do the cutting short); walking is fine
-- The animations are code keyframes in client/ViewAnims (Inspect* clips), nothing uploaded.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local ViewAnims = require(script.Parent.ViewAnims)
local State = require(script.Parent.State)
local Skin = require(script.Parent.Skin)
local Sound = require(script.Parent.Sound)

local Inspect = {}
local player = Players.LocalPlayer

local function held(): (Tool?, Humanoid?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool, hum
end

local function firstPerson(): boolean
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local cam = workspace.CurrentCamera
	return head ~= nil and cam ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 2
end

-- (30 Oct) the Mega Scythe's inspect plays in third person too (client/RiderPose puts it on your character)
local THIRD_PERSON = { MegaScythe = true }
local function canInspect(): boolean
	local tool, hum = held()
	return tool ~= nil
		and hum ~= nil
		and hum.Health > 0
		and hum.SeatPart == nil
		and (firstPerson() or THIRD_PERSON[tool:GetAttribute("ToolId") :: string] == true)
end

local remote: RemoteEvent? = nil
function Inspect.play(force: string?)
	if not canInspect() then
		return
	end
	local tool = held()
	local name, rare = ViewAnims.inspect((tool :: Tool):GetAttribute("ToolId") :: string?, force)
	if name then
		Sound.play("whoosh", 0.05, 0.25) -- a soft swish as it comes up
		if rare then
			Sound.play("rareChime", 0.05, 0.5) -- (30 Oct) a rare one (1 in 25)
		end
		-- everyone else sees it on your character (server/Main passes it on)
		remote = remote or game:GetService("ReplicatedStorage"):FindFirstChild("MowALawnRemotes") and game:GetService("ReplicatedStorage").MowALawnRemotes:FindFirstChild("Inspect") :: RemoteEvent?
		if remote then
			remote:FireServer(name)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Y or input.KeyCode == Enum.KeyCode.ButtonL3 then
		Inspect.play()
	end
end)

-- a swing or a shot cuts it short (keyframed swings already do; this catches the rest: guns, the auto tools' clicks)
local hooked: { [Tool]: boolean } = {}
local function hookTool(t: Instance)
	if t:IsA("Tool") and not hooked[t] then
		hooked[t] = true
		t.Activated:Connect(function()
			ViewAnims.cancelInspect()
		end)
		t.Destroying:Connect(function()
			hooked[t] = nil
		end)
	end
end
local function onCharacter(char: Model)
	for _, c in char:GetChildren() do
		hookTool(c)
	end
	char.ChildAdded:Connect(hookTool)
end
if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
State.on("swing", function()
	ViewAnims.cancelInspect()
end)

-------------------------------------------------------------------------------------------------------------
-- the phone button: a small wooden badge with an eye, just above Roblox's jump button
-------------------------------------------------------------------------------------------------------------
if UserInputService.TouchEnabled then
	local gui = Instance.new("ScreenGui")
	gui.Name = "InspectButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")

	local SIZE = 62
	local b = Instance.new("TextButton")
	b.Name = "Inspect"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(SIZE, SIZE)
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Visible = false
	b.Parent = gui
	local _, face = Skin.frame(b, "ui_badge", Vector2.new(SIZE, SIZE), { stretch = false, name = "Badge" })
	-- the eye: a white almond, an iris, a pupil and a glint
	local eye = Instance.new("Frame")
	eye.Name = "Eye"
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.Position = UDim2.fromScale(0.5, 0.5)
	eye.Size = UDim2.fromScale(0.62, 0.4)
	eye.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	eye.ZIndex = 3
	eye.Parent = face
	local ec = Instance.new("UICorner")
	ec.CornerRadius = UDim.new(1, 0)
	ec.Parent = eye
	local es = Instance.new("UIStroke")
	es.Color = Color3.fromRGB(58, 34, 16)
	es.Thickness = 2.5
	es.Parent = eye
	local function dot(parent: GuiObject, scale: number, color: Color3, pos: UDim2?): Frame
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = pos or UDim2.fromScale(0.5, 0.5)
		d.Size = UDim2.fromScale(scale, scale)
		d.SizeConstraint = Enum.SizeConstraint.RelativeYY
		d.BackgroundColor3 = color
		d.ZIndex = 4
		d.Parent = parent
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = d
		return d
	end
	local iris = dot(eye, 0.86, Color3.fromRGB(70, 160, 80))
	dot(iris, 0.5, Color3.fromRGB(25, 20, 18))
	dot(iris, 0.28, Color3.new(1, 1, 1), UDim2.fromScale(0.68, 0.32))
	Skin.press(b, face)
	b.Activated:Connect(function()
		Inspect.play()
	end)

	-- follow the jump button (it moves with the screen size and orientation); show only when an inspect can play
	local function jumpButton(): GuiObject?
		local tg = player.PlayerGui:FindFirstChild("TouchGui")
		local frame = tg and tg:FindFirstChild("TouchControlFrame")
		local jb = frame and frame:FindFirstChild("JumpButton")
		return if jb and jb:IsA("GuiObject") then jb else nil
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local jb = jumpButton()
		local show = jb ~= nil and jb.Visible and canInspect()
		b.Visible = show
		if show and jb then
			local tg = jb:FindFirstAncestorOfClass("ScreenGui")
			local inset = if tg and not tg.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
			local top = jb.AbsolutePosition + inset
			b.Position = UDim2.fromOffset(top.X + jb.AbsoluteSize.X / 2, top.Y - 6)
		end
	end)
end

return Inspect
