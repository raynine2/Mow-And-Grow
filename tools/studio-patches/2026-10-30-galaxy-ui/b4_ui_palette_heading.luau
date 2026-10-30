local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.UI
local s = m.Source
if string.find(s, [======[if C.theme == "galaxy" then]======], 1, true) then
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
	{ [======[	brownText = Color3.fromRGB(110, 62, 30),
}
UI.wood = WOOD
]======], [======[	brownText = Color3.fromRGB(110, 62, 30),
}
if C.theme == "galaxy" then
	-- (30 Oct, the grass-galaxy theme) the same names, the night sky's colours: words light, boxes violet glass,
	-- the open tab grass green, a greyed-out button a muted violet
	WOOD.brownText = C.dimText
	WOOD.inset = C.glass
	WOOD.insetEdge = C.night
	WOOD.plank = Color3.fromRGB(46, 28, 96)
	WOOD.plankLine = Color3.fromRGB(56, 36, 112)
	WOOD.frame = Color3.fromRGB(36, 22, 80)
	WOOD.frameEdge = Color3.fromRGB(70, 150, 40)
	WOOD.tabWood = Color3.fromRGB(92, 64, 168)
	WOOD.tabOn = C.leaf
	WOOD.grey = Color3.fromRGB(122, 112, 156)
end
UI.wood = WOOD
]======] },
	{ [======[function UI.heading(list: Instance, order: number, text: string)
	local bar = UI.section(list, UDim2.new(1, -10, 0, 44))
]======], [======[function UI.heading(list: Instance, order: number, text: string)
	if C.theme == "galaxy" and hasArt("gg_ribbon") then
		-- (the grass-galaxy theme) a ribbon banner across the list, tinted grass green, the words white
		local holder = Instance.new("Frame")
		holder.Name = "Heading"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -10, 0, 50)
		holder.LayoutOrder = order
		holder.Parent = list
		local S = skin("gg_ribbon") :: any
		local art, face = S.frame(holder, "gg_ribbon", Vector2.new(560, 50), { name = "Art", tint = C.leaf, maxScale = 0.36 })
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.fromScale(0.5, 0)
		UI.text(face, string.upper(text), UDim2.fromScale(1, 1), { stroke = 3 })
		return holder
	end
	local bar = UI.section(list, UDim2.new(1, -10, 0, 44))
]======] },
	{ [======[		if color and color ~= WOOD.inset then
			local base = WOOD.inset]======], [======[		if color and color ~= WOOD.inset and C.theme ~= "galaxy" then
			local base = WOOD.inset]======] },
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
