--!strict
-- STUD EMBER (7 Nov 2026; owner on the chalet: "Top, doe de volgende", after "Meer details en mooier"). The ember
-- isle's forge (forge_lm_ember) rebuilt from studded bricks, measured off square-on pictures of the mesh (front,
-- sides, top; a stud = 26.4 pixels):
--   a volcano of rounded dark boulders in tiers (wider across than deep, its top leaning to the front and right), lava
--   glowing in the seams down its face and side, a blocky crater rim round a lava pool, a puffy smoke cloud drifting
--   off to the right, live smoke and sparks
--   the forge built into its front: an arched furnace mouth (an iron frame with rivets, stone voussoirs round a ring
--   of fire-lit bricks, a red-hot line along the top, layered flame tongues on the hearth), rounded stone steps up to
--   it, a steel shield with a horned crest, a knight's helm and a gold anvil emblem over the arch
--   a great cleaver clamped in an iron bracket on a wooden beam, its grip standing up out of the bracket, steel down
--   the spine and red-hot down the edge with a zigzag crack between; chains (one hanging with a hook in front of the
--   fire, one slung from the anvil to an iron-capped post); a horned anvil on a stone plinth; teardrop bellows (leather
--   between wooden boards) with an iron nozzle; a glowing window in a wooden frame on the +X side
-- Model space as the mesh's: front to -Z, the pivot at the bottom middle. StudEmber.build(K) fills a StudKit.
local StudKit = require(script.Parent.StudKit)

type Kit = StudKit.Kit
local C = Color3.fromRGB
local V = Vector3.new
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local StudEmber = {}

-- (warm, near-black rock and warm dark iron: the mesh's metal catches the lava's light, the sky turns grey blue)
local ROCK = { C(42, 34, 40), C(35, 28, 34), C(48, 39, 46) }
local STONE = { C(76, 66, 66), C(64, 55, 56), C(86, 75, 75) }
local IRON = { C(72, 64, 66), C(58, 51, 54) }
local STEEL = { C(124, 116, 114), C(104, 96, 96) }
local RIVET = C(150, 142, 138)
local WOOD = { C(112, 64, 36), C(92, 52, 30) }
local LEATHER = { C(142, 64, 48), C(112, 50, 38) }
local GOLD = C(206, 152, 62)
local LAVA = C(255, 96, 24)
local LAVA_HOT = C(255, 176, 64)
local LAVA_DEEP = C(196, 46, 14)
local EMBER = C(150, 36, 12) -- the dark red round the glow
local SOOT = C(26, 22, 26)
local SMOKE = { C(218, 216, 218), C(200, 198, 202) }

-------------------------------------------------------------------------------------------------------------
-- the volcano's shape: at each height its half-widths across (rx) and deep (rz) and the middle's X; its middle's Z
-------------------------------------------------------------------------------------------------------------
local PROF = { { 0, 11.9, 10.8, -1.2 }, { 4, 10.75, 9.45, -1.3 }, { 8, 8.85, 8.0, -1.65 }, { 12, 7.0, 6.45, -1.4 }, { 16, 5.0, 5.0, -1.2 }, { 18, 4.15, 4.2, -1.3 }, { 20, 3.3, 3.4, -1.4 }, { 20.6, 3.1, 3.2, -1.4 } }
local CZ = 1.1

local function prof(y: number): (number, number, number)
	for i = 1, #PROF - 1 do
		local a, b = PROF[i], PROF[i + 1]
		if y <= b[1] or i == #PROF - 1 then
			local f = math.clamp((y - a[1]) / (b[1] - a[1]), 0, 1)
			return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f
		end
	end
	return PROF[1][2], PROF[1][3], PROF[1][4]
end

-- the surface at angle `t` (front is -pi/2) and height y, and its outward normal (tilted up with the slope)
local function surface(t: number, y: number): (Vector3, Vector3)
	local rx, rz, cx = prof(y)
	local p = V(cx + rx * math.cos(t), y, CZ + rz * math.sin(t))
	local rx2, rz2 = prof(y + 1)
	local slope = ((rx - rx2) + (rz - rz2)) / 2
	local n = V(math.cos(t) / rx, 0, math.sin(t) / rz).Unit
	return p, (n + Y * slope * 0.6).Unit
end

-- the angle on the front half for a given X at height y (for lava drawn as seen from the front)
local function frontAngle(x: number, y: number): number
	local rx, _, cx = prof(y)
	return -math.acos(math.clamp((x - cx) / rx, -0.999, 0.999))
end

-- the angle on the +X side for a given Z at height y
local function sideAngle(z: number, y: number): number
	local _, rz, _ = prof(y)
	return math.asin(math.clamp((z - CZ) / rz, -0.999, 0.999))
end

-- a smooth rounded lump: a sphere mesh stretched to `size`
local function blob(K: Kit, name: string, size: Vector3, cf: CFrame, col: Color3): Part
	local p = K:brick(name, size, cf, col, true)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- an upright elliptic disc (a cylinder mesh stretched): rx across, rz deep, h tall, `at` its middle
local function oval(K: Kit, name: string, at: Vector3, rx: number, rz: number, h: number, col: Color3): Part
	local p = K:brick(name, V(h, rx * 2, rz * 2), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), col, true)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Cylinder
	m.Parent = p
	return p
end

local function neon(p: BasePart, col: Color3)
	p.Material = Enum.Material.Neon
	p.Color = col
end

-- every part called `name` made to glow in `col` (for shapes built from triangles, which return nothing)
local function neonAll(K: Kit, name: string, col: Color3)
	for _, c in K.model:GetChildren() do
		if c:IsA("BasePart") and c.Name == name then
			neon(c, col)
		end
	end
