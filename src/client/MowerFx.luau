-- Ride-on mower life: turns the wheels and the blade, puffs exhaust smoke, and gives the special mowers an aura.
-- The server rigs the Blender mowers (server/Mowers `rig`): every tyre "Wheel<RL|RR|FL|FR>" and the "Blade" hang on
-- a Motor6D named "Spin"; "ExhaustTip" parts mark where smoke comes out. Motor6D.Transform is local to each client,
-- so every client turns every mower it can see (nothing is sent over the network).
--  * wheels roll with the mower's real speed, each side at its own speed when it turns (zero-turns spin in place)
--  * the blade spins up while someone sits in the seat and winds down when they get off
--  * exhaust: soft grey puffs, thicker while speeding up (orange heat on the Rocket's boosters)
--  * aura: paid mowers (Robux, Trial) get rising sparkles and a soft glow in their colour; gem mowers a few glints
--  * engine (29 Oct): a toy "putt-putt" loop (Config.SOUNDS.engine) while someone sits on it, pitched up with its speed
--    and a little more while it speeds up; it stops when they get off (silent while the id is empty)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Sound = require(script.Parent.Sound)
local okIds, FxIds = pcall(require, ReplicatedStorage.MowALawn:FindFirstChild("FxIds"))
local IDS = if okIds and type(FxIds) == "table" then FxIds else {}

local MowerFx = {}

local FAR = 220 -- studs: mowers further than this from the camera aren't animated
local BLADE_SPEED = 32 -- rad/s at full spin

type Wheel = { motor: Motor6D, radius: number, x: number, flip: number, angle: number }
type Ride = {
	model: Model,
	body: BasePart,
	seat: VehicleSeat?,
	wheels: { Wheel },
	blade: Motor6D?,
	bladeAngle: number,
	bladeRate: number,
	puffs: { ParticleEmitter },
	lastSpeed: number,
	fx: { Instance },
	engine: Sound?,
	enginePitch: number,
}

local rides: { [Model]: Ride } = {}

local function smokeEmitter(parent: Attachment, rocket: boolean): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "ExhaustPuff"
	e.Texture = IDS.smoke or IDS.poof or "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.7, 1.2)
	e.Speed = NumberRange.new(1.5, 3)
	e.SpreadAngle = Vector2.new(14, 14)
	e.Acceleration = Vector3.new(0, 2.5, 0)
	e.Drag = 2
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1.6) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	if rocket then
		e.Color = ColorSequence.new(Color3.fromRGB(255, 190, 120), Color3.fromRGB(150, 150, 160))
		e.LightEmission = 0.35
	else
		e.Color = ColorSequence.new(Color3.fromRGB(205, 205, 210), Color3.fromRGB(150, 150, 158))
		e.LightEmission = 0
	end
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

-- Rising sparkles + a soft glow in the mower's colour (paid), or a few glints (gem mowers).
local function aura(ride: Ride, color: Color3, strong: boolean)
	-- emitted from the invisible chassis box (about the mower's footprint), outward and drifting up
	local e = Instance.new("ParticleEmitter")
	e.Name = "AuraFx"
	e.Texture = IDS.spark or "rbxasset://textures/particles/sparkles_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Rate = if strong then 9 else 2.5
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(0.6, 1.4)
	e.Acceleration = Vector3.new(0, 1.6, 0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, if strong then 0.45 else 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.15)
	e.LightEmission = 0.8
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	e.Parent = ride.body
	table.insert(ride.fx, e)
	if strong then
		local light = Instance.new("PointLight")
		light.Name = "AuraFx"
		light.Color = color
		light.Brightness = 0.6
		light.Range = 9
		light.Shadows = false
		light.Parent = ride.body
		table.insert(ride.fx, light)
	end
end

local tries: { [Model]: number } = {}

local function track(model: Model)
	if rides[model] or not model.Parent then
		return
	end
	local body = model.PrimaryPart or model:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local ride: Ride = {
		model = model,
		body = body,
		seat = model:FindFirstChild("Seat") :: VehicleSeat?,
		wheels = {},
		blade = nil,
		bladeAngle = 0,
		bladeRate = 0,
		puffs = {},
		lastSpeed = 0,
		fx = {},
		engine = nil,
		enginePitch = 0.9,
	}
	local rocket = model:GetAttribute("MowerId") == "RocketMower"
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == "Spin" and d.Part1 then
			local p = d.Part1
			if p.Name == "Blade" then
				ride.blade = d
			else
				-- a cylinder's axle is its X axis; roll it forward whichever way that axis points
				local flip = if p.CFrame.RightVector:Dot(body.CFrame.RightVector) >= 0 then 1 else -1
				table.insert(ride.wheels, { motor = d, radius = math.max(p.Size.Y / 2, 0.3), x = d.C0.Position.X, flip = flip, angle = 0 })
			end
		elseif d:IsA("BasePart") and d.Name == "ExhaustTip" then
			local att = Instance.new("Attachment")
			att.Name = "ExhaustFx"
			att.Parent = d
			table.insert(ride.fx, att)
			table.insert(ride.puffs, smokeEmitter(att, rocket))
		end
	end
	-- the parts can arrive a little after the model: look again shortly (a few times) if nothing turned up
	if #ride.wheels == 0 and not ride.blade and #ride.puffs == 0 and (tries[model] or 0) < 5 then
		tries[model] = (tries[model] or 0) + 1
		for _, f in ride.fx do
			f:Destroy()
		end
		task.delay(1, track, model)
		return
	end
	tries[model] = nil
	local def = Config.mower(model:GetAttribute("MowerId"))
	if def then
		if def.currency == "robux" or def.currency == "trial" then
			aura(ride, def.color, true)
		elseif def.currency == "gems" then
			aura(ride, def.color, false)
		end
	end
	rides[model] = ride
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			rides[model] = nil
		end
	end)
