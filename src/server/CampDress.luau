-- The area camps (owner, 29 Oct 19:28: "remake every zone hub except 1 to make it a bit bigger and idk just make it
-- feel more alive and not so boring if ur going to add or make stuff use blender"; 21:13, about the first go: "its
-- very messy and just cluttered fix it and remove unneccerary stuff"). server/Outposts lays the paved plaza (24 studs
-- round the drop-off pad, on the flat clearing shared/WorldPlan keeps round every pad), the SHOP and UPGRADES stalls,
-- the gas pump and two benches. This adds only a few pieces, each one checked to stand on the paving or, round the
-- plaza, on open ground (off the paths, clear of the boss arena and of everything else):
--   * on the plaza: an entrance arch with the camp's name and four lamp posts;
--   * round it: a house (smoke from its chimney), the area's own landmark and its animals. Golden Wheat Hills: a
--     windmill, chickens in a pen; Blossom Garden: a pavilion with paper lanterns, koi in a pond; Misty Pine Forest: a
--     watchtower with a flag, owls; Bubble Swamp: the house on stilts, a pond with a jetty, a rowing boat and frogs;
--     Frost Peaks: an igloo and a snowman, penguins; Ember Ash Fields: a forge with bellows, salamanders; Starlight
--     Isles: a telescope, wisps;
--   * three gnome villagers: one by the stalls, one walking round the plaza, one at work by the landmark.
-- Models: server/CampProps (made in Blender: tools/blender/camp). What moves is tagged for client/CampLife, which
-- animates it near you. Each camp prints what it placed: "[CampDress] wheat camp: arch, 4 lamps, house@-125+0 ...".
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local FxIds = require(ReplicatedStorage.MowALawn.FxIds) :: { [string]: string }
local CampProps = require(script.Parent.CampProps)
local VoxelKit = require(script.Parent.VoxelKit)

local CampDress = {}

CampDress.RADIUS = 42 -- the whole camp: no grass grows inside (World attribute HubR<z>, RunWorld.patches)

local part = VoxelKit.part
local C = VoxelKit.C
local UP = Vector3.yAxis

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-------------------------------------------------------------------------------------------------------------
-- each area's colours for the models' "@roles" (server/CampProps): { material or nil, colour }; false = left out
-------------------------------------------------------------------------------------------------------------
local BASE_ROLES = {
	trim = { nil, rgb(236, 228, 214) },
	roof = { "VRoof", rgb(110, 74, 56) },
	roof2 = { "VRoof", rgb(86, 56, 42) },
	base = { nil, rgb(230, 222, 205) },
	stone = { nil, rgb(200, 196, 188) },
	door = { nil, rgb(120, 70, 40) },
	glass = { "Glass", rgb(190, 220, 240) },
	board = { nil, rgb(196, 140, 88) },
	wood = { nil, rgb(176, 124, 78) },
	skin = { nil, rgb(255, 204, 170) },
	beard = { nil, rgb(244, 240, 232) },
	tower = { "Plaster", rgb(244, 238, 226) },
	post = { nil, rgb(200, 50, 60) },
	sail = { nil, rgb(246, 240, 226) },
	water = { nil, rgb(70, 150, 200) },
	scope = { nil, rgb(44, 48, 96) },
	snowcap = false,
}
local AREA_ROLES: { [string]: { [string]: any } } = {
	wheat = {
		wall = { "WoodPlanks", rgb(178, 62, 48) }, cloth = { nil, rgb(226, 128, 44) }, accent = { nil, rgb(250, 206, 60) },
		goods1 = { nil, rgb(232, 196, 90) }, goods2 = { nil, rgb(236, 128, 34) }, flower = { nil, rgb(250, 200, 60) },
		coat = { nil, rgb(200, 64, 52) }, pants = { nil, rgb(64, 96, 166) }, hat = { nil, rgb(226, 190, 110) },
	},
	blossom = {
		wall = { "Plaster", rgb(248, 242, 238) }, trim = { nil, rgb(150, 92, 76) }, roof = { "ClayRoofTiles", rgb(226, 112, 152) },
		roof2 = { "ClayRoofTiles", rgb(190, 84, 120) }, base = { nil, rgb(236, 220, 216) }, door = { nil, rgb(176, 70, 92) },
		glass = { "Glass", rgb(255, 222, 236) }, cloth = { nil, rgb(240, 120, 170) }, accent = { nil, rgb(255, 250, 250) },
		goods1 = { nil, rgb(255, 150, 200) }, goods2 = { nil, rgb(255, 250, 244) }, flower = { nil, rgb(255, 140, 190) },
		coat = { nil, rgb(236, 136, 178) }, pants = { nil, rgb(120, 80, 110) }, hat = { nil, rgb(232, 210, 150) },
		board = { nil, rgb(150, 92, 76) },
	},
	pine = {
		wall = { "VLog", rgb(170, 132, 104) }, trim = { nil, rgb(92, 66, 48) }, roof = { "VRoof", rgb(74, 112, 74) },
		roof2 = { "VRoof", rgb(56, 88, 58) }, base = { nil, rgb(196, 198, 192) }, door = { nil, rgb(96, 64, 44) },
		glass = { "Neon", rgb(255, 214, 150) }, cloth = { nil, rgb(64, 124, 84) }, accent = { nil, rgb(200, 64, 52) },
		goods1 = { nil, rgb(150, 105, 70) }, goods2 = { nil, rgb(96, 146, 76) }, flower = { nil, rgb(186, 130, 226) },
		coat = { nil, rgb(190, 54, 44) }, pants = { nil, rgb(76, 64, 54) }, hat = { nil, rgb(190, 54, 44) },
		beard = { nil, rgb(132, 88, 56) }, wood = { nil, rgb(150, 110, 80) },
	},
	swamp = {
		wall = { "WoodPlanks", rgb(130, 112, 82) }, trim = { nil, rgb(82, 66, 48) }, roof = { "Fabric", rgb(160, 140, 80) },
		roof2 = { "Fabric", rgb(130, 112, 62) }, base = { nil, rgb(146, 146, 126) }, stone = { nil, rgb(150, 150, 130) },
		door = { nil, rgb(92, 72, 52) }, glass = { "Neon", rgb(196, 255, 150) }, cloth = { nil, rgb(112, 142, 62) },
		accent = { nil, rgb(176, 255, 146) }, board = { nil, rgb(112, 92, 62) }, goods1 = { nil, rgb(204, 64, 64) },
		goods2 = { nil, rgb(152, 92, 204) }, flower = { nil, rgb(190, 120, 255) }, coat = { nil, rgb(240, 200, 44) },
		pants = { nil, rgb(64, 84, 64) }, hat = { nil, rgb(240, 200, 44) }, beard = { nil, rgb(206, 206, 196) },
		wood = { nil, rgb(132, 104, 74) }, water = { nil, rgb(74, 110, 80) },
	},
	frost = {
		wall = { "VLog", rgb(232, 216, 192) }, trim = { nil, rgb(104, 74, 54) }, roof = { "VRoof", rgb(94, 106, 128) },
		roof2 = { "VRoof", rgb(74, 84, 104) }, base = { nil, rgb(214, 226, 240) }, stone = { nil, rgb(206, 218, 232) },
		door = { nil, rgb(72, 112, 172) }, glass = { "Neon", rgb(255, 222, 156) }, cloth = { nil, rgb(72, 132, 212) },
		accent = { nil, rgb(255, 255, 255) }, board = { nil, rgb(124, 92, 72) }, goods1 = { "Ice", rgb(170, 220, 255) },
		goods2 = { nil, rgb(240, 245, 250) }, flower = { nil, rgb(150, 200, 255) }, coat = { nil, rgb(62, 112, 192) },
		pants = { nil, rgb(52, 62, 84) }, hat = { nil, rgb(232, 232, 242) }, snowcap = { "Snow", rgb(246, 250, 255) },
		water = { nil, rgb(120, 180, 230) },
	},
	ember = {
		wall = { "VStone", rgb(118, 106, 104) }, trim = { nil, rgb(64, 44, 34) }, roof = { "VMetal", rgb(96, 86, 86) },
		roof2 = { "VMetal", rgb(70, 62, 62) }, base = { "Basalt", rgb(78, 70, 72) }, stone = { nil, rgb(110, 100, 100) },
		door = { nil, rgb(112, 52, 32) }, glass = { "Neon", rgb(255, 150, 70) }, cloth = { nil, rgb(204, 72, 42) },
		accent = { nil, rgb(255, 156, 72) }, board = { nil, rgb(92, 62, 42) }, goods1 = { "Neon", rgb(255, 122, 42) },
		goods2 = { nil, rgb(82, 78, 80) }, flower = { "Neon", rgb(255, 102, 42) }, coat = { nil, rgb(122, 72, 42) },
		pants = { nil, rgb(62, 52, 52) }, hat = { nil, rgb(64, 54, 54) }, beard = { nil, rgb(92, 62, 42) },
		wood = { nil, rgb(120, 90, 66) }, water = { nil, rgb(60, 96, 120) },
	},
	isles = {
		wall = { "Plaster", rgb(222, 212, 250) }, trim = { nil, rgb(232, 192, 92) }, roof = { "ClayRoofTiles", rgb(84, 64, 166) },
		roof2 = { "ClayRoofTiles", rgb(64, 48, 132) }, base = { nil, rgb(184, 174, 224) }, stone = { nil, rgb(170, 160, 214) },
		door = { nil, rgb(92, 62, 152) }, glass = { "Neon", rgb(150, 230, 255) }, cloth = { nil, rgb(112, 82, 222) },
		accent = { nil, rgb(255, 222, 122) }, board = { nil, rgb(92, 72, 142) }, goods1 = { "Neon", rgb(150, 230, 255) },
		goods2 = { nil, rgb(202, 162, 255) }, flower = { "Neon", rgb(150, 230, 255) }, coat = { nil, rgb(72, 52, 152) },
		pants = { nil, rgb(52, 42, 92) }, hat = { nil, rgb(72, 52, 152) }, scope = { nil, rgb(52, 46, 120) },
	},
}

