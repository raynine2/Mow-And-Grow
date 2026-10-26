-- The boss weapon crate (Chop A Forest v2): when a boss appears, a crate parachutes down in front of it. Opening it
-- gives you your best gun for the fight (the Glock for everyone; the AK-47 / Minigun if bought with Robux). The guns
-- are taken away when the boss falls. The client fires (client/GunFx) and sends only the aim direction; the server
-- checks the fire rate, the Minigun's spin-up, the range and the aim, then damages the boss (a share of its max HP)
-- or the crawler you're aiming at.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local RunBuilder = require(script.Parent.RunBuilder)
local Boss = require(script.Parent.Boss)
local Night = require(script.Parent.Night)

local Guns = {}

local crate: Model? = nil
local folder: Instance? = nil
local lastShot: { [Player]: number } = {}
local spinStart: { [Player]: number } = {}

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- The best gun this player owns (the Glock for everyone).
function Guns.best(data)
	local best = Config.GUNS[1]
	for _, g in Config.GUNS do
		if g.product and data.guns and data.guns[g.id] then
			best = g
		end
	end
	return best
end

local function buildTool(def): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.CanBeDropped = false
	tool.ToolTip = "Click to shoot the boss"
	tool:SetAttribute("GunId", def.id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 1, 0.5)
	handle.Color = Color3.fromRGB(40, 40, 46)
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool
	local function piece(size: Vector3, offset: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.CFrame = handle.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = handle
		w.Parent = p
		p.Parent = tool
		return p
	end
	if def.id == "Pistol" then
		piece(Vector3.new(0.45, 0.5, 1.6), CFrame.new(0, 0.6, -0.4), def.color)
	elseif def.id == "Rifle" then
		piece(Vector3.new(0.45, 0.55, 3), CFrame.new(0, 0.6, -0.9), Color3.fromRGB(50, 50, 56))
		piece(Vector3.new(0.4, 0.5, 1.3), CFrame.new(0, 0.5, 1.1), def.color)
		piece(Vector3.new(0.35, 0.9, 0.4), CFrame.new(0, -0.1, -0.7) * CFrame.Angles(math.rad(15), 0, 0), Color3.fromRGB(40, 40, 46))
	else
		piece(Vector3.new(1, 1, 2), CFrame.new(0, 0.7, -0.4), def.color)
		for i = 0, 5 do
			local a = i * math.pi / 3
			piece(Vector3.new(0.18, 0.18, 2.2), CFrame.new(math.cos(a) * 0.3, 0.7 + math.sin(a) * 0.3, -2.4), Color3.fromRGB(60, 60, 66))
		end
	end
	return tool
end

local function holding(player: Player): (any, Tool?)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("GunId")
	return if id then Config.gun(id) else nil, tool
end

-- Give `player` their best gun (once per fight).
function Guns.give(player: Player)
	local data = PlayerData.get(player)
	if not data or not Boss.alive() then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, c in { backpack, player.Character } do
		if c then
			for _, t in c:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("GunId") then
					return -- already armed
				end
			end
		end
	end
	local def = Guns.best(data)
	local tool = buildTool(def)
	tool.Parent = backpack
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:EquipTool(tool)
	end
	Net.notify(player, "You grabbed the " .. def.name .. "! Click to shoot the boss.", "green")
	Net.send(player, "Fx", "gunGot", { gun = def.id })
end

-- The crate: falls on a parachute in front of the boss, then opens with a prompt.
function Guns.dropCrate(z: number)
	Guns.clear()
	-- between the boss (which stands at the area's centre facing its gate) and the gate, on the ground there
	-- (it used the old straight-road layout: far from the boss, or under the terraces, in the generated world)
	local centre = RunBuilder.zoneCentre(z)
	local gate = Config.gatePos(z)
	local toGate = Vector3.new(gate.X - centre.X, 0, gate.Z - centre.Z)
	toGate = if toGate.Magnitude > 1 then toGate.Unit else Vector3.zAxis
	local spot = centre + toGate * 26 + toGate:Cross(Vector3.yAxis) * 8
	local y = centre.Y
	local world = workspace:FindFirstChild("World")
	local floor = world and world:FindFirstChild("Ground")
	if floor then
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { floor }
		local hit = workspace:Raycast(Vector3.new(spot.X, centre.Y + 80, spot.Z), Vector3.new(0, -200, 0), rp)
		if hit then
			y = hit.Position.Y
		end
	end
	local ground = Vector3.new(spot.X, y, spot.Z)
	local m = Instance.new("Model")
	m.Name = "WeaponCrate"
	local box = part(m, Vector3.new(4, 3, 4), CFrame.new(ground + Vector3.new(0, 1.5, 0)), Color3.fromRGB(70, 110, 60), Enum.Material.WoodPlanks)
	box.CanCollide = true
	for _, y in { 0.4, 2.6 } do
		part(m, Vector3.new(4.1, 0.3, 4.1), CFrame.new(ground + Vector3.new(0, y, 0)), Color3.fromRGB(240, 200, 40))
	end
	-- the parachute: a flat canopy with stripes, and four lines down to the crate
	local chute = Instance.new("Model")
	chute.Name = "Parachute"
	chute.Parent = m
	for i = -2, 2 do
		part(chute, Vector3.new(2.2, 0.4 + (2 - math.abs(i)) * 0.4, 9), CFrame.new(ground + Vector3.new(i * 2.2, 11 + (2 - math.abs(i)) * 0.5, 0)), if i % 2 == 0 then Color3.fromRGB(240, 70, 60) else Color3.new(1, 1, 1))
	end
	for _, c in { { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } } do
		local top = ground + Vector3.new(c[1] * 2.4, 10.8, c[2] * 2.2)
		local bottom = ground + Vector3.new(c[1], 3, c[2])
		local mid = (top + bottom) / 2
		part(chute, Vector3.new(0.08, 0.08, (top - bottom).Magnitude), CFrame.lookAt(mid, top), Color3.fromRGB(230, 230, 230))
	end
	m.PrimaryPart = box
	local landed = box.CFrame
	m:PivotTo(landed + Vector3.new(0, 70, 0))
	m.Parent = folder
	crate = m
	Net.all("Fx", "crateDrop", { pos = ground })
	task.spawn(function()
		local t0 = os.clock()
		local fall = 3.2
		while m.Parent and os.clock() - t0 < fall do
			local k = (os.clock() - t0) / fall
			local sway = math.sin(k * math.pi * 3) * 0.12
			m:PivotTo((landed + Vector3.new(0, 70 * (1 - k), 0)) * CFrame.Angles(0, 0, sway))
			task.wait()
		end
		if not m.Parent then
			return
		end
		m:PivotTo(landed)
		chute:Destroy()
		Net.all("Fx", "crateLand", { pos = ground })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab a gun"
		prompt.ObjectText = "Weapon Crate"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = box
		prompt.Triggered:Connect(Guns.give)
	end)
end

-- Fight over: the crate goes, and so do the guns.
function Guns.clear()
	if crate then
		crate:Destroy()
		crate = nil
	end
	for _, p in Players:GetPlayers() do
		for _, c in { p:FindFirstChildOfClass("Backpack"), p.Character } do
			if c then
				for _, t in c:GetChildren() do
					if t:IsA("Tool") and t:GetAttribute("GunId") then
						t:Destroy()
					end
				end
			end
		end
	end
end

local function shoot(player: Player, aim: any)
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 or aim.Magnitude > 1.5 then
		return
	end
	local def = holding(player)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not def or not head then
		return
	end
	local dir = aim.Unit
	local now = os.clock()
	-- fire rate (a little slack for network jitter)
	if now - (lastShot[player] or 0) < 0.8 / def.rate then
		return
	end
	-- the Minigun has to spin up: a pause longer than 0.4 s starts the spin over
	if now - (lastShot[player] or 0) > 0.4 then
		spinStart[player] = now
	end
	lastShot[player] = now
	if def.spin and now - (spinStart[player] or now) < def.spin then
		return
	end
	local origin = head.Position
	local bossPos, maxHp = Boss.info()
	if bossPos then
		local to = bossPos + Vector3.new(0, 6, 0) - origin
		if to.Magnitude <= def.range and to.Unit:Dot(dir) > 0.8 then
			Boss.damage(player, math.max(1, maxHp * def.pct))
			return
		end
	end
	local crawlerPos = Night.aimed(origin, dir, def.range)
	if crawlerPos then
		local z = Config.ZONES[1]
		local data = PlayerData.get(player)
		local zone = data and data.run and Config.ZONES[data.run.zone] or z
		Night.hit(player, crawlerPos, 0.5, zone.hp * 2)
	end
end

local started = false
function Guns.start(parent: Instance)
	folder = parent
	if started then
		return
	end
	started = true
	Net.on("Shoot", 30, shoot)
	Players.PlayerRemoving:Connect(function(p)
		lastShot[p] = nil
		spinStart[p] = nil
	end)
end

return Guns
