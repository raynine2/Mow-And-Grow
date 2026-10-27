-- STUDIO, EDIT MODE, FROM A LOCALLY LOADED PLUGIN ONLY: AssetService:CreateAssetAsync is refused everywhere else
-- (tried from the Studio MCP on 27 Oct: "CreateAssetAsync ... not available yet"). Until then import
-- assets/models/MowBundles.fbx by hand (File > Import 3D, meshes into ServerStorage.VoxelModels).
-- Builds the voxel grass bundles (the same design as tools/blender/voxel/bundle.py, the owner's ask on 27 Oct) as
-- EditableMeshes plus one atlas EditableImage, uploads them to Roblox as a Mesh and an Image asset each, and puts
-- one MeshPart per grass mutation (Bundle_None, Bundle_Golden, ...) in ServerStorage.VoxelModels.Bundles, where
-- server/VoxelModels finds them (server/Carry and server/Loot use them). This replaces importing MowBundles.fbx by
-- hand. Returns the asset ids and each mesh's size (copy the sizes to shared/ModelSizes). Not part of the game.
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local VS = 0.125 -- studs per voxel
local L = 19 -- stems run x = 0 .. L-1; the tips fan out past x = 0
local RY, RZ = 4.6, 5.6 -- the oval's half height / half depth (voxels)
local CY, CZ = 5, 0
local BANDS = { 4, 13 }
local C = function(r, g, b)
	return { r, g, b }
end

local PALETTES = {
	None = { stems = { C(62, 140, 38), C(84, 166, 48), C(104, 184, 58), C(52, 122, 32) }, tips = { C(124, 196, 66), C(104, 180, 56) }, cut = C(176, 206, 104), core = C(120, 160, 60), twine = { C(226, 178, 86), C(196, 146, 64) }, knot = C(176, 122, 50), daisy = true },
	Golden = { stems = { C(236, 186, 40), C(250, 208, 70), C(214, 160, 30) }, tips = { C(255, 236, 140), C(255, 224, 100) }, cut = C(255, 246, 190), core = C(206, 150, 30), twine = { C(150, 92, 40), C(124, 74, 32) }, knot = C(104, 62, 26), sparkle = C(255, 255, 230) },
	Rainbow = { stems = { C(255, 110, 170), C(255, 186, 80), C(120, 210, 255) }, tips = { C(190, 140, 255), C(140, 240, 140) }, cut = C(255, 240, 250), core = C(255, 140, 200), twine = { C(255, 255, 255), C(230, 230, 240) }, knot = C(200, 200, 216), sparkle = C(255, 255, 255) },
	Diamond = { stems = { C(140, 228, 255), C(186, 244, 255), C(100, 200, 240) }, tips = { C(230, 252, 255), C(200, 246, 255) }, cut = C(250, 255, 255), core = C(90, 180, 230), twine = { C(90, 120, 160), C(70, 96, 130) }, knot = C(56, 76, 110), sparkle = C(255, 255, 255) },
	Toxic = { stems = { C(150, 255, 40), C(120, 230, 30), C(180, 255, 90) }, tips = { C(210, 255, 120), C(110, 255, 60) }, cut = C(230, 255, 160), core = C(80, 170, 20), twine = { C(90, 60, 120), C(70, 46, 96) }, knot = C(56, 36, 80), sparkle = C(230, 255, 140) },
	Galaxy = { stems = { C(110, 60, 230), C(140, 80, 255), C(80, 44, 190) }, tips = { C(200, 150, 255), C(120, 200, 255) }, cut = C(236, 214, 255), core = C(70, 30, 160), twine = { C(255, 210, 90), C(226, 176, 60) }, knot = C(196, 140, 40), sparkle = C(255, 255, 255) },
}
local ORDER = { "None", "Golden", "Rainbow", "Diamond", "Toxic", "Galaxy" }

-- the shared atlas: one 32 px tile per colour, a lighter rim like the world's voxel models
local G, P = 16, 32
local tiles: { [string]: number } = {}
local tileColours: { { number } } = {}
local function tile(c: { number }): number
	local key = c[1] .. "," .. c[2] .. "," .. c[3]
	local i = tiles[key]
	if not i then
		table.insert(tileColours, c)
		i = #tileColours - 1
		tiles[key] = i
		assert(i < G * G, "atlas full")
	end
	return i
end

local function inside(y: number, z: number, grow: number): boolean
	local dy = (y + 0.5 - (CY + 0.5)) / (RY + grow)
	local dz = (z + 0.5 - (CZ + 0.5)) / (RZ + grow)
	return dy * dy + dz * dz <= 1 and y >= 0
end

-- one bundle's voxels: key "x,y,z" -> atlas tile. The knot and daisy are on +Z (they face out from a player's back).
local function bundle(name: string): ({ [string]: number }, { Vector3 })
	local p = PALETTES[name]
	local rng = Random.new(7)
	local vox: { [string]: number } = {}
	local function set(x: number, y: number, z: number, c: { number })
		vox[x .. "," .. y .. "," .. z] = tile(c)
	end
	local function has(x: number, y: number, z: number): boolean
		return vox[x .. "," .. y .. "," .. z] ~= nil
	end
	local function pick(list: { { number } }): { number }
		return list[rng:NextInteger(1, #list)]
	end
	local zr = math.ceil(RZ + 2)
	local yr = math.ceil(CY + RY + 2)
	local stems = {}
	for y = 0, yr - 1 do
		for z = -zr, zr do
			if inside(y, z, 0) then
				table.insert(stems, { y = y, z = z, c = pick(p.stems), short = rng:NextInteger(0, 1) })
			end
		end
	end
	for _, s in stems do
		for x = 0, L - 1 - s.short do
			set(x, s.y, s.z, s.c)
		end
		local ring = ((s.y - CY) ^ 2 + (s.z - CZ) ^ 2) % 3 == 0
		set(L - 1 - s.short, s.y, s.z, if ring then p.core else p.cut)
	end
	-- the tips fan out past x = 0, each one an unbroken blade
	for _, s in stems do
		local oy, oz = s.y - CY, s.z - CZ
		local d = math.sqrt((oy / RY) ^ 2 + (oz / RZ) ^ 2)
		local n = rng:NextInteger(1, 2) + (if d > 0.6 then 1 else 0)
		local ty, tz = oy / RY * n * 0.9, oz / RZ * n * 0.9
		for k = 1, n do
			local fy = s.y + math.round(ty * k / n)
			local fz = s.z + math.round(tz * k / n)
			if fy >= 0 then
				set(-k, fy, fz, if k >= n - 1 then pick(p.tips) else pick(p.stems))
			end
		end
	end
	-- the twine bands
	for _, bx in BANDS do
		for x = bx, bx + 1 do
			for y = 0, yr do
				for z = -zr - 1, zr + 1 do
					if inside(y, z, 0.9) and not inside(y, z, 0) then
						set(x, y, z, p.twine[(x + y + z) % 2 + 1])
					end
				end
			end
		end
	end
	-- the knot on the front (+Z) of the second band, with two dangling ends
	local kx = BANDS[2]
	local zmax = -math.huge
	for _, s in stems do
		if s.y == CY then
			zmax = math.max(zmax, s.z)
		end
	end
	local zf = zmax + 2
	for _, dx in { -1, 0, 1, 2 } do
		for dy = 0, 1 do
			set(kx + dx, CY + dy, zf, if dx == 0 or dx == 1 then p.knot else p.twine[1])
		end
	end
	for _, d in { { -1, -1 }, { -2, -1 }, { -3, -2 }, { -1, 2 }, { -2, 3 } } do
		set(kx + d[2], CY + d[1], zf, p.twine[2])
	end
	if p.daisy then
		local dx0, dy0 = BANDS[2] - 3, CY + 2
		for _, d in { { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } } do
			set(dx0 + d[1], dy0 + d[2], zf - 1, if math.abs(d[1]) + math.abs(d[2]) == 1 then C(255, 255, 255) else C(236, 236, 228))
		end
		set(dx0, dy0, zf, C(255, 206, 40))
		set(dx0 + 1, dy0 - 2, zf - 1, C(80, 160, 50))
	end
	-- loose blades poking out of the top
	local ytop = 0
	for _, s in stems do
		ytop = math.max(ytop, s.y)
	end
	for _, b in { { 2, -1, 3, -1 }, { 7, 2, 2, -1 }, { 16, -2, 2, 0 }, { 10, 0, 3, -1 } } do
		for k = 1, b[3] do
			set(b[1] + (if k == b[3] then b[4] else 0), ytop + k, b[2], pick(p.tips))
		end
	end
	-- sparkles on the special grass
	if p.sparkle then
		local surface = {}
		for key in vox do
			local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if not has(x, y + 1, z) or not has(x, y, z + 1) or not has(x, y, z - 1) then
				table.insert(surface, key)
			end
		end
		table.sort(surface)
		for _ = 1, math.min(14, #surface) do
			local i = rng:NextInteger(1, #surface)
			vox[surface[i]] = tile(p.sparkle)
			table.remove(surface, i)
		end
	end
	return vox, {}
end

-- the six faces: outward normal and the four corners (unit cube), counter-clockwise seen from outside
local FACES = {
	{ Vector3.new(1, 0, 0), { Vector3.new(1, 0, 0), Vector3.new(1, 1, 0), Vector3.new(1, 1, 1), Vector3.new(1, 0, 1) } },
	{ Vector3.new(-1, 0, 0), { Vector3.new(0, 0, 1), Vector3.new(0, 1, 1), Vector3.new(0, 1, 0), Vector3.new(0, 0, 0) } },
	{ Vector3.new(0, 1, 0), { Vector3.new(0, 1, 0), Vector3.new(0, 1, 1), Vector3.new(1, 1, 1), Vector3.new(1, 1, 0) } },
	{ Vector3.new(0, -1, 0), { Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), Vector3.new(1, 0, 1), Vector3.new(0, 0, 1) } },
	{ Vector3.new(0, 0, 1), { Vector3.new(1, 0, 1), Vector3.new(1, 1, 1), Vector3.new(0, 1, 1), Vector3.new(0, 0, 1) } },
	{ Vector3.new(0, 0, -1), { Vector3.new(0, 0, 0), Vector3.new(0, 1, 0), Vector3.new(1, 1, 0), Vector3.new(1, 0, 0) } },
}

-- an EditableMesh from voxels: outside faces only, centred on its bounding box, flat-shaded (no shared corners)
local function mesh(vox: { [string]: number }): (EditableMesh, Vector3, number)
	local list = {}
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for key, t in vox do
		local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
		local v = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
		table.insert(list, { v, t })
		lo = lo:Min(v)
		hi = hi:Max(v + Vector3.one)
	end
	local mid = (lo + hi) / 2
	local em = AssetService:CreateEditableMesh()
	local inset = 1.5 / (G * P)
	local tris = 0
	for _, e in list do
		local v, t = e[1], e[2]
		local u0, v0 = (t % G) / G + inset, (t // G) / G + inset
		local u1, v1 = u0 + 1 / G - 2 * inset, v0 + 1 / G - 2 * inset
		for _, f in FACES do
			local n = f[1]
			if vox[(v.X + n.X) .. "," .. (v.Y + n.Y) .. "," .. (v.Z + n.Z)] == nil then
				local ids = {}
				for _, c in f[2] do
					table.insert(ids, em:AddVertex((v + c - mid) * VS))
				end
				local uvs = { em:AddUV(Vector2.new(u0, v1)), em:AddUV(Vector2.new(u0, v0)), em:AddUV(Vector2.new(u1, v0)), em:AddUV(Vector2.new(u1, v1)) }
				local nid = em:AddNormal(n)
				for _, tri in { { 1, 2, 3 }, { 1, 3, 4 } } do
					local fid = em:AddTriangle(ids[tri[1]], ids[tri[2]], ids[tri[3]])
					em:SetFaceUVs(fid, { uvs[tri[1]], uvs[tri[2]], uvs[tri[3]] })
					em:SetFaceNormals(fid, { nid, nid, nid })
					tris += 1
				end
			end
		end
	end
	return em, (hi - lo) * VS, tris
end

local function atlasImage(): EditableImage
	local W = G * P
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(W, W) })
	local buf = buffer.create(W * W * 4)
	for i, c in tileColours do
		local ti = i - 1
		local tx, ty = (ti % G) * P, (ti // G) * P
		for y = 0, P - 1 do
			for x = 0, P - 1 do
				local edge = math.min(x, y, P - 1 - x, P - 1 - y)
				local k = if edge < 2 then 1.13 elseif edge < 4 then 1.05 elseif edge > 9 then 0.98 else 1
				local o = ((ty + y) * W + tx + x) * 4
				buffer.writeu8(buf, o, math.min(255, math.floor(c[1] * k)))
				buffer.writeu8(buf, o + 1, math.min(255, math.floor(c[2] * k)))
				buffer.writeu8(buf, o + 2, math.min(255, math.floor(c[3] * k)))
				buffer.writeu8(buf, o + 3, 255)
			end
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(W, W), buf)
	return img
end

local function upload(obj: Object, kind: Enum.AssetType, name: string): number
	local result, id = AssetService:CreateAssetAsync(obj, kind, { Name = name, Description = "Mow A Lawn: voxel grass bundle (tools/studio-voxel-bundles.luau)" })
	assert(result == Enum.CreateAssetResult.Success, ("upload %s failed: %s %s"):format(name, tostring(result), tostring(id)))
	return id
end

-- build everything first (the atlas needs every bundle's colours), then upload
local built = {}
for _, name in ORDER do
	local vox = bundle(name)
	local em, size, tris = mesh(vox)
	table.insert(built, { name = "Bundle_" .. name, em = em, size = size, tris = tris })
end
local out = {}
local imgId = upload(atlasImage(), Enum.AssetType.Image, "MowBundlesAtlas")
table.insert(out, "atlas " .. imgId)
local root = ServerStorage:FindFirstChild("VoxelModels") or Instance.new("Folder", ServerStorage)
root.Name = "VoxelModels"
local folder = root:FindFirstChild("Bundles") or Instance.new("Folder", root)
folder.Name = "Bundles"
for _, b in built do
	local meshId = upload(b.em, Enum.AssetType.Mesh, b.name)
	local part: MeshPart? = nil
	for _ = 1, 20 do
		local ok, res = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromAssetId(meshId))
		end)
		if ok then
			part = res
			break
		end
		task.wait(3)
	end
	assert(part, "couldn't make a MeshPart from mesh " .. meshId)
	part.Name = b.name
	part.TextureID = "rbxassetid://" .. imgId
	part.Anchored = true
	part.CanCollide = false
	part.Size = b.size
	local old = folder:FindFirstChild(b.name)
	if old then
		old:Destroy()
	end
	part.Parent = folder
	table.insert(out, ("%s mesh %d tris %d size %.2f x %.2f x %.2f"):format(b.name, meshId, b.tris, b.size.X, b.size.Y, b.size.Z))
end
return table.concat(out, "\n")
