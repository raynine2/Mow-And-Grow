--!strict
-- THE PET GARDEN (10 Nov 2026; owner: "make the pets from eggs walk here and make a hatch place to interact ... make
-- the hub more interactable"). At the hub's GardenSpot (server/HubFun): a round fenced lawn where every critter you
-- can hatch (Config.PETS) wanders, hops and looks around, with PET GARDEN over its gate; in front of it the eggs on
-- pedestals, turning slowly, their price over them (the VIP price for VIPs: Config.eggPrice). OPEN on an egg opens
-- the EGGS window (client/PetsWindow: the odds, the buttons). The Golden Egg (Robux, random) only stands there where
-- Roblox's policy allows paid random items (shared/Policy), like in the window. Only in the lobby; drawn by each
-- client (the critters run on their own on every screen).
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
	local State = require(here:WaitForChild("State"))
	local UI = require(here:WaitForChild("UI")) :: any
	local PetFollow = require(here:WaitForChild("PetFollow")) :: any
	if not Config.HUB_FUN or not Config.HUB_FUN.on then
		return
	end
	local RADIUS = 10 -- the lawn inside the fence
	local PET_SCALE = 1.7
	local FONT = Config.UI and Config.UI.font or Enum.Font.FredokaOne
	local INK = Color3.fromRGB(30, 26, 40)
	local WHITE = Color3.new(1, 1, 1)
	local CREAM = Color3.fromRGB(245, 236, 214)
	local WOOD = Color3.fromRGB(120, 78, 46)

	local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
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
	type Garden = { folder: Folder, center: CFrame, critters: { Critter }, eggs: { Egg } }
	local garden: Garden? = nil
	local rng = Random.new()

	-- the fence: short posts and two rails round the lawn, open at the front (the gate)
	local function fence(f: Folder, center: CFrame)
		part(f, Vector3.new(0.4, RADIUS * 2 + 2, RADIUS * 2 + 2), center * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 200, 90), Enum.Material.Grass, Enum.PartType.Cylinder)
		local n = 28
		local function open(a: number): boolean -- the gate: the posts straight in front are left out
			return math.abs(((a + math.pi) % (2 * math.pi)) - math.pi) < 0.32
		end
		for k = 0, n - 1 do
			local a = k / n * 2 * math.pi
			local a2 = (k + 1) / n * 2 * math.pi
			if not open(a) then
				local at = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(RADIUS + 0.6))
				part(f, Vector3.new(0.5, 2, 0.5), at * CFrame.new(0, 1, 0), WHITE)
				if not open(a2) then
					local next = center * CFrame.Angles(0, a2, 0) * CFrame.new(0, 0, -(RADIUS + 0.6))
					local len = (next.Position - at.Position).Magnitude
					local mid = (at.Position + next.Position) / 2
					for _, y in { 0.8, 1.6 } do
						part(f, Vector3.new(0.25, 0.3, len), CFrame.lookAt(mid, next.Position) + Vector3.new(0, y, 0), WHITE)
					end
				end
			end
		end
		-- PET GARDEN over the gate
		local front = center * CFrame.new(0, 0, -(RADIUS + 0.6))
		for _, x in { -3.3, 3.3 } do
			part(f, Vector3.new(0.8, 8, 0.8), front * CFrame.new(x, 4, 0), WOOD, Enum.Material.WoodPlanks)
		end
		local sign = part(f, Vector3.new(8.4, 1.9, 0.5), front * CFrame.new(0, 8.4, 0), WOOD, Enum.Material.WoodPlanks)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.LightInfluence = 0
		g.Parent = sign
		text(g, "PET GARDEN", UDim2.fromScale(0.94, 0.8), UDim2.fromScale(0.03, 0.1), Color3.fromRGB(255, 214, 80))
		-- a few flowers on the lawn
		for _ = 1, 14 do
			local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(2, RADIUS - 0.8)
			local at = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)
			part(f, Vector3.new(0.15, 0.7, 0.15), at * CFrame.new(0, 0.6, 0), Color3.fromRGB(70, 150, 60))
			local colors = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 220, 80), WHITE, Color3.fromRGB(150, 130, 255) }
			part(f, Vector3.new(0.6, 0.35, 0.6), at * CFrame.new(0, 1, 0), colors[rng:NextInteger(1, #colors)])
		end
	end

	local function critters(f: Folder, center: CFrame): { Critter }
		local list = {}
		for i, def in Config.PETS do
			local ok, m = pcall(PetFollow.build, def.look)
			if ok and m then
				pcall(function()
					(m :: Model):ScaleTo(PET_SCALE)
				end)
				local a, r = (i / #Config.PETS) * 2 * math.pi, rng:NextNumber(2, RADIUS - 2)
				local pos = (center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)).Position
				m.Parent = f
				table.insert(list, { model = m, pos = pos, yaw = rng:NextNumber(0, 2 * math.pi), goal = pos, waitUntil = os.clock() + rng:NextNumber(0, 3), hop = 0, speed = rng:NextNumber(3, 5.5) })
			end
		end
		return list
	end

	local function eggStand(f: Folder, at: CFrame, egg: any): Egg
		part(f, Vector3.new(3.4, 2.6, 3.4), at * CFrame.new(0, 1.3, 0), CREAM)
		part(f, Vector3.new(3.7, 0.5, 3.7), at * CFrame.new(0, 2.7, 0), egg.color)
		local m = PartBuild.get(if egg.id == "GoldenEgg" then "egg_golden" else "egg_garden")
		if not m then
			m = Instance.new("Model")
			local p = part(m :: Model, Vector3.new(2.4, 3, 2.4), CFrame.new(0, 1.5, 0), egg.color, nil, Enum.PartType.Ball)
			p.Size = Vector3.new(2.4, 3, 2.4)
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
			em:ScaleTo(1.7)
		end)
		em.Parent = f
		-- the name and price over it
		local tagPart = part(f, Vector3.new(1, 1, 1), at * CFrame.new(0, 8.4, 0), WHITE)
		tagPart.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(220, 70)
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
		tagPart.CFrame = at * CFrame.new(0, 3.5, 0)
		bb.StudsOffset = Vector3.new(0, 4.9, 0)
		pp.Triggered:Connect(function()
			if not UI.isOpen("Eggs") then
				UI.open("Eggs")
			end
		end)
		return { model = em, base = at * CFrame.new(0, 2.95, 0), price = price, egg = egg }
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
		local center = spot.CFrame
		fence(f, center)
		local g: Garden = { folder = f, center = center, critters = critters(f, center), eggs = {} }
		-- the eggs in front of the gate, either side of the way in
		local front = center * CFrame.new(0, 0, -(RADIUS + 4.5))
		local gems, robux = {}, {}
		for _, egg in Config.EGGS do
			table.insert(if egg.currency == "robux" then robux else gems, egg)
		end
		for _, egg in gems do
			table.insert(g.eggs, eggStand(f, front * CFrame.new(5.2, 0, 0), egg))
			break
		end
		-- a Robux egg is a paid random item: only where Roblox's policy allows it
		task.spawn(function()
			if robux[1] and Policy.paidRandomOk() and garden == g then
				table.insert(g.eggs, eggStand(f, front * CFrame.new(-5.2, 0, 0), robux[1]))
			end
		end)
		return g
	end

	-- a critter: wait a moment, pick a spot on the lawn, hop over to it, look around
	local function wander(c: Critter, center: CFrame, dt: number, now: number)
		local d = Vector3.new(c.goal.X - c.pos.X, 0, c.goal.Z - c.pos.Z)
		if d.Magnitude < 0.2 then
			if now > c.waitUntil then
				local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(1, RADIUS - 1.6)
				c.goal = (center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)).Position
				c.waitUntil = now + rng:NextNumber(1.5, 4.5)
			end
			c.hop = math.max(0, c.hop - dt * 3)
		else
			local step = math.min(d.Magnitude, c.speed * dt)
			c.pos += d.Unit * step
			local want = math.atan2(-d.X, -d.Z)
			local dy = (want - c.yaw + math.pi) % (2 * math.pi) - math.pi
			c.yaw += dy * math.min(1, dt * 8)
			c.hop += dt * c.speed * 1.3
		end
		local lift = math.abs(math.sin(c.hop * math.pi)) * 0.9
		c.model:PivotTo(CFrame.new(c.pos + Vector3.new(0, 0.6 * PET_SCALE + 0.4 + lift, 0)) * CFrame.Angles(0, c.yaw, 0))
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
			wander(c, g.center, dt, now)
		end
		for k, e in g.eggs do
			local bob = math.sin(now * 2 + k) * 0.25
			e.model:PivotTo(e.base * CFrame.new(0, 0.3 + bob, 0) * CFrame.Angles(0, now * 0.8 + k, 0))
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
