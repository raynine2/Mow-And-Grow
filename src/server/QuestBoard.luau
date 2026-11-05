-- (5 Nov, owner after the balance review: "Daily + weekly quests") The QUESTS window's daily and weekly quests, in the
-- lobby and in runs. Not the run's onboarding chain (server/Quests, Config.QUESTS).
--   * Each UTC day (00:00) a player gets Config.QUEST_BOARD.daily quests from Config.DAILY_QUESTS, and each week
--     (Monday 00:00 UTC) Config.QUEST_BOARD.weekly from Config.WEEKLY_QUESTS. The pick comes from the period number
--     and the UserId (the same in every server), and is saved in the profile's `board` when first handed out.
--   * A quest counts one lifetime counter in the profile's stats (Config.QUEST_KINDS): it saves the counter's value
--     when handed out (`base`) and its progress is how far the counter has gone since. So the game's own code that
--     counts cuts, sales, bosses, areas, speed challenges, hatches, coins, runs and playtime drives the quests; nothing
--     here hooks into the gameplay.
--   * Claiming (remote "Progress" "claim", period, slot) is checked here: done, not claimed yet. It pays flat gems
--     (like the daily rewards) and, for a quest with `egg`, a free egg (that egg's gem price when the pet bag is full).
-- Main.server puts QuestBoard.view in the client's state; client/QuestsWindow draws it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local QuestBoard = {}

local DAY = 86400
-- 1970-01-01 was a Thursday, so day 4 (5 Jan 1970) was a Monday: weeks are counted from there
local MONDAY = 4

local function dayNumber(): number
	return os.time() // DAY
end

local function weekNumber(): number
	return (os.time() // DAY - MONDAY) // 7
end

-- When the current period ends (unix seconds, UTC).
local function dayEnds(): number
	return (dayNumber() + 1) * DAY
end

local function weekEnds(): number
	return ((weekNumber() + 1) * 7 + MONDAY) * DAY
end

local PERIODS = {
	daily = { pool = function() return Config.DAILY_QUESTS end, count = function() return Config.QUEST_BOARD.daily end, number = dayNumber, ends = dayEnds, key = "day", salt = 1 },
	weekly = { pool = function() return Config.WEEKLY_QUESTS end, count = function() return Config.QUEST_BOARD.weekly end, number = weekNumber, ends = weekEnds, key = "week", salt = 2 },
}

-- The lifetime counter a quest kind reads, in the quest's units.
local function counter(data, kind: string): number
	local k = Config.QUEST_KINDS[kind]
	if not k then
		return 0
	end
	local v = tonumber(data.stats and data.stats[k.stat]) or 0
	return v / (k.per or 1)
end

-- `n` quest ids from `pool`, the same for the same seed (a partial shuffle).
local function pick(pool, n: number, seed: number): { string }
	local ids = {}
	for _, q in pool do
		table.insert(ids, q.id)
	end
	local rng = Random.new(seed)
	local out = {}
	for i = 1, math.min(n, #ids) do
		local j = rng:NextInteger(i, #ids)
		ids[i], ids[j] = ids[j], ids[i]
		table.insert(out, ids[i])
	end
	return out
end

local function board(data)
	local b = data.board
	if type(b) ~= "table" then
		b = { day = 0, week = 0, daily = {}, weekly = {} }
		data.board = b
	end
	b.daily = if type(b.daily) == "table" then b.daily else {}
	b.weekly = if type(b.weekly) == "table" then b.weekly else {}
	return b
end

-- Hand out new quests when a period has turned over. Returns true when something was rolled.
local function ensure(player: Player, data): boolean
	local b = board(data)
	local rolled = false
	for name, P in PERIODS do
		local now = P.number()
		if b[P.key] ~= now then
			b[P.key] = now
			local list = {}
			-- (UserId * 31: Studio's test players have small negative ids, which is fine)
			for _, id in pick(P.pool(), P.count(), player.UserId * 31 + now * 1009 + P.salt) do
				local def = Config.boardQuest(id)
				if def then
					table.insert(list, { id = id, base = counter(data, def.kind), claimed = false })
				end
			end
			b[name] = list
			rolled = true
		end
	end
	return rolled
end

local function progress(data, entry): (number, any)
	local def = Config.boardQuest(entry.id)
	if not def then
		return 0, nil
	end
	local got = math.floor(counter(data, def.kind) - (tonumber(entry.base) or 0) + 1e-6)
	return math.clamp(got, 0, def.goal), def
end

local function title(def): string
	local goal = if def.goal >= 100000 then Format.short(def.goal) else Format.commas(def.goal)
	return (string.format(def.title, goal))
end

-- What the client draws: { daily = { ends, list }, weekly = { ends, list }, ready = claimable count }.
function QuestBoard.view(player: Player, data)
	ensure(player, data)
	local b = board(data)
	local out = { ready = 0 }
	for name, P in PERIODS do
		local list = {}
		for slot, entry in b[name] do
			local got, def = progress(data, entry)
			if def then
				local done = got >= def.goal
				local kind = Config.QUEST_KINDS[def.kind]
				table.insert(list, {
					slot = slot,
					id = def.id,
					text = title(def),
					icon = kind and kind.icon or "quest",
					progress = got,
					goal = def.goal,
					gems = def.gems,
					egg = def.egg,
					done = done,
					claimed = entry.claimed == true,
				})
				if done and entry.claimed ~= true then
					out.ready += 1
				end
			end
		end
		out[name] = { ends = P.ends(), list = list }
	end
	return out
end

-- Claim quest `slot` of `period` ("daily" | "weekly").
function QuestBoard.claim(player: Player, data, period: any, slot: any)
	local P = type(period) == "string" and PERIODS[period]
	if not P or type(slot) ~= "number" or slot ~= slot then
		return
	end
	ensure(player, data)
	local entry = board(data)[period][math.floor(slot)]
	if type(entry) ~= "table" or entry.claimed == true then
		return
	end
	local got, def = progress(data, entry)
	if not def or got < def.goal then
		Net.notify(player, "That quest isn't done yet!", "red")
		return
	end
	entry.claimed = true
	data.gems += def.gems -- flat, like the daily rewards
	local egg = def.egg and Config.egg(def.egg)
	local eggGems = 0
	if egg then
		local ok, hatched = pcall(require(script.Parent.Pets).hatch, player, data, egg.id, 1, false)
		if not ok or not hatched then
			eggGems = egg.price or 0 -- (the pet bag is full: its price in gems instead)
			data.gems += eggGems
		end
	end
	PlayerData.changed(player)
	Net.send(player, "Fx", "questClaim", { text = title(def), gems = def.gems + eggGems, egg = egg and eggGems == 0 and egg.name or nil, period = period })
end

-- DEV: finish every quest on the board (the counters stay; the bases go back by the goal).
function QuestBoard.devFinish(player: Player, data)
	ensure(player, data)
	for name in PERIODS do
		for _, entry in board(data)[name] do
			local def = Config.boardQuest(entry.id)
			if def then
				entry.base = counter(data, def.kind) - def.goal
			end
		end
	end
	PlayerData.changed(player)
end

local started = false
function QuestBoard.start()
	if started then
		return
	end
	started = true
	PlayerData.onLoaded(function(player, data)
		ensure(player, data)
		PlayerData.changed(player)
	end)
	Net.on("Progress", 4, function(player, action, a, b)
		local data = PlayerData.get(player)
		if not data or type(action) ~= "string" then
			return
		end
		if action == "claim" then
			QuestBoard.claim(player, data, a, b)
		elseif action == "starsSeen" then
			require(script.Parent.Rebirth).seen(player, data)
		end
	end)
	-- New quests at the turn of the day / week while you play, and the play-time quests tick on (playtime counts up
	-- every second without a state push of its own).
	task.spawn(function()
		while true do
			task.wait(20)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				if data then
					if ensure(player, data) then
						Net.notify(player, "New quests are up! Open QUESTS to see them", "yellow")
						PlayerData.changed(player)
					else
						for name in PERIODS do
							for _, entry in board(data)[name] do
								local def = Config.boardQuest(entry.id)
								if def and def.kind == "minutes" and not entry.claimed then
									PlayerData.changed(player)
								end
							end
						end
					end
				end
			end
		end
	end)
end

return QuestBoard
