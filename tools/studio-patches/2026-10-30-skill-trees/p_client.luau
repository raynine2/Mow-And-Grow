-- Client: require the skill tree window (after GemUpgrades). Anchored; refuses if it's already there.
local cl = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Client
local s = cl.Source
if string.find(s, 'WaitForChild("SkillTreeWindow")', 1, true) then
	return "Client already has it"
end
local anchor = 'require(modules:WaitForChild("GemUpgrades"))'
local i = string.find(s, anchor, 1, true)
if not i or string.find(s, anchor, i + 1, true) then
	return "anchor not found once"
end
local nl = string.find(s, "\n", i, true) or #s
s = string.sub(s, 1, nl) .. 'require(modules:WaitForChild("SkillTreeWindow")) -- (30 Oct) weapon skill trees: the SKILLS button, K, gold MASTERED trees\n' .. string.sub(s, nl + 1)
cl.Source = s
return "Client done (" .. #s .. " chars)"
