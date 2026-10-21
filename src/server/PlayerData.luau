-- Player profiles: one DataStore key per player, written only with UpdateAsync, with a session lock so a
-- player hopping between the lobby and a run server never gets duplicated or rolled-back data.
-- In Studio every profile is a dry run: it loads (if API access is on) but never writes.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)

local PlayerData = {}

local IS_STUDIO = RunService:IsStudio()
local LOCK_STALE = 300 -- a lock older than this (no autosave for 5 min) belongs to a dead server
local AUTOSAVE = 60

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.SAVE_KEY)
end)

local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, any) -> () } = {}
local changedCallbacks: { (Player, any) -> () } = {}
local dirty: { [Player]: boolean } = {}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

local DEFAULT = {
	schema = Config.SCHEMA,
	gems = 0,
	classes = { [Config.DEFAULT_CLASS] = true },
	class = Config.DEFAULT_CLASS,
	perks = { sell = 0, bundle = 0, luck = 0, gem = 0 },
	mowers = {}, -- permanent mowers (gems / robux): [id] = true
	tools = {}, -- PERMANENT tools bought with Robux, given at the start of every run: [id] = true
	lastDaily = 0,
	groupClaimed = false,
	-- lifetime stats (the STATS window): clumps cut, bundles sold, coins earned, mutated ("rare") clumps cut,
	-- seconds played; newsSeen = the newest Config.NEWS id the player has seen
	stats = { cut = 0, runs = 0, bosses = 0, sold = 0, coinsEarned = 0, rare = 0, playtime = 0, newsSeen = 0 },
	guns = {}, -- boss-crate guns bought with Robux: [gunId] = true
	peaceful = false, -- Peaceful Mode for runs this player hosts (no night monsters, no best time)
	pets = {}, -- hatched critters: [uid] = petId
	petsOn = {}, -- equipped pet uids (at most Config.PET_EQUIP)
	petNext = 1, -- next uid number
	index = {}, -- grass types collected: ["<zone>:<mutation>"] = true (see Config.INDEX_GEMS)
	bestTime = 0, -- fastest finished run in seconds (0 = none yet)
	run = nil, -- the saved run, see PlayerData.newRun
	receipts = {}, -- recent processed purchase ids
}

function PlayerData.newRun()
	return {
		zone = 1, -- highest zone unlocked
		coins = 0,
		tool = 1, -- index into Config.TOOLS of the best tool owned
		upgrades = { power = 0, speed = 0, sell = 0, swing = 0, grasp = 0 }, -- (old runs may also have "carry")
		bag = 0, -- index into Config.BAGS of the best bag bought (0 = none)
		vacuum = false, -- the Leaf Vacuum
		mowers = {}, -- coin mowers bought this run: [id] = true
		trial = false, -- Trial Mower bought for this run
		fuel = {}, -- [mowerId] = fuel left
		carry = {}, -- bundles on your back: { {z = zone, m = mutationId}, ... }
		started = os.time(),
		time = 0, -- seconds spent playing this run (server/Run counts it; Best Times uses it)
		introSeen = false, -- the run's fly-over intro was shown (client/Intro)
	}
end

-- Fill in fields added after a profile was first saved, and run schema migrations.
local function reconcile(data)
	for k, v in DEFAULT do
		if data[k] == nil then
			data[k] = deepCopy(v)
		end
	end
	for k, v in DEFAULT.perks do
		if data.perks[k] == nil then
			data.perks[k] = v
		end
	end
	for k, v in DEFAULT.stats do
		if data.stats[k] == nil then
			data.stats[k] = v
		end
	end
	if data.run then
		local fresh = PlayerData.newRun()
		for k, v in fresh do
			if data.run[k] == nil then
				data.run[k] = v
			end
		end
	end
	data.schema = Config.SCHEMA
	return data
end

local function retry(fn: () -> any, tries: number): (boolean, any)
	local delay = 1
	local ok, result
	for _ = 1, tries do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(delay)
		delay *= 2
	end
	return false, result
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

