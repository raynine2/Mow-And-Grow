--!strict
-- THE LOBBY: THE WINDMILL SQUARE AND THE EIGHT LANDS (4 Nov; built from the game's own finished models after the owner
-- said of a lobby of blocks "U CALL THIS A MAIN LOBBY THIS IS TERRIBLE ... USE MODELS WE HAVE", then, of a row of five
-- different arena gateways: "i dont like the gates u used its veyr bad doesnt fit ... make the whole lobby better ...
-- dont make it rommelig en onzin").
-- Composition from the LihFolk vault (World Composition and Set Dressing; Level Design for Roblox):
--   * ONE hero: the ForgeGUI windmill at the north end, the tallest, brightest thing; the spawn faces it.
--   * The party pads are grouped in front of it on one arc ("world gates grouped on one terrace"), five copies of one
--     piece (the meadow's round ForgeGUI altar, sunk so its top is a dais) with one sign style, no mix of looks.
--   * ONE walk: from the spawn straight up the axis to the pads, a curved walk along their front, one cross walk to the
--     two stations; everything symmetric about the axis (made things align); lamps in pairs along the axis.
--   * Negative space: the square is a freshly mown lawn in stripes running toward the windmill (leading lines), nothing
--     standing on it but the lamps and two flower beds where the axis meets the arc.
--   * Stations at the square's sides, facing in: CLASSES (the ForgeGUI cottage, the aura mannequin by its porch) to
--     the right, the GARAGE (the camp's ForgeGUI garage, the mower inside) to the left, FREE REWARDS a few steps left of
--     the spawn, GRASS CUT and BEST TIMES either side of the windmill.
--   * Around it, kept back as scenery: each land's ForgeGUI landmark on a patch of its own ground with its voxel trees
--     (density at the edges), a forest belt round the island.
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
local SPAWN = Vector3.new(0, 0, -62)
local HERO = { pos = Vector3.new(0, 0, 16), height = 104, width = 76 } -- (its sails are most of its width)
local PAD_R = 40 -- the pads' arc round the windmill's middle
local PAD_W = 13 -- each dais across
local PADS = { -- (degrees from the axis, + to the left as you face the windmill)
	{ a = 0, kind = "solo" },
	{ a = 25, kind = "party" },
	{ a = -25, kind = "party" },
	{ a = -50, kind = "party" },
	{ a = 50, kind = "continue" },
}
local WALK_R = PAD_R + 11 -- the curved walk in front of the pads (clear of the daises)
local WALK_ARC = 64 -- it runs from -64 to 64 degrees, out to the two boards
local SQUARE_R = 78 -- the mown square round the axis
local SQUARE_C = Vector3.new(0, 0, -22)
local RING_CENTRE = Vector3.new(0, 0, -30)
local LANDS = { -- (angle from north, + to the left; the starlight observatory behind the spawn)
	{ id = "wheat", lm = "lm_wheat", a = 34, r = 98 },
	{ id = "blossom", lm = "lm_blossom", a = -34, r = 98 },
	{ id = "pine", lm = "lm_pine", a = 68, r = 102 },
	{ id = "swamp", lm = "lm_swamp", a = -68, r = 102 },
	{ id = "frost", lm = "lm_frost", a = 104, r = 100 },
	{ id = "ember", lm = "lm_ember", a = -104, r = 100 },
	{ id = "isles", lm = "lm_starlight", a = 180, r = 96 },
}
local PATCH_R = 30
local REACH = 200 -- the island's half size
local CELL = 8
local SEA = -6
local FLOOR = -24

local FOUNTAIN = Vector3.new(-26, 0, -62) -- (4 Nov) the fountain garden, right of the spawn (server/LobbyLife)
local CLASSES = Vector3.new(-50, 0, -40)
local GARAGE = Vector3.new(50, 0, -40)
local CROSS_Z = -40
Layout.SPAWN = SPAWN
Layout.REWARDS = { pos = Vector3.new(24, 0, -70) }
Layout.GRASS_CUT = { pos = Vector3.new(55, 0, -9) } -- (out to the sides: from the spawn they show between the pads and
Layout.BEST_TIMES = { pos = Vector3.new(-55, 0, -9) } -- the stations, not behind the pads' signs)

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

-- A point on a circle round the windmill, `a` degrees off the axis toward the spawn.
local function arc(a: number, r: number): Vector3
	local t = math.rad(a)
	return HERO.pos + Vector3.new(math.sin(t) * r, 0, -math.cos(t) * r)
end

local function hash(i: number, j: number, k: number): number
	local n = math.sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453
	return n - math.floor(n)
end

-------------------------------------------------------------------------------------------------------------
-- ground and walks
-------------------------------------------------------------------------------------------------------------
-- The ground colour of the 8-stud square at (x, z): the square a mown lawn (two greens in stripes two squares wide,
-- running toward the windmill), a land's own colours on its patch, the meadow's checker elsewhere.
local function groundAt(x: number, z: number): Color3
	local p = Vector3.new(x, 0, z)
	local meadow = zone("meadow").palette
	if (p - SQUARE_C).Magnitude < SQUARE_R then
		return if math.floor((x + 1000) / 16) % 2 == 0 then meadow.ground else meadow.ground2
	end
	for _, l in LANDS do
		if (p - landPos(l)).Magnitude < PATCH_R then
			local pal = zone(l.id).palette
			return if hash(x, z, 3) < 0.5 then pal.ground else pal.ground2
		end
	end
	return if hash(x, z, 9) < 0.5 then meadow.ground else meadow.ground2
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
	-- (4 Nov, owner picked "the edges": the grass ran out in a dirt cliff into the sea) a sandy beach in two steps all
	-- round, on the same wobbly edge
	local nb = math.ceil((REACH + 30) / CELL)
	for j = -nb, nb - 1 do
		local z = (j + 0.5) * CELL
		for i = -nb, nb - 1 do
			local x = (i + 0.5) * CELL
			local wob = math.sin(x * 0.031 + 1.3) * 10 + math.cos(z * 0.027 + 0.4) * 10
			local reach = math.max(math.abs(x), math.abs(z)) + wob
			local land = i < n and j < n and i >= -n and j >= -n and reach < REACH - 8
			if not land and reach < REACH + 16 then
				local btop = if reach < REACH + 4 then -1.4 else -3.6
				local sand = if reach < REACH + 4 then C(236, 214, 160) else C(222, 198, 146)
				local b = block(f, "Beach", Vector3.new(CELL, btop - FLOOR, CELL), CFrame.new(x, (btop + FLOOR) / 2, z), sand, Enum.Material.Sand)
				b.CastShadow = false
			end
		end
	end
	local sea = block(world, "Sea", Vector3.new(1400, 1, 1400), CFrame.new(0, SEA - 0.5, 0), C(40, 150, 220), Enum.Material.Glass)
	sea.Transparency = 0.25
	sea.CanCollide = false
	sea.CastShadow = false
	block(world, "SeaFloor", Vector3.new(1400, 2, 1400), CFrame.new(0, FLOOR - 1, 0), C(226, 200, 140))
end

-- The walks (server/LobbyPaving: bricks in running bond, curved rows on the curve, rings round a gold medallion at the
-- spawn, kerbs, a grout bed): the spawn's round plaza, the axis up to the pads, the curved walk in front of them out to
-- the two boards, the cross walk between the two stations' round forecourts, a short walk to the rewards stall. Listed
-- in the order they keep their stones where they meet.
local function walkAreas(): { any }
	local function v2(p: Vector3): Vector2
		return Vector2.new(p.X, p.Z)
	end
	return {
		{ kind = "disc", c = v2(SPAWN), r = 10, medallion = true },
		{ kind = "disc", c = Vector2.new(CLASSES.X + 16.5, CROSS_Z), r = 6.5 },
		{ kind = "disc", c = Vector2.new(GARAGE.X - 18, CROSS_Z), r = 6.5 },
		{ kind = "seg", a = v2(SPAWN), b = v2(arc(0, WALK_R)), w = 9 },
		{ kind = "arc", c = v2(HERO.pos), r = WALK_R, w = 7, a0 = -WALK_ARC, a1 = WALK_ARC },
		{ kind = "seg", a = Vector2.new(CLASSES.X + 16.5, CROSS_Z), b = Vector2.new(GARAGE.X - 18, CROSS_Z), w = 7 },
		-- the rewards stall's forecourt, its two bays on it (owner, on the bays' cyan frames on the grass with the walk
		-- running into them: "its not good and overlapping maybe change the blue stff"), and the walk to it
		{ kind = "seg", a = Vector2.new(Layout.REWARDS.pos.X - 13, Layout.REWARDS.pos.Z), b = Vector2.new(Layout.REWARDS.pos.X - 3.2, Layout.REWARDS.pos.Z), w = 18 },
		{ kind = "seg", a = Vector2.new(SPAWN.X + 5, SPAWN.Z - 3), b = Vector2.new(Layout.REWARDS.pos.X - 13, Layout.REWARDS.pos.Z + 2), w = 6 },
		-- (4 Nov) the fountain garden's round apron and the short walk to it, mirroring the rewards stall's
		{ kind = "disc", c = v2(FOUNTAIN), r = 9 },
		{ kind = "seg", a = Vector2.new(SPAWN.X - 9, SPAWN.Z), b = Vector2.new(FOUNTAIN.X + 8.5, FOUNTAIN.Z), w = 5 },
	}
end

local function walks(world: Instance)
	require(script.Parent.LobbyPaving).lay(world, walkAreas())
end

-------------------------------------------------------------------------------------------------------------
-- the pads
-------------------------------------------------------------------------------------------------------------
local TURN = CFrame.Angles(0, math.pi / 2, 0) -- (the 30 Oct ForgeGUI meshes face their -Z: server/ArenaForge)
local ALTAR_TOP = 0.95 -- (the meadow altar's flat top as a share of its height, measured: server/ArenaForge)

local function padSign(parent: Instance, at: Vector3, title: string, base: Color3): (TextLabel, TextLabel, Frame)
	local holder = PropKit.part({ size = Vector3.one, cf = CFrame.new(at), color = Color3.new(1, 1, 1), parent = parent, transparency = 1, collide = false, name = "PadStatus" })
	holder.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(9.5, 4.7)
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

-- A thin ring of light on the dais's top in the pad's state colour (blocks round a circle: no smooth cylinders).
local function glowRing(parent: Instance, cf: CFrame, r: number): { BasePart }
	local parts: { BasePart } = {}
	local n = 28
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local p = block(parent, "PadGlow", Vector3.new(2 * math.pi * r / n + 0.15, 0.1, 0.45), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r), OPEN_C, Enum.Material.Neon)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		table.insert(parts, p)
	end
	return parts
end

local function pad(m: Instance, i: number, p: any): any
	local pos = arc(p.a, PAD_R)
	local cf = facing(pos, SPAWN)
	local top = 0.6
	local altar = Models.placeForge("fa_altar_meadow", m, cf * TURN, { depth = PAD_W, width = PAD_W }, true)
	if altar then
		altar.Name = "PadDais"
		local body = altar:FindFirstChildWhichIsA("MeshPart", true)
		local h = if body then body.Size.Y else 2
		-- sunk so its flat top is a step over the lawn (a dais you step onto)
		local sink = math.max(0, h * ALTAR_TOP - 1.1)
		altar:PivotTo(altar:GetPivot() - Vector3.new(0, sink, 0))
		top = h * ALTAR_TOP - sink
		for _, q in altar:GetDescendants() do
			if q:IsA("BasePart") then
				q.CanQuery = false
				q.CanTouch = false
			end
		end
		-- a flat invisible top to stand on (the mesh has no collisions)
		local step = block(m, "PadStep", Vector3.new(PAD_W * 0.8, top, PAD_W * 0.8), cf * CFrame.new(0, top / 2, 0), Color3.new(1, 1, 1))
		invisible(step)
	end
	local kind = p.kind
	local base = if kind == "continue" then SAVE_C else OPEN_C
	local r = PAD_W * 0.36
	local ring = glowRing(m, cf * CFrame.new(0, top + 0.05, 0), r)
	for _, q in ring do
		q.Color = base
	end
	local marker = PropKit.part({ size = Vector3.one, cf = cf * CFrame.new(0, top + 1.6, 0), color = base, parent = m, transparency = 1, collide = false, name = "PadInfo" .. i })
	marker.CanQuery = false
	local title = if kind == "solo" then "SOLO" elseif kind == "continue" then "CONTINUE" else "PARTY"
	local status, pill, box = padSign(m, (cf * CFrame.new(0, top + 7.5, 0)).Position, title, base)
	local maxN = if kind == "party" then Config.PARTY_MAX else 1
	local state = ""
	local def = {
		kind = kind,
		pos = (cf * CFrame.new(0, top, 0)).Position,
		radius = r + 0.6,
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
			local text = LobbyPads.pillFor(kind, newState, n, capN, left)
			if text ~= pill.Text or newState ~= state then
				state = newState
				local c = if newState == "open" then base else BUSY_C
				for _, q in ring do
					q.Color = c
				end
				box.BackgroundColor3 = c
				pill.Text = text
			end
		end,
	}
	def.show("open", 0, nil)
	LobbyKit.tag(LobbyKit.spot(m, cf * CFrame.new(0, top + 1.5, 0), Vector3.new(r * 1.6, 2, r * 1.6), "PadFX"), "LobbyFX", { Kind = "sparkle", Color = base })
	return def
end

local function pads(world: Instance): { any }
	local m = PropKit.folder("PartyBooths", world)
	local defs = {}
	-- (pad 1 is SOLO: the guide arrow shows "PadInfo1" to new players)
	for i, p in PADS do
		table.insert(defs, pad(m, i, p))
	end
	return defs
end

-------------------------------------------------------------------------------------------------------------
-- the hero, the stations, the lands
-------------------------------------------------------------------------------------------------------------
-- (owner: "the windmill is bugged its seethrough") the ForgeGUI windmill's lower tower is an open timber frame: most
-- of its plaster panels are missing, so you saw the trees behind it. A plaster core fills the tower just inside its
-- timbers, up to the balcony, so it reads as the whitewashed tower the top half is. Thin drums, a little narrower each
-- stud up, follow the tower's taper. The sizes are measured on the mesh's own vertices (4 Nov, at HERO's size): the
-- tower's outer wall is 20-21 studs out at the bottom and 18-19 under the balcony, and the core stays about a stud
-- inside that everywhere. (Rays don't work for this: the mesh's collision shape is much fatter than what you see.)
local CORE_TAPER = { { 7, 19.4 }, { 15, 18.4 }, { 21, 17.6 }, { 29.5, 17.0 } } -- { height, radius }
local CORE_BASE = { 1, 7, 21 } -- inside the stone foundation

local function coreRadius(y: number): number
	for i = 1, #CORE_TAPER - 1 do
		local a, b = CORE_TAPER[i], CORE_TAPER[i + 1]
		if y <= b[1] then
			return a[2] + (b[2] - a[2]) * (y - a[1]) / (b[1] - a[1])
		end
	end
	return CORE_TAPER[#CORE_TAPER][2]
end

local function windmillCore(m: Instance)
	local core = Instance.new("Model")
	core.Name = "Core"
	local function drum(y0: number, y1: number, r: number)
		local cf = CFrame.new(HERO.pos + Vector3.new(0, (y0 + y1) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local p = block(core, "Core", Vector3.new(y1 - y0, r * 2, r * 2), cf, C(236, 228, 212), Enum.Material.Plaster)
		p.Shape = Enum.PartType.Cylinder
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	drum(CORE_BASE[1], CORE_BASE[2], CORE_BASE[3])
	local top = CORE_TAPER[#CORE_TAPER][1]
	local y0 = CORE_TAPER[1][1]
	while y0 < top do
		local y1 = math.min(y0 + 1, top)
		drum(y0, y1, coreRadius(y1)) -- the narrower end, so no drum's rim pokes through
		y0 = y1
	end
	core.Parent = m
end

local function hero(world: Instance)
	local m = PropKit.folder("Landmark", world)
	local cf = facing(HERO.pos, SPAWN)
	if not Models.placeForge("windmill", m, cf, { height = HERO.height, width = HERO.width, depth = HERO.width }, false) then
		VM.place(m, "Landmark_windmill", HERO.pos, { scale = 1.4, collide = true })
		return
	end
	windmillCore(m)
end

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
	local at = facing(CLASSES, CLASSES + Vector3.xAxis) -- (its front looks east, across the square)
	local house = Models.placeForge("house_blue", m, at, { width = 22, depth = 19, height = 24 }, true)
	if house then
		PropKit.solidForge(house)
	end
	title(m, (at * CFrame.new(0, 27, -6)).Position, "CLASSES", C(200, 160, 255))
	PropKit.prompt(promptAt(m, at * CFrame.new(0, 3, -13), "ClassPorch"), "Browse", "Classes", "Classes", 12)
	PropKit.prompt(promptAt(m, at * CFrame.new(0, 3, -9), "ClassCounter"), "Browse", "Classes", "Classes", 12)
	LobbyKit.tag(LobbyKit.spot(m, at * CFrame.new(0, 2, -13), Vector3.new(10, 3, 4), "ClassesFX"), "LobbyFX", { Kind = "sparkle", Color = C(200, 225, 255) })
	-- the mannequin beside the porch, turned to the spawn
	local dummy = require(script.Parent.AuraMannequin).build(m, facing((at * CFrame.new(-11, 0, -12)).Position, SPAWN))
	local hidden = Instance.new("TextLabel") -- (server/Lobby writes the stock here; the Classes window shows it)
	hidden.Name = "StockText"
	return hidden, dummy
end

local function garage(world: Instance)
	local m = PropKit.folder("Garage", world)
	local at = facing(GARAGE, GARAGE - Vector3.xAxis) -- (its open front looks west, across the square)
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
	if not Models.place("turntable", m, at, 1) then
		block(m, "TurntableBase", Vector3.new(10, 0.6, 10), at * CFrame.new(0, 0.3, 0), C(70, 70, 78), Enum.Material.DiamondPlate)
	end
	local floor = PropKit.cylinder(m, 5, 0.6, at * CFrame.new(0, 0.3, 0), Color3.new(1, 1, 1))
	floor.Transparency = 1
	floor.CanCollide = false
	floor.Name = "Turntable"
	Models.place("mower_tractor", m, at * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(200), 0), 1, true)
	PropKit.prompt(floor, "Open", "Garage", "Garage", 14) -- (one prompt: client/MowerLock hangs its padlock over it)
end

-- The square's few made things, all in pairs about the axis: lamp posts along the axis walk (clear of the cross walk),
-- two flower beds beside it.
local function dressing(world: Instance)
	local f = PropKit.folder("Dressing", world)
	for _, z in { -56, -49 } do
		for _, sx in { -1, 1 } do
			local p = Vector3.new(sx * 6.6, 0, z)
			if not Models.place("lantern_post", f, CFrame.lookAt(p, Vector3.new(0, 0, z)), 0.9, true) then
				VM.place(f, "S_lantern_post", p, { collide = true })
			end
		end
	end
	for _, sx in { -1, 1 } do
		local p = Vector3.new(sx * 14, 0, -52)
		VM.place(f, "S_flower_bed", p, { yaw = math.pi / 2, collide = true })
	end
	-- lamps along the curved walk's outer edge, between the pads, turned to the walk
	for _, a in { -37.5, -12.5, 12.5, 37.5 } do
		local p = arc(a, WALK_R + 5.6)
		if not Models.place("lantern_post", f, CFrame.lookAt(p, arc(a, WALK_R)), 0.9, true) then
			VM.place(f, "S_lantern_post", p, { collide = true })
		end
	end
end

-- A clipped hedge round the square's south half and sides (the windmill's side stays open), framing it: blocks with a
-- studded top, two greens, a gap toward each land beyond and none on a walk. (World Composition: made things align,
-- a clear edge so the open lawn inside reads as a place.)
local HEDGE_R = 72
local function hedge(world: Instance)
	local f = PropKit.folder("Hedge", world)
	local areas = walkAreas()
	local Paving = require(script.Parent.LobbyPaving)
	local gaps = { 0 } -- (the starlight observatory behind the spawn)
	for _, l in LANDS do
		table.insert(gaps, 180 - l.a)
	end
	local piece = 4.4
	local n = math.floor(2 * math.pi * HEDGE_R * (220 / 360) / piece)
	for i = 0, n - 1 do
		local t = -110 + (i + 0.5) * 220 / n
		local open = false
		for _, g in gaps do
			local d = ((t - g + 180) % 360) - 180
			if math.abs(d) < 5 then
				open = true
			end
		end
		local rad = math.rad(t)
		local p = RING_CENTRE + Vector3.new(math.sin(rad) * HEDGE_R, 0, -math.cos(rad) * HEDGE_R)
		if not open and not Paving.covers(areas, Vector2.new(p.X, p.Z), 3) then
			local cf = CFrame.lookAt(p, p + Vector3.new(math.cos(rad), 0, math.sin(rad)))
			local body = block(f, "Hedge", Vector3.new(2.6, 2.6, piece + 0.05), cf * CFrame.new(0, 1.3, 0), C(52, 120, 46), Enum.Material.Plastic)
			body.TopSurface = Enum.SurfaceType.Smooth
			local top = block(f, "HedgeTop", Vector3.new(2.6, 0.7, piece + 0.05), cf * CFrame.new(0, 2.95, 0), if i % 2 == 0 then C(86, 160, 62) else C(78, 150, 56), Enum.Material.Plastic)
			top.TopSurface = Enum.SurfaceType.Studs
		end
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

-- A land on the ring: its landmark facing the square, its trees round the back half. (No rocks: from the square the
-- big voxel rocks read as grey walls in front of the landmarks.)
local function land(parent: Instance, l: any, rng: Random)
	local f = Instance.new("Folder")
	f.Name = zone(l.id).name
	f.Parent = parent
	local at = landPos(l)
	Models.placeForge(l.lm, f, facing(at, RING_CENTRE), { height = 40, width = 44, depth = 44 }, false)
	local out = (at - RING_CENTRE).Unit
	local right = out:Cross(Vector3.yAxis)
	for k = 1, 5 do
		local a = (k - 3) / 2 * 1.2
		local p = at + out * (PATCH_R - 6) * math.cos(a) + right * (PATCH_R - 4) * math.sin(a)
		tree(f, l.id, p, rng:NextNumber(1.2, 1.5), rng)
	end
end

local function lands(world: Instance)
	local f = PropKit.folder("Lands", world)
	local rng = Random.new(77)
	for _, l in LANDS do
		land(f, l, rng)
		task.wait()
	end
	-- the forest belt round everything (nothing loose on the lawn between: negative space)
	local forest = PropKit.folder("Forest", world)
	for x = -REACH, REACH, 20 do
		for z = -REACH, REACH, 20 do
			local p = Vector3.new(x + rng:NextNumber(-4, 4), 0, z + rng:NextNumber(-4, 4))
			local d = (p - RING_CENTRE).Magnitude
			local edge = math.max(math.abs(p.X), math.abs(p.Z))
			local clear = (p - SQUARE_C).Magnitude < SQUARE_R + 12
			for _, l in LANDS do
				if (p - landPos(l)).Magnitude < PATCH_R + 10 then
					clear = true
				end
			end
			if not clear and edge < REACH - 22 then
				if d > 132 then
					tree(forest, if rng:NextNumber() < 0.45 then "pine" else "meadow", p, rng:NextNumber(1.3, 1.8), rng)
				end
			end
		end
		task.wait()
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
	walks(world)
	local padDefs = pads(world)
	hero(world)
	local stockLabel, dummy = classes(world)
	garage(world)
	local B = require(script.Parent.LobbyBuilder).stations
	B.rewards(world)
	-- the two walk-on bays in gold, inlaid in the forecourt's paving (they were raised cyan frames on the grass)
	local gold = C(255, 196, 46)
	for _, d in (world:FindFirstChild("FreeRewards") :: Instance):GetDescendants() do
		if d:IsA("Model") and d.Name == "PadFrame" then
			for _, s in d:GetChildren() do
				if s:IsA("BasePart") then
					s.Color = gold
					s.Material = Enum.Material.Plastic
					s.TopSurface = Enum.SurfaceType.Smooth
				end
			end
			if d:GetAttribute("Color") ~= nil then
				d:SetAttribute("Color", gold)
			end
		elseif d:IsA("BasePart") and d.Name == "RewardsFX" then
			d:SetAttribute("Color", gold)
		end
	end
	local leaderLabel = B.leaderboard(world)
	local bestLabel = B.bestTimes(world)
	dressing(world)
	hedge(world)
	lands(world)
	-- (4 Nov, owner: "main lobby needs a bit work done", picked more life and the edges) the fountain garden,
	-- villagers, each land's animals, butterflies, the far shores on the horizon (server/LobbyLife)
	local landsCtx = {}
	for _, l in LANDS do
		table.insert(landsCtx, { id = l.id, pos = landPos(l) })
	end
	require(script.Parent.LobbyLife).dress(world, {
		lands = landsCtx,
		centre = RING_CENTRE,
		arc = arc,
		walkR = WALK_R,
		walkArc = WALK_ARC,
		crossZ = CROSS_Z,
		crossX0 = CLASSES.X + 16.5,
		crossX1 = GARAGE.X - 18,
		spawn = SPAWN,
		fountain = FOUNTAIN,
		reach = REACH,
		sea = SEA,
	})
	bounds(world)
	local sp = SPAWN + Vector3.new(0, 0.8, 0)
	Environment.spawn(world, CFrame.lookAt(sp, sp + Vector3.zAxis)) -- looking north at the pads and the windmill
	LobbyKit.tag(LobbyKit.spot(world, CFrame.new(0, 10, -30), Vector3.new(110, 14, 70), "Motes"), "LobbyFX", { Kind = "motes" })
	return { world = world, stockLabel = stockLabel, leaderLabel = leaderLabel, bestLabel = bestLabel, pads = padDefs, mannequin = dummy }
end

return LandsBuilder
