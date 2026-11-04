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

-- One paving stone in the kit's look: smooth, its rim `face` lightened, a thin top plate inset in `face` itself.
-- (Also the areas' paths: server/WorldLook.)
function CampGround.pave(s: BasePart, face: Color3)
	s.Material = Enum.Material.SmoothPlastic
	s.MaterialVariant = ""
	s.TopSurface = Enum.SurfaceType.Smooth
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
end

CampGround.TONES = TONES
CampGround.BORDER = BORDER
CampGround.BORDER_K = BORDER_K

-- THE BUILDINGS' FOOTINGS (owner, 4 Nov: "i dont like how the buildings are mixed with the ground"). The camp's paving
-- is laid square to the world, but the Tool Shop and the Garage stand turned (73 and -17 degrees, where the saved map
-- has them), so the stones ran in under their walls at a slant, half stones poking out along every wall, and the
-- Garage's side stood straight on the grass. Now each stands on its own border of stones, square to the building:
-- a band of kerb stones (the paving's look, CampGround.pave, in the darker edge tones) on a grout bed, from under its
-- walls to a couple of studs out, a hair above the paving so it lies over the stones it crosses; the Tool Shop's band
-- in front runs out past its porch steps as a little terrace. The paving stones it covers whole go.
-- Rectangles in the unit's "0Anchor" frame (-Z is the front): `inner` the band's inside edge (under the walls, outside
-- the room, measured in Studio), `outer` its outside edge.
type Rect = { x0: number, x1: number, z0: number, z1: number }
local FOOTINGS: { [string]: { inner: Rect, outer: Rect } } = {
	["TOOL SHOP"] = { inner = { x0 = -24, x1 = 23.2, z0 = -10.6, z1 = 22 }, outer = { x0 = -30.2, x1 = 27.2, z0 = -17.7, z1 = 28.5 } },
	Garage = { inner = { x0 = -9.8, x1 = 9.8, z0 = -9.2, z1 = 12.6 }, outer = { x0 = -13.2, x1 = 13.5, z0 = -11.2, z1 = 16.2 } },
}
local KERB_H = 0.33 -- the kerb stones' height over the ground (the paving's are 0.3, their top plates 0.305)
local BED_H = 0.312 -- the grout under them
local STONE = 3.4 -- about the paving's size
local GAP = 0.2

local function footingPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = parent
	return p
end

-- One strip of the band: grout under the whole strip, kerb stones on it in rows and columns about a paving stone big.
local function strip(parent: Instance, at: CFrame, x0: number, x1: number, z0: number, z1: number)
	local sx, sz = x1 - x0, z1 - z0
	if sx < 0.3 or sz < 0.3 then
		return
	end
	footingPart(parent, "FootingBed", Vector3.new(sx, BED_H, sz), at * CFrame.new((x0 + x1) / 2, BED_H / 2, (z0 + z1) / 2), GROUT)
	local nx, nz = math.max(1, math.floor(sx / STONE + 0.5)), math.max(1, math.floor(sz / STONE + 0.5))
	local lx, lz = sx / nx, sz / nz
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local cx, cz = x0 + (i + 0.5) * lx, z0 + (j + 0.5) * lz
			local wp = at:PointToWorldSpace(Vector3.new(cx, 0, cz))
			local face = TONES[1 + math.floor(hash(math.floor(wp.X / 3), math.floor(wp.Z / 3), 5) * #TONES)]:Lerp(BORDER, BORDER_K)
			local s = footingPart(parent, "FootingStone", Vector3.new(lx - GAP, KERB_H, lz - GAP), at * CFrame.new(cx, KERB_H / 2, cz), face)
			CampGround.pave(s, face)
		end
	end
end

-- Lays every building's footing (after CampGround.apply). Returns how many footings were laid.
function CampGround.footings(w: Instance): number
	if not CampGround.ON then
		return 0
	end
	local hub = w:FindFirstChild("Hub")
	local tiles = hub and hub:FindFirstChild("CampTiles")
	if not hub then
		return 0
	end
	local n = 0
	for unitName, f in FOOTINGS do
		local unit = hub:FindFirstChild(unitName)
		local anchor = unit and unit:FindFirstChild("0Anchor")
		if not unit or not anchor or not anchor:IsA("BasePart") then
			continue
		end
		local at = CFrame.new(anchor.Position.X, anchor.Position.Y, anchor.Position.Z) * anchor.CFrame.Rotation
		local o, i = f.outer, f.inner
		local folder = Instance.new("Folder")
		folder.Name = "Footing"
		-- the paving stones it covers whole go (their plates too); the ones it crosses stay, under its edge
		for _, p in (if tiles then tiles:GetDescendants() else {}) do
			if p:IsA("BasePart") and (p.Name == "Stone" or p.Name == "StoneTop") then
				local inside = true
				for _, k in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
					local l = at:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size / 2 * k))
					if l.X < o.x0 or l.X > o.x1 or l.Z < o.z0 or l.Z > o.z1 then
						inside = false
						break
					end
				end
				if inside then
					p:Destroy()
				end
			end
		end
		-- the band: front and back strips the full width, the sides between them
		strip(folder, at, o.x0, o.x1, o.z0, i.z0)
		strip(folder, at, o.x0, o.x1, i.z1, o.z1)
		strip(folder, at, o.x0, i.x0, i.z0, i.z1)
		strip(folder, at, i.x1, o.x1, i.z0, i.z1)
		folder.Parent = unit
		n += 1
		task.wait()
	end
	return n
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
		CampGround.pave(s, face)
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
