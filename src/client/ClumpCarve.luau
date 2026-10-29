-- CLUMP CARVE (owner, 28 Oct: "yes" to splitting the clump meshes so a hit cuts a real notch into the stalk, then
-- "it should be different per weapon"). Chop A Forest's trunks lose real wood with every hit; ours now lose real
-- stalk. Each voxel clump mesh was split in Studio into ReplicatedStorage.ClumpCarve.<mesh>: Base (its root
-- layer) and Top (its tuft), cut out of the original meshes with EditableMesh, same texture. The first time you
-- hit a clump, your screen swaps it for those two pieces and builds the stalk between them from voxel parts in
-- the stalk's own colours (the Colors attribute, from tools/blender/voxel/models.py); a voxel the cut reaches
-- splits into 8 half-voxels. Every hit removes the half-voxels inside its weapon's cut, so the outline opens:
--   Bare Hands   a round, lumpy bowl, deepest in the middle
--   Scissors     a thin, clean V-slit that bites deep fast
--   Sickle       a wide, shallow crescent, its ends curving up
--   Mega Scythe  a long, low, flat-edged band that runs round the stalk
--   Push Mower   a ragged chew low down, at blade height (ride-on mowers too)
--   Weed Whacker a frayed, stringy band (the line shreds the stems)
--   Laser Mower  a hairline slit that wraps round fast, its walls glowing hot and cooling
-- Inside it's the stalk's own colour, a little paler (never white: that read as see-through): the skin keeps the
-- stalk's colours (the dark rim round the cut), the next ring in is the step, the core the pith; a floor catches the
-- light, a ceiling is a step darker. A few of the removed bits fly off and the freshly opened faces flash and settle. Near the end only a thin core holds the top up;
-- when it goes, the top breaks off at the cut (client/Fx falls it from there, the stump stays till its stubble
-- comes: prepareFall). Only on your screen, for your own hits (the server's "chip"); at most MAX_ACTIVE clumps at
-- once. Anything without a split mesh keeps the overlay cut (client/ClumpWound).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HitFx = require(script.Parent.HitFx)
local WeaponFx = require(script.Parent.WeaponFx)

local ClumpCarve = {}
local player = Players.LocalPlayer
local templates = ReplicatedStorage:WaitForChild("ClumpCarve", 10)
-- (29 Oct, owner: "when you punch grass the top part becomes invisible for like a split second") the split meshes
-- weren't downloaded until the first hit needed them (Studio: every one "None"), so the clump's top was gone until they
-- came in. Now they're all fetched at the start, and the whole clump stays on screen until a carve's pieces are
-- drawn (hideWhenLoaded).
local ContentProvider = game:GetService("ContentProvider")
if templates then
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, templates:GetDescendants())
	end)
end

local function fetched(p: BasePart): boolean
	local id = if p:IsA("MeshPart") then p.MeshId else ""
	if id == "" then
		return true
	end
	local ok, status = pcall(ContentProvider.GetAssetFetchStatus, ContentProvider, id)
	return not ok or status == Enum.AssetFetchStatus.Success
end

-- Hide the clump's own mesh once the carve's pieces are drawn (at most 1.5 s later; `still`: the carve is on).
local function hideWhenLoaded(src: BasePart, pieces: { BasePart }, still: () -> boolean)
	local function ready(): boolean
		for _, p in pieces do
			if not fetched(p) then
				return false
			end
		end
		return true
	end
	if ready() then
		src.Transparency = 1
		return
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		if ready() or os.clock() - t0 > 1.5 or not still() then
			if conn then
				conn:Disconnect()
			end
			if still() and src.Parent then
				src.Transparency = 1
			end
		end
	end)
end

-- (a carve you walked away from, 40+ studs and 10+ s since its last hit, is put back to the plain mesh to free its
-- slot when a new clump needs one; ~100 small parts each at most)
local MAX_ACTIVE = 8
local N = 6 -- half-voxels across the stalk (it is 3 voxels wide)
local ROWS = 10 -- half-voxel rows from the root layer up to the tuft (5 voxels)
-- the rows a cut may open: the bottom and top rows stay (the root layer and the tuft have no faces where they
-- meet the stalk, so a hole there would show through them)
local LOW, HIGH = 1, ROWS - 2
local FLY_MAX = 7 -- removed bits that fly off per hit
local FIRST_CUT = 0.1 -- how big a cut the first blow opens, however tough the clump (0..1 of the cut sizes below)
local U = 40 -- a voxel, in the template meshes' units
local WHITE = Color3.new(1, 1, 1)
local PITH = Color3.fromRGB(240, 248, 206) -- the pale lime-cream inside of a cut stem (as client/ClumpWound)

