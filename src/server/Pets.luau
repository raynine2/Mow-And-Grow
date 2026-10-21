-- Pets: hatching eggs, equipping critters, and their boosts. Works in the lobby and in runs.
-- Equipped pets are mirrored in the player attribute "Pets" (comma list of pet ids) so every client can draw the
-- followers (client/PetFollow); the server never builds pet models.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local Pets = {}
local rng = Random.new()

local function count(data): number
	local n = 0
	for _ in data.pets do
		n += 1
	end
	return n
end

-- The hatch-luck multiplier from the Hatch Luck passes.
function Pets.luck(player: Player): number
	local l = 1
	if player:GetAttribute("Pass_HatchLuck") == true then
		l *= Config.HATCH_LUCK.pass
	end
	if player:GetAttribute("Pass_SuperHatchLuck") == true then
		l *= Config.HATCH_LUCK.super
	end
	return l
end

-- Summed boosts of the equipped pets: { power, sell, speed, luck }.
function Pets.boosts(data): { [string]: number }
	local b = { power = 0, sell = 0, speed = 0, luck = 0 }
	for _, uid in data.petsOn or {} do
		local p = data.pets and Config.pet(data.pets[uid])
		if p then
			for _, k in Config.PET_STATS do
				b[k] += (p :: any)[k] or 0
			end
		end
	end
	return b
end

local function score(id: string): number
	local p = Config.pet(id)
	if not p then
		return 0
	end
	local s = 0
	for _, k in Config.PET_STATS do
		s += (p :: any)[k] or 0
	end
	return s
end

function Pets.publish(player: Player, data)
	local ids = {}
	for _, uid in data.petsOn do
		if data.pets[uid] then
			table.insert(ids, data.pets[uid])
		end
	end
	player:SetAttribute("Pets", table.concat(ids, ","))
end

local function afterChange(player: Player, data)
	Pets.publish(player, data)
	-- walk speed may have changed
	local Stats = require(script.Parent.Stats) :: any
	Stats.applyCharacter(player, data)
	PlayerData.changed(player)
end

-- Hatch `n` eggs into the profile. `paid` = Robux eggs (never refused for a full inventory: we already took the
-- money). Returns the hatched pet ids, or nil when refused. A new pet is equipped while there is a free slot.
function Pets.hatch(player: Player, data, eggId: string, n: number, paid: boolean): { string }?
	local egg = Config.egg(eggId)
	if not egg or n < 1 then
		return nil
	end
	if not paid and count(data) + n > Config.PET_MAX then
		Net.notify(player, "Your pet bag is full! (" .. Config.PET_MAX .. ")", "red")
		return nil
	end
	local luck = Pets.luck(player)
	local got = {}
	for _ = 1, n do
		local id = Config.rollEgg(egg, luck, rng)
		local uid = "p" .. data.petNext
		data.petNext += 1
		data.pets[uid] = id
		if #data.petsOn < Config.PET_EQUIP then
			table.insert(data.petsOn, uid)
		end
		table.insert(got, id)
	end
	afterChange(player, data)
	Net.send(player, "Fx", "hatch", { egg = eggId, pets = got })
	return got
end

local function equip(player: Player, data, uid: string)
	if not data.pets[uid] or table.find(data.petsOn, uid) then
		return
	end
	if #data.petsOn >= Config.PET_EQUIP then
		Net.notify(player, "You can only take " .. Config.PET_EQUIP .. " pets with you!", "red")
		return
	end
	table.insert(data.petsOn, uid)
	afterChange(player, data)
end

local function unequip(player: Player, data, uid: string)
	local i = table.find(data.petsOn, uid)
	if i then
		table.remove(data.petsOn, i)
		afterChange(player, data)
	end
end

local function equipBest(player: Player, data)
	local uids = {}
	for uid in data.pets do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		return score(data.pets[a]) > score(data.pets[b])
	end)
	table.clear(data.petsOn)
	for i = 1, math.min(Config.PET_EQUIP, #uids) do
		table.insert(data.petsOn, uids[i])
	end
	afterChange(player, data)
end

local started = false
function Pets.start()
	if started then
		return
	end
	started = true
	Net.on("Hatch", 3, function(player, eggId, n)
		local data = PlayerData.get(player)
		local egg = type(eggId) == "string" and Config.egg(eggId)
		if not data or not egg or egg.currency ~= "gems" or (n ~= 1 and n ~= 3) then
			return
		end
		local cost = egg.price * n
		if data.gems < cost then
			Net.notify(player, "Not enough gems!", "red")
			return
		end
		if count(data) + n > Config.PET_MAX then
			Net.notify(player, "Your pet bag is full! (" .. Config.PET_MAX .. ")", "red")
			return
		end
		data.gems -= cost
		Pets.hatch(player, data, egg.id, n, false)
	end)
	Net.on("Pet", 6, function(player, action, uid)
		local data = PlayerData.get(player)
		if not data or type(action) ~= "string" then
			return
		end
		if action == "best" then
			equipBest(player, data)
		elseif type(uid) == "string" then
			if action == "equip" then
				equip(player, data, uid)
			elseif action == "unequip" then
				unequip(player, data, uid)
			end
		end
	end)
	PlayerData.onLoaded(function(player, data)
		Pets.publish(player, data)
	end)
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data then
			Pets.publish(p, data)
		end
	end
end

return Pets
