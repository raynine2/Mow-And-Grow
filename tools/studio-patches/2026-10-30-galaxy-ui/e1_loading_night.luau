local m = game.ReplicatedStorage.MowALawn.LoadingScreen
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "24923 692208240" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		S.sun.Rotation = t * 4
]======], [======[		S.sun.Rotation = if GALAXY then math.sin(t * 0.7) * 5 else t * 4 -- (the moon only rocks)
]======] },
	{ [======[		for _, key in { "logo", "glow_soft", "bg_sun", "bg_cloud", "bg_cloud2", "ui_rays", "bg_windmill", "bg_tree", "bg_tree2", "bg_bush", "bg_bush2", "ui_bar", "ui_grass", "pushmower", "sparkle" } do
]======], [======[		for _, key in { "logo", "glow_soft", "bg_sun", "bg_cloud", "bg_cloud2", "ui_rays", "bg_windmill", "bg_tree", "bg_tree2", "bg_bush", "bg_bush2", "ui_bar", "ui_grass", "pushmower", "sparkle", "moon", "gg_bar" } do
]======] },
	{ [======[	local wood, k = sliced(holder, "ui_bar", BAR.w, BAR.h, BAR_SLICE, BAR_SRC)
]======], [======[	local wood, k = sliced(holder, BAR_KEY, BAR.w, BAR.h, BAR_SLICE, BAR_SRC)
]======] },
	{ [======[		s.ImageColor3 = Color3.fromRGB(16, 30, 10)
]======], [======[		s.ImageColor3 = if GALAXY then Color3.fromRGB(10, 6, 30) else Color3.fromRGB(16, 30, 10)
]======] },
	{ [======[	for _, gl in { { 1060, 660, Color3.fromRGB(255, 232, 150), 0.25 }, { 640, 400, Color3.new(1, 1, 1), 0.45 } } do
]======], [======[	local glowSpecs = if GALAXY then { { 1060, 660, Color3.fromRGB(160, 120, 255), 0.35 }, { 640, 400, Color3.fromRGB(220, 236, 255), 0.55 } } else { { 1060, 660, Color3.fromRGB(255, 232, 150), 0.25 }, { 640, 400, Color3.new(1, 1, 1), 0.45 } }
	for _, gl in glowSpecs do
]======] },
	{ [======[	local shade = frame(group, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(30, 20, 8))
]======], [======[	local shade = frame(group, UDim2.fromScale(1, 1), UDim2.new(), if GALAXY then Color3.fromRGB(8, 4, 24) else Color3.fromRGB(30, 20, 8))
]======] },
	{ [======[		local v = frame(group, UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(side * 0.78, 0), Color3.fromRGB(34, 18, 8))
]======], [======[		local v = frame(group, UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(side * 0.78, 0), if GALAXY then Color3.fromRGB(10, 6, 30) else Color3.fromRGB(34, 18, 8))
]======] },
	{ [======[	standing(world, "bg_bush", Vector2.new(768, 586), 110, 1100, 722)
	-- soft dark edges and a darker bottom, so the bar and the writing read
]======], [======[	standing(world, "bg_bush", Vector2.new(768, 586), 110, 1100, 722)
	if GALAXY then
		fireflies(world)
	end
	-- soft dark edges and a darker bottom, so the bar and the writing read
]======] },
	{ [======[		local stripe = frame(ground, UDim2.fromOffset(55, 300), UDim2.fromOffset(i * 110, 0), Color3.fromRGB(130, 184, 80))
]======], [======[		local stripe = frame(ground, UDim2.fromOffset(55, 300), UDim2.fromOffset(i * 110, 0), if GALAXY then Color3.fromRGB(48, 118, 72) else Color3.fromRGB(130, 184, 80))
]======] },
	{ [======[	hills(world, { { -60, 566, 780, 240 }, { 740, 556, 860, 230 }, { 1400, 570, 720, 240 } }, Color3.fromRGB(110, 170, 70), Color3.fromRGB(200, 214, 110), 4)
	local ground = frame(world, UDim2.fromOffset(2400, 300), UDim2.fromOffset(-560, 600), Color3.fromRGB(110, 170, 70))
]======], [======[	hills(world, { { -60, 566, 780, 240 }, { 740, 556, 860, 230 }, { 1400, 570, 720, 240 } }, if GALAXY then Color3.fromRGB(34, 96, 58) else Color3.fromRGB(110, 170, 70), if GALAXY then Color3.fromRGB(86, 168, 96) else Color3.fromRGB(200, 214, 110), 4)
	local ground = frame(world, UDim2.fromOffset(2400, 300), UDim2.fromOffset(-560, 600), if GALAXY then Color3.fromRGB(34, 96, 58) else Color3.fromRGB(110, 170, 70))
]======] },
	{ [======[		mill.ImageTransparency = 0.1
	end
]======], [======[		mill.ImageTransparency = 0.1
		if GALAXY then
			mill.ImageColor3 = Color3.fromRGB(70, 60, 132)
		end
	end
]======] },
	{ [======[	hills(world, { { 150, 496, 660, 240 }, { 640, 480, 760, 220 }, { 1120, 498, 680, 250 }, { 1500, 504, 560, 210 } }, Color3.fromRGB(170, 160, 150), Color3.fromRGB(226, 196, 170), 3)
]======], [======[	hills(world, { { 150, 496, 660, 240 }, { 640, 480, 760, 220 }, { 1120, 498, 680, 250 }, { 1500, 504, 560, 210 } }, if GALAXY then Color3.fromRGB(50, 42, 108) else Color3.fromRGB(170, 160, 150), if GALAXY then Color3.fromRGB(96, 80, 170) else Color3.fromRGB(226, 196, 170), 3)
]======] },
	{ [======[			end
			table.insert(clouds, { f = f, speed = c[5] })
]======], [======[			end
			if GALAXY then
				f.ImageColor3 = Color3.fromRGB(116, 104, 190) -- (night clouds)
				f.ImageTransparency = 0.35
			end
			table.insert(clouds, { f = f, speed = c[5] })
]======] },
	{ [======[	halo.ImageColor3 = Color3.fromRGB(255, 200, 120)
	halo.ImageTransparency = 0.05
	local sun = img(world, "bg_sun", UDim2.fromOffset(170, 170), UDim2.fromOffset(SUN.X, SUN.Y))
	sun.ImageColor3 = Color3.fromRGB(255, 220, 170)
]======], [======[	halo.ImageColor3 = if GALAXY then Color3.fromRGB(170, 150, 255) else Color3.fromRGB(255, 200, 120)
	halo.ImageTransparency = if GALAXY then 0.3 else 0.05
	local moon = GALAXY and IconIds.moon ~= nil
	local sun = img(world, if moon then "moon" else "bg_sun", UDim2.fromOffset(if moon then 150 else 170, if moon then 160 else 170), UDim2.fromOffset(SUN.X, SUN.Y))
	sun.ImageColor3 = if moon then Color3.new(1, 1, 1) else Color3.fromRGB(255, 220, 170)
]======] },
	{ [======[		r.ImageColor3 = Color3.fromRGB(255, 236, 190)
		r.ImageTransparency = 0.82
]======], [======[		r.ImageColor3 = if GALAXY then Color3.fromRGB(190, 180, 255) else Color3.fromRGB(255, 236, 190)
		r.ImageTransparency = if GALAXY then 0.88 else 0.82
]======] },
	{ [======[	scale.Parent = world

]======], [======[	scale.Parent = world
	if GALAXY then
		nightSky(world)
	end

]======] },
	{ [======[	sg.Color = ColorSequence.new({
]======], [======[	sg.Color = if GALAXY then ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 6, 30)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(34, 20, 86)),
		ColorSequenceKeypoint.new(0.72, Color3.fromRGB(92, 42, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 84, 160)),
	}) else ColorSequence.new({
]======] },
	{ [======[end

-------------------------------------------------------------------------------------------------------------
-- the countryside (a 1280 x 720 world scaled to cover the screen)
]======], [======[end

-- the night sky (galaxy theme): soft nebula clouds and a field of stars, each twinkling at its own pace
local function nightSky(world: Frame)
	for _, n in { { 330, 150, 780, 430, Color3.fromRGB(150, 70, 230), 0.5 }, { 950, 110, 640, 360, Color3.fromRGB(60, 120, 255), 0.66 }, { 640, 330, 1400, 360, Color3.fromRGB(235, 90, 170), 0.72 } } do
		local g = img(world, "glow_soft", UDim2.fromOffset(n[3], n[4]), UDim2.fromOffset(n[1], n[2]))
		g.ScaleType = Enum.ScaleType.Stretch
		g.ImageColor3 = n[5]
		g.ImageTransparency = n[6]
	end
	local rng = Random.new(42)
	for _ = 1, 90 do
		local sz = rng:NextInteger(2, 4)
		local star = frame(world, UDim2.fromOffset(sz, sz), UDim2.fromOffset(rng:NextInteger(0, 1280), rng:NextInteger(0, 440)), Color3.fromRGB(255, 250, 235), sz)
		star.Name = "Star"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.BackgroundTransparency = rng:NextNumber(0.05, 0.5)
		TweenService:Create(star, TweenInfo.new(rng:NextNumber(0.8, 2.2), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber(0, 2)), { BackgroundTransparency = 0.92 }):Play()
	end
	for i, p in { { 210, 80, 28 }, { 760, 150, 18 }, { 1180, 52, 24 }, { 470, 34, 16 } } do
		local sp = img(world, "sparkle", UDim2.fromOffset(p[3], p[3]), UDim2.fromOffset(p[1], p[2]))
		TweenService:Create(sp, TweenInfo.new(1.2 + i * 0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.85 }):Play()
	end
end

-- fireflies drifting over the grass (galaxy theme)
local function fireflies(world: Frame)
	local rng = Random.new(7)
	for _ = 1, 18 do
		local x, y = rng:NextInteger(40, 1240), rng:NextInteger(500, 690)
		local f = img(world, "glow_soft", UDim2.fromOffset(24, 24), UDim2.fromOffset(x, y))
		f.Name = "Firefly"
		f.ScaleType = Enum.ScaleType.Stretch
		f.ImageColor3 = Color3.fromRGB(196, 255, 110)
		f.ImageTransparency = 0.15
		local core = frame(f, UDim2.fromOffset(4, 4), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(244, 255, 200), 2)
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		TweenService:Create(f, TweenInfo.new(rng:NextNumber(2, 4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber(0, 2)), { Position = UDim2.fromOffset(x + rng:NextInteger(-40, 40), y - rng:NextInteger(20, 60)), ImageTransparency = 0.75 }):Play()
	end
end

-------------------------------------------------------------------------------------------------------------
-- the countryside (a 1280 x 720 world scaled to cover the screen)
]======] },
	{ [======[local GOLD_TINT = Color3.fromRGB(255, 226, 196)
]======], [======[local GOLD_TINT = if GALAXY then Color3.fromRGB(140, 150, 216) else Color3.fromRGB(255, 226, 196) -- (galaxy: moonlit)
]======] },
	{ [======[local BAR_FACE = { 47, 52, 49, 44 }

]======], [======[local BAR_FACE = { 47, 52, 49, 44 }
local BAR_KEY = "ui_bar"
if GALAXY and IconIds.gg_bar then
	BAR_KEY, BAR_SLICE, BAR_SRC, BAR_FACE = "gg_bar", Rect.new(60, 30, 708, 54), Vector2.new(768, 84), { 17, 16, 17, 16 }
end

]======] },
	{ [======[local INK = Color3.fromRGB(58, 32, 14) -- the art's dark-brown outline
local FONT = Enum.Font.FredokaOne
]======], [======[local INK = Color3.fromRGB(58, 32, 14) -- the art's dark-brown outline
if GALAXY then
	INK = Color3.fromRGB(22, 12, 48) -- (night: a deep violet outline)
end
local FONT = Enum.Font.FredokaOne
]======] },
	{ [======[	gameName = (require(script.Parent:WaitForChild("Config")) :: any).GAME_NAME or gameName
]======], [======[	local C = require(script.Parent:WaitForChild("Config")) :: any
	gameName = C.GAME_NAME or gameName
	GALAXY = C.UI ~= nil and C.UI.theme == "galaxy"
]======] },
	{ [======[local gameName = "Mow A Lawn"
pcall(function()
]======], [======[local gameName = "Mow A Lawn"
-- (30 Oct, the grass-galaxy theme: Config.UI.theme "galaxy") the same countryside at night: a starry violet sky with
-- nebula glows, the moon instead of the sun, twinkling stars, moonlit hills and trees, fireflies over the grass, and
-- the galaxy kit's bar
local GALAXY = false
pcall(function()
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "29435 1667439687" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
