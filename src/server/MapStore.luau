-- The lobby and run maps saved in the place, so you can see them and edit them in Studio.
--
-- BAKE (Studio, edit mode, in the command bar):
--     require(game.ServerScriptService.MowALawn.MapStore).bake()
--   runs the world builders once and saves the result as Workspace.Maps:
--     Maps.Run    the run map, where it really is (the hub at 0, 0, -48 and the 3x3 grid of areas)
--     Maps.Lobby  the lobby, shifted LOBBY_OFFSET studs to the side so the two don't overlap in Studio
--   plus both maps' Terrain. Baking again needs bake(true); the old Maps is moved to
--   ServerStorage.MowALawnBackups first, so nothing is lost.
--
-- EDIT: move, recolour, delete or add anything in Maps (and sculpt the terrain).
--   Parts marked with a "MapUnit" attribute are the working pieces (shops, shredders, gates, pumps, pads,
--   signs that show live text, the spawn). Code still builds those: you can MOVE or DELETE one as a whole and
--   the game follows (sell spots, prompts and pads move with it), but changes INSIDE one are replaced by code.
--   Everything else (trees, fences, rocks, mountains, paths, your own parts) is used exactly as you left it.
--
-- PLAY: the server builds the world in code as before (so every prompt, pad and sign is wired up), then swaps
-- in your saved map: your scenery replaces the generated one and each working piece is moved to where you put
-- it. With no Maps folder the game builds everything from code, like before.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Ground = require(script.Parent.Ground)

local MapStore = {}

MapStore.LOBBY_OFFSET = Vector3.new(3000, 0, 0)
-- the lobby's ground (its terrain fill is 440 wide, hills ring it at 245 +- 70), in studs
local LOBBY_HALF = 344
local TERRAIN_LOW, TERRAIN_HIGH = -64, 96

-- World folders whose children are separate pieces (each shop, gate, pump, tree...); in the others the whole
-- folder is one piece.
local function splitFolder(name: string): boolean
	return name == "Hub" or name == "Gates" or name == "Fences" or name == "HubYard" or name == "Forest" or string.match(name, "^Zone%d+$") ~= nil
end

local function lobbyRegion(offset: Vector3): Region3
	local a = Vector3.new(-LOBBY_HALF, TERRAIN_LOW, -LOBBY_HALF) + offset
	local b = Vector3.new(LOBBY_HALF, TERRAIN_HIGH, LOBBY_HALF) + offset
	return Region3.new(a, b):ExpandToGrid(4)
end