local function rolesFor(id: string): { [string]: any }
	local r = table.clone(BASE_ROLES)
	for k, v in AREA_ROLES[id] or AREA_ROLES.wheat do
		r[k] = v
	end
	return r
end

-- a few villagers' outfits per area (coat, pants, hat): the first is the area's own
local OUTFITS: { [string]: { { Color3 } } } = {
	wheat = { { rgb(84, 140, 196), rgb(150, 110, 70), rgb(226, 190, 110) }, { rgb(236, 220, 160), rgb(64, 96, 166), rgb(200, 64, 52) } },
	blossom = { { rgb(255, 250, 244), rgb(176, 70, 92), rgb(240, 120, 170) }, { rgb(150, 200, 120), rgb(120, 80, 110), rgb(255, 196, 220) } },
	pine = { { rgb(64, 124, 84), rgb(76, 64, 54), rgb(236, 220, 160) }, { rgb(150, 110, 80), rgb(64, 84, 64), rgb(64, 124, 84) } },
	swamp = { { rgb(112, 142, 62), rgb(92, 72, 52), rgb(152, 92, 204) }, { rgb(204, 64, 64), rgb(64, 84, 64), rgb(240, 200, 44) } },
	frost = { { rgb(204, 64, 64), rgb(52, 62, 84), rgb(244, 244, 250) }, { rgb(240, 200, 44), rgb(72, 112, 172), rgb(62, 112, 192) } },
	ember = { { rgb(82, 78, 80), rgb(122, 72, 42), rgb(204, 72, 42) }, { rgb(204, 72, 42), rgb(62, 52, 52), rgb(255, 156, 72) } },
	isles = { { rgb(112, 82, 222), rgb(52, 42, 92), rgb(232, 192, 92) }, { rgb(150, 230, 255), rgb(72, 52, 152), rgb(112, 82, 222) } },
}

-------------------------------------------------------------------------------------------------------------
-- the camp's frame and the ground round it
-------------------------------------------------------------------------------------------------------------
type Box = { cf: CFrame, hx: number, hz: number }
type Disc = { at: Vector2, r: number }

export type Ctx = {
	w: Instance, -- the run's World
	f: Model, -- the camp's model (World.Outpost<z>)
	z: number,
	base: Vector3, -- the plaza's middle, at its top
	top: number,
	fwd: Vector3, -- toward the area's middle
	right: Vector3,
	R: number, -- the plaza's radius
	rng: Random,
	info: any,
	lanternPost: ((Instance, Vector3, Vector3) -> ())?,
	glow: Color3?, -- the area's lantern glass
	-- filled in here
	id: string?,
	roles: any,
	ground: RaycastParams?,
	blocked: { Box }?, -- round the plaza: paths, water, gates, bridges, landmarks
	circles: { Disc }?, -- round the plaza: the plaza itself, the boss arena and its ramp
	overlap: OverlapParams?,
	taken: { Disc }?, -- round the plaza: what this has built
	obstacles: { Box }?, -- on the plaza: the stalls, the pump, the benches, the pad
	plazaTaken: { Disc }?, -- on the plaza: what this has built
	paveRay: RaycastParams?,
	placed: { string }?, -- for the Output
}

local function dirAt(ctx: Ctx, deg: number): Vector3
	local a = math.rad(deg)
	return ctx.fwd * math.cos(a) + ctx.right * math.sin(a)
end

local function groundAt(ctx: Ctx, x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, ctx.top + 40, z), Vector3.new(0, -90, 0), ctx.ground)
	return if hit then hit.Position.Y else nil
end

