local m = game.ReplicatedStorage.MowALawn.Config
local s = m.Source
if string.find(s, [======[theme = "galaxy"]======], 1, true) then
	return m.Name .. " already has this patch"
end
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local edits = {
	{ [======[	panel = Color3.fromRGB(255, 245, 225),
	dark = Color3.fromRGB(45, 40, 65),
}
]======], [======[	panel = Color3.fromRGB(255, 245, 225),
	dark = Color3.fromRGB(45, 40, 65),
	-- (30 Oct, owner: "remake the ui ... to a grass galaxy theme mix ... use forge gui") "galaxy": the windows, cards,
	-- buttons, plates, ribbons and round menu buttons are the ForgeGUI grass-galaxy kit (assets/icons/gg_*.png: a night
	-- sky inside, a rim of grass and clovers), client/Skin swaps them in. "garden": the wooden garden kit from before.
	theme = "galaxy",
	-- the galaxy kit's colours: words on the night sky, the dim line under them, the glass cards, the grass
	night = Color3.fromRGB(30, 18, 70),
	glass = Color3.fromRGB(58, 34, 112),
	starText = Color3.fromRGB(240, 234, 255),
	dimText = Color3.fromRGB(190, 176, 236),
	leaf = Color3.fromRGB(126, 222, 64),
}
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "NOT CHANGED: edit " .. k .. " not found once in " .. m.Name
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
