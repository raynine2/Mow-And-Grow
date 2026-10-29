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

put("CampDress.5", [====[				VoxelKit.bush(ctx.f, cf * CFrame.new(-6.4, 0, 3), rgb(255, 170, 214), ctx.rng, { rgb(255, 255, 255) })
				VoxelKit.bush(ctx.f, cf * CFrame.new(6.4, 0, 3), rgb(255, 170, 214), ctx.rng, { rgb(255, 255, 255) })
				workAt = cf * CFrame.new(4.0, 0, -7.0)
			elseif id == "frost" then
				place(ctx, "camp_snowman", cf * CFrame.new(-6.2, 0, -3.5) * CFrame.Angles(0, math.rad(25), 0), { collide = true })
				VoxelKit.rocks(ctx.f, cf * CFrame.new(5.6, 0, 3.6), rgb(232, 240, 250), ctx.rng, 3)
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
				for i = 1, 3 do
					local c = Instance.new("Model")
					c.Name = "FloatCrystal"
					local a = i / 3 * math.pi * 2
					local spotCf = cf * CFrame.new(math.cos(a) * 5.4, 4.5 + i, math.sin(a) * 5.4)
					VoxelKit.crystals(c, spotCf, if i == 2 then rgb(255, 222, 122) else rgb(170, 120, 255), ctx.rng, 3, i == 1)
					c.WorldPivot = spotCf
					c.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
					c.Parent = ctx.f
					tag(c, "CampBob", { Amp = 0.7, Freq = 0.2 + i * 0.05, Spin = 12 })
				end
				workAt = cf * CFrame.new(-2.6, 1.0, -3.6)
			end
		end
	end
	if workAt then
		local p = workAt.Position
		local target = workLook or cf.Position
		local look = Vector3.new(target.X, p.Y, target.Z)
		villager(ctx, CFrame.lookAt(p, if (look - p).Magnitude > 0.5 then look else p + workAt.LookVector), "work", { work = AREA_WORK[id :: string], outfit = 1 })
	end
	steppingStones(ctx, spot.cf.Position + spot.cf.LookVector * (size + 1))
end

local function animals(ctx: Ctx)
	local id = ctx.id
	local spot = findSpot(ctx, 55, 30.5, 6, 6)
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
		place(ctx, "camp_scarecrow", cf * CFrame.new(3.2, 0, 3.2) * CFrame.Angles(0, math.rad(200), 0))
		VoxelKit.hay(ctx.f, cf * CFrame.new(-3.0, 0, 3.6), ctx.rng)
		for _ = 1, 5 do
			critter(ctx, "critter_chicken", home, "walk", 4.2, 1.6, 0.9)
		end
	elseif id == "blossom" then
		pond(ctx, cf, 5.2, rgb(110, 170, 210), true)
		for _ = 1, 4 do
			critter(ctx, "critter_koi", home + Vector3.new(0, 0.05, 0), "swim", 3.8, 1.6, 1.0)
		end
		VoxelKit.planter(ctx.f, cf * CFrame.new(0, 0, -6.4), 6, { rgb(255, 140, 190), rgb(255, 255, 255) }, ctx.rng)
	elseif id == "pine" then
		floor(ctx, cf, 11, 11, rgb(92, 76, 56))
		for i, p in { Vector3.new(-3, 0, 2), Vector3.new(2.5, 0, -2), Vector3.new(3.5, 0, 3) } do
			local h = 2.6 + i * 0.5
			part(ctx.f, "Perch", cf * CFrame.new(p + Vector3.new(0, h / 2, 0)), Vector3.new(0.8, h, 0.8), C.log, "log", true)
			if i ~= 2 then
				local m = place(ctx, "critter_owl", cf * CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(0, ctx.rng:NextNumber(0, 6.28), 0), { atomic = true })
				if m then
					tag(m, "CampCritter", { Kind = "perch", Home = m:GetPivot().Position, Range = 0, Speed = 0, Seed = ctx.rng:NextInteger(1, 9999) })
				end
			end
		end
		VoxelKit.bush(ctx.f, cf * CFrame.new(-2.5, 0, -3), C.leaf, ctx.rng)
	elseif id == "swamp" then
		floor(ctx, cf, 11, 11, rgb(86, 74, 52), Enum.Material.Mud)
		for _ = 1, 5 do
			local a = ctx.rng:NextNumber(0, 6.28)
			local h = ctx.rng:NextNumber(1.4, 3.4)
			local p = cf * CFrame.new(math.cos(a) * ctx.rng:NextNumber(1, 4.5), 0, math.sin(a) * ctx.rng:NextNumber(1, 4.5))
			part(ctx.f, "MushStem", p * CFrame.new(0, h / 2, 0), Vector3.new(0.7, h, 0.7), rgb(236, 226, 206))
			part(ctx.f, "MushCap", p * CFrame.new(0, h + 0.3, 0), Vector3.new(h * 0.9, 0.7, h * 0.9), if ctx.rng:NextNumber() < 0.5 then rgb(200, 60, 60) else rgb(150, 90, 200))
		end
		for _ = 1, 2 do
			critter(ctx, "critter_frog", home, "hop", 4.2, 2.0, 0.85)
		end
	elseif id == "frost" then
		floor(ctx, cf, 12, 12, rgb(240, 246, 252), Enum.Material.Snow)
		for _ = 1, 4 do
			critter(ctx, "critter_penguin", home, "waddle", 4.6, 1.2, 0.9)
		end
		for i = 1, 3 do
			part(ctx.f, "IceBlock", cf * CFrame.new(-4 + i * 2, 0.5, 4.6) * CFrame.Angles(0, i, 0), Vector3.new(1.4, 1.0, 1.2), rgb(170, 220, 255), Enum.Material.Ice)
		end
	elseif id == "ember" then
		floor(ctx, cf, 11, 11, rgb(62, 56, 58), Enum.Material.Basalt)
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2
			part(ctx.f, "LavaCrack", cf * CFrame.new(math.cos(a) * 2.2, 0.14, math.sin(a) * 2.2) * CFrame.Angles(0, a, 0), Vector3.new(3.4, 0.06, 0.3), rgb(255, 120, 40), Enum.Material.Neon)
		end
		VoxelKit.rocks(ctx.f, cf * CFrame.new(-3.4, 0, -3.2), rgb(70, 62, 64), ctx.rng, 3)
		VoxelKit.crystals(ctx.f, cf * CFrame.new(3.6, 0, 3.4), rgb(255, 120, 40), ctx.rng, 3, true)
		for _ = 1, 3 do
			critter(ctx, "critter_lizard", home, "crawl", 4.2, 1.4, 1.0)
		end
	elseif id == "isles" then
		VoxelKit.crystals(ctx.f, cf, rgb(170, 120, 255), ctx.rng, 6, true)
		for _ = 1, 6 do
			wisp(ctx, home, 6)
		end
	end
	steppingStones(ctx, spot.cf.Position + spot.cf.LookVector * 6.5)
end

-------------------------------------------------------------------------------------------------------------
-- the air
-------------------------------------------------------------------------------------------------------------
local AIR: { [string]: { any } } = {
	-- { texture, colour, size, rate, lifetime, speed, from above?, light emission, transparency }
	wheat = { "glow", rgb(255, 230, 140), 0.18, 10, 9, 0.6, false, 0.6, 0.35 },
	blossom = { "spark", rgb(255, 170, 210), 0.35, 12, 9, 2.0, true, 0.2, 0.15 },
	pine = { "smoke", rgb(222, 232, 226), 9, 2, 12, 0.4, false, 0, 0.88 },
	swamp = { "glow", rgb(196, 255, 120), 0.3, 9, 6, 0.5, false, 1, 0.1 },
	frost = { "spark", rgb(250, 252, 255), 0.3, 26, 10, 3.5, true, 0.3, 0.1 },
	ember = { "spark", rgb(255, 140, 60), 0.22, 12, 4, 2.6, false, 1, 0.1 },
	isles = { "glow", rgb(200, 230, 255), 0.35, 10, 3, 0.25, false, 1, 0.2 },
}

local function air(ctx: Ctx)
	local a = AIR[ctx.id :: string]
	if not a then
		return
	end
	local above = a[7] == true
	local box = part(ctx.f, "CampAir", CFrame.new(ctx.base + UP * (if above then 26 else 3.5)), Vector3.new(ctx.R * 2.6, if above then 1 else 6, ctx.R * 2.6), Color3.new(1, 1, 1))
	box.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Air"
	e.Texture = FxIds[a[1]] or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(a[2])
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, a[3]), NumberSequenceKeypoint.new(1, a[3] * 0.8) })
	e.Rate = a[4]
	e.Lifetime = NumberRange.new(a[5] * 0.7, a[5])
	e.Speed = NumberRange.new(a[6] * 0.6, a[6])
	e.LightEmission = a[8]
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, a[9]), NumberSequenceKeypoint.new(0.85, a[9]), NumberSequenceKeypoint.new(1, 1) })
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = if above then Enum.NormalId.Bottom else Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(35, 35)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Acceleration = if ctx.id == "ember" then Vector3.new(0.4, 1.0, 0.2) else Vector3.new(0.5, if above then -0.3 else 0.05, 0.3)
	e.Parent = box
