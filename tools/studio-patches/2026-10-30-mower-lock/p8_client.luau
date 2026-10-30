-- Client: require the mower lock (after MowerFx). Anchored; refuses if it's already there.
local cl = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Client
local s = cl.Source
if string.find(s, 'WaitForChild("MowerLock")', 1, true) then
	return "Client already has it"
end
local anchor = 'require(modules:WaitForChild("MowerFx"))'
local i = string.find(s, anchor, 1, true)
if not i or string.find(s, anchor, i + 1, true) then
	return "anchor not found once"
end
local nl = string.find(s, "\n", i, true) or #s
s = string.sub(s, 1, nl) .. 'require(modules:WaitForChild("MowerLock")) -- (30 Oct) mowers locked for the release: holographic locks on the garage and pumps\n' .. string.sub(s, nl + 1)
cl.Source = s
return "Client done (" .. #s .. " chars)"
