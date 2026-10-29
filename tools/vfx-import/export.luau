-- Turns a .rbxm of effects (particles, beams, attachments, parts) into JSON that tools/vfx-import/build.luau (run in
-- Studio) rebuilds instance by instance: Studio can't read a file from here, so the owner's VFX files come in as data.
-- lune run tools/vfx-import/export.luau <in.rbxm> <out.json> [rootName]
-- Kept: Model/Folder/Part (unions, meshparts become plain parts with their size and place), Attachment,
-- ParticleEmitter, Beam, Trail, lights, Texture/Decal, SpecialMesh, attributes. Dropped: humanoids, clothes,
-- accessories, scripts, welds/motors (a rig's parts keep their places).
local fs = require("@lune/fs")
local net = require("@lune/net")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local inPath, outPath, rootName = process.args[1], process.args[2], process.args[3]
local model = roblox.deserializeModel(fs.readFile(inPath))

local PROPS = {
	ParticleEmitter = { "Acceleration", "Brightness", "Color", "Drag", "EmissionDirection", "Enabled", "FlipbookFramerate", "FlipbookLayout", "FlipbookMode", "FlipbookStartRandom", "Lifetime", "LightEmission", "LightInfluence", "LockedToPart", "Orientation", "Rate", "RotSpeed", "Rotation", "Shape", "ShapeInOut", "ShapePartial", "ShapeStyle", "Size", "Speed", "SpreadAngle", "Squash", "Texture", "TimeScale", "Transparency", "VelocityInheritance", "WindAffectsDrag", "ZOffset" },
	Beam = { "Brightness", "Color", "CurveSize0", "CurveSize1", "Enabled", "FaceCamera", "LightEmission", "LightInfluence", "Segments", "Texture", "TextureLength", "TextureMode", "TextureSpeed", "Transparency", "Width0", "Width1", "ZOffset" },
	Trail = { "Brightness", "Color", "Enabled", "FaceCamera", "Lifetime", "LightEmission", "LightInfluence", "MaxLength", "MinLength", "Texture", "TextureLength", "TextureMode", "Transparency", "WidthScale" },
	Attachment = { "CFrame", "Visible" },
	Part = { "Size", "CFrame", "Anchored", "CanCollide", "CanQuery", "CanTouch", "Transparency", "Color", "Material", "Shape", "CastShadow", "Massless" },
	PointLight = { "Brightness", "Color", "Range", "Shadows", "Enabled" },
	SpotLight = { "Brightness", "Color", "Range", "Shadows", "Enabled", "Angle", "Face" },
	SurfaceLight = { "Brightness", "Color", "Range", "Shadows", "Enabled", "Angle", "Face" },
	Texture = { "Texture", "Face", "Transparency", "Color3", "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV" },
	Decal = { "Texture", "Face", "Transparency", "Color3" },
	SpecialMesh = { "MeshId", "TextureId", "MeshType", "Scale", "Offset" },
}
local PARTLIKE = { Part = true, MeshPart = true, UnionOperation = true, WedgePart = true, TrussPart = true }
local BASEPART = { "Size", "CFrame", "Anchored", "CanCollide", "CanQuery", "CanTouch", "Transparency", "Color", "Material", "CastShadow", "Massless" }

local function enc(v: any): any
	local t = typeof(v)
	if t == "number" or t == "boolean" or t == "string" then
		return v
	elseif t == "Vector3" then
		return { t = "V3", v = { v.X, v.Y, v.Z } }
	elseif t == "Vector2" then
		return { t = "V2", v = { v.X, v.Y } }
	elseif t == "CFrame" then
		return { t = "CF", v = { v:GetComponents() } }
	elseif t == "Color3" then
		return { t = "C3", v = { v.R, v.G, v.B } }
	elseif t == "NumberRange" then
		return { t = "NR", v = { v.Min, v.Max } }
	elseif t == "NumberSequence" then
		local k = {}
		for _, p in v.Keypoints do
			table.insert(k, { p.Time, p.Value, p.Envelope })
		end
		return { t = "NS", v = k }
	elseif t == "ColorSequence" then
		local k = {}
		for _, p in v.Keypoints do
			table.insert(k, { p.Time, p.Value.R, p.Value.G, p.Value.B })
		end
		return { t = "CS", v = k }
	elseif t == "EnumItem" then
		return { t = "E", v = { tostring(v.EnumType), v.Name } }
	end
	return nil
end

local nextId = 0
local ids: { [any]: number } = {}
local function node(i: any): any?
	local class = i.ClassName
	if class == "Humanoid" or class == "Shirt" or class == "Pants" or class == "BodyColors" or class == "HumanoidDescription"
		or class == "Accessory" or class == "Weld" or class == "Motor6D" or class == "Animator" or class == "CharacterMesh"
		or class == "StringValue" or class == "Vector3Value" or class == "AccessoryDescription" or class == "BodyPartDescription"
		or string.find(class, "Script") then
		return nil
	end
	local out: any = { c = class, n = i.Name, p = {}, a = {}, k = {} }
	local list = PROPS[class]
	if PARTLIKE[class] then
		out.c = "Part"
		list = BASEPART
	elseif class ~= "Model" and class ~= "Folder" and not list then
		return nil
	end
	nextId += 1
	ids[i] = nextId
	out.id = nextId
	for _, prop in (list or {}) do
		local ok, v = pcall(function()
			return i[prop]
		end)
		if ok then
			local e = enc(v)
			if e ~= nil then
				out.p[prop] = e
			end
		end
	end
	for k, v in i:GetAttributes() do
		local e = enc(v)
		if e ~= nil then
			out.a[k] = e
		end
	end
	for _, c in i:GetChildren() do
		local n = node(c)
		if n then
			table.insert(out.k, n)
		end
	end
	return out
end

local roots = {}
for _, r in model do
	local n = node(r)
	if n then
		if rootName then
			n.n = rootName
		end
		table.insert(roots, n)
	end
end
-- references: a beam's attachments, a model's PrimaryPart
local refs = {}
for _, r in model do
	local all = r:GetDescendants()
	table.insert(all, r)
	for _, d in all do
		if d.ClassName == "Beam" and ids[d] then
			local a0, a1 = d.Attachment0, d.Attachment1
			table.insert(refs, { ids[d], "Attachment0", a0 and ids[a0] or 0 })
			table.insert(refs, { ids[d], "Attachment1", a1 and ids[a1] or 0 })
		elseif d.ClassName == "Trail" and ids[d] then
			local a0, a1 = d.Attachment0, d.Attachment1
			table.insert(refs, { ids[d], "Attachment0", a0 and ids[a0] or 0 })
			table.insert(refs, { ids[d], "Attachment1", a1 and ids[a1] or 0 })
		elseif d.ClassName == "Model" and ids[d] then
			local pp = d.PrimaryPart
			if pp and ids[pp] then
				table.insert(refs, { ids[d], "PrimaryPart", ids[pp] })
			end
		end
	end
end
local json = net.jsonEncode({ roots = roots, refs = refs })
fs.writeFile(outPath, json)
print(outPath, #json, "bytes", nextId, "instances")
