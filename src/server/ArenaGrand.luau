-- ARENA GRAND (30 Oct, owner: "rework the boss arenas to make them more fitting for our game and more detailed / high
-- quality"; his picks: themed per area, keep the 140-stud floor open, stands with a gnome crowd and banners, a statue
-- of the boss with ruins, glitch cracks, lights, and a glowing glitch barrier instead of the gate bars, same timing).
-- Built round each arena right after server/BossArena makes it (floor, wall, gatehouse, pad), from blocks in the
-- area's colours like server/ArenaDress (no uploaded models, so it looks the same in every place it's opened in):
--   * STANDS on both sides, outside the wall: three tiers of seats rising behind it (the upper two show over the
--     wall from inside), a back rail, and a crowd of gnomes in coats and pointy hats facing the fight, some cheering
--     with little flags; banner poles along the back with the area's banners and the boss's crest
--   * the BOSS STATUE at the back, outside the wall: the boss itself (its ForgeGUI mesh) carved in stone on a big
--     plinth, two fire bowls in front, broken pillars, fallen drums and rubble round it
--   * four LIGHT TOWERS in the corners between the stands and the gate / statue: posts with a fire bowl on top
--   * GLITCH CRACKS: the grass-glitch breaking through, magenta and cyan fissures in the floor round the edge (flat,
--     nothing to trip on) with a few pixel cubes floating over them, more at the statue's foot
--   * the GLITCH BARRIER: the gate bars become glitch pillars and a shimmering field rises between them (server/
--     BossArena.setGate moves them, as it moved the bars)
-- Everything is decoration (no queries, no touches); the stands and plinth are solid so nobody walks through them.
-- Nothing goes where something else of the world is (camps, gates, sell pads, bridges, paths): those spots are
-- skipped. Trees and rocks under the stands are taken away, and no grass grows under them (World ArenaRadius).
-- Mobile: about 700 blocks per arena (half of them the crowd), 4 lights and 6 small fires; StreamingEnabled only
-- sends the near ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VoxelKit = require(script.Parent.VoxelKit)

local ArenaGrand = {}

-- (30 Oct evening, owner: "revamp every arena remove unneccery stuff also use forge gui"; picked: the stands and
-- crowd, the statue and ruins, the glitch cracks and pixels, the light towers all go) only the glitch barrier is
-- built now; server/ArenaForge dresses the arenas with ForgeGUI models. true brings the rest back.
ArenaGrand.EXTRAS = false

local C = Color3.fromRGB
local K = VoxelKit.C
local part, jitter = VoxelKit.part, VoxelKit.jitter

local GLITCH = { C(255, 64, 222), C(64, 236, 255) } -- the grass-glitch colours (as the black hole and the corruption)
local SKIN = C(255, 214, 178)
local BEARD = C(246, 244, 238)
local COATS = { C(70, 120, 210), C(220, 70, 60), C(70, 160, 80), C(240, 180, 60), C(150, 90, 200), C(60, 170, 170), C(230, 120, 40) }
local HATS = { C(220, 50, 46), C(60, 110, 220), C(250, 200, 50), C(160, 70, 200), C(50, 160, 70), C(240, 240, 240) }

local STAND_IN = 4.5 -- the first tier's inner edge, studs outside the wall line
local TIER_D = 3.8 -- each tier's depth
local TIER_TOPS = { 7, 10.5, 14, 17.5, 21 } -- each tier's seat height above the floor (the upper four show over the walls)
local SIDE = { { 62, 118 }, { 242, 298 } } -- the stands' arcs (degrees from the entrance)
local SEG_DEG = 8 -- one stand block per this many degrees
local OUT = STAND_IN + TIER_D * #TIER_TOPS + 2.5 -- how far past the wall it all reaches

export type Ctx = {
	z: number,
	world: Instance,
	model: Model,
	centre: Vector3, -- the floor top's centre
	r: number,
	facing: Vector3,
	look: any, -- server/ArenaDress.look(z)
	rig: string?, -- BossMoves' rig name (ReplicatedStorage.BossModels.<rig>.P00 is the statue)
	bossName: string,
	bars: { any }, -- server/BossArena's gate bars ({ part, open, shut }); the barrier joins them
	gateCf: CFrame, -- at the gate, looking into the arena
	gapW: number,
}

