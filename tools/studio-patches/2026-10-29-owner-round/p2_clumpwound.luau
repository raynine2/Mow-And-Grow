local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ClumpWound
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "17959 1172619106" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	p.Color = color:Lerp(WHITE, 0.75)
]======], [======[	p.Color = color:Lerp(WHITE, 0.3) -- (29 Oct: a flash, not white: white read as see-through)
]======] },
	{ [======[		grain = mul(inside, 0.92), -- faint fibres running up the stem
		floorShade = mul(inside, 0.85), -- the top inner wall, a step darker (still far lighter than the stalk)
		stepLit = inside:Lerp(base, 0.35),
		stepShade = mul(inside:Lerp(base, 0.45), 0.86),
]======], [======[		grain = mul(inside, 0.9), -- faint fibres running up the stem
		floorShade = mul(inside, 0.72), -- the top inner wall, in shade
		stepLit = mul(base:Lerp(inside, 0.5), 0.92),
		stepShade = mul(base:Lerp(inside, 0.5), 0.7),
]======] },
	{ [======[		floorLit = inside:Lerp(WHITE, 0.25), -- the floor of the cut catches the light
]======], [======[		floorLit = inside:Lerp(WHITE, 0.06), -- the floor of the cut catches the light
]======] },
	{ [======[	local inside = PITH:Lerp(base, 0.14)
]======], [======[	-- (29 Oct 22:44, owner: "after first punch it becomes a little invisible": near-white pith, lit by the sky, read
	-- as a see-through patch) the inside is the stalk's own colour a third of the way to pith: still the lightest
	-- thing on the clump, never white.
	local inside = base:Lerp(PITH, 0.32)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "18248 914115975" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
