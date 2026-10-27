-- Grass patches: spawning, chopping, hidden mutations, area clear.
-- A patch is a big clump of grass standing in its area like a tree in Chop A Forest (the tuft_<style> model, or
-- brick blades without it). You chop the one you look at: every hit cuts a fresh notch into its foot, and at 0 HP
-- it falls over away from you, breaks into bundles where it lands (server/Run drops them) and leaves stubble
-- (tuft_<style>_cut, its stump). When an area is cleared, all its stubble goes. An invisible "Spot" part marks
-- each patch for effects and the mutation glow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PropKit = require(script.Parent.PropKit)
local RunBuilder = require(script.Parent.RunBuilder)
local Models = require(script.Parent.Models)
local VoxelModels = require(script.Parent.VoxelModels)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local Lawn = require(script.Parent.Lawn)

local Field = {}

type Stalk = { stem: Part, head: Part?, cap: Part?, baseH: number, headH: number, x: number, y: number, z: number, yaw: number, lean: number }
type Patch = {
	part: Part, -- invisible spot at the clump's foot (position used for effects)
	spot: CFrame, -- where the clump stands (on the ground, turned)
	stalks: { Stalk },
	holder: Model, -- the "Patch" model everything of this clump lives in
	model: Model?, -- the Blender tuft, when uploaded (used instead of stalks)
	voxel: boolean?, -- the model is the voxel clump (server/VoxelModels): it keeps its own colours
	stalk: number?, -- the voxel clump's stalk radius (studs): you chop it there, like a tree trunk
	stub: Instance?, -- the stubble left after it falls
	notch: BasePart?, -- the fresh cut in its foot
	notchDir: Vector3?,
	fallDir: Vector3?, -- set when it falls: away from whoever cut it
	landPos: Vector3?, -- where its top lands (its bundles drop there)
	modelScale: number,
	radius: number, -- how far it reaches out from its middle (studs), for hit tests
	height: number, -- how tall it stands
	z: number,
	col: number,
	row: number,
	hp: number,
	maxHp: number,
	mut: string?, -- nil until the first hit reveals it
	cut: boolean,
	baseColor: Color3,
}

