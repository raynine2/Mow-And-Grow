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

-- which area a spot is in: the one whose middle is nearest for its size (nil past every area's edge)
local function areaAt(p: Vector3): number?
	local best, bestK = nil, math.huge
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
	w.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			-- (a moment later: whoever made it is done setting its material and colour by then)
			task.defer(function()
				if d.Parent then
					local a = areaAt(d.Position)
					if a and areas[a] then
						dress(d)
					end
				end
			end)
		end
	end)
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
			if LOBBY_SKIP[p.Name] then
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
