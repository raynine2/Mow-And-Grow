local m = game.ServerScriptService.MowALawn.RunWorld
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "36716 756965663" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	print(("[RunWorld] %d area camps built"):format(require(script.Parent.Outposts).build(w, info, RunBuilder.gasPump)))
	local pads = w:FindFirstChild("Pads")
]======], [======[	print(("[RunWorld] %d area camps built"):format(require(script.Parent.Outposts).build(w, info, RunBuilder.gasPump)))
	print(("[RunWorld] %d squares of rim built up round the isles' void (holes in the map)"):format(sealRim(w)))
	local pads = w:FindFirstChild("Pads")
]======] },
	{ [======[

function RunWorld.build()
]======], [======[

-- (29 Oct, owner: "please fix open holes around map", a screenshot from the meadow's edge) The island's areas are
-- ringed by rim rock, but in a few places the rim has a gap: the void round the floating Starlight Isles (and the
-- sea under them) came right up to the meadow's floor, and the pine forest's floor ran out onto the sea. You looked
-- out of the map there, and could walk off it. Every floor square of the island next to the void or the sea gets
-- the rim built up beside it: the nearest rim rock's body and cap, cloned, from the sea bed up to the rim's height
-- there. The isles' own edges stay open (they float), and so do the gates, the ways between the areas and the isles'
-- bridges. Only the run's copy of the world changes.
local function sealRim(w: Instance): number
	local ground = w:FindFirstChild("Ground")
	local isles = nil
	for _, d in Zones.list do
		if d.floating then
			isles = d
		end
	end
	if not ground or not isles then
		return 0
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { ground }
	local c: Vector2 = isles.center
	-- the whole island, on the ground's 8-stud grid (its lines fall where a floor square's edges are: 4 off a
	-- multiple of 8 in the generated world)
	local px, pz = 4, 4
	for _, d in ground:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Floor" then
			px, pz = (d.Position.X - d.Size.X / 2) % 8, (d.Position.Z - d.Size.Z / 2) % 8
			break
		end
	end
	local wc: Vector2 = Zones.WORLD_CENTER
	local reach = Zones.COAST + 16
	local x0, z0 = math.floor((wc.X - reach - px) / 8) * 8 + px, math.floor((wc.Y - reach - pz) / 8) * 8 + pz
	local n = math.ceil(reach * 2 / 8)
	local top: { [number]: number } = {}
	local kind: { [number]: string } = {}
	local function key(i: number, j: number): number
		return i * 4096 + j
	end
	local function mid(i: number, j: number): Vector2
		return Vector2.new(x0 + j * 8 + 4, z0 + i * 8 + 4)
	end
	local t0 = os.clock()
	for i = 0, n do
		for j = 0, n do
			local p = mid(i, j)
			local hit = workspace:Raycast(Vector3.new(p.X, 400, p.Y), Vector3.new(0, -800, 0), rp)
			kind[key(i, j)] = if hit then hit.Instance.Name else "void"
			if hit then
				top[key(i, j)] = hit.Position.Y
			end
		end
		if os.clock() - t0 > 0.05 then
			task.wait()
			t0 = os.clock()
		end
	end
	-- the isles' own floor (they float: their edges stay open)
	local function onIsles(i: number, j: number): boolean
		local t = top[key(i, j)]
		return t ~= nil and t >= isles.base - 6 and (mid(i, j) - c).Magnitude < isles.radius + 24
	end
	-- the ways in and out stay open: the gates, the stairs and bridges between areas, the isles' bridges
	local keepOut: { { cf: CFrame, hx: number, hz: number } } = {}
	for _, name in { "Gates", "Ways", "IsleBridges" } do
		local fold = w:FindFirstChild(name)
		for _, d in (if fold then fold:GetDescendants() else {}) do
			if d:IsA("BasePart") then
				table.insert(keepOut, { cf = d.CFrame, hx = d.Size.X / 2 + 16, hz = d.Size.Z / 2 + 16 })
			end
		end
	end
	local function kept(p: Vector2): boolean
		for _, b in keepOut do
			local l = b.cf:PointToObjectSpace(Vector3.new(p.X, b.cf.Position.Y, p.Y))
			if math.abs(l.X) < b.hx and math.abs(l.Z) < b.hz then
				return true
			end
		end
		return false
	end
	-- the squares to build up, and the floor each one guards
	local want: { [number]: { i: number, j: number, floor: number } } = {}
	for i = 0, n do
		for j = 0, n do
			local k = key(i, j)
			if kind[k] == "Floor" and not onIsles(i, j) then
				for di = -1, 1 do
					for dj = -1, 1 do
						local k2 = key(i + di, j + dj)
						local open = kind[k2] == "void" or kind[k2] == "SeaFloor"
						if (di ~= 0 or dj ~= 0) and open and i + di >= 0 and j + dj >= 0 and i + di <= n and j + dj <= n and not kept(mid(i + di, j + dj)) then
							local had = want[k2]
							if not had or had.floor < (top[k] :: number) then
								want[k2] = { i = i + di, j = j + dj, floor = top[k] :: number }
							end
						end
					end
				end
			end
		end
	end
	local fold = Instance.new("Folder")
	fold.Name = "SealedRim"
	local made = 0
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ground }
	for _, cell in want do
		local p = mid(cell.i, cell.j)
		-- the rim next to it: how high it stands, and its rock to copy (cap and body)
		local rimTop: number? = nil
		for di = -3, 3 do
			for dj = -3, 3 do
				local k = key(cell.i + di, cell.j + dj)
				local mainRim = (mid(cell.i + di, cell.j + dj) - c).Magnitude > isles.radius
				if kind[k] == "Rock" and top[k] and mainRim and (not rimTop or (top[k] :: number) > rimTop) then
					rimTop = top[k]
				end
			end
		end
		local h = math.clamp(rimTop or (cell.floor + 34), cell.floor + 18, cell.floor + 52)
		-- (the mainland's rim, not the isles' purple rock)
		local cap: BasePart?, body: BasePart? = nil, nil
		local capD, bodyD = math.huge, math.huge
		for _, q in workspace:GetPartBoundsInRadius(Vector3.new(p.X, cell.floor + 20, p.Y), 110, params) do
			local q2 = Vector2.new(q.Position.X, q.Position.Z)
			local d = (q2 - p).Magnitude
			if (q2 - c).Magnitude > isles.radius then
				if q.Name == "Rock" and d < capD then
					cap, capD = q, d
				elseif q.Name == "RockSide" and d < bodyD then
					body, bodyD = q, d
				end
			end
		end
		local bottom = math.min(cell.floor - 30, Zones.SEA - 18)
		local function block(from: BasePart?, name: string, y0: number, y1: number)
			local b: BasePart
			if from then
				b = from:Clone()
				b:ClearAllChildren()
			else
				b = Instance.new("Part")
				b.Material = Enum.Material.Slate
				b.Color = Color3.fromRGB(70, 74, 66)
				b.Anchored = true
			end
			b.Name = name
			b.Size = Vector3.new(8, y1 - y0, 8)
			b.CFrame = CFrame.new(p.X, (y0 + y1) / 2, p.Y)
			b.Parent = fold
		end
		block(body, "RockSide", bottom, h - 1.2)
		block(cap, "Rock", h - 1.2, h)
		made += 1
	end
	fold.Parent = ground
	return made
end

function RunWorld.build()
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "42813 1016278721" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