end

-- a glowing seam from a to b: a thin hot core in a wider dark red crack
local function lavaLine(K: Kit, a: Vector3, b: Vector3, w: number, out: Vector3)
	neon(K:beam("Lava", a, b, w, 0.25, LAVA, out, true), LAVA)
	K:beam("LavaGlow", a - out * 0.12, b - out * 0.12, w * 2.6, 0.2, EMBER, out, true)
end

local function light(K: Kit, at: Vector3, col: Color3, range: number, brightness: number)
	local p = K:brick("Light", V(0.3, 0.3, 0.3), CFrame.new(at), col, true)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	local l = Instance.new("PointLight")
	l.Color = col
	l.Range = range
	l.Brightness = brightness
	l.Parent = p
	return p
end

-------------------------------------------------------------------------------------------------------------
-- lava: seams down the front and the +X side; boulders keep out of them
-------------------------------------------------------------------------------------------------------------
local FRONT_SEAMS = {
	{ { 0.4, 20.3 }, { 1.1, 18.6 }, { 1.5, 17.2 }, { 2.6, 15.6 }, { 3.6, 14.0 }, { 4.4, 12.6 }, { 5.0, 11.0 }, { 5.0, 9.2 }, { 4.6, 7.6 } },
	{ { -2.9, 20.3 }, { -3.4, 18.6 }, { -4.3, 17.0 }, { -4.9, 15.2 }, { -5.2, 13.6 }, { -5.6, 12.2 }, { -6.4, 10.0 }, { -7.0, 7.5 }, { -7.8, 4.5 }, { -8.6, 1.4 } },
	{ { 1.5, 17.2 }, { 2.1, 14.9 }, { 2.9, 13.3 }, { 3.5, 11.9 } },
}
local SIDE_SEAMS = {
	{ { -0.6, 20.2 }, { -0.9, 18.0 }, { -1.2, 16.6 }, { -2.2, 15.6 } },
	{ { -0.9, 18.0 }, { 0.6, 17.6 }, { 2.0, 17.0 } },
}

-- every seam as a list of points on the surface with their normals
local function seamPoints(): { { Vector3 } }
	local lines = {}
	for _, s in FRONT_SEAMS do
		local pts = {}
		for _, q in s do
			local p, n = surface(frontAngle(q[1], q[2]), q[2])
			table.insert(pts, { p, n })
		end
		table.insert(lines, pts)
	end
	for _, s in SIDE_SEAMS do
		local pts = {}
		for _, q in s do
			local p, n = surface(sideAngle(q[1], q[2]), q[2])
			table.insert(pts, { p, n })
		end
		table.insert(lines, pts)
	end
	return lines :: any
end

local function distToSeams(lines: { any }, p: Vector3): number
	local best = math.huge
	for _, pts in lines do
		for i = 1, #pts - 1 do
			local a, b = pts[i][1], pts[i + 1][1]
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			best = math.min(best, (a + ab * t - p).Magnitude)
		end
	end
	return best
end

-------------------------------------------------------------------------------------------------------------
-- the volcano
-------------------------------------------------------------------------------------------------------------
local AX, AY = -0.4, 7.2 -- the furnace arch's middle
local FZ = -8.6 -- the forge's front face
local WIN = V(5.4, 13.2, 0.2) -- the side window

local function inForge(p: Vector3): boolean
	return p.Y < 11.6 and p.X > -5.8 and p.X < 4.9 and p.Z < -2
end

