-- Turns a profile (class + perks + run upgrades + passes) into the numbers the game uses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)

local Stats = {}
-- (owner, 29 Oct) the run's difficulty reward (Config.DIFFICULTY[...].reward): coins and gems x this. Set by server/Run.
Stats.reward = 1

-- Game pass ownership is cached per player by Monetization; it sets these attributes on the player.
local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function Stats.compute(player: Player, data)
	local class = Config.class(data.class) or Config.class(Config.DEFAULT_CLASS)
	local run = data.run
	local up = if run then run.upgrades else {}
	local function level(id: string): number
		return up[id] or 0
	end
	local function per(id: string): number
		local u = Config.upgrade(id)
		return if u then u.per else 0
	end
	local vip = hasPass(player, "VIP")
	local bag = run and Config.BAGS[run.bag or 0]
	-- equipped pets (server/Pets): summed boosts
	local pet = { power = 0, sell = 0, speed = 0, luck = 0 }
	for _, uid in data.petsOn or {} do
		local p = data.pets and Config.pet(data.pets[uid])
		if p then
			for _, k in Config.PET_STATS do
				pet[k] += (p :: any)[k] or 0
			end
		end
	end

	local s = {}
	s.power = (1 + (class.power or 0) + pet.power) * (if vip then 1.15 else 1)
	s.mowerPower = (1 + (class.power or 0) + pet.power + level("power") * per("power")) * (if vip then 1.15 else 1) -- (30 Oct) ride-on mowers keep the old Power upgrade ("Mower Blades"); the tools get theirs from their skill trees (server/SkillTrees)
	s.carry = Config.BASE_CARRY
		+ (class.carry or 0)
		+ (if bag then bag.carry else 0)
		+ level("carry") * Config.LEGACY_CARRY_PER -- Backpack upgrade levels bought before bags existed
	if hasPass(player, "BigBag") then
		s.carry = Config.ENDLESS_CARRY -- the Bottomless Sack
	end
	s.walkSpeed = 16 * (1 + (class.speed or 0) + pet.speed + level("speed") * per("speed"))
	-- pickup reach (studs) and the swing cooldown multiplier
	s.grasp = (Config.LOOT.grasp + level("grasp") * per("grasp")) * (if run and run.vacuum then Config.VACUUM.graspMult else 1)
	s.swing = math.max(0.4, 1 - level("swing") * per("swing"))
	s.sell = (1 + (class.sell or 0) + pet.sell + data.perks.sell * Config.perk("sell").per + level("sell") * per("sell"))
		* (if hasPass(player, "DoubleCoins") then 2 else 1)
		* (if vip then 1.15 else 1)
	s.luck = 1 + (class.luck or 0) + pet.luck + data.perks.luck * Config.perk("luck").per
	s.bundle = data.perks.bundle * Config.perk("bundle").per -- chance of a double bundle
		+ (if hasPass(player, "DoubleClippings") then 1 else 0) -- 2x Clippings: always double
	s.gems = (1 + data.perks.gem * Config.perk("gem").per) * (if hasPass(player, "DoubleGems") then 2 else 1)
	if run then
		-- (29 Oct, owner: "party bonus") more coins from grass for every other player in the run
		local pb = Config.PARTY_BONUS
		if pb then
			s.sell *= 1 + math.min(pb.max, pb.per * math.max(0, #Players:GetPlayers() - 1))
		end
		-- (29 Oct, owner: "Golden Hour") mutation luck x Config.GOLDEN_HOUR.luck while it lasts (server/RunEvents)
		local gh = Config.GOLDEN_HOUR
		local goldenUntil = workspace:GetAttribute("GoldenHourUntil")
		if gh and type(goldenUntil) == "number" and workspace:GetServerTimeNow() < goldenUntil then
			s.luck *= gh.luck
		end
	end
	-- (29 Oct) Hard pays +50%, Expert +100% (in a run only)
	if run then
		s.sell *= Stats.reward
		s.gems *= Stats.reward
	end
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