-------------------------------------------------------------------------------------------------------------
-- the area's materials
-------------------------------------------------------------------------------------------------------------
type Mat = { seat: Color3, seatLook: any, trim: Color3, stone: Color3, cloth: Color3, glow: Color3 }
local function matsFor(look: any): Mat
	local t = look and look.theme or {}
	local woody = t.kind == "garden" or t.kind == "boards" or t.kind == "palisade" or t.kind == "stakes"
	local stone = t.stone or C(200, 200, 194)
	return {
		seat = if woody then (t.wood or K.log) else stone,
		seatLook = if woody then "log" else "stone",
		trim = t.timber or K.timber,
		stone = stone,
		cloth = look and look.accent or C(220, 60, 60),
		glow = t.glow or K.lamp,
	}
end

-------------------------------------------------------------------------------------------------------------
-- what's already there: nothing is built on it
-------------------------------------------------------------------------------------------------------------
local KEEP_OUT_FOLDERS = { "Hub", "Gates", "Pads", "IsleBridges", "Ways", "Paths", "Mowers", "Liquid" }
local blocked: { [number]: boolean }? = nil
local CELL = 6
local function cellKey(x: number, z: number): number
	return (math.floor(x / CELL) + 20000) * 40000 + (math.floor(z / CELL) + 20000)
end

-- every spot something of the world's own stands on (a grid of 6-stud cells), made once per world
local function blockedCells(world: Instance): { [number]: boolean }
	if blocked then
		return blocked
	end
	local b: { [number]: boolean } = {}
	local function mark(p: BasePart)
		local hx, hz = p.Size.X / 2 + 1, p.Size.Z / 2 + 1
		local pos = p.Position
		local r = math.max(hx, hz)
		for x = pos.X - r, pos.X + r, CELL do
			for z = pos.Z - r, pos.Z + r, CELL do
				b[cellKey(x, z)] = true
			end
		end
		b[cellKey(pos.X + r, pos.Z + r)] = true
	end
	for _, f in world:GetChildren() do
		local keep = table.find(KEEP_OUT_FOLDERS, f.Name) ~= nil or f.Name:sub(1, 7) == "Outpost"
		if keep then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 and d.Size.Magnitude < 400 then
					mark(d)
				end
			end
		end
	end
	-- the camps' plazas (World attributes Hub<z> / HubR<z>)
	for z = 1, 12 do
		local hub = world:GetAttribute("Hub" .. z)
		local hr = world:GetAttribute("HubR" .. z)
		if typeof(hub) == "Vector3" then
			local rr = (if type(hr) == "number" then hr else 24) + 6
			for x = hub.X - rr, hub.X + rr, CELL do
				for z2 = hub.Z - rr, hub.Z + rr, CELL do
					if Vector2.new(x - hub.X, z2 - hub.Z).Magnitude <= rr then
						b[cellKey(x, z2)] = true
					end
				end
			end
		end
	end
	blocked = b
	return b
end

local function isBlocked(world: Instance, cf: CFrame, size: Vector3): boolean
	local b = blockedCells(world)
	for _, sx in { -0.5, 0, 0.5 } do
		for _, sz in { -0.5, 0, 0.5 } do
			local p = cf * Vector3.new(sx * size.X, 0, sz * size.Z)
			if b[cellKey(p.X, p.Z)] then
				return true
			end
		end
	end
	return false
end

-- trees, rocks and props (the World's Visuals) standing in a box go
local function clearBox(world: Instance, cf: CFrame, size: Vector3)
	local vis = world:FindFirstChild("Visuals")
	if not vis then
		return
	end
	local inv = cf:Inverse()
	for _, d in vis:GetDescendants() do
		if d:IsA("BasePart") and d.Parent then
			local lp = inv * d.Position
			local foot = math.max(d.Size.X, d.Size.Z) / 2
			if math.abs(lp.X) < size.X / 2 + foot and math.abs(lp.Z) < size.Z / 2 + foot and lp.Y > -size.Y / 2 - 30 then
				local node: Instance = d
				local m = d:FindFirstAncestorWhichIsA("Model")
				if m and m:IsDescendantOf(vis) then
					node = m
				end
				if node.Parent and not node:GetAttribute("MapUnit") then
					node:Destroy()
				end
			end
		end
	end
end

local groundParams: RaycastParams? = nil
local function groundY(world: Instance, x: number, z: number, fallback: number): number
	if not groundParams then
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { world:FindFirstChild("Ground") or world }
		groundParams = rp
	end
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), groundParams)
	return if hit then hit.Position.Y else fallback
