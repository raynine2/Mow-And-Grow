-- The world's layout as plain data, worked out from shared/Zones: a height and kind for every 8 x 8 stud column,
-- the stairs and bridges between zones, the gates, teleport pads, grass patches and landmark spots.
-- server/WorldGen turns this into parts. No Instances here, so it also runs outside Roblox (tools/worldplan.luau
-- draws it as a picture to check the layout).
--
-- Column kinds: "zone" (a zone's or the village's terraces), "rock" (the natural rim between zones),
-- "sea", "chasm" (a gorge under a bridge), "cut" (rock lowered under a stair corridor), "void" (empty air,
-- around the floating isles).
local WorldPlan = {}

export type Cell = { kind: string, h: number, region: number?, near: number, forest: boolean? }
export type Corridor = {
	zone: number, -- the zone this corridor leads INTO
	from: number, -- the region it comes from
	a: Vector2, -- start (inside `from`)
	b: Vector2, -- end (inside `zone`)
	ha: number,
	hb: number,
	width: number,
	gate: string, -- Zones.GATES key
	chasm: boolean,
	bottom: string?,
}

-------------------------------------------------------------------------------------------------------------
-- noise (our own, so the plan is identical everywhere)
-------------------------------------------------------------------------------------------------------------
local function hash2(ix: number, iz: number, seed: number): number
	local n = (ix * 374761393 + iz * 668265263 + seed * 2246822519) % 4294967296
	n = (n * 1274126177) % 4294967296
	n = (n + (n // 65536) * 31) % 4294967296
	return (n % 100000) / 100000
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- value noise in [-1, 1]
local function vnoise(x: number, z: number, seed: number): number
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = smooth(x - ix), smooth(z - iz)
	local a = hash2(ix, iz, seed)
	local b = hash2(ix + 1, iz, seed)
	local c = hash2(ix, iz + 1, seed)
	local d = hash2(ix + 1, iz + 1, seed)
	local top = a + (b - a) * fx
	local bot = c + (d - c) * fx
	return (top + (bot - top) * fz) * 2 - 1
end

local function fbm(x: number, z: number, seed: number): number
	return vnoise(x, z, seed) * 0.65 + vnoise(x * 2.1, z * 2.1, seed + 17) * 0.35
end
WorldPlan.noise = fbm
WorldPlan.hash = hash2

local function quant(h: number, step: number): number
	return math.floor(h / step + 0.5) * step
end

-- A tiny seeded random number source.
local function rng(seed: number)
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function(): number
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end
WorldPlan.rng = rng

-------------------------------------------------------------------------------------------------------------
-- the plan
-------------------------------------------------------------------------------------------------------------
function WorldPlan.make(Z: any)
	local CELL, STEP = Z.CELL, Z.STEP
	local B = Z.BOUNDS
	local nx = math.floor((B.maxX - B.minX) / CELL)
	local nz = math.floor((B.maxZ - B.minZ) / CELL)
	local n = #Z.list
	local plan: any = { nx = nx, nz = nz, cells = {}, corridors = {}, pads = {}, patches = {}, islands = {} }

	local function centre(i: number, j: number): Vector2
		return Vector2.new(B.minX + (i - 0.5) * CELL, B.minZ + (j - 0.5) * CELL)
	end
	local function cellAt(p: Vector2): (number, number)
		return math.floor((p.X - B.minX) / CELL) + 1, math.floor((p.Y - B.minZ) / CELL) + 1
	end
	plan.centre = centre
	plan.cellAt = cellAt

	local function get(i: number, j: number): Cell?
		local col = plan.cells[i]
		return col and col[j]
	end
	plan.get = get

	-- the floating isles: blobs inside the last zone
	local isleZone = nil
	for zi, def in Z.list do
		if def.floating then
			isleZone = zi
			local c = def.center
			plan.islands = {
				{ c = c, r = 68 },
				{ c = c + Vector2.new(-105, 35), r = 40 },
				{ c = c + Vector2.new(86, -62), r = 40 },
				{ c = c + Vector2.new(62, 97), r = 38 },
				{ c = c + Vector2.new(-62, -95), r = 40 },
			}
		end
	end
	local function onIsland(p: Vector2): boolean
		for k, isl in plan.islands do
			local d = p - isl.c
			local a = math.atan2(d.Y, d.X)
			local wob = 1 + 0.12 * math.sin(4 * a + k) + 0.06 * math.sin(7 * a + k * 2)
			if d.Magnitude < isl.r * wob then
				return true
			end
		end
		return false
	end

	-- 1) every column: which region, and its first height
	for i = 1, nx do
		plan.cells[i] = {}
		for j = 1, nz do
			local p = centre(i, j)
			local region, d = Z.regionAt(p)
			-- nearest region even when outside all of them (for rock colour and height)
			local near, nearD = 0, math.huge
			for r = 0, n do
				local dd = Z.normDist(r, p)
				if dd < nearD then
					near, nearD = r, dd
				end
			end
			local cell: Cell
			local fromMiddle = (p - Z.WORLD_CENTER).Magnitude
			if region ~= nil and region == isleZone then
				if onIsland(p) then
					local def = Z.list[region]
					local h = def.base + def.amp * fbm(p.X * def.freq, p.Y * def.freq, region * 101)
					cell = { kind = "zone", h = quant(h, STEP), region = region, near = region }
				else
					cell = { kind = "void", h = -20, region = nil, near = region }
				end
			elseif region ~= nil then
				local def = Z.region(region)
				local h = def.base
				if def.amp and def.amp > 0 then
					h += def.amp * fbm(p.X * def.freq, p.Y * def.freq, region * 101)
				end
				cell = { kind = "zone", h = quant(h, STEP), region = region, near = region }
			elseif fromMiddle > Z.COAST or (near == isleZone and nearD < 1.75) then
				cell = { kind = "sea", h = -20, region = nil, near = near }
			else
				cell = { kind = "rock", h = 0, region = nil, near = near }
			end
			plan.cells[i][j] = cell
		end
	end

	-- 2) terraces: no zone column more than one step above or below its zone neighbours (walkable everywhere)
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for _ = 1, 24 do
		local changed = false
		for i = 1, nx do
			for j = 1, nz do
				local c = plan.cells[i][j]
				if c.kind == "zone" then
					for _, dv in dirs do
						local o = get(i + dv[1], j + dv[2])
						if o and o.kind == "zone" and o.region == c.region then
							if c.h > o.h + STEP then
								c.h = o.h + STEP
								changed = true
							end
						end
					end
				end
			end
		end
		if not changed then
			break
		end
	end
	-- and no pits: a column at most one step below its highest zone neighbour
	for _ = 1, 24 do
		local changed = false
		for i = 1, nx do
			for j = 1, nz do
				local c = plan.cells[i][j]
				if c.kind == "zone" then
					for _, dv in dirs do
						local o = get(i + dv[1], j + dv[2])
						if o and o.kind == "zone" and o.region == c.region and c.h < o.h - STEP then
							c.h = o.h - STEP
							changed = true
						end
					end
				end
			end
		end
		if not changed then
			break
		end
	end

	-- zones never touch: a column next to another region's column turns to rock (only gates join zones)
	local border = {}
	for i = 1, nx do
		for j = 1, nz do
			local c = plan.cells[i][j]
			if c.kind == "zone" then
				for di = -2, 2 do
					for dj = -2, 2 do
						local o = get(i + di, j + dj)
						if o and o.kind == "zone" and o.region ~= c.region then
							table.insert(border, c)
						end
					end
				end
			end
		end
	end
	for _, c in border do
		c.kind = "rock"
		c.region = nil
	end

	-- 3) rock: a rim at least 10 studs above any zone floor within 3 columns, higher and rougher further out
	for i = 1, nx do
		for j = 1, nz do
			local c = plan.cells[i][j]
			if c.kind == "rock" then
				local top = -math.huge
				for di = -4, 4 do
					for dj = -4, 4 do
						local o = get(i + di, j + dj)
						if o and o.kind == "zone" and o.h > top then
							top = o.h
						end
					end
				end
				local p = centre(i, j)
				local rough = fbm(p.X / 40, p.Y / 40, 7)
				if top > -math.huge then
					c.forest = true
					c.h = quant(top + 12 + 2 * rough, 4)
				else
					local def = Z.region(c.near)
					c.h = quant(def.base + 18 + 10 * fbm(p.X / 110, p.Y / 110, 3), 6)
				end
			end
		end
	end

	-- 4) corridors: one per zone, from the region before it; stairs (or a bridge) through the rock between them
	local function heightAt(p: Vector2): number
		local i, j = cellAt(p)
		local c = get(i, j)
		return c and c.h or 0
	end
	-- the last point of region `from`'s floor on the way from its middle toward `toward`
	local function edge(from: number, toward: Vector2): Vector2
		local c = Z.region(from).center
		local dir = (toward - c).Unit
		local p = c
		for _ = 1, 400 do
			local q = p + dir * 2
			local i, j = cellAt(q)
			local cell = get(i, j)
			if not cell or cell.kind ~= "zone" or cell.region ~= from then
				break
			end
			p = q
		end
		return p
	end
	for zi = 1, n do
		local def = Z.list[zi]
		local fromIdx = zi - 1
		local fromC, toC = Z.region(fromIdx).center, def.center
		local dir = (toC - fromC).Unit
		local a0 = edge(fromIdx, toC)
		local b0 = edge(zi, fromC)
		local a = a0 - dir * 10
		local b = b0 + dir * 10
		local gateDef = Z.GATES[def.gate]
		local width = if def.gate == "open" then 28 else 16
		local ha = heightAt(a)
		local hb
		if def.floating then
			-- the stones climb to the nearest island's edge
			b = edge(zi, fromC)
			local best, bestD = nil, math.huge
			for _, isl in plan.islands do
				local d = (isl.c - a).Magnitude - isl.r
				if d < bestD then
					best, bestD = isl, d
				end
			end
			local toIsle = (best.c - a).Unit
			b = best.c - toIsle * (best.r * 0.8)
			hb = def.base
		else
			hb = heightAt(b)
		end
		-- stairs rise at most 2 studs every 5: a steep way in starts further back on both sides
		local need = math.abs(hb - ha) * 2.5
		local have = (b - a).Magnitude
		if need > have and not def.floating then
			local extra = (need - have) / 2 + 4
			a -= dir * extra
			b += dir * extra
			ha, hb = heightAt(a), heightAt(b)
		end
		local cor: Corridor = { zone = zi, from = fromIdx, a = a, b = b, ha = ha, hb = hb, width = width, gate = def.gate, chasm = gateDef.chasm, bottom = gateDef.bottom }
		table.insert(plan.corridors, cor)

		-- carve the rock under it
		local seg = b - a
		local len = seg.Magnitude
		local lo = math.min(ha, hb)
		local i0, j0 = cellAt(Vector2.new(math.min(a.X, b.X) - width, math.min(a.Y, b.Y) - width))
		local i1, j1 = cellAt(Vector2.new(math.max(a.X, b.X) + width, math.max(a.Y, b.Y) + width))
		for i = math.max(1, i0), math.min(nx, i1) do
			for j = math.max(1, j0), math.min(nz, j1) do
				local c = plan.cells[i][j]
				if c.kind == "rock" then
					local p = centre(i, j)
					local t = math.clamp((p - a):Dot(seg) / (len * len), 0, 1)
					local closest = a + seg * t
					if (p - closest).Magnitude <= width / 2 + 2 then
						if cor.chasm then
							c.kind = "chasm"
							c.h = quant(lo - 22, STEP)
						else
							c.kind = "cut"
							c.h = quant(lo - 2, STEP)
						end
					end
				end
			end
		end
	end

	-- 5) drop-off shredders: one in every area after the first, a little way in from its gate (Chop A Forest has
	-- one out in the map, so you don't walk all the way back to the hub to sell)
	for zi = 2, n do
		local cor = plan.corridors[zi]
		local def = Z.list[zi]
		local dir = (def.center - cor.b).Unit
		local p = cor.b + dir * 46 + Vector2.new(-dir.Y, dir.X) * 22
		if def.floating then
			p = plan.islands[1].c + Vector2.new(-30, 0)
		end
		table.insert(plan.pads, { kind = "dropoff", zone = zi, at = p, h = heightAt(p) })
	end

	-- 5b) a flat clearing round every drop-off pad (owner, 29 Oct: the remade area camps looked "very messy": their
	-- plaza stopped at the terraces and pieces stood half in a slope). The pad's zone columns within CAMP_FLAT of it
	-- take one height (the pad's, or the nearest one the gates' stairs allow); round it the ground steps back to its
	-- own height one terrace a column, so everything stays walkable. The columns where a corridor (a gate's stairs)
	-- starts or ends keep their height.
	local CAMP_FLAT = 30
	local fixed: { [any]: number } = {}
	for _, cor in plan.corridors do
		for _, e in { cor.a, cor.b } do
			local i0, j0 = cellAt(e - Vector2.new(14, 14))
			local i1, j1 = cellAt(e + Vector2.new(14, 14))
			for i = i0, i1 do
				for j = j0, j1 do
					local c = get(i, j)
					if c and c.kind == "zone" and (centre(i, j) - e).Magnitude <= 14 then
						fixed[c] = c.h
					end
				end
			end
		end
	end
	-- the lowest and highest each column of `box` may be: within a step a column of every column in `fix` (through
	-- one zone's floor)
	local function bounds(box: { number }, fix: { [any]: number }): ({ [any]: number }, { [any]: number })
		local lo: { [any]: number }, hi: { [any]: number } = {}, {}
		for c, h in fix do
			lo[c], hi[c] = h, h
		end
		for _ = 1, 16 do
			local changed = false
			for i = box[1], box[3] do
				for j = box[2], box[4] do
					local c = get(i, j)
					if c and c.kind == "zone" and fix[c] == nil then
						for _, dv in dirs do
							local o = get(i + dv[1], j + dv[2])
							if o and o.kind == "zone" and o.region == c.region and lo[o] then
								if lo[c] == nil or lo[o] - STEP > lo[c] then
									lo[c] = lo[o] - STEP
									changed = true
								end
								if hi[c] == nil or hi[o] + STEP < hi[c] then
									hi[c] = hi[o] + STEP
									changed = true
								end
							end
						end
					end
				end
			end
			if not changed then
				break
			end
		end
		return lo, hi
	end
	for _, pad in plan.pads do
		if pad.kind == "dropoff" then
			local reach = CAMP_FLAT + 80
			local i0, j0 = cellAt(pad.at - Vector2.new(reach, reach))
			local i1, j1 = cellAt(pad.at + Vector2.new(reach, reach))
			local box = { math.max(1, i0), math.max(1, j0), math.min(nx, i1), math.min(nz, j1) }
			local loK, hiK = bounds(box, fixed)
			-- the clearing's height: the pad's, or the nearest the fixed columns allow (a smaller clearing if none does)
			for flatR = CAMP_FLAT, 22, -4 do
				local disc = {}
				local lmin, lmax = -math.huge, math.huge
				for i = box[1], box[3] do
					for j = box[2], box[4] do
						local c = get(i, j)
						if c and c.kind == "zone" and c.region == pad.zone and fixed[c] == nil and (centre(i, j) - pad.at).Magnitude <= flatR then
							table.insert(disc, c)
							lmin = math.max(lmin, loK[c] or -math.huge)
							lmax = math.min(lmax, hiK[c] or math.huge)
						end
					end
				end
				if #disc > 0 and lmin <= lmax then
					pad.h = math.clamp(pad.h, lmin, lmax)
					local fix = table.clone(fixed)
					for _, c in disc do
						fix[c] = pad.h
					end
					local lo, hi = bounds(box, fix)
					for i = box[1], box[3] do
						for j = box[2], box[4] do
							local c = get(i, j)
							if c and c.kind == "zone" and lo[c] then
								c.h = math.clamp(c.h, lo[c], hi[c])
							end
						end
					end
					break
				end
			end
		end
	end

	-- 6) grass patches: irregular blobs on each zone's floor, away from the landmark, gates and pads
	for zi, def in Z.list do
		local R = rng(zi * 7919 + 13)
		local chosen = {}
		local tries = 0
		local want = if def.floating then 8 else 11
		while #chosen < want and tries < 600 do
			tries += 1
			local ang = R() * math.pi * 2
			local dist = math.sqrt(R()) * def.radius * 0.78
			local p = def.center + Vector2.new(math.cos(ang), math.sin(ang)) * dist
			local i, j = cellAt(p)
			local c = get(i, j)
			local ok = c ~= nil and c.kind == "zone" and c.region == zi and Z.normDist(zi, p) < 0.82
			if ok and def.landmark and (p - def.landmark.at).Magnitude < 34 then
				ok = false
			end
			for _, pad in plan.pads do
				if ok and (p - pad.at).Magnitude < 30 then
					ok = false
				end
			end
			for _, cor in plan.corridors do
				if ok and ((p - cor.a).Magnitude < 34 or (p - cor.b).Magnitude < 34) then
					ok = false
				end
			end
			for _, q in chosen do
				if ok and (p - q.at).Magnitude < 52 then
					ok = false
				end
			end
			if ok then
				local r = 17 + R() * 10
				local blobs = { { at = p, r = r } }
				for k = 1, 3 do
					local a2 = R() * math.pi * 2
					table.insert(blobs, { at = p + Vector2.new(math.cos(a2), math.sin(a2)) * r * (0.55 + R() * 0.3), r = r * (0.45 + R() * 0.25) })
				end
				table.insert(chosen, { zone = zi, at = p, blobs = blobs })
			end
		end
		for _, q in chosen do
			table.insert(plan.patches, q)
		end
	end

	return plan
end

-- Merge columns into rectangles of the same kind, height and look (greedy), so the ground is a few thousand
-- parts instead of tens of thousands. `key(cell)` returns the look key or nil to skip.
function WorldPlan.rects(plan: any, key: (any) -> string?): { { i: number, j: number, w: number, d: number, cell: any, key: string } }
	local nx, nz = plan.nx, plan.nz
	local used = {}
	for i = 1, nx do
		used[i] = {}
	end
	local out = {}
	for j = 1, nz do
		for i = 1, nx do
			if not used[i][j] then
				local c = plan.cells[i][j]
				local k = key(c)
				if k then
					-- grow along x
					local w = 1
					while i + w <= nx and not used[i + w][j] and key(plan.cells[i + w][j]) == k and plan.cells[i + w][j].h == c.h do
						w += 1
					end
					-- grow along z while the whole row matches
					local d = 1
					while j + d <= nz do
						local okRow = true
						for ii = i, i + w - 1 do
							local o = plan.cells[ii][j + d]
							if used[ii][j + d] or key(o) ~= k or o.h ~= c.h then
								okRow = false
								break
							end
						end
						if not okRow then
							break
						end
						d += 1
					end
					for ii = i, i + w - 1 do
						for jj = j, j + d - 1 do
							used[ii][jj] = true
						end
					end
					table.insert(out, { i = i, j = j, w = w, d = d, cell = c, key = k })
				end
			end
		end
	end
	return out
end

return WorldPlan
