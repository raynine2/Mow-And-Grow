local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.CampLife
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "20298 1059054880" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[			table.insert(group, if type(g) == "string" then g else nil)
]======], [======[			-- set by the part's own index: table.insert(group, nil) adds nothing, which slid every later group name
			-- onto the wrong part (the windmill's tower turned with its sails, villagers' arms moved as heads)
			group[#parts] = if type(g) == "string" then g else nil
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "20504 1082693149" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
