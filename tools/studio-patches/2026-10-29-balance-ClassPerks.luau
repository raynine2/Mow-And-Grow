local m = game.ServerScriptService.MowALawn.ClassPerks
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "10572 1978699340" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[--   Weed Puller        Root Rip      every 6th swing rips the clump out in one hit
]======], [======[--   Weed Puller        Root Rip      every 6th swing hits 8x as hard (rips clumps out by the root)
]======] },
	{ [======[--   Lawn Baron         Courier       a full bag sells itself (80%) wherever you are, every 45 s
]======], [======[--   Lawn Baron         Courier       a full bag sells itself (60%) wherever you are, every 60 s
]======] },
	{ [======[--   Mower Specialist   Turbo Deck    ride-on mowers cut 40% wider, drive 20% faster, burn half the fuel
]======], [======[--   Mower Specialist   Turbo Deck    ride-on mowers cut 25% wider, drive 15% faster, burn 40% less fuel
]======] },
	{ [======[--   Goat Man           Graze         you eat grass as you walk: clumps round you take a hit every half second
]======], [======[--   Goat Man           Graze         you eat grass as you walk: clumps round you take a hit every 0.75 s
]======] },
	{ [======[local ROOT_RIP_EVERY = 6
]======], [======[-- (29 Oct, balance 2) the owner: "check our mowers its way too op and some classes". A one-hit rip on every target of a
-- wide tool let a Weed Puller fell a late area with Bare Hands (any HP, every 6th swing), so the rip is a big hit
-- now; Courier was 80% every 45 s, Turbo Deck 1.4 / 1.2 / 0.5, Graze every 0.5 s (tools/balance_model.py).
local ROOT_RIP_EVERY, ROOT_RIP_MULT = 6, 8
]======] },
	{ [======[local COURIER_CUT, COURIER_COOLDOWN = 0.8, 45
]======], [======[local COURIER_CUT, COURIER_COOLDOWN = 0.6, 60
]======] },
	{ [======[local TURBO = { radius = 1.4, speed = 1.2, fuel = 0.5 }
]======], [======[local TURBO = { radius = 1.25, speed = 1.15, fuel = 0.6 }
]======] },
	{ [======[local GRAZE_RADIUS, GRAZE_EVERY = 7, 0.5
]======], [======[local GRAZE_RADIUS, GRAZE_EVERY = 7, 0.75
]======] },
	{ [======[-- A hand-tool swing is about to land: returns the damage to use (Root Rip makes it a one-hit rip) and the
]======], [======[-- A hand-tool swing is about to land: returns the damage to use (Root Rip makes it an 8x hit) and the
]======] },
	{ [======[		return math.huge, "rootRip"
]======], [======[		return damage * ROOT_RIP_MULT * ClassPerks.powerMult(player), "rootRip"
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "10988 380004654" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
