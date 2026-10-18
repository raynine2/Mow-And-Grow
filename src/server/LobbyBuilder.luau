-- Builds the lobby like Chop A Forest's: a dirt clearing in a thick forest, a big START A RUN board behind four
-- party booths, a leaderboard, the rewards stall, the classes cabin (class stock board inside) and the garage.
-- Uses the Blender models (server/Models) and falls back to brick versions when a model isn't uploaded.
-- Returns the handles the Lobby system needs (pads, stock board, leaderboard).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local Environment = require(script.Parent.Environment)

local LobbyBuilder = {}

local DIRT = Color3.fromRGB(166, 124, 82)
local CREAM = Color3.fromRGB(255, 240, 200)
local GOLD = Color3.fromRGB(255, 214, 60)
local CYAN = Color3.fromRGB(40, 230, 255)
local FLOOR_Y = 0.3 -- top of the dirt
local EDGE = 66 -- the fence around the clearing

local function ground(world: Instance)
	PropKit.brick(world, Vector3.new(420, 2, 420), CFrame.new(0, -1, 0), PropKit.GRASS_GREEN, "Grass", Enum.Material.Grass)
	PropKit.brick(world, Vector3.new(EDGE * 2 + 4, FLOOR_Y, EDGE * 2 + 4), CFrame.new(0, FLOOR_Y / 2, 0), DIRT, "Dirt", Enum.Material.Ground)
	-- keep players in
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local pos = Vector3.new(side[1] * 100, 20, side[2] * 100)
		local wallSize = if side[1] ~= 0 then Vector3.new(2, 40, 200) else Vector3.new(200, 40, 2)
		PropKit.wall(world, wallSize, CFrame.new(pos))
	end
end

