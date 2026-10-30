local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossLife
local s = m.Source
if string.find(s, [======[function BossLife.dip]======], 1, true) then
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
	{ [======[-- A blow landed (big: a weak-spot hit): it shudders, and now and then cries out.
]======], [======[-- The moves crouch a boss by lowering it a little (made for the old jointed models): a one-piece model would push
-- its disc into the floor, so small dips are let go (the squash already shows the crouch). Going right under the
-- ground (burrowing, rising out of it, a cameo) still sinks it, smoothly.
function BossLife.dip(v: any, lift: number): number
	if lift >= 0 then
		return lift
	end
	local h = math.max(v.height, 1)
	local k = math.clamp((-lift - 0.1 * h) / (0.25 * h), 0, 1)
	return lift * k * k * (3 - 2 * k)
end

-- A blow landed (big: a weak-spot hit): it shudders, and now and then cries out.
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
