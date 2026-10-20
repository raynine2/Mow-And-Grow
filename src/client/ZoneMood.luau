-- Per-zone mood in a run: as you walk from zone to zone the light, haze and colour grade ease over to that
-- zone's mood (Config.LOOK.moods: fresh lawn, clean golf course, golden wheat farm, misty swamp, humid jungle).
-- The lobby and the hub keep the base look the server set. Client-only, and it only writes while something
-- is changing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Look = require(Shared:WaitForChild("Look"))
local State = require(script.Parent.State)

local ZoneMood = {}
local player = Players.LocalPlayer

local BLEND = 14 -- studs either side of a zone's fence over which two moods mix
local EASE = 0.9 -- how fast the look follows (per second); slow enough to read as a tween

-- moods by index: 0 = the hub (base look), 1..n = the zones
local moods: { [number]: Look.Values } = { [0] = Look.mood(nil) }
for i, def in Config.ZONES do
	moods[i] = Look.mood(def.style)
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Which zone a world position is in (0 = the hub; the zones are rings round it, see Config.RING).
function ZoneMood.zoneAt(pos: Vector3): number
	return Config.zoneAt(pos)
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

-- The look at a world position: the zone's mood, mixed with the neighbour's near a fence.
local scratch: Look.Values = {}
local function targetAt(pos: Vector3): Look.Values
	local zone = ZoneMood.zoneAt(pos)
	local r = Config.ringRadius(pos)
	-- nearest fence (the one into this zone, or the next one out)
	local best, bestD = zone, math.huge
	for i = math.max(1, zone), math.min(#Config.ZONES, zone + 1) do
		local d = math.abs(r - Config.fenceRadius(i))
		if d < bestD then
			best, bestD = i, d
		end
	end
	if bestD >= BLEND then
		return moods[zone]
	end
	local t = smooth((r - Config.fenceRadius(best)) / (2 * BLEND) + 0.5)
	return Look.blend(moods[best - 1], moods[best], t, scratch)
end

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
