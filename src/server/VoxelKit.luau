-- Building blocks for the detailed voxel structures (the boss arenas, server/ArenaDress), in the look of the camp's
-- Tool Shop and Garage (server/CampBuildings): logs wearing a pixel wood texture with the grain along them, stone
-- with a pixel stone texture, plain blocks in a few close tones for boards, trim and roofs, iron lanterns with warm
-- light, braziers, barrels, crates, hay, rocks, crystals and bushes.
-- Everything here is in world space (CFrames), decoration only unless asked: no collisions, no queries.
-- The textures are MaterialVariants Studio made (MaterialService.AssistantMaterials); without them the blocks fall
-- back to plain colours.
local MaterialService = game:GetService("MaterialService")

local VoxelKit = {}

local SKIN: { [string]: { any } } = {
	log = { "MowVoxelLog", Enum.Material.Wood },
	stone = { "MowVoxelStone1", Enum.Material.Cobblestone },
	metal = { "MowVoxelMetal3", Enum.Material.CorrodedMetal },
}
local hasSkin: { [string]: boolean } = {}

VoxelKit.C = {
	log = Color3.fromRGB(236, 214, 190), -- tints over the textures
	stone = Color3.fromRGB(226, 226, 220),
	timber = Color3.fromRGB(92, 66, 50), -- plain blocks
	board = Color3.fromRGB(150, 112, 80),
	iron = Color3.fromRGB(54, 52, 52),
	lamp = Color3.fromRGB(255, 196, 120),
	straw = Color3.fromRGB(214, 176, 92),
	leaf = Color3.fromRGB(66, 112, 56),
	soil = Color3.fromRGB(70, 52, 40),
}
local C = VoxelKit.C

function VoxelKit.jitter(rng: Random, c: Color3, amt: number): Color3
	local k = 1 + (rng:NextNumber() * 2 - 1) * amt
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end
local jitter = VoxelKit.jitter

-- [a, b] split into pieces between minL and maxL long (the last one never shorter than minL).
function VoxelKit.chop(rng: Random, a: number, b: number, minL: number, maxL: number): { { number } }
	local out = {}
	local x = a
	while b - x > 0.01 do
		local len = math.min(rng:NextNumber(minL, maxL), b - x)
		if b - (x + len) < minL then
			len = b - x
		end
		table.insert(out, { x, x + len })
		x += len
	end
	return out
end

-- A block at `cf`. `look`: "log" / "stone" / "metal" (pixel texture) or a Material. Decoration (no collisions or
-- queries) unless `solid`. Small blocks cast no shadow.
function VoxelKit.part(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, look: any?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = size.X * size.Y * size.Z > 1.5
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if type(look) == "string" then
		local s = SKIN[look]
		if s then
			if hasSkin[look] == nil then
				hasSkin[look] = MaterialService:FindFirstChild(s[1], true) ~= nil
			end
			if hasSkin[look] then
				p.Material = s[2]
				p.MaterialVariant = s[1]
			else
				p.Color = color:Lerp(Color3.new(0, 0, 0), 0.2)
			end
		end
	elseif typeof(look) == "EnumItem" then
		p.Material = look
	end
	p.Parent = parent
	return p
end
local part = VoxelKit.part

-- A log lying along cf's X axis (turned so the texture's grain runs along it).
function VoxelKit.log(parent: Instance, cf: CFrame, len: number, h: number, depth: number, color: Color3): Part
	return part(parent, "Log", cf * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, len, depth), color, "log")
end

-- An upright cylinder standing on `base` (Roblox cylinders run along X).
function VoxelKit.cylinder(parent: Instance, name: string, base: CFrame, h: number, d: number, color: Color3, look: any?): Part
	local p = part(parent, name, base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, d, d), color, look)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function VoxelKit.light(p: BasePart, range: number, brightness: number, color: Color3?)
	local l = Instance.new("PointLight")
	l.Color = color or Color3.fromRGB(255, 206, 150)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- A small iron lantern standing on (or, `hang`, hanging under) `cf`. `glow`: the glass colour (warm by default).