local patches: { [number]: { [number]: Patch } } = {} -- [zone][index]
local finishing: { [number]: boolean } = {} -- areas whose last clumps were mowed for the player (report #9)
-- every patch also sits in a bucket of a coarse grid ([zone][cell key]), so hit tests only look nearby
local buckets: { [number]: { [number]: { Patch } } } = {}
local CELL = 24
Field.remaining = {} :: { [number]: number }
Field.totals = {} :: { [number]: number } -- how many patches each zone has (the ring map gives each its own count)
Field.unlocked = 1 -- zones above this can't be cut yet (gate closed)

local folder: Folder? = nil
local rng = Random.new()
local TURF_TOP = 0.02 -- the clumps stand on the zone's ground (top at y = 0)
local MAX_RADIUS = 10 -- the widest clump's reach from its middle (hit tests look this far past their circle)

-- Hooks the run sets up.
Field.onCut = nil :: ((Player, Patch) -> boolean)? -- return false to refuse (bag full)
Field.canCut = nil :: ((Player) -> boolean)?
Field.onZoneCleared = nil :: ((number) -> ())?
Field.onProgress = nil :: (() -> ())?
Field.forceMutation = nil :: ((Player?, string) -> string?)? -- a class's forced mutation (server/ClassPerks)
Field.onForced = nil :: ((Player, Vector3) -> ())?
-- Where zone z's clumps stand ({ cf, scale } each). RunBuilder.patches for the plots map; server/Run sets
-- RunWorld.patches for the generated world.
Field.spots = nil :: ((number) -> { any })?

local function spotsFor(z: number): { any }
	return (Field.spots or RunBuilder.patches)(z)
end

-- The generated world's area id for zone z ("meadow", "frost"...), when its voxel clumps are imported.
local function voxelId(z: number): string?
	local def = Zones.list[z]
	if Config.WORLD_GEN and def and VoxelModels.has("Clump_" .. def.id .. "_1") then
		return def.id
	end
	return nil
end

-- The clump model of area z, and the colour it's painted when the area has a tint.
local function clumpName(z: number): string
	local def = Config.ZONES[z]
	return def.model or ("tuft_" .. def.style)
end

-- Paint a model one flat colour (a toy model's colour is a texture, so the texture goes).
local function paint(model: Instance, color: Color3, material: Enum.Material?)
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			d:Destroy()
		end
	end
	local i = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			i += 1
			if d:IsA("MeshPart") then
				d.TextureID = "" -- a voxel model's colours are its texture: drop it so the paint shows
			end
			d.Color = PropKit.shade(color, 0.94 + (i % 3) * 0.05)
			d.Material = material or Enum.Material.Grass
		end
	end
end

local function cellKey(cx: number, cz: number): number
	return (cx + 1000) * 4096 + (cz + 1000)
end

-- How many patches zone z has.
function Field.totalIn(z: number): number
	return Field.totals[z] or #spotsFor(z)
end

-- How each zone's grass looks: stalk count, width, height factor, and an optional head on top.
-- How each zone's grass looks. A patch is a tuft: `count` blades fanned around the middle, each a slab
-- `width` wide and `thick` deep, leaning outward by `lean` degrees. Wheat and reeds carry a head on top.
local STYLES = {
	lawn = { count = 6, width = 1.3, thick = 0.45, height = 1.0, lean = 16, spread = 1.0 },
	golf = { count = 7, width = 1.0, thick = 0.4, height = 0.75, lean = 10, spread = 1.3 },
	wheat = { count = 5, width = 0.55, thick = 0.55, height = 1.0, lean = 7, spread = 1.2, head = Vector3.new(0.9, 1.7, 0.9), headColor = Color3.fromRGB(215, 160, 50) },
	reeds = { count = 5, width = 0.55, thick = 0.55, height = 1.0, lean = 6, spread = 1.3, head = Vector3.new(0.85, 1.9, 0.85), headColor = Color3.fromRGB(115, 70, 40) },
	jungle = { count = 5, width = 2.3, thick = 0.35, height = 0.75, lean = 34, spread = 0.6 },
	meadow = { count = 7, width = 1.1, thick = 0.4, height = 0.9, lean = 12, spread = 1.2, head = Vector3.new(0.7, 0.7, 0.7), headColor = Color3.fromRGB(255, 235, 90) },
	blossom = { count = 6, width = 1.3, thick = 0.45, height = 1.0, lean = 16, spread = 1.0, head = Vector3.new(0.8, 0.8, 0.8), headColor = Color3.fromRGB(255, 120, 180) },
	prairie = { count = 5, width = 0.6, thick = 0.55, height = 1.0, lean = 9, spread = 1.2, head = Vector3.new(0.9, 1.6, 0.9), headColor = Color3.fromRGB(190, 70, 35) },
}

local function brick(parent: Instance, size: Vector3, cf: CFrame, color: Color3, name: string, material: Enum.Material?): Part
	local part = PropKit.part({ size = size, cf = cf, color = color, parent = parent, collide = false, name = name, material = material })
	part.CanTouch = false
	part.CanQuery = false
	return part
end

-- A blade grows from its foot on the turf, turned by `yaw` and tipped outward by `lean`.
local function bladeFrame(s: Stalk): CFrame
	return CFrame.new(s.x, s.y + TURF_TOP - 0.1, s.z) * CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(math.rad(s.lean), 0, 0)
end

-- After the first hit the top is knocked off (Fx flings it) and a lighter fresh-cut top shows; the blade keeps
-- getting shorter with every hit.
local function layoutStalk(s: Stalk, ratio: number): Part?
	local h = math.max(0.4, s.baseH * (0.3 + 0.7 * ratio))
	local foot = bladeFrame(s)
	s.stem.Size = Vector3.new(s.stem.Size.X, h, s.stem.Size.Z)
	s.stem.CFrame = foot * CFrame.new(0, h / 2, 0)
	local knocked = nil
	if s.head then
		knocked = s.head
		s.head = nil
	end
	if not s.cap then
		s.cap = brick(s.stem.Parent :: Instance, Vector3.new(s.stem.Size.X + 0.02, 0.16, s.stem.Size.Z + 0.02), CFrame.new(), PropKit.shade(s.stem.Color, 1.5), "CutTop", Enum.Material.SmoothPlastic)
	end
	local cap = s.cap :: Part
	cap.CFrame = foot * CFrame.new(0, h + 0.07, 0)
	return knocked
end

local function stubble(p: Patch)
	for _, s in p.stalks do
		s.stem:Destroy()
		if s.head then
			s.head:Destroy()
		end
		if s.cap then
			s.cap:Destroy()
		end
	end
	table.clear(p.stalks)
	if p.model then
		p.model:Destroy()
		p.model = nil
	end
	if p.notch then
		p.notch:Destroy()
		p.notch = nil
	end
	local turf = p.part
	Lawn.mow(turf.Position, p.z) -- its ground is freshly mowed: striped lawn (server/Lawn)
	-- what's left, like a tree stump: the Blender stubble, or a low cut disc
	local def = Config.ZONES[p.z]
	local vid = voxelId(p.z)
	if vid then
		local _, yaw = p.spot:ToOrientation()
		local vstub = VoxelModels.place(turf.Parent :: Instance, "Stubble_" .. vid, p.stalkAt or p.spot.Position, { scale = p.modelScale, yaw = yaw, shadow = false })
		if vstub then
			p.stub = vstub
			for _, n in { "MutationGlow", "MutationSparkle" } do
				local e = turf:FindFirstChild(n)
				if e then
					e:Destroy()
				end
			end
			return
		end
	end
	local stub = Models.place(clumpName(p.z) .. "_cut", turf.Parent :: Instance, p.spot, p.modelScale, true)
	if stub and def.tint then
		paint(stub, PropKit.shade(def.tint, 0.8))
	end
	if not stub then
		local disc = PropKit.cylinder(turf.Parent :: Instance, 1.6 * p.modelScale, 0.4, p.spot * CFrame.new(0, 0.2, 0), PropKit.shade(def.grass[2], 0.8))
		disc.Name = "Stubble"
		disc.CanCollide = false
		disc.CanQuery = false
		disc.Material = Enum.Material.Grass
		p.stub = disc
	else
		p.stub = stub
	end
	local glow = turf:FindFirstChild("MutationGlow")
	if glow then
		glow:Destroy()
	end
	local sparkle = turf:FindFirstChild("MutationSparkle")
	if sparkle then
		sparkle:Destroy()
	end
end

local function spawnPatch(zoneFolder: Instance, z: number, col: number, row: number, alreadyCut: boolean, at: CFrame, size: number): Patch
	local def = Config.ZONES[z]
	local style = STYLES[def.style] or STYLES.lawn
	local pos = at.Position
	local colorA = def.grass[1]
	local colorB = def.grass[2]
	local model = Instance.new("Model")
	model.Name = "Patch"
	local turf = brick(model, Vector3.new(3, 1, 3), CFrame.new(pos.X, pos.Y + 0.5, pos.Z), colorB, "Spot")
	turf.Transparency = 1
	local p: Patch = {
		part = turf,
		holder = model,
		spot = CFrame.new(pos.X, pos.Y + TURF_TOP, pos.Z) * at.Rotation,
		stalks = {},
		z = z,
		col = col,
		row = row,
		hp = def.hp,
		maxHp = def.hp,
		mut = nil,
		cut = alreadyCut,
		baseColor = colorA,
		model = nil,
		modelScale = size,
		radius = 1.5 * size * 0.6,
		height = (def.height or 2) * size * 0.75,
	}
	local tuftName = clumpName(z)
	local vid = voxelId(z)
	if not alreadyCut and vid then
		-- the generated world's voxel clump (one mesh), scaled to the zone
		local holder = Instance.new("Model")
		holder.Name = "Clump"
		local _, yaw = at:ToOrientation()
		local mesh = VoxelModels.place(holder, "Clump_" .. vid .. "_" .. rng:NextInteger(1, 2), p.spot.Position, { scale = size, yaw = yaw })
		if mesh then
			local k = mesh.Size.Y / 7.2 -- the mesh's scale (a meadow clump's mesh is 7.2 studs tall)
			-- (28 Oct) the stalk isn't always in the middle of its mesh (the mesh is centred on its blades, which
			-- lean out unevenly): StalkOffset on the template says where it is, in voxels of the model's own frame
			-- (measured in Studio: wheat_1's stalk sits half a voxel to -X and a whole voxel to -Z). The clump's
			-- pivot, its collider, the hit prediction and the cut (client/ClumpWound) all go to the real stalk.
			local so = mesh:GetAttribute("StalkOffset")
			local stalkAt = p.spot.Position
			if typeof(so) == "Vector3" then
				stalkAt += CFrame.Angles(0, yaw, 0):VectorToWorldSpace(so * 0.4 * k)
			end
			p.stalkAt = stalkAt
			holder.WorldPivot = CFrame.new(stalkAt) * p.spot.Rotation -- falls over about its foot
			holder.Parent = model
			p.model = holder
			p.voxel = true
			p.height = mesh.Size.Y
			-- you chop it at its stalk, like a tree trunk (tools/blender/voxel stalk_clump: a 3 x 3 voxel stalk,
			-- 6 voxels tall, at 0.4 studs a voxel). A collider keeps you at the stalk; the reach is measured from
			-- its surface, so you have to walk right up to it.
			local stalkR = 0.6 * k
			p.stalk = stalkR
			p.radius = stalkR + 1.6
			local collider = brick(holder, Vector3.new(2.4 * k + 0.6, stalkR * 2, stalkR * 2), CFrame.new(stalkAt + Vector3.new(0, (2.4 * k + 0.6) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), "StalkCollider")
			collider.Shape = Enum.PartType.Cylinder
			collider.Transparency = 1
			collider.CanCollide = true
			collider.CanQuery = false
			collider.CanTouch = false
			collider.CastShadow = false
			holder:SetAttribute("Radius", p.radius)
			holder:SetAttribute("Height", p.height)
			holder:SetAttribute("Stalk", stalkR)
		else
			holder:Destroy()
		end
	end
	if not alreadyCut and not p.model and Models.has(tuftName) then
		p.model = Models.place(tuftName, model, p.spot, p.modelScale, true)
		if p.model then
			local _, bounds = p.model:GetBoundingBox()
			p.radius = math.max(bounds.X, bounds.Z) * 0.45
			p.height = bounds.Y
			p.model:SetAttribute("Radius", p.radius) -- the client's aim prediction reads these
			p.model:SetAttribute("Height", p.height)
			if def.tint then
				paint(p.model, def.tint)
			end
		end
	end
	if not alreadyCut and not p.model then
		-- a tuft: blades fanned out around the middle of the tile, alternating two greens with lighter tips
		local tilt = rng:NextNumber(0, math.pi * 2)
		for i = 1, style.count do
			local yaw = tilt + (i / style.count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local r = rng:NextNumber(0.2, 1.3) * style.spread * size * 0.6
			local x = pos.X + math.sin(yaw) * r
			local zz = pos.Z + math.cos(yaw) * r
			local baseH = def.height * style.height * rng:NextNumber(0.7, 1.25) * size * 0.75
			local color = PropKit.shade(if (i + col + row) % 2 == 0 then colorA else colorB, rng:NextNumber(0.93, 1.07))
			local stalk: Stalk = {
				stem = nil :: any,
				head = nil,
				cap = nil,
				baseH = baseH,
				headH = 0,
				x = x,
				y = pos.Y,
				z = zz,
				-- blades lean away from the middle of the tuft
				yaw = yaw,
				lean = style.lean * rng:NextNumber(0.6, 1.3),
			}
			local foot = bladeFrame(stalk)
			stalk.stem = brick(model, Vector3.new(style.width * rng:NextNumber(0.85, 1.15), baseH, style.thick) * Vector3.new(size * 0.6, 1, size * 0.6), foot * CFrame.new(0, baseH / 2, 0), color, "Blade", Enum.Material.Grass)
			if style.head then
				stalk.headH = style.head.Y
				stalk.head = brick(model, style.head, foot * CFrame.new(0, baseH + style.head.Y / 2 - 0.1, 0), style.headColor, "Head", Enum.Material.Fabric)
			end
			table.insert(p.stalks, stalk)
		end
	end
	-- (an area that was already cleared before this run started has no stubble left, like Chop A Forest's stumps)
	model.WorldPivot = p.spot -- falls over about its foot
	model.Parent = zoneFolder
	return p
end

local function spawnZone(z: number, alreadyCut: boolean)
	local zoneFolder = PropKit.folder("Grass" .. z, folder :: Folder)
	patches[z] = {}
	buckets[z] = {}
	local spots = spotsFor(z)
	Field.totals[z] = #spots
	Field.remaining[z] = if alreadyCut then 0 else #spots
	for i, spot in spots do
		local p = spawnPatch(zoneFolder, z, i, z, alreadyCut, spot.cf, spot.scale)
		patches[z][i] = p
		local pos = spot.cf.Position
		if alreadyCut then
			Lawn.mow(pos, z)
		end
		local key = cellKey(math.floor(pos.X / CELL), math.floor(pos.Z / CELL))
		local b = buckets[z][key]
		if not b then
			b = {}
			buckets[z][key] = b
		end
		table.insert(b, p)
		if i % 60 == 0 then
			task.wait() -- spread the big rings over a few frames
		end
	end
end

function Field.build(parent: Instance, startZone: number)
	Lawn.reset()
	table.clear(finishing)
	folder = PropKit.folder("Grass", parent)
	for z = 1, #Config.ZONES do
		spawnZone(z, z < startZone)
	end
	Field.unlocked = startZone
end

-- Patches near a point, nearest first. Only zones that are unlocked.
local function query(pos: Vector3, radius: number): { Patch }
	local found = {}
	local reach = radius + MAX_RADIUS
	local c0x, c1x = math.floor((pos.X - reach) / CELL), math.floor((pos.X + reach) / CELL)
	local c0z, c1z = math.floor((pos.Z - reach) / CELL), math.floor((pos.Z + reach) / CELL)
	for z = 1, Field.unlocked do
		local zb = buckets[z]
		if zb then
			for cx = c0x, c1x do
				for cz = c0z, c1z do
					local b = zb[cellKey(cx, cz)]
					if b then
						for _, p in b do
							if not p.cut then
								local pp = p.spot.Position
								local dx, dz = pp.X - pos.X, pp.Z - pos.Z
								-- count a patch if any part of it is inside the circle
								local d = math.sqrt(dx * dx + dz * dz) - p.radius
								if d <= radius then
									table.insert(found, { p = p, d = d })
								end
							end
						end
					end
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	local out = {}
	for i, f in found do
		out[i] = f.p
	end
	return out
end

local function reveal(p: Patch, luck: number, by: Player?)
	local mut = Config.rollMutation(rng, luck)
	-- a class can force one (the Ultimate Gardener's Midas Touch: server/ClassPerks)
	local forced = if Field.forceMutation then Field.forceMutation(by, mut) else nil
	if forced then
		mut = forced
		if by and Field.onForced then
			Field.onForced(by, p.part.Position)
		end
	end
	p.mut = mut
	if mut == "None" then
		return
	end
	local m = Config.mutation(mut)
	if p.model then
		paint(p.model, m.color, if mut == "Galaxy" or mut == "Toxic" then Enum.Material.Neon elseif mut == "Diamond" then Enum.Material.Glass else Enum.Material.SmoothPlastic)
	end
	for _, s in p.stalks do
		s.stem.Color = m.color
		s.stem.Material = if mut == "Diamond" then Enum.Material.Glass elseif mut == "Galaxy" or mut == "Toxic" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if s.head then
			s.head.Color = PropKit.shade(m.color, 0.8)
		end
	end
	local glow = Instance.new("PointLight")
	glow.Name = "MutationGlow"
	glow.Color = m.color
	glow.Range = 10
	glow.Brightness = 1.5
	glow.Parent = p.part
	local sparkle = Instance.new("ParticleEmitter") -- default texture is the engine's sparkle
	sparkle.Name = "MutationSparkle"
	sparkle.Color = ColorSequence.new(m.color)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(40, 40)
	sparkle.EmissionDirection = Enum.NormalId.Top
	sparkle.Parent = p.part
	p.part:SetAttribute("Mutation", mut)
	Net.all("Fx", "reveal", { pos = p.part.Position, mut = mut, by = by and by.UserId })
end

-- How tall a clump stands (studs), for where hits land and how far it falls.
local function clumpHeight(p: Patch): number
	return p.height
end

local function flatDir(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.05 then f.Unit else nil
end

-- The fresh cut in the clump's foot, on the side it's chopped from: wider and deeper with every hit, pale like
-- the inside of a cut stem (the notch in a Chop A Forest trunk).
local function notch(p: Patch, from: Vector3, ratio: number)
	local dir = p.notchDir or flatDir(from - p.spot.Position) or Vector3.zAxis
	p.notchDir = dir
	if p.stalk then
		return -- (28 Oct) a voxel clump's cut is carved in voxels by the cutter's client (client/ClumpWound)
	end
	local r, hgt = p.radius, p.height
	local cut = 1 - ratio
	if not p.notch then
		local m = Config.mutation(p.mut or "None")
		local grass = Config.ZONES[p.z].tint or Config.ZONES[p.z].grass[1]
		local fresh = PropKit.shade(m.color or grass, 1.3) -- the pale inside of the cut stems
		p.notch = brick(p.holder, Vector3.one, CFrame.new(), fresh, "Notch", Enum.Material.Grass)
	end
	local notchPart = p.notch :: BasePart
	local w = r * (0.35 + 0.45 * cut)
	local h = math.max(0.3, hgt * 0.045) * (1 + 0.6 * cut)
	local d = r * (0.15 + 0.4 * cut)
	-- on a stalk the cut sits at chest height, where your fist lands
	local lift = if p.stalk then math.min(hgt * 0.17, 2.8) else math.min(hgt * 0.14, 1.8)
	local at = p.spot.Position + Vector3.new(0, lift, 0) + dir * (r * 0.55 - d / 2)
	notchPart.Size = Vector3.new(w, h, d)
	notchPart.CFrame = CFrame.lookAt(at, at + dir)
end

local FALL_TIME = 0.7 -- seconds from the last hit until the clump hits the ground
Field.FALL_TIME = FALL_TIME

-- The last hit: the clump topples away from the cutter (every client animates it), then it's swapped for its
-- stubble. Its bundles land where its top falls (p.landPos), dropped by Run after FALL_TIME.
local function fell(p: Patch, player: Player, auto: boolean?)
	local dir = p.fallDir or Vector3.zAxis
	if p.notch then
		p.notch:Destroy()
		p.notch = nil
	end
	Net.all("Fx", "fell", {
		model = p.model or p.holder,
		pos = p.part.Position,
		dir = dir,
		land = p.landPos,
		height = clumpHeight(p),
		time = FALL_TIME,
		color = if p.voxel and Zones.list[p.z] then Zones.list[p.z].palette.grass[1] else p.baseColor,
		mut = p.mut,
		z = p.z,
		by = if auto then 0 else player.UserId, -- (an auto-finished leftover is nobody's own cut: no personal effects)
	})
	task.delay(FALL_TIME + 0.1, function()
		stubble(p)
	end)
end

-- (report #9, Config.AREA_FINISH.autoAt) Nobody should hunt the last 1% of an area: once it's that far mowed, the
-- clumps still standing go down by themselves. `player` (whose cut got it there) is paid for them through
-- Field.onAutoCut (server/Run: coins instead of bundles to walk to). Returns how many it mowed.
Field.onAutoCut = nil :: ((Player, Patch) -> ())?
function Field.finishLeftovers(z: number, player: Player): number
	if finishing[z] then
		return 0
	end
	finishing[z] = true
	local n = 0
	for _, p in patches[z] or {} do
		if not p.cut then
			p.hp = 0
			p.cut = true
			p.fallDir = p.spot.LookVector
			p.landPos = p.spot.Position + p.fallDir * math.max(2.5, clumpHeight(p) * 0.65)
			if p.notch then
				p.notch:Destroy()
				p.notch = nil
			end
			fell(p, player, true)
			Field.remaining[z] -= 1
			n += 1
			if Field.onAutoCut and player.Parent then
				Field.onAutoCut(player, p)
			end
		end
	end
	if n > 0 then
		if Field.onProgress then
			Field.onProgress()
		end
		if Field.remaining[z] <= 0 and Field.onZoneCleared then
			task.delay(FALL_TIME + 0.2, Field.onZoneCleared, z)
		end
	end
	return n
end

-- `from`: where the hit comes from (the cutter); the notch faces it and the clump falls away from it.
local function damagePatch(player: Player, p: Patch, amount: number, luck: number, from: Vector3): boolean
	if p.mut == nil then
		reveal(p, luck, player)
	end
	p.hp = math.max(0, p.hp - amount)
	if p.hp <= 0 then
		local away = p.notchDir and -p.notchDir or flatDir(p.spot.Position - from) or Vector3.zAxis
		p.fallDir = away
		p.landPos = p.spot.Position + away * math.max(2.5, clumpHeight(p) * 0.65)
		local ok = if Field.onCut then Field.onCut(player, p) else true
		if not ok then
			p.hp = math.max(1, p.maxHp * 0.02) -- bag full: stays nearly cut until you empty your bag
			return false
		end
		p.cut = true
		fell(p, player)
		Field.remaining[p.z] -= 1
		if Field.onProgress then
			Field.onProgress()
		end
		local left, total = Field.remaining[p.z], Field.totals[p.z] or 0
		if left <= 0 and Field.onZoneCleared then
			task.delay(FALL_TIME + 0.2, Field.onZoneCleared, p.z)
		elseif left > 0 and total > 0 and left <= math.floor(total * (1 - Config.AREA_FINISH.autoAt) + 1e-6) then
			-- (report #9) the last few go by themselves once the area is ~97% mowed
			task.delay(0.4, Field.finishLeftovers, p.z, player)
		end
	else
		local ratio = p.hp / p.maxHp
		notch(p, from, ratio)
		for _, s in p.stalks do
			local knocked = layoutStalk(s, 0.55 + 0.45 * ratio)
			if knocked then
				-- the top flies off (drawn by every client), then the server copy goes
				Net.all("Fx", "topOff", { pos = knocked.Position, size = knocked.Size, color = knocked.Color })
				knocked:Destroy()
			end
		end
		local first = p.stalks[1]
		local def = Config.ZONES[p.z]
		local h = clumpHeight(p)
		Net.send(player, "Fx", "chip", {
			pos = p.part.Position,
			hitPos = (p.stalkAt or p.spot.Position) + Vector3.new(0, math.min(h * 0.35, 4), 0),
			color = if first then first.stem.Color elseif p.voxel and Zones.list[p.z] then Zones.list[p.z].palette.grass[1] else p.baseColor, -- (28 Oct: a voxel clump's real colour)
			label = def.grassName,
			hp = p.hp,
			max = p.maxHp,
			model = p.model or p.holder,
			ratio = ratio,
			from = from,
			dealt = amount, -- (28 Oct) client/HitMeter shows the bite this hit took
			z = p.z, -- (28 Oct) client/ClumpWound tints the cut to the area's grass / the mutation
			mut = p.mut,
		})
	end
	return true
end

-- Hit up to `maxTargets` patches within `radius` of `pos`. Returns how many were hit.
function Field.hit(player: Player, pos: Vector3, radius: number, damage: number, maxTargets: number?, luck: number): number
	if Field.canCut and not Field.canCut(player) then
		return 0
	end
	local list = query(pos, radius)
	local n = 0
	for _, p in list do
		if maxTargets and n >= maxTargets then
			break
		end
		if not damagePatch(player, p, damage, luck, pos) then
			break -- bag full; stop for this hit
		end
		n += 1
	end
	return n
end

-- A hand-tool swing: chop the clump the player is looking at (like aiming an axe at a tree), within `reach` studs
-- of them. `look` is their camera's look direction. Wide tools (`maxTargets` > 1) also catch the clumps nearest
-- to the aimed one that are in front of the player. Returns how many were hit.
function Field.hitAim(player: Player, rootPos: Vector3, look: Vector3, reach: number, damage: number, maxTargets: number?, luck: number): number
	if Field.canCut and not Field.canCut(player) then
		return 0
	end
	local eye = rootPos + Vector3.new(0, 1.5, 0)
	local list = query(rootPos, reach)
	local best, bestScore = nil, math.huge
	for _, p in list do
		local mid = (p.stalkAt or p.spot.Position) + Vector3.new(0, math.min(p.height * 0.4, 5), 0)
		local to = mid - eye
		local d = math.max(to.Magnitude, 0.1)
		local angle = math.acos(math.clamp(to:Dot(look) / d, -1, 1))
		-- a big clump up close fills more of the view, so it counts over a wider angle
		local score = angle - math.atan2(math.max(p.radius, p.height * 0.35), d)
		if score < bestScore then
			best, bestScore = p, score
		end
	end
	if not best or bestScore > math.rad(14) then
		return 0
	end
	if not damagePatch(player, best, damage, luck, rootPos) then
		return 0
	end
	local n = 1
	local limit = maxTargets or 1
	if limit > 1 then
		local flatLook = flatDir(look) or Vector3.zAxis
		local others = {}
		for _, p in list do
			local to = flatDir(p.spot.Position - rootPos)
			if p ~= best and not p.cut and to and to:Dot(flatLook) > 0.35 then
				table.insert(others, { p = p, d = (p.spot.Position - best.spot.Position).Magnitude })
			end
		end
		table.sort(others, function(a, b)
			return a.d < b.d
		end)
		for _, o in others do
			if n >= limit then
				break
			end
			if not damagePatch(player, o.p, damage, luck, rootPos) then
				break
			end
			n += 1
		end
	end
	return n
end

-- Area z is cleared: its stubble goes in a puff, one after another (like the stumps in Chop A Forest).
function Field.clearStubble(z: number)
	local list = patches[z]
	if not list then
		return
	end
	local stubs = {}
	for _, p in list do
		if p.stub then
			table.insert(stubs, p)
		end
	end
	task.spawn(function()
		-- the whole area's lawn mowed: fill the gaps between the clumps' patches so it's all stripes
		for i, p in list do
			Lawn.mow(p.part.Position, z, 11)
			if i % 10 == 0 then
				task.wait()
			end
		end
	end)
	task.spawn(function()
		for i, p in stubs do
			local stub = p.stub
			p.stub = nil
			if stub then
				Net.all("Fx", "poof", { pos = p.part.Position, scale = p.modelScale })
				stub:Destroy()
			end
			if i % 6 == 0 then
				task.wait(0.03)
			end
		end
	end)
end

-- Studio helper: cut every clump left in area z at once (no loot, no effects).
function Field.devClear(player: Player, z: number)
	for _, p in patches[z] or {} do
		if not p.cut then
			p.hp = 0
			p.fallDir = Vector3.zAxis
			p.landPos = p.spot.Position
			if not Field.onCut or Field.onCut(player, p) then
				p.cut = true
				stubble(p)
				Field.remaining[z] -= 1
			end
		end
	end
	if Field.onProgress then
		Field.onProgress()
	end
	if Field.remaining[z] <= 0 and Field.onZoneCleared then
		Field.onZoneCleared(z)
	end
end

-- Up to `n` hiding places in area z for the Golden Gnome hunt (server/Gnomes): at the foot of random clumps, tucked
-- under their blades just outside the stalk, facing out, and at least `apart` studs from each other when the area
-- has room. Each is a CFrame on the ground.
function Field.hideSpots(z: number, n: number, apart: number?): { CFrame }
	local list = patches[z]
	local out: { CFrame } = {}
	if not list or #list == 0 then
		return out
	end
	local order = {}
	for i = 1, #list do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local gap = apart or 40
	for pass = 1, 2 do
		for _, i in order do
			if #out >= n then
				return out
			end
			local p = list[i]
			local base = p.spot.Position
			local ok = true
			for _, cf in out do
				if (cf.Position - base).Magnitude < (if pass == 1 then gap else 6) then
					ok = false
					break
				end
			end
			if ok then
				local a = rng:NextNumber(0, math.pi * 2)
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local r = (p.stalk or p.radius * 0.35) + 1.4
				local pos = base + dir * r
				table.insert(out, CFrame.lookAt(pos, pos + dir))
			end
		end
	end
	return out
end

function Field.unlock(z: number)
	Field.unlocked = math.max(Field.unlocked, z)
end

function Field.remainingIn(z: number): number
	return Field.remaining[z] or 0
end

return Field
