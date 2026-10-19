-- The ground is Roblox Terrain, not flat bricks: textured grass with animated blades (Terrain.Decoration), dirt
-- clearings with ragged natural edges, real water in the swamp, and rolling hills on the horizon. Everything is
-- filled so the ground's top is at y = 0 (the world builders place things on y = 0).
local Ground = {}

local terrain = workspace.Terrain

local COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(98, 172, 58),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(72, 142, 48),
	[Enum.Material.Ground] = Color3.fromRGB(150, 112, 72),
	[Enum.Material.Mud] = Color3.fromRGB(96, 80, 60),
	[Enum.Material.Sand] = Color3.fromRGB(214, 186, 128),
	[Enum.Material.Rock] = Color3.fromRGB(128, 126, 122),
}

-- Clear the old ground and set the look: grass blades, colours, water.
function Ground.reset()
	terrain:Clear()
	-- some Roblox versions don't let scripts set some of these (Decoration, GrassLength): skip those instead of
	-- stopping the whole world build
	local look = {
		Decoration = true, -- animated grass blades
		GrassLength = 0.7,
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
	terrain:FillBlock(CFrame.new(cx, -4, cz), Vector3.new(w, 8, d), material)
end

-- A patch of `material` with a ragged, natural edge: a block in the middle and overlapping discs of random size
-- all along its border (the ground stays flat; only the material changes).
function Ground.patch(cx: number, cz: number, w: number, d: number, material: Enum.Material, seed: number?)
	local rng = Random.new(seed or 1)
	terrain:FillBlock(CFrame.new(cx, -4, cz), Vector3.new(math.max(4, w - 10), 8, math.max(4, d - 10)), material)
	local function disc(x: number, z: number, r: number)
		terrain:FillCylinder(CFrame.new(x, -4, z), 8, r, material)
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
	local rng = Random.new(seed or 2)
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = dir.Magnitude
	if len < 0.1 then
		return
	end
	local n = math.max(2, math.floor(len / 4))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		terrain:FillCylinder(CFrame.new(p.X + rng:NextNumber(-0.8, 0.8), -4, p.Z + rng:NextNumber(-0.8, 0.8)), 8, width / 2 * rng:NextNumber(0.85, 1.15), material)
	end
end

-- Water `w` x `d` with its surface at y = 0 and a muddy bed under it.
function Ground.water(cx: number, cz: number, w: number, d: number, depth: number?)
	local dp = depth or 4
	terrain:FillBlock(CFrame.new(cx, -dp - 4, cz), Vector3.new(w + 8, 8, d + 8), Enum.Material.Mud)
	terrain:FillBlock(CFrame.new(cx, -dp / 2, cz), Vector3.new(w, dp, d), Enum.Material.Water)
end

-- A rolling hill: the top of a big ball poking out of the ground, `height` studs high and `radius` across.
function Ground.hill(x: number, z: number, radius: number, height: number, material: Enum.Material?)
	-- a ball of radius R centred at y = height - R meets the ground in a circle of `radius`: R = (r^2 + h^2) / 2h
	local r = (radius * radius + height * height) / (2 * height)
	terrain:FillBall(Vector3.new(x, height - r, z), r, material or Enum.Material.Grass)
end

return Ground
