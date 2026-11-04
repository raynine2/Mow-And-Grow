--!strict
-- THE LOBBY COMES ALIVE (owner, 4 Nov: "main lobby needs a bit work done"; he picked "more life: butterflies, birds,
-- water, fountains, NPCs" and "the edges/background: the lands, the forest, the horizon"). server/LandsBuilder calls
-- LobbyLife.dress after the lands. All of it stays off the walks and the lawn's middle (the square's negative space):
--   * THE FOUNTAIN GARDEN on the lawn right of the spawn, mirroring the rewards stall on the left: the ForgeGUI garden
--     fountain on a round paved apron (laid with the walks), two benches facing it, water spraying (client/LobbyFX
--     "fountain") and butterflies;
--   * VILLAGERS: the camps' gnome villagers (server/CampProps, animated by client/CampLife): two walking the curved walk
--     and the cross walk, one by the fountain who greets you (Config.CAMP_LINES.lobby);
--   * EACH LAND'S ANIMALS in front of its landmark: chickens (wheat), koi in a pond (blossom), owls on perches (pine),
--     frogs round a pond (swamp), penguins (frost), salamanders on glowing cracks (ember), wisps (isles), a little
--     bigger than in the camps so they read from the square;
--   * BUTTERFLIES over the flower beds, the fountain and the blossom land (client/LobbyFX "butterflies");
--   * THE HORIZON: past the forest, over the sea, the zones' far shores rise above the trees: snowy peaks toward Frost,
--     a smoking volcano toward Ember, floating islands toward the Isles (behind the spawn), golden and green hills
--     elsewhere (the vault's "let the next zone's landmark break the skyline"). Big simple blocks, no shadows, fading
--     into the haze.
local CollectionService = game:GetService("CollectionService")

local CampProps = require(script.Parent.CampProps)
local Models = require(script.Parent.Models)
local VoxelKit = require(script.Parent.VoxelKit)
local VM = require(script.Parent.VoxelModels)

local LobbyLife = {}

local C = Color3.fromRGB

export type Ctx = {
	lands: { { id: string, pos: Vector3 } },
	centre: Vector3, -- the ring's middle (the lands face it)
	arc: (number, number) -> Vector3, -- a point on a circle round the windmill (degrees off the axis, radius)
	walkR: number,
	walkArc: number,
	crossZ: number,
	crossX0: number,
	crossX1: number,
	spawn: Vector3,
	fountain: Vector3,
	reach: number,
	sea: number,
}

local function tag(inst: Instance, name: string, attrs: { [string]: any })
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
	end
	p.Parent = parent
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- an invisible spot client/LobbyFX dresses (its Kind)
local function fxSpot(parent: Instance, at: Vector3, size: Vector3, kind: string, color: Color3?)
	local p = part(parent, kind .. "Spot", size, CFrame.new(at), Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	tag(p, "LobbyFX", { Kind = kind, Color = color })
end

-------------------------------------------------------------------------------------------------------------
-- the fountain garden
-------------------------------------------------------------------------------------------------------------
local function bench(parent: Instance, cf: CFrame)
	local C2 = VoxelKit.C
	VoxelKit.log(parent, cf * CFrame.new(0, 1.1, 0), 5, 0.6, 1.4, C2.log)
	VoxelKit.log(parent, cf * CFrame.new(0, 1.9, 0.75) * CFrame.Angles(math.rad(-12), 0, 0), 5, 0.9, 0.35, C2.log)
	for _, x in { -1.9, 1.9 } do
		part(parent, "BenchLeg", Vector3.new(0.5, 0.8, 1.2), cf * CFrame.new(x, 0.4, 0), C2.timber, nil, true)
	end
end

local function fountainGarden(world: Instance, ctx: Ctx)
	local f = folder(world, "FountainGarden")
	local at = ctx.fountain
	local m = Models.placeForge("fountain", f, CFrame.lookAt(at, Vector3.new(ctx.spawn.X, at.Y, ctx.spawn.Z)), { width = 9 }, false)
	local top = at + Vector3.new(0, 4, 0)
	if m then
		local box, size = m:GetBoundingBox()
		top = Vector3.new(at.X, box.Position.Y + size.Y / 2 - 0.6, at.Z)
	end
	fxSpot(f, top, Vector3.new(1, 1, 1), "fountain", C(170, 225, 255))
	-- two benches on the apron's far side, facing the fountain (their sitters look along the LookVector)
	for _, deg in { 140, 220 } do
		local a = math.rad(deg)
		local p = at + Vector3.new(math.sin(a), 0, math.cos(a)) * 7.2
		bench(f, CFrame.lookAt(p, Vector3.new(at.X, p.Y, at.Z)))
	end
	fxSpot(f, at + Vector3.new(0, 3, 0), Vector3.new(16, 4, 16), "butterflies", C(255, 214, 90))
end

-------------------------------------------------------------------------------------------------------------
-- villagers
-------------------------------------------------------------------------------------------------------------
local GNOME = {
	{ coat = C(64, 120, 200), pants = C(70, 72, 84), hat = C(214, 52, 48) },
	{ coat = C(236, 196, 70), pants = C(84, 110, 64), hat = C(64, 140, 80) },
	{ coat = C(196, 80, 140), pants = C(70, 60, 90), hat = C(250, 240, 230) },
}

local villagers = 0
local function villager(parent: Instance, cf: CFrame, act: string, look: number, path: { Vector3 }?)
	local g = GNOME[look]
	local roles = {
		skin = { nil, C(255, 204, 170) },
		beard = { nil, C(244, 240, 232) },
		coat = { nil, g.coat },
		pants = { nil, g.pants },
		hat = { nil, g.hat },
	}
	local m = CampProps.place("camp_gnome", parent, cf, { roles = roles, atomic = true, name = "Villager" })
	if not m then
		return
	end
	villagers += 1
	local attrs: { [string]: any } = { Act = act, Area = "lobby", Work = "", Seed = 700 + villagers }
	if path then
		local bits = {}
		for _, p in path do
			table.insert(bits, string.format("%.1f,%.1f", p.X, p.Z))
		end
		attrs.Path = table.concat(bits, ";")
	end
	tag(m, "CampVillager", attrs)
end

local function _people(world: Instance, ctx: Ctx)
	local f = folder(world, "Villagers")
	-- along the curved walk and back (a round there and back again)
	local round = {}
	for a = -ctx.walkArc + 6, ctx.walkArc - 6, 14 do
		table.insert(round, ctx.arc(a, ctx.walkR - 1.2))
	end
	for i = #round - 1, 2, -1 do
		table.insert(round, ctx.arc(-ctx.walkArc + 6 + (i - 1) * 14, ctx.walkR + 1.2))
	end
	villager(f, CFrame.new(round[1]), "walk", 1, round)
	-- along the cross walk, between the two stations, pausing on the way
	local cross = {
		Vector3.new(ctx.crossX0 + 2, 0, ctx.crossZ + 1.2),
		Vector3.new(-12, 0, ctx.crossZ + 1.2),
		Vector3.new(12, 0, ctx.crossZ - 1.2),
		Vector3.new(ctx.crossX1 - 2, 0, ctx.crossZ - 1.2),
		Vector3.new(12, 0, ctx.crossZ + 1.2),
		Vector3.new(-12, 0, ctx.crossZ - 1.2),
	}
	villager(f, CFrame.new(cross[2]), "walk", 2, cross)
	-- by the fountain, greeting whoever comes by
	local by = ctx.fountain + (ctx.spawn - ctx.fountain).Unit * 6.2 + Vector3.new(0, 0, 3)
	villager(f, CFrame.lookAt(by, Vector3.new(ctx.spawn.X, 0, ctx.spawn.Z)), "idle", 3)
end

-------------------------------------------------------------------------------------------------------------
-- the lands' animals
-------------------------------------------------------------------------------------------------------------
local SCALE = 1.5 -- (bigger than in the camps: they're seen from the square, 30 to 60 studs off)
local rng = Random.new(4411)

local function critter(parent: Instance, name: string, home: Vector3, kind: string, range: number, speed: number, scale: number?)
	local a = rng:NextNumber(0, math.pi * 2)
	local p = home + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0, range * 0.7)
	local m = CampProps.place(name, parent, CFrame.lookAt(p, p + Vector3.new(math.sin(a), 0, math.cos(a))), { atomic = true, scale = (scale or 1) * SCALE })
	if m then
		tag(m, "CampCritter", { Kind = kind, Home = home, Range = range, Speed = speed * 1.2, Seed = rng:NextInteger(1, 9999) })
	end
end

local function pond(parent: Instance, at: Vector3, r: number, water: Color3, stone: Color3, lily: boolean)
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local s = part(parent, "PondStone", Vector3.new(1.3, 0.7, r * 0.5), CFrame.new(at + Vector3.new(math.cos(a) * (r + 0.5), 0.3, math.sin(a) * (r + 0.5))) * CFrame.Angles(0, -a, 0), stone:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)), Enum.Material.Slate)
		s.CastShadow = false
	end
	local w = part(parent, "PondWater", Vector3.new(0.2, r * 2, r * 2), CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), water, Enum.Material.Glass)
	w.Shape = Enum.PartType.Cylinder
	w.Transparency = 0.2
	w.CastShadow = false
	local bed = part(parent, "PondBed", Vector3.new(0.1, r * 2, r * 2), CFrame.new(at + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), water:Lerp(Color3.new(0, 0, 0), 0.55), Enum.Material.Mud)
	bed.Shape = Enum.PartType.Cylinder
	if lily then
		for _ = 1, 5 do
			local a, d = rng:NextNumber(0, 6.28), rng:NextNumber(0.8, r - 1)
			local pad = part(parent, "LilyPad", Vector3.new(0.06, 1.6, 1.6), CFrame.new(at + Vector3.new(math.cos(a) * d, 0.25, math.sin(a) * d)) * CFrame.Angles(0, 0, math.rad(90)), C(90, 170, 70))
			pad.Shape = Enum.PartType.Cylinder
			pad.CastShadow = false
		end
	end
