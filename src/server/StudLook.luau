--!strict
-- STUD LOOK (7 Nov 2026, owner, with a TikTok of another Roblox game: "Waarom is onze wereld niet net als dit kwa
-- kwaliteit", then "ik bedoel meer de style van de texturen enzo", and for a start "Eerst 1 gebied als test").
-- The classic Roblox toy-brick look: every part plain Plastic with studs on its top and sides, in its own colour; no
-- pixel textures, no realistic grass. On the run's copy of the world (server/RunWorld.build, near the end) in the
-- areas listed in Config.STUD_LOOK.areas, and on every part added there later (the mowed lawn, stubble, regrown
-- grass, drops). Meshes (the ForgeGUI buildings, landmarks, archways) keep their own textures: studs only draw on
-- parts. Glowing, glass and see-through parts and anything with a picture or text on it are left alone too.
-- Config.STUD_LOOK = nil (or no areas): the old look everywhere.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config) :: any
local Zones = require(ReplicatedStorage.MowALawn.Zones) :: any

local StudLook = {}

local STUDS = Enum.SurfaceType.Studs
local INLET = Enum.SurfaceType.Inlet
local PLASTIC = Enum.Material.Plastic
local LEAVE: { [Enum.Material]: boolean } = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Metal] = true, -- (lantern posts, rails: they read as iron)
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.Foil] = true,
}

