-- Creates src/server/SkillTrees.luau in Studio (a new ModuleScript, exactly git's text). Run in Edit mode.
local src = [=====[
-- WEAPON SKILL TREES, the server side. The numbers are shared/SkillTrees (Config.SKILL_TREES), the window
-- client/SkillTreeWindow. Works in the lobby and in runs; mastery points are only earned in runs.
--
-- The profile's part (profile.skills), made and kept up to date by SkillTrees.migrate (the schema default and the
-- migration of older profiles, run when a profile loads and before any use, so server/PlayerData needs nothing):
--   skills = {
--     v = 1,
--     mp = { [toolId] = n },                        mastery points left to spend
--     earned = { [toolId] = n },                    every mastery point ever earned with that weapon
--     levels = { [toolId] = { [skillId] = pips } }, the pips bought
--     owned = { [toolId] = true },                  weapons ever owned (bought in a run, or forever with Robux): their
--                                                   tree is open for good; the rest show LOCKED
--     mastered = { [toolId] = true },               every pip of that tree full: the gold tree. Later code hooks in
--                                                   with SkillTrees.isMastered(player, toolId) / SkillTrees.onMastered
--   }
--
-- Hooks in other files, one line each: Main (SkillTrees.start, and `skills` in the snapshot), Net (the "Skill"
-- remote), Tools.equipped (the held tool's numbers with its skills: SkillTrees.boost), Run's onCut (mastery points and
-- Harvest: SkillTrees.onCut), client/Input (a shorter swing: the tool's SkillCooldown attribute).
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

local VERSION = 1
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

-------------------------------------------------------------------------------------------------------------
-- the profile
-------------------------------------------------------------------------------------------------------------
-- Make profile.skills (a new or old profile) or bring it up to date: every table there, every weapon's numbers whole
-- and not negative, `mastered` matching the pips. Stored pips above Tree.PIPS are kept (they count as PIPS), so
-- lowering PIPS and raising it again loses nothing.
function SkillTrees.migrate(data)
	local s = data.skills
	if type(s) ~= "table" then
		s = {}
		data.skills = s
	end
	for _, key in { "mp", "earned", "levels", "owned", "mastered" } do
		if type(s[key]) ~= "table" then
			s[key] = {}
		end
	end
	for _, def in Config.TOOLS do
		local id = def.id
		local tree = Tree.tree(id)
		if tree then
			s.mp[id] = count(s.mp[id])
			s.earned[id] = count(s.earned[id])
			local lv = s.levels[id]
			if type(lv) ~= "table" then
				lv = {}
				s.levels[id] = lv
			end
			for _, sk in tree.skills do
				lv[sk.id] = count(lv[sk.id])
			end
			s.mastered[id] = if Tree.isMastered(id, lv) then true else nil
			if s.owned[id] ~= nil and s.owned[id] ~= true then
				s.owned[id] = nil
			end
		end
	end
	s.owned[Config.TOOLS[1].id] = true -- bare hands: everyone has them
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

-- A weapon's tree opens for good once you own it: bought in a run (tools are bought in order, so every tool up to
-- run.tool), or forever with Robux (data.tools).
local function markOwned(data, s)
	for id in data.tools or {} do
		if Tree.tree(id) then
			s.owned[id] = true
		end
	end
	local run = data.run
	local best = if type(run) == "table" then tonumber(run.tool) else nil
	if best then
		for i = 1, math.min(math.floor(best), #Config.TOOLS) do
			s.owned[Config.TOOLS[i].id] = true
		end
	end
end

-- What the client draws (the snapshot's `skills`, from Main): { [toolId] = { mp, earned, owned, mastered, levels } }.
-- (Also records weapons bought since the last look.)
function SkillTrees.view(data)
	if not ON then
		return nil
	end
	local s = ensure(data)
	markOwned(data, s)
	local out = {}
	for _, def in Config.TOOLS do
		local id = def.id
		if Tree.tree(id) then
			out[id] = {
				mp = s.mp[id] or 0,
				earned = s.earned[id] or 0,
				owned = s.owned[id] == true,
				mastered = s.mastered[id] == true,
				levels = s.levels[id] or {},
			}
		end
	end
	return out
end

-- Every pip of `toolId`'s tree is bought (the gold tree).
function SkillTrees.isMastered(player: Player, toolId: string): boolean
	local data = PlayerData.get(player)
	return ON and data ~= nil and ensure(data).mastered[toolId] == true
end

-- `fn(player, toolId)` runs when a player masters a weapon (the last pip of its tree), once per weapon.
function SkillTrees.onMastered(fn: (Player, string) -> ())
	table.insert(masteredHooks, fn)
end

-------------------------------------------------------------------------------------------------------------
-- the skills at work
-------------------------------------------------------------------------------------------------------------
-- The held tool's Config entry with its skills on (server/Tools.equipped returns this instead): damage x power,
-- cooldown x speed, radius x width. Swing tools also get the SkillCooldown attribute, so client/Input lets you swing
-- as often as the server allows. Cached per player and tool until a pip is bought.
function SkillTrees.boost(player: Player, def, tool: Instance?)
	if not ON or type(def) ~= "table" or not Tree.tree(def.id) then
		return def
	end
	local data = PlayerData.get(player)
	if not data then
		return def
	end
	local byTool = boosted[player]
	if not byTool then
		byTool = {}
		boosted[player] = byTool
	end
	local b = byTool[def.id]
	if not b then
		local m = Tree.mults(def.id, ensure(data).levels[def.id])
		b = table.clone(def)
		b.damage = def.damage * m.damage
		if def.cooldown then
			b.cooldown = def.cooldown * m.cooldown
		end
		b.radius = def.radius * m.radius
		b.skillCooldown = if def.cooldown and m.cooldown < 0.9999 then m.cooldown else nil
		byTool[def.id] = b
	end
	if tool and tool:IsA("Tool") and tool:GetAttribute("SkillCooldown") ~= b.skillCooldown then
		tool:SetAttribute("SkillCooldown", b.skillCooldown)
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
	if not i or (i > (data.run.tool or 1) and not (data.tools and data.tools[id])) then
		return nil
	end
	if require(script.Parent.Mowers).driving(player) then
		return nil
	end
	return id
end

-- server/Run's onCut: a clump was chopped down and its bundles dropped. The weapon in hand gets its mastery points (if
-- the clump grows in its own areas or later: Tree.earns), and its Harvest skill may drop one more bundle (anywhere).
function SkillTrees.onCut(player: Player, patch)
	local data = ON and PlayerData.get(player)
	if not data or not data.run or type(patch) ~= "table" then
		return
	end
	local id = cuttingWith(player, data)
	if not id then
		return
	end
	local s = ensure(data)
	s.owned[id] = true
	if Tree.earns(id, patch.z) then
		local pts = if patch.elder then Tree.POINTS.elder else Tree.POINTS.clump
		s.mp[id] = (s.mp[id] or 0) + pts
		s.earned[id] = (s.earned[id] or 0) + pts
	end
	local harvest = Tree.mults(id, s.levels[id]).harvest
	if harvest > 0 and rng:NextNumber() < harvest and patch.part then
		local land = patch.landPos or patch.part.Position
		require(script.Parent.Loot).drop(player, "bundle", land, patch.z, patch.mut, nil, require(script.Parent.Field).FALL_TIME)
		Net.send(player, "Fx", "skillHarvest", { pos = land })
	end
	PlayerData.changed(player)
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

local function mastered(player: Player, def)
	Net.send(player, "Fx", "skillMastered", { tool = def.id })
	Net.notifyAll(("%s MASTERED the %s!"):format(player.DisplayName, def.name), "yellow")
	for _, fn in masteredHooks do
		task.spawn(fn, player, def.id)
	end
end

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
	local s = ensure(data)
	markOwned(data, s)
	local lv = s.levels[def.id]
	local ok, why, mp, gems = Tree.check(def.id, sk.id, { mp = s.mp[def.id], owned = s.owned[def.id], levels = lv }, data.gems)
	if not ok or not mp then
		if why == "locked" then
			Net.notify(player, "Buy the " .. def.name .. " in a run to open its skill tree!", "red")
		elseif why == "max" then
			Net.notify(player, sk.name .. " is maxed!", "yellow")
		elseif why == "mp" then
			Net.notify(player, "Not enough mastery points! Chop grass with the " .. def.name .. ".", "red")
		elseif why == "gems" then
			Net.notify(player, "Not enough gems!", "red")
		end
		return
	end
	local level = Tree.level(lv, sk.id)
	s.mp[def.id] -= mp
	data.gems -= gems
	lv[sk.id] = level + 1
	refreshTools(player)
	if Tree.isMastered(def.id, lv) and not s.mastered[def.id] then
		s.mastered[def.id] = true
		mastered(player, def)
	else
		Net.send(player, "Fx", "purchase", {})
	end
	Net.send(player, "Fx", "skillPip", { tool = def.id, skill = sk.id, level = level + 1 })
	PlayerData.changed(player)
	task.spawn(PlayerData.save, player)
end

-------------------------------------------------------------------------------------------------------------
-- Studio test hook (never in live games): ServerStorage.SkillTreeDev:Invoke(cmd, player?, ...)
--   ("mp", player, amount, toolId?)  give mastery points to one weapon (or all), and open its tree
--   ("max", player, toolId?)         fill every pip of one weapon (or all) but the last: the next buy masters it
--   ("reset", player, toolId?)       empty the pips and mastery points
-------------------------------------------------------------------------------------------------------------
local function devHook()
	local hook = Instance.new("BindableFunction")
	hook.Name = "SkillTreeDev"
	hook.OnInvoke = function(cmd: string, who: any, a: any, b: any)
		local player = if typeof(who) == "Instance" and who:IsA("Player") then who else Players:GetPlayers()[1]
		local data = player and PlayerData.get(player)
		if not data then
			return false
		end
		local s = ensure(data)
		local only = if cmd == "mp" then b else a
		for _, def in Config.TOOLS do
			local tree = Tree.tree(def.id)
			if tree and (only == nil or only == def.id) then
				if cmd == "mp" then
					s.mp[def.id] += count(a)
					s.owned[def.id] = true
				elseif cmd == "max" then
					s.owned[def.id] = true
					for i, sk in tree.skills do
						s.levels[def.id][sk.id] = if i == #tree.skills then Tree.PIPS - 1 else Tree.PIPS
					end
					s.mastered[def.id] = nil
				elseif cmd == "reset" then
					s.mp[def.id] = 0
					table.clear(s.levels[def.id])
					s.mastered[def.id] = nil
				end
			end
		end
		SkillTrees.migrate(data)
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
		markOwned(data, SkillTrees.migrate(data))
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
if hashOf(src) ~= "13889 1193936855" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.ServerScriptService.MowALawn
if folder:FindFirstChild("SkillTrees") then
	return "SkillTrees is already there: " .. hashOf(folder.SkillTrees.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "SkillTrees"
m.Source = src
m.Parent = folder
return "SkillTrees installed: " .. hashOf(m.Source)
