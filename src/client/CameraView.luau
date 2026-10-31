-- Camera: runs start in first person like Chop A Forest. In the camps (area 1's camp and every area's camp) the
-- camera is free: walking in swings it out to third person, V (or the mouse wheel) switches, Shift toggles shift
-- lock. Out in the areas it's first person only. The lobby is always third person.
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Device = require(script.Parent.Device)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Potato = require(script.Parent.Potato)
local Canopy = require(script.Parent.Canopy) -- (30 Oct) your eye ducks under low grass tufts (the clump flicker fix)

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
	hint.Visible = run and not Device.touch
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
local bobPhase = 0
local landDip = 0
local fovNow = FOV_LOBBY
local rollNow = 0

-- How much of the kicks and shakes to show: Settings "Reduce camera shake" (the CalmCamera attribute, client/Settings)
-- and Potato Mode turn them down.
local KICK = Config.CAMERA_KICK
local function shakeScale(): number
	local k = 1
	if player:GetAttribute("CalmCamera") == true then
		k *= KICK.reduced
	end
	if Potato.on then
		k *= KICK.potato
	end
	return k
end

-- A quick zoom-in punch of `amount` degrees that springs back (the big moments: a clump falling, a boss hit, an
-- area cleared). Potato Mode has none; "Reduce camera shake" makes them smaller.
function CameraView.kick(amount: number)
	if Potato.on then
		return
	end
	if player:GetAttribute("CalmCamera") == true then
		amount *= KICK.reduced
	end
	kickAmount = math.max(kickAmount, amount)
end

-------------------------------------------------------------------------------------------------------------
-- the camera kick (the report "Making Mow A Lawn feel as satisfying as Chop A Forest", 28 Oct: "the screen moves
-- when you swing"; tuning in Config.CAMERA_KICK). Both kinds only tilt the view (pitch and roll) and nudge it a
-- hair, so they never fight your own turning:
--   * jolt(pitch, roll): a hit. The view dips and rolls on the impact frame and springs back in about 0.15 s with
--     a little overshoot. Worked out from the time since the hit, so a slow frame never stacks it up.
--   * trauma(amount): the bigger moments. Trauma (0..1) drains at KICK.decay per second; the shake you see is
--     trauma squared on smooth noise, so a small one is a shiver, a big one is strong, and nothing snaps
--     (Eiserloh, "Juicing Your Cameras With Math", GDC 2016). shake(power, time) is the old call, kept for the
--     boss and gate shakes: power 10 = trauma 1, held for `time`.
-- Roblox's camera starts every frame from the angle it ended on, so a tilt left in the camera would slowly drag
-- your aim: the tilt is put on after the camera updates and taken back off just before its next update.
-------------------------------------------------------------------------------------------------------------
type Jolt = { at: number, pitch: number, roll: number }
local jolts: { Jolt } = {}
local JOLT_LIFE = 0.22
local trauma = 0
local holdUntil, holdLevel = 0, 0
local noiseT = 0

-- 0 at the hit, full at ~0.035 s, back through zero at ~0.105 s, a small overshoot, gone by ~0.2 s
local function joltShape(u: number): number
	return math.exp(-u * 18) * math.sin(u * 30) / 0.462
end

function CameraView.jolt(pitch: number, roll: number?)
	local k = shakeScale()
	if k <= 0 then
		return
	end
	if #jolts >= 4 then
		table.remove(jolts, 1)
	end
	table.insert(jolts, { at = os.clock(), pitch = math.rad(pitch * k), roll = math.rad((roll or 0) * k) })
end

function CameraView.trauma(amount: number)
	trauma = math.min(1, trauma + amount * shakeScale())
end

-- A big moment (a clump you chopped falling, a find, an area at 100%): a bigger jolt than a hit (2.4 x `amount`
-- degrees, so 0.5 dips 1.2 deg) plus a rumble of `amount` trauma. (A rumble alone is short and soft at these
-- levels: play-tested, trauma 0.45 showed ~0.2 deg, less than a normal hit.)
function CameraView.impact(amount: number)
	CameraView.jolt(amount * 2.4, 0)
	CameraView.trauma(amount)
end

-- Shake the view with `power` (about 1 = light, 10 = huge) for `time` seconds.
function CameraView.shake(power: number, time: number)
	local level = math.sqrt(math.clamp(power / 10, 0, 1)) * shakeScale()
	trauma = math.max(trauma, level)
	if time > 0.25 then
		-- a long rumble (a gate sinking) holds its level, then drains
		local now = os.clock()
		if now >= holdUntil then
			holdLevel = 0
		end
		holdUntil = math.max(holdUntil, now + time - 0.25)
		holdLevel = math.max(holdLevel, level)
	end
end

-- A short buzz on phones and gamepads that can (only the big moments: never on a normal hit). Quietly does nothing
-- where Roblox can't vibrate.
function CameraView.buzz(strength: number, time: number)
	if Potato.on then
		return
	end
	for _, input in { Enum.UserInputType.Gamepad1, Enum.UserInputType.Touch } do
		pcall(function()
			if HapticService:IsVibrationSupported(input) and HapticService:IsMotorSupported(input, Enum.VibrationMotor.Large) then
				HapticService:SetMotor(input, Enum.VibrationMotor.Large, strength)
				task.delay(time, function()
					pcall(HapticService.SetMotor, HapticService, input, Enum.VibrationMotor.Large, 0)
				end)
			end
		end)
	end
end

-- This frame's tilt and nudge (identity when there's nothing to show). dt drains the trauma.
local function shakeNow(dt: number): CFrame?
	local now = os.clock()
	if now < holdUntil then
		trauma = math.max(trauma, holdLevel)
	end
	trauma = math.max(0, trauma - KICK.decay * dt)
	local pitch, roll = 0, 0
	for i = #jolts, 1, -1 do
		local j = jolts[i]
		local u = now - j.at
		if u > JOLT_LIFE then
			table.remove(jolts, i)
		else
			local s = joltShape(u)
			pitch -= j.pitch * s -- dips toward the grass
			roll += j.roll * s
		end
	end
	local cap = math.rad(2)
	pitch, roll = math.clamp(pitch, -cap, cap), math.clamp(roll, -cap, cap)
	local x, y = 0, 0
	if trauma > 0 then
		noiseT += dt * 25
		local s = trauma * trauma
		local a = math.rad(KICK.maxAngle) * s
		local function n(seed: number): number
			return math.clamp(math.noise(noiseT, seed) * 2, -1, 1)
		end
		pitch += n(0.1) * a
		roll += n(7.3) * a
		x = n(13.7) * KICK.maxOffset * s
		y = n(21.1) * KICK.maxOffset * s
	end
	if pitch == 0 and roll == 0 and x == 0 and y == 0 then
		return nil
	end
	return CFrame.new(x, y, 0) * CFrame.Angles(pitch, 0, roll)
