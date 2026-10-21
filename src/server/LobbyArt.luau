-- The lobby in the generated world's style (Config.WORLD_GEN): instead of the Terrain clearing, a voxel island
-- like the run's valleys. A flat plaza (y = 0, where the lobby buildings stand) with warm studded paths between
-- the spawn, the party pads and the cabins; grass terraces rising in 2-stud steps toward a ring of big voxel
-- trees (server/VoxelModels); a rock cliff down to the sea; the meadow's windmill turning on the hill behind the
-- party pads; bushes, rocks, flowers and grass blades everywhere; WorldGen's lighting.
-- LobbyBuilder calls LobbyArt.build(world) in place of its Terrain ground and forest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)
local VoxelModels = require(script.Parent.VoxelModels)

local LobbyArt = {}

local CELL = 8
local REACH = 216 -- the island's half-size (studs)
local CLEARING = 70 -- the flat plaza's half-size
local FLOOR = -24
local SEA = -6

local MEADOW = Zones.list[1].palette
local SAND = Color3.fromRGB(226, 200, 140)

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
	{ Vector2.new(0, 10), Vector2.new(-48, 24) },
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
	local rise = (d - CLEARING) / 9 + (math.sin(x * 0.05) + math.cos(z * 0.043)) * 1.2
	return math.clamp(math.floor(rise) * 2, 2, 22)
end

