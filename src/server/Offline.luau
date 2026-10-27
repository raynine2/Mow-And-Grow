-- OFFLINE EARNINGS (owner, 28 Oct: "make solo and friend runs save offline so people would come back").
-- Runs already save in the profile (data.run: area, coins, tools, upgrades, bag, coin mowers) until they're finished,
-- for solo and party runs alike (each player keeps their own). On top of that, time away pays: join with a saved run
-- after at least Config.OFFLINE.minAway seconds and your lawn "grew while you were away":
--   * coins straight into the saved run: minutes away x Config.OFFLINE.coinsPerMin x the run's area grass value
--   * a few gems: hours away x Config.OFFLINE.gemsPerHour
-- both capped at Config.OFFLINE.maxHours. client/WelcomeBack shows it (Fx "offline") with a CONTINUE RUN button.
-- data.lastSeen (os.time) is stamped on join, every minute and on leave. A lobby -> run teleport takes seconds, so it
-- never counts as time away. Server time only: nothing the client sends is trusted.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local Offline = {}

local function stamp(player: Player)
	local data = PlayerData.get(player)
	if data then
		data.lastSeen = os.time()
	end
end

-- What `data` earns for the time since data.lastSeen: coins, gems, minutes away (all 0 when nothing is due).
function Offline.reward(data, now: number): (number, number, number)
	local cfg = (Config :: any).OFFLINE
	local last = tonumber(data.lastSeen)
	if not cfg or not last or type(data.run) ~= "table" then
		return 0, 0, 0
	end
	local away = now - last
	if away < cfg.minAway then
		return 0, 0, 0
	end
	local secs = math.min(away, cfg.maxHours * 3600)
	local zone = Config.ZONES[math.clamp(tonumber(data.run.zone) or 1, 1, #Config.ZONES)]
	local coins = math.floor(secs / 60 * cfg.coinsPerMin * (zone and zone.value or 1))
	local gems = math.floor(secs / 3600 * cfg.gemsPerHour)
	return coins, gems, math.floor(away / 60)
end

function Offline.start()
	PlayerData.onLoaded(function(player, data)
		local now = os.time()
		local coins, gems, mins = Offline.reward(data, now)
		data.lastSeen = now
		if coins <= 0 and gems <= 0 then
			return
		end
		data.run.coins = (data.run.coins or 0) + coins
		data.gems = (data.gems or 0) + gems
		PlayerData.changed(player)
		local cfg = (Config :: any).OFFLINE
		-- (a moment later: the client is still loading on join)
		task.delay(5, function()
			if player.Parent then
				Net.send(player, "Fx", "offline", {
					coins = coins,
					gems = gems,
					mins = mins,
					zone = data.run and data.run.zone or 1,
					capped = mins >= cfg.maxHours * 60,
				})
			end
		end)
	end)
	Players.PlayerRemoving:Connect(stamp)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in Players:GetPlayers() do
				stamp(p)
			end
		end
	end)
end

return Offline
