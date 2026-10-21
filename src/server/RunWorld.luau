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
					local at = if z > 1 then Config.zoneEntry(z) else Config.zoneCentre(0) + Vector3.new(0, 0, -20)
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
	clearVillage(w)
	texturedGround(w)
	restyleStairs(w)
	-- (the saved world keeps its voxel trees, bushes and rocks: partNature would swap them for part-built ones)

	local info = { world = w, gates = {}, pumps = {}, sellPads = {}, meshGround = true }
	paths(w)
	RunBuilder.hub(w, info)
	require(script.Parent.HubDressing).village(w)

	local gates = w:FindFirstChild("Gates")
	for _, g in (if gates then gates:GetChildren() else {}) do
		local z = g:GetAttribute("Zone")
		if typeof(z) == "number" then
			closeGate(g)
			g:SetAttribute("NewWorld", true)
			table.insert(info.gates, { b = z, model = g })
		end
	end

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
							if free(p) then
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

return RunWorld
