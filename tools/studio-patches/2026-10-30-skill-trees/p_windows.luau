-- Windows: the Upgrades window says where the weapon upgrades went (the "Tool" section is gone from Config; its
-- sections are drawn from Config.UPGRADE_SECTIONS, so nothing else changes here).
-- Studio's copy differs from git's: anchored on the money line under the cards, which must be found once.
local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Windows
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "40700 613362573" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local anchor = [=[moneyLine(upgrades.list, 99, "Your money: $"]=]
local i, j = string.find(s, anchor, 1, true)
if not i or string.find(s, anchor, j + 1, true) then
	return "NOT CHANGED: `" .. anchor .. "` not found once"
end
local nl = string.find(s, "\n", j, true) or #s
s = string.sub(s, 1, nl) .. [=[	moneyLine(upgrades.list, 100, "Weapon upgrades: SKILLS (K). Every weapon has its own tree") -- (30 Oct) client/SkillTreeWindow]=] .. "\n" .. string.sub(s, nl + 1)
m.Source = s
return m.Name .. " done: " .. hashOf(s)