-- How each weapon cuts, for how much of the clump is cut so far (c, 0..1). (Tuned in a simulation of these exact
-- formulas, 28 Oct: by 15/40/70/92% cut the bigger cuts have taken about 10-20 / 30-50 / 60-80 / 75-105 of the
-- 360 half-voxels, the scissors' and the laser's slits stay slimmer, and the back of the core is never cut.)
--   A how far round the stalk (radians either side of where it came from), B how tall (half-voxel rows either
--   side of the aim), D how deep (half-voxels in from the skin: the core is 2.5 in, so near the end only a thin
--   core is left), noise how lumpy its edge is, kind its profile (bowl round, vee a wedge, crescent a curve whose
--   ends lift, band flat-topped), row a fixed height (mowers cut low), strand a frayed edge, hot glowing walls.
type Shape = { A: (number) -> number, B: (number) -> number, D: (number) -> number, noise: number, kind: string, row: number?, strand: boolean?, hot: Color3? }
local SHAPES: { [string]: Shape } = {
	Hands = {
		A = function(c) return 0.55 + 1.9 * c ^ 0.9 end,
		B = function(c) return 1.3 + 1.5 * c ^ 0.8 end,
		D = function(c) return 1.0 + 1.8 * c ^ 0.85 end,
		noise = 0.22,
		kind = "bowl",
	},
	Scissors = {
		A = function(c) return 0.7 + 1.5 * c end,
		B = function(c) return 0.8 + 0.9 * c end,
		D = function(c) return 1.8 + 1.3 * c ^ 0.8 end,
		noise = 0.04,
		kind = "vee",
	},
	Sickle = {
		A = function(c) return 0.95 + 2.0 * c end,
		B = function(c) return 0.9 + 1.2 * c end,
		D = function(c) return 0.8 + 1.9 * c ^ 1.1 end,
		noise = 0.07,
		kind = "crescent",
	},
	MegaScythe = {
		A = function(c) return 1.2 + 2.0 * c end,
		B = function(c) return 0.8 + 0.9 * c end,
		D = function(c) return 0.9 + 1.6 * c ^ 0.9 end,
		noise = 0.04,
		kind = "band",
	},
	PushMower = {
		A = function(c) return 1.0 + 2.2 * c end,
		B = function(c) return 1.0 + 0.8 * c end,
		D = function(c) return 1.0 + 1.9 * c end,
		noise = 0.32,
		kind = "bowl",
		row = 1.5,
	},
	WeedWhacker = {
		A = function(c) return 1.0 + 1.8 * c end,
		B = function(c) return 1.0 + 0.9 * c end,
		D = function(c) return 0.8 + 1.5 * c end,
		noise = 0.45,
		kind = "band",
		strand = true,
	},
	LaserMower = {
		A = function(c) return 1.2 + 2.2 * c end,
		B = function(c) return 0.6 + 0.5 * c end,
		D = function(c) return 1.2 + 1.9 * c end,
		noise = 0,
		kind = "vee",
		hot = Color3.fromRGB(120, 240, 255),
	},
}

