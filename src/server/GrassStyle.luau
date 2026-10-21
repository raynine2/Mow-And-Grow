-- How a grass clump looks, per area, in the Catch a Brainrot style: a tight cluster of 1 x 1 toy bricks standing
-- straight up on a one-stud grid, studs on top, heights in whole brick steps (tallest in the middle), two or three
-- close shades of the area's colour. Rare clumps are made of glowing bricks. server/Field builds every clump
-- with this; edit it to restyle the grass everywhere.
local Models = require(script.Parent.VoxelModels)

local GrassStyle = {}

local BRICK = 1.2 -- one brick's height

-- per area id: shades, rare glow colour, height range in bricks, how many bricks, brick width, an optional
-- "top" (a differently coloured last brick: wheat ears, flower heads, crystal tips)
GrassStyle.STYLES = {
	meadow = { shades = { Color3.fromRGB(48, 160, 64), Color3.fromRGB(62, 180, 74), Color3.fromRGB(38, 140, 58) }, rare = Color3.fromRGB(255, 214, 40), bricks = { 3, 7 }, count = 14, width = 1 },
	wheat = { shades = { Color3.fromRGB(232, 176, 58), Color3.fromRGB(246, 196, 80), Color3.fromRGB(214, 150, 44) }, top = Color3.fromRGB(255, 232, 150), rare = Color3.fromRGB(255, 255, 230), bricks = { 4, 8 }, count = 14, width = 0.8 },
	blossom = { shades = { Color3.fromRGB(86, 182, 96), Color3.fromRGB(70, 160, 84) }, top = Color3.fromRGB(255, 140, 200), top2 = Color3.fromRGB(255, 255, 255), rare = Color3.fromRGB(255, 60, 210), bricks = { 3, 6 }, count = 13, width = 1 },
	pine = { shades = { Color3.fromRGB(40, 150, 110), Color3.fromRGB(54, 170, 124), Color3.fromRGB(30, 126, 94) }, rare = Color3.fromRGB(190, 255, 110), bricks = { 3, 7 }, count = 14, width = 1 },
	swamp = { shades = { Color3.fromRGB(110, 146, 58), Color3.fromRGB(92, 128, 50) }, top = Color3.fromRGB(110, 70, 50), rare = Color3.fromRGB(200, 120, 255), bricks = { 5, 9 }, count = 12, width = 0.8 },
	frost = { shades = { Color3.fromRGB(244, 250, 255), Color3.fromRGB(220, 238, 255), Color3.fromRGB(200, 226, 250) }, rare = Color3.fromRGB(60, 230, 255), bricks = { 3, 7 }, count = 14, width = 1 },
	ember = { shades = { Color3.fromRGB(64, 52, 58), Color3.fromRGB(80, 64, 70) }, top = Color3.fromRGB(255, 120, 40), topNeon = true, rare = Color3.fromRGB(255, 214, 70), bricks = { 3, 6 }, count = 13, width = 1 },
	isles = { shades = { Color3.fromRGB(180, 140, 255), Color3.fromRGB(150, 110, 240) }, top = Color3.fromRGB(120, 240, 255), topNeon = true, rare = Color3.fromRGB(255, 255, 255), bricks = { 3, 7 }, count = 13, width = 1 },
}

-- the one-stud grid cells a clump uses, nearest the middle first
local SPOTS = {}
for x = -2, 2 do
	for z = -2, 2 do
		local d = math.sqrt(x * x + z * z)
		if d <= 2.3 then
			table.insert(SPOTS, { x = x, z = z, d = d })
		end
	end
end
table.sort(SPOTS, function(a, b)
	return a.d < b.d
end)

export type Stick = { part: BasePart, h: number, cell: Vector3 }