function VoxelKit.lantern(parent: Instance, cf: CFrame, lit: boolean, glow: Color3?, hang: boolean?)
	local dy = if hang then -1 else 1
	local g = glow or C.lamp
	part(parent, "LanternBase", cf * CFrame.new(0, dy * 0.12, 0), Vector3.new(0.95, 0.24, 0.95), C.iron)
	local core = part(parent, "LanternGlass", cf * CFrame.new(0, dy * 0.75, 0), Vector3.new(0.7, 1.0, 0.7), g, Enum.Material.SmoothPlastic)
	core.Transparency = 0.12
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(parent, "LanternBar", cf * CFrame.new(sx * 0.37, dy * 0.75, sz * 0.37), Vector3.new(0.12, 1.1, 0.12), C.iron)
		end
	end
	part(parent, "LanternCap", cf * CFrame.new(0, dy * 1.4, 0), Vector3.new(1.05, 0.3, 1.05), C.iron)
	part(parent, "LanternCap", cf * CFrame.new(0, dy * 1.65, 0), Vector3.new(0.5, 0.25, 0.5), C.iron)
	if lit then
		VoxelKit.light(core, 14, 0.55, g:Lerp(Color3.new(1, 1, 1), 0.2))
	end
end

-- Flames: a soft fire and a few sparks on `p`, with light (`color` the light's colour).
function VoxelKit.fire(p: BasePart, color: Color3?, size: number?)
	local s = size or 1
	local f = Instance.new("ParticleEmitter")
	f.Name = "Flame"
	f.Texture = "rbxasset://textures/particles/fire_main.dds"
	f.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), color or Color3.fromRGB(255, 96, 30))
	f.LightEmission = 0.8
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * s), NumberSequenceKeypoint.new(1, 0.2 * s) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	f.Lifetime = NumberRange.new(0.5, 0.9)
	f.Rate = 18
	f.Speed = NumberRange.new(2, 3.5)
	f.SpreadAngle = Vector2.new(12, 12)
	f.Parent = p
	VoxelKit.light(p, 16, 0.9, color or Color3.fromRGB(255, 150, 70))
end

function VoxelKit.barrel(parent: Instance, base: CFrame, h: number, rng: Random)
	local d = h * 0.72
	VoxelKit.cylinder(parent, "Barrel", base, h, d, jitter(rng, C.board, 0.06))
	for _, f in { 0.16, 0.84 } do
		VoxelKit.cylinder(parent, "Hoop", base * CFrame.new(0, h * f - 0.11, 0), 0.22, d + 0.08, C.iron)
	end
	VoxelKit.cylinder(parent, "BarrelLid", base * CFrame.new(0, h - 0.02, 0), 0.06, d - 0.25, C.timber)
end

function VoxelKit.crate(parent: Instance, cf: CFrame, s: number, rng: Random)
	part(parent, "Crate", cf, Vector3.one * s, jitter(rng, C.board, 0.07))
	for _, face in { -1, 1 } do
		for _, f in { -1, 1 } do
			part(parent, "CrateBand", cf * CFrame.new(0, f * (s / 2 - 0.15), face * (s / 2 + 0.02)), Vector3.new(s + 0.04, 0.3, 0.1), C.timber)
			part(parent, "CrateBand", cf * CFrame.new(f * (s / 2 - 0.15), 0, face * (s / 2 + 0.02)), Vector3.new(0.3, s + 0.04, 0.1), C.timber)
		end
		part(parent, "CrateBrace", cf * CFrame.new(0, 0, face * (s / 2 + 0.04)) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.28, s * 1.25, 0.08), C.timber)
	end
end

-- A hay bale lying on `cf` (its middle on the ground), with two twine bands.
function VoxelKit.hay(parent: Instance, cf: CFrame, rng: Random)
	local size = Vector3.new(3, 1.6, 1.8)
	part(parent, "Hay", cf * CFrame.new(0, size.Y / 2, 0), size, jitter(rng, C.straw, 0.06), Enum.Material.Fabric)
	for _, x in { -0.8, 0.8 } do
		part(parent, "Twine", cf * CFrame.new(x, size.Y / 2, 0), Vector3.new(0.18, size.Y + 0.06, size.Z + 0.06), Color3.fromRGB(150, 110, 60))
	end
end

-- A heap of rocks round `cf`, stone texture in `tint`.
function VoxelKit.rocks(parent: Instance, cf: CFrame, tint: Color3, rng: Random, n: number?)
	for i = 1, n or 3 do
		local s = rng:NextNumber(1.2, 2.6) * (if i == 1 then 1.3 else 1)
		local off = CFrame.new(rng:NextNumber(-1.6, 1.6), s * 0.4, rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.3), rng:NextNumber(-0.3, 0.3))
		part(parent, "Rock", cf * off, Vector3.new(s * 1.2, s, s), jitter(rng, tint, 0.08), "stone")
	end
