-- The world's sound bed, all on this client:
--   - footsteps: Roblox's own walking sound is one plastic loop on every floor, so it's muted for you and each
--     step plays instead: a light rustle on grass, a soft heel thud on dirt, wood and stone (pitch and volume
--     vary a little, and a sprint steps faster);
--   - ambience: quiet loops of distant birds and a breeze, crossfaded by where you are (jungle birds in the
--     jungle and the swamp, birds and breeze everywhere else; only the breeze at night).
-- Licensed audio only (Config.SOUNDS: Pro Sound Effects library sounds and engine built-ins).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)
local ZoneMood = require(script.Parent.ZoneMood)

local Soundscape = {}
local player = Players.LocalPlayer

-------------------------------------------------------------------------------------------------------------
-- footsteps
-------------------------------------------------------------------------------------------------------------
local SOFT = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Snow] = true,
	[Enum.Material.Fabric] = true,
}
local STRIDE = 3.4 -- studs walked per step at walking speed (a little longer when running)

-- Roblox's RbxCharacterSounds puts a looping "Running" sound in the root part: keep it silent for you.
local function muteRunning(root: Instance)
	local function mute(s: Instance)
		if s:IsA("Sound") and s.Name == "Running" then
			s.Volume = 0
			s:GetPropertyChangedSignal("Volume"):Connect(function()
				if s.Volume ~= 0 then
					s.Volume = 0
				end
			end)
		end
	end
	for _, c in root:GetChildren() do
		mute(c)
	end
	root.ChildAdded:Connect(mute)
end

local function onCharacter(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if root then
		muteRunning(root)
	end
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local walked = 0
local left = false -- alternate feet: a hair of pitch difference between them

local function step(material: Enum.Material, speed: number)
	left = not left
	local loud = math.clamp(0.75 + speed / 40, 0.75, 1.25)
	local foot = if left then 0.97 else 1.03
	if SOFT[material] then
		Sound.play("stepGrass", 0.12, loud * foot)
		Sound.play("stepThud", 0.1, 0.45 * loud)
	else
		-- dirt, sand, wood, stone, plastic: the heel, a touch brighter on hard floors
		local hard = material ~= Enum.Material.Ground and material ~= Enum.Material.Sand
		Sound.play("stepThud", 0.08, loud * (if hard then 1.1 else 0.9) * foot)
		if not hard then
			Sound.play("stepGrass", 0.15, 0.35 * loud) -- a little grit
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 or hum.SeatPart then
		walked = 0
		return
	end
	local material = hum.FloorMaterial
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if material == Enum.Material.Air or speed < 1.5 then
		walked = math.min(walked, STRIDE * 0.6) -- the first step after stopping comes quickly
		return
	end
	walked += speed * dt
	local stride = STRIDE * math.clamp(speed / 16, 1, 1.35)
	if walked >= stride then
		walked -= stride
		step(material, speed)
	end
end)

-- Landing after a jump or a fall: one heavier step.
local function hookLanding(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			Sound.play("stepThud", 0.05, 1.6)
			if SOFT[hum.FloorMaterial] then
				Sound.play("stepGrass", 0.1, 1.2)
			end
			walked = 0
		end
	end)
end
player.CharacterAdded:Connect(hookLanding)
if player.Character then
	task.spawn(hookLanding, player.Character)
end

-------------------------------------------------------------------------------------------------------------
-- ambience
-------------------------------------------------------------------------------------------------------------
local group = Instance.new("SoundGroup")
group.Name = "MowALawnAmbience"
group.Volume = 1
group.Parent = SoundService

type Bed = { sound: Sound, full: number, level: number }
local beds: { [string]: Bed } = {}
for _, key in { "ambBirds", "ambWind", "ambJungle" } do
	local def = Config.SOUNDS[key]
	if def and def.id and def.id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Amb_" .. key
		s.SoundId = def.id
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = group
		s.Parent = SoundService
		s:Play()
		beds[key] = { sound = s, full = def.volume or 0.2, level = 0 }
	end
end

local JUNGLY = { jungle = true, reeds = true }

-- How loud each bed should be right now (0..1).
local function targets(): { [string]: number }
	local night = ReplicatedStorage:GetAttribute("DayPhase") == "night"
	local z = if State.isRun() then ZoneMood.zone else 0
	local def = Config.ZONES[z]
	local jungly = def ~= nil and JUNGLY[def.style or ""] == true
	return {
		ambBirds = if night or jungly then 0 else 1,
		ambJungle = if jungly and not night then 1 else 0,
		ambWind = if night then 0.8 else 1,
	}
end

RunService.Heartbeat:Connect(function(dt)
	local want = targets()
	local k = math.min(1, dt * 0.6) -- slow crossfades (a couple of seconds)
	for key, b in beds do
		b.level += ((want[key] or 0) - b.level) * k
		local v = b.full * b.level
		if math.abs(b.sound.Volume - v) > 0.002 then
			b.sound.Volume = v
		end
	end
end)

-- Duck the ambience for a moment (big moments that want the stage, like a rare reveal).
function Soundscape.duck(amount: number, time: number)
	group.Volume = 1 - amount
	task.delay(time, function()
		group.Volume = 1
	end)
end

return Soundscape