local function volcano(K: Kit, lines: { any })
	-- the core: elliptic discs stacked up the middle
	for y = 0.6, 19.8, 1.6 do
		local rx, rz, cx = prof(y)
		-- (kept well inside, so it never fills the furnace mouth)
		oval(K, "Core", V(cx, y, CZ), rx - 2.4, rz - 2.4, 1.7, ROCK[2])
	end
	-- boulders in staggered tiers
	for k = 0, 8 do
		local y = 1.1 + k * 2.3
		local rx, rz = prof(y)
		local per = 2 * math.pi * math.sqrt((rx * rx + rz * rz) / 2)
		local n = math.max(6, math.round(per / 3.3))
		for i = 0, n - 1 do
			local t = i / n * math.pi * 2 + k * 0.37
			local p, nrm = surface(t, y)
			local pos = p - nrm * 0.7
			local d = distToSeams(lines, pos)
			if not inForge(pos) and d > 0.9 and (pos - WIN).Magnitude > 2.7 then
				local s = if d < 1.7 then 0.62 else 1
				local var = ((i * 7 + k * 3) % 3) * 0.3
				-- (flat-faced studded slabs, a little askew: the mesh's rock is chunky cut stone, not round)
				local tw = (((i * 5 + k * 7) % 5) - 2) * 0.05
				K:brick("Boulder", V(3.7 + var, 2.4 + var * 0.4, 1.5) * s, CFrame.lookAt(pos, pos + nrm) * CFrame.Angles(tw, tw * 0.6, tw * 1.4), ROCK[(i + k) % 3 + 1])
			end
		end
	end
	-- the seams themselves
	for _, pts in lines do
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			lavaLine(K, a[1] - a[2] * 0.05, b[1] - b[2] * 0.05, 0.24, (a[2] + b[2]).Unit)
		end
	end
	-- a pool of lava at its foot, on the right, where the long seam runs out
	neon(oval(K, "LavaPool", V(-9.0, 0.2, -6.4), 1.8, 1.2, 0.3, LAVA), LAVA)
	light(K, V(-8.8, 1.2, -7.2), LAVA, 7, 0.6)
end

local function crater(K: Kit)
	local c = V(-1.4, 0, 0.3)
	K:ring("CraterRim", c, 9, 3.6, 19.3, 1.5, 1.2, { ROCK[1], ROCK[3], ROCK[2] })
	for i = 0, 8 do
		local a = (i + 0.5) / 9 * math.pi * 2
		local p = c + V(math.cos(a) * 3.0, 20.8 + (i % 3) * 0.15, math.sin(a) * 3.0)
		K:brick("RimStone", V(1.6, 0.5 + (i % 2) * 0.3, 1.0), CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, 0), ROCK[(i + 1) % 3 + 1])
	end
	neon(oval(K, "CraterLava", c + V(0, 20.2, 0), 2.6, 2.6, 0.3, LAVA_DEEP), LAVA_DEEP)
	neon(oval(K, "CraterLava", c + V(0, 20.25, 0), 1.4, 1.4, 0.3, LAVA), LAVA)
	local glow = light(K, c + V(0, 20.6, 0), LAVA, 8, 0.9)
	-- sparks leaping out
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(LAVA_HOT, LAVA)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.35, 0.1)
	sparks.Lifetime = NumberRange.new(1.4, 2.4)
	sparks.Rate = 6
	sparks.Speed = NumberRange.new(4, 7)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, -4, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = glow
	-- live smoke under the sculpted cloud
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(C(200, 196, 204), C(150, 146, 156))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Lifetime = NumberRange.new(5, 7)
	smoke.Rate = 2
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Acceleration = Vector3.new(-0.6, 0.2, 0.2)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-15, 15)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = glow
	-- the sculpted cloud: a column out of the crater that billows and trails off to the right (-X), warm at its foot
	-- (overlapping puffs so it reads as one cloud, not a bunch of balls)
	local puffs = {
		{ -1.2, 21.9, 0.2, 1.8, 2.0 }, { -1.1, 23.2, 0.3, 2.8, 2.6 }, { -2.1, 24.3, 0.4, 3.6, 2.8 },
		{ -3.9, 25.1, 0.6, 3.8, 2.5 }, { -5.9, 25.4, 0.8, 3.0, 2.1 }, { -2.8, 25.6, -0.2, 2.8, 1.9 },
		{ -3.0, 24.5, 1.0, 4.2, 2.6 }, { -4.9, 24.7, 0.3, 3.6, 2.2 }, { -1.6, 25.2, 0.9, 2.6, 2.0 },
	}
	for i, b in puffs do
		local col = if i == 1 then C(214, 182, 170) elseif i == 2 then C(216, 206, 206) else SMOKE[i % 2 + 1]
		local puff = blob(K, "SmokeCloud", V(b[4], b[5], b[4] * 0.9), CFrame.new(b[1], b[2], b[3]), col)
		puff.Color = col
		puff.Material = Enum.Material.SmoothPlastic
	end
end

