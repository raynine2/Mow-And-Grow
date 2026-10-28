-- Mow A Lawn: every number and every piece of content lives here.
-- Systems read from this table, so new content starts with a new entry here.

local Config = {}

Config.GAME_NAME = "Mow A Lawn"
-- The end credits' MADE BY (client/Ending): the game's owner comes first by itself; add the Roblox usernames of
-- everyone else who builds the game with you in Studio here, e.g. { "BuilderName", "ScripterName" }. Each shows as
-- "Display Name (@username)".
Config.CREDITS_TEAM = {} :: { string }
Config.GROUP_ID = 96047379 -- Atlas Interactive Inc (group reward)
Config.ADMINS = { 1994267229 }

-- Studio only: which mode a test server starts in ("Lobby" or "Run").
-- The Workspace attribute ForceMode overrides this.
Config.STUDIO_MODE = "Lobby"

-- The ground: "Blender" = the ground_* models (server/GroundMesh), "Terrain" = Roblox Terrain (server/Ground).
-- Terrain for now: the ground models need a mesh upload, and as native parts they'd be thousands of wedges.
-- Blender falls back to Terrain by itself while its models aren't uploaded.
Config.GROUND = "Terrain"

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
	{ id = "Scissors", name = "Garden Scissors", cost = 25, kind = "swing", damage = 3, cooldown = 0.4, radius = 6, targets = 2, color = Color3.fromRGB(255, 80, 80) },
	{ id = "Sickle", name = "Sickle", cost = 1500, kind = "swing", damage = 12, cooldown = 0.45, radius = 8, targets = 4, color = Color3.fromRGB(190, 190, 205) },
	{ id = "PushMower", name = "Push Mower", cost = 7000, kind = "auto", damage = 30, radius = 6, color = Color3.fromRGB(255, 140, 30) },
	{ id = "WeedWhacker", name = "Weed Whacker", cost = 60000, kind = "auto", damage = 140, radius = 9, color = Color3.fromRGB(60, 200, 80) },
	{ id = "MegaScythe", name = "Mega Scythe", cost = 400000, kind = "swing", damage = 2500, cooldown = 0.5, radius = 13, targets = 12, color = Color3.fromRGB(150, 90, 255) },
	{ id = "LaserMower", name = "Laser Mower", cost = 1500000, kind = "auto", damage = 4000, radius = 11, color = Color3.fromRGB(60, 230, 255) },
}
Config.BOSS_TOOL_MULT = 1 -- tool damage multiplier against bosses

-------------------------------------------------------------------------------------------------------------
-- Run upgrades (coins, Tab menu). Bought one level at a time, reset every run.
-------------------------------------------------------------------------------------------------------------
-- `section` groups them in the upgrades window (Hands / Tool / Gear). Carry comes from bags (Config.BAGS); the old
-- "carry" upgrade is gone, but levels bought before still count (Config.LEGACY_CARRY_PER bundles each).
Config.UPGRADE_SECTIONS = { "Hands", "Tool", "Gear" }
Config.UPGRADES = {
	-- like Chop A Forest's first purchase: until you own it, every swing is a click
	{ id = "hold", section = "Hands", name = "Hold", desc = "Hold the button to keep cutting", per = 1, base = 20, growth = 1, max = 1 },
	{ id = "swing", section = "Hands", name = "Swing Speed", desc = "-6% time between swings", per = 0.06, base = 30, growth = 2.6, max = 10 },
	{ id = "grasp", section = "Hands", name = "Grasp", desc = "+1.5 studs pickup reach", per = 1.5, base = 60, growth = 2.5, max = 10 },
	{ id = "power", section = "Tool", name = "Power", desc = "+20% cutting power", per = 0.20, base = 100, growth = 3.2, max = 10 },
	{ id = "speed", section = "Gear", name = "Walk Speed", desc = "+6% walk speed", per = 0.06, base = 250, growth = 3.0, max = 10 },
	{ id = "sell", section = "Gear", name = "Shredder Boost", desc = "+15% coins per bundle", per = 0.15, base = 300, growth = 3.4, max = 10 },
}
Config.LEGACY_CARRY_PER = 3

-------------------------------------------------------------------------------------------------------------
-- Loot: a cut patch drops its bundle on the ground (and sometimes a free gem). Only you can pick up yours: walk
-- within your Grasp reach and it flies into your bag. Bundles on the ground count toward your bag, so you can't
-- cut more than you can carry.
-------------------------------------------------------------------------------------------------------------
Config.LOOT = {
	grasp = 7, -- base pickup reach in studs (+ Grasp upgrades, x the Leaf Vacuum)
	maxOnGround = 60, -- per player, whatever their bag size
	spread = 2.5, -- how far from the patch a drop lands
}
Config.GEM_DROP = { chance = 0.035, min = 1, max = 3 } -- per cut patch, before Gem Value / 2x Gems

-- Bags: bought in order at the Bag Stand in the hub (coins, reset every run). The Bottomless Sack game pass
-- (Config.PASSES.BigBag) makes your bag endless.
Config.BAGS = {
	{ id = "Satchel", name = "Grass Satchel", model = "bag_satchel", cost = 175, carry = 5 },
	{ id = "Backpack", name = "Clipping Backpack", model = "bag_backpack", cost = 600, carry = 15 },
	{ id = "Expedition", name = "Expedition Pack", model = "bag_hiker", cost = 4000, carry = 40 },
}
Config.ENDLESS_CARRY = 9999 -- what "endless" means in numbers (the HUD shows it as a big infinity sign)

-- The Leaf Vacuum: gear from the Bag Stand. Owned for the run, works on its own (no need to hold it).
Config.VACUUM = { name = "Leaf Vacuum", cost = 1000, graspMult = 3 }

-- The Index: every grass type x mutation you've collected. A new one pays gems once.
Config.INDEX_GEMS = 5

-- GOLDEN GNOME HUNT (owner, 27 Oct): little golden gnomes hide at the foot of the grass clumps, `perArea` in every
-- area of a run. Walk up and pick one up (E): everyone in the server hears who found which, and it goes in your
-- collection (the Index window). One gnome per area plus the rare Diamond Gnome, which can take the place of any
-- hidden gnome (`diamondChance` each, at most one per run). The first of each kind pays `gems` (the Diamond its
-- own), later copies `againGems`, and the whole set `setGems` once. `hat` colours each area's gnome.
Config.GNOMES = {
	perArea = 3,
	diamondChance = 0.04,
	againGems = 2,
	setGems = 500,
	reach = 9, -- how close you must be to pick one up (studs)
	list = {
		{ id = "Backyard", name = "Backyard Gnome", zone = 1, gems = 15, hat = Color3.fromRGB(226, 58, 48) },
		{ id = "Meadow", name = "Meadow Gnome", zone = 2, gems = 20, hat = Color3.fromRGB(172, 102, 232) },
		{ id = "Golf", name = "Golf Gnome", zone = 3, gems = 25, hat = Color3.fromRGB(245, 245, 240) },
		{ id = "Wheat", name = "Wheat Gnome", zone = 4, gems = 30, hat = Color3.fromRGB(242, 138, 38) },
		{ id = "Blossom", name = "Blossom Gnome", zone = 5, gems = 40, hat = Color3.fromRGB(255, 128, 190) },
		{ id = "Swamp", name = "Swamp Gnome", zone = 6, gems = 50, hat = Color3.fromRGB(52, 168, 150) },
		{ id = "Prairie", name = "Prairie Gnome", zone = 7, gems = 60, hat = Color3.fromRGB(186, 78, 40) },
		{ id = "Jungle", name = "Jungle Gnome", zone = 8, gems = 80, hat = Color3.fromRGB(140, 220, 40) },
		{ id = "Diamond", name = "Diamond Gnome", zone = 0, gems = 200, hat = Color3.fromRGB(225, 250, 255), diamond = true },
	},
}
function Config.gnome(id: string)
	for _, g in Config.GNOMES.list do
		if g.id == id then
			return g
		end
	end
	return nil
end

