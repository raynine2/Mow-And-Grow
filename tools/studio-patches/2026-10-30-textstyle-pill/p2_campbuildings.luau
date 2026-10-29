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
