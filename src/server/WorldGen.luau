-- Builds the world from shared/WorldPlan into Workspace.World: studded voxel terraces, rock rims, the sea and
-- gorges, stairs and bridges between zones, the gates, teleport pads, grass patches, the village and a block for
-- each landmark. This is the BLOCKOUT: right shapes and zone colours, no art yet.
--
-- Run it in Studio (edit mode, command bar):  require(game.ServerScriptService.MowALawn.WorldGen).build()
-- It replaces Workspace.World and the Terrain. Building again replaces your edits; back them up first.
--
-- What the game reads from the map (so moving these in Studio moves them in the game):
--   World.Gates.Gate<n>      Model, attributes Zone, Kind, Price. Children: Blocker parts (solid until bought),
--                            Walkway parts (bridges and stones: only solid once bought), Sign, Prompt
--   World.Pads.*             Part, attributes PadKind ("toZone" / "toVillage") and Zone
--   World.Patches.Zone<n>.*  invisible discs; grass grows inside them (attribute Zone)
--   World.Hazards.*          invisible; touching one sends you back to safety (gorges, the sea)
--   World.Village.Spots.*    where the village buildings go (Sell, Shop, Upgrades, Garage, Pets, Classes, ...)
--   World.Spawn              the SpawnLocation
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Zones = require(ReplicatedStorage.MowALawn.Zones)
local WorldPlan = require(ReplicatedStorage.MowALawn.WorldPlan)

local WorldGen = {}

local STUDS = Enum.SurfaceType.Studs
local SMOOTH = Enum.SurfaceType.Smooth

-- A plain block. Ground and props are Plastic with studs on top, like toy bricks.
local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = STUDS
	p.BottomSurface = SMOOTH
	p.LeftSurface = SMOOTH
	p.RightSurface = SMOOTH
	p.FrontSurface = SMOOTH
	p.BackSurface = SMOOTH
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
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

