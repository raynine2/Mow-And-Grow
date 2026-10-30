-- Ride-on mowers: spawned at the garage pad, only the owner can drive, burn fuel while moving.
-- The driver's client steers (see client Drive); the server owns fuel and cutting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PlayerData = require(script.Parent.PlayerData)
local Net = require(script.Parent.Net)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)

local MOWER_MODEL = {
	RustyRider = "mower_rusty",
	TurboTractor = "mower_tractor",
	GoldenZeroTurn = "mower_zeroturn",
	MonsterMulcher = "mower_mulcher",
	TrialMower = "mower_trial",
	RocketMower = "mower_rocket",
}

local Mowers = {}

local active: { [Player]: Model } = {}
local folder: Folder? = nil
Mowers.spawnCFrame = CFrame.new(0, 2, 0)

function Mowers.setup(parent: Instance, spawnCf: CFrame)
	folder = PropKit.folder("Mowers", parent)
	Mowers.spawnCFrame = spawnCf
end

-- Does this player own mower `id` right now?
function Mowers.owns(data, id: string): boolean
	local def = Config.mower(id)
	if not def then
		return false
	end
	if def.currency == "gems" or def.currency == "robux" then
		return data.mowers[id] == true
	elseif def.currency == "coins" then
		return data.run ~= nil and data.run.mowers[id] == true
	elseif def.currency == "trial" then
		return data.run ~= nil and data.run.trial == true
	end
	return false
end

