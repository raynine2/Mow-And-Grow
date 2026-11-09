--!strict
-- (9 Nov, owner: "I DONT SEE THE AURAS WHEN CLICKING THE CLASSES") your own class aura is drawn (ClassFXController /
-- client/Auras), but in first person it's hidden on purpose, and a run pins you to first person outside the camps:
-- so picking a class showed nothing. Now, when your class changes and the camera is close to your head, the camera
-- swings out and circles you once (about 2.6 s) so you see the new aura, then hands the camera back. Nothing else
-- changes: the auras themselves are untouched.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local LENGTH = 2.6
local spawnedAt = os.clock()
local busy = false

player.CharacterAdded:Connect(function()
	spawnedAt = os.clock()
end)

local function show()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if busy or not root or not head then
		return
	end
	camera = workspace.CurrentCamera
	-- only from your own normal camera, close in (first person); cutscenes and the boss camera are left alone
	if camera.CameraType ~= Enum.CameraType.Custom or (camera.CFrame.Position - head.Position).Magnitude > 2.5 then
		return
	end
	busy = true
	local back = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local a0 = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / LENGTH
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if t >= 1 or not r then
			conn:Disconnect()
			camera.CameraType = back
			busy = false
			return
		end
		local ease = 1 - (1 - math.min(1, t * 3)) ^ 2 -- swing out quickly, then circle
		local a = a0 + math.pi + t * math.pi * 1.4
		local dist = 3 + 7 * ease
		local at = r.Position + Vector3.new(0, 1, 0)
		camera.CFrame = CFrame.lookAt(at + Vector3.new(math.sin(a) * dist, 1.5 + 1.5 * ease, math.cos(a) * dist), at)
	end)
end

player:GetAttributeChangedSignal("Class"):Connect(function()
	-- (the attribute is also set when you join or respawn: only a real switch shows off)
	if os.clock() - spawnedAt > 4 then
		task.delay(0.3, show)
	end
end)
