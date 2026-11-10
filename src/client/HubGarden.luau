--!strict
-- THE PET GARDEN (10 Nov 2026; owner: "make the pets from eggs walk here and make a hatch place to interact ... make
-- the hub more interactable"; remodelled the same day: "make the models with blender ... the stud voxel style", "make
-- it more detailed"; design: the Claude Design canvas "Mow And Grow Hub Remodel"). At the hub's GardenSpot
-- (server/HubFun), built by shared/HubBricks from the Blender model pet_garden: a studded hedge ring with flowers, a
-- mown-stripe lawn, a pond with lily pads, reeds and a plank bridge, flower beds, a fruit tree, mushrooms, a bench, a
-- birdhouse, stepping stones from a flowered gate arch with lanterns and PET GARDEN on it. Every critter you can hatch
-- (Config.PETS) wanders the lawn, hopping round the pond, the beds and the tree. Outside the gate the eggs sit in straw
-- nests on stone pedestals, turning slowly over a glow ring in their colour, the price over them (the VIP price for
-- VIPs: Config.eggPrice). OPEN on an egg opens the EGGS window (client/PetsWindow: the odds, the buttons). The Golden
-- Egg (Robux, random) only stands there where Roblox's policy allows paid random items (shared/Policy), like in the
-- window. Only in the lobby; drawn by each client.
local HubGarden = {}
task.spawn(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer
	local here = script.Parent
	local Shared = ReplicatedStorage:WaitForChild("MowALawn")
	local Config = require(Shared:WaitForChild("Config"))
	local Format = require(Shared:WaitForChild("Format"))
	local PartBuild = require(Shared:WaitForChild("PartBuild"))
	local Policy = require(Shared:WaitForChild("Policy"))
	local HubBricks = require(Shared:WaitForChild("HubBricks")) :: any
	local State = require(here:WaitForChild("State"))
	local UI = require(here:WaitForChild("UI")) :: any
	local PetFollow = require(here:WaitForChild("PetFollow")) :: any
	-- (10 Nov, owner: "make pet garden bigger and 100x prettier with high quality") the lush garden from the game's own
	-- models (client/GardenBuild); the stud-voxel one only if those aren't there
	local GardenBuild = require(here:WaitForChild("GardenBuild")) :: any
	if not Config.HUB_FUN or not Config.HUB_FUN.on then
		return
	end
	local PET_SCALE = 1.05
	local LAWN_Y = 1 -- the lawn's top, over the spot
	local FONT = Config.UI and Config.UI.font or Enum.Font.FredokaOne
	local INK = Color3.fromRGB(30, 26, 40)
	local WHITE = Color3.new(1, 1, 1)

	local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = parent
		return p
	end

	local function text(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = size
		l.Position = pos
		l.Font = FONT
		l.TextScaled = true
		l.Text = t
		l.TextColor3 = color
		l.Parent = parent
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = 3
		s.Parent = l
		return l
	end

	type Critter = { model: Model, pos: Vector3, yaw: number, goal: Vector3, waitUntil: number, hop: number, speed: number }
	type Egg = { model: Model, base: CFrame, price: TextLabel?, egg: any }
	type Garden = { folder: Folder, center: CFrame, critters: { Critter }, eggs: { Egg }, free: (Vector3) -> boolean, radius: number }
	local garden: Garden? = nil
	local rng = Random.new()

	-- is this lawn spot free for a critter (not the pond, a bed, the tree)?
	local function freeTest(center: CFrame, anchors: any): ((Vector3) -> boolean, number)
		local radius = tonumber(anchors.lawnR) or 10
		local blocks = {}
		local pond = anchors.pond
		if type(pond) == "table" then
			table.insert(blocks, { x = pond[1], z = pond[2], r = pond[3] + 1.4 })
		end
		for _, b in (anchors.beds or {}) :: { any } do
			table.insert(blocks, { x = b[1], z = b[2], r = 2.9 })
		end
		local tree = anchors.tree
		if type(tree) == "table" then
			table.insert(blocks, { x = tree[1], z = tree[2], r = tree[3] })
		end
		for _, t in (anchors.trees or {}) :: { any } do
			table.insert(blocks, { x = t[1], z = t[2], r = t[3] })
		end
		for _, key in { "nestA", "nestB" } do -- (the lush garden's egg pedestals stand on the lawn)
			local n = anchors[key]
			if anchors.lush and typeof(n) == "Vector3" then
				local l = center:PointToObjectSpace(n)
				table.insert(blocks, { x = l.X, z = l.Z, r = 2.6 })
			end
		end
		return function(p: Vector3): boolean
			local l = center:PointToObjectSpace(p)
			if Vector2.new(l.X, l.Z).Magnitude > radius - 0.8 then
				return false
			end
			for _, b in blocks do
				if Vector2.new(l.X - b.x, l.Z - b.z).Magnitude < b.r then
					return false
				end
			end
			return true
		end, radius
	end

	local function randomSpot(g: { center: CFrame, free: (Vector3) -> boolean, radius: number }): Vector3
		for _ = 1, 30 do
			local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(1, g.radius - 1)
			local p = (g.center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)).Position
			if g.free(p) then
				return p
			end
		end
		return (g.center * CFrame.new(-4, 0, 3)).Position
	end

	local function critters(f: Folder, g: any): { Critter }
		local list = {}
		for _, def in Config.PETS do
			local ok, m = pcall(PetFollow.build, def.look)
			if ok and m then
				pcall(function()
					(m :: Model):ScaleTo(PET_SCALE)
				end)
				local pos = randomSpot(g)
				m.Parent = f
				table.insert(list, { model = m, pos = pos, yaw = rng:NextNumber(0, 2 * math.pi), goal = pos, waitUntil = os.clock() + rng:NextNumber(0, 3), hop = 0, speed = rng:NextNumber(3, 5.5) })
			end
		end
		return list
	end

	local function eggStand(f: Folder, at: Vector3, rot: CFrame, egg: any): Egg
		local m = PartBuild.get(if egg.id == "GoldenEgg" then "egg_golden" else "egg_garden")
		if not m then
			m = Instance.new("Model")
			local p = part(m :: Model, Vector3.new(2.4, 3, 2.4), CFrame.new(0, 1.5, 0), egg.color)
			p.Shape = Enum.PartType.Ball
		end
		local em = m :: Model
		for _, d in em:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		pcall(function()
			em:ScaleTo(1.25)
		end)
		em.Parent = f
		-- a glow ring on the pedestal's top in the egg's colour, a soft light
		local ring = part(f, Vector3.new(0.12, 3.6, 3.6), CFrame.new(at + Vector3.new(0, -0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)), egg.color)
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.55
		local light = Instance.new("PointLight")
		light.Color = egg.color
		light.Range = 9
		light.Brightness = 1.4
		light.Parent = ring
		-- the name and price over it
		local tagPart = part(f, Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 1, 0)), WHITE)
		tagPart.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(220, 70)
		bb.StudsOffset = Vector3.new(0, 4.6, 0)
		bb.MaxDistance = 70
		bb.LightInfluence = 0
		bb.Parent = tagPart
		text(bb, string.upper(egg.name), UDim2.new(1, 0, 0.55, 0), UDim2.fromScale(0, 0), egg.color:Lerp(WHITE, 0.25))
		local price = text(bb, "", UDim2.new(1, 0, 0.45, 0), UDim2.fromScale(0, 0.55), WHITE)
		-- OPEN: the eggs window
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Open"
		pp.ObjectText = egg.name
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 10
		pp.RequiresLineOfSight = false
		pp.Parent = tagPart
		pp.Triggered:Connect(function()
			if not UI.isOpen("Eggs") then
				UI.open("Eggs")
			end
		end)
		return { model = em, base = CFrame.new(at) * rot, price = price, egg = egg }
	end

	local function priceText(egg: any): string
		if egg.currency == "robux" then
			return "Exclusive pets!"
		end
		local p = Config.eggPrice(egg, player)
		if p < (egg.price or 0) then
			return ("%s 💎  (VIP -%d)"):format(Format.commas(p), Config.VIP_EGG_DISCOUNT)
		end
		return Format.commas(p) .. " 💎"
	end

	local function build(spot: BasePart): Garden
		local f = Instance.new("Folder")
		f.Name = "HubGarden"
		f.Parent = workspace
		local at = spot.CFrame
		local rot = at.Rotation
		local anchors = GardenBuild.build(at, f)
		if not anchors then
			local _, a = HubBricks.build("pet_garden", at, f)
			anchors = a
		end
		-- PET GARDEN on the arch's plank (the lush garden writes its own)
		local sign = part(f, Vector3.new(5.8, 1.4, 0.05), CFrame.new(anchors.sign :: Vector3) * rot * CFrame.new(0, 0, -0.06), WHITE)
		sign.Transparency = 1
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.LightInfluence = 0
		sg.Parent = sign
		text(sg, "PET GARDEN", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(255, 214, 80))
		if anchors.lush then
			sign:Destroy()
		end
		local lawnY = if anchors.lush then 0.77 else LAWN_Y
		local free, radius = freeTest(at * CFrame.new(0, lawnY, 0), anchors)
		local g: Garden = { folder = f, center = at * CFrame.new(0, lawnY, 0), critters = {}, eggs = {}, free = free, radius = radius }
		g.critters = critters(f, g)
		-- the eggs in their nests: the gem egg on one, the Robux egg on the other where it's allowed
		local gems, robux = {}, {}
		for _, egg in Config.EGGS do
			table.insert(if egg.currency == "robux" then robux else gems, egg)
		end
		if gems[1] and anchors.nestA then
			table.insert(g.eggs, eggStand(f, anchors.nestA :: Vector3, rot, gems[1]))
		end
		task.spawn(function()
			-- a Robux egg is a paid random item: only where Roblox's policy allows it
			if robux[1] and anchors.nestB and Policy.paidRandomOk() and garden == g then
				table.insert(g.eggs, eggStand(f, anchors.nestB :: Vector3, rot, robux[1]))
			end
		end)
		return g
	end

	-- a critter: wait a moment, pick a free spot on the lawn, hop over to it, look around
	local function wander(c: Critter, g: Garden, dt: number, now: number)
		local d = Vector3.new(c.goal.X - c.pos.X, 0, c.goal.Z - c.pos.Z)
		if d.Magnitude < 0.2 then
			if now > c.waitUntil then
				c.goal = randomSpot(g)
				c.waitUntil = now + rng:NextNumber(1.5, 4.5)
			end
			c.hop = math.max(0, c.hop - dt * 3)
		else
			local step = math.min(d.Magnitude, c.speed * dt)
			local nextPos = c.pos + d.Unit * step
			if not g.free(nextPos) and g.free(c.pos) then
				c.goal = randomSpot(g) -- (something in the way: somewhere else)
			else
				c.pos = nextPos
			end
			local want = math.atan2(-d.X, -d.Z)
			local dy = (want - c.yaw + math.pi) % (2 * math.pi) - math.pi
			c.yaw += dy * math.min(1, dt * 8)
			c.hop += dt * c.speed * 1.3
		end
		local lift = math.abs(math.sin(c.hop * math.pi)) * 0.9
		c.model:PivotTo(CFrame.new(c.pos + Vector3.new(0, 0.6 * PET_SCALE + lift, 0)) * CFrame.Angles(0, c.yaw, 0))
	end

	local lastPrice = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local world = workspace:FindFirstChild("World")
		local fun = world and world:FindFirstChild("HubFun")
		local spot = fun and fun:FindFirstChild("GardenSpot") :: BasePart?
		if not spot or State.isRun() then
			if garden then
				garden.folder:Destroy()
				garden = nil
			end
			return
		end
		if not garden then
			garden = build(spot)
		end
		local g = garden :: Garden
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - g.center.Position).Magnitude > 180 then
			return -- far away: nothing to move
		end
		local now = os.clock()
		for _, c in g.critters do
			wander(c, g, dt, now)
		end
		for k, e in g.eggs do
			local bob = math.sin(now * 2 + k) * 0.2
			e.model:PivotTo(e.base * CFrame.new(0, 0.1 + bob, 0) * CFrame.Angles(0, now * 0.8 + k, 0))
		end
		if now - lastPrice > 1 then
			lastPrice = now
			for _, e in g.eggs do
				if e.price then
					e.price.Text = priceText(e.egg)
				end
			end
		end
	end)
end)
return HubGarden
