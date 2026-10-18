-- Mow A Lawn: every number and every piece of content lives here.
-- Systems read from this table, so new content starts with a new entry here.

local Config = {}

Config.GAME_NAME = "Mow A Lawn"
Config.GROUP_ID = 96047379 -- Atlas Interactive Inc (group reward)
Config.ADMINS = { 1994267229 }

-- Studio only: which mode a test server starts in ("Lobby" or "Run").
-- The Workspace attribute ForceMode overrides this.
Config.STUDIO_MODE = "Lobby"

Config.SAVE_KEY = "MowALawn_v1"
Config.SCHEMA = 1

-------------------------------------------------------------------------------------------------------------
-- Tools: bought in order with run coins, reset every run.
-- kind "swing": click to hit the nearest `targets` patches within `radius`.
-- kind "auto":  cuts every patch within `radius` each tick while equipped.
-------------------------------------------------------------------------------------------------------------
Config.TICK = 0.25 -- seconds between auto-cut ticks
Config.TOOLS = {
	{ id = "Hands", name = "Bare Hands", cost = 0, kind = "swing", damage = 1, cooldown = 0.45, radius = 5, targets = 1, color = Color3.fromRGB(255, 205, 160) },
	{ id = "Scissors", name = "Garden Scissors", cost = 150, kind = "swing", damage = 3, cooldown = 0.4, radius = 6, targets = 2, color = Color3.fromRGB(255, 80, 80) },
	{ id = "Sickle", name = "Sickle", cost = 1500, kind = "swing", damage = 12, cooldown = 0.45, radius = 8, targets = 4, color = Color3.fromRGB(190, 190, 205) },
	{ id = "PushMower", name = "Push Mower", cost = 12000, kind = "auto", damage = 30, radius = 6, color = Color3.fromRGB(255, 140, 30) },
	{ id = "WeedWhacker", name = "Weed Whacker", cost = 90000, kind = "auto", damage = 140, radius = 9, color = Color3.fromRGB(60, 200, 80) },
	{ id = "MegaScythe", name = "Mega Scythe", cost = 700000, kind = "swing", damage = 2500, cooldown = 0.5, radius = 13, targets = 12, color = Color3.fromRGB(150, 90, 255) },
	{ id = "LaserMower", name = "Laser Mower", cost = 5000000, kind = "auto", damage = 4000, radius = 11, color = Color3.fromRGB(60, 230, 255) },
}
Config.BOSS_TOOL_MULT = 1 -- tool damage multiplier against bosses

-------------------------------------------------------------------------------------------------------------
-- Run upgrades (coins, Tab menu). Bought one level at a time, reset every run.
-------------------------------------------------------------------------------------------------------------
Config.UPGRADES = {
	{ id = "power", name = "Power", desc = "+20% cutting power", per = 0.20, base = 100, growth = 3.2, max = 10 },
	{ id = "carry", name = "Backpack", desc = "+3 bundles carried", per = 3, base = 175, growth = 2.6, max = 10 },
	{ id = "speed", name = "Walk Speed", desc = "+6% walk speed", per = 0.06, base = 250, growth = 3.0, max = 10 },
	{ id = "sell", name = "Sell Price", desc = "+15% coins per bundle", per = 0.15, base = 300, growth = 3.4, max = 10 },
}

function Config.upgrade(id: string)
	for _, u in Config.UPGRADES do
		if u.id == id then
			return u
		end
	end
	return nil
end

function Config.upgradeCost(id: string, level: number): number
	local u = Config.upgrade(id)
	if not u then
		return math.huge
	end
	return math.floor(u.base * u.growth ^ level)
end

-------------------------------------------------------------------------------------------------------------
-- Zones: one road, cleared in order. Clear every patch to wake the boss; beat the boss to open the next zone.
-------------------------------------------------------------------------------------------------------------
Config.GRID = { cols = 10, rows = 12, tile = 6 } -- patches per zone = cols * rows
Config.ZONE_SPACING = 120 -- studs from one zone's start to the next
Config.FIRST_ZONE_Z = 30
Config.BASE_CARRY = 5

