-- Ride-on mowers: spawned at the garage pad, only the owner can drive, burn fuel while moving.
-- The driver's client steers (see client Drive); the server owns fuel and cutting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PlayerData = require(script.Parent.PlayerData)
local Net = require(script.Parent.Net)
local PropKit = require(script.Parent.PropKit)

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

local function decorate(model: Model, body: BasePart, def)
	local function add(size: Vector3, offset: CFrame, color: Color3, name: string, neon: boolean?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
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
	local dark = Color3.fromRGB(40, 40, 48)
	add(Vector3.new(5.6, 1.4, 3), CFrame.new(0, 1.3, -2.2), PropKit.shade(def.color, 1.1), "Hood")
	add(Vector3.new(6.2, 0.6, 2.2), CFrame.new(0, -0.4, -3.4), dark, "Deck")
	for _, x in { -2.8, 2.8 } do
		for _, z in { -2.4, 2.4 } do
			local wheel = add(Vector3.new(1, 2, 2), CFrame.new(x, -0.3, z), dark, "Wheel")
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	add(Vector3.new(0.4, 2.6, 0.4), CFrame.new(-1.2, 1.6, 0.3), dark, "SteerPost")
	add(Vector3.new(2.4, 0.3, 0.3), CFrame.new(-1.2, 2.9, 0.3), dark, "SteerBar")
	add(Vector3.new(1.4, 0.4, 0.8), CFrame.new(0, 0.8, -3.75), Color3.fromRGB(255, 255, 255), "Headlight", true)
end

local function build(player: Player, def, fuel: number): Model
	local model = Instance.new("Model")
	model.Name = player.Name .. "'s " .. def.name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(5.4, 1.6, 7.4)
	body.Color = def.color
	body.TopSurface = Enum.SurfaceType.Studs
	body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0, 0, 100, 1)
	body.CFrame = Mowers.spawnCFrame
	body.Parent = model
	decorate(model, body, def)

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.4, 1, 2.4)
	seat.Color = Color3.fromRGB(45, 45, 55)
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.CanQuery = false
	seat.Massless = true
	seat.CFrame = body.CFrame * CFrame.new(0, 1.3, 1.4)
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
	model:SetAttribute("Speed", def.speed)
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
	Net.notify(player, def.name .. " is waiting at the mower pad!", "green")
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
		local drivingModel = Mowers.driving(player)
		local body = m.PrimaryPart
		if drivingModel and body then
			local v = body.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > 3 then
				local fuel = math.max(0, (m:GetAttribute("Fuel") or 0) - dt)
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
