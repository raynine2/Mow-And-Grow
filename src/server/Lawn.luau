-- The mowed lawn: every clump you cut leaves its patch of ground freshly mowed, in bright stripes that stay for
-- the rest of the run. That makes the before/after easy to see: the shaggy, darker field with its tall sticks of
-- grass, against clean striped lawn where you've been.
--
-- The ground of the generated world is 8 x 8 stud columns (World.Ground, server/WorldGen). Mowing a clump lays a
-- thin tile on top of its column, coloured by the column's place in the world so the tiles line up into stripes
-- (one light, one darker, alternating every column along x), and clears the ground cover standing on that column
-- (the little grass sticks, flowers and colour patches in World.Visuals). Paths stay as they are.
-- Called by server/Field when a clump's stubble appears, and for every clump of an area that was already cleared
-- before the run started.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)

local Lawn = {}

local CELL = 8 -- the ground grid (Zones.CELL)
local LIFT = 0.1 -- the tile sits just above the ground (and the ground's own colour patches)
local THICK = 0.08

local done: { [string]: boolean } = {}
local cover: { [string]: { BasePart } }? = nil
local folder: Folder? = nil
local params: RaycastParams? = nil

local function world(): Instance?
	return workspace:FindFirstChild("World")
end

local OX, OZ = Zones.BOUNDS.minX, Zones.BOUNDS.minZ -- the ground grid's corner (columns start here)

local function col(x: number): number
	return math.floor((x - OX) / CELL)
end
local function row(z: number): number
	return math.floor((z - OZ) / CELL)
end
local function cellName(x: number, z: number): string
	return col(x) .. ":" .. row(z)
end

-- The ground cover standing on each column: small parts in World.Visuals (not the path tiles, 3.1 x 0.3 x 3.1).
local function coverIndex(): { [string]: { BasePart } }
	if cover then
		return cover
	end
	local index: { [string]: { BasePart } } = {}
	local w = world()
	local visuals = w and w:FindFirstChild("Visuals")
	if visuals then
		for _, d in visuals:GetDescendants() do
			if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Model") then
				local s = d.Size
				local isPath = math.abs(s.X - 3.1) < 0.01 and math.abs(s.Y - 0.3) < 0.01
				local isPatch = math.abs(s.X - CELL) < 0.01 and math.abs(s.Z - CELL) < 0.01 and s.Y < 0.2
				if not isPath and (isPatch or s.Magnitude < 4.6) then
					local k = cellName(d.Position.X, d.Position.Z)
					local list = index[k]
					if not list then
						list = {}
						index[k] = list
					end
					table.insert(list, d)
				end
			end
		end
	end
	cover = index
	return index
end

local function groundParams(): RaycastParams?
	if params then
		return params
	end
	local w = world()
	local ground = w and w:FindFirstChild("Ground")
	if not ground then
		return nil
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { ground }
	params = p
	return p
end

-- The two mowed shades for zone z: brighter and a little more saturated than its ground.
local function shades(z: number): (Color3, Color3)
	local def = Zones.list[z]
	local base = if def then def.palette.ground else Color3.fromRGB(76, 178, 50)
	local h, s, v = base:ToHSV()
	local light = Color3.fromHSV(h, math.min(1, s * 1.08), math.min(1, v * 1.22))
	local dark = Color3.fromHSV(h, math.min(1, s * 1.12), math.min(1, v * 1.04))
	return light, dark
end

local function tileFolder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local w = world()
	if not w then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = "Mowed"
	f.Parent = w
	folder = f
	return f
end

-- Mow one ground column (by its grid index) in zone z. Safe to call again for the same column.
local function mowColumn(ix: number, iz: number, z: number, rp: RaycastParams, parent: Instance)
	local key = ix .. ":" .. iz
	if done[key] then
		return
	end
	local cx = OX + (ix + 0.5) * CELL
	local cz = OZ + (iz + 0.5) * CELL
	local hit = workspace:Raycast(Vector3.new(cx, 300, cz), Vector3.new(0, -600, 0), rp)
	if not hit or hit.Normal.Y < 0.9 then
		return
	end
	done[key] = true
	local top = hit.Position.Y
	local light, dark = shades(z)
	local t = Instance.new("Part")
	t.Name = "MowedTile"
	t.Anchored = true
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	t.CastShadow = false
	t.Material = Enum.Material.SmoothPlastic
	t.TopSurface = Enum.SurfaceType.Smooth
	t.BottomSurface = Enum.SurfaceType.Smooth
	t.Color = if ix % 2 == 0 then light else dark
	t.Size = Vector3.new(CELL, THICK, CELL)
	t.CFrame = CFrame.new(cx, top + LIFT - THICK / 2 + 0.02, cz)
	t.Parent = parent
	-- the shaggy bits standing on this column go
	local index = coverIndex()
	local list = index[key]
	if list then
		for _, d in list do
			if d.Parent and math.abs(d.Position.Y - top) < 6 then
				d:Destroy()
			end
		end
		index[key] = nil
	end
end

-- Mow every ground column within `radius` studs of `pos` (in zone z): a clump's patch of lawn. Neighbouring
-- clumps' patches overlap, so mowed ground joins up into whole stripes.
function Lawn.mow(pos: Vector3, z: number, radius: number?)
	local rp = groundParams()
	local parent = tileFolder()
	if not rp or not parent then
		return
	end
	local r = radius or 7
	for ix = col(pos.X - r), col(pos.X + r) do
		for iz = row(pos.Z - r), row(pos.Z + r) do
			local cx = OX + (ix + 0.5) * CELL
			local cz = OZ + (iz + 0.5) * CELL
			if Vector2.new(cx - pos.X, cz - pos.Z).Magnitude <= r then
				mowColumn(ix, iz, z, rp, parent)
			end
		end
	end
end

-- A new run (the world is rebuilt): forget what was mowed.
function Lawn.reset()
	table.clear(done)
	cover = nil
	params = nil
	if folder then
		folder:Destroy()
		folder = nil
	end
end

return Lawn
