-- FILM SETS (Films v2, 5 Nov 2026): the places the new films are shot in, built on this client only, far out of the
-- map (Config.FILMS_V2.setAt) so nothing of the game's world stands in a shot and nothing of theirs stands in the
-- game. In the game's own blocky style, from its own models (ReplicatedStorage.MowALawnModels).
--   FilmSet.meadow(at, opts?) -> Meadow   the moonlit meadow outside the town (the opening; the finale's sunrise)
--   FilmSet.realm(at, opts?) -> Realm     Rayan's realm: an endless gold lawn under a gold sky (the finale)
-- Each returns its pieces (for the films to move) and destroy(). Phones and Potato Mode get fewer tufts and trees.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Device = require(script.Parent.Device)
local Potato = require(script.Parent.Potato)

local FilmSet = {}

local PINK = Color3.fromRGB(255, 40, 170)
local HOT = Color3.fromRGB(255, 196, 236)
local GOLD = Color3.fromRGB(255, 200, 80)
local LAMP = Color3.fromRGB(255, 176, 96)

local function lite(): boolean
	return Potato.on or Device.touch
end

local function models(): Instance?
	return ReplicatedStorage:FindFirstChild("MowALawnModels")
end

-- A copy of one of the game's models (anchored, no collisions), its pivot put at `cf` (its bottom on cf's Y), scaled
-- by `scale`. nil if the model isn't there.
local function prop(name: string, cf: CFrame, scale: number?, parent: Instance): Model?
	local src = models()
	local t = src and src:FindFirstChild(name)
	if not t or not t:IsA("Model") then
		return nil
	end
	local m = t:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	if scale and math.abs(scale - 1) > 1e-3 then
		m:ScaleTo(m:GetScale() * scale)
	end
	-- (stand it on the ground: its bounding box's bottom at cf's height)
	local box, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local lift = pivot.Position.Y - (box.Position.Y - size.Y / 2)
	m:PivotTo(cf * CFrame.new(0, lift, 0))
	m.Parent = parent
	return m
end
FilmSet.prop = prop

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Block"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
FilmSet.block = block