end

-------------------------------------------------------------------------------------------------------------
-- dressing one camp
-------------------------------------------------------------------------------------------------------------
-- The villagers' walk round the plaza (local x right, z toward the area's middle), clear of the stalls, pump,
-- benches, well and cart.
local LOOP = { { 0, 16 }, { 10, 13.5 }, { 19.5, 1 }, { 17, -14 }, { 0, -17.5 }, { -17, -14 }, { -21, 1 }, { -17, 13 } }

function CampDress.dress(ctx: Ctx)
	local def = Zones.list[ctx.z]
	ctx.id = def and def.id or "wheat"
	ctx.roles = rolesFor(ctx.id :: string)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ctx.w:FindFirstChild("Ground") :: Instance }
	ctx.ground = params
	collectBlocked(ctx)
	-- the plaza's pieces
	arch(ctx, if def then def.name else "")
	signpost(ctx)
	place(ctx, "camp_noticeboard", at(ctx, 6.8, ctx.R - 4.6, -ctx.fwd), { collide = true })
	place(ctx, "camp_well", at(ctx, -15.5, -6), { collide = true })
	place(ctx, "camp_cart", at(ctx, 17, 10, -ctx.right), { collide = true })
	for i, deg in { 48, -48, 155, -155 } do
		banner(ctx, deg, i * 0.7)
	end
	if ctx.lanternPost then
		for _, deg in { 32, -32, 70, -70, 100, -100, 170, -170 } do
			local d = dirAt(ctx, deg)
]====], "8975 1903991386")
return "part 9/13 (CampDress.5): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