-- Big chunky sign text (SurfaceGui on the front face).
local function signText(part: BasePart, lines: { { text: string, color: Color3, size: number } }, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.Parent = gui
	local total = 0
	for _, l in lines do
		total += l.size
	end
	for i, l in lines do
		local t = Instance.new("TextLabel")
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(0.94, 0, l.size / total * 0.86, 0)
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.Text = l.text
		t.TextColor3 = l.color
		t.TextStrokeTransparency = 0.2
		t.Parent = gui
	end
	gui.Parent = part
	return gui
end

local function flat(v: Vector2, y: number): Vector3
	return Vector3.new(v.X, y, v.Y)
end

-- Yields every so often while building, so Studio stays responsive.
local built = 0
local function tick()
	built += 1
	if built % 300 == 0 then
		task.wait()
	end
end

-------------------------------------------------------------------------------------------------------------
-- ground
-------------------------------------------------------------------------------------------------------------
local function groundColor(c: any): Color3
	if c.kind == "zone" then
		local pal = Zones.region(c.region).palette
		return if (c.h // Zones.STEP) % 2 == 0 then pal.ground else pal.ground2
	elseif c.kind == "rock" or c.kind == "cut" then
		local rock = Zones.region(c.near).palette.rock
		return if (c.h // 4) % 2 == 0 then rock else rock:Lerp(Color3.new(0, 0, 0), 0.12)
	elseif c.kind == "chasm" then
		return Color3.fromRGB(70, 66, 74)
	end
	return Color3.fromRGB(226, 200, 140) -- sea floor sand
end

local function buildGround(world: Folder, plan: any)
	local ground = folder(world, "Ground")
	local B = Zones.BOUNDS
	local C = Zones.CELL
	local rects = WorldPlan.rects(plan, function(c)
		if c.kind == "void" then
			return nil
		end
		local look = if c.kind == "zone" then "z" .. c.region .. ":" .. (c.h // Zones.STEP) % 2 elseif c.kind == "sea" then "sea" else c.kind .. ":" .. c.near .. ":" .. (c.h // 4) % 2
		return look
	end)
	local isleZone = nil
	for zi, def in Zones.list do
		if def.floating then
			isleZone = zi
		end
	end
	local holder = Instance.new("Folder")
	holder.Name = "Chunk"
	local n = 0
	for _, r in rects do
		local c = r.cell
		local top = c.h
		local bottom = Zones.FLOOR
		if c.kind == "zone" and c.region == isleZone then
			bottom = top - 14
		end
		local x0 = B.minX + (r.i - 1) * C
		local z0 = B.minZ + (r.j - 1) * C
		local size = Vector3.new(r.w * C, top - bottom, r.d * C)
		local cf = CFrame.new(x0 + size.X / 2, (top + bottom) / 2, z0 + size.Z / 2)
		local name = if c.kind == "zone" then "Floor" elseif c.kind == "sea" then "SeaFloor" else "Rock"
		local p = block(holder, name, size, cf, groundColor(c))
		if c.kind == "zone" then
			p:SetAttribute("Zone", c.region)
		end
		n += 1
		if n % 400 == 0 then
			holder.Parent = ground
			holder = Instance.new("Folder")
			holder.Name = "Chunk"
			task.wait()
		end
	end
	holder.Parent = ground
	return rects
end

-- The sea, gorge water and lava, plus the invisible hazards that send a fallen player back.
local function buildWater(world: Folder, plan: any)
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(40, 170, 230)
	terrain.WaterTransparency = 0.25
	terrain.WaterWaveSize = 0.1
	terrain.WaterReflectance = 0.5
	local hazards = folder(world, "Hazards")
	local B = Zones.BOUNDS
	local C = Zones.CELL
	local lavaF = folder(world, "Lava")
	local rects = WorldPlan.rects(plan, function(c)
		if c.kind == "sea" or c.kind == "void" then
			return "sea"
		elseif c.kind == "chasm" then
			return "chasm"
		end
		return nil
	end)
	local corridorBottom: { [number]: string } = {}
	for _, cor in plan.corridors do
		corridorBottom[cor.zone] = cor.bottom or "water"
	end
	for _, r in rects do
		local x0 = B.minX + (r.i - 1) * C
		local z0 = B.minZ + (r.j - 1) * C
		local w, d = r.w * C, r.d * C
		local cx, cz = x0 + w / 2, z0 + d / 2
		if r.key == "sea" then
			terrain:FillBlock(CFrame.new(cx, (-20 + Zones.SEA) / 2, cz), Vector3.new(w, Zones.SEA + 20, d), Enum.Material.Water)
			local hz = block(hazards, "Sea", Vector3.new(w, 10, d), CFrame.new(cx, Zones.SEA - 3, cz), Color3.new(0, 0, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
			hz:SetAttribute("Hazard", true)
		else
			local bottom = r.cell.h
			-- which corridor's gorge is this? the nearest one
			local p = Vector2.new(cx, cz)
			local best, bestD = "water", math.huge
			for _, cor in plan.corridors do
				if cor.chasm then
					local dd = (p - (cor.a + cor.b) / 2).Magnitude
					if dd < bestD then
						best, bestD = cor.bottom or "water", dd
					end
				end
			end
			if best == "lava" then
				block(lavaF, "Lava", Vector3.new(w, 1, d), CFrame.new(cx, bottom + 0.5, cz), Color3.fromRGB(255, 110, 30), { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, TopSurface = SMOOTH })
			else
				terrain:FillBlock(CFrame.new(cx, bottom + 3, cz), Vector3.new(w, 6, d), Enum.Material.Water)
			end
			local hz = block(hazards, "Gorge", Vector3.new(w, 10, d), CFrame.new(cx, bottom + 5, cz), Color3.new(1, 0, 0), { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
			hz:SetAttribute("Hazard", true)
		end
		tick()
	end
end

-------------------------------------------------------------------------------------------------------------
-- corridors and gates
-------------------------------------------------------------------------------------------------------------
local STONE = Color3.fromRGB(196, 186, 170)
local WOOD = Color3.fromRGB(168, 112, 64)

-- Stairs from a (height ha) to b (height hb): 4-stud treads, each rising at most 2 studs.
local function stairs(parent: Instance, cor: any, color: Color3, name: string, thickness: number?): { BasePart }
	local seg = cor.b - cor.a
	local len = seg.Magnitude
	local dir = seg.Unit
	local n = math.max(1, math.ceil(len / 4))
	local out = {}
	local lo = math.min(cor.ha, cor.hb) - 6
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local top = cor.ha + (cor.hb - cor.ha) * ((k + 1) / n)
		local p = cor.a + seg * t
		local bottom = if thickness then top - thickness else lo
		local size = Vector3.new(cor.width, top - bottom, len / n + 0.05)
		local cf = CFrame.lookAt(flat(p, (top + bottom) / 2), flat(p + dir, (top + bottom) / 2))
		table.insert(out, block(parent, name, size, cf, if k % 2 == 0 then color else color:Lerp(Color3.new(0, 0, 0), 0.08)))
	end
	return out
end

-- Stepping stones for the floating isles.
local function stones(parent: Instance, cor: any, color: Color3): { BasePart }
	local seg = cor.b - cor.a
	local len = seg.Magnitude
	local n = math.ceil(len / 6.5)
	local out = {}
	local R = WorldPlan.rng(cor.zone * 31)
	local side = Vector2.new(-seg.Unit.Y, seg.Unit.X)
	for k = 0, n do
		local t = k / n
		local p = cor.a + seg * t + side * ((R() - 0.5) * 3)
		local top = cor.ha + (cor.hb - cor.ha) * t
		table.insert(out, block(parent, "Stone", Vector3.new(5, 1.6, 5), CFrame.new(flat(p, top - 0.8)) * CFrame.Angles(0, R() * 0.6, 0), color))
	end
	return out
end

local function formatPrice(n: number): string
	if n >= 1e6 then
		return (("%.1f"):format(n / 1e6):gsub("%.0$", "")) .. "M"
	elseif n >= 1e3 then
		return (("%.1f"):format(n / 1e3):gsub("%.0$", "")) .. "K"
	end
	return tostring(n)
end

local function buildGate(gates: Folder, corridors: Folder, cor: any)
	local def = Zones.list[cor.zone]
	local gateDef = Zones.GATES[cor.gate]
	local seg = cor.b - cor.a
	local dir = seg.Unit
	local side = Vector2.new(-dir.Y, dir.X)
	local mid = cor.a + seg * 0.5
	local midH = (cor.ha + cor.hb) / 2
	local accent = def.palette.accent

	if cor.gate == "open" then
		local f = folder(corridors, "Way" .. cor.zone)
		stairs(f, cor, STONE, "Stair")
		return
	end

	local model = Instance.new("Model")
	model.Name = "Gate" .. cor.zone
	model:SetAttribute("Zone", cor.zone)
	model:SetAttribute("Kind", cor.gate)
	model:SetAttribute("Price", def.price)

	if gateDef.chasm then
		-- the walkway is the gate: solid only for players who own the zone
		local walk = if cor.gate == "stones" then stones(model, cor, accent) else stairs(model, cor, if cor.gate == "obsidian" then Color3.fromRGB(40, 32, 48) else WOOD, "Walkway", 1.4)
		for _, p in walk do
			p.Name = "Walkway"
		end
		-- posts at both ends
		for _, endP in { { cor.a, cor.ha }, { cor.b, cor.hb } } do
			for _, s in { -1, 1 } do
				local pos = endP[1] + side * s * (cor.width / 2 + 0.6)
				block(model, "Post", Vector3.new(1.4, 7, 1.4), CFrame.new(flat(pos, endP[2] + 3.5)), WOOD)
				block(model, "PostGlow", Vector3.new(1.6, 0.6, 1.6), CFrame.new(flat(pos, endP[2] + 7.3)), accent, { Material = Enum.Material.Neon })
			end
		end
	else
		-- stairs through the pass, blocked in the middle
		local f = folder(corridors, "Way" .. cor.zone)
		stairs(f, cor, STONE, "Stair")
		local blockerColor = if cor.gate == "barrier" then Color3.fromRGB(255, 120, 220) elseif cor.gate == "icewall" then Color3.fromRGB(140, 220, 255) else Color3.fromRGB(120, 112, 104)
		local cf = CFrame.lookAt(flat(mid, midH + 10), flat(mid + dir, midH + 10))
		if cor.gate == "rockslide" then
			local R = WorldPlan.rng(cor.zone * 17)
			for k = 1, 6 do
				local sz = 5 + R() * 5
				local off = Vector3.new((R() - 0.5) * (cor.width - 4), -6 + R() * 12, (R() - 0.5) * 4)
				block(model, "Blocker", Vector3.new(sz, sz, sz), cf * CFrame.new(off) * CFrame.Angles(R(), R(), R()), blockerColor)
			end
			block(model, "Blocker", Vector3.new(cor.width + 2, 22, 3), cf, blockerColor, { Transparency = 1 })
		else
			block(model, "Blocker", Vector3.new(cor.width + 2, 22, if cor.gate == "icewall" then 4 else 1), cf, blockerColor, {
				Material = if cor.gate == "barrier" then Enum.Material.ForceField else Enum.Material.Glass,
				Transparency = if cor.gate == "barrier" then 0.2 else 0.35,
			})
		end
		-- the arch around it
		for _, s in { -1, 1 } do
			block(model, "Arch", Vector3.new(3, 24, 4), cf * CFrame.new(s * (cor.width / 2 + 1.5), 2, 0), STONE)
		end
		block(model, "Arch", Vector3.new(cor.width + 6, 3, 4), cf * CFrame.new(0, 15.5, 0), STONE)
		block(model, "ArchGlow", Vector3.new(cor.width + 6.4, 0.6, 4.4), cf * CFrame.new(0, 17.2, 0), accent, { Material = Enum.Material.Neon })
	end

	-- the price sign on the near side, facing the player coming up
	local signAt = cor.a + dir * 6 + side * (cor.width / 2 + 4)
	local post = block(model, "SignPost", Vector3.new(1, 8, 1), CFrame.new(flat(signAt, cor.ha + 4)), WOOD)
	local board = block(model, "Sign", Vector3.new(10, 6, 0.8), CFrame.lookAt(flat(signAt, cor.ha + 9), flat(signAt - dir, cor.ha + 9)), Color3.fromRGB(28, 26, 36))
	block(model, "SignGlow", Vector3.new(10.4, 0.4, 1), board.CFrame * CFrame.new(0, -3.2, 0), accent, { Material = Enum.Material.Neon })
	signText(board, {
		{ text = string.upper(def.name), color = Color3.new(1, 1, 1), size = 1.1 },
		{ text = formatPrice(def.price) .. " COINS", color = Color3.fromRGB(255, 214, 60), size = 1.4 },
		{ text = gateDef.label, color = accent, size = 0.8 },
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockPrompt"
	prompt.ActionText = "Unlock " .. def.name
	prompt.ObjectText = formatPrice(def.price) .. " coins"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = post
	model.Parent = gates
end

-------------------------------------------------------------------------------------------------------------
-- pads, village, landmarks, patches
-------------------------------------------------------------------------------------------------------------
local DARK = Color3.fromRGB(46, 44, 56)

-- A teleport/sell pad: stepped dark stone base, glowing neon ring, white emblem text on top.
local function pad(parent: Instance, name: string, at: Vector3, radius: number, color: Color3, label: string): Part
	local disc = function(r: number, h: number, y: number, col: Color3, props: { [string]: any }?)
		local p = block(parent, name .. "Step", Vector3.new(h, r * 2, r * 2), CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), col, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	disc(radius + 2, 1, 0.5, DARK)
	disc(radius + 1, 1, 1.5, DARK:Lerp(Color3.new(1, 1, 1), 0.08))
	disc(radius + 0.5, 0.3, 2.1, color, { Material = Enum.Material.Neon })
	local top = disc(radius, 0.5, 2.3, Color3.fromRGB(30, 30, 40))
	top.Name = name
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- the cylinder's flat top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.7, 0.3)
	t.Position = UDim2.fromScale(0.15, 0.35)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = label
	t.Rotation = 90
	t.Parent = gui
	gui.Parent = top
	return top
end

local function buildPads(world: Folder, plan: any)
	local pads = folder(world, "Pads")
	for _, p in plan.pads do
		local def = Zones.list[p.zone]
		local at = flat(p.at, p.h)
		local part
		if p.kind == "toZone" then
			part = pad(pads, "ZonePad", at, 5, def.palette.accent, string.upper(def.name))
		else
			part = pad(pads, "VillagePad", at, 5, Color3.fromRGB(255, 220, 90), "VILLAGE")
		end
		part:SetAttribute("PadKind", p.kind)
		part:SetAttribute("Zone", p.zone)
		tick()
	end
end

-- The village (blockout): a plaza, the sell pad, buildings as labelled blocks on marker spots.
local VILLAGE_SPOTS = {
	{ name = "Sell", at = Vector2.new(-24, -16), size = Vector3.new(0, 0, 0), label = "SELL" },
	{ name = "Shop", at = Vector2.new(22, -24), size = Vector3.new(16, 12, 12), label = "TOOL SHOP" },
	{ name = "Upgrades", at = Vector2.new(30, 4), size = Vector3.new(12, 10, 12), label = "UPGRADES" },
	{ name = "Garage", at = Vector2.new(-34, 12), size = Vector3.new(16, 12, 14), label = "GARAGE" },
	{ name = "Pets", at = Vector2.new(-6, -34), size = Vector3.new(14, 11, 10), label = "PETS" },
	{ name = "Classes", at = Vector2.new(-30, -34), size = Vector3.new(12, 12, 10), label = "CLASSES" },
	{ name = "Rewards", at = Vector2.new(14, 26), size = Vector3.new(10, 8, 8), label = "REWARDS" },
	{ name = "Boards", at = Vector2.new(22, -42), size = Vector3.new(18, 14, 2), label = "LEADERBOARDS" },
	{ name = "Portal", at = Vector2.new(0, -58), size = Vector3.new(14, 18, 3), label = "LOBBY" },
}

local function buildVillage(world: Folder)
	local v = folder(world, "Village")
	local spots = folder(v, "Spots")
	for _, s in VILLAGE_SPOTS do
		local marker = block(spots, s.name, Vector3.new(2, 1, 2), CFrame.new(flat(s.at, 0.5)), Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false })
		marker:SetAttribute("Spot", s.name)
		if s.name == "Sell" then
			local top = pad(v, "SellPad", flat(s.at, 0), 9, Color3.fromRGB(120, 255, 90), "SELL")
			top:SetAttribute("Sell", true)
		else
			local face = CFrame.lookAt(flat(s.at, s.size.Y / 2), flat(Vector2.zero, s.size.Y / 2))
			local b = block(v, s.name .. "Block", s.size, face, Color3.fromRGB(180, 150, 110))
			signText(b, { { text = s.label, color = Color3.new(1, 1, 1), size = 1 } }, Enum.NormalId.Front)
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 14)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = world
	-- a fountain in the middle
	local f = block(v, "Fountain", Vector3.new(2, 14, 14), CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), STONE)
	f.Shape = Enum.PartType.Cylinder
	local w = block(v, "FountainWater", Vector3.new(0.4, 12, 12), CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 200, 255), { Material = Enum.Material.Neon, Transparency = 0.2 })
	w.Shape = Enum.PartType.Cylinder
end

-- A grey stand-in for each landmark (the art pass replaces them).
local function buildLandmarks(world: Folder, plan: any)
	local lm = folder(world, "Landmarks")
	for zi, def in Zones.list do
		local l = def.landmark
		local i, j = plan.cellAt(l.at)
		local c = plan.get(i, j)
		local base = if c and c.kind == "zone" then c.h else def.base
		local m = Instance.new("Model")
		m.Name = def.id .. "_" .. l.kind
		m:SetAttribute("Zone", zi)
		local col = def.palette.accent
		if l.kind == "floatrock" then
			block(m, "Rock", Vector3.new(30, 20, 26), CFrame.new(flat(l.at, base + l.height)), def.palette.rock)
			block(m, "Heart", Vector3.new(8, 8, 8), CFrame.new(flat(l.at, base + l.height - 13)) * CFrame.Angles(0.6, 0.6, 0), col, { Material = Enum.Material.Neon })
		else
			local w = if l.kind == "volcano" then 46 else 12
			local steps = if l.kind == "volcano" then 6 else 1
			for k = 0, steps - 1 do
				local hh = l.height / steps
				local ww = w * (1 - k / (steps + 1))
				block(m, "Body", Vector3.new(ww, hh, ww), CFrame.new(flat(l.at, base + hh * (k + 0.5))), if k == steps - 1 then col else Color3.fromRGB(150, 150, 150))
			end
			block(m, "Top", Vector3.new(w * 0.7, 3, w * 0.7), CFrame.new(flat(l.at, base + l.height + 1.5)), col, { Material = Enum.Material.Neon })
		end
		local tag = block(m, "Label", Vector3.new(1, 1, 1), CFrame.new(flat(l.at, base + l.height + 6)), col, { Transparency = 1, CanCollide = false, CanQuery = false })
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(240, 40)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 2000
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = string.upper(l.kind) .. " (stand-in)"
		t.Parent = bb
		bb.Parent = tag
		m.Parent = lm
	end
end

-- Grass patches: invisible discs on the zone floor. The grass system scatters clusters inside them.
local function buildPatches(world: Folder, plan: any)
	local root = folder(world, "Patches")
	local byZone: { [number]: Folder } = {}
	for k, patch in plan.patches do
		local f = byZone[patch.zone]
		if not f then
			f = folder(root, "Zone" .. patch.zone)
			byZone[patch.zone] = f
		end
		for b, blob in patch.blobs do
			local i, j = plan.cellAt(blob.at)
			local c = plan.get(i, j)
			local h = if c then c.h else 0
			local disc = block(f, "Patch" .. k .. "_" .. b, Vector3.new(1, blob.r * 2, blob.r * 2), CFrame.new(flat(blob.at, h + 0.5)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 255, 255), {
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
			disc.Shape = Enum.PartType.Cylinder
			disc:SetAttribute("Zone", patch.zone)
			disc:SetAttribute("Patch", k)
		end
	end
end

-- Islands of the floating zone: little plank bridges between them so the whole zone is walkable.
local function buildIsleBridges(world: Folder, plan: any)
	local isles = plan.islands
	if #isles == 0 then
		return
	end
	local def
	for _, d in Zones.list do
		if d.floating then
			def = d
		end
	end
	local f = folder(world, "IsleBridges")
	for k = 2, #isles do
		local a, b = isles[1].c, isles[k].c
		local dir = (b - a).Unit
		local from = a + dir * (isles[1].r * 0.7)
		local to = b - dir * (isles[k].r * 0.7)
		local len = (to - from).Magnitude
		local mid = (from + to) / 2
		block(f, "Bridge", Vector3.new(6, 1.2, len), CFrame.lookAt(flat(mid, def.base - 0.6), flat(to, def.base - 0.6)), def.palette.accent, { Material = Enum.Material.Neon, Transparency = 0.15 })
	end
end

-- Invisible walls past the coast, so nobody swims off the map.
local function buildBounds(world: Folder)
	local f = folder(world, "Bounds")
	local n = 48
	local r = Zones.COAST + 30
	local c = Zones.WORLD_CENTER
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local p = c + Vector2.new(math.cos(a), math.sin(a)) * r
		local width = 2 * math.pi * r / n + 4
		block(f, "Wall", Vector3.new(width, 300, 4), CFrame.lookAt(flat(p, 100), flat(c, 100)), Color3.new(1, 1, 1), { Transparency = 1, CastShadow = false })
	end
end

-------------------------------------------------------------------------------------------------------------
-- build
-------------------------------------------------------------------------------------------------------------
function WorldGen.build(): Folder
	local t0 = os.clock()
	built = 0
	local plan = WorldPlan.make(Zones)
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "World"
	world:SetAttribute("Built", os.date("%Y-%m-%d %H:%M"))
	world:SetAttribute("Generator", "WorldGen v1 (blockout)")
	world.Parent = workspace

	local rects = buildGround(world, plan)
	buildWater(world, plan)
	local gates = folder(world, "Gates")
	local corridors = folder(world, "Ways")
	for _, cor in plan.corridors do
		buildGate(gates, corridors, cor)
		tick()
	end
	buildPads(world, plan)
	buildVillage(world)
	buildLandmarks(world, plan)
	buildPatches(world, plan)
	buildIsleBridges(world, plan)
	buildBounds(world)
	local visuals = folder(world, "Visuals")
	folder(visuals, "Village")
	for _, def in Zones.list do
		folder(visuals, def.name)
	end

	local parts = 0
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local msg = ("[WorldGen] built in %.1fs: %d ground blocks, %d parts in all, %d patches"):format(os.clock() - t0, #rects, parts, #plan.patches)
	if not RunService:IsRunning() then
		print(msg)
	end
	return world
end

return WorldGen
