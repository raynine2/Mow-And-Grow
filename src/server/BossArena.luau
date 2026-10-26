-- Boss arenas (the owner's boss brief, 26 Oct): a fenced 140-stud pocket near the edge of every area, themed per
-- area, where that area's boss fights. Built at run start on the generated world (Config.BOSS_ARENAS):
--   * a flat floor at the highest ground under it (floating isles get a stone skirt down to the water), no grass
--     (RunWorld.patches skips the World attributes Arena<z> / ArenaRadius), trees and rocks inside cleared away
--   * a themed wall all round with invisible colliders, one entrance facing the area's middle with an arch, a
--     name sign and gate bars that close 10 s after the fight starts (BossArena.setGate)
--   * the summon pad between the boss's spot and the entrance (server/Boss reads who stands on it)
--   * mowers park outside: a player driving into the arena is put on foot and the mower goes back out
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local BossMoves = require(ReplicatedStorage.MowALawn.BossMoves)
local Net = require(script.Parent.Net)

local BossArena = {}

export type Arena = {
	z: number,
	centre: Vector3, -- the middle of the floor (on its top)
	radius: number,
	facing: Vector3, -- unit, from the middle towards the entrance
	bossSpot: CFrame, -- where the boss stands, looking at the entrance
	padPos: Vector3,
	entry: Vector3, -- just inside the entrance (downed players get up here)
	outside: Vector3, -- just outside the entrance (where mowers are parked)
	model: Model,
	pad: BasePart,
	bars: { { part: BasePart, open: CFrame, shut: CFrame } },
	closed: boolean,
}

local arenas: { [number]: Arena } = {}
local C = Color3.fromRGB

-- the look of each theme: floor, rim, and the wall builder below
local THEMES = {
	meadow = { floor = C(124, 196, 82), floorMat = Enum.Material.Grass, rim = C(150, 140, 120), accent = C(255, 228, 90) },
	hedge = { floor = C(132, 168, 84), floorMat = Enum.Material.Grass, rim = C(120, 98, 70), accent = C(232, 48, 42) },
	bunker = { floor = C(235, 215, 150), floorMat = Enum.Material.Sand, rim = C(96, 170, 70), accent = C(255, 225, 77) },
	cornfield = { floor = C(168, 122, 72), floorMat = Enum.Material.Ground, rim = C(140, 100, 60), accent = C(240, 200, 80) },
	sakura = { floor = C(196, 188, 176), floorMat = Enum.Material.Slate, rim = C(140, 136, 130), accent = C(255, 159, 205) },
	swamp = { floor = C(70, 96, 74), floorMat = Enum.Material.Mud, rim = C(60, 50, 40), accent = C(157, 255, 90) },
	pumpkin = { floor = C(150, 108, 62), floorMat = Enum.Material.Ground, rim = C(110, 80, 50), accent = C(255, 140, 40) },
	ruins = { floor = C(140, 134, 116), floorMat = Enum.Material.Cobblestone, rim = C(96, 110, 80), accent = C(63, 255, 208) },
}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, radius: number, height: number, top: Vector3, color: Color3, mat: Enum.Material): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(top - Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = mat,
	})
end

-------------------------------------------------------------------------------------------------------------
-- the wall: one themed piece per segment (angle a, at the rim), plus invisible colliders
-------------------------------------------------------------------------------------------------------------
local WALL: { [string]: (Instance, CFrame, number, any) -> () } = {}

-- `at`: on the rim at floor height, LookVector pointing into the arena; `w`: the segment's width
WALL.meadow = function(f, at, w, t)
	-- white picket fence + flower bushes
	part(f, { Name = "Rail", Size = Vector3.new(w, 0.6, 0.5), CFrame = at * CFrame.new(0, 3.2, 0), Color = C(250, 248, 240) })
	part(f, { Name = "Rail", Size = Vector3.new(w, 0.6, 0.5), CFrame = at * CFrame.new(0, 1.6, 0), Color = C(250, 248, 240) })
	for i = -1, 1 do
		part(f, { Name = "Picket", Size = Vector3.new(0.7, 4.6, 0.6), CFrame = at * CFrame.new(i * w / 3, 2.3, 0.1), Color = C(255, 255, 255) })
	end
	part(f, { Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.one * 4.5, CFrame = at * CFrame.new(0, 1.2, 3), Color = C(70, 160, 50), Material = Enum.Material.Grass })
	part(f, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = at * CFrame.new(0.8, 3.1, 2.4), Color = t.accent, Material = Enum.Material.Neon })
