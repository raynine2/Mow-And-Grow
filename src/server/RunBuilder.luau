-- Builds a run's map: ONE continuous world like Chop A Forest's (see Config.MAP), a 3 x 3 grid of fenced plots.
-- The hub (shredder, tool shop, bag stand, garage, gas pump) is the middle plot of the south row; the eight areas
-- fill the rest, each with its own ground and props, and every fence two plots share has a gate in the middle.
-- A second shredder (the drop-off) stands in the middle of the first area. A forest belt and a ring of snowy
-- mountains close the world off.
-- Grass patches are spawned by Field (positions from RunBuilder.patches); this file builds the static world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local Environment = require(script.Parent.Environment)
local Ground = require(script.Parent.Ground)

local RunBuilder = {}

local FLOOR_Y = 0 -- top of the ground (Terrain)

-- An invisible part to hang a prompt on.
local function promptSpot(parent: Instance, cf: CFrame, name: string): Part
	local p = PropKit.part({ size = Vector3.new(2, 2, 2), cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = name })
	p.CanQuery = false
	return p
end

-------------------------------------------------------------------------------------------------------------
-- tool shop: a log cabin with every tool in a frame on its walls (like Chop A Forest's axe wall)
-------------------------------------------------------------------------------------------------------------
local TOOL_MODEL = {
	Scissors = "tool_scissors",
	Sickle = "tool_sickle",
	PushMower = "tool_pushmower",
	WeedWhacker = "tool_whacker",
	MegaScythe = "tool_scythe",
	LaserMower = "tool_lasermower",
}
-- where each frame hangs in the cabin's room (cabin studs): four on the back wall, one on each side wall
local FRAME_SPOTS = {
	{ Vector3.new(9, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(3, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(-3, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(-9, 1.7, 9.33), 0, 0.85 },
	{ Vector3.new(11.77, 1.7, 7.3), 90, 0.66 },
	{ Vector3.new(-11.77, 1.7, 7.3), -90, 0.66 },
}
-- hand tools hang across the pegs: their length (model Z) along the board, flat side out
local HANG = CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90))

local function toolFrame(parent: Instance, cabinAt: CFrame, tool, spot)
	local s = spot[3]
	local cf = cabinAt * CFrame.new(spot[1]) * CFrame.Angles(0, math.rad(spot[2]), 0)
	if not Models.place("tool_wall_frame", parent, cf, s, true) then
		PropKit.brick(parent, Vector3.new(6, 5, 0.3) * s, cf * CFrame.new(Vector3.new(0, 3.6, 0) * s), Color3.fromRGB(232, 176, 112), "ToolBoard", Enum.Material.WoodPlanks)
		PropKit.brick(parent, Vector3.new(5.4, 1.6, 0.4) * s, cf * CFrame.new(Vector3.new(0, 0.8, -0.3) * s), Color3.fromRGB(62, 42, 30), "PriceBoard", Enum.Material.Wood)
	end
	PropKit.facePanel(parent, cf, Vector3.new(0, 0.82, -0.57), Vector2.new(5.4, 1.5), "$" .. Format.commas(tool.cost), Color3.fromRGB(120, 255, 90), s)
	local onFloor = tool.id == "PushMower" or tool.id == "LaserMower"
	local name = TOOL_MODEL[tool.id]
	if onFloor then
		-- mowers stand on the cabin floor in front of their frame
		Models.place(name, parent, cf * CFrame.new(0, -1.2, -3.6 * s), 0.85, true)
	else
		local target = cf * CFrame.new(Vector3.new(0, 3.9, -0.85) * s)
		local m = Models.place(name, parent, target * HANG, 1, true)
		if m then
			local _, size = m:GetBoundingBox()
			local fit = 4.2 * s / math.max(size.X, size.Y, size.Z)
			if fit < 1 then
				m:ScaleTo(fit)
			end
			local box = m:GetBoundingBox()
			m:PivotTo(m:GetPivot() + (target.Position - box.Position))
		end
	end
	local prompt = PropKit.prompt(promptSpot(parent, cf * CFrame.new(0, 3.5 * s, -1.5), "ToolFrame"), "View", tool.name, "ToolView", 7)
	prompt:SetAttribute("Item", tool.id)
end

local function toolShop(m: Instance, info)
	local shop = PropKit.folder("TOOL SHOP", m)
	local pos = Vector3.new(24, FLOOR_Y, -40)
	local at = CFrame.lookAt(pos, pos - Vector3.xAxis)
	if not PropKit.cabin(shop, at, 1) then
		PropKit.stall(m, CFrame.new(28, 0, -55) * CFrame.Angles(0, math.rad(90), 0), "TOOL SHOP", Color3.fromRGB(255, 80, 80), "Tools")
		return
	end
	PropKit.cabinSign(shop, at, 1, "TOOL SHOP", Color3.fromRGB(255, 120, 70))
	for i = 2, #Config.TOOLS do
		local spot = FRAME_SPOTS[i - 1]
		if spot then
			toolFrame(shop, at, Config.TOOLS[i], spot)
		end
	end
	-- the Guide arrow points just outside the door ("Counter" looks out of the door)
	promptSpot(shop, at * CFrame.new(0, 2, -6), "Counter")
	-- a lantern at the door
	Models.place("lantern_post", shop, at * CFrame.new(5, 0.5, -10.6), 0.8, true)
end

-- The Bag Stand (bag_stand model): a striped market stall by the spawn. The three bag tiers stand on its stumps,
-- the Bottomless Sack sits on the counter and the Leaf Vacuum leans beside it. Its prompt opens the Bags window.
local function bagStand(m: Instance)
	local stand = PropKit.folder("BAG STAND", m)
	local pos = Vector3.new(28, FLOOR_Y, -68)
	local at = CFrame.lookAt(pos, pos - Vector3.xAxis) -- facing the path from the spawn
	if not Models.place("bag_stand", stand, at, 1, true) then
		PropKit.stall(stand, at, "BAGS", Color3.fromRGB(90, 190, 90), "Bags")
		return
	end
	PropKit.facePanel(stand, at, Vector3.new(0, 10.6, 0.9), Vector2.new(9.4, 2.2), "BAGS & GEAR", Color3.fromRGB(255, 240, 200))
	PropKit.collider(stand, at, Vector3.new(0, 3.7, 0.7), Vector3.new(14, 7.4, 3))
	-- the bags on their stumps (model studs: stump tops at y 2, z -4.5), each with its price in front
	for i, bag in Config.BAGS do
		local x = ({ -5, 0, 5 })[i]
		if x then
			PropKit.collider(stand, at, Vector3.new(x, 1, -4.5), Vector3.new(2.7, 2, 2.7))
			Models.place(bag.model, stand, at * CFrame.new(x, 2, -4.5), 1.1, true)
			PropKit.facePanel(stand, at, Vector3.new(x, 1, -5.85), Vector2.new(2.6, 0.9), "$" .. Format.short(bag.cost), Color3.fromRGB(120, 255, 90))
		end
	end
	Models.place("bag_infinite", stand, at * CFrame.new(0, 3.53, -0.6), 0.75, true)
	Models.place("tool_vacuum", stand, at * CFrame.new(-8.6, 2.65, -1), 0.8, true)
	PropKit.prompt(promptSpot(stand, at * CFrame.new(0, 3, -7.5), "BagCounter"), "Shop", "Bags & Gear", "Bags", 12)
end

-- Gas pump: prompt refuels your mower if it's parked nearby. `facing` is where its front looks.
local function gasPump(parent: Instance, pos: Vector3, info, facing: Vector3?)
	local cf = CFrame.lookAt(pos, pos + (facing or -Vector3.zAxis))
	local body: BasePart
	if Models.place("gas_pump", parent, cf, 1.1, true) then
		body = PropKit.collider(parent, cf, Vector3.new(0, 3, 0), Vector3.new(3.2, 6.2, 2.8), 1.1)
		body.Name = "GasPump"
	else
		local red = Color3.fromRGB(240, 60, 60)
		body = PropKit.brick(parent, Vector3.new(3, 6, 2.4), cf * CFrame.new(0, 3, 0), red, "GasPump")
		PropKit.brick(parent, Vector3.new(3.4, 1, 2.8), cf * CFrame.new(0, 6.5, 0), Color3.fromRGB(255, 255, 255), "PumpTop")
		PropKit.brick(parent, Vector3.new(2, 1.4, 0.4), cf * CFrame.new(0, 4.6, -1.3), Color3.fromRGB(40, 40, 50), "PumpScreen")
	end
	PropKit.billboard(body, "GAS", Color3.fromRGB(255, 230, 80), Vector2.new(5, 2), Vector3.new(0, 5, 0), 120)
	local prompt = PropKit.prompt(body, "Refuel", "Gas Pump", nil, 14)
	prompt:SetAttribute("Pump", true)
	table.insert(info.pumps, { pos = pos, prompt = prompt })
end

-- The garage: an open wooden bay (party booth model) where your mower spawns, with a gas pump beside it.
local function garageBay(m: Instance, info)
	local pos = Vector3.new(-30, FLOOR_Y, -64)
	local at = CFrame.lookAt(pos, pos + Vector3.xAxis)
	local g = PropKit.folder("Garage", m)
	if Models.place("party_booth", g, at, 1.1, true) then
		PropKit.facePanel(g, at, Vector3.new(0, 7, 5.93), Vector2.new(10.4, 4), "GARAGE", Color3.fromRGB(255, 150, 50), 1.1)
		for _, x in { -7.2, 7.2 } do
			PropKit.collider(g, at, Vector3.new(x, 5, 6.6), Vector3.new(1.4, 10, 1.4), 1.1)
			PropKit.collider(g, at, Vector3.new(x, 1.2, 0), Vector3.new(0.8, 2.4, 14), 1.1)
		end
		PropKit.collider(g, at, Vector3.new(0, 1.2, 7), Vector3.new(14, 2.4, 0.8), 1.1)
	else
		PropKit.stall(g, CFrame.new(-28, 0, -70) * CFrame.Angles(0, math.rad(-90), 0), "GARAGE", Color3.fromRGB(160, 95, 255), "Mowers")
		PropKit.pad(g, pos, 5, Color3.fromRGB(160, 95, 255), "MOWER SPAWN")
	end
	PropKit.prompt(promptSpot(g, at * CFrame.new(0, 3, -8.5), "GaragePrompt"), "Open", "Garage", "Mowers", 12)
	info.garageSpawn = at * CFrame.new(0, 2, 0)
	gasPump(g, (at * CFrame.new(10, 0, -6)).Position, info, Vector3.xAxis)
end

-------------------------------------------------------------------------------------------------------------
-- hub
-------------------------------------------------------------------------------------------------------------
-- A Giant Grass Shredder (Blender model) at `at` (drum toward at.LookVector) with its log-framed sell pad in
-- front of the hopper. Every shredder is a sell spot (info.sellPads); the first one is the hub's.
local function shredderAt(parent: Instance, info, at: CFrame, name: string): boolean
	local s = PropKit.folder(name, parent)
	if not Models.place("shredder", s, at, 1.15, true) then
		s:Destroy()
		return false
	end
	PropKit.collider(s, at, Vector3.new(0, 5, -0.7), Vector3.new(7.8, 10, 14.5), 1.15)
	local mouth = (at * CFrame.new(Vector3.new(0.3, 8.8, 4.8) * 1.15)).Position
	local out = (at * CFrame.new(Vector3.new(0, 1.2, -8.6) * 1.15)).Position
	local padAt = at * CFrame.new(0, 0, 16.5)
	local sellPos = padAt.Position
	if Models.place("sell_pad", s, padAt, 1, true) then
		PropKit.collider(s, padAt, Vector3.new(0, 0.41, 0), Vector3.new(13, 0.82, 13))
	else
		PropKit.pad(s, sellPos, 6, Color3.fromRGB(80, 220, 80))
	end
	local holder = promptSpot(s, CFrame.new(sellPos + Vector3.new(0, 1, 0)), "SellLabel")
	PropKit.billboard(holder, "DROP BUNDLES", Color3.fromRGB(255, 230, 80), Vector2.new(12, 2.6), Vector3.new(0, 5, 0), 120)
	info.sellPads = info.sellPads or {}
	table.insert(info.sellPads, { pos = sellPos, radius = 7, mouth = mouth, out = out })
	if not info.sellPos then
		info.sellPos = sellPos
		info.sellRadius = 7
		info.shredderMouth = mouth
		info.shredderOut = out
	end
	return true
end

local function shredder(m: Instance, info): boolean
	local pos = Vector3.new(-24, FLOOR_Y, -36)
	if not shredderAt(m, info, CFrame.lookAt(pos, pos - Vector3.xAxis), "Shredder") then -- drum toward the spawn
		return false
	end
	local s = m:FindFirstChild("Shredder") :: Instance
	-- the 2X COINS board next to the machine (opens the store)
	local signAt = CFrame.lookAt(Vector3.new(-38, FLOOR_Y, -50), Vector3.new(-6, FLOOR_Y, -68))
	if Models.place("start_sign", s, signAt, 0.45, true) then
		PropKit.facePanel(s, signAt, Vector3.new(0, 9.3, -0.62), Vector2.new(27, 4), "2X COINS", Color3.fromRGB(255, 214, 60), 0.45)
		PropKit.facePanel(s, signAt, Vector3.new(0, 6.1, -0.62), Vector2.new(27, 1.5), "BUY!", Color3.fromRGB(120, 255, 90), 0.45)
		PropKit.prompt(promptSpot(s, signAt * CFrame.new(0, 3, -1.5), "CoinsSign"), "Open", "2x Coins", "Store", 10)
	end
	return true
end

local function hub(world: Instance, info)
	local m = PropKit.folder("Hub", world)
	-- ground: grass with a dirt yard around the cabin and the machines, and a worn path out to the first field
	-- (Terrain version; the Blender ground_hub model has the same layout)
	if not info.meshGround then
		Ground.patch(0, -48, 92, 56, Enum.Material.Ground, 3)
		Ground.patch(-8, -36, 16, 16, Enum.Material.Mud, 6) -- trodden mud at the sell pad
	end
	Environment.spawn(m, CFrame.lookAt(Vector3.new(0, 0.8, -68), Vector3.new(0, 0.8, 0)))
	toolShop(m, info)
	bagStand(m)
	garageBay(m, info)
	if shredder(m, info) then
		return
	end

	-- Giant Grass Shredder (brick version, used until the Blender model is uploaded)
	local s = PropKit.folder("Shredder", m)
	local base = CFrame.new(-28, 0, -45) * CFrame.Angles(0, math.rad(-90), 0)
	local orange = Color3.fromRGB(255, 140, 40)
	local body = PropKit.brick(s, Vector3.new(14, 10, 10), base * CFrame.new(0, 5, 0), orange, "ShredderBody")
	PropKit.brick(s, Vector3.new(15, 1.4, 11), base * CFrame.new(0, 10.6, 0), PropKit.shade(orange, 0.8), "ShredderRim")
	-- hopper (stepped funnel)
	for i = 0, 2 do
		local w = 12 + i * 2.4
		PropKit.brick(s, Vector3.new(w, 1.6, 8 + i * 2), base * CFrame.new(0, 12 + i * 1.6, 0), PropKit.shade(Color3.fromRGB(255, 205, 50), 1 - i * 0.05), "Hopper")
	end
	local mouth = PropKit.brick(s, Vector3.new(10, 0.6, 6), base * CFrame.new(0, 16.6, 0), Color3.fromRGB(35, 30, 40), "Mouth")
	mouth.Name = "ShredderMouth"
	-- teeth rollers
	for _, x in { -2.5, 2.5 } do
		local roller = PropKit.cylinder(s, 1.4, 9, base * CFrame.new(x, 16.2, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(180, 180, 195))
		roller.Name = "Roller"
		roller:SetAttribute("Spin", 6)
	end
	-- coin chute
	PropKit.brick(s, Vector3.new(4, 3, 4), base * CFrame.new(0, 1.5, -6.5), Color3.fromRGB(60, 60, 70), "Chute")
	PropKit.brick(s, Vector3.new(6, 1, 3), base * CFrame.new(0, 0.5, -9), Color3.fromRGB(255, 205, 50), "CoinTray")
	local sign = PropKit.sign(s, base * CFrame.new(0, 6, -5.2), Vector3.new(12, 3, 0.6), "SHREDDER", Color3.fromRGB(80, 200, 80))
	sign.Name = "ShredderSign"
	local sellPos = (base * CFrame.new(0, 0, -13)).Position
	PropKit.pad(s, sellPos, 6, Color3.fromRGB(80, 220, 80), "SELL BUNDLES")
	info.sellPos = sellPos
	info.sellRadius = 7
	info.shredderMouth = mouth.Position
	info.shredderOut = (base * CFrame.new(0, 1, -9)).Position
	info.sellPads = info.sellPads or {}
	table.insert(info.sellPads, 1, { pos = sellPos, radius = 7, mouth = info.shredderMouth, out = info.shredderOut })
	body:SetAttribute("Shredder", true)
end

-------------------------------------------------------------------------------------------------------------
-- the world: a 3 x 3 grid of fenced plots, like Chop A Forest's woods (see Config.MAP)
-------------------------------------------------------------------------------------------------------------
local M = Config.MAP
local HALF = M.cell / 2
local HUB = Config.zoneCentre(0)
local COLS, ROWS = 3, 3
local MIN_X = HUB.X + (1 - M.hubCell[1]) * M.cell - HALF
local MAX_X = HUB.X + (COLS - M.hubCell[1]) * M.cell + HALF
local MIN_Z = HUB.Z + (1 - M.hubCell[2]) * M.cell - HALF
local MAX_Z = HUB.Z + (ROWS - M.hubCell[2]) * M.cell + HALF
local MID = Vector3.new((MIN_X + MAX_X) / 2, 0, (MIN_Z + MAX_Z) / 2)
local FENCE_H = 26 -- the invisible wall over every fence, so nobody hops into a locked area

-- the ground of each area's field (a grassy verge runs along its fences)
local ZONE_GROUND = {
	lawn = Enum.Material.Grass,
	meadow = Enum.Material.LeafyGrass,
	golf = Enum.Material.Grass,
	wheat = Enum.Material.Ground,
	blossom = Enum.Material.Grass,
	reeds = Enum.Material.Mud,
	prairie = Enum.Material.Sand,
	jungle = Enum.Material.LeafyGrass,
}

-- Spots inside an area kept free of grass: the way in through every gate, the drop-off shredder, and the area's
-- props (sand traps, hay, ponds, trees, rocks). Built the same way every time, so the grass and the props agree.
type Keepout = { pos: Vector3, r: number, kind: string }
local keepoutCache: { [number]: { Keepout } } = {}
local function keepouts(z: number): { Keepout }
	local cached = keepoutCache[z]
	if cached then
		return cached
	end
	local c = Config.zoneCentre(z)
	local rng = Random.new(z * 3571 + 11)
	local list: { Keepout } = {}
	local function add(pos: Vector3, r: number, kind: string)
		table.insert(list, { pos = pos, r = r, kind = kind })
	end
	for _, g in Config.gates() do
		if g.a == z or g.b == z then
			local into = c - g.pos
			add(g.pos + Vector3.new(into.X, 0, into.Z).Unit * 9, 12, "gate")
		end
	end
	if M.dropOff == z then
		add(c, 25, "dropoff")
	elseif Config.BOSSES then
		add(c, 14, "arena")
	end
	-- `n` props of radius `r` at random spots, clear of everything placed so far
	local function scatter(n: number, r: number, kind: string)
		local placed, tries = 0, 0
		while placed < n and tries < n * 30 do
			tries += 1
			local edge = r + 10
			local p = c + Vector3.new(rng:NextNumber(-HALF + edge, HALF - edge), 0, rng:NextNumber(-HALF + edge, HALF - edge))
			local free = true
			for _, k in list do
				if (p - k.pos).Magnitude < k.r + r + 6 then
					free = false
					break
				end
			end
			if free then
				add(p, r, kind)
				placed += 1
			end
		end
	end
	local style = Config.ZONES[z].style
	if style == "golf" then
		scatter(4, 9, "sand")
		scatter(1, 6, "flag")
	elseif style == "meadow" then
		scatter(5, 6, "birch")
	elseif style == "wheat" then
		scatter(5, 5, "hay")
		scatter(1, 8, "haystack")
	elseif style == "blossom" then
		scatter(7, 7, "blossomtree")
	elseif style == "reeds" then
		scatter(3, 15, "pond")
	elseif style == "prairie" then
		scatter(5, 7, "autumntree")
		scatter(2, 5, "hay")
	elseif style == "jungle" then
		scatter(6, 9, "bigtree")
	end
	scatter(2, 4, "rock")
	scatter(2, 4, "bush")
	keepoutCache[z] = list
	return list
end

-- Every grass clump of area z: { cf, scale } on the ground, on a jittered grid (every other row shifted half a
-- step, so it reads like a planted forest, not a grid). Keep-out spots stay clear.
export type PatchSpot = { cf: CFrame, scale: number }
local patchCache: { [number]: { PatchSpot } } = {}
function RunBuilder.patches(z: number): { PatchSpot }
	local cached = patchCache[z]
	if cached then
		return cached
	end
	local def = Config.ZONES[z]
	local c = Config.zoneCentre(z)
	local s = def.spacing or 14
	local rng = Random.new(z * 7919)
	local list: { PatchSpot } = {}
	local lo = -HALF + M.margin + s * 0.5
	local hi = HALF - M.margin - s * 0.5
	local row = 0
	local zz = lo
	while zz <= hi + 0.01 do
		local xx = lo + (row % 2) * s * 0.5
		while xx <= hi + 0.01 do
			local pos = c + Vector3.new(xx + rng:NextNumber(-0.25, 0.25) * s, 0, zz + rng:NextNumber(-0.25, 0.25) * s)
			local yaw = rng:NextNumber(0, 2 * math.pi)
			local scale = (def.scale or 2) * rng:NextNumber(0.88, 1.12)
			local blocked = false
			for _, k in keepouts(z) do
				local d = pos - k.pos
				if d.X * d.X + d.Z * d.Z < (k.r + s * 0.45) ^ 2 then
					blocked = true
					break
				end
			end
			if not blocked then
				table.insert(list, { cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0), scale = scale })
			end
			xx += s
		end
		zz += s * 0.87
		row += 1
	end
	patchCache[z] = list
	return list
end

-- A straight fence from a to b (the wooden fence model) with an invisible wall over it. `out` is sideways to it.
local function fenceLine(parent: Instance, a: Vector3, b: Vector3, out: Vector3)
	local len = (b - a).Magnitude
	if len < 1 then
		return
	end
	PropKit.fenceRow(parent, a, b, out)
	local mid = (a + b) / 2 + Vector3.new(0, FENCE_H / 2, 0)
	PropKit.wall(parent, Vector3.new(len + 0.6, FENCE_H, 1.6), CFrame.lookAt(mid, mid + out)).Name = "FenceWall"
end

-- The fences: every shared edge gets a gate in the middle (closed until both sides are open), and the outside
-- edge of the world is one long fence.
local function fences(world: Instance, info)
	local f = PropKit.folder("Fences", world)
	local gatesFolder = PropKit.folder("Gates", world)
	local w = M.gateWidth
	for _, g in Config.gates() do
		local out = g.along:Cross(Vector3.yAxis)
		fenceLine(f, g.pos - g.along * HALF, g.pos - g.along * (w / 2), out)
		fenceLine(f, g.pos + g.along * (w / 2), g.pos + g.along * HALF, out)
		-- lanterns either side of the opening, on the side you come from
		local back = Config.zoneCentre(g.a) - g.pos
		back = Vector3.new(back.X, 0, back.Z).Unit
		for side = -1, 1, 2 do
			local p = g.pos + g.along * side * (w / 2 + 2.5) + back * 2.5
			Models.place("lantern_post", f, CFrame.lookAt(p, p + back), 0.8, true)
		end
		-- the gate itself: its front looks back toward the side you come from
		local model = Instance.new("Model")
		model.Name = ("Gate%d_%d"):format(g.b, g.a)
		local gateAt = CFrame.lookAt(g.pos, g.pos + back)
		local scale = w / 16
		local need = Config.ZONES[g.b - 1]
		local text = if need then "LOCKED\nMow the " .. need.name else "LOCKED"
		if Models.place("gate", model, gateAt, scale, true) then
			PropKit.facePanel(model, gateAt, Vector3.new(0, 5.3, -2.3), Vector2.new(15.6, 4), text, Color3.fromRGB(255, 235, 120), scale)
		else
			local logColor = Color3.fromRGB(125, 80, 50)
			for x = -w / 2 + 1.5, w / 2 - 1.5, 3 do
				local hgt = 11 + ((x * 7) % 3)
				local log = PropKit.cylinder(model, 1.5, hgt, gateAt * CFrame.new(x, hgt / 2, 0), PropKit.shade(logColor, 0.95))
				log.Material = Enum.Material.Wood
				log.Name = "GateLog"
			end
			local sign = PropKit.brick(model, Vector3.new(w + 2, 4.2, 0.6), gateAt * CFrame.new(0, 6.5, -2.3), Color3.fromRGB(200, 160, 105), "GateSign", Enum.Material.WoodPlanks)
			PropKit.surfaceText(sign, text, Color3.fromRGB(255, 235, 120))
		end
		local up = g.pos + Vector3.new(0, FENCE_H / 2, 0)
		PropKit.wall(model, Vector3.new(w + 2, FENCE_H, 2), CFrame.lookAt(up, up + back)).Name = "GateWall"
		model.Parent = gatesFolder
		table.insert(info.gates, { a = g.a, b = g.b, model = model })
	end
	local corners = { Vector3.new(MIN_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MIN_Z), Vector3.new(MAX_X, 0, MAX_Z), Vector3.new(MIN_X, 0, MAX_Z) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local mid = (a + b) / 2
		fenceLine(f, a, b, (mid - MID).Unit)
	end
end

-- Each area's name on a board just inside the gate you reach it through, so you can read it over the closed gate.
local function areaSign(parent: Instance, z: number)
	local g = Config.gateInto(z)
	if not g then
		return
	end
	local def = Config.ZONES[z]
	local into = Config.zoneCentre(z) - g.pos
	into = Vector3.new(into.X, 0, into.Z).Unit
	local pos = g.pos + into * 7 + g.along * (M.gateWidth / 2 + 9)
	local signAt = CFrame.lookAt(pos, g.pos - into * 6)
	if Models.place("start_sign", parent, signAt, 0.55, true) then
		PropKit.facePanel(parent, signAt, Vector3.new(0, 9.0, -0.62), Vector2.new(27, 4.6), def.name, Color3.fromRGB(255, 240, 200), 0.55)
	else
		PropKit.sign(parent, signAt * CFrame.new(0, 7, 0), Vector3.new(16, 4, 1), def.name, def.grass[1], Color3.new(1, 1, 1))
	end
end

-- One area: its props on their keep-out spots (and the drop-off shredder in its own clearing).
local function areaProps(world: Instance, z: number, info)
	local m = PropKit.folder("Zone" .. z, world)
	areaSign(m, z)
	for _, k in keepouts(z) do
		local at = CFrame.new(k.pos) * CFrame.Angles(0, math.rad((k.pos.X * 13 + k.pos.Z * 7) % 360), 0)
		if k.kind == "sand" then
			Ground.disc(k.pos.X, k.pos.Z, k.r - 1, Enum.Material.Sand)
		elseif k.kind == "flag" then
			if not Models.place("golf_flag", m, at, 1, true) then
				PropKit.brick(m, Vector3.new(0.5, 9, 0.5), at * CFrame.new(0, 4.5, 0), Color3.fromRGB(255, 255, 255), "FlagPole")
				PropKit.brick(m, Vector3.new(0.2, 2.4, 3.4), at * CFrame.new(0, 7.8, 1.7), Color3.fromRGB(255, 70, 70), "Flag")
			end
		elseif k.kind == "hay" or k.kind == "haystack" then
			if not Models.place("hay_bale", m, at, if k.kind == "haystack" then 1.4 else 1) then
				PropKit.brick(m, Vector3.new(4, 3.6, 4), at * CFrame.new(0, 1.8, 0), Color3.fromRGB(235, 190, 70), "HayBale")
			end
		elseif k.kind == "pond" then
			Ground.water(k.pos.X, k.pos.Z, k.r * 1.5, k.r * 1.1, 3)
		elseif k.kind == "bigtree" then
			if not Models.place("jungle_tree", m, at, 1.2, true) then
				PropKit.forestTree(m, k.pos, 1.9, { leaf = Color3.fromRGB(20, 95, 38) })
			end
		elseif k.kind == "blossomtree" then
			PropKit.forestTree(m, k.pos, 0.75, { leaf = Color3.fromRGB(255, 170, 210), bricks = true })
		elseif k.kind == "autumntree" then
			PropKit.forestTree(m, k.pos, 0.8, { leaf = if (k.pos.X + k.pos.Z) % 2 < 1 then Color3.fromRGB(235, 120, 40) else Color3.fromRGB(215, 60, 45), bricks = true })
		elseif k.kind == "birch" then
			PropKit.forestTree(m, k.pos, 0.75, { birch = true })
		elseif k.kind == "rock" then
			Models.place("rock", m, at, 1.6)
		elseif k.kind == "bush" then
			Models.place("bush", m, at, 1.3, true)
		elseif k.kind == "dropoff" then
			-- Chop A Forest's far-off shredder: sell here instead of walking all the way back to the hub
			Ground.disc(k.pos.X, k.pos.Z, k.r - 2, Enum.Material.Ground)
			local machine = k.pos - Vector3.xAxis * 8
			if shredderAt(m, info, CFrame.lookAt(machine, machine - Vector3.xAxis), "DropOff") then
				local holder = promptSpot(m, CFrame.new(machine + Vector3.new(0, 1, 0)), "DropOffLabel")
				PropKit.billboard(holder, "DROP-OFF", Color3.fromRGB(120, 255, 90), Vector2.new(10, 2.4), Vector3.new(0, 15, 0), 220)
			end
			gasPump(m, k.pos + Vector3.new(4, 0, 15), info, Vector3.zAxis)
		elseif k.kind == "arena" then
			Ground.disc(k.pos.X, k.pos.Z, 12, Enum.Material.Ground)
		end
	end
end

-- The hub's yard: dirt paths from the spawn to its three gates, a few trees and hay in the corners.
local function hubYard(world: Instance)
	local m = PropKit.folder("HubYard", world)
	Ground.path(Vector3.new(0, 0, -64), HUB + Vector3.new(0, 0, HALF + 3), 12, Enum.Material.Ground, 4)
	for _, side in { -1, 1 } do
		Ground.path(HUB + Vector3.new(side * 40, 0, -2), HUB + Vector3.new(side * (HALF + 3), 0, 0), 11, Enum.Material.Ground, 5 + side)
	end
	local rng = Random.new(5)
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		for i = 1, 3 do
			local p = HUB + Vector3.new(corner.X * (HALF - 14 - i * 9), 0, corner.Z * (HALF - 12 - rng:NextNumber(0, 16)))
			PropKit.forestTree(m, p, rng:NextNumber(0.8, 1.05), { birch = i == 2 })
		end
		Models.place("hay_bale", m, CFrame.new(HUB + Vector3.new(corner.X * (HALF - 40), 0, corner.Z * (HALF - 22))), 1, true)
	end
end

-- The forest belt all round the outside fence and the snowy mountains on the horizon.
local function horizon(world: Instance)
	local f = PropKit.folder("Forest", world)
	local rng = Random.new(77)
	local step = 22
	local n = 0
	for x = MIN_X - 96, MAX_X + 96, step do
		for z = MIN_Z - 96, MAX_Z + 96, step do
			if not (x > MIN_X - 10 and x < MAX_X + 10 and z > MIN_Z - 10 and z < MAX_Z + 10) then
				local pos = Vector3.new(x + rng:NextNumber(-6, 6), 0, z + rng:NextNumber(-6, 6))
				local pick = rng:NextNumber()
				local name = if pick < 0.12 then "birch" elseif pick < 0.3 then "jungle_tree" elseif pick < 0.55 then "oak_small" else "oak"
				local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
				if not Models.place(name, f, cf, rng:NextNumber(1.0, 1.45), true) then
					PropKit.forestTree(f, pos, rng:NextNumber(1.0, 1.3), { lite = true, birch = name == "birch" })
				end
				n += 1
				if n % 60 == 0 then
					task.wait()
				end
			end
		end
	end
	local reach = math.max(MAX_X - MIN_X, MAX_Z - MIN_Z) / 2
	for i = 0, 27 do
		local a = (i + rng:NextNumber(-0.2, 0.2)) / 28 * 2 * math.pi
		local r = reach + rng:NextNumber(230, 290)
		PropKit.mountain(world, MID + Vector3.new(math.sin(a) * r, -2, math.cos(a) * r), rng:NextNumber(2.8, 3.8))
	end
end

function RunBuilder.build()
	local world = Environment.apply()
	local info = { world = world, gates = {}, pumps = {}, sellPads = {}, meshGround = false }

	-- the ground: grass everywhere, each area's own field inside a grassy verge
	Ground.fill(MID.X, MID.Z, (MAX_X - MIN_X) + 280, (MAX_Z - MIN_Z) + 280, Enum.Material.Grass)
	for z, def in Config.ZONES do
		local mat = ZONE_GROUND[def.style] or Enum.Material.Grass
		if mat ~= Enum.Material.Grass then
			local c = Config.zoneCentre(z)
			Ground.fill(c.X, c.Z, M.cell - 12, M.cell - 12, mat)
		end
	end

	hub(world, info)
	hubYard(world)
	fences(world, info)
	for z = 1, #Config.ZONES do
		areaProps(world, z, info)
		task.wait()
	end
	horizon(world)
	Ground.flatten(MID.X, MID.Z, math.max(MAX_X - MIN_X, MAX_Z - MIN_Z) / 2 + 140) -- surface exactly at y = 0
	return info
end

-- Area z's middle (the boss arena when bosses are on, see Config.BOSSES).
function RunBuilder.zoneCentre(z: number): Vector3
	return Config.zoneCentre(z)
end

return RunBuilder
