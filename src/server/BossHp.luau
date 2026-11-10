--!strict
-- BOSS HP FIT (10 Nov 2026, owner: "bosses hp need to change because boss can take up to 10 min players will
-- litterly leave fix every hp with every boss ... chapter 1 shoudnt be that hard but also not too easy").
--
-- Why fights got so long: the boss HP (Config.BOSS_HP) was set on 29 Oct for fights where the free gun did most of the
-- damage (2% of the boss's max HP a second). The guns went on 7 Nov (Config.GUNS_ON = false) and only the tools hurt
-- the bosses since, so a player one tool behind took 5-15 minutes. Config.BOSS_HP is retuned for tools only, and on
-- top of that this caps a fight's HP at what the fighters' own weapons can do in Config.BOSS_FIT.maxTime: whoever
-- comes in under-geared (Bare Hands at the Harvest Maw, a Weed Whacker at the Frost Thornback) still gets a fight of
-- a few minutes, never ten. The cap never goes below `floor` x the HP, so skipping your tools doesn't make a boss a
-- pushover, and it never adds HP: a strong player still feels strong.
--
-- A fighter's damage a second = their best weapon this run (run.tool, with its skill tree, server/SkillTrees.boost)
-- x their power (class + pets + VIP, server/Stats), swing tools every cooldown x Swing Speed x 0.85 (server/Run's
-- swing check), auto tools every Config.TICK; x `share`, the part of a fight you're actually hitting (dodging,
-- walking up, stuns). The weak-spot windows (x2.5) and the pets' chip come on top, so real fights end sooner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)

local BossHp = {}

-- one fighter's damage a second against a boss with the weapon they'd bring (0 if unknown)
function BossHp.dps(player: Player): number
	local ok, v = pcall(function()
		local PlayerData = require(script.Parent.PlayerData) :: any
		local data = PlayerData.get(player)
		if not data or type(data.run) ~= "table" then
			return 0
		end
		local i = math.clamp(tonumber(data.run.tool) or 1, 1, #Config.TOOLS)
		local def = require(script.Parent.SkillTrees).boost(player, Config.TOOLS[i], nil)
		local stats = require(script.Parent.Stats).compute(player, data)
		local hit = def.damage * stats.power * Config.BOSS_TOOL_MULT
		if def.kind == "swing" then
			return hit / math.max(0.05, (def.cooldown or 0.45) * (stats.swing or 1) * 0.85)
		end
		return hit / Config.TICK
	end)
	return if ok and type(v) == "number" and v == v then v else 0
end

-- `hp` (the boss's HP for this party and difficulty), limited to what `fighters` can take off in maxTime x the
-- difficulty's HP multiplier (`hard`: Hard and Expert fights may run longer), but never under floor x hp
function BossHp.fit(hp: number, fighters: { Player }, hard: number?): number
	local F = Config.BOSS_FIT
	if type(F) ~= "table" or not F.on or #fighters == 0 then
		return hp
	end
	local dps = 0
	for _, p in fighters do
		dps += BossHp.dps(p)
	end
	if dps <= 0 then
		return hp
	end
	local most = dps * F.share * F.maxTime * math.max(1, hard or 1)
	return math.floor(math.clamp(most, hp * F.floor, hp) + 0.5)
end

return BossHp
