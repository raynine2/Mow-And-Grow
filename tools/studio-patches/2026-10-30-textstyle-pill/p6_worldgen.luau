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