-- A glowing outline on the ground (a rectangle w x d around `centre`, in the model's own studs).
local function outline(parent: Instance, at: CFrame, centre: Vector3, w: number, d: number, color: Color3)
	for _, e in { { 0, d / 2, w, 0.4 }, { 0, -d / 2, w, 0.4 }, { w / 2, 0, 0.4, d }, { -w / 2, 0, 0.4, d } } do
		local p = PropKit.brick(parent, Vector3.new(e[3], 0.12, e[4]), at * CFrame.new(centre + Vector3.new(e[1], 0.06, e[2])), color, "Outline", Enum.Material.Neon)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
end

-- An invisible part to hang a prompt on.
local function promptSpot(parent: Instance, cf: CFrame, name: string): Part
	local p = PropKit.part({ size = Vector3.new(2, 2, 2), cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = name })
	p.CanQuery = false
	return p
end

local function scatter(world: Instance)
	-- stumps, logs, rocks and bushes along the fence, kept clear of the buildings
	local bits = PropKit.folder("Props", world)
	local rng = Random.new(21)
	local kinds = { "stump", "log", "rock", "bush", "bush", "rock", "log" }
	for i = 1, 34 do
		local side = i % 4
		local t = rng:NextNumber(-60, 60)
		local inset = rng:NextNumber(3, 6)
		local pos
		if side == 0 then
			pos = Vector3.new(if math.abs(t) < 28 then t + 50 * math.sign(t + 0.01) else t, FLOOR_Y, EDGE - inset)
		elseif side == 1 then
			pos = Vector3.new(t, FLOOR_Y, -EDGE + inset)
		else
			local z = if t > -2 and t < 40 then -50 - (t % 10) else t
			pos = Vector3.new(if side == 2 then EDGE - inset else -EDGE + inset, FLOOR_Y, z)
		end
		pos = Vector3.new(math.clamp(pos.X, -62, 62), FLOOR_Y, pos.Z)
		local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if not Models.place(kinds[rng:NextInteger(1, #kinds)], bits, cf, rng:NextNumber(0.8, 1.2)) then
			PropKit.bush(bits, pos, 0.8)
		end
	end
end

local function decor(world: Instance)
	-- the clearing sits in a thick forest, with mountains far behind
	local trees = PropKit.folder("Trees", world)
	local rng = Random.new(7)
	PropKit.forest(trees, -190, 190, EDGE + 10, 190, { seed = 11, detailRadius = 120 })
	PropKit.forest(trees, -190, 190, -190, -EDGE - 10, { seed = 12, detailRadius = 120 })
	PropKit.forest(trees, EDGE + 10, 190, -EDGE - 4, EDGE + 4, { seed = 13, detailRadius = 120 })
	PropKit.forest(trees, -190, -EDGE - 10, -EDGE - 4, EDGE + 4, { seed = 14, detailRadius = 120 })
	for i = 0, 7 do
		local t = i / 8 * math.pi * 2 + 0.3
		PropKit.mountain(world, Vector3.new(math.cos(t) * 330, -2, math.sin(t) * 330), rng:NextNumber(1.6, 2.4))
	end
	-- wooden fence all around the clearing, facing in
	local fence = PropKit.folder("Fence", world)
	local e = EDGE
	PropKit.fenceRow(fence, Vector3.new(-e, FLOOR_Y, e), Vector3.new(e, FLOOR_Y, e), -Vector3.zAxis)
	PropKit.fenceRow(fence, Vector3.new(-e, FLOOR_Y, -e), Vector3.new(e, FLOOR_Y, -e), Vector3.zAxis)
	PropKit.fenceRow(fence, Vector3.new(e, FLOOR_Y, -e), Vector3.new(e, FLOOR_Y, e), -Vector3.xAxis)
	PropKit.fenceRow(fence, Vector3.new(-e, FLOOR_Y, -e), Vector3.new(-e, FLOOR_Y, e), Vector3.xAxis)
	-- lanterns along the walk from the spawn to the booths
	local lamps = PropKit.folder("Lanterns", world)
	for _, z in { -34, -14, 6, 24 } do
		for _, x in { -13, 13 } do
			local pos = Vector3.new(x, FLOOR_Y, z)
			if not Models.place("lantern_post", lamps, CFrame.lookAt(pos, Vector3.new(0, FLOOR_Y, z)), 1, true) then
				PropKit.brick(lamps, Vector3.new(0.8, 6, 0.8), CFrame.new(pos + Vector3.new(0, 3, 0)), PropKit.TRUNK, "LanternPost", Enum.Material.Wood)
			end
		end
	end
	scatter(world)
end

-------------------------------------------------------------------------------------------------------------
-- log cabins (classes shop and garage)
-------------------------------------------------------------------------------------------------------------
local cabin = PropKit.cabin
local cabinSign = PropKit.cabinSign

-- The class booth: a cabin with the stock board on its back wall. The Lobby system updates the board.
local function oldClassBooth(world: Instance): TextLabel
	local m = PropKit.stall(world, CFrame.new(-55, 0, -5) * CFrame.Angles(0, math.rad(-90), 0), "CLASSES", Color3.fromRGB(160, 95, 255), "Classes")
	local board = PropKit.part({ size = Vector3.new(16, 9, 1), cf = CFrame.new(-62, 9, -5) * CFrame.Angles(0, math.rad(-90), 0), color = Color3.fromRGB(60, 40, 110), parent = m, name = "StockBoard" })
	local label = PropKit.surfaceText(board, "Classes in stock", Color3.new(1, 1, 1))
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function classCabin(world: Instance): TextLabel
	local m = PropKit.folder("Classes", world)
	local pos = Vector3.new(-46, FLOOR_Y, -22)
	local at = CFrame.lookAt(pos, pos + Vector3.xAxis)
	local purple = Color3.fromRGB(180, 100, 255)
	if not cabin(m, at, 1) then
		return oldClassBooth(world)
	end
	cabinSign(m, at, 1, "CLASSES", purple)
	outline(m, at, Vector3.new(0, 0, -16), 16, 6, purple)
	local board = PropKit.part({ size = Vector3.new(14, 6.4, 0.3), cf = at * CFrame.new(0, 5.8, 9.3), color = Color3.fromRGB(44, 30, 60), parent = m, name = "StockBoard" })
	local label = PropKit.surfaceText(board, "Classes in stock", Color3.new(1, 1, 1))
	label.TextYAlignment = Enum.TextYAlignment.Top
	PropKit.prompt(promptSpot(m, at * CFrame.new(0, 3, 5), "ClassCounter"), "Browse", "Classes", "Classes", 12)
	PropKit.prompt(promptSpot(m, at * CFrame.new(0, 3, -9), "ClassPorch"), "Browse", "Classes", "Classes", 10)
	return label
end

local function oldGarage(world: Instance)
	local cf = CFrame.new(55, 0, 25) * CFrame.Angles(0, math.rad(90), 0)
	local m = Instance.new("Model")
	m.Name = "Garage"
	local wall = Color3.fromRGB(80, 160, 255)
	PropKit.brick(m, Vector3.new(18, 10, 1), cf * CFrame.new(0, 5, 6), wall, "Back")
	PropKit.brick(m, Vector3.new(1, 10, 12), cf * CFrame.new(-8.5, 5, 0), wall, "Side")
	PropKit.brick(m, Vector3.new(1, 10, 12), cf * CFrame.new(8.5, 5, 0), wall, "Side")
	PropKit.brick(m, Vector3.new(19, 1.2, 13), cf * CFrame.new(0, 10.6, 0), PropKit.shade(wall, 0.8), "Roof")
	PropKit.sign(m, cf * CFrame.new(0, 13, -6), Vector3.new(14, 3, 0.8), "GARAGE", Color3.fromRGB(255, 140, 40)).Name = "GarageSign"
	local floor = PropKit.cylinder(m, 5, 0.6, cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(230, 230, 240))
	PropKit.brick(m, Vector3.new(5, 2.4, 7), cf * CFrame.new(0, 2, 0), Color3.fromRGB(255, 200, 40), "DisplayMower")
	PropKit.prompt(floor, "Open", "Garage", "Garage")
	m.Parent = world
end

-- The garage: a smaller cabin with a mower on a turntable in front of the porch.
local function garageCabin(world: Instance)
	local m = PropKit.folder("Garage", world)
	local pos = Vector3.new(46, FLOOR_Y, -22)
	local at = CFrame.lookAt(pos, pos - Vector3.xAxis)
	local s = 0.85
	if not cabin(m, at, s) then
		oldGarage(world)
		return
	end
	cabinSign(m, at, s, "GARAGE", Color3.fromRGB(255, 150, 50))
	local spot = at * CFrame.new(0, 0, -18 * s)
	local floor = PropKit.cylinder(m, 5, 0.6, spot * CFrame.new(0, 0.3, 0), Color3.fromRGB(70, 70, 78))
	floor.Name = "Turntable"
	floor.Material = Enum.Material.DiamondPlate
	outline(m, spot, Vector3.zero, 12, 12, Color3.fromRGB(255, 150, 50))
	if not Models.place("mower_tractor", m, spot * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(200), 0), 1, true) then
		PropKit.brick(m, Vector3.new(5, 2.4, 7), spot * CFrame.new(0, 1.8, 0), Color3.fromRGB(255, 200, 40), "DisplayMower")
	end
	PropKit.prompt(floor, "Open", "Garage", "Garage", 14)
end

-------------------------------------------------------------------------------------------------------------
-- rewards, leaderboard, party booths
-------------------------------------------------------------------------------------------------------------
local function oldRewardsChest(world: Instance)
	local m = Instance.new("Model")
	m.Name = "FreeRewards"
	local cf = CFrame.new(55, 0, -5) * CFrame.Angles(0, math.rad(90), 0)
	local gold = Color3.fromRGB(255, 205, 50)
	local base = PropKit.brick(m, Vector3.new(10, 5, 7), cf * CFrame.new(0, 2.5, 0), gold, "ChestBase")
	PropKit.brick(m, Vector3.new(10.4, 3, 7.4), cf * CFrame.new(0, 6.5, 0), PropKit.shade(gold, 1.05), "ChestLid")
	PropKit.billboard(base, "FREE REWARDS", GOLD, Vector2.new(14, 3), Vector3.new(0, 8, 0))
	PropKit.prompt(base, "Open", "Free Rewards", "Rewards")
	m.Parent = world
end

local function rewardsStall(world: Instance)
	local m = PropKit.folder("FreeRewards", world)
	local pos = Vector3.new(-50, FLOOR_Y, 26)
	local at = CFrame.lookAt(pos, Vector3.new(0, FLOOR_Y, 16))
	if not Models.place("rewards_stall", m, at, 1, true) then
		oldRewardsChest(world)
		return
	end
	PropKit.facePanel(m, at, Vector3.new(0, 13.5, -0.6), Vector2.new(16, 3), "REWARDS", Color3.fromRGB(255, 170, 50))
	-- seen from the front the daily bay is on the left (+X), the group bay on the right
	local daily = ("DAILY REWARD\n+%d Gems\nEvery %d hours"):format(Config.DAILY_GEMS, Config.DAILY_COOLDOWN // 3600)
	PropKit.facePanel(m, at, Vector3.new(3.9, 6.6, 2.3), Vector2.new(6, 3.4), daily, Color3.new(1, 1, 1))
	PropKit.facePanel(m, at, Vector3.new(-3.9, 6.6, 2.3), Vector2.new(6, 3.4), ("GROUP REWARD\n+%d Gems\nJoin the group!"):format(Config.GROUP_GEMS), Color3.new(1, 1, 1))
	outline(m, at, Vector3.new(3.9, 0, -5), 7, 6, CYAN)
	outline(m, at, Vector3.new(-3.9, 0, -5), 7, 6, CYAN)
	PropKit.collider(m, at, Vector3.new(0, 4.5, 2.65), Vector3.new(17, 9, 0.8))
	for _, x in { -7.9, 7.9 } do
		PropKit.collider(m, at, Vector3.new(x, 6, 0.5), Vector3.new(1.2, 12, 5.4))
	end
	for _, x in { -3.3, 3.3 } do
		PropKit.collider(m, at, Vector3.new(x, 1.9, -3.1), Vector3.new(4.2, 3.8, 2.6))
	end
	PropKit.prompt(promptSpot(m, at * CFrame.new(0, 3, -5), "RewardsPrompt"), "Open", "Free Rewards", "Rewards", 14)
end

-- The leaderboard's text label (the Lobby system fills it with this server's top mowers).
local function leaderboard(world: Instance): TextLabel
	local m = PropKit.folder("Leaderboard", world)
	local pos = Vector3.new(50, FLOOR_Y, 30)
	local at = CFrame.lookAt(pos, Vector3.new(0, FLOOR_Y, -10))
	local s = 1.25
	local body: TextLabel
	if Models.place("leaderboard", m, at, s, true) then
		PropKit.facePanel(m, at, Vector3.new(0, 10.65, -0.39), Vector2.new(10, 1.3), "TOP MOWERS", GOLD, s)
		body = PropKit.facePanel(m, at, Vector3.new(0, 6.6, -0.34), Vector2.new(9.6, 6.2), "", Color3.new(1, 1, 1), s)
		PropKit.collider(m, at, Vector3.new(0, 7, 0), Vector3.new(13, 14, 1.6), s)
	else
		local board = PropKit.part({ size = Vector3.new(12, 10, 1), cf = at * CFrame.new(0, 8, 0), color = Color3.fromRGB(44, 34, 30), parent = m, name = "LeaderBoard" })
		body = PropKit.surfaceText(board, "", Color3.new(1, 1, 1))
	end
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	return body
end

local PAD_COLORS = { Color3.fromRGB(80, 200, 80), Color3.fromRGB(60, 165, 255), Color3.fromRGB(160, 95, 255), Color3.fromRGB(255, 110, 190) }

local function startBoard(m: Instance)
	-- the board stands high on two tall log legs so it shows over the booths' roofs
	local lift = 9
	local at = CFrame.lookAt(Vector3.new(0, FLOOR_Y + lift, 58), Vector3.new(0, FLOOR_Y + lift, 0))
	local s = 1.6
	if Models.place("start_sign", m, at, s, true) then
		for _, x in { -12.5, 12.5 } do
			local leg = PropKit.cylinder(m, 0.95 * s, lift + 1, at * CFrame.new(x * s, -lift / 2 + 0.5, 0.7 * s), Color3.fromRGB(110, 70, 42))
			leg.Material = Enum.Material.Wood
			leg.Name = "SignLeg"
		end
		PropKit.facePanel(m, at, Vector3.new(0, 9.3, -0.62), Vector2.new(27, 4), "START A RUN", GOLD, s)
		local sub = ("Step on a pad - play solo or bring up to %d friends"):format(Config.PARTY_MAX - 1)
		PropKit.facePanel(m, at, Vector3.new(0, 6.1, -0.62), Vector2.new(27, 1.5), sub, CREAM, s)
		PropKit.collider(m, at, Vector3.new(0, 6, 0.6), Vector3.new(30, 12, 2.4), s)
	else
		PropKit.sign(m, CFrame.new(0, 14, 58), Vector3.new(30, 5, 1.5), "START A RUN", Color3.fromRGB(80, 200, 80), Color3.new(1, 1, 1))
	end
end

local function partyArea(world: Instance)
	local m = PropKit.folder("PartyBooths", world)
	startBoard(m)
	local pads = {}
	for i = 1, 4 do
		local kind = if i == 1 then "solo" else "party"
		local title = if i == 1 then "SOLO" else "PARTY"
		local pos = Vector3.new(-27 + (i - 1) * 18, FLOOR_Y, 38)
		local at = CFrame.lookAt(pos, pos - Vector3.zAxis)
		local high = 6
		if Models.place("party_booth", m, at, 1, true) then
			PropKit.facePanel(m, at, Vector3.new(0, 7, 5.93), Vector2.new(10.4, 4), "THE LAWN\n" .. title, CREAM)
			for _, x in { -7.2, 7.2 } do
				PropKit.collider(m, at, Vector3.new(x, 5, 6.6), Vector3.new(1.4, 10, 1.4)) -- back posts
				PropKit.collider(m, at, Vector3.new(x, 1.2, 0), Vector3.new(0.8, 2.4, 14)) -- side rails
			end
			PropKit.collider(m, at, Vector3.new(0, 1.2, 7), Vector3.new(14, 2.4, 0.8)) -- back rail
			high = 14.5
		else
			PropKit.pad(m, pos, 7, PAD_COLORS[i])
		end
		local holder = PropKit.part({ size = Vector3.new(1, 1, 1), cf = CFrame.new(pos + Vector3.new(0, 1, 0)), color = PAD_COLORS[i], parent = m, transparency = 1, collide = false, name = "PadInfo" .. i })
		holder.CanQuery = false
		local label = PropKit.billboard(holder, title, Color3.new(1, 1, 1), Vector2.new(12, 3.5), Vector3.new(0, high, 0), 150)
		table.insert(pads, { kind = kind, pos = pos, radius = 6, label = label, title = title })
	end
	return pads
end

function LobbyBuilder.build()
	local world = Environment.apply()
	ground(world)
	decor(world)
	Environment.spawn(world, CFrame.lookAt(Vector3.new(0, 0.8, -46), Vector3.new(0, 0.8, 0)))
	local stockLabel = classCabin(world)
	garageCabin(world)
	rewardsStall(world)
	local leaderLabel = leaderboard(world)
	local pads = partyArea(world)
	return { world = world, stockLabel = stockLabel, leaderLabel = leaderLabel, pads = pads }
end

return LobbyBuilder
