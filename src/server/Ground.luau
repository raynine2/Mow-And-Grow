-- The ground is Roblox Terrain, not flat bricks: textured grass with animated blades (Terrain.Decoration), dirt
-- clearings with ragged natural edges, real water in the swamp, and rolling hills on the horizon. Everything is
-- filled so the ground's top is at y = 0 (the world builders place things on y = 0).
local Ground = {}

-- True while a world is built on top of a map saved in the place (server/MapStore): the saved Terrain is the
-- ground then, so the builders' fills, hills and paths are skipped.
Ground.locked = false

local terrain = workspace.Terrain

-- Smooth terrain draws its surface 2 studs ABOVE the top of a fill (measured: a block filled up to y = 0 shows its
-- grass at y = 2). Every fill below is lowered by this much so the visible ground really is at y = 0, where the
-- builders put the models, pads and paths.
local SINK = 2

-- Terrain colours are per material for the whole map, so every run area gets its own material (RunBuilder's
-- AREA_GROUND) and the material its own colour. Grass and Ground are also the hub's and the lobby's.
local COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(100, 182, 56), -- Backyard Lawn, the hub, the lobby, the verges: bright green
	[Enum.Material.LeafyGrass] = Color3.fromRGB(150, 188, 66), -- Flower Meadow: yellow-green
	[Enum.Material.Pavement] = Color3.fromRGB(128, 206, 96), -- Golf Course: smooth, manicured light green
	[Enum.Material.Sandstone] = Color3.fromRGB(206, 162, 82), -- Wheat Farm: golden stubble field
	[Enum.Material.Limestone] = Color3.fromRGB(214, 168, 182), -- Blossom Garden: a carpet of pink petals
	[Enum.Material.Mud] = Color3.fromRGB(80, 94, 64), -- Swamp Reeds: murky olive (also the lobby's trodden mud)
	[Enum.Material.Sand] = Color3.fromRGB(214, 148, 78), -- Autumn Prairie: orange-tan
	[Enum.Material.Slate] = Color3.fromRGB(48, 112, 46), -- Mega Jungle: deep mossy green
	[Enum.Material.Ground] = Color3.fromRGB(156, 116, 74), -- dirt: paths, yards, the lobby clearing
	[Enum.Material.Salt] = Color3.fromRGB(240, 224, 170), -- golf sand traps
	[Enum.Material.Rock] = Color3.fromRGB(128, 126, 122),
}

-- Clear the old ground and set the look: grass blades, colours, water.
function Ground.reset()
	if not Ground.locked then
		terrain:Clear()
	end
	-- some Roblox versions don't let scripts set some of these (Decoration, GrassLength): skip those instead of
	-- stopping the whole world build
	local look = {
		Decoration = true, -- animated grass blades
		GrassLength = 0.25, -- short, like Chop A Forest's flat lawn, so the clumps you chop stand out
		WaterColor = Color3.fromRGB(46, 120, 110),
		WaterTransparency = 0.35,
		WaterWaveSize = 0.12,
		WaterWaveSpeed = 8,
		WaterReflectance = 0.6,
	}
	for prop, value in look do
		pcall(function()
			(terrain :: any)[prop] = value
		end)
	end
	for material, color in COLORS do
		terrain:SetMaterialColor(material, color)
	end
end

-- A flat slab of `material`, `w` x `d` studs centred on (cx, cz), top at y = 0, 8 studs deep.
function Ground.fill(cx: number, cz: number, w: number, d: number, material: Enum.Material)
	if Ground.locked then
		return
	end
	terrain:FillBlock(CFrame.new(cx, -4 - SINK, cz), Vector3.new(w, 8, d), material)
end

-- A flat disc of `material` (radius `r`) centred on (cx, cz), top at y = 0.
function Ground.disc(cx: number, cz: number, r: number, material: Enum.Material)
	if Ground.locked then
		return
	end
	terrain:FillCylinder(CFrame.new(cx, -4 - SINK, cz), 8, r, material)
end

-- A band of `material` out to radius `outer`. Terrain can't fill a ring directly: this fills the whole disc, and
-- whatever is painted inside `inner` afterwards covers the middle (paint from the outside in).
function Ground.ring(cx: number, cz: number, inner: number, outer: number, material: Enum.Material)
	local _ = inner
	Ground.disc(cx, cz, outer, material)
end

