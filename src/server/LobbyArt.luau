-- The lobby in Chop A Forest's style (Config.WORLD_GEN): a flat island of textured grass with dirt paths between
-- the spawn, the party pads and the cabins, a hedge of bushes and rocks round the plaza, a thick wood of
-- part-built trees all round (server/HubKit), a cliff down to the sea, and WorldGen's lighting.
-- LobbyBuilder calls LobbyArt.build(world) in place of its Terrain ground and forest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)

local LobbyArt = {}

local CELL = 8
local REACH = 216 -- the island's half-size (studs)
local CLEARING = 66 -- the flat plaza's half-size (the fence runs just inside it)
local FLOOR = -24
local SEA = -6

local MEADOW = Zones.list[1].palette
local SAND = Color3.fromRGB(226, 200, 140)
local LAWN = Color3.fromRGB(104, 172, 66) -- Chop A Forest's lawn: Roblox's Grass material in a soft green

local count = 0
local function tick()
	count += 1
	if count % 300 == 0 then
		task.wait()
	end
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, studs: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if studs then Enum.Material.Plastic else Enum.Material.SmoothPlastic
	p.TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	tick()
	return p
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function hash(i: number, j: number, k: number): number
	local n = math.sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453
	return n - math.floor(n)
end

-- the walks across the plaza: spawn -> party pads, and out to the cabins, the rewards stall and the boards
local PATHS = {
	{ Vector2.new(0, -52), Vector2.new(0, 34) },
	{ Vector2.new(-46, -22), Vector2.new(46, -22) },
	{ Vector2.new(0, 26), Vector2.new(-42, 26) }, -- to the rewards stall
	{ Vector2.new(-44, 42), Vector2.new(44, 42) },
}
local function pathDist(p: Vector2): number
	local best = math.huge
	for _, s in PATHS do
		local ab = s[2] - s[1]
		local t = math.clamp((p - s[1]):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (p - (s[1] + ab * t)).Magnitude)
	end
	return best
end

-- Height of the ground at a cell centre (nil = sea). The plaza is flat at 0; outside it the ground rises in
-- 2-stud terraces to the forest, then the island ends in a cliff.
local function heightAt(x: number, z: number): number?
	local d = math.max(math.abs(x), math.abs(z))
	local wob = math.sin(x * 0.031 + 1.3) * 10 + math.cos(z * 0.027 + 0.4) * 10
	if d <= CLEARING then
		return 0
	end
	if d + wob > REACH - 8 then
		return nil
	end
	-- flat grass all the way to the cliff, like Chop A Forest's clearing in the woods (no blocky terraces)
	return 0
end

