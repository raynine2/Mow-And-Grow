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

put("CampDress.5", [====[		local boat = place(ctx, "camp_boat", cf * CFrame.new(2.6, 0.12, 2.2) * CFrame.Angles(0, math.rad(20), 0), { atomic = true })
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
			lamps(ctx, m, id == "blossom")
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
		floor(ctx, cf, 11, 11, rgb(196, 166, 92), Enum.Material.Fabric)
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
		floor(ctx, cf, 11, 11, rgb(92, 76, 56))
		for i, p in { Vector3.new(-2.8, 0, 1.5), Vector3.new(2.8, 0, -1.5) } do
			local h = 2.8 + i * 0.6
			part(ctx.f, "Perch", cf * CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(0.8, h, 0.8), C.log, "log", true)
			local m = place(ctx, "critter_owl", cf * CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(0, ctx.rng:NextNumber(0, 6.28), 0), { atomic = true })
			if m then
				tag(m, "CampCritter", { Kind = "perch", Home = m:GetPivot().Position, Range = 0, Speed = 0, Seed = ctx.rng:NextInteger(1, 9999) })
			end
		end
	elseif id == "frost" then
		floor(ctx, cf, 12, 12, rgb(240, 246, 252), Enum.Material.Snow)
		for _ = 1, 3 do
			critter(ctx, "critter_penguin", home, "waddle", 4.6, 1.2, 0.9)
		end
	elseif id == "ember" then
		floor(ctx, cf, 11, 11, rgb(62, 56, 58), Enum.Material.Basalt)
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
-- The walk round the plaza: eight points on a circle with every step of the way paved and clear (the first circle
-- that works, nil if none does).
local function walkLoop(ctx: Ctx): { Vector3 }?
	for _, rr in { 17.5, 16, 19, 14.5, 20.5, 13 } do
		for _, off in { 0, 22.5 } do
			local pts = {}
			for k = 0, 7 do
				table.insert(pts, ctx.base + dirAt(ctx, k * 45 + off) * rr)
			end
			local ok = true
			for k = 1, 8 do
				local a, b = pts[k], pts[k % 8 + 1]
				local n = math.ceil((b - a).Magnitude / 1.25)
				for s = 0, n - 1 do
					ok = ok and onPlaza(ctx, a:Lerp(b, s / n), 1.0)
				end
			end
			if ok then
				return pts
			end
		end
	end
	return nil
end

local function people(ctx: Ctx)
	-- one by the stalls, looking out over the plaza
	local n = 0
	for _, s in { { -12.4, -9.4 }, { -11.5, -6.5 }, { 12.4, -9.4 }, { 11.5, -6.5 }, { -15, -5 }, { 15, -5 } } do
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
]====], "7252 444238242")
return "part 5/5 (CampDress.5): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
