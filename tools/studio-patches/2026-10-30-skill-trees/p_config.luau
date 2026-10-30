-- Config: Config.SKILL_TREES, and the Upgrades window's "Tool" section goes (the weapon skill trees replace it).
-- Studio's copy differs from git's, so each change is anchored on a short piece of one line that both copies have;
-- it must be found exactly once, and nothing changes if the script isn't the copy this was made for.
-- The Tool section is found by its own lines (`section = "Tool"`), not by git's exact text: it must be one line, the
-- Power upgrade (id "power"). That line stays, as the Mower section's "Mower Blades" (same id and numbers, so a saved
-- run's levels keep powering its ride-on mowers; server/Stats mowerPower), and "Tool" leaves UPGRADE_SECTIONS.
local m = game.ReplicatedStorage.MowALawn.Config
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "93131 925977069" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local function plainCount(text, piece)
	local n, from = 0, 1
	while true do
		local i, j = string.find(text, piece, from, true)
		if not i then
			return n
		end
		n += 1
		from = j + 1
	end
end
-- the Power upgrade's line -> Mower Blades (its own per/base/growth/max are kept)
local function toBlades(line)
	if not string.find(line, 'id = "power"', 1, true) then
		return nil, 'the one `section = "Tool"` line is not the Power upgrade (id "power")'
	end
	local per = tonumber(string.match(line, "per = ([%d%.]+)"))
	if not per then
		return nil, "the Power upgrade's line has no `per = <number>`"
	end
	local out = string.gsub(line, 'section = "Tool"', 'section = "Mower"', 1)
	local n1, n2
	out, n1 = string.gsub(out, 'name = "[^"]*"', 'name = "Mower Blades"', 1)
	out, n2 = string.gsub(out, 'desc = "[^"]*"', ('desc = "+%d%%%% ride-on mower cutting power"'):format(math.floor(per * 100 + 0.5)), 1)
	if n1 ~= 1 or n2 ~= 1 then
		return nil, "the Power upgrade's line has no name / desc field"
	end
	return out .. ' -- (30 Oct) was the "Tool" section\'s Power: the tools\' power is in their skill trees now (shared/SkillTrees); the id stays, so a saved run\'s levels keep powering its mowers'
end
local function noToolSection(line)
	if plainCount(line, '"Tool", ') ~= 1 then
		return nil, 'UPGRADE_SECTIONS does not list "Tool", exactly once'
	end
	return (string.gsub(line, '"Tool", ', "", 1))
end
-- { kind, anchor, text }: "after" adds `text` as a new line after the anchor's line; "swap" replaces the anchor;
-- "line" replaces the anchor's whole line with text(line)
local edits = {
	{ "after", [======[Config.BOSS_TOOL_MULT = ]======], [======[Config.SKILL_TREES = require(script.Parent:WaitForChild("SkillTrees")) -- (30 Oct) weapon skill trees: every number in shared/SkillTrees]======] },
	{ "line", [======[Config.UPGRADE_SECTIONS = ]======], noToolSection },
	{ "line", [======[section = "Tool"]======], toBlades },
}
for k, e in edits do
	local n = plainCount(s, e[2])
	if n ~= 1 then
		return "NOT CHANGED: edit " .. k .. ": `" .. e[2] .. "` found " .. n .. " times (must be once)"
	end
end
for k, e in edits do
	local i, j = string.find(s, e[2], 1, true)
	local ls = (string.find(string.reverse(string.sub(s, 1, i)), "\n", 1, true))
	local lineStart = if ls then i - ls + 2 else 1
	local lineEnd = (string.find(s, "\n", j, true) or #s + 1) - 1
	if e[1] == "after" then
		s = string.sub(s, 1, lineEnd + 1) .. e[3] .. "\n" .. string.sub(s, lineEnd + 2)
	elseif e[1] == "swap" then
		s = string.sub(s, 1, i - 1) .. e[3] .. string.sub(s, j + 1)
	else
		local new, why = e[3](string.sub(s, lineStart, lineEnd))
		if not new then
			return "NOT CHANGED: edit " .. k .. ": " .. why
		end
		s = string.sub(s, 1, lineStart - 1) .. new .. string.sub(s, lineEnd + 1)
	end
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
