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
-- the hint shows for a while at the start of a run and after pressing V, then fades (it was on screen all the
-- time; owner, 27 Oct: "the game feels cluttered")
local hintUntil = 0
local HINT_TIME = 15

local wasRun = false
local function onMode()
	local run = State.isRun()
	hint.Visible = run and not UserInputService.TouchEnabled
	if run and not wasRun then
		hintUntil = os.clock() + HINT_TIME
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
	hintUntil = math.max(hintUntil, os.clock() + 4)
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
		local left = hintUntil - os.clock()
		local a = math.clamp(1 - left, 0, 1) -- fades over the last second
		hint.TextTransparency = a
		local stroke = hint:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = a
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- camera feel: the one owner of the field of view and the camera offset
--   - a wide view (80 everywhere) that opens up a little more
--     the faster you go (sprinting, mowers);
--   - first person: a very light head bob while walking and a small dip when you land; no lean (Chop A Forest's
--     view stays steady and leaves the motion to the arms and the effects);
--   - kicks (hits) and shakes (slams, gates) are asked for here, never written straight to the camera.
-------------------------------------------------------------------------------------------------------------
-- owner, 27 Oct: "increase the FOV". 80 everywhere (was 70/70/72: the view felt cramped and the fists filled the
-- screen); cutscenes still set their own and hand back to this
local FOV_LOBBY, FOV_FIRST, FOV_THIRD = 80, 80, 80
local SPEED_FOV = 5 -- extra degrees at full speed
local kickAmount = 0
local shakeUntil, shakePower = 0, 0
local bobPhase = 0
local landDip = 0
local fovNow = FOV_LOBBY
local rollNow = 0

-- A quick zoom-in punch of `amount` degrees that springs back (hits, slams, boss death).
function CameraView.kick(amount: number)
	kickAmount = math.max(kickAmount, amount)
end

-- A slow push-in of `amount` degrees: eases in over `inTime`, holds `hold` seconds, eases back out over
-- `outTime` (a rare reveal's slow-motion beat). A newer focus replaces an older one.
local focusAmount, focusStart, focusIn, focusHold, focusOut = 0, -10, 0.1, 0, 0.1
function CameraView.focus(amount: number, inTime: number, hold: number, outTime: number)
	focusAmount, focusStart, focusIn, focusHold, focusOut = amount, os.clock(), inTime, hold, outTime
end
local function focusNow(): number
	local t = os.clock() - focusStart
	if t < 0 or t > focusIn + focusHold + focusOut then
		return 0
	end
	local k
	if t < focusIn then
		k = t / focusIn
	elseif t < focusIn + focusHold then
		k = 1
	else
		k = 1 - (t - focusIn - focusHold) / focusOut
	end
	return focusAmount * k * k * (3 - 2 * k)
end

-- Shake the view with `power` (about 1 = light, 6 = huge) for `time` seconds.
function CameraView.shake(power: number, time: number)
	shakeUntil = math.max(shakeUntil, os.clock() + time)
	shakePower = math.max(shakePower, power)
end

local function hookLanding(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local fallSpeed = 0
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			fallSpeed = 0
		elseif new == Enum.HumanoidStateType.Landed then
			landDip = math.clamp(fallSpeed / 160, 0.04, 0.3)
		end
	end)
	local conn = RunService.Heartbeat:Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and hum:GetState() == Enum.HumanoidStateType.Freefall then
			fallSpeed = math.max(fallSpeed, -root.AssemblyLinearVelocity.Y)
		end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			conn:Disconnect()
		end
	end)
end
player.CharacterAdded:Connect(hookLanding)
if player.Character then
	task.spawn(hookLanding, player.Character)
end

RunService:BindToRenderStep("MowALawnCameraFeel", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or cam.CameraType ~= Enum.CameraType.Custom or not hum or not root then
		return -- cutscenes (boss intro) drive the camera themselves
	end
	local vel = root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local speed = flat.Magnitude
	local first = inFirstPerson()
	local onGround = hum.FloorMaterial ~= Enum.Material.Air

	-- field of view: eased toward the mode's base plus a speed boost; kicks bite instantly and spring back
	local base = if not State.isRun() then FOV_LOBBY elseif first then FOV_FIRST else FOV_THIRD
	local target = base + SPEED_FOV * math.clamp((speed - 8) / 30, 0, 1)
	fovNow += (target - fovNow) * math.min(1, dt * 6)
	kickAmount *= math.exp(-dt * 11)
	cam.FieldOfView = fovNow - kickAmount - focusNow()

	-- offset: head bob (first person, walking on the ground), landing dip, shake
	local walk = if first and onGround and not hum.SeatPart then math.clamp(speed / 16, 0, 1.3) else 0
	if walk > 0.05 then
		bobPhase += dt * (5.5 + speed * 0.3)
	end
	local bobX = math.sin(bobPhase) * 0.02 * walk
	local bobY = math.cos(bobPhase * 2) * 0.03 * walk
	landDip *= math.exp(-dt * 9)
	local sx, sy = 0, 0
	local left = shakeUntil - os.clock()
	if left > 0 then
		local p = shakePower * math.min(1, left * 3) * 0.12
		sx, sy = (math.random() - 0.5) * p, (math.random() - 0.5) * p
	else
		shakePower = 0
	end
	hum.CameraOffset = Vector3.new(bobX + sx, bobY - landDip + sy, 0)

	-- a slight lean into strafes and with the steps (first person only)
	local lateral = flat:Dot(cam.CFrame.RightVector)
	local targetRoll = 0 -- no lean: a steady view like Chop A Forest's
	local _ = lateral
	rollNow += (targetRoll - rollNow) * math.min(1, dt * 8)
	if math.abs(rollNow) > 1e-4 then
		cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, rollNow)
	end
end)

return CameraView