local function colorAt(x: number, z: number, h: number): (Color3, boolean)
	if h == 0 then
		-- one even lawn (the dirt paths are laid on top: server/HubPaths)
		return LAWN, false
	end
	local base = if (h // 2) % 2 == 0 then LAWN else LAWN:Lerp(MEADOW.ground2, 0.5)
	return base:Lerp(Color3.new(0, 0, 0), math.min(0.2, h * 0.01)), false
end

-- The ground: rows of same-height, same-colour cells merged into long blocks (a studded top on a dirt body).
local function ground(world: Instance)
	local f = Instance.new("Folder")
	f.Name = "Ground"
	f.Parent = world
	local side = MEADOW.ground:Lerp(Color3.fromRGB(70, 46, 30), 0.35):Lerp(Color3.new(0, 0, 0), 0.25)
	local n = math.ceil(REACH / CELL)
	for j = -n, n - 1 do
		local z = (j + 0.5) * CELL
		local runStart, runH, runC, runPath = nil, nil, nil, nil
		local function flush(iEnd: number)
			if runStart == nil then
				return
			end
			local x0 = runStart * CELL
			local x1 = iEnd * CELL
			local w = x1 - x0
			local h = runH :: number
			-- textured grass on top (no studs), dirt or rock below, like Chop A Forest's ground
			local top = block(f, "Floor", Vector3.new(w, 1.2, CELL), CFrame.new((x0 + x1) / 2, h - 0.6, z), runC :: Color3, false)
			top.Material = Enum.Material.Grass
			local body = block(f, "FloorSide", Vector3.new(w, h - 1.2 - FLOOR, CELL), CFrame.new((x0 + x1) / 2, (h - 1.2 + FLOOR) / 2, z), if h > 4 then MEADOW.rock:Lerp(Color3.new(0, 0, 0), 0.1) else side)
			body.Material = if h > 4 then Enum.Material.Slate else Enum.Material.Ground
			runStart = nil
		end
		for i = -n, n do
			local x = (i + 0.5) * CELL
			local h = if i < n then heightAt(x, z) else nil
			local c, isPath = nil, false
			if h then
				c, isPath = colorAt(x, z, h)
			end
			if runStart ~= nil and (h ~= runH or c ~= runC) then
				flush(i)
			end
			if h and runStart == nil then
				runStart, runH, runC, runPath = i, h, c, isPath
			end
		end
	end
	-- the sea all round, and sand under it
	local sea = block(world, "Sea", Vector3.new(1400, 1, 1400), CFrame.new(0, SEA - 0.5, 0), Color3.fromRGB(40, 150, 220))
	sea.Material = Enum.Material.Glass
	sea.Transparency = 0.25
	sea.CanCollide = false
	sea.CastShadow = false
	block(world, "SeaFloor", Vector3.new(1400, 2, 1400), CFrame.new(0, FLOOR - 1, 0), SAND)
end

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include

local function groundY(world: Instance, x: number, z: number): number?
	groundRay.FilterDescendantsInstances = { world:FindFirstChild("Ground") :: Instance }
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0), groundRay)
	return hit and hit.Position.Y
end

-- A tidy wooden fence round the plaza and a thick, even wood of green trees behind it (server/HubKit), pines in
-- the back rows: one palette, like the woods round Chop A Forest's yard.
local function nature(world: Instance)
	local f = Instance.new("Folder")
	f.Name = "Visuals"
	f.Parent = world
	local rng = Random.new(31)
	local HubKit = require(script.Parent.HubKit)
	local e = CLEARING - 2
	for _, side in { { Vector3.new(-e, 0, -e), Vector3.new(e, 0, -e) }, { Vector3.new(e, 0, -e), Vector3.new(e, 0, e) }, { Vector3.new(e, 0, e), Vector3.new(-e, 0, e) }, { Vector3.new(-e, 0, e), Vector3.new(-e, 0, -e) } } do
		HubKit.fence(f, side[1], side[2])
	end
	local step = 15
	for x = -REACH, REACH, step do
		for z = -REACH, REACH, step do
			local px, pz = x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3)
			local d = math.max(math.abs(px), math.abs(pz))
			if d > CLEARING + 7 and d < REACH - 20 then
				local y = groundY(world, px, pz)
				if y then
					local kind = if d > CLEARING + 40 and rng:NextNumber() < 0.45 then "pine" else "meadow"
					HubKit.tree(f, Vector3.new(px, y, pz), rng:NextNumber(1.35, 1.6), kind, rng)
					tick()
				end
			end
		end
	end
end

-- Keep players on the island: invisible walls just inside the cliff.
local function bounds(world: Instance)
	local e = REACH - 30
	for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local size = if s[1] ~= 0 then Vector3.new(2, 80, e * 2) else Vector3.new(e * 2, 80, 2)
		local wall = block(world, "Bound", size, CFrame.new(s[1] * e, 30, s[2] * e), Color3.new(1, 1, 1))
		wall.Transparency = 1
		wall.CastShadow = false
	end
end

function LobbyArt.build(world: Instance)
	workspace.Terrain:Clear()
	ground(world)
	local segments = {}
	for _, s in PATHS do
		table.insert(segments, { a = s[1], b = s[2], width = 12 })
	end
	require(script.Parent.HubPaths).lay(world, segments, 0, 11)
	nature(world)
	bounds(world)
	require(script.Parent.WorldGen).lighting()
end

return LobbyArt
