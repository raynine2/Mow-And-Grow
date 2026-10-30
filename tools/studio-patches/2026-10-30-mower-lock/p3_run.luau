-- Run: no coin mower can be bought while locked
-- Studio's copy can differ from git's, so each change is anchored on a piece of one line both copies have; it must be
-- found exactly once, and nothing changes if the script isn't the copy this was made for (or already has the lock).
local m = game.ServerScriptService.MowALawn.Run
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if string.find(s, "MOWERS_LOCKED", 1, true) then
	return m.Name .. " already has the mower lock"
end
if hashOf(s) ~= "44975 1537369329" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
-- { kind, anchor, text }: "after" adds `text` after the anchor (the anchor ends with its line's newline);
-- "before" adds it just before the anchor
local edits = {
	{ "after", [======[local function buyCoinMower(player: Player, data, id: string)
]======], [======[	if Config.MOWERS_LOCKED then -- (30 Oct: no mower can be bought while they're locked, shared/Config MOWERS_LOCKED)
		Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
		return
	end
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[2], 1, true)
	if not i or string.find(s, e[2], j + 1, true) then
		return "edit " .. k .. ": anchor not found once"
	end
	if e[1] == "after" then
		s = string.sub(s, 1, j) .. e[3] .. string.sub(s, j + 1)
	else
		s = string.sub(s, 1, i - 1) .. e[3] .. string.sub(s, i)
	end
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