end

local function wisp(parent: Instance, home: Vector3, range: number)
	local m = Instance.new("Model")
	m.Name = "Wisp"
	local core = part(m, "WispCore", Vector3.one * 0.9, CFrame.new(home + Vector3.new(0, 4, 0)), C(170, 240, 255), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CastShadow = false
	local halo = part(m, "WispHalo", Vector3.one * 1.8, core.CFrame, C(150, 220, 255), Enum.Material.Neon)
	halo.Shape = Enum.PartType.Ball
	halo.Transparency = 0.7
	halo.CastShadow = false
	VoxelKit.light(core, 12, 0.8, C(150, 230, 255))
	m.WorldPivot = core.CFrame
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	tag(m, "CampCritter", { Kind = "float", Home = home + Vector3.new(0, 4, 0), Range = range, Speed = 2.4, Seed = rng:NextInteger(1, 9999) })
end

local function animals(world: Instance, ctx: Ctx)
	local f = folder(world, "Animals")
	for _, l in ctx.lands do
		local toward = Vector3.new(ctx.centre.X - l.pos.X, 0, ctx.centre.Z - l.pos.Z).Unit
		local right = toward:Cross(Vector3.yAxis)
		-- in front of the landmark, a little to one side of its door
		local home = l.pos + toward * 15 + right * 7
		home = Vector3.new(home.X, 0.12, home.Z)
		local id = l.id
		if id == "wheat" then
			for _ = 1, 4 do
				critter(f, "critter_chicken", home, "walk", 6, 1.6, 0.9)
			end
		elseif id == "blossom" then
			pond(f, home, 5, C(110, 180, 220), C(214, 200, 196), true)
			for _ = 1, 3 do
				critter(f, "critter_koi", home + Vector3.new(0, 0.12, 0), "swim", 3.6, 1.6, 0.8)
			end
			fxSpot(f, l.pos + toward * 12 + Vector3.new(0, 4, 0), Vector3.new(18, 6, 18), "butterflies", C(255, 150, 200))
		elseif id == "pine" then
			for i, d in { -3, 3 } do
				local foot = home + right * d + toward * (i - 1.5) * 2
				local h = 3.4 + i * 0.8
				VoxelKit.log(f, CFrame.new(foot + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), h, 1.1, 1.1, VoxelKit.C.log)
				local o = CampProps.place("critter_owl", f, CFrame.new(foot + Vector3.new(0, h, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { atomic = true, scale = SCALE })
				if o then
					tag(o, "CampCritter", { Kind = "perch", Home = o:GetPivot().Position, Range = 0, Speed = 0, Seed = rng:NextInteger(1, 9999) })
				end
			end
		elseif id == "swamp" then
			pond(f, home, 4.6, C(84, 120, 84), C(120, 126, 100), true)
			for _ = 1, 3 do
				critter(f, "critter_frog", home + toward * 0.5, "hop", 6.5, 2.0, 0.85)
			end
		elseif id == "frost" then
			for _ = 1, 3 do
				critter(f, "critter_penguin", home, "waddle", 5.5, 1.2, 0.9)
			end
		elseif id == "ember" then
			for i = 1, 4 do
				local a = i / 4 * math.pi * 2
				local c = part(f, "LavaCrack", Vector3.new(4, 0.06, 0.35), CFrame.new(home + Vector3.new(math.cos(a) * 2.6, 0.05, math.sin(a) * 2.6)) * CFrame.Angles(0, a, 0), C(255, 120, 40), Enum.Material.Neon)
				c.CastShadow = false
			end
			for _ = 1, 2 do
				critter(f, "critter_lizard", home, "crawl", 5, 1.4, 1.0)
			end
		elseif id == "isles" then
			for _ = 1, 4 do
				wisp(f, home, 7)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the horizon
-------------------------------------------------------------------------------------------------------------
-- A far landmass: stacked, shrinking blocks (a voxel hill), its layers' colours bottom to top. `peak`: a snowcap.
local function hill(parent: Instance, at: Vector3, w: number, h: number, layers: { Color3 }, seed: number)
	local r = Random.new(seed)
	local n = #layers
	local y = at.Y
	local lh = h / n
	for i, col in layers do
		local k = 1 - (i - 1) / n * 0.82
		local s = Vector3.new(w * k * r:NextNumber(0.9, 1.1), lh * 1.05, w * k * r:NextNumber(0.85, 1.05))
		local off = Vector3.new(r:NextNumber(-0.06, 0.06) * w * (1 - k), 0, r:NextNumber(-0.06, 0.06) * w * (1 - k))
		local p = part(parent, "Far", s, CFrame.new(at + off + Vector3.new(0, y - at.Y + lh / 2, 0)) * CFrame.Angles(0, math.rad(r:NextNumber(-25, 25)), 0), col, Enum.Material.SmoothPlastic)
		p.CastShadow = false
		y += lh
	end
end

local function volcano(parent: Instance, at: Vector3, w: number, h: number, toward: Vector3)
	local layers = { C(70, 62, 66), C(62, 54, 58), C(56, 48, 52), C(50, 42, 46), C(46, 38, 42), C(42, 34, 38), C(40, 32, 36), C(38, 30, 34) }
	hill(parent, at, w, h, layers, 91)
	local top = at + Vector3.new(0, h, 0)
	local crater = part(parent, "Crater", Vector3.new(w * 0.12, 1, w * 0.12), CFrame.new(top + Vector3.new(0, 0.2, 0)), C(255, 120, 36), Enum.Material.Neon)
	crater.CastShadow = false
	-- a lava flow down one side, in steps
	local lh = h / #layers
	for i = 1, #layers - 1 do
		local k = 1 - (i - 1) / #layers * 0.82
		local y = at.Y + lh * i
		local edge = w * k / 2
		local p = at + toward * edge + Vector3.new(0, y - lh / 2 - at.Y, 0)
		local flow = part(parent, "Lava", Vector3.new(w * 0.04, lh * 1.02, 1.2), CFrame.lookAt(p, p + toward), C(255, 110, 30), Enum.Material.Neon)
		flow.CastShadow = false
	end
	local smoke = Instance.new("Smoke")
	smoke.Color = C(70, 66, 70)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 12
	smoke.Size = 30
	smoke.Parent = crater
	VoxelKit.light(crater, 60, 2, C(255, 140, 60))
end

local function floatingIsle(parent: Instance, at: Vector3, w: number)
	local rock = { C(96, 84, 140), C(110, 96, 156), C(124, 110, 172), C(140, 126, 190) }
	-- an upside-down hill of rock, its top a lilac lawn with a crystal and a tree
	local y = at.Y
	for i = 1, #rock do
		local k = 0.25 + (i - 1) / #rock * 0.75
		local s = Vector3.new(w * k, w * 0.14, w * k)
		local p = part(parent, "Isle", s, CFrame.new(at.X, y + s.Y / 2, at.Z) * CFrame.Angles(0, math.rad(i * 17), 0), rock[i], Enum.Material.SmoothPlastic)
		p.CastShadow = false
		y += s.Y
	end
	local lawn = part(parent, "IsleTop", Vector3.new(w * 1.02, 1.2, w * 1.02), CFrame.new(at.X, y + 0.6, at.Z) * CFrame.Angles(0, math.rad(68), 0), C(186, 150, 255), Enum.Material.SmoothPlastic)
	lawn.CastShadow = false
	local cr = part(parent, "IsleCrystal", Vector3.new(w * 0.08, w * 0.3, w * 0.08), CFrame.new(at.X + w * 0.2, y + w * 0.15, at.Z) * CFrame.Angles(0, math.rad(45), math.rad(8)), C(120, 236, 255), Enum.Material.Neon)
	cr.CastShadow = false
	VM.place(parent, "Tree_isles_" .. (1 + math.floor(at.X) % 3), Vector3.new(at.X - w * 0.15, y + 1.2, at.Z - w * 0.1), { scale = w / 40 })
end

local function horizon(world: Instance, ctx: Ctx)
	local f = folder(world, "Horizon")
	local base = ctx.sea - 2
	local function at(deg: number, r: number): Vector3
		local a = math.rad(deg)
		return ctx.centre + Vector3.new(math.sin(a) * r, base - ctx.centre.Y, math.cos(a) * r)
	end
	local GREEN = { C(222, 204, 150), C(78, 150, 62), C(70, 140, 58), C(84, 160, 66), C(96, 170, 74), C(108, 180, 80) }
	local GOLD = { C(222, 204, 150), C(200, 160, 70), C(214, 172, 76), C(228, 186, 86), C(240, 200, 98) }
	local PINK = { C(222, 204, 150), C(98, 160, 92), C(110, 172, 100), C(232, 160, 196), C(246, 186, 214) }
	local PINE = { C(222, 204, 150), C(54, 112, 84), C(48, 104, 78), C(60, 120, 90), C(130, 140, 136), C(236, 242, 248) }
	local SWAMP = { C(140, 130, 96), C(96, 120, 64), C(88, 112, 58), C(104, 128, 70) }
	local SNOW = { C(150, 168, 190), C(170, 186, 206), C(196, 210, 226), C(220, 230, 242), C(240, 246, 252), C(250, 252, 255) }
	-- (degrees as the lands: from north, + to the left; each zone's shore behind its land)
	hill(f, at(0, 560), 260, 150, PINE, 11) -- behind the windmill: a long blue-green range with snow
	hill(f, at(22, 600), 200, 110, GREEN, 12)
	hill(f, at(-20, 610), 210, 120, GREEN, 13)
	hill(f, at(40, 520), 180, 90, GOLD, 14)
	hill(f, at(-40, 530), 170, 95, PINK, 15)
	hill(f, at(70, 560), 220, 170, PINE, 16)
	hill(f, at(-70, 540), 180, 70, SWAMP, 17)
	hill(f, at(104, 560), 240, 210, SNOW, 18) -- frost: the tallest, snowy peaks
	hill(f, at(126, 600), 160, 140, SNOW, 19)
	local vAt = at(-104, 560)
	volcano(f, vAt, 230, 180, Vector3.new(ctx.centre.X - vAt.X, 0, ctx.centre.Z - vAt.Z).Unit) -- ember
	hill(f, at(-130, 600), 160, 80, { C(90, 80, 84), C(76, 68, 72), C(64, 58, 62) }, 20)
	hill(f, at(150, 620), 200, 100, GREEN, 21)
	hill(f, at(-155, 620), 190, 110, GREEN, 22)
	-- the isles, behind the spawn: floating islands over the sea
	for i, p in { { 180, 470, 110, 50 }, { 196, 540, 150, 40 }, { 166, 560, 80, 34 } } do
		local pos = at(p[1], p[2]) + Vector3.new(0, p[3], 0)
		floatingIsle(f, pos, p[4])
		local _ = i
	end
end

-------------------------------------------------------------------------------------------------------------
function LobbyLife.dress(world: Instance, ctx: Ctx)
	local steps: { { any } } = {
		{ "fountain garden", fountainGarden },
		-- (no villagers: owner, 4 Nov, of the gnome by the fountain: "die kabouter is beetje slecht")
		{ "animals", animals },
		{ "horizon", horizon },
	}
	for _, s in steps do
		local ok, err = pcall(s[2], world, ctx)
		if not ok then
			warn("[LobbyLife] " .. s[1] .. ": " .. tostring(err))
		end
		task.wait()
	end
	-- butterflies over the two flower beds by the spawn
	local fx = folder(world, "LifeFX")
	for _, sx in { -1, 1 } do
		fxSpot(fx, Vector3.new(sx * 14, 3, ctx.spawn.Z + 10), Vector3.new(14, 4, 14), "butterflies", if sx < 0 then C(255, 240, 120) else C(150, 200, 255))
	end
end

return LobbyLife
