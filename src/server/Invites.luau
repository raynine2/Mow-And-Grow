--!strict
-- INVITES (1 Nov, owner: "mensen invite give you a friends boost of reward", and he picked "invite reward only").
-- The INVITE button (client/Hud, in the lobby) opens Roblox's invite-friends prompt. When someone who has never
-- played joins from your invite (their join data's ReferredByPlayerId), you get Config.INVITE.gems once for them and
-- they get Config.INVITE.welcomeGems. If you're in another server by then (a private run, say), the reward waits in a
-- DataStore and lands the next time you're in a server where your profile loads.
-- Guards: each friend pays out once ever, their account must be at least Config.INVITE.minAccountAge days old, and
-- at most Config.INVITE.perDay friends pay out a day.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local Invites = {}

local CFG = (Config :: any).INVITE or { gems = 150, welcomeGems = 50, perDay = 10, minAccountAge = 3 }
local store: DataStore? = nil
if not game:GetService("RunService"):IsStudio() then -- (Studio tests never touch the live invite list)
	pcall(function()
		store = DataStoreService:GetDataStore("MowALawn_Invites_v1")
	end)
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Pay the inviter for one friend. False when they were already paid for that friend or hit today's limit.
local function pay(inviter: Player, data: any, friendId: number, friendName: string): boolean
	data.invited = data.invited or {}
	local key = tostring(friendId)
	if data.invited[key] then
		return false
	end
	if data.inviteDay ~= today() then
		data.inviteDay = today()
		data.inviteToday = 0
	end
	if (data.inviteToday or 0) >= CFG.perDay then
		return false
	end
	data.invited[key] = os.time()
	data.inviteToday = (data.inviteToday or 0) + 1
	data.gems += CFG.gems
	data.stats.invites = (data.stats.invites or 0) + 1
	PlayerData.changed(inviter)
	Net.notify(inviter, friendName .. " joined from your invite! +" .. CFG.gems .. " gems", "gold")
	return true
end

-- Rewards that waited for you while you were in another server: taken off the list, then paid.
local function collect(player: Player, data: any)
	if not store then
		return
	end
	local waiting: { any }? = nil
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync("pending_" .. player.UserId, function(old)
			if type(old) ~= "table" or #old == 0 then
				waiting = nil
				return nil -- (nothing waiting: no write)
			end
			waiting = old
			return {}
		end)
	end)
	if ok and waiting then
		for _, e in waiting :: { any } do
			if type(e) == "table" and tonumber(e.id) then
				pay(player, data, tonumber(e.id) :: number, tostring(e.name or "A friend"))
			end
		end
	end
end

-- Leave a reward for an inviter who isn't in this server.
local function leave(inviterId: number, friendId: number, friendName: string)
	if not store then
		return
	end
	pcall(function()
		(store :: DataStore):UpdateAsync("pending_" .. inviterId, function(old)
			local list = if type(old) == "table" then old else {}
			if #list >= 50 then
				return nil
			end
			for _, e in list do
				if type(e) == "table" and e.id == friendId then
					return nil
				end
			end
			table.insert(list, { id = friendId, name = friendName, t = os.time() })
			return list
		end)
	end)
end

local function loaded(player: Player, data: any)
	if not data then
		return
	end
	collect(player, data)
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	local by = if ok and type(join) == "table" then tonumber(join.ReferredByPlayerId) or 0 else 0
	if by <= 0 or by == player.UserId or data.referredBy ~= nil then
		return
	end
	-- only friends who are new to the game count, on accounts that aren't brand new
	if not PlayerData.isNew(data) or player.AccountAge < CFG.minAccountAge then
		return
	end
	data.referredBy = by
	data.gems += CFG.welcomeGems
	PlayerData.changed(player)
	Net.notify(player, "Welcome! A friend invited you: +" .. CFG.welcomeGems .. " gems", "gold")
	local inviter = Players:GetPlayerByUserId(by)
	local idata = inviter and PlayerData.get(inviter)
	if inviter and idata then
		pay(inviter, idata, player.UserId, player.DisplayName)
	else
		task.spawn(leave, by, player.UserId, player.DisplayName)
	end
end

function Invites.start()
	PlayerData.onLoaded(loaded)
end

return Invites