end
WALL.hedge = function(f, at, w, t)
	part(f, { Name = "Hedge", Size = Vector3.new(w + 0.4, 9, 5), CFrame = at * CFrame.new(0, 4.5, -1), Color = C(46, 120, 46), Material = Enum.Material.Grass })
	for i = -1, 1, 2 do
		part(f, { Name = "Rose", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = at * CFrame.new(i * w / 4, 5 + i, 1.6), Color = t.accent })
	end
end
WALL.bunker = function(f, at, w, t)
	part(f, { Name = "Dune", Shape = Enum.PartType.Cylinder, Size = Vector3.new(w + 1, 7, 7), CFrame = at * CFrame.new(0, 0.6, -1), Color = C(220, 196, 128), Material = Enum.Material.Sand })
	part(f, { Name = "Turf", Size = Vector3.new(w + 1, 1, 4), CFrame = at * CFrame.new(0, 3.6, -3), Color = C(96, 170, 70), Material = Enum.Material.Grass })
end
WALL.cornfield = function(f, at, w, t)
	for i = -1, 1 do
		local h = 11 + (i % 2) * 2
		part(f, { Name = "Stalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.1, 1.1), CFrame = at * CFrame.new(i * w / 3, h / 2, -1) * CFrame.Angles(0, 0, math.rad(90)), Color = C(150, 170, 60) })
		part(f, { Name = "Cob", Size = Vector3.new(1.4, 3, 1.4), CFrame = at * CFrame.new(i * w / 3 + 0.8, h * 0.62, -0.4) * CFrame.Angles(0, 0, math.rad(15)), Color = t.accent })
		part(f, { Name = "Leaf", Size = Vector3.new(4, 0.3, 1.2), CFrame = at * CFrame.new(i * w / 3, h * 0.45, -1) * CFrame.Angles(0, i, math.rad(25)), Color = C(110, 160, 50) })
	end
end
WALL.sakura = function(f, at, w, t)
	part(f, { Name = "Wall", Size = Vector3.new(w, 3, 2), CFrame = at * CFrame.new(0, 1.5, 0), Color = C(230, 220, 205), Material = Enum.Material.Slate })
	part(f, { Name = "Cap", Size = Vector3.new(w + 0.4, 0.8, 2.6), CFrame = at * CFrame.new(0, 3.4, 0), Color = C(120, 60, 60) })
	part(f, { Name = "Petals", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2, 3), CFrame = at * CFrame.new(w / 3, 4, -0.6), Color = t.accent })
end
WALL.swamp = function(f, at, w, t)
	for i = -1, 1 do
		local h = 6 + (i + 1) % 2 * 2.5
		part(f, { Name = "Stake", Size = Vector3.new(1.2, h, 1.2), CFrame = at * CFrame.new(i * w / 3, h / 2, 0) * CFrame.Angles(math.rad(i * 6), 0, math.rad(i * 4)), Color = C(70, 52, 36), Material = Enum.Material.Wood })
	end
	part(f, { Name = "Reeds", Size = Vector3.new(w * 0.6, 5, 0.4), CFrame = at * CFrame.new(0, 2.5, 1.5), Color = C(90, 130, 70), Material = Enum.Material.Grass })
	part(f, { Name = "Moss", Size = Vector3.new(w, 0.8, 3), CFrame = at * CFrame.new(0, 0.4, 1), Color = C(80, 120, 60), Material = Enum.Material.Grass })
end
WALL.pumpkin = function(f, at, w, t)
	part(f, { Name = "Rail", Size = Vector3.new(w, 0.8, 0.6), CFrame = at * CFrame.new(0, 3.4, 0), Color = C(110, 74, 44), Material = Enum.Material.Wood })
	part(f, { Name = "Post", Size = Vector3.new(1, 5, 1), CFrame = at * CFrame.new(-w / 2 + 0.5, 2.5, 0), Color = C(96, 64, 38), Material = Enum.Material.Wood })
	part(f, { Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 3, 3.6), CFrame = at * CFrame.new(w / 4, 1.5, 2.2), Color = t.accent })
	part(f, { Name = "Stem", Size = Vector3.new(0.4, 0.9, 0.4), CFrame = at * CFrame.new(w / 4, 3.3, 2.2), Color = C(80, 110, 40) })
