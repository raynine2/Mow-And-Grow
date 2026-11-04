--!strict
-- THE LOBBY: THE GATES TO THE EIGHT LANDS (4 Nov, third remake; owner, on a lobby of blocks: "U CALL THIS A MAIN LOBBY
-- THIS IS TERRIBLE ... USE OBISDIAN AND FIX THJIS SHIT USE MODELS WE HAVE", then picked "the best models": our
-- ForgeGUI models, the arena gateways as party pads, the cabins like the camp's, the eight lands' landmarks round it).
-- Built only from the game's own finished models: the ForgeGUI buildings and landmarks (shared/ForgeModelIds) and the
-- voxel trees, bushes and rocks (ServerStorage.VoxelModels). Composition from the LihFolk vault (Level Design for
-- Roblox: "courtyard + gates" for a game whose main action is picking where to go, spawn facing the main thing, every
-- station visible or signposted from it; World Composition: one hero, framed, tallest; dense at the edges, clear in the
-- middle; Zone and Biome Art Direction: each land's landmark visible as the pull forward).
--
--   * You spawn at the south end of a paved courtyard, looking north at a wall of five arena gateways, one per land:
--     walk into a gateway's arch to start (SOLO in the middle, PARTY either side, the gold-wheat one is CONTINUE).
--   * Over the gates rises the hero: the giant ForgeGUI windmill.
--   * Round the courtyard, beyond a low hedge, the lands themselves: each land's ForgeGUI landmark on a patch of its
--     own ground with its own trees and rocks (wheat, blossom, pine, swamp, frost, ember; Starlight's observatory
--     behind you), a forest belt behind them all.
--   * On the courtyard's sides: CLASSES (a ForgeGUI cottage, the aura mannequin in front), the GARAGE (the camp's
--     ForgeGUI garage, the mower on its turntable inside), FREE REWARDS a few steps left of the spawn, GRASS CUT and
--     BEST TIMES at the courtyard's south corners.
-- Lobby space: y = 0 the ground, +Z north, +X to your left as you look north from the spawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)
local VM = require(script.Parent.VoxelModels)
local Environment = require(script.Parent.Environment)
local LobbyKit = require(script.Parent.LobbyKit)
local LobbyPads = require(script.Parent.LobbyPads)
local Layout = require(script.Parent.LobbyLayout)

local LandsBuilder = {}
LandsBuilder.ON = true