type Tones = { floor: Color3, wall: Color3, ceil: Color3, deep: Color3, grain: Color3, step: Color3, stepCeil: Color3, fresh: Color3 }
type Side = { dir: Vector2, row: number, cut: number, seed: number, tool: string }
type Carve = {
	m: Model,
	src: BasePart, -- the original mesh (hidden on this screen)
	base: BasePart,
	top: BasePart,
	rel: CFrame, -- the original mesh in the clump's upright pose
	sc: Vector3, -- template mesh units -> studs
	centre: Vector3, -- the stalk's bottom middle, in mesh units
	colors: { Color3 }, -- the stalk's 45 voxels (y 1..5, x, z)
	solid: { [number]: boolean }, -- half-voxels still there
	vox: { [number]: BasePart }, -- whole voxels not split yet
	cells: { [number]: BasePart }, -- half-voxels of split voxels
	split: { [number]: boolean },
	sides: { Side },
	tones: Tones,
	last: number, -- when it was last hit
}
local carves: { [Model]: Carve } = {}
local active = 0
-- clumps going over (client/Fx "fell"): a blow still on its way doesn't start a new stalk on one
local falling: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function mul(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- (owner, 28 Oct, first look in play: "when you punch it a part becomes invisible": an evenly pale cut read as a
-- see-through window, not a hole) a hole reads as a hole when it gets darker the deeper and higher you look into it:
-- the floor catches the light, the side walls are a step down, the ceiling and the back of the hole are in shade,
-- and the skin round the edge darkens a touch (client/ClumpCarve parts also cast shadows into it).
-- (29 Oct 22:44, owner, again: "after first punch it becomes a little invisible": the inside was still mostly pith,
-- near white, and lit by the sky it read as a window onto the sky) the inside is the stalk's own colour, only a
-- third of the way to pith: lighter than the skin where it's fresh, darker in the shade, never white.
local function tonesFor(base: Color3): Tones
	local inside = base:Lerp(PITH, 0.32)
	return {
		floor = inside, -- the floor of the cut, lit from above
		wall = mul(inside, 0.78),
		ceil = mul(inside, 0.5), -- the top inner wall, in shade
		deep = mul(inside, 0.6), -- the back of the hole
		grain = mul(inside, 0.68), -- faint fibres up the stem
		step = mul(base:Lerp(inside, 0.5), 0.82),
		stepCeil = mul(base:Lerp(inside, 0.5), 0.55),
		-- (30 Oct, owner: "even the first hit should show": a first blow only takes the skin off, and the stem
		-- under it was the side-wall green, so the scuff hardly showed till the second blow went deeper) the back of
		-- a shallow scuff is fresh, lit: a shade lighter than the skin
		fresh = mul(inside, 0.92),
	}
end

-- a fixed little number per cell and cut (-1..1): the lumpy edge of a torn cut
local function bump(a: number, b: number, r: number, seed: number): number
	local h = math.sin(a * 12.9898 + b * 4.1414 + r * 78.233 + seed * 37.719) * 43758.5453
	return (h - math.floor(h)) * 2 - 1
end

local function cellKey(a: number, b: number, r: number): number
	return a + b * N + r * N * N
end

local function voxKey(a: number, b: number, r: number): number
	return a // 2 + (b // 2) * 3 + (r // 2) * 9
end

local function toolNow(): string
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then
		return "PushMower" -- a ride-on mower chews low like the push mower
	end
	local id = WeaponFx.heldId()
	return if id and SHAPES[id] then id else "Hands"
end

-- the skin colour of voxel (I, K) at height vy (1..5)
local function skin(cv: Carve, I: number, K: number, vy: number): Color3
	if cv.src.TextureID == "" then
		return cv.src.Color -- a mutation painted it (server/Field reveal)
	end
	return cv.colors[(vy - 1) * 9 + I * 3 + K + 1] or cv.tones.step
end

-- is any neighbour of half-voxel (a, b, r) cut away?
local function opened(cv: Carve, a: number, b: number, r: number): boolean
	return (a > 0 and not cv.solid[cellKey(a - 1, b, r)])
		or (a < N - 1 and not cv.solid[cellKey(a + 1, b, r)])
		or (b > 0 and not cv.solid[cellKey(a, b - 1, r)])
		or (b < N - 1 and not cv.solid[cellKey(a, b + 1, r)])
		or (r > 0 and not cv.solid[cellKey(a, b, r - 1)])
		or (r < ROWS - 1 and not cv.solid[cellKey(a, b, r + 1)])
end

local function cellColor(cv: Carve, a: number, b: number, r: number): Color3
	local ring = math.min(a, N - 1 - a, b, N - 1 - b)
	if ring == 0 then
		local sk = skin(cv, a // 2, b // 2, r // 2 + 1)
		return if opened(cv, a, b, r) then mul(sk, 0.8) else sk -- the skin round the cut: its dark rim
	end
	local tn = cv.tones
	local up = r < ROWS - 1 and not cv.solid[cellKey(a, b, r + 1)] -- open above: a floor
	local down = r > 0 and not cv.solid[cellKey(a, b, r - 1)] -- open below: a ceiling
	if up then
		return tn.floor
	elseif down then
		return if ring == 1 then tn.stepCeil else tn.ceil
	elseif ring == 1 then
		-- the skin in front of it is gone: the back of a shallow scuff, facing out into the light
		local open = (a == 1 and not cv.solid[cellKey(0, b, r)])
			or (a == N - 2 and not cv.solid[cellKey(N - 1, b, r)])
			or (b == 1 and not cv.solid[cellKey(a, 0, r)])
			or (b == N - 2 and not cv.solid[cellKey(a, N - 1, r)])
		return if open then tn.fresh else tn.step -- else a side wall near the skin
	end
	return if (a + b + r // 3) % 3 == 0 then tn.grain else tn.deep -- the back of the hole
end

-- mesh units (from the mesh's middle) -> where that sits in the clump's upright pose
local function relAt(cv: Carve, p: Vector3): CFrame
	return cv.rel * CFrame.new(p * cv.sc)
end

local function cellPos(cv: Carve, a: number, b: number, r: number): Vector3
	return cv.centre + Vector3.new((a - 2.5) * U / 2, (r + 0.5) * U / 2, (b - 2.5) * U / 2)
end

local function newPart(cv: Carve, rel: CFrame, size: Vector3, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = "Carve"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true -- (shadow falls into the cut)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = if cv.src.TextureID == "" then cv.src.Material else Enum.Material.SmoothPlastic
	p.Color = color
	HitFx.attach(cv.m, p, rel, size) -- leans, wobbles and squashes with the clump
	p.Parent = cv.m
	return p
end

-- Swap the clump for its split pieces and build its stalk in whole voxels.
local function start(m: Model): Carve?
	if not templates then
		return nil
	end
	local src, tpl
	for _, ch in m:GetChildren() do
		if ch:IsA("MeshPart") and templates:FindFirstChild(ch.Name) then
			src, tpl = ch, templates[ch.Name]
			break
		end
	end
	if not src or not tpl then
		return nil
	end
	local ms = tpl:GetAttribute("MeshSize")
	local centre = tpl:GetAttribute("StalkCentre")
	local hex = tpl:GetAttribute("Colors")
	local baseT, topT = tpl:FindFirstChild("Base"), tpl:FindFirstChild("Top")
	if typeof(ms) ~= "Vector3" or typeof(centre) ~= "Vector3" or type(hex) ~= "string" or not baseT or not topT then
		return nil
	end
	local rel, size = HitFx.rest(m, src)
	local sc = Vector3.new(size.X / ms.X, size.Y / ms.Y, size.Z / ms.Z)
	local colors = {}
	local sum = Vector3.zero
	for i = 0, 44 do
		local c = Color3.fromHex(hex:sub(i * 6 + 1, i * 6 + 6))
		colors[i + 1] = c
		sum += Vector3.new(c.R, c.G, c.B)
	end
	local avg = sum / 45
	local cv: Carve = {
		m = m,
		src = src :: BasePart,
		base = nil :: any,
		top = nil :: any,
		rel = rel,
		sc = sc,
		centre = centre,
		colors = colors,
		solid = {},
		vox = {},
		cells = {},
		split = {},
		sides = {},
		last = os.clock(),
		tones = tonesFor(if src.TextureID == "" then src.Color else Color3.new(avg.X, avg.Y, avg.Z)),
	}
	for _, t in { baseT, topT } do
		local p = (t :: MeshPart):Clone()
		p:SetAttribute("Offset", nil)
		p:SetAttribute("AssetId", nil)
		p:SetAttribute("Clamped", nil)
		p.Name = "Carve" .. t.Name
		p.TextureID = (src :: MeshPart).TextureID
		p.Color = src.Color
		p.Material = src.Material
		HitFx.attach(m, p, relAt(cv, t:GetAttribute("Offset") :: Vector3), (t :: MeshPart).MeshSize * sc)
		p.Parent = m
		if t == baseT then
			cv.base = p
		else
			cv.top = p
		end
	end
	-- the clump's own mesh goes (on this screen only; clones of it stay hidden too: client/Fx's falling copy) once
	-- the pieces are drawn
	hideWhenLoaded(src, { cv.base, cv.top }, function()
		return cv.base.Parent ~= nil
	end)
	for i = 0, N * N * ROWS - 1 do
		cv.solid[i] = true
	end
	for vy = 1, 5 do
		for I = 0, 2 do
			for K = 0, 2 do
				local pos = centre + Vector3.new((I - 1) * U, (vy - 1) * U + U / 2, (K - 1) * U)
				local color = if I == 1 and K == 1 then cv.tones.deep else skin(cv, I, K, vy)
				cv.vox[I + K * 3 + (vy - 1) * 9] = newPart(cv, relAt(cv, pos), Vector3.one * U * 1.005 * sc, color)
			end
		end
	end
	return cv
end

-- Split the whole voxel `k` into its solid half-voxels.
local function splitVox(cv: Carve, k: number)
	if cv.split[k] then
		return
	end
	cv.split[k] = true
	local old = cv.vox[k]
	if old then
		old:Destroy()
		cv.vox[k] = nil
	end
	local I, K, vy = k % 3, (k // 3) % 3, k // 9
	for da = 0, 1 do
		for db = 0, 1 do
			for dr = 0, 1 do
				local a, b, r = I * 2 + da, K * 2 + db, vy * 2 + dr
				local key = cellKey(a, b, r)
				if cv.solid[key] then
					cv.cells[key] = newPart(cv, relAt(cv, cellPos(cv, a, b, r)), Vector3.one * (U / 2) * 1.01 * cv.sc, cellColor(cv, a, b, r))
				end
			end
		end
	end
end

-- Is half-voxel (a, b, r) inside side `s`'s cut?
local function inCut(s: Side, sh: Shape, a: number, b: number, r: number): boolean
	local px, pz = a - 2.5, b - 2.5
	local ring = math.min(a, N - 1 - a, b, N - 1 - b)
	local depth = ring + 0.5
	local out = Vector2.new(px, pz).Unit
	local ang = math.acos(math.clamp(out:Dot(s.dir), -1, 1))
	if ring == 2 and ang > math.pi / 2 then
		return false -- the back of the core always stays: it holds the top up till the last hit
	end
	-- (30 Oct) a blow always opens at least a small cut: a tough clump's first hit used to take a sliver of it
	local c = math.clamp(FIRST_CUT + (1 - FIRST_CUT) * s.cut * 1.04, 0, 1)
	local A, B, D = sh.A(c), sh.B(c), sh.D(c)
	local n = if sh.strand then bump(a, b, 0, s.seed) * 0.75 + bump(a, b, r, s.seed) * 0.25 else bump(a, b, r, s.seed)
	local lump = 1 + sh.noise * n
	local qa = ang / (A * lump)
	if qa >= 1 then
		return false
	end
	local fa = if sh.kind == "band" then (1 - qa ^ 4) ^ 0.25 else math.sqrt(1 - qa * qa)
	local v = r - s.row
	if sh.kind == "crescent" then
		v -= B * 0.9 * (ang / A) ^ 2 -- the ends of the crescent lift
	end
	local q = math.abs(v) / (B * lump)
	if q >= 1 then
		return false
	end
	local fv = if sh.kind == "band" then (1 - q ^ 6) ^ (1 / 6) elseif sh.kind == "vee" then 1 - q else math.sqrt(1 - q * q)
	return depth < D * fa * fv * lump
end

-- A removed bit flies off toward the cutter and shrinks away.
local function fly(cv: Carve, a: number, b: number, r: number, color: Color3, toward: Vector3)
	local cf = cv.m:GetPivot() * relAt(cv, cellPos(cv, a, b, r))
	local p = Instance.new("Part")
	p.Name = "CarveBit"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	local s = (U / 2) * cv.sc.X * 0.95
	p.Size = Vector3.one * s
	p.CFrame = cf
	p.Parent = workspace
	local spread = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2.4
	local goal = cf.Position + toward * (1.6 + math.random() * 1.6) + spread + Vector3.new(0, 0.9 + math.random() * 1.2, 0)
	local t = 0.32 + math.random() * 0.2
	TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(goal) * CFrame.Angles(math.random() * 4, math.random() * 4, math.random() * 4),
		Size = Vector3.one * s * 0.15,
	}):Play()
	Debris:AddItem(p, t + 0.05)
end

-- (owner, 28 Oct: "make it depending on where you hit the grass ... so it keeps changing depending on where you're
-- hitting it") Where your crosshair meets the stalk as it stands now (leaning or not): the direction round the
-- stalk from its middle to that point, and the half-voxel row. The box is widened a little so a near miss at its
-- edge still counts; nil when the crosshair isn't on the stalk.
local function aimSpot(cv: Carve, m: Model): (Vector2?, number?)
	local cam = workspace.CurrentCamera
	if not cam then
		return nil, nil
	end
	local h = U / 2
	local cf = m:GetPivot() * cv.rel * CFrame.new(cv.centre * cv.sc) -- the stalk's bottom middle
	local hx, hy, hz = 3 * h * cv.sc.X, ROWS * h * cv.sc.Y, 3 * h * cv.sc.Z
	local o = cf:PointToObjectSpace(cam.CFrame.Position)
	local d = cf:VectorToObjectSpace(cam.CFrame.LookVector)
	local lo = Vector3.new(-hx * 1.3, 0, -hz * 1.3)
	local hi = Vector3.new(hx * 1.3, hy, hz * 1.3)
	local t0, t1 = -math.huge, math.huge
	for _, ax in { "X", "Y", "Z" } do
		local oo, dd, l, u = (o :: any)[ax], (d :: any)[ax], (lo :: any)[ax], (hi :: any)[ax]
		if math.abs(dd) < 1e-6 then
			if oo < l or oo > u then
				return nil, nil
			end
		else
			local ta, tb = (l - oo) / dd, (u - oo) / dd
			if ta > tb then
				ta, tb = tb, ta
			end
			t0, t1 = math.max(t0, ta), math.min(t1, tb)
			if t0 > t1 then
				return nil, nil
			end
		end
	end
	if t0 < 0 or t0 > 40 then
		return nil, nil
	end
	local p = o + d * t0
	local dir = Vector2.new(p.X / (h * cv.sc.X), p.Z / (h * cv.sc.Z)) -- half-voxels from the middle (3 on a face)
	if dir.Magnitude < 0.3 then
		return nil, nil
	end
	return dir.Unit, math.clamp(math.floor(p.Y / (h * cv.sc.Y)), LOW, HIGH)
end

-- The row your crosshair is on where the view line meets the stalk (nil when you aren't looking at it).
local function aimRow(cv: Carve, bottom: Vector3, cellH: number, R: number): number?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local eye, look = cam.CFrame.Position, cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local to = Vector3.new(bottom.X - eye.X, 0, bottom.Z - eye.Z)
	if flat.Magnitude < 0.05 or to.Magnitude < 0.05 then
		return nil
	end
	local dot = to.Unit:Dot(flat.Unit)
	local off = to.Magnitude * math.sqrt(math.max(0, 1 - dot * dot))
	if dot < 0.5 or off > R + 1.2 then
		return nil
	end
	local t = math.max(0, to.Magnitude - R) / flat.Magnitude
	local y = eye.Y + look.Y * t - bottom.Y
	return math.clamp(math.floor(y / cellH), LOW + 1, HIGH - 1)
end

-- Put a carve back to the plain mesh (frees its slot).
local function restore(cv: Carve)
	for _, p in cv.vox do
		p:Destroy()
	end
	for _, p in cv.cells do
		p:Destroy()
	end
	cv.base:Destroy()
	cv.top:Destroy()
	cv.src.Transparency = 0
	if carves[cv.m] then
		carves[cv.m] = nil
		active -= 1
	end
end

-- Make room for a new carve: forget clumps that are gone, then put back the stalest one you walked away from.
local function makeRoom(): boolean
	for other in carves do
		if not other.Parent then
			carves[other] = nil
			active -= 1
		end
	end
	if active < MAX_ACTIVE then
		return true
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local now = os.clock()
	local oldest: Carve? = nil
	for m, cv in carves do
		local far = not root or (m:GetPivot().Position - root.Position).Magnitude > 40
		if far and now - cv.last > 10 and (not oldest or cv.last < oldest.last) then
			oldest = cv
		end
	end
	if oldest then
		restore(oldest)
	end
	return active < MAX_ACTIVE
end

-- A hit (the server's "chip": model, from, dealt, max, z, mut). True when it was carved here.
function ClumpCarve.hit(d): boolean
	local m = d.model
	if typeof(m) ~= "Instance" or not m:IsA("Model") or not m.Parent or typeof(d.from) ~= "Vector3" or not d.max or d.max <= 0 then
		return false
	end
	if falling[m] then
		return true -- (30 Oct) it's going over: a blow that lands late doesn't start a new stalk on it
	end
	local cv = carves[m]
	if cv and (cv.src.Parent ~= m or not cv.base.Parent or not cv.top.Parent) then
		-- (30 Oct) its mesh was swapped under it (streamed out and back in) or a piece went: put it back and start
		-- over, rather than leave the plant hidden, or doubled with its cut hidden inside
		restore(cv)
		cv = nil
	end
	if not cv then
		if active >= MAX_ACTIVE and not makeRoom() then
			return false
		end
		local made = start(m)
		if not made then
			return false
		end
		cv = made
		carves[m] = made
		active += 1
		m.AncestryChanged:Connect(function(_, parent)
			if not parent and carves[m] then
				carves[m] = nil
				active -= 1
			end
		end)
	end
	local c = cv :: Carve
	c.last = os.clock()
	-- keep the pieces dressed like the original (a mutation repaints it on the first hit)
	for _, p in { c.base, c.top } do
		if p.TextureID ~= (c.src :: MeshPart).TextureID then
			p.TextureID = (c.src :: MeshPart).TextureID
		end
		p.Color = c.src.Color
		p.Material = c.src.Material
	end
	if c.src.TextureID == "" then
		c.tones = tonesFor(c.src.Color)
	end
	local tool = toolNow()
	local sh = SHAPES[tool]
	local upright = HitFx.base(m)
	local meshCf = upright * c.rel
	local bottom = (meshCf * CFrame.new(c.centre * c.sc)).Position
	local cellH = (U / 2) * c.sc.Y
	local R = (U * 1.5) * c.sc.X
	-- the cut goes where your crosshair is on the stalk (its side and height); a mower cuts low on the side you
	-- come from; without an aim, the side facing you at chest height
	local aimDir, aimR = aimSpot(c, m)
	local localDir = meshCf:VectorToObjectSpace(Vector3.new(d.from.X - bottom.X, 0, d.from.Z - bottom.Z))
	local dir = Vector2.new(localDir.X, localDir.Z)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector2.new(0, 1)
	if aimDir and aimDir:Dot(dir) > -0.2 then
		dir = aimDir
	end
	local row = sh.row or aimR or aimRow(c, bottom, cellH, R) or math.clamp(math.floor(math.min((m:GetAttribute("Height") or 7) * 0.17, 2.8) / cellH), LOW + 1, HIGH - 1)
	-- the same spot again deepens that hole and pulls it a little toward this hit; a new spot starts a hole of its
	-- own there (a bit bigger the more the clump is cut already), and holes that meet run into each other
	local side: Side? = nil
	local most = 0
	for _, s in c.sides do
		most = math.max(most, s.cut)
		if not side and s.tool == tool and s.dir:Dot(dir) > 0.93 and math.abs(s.row - row) <= 1 then
			side = s
		end
	end
	if side then
		side.dir = (side.dir * 2 + dir).Unit
		side.row = (side.row * 2 + row) / 3
	else
		side = { dir = dir, row = row, cut = most * 0.35, seed = math.random() * 100, tool = tool }
		table.insert(c.sides, side :: Side)
	end
	local s = side :: Side
	s.cut += (if type(d.dealt) == "number" then d.dealt else d.max * 0.25) / d.max
	-- what this hit takes out
	local removed = {}
	for r = LOW, HIGH do
		for a = 0, N - 1 do
			for b = 0, N - 1 do
				local key = cellKey(a, b, r)
				if c.solid[key] and inCut(s, sh, a, b, r) then
					table.insert(removed, { a, b, r, key })
				end
			end
		end
	end
	if #removed == 0 then
		return true
	end
	if RunService:IsStudio() then
		task.defer(function() -- (Studio tests: the stalk's state as 360 ones and zeros, key a + b*6 + r*36)
			local bits = table.create(N * N * ROWS)
			for i = 0, N * N * ROWS - 1 do
				bits[i + 1] = if c.solid[i] then "1" else "0"
			end
			m:SetAttribute("CarveSolid", table.concat(bits))
		end)
	end
	local colorsBefore = {}
	for i, e in removed do
		colorsBefore[i] = cellColor(c, e[1], e[2], e[3])
		c.solid[e[4]] = false
	end
	-- split every voxel the cut reaches or opens onto, and drop the removed half-voxels
	local touched: { [number]: boolean } = {}
	local NB = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
	for _, e in removed do
		touched[voxKey(e[1], e[2], e[3])] = true
		for _, o in NB do
			local a, b, r = e[1] + o[1], e[2] + o[2], e[3] + o[3]
			if a >= 0 and a < N and b >= 0 and b < N and r >= 0 and r < ROWS then
				touched[voxKey(a, b, r)] = true
			end
		end
	end
	for k in touched do
		splitVox(c, k)
	end
	for _, e in removed do
		local p = c.cells[e[4]]
		if p then
			p:Destroy()
			c.cells[e[4]] = nil
		end
	end
	-- the faces this hit opened: their colour for where they now sit (floor, ceiling), flashing in white-hot
	local exposed: { [number]: boolean } = {}
	for _, e in removed do
		for _, o in NB do
			local a, b, r = e[1] + o[1], e[2] + o[2], e[3] + o[3]
			if a >= 0 and a < N and b >= 0 and b < N and r >= 0 and r < ROWS then
				local key = cellKey(a, b, r)
				if c.solid[key] and not exposed[key] then
					exposed[key] = true
					local p = c.cells[key]
					if p then
						local color = cellColor(c, a, b, r)
						if sh.hot then
							p.Material = Enum.Material.Neon
							p.Color = sh.hot
							task.delay(0.45, function()
								if p.Parent then
									p.Material = if c.src.TextureID == "" then c.src.Material else Enum.Material.SmoothPlastic
								end
							end)
							TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = color }):Play()
						else
							p.Color = color:Lerp(WHITE, 0.25) -- (a flash, not white: white read as see-through)
							TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = color }):Play()
						end
					end
				end
			end
		end
	end
	-- a few of the removed bits fly off toward you (the skin ones first: that's what you see go)
	local toward = Vector3.new(d.from.X - bottom.X, 0, d.from.Z - bottom.Z)
	toward = if toward.Magnitude > 1e-3 then toward.Unit else Vector3.zAxis
	table.sort(removed, function(x, y)
		return math.min(x[1], N - 1 - x[1], x[2], N - 1 - x[2]) < math.min(y[1], N - 1 - y[1], y[2], N - 1 - y[2])
	end)
	local i0 = 0
	for i, e in removed do
		if i0 >= FLY_MAX then
			break
		end
		if i % 2 == 1 or #removed <= FLY_MAX then
			i0 += 1
			fly(c, e[1], e[2], e[3], colorsBefore[i] or c.tones.floor, toward)
		end
	end
	return true
end

-- Is this clump carved here? (client/Fx falls a carved clump from its cut.)
function ClumpCarve.carved(m: Model): boolean
	return carves[m] ~= nil
end

-- The clump is falling: mark what stays standing (the root layer and the stalk below the deepest cut, attribute
-- CarveStump) and return the height (world Y, upright pose) it breaks at; nil when it isn't carved.
function ClumpCarve.prepareFall(m: Model): number?
	falling[m] = true
	local cv = carves[m]
	if not cv then
		return nil
	end
	local best: Side? = nil
	for _, s in cv.sides do
		if not best or s.cut > best.cut then
			best = s
		end
	end
	local row = math.clamp(math.floor((if best then best.row else 4) + 0.5), LOW, HIGH)
	cv.base:SetAttribute("CarveStump", true)
	for key, p in cv.cells do
		if p.Parent and key // (N * N) < row then
			p:SetAttribute("CarveStump", true)
		end
	end
	for key, p in cv.vox do
		if p.Parent and (key // 9) * 2 + 1 < row then
			p:SetAttribute("CarveStump", true)
		end
	end
	local at = HitFx.base(m) * relAt(cv, cv.centre + Vector3.new(0, row * U / 2, 0))
	return at.Position.Y
end

-- (tests) the shape table, and the half-voxels still standing in clump `m`'s stalk (key a + b*6 + r*36)
ClumpCarve.SHAPES = SHAPES
function ClumpCarve.solidOf(m: Model): { [number]: boolean }?
	local cv = carves[m]
	return cv and cv.solid
end

return ClumpCarve
