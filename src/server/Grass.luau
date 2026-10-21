-- The grass: waist-high clusters of brick sticks growing inside each zone's patches (World.Patches, made by
-- server/WorldGen). Tools cut every cluster in front of you, auto tools and mowers cut everything around them.
-- A cluster takes several hits in tougher zones (its sticks get shorter with each one); at 0 HP it's cut down to
-- stubble and drops its bundles (server/Run), then pops back after REGROW seconds. Rare clusters glow.
--
-- Same API as the old server/Field, so server/Run uses either.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local Net = require(script.Parent.Net)

local Grass = {}

export type Cluster = {
	model: Model,
	part: BasePart, -- the first stick (effects position)
	spot: CFrame, -- where it stands (on the ground)
	sticks: { { part: Part, h: number, w: number, off: Vector3, yaw: number, tilt: number } },
	z: number,
	hp: number,
	maxHp: number,
	mut: string, -- the mutation ("None" = normal), rolled when it (re)grows
	cut: boolean,
	landPos: Vector3,
	radius: number,
	height: number,
}

local SPACING = 7.5 -- studs between clusters inside a patch
local CELL = 24 -- hit-test grid
local REGROW = { 22, 34 } -- seconds before a cut cluster pops back
local STUB = 0.5 -- stubble height

Grass.FALL_TIME = 0.12 -- bundles drop this long after the cut (Run reads it)
Grass.unlocked = 1
Grass.remaining = {} :: { [number]: number }
Grass.totals = {} :: { [number]: number }

-- Hooks the game sets up.
Grass.onCut = nil :: ((Player, Cluster) -> boolean)? -- false = refuse (bag full)
Grass.canCut = nil :: ((Player) -> boolean)?
Grass.canCutZone = nil :: ((Player, number) -> boolean)? -- the player owns zone z
Grass.onZoneCleared = nil :: ((number) -> ())?
Grass.onProgress = nil :: (() -> ())?

local all: { Cluster } = {}
local buckets: { [number]: { Cluster } } = {}
local folder: Folder? = nil
local rng = Random.new()

local function key(x: number, z: number): number
	return (math.floor(x / CELL) + 1000) * 4096 + (math.floor(z / CELL) + 1000)
end

local function query(pos: Vector3, radius: number): { Cluster }
	local out = {}
	local r = radius + 3
	for cx = math.floor((pos.X - r) / CELL), math.floor((pos.X + r) / CELL) do
		for cz = math.floor((pos.Z - r) / CELL), math.floor((pos.Z + r) / CELL) do
			local list = buckets[(cx + 1000) * 4096 + (cz + 1000)]
			if list then
				for _, c in list do
					if not c.cut then
						local d = Vector3.new(c.spot.X - pos.X, 0, c.spot.Z - pos.Z).Magnitude
						if d <= radius + c.radius then
							table.insert(out, c)
						end
					end
				end
			end
		end
	end
	return out
end

-- Grass shape per zone: stick height range and width (wheat is tall and thin, frost short and chunky...).
local SHAPES = {
	meadow = { h = { 3.2, 5.2 }, w = { 0.9, 1.2 }, n = 4 },
	wheat = { h = { 5, 7.5 }, w = { 0.6, 0.9 }, n = 5 },
	blossom = { h = { 3, 4.8 }, w = { 0.9, 1.3 }, n = 4 },
	pine = { h = { 3.5, 6 }, w = { 0.8, 1.1 }, n = 4 },
	swamp = { h = { 5, 8 }, w = { 0.6, 0.9 }, n = 4 },
	frost = { h = { 2.5, 4.5 }, w = { 1.2, 1.8 }, n = 3 },
	ember = { h = { 3, 5 }, w = { 0.9, 1.2 }, n = 4 },
	isles = { h = { 3.5, 6 }, w = { 1, 1.4 }, n = 3 },
}

