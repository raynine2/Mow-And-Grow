local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.MowerLock
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "19989 1536906607" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		return floor + Vector3.new(0, (BODY.Y / 2 + 2.6) * s, 0), floor, 3, s
]======], [======[		return floor + Vector3.new(0, (BODY.Y / 2 + 1.9) * s, 0), floor, 3, s
]======] },
	{ [======[	anchor.CFrame = CFrame.new(centre + Vector3.new(0, (BODY.Y / 2 + LEG + ARC_R + 1.9) * s, 0))
]======], [======[	-- (just clear of the shackle at the top of its bob: on the garage it stays under the GARAGE board)
	anchor.CFrame = CFrame.new(centre + Vector3.new(0, (BODY.Y / 2 + LEG + ARC_R + 1.75) * s, 0))
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "20091 1943267726" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
