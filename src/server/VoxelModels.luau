-- The voxel Blender models (tools/blender/voxel): trees, bushes, rocks, grass clumps and landmarks for the 8
-- areas, each a single MeshPart, all sharing one texture. They come in once through Studio's Import 3D
-- (assets/models/MowModels.fbx) and live in ServerStorage.VoxelModels. Until then `available()` is false and
-- WorldArt / GrassStyle keep building their part versions, so nothing breaks either way.
-- (server/Models is the older GLB/InsertService pipeline for the other game models; this is separate.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Sizes = require(ReplicatedStorage.MowALawn.ModelSizes)

local VoxelModels = {}

-- Roblox's importer turns models 180 degrees about Y (see server/Models); this turns them back so a model's
-- front (the windmill's door) faces the CFrame's LookVector.
local TURN = CFrame.Angles(0, math.pi, 0)

local templates: { [string]: MeshPart }? = nil

local function load(): { [string]: MeshPart }
	if templates then
		return templates
	end
	local found: { [string]: MeshPart } = {}
	local folder = ServerStorage:FindFirstChild("VoxelModels")
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("MeshPart") and Sizes[d.Name] then
				found[d.Name] = d
			end
		end
	end
	templates = found
	return found
end

-- Forget the cached templates (after importing or replacing the models in Studio).
function VoxelModels.reset()
	templates = nil
end

function VoxelModels.available(): boolean
	return next(load()) ~= nil
end

function VoxelModels.has(name: string): boolean
	return load()[name] ~= nil
end

-- The model's natural size in studs (from the Blender build).
function VoxelModels.size(name: string): Vector3?
	return Sizes[name]
end

export type PlaceOptions = {
	scale: number?,
	yaw: number?,
	collide: boolean?, -- solid (with the template's collision shape); default off
	shadow: boolean?,
	name: string?,
}

-- Place a copy standing on `foot` (the middle of its footprint at ground level). Nil if that model isn't
-- imported.
function VoxelModels.place(parent: Instance, name: string, foot: Vector3, opts: PlaceOptions?): MeshPart?
	local tpl = load()[name]
	if not tpl then
		return nil
	end
	local o = opts or {}
	local size = Sizes[name] * (o.scale or 1)
	local p = tpl:Clone()
	p.Name = o.name or name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(foot) * CFrame.Angles(0, o.yaw or 0, 0) * CFrame.new(0, size.Y / 2, 0) * TURN
	p.CanCollide = o.collide == true
	p.CanQuery = o.collide == true
	p.CanTouch = false
	p.CastShadow = o.shadow ~= false
	p.Parent = parent
	return p
end

-- An invisible collision block (a tree's trunk, so players bump into trees but not their leaves).
function VoxelModels.blocker(parent: Instance, size: Vector3, cf: CFrame): Part
	local b = Instance.new("Part")
	b.Name = "Blocker"
	b.Anchored = true
	b.Transparency = 1
	b.CanTouch = false
	b.CastShadow = false
	b.Size = size
	b.CFrame = cf
	b.Parent = parent
	return b
end

return VoxelModels
