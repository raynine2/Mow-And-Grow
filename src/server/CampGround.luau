--!strict
-- THE STARTING CAMP'S PAVING, REDONE (owner, 4 Nov, standing in the camp: "the bricks and the random lanterns and plants
-- ... remove it or wtf"; then, with the camp on grass: "it looks so clumpy now ... very sloppy, i liked the bricks but
-- they had bad quality"). In the run's copy of the world (server/RunWorld.build, before server/WalkPlates lays its
-- plates), the camp's hand-laid paving (Hub.CampTiles: 0.3-stud stones on 8 x 8 bed blocks) keeps its layout but gets
-- the voxel kit's tile look (tools/blender/voxel/kit.py: every block a lighter bevelled rim round a slightly darker
-- face): each stone a warm sandstone in one of four close tones, its rim lighter, a thin top plate inset in its own
-- tone; the beds between them dark grout, so every stone reads; the stones along the paving's edge a shade darker, a
-- border where it meets the grass. (It was flat orange plastic on an orange bed.) The camp's loose lantern posts
-- (Hub.CampDecor) go; the buildings keep their own lamps. The flower beds, lantern ring and bunting were
-- server/HubSquare (off). Studio's saved world is untouched: CampGround.ON = false gives the old paving back.
local CampGround = {}

CampGround.ON = true

local TONES = {
	Color3.fromRGB(230, 178, 104),
	Color3.fromRGB(218, 166, 94),
	Color3.fromRGB(238, 190, 118),
	Color3.fromRGB(208, 156, 88),
}
local RIM = 0.18 -- how much lighter a stone's rim is than its face (toward white)
local INSET = 0.28 -- the rim's width, studs
local GROUT = Color3.fromRGB(92, 68, 50)
local BORDER = Color3.fromRGB(120, 92, 64) -- the edge stones lean this way
local BORDER_K = 0.45

local function hash(x: number, z: number, seed: number): number
	local n = math.sin(x * 12.9898 + z * 78.233 + seed * 37.719) * 43758.5453
	return n - math.floor(n)
end

-- Is (x, z) over one of the beds?
local function onBed(beds: { BasePart }, x: number, z: number): boolean
	for _, b in beds do
		local l = b.CFrame:PointToObjectSpace(Vector3.new(x, b.Position.Y, z))
		if math.abs(l.X) <= b.Size.X / 2 and math.abs(l.Z) <= b.Size.Z / 2 then
			return true
		end
	end
	return false
end

-- Returns how many stones were restyled.
function CampGround.apply(w: Instance): number
	if not CampGround.ON then
		return 0
	end
	local hub = w:FindFirstChild("Hub")
	local tiles = hub and hub:FindFirstChild("CampTiles")
	if not hub or not tiles then
		return 0
	end
	local beds: { BasePart } = {}
	local stones: { BasePart } = {}
	for _, p in tiles:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Bed" then
				table.insert(beds, p)
			elseif p.Name == "Stone" then
				table.insert(stones, p)
			end
		end
	end
	for _, b in beds do
		b.Material = Enum.Material.SmoothPlastic
		b.MaterialVariant = ""
		b.Color = GROUT
	end
	for i, s in stones do
		local x, z = s.Position.X, s.Position.Z
		local face = TONES[1 + math.floor(hash(math.floor(x / 4), math.floor(z / 4), 3) * #TONES)]
		if not (onBed(beds, x + 4, z) and onBed(beds, x - 4, z) and onBed(beds, x, z + 4) and onBed(beds, x, z - 4)) then
			face = face:Lerp(BORDER, BORDER_K)
		end
		s.Material = Enum.Material.SmoothPlastic
		s.MaterialVariant = ""
		s.Color = face:Lerp(Color3.new(1, 1, 1), RIM)
		local top = Instance.new("Part")
		top.Name = "StoneTop"
		top.Anchored = true
		top.CanCollide = false
		top.CanQuery = false
		top.CanTouch = false
		top.CastShadow = false
		top.Material = Enum.Material.SmoothPlastic
		top.TopSurface = Enum.SurfaceType.Smooth
		top.BottomSurface = Enum.SurfaceType.Smooth
		top.Size = Vector3.new(math.max(0.2, s.Size.X - INSET * 2), 0.04, math.max(0.2, s.Size.Z - INSET * 2))
		-- (its top 0.005 over the stone's: no flicker, and no step for the feet over server/WalkPlates' plate)
		top.CFrame = s.CFrame * CFrame.new(0, s.Size.Y / 2 - 0.015, 0)
		top.Color = face
		top.Parent = s.Parent
		if i % 100 == 0 then
			task.wait()
		end
	end
	local decor = hub:FindFirstChild("CampDecor")
	for _, d in (if decor then decor:GetChildren() else {}) do
		if d.Name == "lantern_post" then
			d:Destroy()
		end
	end
	return #stones
end

return CampGround
