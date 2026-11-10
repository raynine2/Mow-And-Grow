--!strict
-- THE PET GARDEN, LUSH (10 Nov 2026, owner: "make pet garden bigger and more prettier 100x prettier with high quality";
-- he called the stud-voxel house "lelijk", so this one is built from the game's own good-looking models, the hub's
-- style: the blossom trees, bushes and fountain of the lobby map, the flower beds, fences, benches and lantern posts in
-- ReplicatedStorage.MowALawnModels). client/HubGarden draws it at the hub's GardenSpot; this file only builds.
--   * a round lawn (radius LAWN) on a cobblestone kerb, white picket fences round it with blossom bushes between
--   * a front gate toward the spawn: a timber arch with PET GARDEN, flower garlands and two lanterns; a back gate
--   * a winding stepping-stone path from gate to gate, the fountain in a pond of lily pads, two blossom trees
--   * four flower beds, two benches, lantern posts, butterflies, fireflies and drifting petals
--   * the two egg pedestals just inside the front gate, either side of the path
-- GardenBuild.build(at, parent) -> anchors (lawn coordinates: front = -Z, y 0 the ground): sign (world Vector3),
-- nestA / nestB (world Vector3, the egg's foot), pond = { x, z, r }, beds = { { x, z } }, trees = { { x, z, r } },
-- lawnR. nil when the models aren't there (client/HubGarden then builds the old garden).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GardenBuild = {}

local LAWN = 16
local C = Color3.fromRGB
local FONT = Enum.Font.FredokaOne

-- a template by name: the shared models first, then the lobby map (the trees, bushes and fountain live there)
local cache: { [string]: Instance | false } = {}
local function tpl(name: string): Instance?
	local c = cache[name]
	if c ~= nil then
		return if c then c else nil
	end
	local f = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local found = f and f:FindFirstChild(name)
	if not found then
		for _, root in { workspace:FindFirstChild("World"), workspace:FindFirstChild("Maps") } do
			found = found or (root and root:FindFirstChild(name, true))
		end
	end
	cache[name] = found or false
	return found
end

local function settle(inst: Instance)
	for _, d in (if inst:IsA("BasePart") then { inst } else inst:GetDescendants()) :: { Instance } do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- a copy of `name`, its longest side `size` studs (nil: as it is), its bottom middle on `cf`
local function put(parent: Instance, name: string, cf: CFrame, size: number?, collide: boolean?): Instance?
	local t = tpl(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	settle(m)
	if m:IsA("BasePart") then
		local p = m :: BasePart
		if size then
			local k = size / math.max(p.Size.X, p.Size.Y, p.Size.Z)
			p.Size *= k
		end
		p.CFrame = cf * CFrame.new(0, p.Size.Y / 2, 0)
		p.CanCollide = collide == true
	elseif m:IsA("Model") then
		local mm = m :: Model
		if size then
			local _, s = mm:GetBoundingBox()
			pcall(function()
				mm:ScaleTo(mm:GetScale() * size / math.max(s.X, s.Y, s.Z))
			end)
		end
		mm:PivotTo(cf)
		local bcf, bs = mm:GetBoundingBox()
		local l = cf:PointToObjectSpace(bcf.Position)
		mm:PivotTo(mm:GetPivot() + cf:VectorToWorldSpace(Vector3.new(-l.X, 0, -l.Z)) + Vector3.new(0, cf.Position.Y - (bcf.Position.Y - bs.Y / 2), 0))
		for _, d in mm:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = collide == true and d.CanCollide
			end
		end
	end
	m.Parent = parent
	return m
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 3
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- a flat round thing (lawn, stone, pad): a cylinder lying flat, top at `top`
local function disc(parent: Instance, at: CFrame, x: number, z: number, r: number, top: number, h: number, color: Color3, mat: Enum.Material): Part
	return part(parent, Vector3.new(h, r * 2, r * 2), at * CFrame.new(x, top - h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, mat, Enum.PartType.Cylinder)
end

local function flowerBall(parent: Instance, cf: CFrame, color: Color3, s: number)
	part(parent, Vector3.new(s, s, s), cf, color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(parent, Vector3.new(s * 0.45, s * 0.45, s * 0.45), cf * CFrame.new(0, s * 0.18, -s * 0.3), C(255, 236, 120), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

local FLOWERS = { C(255, 120, 170), C(255, 214, 70), C(250, 250, 255), C(190, 140, 255), C(255, 150, 80) }

local function emitter(parent: BasePart, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
end

function GardenBuild.build(at: CFrame, parent: Instance): { [string]: any }?
	if not tpl("fence") or not tpl("flower_bed") then
		return nil
	end
	local f = Instance.new("Model")
	f.Name = "lush_garden"
	local rng = Random.new(11)
	local function L(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end

	-- the ground: a cobblestone kerb, the lawn on it in two greens (mown rings), a soft dark edge
	disc(f, at, 0, 0, LAWN + 1.2, 0.55, 1.4, C(150, 142, 132), Enum.Material.Cobblestone)
	disc(f, at, 0, 0, LAWN, 0.75, 1.4, C(98, 186, 74), Enum.Material.Grass)
	for i, r in { LAWN - 3.5, LAWN - 7.5, LAWN - 11.5 } do
		disc(f, at, 0, 0, r, 0.77 + i * 0.002, 0.2, if i % 2 == 1 then C(112, 200, 82) else C(98, 186, 74), Enum.Material.Grass)
	end

	-- fences round the lawn with blossom bushes between, the front and back left open for the gates
	local gates = { { a = -math.pi / 2, half = 0.36 }, { a = math.pi / 2, half = 0.26 } } -- front (-Z), back (+Z)
	local function inGate(a: number): boolean
		for _, g in gates do
			local d = math.abs(math.atan2(math.sin(a - g.a), math.cos(a - g.a)))
			if d < g.half then
				return true
			end
		end
		return false
	end
	local n = 14
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * 2 * math.pi
		if not inGate(a) then
			local pos = Vector3.new(math.cos(a) * (LAWN + 0.4), 0.75, math.sin(a) * (LAWN + 0.4))
			local cf = at * CFrame.new(pos) * CFrame.Angles(0, -a + math.pi / 2, 0)
			put(f, "fence", cf, 7.4, true)
		end
		local b = i / n * 2 * math.pi
		if not inGate(b) then
			local pos = Vector3.new(math.cos(b) * (LAWN + 1.4), 0.6, math.sin(b) * (LAWN + 1.4))
			put(f, if i % 2 == 0 then "Bush_blossom" else "Bush_meadow", at * CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(4.2, 5.4))
		end
	end

	-- the front gate: two timber posts, a curved beam, garlands of flowers, lanterns, PET GARDEN
	local GZ = -LAWN - 0.6
	local wood, woodDark = C(176, 112, 62), C(118, 72, 40)
	for _, x in { -5.2, 5.2 } do
		part(f, Vector3.new(1.4, 1.2, 1.4), L(x, 0.6, GZ), C(140, 134, 126), Enum.Material.Cobblestone)
		part(f, Vector3.new(1, 10, 1), L(x, 6.2, GZ), wood, Enum.Material.Wood)
		for k = 0, 6 do
			flowerBall(f, L(x + (if x < 0 then -0.55 else 0.55), 2 + k * 1.25, GZ - 0.35) * CFrame.Angles(0, 0, k), FLOWERS[k % #FLOWERS + 1], 0.75)
		end
	end
	for k = -3, 3 do
		local x = k * 1.75
		local y = 11.4 + math.cos(k / 3 * math.pi / 2) * 1.3
		local tilt = -math.atan(math.sin(k / 3 * math.pi / 2) * 1.3 * (math.pi / 2) / 3 / 1.75) * 0.9
		part(f, Vector3.new(1.95, 0.9, 1.3), L(x, y, GZ) * CFrame.Angles(0, 0, tilt), if k % 2 == 0 then wood else woodDark, Enum.Material.Wood)
		flowerBall(f, L(x, y + 0.65, GZ - 0.4), FLOWERS[(k + 4) % #FLOWERS + 1], 0.7)
	end
	local board = part(f, Vector3.new(8.4, 2.1, 0.4), L(0, 10.2, GZ - 0.2), C(246, 226, 180), Enum.Material.WoodPlanks)
	part(f, Vector3.new(8.9, 2.5, 0.3), L(0, 10.2, GZ), woodDark, Enum.Material.Wood)
	for _, x in { -3.2, 3.2 } do
		part(f, Vector3.new(0.12, 1.4, 0.12), L(x, 11.6, GZ - 0.2), C(70, 60, 50), Enum.Material.Metal)
	end
	local sign = board.CFrame * CFrame.new(0, 0, -0.21)
	for _, x in { -6.6, 6.6 } do
		put(f, "lantern_post", L(x, 0.75, GZ - 1.2) * CFrame.Angles(0, if x < 0 then math.rad(-90) else math.rad(90), 0), 7.5)
	end
	-- the back gate: two short posts with lanterns
	for _, x in { -4.4, 4.4 } do
		part(f, Vector3.new(1.2, 3.4, 1.2), L(x, 2.4, LAWN + 0.4), wood, Enum.Material.Wood)
		part(f, Vector3.new(1.5, 0.5, 1.5), L(x, 4.3, LAWN + 0.4), woodDark, Enum.Material.Wood)
	end

	-- the stepping-stone path from gate to gate, winding round the fountain
	for i = 0, 15 do
		local t = i / 15
		local z = -LAWN + 0.8 + t * (2 * LAWN - 1.6)
		local x = -math.sin(t * math.pi) * 6.5 + (if i % 2 == 0 then 0.5 else -0.5)
		disc(f, at, x, z, rng:NextNumber(1.05, 1.35), 0.95, 0.4, C(196, 188, 176):Lerp(C(160, 152, 142), rng:NextNumber()), Enum.Material.Slate)
	end

	-- the pond and the fountain in it, lily pads, rocks round it
	local PX, PZ, PR = 5.5, 2.5, 5.2
	disc(f, at, PX, PZ, PR + 0.7, 0.95, 0.5, C(170, 162, 150), Enum.Material.Cobblestone)
	local water = disc(f, at, PX, PZ, PR, 1.0, 0.3, C(88, 190, 236), Enum.Material.Glass)
	water.Transparency = 0.15
	water.Reflectance = 0.15
	put(f, "forge_fountain", L(PX, 0.85, PZ), 6.5)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi + 0.4
		local r = PR - 1.1
		disc(f, at, PX + math.cos(a) * r, PZ + math.sin(a) * r, 0.7, 1.08, 0.08, C(82, 168, 72), Enum.Material.SmoothPlastic)
		if i % 2 == 0 then
			flowerBall(f, L(PX + math.cos(a) * r, 1.3, PZ + math.sin(a) * r), C(255, 150, 200), 0.45)
		end
	end
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi + 1.1
		put(f, "rock", L(PX + math.cos(a) * (PR + 0.8), 0.75, PZ + math.sin(a) * (PR + 0.8)) * CFrame.Angles(0, a, 0), rng:NextNumber(1.6, 2.4))
	end

	-- two blossom trees at the back, fallen petals under them
	local trees = { { x = -9.5, z = 8.5 }, { x = 9.5, z = 11.5 } }
	for i, t in trees do
		put(f, if i == 1 then "Tree_blossom_1" else "Tree_blossom_3", L(t.x, 0.75, t.z) * CFrame.Angles(0, i * 2.1, 0), 12.5)
		for _ = 1, 8 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(1, 4.2)
			part(f, Vector3.new(0.5, 0.05, 0.35), L(t.x + math.cos(a) * r, 0.79, t.z + math.sin(a) * r) * CFrame.Angles(0, a, 0), C(255, 180, 210))
		end
	end

	-- flower beds, benches, inner lanterns
	local beds = { { x = -11, z = -3 }, { x = -4, z = 12 }, { x = 12, z = -6 }, { x = 2.5, z = -9.5 } }
	for _, b in beds do
		put(f, "flower_bed", L(b.x, 0.75, b.z) * CFrame.lookAt(Vector3.zero, -Vector3.new(b.x, 0, b.z)), 6.2)
	end
	put(f, "bench", L(PX, 0.75, PZ + PR + 2.6) * CFrame.Angles(0, math.pi, 0), 5)
	put(f, "bench", L(-12.5, 0.75, 4.5) * CFrame.Angles(0, -math.pi / 2, 0), 5)
	for _, p in { Vector3.new(-6, 0.75, -2), Vector3.new(12, 0.75, 6.5) } do
		put(f, "lantern_post", L(p.X, p.Y, p.Z), 6.5)
	end

	-- the egg pedestals, just inside the front gate either side of the path
	local nests = {}
	for name, x in { nestA = 6.2, nestB = -7.2 } do
		local base = L(x, 0.75, -10.8)
		part(f, Vector3.new(2.6, 3.4, 3.4), base * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), C(206, 200, 190), Enum.Material.Marble, Enum.PartType.Cylinder)
		part(f, Vector3.new(0.4, 3.9, 3.9), base * CFrame.new(0, 2.35, 0) * CFrame.Angles(0, 0, math.rad(90)), C(230, 184, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
		for k = 0, 9 do
			local a = k / 10 * 2 * math.pi
			part(f, Vector3.new(1.1, 0.45, 0.6), base * CFrame.new(math.cos(a) * 1.25, 2.75, math.sin(a) * 1.25) * CFrame.Angles(0, -a, 0.3), if k % 2 == 0 then C(232, 196, 112) else C(206, 166, 86), Enum.Material.Fabric)
		end
		nests[name] = (base * CFrame.new(0, 2.6, 0)).Position
	end

	-- life: butterflies over the beds, fireflies at dusk-like glow, petals drifting off the trees
	local air = part(f, Vector3.new(LAWN * 1.6, 1, LAWN * 1.6), L(0, 4, 0), C(255, 255, 255))
	air.Transparency = 1
	emitter(air, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C(255, 240, 160)),
		LightEmission = 0.8, Rate = 3, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) }),
	})
	for _, t in trees do
		local up = part(f, Vector3.new(8, 1, 8), L(t.x, 10, t.z), C(255, 255, 255))
		up.Transparency = 1
		emitter(up, {
			Color = ColorSequence.new(C(255, 186, 214)), Rate = 2.5, Lifetime = NumberRange.new(4, 6),
			Speed = NumberRange.new(0.5, 1.2), Acceleration = Vector3.new(0.6, -1.2, 0.3), Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90), Size = NumberSequence.new(0.28), SpreadAngle = Vector2.new(60, 60),
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
		})
	end
	local bf = tpl("Butterflies")
	if bf then
		local b = bf:Clone()
		settle(b)
		if b:IsA("PVInstance") then
			b:PivotTo(L(0, 2.5, 0))
		end
		b.Parent = f
	end
	local glow = Instance.new("PointLight")
	glow.Color = C(255, 230, 180)
	glow.Range = 22
	glow.Brightness = 0.5
	glow.Parent = air

	-- the sign's words
	local sp = part(f, Vector3.new(8, 1.9, 0.05), sign, C(255, 255, 255))
	sp.Transparency = 1
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.Parent = sp
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.94, 0.9)
	t.Position = UDim2.fromScale(0.03, 0.05)
	t.Font = FONT
	t.TextScaled = true
	t.Text = "🐾 PET GARDEN 🐾"
	t.TextColor3 = C(120, 70, 36)
	t.Parent = sg

	f.Parent = parent
	return {
		sign = sign.Position,
		nestA = nests.nestA,
		nestB = nests.nestB,
		pond = { PX, PZ, PR + 0.6 },
		beds = { { beds[1].x, beds[1].z }, { beds[2].x, beds[2].z }, { beds[3].x, beds[3].z }, { beds[4].x, beds[4].z }, { -12.5, 4.5 }, { PX, PZ + PR + 2.6 } },
		trees = { { trees[1].x, trees[1].z, 3.2 }, { trees[2].x, trees[2].z, 3.2 } },
		lawnR = LAWN - 1.2,
		lush = true,
	}
end

return GardenBuild