-------------------------------------------------------------------------------------------------------------
-- the forge front: the furnace mouth
-------------------------------------------------------------------------------------------------------------
-- an arc of pieces round the arch's middle from radius r0 to r1, front at z0 and `depth` deep
local function arc(K: Kit, name: string, r0: number, r1: number, z0: number, depth: number, segs: number, cols: { Color3 }, smooth: boolean?): { BasePart }
	local out = {}
	local rm, th = (r0 + r1) / 2, r1 - r0
	for i = 0, segs - 1 do
		local a = (i + 0.5) / segs * math.pi
		local w = 2 * rm * math.tan(math.pi / segs / 2) + 0.05
		local cf = CFrame.new(AX + math.cos(a) * rm, AY + math.sin(a) * rm, z0 + depth / 2) * CFrame.Angles(0, 0, a - math.pi / 2)
		table.insert(out, K:brick(name, V(w, th, depth), cf, cols[i % #cols + 1], smooth))
	end
	return out
end

local function furnace(K: Kit)
	local OPEN, BRICK, FRAME = 2.45, 3.7, 4.4
	-- the stone behind it all, out to the cone, and the hood over the arch
	K:box("ForgeStone", -5.0, 0.4, FZ + 2.0, 4.3, AY, -3.0, STONE[2])
	K:rod("ForgeHood", FRAME * 2 + 0.5, 3.6, CFrame.new(AX, AY, FZ + 3.8) * CFrame.Angles(0, math.pi / 2, 0), STONE[2])
	-- the jambs: a column of fire-lit bricks inside a column of stones, on a stone base; the hearth below the opening
	local INNER = OPEN + 0.5
	local LIT = { C(112, 64, 50), C(98, 54, 42) }
	for _, s in { -1, 1 } do
		local function xs(a: number, b: number): (number, number)
			return math.min(AX + s * a, AX + s * b), math.max(AX + s * a, AX + s * b)
		end
		local a0, a1 = xs(OPEN, BRICK)
		K:box("Jamb", a0, 0.4, FZ, a1, 3.0, FZ + 2.0, STONE[2])
		for r = 0, 3 do
			local y0, y1 = 3.0 + r * 1.05, 3.0 + (r + 1) * 1.05 - 0.05
			local i0, i1 = xs(OPEN, INNER - 0.03)
			K:box("ArchBrick", i0, y0, FZ + 0.1, i1, y1, FZ + 2.0, LIT[(r + 1) % 2 + 1], true)
			local o0, o1 = xs(INNER, BRICK)
			K:box("Jamb", o0, y0, FZ - (r % 2) * 0.08, o1, y1, FZ + 2.0, STONE[(r + (s + 1) / 2) % 3 + 1])
		end
	end
	K:box("Hearth", AX - OPEN, 0.4, FZ, AX + OPEN, 3.0, FZ + 2.0, STONE[2])
	K:box("HearthSill", AX - OPEN - 0.1, 2.75, FZ - 0.15, AX + OPEN + 0.1, 3.05, FZ + 1.0, STONE[3], true)
	-- the arch: fire-lit bricks inside a ring of stone voussoirs, the iron frame with its rivets, a red-hot line along
	-- the top of the opening and a dull glow round the frame
	arc(K, "ArchBrick", OPEN, INNER, FZ + 0.1, 1.9, 13, LIT, true)
	arc(K, "Voussoir", INNER + 0.03, BRICK, FZ, 2.0, 9, STONE)
	arc(K, "IronFrame", BRICK, FRAME, FZ - 0.3, 0.6, 12, { IRON[1] }, true)
	for _, a in arc(K, "LavaRim", OPEN - 0.06, OPEN + 0.04, FZ + 0.05, 0.3, 14, { LAVA_DEEP }, true) do
		neon(a, LAVA_DEEP)
	end
	arc(K, "LavaHalo", FRAME, FRAME + 0.18, FZ + 0.1, 0.3, 12, { EMBER }, true)
	for _, s in { -1, 1 } do
		local x0 = AX + s * BRICK
		local x1 = AX + s * FRAME
		K:box("IronFrame", math.min(x0, x1), 2.4, FZ - 0.3, math.max(x0, x1), AY, FZ + 0.3, IRON[1], true)
		K:box("LavaHalo", math.min(x1, x1 + s * 0.18), 2.4, FZ + 0.1, math.max(x1, x1 + s * 0.18), AY, FZ + 0.4, EMBER, true)
		for _, y in { 3.2, 5.6 } do
			K:ball("Rivet", 0.28, V(AX + s * 4.05, y, FZ - 0.32), RIVET)
		end
		K:box("IronFoot", AX + s * 4.05 - 0.55, 1.8, FZ - 0.4, AX + s * 4.05 + 0.55, 2.4, FZ + 0.3, IRON[2], true)
	end
	for i = 0, 6 do
		local a = (i + 0.5) / 7 * math.pi
		K:ball("Rivet", 0.28, V(AX + math.cos(a) * 4.05, AY + math.sin(a) * 4.05, FZ - 0.32), RIVET)
	end
	-- inside: a back glowing hot low down and dull red up in the vault, embers, logs, layered flame tongues
	local back = FZ + 1.95
	neon(K:box("FireBack", AX - OPEN, 3.0, back - 0.1, AX + OPEN, 5.8, back, C(200, 64, 18), true), C(200, 64, 18))
	K:box("FireVault", AX - OPEN, 5.8, back - 0.1, AX + OPEN, AY, back, C(96, 28, 14), true)
	K:rod("FireVault", OPEN * 2, 0.1, CFrame.new(AX, AY, back - 0.05) * CFrame.Angles(0, math.pi / 2, 0), C(96, 28, 14))
	neon(K:box("Embers", AX - OPEN, 3.0, FZ + 0.6, AX + OPEN, 3.35, back - 0.1, LAVA_DEEP, true), LAVA_DEEP)
	for _, l in { { -0.15, 0.3 }, { 0.2, -0.25 } } do
		K:rod("Log", 0.5, 3.6, CFrame.new(AX + l[1], 3.3, FZ + 1.0 + l[2]) * CFrame.Angles(0, l[2], 0), C(46, 30, 24))
	end
	-- the flames, back to front: wide deep red tongues, orange ones, yellow ones, a pale core
	local layers = {
		{ "FlameBack", LAVA_DEEP, FZ + 1.6, { { -1.7, 1.4, 2.6, -0.3 }, { -0.6, 1.4, 3.4, 0.2 }, { 0.5, 1.4, 3.2, -0.2 }, { 1.6, 1.3, 2.4, 0.3 } } },
		{ "FlameMid", LAVA, FZ + 1.25, { { -1.2, 1.2, 2.4, 0.25 }, { -0.1, 1.25, 3.0, -0.2 }, { 1.0, 1.2, 2.3, 0.2 } } },
		{ "FlameFront", LAVA_HOT, FZ + 0.9, { { -0.6, 0.95, 1.9, -0.15 }, { 0.45, 0.9, 1.6, 0.2 } } },
		{ "FlameCore", C(255, 228, 150), FZ + 0.75, { { -0.1, 0.6, 1.2, 0.05 } } },
	}
	for _, l in layers do
		for _, f in l[4] do
			local x, w, h, lean, y0 = AX + f[1], f[2], f[3], f[4], 3.35
			local pts = { V(x - w / 2, y0, l[3]), V(x + w / 2, y0, l[3]), V(x + w * 0.34 + lean * 0.4, y0 + h * 0.5, l[3]), V(x + lean, y0 + h, l[3]), V(x - w * 0.36 + lean * 0.45, y0 + h * 0.56, l[3]) }
			for i = 2, #pts - 1 do
				K:tri(l[1], pts[1], pts[i], pts[i + 1], l[2], V(x, y0 + 1, l[3] + 1), 0.12)
			end
		end
		neonAll(K, l[1], l[2])
	end
	local fire = light(K, V(AX, 4.2, FZ + 1.0), LAVA, 11, 1.1)
	local f = Instance.new("ParticleEmitter")
	f.Name = "Fire"
	f.Texture = "rbxasset://textures/particles/fire_main.dds"
	f.Color = ColorSequence.new(LAVA_HOT, LAVA_DEEP)
	f.LightEmission = 1
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0.2) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	f.Lifetime = NumberRange.new(0.6, 1.0)
	f.Rate = 14
	f.Speed = NumberRange.new(1, 2)
	f.SpreadAngle = Vector2.new(15, 15)
	f.EmissionDirection = Enum.NormalId.Top
	f.Parent = fire
	-- the steps up to it, as wide as the opening, their front edges rounded
	for k, s in { { 0.4, 1.0, -11.6 }, { 1.0, 1.65, -10.8 }, { 1.65, 2.3, -10.0 } } do
		K:box("Step", -2.9, s[1], s[3], 2.15, s[2], FZ, STONE[k % 3 + 1])
		K:rod("StepNose", s[2] - s[1], 5.05, CFrame.new(-0.375, (s[1] + s[2]) / 2, s[3]), STONE[k % 3 + 1])
	end
end

-------------------------------------------------------------------------------------------------------------
-- the shield over the arch
-------------------------------------------------------------------------------------------------------------
local function shield(K: Kit)
	local tilt = math.rad(24)
	local SF = CFrame.new(-0.75, 13.4, -7.7) * CFrame.Angles(tilt, 0, 0)
	local function p(u: number, v: number, w: number?): Vector3
		return (SF * CFrame.new(u, v, w or 0)).Position
	end
	local inside = (SF * CFrame.new(0, 0, 1)).Position
	local function plate(name: string, pts: { { number } }, col: Color3, w: number, t: number)
		local a = p(pts[1][1], pts[1][2], w)
		for i = 2, #pts - 1 do
			K:tri(name, a, p(pts[i][1], pts[i][2], w), p(pts[i + 1][1], pts[i + 1][2], w), col, inside, t)
		end
	end
	-- the body: a pointed steel plate with a darker rim
	plate("ShieldBody", { { -1.95, 0.1 }, { 1.95, 0.1 }, { 1.3, -2.0 }, { 0, -3.45 }, { -1.3, -2.0 } }, STEEL[1], 0, 0.35)
	local rim = { { -1.95, 0.1 }, { 1.95, 0.1 }, { 1.3, -2.0 }, { 0, -3.45 }, { -1.3, -2.0 }, { -1.95, 0.1 } }
	for i = 1, #rim - 1 do
		K:beam("ShieldRim", p(rim[i][1], rim[i][2], -0.2), p(rim[i + 1][1], rim[i + 1][2], -0.2), 0.3, 0.2, IRON[2], (SF.LookVector * -1), true)
	end
	-- the horned crest across its top, a spike up the middle
	K:brick("Crest", V(4.0, 1.7, 0.5), SF * CFrame.new(0, 0.45, -0.1), IRON[1], true)
	for _, s in { -1, 1 } do
		plate("Horn", { { s * 1.95, 1.3 }, { s * 1.95, -0.35 }, { s * 2.85, 0.9 } }, IRON[1], -0.05, 0.4)
	end
	-- a knight's helm above it: a steel shell with its top corners cut off round a dark arched window, the crest's
	-- spade-shaped nose guard rising into it
	K:brick("Helm", V(3.0, 2.3, 0.6), SF * CFrame.new(0, 2.45, 0.15), STEEL[1], true)
	K:brick("Helm", V(2.0, 0.6, 0.6), SF * CFrame.new(0, 3.9, 0.15), STEEL[1], true)
	for _, s in { -1, 1 } do
		plate("Helm", { { s * 1.5, 3.6 }, { s * 1.0, 3.6 }, { s * 1.0, 4.2 } }, STEEL[1], -0.15, 0.6)
	end
	K:brick("HelmWindow", V(1.9, 0.7, 0.2), SF * CFrame.new(0, 2.3, -0.1), SOOT, true)
	K:rod("HelmWindow", 1.9, 0.2, SF * CFrame.new(0, 2.65, -0.1) * CFrame.Angles(0, math.pi / 2, 0), SOOT)
	plate("Spike", { { -0.5, 1.2 }, { 0.5, 1.2 }, { 0.4, 2.0 }, { 0, 2.75 }, { -0.4, 2.0 } }, STEEL[2], -0.4, 0.3)
	K:brick("HoodRim", V(3.1, 0.3, 0.7), SF * CFrame.new(0, 1.35, 0.05), IRON[2], true)
	-- the gold anvil emblem: a broad bar and a stem tapering to a point
	K:brick("Emblem", V(2.4, 1.05, 0.35), SF * CFrame.new(0, 0.55, -0.45), GOLD, true)
	plate("Emblem", { { -0.55, 0.05 }, { 0.55, 0.05 }, { 0, -2.4 } }, GOLD, -0.45, 0.3)
	K:brick("EmblemShade", V(2.4, 0.18, 0.36), SF * CFrame.new(0, 0.1, -0.45), C(150, 104, 40), true)
	-- rivets
	for _, r in { { -1.65, 0.0 }, { 1.65, 0.0 }, { -1.2, 1.75 }, { 1.2, 1.75 }, { -1.2, 3.55 }, { 1.2, 3.55 }, { 0, -2.95 } } do
		K:ball("Rivet", 0.3, p(r[1], r[2], -0.35), RIVET)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the cleaver, its beam and bracket; chains; posts
-------------------------------------------------------------------------------------------------------------
-- a chain along a list of points: links in turn flat and edge-on
local function chain(K: Kit, pts: { Vector3 })
	local k = 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local n = math.max(1, math.round(len / 0.62))
		for j = 0, n - 1 do
			local m = a + dir * ((j + 0.5) * len / n)
			local size = if k % 2 == 0 then V(0.5, 0.18, 0.78) else V(0.18, 0.5, 0.78)
			-- (a hanging chain points straight down: look along it with Z as up)
			K:brick("ChainLink", size, CFrame.lookAt(m, m + dir, if math.abs(dir.Y) > 0.9 then Z else Y), C(90, 84, 86), true)
			k += 1
		end
	end
end

local function cleaver(K: Kit)
	-- the beam out from behind the shield, an iron cap and a hook on its far end, the chain's mount by the shield
	K:beam("Beam", V(-2.15, 12.65, -8.4), V(-8.6, 12.65, -8.4), 0.95, 0.9, WOOD[1], -Z)
	K:beam("BeamGrain", V(-3.4, 12.45, -8.87), V(-4.2, 12.45, -8.87), 0.1, 0.05, WOOD[2], -Z, true)
	K:beam("BeamGrain", V(-7.35, 12.85, -8.87), V(-8.05, 12.85, -8.87), 0.1, 0.05, WOOD[2], -Z, true)
	K:box("BeamCap", -9.0, 12.25, -8.95, -8.05, 13.3, -7.85, IRON[1], true)
	K:ball("Rivet", 0.3, V(-8.5, 12.75, -9.0), RIVET)
	for _, h in { { V(-8.75, 12.25, -8.4), V(-8.75, 11.6, -8.4) }, { V(-8.75, 11.6, -8.4), V(-8.35, 11.4, -8.4) }, { V(-8.35, 11.4, -8.4), V(-8.2, 11.75, -8.4) } } do
		K:beam("Hook", h[1], h[2], 0.2, 0.2, IRON[2], -Z, true)
	end
	K:box("ChainMount", -3.4, 12.1, -9.45, -2.35, 13.2, -7.8, IRON[1], true)
	K:ball("Rivet", 0.3, V(-2.9, 12.7, -9.5), RIVET)
	-- the iron bracket clamping the blade to it: banded, three rivets
	K:box("Bracket", -7.35, 11.8, -9.35, -4.2, 13.35, -7.8, IRON[1], true)
	for _, y in { 11.9, 13.1 } do
		K:box("BracketBand", -7.35, y, -9.42, -4.2, y + 0.15, -9.3, IRON[2], true)
	end
	K:ball("Rivet", 0.3, V(-4.6, 12.6, -9.4), RIVET)
	K:ball("Rivet", 0.45, V(-6.0, 12.6, -9.45), RIVET)
	K:ball("Rivet", 0.3, V(-7.0, 12.6, -9.4), RIVET)
	-- its grip standing up out of the bracket: wood with iron rings, an iron cap
	K:cyl("Grip", 0.85, 2.0, V(-5.75, 14.3, -8.6), WOOD[2])
	for _, y in { 13.6, 14.6 } do
		K:cyl("GripRing", 1.0, 0.22, V(-5.75, y, -8.6), IRON[2])
	end
	K:cyl("GripCap", 1.1, 0.4, V(-5.75, 15.45, -8.6), IRON[1])
	-- the blade: a straight spine near the arch, a convex edge out to the right curving in to the tip at the bottom.
	-- Steel down the spine side, red-hot lava down the edge side, a dark zigzag crack between them.
	local tilt = math.rad(6)
	local BF = CFrame.new(-6.0, 7.3, -9.9) * CFrame.Angles(tilt, 0, 0)
	local function q(x: number, y: number, w: number?): Vector3
		return (BF * CFrame.new(x + 6.0, (y - 7.3) / math.cos(tilt), w or 0)).Position
	end
	local inside = (BF * CFrame.new(0, 0, 1)).Position
	local out = BF.LookVector * -1
	local spine = { { -4.0, 11.9 }, { -4.05, 9.5 }, { -3.8, 7.0 }, { -3.45, 4.4 }, { -3.3, 2.0 } }
	local edge = { { -8.2, 12.0 }, { -8.75, 9.5 }, { -8.3, 7.0 }, { -6.9, 4.6 }, { -3.3, 2.0 } }
	local function at(poly: { { number } }, t: number): { number }
		local i = math.min(math.floor(t), #poly - 2)
		local f = t - i
		local a, b = poly[i + 1], poly[i + 2]
		return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f }
	end
	local function mix(a: { number }, b: { number }, f: number): { number }
		return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f }
	end
	local N = 9
	local rows = {}
	for j = 0, N - 1 do
		local t = j / (N - 1) * (#spine - 1)
		local s, e = at(spine, t), at(edge, t)
		local f = 0.62 - 0.22 * j / (N - 1) + (if j % 2 == 0 then -0.06 else 0.06)
		table.insert(rows, { s, mix(s, e, f), e })
	end
	local HOT = C(196, 66, 26) -- (lit orange, not neon: neon here drowns the blade in flat red)
	local function quad(name: string, a: { number }, b: { number }, c: { number }, d: { number }, col: Color3)
		K:tri(name, q(a[1], a[2]), q(b[1], b[2]), q(c[1], c[2]), col, inside, 0.3)
		K:tri(name, q(a[1], a[2]), q(c[1], c[2]), q(d[1], d[2]), col, inside, 0.3)
	end
	local function line(name: string, a: { number }, b: { number }, w: number, t: number, d: number, col: Color3): Part
		return K:beam(name, q(a[1], a[2], d), q(b[1], b[2], d), w, t, col, out, true)
	end
	for j = 1, N - 1 do
		local r0, r1 = rows[j], rows[j + 1]
		quad("Blade", r0[1], r1[1], r1[2], r0[2], C(84, 78, 80))
		quad("BladeHot", r0[2], r1[2], r1[3], r0[3], HOT)
		line("BladeCrack", r0[2], r1[2], 0.16, 0.12, -0.05, C(70, 22, 14))
		line("BladeSpine", r0[1], r1[1], 0.4, 0.36, -0.1, IRON[2])
		line("BladeBevel", mix(r0[1], r0[3], 0.12), mix(r1[1], r1[3], 0.12), 0.3, 0.06, -0.03, C(110, 104, 106))
		neon(line("BladeEdge", r0[3], r1[3], 0.3, 0.34, -0.05, LAVA), LAVA)
		if j > 1 and j < N - 1 then
			neon(line("BladeVein", mix(r0[2], r0[3], 0.5), mix(r1[2], r1[3], 0.5), 0.1, 0.06, -0.03, LAVA), LAVA)
		end
	end
	-- nicks and scratches in the steel
	for _, s in { { { -4.4, 10.8 }, { -4.9, 10.2 } }, { { -4.2, 8.3 }, { -4.8, 7.9 } }, { { -4.6, 6.4 }, { -5.0, 5.7 } } } do
		line("Scratch", s[1], s[2], 0.07, 0.04, -0.02, C(118, 112, 114))
	end
	-- the clamp plate where the blade meets the bracket
	K:brick("Clamp", V(1.3, 1.2, 0.3), CFrame.new(q(-5.9, 11.2, -0.2)) * BF.Rotation, IRON[1], true)
	K:ball("Rivet", 0.35, q(-5.9, 11.1, -0.4), RIVET)
	light(K, q(-7.0, 7.0, -0.8), LAVA, 5, 0.5)
end

local function chainsAndPosts(K: Kit)
	-- the right post (iron cap on wood) and the left one
	K:cyl("Post", 0.8, 3.8, V(-7.7, 2.2, -10.8), WOOD[1])
	K:box("PostCap", -8.55, 3.9, -11.2, -6.85, 5.7, -10.4, IRON[1], true)
	K:ball("Rivet", 0.4, V(-7.7, 4.8, -11.25), RIVET)
	K:cyl("Post", 0.8, 5.0, V(6.1, 5.4, -9.6), WOOD[1])
	K:box("PostCap", 5.3, 7.6, -10.0, 6.9, 9.6, -9.2, IRON[1], true)
	K:ball("Rivet", 0.4, V(6.1, 8.6, -10.05), RIVET)
	-- the chain hanging off the bracket in front of the fire, a hook on it
	chain(K, { V(-2.9, 12.1, -9.6), V(-2.9, 5.6, -9.6) })
	for _, h in { { V(-2.9, 5.6, -9.6), V(-2.9, 4.7, -9.6) }, { V(-2.9, 4.7, -9.6), V(-2.4, 4.45, -9.6) }, { V(-2.4, 4.45, -9.6), V(-2.2, 5.0, -9.6) } } do
		K:beam("Hook", h[1], h[2], 0.24, 0.24, IRON[1], -Z, true)
	end
	-- the chain slung from the anvil to the right post
	local pts = {}
	for i = 0, 14 do
		local f = i / 14
		local x = 2.7 + (-6.85 - 2.7) * f
		local y = 3.8 + (4.6 - 3.8) * f - 1.5 * (1 - (2 * f - 1) ^ 2)
		table.insert(pts, V(x, y, -10.95 + f * 0.1))
	end
	chain(K, pts)
end

-------------------------------------------------------------------------------------------------------------
-- the platforms, the anvil, the bellows, the side window
-------------------------------------------------------------------------------------------------------------
-- a block of studded stones in staggered rows, `x0..x1` across, `y0..y1` up, `z0..z1` deep
local function stones(K: Kit, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number)
	local rows = math.max(1, math.round((y1 - y0) / 0.85))
	local h = (y1 - y0) / rows
	for r = 0, rows - 1 do
		local x = x0 - (if r % 2 == 1 then 0.75 else 0)
		local k = 0
		while x < x1 - 0.05 do
			local w = 1.5 + ((r + k) % 3) * 0.2
			local a, b = math.max(x, x0), math.min(x + w, x1)
			if b - a > 0.2 then
				local top = y0 + (r + 1) * h - 0.03 + (if r == rows - 1 then (((r + k) * 3) % 3 - 1) * 0.15 else 0)
				K:box("Stone", a + 0.03, y0 + r * h, z0 - ((r + k) % 2) * 0.12, b - 0.03, top, z1, STONE[(r + k) % 3 + 1])
			end
			x += w
			k += 1
		end
	end
end

local function platforms(K: Kit)
	-- the anvil's plinth: two courses of stones under a capping slab
	stones(K, 2.2, 0.4, -11.4, 8.6, 2.15, FZ)
	K:box("PlinthCap", 2.0, 2.15, -11.55, 8.8, 2.45, FZ + 0.1, STONE[3])
	-- a low step out to the bellows
	stones(K, 8.6, 0.4, -10.2, 10.6, 1.2, -6.4)
	-- the block right of the steps, and the stones the right post stands in
	stones(K, -6.6, 0.4, -11.4, -2.9, 1.9, FZ)
	stones(K, -9.2, 0.4, -11.7, -6.6, 1.2, -9.4)
end

local function anvil(K: Kit)
	local z0, z1 = -10.9, -8.8
	local zm, d = (z0 + z1) / 2, z1 - z0
	-- two feet with a dark arch between them, a narrow waist flaring out under a thick body (wedges)
	K:box("AnvilFoot", 2.8, 2.4, z0, 3.9, 3.3, z1, IRON[2], true)
	K:box("AnvilFoot", 5.4, 2.4, z0, 6.5, 3.3, z1, IRON[2], true)
	K:box("AnvilFoot", 2.8, 2.95, z0 + 0.1, 6.5, 3.45, z1 - 0.1, IRON[2], true)
	K:box("AnvilArch", 3.9, 2.4, z0 + 0.35, 5.4, 2.95, z1 - 0.35, SOOT, true)
	K:box("AnvilWaist", 3.7, 3.4, z0 + 0.4, 5.6, 4.45, z1 - 0.4, IRON[2], true)
	K:wedge("AnvilFlare", V(d - 0.8, 0.75, 1.5), CFrame.new(6.35, 4.05, zm) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), IRON[2], true)
	K:wedge("AnvilFlare", V(d - 0.8, 0.75, 0.7), CFrame.new(3.35, 4.05, zm) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), IRON[2], true)
	K:box("AnvilTop", 3.0, 4.4, z0 + 0.1, 7.1, 5.7, z1 - 0.1, IRON[1], true)
	K:box("AnvilFace", 3.0, 5.65, z0 + 0.15, 7.1, 5.85, z1 - 0.15, C(124, 116, 116), true)
	-- the long horn (to +X) and the short heel (to -X), nearly flat on top and tapering from below
	K:wedge("AnvilHorn", V(d - 0.3, 0.45, 2.3), CFrame.new(8.25, 5.625, zm) * CFrame.Angles(0, -math.pi / 2, 0), IRON[1], true)
	K:wedge("AnvilHorn", V(d - 0.3, 1.0, 2.3), CFrame.new(8.25, 4.9, zm) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), IRON[1], true)
	K:wedge("AnvilHeel", V(d - 0.5, 0.4, 1.4), CFrame.new(2.3, 5.65, zm) * CFrame.Angles(0, math.pi / 2, 0), IRON[1], true)
	K:wedge("AnvilHeel", V(d - 0.5, 0.75, 1.4), CFrame.new(2.3, 5.075, zm) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), IRON[1], true)