local C = Color3.fromRGB
local SPAWN = Vector3.new(0, 0, -64)
local COURT = { x0 = -64, x1 = 64, z0 = -96, z1 = -22 }
local GATE_Z = -27 -- the gates' middles
local GATE_W = 23
local GATES = { -- (x, the land, the pad's kind) left to right as you face them
	{ x = 50, land = "wheat", kind = "continue" },
	{ x = 25, land = "blossom", kind = "party" },
	{ x = 0, land = "meadow", kind = "solo" },
	{ x = -25, land = "pine", kind = "party" },
	{ x = -50, land = "swamp", kind = "party" },
}
-- (measured on the gate meshes: the arch's opening as a share of the width, server/ArenaForge)
local OPEN = { meadow = 0.36, wheat = 0.43, blossom = 0.37, pine = 0.29, swamp = 0.29 }
local HERO = { pos = Vector3.new(0, 0, 42), height = 112 }
local RING_CENTRE = Vector3.new(0, 0, -44)
local LANDS = { -- (angle from north, + to the left; the starlight observatory behind the spawn)
	{ id = "wheat", lm = "lm_wheat", a = 30, r = 120 },
	{ id = "blossom", lm = "lm_blossom", a = -30, r = 120 },
	{ id = "pine", lm = "lm_pine", a = 62, r = 124 },
	{ id = "swamp", lm = "lm_swamp", a = -62, r = 124 },
	{ id = "frost", lm = "lm_frost", a = 96, r = 116 },
	{ id = "ember", lm = "lm_ember", a = -96, r = 116 },
	{ id = "isles", lm = "lm_starlight", a = 180, r = 112 },
}
local PATCH_R = 30
local REACH = 232 -- the island's half size
local CELL = 8
local SEA = -6
local FLOOR = -24

local CLASSES = Vector3.new(-48, 0, -58)
local GARAGE = Vector3.new(49, 0, -60)
Layout.SPAWN = SPAWN
Layout.REWARDS = { pos = Vector3.new(19, 0, -81) }
Layout.GRASS_CUT = { pos = Vector3.new(44, 0, -88) }
Layout.BEST_TIMES = { pos = Vector3.new(-44, 0, -88) }

local OPEN_C = C(80, 255, 95)
local BUSY_C = C(40, 210, 255)
local SAVE_C = C(255, 196, 46)

local count = 0
local function tick()
	count += 1
	if count % 300 == 0 then
		task.wait()
	end
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	tick()
	return p
end

local function invisible(p: BasePart)
	p.Transparency = 1
	p.CastShadow = false
	p.CanQuery = false
	p.CanTouch = false
end

local function facing(pos: Vector3, toward: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
end

local function zone(id: string): any
	for _, z in Zones.list do
		if z.id == id then
			return z
		end
	end
	return Zones.list[1]
end

local function landPos(l: any): Vector3
	local a = math.rad(l.a)
	return RING_CENTRE + Vector3.new(math.sin(a) * l.r, 0, math.cos(a) * l.r)
end

local function hash(i: number, j: number, k: number): number
	local n = math.sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453
	return n - math.floor(n)
end

-------------------------------------------------------------------------------------------------------------
-- ground
-------------------------------------------------------------------------------------------------------------
-- The ground colour of the 8-stud square at (x, z): a land's own two greens (or golds, pinks, whites...) on its patch,
-- the meadow's elsewhere, checkered at random like the run's areas.
local function groundAt(x: number, z: number): Color3
	local p = Vector3.new(x, 0, z)
	for _, l in LANDS do
		if (p - landPos(l)).Magnitude < PATCH_R then
			local pal = zone(l.id).palette
			return if hash(x, z, 3) < 0.5 then pal.ground else pal.ground2
		end
	end
	local pal = zone("meadow").palette
	return if hash(x, z, 9) < 0.5 then pal.ground else pal.ground2
end

local function ground(world: Instance)
	local f = Instance.new("Folder")
	f.Name = "Ground"
	f.Parent = world
	local side = C(92, 64, 40)
	local n = math.ceil(REACH / CELL)
	for j = -n, n - 1 do
		local z = (j + 0.5) * CELL
		local runStart: number?, runC: Color3? = nil, nil
		local function flush(iEnd: number)
			if runStart == nil then
				return
			end
			local x0, x1 = runStart * CELL, iEnd * CELL
			local top = block(f, "Floor", Vector3.new(x1 - x0, 1.2, CELL), CFrame.new((x0 + x1) / 2, -0.6, z), runC :: Color3, Enum.Material.Grass)
			top.CastShadow = false
			block(f, "FloorSide", Vector3.new(x1 - x0, -1.2 - FLOOR, CELL), CFrame.new((x0 + x1) / 2, (-1.2 + FLOOR) / 2, z), side, Enum.Material.Ground)
			runStart = nil
		end
		for i = -n, n do
			local x = (i + 0.5) * CELL
			local wob = math.sin(x * 0.031 + 1.3) * 10 + math.cos(z * 0.027 + 0.4) * 10
			local land = i < n and math.max(math.abs(x), math.abs(z)) + wob < REACH - 8
			local c = if land then groundAt(x, z) else nil
			if runStart ~= nil and c ~= runC then
				flush(i)
			end
			if c and runStart == nil then
				runStart, runC = i, c
			end
		end
	end
	local sea = block(world, "Sea", Vector3.new(1400, 1, 1400), CFrame.new(0, SEA - 0.5, 0), C(40, 150, 220), Enum.Material.Glass)
	sea.Transparency = 0.25
	sea.CanCollide = false
	sea.CastShadow = false
	block(world, "SeaFloor", Vector3.new(1400, 2, 1400), CFrame.new(0, FLOOR - 1, 0), C(226, 200, 140))
end

-- The walks, in the camp's golden paving (server/HubPaths): a round plaza at the spawn, a walk fanning out to each
-- gate (leading lines: World Composition), an apron along the gate row, and walks to every station and out to the
-- lands. Between them the courtyard is lawn, with flower beds and lamps (dressing()).
local SPAWN_PLAZA = 13
local APRON_Z = GATE_Z - 7
local function walkSegments(): { any }
	local s0 = Vector2.new(SPAWN.X, SPAWN.Z)
	local segs = {}
	local function walk(a: Vector2, b: Vector2, w: number)
		table.insert(segs, { a = a, b = b, width = w })
	end
	for _, g in GATES do
		walk(s0, Vector2.new(g.x, APRON_Z), 7)
	end
	walk(Vector2.new(-58, APRON_Z), Vector2.new(58, APRON_Z), 9)
	walk(s0, Vector2.new(CLASSES.X + 14, CLASSES.Z), 7)
	walk(s0, Vector2.new(GARAGE.X - 13, GARAGE.Z), 7)
	walk(s0, Vector2.new(Layout.REWARDS.pos.X - 6, Layout.REWARDS.pos.Z), 6)
	for _, b in { Layout.GRASS_CUT.pos, Layout.BEST_TIMES.pos } do
		walk(s0, Vector2.new(b.X * 0.85, b.Z + 6), 6)
	end
	-- out to the lands, from the apron's ends or the spawn plaza, whichever is nearer
	local starts = { Vector2.new(-58, APRON_Z), Vector2.new(58, APRON_Z), s0 }
	for _, l in LANDS do
		local p = landPos(l)
		local to = Vector2.new(p.X, p.Z)
		local from = starts[1]
		for _, st in starts do
			if (st - to).Magnitude < (from - to).Magnitude then
				from = st
			end
		end
		local stop = to - (to - from).Unit * (PATCH_R - 6)
		walk(from, stop, 6)
	end
	return segs
end

local function paving(world: Instance)
	local HubPaths = require(script.Parent.HubPaths)
	HubPaths.pave(HubPaths.lay(world, walkSegments(), 0, 11, { { centre = Vector2.new(SPAWN.X, SPAWN.Z), radius = SPAWN_PLAZA } }), Vector3.zero)
end

-------------------------------------------------------------------------------------------------------------
-- the gates (the party pads)
-------------------------------------------------------------------------------------------------------------
local TURN = CFrame.Angles(0, math.pi / 2, 0) -- (the 30 Oct ForgeGUI meshes face their -Z: server/ArenaForge)

local function gateSign(parent: Instance, at: Vector3, title: string, base: Color3): (TextLabel, TextLabel, Frame)
	local holder = PropKit.part({ size = Vector3.one, cf = CFrame.new(at), color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = "PadStatus" })
	holder.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(13, 6.4)
	gui.LightInfluence = 0
	gui.MaxDistance = 170
	gui.Parent = holder
	local function label(par: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, stroke: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = size
		l.Position = pos
		l.Font = Config.UI.font
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = stroke
		s.Color = C(58, 34, 18)
		s.Parent = l
		l.Parent = par
		return l
	end
	label(gui, title, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0), PropKit.TITLE, 4)
	local box = Instance.new("Frame")
	box.BorderSizePixel = 0
	box.Size = UDim2.fromScale(0.62, 0.24)
	box.Position = UDim2.fromScale(0.19, 0.44)
	box.BackgroundColor3 = base
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0.5, 0)
	cr.Parent = box
	local bs = Instance.new("UIStroke")
	bs.Thickness = 2.5
	bs.Color = C(30, 60, 40)
	bs.Parent = box
	box.Parent = gui
	local pill = label(box, "OPEN", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1), Color3.new(1, 1, 1), 2)
	local status = label(gui, "", UDim2.fromScale(1, 0.26), UDim2.fromScale(0, 0.72), C(255, 240, 205), 2.5)
	return status, pill, box
end

-- The pad on the ground in the arch: a dark stone ring round a disc in the state's colour (a ring of blocks: no
-- smooth cylinders in the voxel world).
local function padDisc(parent: Instance, cf: CFrame, r: number, color: Color3): { BasePart }
	local inlay: { BasePart } = {}
	local g = 1
	local n = math.ceil(r / g)
	for j = -n, n - 1 do
		local zc = (j + 0.5) * g
		if math.abs(zc) < r then
			local hw = math.floor(math.sqrt(r * r - zc * zc) / g + 0.5) * g
			if hw > 0 then
				local rim = block(parent, "PadRim", Vector3.new(hw * 2, 0.5, g), cf * CFrame.new(0, 0.25, zc), C(70, 66, 74))
				rim.TopSurface = Enum.SurfaceType.Studs
				rim.Material = Enum.Material.Plastic
				local iw = hw * 2 - 2
				local ri = r - 1
				if math.abs(zc) < ri and iw > 0.5 then
					local hi = math.floor(math.sqrt(ri * ri - zc * zc) / g + 0.5) * g
					if hi > 0 then
						local p = block(parent, "PadGlow", Vector3.new(hi * 2, 0.12, g), cf * CFrame.new(0, 0.56, zc), color)
						p.CanCollide = false
						p.CastShadow = false
						table.insert(inlay, p)
					end
				end
			end
		end
	end
	return inlay
