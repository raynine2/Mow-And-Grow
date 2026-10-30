local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Skin
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "26001 26618939" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		ui_badge = "gg_badge",
	},
]======], [======[		ui_badge = "gg_badge",
		ui_bar = "gg_bar",
	},
]======] },
	{ [======[		ui_inset = "gg_card",
]======], [======[		ui_inset = "gg_inset",
]======] },
	{ [======[	gg_badge = { w = 496, h = 512, slice = Rect.new(150, 150, 346, 360), face = { 110, 100, 110, 130 }, fallback = Color3.fromRGB(40, 24, 90), radius = 999 },
} :: { [string]: FrameDef }
]======], [======[	gg_badge = { w = 496, h = 512, slice = Rect.new(150, 150, 346, 360), face = { 110, 100, 110, 130 }, fallback = Color3.fromRGB(40, 24, 90), radius = 999 },
	gg_inset = { w = 1024, h = 408, slice = Rect.new(70, 70, 954, 338), face = { 26, 26, 26, 26 }, fallback = Color3.fromRGB(20, 14, 70), radius = 16 },
	gg_bar = { w = 768, h = 84, slice = Rect.new(60, 30, 708, 54), face = { 17, 16, 17, 16 }, fallback = Color3.fromRGB(30, 20, 60), radius = 999 },
} :: { [string]: FrameDef }
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "26319 1299661676" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