-- flat ground cover in World.Visuals (path tiles, the 8 x 8 grass squares, flowers): never cleared away
local function isFlat(d: Instance): boolean
	return d:IsA("BasePart") and d.Size.Y <= 0.6 and math.max(d.Size.X, d.Size.Z) <= 8
end

-- a path tile (WorldArt's 3.1 x 0.3 x 3.1 paving): built round, never on
local function isPath(d: Instance): boolean
	return d:IsA("BasePart") and math.abs(d.Size.Y - 0.3) < 0.05 and math.abs(d.Size.X - 3.1) < 0.05 and math.abs(d.Size.Z - 3.1) < 0.05
end

-- A box's footprint on the ground (its most upright axis is its height: a disc lying on its side, a stall).
local function footprint(cf: CFrame, size: Vector3): Box
	local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local half = { size.X / 2, size.Y / 2, size.Z / 2 }
	local up = 1
	for i = 2, 3 do
		if math.abs(axes[i].Y) > math.abs(axes[up].Y) then
			up = i
		end
	end
	local a = if up == 1 then 2 else 1
	local b = if up == 3 then 2 else 3
	local u = Vector3.new(axes[a].X, 0, axes[a].Z)
	u = if u.Magnitude > 1e-3 then u.Unit else Vector3.xAxis
	return { cf = CFrame.fromMatrix(cf.Position, u, UP), hx = half[a], hz = half[b] }
end

local function outside(b: Box, p: Vector3, r: number): boolean
	local lp = b.cf:PointToObjectSpace(Vector3.new(p.X, b.cf.Position.Y, p.Z))
	local dx, dz = math.max(0, math.abs(lp.X) - b.hx), math.max(0, math.abs(lp.Z) - b.hz)
	return dx * dx + dz * dz >= r * r
end

-- What a building round the plaza mustn't stand on.
local function collectBlocked(ctx: Ctx)
	local list: { Box } = {}
	local c = Vector2.new(ctx.base.X, ctx.base.Z)
	local function add(cf: CFrame, size: Vector3)
		if (Vector2.new(cf.Position.X, cf.Position.Z) - c).Magnitude < 90 + math.max(size.X, size.Z) / 2 then
			table.insert(list, footprint(cf, size))
		end
	end
	for _, name in { "Ways", "Hazards", "Liquid", "Gates", "Bounds", "IsleBridges" } do
		local fold = ctx.w:FindFirstChild(name)
		for _, d in (if fold then fold:GetDescendants() else {}) do
			if d:IsA("BasePart") then
				add(d.CFrame, d.Size)
			end
		end
	end
	-- the paths (tiles in World.Visuals) and the areas' landmarks
	local visuals = ctx.w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			if isPath(d) then
				add((d :: BasePart).CFrame, (d :: BasePart).Size)
			elseif string.find(d.Name, "Landmark", 1, true) then
				if d:IsA("Model") then
					local cf, size = d:GetBoundingBox()
					add(cf, size)
				elseif d:IsA("BasePart") then
					add(d.CFrame, d.Size)
				end
			end
		end
	end
	ctx.blocked = list
	-- the plaza with its edge, and this area's boss arena with the ramp up to its gate (server/BossArena builds it
	-- after the camps, from Config.BOSS_ARENAS, its gate facing the area's middle)
	local circles: { Disc } = { { at = c, r = ctx.R + 2.5 } }
	local spot = Config.BOSS_ARENAS and Config.BOSS_ARENAS[ctx.z]
	local zone = Zones.list[ctx.z]
	if spot and zone then
		local ac = Vector2.new(spot.x, spot.z)
		local ar = (Config.BOSS_ARENA_RADIUS or 70) + 3
		table.insert(circles, { at = ac, r = ar + 3 })
		local out = zone.center - ac
		if out.Magnitude > 1 then
			for k = 0, 54, 6 do
				table.insert(circles, { at = ac + out.Unit * (ar + k), r = 12 })
			end
		end
	end
	ctx.circles = circles
	ctx.taken = {}
	ctx.placed = {}
	-- anything else standing round the plaza (a bridge, a pad, a building) except the ground, the scenery, this camp
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { ctx.f }
	for _, name in { "Ground", "Visuals", "Patches", "Grass", "Loot" } do
		local d = ctx.w:FindFirstChild(name)
		if d then
			table.insert(skip, d)
		end
	end
	overlap.FilterDescendantsInstances = skip
	ctx.overlap = overlap
end

local function free(ctx: Ctx, p: Vector3, r: number): boolean
	local q = Vector2.new(p.X, p.Z)
	for _, k in ctx.circles :: { Disc } do
		if (q - k.at).Magnitude < r + k.r then
			return false
		end
	end
	for _, t in ctx.taken :: { Disc } do
		if (q - t.at).Magnitude < r + t.r + 8 then
			return false
		end
	end
	for _, b in ctx.blocked :: { Box } do
		if not outside(b, p, r + 1) then
			return false
		end
	end
	return #workspace:GetPartBoundsInBox(CFrame.new(p.X, ctx.top + 11, p.Z), Vector3.new(r * 2, 24, r * 2), ctx.overlap) == 0
end

-- Take the scenery (trees, bushes, rocks) off a building's spot; the paths and the landmarks stay.
local function clearAround(ctx: Ctx, p: Vector3, r: number)
	local visuals = ctx.w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			local q = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
			if q and Vector2.new(q.X - p.X, q.Z - p.Z).Magnitude < r and d.Name ~= "Blocker" and not string.find(d.Name, "Landmark", 1, true) and not isFlat(d) then
				d:Destroy()
			end
		end
	end
end

export type Spot = { cf: CFrame, y: number, gmin: number }

-- the turns to try round a wanted angle, nearest first: 0, 10, -10, 20, -20 ... 180
local TURNS = { 0 }
for k = 10, 170, 10 do
	table.insert(TURNS, k)
	table.insert(TURNS, -k)
end
table.insert(TURNS, 180)

-- A spot for something halfW x halfD round angle `deg` from the area's middle (or the nearest free angle) and `r`
-- from the pad: on ground that's there, not too steep, free (above); its front toward the plaza. nil if there's none.
local function findSpot(ctx: Ctx, name: string, deg: number, r: number, halfW: number, halfD: number): Spot?
	local best: Spot? = nil
	local bestScore = math.huge
	for _, da in TURNS do
		for _, dr in { 0, 3, 6 } do
			local dir = dirAt(ctx, deg + da)
			local p = ctx.base + dir * (r + dr)
			local cf = CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.new(p.X, 0, p.Z) - dir)
			local gmin, gmax, ok = math.huge, -math.huge, true
			for _, sx in { -1, 0, 1 } do
				for _, sz in { -1, 0, 1 } do
					local q = cf * Vector3.new(sx * halfW, 0, sz * halfD)
					local g = groundAt(ctx, q.X, q.Z)
					if not g then
						ok = false
						break
					end
					gmin, gmax = math.min(gmin, g), math.max(gmax, g)
				end
				if not ok then
					break
				end
			end
			if ok and gmax - gmin <= 4.5 and gmax <= ctx.top + 5 and gmin >= ctx.top - 9 and free(ctx, p, math.max(halfW, halfD)) then
				-- level with the plaza when the ground is just below it
				local y = if gmax < ctx.top and ctx.top - gmax <= 2.6 then ctx.top else gmax
				local score = (y - gmin) * 2 + math.abs(da) * 0.06 + dr * 0.3 + math.abs(y - ctx.top) * 0.8
				if score < bestScore then
					bestScore = score
					best = { cf = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) - dir), y = y, gmin = gmin }
				end
			end
		end
		if best and bestScore < 2 then
			break
		end
	end
	if best then
		table.insert(ctx.taken :: { Disc }, { at = Vector2.new(best.cf.Position.X, best.cf.Position.Z), r = math.max(halfW, halfD) })
		table.insert(ctx.placed :: { string }, string.format("%s@%.0f%+.0f", name, deg, best.y - ctx.top))
	else
		table.insert(ctx.placed :: { string }, name .. ":none")
	end
	return best