-- CAMERA KICK (the report "Making Mow A Lawn feel as satisfying as Chop A Forest", 28 Oct, section 3: "the screen
-- moves when you swing"). client/CameraView draws it. Angles in degrees.
--   hit:    every hand-tool hit (yours): the view dips `pitch` and rolls `roll` (alternating sides) on the impact
--           frame and springs back in about 0.15 s. No field-of-view punch and no freeze on a normal hit.
--   bump:   auto tools and ride-on mowers while they cut: a tiny dip, at most one every `every` seconds.
--   felled / gnome / area: the big moments (a clump you chopped falls, a gnome found, an area at 100%): a jolt of
--           2.4 x that many degrees plus that much trauma (0..1), a rumble. bossHit: trauma on top of the hit's jolt.
--           The rumble you see is trauma squared, on smooth noise, so a small one is a shiver and a big one is
--           strong; boss slams use the old shake powers (10 = trauma 1).
--   maxAngle / maxOffset: the rumble at trauma 1 (tilt, and a nudge in studs); decay: trauma lost per second.
--   (play-tested 27 Oct: a hit dips 0.75 deg and is gone in ~0.17 s; a rumble of 0.45 alone only showed ~0.2 deg,
--   less than a hit, hence the jolt on the big moments and the 3 deg full tilt)
--   reduced: the Settings "Reduce camera shake" switch scales everything by this; potato: Potato Mode does
--           the same and drops the field-of-view punches.
Config.CAMERA_KICK = {
	hit = { pitch = 0.75, roll = 0.45 },
	bump = { pitch = 0.18, every = 0.3 },
	felled = 0.5,
	bossHit = 0.45,
	gnome = 0.6,
	area = 0.8,
	maxAngle = 3,
	maxOffset = 0.12,
	decay = 1.8,
	reduced = 0.35,
	potato = 0.5,
}

-- THE REST OF THE REPORT (owner, 27 Oct: "do it"). Each switch below turns its part off.
-- #1 FIRST 90 SECONDS: a brand-new player (no grass cut, nothing sold, no run finished) mows within seconds.
--   autoStart: seconds in the lobby before a first-timer is sent into a solo run (no News window, no pad to find; a
--              STAY IN LOBBY button cancels it). 0 = off.
--   loaner:    the tool lent to a first-timer for their first run until their first sale ("walk into the grass to
--              mow it"); then they're back to Bare Hands and buy their own. "" = off.
--   introAfterSale: the intro film waits for that first sale instead of playing before you've cut anything.
Config.FIRST_TIMER = { autoStart = 6, loaner = "PushMower", introAfterSale = true }
-- #2 COINS ON EVERY CUT (Chop A Forest pays a few coins per hit): this share of a clump's bundle value is paid the
-- moment you cut it (at least 1 coin); the bundles still sell in full. 0 = off.
Config.CUT_COINS = 0.25
-- #9 FINISHING AN AREA: dings when the area passes these shares; the last `glowAt` share of clumps glow with a
-- beacon so you find them; at `autoAt` the leftovers are mowed for you and paid out in coins (no hunting the last
-- 1%). autoAt = 1 turns the auto-finish off.
Config.AREA_FINISH = { dings = { 0.25, 0.5, 0.75, 0.9 }, glowAt = 0.95, autoAt = 0.97 }
-- #16 RUN MEDALS: finish a run under these times. Saved in the profile; `badge` is the Roblox badge to award once
-- the owner has made it (0 = none). Peaceful runs and runs joined part-way through don't count (like BEST TIMES).
Config.RUN_MEDALS = {
	{ id = "Gold", name = "Gold", minutes = 60, badge = 0, color = Color3.fromRGB(255, 205, 50) },
	{ id = "Silver", name = "Silver", minutes = 75, badge = 0, color = Color3.fromRGB(205, 215, 230) },
	{ id = "Bronze", name = "Bronze", minutes = 90, badge = 0, color = Color3.fromRGB(215, 140, 80) },
}
-- The best medal a run of `seconds` earns (nil = none).
function Config.runMedal(seconds: number)
	for _, m in Config.RUN_MEDALS do
		if seconds > 0 and seconds <= m.minutes * 60 then
			return m
		end
	end
	return nil
end

-- WORLD 2 TEASER (owner, 27 Oct: the ending "teasing world 2 a corrupt world with a demon glitch type of enemy and
-- boss", and a sneak peek of it in the opening). client/Ending's twist and title, client/Intro's peek (`peek`).
Config.WORLD2 = { title = "WORLD 2", name = "THE CORRUPTED VALLEY", soon = "COMING SOON", peek = true }

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
-- Areas (zones), like Chop A Forest's woods: fenced fields that open one after another. Mow every clump in the
-- newest area and the next one unlocks (its gates sink into the ground). Clumps are "grass trees": you chop one
-- down, it falls over and breaks into `drops` bundles, and its stubble stays until the whole area is cleared.
-- Clumps stand 7-14 studs tall like trees (`scale` x their model, `spacing` studs apart); later areas are tougher.
-- model: the clump model (default "tuft_" .. style); tint: recolour it (flat colour instead of its texture).
-------------------------------------------------------------------------------------------------------------
Config.BASE_CARRY = 5
-- Pacing (22 Oct, after the Chop A Forest teardown): aim for a free-to-play clear of 60-90 minutes, with the first
-- boss and a ride-on mower inside the first 15. A rough sim of one good player came out at ~56 min of mowing plus
-- the boss fights (area 1 ~7 min with its new drop-off pad, server/RunWorld). Values were x1.5 from area 2, HP -20%
-- in areas 5-7, areas 4 and 7 spaced wider (fewer clumps), and the Push Mower, Weed Whacker, bags and Rusty Rider
-- made cheaper. Retune here after real playtests.
Config.BOSSES = true -- clearing an area wakes its boss, and beating the boss opens the next area (false: areas open straight away)

Config.ZONES = {
	{
		name = "Backyard Lawn", grassName = "Lawn Grass", style = "lawn", hp = 3, value = 2, drops = 1, height = 2,
		spacing = 11, scale = 4.0,
		grass = { Color3.fromRGB(110, 210, 70), Color3.fromRGB(90, 195, 60) },
		ground = Color3.fromRGB(150, 110, 70),
		boss = { name = "Dandelion King", hp = 400, color = Color3.fromRGB(255, 220, 40), every = 4.5, radius = 9, gems = 10, coins = 150 },
	},
	{
		name = "Flower Meadow", grassName = "Meadow Grass", style = "meadow", model = "tuft_golf", hp = 12, value = 12, drops = 1, height = 2.2,
		spacing = 11.5, scale = 6.3, tint = Color3.fromRGB(150, 215, 95),
		grass = { Color3.fromRGB(150, 215, 95), Color3.fromRGB(130, 200, 80) },
		ground = Color3.fromRGB(120, 160, 70),
		boss = { name = "Bramble Brute", hp = 2000, color = Color3.fromRGB(40, 140, 60), every = 4.2, radius = 9, gems = 15, coins = 600 },
	},
	{
		name = "Golf Course", grassName = "Golf Grass", style = "golf", hp = 50, value = 45, drops = 1, height = 2.5,
		spacing = 12.5, scale = 7.2,
		grass = { Color3.fromRGB(70, 200, 90), Color3.fromRGB(55, 180, 75) },
		ground = Color3.fromRGB(235, 215, 150),
		boss = { name = "Bunker Thornback", hp = 6000, color = Color3.fromRGB(235, 200, 110), every = 4, radius = 10, gems = 20, coins = 2000 },
	},
	{
		name = "Wheat Farm", grassName = "Wheat", style = "wheat", hp = 150, value = 80, drops = 1, height = 5,
		spacing = 11, scale = 4.0,
		grass = { Color3.fromRGB(240, 200, 80), Color3.fromRGB(225, 180, 60) },
		ground = Color3.fromRGB(140, 95, 55),
		boss = { name = "Harvest Maw", hp = 90000, color = Color3.fromRGB(240, 200, 80), every = 3.6, radius = 11, gems = 35, coins = 25000 },
	},
	{
		name = "Blossom Garden", grassName = "Blossom Grass", style = "blossom", model = "tuft_lawn", hp = 480, value = 300, drops = 2, height = 2.5,
		spacing = 13.5, scale = 5.1, tint = Color3.fromRGB(255, 160, 205),
		grass = { Color3.fromRGB(255, 160, 205), Color3.fromRGB(240, 130, 185) },
		ground = Color3.fromRGB(120, 170, 80),
		boss = { name = "Sakura Snapjaw", hp = 300000, color = Color3.fromRGB(255, 150, 200), every = 3.5, radius = 11, gems = 45, coins = 80000 },
	},
	{
		name = "Swamp Reeds", grassName = "Reeds", style = "reeds", hp = 2000, value = 1100, drops = 2, height = 6.5,
		spacing = 12, scale = 4.6,
		grass = { Color3.fromRGB(80, 150, 100), Color3.fromRGB(60, 130, 90) },
		ground = Color3.fromRGB(70, 100, 85),
		boss = { name = "Bog Strangler", hp = 1200000, color = Color3.fromRGB(125, 212, 90), every = 3.3, radius = 12, gems = 55, coins = 300000 },
	},
	{
		name = "Autumn Prairie", grassName = "Prairie Grass", style = "prairie", model = "tuft_wheat", hp = 4800, value = 2400, drops = 2, height = 6,
		spacing = 11.5, scale = 5.1, tint = Color3.fromRGB(235, 120, 45),
		grass = { Color3.fromRGB(235, 120, 45), Color3.fromRGB(215, 95, 40) },
		ground = Color3.fromRGB(150, 110, 60),
		boss = { name = "Hollow Harvest", hp = 4000000, color = Color3.fromRGB(255, 140, 40), every = 3.1, radius = 13, gems = 65, coins = 1000000 },
	},
	{
		name = "Mega Jungle", grassName = "Jungle Bush", style = "jungle", hp = 60000, value = 12000, drops = 4, height = 8,
		spacing = 21, scale = 6.0,
		grass = { Color3.fromRGB(30, 160, 60), Color3.fromRGB(20, 130, 50) },
		ground = Color3.fromRGB(90, 70, 45),
		boss = { name = "Jungle Titan", hp = 15000000, color = Color3.fromRGB(63, 230, 200), every = 3, radius = 14, gems = 80, coins = 4000000 },
	},
}
-- Boss weapon crate (Chop A Forest v2): a crate parachutes in when a boss appears; opening it gives you your best
-- gun for the fight (taken away when the boss falls). Damage is a share of the boss's max HP per shot, so every
-- zone's boss takes about the same time. `product` = bought with Robux, yours in every fight.
Config.GUNS = {
	{ id = "Pistol", name = "Glock-18", pct = 0.004, rate = 5, range = 110, color = Color3.fromRGB(60, 60, 70), stats = "SEMI-AUTO - 5 SHOTS/S - 110 STUDS" },
	{ id = "Rifle", name = "AK-47", product = "GunRifle", pct = 0.005, rate = 9, range = 130, color = Color3.fromRGB(150, 95, 50), stats = "AUTO - 9 SHOTS/S - 130 STUDS" },
	{ id = "Minigun", name = "Minigun", product = "GunMinigun", pct = 0.004, rate = 20, range = 120, spin = 0.8, color = Color3.fromRGB(90, 95, 110), stats = "SPINS UP, THEN SHREDS - 20 SHOTS/S" },
}
function Config.gun(id: string)
	for _, g in Config.GUNS do
		if g.id == id then
			return g
		end
	end
	return nil
end

-- Day and night in a run. At night Weed Crawlers creep out of the grass and chase players outside the hub; a hit
-- stuns you. Peaceful Mode (the host's lobby toggle) turns them off, and a peaceful run doesn't set a best time.
Config.DAY_LENGTH = 420
Config.NIGHT_LENGTH = 120
Config.CRAWLERS = {
	name = "Weed Crawler",
	maxPerPlayer = 2,
	maxTotal = 8,
	every = 8, -- seconds between spawns (per player, while under the cap)
	speed = 10,
	hpHits = 2, -- HP = the zone's grass HP x this (tested 20 Oct: 4 was too tanky for bare hands)
	reward = 8, -- coins = the zone's grass value x this
	color = Color3.fromRGB(70, 40, 90),
}

Config.BOSS_HP_PER_EXTRA_PLAYER = 0.6 -- (old fights; server/Boss now uses BOSS_PARTY_HP)
-- Boss fights (the owner's boss brief, 26 Oct; moves, timing and words in shared/BossMoves):
-- boss HP x this for 1 / 2 / 3 / 4+ players in the arena when the fight starts
Config.BOSS_PARTY_HP = { 1, 1.7, 2.4, 3.0 }
-- Boss HP per area: about 2.5 minutes for one player with the area's expected tool (Scissors, Sickle, Push Mower,
-- Weed Whacker x2, Mega Scythe x2, Laser Mower) and a few Power upgrades, hitting about half the time plus the
-- x2.5 punish windows. Guesses from Config.TOOLS (26 Oct): retune after real playtests.
Config.BOSS_HP = { 1400, 5000, 25000, 120000, 200000, 1200000, 1500000, 4800000 }
-- Players in a boss fight (server/BossFighters): 100 HP; at 0 you're downed for BOSS_DOWN_TIME s and a teammate
-- standing next to you for BOSS_REVIVE_TIME s picks you up, else you get up at the arena entrance.
Config.BOSS_PLAYER_HP = 100
Config.BOSS_DOWN_TIME = 10
Config.BOSS_REVIVE_TIME = 2.5
Config.BOSS_REVIVE_RADIUS = 9
-- juice boxes (owner, 26 Oct round 2): +30 HP, one every ~20 s and one each time the boss is stunned open
Config.BOSS_HEAL = { every = 20, amount = 30, life = 16, radius = 5, onPunish = true }
-- pets chip in (owner, round 2): every `every` s each standing fighter's equipped pets take perPet x (number of
-- pets) of the boss's max HP; small on purpose (3 pets: about a tenth of the boss over a 2.5 minute fight)
Config.BOSS_PET_CHIP = { every = 1, perPet = 0.00025 }
-- no-hit bonus (owner, round 2): extra gems for a fighter the boss never hit in that fight (x the area's boss gems)
Config.BOSS_NOHIT_GEMS = 1
-- Roblox badge per boss (0 = none yet: make them on the Creator Hub and put the ids here); the in-game trophy
-- (PlayerData.bossTrophies) is given either way.
Config.BOSS_BADGES = { 0, 0, 0, 0, 0, 0, 0, 0 }
-- Boss arenas (server/BossArena): a fenced 140-stud pocket at the FAR END of each area (owner, round 2: opposite
-- the gate you come in by). x, z = the middle; picked in Studio (26 Oct) by raycasting the generated ground: the
-- flattest spot within 80 degrees of straight across from the way in, 85-135 studs from the area's middle, at
-- least 100 studs from the landmark and the way out, and clear of the camp, the gates, the pads and the isles'
-- bridges (an arena never sits on one of those; trees and rocks inside are cleared). Move one by changing its
-- numbers here.
Config.BOSS_ARENA_RADIUS = 70
Config.BOSS_ARENAS = {
	{ x = -26, z = 460 },
	{ x = -434, z = 337 },
	{ x = -469, z = -233 },
	{ x = -187, z = -508 },
	{ x = 285, z = -472 },
	{ x = 544, z = -154 },
	{ x = 400, z = 277 }, -- 7 and 8 moved (26 Oct): the old spots sat on the Starlight gate and the isles' sell pad
	{ x = 130, z = 650 },
}
Config.RUN_COMPLETE_GEMS = 150

-- (old straight-road layout; only the unused Blender ground sheets in server/GroundMesh still read these)
Config.ZONE_SPACING = 120
Config.FIRST_ZONE_Z = 30
function Config.zoneStartZ(zone: number): number
	return Config.FIRST_ZONE_Z + (zone - 1) * Config.ZONE_SPACING
end

-------------------------------------------------------------------------------------------------------------
-- The run map: ONE continuous world like Chop A Forest's, a 3 x 3 grid of square fenced plots. The hub (spawn,
-- tool shop, shredder, bag stand, garage) is the middle plot of the south row and the areas fill the other eight,
-- opening outward from the hub: the first right in front of it, the next two beside it, then the middle row's
-- sides, then the far row. Every two plots that touch share a fence with a gate in the middle, and a gate opens
-- once both of its plots are open. A forest belt and snowy mountains close the world off.
-- Grid cells are { col, row }: col 1..3 runs west to east (-X to +X), row 1..3 south to north (-Z to +Z).
-------------------------------------------------------------------------------------------------------------
Config.MAP = {
	cell = 180, -- one plot's side, fence to fence
	hubCell = { 2, 1 },
	hubCentre = Vector3.new(0, 0, -48), -- the middle of the hub plot (the hub buildings are built around it)
	cells = { { 2, 2 }, { 3, 1 }, { 1, 1 }, { 3, 2 }, { 1, 2 }, { 2, 3 }, { 3, 3 }, { 1, 3 } }, -- area z's plot
	gateWidth = 20, -- the opening in a shared fence
	margin = 13, -- no grass this close to a fence (each area's signature trees line the inside of its fences)
	dropOff = 1, -- the second shredder stands in the middle of this area (Chop A Forest's far-off shredder)
}

local function cellOf(z: number): { number }
	return if z <= 0 then Config.MAP.hubCell else Config.MAP.cells[z]
end

-- The middle of area z's plot (z = 0: the hub), on the ground.
function Config.zoneCentre(z: number): Vector3
	local M = Config.MAP
	local c = cellOf(z)
	return M.hubCentre + Vector3.new((c[1] - M.hubCell[1]) * M.cell, 0, (c[2] - M.hubCell[2]) * M.cell)
end

-- Half the side of a plot.
function Config.zoneHalf(): number
	return Config.MAP.cell / 2
end

-- Which area a point is in: 0 = the hub, 1..n = an area, -1 = outside the map.
function Config.zoneAt(pos: Vector3): number
	local M = Config.MAP
	local col = math.floor((pos.X - M.hubCentre.X) / M.cell + 0.5) + M.hubCell[1]
	local row = math.floor((pos.Z - M.hubCentre.Z) / M.cell + 0.5) + M.hubCell[2]
	if col == M.hubCell[1] and row == M.hubCell[2] then
		return 0
	end
	for z, c in M.cells do
		if c[1] == col and c[2] == row then
			return z
		end
	end
	return -1
end

-- Every gate: a shared fence between two plots that touch. { a, b } are the areas on each side (0 = the hub,
-- a < b), pos is the gate's middle on the ground and along the direction the fence runs. A gate is open once
-- area b is unlocked.
export type Gate = { a: number, b: number, pos: Vector3, along: Vector3 }
local gateList: { Gate }? = nil
function Config.gates(): { Gate }
	if gateList then
		return gateList
	end
	local list: { Gate } = {}
	local ids = { 0 }
	for z = 1, #Config.MAP.cells do
		table.insert(ids, z)
	end
	for i = 1, #ids do
		for j = i + 1, #ids do
			local a, b = ids[i], ids[j]
			local ca, cb = cellOf(a), cellOf(b)
			local dc, dr = cb[1] - ca[1], cb[2] - ca[2]
			if math.abs(dc) + math.abs(dr) == 1 then
				local mid = (Config.zoneCentre(a) + Config.zoneCentre(b)) / 2
				table.insert(list, { a = math.min(a, b), b = math.max(a, b), pos = mid, along = if dc ~= 0 then Vector3.zAxis else Vector3.xAxis })
			end
		end
	end
	gateList = list
	return list
end

-- The gate you walk through into area z: the one from the most recently opened neighbour.
function Config.gateInto(z: number): Gate?
	local best: Gate? = nil
	for _, g in Config.gates() do
		if g.b == z and (best == nil or g.a > best.a) then
			best = g
		end
	end
	return best
end

-- Where that gate is, on the ground.
function Config.gatePos(z: number): Vector3
	local g = Config.gateInto(z)
	return if g then g.pos else Config.zoneCentre(z)
end

-- A spot just inside area z, past its gate.
function Config.zoneEntry(z: number): Vector3
	local g = Config.gateInto(z)
	if not g then
		return Config.zoneCentre(z)
	end
	local into = Config.zoneCentre(z) - g.pos
	return g.pos + into.Unit * 10
end

-------------------------------------------------------------------------------------------------------------
-- The generated world (server/WorldGen from shared/Zones): a village in the middle and eight valleys around
-- it, each behind one gate. When WORLD_GEN is on, runs play there (server/RunWorld) and the map helpers above
-- answer for it: Config zone z is Zones.list[z], the hub is the village (its buildings south of the fountain),
-- and gate positions come from attributes WorldGen puts on Workspace.World (GatePos<z>, GateEntry<z>).
-------------------------------------------------------------------------------------------------------------
Config.WORLD_GEN = true
-- Name signs on the hub buildings (shop boards, the arches, START A RUN, floating DROP BUNDLES / GAS labels).
-- Off: the buildings speak for themselves and their prompts name them. Price tags and the score boards stay.
Config.HUB_SIGNS = false
-- The run camp's CLASSES stand is a black hole you jump into (server/BlackHole, client/BlackHole). Off: the old
-- observatory kiosk with its class hologram (classes_kiosk, client/ClassHolo).
Config.CLASSES_BLACK_HOLE = true

do
	local Zones = require(script.Parent.Zones)
	local plotCentre, plotAt, plotGates, plotEntry = Config.zoneCentre, Config.zoneAt, Config.gates, Config.zoneEntry
	local HUB = Vector3.new(0, 0, -48)

	local function genWorld(): Instance?
		local w = workspace:FindFirstChild("World")
		return if w and w:GetAttribute("GatePos2") ~= nil then w else nil
	end

	function Config.zoneCentre(z: number): Vector3
		if not Config.WORLD_GEN then
			return plotCentre(z)
		end
		local def = Zones.list[z]
		if z <= 0 or not def then
			return HUB
		end
		return Vector3.new(def.center.X, def.base, def.center.Y)
	end

	function Config.zoneAt(pos: Vector3): number
		if not Config.WORLD_GEN then
			return plotAt(pos)
		end
		return Zones.zoneAt(pos) or -1
	end

	function Config.gates(): { Gate }
		local w = Config.WORLD_GEN and genWorld()
		if not w then
			return plotGates()
		end
		local list: { Gate } = {}
		for z = 1, #Zones.list do
			local pos = w:GetAttribute("GatePos" .. z)
			if typeof(pos) == "Vector3" then
				table.insert(list, { a = z - 1, b = z, pos = pos, along = Vector3.xAxis })
			end
		end
		return list
	end

	function Config.zoneEntry(z: number): Vector3
		local w = Config.WORLD_GEN and genWorld()
		local entry = w and w:GetAttribute("GateEntry" .. z)
		if typeof(entry) == "Vector3" then
			return entry
		end
		return plotEntry(z)
	end
end

-------------------------------------------------------------------------------------------------------------
-- World look: lighting and post-processing (shared/Look applies it). `base` is the lobby and the hub; the
-- server sets it at start. In a run the client (client/ZoneMood) blends toward each zone's mood as you walk,
-- so a mood only lists what it changes. Colours are Color3, the rest numbers; everything here can be blended.
-------------------------------------------------------------------------------------------------------------
Config.LOOK = {
	-- set once by the server (not blended): an afternoon sun for long, soft shadows; built-in clouds
	clockTime = 15.2,
	latitude = 38,
	shadowSoftness = 0.25,
	envDiffuse = 0.75,
	envSpecular = 0.35,
	sunSize = 16, -- Sky.SunAngularSize (bigger, warmer sun for the glare)
	bloomSize = 26,
	bloomThreshold = 1.4, -- only HDR-bright things bloom (sun, neon, glare)
	dof = { focus = 60, radius = 70, far = 0.1 }, -- very soft blur far away only
	clouds = { cover = 0.42, density = 0.32, color = Color3.fromRGB(255, 255, 255) }, -- soft high streaks
	wind = Vector3.new(4, 0, 3), -- workspace.GlobalWind: drifts the clouds and the floating pollen
	base = {
		brightness = 2.7,
		exposure = 0.05,
		ambient = Color3.fromRGB(118, 112, 128),
		outdoorAmbient = Color3.fromRGB(168, 162, 170),
		colorShiftTop = Color3.fromRGB(255, 244, 222),
		saturation = 0.24,
		contrast = 0.1,
		ccBrightness = 0.015,
		tint = Color3.fromRGB(255, 251, 242),
		-- a saturated cartoon-blue sky with a pale, hazy band at the horizon (Chop A Forest's sky)
		atmoDensity = 0.3,
		atmoOffset = 0.25,
		atmoColor = Color3.fromRGB(214, 232, 255),
		atmoDecay = Color3.fromRGB(86, 136, 232),
		atmoGlare = 0.15,
		atmoHaze = 1.0,
		bloomIntensity = 0.55,
		raysIntensity = 0.05,
		raysSpread = 0.55,
	},
	-- Night in a run (server/DayNight turns the clock; client/ZoneMood blends this in as the sun goes down):
	-- deep blue light, stars and the moon in the sky.
	night = {
		brightness = 1.1,
		exposure = -0.05,
		ambient = Color3.fromRGB(58, 66, 110),
		outdoorAmbient = Color3.fromRGB(74, 88, 150),
		colorShiftTop = Color3.fromRGB(120, 140, 220),
		saturation = 0.08,
		contrast = 0.12,
		ccBrightness = 0.02,
		tint = Color3.fromRGB(196, 210, 255),
		atmoDensity = 0.32,
		atmoOffset = 0.2,
		atmoColor = Color3.fromRGB(70, 92, 160),
		atmoDecay = Color3.fromRGB(26, 36, 92),
		atmoGlare = 0,
		atmoHaze = 1.2,
		bloomIntensity = 0.8,
		raysIntensity = 0,
		raysSpread = 0.55,
	},
	day = { length = 480, nightLength = 240, dawn = 6.5, dusk = 18 }, -- seconds of day and night, sun times
	moods = {
		-- fresh green-gold
		lawn = {
			tint = Color3.fromRGB(252, 255, 236),
			saturation = 0.28,
			atmoColor = Color3.fromRGB(212, 232, 214),
			atmoDecay = Color3.fromRGB(140, 185, 165),
			colorShiftTop = Color3.fromRGB(255, 246, 215),
		},
		-- soft spring morning: light haze, a touch of warmth
		meadow = {
			tint = Color3.fromRGB(255, 252, 232),
			saturation = 0.32,
			atmoColor = Color3.fromRGB(225, 236, 214),
			atmoDecay = Color3.fromRGB(160, 195, 160),
			colorShiftTop = Color3.fromRGB(255, 240, 210),
			atmoHaze = 1.4,
		},
		-- pink blossom light: rosy air, gentle bloom
		blossom = {
			tint = Color3.fromRGB(255, 240, 246),
			saturation = 0.3,
			colorShiftTop = Color3.fromRGB(255, 225, 235),
			atmoColor = Color3.fromRGB(250, 222, 236),
			atmoDecay = Color3.fromRGB(215, 160, 190),
			atmoGlare = 0.4,
			atmoHaze = 1.5,
			bloomIntensity = 0.7,
		},
		-- late autumn sun: deep orange, long haze
		prairie = {
			tint = Color3.fromRGB(255, 228, 196),
			saturation = 0.34,
			contrast = 0.14,
			colorShiftTop = Color3.fromRGB(255, 196, 130),
			outdoorAmbient = Color3.fromRGB(190, 160, 135),
			atmoDensity = 0.32,
			atmoColor = Color3.fromRGB(250, 210, 165),
			atmoDecay = Color3.fromRGB(215, 130, 80),
			atmoGlare = 0.7,
			atmoHaze = 1.9,
			bloomIntensity = 0.7,
			raysIntensity = 0.12,
		},
		-- bright and clean: clearer air, crisp contrast
		golf = {
			tint = Color3.fromRGB(248, 252, 255),
			contrast = 0.13,
			ccBrightness = 0.03,
			atmoDensity = 0.22,
			atmoHaze = 0.6,
			atmoGlare = 0.15,
			atmoColor = Color3.fromRGB(215, 232, 255),
			bloomIntensity = 0.5,
		},
		-- warm golden afternoon
		wheat = {
			tint = Color3.fromRGB(255, 236, 205),
			saturation = 0.3,
			colorShiftTop = Color3.fromRGB(255, 212, 150),
			outdoorAmbient = Color3.fromRGB(185, 165, 145),
			atmoDensity = 0.3,
			atmoColor = Color3.fromRGB(255, 226, 182),
			atmoDecay = Color3.fromRGB(225, 165, 110),
			atmoGlare = 0.65,
			atmoHaze = 1.7,
			bloomIntensity = 0.7,
			raysIntensity = 0.1,
		},
		-- misty teal swamp
		reeds = {
			tint = Color3.fromRGB(222, 245, 242),
			saturation = 0.1,
			contrast = 0.05,
			ccBrightness = 0,
			ambient = Color3.fromRGB(105, 128, 128),
			outdoorAmbient = Color3.fromRGB(145, 168, 165),
			colorShiftTop = Color3.fromRGB(225, 245, 240),
			atmoDensity = 0.44,
			atmoOffset = 0.06,
			atmoColor = Color3.fromRGB(172, 214, 208),
			atmoDecay = Color3.fromRGB(90, 140, 140),
			atmoGlare = 0.1,
			atmoHaze = 2.6,
			raysIntensity = 0.03,
		},
		-- deep green, humid haze, god-rays through the canopy
		jungle = {
			brightness = 2.5,
			tint = Color3.fromRGB(228, 255, 226),
			saturation = 0.32,
			contrast = 0.15,
			ccBrightness = -0.02,
			ambient = Color3.fromRGB(95, 125, 95),
			outdoorAmbient = Color3.fromRGB(140, 170, 135),
			colorShiftTop = Color3.fromRGB(240, 255, 210),
			atmoDensity = 0.42,
			atmoOffset = 0.1,
			atmoColor = Color3.fromRGB(175, 212, 165),
			atmoDecay = Color3.fromRGB(60, 112, 72),
			atmoGlare = 0.45,
			atmoHaze = 2.2,
			bloomIntensity = 0.65,
			raysIntensity = 0.2,
			raysSpread = 0.8,
		},
	} :: { [string]: { [string]: any } },
}

-------------------------------------------------------------------------------------------------------------
-- Quests: the onboarding chain shown top-left during a run (like Chop A Forest's "QUEST 3/8").
-- event = what counts: cut (patches), sell (bundles sold), tool (best tool index reached), carry (backpack
-- levels), zone (zones cleared), boss (bosses beaten), mower (a ride-on mower bought or spawned).
-------------------------------------------------------------------------------------------------------------
Config.QUESTS = {
	{ title = "Cut 10 grass", hint = "Look at a clump and click to cut it", event = "cut", goal = 10, reward = 20 },
	{ title = "Sell your bundles", hint = "Walk onto the sell pad", event = "sell", goal = 5, reward = 40 },
	{ title = "Buy the Scissors in the cabin", hint = "They're on the wall inside the cabin", event = "tool", goal = 2, reward = 25 },
	{ title = "Buy a bag at the Bag Stand", hint = "It's by the spawn, next to the tool shop", event = "bag", goal = 1, reward = 100 },
	{ title = "Cut 60 grass", hint = "Keep mowing the Backyard Lawn", event = "cut", goal = 60, reward = 150 },
	{ title = "Mow the whole Backyard Lawn", hint = "Every last patch!", event = "zone", goal = 1, reward = 250 },
	{ title = "Get a ride-on mower", hint = "Buy one at the Garage", event = "mower", goal = 1, reward = 500 },
	{ title = "Mow the whole Flower Meadow", hint = "Its gate opens when you beat the lawn's boss", event = "zone", goal = 1, reward = 300 },
}

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
-- Rarer = better on every axis: each step up adds a stat and every stat it already had grows (Chop A Forest's
-- curve: a Secret has all five, e.g. Clawman +120% power / +38% speed / +50% sell / +85% luck / +10 carry).
--   Common 1 stat, Uncommon 2, Rare 3, Epic 4, Legendary/Mythic/Secret all 5
Config.CLASSES = {
	{ id = "WeedPuller", name = "Weed Puller", rarity = "Common", gems = 0, power = 0.05 },
	{ id = "Gardener", name = "Gardener", rarity = "Uncommon", gems = 180, power = 0.12, carry = 1, product = "ClassGardener" },
	{ id = "Groundskeeper", name = "Groundskeeper", rarity = "Rare", gems = 270, power = 0.18, sell = 0.10, carry = 2, product = "ClassGroundskeeper" },
	{ id = "LawnBaron", name = "Lawn Baron", rarity = "Rare", gems = 330, power = 0.15, sell = 0.30, carry = 2, product = "ClassLawnBaron" },
	{ id = "HedgeReaper", name = "Hedge Reaper", rarity = "Epic", gems = 500, power = 0.30, sell = 0.12, luck = 0.25, carry = 3, product = "ClassHedgeReaper" },
	{ id = "MowerSpecialist", name = "Mower Specialist", rarity = "Epic", gems = 800, power = 0.40, speed = 0.12, sell = 0.15, carry = 3, product = "ClassMowerSpecialist" },
	{ id = "GrassTitan", name = "Grass Titan", rarity = "Legendary", gems = 1000, power = 0.65, speed = 0.15, sell = 0.20, luck = 0.25, carry = 4, product = "ClassGrassTitan" },
	{ id = "UltimateGardener", name = "Ultimate Gardener", rarity = "Legendary", gems = 1600, power = 0.75, speed = 0.20, sell = 0.30, luck = 0.30, carry = 5, product = "ClassUltimateGardener" },
	{ id = "LawnLegend", name = "Lawn Legend", rarity = "Mythic", gems = 2700, power = 1.10, speed = 0.28, sell = 0.55, luck = 0.60, carry = 7, product = "ClassLawnLegend" },
	{ id = "GoatMan", name = "Goat Man", rarity = "Secret", gems = 4000, power = 1.5, speed = 0.40, sell = 0.7, luck = 1.0, carry = 10, product = "ClassGoatMan" }, -- +150 power / +70 sell (owner 27 Oct: was +200 / +100, too big a jump over Lawn Legend's +110; still the strongest)
}
-- Each class's own gimmick (owner, 27 Oct: unique, not only stats). server/ClassPerks runs them; the class cards show
-- these words.
Config.CLASS_GIMMICK = {
	WeedPuller = { name = "Root Rip", text = "Every 6th swing rips the clump out in one hit." },
	Gardener = { name = "Green Thumb", text = "Bundles fly to you from much further away." },
	Groundskeeper = { name = "Tidy Up", text = "When a clump falls, the 2 nearest clumps take a free hit." },
	LawnBaron = { name = "Courier", text = "A full bag sells itself for 80%, wherever you are (every 45 s)." },
	HedgeReaper = { name = "Reap Wave", text = "Every 8th swing sends a wave that hits every clump around you." },
	MowerSpecialist = { name = "Turbo Deck", text = "Ride-on mowers cut 40% wider, drive 20% faster, burn half the fuel." },
	GrassTitan = { name = "Titan Stomp", text = "Land from a jump to stomp: clumps around you take 2 hits (4 s cooldown)." },
	UltimateGardener = { name = "Midas Touch", text = "Every 20th clump you uncover is a mutation (Golden or better)." },
	LawnLegend = { name = "Hot Streak", text = "Cut fast: each clump in a streak adds +5% power, up to +60%." },
	GoatMan = { name = "Graze", text = "You eat grass as you walk: clumps around you take a hit every 0.5 s." },
}
-- each gimmick's own icon (ForgeGUI art, 27 Oct), shown on the big class card's gimmick row
Config.GIMMICK_ICONS = {
	WeedPuller = "rbxassetid://117785591700509",
	Gardener = "rbxassetid://123254637418981",
	LawnBaron = "rbxassetid://84660502573780",
	UltimateGardener = "rbxassetid://125116243612326",
	LawnLegend = "rbxassetid://90016869455155",
	GoatMan = "rbxassetid://87148456600074",
} :: { [string]: string }
Config.DEFAULT_CLASS = "WeedPuller"
Config.STOCK_WINDOW = 300 -- seconds between booth restocks
-- 3 classes per restock, rarer at the top so the best ones are worth waiting for (owner, 27 Oct; Chop A Forest's curve).
-- Shown odds come out about Uncommon 90% / Rare 59% / Epic 33% / Legendary 12% / Mythic 3.4% / Secret 1% (Lucky
-- Restock: Legendary 28% / Mythic 7.7% / Secret 1.5%); Config.CLASS_CHANCE works them out from these weights.
Config.STOCK_SLOTS = 3
Config.STOCK_WEIGHTS = { Uncommon = 130, Rare = 46, Epic = 22, Legendary = 7.5, Mythic = 1.55, Secret = 0.29 } -- (owner, 27 Oct: Lawn Legend 2.5%, Goat Man 0.5%)

function Config.class(id: string)
	for _, c in Config.CLASSES do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- Lucky Restock (Chop A Forest's "x3 LUCK"): rarity weights are multiplied by these.
-- (the top two at 5x so the shown odds really come out about 3x: 3 slots dealt without repeats dampen a raw multiplier)
Config.LUCKY_MULT = { Epic = 2, Legendary = 4, Mythic = 5, Secret = 5.5 }

function Config.stockWindow(): number
	return math.floor(workspace:GetServerTimeNow() / Config.STOCK_WINDOW)
end

-- Is a bought Restock (data.classDeal) still on? It lasts STOCK_WINDOW from the purchase (older saved deals: their
-- window).
function Config.dealActive(deal: any): boolean
	if type(deal) ~= "table" then
		return false
	end
	if type(deal.expires) == "number" then
		return workspace:GetServerTimeNow() < deal.expires
	end
	return deal.window == Config.stockWindow()
end

-- The booth stock for a 5-minute window. Same seed on every server, so every lobby shows the same stock.
function Config.classStock(window: number): { string }
	return Config.rollStock(Random.new(window * 7919 + 13), false)
end

-- Deal Config.STOCK_SLOTS different classes, weighted by rarity (luckier with `lucky`).
function Config.rollStock(rng: Random, lucky: boolean): { string }
	local pool = {}
	for _, c in Config.CLASSES do
		local w = Config.STOCK_WEIGHTS[c.rarity]
		if w then
			if lucky then
				w *= Config.LUCKY_MULT[c.rarity] or 1
			end
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

-- The odds shown on every class card: the chance a class is in a deal (normal and Lucky Restock).
-- Worked out once by dealing 20,000 times with a fixed seed, so every client shows the same numbers.
Config.CLASS_CHANCE = {} :: { [string]: number }
Config.CLASS_CHANCE_LUCKY = {} :: { [string]: number }
do
	local N = 20000
	for _, mode in { { Config.CLASS_CHANCE, false }, { Config.CLASS_CHANCE_LUCKY, true } } do
		local rng = Random.new(424242)
		local hits = {}
		for _ = 1, N do
			for _, id in Config.rollStock(rng, mode[2]) do
				hits[id] = (hits[id] or 0) + 1
			end
		end
		for id, n in hits do
			mode[1][id] = n / N
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- Pets: garden critters hatched from eggs, owned forever. Up to PET_EQUIP follow you and add their boosts.
-- Boost keys match Stats: power, sell, speed, luck (all +fractions). `look` tells client/PetFollow how to build it.
-------------------------------------------------------------------------------------------------------------
Config.PET_EQUIP = 3
Config.PET_MAX = 60 -- inventory size
Config.PETS = {
	{ id = "Bee", name = "Bumble Bee", rarity = "Common", power = 0.05, look = { kind = "bee", color = Color3.fromRGB(255, 200, 40), accent = Color3.fromRGB(40, 35, 30) } },
	{ id = "Snail", name = "Garden Snail", rarity = "Common", sell = 0.05, look = { kind = "snail", color = Color3.fromRGB(190, 220, 120), accent = Color3.fromRGB(170, 100, 60) } },
	{ id = "Bunny", name = "Lawn Bunny", rarity = "Uncommon", speed = 0.08, look = { kind = "bunny", color = Color3.fromRGB(240, 235, 225), accent = Color3.fromRGB(255, 160, 180) } },
	{ id = "Ladybug", name = "Ladybug", rarity = "Uncommon", luck = 0.10, look = { kind = "bug", color = Color3.fromRGB(230, 50, 45), accent = Color3.fromRGB(30, 25, 25) } },
	{ id = "Mole", name = "Burrow Mole", rarity = "Rare", power = 0.15, look = { kind = "mole", color = Color3.fromRGB(110, 80, 70), accent = Color3.fromRGB(255, 170, 170) } },
	{ id = "Hedgehog", name = "Hedgehog", rarity = "Rare", sell = 0.15, look = { kind = "hedgehog", color = Color3.fromRGB(150, 110, 80), accent = Color3.fromRGB(240, 210, 170) } },
	{ id = "Gnome", name = "Garden Gnome", rarity = "Epic", power = 0.25, sell = 0.10, look = { kind = "gnome", color = Color3.fromRGB(60, 120, 220), accent = Color3.fromRGB(230, 50, 50) } },
	{ id = "Firefly", name = "Firefly", rarity = "Epic", luck = 0.30, look = { kind = "bee", color = Color3.fromRGB(190, 255, 90), accent = Color3.fromRGB(50, 60, 40), glow = true } },
	{ id = "GoldenGnome", name = "Golden Gnome", rarity = "Legendary", power = 0.50, speed = 0.15, look = { kind = "gnome", color = Color3.fromRGB(255, 200, 40), accent = Color3.fromRGB(255, 230, 120), glow = true } },
	-- Golden Egg only
	{ id = "RoyalBeetle", name = "Royal Beetle", rarity = "Rare", power = 0.20, sell = 0.10, look = { kind = "bug", color = Color3.fromRGB(130, 60, 200), accent = Color3.fromRGB(255, 210, 60) } },
	{ id = "ThunderHare", name = "Thunder Hare", rarity = "Epic", speed = 0.25, power = 0.25, look = { kind = "bunny", color = Color3.fromRGB(90, 170, 255), accent = Color3.fromRGB(255, 240, 80), glow = true } },
	{ id = "RainbowButterfly", name = "Rainbow Butterfly", rarity = "Secret", power = 1.0, sell = 0.5, luck = 0.5, speed = 0.2, look = { kind = "butterfly", color = Color3.fromRGB(255, 110, 200), accent = Color3.fromRGB(110, 220, 255), glow = true } },
}
Config.PET_STATS = { "power", "sell", "speed", "luck" }

function Config.pet(id: string)
	for _, p in Config.PETS do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- Eggs. `pets` = { id, weight } (the weights ARE the shown odds, in %). currency gems: bought with gems (1 or 3);
-- currency robux: the products in `products` (1 / 3 / 10). Hatch Luck passes multiply the weight of every pet
-- of a `luckRarities` rarity (the window shows the odds with your luck applied).
Config.EGGS = {
	{
		id = "GardenEgg", name = "Garden Egg", currency = "gems", price = 120, color = Color3.fromRGB(120, 200, 80),
		pets = { { "Bee", 30 }, { "Snail", 26 }, { "Bunny", 16 }, { "Ladybug", 13 }, { "Mole", 6 }, { "Hedgehog", 5 }, { "Gnome", 2 }, { "Firefly", 1.5 }, { "GoldenGnome", 0.5 } },
	},
	{
		id = "GoldenEgg", name = "Golden Egg", currency = "robux", color = Color3.fromRGB(255, 190, 40), exclusive = true,
		desc = "Exclusive critters - Rare or better", -- (short: the card's line is 400 px wide)
		pets = { { "RoyalBeetle", 42 }, { "ThunderHare", 38 }, { "GoldenGnome", 16 }, { "RainbowButterfly", 4 } },
		products = { { count = 1, key = "GoldenEgg1" }, { count = 3, key = "GoldenEgg3" }, { count = 10, key = "GoldenEgg10", tag = "BEST VALUE" } },
	},
}
Config.HATCH_LUCK = { pass = 1.5, super = 2 } -- HatchLuck / SuperHatchLuck (they stack: x3)
Config.HATCH_LUCK_RARITIES = { Epic = true, Legendary = true, Mythic = true, Secret = true }

function Config.egg(id: string)
	for _, e in Config.EGGS do
		if e.id == id then
			return e
		end
	end
	return nil
end

-- The odds for an egg with a hatch-luck multiplier: { { id, chance 0-1 } } in the egg's order.
function Config.eggOdds(egg, luck: number): { { any } }
	local total, rows = 0, {}
	for _, row in egg.pets do
		local p = Config.pet(row[1])
		local w = row[2] * (if p and Config.HATCH_LUCK_RARITIES[p.rarity] then luck else 1)
		total += w
		table.insert(rows, { row[1], w })
	end
	for _, r in rows do
		r[2] /= total
	end
	return rows
end

function Config.rollEgg(egg, luck: number, rng: Random): string
	local pick = rng:NextNumber()
	for _, r in Config.eggOdds(egg, luck) do
		pick -= r[2]
		if pick <= 0 then
			return r[1]
		end
	end
	return egg.pets[1][1]
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
	{ id = "RustyRider", name = "Rusty Rider", currency = "coins", price = 350, damage = 6, radius = 6, speed = 30, fuel = 60, color = Color3.fromRGB(200, 90, 50) },
	{ id = "TurboTractor", name = "Turbo Tractor", currency = "coins", price = 40000, damage = 120, radius = 9, speed = 38, fuel = 90, color = Color3.fromRGB(60, 170, 255) },
	-- (report #12) the zero-turn mows a wide swath: `swath` x its radius, centred `ahead` studs out on its deck, and its
	-- lawn stripe is `stripe` studs wide (client/MowFx)
	{ id = "GoldenZeroTurn", name = "Golden Zero-Turn", currency = "gems", price = 900, damage = 400, radius = 10, speed = 42, fuel = 120, color = Color3.fromRGB(255, 200, 40), swath = 1.3, ahead = 4, stripe = 14 },
	{ id = "MonsterMulcher", name = "Monster Mulcher", currency = "gems", price = 2500, damage = 3000, radius = 12, speed = 46, fuel = 150, color = Color3.fromRGB(150, 60, 220) },
	{ id = "TrialMower", name = "Trial Mower", currency = "trial", product = "TrialMower", damage = 800, radius = 11, speed = 44, fuel = 140, color = Color3.fromRGB(255, 80, 160) },
	{ id = "RocketMower", name = "Rocket Mower", currency = "robux", product = "RocketMower", damage = 2000, radius = 12, speed = 50, fuel = 200, color = Color3.fromRGB(255, 70, 40) },
}
Config.FUEL_PRICE_PER_ZONE = { 2, 4, 10, 30, 90, 250, 700, 2000 } -- coins per fuel point, by the run's current zone

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
-- The daily reward ladder (server/Daily): gems for day 1..7 of a streak, claimed once per day; then it starts
-- over at day 1 (the streak count keeps going). Missing a day resets to day 1.
Config.DAILY_STREAK = { 50, 75, 100, 150, 200, 300, 600 }
Config.DAILY_GEMS = Config.DAILY_STREAK[1]
Config.DAILY_COOLDOWN = 24 * 3600
-- On top of the ladder, a little free gems at the same stall every 6 hours (Chop A Forest's daily is 35 gems every
-- 6 hours): one more reason to drop in during the day. server/Daily.
Config.FREE_GEMS = { gems = 20, every = 6 * 3600 }
-- Offline earnings (server/Offline, owner 28 Oct): time away with a saved run pays coins into that run (per minute x the
-- run's area grass value) and a few gems, capped. Nothing under minAway seconds counts (teleports, quick rejoins).
Config.OFFLINE = { minAway = 600, maxHours = 8, coinsPerMin = 3, gemsPerHour = 2 }
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
	Gems150 = { id = 3720129180, robux = 49, gems = 150, name = "150 Gems" },
	Gems500 = { id = 3720129187, robux = 149, gems = 500, name = "500 Gems" },
	Gems1500 = { id = 3720129195, robux = 399, gems = 1500, name = "1,500 Gems" },
	Gems5000 = { id = 3720129202, robux = 999, gems = 5000, name = "5,000 Gems" },
	TrialMower = { id = 3720129209, robux = 25, mower = "TrialMower", name = "Trial Mower (this run)" },
	RocketMower = { id = 3720129219, robux = 499, mower = "RocketMower", name = "Rocket Mower" },
	-- every class can be bought for Robux, in stock or not (owner, 27 Oct: the pay-to-win path). The first five are a
	-- bit cheaper than Chop A Forest's, the top two a bit dearer. The ids of 0 still have to be made on the Creator
	-- Dashboard (until then the button says "Coming soon"); Lawn Legend (was 799) and Goat Man (was 1499) need their
	-- price changed there too, or Roblox charges the old price.
	ClassGardener = { id = 3722990329, robux = 39, class = "Gardener", name = "Gardener class" },
	ClassGroundskeeper = { id = 3722990484, robux = 65, class = "Groundskeeper", name = "Groundskeeper class" },
	ClassLawnBaron = { id = 3722990570, robux = 85, class = "LawnBaron", name = "Lawn Baron class" },
	ClassHedgeReaper = { id = 3722990740, robux = 129, class = "HedgeReaper", name = "Hedge Reaper class" },
	ClassMowerSpecialist = { id = 3722990933, robux = 219, class = "MowerSpecialist", name = "Mower Specialist class" },
	ClassGrassTitan = { id = 3722991031, robux = 349, class = "GrassTitan", name = "Grass Titan class" },
	ClassUltimateGardener = { id = 3722991075, robux = 549, class = "UltimateGardener", name = "Ultimate Gardener class" },
	ClassLawnLegend = { id = 3720129226, robux = 999, class = "LawnLegend", name = "Lawn Legend class" },
	ClassGoatMan = { id = 3720129235, robux = 1699, class = "GoatMan", name = "Goat Man class" },
	-- Class card deal: deal yourself new cards now (until the next restock). Random result, so the odds are
	-- shown on every card (Config.CLASS_CHANCE / CLASS_CHANCE_LUCKY).
	-- guns for the boss crate (yours in every fight)
	GunRifle = { id = 3720129252, robux = 64, gun = "Rifle", name = "AK-47" },
	GunMinigun = { id = 3720129260, robux = 320, gun = "Minigun", name = "Minigun" },
	-- Golden Egg (random result: odds shown on the egg card)
	GoldenEgg1 = { id = 3720129270, robux = 80, egg = "GoldenEgg", count = 1, paidRandom = true, name = "Golden Egg" },
	GoldenEgg3 = { id = 3720129278, robux = 224, egg = "GoldenEgg", count = 3, paidRandom = true, name = "3 Golden Eggs" },
	GoldenEgg10 = { id = 3720129285, robux = 680, egg = "GoldenEgg", count = 10, paidRandom = true, name = "10 Golden Eggs" },
	ClassRestock = { id = 3720129296, robux = 29, restock = "normal", paidRandom = true, name = "Restock" },
	ClassLuckyRestock = { id = 3720129304, robux = 99, restock = "lucky", paidRandom = true, name = "Lucky Restock" },
}
Config.PRODUCT_ORDER = { "Gems150", "Gems500", "Gems1500", "Gems5000", "TrialMower", "RocketMower", "ClassLawnLegend", "ClassGoatMan" }

-- Tool products, like Chop A Forest's item popup: ONE TIME = this run only, PERMANENT = every run you play.
-- { once, forever } in Robux. Each tool gets `once` / `forever` product keys (ToolOnce<Id> / ToolForever<Id>);
-- set their ids after creating the products on the Creator Dashboard (0 = "Coming soon").
Config.TOOL_ROBUX = {
	Scissors = { 16, 64 },
	Sickle = { 24, 99 },
	PushMower = { 40, 160 },
	WeedWhacker = { 60, 240 },
	MegaScythe = { 99, 399 },
	LaserMower = { 149, 599 },
}
-- Developer product ids (made on 19 Oct 2026, universe 10771817013): { once, forever }
Config.TOOL_PRODUCT_IDS = {
	Scissors = { 3720125625, 3720125637 },
	Sickle = { 3720125640, 3720125645 },
	PushMower = { 3720125653, 3720125660 },
	WeedWhacker = { 3720125666, 3720125672 },
	MegaScythe = { 3720125677, 3720125685 },
	LaserMower = { 3720125692, 3720125694 },
}
for _, t in Config.TOOLS do
	local r = Config.TOOL_ROBUX[t.id]
	if r then
		local ids = Config.TOOL_PRODUCT_IDS[t.id] or { 0, 0 }
		t.once = "ToolOnce" .. t.id
		t.forever = "ToolForever" .. t.id
		Config.PRODUCTS[t.once] = { id = ids[1], robux = r[1], tool = t.id, name = t.name .. " (this run)" }
		Config.PRODUCTS[t.forever] = { id = ids[2], robux = r[2], tool = t.id, forever = true, name = t.name .. " (forever)" }
	end
end

function Config.toolIndex(id: string): number?
	for i, t in Config.TOOLS do
		if t.id == id then
			return i
		end
	end
	return nil
end

-- Chop A Forest's passes, mowed: Infinite Backpack -> Bottomless Sack, 2X Logs -> 2X Clippings.
-- `tag` is the tilted corner ribbon on the shop card, `color` the card colour.
Config.PASSES = {
	BigBag = { id = 2039890718, robux = 149, name = "Bottomless Sack", desc = "Carry as many bundles as you like", tag = "BEST VALUE", color = Color3.fromRGB(150, 80, 230) },
	DoubleCoins = { id = 2039740721, robux = 299, name = "2x Coins", desc = "Every bundle sells for double", color = Color3.fromRGB(250, 190, 40) },
	DoubleClippings = { id = 2040790478, robux = 120, name = "2x Clippings", desc = "Every clump you cut drops two bundles", color = Color3.fromRGB(90, 200, 70) },
	DoubleGems = { id = 2041640383, robux = 399, name = "2x Gems", desc = "Double gems from everything", color = Color3.fromRGB(60, 160, 250) },
	VIP = { id = 2042072324, robux = 249, name = "VIP", desc = "+15% power, +15% sell, VIP tag", tag = "POPULAR", color = Color3.fromRGB(240, 90, 150) },
	HatchLuck = { id = 2036909108, robux = 149, name = "Hatch Luck", desc = "Epic+ critters 1.5x more likely from every egg", color = Color3.fromRGB(80, 200, 120) },
	SuperHatchLuck = { id = 2040568482, robux = 399, name = "Super Hatch Luck", desc = "Epic+ critters 2x more likely (stacks to 3x)", tag = "SUPER", color = Color3.fromRGB(255, 190, 40) },
}
Config.PASS_ORDER = { "BigBag", "DoubleCoins", "DoubleClippings", "DoubleGems", "VIP", "HatchLuck", "SuperHatchLuck" }

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
-- Sounds. LICENSED AUDIO ONLY: Roblox-owned assets or the engine's built-in rbxasset sounds.
-- id = "" means silent. gap = minimum seconds between plays, pitch = base playback speed.
-------------------------------------------------------------------------------------------------------------
Config.SOUNDS = {
	-- All Roblox-owned (creator "Roblox", user 1), checked on the Creator Store API on 18 Oct 2026.
	cut = { id = "rbxassetid://12222200", volume = 0.35, pitch = 1.1, gap = 0.06 }, -- swoosh.wav
	chip = { id = "rbxassetid://12222140", volume = 0.2, pitch = 1.2, gap = 0.08 }, -- snap.wav
	reveal = { id = "rbxassetid://17208327798", volume = 0.55 }, -- Roblox GUI - Aura
	sell = { id = "rbxassetid://127645268874265", volume = 0.5, gap = 0.2 }, -- CoinTransfer_01
	purchase = { id = "rbxassetid://17208380755", volume = 0.5 }, -- Roblox GUI - Purchase
	upgrade = { id = "rbxassetid://10066947742", volume = 0.45 }, -- RBLX UI Purchase (SFX)
	denied = { id = "rbxassetid://17208353912", volume = 0.4, gap = 0.6 }, -- Roblox GUI - Negative
	click = { id = "rbxassetid://102855535543930", volume = 1, gap = 0.04 }, -- Creamy Keyboard Sound Effect (Yangz's pick for every UI click; community upload, not Roblox-owned)
	whoosh = { id = "rbxassetid://15675024286", volume = 0.35, gap = 0.1 }, -- Roblox_UI_Whoosh_01
	warn = { id = "rbxassetid://15675028888", volume = 0.35 }, -- Roblox_UI_Whoosh_02
	slam = { id = "rbxassetid://12221984", volume = 0.6, pitch = 0.7 }, -- collide.wav
	hit = { id = "rbxassetid://12222046", volume = 0.35, gap = 0.08 }, -- hit.wav
	hurt = { id = "rbxasset://sounds/ouch.ogg", volume = 0.5 }, -- engine built-in
	-- Chopping feel (client/HitFx, Fx, LootFx). Pro Sound Effects library sounds (licensed to every Roblox
	-- experience, creator "ProSoundEffects"), checked loading in Studio on 21 Oct 2026, plus engine built-ins.
	punch = { id = "rbxassetid://9113535176", volume = 0.45, pitch = 1.35, gap = 0.05 }, -- Body Slam Low End Thump 1
	rustle = { id = "rbxassetid://9114515257", volume = 0.32, pitch = 1.15, gap = 0.05 }, -- Foliage Crunchy Rustle 1
	slice = { id = "rbxasset://sounds/swordslash.wav", volume = 0.22, pitch = 1.35, gap = 0.05 }, -- engine built-in
	swingHand = { id = "rbxassetid://9126047581", volume = 0.3, pitch = 1.1, gap = 0.05 }, -- Synth Air Whoosh Karate Swish 13
	swingBlade = { id = "rbxassetid://9126283592", volume = 0.3, pitch = 1.2, gap = 0.05 }, -- Wood Swish Ruler Whoosh 17
	fellCrunch = { id = "rbxassetid://9114518077", volume = 0.45, gap = 0.08 }, -- Foliage Movement 1 (bursting through hedge)
	fellLand = { id = "rbxassetid://9114515868", volume = 0.5, gap = 0.08 }, -- Foliage Drop 4 (branch drops to dirt)
	burst = { id = "rbxassetid://9116406610", volume = 0.3, pitch = 1.3, gap = 0.06 }, -- Magic Poofs Thumpy 1
	pickup = { id = "rbxassetid://9112751731", volume = 0.4, gap = 0.03 }, -- Bubble Bloop High Pitched Cute 6
	-- a rare grass reveal (client/Moments): a magic chime, pitched up for the rarer mutations
	rareChime = { id = "rbxassetid://9116394545", volume = 0.6, gap = 0.1 }, -- Magic Glows Soft Clusters Of Chiming Hits 1
	-- footsteps (client/Soundscape): the store's grass/dirt footsteps are all unlicensed uploads, so a step is a
	-- light foliage rustle (on grass) over a soft heel thud (the engine's landing sound, pitched up)
	stepGrass = { id = "rbxassetid://9114517148", volume = 0.14, pitch = 1.3, gap = 0.12 }, -- Foliage Drop 5
	stepThud = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.12, pitch = 1.35, gap = 0.12 }, -- engine built-in
	-- ambience loops (client/Soundscape), very quiet under the music
	ambBirds = { id = "rbxassetid://9112832297", volume = 0.22 }, -- Mountain Birds 2 (light, distant)
	ambWind = { id = "rbxassetid://9112777807", volume = 0.16 }, -- Farmland Presence 1 (wind through vines, insects)
	ambJungle = { id = "rbxassetid://9112805601", volume = 0.22 }, -- Jungle Birds Ambience 2 (loop)
	roar = { id = "rbxassetid://9120031442", volume = 0.45, pitch = 1.25 }, -- Thunder With Lion Roar (pitched up)
	victory = { id = "rbxassetid://12222253", volume = 0.6 }, -- victory.wav
	engine = { id = "", volume = 0.3 }, -- Roblox has no mower/engine loop; silent until a licensed one is found
	musicLobby = { id = "rbxassetid://15930255433", volume = 0.35 }, -- Roblox_RetroFluteMusic_01
	musicRun = { id = "rbxassetid://130053244401794", volume = 0.3 }, -- TutorialMusic_01
	-- the run's opening cutscene (client/Intro): Roblox's licensed music library (verified creator DistrokidOfficial)
	introMusic = { id = "rbxassetid://75981022182996", volume = 0.55 }, -- Epic Trailer Music with Powerful Drums
	-- boss fights (client/BossCine): Roblox's licensed music library (verified creator DistrokidOfficial); phase 2
	-- plays it 12% faster
	bossMusic = { id = "rbxassetid://132347366936691", volume = 0.45 }, -- Boss Fight!
	-- the CLASSES black hole (server/BlackHole, client/BlackHole): Pro Sound Effects library sounds (licensed to every
	-- Roblox experience, creator "ProSoundEffects", checked on the Creator Store on 26 Oct 2026)
	bhHum = { id = "rbxassetid://9125898973", volume = 0.45 }, -- Sci Fi Transformation Synth Tones Slow Swirling 1 (loop)
	bhPull = { id = "rbxassetid://9119468100", volume = 0.6, pitch = 0.8 }, -- Spirit Pass Bys Fast Whooshes 5
	bhWarp = { id = "rbxassetid://9125973433", volume = 0.45 }, -- Spaceship Blast High Pitch Energy Charge Up 2
	bhOut = { id = "rbxassetid://9114159659", volume = 0.55, pitch = 0.9 }, -- Doppler Whooshes Crackly Airy Bursts 2
	bhPop = { id = "rbxassetid://9116406610", volume = 0.45, pitch = 0.75 }, -- Magic Poofs Thumpy 1
}

-------------------------------------------------------------------------------------------------------------
-- The films (client/Intro, client/Ending; client/Film, FilmAudio, FilmVoice). Owner, 28 Oct: "make it feel like a
-- real movie with a story ... matching audio".
-------------------------------------------------------------------------------------------------------------
Config.FILM = {
	-- the Mayor's voice (owner, 28 Oct: the text-to-speech one was "very bland and AI rubbish"): he talks in a
	-- made-up mumble of licensed sounds, one per syllable (client/Babble): "bassoon", "kazoo", "tuba", "hum", or
	-- "none" (subtitles only, his jaw still moves). The DEV panel's MAYOR VOICE button plays them one after the
	-- other so the owner can pick by ear; until then he's silent (the council: a cheap voice is worse than none).
	babble = "none",
	-- Roblox's text-to-speech for the Mayor instead (made on each player's device; free). Off since 28 Oct (above).
	-- If it can't be made in time, a line plays without a voice.
	voice = false,
	voiceId = "1", -- British male
	voicePitch = -1.5, -- semitones
	voiceSpeed = 0.95,
	voiceVolume = 1.6,
	-- the glitch demon's one line in the ending (a retro voice, pitched right down, distorted). Off (owner, 28 Oct
	-- evening: "remove the voice from the monster"): its line is a subtitle over a growl.
	demonVoice = false,
	demonVoiceId = "9",
}

-- Film music and sound effects. Licensed only: APM Music ("APMOfficial"), Pro Sound Effects ("ProSoundEffects") and
-- DistroKid ("DistrokidOfficial") library audio, which Roblox licenses to every experience. Each was checked loading
-- in Studio on 28 Oct 2026 (len = its length in seconds).
Config.FILM_SOUNDS = {
	-- music
	storyMusic = { id = "rbxassetid://9046390239", volume = 0.5, len = 117.1 }, -- APM: Morning Skies
	lonelyMusic = { id = "rbxassetid://9046596064", volume = 0.45, len = 61.4 }, -- APM: Alone (a 60)
	darkMusic = { id = "rbxassetid://9044407196", volume = 0.5, len = 62.0 }, -- APM: Back to the Shadows 60A
	heroMusic = { id = "rbxassetid://75981022182996", volume = 0.55, len = 163.7 }, -- DistroKid: Epic Trailer Music with Powerful Drums
	calmMusic = { id = "rbxassetid://114683938950404", volume = 0.5, len = 95.4 }, -- DistroKid: Time Will Heal (Ambience)
	flightMusic = { id = "rbxassetid://1842932462", volume = 0.5, len = 212.0 }, -- APM: Sunrise (No Choir)
	partyMusic = { id = "rbxassetid://9043170481", volume = 0.5, len = 61.0 }, -- APM: Dancing for Joy 60 A
	dreadMusic = { id = "rbxassetid://9046506025", volume = 0.55, len = 110.5 }, -- APM: Imminent Closure (Underscore C)
	creditsMusic = { id = "rbxassetid://1835176977", volume = 0.5, len = 61.1 }, -- APM: Triumphant Return 60B
	heartbeat = { id = "rbxassetid://9043365842", volume = 0.5, len = 60.1 }, -- APM: Heartbeat 02 96BPM
	-- risers, swells and hits (APM)
	rise = { id = "rbxassetid://9045215347", volume = 0.5, len = 12.5 }, -- Rise Up Rise
	riseDark = { id = "rbxassetid://9046338207", volume = 0.55, len = 9.1 }, -- Smoldering Fate Rise
	suck = { id = "rbxassetid://1843028062", volume = 0.5, len = 13.3 }, -- Suck Out Rise
	swell = { id = "rbxassetid://9040281024", volume = 0.5, len = 5.7 }, -- Amplified Expanse
	demonSwell = { id = "rbxassetid://9039690720", volume = 0.6, len = 8.1 }, -- Tortured Underbelly Swell
	revStop = { id = "rbxassetid://9043343295", volume = 0.5, len = 4.1 }, -- Reverse Noise Hard End 09
	revBuild = { id = "rbxassetid://1837834264", volume = 0.5, len = 4.0 }, -- Reverse Hard Stop (build)
	drone = { id = "rbxassetid://1841164822", volume = 0.5, len = 10.0 }, -- Drama Drone Hits 15
	sting = { id = "rbxassetid://1843079916", volume = 0.5, len = 6.9 }, -- Deep Thought - Sting 01
	impact = { id = "rbxassetid://1843025542", volume = 0.7, len = 6.8 }, -- Deep Impact
	slam = { id = "rbxassetid://1843023670", volume = 0.6, len = 7.3 }, -- Rumble Slam
	boom = { id = "rbxassetid://1843024924", volume = 0.5, len = 6.8 }, -- Distant Explosion (fireworks, pitched up)
	bigHit = { id = "rbxassetid://1843054069", volume = 0.6, len = 7.9 }, -- Bing Bang Boom
	titleHit = { id = "rbxassetid://122370204111513", volume = 0.6, len = 4.4 }, -- Chasing Sunlight Hit4
	swipe = { id = "rbxassetid://1837834185", volume = 0.35, len = 4.0 }, -- swipe (whip pans)
	swipe2 = { id = "rbxassetid://1837834151", volume = 0.35, len = 4.1 },
	-- Pro Sound Effects
	crowd = { id = "rbxassetid://9119562636", volume = 0.35, len = 45.2 }, -- Stadium Crowd 2
	applause = { id = "rbxassetid://9113138035", volume = 0.45, len = 16.4 }, -- Applause Tight 4
	growl = { id = "rbxassetid://9125471073", volume = 0.7, len = 2.0 }, -- Creature Growls Lion Deep Guttural Rumbling
	growl2 = { id = "rbxassetid://9113971531", volume = 0.6, len = 1.7 }, -- Creature Growls Lion 4
	rumble = { id = "rbxassetid://9125876218", volume = 0.6, len = 6.5 }, -- Rock Scrape Deep Bouncy Drags Rumbling Clunks 4
	crate = { id = "rbxassetid://9120915583", volume = 0.7, len = 1.5 }, -- Wood Impacts 10
	crate2 = { id = "rbxassetid://9120915994", volume = 0.6, len = 1.1 }, -- Wood Impacts 16
	thud = { id = "rbxassetid://9120876932", volume = 0.5, len = 0.9 }, -- Wood Fall Wood Pallets Impacts On Dirt 2
	whomp = { id = "rbxassetid://9113042263", volume = 0.5, len = 0.8 }, -- Acoustic Whomps 9
	synthWhomp = { id = "rbxassetid://9119874551", volume = 0.5, len = 0.9 }, -- Synth Whomps 33
	mower = { id = "rbxassetid://9116245012", volume = 0.4, len = 91.6 }, -- Lawn Mower Motor 2
	leaves = { id = "rbxassetid://9116248055", volume = 0.5, len = 24.5 }, -- Leaf Movement 2
	brush = { id = "rbxassetid://9116143977", volume = 0.5, len = 2.0 }, -- Kelp Impact Big 26 ("machete on thick brush")
	eerie = { id = "rbxassetid://9112775414", volume = 0.45, len = 63.7 }, -- Eerie Ambience 2
	servo = { id = "rbxassetid://9119008083", volume = 0.35, len = 12.9 }, -- Servo Short Bursts (sliced into glitches)
}

-------------------------------------------------------------------------------------------------------------
-- UI icons: image asset ids (rbxassetid://...) of icons rendered in Blender (tools/blender) and uploaded.
-- "" = use the drawn stand-in from client/UI.luau.
-------------------------------------------------------------------------------------------------------------
Config.ICONS = {
	coin = "", gem = "", bundle = "", backpack = "", basket = "", upgrade = "", lock = "", clover = "", leaf = "",
	stats = "", hands = "", scissors = "", sickle = "", pushmower = "", whacker = "", scythe = "", lasermower = "",
}
for name, id in require(script.Parent.IconIds) :: { [string]: string } do
	Config.ICONS[name] = id
end
-- class card art (2D, Store Icons/classart.py, uploaded 21 Oct 2026): UI.icon("class_<ClassId>")
for id, asset in {
	WeedPuller = 101974844305588, Gardener = 98013595086200, Groundskeeper = 135381814163967, LawnBaron = 105748382657411,
	HedgeReaper = 114080642070778, MowerSpecialist = 137232098698423, GrassTitan = 82171403768236,
	UltimateGardener = 78945880148946, LawnLegend = 84940076053307, GoatMan = 83112863068435,
} do
	Config.ICONS["class_" .. id] = "rbxassetid://" .. asset
end
-- full-bleed class card pictures (Store Icons/classscene.py, 600 x 400): Config.ICONS.scene_<ClassId>
for id, asset in {
	WeedPuller = 85809588456813, Gardener = 94384876404199, Groundskeeper = 117161180323886, LawnBaron = 80765545126396,
	HedgeReaper = 72516398737049, MowerSpecialist = 133502277849177, GrassTitan = 105467094992747,
	UltimateGardener = 92680252173020, LawnLegend = 102045731512051, GoatMan = 77353215008538,
} do
	Config.ICONS["scene_" .. id] = "rbxassetid://" .. asset
end
-- menu tab and side HUD pictures (Store Icons/uiicons.py); a newer upload of the same name in IconIds wins
for name, id in {
	paw = "rbxassetid://111248410488377",
	egg = "rbxassetid://133516698228335",
	book = "rbxassetid://82956166303568",
	clipboard = "rbxassetid://119603392279586",
	newspaper = "rbxassetid://74489703623422",
} do
	if (Config.ICONS[name] or "") == "" then
		Config.ICONS[name] = id
	end
end

-------------------------------------------------------------------------------------------------------------
-- Look (bubbly UI on Chop A Forest style wooden boards)
-------------------------------------------------------------------------------------------------------------
-- How big the whole interface is drawn: 1 = the 1280x720 layout fills the screen. The owner found that too big
-- (22 Oct), so it is drawn a bit smaller; raise it towards 1 for bigger, lower it for smaller. 0.82 until 27 Oct,
-- then smaller again (the owner: "it's taking a lot of screen space"); 0.7 was a bit too small, so 0.76.
Config.UI_SIZE = 0.76
-- Phones and tablets (touch, no keyboard) keep the full size: their screens are small already, and 0.82 made the
-- text too small to read there.
Config.UI_SIZE_TOUCH = 1
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

-------------------------------------------------------------------------------------------------------------
-- News (the NEWS window): newest last. `id` counts up; a player who hasn't seen the newest id gets the window
-- once in the lobby. `time` is a UTC unix time, `icon` a UI icon key.
-------------------------------------------------------------------------------------------------------------
Config.NEWS = {
	{
		id = 1,
		title = "Mow And Grow",
		update = "LAUNCH",
		time = 1792324800, -- 18 Oct 2026
		icon = "clover",
		desc = "The lawn has gone wild. Grab your hands and start mowing!",
		bullets = {
			"Cut grass, carry the bundles and shred them for coins",
			"Tools from Bare Hands to the Laser Mower",
			"Ride-on mowers, bags, the Leaf Vacuum and upgrades",
			"Hidden mutations: Golden, Rainbow, Diamond, Toxic and Galaxy",
			"Classes and gem perks that you keep forever",
		},
	},
	{
		id = 2,
		title = "The Big Rebuild",
		update = "UPDATE 1",
		time = 1792504800, -- 20 Oct 2026
		icon = "star",
		desc = "A whole new map, tree-sized grass and a brand new lobby.",
		bullets = {
			"8 fenced areas that open one after another",
			"Grass clumps stand like trees: aim, cut, watch them fall",
			"Bundles land where a clump falls",
			"New Hold upgrade: keep the button down to keep cutting",
			"A second shredder in the middle of the map",
			"New lobby: glowing party pads and a big START A RUN board",
			"New menus, stats and this news board",
		},
	},
}

-- The next event, on the lobby's notice board (server/LobbyKit.eventBoard); the countdown runs to startsAt (UTC).
Config.EVENT = { title = "HALLOWEEN", name = "???", startsAt = 1792857600, dateText = "OCT 24" } -- 24 Oct 2026 16:00 UTC

-- In the generated world the areas go by its names (shared/Zones: Sunny Meadow, Golden Wheat Hills...), so the
-- HUD, the gates' signs and the quests all say the same thing.
if Config.WORLD_GEN then
	local Zones = require(script.Parent.Zones)
	local renames: { [string]: string } = {}
	for z, def in Config.ZONES do
		local g = Zones.list[z]
		if g then
			renames[def.name] = g.name
			def.name = g.name
			def.grassName = g.grassName or def.grassName
		end
	end
	for _, q in Config.QUESTS do
		for old, new in renames do
			q.title = string.gsub(q.title, old, new)
			if q.hint then
				q.hint = string.gsub(q.hint, old, new)
			end
		end
		if q.hint then
			q.hint = string.gsub(q.hint, "cleared the lawn", "cleared the first area")
		end
	end
end

return Config
