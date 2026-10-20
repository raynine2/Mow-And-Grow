-- Builds a run's map: ONE big round world (see Config.RING). The hub (shredder, tool shop, bag stand, garage,
-- gas pump) sits in the middle; each zone is a fenced ring around the one before it, wider every time, like the
-- walls in Attack on Titan. One road runs out of the hub through a gate in every fence. A forest belt and a ring
-- of snowy mountains close the world off.
-- Grass patches are spawned by Field (positions from RunBuilder.patches); this file builds the static world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Format = require(ReplicatedStorage.MowALawn.Format)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local Environment = require(script.Parent.Environment)
local Ground = require(script.Parent.Ground)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

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
-- The Giant Grass Shredder (Blender model) with its log-framed sell pad in front of the hopper.
local function shredder(m: Instance, info): boolean
	local s = PropKit.folder("Shredder", m)
	local pos = Vector3.new(-24, FLOOR_Y, -36)
	local at = CFrame.lookAt(pos, pos - Vector3.xAxis) -- drum toward the spawn, hopper toward the yard
	if not Models.place("shredder", s, at, 1.15, true) then
		return false
	end
	PropKit.collider(s, at, Vector3.new(0, 5, -0.7), Vector3.new(7.8, 10, 14.5), 1.15)
	info.shredderMouth = (at * CFrame.new(Vector3.new(0.3, 8.8, 4.8) * 1.15)).Position
	info.shredderOut = (at * CFrame.new(Vector3.new(0, 1.2, -8.6) * 1.15)).Position
	local padAt = at * CFrame.new(0, 0, 16.5)
	local sellPos = padAt.Position
	if Models.place("sell_pad", s, padAt, 1, true) then
		PropKit.collider(s, padAt, Vector3.new(0, 0.41, 0), Vector3.new(13, 0.82, 13))
	else
		PropKit.pad(s, sellPos, 6, Color3.fromRGB(80, 220, 80))
	end
	local holder = promptSpot(s, CFrame.new(sellPos + Vector3.new(0, 1, 0)), "SellLabel")
	PropKit.billboard(holder, "DROP BUNDLES", Color3.fromRGB(255, 230, 80), Vector2.new(12, 2.6), Vector3.new(0, 5, 0), 120)
	info.sellPos = sellPos
	info.sellRadius = 7
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
	body:SetAttribute("Shredder", true)
end

-------------------------------------------------------------------------------------------------------------
-- the ring world
-------------------------------------------------------------------------------------------------------------
local R = Config.RING
local C = R.centre

-- the ground under each zone's field
local ZONE_GROUND = {
	lawn = Enum.Material.Grass,
	golf = Enum.Material.Grass,
	wheat = Enum.Material.Ground,
	reeds = Enum.Material.Mud,
	jungle = Enum.Material.LeafyGrass,
}

-- a point at radius r and angle a (radians, 0 = along the road, +Z), on the ground
local function polar(r: number, a: number): Vector3
	return C + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
end

-- Spots inside a zone's field kept free of grass for its props (ponds, sand traps, hay bales, big trees, rocks).
-- Built the same way every time, so the grass and the props agree.
type Keepout = { pos: Vector3, r: number, kind: string }
local keepoutCache: { [number]: { Keepout } } = {}
local function keepouts(z: number): { Keepout }
	local cached = keepoutCache[z]
	if cached then
		return cached
	end
	local ring = R.zones[z]
	local mid = (ring.inner + ring.outer) / 2
	local list: { Keepout } = {}
	local style = Config.ZONES[z].style
	local function add(angleDeg: number, r: number, radius: number, kind: string)
		table.insert(list, { pos = polar(r, math.rad(angleDeg)), r = radius, kind = kind })
	end
	if style == "golf" then
		for _, a in { 100, 175, 255, 320 } do
			add(a, mid + ((a % 3) - 1) * 12, 9, "sand")
		end
		add(205, mid, 7, "flag")
	elseif style == "wheat" then
		for _, a in { 85, 140, 200, 265, 325 } do
			add(a, ring.inner + 10, 5, "hay")
		end
		add(232, mid, 8, "haystack")
	elseif style == "reeds" then
		for _, a in { 95, 160, 220, 290 } do
			add(a, mid, 16, "pond")
		end
	elseif style == "jungle" then
		for _, a in { 70, 120, 170, 215, 260, 300, 335 } do
			add(a, mid + ((a % 5) - 2) * 10, 9, "bigtree")
		end
	end
	-- a few rocks and bushes in every zone, near its outer fence
	for i = 1, 5 do
		add(60 + i * 55 + z * 13, ring.outer - 6, 4, if i % 2 == 0 then "rock" else "bush")
	end
	keepoutCache[z] = list
	return list
end