end

-- Under a building (w x d) where the ground falls away: the area's own ground built up to its floor (copies of the
-- terrain's top layer and body there), so it stands on a little terrace of the ground, not on a stone slab with
-- steps (owner, 29 Oct: "remove every slop part thats ugly").
local function footing(ctx: Ctx, spot: Spot, w: number, d: number)
	local h = spot.y - spot.gmin
	if h < 0.1 then
		return
	end
	local c = spot.cf.Position
	local hit = workspace:Raycast(c + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), ctx.ground)
	local top = hit and hit.Instance
	if not (hit and top and top:IsA("BasePart")) then
		return
	end
	local layer = math.min(1.2, h + 0.5)
	local q = top:Clone()
	q:ClearAllChildren()
	q.Name = "Fill"
	q.Size = Vector3.new(w, layer, d)
	q.CFrame = spot.cf * CFrame.new(0, -layer / 2, 0)
	q.Parent = ctx.f
	local bodyH = spot.y - layer - (spot.gmin - 0.5)
	if bodyH > 0.05 then
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { ctx.w:FindFirstChild("Ground") :: Instance }
		local under = workspace:GetPartBoundsInBox(CFrame.new(hit.Position - Vector3.new(0, 2, 0)), Vector3.one * 0.2, params)
		local b = (under[1] or top):Clone()
		b:ClearAllChildren()
		b.Name = "Fill"
		b.Size = Vector3.new(w, bodyH, d)
		b.CFrame = spot.cf * CFrame.new(0, -layer - bodyH / 2, 0)
		b.Parent = ctx.f
	end
end

local function tag(inst: Instance, name: string, attrs: { [string]: any }?)
	for k, v in attrs or {} do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

local function place(ctx: Ctx, name: string, cf: CFrame, opts: { [string]: any }?): Model?
	local o = table.clone(opts or {})
	o.roles = o.roles or ctx.roles
	return CampProps.place(name, ctx.f, cf, o :: any)
end

-- A lamp on a model's "Lamp" markers: a bracket and a hanging lantern in the area's glow.
local function lamps(ctx: Ctx, m: Model, hang: boolean?)
	for _, mk in CampProps.markers(m, "Lamp") do
		if hang then
			VoxelKit.lantern(ctx.f, mk.CFrame * CFrame.new(0, 0.2, 0), true, ctx.glow, true)
		else
			part(ctx.f, "LampArm", mk.CFrame * CFrame.new(0, 0.5, 0.35), Vector3.new(0.25, 0.25, 0.9), C.iron)
			VoxelKit.lantern(ctx.f, mk.CFrame * CFrame.new(0, 0.38, 0), true, ctx.glow, true)
		end
	end
end

local function smoke(m: Model, color: Color3?, rate: number?)
	for _, mk in CampProps.markers(m, "Smoke") do
		local e = Instance.new("ParticleEmitter")
		e.Name = "ChimneySmoke"
		e.Texture = FxIds.smoke or "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(color or rgb(214, 210, 204), rgb(160, 158, 156))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(4, 6.5)
		e.Rate = rate or 3
		e.Speed = NumberRange.new(2, 3.2)
		e.SpreadAngle = Vector2.new(10, 10)
		e.Acceleration = Vector3.new(0.8, 0.4, 0.3)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.Rotation = NumberRange.new(0, 360)
		e.LightInfluence = 0.8
		e.Parent = mk
	end
end

-- A sign's text (both faces of `p`).
local function signText(p: BasePart, text: string, color: Color3?, ppu: number?)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = ppu or 40
		gui.LightInfluence = 0.4
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -12, 1, -8)
		t.Position = UDim2.fromOffset(6, 4)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color or rgb(255, 240, 200)
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = rgb(60, 36, 20)
		st.Parent = t
		t.Parent = gui
	end
end

-------------------------------------------------------------------------------------------------------------
-- on the plaza: what stands there already, and whether a spot is paved and clear
-------------------------------------------------------------------------------------------------------------
local PAVING = { Tile = true, TileBed = true, Plank = true, Footing = true, Step = true, WalkPlate = true }

local function plazaSetup(ctx: Ctx)
	local boxes: { Box } = {}
	local function add(cf: CFrame, size: Vector3)
		table.insert(boxes, footprint(cf, size))
	end
	for _, d in ctx.f:GetChildren() do
		if d:IsA("Model") then
			local cf, size = d:GetBoundingBox()
			add(cf, size)
		elseif d:IsA("BasePart") and not PAVING[d.Name] then
			add(d.CFrame, d.Size)
		end
	end
	ctx.plazaTaken = {}
	local pads = ctx.w:FindFirstChild("Pads")
	for _, d in (if pads then pads:GetChildren() else {}) do
		local cf: CFrame?, size: Vector3? = nil, nil
		if d:IsA("Model") then
			cf, size = d:GetBoundingBox()
		elseif d:IsA("BasePart") then
			cf, size = d.CFrame, d.Size
		end
		if cf and size and Vector2.new(cf.Position.X - ctx.base.X, cf.Position.Z - ctx.base.Z).Magnitude < ctx.R + 6 then
			if d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
				-- the pad's round steps (discs on their side): round
				table.insert(ctx.plazaTaken :: { Disc }, { at = Vector2.new(cf.Position.X, cf.Position.Z), r = math.max(size.Y, size.Z) / 2 })
			else
				add(cf, size)
			end
		end
	end
	ctx.obstacles = boxes
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { ctx.f }
	ctx.paveRay = ray
end

