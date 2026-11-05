-- (5 Nov) EMOTES (owner: "a button / key (G) with 6 silly emotes ... make your friends laugh"). A client asks for an
-- emote on the "Emote" remote; this checks it (a real id from Config.EMOTES.list, the cooldown, alive, on foot, not in
-- a boss fight) and tells every client (player, id, server time it started). Each client poses that character by code
-- (client/Emotes): Motor6D.Transform doesn't replicate, so nothing else goes over the network. Moving cancels an
-- emote on every screen by itself (each client watches the character), so there is no "stop" message.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)

local Emotes = {}

local lastAt: { [Player]: number } = {}

local function known(id: any): boolean
	local E = Config.EMOTES
	if type(id) ~= "string" or #id > 24 or not E then
		return false
	end
	for _, e in E.list do
		if e.id == id then
			return true
		end
	end
	return false
end

local function canEmote(player: Player): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not hum.RootPart then
		return false
	end
	if hum.SeatPart or hum.Sit then
		return false -- (riding a mower: client/RiderPose has the body)
	end
	if player:GetAttribute("BossHP") ~= nil then
		return false -- (in a boss fight: server/BossFighters)
	end
	return true
end

function Emotes.start()
	Net.on("Emote", 2, function(player, id)
		local E = Config.EMOTES
		if not E or E.on == false or not known(id) or not canEmote(player) then
			return
		end
		local now = os.clock()
		if now - (lastAt[player] or -math.huge) < (E.cooldown or 4) - 0.25 then
			return -- (a quarter of a second of slack for network jitter)
		end
		lastAt[player] = now
		Net.all("Emote", player, id, workspace:GetServerTimeNow())
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastAt[p] = nil
	end)
end

return Emotes