-- Build one clump standing on `at` (its foot, on the ground). `rng` is a Random. Returns the model and its
-- sticks (each stick's full height, so it can be shrunk while chopped and regrown).
-- The Blender clump (one mesh, two variants per area) when the models are imported; rare ones glow.
local function meshClump(parent: Instance, at: Vector3, id: string, rng: Random, rare: boolean): (Model?, { Stick }?)
	local name = "Clump_" .. id .. "_" .. rng:NextInteger(1, 2)
	if not Models.has(name) then
		return nil, nil
	end
	local m = Instance.new("Model")
	m.Name = "Clump"
	local p = Models.place(m, name, at, { scale = rng:NextNumber(0.95, 1.15), yaw = rng:NextInteger(0, 3) * math.pi / 2, shadow = false, name = "Stick" }) :: MeshPart
	if rare then
		local st = GrassStyle.STYLES[id] or GrassStyle.STYLES.meadow
		p.TextureID = ""
		p.Material = Enum.Material.Neon
		p.Color = st.rare
	end
	m.Parent = parent
	return m, { { part = p, h = p.Size.Y, cell = Vector3.zero } }
end

-- What's left after mowing, if the models are imported (nil otherwise).
function GrassStyle.stubble(parent: Instance, at: Vector3, id: string, rng: Random): MeshPart?
	return Models.place(parent, "Stubble_" .. id, at, { yaw = rng:NextInteger(0, 3) * math.pi / 2, shadow = false })
end

function GrassStyle.build(parent: Instance, at: Vector3, id: string, rng: Random, rare: boolean): (Model, { Stick })
	local mm, ms = meshClump(parent, at, id, rng, rare)
	if mm and ms then
		return mm, ms
	end
	local st = GrassStyle.STYLES[id] or GrassStyle.STYLES.meadow
	local m = Instance.new("Model")
	m.Name = "Clump"
	local sticks = {}
	local yaw = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	local n = math.min(st.count, #SPOTS)
	for k = 1, n do
		local s = SPOTS[k]
		-- the middle grows tallest; the edge is shorter and patchier
		local edge = s.d / 2.3
		if k > 5 and rng:NextNumber() < 0.18 then
			continue
		end
		local bricks = math.floor(rng:NextNumber(st.bricks[1], st.bricks[2] + 0.99) * (1 - edge * 0.4))
		bricks = math.max(st.bricks[1] - 1, bricks)
		local h = bricks * BRICK
		local cell = Vector3.new(s.x * st.width, 0, s.z * st.width)
		local color = st.shades[rng:NextInteger(1, #st.shades)]
		local mat = Enum.Material.Plastic
		if rare then
			color = st.rare
			mat = Enum.Material.Neon
		end
		local p = Instance.new("Part")
		p.Name = "Stick"
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = k <= 4
		p.Material = mat
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = Vector3.new(st.width, h, st.width)
		p.CFrame = yaw * CFrame.new(cell + Vector3.new(0, h / 2, 0))
		p.Parent = m
		table.insert(sticks, { part = p, h = h, cell = cell })
		-- a coloured head on some sticks (wheat ears, flowers, glowing tips)
		if st.top and not rare and rng:NextNumber() < 0.55 then
			local t = Instance.new("Part")
			t.Name = "Head"
			t.Anchored = true
			t.CanCollide = false
			t.CanTouch = false
			t.CastShadow = false
			t.Material = if st.topNeon then Enum.Material.Neon else Enum.Material.Plastic
			t.Color = if st.top2 and rng:NextNumber() < 0.4 then st.top2 else st.top
			t.TopSurface = Enum.SurfaceType.Studs
			t.BottomSurface = Enum.SurfaceType.Smooth
			local w = st.width * 1.15
			t.Size = Vector3.new(w, BRICK, w)
			t.CFrame = yaw * CFrame.new(cell + Vector3.new(0, h + BRICK / 2, 0))
			t.Parent = m
		end
	end
	m.Parent = parent
	return m, sticks
end

GrassStyle.BRICK = BRICK

return GrassStyle
