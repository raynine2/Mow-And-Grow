local results = {}
table.insert(results, "p1_lobbykit: " .. tostring((function()
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

end)()))
table.insert(results, "p2_campbuildings: " .. tostring((function()
local m = game.ServerScriptService.MowALawn.CampBuildings
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "56863 1152258283" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	label.Font = Enum.Font.LuckiestGuy
]======], [======[	label.Font = Enum.Font.FredokaOne
]======] },
	{ [======[-- Chop A Forest's sign style text on the -Z face of `part`.
]======], [======[-- Sign text in our UI font (Fredoka One) on the -Z face of `part`.
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "56869 1882550476" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)

end)()))
table.insert(results, "p3_propkit: " .. tostring((function()
local m = game.ServerScriptService.MowALawn.PropKit
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "27529 622129584" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	label.Font = Enum.Font.LuckiestGuy
]======], [======[	label.Font = Config.UI.font
]======] },
	{ [======[	-- Chop A Forest's sign style: Luckiest Guy, orange gradient, thick brown outline (`color` tints the top)
]======], [======[	-- the sign style: our UI font (Fredoka One), orange gradient, thick brown outline (`color` tints the top)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "27523 2001136832" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)

end)()))
table.insert(results, "p4_blackhole: " .. tostring((function()
local m = game.ServerScriptService.MowALawn.BlackHole
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "26233 484891119" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	sub.Font = Enum.Font.LuckiestGuy
]======], [======[	sub.Font = Config.UI.font
]======] },
	{ [======[	title.Font = Enum.Font.LuckiestGuy
]======], [======[	title.Font = Config.UI.font
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "26219 651625050" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)

end)()))
table.insert(results, "p5_forgedress: " .. tostring((function()
local m = game.ServerScriptService.MowALawn.ForgeDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "14386 814048114" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	title.Font = Enum.Font.LuckiestGuy
]======], [======[	title.Font = Enum.Font.FredokaOne
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "14385 1353583866" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)

end)()))
table.insert(results, "p6_worldgen: " .. tostring((function()
local m = game.ServerScriptService.MowALawn.WorldGen
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "26019 1113332630" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	t.Position = UDim2.fromScale(0.15, 0.35)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
]======], [======[	t.Position = UDim2.fromScale(0.15, 0.35)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
]======] },
	{ [======[		t.Font = Enum.Font.Arcade
]======], [======[		t.Font = Enum.Font.FredokaOne
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "26027 1156192527" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)

end)()))
table.insert(results, "p7_classholo: " .. tostring((function()
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

end)()))
table.insert(results, "p8_client: " .. tostring((function()
-- client/Client: two lines (Studio's copy differs from git's: anchored on lines both have)
local cl = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Client
local s = cl.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "4015 1171987577" then
	return "NOT CHANGED: Client is " .. hashOf(s)
end
local adds = {
	{ 'local State = require(modules:WaitForChild("State"))\n', 'require(modules:WaitForChild("TextStyle")) -- every text in our UI style: Fredoka One, the dark outline, gold headlines\n' },
	{ 'require(modules:WaitForChild("Settings"))', 'require(modules:WaitForChild("PotatoPill")) -- the "Potato: OFF" pill in Roblox\'s top bar, beside Roblox\'s buttons\n' },
}
for k, a in adds do
	local i = string.find(s, a[1], 1, true)
	if not i or string.find(s, a[1], i + 1, true) then
		return "line " .. k .. ": anchor not found once"
	end
	local j = string.find(s, "\n", i, true)
	s = string.sub(s, 1, j) .. a[2] .. string.sub(s, j + 1)
end
cl.Source = s
return "Client done: " .. hashOf(s)

end)()))
return table.concat(results, "\n")
