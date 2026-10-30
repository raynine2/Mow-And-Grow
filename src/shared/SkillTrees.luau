-- WEAPON SKILL TREES: every number (owner, 30 Oct: "an skill tree like chop a forest for every weapon make it super
-- balanced but when u max the skill tree for said weapon make it gold so its like u earned something"; then, on
-- seeing it: the pips reset every run and cost coins, MASTERED stays forever, the trees replace the Upgrades
-- window's "Tool" section). Config.SKILL_TREES is this module. server/SkillTrees runs it, client/SkillTreeWindow
-- draws it. Pure data and math, no Roblox calls, so tools/skilltrees-test.luau checks it in Lune.
--
-- HOW IT WORKS
--   * Every weapon in Config.TOOLS has a tree: three skills of PIPS pips each (15 pips a tree), bought one pip at a
--     time with the RUN's coins, like the run upgrades (Config.UPGRADES), and gone when the run ends (run.skills).
--   * Only your best weapon learns (the newest one you own this run, run.tool): a weapon you've moved on from keeps
--     its pips but takes no more, and one you don't own this run is LOCKED. (Income grows ~4x an area: without this,
--     a late run's pocket money would fill the early weapons' trees.)
--   * At most MAX_FULL_PER_RUN trees can be filled in one run, so maxing every tree in a run is impossible whatever
--     a player earns (the 2x Coins pass, perks and a top class make ~6x a new player's coins).
--   * The first time all 15 pips of a weapon are full, it is MASTERED for good (profile.skills.mastered): its page
--     stays gold in every later run, even at 0 pips. Banner and confetti only that first time.
--
-- WHAT A PIP GIVES (STATS: the same for every weapon)
--   power    +32% power with this weapon (5 pips: +160%), added to class + pet power exactly like the old "Tool"
--            section's Power upgrade (+20% a level, 10 levels, +200%), which it replaces for the tools
--   speed    -3% time between swings (swing tools; 5 pips: -15%, on top of the Hands section's Swing Speed)
--   width    +3% cutting radius (auto tools; 5 pips: +15%)
--   harvest  +4% chance that a clump you chop drops one more bundle (5 pips: +20%)
-- Swing tools (Hands, Scissors, Sickle, Mega Scythe): power / speed / harvest; auto tools (Push Mower, Weed Whacker,
-- Laser Mower): power / width / harvest. A maxed tree cuts about as hard as the old Power upgrade at level 10
-- (new player, power 1.05: x2.52 power x1.18 swings = x2.97 vs the old x2.90; class power 1.0: x2.12 vs x2.0). The
-- old upgrade also powered ride-on mowers: that part stays in the Mower section as "Mower Blades" (server/Stats
-- mowerPower), so mowers, the Robux Rocket Mower too, cut as before.
--
-- PRICES (python3 tools/skilltrees_balance.py: tools/balance_model.py's run economy with these trees in it)
--   Coins a fresh run earns in each weapon's areas (its "phase"): Backyard ~770 (Hands, Scissors), Meadow ~3,400
--   (Sickle), Golf ~14,000 (Push Mower), Wheat + Blossom ~245,000 (Weed Whacker), Swamp + Prairie ~3.5M (Mega
--   Scythe), Jungle ~13M (Laser Mower); a whole run ~17M, a Goat Man ~26M, a 2x Coins Goat Man ~54M.
--   A tree costs 2x its phase's coins (the Laser 1x: nothing comes after the Jungle, and nothing can be bought after
--   its boss), a pip x3 the one before (pip n of a skill = base x 3^(n-1), base = tree / 363, rounded), so the first
--   pips are cheap (a typical run buys ~9-12 of a weapon's 15 pips and keeps the old pacing: fresh run 37.1 min vs
--   36.2 before, Goat Man 22.0 vs 22.5, five runs in 22.2 vs 22.4; mower runs within ~1.3 min) and the last ones are
--   dear: no tree is filled by accident (fresh, Goat Man, a five-runs-in Grass Titan). Filling one is a run's goal:
--   buy its pips before the next tool, and it fills around the end of the weapon's areas or early in the next (the
--   next area pays ~4x), costing a fresh run 0-9 min; the Laser in the Jungle for a dedicated Goat Man, never in a
--   first run. Only 2x Coins / whale players fill the Laser in a normal run (nothing else to buy at the end).
--   Without MAX_FULL_PER_RUN a player filling every tree before moving on would fill 6 (7 with 2x Coins).
--   Tool order (worst case, player power 1-4, in the next tool's areas): with the same pips the next tool always
--   out-cuts the one before (0.18-0.78x), but the Sickle / Push Mower pair, which already overlaps with no skills
--   (1.28x; 1.16x both maxed; a maxed Sickle vs a plain Push Mower 1.45x). A maxed tree vs the next tool at 0 pips:
--   Hands 0.54x, Scissors 0.83x, Push Mower 0.56x (Studio's damage 0.74x), Weed Whacker 0.21x (0.32x), Mega Scythe
--   1.94x: a new Laser Mower needs 5 pips (power 3, width 2: 612,000 coins, 8.6% of a maxed Scythe tree) to out-cut
--   a maxed Scythe in the Jungle (a typical run reaches the Laser with ~11 Scythe pips, not 15).
local SkillTrees = {}

SkillTrees.PIPS = 5
SkillTrees.MAX_FULL_PER_RUN = 1 -- trees that may be filled (every pip) in one run; raise it to allow more

export type Stat = { per: number, what: string, icon: string, sign: number }
SkillTrees.STATS = {
	power = { per = 0.32, what = "cutting power", icon = "up_power", sign = 1 },
	speed = { per = 0.03, what = "time between swings", icon = "up_swing", sign = -1 },
	width = { per = 0.03, what = "cutting width", icon = "ring", sign = 1 },
	harvest = { per = 0.04, what = "extra bundle chance", icon = "bundle", sign = 1 },
} :: { [string]: Stat }

export type Skill = { id: string, name: string, desc: string }
export type Tree = { icon: string, coins: { number }, skills: { Skill } }

-- `coins`: the price of pip 1..5 of ONE skill (every skill of a weapon costs the same).
SkillTrees.TREES = {
	Hands = {
		icon = "hands",
		coins = { 5, 15, 40, 110, 340 },
		skills = {
			{ id = "power", name = "Iron Fists", desc = "Every punch hits harder." },
			{ id = "speed", name = "Quick Hands", desc = "Punch faster." },
			{ id = "harvest", name = "Armful", desc = "A clump you punch down may drop one more bundle." },
		},
	},
	Scissors = {
		icon = "scissors",
		coins = { 5, 15, 40, 110, 340 },
		skills = {
			{ id = "power", name = "Sharp Blades", desc = "Every snip cuts deeper." },
			{ id = "speed", name = "Snappy Snips", desc = "Snip faster." },
			{ id = "harvest", name = "Clean Cut", desc = "A clump you snip down may drop one more bundle." },
		},
	},
	Sickle = {
		icon = "sickle",
		coins = { 20, 55, 170, 510, 1500 },
		skills = {
			{ id = "power", name = "Honed Edge", desc = "Every swing bites deeper." },
			{ id = "speed", name = "Swift Arc", desc = "Swing faster." },
			{ id = "harvest", name = "Gatherer", desc = "A clump you cut down may drop one more bundle." },
		},
	},
	PushMower = {
		icon = "pushmower",
		coins = { 80, 230, 700, 2100, 6300 },
		skills = {
			{ id = "power", name = "Sharper Blade", desc = "The blade cuts harder." },
			{ id = "width", name = "Broad Deck", desc = "Mows a wider circle around you." },
			{ id = "harvest", name = "Grass Catcher", desc = "A clump you mow down may drop one more bundle." },
		},
	},
	WeedWhacker = {
		icon = "whacker",
		coins = { 1300, 4000, 12000, 36000, 110000 },
		skills = {
			{ id = "power", name = "Tough Line", desc = "The spinning line cuts harder." },
			{ id = "width", name = "Long Line", desc = "Whacks a wider circle around you." },
			{ id = "harvest", name = "Clipping Bag", desc = "A clump you whack down may drop one more bundle." },
		},
	},
	MegaScythe = {
		icon = "scythe",
		coins = { 19000, 58000, 170000, 520000, 1600000 },
		skills = {
			{ id = "power", name = "Reaper's Edge", desc = "Every sweep cuts harder." },
			{ id = "speed", name = "Reaper's Rhythm", desc = "Sweep faster." },
			{ id = "harvest", name = "Grim Harvest", desc = "A clump you reap may drop one more bundle." },
		},
	},
	LaserMower = {
		icon = "lasermower",
		coins = { 36000, 110000, 320000, 970000, 2900000 },
		skills = {
			{ id = "power", name = "Overcharge", desc = "The lasers burn hotter." },
			{ id = "width", name = "Wide Beam", desc = "Cuts a wider circle around you." },
			{ id = "harvest", name = "Tractor Beam", desc = "A clump you laser down may drop one more bundle." },
		},
	},
} :: { [string]: Tree }

function SkillTrees.tree(toolId: any): Tree?
	if type(toolId) ~= "string" then
		return nil
	end
	return SkillTrees.TREES[toolId]
end

function SkillTrees.skill(toolId: any, skillId: any): Skill?
	local t = SkillTrees.tree(toolId)
	if not t or type(skillId) ~= "string" then
		return nil
	end
	for _, s in t.skills do
		if s.id == skillId then
			return s
		end
	end
	return nil
end

-- A stored level as a whole number of pips, 0..PIPS (anything odd in a run counts as 0).
function SkillTrees.level(levels: any, skillId: string): number
	local n = if type(levels) == "table" then tonumber(levels[skillId]) else nil
	if not n or n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, SkillTrees.PIPS)
end

-- The coins pip number `pip` (1..PIPS) of any skill of `toolId` costs; nil past the last pip.
function SkillTrees.cost(toolId: string, pip: number): number?
	local t = SkillTrees.tree(toolId)
	if not t or pip < 1 or pip > SkillTrees.PIPS then
		return nil
	end
	return t.coins[pip]
end

-- The bonus of `skillId` at `level` pips, as a fraction (0.32 = +32%; for speed it's taken OFF the swing time).
function SkillTrees.value(skillId: string, level: number): number
	local s = SkillTrees.STATS[skillId]
	if not s then
		return 0
	end
	return s.per * math.clamp(level, 0, SkillTrees.PIPS)
end

-- "+64%" / "-9%" for showing a bonus.
function SkillTrees.text(skillId: string, level: number): string
	local s = SkillTrees.STATS[skillId]
	local pct = math.floor(SkillTrees.value(skillId, level) * 100 + 0.5)
	return (if s and s.sign < 0 then "-" else "+") .. pct .. "%"
end

-- What a weapon's skills give at `levels` ({ [skillId] = pips }): `power` is added to the player's power (like the
-- old Power upgrade's levels: server/SkillTrees.boost turns it into the tool's damage), the rest are multipliers.
export type Mults = { power: number, cooldown: number, radius: number, harvest: number }
function SkillTrees.mults(toolId: string, levels: any): Mults
	local m = { power = 0, cooldown = 1, radius = 1, harvest = 0 }
	local t = SkillTrees.tree(toolId)
	if not t then
		return m
	end
	for _, s in t.skills do
		local v = SkillTrees.value(s.id, SkillTrees.level(levels, s.id))
		if s.id == "power" then
			m.power = v
		elseif s.id == "speed" then
			m.cooldown = 1 - v
		elseif s.id == "width" then
			m.radius = 1 + v
		elseif s.id == "harvest" then
			m.harvest = v
		end
	end
	return m
end

-- The damage multiplier for a tool whose tree gives `treePower`, for a player whose power is `power` (class + pets,
-- x VIP: server/Stats) and VIP factor `vip`: the tree's power is ADDED to the player's, as the old upgrade's was,
-- so the hit is def.damage x (power + treePower x vip) (a strong class doesn't multiply it up).
function SkillTrees.damageMult(treePower: number, power: number, vip: number?): number
	if treePower <= 0 or power <= 0 then
		return 1
	end
	return 1 + treePower * (vip or 1) / power
end

-- Pips filled and pips in all of a weapon's tree.
function SkillTrees.pips(toolId: string, levels: any): (number, number)
	local t = SkillTrees.tree(toolId)
	if not t then
		return 0, 0
	end
	local have = 0
	for _, s in t.skills do
		have += SkillTrees.level(levels, s.id)
	end
	return have, #t.skills * SkillTrees.PIPS
end

-- Every pip of the weapon's tree is full.
function SkillTrees.isFull(toolId: string, levels: any): boolean
	local have, total = SkillTrees.pips(toolId, levels)
	return total > 0 and have >= total
end

-- How many weapons' trees are full in a run's pips ({ [toolId] = levels }).
function SkillTrees.fullCount(runSkills: any): number
	local n = 0
	if type(runSkills) == "table" then
		for id, levels in runSkills do
			if SkillTrees.isFull(id, levels) then
				n += 1
			end
		end
	end
	return n
end

-- Can the next pip of `skillId` be bought? `state` describes the weapon in this run: { levels, owned (in this run),
-- best (it's the best weapon you own: only it learns), coins (the run's), runSkills (every weapon's pips, for the
-- one-full-tree rule), inRun }. Returns ok, why not ("unknown" | "lobby" | "locked" | "past" | "max" | "oneARun" |
-- "coins"), and the pip's price. The server decides with this; the window colours prices and says why not with it.
function SkillTrees.check(toolId: string, skillId: string, state: any): (boolean, string?, number?)
	if not SkillTrees.skill(toolId, skillId) or type(state) ~= "table" then
		return false, "unknown", nil
	end
	local levels = state.levels
	local level = SkillTrees.level(levels, skillId)
	local price = SkillTrees.cost(toolId, level + 1)
	if state.inRun ~= true then
		return false, "lobby", price
	elseif state.owned ~= true then
		return false, "locked", price
	elseif not price then
		return false, "max", nil
	elseif state.best ~= true then
		return false, "past", price
	end
	-- the pip that would fill this tree: only if fewer than MAX_FULL_PER_RUN trees are full this run already
	local have, total = SkillTrees.pips(toolId, levels)
	if have + 1 >= total and SkillTrees.fullCount(state.runSkills) >= SkillTrees.MAX_FULL_PER_RUN then
		return false, "oneARun", price
	end
	if (tonumber(state.coins) or 0) < price then
		return false, "coins", price
	end
	return true, nil, price
end

-- The coins for a whole tree.
function SkillTrees.totalCost(toolId: string): number
	local t = SkillTrees.tree(toolId)
	if not t then
		return 0
	end
	local sum = 0
	for pip = 1, SkillTrees.PIPS do
		sum += t.coins[pip]
	end
	return sum * #t.skills
end

return SkillTrees
