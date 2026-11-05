-- SPRINT (5 Nov, owner's TikTok: "simulate an eight year old playing your roblox game with all coins, XP, badges and
-- rewards removed ... improve the core mechanics until it can stand on its own"; walking to the grass and back to the
-- Shredder had nothing fun in it; he picked a free sprint). Hold Shift (L3 on a gamepad, the SPRINT button on a phone)
-- to run Config.SPRINT.mult x as fast: no stamina, a spray of grass behind your feet, and the wider view client/
-- CameraView already gives speed.
-- The server owns your walk speed (server/Stats; boss fights set 0 while you're downed): this only multiplies
-- whatever the server last set, on your own screen (your character's physics are yours), and never when it's 0, while
-- you sit (mowers) or while a film or fly-over has the camera.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local Sprint = {}
local S = Config.SPRINT or { mult = 1.6, on = true }
local player = Players.LocalPlayer

local wanted = false -- the key / button is held
Sprint.on = false -- sprinting right now (others may read it)

local hum: Humanoid? = nil
local base = 16 -- the server's walk speed
local writing = false -- our own write of WalkSpeed (not a new base)
local trail: ParticleEmitter? = nil

local function apply()
	local h = hum
	if not h or not h.Parent then
		return
	end
	local cam = workspace.CurrentCamera
	local free = cam ~= nil and cam.CameraType == Enum.CameraType.Custom
	local go = S.on ~= false and wanted and base > 0 and not h.Sit and free
	Sprint.on = go
	local want = if go then base * (S.mult or 1.6) else base
	if math.abs(h.WalkSpeed - want) > 0.01 then
		writing = true
		h.WalkSpeed = want
		writing = false
	end
end

-- grass flicked up from your feet while you sprint over the ground
local function makeTrail(root: BasePart)
	local a = Instance.new("Attachment")
	a.Name = "SprintTrail"
	a.Position = Vector3.new(0, -2.8, 0.6)
	a.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 225, 90), Color3.fromRGB(90, 170, 60))
	e.LightInfluence = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.3, 0.55)
	e.Speed = NumberRange.new(4, 8)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Back
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Rate = 0
	e.Parent = a
	trail = e
end

local function onCharacter(char: Model)
	local h = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not h then
		return
	end
	hum = h
	base = h.WalkSpeed
	h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if writing then
			return
		end
		-- the server (or a fight) set a new speed: that's the base; sprint on top of it again
		base = h.WalkSpeed
		apply()
	end)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if root then
		makeTrail(root)
	end
	apply()
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local function set(on: boolean)
	if wanted ~= on then
		wanted = on
		apply()
	end
end

-- keyboard and gamepad hold; the phone gets a SPRINT button (ContextActionService's own touch button)
local function action(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		set(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		set(false)
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("MowSprint", action, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("MowSprint", "SPRINT")
ContextActionService:SetPosition("MowSprint", UDim2.new(1, -170, 1, -150))
UserInputService.WindowFocusReleased:Connect(function()
	set(false)
end)

-- the camera can change hands (films, the fly-over) and the grass spray follows how fast you're really going
RunService.Heartbeat:Connect(function()
	if wanted then
		apply()
	end
	local e = trail
	if e then
		local h = hum
		local moving = h ~= nil and h.MoveDirection.Magnitude > 0.1 and h.FloorMaterial ~= Enum.Material.Air
		local r = if Sprint.on and moving then 26 else 0
		if e.Rate ~= r then
			e.Rate = r
		end
	end
end)

return Sprint
