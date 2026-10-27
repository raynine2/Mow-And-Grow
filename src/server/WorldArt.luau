-- The art on top of the world's shape (server/WorldGen calls this): big cube-canopy trees making a forest wall
-- around every area, tile patterns and grass tufts on the floors, flowers and rocks, glowing cracks in the ice
-- and the ash, a landmark build per area, and drifting ambient particles (pollen, petals, fireflies, snow,
-- embers...). Everything is chunky blocks in the Catch a Brainrot style: saturated, studded, glowing accents.
-- All decoration goes in World.Visuals.<area name>; it's anchored and never blocks the grass patches.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)
local WorldPlan = require(ReplicatedStorage.MowALawn.WorldPlan)
local Models = require(script.Parent.VoxelModels)

local WorldArt = {}

local SMOOTH = Enum.SurfaceType.Smooth
local STUDS = Enum.SurfaceType.Studs
local GROUND_STICKS = false -- the thin grass sticks standing all over the floor (off: they read as clutter)

local count = 0
local function blk(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, studs: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = if studs then STUDS else SMOOTH
	p.BottomSurface = SMOOTH
	p.Parent = parent
	count += 1
	if count % 500 == 0 then
		task.wait()
	end
	return p
end
WorldArt.blk = blk

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
WorldArt.shade = shade

local function v3(p: Vector2, y: number): Vector3
	return Vector3.new(p.X, y, p.Y)
end

-------------------------------------------------------------------------------------------------------------
-- trees: one look per area
-------------------------------------------------------------------------------------------------------------
local TRUNK = Color3.fromRGB(112, 68, 42)

local FACES = { "TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface" }
-- Studs on every face: the toy-brick grid Catch a Brainrot's leaves and bark show up close.
local function studAll(p: BasePart): BasePart
	for _, f in FACES do
		(p :: any)[f] = STUDS
	end
	p.Material = Enum.Material.Plastic
	return p
end
WorldArt.studAll = studAll

-- A voxel ball: horizontal slices of a sphere on a `v`-stud grid, each slice merged into a few rectangles.
-- `shades` = { dark, mid, light }: the bottom of the ball is dark, the top light; `lift` (0..1) brightens a ball
-- that sits high in the canopy. `half`: only the top half (a bush mound).
local function lump(parent: Instance, c: Vector3, r: number, v: number, shades: { Color3 }, lift: number, half: boolean?, solid: boolean?)
	for y = -r + v / 2, r - v / 2, v do
		if half and y < -v / 2 then
			continue
		end
		local rs = math.sqrt(math.max(0, r * r - y * y))
		local n = math.floor(rs / v + 0.35)
		if n >= 1 then
			local band = math.clamp((y + r) / (2 * r) + lift * 0.35, 0, 1)
			local col = if band > 0.68 then shades[3] elseif band > 0.34 then shades[2] else shades[1]
			local rows = {}
			for k = -n, n - 1 do
				local z = (k + 0.5) * v
				local hw = math.sqrt(math.max(0, rs * rs - z * z))
				local m = math.floor(hw / v + 0.35)
				if m >= 1 then
					table.insert(rows, { z = z, m = m })
				end
			end
			local i = 1
			while i <= #rows do
				local j = i
				while j + 1 <= #rows and rows[j + 1].m == rows[i].m do
					j += 1
				end
				local z0, z1 = rows[i].z - v / 2, rows[j].z + v / 2
				local p = studAll(blk(parent, Vector3.new(rows[i].m * 2 * v, v, z1 - z0), CFrame.new(c + Vector3.new(0, y, (z0 + z1) / 2)), col))
				p.CanCollide = solid == true
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = y > 0
				i = j + 1
			end
		end
	end
end
WorldArt.lump = lump

-- A big tree in the Catch a Brainrot style: a thick trunk with roots and branches, and a canopy of voxel
-- balls (dark underneath, light on top). `fine`: small voxels (near the player); otherwise big voxels (the
-- back rows of the forest, seen from far).
local function roundTree(parent: Instance, at: Vector3, size: number, leaves: { Color3 }, trunk: Color3, R: () -> number, fine: boolean?)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local s = size
	local h = 15 * s
	studAll(blk(m, Vector3.new(4 * s, h, 4 * s), CFrame.new(at + Vector3.new(0, h / 2, 0)), trunk))
	if fine then
		studAll(blk(m, Vector3.new(3 * s, h * 0.5, 3 * s), CFrame.new(at + Vector3.new(1.2 * s, h * 0.72, 0.8 * s)), shade(trunk, 0.88)))
		for k = 1, 4 do
			local a = k * math.pi / 2 + R()
			studAll(deco(blk(m, Vector3.new(2 * s, 2 * s, 5 * s), CFrame.new(at + Vector3.new(math.cos(a) * 2.6 * s, 1 * s, math.sin(a) * 2.6 * s)) * CFrame.Angles(0, -a + math.pi / 2, 0), trunk)))
		end
		for _, b in { { 1, 0.2 }, { -0.8, -0.6 } } do
			local dir = Vector3.new(b[1], 0.9, b[2]).Unit
			local mid = at + Vector3.new(0, h * 0.7, 0) + dir * 4 * s
			studAll(deco(blk(m, Vector3.new(2 * s, 2 * s, 9 * s), CFrame.lookAt(mid, mid + dir), trunk)))
		end
	end
	local shades = { leaves[4], leaves[1], leaves[3] }
	local top = at + Vector3.new(0, h + 4 * s, 0)
	local v = if fine then 1.9 * s else 3.2 * s
	lump(m, top, 8 * s, v, shades, 0.25)
	local balls = if fine then 5 else 3
	for k = 1, balls do
		local a = k / balls * math.pi * 2 + (R() - 0.5) * 0.6
		local dy = (R() * 5 - 3) * s
		lump(m, top + Vector3.new(math.cos(a) * 7 * s, dy, math.sin(a) * 7 * s), (5 + R() * 1.8) * s, v, shades, math.clamp(dy / (6 * s) + 0.2, 0, 1))
	end
	m.Parent = parent
end

-- A pine of stacked square layers, turned against each other (pine forest, frost peaks with snow on top).
local function pineTree(parent: Instance, at: Vector3, size: number, leaves: { Color3 }, snow: boolean, R: () -> number)
	local m = Instance.new("Model")
	m.Name = "Pine"
	local trunkH = 5 * size
	blk(m, Vector3.new(2.4 * size, trunkH, 2.4 * size), CFrame.new(at + Vector3.new(0, trunkH / 2, 0)), Color3.fromRGB(96, 60, 40))
	local y = trunkH
	local layers = 6
	for k = 0, layers - 1 do
		local w = (14 - k * 2) * size
		local h = 3.2 * size
		local c = leaves[1 + (k % 2)]
		studAll(deco(blk(m, Vector3.new(w, h, w), CFrame.new(at + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, (k % 2) * math.rad(45) + R() * 0.1, 0), c)))
		if snow then
			deco(blk(m, Vector3.new(w * 0.8, 0.8 * size, w * 0.8), CFrame.new(at + Vector3.new(0, y + h + 0.4 * size, 0)) * CFrame.Angles(0, (k % 2) * math.rad(45), 0), Color3.fromRGB(245, 250, 255)))
		end
		y += h * 0.85
	end
	deco(blk(m, Vector3.new(2 * size, 3 * size, 2 * size), CFrame.new(at + Vector3.new(0, y + 1.5 * size, 0)), if snow then Color3.fromRGB(255, 255, 255) else leaves[2]))
	m.Parent = parent
end

-- A burnt tree with glowing tips (ember fields).
local function deadTree(parent: Instance, at: Vector3, size: number, R: () -> number)
	local m = Instance.new("Model")
	m.Name = "DeadTree"
	local h = 14 * size
	blk(m, Vector3.new(2.6 * size, h, 2.6 * size), CFrame.new(at + Vector3.new(0, h / 2, 0)), Color3.fromRGB(40, 32, 36))
	for k = 1, 4 do
		local a = k * math.pi / 2 + R()
		local len = (5 + R() * 4) * size
		local y = h * (0.45 + k * 0.12)
		local dir = Vector3.new(math.cos(a), 0.6, math.sin(a)).Unit
		local mid = at + Vector3.new(0, y, 0) + dir * len / 2
		deco(blk(m, Vector3.new(1.4 * size, 1.4 * size, len), CFrame.lookAt(mid, mid + dir), Color3.fromRGB(46, 36, 40)))
		deco(blk(m, Vector3.new(1.6 * size, 1.6 * size, 1.6 * size), CFrame.new(mid + dir * len / 2), Color3.fromRGB(255, 120, 40), Enum.Material.Neon))
	end
	m.Parent = parent
end

-- A crystal "tree" (starlight isles): glowing shards.
local function crystalTree(parent: Instance, at: Vector3, size: number, cols: { Color3 }, R: () -> number)
	local m = Instance.new("Model")
	m.Name = "Crystal"
	for k = 1, 5 do
		local h = (8 + R() * 14) * size
		local w = (2.2 + R() * 2) * size
		local off = Vector3.new(R() * 6 - 3, 0, R() * 6 - 3) * size
		deco(blk(m, Vector3.new(w, h, w), CFrame.new(at + off) * CFrame.Angles(R() * 0.4 - 0.2, R() * 3, R() * 0.4 - 0.2) * CFrame.new(0, h / 2, 0), cols[1 + (k % #cols)], if k % 2 == 0 then Enum.Material.Neon else Enum.Material.Glass))
	end
	m.Parent = parent
end

-- The Blender tree for this area (3 variants), if the models are imported. `size` is the old part-tree size
-- (1.5 - 2.8); the meshes are about 1.6 of those. Quarter-turn yaws keep the voxels on the world grid.
local function meshTree(zi: number, parent: Instance, at: Vector3, size: number, R: () -> number): boolean
	local v = 1 + math.floor(R() * 3) % 3
	local name = "Tree_" .. (Zones.region(zi).id or "meadow") .. "_" .. v -- the village has no id: meadow trees
	if not Models.has(name) then
		name = "Tree_meadow_" .. v
	end
	local scale = size / 1.6
	if not Models.place(parent, name, at, { scale = scale, yaw = math.floor(R() * 4) * math.pi / 2 }) then
		return false
	end
	Models.blocker(parent, Vector3.new(4.8 * scale, 20 * scale, 4.8 * scale), CFrame.new(at + Vector3.new(0, 10 * scale, 0)))
	count += 2
	if count % 500 < 2 then
		task.wait()
	end
	return true
end

local function treeFor(zi: number, parent: Instance, at: Vector3, size: number, R: () -> number, fine: boolean?)
	if meshTree(zi, parent, at, size, R) then
		return
	end
	local def = Zones.region(zi)
	local id = def.id
	if id == "pine" then
		pineTree(parent, at, size, { Color3.fromRGB(34, 110, 80), Color3.fromRGB(46, 134, 96) }, false, R)
	elseif id == "frost" then
		pineTree(parent, at, size, { Color3.fromRGB(70, 120, 150), Color3.fromRGB(90, 146, 176) }, true, R)
	elseif id == "ember" then
		deadTree(parent, at, size, R)
	elseif id == "isles" then
		crystalTree(parent, at, size, { Color3.fromRGB(190, 140, 255), Color3.fromRGB(110, 240, 255), Color3.fromRGB(255, 140, 240) }, R)
	elseif id == "blossom" then
		roundTree(parent, at, size, { Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 176, 214), Color3.fromRGB(255, 214, 234), Color3.fromRGB(226, 110, 160) }, Color3.fromRGB(110, 70, 60), R, fine)
	elseif id == "wheat" then
		roundTree(parent, at, size, { Color3.fromRGB(238, 150, 46), Color3.fromRGB(250, 178, 60), Color3.fromRGB(255, 206, 90), Color3.fromRGB(206, 112, 36) }, TRUNK, R, fine)
	elseif id == "swamp" then
		roundTree(parent, at, size, { Color3.fromRGB(58, 103, 36), Color3.fromRGB(72, 120, 43), Color3.fromRGB(92, 141, 52), Color3.fromRGB(43, 79, 29) }, Color3.fromRGB(80, 60, 50), R, fine)
	else
		roundTree(parent, at, size, { Color3.fromRGB(23, 129, 63), Color3.fromRGB(34, 148, 72), Color3.fromRGB(60, 172, 82), Color3.fromRGB(17, 101, 55) }, TRUNK, R, fine)
	end
end

-------------------------------------------------------------------------------------------------------------
-- landmarks
-------------------------------------------------------------------------------------------------------------
-- Blender landmarks: scale, and how high the foot sits above the ground (the floating rock hangs in the air).
local LANDMARK_MESH = {
	-- (owner, 27 Oct: the ForgeGUI windmill by the camp looked dark and out of place, "remove this or fix it") the
	-- voxel one, a bit smaller and 15 studs further back so its sails clear the Tool Shop's roof
	windmill = { scale = 1.1, shift = Vector3.new(0, 0, 15) },
	silo = { scale = 1.1 },
	cherry = { scale = 1 },
	elderpine = { scale = 1 },
	mushroomhut = { scale = 1 },
	icespire = { scale = 1.2 },
	volcano = { scale = 1.5 },
	floatrock = { scale = 1, lift = 14 },
}

local function meshLandmark(parent: Instance, def: any, at: Vector3): boolean
	local l = def.landmark
	local name = "Landmark_" .. l.kind
	local spec = LANDMARK_MESH[l.kind]
	if not spec or not Models.has(name) then
		return false
	end
	local m = Instance.new("Model")
	m.Name = def.name .. " Landmark"
	at += spec.shift or Vector3.zero
	local body = Models.place(m, name, at + Vector3.new(0, spec.lift or 0, 0), { scale = spec.scale, collide = true }) :: MeshPart
	if l.kind == "windmill" then
		-- the sails hang on the axle at the tower's front and turn (client/Fx spins parts with Spin). A placed
		-- mesh's own +Z is its front (VoxelModels turns imports to face the LookVector), so the axle is at +Z.
		local k = spec.scale
		local axle = body.CFrame * CFrame.new(0, -body.Size.Y / 2 + 25.8 * k, 14.4 * k)
		local sails = Models.place(m, "Landmark_windmill_sails", at, { scale = k })
		if sails then
			sails.CFrame = axle
			sails:SetAttribute("Spin", 0.5)
			sails:SetAttribute("SpinAxis", "Z")
		end
	end
	m.Parent = parent
	return true
end

-- The ForgeGUI landmark for each kind (shared/ForgeModelIds; loaded by server/Models at server start).
local FORGE_LANDMARK: { [string]: string } = {
	windmill = "windmill",
	silo = "lm_wheat",
	cherry = "lm_blossom",
	elderpine = "lm_pine",
	mushroomhut = "lm_swamp",
	icespire = "lm_frost",
	volcano = "lm_ember",
	floatrock = "lm_starlight",
}

-- The area's ForgeGUI landmark standing on the ground at `at` (the Starlight observatory too: it isn't a floating
-- rock), the landmark's height tall and at most 46 studs across (WorldPlan keeps the grass ~34 studs away), its
-- front toward the area's centre.
local function forgeLandmark(parent: Instance, def: any, at: Vector3): Model?
	local l = def.landmark
	local name = FORGE_LANDMARK[l.kind]
	if not name then
		return nil
	end
	local foot = at
	local look = Vector3.new(def.center.X, foot.Y, def.center.Y)
	if (look - foot).Magnitude < 1 then
		look = foot - Vector3.zAxis
	end
	local m = Instance.new("Model")
	m.Name = def.name .. " Landmark"
	local ServerModels = require(script.Parent.Models) -- (required here: Models loads HubKit and VoxelModels)
	if not ServerModels.placeForge(name, m, CFrame.lookAt(foot, look), { height = l.height, width = 46, depth = 46 }) then
		m:Destroy()
		return nil
	end
	m:SetAttribute("Forge", true)
	m.Parent = parent
	return m
end

-- Swap the landmarks of a world saved in the place (built before the ForgeGUI models) for the ForgeGUI ones, on
-- the ground under the old ones. Returns how many were swapped. The world must be in the Workspace.
function WorldArt.forgeLandmarks(world: Instance): number
	local n = 0
	for _, def in Zones.list do
		local l = def.landmark
		local old = l and FORGE_LANDMARK[l.kind] and world:FindFirstChild(def.name .. " Landmark", true)
		if old and old:IsA("Model") and not old:GetAttribute("Forge") then
			local cf, size = old:GetBoundingBox()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { old }
			local top = cf.Position.Y + size.Y / 2 + 10
			local hit = workspace:Raycast(Vector3.new(l.at.X, top, l.at.Y), Vector3.new(0, -(size.Y + 120), 0), params)
			local base = if hit then hit.Position.Y else cf.Position.Y - size.Y / 2
			if forgeLandmark(old.Parent :: Instance, def, v3(l.at, base)) then
				old:Destroy()
				n += 1
			end
		end
	end
	return n
end

local function landmark(parent: Instance, zi: number, base: number)
	local def = Zones.list[zi]
	local l = def.landmark
	local at = v3(l.at, base)
	-- (the windmill is the voxel one now, see LANDMARK_MESH; the other areas keep their ForgeGUI landmarks)
	if (l.kind ~= "windmill" and forgeLandmark(parent, def, at)) or meshLandmark(parent, def, at) then
		return
	end
	local m = Instance.new("Model")
	m.Name = def.name .. " Landmark"
	local accent = def.palette.accent
	local R = WorldPlan.rng(zi * 977)
	if l.kind == "windmill" then
		for k = 0, 5 do
			local w = 14 - k * 1.3
			blk(m, Vector3.new(w, 6, w), CFrame.new(at + Vector3.new(0, 3 + k * 6, 0)), if k % 2 == 0 then Color3.fromRGB(250, 248, 240) else Color3.fromRGB(230, 70, 60))
		end
		blk(m, Vector3.new(10, 5, 10), CFrame.new(at + Vector3.new(0, 38.5, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(200, 50, 50))
		local hub = at + Vector3.new(0, 33, -6.5)
		blk(m, Vector3.new(2.5, 2.5, 2.5), CFrame.new(hub), Color3.fromRGB(90, 60, 40))
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.3
			local cf = CFrame.new(hub) * CFrame.Angles(0, 0, a) * CFrame.new(0, 11, 0)
			blk(m, Vector3.new(4.5, 20, 0.6), cf, Color3.fromRGB(255, 252, 240))
			blk(m, Vector3.new(0.8, 22, 0.8), CFrame.new(hub) * CFrame.Angles(0, 0, a) * CFrame.new(0, 11, -0.4), Color3.fromRGB(120, 80, 50))
		end
		blk(m, Vector3.new(4, 6, 0.6), CFrame.new(at + Vector3.new(0, 3, -6.8)), Color3.fromRGB(110, 70, 40))
	elseif l.kind == "silo" then
		for k = 0, 7 do
			local c = blk(m, Vector3.new(6, 16, 16), CFrame.new(at + Vector3.new(0, 3 + k * 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), if k % 2 == 0 then Color3.fromRGB(220, 70, 60) else Color3.fromRGB(240, 236, 226))
			c.Shape = Enum.PartType.Cylinder
		end
		local dome = blk(m, Vector3.new(16, 16, 16), CFrame.new(at + Vector3.new(0, 48, 0)), Color3.fromRGB(200, 200, 210), Enum.Material.SmoothPlastic)
		dome.Shape = Enum.PartType.Ball
		blk(m, Vector3.new(0.8, 10, 0.8), CFrame.new(at + Vector3.new(0, 60, 0)), Color3.fromRGB(80, 80, 90))
		blk(m, Vector3.new(5, 0.8, 0.8), CFrame.new(at + Vector3.new(0, 64, 0)), accent, Enum.Material.Neon)
		-- the barn beside it
		local barn = at + Vector3.new(20, 0, 6)
		blk(m, Vector3.new(22, 14, 18), CFrame.new(barn + Vector3.new(0, 7, 0)), Color3.fromRGB(200, 56, 48))
		blk(m, Vector3.new(24, 2, 20), CFrame.new(barn + Vector3.new(0, 15, 0)), Color3.fromRGB(250, 246, 236))
		blk(m, Vector3.new(16, 6, 20), CFrame.new(barn + Vector3.new(0, 19, 0)), Color3.fromRGB(150, 40, 36))
		blk(m, Vector3.new(8, 10, 0.6), CFrame.new(barn + Vector3.new(0, 5, -9.2)), Color3.fromRGB(250, 246, 236))
	elseif l.kind == "cherry" then
		blk(m, Vector3.new(7, 30, 7), CFrame.new(at + Vector3.new(0, 15, 0)), Color3.fromRGB(110, 70, 60))
		for _, b in { { 1, 0 }, { -1, 0.5 }, { 0.3, 1 } } do
			local dir = Vector3.new(b[1], 0.7, b[2]).Unit
			local mid = at + Vector3.new(0, 24, 0) + dir * 7
			blk(m, Vector3.new(3, 3, 14), CFrame.lookAt(mid, mid + dir), Color3.fromRGB(110, 70, 60))
		end
		local pinks = { Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 186, 220), Color3.fromRGB(255, 220, 238), Color3.fromRGB(230, 110, 160) }
		for _ = 1, 40 do
			local u = Vector3.new(R() * 2 - 1, R() * 1.5 - 0.5, R() * 2 - 1)
			if u.Magnitude > 1 then
				u = u.Unit
			end
			local s = 7 + R() * 6
			blk(m, Vector3.new(s, s * 0.85, s), CFrame.new(at + Vector3.new(u.X * 18, 40 + u.Y * 10, u.Z * 18)), pinks[1 + math.floor((u.Y + 1) * 1.6) % 4])
		end
	elseif l.kind == "elderpine" then
		pineTree(m, at, 4.2, { Color3.fromRGB(28, 96, 70), Color3.fromRGB(40, 122, 88) }, false, R)
	elseif l.kind == "mushroomhut" then
		local stem = blk(m, Vector3.new(26, 14, 14), CFrame.new(at + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(236, 224, 200))
		stem.Shape = Enum.PartType.Cylinder
		blk(m, Vector3.new(40, 8, 40), CFrame.new(at + Vector3.new(0, 30, 0)), Color3.fromRGB(150, 70, 200))
		blk(m, Vector3.new(30, 6, 30), CFrame.new(at + Vector3.new(0, 37, 0)), Color3.fromRGB(170, 90, 220))
		blk(m, Vector3.new(18, 4, 18), CFrame.new(at + Vector3.new(0, 42, 0)), Color3.fromRGB(190, 110, 235))
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2
			blk(m, Vector3.new(3, 1, 3), CFrame.new(at + Vector3.new(math.cos(a) * 15, 34.5, math.sin(a) * 15)), Color3.fromRGB(255, 255, 255))
		end
		blk(m, Vector3.new(5, 8, 0.6), CFrame.new(at + Vector3.new(0, 4, -7.2)), Color3.fromRGB(90, 60, 50))
		blk(m, Vector3.new(2, 2, 0.6), CFrame.new(at + Vector3.new(4, 9, -7.2)), Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
		-- cauldron
		local caul = at + Vector3.new(12, 0, -12)
		blk(m, Vector3.new(6, 4, 6), CFrame.new(caul + Vector3.new(0, 2, 0)), Color3.fromRGB(40, 40, 50))
		blk(m, Vector3.new(5, 0.4, 5), CFrame.new(caul + Vector3.new(0, 4, 0)), Color3.fromRGB(61, 219, 60), Enum.Material.Neon)
	elseif l.kind == "icespire" then
		for k = 0, 9 do
			local w = 16 - k * 1.4
			local h = 10
			blk(m, Vector3.new(w, h, w), CFrame.new(at + Vector3.new(0, h / 2 + k * 9.4, 0)) * CFrame.Angles(0, k * 0.35, 0), if k % 3 == 0 then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(190, 236, 255), if k % 3 == 0 then Enum.Material.Neon else Enum.Material.Glass).Transparency = if k % 3 == 0 then 0 else 0.15
		end
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2
			local h = 14 + R() * 16
			blk(m, Vector3.new(4, h, 4), CFrame.new(at + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)) * CFrame.Angles(math.cos(a) * 0.3, 0, -math.sin(a) * 0.3) * CFrame.new(0, h / 2, 0), Color3.fromRGB(150, 226, 255), Enum.Material.Glass).Transparency = 0.1
		end
	elseif l.kind == "volcano" then
		for k = 0, 7 do
			local w = 70 - k * 8
			blk(m, Vector3.new(w, 10, w), CFrame.new(at + Vector3.new(0, 5 + k * 10, 0)) * CFrame.Angles(0, k * 0.2, 0), if k % 2 == 0 then Color3.fromRGB(56, 44, 50) else Color3.fromRGB(70, 56, 62))
		end
		blk(m, Vector3.new(12, 2, 12), CFrame.new(at + Vector3.new(0, 81, 0)), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
		for k = 1, 4 do
			local a = k * math.pi / 2 + 0.4
			for s = 0, 6 do
				local r = 6 + s * 4.6
				local y = 80 - s * 10
				blk(m, Vector3.new(3, 2, 5), CFrame.new(at + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(0, -a, 0), Color3.fromRGB(255, 100 + s * 10, 30), Enum.Material.Neon)
			end
		end
	elseif l.kind == "floatrock" then
		local c = at + Vector3.new(0, 40, 0)
		for k = 0, 4 do
			local w = 34 - k * 6
			blk(m, Vector3.new(w, 6, w), CFrame.new(c + Vector3.new(0, -k * 5, 0)) * CFrame.Angles(0, k * 0.4, 0), if k == 0 then Color3.fromRGB(150, 120, 255) else Color3.fromRGB(96, 76, 150))
		end
		blk(m, Vector3.new(9, 9, 9), CFrame.new(c + Vector3.new(0, 10, 0)) * CFrame.Angles(0.6, 0.6, 0), Color3.fromRGB(110, 240, 255), Enum.Material.Neon)
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			blk(m, Vector3.new(4, 4, 4), CFrame.new(c + Vector3.new(math.cos(a) * 26, -6 + R() * 12, math.sin(a) * 26)) * CFrame.Angles(R(), R(), R()), Color3.fromRGB(96, 76, 150))
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = d.Size.Magnitude > 6
		end
	end
	m.Parent = parent
end

-------------------------------------------------------------------------------------------------------------
-- ambient particles: one big emitter per area
-------------------------------------------------------------------------------------------------------------
local AMBIENT = {
	pollen = { color = { Color3.fromRGB(255, 250, 190), Color3.fromRGB(255, 230, 120) }, size = 0.35, rate = 30, life = 7, speed = 0.6, acc = Vector3.new(0, 0.2, 0), glow = 1, up = 3 },
	dust = { color = { Color3.fromRGB(255, 230, 160), Color3.fromRGB(240, 200, 120) }, size = 0.3, rate = 36, life = 8, speed = 1, acc = Vector3.new(0.6, 0.1, 0), glow = 0.6, up = 3 },
	petals = { color = { Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 220, 236) }, size = 0.55, rate = 40, life = 9, speed = 0.8, acc = Vector3.new(0.4, -1.2, 0), glow = 0.2, up = 26 },
	fireflies = { color = { Color3.fromRGB(162, 219, 89), Color3.fromRGB(109, 219, 109) }, size = 0.45, rate = 26, life = 6, speed = 0.5, acc = Vector3.new(0, 0.1, 0), glow = 1, up = 3, blink = true },
	bubbles = { color = { Color3.fromRGB(152, 219, 137), Color3.fromRGB(220, 170, 255) }, size = 0.6, rate = 26, life = 5, speed = 1, acc = Vector3.new(0, 1.2, 0), glow = 0.6, up = 1 },
	snow = { color = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 240, 255) }, size = 0.55, rate = 120, life = 10, speed = 1, acc = Vector3.new(0.3, -3, 0), glow = 0.5, up = 40 },
	embers = { color = { Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 80, 30) }, size = 0.35, rate = 60, life = 6, speed = 1.5, acc = Vector3.new(0, 3, 0), glow = 1, up = 1 },
	sparkles = { color = { Color3.fromRGB(200, 160, 255), Color3.fromRGB(120, 240, 255) }, size = 0.7, rate = 40, life = 4, speed = 0.3, acc = Vector3.zero, glow = 1, up = 6, blink = true },
}

local function ambient(parent: Instance, zi: number)
	local def = Zones.list[zi]
	local a = AMBIENT[def.ambient]
	if not a then
		return
	end
	local p = deco(blk(parent, Vector3.new(def.radius * 1.5, 1, def.radius * 1.5), CFrame.new(v3(def.center, def.base + a.up)), Color3.new(1, 1, 1)))
	p.Name = "Ambient"
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = def.ambient
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(a.color[1], a.color[2])
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, a.size), NumberSequenceKeypoint.new(0.85, a.size), NumberSequenceKeypoint.new(1, 0) })
	if a.blink then
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 1) })
	end
	e.LightEmission = a.glow
	e.LightInfluence = 0
	e.Rate = a.rate
	e.Lifetime = NumberRange.new(a.life * 0.7, a.life)
	e.Speed = NumberRange.new(a.speed * 0.5, a.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = a.acc
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = p
end

-------------------------------------------------------------------------------------------------------------
-- decorate
-------------------------------------------------------------------------------------------------------------
-- `patchFree(p)`: true when p (Vector2) is clear of every grass patch (decoration never sits on the grass).
function WorldArt.decorate(world: Instance, plan: any)
	count = 0
	local visuals = world:FindFirstChild("Visuals") or Instance.new("Folder")
	visuals.Name = "Visuals"
	visuals.Parent = world
	local folders: { [number]: Folder } = {}
	local function folderFor(zi: number): Folder
		local f = folders[zi]
		if not f then
			f = Instance.new("Folder")
			f.Name = if zi == 0 then "Village" else Zones.list[zi].name
			f.Parent = visuals
			folders[zi] = f
		end
		return f
	end
	local function patchFree(p: Vector2, margin: number): boolean
		for _, patch in plan.patches do
			for _, b in patch.blobs do
				if (p - b.at).Magnitude < b.r + margin then
					return false
				end
			end
		end
		return true
	end
	local function onCorridor(p: Vector2): boolean
		for _, cor in plan.corridors do
			local seg = cor.b - cor.a
			local t = math.clamp((p - cor.a):Dot(seg) / seg:Dot(seg), 0, 1)
			if (p - (cor.a + seg * t)).Magnitude < cor.width / 2 + 10 then
				return true
			end
		end
		for _, pad in plan.pads do
			if (p - pad.at).Magnitude < 16 then
				return true
			end
		end
		return false
	end
	local hash = WorldPlan.hash
	local C = Zones.CELL

	-- 1) floor tiles, tufts and flowers on every zone column
	for i = 1, plan.nx do
		for j = 1, plan.nz do
			local c = plan.cells[i][j]
			if c.kind == "zone" and c.region and c.region > 0 then
				local def = Zones.list[c.region]
				local p = plan.centre(i, j)
				local f = folderFor(c.region)
				local r1 = hash(i, j, 11)
				local id = def.id
				if id == "frost" or id == "ember" then
					-- glowing cracks: a short zig-zag from this column
					if r1 < 0.07 then
						local col = if id == "frost" then Color3.fromRGB(70, 230, 255) else Color3.fromRGB(255, 120, 30)
						local at = p
						local a = hash(i, j, 5) * math.pi * 2
						for s = 1, 5 do
							a += (hash(i + s, j, 9) - 0.5) * 1.6
							local len = 3 + hash(i, j + s, 3) * 5
							local nxt = at + Vector2.new(math.cos(a), math.sin(a)) * len
							local ci, cj = plan.cellAt(nxt)
							local oc = plan.get(ci, cj)
							if not oc or oc.kind ~= "zone" or oc.h ~= c.h then
								break
							end
							local mid = (at + nxt) / 2
							deco(blk(f, Vector3.new(0.45, 0.14, len + 0.4), CFrame.lookAt(v3(mid, c.h + 0.07), v3(nxt, c.h + 0.07)), col, Enum.Material.Neon))
							at = nxt
						end
					end
				else
					-- a lighter or darker tile here and there: the ground's pattern
					if r1 < 0.2 then
						local base = if (c.h // Zones.STEP) % 2 == 0 then def.palette.ground else def.palette.ground2
						local k = if hash(i, j, 12) < 0.5 then 1.09 else 0.92
						deco(blk(f, Vector3.new(C, 0.12, C), CFrame.new(v3(p, c.h + 0.06)), shade(base, k)))
					end
					-- ground cover: clumps of thin tall blades all over the floor. Off (owner, 27 Oct: the map felt
					-- cluttered next to Chop A Forest's clean ground; they were ~12,000 loose parts). RunWorld also
					-- clears them from a world saved with them.
					local rc = hash(i, j, 19)
					if GROUND_STICKS and rc < 0.3 and patchFree(p, 0) and not onCorridor(p) then
						local g = def.palette.grass
						local base = Vector2.new(hash(i, j, 30) * 5 - 2.5, hash(i, j, 40) * 5 - 2.5)
						for t = 1, 4 do
							local h = 1.6 + hash(i, j, 20 + t) * 2.4
							local off = base + Vector2.new(hash(i, j, 31 + t) * 1.6 - 0.8, hash(i, j, 41 + t) * 1.6 - 0.8)
							local lean = CFrame.Angles((hash(i, j, 51 + t) - 0.5) * 0.5, hash(i, j, 61 + t) * 3, (hash(i, j, 71 + t) - 0.5) * 0.5)
							deco(blk(f, Vector3.new(0.35, h, 0.35), CFrame.new(v3(p + off, c.h)) * lean * CFrame.new(0, h / 2, 0), shade(g[1 + (t % #g)], 0.62 + hash(i, j, 81 + t) * 0.2)))
						end
					end
					-- flowers
					if r1 > 0.86 and r1 <= 0.93 and id ~= "isles" and patchFree(p, 1) and not onCorridor(p) then
						local cols = if id == "blossom" then { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 120, 190) } elseif id == "swamp" then { Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 255, 255) } else { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 50), Color3.fromRGB(255, 120, 180), Color3.fromRGB(120, 180, 255) }
						local col = cols[1 + math.floor(hash(i, j, 50) * #cols)]
						local off = Vector2.new(hash(i, j, 51) * 5 - 2.5, hash(i, j, 52) * 5 - 2.5)
						local fp = p + off
						deco(blk(f, Vector3.new(1.8, 0.3, 0.6), CFrame.new(v3(fp, c.h + 0.15)), col))
						deco(blk(f, Vector3.new(0.6, 0.3, 1.8), CFrame.new(v3(fp, c.h + 0.15)), col))
						deco(blk(f, Vector3.new(0.6, 0.45, 0.6), CFrame.new(v3(fp, c.h + 0.22)), Color3.fromRGB(255, 196, 30)))
					end
				end
			end
		end
	end
	task.wait()

	-- 1b) voxel bushes along each area's edge, at the foot of the forest
	local BUSH = {
		meadow = { Color3.fromRGB(26, 118, 56), Color3.fromRGB(40, 152, 66), Color3.fromRGB(70, 190, 82) },
		wheat = { Color3.fromRGB(190, 110, 30), Color3.fromRGB(226, 150, 46), Color3.fromRGB(250, 196, 80) },
		blossom = { Color3.fromRGB(60, 140, 76), Color3.fromRGB(80, 170, 90), Color3.fromRGB(255, 170, 214) },
		pine = { Color3.fromRGB(20, 92, 66), Color3.fromRGB(34, 120, 86), Color3.fromRGB(60, 156, 110) },
		swamp = { Color3.fromRGB(46, 76, 30), Color3.fromRGB(70, 104, 42), Color3.fromRGB(110, 140, 60) },
		frost = { Color3.fromRGB(150, 196, 230), Color3.fromRGB(200, 228, 250), Color3.fromRGB(250, 252, 255) },
		ember = { Color3.fromRGB(40, 30, 36), Color3.fromRGB(60, 46, 52), Color3.fromRGB(255, 110, 40) },
		isles = { Color3.fromRGB(100, 70, 200), Color3.fromRGB(150, 110, 240), Color3.fromRGB(110, 230, 255) },
	}
	for i = 1, plan.nx do
		for j = 1, plan.nz do
			local c = plan.cells[i][j]
			if c.kind == "zone" and c.region and c.region > 0 and hash(i, j, 61) < 0.32 then
				local edge = false
				for _, dv in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local o = plan.get(i + dv[1], j + dv[2])
					if o and o.kind == "rock" then
						edge = true
					end
				end
				local p = plan.centre(i, j)
				if edge and patchFree(p, 3) and not onCorridor(p) then
					local id = Zones.list[c.region].id
					local r = 2.4 + hash(i, j, 62) * 1.8
					local yaw = math.floor(hash(i, j, 63) * 4) * math.pi / 2
					if not Models.place(folderFor(c.region), "Bush_" .. id, v3(p, c.h - 0.2), { scale = r / 4.2, yaw = yaw, collide = true }) then
						lump(folderFor(c.region), v3(p, c.h), r, 1.2, BUSH[id] or BUSH.meadow, 0.2, true, true)
					end
				end
			end
		end
	end
	task.wait()

	-- 1c) studded paths from each gate into the middle of its area, with darker border tiles
	local PATH = {
		meadow = Color3.fromRGB(240, 162, 82),
		wheat = Color3.fromRGB(214, 140, 70),
		blossom = Color3.fromRGB(236, 220, 200),
		pine = Color3.fromRGB(150, 130, 110),
		swamp = Color3.fromRGB(140, 104, 70),
		frost = Color3.fromRGB(170, 214, 250),
		ember = Color3.fromRGB(46, 40, 44),
		isles = Color3.fromRGB(200, 180, 255),
	}
	for _, cor in plan.corridors do
		local def = Zones.list[cor.zone]
		if not def.floating then
			local f = folderFor(cor.zone)
			local from = cor.b
			local to = def.center
			local dir = (to - from).Unit
			local side = Vector2.new(-dir.Y, dir.X)
			local len = (to - from).Magnitude - 24
			local col = PATH[def.id] or PATH.meadow
			local bend = (hash(cor.zone, 3, 7) - 0.5) * 0.5
			for d = 0, len, 3.2 do
				local wob = math.sin(d / 26 + cor.zone) * 6 + bend * d * 0.15
				local mid = from + dir * d + side * wob
				for k = -2, 2 do
					local q = mid + side * (k * 3.2)
					local ci, cj = plan.cellAt(q)
					local cc = plan.get(ci, cj)
					if cc and cc.kind == "zone" then
						local border = math.abs(k) == 2
						if not (border and hash(ci + k, cj + math.floor(d), 71) < 0.35) then
							local tile = blk(f, Vector3.new(3.1, 0.3, 3.1), CFrame.new(v3(q, cc.h + 0.15)), if border then shade(col, 0.78) else (if hash(math.floor(d), k, 72) < 0.5 then col else shade(col, 0.94)), Enum.Material.Plastic, true)
							deco(tile)
						end
					end
				end
			end
		end
	end
	task.wait()

	-- 2) the forest wall: big trees on the wooded plateau around every area
	local R = WorldPlan.rng(4242)
	local spacing = 23
	local B = Zones.BOUNDS
	for x = B.minX, B.maxX, spacing do
		for z = B.minZ, B.maxZ, spacing do
			local p = Vector2.new(x + (R() - 0.5) * 10, z + (R() - 0.5) * 10)
			local i, j = plan.cellAt(p)
			local c = plan.get(i, j)
			if c and c.kind == "rock" and c.forest and R() < 0.85 and not onCorridor(p) then
				-- is this tree in the front rows (a zone floor within 2 columns)?
				local front = false
				for di = -2, 2 do
					for dj = -2, 2 do
						local o = plan.get(i + di, j + dj)
						if o and o.kind == "zone" then
							front = true
						end
					end
				end
				local size = if front then 1.5 + R() * 0.7 else 1.6 + R() * 0.6
				treeFor(c.near, folderFor(c.near), v3(p, c.h), size, R, front)
			end
		end
	end
	task.wait()

	-- 3) a few trees and rocks inside each area, clear of the grass
	for zi, def in Zones.list do
		local f = folderFor(zi)
		local placed = 0
		for _ = 1, 200 do
			if placed >= 16 then
				break
			end
			local ang = R() * math.pi * 2
			local p = def.center + Vector2.new(math.cos(ang), math.sin(ang)) * math.sqrt(R()) * def.radius * 0.85
			local i, j = plan.cellAt(p)
			local c = plan.get(i, j)
			if c and c.kind == "zone" and c.region == zi and patchFree(p, 6) and not onCorridor(p) and (p - def.landmark.at).Magnitude > 40 then
				placed += 1
				if placed % 4 == 0 then
					local s = 2 + R() * 2.5
					local rockName = "Rock_" .. def.id .. (if s > 3.4 then "_big" else "")
					if not Models.place(f, rockName, v3(p, c.h - 0.3), { scale = s / 3, yaw = math.floor(R() * 4) * math.pi / 2, collide = true }) then
						local g = shade(def.palette.rock, 1.25)
						blk(f, Vector3.new(s * 1.4, s, s * 1.2), CFrame.new(v3(p, c.h + s * 0.45)) * CFrame.Angles(0, R() * 3, 0), g)
						deco(blk(f, Vector3.new(s * 0.7, s * 0.6, s * 0.7), CFrame.new(v3(p + Vector2.new(s * 0.8, s * 0.5), c.h + s * 0.25)), shade(g, 0.9)))
					end
				else
					-- giants: the trees inside an area tower over the grass like in the reference
					treeFor(zi, f, v3(p, c.h), 1.8 + R() * 1, R, true)
				end
			end
		end
		-- landmark and ambience
		local li, lj = plan.cellAt(def.landmark.at)
		local lc = plan.get(li, lj)
		landmark(f, zi, if lc and lc.kind == "zone" then lc.h else def.base)
		ambient(f, zi)
		task.wait()
	end
	-- the village gets trees round its edge too (from the forest pass) and the meadow's pollen
	return count
end

return WorldArt
