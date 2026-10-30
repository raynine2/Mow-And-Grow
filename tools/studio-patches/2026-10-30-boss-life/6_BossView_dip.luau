local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossView
local s = m.Source
if string.find(s, [======[BossLife.dip]======], 1, true) then
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
	{ [======[	local lift = v.lift.x + (if life then life.lift + BossLife.rim(v, pitch, roll) else 0)
]======], [======[	local lift = if life then BossLife.dip(v, v.lift.x) + life.lift + BossLife.rim(v, pitch, roll) else v.lift.x
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
