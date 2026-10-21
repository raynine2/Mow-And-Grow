-- Stone paths for the hubs, in the chunky, tidy style of Catch a Brainrot: big square sandstone slabs on a 3-stud
-- grid with thin grout lines between them, each slab with a bevelled lighter top, framed by a solid kerb of darker
-- stone blocks, and grass tufts growing up along the outside of the kerb. Colours are warm on purpose: the hubs'
-- blue-ish daylight cools them down.
-- HubPaths.lay(parent, segments, y) lays every segment's path (they may cross; slabs are shared).
local HubPaths = {}

export type Segment = { a: Vector2, b: Vector2, width: number }

local SLAB = {
	Color3.fromRGB(240, 206, 150),
	Color3.fromRGB(232, 196, 138),
	Color3.fromRGB(246, 216, 166),
	Color3.fromRGB(226, 188, 130),
}
local GROUT = Color3.fromRGB(150, 118, 84)
local KERB = { Color3.fromRGB(176, 142, 102), Color3.fromRGB(162, 128, 92) }
local GRASS = { Color3.fromRGB(70, 168, 56), Color3.fromRGB(96, 190, 66) }
local FLOWER = { Color3.fromRGB(255, 236, 90), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 130, 170) }

local G = 3 -- grid step
local SLAB_SIZE = 2.72 -- leaves a thin grout line
local SLAB_H = 0.45
local KERB_H = 0.75

local count = 0
local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	count += 1
	if count % 400 == 0 then
		task.wait()
	end
	return p
end

-- how far p is outside the paths (negative inside)
local function dist(segments: { Segment }, p: Vector2): number
	local best = math.huge
	for _, s in segments do
		local ab = s.b - s.a
		local t = math.clamp((p - s.a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (p - (s.a + ab * t)).Magnitude - s.width / 2)
	end
	return best
end

-- one slab: a body and a slightly smaller, lighter top (the bevel)
local function slab(f: Instance, x: number, z: number, y: number, rng: Random)
	local col = SLAB[rng:NextInteger(1, #SLAB)]
	local h = SLAB_H + rng:NextNumber(-0.05, 0.05)
	block(f, "PathSlab", Vector3.new(SLAB_SIZE, h, SLAB_SIZE), CFrame.new(x, y + h / 2, z), col:Lerp(GROUT, 0.25), true)
	block(f, "PathTop", Vector3.new(SLAB_SIZE - 0.4, 0.08, SLAB_SIZE - 0.4), CFrame.new(x, y + h + 0.04, z), col)
end

local function kerb(f: Instance, x: number, z: number, y: number, i: number, j: number)
	block(f, "Kerb", Vector3.new(G, KERB_H, G), CFrame.new(x, y + KERB_H / 2, z), KERB[(i + j) % 2 + 1], true)
	block(f, "KerbTop", Vector3.new(G - 0.3, 0.08, G - 0.3), CFrame.new(x, y + KERB_H + 0.04, z), KERB[(i + j) % 2 + 1]:Lerp(Color3.new(1, 1, 1), 0.12))
end

-- grass tufts (and the odd flower) just outside the kerb
local function tufts(f: Instance, x: number, z: number, y: number, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(0.6, 1.3)
		block(f, "GrassTuft", Vector3.new(0.35, h, 0.35), CFrame.new(x + rng:NextNumber(-1.2, 1.2), y + h / 2, z + rng:NextNumber(-1.2, 1.2)), GRASS[rng:NextInteger(1, #GRASS)])
	end
	if rng:NextNumber() < 0.25 then
		local fx, fz = x + rng:NextNumber(-1, 1), z + rng:NextNumber(-1, 1)
		block(f, "FlowerStem", Vector3.new(0.2, 1.1, 0.2), CFrame.new(fx, y + 0.55, fz), GRASS[1])
		block(f, "Flower", Vector3.new(0.6, 0.35, 0.6), CFrame.new(fx, y + 1.2, fz), FLOWER[rng:NextInteger(1, #FLOWER)])
	end
end

function HubPaths.lay(parent: Instance, segments: { Segment }, y: number, seed: number?)
	local f = Instance.new("Folder")
	f.Name = "Paths"
	local rng = Random.new(seed or 7)
	-- the grout under the slabs (shows in the thin lines between them)
	for _, s in segments do
		local a, b = s.a, s.b
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + s.width
		block(f, "PathGrout", Vector3.new(s.width + 2, 0.2, len), CFrame.lookAt(Vector3.new(mid.X, y + 0.1, mid.Y), Vector3.new(b.X, y + 0.1, b.Y)), GROUT)
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, s in segments do
		for _, p in { s.a, s.b } do
			minX, maxX = math.min(minX, p.X - s.width), math.max(maxX, p.X + s.width)
			minZ, maxZ = math.min(minZ, p.Y - s.width), math.max(maxZ, p.Y + s.width)
		end
	end
	for i = math.floor(minX / G), math.ceil(maxX / G) do
		for j = math.floor(minZ / G), math.ceil(maxZ / G) do
			local x, z = i * G, j * G
			local d = dist(segments, Vector2.new(x, z))
			if d < -1.5 then
				slab(f, x, z, y, rng)
			elseif d < 1.5 then
				kerb(f, x, z, y, i, j)
			elseif d < 4.5 and rng:NextNumber() < 0.45 then
				tufts(f, x, z, y, rng)
			end
		end
	end
	f.Parent = parent
	return f
end

return HubPaths
