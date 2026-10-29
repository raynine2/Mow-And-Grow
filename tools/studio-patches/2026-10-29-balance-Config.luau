local m = game.ReplicatedStorage.MowALawn.Config
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "87923 431663034" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	{ id = "Sickle", name = "Sickle", cost = 500, kind = "swing", damage = 12, cooldown = 0.45, radius = 8, targets = 4, color = Color3.fromRGB(190, 190, 205) },
	{ id = "PushMower", name = "Push Mower", cost = 1800, kind = "auto", damage = 38, radius = 6, color = Color3.fromRGB(255, 140, 30) },
	{ id = "WeedWhacker", name = "Weed Whacker", cost = 4700, kind = "auto", damage = 220, radius = 9, color = Color3.fromRGB(60, 200, 80) },
	{ id = "MegaScythe", name = "Mega Scythe", cost = 78000, kind = "swing", damage = 2500, cooldown = 0.5, radius = 13, targets = 12, color = Color3.fromRGB(150, 90, 255) },
	{ id = "LaserMower", name = "Laser Mower", cost = 240000, kind = "auto", damage = 4000, radius = 11, color = Color3.fromRGB(60, 230, 255) },
]======], [======[	{ id = "Sickle", name = "Sickle", cost = 600, kind = "swing", damage = 12, cooldown = 0.45, radius = 8, targets = 4, color = Color3.fromRGB(190, 190, 205) },
	{ id = "PushMower", name = "Push Mower", cost = 2500, kind = "auto", damage = 38, radius = 6, color = Color3.fromRGB(255, 140, 30) },
	{ id = "WeedWhacker", name = "Weed Whacker", cost = 14000, kind = "auto", damage = 220, radius = 9, color = Color3.fromRGB(60, 200, 80) },
	{ id = "MegaScythe", name = "Mega Scythe", cost = 300000, kind = "swing", damage = 2500, cooldown = 0.5, radius = 13, targets = 12, color = Color3.fromRGB(150, 90, 255) },
	{ id = "LaserMower", name = "Laser Mower", cost = 1600000, kind = "auto", damage = 4000, radius = 11, color = Color3.fromRGB(60, 230, 255) },
]======] },
	{ [======[	{ id = "Gold", name = "Gold", minutes = 20, badge = 0, color = Color3.fromRGB(255, 205, 50) },
	{ id = "Silver", name = "Silver", minutes = 25, badge = 0, color = Color3.fromRGB(205, 215, 230) },
	{ id = "Bronze", name = "Bronze", minutes = 32, badge = 0, color = Color3.fromRGB(215, 140, 80) },
]======], [======[	{ id = "Gold", name = "Gold", minutes = 27, badge = 0, color = Color3.fromRGB(255, 205, 50) },
	{ id = "Silver", name = "Silver", minutes = 34, badge = 0, color = Color3.fromRGB(205, 215, 230) },
	{ id = "Bronze", name = "Bronze", minutes = 44, badge = 0, color = Color3.fromRGB(215, 140, 80) },
]======] },
	{ [======[-- made cheaper. Retune here after real playtests.
Config.BOSSES = true -- clearing an area wakes its boss, and beating the boss opens the next area (false: areas open straight away)
]======], [======[-- made cheaper. Retune here after real playtests.
-- (29 Oct, balance 2) The owner: "check our mowers its way too op and some classes ... a full balancing check
-- on everything and also add more grass in areas so its not too easy". A run model (tools/balance_model.py)
-- put a first run at ~26 min and one on a gem mower at ~17 (the Monster Mulcher one-shot every area up to the
-- Swamp). Now: `fill` packs every area's patches tighter (x1.35 clumps, x1.5 in the jungle; server/RunWorld),
-- the grass from the Meadow on is tougher (each tool needs 2-3 hits in its own area), the late tools cost
-- more and the boss coins are halved (coins ran away: millions left over at the end), the mowers cut like the
-- tools of their areas instead of far past them (a gem mower speeds up the first 4-5 areas; the last three
-- need tools) and three class gimmicks were trimmed (server/ClassPerks). The model now: a first run ~36 min,
-- on a gem mower ~26, Goat Man ~23.
Config.BOSSES = true -- clearing an area wakes its boss, and beating the boss opens the next area (false: areas open straight away)
]======] },
	{ [======[		name = "Backyard Lawn", grassName = "Lawn Grass", style = "lawn", hp = 2, value = 3, drops = 1, height = 2, -- (29 Oct) was hp 3, value 2
		spacing = 11, scale = 4.0,
		grass = { Color3.fromRGB(110, 210, 70), Color3.fromRGB(90, 195, 60) },
]======], [======[		name = "Backyard Lawn", grassName = "Lawn Grass", style = "lawn", hp = 2, value = 3, drops = 1, height = 2, -- (29 Oct) was hp 3, value 2
		spacing = 11, fill = 1.35, scale = 4.0,
		grass = { Color3.fromRGB(110, 210, 70), Color3.fromRGB(90, 195, 60) },
]======] },
	{ [======[		name = "Flower Meadow", grassName = "Meadow Grass", style = "meadow", model = "tuft_golf", hp = 6, value = 12, drops = 1, height = 2.2, -- (29 Oct) was hp 12, value 12
		spacing = 11.5, scale = 6.3, tint = Color3.fromRGB(150, 215, 95),
]======], [======[		name = "Flower Meadow", grassName = "Meadow Grass", style = "meadow", model = "tuft_golf", hp = 9, value = 12, drops = 1, height = 2.2, -- (29 Oct) was hp 12, value 12; (29 Oct, balance 2) hp 6 -> 9
		spacing = 11.5, fill = 1.35, scale = 6.3, tint = Color3.fromRGB(150, 215, 95),
]======] },
	{ [======[		boss = { name = "Harvest Maw", hp = 900, color = Color3.fromRGB(240, 200, 80), every = 4.2, radius = 11, gems = 15, coins = 600 }, -- (29 Oct) boss moved here to fit the biome; was Bramble Brute
]======], [======[		boss = { name = "Harvest Maw", hp = 900, color = Color3.fromRGB(240, 200, 80), every = 4.2, radius = 11, gems = 15, coins = 500 }, -- (29 Oct) boss moved here to fit the biome; was Bramble Brute
]======] },
	{ [======[		name = "Golf Course", grassName = "Golf Grass", style = "golf", hp = 25, value = 45, drops = 1, height = 2.5, -- (29 Oct) was hp 50, value 45
		spacing = 12.5, scale = 7.2,
]======], [======[		name = "Golf Course", grassName = "Golf Grass", style = "golf", hp = 40, value = 45, drops = 1, height = 2.5, -- (29 Oct) was hp 50, value 45; (29 Oct, balance 2) hp 25 -> 40
		spacing = 12.5, fill = 1.35, scale = 7.2,
]======] },
	{ [======[		boss = { name = "Sakura Snapjaw", hp = 5800, color = Color3.fromRGB(255, 150, 200), every = 4, radius = 11, gems = 20, coins = 2000 }, -- (29 Oct) boss moved here to fit the biome; was Bunker Thornback
]======], [======[		boss = { name = "Sakura Snapjaw", hp = 5800, color = Color3.fromRGB(255, 150, 200), every = 4, radius = 11, gems = 20, coins = 1500 }, -- (29 Oct) boss moved here to fit the biome; was Bunker Thornback
]======] },
	{ [======[		name = "Wheat Farm", grassName = "Wheat", style = "wheat", hp = 130, value = 80, drops = 1, height = 5, -- (29 Oct) was hp 150, value 80
		spacing = 11, scale = 4.0,
]======], [======[		name = "Wheat Farm", grassName = "Wheat", style = "wheat", hp = 180, value = 80, drops = 1, height = 5, -- (29 Oct) was hp 150, value 80; (29 Oct, balance 2) hp 130 -> 180
		spacing = 11, fill = 1.35, scale = 4.0,
]======] },
	{ [======[		boss = { name = "Bramble Brute", hp = 44000, color = Color3.fromRGB(40, 140, 60), every = 3.6, radius = 9, gems = 35, coins = 25000 }, -- (29 Oct) boss moved here to fit the biome; was Harvest Maw
]======], [======[		boss = { name = "Bramble Brute", hp = 44000, color = Color3.fromRGB(40, 140, 60), every = 3.6, radius = 9, gems = 35, coins = 12000 }, -- (29 Oct) boss moved here to fit the biome; was Harvest Maw
]======] },
	{ [======[		name = "Blossom Garden", grassName = "Blossom Grass", style = "blossom", model = "tuft_lawn", hp = 750, value = 300, drops = 2, height = 2.5, -- (29 Oct) was hp 480, value 300
		spacing = 13.5, scale = 5.1, tint = Color3.fromRGB(255, 160, 205),
]======], [======[		name = "Blossom Garden", grassName = "Blossom Grass", style = "blossom", model = "tuft_lawn", hp = 1000, value = 300, drops = 2, height = 2.5, -- (29 Oct) was hp 480, value 300; (29 Oct, balance 2) hp 750 -> 1000
		spacing = 13.5, fill = 1.35, scale = 5.1, tint = Color3.fromRGB(255, 160, 205),
]======] },
	{ [======[		boss = { name = "Bog Strangler", hp = 61000, color = Color3.fromRGB(125, 212, 90), every = 3.5, radius = 12, gems = 45, coins = 80000 }, -- (29 Oct) boss moved here to fit the biome; was Sakura Snapjaw
]======], [======[		boss = { name = "Bog Strangler", hp = 61000, color = Color3.fromRGB(125, 212, 90), every = 3.5, radius = 12, gems = 45, coins = 40000 }, -- (29 Oct) boss moved here to fit the biome; was Sakura Snapjaw
]======] },
	{ [======[		name = "Swamp Reeds", grassName = "Reeds", style = "reeds", hp = 2300, value = 1100, drops = 2, height = 6.5, -- (29 Oct) was hp 2000, value 1100
		spacing = 12, scale = 4.6,
]======], [======[		name = "Swamp Reeds", grassName = "Reeds", style = "reeds", hp = 7000, value = 1100, drops = 2, height = 6.5, -- (29 Oct) was hp 2000, value 1100; (29 Oct, balance 2) hp 2300 -> 7000
		spacing = 12, fill = 1.35, scale = 4.6,
]======] },
	{ [======[		boss = { name = "Frost Thornback", hp = 400000, color = Color3.fromRGB(160, 220, 255), every = 3.3, radius = 10, gems = 55, coins = 300000 }, -- (29 Oct) boss moved here to fit the biome; was Bog Strangler
]======], [======[		boss = { name = "Frost Thornback", hp = 400000, color = Color3.fromRGB(160, 220, 255), every = 3.3, radius = 10, gems = 55, coins = 150000 }, -- (29 Oct) boss moved here to fit the biome; was Bog Strangler
]======] },
	{ [======[		name = "Autumn Prairie", grassName = "Prairie Grass", style = "prairie", model = "tuft_wheat", hp = 12000, value = 2400, drops = 2, height = 6, -- (29 Oct) was hp 4800, value 2400
		spacing = 11.5, scale = 5.1, tint = Color3.fromRGB(235, 120, 45),
]======], [======[		name = "Autumn Prairie", grassName = "Prairie Grass", style = "prairie", model = "tuft_wheat", hp = 30000, value = 2400, drops = 2, height = 6, -- (29 Oct) was hp 4800, value 2400; (29 Oct, balance 2) hp 12000 -> 30000
		spacing = 11.5, fill = 1.35, scale = 5.1, tint = Color3.fromRGB(235, 120, 45),
]======] },
	{ [======[		boss = { name = "Hollow Harvest", hp = 1600000, color = Color3.fromRGB(255, 140, 40), every = 3.1, radius = 13, gems = 65, coins = 1000000 },
]======], [======[		boss = { name = "Hollow Harvest", hp = 1600000, color = Color3.fromRGB(255, 140, 40), every = 3.1, radius = 13, gems = 65, coins = 500000 },
]======] },
	{ [======[		name = "Mega Jungle", grassName = "Jungle Bush", style = "jungle", hp = 50000, value = 12000, drops = 4, height = 8, -- (29 Oct) was hp 60000, value 12000
		spacing = 21, scale = 6.0,
]======], [======[		name = "Mega Jungle", grassName = "Jungle Bush", style = "jungle", hp = 100000, value = 12000, drops = 4, height = 8, -- (29 Oct) was hp 60000, value 12000; (29 Oct, balance 2) hp 50000 -> 100000
		spacing = 21, fill = 1.5, scale = 6.0,
]======] },
	{ [======[		boss = { name = "Jungle Titan", hp = 2200000, color = Color3.fromRGB(63, 230, 200), every = 3, radius = 14, gems = 80, coins = 4000000 },
]======], [======[		boss = { name = "Jungle Titan", hp = 2200000, color = Color3.fromRGB(63, 230, 200), every = 3, radius = 14, gems = 80, coins = 2000000 },
]======] },
	{ [======[	hpHits = 2, -- HP = the zone's grass HP x this (tested 20 Oct: 4 was too tanky for bare hands)
]======], [======[	hpHits = 1.3, -- HP = the zone's grass HP x this (tested 20 Oct: 4 was too tanky for bare hands; (29 Oct, balance 2) was 2: the late areas' grass is 2-3x tougher)
]======] },
	{ [======[	{ title = "Get a ride-on mower", hint = "Buy one at the Garage", event = "mower", goal = 1, reward = 500 },
]======], [======[	{ title = "Get a ride-on mower", hint = "Buy one at the Garage", event = "mower", goal = 1, reward = 200 },
]======] },
	{ [======[	WeedPuller = { name = "Root Rip", text = "Every 6th swing rips the clump out in one hit." },
]======], [======[	WeedPuller = { name = "Root Rip", text = "Every 6th swing hits 8x as hard: it rips clumps out by the root." },
]======] },
	{ [======[	LawnBaron = { name = "Courier", text = "A full bag sells itself for 80%, wherever you are (every 45 s)." },
]======], [======[	LawnBaron = { name = "Courier", text = "A full bag sells itself for 60%, wherever you are (every 60 s)." },
]======] },
	{ [======[	MowerSpecialist = { name = "Turbo Deck", text = "Ride-on mowers cut 40% wider, drive 20% faster, burn half the fuel." },
]======], [======[	MowerSpecialist = { name = "Turbo Deck", text = "Ride-on mowers cut 25% wider, drive 15% faster, burn 40% less fuel." },
]======] },
	{ [======[	GoatMan = { name = "Graze", text = "You eat grass as you walk: clumps around you take a hit every 0.5 s." },
]======], [======[	GoatMan = { name = "Graze", text = "You eat grass as you walk: clumps around you take a hit every 0.75 s." },
]======] },
	{ [======[	{ id = "RustyRider", name = "Rusty Rider", currency = "coins", price = 350, damage = 6, radius = 6, speed = 30, fuel = 60, color = Color3.fromRGB(200, 90, 50) },
	{ id = "TurboTractor", name = "Turbo Tractor", currency = "coins", price = 40000, damage = 120, radius = 9, speed = 38, fuel = 90, color = Color3.fromRGB(60, 170, 255) },
]======], [======[	{ id = "RustyRider", name = "Rusty Rider", currency = "coins", price = 700, damage = 7, radius = 6, speed = 26, fuel = 60, color = Color3.fromRGB(200, 90, 50) },
	{ id = "TurboTractor", name = "Turbo Tractor", currency = "coins", price = 15000, damage = 110, radius = 8, speed = 34, fuel = 90, color = Color3.fromRGB(60, 170, 255) },
]======] },
	{ [======[	{ id = "GoldenZeroTurn", name = "Golden Zero-Turn", currency = "gems", price = 900, damage = 400, radius = 10, speed = 42, fuel = 120, color = Color3.fromRGB(255, 200, 40), swath = 1.3, ahead = 4, stripe = 14 },
	{ id = "MonsterMulcher", name = "Monster Mulcher", currency = "gems", price = 2500, damage = 3000, radius = 12, speed = 46, fuel = 150, color = Color3.fromRGB(150, 60, 220) },
	{ id = "TrialMower", name = "Trial Mower", currency = "trial", product = "TrialMower", damage = 800, radius = 11, speed = 44, fuel = 140, color = Color3.fromRGB(255, 80, 160) },
	{ id = "RocketMower", name = "Rocket Mower", currency = "robux", product = "RocketMower", damage = 2000, radius = 12, speed = 50, fuel = 200, color = Color3.fromRGB(255, 70, 40) },
]======], [======[	{ id = "GoldenZeroTurn", name = "Golden Zero-Turn", currency = "gems", price = 900, damage = 90, radius = 8, speed = 40, fuel = 120, color = Color3.fromRGB(255, 200, 40), swath = 1.3, ahead = 4, stripe = 11 },
	{ id = "MonsterMulcher", name = "Monster Mulcher", currency = "gems", price = 2500, damage = 320, radius = 9, speed = 44, fuel = 150, color = Color3.fromRGB(150, 60, 220) },
	{ id = "TrialMower", name = "Trial Mower", currency = "trial", product = "TrialMower", damage = 260, radius = 9, speed = 44, fuel = 140, color = Color3.fromRGB(255, 80, 160) },
	{ id = "RocketMower", name = "Rocket Mower", currency = "robux", product = "RocketMower", damage = 900, radius = 10, speed = 48, fuel = 200, color = Color3.fromRGB(255, 70, 40) },
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "89277 2828766" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
