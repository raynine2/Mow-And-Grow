local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Skin
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "23797 845675608" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	local o = props or {}
	local def = Skin.FRAMES[key]
]======], [======[	local o = props or {}
	key = themed(key)
	local def = Skin.FRAMES[key]
]======] },
	{ [======[} :: { [string]: FrameDef }

]======], [======[} :: { [string]: FrameDef }

-- The theme (Config.UI.theme): under "galaxy" the garden kit's frames are drawn with the grass-galaxy kit's art, so
-- every window, card, button, plate and ribbon changes at once. A key keeps its garden art while its galaxy piece
-- isn't uploaded. The themed pieces that read differently (the cream paper, the cork board, the soil box) are restyled
-- in their own windows.
Skin.THEMES = {
	galaxy = {
		ui_sign = "gg_panel",
		ui_pcard = "gg_card",
		ui_card = "gg_card",
		ui_tile = "gg_card",
		ui_tag = "gg_card",
		ui_inset = "gg_card",
		ui_button = "gg_button",
		ui_plate = "gg_plate",
		ui_ribbon = "gg_ribbon",
		ui_badge = "gg_badge",
	},
}
local function themed(key: string): string
	local map = Skin.THEMES[Config.UI and Config.UI.theme or ""]
	local to = map and map[key]
	if to then
		local id = Config.ICONS and Config.ICONS[to]
		if id and id ~= "" then
			return to
		end
	end
	return key
end
Skin.themed = themed

]======] },
	{ [======[	card_ribbon = { w = 925, h = 290, slice = Rect.new(330, 110, 595, 170), face = { 130, 30, 130, 100 }, fallback = Color3.fromRGB(240, 240, 240), radius = 6 },
} :: { [string]: FrameDef }
]======], [======[	card_ribbon = { w = 925, h = 290, slice = Rect.new(330, 110, 595, 170), face = { 130, 30, 130, 100 }, fallback = Color3.fromRGB(240, 240, 240), radius = 6 },
	-- (30 Oct, the grass-galaxy kit, owner: "remake the ui ... grass galaxy theme mix ... use forge gui"; ForgeGUI art,
	-- trimmed, assets/icons/gg_*.png): a night sky with a nebula inside a rim of grass and clovers. The 9-slice centres
	-- keep the corner clovers, stars and ribbon tails whole; the faces are the flat insides.
	gg_panel = { w = 1024, h = 554, slice = Rect.new(140, 140, 884, 414), face = { 62, 62, 62, 60 }, fallback = Color3.fromRGB(40, 24, 90), radius = 24 },
	gg_card = { w = 494, h = 512, slice = Rect.new(100, 110, 394, 402), face = { 36, 36, 36, 36 }, fallback = Color3.fromRGB(58, 34, 112), radius = 18 },
	gg_button = { w = 768, h = 239, slice = Rect.new(120, 100, 648, 140), face = { 28, 16, 28, 40 }, fallback = Color3.fromRGB(240, 240, 240), radius = 12 },
	gg_plate = { w = 768, h = 200, slice = Rect.new(100, 90, 600, 120), face = { 30, 30, 130, 30 }, fallback = Color3.fromRGB(36, 22, 74), radius = 999 },
	gg_ribbon = { w = 1024, h = 169, slice = Rect.new(150, 60, 874, 110), face = { 120, 20, 120, 30 }, fallback = Color3.fromRGB(240, 240, 240), radius = 6 },
	gg_badge = { w = 496, h = 512, slice = Rect.new(150, 150, 346, 360), face = { 110, 100, 110, 130 }, fallback = Color3.fromRGB(40, 24, 90), radius = 999 },
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
if hashOf(s) ~= "26001 26618939" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
