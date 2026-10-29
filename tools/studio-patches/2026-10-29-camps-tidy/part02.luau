local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	buf = Instance.new("Folder")
	buf.Name = "ClaudePatchBuf"
	buf.Parent = ss
end
local bad = {}
local function put(name, text, want)
	if hashOf(text) ~= want then
		table.insert(bad, name .. " garbled")
		return
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
end

put("CampDress.2", [====[	ember = { { rgb(82, 78, 80), rgb(122, 72, 42), rgb(204, 72, 42) }, { rgb(204, 72, 42), rgb(62, 52, 52), rgb(255, 156, 72) } },
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

-- a path tile (World.Visuals: WorldArt's flat 3.1 x 0.3 x 3.1 paving) or other flat ground cover: kept, built round
local function isFlat(d: Instance): boolean
	return d:IsA("BasePart") and d.Size.Y <= 0.6 and math.max(d.Size.X, d.Size.Z) <= 8
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
			table.insert(list, { cf = cf, hx = size.X / 2, hz = size.Z / 2 })
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
	-- the paths (flat tiles in World.Visuals) and the areas' landmarks
	local visuals = ctx.w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			if isFlat(d) then
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
		if (q - t.at).Magnitude < r + t.r + 3 then
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

-- A spot for something halfW x halfD round angle `deg` from the area's middle and `r` from the pad: on ground that's
-- there, not too steep, free (above); its front toward the plaza. nil if there's none.
local function findSpot(ctx: Ctx, name: string, deg: number, r: number, halfW: number, halfD: number): Spot?
	local best: Spot? = nil
	local bestScore = math.huge
	for _, da in { 0, 12, -12, 24, -24, 36, -36, 50, -50, 65, -65 } do
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

-- A stone footing under a building (w x d) from the lowest ground up to its floor, with steps down at its front.
local function footing(ctx: Ctx, spot: Spot, w: number, d: number)
	local h = spot.y - spot.gmin + 0.6
	if h < 0.7 then
		return
	end
	local stone = ctx.roles.base[2] :: Color3
	part(ctx.f, "Footing", spot.cf * CFrame.new(0, -h / 2, 0), Vector3.new(w, h, d), VoxelKit.jitter(ctx.rng, stone, 0.03), "stone", true)
	part(ctx.f, "FootingCap", spot.cf * CFrame.new(0, -0.15, 0), Vector3.new(w + 0.5, 0.3, d + 0.5), C.timber, nil, true)
	local n = math.floor((h - 0.6) / 1.1)
	for i = 1, n do
		part(ctx.f, "Step", spot.cf * CFrame.new(0, -0.6 - (i - 1) * 1.1 - 0.55, -(d / 2 + 0.6 + (i - 1) * 1.2)), Vector3.new(4, 1.1, 1.2), VoxelKit.jitter(ctx.rng, stone, 0.05), "stone", true)
	end
end

local function tag(inst: Instance, name: string, attrs: { [string]: any }?)
	for k, v in attrs or {} do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

]====], "8970 1446627805")
return "part 2/5 (CampDress.2): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
