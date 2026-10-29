-- Tools: the held tool with its skill tree
-- Studio's copy differs from git's, so each change is anchored on a short piece of one line that both copies have;
-- it must be found exactly once, and nothing changes if the script isn't the copy this was made for.
local m = game.ServerScriptService.MowALawn.Tools
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "13779 1532520864" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
-- { kind, anchor, text }: "after" adds `text` as a new line after the anchor's line; "swap" replaces the anchor
local edits = {
	{ "swap", [======[	return Config.TOOLS[i], tool
]======], [======[	return require(script.Parent.SkillTrees).boost(player, Config.TOOLS[i], tool), tool -- (30 Oct) with its skill tree
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[2], 1, true)
	if not i or string.find(s, e[2], j + 1, true) then
		return "edit " .. k .. ": anchor not found once"
	end
	if e[1] == "after" then
		local nl = string.find(s, "\n", j, true) or #s
		s = string.sub(s, 1, nl) .. e[3] .. "\n" .. string.sub(s, nl + 1)
	else
		s = string.sub(s, 1, i - 1) .. e[3] .. string.sub(s, j + 1)
	end
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