-- nothing on the plaza within `r` of world point p
local function clearOf(ctx: Ctx, p: Vector3, r: number): boolean
	for _, b in ctx.obstacles :: { Box } do
		if not outside(b, p, r) then
			return false
		end
	end
	for _, t in ctx.plazaTaken :: { Disc } do
		if Vector2.new(p.X - t.at.X, p.Z - t.at.Y).Magnitude < r + t.r then
			return false
		end
	end
	return true
end

-- paved at the plaza's height under world point p, nothing on it up to head height (an arch's sign is higher)
local function paved(ctx: Ctx, p: Vector3): boolean
	local hit = workspace:Raycast(Vector3.new(p.X, ctx.top + 4.5, p.Z), Vector3.new(0, -6.5, 0), ctx.paveRay)
	return hit ~= nil and PAVING[hit.Instance.Name] == true and math.abs(hit.Position.Y - ctx.top) < 0.35
end

-- a round spot of radius r at p: paved all over and clear
local function onPlaza(ctx: Ctx, p: Vector3, r: number): boolean
	if not paved(ctx, p) or not clearOf(ctx, p, r) then
		return false
	end
	for k = 0, 7 do
		local a = k * math.pi / 4
		if not paved(ctx, p + Vector3.new(math.cos(a), 0, math.sin(a)) * r) then
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the plaza's pieces
-------------------------------------------------------------------------------------------------------------
-- Where the busiest path comes in (degrees from the area's middle; 0 when no path does): the arch goes there.
local function entrance(ctx: Ctx): number
	local bins: { [number]: { number } } = {}
	local visuals = ctx.w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			if isPath(d) then
				local v = (d :: BasePart).Position - ctx.base
				local dist = Vector2.new(v.X, v.Z).Magnitude
				if dist > ctx.R + 2 and dist < ctx.R + 18 then
					local deg = math.deg(math.atan2(v:Dot(ctx.right), v:Dot(ctx.fwd)))
					local k = math.floor(deg / 20 + 0.5)
					bins[k] = bins[k] or {}
					table.insert(bins[k], deg)
				end
			end
		end
	end
	local best, most = nil, 0
	for _, list in bins do
		if #list > most then
			best, most = list, #list
		end
	end
	if not best then
		return 0
	end
	-- the bin's middle (angles near +-180 are kept on one side)
	local s, c = 0, 0
	for _, deg in best do
		s += math.sin(math.rad(deg))
		c += math.cos(math.rad(deg))
	end
	return math.deg(math.atan2(s, c))
end

-- The entrance arch where the path comes in, its two feet and the way through on the paving.
local function arch(ctx: Ctx, name: string)
	local e = entrance(ctx)
	for _, dist in { ctx.R - 3.6, ctx.R - 4.8, ctx.R - 6, ctx.R - 7.5 } do
		for _, da in { 0, 12, -12, 24, -24, 36, -36 } do
			local deg = e + da
			local d = dirAt(ctx, deg)
			local p = ctx.base + d * dist
			local cf = CFrame.lookAt(p, p + d)
			local ok = clearOf(ctx, p, 2.5)
			for _, x in { -7.6, -5, -2.5, 0, 2.5, 5, 7.6 } do
				for _, z in { -1.1, 1.1 } do
					ok = ok and paved(ctx, (cf * CFrame.new(x, 0, z)).Position)
				end
			end
			for _, x in { -6.6, 6.6 } do
				ok = ok and clearOf(ctx, (cf * CFrame.new(x, 0, 0)).Position, 2.2)
			end
			if ok then
				local m = place(ctx, "camp_arch", cf, { collide = true })
				if not m then
					return
				end
				-- no name board (owner, 29 Oct: "remove every slop part thats ugly like signs"): the board, its rim and
				-- chains hang between the posts under the beams
				local left = 0
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") then
						local lp = cf:PointToObjectSpace(p.Position)
						if math.abs(lp.X) <= 4.7 and lp.Y > 5.5 and lp.Y < 9.05 and math.abs(lp.Z) <= 0.6 then
							p:Destroy()
						else
							left += 1
						end
					end
				end
				m:SetAttribute("NParts", left) -- (client/CampLife waits for all of them to stream in)
				local _ = name
				lamps(ctx, m)
				for _, g in { "BanL", "BanR" } do
					tag(m, "CampSway", { ["Group_" .. g] = true })
				end
				m:SetAttribute("Amp", 6)
				m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				for _, x in { -6.6, 6.6 } do
					local q = (cf * CFrame.new(x, 0, 0)).Position
					table.insert(ctx.plazaTaken :: { Disc }, { at = Vector2.new(q.X, q.Z), r = 1.8 })
				end
				table.insert(ctx.placed :: { string }, string.format("arch@%.0f/%.1f", deg, dist))
				return
			end
		end
	end
	table.insert(ctx.placed :: { string }, "arch:none")
end

-- Four lamp posts near the edge, between the arch and the stalls.
local function lampPosts(ctx: Ctx)
	local lanternPost = ctx.lanternPost
	if not lanternPost then
		return
	end
	local n = 0
	for _, deg in { 42, -42, 138, -138 } do
		local done = false
		for _, da in { 0, 8, -8, 16, -16 } do
			for _, inset in { 1.8, 3.2, 4.6 } do
				if not done then
					local d = dirAt(ctx, deg + da)
					local p = ctx.base + d * (ctx.R - inset)
					if onPlaza(ctx, p, 1.3) then
						lanternPost(ctx.f, p, d)
						table.insert(ctx.plazaTaken :: { Disc }, { at = Vector2.new(p.X, p.Z), r = 1.2 })
						done = true
						n += 1
					end
				end
			end
		end
	end
	table.insert(ctx.placed :: { string }, n .. " lamps")
end

-------------------------------------------------------------------------------------------------------------
-- villagers and critters (client/CampLife moves them)
-------------------------------------------------------------------------------------------------------------
local TOOLS: { [string]: (Instance, CFrame, Random) -> { BasePart } } = {}
local function held(parent: Instance, cf: CFrame, size: Vector3, color: Color3, look: any?): BasePart
	return part(parent, "Held", cf, size, color, look)
end
TOOLS.rake = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.3, 0), Vector3.new(0.18, 4.2, 0.18), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, 2.3, 0), Vector3.new(1.4, 0.2, 0.3), rgb(110, 110, 116)) }
end
TOOLS.water = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, -0.45, -0.25), Vector3.new(0.8, 0.8, 1.0), rgb(110, 170, 140), Enum.Material.Metal), held(p, hand * CFrame.new(0, -0.25, -0.95) * CFrame.Angles(math.rad(35), 0, 0), Vector3.new(0.18, 0.18, 0.9), rgb(110, 170, 140), Enum.Material.Metal) }
end
TOOLS.chop = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.6, 0), Vector3.new(0.2, 2.4, 0.2), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, 1.65, -0.35), Vector3.new(0.15, 0.6, 0.75), rgb(170, 172, 178), Enum.Material.Metal) }
end
TOOLS.fish = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 1.3, -1.9) * CFrame.Angles(math.rad(-55), 0, 0), Vector3.new(0.12, 4.6, 0.12), rgb(150, 110, 70)) }
end
TOOLS.shovel = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.5, 0), Vector3.new(0.18, 3.0, 0.18), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, -1.15, 0), Vector3.new(0.9, 0.8, 0.12), rgb(80, 130, 200), Enum.Material.Metal) }
end
TOOLS.hammer = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.45, 0), Vector3.new(0.18, 1.5, 0.18), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, 1.25, 0), Vector3.new(0.7, 0.4, 0.4), rgb(70, 68, 70), Enum.Material.Metal) }
end
TOOLS.gaze = function(p, hand, _)
	local star = held(p, hand * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.55, 0.55, 0.3), rgb(255, 230, 120), Enum.Material.Neon)
	VoxelKit.light(star, 8, 0.6, rgb(255, 230, 150))
	return { held(p, hand * CFrame.new(0, 0.9, 0), Vector3.new(0.2, 3.4, 0.2), rgb(120, 90, 160)), star }
