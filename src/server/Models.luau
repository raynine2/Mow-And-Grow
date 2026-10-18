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

function Models.loadAll()
	for name, id in ModelIds do
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
			warn(("[Models] couldn't load %s (%d): %s"):format(name, id, tostring(result)))
		end
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
