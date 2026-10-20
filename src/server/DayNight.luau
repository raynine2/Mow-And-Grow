-- Day and night in a run (Chop A Forest: 8-minute days, 4-minute nights). The server turns Lighting.ClockTime
-- smoothly from dawn to dusk over the day and on round through midnight over the night, and publishes the phase
-- for the HUD as ReplicatedStorage attributes: DayPhase ("day" / "night"), DayLeft (seconds left in the phase)
-- and DayLength (seconds in the phase). The night look (deep blue light) is blended in by client/ZoneMood from
-- the clock, so it eases in at sunset. The lobby keeps its sunny afternoon (this only starts in runs).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)

local DayNight = {}

local started = false

-- Where in the cycle we are: phase, seconds into it, the phase's length, and the clock time it means.
function DayNight.at(t: number): (string, number, number, number)
	local d = Config.LOOK.day
	local cycle = d.length + d.nightLength
	local into = t % cycle
	if into < d.length then
		local k = into / d.length
		return "day", into, d.length, d.dawn + (d.dusk - d.dawn) * k
	end
	local k = (into - d.length) / d.nightLength
	local nightHours = 24 - d.dusk + d.dawn
	return "night", into - d.length, d.nightLength, (d.dusk + nightHours * k) % 24
end

function DayNight.start()
	if started then
		return
	end
	started = true
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		pcall(function()
			sky.CelestialBodiesShown = true
			sky.StarCount = 3000
			sky.MoonAngularSize = 14
		end)
	end
	local t0 = os.clock()
	-- the clock, 10 times a second (smooth on the clients)
	task.spawn(function()
		while true do
			local _, _, _, clock = DayNight.at(os.clock() - t0)
			Lighting.ClockTime = clock
			task.wait(0.1)
		end
	end)
	-- the HUD's phase bar, once a second
	task.spawn(function()
		while true do
			local phase, into, len = DayNight.at(os.clock() - t0)
			ReplicatedStorage:SetAttribute("DayPhase", phase)
			ReplicatedStorage:SetAttribute("DayLeft", math.max(0, math.ceil(len - into)))
			ReplicatedStorage:SetAttribute("DayLength", len)
			task.wait(1)
		end
	end)
end

return DayNight