end
WALL.ruins = function(f, at, w, t)
	part(f, { Name = "Block", Size = Vector3.new(w, 4 + (w % 3), 3), CFrame = at * CFrame.new(0, 2, 0), Color = C(130, 128, 110), Material = Enum.Material.Cobblestone })
	part(f, { Name = "Moss", Size = Vector3.new(w * 0.7, 0.6, 3.2), CFrame = at * CFrame.new(-1, 4.3, 0), Color = C(70, 130, 60), Material = Enum.Material.Grass })
	part(f, { Name = "Rune", Size = Vector3.new(1.6, 1.6, 0.2), CFrame = at * CFrame.new(0, 2.2, 1.55), Color = t.accent, Material = Enum.Material.Neon })
end

-------------------------------------------------------------------------------------------------------------
-- building
-------------------------------------------------------------------------------------------------------------
local function groundRay(world: Instance): RaycastParams
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { world:FindFirstChild("Ground") :: Instance }
	return rp
end

-- highest and lowest ground under the disc
local function heights(c: Vector2, r: number, rp: RaycastParams): (number, number)
	local hi, lo = -math.huge, math.huge
	for i = -7, 7 do
		for j = -7, 7 do
			local x, z = i * r / 7, j * r / 7
			if x * x + z * z <= r * r then
				local hit = workspace:Raycast(Vector3.new(c.X + x, 400, c.Y + z), Vector3.new(0, -800, 0), rp)
				if hit then
					hi = math.max(hi, hit.Position.Y)
					lo = math.min(lo, hit.Position.Y)
				end
			end
		end
	end
	if hi == -math.huge then
		hi, lo = 0, -10
	end
	return hi, lo
end

-- trees, rocks, bushes and props standing where the arena goes are taken away (the world is a fresh copy). Every
-- piece whose footprint reaches inside the wall goes, so no tree pokes through the fence or the floor (owner, 26 Oct:
-- "some bosses spawn inside trees"). The scenery parts have CanQuery off, so this walks the folders instead of
-- asking the physics engine (GetPartBoundsInBox never saw them).
local function clearSpace(world: Instance, c: Vector3, r: number)
	local keep = { Ground = true, Gates = true, Patches = true, Bounds = true, Hub = true, Arenas = true, Grass = true, Hazards = true, Liquid = true, Pads = true }
	for _, f in world:GetChildren() do
		if not f:IsA("Folder") or keep[f.Name] then
			continue
		end
		for _, d in f:GetDescendants() do
			if not d:IsA("BasePart") or not d.Parent or d:GetAttribute("Sell") then
				continue
			end
			local foot = math.max(d.Size.X, d.Size.Z) / 2
			local dist = Vector2.new(d.Position.X - c.X, d.Position.Z - c.Z).Magnitude
			if dist - foot < r + 4 and d.Position.Y + d.Size.Y / 2 > c.Y - 12 then
				local node: Instance = d
				local m = d:FindFirstAncestorWhichIsA("Model")
				if m and m ~= workspace and m:IsDescendantOf(world) then
					node = m
				end
				if node.Parent and not node:GetAttribute("MapUnit") then
					node:Destroy()
				end
			end
		end
	end
end

local function sign(parent: Instance, cf: CFrame, text: string, color: Color3)
	local board = part(parent, { Name = "Sign", Size = Vector3.new(22, 4, 0.8), CFrame = cf, Color = C(90, 62, 40), Material = Enum.Material.Wood })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 24
		g.Parent = board
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = text
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = C(40, 24, 12)
		s.Parent = l
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.04, 0)
		pad.PaddingRight = UDim.new(0.04, 0)
		pad.Parent = l
		l.Parent = g
	end
end