end

-- The engine loop: on while someone rides and the mower is near the camera; idle pitch 0.9, up to about 1.35 at
-- 40 studs/s, a little higher while speeding up (smoothed so it doesn't wobble).
local function engine(ride: Ride, on: boolean, speed: number, accel: number, dt: number)
	if not on then
		if ride.engine then
			ride.engine:Destroy()
			ride.engine = nil
		end
		return
	end
	if not ride.engine then
		ride.engine = Sound.loop("engine", ride.body)
		ride.enginePitch = 0.9
		if not ride.engine then
			return
		end
	end
	local s = ride.engine :: Sound
	local k = math.clamp(speed / 40, 0, 1)
	local want = 0.9 + 0.45 * k + math.min(accel, 30) * 0.004
	ride.enginePitch += (want - ride.enginePitch) * math.min(1, dt * 4)
	s.PlaybackSpeed = ride.enginePitch
	s.Volume = ((Config.SOUNDS.engine or {}).volume or 0.3) * (0.75 + 0.25 * k)
end

local function step(dt: number)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, ride in rides do
		local body = ride.body
		if not body.Parent then
			rides[model] = nil
			continue
		end
		local cf = body.CFrame
		local near = (cf.Position - camPos).Magnitude < FAR
		local vel = body.AssemblyLinearVelocity
		local spin = cf:VectorToObjectSpace(body.AssemblyAngularVelocity).Y
		local forward = vel:Dot(cf.LookVector)
		local seated = ride.seat ~= nil and ride.seat.Occupant ~= nil
		if near then
			for _, w in ride.wheels do
				-- each wheel's ground speed: the mower's speed plus its share of the turn
				local v = forward + spin * w.x
				w.angle = (w.angle - w.flip * v / w.radius * dt) % (math.pi * 2)
				w.motor.Transform = CFrame.Angles(w.angle, 0, 0)
			end
			if ride.blade then
				local target = if seated then BLADE_SPEED else 0
				ride.bladeRate += (target - ride.bladeRate) * math.min(1, dt * (if seated then 1.5 else 0.8))
				ride.bladeAngle = (ride.bladeAngle + ride.bladeRate * dt) % (math.pi * 2)
				ride.blade.Transform = CFrame.Angles(ride.bladeAngle, 0, 0)
			end
		end
		-- exhaust: idle puffs while seated, more while speeding up; none when parked and empty or far away
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local accel = math.max(0, speed - ride.lastSpeed) / math.max(dt, 1e-3)
		ride.lastSpeed = speed
		local rate = if near and seated then 3 + math.min(speed, 40) * 0.12 + math.min(accel, 40) * 0.25 else 0
		for _, e in ride.puffs do
			e.Rate = rate
		end
		engine(ride, near and seated, speed, accel, dt)
	end
end

function MowerFx.start()
	local function check(d: Instance)
		if d:IsA("Model") and d:GetAttribute("MowerId") then
			task.defer(track, d)
		end
	end
	for _, d in workspace:GetDescendants() do
		check(d)
	end
	workspace.DescendantAdded:Connect(check)
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

MowerFx.start()

return MowerFx
