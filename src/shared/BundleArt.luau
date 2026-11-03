--!strict
-- The grass bundles' look (owner 1 Nov: "Remake the grass bundle modles ... theyre supposed to be different each biome
-- and mutations"). ForgeGUI 3D models in ReplicatedStorage.BundleModels: Zone1 .. Zone8 (each area's own grass tied
-- with an orange-brown band) and Golden, Rainbow, Diamond, Toxic, Galaxy (a mutated bundle shows its mutation, from
-- any area). Each model stands upright as built, so its long side is Y and its attribute Native is its full size.
-- Used by server/Carry (the stack on your back), server/Loot (bundles on the ground), server/ShopRoom (the stack by
-- the wall) and client/SellFx (bundles flying into the shredder).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BundleArt = {}

local folder: Instance? = nil

local function models(): Instance?
	if not folder or not folder.Parent then
		folder = ReplicatedStorage:FindFirstChild("BundleModels")
	end
	return folder
end

-- The model for a bundle from area `z` with mutation `mut` (nil or "None" is plain grass).
function BundleArt.name(z: number?, mut: string?): string
	if mut and mut ~= "None" then
		return mut
	end
	return "Zone" .. tostring(z or 1)
end

-- A copy of that bundle, `length` studs long (end to end), or less if that would make it thicker than `thick`
-- studs (they're stout sheaves; a stack on your back is a stud a row). Anchored and not collidable, not parented
-- yet. Nil when the models aren't in the game (callers keep their old fallback).
function BundleArt.make(z: number?, mut: string?, length: number, thick: number?): MeshPart?
	local f = models()
	if not f then
		return nil
	end
	local t = f:FindFirstChild(BundleArt.name(z, mut)) or f:FindFirstChild("Zone" .. tostring(z or 1)) or f:FindFirstChild("Zone1")
	if not t or not t:IsA("MeshPart") then
		return nil
	end
	local m = t:Clone()
	local native = (m:GetAttribute("Native") :: Vector3?) or m.Size
	local k = length / math.max(native.Y, 0.01)
	if thick then
		k = math.min(k, thick / math.max(native.X, native.Z, 0.01))
	end
	m.Size = native * k
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Massless = true
	m.CastShadow = false
	return m
end

-- Where a bundle lies on its side on top of `cf` (a point on the ground or a shelf, Y up): its long side along
-- cf's X axis, cut tops toward -X.
function BundleArt.lying(m: MeshPart, cf: CFrame): CFrame
	return cf * CFrame.new(0, math.max(m.Size.X, m.Size.Z) / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
end

-- How thick a bundle of that length is (its height when lying down).
function BundleArt.thickness(m: MeshPart): number
	return math.max(m.Size.X, m.Size.Z)
end

return BundleArt
