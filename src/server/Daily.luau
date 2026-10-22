-- The daily reward with a streak: claim once per day (UTC) at the Free Rewards stall. Coming back the next day
-- moves you one day along a 7-day ladder of bigger and bigger gem rewards (Config.DAILY_STREAK); after day 7 it
-- starts over at day 1 but the streak count keeps going. Missing a day resets the streak to day 1.
-- Between ladder days there are free gems every 6 hours (Config.FREE_GEMS) at the same stall: claiming gives the
-- ladder day when it's ready, else the free gems when they're ready.
-- Used by server/Lobby and server/Hub (both have the stall); Main puts Daily.view and Daily.freeView in the
-- client's state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local Net = require(script.Parent.Net)

local Daily = {}

local DAY = 86400

local function today(): number
	return os.time() // DAY
end

local function slot(streak: number): number
	return ((math.max(streak, 1) - 1) % #Config.DAILY_STREAK) + 1
end

export type View = {
	ready: boolean, -- can claim now
	wait: number, -- seconds until the next claim (0 when ready)
	day: number, -- the ladder slot you'd claim now (ready) or claimed today (1..7)
	streak: number, -- days in a row so far (counting today once claimed)
	claimedToday: boolean,
}

function Daily.view(data): View
	local t = today()
	local last = data.lastDailyDay or 0
	local streak = data.dailyStreak or 0
	if last == t then
		return { ready = false, wait = (t + 1) * DAY - os.time(), day = slot(streak), streak = streak, claimedToday = true }
	end
	local keeps = last == t - 1 -- claimed yesterday: the streak carries on
	local held = if keeps then streak else 0
	return { ready = true, wait = 0, day = slot(held + 1), streak = held, claimedToday = false }
end

export type FreeView = { ready: boolean, wait: number, gems: number }

-- The 6-hourly free gems: ready now, or how long until they are.
function Daily.freeView(data): FreeView
	local left = (data.lastFreeGems or 0) + Config.FREE_GEMS.every - os.time()
	return { ready = left <= 0, wait = math.max(0, left), gems = Config.FREE_GEMS.gems }
end

local function claimFree(player: Player, data): boolean
	local f = Daily.freeView(data)
	if not f.ready then
		return false
	end
	data.lastFreeGems = os.time()
	data.gems += f.gems
	Net.send(player, "Fx", "daily", { free = true, gems = f.gems, wait = Config.FREE_GEMS.every })
	return true
end

-- Claim at the stall: today's ladder day if it's ready, else the free gems. Returns true when gems were given.
function Daily.claim(player: Player, data): boolean
	local v = Daily.view(data)
	if not v.ready then
		if claimFree(player, data) then
			return true
		end
		local f = Daily.freeView(data)
		Net.notify(player, ("Free gems in %s · day %d tomorrow (%s)"):format(Format.clock(f.wait), slot(v.streak + 1), Format.clock(v.wait)), "yellow")
		return false
	end
	data.dailyStreak = v.streak + 1
	data.lastDailyDay = today()
	data.lastDaily = os.time()
	local gems = Config.DAILY_STREAK[v.day]
	data.gems += gems
	Net.send(player, "Fx", "daily", { day = v.day, gems = gems, streak = data.dailyStreak })
	return true
end

return Daily
