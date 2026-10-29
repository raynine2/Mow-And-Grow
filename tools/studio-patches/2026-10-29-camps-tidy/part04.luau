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

put("CampDress.4", [====[	return { held(p, hand * CFrame.new(0, 0.5, 0), Vector3.new(0.18, 3.0, 0.18), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, -1.15, 0), Vector3.new(0.9, 0.8, 0.12), rgb(80, 130, 200), Enum.Material.Metal) }
end
TOOLS.hammer = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.45, 0), Vector3.new(0.18, 1.5, 0.18), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, 1.25, 0), Vector3.new(0.7, 0.4, 0.4), rgb(70, 68, 70), Enum.Material.Metal) }
end
TOOLS.gaze = function(p, hand, _)
	local star = held(p, hand * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.55, 0.55, 0.3), rgb(255, 230, 120), Enum.Material.Neon)
	VoxelKit.light(star, 8, 0.6, rgb(255, 230, 150))
	return { held(p, hand * CFrame.new(0, 0.9, 0), Vector3.new(0.2, 3.4, 0.2), rgb(120, 90, 160)), star }
end
local AREA_WORK = { wheat = "rake", blossom = "water", pine = "chop", swamp = "fish", frost = "shovel", ember = "hammer", isles = "gaze" }

local villagerN = 0
-- A gnome villager standing on `cf` (front: cf's LookVector). `act`: idle (looks at you, waves, talks), walk (along
-- `path`, world points), work (`work`: the area's job, with its tool in the right hand).
local function villager(ctx: Ctx, cf: CFrame, act: string, opts: { path: { Vector3 }?, work: string?, outfit: number?, lift: number? }?)
	local o = opts or {}
	local roles = table.clone(ctx.roles)
	local outfits = OUTFITS[ctx.id :: string]
	local pick = o.outfit and outfits and outfits[o.outfit]
	if pick then
		roles.coat, roles.pants, roles.hat = { nil, pick[1] }, { nil, pick[2] }, { nil, pick[3] }
	end
	villagerN += 1
	local m = CampProps.place("camp_gnome", ctx.f, cf * CFrame.new(0, o.lift or 0, 0), { roles = roles, atomic = true, name = "Villager" })
	if not m then
		return
	end
	local work = o.work
	if work and TOOLS[work] then
		local hand = CampProps.markers(m, "Hand")[1]
		if hand then
			for _, p in TOOLS[work](m, hand.CFrame, ctx.rng) do
				p:SetAttribute("G", "armR")
				p.Parent = m
			end
		end
	end
	local attrs: { [string]: any } = { Act = act, Area = ctx.id, Work = work or "", Seed = villagerN }
	if o.path then
		local bits = {}
		for _, p in o.path do
			table.insert(bits, string.format("%.1f,%.1f", p.X, p.Z))
		end
		attrs.Path = table.concat(bits, ";")
	end
	tag(m, "CampVillager", attrs)
end

-- `kind`: walk / hop / swim / perch / waddle / crawl, round `home` (on the ground) within `range`.
local function critter(ctx: Ctx, name: string, home: Vector3, kind: string, range: number, speed: number, scale: number?)
	local a = ctx.rng:NextNumber(0, math.pi * 2)
	local p = home + Vector3.new(math.cos(a), 0, math.sin(a)) * ctx.rng:NextNumber(0, range * 0.7)
	local cf = CFrame.lookAt(p, p + Vector3.new(math.sin(a), 0, math.cos(a)))
	local m = place(ctx, name, cf, { atomic = true, scale = scale })
	if m then
		tag(m, "CampCritter", { Kind = kind, Home = home, Range = range, Speed = speed, Seed = ctx.rng:NextInteger(1, 9999) })
	end
end

local function wisp(ctx: Ctx, home: Vector3, range: number)
	local m = Instance.new("Model")
	m.Name = "Wisp"
	local core = part(m, "WispCore", CFrame.new(home + Vector3.new(0, 3, 0)), Vector3.one * 0.6, rgb(170, 240, 255), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CastShadow = false
	local halo = part(m, "WispHalo", core.CFrame, Vector3.one * 1.2, rgb(150, 220, 255), Enum.Material.Neon)
	halo.Shape = Enum.PartType.Ball
	halo.Transparency = 0.7
	halo.CastShadow = false
	VoxelKit.light(core, 10, 0.8, rgb(150, 230, 255))
	m.WorldPivot = core.CFrame
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = ctx.f
	tag(m, "CampCritter", { Kind = "float", Home = home + Vector3.new(0, 3, 0), Range = range, Speed = 2.2, Seed = ctx.rng:NextInteger(1, 9999) })
end

-------------------------------------------------------------------------------------------------------------
-- round the plaza: the house, the landmark, the animals
-------------------------------------------------------------------------------------------------------------
local function house(ctx: Ctx)
	local spot = findSpot(ctx, "house", -125, ctx.R + 2.5 + 8, 7.6, 7.2)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, 12)
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
		for _ = 1, 4 do
			local a, d = ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(0.6, r - 0.8)
			local pad = part(ctx.f, "LilyPad", cf * CFrame.new(math.cos(a) * d, 0.23, math.sin(a) * d) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, 1.3, 1.3), rgb(90, 170, 70))
			pad.Shape = Enum.PartType.Cylinder
		end
	end
end

local LANDMARK = { wheat = "camp_windmill", blossom = "camp_pavilion", pine = "camp_watchtower", frost = "camp_igloo", ember = "camp_forge", isles = "camp_telescope" }
local LANDMARK_SIZE = { wheat = 4.6, blossom = 6.0, pine = 4.0, swamp = 7.0, frost = 6.4, ember = 6.4, isles = 4.0 }

local function landmark(ctx: Ctx)
	local id = ctx.id :: string
	local size = LANDMARK_SIZE[id] or 5
	local spot = findSpot(ctx, "landmark", 120, ctx.R + 2.5 + size + 1, size, size)
	if not spot then
		return
	end
	clearAround(ctx, spot.cf.Position, size + 5)
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
]====], "8972 45084471")
return "part 4/5 (CampDress.4): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
