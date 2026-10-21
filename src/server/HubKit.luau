-- The hub buildings and props in Chop A Forest's style: built from smooth parts with Roblox's realistic materials
-- (round Wood logs, WoodPlanks decks and roofs, Slate stone, Metal), no studs and no voxels. Every model is laid
-- out exactly like the voxel prop it replaces (origin at the middle of its footprint on the ground, front = -Z),
-- so the builders' colliders, sign panels and prompts still line up. server/Models uses HubKit.build(name) as
-- the template for each name in HubKit.NAMES when Config.WORLD_GEN is on.
local HubKit = {}

local M = Enum.Material

-- colours
local LOG = Color3.fromRGB(178, 124, 74)
local LOG2 = Color3.fromRGB(160, 108, 62)
local LOG_END = Color3.fromRGB(222, 182, 124)
local PLANK = Color3.fromRGB(156, 104, 62)
local PLANK_DARK = Color3.fromRGB(96, 62, 38)
local ROOF = Color3.fromRGB(104, 66, 44)
local STONE = Color3.fromRGB(150, 148, 142)
local STONE2 = Color3.fromRGB(122, 120, 116)
local IRON = Color3.fromRGB(52, 52, 58)
local WARM = Color3.fromRGB(255, 196, 112)
local ORANGE = Color3.fromRGB(242, 124, 34)
local YELLOW = Color3.fromRGB(252, 204, 44)
local BLACK = Color3.fromRGB(34, 34, 38)
local RED = Color3.fromRGB(206, 52, 44)
local WHITE = Color3.fromRGB(244, 242, 234)
local LEAF = Color3.fromRGB(70, 150, 60)
local FLOWERS = { Color3.fromRGB(255, 92, 120), Color3.fromRGB(255, 214, 64), Color3.fromRGB(250, 250, 250), Color3.fromRGB(150, 120, 255) }
local GOLD = Color3.fromRGB(255, 196, 46)

type Opts = { collide: boolean?, shape: Enum.PartType?, shadow: boolean? }

-- One part of a model (model-local CFrame). Parts don't collide unless asked: the builders add simple colliders.
local function P(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, o: Opts?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = o ~= nil and o.collide == true
	p.CanQuery = p.CanCollide
	p.CanTouch = false
	p.CastShadow = not (o and o.shadow == false)
	if o and o.shape then
		p.Shape = o.shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) turned to point up
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis turned to run along Z

-- a log: a Wood cylinder from a to b (model-local points), radius r, with light cut ends
local function log(m: Model, a: Vector3, b: Vector3, r: number, color: Color3?, collide: boolean?)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local p = P(m, "Log", Vector3.new(len, r * 2, r * 2), cf, color or LOG, M.Wood, { shape = Enum.PartType.Cylinder, collide = collide })
	-- the cut ends: thin lighter discs
	for _, s in { -1, 1 } do
		P(m, "LogEnd", Vector3.new(0.06, r * 1.8, r * 1.8), cf * CFrame.new(s * (len / 2 + 0.02), 0, 0), LOG_END, M.Wood, { shape = Enum.PartType.Cylinder, shadow = false })
	end
	return p
end

-- a plain cylinder standing up at `pos` (its bottom), radius r, height h
local function post(m: Model, pos: Vector3, r: number, h: number, color: Color3, mat: Enum.Material, collide: boolean?): BasePart
	return P(m, "Post", Vector3.new(h, r * 2, r * 2), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * UP, color, mat, { shape = Enum.PartType.Cylinder, collide = collide })
end

