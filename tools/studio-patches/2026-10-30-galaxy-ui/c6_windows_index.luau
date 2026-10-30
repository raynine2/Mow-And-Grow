local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Windows
local s = m.Source
if string.find(s, [======[elseif C.theme == "galaxy" then Color3.fromRGB(70, 48, 140)]======], 1, true) then
	return m.Name .. " already has this patch"
end
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local edits = {
	{ [======[			local color = if got then (m.color or zone.grass[1]) else Color3.fromRGB(60, 52, 48)
]======], [======[			local color = if got then (m.color or zone.grass[1]) elseif C.theme == "galaxy" then Color3.fromRGB(70, 48, 140) else Color3.fromRGB(60, 52, 48)
]======] },
	{ [======[else Color3.fromRGB(110, 94, 80)
]======], [======[elseif C.theme == "galaxy" then Color3.fromRGB(70, 48, 140) else Color3.fromRGB(110, 94, 80)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "NOT CHANGED: edit " .. k .. " not found once in " .. m.Name
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
