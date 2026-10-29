local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Intro
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "61317 824054457" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		FilmVoice.waitFor(LINES.N1, 1.5)
	end
]======], [======[		FilmVoice.waitFor(LINES.N1, 1.5)
	end
	local waitUntil = os.clock() + 8
	while not kingReady and playing and os.clock() < waitUntil do
		task.wait(0.05)
	end
]======] },
	{ [======[		local models = ReplicatedStorage:FindFirstChild("BossModels")
		if models then
]======], [======[		local models = ReplicatedStorage:FindFirstChild("BossModels")
		local king = models and models:FindFirstChild(BossMoves.get(1).rig)
		if king then
			pcall(function()
				ContentProvider:PreloadAsync({ king })
			end)
		end
		kingReady = true
		if models then
]======] },
	{ [======[	-- (the guardians' models and textures for the King and the roll call)
	task.spawn(function()
]======], [======[	-- (the guardians' models and textures for the King and the roll call)
	-- (30 Oct, owner: "de bosses spawnen niet goed in of laden niet goed in de trailer en komen later pas": the film
	-- didn't wait for them, so on a fresh client the King's meshes and paint were still downloading when his shots
	-- came up, and he popped in late. The black cover now waits for the King (his shots come first), at most 8 s; the
	-- other guardians load right behind him, before their shots ~5 s later.)
	local kingReady = false
	task.spawn(function()
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "62062 1849104164" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