end

local function gate(world: Instance, m: Instance, i: number, g: any): any
	local pos = Vector3.new(g.x, 0, GATE_Z)
	local cf = facing(pos, Vector3.new(g.x, 0, SPAWN.Z)) -- (its front toward the courtyard)
	local model = Models.placeForge("fa_gate_" .. g.land, m, cf * TURN, { depth = GATE_W }, true)
	local openHalf = GATE_W * (OPEN[g.land] or 0.33) / 2
	local height = 14
	if model then
		model.Name = "Gate_" .. g.land
		local body = model:FindFirstChildWhichIsA("MeshPart", true)
		if body then
			height = body.Size.Y
		end
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = false
				p.CanTouch = false
			end
		end
		-- its towers are solid; the way in is the arch
		local towerW = GATE_W / 2 - openHalf
		for _, side in { -1, 1 } do
			local col = block(m, "TowerCollider", Vector3.new(towerW, 26, 8), cf * CFrame.new(side * (openHalf + towerW / 2), 13, 0), Color3.new(1, 1, 1))
			invisible(col)
		end
	end
	local kind = g.kind
	local base = if kind == "continue" then SAVE_C else OPEN_C
	local r = math.min(openHalf - 0.4, 4.6)
	local padAt = cf * CFrame.new(0, 0, -1)
	local inlay = padDisc(m, padAt, r, base)
	local marker = PropKit.part({ size = Vector3.one, cf = padAt * CFrame.new(0, 1.6, 0), color = base, parent = m, transparency = 1, collide = false, name = "PadInfo" .. i })
	marker.CanQuery = false
	local title = if kind == "solo" then "SOLO" elseif kind == "continue" then "CONTINUE" else "PARTY"
	local status, pill, box = gateSign(m, (cf * CFrame.new(0, height + 4.2, -1)).Position, title, base)
	local maxN = if kind == "party" then Config.PARTY_MAX else 1
	local state = ""
	local def = {
		kind = kind,
		pos = (padAt * CFrame.new(0, 0.6, 0)).Position,
		radius = r - 0.3,
		label = status,
		title = title,
		show = function(newState: string, n: number, left: number?, who: string?, limit: number?)
			local capN = limit or maxN
			if newState == "open" then
				status.Text = if kind == "continue" then "Your saved run" elseif kind == "solo" then "Play alone" else ("%d/%d"):format(n, capN)
			elseif newState == "creating" then
				status.Text = (who or "Someone") .. " is setting up"
			elseif newState == "starting" then
				status.Text = if kind == "party" then ("%d/%d  -  %d"):format(n, capN, left or 0) else ("Starting in %d"):format(left or 0)
			else
				status.Text = "Teleporting..."
			end
			local p = LobbyPads.pillFor(kind, newState, n, capN, left)
			if p ~= pill.Text or newState ~= state then
				state = newState
				local c = if newState == "open" then base else BUSY_C
				for _, q in inlay do
					q.Color = c
				end
				box.BackgroundColor3 = c
				pill.Text = p
			end
		end,
	}
	def.show("open", 0, nil)
	-- a little sparkle rising in the arch
	LobbyKit.tag(LobbyKit.spot(m, padAt * CFrame.new(0, 2, 0), Vector3.new(r * 1.6, 3, r * 1.6), "PadFX"), "LobbyFX", { Kind = "sparkle", Color = base })
	local _ = world
	return def
