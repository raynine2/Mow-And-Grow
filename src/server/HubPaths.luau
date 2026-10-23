-- Paths for the hubs in Chop A Forest's style: clean packed-dirt walks across the grass, straight-edged, with a
-- thin darker border along each side. Nothing scattered on them and nothing standing up, so the hub reads tidy.
-- HubPaths.lay(parent, segments, y) lays every segment's path (they may cross: the walks are drawn over the
-- borders, so crossings join cleanly). HubPaths.pave() then gives them the zone camp's stone paving (the lobby).
local HubPaths = {}

export type Segment = { a: Vector2, b: Vector2, width: number }

local DIRT = Color3.fromRGB(214, 152, 88) -- warm: the blue daylight greys it
local BORDER = Color3.fromRGB(150, 98, 58)
local MAT = Enum.Material.Sand -- a fine, even grain: reads as packed dirt without the Ground texture's grey patches

local function flat(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = MAT
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Round plazas (each { centre: Vector2, radius: number }) are laid the same way as the walks.
function HubPaths.lay(parent: Instance, segments: { Segment }, y: number, _seed: number?, discs: { { centre: Vector2, radius: number } }?)
	local f = Instance.new("Folder")
	f.Name = "Paths"
	for _, d in discs or {} do
		local c = d.centre
		local border = flat(f, "PathBorder", Vector3.new(0.08, (d.radius + 0.6) * 2, (d.radius + 0.6) * 2), CFrame.new(c.X, y + 0.04, c.Y) * CFrame.Angles(0, 0, math.rad(90)), BORDER)
		border.Shape = Enum.PartType.Cylinder
		local top = flat(f, "Path", Vector3.new(0.13, d.radius * 2, d.radius * 2), CFrame.new(c.X, y + 0.065, c.Y) * CFrame.Angles(0, 0, math.rad(90)), DIRT)
		top.Shape = Enum.PartType.Cylinder
	end
	-- borders first (a little wider, a little lower), then the walks on top
	for pass = 1, 2 do
		for _, s in segments do
			local a, b = s.a, s.b
			local len = (b - a).Magnitude
			local frame = CFrame.lookAt(Vector3.new(a.X, y, a.Y), Vector3.new(b.X, y, b.Y))
			if pass == 1 then
				flat(f, "PathBorder", Vector3.new(s.width + 1.2, 0.08, len + s.width + 1.2), frame * CFrame.new(0, 0.04, -len / 2), BORDER)
			else
				flat(f, "Path", Vector3.new(s.width, 0.12, len + s.width), frame * CFrame.new(0, 0.06, -len / 2), DIRT)
			end
		end
	end
	f.Parent = parent
	return f
end

-- The zone camp's paving (Workspace.World.Hub.CampTiles): golden stones about 3.4 studs square on a 4-stud grid,
-- in two shades, over a darker bed that shows in the joints, the odd stone missing.
local STONE = { Color3.fromRGB(240, 162, 82), Color3.fromRGB(225, 152, 77) }
local BED = Color3.fromRGB(184, 121, 61)
local EDGE = Color3.fromRGB(150, 98, 58)

local function rand(i: number, j: number, k: number): number
	local n = math.sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453
	return n - math.floor(n)
end

-- The top of the walk under a stone centred at q (nil when the stone wouldn't fit on a walk).
local function walkTop(walks: { BasePart }, q: Vector3): number?
	local top = nil
	for _, p in walks do
		local fits = false
		if p.Shape == Enum.PartType.Cylinder then
			-- a round plaza: a flat cylinder on its side (diameter in Y and Z)
			fits = Vector2.new(q.X - p.Position.X, q.Z - p.Position.Z).Magnitude + 2.3 <= p.Size.Y / 2
		else
			local l = p.CFrame:PointToObjectSpace(Vector3.new(q.X, p.Position.Y, q.Z))
			fits = math.abs(l.X) + 1.6 <= p.Size.X / 2 and math.abs(l.Z) + 1.6 <= p.Size.Z / 2
		end
		if fits then
			local y = p.Position.Y + (if p.Shape == Enum.PartType.Cylinder then p.Size.X else p.Size.Y) / 2
			top = math.max(top or y, y)
		end
	end
	return top
end

-- HubPaths.pave(paths, origin) turns a Paths folder made by lay() into that paving: the walks become the bed and
-- stones go on top. The grid is fixed to `origin` (the lobby's centre), so a saved copy of the lobby gets the same
-- stones as a fresh one. Run once per folder.
function HubPaths.pave(paths: Instance, origin: Vector3)
	local walks: { BasePart } = {}
	local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, p in paths:GetChildren() do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.Plastic
			p.Color = if p.Name == "Path" then BED else EDGE
			if p.Name == "Path" then
				table.insert(walks, p)
				local r = p.Size.Magnitude / 2
				lo = lo:Min(Vector2.new(p.Position.X - r, p.Position.Z - r))
				hi = hi:Max(Vector2.new(p.Position.X + r, p.Position.Z + r))
			end
		end
	end
	local stones = Instance.new("Folder")
	stones.Name = "Stones"
	-- grid: x on multiples of 4, z two studs off, so 12-stud walks both ways get three stones across
	for i = math.floor((lo.X - origin.X) / 4), math.ceil((hi.X - origin.X) / 4) do
		for j = math.floor((lo.Y - origin.Z - 2) / 4), math.ceil((hi.Y - origin.Z - 2) / 4) do
			local q = Vector3.new(origin.X + i * 4, 0, origin.Z + j * 4 + 2)
			local top = walkTop(walks, q)
			if top and rand(i, j, 3) >= 0.05 then
				local s = 3.3 + rand(i, j, 4) * 0.22
				local p = Instance.new("Part")
				p.Name = "Stone"
				p.Anchored = true
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Material = Enum.Material.Plastic
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				p.Color = STONE[if rand(i, j, 5) < 0.5 then 1 else 2]
				p.Size = Vector3.new(s, 0.2, s) -- (thin: the pads' glowing frames, 0.4 up, stay on top)
				p.CFrame = CFrame.new(q.X + (rand(i, j, 6) - 0.5) * 0.2, top + 0.1, q.Z + (rand(i, j, 7) - 0.5) * 0.2)
				p.Parent = stones
			end
		end
	end
	stones.Parent = paths
	return stones
end

return HubPaths
