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

local BLEND = 14 -- studs either side of a zone's gate over which two moods mix
local EASE = 0.9 -- how fast the look follows (per second); slow enough to read as a tween
local GATE_OFFSET = 16 -- a zone's gate stands this far before its first row (RunBuilder)

-- moods by index: 0 = the hub (base look), 1..n = the zones
local moods: { [number]: Look.Values } = { [0] = Look.mood(nil) }
for i, def in Config.ZONES do
	moods[i] = Look.mood(def.style)
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Which zone a world Z is in (0 = the hub before the first gate).
function ZoneMood.zoneAt(z: number): number
	local n = 0
	for i = 1, #Config.ZONES do
		if z >= Config.zoneStartZ(i) - GATE_OFFSET then
			n = i
		end
	end
	return n
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

-- The look at a world Z: the zone's mood, mixed with the neighbour's near a gate.
local scratch: Look.Values = {}
local function targetAt(z: number): Look.Values
	local zone = ZoneMood.zoneAt(z)
	-- nearest gate line (the one into this zone, or the next one)
	local best, bestD = zone, math.huge
	for i = math.max(1, zone), math.min(#Config.ZONES, zone + 1) do
		local d = math.abs(z - (Config.zoneStartZ(i) - GATE_OFFSET))
		if d < bestD then
			best, bestD = i, d
		end
	end
	if bestD >= BLEND then
		return moods[zone]
	end
	local gate = Config.zoneStartZ(best) - GATE_OFFSET
	local t = smooth((z - gate) / (2 * BLEND) + 0.5)
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
			ZoneMood.zone = ZoneMood.zoneAt(pos.Z)
			target = targetAt(pos.Z)
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
