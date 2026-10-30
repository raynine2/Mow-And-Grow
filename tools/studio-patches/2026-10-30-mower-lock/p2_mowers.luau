-- Mowers: spawning and gas refuse while the mowers are locked
-- Studio's copy can differ from git's, so each change is anchored on a piece of one line both copies have; it must be
-- found exactly once, and nothing changes if the script isn't the copy this was made for (or already has the lock).
local m = game.ServerScriptService.MowALawn.Mowers
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
if hashOf(s) ~= "16662 974742268" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
-- { kind, anchor, text }: "after" adds `text` after the anchor (the anchor ends with its line's newline);
-- "before" adds it just before the anchor
local edits = {
	{ "after", [======[function Mowers.spawn(player: Player, id: string): boolean
]======], [======[	if Config.MOWERS_LOCKED then -- (30 Oct: the ride-on mowers are locked for the release, shared/Config MOWERS_LOCKED)
		Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
		return false
	end
]======] },
	{ "after", [======[function Mowers.refuel(player: Player, pumpPos: Vector3, pricePerFuel: number): number
]======], [======[	if Config.MOWERS_LOCKED then -- (30 Oct: gas is locked with the mowers, shared/Config MOWERS_LOCKED)
		Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
		return 0
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
