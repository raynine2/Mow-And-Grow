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

put("CampDress.4", [====[-- round the plaza: the house, the tents, the landmark, the animals
-------------------------------------------------------------------------------------------------------------
local function house(ctx: Ctx)
	local spot = findSpot(ctx, -125, 31.5, 7.6, 7.2)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, 11)
	local cf = spot.cf
	if ctx.id == "swamp" then
		-- on stilts over the bog, a deck along its front and steps down
		local lift = 3.2
		for _, x in { -6.4, 0, 6.4 } do
			for _, z in { -5, 5 } do
				local h = spot.y + lift - spot.gmin + 0.6
				part(ctx.f, "Stilt", cf * CFrame.new(x, lift - h / 2, z), Vector3.new(0.9, h, 0.9), VoxelKit.jitter(ctx.rng, rgb(150, 120, 90), 0.06), "log", true)
			end
		end
		part(ctx.f, "Deck", cf * CFrame.new(0, lift - 0.2, -6.4), Vector3.new(14.4, 0.4, 3.4), rgb(130, 108, 78), Enum.Material.WoodPlanks, true)
		for i = 1, 4 do
			part(ctx.f, "DeckStep", cf * CFrame.new(0, lift - 0.4 - i * 0.8, -8.1 - i * 0.9), Vector3.new(3.4, 0.35, 0.95), rgb(118, 96, 70), Enum.Material.WoodPlanks, true)
		end
		cf = cf * CFrame.new(0, lift, 0)
	else
		footing(ctx, spot, 14.6, 12.4)
	end
	local m = place(ctx, "camp_house", cf, { collide = true })
	if m then
		smoke(m, if ctx.id == "ember" then rgb(120, 110, 106) else nil)
		lamps(ctx, m)
	end
	steppingStones(ctx, spot.cf.Position + spot.cf.LookVector * 7.5)
	-- flowers and barrels by the house
	VoxelKit.barrel(ctx.f, cf * CFrame.new(7.9, 0, -4.2), 2.2, ctx.rng)
	VoxelKit.crate(ctx.f, cf * CFrame.new(-8.0, 0.6, -3.6) * CFrame.Angles(0, 0.3, 0), 1.2, ctx.rng)
end

local function campfire(ctx: Ctx, cf: CFrame)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(ctx.f, "RingStone", cf * CFrame.new(math.cos(a) * 1.8, 0.35, math.sin(a) * 1.8) * CFrame.Angles(0, -a, 0), Vector3.new(0.9, 0.7, 0.8), VoxelKit.jitter(ctx.rng, ctx.roles.stone[2], 0.08), "stone")
	end
	VoxelKit.log(ctx.f, cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.rad(30), 0), 2.4, 0.5, 0.5, C.log)
	VoxelKit.log(ctx.f, cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(-40), 0), 2.4, 0.5, 0.5, C.log)
	local core = part(ctx.f, "Embers", cf * CFrame.new(0, 0.5, 0), Vector3.new(1, 0.3, 1), if ctx.id == "isles" then rgb(150, 220, 255) else rgb(255, 150, 60), Enum.Material.Neon)
	VoxelKit.fire(core, if ctx.id == "isles" then rgb(120, 180, 255) elseif ctx.id == "swamp" then rgb(150, 255, 110) else nil, 1.2)
end

local function tents(ctx: Ctx)
	local spot = findSpot(ctx, -55, 31, 7.5, 6)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, 10)
	footing(ctx, spot, 15, 12)
	local cf = spot.cf
	-- two tents round a fire, their doors toward it
	local fire = cf * CFrame.new(0, 0, -0.5)
	for _, x in { -4.6, 4.6 } do
		local p = (cf * CFrame.new(x, 0, 2.2)).Position
		place(ctx, "camp_tent", CFrame.lookAt(p, Vector3.new(fire.Position.X, p.Y, fire.Position.Z)) * CFrame.Angles(0, math.rad(x > 0 and -15 or 15), 0), { collide = true })
	end
	campfire(ctx, fire)
	local seat = cf * CFrame.new(0, 0, -4.4)
	VoxelKit.log(ctx.f, seat * CFrame.new(0, 0.45, 0), 3.4, 0.9, 0.9, C.log)
	villager(ctx, CFrame.lookAt((seat * CFrame.new(0.4, 0, 0)).Position, fire.Position) * CFrame.new(0, 0, 0), "sit", { outfit = 2 })
	VoxelKit.crate(ctx.f, cf * CFrame.new(5.6, 0.6, -3.2) * CFrame.Angles(0, 0.4, 0), 1.2, ctx.rng)
	VoxelKit.barrel(ctx.f, cf * CFrame.new(-5.8, 0, -3.0), 2.0, ctx.rng)
	steppingStones(ctx, spot.cf.Position + spot.cf.LookVector * 6)
