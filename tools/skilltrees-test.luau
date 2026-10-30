-- Checks the weapon skill trees in Lune:   lune run tools/skilltrees-test.luau
--   * src/shared/SkillTrees.luau (pure Luau): every weapon in Config.TOOLS has a tree that fits its kind, coin prices
--     that climb ~x3 a pip and match the header's totals (2x each weapon's phase coins, the Laser 1x), bonuses that
--     keep a maxed tree close to the old "Tool" section's Power upgrade, and a buy rule that says yes / no for the
--     right reasons (lobby, locked, past, max, one full tree a run, coins).
--   * the hooks in other files: the "Tool" section is gone from Config.UPGRADES (its Power is "Mower Blades" in the
--     Mower section), PlayerData.newRun has run.skills, Stats has mowerPower and Run's mowers use it.
--   * src/server/SkillTrees.luau, run against stand-ins for Roblox: an old profile and an old saved run load, pips
--     are bought with the run's coins and only for the best weapon, one tree fills a run, the first full tree masters
--     the weapon for good (celebration once), a new run starts with no pips but keeps MASTERED, the held tool gets its
--     numbers, Harvest drops a bundle, and a half-done Studio copy turns the trees off without breaking anything.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Tree = require("../src/shared/SkillTrees")

local failed, passed = 0, 0
local function check(ok: any, what: string)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. what)
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) < (eps or 1e-9)
end

-- Config.TOOLS, read from the source (Config itself needs Roblox), in shop order
local config = fs.readFile("src/shared/Config.luau")
local block = string.match(config, "Config%.TOOLS = (%b{})")
check(block ~= nil, "found Config.TOOLS")
local defs = {}
for id, kind in string.gmatch(block or "", '{ id = "(%w+)",[^\n]-kind = "(%w+)"') do
	local line = string.match(block or "", '{ id = "' .. id .. '",[^\n]*')
	table.insert(defs, {
		id = id,
		kind = kind,
		name = string.match(line, 'name = "([^"]+)"'),
		damage = tonumber(string.match(line, "damage = ([%d.]+)")),
		cooldown = tonumber(string.match(line, "cooldown = ([%d.]+)")),
		radius = tonumber(string.match(line, "radius = ([%d.]+)")),
	})
