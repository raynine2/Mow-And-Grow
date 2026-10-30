local m = game.ServerScriptService.MowALawn.Monetization
local s = m.Source
if string.find(s, [======[a class hidden until its feature opens]======], 1, true) then
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
	{ [======[			if p.mower and Config.MOWERS_LOCKED then -- (30 Oct: never take Robux for a locked mower, shared/Config MOWERS_LOCKED)
]======], [======[			local cls = if p.class then Config.class(p.class) :: any else nil
			if cls and cls.hidden then -- (30 Oct: a class hidden until its feature opens, shared/Config MOWERS_LOCKED)
				Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
				return
			end
			if p.mower and Config.MOWERS_LOCKED then -- (30 Oct: never take Robux for a locked mower, shared/Config MOWERS_LOCKED)
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
