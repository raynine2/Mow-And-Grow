-- The area camps' models (owner, 29 Oct: "remake every zone hub except 1 ... if ur going to add or make stuff use
-- blender"), made in Blender: tools/blender/camp/models.py, written here by tools/blender/camp/build.py (Blender's
-- Python, bpy). Every shape is one native part (Block, Wedge, Cylinder, Ball), so nothing needs uploading.
-- DON'T EDIT THE DATA BY HAND: change models.py and run build.py (the rest of this file is its template,
-- tools/blender/camp/CampProps.template.luau).
--
-- A model's text: "m" lists its materials ("<Kind>__<RRGGBB or @role>[__T<percent>]"; Kind "Mark" is an invisible
-- marker part named after it, e.g. Smoke, Lamp, SignFace), "g name x y z" its groups (parts client/CampLife moves:
-- a windmill's sails, a gnome's arms; the pivot in the model's own studs), then one line per part: shape (b block,
-- w wedge, c cylinder, s ball; upper case when turned), size x y z, position x y z, [turn x y z in degrees,
-- CFrame.fromOrientation], material number, [group number]. The model's front faces -Z (the CFrame's LookVector).
local MaterialService = game:GetService("MaterialService")

local CampProps = {}

-- A theme's role: { kind (a material name, or nil to keep the model's), colour }.
export type Roles = { [string]: { any } }
export type PlaceOpts = { scale: number?, roles: Roles?, collide: boolean?, name: string?, atomic: boolean? }

-- the world's voxel textures (server/VoxelKit): MaterialVariants in the place; plain materials without them
local VOXEL: { [string]: { any } } = {
	VLog = { "MowVoxelLog", Enum.Material.Wood },
	VStone = { "MowVoxelStone1", Enum.Material.Cobblestone },
	VPlank = { "MowVoxelPlanks", Enum.Material.WoodPlanks },
	VRoof = { "MowVoxelRoof", Enum.Material.RoofShingles },
	VMetal = { "MowVoxelMetal3", Enum.Material.CorrodedMetal },
}
local hasVariant: { [string]: boolean } = {}
local function variant(name: string): boolean
	if hasVariant[name] == nil then
		hasVariant[name] = MaterialService:FindFirstChild(name, true) ~= nil
	end
	return hasVariant[name]
end

local DATA: { [string]: string } = {
--@@DATA@@
}

type Mat = { kind: string, col: string, t: number }
type Spec = { mats: { Mat }, groups: { { name: string, pivot: Vector3 } }, parts: { { any } } }
local specs: { [string]: Spec } = {}

