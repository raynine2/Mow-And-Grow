-- Camera: runs start in first person like Chop A Forest. In the camps (area 1's camp and every area's camp) the
-- camera is free: walking in swings it out to third person, V (or the mouse wheel) switches, Shift toggles shift
-- lock. Out in the areas it's first person only. The lobby is always third person.
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

-- Outside the camps (the camp in area 1 and every area's camp, server/Outposts) a run is first person only
-- (owner, 27 Oct: "if you walk out of the hubs in the zones you get forced in first person", like Chop A Forest):
-- `locked` pins the zoom at first person there. Driving a mower stays free.
local locked = false

-- Pin the camera at distance `d` for a moment, then free the range again so the scroll wheel still works.
local function zoomTo(d: number)
	player.CameraMinZoomDistance = d
	player.CameraMaxZoomDistance = d
	task.delay(0.15, function()
		player.CameraMinZoomDistance = FIRST
		player.CameraMaxZoomDistance = if locked then FIRST else MAX_ZOOM
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

-- A free mouse in first person (owner, 27 Oct: "when I'm first person the free mouse doesn't work, the mouse is
-- stuck"): outside the camps V frees the cursor (and locks it again) while you stay in first person, and any open
-- window frees it too, so its buttons can be clicked. Roblox's own way: a visible Modal button unlocks the mouse.
local mouseFree = false
local modalGui = Instance.new("ScreenGui")
modalGui.Name = "MowFreeMouse"
modalGui.ResetOnSpawn = false
modalGui.Parent = player:WaitForChild("PlayerGui")
local modal = Instance.new("TextButton")
modal.Name = "Modal"
modal.Text = ""
modal.BackgroundTransparency = 1
modal.Size = UDim2.fromOffset(1, 1)
modal.Modal = true
modal.Visible = false
modal.Parent = modalGui
-- (and, to be sure, the cursor is set free every frame right after Roblox's camera locks it in first person)
local wantFree = false
RunService:BindToRenderStep("MowFreeMouse", Enum.RenderPriority.Camera.Value + 5, function()
	if wantFree then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

function CameraView.toggle()
	if not State.isRun() then
		return
	end
	hintUntil = math.max(hintUntil, os.clock() + 4)
	if locked then
		mouseFree = not mouseFree -- outside the camps: first person stays, V frees / locks the mouse
		return
	end
	zoomTo(if inFirstPerson() then THIRD else FIRST)
end

-- The camps: { centre, radius } from the World's attributes (CampCenter / CampRadius, Hub<z> / HubR<z>).
local hubList: { { c: Vector3, r: number } } = {}
local hubsAt = -10
local function hubs(): { { c: Vector3, r: number } }
	if os.clock() - hubsAt < 3 then
		return hubList
	end
	hubsAt = os.clock()
	table.clear(hubList)
	local w = workspace:FindFirstChild("World")
	if not w then
		return hubList
	end
	local camp, campR = w:GetAttribute("CampCenter"), w:GetAttribute("CampRadius")
	if typeof(camp) == "Vector3" and type(campR) == "number" then
		table.insert(hubList, { c = camp, r = campR })
	end
	for z = 1, 12 do
		local c, r = w:GetAttribute("Hub" .. z), w:GetAttribute("HubR" .. z)
		if typeof(c) == "Vector3" and type(r) == "number" then
			table.insert(hubList, { c = c, r = r })
		end
	end
	return hubList
end

local function inHub(pos: Vector3): boolean
	for _, h in hubs() do
		if Vector2.new(pos.X - h.c.X, pos.Z - h.c.Z).Magnitude < h.r + 2 then
			return true
		end
	end
	return false
end

-- Every few frames: lock to first person outside the camps, free (and out to third person) on walking into one.
local wasInside: boolean? = nil
task.spawn(function()
	while true do
		task.wait(0.2)
		local cam = workspace.CurrentCamera
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not State.isRun() or not cam or cam.CameraType ~= Enum.CameraType.Custom or not root or not hum then
			if locked and not State.isRun() then
				locked = false
				player.CameraMaxZoomDistance = 128
			end
			wasInside = nil
			continue
		end
		local inside = inHub(root.Position)
		local free = inside or hum.SeatPart ~= nil
		if not free and not locked then
			locked = true
			player.CameraMinZoomDistance = FIRST
			player.CameraMaxZoomDistance = FIRST
			if wasInside then
				hintUntil = os.clock() + 5 -- walked out of a camp: "[V] Free mouse" for a moment
			end
		elseif free and locked then
			locked = false
			mouseFree = false
			player.CameraMinZoomDistance = FIRST
			player.CameraMaxZoomDistance = MAX_ZOOM
		end
		if inside and wasInside == false then
			zoomTo(THIRD) -- walked into a camp: out to third person, like Chop A Forest's camps
			hintUntil = os.clock() + 4
		end
		wasInside = inside
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		CameraView.toggle()
	end
end)

RunService.RenderStepped:Connect(function()
	-- the mouse is free in first person while you asked for it (V) or a window is open
	local want = State.isRun() and inFirstPerson() and (mouseFree or UI.anyOpen())
	wantFree = want
	if modal.Visible ~= want then
		modal.Visible = want
	end
	if hint.Visible then
		hint.Text = if locked then (if mouseFree then "[V] Lock the mouse" else "[V] Free mouse") elseif inFirstPerson() then "[V] Third person" else "[V] First person   [Shift] Shift lock"
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
	-- (only past a run: walking and stopping no longer make the view breathe in and out)
	local target = base + SPEED_FOV * math.clamp((speed - 22) / 30, 0, 1)
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
