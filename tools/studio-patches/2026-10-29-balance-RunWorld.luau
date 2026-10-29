local m = game.ServerScriptService.MowALawn.RunWorld
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "36227 708944919" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	local spacing = math.clamp((def and def.spacing or 11) * 0.9, 7, 13)
]======], [======[	-- (29 Oct, balance 2; owner: "add more grass in areas so its not too easy") `fill` packs the area's patches
	-- tighter: x that many clumps, each as big as before (RunWorld.clumpScale still goes by `spacing`)
	local spacing = math.clamp((def and def.spacing or 11) * 0.9, 7, 13) / math.sqrt(def and def.fill or 1)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "36473 1711854206" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