end

-------------------------------------------------------------------------------------------------------------
-- geometry round the arena (angles in degrees from the entrance, turning like server/ArenaDress's rim)
-------------------------------------------------------------------------------------------------------------
local function dirAt(ctx: Ctx, deg: number): Vector3
	local yaw0 = math.atan2(ctx.facing.X, ctx.facing.Z)
	local a = yaw0 + math.rad(deg)
	return Vector3.new(math.sin(a), 0, math.cos(a))
end

-- a frame at angle `deg`, radius `rad`, floor height + `up`: -Z points at the arena's middle, X along the ring
local function frameAt(ctx: Ctx, deg: number, rad: number, up: number): CFrame
	local out = dirAt(ctx, deg)
	local pos = ctx.centre + out * rad + Vector3.new(0, up, 0)
	return CFrame.lookAt(pos, Vector3.new(ctx.centre.X, pos.Y, ctx.centre.Z))
end

-------------------------------------------------------------------------------------------------------------
-- a gnome in the crowd (~4.8 studs: they're watched from across a 140-stud floor; feet at `cf`, facing cf's look)
-------------------------------------------------------------------------------------------------------------
local function gnome(parent: Instance, cf: CFrame, rng: Random)
	local coat = COATS[rng:NextInteger(1, #COATS)]
	local hat = HATS[rng:NextInteger(1, #HATS)]
	local s = rng:NextNumber(0.9, 1.08) * 1.45
	local function b(name: string, off: Vector3, size: Vector3, col: Color3, mat: any?)
		return part(parent, name, cf * CFrame.new(off * s), size * s, col, mat or Enum.Material.SmoothPlastic)
	end
	b("Boots", Vector3.new(0, 0.25, 0), Vector3.new(1.1, 0.5, 0.9), C(70, 46, 32))
	b("Coat", Vector3.new(0, 1.05, 0), Vector3.new(1.25, 1.2, 1.0), coat)
	b("Face", Vector3.new(0, 1.95, -0.02), Vector3.new(0.9, 0.7, 0.8), SKIN)
	b("Beard", Vector3.new(0, 1.55, -0.38), Vector3.new(0.92, 0.75, 0.2), BEARD)
	b("Hat", Vector3.new(0, 2.55, 0), Vector3.new(1.0, 0.55, 1.0), hat)
	b("HatTip", Vector3.new(0, 3.0, 0.08), Vector3.new(0.55, 0.45, 0.55), hat)
	local cheer = rng:NextNumber() < 0.35
	if cheer then
		-- an arm up, a little flag in the area's colour on some
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		b("Arm", Vector3.new(side * 0.72, 2.1, 0), Vector3.new(0.3, 1.0, 0.3), coat)
		if rng:NextNumber() < 0.6 then
			b("FlagStick", Vector3.new(side * 0.72, 3.0, 0), Vector3.new(0.1, 1.2, 0.1), C(90, 64, 44))
			local fl = b("Flag", Vector3.new(side * 0.72 + side * 0.36, 3.3, 0), Vector3.new(0.7, 0.45, 0.06), (parent:GetAttribute("FlagColor") :: Color3?) or C(255, 255, 255))
			fl.CastShadow = false
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the stands
-------------------------------------------------------------------------------------------------------------
local function crestGui(p: BasePart, face: Enum.NormalId, text: string, col: Color3)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 1
	g.Parent = p
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.36)
	ring.Size = UDim2.fromScale(0.78, 0.78)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeXX
	ring.BackgroundColor3 = C(255, 248, 230)
	ring.Parent = g
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = col:Lerp(C(0, 0, 0), 0.45)
	st.Parent = ring
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = col:Lerp(C(0, 0, 0), 0.25)
	l.Parent = ring
end

local function stands(ctx: Ctx, parent: Instance, m: Mat, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Stands"
	folder:SetAttribute("FlagColor", m.cloth)
	folder.Parent = parent
	local crowd = Instance.new("Folder")
	crowd.Name = "Crowd"
	crowd:SetAttribute("FlagColor", m.cloth)
	crowd.Parent = folder
	local floorY = ctx.centre.Y
	local initial = string.upper(string.sub(ctx.bossName, 1, 1))
	for _, arc in SIDE do
		local d0, d1 = arc[1], arc[2]
		local n = math.floor((d1 - d0) / SEG_DEG + 0.5)
		local step = (d1 - d0) / n
		for i = 0, n - 1 do
			local deg = d0 + (i + 0.5) * step
			local half = math.rad(step / 2)
			-- the whole column (all tiers) at this angle: skipped if it would stand on something of the world's
			local rOut = ctx.r + OUT
			local colCf = frameAt(ctx, deg, ctx.r + STAND_IN + (OUT - STAND_IN) / 2, 0)
			local colSize = Vector3.new(2 * rOut * math.sin(half) + 1, 30, OUT - STAND_IN + 1)
			local out = dirAt(ctx, deg)
			local gpos = ctx.centre + out * (ctx.r + STAND_IN + TIER_D)
			local g = groundY(ctx.world, gpos.X, gpos.Z, floorY - 4)
			if g > floorY + 3 or isBlocked(ctx.world, colCf, colSize) then
				continue
			end
			clearBox(ctx.world, colCf, colSize)
			for k, top in TIER_TOPS do
				local ri = ctx.r + STAND_IN + (k - 1) * TIER_D
				local ro = ri + TIER_D
				local rc = (ri + ro) / 2
				local w = 2 * ro * math.sin(half) + 0.25
				local bottom = math.min(g, floorY) - 2
				local h = floorY + top - bottom
				local cf = frameAt(ctx, deg, rc, top - h / 2)
				part(folder, "Tier", cf, Vector3.new(w, h, TIER_D), jitter(rng, m.seat, 0.05), m.seatLook, true)
				-- the seat's front lip and a cushion strip in the area's colour
				part(folder, "Lip", frameAt(ctx, deg, ri + 0.12, top + 0.06), Vector3.new(w, 0.32, 0.36), jitter(rng, m.trim, 0.05))
				part(folder, "Cushion", frameAt(ctx, deg, rc + 0.4, top + 0.12), Vector3.new(w - 0.3, 0.2, 1.4), jitter(rng, m.cloth, 0.06), Enum.Material.Fabric)
				-- gnomes along the seat, facing the fight
				local arcLen = rc * math.rad(step)
				local count = math.max(1, math.floor(arcLen / 3.6))
				for j = 0, count - 1 do
					if k > 1 and rng:NextNumber() < 0.6 then -- (the first row is behind the wall)
						local dj = deg + ((j + 0.5) / count - 0.5) * step
						local feet = frameAt(ctx, dj, rc - 0.2, top + 0.22) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
						gnome(crowd, feet, rng)
					end
				end
			end
			-- the back rail, and a banner pole on every other column
			local rb = ctx.r + STAND_IN + TIER_D * #TIER_TOPS + 0.5
			local wb = 2 * rb * math.sin(half) + 0.3
			local railTop = TIER_TOPS[#TIER_TOPS] + 2.4
			part(folder, "BackWall", frameAt(ctx, deg, rb, (railTop - 1) / 2), Vector3.new(wb, railTop + 1, 0.9), jitter(rng, m.trim, 0.05), m.seatLook, true)
			part(folder, "RailCap", frameAt(ctx, deg, rb, railTop + 0.15), Vector3.new(wb + 0.2, 0.3, 1.2), jitter(rng, m.stone, 0.04), "stone")
			if i % 2 == 0 then
				local pole = frameAt(ctx, deg, rb + 0.9, 0)
				part(folder, "BannerPole", pole * CFrame.new(0, (railTop + 15) / 2, 0), Vector3.new(0.5, railTop + 15, 0.5), C(90, 66, 50), "log")
				part(folder, "BannerTop", pole * CFrame.new(0, railTop + 15.3, 0), Vector3.new(0.8, 0.6, 0.8), C(230, 190, 80), Enum.Material.Metal)
				part(folder, "BannerBar", pole * CFrame.new(0, railTop + 14.4, -0.4), Vector3.new(3.6, 0.3, 0.3), C(90, 66, 50), "log")
				local banner = part(folder, "Banner", pole * CFrame.new(0, railTop + 11.6, -0.45), Vector3.new(3.2, 5.4, 0.12), m.cloth, Enum.Material.Fabric)
				banner.CastShadow = false
				part(folder, "BannerTrim", pole * CFrame.new(0, railTop + 9.0, -0.45), Vector3.new(3.2, 0.45, 0.16), m.cloth:Lerp(C(0, 0, 0), 0.35), Enum.Material.Fabric)
				crestGui(banner, Enum.NormalId.Front, initial, m.cloth)
			end
			-- a striped canopy over the top rows, sloping down toward the fight
			local cTop = railTop + 6
			local post = frameAt(ctx, deg, rb, 0)
			part(folder, "CanopyPost", post * CFrame.new(-wb / 2 + 0.3, (railTop + cTop) / 2, 0), Vector3.new(0.45, cTop - railTop, 0.45), C(90, 66, 50), "log")
			local reach = TIER_D * 2.2
			local rise = 3.2
			local slope = math.atan2(rise, reach)
			local roofLen = math.sqrt(reach * reach + rise * rise)
			local roofCf = frameAt(ctx, deg, rb - reach / 2, cTop - rise / 2) * CFrame.Angles(-slope, 0, 0)
			local stripe = if i % 2 == 0 then m.cloth else C(250, 246, 236)
			local roof = part(folder, "Canopy", roofCf, Vector3.new(wb + 0.4, 0.25, roofLen + 0.4), stripe, Enum.Material.Fabric)
			roof.CastShadow = true
			part(folder, "CanopyEdge", frameAt(ctx, deg, rb - reach - 0.1, cTop - rise - 0.35), Vector3.new(wb + 0.4, 0.7, 0.2), stripe:Lerp(C(0, 0, 0), 0.2), Enum.Material.Fabric).CastShadow = false
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the boss statue, ruins round it
-------------------------------------------------------------------------------------------------------------
local function pillar(parent: Instance, base: CFrame, h: number, d: number, col: Color3, rng: Random, broken: boolean)
	local drums = math.max(2, math.floor(h / 2.6))
	local dh = h / drums
	for i = 0, drums - 1 do
		local last = i == drums - 1
		local tilt = if last and broken then CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)) else CFrame.new()
		local cf = base * CFrame.new(rng:NextNumber(-0.06, 0.06), dh * (i + 0.5), rng:NextNumber(-0.06, 0.06)) * tilt
		part(parent, "Drum", cf, Vector3.new(d, dh - 0.05, d), jitter(rng, col, 0.07), "stone", true)
	end
	part(parent, "PillarBase", base * CFrame.new(0, 0.3, 0), Vector3.new(d + 1, 0.6, d + 1), jitter(rng, col, 0.05), "stone", true)
	if not broken then
		part(parent, "PillarCap", base * CFrame.new(0, h + 0.4, 0), Vector3.new(d + 1, 0.8, d + 1), jitter(rng, col, 0.05), "stone", true)
	end
	-- moss on it
	for _ = 1, 2 do
		local y = rng:NextNumber(0.5, h * 0.7)
		part(parent, "Moss", base * CFrame.new(rng:NextNumber(-0.2, 0.2) * d, y, -d / 2 - 0.05), Vector3.new(d * 0.6, 0.8, 0.2), C(78, 132, 60), Enum.Material.Grass)
	end
end

local function statue(ctx: Ctx, parent: Instance, m: Mat, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Statue"
	folder.Parent = parent
	local floorY = ctx.centre.Y
	-- the back of the arena, or as near it as it fits
	local deg = 180
	for _, try in { 180, 162, 198, 145, 215 } do
		local cf = frameAt(ctx, try, ctx.r + 12, 0)
		if not isBlocked(ctx.world, cf, Vector3.new(26, 30, 20)) then
			deg = try
			break
		end
	end
	local rad = ctx.r + 12
	local base = frameAt(ctx, deg, rad, 0)
	clearBox(ctx.world, base, Vector3.new(30, 40, 24))
	local g = groundY(ctx.world, base.Position.X, base.Position.Z, floorY - 4)
	local bottom = math.min(g, floorY) - 2
	-- the plinth: a stepped stone block, its top a little above the wall's
	local pTop = 8
	part(folder, "PlinthFoot", base * CFrame.new(0, (bottom - floorY + 1.5) / 2, 0), Vector3.new(19, floorY + 1.5 - bottom, 16), jitter(rng, m.stone, 0.04), "stone", true)
	part(folder, "Plinth", base * CFrame.new(0, (1.5 + pTop) / 2, 0), Vector3.new(15, pTop - 1.5, 13), jitter(rng, m.stone, 0.04), "stone", true)
	part(folder, "PlinthCap", base * CFrame.new(0, pTop + 0.3, 0), Vector3.new(16, 0.6, 14), jitter(rng, m.stone:Lerp(C(255, 255, 255), 0.15), 0.03), "stone", true)
	local plaque = part(folder, "Plaque", base * CFrame.new(0, 4.8, -6.56), Vector3.new(10, 2.2, 0.2), C(186, 150, 70), Enum.Material.Metal)
	do
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.Parent = plaque
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.94, 0.86)
		l.Position = UDim2.fromScale(0.03, 0.07)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextColor3 = C(60, 40, 20)
		l.Text = ctx.bossName
		l.Parent = sg
	end
	-- the boss, in stone
	local models = ReplicatedStorage:FindFirstChild("BossModels")
	local src = ctx.rig and models and models:FindFirstChild(ctx.rig)
	local mesh = src and src:FindFirstChild("P00")
	if mesh and mesh:IsA("MeshPart") then
		local s = mesh:Clone()
		for _, ch in s:GetChildren() do
			ch:Destroy()
		end
		s.Name = "BossStatue"
		s.TextureID = ""
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.Material = Enum.Material.Slate
		s.Color = m.stone:Lerp(C(128, 128, 120), 0.45)
		local scale = 40 / math.max(mesh.Size.Y, 0.1)
		s.Size = mesh.Size * scale
		local feet = base * CFrame.new(0, pTop + 0.6, 0)
		-- (the rig looks along its own look vector: the statue faces the arena)
		s.CFrame = feet * CFrame.new(0, s.Size.Y / 2, 0)
		s.Parent = folder
	else
		-- no boss mesh: an obelisk
		part(folder, "Obelisk", base * CFrame.new(0, pTop + 8, 0), Vector3.new(4, 16, 4), jitter(rng, m.stone, 0.05), "stone", true)
	end
	-- fire bowls on the plinth's front corners
	for _, sx in { -1, 1 } do
		local bowl = part(folder, "FireBowl", base * CFrame.new(sx * 6.4, pTop + 1.0, -5.2), Vector3.new(1.8, 0.8, 1.8), K.iron, Enum.Material.Metal)
		part(folder, "BowlFoot", base * CFrame.new(sx * 6.4, pTop + 0.45, -5.2), Vector3.new(1.0, 0.5, 1.0), K.iron, Enum.Material.Metal)
		local coal = part(folder, "Coals", base * CFrame.new(sx * 6.4, pTop + 1.45, -5.2), Vector3.new(1.4, 0.2, 1.4), m.glow, Enum.Material.Neon)
		coal.CastShadow = false
		VoxelKit.fire(coal, m.glow, 1.1)
		local _ = bowl
	end
	-- broken pillars either side, drums lying about, rubble
	for _, side in { -1, 1 } do
		local pdeg = deg + side * 13
		local pb = frameAt(ctx, pdeg, rad - 1, 0)
		local pg = groundY(ctx.world, pb.Position.X, pb.Position.Z, floorY - 4)
		local foot = pb * CFrame.new(0, math.min(pg, floorY) - floorY, 0)
		part(folder, "PillarFoot", foot * CFrame.new(0, (floorY - math.min(pg, floorY)) / 2 - 1, 0), Vector3.new(4.6, floorY - math.min(pg, floorY) + 2, 4.6), jitter(rng, m.stone, 0.05), "stone", true)
		pillar(folder, pb, rng:NextNumber(13, 19), 3.6, m.stone, rng, true)
		local lying = frameAt(ctx, deg + side * 22, rad + 3, 1.3) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), math.rad(90))
		for i = 0, 2 do
			part(folder, "FallenDrum", lying * CFrame.new(0, (i - 1) * 2.7, 0) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0), Vector3.new(3, 2.6, 3), jitter(rng, m.stone, 0.08), "stone", true)
		end
		for _ = 1, 4 do
			local rb = frameAt(ctx, deg + side * rng:NextNumber(4, 26), rad + rng:NextNumber(-4, 6), 0.4) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4))
			local sz = rng:NextNumber(0.8, 1.8)
			part(folder, "Rubble", rb, Vector3.new(sz, sz * 0.7, sz * 1.1), jitter(rng, m.stone, 0.1), "stone")
		end
	end
	return deg
