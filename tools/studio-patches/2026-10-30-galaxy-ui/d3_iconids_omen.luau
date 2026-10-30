local m = game.ReplicatedStorage.MowALawn.IconIds
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "6032 657260351" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	newspaper = "rbxassetid://71805986250786",
	paw = "rbxassetid://104057465630094",
]======], [======[	newspaper = "rbxassetid://71805986250786",
	omen_banner = "rbxassetid://83618748137117",
	omen_beam = "rbxassetid://115404613156820",
	omen_eye = "rbxassetid://112397504018633",
	omen_lines = "rbxassetid://139240077469365",
	omen_ring = "rbxassetid://113039136612686",
	omen_vignette = "rbxassetid://77424499357327",
	paw = "rbxassetid://104057465630094",
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "6306 1429822840" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
