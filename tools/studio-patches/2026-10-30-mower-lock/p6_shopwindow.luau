local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.ShopWindow
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "16529 2147428512" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	if trial and State.isRun() then
]======], [======[	if trial and State.isRun() and not Config.MOWERS_LOCKED then
]======] },
	{ [======[	if rocket and not table.find(d.mowers, rocket.id) then
]======], [======[	if rocket and not table.find(d.mowers, rocket.id) and not Config.MOWERS_LOCKED then
]======] },
	{ [======[	local stats = ("Power %s  -  Speed %d  -  Fuel %d"):format(Format.short(m.damage), m.speed, m.fuel)
	if m.currency == "gems" then
]======], [======[	local stats = ("Power %s  -  Speed %d  -  Fuel %d"):format(Format.short(m.damage), m.speed, m.fuel)
	if Config.MOWERS_LOCKED then
		-- (30 Oct: the ride-on mowers are locked for the release, shared/Config MOWERS_LOCKED: shown, not sold)
		return {
			title = m.name,
			desc = "Coming in a future update",
			icon = icon,
			color = m.color,
			tags = { "SOON" },
			prices = { { text = "🔒 SOON", enabled = false, onClick = function() end } },
		}
	end
	if m.currency == "gems" then
]======] },
	{ [======[	POPULAR = Color3.fromRGB(255, 120, 170),
	SUPER = Color3.fromRGB(255, 190, 40),
]======], [======[	POPULAR = Color3.fromRGB(255, 120, 170),
	SOON = Color3.fromRGB(60, 200, 255), -- (30 Oct: the locked ride-on mowers)
	SUPER = Color3.fromRGB(255, 190, 40),
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "17020 880152127" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
