-- A run in the generated world (Config.WORLD_GEN): server/WorldGen's village and eight valleys instead of
-- RunBuilder's 3 x 3 plots. Gives server/Run the same `info` RunBuilder.build does:
--   * the world: the one built in Studio and saved in the place (Workspace.World, set aside at server start by
--     RunWorld.stash so the lobby doesn't replace it), else built now with WorldGen.build (slower);
--   * the hub buildings (tool shop, bag stand, garage, shredder, spawn) in the village, from RunBuilder.hub;
--   * the gates (World.Gates.Gate<z>, closed until the area before is mowed bare; Run opens them);
--   * the drop-off pads in every valley as extra sell spots;
--   * where the grass grows (RunWorld.patches, read by server/Field): clumps scattered in World.Patches.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local RunBuilder = require(script.Parent.RunBuilder)

local RunWorld = {}

local STASH = "GenWorld"
local world: Instance? = nil

-- At server start (before the lobby builds its own World): keep the generated world saved in the place.
function RunWorld.stash()
	local w = workspace:FindFirstChild("World")
	if w and w:GetAttribute("GatePos2") ~= nil and not ServerStorage:FindFirstChild(STASH) then
		w.Name = STASH
		w.Parent = ServerStorage
	end
end

-- A gate's closed look: blockers stand; a missing bridge (chasm gates) shows as a faint ghost you fall through.
local function closeGate(gate: Instance)
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Walkway" then
			p:SetAttribute("SolidTransparency", p.Transparency)
			p.Transparency = 0.8
			p.CanCollide = false
			p.CanQuery = false
		end
	end
end

-- Open it (server/Run calls this): blockers stop blocking and fade (after `hideAfter` s, while the client's
-- banner shows), the bridge becomes solid, the "mow all of ... to open" sign goes.
function RunWorld.openGate(gate: Instance, hideAfter: number?)
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Walkway" then
				p.Transparency = p:GetAttribute("SolidTransparency") or 0
				p.CanCollide = true
				p.CanQuery = true
			elseif p.Name == "Blocker" then
				p.CanCollide = false
			end
		end
	end
	local function hide()
		for _, p in gate:GetDescendants() do
			if p:IsA("BasePart") and (p.Name == "Blocker" or string.sub(p.Name, 1, 4) == "Sign") then
				p.Transparency = 1
				p.CanCollide = false
			elseif p:IsA("SurfaceGui") then
				p.Enabled = false
			end
		end
	end
	if hideAfter then
		task.delay(hideAfter, hide)
	else
		hide()
	end
end

-- The village's blockout buildings make way for the real hub buildings.
local function clearVillage(w: Instance)
	local v = w:FindFirstChild("Village")
	if v then
		for _, c in v:GetChildren() do
			if c.Name ~= "Fountain" and c.Name ~= "FountainWater" then
				c:Destroy()
			end
		end
	end
	local spawn = w:FindFirstChild("Spawn")
	if spawn then
		spawn:Destroy()
	end
end

-- The saved world's ground gets Roblox's textured materials instead of flat plastic, like Chop A Forest's:
-- grass on the areas' floors (snow in the frost area), dirt down the sides, slate on the rocks.
local function texturedGround(w: Instance)
	local ground = w:FindFirstChild("Ground")
	if not ground then
		return
	end
	for _, p in ground:GetDescendants() do
		if p:IsA("BasePart") then
			p.TopSurface = Enum.SurfaceType.Smooth
			local zone = p:GetAttribute("Zone")
			if p.Name == "Floor" then
				local id = if typeof(zone) == "number" then Zones.region(zone).id else nil
				p.Material = if id == "frost" then Enum.Material.Snow elseif id == "ember" then Enum.Material.Basalt else Enum.Material.Grass
			elseif p.Name == "FloorSide" then
				p.Material = Enum.Material.Ground
			elseif p.Name == "Rock" or p.Name == "RockSide" then
				local c = p.Color
				p.Material = if c.G > c.R + 0.05 and c.G > c.B then Enum.Material.Grass else Enum.Material.Slate
			end
		end
	end
end

-- The saved world's voxel trees, bushes and rocks give way to Chop A Forest style ones built from parts
-- (server/HubKit), standing where they stood and as tall, in each area's colours. The landmarks stay.
local TREE_KIND = { meadow = "meadow", blossom = "blossom", wheat = "autumn", pine = "pine", swamp = "swamp", frost = "frost", ember = "ember", isles = "meadow" }
local function partNature(w: Instance)
	local visuals = w:FindFirstChild("Visuals")
	if not visuals then
		return
	end
	local HubKit = require(script.Parent.HubKit)
	local rng = Random.new(77)
	local n = 0
	for _, mesh in visuals:GetDescendants() do
		if mesh:IsA("MeshPart") then
			local what, area = string.match(mesh.Name, "^(%a+)_(%a+)")
			local kind = area and TREE_KIND[area]
			if kind and (what == "Tree" or what == "Bush" or what == "Rock") then
				local foot = mesh.Position - Vector3.new(0, mesh.Size.Y / 2, 0)
				local parent = mesh.Parent :: Instance
				if what == "Tree" then
					HubKit.tree(parent, foot, mesh.Size.Y / 14.5, kind, rng)
				elseif what == "Bush" then
					HubKit.bush(parent, foot, mesh.Size.Y / 2.6, rng, area == "blossom" or area == "meadow", kind)
				else
					HubKit.rock(parent, foot, mesh.Size.Y / 2, rng)
				end
				mesh:Destroy()
				n += 1
				if n % 60 == 0 then
					task.wait()
				end
			end
		end
	end
end

-- The stone stairs between the areas (the saved world's "Stair" blocks) restyled to match the hubs: rough slate
-- risers, packed-dirt treads like the paths with a stone kerb along each side, a round log along the front edge
-- of every step, and a lamp post either side at the top and the bottom.
local STAIR_STONE = { Color3.fromRGB(150, 146, 138), Color3.fromRGB(136, 132, 126) }
local TREAD = Color3.fromRGB(214, 152, 88)
local KERB = Color3.fromRGB(170, 166, 158)
local STAIR_LOG = Color3.fromRGB(182, 128, 78)
local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function restyleStairs(w: Instance)
	-- the stairs come in runs (one folder each); restyle every run
	local runs: { [Instance]: { BasePart } } = {}
	for _, p in w:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Stair" and p.Parent then
			runs[p.Parent] = runs[p.Parent] or {}
			table.insert(runs[p.Parent], p)
		end
	end
	local Models = require(script.Parent.Models)
	for folder, steps in runs do
		local look = steps[1].CFrame.LookVector
		table.sort(steps, function(a, b)
			return a.Position:Dot(look) < b.Position:Dot(look)
		end)
		local function top(p: BasePart): number
			return p.Position.Y + p.Size.Y / 2
		end
		for i, p in steps do
			p.Material = Enum.Material.Slate
			p.Color = STAIR_STONE[i % 2 + 1]
			p.TopSurface = Enum.SurfaceType.Smooth
			local w2, d = p.Size.X / 2, p.Size.Z
			local y = p.Size.Y / 2
			-- dirt tread with a stone kerb along both sides
			deco(folder, "StairTread", Vector3.new(p.Size.X - 1.6, 0.2, d + 0.02), p.CFrame * CFrame.new(0, y + 0.08, 0), TREAD, Enum.Material.Sand)
			for _, sx in { -1, 1 } do
				deco(folder, "StairKerb", Vector3.new(0.8, 0.45, d + 0.04), p.CFrame * CFrame.new(sx * (w2 - 0.4), y + 0.2, 0), KERB, Enum.Material.Slate)
			end
			-- a log along the edge facing the lower neighbour (the riser you see walking up)
			local before, after = steps[i - 1], steps[i + 1]
			local lowerBehind = before ~= nil and top(before) < top(p) - 0.2
			local lowerAhead = after ~= nil and top(after) < top(p) - 0.2
			for _, edge in { if lowerBehind then 1 else 0, if lowerAhead then -1 else 0 } do
				if edge ~= 0 then
					-- local -Z points along `look` (ahead); +Z is behind
					deco(folder, "StairLog", Vector3.new(p.Size.X - 1.6, 0.8, 0.8), p.CFrame * CFrame.new(0, y + 0.05, edge * (d / 2 - 0.35)), STAIR_LOG, Enum.Material.Wood, Enum.PartType.Cylinder)
				end
			end
		end
		-- lamp posts on the stair's edges at the bottom and the top, facing across it
		local lamps = Instance.new("Folder")
		lamps.Name = "StairLamps"
		lamps.Parent = folder
		for _, p in { steps[1], steps[#steps] } do
			for _, sx in { -1, 1 } do
				local at = p.CFrame * CFrame.new(sx * (p.Size.X / 2 - 1.2), p.Size.Y / 2, 0)
				local foot = at.Position
				local inward = foot - at.RightVector * sx
				Models.place("lantern_post", lamps, CFrame.lookAt(foot, Vector3.new(inward.X, foot.Y, inward.Z)), 0.85, true)
			end
		end
	end
end

-- The areas' tiled paths (WorldArt: 3.1 x 0.3 x 3.1 tiles in World.Visuals) are kept clear of grass: the ground
-- cover's little blades and flowers standing on a tile go, and no mowable clump grows over one (RunWorld.patches
-- asks onPath).
local PATH_CELL = 4
local pathCells: { [number]: { Vector3 } } = {}
local function cellKey(x: number, z: number): number
	return (math.floor(x / PATH_CELL) + 4000) * 10000 + (math.floor(z / PATH_CELL) + 4000)
end
local function onPath(p: Vector3, r: number): boolean
	local n = math.ceil((r + 2) / PATH_CELL)
	for i = -n, n do
		for j = -n, n do
			for _, t in pathCells[cellKey(p.X + i * PATH_CELL, p.Z + j * PATH_CELL)] or {} do
				if math.abs(t.X - p.X) < r + 1.6 and math.abs(t.Z - p.Z) < r + 1.6 and math.abs(t.Y - p.Y) < 6 then
					return true
				end
			end
		end
	end
	return false
end
local function clearPaths(w: Instance)
	local visuals = w:FindFirstChild("Visuals")
	if not visuals then
		return
	end
	table.clear(pathCells)
	local small: { BasePart } = {}
	for _, d in visuals:GetDescendants() do
		if d:IsA("Part") then
			local sz = d.Size
			if math.abs(sz.X - 3.1) < 0.01 and math.abs(sz.Y - 0.3) < 0.01 and math.abs(sz.Z - 3.1) < 0.01 then
				local k = cellKey(d.Position.X, d.Position.Z)
				pathCells[k] = pathCells[k] or {}
				table.insert(pathCells[k], d.Position)
			elseif sz.Magnitude < 4 then
				table.insert(small, d)
			end
		end
	end
	local n = 0
	for _, d in small do
		if onPath(d.Position - Vector3.new(0, 1, 0), 1.2) then -- (also the gaps between tiles and at the ragged edges)
			d:Destroy()
			n += 1
		end
	end
	print(("[RunWorld] %d bits of grass cleared off the paths"):format(n))
end

-- Dirt paths across the village between the hub buildings (like the lobby's: server/HubPaths).
local PATHS = {
	{ Vector2.new(0, -82), Vector2.new(0, 30) }, -- the main walk: spawn -> fountain -> the way north to the meadow
	{ Vector2.new(-21, -46), Vector2.new(20, -46) }, -- tool shop <-> bag stand
	{ Vector2.new(-25, -14), Vector2.new(17, -14) }, -- garage <-> the shredder's sell pad
}
local SQUARE = { Vector2.new(0, -3), Vector2.new(0, 3), 24 } -- the open dirt square round the fountain
local function paths(w: Instance)
	local segments = {}
	for _, s in PATHS do
		table.insert(segments, { a = s[1], b = s[2], width = 9 })
	end
	table.insert(segments, { a = SQUARE[1], b = SQUARE[2], width = SQUARE[3] })
	require(script.Parent.HubPaths).lay(w, segments, 0, 5)
end

-- The first area has no drop-off of its own in the generated map, and the village shredder is ~350 studs from
-- its grass, so the first minutes were spent walking. Give it one: a copy of area 2's drop-off pad, put on flat
-- ground in the middle of area 1's grass, clear of every clump (RunWorld.patches).
local function meadowDropOff(w: Instance)
	local pads = w:FindFirstChild("Pads")
	if not pads or pads:FindFirstChild("DropOff1") or not pads:FindFirstChild("DropOff2") or w:GetAttribute("CampCenter") then
		return
	end
	local clumps = RunWorld.patches(1)
	if #clumps < 4 then
		return
	end
	local ground = w:FindFirstChild("Ground")
	if not ground then
		return
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { ground }
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, c in clumps do
		local p = c.cf.Position
		minX, maxX, minZ, maxZ = math.min(minX, p.X), math.max(maxX, p.X), math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local function heightAt(x: number, z: number): number?
		local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), ray)
		return if hit and hit.Normal.Y > 0.95 then hit.Position.Y else nil
	end
	local best, bestScore = nil, math.huge
	for x = minX, maxX, 4 do
		for z = minZ, maxZ, 4 do
			local near, sum = math.huge, 0
			for _, c in clumps do
				local p = c.cf.Position
				local d = Vector2.new(p.X - x, p.Z - z).Magnitude
				near = math.min(near, d)
				sum += d
			end
			local score = sum / #clumps
			if near >= 12 and score < bestScore then
				local y = heightAt(x, z)
				local flat = y ~= nil
				if y then
					for _, o in { Vector2.new(8, 0), Vector2.new(-8, 0), Vector2.new(0, 8), Vector2.new(0, -8) } do
						local y2 = heightAt(x + o.X, z + o.Y)
						if not y2 or math.abs(y2 - y) > 0.3 then
							flat = false
							break
						end
					end
				end
				if flat and y then
					best, bestScore = Vector3.new(x, y, z), score
				end
			end
		end
	end
	if not best then
		return
	end
	-- copy area 2's pad (the top disc and its steps) over to the spot
	local src = pads:FindFirstChild("DropOff2") :: BasePart
	local srcFoot = src.Position - Vector3.new(0, 2.3, 0) -- the pad's top disc sits 2.3 above the ground
	local move = best - srcFoot
	for _, part in pads:GetChildren() do
		if part:IsA("BasePart") and (part.Name == "DropOff2" or part.Name == "DropOff2Step") then
			local copy = part:Clone()
			copy.Name = if part.Name == "DropOff2" then "DropOff1" else "DropOff1Step"
			copy.CFrame = part.CFrame + move
			if part.Name == "DropOff2" then
				copy:SetAttribute("Zone", 1)
			end
			copy.Parent = pads
		end
	end
	print(("[RunWorld] area 1 drop-off placed at %d, %d (avg %.0f studs from its grass)"):format(best.X, best.Z, bestScore))
end


-- Players who fall into the sea, a gorge or lava come back at the way into the area they're working on.
local function safetyNet(info)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and root.Position.Y < Zones.SEA - 4 then
					local z = info.zone and info.zone() or 1
					local camp = info.world and info.world:GetAttribute("CampCenter")
					local start = if typeof(camp) == "Vector3" then camp else Config.zoneCentre(0) + Vector3.new(0, 0, -20)
					local at = if z > 1 then Config.zoneEntry(z) else start
					char:PivotTo(CFrame.new(at + Vector3.new(0, 5, 0)))
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

function RunWorld.build()
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	workspace.Terrain:Clear() -- the lobby's Terrain ground; this world is all parts
	local saved = ServerStorage:FindFirstChild(STASH)
	local w: Instance
	if saved then
		w = saved:Clone()
		w.Name = "World"
		w.Parent = workspace
	else
		w = require(script.Parent.WorldGen).build()
	end
	world = w
	require(script.Parent.WorldGen).lighting()
	-- the ForgeGUI landmarks in place of the ones the saved world was built with
	print(("[RunWorld] %d ForgeGUI landmarks"):format(require(script.Parent.WorldArt).forgeLandmarks(w)))
	local info = { world = w, gates = {}, pumps = {}, sellPads = {}, meshGround = true }
	if w:GetAttribute("VillageBaked") then
		-- the village was baked into the saved world in Studio (RunWorld.bakeVillage), maybe moved around by hand:
		-- build the working pieces fresh (prompts, pads, spawn) and put each where its saved copy stands
		clearPaths(w) -- (only to learn where the paths are, so no grass grows on them)
		local fresh = Instance.new("Folder")
		fresh.Name = "FreshVillage"
		fresh.Parent = workspace
		info.world = fresh
		RunBuilder.hub(fresh, info)
		require(script.Parent.MapStore).swapInto(info, w :: Folder)
		info.world = w
	else
		clearVillage(w)
		texturedGround(w)
		restyleStairs(w)
		clearPaths(w)
		-- (the saved world keeps its voxel trees, bushes and rocks: partNature would swap them for part-built ones)
		paths(w)
		RunBuilder.hub(w, info)
		require(script.Parent.HubDressing).village(w)
	end

	local gates = w:FindFirstChild("Gates")
	for _, g in (if gates then gates:GetChildren() else {}) do
		local z = g:GetAttribute("Zone")
		if typeof(z) == "number" then
			closeGate(g)
			g:SetAttribute("NewWorld", true)
			table.insert(info.gates, { b = z, model = g })
		end
	end

	meadowDropOff(w)
	local pads = w:FindFirstChild("Pads")
	for _, pad in (if pads then pads:GetChildren() else {}) do
		if pad:IsA("BasePart") and pad:GetAttribute("Sell") then
			local top = pad.Position + Vector3.new(0, pad.Size.X / 2, 0)
			table.insert(info.sellPads, { pos = top, radius = 7, mouth = top + Vector3.new(0, 5, 0), out = top })
		end
	end

	safetyNet(info)
	return info
end


-------------------------------------------------------------------------------------------------------------
-- where the grass grows
-------------------------------------------------------------------------------------------------------------
local cache: { [number]: { { cf: CFrame, scale: number } } } = {}

-- How big a zone's clumps are (the Blender clump is ~5.4 studs wide, ~7 tall): the zone's spacing sets it, so
-- clumps nearly touch, like the trees of a Chop A Forest wood.
function RunWorld.clumpScale(z: number): number
	local def = Config.ZONES[z]
	return math.clamp((def and def.spacing or 11) / 6, 1.5, 2.3)
end

-- Clump spots in zone z: a jittered grid inside every patch disc of World.Patches.Zone<z>, standing on the floor.
function RunWorld.patches(z: number): { { cf: CFrame, scale: number } }
	if cache[z] then
		return cache[z]
	end
	local list = {}
	local w = world or workspace:FindFirstChild("World")
	local folder = w and w:FindFirstChild("Patches")
	local discs = folder and folder:FindFirstChild("Zone" .. z)
	local ground = w and w:FindFirstChild("Ground")
	if not discs or not ground then
		cache[z] = list
		return list
	end
	local def = Config.ZONES[z]
	local spacing = math.clamp((def and def.spacing or 11) * 0.9, 7, 13)
	local scale = RunWorld.clumpScale(z)
	local rng = Random.new(z * 7919)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { ground }
	local placed: { Vector3 } = {}
	-- yard discs (attribute Yard: the grass round the village's buildings) keep clear of anything built there
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { ground, folder :: Instance }
	local function blocked(p: Vector3, r: number): boolean
		for _, part in workspace:GetPartBoundsInRadius(p + Vector3.new(0, 4, 0), r, overlap) do
			if part.CanCollide or part.Size.Magnitude > 4.6 then
				if not part:FindFirstAncestor("Grass") and not part:FindFirstAncestor("Mowed") then
					return true
				end
			end
		end
		return false
	end
	-- no grass in the camp (RunWorld.moveVillageToCamp: World attributes CampCenter, CampRadius)
	local camp = w and w:GetAttribute("CampCenter")
	local campR = (w and w:GetAttribute("CampRadius") or 0) :: number
	local function inCamp(p: Vector3): boolean
		return typeof(camp) == "Vector3" and Vector2.new(p.X - camp.X, p.Z - camp.Z).Magnitude < campR + 4
	end
	-- nor inside an area's landmark (up to ~46 studs wide) or on a drop-off pad (the patch blobs reached them)
	local keepOut: { { at: Vector2, r: number } } = {}
	for _, zdef in Zones.list do
		if zdef.landmark then
			table.insert(keepOut, { at = zdef.landmark.at, r = 26 })
		end
	end
	local padFolder = w and w:FindFirstChild("Pads")
	for _, pd in (if padFolder then padFolder:GetChildren() else {}) do
		if string.match(pd.Name, "^DropOff") then
			local pp = if pd:IsA("Model") then pd:GetPivot().Position elseif pd:IsA("BasePart") then pd.Position else nil
			if pp then
				table.insert(keepOut, { at = Vector2.new(pp.X, pp.Z), r = 11 })
			end
		end
	end
	local function keptOut(p: Vector3): boolean
		for _, k in keepOut do
			if Vector2.new(p.X - k.at.X, p.Z - k.at.Y).Magnitude < k.r then
				return true
			end
		end
		return false
	end
	-- no grass on the boss arenas (server/BossArena: World attributes Arena<z>, ArenaRadius)
	local arenaR = (w and w:GetAttribute("ArenaRadius") or 0) :: number
	local arenaCs: { Vector3 } = {}
	for i = 1, #Config.ZONES do
		local a = w and w:GetAttribute("Arena" .. i)
		if typeof(a) == "Vector3" then
			table.insert(arenaCs, a)
		end
	end
	local function inArena(p: Vector3): boolean
		for _, a in arenaCs do
			if Vector2.new(p.X - a.X, p.Z - a.Z).Magnitude < arenaR + 6 then
				return true
			end
		end
		return false
	end
	local function free(p: Vector3): boolean
		for _, q in placed do
			if (Vector3.new(q.X - p.X, 0, q.Z - p.Z)).Magnitude < spacing * 0.85 then
				return false
			end
		end
		return true
	end
	local kids = discs:GetChildren()
	table.sort(kids, function(a, b)
		return a.Name < b.Name
	end)
	for _, d in kids do
		if d:IsA("BasePart") then
			local yard = d:GetAttribute("Yard") == true
			local c = d.Position
			local r = d.Size.Y / 2 - 2
			local n = math.ceil(r / spacing)
			for i = -n, n do
				for j = -n, n do
					local x = c.X + (i + (j % 2) * 0.5) * spacing + rng:NextNumber(-1.5, 1.5)
					local zz = c.Z + j * spacing * 0.87 + rng:NextNumber(-1.5, 1.5)
					local flatD = Vector2.new(x - c.X, zz - c.Z).Magnitude
					if flatD <= r then
						local hit = workspace:Raycast(Vector3.new(x, c.Y + 40, zz), Vector3.new(0, -80, 0), ray)
						if hit and hit.Normal.Y > 0.9 and math.abs(hit.Position.Y - (c.Y - 0.5)) < 6.5 then
							local p = hit.Position
							if free(p) and not inCamp(p) and not keptOut(p) and not inArena(p) and not onPath(p, 2.6 * scale) and not (yard and blocked(p, 3.4 * scale)) then
								table.insert(placed, p)
								local yaw = rng:NextInteger(0, 3) * math.pi / 2
								table.insert(list, { cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0), scale = scale * rng:NextNumber(0.9, 1.1) })
							end
						end
					end
				end
			end
		end
	end
	cache[z] = list
	return list
end

-- STUDIO, EDIT MODE (command bar): require(game.ServerScriptService.MowALawn.RunWorld).bakeVillage()
-- Puts the run's village into the saved world as real parts, so you can see it in Edit mode and move things by
-- hand: the tool shop, bag stand, garage, shredder, spawn, the paths, the arch and benches, area 1's drop-off.
-- It does to Workspace.World what a run's server does at start, once, and marks it (attribute VillageBaked).
-- The working pieces (marked MapUnit) can be moved or deleted as a whole and the game follows; changes inside
-- them are replaced by code. A copy of the world as it was goes to ServerStorage.MowALawnBackups first.
function RunWorld.bakeVillage()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Bake in Studio with the game stopped (edit mode)")
	local w = workspace:FindFirstChild("World")
	assert(w and w:GetAttribute("GatePos2") ~= nil, "Workspace.World isn't the generated world")
	if w:GetAttribute("VillageBaked") then
		warn("[RunWorld] The village is already baked into Workspace.World (" .. tostring(w:GetAttribute("VillageBaked")) .. "). To start over, put back the copy in ServerStorage.MowALawnBackups.")
		return
	end
	local backups = ServerStorage:FindFirstChild("MowALawnBackups") or Instance.new("Folder")
	backups.Name = "MowALawnBackups"
	backups.Parent = ServerStorage
	local copy = w:Clone()
	copy.Name = "World before village bake " .. os.date("%Y-%m-%d %H.%M")
	copy.Parent = backups
	require(script.Parent.Models).loadAll(30)
	world = w
	table.clear(cache)
	clearVillage(w)
	texturedGround(w)
	restyleStairs(w)
	clearPaths(w)
	paths(w)
	require(script.Parent.HubDressing).village(w)
	meadowDropOff(w)
	-- the buildings: built on their own and tagged there (so only they become working pieces), then moved in
	local fresh = Instance.new("Folder")
	fresh.Name = "FreshVillage"
	fresh.Parent = workspace
	local info = { world = fresh, gates = {}, pumps = {}, sellPads = {}, meshGround = true }
	RunBuilder.hub(fresh, info)
	require(script.Parent.MapStore).markSaved(fresh, info, "FreshVillage")
	for _, c in fresh:GetChildren() do
		c.Parent = w
	end
	fresh:Destroy()
	w:SetAttribute("VillageBaked", os.date("%Y-%m-%d %H:%M"))
	print("[RunWorld] Village baked into Workspace.World: move things around, then save the place.")
end


-- STUDIO, EDIT MODE, once (command bar), after bakeVillage:
--   require(game.ServerScriptService.MowALawn.RunWorld).moveVillageToCamp(Vector3.new(73, 0, 351), 34)
-- Chop A Forest's camp sits in its first wood, so the first area IS where you start. This moves the village's
-- working buildings (tool shop, bag stand, garage, shredder, classes stand, spawn) onto a flat dirt yard in the
-- middle of area 1's grass at `centre` (radius `radius`), facing the rest of the meadow; clears the trees and
-- ground cover standing there; and marks the world (CampCenter / CampRadius / CampFacing) so no grass grows in
-- the camp and the boss arena keeps away from it. What it takes away goes to ServerStorage.MowALawnBackups.
local CAMP_LAYOUT = {
	-- unit name, where it stood in the village (its spot and the point it looked at), where it goes in the camp
	-- (x: to the camp's right, z: forward into the meadow) and which way it faces there
	{ "TOOL SHOP", Vector3.new(-34, 0, -46), Vector3.new(0, 0, -46), Vector2.new(-24, -2), "right" },
	{ "Garage", Vector3.new(-34, 0, -14), Vector3.new(0, 0, -14), Vector2.new(-24, 22), "right" },
	{ "BAG STAND", Vector3.new(32, 0, -48), Vector3.new(0, 0, -48), Vector2.new(22, -4), "left" },
	{ "Shredder", Vector3.new(40, 0, -14), Vector3.new(80, 0, -14), Vector2.new(24, 18), "right" },
	{ "CLASSES", Vector3.new(-24, 0, 12), Vector3.new(0, 0, 12), Vector2.new(-8, -24), "forward" },
	{ "SpawnLocation", Vector3.new(0, 0, -74), Vector3.new(0, 0, -64), Vector2.new(8, -20), "forward" },
}

function RunWorld.moveVillageToCamp(centre: Vector3, radius: number)
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Run in Studio with the game stopped (edit mode)")
	local w = workspace:FindFirstChild("World") :: Instance
	assert(w and w:GetAttribute("VillageBaked"), "Bake the village first: RunWorld.bakeVillage()")
	assert(not w:GetAttribute("CampCenter"), "The camp is already in area 1")
	local hub = w:FindFirstChild("Hub") :: Instance
	local backups = ServerStorage:FindFirstChild("MowALawnBackups") :: Instance
	local bk = Instance.new("Folder")
	bk.Name = "Before the camp " .. os.date("%Y-%m-%d %H.%M")
	bk.Parent = backups
	local ground = w:FindFirstChild("Ground") :: Instance
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { ground }
	-- the yard's height: the highest ground under it
	local top = -math.huge
	for x = -radius, radius, 4 do
		for z = -radius, radius, 4 do
			if x * x + z * z <= radius * radius then
				local hit = workspace:Raycast(Vector3.new(centre.X + x, 300, centre.Z + z), Vector3.new(0, -600, 0), rp)
				if hit then
					top = math.max(top, hit.Position.Y)
				end
			end
		end
	end
	top += 0.3
	local c = Vector3.new(centre.X, top, centre.Z)
	-- face the rest of the meadow
	local meadow = Config.zoneCentre(1)
	local fwd = Vector3.new(meadow.X - c.X, 0, meadow.Z - c.Z)
	fwd = if fwd.Magnitude > 1 then fwd.Unit else Vector3.zAxis
	local right = fwd:Cross(Vector3.yAxis)
	-- clear what stands in the camp (trees, bushes, ground cover, a drop-off pad), keeping a copy
	local clear = OverlapParams.new()
	clear.FilterType = Enum.RaycastFilterType.Include
	clear.FilterDescendantsInstances = { w:FindFirstChild("Visuals") :: Instance, w:FindFirstChild("Pads") :: Instance }
	local moved = 0
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(c), Vector3.new(radius * 2 + 4, 60, radius * 2 + 4), clear) do
		if part.Parent and part:IsDescendantOf(w) and Vector2.new(part.Position.X - c.X, part.Position.Z - c.Z).Magnitude < radius + 2 then
			local node: Instance = part
			-- whole models (a tree is one MeshPart, a prop can be a Model)
			local model = part:FindFirstAncestorWhichIsA("Model")
			if model and model:IsDescendantOf(w) then
				node = model
			end
			if node.Parent then
				node.Parent = bk
				moved += 1
			end
		end
	end
	-- the dirt yard: one flat slab down to below the lowest step
	local yard = Instance.new("Part")
	yard.Name = "CampYard"
	yard.Anchored = true
	yard.Shape = Enum.PartType.Cylinder
	yard.Size = Vector3.new(8, radius * 2, radius * 2)
	yard.CFrame = CFrame.new(c - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	yard.Material = Enum.Material.Ground
	yard.Color = Color3.fromRGB(150, 112, 74)
	yard.TopSurface = Enum.SurfaceType.Smooth
	yard.Parent = hub
	local rim = yard:Clone()
	rim.Name = "CampRim"
	rim.Size = Vector3.new(7.6, radius * 2 + 3, radius * 2 + 3)
	rim.Material = Enum.Material.Grass
	rim.Color = Color3.fromRGB(86, 168, 58)
	rim.CFrame = yard.CFrame - Vector3.new(0, 0.25, 0)
	rim.Parent = hub
	-- move the buildings
	local function dir(name: string): Vector3
		return if name == "right" then right elseif name == "left" then -right else fwd
	end
	for _, l in CAMP_LAYOUT do
		local unit = hub:FindFirstChild(l[1])
		if unit then
			local old = CFrame.lookAt(l[2], l[3])
			local at = c + right * l[4].X + fwd * l[4].Y
			local new = CFrame.lookAt(at, at + dir(l[5]))
			local delta = new * old:Inverse()
			if unit:IsA("Model") then
				unit:PivotTo(delta * unit:GetPivot())
			elseif unit:IsA("BasePart") then
				unit.CFrame = delta * unit.CFrame
			end
		end
	end
	w:SetAttribute("CampCenter", c)
	w:SetAttribute("CampRadius", radius)
	w:SetAttribute("CampFacing", fwd)
	print(("[RunWorld] The village's buildings are now in area 1's camp at %d, %d (%d things cleared from the yard, kept in %s)"):format(c.X, c.Z, moved, bk.Name))
end


-- STUDIO, EDIT MODE (command bar): require(game.ServerScriptService.MowALawn.RunWorld).refreshForge()
-- Puts the ForgeGUI models into the world saved in the place, so Edit mode shows what a run shows: the 8 area
-- landmarks (WorldArt.forgeLandmarks) and the camp's working buildings (BAG STAND, Shredder, TOOL SHOP, Garage,
-- CLASSES: built fresh by the code, then put exactly where the saved ones stand, so hand moves are kept; what's
-- inside them is the code's anyway, a run replaces it). Copies of what it replaces go to
-- ServerStorage.MowALawnBackups first. Safe to run again.
local function swapUnit(w: Instance, fresh: Instance, name: string, inner: string, bk: Instance): boolean
	local hub, freshHub = w:FindFirstChild("Hub"), fresh:FindFirstChild("Hub")
	local saved = hub and hub:FindFirstChild(name)
	local gen = freshHub and freshHub:FindFirstChild(name)
	local a = gen and gen:FindFirstChild(inner)
	local b = saved and saved:FindFirstChild(inner)
	if not (saved and gen and a and b) then
		warn("[RunWorld] couldn't find " .. name .. " in the saved world")
		return false
	end
	-- the code's piece, moved by how far the saved one was moved (measured on the same part or model in both:
	-- the building model, or the invisible "0Anchor" spot)
	local function pivot(x: Instance): CFrame
		return if x:IsA("BasePart") then x.CFrame else (x :: Model):GetPivot()
	end
	local delta = pivot(b) * pivot(a):Inverse()
	local function move(inst: Instance)
		if inst:IsA("Model") then
			inst:PivotTo(delta * inst:GetPivot())
		elseif inst:IsA("BasePart") then
			inst.CFrame = delta * inst.CFrame
		else
			for _, c in inst:GetChildren() do
				move(c)
			end
		end
	end
	move(gen)
	saved.Parent = bk
	gen.Parent = hub
	return true
end

function RunWorld.refreshForge()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Run in Studio with the game stopped (edit mode)")
	local w = workspace:FindFirstChild("World")
	assert(w and w:GetAttribute("VillageBaked"), "Workspace.World isn't the saved generated world")
	local Models = require(script.Parent.Models)
	Models.loadAll(30)
	local backups = ServerStorage:FindFirstChild("MowALawnBackups") or Instance.new("Folder")
	backups.Name = "MowALawnBackups"
	backups.Parent = ServerStorage
	local bk = Instance.new("Folder")
	bk.Name = "Before ForgeGUI refresh " .. os.date("%Y-%m-%d %H.%M")
	bk.Parent = backups
	-- landmarks: keep copies of the old ones, then swap
	local visuals = w:FindFirstChild("Visuals")
	for _, d in (if visuals then visuals:GetDescendants() else {}) do
		if d:IsA("Model") and string.match(d.Name, " Landmark$") and not d:GetAttribute("Forge") then
			d:Clone().Parent = bk
		end
	end
	local marks = require(script.Parent.WorldArt).forgeLandmarks(w)
	-- the working pieces: build the hub on its own (as a run's server does) and take the buildings
	local fresh = Instance.new("Folder")
	fresh.Name = "FreshVillage"
	fresh.Parent = workspace
	local info = { world = fresh, gates = {}, pumps = {}, sellPads = {}, meshGround = true }
	RunBuilder.hub(fresh, info)
	require(script.Parent.MapStore).markSaved(fresh, info, "FreshVillage")
	local units = 0
	for _, pair in { { "BAG STAND", "bag_stand" }, { "Shredder", "shredder" }, { "TOOL SHOP", "0Anchor" }, { "Garage", "0Anchor" }, { "CLASSES", "0Anchor" } } do
		if swapUnit(w, fresh, pair[1], pair[2], bk) then
			units += 1
		end
	end
	fresh:Destroy()
	print(("[RunWorld] ForgeGUI refresh: %d landmarks and %d buildings swapped (old copies in %s). Save the place."):format(marks, units, bk:GetFullName()))
end

return RunWorld
