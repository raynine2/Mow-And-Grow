-- The area camps, remade bigger and alive (owner, 29 Oct: "remake every zone hub except 1 to make it a bit bigger
-- and ... make it feel more alive and not so boring; if ur going to add or make stuff use blender"). server/Outposts
-- lays the paved plaza (now 24 studs round the drop-off pad), the SHOP and UPGRADES stalls, the gas pump and the
-- benches; this dresses it, with the Blender models in server/CampProps (tools/blender/camp):
--   * on the plaza: an entrance arch with the camp's name, a signpost whose arrows point at the boss arena, the next
--     area and the spawn camp, a notice board, a well, a market cart with the area's goods, banners, lamp posts;
--   * round it (on the ground, levelled with a stone footing, stepping stones from the plaza): a house with smoke
--     from its chimney, a camp corner with two tents and a fire, the area's own landmark and its animals:
--       Golden Wheat Hills: windmill, chicken run, scarecrow, hay; Blossom Garden: pavilion with paper lanterns, koi
--       pond; Misty Pine Forest: watchtower, owls, log pile; Bubble Swamp: the house on stilts, a pond with a jetty,
--       a rowing boat and frogs; Frost Peaks: igloo, snowman, penguins, snow on the roofs; Ember Ash Fields: forge
--       with bellows, embers and lava, fire salamanders; Starlight Isles: telescope, floating crystals, wisps;
--   * people: gnome villagers, two by the stalls, one walking round, one by the fire, one at work by the landmark;
--   * the air: the area's drifting pollen / petals / mist / fireflies / snow / embers / sparkles.
-- Everything is decoration (only the buildings collide). What moves is tagged for client/CampLife, which animates it
-- near you (windmill sails, banners, the telescope, critters, villagers who look at you, wave and talk).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local FxIds = require(ReplicatedStorage.MowALawn.FxIds) :: { [string]: string }
local CampProps = require(script.Parent.CampProps)
local VoxelKit = require(script.Parent.VoxelKit)

local CampDress = {}

CampDress.RADIUS = 36 -- the whole camp: no grass grows inside (World attribute HubR<z>, RunWorld.patches)

local part = VoxelKit.part
local C = VoxelKit.C
local UP = Vector3.yAxis

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-------------------------------------------------------------------------------------------------------------
-- each area's colours for the models' "@roles" (server/CampProps): { material or nil, colour }; false = left out
-------------------------------------------------------------------------------------------------------------
local BASE_ROLES = {
	trim = { nil, rgb(236, 228, 214) },
	roof = { "VRoof", rgb(110, 74, 56) },
	roof2 = { "VRoof", rgb(86, 56, 42) },
	base = { nil, rgb(230, 222, 205) },
	stone = { nil, rgb(200, 196, 188) },
	door = { nil, rgb(120, 70, 40) },
	glass = { "Glass", rgb(190, 220, 240) },
	board = { nil, rgb(196, 140, 88) },
	wood = { nil, rgb(176, 124, 78) },
	skin = { nil, rgb(255, 204, 170) },
	beard = { nil, rgb(244, 240, 232) },
	tower = { "Plaster", rgb(244, 238, 226) },
	post = { nil, rgb(200, 50, 60) },
	sail = { nil, rgb(246, 240, 226) },
	water = { nil, rgb(70, 150, 200) },
	scope = { nil, rgb(44, 48, 96) },
	snowcap = false,
}
local AREA_ROLES: { [string]: { [string]: any } } = {
	wheat = {
		wall = { "WoodPlanks", rgb(178, 62, 48) }, cloth = { nil, rgb(226, 128, 44) }, accent = { nil, rgb(250, 206, 60) },
		goods1 = { nil, rgb(232, 196, 90) }, goods2 = { nil, rgb(236, 128, 34) }, flower = { nil, rgb(250, 200, 60) },
		coat = { nil, rgb(200, 64, 52) }, pants = { nil, rgb(64, 96, 166) }, hat = { nil, rgb(226, 190, 110) },
	},
	blossom = {
		wall = { "Plaster", rgb(248, 242, 238) }, trim = { nil, rgb(150, 92, 76) }, roof = { "ClayRoofTiles", rgb(226, 112, 152) },
		roof2 = { "ClayRoofTiles", rgb(190, 84, 120) }, base = { nil, rgb(236, 220, 216) }, door = { nil, rgb(176, 70, 92) },
		glass = { "Glass", rgb(255, 222, 236) }, cloth = { nil, rgb(240, 120, 170) }, accent = { nil, rgb(255, 250, 250) },
		goods1 = { nil, rgb(255, 150, 200) }, goods2 = { nil, rgb(255, 250, 244) }, flower = { nil, rgb(255, 140, 190) },
		coat = { nil, rgb(236, 136, 178) }, pants = { nil, rgb(120, 80, 110) }, hat = { nil, rgb(232, 210, 150) },
		board = { nil, rgb(150, 92, 76) },
	},
	pine = {
		wall = { "VLog", rgb(170, 132, 104) }, trim = { nil, rgb(92, 66, 48) }, roof = { "VRoof", rgb(74, 112, 74) },
		roof2 = { "VRoof", rgb(56, 88, 58) }, base = { nil, rgb(196, 198, 192) }, door = { nil, rgb(96, 64, 44) },
		glass = { "Neon", rgb(255, 214, 150) }, cloth = { nil, rgb(64, 124, 84) }, accent = { nil, rgb(200, 64, 52) },
		goods1 = { nil, rgb(150, 105, 70) }, goods2 = { nil, rgb(96, 146, 76) }, flower = { nil, rgb(186, 130, 226) },
		coat = { nil, rgb(190, 54, 44) }, pants = { nil, rgb(76, 64, 54) }, hat = { nil, rgb(190, 54, 44) },
		beard = { nil, rgb(132, 88, 56) }, wood = { nil, rgb(150, 110, 80) },
	},
	swamp = {
		wall = { "WoodPlanks", rgb(130, 112, 82) }, trim = { nil, rgb(82, 66, 48) }, roof = { "Fabric", rgb(160, 140, 80) },
		roof2 = { "Fabric", rgb(130, 112, 62) }, base = { nil, rgb(146, 146, 126) }, stone = { nil, rgb(150, 150, 130) },
		door = { nil, rgb(92, 72, 52) }, glass = { "Neon", rgb(196, 255, 150) }, cloth = { nil, rgb(112, 142, 62) },
		accent = { nil, rgb(176, 255, 146) }, board = { nil, rgb(112, 92, 62) }, goods1 = { nil, rgb(204, 64, 64) },
		goods2 = { nil, rgb(152, 92, 204) }, flower = { nil, rgb(190, 120, 255) }, coat = { nil, rgb(240, 200, 44) },
		pants = { nil, rgb(64, 84, 64) }, hat = { nil, rgb(240, 200, 44) }, beard = { nil, rgb(206, 206, 196) },
		wood = { nil, rgb(132, 104, 74) }, water = { nil, rgb(74, 110, 80) },
	},
	frost = {
		wall = { "VLog", rgb(232, 216, 192) }, trim = { nil, rgb(104, 74, 54) }, roof = { "VRoof", rgb(94, 106, 128) },
		roof2 = { "VRoof", rgb(74, 84, 104) }, base = { nil, rgb(214, 226, 240) }, stone = { nil, rgb(206, 218, 232) },
		door = { nil, rgb(72, 112, 172) }, glass = { "Neon", rgb(255, 222, 156) }, cloth = { nil, rgb(72, 132, 212) },
		accent = { nil, rgb(255, 255, 255) }, board = { nil, rgb(124, 92, 72) }, goods1 = { "Ice", rgb(170, 220, 255) },
		goods2 = { nil, rgb(240, 245, 250) }, flower = { nil, rgb(150, 200, 255) }, coat = { nil, rgb(62, 112, 192) },
		pants = { nil, rgb(52, 62, 84) }, hat = { nil, rgb(232, 232, 242) }, snowcap = { "Snow", rgb(246, 250, 255) },
		water = { nil, rgb(120, 180, 230) },
	},
	ember = {
		wall = { "VStone", rgb(118, 106, 104) }, trim = { nil, rgb(64, 44, 34) }, roof = { "VMetal", rgb(96, 86, 86) },
		roof2 = { "VMetal", rgb(70, 62, 62) }, base = { "Basalt", rgb(78, 70, 72) }, stone = { nil, rgb(110, 100, 100) },
		door = { nil, rgb(112, 52, 32) }, glass = { "Neon", rgb(255, 150, 70) }, cloth = { nil, rgb(204, 72, 42) },
		accent = { nil, rgb(255, 156, 72) }, board = { nil, rgb(92, 62, 42) }, goods1 = { "Neon", rgb(255, 122, 42) },
		goods2 = { nil, rgb(82, 78, 80) }, flower = { "Neon", rgb(255, 102, 42) }, coat = { nil, rgb(122, 72, 42) },
		pants = { nil, rgb(62, 52, 52) }, hat = { nil, rgb(64, 54, 54) }, beard = { nil, rgb(92, 62, 42) },
		wood = { nil, rgb(120, 90, 66) }, water = { nil, rgb(60, 96, 120) },
	},
	isles = {
		wall = { "Plaster", rgb(222, 212, 250) }, trim = { nil, rgb(232, 192, 92) }, roof = { "ClayRoofTiles", rgb(84, 64, 166) },
		roof2 = { "ClayRoofTiles", rgb(64, 48, 132) }, base = { nil, rgb(184, 174, 224) }, stone = { nil, rgb(170, 160, 214) },
		door = { nil, rgb(92, 62, 152) }, glass = { "Neon", rgb(150, 230, 255) }, cloth = { nil, rgb(112, 82, 222) },
		accent = { nil, rgb(255, 222, 122) }, board = { nil, rgb(92, 72, 142) }, goods1 = { "Neon", rgb(150, 230, 255) },
		goods2 = { nil, rgb(202, 162, 255) }, flower = { "Neon", rgb(150, 230, 255) }, coat = { nil, rgb(72, 52, 152) },
		pants = { nil, rgb(52, 42, 92) }, hat = { nil, rgb(72, 52, 152) }, scope = { nil, rgb(52, 46, 120) },
	},
}

local function rolesFor(id: string): { [string]: any }
	local r = table.clone(BASE_ROLES)
	for k, v in AREA_ROLES[id] or AREA_ROLES.wheat do
		r[k] = v
	end
	return r
end

-- a few villagers' outfits per area (coat, pants, hat): the first is the area's own
local OUTFITS: { [string]: { { Color3 } } } = {
	wheat = { { rgb(84, 140, 196), rgb(150, 110, 70), rgb(226, 190, 110) }, { rgb(236, 220, 160), rgb(64, 96, 166), rgb(200, 64, 52) } },
	blossom = { { rgb(255, 250, 244), rgb(176, 70, 92), rgb(240, 120, 170) }, { rgb(150, 200, 120), rgb(120, 80, 110), rgb(255, 196, 220) } },
	pine = { { rgb(64, 124, 84), rgb(76, 64, 54), rgb(236, 220, 160) }, { rgb(150, 110, 80), rgb(64, 84, 64), rgb(64, 124, 84) } },
	swamp = { { rgb(112, 142, 62), rgb(92, 72, 52), rgb(152, 92, 204) }, { rgb(204, 64, 64), rgb(64, 84, 64), rgb(240, 200, 44) } },
	frost = { { rgb(204, 64, 64), rgb(52, 62, 84), rgb(244, 244, 250) }, { rgb(240, 200, 44), rgb(72, 112, 172), rgb(62, 112, 192) } },
	ember = { { rgb(82, 78, 80), rgb(122, 72, 42), rgb(204, 72, 42) }, { rgb(204, 72, 42), rgb(62, 52, 52), rgb(255, 156, 72) } },
	isles = { { rgb(112, 82, 222), rgb(52, 42, 92), rgb(232, 192, 92) }, { rgb(150, 230, 255), rgb(72, 52, 152), rgb(112, 82, 222) } },
}

-------------------------------------------------------------------------------------------------------------
-- the camp's frame and the ground round it
-------------------------------------------------------------------------------------------------------------
export type Ctx = {
	w: Instance, -- the run's World
	f: Model, -- the camp's model (World.Outpost<z>)
	z: number,
	base: Vector3, -- the plaza's middle, at its top
	top: number,
	fwd: Vector3, -- toward the area's middle
	right: Vector3,
	R: number, -- the plaza's radius
	rng: Random,
	info: any,
	lanternPost: ((Instance, Vector3, Vector3) -> ())?,
	glow: Color3?, -- the area's lantern glass
	-- filled in here
	id: string?,
	roles: any,
	ground: RaycastParams?,
	blocked: { { cf: CFrame, hx: number, hz: number } }?,
	placed: { string }?,
	taken: { { at: Vector2, r: number } }?,
}

local function at(ctx: Ctx, x: number, z: number, face: Vector3?): CFrame
	local p = ctx.base + ctx.right * x + ctx.fwd * z
	return CFrame.lookAt(p, p + (face or ctx.fwd))
end

local function dirAt(ctx: Ctx, deg: number): Vector3
	local a = math.rad(deg)
	return ctx.fwd * math.cos(a) + ctx.right * math.sin(a)
end

local function groundAt(ctx: Ctx, x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, ctx.top + 40, z), Vector3.new(0, -90, 0), ctx.ground)
	return if hit then hit.Position.Y else nil