-- A patch of `material` with a ragged, natural edge: a block in the middle and overlapping discs of random size
-- all along its border (the ground stays flat; only the material changes).
function Ground.patch(cx: number, cz: number, w: number, d: number, material: Enum.Material, seed: number?)
	if Ground.locked then
		return
	end
	local rng = Random.new(seed or 1)
	terrain:FillBlock(CFrame.new(cx, -4 - SINK, cz), Vector3.new(math.max(4, w - 10), 8, math.max(4, d - 10)), material)
	local function disc(x: number, z: number, r: number)
		terrain:FillCylinder(CFrame.new(x, -4 - SINK, z), 8, r, material)
	end
	local step = 7
	for x = cx - w / 2, cx + w / 2, step do
		disc(x + rng:NextNumber(-2, 2), cz - d / 2 + rng:NextNumber(-3, 4), rng:NextNumber(4, 8))
		disc(x + rng:NextNumber(-2, 2), cz + d / 2 + rng:NextNumber(-4, 3), rng:NextNumber(4, 8))
	end
	for z = cz - d / 2, cz + d / 2, step do
		disc(cx - w / 2 + rng:NextNumber(-3, 4), z + rng:NextNumber(-2, 2), rng:NextNumber(4, 8))
		disc(cx + w / 2 + rng:NextNumber(-4, 3), z + rng:NextNumber(-2, 2), rng:NextNumber(4, 8))
	end
end

-- A worn path of `material` from a to b (flat on y = 0), `width` studs wide, with rounded, slightly wobbly edges.
function Ground.path(a: Vector3, b: Vector3, width: number, material: Enum.Material, seed: number?)
	if Ground.locked then
		return
	end
	local rng = Random.new(seed or 2)
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = dir.Magnitude
	if len < 0.1 then
		return
	end
	local n = math.max(2, math.floor(len / 4))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		terrain:FillCylinder(CFrame.new(p.X + rng:NextNumber(-0.8, 0.8), -4 - SINK, p.Z + rng:NextNumber(-0.8, 0.8)), 8, width / 2 * rng:NextNumber(0.85, 1.15), material)
	end
end

-- Water `w` x `d` with its surface at y = 0 and a muddy bed under it.
function Ground.water(cx: number, cz: number, w: number, d: number, depth: number?)
	if Ground.locked then
		return
	end
	local dp = depth or 4
	terrain:FillBlock(CFrame.new(cx, -dp - 4 - SINK, cz), Vector3.new(w + 8, 8, d + 8), Enum.Material.Mud)
	terrain:FillBlock(CFrame.new(cx, -dp / 2 - SINK, cz), Vector3.new(w, dp, d), Enum.Material.Water)
end

-- A rolling hill: the top of a big ball poking out of the ground, `height` studs high and `radius` across.
function Ground.hill(x: number, z: number, radius: number, height: number, material: Enum.Material?)
	if Ground.locked then
		return
	end
	-- a ball of radius R centred at y = height - R meets the ground in a circle of `radius`: R = (r^2 + h^2) / 2h
	local r = (radius * radius + height * height) / (2 * height)
	terrain:FillBall(Vector3.new(x, height - r - SINK, z), r, material or Enum.Material.Grass)
end

-- Levels the ground's surface to exactly y = 0 over a square (cx, cz) +- half. FillCylinder (discs, ragged patches,
-- paths) rounds the top terrain cell up to full, which shows the grass 2 studs too high; a half-full top cell
-- puts the surface right at y = 0. Hills (ground above y = 0) and water are left alone. Run it once the ground
-- is all painted.
function Ground.flatten(cx: number, cz: number, half: number)
	if Ground.locked then
		return
	end
	local tile = 256
	for x0 = cx - half, cx + half - 1, tile do
		for z0 = cz - half, cz + half - 1, tile do
			local region = Region3.new(Vector3.new(x0, -4, z0), Vector3.new(x0 + tile, 4, z0 + tile)):ExpandToGrid(4)
			local mats, occ = terrain:ReadVoxels(region, 4)
			local size = mats.Size
			local changed = false
			for ix = 1, size.X do
				for iz = 1, size.Z do
					local m = mats[ix][1][iz]
					if m ~= Enum.Material.Air and m ~= Enum.Material.Water and mats[ix][2][iz] == Enum.Material.Air then
						occ[ix][1][iz] = 0.5
						changed = true
					end
				end
			end
			if changed then
				terrain:WriteVoxels(region, 4, mats, occ)
			end
		end
		task.wait()
	end
end

return Ground