-- Every grass clump of zone z: { cf, scale } on the ground, scattered in rows round the ring (each row jittered
-- and offset so it doesn't read as a grid). The road and the keep-out spots stay clear.
export type PatchSpot = { cf: CFrame, scale: number }
local patchCache: { [number]: { PatchSpot } } = {}
function RunBuilder.patches(z: number): { PatchSpot }
	local cached = patchCache[z]
	if cached then
		return cached
	end
	local ring = R.zones[z]
	local s = ring.spacing
	local rng = Random.new(z * 7919)
	local list: { PatchSpot } = {}
	local r = ring.inner + s * 0.5
	local row = 0
	while r <= ring.outer - s * 0.4 do
		local n = math.max(8, math.floor(2 * math.pi * r / s))
		local offset = (row % 2) * 0.5
		for i = 0, n - 1 do
			local a = (i + offset + rng:NextNumber(-0.18, 0.18)) / n * 2 * math.pi
			local pos = polar(r + rng:NextNumber(-0.22, 0.22) * s, a)
			local rel = pos - C
			local blocked = rel.Z > 0 and math.abs(rel.X) < R.road + s * 0.4 -- the road
			if not blocked then
				for _, k in keepouts(z) do
					local d = pos - k.pos
					if d.X * d.X + d.Z * d.Z < (k.r + s * 0.45) ^ 2 then
						blocked = true
						break
					end
				end
			end
			if not blocked then
				table.insert(list, {
					cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
					scale = ring.scale * rng:NextNumber(0.88, 1.12),
				})
			end
		end
		r += s * 0.87
		row += 1
	end
	patchCache[z] = list
	return list
end

-- A ring of fence round the centre at `radius`, with an opening `gap` studs wide where the road crosses it.
-- Every piece has an invisible collider so nobody hops over into a locked zone.
local function ringFence(parent: Instance, radius: number, gap: number)
	local n = math.max(12, math.floor(2 * math.pi * radius / 10 + 0.5))
	for i = 0, n - 1 do
		local p0 = polar(radius, i / n * 2 * math.pi)
		local p1 = polar(radius, (i + 1) / n * 2 * math.pi)
		local mid = (p0 + p1) / 2
		local rel = mid - C
		if not (rel.Z > 0 and math.abs(rel.X) < gap / 2) then
			local out = Vector3.new(rel.X, 0, rel.Z).Unit
			PropKit.fenceRow(parent, p0, p1, out)
			local up = mid + Vector3.new(0, 13, 0)
			PropKit.wall(parent, Vector3.new((p1 - p0).Magnitude + 0.6, 26, 1.6), CFrame.lookAt(up, up + out)).Name = "FenceWall"
		end
	end
end

-- The forest belt outside the last fence and the ring of snowy mountains on the horizon.
local function horizon(world: Instance)
	local f = PropKit.folder("Forest", world)
	local rng = Random.new(77)
	local rr = R.edge + 10
	local row = 0
	while rr <= R.edge + 96 do
		local n = math.floor(2 * math.pi * rr / 24)
		for i = 0, n - 1 do
			local pos = polar(rr + rng:NextNumber(-6, 6), (i + (row % 2) * 0.5 + rng:NextNumber(-0.25, 0.25)) / n * 2 * math.pi)
			local pick = rng:NextNumber()
			local name = if pick < 0.12 then "birch" elseif pick < 0.3 then "jungle_tree" elseif pick < 0.55 then "oak_small" else "oak"
			Models.place(name, f, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), rng:NextNumber(1.0, 1.45), true)
		end
		rr += 22
		row += 1
	end
	for i = 0, 23 do
		local a = (i + rng:NextNumber(-0.2, 0.2)) / 24 * 2 * math.pi
		PropKit.mountain(world, polar(rng:NextNumber(600, 660), a) + Vector3.new(0, -2, 0), rng:NextNumber(2.6, 3.6))
	end
end