end

local function gates(world: Instance): { any }
	local m = PropKit.folder("PartyBooths", world)
	-- pad 1 is SOLO (the guide arrow shows "PadInfo1" to new players), then the parties, CONTINUE last
	local order = {}
	for _, kind in { "solo", "party", "continue" } do
		for _, g in GATES do
			if g.kind == kind then
				table.insert(order, g)
			end
		end
	end
	local defs = {}
	for i, g in order do
		table.insert(defs, gate(world, m, i, g))
	end
	return defs
end

-------------------------------------------------------------------------------------------------------------
-- the hero and the lands
-------------------------------------------------------------------------------------------------------------
local function hero(world: Instance)
	local m = PropKit.folder("Landmark", world)
	local cf = facing(HERO.pos, SPAWN)
	local mill = Models.placeForge("windmill", m, cf, { height = HERO.height }, false)
	if not mill then
		VM.place(m, "Landmark_windmill", HERO.pos, { scale = 1.4, collide = true })
	end
end

local function tree(parent: Instance, land: string, foot: Vector3, scale: number, rng: Random)
	local name = "Tree_" .. land .. "_" .. rng:NextInteger(1, 3)
	if not VM.has(name) then
		name = "Tree_meadow_" .. rng:NextInteger(1, 3)
	end
	local s = scale * 0.75
	VM.place(parent, name, foot, { scale = s, yaw = rng:NextInteger(0, 3) * math.pi / 2 })
	VM.blocker(parent, Vector3.new(4.8 * s, 20 * s, 4.8 * s), CFrame.new(foot + Vector3.new(0, 10 * s, 0)))
