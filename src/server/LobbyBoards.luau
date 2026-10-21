-- The lobby's leaderboards (BEST TIMES, GRASS CUT, CASH EARNED, PLAYTIME), all-time and from every server like
-- Chop A Forest's. Each stat has an OrderedDataStore: this server writes its players' values every few minutes
-- (live servers only) and reads the top 8 once a minute. In Studio, or when the store can't be read or is empty,
-- a board shows this server's players instead. The boards are found by their "LobbyBoard" tag (Key attribute)
-- in the world, with the row frames LobbyKit.rows made. Every player also gets an "LB_<key>" attribute
-- ("rank|value") that client/LobbyFX shows in the board's YOU row.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local PlayerData = require(script.Parent.PlayerData)

local LobbyBoards = {}

local function duration(sec: number): string
	sec = math.floor(sec)
	local d, h, m = sec // 86400, (sec % 86400) // 3600, (sec % 3600) // 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	end
	return ("%dm"):format(m)
end

type Def = { key: string, store: string, asc: boolean, write: boolean, value: (any) -> number, text: (number) -> string }
local DEFS: { Def } = {
	-- BestTimes writes this store itself (only a new best), lower is better
	{ key = "best", store = "_BestTimes", asc = true, write = false, value = function(d) return d.bestTime or 0 end, text = function(n) return Format.clock(n) end },
	{ key = "cut", store = "_LB_cut", asc = false, write = true, value = function(d) return d.stats and d.stats.cut or 0 end, text = function(n) return Format.short(n) end },
	{ key = "cash", store = "_LB_cash", asc = false, write = true, value = function(d) return d.stats and d.stats.coinsEarned or 0 end, text = function(n) return "$" .. Format.short(n) end },
	{ key = "time", store = "_LB_time", asc = false, write = true, value = function(d) return d.stats and d.stats.playtime or 0 end, text = duration },
}

type Row = { userId: number, name: string, value: number }
local stores: { [string]: OrderedDataStore } = {}
local top: { [string]: { Row } } = {} -- the last global read per key
local written: { [string]: number } = {} -- "<key>:<userId>" -> last value written
local names: { [number]: string } = {}

local live = not RunService:IsStudio()

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	local name = if p then p.DisplayName else nil
	if not name then
		local ok, res = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and res then res else "Player"
	end
	names[userId] = name :: string
	return name :: string
end

local function save(player: Player)
	local data = PlayerData.get(player)
	if not live or not data or data._dryRun then
		return
	end
	for _, def in DEFS do
		local store = stores[def.key]
		local v = math.floor(def.value(data))
		local k = def.key .. ":" .. player.UserId
		if def.write and store and v > 0 and written[k] ~= v then
			local ok = pcall(function()
				store:SetAsync(tostring(player.UserId), v)
			end)
			if ok then
				written[k] = v
			end
		end
	end
end

local function read(def: Def)
	local store = stores[def.key]
	if not live or not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(def.asc, 8)
	end)
	if not ok or not pages then
		return
	end
	local rows = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local id = tonumber(entry.key)
		if id and type(entry.value) == "number" and entry.value > 0 then
			table.insert(rows, { userId = id, name = nameOf(id), value = entry.value })
		end
	end
	top[def.key] = rows
end

-- This server's players, best first (Studio, or a store with nothing in it yet).
local function local_(def: Def): { Row }
	local rows = {}
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		local v = data and def.value(data) or 0
		if v > 0 then
			table.insert(rows, { userId = p.UserId, name = p.DisplayName, value = v })
		end
	end
	table.sort(rows, function(a, b)
		if def.asc then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	return rows
end

local function show(def: Def)
	local rows = top[def.key]
	if not rows or #rows == 0 then
		rows = local_(def)
	end
	for _, part in CollectionService:GetTagged("LobbyBoard") do
		if part:GetAttribute("Key") ~= def.key or not part:IsDescendantOf(workspace) then
			continue
		end
		local gui = part:FindFirstChildWhichIsA("SurfaceGui")
		for i = 1, 8 do
			local f = gui and gui:FindFirstChild("Row" .. i)
			if not f then
				continue
			end
			local r = rows[i]
			f.Visible = r ~= nil
			if r then
				(f :: any).PlayerName.Text = r.name;
				(f :: any).Value.Text = def.text(r.value);
				(f :: any).Icon.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(r.userId)
			end
		end
	end
	-- the YOU rows
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if not data then
			continue
		end
		local rank = "-"
		for i, r in rows do
			if r.userId == p.UserId then
				rank = "#" .. i
			end
		end
		local v = def.value(data)
		local attr = rank .. "|" .. (if v > 0 then def.text(v) else "-")
		if p:GetAttribute("LB_" .. def.key) ~= attr then
			p:SetAttribute("LB_" .. def.key, attr)
		end
	end
end

local started = false
function LobbyBoards.start()
	if started then
		return
	end
	started = true
	for _, def in DEFS do
		pcall(function()
			stores[def.key] = DataStoreService:GetOrderedDataStore(Config.SAVE_KEY .. def.store)
		end)
	end
	Players.PlayerRemoving:Connect(save)
	task.spawn(function()
		local tick = 0
		while true do
			if tick % 60 == 0 then
				for _, def in DEFS do
					read(def)
				end
			end
			if tick % 180 == 90 then
				for _, p in Players:GetPlayers() do
					task.spawn(save, p)
				end
			end
			for _, def in DEFS do
				local ok, err = pcall(show, def)
				if not ok then
					warn("[LobbyBoards] " .. tostring(err))
				end
			end
			tick += 5
			task.wait(5)
		end
	end)
end

return LobbyBoards
