local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ClumpCarve
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "30121 1621535552" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[							p.Color = color:Lerp(WHITE, 0.6)
]======], [======[							p.Color = color:Lerp(WHITE, 0.25) -- (a flash, not white: white read as see-through)
]======] },
	{ [======[		-- a shallow scuff is fresh, lit pith
		fresh = mul(inside:Lerp(base, 0.12), 0.97),
]======], [======[		-- a shallow scuff is fresh, lit: a shade lighter than the skin
		fresh = mul(inside, 0.92),
]======] },
	{ [======[		floor = inside:Lerp(WHITE, 0.12), -- the floor of the cut, lit from above
		wall = mul(inside:Lerp(base, 0.3), 0.88),
		ceil = mul(inside:Lerp(base, 0.5), 0.62), -- the top inner wall, in shade
		deep = mul(inside:Lerp(base, 0.4), 0.72), -- the back of the hole
		grain = mul(inside:Lerp(base, 0.3), 0.8), -- faint fibres up the stem
		step = mul(inside:Lerp(base, 0.45), 0.9),
		stepCeil = mul(inside:Lerp(base, 0.55), 0.6),
]======], [======[		floor = inside, -- the floor of the cut, lit from above
		wall = mul(inside, 0.78),
		ceil = mul(inside, 0.5), -- the top inner wall, in shade
		deep = mul(inside, 0.6), -- the back of the hole
		grain = mul(inside, 0.68), -- faint fibres up the stem
		step = mul(base:Lerp(inside, 0.5), 0.82),
		stepCeil = mul(base:Lerp(inside, 0.5), 0.55),
]======] },
	{ [======[	local inside = PITH:Lerp(base, 0.22)
]======], [======[	local inside = base:Lerp(PITH, 0.32)
]======] },
	{ [======[-- and the skin round the edge darkens a touch (client/ClumpCarve parts also cast shadows into it).
local function tonesFor(base: Color3): Tones
]======], [======[-- and the skin round the edge darkens a touch (client/ClumpCarve parts also cast shadows into it).
-- (29 Oct 22:44, owner, again: "after first punch it becomes a little invisible": the inside was still mostly pith,
-- near white, and lit by the sky it read as a window onto the sky) the inside is the stalk's own colour, only a
-- third of the way to pith: lighter than the skin where it's fresh, darker in the shade, never white.
local function tonesFor(base: Color3): Tones
]======] },
	{ [======[-- Inside it's pale: the skin keeps the stalk's colours (the dark rim round the cut), the next ring in is the step,
-- the core the brightest pith; a floor catches the light, a ceiling is a step darker. A few of the removed bits
-- fly off and the freshly opened faces flash white and settle. Near the end only a thin core holds the top up;
]======], [======[-- Inside it's the stalk's own colour, a little paler (never white: that read as see-through): the skin keeps the
-- stalk's colours (the dark rim round the cut), the next ring in is the step, the core the pith; a floor catches the
-- light, a ceiling is a step darker. A few of the removed bits fly off and the freshly opened faces flash and settle. Near the end only a thin core holds the top up;
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "30490 390877430" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