end

-- A land on the ring: its landmark facing the courtyard, its trees round the back half, rocks and bushes in front.
local function land(parent: Instance, l: any, rng: Random)
	local f = Instance.new("Folder")
	f.Name = zone(l.id).name
	f.Parent = parent
	local at = landPos(l)
	local toward = RING_CENTRE
	Models.placeForge(l.lm, f, facing(at, toward), { height = 40, width = 44, depth = 44 }, false)
	local out = (at - toward).Unit
	local right = out:Cross(Vector3.yAxis)
	for k = 1, 6 do
		local a = (k - 3.5) / 2.5 * 1.25
		local p = at + out * (PATCH_R - 6) * math.cos(a) + right * (PATCH_R - 4) * math.sin(a)
		tree(f, l.id, p + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), rng:NextNumber(1.1, 1.5), rng)
	end
	for _, s in { -1, 1 } do
		local p = at - out * (PATCH_R - 8) + right * s * 16
		VM.place(f, "Rock_" .. l.id .. "_big", p, { scale = rng:NextNumber(1.2, 1.6), yaw = rng:NextNumber(0, math.pi * 2), collide = true })
		VM.place(f, "Bush_" .. l.id, p + right * s * 6 + out * 3, { scale = 0.9, yaw = rng:NextNumber(0, math.pi * 2), collide = true })
		VM.place(f, "Rock_" .. l.id, at - out * (PATCH_R - 4) + right * s * 7, { scale = 1.2, yaw = rng:NextNumber(0, math.pi * 2) })
	end
end