end

-- What a building mustn't stand on: the paths, hazards, water, gates and bridges (round the camp), each as its
-- footprint (a turned rectangle).
local function collectBlocked(ctx: Ctx)
	local list = {}
	local c = Vector2.new(ctx.base.X, ctx.base.Z)
	for _, name in { "Ways", "Hazards", "Liquid", "Gates", "Arenas", "Bounds", "IsleBridges" } do
		local fold = ctx.w:FindFirstChild(name)
		if fold then
			for _, d in fold:GetDescendants() do
				if d:IsA("BasePart") then
					local p = Vector2.new(d.Position.X, d.Position.Z)
					if (p - c).Magnitude < 70 + math.max(d.Size.X, d.Size.Z) / 2 then
						table.insert(list, { cf = d.CFrame, hx = d.Size.X / 2, hz = d.Size.Z / 2 })
					end
				end
			end
		end
	end
	ctx.blocked = list
	ctx.taken = {}
	ctx.placed = {}
end

local function free(ctx: Ctx, p: Vector3, r: number): boolean
	local q = Vector2.new(p.X, p.Z)
	for _, b in ctx.blocked :: any do
		local lp = b.cf:PointToObjectSpace(Vector3.new(p.X, b.cf.Position.Y, p.Z))
		local dx, dz = math.max(0, math.abs(lp.X) - b.hx), math.max(0, math.abs(lp.Z) - b.hz)
		if dx * dx + dz * dz < r * r then
			return false
		end
	end
	for _, t in ctx.taken :: any do
		if (q - t.at).Magnitude < r + t.r then
			return false
		end
	end
	return true
