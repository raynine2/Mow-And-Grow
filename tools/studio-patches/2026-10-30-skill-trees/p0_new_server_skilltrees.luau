-- Creates src/server/SkillTrees.luau in Studio (a ModuleScript, exactly git's text: the second version, pips bought with a
-- run's coins, MASTERED for good). Run in Edit mode. Installs it if it isn't there; replaces the first version (13889 1193936855)
-- if that is there; refuses anything else (someone's own changes: ask before replacing them).
local src = [=====[
-- WEAPON SKILL TREES, the server side. The numbers are shared/SkillTrees (Config.SKILL_TREES), the window
-- client/SkillTreeWindow. Pips are bought with the run's coins and live in the run, like the run upgrades; MASTERED
-- (every pip of a weapon full, once) is kept forever in the profile.
--
--   run.skills = { [toolId] = { [skillId] = pips } }   this run's pips (PlayerData.newRun; made here too if missing)
--   profile.skills = { v = 2, mastered = { [toolId] = true } }   weapons ever mastered: their page stays gold.
--     Later code hooks in with SkillTrees.isMastered(player, toolId) / SkillTrees.onMastered(fn).
--
-- Hooks in other files: Main (SkillTrees.start, the snapshot's `skills`), Net (the "Skill" remote), Tools.equipped
-- (the held tool with its skills: SkillTrees.boost), Run (onCut: Harvest; the class gimmicks' "best tool hit" with
-- its skills; mowers use Stats.mowerPower), Stats (mowerPower: the old Power upgrade, now "Mower Blades"),
-- PlayerData.newRun (run.skills), client/Input (a shorter swing: the tool's SkillCooldown attribute).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local Tree = Config.SKILL_TREES
local SkillTrees = {}
-- (a half-done copy into a place whose shared/Config lacks the SKILL_TREES line turns the trees off, not the game)
local ON = type(Tree) == "table"
if not ON then
	warn("[SkillTrees] Config.SKILL_TREES is missing (shared/Config needs its require line): skill trees are off")
end

local VERSION = 2
local BUY_GAP = 0.2 -- seconds between two pip buys of one player (on top of Net's rate limit)
local rng = Random.new()
local started = false
local migrated: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- profiles already brought up to date
local boosted: { [Player]: { [string]: any } } = {} -- [player][toolId] = that tool's def with its skills (a buy clears it)
local lastBuy: { [Player]: number } = {}
local masteredHooks: { (Player, string) -> () } = {}

local function count(v: any): number
	local n = tonumber(v)
	if not n or n ~= n or n == math.huge then
		return 0
	end
	return math.max(0, math.floor(n))
end

local function toolDef(id: string)
	local i = Config.toolIndex(id)
	return i and Config.TOOLS[i], i
end

local function inRun(): boolean
	return require(script.Parent.Mode).isRun == true
end

-------------------------------------------------------------------------------------------------------------
-- the profile (MASTERED, forever) and the run (pips)
-------------------------------------------------------------------------------------------------------------
-- Make profile.skills or bring an older one up to date. Only `mastered` is kept: the first version's mastery points
-- and permanent pips (29-30 Oct, never in a live game) go.
function SkillTrees.migrate(data)
	local s = data.skills
	if type(s) ~= "table" then
		s = {}
		data.skills = s
	end
	if type(s.mastered) ~= "table" then
		s.mastered = {}
	end
	for id, v in s.mastered do
		if v ~= true or not Tree.tree(id) then
			s.mastered[id] = nil
		end
	end
	s.mp, s.earned, s.levels, s.owned = nil, nil, nil, nil
	s.v = VERSION
	migrated[data] = true
	return s
end

local function ensure(data)
	if migrated[data] and type(data.skills) == "table" then
		return data.skills
	end
	return SkillTrees.migrate(data)
end

-- This run's pips: { [toolId] = { [skillId] = pips } } (a saved run from before skill trees has none yet).
local function runSkills(run)
	local rs = run.skills
	if type(rs) ~= "table" then
		rs = {}
		run.skills = rs
	end
	return rs
end

local function levelsOf(run, id: string)
	local rs = runSkills(run)
	local lv = rs[id]
	if type(lv) ~= "table" then
		lv = {}
		rs[id] = lv
	end
	return lv
end

-- Owned in this run: tools are bought in order, so every tool up to run.tool (a forever Robux tool lifts run.tool).
local function owns(data, index: number?, id: string): boolean
	local run = data.run
	if type(run) ~= "table" or not index then
		return false
	end
	return index <= (tonumber(run.tool) or 1) or (data.tools ~= nil and data.tools[id] == true)
end

-- The best weapon owned this run: the only one whose tree takes pips.
local function bestId(data): string?
	local run = data.run
	if type(run) ~= "table" then
		return nil
	end
	local best = math.clamp(math.floor(tonumber(run.tool) or 1), 1, #Config.TOOLS)
	for id in data.tools or {} do
		local i = Config.toolIndex(id)
		if i and i > best then
			best = i
		end
	end
	return Config.TOOLS[best].id
end

-- What shared/SkillTrees.check needs for one weapon.
local function state(data, id: string)
	local run = data.run
	local _, i = toolDef(id)
	return {
		levels = if type(run) == "table" then levelsOf(run, id) else {},
		owned = owns(data, i, id),
		best = bestId(data) == id,
		coins = if type(run) == "table" then run.coins else 0,
		runSkills = if type(run) == "table" then runSkills(run) else {},
		inRun = type(run) == "table" and inRun(),
	}
end

-- What the client draws (the snapshot's `skills`, from Main): { inRun, best, trees = { [toolId] = { levels, owned,
-- mastered } } }. Its coins are the snapshot's run.coins.
function SkillTrees.view(data)
	if not ON then
		return nil
	end
	local s = ensure(data)
	local trees = {}
	for i, def in Config.TOOLS do
		if Tree.tree(def.id) then
			local run = data.run
			trees[def.id] = {
				levels = if type(run) == "table" then levelsOf(run, def.id) else {},
				owned = owns(data, i, def.id),
				mastered = s.mastered[def.id] == true,
			}
		end
	end
	return { inRun = type(data.run) == "table" and inRun(), best = bestId(data), trees = trees }
end

-- The weapon has been mastered (every pip full in some run): forever.
function SkillTrees.isMastered(player: Player, toolId: string): boolean
	local data = PlayerData.get(player)
	return ON and data ~= nil and ensure(data).mastered[toolId] == true
end

-- `fn(player, toolId)` runs when a player masters a weapon for the first time.
function SkillTrees.onMastered(fn: (Player, string) -> ())
	table.insert(masteredHooks, fn)
end

-------------------------------------------------------------------------------------------------------------
-- the skills at work
-------------------------------------------------------------------------------------------------------------
-- The held tool's Config entry with this run's skills on (server/Tools.equipped returns this instead): damage x the
-- Power skill (ADDED to the player's power like the old Power upgrade: shared/SkillTrees.damageMult), cooldown x
-- Speed, radius x Width. Swing tools also get the SkillCooldown attribute (client/Input swings as often as the server
-- allows), a mastered weapon the Mastered attribute. Cached per player and tool until a pip is bought, the player's
-- power changes or a new run starts.
function SkillTrees.boost(player: Player, def, tool: Instance?)
	if not ON or type(def) ~= "table" or not Tree.tree(def.id) then
		return def
	end
	local data = PlayerData.get(player)
	if not data or type(data.run) ~= "table" then
		return def
	end
	local power = require(script.Parent.Stats).compute(player, data).power
	local byTool = boosted[player]
	if not byTool then
		byTool = {}
		boosted[player] = byTool
	end
	local b = byTool[def.id]
	if not b or b.skillPowerBase ~= power or b.skillRun ~= data.run then
		local m = Tree.mults(def.id, levelsOf(data.run, def.id))
		local vip = if player:GetAttribute("Pass_VIP") == true then 1.15 else 1
		b = table.clone(def)
		b.damage = def.damage * Tree.damageMult(m.power, power, vip)
		if def.cooldown then
			b.cooldown = def.cooldown * m.cooldown
		end
		b.radius = def.radius * m.radius
		b.skillCooldown = if def.cooldown and m.cooldown < 0.9999 then m.cooldown else nil
		b.skillPowerBase = power
		b.skillRun = data.run -- a new run (new run table, no pips yet) makes it again
		byTool[def.id] = b
	end
	if tool and tool:IsA("Tool") then
		if tool:GetAttribute("SkillCooldown") ~= b.skillCooldown then
			tool:SetAttribute("SkillCooldown", b.skillCooldown)
		end
		local mastered = ensure(data).mastered[def.id] == true or nil
		if tool:GetAttribute("Mastered") ~= mastered then
			tool:SetAttribute("Mastered", mastered)
		end
	end
	return b
end

-- The weapon a cut counts for: the one in your hand, if you own it (not a first-timer's loan) and you aren't driving
-- a ride-on mower.
local function cuttingWith(player: Player, data): string?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ToolId")
	if type(id) ~= "string" or tool:GetAttribute("Loaner") or not Tree.tree(id) then
		return nil
	end
	local _, i = toolDef(id)
	if not owns(data, i, id) or require(script.Parent.Mowers).driving(player) then
		return nil
	end
	return id
end

-- server/Run's onCut: a clump was chopped down and its bundles dropped. The Harvest skill of the weapon in hand may
-- drop one more.
function SkillTrees.onCut(player: Player, patch)
	local data = ON and PlayerData.get(player)
	if not data or type(data.run) ~= "table" or type(patch) ~= "table" or not patch.part then
		return
	end
	local id = cuttingWith(player, data)
	local harvest = if id then Tree.mults(id, levelsOf(data.run, id)).harvest else 0
	if harvest > 0 and rng:NextNumber() < harvest then
		local land = patch.landPos or patch.part.Position
		require(script.Parent.Loot).drop(player, "bundle", land, patch.z, patch.mut, nil, require(script.Parent.Field).FALL_TIME)
		Net.send(player, "Fx", "skillHarvest", { pos = land })
	end
end

-------------------------------------------------------------------------------------------------------------
-- buying a pip
-------------------------------------------------------------------------------------------------------------
local function refreshTools(player: Player)
	boosted[player] = nil
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		for _, t in if container then container:GetChildren() else {} do
			local def = t:IsA("Tool") and toolDef(t:GetAttribute("ToolId") or "")
			if def then
				SkillTrees.boost(player, def, t)
			end
		end
	end
end

local WHY = {
	lobby = "Weapon skills are bought in a run.",
	locked = "Buy the %s in this run to open its skill tree!",
	past = "Only your best weapon learns skills now: the %s's tree is done for this run.",
	max = "%s is maxed!",
	oneARun = "One weapon can be maxed a run: the rest of the %s's tree waits for the next run.",
	coins = "Not enough coins!",
}

local function buy(player: Player, toolId: any, skillId: any)
	local now = os.clock()
	if (lastBuy[player] or 0) + BUY_GAP > now then
		return
	end
	lastBuy[player] = now
	local data = PlayerData.get(player)
	local sk = Tree.skill(toolId, skillId)
	local def = sk and toolDef(toolId)
	if not data or not sk or not def then
		return
	end
	local st = state(data, def.id)
	local ok, why, price = Tree.check(def.id, sk.id, st)
	if not ok or not price then
		local text = WHY[why or ""]
		if text then
			Net.notify(player, text:format(if why == "max" then sk.name else def.name), if why == "max" then "yellow" else "red")
		end
		return
	end
	data.run.coins -= price
	st.levels[sk.id] = Tree.level(st.levels, sk.id) + 1
	refreshTools(player)
	local s = ensure(data)
	if Tree.isFull(def.id, st.levels) and not s.mastered[def.id] then
		-- the first time: MASTERED for good (banner, confetti and the server's cheer only now)
		s.mastered[def.id] = true
		refreshTools(player)
		Net.send(player, "Fx", "skillMastered", { tool = def.id })
		Net.notifyAll(("%s MASTERED the %s!"):format(player.DisplayName, def.name), "yellow")
		for _, fn in masteredHooks do
			task.spawn(fn, player, def.id)
		end
		task.spawn(PlayerData.save, player)
	else
		Net.send(player, "Fx", "purchase", {})
	end
	Net.send(player, "Fx", "skillPip", { tool = def.id, skill = sk.id, level = st.levels[sk.id], full = Tree.isFull(def.id, st.levels) })
	PlayerData.changed(player)
end

-------------------------------------------------------------------------------------------------------------
-- Studio test hook (never in live games; Studio never saves): ServerStorage.SkillTreeDev:Invoke(cmd, player?, ...)
--   ("max", player, toolId?)    this run: every pip of the best weapon (or toolId) but the last one
--   ("master", player, toolId)  mastered for good (the gold page, without the celebration)
--   ("reset", player)           this run's pips and every mastery gone
-- (coins: ServerStorage.DevHook:Invoke("coins", nil, 1e7))
-------------------------------------------------------------------------------------------------------------
local function devHook()
	local hook = Instance.new("BindableFunction")
	hook.Name = "SkillTreeDev"
	hook.OnInvoke = function(cmd: string, who: any, id: any)
		local player = if typeof(who) == "Instance" and who:IsA("Player") then who else Players:GetPlayers()[1]
		local data = player and PlayerData.get(player)
		if not data then
			return false
		end
		local s = ensure(data)
		if cmd == "max" and type(data.run) == "table" then
			local target = if type(id) == "string" then id else bestId(data)
			local tree = Tree.tree(target)
			if not tree then
				return false
			end
			local lv = levelsOf(data.run, target :: string)
			for i, sk in tree.skills do
				lv[sk.id] = if i == #tree.skills then Tree.PIPS - 1 else Tree.PIPS
			end
		elseif cmd == "master" and Tree.tree(id) then
			s.mastered[id] = true
		elseif cmd == "reset" then
			table.clear(s.mastered)
			if type(data.run) == "table" then
				data.run.skills = {}
			end
		else
			return false
		end
		refreshTools(player)
		PlayerData.changed(player)
		return true
	end
	hook.Parent = ServerStorage
end

function SkillTrees.start()
	if started or not ON then
		return
	end
	started = true
	PlayerData.onLoaded(function(_player, data)
		SkillTrees.migrate(data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		boosted[player] = nil
		lastBuy[player] = nil
	end)
	-- (Net makes the remote from its INBOUND list: without the "Skill" line buying is off, but nothing else breaks)
	local ok, err = pcall(Net.on, "Skill", 4, buy)
	if not ok then
		warn("[SkillTrees] no \"Skill\" remote (server/Net's INBOUND list needs its line): buying pips is off. " .. tostring(err))
	end
	if RunService:IsStudio() then
		devHook()
	end
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
if hashOf(src) ~= "14573 299627822" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.ServerScriptService.MowALawn
local old = folder:FindFirstChild("SkillTrees")
if old then
	local now = hashOf(old.Source)
	if now == "14573 299627822" then
		return "SkillTrees is already this version: " .. now
	elseif now ~= "13889 1193936855" then
		return "NOT CHANGED: SkillTrees is there but isn't the first version (" .. now .. "): ask before replacing it"
	end
	old.Source = src
	return "SkillTrees updated from the first version: " .. hashOf(old.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "SkillTrees"
m.Source = src
m.Parent = folder
return "SkillTrees installed: " .. hashOf(m.Source)