-- The floor sits on the highest ground under it, so on a slope the entrance can be a cliff (up to 14 studs): a
-- ramp runs from the gate down to the ground outside (about 25 degrees), and anything standing on it is cleared.
local function entranceRamp(world: Instance, model: Instance, gatePos: Vector3, facing: Vector3, width: number, theme: any)
	local rp = groundRay(world)
	local function groundAt(d: number): number?
		local p = gatePos + facing * d
		local hit = workspace:Raycast(Vector3.new(p.X, gatePos.Y + 60, p.Z), Vector3.new(0, -200, 0), rp)
		return if hit then hit.Position.Y else nil
	end
	local len = 6
	local drop = 0
	for _ = 1, 3 do
		local g = groundAt(len + 2)
		if not g then
			return
		end
		drop = gatePos.Y - g
		len = math.clamp(drop * 2.15, 6, 46)
	end
	if drop < 1.5 then
		return
	end
	local mid = gatePos + facing * (len / 2 + 1)
	clearSpace(world, Vector3.new(mid.X, gatePos.Y - drop, mid.Z), len / 2 + 2)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "EntranceRamp"
	ramp.Anchored = true
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	ramp.Size = Vector3.new(width, drop, len)
	-- a wedge is tall at its back (+Z) and flat at its front (-Z): the front points away from the arena
	ramp.CFrame = CFrame.lookAt(Vector3.new(mid.X, gatePos.Y - drop / 2, mid.Z), Vector3.new(mid.X, gatePos.Y - drop / 2, mid.Z) + facing)
	ramp.Color = theme.floor
	ramp.Material = theme.floorMat
	ramp.Parent = model
	for side = -1, 1, 2 do
		local rail = Instance.new("WedgePart")
		rail.Name = "RampEdge"
		rail.Anchored = true
		rail.Size = Vector3.new(1.2, drop + 1, len)
		rail.CFrame = ramp.CFrame * CFrame.new(side * (width / 2 + 0.6), 0.5, 0)
		rail.Color = theme.rim
		rail.Material = Enum.Material.Slate
		rail.Parent = model
	end
end