end

-- Glowing crystals (turned 45 degrees, tilted out) round `cf`.
function VoxelKit.crystals(parent: Instance, cf: CFrame, color: Color3, rng: Random, n: number?, lit: boolean?)
	local first: BasePart? = nil
	for i = 1, n or 4 do
		local h = rng:NextNumber(1.6, 4.2) * (if i == 1 then 1.3 else 1)
		local w = h * 0.32
		local tilt = CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.3), rng:NextNumber(-0.35, 0.35))
		local c = part(parent, "Crystal", cf * CFrame.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2)) * tilt * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(w, h, w), color, Enum.Material.Neon)
		c.Transparency = 0.15
		first = first or c
	end
	if lit and first then
		VoxelKit.light(first, 12, 0.6, color)
	end
end

-- A leafy bush of blocks round `cf` (on the ground), `color` its leaves, with a few flowers when `flowers` given.
function VoxelKit.bush(parent: Instance, cf: CFrame, color: Color3, rng: Random, flowers: { Color3 }?)
	for i = 1, 5 do
		local s = rng:NextNumber(1.2, 2.2) * (if i == 1 then 1.35 else 1)
		local p = part(parent, "Leaves", cf * CFrame.new(rng:NextNumber(-1.1, 1.1), s * 0.45 + (if i > 3 then 0.6 else 0), rng:NextNumber(-1.1, 1.1)), Vector3.one * s, jitter(rng, color, 0.1), Enum.Material.Grass)
		p.CastShadow = true
	end
	if flowers then
		for _ = 1, 4 do
			part(parent, "Flower", cf * CFrame.new(rng:NextNumber(-1.4, 1.4), rng:NextNumber(1.6, 2.5), rng:NextNumber(-1.4, 1.4)), Vector3.one * 0.42, flowers[rng:NextInteger(1, #flowers)])
		end
	end
end

-- A planter box (w wide) with leafy mounds and flowers, its middle at `cf` (on the ground).
function VoxelKit.planter(parent: Instance, cf: CFrame, w: number, flowers: { Color3 }, rng: Random)
	part(parent, "Planter", cf * CFrame.new(0, 0.5, 0), Vector3.new(w, 1.0, 1.1), jitter(rng, C.board, 0.05))
	part(parent, "PlanterRim", cf * CFrame.new(0, 1.04, 0), Vector3.new(w + 0.2, 0.12, 1.3), C.timber)
	part(parent, "Soil", cf * CFrame.new(0, 1.0, 0), Vector3.new(w - 0.25, 0.08, 0.85), C.soil)
	local n = math.max(2, math.floor(w / 0.85))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * w / n
		local s = rng:NextNumber(0.55, 0.85)
		part(parent, "Leaves", cf * CFrame.new(x, 1.0 + s / 2, rng:NextNumber(-0.12, 0.12)), Vector3.one * s, jitter(rng, C.leaf, 0.12))
		if i % 2 == 1 then
			part(parent, "Flower", cf * CFrame.new(x + 0.1, 1.0 + s + 0.15, 0), Vector3.one * 0.38, flowers[rng:NextInteger(1, #flowers)])
		end
	end
end

-- A stepped block roof on a square top (w across) at `cf`: `steps` shrinking slabs and a cap.
function VoxelKit.pyramid(parent: Instance, cf: CFrame, w: number, steps: number, rise: number, color: Color3, rng: Random)
	for i = 0, steps - 1 do
		local s = w - i * (w / (steps + 0.6))
		part(parent, "Roof", cf * CFrame.new(0, i * rise + rise / 2, 0), Vector3.new(s, rise, s), jitter(rng, color, 0.05))
		part(parent, "RoofEdge", cf * CFrame.new(0, i * rise + 0.12, 0), Vector3.new(s + 0.12, 0.24, s + 0.12), C.timber)
	end
	part(parent, "RoofCap", cf * CFrame.new(0, steps * rise + 0.3, 0), Vector3.new(0.9, 0.6, 0.9), C.timber)
end

return VoxelKit