end
check(#defs == 7, "Config.TOOLS has 7 weapons (found " .. #defs .. ")")

-------------------------------------------------------------------------------------------------------------
-- the hooks in the shared files (git's copies; tools/studio-patches/2026-10-30-skill-trees makes the same in Studio)
-------------------------------------------------------------------------------------------------------------
check(string.find(config, 'Config.SKILL_TREES = require(script.Parent:WaitForChild("SkillTrees"))', 1, true) ~= nil, "Config requires the module")
check(string.find(config, 'Config.UPGRADE_SECTIONS = { "Hands", "Gear", "Mower" }', 1, true) ~= nil, "the upgrades window has no Tool section")
check(string.find(config, 'section = "Tool"', 1, true) == nil, "no upgrade is in the Tool section")
local powerLine = string.match(config, '\n\t{ id = "power",[^\n]*') or ""
check(string.find(powerLine, 'section = "Mower", name = "Mower Blades"', 1, true) ~= nil, "the old Power upgrade is the Mower section's Mower Blades (same id)")
check(string.find(powerLine, "per = 0.20, base = 100, growth = 3.2, max = 10", 1, true) ~= nil, "Mower Blades keeps the old numbers")
local playerData = fs.readFile("src/server/PlayerData.luau")
check(string.find(playerData, "\n\t\tskills = {}, --", 1, true) ~= nil, "PlayerData.newRun has run.skills")
local stats = fs.readFile("src/server/Stats.luau")
check(string.find(stats, 's.power = (1 + (class.power or 0) + pet.power) * (if vip then 1.15 else 1)', 1, true) ~= nil, "Stats: the tools' power has no upgrade in it")
check(string.find(stats, 's.mowerPower = (1 + (class.power or 0) + pet.power + level("power") * per("power"))', 1, true) ~= nil, "Stats: mowerPower keeps it")
local run = fs.readFile("src/server/Run.luau")
check(string.find(run, "mdef.damage * (stats.mowerPower or stats.power) *", 1, true) ~= nil, "Run: ride-on mowers cut with mowerPower")
check(string.find(run, "SkillTrees).boost(player, Config.TOOLS[", 1, true) ~= nil, "Run: the class gimmicks' best-tool hit has its skills")
check(string.find(run, "SkillTrees).onCut(player, patch)", 1, true) ~= nil, "Run: onCut (Harvest)")
check(string.find(fs.readFile("src/server/Tools.luau"), "SkillTrees).boost(player, Config.TOOLS[i], tool), tool", 1, true) ~= nil, "Tools.equipped returns the boosted tool")

-------------------------------------------------------------------------------------------------------------
-- the trees
-------------------------------------------------------------------------------------------------------------
local P = Tree.PIPS
check(P == 5, "5 pips a skill")
check(Tree.MAX_FULL_PER_RUN == 1, "one full tree a run")

-- the header's totals: 2x the coins a fresh run earns in each weapon's areas (the Laser 1x)
local TOTAL = { Hands = 1530, Scissors = 1530, Sickle = 6765, PushMower = 28230, WeedWhacker = 489900, MegaScythe = 7101000, LaserMower = 13008000 }
local PHASE = { Hands = 770, Scissors = 770, Sickle = 3400, PushMower = 14000, WeedWhacker = 245000, MegaScythe = 3.5e6, LaserMower = 13e6 }
local lastTotal = 0
for _, t in defs do
	local tree = Tree.tree(t.id)
	check(tree ~= nil, t.id .. " has a tree")
	if tree then
		check(#tree.skills == 3, t.id .. ": 3 skills")
		local seen = {}
		for _, sk in tree.skills do
			check(Tree.STATS[sk.id] ~= nil, t.id .. "." .. sk.id .. " is a known stat")
			check(not seen[sk.id], t.id .. "." .. sk.id .. " only once")
			seen[sk.id] = true
			check(#sk.name > 0 and #sk.desc > 0, t.id .. "." .. sk.id .. " has a name and a description")
		end
		check(seen.power and seen.harvest, t.id .. ": power and harvest")
		if t.kind == "swing" then
			check(seen.speed and not seen.width, t.id .. " (swing): speed, no width")
		else
			check(seen.width and not seen.speed, t.id .. " (auto): width, no speed")
		end
		check(#tree.coins == P, t.id .. ": a price for every pip")
		for pip = 1, P do
			if pip > 1 then
				local r = tree.coins[pip] / tree.coins[pip - 1]
				check(r >= 2.6 and r <= 3.2, ("%s: pip %d costs %.2fx pip %d (~x3)"):format(t.id, pip, r, pip - 1))
			end
			check(Tree.cost(t.id, pip) == tree.coins[pip], t.id .. ": cost of pip " .. pip)
		end
		check(Tree.cost(t.id, 0) == nil and Tree.cost(t.id, P + 1) == nil, t.id .. ": no pip 0 or " .. (P + 1))
		local total = Tree.totalCost(t.id)
		check(total == TOTAL[t.id], ("%s: tree %d coins (header)"):format(t.id, total))
		local want = if t.id == "LaserMower" then 1 else 2
		check(near(total / PHASE[t.id], want, 0.1), ("%s: tree = %.2fx its phase's coins (want %d)"):format(t.id, total / PHASE[t.id], want))
		check(total >= lastTotal, t.id .. ": a later weapon's tree never costs less")
		lastTotal = total
	end
end
local count = 0
for _ in Tree.TREES do
	count += 1
end
check(count == #defs, "a tree only for weapons that exist")
check(Tree.totalCost("Nope") == 0 and Tree.cost("Nope", 1) == nil, "an unknown weapon has no prices")

-- the bonuses
check(near(Tree.value("power", 5), 1.6) and Tree.text("power", 5) == "+160%", "power: +160% at max (+32% a pip)")
check(near(Tree.value("speed", 5), 0.15) and Tree.text("speed", 5) == "-15%", "speed: -15% swing time at max")
check(near(Tree.value("width", 5), 0.15) and Tree.text("width", 5) == "+15%", "width: +15% at max")
check(near(Tree.value("harvest", 5), 0.20) and Tree.text("harvest", 5) == "+20%", "harvest: +20% at max")
check(Tree.text("power", 0) == "+0%" and Tree.text("speed", 2) == "-6%", "texts at 0 and 2 pips")
for id, s in Tree.STATS do
	check(near(Tree.value(id, 99), s.per * P) and Tree.value(id, -4) == 0, id .. ": levels clamp to 0..PIPS")
end
check(Tree.value("nope", 3) == 0, "an unknown stat gives nothing")

-- a maxed tree vs the old Tool section's Power at level 10 (+20% a level, added to class + pet power)
for _, power in { 1.05, 2.0, 4.0 } do
	local old = (power + 2.0) / power
	local new = Tree.damageMult(Tree.value("power", 5), power, 1) / (1 - Tree.value("speed", 5))
	-- (the Speed skill is new on top: +2% for a new player, +10% for a player with power 4)
	check(new >= old * 0.95 and new <= old * 1.12, ("player power %.2f: a maxed swing tree x%.2f vs the old upgrade x%.2f"):format(power, new, old))
	-- (an auto tool walking through grass cuts a strip as wide as its circle: Width counts once)
	local auto = Tree.damageMult(Tree.value("power", 5), power, 1) * (1 + Tree.value("width", 5))
	check(auto >= old * 0.95 and auto <= old * 1.12, ("player power %.2f: a maxed auto tree x%.2f vs the old upgrade x%.2f"):format(power, auto, old))
end

-- the multipliers the server puts on a tool
local m0 = Tree.mults("Sickle", {})
check(m0.power == 0 and m0.cooldown == 1 and m0.radius == 1 and m0.harvest == 0, "no pips: no change")
local mS = Tree.mults("Sickle", { power = 5, speed = 5, harvest = 5 })
check(near(mS.power, 1.6) and near(mS.cooldown, 0.85) and mS.radius == 1 and near(mS.harvest, 0.2), "a maxed Sickle")
local mL = Tree.mults("LaserMower", { power = 3, width = 5, harvest = 1 })
check(near(mL.power, 0.96) and mL.cooldown == 1 and near(mL.radius, 1.15) and near(mL.harvest, 0.04), "a Laser Mower 3/5/1")
local mBad = Tree.mults("Scissors", { power = "lots", speed = 0 / 0, harvest = 12.7 })
check(mBad.power == 0 and mBad.cooldown == 1 and near(mBad.harvest, 0.2), "junk levels are safe")
check(Tree.mults("Nope", { power = 5 }).power == 0, "an unknown weapon gets nothing")
-- the tree's power is ADDED to the player's (like the old upgrade), VIP on top of both
check(near(Tree.damageMult(1.6, 1, 1), 2.6) and near(Tree.damageMult(1.6, 2, 1), 1.8), "damageMult: (power + tree) / power")
check(near(Tree.damageMult(1.6, 1.15, 1.15) * 1.15, (1 + 1.6) * 1.15), "damageMult with VIP: (1 + tree) x 1.15, as the old upgrade")
check(Tree.damageMult(0, 2, 1) == 1 and Tree.damageMult(1, 0, 1) == 1, "damageMult: nothing to add / no power")

-- pips, full trees
check(select(1, Tree.pips("Hands", {})) == 0 and select(2, Tree.pips("Hands", {})) == 15, "0 / 15 pips")
check(not Tree.isFull("Hands", { power = 5, speed = 5, harvest = 4 }), "14 / 15 isn't full")
check(Tree.isFull("Hands", { power = 5, speed = 5, harvest = 5 }), "15 / 15 is full")
check(Tree.isFull("Hands", { power = 9, speed = 5, harvest = 5 }), "more than 5 counts as 5")
check(not Tree.isFull("Hands", { power = 5, speed = 5, width = 5 }), "a skill the weapon doesn't have doesn't count")
check(not Tree.isFull("Nope", {}), "an unknown weapon is never full")
local fullHands = { power = 5, speed = 5, harvest = 5 }
check(Tree.fullCount({ Hands = fullHands, Scissors = { power = 5 }, Nope = fullHands }) == 1 and Tree.fullCount(nil) == 0, "fullCount")

-- the buy rule (server and window both use it)
local function state(levels, coins, extra)
	local s = { levels = levels or {}, owned = true, best = true, coins = coins, runSkills = {}, inRun = true }
	for k, v in extra or {} do
		s[k] = v
	end
	return s
end
local ok, why, price = Tree.check("Scissors", "power", state({}, 5))
check(ok and why == nil and price == 5, "the first pip with exactly enough coins")
ok, why, price = Tree.check("Scissors", "power", state({}, 4))
check(not ok and why == "coins" and price == 5, "one coin short")
ok, why = Tree.check("Scissors", "power", state({}, 10 ^ 9, { inRun = false }))
check(not ok and why == "lobby", "in the lobby: nothing")
ok, why = Tree.check("Scissors", "power", state({}, 10 ^ 9, { owned = false }))
check(not ok and why == "locked", "not owned in this run: locked")
ok, why = Tree.check("Scissors", "power", state({}, 10 ^ 9, { best = false }))
check(not ok and why == "past", "owned, not the best: an old weapon takes no pips")
ok, why, price = Tree.check("Scissors", "power", state({ power = 5 }, 10 ^ 9, { best = false }))
check(not ok and why == "max" and price == nil, "a full skill: max (before past)")
ok, why = Tree.check("Scissors", "width", state({}, 10 ^ 9))
check(not ok and why == "unknown", "a skill the Scissors don't have")
ok, why = Tree.check("Nope", "power", state({}, 10 ^ 9))
check(not ok and why == "unknown", "a weapon that doesn't exist")
ok, why = Tree.check("Scissors", "power", "junk")
check(not ok and why == "unknown", "no state")
-- one full tree a run: another weapon's tree is full, so this one takes all but its last pip
local almost = { power = 5, speed = 5, harvest = 4 }
ok, why = Tree.check("Sickle", "speed", state({ power = 5, speed = 4, harvest = 4 }, 10 ^ 9, { runSkills = { Scissors = fullHands } }))
check(ok, "13 -> 14 pips with another tree full: fine")
ok, why, price = Tree.check("Sickle", "harvest", state(almost, 10 ^ 9, { runSkills = { Scissors = fullHands, Sickle = almost } }))
check(not ok and why == "oneARun" and price == 1500, "the last pip with another tree full: one a run")
ok = Tree.check("Sickle", "harvest", state(almost, 10 ^ 9, { runSkills = { Scissors = { power = 5 }, Sickle = almost } }))
check(ok, "the last pip with no other tree full: fine")

-- buying a whole tree pip by pip, as the server does: 15 buys fill it, it costs totalCost, nothing more after
for _, t in defs do
	local levels = {}
	local wallet = 10 ^ 9
	local buys = 0
	local skills = Tree.tree(t.id).skills
	while true do
		local bought = false
		for _, sk in skills do -- round-robin, like a player spreading pips
			local good, _, cost = Tree.check(t.id, sk.id, state(levels, wallet, { runSkills = { [t.id] = levels } }))
			if good and cost then
				wallet -= cost
				levels[sk.id] = Tree.level(levels, sk.id) + 1
				buys += 1
				bought = true
				check(Tree.isFull(t.id, levels) == (buys == 15), t.id .. ": full only on the 15th buy")
			end
		end
		if not bought then
			break
		end
	end
	check(buys == 15 and 10 ^ 9 - wallet == Tree.totalCost(t.id), t.id .. ": 15 buys, spent = totalCost")
end

-------------------------------------------------------------------------------------------------------------
-- src/server/SkillTrees.luau, run against stand-ins for Roblox
-------------------------------------------------------------------------------------------------------------
local clock = 100
local roll = 0.5
local statPower = 1
local notes, fx, all, drops, onLoaded, handlers, removing, saves = {}, {}, {}, {}, {}, {}, {}, 0
local profiles = {}
local driving = false
local Mode = { isRun = true }

local ConfigStub = {
	TOOLS = defs,
	SKILL_TREES = Tree,
	toolIndex = function(id)
		for i, t in defs do
			if t.id == id then
				return i
			end
		end
		return nil
	end,
}
local Net = {
	on = function(name, rate, fn)
		handlers[name] = { rate = rate, fn = fn }
	end,
	send = function(_, name, kind, data)
		table.insert(fx, { name = name, kind = kind, data = data })
	end,
	notify = function(_, text)
		table.insert(notes, text)
	end,
	notifyAll = function(text)
		table.insert(all, text)
	end,
}
local PlayerData = {
	get = function(p)
		return profiles[p]
	end,
	onLoaded = function(fn)
		table.insert(onLoaded, fn)
	end,
	changed = function() end,
	save = function()
		saves += 1
	end,
}
local parent = {
	Net = Net,
	PlayerData = PlayerData,
	Mode = Mode,
	Stats = { compute = function()
		return { power = statPower }
	end },
	Mowers = { driving = function()
		return driving
	end },
	Loot = { drop = function(...)
		table.insert(drops, { ... })
	end },
	Field = { FALL_TIME = 0.7 },
}
local services = {
	Players = { PlayerRemoving = { Connect = function(_, fn)
		table.insert(removing, fn)
	end }, GetPlayers = function()
		return {}
	end },
	ReplicatedStorage = { MowALawn = { Config = ConfigStub } },
	RunService = { IsStudio = function()
		return false
	end },
	ServerStorage = {},
}
local env = {
	game = { GetService = function(_, name)
		return services[name]
	end },
	script = { Parent = parent },
	require = function(m)
		return m
	end,
	Random = { new = function()
		return { NextNumber = function()
			return roll
		end }
	end },
	task = { spawn = function(fn, ...)
		fn(...)
	end },
	os = { clock = function()
		return clock
	end, time = os.time },
	math = math, table = table, string = string, type = type, typeof = typeof, tonumber = tonumber, tostring = tostring,
	setmetatable = setmetatable, pairs = pairs, ipairs = ipairs, select = select, error = error, pcall = pcall, print = print,
	warn = function(...)
		print("[warn]", ...)
	end,
}
local Server = luau.load(fs.readFile("src/server/SkillTrees.luau"), { debugName = "server/SkillTrees", environment = env, injectGlobals = false })()

-- a held tool / backpack tool stand-in
local function toolObj(id: string, loaner: boolean?)
	local attrs = { ToolId = id, Loaner = loaner }
	return {
		IsA = function(_, c)
			return c == "Tool"
		end,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
		SetAttribute = function(_, k, v)
			attrs[k] = v
		end,
		attrs = attrs,
	}
end
local held = nil
local playerAttrs = {}
local player = {
	Name = "Tester",
	DisplayName = "Tester",
	Character = { FindFirstChildOfClass = function(_, c)
		return if c == "Tool" then held else nil
	end, GetChildren = function()
		return { held }
	end },
	FindFirstChildOfClass = function()
		return nil
	end,
	GetAttribute = function(_, k)
		return playerAttrs[k]
	end,
}
local function buy(toolId: any, skillId: any)
	clock += 1
	handlers.Skill.fn(player, toolId, skillId)
end
local function last(list)
	return list[#list]
end
local function sawFx(kind: string, from: number): boolean
	for i = from + 1, #fx do
		if fx[i].kind == kind then
			return true
		end
	end
	return false
end

Server.start()
check(handlers.Skill ~= nil and handlers.Skill.rate > 0, "server: the Skill remote is rate-limited")

-- a profile from the first version (mastery points, forever pips) with a saved run from before skill trees (the old
-- Power upgrade at 3, no run.skills): both load
local data = {
	gems = 0,
	tools = {},
	stats = {},
	skills = { v = 1, mp = { Scissors = 50 }, earned = { Scissors = 900 }, levels = { Scissors = { power = 5 } }, owned = { Hands = true }, mastered = { Hands = true, Nope = true, Sickle = "yes" } },
	run = { tool = 2, coins = 0, upgrades = { power = 3, speed = 0, sell = 0, swing = 0, grasp = 0 } },
}
profiles[player] = data
for _, fn in onLoaded do
	fn(player, data)
end
check(data.skills.v == 2 and data.skills.mp == nil and data.skills.levels == nil and data.skills.owned == nil and data.skills.earned == nil, "server: the first version's points and pips go")
check(data.skills.mastered.Hands == true and data.skills.mastered.Nope == nil and data.skills.mastered.Sickle == nil, "server: only real `true` masteries stay")
local v0 = Server.view(data)
check(v0.inRun == true and v0.best == "Scissors", "server: the view: in a run, the Scissors are the best weapon")
check(v0.trees.Hands.owned and v0.trees.Scissors.owned and not v0.trees.Sickle.owned, "server: owned = bought in this run")
check(v0.trees.Hands.mastered and not v0.trees.Scissors.mastered, "server: mastered from the profile")
check(type(data.run.skills) == "table" and next(v0.trees.Scissors.levels) == nil, "server: an old saved run gets run.skills, no pips")
check(data.run.upgrades.power == 3, "server: the old Power levels stay (Mower Blades now)")

-- buying: the reasons
Mode.isRun = false
buy("Scissors", "power")
check(string.find(last(notes) or "", "bought in a run", 1, true) ~= nil and Server.view(data).inRun == false, "server: nothing in the lobby")
Mode.isRun = true
buy("Sickle", "power")
check(string.find(last(notes) or "", "Buy the Sickle in this run", 1, true) ~= nil, "server: not owned this run: locked")
data.run.coins = 10 ^ 6
buy("Hands", "power")
check(string.find(last(notes) or "", "Only your best weapon", 1, true) ~= nil and next(data.run.skills.Hands or {}) == nil, "server: an old weapon (the Hands) takes no pips")
data.run.coins = 4
buy("Scissors", "power")
check(string.find(last(notes) or "", "Not enough coins", 1, true) ~= nil and (data.run.skills.Scissors.power or 0) == 0, "server: 4 < 5 coins")
data.run.coins = 5
local fx0 = #fx
buy("Scissors", "power")
check(data.run.skills.Scissors.power == 1 and data.run.coins == 0, "server: pip 1 bought for 5 coins")
check(last(fx).kind == "skillPip" and last(fx).data.level == 1 and sawFx("purchase", fx0), "server: the purchase and pip Fx")
data.run.coins = 10 ^ 6
handlers.Skill.fn(player, "Scissors", "power") -- (same clock: too soon after the last buy)
check(data.run.skills.Scissors.power == 1, "server: a second buy in the same 0.2 s is ignored")
buy("Scissors", "width")
buy({}, 5)
buy("Scissors", nil)
check(data.run.skills.Scissors.power == 1 and data.run.skills.Scissors.width == nil and data.run.coins == 10 ^ 6, "server: junk requests change nothing")
buy("Scissors", "power")
buy("Scissors", "power")
check(data.run.skills.Scissors.power == 3 and data.run.coins == 10 ^ 6 - 15 - 40, "server: pips 2, 3 for 15 + 40 coins")

-- the held tool's numbers
held = toolObj("Scissors")
local sDef = defs[2]
local b1 = Server.boost(player, sDef, held)
check(b1 ~= sDef and near(b1.damage, 3 * (1 + 0.96)) and b1.cooldown == sDef.cooldown and b1.radius == sDef.radius, "server: Scissors with 3 power pips: damage x(1 + 0.96)")
check(sDef.damage == 3, "server: Config's own table is never changed")
check(held.attrs.SkillCooldown == nil, "server: no speed pips, no SkillCooldown")
check(Server.boost(player, sDef, held) == b1, "server: cached until something changes")
statPower = 2
local b1b = Server.boost(player, sDef, held)
check(b1b ~= b1 and near(b1b.damage, 3 * (1 + 0.96 / 2)), "server: the tree's power is added to the player's (power 2: x1.48)")
statPower = 1.15
playerAttrs.Pass_VIP = true
local b1v = Server.boost(player, sDef, held)
check(near(b1v.damage * 1.15, 3 * (1 + 0.96) * 1.15), "server: VIP: (1 + tree) x 1.15, like the old upgrade")
statPower = 1
playerAttrs.Pass_VIP = nil
for _ = 1, 5 do
	buy("Scissors", "speed")
end
local b2 = Server.boost(player, sDef, held)
check(near(b2.cooldown, sDef.cooldown * 0.85), "server: 5 speed pips: 15% shorter swing")
check(held.attrs.SkillCooldown ~= nil and near(held.attrs.SkillCooldown, 0.85), "server: the tool tells client/Input (SkillCooldown 0.85)")
data.run.skills.PushMower = { width = 5 }
local pDef = defs[4]
local b3 = Server.boost(player, pDef, toolObj("PushMower"))
check(near(b3.radius, pDef.radius * 1.15) and b3.cooldown == nil and b3.skillCooldown == nil, "server: a Push Mower's width")
check(Server.boost(player, { id = "Gun", damage = 1 }, nil).damage == 1, "server: something without a tree passes through")

-- Harvest
for _ = 1, 4 do
	buy("Scissors", "harvest")
end
local before = #drops
roll = 0.1 -- (16% at 4 pips: a hit)
Server.onCut(player, { z = 3, mut = "Golden", landPos = "land", part = { Position = "here" } })
check(#drops == before + 1 and drops[#drops][2] == "bundle" and drops[#drops][3] == "land" and drops[#drops][5] == "Golden" and drops[#drops][7] == 0.7, "server: Harvest drops one more bundle, same mutation, when the clump lands")
check(last(fx).kind == "skillHarvest", "server: the Harvest Fx")
roll = 0.5
Server.onCut(player, { z = 3, part = { Position = "here" } })
check(#drops == before + 1, "server: no extra bundle on a miss")
roll = 0.1
driving = true
Server.onCut(player, { z = 3, part = { Position = "here" } })
driving = false
held = toolObj("Scissors", true)
Server.onCut(player, { z = 3, part = { Position = "here" } })
held = toolObj("Sickle")
data.run.skills.Sickle = { harvest = 5 }
Server.onCut(player, { z = 3, part = { Position = "here" } })
data.run.skills.Sickle = nil
held = nil
Server.onCut(player, { z = 3, part = { Position = "here" } })
check(#drops == before + 1, "server: no Harvest on a mower, with a loan, with a tool not owned, with empty hands")
roll = 0.5
held = toolObj("Scissors")

-- mastering: the 15th pip, the first time
local hooked = 0
Server.onMastered(function(p, id)
	if p == player and id == "Scissors" then
		hooked += 1
	end
end)
buy("Scissors", "harvest") -- harvest 5: power 3 + speed 5 + harvest 5 = 13 pips
buy("Scissors", "power") -- 14
check(select(1, Tree.pips("Scissors", data.run.skills.Scissors)) == 14, "server: 14 pips")
check(not Server.isMastered(player, "Scissors") and hooked == 0 and #all == 0, "server: not mastered at 14 pips")
local fx1, saves1 = #fx, saves
buy("Scissors", "power") -- pip 5 of power: 15 / 15
check(data.skills.mastered.Scissors == true and Server.isMastered(player, "Scissors"), "server: 15 / 15 masters the Scissors")
check(hooked == 1 and #all == 1 and string.find(all[1], "MASTERED the Garden Scissors", 1, true) ~= nil, "server: onMastered once, the server hears it")
check(sawFx("skillMastered", fx1) and not sawFx("purchase", fx1) and saves == saves1 + 1, "server: the MASTERED Fx (no plain purchase Fx), saved at once")
check(held.attrs.Mastered == true, "server: the held tool says Mastered")
local coinsLeft = data.run.coins
buy("Scissors", "power")
check(data.run.coins == coinsLeft and string.find(last(notes) or "", "maxed", 1, true) ~= nil, "server: nothing more to buy")
check(Server.view(data).trees.Scissors.mastered == true, "server: the view says mastered")

-- the next weapon: only it learns now, and its last pip waits (the Scissors filled this run's one full tree)
data.run.tool = 3
buy("Scissors", "power")
check(Server.view(data).best == "Sickle", "server: the Sickle is the best weapon now")
data.run.skills.Sickle = { power = 5, speed = 5, harvest = 4 }
local coinsBefore = data.run.coins
buy("Sickle", "harvest")
check(data.run.skills.Sickle.harvest == 4 and data.run.coins == coinsBefore and string.find(last(notes) or "", "One weapon can be maxed a run", 1, true) ~= nil, "server: one full tree a run")

-- a new run (PlayerData.newRun): no pips, MASTERED stays, the tool hits like new again
data.run = { tool = 2, coins = 0, upgrades = { power = 0, speed = 0, sell = 0, swing = 0, grasp = 0 }, skills = {} }
local v1 = Server.view(data)
check(v1.trees.Scissors.mastered and next(v1.trees.Scissors.levels) == nil and v1.trees.Hands.mastered, "server: a new run: no pips, still mastered")
local b4 = Server.boost(player, sDef, held)
check(near(b4.damage, sDef.damage) and b4.cooldown == sDef.cooldown, "server: a new run's tool has no skills on (the cache follows the run)")
check(held.attrs.Mastered == true and held.attrs.SkillCooldown == nil, "server: ... but still says Mastered")
-- filling it again: no second celebration
data.run.coins = 10 ^ 6
for _, sk in Tree.tree("Scissors").skills do
	for _ = 1, P do
		buy("Scissors", sk.id)
	end
end
local fx2 = #fx
check(Tree.isFull("Scissors", data.run.skills.Scissors), "server: the Scissors maxed again")
check(hooked == 1 and #all == 1, "server: no second MASTERED message or hook")
local again = false
for i = 1, fx2 do
	if fx[i].kind == "skillMastered" and i > fx1 + 2 then
		again = true
	end
end
check(not again, "server: no second celebration Fx")
check(next(data.run.skills.Hands or {}) == nil, "server: the old weapons got nothing")

-- a forever (Robux) tool: owned in every run; the best weapon even with run.tool lower (Tools.give lifts run.tool)
data.tools = { WeedWhacker = true }
local v2 = Server.view(data)
check(v2.trees.WeedWhacker.owned and v2.best == "WeedWhacker" and not v2.trees.PushMower.owned, "server: a forever tool is owned and the best")
data.tools = {}

-- leaving clears the caches
for _, fn in removing do
	fn(player)
end

-- a half-done copy into Studio must turn the trees off, not break the game:
-- (1) shared/Config without the SKILL_TREES line
local source = fs.readFile("src/server/SkillTrees.luau")
local warned = {}
local function loadWith(cfg, net)
	local e = table.clone(env)
	e.warn = function(text)
		table.insert(warned, text)
	end
	e.script = { Parent = setmetatable({ Net = net }, { __index = parent }) }
	e.game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return { MowALawn = { Config = cfg } }
		end
		return services[name]
	end }
	return luau.load(source, { debugName = "server/SkillTrees (guard)", environment = e, injectGlobals = false })()
end
local noTrees = loadWith({ TOOLS = defs, toolIndex = ConfigStub.toolIndex }, Net)
local okStart = pcall(noTrees.start)
local plain = defs[2]
check(okStart and #warned == 1 and string.find(warned[1], "SKILL_TREES is missing", 1, true) ~= nil, "guard: no Config.SKILL_TREES -> one warning, start() is fine")
check(noTrees.view(data) == nil and noTrees.boost(player, plain, nil) == plain and noTrees.isMastered(player, "Scissors") == false, "guard: view nil, tools plain, nothing mastered")
check(pcall(noTrees.onCut, player, { z = 1, part = { Position = "here" } }), "guard: cuts don't error")
-- (2) server/Net without the "Skill" remote: Net.on errors inside start()
warned = {}
local brokenNet = setmetatable({ on = function()
	error("attempt to index nil with 'OnServerEvent'")
end }, { __index = Net })
local noRemote = loadWith(ConfigStub, brokenNet)
check(pcall(noRemote.start) and #warned == 1 and string.find(warned[1], "no \"Skill\" remote", 1, true) ~= nil, "guard: no Skill remote -> a warning, start() doesn't throw")
-- (3) server/Stats without mowerPower (Run's `or stats.power`) is Run's business; the boost only needs .power

print(("%d checks passed, %d failed"):format(passed, failed))
process.exit(if failed > 0 then 1 else 0)