local function build(world: Instance, folder: Instance, z: number): Arena?
	local spot = Config.BOSS_ARENAS[z]
	local def = BossMoves.get(z)
	if not spot or not def then
		return nil
	end
	local theme = THEMES[def.arena] or THEMES.meadow
	local r = Config.BOSS_ARENA_RADIUS
	local c2 = Vector2.new(spot.x, spot.z)
	local hi, lo = heights(c2, r + 4, groundRay(world))
	local top = hi + 0.4
	local centre = Vector3.new(spot.x, top, spot.z)
	-- the entrance faces the area's middle
	local zone = Zones.list[z]
	local mid = if zone then Vector3.new(zone.center.X, top, zone.center.Y) else centre + Vector3.zAxis
	local facing = mid - centre
	facing = if facing.Magnitude > 1 then facing.Unit else Vector3.zAxis
	clearSpace(world, centre, r)

	local model = Instance.new("Model")
	model.Name = "Arena" .. z
	-- floor + rim + skirt down to the lowest ground (or the water, for the floating isles)
	cyl(model, "Rim", r + 3, 5, centre + Vector3.new(0, -0.3, 0), theme.rim, Enum.Material.Slate)
	local floor = cyl(model, "Floor", r, 5, centre, theme.floor, theme.floorMat)
	floor:SetAttribute("ArenaFloor", z)
	local depth = math.max(6, top - math.min(lo, Zones.SEA) + 4)
	cyl(model, "Skirt", r + 2, depth, centre + Vector3.new(0, -5, 0), theme.rim, Enum.Material.Rock)
	-- a faint ring marking the fight floor
	local ring = cyl(model, "Line", r - 6, 0.1, centre + Vector3.new(0, 0.06, 0), theme.accent, Enum.Material.SmoothPlastic)
	ring.Transparency = 0.82
	ring.CanCollide = false
	cyl(model, "LineCut", r - 7, 0.12, centre + Vector3.new(0, 0.07, 0), theme.floor, theme.floorMat).CanCollide = false

	-- the wall: segments all round except the entrance gap
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "Wall"
	wallFolder.Parent = model
	local segs = 30
	local segW = 2 * math.pi * r / segs
	local yaw0 = math.atan2(facing.X, facing.Z)
	local builder = WALL[def.arena] or WALL.meadow
	for i = 0, segs - 1 do
		local a = yaw0 + (i + 0.5) / segs * 2 * math.pi
		local gap = i == 0 or i == segs - 1 -- the two segments either side of the facing direction
		if not gap then
			local pos = centre + Vector3.new(math.sin(a), 0, math.cos(a)) * r
			local at = CFrame.lookAt(pos, Vector3.new(centre.X, pos.Y, centre.Z))
			builder(wallFolder, at, segW, theme)
			local col = part(wallFolder, { Name = "Collider", Size = Vector3.new(segW + 0.6, 26, 2), CFrame = at * CFrame.new(0, 13, -1.5), Transparency = 1 })
			col.CanQuery = false
		end
	end

	-- the entrance: arch, name sign, gate bars
	local gatePos = centre + facing * r
	local gateCf = CFrame.lookAt(gatePos, gatePos - facing) -- looks into the arena
	local gapW = segW * 2
	for s = -1, 1, 2 do
		part(model, { Name = "ArchPost", Size = Vector3.new(3, 16, 3), CFrame = gateCf * CFrame.new(s * (gapW / 2 + 1.2), 8, 0), Color = theme.rim, Material = Enum.Material.Slate })
		part(model, { Name = "ArchCap", Size = Vector3.new(4, 1.2, 4), CFrame = gateCf * CFrame.new(s * (gapW / 2 + 1.2), 16.6, 0), Color = theme.accent, Material = Enum.Material.Neon })
	end
	part(model, { Name = "ArchBeam", Size = Vector3.new(gapW + 6, 2, 3), CFrame = gateCf * CFrame.new(0, 15.5, 0), Color = theme.rim, Material = Enum.Material.Slate })
	sign(model, gateCf * CFrame.new(0, 12.4, 0.2), (Config.ZONES[z].boss.name or "BOSS"):upper(), theme.accent)
	entranceRamp(world, model, gatePos, facing, gapW + 4, theme)
	local bars = {}
	local nBars = 6
	for i = 1, nBars do
		local x = (i - 0.5) / nBars * gapW - gapW / 2
		local shut = gateCf * CFrame.new(x, 5.5, 0)
		local open = shut * CFrame.new(0, -11.6, 0)
		local bar = part(model, { Name = "GateBar", Size = Vector3.new(0.9, 11, 0.9), CFrame = open, Color = C(70, 60, 55), Material = Enum.Material.Metal, CanCollide = false })
		bar.Transparency = 1
		table.insert(bars, { part = bar, open = open, shut = shut })
	end
	do
		-- the bars have gaps a player fits through: an invisible wall across the gate while it's shut, so a knock
		-- back can't throw anyone out of the fight (26 Oct)
		local gw = part(model, { Name = "GateCollider", Size = Vector3.new(gapW + 2, 26, 2), CFrame = gateCf * CFrame.new(0, 13, -0.5), Transparency = 1, CanCollide = false })
		gw.CanQuery = false
	end

	-- the boss's spot (back of the arena, looking at the entrance) and the summon pad
	local bossPos = centre - facing * (r * 0.28)
	local bossSpot = CFrame.lookAt(bossPos, bossPos + facing)
	local padPos = centre + facing * (r * 0.42)
	local pad = cyl(model, "SummonPad", 6.5, 0.6, padPos + Vector3.new(0, 0.3, 0), theme.accent, Enum.Material.Neon)
	pad.CanCollide = false
	pad.Transparency = 0.55
	pad:SetAttribute("SummonPad", z)
	local padRing = cyl(model, "SummonRing", 7.5, 0.4, padPos + Vector3.new(0, 0.2, 0), C(60, 50, 40), Enum.Material.Slate)
	padRing.CanCollide = false
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadLabel"
	bb.Size = UDim2.fromOffset(260, 60)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.MaxDistance = 140
	bb.AlwaysOnTop = false
	bb.Parent = pad
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = C(255, 255, 255)
	label.Text = "MOW THE AREA TO WAKE THE BOSS"
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Parent = label
	label.Parent = bb

	model:SetAttribute("Zone", z)
	model:SetAttribute("Radius", r)
	model:SetAttribute("Centre", centre)
	model:SetAttribute("Facing", facing)
	model.Parent = folder
	world:SetAttribute("Arena" .. z, centre)
	world:SetAttribute("ArenaRadius", r)

	return {
		z = z,
		centre = centre,
		radius = r,
		facing = facing,
		bossSpot = bossSpot,
		padPos = padPos,
		entry = gatePos - facing * 8 + Vector3.new(0, 3, 0),
		outside = gatePos + facing * 14 + Vector3.new(0, 3, 0),
		model = model,
		pad = pad,
		bars = bars,
		gateWall = model:FindFirstChild("GateCollider"),
		closed = false,
	}
end

-- At run start, right after the world is built (before any grass is placed).
function BossArena.build(info)
	local world = info.world :: Instance
	local folder = world:FindFirstChild("Arenas") or Instance.new("Folder")
	folder.Name = "Arenas"
	folder.Parent = world
	for z = 1, #Config.ZONES do
		local ok, err = pcall(function()
			local a = build(world, folder, z)
			if a then
				arenas[z] = a
			end
		end)
		if not ok then
			warn("[BossArena] area " .. z .. ": " .. tostring(err))
		end
	end
	task.spawn(BossArena.mowerLoop)
end

function BossArena.get(z: number): Arena?
	return arenas[z]