end
local AREA_WORK = { wheat = "rake", blossom = "water", pine = "chop", swamp = "fish", frost = "shovel", ember = "hammer", isles = "gaze" }

local villagerN = 0
-- A gnome villager standing on `cf` (front: cf's LookVector). `act`: idle (looks at you, waves, talks), walk (along
-- `path`, world points), work (`work`: the area's job, with its tool in the right hand).
local function villager(ctx: Ctx, cf: CFrame, act: string, opts: { path: { Vector3 }?, work: string?, outfit: number?, lift: number? }?)
	local o = opts or {}
	local roles = table.clone(ctx.roles)
	local outfits = OUTFITS[ctx.id :: string]
	local pick = o.outfit and outfits and outfits[o.outfit]
	if pick then
		roles.coat, roles.pants, roles.hat = { nil, pick[1] }, { nil, pick[2] }, { nil, pick[3] }
	end
	villagerN += 1
	local m = CampProps.place("camp_gnome", ctx.f, cf * CFrame.new(0, o.lift or 0, 0), { roles = roles, atomic = true, name = "Villager" })
	if not m then
		return
	end
	local work = o.work
	if work and TOOLS[work] then
		local hand = CampProps.markers(m, "Hand")[1]
		if hand then
			for _, p in TOOLS[work](m, hand.CFrame, ctx.rng) do
				p:SetAttribute("G", "armR")
				p.Parent = m
			end
		end
	end
	local attrs: { [string]: any } = { Act = act, Area = ctx.id, Work = work or "", Seed = villagerN }
	if o.path then
		local bits = {}
		for _, p in o.path do
			table.insert(bits, string.format("%.1f,%.1f", p.X, p.Z))
		end
		attrs.Path = table.concat(bits, ";")
	end
	tag(m, "CampVillager", attrs)
end

-- `kind`: walk / hop / swim / perch / waddle / crawl, round `home` (on the ground) within `range`.
local function critter(ctx: Ctx, name: string, home: Vector3, kind: string, range: number, speed: number, scale: number?)
	local a = ctx.rng:NextNumber(0, math.pi * 2)
	local p = home + Vector3.new(math.cos(a), 0, math.sin(a)) * ctx.rng:NextNumber(0, range * 0.7)
	local cf = CFrame.lookAt(p, p + Vector3.new(math.sin(a), 0, math.cos(a)))
	local m = place(ctx, name, cf, { atomic = true, scale = scale })
	if m then
		tag(m, "CampCritter", { Kind = kind, Home = home, Range = range, Speed = speed, Seed = ctx.rng:NextInteger(1, 9999) })
	end
end

local function wisp(ctx: Ctx, home: Vector3, range: number)
	local m = Instance.new("Model")
	m.Name = "Wisp"
	local core = part(m, "WispCore", CFrame.new(home + Vector3.new(0, 3, 0)), Vector3.one * 0.6, rgb(170, 240, 255), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CastShadow = false
	local halo = part(m, "WispHalo", core.CFrame, Vector3.one * 1.2, rgb(150, 220, 255), Enum.Material.Neon)
	halo.Shape = Enum.PartType.Ball
	halo.Transparency = 0.7
	halo.CastShadow = false
	VoxelKit.light(core, 10, 0.8, rgb(150, 230, 255))
	m.WorldPivot = core.CFrame
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = ctx.f
	tag(m, "CampCritter", { Kind = "float", Home = home + Vector3.new(0, 3, 0), Range = range, Speed = 2.2, Seed = ctx.rng:NextInteger(1, 9999) })
end

-------------------------------------------------------------------------------------------------------------
-- round the plaza: the house, the landmark, the animals
-------------------------------------------------------------------------------------------------------------
local function house(ctx: Ctx)
	local spot = findSpot(ctx, "house", -125, ctx.R + 2.5 + 8, 7.6, 7.2)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, 12)
	local cf = spot.cf
	if ctx.id == "swamp" then
		-- on stilts over the bog, a deck along its front and steps down
		local lift = 3.2
		for _, x in { -6.4, 0, 6.4 } do
			for _, z in { -5, 5 } do
				local h = spot.y + lift - spot.gmin + 0.6
				part(ctx.f, "Stilt", cf * CFrame.new(x, lift - h / 2, z), Vector3.new(0.9, h, 0.9), VoxelKit.jitter(ctx.rng, rgb(150, 120, 90), 0.06), "log", true)
			end
		end
		part(ctx.f, "Deck", cf * CFrame.new(0, lift - 0.2, -6.4), Vector3.new(14.4, 0.4, 3.4), rgb(130, 108, 78), Enum.Material.WoodPlanks, true)
		for i = 1, 4 do
			part(ctx.f, "DeckStep", cf * CFrame.new(0, lift - 0.4 - i * 0.8, -8.1 - i * 0.9), Vector3.new(3.4, 0.35, 0.95), rgb(118, 96, 70), Enum.Material.WoodPlanks, true)
		end
		cf = cf * CFrame.new(0, lift, 0)
	else
		footing(ctx, spot, 14.6, 12.4)
	end
	local m = place(ctx, "camp_house", cf, { collide = true })
	if m then
		smoke(m, if ctx.id == "ember" then rgb(120, 110, 106) else nil)
	end
end

local function fence(ctx: Ctx, cf: CFrame, w: number, d: number, gapFront: boolean?)
	local wood = ctx.roles.wood[2] :: Color3
	local corners = { Vector3.new(-w / 2, 0, -d / 2), Vector3.new(w / 2, 0, -d / 2), Vector3.new(w / 2, 0, d / 2), Vector3.new(-w / 2, 0, d / 2) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local along = (b - a).Unit
		local seg = CFrame.lookAt(mid, mid + along)
		if gapFront and i == 1 then
			-- a gate gap in the middle of the front side
			for _, s in { -1, 1 } do
				local m2 = mid + along * s * (len / 4 + 0.6)
				part(ctx.f, "Rail", cf * CFrame.lookAt(m2 + Vector3.new(0, 1.6, 0), m2 + Vector3.new(0, 1.6, 0) + along), Vector3.new(0.25, 0.25, len / 2 - 1.2), wood)
				part(ctx.f, "Rail", cf * CFrame.lookAt(m2 + Vector3.new(0, 0.9, 0), m2 + Vector3.new(0, 0.9, 0) + along), Vector3.new(0.25, 0.25, len / 2 - 1.2), wood)
			end
		else
			part(ctx.f, "Rail", cf * (seg + Vector3.new(0, 1.6, 0)), Vector3.new(0.25, 0.25, len), wood)
			part(ctx.f, "Rail", cf * (seg + Vector3.new(0, 0.9, 0)), Vector3.new(0.25, 0.25, len), wood)
		end
		part(ctx.f, "FencePost", cf * CFrame.new(a + Vector3.new(0, 1.0, 0)), Vector3.new(0.45, 2.0, 0.45), wood, "log", true)
	end
end

local function pond(ctx: Ctx, cf: CFrame, r: number, water: Color3, lily: boolean?)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		part(ctx.f, "PondStone", cf * CFrame.new(math.cos(a) * (r + 0.4), 0.3, math.sin(a) * (r + 0.4)) * CFrame.Angles(0, -a, 0), Vector3.new(1.0, 0.6, r * 0.62), VoxelKit.jitter(ctx.rng, ctx.roles.stone[2], 0.07), "stone")
	end
	local wtr = part(ctx.f, "PondWater", cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, r * 2, r * 2), water, Enum.Material.Glass)
	wtr.Shape = Enum.PartType.Cylinder
	wtr.Transparency = 0.25
	part(ctx.f, "PondBed", cf * CFrame.new(0, -0.05, 0), Vector3.new(r * 2, 0.1, r * 2), rgb(60, 70, 50), Enum.Material.Mud)
	if lily then
		for _ = 1, 4 do
			local a, d = ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(0.6, r - 0.8)
			local pad = part(ctx.f, "LilyPad", cf * CFrame.new(math.cos(a) * d, 0.23, math.sin(a) * d) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, 1.3, 1.3), rgb(90, 170, 70))
			pad.Shape = Enum.PartType.Cylinder
		end
	end
