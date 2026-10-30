local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ShopWindow
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "17020 880152127" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	UI.text(face, string.upper(cat.id), UDim2.new(1, -48, 1, -4), { pos = UDim2.fromOffset(46, 2), stroke = if active then 3 else 2.5, color = if active then Color3.new(1, 1, 1) else Color3.fromRGB(255, 252, 240) })
]======], [======[	-- (one size for every name: as big as the longest, FEATURED, fits; it scales with the window on every screen)
	UI.text(face, string.upper(cat.id), UDim2.new(1, -48, 1, -4), { pos = UDim2.fromOffset(46, 2), textSize = 27, stroke = if active then 3 else 2.5, color = if active then Color3.new(1, 1, 1) else Color3.fromRGB(255, 252, 240) })
]======] },
	{ [======[	b.Position = UDim2.fromOffset(if active then 22 else 6, 32 + (i - 1) * PACKET_GAP)
	b.Rotation = if i % 2 == 0 then 2 else -2
]======], [======[	b.Position = UDim2.fromOffset(if active then 18 else 6, 32 + (i - 1) * PACKET_GAP)
]======] },
	{ [======[-- sparkles and its picture bobs; the others are pale until you pick them.
]======], [======[-- sparkles and its picture bobs; the others are pale until you pick them. (30 Oct, owner: "fix broken ui": they
-- stand straight and in line now, not tilted every other way, and every name is the same size.)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "17239 1319058608" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