Config.ZONES = {
	{
		name = "Backyard Lawn", hp = 3, value = 3, height = 2,
		grass = { Color3.fromRGB(110, 210, 70), Color3.fromRGB(90, 195, 60) },
		ground = Color3.fromRGB(150, 110, 70),
		boss = { name = "Dandelion King", hp = 400, color = Color3.fromRGB(255, 220, 40), every = 4.5, radius = 9, gems = 10, coins = 150 },
	},
	{
		name = "Golf Course", hp = 40, value = 35, height = 2.5,
		grass = { Color3.fromRGB(70, 200, 90), Color3.fromRGB(55, 180, 75) },
		ground = Color3.fromRGB(235, 215, 150),
		boss = { name = "Thorn Bush", hp = 6000, color = Color3.fromRGB(40, 140, 60), every = 4, radius = 10, gems = 20, coins = 2000 },
	},
	{
		name = "Wheat Farm", hp = 600, value = 420, height = 5,
		grass = { Color3.fromRGB(240, 200, 80), Color3.fromRGB(225, 180, 60) },
		ground = Color3.fromRGB(140, 95, 55),
		boss = { name = "Venus Flytrap", hp = 90000, color = Color3.fromRGB(200, 40, 70), every = 3.6, radius = 11, gems = 35, coins = 25000 },
	},
	{
		name = "Swamp Reeds", hp = 8000, value = 5000, height = 6.5,
		grass = { Color3.fromRGB(80, 150, 100), Color3.fromRGB(60, 130, 90) },
		ground = Color3.fromRGB(70, 100, 85),
		boss = { name = "Swamp Vine", hp = 1200000, color = Color3.fromRGB(90, 70, 140), every = 3.3, radius = 12, gems = 55, coins = 300000 },
	},
	{
		name = "Mega Jungle", hp = 100000, value = 60000, height = 8,
		grass = { Color3.fromRGB(30, 160, 60), Color3.fromRGB(20, 130, 50) },
		ground = Color3.fromRGB(90, 70, 45),
		boss = { name = "Jungle Titan", hp = 15000000, color = Color3.fromRGB(20, 90, 40), every = 3, radius = 14, gems = 80, coins = 4000000 },
	},
}
Config.BOSS_HP_PER_EXTRA_PLAYER = 0.6 -- +60% boss HP for every party member after the first
Config.RUN_COMPLETE_GEMS = 150

function Config.zoneStartZ(zone: number): number
	return Config.FIRST_ZONE_Z + (zone - 1) * Config.ZONE_SPACING
end

-------------------------------------------------------------------------------------------------------------
-- Mutations: rolled when a patch is first hit (hidden until then). Luck multiplies every non-None weight.
-------------------------------------------------------------------------------------------------------------
Config.MUTATIONS = {
	{ id = "None", weight = 860, mult = 1, gems = 0 },
	{ id = "Golden", weight = 80, mult = 2, gems = 1, color = Color3.fromRGB(255, 205, 40) },
	{ id = "Rainbow", weight = 35, mult = 3, gems = 2, color = Color3.fromRGB(255, 110, 200) },
	{ id = "Diamond", weight = 15, mult = 5, gems = 4, color = Color3.fromRGB(120, 230, 255) },
	{ id = "Toxic", weight = 7, mult = 7, gems = 8, color = Color3.fromRGB(150, 255, 40) },
	{ id = "Galaxy", weight = 3, mult = 10, gems = 20, color = Color3.fromRGB(130, 70, 255) },
}

function Config.mutation(id: string)
	for _, m in Config.MUTATIONS do
		if m.id == id then
			return m
		end
	end
	return Config.MUTATIONS[1]
end

function Config.rollMutation(rng: Random, luck: number): string
	local total = 0
	for _, m in Config.MUTATIONS do
		total += if m.id == "None" then m.weight else m.weight * luck
	end
	local pick = rng:NextNumber() * total
	for _, m in Config.MUTATIONS do
		pick -= if m.id == "None" then m.weight else m.weight * luck
		if pick <= 0 then
			return m.id
		end
	end
	return "None"
end

