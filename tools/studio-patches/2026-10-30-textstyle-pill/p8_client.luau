-- client/Client: two lines (Studio's copy differs from git's: anchored on lines both have)
local cl = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Client
local s = cl.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "4015 1171987577" then
	return "NOT CHANGED: Client is " .. hashOf(s)
end
local adds = {
	{ 'local State = require(modules:WaitForChild("State"))\n', 'require(modules:WaitForChild("TextStyle")) -- every text in our UI style: Fredoka One, the dark outline, gold headlines\n' },
	{ 'require(modules:WaitForChild("Settings"))', 'require(modules:WaitForChild("PotatoPill")) -- the "Potato: OFF" pill in Roblox\'s top bar, beside Roblox\'s buttons\n' },
}
for k, a in adds do
	local i = string.find(s, a[1], 1, true)
	if not i or string.find(s, a[1], i + 1, true) then
		return "line " .. k .. ": anchor not found once"
	end
	local j = string.find(s, "\n", i, true)
	s = string.sub(s, 1, j) .. a[2] .. string.sub(s, j + 1)
end
cl.Source = s
return "Client done: " .. hashOf(s)
