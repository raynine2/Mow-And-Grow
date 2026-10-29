local m = game.ServerScriptService.MowALawn.LobbyKit
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "49946 58406807" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	count.Font = Enum.Font.LuckiestGuy
]======], [======[	count.Font = Config.UI.font
]======] },
	{ [======[	top.Font = Enum.Font.LuckiestGuy
]======], [======[	top.Font = Config.UI.font
]======] },
	{ [======[	banner.Font = Enum.Font.LuckiestGuy
]======], [======[	banner.Font = Config.UI.font
]======] },
	{ [======[	l.Font = Enum.Font.LuckiestGuy
]======], [======[	l.Font = Config.UI.font
]======] },
	{ [======[-- Big sign text: Luckiest Guy with an orange gradient and a thick brown outline on a part's front face.
]======], [======[-- Big sign text: our UI font (Fredoka One) with an orange gradient and a thick brown outline on a part's front face.
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "49931 27065349" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
