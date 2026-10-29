local m = game.ServerScriptService.MowALawn.Outposts
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "25651 457739061" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	bench(f, at(-14.5, 1, right))
	bench(f, at(12, 4, -right))
]======], [======[	bench(f, at(-16, 2, right))
	bench(f, at(16, 5, -right))
]======] },
	{ [======[		gasPump(f, base + right * 12 + fwd * -3, info, -right)
]======], [======[		gasPump(f, base + right * 16 + fwd * -4, info, -right)
]======] },
	{ [======[	stall(f, at(-6.5, -11), "SHOP", "Shop", th, rng, def.id)
	stall(f, at(6.5, -11), "UPGRADES", "Upgrades", th, rng, def.id)
]======], [======[	-- (29 Oct, owner: "why is the middle so close to the stores": they stood against the pad's 9-stud ring) set back
	-- on the bigger plaza, an open ring round the pad
	stall(f, at(-7.5, -16), "SHOP", "Shop", th, rng, def.id)
	stall(f, at(7.5, -16), "UPGRADES", "Upgrades", th, rng, def.id)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "25816 1841533535" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
