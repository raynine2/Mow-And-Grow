-- Stats: the tools' power no longer has the old Power upgrade in it (their skill trees add theirs:
-- server/SkillTrees.boost); ride-on mowers keep it as `mowerPower` (the upgrade is the Mower section's "Mower Blades"
-- now, same id "power"). Studio's copy differs from git's: the power line is found by its piece
-- `level("power") * per("power")` (once), and its two new lines are made from Studio's own line.
local m = game.ServerScriptService.MowALawn.Stats
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "3739 382049001" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local piece = [=[ + level("power") * per("power")]=]
local i, j = string.find(s, piece, 1, true)
if not i or string.find(s, piece, j + 1, true) then
	return "NOT CHANGED: `" .. piece .. "` not found once"
end
local ls = (string.find(string.reverse(string.sub(s, 1, i)), "\n", 1, true))
local lineStart = if ls then i - ls + 2 else 1
local lineEnd = (string.find(s, "\n", j, true) or #s + 1) - 1
local line = string.sub(s, lineStart, lineEnd)
if not string.find(line, "s.power = ", 1, true) or string.find(line, "--", 1, true) then
	return "NOT CHANGED: the line with the Power upgrade isn't a plain `s.power = ...` line: " .. line
end
local tools = (string.gsub(line, piece:gsub("%p", "%%%0"), "", 1))
local mowers = (string.gsub(line, "s%.power = ", "s.mowerPower = ", 1))
	.. ' -- (30 Oct) ride-on mowers keep the old Power upgrade ("Mower Blades"); the tools get theirs from their skill trees (server/SkillTrees)'
s = string.sub(s, 1, lineStart - 1) .. tools .. "\n" .. mowers .. string.sub(s, lineEnd + 1)
m.Source = s
return m.Name .. " done: " .. hashOf(s)
