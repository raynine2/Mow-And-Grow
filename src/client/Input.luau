-- Player input: swing tools (click or hold), open menus at stalls, Tab for upgrades, drive mowers.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Input = {}
local player = Players.LocalPlayer
local hoverVelocity: (Model, BasePart, Vector3, number, number) -> number

-------------------------------------------------------------------------------------------------------------
-- tools: hold to keep swinging
-------------------------------------------------------------------------------------------------------------
local holding = false
local lastSwing = 0

local function equippedSwingTool(): Tool?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Kind") == "swing" then
		return tool
	end
	return nil
end

local function toolCooldown(): number
	local tool = equippedSwingTool()
	local id = tool and tool:GetAttribute("ToolId")
	local mult = State.data and State.data.swing or 1 -- Swing Speed upgrades (the server checks the same)
	for _, def in Config.TOOLS do
		if def.id == id then
			return (def.cooldown or 0.4) * mult
		end
	end
	return 0.4 * mult
end

-- Where you're looking: the clump in the middle of the screen is the one you chop (like aiming an axe).
local function aim(): Vector3
	local cam = workspace.CurrentCamera
	return if cam then cam.CFrame.LookVector else Vector3.zAxis
end

local function swing()
	local now = os.clock()
	if now - lastSwing < toolCooldown() then
		return
	end
	lastSwing = now
	local look = aim()
	State.fire("Swing", look)
	State.emit("swing", look)
end

-- The Hold upgrade (first thing in the Hands section): until you own it, every swing is its own click.
local function canHold(): boolean
	local run = State.data and State.data.run
	return run ~= nil and run.upgrades ~= nil and (run.upgrades.hold or 0) >= 1
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("Kind") ~= "swing" or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		holding = true
		swing()
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	tool.Unequipped:Connect(function()
		holding = false
	end)
end

local function onCharacter(char: Model)
	holding = false
	char.ChildAdded:Connect(hookTool)
	for _, c in char:GetChildren() do
		hookTool(c)
	end
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

-- keep swinging while the button is held (server enforces the real cooldown)
task.spawn(function()
	while true do
		task.wait(0.1)
		if holding and equippedSwingTool() and canHold() then
			swing()
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- stall prompts open windows
-------------------------------------------------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local window = prompt:GetAttribute("Window")
	if type(window) == "string" then
		-- prompts can carry an item id (tool frames on the cabin wall, mower displays)
		State.emit("openFor", window, prompt:GetAttribute("Item"))
		UI.open(window)
	end
end)

-- close a window when you walk away from the stall that opened it (only then: a camera cut, like the class
-- room's, hides prompts for a moment while you're still standing there)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	local window = prompt:GetAttribute("Window")
	if type(window) == "string" and UI.isOpen(window) then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local part = prompt.Parent
		if root and part and part:IsA("BasePart") and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 1 then
			return
		end
		UI.close()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		UI.close()
	end
end)

-------------------------------------------------------------------------------------------------------------
-- driving: the server gives the driver physics ownership; we set the drive constraints each frame
-------------------------------------------------------------------------------------------------------------
local driving: Model? = nil
local yaw = 0
local speed = 0

local function currentMower(): (Model?, VehicleSeat?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") then
		local model = seat.Parent
		if model and model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
			return model, seat
		end
	end
	return nil, nil
end

-- the ground under a point: its height, or nil (water, a gorge, the edge of the world). Scenery (trees, flowers,
-- grass) can't be hit by rays, so only the ground, paths, bridges and buildings count.
local MAX_CLIMB = 4.5 -- a terrace step up to this high is driven over; anything taller is a wall
local KERB = 1.2 -- anything that isn't the ground itself (an arena hedge, a fence, a planter) is only climbed this high
local CLEAR = 0.35 -- studs between the chassis and the ground
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
-- The ray starts at `top` (just above the highest step the mower may climb), never high above the chassis: a roof,
-- a bridge or a branch overhead isn't ground (a ray from up high made a mower in the garage float up onto the roof).
local function groundY(at: Vector3, top: number, ignore: { Instance }): (number?, Instance?)
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(at.X, top, at.Z), Vector3.new(0, -40, 0), rayParams)
	return hit and hit.Position.Y, hit and hit.Instance
end

