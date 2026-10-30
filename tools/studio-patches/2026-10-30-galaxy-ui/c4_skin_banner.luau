local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Skin
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "26392 525706101" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		ui_soil = "gg_inset", -- (the Pets window's critter-burrow soil boxes)
	},
]======], [======[		ui_soil = "gg_inset", -- (the Pets window's critter-burrow soil boxes)
		ui_banner = "gg_panel", -- (the hanging sign: CLASS IN STOCK, the first-run coach card)
	},
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "26482 773376415" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
