local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Hud
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "39348 151659687" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		trackText.Text = string.format("%.1f%% cleared", pct * 100)
	end
]======], [======[		trackText.Text = string.format("%.1f%% cleared", pct * 100)
	end
	if w.boss or w.bossWaiting then
		-- (29 Oct, the bug sweep) the boss opens the next area, not mowing: it said "Mow it all to open ..." while the
		-- boss waited and all through the fight
		local here = Config.ZONES[w.zone or 1]
		local bossName = if here and here.boss then here.boss.name else "boss"
		nextText.Text = if nextZone and (w.zone or 1) < zones then ("Beat the %s to open %s"):format(bossName, nextZone.name) else ("Beat the %s!"):format(bossName)
	end
]======] },
	{ [======[		trackText.Text = "BOSS AWAKE!"
		nextText.Text = if nextZone and (w.zone or 1) < zones then ("Beat the %s to open %s"):format(bossName, nextZone.name) else ("Beat the %s!"):format(bossName)
	else
]======], [======[		trackText.Text = "BOSS AWAKE!"
	else
]======] },
	{ [======[		-- cleared" and "Mow it all to open ..." with nothing left to mow
		local here = Config.ZONES[w.zone or 1]
		local bossName = if here and here.boss then here.boss.name else "boss"
]======], [======[		-- cleared" with nothing left to mow
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "39514 526136225" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
