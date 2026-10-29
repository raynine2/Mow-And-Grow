local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossKill
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "20066 1558143226" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	play("SunBreak", pos + Vector3.new(0, 6 * size, 0), { scale = size * 1.6 })
	play("GoldPillar", pos, { scale = size * 1.5, hold = 3 })
]======], [======[	-- (checked on screen: at 1.6x the sun-break's glow washed the whole picture out for over a second, hiding the
	-- fireworks and the coins: smaller and higher, it reads as a burst of light over the spot)
	play("SunBreak", pos + Vector3.new(0, 14 * size, 0), { scale = size * 0.7 })
	play("GoldPillar", pos, { scale = size * 1.2, hold = 2.5 })
]======] },
	{ [======[	tween(group, 0.35, { GroupTransparency = 0.15 })
]======], [======[	tween(group, 0.35, { GroupTransparency = 0.45 })
]======] },
	{ [======[		gr.Transparency = seq({ { 0, 1 }, { 0.12, 0.65 }, { 0.42, 0.3 }, { 0.5, 0.25 }, { 0.58, 0.3 }, { 0.88, 0.65 }, { 1, 1 } })
]======], [======[		gr.Transparency = seq({ { 0, 1 }, { 0.15, 0.85 }, { 0.4, 0.45 }, { 0.5, 0.4 }, { 0.6, 0.45 }, { 0.85, 0.85 }, { 1, 1 } })
]======] },
	{ [======[		r.Size = UDim2.fromScale(1, 0.05)
]======], [======[		r.Size = UDim2.fromScale(1, 0.03)
]======] },
	{ [======[	glow.Parent = group
	for i = 1, 12 do
]======], [======[	glow.Parent = group
	-- (checked on screen: wide, strong rays covered the whole picture; thin ones round the card read as a halo)
	for i = 1, 12 do
]======] },
	{ [======[	glow.ImageTransparency = 0.2
]======], [======[	glow.ImageTransparency = 0.35
]======] },
	{ [======[	glow.Size = UDim2.fromScale(0.45, 0.45)
]======], [======[	glow.Size = UDim2.fromScale(0.6, 0.6)
]======] },
	{ [======[	box.Size = UDim2.fromScale(1.6, 1.6)
]======], [======[	box.Size = UDim2.fromScale(0.62, 0.62)
]======] },
	{ [======[	light.Brightness = 12
]======], [======[	light.Brightness = 6
]======] },
	{ [======[	local f = fill(g, WHITE, 0)
	tween(f, 0.8, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(g, 0.9)
]======], [======[	local f = fill(g, WHITE, 0.05)
	tween(f, 0.55, { BackgroundTransparency = 1 })
	Debris:AddItem(g, 0.7)
]======] },
	{ [======[	tween(sc, 0.5, { Scale = 1.25 })
]======], [======[	tween(sc, 0.5, { Scale = 2.1 * k })
]======] },
	{ [======[	stroke.Color = INK
]======], [======[]======] },
	{ [======[	tween(sc, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	stroke.Color = WHITE
]======], [======[	local k = g.AbsoluteSize.Y / 720 -- (the screen's height against a 720p screen)
	sc.Scale = 4.2 * k
	tween(sc, 0.14, { Scale = 1.7 * k }, Enum.EasingStyle.Back)
]======] },
	{ [======[	sc.Scale = 2.4
]======], [======[	sc.Scale = 4.2
]======] },
	{ [======[	t.TextScaled = true
]======], [======[	t.TextSize = 100
]======] },
	{ [======[	t.Size = UDim2.fromScale(0.9, 0.24)
]======], [======[	t.Size = UDim2.fromOffset(460, 110)
]======] },
	{ [======[-- "FINISH!" in our title style: gold to orange, a heavy outline
]======], [======[-- "FINISH!" in our title style: gold to orange, a heavy outline. (Roblox draws text at most 100 px, scaled to fit
-- or not, so it is set at 100 and the UIScale makes it big: ~1/4 of the screen's height at rest.)
]======] },
	{ [======[	pillarBeam(host, foot, top, 20, 0.6, 70, 0.6, color) -- the soft outer glow
	pillarBeam(host, foot, top, 7, 1.7, 32, 0.08, color:Lerp(WHITE, 0.55)) -- the bright core
]======], [======[	-- (checked against a bright midday sky: fully additive light washed out to white there, so the outer glow is
	-- mostly painted on and the core only partly additive: it keeps the area's colour)
	pillarBeam(host, foot, top, 22, 0.6, 70, 0.3, color, 0.25) -- the soft outer glow
	pillarBeam(host, foot, top, 7, 1.7, 32, 0, color:Lerp(WHITE, 0.2), 0.8) -- the bright core
]======] },
	{ [======[	b.LightEmission = 1
]======], [======[	b.LightEmission = glow
]======] },
	{ [======[local function pillarBeam(host: BasePart, a0: Attachment, a1: Attachment, width: number, speed: number, length: number, alpha: number, color: Color3)
]======], [======[local function pillarBeam(host: BasePart, a0: Attachment, a1: Attachment, width: number, speed: number, length: number, alpha: number, color: Color3, glow: number)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "20773 1742596366" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