end

-- Is `pos` on area z's arena floor (inside the wall)?
function BossArena.inside(z: number, pos: Vector3, margin: number?): boolean
	local a = arenas[z]
	if not a then
		return false
	end
	return Vector2.new(pos.X - a.centre.X, pos.Z - a.centre.Z).Magnitude <= a.radius + (margin or 0)
		and math.abs(pos.Y - a.centre.Y) < 40
end

-- Is `pos` within `margin` studs of any arena's wall (or inside one)?
function BossArena.near(pos: Vector3, margin: number): boolean
	for z in arenas do
		if BossArena.inside(z, pos, margin) then
			return true
		end
	end
	return false
end

function BossArena.playersInside(z: number): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and BossArena.inside(z, root.Position, -1) then
			table.insert(list, p)
		end
	end
	return list
end

-- Pull a player who is still out in the area into the arena (just inside the gate) before it shuts (owner, round
-- 2). A mower driver is put on foot first; the mower stays outside.
function BossArena.pullIn(z: number, p: Player)
	local a = arenas[z]
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not a or not char or not hum or hum.Health <= 0 then
		return
	end
	hum.Sit = false
	local spread = Vector3.new(math.random(-6, 6), 0, math.random(-3, 3))
	task.defer(function()
		if char.Parent then
			char:PivotTo(CFrame.lookAt(a.entry + spread, a.entry + spread - a.facing))
		end
	end)
	Net.notify(p, "The boss fight is starting: you've been pulled into the arena!", "yellow")
end

-- Close (true) or open the gate bars; they slide up out of / down into the floor.
function BossArena.setGate(z: number, closed: boolean)
	local a = arenas[z]
	if not a or a.closed == closed then
		return
	end
	a.closed = closed
	if a.gateWall then
		a.gateWall.CanCollide = closed
	end
	for i, b in a.bars do
		b.part.CanCollide = closed
		if closed then
			b.part.Transparency = 0
		end
		local tw = TweenService:Create(b.part, TweenInfo.new(0.5 + i * 0.05, Enum.EasingStyle.Back, if closed then Enum.EasingDirection.Out else Enum.EasingDirection.In), {
			CFrame = if closed then b.shut else b.open,
		})
		tw:Play()
		if not closed then
			tw.Completed:Once(function()
				if not a.closed then
					b.part.Transparency = 1
				end
			end)
		end
	end
end

-- The pad's look and words: "locked" (mow first), "ready" (stand here), "busy" (fighting), "done" (beaten).
function BossArena.setPad(z: number, mode: string, text: string?)
	local a = arenas[z]
	if not a then
		return
	end
	local theme = THEMES[BossMoves.get(z).arena] or THEMES.meadow
	local bb = a.pad:FindFirstChild("PadLabel")
	local label = bb and bb:FindFirstChild("Text") :: TextLabel?
	a.pad:SetAttribute("Mode", mode)
	if mode == "ready" then
		a.pad.Color = theme.accent
		a.pad.Transparency = 0.25
	else
		a.pad.Color = C(120, 120, 120)
		a.pad.Transparency = if mode == "busy" then 1 else 0.6
	end
	if label then
		label.Text = text
			or (if mode == "ready" then "STAND HERE TO FIGHT!" elseif mode == "done" then "BEATEN!" elseif mode == "busy" then "" else "MOW THE AREA TO WAKE THE BOSS")
	end
end

-- Mowers park outside: anyone driving onto an arena floor is put on foot and their mower goes back out.
function BossArena.mowerLoop()
	local Mowers = require(script.Parent.Mowers) :: any
	local warned: { [Player]: number } = {}
	while true do
		task.wait(0.4)
		for _, p in Players:GetPlayers() do
			local mower = Mowers.driving(p)
			local root = mower and mower.PrimaryPart
			if root then
				for z, a in arenas do
					if BossArena.inside(z, root.Position, 2) then
						local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
						if hum then
							hum.Sit = false
							hum.Jump = true
						end
						task.delay(0.1, function()
							if mower.Parent then
								mower:PivotTo(CFrame.lookAt(a.outside, a.outside + a.facing))
								root.AssemblyLinearVelocity = Vector3.zero
							end
						end)
						if (warned[p] or 0) + 4 < os.clock() then
							warned[p] = os.clock()
							Net.notify(p, "Mowers park outside the arena: fight on foot!", "yellow")
						end
						break
					end
				end
			end
		end
	end
end

return BossArena
