--!strict
-- ONE LOOK FOR THE GROUND (owner, 4 Nov, at the starting area: "it feels so sloppy and everyhting looks messy different
-- parts different styles ... fix it", and on the flat bright squares: "i also dont like the no detailed grass
-- brightness"). Runs on the run's copy of the world (server/RunWorld.build, after server/CampGround), so Studio's
-- saved world is untouched; WorldLook.ON = false gives the old look back.
--   * The ground's pattern (WorldArt: an 8 x 8 tile a shade lighter or darker on about a fifth of the floor
--     squares) was flat plastic, 9% off the floor, on Roblox's textured grass: flat bright squares. Each gets the
--     floor's own material under it and sits one small step (5%) off the floor's colour.
--   * The areas' paths (WorldArt: orange studded toy-brick tiles, 3.1 x 0.3 x 3.1) were a third paving style next to
--     the camp's stones and the walk plates. They're laid like the camp's now (server/CampGround.pave: smooth, a
--     lighter rim, an inset top plate), in a few close tones; the meadow's in the camp's own sandstone so its path runs
--     on from the camp, the other areas' in their own path colour; the edge tiles lean darker like the camp's border.
-- (The mowed lawn and the stubble got the same treatment at the source: server/Lawn, server/Stubble.)
local CampGround = require(script.Parent.CampGround)

local WorldLook = {}

WorldLook.ON = true

local OVERLAY_STEP = 0.05 -- the ground pattern's tiles: this much lighter or darker than the floor
-- the paths: the base colour per area folder (World.Visuals.<area name>); the rest keep their own
local PATH_BASE: { [string]: Color3 } = {
	["Sunny Meadow"] = CampGround.TONES[1],
}
local PATH_TONES = { 1, 0.95, 1.03, 0.9 } -- each tile one of these times the base
local PATH_CELL = 3.2 -- WorldArt lays them 3.2 apart

local function mul(c: Color3, k: number): Color3
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

local function hash(x: number, z: number, seed: number): number
	local n = math.sin(x * 12.9898 + z * 78.233 + seed * 37.719) * 43758.5453
	return n - math.floor(n)
end

local function value(c: Color3): number
	local _, _, v = c:ToHSV()
	return v
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.01
end

-- The ground pattern's tiles: the floor's material, one step off its colour. Returns how many.
local function overlays(w: Instance): number
	local visuals = w:FindFirstChild("Visuals")
	local ground = w:FindFirstChild("Ground")
	if not visuals or not ground then
		return 0
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { ground }
	local n = 0
	for _, area in visuals:GetChildren() do
		for _, d in area:GetChildren() do
			if d:IsA("Part") and near(d.Size.X, 8) and near(d.Size.Z, 8) and near(d.Size.Y, 0.12) and d.Material == Enum.Material.SmoothPlastic then
				local hit = workspace:Raycast(d.Position + Vector3.new(0, 1, 0), Vector3.new(0, -4, 0), rp)
				local floor = hit and hit.Instance
				if floor and floor:IsA("BasePart") then
					local k = if value(d.Color) > value(floor.Color) then 1 + OVERLAY_STEP else 1 - OVERLAY_STEP
					d.Color = mul(floor.Color, k)
					d.Material = floor.Material
					n += 1
					if n % 300 == 0 then
						task.wait()
					end
				end
			end
		end
	end
	return n
end

-- The areas' path tiles, laid like the camp's paving. Returns how many.
local function paths(w: Instance): number
	local visuals = w:FindFirstChild("Visuals")
	if not visuals then
		return 0
	end
	local n = 0
	for _, area in visuals:GetChildren() do
		local tiles: { Part } = {}
		for _, d in area:GetChildren() do
			if d:IsA("Part") and near(d.Size.X, 3.1) and near(d.Size.Z, 3.1) and near(d.Size.Y, 0.3) then
				table.insert(tiles, d)
			end
		end
		if #tiles == 0 then
			continue
		end
		-- the path's own colour: its lightest tile (WorldArt: the colour, 0.94 of it, and 0.78 of it on the edges)
		local own = tiles[1].Color
		for _, t in tiles do
			if value(t.Color) > value(own) then
				own = t.Color
			end
		end
		local base = PATH_BASE[area.Name] or own
		local edge = value(own) * 0.85
		for _, t in tiles do
			local ix, iz = math.floor(t.Position.X / PATH_CELL), math.floor(t.Position.Z / PATH_CELL)
			local face = mul(base, PATH_TONES[1 + math.floor(hash(ix, iz, 3) * #PATH_TONES)])
			if value(t.Color) < edge then
				face = face:Lerp(CampGround.BORDER, CampGround.BORDER_K)
			end
			CampGround.pave(t, face)
			n += 1
			if n % 200 == 0 then
				task.wait()
			end
		end
	end
	return n
end

-- Returns (ground pattern tiles, path tiles) restyled.
function WorldLook.apply(w: Instance): (number, number)
	if not WorldLook.ON then
		return 0, 0
	end
	local a = overlays(w)
	local b = paths(w)
	return a, b
end

return WorldLook
