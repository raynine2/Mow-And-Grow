-- Creates src/shared/SkillTrees.luau in Studio (a new ModuleScript, exactly git's text). Run in Edit mode.
local src = [=====[
-- WEAPON SKILL TREES: every number (owner, 30 Oct: "an skill tree like chop a forest for every weapon make it super
-- balanced but when u max the skill tree for said weapon make it gold so its like u earned something but make it like
-- balanced but hard to get"). Config.SKILL_TREES is this module. server/SkillTrees runs it, client/SkillTreeWindow
-- draws it. PERMANENT: saved in the profile (profile.skills). Run upgrades (Config.UPGRADES) reset every run; these
-- don't. Pure data and math, no Roblox calls, so tools/skilltrees-test.luau checks it in Lune.
--
-- HOW IT WORKS
--   * Every weapon in Config.TOOLS has a tree: three skills of PIPS pips each (15 pips a tree).
--   * Chopping a clump down with a weapon you own gives THAT weapon POINTS.clump mastery point (an Elder Clump
--     POINTS.elder), if the clump grows in the weapon's own areas or later ones (`from`: an index into Config.ZONES).
--     Only a weapon's own points buy its pips: you master a weapon by using it where it's a match for the grass.
--     Robux can't buy mastery points, and a weapon owned forever with Robux (held from area 1) earns nothing in the
--     easy areas before its own: without `from`, a forever Laser Mower would earn ~1,000 a run instead of ~68 and
--     master its tree in under 2 runs. Cuts made while you drive a ride-on mower count for no weapon.
--   * A pip costs more each time (`mp` below, x1.8 a pip). The top two pips of every skill also cost gems (`gems`).
--   * All 15 pips full = MASTERED: the tree turns gold and server/SkillTrees sets profile.skills.mastered[tool]
--     (SkillTrees.isMastered / onMastered there, for the maxed-weapon ability that comes later).
--
-- WHAT A PIP GIVES (STATS: the same for every weapon, so it reads the same everywhere)
--   power    +4% cutting power (the tool's damage, on grass, bosses and crawlers)   5 pips: +20%
--   speed    -3% time between swings (swing tools)                                  5 pips: -15% (17.6% more swings)
--   width    +3% cutting radius (auto tools)                                        5 pips: +15%
--   harvest  +4% chance that a clump you chop drops one more bundle                 5 pips: +20%
-- Swing tools (Hands, Scissors, Sickle, Mega Scythe) get power / speed / harvest; auto tools (Push Mower, Weed
-- Whacker, Laser Mower) get power / width / harvest.
--
-- BALANCE CHECK (python3 tools/skilltrees_balance.py: tools/balance_model.py's cutting rates, player power 1.0 to
-- 4.0, each tool in the next tool's own area). The tool order holds: a maxed tool doesn't beat the NEXT tool, unmaxed,
-- where that one is made for. Worst case of maxed tool / plain next tool (git's / Studio's tool damage):
--   Hands vs Scissors (Backyard) 0.54x, Scissors vs Sickle (Meadow) 0.83x, Push Mower vs Weed Whacker (Wheat, Blossom)
--   0.56x / 0.74x, Weed Whacker vs Mega Scythe (Swamp, Prairie) 0.16x / 0.25x, Mega Scythe vs Laser Mower (Jungle)
--   1.00x (a tie at one power level, behind at every other).
--   The one close pair is the Sickle and the Push Mower in the Golf Course: a plain Sickle already out-cuts a plain Push
--   Mower there at 29% of power levels (4 targets a swing vs a small circle; the mower's plus is that it needs no
--   clicking); a maxed Sickle at 52% (Studio's damage: 22% / 44%). A maxed Scissors hits for 3.6, a plain Mega Scythe
--   for 2,500.
--   Rejected: +20-25% each with a REACH skill for swing tools (more clumps in range of the multi-target tools: a maxed
--   Mega Scythe out-cut a plain Laser Mower by 44%, a maxed Sickle a plain Push Mower by 74%).
--
-- HOW LONG TO MASTER (aim: ~20 runs of using the weapon where it belongs, 8-12 hours of play; all weapons level up at
-- the same time). Clumps a run in each weapon's own areas (balance model x Config fill): Backyard 130, Meadow 143,
-- Golf 147, Wheat 170, Blossom 111, Swamp 100, Prairie 150, Jungle 68. Runs take 20-36 min.
--   weapon        its areas          mastery a run   whole tree (3 x the mp row)   runs to master   gems for the tree
--   Hands         (Backyard+Meadow)  ~20 / 273*      1,470                        ~75 / 5.4*        105
--   Scissors      Backyard           130             2,640                        20.3              165
--   Sickle        Meadow             143             2,895                        20.2              255
--   Push Mower    Golf               147             2,895                        19.7              420
--   Weed Whacker  Wheat + Blossom    281             5,625                        20.0              630
--   Mega Scythe   Swamp + Prairie    250             4,965                        19.9              930
--   Laser Mower   Jungle             68              1,410                        20.7              1,350
--   (* Hands: ~20 clumps a run before you buy the Scissors, or 273 if you punch the first two areas bare-handed,
--   ~25 min of punching a run: a flex for the dedicated.) All seven trees: 3,855 gems (about 4 runs of gems, spread
--   over ~20). With a gem mower the early weapons only level up if you choose to use them in their areas.
--   mp row = base x 1.8^(pip-1), base = tree total / 67.1 (3 skills x 22.37), rounded to 2 figures.
local SkillTrees = {}

SkillTrees.PIPS = 5
SkillTrees.POINTS = { clump = 1, elder = 20 }

export type Stat = { per: number, what: string, icon: string, sign: number }
SkillTrees.STATS = {
	power = { per = 0.04, what = "cutting power", icon = "up_power", sign = 1 },
	speed = { per = 0.03, what = "time between swings", icon = "up_swing", sign = -1 },
	width = { per = 0.03, what = "cutting width", icon = "ring", sign = 1 },
	harvest = { per = 0.04, what = "extra bundle chance", icon = "bundle", sign = 1 },
} :: { [string]: Stat }

export type Skill = { id: string, name: string, desc: string }
export type Tree = { icon: string, from: number, mp: { number }, gems: { number }, skills: { Skill } }

-- `from`: the first area (Config.ZONES index) whose clumps give this weapon mastery points (its own area; later ones
-- count too). `mp`: mastery points for pip 1..5 of ONE skill (every skill of a weapon costs the same). `gems`: on
-- top, per pip.
SkillTrees.TREES = {
	Hands = {
		icon = "hands",
		from = 1,
		mp = { 20, 40, 70, 130, 230 },
		gems = { 0, 0, 0, 10, 25 },
		skills = {
			{ id = "power", name = "Iron Fists", desc = "Every punch hits harder." },
			{ id = "speed", name = "Quick Hands", desc = "Punch faster." },
			{ id = "harvest", name = "Armful", desc = "A clump you punch down may drop one more bundle." },
		},
	},
	Scissors = {
		icon = "scissors",
		from = 1,
		mp = { 40, 70, 130, 230, 410 },
		gems = { 0, 0, 0, 15, 40 },
		skills = {
			{ id = "power", name = "Sharp Blades", desc = "Every snip cuts deeper." },
			{ id = "speed", name = "Snappy Snips", desc = "Snip faster." },
			{ id = "harvest", name = "Clean Cut", desc = "A clump you snip down may drop one more bundle." },
		},
	},
	Sickle = {
		icon = "sickle",
		from = 2,
		mp = { 45, 80, 140, 250, 450 },
		gems = { 0, 0, 0, 25, 60 },
		skills = {
			{ id = "power", name = "Honed Edge", desc = "Every swing bites deeper." },
			{ id = "speed", name = "Swift Arc", desc = "Swing faster." },
			{ id = "harvest", name = "Gatherer", desc = "A clump you cut down may drop one more bundle." },
		},
	},
	PushMower = {
		icon = "pushmower",
		from = 3,
		mp = { 45, 80, 140, 250, 450 },
		gems = { 0, 0, 0, 40, 100 },
		skills = {
			{ id = "power", name = "Sharper Blade", desc = "The blade cuts harder." },
			{ id = "width", name = "Broad Deck", desc = "Mows a wider circle around you." },
			{ id = "harvest", name = "Grass Catcher", desc = "A clump you mow down may drop one more bundle." },
		},
	},
	WeedWhacker = {
		icon = "whacker",
		from = 4,
		mp = { 85, 150, 270, 490, 880 },
		gems = { 0, 0, 0, 60, 150 },
		skills = {
			{ id = "power", name = "Tough Line", desc = "The spinning line cuts harder." },
			{ id = "width", name = "Long Line", desc = "Whacks a wider circle around you." },
			{ id = "harvest", name = "Clipping Bag", desc = "A clump you whack down may drop one more bundle." },
		},
	},
	MegaScythe = {
		icon = "scythe",
		from = 6,
		mp = { 75, 130, 240, 430, 780 },
		gems = { 0, 0, 0, 90, 220 },
		skills = {
			{ id = "power", name = "Reaper's Edge", desc = "Every sweep cuts harder." },
			{ id = "speed", name = "Reaper's Rhythm", desc = "Sweep faster." },
			{ id = "harvest", name = "Grim Harvest", desc = "A clump you reap may drop one more bundle." },
		},
	},
	LaserMower = {
		icon = "lasermower",
		from = 8,
		mp = { 20, 40, 70, 120, 220 },
		gems = { 0, 0, 0, 130, 320 },
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

-- Does chopping a clump in area `zone` (a Config.ZONES index) give `toolId` mastery points? (Its own areas and later.)
function SkillTrees.earns(toolId: string, zone: any): boolean
	local t = SkillTrees.tree(toolId)
	return t ~= nil and type(zone) == "number" and zone >= t.from
end

-- A stored level as a whole number of pips, 0..PIPS (anything odd in a profile counts as 0).
function SkillTrees.level(levels: any, skillId: string): number
	local n = if type(levels) == "table" then tonumber(levels[skillId]) else nil
	if not n or n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, SkillTrees.PIPS)
end

-- What pip number `pip` (1..PIPS) of any skill of `toolId` costs: mastery points, gems. nil past the last pip.
function SkillTrees.cost(toolId: string, pip: number): (number?, number)
	local t = SkillTrees.tree(toolId)
	if not t or pip < 1 or pip > SkillTrees.PIPS then
		return nil, 0
	end
	return t.mp[pip], t.gems[pip] or 0
end

-- The bonus of `skillId` at `level` pips, as a fraction (0.12 = 12%; for speed it's taken OFF the swing time).
function SkillTrees.value(skillId: string, level: number): number
	local s = SkillTrees.STATS[skillId]
	if not s then
		return 0
	end
	return s.per * math.clamp(level, 0, SkillTrees.PIPS)
end

-- "+12%" / "-9%" for showing a bonus.
function SkillTrees.text(skillId: string, level: number): string
	local s = SkillTrees.STATS[skillId]
	local pct = math.floor(SkillTrees.value(skillId, level) * 100 + 0.5)
	return (if s and s.sign < 0 then "-" else "+") .. pct .. "%"
end

-- The multipliers a weapon's skills give at `levels` ({ [skillId] = pips }).
export type Mults = { damage: number, cooldown: number, radius: number, harvest: number }
function SkillTrees.mults(toolId: string, levels: any): Mults
	local m = { damage = 1, cooldown = 1, radius = 1, harvest = 0 }
	local t = SkillTrees.tree(toolId)
	if not t then
		return m
	end
	for _, s in t.skills do
		local v = SkillTrees.value(s.id, SkillTrees.level(levels, s.id))
		if s.id == "power" then
			m.damage = 1 + v
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
function SkillTrees.isMastered(toolId: string, levels: any): boolean
	local have, total = SkillTrees.pips(toolId, levels)
	return total > 0 and have >= total
end

-- Can the next pip of `skillId` be bought? `tree` is one weapon's part of the profile ({ mp, owned, levels }, as
-- server/SkillTrees keeps it and the client gets it), `gems` the player's gems. Returns: ok, why not ("unknown" |
-- "locked" | "max" | "mp" | "gems"), and the pip's price (mastery points, gems). The server decides with this; the
-- window uses it to colour prices and say why not.
function SkillTrees.check(toolId: string, skillId: string, tree: any, gems: any): (boolean, string?, number?, number)
	if not SkillTrees.skill(toolId, skillId) or type(tree) ~= "table" then
		return false, "unknown", nil, 0
	end
	local mp, gemCost = SkillTrees.cost(toolId, SkillTrees.level(tree.levels, skillId) + 1)
	if tree.owned ~= true then
		return false, "locked", mp, gemCost
	elseif not mp then
		return false, "max", nil, 0
	elseif (tonumber(tree.mp) or 0) < mp then
		return false, "mp", mp, gemCost
	elseif (tonumber(gems) or 0) < gemCost then
		return false, "gems", mp, gemCost
	end
	return true, nil, mp, gemCost
end

-- Mastery points and gems for a whole tree.
function SkillTrees.totalCost(toolId: string): (number, number)
	local t = SkillTrees.tree(toolId)
	if not t then
		return 0, 0
	end
	local mp, gems = 0, 0
	for pip = 1, SkillTrees.PIPS do
		mp += t.mp[pip]
		gems += t.gems[pip] or 0
	end
	return mp * #t.skills, gems * #t.skills
end

return SkillTrees
]=====]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "13436 1485540072" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.ReplicatedStorage.MowALawn
if folder:FindFirstChild("SkillTrees") then
	return "SkillTrees is already there: " .. hashOf(folder.SkillTrees.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "SkillTrees"
m.Source = src
m.Parent = folder
return "SkillTrees installed: " .. hashOf(m.Source)