end

-- the bellows: a teardrop of leather between two wooden boards (front and back), lying against the volcano with
-- its narrow end and iron nozzle pointing out and down to +X
local function bellows(K: Kit)
	local c = V(9.8, 4.5, -2.8)
	local ax = V(1, -0.62, 0).Unit
	local across = V(-ax.Y, ax.X, 0)
	blob(K, "Bellows", V(5.2, 4.6, 4.4), CFrame.fromMatrix(c, ax, across), LEATHER[1])
	for _, s in { -1, 1 } do
		-- (rounded boards, a big one and a small one toward the nozzle, make the teardrop)
		blob(K, "BellowsBoard", V(5.8, 5.0, 1.7), CFrame.fromMatrix(c + Z * (s * 1.5), ax, across), WOOD[2])
		blob(K, "BellowsBoard", V(2.6, 2.9, 1.5), CFrame.fromMatrix(c + Z * (s * 1.3) + ax * 2.0, ax, across), WOOD[2])
	end
	-- the front board's staves, drawn over its curve and drawing together toward the nozzle
	local cb = c - Z * 1.5
	for _, u0 in { -0.7, -0.35, 0, 0.35, 0.7 } do
		local prev: Vector3? = nil
		for _, t in { -0.9, -0.5, -0.1, 0.3, 0.7, 0.95 } do
			local u = u0 * (1 - 0.5 * (t + 1) / 2)
			local pt = cb + ax * (2.9 * t) + across * (2.5 * u) - Z * (0.85 * math.sqrt(math.max(0, 1 - t * t - u * u)) + 0.03)
			if prev then
				K:beam("BellowsStave", prev, pt, 0.12, 0.06, C(58, 32, 20), -Z, true)
			end
			prev = pt
		end
	end
	-- the iron collar and the nozzle
	local function along(dist: number): CFrame
		return CFrame.fromMatrix(c + ax * dist, ax, across)
	end
	K:rod("BellowsCollar", 1.7, 0.5, along(3.15), IRON[1])
	K:rod("Nozzle", 1.2, 1.0, along(3.6), IRON[2])
	K:rod("Nozzle", 0.95, 1.4, along(4.4), IRON[1])
	K:rod("NozzleRing", 1.15, 0.25, along(5.0), IRON[2])
	K:rod("NozzleHole", 0.55, 0.05, along(5.2), SOOT)
