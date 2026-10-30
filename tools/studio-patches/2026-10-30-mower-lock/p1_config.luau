-- Config: the MOWERS_LOCKED switch, added before its last line
-- Studio's copy can differ from git's, so each change is anchored on a piece of one line both copies have; it must be
-- found exactly once, and nothing changes if the script isn't the copy this was made for (or already has the lock).
local m = game.ReplicatedStorage.MowALawn.Config
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
if hashOf(s) ~= "93131 925977069" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
-- { kind, anchor, text }: "after" adds `text` after the anchor (the anchor ends with its line's newline);
-- "before" adds it just before the anchor
local edits = {
	{ "before", [======[

return Config
]======], [======[

-------------------------------------------------------------------------------------------------------------
-- (30 Oct, owner: "for game release i want to close of the mower system including gas etc and release it in a later
-- update ... just a lock on it") The ride-on mowers and their gas are LOCKED for the release. Everything stays in
-- the game; while MOWERS_LOCKED is on:
--   * the server refuses every way in: spawning (server/Mowers.spawn), gas (Mowers.refuel), buying one for coins
--     (server/Run), gems (server/GemShop) or Robux (server/Monetization never prompts a mower product)
--   * the upgrades window has no Mower section (those upgrades only power ride-on mowers), the Robux mowers leave the
--     product list, and the store's Mowers tab shows them locked (client/ShopWindow)
--   * the quest "Get a ride-on mower" becomes "Beat the Backyard boss" at the same step of the chain (a saved run's
--     quest number still fits)
--   * the garage, every gas pump and the lobby's garage wear a holographic lock with their prompts off
--     (client/MowerLock)
-- Set it to false for the mower update: everything comes back as it was.
-------------------------------------------------------------------------------------------------------------
Config.MOWERS_LOCKED = true
Config.MOWERS_LOCKED_TEXT = "🔒 Ride-on mowers & gas are coming in a future update!"
if Config.MOWERS_LOCKED then
	local sections = {}
	for _, s in Config.UPGRADE_SECTIONS do
		if s ~= "Mower" then
			table.insert(sections, s)
		end
	end
	Config.UPGRADE_SECTIONS = sections
	local order = {}
	for _, key in Config.PRODUCT_ORDER do
		local p = Config.PRODUCTS[key]
		if not (p and p.mower) then
			table.insert(order, key)
		end
	end
	Config.PRODUCT_ORDER = order
	for i, q in Config.QUESTS do
		if q.event == "mower" then
			Config.QUESTS[i] = { title = "Beat the Backyard boss", hint = "Clear the lawn, then stand on the glowing pad in its arena", event = "boss", goal = 1, reward = q.reward }
		end
	end
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