end

local LANDMARK = { wheat = "camp_windmill", blossom = "camp_pavilion", pine = "camp_watchtower", frost = "camp_igloo", ember = "camp_forge", isles = "camp_telescope" }
local LANDMARK_SIZE = { wheat = 4.6, blossom = 6.0, pine = 4.0, swamp = 7.0, frost = 6.4, ember = 6.4, isles = 4.0 }

local function landmark(ctx: Ctx)
	local id = ctx.id :: string
	local size = LANDMARK_SIZE[id] or 5
	local spot = findSpot(ctx, "landmark", 120, ctx.R + 2.5 + size + 1, size, size)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, size + 5)
	local cf = spot.cf
	local workAt: CFrame? = nil
	local workLook: Vector3? = nil
	if id == "swamp" then
		-- a pond with a jetty and a rowing boat (bobbing), frogs on the lily pads
		footing(ctx, spot, 14, 14)
		pond(ctx, cf * CFrame.new(0, 0, 1), 6.2, ctx.roles.water[2], true)
		for i = 0, 3 do
			part(ctx.f, "Jetty", cf * CFrame.new(-1.2, 0.55, -6.5 + i * 2.2), Vector3.new(2.6, 0.3, 2.1), VoxelKit.jitter(ctx.rng, rgb(130, 108, 78), 0.05), Enum.Material.WoodPlanks, true)
			for _, x in { -2.4, 0 } do
				part(ctx.f, "JettyPost", cf * CFrame.new(x, 0.2, -6.5 + i * 2.2), Vector3.new(0.4, 1.4, 0.4), rgb(110, 88, 64), "log")
			end
		end
		local boat = place(ctx, "camp_boat", cf * CFrame.new(2.6, 0.12, 2.2) * CFrame.Angles(0, math.rad(20), 0), { atomic = true })
		if boat then
			tag(boat, "CampBob", { Amp = 0.12, Freq = 0.35, Roll = 3 })
		end
		for _ = 1, 3 do
			critter(ctx, "critter_frog", (cf * CFrame.new(0, 0.62, 1)).Position, "hop", 5.4, 2.0, 0.85)
		end
		for i = 1, 4 do -- reeds
			local a = i / 4 * math.pi * 2 + 0.6
			local h = ctx.rng:NextNumber(2.2, 3.4)
			local base = cf * CFrame.new(math.cos(a) * 6.8, 0, 1 + math.sin(a) * 6.8)
			part(ctx.f, "Reed", base * CFrame.new(0, h / 2, 0), Vector3.new(0.15, h, 0.15), rgb(110, 150, 70))
			part(ctx.f, "Cattail", base * CFrame.new(0, h + 0.3, 0), Vector3.new(0.32, 0.8, 0.32), rgb(120, 80, 50))
		end
		workAt = cf * CFrame.new(-1.2, 0.7, -2.3) * CFrame.Angles(0, math.pi, 0)
	else
		footing(ctx, spot, size * 2 + 1, size * 2 + 1)
		local name = LANDMARK[id]
		local m = name and place(ctx, name, cf, { collide = true, atomic = true })
		if m then
			if id == "blossom" then
				lamps(ctx, m, true) -- the pavilion's paper lanterns
			end
			smoke(m, rgb(110, 104, 100), 5)
			if id == "wheat" then
				tag(m, "CampSpin", { Group_Rotor = true, Axis = Vector3.new(0, 0, -1), Speed = 28 })
				workAt = cf * CFrame.new(3.6, 0, -6.2)
			elseif id == "pine" then
				tag(m, "CampSway", { Group_Flag = true, Amp = 14, Phase = 0.3, Axis = Vector3.yAxis })
				workAt = cf * CFrame.new(-4.2, 0, -5.4)
			elseif id == "blossom" then
				workAt = cf * CFrame.new(4.0, 0, -7.0)
			elseif id == "frost" then
				place(ctx, "camp_snowman", cf * CFrame.new(-6.2, 0, -3.5) * CFrame.Angles(0, math.rad(25), 0), { collide = true })
				workAt = cf * CFrame.new(3.2, 0, -7.4)
			elseif id == "ember" then
				tag(m, "CampPump", { Group_Bellows = true, Amp = 10, Freq = 0.7 })
				for _, mk in CampProps.markers(m, "Embers") do
					VoxelKit.fire(mk, rgb(255, 120, 40), 1.4)
				end
				workAt = cf * CFrame.new(3.4, 0, -5.2)
				workLook = (cf * CFrame.new(3.4, 0, -3.4)).Position
			elseif id == "isles" then
				tag(m, "CampSweep", { Group_Scope = true, Amp = 35, Freq = 0.05 })
				workAt = cf * CFrame.new(-2.6, 1.0, -3.6)
			end
		end
	end
	if workAt then
		local p = workAt.Position
		local target = workLook or cf.Position
		local look = Vector3.new(target.X, p.Y, target.Z)
		villager(ctx, CFrame.lookAt(p, if (look - p).Magnitude > 0.5 then look else p + workAt.LookVector), "work", { work = AREA_WORK[id], outfit = 1 })
	end
