local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "47955 1234471113" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	table.insert(ctx.placed :: { string }, "arch:none")
]======], [======[	local cf = best
	if not cf then
		table.insert(ctx.placed :: { string }, "arch:none")
		return
	end
	local m = place(ctx, "camp_arch", cf, { collide = true })
	if not m then
		return
	end
	-- no name board (owner, 29 Oct: "remove every slop part thats ugly like signs"): the board, its rim and chains hang
	-- between the posts under the beams
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
	ctx.archAt = cf
	table.insert(ctx.placed :: { string }, string.format("arch@%.0f/%.1f room %.1f", bestDeg, bestDist, bestRoom))
]======] },
	{ [======[				for _, x in (if pass == 1 then { -9.1, -6.6, -3.3, 3.3, 6.6, 9.1 } else { -6.6, 6.6 }) do
					ok = ok and clearOf(ctx, (cf * CFrame.new(x, 0, 0)).Position, if pass == 1 then 3.2 else 2.2)
				end
				if ok then
					local m = place(ctx, "camp_arch", cf, { collide = true })
					if not m then
						return
					end
					-- no name board (owner, 29 Oct: "remove every slop part thats ugly like signs"): the board, its rim
					-- and chains hang between the posts under the beams
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
					ctx.archAt = cf
					table.insert(ctx.placed :: { string }, string.format("arch@%.0f/%.1f%s", deg, dist, if pass == 2 then " (tight)" else ""))
					return
]======], [======[			end
			for _, x in { -6.6, 6.6 } do
				ok = ok and clearOf(ctx, (cf * CFrame.new(x, 0, 0)).Position, 2.2)
			end
			if ok then
				local room = roomAt(ctx, cf)
				local score = math.min(room, 4) - 0.02 * math.abs(da) - 0.15 * (ctx.R - 3.6 - dist)
				if score > bestScore + 0.01 then
					best, bestScore, bestDeg, bestDist, bestRoom = cf, score, deg, dist, room
]======] },
	{ [======[	for pass = 1, 2 do
		for _, dist in { ctx.R - 3.6, ctx.R - 4.8, ctx.R - 6, ctx.R - 7.5 } do
			for _, da in { 0, 12, -12, 24, -24, 36, -36 } do
				local deg = e + da
				local d = dirAt(ctx, deg)
				local p = ctx.base + d * dist
				local cf = CFrame.lookAt(p, p + d)
				local ok = clearOf(ctx, p, if pass == 1 then 3 else 2.5)
				for _, x in { -7.6, -5, -2.5, 0, 2.5, 5, 7.6 } do
					for _, z in { -1.1, 1.1 } do
						ok = ok and paved(ctx, (cf * CFrame.new(x, 0, z)).Position)
					end
]======], [======[	local best: CFrame?, bestScore, bestDeg, bestDist, bestRoom = nil, -math.huge, 0, 0, 0
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
]======] },
	{ [======[-- The entrance arch where the path comes in, its two feet and the way through on the paving: first with room all
-- round it (its posts and roof ends 3 studs clear of the stalls, the pump and the benches; owner, 29 Oct: "its very
-- messy and just cluttered"), else where it just fits.
]======], [======[-- How far an arch at cf (its posts and roof: 9.1 either side, 1.8 deep) keeps from the stalls, the pump, the benches
-- and what's been built on the plaza.
local function roomAt(ctx: Ctx, cf: CFrame): number
	local room = math.huge
	for k = 0, 10 do
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
		end
	end
	return room
end

-- The entrance arch where the path comes in, its two feet and the way through on the paving. Of the spots where it
-- fits, the one with the most room round it (up to 4 studs from the stalls, the pump and the benches; owner, 29 Oct:
-- "its very messy and just cluttered"), the nearer the path and the plaza's edge the better.
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "48860 915371797" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
