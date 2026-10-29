-- Checks the weapon skill trees' numbers and math (src/shared/SkillTrees.luau, pure Luau) in Lune:
--   lune run tools/skilltrees-test.luau
-- Every weapon in Config.TOOLS has a tree that fits its kind, the prices climb steeply, the bonuses stay capped, the
-- buy rule says yes / no for the right reasons, and the time to master matches the table in the module's header.
local fs = require("@lune/fs")
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
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

-- Config.TOOLS, read from the source (Config itself needs Roblox): { id, kind } in shop order
local tools = {}
local config = fs.readFile("src/shared/Config.luau")
local block = string.match(config, "Config%.TOOLS = (%b{})")
check(block ~= nil, "found Config.TOOLS")
for id, kind in string.gmatch(block or "", '{ id = "(%w+)",[^\n]-kind = "(%w+)"') do
	table.insert(tools, { id = id, kind = kind })
end
check(#tools == 7, "Config.TOOLS has 7 weapons (found " .. #tools .. ")")
check(string.find(config, 'Config.SKILL_TREES = require(script.Parent:WaitForChild("SkillTrees"))', 1, true) ~= nil, "Config requires the module")

local P = Tree.PIPS
check(P == 5, "5 pips a skill")

-- every weapon: a tree of three skills that fit its kind, with steep prices and gems only on the top two pips
for _, t in tools do
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
		check(#tree.mp == P and #tree.gems == P, t.id .. ": a price for every pip")
		for pip = 1, P do
			if pip > 1 then
				local r = tree.mp[pip] / tree.mp[pip - 1]
				check(r >= 1.5 and r <= 2.1, ("%s: pip %d costs %.2fx pip %d (steep, 1.5-2.1)"):format(t.id, pip, r, pip - 1))
			end
			check((tree.gems[pip] > 0) == (pip >= P - 1), t.id .. ": gems on pips 4 and 5 only (pip " .. pip .. ")")
			local mp, gems = Tree.cost(t.id, pip)
			check(mp == tree.mp[pip] and gems == tree.gems[pip], t.id .. ": cost of pip " .. pip)
		end
		check(Tree.cost(t.id, 0) == nil and Tree.cost(t.id, P + 1) == nil, t.id .. ": no pip 0 or " .. (P + 1))
	end
end
local count = 0
for _ in Tree.TREES do
	count += 1
end
check(count == #tools, "a tree only for weapons that exist")

-- where each weapon earns: its own area(s) and later, never before (a forever-owned weapon can't farm easy grass)
local FROM = { Hands = 1, Scissors = 1, Sickle = 2, PushMower = 3, WeedWhacker = 4, MegaScythe = 6, LaserMower = 8 }
local lastFrom = 1
for _, t in tools do
	local from = Tree.tree(t.id) and Tree.tree(t.id).from
	check(from == FROM[t.id], t.id .. " earns from area " .. tostring(FROM[t.id]))
	check(type(from) == "number" and from >= lastFrom, t.id .. ": a later weapon never starts earning earlier")
	lastFrom = from or lastFrom
	if from then
		check(not Tree.earns(t.id, from - 1) and Tree.earns(t.id, from) and Tree.earns(t.id, 8), t.id .. ": earns(from - 1) no, earns(from), earns(8)")
	end
end
check(not Tree.earns("LaserMower", nil) and not Tree.earns("Nope", 8), "earns: no zone / no weapon")

-- the bonuses: per pip, at max, capped at +20-30%
check(near(Tree.value("power", 5), 0.20) and Tree.text("power", 5) == "+20%", "power: +20% at max")
check(near(Tree.value("speed", 5), 0.15) and Tree.text("speed", 5) == "-15%", "speed: -15% swing time at max")
check(near(Tree.value("width", 5), 0.15) and Tree.text("width", 5) == "+15%", "width: +15% at max")
check(near(Tree.value("harvest", 5), 0.20) and Tree.text("harvest", 5) == "+20%", "harvest: +20% at max")
check(Tree.text("power", 0) == "+0%" and Tree.text("speed", 2) == "-6%", "texts at 0 and 2 pips")
for id, s in Tree.STATS do
	check(s.per * P <= 0.30 + 1e-9, id .. " is at most +30% at max")
	check(near(Tree.value(id, 99), s.per * P) and Tree.value(id, -4) == 0, id .. ": levels clamp to 0..PIPS")
end
check(Tree.value("nope", 3) == 0, "an unknown stat gives nothing")

-- the multipliers the server puts on a tool
local m0 = Tree.mults("Sickle", {})
check(m0.damage == 1 and m0.cooldown == 1 and m0.radius == 1 and m0.harvest == 0, "no pips: no change")
local mS = Tree.mults("Sickle", { power = 5, speed = 5, harvest = 5 })
check(near(mS.damage, 1.2) and near(mS.cooldown, 0.85) and mS.radius == 1 and near(mS.harvest, 0.2), "a maxed Sickle")
local mL = Tree.mults("LaserMower", { power = 3, width = 5, harvest = 1 })
check(near(mL.damage, 1.12) and mL.cooldown == 1 and near(mL.radius, 1.15) and near(mL.harvest, 0.04), "a Laser Mower 3/5/1")
local mBad = Tree.mults("Scissors", { power = "lots", speed = 0 / 0, harvest = 12.7 })
check(mBad.damage == 1 and mBad.cooldown == 1 and near(mBad.harvest, 0.2), "junk levels in a profile are safe")
check(Tree.mults("Nope", { power = 5 }).damage == 1, "an unknown weapon gets nothing")

-- pips and mastered
check(select(1, Tree.pips("Hands", {})) == 0 and select(2, Tree.pips("Hands", {})) == 15, "0 / 15 pips")
check(not Tree.isMastered("Hands", { power = 5, speed = 5, harvest = 4 }), "14 / 15 isn't mastered")
check(Tree.isMastered("Hands", { power = 5, speed = 5, harvest = 5 }), "15 / 15 is mastered")
check(Tree.isMastered("Hands", { power = 9, speed = 5, harvest = 5 }), "more than 5 counts as 5")
check(not Tree.isMastered("Hands", { power = 5, speed = 5, width = 5 }), "a skill the weapon doesn't have doesn't count")
check(not Tree.isMastered("Nope", {}), "an unknown weapon is never mastered")

-- the buy rule (server and window both use it)
local function view(mp: number, owned: boolean, levels: { [string]: number }?)
	return { mp = mp, owned = owned, levels = levels or {} }
end
local ok, why, mp, gems = Tree.check("Scissors", "power", view(40, true), 0)
check(ok and why == nil and mp == 40 and gems == 0, "the first pip with exactly enough")
ok, why = Tree.check("Scissors", "power", view(39, true), 1000)
check(not ok and why == "mp", "one mastery point short")
ok, why = Tree.check("Scissors", "power", view(99999, false), 99999)
check(not ok and why == "locked", "never owned: locked")
ok, why, mp, gems = Tree.check("Scissors", "power", view(230, true, { power = 3 }), 14)
check(not ok and why == "gems" and mp == 230 and gems == 15, "pip 4 needs 15 gems too")
ok = Tree.check("Scissors", "power", view(230, true, { power = 3 }), 15)
check(ok, "pip 4 with the gems")
ok, why, mp = Tree.check("Scissors", "power", view(99999, true, { power = 5 }), 99999)
check(not ok and why == "max" and mp == nil, "a full skill: max")
ok, why = Tree.check("Scissors", "width", view(99999, true), 99999)
check(not ok and why == "unknown", "a skill the Scissors don't have")
ok, why = Tree.check("Nope", "power", view(99999, true), 99999)
check(not ok and why == "unknown", "a weapon that doesn't exist")
ok, why = Tree.check("Scissors", "power", "junk", 99999)
check(not ok and why == "unknown", "no profile part")

-- buying a whole tree, pip by pip as the server does: 15 buys master it, then nothing more can be bought, and it
-- costs exactly the module's totals
local expect = {
	Hands = { 1470, 105 }, Scissors = { 2640, 165 }, Sickle = { 2895, 255 }, PushMower = { 2895, 420 },
	WeedWhacker = { 5625, 630 }, MegaScythe = { 4965, 930 }, LaserMower = { 1410, 1350 },
}
for _, t in tools do
	local state = view(10 ^ 9, true)
	local wallet = 10 ^ 9
	local buys = 0
	local skills = Tree.tree(t.id).skills
	while true do
		local bought = false
		for _, sk in skills do -- round-robin, like a player spreading pips
			local good, _, cost, gemCost = Tree.check(t.id, sk.id, state, wallet)
			if good and cost then
				state.mp -= cost
				wallet -= gemCost
				state.levels[sk.id] = Tree.level(state.levels, sk.id) + 1
				buys += 1
				bought = true
				check(Tree.isMastered(t.id, state.levels) == (buys == 15), t.id .. ": mastered only on the 15th buy")
			end
		end
		if not bought then
			break
		end
	end
	local spentMp, spentGems = 10 ^ 9 - state.mp, 10 ^ 9 - wallet
	local totalMp, totalGems = Tree.totalCost(t.id)
	check(buys == 15, t.id .. ": 15 buys")
	check(spentMp == totalMp and spentGems == totalGems, t.id .. ": spent = totalCost")
	check(totalMp == expect[t.id][1] and totalGems == expect[t.id][2], ("%s: tree %d mp / %d gems (header table)"):format(t.id, totalMp, totalGems))
end

-- the time to master in the header: ~20 runs of each weapon's own areas (Hands is the dedicated punch-only grind)
local AREAS = { Backyard = 130, Meadow = 143, Golf = 147, Wheat = 170, Blossom = 111, Swamp = 100, Prairie = 150, Jungle = 68 }
local perRun = {
	Hands = AREAS.Backyard + AREAS.Meadow, Scissors = AREAS.Backyard, Sickle = AREAS.Meadow, PushMower = AREAS.Golf,
	WeedWhacker = AREAS.Wheat + AREAS.Blossom, MegaScythe = AREAS.Swamp + AREAS.Prairie, LaserMower = AREAS.Jungle,
}
for _, t in tools do
	local runs = Tree.totalCost(t.id) / perRun[t.id]
	if t.id == "Hands" then
		check(runs > 4 and runs < 7, ("Hands: %.1f punch-only runs"):format(runs))
	else
		check(runs > 19 and runs < 21.5, ("%s: %.1f runs to master (aim ~20)"):format(t.id, runs))
	end
end
check(Tree.POINTS.clump == 1 and Tree.POINTS.elder > Tree.POINTS.clump, "1 point a clump, more for an Elder Clump")

-------------------------------------------------------------------------------------------------------------
-- src/server/SkillTrees.luau itself, run against stand-ins for Roblox (services, Net, PlayerData, the tools in a
-- hand): an old profile loads, the trees open as tools are owned, cuts pay the right weapon, buys are checked, the
-- last pip masters the tree once, the held tool gets its numbers, Harvest drops a bundle.
-------------------------------------------------------------------------------------------------------------
local luau = require("@lune/luau")

local clock = 100
local roll = 0.5
local notes, fx, all, drops, onLoaded, handlers, removing = {}, {}, {}, {}, {}, {}, {}
local profiles = {}
local driving = false

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
	save = function() end,
}
local parent = {
	Net = Net,
	PlayerData = PlayerData,
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
}
local function buy(toolId: any, skillId: any)
	clock += 1
	handlers.Skill.fn(player, toolId, skillId)
end
local function last(list)
	return list[#list]
end

Server.start()
check(handlers.Skill ~= nil and handlers.Skill.rate > 0, "server: the Skill remote is rate-limited")
-- an old profile, saved before skill trees existed
local data = { gems = 0, tools = {}, run = nil, stats = {} }
profiles[player] = data
for _, fn in onLoaded do
	fn(player, data)
end
check(type(data.skills) == "table" and data.skills.v == 1, "server: an old profile gets profile.skills")
check(data.skills.owned.Hands == true and not data.skills.owned.Scissors, "server: only the bare hands are open")
local v0 = Server.view(data)
check(v0.Hands.owned and not v0.Scissors.owned and v0.LaserMower.mp == 0, "server: the view")

buy("Scissors", "power")
check(string.find(last(notes) or "", "in a run to open", 1, true) ~= nil and data.skills.levels.Scissors.power == 0, "server: no buy before owning")
data.run = { tool = 2 }
Server.view(data)
check(data.skills.owned.Scissors == true and not data.skills.owned.Sickle, "server: buying the Scissors in a run opens their tree")
data.run = { tool = 1 } -- (a new run starts with bare hands again: the tree stays open)
Server.view(data)
check(data.skills.owned.Scissors == true, "server: an opened tree stays open")
data.run = { tool = 2 }

-- earning: the weapon in hand, owned, not on a mower, not a loan
held = toolObj("Scissors")
Server.onCut(player, { z = 1, part = { Position = "here" } })
check(data.skills.mp.Scissors == 1 and data.skills.earned.Scissors == 1, "server: a clump pays the held weapon 1")
Server.onCut(player, { z = 2, elder = true, part = { Position = "here" } })
check(data.skills.mp.Scissors == 21, "server: an Elder Clump pays 20")
driving = true
Server.onCut(player, { z = 1, part = { Position = "here" } })
driving = false
check(data.skills.mp.Scissors == 21, "server: nothing while driving a mower")
held = toolObj("PushMower", true)
Server.onCut(player, { z = 1, part = { Position = "here" } })
check((data.skills.mp.PushMower or 0) == 0, "server: nothing for a first-timer's loan")
held = toolObj("Sickle")
Server.onCut(player, { z = 1, part = { Position = "here" } })
check((data.skills.mp.Sickle or 0) == 0, "server: nothing for a tool you don't own")
held = nil
Server.onCut(player, { z = 1, part = { Position = "here" } })
check(data.skills.mp.Scissors == 21, "server: nothing with empty hands")
-- a Laser Mower owned forever with Robux, held from area 1: nothing before the Mega Jungle (its area)
data.tools = { LaserMower = true }
held = toolObj("LaserMower")
Server.onCut(player, { z = 1, part = { Position = "here" } })
Server.onCut(player, { z = 7, part = { Position = "here" } })
check((data.skills.mp.LaserMower or 0) == 0 and data.skills.owned.LaserMower == true, "server: a forever Laser earns nothing in areas 1-7 (its tree opens)")
Server.onCut(player, { z = 8, part = { Position = "here" } })
check(data.skills.mp.LaserMower == 1, "server: ... and 1 a clump in the Mega Jungle")
data.skills.mp.LaserMower = 0
data.tools = {}
held = nil

-- buying
buy("Scissors", "power")
check(data.skills.levels.Scissors.power == 0 and string.find(last(notes) or "", "Not enough mastery", 1, true) ~= nil, "server: 21 < 40 mastery points")
data.skills.mp.Scissors = 40
buy("Scissors", "power")
check(data.skills.levels.Scissors.power == 1 and data.skills.mp.Scissors == 0, "server: pip 1 bought for 40")
check(last(fx).kind == "skillPip" and last(fx).data.level == 1, "server: the pip Fx")
data.skills.mp.Scissors = 10 ^ 6
handlers.Skill.fn(player, "Scissors", "power") -- (same clock: too soon after the last buy)
check(data.skills.levels.Scissors.power == 1, "server: a second buy in the same 0.2 s is ignored")
buy("Scissors", "width")
check(data.skills.levels.Scissors.width == nil, "server: a skill the Scissors don't have")
buy({}, 5)
buy("Scissors", nil)
check(data.skills.levels.Scissors.power == 1, "server: junk requests change nothing")
buy("Scissors", "power")
buy("Scissors", "power")
check(data.skills.levels.Scissors.power == 3, "server: pips 2, 3")
buy("Scissors", "power")
check(data.skills.levels.Scissors.power == 3 and string.find(last(notes) or "", "gems", 1, true) ~= nil, "server: pip 4 needs gems")
data.gems = 15
buy("Scissors", "power")
check(data.skills.levels.Scissors.power == 4 and data.gems == 0, "server: pip 4 takes 15 gems")

-- the held tool's numbers
held = toolObj("Scissors")
local sDef = defs[2]
local b1 = Server.boost(player, sDef, held)
check(b1 ~= sDef and math.abs(b1.damage - sDef.damage * 1.16) < 1e-9 and b1.cooldown == sDef.cooldown and b1.radius == sDef.radius, "server: Scissors with 4 power pips hit 16% harder")
check(sDef.damage == 3, "server: Config's own table is never changed")
check(held.attrs.SkillCooldown == nil, "server: no speed pips, no SkillCooldown")
check(Server.boost(player, sDef, held) == b1, "server: cached until a buy")
data.gems = 10 ^ 6
for _ = 1, 5 do
	buy("Scissors", "speed")
end
local b2 = Server.boost(player, sDef, held)
check(b2 ~= b1 and math.abs(b2.cooldown - sDef.cooldown * 0.85) < 1e-9, "server: 5 speed pips: 15% shorter swing")
check(held.attrs.SkillCooldown ~= nil and math.abs(held.attrs.SkillCooldown - 0.85) < 1e-9, "server: the tool tells client/Input (SkillCooldown 0.85)")
data.skills.levels.PushMower = { width = 5 }
local pDef = defs[4]
local b3 = Server.boost(player, pDef, toolObj("PushMower"))
check(math.abs(b3.radius - pDef.radius * 1.15) < 1e-9 and b3.cooldown == nil and b3.skillCooldown == nil, "server: a Push Mower's width")

-- Harvest
for _ = 1, 4 do
	buy("Scissors", "harvest")
end
local before = #drops
roll = 0.1 -- (16% chance at 4 pips: hit)
Server.onCut(player, { z = 3, mut = "Golden", landPos = "land", part = { Position = "here" } })
check(#drops == before + 1 and drops[#drops][2] == "bundle" and drops[#drops][3] == "land" and drops[#drops][5] == "Golden" and drops[#drops][7] == 0.7, "server: Harvest drops one more bundle, same mutation, when the clump lands")
check(last(fx).kind == "skillHarvest", "server: the Harvest Fx")
roll = 0.5
Server.onCut(player, { z = 3, part = { Position = "here" } })
check(#drops == before + 1, "server: no extra bundle on a miss")
data.skills.levels.LaserMower = { harvest = 5 }
data.tools = { LaserMower = true }
held = toolObj("LaserMower")
roll = 0.1
Server.onCut(player, { z = 1, part = { Position = "here" } })
check(#drops == before + 2 and (data.skills.mp.LaserMower or 0) == 0, "server: Harvest works anywhere, mastery only from the weapon's area")
roll = 0.5
data.tools = {}
data.skills.levels.LaserMower = {}
held = toolObj("Scissors")

-- mastering: the 15th pip, once
local hooked = 0
Server.onMastered(function(p, id)
	if p == player and id == "Scissors" then
		hooked += 1
	end
end)
buy("Scissors", "harvest") -- harvest 5: power 4 + speed 5 + harvest 5 = 14 pips
check(select(1, Tree.pips("Scissors", data.skills.levels.Scissors)) == 14, "server: 14 pips")
check(not Server.isMastered(player, "Scissors") and hooked == 0 and #all == 0, "server: not mastered at 14 pips")
buy("Scissors", "power") -- pip 5 of power: 15 / 15
check(data.skills.mastered.Scissors == true and Server.isMastered(player, "Scissors"), "server: 15 / 15 is mastered")
check(hooked == 1 and #all == 1 and string.find(all[1], "MASTERED the Garden Scissors", 1, true) ~= nil, "server: onMastered once, the server hears it")
local sawMastered = false
for _, e in fx do
	if e.kind == "skillMastered" and e.data.tool == "Scissors" then
		sawMastered = true
	end
end
check(sawMastered, "server: the MASTERED Fx")
local mpLeft = data.skills.mp.Scissors
buy("Scissors", "power")
check(data.skills.mp.Scissors == mpLeft and string.find(last(notes) or "", "maxed", 1, true) ~= nil and hooked == 1, "server: nothing more to buy")
check(Server.view(data).Scissors.mastered == true, "server: the view says mastered")

-- a damaged profile is repaired, not lost
local junk = { gems = 0, skills = { mp = { Scissors = -5, Sickle = "x" }, levels = { Scissors = { power = 99 }, Sickle = "bad" }, owned = { Sickle = "yes" }, mastered = { Hands = true } } }
Server.migrate(junk)
check(junk.skills.mp.Scissors == 0 and junk.skills.mp.Sickle == 0, "server: bad mastery numbers become 0")
check(junk.skills.levels.Scissors.power == 99 and type(junk.skills.levels.Sickle) == "table", "server: odd pips kept, a bad table replaced")
check(junk.skills.owned.Sickle == nil and junk.skills.owned.Hands == true, "server: only `true` opens a tree")
check(junk.skills.mastered.Hands == nil, "server: `mastered` follows the pips")

-- leaving clears the caches
for _, fn in removing do
	fn(player)
end

-- a half-done copy into Studio must turn the trees off, not break the game:
-- (1) shared/Config without the SKILL_TREES line
local source = fs.readFile("src/server/SkillTrees.luau")
local warned = {}
local function loadWith(config, net)
	local e = table.clone(env)
	e.warn = function(text)
		table.insert(warned, text)
	end
	e.script = { Parent = setmetatable({ Net = net }, { __index = parent }) }
	e.game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return { MowALawn = { Config = config } }
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

print(("%d checks passed, %d failed"):format(passed, failed))
process.exit(if failed > 0 then 1 else 0)
