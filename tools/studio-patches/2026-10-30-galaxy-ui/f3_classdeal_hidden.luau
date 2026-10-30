local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ClassDeal
local s = m.Source
if string.find(s, [======[(c :: any).hidden and not owned]======], 1, true) then
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
	{ [======[		if tab == "stock" and c.gems <= 0 and not owned then
			continue
		end
		card(c, i, d, stock)
]======], [======[		if tab == "stock" and c.gems <= 0 and not owned then
			continue
		end
		if (c :: any).hidden and not owned then
			continue -- (30 Oct: hidden until its feature opens, shared/Config MOWERS_LOCKED)
		end
		card(c, i, d, stock)
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
