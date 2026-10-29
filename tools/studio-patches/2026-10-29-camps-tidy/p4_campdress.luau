local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "45798 1572776351" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	for _, s in { { -12.4, -9.4 }, { -11.5, -6.5 }, { 12.4, -9.4 }, { 11.5, -6.5 }, { -15, -5 }, { 15, -5 } } do
]======], [======[	for _, s in { { -14.6, -12.5 }, { 14.6, -12.5 }, { -13, -10 }, { 13, -10 }, { -15, -5 }, { 15, -5 } } do
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "45794 319622153" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
