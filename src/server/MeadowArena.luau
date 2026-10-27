-- The Sunny Meadow boss arena (the Dandelion King's), its own look (owner, 27 Oct: "remake the first one, it's
-- very bad"; the stone towers and picket wall read as grey bricks on a flat green disc).
-- A garden, not a fort: a thick hedge wall in chunky leaf blocks with flowers in it, topiary pillars on the joints,
-- a rose arbour over the way in, a lawn mown in light and dark stripes with a stepping-stone path from the arbour to
-- the summon pad, giant dandelions (yellow heads and white puff balls) round the inside, flower beds, and four
-- sunflowers round the pad. Built from blocks like the voxel trees: a few close greens, a shade off each other.
-- Everything is decoration (no collisions or queries); BossArena's colliders, gate bars and pad do the work.
-- Called by server/ArenaDress for the meadow (its Ctx: centre on the floor top, r, facing, segs, yaw0, look).
local VoxelKit = require(script.Parent.VoxelKit)

local MeadowArena = {}

local C = Color3.fromRGB
local part, jitter, chop = VoxelKit.part, VoxelKit.jitter, VoxelKit.chop

local HEDGE = { C(62, 132, 54), C(54, 120, 48), C(72, 144, 60), C(48, 110, 44) }
local FLOWERS = { C(255, 214, 60), C(255, 255, 255), C(232, 96, 110), C(255, 160, 60), C(190, 140, 230) }
local TIMBER = C(118, 84, 58)
local TIMBER_DARK = C(86, 60, 42)
local STONE = C(206, 200, 186)
local H = 9 -- the hedge's height (the arena is 140 across: a tall, thick hedge reads as a wall)
local D = 4.4 -- its depth

local function leaf(rng: Random): Color3
	return jitter(rng, HEDGE[rng:NextInteger(1, #HEDGE)], 0.05)
end

-------------------------------------------------------------------------------------------------------------
-- geometry (the same as ArenaDress's)
-------------------------------------------------------------------------------------------------------------
local function jointAngle(ctx, j: number): number
	return ctx.yaw0 + j / ctx.segs * 2 * math.pi
end

local function rimPoint(ctx, a: number, rad: number): Vector3
	return ctx.centre + Vector3.new(math.sin(a), 0, math.cos(a)) * rad
end

-- X along the ring, -Z into the arena, on the floor top
local function rimFrame(ctx, a: number, rad: number): CFrame
	local pos = rimPoint(ctx, a, rad)
	return CFrame.fromMatrix(pos, Vector3.new(math.cos(a), 0, -math.sin(a)), Vector3.yAxis, Vector3.new(math.sin(a), 0, math.cos(a)))
end

local function sectionFrame(ctx, j: number): (CFrame, number)
	local a, b = rimPoint(ctx, jointAngle(ctx, j), ctx.r), rimPoint(ctx, jointAngle(ctx, j + 1), ctx.r)
	local x = (b - a).Unit
	return CFrame.fromMatrix((a + b) / 2, x, Vector3.yAxis, x:Cross(Vector3.yAxis)), (b - a).Magnitude
end

-------------------------------------------------------------------------------------------------------------
-- pieces
-------------------------------------------------------------------------------------------------------------
-- A flower: two crossed petal bars round a centre (`cf` at its middle, facing up), `s` its size (3 parts: the
-- arena has a lot of them).
local function flower(parent: Instance, cf: CFrame, color: Color3, s: number)
	part(parent, "FlowerHeart", cf * CFrame.new(0, s * 0.05, 0), Vector3.one * s * 0.42, if color == FLOWERS[1] then C(214, 140, 40) else C(255, 214, 80))
	part(parent, "Petals", cf, Vector3.new(s * 1.1, s * 0.22, s * 0.36), color)
	part(parent, "Petals", cf, Vector3.new(s * 0.36, s * 0.22, s * 1.1), color)
end

-- One section of hedge from joint to joint: a timber edging board along both feet, the hedge body in long blocks,
-- leaf cubes bulging out of both faces and the top, flowers in it.
local function hedgeSection(parent: Instance, f: CFrame, L: number, rng: Random)
	for _, z in { -D / 2 - 0.2, D / 2 + 0.2 } do
		part(parent, "Edging", f * CFrame.new(0, 0.3, z), Vector3.new(L + 0.4, 0.6, 0.35), TIMBER_DARK)
	end
	-- a flower border along the inside foot: a soil strip with flowers and leafy tufts
	part(parent, "Border", f * CFrame.new(0, 0.12, -D / 2 - 1.3), Vector3.new(L + 0.1, 0.24, 1.9), C(92, 66, 46))
	for x = -L / 2 + 0.7, L / 2 - 0.7, 1.6 do
		if rng:NextNumber() < 0.5 then
			flower(parent, f * CFrame.new(x + rng:NextNumber(-0.3, 0.3), 0.75, -D / 2 - 1.3 + rng:NextNumber(-0.4, 0.4)), FLOWERS[rng:NextInteger(1, #FLOWERS)], rng:NextNumber(0.8, 1.1))
			part(parent, "FlowerStem", f * CFrame.new(x, 0.4, -D / 2 - 1.3), Vector3.new(0.15, 0.5, 0.15), C(80, 140, 56))
		else
			part(parent, "Tuft", f * CFrame.new(x, 0.55, -D / 2 - 1.3 + rng:NextNumber(-0.4, 0.4)), Vector3.one * rng:NextNumber(0.7, 1.0), leaf(rng))
		end
	end
	for _, piece in chop(rng, -L / 2 - 0.1, L / 2 + 0.1, 2.4, 4.2) do
		local h = H + rng:NextNumber(-0.4, 0.3)
		local p = part(parent, "Hedge", f * CFrame.new((piece[1] + piece[2]) / 2, h / 2, 0), Vector3.new(piece[2] - piece[1] + 0.02, h, D), leaf(rng))
		p.CastShadow = true
	end
	-- bulges: cubes half out of the faces and the top, so the hedge isn't a flat box
	for _ = 1, 12 do
		local s = rng:NextNumber(1.2, 2.2)
		local side = if rng:NextNumber() < 0.6 then -1 else 1
		part(parent, "Leaves", f * CFrame.new(rng:NextNumber(-L / 2 + 0.7, L / 2 - 0.7), rng:NextNumber(1.0, H - 1.0), side * (D / 2 + s * 0.12)), Vector3.one * s, leaf(rng))
	end
	for _ = 1, 5 do
		local s = rng:NextNumber(1.6, 2.6)
		part(parent, "Leaves", f * CFrame.new(rng:NextNumber(-L / 2 + 1, L / 2 - 1), H - 0.2 + s * 0.3, rng:NextNumber(-1, 1)), Vector3.one * s, leaf(rng))
	end
	-- flowers on the inner face (the side you fight on) and a couple on top
	for i = 1, 6 do
		local top = i > 4
		local cf = if top
			then f * CFrame.new(rng:NextNumber(-L / 2 + 0.6, L / 2 - 0.6), H + 0.4, rng:NextNumber(-1.2, 1.2))
			else f * CFrame.new(rng:NextNumber(-L / 2 + 0.6, L / 2 - 0.6), rng:NextNumber(1.5, H - 1.2), -D / 2 - 0.12) * CFrame.Angles(math.rad(90), 0, 0)
		flower(parent, cf, FLOWERS[rng:NextInteger(1, #FLOWERS)], rng:NextNumber(1.0, 1.4))
	end
end

-- A topiary pillar on a joint: a taller square of hedge with a ball (stacked cubes) on top; some with a lantern.
local function topiary(parent: Instance, jf: CFrame, rng: Random, lit: boolean)
	part(parent, "TopiaryPot", jf * CFrame.new(0, 0.6, 0), Vector3.new(5.4, 1.2, 5.4), jitter(rng, STONE, 0.04), "stone")
	part(parent, "Topiary", jf * CFrame.new(0, 1.2 + (H + 1.2) / 2, 0), Vector3.new(5.0, H + 1.2, 5.0), leaf(rng))
	local y = H + 2.4 + 1.9
	part(parent, "TopiaryBall", jf * CFrame.new(0, y, 0), Vector3.new(4.0, 3.8, 4.0), leaf(rng))
	part(parent, "TopiaryBall", jf * CFrame.new(0, y, 0), Vector3.new(4.8, 2.6, 2.6), leaf(rng))
	part(parent, "TopiaryBall", jf * CFrame.new(0, y, 0), Vector3.new(2.6, 2.6, 4.8), leaf(rng))
	part(parent, "TopiaryBall", jf * CFrame.new(0, y + 2.1, 0), Vector3.new(2.2, 1.2, 2.2), leaf(rng))
	if lit then
		part(parent, "LanternArm", jf * CFrame.new(0, H - 0.6, -3.1), Vector3.new(0.35, 0.35, 1.6), VoxelKit.C.iron)
		VoxelKit.lantern(parent, jf * CFrame.new(0, H - 0.75, -3.7), true, nil, true)
	end
end

-- A giant dandelion: a bent stem in three pieces, two leaves at the foot, a yellow head or a white puff ball.
local function dandelion(parent: Instance, base: CFrame, height: number, puff: boolean, rng: Random)
	local k = height / 10 -- the head's size follows the height
	local stem = C(92, 150, 64)
	local cf = base
	local seg = height / 3
	for _ = 1, 3 do
		cf = cf * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
		part(parent, "Stem", cf * CFrame.new(0, seg / 2, 0), Vector3.new(0.6 * k, seg + 0.1, 0.6 * k), jitter(rng, stem, 0.05))
		cf = cf * CFrame.new(0, seg, 0)
	end
	for i = 0, 1 do
		local a = i * math.pi + rng:NextNumber(-0.4, 0.4)
		part(parent, "DandelionLeaf", base * CFrame.Angles(0, a, 0) * CFrame.new(1.3 * k, 0.5 * k, 0) * CFrame.Angles(0, 0, math.rad(28)), Vector3.new(2.8, 0.3, 0.9) * k, jitter(rng, stem:Lerp(C(40, 90, 40), 0.3), 0.05))
	end
	local head = cf * CFrame.new(0, 0.8 * k, 0)
	if puff then
		-- a ball of white seed tufts round a small green centre
		part(parent, "PuffHeart", head, Vector3.one * 0.9 * k, C(150, 170, 110))
		local n = 18
		for i = 0, n - 1 do
			-- spread over a sphere (golden angle)
			local y = 1 - (i + 0.5) / n * 2
			local rr = math.sqrt(1 - y * y)
			local th = i * 2.39996
			local dir = Vector3.new(math.cos(th) * rr, y, math.sin(th) * rr)
			local tuft = part(parent, "PuffSeed", CFrame.lookAt(head.Position + dir * 1.7 * k, head.Position + dir * 3 * k), Vector3.one * 0.78 * k, jitter(rng, C(250, 250, 246), 0.02), Enum.Material.SmoothPlastic)
			tuft.Transparency = 0.08
		end
	else
		part(parent, "DandelionBase", head * CFrame.new(0, -0.45 * k, 0), Vector3.new(1.3, 0.5, 1.3) * k, C(80, 140, 58))
		local ring = { { 1.1, 0.0, 10 }, { 0.75, 0.35, 8 }, { 0.35, 0.6, 5 } }
		for _, rgt in ring do
			for i = 0, rgt[3] - 1 do
				local a = i / rgt[3] * 2 * math.pi + rgt[1]
				part(parent, "DandelionPetal", head * CFrame.Angles(0, a, 0) * CFrame.new(rgt[1] * k, rgt[2] * k, 0) * CFrame.Angles(0, 0, math.rad(-20)), Vector3.new(0.7, 0.3, 0.42) * k, jitter(rng, C(255, 206, 40), 0.05))
			end
		end
		part(parent, "DandelionTop", head * CFrame.new(0, 0.75 * k, 0), Vector3.new(0.6, 0.3, 0.6) * k, C(255, 222, 70))
	end
end

-- A sunflower: stem, two leaves, a brown disc with a ring of yellow petals, facing `cf`'s -Z.
local function sunflower(parent: Instance, base: CFrame, height: number, rng: Random)
	local k = height / 6
	part(parent, "Stem", base * CFrame.new(0, height / 2, 0), Vector3.new(0.5 * k, height, 0.5 * k), C(86, 140, 58))
	for _, s in { -1, 1 } do
		part(parent, "SunLeaf", base * CFrame.new(s * 0.8 * k, height * 0.45, 0) * CFrame.Angles(0, 0, math.rad(s * -25)), Vector3.new(1.4, 0.25, 0.9) * k, C(76, 132, 52))
	end
	local head = base * CFrame.new(0, height + 0.2 * k, 0) * CFrame.Angles(math.rad(-15), 0, 0)
	part(parent, "SunDisc", head, Vector3.new(1.5, 1.5, 0.4) * k, C(110, 70, 36))
	for i = 0, 11 do
		local a = i / 12 * 2 * math.pi
		part(parent, "SunPetal", head * CFrame.Angles(0, 0, a) * CFrame.new(1.15 * k, 0, 0.05), Vector3.new(0.8, 0.45, 0.25) * k, jitter(rng, C(255, 196, 40), 0.05))
	end
end

-------------------------------------------------------------------------------------------------------------
-- the floor: mown stripes and a stepping-stone path
-------------------------------------------------------------------------------------------------------------
local function lawn(ctx, parent: Instance, floor: Color3, rng: Random)
	local c, r, f = ctx.centre, ctx.r - 3.5, ctx.facing
	local across = f:Cross(Vector3.yAxis)
	local w = 6
	local light = floor:Lerp(Color3.new(1, 1, 1), 0.09)
	local i = 0
	for d = -r + w / 2, r - w / 2, w do
		i += 1
		if i % 2 == 0 then
			local half = math.sqrt(math.max(0, r * r - d * d)) - 0.5
			if half > 1 then
				local pos = c + f * d + Vector3.new(0, 0.09, 0)
				part(parent, "MowStripe", CFrame.fromMatrix(pos, across, Vector3.yAxis), Vector3.new(half * 2, 0.04, w), light, Enum.Material.Grass)
			end
		end
	end
	-- stepping stones from the arbour to the summon pad's ring
	local from, to = ctx.r - 2, ctx.r * 0.42 + 10
	local n = math.floor((from - to) / 2.6)
	for k = 0, n do
		local d = from - k * (from - to) / n
		local side = (k % 2 == 0) and 0.6 or -0.6
		local pos = c + f * d + across * side + Vector3.new(0, 0.12, 0)
		part(parent, "SteppingStone", CFrame.lookAt(pos, pos + f) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Vector3.new(rng:NextNumber(2.0, 2.6), 0.2, rng:NextNumber(1.6, 2.0)), jitter(rng, STONE, 0.06), "stone")
	end
	-- clover and little flowers scattered on the lawn
	for _ = 1, 40 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local rr = math.sqrt(rng:NextNumber()) * (ctx.r - 8)
		local pos = c + Vector3.new(math.sin(a) * rr, 0.15, math.cos(a) * rr)
		if (pos - (c + f * ctx.r * 0.42)).Magnitude > 11 then
			part(parent, "LawnFlower", CFrame.new(pos), Vector3.new(0.35, 0.18, 0.35), FLOWERS[rng:NextInteger(1, #FLOWERS)])
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the parts ArenaDress calls
-------------------------------------------------------------------------------------------------------------
function MeadowArena.wall(ctx, folder: Instance)
	local rng = Random.new(1201)
	for j = 1, ctx.segs - 2 do
		local f, L = sectionFrame(ctx, j)
		hedgeSection(folder, f, L, rng)
	end
	for j = 2, ctx.segs - 2 do
		topiary(folder, rimFrame(ctx, jointAngle(ctx, j), ctx.r), rng, j % 4 == 0)
	end
	-- giant dandelions and flower beds round the inside (none within 45 degrees of the way in)
	local spots = 16
	for s = 0, spots - 1 do
		local u = (s + 0.5) / spots
		if math.min(u, 1 - u) * 360 < 45 then
			continue
		end
		local a = ctx.yaw0 + u * 2 * math.pi
		local base = CFrame.lookAt(rimPoint(ctx, a, ctx.r - 9), ctx.centre)
		if s % 3 == 1 then
			VoxelKit.planter(folder, base, 7, FLOWERS, rng)
			VoxelKit.bush(folder, base * CFrame.new(4.6, 0, 0.8), HEDGE[2], rng, FLOWERS)
			VoxelKit.bush(folder, base * CFrame.new(-4.6, 0, 0.8), HEDGE[3], rng, FLOWERS)
		else
			-- a clump of giant dandelions: a tall one, a smaller one, a little one
			dandelion(folder, base, rng:NextNumber(16, 21), s % 3 == 2, rng)
			dandelion(folder, base * CFrame.new(rng:NextNumber(3.5, 4.5), 0, 1.5), rng:NextNumber(10, 13), s % 3 ~= 2, rng)
			dandelion(folder, base * CFrame.new(rng:NextNumber(-4, -3), 0, 2), rng:NextNumber(6, 8), true, rng)
		end
	end
	lawn(ctx, folder, ctx.look.floor, rng)
end

-- The rose arbour over the way in: two pairs of thick timber posts just outside the gap (the gate bars slide up
-- between them), double beams across the top with rafters sticking out, climbing roses up the posts and a mass of
-- leaves and roses over the top, lanterns hanging under it.
local AH = 16 -- the beams' underside
function MeadowArena.gate(ctx): Model
	local m = Instance.new("Model")
	m.Name = "ArenaGate"
	local rng = Random.new(1301)
	local ends = {}
	local rose = function(): Color3
		return if rng:NextNumber() < 0.55 then C(232, 80, 100) else C(255, 236, 240)
	end
	for _, j in { 1, ctx.segs - 1 } do
		local jf = rimFrame(ctx, jointAngle(ctx, j), ctx.r)
		local tf = jf * CFrame.new(if j == 1 then 1.6 else -1.6, 0, 0)
		table.insert(ends, tf)
		part(m, "ArbourBase", tf * CFrame.new(0, 0.5, 0), Vector3.new(3.4, 1.0, 6.6), jitter(rng, STONE, 0.04), "stone")
		for _, z in { -2.4, 2.4 } do
			part(m, "ArbourPost", tf * CFrame.new(0, 1.0 + (AH - 1.0) / 2, z), Vector3.new(1.6, AH - 1.0, 1.6), TIMBER)
			part(m, "PostCap", tf * CFrame.new(0, 1.2, z), Vector3.new(2.0, 0.4, 2.0), TIMBER_DARK)
			-- roses climbing the post
			for k = 1, 8 do
				local y = 1 + k * 1.8 + rng:NextNumber(-0.3, 0.3)
				part(m, "Vine", tf * CFrame.new(rng:NextNumber(-0.8, 0.8), y, z + rng:NextNumber(-0.9, 0.9)), Vector3.one * rng:NextNumber(1.1, 1.6), leaf(rng))
				if k % 2 == 0 then
					part(m, "Rose", tf * CFrame.new(rng:NextNumber(-1, 1), y + 0.5, z + rng:NextNumber(-1, 1)), Vector3.one * 0.7, rose())
				end
			end
		end
		-- a white lattice panel between the two posts
		for k = 0, 6 do
			part(m, "Lattice", tf * CFrame.new(0, 2 + k * 2, 0), Vector3.new(0.3, 0.3, 4.8), C(240, 236, 226))
		end
		for _, z in { -1.2, 0, 1.2 } do
			part(m, "Lattice", tf * CFrame.new(0, 8, z), Vector3.new(0.3, 13.6, 0.3), C(240, 236, 226))
		end
	end
	local a, b = ends[1].Position, ends[2].Position
	local x = (b - a).Unit
	local lf = CFrame.fromMatrix((a + b) / 2, x, Vector3.yAxis, x:Cross(Vector3.yAxis))
	local span = (b - a).Magnitude
	-- (the beams' undersides at 16: the gate bars, 11 tall, slide up under them)
	for _, z in { -2.4, 2.4 } do
		part(m, "ArbourBeam", lf * CFrame.new(0, AH + 0.7, z), Vector3.new(span + 5, 1.4, 1.0), TIMBER)
		for _, sx in { -1, 1 } do
			part(m, "BeamEnd", lf * CFrame.new(sx * (span / 2 + 2.6), AH + 0.5, z), Vector3.new(0.8, 1.0, 1.0), TIMBER_DARK)
		end
	end
	local n = math.floor((span + 4) / 1.6)
	for k = 0, n do
		local xx = -(span + 4) / 2 + k * (span + 4) / n
		part(m, "Rafter", lf * CFrame.new(xx, AH + 1.75, 0), Vector3.new(0.6, 0.7, 7.4), TIMBER_DARK)
	end
	-- leaves and roses over the top, hanging down a little on both faces
	for _ = 1, 44 do
		local sz = rng:NextNumber(1.4, 2.4)
		part(m, "Vine", lf * CFrame.new(rng:NextNumber(-span / 2 - 2, span / 2 + 2), AH + 2.3 + rng:NextNumber(0, 1.0), rng:NextNumber(-3, 3)), Vector3.one * sz, leaf(rng))
	end
	for _ = 1, 18 do
		local z = if rng:NextNumber() < 0.5 then -3.4 else 3.4
		local len = rng:NextNumber(1.2, 2.8)
		part(m, "HangingVine", lf * CFrame.new(rng:NextNumber(-span / 2, span / 2), AH + 0.3 - len / 2, z), Vector3.new(0.9, len, 0.9), leaf(rng))
	end
	for _ = 1, 28 do
		part(m, "Rose", lf * CFrame.new(rng:NextNumber(-span / 2 - 2, span / 2 + 2), AH + 3.3 + rng:NextNumber(0, 0.4), rng:NextNumber(-3, 3)), Vector3.one * 0.8, rose())
	end
	-- lanterns hanging under the beams
	for _, z in { -2.4, 2.4 } do
		for _, xx in { -span / 4, span / 4 } do
			VoxelKit.lantern(m, lf * CFrame.new(xx, AH, z), z > 0, nil, true)
		end
	end
	m.Parent = ctx.model
	return m
end

-- Round the summon pad: a ring of flat stepping stones and four sunflowers facing it.
function MeadowArena.altar(ctx, padPos: Vector3)
	local m = Instance.new("Model")
	m.Name = "SummonAltar"
	local rng = Random.new(1401)
	local n = 16
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		local pos = padPos + Vector3.new(math.sin(a), 0, math.cos(a)) * 7.9 + Vector3.new(0, 0.12, 0)
		part(m, "AltarStone", CFrame.lookAt(pos, Vector3.new(padPos.X, pos.Y, padPos.Z)), Vector3.new(2.7, 0.24, 1.7), jitter(rng, STONE, 0.06), "stone")
	end
	-- sunflowers in an arc behind the pad (away from the arbour), so the view from the gate to the pad stays open
	local toGate = (ctx.centre + ctx.facing * ctx.r - padPos) * Vector3.new(1, 0, 1)
	local back = if toGate.Magnitude > 0.1 then -toGate.Unit else Vector3.zAxis
	for _, deg in { -72, -26, 26, 72 } do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(back)
		local pos = padPos + dir * 13
		sunflower(m, CFrame.lookAt(pos, Vector3.new(padPos.X, pos.Y, padPos.Z)), rng:NextNumber(8, 10), rng)
	end
	m.Parent = ctx.model
end

return MeadowArena