-- Place the sticks of a cluster at `scale` of their full height (0..1), with the right colours.
local function layout(c: Cluster, scale: number)
	local def = Zones.list[c.z]
	local pal = def.palette
	local mut = if c.mut ~= "None" then Config.mutation(c.mut) else nil
	for i, s in c.sticks do
		local h = math.max(STUB, s.h * scale)
		s.part.Size = Vector3.new(s.w, h, s.w)
		s.part.CFrame = c.spot * CFrame.new(s.off) * CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(s.tilt, 0, 0) * CFrame.new(0, h / 2, 0)
		if mut and not c.cut then
			s.part.Color = mut.color or pal.rare
			s.part.Material = Enum.Material.Neon
		else
			s.part.Color = pal.grass[(i - 1) % #pal.grass + 1]
			s.part.Material = Enum.Material.Plastic
		end
	end
end

local function grow(c: Cluster)
	c.cut = false
	c.hp = c.maxHp
	-- rare grass: rolled when it grows, so players can spot it from afar
	c.mut = Config.rollMutation(rng, 1)
	layout(c, 1)
	c.model:SetAttribute("Cut", false)
	c.model:SetAttribute("Mut", if c.mut ~= "None" then c.mut else nil)
end

local function makeCluster(parent: Instance, z: number, at: Vector3, r: Random): Cluster
	local def = Zones.list[z]
	local shape = SHAPES[def.id] or SHAPES.meadow
	local cfg = Config.ZONES[z]
	local model = Instance.new("Model")
	model.Name = "Tuft"
	model:SetAttribute("Zone", z)
	local c: Cluster = {
		model = model,
		part = nil :: any,
		spot = CFrame.new(at) * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0),
		sticks = {},
		z = z,
		hp = cfg and cfg.hp or 1,
		maxHp = cfg and cfg.hp or 1,
		mut = "None",
		cut = false,
		landPos = at,
		radius = 2.2,
		height = shape.h[2],
	}
	for i = 1, shape.n do
		local p = Instance.new("Part")
		p.Name = "Stick"
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		local ang = (i - 1) / shape.n * math.pi * 2 + r:NextNumber(-0.4, 0.4)
		local dist = if i == 1 then 0 else r:NextNumber(0.7, 1.5)
		table.insert(c.sticks, {
			part = p,
			h = r:NextNumber(shape.h[1], shape.h[2]),
			w = r:NextNumber(shape.w[1], shape.w[2]),
			off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist),
			yaw = r:NextNumber(0, math.pi / 2),
			tilt = r:NextNumber(-0.12, 0.12),
		})
	end
	c.part = c.sticks[1].part
	model.PrimaryPart = c.part
	grow(c)
	model.Parent = parent
	return c
end

-- The ground height under (x, z): the top of the highest floor block (a ray down onto World.Ground).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(x: number, z: number, near: number): number?
	local hit = workspace:Raycast(Vector3.new(x, near + 40, z), Vector3.new(0, -90, 0), rayParams)
	return hit and hit.Position.Y
end

-- Spawn clusters inside every patch of the map.
function Grass.build(world: Instance, _startZone: number?)
	if folder then
		folder:Destroy()
	end
	table.clear(all)
	table.clear(buckets)
	local f = Instance.new("Folder")
	f.Name = "Grass"
	folder = f
	local ground = world:FindFirstChild("Ground")
	rayParams.FilterDescendantsInstances = { ground or world }
	local patches = world:FindFirstChild("Patches")
	local r = Random.new(20261021)
	for z = 1, #Zones.list do
		Grass.remaining[z] = 0
		Grass.totals[z] = 0
	end
	local zoneFolders: { [number]: Folder } = {}
	for _, zf in (patches and patches:GetChildren() or {}) do
		for _, disc in zf:GetChildren() do
			local z = disc:GetAttribute("Zone")
			if disc:IsA("BasePart") and type(z) == "number" and Zones.list[z] then
				local zfolder = zoneFolders[z]
				if not zfolder then
					zfolder = Instance.new("Folder")
					zfolder.Name = "Zone" .. z
					zfolder.Parent = f
					zoneFolders[z] = zfolder
				end
				-- a jittered grid inside the disc (radius = half its Y/Z size)
				local radius = disc.Size.Y / 2
				local centre = disc.Position
				for gx = -radius, radius, SPACING do
					for gz = -radius, radius, SPACING do
						local x = centre.X + gx + r:NextNumber(-2.2, 2.2)
						local zz = centre.Z + gz + r:NextNumber(-2.2, 2.2)
						if Vector2.new(x - centre.X, zz - centre.Z).Magnitude <= radius - 1 then
							-- skip spots another disc of the same patch already filled
							local k = key(x, zz)
							local crowded = false
							for _, o in (buckets[k] or {}) do
								if Vector2.new(o.spot.X - x, o.spot.Z - zz).Magnitude < SPACING * 0.75 then
									crowded = true
									break
								end
							end
							local y = if crowded then nil else groundAt(x, zz, centre.Y)
							if y and math.abs(y - centre.Y) < 14 then
								local c = makeCluster(zfolder, z, Vector3.new(x, y, zz), r)
								table.insert(all, c)
								buckets[k] = buckets[k] or {}
								table.insert(buckets[k], c)
								Grass.totals[z] += 1
								Grass.remaining[z] += 1
							end
						end
					end
				end
			end
		end
		task.wait()
	end
	f.Parent = world
	return f
