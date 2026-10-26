-- The camp fountain, remade to fit the camp (the owner, 26 Oct: "remake the fountain and make it fit the area").
-- The old one (PartModels/camp_fountain, grey marble) looked cold next to the golden paving, the log cabins and the
-- wooden benches. This one is a garden fountain in the camp's own materials:
--   * an octagonal basin of warm studded sandstone (the paving's colours, a shade deeper) with plank caps like the
--     benches, moss on a few caps, a dark wet floor and clear water with lily pads
--   * in the middle a stack of mossy stones holding a big tilted watering can (teal paint, brass band) that pours
--     an arc of water into the pool: a stream, a splash and ripples where it lands, a little mist
--   * four wooden planters of flowers on the corners (where the old ones stood)
-- It keeps the old footprint (about 9.5 studs across), so the benches round it still fit.
-- Built by tools/studio-camp-fountain.luau into the saved camp (Workspace.World.Hub.CampDecor), in edit mode.
local PropKit = require(script.Parent.PropKit)

local CampFountain = {}

local SAND = { Color3.fromRGB(214, 160, 96), Color3.fromRGB(200, 148, 86), Color3.fromRGB(222, 170, 106) }
local PLANK = Color3.fromRGB(150, 100, 58)
local PLANK_DARK = Color3.fromRGB(122, 80, 46)
local MOSS = Color3.fromRGB(96, 160, 58)
local WET = Color3.fromRGB(118, 92, 66)
local WATER = Color3.fromRGB(84, 176, 222)
local PAINT = Color3.fromRGB(64, 150, 132)
local PAINT_DARK = Color3.fromRGB(44, 112, 98)
local BRASS = Color3.fromRGB(226, 176, 74)
local GLOW = "rbxassetid://125552447014366"
local RING = "rbxassetid://115339930898563"

local function part(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?, shape: Enum.PartType?): Part
	local p = PropKit.part({ size = size, cf = cf, color = color, parent = m, name = name, material = material, collide = solid == true, shape = shape })
	p.CastShadow = solid == true
	if not solid then
		p.CanQuery = false
		p.CanTouch = false
	end
	return p
end

-- a cylinder standing up (Roblox cylinders run along X)
local function disc(m: Instance, name: string, radius: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
	return part(m, name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, solid, Enum.PartType.Cylinder)
end

local function seq(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new(a, b)
end

local function nseq(...): NumberSequence
	local args = { ... }
	local keys = {}
	for i = 1, #args, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(keys)
end

-- the basin: eight studded sandstone walls with plank caps, moss on some, the wet floor and the water
local function basin(m: Instance, at: CFrame, rng: Random): number
	local apothem = 3.75
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local face = at * CFrame.Angles(0, -a, 0)
		local wall = part(m, "Wall", Vector3.new(3.3, 1.3, 0.7), face * CFrame.new(0, 0.65, -apothem), SAND[i % #SAND + 1], Enum.Material.Sandstone, true)
		wall.TopSurface = Enum.SurfaceType.Studs
		local cap = part(m, "Cap", Vector3.new(3.45, 0.26, 1.05), face * CFrame.new(0, 1.43, -apothem - 0.05), if i % 2 == 0 then PLANK else PLANK_DARK, Enum.Material.WoodPlanks, true)
		cap.TopSurface = Enum.SurfaceType.Studs
		if rng:NextNumber() < 0.4 then
			part(m, "Moss", Vector3.new(rng:NextNumber(0.9, 1.6), 0.1, 0.7), face * CFrame.new(rng:NextNumber(-0.9, 0.9), 1.6, -apothem - 0.05), MOSS, Enum.Material.Grass)
		end
		-- a little foot stone outside each corner
		local corner = at * CFrame.Angles(0, -math.rad(i * 45), 0) * CFrame.new(0, 0.2, -4.15)
		part(m, "Foot", Vector3.new(0.9, 0.4, 0.9), corner * CFrame.Angles(0, math.rad(45), 0), SAND[(i + 1) % #SAND + 1], Enum.Material.Sandstone, true)
	end
	disc(m, "Floor", 3.75, 0.4, at * CFrame.new(0, 0.2, 0), WET, Enum.Material.Slate, true)
	local waterY = 1.08
	local water = disc(m, "Water", 3.55, 0.12, at * CFrame.new(0, waterY, 0), WATER, Enum.Material.Glass)
	water.Transparency = 0.3
	water.Reflectance = 0.15
	-- lily pads, one in flower
	for i = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1.9, 2.8)
		local pad = at * CFrame.new(math.cos(a) * r, waterY + 0.08, math.sin(a) * r)
		disc(m, "LilyPad", rng:NextNumber(0.45, 0.62), 0.06, pad, Color3.fromRGB(86, 166, 62), Enum.Material.SmoothPlastic)
		if i == 1 then
			part(m, "Lily", Vector3.new(0.38, 0.38, 0.38), pad * CFrame.new(0.1, 0.18, 0), Color3.fromRGB(250, 150, 190), Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
			part(m, "LilyHeart", Vector3.new(0.16, 0.16, 0.16), pad * CFrame.new(0.1, 0.36, 0), Color3.fromRGB(255, 220, 90), Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
		end
	end
	return waterY
end

-- the middle: mossy stones and the watering can pouring into the pool; returns the spout's tip (+Y along the pour)
local function wateringCan(m: Instance, at: CFrame): CFrame
	local stones = {
		{ Vector3.new(1.9, 1, 1.9), 0.9, 0 },
		{ Vector3.new(1.6, 0.9, 1.6), 1.85, 22 },
		{ Vector3.new(1.75, 0.6, 1.75), 2.6, 41 },
	}
	for i, s in stones do
		local stone = part(m, "Pedestal", s[1], at * CFrame.new(0, s[2], 0) * CFrame.Angles(0, math.rad(s[3]), 0), SAND[i], Enum.Material.Sandstone, true)
		stone.TopSurface = Enum.SurfaceType.Studs
	end
	part(m, "Moss", Vector3.new(1.1, 0.12, 0.8), at * CFrame.new(-0.35, 2.36, 0.4) * CFrame.Angles(0, 0.4, 0), MOSS, Enum.Material.Grass)
	-- the can, tipped forward (+X) to pour
	local base = at * CFrame.new(-0.6, 2.9, 0) * CFrame.Angles(0, 0, math.rad(-24))
	disc(m, "CanBody", 0.95, 1.9, base * CFrame.new(0, 0.95, 0), PAINT, Enum.Material.Metal, true)
	disc(m, "CanBand", 0.99, 0.22, base * CFrame.new(0, 1.15, 0), BRASS, Enum.Material.Metal)
	disc(m, "CanFoot", 0.99, 0.16, base * CFrame.new(0, 0.08, 0), PAINT_DARK, Enum.Material.Metal)
	disc(m, "CanLid", 0.7, 0.14, base * CFrame.new(0, 1.95, 0), PAINT_DARK, Enum.Material.Metal)
	disc(m, "CanKnob", 0.18, 0.2, base * CFrame.new(0, 2.08, 0), BRASS, Enum.Material.Metal)
	-- the handle: an arch over the top, at the back
	part(m, "Handle", Vector3.new(0.22, 1.2, 0.22), base * CFrame.new(-1.05, 1.55, 0), PAINT_DARK, Enum.Material.Metal)
	part(m, "Handle", Vector3.new(1.0, 0.22, 0.22), base * CFrame.new(-0.6, 2.12, 0), PAINT_DARK, Enum.Material.Metal)
	-- the spout: from low on the front, out and a little down (so the water lands well inside the pool), the rose
	-- on the end
	local root = base * CFrame.new(0.8, 0.45, 0)
	local dir = base * CFrame.Angles(0, 0, math.rad(-81)) -- (+Y of this points along the spout)
	local len = 1.7
	local spout = CFrame.new(root.Position) * (dir - dir.Position) * CFrame.new(0, len / 2, 0)
	part(m, "Spout", Vector3.new(0.3, len, 0.3), spout, PAINT, Enum.Material.Metal)
	local tip = CFrame.new(root.Position) * (dir - dir.Position) * CFrame.new(0, len + 0.05, 0)
	disc(m, "Rose", 0.32, 0.22, tip, BRASS, Enum.Material.Metal)
	return tip
end

-- where water leaving `from` along its +Y at `speed` (gravity `g`) comes down to height `y`
local function landing(from: CFrame, speed: number, g: number, y: number): Vector3
	local p = from.Position
	local v = from.UpVector * speed
	for _ = 1, 400 do
		local dt = 0.005
		v += Vector3.new(0, -g * dt, 0)
		p += v * dt
		if p.Y <= y and v.Y < 0 then
			break
		end
	end
	return p
end

local function water(m: Instance, at: CFrame, tip: CFrame, waterY: number)
	local SPEED, G = 2.5, 18
	local a = Instance.new("Attachment")
	a.Name = "Pour"
	a.Parent = m:FindFirstChild("Spout")
	a.WorldCFrame = tip
	local pour = Instance.new("ParticleEmitter")
	pour.Name = "Pour"
	pour.Texture = GLOW
	pour.Rate = 70
	pour.Lifetime = NumberRange.new(0.38, 0.42)
	pour.Speed = NumberRange.new(SPEED * 0.95, SPEED * 1.05)
	pour.SpreadAngle = Vector2.new(5, 5)
	pour.EmissionDirection = Enum.NormalId.Top
	pour.Acceleration = Vector3.new(0, -G, 0)
	pour.Size = nseq(0, 0.3, 1, 0.22)
	pour.Transparency = nseq(0, 0.3, 0.85, 0.45, 1, 1)
	pour.Color = seq(Color3.fromRGB(235, 250, 255), Color3.fromRGB(150, 215, 245))
	pour.LightEmission = 0.3
	pour.LightInfluence = 0.7
	pour.Parent = a
	-- where it lands: a splash, ripples spreading, a little mist
	local hit = landing(tip, SPEED, G, at.Y + waterY)
	local splashAt = Instance.new("Attachment")
	splashAt.Name = "Splash"
	splashAt.Parent = m:FindFirstChild("Floor")
	splashAt.WorldCFrame = CFrame.new(hit.X, at.Y + waterY + 0.08, hit.Z)
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Texture = GLOW
	splash.Rate = 30
	splash.Lifetime = NumberRange.new(0.35, 0.5)
	splash.Speed = NumberRange.new(2, 3.5)
	splash.SpreadAngle = Vector2.new(55, 55)
	splash.Acceleration = Vector3.new(0, -16, 0)
	splash.Size = nseq(0, 0.2, 1, 0.08)
	splash.Transparency = nseq(0, 0.3, 1, 1)
	splash.Color = seq(Color3.fromRGB(240, 252, 255), Color3.fromRGB(190, 230, 250))
	splash.LightInfluence = 0.7
	splash.Parent = splashAt
	local ripple = Instance.new("ParticleEmitter")
	ripple.Name = "Ripple"
	ripple.Texture = RING
	ripple.Rate = 2.5
	ripple.Lifetime = NumberRange.new(1.4, 1.6)
	ripple.Speed = NumberRange.new(0.01)
	ripple.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ripple.Size = nseq(0, 0.3, 1, 2.6)
	ripple.Transparency = nseq(0, 0.35, 1, 1)
	ripple.Color = seq(Color3.fromRGB(235, 250, 255), Color3.fromRGB(235, 250, 255))
	ripple.LightInfluence = 0.6
	ripple.Parent = splashAt
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = GLOW
	mist.Rate = 3
	mist.Lifetime = NumberRange.new(1.2, 1.8)
	mist.Speed = NumberRange.new(0.3, 0.6)
	mist.Size = nseq(0, 0.8, 1, 1.8)
	mist.Transparency = nseq(0, 1, 0.3, 0.85, 1, 1)
	mist.Color = seq(Color3.new(1, 1, 1), Color3.fromRGB(220, 240, 255))
	mist.LightInfluence = 0.8
	mist.Parent = splashAt
	-- slow rings across the rest of the pool
	local pool = part(m, "PoolArea", Vector3.new(5.6, 0.05, 5.6), at * CFrame.new(0, waterY + 0.08, 0), WATER)
	pool.Transparency = 1
	local calm = ripple:Clone()
	calm.Name = "CalmRipple"
	calm.Rate = 0.8
	calm.Size = nseq(0, 0.2, 1, 1.6)
	calm.Transparency = nseq(0, 0.55, 1, 1)
	calm.Shape = Enum.ParticleEmitterShape.Disc
	calm.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	calm.EmissionDirection = Enum.NormalId.Top
	calm.Parent = pool
end

-- four planters of flowers on the corners
local function planters(m: Instance, at: CFrame, rng: Random)
	local FLOWERS = { Color3.fromRGB(250, 140, 180), Color3.fromRGB(255, 214, 80), Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 140, 255) }
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local cf = at * CFrame.new(math.cos(a) * 5, 0, math.sin(a) * 5) * CFrame.Angles(0, -a + math.rad(90), 0)
		local box = part(m, "Planter", Vector3.new(1.7, 0.8, 1.1), cf * CFrame.new(0, 0.4, 0), PLANK, Enum.Material.WoodPlanks, true)
		box.TopSurface = Enum.SurfaceType.Studs
		part(m, "PlanterRim", Vector3.new(1.85, 0.14, 1.25), cf * CFrame.new(0, 0.82, 0), PLANK_DARK, Enum.Material.WoodPlanks)
		part(m, "Soil", Vector3.new(1.5, 0.1, 0.9), cf * CFrame.new(0, 0.84, 0), Color3.fromRGB(96, 66, 44), Enum.Material.Ground)
		part(m, "Leaves", Vector3.new(1.3, 0.55, 0.75), cf * CFrame.new(0, 1.1, 0), Color3.fromRGB(88, 158, 60), Enum.Material.Grass)
		for j = 1, 4 do
			local x = -0.55 + (j - 1) * 0.37 + rng:NextNumber(-0.06, 0.06)
			part(m, "Flower", Vector3.new(0.34, 0.34, 0.34), cf * CFrame.new(x, 1.45 + rng:NextNumber(-0.05, 0.12), rng:NextNumber(-0.18, 0.18)), FLOWERS[(i + j) % #FLOWERS + 1], Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
		end
	end
end

-- Build the fountain into a new Model under `parent`, its floor centre at `at`.
function CampFountain.build(parent: Instance, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "camp_fountain"
	local rng = Random.new(2210)
	local waterY = basin(m, at, rng)
	local tip = wateringCan(m, at)
	planters(m, at, rng)
	water(m, at, tip, waterY)
	m.WorldPivot = at
	m:SetAttribute("GardenFountain", true)
	m.Parent = parent
	return m
end

return CampFountain