-- The same box in Terrain cells (4 studs), for CopyRegion; and its low corner, for PasteRegion.
local function lobbyCells(offset: Vector3): (Region3int16, Vector3int16)
	local a = Vector3.new(-LOBBY_HALF, TERRAIN_LOW, -LOBBY_HALF) + offset
	local b = Vector3.new(LOBBY_HALF, TERRAIN_HIGH, LOBBY_HALF) + offset
	local lo = Vector3int16.new(a.X // 4, a.Y // 4, a.Z // 4)
	local hi = Vector3int16.new(b.X // 4 - 1, b.Y // 4 - 1, b.Z // 4 - 1)
	return Region3int16.new(lo, hi), lo
end

-------------------------------------------------------------------------------------------------------------
-- working pieces ("units")
-------------------------------------------------------------------------------------------------------------
-- The piece `inst` belongs to: a child of World, or a grandchild when that child is a split folder.
local function unitOf(world: Instance, inst: Instance): Instance?
	local node: Instance? = inst
	while node and node.Parent and node.Parent ~= world do
		local parent = node.Parent :: Instance
		if parent.Parent == world and splitFolder(parent.Name) then
			return node
		end
		node = parent
	end
	return if node and node.Parent == world then node else nil
end

-- "Zone1/GasPump#1": the path of names from World, numbered among same-named brothers.
local function idOf(world: Instance, unit: Instance): string
	local parts = {}
	local node: Instance? = unit
	while node and node ~= world do
		local n = 0
		local parent = node.Parent :: Instance
		for _, sib in parent:GetChildren() do
			if sib.Name == node.Name then
				n += 1
			end
			if sib == node then
				break
			end
		end
		table.insert(parts, 1, node.Name .. "#" .. n)
		node = parent
	end
	return table.concat(parts, "/")
end

local function collectInstances(value: any, out: { Instance }, seen: { [any]: boolean })
	if typeof(value) == "Instance" then
		table.insert(out, value)
	elseif type(value) == "table" and not seen[value] then
		seen[value] = true
		for k, v in value do
			if k ~= "world" then
				collectInstances(v, out, seen)
			end
		end
	end
end

-- Every working piece of a freshly built world: anything the game keeps a handle on (the builder's info),
-- anything with a prompt or click detector, and the spawn. Tags each with a MapUnit attribute.
local function stamp(world: Instance, info: any): { [string]: Instance }
	local marked: { [Instance]: boolean } = {}
	local refs = {}
	collectInstances(info, refs, {})
	for _, d in world:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("SpawnLocation") then
			table.insert(refs, d)
		end
	end
	for _, r in refs do
		if r:IsDescendantOf(world) then
			local u = unitOf(world, r)
			if u then
				marked[u] = true
			end
		end
	end
	local units: { [string]: Instance } = {}
	for u in marked do
		local id = idOf(world, u)
		u:SetAttribute("MapUnit", id)
		units[id] = u
	end
	return units
end

-- Where a piece is (to tell how far it was moved): its first part. The saved and the generated piece are built
-- the same way, so their first parts match (a Folder piece is saved as a Model with the same children).
local function pivotOf(inst: Instance): CFrame?
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return nil
end

-- The two copies of a piece measured on the same part: one whose name path inside the piece is unique (like
-- "StartBoard/Board"), the same in both. Child order isn't kept when the place is saved and loaded, so "the
-- first part" can be a different part in each copy (that moved the START A RUN board off its posts).
local function namedParts(unit: Instance): { [string]: BasePart }
	local count: { [string]: number } = {}
	local parts: { [string]: BasePart } = {}
	for _, d in unit:GetDescendants() do
		if d:IsA("BasePart") then
			local path = d.Name
			local node = d.Parent
			while node and node ~= unit do
				path = node.Name .. "/" .. path
				node = node.Parent
			end
			count[path] = (count[path] or 0) + 1
			parts[path] = d
		end
	end
	for path, n in count do
		if n > 1 then
			parts[path] = nil
		end
	end
	return parts
end

local function matchPivots(gen: Instance, saved: Instance): (CFrame?, CFrame?)
	if gen:IsA("BasePart") and saved:IsA("BasePart") then
		return gen.CFrame, saved.CFrame
	end
	local a, b = namedParts(gen), namedParts(saved)
	local best: string? = nil
	for path in a do
		if b[path] and (best == nil or path < best) then
			best = path
		end
	end
	if best then
		return a[best].CFrame, b[best].CFrame
	end
	return pivotOf(gen), pivotOf(saved)
end

local function moveBy(inst: Instance, delta: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(delta * inst:GetPivot())
	elseif inst:IsA("BasePart") then
		inst.CFrame = delta * inst.CFrame
	else
		for _, c in inst:GetChildren() do
			moveBy(c, delta)
		end
	end
end

local function partsOf(inst: Instance): { BasePart }
	local list = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Positions the game keeps in plain numbers (sell spots, pad centres, the mower spawn) follow the piece they
-- belong to: the piece with a part closest to them (within 30 studs), if that piece was moved.
local function shiftInfo(info: any, moved: { { parts: { BasePart }, delta: CFrame } })
	local function nearest(p: Vector3): CFrame?
		local best, bestD = nil, 30
		for _, m in moved do
			for _, part in m.parts do
				local d = (part.Position - p).Magnitude
				if d < bestD then
					best, bestD = m.delta, d
				end
			end
		end
		return best
	end
	local seen = {}
	local function walk(t: any)
		if seen[t] then
			return
		end
		seen[t] = true
		for k, v in t do
			if k == "world" then
				continue
			end
			if typeof(v) == "Vector3" then
				local delta = nearest(v)
				if delta and delta ~= CFrame.identity then
					t[k] = delta * v
				end
			elseif typeof(v) == "CFrame" then
				local delta = nearest(v.Position)
				if delta and delta ~= CFrame.identity then
					t[k] = delta * v
				end
			elseif type(v) == "table" then
				walk(v)
			end
		end
	end
	walk(info)
end

-- Put the generated working pieces into the saved map where the user left them, and make the saved map the world.
local function swapIn(info: any, saved: Folder): Folder
	local world = info.world :: Instance
	local genUnits = stamp(world, info)
	local savedUnits: { [string]: Instance } = {}
	for _, d in saved:GetDescendants() do
		local id = d:GetAttribute("MapUnit")
		if type(id) == "string" and not savedUnits[id] then
			savedUnits[id] = d
		end
	end

	-- 1) work out every move first (positions in info shift by where the pieces were built)
	local moved = {}
	local plan = {}
	for id, gen in genUnits do
		local s = savedUnits[id]
		local delta = CFrame.identity
		if s then
			local a, b = matchPivots(gen, s)
			if a and b then
				delta = b * a:Inverse()
			end
		end
		-- every piece takes part in "which piece is this position nearest to", moved or not
		table.insert(moved, { parts = partsOf(gen), delta = delta })
		table.insert(plan, { id = id, gen = gen, saved = s, delta = delta })
	end
	shiftInfo(info, moved)

	-- 2) swap: the generated piece (wired up) takes the saved one's place
	for _, step in plan do
		local s = step.saved
		if s then
			step.gen.Parent = s.Parent
			s:Destroy()
			if step.delta ~= CFrame.identity then
				moveBy(step.gen, step.delta)
			end
		else
			-- deleted in Studio, or new in the code since the bake: keep the code's one where the code put it
			local folderName = string.match(step.id, "^([^#/]+)#%d+/")
			local holder = folderName and saved:FindFirstChild(folderName)
			step.gen.Parent = holder or saved
			warn(("[MapStore] %s isn't in the saved map; using the code's one (bake again to see it in Studio)"):format(step.id))
		end
		savedUnits[step.id] = nil
	end
	-- working pieces the code doesn't make any more: their prompts would do nothing
	for _, s in savedUnits do
		if s.Parent then
			s:Destroy()
		end
	end

	-- 3) the saved map becomes the world
	world:Destroy()
	saved.Name = "World"
	saved.Parent = workspace
	info.world = saved
	return saved
end

-------------------------------------------------------------------------------------------------------------
-- loading at runtime
-------------------------------------------------------------------------------------------------------------
local stash: Instance? = nil -- the saved maps, out of sight once the server has started
-- "both" while the Terrain holds both maps, "lobby" once the lobby's ground replaced the run's
local terrainState = "none"

local function findMaps(): Instance?
	if stash and not stash.Parent then
		return nil -- dropped after use in a live server
	end
	if stash and stash.Parent then
		return stash
	end
	local maps = workspace:FindFirstChild("Maps")
	if maps then
		terrainState = if maps:GetAttribute("Terrain") == true then "both" else "none"
		maps.Parent = ServerStorage -- out of the world; kept so a Studio lobby can still switch into a run
		stash = maps
	end
	return maps
end

local function prepareTerrain(mode: string): boolean
	local terrain = workspace.Terrain
	if terrainState ~= "both" then
		return false
	end
	if mode == "Run" then
		terrain:FillRegion(lobbyRegion(MapStore.LOBBY_OFFSET), 4, Enum.Material.Air)
		terrainState = "run"
		return true
	end
	-- lobby: lift its ground from beside the run map onto the middle
	local ok, err = pcall(function()
		local copy = terrain:CopyRegion((lobbyCells(MapStore.LOBBY_OFFSET)))
		terrain:Clear()
		local _, corner = lobbyCells(Vector3.zero)
		terrain:PasteRegion(copy, corner, true)
	end)
	terrainState = "lobby"
	if not ok then
		warn("[MapStore] couldn't move the lobby's terrain: " .. tostring(err))
	end
	return ok
end

-- Called first thing at server start: takes the saved maps out of Workspace before anyone joins.
function MapStore.init()
	findMaps()
end

-- Build the world for `mode` ("Lobby" or "Run") with `build` (LobbyBuilder.build / RunBuilder.build), using the
-- map saved in the place when there is one. Returns the builder's info, with info.world the finished world.
function MapStore.load(mode: string, build: () -> any): any
	local maps = findMaps()
	local found = maps and maps:FindFirstChild(mode)
	if not found or not found:IsA("Folder") then
		return build()
	end
	local saved = found:Clone() :: Folder -- keep the stash whole (Studio can switch lobby -> run)
	Ground.locked = prepareTerrain(mode)
	local ok, info = pcall(build)
	Ground.locked = false
	if not ok then
		error(info)
	end
	if mode == "Lobby" then
		moveBy(saved, CFrame.new(-MapStore.LOBBY_OFFSET))
	end
	local okSwap, err = pcall(swapIn, info, saved)
	if not okSwap then
		warn("[MapStore] couldn't use the saved " .. mode .. " map, using the code's: " .. tostring(err))
	end
	if not RunService:IsStudio() and stash then
		stash:Destroy() -- live servers never switch modes
	end
	return info
end

-------------------------------------------------------------------------------------------------------------
-- baking (Studio, edit mode)
-------------------------------------------------------------------------------------------------------------
-- The built world as a saved map: a Folder (so clicking a tree in Studio picks the tree, not the whole map),
-- with every working piece that is a Folder turned into a Model (so it can be picked and moved as one).
local function asSaved(world: Instance, info: any, name: string): Folder
	for _, unit in stamp(world, info) do
		if unit:IsA("Folder") then
			local m = Instance.new("Model")
			m.Name = unit.Name
			for k, v in unit:GetAttributes() do
				m:SetAttribute(k, v)
			end
			for _, c in unit:GetChildren() do
				c.Parent = m
			end
			m.Parent = unit.Parent
			unit:Destroy()
		end
	end
	world.Name = name
	return world :: Folder
end

-- For the generated world (server/RunWorld): the same two steps on a world saved in the place (its village baked
-- in Studio). markSaved tags a just-built world's working pieces; swapInto puts freshly built (wired) pieces where
-- the saved ones stand, and the saved world (`saved`) becomes info.world.
MapStore.markSaved = asSaved
MapStore.swapInto = swapIn

function MapStore.bake(force: boolean?)
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Bake in Studio with the game stopped (edit mode)")
	local old = workspace:FindFirstChild("Maps")
	if old then
		if not force then
			warn("[MapStore] Workspace.Maps is already there (your edits). To rebuild it from code: MapStore.bake(true) - the old one is backed up to ServerStorage.MowALawnBackups.")
			return
		end
		local backups = ServerStorage:FindFirstChild("MowALawnBackups") or Instance.new("Folder")
		backups.Name = "MowALawnBackups"
		backups.Parent = ServerStorage
		old.Name = "Maps " .. os.date("%Y-%m-%d %H.%M.%S")
		old.Parent = backups
	end
	local Models = require(script.Parent.Models)
	Models.loadAll(30)
	local maps = Instance.new("Folder")
	maps.Name = "Maps"

	-- the lobby first (each build clears the terrain), then moved aside with its ground
	local lobbyInfo = require(script.Parent.LobbyBuilder).build()
	local lobbyGround = workspace.Terrain:CopyRegion((lobbyCells(Vector3.zero)))
	local lobby = asSaved(lobbyInfo.world, lobbyInfo, "Lobby")
	moveBy(lobby, CFrame.new(MapStore.LOBBY_OFFSET))
	lobby.Parent = maps
	maps.Parent = workspace

	local runInfo = require(script.Parent.RunBuilder).build()
	local run = asSaved(runInfo.world, runInfo, "Run")
	run.Parent = maps

	local _, corner = lobbyCells(MapStore.LOBBY_OFFSET)
	workspace.Terrain:PasteRegion(lobbyGround, corner, true)
	maps:SetAttribute("Terrain", true)
	maps:SetAttribute("BakedAt", os.date("%Y-%m-%d %H:%M"))
	print(("[MapStore] Baked: Workspace.Maps.Run (the run map) and Workspace.Maps.Lobby (%d studs to the side). Edit away, then save the place."):format(MapStore.LOBBY_OFFSET.X))
end

-- STUDIO, EDIT MODE (command bar): require(game.ServerScriptService.MowALawn.MapStore).bakeLobby()
-- Saves only the lobby, as Workspace.Maps.Lobby (LOBBY_OFFSET studs to the side, with its ground), for a place
-- whose run is the generated world (Config.WORLD_GEN: a run uses Workspace.World, not Maps.Run). Unlike bake(),
-- it leaves everything else as it was: Workspace.World (the saved run world), the Baseplate and spawns, the
-- Lighting and the Terrain are set aside while the lobby builds and put back after. bakeLobby(true) rebuilds a
-- saved lobby (the old one goes to ServerStorage.MowALawnBackups first).
local LIGHT_PROPS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "GeographicLatitude", "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation", "FogColor", "FogStart", "FogEnd", "GlobalShadows", "ShadowSoftness" }
local TERRAIN_PROPS = { "Decoration", "GrassLength", "WaterColor", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance" }

local function snapshot(inst: Instance, props: { string }): { [string]: any }
	local out = {}
	for _, p in props do
		pcall(function()
			out[p] = (inst :: any)[p]
		end)
	end
	return out
end

local function restore(inst: Instance, values: { [string]: any })
	for p, v in values do
		pcall(function()
			(inst :: any)[p] = v
		end)
	end
end

function MapStore.bakeLobby(force: boolean?)
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Bake in Studio with the game stopped (edit mode)")
	local maps = workspace:FindFirstChild("Maps")
	local backups = ServerStorage:FindFirstChild("MowALawnBackups") or Instance.new("Folder")
	backups.Name = "MowALawnBackups"
	backups.Parent = ServerStorage
	local oldLobby = maps and maps:FindFirstChild("Lobby")
	if oldLobby then
		if not force then
			warn("[MapStore] Workspace.Maps.Lobby is already there (your edits). To rebuild it from code: MapStore.bakeLobby(true) - the old one is backed up to ServerStorage.MowALawnBackups.")
			return
		end
		oldLobby.Name = "Maps.Lobby " .. os.date("%Y-%m-%d %H.%M.%S")
		oldLobby.Parent = backups
	end
	-- set aside what building the lobby would change
	local aside = Instance.new("Folder")
	aside.Name = "BakeLobby aside (put back automatically)"
	aside.Parent = ServerStorage
	for _, c in workspace:GetChildren() do
		if c.Name == "World" or c.Name == "Baseplate" or c:IsA("SpawnLocation") then
			c.Parent = aside
		end
	end
	local lighting = game:GetService("Lighting")
	local lightProps = snapshot(lighting, LIGHT_PROPS)
	local terrainProps = snapshot(workspace.Terrain, TERRAIN_PROPS)
	local lightKids = {}
	for _, c in lighting:GetChildren() do
		table.insert(lightKids, c:Clone())
	end
	-- the terrain: only the lobby's box in the middle is used (copied first, cleared, put back after)
	local origin = workspace.Terrain:CopyRegion((lobbyCells(Vector3.zero)))
	workspace.Terrain:FillRegion(lobbyRegion(Vector3.zero), 4, Enum.Material.Air)

	local Models = require(script.Parent.Models)
	Models.loadAll(30)
	Ground.keepTerrain = true
	local ok, err = pcall(function()
		local info = require(script.Parent.LobbyBuilder).build()
		local ground = workspace.Terrain:CopyRegion((lobbyCells(Vector3.zero)))
		local lobby = asSaved(info.world, info, "Lobby")
		moveBy(lobby, CFrame.new(MapStore.LOBBY_OFFSET))
		if not maps then
			maps = Instance.new("Folder")
			maps.Name = "Maps"
		end
		lobby.Parent = maps
		local _, corner = lobbyCells(MapStore.LOBBY_OFFSET)
		workspace.Terrain:PasteRegion(ground, corner, true)
	end)

	Ground.keepTerrain = false
	-- put everything back: the terrain at the middle, the lighting, the run world, baseplate and spawns
	workspace.Terrain:FillRegion(lobbyRegion(Vector3.zero), 4, Enum.Material.Air)
	local _, originCorner = lobbyCells(Vector3.zero)
	workspace.Terrain:PasteRegion(origin, originCorner, true)
	restore(workspace.Terrain, terrainProps)
	restore(lighting, lightProps)
	for _, c in lighting:GetChildren() do
		c:Destroy()
	end
	for _, c in lightKids do
		c.Parent = lighting
	end
	for _, c in aside:GetChildren() do
		c.Parent = workspace
	end
	aside:Destroy()
	assert(ok, err)
	local m = maps :: Folder
	m:SetAttribute("Terrain", true)
	m:SetAttribute("LobbyBakedAt", os.date("%Y-%m-%d %H:%M"))
	m.Parent = workspace
	print(("[MapStore] Lobby saved as Workspace.Maps.Lobby, %d studs to the side. Edit away, then save the place."):format(MapStore.LOBBY_OFFSET.X))
end

return MapStore