end

local function regrowLater(c: Cluster)
	task.delay(rng:NextNumber(REGROW[1], REGROW[2]), function()
		if not c.model.Parent then
			return
		end
		grow(c)
		Grass.remaining[c.z] += 1
		Net.all("Fx", "regrow", { model = c.model, pos = c.spot.Position, z = c.z })
		if Grass.onProgress then
			Grass.onProgress()
		end
	end)
end

local function damage(player: Player, c: Cluster, amount: number, _luck: number, from: Vector3): boolean
	c.hp = math.max(0, c.hp - amount)
	if c.hp <= 0 then
		c.landPos = c.spot.Position + Vector3.new(0, 0.5, 0)
		local ok = if Grass.onCut then Grass.onCut(player, c) else true
		if not ok then
			c.hp = math.max(1, c.maxHp * 0.02)
			return false
		end
		c.cut = true
		local def = Zones.list[c.z]
		Net.all("Fx", "mow", {
			pos = c.spot.Position + Vector3.new(0, 1.5, 0),
			colors = def.palette.grass,
			rare = c.mut ~= "None",
			rareColor = def.palette.rare,
			z = c.z,
			by = player.UserId,
		})
		layout(c, 0)
		c.model:SetAttribute("Cut", true)
		Grass.remaining[c.z] -= 1
		regrowLater(c)
		if Grass.onProgress then
			Grass.onProgress()
		end
	else
		layout(c, 0.35 + 0.65 * c.hp / c.maxHp)
		Net.send(player, "Fx", "chip", {
			pos = c.spot.Position,
			hitPos = c.spot.Position + Vector3.new(0, 2, 0),
			color = c.part.Color,
			label = Config.ZONES[c.z] and Config.ZONES[c.z].grassName or "",
			hp = c.hp,
			max = c.maxHp,
			model = c.model,
			ratio = c.hp / c.maxHp,
			from = from,
		})
	end
	return true
end

local function allowed(player: Player, c: Cluster): boolean
	if Grass.canCutZone then
		return Grass.canCutZone(player, c.z)
	end
	return c.z <= Grass.unlocked
end

-- Hit up to `maxTargets` clusters within `radius` of `pos` (auto tools, mowers). Returns how many were hit.
function Grass.hit(player: Player, pos: Vector3, radius: number, amount: number, maxTargets: number?, luck: number): number
	if Grass.canCut and not Grass.canCut(player) then
		return 0
	end
	local n = 0
	for _, c in query(pos, radius) do
		if maxTargets and n >= maxTargets then
			break
		end
		if allowed(player, c) then
			if not damage(player, c, amount, luck, pos) then
				break
			end
			n += 1
		end
	end
	return n
end

-- A swing: everything in a wide arc in front of the player, within `reach`, nearest first (at least 1 target).
function Grass.hitAim(player: Player, rootPos: Vector3, look: Vector3, reach: number, amount: number, maxTargets: number?, luck: number): number
	if Grass.canCut and not Grass.canCut(player) then
		return 0
	end
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.zAxis
	local list = {}
	for _, c in query(rootPos, reach) do
		local to = Vector3.new(c.spot.X - rootPos.X, 0, c.spot.Z - rootPos.Z)
		local d = to.Magnitude
		if allowed(player, c) and (d < 3 or to.Unit:Dot(flatLook) > 0.25) then
			table.insert(list, { c = c, d = d })
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	local n = 0
	local cap = math.max(1, maxTargets or 1)
	for _, e in list do
		if n >= cap then
			break
		end
		if not damage(player, e.c, amount, luck, rootPos) then
			break
		end
		n += 1
	end
	return n
end

function Grass.totalIn(z: number): number
	return Grass.totals[z] or 0
end

function Grass.remainingIn(z: number): number
	return Grass.remaining[z] or 0
end

-- Zones never "clear" in the open world: grass regrows. Kept for the old callers.
function Grass.unlock(z: number)
	Grass.unlocked = math.max(Grass.unlocked, z)
end
function Grass.clearStubble(_z: number) end

-- Dev panel: cut everything in zone z (no bundles).
function Grass.devClear(player: Player, z: number)
	local hook = Grass.onCut
	Grass.onCut = function()
		return true
	end
	for _, c in all do
		if c.z == z and not c.cut then
			damage(player, c, math.huge, 1, c.spot.Position)
		end
	end
	Grass.onCut = hook
end

return Grass
