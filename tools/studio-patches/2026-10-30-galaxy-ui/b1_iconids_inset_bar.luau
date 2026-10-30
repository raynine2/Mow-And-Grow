local m = game.ReplicatedStorage.MowALawn.IconIds
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "5946 1318315861" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	gg_close = "rbxassetid://121847525218809",
	gg_panel = "rbxassetid://132476287132779",
]======], [======[	gg_close = "rbxassetid://121847525218809",
	gg_inset = "rbxassetid://107128954403371",
	gg_panel = "rbxassetid://132476287132779",
]======] },
	{ [======[	gg_badge = "rbxassetid://79543216145859",
	gg_button = "rbxassetid://96028183123649",
]======], [======[	gg_badge = "rbxassetid://79543216145859",
	gg_bar = "rbxassetid://127234105615077",
	gg_button = "rbxassetid://96028183123649",
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "6032 657260351" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