end

-- Take the scenery (trees, bushes, rocks) off a building's spot.
local function clearAround(ctx: Ctx, p: Vector3, r: number)
	local visuals = ctx.w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			local q = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
			if q and Vector2.new(q.X - p.X, q.Z - p.Z).Magnitude < r and d.Name ~= "Blocker" and not string.find(d.Name, "Landmark", 1, true) then
				d:Destroy()
			end
		end
	end
end

export type Spot = { cf: CFrame, y: number, gmin: number }

-- A spot for something halfW x halfD round angle `deg` from the area's middle and `r` from the pad: on ground that's
-- there, not too steep, off the paths, clear of the rest; its front toward the plaza. nil if there's none.
local function findSpot(ctx: Ctx, deg: number, r: number, halfW: number, halfD: number): Spot?
	local best: Spot? = nil
	local bestScore = math.huge
	for _, da in { 0, 10, -10, 20, -20, 32, -32, 45, -45 } do
		for _, dr in { 0, 3, 6 } do
			local dir = dirAt(ctx, deg + da)
			local p = ctx.base + dir * (r + dr)
			local cf = CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.new(p.X, 0, p.Z) - dir)
			local gmin, gmax, ok = math.huge, -math.huge, true
			for _, sx in { -1, 0, 1 } do
				for _, sz in { -1, 0, 1 } do
					local q = cf * Vector3.new(sx * halfW, 0, sz * halfD)
					local g = groundAt(ctx, q.X, q.Z)
					if not g then
						ok = false
						break
					end
					gmin, gmax = math.min(gmin, g), math.max(gmax, g)
				end
				if not ok then
					break
				end
			end
			if ok and gmax - gmin <= 6 and gmax <= ctx.top + 7 and gmin >= ctx.top - 14 and free(ctx, p, math.max(halfW, halfD)) then
				-- level with the plaza when the ground is just below it
				local y = if gmax < ctx.top and ctx.top - gmax <= 2.6 then ctx.top else gmax
				local score = (y - gmin) * 2 + math.abs(da) * 0.08 + dr * 0.3 + math.abs(y - ctx.top) * 0.8
				if score < bestScore then
					bestScore = score
					best = { cf = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) - dir), y = y, gmin = gmin }
				end
			end
		end
		if best and bestScore < 3 then
			break
		end
	end
	if best then
		table.insert(ctx.taken :: any, { at = Vector2.new(best.cf.Position.X, best.cf.Position.Z), r = math.max(halfW, halfD) })
		table.insert(ctx.placed :: { string }, string.format("%.0f@%.0f", deg, best.y - ctx.top))
	else
		table.insert(ctx.placed :: { string }, string.format("%.0f:none", deg))
	end
	return best