local function decode(name: string): Spec?
	local cached = specs[name]
	if cached then
		return cached
	end
	local text = DATA[name]
	if not text then
		return nil
	end
	local s: Spec = { mats = {}, groups = {}, parts = {} }
	for line in string.gmatch(text, "[^\n]+") do
		local f = string.split(line, " ")
		local tag = f[1]
		if tag == "m" then
			for i = 2, #f do
				local bits = string.split(f[i], "__")
				table.insert(s.mats, { kind = bits[1], col = bits[2], t = if bits[3] then (tonumber(string.sub(bits[3], 2)) or 0) / 100 else 0 })
			end
		elseif tag == "g" then
			table.insert(s.groups, { name = f[2], pivot = Vector3.new(tonumber(f[3]) or 0, tonumber(f[4]) or 0, tonumber(f[5]) or 0) })
		else
			local n = table.create(#f - 1)
			for i = 2, #f do
				n[i - 1] = tonumber(f[i]) or 0
			end
			table.insert(s.parts, { tag, n })
		end
	end
	specs[name] = s
	return s
end

function CampProps.has(name: string): boolean
	return DATA[name] ~= nil
end

-- The materials of a model with `roles` filled in.
local function resolve(spec: Spec, roles: Roles): { any }
	local out = {}
	for i, mt in spec.mats do
		local kind, col = mt.kind, mt.col
		if kind == "Mark" then
			out[i] = { mark = col }
			continue
		end
		local color = Color3.new(1, 1, 1)
		if string.sub(col, 1, 1) == "@" then
			local r = roles[string.sub(col, 2)]
			if r then
				color = r[2] or color
				if r[1] then
					kind = r[1]
				end
			end
		else
			color = Color3.fromHex(col)
		end
		local material, variantName = nil, nil
		local v = VOXEL[kind]
		if v then
			material = v[2]
			variantName = if variant(v[1]) then v[1] else nil
		else
			local ok, m = pcall(function()
				return (Enum.Material :: any)[kind]
			end)
			material = if ok and m then m else Enum.Material.Plastic
		end
		out[i] = { material = material, variant = variantName, color = color, t = mt.t }
	end
	return out
end

local SHAPE = { b = Enum.PartType.Block, c = Enum.PartType.Cylinder, s = Enum.PartType.Ball }

-- Build model `name` at `cf` (its ground point, front toward cf.LookVector) into `parent`. Decoration (no
-- collisions) unless opts.collide. Parts of a group get the attribute G = the group's name; the model gets
-- "Pivot_<group>" (its pivot in the model's studs) and NParts. nil when there's no such model.
function CampProps.place(name: string, parent: Instance, cf: CFrame, opts: PlaceOpts?): Model?
	local o = opts or {}
	local spec = decode(name)
	if not spec then
		return nil
	end
	local k = o.scale or 1
	local mats = resolve(spec, o.roles or {})
	local model = Instance.new("Model")
	model.Name = o.name or name
	if o.atomic then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	local n = 0
	for _, p in spec.parts do
		local tag: string, v = p[1], p[2]
		local low = string.lower(tag)
		local rx, ry, rz, mi, gi = 0, 0, 0, v[7], v[8]
		if tag ~= low then
			rx, ry, rz, mi, gi = v[7], v[8], v[9], v[10], v[11]
		end
		local mt = mats[mi]
		local part: BasePart
		if low == "w" then
			part = Instance.new("WedgePart")
		else
			local pp = Instance.new("Part")
			pp.Shape = SHAPE[low] or Enum.PartType.Block
			part = pp
		end
		local size = Vector3.new(v[1], v[2], v[3]) * k
		part.Size = size
		part.CFrame = cf * CFrame.new(v[4] * k, v[5] * k, v[6] * k) * CFrame.fromOrientation(math.rad(rx), math.rad(ry), math.rad(rz))
		part.Anchored = true
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if mt and mt.mark then
			part.Name = mt.mark
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		else
			part.Name = "P"
			part.Material = mt.material
			if mt.variant then
				part.MaterialVariant = mt.variant
			end
			part.Color = mt.color
			part.Transparency = mt.t
			local big = math.max(size.X, size.Y, size.Z) >= 1.6
			part.CanCollide = o.collide == true and big
			part.CanQuery = o.collide == true and big
			part.CastShadow = big
		end
		if gi and spec.groups[gi] then
			part:SetAttribute("G", spec.groups[gi].name)
		end
		part.Parent = model
		n += 1
	end
	for _, g in spec.groups do
		model:SetAttribute("Pivot_" .. g.name, g.pivot * k)
	end
	model:SetAttribute("NParts", n)
	model.WorldPivot = cf
	model.Parent = parent
	return model
end

-- The marker parts called `name` in a placed model (Smoke, Lamp, SignFace, Hand ...).
function CampProps.markers(model: Instance, name: string): { BasePart }
	local out = {}
	for _, d in model:GetChildren() do
		if d.Name == name and d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Turn group `g` of a placed model about its pivot by `rot` (in the model's own axes), e.g. a signpost's arrow.
function CampProps.turnGroup(model: Model, g: string, rot: CFrame)
	local pivot = model:GetAttribute("Pivot_" .. g)
	if typeof(pivot) ~= "Vector3" then
		return
	end
	local at = model:GetPivot() * CFrame.new(pivot)
	local move = at * rot * at:Inverse()
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("G") == g then
			d.CFrame = move * d.CFrame
		end
	end
end

return CampProps
