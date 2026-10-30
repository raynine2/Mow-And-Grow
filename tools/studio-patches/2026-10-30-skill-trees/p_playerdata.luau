-- PlayerData: a new run's skill tree pips (run.skills, emptied every run like the run upgrades; server/SkillTrees
-- makes it for a saved run from before). Studio's copy differs from git's: anchored on the start of newRun's
-- one-line upgrades table, which must be found once and close on its own line.
local m = game.ServerScriptService.MowALawn.PlayerData
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "11246 738900900" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local anchor = [=[upgrades = { power = 0]=]
local i, j = string.find(s, anchor, 1, true)
if not i or string.find(s, anchor, j + 1, true) then
	return "NOT CHANGED: `" .. anchor .. "` not found once"
end
local nl = string.find(s, "\n", j, true) or #s
if not string.find(string.sub(s, j, nl), "},", 1, true) then
	return "NOT CHANGED: newRun's upgrades table doesn't close on its own line"
end
s = string.sub(s, 1, nl) .. [=[		skills = {}, -- (30 Oct) weapon skill tree pips this run: [toolId] = { [skillId] = pips } (server/SkillTrees)]=] .. "\n" .. string.sub(s, nl + 1)
m.Source = s
return m.Name .. " done: " .. hashOf(s)
