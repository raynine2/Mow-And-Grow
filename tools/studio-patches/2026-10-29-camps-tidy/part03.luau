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

put("CampDress.3", [====[local function place(ctx: Ctx, name: string, cf: CFrame, opts: { [string]: any }?): Model?
	local o = table.clone(opts or {})
	o.roles = o.roles or ctx.roles
	return CampProps.place(name, ctx.f, cf, o :: any)
end

-- A lamp on a model's "Lamp" markers: a bracket and a hanging lantern in the area's glow.
local function lamps(ctx: Ctx, m: Model, hang: boolean?)
	for _, mk in CampProps.markers(m, "Lamp") do
		if hang then
			VoxelKit.lantern(ctx.f, mk.CFrame * CFrame.new(0, 0.2, 0), true, ctx.glow, true)
		else
			part(ctx.f, "LampArm", mk.CFrame * CFrame.new(0, 0.5, 0.35), Vector3.new(0.25, 0.25, 0.9), C.iron)
			VoxelKit.lantern(ctx.f, mk.CFrame * CFrame.new(0, 0.38, 0), true, ctx.glow, true)
		end
	end
end

local function smoke(m: Model, color: Color3?, rate: number?)
	for _, mk in CampProps.markers(m, "Smoke") do
		local e = Instance.new("ParticleEmitter")
		e.Name = "ChimneySmoke"
		e.Texture = FxIds.smoke or "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(color or rgb(214, 210, 204), rgb(160, 158, 156))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(4, 6.5)
		e.Rate = rate or 3
		e.Speed = NumberRange.new(2, 3.2)
		e.SpreadAngle = Vector2.new(10, 10)
		e.Acceleration = Vector3.new(0.8, 0.4, 0.3)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.Rotation = NumberRange.new(0, 360)
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
-- on the plaza: what stands there already, and whether a spot is paved and clear
-------------------------------------------------------------------------------------------------------------
local PAVING = { Tile = true, TileBed = true, Plank = true, Footing = true, Step = true, WalkPlate = true }

local function plazaSetup(ctx: Ctx)
	local boxes: { Box } = {}
	local function add(cf: CFrame, size: Vector3)
		table.insert(boxes, { cf = cf, hx = size.X / 2, hz = size.Z / 2 })
	end
	for _, d in ctx.f:GetChildren() do
		if d:IsA("Model") then
			local cf, size = d:GetBoundingBox()
			add(cf, size)
		elseif d:IsA("BasePart") and not PAVING[d.Name] then
			add(d.CFrame, d.Size)
		end
	end
	local pads = ctx.w:FindFirstChild("Pads")
	for _, d in (if pads then pads:GetChildren() else {}) do
		local cf: CFrame?, size: Vector3? = nil, nil
		if d:IsA("Model") then
			cf, size = d:GetBoundingBox()
		elseif d:IsA("BasePart") then
			cf, size = d.CFrame, d.Size
		end
		if cf and size and Vector2.new(cf.Position.X - ctx.base.X, cf.Position.Z - ctx.base.Z).Magnitude < ctx.R + 6 then
			add(cf, size)
		end
	end
	ctx.obstacles = boxes
	ctx.plazaTaken = {}
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { ctx.f }
	ctx.paveRay = ray
end

-- nothing on the plaza within `r` of world point p
local function clearOf(ctx: Ctx, p: Vector3, r: number): boolean
	for _, b in ctx.obstacles :: { Box } do
		if not outside(b, p, r) then
			return false
		end
	end
	for _, t in ctx.plazaTaken :: { Disc } do
		if Vector2.new(p.X - t.at.X, p.Z - t.at.Y).Magnitude < r + t.r then
			return false
		end
	end
	return true
end

-- paved at the plaza's height under world point p, nothing on it up to head height (an arch's sign is higher)
local function paved(ctx: Ctx, p: Vector3): boolean
	local hit = workspace:Raycast(Vector3.new(p.X, ctx.top + 4.5, p.Z), Vector3.new(0, -6.5, 0), ctx.paveRay)
	return hit ~= nil and PAVING[hit.Instance.Name] == true and math.abs(hit.Position.Y - ctx.top) < 0.35
end

-- a round spot of radius r at p: paved all over and clear
local function onPlaza(ctx: Ctx, p: Vector3, r: number): boolean
	if not paved(ctx, p) or not clearOf(ctx, p, r) then
		return false
	end
	for k = 0, 7 do
		local a = k * math.pi / 4
		if not paved(ctx, p + Vector3.new(math.cos(a), 0, math.sin(a)) * r) then
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the plaza's pieces
-------------------------------------------------------------------------------------------------------------
-- The entrance arch toward the area's middle, its two feet and the way through on the paving.
local function arch(ctx: Ctx, name: string)
	for _, dist in { ctx.R - 3.6, ctx.R - 4.8, ctx.R - 6, ctx.R - 7.5 } do
		for _, deg in { 0, 12, -12, 24, -24, 36, -36 } do
			local d = dirAt(ctx, deg)
			local p = ctx.base + d * dist
			local cf = CFrame.lookAt(p, p + d)
			local ok = clearOf(ctx, p, 2.5)
			for _, x in { -7.6, -5, -2.5, 0, 2.5, 5, 7.6 } do
				for _, z in { -1.1, 1.1 } do
					ok = ok and paved(ctx, (cf * CFrame.new(x, 0, z)).Position)
				end
			end
			for _, x in { -6.6, 6.6 } do
				ok = ok and clearOf(ctx, (cf * CFrame.new(x, 0, 0)).Position, 2.2)
			end
			if ok then
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
				for _, x in { -6.6, 6.6 } do
					local q = (cf * CFrame.new(x, 0, 0)).Position
					table.insert(ctx.plazaTaken :: { Disc }, { at = Vector2.new(q.X, q.Z), r = 1.8 })
				end
				table.insert(ctx.placed :: { string }, string.format("arch@%.0f/%.1f", deg, dist))
				return
			end
		end
	end
	table.insert(ctx.placed :: { string }, "arch:none")
end

-- Four lamp posts near the edge, between the arch and the stalls.
local function lampPosts(ctx: Ctx)
	local lanternPost = ctx.lanternPost
	if not lanternPost then
		return
	end
	local n = 0
	for _, deg in { 42, -42, 138, -138 } do
		local done = false
		for _, da in { 0, 8, -8, 16, -16 } do
			for _, inset in { 1.8, 3.2, 4.6 } do
				if not done then
					local d = dirAt(ctx, deg + da)
					local p = ctx.base + d * (ctx.R - inset)
					if onPlaza(ctx, p, 1.3) then
						lanternPost(ctx.f, p, d)
						table.insert(ctx.plazaTaken :: { Disc }, { at = Vector2.new(p.X, p.Z), r = 1.2 })
						done = true
						n += 1
					end
				end
			end
		end
	end
	table.insert(ctx.placed :: { string }, n .. " lamps")
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
]====], "8853 1199636205")
return "part 3/5 (CampDress.3): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
