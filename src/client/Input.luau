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

local function swing()
	local now = os.clock()
	if now - lastSwing < toolCooldown() then
		return
	end
	lastSwing = now
	State.fire("Swing")
	State.emit("swing")
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
		if holding and equippedSwingTool() then
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

-- close a window when you walk away from the stall that opened it
ProximityPromptService.PromptHidden:Connect(function(prompt)
	local window = prompt:GetAttribute("Window")
	if type(window) == "string" and UI.isOpen(window) then
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

RunService.RenderStepped:Connect(function(dt)
	local model, seat = currentMower()
	if model ~= driving then
		driving = model
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
	State.emit("fuel", fuel, maxFuel)
	local top = model:GetAttribute("Speed") or 30
	local throttle = if fuel > 0 then seat.ThrottleFloat else 0
	local target = if throttle >= 0 then throttle * top else throttle * top * 0.5
	speed += (target - speed) * math.min(1, dt * 3)
	local turnRate = 2.2 * math.clamp(math.abs(speed) / 12, 0.35, 1)
	yaw -= seat.SteerFloat * turnRate * dt * (if speed < 0 then -1 else 1)
	local rot = CFrame.Angles(0, yaw, 0)
	local dir = rot.LookVector
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
	ao.CFrame = rot
end)

return Input
