local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Skin
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "23460 668338792" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	ui_packet = { w = 768, h = 574, slice = Rect.new(170, 150, 640, 430), face = { 160, 110, 60, 100 }, fallback = Color3.fromRGB(240, 236, 228), radius = 10 },
]======], [======[	-- (30 Oct, owner: "fix broken ui": the packet is drawn slanted, so a tall middle row squashed into the shop's
	-- short tabs left a seam across them, a broken crimp and steps at the right end. Now the middle row is 5 rows
	-- thin: the top half meets the bottom half and the whole height scales evenly; only the middle stretches wide)
	ui_packet = { w = 768, h = 574, slice = Rect.new(170, 285, 640, 290), face = { 160, 110, 60, 100 }, fallback = Color3.fromRGB(240, 236, 228), radius = 10 },
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "23797 845675608" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
