local m = game.ReplicatedStorage.MowALawn.Config
local s = m.Source
if string.find(s, [======[function Config.workOutClassOdds()]======], 1, true) then
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
	{ [======[		local w = Config.STOCK_WEIGHTS[c.rarity]
		if w then
]======], [======[		local w = Config.STOCK_WEIGHTS[c.rarity]
		if w and not (c :: any).hidden then -- (hidden: never dealt, see MOWERS_LOCKED below)
]======] },
	{ [======[Config.CLASS_CHANCE_LUCKY = {} :: { [string]: number }
do
	local N = 20000
]======], [======[Config.CLASS_CHANCE_LUCKY = {} :: { [string]: number }
function Config.workOutClassOdds()
	table.clear(Config.CLASS_CHANCE)
	table.clear(Config.CLASS_CHANCE_LUCKY)
	local N = 20000
]======] },
	{ [======[		for id, n in hits do
			mode[1][id] = n / N
		end
	end
end
]======], [======[		for id, n in hits do
			mode[1][id] = n / N
		end
	end
end
Config.workOutClassOdds()
]======] },
	{ [======[	for i, q in Config.QUESTS do
		if q.event == "mower" then
]======], [======[	-- (30 Oct, owner: hide it until the mowers open) the Mower Specialist's perk only works on ride-on mowers: the class
	-- is never dealt (so it can't be bought with gems), its Robux product is refused (server/Monetization) and its card
	-- is left out of the stand (client/ClassDeal); whoever has it keeps it. The odds on the cards are worked out again.
	for _, c in Config.CLASSES do
		if c.id == "MowerSpecialist" then
			(c :: any).hidden = true
		end
	end
	Config.workOutClassOdds()
	for i, q in Config.QUESTS do
		if q.event == "mower" then
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
