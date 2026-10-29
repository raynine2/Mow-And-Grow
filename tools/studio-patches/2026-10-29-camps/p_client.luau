-- Client: require CampLife after Life.
local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Client
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if string.find(s, "CampLife", 1, true) then
	return "Client already requires CampLife: " .. hashOf(s)
end
if hashOf(s) ~= "3780 1361335942" then
	return "NOT CHANGED: Client is " .. hashOf(s) .. " (expected 3780 1361335942)"
end
local i, j = string.find(s, 'require(modules:WaitForChild("Life"))', 1, true)
if not i or string.find(s, 'require(modules:WaitForChild("Life"))', j + 1, true) then
	return "NOT CHANGED: the Life line isn't there once"
end
local e = string.find(s, "\n", j, true) or #s
s = string.sub(s, 1, e) .. 'require(modules:WaitForChild("CampLife")) -- (29 Oct) the area camps: villagers, animals, windmill sails, banners\n' .. string.sub(s, e + 1)
m.Source = s
return "Client done: " .. hashOf(s)