end

-- A stone footing under a building (w x d) from the lowest ground up to its floor, with steps down at its front.
local function footing(ctx: Ctx, spot: Spot, w: number, d: number)
	local h = spot.y - spot.gmin + 0.6
	if h < 0.7 then
		return
	end
	local stone = ctx.roles.base[2] :: Color3
	part(ctx.f, "Footing", spot.cf * CFrame.new(0, -h / 2, 0), Vector3.new(w, h, d), VoxelKit.jitter(ctx.rng, stone, 0.03), "stone", true)
	part(ctx.f, "FootingCap", spot.cf * CFrame.new(0, -0.15, 0), Vector3.new(w + 0.5, 0.3, d + 0.5), C.timber, nil, true)
	local n = math.floor((h - 0.6) / 1.1)
	for i = 1, n do
		local sh = h - 0.6 - (i - 1) * 1.1
		part(ctx.f, "Step", spot.cf * CFrame.new(0, -0.6 - (i - 1) * 1.1 - sh / 2 + sh / 2 - 0.55, -(d / 2 + 0.6 + (i - 1) * 1.2)), Vector3.new(4, 1.1, 1.2), VoxelKit.jitter(ctx.rng, stone, 0.05), "stone", true)
	end
end

-- Stepping stones from the plaza's edge to `to`, following the ground.
local function steppingStones(ctx: Ctx, to: Vector3)
	local flat = Vector3.new(to.X - ctx.base.X, 0, to.Z - ctx.base.Z)
	if flat.Magnitude < ctx.R + 1 then
		return
	end
	local dir = flat.Unit
	local from = ctx.base + dir * (ctx.R - 0.5)
	local dist = (Vector3.new(to.X, 0, to.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
	local n = math.floor(dist / 2.3)
	for i = 1, n do
		local p = from + dir * (i * 2.3)
		local g = groundAt(ctx, p.X, p.Z)
		if g then
			local cf = CFrame.new(p.X, g + 0.12, p.Z) * CFrame.Angles(0, ctx.rng:NextNumber(0, math.pi), 0)
			part(ctx.f, "SteppingStone", cf, Vector3.new(ctx.rng:NextNumber(1.7, 2.2), 0.3, ctx.rng:NextNumber(1.5, 2.0)), VoxelKit.jitter(ctx.rng, ctx.roles.stone[2], 0.06), "stone")
		end
	end
end

local function tag(inst: Instance, name: string, attrs: { [string]: any }?)
	for k, v in attrs or {} do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

local function place(ctx: Ctx, name: string, cf: CFrame, opts: { [string]: any }?): Model?
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
-- round the plaza: the house, the tents, the landmark, the animals
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
				VoxelKit.bush(ctx.f, cf * CFrame.new(-6.4, 0, 3), rgb(255, 170, 214), ctx.rng, { rgb(255, 255, 255) })
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
			ctx.lanternPost(ctx.f, ctx.base + d * (ctx.R - 1.5), d)
		end
	end
	VoxelKit.crate(ctx.f, at(ctx, 19.2, 14.6) * CFrame.new(0, 0.6, 0), 1.2, ctx.rng)
	VoxelKit.barrel(ctx.f, at(ctx, -19.6, -9.6), 2.2, ctx.rng)
	-- market goods behind the stall keepers, planters at the sides, flowering bushes by the arch
	for _, s in { -1, 1 } do
		VoxelKit.crate(ctx.f, at(ctx, s * 13.4, -12.9) * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, s * 0.3, 0), 1.2, ctx.rng)
		VoxelKit.barrel(ctx.f, at(ctx, s * 15.0, -11.4), 2.0, ctx.rng)
		local pd = dirAt(ctx, s * 85)
		local pp = ctx.base + pd * (ctx.R - 1.6)
		VoxelKit.planter(ctx.f, CFrame.lookAt(pp, pp - pd), 4.6, { ctx.roles.flower[2], Color3.new(1, 1, 1) }, ctx.rng)
		VoxelKit.bush(ctx.f, at(ctx, s * 9.8, ctx.R - 2.4), C.leaf, ctx.rng, { ctx.roles.flower[2], ctx.roles.accent[2] })
	end
	-- round it
	for _, step in { house, landmark, tents, animals } do
		local ok, err = pcall(step, ctx)
		if not ok then
			warn(("[CampDress] area %d: %s"):format(ctx.z, tostring(err)))
		end
	end
	print(("[CampDress] %s camp: %s"):format(ctx.id :: string, table.concat(ctx.placed :: { string }, ", ")))
	-- people: by the stalls, walking round, and the air
	villager(ctx, at(ctx, -12.4, -9.4, ctx.fwd), "idle", { outfit = 1 })
	villager(ctx, at(ctx, 12.4, -9.4, ctx.fwd), "idle", { outfit = 2 })
	local path = {}
	for _, p in LOOP do
		table.insert(path, ctx.base + ctx.right * p[1] + ctx.fwd * p[2])
	end
	villager(ctx, CFrame.lookAt(path[1], path[2]), "walk", { path = path })
	air(ctx)
end

return CampDress
