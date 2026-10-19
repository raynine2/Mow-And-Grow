-- Blender models in the game. tools/upload_models.py uploads assets/models/*.glb and writes their ids into
-- shared/ModelIds.luau; at server start this loads them (InsertService), gives every MeshPart the Roblox
-- Material + Color encoded in its name ("Wood__7A4630"), anchors them, and keeps a template per model.
-- Builders call Models.place(name, parent, cframe, scale) and fall back to their part-built version when a
-- model isn't uploaded yet (Models.place returns nil).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelIds = require(ReplicatedStorage.MowALawn.ModelIds)

local Models = {}

local templates: { [string]: Model } = {}
local folder = Instance.new("Folder")
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
		part.Name = matName
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanTouch = false
		part.Parent = model
	end
	model.WorldPivot = CFrame.new()
	model.Parent = folder
	return model
end

-- Loads every model at the same time (one at a time took ~30 s) and waits at most `timeout` seconds; a model
-- that isn't loaded by then uses its native-part version if it has one, else its brick fallback.
function Models.loadAll(timeout: number?)
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
	for _, module in partModels and partModels:GetChildren() or {} do
		if module:IsA("ModuleScript") and not templates[module.Name] then
			local ok, err = pcall(function()
				templates[module.Name] = buildFromParts(module.Name, require(module) :: any)
			end)
			if ok then
				built += 1
			else
				warn(("[Models] couldn't build %s from parts: %s"):format(module.Name, tostring(err)))
			end
		end
	end
	if built > 0 then
		print(("[Models] %d models built from native parts"):format(built))
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
