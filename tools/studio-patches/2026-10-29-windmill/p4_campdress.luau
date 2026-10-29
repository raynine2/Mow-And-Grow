local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "48860 915371797" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	table.insert(ctx.placed :: { string }, string.format("arch@%.0f/%.1f room %.1f", bestDeg, bestDist, bestRoom))
end

-- Out of the arch's way (for what stands still: lamp posts, a villager standing about; owner, 29 Oct, after a lamp
-- post stood in the gateway): a spot of radius r that keeps 2.5 studs from its posts and roof ends (+-9.1 across,
-- +-1.8 deep) and off the way through it (4.5 either side of its middle, from 4 outside to 8 inside the camp).
local function offArch(ctx: Ctx, p: Vector3, r: number): boolean
	local cf = ctx.archAt
	if not cf then
		return true
	end
	local l = cf:PointToObjectSpace(p) -- (+Z: into the camp)
	if math.abs(l.X) < 9.1 + 2.5 + r and math.abs(l.Z) < 1.8 + 2.5 + r then
		return false
	end
	return not (math.abs(l.X) < 4.5 + r and l.Z > -4 - r and l.Z < 8 + r)
]======], [======[	local bench = benchOut(ctx, cf)
	table.insert(ctx.placed :: { string }, string.format("arch@%.0f/%.1f room %.1f%s", bestDeg, bestDist, bestRoom, if bench then " (" .. bench .. ")" else ""))
]======] },
	{ [======[				ok = ok and clearOf(ctx, (cf * CFrame.new(x, 0, 0)).Position, 2.2)
]======], [======[				ok = ok and clearOf(ctx, (cf * CFrame.new(x, 0, 0)).Position, 2.2, true)
]======] },
	{ [======[			local ok = clearOf(ctx, p, 2.5)
]======], [======[			local ok = clearOf(ctx, p, 2.5, true)
]======] },
	{ [======[-- fits, the one with the most room round it (up to 4 studs from the stalls, the pump and the benches; owner, 29 Oct:
-- "its very messy and just cluttered"), the nearer the path and the plaza's edge the better.
]======], [======[-- fits, the one with the most room round it (up to 4 studs from the stalls and the pump; a bench in the way gives
-- way; owner, 29 Oct: "its very messy and just cluttered"), the nearer the path and the plaza's edge the better.
]======] },
	{ [======[

-- The entrance arch where the path comes in, its two feet and the way through on the paving. Of the spots where it
]======], [======[

-- Out of the arch's way (for what stands still: lamp posts, a villager standing about, a bench; owner, 29 Oct, after
-- a lamp post stood in the gateway): a spot of radius r that keeps 2.5 studs from its posts and roof ends and off the
-- way through it (4.5 either side of its middle, from 4 outside to 8 inside the camp).
local function offArch(ctx: Ctx, p: Vector3, r: number): boolean
	local cf = ctx.archAt
	if not cf then
		return true
	end
	local l = cf:PointToObjectSpace(p) -- (+Z: into the camp)
	if math.abs(l.X) < ARCH_HX + 2.5 + r and math.abs(l.Z) < ARCH_HZ + 2.5 + r then
		return false
	end
	return not (math.abs(l.X) < 4.5 + r and l.Z > -4 - r and l.Z < 8 + r)
end

-- A bench closer than 2.5 studs to the arch is carried round the plaza (about its middle) to a clear spot, or else
-- taken away. Returns what happened (nil: no bench in the way).
local function benchOut(ctx: Ctx, cf: CFrame): string?
	local hit: { Vector3 } = {}
	for _, b in ctx.obstacles :: { Box } do
		if b.bench and archGap(cf, b) < 2.5 then
			table.insert(hit, b.cf.Position)
		end
	end
	if #hit == 0 then
		return nil
	end
	-- the whole bench: its logs and legs (one bench is 5 studs long; the two stand on opposite sides)
	local parts: { BasePart } = {}
	for _, d in ctx.f:GetChildren() do
		if d:IsA("BasePart") and BENCH[d.Name] then
			for _, q in hit do
				if Vector2.new(d.Position.X - q.X, d.Position.Z - q.Z).Magnitude < 4.5 then
					table.insert(parts, d)
					break
				end
			end
		end
	end
	local keep: { Box } = {}
	for _, b in ctx.obstacles :: { Box } do
		local mine = false
		for _, p in (if b.bench then parts else {}) do
			mine = mine or (b.cf.Position - p.Position).Magnitude < 0.05
		end
		if not mine then
			table.insert(keep, b)
		end
	end
	ctx.obstacles = keep
	if #parts == 0 then
		return nil
	end
	local mid = Vector3.zero
	for _, p in parts do
		mid += p.Position
	end
	mid /= #parts
	local c = Vector3.new(ctx.base.X, 0, ctx.base.Z)
	for _, da in { 15, -15, 30, -30, 45, -45, 60, -60 } do
		local turn = CFrame.new(c) * CFrame.Angles(0, math.rad(da), 0) * CFrame.new(-c)
		local to = turn * mid
		local ok = clearOf(ctx, to, 3.6) and offArch(ctx, to, 3.2)
		for _, p in parts do
			ok = ok and paved(ctx, turn * p.Position)
		end
		if ok then
			for _, p in parts do
				p.CFrame = turn * p.CFrame
				local b = footprint(p.CFrame, p.Size)
				b.bench = true
				table.insert(ctx.obstacles :: { Box }, b)
			end
			return string.format("bench moved %+d", da)
		end
	end
	for _, p in parts do
		p:Destroy()
	end
	return "bench taken away"
end

-- The entrance arch where the path comes in, its two feet and the way through on the paving. Of the spots where it
]======] },
	{ [======[			end
		end
	end
	return room
]======], [======[			end
		end
	end
	for _, t in ctx.plazaTaken :: { Disc } do
		room = math.min(room, fromArch(cf, Vector3.new(t.at.X, 0, t.at.Y)) - t.r)
	end
	return room
]======] },
	{ [======[	for k = 0, 10 do
		local x = -9.1 + k * 1.82
		for _, z in { -1.8, 1.8 } do
			local p = cf * Vector3.new(x, 0, z)
			for _, b in ctx.obstacles :: { Box } do
				local lp = b.cf:PointToObjectSpace(Vector3.new(p.X, b.cf.Position.Y, p.Z))
				local dx, dz = math.max(0, math.abs(lp.X) - b.hx), math.max(0, math.abs(lp.Z) - b.hz)
				room = math.min(room, math.sqrt(dx * dx + dz * dz))
			end
			for _, t in ctx.plazaTaken :: { Disc } do
				room = math.min(room, Vector2.new(p.X - t.at.X, p.Z - t.at.Y).Magnitude - t.r)
			end
]======], [======[	for _, b in ctx.obstacles :: { Box } do
		if not b.bench then
			room = math.min(room, archGap(cf, b))
]======] },
	{ [======[-- How far an arch at cf (its posts and roof: 9.1 either side, 1.8 deep) keeps from the stalls, the pump, the benches
-- and what's been built on the plaza.
]======], [======[-- The arch's footprint (its posts and roof): 9.1 studs either side of its middle, 1.8 deep.
local ARCH_HX, ARCH_HZ = 9.1, 1.8

-- how far world point p is from the footprint of an arch at cf
local function fromArch(cf: CFrame, p: Vector3): number
	local l = cf:PointToObjectSpace(Vector3.new(p.X, cf.Position.Y, p.Z))
	local dx, dz = math.max(0, math.abs(l.X) - ARCH_HX), math.max(0, math.abs(l.Z) - ARCH_HZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- the gap between the footprint of an arch at cf and box b (two rectangles: from the corners of each to the other)
local function archGap(cf: CFrame, b: Box): number
	local g = math.huge
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			g = math.min(g, fromArch(cf, b.cf * Vector3.new(sx * b.hx, 0, sz * b.hz)))
		end
	end
	for k = 0, 10 do
		for _, z in { -ARCH_HZ, ARCH_HZ } do
			local p = cf * Vector3.new(-ARCH_HX + k * ARCH_HX / 5, 0, z)
			local lp = b.cf:PointToObjectSpace(Vector3.new(p.X, b.cf.Position.Y, p.Z))
			local dx, dz = math.max(0, math.abs(lp.X) - b.hx), math.max(0, math.abs(lp.Z) - b.hz)
			g = math.min(g, math.sqrt(dx * dx + dz * dz))
		end
	end
	return g
end

-- How far an arch at cf keeps from the stalls, the pump and what's been built on the plaza (a bench gives way).
]======] },
	{ [======[		if not outside(b, p, r) then
]======], [======[		if not (benchGoes and b.bench) and not outside(b, p, r) then
]======] },
	{ [======[-- nothing on the plaza within `r` of world point p
local function clearOf(ctx: Ctx, p: Vector3, r: number): boolean
]======], [======[-- nothing on the plaza within `r` of world point p (but a bench when `benchGoes`: it's moved off)
local function clearOf(ctx: Ctx, p: Vector3, r: number, benchGoes: boolean?): boolean
]======] },
	{ [======[		elseif d:IsA("BasePart") and not PAVING[d.Name] then
			add(d.CFrame, d.Size)
		end
]======], [======[		elseif d:IsA("BasePart") and not PAVING[d.Name] then
			add(d.CFrame, d.Size, BENCH[d.Name] == true)
		end
]======] },
	{ [======[	local function add(cf: CFrame, size: Vector3)
		table.insert(boxes, footprint(cf, size))
]======], [======[	local function add(cf: CFrame, size: Vector3, bench: boolean?)
		local b = footprint(cf, size)
		b.bench = bench
		table.insert(boxes, b)
]======] },
	{ [======[local PAVING = { Tile = true, TileBed = true, Plank = true, Footing = true, Step = true, WalkPlate = true }

]======], [======[local PAVING = { Tile = true, TileBed = true, Plank = true, Footing = true, Step = true, WalkPlate = true }
local BENCH = { Log = true, BenchLeg = true } -- server/Outposts' log benches

]======] },
	{ [======[type Box = { cf: CFrame, hx: number, hz: number }
]======], [======[type Box = { cf: CFrame, hx: number, hz: number, bench: boolean? }
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "51915 1212517591" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
