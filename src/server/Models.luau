-- Blender models in the game. tools/upload_models.py uploads assets/models/*.glb and writes their ids into
-- shared/ModelIds.luau; at server start this loads them (InsertService), gives every MeshPart the Roblox
-- Material + Color encoded in its name ("Wood__7A4630"), anchors them, and keeps a template per model.
-- Builders call Models.place(name, parent, cframe, scale) and fall back to their part-built version when a
-- model isn't uploaded yet (Models.place returns nil).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ModelIds = require(ReplicatedStorage.MowALawn.ModelIds)
local ForgeModelIds = require(ReplicatedStorage.MowALawn.ForgeModelIds)
local Config = require(ReplicatedStorage.MowALawn.Config)

local Models = {}

-- voxel props that keep their own collisions (the rest get invisible colliders from their builders)
local VOXEL_SOLID = {
	turntable = true,
	lantern_post = true,
	gas_pump = true,
	bench = true,
	mower_statue = true,
	crate_stack = true,
	barrel = true,
	hay_bale = true,
	planter = true,
	wheelbarrow = true,
}

local templates: { [string]: Model } = {}
-- (29 Oct) one folder only: a second, empty one (an edit-time require leaves one in the saved place) made the
-- clients' FindFirstChild pick the empty folder, so the first-person tools never got their models
local folder = ReplicatedStorage:FindFirstChild("MowALawnModels") or Instance.new("Folder")
folder.Name = "MowALawnModels"
folder.Parent = ReplicatedStorage

local function parseColor(hex: string): Color3?
	if #hex ~= 6 then
		return nil
	end
	local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
	if not r or not g or not b then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

-- Turn the imported asset into a clean template: one Model, MeshParts styled from their names, pivot at the
-- Blender origin (marked by the "Origin__000000" triangle).
local function prepare(name: string, asset: Instance): Model?
	local model = Instance.new("Model")
	model.Name = name
	local origin: BasePart? = nil
	for _, d in asset:GetDescendants() do
		if d:IsA("BasePart") then
			local kind, hex = d.Name:match("^(%w+)__(%x+)")
			if kind == "Origin" then
				origin = d
			else
				if kind then
					local ok = pcall(function()
						d.Material = (Enum.Material :: any)[kind]
					end)
					if not ok then
						d.Material = Enum.Material.Plastic
					end
					local c = hex and parseColor(hex)
					if c then
						d.Color = c
					end
					if kind == "Neon" then
						d.CastShadow = false
					end
					-- "Glass__2E786E__T35" = 35% transparent (water, glow sheets)
					local see = d.Name:match("__T(%d+)$")
					if see then
						d.Transparency = (tonumber(see) :: number) / 100
						d.CastShadow = false
					end
				end
				-- the importer may add textures/surface appearances from the glTF material; we want Roblox materials
				for _, extra in d:GetChildren() do
					if extra:IsA("SurfaceAppearance") then
						extra:Destroy()
					end
				end
				if d:IsA("MeshPart") then
					pcall(function()
						(d :: any).TextureID = ""
					end)
				end
				d.Anchored = true
				d.CanTouch = false
				d.Parent = model
			end
		end
	end
	if #model:GetChildren() == 0 then
		return nil
	end
	-- Roblox's importer turns the model 180 degrees around Y (the front ends up facing +Z). Turning the pivot
	-- back means a placed model's front faces its CFrame's LookVector, and model-space coordinates match the
	-- glTF file (x = x, y = up, z = glTF z).
	local pivot = if origin then CFrame.new(origin.Position) else model:GetBoundingBox()
	model.WorldPivot = pivot * CFrame.Angles(0, math.pi, 0)
	model:PivotTo(CFrame.new())
	model.Parent = folder
	return model
end

-- Native-part versions of the Blender models (server/PartModels, made by tools/blender/to_parts.py): no mesh
-- upload needed. Used for any model that isn't uploaded.
local partModels = script.Parent:FindFirstChild("PartModels")
local SHAPES = { B = Enum.PartType.Block, C = Enum.PartType.Cylinder, S = Enum.PartType.Ball }

-- A template from a PartModels spec. Its parts are already in the model's own studs (front = -Z), so the pivot
-- is simply the origin.
local function buildFromParts(name: string, spec: { materials: { string }, parts: { { any } } }): Model
	local model = Instance.new("Model")
	model.Name = name
	for _, p in spec.parts do
		local part: BasePart
		if p[1] == "W" then
			part = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			block.Shape = SHAPES[p[1]] or Enum.PartType.Block
			part = block
		end
		part.Size = Vector3.new(p[2], p[3], p[4])
		part.CFrame = CFrame.new(p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13], p[14], p[15], p[16])
		if p[1] == "E" then
			-- an ellipsoid: a block with a Sphere mesh filling it
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		local matName = spec.materials[p[17]] or "Plastic__A3A2A5"
		local kind, hex = matName:match("^(%w+)__(%x+)")
		pcall(function()
			part.Material = (Enum.Material :: any)[kind]
		end)
		local c = hex and parseColor(hex)
		if c then
			part.Color = c
		end
		local see = matName:match("__T(%d+)")
		if see then
			part.Transparency = (tonumber(see) :: number) / 100
		end
		if kind == "Neon" or see then
			part.CastShadow = false
		end
		-- moving parts (Wheel*, Blade*, ExhaustTip) carry their own name so the game can animate them
		part.Name = if type(p[18]) == "string" then p[18] else matName
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanTouch = false
		part.Parent = model
	end
	-- (30 Oct) effects plain part data can't carry (lights, particles, glows): the spec's own dress()
	if type((spec :: any).dress) == "function" then
		local ok, err = pcall((spec :: any).dress, model)
		if not ok then
			warn(("[Models] %s dress: %s"):format(name, tostring(err)))
		end
	end
	model.WorldPivot = CFrame.new()
	model.Parent = folder
	return model
end

-- Sculpted, texture-baked "toy" versions of some models (tools/blender/toy, method by fwjelaa / FWJ STUDIOS). Their
-- FBX files (assets/toy_models) come in through Studio's Import 3D and live in ServerStorage.ToyModels, named like
-- the keys below. Each replaces the game model `name`, scaled to that model's height (or `height` when it has
-- none). turn = degrees about Y that make the mesh face its pivot's LookVector.
local TOY_MODELS: { [string]: { name: string, height: number, turn: number } } = {
	DandelionKing = { name = "boss_dandelion", height = 17.5, turn = 180 },
	ThornBush = { name = "boss_thornbush", height = 16, turn = 180 },
	VenusFlytrap = { name = "boss_flytrap", height = 18, turn = 180 },
	SwampVine = { name = "boss_vine", height = 20, turn = 180 },
	JungleTitan = { name = "boss_jungle", height = 22, turn = 180 },
	-- nature
	Oak = { name = "oak", height = 30, turn = 180 },
	OakSmall = { name = "oak_small", height = 22, turn = 180 },
	Birch = { name = "birch", height = 28, turn = 180 },
	JungleTree = { name = "jungle_tree", height = 34, turn = 180 },
	Bush = { name = "bush", height = 5, turn = 180 },
	Rock = { name = "rock", height = 4, turn = 180 },
	Stump = { name = "stump", height = 3, turn = 180 },
	Log = { name = "log", height = 3, turn = 180 },
	-- the grass clumps you mow, and the stubble they leave
	TuftLawn = { name = "tuft_lawn", height = 4, turn = 180 },
	TuftLawnCut = { name = "tuft_lawn_cut", height = 1, turn = 180 },
	TuftGolf = { name = "tuft_golf", height = 3, turn = 180 },
	TuftGolfCut = { name = "tuft_golf_cut", height = 0.8, turn = 180 },
	TuftWheat = { name = "tuft_wheat", height = 5, turn = 180 },
	TuftWheatCut = { name = "tuft_wheat_cut", height = 1.2, turn = 180 },
	TuftReeds = { name = "tuft_reeds", height = 6, turn = 180 },
	TuftReedsCut = { name = "tuft_reeds_cut", height = 1.2, turn = 180 },
	TuftJungle = { name = "tuft_jungle", height = 4.5, turn = 180 },
	TuftJungleCut = { name = "tuft_jungle_cut", height = 1, turn = 180 },
}

-- A template from an imported toy mesh: the mesh part(s) anchored, pivot at the feet (bottom centre of the
-- bounds), scaled to `height` studs.
local function buildFromToy(toyName: string, src: Instance, height: number): Model?
	local info = TOY_MODELS[toyName]
	local model = Instance.new("Model")
	model.Name = info.name
	local sources = if src:IsA("BasePart") then { src } else src:GetDescendants()
	local count = 0
	for _, d in sources do
		if d:IsA("BasePart") then
			local p = d:Clone()
			p.Anchored = true
			p.CanTouch = false
			p.Parent = model
			count += 1
		end
	end
	if count == 0 then
		model:Destroy()
		return nil
	end
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, math.rad(info.turn), 0)
	model:ScaleTo(height / size.Y)
	model.Parent = folder
	return model
end

-------------------------------------------------------------------------------------------------------------
-- ForgeGUI buildings (shared/ForgeModelIds): one textured MeshPart each, front at the mesh's -X
-------------------------------------------------------------------------------------------------------------
-- Older models a ForgeGUI building replaces. The new one is fitted into the old one's box (same height, no
-- wider than the old one) and stands on the same spot, so builders keep placing it the same way.
local FORGE_SWAP: { [string]: string } = {
	bag_stand = "bagstand",
	shredder = "shredder",
	rewards_stall = "rewards",
	leaderboard = "leaderboard",
	trophy_board = "leaderboard",
}
local forgeRaw: { [string]: Model } = {}
-- The ForgeGUI models made on 26 Oct come with their front at the mesh's +Z (the older ones: -X).
local FRONT_PLUS_Z: { [string]: boolean } = {}
for _, n in { "fountain", "dropoff", "partybooth", "altar", "gate_wheat", "gate_blossom", "gate_pine", "gate_swamp", "gate_frost", "gate_ember", "gate_starlight", "arena_meadow", "arena_hedge", "arena_bunker", "arena_cornfield", "arena_sakura", "arena_swamp", "arena_pumpkin", "arena_ruins", "arena_frost", "arena_ember", "arena_starlight" } do
	FRONT_PLUS_Z[n] = true
end
-- (and the boss arenas' walls, pillars and props: server/ArenaDress)
for _, area in { "meadow", "wheat", "blossom", "pine", "swamp", "frost", "ember", "starlight" } do
	FRONT_PLUS_Z["awall_" .. area] = true
	FRONT_PLUS_Z["vwall_" .. area] = true
	FRONT_PLUS_Z["varena_" .. area] = true
	FRONT_PLUS_Z["apost_" .. area] = true
	FRONT_PLUS_Z["aprop_" .. area .. "1"] = true
	FRONT_PLUS_Z["aprop_" .. area .. "2"] = true
end

-- A template from a loaded ForgeGUI asset: the mesh (texture kept), pivot at the bottom centre, front toward
-- the pivot's LookVector (-Z).
local function prepareForge(name: string, asset: Instance): Model?
	local mesh = asset:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "forge_" .. name
	mesh.Name = "Body"
	mesh.Anchored = true
	mesh.CanTouch = false
	-- the mesh's front is its -X: turning it -90 degrees about Y points that at -Z (a +Z front: half a turn)
	mesh.CFrame = CFrame.new(0, mesh.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(if FRONT_PLUS_Z[name] then 180 else -90), 0)
	mesh.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

local function loadForge(): number
	local pending = 0
	for name, id in ForgeModelIds do
		pending += 1
		task.spawn(function()
			local ok, result = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			local m = ok and result and prepareForge(name, result)
			if m then
				forgeRaw[name] = m
				m.Parent = folder
				templates[m.Name] = m
			else
				warn(("[Models] couldn't load ForgeGUI model %s (%d): %s"):format(name, id, tostring(result)))
			end
			if ok and result then
				result:Destroy()
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 20
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	return pending
end

-- The scale that fits a model of size `have` into `want` (any of height / width / depth; nil = no limit).
function Models.fitScale(have: Vector3, want: { height: number?, width: number?, depth: number? }): number
	local k = math.huge
	if want.height then
		k = math.min(k, want.height / have.Y)
	end
	if want.width then
		k = math.min(k, want.width / have.X)
	end
	if want.depth then
		k = math.min(k, want.depth / have.Z)
	end
	return if k == math.huge then 1 else k
end

-- Swap the old templates for their ForgeGUI buildings, fitted into the old ones' boxes.
local function swapForge()
	for oldName, forgeName in FORGE_SWAP do
		local raw = forgeRaw[forgeName]
		local old = templates[oldName]
		if raw and old then
			local box, size = old:GetBoundingBox()
			local k = Models.fitScale(raw:GetExtentsSize(), { height = size.Y, width = size.X * 1.1 })
			local m = raw:Clone()
			m.Name = oldName
			-- resize the parts themselves, not with ScaleTo: Models.place's ScaleTo(scale) is absolute and would undo it
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.Size *= k
					p.CFrame = p.CFrame.Rotation + p.Position * k
				end
			end
			-- stand it where the old one stood: same bottom centre (in the template's own space)
			local foot = box.Position - Vector3.new(0, size.Y / 2, 0)
			m:PivotTo(CFrame.new(foot))
			m.WorldPivot = CFrame.new()
			m:SetAttribute("Forge", true)
			m.Parent = folder
			old:Destroy()
			templates[oldName] = m
		end
	end
end

-- Is the template `name` a ForgeGUI building (so builders can skip extras the older model needed)?
function Models.isForge(name: string): boolean
	local t = templates[name]
	return t ~= nil and (t:GetAttribute("Forge") == true or string.sub(t.Name, 1, 6) == "forge_")
end

-- A ForgeGUI building ("bagstand", "barn"...) at `cf` (feet there, front toward cf.LookVector), scaled to fit
-- `want` (height / width / depth in studs). Returns nil if it isn't loaded.
function Models.placeForge(name: string, parent: Instance, cf: CFrame, want: { height: number?, width: number?, depth: number? }, noCollide: boolean?): Model?
	local raw = forgeRaw[name]
	if not raw then
		return nil
	end
	return Models.place(raw.Name, parent, cf, Models.fitScale(raw:GetExtentsSize(), want), noCollide)
end

-------------------------------------------------------------------------------------------------------------
-- ForgeGUI tools (31 Oct, owner: "revamp the mega sytche model witth forgegui")
-------------------------------------------------------------------------------------------------------------
-- A ForgeGUI mesh that takes over a tool template's look. The template keeps its frame (for the scythe: the grip
-- at the origin, the snath along -Z at y 0, the head at its far end with the blade rising +Y and sweeping back
-- toward the hands), so the held tool (server/Tools), the first-person view (client/ViewModel) and the shop boards
-- hold and place it as before. `turn` takes the mesh's own axes to the template's, `length` is its size along the
-- template's Z (the snath) in the template's studs, `center` where its middle goes. `light`: a violet light in the
-- blade's curve; `gem`: a faint one at the pommel; `sparkle`: spots along the blade sparkles drift from; `trail`:
-- the blade's root and tip, where server/Tools hangs the swing trail ("TrailA", "TrailB"). (All attachments in the
-- mesh, no helper parts: client/ViewModel shows every part of the tool you hold, an unseen one too. No emissive glow
-- from the texture: a game script may not set a SurfaceAppearance's EmissiveMaskContent.)
type ForgeTool = {
	forge: string,
	turn: CFrame,
	length: number,
	center: Vector3,
	light: Vector3?,
	gem: Vector3?,
	sparkle: { Vector3 }?,
	trail: { Vector3 }?,
}
local FORGE_TOOLS: { [string]: ForgeTool } = {
	tool_scythe = {
		forge = "megascythe",
		-- (the mesh stands up its +Y, the head at the top, the blade out to its +X: the head goes to -Z, the blade to +Y)
		turn = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0)),
		-- (measured in Studio: like the part model, the butt at z 2.6, the snath's axis at y 0, the head at -5.25,
		-- the blade up to y 5.4 with its tip back at z -1.4, the side grip at -2.5)
		length = 9.7,
		center = Vector3.new(0, 1.95, -2.25),
		light = Vector3.new(0, 3.4, -4.2),
		gem = Vector3.new(0, 0, 2.35),
		sparkle = { Vector3.new(0, 2.6, -6.2), Vector3.new(0, 4, -5.2), Vector3.new(0, 4.6, -4), Vector3.new(0, 5, -2.9), Vector3.new(0, 5.2, -1.9) },
		trail = { Vector3.new(0, 2.6, -5.6), Vector3.new(0, 5.15, -1.7) },
	},
}

-- a spot on a tool's mesh (`at` in the template's studs) for a light or an emitter
local function spot(mesh: MeshPart, name: string, at: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = mesh.CFrame:ToObjectSpace(CFrame.new(at))
	a.Parent = mesh
	return a
end

local function lightAt(mesh: MeshPart, name: string, at: Vector3, color: Color3, range: number, brightness: number)
	local p = spot(mesh, name, at)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = p
end

local function swapTools(): number
	local n = 0
	for name, t in FORGE_TOOLS do
		local raw = forgeRaw[t.forge]
		local body = raw and raw:FindFirstChild("Body") :: MeshPart?
		if not body then
			continue
		end
		local model = Instance.new("Model")
		model.Name = name
		local mesh = body:Clone()
		mesh.Size *= t.length / math.abs(t.turn:VectorToWorldSpace(mesh.Size).Z)
		mesh.CFrame = CFrame.new(t.center) * t.turn
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.Parent = model
		if t.light then
			lightAt(mesh, "BladeLight", t.light, Color3.fromRGB(190, 110, 255), 9, 1.3)
		end
		if t.gem then
			lightAt(mesh, "PommelGem", t.gem, Color3.fromRGB(230, 190, 255), 3.5, 1)
		end
		for _, at in t.sparkle or {} do
			local e = Instance.new("ParticleEmitter")
			e.Name = "EdgeSparkle"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 235, 255), Color3.fromRGB(186, 84, 255))
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.22), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new(0.1, 1)
			e.Lifetime = NumberRange.new(0.5, 0.9)
			e.Rate = 1.5
			e.Speed = NumberRange.new(0.2, 0.6)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-90, 90)
			e.Drag = 2
			e.Parent = spot(mesh, "Sparkle", at)
		end
		if t.trail then
			spot(mesh, "TrailA", t.trail[1])
			spot(mesh, "TrailB", t.trail[2])
		end
		model.WorldPivot = CFrame.new()
		model:SetAttribute("ForgeTool", true)
		model.Parent = folder
		local old = templates[name]
		if old then
			old:Destroy()
		end
		templates[name] = model
		n += 1
	end
	return n
end

-------------------------------------------------------------------------------------------------------------
-- generated props (ServerStorage.GenProps: made with Roblox's mesh generator in Studio, 29 Oct)
-------------------------------------------------------------------------------------------------------------
-- The owner, 29 Oct: "remake all lanterns, gas pumps and all stands" and "you use the wrong backpacks". Every child
-- of ServerStorage.GenProps is a ready template (textured MeshParts, pivot at the bottom centre, front toward the
-- pivot's LookVector) named like the game model it replaces: lantern_post (with its own light), gas_pump, the bags
-- (bag_satchel, bag_backpack, bag_hiker, bag_infinite) and the camps' market stalls (stall_<area>: server/Outposts).
-- It's fitted into the old template's box (its height, no wider than 1.1 x), so builders keep placing it the same
-- way; one with no old template is used as it is. Points a builder needs ride along as attributes in the template's
-- own studs (LightAt: the lamp's glass; SignAt / SignSize: a stall's name board; CounterAt / CounterSize: its
-- counter) and are scaled with it. The asset ids are in assets/genprops.json.
local function swapGen(): number
	local src = ServerStorage:FindFirstChild("GenProps")
	local n = 0
	for _, raw in (if src then src:GetChildren() else {}) do
		if raw:IsA("Model") then
			local m = raw:Clone()
			local old = templates[raw.Name]
			local k = 1
			if old then
				local _, size = old:GetBoundingBox()
				k = Models.fitScale(m:GetExtentsSize(), { height = size.Y, width = size.X * 1.1 })
			end
			if math.abs(k - 1) > 0.001 then
				-- (the parts themselves, as swapForge does: Models.place's ScaleTo is absolute)
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then
						p.Size *= k
						p.CFrame = p.CFrame.Rotation + p.Position * k
					end
				end
				for key, v in m:GetAttributes() do
					if typeof(v) == "Vector3" or typeof(v) == "Vector2" then
						m:SetAttribute(key, v * k)
					elseif typeof(v) == "CFrame" then
						m:SetAttribute(key, v.Rotation + v.Position * k)
					end
				end
			end
			m:SetAttribute("Gen", true)
			m.WorldPivot = CFrame.new()
			m.Parent = folder
			if old then
				old:Destroy()
			end
			templates[raw.Name] = m
			n += 1
		end
	end
	return n
end

-- Is the template `name` one of the generated props (ServerStorage.GenProps)?
function Models.isGen(name: string): boolean
	local t = templates[name]
	return t ~= nil and t:GetAttribute("Gen") == true
end

-- Loads every model at the same time (one at a time took ~30 s) and waits at most `timeout` seconds; a model
-- that isn't loaded by then uses its native-part version if it has one, else its brick fallback.
function Models.loadAll(timeout: number?)
	-- (31 Oct) a fresh set each time: every load in edit mode (RunWorld.refreshForge, MapStore) left its copies in
	-- the folder and the place was saved with 7 of each template, so a client looking one up by name
	-- (client/ViewModel, HitFx, SellFx) could get a stale one (the old Mega Scythe in first person)
	for _, c in folder:GetChildren() do
		c:Destroy()
	end
	table.clear(templates)
	table.clear(forgeRaw)
	-- the ForgeGUI buildings load alongside the rest
	local forgeLeft: number? = nil
	task.spawn(function()
		forgeLeft = loadForge()
	end)
	local pending = 0
	local failed = 0
	for name, id in ModelIds do
		pending += 1
		task.spawn(function()
			local ok, result = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if ok and result then
				local m = prepare(name, result)
				if m then
					templates[name] = m
				end
				result:Destroy()
			else
				failed += 1
				warn(("[Models] couldn't load %s (%d): %s"):format(name, id, tostring(result)))
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + (timeout or 20)
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	local loaded = 0
	for _ in templates do
		loaded += 1
	end
	print(("[Models] %d models loaded, %d failed, %d still loading"):format(loaded, failed, pending))
	if failed > 0 then
		warn("[Models] Models only load in a game owned by the account that uploaded them (see tools/upload_models.py). Using brick versions for the missing ones.")
	end
	-- models that aren't uploaded but have a native-part version (PartModels) are built from that
	local built = 0
	-- (30 Oct) a spec with `prefer` replaces even a loaded upload (the Mega Scythe: its part version was reworked
	-- after the upload, so the old mesh would bring back the blade curling over the hands)
	for _, module in partModels and partModels:GetChildren() or {} do
		if module:IsA("ModuleScript") then
			local ok, err = pcall(function()
				local spec = require(module) :: any
				local old = templates[module.Name]
				if old and not spec.prefer then
					return
				end
				templates[module.Name] = buildFromParts(module.Name, spec)
				built += 1
				if old then
					old:Destroy()
				end
			end)
			if not ok then
				warn(("[Models] couldn't build %s from parts: %s"):format(module.Name, tostring(err)))
			end
		end
	end
	if built > 0 then
		print(("[Models] %d models built from native parts"):format(built))
	end
	-- sculpted toy versions (imported meshes in ServerStorage.ToyModels) replace their model
	local toys = 0
	local toyFolder = ServerStorage:FindFirstChild("ToyModels")
	for toyName, info in TOY_MODELS do
		local src = toyFolder and toyFolder:FindFirstChild(toyName)
		if src then
			local old = templates[info.name]
			local height = info.height
			if old then
				local _, size = old:GetBoundingBox()
				height = size.Y
			end
			local ok, m = pcall(buildFromToy, toyName, src, height)
			if ok and m then
				if old then
					old:Destroy()
				end
				templates[info.name] = m
				toys += 1
			else
				warn(("[Models] couldn't use toy model %s: %s"):format(toyName, tostring(m)))
			end
		end
	end
	if toys > 0 then
		print(("[Models] %d sculpted toy models in use"):format(toys))
	end
	-- the generated world's voxel versions of the hub buildings and props (ServerStorage.VoxelModels "Prop_<name>",
	-- from tools/blender/voxel/props.py) replace their model, laid out like it (shared/ModelOrigins)
	local voxels = 0
	if Config.WORLD_GEN then
		local VoxelModels = require(script.Parent.VoxelModels)
		local Origins = require(ReplicatedStorage.MowALawn.ModelOrigins)
		-- a prop can be several meshes ("Prop_<name>" and "Prop_<name>__<piece>"), each at its own origin
		local groups: { [string]: { { mesh: string, origin: Vector3 } } } = {}
		for meshName, origin in Origins do
			local rest = string.sub(meshName, 6)
			local name = string.match(rest, "^(.-)__") or rest
			groups[name] = groups[name] or {}
			table.insert(groups[name], { mesh = meshName, origin = origin })
		end
		for name, pieces in groups do
			local model = Instance.new("Model")
			model.Name = name
			local holder = Instance.new("Folder")
			local count = 0
			for _, piece in pieces do
				local mesh = VoxelModels.place(holder, piece.mesh, Vector3.zero)
				if mesh then
					-- VoxelModels.place stands it at the origin facing -Z; move it to where the toy model's parts were
					mesh.CFrame = CFrame.new(piece.origin) * mesh.CFrame
					mesh.CanCollide = VOXEL_SOLID[name] == true and not string.find(piece.mesh, "__", 1, true)
					mesh.CanQuery = mesh.CanCollide
					mesh.CastShadow = not string.find(piece.mesh, "__", 1, true) or mesh.Size.Magnitude > 4
					mesh.Parent = model
					count += 1
				end
			end
			holder:Destroy()
			if count > 0 then
				model.WorldPivot = CFrame.new()
				model.Parent = folder
				local old = templates[name]
				if old then
					old:Destroy()
				end
				templates[name] = model
				voxels += 1
			else
				model:Destroy()
			end
		end
	end
	if voxels > 0 then
		print(("[Models] %d voxel props in use"):format(voxels))
	end
	-- the hub buildings and props built from parts in Chop A Forest's style (server/HubKit) replace those
	local kit = 0
	if Config.WORLD_GEN then
		local HubKit = require(script.Parent.HubKit)
		local VoxelModels = require(script.Parent.VoxelModels)
		local SmoothOrigins = require(ReplicatedStorage.MowALawn.SmoothOrigins)
		for _, name in HubKit.NAMES do
			-- the Blender version (tools/blender/smooth, mesh S_<name>) when it's imported, else built from parts
			local m: Model? = nil
			local sname = "S_" .. name
			if VoxelModels.has(sname) and SmoothOrigins[sname] then
				m = Instance.new("Model")
				local model = m :: Model
				model.Name = name
				local holder = Instance.new("Folder")
				local mesh = VoxelModels.place(holder, sname, Vector3.zero) :: MeshPart
				mesh.CFrame = CFrame.new(SmoothOrigins[sname]) * mesh.CFrame
				mesh.CanCollide = VOXEL_SOLID[name] == true
				mesh.CanQuery = mesh.CanCollide
				mesh.Parent = model
				holder:Destroy()
				model.WorldPivot = CFrame.new()
			else
				m = HubKit.build(name)
			end
			if m then
				m.Parent = folder
				local old = templates[name]
				if old then
					old:Destroy()
				end
				templates[name] = m
				kit += 1
			end
		end
		print(("[Models] %d hub models built from parts (HubKit)"):format(kit))
	end
	while forgeLeft == nil do
		task.wait(0.1)
	end
	swapForge()
	local tools = swapTools()
	if tools > 0 then
		print(("[Models] %d tools remade with ForgeGUI"):format(tools))
	end
	local forged = 0
	for _ in forgeRaw do
		forged += 1
	end
	print(("[Models] %d ForgeGUI buildings loaded (%d not loaded)"):format(forged, forgeLeft or 0))
	local gens = swapGen()
	if gens > 0 then
		print(("[Models] %d generated props in use (ServerStorage.GenProps)"):format(gens))
	end
end

function Models.has(name: string): boolean
	return templates[name] ~= nil
end

-- A copy of model `name` at `cf` (its Blender origin goes there, its front faces cf.LookVector), optionally
-- scaled. Returns nil if the model isn't uploaded yet, so callers can build their fallback instead.
-- noCollide: the mesh gets no collisions (the caller adds simple invisible colliders, e.g. for walk-in
-- buildings, whose door a rough mesh collision could block).
function Models.place(name: string, parent: Instance, cf: CFrame, scale: number?, noCollide: boolean?): Model?
	local t = templates[name]
	if not t then
		return nil
	end
	local m = t:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	if noCollide then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- Attach a placed model to a moving part: unanchor, weld every part to `to`, no mass, no collisions.
function Models.weldTo(model: Model, to: BasePart)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = p
			w.Part1 = to
			w.Parent = p
		end
	end
end

return Models