end

-- a flat floor (a pen, a pond's bed) at `cf`: w x d
local function floor(ctx: Ctx, cf: CFrame, w: number, d: number, color: Color3, material: Enum.Material?)
	part(ctx.f, "PenFloor", cf * CFrame.new(0, 0.06, 0), Vector3.new(w, 0.12, d), color, material or Enum.Material.Ground, true)
end

local function fence(ctx: Ctx, cf: CFrame, w: number, d: number, gapFront: boolean?)
	local wood = ctx.roles.wood[2] :: Color3
	local corners = { Vector3.new(-w / 2, 0, -d / 2), Vector3.new(w / 2, 0, -d / 2), Vector3.new(w / 2, 0, d / 2), Vector3.new(-w / 2, 0, d / 2) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local along = (b - a).Unit
		local seg = CFrame.lookAt(mid, mid + along)
		if gapFront and i == 1 then
			-- a gate gap in the middle of the front side
			for _, s in { -1, 1 } do
				local m2 = mid + along * s * (len / 4 + 0.6)
				part(ctx.f, "Rail", cf * CFrame.lookAt(m2 + Vector3.new(0, 1.6, 0), m2 + Vector3.new(0, 1.6, 0) + along), Vector3.new(0.25, 0.25, len / 2 - 1.2), wood)
				part(ctx.f, "Rail", cf * CFrame.lookAt(m2 + Vector3.new(0, 0.9, 0), m2 + Vector3.new(0, 0.9, 0) + along), Vector3.new(0.25, 0.25, len / 2 - 1.2), wood)
			end
		else
			part(ctx.f, "Rail", cf * (seg + Vector3.new(0, 1.6, 0)), Vector3.new(0.25, 0.25, len), wood)
			part(ctx.f, "Rail", cf * (seg + Vector3.new(0, 0.9, 0)), Vector3.new(0.25, 0.25, len), wood)
		end
		part(ctx.f, "FencePost", cf * CFrame.new(a + Vector3.new(0, 1.0, 0)), Vector3.new(0.45, 2.0, 0.45), wood, "log", true)
	end
end

local function pond(ctx: Ctx, cf: CFrame, r: number, water: Color3, lily: boolean?)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		part(ctx.f, "PondStone", cf * CFrame.new(math.cos(a) * (r + 0.4), 0.3, math.sin(a) * (r + 0.4)) * CFrame.Angles(0, -a, 0), Vector3.new(1.0, 0.6, r * 0.62), VoxelKit.jitter(ctx.rng, ctx.roles.stone[2], 0.07), "stone")
	end
	local wtr = part(ctx.f, "PondWater", cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, r * 2, r * 2), water, Enum.Material.Glass)
	wtr.Shape = Enum.PartType.Cylinder
	wtr.Transparency = 0.25
	part(ctx.f, "PondBed", cf * CFrame.new(0, -0.05, 0), Vector3.new(r * 2, 0.1, r * 2), rgb(60, 70, 50), Enum.Material.Mud)
	if lily then
		for _ = 1, 5 do
			local a, d = ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(0.6, r - 0.8)
			local pad = part(ctx.f, "LilyPad", cf * CFrame.new(math.cos(a) * d, 0.23, math.sin(a) * d) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, 1.3, 1.3), rgb(90, 170, 70))
			pad.Shape = Enum.PartType.Cylinder
		end
	end
end