-- Load with a session lock. Returns the profile table or nil.
local function load(player: Player)
	if not store then
		return reconcile(deepCopy(DEFAULT)), "nostore"
	end
	if IS_STUDIO then
		local ok, data = retry(function()
			return store:GetAsync(key(player))
		end, 2)
		return reconcile(if ok and type(data) == "table" then data else deepCopy(DEFAULT)), "studio"
	end

	for attempt = 1, 8 do
		local lockedByOther = false
		local ok, result = retry(function()
			return store:UpdateAsync(key(player), function(old)
				old = if type(old) == "table" then old else deepCopy(DEFAULT)
				local lock = old._lock
				if lock and lock.job ~= game.JobId and os.time() - (lock.t or 0) < LOCK_STALE and attempt < 8 then
					lockedByOther = true
					return nil -- leave it alone, try again soon
				end
				old._lock = { job = game.JobId, t = os.time() }
				return old
			end)
		end, 3)
		if not ok then
			return nil, "error"
		end
		if not lockedByOther and type(result) == "table" then
			return reconcile(result), "ok"
		end
		task.wait(5) -- the other server is still saving this player (normal right after a teleport)
		if not player.Parent then
			return nil, "left"
		end
	end
	return nil, "locked"
end

local function write(player: Player, release: boolean)
	local data = profiles[player]
	if not data or not store or data._dryRun then
		return true
	end
	local copy = deepCopy(data)
	local ok = retry(function()
		store:UpdateAsync(key(player), function(old)
			if type(old) == "table" and old._lock and old._lock.job ~= game.JobId then
				return nil -- another server owns this player now; never overwrite it
			end
			copy._lock = if release then nil else { job = game.JobId, t = os.time() }
			return copy
		end)
	end, 4)
	return ok
end

function PlayerData.get(player: Player)
	return profiles[player]
end

-- Total playtime: one second per second online, in any mode (the client ticks its copy between updates).
task.spawn(function()
	while true do
		task.wait(1)
		for _, prof in profiles do
			if prof.stats then
				prof.stats.playtime = (prof.stats.playtime or 0) + 1
			end
		end
	end
end)

function PlayerData.wait(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function PlayerData.onLoaded(fn: (Player, any) -> ())
	table.insert(loadedCallbacks, fn)
	for p, prof in profiles do
		task.spawn(fn, p, prof)
	end
end

function PlayerData.onChanged(fn: (Player, any) -> ())
	table.insert(changedCallbacks, fn)
end

-- Call after changing a profile. Pushes the new state to the client on the next heartbeat.
function PlayerData.changed(player: Player)
	dirty[player] = true
end

function PlayerData.save(player: Player)
	return write(player, false)
end

-- Remember a processed purchase so a retried receipt is never granted twice.
function PlayerData.hasReceipt(data, purchaseId: string): boolean
	return table.find(data.receipts, purchaseId) ~= nil
end
function PlayerData.addReceipt(data, purchaseId: string)
	table.insert(data.receipts, purchaseId)
	while #data.receipts > 50 do
		table.remove(data.receipts, 1)
	end
end

local function onJoin(player: Player)
	local data, why = load(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick(
			"Your save couldn't load right now ("
				.. tostring(why)
				.. "). Nothing was lost; please rejoin in a minute."
		)
		return
	end
	if IS_STUDIO then
		data._dryRun = true -- Studio tests never save
	end
	profiles[player] = data
	for _, fn in loadedCallbacks do
		task.spawn(fn, player, data)
	end
	dirty[player] = true
end

local function onLeave(player: Player)
	if profiles[player] then
		write(player, true)
	end
	profiles[player] = nil
	dirty[player] = nil
end

Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end

-- Push changed state to clients (batched once per frame).
RunService.Heartbeat:Connect(function()
	for player in dirty do
		dirty[player] = nil
		local data = profiles[player]
		if data then
			for _, fn in changedCallbacks do
				local ok, err = pcall(fn, player, data)
				if not ok then
					warn("[PlayerData] changed callback failed: " .. tostring(err))
				end
			end
		end
	end
end)

-- Autosave.
task.spawn(function()
	while true do
		task.wait(AUTOSAVE)
		for player in profiles do
			task.spawn(write, player, false)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			write(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

return PlayerData
