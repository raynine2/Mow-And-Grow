local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Intro
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "60487 631385606" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[			end
		end
	end
	return best
]======], [======[			end
		end
		task.wait()
	end
	return best
]======] },
	{ [======[				if score >= 5 then
]======], [======[				if score >= full then
]======] },
	{ [======[						score -= 3
]======], [======[						score -= 10
]======] },
	{ [======[				for _, k in { 0.95, 0.7, 0.45, 0.2 } do
					if not blocked(eye, feet + UP * (H * k), boxes) then
						score += 1
]======], [======[				for _, k in { 0.97, 0.83, 0.69, 0.55, 0.41, 0.27, 0.13 } do
					for _, s in { 0, -1, 1 } do
						if not blocked(eye, feet + UP * (H * k) + side * (H * 0.22 * s), boxes) then
							score += 1
						end
]======] },
	{ [======[	for _, dist in { 78, 88, 68, 100, 58, 112 } do
		for _, yaw in { 0, -10, 10, -20, 20, -30, 30, -40, 40 } do
]======], [======[	-- (30 Oct, owner: "cant even see dandelion boss in first intro because of house": the tool shop's roof cut
	-- through him: four points up his middle were clear, a thin roof edge sat between two of them. Now 7 heights x
	-- his middle and both sides, and the tear over him, must all be clear (22 lines); the search turns further round
	-- the Mayor (meadow side first) before it settles for the clearest spot.)
	local full = 7 * 3 + 1
	for _, yaw in { 0, -10, 10, -20, 20, -30, 30, -40, 40, -55, 55, -70, 70, -90, 90, -110, 110, -135, 135, -160, 160, 180 } do
		for _, dist in { 78, 88, 68, 100, 58, 112 } do
]======] },
	{ [======[	for _, name in { "Visuals", "Hub", "Ground", "Gates", "Patches", "Ways", "Pads" } do
		local f = world and world:FindFirstChild(name)
		if f then
]======], [======[	-- (30 Oct: every folder of the world but the grass (hidden in the films), water and the invisible bounds: the
	-- boss arenas and the area camps were missing)
	local skip = { Grass = true, Liquid = true, Bounds = true, Loot = true, Mowers = true, Crawlers = true, Water = true }
	for _, f in (if world then world:GetChildren() else {}) do
		if not skip[f.Name] then
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "61317 824054457" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