end

local function animals(ctx: Ctx)
	local id = ctx.id :: string
	if id == "swamp" then
		return -- the frogs live in the landmark's pond
	end
	local spot = findSpot(ctx, "animals", 55, ctx.R + 2.5 + 6.5, 6, 6)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, 9)
	footing(ctx, spot, 13, 13)
	local cf = spot.cf
	local home = cf.Position + UP * 0.12
	if id == "wheat" then
		fence(ctx, cf, 11, 11, true)
		for _ = 1, 4 do
			critter(ctx, "critter_chicken", home, "walk", 4.2, 1.6, 0.9)
		end
	elseif id == "blossom" then
		pond(ctx, cf, 5.2, rgb(110, 170, 210), true)
		for _ = 1, 3 do
			critter(ctx, "critter_koi", home + Vector3.new(0, 0.05, 0), "swim", 3.8, 1.6, 1.0)
		end
	elseif id == "pine" then
		for i, p in { Vector3.new(-2.8, 0, 1.5), Vector3.new(2.8, 0, -1.5) } do
			local h = 2.8 + i * 0.6
			part(ctx.f, "Perch", cf * CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(0.8, h, 0.8), C.log, "log", true)
			local m = place(ctx, "critter_owl", cf * CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(0, ctx.rng:NextNumber(0, 6.28), 0), { atomic = true })
			if m then
				tag(m, "CampCritter", { Kind = "perch", Home = m:GetPivot().Position, Range = 0, Speed = 0, Seed = ctx.rng:NextInteger(1, 9999) })
			end
		end
	elseif id == "frost" then
		for _ = 1, 3 do
			critter(ctx, "critter_penguin", home, "waddle", 4.6, 1.2, 0.9)
		end
	elseif id == "ember" then
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2
			part(ctx.f, "LavaCrack", cf * CFrame.new(math.cos(a) * 2.2, 0.14, math.sin(a) * 2.2) * CFrame.Angles(0, a, 0), Vector3.new(3.4, 0.06, 0.3), rgb(255, 120, 40), Enum.Material.Neon)
		end
		for _ = 1, 2 do
			critter(ctx, "critter_lizard", home, "crawl", 4.2, 1.4, 1.0)
		end
	elseif id == "isles" then
		VoxelKit.crystals(ctx.f, cf, rgb(170, 120, 255), ctx.rng, 4, true)
		for _ = 1, 4 do
			wisp(ctx, home, 6)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the people on the plaza
-------------------------------------------------------------------------------------------------------------
-- every step from a to b paved and clear
local function walkable(ctx: Ctx, a: Vector3, b: Vector3): boolean
	local n = math.ceil((b - a).Magnitude / 1.25)
	for s = 0, n do
		if not onPlaza(ctx, a:Lerp(b, s / n), 1.0) then
			return false
		end
	end
	return true
end

-- The walk round the plaza: eight points on a circle with every step of the way paved and clear; else back and forth
-- along half a circle in front of the stalls (the first that works, nil if none does).
local function walkLoop(ctx: Ctx): { Vector3 }?
	for _, rr in { 17.5, 16, 19, 14.5, 20.5 } do
		for _, off in { 0, 22.5 } do
			local pts = {}
			for k = 0, 7 do
				table.insert(pts, ctx.base + dirAt(ctx, k * 45 + off) * rr)
			end
			local ok = true
			for k = 1, 8 do
				ok = ok and walkable(ctx, pts[k], pts[k % 8 + 1])
			end
			if ok then
				return pts
			end
		end
	end
	for _, rr in { 16, 17.5, 14.5, 19, 13 } do
		for _, mid in { 0, 30, -30, 60, -60, 90, -90 } do
			local pts = {}
			for k = -3, 3 do
				table.insert(pts, ctx.base + dirAt(ctx, mid + k * 30) * rr)
			end
			local ok = true
			for k = 1, 6 do
				ok = ok and walkable(ctx, pts[k], pts[k + 1])
			end
			if ok then
				-- there and back: 1..7, then 6..2 (the loop closes from 2 to 1)
				for k = 6, 2, -1 do
					table.insert(pts, pts[k])
				end
				return pts
			end
		end
	end
	return nil
end

local function people(ctx: Ctx)
	-- one by the stalls, looking out over the plaza
	local n = 0
	for _, s in { { -14.6, -12.5 }, { 14.6, -12.5 }, { -13, -10 }, { 13, -10 }, { -15, -5 }, { 15, -5 } } do
		local p = ctx.base + ctx.right * s[1] + ctx.fwd * s[2]
		if onPlaza(ctx, p, 1.1) then
			villager(ctx, CFrame.lookAt(p, p + ctx.fwd), "idle", { outfit = 1 })
			table.insert(ctx.plazaTaken :: { Disc }, { at = Vector2.new(p.X, p.Z), r = 1.3 })
			n += 1
			break
		end
	end
	-- one walking round
	local loop = walkLoop(ctx)
	if loop then
		villager(ctx, CFrame.lookAt(loop[1], loop[2]), "walk", { path = loop, outfit = 2 })
		n += 1
	end
	table.insert(ctx.placed :: { string }, n .. " villagers on the plaza")
end

-------------------------------------------------------------------------------------------------------------
-- dressing one camp
-------------------------------------------------------------------------------------------------------------
function CampDress.dress(ctx: Ctx)
	local def = Zones.list[ctx.z]
	ctx.id = def and def.id or "wheat"
	ctx.roles = rolesFor(ctx.id :: string)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ctx.w:FindFirstChild("Ground") :: Instance }
	ctx.ground = params
	collectBlocked(ctx)
	plazaSetup(ctx)
	for _, step in { function()
		arch(ctx, if def then def.name else "")
	end, function()
		lampPosts(ctx)
	end, function()
		house(ctx)
	end, function()
		landmark(ctx)
	end, function()
		animals(ctx)
	end, function()
		people(ctx)
	end } do
		local ok, err = pcall(step)
		if not ok then
			warn(("[CampDress] area %d: %s"):format(ctx.z, tostring(err)))
		end
	end
	print(("[CampDress] %s camp: %s"):format(ctx.id :: string, table.concat(ctx.placed :: { string }, ", ")))
end

return CampDress