-- One zone: the fence (with the gate) you cross to get in, its sign, gas pump, lanterns, boss arena and props.
local function zone(world: Instance, z: number, info)
	local def = Config.ZONES[z]
	local ring = R.zones[z]
	local m = PropKit.folder("Zone" .. z, world)
	local gate = Config.gatePos(z)
	local width = R.road * 2 + 8

	ringFence(m, Config.fenceRadius(z), width)

	-- zone sign beside the gate, inside the ring, turned to the road
	local signAt = CFrame.lookAt(gate + Vector3.new(-R.road - 10, 0, 7), gate + Vector3.new(0, 0, 4))
	if Models.place("start_sign", m, signAt, 0.55, true) then
		PropKit.facePanel(m, signAt, Vector3.new(0, 9.0, -0.62), Vector2.new(27, 4.6), def.name, Color3.fromRGB(255, 240, 200), 0.55)
	else
		PropKit.sign(m, signAt * CFrame.new(0, 7, 0), Vector3.new(16, 4, 1), def.name, def.grass[1], Color3.new(1, 1, 1))
	end

	-- the gate (zones 2+): closed until the boss before it falls
	if z > 1 then
		local g = Instance.new("Model")
		g.Name = "Gate" .. z
		local gateAt = CFrame.lookAt(gate, gate - Vector3.zAxis) -- faces the hub side
		if Models.place("gate", g, gateAt, width / 16, true) then
			PropKit.facePanel(g, gateAt, Vector3.new(0, 5.3, -2.3), Vector2.new(15.6, 4), "LOCKED\nBeat the " .. Config.ZONES[z - 1].boss.name, Color3.fromRGB(255, 235, 120), width / 16)
		else
			local logColor = Color3.fromRGB(125, 80, 50)
			for x = -width / 2 + 1.5, width / 2 - 1.5, 3 do
				local hgt = 11 + ((x * 7) % 3)
				local log = PropKit.cylinder(g, 1.5, hgt, CFrame.new(gate + Vector3.new(x, hgt / 2, 0)), PropKit.shade(logColor, 0.95))
				log.Material = Enum.Material.Wood
				log.Name = "GateLog"
			end
			local sign = PropKit.brick(g, Vector3.new(22, 4.2, 0.6), CFrame.new(gate + Vector3.new(0, 6.5, -2.3)), Color3.fromRGB(200, 160, 105), "GateSign", Enum.Material.WoodPlanks)
			PropKit.surfaceText(sign, "LOCKED: beat the " .. Config.ZONES[z - 1].boss.name, Color3.fromRGB(255, 235, 120))
		end
		PropKit.wall(g, Vector3.new(width + 2, 30, 2), CFrame.new(gate + Vector3.new(0, 15, 0))).Name = "GateWall"
		g.Parent = m
		info.gates[z] = g
	end

	-- a gas pump just inside the gate beside the road, and lanterns along the road through the ring
	gasPump(m, gate + Vector3.new(R.road + 7, 0, 10), info, -Vector3.xAxis)
	local r = ring.inner + 4
	while r < ring.outer do
		for side = -1, 1, 2 do
			local p = R.centre + Vector3.new(side * (R.road + 2), 0, r)
			Models.place("lantern_post", m, CFrame.lookAt(p, R.centre + Vector3.new(0, 0, r)), 0.8, true)
		end
		r += 34
	end

	-- the boss arena: a worn dirt circle the boss grows out of
	local arena = Config.zoneCentre(z)
	Ground.disc(arena.X, arena.Z, 12, Enum.Material.Ground)

	-- the zone's props (their spots are kept free of grass, see keepouts)
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
		elseif k.kind == "rock" then
			Models.place("rock", m, at, 1.6)
		elseif k.kind == "bush" then
			Models.place("bush", m, at, 1.3, true)
		end
	end
end

function RunBuilder.build()
	local world = Environment.apply()
	-- one round world on Terrain (the straight-road Blender ground sheets don't fit it)
	local info = { world = world, gates = {}, pumps = {}, meshGround = false }

	-- the ground, painted from the outside in: forest floor, each ring's own ground, then the hub
	Ground.disc(C.X, C.Z, R.edge + 260, Enum.Material.Grass)
	for z = #Config.ZONES, 1, -1 do
		local mat = ZONE_GROUND[Config.ZONES[z].style] or Enum.Material.Grass
		Ground.disc(C.X, C.Z, Config.fenceRadius(z + 1) - 2, mat)
		if mat ~= Enum.Material.Grass then
			-- a grassy verge along the fence, so every ring reads as its own field
			Ground.ring(C.X, C.Z, Config.fenceRadius(z) - 1, Config.fenceRadius(z) + 5, Enum.Material.Grass)
		end
	end
	Ground.disc(C.X, C.Z, R.hub + 3, Enum.Material.Grass)
	-- the road out of the hub, through every gate to the edge of the world
	Ground.path(C + Vector3.new(0, 0, 20), C + Vector3.new(0, 0, R.edge + 6), R.road * 2, Enum.Material.Ground, 4)

	hub(world, info)
	-- the old lobby's buildings (party pads, classes, rewards, garage, boards) round the hub: one map
	info.lobby = LobbyBuilder.hub(world)
	for z = 1, #Config.ZONES do
		zone(world, z, info)
	end
	ringFence(PropKit.folder("Edge", world), R.edge, 0) -- the edge of the world
	horizon(world)
	Ground.flatten(C.X, C.Z, R.edge + 260) -- surface exactly at y = 0, where everything stands
	return info
end

-- Zone z's boss arena (see Config.zoneCentre).
function RunBuilder.zoneCentre(z: number): Vector3
	return Config.zoneCentre(z)
end

return RunBuilder
