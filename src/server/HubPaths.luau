-- Paths for the hubs in Chop A Forest's style: worn dirt tracks across the grass (Roblox's Ground material),
-- with soft, uneven edges where the grass grows over them and the odd stone along the side. Nothing stands up out
-- of the ground, so they read as part of the lawn.
-- HubPaths.lay(parent, segments, y) lays every segment's path (they may cross).
local HubPaths = {}

export type Segment = { a: Vector2, b: Vector2, width: number }

local DIRT = Color3.fromRGB(214, 174, 122) -- light: the Ground texture is dark
local DIRT2 = Color3.fromRGB(198, 160, 110)
local STONE = Color3.fromRGB(150, 148, 142)

local count = 0
local function flat(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): Part
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
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	count += 1
	if count % 300 == 0 then
		task.wait()
	end
	return p
end

function HubPaths.lay(parent: Instance, segments: { Segment }, y: number, seed: number?)
	local f = Instance.new("Folder")
	f.Name = "Paths"
	local rng = Random.new(seed or 7)
	for _, s in segments do
		local a, b = s.a, s.b
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local side = Vector2.new(-dir.Y, dir.X)
		local frame = CFrame.lookAt(Vector3.new(a.X, y, a.Y), Vector3.new(b.X, y, b.Y))
		-- the track itself, running a little past both ends so crossings join up
		flat(f, "Path", Vector3.new(s.width - 1.2, 0.1, len + s.width - 1.2), frame * CFrame.new(0, 0.05, -len / 2), DIRT, Enum.Material.Ground)
		-- soft edges: overlapping patches of dirt that wander in and out a little
		local n = math.floor(len / 2.5)
		for i = 0, n do
			local t = i / math.max(n, 1)
			local p = a + (b - a) * t
			for _, sgn in { -1, 1 } do
				local off = (s.width / 2 - 0.6) + rng:NextNumber(-0.5, 0.6)
				local c = p + side * sgn * off
				local w = rng:NextNumber(1.6, 3.2)
				flat(f, "PathEdge", Vector3.new(w, 0.08, rng:NextNumber(2.2, 3.6)), CFrame.new(c.X, y + 0.04, c.Y) * CFrame.Angles(0, math.atan2(dir.X, dir.Y) + rng:NextNumber(-0.35, 0.35), 0), if rng:NextNumber() < 0.5 then DIRT else DIRT2, Enum.Material.Ground)
				-- now and then a flat stone at the edge
				if rng:NextNumber() < 0.12 then
					local st = p + side * sgn * (s.width / 2 + rng:NextNumber(0, 0.8))
					local r = rng:NextNumber(0.7, 1.3)
					flat(f, "PathStone", Vector3.new(r * 1.4, 0.3, r), CFrame.new(st.X, y + 0.1, st.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), STONE, Enum.Material.Slate)
				end
			end
		end
		-- a few darker worn patches along the middle
		for _ = 1, math.floor(len / 12) do
			local p = a + (b - a) * rng:NextNumber(0.05, 0.95) + side * rng:NextNumber(-s.width / 5, s.width / 5)
			flat(f, "PathWear", Vector3.new(rng:NextNumber(2, 3.5), 0.11, rng:NextNumber(3, 5)), CFrame.new(p.X, y + 0.06, p.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), DIRT2, Enum.Material.Ground)
		end
	end
	f.Parent = parent
	return f
end

return HubPaths
