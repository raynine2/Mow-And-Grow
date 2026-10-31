-- (owner, 29 Oct: "add analytics so you can see where real players quit") Roblox AnalyticsService events, shown in
-- the Creator Dashboard under Analytics. No personal data: only what happened in the run.
--   funnel "Run": step z = reached area z (1..8), step 9 = finished the run
--   custom events: BossDefeated / BossWipe (value = area), RunComplete (value = minutes), ShopBuy (value = coins)
--   every event carries the run's difficulty in CustomField01
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = {}

local function fields(extra: string?): { [string]: string }
	local f = {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tostring(ReplicatedStorage:GetAttribute("Difficulty") or "Normal"),
	}
	if extra then
		f[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = extra
	end
	return f
end

local reached: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(p)
	reached[p] = nil
end)

-- The run reached area z (each player's funnel only moves forward).
function Analytics.area(z: number)
	for _, p in Players:GetPlayers() do
		if (reached[p] or 0) < z then
			for step = (reached[p] or 0) + 1, z do
				pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, p, "Run", nil, step, "Area " .. step, fields())
			end
			reached[p] = z
		end
	end
end

function Analytics.event(name: string, value: number?, extra: string?, player: Player?)
	local list = if player then { player } else Players:GetPlayers()
	for _, p in list do
		pcall(AnalyticsService.LogCustomEvent, AnalyticsService, p, name, value or 1, fields(extra))
	end
end

-- The run is over: the last funnel step and the time.
function Analytics.complete(player: Player, seconds: number)
	pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, player, "Run", nil, 9, "Finished", fields())
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "RunComplete", math.floor(seconds / 60 + 0.5), fields())
end

return Analytics
