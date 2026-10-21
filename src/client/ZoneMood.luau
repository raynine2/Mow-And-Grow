-- Per-zone mood in a run: as you walk from zone to zone the light, haze and colour grade ease over to that
-- zone's mood (Config.LOOK.moods: fresh lawn, clean golf course, golden wheat farm, misty swamp, humid jungle).
-- The lobby and the hub keep the base look the server set. Client-only, and it only writes while something
-- is changing.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Look = require(Shared:WaitForChild("Look"))
local State = require(script.Parent.State)

local ZoneMood = {}
local player = Players.LocalPlayer

local EASE = 0.9 -- how fast the look follows (per second); slow enough to read as a tween

-- moods by index: 0 = the hub (base look), 1..n = the zones
local moods: { [number]: Look.Values } = { [0] = Look.mood(nil) }
for i, def in Config.ZONES do
	moods[i] = Look.mood(def.style)
end

-- the night look (server/DayNight turns the clock; this eases the deep blue light in around sunset)
local night: Look.Values = table.clone(Config.LOOK.base)
for k, v in Config.LOOK.night do
	night[k] = v
end

-- How much of the night look to use at the current time of day: 0 by day, 1 at night, eased across ~1.2 hours
-- of game time around dusk and dawn.
local function nightness(): number
	local d = Config.LOOK.day
	local c = Lighting.ClockTime
	local function ramp(x: number): number
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end
	if c >= 12 then
		return ramp((c - (d.dusk - 0.6)) / 1.2)
	end
	return 1 - ramp((c - (d.dawn - 0.6)) / 1.2)
end

-- Which area a world position is in (0 = the hub or outside the map; see Config.MAP).
function ZoneMood.zoneAt(pos: Vector3): number
	return math.max(0, Config.zoneAt(pos))
end

-- The zone the local player is standing in (0 = hub, or the lobby).
ZoneMood.zone = 0

local function focus(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return root.Position
	end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position
end

-- The look at a world position: the mood of the area it's in (the slow easing below blends across fences).
local function targetAt(pos: Vector3): Look.Values
	return moods[ZoneMood.zoneAt(pos)] or moods[0]
end

local nightMix: Look.Values = {}
local current: Look.Values = table.clone(moods[0])
local written: Look.Values = table.clone(moods[0])
local changed: Look.Values = {}

RunService.Heartbeat:Connect(function(dt)
	local target = moods[0]
	ZoneMood.zone = 0
	if State.isRun() then
		local pos = focus()
		if pos then
			ZoneMood.zone = ZoneMood.zoneAt(pos)
			target = targetAt(pos)
		end
		if Config.WORLD_GEN then
			return -- the generated world's valleys have their own lighting (client/BiomeLight)
		end
		-- the time of day on top of the area's mood
		local n = nightness()
		if n > 0.001 then
			target = Look.blend(target, night, n, nightMix)
		end
	end
	Look.blend(current, target, 1 - math.exp(-dt * EASE), current)
	-- write only the values that moved enough to see
	table.clear(changed)
	local any = false
	for k, v in current do
		if Look.diff(v, written[k]) > 0.003 then
			changed[k] = v
			written[k] = v
			any = true
		end
	end
	if any then
		Look.apply(changed)
	end
end)

return ZoneMood