-- the map's own ground (terraces, terrain), as opposed to things standing on it
local function isGround(inst: Instance?): boolean
	if not inst then
		return false
	end
	if inst == workspace.Terrain then
		return true
	end
	local world = workspace:FindFirstChild("World")
	local ground = world and world:FindFirstChild("Ground")
	return ground ~= nil and inst:IsDescendantOf(ground)
end

-- the vertical speed that keeps the chassis floating CLEAR above the highest ground under and just ahead of it
hoverVelocity = function(model: Model, body: BasePart, dir: Vector3, speed: number, dt: number): number
	local ignore = { model, player.Character :: Instance }
	local pos = body.Position
	local half = body.Size.Y / 2
	local reach = body.Size.Z / 2 + 1.5 + math.abs(speed) * 0.18
	local fwd = dir * (if speed < 0 then -1 else 1)
	local side = Vector3.new(-fwd.Z, 0, fwd.X) * (body.Size.X / 2 - 0.4)
	local top = pos.Y - half + MAX_CLIMB + 0.5
	local here = groundY(pos, top, ignore)
	local best: number? = here
	for _, p in { pos + fwd * reach, pos + fwd * reach + side, pos + fwd * reach - side, pos + fwd * (reach * 0.5) } do
		local y, inst = groundY(p, top, ignore)
		-- a step we can climb lifts us early; a wall (or a cliff, or a hedge round an arena, owner test 27 Oct) is
		-- left to the collision to stop us
		if y and (not best or y > best) and y - (pos.Y - half) <= (if isGround(inst) then MAX_CLIMB else KERB) then
			best = y
		end
	end
	if not best then
		-- nothing below (a gorge, the sea): fall
		return math.max(-120, body.AssemblyLinearVelocity.Y - workspace.Gravity * dt)
	end
	local want = best + half + CLEAR
	local dy = want - pos.Y
	if dy < -1.5 then
		-- going down a step or off a ledge: fall naturally (a little softened), don't snap down
		return math.max(-80, math.min(body.AssemblyLinearVelocity.Y, 0) - workspace.Gravity * 0.7 * dt)
	end
	return math.clamp(dy * 14, -40, 45)
end

local lastFuel, lastMaxFuel = -1, -1
RunService.RenderStepped:Connect(function(dt)
	local model, seat = currentMower()
	if model ~= driving then
		driving = model
		lastFuel, lastMaxFuel = -1, -1
		State.emit("driving", model)
		if model and model.PrimaryPart then
			local look = model.PrimaryPart.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z)
			speed = 0
		end
	end
	if not model or not seat then
		return
	end
	local body = model.PrimaryPart
	if not body then
		return
	end
	local lv = body:FindFirstChild("Drive") :: LinearVelocity?
	local ao = body:FindFirstChild("Steer") :: AlignOrientation?
	if not lv or not ao then
		return
	end
	local fuel = model:GetAttribute("Fuel") or 0
	local maxFuel = model:GetAttribute("MaxFuel") or 0
	-- (only when it changes: an emit every frame rebuilt the fuel bar's text every frame)
	if fuel ~= lastFuel or maxFuel ~= lastMaxFuel then
		lastFuel, lastMaxFuel = fuel, maxFuel
		State.emit("fuel", fuel, maxFuel)
	end
	local top = model:GetAttribute("Speed") or 30
	local throttle = if fuel > 0 then seat.ThrottleFloat else 0
	local target = if throttle >= 0 then throttle * top else throttle * top * 0.5
	speed += (target - speed) * math.min(1, dt * 3)
	local turnRate = 2.2 * math.clamp(math.abs(speed) / 12, 0.35, 1)
	yaw -= seat.SteerFloat * turnRate * dt * (if speed < 0 then -1 else 1)
	local rot = CFrame.Angles(0, yaw, 0)
	local dir = rot.LookVector
	-- ride over the terraces (owner, 27 Oct: mowers got stuck on the 2-stud ground steps): the mower floats a
	-- hair above the ground, and it looks ahead along where it's going, so it lifts before a step reaches the
	-- chassis and drops gently down the other side. Walls, cliffs over MAX_CLIMB and closed gates still stop it.
	-- (These settings are local: the server's own Drive constraint is untouched, so when you get out it just stops.)
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	local vy = hoverVelocity(model, body, dir, speed, dt)
	lv.VectorVelocity = Vector3.new(dir.X * speed, vy, dir.Z * speed)
	ao.CFrame = rot
end)

return Input