-- Chunky machine in the trailer's style: dark chassis, big tyres with coloured hubs, a coloured engine hood
-- with grille and exhaust, a seat with roll bar, and a wide mowing deck out front with a spinning blade disc.
local function decorate(model: Model, body: BasePart, def)
	local function add(size: Vector3, offset: CFrame, color: Color3, name: string, material: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = body.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = body
		w.Parent = p
		p.Parent = model
		return p
	end
	local dark = Color3.fromRGB(42, 42, 50)
	local steel = Color3.fromRGB(150, 155, 165)
	local c = def.color
	-- tyres: big at the back, small at the front, each with a coloured hub
	for _, x in { -2.9, 2.9 } do
		add(Vector3.new(1.4, 3.4, 3.4), CFrame.new(x, 0.4, 2.2), dark, "RearTyre", Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(1.5, 1.5, 1.5), CFrame.new(x, 0.4, 2.2), PropKit.shade(c, 0.9), "Hub", nil, Enum.PartType.Cylinder)
		add(Vector3.new(1, 2.2, 2.2), CFrame.new(x * 0.95, -0.2, -2.4), dark, "FrontTyre", Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(1.1, 1, 1), CFrame.new(x * 0.95, -0.2, -2.4), PropKit.shade(c, 0.9), "Hub", nil, Enum.PartType.Cylinder)
		-- mudguard over the rear tyre
		add(Vector3.new(1.7, 0.4, 3.8), CFrame.new(x, 2.3, 2.2), c, "Fender")
	end
	-- engine hood with a grille and an exhaust pipe
	add(Vector3.new(4.4, 2, 3.6), CFrame.new(0, 1.6, -1.8), c, "Hood")
	add(Vector3.new(4.6, 0.3, 3.8), CFrame.new(0, 2.7, -1.8), PropKit.shade(c, 0.85), "HoodTop")
	add(Vector3.new(3.4, 1.2, 0.2), CFrame.new(0, 1.5, -3.65), dark, "Grille")
	for i = -1, 1 do
		add(Vector3.new(3.2, 0.12, 0.25), CFrame.new(0, 1.5 + i * 0.35, -3.72), steel, "GrilleBar", Enum.Material.Metal)
	end
	add(Vector3.new(0.9, 0.5, 0.3), CFrame.new(-1.6, 2.1, -3.7), Color3.fromRGB(255, 250, 220), "Headlight", Enum.Material.Neon)
	add(Vector3.new(0.9, 0.5, 0.3), CFrame.new(1.6, 2.1, -3.7), Color3.fromRGB(255, 250, 220), "Headlight", Enum.Material.Neon)
	add(Vector3.new(0.5, 2.4, 0.5), CFrame.new(1.6, 3.6, -0.8), dark, "Exhaust", Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = body.CFrame * CFrame.new(1.6, 3.6, -0.8) * CFrame.Angles(0, 0, math.rad(90))
	-- steering wheel
	add(Vector3.new(0.3, 1.6, 0.3), CFrame.new(0, 2.6, 0.2) * CFrame.Angles(math.rad(-30), 0, 0), dark, "SteerColumn")
	add(Vector3.new(0.3, 1.6, 1.6), CFrame.new(0, 3.3, 0.6) * CFrame.Angles(math.rad(-30), 0, 0) * CFrame.Angles(0, 0, math.rad(90)), dark, "SteerWheel", nil, Enum.PartType.Cylinder)
	-- roll bar behind the seat
	for _, x in { -2.2, 2.2 } do
		add(Vector3.new(0.4, 4.4, 0.4), CFrame.new(x, 3.2, 3.6), dark, "RollBar", Enum.Material.Metal)
	end
	add(Vector3.new(4.8, 0.4, 0.4), CFrame.new(0, 5.4, 3.6), dark, "RollBarTop", Enum.Material.Metal)
	-- mowing deck out front with a spinning blade disc
	add(Vector3.new(7.4, 0.8, 3.2), CFrame.new(0, -0.6, -5.2), steel, "Deck", Enum.Material.DiamondPlate)
	add(Vector3.new(7.6, 0.3, 3.4), CFrame.new(0, -0.15, -5.2), PropKit.shade(c, 0.8), "DeckRim")
	local disc = add(Vector3.new(0.2, 3, 3), CFrame.new(0, -1.05, -5.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(215, 220, 230), "Blade", Enum.Material.Metal, Enum.PartType.Cylinder)
	disc:SetAttribute("SpinBlade", true)
	add(Vector3.new(0.25, 1.1, 1.1), CFrame.new(0, -0.95, -5.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 40, 40), "BladeHub", nil, Enum.PartType.Cylinder)
end

-- Moving parts of a Blender mower (named by tools/blender/to_parts.py): each tyre "Wheel<RL|RR|FL|FR>" and the
-- "Blade" get a Motor6D to the chassis that clients turn (client MowerFx); their bits ("WheelRL_lug3", "Blade_bar0")
-- weld to them; everything else welds to the chassis like Models.weldTo.
local function rig(placed: Model, body: BasePart)
	local hubs: { [string]: BasePart } = {}
	for _, p in placed:GetDescendants() do
		if p:IsA("BasePart") and (p.Name:match("^Wheel%u%u$") or p.Name == "Blade") then
			hubs[p.Name] = p
		end
	end
	for _, p in placed:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			if hubs[p.Name] == p then
				local motor = Instance.new("Motor6D")
				motor.Name = "Spin"
				motor.Part0 = body
				motor.Part1 = p
				motor.C0 = body.CFrame:ToObjectSpace(p.CFrame)
				motor.Parent = p
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = p
				w.Part1 = hubs[p.Name:match("^(%w+)_") or ""] or body
				w.Parent = p
			end
		end
	end
end

local function build(player: Player, def, fuel: number): Model
	local model = Instance.new("Model")
	model.Name = player.Name .. "'s " .. def.name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(5, 1.4, 7.2)
	body.Color = def.color
	body.TopSurface = Enum.SurfaceType.Smooth
	body.Color = Color3.fromRGB(42, 42, 50)
	body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0, 0, 100, 1)
	body.CFrame = Mowers.spawnCFrame
	body.Parent = model
	-- the Blender mower sits on the chassis (origin = ground under the middle); the chassis turns invisible
	local modelName = MOWER_MODEL[def.id]
	-- the Trial Mower has its own model; an old place without it falls back to a pink Zero-Turn
	local tint = def.id == "TrialMower" and not Models.has(modelName)
	if tint then
		modelName = "mower_zeroturn"
	end
	local placed = modelName and Models.place(modelName, model, body.CFrame * CFrame.new(0, -1.2, 0))
	if placed then
		rig(placed, body)
		body.Transparency = 1
		if tint then
			for _, p in placed:GetDescendants() do
				if p:IsA("BasePart") and p.Material ~= Enum.Material.Metal and p.Material ~= Enum.Material.Fabric then
					p.Color = PropKit.shade(def.color, p.Color.R + 0.3)
				end
			end
		end
	else
		decorate(model, body, def)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.4, 1, 2.4)
	seat.Color = Color3.fromRGB(45, 45, 55)
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.CanQuery = false
	seat.Massless = true
	-- Blender mowers have their seat spot 3 studs up and 1 stud back from the middle
	seat.CFrame = if placed then body.CFrame * CFrame.new(0, 2.3, 1) else body.CFrame * CFrame.new(0, 1.4, 2.2)
	if placed then
		seat.Transparency = 1
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = seat
	w.Part1 = body
	w.Parent = seat
	seat.Parent = model

	local att = Instance.new("Attachment")
	att.Name = "Root"
	att.Parent = body
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Drive"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.zero
	lv.MaxForce = 60000
	lv.Parent = body
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Steer"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e7
	ao.Responsiveness = 30
	ao.CFrame = Mowers.spawnCFrame.Rotation
	ao.Parent = body

	model.PrimaryPart = body
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("MowerId", def.id)
	model:SetAttribute("Speed", def.speed * require(script.Parent.ClassPerks).mower(player).speed) -- Turbo Deck
	if def.stripe then
		model:SetAttribute("Swath", def.stripe) -- (report #12) its lawn stripe's width (client/MowFx)
	end
	model:SetAttribute("Fuel", fuel)
	model:SetAttribute("MaxFuel", def.fuel)
	PropKit.billboard(body, def.name, Color3.fromRGB(255, 255, 255), Vector2.new(8, 1.6), Vector3.new(0, 5, 0), 80)
	model.Parent = folder

	-- only the owner may drive
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		if hum then
			local who = Players:GetPlayerFromCharacter(hum.Parent)
			if who ~= player then
				hum.Sit = false
				task.defer(function()
					hum.Jump = true
				end)
				if who then
					Net.notify(who, "That's " .. player.DisplayName .. "'s mower!", "red")
				end
				return
			end
			pcall(function()
				body:SetNetworkOwner(player)
			end)
		else
			lv.PlaneVelocity = Vector2.zero
			pcall(function()
				body:SetNetworkOwner(nil)
			end)
		end
	end)
	return model
end

function Mowers.despawn(player: Player)
	local m = active[player]
	if m then
		active[player] = nil
		m:Destroy()
	end
end

function Mowers.spawn(player: Player, id: string): boolean
	if Config.MOWERS_LOCKED then -- (30 Oct: the ride-on mowers are locked for the release, shared/Config MOWERS_LOCKED)
		Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
		return false
	end
	local data = PlayerData.get(player)
	local def = Config.mower(id)
	if not data or not data.run or not def or not Mowers.owns(data, id) then
		return false
	end
	Mowers.despawn(player)
	local fuel = data.run.fuel[id]
	if fuel == nil then
		fuel = def.fuel
		data.run.fuel[id] = fuel
	end
	active[player] = build(player, def, fuel)
	Net.send(player, "Fx", "mowerReady", { pos = Mowers.spawnCFrame.Position, name = def.name })
	return true
end

function Mowers.active(player: Player): Model?
	return active[player]
end

-- The mower this player is driving right now (seated in their own mower), or nil.
function Mowers.driving(player: Player): (Model?, any)
	local m = active[player]
	if not m then
		return nil, nil
	end
	local seat = m:FindFirstChild("Seat") :: VehicleSeat?
	local hum = seat and seat.Occupant
	if hum and hum.Parent == player.Character then
		return m, Config.mower(m:GetAttribute("MowerId"))
	end
	return nil, nil
end

-- Called every 0.5 s by the run: burn fuel while moving.
function Mowers.burn(dt: number)
	for player, m in active do
		-- (29 Oct) the Engine upgrade (Config.UPGRADES "engine", server/ClassPerks.mower) counts while you drive
		local mdef = Config.mower(m:GetAttribute("MowerId"))
		if mdef then
			local top = mdef.speed * require(script.Parent.ClassPerks).mower(player).speed
			if m:GetAttribute("Speed") ~= top then
				m:SetAttribute("Speed", top)
			end
		end
		local drivingModel = Mowers.driving(player)
		local body = m.PrimaryPart
		if drivingModel and body then
			local v = body.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > 3 then
				local fuel = math.max(0, (m:GetAttribute("Fuel") or 0) - dt * require(script.Parent.ClassPerks).mower(player).fuel)
				m:SetAttribute("Fuel", fuel)
				local data = PlayerData.get(player)
				if data and data.run then
					data.run.fuel[m:GetAttribute("MowerId")] = fuel
				end
				if fuel <= 0 then
					local lv = body:FindFirstChild("Drive") :: LinearVelocity?
					if lv then
						lv.PlaneVelocity = Vector2.zero
					end
				end
			end
		end
	end
end

-- Fill the player's mower at a pump. Returns fuel added.
function Mowers.refuel(player: Player, pumpPos: Vector3, pricePerFuel: number): number
	if Config.MOWERS_LOCKED then -- (30 Oct: gas is locked with the mowers, shared/Config MOWERS_LOCKED)
		Net.notify(player, Config.MOWERS_LOCKED_TEXT, "yellow")
		return 0
	end
	local data = PlayerData.get(player)
	local m = active[player]
	if not data or not data.run or not m or not m.PrimaryPart then
		Net.notify(player, "Spawn a mower at the Garage first!", "red")
		return 0
	end
	if (m.PrimaryPart.Position - pumpPos).Magnitude > 30 then
		Net.notify(player, "Park your mower next to the pump!", "red")
		return 0
	end
	local fuel = m:GetAttribute("Fuel") or 0
	local max = m:GetAttribute("MaxFuel") or 0
	local need = math.floor(max - fuel)
	if need <= 0 then
		Net.notify(player, "Your tank is already full!", "yellow")
		return 0
	end
	local affordable = math.floor(data.run.coins / pricePerFuel)
	local add = math.min(need, affordable)
	if add <= 0 then
		Net.notify(player, "Not enough coins for gas!", "red")
		return 0
	end
	data.run.coins -= add * pricePerFuel
	fuel += add
	m:SetAttribute("Fuel", fuel)
	data.run.fuel[m:GetAttribute("MowerId")] = fuel
	PlayerData.changed(player)
	Net.notify(player, "+" .. add .. " fuel", "green")
	return add
end

Players.PlayerRemoving:Connect(function(p)
	Mowers.despawn(p)
end)

return Mowers