-- a window on a wall facing `out` (unit vector, horizontal): dark frame, warm glass, a cross bar, two shutters
local function window(m: Model, centre: Vector3, out: Vector3, w: number, h: number)
	local cf = CFrame.lookAt(centre, centre + out)
	P(m, "WindowGlass", Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.05), WARM, M.SmoothPlastic, { shadow = false })
	local t = 0.32
	for _, e in { { 0, h / 2, w + t, t }, { 0, -h / 2, w + t, t }, { w / 2, 0, t, h }, { -w / 2, 0, t, h }, { 0, 0, w, 0.16 }, { 0, 0, 0.16, h } } do
		P(m, "WindowFrame", Vector3.new(e[3], e[4], 0.25), cf * CFrame.new(e[1], e[2], -0.18), PLANK_DARK, M.Wood)
	end
	for _, s in { -1, 1 } do
		P(m, "Shutter", Vector3.new(w * 0.42, h + 0.2, 0.18), cf * CFrame.new(s * (w / 2 + w * 0.25), 0, -0.12), PLANK_DARK, M.WoodPlanks)
	end
	-- a tidy flower box under it
	P(m, "FlowerBox", Vector3.new(w + 0.4, 0.6, 0.7), cf * CFrame.new(0, -h / 2 - 0.45, -0.45), PLANK, M.WoodPlanks)
	for i = 0, 4 do
		local x = -w / 2 + 0.3 + i * (w - 0.6) / 4
		P(m, "Flower", Vector3.new(0.55, 0.55, 0.55), cf * CFrame.new(x, -h / 2 - 0.05, -0.45), FLOWERS[(i % #FLOWERS) + 1], M.SmoothPlastic, { shape = Enum.PartType.Ball, shadow = false })
	end
end

-- a small wall lantern facing `out`
local function wallLantern(m: Model, pos: Vector3, out: Vector3)
	local cf = CFrame.lookAt(pos, pos + out)
	P(m, "LanternGlass", Vector3.new(0.6, 0.8, 0.6), cf * CFrame.new(0, 0, -0.5), WARM, M.SmoothPlastic, { shadow = false })
	P(m, "LanternCap", Vector3.new(0.8, 0.2, 0.8), cf * CFrame.new(0, 0.5, -0.5), IRON, M.Metal)
	P(m, "LanternBase", Vector3.new(0.7, 0.15, 0.7), cf * CFrame.new(0, -0.47, -0.5), IRON, M.Metal)
	P(m, "LanternArm", Vector3.new(0.12, 0.12, 0.5), cf * CFrame.new(0, 0.5, -0.15), IRON, M.Metal)
end

-------------------------------------------------------------------------------------------------------------
-- log cabin (the shops). Room inside x -11.9..11.9, z -2.5..9.5, floor top 0.5, walls 12 high (the colliders in
-- PropKit.CABIN_WALLS), a 5-wide door in the front wall (z -3.2), the porch to z -11.9, the shop sign hangs in
-- front of the porch roof at (0, 10.4, -12.3), chimney smoke at (8.5, 23, 7).
-------------------------------------------------------------------------------------------------------------
local function cabinWalls(m: Model)
	local r = 0.66
	for row = 0, 9 do
		local y = 1.2 + row * 1.12
		local c = if row % 2 == 0 then LOG else LOG2
		log(m, Vector3.new(-13.6, y, 10.2), Vector3.new(13.6, y, 10.2), r, c) -- back
		for _, x in { -12.65, 12.65 } do
			log(m, Vector3.new(x, y + 0.56 * (row % 2), -4.3), Vector3.new(x, y + 0.56 * (row % 2), 11.1), r, c) -- sides
		end
		if y > 8.6 then
			log(m, Vector3.new(-13.6, y, -3.2), Vector3.new(13.6, y, -3.2), r, c) -- over the door
		else
			log(m, Vector3.new(-13.6, y, -3.2), Vector3.new(-2.6, y, -3.2), r, c)
			log(m, Vector3.new(2.6, y, -3.2), Vector3.new(13.6, y, -3.2), r, c)
		end
	end
	-- the door frame
	for _, x in { -2.75, 2.75 } do
		P(m, "DoorPost", Vector3.new(0.5, 8.2, 1.5), CFrame.new(x, 4.5, -3.2), PLANK_DARK, M.Wood)
	end
	P(m, "DoorLintel", Vector3.new(6.1, 0.6, 1.6), CFrame.new(0, 8.6, -3.2), PLANK_DARK, M.Wood)
	-- windows: two at the front, one on each side
	for _, x in { -7.8, 7.8 } do
		window(m, Vector3.new(x, 5.6, -3.95), -Vector3.zAxis, 3.6, 3)
	end
	for _, s in { -1, 1 } do
		window(m, Vector3.new(s * 13.4, 5.6, 1), Vector3.new(s, 0, 0), 3.2, 3)
	end
	for _, x in { -3.7, 3.7 } do
		wallLantern(m, Vector3.new(x, 7.4, -3.9), -Vector3.zAxis)
	end
end

local function cabinRoof(m: Model)
	-- the main gable roof, ridge along X over the room's middle
	local rise, run = 6.6, 8.6
	local ang = math.atan2(rise, run)
	local len = math.sqrt(rise * rise + run * run) + 0.6
	local ridgeY, ridgeZ = 18.9, 3.5
	P(m, "Roof", Vector3.new(30, 0.7, len), CFrame.new(0, ridgeY - rise / 2, ridgeZ - run / 2) * CFrame.Angles(-ang, 0, 0), ROOF, M.WoodPlanks)
	P(m, "Roof", Vector3.new(30, 0.7, len), CFrame.new(0, ridgeY - rise / 2, ridgeZ + run / 2) * CFrame.Angles(ang, 0, 0), ROOF, M.WoodPlanks)
	log(m, Vector3.new(-15.2, ridgeY + 0.35, ridgeZ), Vector3.new(15.2, ridgeY + 0.35, ridgeZ), 0.55, LOG2)
	-- the gable ends: wedges of planks
	for _, x in { -12.65, 12.65 } do
		P(m, "Gable", Vector3.new(1.2, rise, run), CFrame.new(x, 12.3 + rise / 2, ridgeZ - run / 2), LOG, M.WoodPlanks)
		P(m, "Gable", Vector3.new(1.2, rise, run), CFrame.new(x, 12.3 + rise / 2, ridgeZ + run / 2) * CFrame.Angles(0, math.pi, 0), LOG, M.WoodPlanks)
	end
	-- the porch roof: a lean-to from the wall down to the porch front, on log posts
	local pr = 1.0
	local pl = 8.4
	P(m, "PorchRoof", Vector3.new(29, 0.5, pl + 0.4), CFrame.new(0, 11.9 - pr / 2, -3.6 - pl / 2) * CFrame.Angles(-math.atan2(pr, pl), 0, 0), ROOF, M.WoodPlanks)
	P(m, "Fascia", Vector3.new(29, 0.7, 0.3), CFrame.new(0, 10.85, -11.95), PLANK_DARK, M.Wood)
	for _, x in { -12.8, -4.4, 4.4, 12.8 } do
		post(m, Vector3.new(x, 0.5, -11.3), 0.42, 10.4, LOG, M.Wood)
	end
	-- the chimney
	P(m, "Chimney", Vector3.new(2.4, 10.4, 2.4), CFrame.new(8.5, 17.2, 7), STONE, M.Slate)
	P(m, "ChimneyCap", Vector3.new(3, 0.6, 3), CFrame.new(8.5, 22.5, 7), STONE2, M.Slate)
end

local function cabinPorch(m: Model)
	P(m, "Foundation", Vector3.new(27.8, 0.6, 15.8), CFrame.new(0, 0.2, 3.5), STONE, M.Slate)
	P(m, "Floor", Vector3.new(24, 0.12, 12.2), CFrame.new(0, 0.56, 3.5), PLANK, M.WoodPlanks)
	P(m, "Porch", Vector3.new(27, 0.5, 8.4), CFrame.new(0, 0.25, -7.8), PLANK, M.WoodPlanks)
	log(m, Vector3.new(-13.8, 0.3, -12), Vector3.new(13.8, 0.3, -12), 0.36, LOG2)
	P(m, "Step", Vector3.new(7.4, 0.26, 1.3), CFrame.new(0, 0.13, -12.7), PLANK, M.WoodPlanks)
	-- railings between the posts (open in the middle for the steps)
	for _, s in { -1, 1 } do
		for _, y in { 1.7, 3.2 } do
			log(m, Vector3.new(s * 4.4, y, -11.3), Vector3.new(s * 12.8, y, -11.3), 0.16, LOG2)
		end
		for i = 1, 5 do
			local x = s * (4.4 + i * 1.4)
			P(m, "Baluster", Vector3.new(0.22, 2.6, 0.22), CFrame.new(x, 1.8, -11.3), LOG2, M.Wood, { shadow = false })
		end
	end
	-- a barrel and a crate on the porch, a rocking-chair-free tidy porch
	P(m, "Barrel", Vector3.new(2.4, 1.7, 1.7), CFrame.new(-10.8, 1.7, -8.6) * UP, PLANK, M.WoodPlanks, { shape = Enum.PartType.Cylinder })
	for _, y in { 1.0, 2.4 } do
		P(m, "BarrelBand", Vector3.new(0.14, 1.8, 1.8), CFrame.new(-10.8, y, -8.6) * UP, IRON, M.Metal, { shape = Enum.PartType.Cylinder })
	end
	P(m, "Crate", Vector3.new(1.8, 1.8, 1.8), CFrame.new(10.8, 1.4, -8.8) * CFrame.Angles(0, 0.2, 0), PLANK, M.WoodPlanks)
end

-- Roblox WedgePart for the gables: swap the placeholder Parts named Gable for wedges with the same CFrame.
local function wedgeify(m: Model)
	for _, p in m:GetChildren() do
		if p:IsA("Part") and p.Name == "Gable" then
			local w = Instance.new("WedgePart")
			w.Name = "Gable"
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.Size = p.Size
			w.CFrame = p.CFrame
			w.Color = p.Color
			w.Material = p.Material
			w.Parent = m
			p:Destroy()
		end
	end
end

local function logCabin(m: Model)
	cabinPorch(m)
	cabinWalls(m)
	cabinRoof(m)
	wedgeify(m)
end

-------------------------------------------------------------------------------------------------------------
-- shredder (7.8 x 11.3 x 14.6, drum toward -Z): orange machine on a dark chassis, hazard-striped hopper with its
-- mouth at (0.3, 8.8, 4.8), the coin chute at the front (out at (0, 1.2, -8.6)).
-------------------------------------------------------------------------------------------------------------
local function hazard(m: Model, cf: CFrame, len: number, h: number, d: number)
	local n = math.max(2, math.floor(len / 0.9))
	for i = 0, n - 1 do
		local x = -len / 2 + (i + 0.5) * len / n
		P(m, "Hazard", Vector3.new(len / n, h, d), cf * CFrame.new(x, 0, 0), if i % 2 == 0 then YELLOW else BLACK, M.SmoothPlastic)
	end
end

local function shredder(m: Model)
	P(m, "Chassis", Vector3.new(7, 1, 13.6), CFrame.new(0, 1.5, -0.7), IRON, M.DiamondPlate)
	for _, x in { -3.7, 3.7 } do
		for _, z in { -5, 3.6 } do
			P(m, "Wheel", Vector3.new(0.9, 2.4, 2.4), CFrame.new(x, 1.2, z), BLACK, M.Rubber, { shape = Enum.PartType.Cylinder })
			P(m, "Hub", Vector3.new(0.95, 1.1, 1.1), CFrame.new(x, 1.2, z), Color3.fromRGB(190, 190, 196), M.Metal, { shape = Enum.PartType.Cylinder })
		end
	end
	P(m, "Body", Vector3.new(6.6, 5, 9.4), CFrame.new(0, 4.5, -2.2), ORANGE, M.SmoothPlastic)
	P(m, "BodyTrim", Vector3.new(6.8, 0.4, 9.6), CFrame.new(0, 7.1, -2.2), Color3.fromRGB(196, 92, 22), M.SmoothPlastic)
	-- the gear on each side
	for _, s in { -1, 1 } do
		local c = CFrame.new(s * 3.35, 4.6, -2.4)
		P(m, "Gear", Vector3.new(0.3, 3.6, 3.6), c, Color3.fromRGB(176, 176, 182), M.Metal, { shape = Enum.PartType.Cylinder })
		P(m, "GearHub", Vector3.new(0.45, 1.2, 1.2), c, IRON, M.Metal, { shape = Enum.PartType.Cylinder })
		for k = 0, 7 do
			local a = k * math.pi / 4
			P(m, "GearTooth", Vector3.new(0.3, 0.7, 0.7), c * CFrame.Angles(a, 0, 0) * CFrame.new(0, 2, 0), Color3.fromRGB(176, 176, 182), M.Metal)
		end
	end
	-- the hopper: a stepped yellow funnel with hazard stripes round the mouth
	P(m, "HopperStand", Vector3.new(6.2, 5, 4.9), CFrame.new(0, 4.5, 4.95), Color3.fromRGB(196, 92, 22), M.SmoothPlastic)
	P(m, "HopperBase", Vector3.new(6.2, 1.6, 5.6), CFrame.new(0, 7.8, 4.6), YELLOW, M.SmoothPlastic)
	P(m, "HopperMouth", Vector3.new(4.6, 0.3, 4), CFrame.new(0.3, 8.65, 4.8), BLACK, M.SmoothPlastic, { shadow = false })
	for _, e in { { 0, 2.95, 7.4 }, { 0, -2.95, 7.4 } } do
		hazard(m, CFrame.new(e[1], 9.05, 4.6 + e[2]), e[3], 0.9, 0.5)
	end
	for _, x in { -3.45, 3.45 } do
		hazard(m, CFrame.new(x, 9.05, 4.6) * CFrame.Angles(0, math.rad(90), 0), 5.4, 0.9, 0.5)
	end
	-- roller teeth in the mouth
	for i = -2, 2 do
		P(m, "Tooth", Vector3.new(0.5, 0.5, 3.4), CFrame.new(i * 0.85 + 0.3, 8.9, 4.8), Color3.fromRGB(200, 200, 206), M.Metal)
	end
	-- the front chute and coin tray
	P(m, "Chute", Vector3.new(4.4, 0.3, 3.6), CFrame.new(0, 3.1, -8) * CFrame.Angles(math.rad(28), 0, 0), Color3.fromRGB(190, 190, 196), M.Metal)
	for _, x in { -2.3, 2.3 } do
		P(m, "ChuteSide", Vector3.new(0.3, 1, 3.6), CFrame.new(x, 3.5, -8) * CFrame.Angles(math.rad(28), 0, 0), IRON, M.Metal)
	end
	P(m, "Tray", Vector3.new(5, 0.4, 2.6), CFrame.new(0, 0.6, -9.6), IRON, M.Metal)
	for k = 0, 9 do
		P(m, "Coin", Vector3.new(0.12, 0.7, 0.7), CFrame.new(-1.8 + (k % 5) * 0.9, 0.9 + (k // 5) * 0.12, -9.2 - (k // 5) * 0.7) * CFrame.Angles(0, 0, math.rad(90)), GOLD, M.SmoothPlastic, { shape = Enum.PartType.Cylinder, shadow = false })
	end
	-- exhaust and warning lamps
	post(m, Vector3.new(2.4, 7, -5.5), 0.35, 4, IRON, M.Metal)
	for _, x in { -2.4, 0 } do
		P(m, "WarnLamp", Vector3.new(0.7, 0.7, 0.7), CFrame.new(x, 7.6, -6.4), ORANGE:Lerp(YELLOW, 0.5), M.SmoothPlastic, { shape = Enum.PartType.Ball })
	end
end

-- sell pad (13 x 1.3 x 13): a plank deck with a hazard-striped edge inside a log frame, like Chop A Forest's drop pad
local function sellPad(m: Model)
	P(m, "Deck", Vector3.new(11.6, 0.6, 11.6), CFrame.new(0, 0.5, 0), PLANK, M.WoodPlanks)
	for _, s in { -1, 1 } do
		hazard(m, CFrame.new(0, 0.82, s * 5.35), 11.6, 0.06, 0.8)
		hazard(m, CFrame.new(s * 5.35, 0.82, 0) * CFrame.Angles(0, math.rad(90), 0), 10, 0.06, 0.8)
	end
	for _, s in { -1, 1 } do
		log(m, Vector3.new(-6.5, 0.45, s * 6.2), Vector3.new(6.5, 0.45, s * 6.2), 0.45, LOG2)
		log(m, Vector3.new(s * 6.2, 0.45, -6.5), Vector3.new(s * 6.2, 0.45, 6.5), 0.45, LOG2)
	end
	for _, x in { -6.2, 6.2 } do
		for _, z in { -6.2, 6.2 } do
			post(m, Vector3.new(x, 0, z), 0.55, 1.4, LOG, M.Wood)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- stalls
-------------------------------------------------------------------------------------------------------------
-- a sloped awning of alternating stripes from (y0 at z0) down to (y1 at z1), x -hw..hw
local function awning(m: Model, hw: number, y0: number, z0: number, y1: number, z1: number, a: Color3, b: Color3)
	local dz, dy = z1 - z0, y1 - y0
	local len = math.sqrt(dz * dz + dy * dy)
	local cf = CFrame.lookAt(Vector3.new(0, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(0, y1, z1))
	local n = math.floor(hw * 2 / 1.5)
	for i = 0, n - 1 do
		local x = -hw + (i + 0.5) * hw * 2 / n
		P(m, "Awning", Vector3.new(hw * 2 / n, 0.3, len), cf * CFrame.new(x, 0, 0), if i % 2 == 0 then a else b, M.Fabric)
		-- the scalloped front edge
		P(m, "AwningFlap", Vector3.new(hw * 2 / n, 0.8, 0.12), CFrame.new(x, y1 - 0.4, z1), if i % 2 == 0 then a else b, M.Fabric, { shadow = false })
	end
end

-- a sign board (dark planks in a log-coloured frame), the game writes on its front
local function board(m: Model, centre: Vector3, w: number, h: number)
	P(m, "SignBoard", Vector3.new(w, h, 0.4), CFrame.new(centre), PLANK_DARK, M.WoodPlanks)
	for _, e in { { 0, h / 2, w + 0.5, 0.35 }, { 0, -h / 2, w + 0.5, 0.35 }, { w / 2, 0, 0.35, h }, { -w / 2, 0, 0.35, h } } do
		P(m, "SignFrame", Vector3.new(e[3], e[4], 0.55), CFrame.new(centre + Vector3.new(e[1], e[2], 0)), LOG, M.Wood)
	end
end

-- bag stand (15 x 11.9 x 8.6): counter x -7..7 (top 3.5), stumps at x -5/0/5 z -4.5 (tops at 2), sign at y 10.6
local function bagStand(m: Model)
	P(m, "BackWall", Vector3.new(14.4, 9.6, 0.5), CFrame.new(0, 4.8, 2.2), PLANK, M.WoodPlanks)
	P(m, "Counter", Vector3.new(14.4, 3.5, 2.4), CFrame.new(0, 1.75, 0.8), PLANK, M.WoodPlanks)
	P(m, "CounterTop", Vector3.new(14.8, 0.3, 2.8), CFrame.new(0, 3.6, 0.8), PLANK_DARK, M.Wood)
	for _, x in { -7.2, 7.2 } do
		post(m, Vector3.new(x, 0, -6.2), 0.36, 9, LOG, M.Wood)
		post(m, Vector3.new(x, 0, 2.2), 0.4, 10.2, LOG, M.Wood)
		wallLantern(m, Vector3.new(x, 7.2, -6.2), -Vector3.zAxis)
	end
	awning(m, 7.8, 9.8, 2.4, 8.4, -6.8, RED, WHITE)
	board(m, Vector3.new(0, 10.6, 1.25), 10, 2.6)
	for _, x in { -5, 0, 5 } do
		post(m, Vector3.new(x, 0, -4.5), 1.3, 2, LOG2, M.Wood)
		P(m, "StumpTop", Vector3.new(0.06, 2.4, 2.4), CFrame.new(x, 2.02, -4.5) * UP, LOG_END, M.Wood, { shape = Enum.PartType.Cylinder })
	end
end

-- rewards stall (19 x 15.5 x 8.6): back wall x -8.5..8.5 z 2.3..3.1 up to 9, posts x +-7.9, counters x +-3.3
-- (top 3.8, z -3.1), REWARDS board across the top (front face z -0.6, y 13.5)
local function rewardsStall(m: Model)
	P(m, "BackWall", Vector3.new(17, 9, 0.8), CFrame.new(0, 4.5, 2.7), PLANK, M.WoodPlanks)
	for _, x in { -7.9, 7.9 } do
		post(m, Vector3.new(x, 0, 0.5), 0.5, 12, LOG, M.Wood)
		post(m, Vector3.new(x, 0, -2.4), 0.36, 9.6, LOG, M.Wood)
	end
	for _, x in { -3.3, 3.3 } do
		P(m, "Counter", Vector3.new(4.2, 3.6, 2.6), CFrame.new(x, 1.8, -3.1), PLANK, M.WoodPlanks)
		P(m, "CounterTop", Vector3.new(4.6, 0.3, 3), CFrame.new(x, 3.75, -3.1), PLANK_DARK, M.Wood)
	end
	awning(m, 9.4, 11.4, 3.2, 9.8, -4.3, Color3.fromRGB(60, 170, 172), WHITE)
	board(m, Vector3.new(0, 13.5, -0.4), 16.6, 3.4)
	-- presents on the counters, a gold star over the board
	for i, x in { -4.4, -2.4, 2.6, 4.2 } do
		local c = ({ RED, Color3.fromRGB(70, 140, 230), Color3.fromRGB(150, 110, 230), Color3.fromRGB(80, 180, 80) })[i]
		P(m, "Present", Vector3.new(1.3, 1.2, 1.3), CFrame.new(x, 4.5, -3.1) * CFrame.Angles(0, 0.3 * i, 0), c, M.SmoothPlastic)
		P(m, "Ribbon", Vector3.new(1.34, 1.24, 0.25), CFrame.new(x, 4.5, -3.1) * CFrame.Angles(0, 0.3 * i, 0), GOLD, M.SmoothPlastic, { shadow = false })
	end
	P(m, "Star", Vector3.new(0.5, 2.2, 2.2), CFrame.new(0, 16.4, -0.4) * CFrame.Angles(0, math.rad(90), 0), GOLD, M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
end

-- the run's garage bay (party_booth, 16.9 x 12.4 x 16.4): open front (-Z), sign on the back wall (y 5..9, z ~6)
local function garageBay(m: Model)
	P(m, "Floor", Vector3.new(15.6, 0.3, 14.6), CFrame.new(0, 0.15, 0), Color3.fromRGB(150, 150, 150), M.Concrete)
	P(m, "BackWall", Vector3.new(15.2, 10, 0.6), CFrame.new(0, 5, 6.7), PLANK, M.WoodPlanks)
	for _, x in { -7.2, 7.2 } do
		post(m, Vector3.new(x, 0, 6.6), 0.55, 10.4, LOG, M.Wood)
		post(m, Vector3.new(x, 0, -6.6), 0.5, 9.6, LOG, M.Wood)
		log(m, Vector3.new(x, 1.3, -6.6), Vector3.new(x, 1.3, 6.6), 0.22, LOG2)
		log(m, Vector3.new(x, 2.5, -6.6), Vector3.new(x, 2.5, 6.6), 0.22, LOG2)
	end
	log(m, Vector3.new(-7.6, 9.6, -6.6), Vector3.new(7.6, 9.6, -6.6), 0.4, LOG2)
	-- a corrugated metal roof sloping to the front
	for i = 0, 8 do
		local x = -8 + i * 2
		P(m, "Roof", Vector3.new(2.05, 0.35, 15.6), CFrame.new(x, 10.4 + (i % 2) * 0.12, 0) * CFrame.Angles(math.rad(-4), 0, 0), Color3.fromRGB(70, 130, 190), M.CorrodedMetal)
	end
	board(m, Vector3.new(0, 7, 6.2), 11, 4.4)
	-- a tyre stack, an oil drum and a workbench at the back corners
	for k = 0, 2 do
		P(m, "Tyre", Vector3.new(0.8, 2.2, 2.2), CFrame.new(5.6, 0.7 + k * 0.82, 4.6) * UP, BLACK, M.Rubber, { shape = Enum.PartType.Cylinder })
	end
	post(m, Vector3.new(-5.6, 0.3, 4.8), 0.9, 2.6, RED, M.Metal)
	P(m, "Bench", Vector3.new(4, 0.3, 1.6), CFrame.new(-2.5, 2.6, 5.6), PLANK, M.WoodPlanks)
	for _, x in { -4.2, -0.8 } do
		P(m, "BenchLeg", Vector3.new(0.3, 2.4, 1.4), CFrame.new(x, 1.4, 5.6), PLANK_DARK, M.Wood)
	end
end

-------------------------------------------------------------------------------------------------------------
-- boards, arch, lamps
-------------------------------------------------------------------------------------------------------------
-- notice board (front face z -0.35): title at y 10.65, body y 3.5..9.7; `top` adds a trophy or a crown
local function noticeBoard(m: Model, top: string)
	P(m, "Board", Vector3.new(10.6, 9, 0.5), CFrame.new(0, 7.2, 0), PLANK_DARK, M.WoodPlanks)
	for _, e in { { 0, 11.85, 11.6, 0.6 }, { 0, 2.55, 11.6, 0.6 }, { 5.55, 7.2, 0.6, 9.9 }, { -5.55, 7.2, 0.6, 9.9 }, { 0, 9.9, 10.6, 0.25 } } do
		P(m, "Frame", Vector3.new(e[3], e[4], 0.7), CFrame.new(e[1], e[2], 0), LOG, M.Wood)
	end
	for _, x in { -5.9, 5.9 } do
		post(m, Vector3.new(x, 0, 0), 0.45, 13, LOG2, M.Wood)
		P(m, "Foot", Vector3.new(1.6, 0.8, 1.6), CFrame.new(x, 0.4, 0), STONE, M.Slate)
	end
	-- a little roof
	for _, s in { -1, 1 } do
		P(m, "Roof", Vector3.new(13, 0.35, 1.6), CFrame.new(0, 13.2, s * 0.65) * CFrame.Angles(s * math.rad(28), 0, 0), ROOF, M.WoodPlanks)
	end
	if top == "trophy" then
		P(m, "TrophyBase", Vector3.new(1.6, 0.6, 1.2), CFrame.new(0, 13.8, 0), PLANK_DARK, M.Wood)
		P(m, "TrophyStem", Vector3.new(0.9, 0.5, 0.5), CFrame.new(0, 14.5, 0) * UP, GOLD, M.Metal, { shape = Enum.PartType.Cylinder })
		P(m, "TrophyCup", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 15.5, 0), GOLD, M.Metal, { shape = Enum.PartType.Ball })
	else
		for i = -2, 2 do
			P(m, "CrownSpike", Vector3.new(0.4, 0.9 + (2 - math.abs(i)) * 0.2, 0.4), CFrame.new(i * 0.6, 14.2, 0), GOLD, M.Metal)
		end
		P(m, "CrownBand", Vector3.new(3.2, 0.5, 0.6), CFrame.new(0, 13.8, 0), GOLD, M.Metal)
	end
end

-- welcome arch (24 wide, 21 high): two big log posts on stone feet, a log beam, a sign board centred at y 14.7
-- (front face z -0.7; server/HubDressing puts the text just in front of it), a plank roof and two lanterns hanging under the beam
local function welcomeArch(m: Model)
	for _, x in { -11.5, 11.5 } do
		P(m, "Foot", Vector3.new(4, 1.6, 4), CFrame.new(x, 0.8, 0), STONE, M.Slate, { collide = false })
		P(m, "FootCap", Vector3.new(3.4, 0.5, 3.4), CFrame.new(x, 1.85, 0), STONE2, M.Slate)
		post(m, Vector3.new(x, 2.1, 0), 1.15, 15.4, LOG, M.Wood)
	end
	log(m, Vector3.new(-14.5, 12, 0), Vector3.new(14.5, 12, 0), 0.9, LOG2)
	log(m, Vector3.new(-14.5, 17.4, 0), Vector3.new(14.5, 17.4, 0), 0.9, LOG2)
	P(m, "Board", Vector3.new(18.4, 4.4, 0.5), CFrame.new(0, 14.7, -0.45), PLANK_DARK, M.WoodPlanks)
	for _, x in { -9.4, 9.4 } do
		P(m, "BoardEdge", Vector3.new(0.5, 4.6, 0.7), CFrame.new(x, 14.7, -0.45), LOG, M.Wood)
	end
	for _, s in { -1, 1 } do
		P(m, "Roof", Vector3.new(31, 0.5, 2.6), CFrame.new(0, 18.9, s * 1.05) * CFrame.Angles(s * math.rad(25), 0, 0), ROOF, M.WoodPlanks)
	end
	for _, x in { -7, 7 } do
		P(m, "Chain", Vector3.new(0.12, 1.1, 0.12), CFrame.new(x, 10.95, -0.9), IRON, M.Metal)
		P(m, "Lantern", Vector3.new(0.9, 1.2, 0.9), CFrame.new(x, 9.8, -0.9), WARM, M.SmoothPlastic, { shadow = false })
		P(m, "LanternCap", Vector3.new(1.2, 0.25, 1.2), CFrame.new(x, 10.5, -0.9), IRON, M.Metal)
		P(m, "LanternBase", Vector3.new(1, 0.2, 1), CFrame.new(x, 9.1, -0.9), IRON, M.Metal)
	end
end

-- lamp post (about 8.8 high): stone foot, wooden post, an iron arm reaching forward (-Z) with a lantern hanging
-- from it; the game puts the warm glass and a light in at (0, 4.75, -2.5)
local function lanternPost(m: Model)
	P(m, "Foot", Vector3.new(1.8, 0.9, 1.8), CFrame.new(0, 0.45, 0), STONE, M.Slate, { collide = true })
	post(m, Vector3.new(0, 0.9, 0), 0.32, 7.9, PLANK_DARK, M.Wood, true)
	P(m, "Cap", Vector3.new(0.9, 0.4, 0.9), CFrame.new(0, 9, 0), IRON, M.Metal)
	P(m, "Arm", Vector3.new(0.22, 0.22, 2.9), CFrame.new(0, 7.3, -1.25), IRON, M.Metal)
	P(m, "Brace", Vector3.new(0.16, 0.16, 1.8), CFrame.new(0, 6.6, -0.6) * CFrame.Angles(math.rad(-40), 0, 0), IRON, M.Metal)
	P(m, "Chain", Vector3.new(0.1, 1.1, 0.1), CFrame.new(0, 6.7, -2.5), IRON, M.Metal)
	P(m, "LanternRoof", Vector3.new(1.7, 0.3, 1.7), CFrame.new(0, 6, -2.5), IRON, M.Metal)
	P(m, "LanternTop", Vector3.new(1, 0.3, 1), CFrame.new(0, 6.25, -2.5), IRON, M.Metal)
	P(m, "LanternBase", Vector3.new(1.5, 0.25, 1.5), CFrame.new(0, 3.85, -2.5), IRON, M.Metal)
	for _, x in { -0.65, 0.65 } do
		for _, z in { -0.65, 0.65 } do
			P(m, "LanternBar", Vector3.new(0.14, 2, 0.14), CFrame.new(x, 4.9, -2.5 + z), IRON, M.Metal)
		end
	end
end

-- retro gas pump (3.7 x 6.3 x 3): red body with a white band, a round glowing globe, a dial and a hose
local function gasPump(m: Model)
	P(m, "Base", Vector3.new(3.4, 0.5, 2.8), CFrame.new(0, 0.25, 0), STONE2, M.Concrete)
	P(m, "Body", Vector3.new(2.8, 4.6, 2.2), CFrame.new(0, 2.8, 0), RED, M.SmoothPlastic)
	P(m, "Band", Vector3.new(2.85, 0.6, 2.25), CFrame.new(0, 3.6, 0), WHITE, M.SmoothPlastic)
	P(m, "Top", Vector3.new(2.2, 2.8, 2.8), CFrame.new(0, 5.1, 0) * CFrame.Angles(0, math.rad(90), 0), RED, M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	P(m, "Globe", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 6.3, 0), WHITE, M.SmoothPlastic, { shape = Enum.PartType.Ball })
	P(m, "Dial", Vector3.new(1.6, 1.2, 0.1), CFrame.new(0, 4.6, -1.12), WHITE, M.SmoothPlastic)
	P(m, "Needle", Vector3.new(0.08, 0.6, 0.05), CFrame.new(0.1, 4.6, -1.18) * CFrame.Angles(0, 0, math.rad(-30)), BLACK, M.SmoothPlastic, { shadow = false })
	P(m, "Hose", Vector3.new(0.25, 2.8, 0.25), CFrame.new(1.55, 2.4, -0.3), BLACK, M.Rubber)
	P(m, "Nozzle", Vector3.new(0.4, 0.9, 0.6), CFrame.new(1.6, 3.8, -0.3), IRON, M.Metal)
end

-------------------------------------------------------------------------------------------------------------
-- dressing
-------------------------------------------------------------------------------------------------------------
local function barrel(m: Model)
	P(m, "Barrel", Vector3.new(2.6, 2, 2), CFrame.new(0, 1.3, 0) * UP, PLANK, M.WoodPlanks, { shape = Enum.PartType.Cylinder, collide = true })
	for _, y in { 0.4, 1.3, 2.2 } do
		P(m, "Band", Vector3.new(0.16, 2.08, 2.08), CFrame.new(0, y, 0) * UP, IRON, M.Metal, { shape = Enum.PartType.Cylinder })
	end
	P(m, "Lid", Vector3.new(0.06, 1.8, 1.8), CFrame.new(0, 2.62, 0) * UP, PLANK_DARK, M.Wood, { shape = Enum.PartType.Cylinder })
end

local function crate(m: Model, cf: CFrame, s: number)
	P(m, "Crate", Vector3.new(s, s, s), cf, PLANK, M.WoodPlanks, { collide = true })
	for _, e in { { 0, s / 2, s + 0.1, 0.25, s + 0.1 }, { 0, -s / 2, s + 0.1, 0.25, s + 0.1 } } do
		P(m, "CrateEdge", Vector3.new(e[3], e[4], e[5]), cf * CFrame.new(e[1], e[2] * 0.95, 0), PLANK_DARK, M.Wood)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			P(m, "CrateCorner", Vector3.new(0.25, s, 0.25), cf * CFrame.new(x * s / 2, 0, z * s / 2), PLANK_DARK, M.Wood)
		end
	end
end

local function crateStack(m: Model)
	crate(m, CFrame.new(-0.95, 0.9, 0), 1.8)
	crate(m, CFrame.new(1.0, 0.8, 0.1) * CFrame.Angles(0, 0.15, 0), 1.6)
	crate(m, CFrame.new(-0.2, 2.6, 0) * CFrame.Angles(0, -0.1, 0), 1.6)
end

local function planter(m: Model)
	P(m, "Box", Vector3.new(4, 1.2, 1.5), CFrame.new(0, 0.6, 0), PLANK, M.WoodPlanks, { collide = true })
	P(m, "Rim", Vector3.new(4.2, 0.2, 1.7), CFrame.new(0, 1.25, 0), PLANK_DARK, M.Wood)
	P(m, "Soil", Vector3.new(3.7, 0.1, 1.2), CFrame.new(0, 1.22, 0), Color3.fromRGB(86, 60, 40), M.Ground)
	for i = 0, 5 do
		local x = -1.5 + i * 0.6
		P(m, "Leaves", Vector3.new(0.7, 0.6, 0.7), CFrame.new(x, 1.5, (i % 2) * 0.3 - 0.15), LEAF, M.Grass, { shape = Enum.PartType.Ball, shadow = false })
		P(m, "Flower", Vector3.new(0.45, 0.45, 0.45), CFrame.new(x, 1.95, (i % 2) * 0.3 - 0.15), FLOWERS[(i % #FLOWERS) + 1], M.SmoothPlastic, { shape = Enum.PartType.Ball, shadow = false })
	end
end

local function bench(m: Model)
	for k = 0, 2 do
		P(m, "Seat", Vector3.new(6, 0.22, 0.42), CFrame.new(0, 1.45, -0.45 + k * 0.48), PLANK, M.WoodPlanks, { collide = k == 1 })
	end
	for k = 0, 1 do
		P(m, "Back", Vector3.new(6, 0.42, 0.18), CFrame.new(0, 2.15 + k * 0.6, 0.72) * CFrame.Angles(math.rad(-10), 0, 0), PLANK, M.WoodPlanks)
	end
	for _, x in { -2.5, 2.5 } do
		P(m, "Leg", Vector3.new(0.25, 1.4, 1.5), CFrame.new(x, 0.7, 0.05), IRON, M.Metal)
		P(m, "BackLeg", Vector3.new(0.25, 1.6, 0.2), CFrame.new(x, 2.3, 0.75), IRON, M.Metal)
	end
end

local function hayBale(m: Model)
	P(m, "Hay", Vector3.new(6, 4, 4), CFrame.new(0, 2, 0), Color3.fromRGB(226, 190, 92), M.Fabric, { collide = true })
	for _, x in { -1.6, 1.6 } do
		P(m, "Strap", Vector3.new(0.3, 4.06, 4.06), CFrame.new(x, 2, 0), Color3.fromRGB(150, 110, 60), M.Fabric)
	end
end

local function mowerStatue(m: Model)
	P(m, "Plinth", Vector3.new(7, 1, 7), CFrame.new(0, 0.5, 0), STONE2, M.Slate, { collide = true })
	P(m, "Plinth2", Vector3.new(5.4, 2.4, 5.4), CFrame.new(0, 2.2, 0), STONE, M.Slate, { collide = true })
	P(m, "Plinth3", Vector3.new(6, 0.4, 6), CFrame.new(0, 3.6, 0), STONE2, M.Slate)
	-- the golden push mower
	P(m, "Deck", Vector3.new(3.6, 1, 3.4), CFrame.new(0, 4.6, 0), GOLD, M.Metal)
	P(m, "Motor", Vector3.new(1.8, 1.4, 1.8), CFrame.new(0, 5.6, -0.2) * UP, GOLD, M.Metal, { shape = Enum.PartType.Cylinder })
	for _, x in { -1.9, 1.9 } do
		for _, z in { -1.3, 1.3 } do
			P(m, "Wheel", Vector3.new(0.4, 1.3, 1.3), CFrame.new(x, 4.4, z), GOLD:Lerp(Color3.new(0, 0, 0), 0.25), M.Metal, { shape = Enum.PartType.Cylinder })
		end
	end
	for _, x in { -1.3, 1.3 } do
		P(m, "Handle", Vector3.new(0.22, 0.22, 4.4), CFrame.new(x, 6.6, 3.2) * CFrame.Angles(math.rad(-45), 0, 0), GOLD, M.Metal)
	end
	P(m, "Grip", Vector3.new(3, 0.3, 0.3), CFrame.new(0, 8.15, 4.75), GOLD, M.Metal)
end

-------------------------------------------------------------------------------------------------------------
local BUILDERS: { [string]: (Model) -> () } = {
	log_cabin = logCabin,
	shredder = shredder,
	sell_pad = sellPad,
	bag_stand = bagStand,
	rewards_stall = rewardsStall,
	party_booth = garageBay,
	leaderboard = function(m)
		noticeBoard(m, "crown")
	end,
	trophy_board = function(m)
		noticeBoard(m, "trophy")
	end,
	welcome_arch = welcomeArch,
	lantern_post = lanternPost,
	gas_pump = gasPump,
	barrel = barrel,
	crate_stack = crateStack,
	planter = planter,
	bench = bench,
	hay_bale = hayBale,
	mower_statue = mowerStatue,
}

HubKit.NAMES = {}
for name in BUILDERS do
	table.insert(HubKit.NAMES, name)
end

-- A fresh template Model for `name` (pivot at the origin), or nil if HubKit doesn't make it.
function HubKit.build(name: string): Model?
	local f = BUILDERS[name]
	if not f then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = name
	f(m)
	m.WorldPivot = CFrame.new()
	return m
end

return HubKit