local function landmark(ctx: Ctx)
	local id = ctx.id
	local size = ({ wheat = 4.6, blossom = 6.0, pine = 4.0, swamp = 7.0, frost = 6.4, ember = 6.4, isles = 4.0 })[id :: string] or 5
	local spot = findSpot(ctx, 120, 31, size, size)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, size + 4)
	local cf = spot.cf
	local workAt: CFrame? = nil
	local workLook: Vector3? = nil
	if id == "swamp" then
		-- a pond with a jetty and a rowing boat (bobbing), frogs on the lily pads
		footing(ctx, spot, 14, 14)
		pond(ctx, cf * CFrame.new(0, 0, 1), 6.2, ctx.roles.water[2], true)
		for i = 0, 3 do
			part(ctx.f, "Jetty", cf * CFrame.new(-1.2, 0.55, -6.5 + i * 2.2), Vector3.new(2.6, 0.3, 2.1), VoxelKit.jitter(ctx.rng, rgb(130, 108, 78), 0.05), Enum.Material.WoodPlanks, true)
			for _, x in { -2.4, 0 } do
				part(ctx.f, "JettyPost", cf * CFrame.new(x, 0.2, -6.5 + i * 2.2), Vector3.new(0.4, 1.4, 0.4), rgb(110, 88, 64), "log")
			end
		end
		local boat = place(ctx, "camp_boat", cf * CFrame.new(2.6, 0.12, 2.2) * CFrame.Angles(0, math.rad(20), 0), { atomic = true })
		if boat then
			tag(boat, "CampBob", { Amp = 0.12, Freq = 0.35, Roll = 3 })
		end
		for _ = 1, 4 do
			critter(ctx, "critter_frog", (cf * CFrame.new(0, 0.62, 1)).Position, "hop", 5.4, 2.0, 0.85)
		end
		for i = 1, 6 do -- reeds
			local a = i / 6 * math.pi * 2 + 0.3
			local h = ctx.rng:NextNumber(2.2, 3.4)
			local base = cf * CFrame.new(math.cos(a) * 6.8, 0, 1 + math.sin(a) * 6.8)
			part(ctx.f, "Reed", base * CFrame.new(0, h / 2, 0), Vector3.new(0.15, h, 0.15), rgb(110, 150, 70))
			part(ctx.f, "Cattail", base * CFrame.new(0, h + 0.3, 0), Vector3.new(0.32, 0.8, 0.32), rgb(120, 80, 50))
		end
		workAt = cf * CFrame.new(-1.2, 0.7, -2.3) * CFrame.Angles(0, math.pi, 0)
	else
		footing(ctx, spot, size * 2 + 1, size * 2 + 1)
		local name = ({ wheat = "camp_windmill", blossom = "camp_pavilion", pine = "camp_watchtower", frost = "camp_igloo", ember = "camp_forge", isles = "camp_telescope" })[id :: string]
		local m = name and place(ctx, name, cf, { collide = true, atomic = true })
		if m then
			lamps(ctx, m, id == "blossom")
			smoke(m, rgb(110, 104, 100), 5)
			if id == "wheat" then
				tag(m, "CampSpin", { Group_Rotor = true, Axis = Vector3.new(0, 0, -1), Speed = 28 })
				for i = 1, 4 do
					VoxelKit.hay(ctx.f, cf * CFrame.new(-6 + i * 2.8, 0, 5.8) * CFrame.Angles(0, ctx.rng:NextNumber(-0.2, 0.2), 0), ctx.rng)
				end
				workAt = cf * CFrame.new(3.6, 0, -6.2)
			elseif id == "pine" then
				tag(m, "CampSway", { Group_Flag = true, Amp = 14, Phase = 0.3, Axis = Vector3.yAxis })
				for i = 0, 5 do
					VoxelKit.log(ctx.f, cf * CFrame.new(-6.5, 0.55 + math.floor(i / 3) * 1.0, -2 + (i % 3) * 1.1 + (if i >= 3 then 0.55 else 0)), 4.2, 1.0, 1.0, C.log)
				end
				workAt = cf * CFrame.new(-4.2, 0, -5.4)
			elseif id == "blossom" then
]====], "8908 181006670")
return "part 8/13 (CampDress.4): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
