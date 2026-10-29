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

put("CampDress.2", [====[	frost = { { rgb(204, 64, 64), rgb(52, 62, 84), rgb(244, 244, 250) }, { rgb(240, 200, 44), rgb(72, 112, 172), rgb(62, 112, 192) } },
	ember = { { rgb(82, 78, 80), rgb(122, 72, 42), rgb(204, 72, 42) }, { rgb(204, 72, 42), rgb(62, 52, 52), rgb(255, 156, 72) } },
	isles = { { rgb(112, 82, 222), rgb(52, 42, 92), rgb(232, 192, 92) }, { rgb(150, 230, 255), rgb(72, 52, 152), rgb(112, 82, 222) } },
}

-------------------------------------------------------------------------------------------------------------
-- the camp's frame and the ground round it
-------------------------------------------------------------------------------------------------------------
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
	blocked: { { cf: CFrame, hx: number, hz: number } }?,
	placed: { string }?,
	taken: { { at: Vector2, r: number } }?,
}

local function at(ctx: Ctx, x: number, z: number, face: Vector3?): CFrame
	local p = ctx.base + ctx.right * x + ctx.fwd * z
	return CFrame.lookAt(p, p + (face or ctx.fwd))
end

local function dirAt(ctx: Ctx, deg: number): Vector3
	local a = math.rad(deg)
	return ctx.fwd * math.cos(a) + ctx.right * math.sin(a)
end

local function groundAt(ctx: Ctx, x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, ctx.top + 40, z), Vector3.new(0, -90, 0), ctx.ground)
	return if hit then hit.Position.Y else nil
end

-- What a building mustn't stand on: the paths, hazards, water, gates and bridges (round the camp), each as its
-- footprint (a turned rectangle).
local function collectBlocked(ctx: Ctx)
	local list = {}
	local c = Vector2.new(ctx.base.X, ctx.base.Z)
	for _, name in { "Ways", "Hazards", "Liquid", "Gates", "Arenas", "Bounds", "IsleBridges" } do
		local fold = ctx.w:FindFirstChild(name)
		if fold then
			for _, d in fold:GetDescendants() do
				if d:IsA("BasePart") then
					local p = Vector2.new(d.Position.X, d.Position.Z)
					if (p - c).Magnitude < 70 + math.max(d.Size.X, d.Size.Z) / 2 then
						table.insert(list, { cf = d.CFrame, hx = d.Size.X / 2, hz = d.Size.Z / 2 })
					end
				end
			end
		end
	end
	ctx.blocked = list
	ctx.taken = {}
	ctx.placed = {}
end

local function free(ctx: Ctx, p: Vector3, r: number): boolean
	local q = Vector2.new(p.X, p.Z)
	for _, b in ctx.blocked :: any do
		local lp = b.cf:PointToObjectSpace(Vector3.new(p.X, b.cf.Position.Y, p.Z))
		local dx, dz = math.max(0, math.abs(lp.X) - b.hx), math.max(0, math.abs(lp.Z) - b.hz)
		if dx * dx + dz * dz < r * r then
			return false
		end
	end
	for _, t in ctx.taken :: any do
		if (q - t.at).Magnitude < r + t.r then
			return false
		end
	end
	return true
end

-- Take the scenery (trees, bushes, rocks) off a building's spot.
local function clearAround(ctx: Ctx, p: Vector3, r: number)
	local visuals = ctx.w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			local q = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
			if q and Vector2.new(q.X - p.X, q.Z - p.Z).Magnitude < r and d.Name ~= "Blocker" and not string.find(d.Name, "Landmark", 1, true) then
				d:Destroy()
			end
		end
	end
end

export type Spot = { cf: CFrame, y: number, gmin: number }

-- A spot for something halfW x halfD round angle `deg` from the area's middle and `r` from the pad: on ground that's
-- there, not too steep, off the paths, clear of the rest; its front toward the plaza. nil if there's none.
local function findSpot(ctx: Ctx, deg: number, r: number, halfW: number, halfD: number): Spot?
	local best: Spot? = nil
	local bestScore = math.huge
	for _, da in { 0, 10, -10, 20, -20, 32, -32, 45, -45 } do
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
			if ok and gmax - gmin <= 6 and gmax <= ctx.top + 7 and gmin >= ctx.top - 14 and free(ctx, p, math.max(halfW, halfD)) then
				-- level with the plaza when the ground is just below it
				local y = if gmax < ctx.top and ctx.top - gmax <= 2.6 then ctx.top else gmax
				local score = (y - gmin) * 2 + math.abs(da) * 0.08 + dr * 0.3 + math.abs(y - ctx.top) * 0.8
				if score < bestScore then
					bestScore = score
					best = { cf = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) - dir), y = y, gmin = gmin }
				end
			end
		end
		if best and bestScore < 3 then
			break
		end
	end
	if best then
		table.insert(ctx.taken :: any, { at = Vector2.new(best.cf.Position.X, best.cf.Position.Z), r = math.max(halfW, halfD) })
		table.insert(ctx.placed :: { string }, string.format("%.0f@%.0f", deg, best.y - ctx.top))
	else
		table.insert(ctx.placed :: { string }, string.format("%.0f:none", deg))
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
		local sh = h - 0.6 - (i - 1) * 1.1
		part(ctx.f, "Step", spot.cf * CFrame.new(0, -0.6 - (i - 1) * 1.1 - sh / 2 + sh / 2 - 0.55, -(d / 2 + 0.6 + (i - 1) * 1.2)), Vector3.new(4, 1.1, 1.2), VoxelKit.jitter(ctx.rng, stone, 0.05), "stone", true)
	end
end

-- Stepping stones from the plaza's edge to `to`, following the ground.
local function steppingStones(ctx: Ctx, to: Vector3)
	local flat = Vector3.new(to.X - ctx.base.X, 0, to.Z - ctx.base.Z)
	if flat.Magnitude < ctx.R + 1 then
		return
	end
	local dir = flat.Unit
	local from = ctx.base + dir * (ctx.R - 0.5)
	local dist = (Vector3.new(to.X, 0, to.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
	local n = math.floor(dist / 2.3)
	for i = 1, n do
		local p = from + dir * (i * 2.3)
		local g = groundAt(ctx, p.X, p.Z)
		if g then
			local cf = CFrame.new(p.X, g + 0.12, p.Z) * CFrame.Angles(0, ctx.rng:NextNumber(0, math.pi), 0)
			part(ctx.f, "SteppingStone", cf, Vector3.new(ctx.rng:NextNumber(1.7, 2.2), 0.3, ctx.rng:NextNumber(1.5, 2.0)), VoxelKit.jitter(ctx.rng, ctx.roles.stone[2], 0.06), "stone")
		end
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
]====], "8977 1332259226")
return "part 6/13 (CampDress.2): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
