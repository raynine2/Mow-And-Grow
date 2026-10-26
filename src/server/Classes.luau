-- Buying and equipping classes (gems), for the class stand in the lobby (server/Lobby) and in a run's village
-- (server/Run): the stock rolls every Config.STOCK_WINDOW seconds, and a Restock / Lucky Restock (Robux,
-- server/Monetization) deals a player their own cards until the next roll.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)

local Classes = {}

function Classes.stockWindow(): number
	return math.floor(workspace:GetServerTimeNow() / Config.STOCK_WINDOW)
end

function Classes.inStock(data, classId: string): boolean
	local w = Classes.stockWindow()
	-- a Restock / Lucky Restock bought this window replaces the stand's stock for that player
	local deal = data.classDeal
	if deal and Config.dealActive(deal) then
		return table.find(deal.ids, classId) ~= nil
	end
	-- a few seconds of grace so a click right at the restock still counts
	for _, win in { w, if workspace:GetServerTimeNow() % Config.STOCK_WINDOW < 5 then w - 1 else w } do
		if table.find(Config.classStock(win), classId) then
			return true
		end
	end
	return false
end

function Classes.buy(player: Player, data, id: string)
	local c = Config.class(id)
	if not c or c.gems <= 0 then
		return
	end
	if data.classes[id] then
		Classes.equip(player, data, id)
		return
	end
	if not Classes.inStock(data, id) then
		Net.notify(player, c.name .. " isn't in stock right now. Check back after the restock!", "red")
		return
	end
	if data.gems < c.gems then
		Net.notify(player, "Not enough gems!", "red")
		return
	end
	data.gems -= c.gems
	data.classes[id] = true
	data.class = id
	Stats.applyCharacter(player, data)
	Net.notify(player, "You are now a " .. c.name .. "!", "purple")
	Net.send(player, "Fx", "purchase", { big = true })
	task.spawn(PlayerData.save, player)
end

function Classes.equip(player: Player, data, id: string)
	if type(id) ~= "string" or not data.classes[id] then
		return
	end
	data.class = id
	Stats.applyCharacter(player, data)
	PlayerData.changed(player)
	Net.notify(player, "Equipped " .. (Config.class(id) :: any).name, "green")
end

return Classes