-------------------------------------------------------------------------------------------------------------
-- Classes: bought with gems from the lobby booth (stock rolls every 5 min), owned forever, one equipped.
-------------------------------------------------------------------------------------------------------------
Config.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 90),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 110),
	Secret = Color3.fromRGB(40, 40, 50),
}
Config.CLASSES = {
	{ id = "WeedPuller", name = "Weed Puller", rarity = "Common", gems = 0, power = 0.05 },
	{ id = "Gardener", name = "Gardener", rarity = "Uncommon", gems = 180, power = 0.10, carry = 1 },
	{ id = "Groundskeeper", name = "Groundskeeper", rarity = "Rare", gems = 270, carry = 2, sell = 0.10 },
	{ id = "LawnBaron", name = "Lawn Baron", rarity = "Rare", gems = 330, sell = 0.30 },
	{ id = "HedgeReaper", name = "Hedge Reaper", rarity = "Epic", gems = 500, power = 0.20, luck = 0.25 },
	{ id = "MowerSpecialist", name = "Mower Specialist", rarity = "Epic", gems = 800, power = 0.35, speed = 0.10 },
	{ id = "GrassTitan", name = "Grass Titan", rarity = "Legendary", gems = 1000, power = 0.60, carry = 2 },
	{ id = "UltimateGardener", name = "Ultimate Gardener", rarity = "Legendary", gems = 1600, power = 0.50, speed = 0.20, sell = 0.25 },
	{ id = "LawnLegend", name = "Lawn Legend", rarity = "Mythic", gems = 2700, power = 1.0, speed = 0.25, sell = 0.50, luck = 0.50, carry = 3, product = "ClassLawnLegend" },
	{ id = "GoatMan", name = "Goat Man", rarity = "Secret", gems = 4000, power = 2.0, speed = 0.35, sell = 1.0, luck = 1.0, carry = 5, product = "ClassGoatMan" },
}
Config.DEFAULT_CLASS = "WeedPuller"
Config.STOCK_WINDOW = 300 -- seconds between booth restocks
Config.STOCK_SLOTS = 4
Config.STOCK_WEIGHTS = { Uncommon = 40, Rare = 30, Epic = 15, Legendary = 8, Mythic = 4, Secret = 1 }

function Config.class(id: string)
	for _, c in Config.CLASSES do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- The booth stock for a 5-minute window. Same seed on every server, so every lobby shows the same stock.
function Config.classStock(window: number): { string }
	local rng = Random.new(window * 7919 + 13)
	local pool = {}
	for _, c in Config.CLASSES do
		local w = Config.STOCK_WEIGHTS[c.rarity]
		if w then
			table.insert(pool, { id = c.id, weight = w })
		end
	end
	local stock = {}
	for _ = 1, Config.STOCK_SLOTS do
		local total = 0
		for _, p in pool do
			total += p.weight
		end
		if total <= 0 then
			break
		end
		local pick = rng:NextNumber() * total
		for i, p in pool do
			pick -= p.weight
			if pick <= 0 then
				table.insert(stock, p.id)
				table.remove(pool, i)
				break
			end
		end
	end
	return stock
end

-------------------------------------------------------------------------------------------------------------
-- Gem perks (lobby): permanent, bought one level at a time with gems.
-------------------------------------------------------------------------------------------------------------
Config.PERKS = {
	{ id = "sell", name = "Sell Value", desc = "+10% coins per level", per = 0.10, costs = { 25, 60, 140, 300, 600 } },
	{ id = "bundle", name = "Bigger Bundle", desc = "+10% chance of a double bundle", per = 0.10, costs = { 40, 90, 200, 400, 800 } },
	{ id = "luck", name = "Mutation Luck", desc = "+20% mutation luck per level", per = 0.20, costs = { 40, 90, 200, 400, 800 } },
	{ id = "gem", name = "Gem Value", desc = "+10% gems per level", per = 0.10, costs = { 50, 120, 260, 520, 1000 } },
}

function Config.perk(id: string)
	for _, p in Config.PERKS do
		if p.id == id then
			return p
		end
	end
	return nil
end

-------------------------------------------------------------------------------------------------------------
-- Ride-on mowers: cut while you drive and burn fuel (1 per second of driving).
-- currency "coins": bought in a run, lost when the run ends. "gems"/"robux": owned forever.
-- "trial": a Robux mower that lasts one run.
-------------------------------------------------------------------------------------------------------------
Config.MOWERS = {
	{ id = "RustyRider", name = "Rusty Rider", currency = "coins", price = 500, damage = 6, radius = 6, speed = 30, fuel = 60, color = Color3.fromRGB(200, 90, 50) },
	{ id = "TurboTractor", name = "Turbo Tractor", currency = "coins", price = 40000, damage = 120, radius = 9, speed = 38, fuel = 90, color = Color3.fromRGB(60, 170, 255) },
	{ id = "GoldenZeroTurn", name = "Golden Zero-Turn", currency = "gems", price = 900, damage = 400, radius = 10, speed = 42, fuel = 120, color = Color3.fromRGB(255, 200, 40) },
	{ id = "MonsterMulcher", name = "Monster Mulcher", currency = "gems", price = 2500, damage = 3000, radius = 12, speed = 46, fuel = 150, color = Color3.fromRGB(150, 60, 220) },
	{ id = "TrialMower", name = "Trial Mower", currency = "trial", product = "TrialMower", damage = 800, radius = 11, speed = 44, fuel = 140, color = Color3.fromRGB(255, 80, 160) },
	{ id = "RocketMower", name = "Rocket Mower", currency = "robux", product = "RocketMower", damage = 2000, radius = 12, speed = 50, fuel = 200, color = Color3.fromRGB(255, 70, 40) },
}
Config.FUEL_PRICE_PER_ZONE = { 2, 8, 40, 200, 1000 } -- coins per fuel point, by the run's current zone