-------------------------------------------------------------------------------------------------------------
-- THE MEADOW
-------------------------------------------------------------------------------------------------------------
-- The plan, in the set's own frame (+X east, -Z north, the ground at y = 0):
--   the fight's middle at the origin; the demon comes up out of a fissure 52 north of it, facing south;
--   a dirt path from the south (the town's way) up to the middle, fenced, lanterns along it;
--   Rayan's shed 30 west of the middle, its open side east; hay by it;
--   wild grass everywhere off the path (tuft_lawn), wheat and reeds by the fences;
--   oaks and birches round the edge; hills, the windmill and the town on the horizon; pink cracks in the sky.
export type Tuft = { model: Model, part: BasePart?, at: CFrame, scale: number, cut: boolean }

local function scatter(rng: Random, n: number, rMin: number, rMax: number, ok: (Vector3) -> boolean): { Vector3 }
	local out = {}
	local tries = 0
	while #out < n and tries < n * 6 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber((rMin / rMax) ^ 2, 1)) * rMax
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if ok(p) then
			table.insert(out, p)
		end
	end
	return out
end

-- (the dirt path: from (0, 0, 95) to the middle, a gentle S)
local function pathX(z: number): number
	return math.sin(z / 28) * 4
end
local function onPath(p: Vector3): boolean
	return p.Z > -6 and p.Z < 140 and math.abs(p.X - pathX(p.Z)) < 6.5
end

export type MeadowOpts = { tufts: number?, night: boolean? }

function FilmSet.meadow(at: CFrame, opts: MeadowOpts?): any
	local o = opts or {}
	local light = lite()
	local rng = Random.new(905)
	local folder = Instance.new("Folder")
	folder.Name = "FilmSet"
	local set: any = { folder = folder, at = at, tufts = {} :: { Tuft }, lanterns = {}, trees = {}, rim = {}, glow = {} }
	local function W(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	set.W = W
	set.fissure = W(0, 0, -52)

	-- the ground: one big field, darker and lighter patches over it, the path
	block(folder, Vector3.new(1400, 4, 1400), W(0, -2, -100), Color3.fromRGB(58, 92, 50), Enum.Material.Grass, "Ground")
	for _ = 1, (if light then 10 else 26) do
		local sx, sz = rng:NextNumber(30, 90), rng:NextNumber(30, 90)
		local p = Vector3.new(rng:NextNumber(-220, 220), 0, rng:NextNumber(-260, 160))
		local shade = if rng:NextNumber() < 0.5 then Color3.fromRGB(50, 82, 44) else Color3.fromRGB(66, 102, 54)
		block(folder, Vector3.new(sx, 0.2, sz), W(p.X, 0.02 + rng:NextNumber(0, 0.04), p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), shade, Enum.Material.Grass, "Patch")
	end
	for z = 140, -4, -6 do
		local x = pathX(z)
		local x2 = pathX(z - 6)
		local mid = Vector3.new((x + x2) / 2, 0.06, z - 3)
		local yaw = math.atan2(-(x2 - x), -6)
		block(folder, Vector3.new(7.5, 0.12, 6.8), W(mid.X, mid.Y, mid.Z) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(120, 92, 60), Enum.Material.Ground, "Path")
	end
	-- the fight's bare middle (trampled), round the fissure
	block(folder, Vector3.new(30, 0.14, 26), W(0, 0.07, -50), Color3.fromRGB(70, 60, 48), Enum.Material.Ground, "Scorch")

	-- the fissure: a jagged trench, its glowing pink depths, broken rock lifted round its rim (the film lifts them)
	local fz = -52
	for i = -6, 6 do
		local w = 3.4 - math.abs(i) * 0.4 + rng:NextNumber(-0.4, 0.4)
		local cf = W(i * 2.6, -0.4, fz + math.sin(i * 1.3) * 1.6) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		block(folder, Vector3.new(2.8, 0.9, math.max(w, 0.8)), cf, Color3.fromRGB(10, 6, 14), Enum.Material.Slate, "Crack")
		local g = block(folder, Vector3.new(2.6, 0.35, math.max(w - 0.9, 0.3)), cf * CFrame.new(0, 0.5, 0), PINK, Enum.Material.Neon, "CrackGlow")
		g.Transparency = 1
		table.insert(set.glow, g)
		if i % 3 == 0 then
			local pl = Instance.new("PointLight")
			pl.Color = PINK
			pl.Range = 18
			pl.Brightness = 0
			pl.Shadows = false
			pl.Parent = g
		end
	end
	for i = 1, (if light then 14 else 26) do
		local a = (i / (if light then 14 else 26)) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local r = rng:NextNumber(13, 19)
		local size = Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(1.2, 2.6), rng:NextNumber(3, 6))
		local cf = W(math.cos(a) * r * 1.25, -size.Y / 2 + 0.3, fz + math.sin(a) * r) * CFrame.Angles(0, -a, 0)
		local rock = block(folder, size, cf, Color3.fromRGB(64, 58, 62):Lerp(Color3.fromRGB(40, 70, 40), rng:NextNumber(0, 0.4)), Enum.Material.Slate, "Rim")
		-- (each chunk tips outward from the hole as the demon comes up: the film sets k 0..1)
		table.insert(set.rim, { part = rock, cf = cf, out = Vector3.new(math.cos(a), 0, math.sin(a)), tilt = rng:NextNumber(25, 55), lift = rng:NextNumber(1, 3.5) })
	end
	local pinkLight = Instance.new("PointLight")
	pinkLight.Color = PINK
	pinkLight.Range = 40
	pinkLight.Brightness = 0
	pinkLight.Shadows = false
	pinkLight.Parent = set.glow[1] or folder
	set.pinkLight = pinkLight

	-- the shed (the game's garage, 223 bricks) west of the middle, its open front facing east, and hay beside it
	set.shed = prop("garage_shed", W(-31, 0, -6) * CFrame.Angles(0, math.rad(90), 0), 0.8, folder)
	for _, h in { { -22, 4, 20 }, { -21, 8, -40 }, { -25, -12, 70 }, { -16, -15, 10 } } do
		prop("hay_bale", W(h[1], 0, h[2]) * CFrame.Angles(0, math.rad(h[3]), 0), 1.1, folder)
	end
	prop("hay_bale", W(-21.5, 3.9, 5.5) * CFrame.Angles(0, math.rad(35), 0), 1.0, folder)
	prop("barrel", W(-24, 0, -16), 1.1, folder)
	prop("crate_stack", W(-25.5, 0, 9), 1.0, folder)
	prop("wheelbarrow", W(-18, 0, -18) * CFrame.Angles(0, math.rad(-30), 0), 1.0, folder)

	-- the path's fences and lanterns
	for z = 18, 120, 8.4 do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.88 then
				local x = pathX(z) + side * 8.5
				local lean = if rng:NextNumber() < 0.15 then rng:NextNumber(-12, 12) else 0
				prop("fence", W(x, 0, z) * CFrame.Angles(0, math.rad(90 + rng:NextNumber(-4, 4)), math.rad(lean)), 1, folder)
			end
		end
	end
	for _, l in { { -9, 24 }, { 9, 46 }, { -9, 70 }, { 9, 96 }, { 17, -12 }, { -15, -28 } } do
		local m = prop("lantern_post", W(pathX(l[2]) + l[1], 0, l[2]) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0), 1.15, folder)
		if m then
			local top: BasePart? = nil
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and (not top or d.Position.Y > top.Position.Y) then
					top = d
				end
			end
			if top then
				local pl = Instance.new("PointLight")
				pl.Color = LAMP
				pl.Range = 20
				pl.Brightness = 1.3
				pl.Shadows = not light
				pl.Parent = top
			end
			table.insert(set.lanterns, { model = m, top = top })
		end
	end

	-- trees: a few big ones near (for framing), a ring of them farther out, more on the far hills
	local function tree(name: string, x: number, z: number, s: number)
		local m = prop(name, W(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), s, folder)
		if m then
			table.insert(set.trees, m)
		end
	end
	tree("oak", 44, -22, 1.05)
	tree("oak_small", -54, -44, 1.1)
	tree("birch", 52, 30, 0.95)
	tree("oak", -62, 46, 1.0)
	tree("oak_small", 30, 66, 0.9)
	tree("birch", -40, -88, 1.1)
	tree("oak", 70, -70, 1.2)
	local far = if light then 16 else 40
	for i = 1, far do
		local a = (i / far) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(115, 210)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r - 40)
		if not onPath(p) and not (p.Z < -90 and math.abs(p.X) < 45) then
			local names = { "oak", "oak_small", "birch" }
			tree(names[rng:NextInteger(1, 3)], p.X, p.Z, rng:NextNumber(0.9, 1.5))
		end
	end
	for _, r in { { -14, 72, 1.3 }, { 26, -36, 1.0 }, { -36, 30, 1.2 }, { 60, 8, 1.5 }, { -70, -10, 1.4 } } do
		prop("rock", W(r[1], 0, r[2]) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), r[3], folder)
	end
	prop("stump", W(18, 0, 28), 1.1, folder)
	prop("log", W(22, 0, 31) * CFrame.Angles(0, math.rad(60), 0), 1.2, folder)
	prop("signpost", W(pathX(110) + 6, 0, 110) * CFrame.Angles(0, math.rad(-20), 0), 1.0, folder)

	-- the horizon: hills all round, the windmill on the north-east hill against the cracked sky, the town south-east
	local hills = if light then 6 else 11
	for i = 1, hills do
		local a = (i / hills) * math.pi * 2
		local r = rng:NextNumber(420, 520)
		prop("mountain", W(math.cos(a) * r, -18, math.sin(a) * r - 60) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(3.2, 5.0), folder)
	end
	prop("forge_windmill", W(150, 0, -230) * CFrame.Angles(0, math.rad(200), 0), 58, folder)
	prop("forge_barn", W(185, 0, -205) * CFrame.Angles(0, math.rad(220), 0), 34, folder)
	local townAt = Vector3.new(170, 0, 240)
	for i, h in { { 0, 0, "forge_house_red", 26 }, { 34, 12, "forge_house_blue", 24 }, { -30, 18, "forge_house_blue", 22 }, { 12, 44, "forge_house_red", 28 }, { -12, -30, "forge_barn", 30 } } do
		local m = prop(h[3], W(townAt.X + h[1], 0, townAt.Z + h[2]) * CFrame.Angles(0, math.rad(200 + i * 23), 0), h[4], folder)
		if m then
			-- (lit windows: a warm glow by each house)
			local glowAt = W(townAt.X + h[1], 6, townAt.Z + h[2] - 6)
			local g = block(folder, Vector3.new(1, 1, 1), glowAt, LAMP, Enum.Material.Neon, "TownLight")
			g.Transparency = 1
			local pl = Instance.new("PointLight")
			pl.Color = LAMP
			pl.Range = 26
			pl.Brightness = 2
			pl.Parent = g
		end
	end

	-- the wild grass (tall tufts), wheat and reeds by the fences
	local count = o.tufts or (if light then 260 else 640)
	local spots = scatter(rng, count, 4, 92, function(p)
		return not onPath(p) and not (math.abs(p.X) < 22 and p.Z < -38 and p.Z > -66) and not (p.X < -22 and p.X > -42 and math.abs(p.Z + 6) < 11)
	end)
	for i, p in spots do
		local s = rng:NextNumber(0.75, 1.35)
		local cf = W(p.X, 0, p.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local m = prop("tuft_lawn", cf, s, folder)
		if m then
			table.insert(set.tufts, { model = m, part = m:FindFirstChildWhichIsA("BasePart", true), at = cf, scale = s, cut = false })
		end
		if i % 120 == 0 then
			task.wait()
		end
	end
	for z = 20, 116, 5 do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.55 then
				local x = pathX(z) + side * rng:NextNumber(9.5, 12)
				prop(if rng:NextNumber() < 0.6 then "tuft_wheat" else "tuft_reeds", W(x, 0, z + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(0.8, 1.2), folder)
			end
		end
	end

	-- the sky's pink cracks (far north, high over the demon): jagged neon lines, a darker halo round them
	local sky = Instance.new("Model")
	sky.Name = "SkyCracks"
	local cracks = {}
	local function crack(from: Vector3, dir: Vector3, len: number, width: number, depth: number)
		local p = from
		local d = dir.Unit
		local steps = math.max(3, math.floor(len / 22))
		for _ = 1, steps do
			local turn = CFrame.fromAxisAngle(Vector3.zAxis, rng:NextNumber(-0.7, 0.7))
			d = (turn:VectorToWorldSpace(d)).Unit
			local seg = rng:NextNumber(24, 44)
			local q = p + d * seg
			local mid = (p + q) / 2
			local cf = W(0, 0, 0) * CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X))
			local core = block(sky, Vector3.new(seg + width, width, 1), cf, HOT, Enum.Material.Neon, "Crack")
			local halo = block(sky, Vector3.new(seg + width * 3, width * 3.6, 0.6), cf * CFrame.new(0, 0, -2), PINK, Enum.Material.Neon, "Halo")
			halo.Transparency = 0.55
			core.Transparency = 1
			halo.Transparency = 1
			table.insert(cracks, { core = core, halo = halo, order = #cracks })
			if depth > 0 and rng:NextNumber() < 0.45 then
				crack(q, d + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 0.3), 0), len * 0.45, width * 0.7, depth - 1)
			end
			p = q
		end
	end
	-- (in a plane 640 north of the set, facing it; x across, y up)
	local skyPlane = Vector3.new(0, 0, -640)
	for i, c in { { -60, 380, 0.3, -1 }, { 40, 420, -0.2, -1 }, { 170, 360, 0.8, -0.6 }, { -200, 340, -0.9, -0.5 } } do
		crack(Vector3.new(c[1], c[2], 0), Vector3.new(c[3], c[4], 0), 300 + i * 40, 5, 2)
	end
	for _, c in cracks do
		c.core.CFrame = W(0, 0, 0) * CFrame.new(skyPlane) * (W(0, 0, 0):ToObjectSpace(c.core.CFrame))
		c.halo.CFrame = W(0, 0, 0) * CFrame.new(skyPlane) * (W(0, 0, 0):ToObjectSpace(c.halo.CFrame))
	end
	sky.Parent = folder
	set.cracks = cracks
	-- how much of the sky has cracked (0..1, in the order they were drawn) and a flicker
	function set.crackSky(k: number, t: number)
		local n = #cracks
		for i, c in cracks do
			local on = (i / n) <= k
			local flick = if on then (0.5 + 0.5 * math.noise(t * 3, i * 0.7)) else 0
			c.core.Transparency = if on then 0.05 + (1 - flick) * 0.25 else 1
			c.halo.Transparency = if on then 0.62 + (1 - flick) * 0.25 else 1
		end
	end

	-- (after the reference's silhouette against a huge moon) a big moon low in the west, for Rayan's card
	local moonDir = Vector3.new(-1, 0.38, 0.25).Unit
	local moonAt = at.Position + at:VectorToWorldSpace(moonDir) * 420 + Vector3.new(0, 20, 0)
	local moon = block(folder, Vector3.new(84, 84, 84), CFrame.new(moonAt), Color3.fromRGB(226, 232, 255), Enum.Material.Neon, "Moon")
	moon.Shape = Enum.PartType.Ball
	moon.CastShadow = false
	local halo = block(folder, Vector3.new(150, 150, 150), CFrame.new(moonAt + (at.Position - moonAt).Unit * 30), Color3.fromRGB(150, 140, 255), Enum.Material.Neon, "MoonHalo")
	halo.Shape = Enum.PartType.Ball
	halo.Transparency = 0.86
	halo.CastShadow = false
	set.moon = moon
	set.moonDir = moonDir

	-- night motes drifting over the grass
	local motes = block(folder, Vector3.new(160, 1, 160), W(0, 3, -20), Color3.new(), Enum.Material.SmoothPlastic, "Motes")
	motes.Transparency = 1
	local em = Instance.new("ParticleEmitter")
	em.Rate = if light then 8 else 22
	em.Lifetime = NumberRange.new(5, 9)
	em.Speed = NumberRange.new(0.2, 0.8)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.18), NumberSequenceKeypoint.new(0.8, 0.14), NumberSequenceKeypoint.new(1, 0) })
	em.Color = ColorSequence.new(Color3.fromRGB(255, 236, 160))
	em.LightEmission = 1
	em.LightInfluence = 0
	em.Transparency = NumberSequence.new(0.2)
	em.Acceleration = Vector3.new(0, 0.15, 0)
	em.Parent = motes
	set.motes = em

	folder.Parent = workspace
	-- the tall grass round a point mown flat (the ultimate): tufts within `radius` swap to their cut version;
	-- returns the spots that were cut (for the clippings)
	function set.mow(center: Vector3, radius: number): { Vector3 }
		local cut = {}
		for _, t in set.tufts do
			if not t.cut then
				local p = t.at.Position
				if (Vector3.new(p.X, 0, p.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude <= radius then
					t.cut = true
					local stub = prop("tuft_lawn_cut", t.at, t.scale, folder)
					if stub then
						t.model:Destroy()
						t.model = stub
						t.part = stub:FindFirstChildWhichIsA("BasePart", true)
					end
					table.insert(cut, p)
				end
			end
		end
		return cut
	end
	-- (the demon's rim rocks tipped out by k 0..1)
	function set.lift(k: number)
		local e = math.clamp(k, 0, 1)
		for _, r in set.rim do
			local out = at:VectorToWorldSpace(r.out)
			local axis = at.UpVector:Cross(out)
			r.part.CFrame = (r.cf + out * e * 2.5 + at.UpVector * r.lift * e) * CFrame.fromAxisAngle(r.cf:VectorToObjectSpace(axis), math.rad(r.tilt * e))
		end
	end
	function set.destroy()
		folder:Destroy()
	end
	return set
end

-------------------------------------------------------------------------------------------------------------
-- THE REALM (Rayan's): an endless gold lawn under a gold dome, the eight guardians standing round in a ring
-------------------------------------------------------------------------------------------------------------
function FilmSet.realm(at: CFrame, opts: any?): any
	local light = lite()
	local rng = Random.new(1207)
	local folder = Instance.new("Folder")
	folder.Name = "FilmSet"
	local set: any = { folder = folder, at = at, panels = {}, tufts = {}, guardians = {} }
	local function W(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	set.W = W
	block(folder, Vector3.new(2400, 4, 2400), W(0, -2, 0), Color3.fromRGB(222, 168, 58), Enum.Material.Grass, "Ground")
	-- gold tufts, flat and bright
	local n = if light then 160 else 420
	for _, p in scatter(rng, n, 6, 140, function()
		return true
	end) do
		local m = prop("tuft_lawn", W(p.X, 0, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(0.6, 1.1), folder)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") then
					d.TextureID = ""
					d.Color = Color3.fromRGB(255, 214, 96):Lerp(Color3.fromRGB(255, 240, 180), rng:NextNumber(0, 0.5))
				end
			end
			table.insert(set.tufts, m)
		end
	end
	-- the dome: rings of pale gold glass panels, radius 300 (they shatter at the end)
	local R = 300
	for ring = 0, 5 do
		local el = math.rad(4 + ring * 14)
		local count = math.max(8, math.floor(34 * math.cos(el)))
		for i = 1, count do
			local az = (i / count) * math.pi * 2 + ring * 0.21
			local dir = Vector3.new(math.cos(az) * math.cos(el), math.sin(el), math.sin(az) * math.cos(el))
			local w = 2 * math.pi * R * math.cos(el) / count + 4
			local cf = CFrame.lookAt(W(0, 0, 0).Position + dir * R, W(0, 0, 0).Position)
			local p = block(folder, Vector3.new(w, 14 * math.pi / 180 * R + 4, 2), cf, Color3.fromRGB(255, 226, 150), Enum.Material.Glass, "Panel")
			p.Transparency = 0.35
			p.CastShadow = false
			table.insert(set.panels, { part = p, cf = cf, dir = dir })
		end
	end
	local cap = block(folder, Vector3.new(260, 2, 260), W(0, R * 0.98, 0), Color3.fromRGB(255, 236, 190), Enum.Material.Glass, "Panel")
	cap.Transparency = 0.35
	table.insert(set.panels, { part = cap, cf = cap.CFrame, dir = Vector3.yAxis })
	-- the eight guardians in a ring round the middle, facing in (BossModels, statues)
	local bm = ReplicatedStorage:FindFirstChild("BossModels")
	if bm then
		local list = bm:GetChildren()
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		for i, src in list do
			local a = (i / #list) * math.pi * 2 + math.pi / 8
			local pos = Vector3.new(math.cos(a) * 58, 0, math.sin(a) * 58)
			local m = src:Clone()
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				elseif d:IsA("BaseScript") or d:IsA("AnimationController") then
					d:Destroy()
				end
			end
			m:ScaleTo(m:GetScale() * 2.6)
			local box, size = m:GetBoundingBox()
			local cf = CFrame.lookAt(W(pos.X, 0, pos.Z).Position, W(0, 0, 0).Position)
			m:PivotTo(cf * CFrame.new(0, (m:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)), 0))
			m.Parent = folder
			table.insert(set.guardians, { model = m, name = src.Name, at = cf, size = size })
		end
	end
	-- motes of gold light
	local motes = block(folder, Vector3.new(200, 1, 200), W(0, 2, 0), Color3.new(), Enum.Material.SmoothPlastic, "Motes")
	motes.Transparency = 1
	local em = Instance.new("ParticleEmitter")
	em.Rate = if light then 10 else 30
	em.Lifetime = NumberRange.new(4, 8)
	em.Speed = NumberRange.new(0.5, 1.5)
	em.SpreadAngle = Vector2.new(180, 30)
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.22), NumberSequenceKeypoint.new(1, 0) })
	em.Color = ColorSequence.new(Color3.fromRGB(255, 236, 170))
	em.LightEmission = 1
	em.LightInfluence = 0
	em.Acceleration = Vector3.new(0, 0.6, 0)
	em.Parent = motes
	folder.Parent = workspace
	-- the dome breaks: every panel cracks white, then falls away outward, spinning (over `time`)
	function set.shatter(time: number)
		for _, pnl in set.panels do
			local p = pnl.part
			p.Material = Enum.Material.Neon
			p.Color = Color3.new(1, 1, 1)
			p.Transparency = 0.2
			local spin = CFrame.Angles(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5))
			local goal = (pnl.cf + pnl.dir * rng:NextNumber(60, 140) + Vector3.new(0, -rng:NextNumber(40, 160), 0)) * spin
			task.delay(rng:NextNumber(0, 0.25), function()
				if p.Parent then
					p.Material = Enum.Material.Glass
					p.Color = Color3.fromRGB(255, 236, 190)
					TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = goal, Transparency = 1 }):Play()
				end
			end)
		end
	end
	function set.destroy()
		folder:Destroy()
	end
	return set
end

return FilmSet