local function lands(world: Instance)
	local f = PropKit.folder("Lands", world)
	local rng = Random.new(77)
	for _, l in LANDS do
		land(f, l, rng)
		task.wait()
	end
	-- the forest belt round everything, and a few meadow trees between the lands (none near the courtyard, the gates'
	-- backs or a land's patch)
	local forest = PropKit.folder("Forest", world)
	for x = -REACH, REACH, 20 do
		for z = -REACH, REACH, 20 do
			local p = Vector3.new(x + rng:NextNumber(-4, 4), 0, z + rng:NextNumber(-4, 4))
			local d = (p - RING_CENTRE).Magnitude
			local edge = math.max(math.abs(p.X), math.abs(p.Z))
			local nearLand = false
			for _, l in LANDS do
				if (p - landPos(l)).Magnitude < PATCH_R + 10 then
					nearLand = true
				end
			end
			local nearHero = (p - HERO.pos).Magnitude < 40
			if not nearLand and not nearHero and edge < REACH - 22 then
				if d > 160 then
					tree(forest, if rng:NextNumber() < 0.45 then "pine" else "meadow", p, rng:NextNumber(1.3, 1.8), rng)
				elseif d > 92 and rng:NextNumber() < 0.35 then
					tree(forest, "meadow", p, rng:NextNumber(1.0, 1.3), rng)
				end
			end
		end
		task.wait()
	end
end

-- A low hedge of bushes round the courtyard (gaps for the walks), so it reads as a place, and the lands beyond it.
local function hedge(world: Instance)
	local f = PropKit.folder("Hedge", world)
	local rng = Random.new(12)
	local walks = walkSegments()
	local function onWalk(p: Vector3): boolean
		local q = Vector2.new(p.X, p.Z)
		for _, s in walks do
			local ab = s.b - s.a
			local t = math.clamp((q - s.a):Dot(ab) / math.max(ab:Dot(ab), 1e-3), 0, 1)
			if (q - (s.a + ab * t)).Magnitude < s.width / 2 + 3 then
				return true
			end
		end
		return false
	end
	local function row(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local n = math.floor(len / 7)
		for i = 0, n do
			local p = a + (b - a) * (i / math.max(n, 1))
			local gap = onWalk(p)
			if not gap then
				VM.place(f, "Bush_meadow", p, { scale = rng:NextNumber(0.85, 1.05), yaw = rng:NextInteger(0, 3) * math.pi / 2, collide = true })
			end
		end
	end
	local x0, x1, z0, z1 = COURT.x0 - 3, COURT.x1 + 3, COURT.z0 - 3, COURT.z1
	row(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0))
	row(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1 - 6))
	row(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1 - 6))
end

-------------------------------------------------------------------------------------------------------------
-- stations
-------------------------------------------------------------------------------------------------------------
local function promptAt(parent: Instance, cf: CFrame, name: string): BasePart
	local p = PropKit.part({ size = Vector3.new(2, 2, 2), cf = cf, color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = name })
	p.CanQuery = false
	return p
end

local function title(parent: Instance, at: Vector3, text: string, color: Color3)
	local p = promptAt(parent, CFrame.new(at), "Title")
	PropKit.billboard(p, text, color, Vector2.new(14, 3.4), Vector3.zero, 220)
end

local function classes(world: Instance): (TextLabel, Model?)
	local m = PropKit.folder("Classes", world)
	local at = facing(CLASSES, CLASSES + Vector3.xAxis) -- (its front looks east, across the courtyard)
	local house = Models.placeForge("house_blue", m, at, { width = 22, depth = 19, height = 24 }, true)
	if house then
		PropKit.solidForge(house)
	end
	title(m, (at * CFrame.new(0, 27, -6)).Position, "CLASSES", C(200, 160, 255))
	PropKit.prompt(promptAt(m, at * CFrame.new(0, 3, -13), "ClassPorch"), "Browse", "Classes", "Classes", 12)
	PropKit.prompt(promptAt(m, at * CFrame.new(0, 3, -9), "ClassCounter"), "Browse", "Classes", "Classes", 12)
	LobbyPads.space(m, at * CFrame.new(0, 0.02, -15), 14, 6)
	LobbyKit.tag(LobbyKit.spot(m, at * CFrame.new(0, 2, -15), Vector3.new(12, 3, 5), "ClassesFX"), "LobbyFX", { Kind = "sparkle", Color = C(200, 225, 255) })
	-- the mannequin south of the porch, turned to the spawn
	local dummy = require(script.Parent.AuraMannequin).build(m, facing((at * CFrame.new(-12, 0, -14)).Position, SPAWN))
	local hidden = Instance.new("TextLabel") -- (server/Lobby writes the stock here; the Classes window shows it)
	hidden.Name = "StockText"
	return hidden, dummy
end

