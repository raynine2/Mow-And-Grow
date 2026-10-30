local m = game.ReplicatedStorage.MowALawn.Config
local s = m.Source
if string.find(s, [======[BOSS_PROWL]======], 1, true) then
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
	{ [======[Config.FILM_SOUNDS = {
]======], [======[-- (30 Oct, owner: "the bosses are very stiff and dont do alot they are just a statue") between its moves a boss
-- prowls towards one of the fighters (server/Boss); the client rocks it along (client/BossLife)
Config.BOSS_PROWL = {
	speed = 7, -- studs a second for a 40-stud boss (a bigger one strides faster)
	keep = 9, -- it stops this far short of the fighter (from the edge of its body)
	pause = 0.35, -- seconds it stands after a move before it sets off
}

Config.FILM_SOUNDS = {
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