-- which area a spot is in: the one whose middle is nearest for its size (nil past every area's edge); 0 is the
-- Spawn Village (Zones.village)
local function areaAt(p: Vector3): number?
	local best, bestK = nil, math.huge
	local v = Zones.village
	if v and typeof(v.center) == "Vector2" then
		best, bestK = 0, (Vector2.new(p.X, p.Z) - v.center).Magnitude / (v.radius or 124)
	end
	for i, z in Zones.list do
		local c = z.center
		local r = z.radius or 200
		if typeof(c) == "Vector3" then
			local k = (Vector3.new(p.X - c.X, 0, p.Z - c.Z)).Magnitude / r
			if k < bestK then
				best, bestK = i, k
			end
		elseif typeof(c) == "Vector2" then
			local k = (Vector2.new(p.X, p.Z) - c).Magnitude / r
			if k < bestK then
				best, bestK = i, k
			end
		end
	end
	return if bestK <= 1.15 then best else nil
end

local function wanted(): { [number]: boolean }
	local s = Config.STUD_LOOK
	local set: { [number]: boolean } = {}
	if type(s) == "table" and type(s.areas) == "table" then
		for _, a in s.areas do
			if type(a) == "number" then
				set[a] = true
			end
		end
	end
	if type(s) == "table" and s.village == true then
		set[0] = true -- (14:59, owner: "doe dit voor elke area nu") the Spawn Village too
	end
	return set
end

-- one part (true if it took the look)
local function dress(p: BasePart): boolean
	if not (p:IsA("Part") or p:IsA("WedgePart") or p:IsA("CornerWedgePart")) then
		return false -- (meshes and unions: no surfaces)
	end
	if LEAVE[p.Material] or p.Transparency >= 0.9 then
		return false
	end
	if p:FindFirstChildWhichIsA("Decal") or p:FindFirstChildWhichIsA("SurfaceGui") then
		return false -- (signs, faces, pictures)
	end
	p.Material = PLASTIC
	p.MaterialVariant = ""
	if p:IsA("Part") and p.Shape ~= Enum.PartType.Block then
		return true -- (balls and cylinders: plain plastic; studs wrap badly round them)
	end
	p.TopSurface = STUDS
	p.FrontSurface = STUDS
	p.BackSurface = STUDS
	p.LeftSurface = STUDS
	p.RightSurface = STUDS
	p.BottomSurface = INLET
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the trees, bushes and rocks: chunky studded blocks in two or three close tones (the voxel meshes wear a pixel
-- texture), on a square grid like the reference's: a thick square trunk, a big canopy block, smaller blocks round it
-------------------------------------------------------------------------------------------------------------
local C = Color3.fromRGB
local TRUNK = { C(120, 66, 52), C(102, 54, 44) }
local LEAVES = {
	meadow = { C(64, 152, 70), C(48, 128, 60), C(84, 170, 84) },
	wheat = { C(206, 150, 56), C(184, 124, 46), C(222, 172, 72) },
	blossom = { C(246, 156, 196), C(228, 128, 176), C(255, 186, 214) },
	pine = { C(40, 120, 84), C(30, 100, 70), C(54, 140, 96) },
	swamp = { C(96, 128, 60), C(80, 110, 52), C(112, 146, 70) },
	frost = { C(224, 238, 250), C(196, 220, 244), C(240, 248, 255) },
	ember = { C(92, 70, 74), C(74, 56, 60), C(255, 120, 50) },
	isles = { C(170, 130, 240), C(140, 104, 220), C(196, 160, 255) },
}
local ROCK = { C(150, 146, 156), C(126, 122, 134) }

local function block(m: Instance, size: Vector3, cf: CFrame, col: Color3, name: string)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Parent = m
	dress(p)
end

local function tree(parent: Instance, foot: Vector3, h: number, kind: string, rng: Random): Model
	local m = Instance.new("Model")
	m.Name = "StudTree"
	local u = h / 14 -- (the reference's tree: about 14 of these tall)
	local base = CFrame.new(foot) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
	local leaves = LEAVES[kind] or LEAVES.meadow
	local tw = math.max(1, math.floor(2 * u + 0.5))
	local th = 8 * u
	block(m, Vector3.new(tw, th, tw), base * CFrame.new(0, th / 2, 0), TRUNK[1], "Trunk")
	-- a branch block poking out of the trunk
	local side = if rng:NextNumber() < 0.5 then 1 else -1
	block(m, Vector3.new(tw * 1.4, tw * 0.6, tw * 0.6), base * CFrame.new(side * tw * 0.9, th * 0.62, 0), TRUNK[2], "Branch")
	-- the canopy: one big block, a smaller one on top, three round its sides at different heights
	local cw = 7 * u
	local cy = th + 2 * u
	block(m, Vector3.new(cw, 5 * u, cw), base * CFrame.new(0, cy, 0), leaves[1], "Leaves")
	block(m, Vector3.new(cw * 0.62, 3 * u, cw * 0.62), base * CFrame.new(rng:NextNumber(-1, 1) * u, cy + 4 * u, rng:NextNumber(-1, 1) * u), leaves[3], "Leaves")
	for i = 0, 2 do
		local a = i * (math.pi * 2 / 3) + rng:NextNumber(-0.4, 0.4)
		local s = rng:NextNumber(2.8, 3.8) * u
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (cw / 2 + s * 0.2)
		block(m, Vector3.new(s, s * 0.85, s), base * CFrame.new(off.X, cy + rng:NextNumber(-1.8, 1.2) * u, off.Z), leaves[2], "Leaves")
	end
	m.Parent = parent
	return m
end

local function bush(parent: Instance, foot: Vector3, size: Vector3, kind: string, rng: Random): Model
	local m = Instance.new("Model")
	m.Name = "StudBush"
	local leaves = LEAVES[kind] or LEAVES.meadow
	local base = CFrame.new(foot) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
	local w, h = math.max(size.X, size.Z) * 0.7, size.Y * 0.8
	block(m, Vector3.new(w, h, w * 0.85), base * CFrame.new(0, h / 2, 0), leaves[1], "Leaves")
	block(m, Vector3.new(w * 0.55, h * 0.75, w * 0.55), base * CFrame.new(w * 0.45, h * 0.375, w * 0.2), leaves[2], "Leaves")
	m.Parent = parent
	return m
end

local function rock(parent: Instance, foot: Vector3, size: Vector3, rng: Random): Model
	local m = Instance.new("Model")
	m.Name = "StudRock"
	local base = CFrame.new(foot) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
	local w, h = math.max(size.X, size.Z) * 0.75, size.Y * 0.8
	block(m, Vector3.new(w, h, w * 0.8), base * CFrame.new(0, h / 2, 0), ROCK[1], "Rock")
	block(m, Vector3.new(w * 0.5, h * 0.6, w * 0.5), base * CFrame.new(-w * 0.45, h * 0.3, w * 0.25), ROCK[2], "Rock")
	m.Parent = parent
	return m
end

-- the voxel nature meshes (Tree_<area>_n, Bush_<area>, Rock_<area>[_big]) in the wanted areas, swapped for blocks
local function swapNature(w: Instance, areas: { [number]: boolean }): number
	local rng = Random.new(1107)
	local n = 0
	local list = {}
	for _, d in w:GetDescendants() do
		if d:IsA("MeshPart") then
			local what, kind = string.match(d.Name, "^(%a+)_(%a+)")
			if (what == "Tree" or what == "Bush" or what == "Rock") and kind then
				local a = areaAt(d.Position)
				if a and areas[a] then
					table.insert(list, { d = d, what = what, kind = kind })
				end
			end
		end
	end
	for _, it in list do
		local d = it.d :: MeshPart
		local foot = d.Position - Vector3.new(0, d.Size.Y / 2, 0)
		local parent = d.Parent :: Instance
		if it.what == "Tree" then
			tree(parent, foot, d.Size.Y, it.kind, rng)
		elseif it.what == "Bush" then
			bush(parent, foot, d.Size, it.kind, rng)
		else
			rock(parent, foot, d.Size, rng)
		end
		d:Destroy()
		n += 1
		if n % 40 == 0 then
			task.wait()
		end
	end
	return n
end

-- (below: the round stones)
local studRoundsIn: (Instance, { [number]: boolean }) -> number
local isDisc: (Instance) -> boolean
local studDisc: (Part) -> number

-- The world `w` (the run's copy): every part in the wanted areas now, and what's added there from now on.
-- Returns how many parts took the look.
function StudLook.apply(w: Instance): number
	local areas = wanted()
	if next(areas) == nil then
		return 0
	end
	-- (7 Nov 14:05, owner: "Revert alle bomen terug": the voxel trees, bushes and rocks stay; the block versions only
	-- with Config.STUD_LOOK.trees = true)
	if Config.STUD_LOOK.trees == true then
		local nNature = swapNature(w, areas)
		print(("[StudLook] %d voxel trees, bushes and rocks rebuilt in studded blocks"):format(nNature))
	end
	local n = 0
	for i, d in w:GetDescendants() do
		if d:IsA("BasePart") then
			local a = areaAt(d.Position)
			if a and areas[a] and dress(d) then
				n += 1
			end
		end
		if i % 4000 == 0 then
			task.wait()
		end
	end
	-- (14:59) the round stones with studs, as in the lobby
	local okRound, rounds = pcall(studRoundsIn, w, areas)
	if okRound then
		print(("[StudLook] the run's round stones: %d studded slices"):format(rounds))
	else
		warn("[StudLook] the run's round stones: " .. tostring(rounds))
	end
	w.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			-- (a moment later: whoever made it is done setting its material and colour by then)
			task.defer(function()
				local built = d.Parent and d:FindFirstAncestorWhichIsA("Model")
				while built and built:GetAttribute("StudBuilt") ~= true do
					built = built.Parent and built.Parent:FindFirstAncestorWhichIsA("Model") or nil
				end
				if d.Parent and not built then -- (a model built in studs already keeps its own look)
					local a = areaAt(d.Position)
					if a and areas[a] then
						dress(d)
						-- (14:59) a round stone made later (the boss arenas' floors are built after the world)
						if isDisc(d) then
							studDisc(d :: Part)
						end
					end
				end
			end)
		end
	end)
	return n
end

-------------------------------------------------------------------------------------------------------------
-- the lobby's grass floor (7 Nov 14:43, owner: "the grass"). It's Terrain, and Terrain takes no studs, so the grass
-- on the island's top is laid again in studded blocks: a 4 x 4 column on every Terrain cell whose top is grass, its
-- top where the grass was (in half-stud steps, a tenth lower so the paving's beds lying on it stay on top), in mowed
-- stripes; the Terrain in those columns is lowered out of sight under them (its grass blades would poke through).
-- At runtime only: the saved map keeps its Terrain.
-------------------------------------------------------------------------------------------------------------
local GRASS_A = C(100, 182, 56) -- the lobby's Terrain grass (server/Ground)
local GRASS_B = C(88, 166, 48) -- the darker stripe
local CELL = 4 -- a Terrain cell
local REACH = 200 -- how far from the middle to look (the island's grass is within about 130)
local DEPTH = 8 -- how deep a column goes (its studded sides show as steps at the rim)
local STRIPE = 8 -- studs per mowed stripe
-- what gets covered: the island's top is Grass and LeafyGrass, with Ground / Mud worn spots; all one lawn in studs
-- (the dirt left showing between the blocks read as holes)
local COVER: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
}

local function studGrass(w: Instance): number
	local terrain = workspace.Terrain
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { terrain }
	-- 1) every cell of the island's top, and how high: the grass sets the island's box, the worn spots and the other
	-- grass count inside it (the side isles' grounds stay as they are)
	local found = {}
	local gx0, gx1, gz0, gz1 = math.huge, -math.huge, math.huge, -math.huge
	for x = -REACH, REACH - CELL, CELL do
		for z = -REACH, REACH - CELL, CELL do
			local hit = workspace:Raycast(Vector3.new(x + CELL / 2, 150, z + CELL / 2), Vector3.new(0, -300, 0), rp)
			if hit and COVER[hit.Material] and hit.Position.Y > -40 and hit.Position.Y < 6 then
				table.insert(found, { x = x, z = z, y = hit.Position.Y })
				if hit.Material == Enum.Material.Grass then
					gx0, gx1 = math.min(gx0, x), math.max(gx1, x)
					gz0, gz1 = math.min(gz0, z), math.max(gz1, z)
				end
			end
		end
	end
	local tops: { [number]: { [number]: number } } = {} -- [z][x] = the column's top
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, c in found do
		if c.x >= gx0 - 8 and c.x <= gx1 + 8 and c.z >= gz0 - 8 and c.z <= gz1 + 8 then
			local row = tops[c.z] or {}
			tops[c.z] = row
			row[c.x] = math.floor(c.y * 2 + 0.5) / 2 - 0.1
			minX, maxX = math.min(minX, c.x), math.max(maxX, c.x)
			minZ, maxZ = math.min(minZ, c.z), math.max(maxZ, c.z)
		end
	end
	if minX > maxX then
		return 0
	end
	-- 2) the blocks: a row's neighbours at the same height are one long block
	local folder = Instance.new("Folder")
	folder.Name = "StudGrass"
	local n = 0
	for z, row in tops do
		local xs = {}
		for x in row do
			table.insert(xs, x)
		end
		table.sort(xs)
		local i = 1
		while i <= #xs do
			local x0, top = xs[i], row[xs[i]]
			local j = i
			while j < #xs and xs[j + 1] == xs[j] + CELL and row[xs[j + 1]] == top do
				j += 1
			end
			local len = (j - i + 1) * CELL
			local p = Instance.new("Part")
			p.Name = "Grass"
			p.Anchored = true
			p.Size = Vector3.new(len, DEPTH, CELL)
			p.CFrame = CFrame.new(x0 + len / 2, top - DEPTH / 2, z + CELL / 2)
			p.Color = if (z // STRIPE) % 2 == 0 then GRASS_A else GRASS_B
			p.Parent = folder
			dress(p)
			n += 1
			i = j + 1
		end
	end
	folder.Parent = w
	-- 3) the Terrain in those columns goes down out of sight (it draws its surface ~2 studs over its fill's top)
	local lo, hi = -64, 24
	local region = Region3.new(Vector3.new(minX, lo, minZ), Vector3.new(maxX + CELL, hi, maxZ + CELL))
	local mats, occ = terrain:ReadVoxels(region, CELL)
	local size = mats.Size
	for xi = 1, size.X do
		local x = minX + (xi - 1) * CELL
		for zi = 1, size.Z do
			local z = minZ + (zi - 1) * CELL
			local top = tops[z] and tops[z][x]
			if top then
				local from = math.floor((top - 2) / CELL) * CELL
				for yi = 1, size.Y do
					if lo + (yi - 1) * CELL >= from then
						mats[xi][yi][zi] = Enum.Material.Air
						occ[xi][yi][zi] = 0
					end
				end
			end
		end
	end
	terrain:WriteVoxels(region, CELL, mats, occ)
	return n
end

-------------------------------------------------------------------------------------------------------------
-- the lobby's round paving (7 Nov 14:52, owner: "Make the circle stones also like how u did the bricks"). Studs
-- don't draw on a cylinder, so every flat disc in World.Paving is laid again as a fan of thin wedges (two right
-- triangles per slice, studs on their faces): the same circle, size, height and colour, with studs. The disc itself
-- stays, hidden.
-------------------------------------------------------------------------------------------------------------
-- (15:24, owner: "de boss arenas te bright vooral bij de eerste") an arena's floor in studded plastic reads far brighter
-- than its old grass / stone material did (Sunny Meadow's was a 140-stud sheet of lime): an arena's discs come out
-- calmer, a fifth less light and a little less colour
local function calmer(c: Color3): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * 0.85, v * 0.78)
end

-- A big disc (an arena's floor, 32+ across): its middle again in straight rows of studded plastic just over the fan,
-- so its studs run in one grid like a baseplate (the fan turns each slice's studs, which swirled across the whole
-- floor); every row stays inside the circle, the fan shows only in the slivers at the edge. Not for a see-through
-- disc or one lying under another (an arena's Rim).
local ROW = 4
local function rows(cyl: Part, col: Color3, m: Model): number
	local r = cyl.Size.Y / 2
	if r < 16 or cyl.Transparency > 0 or cyl.Name == "Rim" then
		return 0
	end
	local pos = cyl.Position
	local top = pos.Y + cyl.Size.X / 2
	local n = 0
	for i = -math.floor(r / ROW), math.floor(r / ROW) - 1 do
		local z0, z1 = i * ROW, (i + 1) * ROW
		local far = math.max(math.abs(z0), math.abs(z1))
		local half = if far < r then math.floor(math.sqrt(r * r - far * far)) else 0
		if half >= 2 then
			local p = Instance.new("Part")
			p.Name = "Row"
			p.Anchored = true
			p.CanCollide = false -- (the fan under it carries the feet)
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size = Vector3.new(half * 2, 0.2, ROW)
			p.CFrame = CFrame.new(pos.X, top + 0.02 - 0.1, pos.Z + (z0 + z1) / 2)
			p.Color = col
			p.Material = PLASTIC
			p.TopSurface = STUDS
			p.BottomSurface = INLET
			p.Parent = m
			n += 1
		end
	end
	return n
end

studDisc = function(cyl: Part): number
	local cf = cyl.CFrame
	local A, B = cf.UpVector, cf.LookVector -- the disc's plane (its axis, RightVector, points up)
	local r = cyl.Size.Y / 2
	local t = cyl.Size.X
	local slices = math.clamp(math.floor(r * 2.4 + 0.5), 12, 40)
	local th = math.pi * 2 / slices
	local h, wid = r * math.cos(th / 2), r * math.sin(th / 2)
	local c = cf.Position
	local col = if cyl:FindFirstAncestor("Arenas") then calmer(cyl.Color) else cyl.Color
	local m = Instance.new("Model")
	m.Name = "StudRound"
	local extra = rows(cyl, col, m)
	for k = 0, slices - 1 do
		local a = (k + 0.5) * th
		local out = A * math.cos(a) + B * math.sin(a)
		local along = -A * math.sin(a) + B * math.cos(a)
		local mid = c + out * h -- the slice's outer edge's middle
		for _, side in { 1, -1 } do
			-- a right triangle: its right angle at `mid`, one leg in to the centre, the other out to the slice's corner
			local tdir = along * side
			local yv, zv = -out, -tdir
			local p = Instance.new("WedgePart")
			p.Name = "Slice"
			p.Anchored = true
			p.CanCollide = cyl.CanCollide
			p.Size = Vector3.new(t, h, wid)
			p.CFrame = CFrame.fromMatrix(mid + yv * (h / 2) + tdir * (wid / 2), yv:Cross(zv), yv, zv)
			p.Color = col
			p.Transparency = cyl.Transparency -- (an arena's faint ring line)
			p.CastShadow = cyl.CastShadow
			p.CanQuery = cyl.CanQuery
			p.CanTouch = cyl.CanTouch
			p.Material = PLASTIC
			p.LeftSurface, p.RightSurface, p.BottomSurface = STUDS, STUDS, STUDS -- (its two faces and the rim)
			p.Parent = m
		end
	end
	m.Parent = cyl.Parent
	cyl.Transparency = 1
	cyl.CanCollide = false
	cyl.CastShadow = false
	return slices * 2 + extra
end

-- a flat round stone: a cylinder lying flat, 4 studs across or more, not glowing, see-through or carrying a picture
isDisc = function(d: Instance): boolean
	if not (d:IsA("Part") and d.Shape == Enum.PartType.Cylinder) then
		return false
	end
	local p = d :: Part
	return p.Transparency < 0.9
		and p.Size.Y >= 4
		and p.Size.X <= 6 -- (a tall column, like an arena's skirt down to the ground, stays round)
		and math.abs(p.CFrame.RightVector.Y) > 0.95
		and not LEAVE[p.Material]
		and p:FindFirstChildWhichIsA("Decal") == nil
		and p:FindFirstChildWhichIsA("SurfaceGui") == nil
end

local function studRounds(w: Instance): number
	local paving = w:FindFirstChild("Paving")
	if not paving then
		return 0
	end
	local n = 0
	for _, d in paving:GetDescendants() do
		if isDisc(d) then
			n += studDisc(d :: Part)
		end
	end
	return n
end

-- (14:59, owner: "doe dit voor elke area nu") the run's round stones in the wanted areas too (plazas, the arenas'
-- floors); a working piece's (MapUnit: the drop-off pads, shops...) are left as they are, its game code may use them
local function inUnit(d: Instance, w: Instance): boolean
	local p = d.Parent
	while p and p ~= w do
		if p:GetAttribute("MapUnit") ~= nil then
			return true
		end
		p = p.Parent
	end
	return false
end

studRoundsIn = function(w: Instance, areas: { [number]: boolean }): number
	local list = {}
	for _, d in w:GetDescendants() do
		if isDisc(d) then
			local a = areaAt((d :: Part).Position)
			if a and areas[a] and not inUnit(d, w) then
				table.insert(list, d)
			end
		end
	end
	local n = 0
	for i, d in list do
		n += studDisc(d :: Part)
		if i % 20 == 0 then
			task.wait()
		end
	end
	return n
end

-- The lobby, the main hub (7 Nov 14:37, owner: "also change the main hub with the things"): every part of its world
-- `w` (server/Lobby.start, after the saved map is in) and what's added there later, the same way as above; the clouds
-- and the floating motes stay soft (studs on a cloud make it a block). The grass floor is Terrain: no studs there,
-- as in the run. On with Config.STUD_LOOK.lobby = true. Returns how many parts took the look.
local LOBBY_SKIP: { [string]: boolean } = { Clouds = true, Motes = true }

function StudLook.applyLobby(w: Instance): number
	local s = Config.STUD_LOOK
	if type(s) ~= "table" or s.lobby ~= true then
		return 0
	end
	local function skip(d: Instance): boolean
		local p = d.Parent
		while p and p ~= w do
			-- (7 Nov) and a model built in studs already (StudWindmill, StudHouse: its smooth roof tiles stay smooth)
			if LOBBY_SKIP[p.Name] or p:GetAttribute("StudBuilt") == true then
				return true
			end
			p = p.Parent
		end
		return false
	end
	local n = 0
	for i, d in w:GetDescendants() do
		if d:IsA("BasePart") and not skip(d) and dress(d) then
			n += 1
		end
		if i % 4000 == 0 then
			task.wait()
		end
	end
	-- (14:52, owner: "the circle stones") the round paving with studs too
	local okRound, rounds = pcall(studRounds, w)
	if okRound then
		print(("[StudLook] the lobby's round paving: %d studded slices"):format(rounds))
	else
		warn("[StudLook] the lobby's round paving: " .. tostring(rounds))
	end
	-- (14:43, owner: "the grass") the grass floor in studded blocks too
	local okGrass, grass = pcall(studGrass, w)
	if okGrass then
		print(("[StudLook] the lobby's grass: %d studded blocks"):format(grass))
	else
		warn("[StudLook] the lobby's grass: " .. tostring(grass))
	end
	w.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			task.defer(function()
				if d.Parent and not skip(d) then
					dress(d)
				end
			end)
		end
	end)
	return n
end

StudLook.areaAt = areaAt

return StudLook
