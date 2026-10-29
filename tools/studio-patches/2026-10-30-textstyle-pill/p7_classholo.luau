local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ClassHolo
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "16278 1798344101" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
if not string.find(s, "\nlocal Config = ", 1, true) then
	return "NOT CHANGED: no Config in " .. m.Name
end
local edits = {
	{ [======[	news.Font = Enum.Font.LuckiestGuy
]======], [======[	news.Font = Config.UI.font
]======] },
	{ [======[	local rarity = label(80, 34, 30, Enum.Font.GothamBold)
	local clock = label(132, 30, 24, Enum.Font.GothamBold)
]======], [======[	local rarity = label(80, 34, 30, Config.UI.font)
	local clock = label(132, 30, 24, Config.UI.font)
]======] },
	{ [======[	local name = label(26, 50, 40, Enum.Font.LuckiestGuy)
]======], [======[	local name = label(26, 50, 40, Config.UI.font)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
-- (Studio's ClassHolo differs from git's, so there is no exact result to check: each edit was found exactly once)
m.Source = s
return m.Name .. " done: " .. hashOf(s)
