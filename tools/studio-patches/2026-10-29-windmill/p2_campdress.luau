local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "46639 415893255" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		if onPlaza(ctx, p, 1.1) then
]======], [======[		if onPlaza(ctx, p, 1.1) and offArch(ctx, p, 1.1) then
]======] },
	{ [======[					if onPlaza(ctx, p, 1.3) then
]======], [======[					if onPlaza(ctx, p, 1.3) and offArch(ctx, p, 1.3) then
]======] },
	{ [======[		for _, da in { 0, 8, -8, 16, -16 } do
]======], [======[		for _, da in { 0, 8, -8, 16, -16, 24, -24 } do
]======] },
	{ [======[	table.insert(ctx.placed :: { string }, "arch:none")
end
]======], [======[	table.insert(ctx.placed :: { string }, "arch:none")
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
end
]======] },
	{ [======[				-- no name board (owner, 29 Oct: "remove every slop part thats ugly like signs"): the board, its rim and
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
]======], [======[]======] },
	{ [======[			end
			for _, x in { -6.6, 6.6 } do
				ok = ok and clearOf(ctx, (cf * CFrame.new(x, 0, 0)).Position, 2.2)
			end
			if ok then
				local m = place(ctx, "camp_arch", cf, { collide = true })
				if not m then
]======], [======[				for _, x in (if pass == 1 then { -9.1, -6.6, -3.3, 3.3, 6.6, 9.1 } else { -6.6, 6.6 }) do
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
]======] },
	{ [======[	for _, dist in { ctx.R - 3.6, ctx.R - 4.8, ctx.R - 6, ctx.R - 7.5 } do
		for _, da in { 0, 12, -12, 24, -24, 36, -36 } do
			local deg = e + da
			local d = dirAt(ctx, deg)
			local p = ctx.base + d * dist
			local cf = CFrame.lookAt(p, p + d)
			local ok = clearOf(ctx, p, 2.5)
			for _, x in { -7.6, -5, -2.5, 0, 2.5, 5, 7.6 } do
				for _, z in { -1.1, 1.1 } do
					ok = ok and paved(ctx, (cf * CFrame.new(x, 0, z)).Position)
]======], [======[	for pass = 1, 2 do
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
]======] },
	{ [======[-- The entrance arch where the path comes in, its two feet and the way through on the paving.
]======], [======[-- The entrance arch where the path comes in, its two feet and the way through on the paving: first with room all
-- round it (its posts and roof ends 3 studs clear of the stalls, the pump and the benches; owner, 29 Oct: "its very
-- messy and just cluttered"), else where it just fits.
]======] },
	{ [======[	plazaTaken: { Disc }?, -- on the plaza: what this has built
	paveRay: RaycastParams?,
]======], [======[	plazaTaken: { Disc }?, -- on the plaza: what this has built
	archAt: CFrame?, -- on the plaza: the arch (front: out of the camp); its way through stays clear
	paveRay: RaycastParams?,
]======] },
	{ [======[--   * on the plaza: an entrance arch with the camp's name and four lamp posts;
]======], [======[--   * on the plaza: an entrance arch (room round it, its way through kept clear) and four lamp posts;
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "47955 1234471113" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
