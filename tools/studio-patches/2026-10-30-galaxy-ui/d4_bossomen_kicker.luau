local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossOmen
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "21473 1554448062" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[			tween(kicker, 0.45, { TextColor3 = BLOOD }, Enum.EasingStyle.Sine)
]======], [======[			tween(kicker, 0.45, { TextColor3 = Color3.fromRGB(255, 214, 218) }, Enum.EasingStyle.Sine) -- (pale, so it reads on the red)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "21531 551908261" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
