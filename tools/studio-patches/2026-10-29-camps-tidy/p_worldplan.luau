local m = game.ReplicatedStorage.MowALawn.WorldPlan
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "14212 1612703078" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[

	-- 6) grass patches: irregular blobs on each zone's floor, away from the landmark, gates and pads
]======], [======[

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
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "17547 1877402711" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