end

local applied: CFrame? = nil -- the tilt put on the camera this frame, taken off before the next camera update
RunService:BindToRenderStep("MowALawnCameraUndo", Enum.RenderPriority.Camera.Value - 1, function()
	local cam = workspace.CurrentCamera
	if applied and cam and cam.CameraType == Enum.CameraType.Custom then
		cam.CFrame = cam.CFrame * applied:Inverse()
	end
	applied = nil
end)

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
	local shake = shakeNow(dt) -- (worked out every frame, so a shake also drains during a cutscene)
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

	-- offset: head bob (first person, walking on the ground), landing dip
	local walk = if first and onGround and not hum.SeatPart then math.clamp(speed / 16, 0, 1.3) else 0
	if walk > 0.05 then
		bobPhase += dt * (5.5 + speed * 0.3)
	end
	local bobX = math.sin(bobPhase) * 0.02 * walk
	local bobY = math.cos(bobPhase * 2) * 0.03 * walk
	landDip *= math.exp(-dt * 9)
	-- (the old shake jumped the camera to a new random spot every frame: the jitter that made hits feel rough;
	-- shakes are the smooth tilt below now)
	-- (30 Oct) minus how far client/Canopy ducks your eye under a low grass tuft (else it sat inside the tuft: flicker)
	hum.CameraOffset = Vector3.new(bobX, bobY - landDip - Canopy.dip(), 0)

	-- a slight lean into strafes and with the steps (first person only)
	local lateral = flat:Dot(cam.CFrame.RightVector)
	local targetRoll = 0 -- no lean: a steady view like Chop A Forest's
	local _ = lateral
	rollNow += (targetRoll - rollNow) * math.min(1, dt * 8)
	if math.abs(rollNow) > 1e-4 then
		cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, rollNow)
	end

	-- the camera kick and shake (taken off again by MowALawnCameraUndo before the next camera update)
	if shake then
		cam.CFrame = cam.CFrame * shake
		applied = shake
	end
end)

return CameraView