function Config.mower(id: string)
	for _, m in Config.MOWERS do
		if m.id == id then
			return m
		end
	end
	return nil
end

-------------------------------------------------------------------------------------------------------------
-- Rewards
-------------------------------------------------------------------------------------------------------------
Config.DAILY_GEMS = 35
Config.DAILY_COOLDOWN = 6 * 3600
Config.GROUP_GEMS = 100

-------------------------------------------------------------------------------------------------------------
-- Lobby parties
-------------------------------------------------------------------------------------------------------------
Config.PARTY_MAX = 4
Config.PARTY_COUNTDOWN = 15
Config.SOLO_COUNTDOWN = 3

-------------------------------------------------------------------------------------------------------------
-- Robux. Fill in the ids after creating them on the Creator Dashboard; an id of 0 shows "coming soon".
-- No paid item here has a random result. If one is ever added, give it `paidRandom = true` and show odds.
-------------------------------------------------------------------------------------------------------------
Config.PRODUCTS = {
	Gems150 = { id = 0, robux = 49, gems = 150, name = "150 Gems" },
	Gems500 = { id = 0, robux = 149, gems = 500, name = "500 Gems" },
	Gems1500 = { id = 0, robux = 399, gems = 1500, name = "1,500 Gems" },
	Gems5000 = { id = 0, robux = 999, gems = 5000, name = "5,000 Gems" },
	TrialMower = { id = 0, robux = 25, mower = "TrialMower", name = "Trial Mower (this run)" },
	RocketMower = { id = 0, robux = 499, mower = "RocketMower", name = "Rocket Mower" },
	ClassLawnLegend = { id = 0, robux = 799, class = "LawnLegend", name = "Lawn Legend class" },
	ClassGoatMan = { id = 0, robux = 1499, class = "GoatMan", name = "Goat Man class" },
}
Config.PRODUCT_ORDER = { "Gems150", "Gems500", "Gems1500", "Gems5000", "TrialMower", "RocketMower", "ClassLawnLegend", "ClassGoatMan" }

Config.PASSES = {
	DoubleCoins = { id = 0, robux = 299, name = "2x Coins", desc = "Double coins from the shredder" },
	DoubleGems = { id = 0, robux = 399, name = "2x Gems", desc = "Double gems from everything" },
	BigBag = { id = 0, robux = 199, name = "Big Bag", desc = "+10 bundles carried" },
	VIP = { id = 0, robux = 249, name = "VIP", desc = "+15% power, +15% sell, VIP tag" },
}
Config.PASS_ORDER = { "DoubleCoins", "DoubleGems", "BigBag", "VIP" }

function Config.productByAssetId(assetId: number)
	if assetId == 0 then
		return nil, nil
	end
	for key, p in Config.PRODUCTS do
		if p.id == assetId then
			return key, p
		end
	end
	return nil, nil
end

-------------------------------------------------------------------------------------------------------------
-- Look (Throw-an-Egg style studded bricks + bubbly UI)
-------------------------------------------------------------------------------------------------------------
Config.UI = {
	font = Enum.Font.FredokaOne,
	outline = Color3.fromRGB(30, 25, 45),
	green = Color3.fromRGB(80, 210, 80),
	yellow = Color3.fromRGB(255, 205, 50),
	orange = Color3.fromRGB(255, 140, 40),
	red = Color3.fromRGB(255, 80, 80),
	blue = Color3.fromRGB(60, 165, 255),
	purple = Color3.fromRGB(160, 95, 255),
	pink = Color3.fromRGB(255, 110, 190),
	panel = Color3.fromRGB(255, 245, 225),
	dark = Color3.fromRGB(45, 40, 65),
}

return Config
