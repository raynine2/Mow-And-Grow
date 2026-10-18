-- Turns a profile (class + perks + run upgrades + passes) into the numbers the game uses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)

local Stats = {}

-- Game pass ownership is cached per player by Monetization; it sets these attributes on the player.
local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function Stats.compute(player: Player, data)
	local class = Config.class(data.class) or Config.class(Config.DEFAULT_CLASS)
	local run = data.run
	local up = if run then run.upgrades else { power = 0, carry = 0, speed = 0, sell = 0 }
	local vip = hasPass(player, "VIP")

	local s = {}
	s.power = (1 + (class.power or 0) + up.power * Config.upgrade("power").per) * (if vip then 1.15 else 1)
	s.carry = Config.BASE_CARRY
		+ (class.carry or 0)
		+ up.carry * Config.upgrade("carry").per
		+ (if hasPass(player, "BigBag") then 10 else 0)
	s.walkSpeed = 16 * (1 + (class.speed or 0) + up.speed * Config.upgrade("speed").per)
	s.sell = (1 + (class.sell or 0) + data.perks.sell * Config.perk("sell").per + up.sell * Config.upgrade("sell").per)
		* (if hasPass(player, "DoubleCoins") then 2 else 1)
		* (if vip then 1.15 else 1)
	s.luck = 1 + (class.luck or 0) + data.perks.luck * Config.perk("luck").per
	s.bundle = data.perks.bundle * Config.perk("bundle").per -- chance of a double bundle
	s.gems = (1 + data.perks.gem * Config.perk("gem").per) * (if hasPass(player, "DoubleGems") then 2 else 1)
	return s
end

-- Apply walk speed to the character (unless it's stunned by a boss).
function Stats.applyCharacter(player: Player, data)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and not char:GetAttribute("Stunned") then
		hum.WalkSpeed = Stats.compute(player, data).walkSpeed
	end
end

return Stats
