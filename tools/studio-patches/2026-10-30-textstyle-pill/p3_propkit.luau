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