end

-------------------------------------------------------------------------------------------------------------
-- light towers
-------------------------------------------------------------------------------------------------------------
local function towers(ctx: Ctx, parent: Instance, m: Mat, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Lights"
	folder.Parent = parent
	local floorY = ctx.centre.Y
	for _, deg in { 36, 144, 216, 324 } do
		local base = frameAt(ctx, deg, ctx.r + 7, 0)
		if isBlocked(ctx.world, base, Vector3.new(5, 20, 5)) then
			continue
		end
		clearBox(ctx.world, base, Vector3.new(6, 30, 6))
		local g = groundY(ctx.world, base.Position.X, base.Position.Z, floorY - 4)
		local bottom = math.min(g, floorY) - 1.5
		local h = 18
		part(folder, "TowerFoot", base * CFrame.new(0, (bottom - floorY + 1) / 2, 0), Vector3.new(3.6, floorY + 1 - bottom, 3.6), jitter(rng, m.stone, 0.05), "stone", true)
		part(folder, "TowerPost", base * CFrame.new(0, 1 + h / 2, 0), Vector3.new(1.6, h, 1.6), jitter(rng, m.trim, 0.05), "log", true)
		for _, y in { 5, 11 } do
			part(folder, "PostBand", base * CFrame.new(0, y, 0), Vector3.new(1.9, 0.4, 1.9), K.iron, Enum.Material.Metal)
		end
		part(folder, "BowlFoot", base * CFrame.new(0, h + 1.4, 0), Vector3.new(2.2, 0.8, 2.2), K.iron, Enum.Material.Metal)
		part(folder, "Bowl", base * CFrame.new(0, h + 2.1, 0), Vector3.new(3.2, 0.9, 3.2), K.iron, Enum.Material.Metal)
		local coal = part(folder, "Coals", base * CFrame.new(0, h + 2.6, 0), Vector3.new(2.6, 0.25, 2.6), m.glow, Enum.Material.Neon)
		coal.CastShadow = false
		VoxelKit.fire(coal, m.glow, 1.6)
		-- (VoxelKit.fire's light reaches 16; the arena wants a little more)
		local l = coal:FindFirstChildOfClass("PointLight")
		if l then
			l.Range = 30
			l.Brightness = 1.2
		end
		-- a banner on the post, facing in
		local banner = part(folder, "TowerBanner", base * CFrame.new(0, h - 4, -0.9), Vector3.new(2.4, 6, 0.12), m.cloth, Enum.Material.Fabric)
		banner.CastShadow = false
		part(folder, "TowerBannerBar", base * CFrame.new(0, h - 0.9, -0.9), Vector3.new(2.8, 0.25, 0.25), K.iron, Enum.Material.Metal)
	end
end

-------------------------------------------------------------------------------------------------------------
-- glitch cracks
-------------------------------------------------------------------------------------------------------------
local function crack(parent: Instance, start: CFrame, rng: Random, n: number, col: Color3, ground: boolean)
	-- a zigzag of flat neon strips over a dark fissure, from `start` along its -Z
	local at = start
	local w = rng:NextNumber(0.42, 0.6)
	for i = 1, n do
		local len = rng:NextNumber(1.6, 3.2)
		at = at * CFrame.Angles(0, rng:NextNumber(-0.7, 0.7), 0)
		local mid = at * CFrame.new(0, 0, -len / 2)
		local dark = part(parent, "Fissure", mid * CFrame.new(0, 0.03, 0), Vector3.new(w + 0.3, 0.06, len + 0.2), C(28, 14, 36), Enum.Material.SmoothPlastic)
		dark.CastShadow = false
		local glow = part(parent, "Glitch", mid * CFrame.new(0, 0.07, 0), Vector3.new(w * 0.45, 0.05, len), col, Enum.Material.Neon)
		glow.CastShadow = false
		-- a branch now and then
		if i > 1 and rng:NextNumber() < 0.35 then
			local bl = rng:NextNumber(0.8, 1.8)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local bcf = at * CFrame.Angles(0, side * rng:NextNumber(0.6, 1.1), 0) * CFrame.new(0, 0, -bl / 2)
			part(parent, "Fissure", bcf * CFrame.new(0, 0.03, 0), Vector3.new(w * 0.7, 0.06, bl), C(28, 14, 36), Enum.Material.SmoothPlastic).CastShadow = false
			part(parent, "Glitch", bcf * CFrame.new(0, 0.07, 0), Vector3.new(w * 0.3, 0.05, bl), col, Enum.Material.Neon).CastShadow = false
		end
		at = at * CFrame.new(0, 0, -len)
		w *= 0.86
	end
	-- pixels floating over it
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(0.4, 0.95)
		local cube = part(parent, "Pixel", start * CFrame.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(1.2, 4.2), -rng:NextNumber(0.5, 4)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0), Vector3.new(s, s, s), col, Enum.Material.Neon)
		cube.Transparency = 0.15
		cube.CastShadow = false
	end
	local _ = ground
end

local function cracks(ctx: Ctx, parent: Instance, statueDeg: number, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Glitch"
	folder.Parent = parent
	-- round the inside of the wall (never at the entrance), running in from the wall a little way
	local n = 9
	for i = 0, n - 1 do
		local deg = 30 + (i + rng:NextNumber(0.15, 0.85)) * (300 / n)
		local start = frameAt(ctx, deg, ctx.r - rng:NextNumber(1.5, 3.5), 0) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
		crack(folder, start, rng, rng:NextInteger(3, 6), GLITCH[(i % 2) + 1], true)
	end
	-- at the statue's foot, outside the wall
	for _, side in { -1, 1 } do
		local start = frameAt(ctx, statueDeg + side * 6, ctx.r + 4, 0) * CFrame.Angles(0, math.pi + side * 0.8, 0)
		crack(folder, start, rng, 4, GLITCH[if side < 0 then 1 else 2], true)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the glitch barrier (the gate)
-------------------------------------------------------------------------------------------------------------
local function barrier(ctx: Ctx, parent: Instance)
	local bars = ctx.bars
	-- the bars become glitch pillars
	for i, b in bars do
		local p = b.part :: BasePart
		p.Material = Enum.Material.Neon
		p.Color = GLITCH[(i % 2) + 1]
		p.Size = Vector3.new(0.5, p.Size.Y, 0.5)
		p.CastShadow = false
		p.Name = "GlitchPillar"
	end
	-- a shimmering field between them (ForceField moves by itself, nothing to animate), and two thin scan lines
	local h = 11
	local shut = ctx.gateCf * CFrame.new(0, 5.5, -0.1)
	local open = shut * CFrame.new(0, -h - 0.6, 0)
	local veil = part(parent, "GlitchVeil", open, Vector3.new(ctx.gapW, h, 0.25), GLITCH[1], Enum.Material.ForceField)
	veil.Transparency = 1
	veil.CastShadow = false
	table.insert(bars, { part = veil, open = open, shut = shut })
	for k, y in { -2.5, 2.2 } do
		local s = shut * CFrame.new(0, y, -0.05)
		local o = s * CFrame.new(0, -h - 0.6, 0)
		local line = part(parent, "GlitchScan", o, Vector3.new(ctx.gapW, 0.18, 0.3), GLITCH[k], Enum.Material.Neon)
		line.Transparency = 1
		line.CastShadow = false
		table.insert(bars, { part = line, open = o, shut = s })
	end
end

-------------------------------------------------------------------------------------------------------------
function ArenaGrand.build(ctx: Ctx)
	local folder = Instance.new("Folder")
	folder.Name = "Grand"
	folder.Parent = ctx.model
	barrier(ctx, folder)
	if not ArenaGrand.EXTRAS then
		return
	end
	local m = matsFor(ctx.look)
	local rng = Random.new(ctx.z * 977 + 13)
	stands(ctx, folder, m, rng)
	local statueDeg = statue(ctx, folder, m, rng)
	towers(ctx, folder, m, rng)
	cracks(ctx, folder, statueDeg, rng)
	-- no grass under the stands (server/RunWorld keeps grass ArenaRadius + 6 away from every arena's middle)
	-- (deferred: server/BossArena sets the plain radius after this; the grass is placed long after both)
	local world, wide = ctx.world, ctx.r + OUT
	task.defer(function()
		world:SetAttribute("ArenaRadius", math.max(world:GetAttribute("ArenaRadius") or 0, wide))
	end)
end

-- (30 Oct evening) for server/ArenaForge's stands: what's already there, clearing scenery, the ground's height
ArenaGrand.isBlocked = isBlocked
ArenaGrand.clearBox = clearBox
ArenaGrand.groundY = groundY

-- The glitch in arena z's floor heals (fades) once its boss is beaten (server/BossArena.dropWall).
function ArenaGrand.heal(model: Instance)
	local grand = model:FindFirstChild("Grand")
	local g = grand and grand:FindFirstChild("Glitch")
	if not g then
		return
	end
	local TweenService = game:GetService("TweenService")
	for i, p in g:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Glitch" or p.Name == "Pixel") then
			TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4 + (i % 10) * 0.05), { Transparency = 1 }):Play()
		end
	end
end

return ArenaGrand
