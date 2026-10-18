-- Camera: runs start in first person like Chop A Forest, but you're never stuck there. Press V (or scroll the
-- mouse wheel out) for third person with a free mouse; Shift toggles shift lock there; V again (or scrolling
-- all the way in) goes back to first person. The lobby is always third person.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local CameraView = {}
local player = Players.LocalPlayer

local FIRST = 0.5
local THIRD = 14
local MAX_ZOOM = 30

-- Pin the camera at distance `d` for a moment, then free the range again so the scroll wheel still works.
local function zoomTo(d: number)
	player.CameraMinZoomDistance = d
	player.CameraMaxZoomDistance = d
	task.delay(0.15, function()
		player.CameraMinZoomDistance = FIRST
		player.CameraMaxZoomDistance = MAX_ZOOM
	end)
end

local function inFirstPerson(): boolean
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local cam = workspace.CurrentCamera
	return head ~= nil and cam ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.5
end

local hint = UI.text(UI.gui, "", UDim2.fromOffset(240, 26), {
	pos = UDim2.new(1, -16, 1, -14),
	anchor = Vector2.new(1, 1),
	align = Enum.TextXAlignment.Right,
	name = "CameraHint",
	stroke = 2,
})
hint.Visible = false

local wasRun = false
local function onMode()
	local run = State.isRun()
	hint.Visible = run and not UserInputService.TouchEnabled
	if run and not wasRun then
		-- entering a run: first person, like the video
		player.CameraMode = Enum.CameraMode.Classic
		zoomTo(FIRST)
	elseif not run and wasRun then
		player.CameraMinZoomDistance = FIRST
		player.CameraMaxZoomDistance = 128
		zoomTo(THIRD)
	end
	wasRun = run
end
State.on("data", onMode)
State.on("world", onMode)
player.CharacterAdded:Connect(function()
	if State.isRun() then
		task.wait(0.3)
		zoomTo(FIRST)
	end
end)

function CameraView.toggle()
	if not State.isRun() then
		return
	end
	zoomTo(if inFirstPerson() then THIRD else FIRST)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		CameraView.toggle()
	end
end)

RunService.RenderStepped:Connect(function()
	if hint.Visible then
		hint.Text = if inFirstPerson() then "[V] Free mouse" else "[V] First person   [Shift] Shift lock"
	end
end)

return CameraView