end

-- the window on the +X side: a wooden frame (the cross planks run past the posts, a rivet on each end) round a pane
-- glowing yellow in the middle and orange at the edges
local function sideWindow(K: Kit)
	local f = CFrame.lookAt(WIN, WIN + V(0.94, 0, -0.34))
	K:brick("WindowBack", V(3.6, 4.4, 0.6), f * CFrame.new(0, 0, 0.6), ROCK[2])
	neon(K:brick("WindowGlow", V(2.5, 2.9, 0.2), f * CFrame.new(0, 0, 0.2), LAVA, true), LAVA)
	neon(K:brick("WindowGlow", V(1.3, 2.1, 0.2), f * CFrame.new(0, 0, 0.12), LAVA_HOT, true), LAVA_HOT)
	for _, e in { -1, 1 } do
		K:brick("WindowFrame", V(0.6, 3.4, 0.5), f * CFrame.new(e * 1.55, 0, -0.1), WOOD[1])
		K:brick("WindowFrame", V(4.1, 0.6, 0.5), f * CFrame.new(0, e * 1.75, -0.15), WOOD[2])
		for _, e2 in { -1, 1 } do
			K:ball("Rivet", 0.3, (f * CFrame.new(e * 1.75, e2 * 1.75, -0.45)).Position, RIVET)
		end
	end
	light(K, WIN + X * 1.0, LAVA, 6, 0.5)
end

function StudEmber.build(K: Kit)
	local lines = seamPoints()
	volcano(K, lines)
	crater(K)
	furnace(K)
	shield(K)
	cleaver(K)
	chainsAndPosts(K)
	platforms(K)
	anvil(K)
	bellows(K)
	sideWindow(K)
end

return StudEmber
