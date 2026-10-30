local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.MowerLock
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "20091 1943267726" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		-- the lobby: over the mower on its turntable, the ring round the turntable
		local floor = ground(holder.Position)
]======], [======[		-- the lobby: over the mower on its turntable, the ring on the turntable's top round it (not the ground under the
		-- prompt: that's the mower's roof)
		local cf, size = holder.CFrame, holder.Size
		local height = math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z
		local floor = holder.Position + Vector3.new(0, height / 2, 0)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "20362 22597776" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
