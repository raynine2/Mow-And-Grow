local results = {}
table.insert(results, "p1_config: " .. tostring((function()
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

end)()))
table.insert(results, "p2_mowers: " .. tostring((function()
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

end)()))
table.insert(results, "p3_run: " .. tostring((function()
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

end)()))
table.insert(results, "p4_gemshop: " .. tostring((function()
-- GemShop: no gem mower can be bought while locked
-- Studio's copy can differ from git's, so each change is anchored on a piece of one line both copies have; it must be
-- found exactly once, and nothing changes if the script isn't the copy this was made for (or already has the lock).
local m = game.ServerScriptService.MowALawn.GemShop
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
if hashOf(s) ~= "1405 1150100285" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
-- { kind, anchor, text }: "after" adds `text` after the anchor (the anchor ends with its line's newline);
-- "before" adds it just before the anchor
local edits = {
	{ "after", [======[function GemShop.buyGemMower(player: Player, data, id: string)
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

end)()))
table.insert(results, "p5_monetization: " .. tostring((function()
-- Monetization: never prompt a Robux mower while locked
-- Studio's copy can differ from git's, so each change is anchored on a piece of one line both copies have; it must be
-- found exactly once, and nothing changes if the script isn't the copy this was made for (or already has the lock).
local m = game.ServerScriptService.MowALawn.Monetization
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
if hashOf(s) ~= "9006 601597384" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
-- { kind, anchor, text }: "after" adds `text` after the anchor (the anchor ends with its line's newline);
-- "before" adds it just before the anchor
local edits = {
	{ "before", [======[			MarketplaceService:PromptProductPurchase(player, p.id)
]======], [======[			if p.mower and Config.MOWERS_LOCKED then -- (30 Oct: never take Robux for a locked mower, shared/Config MOWERS_LOCKED)
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

end)()))
table.insert(results, "p6_shopwindow: " .. tostring((function()
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

end)()))
table.insert(results, "p8_client: " .. tostring((function()
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

end)()))
return table.concat(results, "\n")
