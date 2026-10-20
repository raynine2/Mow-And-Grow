-- One landmark in each run area, something worth walking to (the paths through an area lead to it): a garden
-- shed, a stone well, a golf clubhouse with its putting green, a windmill and a red barn, a white gazebo, a
-- wooden bridge over the swamp pond, a hay wagon with a scarecrow, a jungle lookout tower. Built from bricks in
-- the chunky style of the rest of the map. Each stands on `cf` (its front = cf.LookVector, toward the path).
local PropKit = require(script.Parent.PropKit)
local Ground = require(script.Parent.Ground)

local Landmarks = {}

-- how much room each needs (kept free of grass)
Landmarks.RADIUS = {
	lawn = 13,
	meadow = 11,
	golf = 22,
	wheat = 24,
	blossom = 12,
	reeds = 22,
	prairie = 11,
	jungle = 14,
}

local WOOD = Color3.fromRGB(150, 98, 58)
local DARK = Color3.fromRGB(96, 60, 36)
local WHITE = Color3.fromRGB(240, 238, 228)
local STONE = Color3.fromRGB(150, 148, 140)

local function b(m: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	return PropKit.brick(m, size, cf, color, name or "Piece", material or Enum.Material.SmoothPlastic)
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	return p
end

-- A gabled roof of two slabs over a w x d footprint whose eaves are at height y (in cf's space).
local function gable(m: Instance, cf: CFrame, w: number, d: number, y: number, color: Color3, pitch: number?)
	local a = math.rad(pitch or 30)
	local half = w / 2 + 0.8
	local slab = half / math.cos(a)
	for side = -1, 1, 2 do
		local c = cf * CFrame.new(side * half / 2, y + math.tan(a) * half / 2, 0) * CFrame.Angles(0, 0, -side * a)
		b(m, Vector3.new(slab, 0.6, d + 1.6), c, color, Enum.Material.WoodPlanks, "Roof")
	end
	-- gable ends (triangle-ish: stacked shrinking boards)
	for _, z in { -d / 2, d / 2 } do
		local rows = 4
		for i = 0, rows - 1 do
			local k = 1 - (i + 0.5) / rows
			b(m, Vector3.new(w * k, math.tan(a) * half / rows, 0.4), cf * CFrame.new(0, y + math.tan(a) * half * (i + 0.5) / rows, z), DARK, Enum.Material.WoodPlanks, "Gable")
		end
	end
end

local function shed(m: Instance, cf: CFrame)
	local W, D, H = 9, 7, 6
	b(m, Vector3.new(W, 0.4, D), cf * CFrame.new(0, 0.2, 0), DARK, Enum.Material.WoodPlanks)
	for _, e in { { 0, -D / 2, W, 0.4 }, { 0, D / 2, W, 0.4 }, { -W / 2, 0, 0.4, D }, { W / 2, 0, 0.4, D } } do
		b(m, Vector3.new(e[3], H, e[4]), cf * CFrame.new(e[1], H / 2, e[2]), Color3.fromRGB(110, 170, 210), Enum.Material.WoodPlanks, "Wall")
	end
	b(m, Vector3.new(3, 4.6, 0.5), cf * CFrame.new(0, 2.5, -D / 2 - 0.05), WHITE, Enum.Material.WoodPlanks, "Door")
	b(m, Vector3.new(2, 1.6, 0.5), cf * CFrame.new(-2.9, 3.6, -D / 2 - 0.05), Color3.fromRGB(180, 220, 255), Enum.Material.Glass, "Window")
	gable(m, cf, W, D, H, Color3.fromRGB(180, 70, 55))
	-- a picnic table beside it
	local t = cf * CFrame.new(W / 2 + 5, 0, -2)
	b(m, Vector3.new(6, 0.4, 2.6), t * CFrame.new(0, 2.6, 0), WOOD, Enum.Material.WoodPlanks, "Table")
	for _, z in { -2.4, 2.4 } do
		b(m, Vector3.new(6, 0.35, 1), t * CFrame.new(0, 1.5, z), WOOD, Enum.Material.WoodPlanks, "Bench")
	end
	for _, x in { -2.4, 2.4 } do
		b(m, Vector3.new(0.4, 2.6, 0.4), t * CFrame.new(x, 1.3, 0), DARK, Enum.Material.Wood)
	end
end

local function well(m: Instance, cf: CFrame)
	local ring = PropKit.cylinder(m, 3.2, 2.6, cf * CFrame.new(0, 1.3, 0), STONE)
	ring.Material = Enum.Material.Cobblestone
	local water = PropKit.cylinder(m, 2.5, 0.2, cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(50, 110, 150))
	water.Material = Enum.Material.Glass
	for _, x in { -3, 3 } do
		b(m, Vector3.new(0.6, 6.5, 0.6), cf * CFrame.new(x, 3.25, 0), DARK, Enum.Material.Wood)
	end
	deco(b(m, Vector3.new(6.6, 0.5, 0.5), cf * CFrame.new(0, 5.4, 0), DARK, Enum.Material.Wood, "Crank"))
	deco(b(m, Vector3.new(1, 1.1, 1), cf * CFrame.new(0, 4.2, 0), WOOD, Enum.Material.Wood, "Bucket"))
	gable(m, cf, 6, 4, 6.4, Color3.fromRGB(150, 60, 45), 35)
	-- beehives in a row
	for i = 0, 2 do
		local h = cf * CFrame.new(-5 + i * 3.4, 0, 7)
		b(m, Vector3.new(2.2, 0.4, 2.2), h * CFrame.new(0, 0.6, 0), DARK, Enum.Material.Wood)
		b(m, Vector3.new(2, 2.4, 2), h * CFrame.new(0, 2, 0), Color3.fromRGB(240, 196, 70), Enum.Material.WoodPlanks, "Hive")
		b(m, Vector3.new(2.4, 0.4, 2.4), h * CFrame.new(0, 3.4, 0), WHITE, Enum.Material.WoodPlanks)
	end
end

local function clubhouse(m: Instance, cf: CFrame)
	local W, D, H = 18, 11, 8
	local house = cf * CFrame.new(0, 0, 6)
	b(m, Vector3.new(W + 4, 0.6, D + 6), house * CFrame.new(0, 0.3, -2), Color3.fromRGB(200, 190, 170), Enum.Material.WoodPlanks, "Deck")
	for _, e in { { 0, D / 2, W, 0.6 }, { -W / 2, 0, 0.6, D }, { W / 2, 0, 0.6, D } } do
		b(m, Vector3.new(e[3], H, e[4]), house * CFrame.new(e[1], H / 2, e[2]), WHITE, Enum.Material.WoodPlanks, "Wall")
	end
	-- the front: wall with a door and two big windows
	b(m, Vector3.new(W, 2, 0.6), house * CFrame.new(0, H - 1, -D / 2), WHITE, Enum.Material.WoodPlanks)
	for _, x in { -6, 6 } do
		b(m, Vector3.new(4.4, 3.6, 0.3), house * CFrame.new(x, 3.6, -D / 2), Color3.fromRGB(170, 215, 255), Enum.Material.Glass, "Window")
		b(m, Vector3.new(1.8, H - 2, 0.6), house * CFrame.new(x + (if x < 0 then -3.1 else 3.1), (H - 2) / 2, -D / 2), WHITE, Enum.Material.WoodPlanks)
	end
	gable(m, house, W, D, H, Color3.fromRGB(60, 140, 70), 22)
	local sign = b(m, Vector3.new(10, 2, 0.4), house * CFrame.new(0, H + 1.6, -D / 2 - 1), Color3.fromRGB(40, 100, 50), Enum.Material.WoodPlanks, "Sign")
	PropKit.surfaceText(sign, "CLUBHOUSE", Color3.new(1, 1, 1))
	-- the putting green with its flag in front
	local green = cf * CFrame.new(0, 0, -11)
	Ground.disc(green.Position.X, green.Position.Z, 8, Enum.Material.Grass)
	b(m, Vector3.new(0.3, 7, 0.3), green * CFrame.new(2, 3.5, 0), WHITE, Enum.Material.Metal, "FlagPole")
	b(m, Vector3.new(0.1, 1.6, 2.6), green * CFrame.new(2, 6.2, 1.3), Color3.fromRGB(230, 50, 50), Enum.Material.Fabric, "Flag")
	PropKit.cylinder(m, 0.6, 0.1, green * CFrame.new(2, 0.05, 0), Color3.fromRGB(20, 20, 20))
	-- a golf cart
	local cart = cf * CFrame.new(-W / 2 - 4, 0, 0) * CFrame.Angles(0, math.rad(80), 0)
	b(m, Vector3.new(3, 1.2, 5), cart * CFrame.new(0, 1.4, 0), WHITE, Enum.Material.SmoothPlastic, "Cart")
	b(m, Vector3.new(3.2, 0.3, 4), cart * CFrame.new(0, 4.2, 0.3), Color3.fromRGB(40, 120, 60), Enum.Material.Fabric, "Canopy")
	for _, p in { { -1.4, -1.6 }, { 1.4, -1.6 }, { -1.4, 1.6 }, { 1.4, 1.6 } } do
		PropKit.cylinder(m, 0.55, 0.5, cart * CFrame.new(p[1], 0.55, p[2]) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 30, 30))
	end
	for _, z in { -1.4, 1.9 } do
		b(m, Vector3.new(0.25, 2.6, 0.25), cart * CFrame.new(1.4, 2.9, z), DARK, Enum.Material.Metal)
		b(m, Vector3.new(0.25, 2.6, 0.25), cart * CFrame.new(-1.4, 2.9, z), DARK, Enum.Material.Metal)
	end
end

local function windmill(m: Instance, cf: CFrame)
	local tower = cf * CFrame.new(-9, 0, 4)
	local levels = 5
	for i = 0, levels - 1 do
		local w = 9 - i * 1.1
		b(m, Vector3.new(w, 4, w), tower * CFrame.new(0, 2 + i * 4, 0) * CFrame.Angles(0, math.rad(45), 0), if i % 2 == 0 then WHITE else Color3.fromRGB(226, 220, 205), Enum.Material.WoodPlanks, "Tower")
	end
	local capY = levels * 4
	b(m, Vector3.new(5.4, 3, 5.4), tower * CFrame.new(0, capY + 1.5, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(170, 60, 45), Enum.Material.WoodPlanks, "Cap")
	b(m, Vector3.new(3, 1.6, 3), tower * CFrame.new(0, capY + 3.6, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(150, 50, 40), Enum.Material.WoodPlanks, "Cap")
	b(m, Vector3.new(1.6, 4, 0.8), tower * CFrame.new(0, 2, -4.6), DARK, Enum.Material.WoodPlanks, "Door")
	-- the sails: a hub on the front and four lattice blades
	local hub = tower * CFrame.new(0, capY - 1, -4.6)
	PropKit.cylinder(m, 1, 1.4, hub * CFrame.Angles(math.rad(90), 0, 0), DARK)
	for i = 0, 3 do
		local a = math.rad(20 + i * 90)
		local blade = hub * CFrame.Angles(0, 0, a)
		deco(b(m, Vector3.new(0.5, 11, 0.4), blade * CFrame.new(0, 6, -0.6), DARK, Enum.Material.Wood, "Arm"))
		deco(b(m, Vector3.new(2.6, 8.4, 0.2), blade * CFrame.new(1.4, 7, -0.7), Color3.fromRGB(240, 232, 210), Enum.Material.Fabric, "Sail"))
	end
	-- the red barn
	local barn = cf * CFrame.new(10, 0, 6)
	local W, D, H = 14, 16, 9
	for _, e in { { 0, D / 2, W, 0.6 }, { 0, -D / 2, W, 0.6 }, { -W / 2, 0, 0.6, D }, { W / 2, 0, 0.6, D } } do
		b(m, Vector3.new(e[3], H, e[4]), barn * CFrame.new(e[1], H / 2, e[2]), Color3.fromRGB(176, 46, 40), Enum.Material.WoodPlanks, "Wall")
	end
	b(m, Vector3.new(6, 7, 0.4), barn * CFrame.new(0, 3.5, -D / 2 - 0.2), Color3.fromRGB(150, 36, 32), Enum.Material.WoodPlanks, "BarnDoor")
	for _, r in { 45, -45 } do
		deco(b(m, Vector3.new(0.5, 9, 0.2), barn * CFrame.new(0, 3.5, -D / 2 - 0.45) * CFrame.Angles(0, 0, math.rad(r)), WHITE, Enum.Material.WoodPlanks, "Trim"))
	end
	-- the gable roof turned so its ridge runs front to back
	gable(m, barn * CFrame.Angles(0, math.rad(90), 0), D, W, H, Color3.fromRGB(90, 70, 60), 35)
	for i = 0, 2 do
		local bale = barn * CFrame.new(-W / 2 - 3, 1.2, -4 + i * 3.4)
		b(m, Vector3.new(3, 2.4, 2.4), bale, Color3.fromRGB(230, 190, 80), Enum.Material.Fabric, "HayBale")
	end
end

local function gazebo(m: Instance, cf: CFrame)
	local floor = PropKit.cylinder(m, 6.5, 0.8, cf * CFrame.new(0, 0.4, 0), WHITE)
	floor.Material = Enum.Material.WoodPlanks
	for i = 0, 7 do
		local a = i * math.pi / 4
		local p = cf * CFrame.new(math.cos(a) * 5.8, 0, math.sin(a) * 5.8)
		b(m, Vector3.new(0.6, 7.5, 0.6), p * CFrame.new(0, 4.5, 0), WHITE, Enum.Material.WoodPlanks, "Post")
		if i ~= 6 then -- a gap at the front
			local mid = cf * CFrame.Angles(0, -(a + math.pi / 8), 0) * CFrame.new(5.4, 1.6, 0)
			deco(b(m, Vector3.new(0.3, 0.3, 4.4), mid, WHITE, Enum.Material.WoodPlanks, "Rail"))
		end
	end
	-- a stepped round roof with a finial
	for i = 0, 3 do
		local r = 7.4 - i * 1.8
		local disc = PropKit.cylinder(m, r, 0.9, cf * CFrame.new(0, 8.6 + i * 0.9, 0), Color3.fromRGB(235, 130, 170))
		disc.Material = Enum.Material.WoodPlanks
		disc.CanCollide = false
	end
	deco(b(m, Vector3.new(0.6, 1.6, 0.6), cf * CFrame.new(0, 13.2, 0), Color3.fromRGB(255, 215, 90), Enum.Material.Metal, "Finial"))
	-- stone lanterns either side of the way in
	for _, x in { -4, 4 } do
		local l = cf * CFrame.new(x, 0, -9)
		b(m, Vector3.new(1.4, 2.4, 1.4), l * CFrame.new(0, 1.2, 0), STONE, Enum.Material.Slate)
		local lamp = b(m, Vector3.new(1.8, 1.2, 1.8), l * CFrame.new(0, 3, 0), Color3.fromRGB(255, 230, 170), Enum.Material.Neon, "Lamp")
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 150)
		light.Range = 12
		light.Brightness = 0.8
		light.Parent = lamp
		b(m, Vector3.new(2.4, 0.6, 2.4), l * CFrame.new(0, 3.9, 0), STONE, Enum.Material.Slate)
	end
end

-- The swamp pond with a plank bridge over it and a little rowing boat.
local function bridge(m: Instance, cf: CFrame)
	local pond = cf
	Ground.water(pond.Position.X, pond.Position.Z, 34, 20, 3)
	local len = 40
	for i = 0, math.floor(len / 1.4) do
		local z = -len / 2 + i * 1.4
		local arch = math.cos(z / len * math.pi) * 1.6
		b(m, Vector3.new(6, 0.4, 1.2), cf * CFrame.new(0, 0.9 + arch, z) * CFrame.Angles(0, math.rad((i % 3) - 1), 0), Color3.fromRGB(140, 100, 64), Enum.Material.WoodPlanks, "Plank")
	end
	for _, x in { -3.2, 3.2 } do
		for i = 0, 6 do
			local z = -len / 2 + i * len / 6
			local arch = math.cos(z / len * math.pi) * 1.6
			b(m, Vector3.new(0.5, 4 + arch, 0.5), cf * CFrame.new(x, (4 + arch) / 2 - 0.5, z), DARK, Enum.Material.Wood, "Post")
		end
		for i = 0, 5 do
			local z0 = -len / 2 + i * len / 6
			local z1 = z0 + len / 6
			local y0 = math.cos(z0 / len * math.pi) * 1.6 + 3.2
			local y1 = math.cos(z1 / len * math.pi) * 1.6 + 3.2
			local a = Vector3.new(x, y0, z0)
			local bpos = Vector3.new(x, y1, z1)
			local mid = (a + bpos) / 2
			deco(b(m, Vector3.new(0.3, 0.3, (bpos - a).Magnitude), cf * CFrame.lookAt(mid, bpos), WOOD, Enum.Material.Wood, "Rail"))
		end
	end
	-- the boat, floating beside the bridge
	local boat = cf * CFrame.new(9, 0.2, 4) * CFrame.Angles(0, math.rad(25), 0)
	b(m, Vector3.new(3, 0.8, 7), boat, Color3.fromRGB(150, 90, 50), Enum.Material.WoodPlanks, "Boat")
	for _, x in { -1.4, 1.4 } do
		b(m, Vector3.new(0.3, 1, 7), boat * CFrame.new(x, 0.8, 0), Color3.fromRGB(120, 70, 40), Enum.Material.WoodPlanks)
	end
	-- cattails along the shore
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = cf * CFrame.new(math.cos(a) * 19, 0, math.sin(a) * 12)
		for j = 0, 2 do
			local h = 3 + j * 0.7
			local stem = cf.Rotation + (p.Position + Vector3.new(j * 0.5 - 0.5, h / 2, (j % 2) * 0.4))
			deco(b(m, Vector3.new(0.15, h, 0.15), stem, Color3.fromRGB(80, 130, 60), Enum.Material.Grass, "Reed"))
			deco(b(m, Vector3.new(0.35, 0.9, 0.35), stem * CFrame.new(0, h / 2, 0), Color3.fromRGB(100, 62, 36), Enum.Material.Fabric, "Cattail"))
		end
	end
end

local function wagon(m: Instance, cf: CFrame)
	local w = cf * CFrame.Angles(0, math.rad(15), 0)
	b(m, Vector3.new(5, 0.5, 8), w * CFrame.new(0, 2.2, 0), WOOD, Enum.Material.WoodPlanks, "Bed")
	for _, x in { -2.5, 2.5 } do
		b(m, Vector3.new(0.3, 1.4, 8), w * CFrame.new(x, 3.1, 0), DARK, Enum.Material.WoodPlanks, "Side")
	end
	for _, p in { { -2.8, -2.6 }, { 2.8, -2.6 }, { -2.8, 2.6 }, { 2.8, 2.6 } } do
		local wheel = PropKit.cylinder(m, 1.5, 0.4, w * CFrame.new(p[1], 1.5, p[2]) * CFrame.Angles(0, 0, math.rad(90)), DARK)
		wheel.Material = Enum.Material.Wood
	end
	deco(b(m, Vector3.new(0.4, 0.4, 5), w * CFrame.new(0, 1.8, -6), DARK, Enum.Material.Wood, "Shaft"))
	-- the hay heaped on it
	for i = 0, 4 do
		local h = b(m, Vector3.new(4.4 - i * 0.6, 1.2, 7 - i * 1.1), w * CFrame.new(0, 3 + i * 1, 0) * CFrame.Angles(0, math.rad(i * 9), 0), Color3.fromRGB(232, 188, 80), Enum.Material.Fabric, "Hay")
		h.CanCollide = false
	end
	-- a scarecrow on a post
	local s = cf * CFrame.new(-8, 0, 3)
	b(m, Vector3.new(0.5, 7, 0.5), s * CFrame.new(0, 3.5, 0), DARK, Enum.Material.Wood)
	deco(b(m, Vector3.new(6, 0.4, 0.4), s * CFrame.new(0, 5.2, 0), DARK, Enum.Material.Wood))
	b(m, Vector3.new(2.4, 2.8, 1.2), s * CFrame.new(0, 4.6, 0), Color3.fromRGB(70, 110, 170), Enum.Material.Fabric, "Shirt")
	b(m, Vector3.new(1.6, 1.6, 1.6), s * CFrame.new(0, 6.8, 0), Color3.fromRGB(230, 200, 140), Enum.Material.Fabric, "Head")
	b(m, Vector3.new(2.8, 0.3, 2.8), s * CFrame.new(0, 7.7, 0), Color3.fromRGB(200, 160, 70), Enum.Material.Fabric, "HatBrim")
	b(m, Vector3.new(1.5, 1, 1.5), s * CFrame.new(0, 8.3, 0), Color3.fromRGB(200, 160, 70), Enum.Material.Fabric, "Hat")
end

local function lookout(m: Instance, cf: CFrame)
	local H = 15
	for _, p in { { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 } } do
		b(m, Vector3.new(0.9, H + 5, 0.9), cf * CFrame.new(p[1], (H + 5) / 2, p[2]), DARK, Enum.Material.Wood, "Stilt")
	end
	for _, y in { 4, 9 } do
		for _, e in { { 0, -3.5, 7, 0.4 }, { 0, 3.5, 7, 0.4 }, { -3.5, 0, 0.4, 7 }, { 3.5, 0, 0.4, 7 } } do
			deco(b(m, Vector3.new(e[3], 0.4, e[4]), cf * CFrame.new(e[1], y, e[2]), WOOD, Enum.Material.Wood, "Brace"))
		end
	end
	b(m, Vector3.new(9, 0.6, 9), cf * CFrame.new(0, H, 0), WOOD, Enum.Material.WoodPlanks, "Platform")
	for _, e in { { 0, -4.3, 9, 0.3 }, { 0, 4.3, 9, 0.3 }, { -4.3, 0, 0.3, 9 }, { 4.3, 0, 0.3, 9 } } do
		b(m, Vector3.new(e[3], 2.4, e[4]), cf * CFrame.new(e[1], H + 1.5, e[2]), DARK, Enum.Material.WoodPlanks, "Railing")
	end
	gable(m, cf * CFrame.new(0, H + 4.4, 0), 9, 9, 0, Color3.fromRGB(70, 120, 50), 30)
	-- a ladder up the front
	for i = 0, math.floor(H / 1.4) do
		deco(b(m, Vector3.new(2.4, 0.3, 0.3), cf * CFrame.new(0, 0.8 + i * 1.4, -4.6), WOOD, Enum.Material.Wood, "Rung"))
	end
	for _, x in { -1.3, 1.3 } do
		b(m, Vector3.new(0.35, H + 1, 0.35), cf * CFrame.new(x, (H + 1) / 2, -4.6), DARK, Enum.Material.Wood, "LadderRail")
	end
	-- mossy ruin stones beside it
	for i = 0, 4 do
		local s = cf * CFrame.new(8 + (i % 2) * 2, 0, -4 + i * 2)
		b(m, Vector3.new(2.2, 1.8 + (i % 3) * 1.4, 2.2), s * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(i * 23), math.rad((i % 2) * 6)), Color3.fromRGB(120, 130, 110), Enum.Material.Slate, "Ruin")
	end
end

local BUILD = {
	lawn = shed,
	meadow = well,
	golf = clubhouse,
	wheat = windmill,
	blossom = gazebo,
	reeds = bridge,
	prairie = wagon,
	jungle = lookout,
}

function Landmarks.build(parent: Instance, style: string, cf: CFrame)
	local fn = BUILD[style]
	if not fn then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Landmark_" .. style
	fn(m, cf)
	m.Parent = parent
end

return Landmarks
