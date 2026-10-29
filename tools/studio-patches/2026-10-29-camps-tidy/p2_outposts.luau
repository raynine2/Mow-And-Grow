local m = game.ServerScriptService.MowALawn.Outposts
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "22649 1525364530" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	local ground = { w:FindFirstChild("Ground") :: Instance }
	local arena = Config.BOSS_ARENAS and Config.BOSS_ARENAS[z]
]======], [======[	local ground = { w:FindFirstChild("Ground") :: Instance }
	levelPlaza(w, base, top, 1.5)
	local arena = Config.BOSS_ARENAS and Config.BOSS_ARENAS[z]
]======] },
	{ [======[	return if hit then hit.Position.Y else nil
end
]======], [======[	return if hit then hit.Position.Y else nil
end

-- (29 Oct, the camps "very messy": a plaza stopped wherever a terrace rose inside it) The terraces rising inside the
-- plaza (+ `margin`) are cut down to it, in the run's copy of the world: each ground block (World.Ground's "Floor" top
-- or "FloorSide" body, on the 8-stud grid) reaching above the paving there is split into its columns and those inside
-- are lowered. A world generated after 29 Oct already has a flat clearing there (shared/WorldPlan, step 5b).
local function levelPlaza(w: Instance, c: Vector3, top: number, margin: number)
	local ground = w:FindFirstChild("Ground")
	if not ground then
		return
	end
	local reach = R + margin
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ground }
	local around = workspace:GetPartBoundsInBox(CFrame.new(c.X, top + 40, c.Z), Vector3.new(reach * 2, 80, reach * 2), params)
	local G = Zones.CELL
	for _, p in around do
		local floor = p.Name == "Floor"
		if (floor or p.Name == "FloorSide") and p.Position.Y + p.Size.Y / 2 > top + 0.05 then
			local x0, z0 = p.Position.X - p.Size.X / 2, p.Position.Z - p.Size.Z / 2
			local nx, nz = math.max(1, math.floor(p.Size.X / G + 0.5)), math.max(1, math.floor(p.Size.Z / G + 0.5))
			local function inside(i: number, j: number): boolean
				return Vector2.new(x0 + (i + 0.5) * G - c.X, z0 + (j + 0.5) * G - c.Z).Magnitude <= reach
			end
			local i0, i1, j0, j1 = math.huge, -math.huge, math.huge, -math.huge
			for i = 0, nx - 1 do
				for j = 0, nz - 1 do
					if inside(i, j) then
						i0, i1, j0, j1 = math.min(i0, i), math.max(i1, i), math.min(j0, j), math.max(j1, j)
					end
				end
			end
			if i0 <= i1 then
				local pTop, pBottom = p.Position.Y + p.Size.Y / 2, p.Position.Y - p.Size.Y / 2
				-- a copy of the block over columns [ia, ib] x [ja, jb], from b up to t
				local function piece(ia: number, ib: number, ja: number, jb: number, t: number, b: number)
					if ia <= ib and ja <= jb and t - b > 0.05 then
						local q = p:Clone()
						q.Size = Vector3.new((ib - ia + 1) * G, t - b, (jb - ja + 1) * G)
						q.CFrame = CFrame.new(x0 + (ia + ib + 1) / 2 * G, (t + b) / 2, z0 + (ja + jb + 1) / 2 * G)
						q.Parent = p.Parent
					end
				end
				-- round the cut: four strips as they were
				piece(0, i0 - 1, 0, nz - 1, pTop, pBottom)
				piece(i1 + 1, nx - 1, 0, nz - 1, pTop, pBottom)
				piece(i0, i1, 0, j0 - 1, pTop, pBottom)
				piece(i0, i1, j1 + 1, nz - 1, pTop, pBottom)
				-- in it, column by column: the top layer down to the ground under the pad (just below the paving), the
				-- body under it stopping below that
				local g = top - 0.02
				for i = i0, i1 do
					for j = j0, j1 do
						if not inside(i, j) then
							piece(i, i, j, j, pTop, pBottom)
						elseif floor then
							piece(i, i, j, j, g, g - p.Size.Y)
						else
							piece(i, i, j, j, math.min(pTop, g - 1.2), pBottom)
						end
					end
				end
				p:Destroy()
			end
		end
	end
end
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "25651 457739061" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
