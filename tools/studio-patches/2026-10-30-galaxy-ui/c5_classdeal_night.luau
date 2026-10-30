local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ClassDeal
local s = m.Source
if string.find(s, [======[Config.UI.theme ~= "galaxy"]======], 1, true) then
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
	{ [======[local GUILD = Skin.has("ui_cork")
]======], [======[-- (30 Oct) under the grass-galaxy theme (Config.UI.theme) the stand is the night-sky edition again: starfield, violet
-- glass, moon card backs; the guild's cork, parchment and chalk only in the garden theme
local GUILD = Skin.has("ui_cork") and Config.UI.theme ~= "galaxy"
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