local function garage(world: Instance)
	local m = PropKit.folder("Garage", world)
	local at = facing(GARAGE, GARAGE - Vector3.xAxis) -- (its open front looks west, across the courtyard)
	local shell = Models.placeForge("garage_shell", m, at * CFrame.new(0, -0.6, 2.92) * TURN, { depth = 23.5 }, true)
	if shell then
		for _, p in shell:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = false
				p.CanTouch = false
			end
		end
		-- its log walls are solid (the mesh has no collisions): back and sides, the front open
		for _, w in { { 0, 11, 10.6, 22, 1.2 }, { 10.6, 11, 1, 1.2, 20 }, { -10.6, 11, 1, 1.2, 20 } } do
			invisible(block(m, "Wall", Vector3.new(w[4], 22, w[5]), at * CFrame.new(w[1], w[2], w[3]), Color3.new(1, 1, 1)))
		end
	end
	title(m, (at * CFrame.new(0, 25, -4)).Position, "GARAGE", PropKit.TITLE)
	local spot = at * CFrame.new(0, 0, 0)
	if not Models.place("turntable", m, spot, 1) then
		block(m, "TurntableBase", Vector3.new(10, 0.6, 10), spot * CFrame.new(0, 0.3, 0), C(70, 70, 78), Enum.Material.DiamondPlate)
	end
	local floor = PropKit.cylinder(m, 5, 0.6, spot * CFrame.new(0, 0.3, 0), Color3.new(1, 1, 1))
	floor.Transparency = 1
	floor.CanCollide = false
	floor.Name = "Turntable"
	Models.place("mower_tractor", m, spot * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(200), 0), 1, true)
	PropKit.prompt(floor, "Open", "Garage", "Garage", 14) -- (one prompt: client/MowerLock hangs its padlock over it)
end

-- The courtyard's lawn between the walks: flower beds, benches facing the gates, lamp posts along the fan.
local function dressing(world: Instance)
	local f = PropKit.folder("Dressing", world)
	local function piece(name: string, pos: Vector3, toward: Vector3)
		local d = toward - pos
		VM.place(f, name, pos, { yaw = math.atan2(-d.X, -d.Z), collide = true })
	end
	-- (in the wedges between the fan's walks, halfway to the gates)
	for _, x in { -37, -12.5, 12.5, 37 } do
		piece("S_flower_bed", Vector3.new(x * 0.62, 0, -48), Vector3.new(0, 0, -48))
	end
	for _, sx in { -1, 1 } do
		piece("S_bench", Vector3.new(sx * 30, 0, -50), Vector3.new(sx * 30, 0, -20))
		piece("S_flower_bed", Vector3.new(sx * 54, 0, -42), Vector3.new(0, 0, -42))
	end
	-- lamp posts on the apron, between the gates
	for _, x in { -37.5, -12.5, 12.5, 37.5 } do
		local p = Vector3.new(x, 0, APRON_Z - 3)
		if not Models.place("lantern_post", f, CFrame.lookAt(p, p - Vector3.zAxis), 0.9, true) then
			VM.place(f, "S_lantern_post", p, { collide = true })
		end
	end
end

local function bounds(world: Instance)
	local e = REACH - 30
	for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local size = if s[1] ~= 0 then Vector3.new(2, 80, e * 2) else Vector3.new(e * 2, 80, 2)
		invisible(block(world, "Bound", size, CFrame.new(s[1] * e, 30, s[2] * e), Color3.new(1, 1, 1)))
	end
end

function LandsBuilder.build()
	local world = Environment.apply()
	workspace.Terrain:Clear()
	require(script.Parent.WorldGen).lighting()
	ground(world)
	paving(world)
	local pads = gates(world)
	hero(world)
	local stockLabel, dummy = classes(world)
	garage(world)
	local B = require(script.Parent.LobbyBuilder).stations
	B.rewards(world)
	local leaderLabel = B.leaderboard(world)
	local bestLabel = B.bestTimes(world)
	hedge(world)
	dressing(world)
	lands(world)
	bounds(world)
	local sp = SPAWN + Vector3.new(0, 0.8, 0)
	Environment.spawn(world, CFrame.lookAt(sp, sp + Vector3.zAxis)) -- looking north at the gates and the windmill
	LobbyKit.tag(LobbyKit.spot(world, CFrame.new(0, 10, -55), Vector3.new(120, 14, 70), "Motes"), "LobbyFX", { Kind = "motes" })
	return { world = world, stockLabel = stockLabel, leaderLabel = leaderLabel, bestLabel = bestLabel, pads = pads, mannequin = dummy }
end

return LandsBuilder
