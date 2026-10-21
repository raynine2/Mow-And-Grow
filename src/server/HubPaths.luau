-- Paths for the hubs in Chop A Forest's style: clean packed-dirt walks across the grass, straight-edged, with a
-- thin darker border along each side. Nothing scattered on them and nothing standing up, so the hub reads tidy.
-- HubPaths.lay(parent, segments, y) lays every segment's path (they may cross: the walks are drawn over the
-- borders, so crossings join cleanly).
local HubPaths = {}

export type Segment = { a: Vector2, b: Vector2, width: number }

local DIRT = Color3.fromRGB(196, 150, 100)
local BORDER = Color3.fromRGB(150, 108, 70)
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

function HubPaths.lay(parent: Instance, segments: { Segment }, y: number, _seed: number?)
	local f = Instance.new("Folder")
	f.Name = "Paths"
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

return HubPaths
