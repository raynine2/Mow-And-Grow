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

put("CampDress.3", [====[		e.Rotation = NumberRange.new(0, 360)
		e.LightInfluence = 0.8
		e.Parent = mk
	end
end

-- A sign's text (both faces of `p`).
local function signText(p: BasePart, text: string, color: Color3?, ppu: number?)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = ppu or 40
		gui.LightInfluence = 0.4
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -12, 1, -8)
		t.Position = UDim2.fromOffset(6, 4)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color or rgb(255, 240, 200)
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = rgb(60, 36, 20)
		st.Parent = t
		t.Parent = gui
	end
end

-------------------------------------------------------------------------------------------------------------
-- the plaza's new pieces
-------------------------------------------------------------------------------------------------------------
local function arch(ctx: Ctx, name: string)
	local cf = at(ctx, 0, ctx.R - 1.2)
	local m = place(ctx, "camp_arch", cf, { collide = true })
	if not m then
		return
	end
	local face = CampProps.markers(m, "SignFace")[1]
	if face then
		signText(face, string.upper(name) .. " CAMP")
	end
	lamps(ctx, m)
	for _, g in { "BanL", "BanR" } do
		tag(m, "CampSway", { ["Group_" .. g] = true })
	end
	m:SetAttribute("Amp", 6)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- Where the next area's gate, this area's boss arena and the spawn camp are (the arena is built after the camps:
-- the arrow waits for it).
local function signpost(ctx: Ctx)
	local cf = at(ctx, -6.2, ctx.R - 4.6, ctx.fwd)
	local m = place(ctx, "camp_signpost", cf, { collide = true })
	if not m then
		return
	end
	local function point(i: number, target: Vector3, text: string)
		local d = cf:VectorToObjectSpace(Vector3.new(target.X - cf.Position.X, 0, target.Z - cf.Position.Z))
		if d.Magnitude < 1 then
			return
		end
		CampProps.turnGroup(m, "Arrow" .. i, CFrame.Angles(0, math.atan2(-d.Z, d.X), 0))
		local board: BasePart? = nil
		for _, p in m:GetChildren() do
			if p:IsA("Part") and p:GetAttribute("G") == "Arrow" .. i and p.Shape == Enum.PartType.Block then
				board = p
			end
		end
		if board then
			signText(board, text, nil, 50)
		end
	end
	local z = ctx.z
	local nextGate: Vector3? = nil
	for _, g in (ctx.info and ctx.info.gates) or {} do
		if g.b == z + 1 and g.model then
			nextGate = if g.model:IsA("Model") then g.model:GetPivot().Position else (g.model :: any).Position
		end
	end
	local nextDef = Zones.list[z + 1]
	if nextGate and nextDef then
		point(2, nextGate, string.upper(nextDef.name))
	end
	local camp = ctx.w:GetAttribute("CampCenter")
	if typeof(camp) == "Vector3" then
		point(3, camp, "SPAWN CAMP")
	end
	local boss = Config.ZONES[z] and Config.ZONES[z].boss
	task.spawn(function()
		for _ = 1, 120 do
			local arena = ctx.w:GetAttribute("Arena" .. z)
			if typeof(arena) == "Vector3" then
				if m.Parent then
					point(1, arena, string.upper(if boss then boss.name else "BOSS") .. "!")
				end
				return
			end
			task.wait(0.5)
		end
	end)
end

local function banner(ctx: Ctx, deg: number, phase: number)
	local d = dirAt(ctx, deg)
	local p = ctx.base + d * (ctx.R - 1.6)
	local m = place(ctx, "camp_banner", CFrame.lookAt(p, p + d))
	if m then
		tag(m, "CampSway", { Group_Cloth = true, Amp = 7, Phase = phase })
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

-------------------------------------------------------------------------------------------------------------
-- villagers and critters (client/CampLife moves them)
-------------------------------------------------------------------------------------------------------------
local TOOLS: { [string]: (Instance, CFrame, Random) -> { BasePart } } = {}
local function held(parent: Instance, cf: CFrame, size: Vector3, color: Color3, look: any?): BasePart
	return part(parent, "Held", cf, size, color, look)
end
TOOLS.rake = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.3, 0), Vector3.new(0.18, 4.2, 0.18), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, 2.3, 0), Vector3.new(1.4, 0.2, 0.3), rgb(110, 110, 116)) }
end
TOOLS.water = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, -0.45, -0.25), Vector3.new(0.8, 0.8, 1.0), rgb(110, 170, 140), Enum.Material.Metal), held(p, hand * CFrame.new(0, -0.25, -0.95) * CFrame.Angles(math.rad(35), 0, 0), Vector3.new(0.18, 0.18, 0.9), rgb(110, 170, 140), Enum.Material.Metal) }
end
TOOLS.chop = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.6, 0), Vector3.new(0.2, 2.4, 0.2), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, 1.65, -0.35), Vector3.new(0.15, 0.6, 0.75), rgb(170, 172, 178), Enum.Material.Metal) }
end
TOOLS.fish = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 1.3, -1.9) * CFrame.Angles(math.rad(-55), 0, 0), Vector3.new(0.12, 4.6, 0.12), rgb(150, 110, 70)) }
end
TOOLS.shovel = function(p, hand, _)
	return { held(p, hand * CFrame.new(0, 0.5, 0), Vector3.new(0.18, 3.0, 0.18), rgb(150, 110, 70)), held(p, hand * CFrame.new(0, -1.15, 0), Vector3.new(0.9, 0.8, 0.12), rgb(80, 130, 200), Enum.Material.Metal) }
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
-- `path`, world points), sit, work (`work`: the area's job, with its tool in the right hand).
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
]====], "8970 1184137873")
return "part 7/13 (CampDress.3): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
