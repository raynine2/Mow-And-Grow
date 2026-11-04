--!strict
-- What's left of a cut clump, like a tree stump in Chop A Forest: a short stalk of bundled stems on its root flare,
-- built from a few blocks on the clump's voxel grain (0.4 studs at scale 1: tools/blender/voxel/models.py
-- STALK_VOXEL) in the clump's own colours (models.py GRASS), so it matches the standing grass beside it.
-- (4 Nov, owner, on the old Blender stubble: "i also dont like the no detailed grass brightness". Its cut face was
-- the clump's green lifted to near white mint, the brightest thing on the field. Now the cut face is the stem colour
-- turned toward straw, inset like the camp's paving stones (server/CampGround), and the stalk keeps the clump's darker
-- stem stripes at its corners; nothing on it is lighter than the mowed lawn under it.)
-- server/Field puts one where a clump falls and destroys it when the area is cleared.
local Stubble = {}

local C = Color3.fromRGB
-- each area's stem shades, the same as its clumps' (models.py GRASS): [1] the stalk's main shade
local SHADES: { [string]: { Color3 } } = {
	meadow = { C(48, 160, 64), C(62, 180, 74), C(38, 140, 58) },
	wheat = { C(232, 176, 58), C(246, 196, 80), C(214, 150, 44) },
	blossom = { C(86, 182, 96), C(70, 160, 84) },
	pine = { C(40, 150, 110), C(54, 170, 124), C(30, 126, 94) },
	swamp = { C(110, 146, 58), C(92, 128, 50) },
	frost = { C(244, 250, 255), C(220, 238, 255), C(200, 226, 250) },
	ember = { C(64, 52, 58), C(80, 64, 70) },
	isles = { C(180, 140, 255), C(150, 110, 240) },
}
local STRAW = C(226, 206, 118) -- the inside of a cut stem
local CUT = 0.55 -- how far the cut face turns to straw
local VOXEL = 0.4 -- studs per voxel at scale 1

local function mul(c: Color3, k: number): Color3
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

local function block(m: Model, size: Vector3, cf: CFrame, col: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Parent = m
	return p
end

-- A stump for an area (`id`: "meadow", "wheat"...) standing on `foot`, `scale` times the clump's size, turned `yaw`.
function Stubble.build(parent: Instance, id: string, foot: Vector3, scale: number, yaw: number): Model
	local sh = SHADES[id] or SHADES.meadow
	local v = VOXEL * scale
	local base = CFrame.new(foot) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model")
	m.Name = "Stubble_" .. id
	local root = mul(sh[1], 0.66)
	local dark = mul(sh[1], 0.8)
	local stem = sh[2] or sh[1]
	-- the root flare: a low plus round the foot, and a few stubs off its arms
	block(m, Vector3.new(5 * v, 0.9 * v, 3 * v), base * CFrame.new(0, 0.45 * v, 0), root)
	block(m, Vector3.new(3 * v, 0.9 * v, 5 * v), base * CFrame.new(0, 0.45 * v, 0), root)
	local rng = Random.new(math.floor(foot.X * 7 + foot.Z * 13))
	for _, d in { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } } do
		if rng:NextNumber() < 0.5 then
			block(m, Vector3.new(v, 0.6 * v, v), base * CFrame.new(d[1] * v, 0.3 * v, d[2] * v), root)
		end
	end
	-- the cut stalk, its darker stems at the corners (a hair proud of it, so they don't flicker)
	local h = 2.2 * v
	local e = 0.03
	block(m, Vector3.new(3 * v, h, 3 * v), base * CFrame.new(0, h / 2, 0), stem)
	for _, d in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		block(m, Vector3.new(v + e, h + e, v + e), base * CFrame.new(d[1] * v, (h + e) / 2, d[2] * v), dark)
	end
	-- the cut face, inset (client/ClumpWound rings it with fibre bundles for the player who cut it)
	local face = block(m, Vector3.new(2.6 * v, 0.04, 2.6 * v), base * CFrame.new(0, h + e + 0.005, 0), sh[1]:Lerp(STRAW, CUT))
	face.Name = "CutFace"
	m.Parent = parent
	return m
end

return Stubble
