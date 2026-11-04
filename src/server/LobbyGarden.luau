--!strict
-- THE BACK GARDENS (owner, 4 Nov, turning round at the spawn: "I DONT LIKE THE BACK AREA OF THE MAP VERY VERY BLAND
-- AND EMPTY"). Behind the spawn the lawn ran 40 studs to the hedge with nothing on it, and past the hedge the
-- observatory stood alone in plain grass. server/LandsBuilder calls LobbyGarden.dress after the lands; LandsBuilder
-- lays the star walk's paving with the other walks (so the hedge and kerbs meet it) and leaves a wider gap in the
-- hedge for its gate. Facing the observatory from the spawn:
--   * THE STAR WALK down the middle: from the spawn's plaza through the hedge to a round landing at the
--     observatory's steps, lamps in pairs, two of the isles' lit pillars as a gate in the hedge, crystals glowing
--     either side of the landing, three little rocks floating above with crystals on them (a taste of the Isles);
--   * THE VEGETABLE PATCH on the left, behind the fountain: a white picket fence with a gate toward the walk, three
--     beds (cabbages, carrots, pumpkins), sunflowers along the back, a scarecrow, a gnome with a watering can,
--     a wheelbarrow and crates by the gate, stepping stones from the walk; beside it a red HEN HOUSE with its hens;
--   * between them and the walk: three little CHERRY TREES on the left, a PICNIC with two gnomes on the right;
--   * THE LILY POND on the right, behind the rewards stall: a pond with a stony edge, lily pads and flowers, koi,
--     reeds and cattails, a little wooden jetty you can walk out on with a gnome fishing off its end, a bench; past
--     it, by the garage, the golden MOWER STATUE;
--   * FLOWERS AND TALL GRASS in clusters over the lawn;
--   * past the hedge, ALL ROUND THE ISLAND between the hedge and the forest: little groves, bushes, rocks, tufts
--     and flowers in the nearest land's colours, so the ring of grass between the lands isn't bare either.
-- Lobby space as LandsBuilder's: y = 0 the ground, +Z north (the windmill), the observatory south of the spawn.
local CollectionService = game:GetService("CollectionService")

local CampProps = require(script.Parent.CampProps)
local Models = require(script.Parent.Models)
local VoxelKit = require(script.Parent.VoxelKit)
local VM = require(script.Parent.VoxelModels)

local LobbyGarden = {}

local C = Color3.fromRGB
local part = VoxelKit.part -- (parent, name, cf, size, color, look?, solid?)
local jitter = VoxelKit.jitter

export type Ctx = {
	spawn: Vector3,
	centre: Vector3, -- the hedge's (and the lands' ring's) middle
	hedgeR: number,
	backZ: number, -- the star walk's landing at the observatory's steps
	gateDeg: number, -- the gate pillars, this many degrees either side of the walk on the hedge
	lands: { { id: string, pos: Vector3 } },
	patchR: number, -- each land's own patch of ground
	forestR: number, -- the forest belt starts this far from the centre
	squareC: Vector3,
	squareR: number,
	covers: (x: number, z: number, grow: number) -> boolean, -- on (or within `grow` of) a walk
}

local rng = Random.new(5150)

local function tag(inst: Instance, name: string, attrs: { [string]: any })
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function flat(p: Vector3): Vector3
	return Vector3.new(p.X, 0, p.Z)
end

-- an invisible spot client/LobbyFX dresses (its Kind)
local function fxSpot(parent: Instance, at: Vector3, size: Vector3, kind: string, color: Color3?)
	local p = part(parent, kind .. "Spot", CFrame.new(at), size, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	tag(p, "LobbyFX", { Kind = kind, Color = color })
end

-- the things already standing on the lawn, so the scatter keeps off them: { x, z, r }
local taken: { { number } } = {}
local function take(x: number, z: number, r: number)
	table.insert(taken, { x, z, r })
end
local function free(x: number, z: number, r: number): boolean
	for _, t in taken do
		local dx, dz = x - t[1], z - t[2]
		if dx * dx + dz * dz < (r + t[3]) ^ 2 then
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- small things: flowers, tufts, villagers
-------------------------------------------------------------------------------------------------------------
local FLOWERS = {
	meadow = { C(255, 255, 250), C(255, 214, 60), C(255, 140, 180), C(170, 140, 255) },
	wheat = { C(255, 214, 60), C(240, 120, 60), C(255, 255, 250) },
	blossom = { C(255, 150, 200), C(255, 214, 236), C(255, 255, 250) },
	pine = { C(255, 255, 250), C(150, 190, 255) },
	swamp = { C(255, 255, 250), C(220, 200, 120) },
	frost = { C(220, 240, 255), C(170, 220, 255) },
	ember = { C(255, 140, 50), C(255, 200, 80) },
	isles = { C(190, 160, 255), C(140, 230, 255), C(255, 255, 250) },
}
local LEAF = C(56, 140, 44)

-- a patch of 5 to 7 little flowers (one block each) on two leaves, round (x, z)
local function flowers(parent: Instance, x: number, z: number, land: string)
	local cols = FLOWERS[land] or FLOWERS.meadow
	local main = cols[rng:NextInteger(1, #cols)]
	for _ = 1, 2 do
		local s = rng:NextNumber(0.8, 1.2)
		part(parent, "Leaf", CFrame.new(x + rng:NextNumber(-1, 1), 0.06, z + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 1.57), 0), Vector3.new(s, 0.12, s), jitter(rng, LEAF, 0.1))
	end
	for _ = 1, rng:NextInteger(5, 7) do
		local c = if rng:NextNumber() < 0.75 then main else cols[rng:NextInteger(1, #cols)]
		local h = rng:NextNumber(0.25, 0.7)
		local p = CFrame.new(x + rng:NextNumber(-1.6, 1.6), 0, z + rng:NextNumber(-1.6, 1.6))
		part(parent, "Stem", p * CFrame.new(0, h / 2, 0), Vector3.new(0.12, h, 0.12), LEAF)
		part(parent, "Flower", p * CFrame.new(0, h + 0.14, 0) * CFrame.Angles(0, rng:NextNumber(0, 1.57), 0), Vector3.new(0.5, 0.26, 0.5), c)
	end
end

-- a tuft of long grass: 5 to 7 blades leaning out from (x, z), `col` their green
local function tuft(parent: Instance, x: number, z: number, col: Color3, scale: number?)
	local k = scale or 1
	for i = 1, rng:NextInteger(5, 7) do
		local h = rng:NextNumber(1.2, 2.6) * k * (if i == 1 then 1.25 else 1)
		local a = rng:NextNumber(0, math.pi * 2)
		local lean = rng:NextNumber(0.1, 0.35)
		local base = CFrame.new(x + math.cos(a) * 0.35, 0, z + math.sin(a) * 0.35) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -lean)
		part(parent, "Blade", base * CFrame.new(0, h / 2, 0), Vector3.new(0.22 * k, h, 0.22 * k), jitter(rng, col, 0.12))
	end
end

local GNOME = {
	{ coat = C(64, 120, 200), pants = C(70, 72, 84), hat = C(214, 52, 48) },
	{ coat = C(236, 196, 70), pants = C(84, 110, 64), hat = C(64, 140, 80) },
	{ coat = C(196, 80, 140), pants = C(70, 60, 90), hat = C(250, 240, 230) },
	{ coat = C(110, 170, 90), pants = C(96, 70, 50), hat = C(240, 150, 40) },
}
-- the tools in a working gnome's right hand (as server/CampDress's, moved with the arm by client/CampLife)
local TOOLS: { [string]: (Model, CFrame) -> { BasePart } } = {
	water = function(m, hand)
		return {
			part(m, "Held", hand * CFrame.new(0, -0.45, -0.25), Vector3.new(0.8, 0.8, 1.0), C(110, 170, 140), Enum.Material.Metal),
			part(m, "Held", hand * CFrame.new(0, -0.25, -0.95) * CFrame.Angles(math.rad(35), 0, 0), Vector3.new(0.18, 0.18, 0.9), C(110, 170, 140), Enum.Material.Metal),
		}
	end,
	fish = function(m, hand)
		return { part(m, "Held", hand * CFrame.new(0, 1.3, -1.9) * CFrame.Angles(math.rad(-55), 0, 0), Vector3.new(0.12, 4.6, 0.12), C(150, 110, 70)) }
	end,
	gaze = function(m, hand)
		local star = part(m, "Held", hand * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.55, 0.55, 0.3), C(255, 230, 120), Enum.Material.Neon)
		VoxelKit.light(star, 8, 0.6, C(255, 230, 150))
		return { part(m, "Held", hand * CFrame.new(0, 0.9, 0), Vector3.new(0.2, 3.4, 0.2), C(120, 90, 160)), star }
	end,
}

local villagers = 0
local function villager(parent: Instance, cf: CFrame, act: string, look: number, work: string?)
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
	if work and TOOLS[work] then
		local hand = CampProps.markers(m, "Hand")[1]
		if hand then
			for _, p in TOOLS[work](m, hand.CFrame) do
				p:SetAttribute("G", "armR")
			end
		end
	end
	tag(m, "CampVillager", { Act = act, Area = "lobby", Work = work or "", Seed = 760 + villagers })
end

local function critter(parent: Instance, name: string, home: Vector3, kind: string, range: number, speed: number, scale: number)
	local a = rng:NextNumber(0, math.pi * 2)
	local p = home + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0, range * 0.7)
	local m = CampProps.place(name, parent, CFrame.lookAt(p, p + Vector3.new(math.sin(a), 0, math.cos(a))), { atomic = true, scale = scale })
	if m then
		tag(m, "CampCritter", { Kind = kind, Home = home, Range = range, Speed = speed, Seed = rng:NextInteger(1, 9999) })
	end
end

-------------------------------------------------------------------------------------------------------------
-- the star walk
-------------------------------------------------------------------------------------------------------------
local ISLE_GLOW = C(150, 230, 255)
local CRYSTAL = { C(176, 140, 255), C(120, 226, 255) }

local function floatingRock(parent: Instance, at: Vector3, s: number, seed: number)
	local m = Instance.new("Model")
	m.Name = "FloatingRock"
	local rock = VM.place(m, "Landmark_floatrock", at, { scale = s, yaw = rng:NextNumber(0, 6.28) })
	if not rock then
		-- (no voxel models imported) a little upside-down step pyramid of lilac rock
		for i = 1, 3 do
			local w = (4 - i) * 1.4 * s * 10
			part(m, "Isle", CFrame.new(at + Vector3.new(0, -i * 1.1 * s * 10, 0)), Vector3.new(w, 1.1 * s * 10, w), C(120 + i * 10, 104 + i * 10, 170 + i * 8), "stone")
		end
	end
	local top = at + Vector3.new(0, (VM.size("Landmark_floatrock") or Vector3.new(0, 4, 0)).Y * s * 0.62, 0)
	VoxelKit.crystals(m, CFrame.new(top), CRYSTAL[seed % 2 + 1], rng, 3, true)
	m.WorldPivot = CFrame.new(at)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	tag(m, "CampBob", { Amp = 0.9, Freq = 0.11 + seed * 0.02, Spin = (if seed % 2 == 0 then 3 else -3), Roll = 2 })
end

local function starWalk(world: Instance, ctx: Ctx)
	local f = folder(world, "StarWalk")
	local z0 = ctx.spawn.Z - 10
	-- lamps in pairs along the walk, turned to it
	for _, z in { z0 - 8, z0 - 20 } do
		for _, sx in { -1, 1 } do
			local p = Vector3.new(sx * 4.9, 0, z)
			if not Models.place("lantern_post", f, CFrame.lookAt(p, Vector3.new(0, 0, z)), 0.9, true) then
				VM.place(f, "S_lantern_post", p, { collide = true })
			end
			take(p.X, p.Z, 1.5)
		end
	end
	take(0, (z0 + ctx.backZ) / 2, 0) -- (the walk itself: ctx.covers)
	-- the gate: two of the isles' lit pillars on the hedge line either side of the walk
	for _, sx in { -1, 1 } do
		local a = math.rad(ctx.gateDeg * sx)
		local p = ctx.centre + Vector3.new(math.sin(a) * ctx.hedgeR, 0, -math.cos(a) * ctx.hedgeR)
		local m = Models.placeForge("fa_pillar_isles", f, CFrame.lookAt(p, Vector3.new(0, 0, p.Z + 20)), { height = 11 }, false)
		if m then
			-- (lit like the camps' plaza pillars: server/HubPlaza.frame)
			local box, size = m:GetBoundingBox()
			local lamp = part(f, "PillarLight", CFrame.new(box.Position + Vector3.new(0, size.Y * 0.36, 0)), Vector3.one * 0.4, ISLE_GLOW)
			lamp.Transparency = 1
			lamp.CastShadow = false
			VoxelKit.light(lamp, 16, 1.4, ISLE_GLOW)
		else
			VoxelKit.cylinder(f, "GatePost", CFrame.new(p), 7, 1.6, C(200, 190, 240), "stone")
		end
		take(p.X, p.Z, 3)
	end
	-- crystals glowing either side of the landing, and the stargazer by them
	for _, sx in { -1, 1 } do
		for i, off in { Vector3.new(23, 0, -3), Vector3.new(30, 0, -11), Vector3.new(35, 0, 1) } do
			local p = Vector3.new(sx * off.X, 0, ctx.backZ + off.Z)
			VoxelKit.crystals(f, CFrame.new(p), CRYSTAL[(i + (if sx > 0 then 1 else 0)) % 2 + 1], rng, if i == 1 then 5 else 3, i == 1)
			take(p.X, p.Z, 3)
		end
		fxSpot(f, Vector3.new(sx * 25, 3, ctx.backZ - 3), Vector3.new(8, 5, 8), "sparkle", ISLE_GLOW)
	end
	local gazer = Vector3.new(-15, 0, ctx.backZ - 0.5)
	villager(f, CFrame.lookAt(gazer, Vector3.new(0, 0, ctx.spawn.Z - 18)), "work", 3, "gaze")
	take(gazer.X, gazer.Z, 2)
	-- little rocks floating above the landing's sides, crystals on top (bobbing: client/CampLife)
	for i, p in { Vector3.new(-25, 17, ctx.backZ - 6), Vector3.new(27, 21, ctx.backZ - 12), Vector3.new(-9, 27, ctx.backZ - 30), Vector3.new(14, 15, ctx.backZ + 6) } do
		floatingRock(f, p, if i == 3 then 0.16 else 0.11, i)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the vegetable patch (left of the walk, behind the fountain)
-------------------------------------------------------------------------------------------------------------
local PICKET = C(246, 242, 232)
local SOIL = C(96, 66, 44)
local PATH = C(176, 138, 92)

local function picketSide(parent: Instance, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / 1.15))
	local along = (b - a).Unit
	for i = 0, n do
		local p = a + along * (i * len / n)
		local h = if i == 0 or i == n then 2.0 else 1.6
		part(parent, "Picket", CFrame.lookAt(p, p + along) * CFrame.new(0, h / 2, 0), Vector3.new(0.34, h, 0.34), PICKET, nil, true)
		part(parent, "PicketTip", CFrame.lookAt(p, p + along) * CFrame.new(0, h + 0.1, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.26, 0.26, 0.36), PICKET)
	end
	local mid = (a + b) / 2
	for _, y in { 0.55, 1.2 } do
		part(parent, "Rail", CFrame.lookAt(mid, mid + along) * CFrame.new(0, y, 0), Vector3.new(0.14, 0.24, len), PICKET:Lerp(Color3.new(0, 0, 0), 0.08), nil, true)
	end
end

local function sunflower(parent: Instance, foot: Vector3, face: Vector3)
	local h = rng:NextNumber(3.4, 4.6)
	local cf = CFrame.lookAt(foot, Vector3.new(face.X, foot.Y, face.Z))
	part(parent, "Stem", cf * CFrame.new(0, h / 2, 0), Vector3.new(0.26, h, 0.26), C(70, 140, 50))
	for _, s in { -1, 1 } do
		part(parent, "Leaf", cf * CFrame.new(s * 0.5, h * 0.45 + s * 0.3, 0) * CFrame.Angles(0, 0, s * math.rad(-25)), Vector3.new(0.9, 0.14, 0.6), C(80, 156, 56))
	end
	local head = cf * CFrame.new(0, h + 0.2, -0.25) * CFrame.Angles(math.rad(-15), 0, 0)
	part(parent, "Petals", head, Vector3.new(1.9, 1.9, 0.18), C(255, 206, 40))
	part(parent, "Petals", head * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(1.9, 1.9, 0.16), C(255, 186, 30))
	part(parent, "Seeds", head * CFrame.new(0, 0, -0.12), Vector3.new(0.95, 0.95, 0.16), C(110, 70, 36))
end

local function crop(parent: Instance, kind: string, at: CFrame)
	if kind == "cabbage" then
		part(parent, "Cabbage", at * CFrame.new(0, 0.42, 0) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Vector3.new(0.95, 0.75, 0.95), jitter(rng, C(118, 190, 92), 0.08))
		part(parent, "CabbageTop", at * CFrame.new(0, 0.86, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(0.6, 0.3, 0.6), C(176, 226, 130))
		for _, a in { 0, 2.1, 4.2 } do
			part(parent, "CabbageLeaf", at * CFrame.Angles(0, a, 0) * CFrame.new(0.55, 0.25, 0) * CFrame.Angles(0, 0, math.rad(-30)), Vector3.new(0.7, 0.12, 0.55), C(96, 170, 74))
		end
	elseif kind == "carrot" then
		part(parent, "CarrotTop", at * CFrame.new(0, 0.14, 0), Vector3.new(0.42, 0.24, 0.42), C(240, 128, 40))
		for _, a in { 0, 2.1, 4.2 } do
			part(parent, "CarrotLeaf", at * CFrame.Angles(0, a, 0) * CFrame.new(0.12, 0.62, 0) * CFrame.Angles(0, 0, math.rad(-18)), Vector3.new(0.14, 0.9, 0.14), C(90, 176, 60))
		end
	else -- pumpkin
		local s = rng:NextNumber(0.9, 1.35)
		part(parent, "Pumpkin", at * CFrame.new(0, s * 0.38, 0) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Vector3.new(s, s * 0.76, s), jitter(rng, C(240, 140, 40), 0.06))
		part(parent, "PumpkinRib", at * CFrame.new(0, s * 0.38, 0), Vector3.new(s * 1.06, s * 0.6, s * 0.4), C(226, 120, 34))
		part(parent, "PumpkinStem", at * CFrame.new(0, s * 0.8, 0), Vector3.new(0.16, 0.34, 0.16), C(90, 110, 50))
		part(parent, "PumpkinLeaf", at * CFrame.new(s * 0.7, 0.08, 0.2) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Vector3.new(0.9, 0.12, 0.9), C(80, 150, 60))
	end
end

local function vegetablePatch(world: Instance, ctx: Ctx)
	local f = folder(world, "VegetablePatch")
	local A = Vector3.new(-31, 0, ctx.spawn.Z - 18)
	local W, D = 15, 9
	take(A.X, A.Z, 9.5)
	-- the ground: a low soil bed, three raised beds with straw paths between
	part(f, "PatchGround", CFrame.new(A + Vector3.new(0, 0.05, 0)), Vector3.new(W - 0.6, 0.1, D - 0.6), PATH, Enum.Material.Ground)
	local rows = { { z = 2.6, kind = "cabbage" }, { z = 0, kind = "carrot" }, { z = -2.6, kind = "pumpkin" } }
	for _, r in rows do
		local bed = CFrame.new(A + Vector3.new(-0.6, 0, r.z))
		part(f, "Bed", bed * CFrame.new(0, 0.2, 0), Vector3.new(W - 3, 0.3, 1.8), jitter(rng, SOIL, 0.05), Enum.Material.Ground)
		local n = if r.kind == "pumpkin" then 6 else 8
		for i = 1, n do
			local x = -(W - 3) / 2 + (i - 0.5) * (W - 3) / n
			crop(f, r.kind, bed * CFrame.new(x + rng:NextNumber(-0.15, 0.15), 0.35, rng:NextNumber(-0.15, 0.15)))
		end
	end
	-- the fence, its gate toward the walk (east), sunflowers along the back facing the spawn
	local x0, x1, za, zb = A.X - W / 2, A.X + W / 2, A.Z - D / 2, A.Z + D / 2
	picketSide(f, Vector3.new(x0, 0, za), Vector3.new(x1, 0, za))
	picketSide(f, Vector3.new(x0, 0, zb), Vector3.new(x1, 0, zb))
	picketSide(f, Vector3.new(x0, 0, za), Vector3.new(x0, 0, zb))
	picketSide(f, Vector3.new(x1, 0, za), Vector3.new(x1, 0, A.Z - 1.5))
	picketSide(f, Vector3.new(x1, 0, A.Z + 1.5), Vector3.new(x1, 0, zb))
	for i = 1, 5 do
		local p = Vector3.new(x0 + 1.6 + (i - 1) * (W - 3.6) / 4, 0, za + 0.75)
		sunflower(f, p, ctx.spawn)
	end
	-- the scarecrow among the carrots, the gardener watering the cabbages
	CampProps.place("camp_scarecrow", f, CFrame.lookAt(A + Vector3.new(-3.2, 0.3, 0), ctx.spawn), { atomic = true })
	local g = A + Vector3.new(2.5, 0, 1.3)
	villager(f, CFrame.lookAt(g, g + Vector3.new(-0.4, 0, 1)), "work", 4, "water")
	-- by the gate: a wheelbarrow of pumpkins, crates, a barrel
	local gate = Vector3.new(x1, 0, A.Z)
	if VM.place(f, "Prop_wheelbarrow", gate + Vector3.new(2.6, 0, -3.4), { scale = 0.9, yaw = math.rad(200), collide = true }) == nil then
		VoxelKit.crate(f, CFrame.new(gate + Vector3.new(2.6, 0.7, -3.4)), 1.4, rng)
	end
	VoxelKit.crate(f, CFrame.new(gate + Vector3.new(2.2, 0.6, 3.2)) * CFrame.Angles(0, 0.3, 0), 1.2, rng)
	crop(f, "pumpkin", CFrame.new(gate + Vector3.new(2.2, 1.2, 3.2)))
	VoxelKit.barrel(f, CFrame.new(gate + Vector3.new(3.6, 0, 4.3)), 1.6, rng)
	take(gate.X + 3, gate.Z, 3.5)
	-- stepping stones from the walk to the gate
	local from, to = Vector3.new(-3.6, 0, A.Z), gate + Vector3.new(1.4, 0, 0)
	local n = 7
	for i = 0, n - 1 do
		local p = from:Lerp(to, (i + 0.5) / n) + Vector3.new(0, 0.08, rng:NextNumber(-0.5, 0.5))
		part(f, "SteppingStone", CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Vector3.new(1.6, 0.16, 1.3), jitter(rng, C(214, 206, 192), 0.06))
		take(p.X, p.Z, 1.2)
	end
	fxSpot(f, A + Vector3.new(0, 3.5, 0), Vector3.new(14, 4, 9), "butterflies", C(255, 236, 120))
end

-------------------------------------------------------------------------------------------------------------
-- the lily pond (right of the walk, behind the rewards stall)
-------------------------------------------------------------------------------------------------------------
local WATER = C(84, 176, 222)
local WATER_BED = C(40, 92, 110)

local function pond(world: Instance, ctx: Ctx)
	local f = folder(world, "LilyPond")
	local O = Vector3.new(36, 0, ctx.spawn.Z - 18)
	-- a kidney of three round pools, laid in one-stud cells (the voxel look, and no doubled water where they overlap)
	local blobs: { { c: Vector3, r: number } } = { { c = O, r = 6.5 }, { c = O + Vector3.new(-7, 0, -6), r = 4.5 }, { c = O + Vector3.new(7, 0, 6), r = 3.5 } }
	local function wet(x: number, z: number, grow: number): boolean
		for _, b in blobs do
			local dx, dz = x - b.c.X, z - b.c.Z
			if dx * dx + dz * dz < (b.r + grow) ^ 2 then
				return true
			end
		end
		return false
	end
	for _, b in blobs do
		take(b.c.X, b.c.Z, b.r + 1.5)
	end
	-- the jetty's spot (built below): from the grass on the walk's side out over the big pool
	local jz = O.Z + 2.2
	local jx0, jx1 = O.X - 9, O.X - 1.5
	local x0, x1 = math.floor(O.X - 15), math.ceil(O.X + 15)
	for z = math.floor(O.Z - 15), math.ceil(O.Z + 15) do
		local run: number? = nil
		for x = x0, x1 + 1 do
			local inside = x <= x1 and wet(x + 0.5, z + 0.5, 0)
			if inside and run == nil then
				run = x
			elseif not inside and run ~= nil then
				local len = x - run
				local mid = Vector3.new(run + len / 2, 0, z + 0.5)
				part(f, "PondBed", CFrame.new(mid + Vector3.new(0, 0.04, 0)), Vector3.new(len, 0.08, 1), WATER_BED, Enum.Material.Mud)
				local w = part(f, "PondWater", CFrame.new(mid + Vector3.new(0, 0.17, 0)), Vector3.new(len, 0.1, 1), WATER, Enum.Material.Glass)
				w.Transparency = 0.25
				w.CastShadow = false
				run = nil
			end
		end
	end
	-- the stony edge: a stone on every edge cell, a few left out where grass runs down to the water
	for z = math.floor(O.Z - 16), math.ceil(O.Z + 16), 1.3 do
		for x = x0 - 1, x1 + 1, 1.3 do
			local underJetty = math.abs(z - jz) < 1.9 and x > jx0 - 0.5 and x < jx1 + 0.5
			if not wet(x, z, 0) and wet(x, z, 1.3) and not underJetty and rng:NextNumber() < 0.85 then
				-- (plain light stones: the pixel stone texture came out nearly black on the grass)
				local h = rng:NextNumber(0.3, 0.6)
				local s = rng:NextNumber(1.1, 1.5)
				local st = part(f, "PondStone", CFrame.new(x, h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1.57), 0), Vector3.new(s, h, s * rng:NextNumber(0.8, 1.1)), jitter(rng, C(204, 198, 186), 0.08))
				st.CastShadow = false
			end
		end
	end
	-- lily pads, three in flower, and a frog sitting on one
	local pads: { Vector3 } = {}
	for _ = 1, 40 do
		if #pads >= 8 then
			break
		end
		local p = O + Vector3.new(rng:NextNumber(-11, 11), 0, rng:NextNumber(-10, 10))
		if wet(p.X, p.Z, -1.2) then
			local ok = true
			for _, q in pads do
				if (q - p).Magnitude < 2.4 then
					ok = false
				end
			end
			if ok then
				table.insert(pads, p)
			end
		end
	end
	for i, p in pads do
		local s = rng:NextNumber(1.3, 1.9)
		local pad = part(f, "LilyPad", CFrame.new(p + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Vector3.new(s, 0.08, s), jitter(rng, C(86, 168, 66), 0.08))
		pad.CastShadow = false
		if i <= 3 then
			part(f, "LilyPetal", CFrame.new(p + Vector3.new(0.2, 0.42, 0.1)) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(0.7, 0.24, 0.7), C(255, 168, 210))
			part(f, "LilyPetal", CFrame.new(p + Vector3.new(0.2, 0.5, 0.1)), Vector3.new(0.5, 0.22, 0.5), C(255, 214, 236))
			part(f, "LilyHeart", CFrame.new(p + Vector3.new(0.2, 0.62, 0.1)), Vector3.new(0.22, 0.12, 0.22), C(255, 214, 80))
		elseif i == 4 then
			local frog = CampProps.place("critter_frog", f, CFrame.new(p + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { atomic = true, scale = 1.2 })
			if frog then
				tag(frog, "CampCritter", { Kind = "perch", Home = frog:GetPivot().Position, Range = 0, Speed = 0, Seed = rng:NextInteger(1, 9999) })
			end
		end
	end
	-- koi going round the big pool
	for _ = 1, 3 do
		critter(f, "critter_koi", O + Vector3.new(0, 0.14, 0), "swim", 4.2, 1.6, 1.1)
	end
	-- reeds and cattails at the far edges
	-- (angles in x, z: the far side, toward the hedge)
	for _, spot in { { 1, -0.5 }, { 1, -1.15 }, { 2, -2.0 }, { 2, -2.7 }, { 3, 0.3 } } do
		local b = blobs[spot[1]]
		local a = spot[2]
		local foot = b.c + Vector3.new(math.cos(a) * (b.r + 0.6), 0, math.sin(a) * (b.r + 0.6))
		for _ = 1, 7 do
			local h = rng:NextNumber(2.0, 3.8)
			local p = foot + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			local tilt = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
			part(f, "Reed", CFrame.new(p) * tilt * CFrame.new(0, h / 2, 0), Vector3.new(0.2, h, 0.2), jitter(rng, C(96, 150, 70), 0.1))
			if rng:NextNumber() < 0.45 then
				part(f, "Cattail", CFrame.new(p) * tilt * CFrame.new(0, h - 0.35, 0), Vector3.new(0.38, 0.95, 0.38), C(116, 74, 46))
			end
		end
	end
	-- the jetty: solid, walk out on it
	local wood = C(150, 112, 78)
	local np = 8
	for i = 0, np - 1 do
		local x = jx0 + (i + 0.5) * (jx1 - jx0) / np
		part(f, "Plank", CFrame.new(x, 0.6, jz), Vector3.new((jx1 - jx0) / np - 0.12, 0.25, 2.8), jitter(rng, wood, 0.07), Enum.Material.WoodPlanks, true)
	end
	for _, x in { jx0 + 0.6, (jx0 + jx1) / 2, jx1 - 0.4 } do
		for _, s in { -1, 1 } do
			part(f, "JettyPost", CFrame.new(x, 0.55, jz + s * 1.45), Vector3.new(0.4, 1.3, 0.4), C(110, 80, 56), "log")
		end
	end
	take((jx0 + jx1) / 2, jz, 5)
	local fisher = Vector3.new(jx1 - 0.9, 0.72, jz - 0.4)
	villager(f, CFrame.lookAt(fisher, fisher + Vector3.new(1, 0, -0.15)), "work", 1, "fish")
	-- a bench on the grass facing the water
	local bp = O + Vector3.new(4, 0, 10.5)
	if VM.place(f, "Prop_bench", bp, { yaw = math.atan2(-(O.X - bp.X), -(O.Z - bp.Z)), collide = true }) == nil then
		VoxelKit.log(f, CFrame.lookAt(bp, O) * CFrame.new(0, 1, 0), 5, 0.6, 1.4, VoxelKit.C.log)
	end
	take(bp.X, bp.Z, 3.5)
	fxSpot(f, O + Vector3.new(0, 2.5, 0), Vector3.new(16, 3, 14), "butterflies", C(150, 220, 255))
end

-------------------------------------------------------------------------------------------------------------
-- the farm corner, the picnic, the cherry trees, the statue
-------------------------------------------------------------------------------------------------------------
local BARN = C(196, 84, 64)
local TRIM = C(246, 238, 222)
local ROOF = C(112, 80, 62)

-- a little red hen house on legs left of the fountain, a ramp down to its yard, the hens round it
local function henHouse(world: Instance, ctx: Ctx)
	local f = folder(world, "HenHouse")
	local at = Vector3.new(-47, 0, ctx.spawn.Z - 4)
	local cf = CFrame.lookAt(at, Vector3.new(ctx.spawn.X, 0, ctx.spawn.Z - 8))
	take(at.X, at.Z, 5)
	for _, x in { -1.8, 1.8 } do
		for _, z in { -1.3, 1.3 } do
			part(f, "Leg", cf * CFrame.new(x, 0.6, z), Vector3.new(0.45, 1.2, 0.45), C(150, 110, 80), "log", true)
		end
	end
	part(f, "Floor", cf * CFrame.new(0, 1.3, 0), Vector3.new(4.6, 0.25, 3.4), C(120, 88, 64), Enum.Material.WoodPlanks, true)
	part(f, "Body", cf * CFrame.new(0, 2.65, 0), Vector3.new(4.4, 2.5, 3.2), BARN, Enum.Material.WoodPlanks, true)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -1.6, 1.6 } do
			part(f, "Trim", cf * CFrame.new(x, 2.65, z), Vector3.new(0.3, 2.55, 0.3), TRIM)
		end
	end
	part(f, "TrimTop", cf * CFrame.new(0, 3.9, -1.6), Vector3.new(4.7, 0.25, 0.3), TRIM)
	-- the gable roof, two slabs and a ridge
	for _, s in { -1, 1 } do
		part(f, "Roof", cf * CFrame.new(0, 4.55, s * 0.95) * CFrame.Angles(s * math.rad(32), 0, 0), Vector3.new(5.2, 0.3, 2.6), ROOF, nil, true)
	end
	part(f, "Ridge", cf * CFrame.new(0, 5.25, 0), Vector3.new(5.3, 0.3, 0.4), ROOF:Lerp(Color3.new(0, 0, 0), 0.2))
	part(f, "Gable", cf * CFrame.new(-2.21, 4.15, 0) * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(0.2, 1.6, 1.6), BARN)
	part(f, "Gable", cf * CFrame.new(2.21, 4.15, 0) * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(0.2, 1.6, 1.6), BARN)
	-- the door with straw in it, a round window, the ramp with its cleats
	part(f, "Door", cf * CFrame.new(-0.9, 2.3, -1.61), Vector3.new(1.2, 1.5, 0.06), C(40, 30, 26))
	part(f, "Straw", cf * CFrame.new(-0.9, 1.65, -1.55), Vector3.new(1.0, 0.25, 0.2), VoxelKit.C.straw)
	local win = part(f, "Window", cf * CFrame.new(1.0, 2.9, -1.62) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, 0.9, 0.9), C(255, 214, 140), Enum.Material.Neon)
	win.Shape = Enum.PartType.Cylinder
	local ramp = cf * CFrame.new(-0.9, 0.85, -2.95) * CFrame.Angles(math.rad(-33), 0, 0)
	part(f, "Ramp", ramp, Vector3.new(1.1, 0.16, 3.0), C(150, 112, 78), Enum.Material.WoodPlanks, true)
	for k = -1, 1 do
		part(f, "Cleat", ramp * CFrame.new(0, 0.12, k * 0.8), Vector3.new(1.1, 0.1, 0.14), C(110, 80, 56))
	end
	-- the yard: straw on the ground, a feed trough, a hay bale
	for _ = 1, 6 do
		part(f, "StrawBit", CFrame.new(at + Vector3.new(rng:NextNumber(-4, 4), 0.05, rng:NextNumber(-4, 4))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(rng:NextNumber(0.8, 1.6), 0.1, rng:NextNumber(0.5, 1.0)), jitter(rng, VoxelKit.C.straw, 0.08))
	end
	local trough = cf * CFrame.new(2.6, 0.3, -3.6)
	part(f, "Trough", trough, Vector3.new(2.2, 0.6, 0.8), C(140, 104, 72), Enum.Material.WoodPlanks)
	part(f, "Grain", trough * CFrame.new(0, 0.28, 0), Vector3.new(1.9, 0.08, 0.55), C(232, 196, 110))
	VoxelKit.hay(f, cf * CFrame.new(-3.4, 0, 1.6) * CFrame.Angles(0, 0.3, 0), rng)
	for _ = 1, 3 do
		critter(f, "critter_chicken", (cf * CFrame.new(0, 0.12, -5)).Position, "walk", 3.4, 1.6, 1.2)
	end
end

-- a picnic on the lawn right of the walk: a checked blanket, a basket, plates, two gnomes sitting on it
local function picnic(world: Instance, ctx: Ctx)
	local f = folder(world, "Picnic")
	local at = Vector3.new(15, 0, ctx.spawn.Z - 29)
	local cf = CFrame.new(at) * CFrame.Angles(0, math.rad(12), 0)
	take(at.X, at.Z, 5)
	for i = 0, 3 do
		for j = 0, 2 do
			local red = (i + j) % 2 == 0
			part(f, "Blanket", cf * CFrame.new(-2.25 + i * 1.5, 0.06, -1.5 + j * 1.5), Vector3.new(1.5, 0.08, 1.5), if red then C(220, 64, 60) else C(250, 244, 236), Enum.Material.Fabric)
		end
	end
	local basket = cf * CFrame.new(0.4, 0, 0)
	part(f, "Basket", basket * CFrame.new(0, 0.45, 0), Vector3.new(1.3, 0.7, 0.9), C(196, 150, 90), Enum.Material.Fabric)
	part(f, "BasketLid", basket * CFrame.new(0, 0.86, 0.2), Vector3.new(1.35, 0.12, 0.5), C(176, 130, 76))
	part(f, "Handle", basket * CFrame.new(0, 1.25, -0.05), Vector3.new(1.0, 0.14, 0.14), C(150, 110, 66))
	for _, x in { -0.45, 0.45 } do
		part(f, "Handle", basket * CFrame.new(x, 1.0, -0.05), Vector3.new(0.14, 0.5, 0.14), C(150, 110, 66))
	end
	for _, z in { -0.9, 0.9 } do
		local plate = part(f, "Plate", cf * CFrame.new(-1.3, 0.14, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, 0.95, 0.95), C(250, 250, 250))
		plate.Shape = Enum.PartType.Cylinder
		part(f, "Sandwich", cf * CFrame.new(-1.3, 0.25, z), Vector3.new(0.55, 0.18, 0.4), C(236, 200, 140))
	end
	local apple = part(f, "Apple", cf * CFrame.new(1.6, 0.3, 0.9), Vector3.one * 0.42, C(220, 50, 46))
	apple.Shape = Enum.PartType.Ball
	part(f, "Juice", cf * CFrame.new(1.6, 0.5, -0.7), Vector3.new(0.35, 0.8, 0.35), C(255, 170, 60), Enum.Material.Glass)
	-- the two picnickers on the blanket's long sides, facing each other (sitting: client/CampLife)
	for i, z in { -2.1, 2.1 } do
		local p = (cf * CFrame.new(-0.6, -0.85, z)).Position
		villager(f, CFrame.lookAt(p, (cf * CFrame.new(-0.6, -0.85, 0)).Position), "sit", if i == 1 then 2 else 3)
	end
end

-- three little cherry trees left of the walk, petals on the grass under them, a basket of cherries
local function orchard(world: Instance, ctx: Ctx)
	local f = folder(world, "Orchard")
	for i, p in { Vector3.new(-12, 0, ctx.spawn.Z - 30), Vector3.new(-21, 0, ctx.spawn.Z - 31.5), Vector3.new(-15, 0, ctx.spawn.Z - 37) } do
		local s = if i == 1 then 0.32 else 0.27
		if VM.place(f, "Tree_blossom_" .. i, p, { scale = s, yaw = rng:NextInteger(0, 3) * math.pi / 2 }) then
			VM.blocker(f, Vector3.new(4.8 * s, 20 * s, 4.8 * s), CFrame.new(p + Vector3.new(0, 10 * s, 0)))
		end
		take(p.X, p.Z, 4.5)
		for _ = 1, 9 do
			local a, d = rng:NextNumber(0, 6.28), rng:NextNumber(1.5, 5)
			part(f, "Petal", CFrame.new(p + Vector3.new(math.cos(a) * d, 0.04, math.sin(a) * d)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Vector3.new(0.4, 0.06, 0.4), if rng:NextNumber() < 0.6 then C(255, 170, 210) else C(255, 220, 236))
		end
	end
	local b = Vector3.new(-8.6, 0, ctx.spawn.Z - 35)
	part(f, "Basket", CFrame.new(b + Vector3.new(0, 0.4, 0)), Vector3.new(1.2, 0.8, 1.2), C(196, 150, 90), Enum.Material.Fabric)
	for _ = 1, 6 do
		local c = part(f, "Cherry", CFrame.new(b + Vector3.new(rng:NextNumber(-0.35, 0.35), 0.9, rng:NextNumber(-0.35, 0.35))), Vector3.one * 0.32, C(200, 30, 50))
		c.Shape = Enum.PartType.Ball
	end
	fxSpot(f, Vector3.new(-16, 4, ctx.spawn.Z - 33), Vector3.new(14, 5, 12), "butterflies", C(255, 170, 210))
end

-- the golden mower statue (it has its own mossy stone base) between the pond and the garage, turned to the spawn
local function statue(world: Instance, ctx: Ctx)
	local f = folder(world, "MowerStatue")
	local at = Vector3.new(52, 0, ctx.spawn.Z - 3)
	local cf = CFrame.lookAt(at, Vector3.new(ctx.spawn.X, 0, ctx.spawn.Z))
	take(at.X, at.Z, 5.5)
	if VM.place(f, "Prop_mower_statue", at, { scale = 0.8, yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z), collide = true }) == nil then
		Models.place("mower_tractor", f, cf, 0.8, true)
	end
	for _, c in { Vector3.new(-4.6, 0, -4.6), Vector3.new(4.6, 0, -4.6), Vector3.new(-4.6, 0, 4.6), Vector3.new(4.6, 0, 4.6) } do
		local p = (cf * CFrame.new(c)).Position
		flowers(f, p.X, p.Z, "meadow")
	end
	fxSpot(f, (cf * CFrame.new(0, 5, 0)).Position, Vector3.new(6, 6, 6), "sparkle", C(255, 220, 120))
end

-------------------------------------------------------------------------------------------------------------
-- the lawn behind the spawn, and the ring past the hedge
-------------------------------------------------------------------------------------------------------------
local function nearestLand(ctx: Ctx, x: number, z: number): (string, number)
	local best, bd = "meadow", math.huge
	for _, l in ctx.lands do
		local d = (Vector3.new(x, 0, z) - flat(l.pos)).Magnitude
		if d < bd then
			best, bd = l.id, d
		end
	end
	return best, bd
end

local GRASS = C(70, 160, 52)
local BUSH = { meadow = "Bush_meadow", wheat = "Bush_wheat", blossom = "Bush_blossom", pine = "Bush_pine", swamp = "Bush_swamp", frost = "Bush_frost", ember = "Bush_ember", isles = "Bush_isles" }

-- One cluster at (x, z) in `land`'s look: a bush with tufts and flowers round it, or a rock with tufts, or a
-- patch of flowers, or long grass.
local function cluster(parent: Instance, x: number, z: number, land: string, big: boolean)
	local roll = rng:NextNumber()
	if big and roll < 0.45 then
		local s = rng:NextNumber(0.42, 0.62)
		if VM.place(parent, BUSH[land] or "Bush_meadow", Vector3.new(x, 0, z), { scale = s, yaw = rng:NextInteger(0, 3) * math.pi / 2 }) == nil then
			VoxelKit.bush(parent, CFrame.new(x, 0, z), C(66, 140, 52), rng, FLOWERS[land])
		end
		for _ = 1, 2 do
			local a = rng:NextNumber(0, 6.28)
			tuft(parent, x + math.cos(a) * 3.4, z + math.sin(a) * 3.4, GRASS)
		end
		flowers(parent, x + rng:NextNumber(-4, 4), z + rng:NextNumber(3, 4.5), land)
	elseif big and roll < 0.62 then
		if VM.place(parent, "Rock_" .. land, Vector3.new(x, -0.3, z), { scale = rng:NextNumber(0.24, 0.36), yaw = rng:NextNumber(0, 6.28) }) == nil then
			VoxelKit.rocks(parent, CFrame.new(x, 0, z), C(170, 168, 160), rng, 3)
		end
		tuft(parent, x + 2.6, z + 1, GRASS)
		tuft(parent, x - 2.2, z - 1.4, GRASS, 0.8)
	elseif roll < 0.82 then
		flowers(parent, x, z, land)
		if rng:NextNumber() < 0.5 then
			flowers(parent, x + rng:NextNumber(2.5, 3.5), z + rng:NextNumber(-2, 2), land)
		end
	else
		for _ = 1, 3 do
			tuft(parent, x + rng:NextNumber(-2, 2), z + rng:NextNumber(-2, 2), GRASS)
		end
	end
end

local function lawn(world: Instance, ctx: Ctx)
	local f = folder(world, "BackLawn")
	-- flowers and long grass over the lawn behind the spawn (the hedge itself is voxel bushes now: LandsBuilder)
	local placed = 0
	for _ = 1, 400 do
		if placed >= 40 then
			break
		end
		local x, z = rng:NextNumber(-62, 62), rng:NextNumber(ctx.backZ, ctx.spawn.Z - 6)
		local d = (Vector3.new(x, 0, z) - flat(ctx.centre)).Magnitude
		if d < ctx.hedgeR - 3 and free(x, z, 2.6) and not ctx.covers(x, z, 2.2) and z < ctx.spawn.Z - 4 then
			if rng:NextNumber() < 0.7 then
				flowers(f, x, z, "meadow")
			else
				tuft(f, x, z, GRASS)
				tuft(f, x + rng:NextNumber(1.2, 2), z + rng:NextNumber(-1, 1), GRASS, 0.8)
			end
			take(x, z, 2.4)
			placed += 1
		end
	end
end

local function ring(world: Instance, ctx: Ctx)
	local f = folder(world, "Meadows")
	local cx, cz = ctx.centre.X, ctx.centre.Z
	local n = 0
	for gx = -150, 150, 13 do
		for gz = -170, 130, 13 do
			local x, z = gx + rng:NextNumber(-4, 4), gz + rng:NextNumber(-4, 4)
			local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
			local land, ld = nearestLand(ctx, x, z)
			local inSquare = (Vector3.new(x, 0, z) - flat(ctx.squareC)).Magnitude < ctx.squareR + 4
			local onHedge = d > ctx.hedgeR - 5 and d < ctx.hedgeR + 6
			if d < ctx.forestR - 6 and not inSquare and not onHedge and ld > ctx.patchR - 2 and free(x, z, 4) and not ctx.covers(x, z, 4) then
				if rng:NextNumber() < 0.62 then
					cluster(f, x, z, land, true)
					take(x, z, 4)
					n += 1
				end
			end
		end
		task.wait()
	end
	-- two small groves framing the observatory, in the isles' violet
	for _, sx in { -1, 1 } do
		for i, off in { Vector3.new(46, 0, -14), Vector3.new(58, 0, -2), Vector3.new(40, 0, -27) } do
			local p = Vector3.new(sx * off.X, 0, ctx.backZ + off.Z)
			local name = "Tree_isles_" .. ((i + (if sx > 0 then 1 else 0)) % 3 + 1)
			local s = if i == 1 then 0.5 else 0.38
			if VM.place(f, name, p, { scale = s, yaw = rng:NextInteger(0, 3) * math.pi / 2 }) then
				VM.blocker(f, Vector3.new(4.8 * s, 20 * s, 4.8 * s), CFrame.new(p + Vector3.new(0, 10 * s, 0)))
			end
			for _ = 1, 2 do
				local a = rng:NextNumber(0, 6.28)
				flowers(f, p.X + math.cos(a) * 6, p.Z + math.sin(a) * 6, "isles")
			end
		end
	end
	return n
end

-------------------------------------------------------------------------------------------------------------
function LobbyGarden.dress(world: Instance, ctx: Ctx)
	table.clear(taken)
	-- (the fountain garden and the rewards stall, already standing behind the spawn's sides)
	take(-26, ctx.spawn.Z, 10)
	take(20, ctx.spawn.Z - 8, 9)
	local steps: { { any } } = {
		{ "star walk", starWalk },
		{ "vegetable patch", vegetablePatch },
		{ "lily pond", pond },
		{ "hen house", henHouse },
		{ "picnic", picnic },
		{ "cherry trees", orchard },
		{ "statue", statue },
		{ "lawn", lawn },
		{ "meadows", ring },
	}
	for _, s in steps do
		local ok, err = pcall(s[2], world, ctx)
		if not ok then
			warn("[LobbyGarden] " .. s[1] .. ": " .. tostring(err))
		end
		task.wait()
	end
end

return LobbyGarden
