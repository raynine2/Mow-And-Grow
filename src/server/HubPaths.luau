-- Cobblestone paths for the hubs, in the Catch a Brainrot style: chunky stone tiles of a few warm shades laid on
-- a 3-stud grid, each a little rotated and at its own height, with dark earth showing between them; broken edges,
-- bigger grey kerb stones along both sides, the odd mossy tile, grass poking up at the edges and pebbles.
-- HubPaths.lay(parent, segments, y) lays every segment's path (they may cross; tiles are shared).
local HubPaths = {}

export type Segment = { a: Vector2, b: Vector2, width: number }

local TILE = {
	Color3.fromRGB(222, 204, 166),
	Color3.fromRGB(206, 186, 148),
	Color3.fromRGB(232, 216, 182),
	Color3.fromRGB(194, 172, 134),
}
local MOSSY = Color3.fromRGB(160, 176, 112)
local EARTH = Color3.fromRGB(118, 88, 60)
local KERB = { Color3.fromRGB(150, 150, 158), Color3.fromRGB(128, 128, 138), Color3.fromRGB(170, 170, 176) }
local GRASS = { Color3.fromRGB(70, 160, 56), Color3.fromRGB(92, 182, 66) }

local count = 0
local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = false
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

-- distance from p to the nearest segment, and that segment
local function nearest(segments: { Segment }, p: Vector2): (number, Segment)
	local best, bestSeg = math.huge, segments[1]
	for _, s in segments do
		local ab = s.b - s.a
		local t = math.clamp((p - s.a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		local d = (p - (s.a + ab * t)).Magnitude - s.width / 2
		if d < best then
			best, bestSeg = d, s
		end
	end
	return best, bestSeg
end

function HubPaths.lay(parent: Instance, segments: { Segment }, y: number, seed: number?)
	local f = Instance.new("Folder")
	f.Name = "Paths"
	local rng = Random.new(seed or 7)
	-- the earth under the stones (shows in the gaps)
	for _, s in segments do
		local a, b = s.a, s.b
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + s.width
		block(f, "PathEarth", Vector3.new(s.width + 0.6, 0.12, len), CFrame.lookAt(Vector3.new(mid.X, y + 0.06, mid.Y), Vector3.new(b.X, y + 0.06, b.Y)), EARTH)
	end
	-- the tiles, on a 3-stud grid over everything the paths cover
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, s in segments do
		for _, p in { s.a, s.b } do
			minX, maxX = math.min(minX, p.X - s.width), math.max(maxX, p.X + s.width)
			minZ, maxZ = math.min(minZ, p.Y - s.width), math.max(maxZ, p.Y + s.width)
		end
	end
	local G = 3
	for gx = math.floor(minX / G) * G, maxX, G do
		for gz = math.floor(minZ / G) * G, maxZ, G do
			local p = Vector2.new(gx + rng:NextNumber(-0.25, 0.25), gz + rng:NextNumber(-0.25, 0.25))
			local d = nearest(segments, p)
			-- inside, with a ragged edge where some tiles are missing
			if d < -0.6 and not (d > -2.4 and rng:NextNumber() < 0.3) then
				local w = rng:NextNumber(2.25, 2.7)
				local l = rng:NextNumber(2.25, 2.7)
				local h = rng:NextNumber(0.35, 0.6)
				local col = if rng:NextNumber() < 0.06 then MOSSY else TILE[rng:NextInteger(1, #TILE)]
				local cf = CFrame.new(p.X, y + h / 2 + rng:NextNumber(0, 0.12), p.Y) * CFrame.Angles(0, math.rad(rng:NextNumber(-7, 7)), 0)
				block(f, "PathStone", Vector3.new(w, h, l), cf, col, true)
				-- a lighter chip on some tiles, like a worn top
				if rng:NextNumber() < 0.25 then
					block(f, "PathChip", Vector3.new(w * 0.45, 0.06, l * 0.4), cf * CFrame.new(rng:NextNumber(-0.4, 0.4), h / 2 + 0.03, rng:NextNumber(-0.4, 0.4)), col:Lerp(Color3.new(1, 1, 1), 0.18))
				end
			elseif d >= -0.6 and d < 1.4 then
				-- the kerb: chunky grey stones along the edge, half sunk, with grass between them
				if rng:NextNumber() < 0.55 then
					local s = rng:NextNumber(1.4, 2.2)
					local h = rng:NextNumber(0.6, 1.0)
					block(f, "Kerb", Vector3.new(s, h, s * rng:NextNumber(0.8, 1.2)), CFrame.new(p.X, y + h / 2 - 0.15, p.Y) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0), KERB[rng:NextInteger(1, #KERB)])
				elseif rng:NextNumber() < 0.6 then
					for _ = 1, 3 do
						local bh = rng:NextNumber(0.5, 1.1)
						block(f, "GrassTuft", Vector3.new(0.3, bh, 0.3), CFrame.new(p.X + rng:NextNumber(-0.8, 0.8), y + bh / 2, p.Y + rng:NextNumber(-0.8, 0.8)), GRASS[rng:NextInteger(1, 2)])
					end
				end
			end
			-- a few pebbles scattered near the path
			if d > -0.5 and d < 2.5 and rng:NextNumber() < 0.15 then
				local s = rng:NextNumber(0.35, 0.6)
				block(f, "Pebble", Vector3.new(s, s * 0.6, s), CFrame.new(p.X + rng:NextNumber(-1, 1), y + s * 0.3, p.Y + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), KERB[rng:NextInteger(1, #KERB)])
			end
		end
	end
	f.Parent = parent
	return f
end

return HubPaths
