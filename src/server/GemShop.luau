-- Gem purchases that work in both the lobby and a run: permanent perks and gem mowers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local GemShop = {}

function GemShop.buyPerk(player: Player, data, id: string)
	local p = Config.perk(id)
	if not p then
		return
	end
	local level = data.perks[id] or 0
	local cost = p.costs[level + 1]
	if not cost then
		Net.notify(player, p.name .. " is maxed!", "yellow")
		return
	end
	if data.gems < cost then
		Net.notify(player, "Not enough gems!", "red")
		return
	end
	data.gems -= cost
	data.perks[id] = level + 1
	Net.send(player, "Fx", "purchase", {})
	task.spawn(PlayerData.save, player)
end

function GemShop.buyGemMower(player: Player, data, id: string)
	if Config.MOWERS_LOCKED then -- (30 Oct: no mower can be bought while they're locked, shared/Config MOWERS_LOCKED)
		Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
		return
	end
	local m = Config.mower(id)
	if not m or m.currency ~= "gems" then
		return
	end
	if data.mowers[id] then
		Net.notify(player, "You already own the " .. m.name .. "! Spawn it at the Garage in a run.", "yellow")
		return
	end
	if data.gems < m.price then
		Net.notify(player, "Not enough gems!", "red")
		return
	end
	data.gems -= m.price
	data.mowers[id] = true
	Net.notify(player, m.name .. " is yours forever!", "purple")
	Net.send(player, "Fx", "purchase", { big = true })
	task.spawn(PlayerData.save, player)
end

return GemShop
