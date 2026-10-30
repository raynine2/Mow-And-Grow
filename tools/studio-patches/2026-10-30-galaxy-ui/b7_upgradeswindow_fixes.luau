local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.UpgradesWindow
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "26975 37001599" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[				picked = nil
]======], [======[				picked = "page"
]======] },
	{ [======[	local key = if picked and items[picked] then picked else first
]======], [======[	local key = if picked == "page" then (pageFirst or first) elseif picked and items[picked] then picked else first
]======] },
	{ [======[			cardsIn(box, upgradeItems(section, d, p.locked == true))
]======], [======[			local list = upgradeItems(section, d, p.locked == true)
			cardsIn(box, list)
			pageFirst = list[1] and list[1].key
]======] },
	{ [======[			cardsIn(box, list)
			local tree = Tree.tree(def.id)
]======], [======[			cardsIn(box, list)
			pageFirst = list[1] and list[1].key
			local tree = Tree.tree(def.id)
]======] },
	{ [======[	local first: string? = nil
	local leftSlots = { Vector2.new(GAP, ROW_Y[1]), Vector2.new(GAP, ROW_Y[2]) }
]======], [======[	local first: string? = nil
	local pageFirst: string? = nil
	local leftSlots = { Vector2.new(GAP, ROW_Y[1]), Vector2.new(GAP, ROW_Y[2]) }
]======] },
	{ [======[		picked = nil
]======], [======[		picked = "page" -- (the new page's first card)
]======] },
	{ [======[	UI.text(box, lv, UDim2.fromOffset(right, 22), { pos = UDim2.fromOffset(x, 134), color = if it.gold then GOLD else C.dimText, stroke = 2 })
]======], [======[	UI.text(box, lv, UDim2.fromOffset(right, 26), { pos = UDim2.fromOffset(x, 130), color = if it.gold then GOLD else DOT_ON, stroke = 2.5 })
]======] },
	{ [======[		lv = ("%d / %d  ·  %s"):format(it.level, it.max, it.now or "") .. (if it.nxt then "  >  " .. it.nxt else "")
]======], [======[		-- (what it gives now, and after the next pip)
		lv = ("Lv %d/%d   %s"):format(it.level, it.max, it.now or "") .. (if it.nxt then "  >  " .. it.nxt else "")
]======] },
	{ [======[	UI.text(box, it.desc, UDim2.fromOffset(right, 42), { pos = UDim2.fromOffset(x, 90), color = C.starText, stroke = 2, textSize = 18 })
]======], [======[	UI.text(box, it.desc, UDim2.fromOffset(right, 40), { pos = UDim2.fromOffset(x, 88), color = C.starText, stroke = 2, textSize = 18 })
]======] },
	{ [======[		bar.Rotation = (if up then -1 else 1) * side * 40
]======], [======[		bar.Rotation = (if up then 1 else -1) * side * 40
]======] },
	{ [======[local DOT_OFF = Color3.fromRGB(24, 14, 56)
]======], [======[local DOT_OFF = Color3.fromRGB(52, 36, 104)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "27240 1307339455" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