local function colorAt(x: number, z: number, h: number): (Color3, boolean)
	if h == 0 then
		-- (the paths themselves are cobblestones laid on top: server/HubPaths)
		return if hash(x // 16, z // 16, 3) < 0.5 then MEADOW.ground else MEADOW.ground2, false
	end
	local base = if (h // 2) % 2 == 0 then MEADOW.ground else MEADOW.ground2
	return base:Lerp(Color3.new(0, 0, 0), math.min(0.25, h * 0.012)), false
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
			local top = block(f, "Floor", Vector3.new(w, 1.2, CELL), CFrame.new((x0 + x1) / 2, h - 0.6, z), runC :: Color3, true)
			top.Material = if runPath then Enum.Material.Plastic else Enum.Material.SmoothPlastic
			top.TopSurface = if runPath then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
			block(f, "FloorSide", Vector3.new(w, h - 1.2 - FLOOR, CELL), CFrame.new((x0 + x1) / 2, (h - 1.2 + FLOOR) / 2, z), if h > 4 then MEADOW.rock:Lerp(Color3.new(0, 0, 0), 0.1) else side)
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

-- Big voxel trees on the terraces all round, bushes and rocks along the plaza's edge, the windmill on the hill.
local function nature(world: Instance)
	local f = Instance.new("Folder")
	f.Name = "Visuals"
	f.Parent = world
	local rng = Random.new(31)
	local kinds = { "meadow", "meadow", "meadow", "blossom", "pine", "wheat" }
	local step = 20
	for x = -REACH, REACH, step do
		for z = -REACH, REACH, step do
			local px, pz = x + rng:NextNumber(-6, 6), z + rng:NextNumber(-6, 6)
			local d = math.max(math.abs(px), math.abs(pz))
			-- keep the windmill's hill open
			local nearMill = Vector2.new(px - 52, pz - 132).Magnitude < 58
			if d > CLEARING + 12 and d < REACH - 22 and not nearMill and rng:NextNumber() < 0.85 then
				local y = groundY(world, px, pz)
				if y then
					local kind = kinds[rng:NextInteger(1, #kinds)]
					local scale = rng:NextNumber(1.0, 1.5) * (if d < CLEARING + 30 then 0.9 else 1.15)
					local name = "Tree_" .. kind .. "_" .. rng:NextInteger(1, 3)
					local foot = Vector3.new(px, y, pz)
					if VoxelModels.place(f, name, foot, { scale = scale, yaw = rng:NextInteger(0, 3) * math.pi / 2 }) then
						VoxelModels.blocker(f, Vector3.new(4.8 * scale, 20 * scale, 4.8 * scale), CFrame.new(foot + Vector3.new(0, 10 * scale, 0)))
					end
					tick()
				end
			end
		end
	end
	-- a hedge of bushes and some rocks round the plaza, with gaps at the paths
	for t = -CLEARING, CLEARING, 9 do
		for _, sideP in { Vector2.new(t, CLEARING + 4), Vector2.new(t, -CLEARING - 4), Vector2.new(CLEARING + 4, t), Vector2.new(-CLEARING - 4, t) } do
			if math.abs(t) > 10 and rng:NextNumber() < 0.8 then
				local y = groundY(world, sideP.X, sideP.Y)
				if y then
					local isRock = rng:NextNumber() < 0.2
					local name = if isRock then "Rock_meadow" .. (if rng:NextNumber() < 0.4 then "_big" else "") elseif rng:NextNumber() < 0.25 then "Bush_blossom" else "Bush_meadow"
					VoxelModels.place(f, name, Vector3.new(sideP.X, y - 0.2, sideP.Y), { scale = rng:NextNumber(0.8, 1.2), yaw = rng:NextInteger(0, 3) * math.pi / 2, collide = true })
				end
			end
		end
	end
	-- the windmill on the hill behind the party pads, sails turning (client/Fx spins parts with Spin)
	local my = groundY(world, 52, 132)
	if my and VoxelModels.has("Landmark_windmill") then
		local k = 1.15
		local foot = Vector3.new(52, my, 132)
		local body = VoxelModels.place(f, "Landmark_windmill", foot, { scale = k, yaw = math.pi + 0.5, collide = true }) :: MeshPart
		local sails = VoxelModels.place(f, "Landmark_windmill_sails", foot, { scale = k })
		if sails then
			sails.CFrame = body.CFrame * CFrame.new(0, -body.Size.Y / 2 + 25.8 * k, 14.4 * k)
			sails:SetAttribute("Spin", 0.5)
			sails:SetAttribute("SpinAxis", "Z")
		end
	end
end

-- Flowers and grass blades on the grass (not on the paths), like the valleys' ground cover.
local FLOWERS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 50), Color3.fromRGB(255, 120, 180), Color3.fromRGB(120, 180, 255) }
local function cover(world: Instance)
	local f = Instance.new("Folder")
	f.Name = "Cover"
	f.Parent = world
	local blade = MEADOW.grass[2]
	for x = -REACH + 4, REACH - 4, 6 do
		for z = -REACH + 4, REACH - 4, 6 do
			local r = hash(x, z, 9)
			if r < 0.42 then
				local px, pz = x + (hash(x, z, 1) - 0.5) * 4, z + (hash(x, z, 2) - 0.5) * 4
				local h = heightAt(px, pz)
				if h and not (h == 0 and pathDist(Vector2.new(px, pz)) < 9) then
					local d = math.max(math.abs(px), math.abs(pz))
					-- keep the plaza around the buildings tidy
					local busy = h == 0 and d < CLEARING - 6 and (math.abs(px) < 14 or pz > 28 or (math.abs(px) > 34 and pz < -4))
					if not busy then
						if r < 0.08 then
							local col = FLOWERS[1 + math.floor(hash(x, z, 4) * #FLOWERS)]
							deco(block(f, "Stem", Vector3.new(0.3, 1.2, 0.3), CFrame.new(px, h + 0.6, pz), Color3.fromRGB(60, 150, 50)))
							deco(block(f, "Flower", Vector3.new(0.9, 0.5, 0.9), CFrame.new(px, h + 1.3, pz), col, true))
						else
							for k = 1, 2 do
								local ox, oz = (hash(x + k, z, 5) - 0.5) * 2, (hash(x, z + k, 6) - 0.5) * 2
								local bh = 0.8 + hash(x, z, 7 + k) * 1.2
								deco(block(f, "Blade", Vector3.new(0.35, bh, 0.35), CFrame.new(px + ox, h + bh / 2, pz + oz), blade:Lerp(Color3.new(1, 1, 0.6), hash(x, z, k) * 0.15)))
							end
						end
					end
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
	cover(world)
	bounds(world)
	require(script.Parent.WorldGen).lighting()
end

return LobbyArt
