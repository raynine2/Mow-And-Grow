-- Builds a model from a native-part spec made by tools/blender/to_parts.py (shared/PartModels: the eggs and pets
-- the client needs; the server's own are in server/PartModels and built by server/Models).
-- Spec: { materials = { "<Material>__<RRGGBB>[__T<percent>]" }, parts = { { shape, sx, sy, sz, x, y, z, R00..R22,
-- material index[, name] } } }. Shapes: B block, C cylinder, W wedge, S ball, E ellipsoid (a block with a Sphere
-- mesh). The model's own studs: front = -Z, pivot = the origin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartBuild = {}

local SHAPES = { B = Enum.PartType.Block, C = Enum.PartType.Cylinder, S = Enum.PartType.Ball, E = Enum.PartType.Block }
local cache: { [string]: Model } = {}

local function parseColor(hex: string): Color3?
	local ok, c = pcall(Color3.fromHex, hex)
	return if ok then c else nil
end

function PartBuild.build(name: string, spec: { materials: { string }, parts: { { any } } }): Model
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
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		local matName = spec.materials[p[17]] or "SmoothPlastic__A3A2A5"
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
		if kind == "Foil" or kind == "Metal" then
			part.Reflectance = if kind == "Foil" then 0.25 else 0.1
		end
		part.Name = if type(p[18]) == "string" then p[18] else matName
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- A fresh copy of shared/PartModels/<name>, or nil if there is no such model.
function PartBuild.get(name: string): Model?
	if not cache[name] then
		local folder = ReplicatedStorage:FindFirstChild("MowALawn")
		local models = folder and folder:FindFirstChild("PartModels")
		local module = models and models:FindFirstChild(name)
		if not module or not module:IsA("ModuleScript") then
			return nil
		end
		local ok, spec = pcall(require, module)
		if not ok then
			warn("[PartBuild] " .. name .. ": " .. tostring(spec))
			return nil
		end
		cache[name] = PartBuild.build(name, spec :: any)
	end
	return cache[name]:Clone()
end

return PartBuild
