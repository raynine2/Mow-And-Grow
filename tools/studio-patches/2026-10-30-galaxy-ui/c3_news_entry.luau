local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.NewsWindow
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "9900 1618247114" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	local color = if selected then W.tabOn else Color3.fromRGB(176, 120, 72)
]======], [======[	-- (grass-galaxy: the others violet like the windows' tabs, not the garden kit's brown)
	local color = if selected then W.tabOn elseif C.theme == "galaxy" then W.tabWood else Color3.fromRGB(176, 120, 72)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "10031 1656155303" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
