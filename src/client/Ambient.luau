-- Little life in the world, like the trailer's cardinal: red birds hop around the grass, peck, and flutter
-- away when you come close. Butterflies wander around you and rest on the grass clumps, pollen and dandelion
-- seeds drift in the sun, fireflies glow in the swamp and the jungle, and dragonflies dart over the swamp.
-- Client-only decoration: capped, nothing collides, nothing blocks clicks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local State = require(script.Parent.State)
local Wind = require(script.Parent.Wind)
local ZoneMood = require(script.Parent.ZoneMood)

local Ambient = {}
local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "Birds"
folder.Parent = workspace

local RED = Color3.fromRGB(205, 35, 40)

local function part(parent: Instance, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

type Bird = { model: Model, pieces: { { part: BasePart, offset: CFrame } }, pos: Vector3, yaw: number, state: string, timer: number, vel: Vector3 }

local function makeBird(): Bird
	local m = Instance.new("Model")
	m.Name = "Cardinal"
	local pieces = {}
	local function add(size: Vector3, offset: CFrame, color: Color3)
		table.insert(pieces, { part = part(m, size, color), offset = offset })
	end
	add(Vector3.new(0.8, 0.7, 1.1), CFrame.new(0, 0.55, 0), RED) -- body
	add(Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1.05, -0.45), RED) -- head
	add(Vector3.new(0.25, 0.4, 0.35), CFrame.new(0, 1.45, -0.35) * CFrame.Angles(math.rad(-20), 0, 0), RED) -- crest
	add(Vector3.new(0.62, 0.3, 0.2), CFrame.new(0, 1.0, -0.72), Color3.fromRGB(25, 20, 25)) -- mask
	add(Vector3.new(0.22, 0.2, 0.3), CFrame.new(0, 0.98, -0.88), Color3.fromRGB(255, 150, 40)) -- beak
	add(Vector3.new(0.12, 0.12, 0.12), CFrame.new(0.2, 1.12, -0.76), Color3.new(1, 1, 1)) -- eye
	add(Vector3.new(0.12, 0.12, 0.12), CFrame.new(-0.2, 1.12, -0.76), Color3.new(1, 1, 1))
	add(Vector3.new(0.5, 0.15, 0.7), CFrame.new(0, 0.45, 0.75) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(160, 25, 30)) -- tail
	add(Vector3.new(0.12, 0.3, 0.12), CFrame.new(0.18, 0.15, 0), Color3.fromRGB(80, 60, 50)) -- legs
	add(Vector3.new(0.12, 0.3, 0.12), CFrame.new(-0.18, 0.15, 0), Color3.fromRGB(80, 60, 50))
	m.Parent = folder
	return { model = m, pieces = pieces, pos = Vector3.zero, yaw = 0, state = "idle", timer = 0, vel = Vector3.zero }
end

local birds: { Bird } = {}

-- where birds can live: the hub / first zone in a run, the plaza edge in the lobby
local function randomSpot(): Vector3
	if State.mode == "Run" then
		local zone = (State.world and State.world.zone) or 1
		local zs = Config.zoneStartZ(zone)
		return Vector3.new(math.random(-40, 40), 0, math.random(math.floor(zs - 30), math.floor(zs + 80)))
	end
	local a = math.random() * math.pi * 2
	local r = math.random(30, 75)
	return Vector3.new(math.cos(a) * r, 0.4, math.sin(a) * r)
end

for _ = 1, 6 do
	local b = makeBird()
	b.pos = randomSpot()
	b.yaw = math.random() * math.pi * 2
	b.timer = math.random() * 2
	table.insert(birds, b)
end

local lastMode = State.mode
RunService.Heartbeat:Connect(function(dt)
	if State.mode ~= lastMode then
		lastMode = State.mode
		for _, b in birds do
			b.pos = randomSpot()
			b.state = "idle"
		end
	end
	local char = player.Character
	local me = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local t = os.clock()
	for _, b in birds do
		b.timer -= dt
		local hop = 0
		local peck = 0
		if b.state == "fly" then
			b.pos += b.vel * dt
			b.vel += Vector3.new(0, 4 * dt, 0)
			if b.timer <= 0 then
				b.pos = randomSpot()
				b.state = "idle"
				b.timer = 1
			end
		else
			if me and (me.Position - b.pos).Magnitude < 12 then
				-- startled: flutter up and away from the player
				local away = Vector3.new(b.pos.X - me.Position.X, 0, b.pos.Z - me.Position.Z)
				away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
				b.vel = away * 18 + Vector3.new(0, 10, 0)
				b.yaw = math.atan2(-away.X, -away.Z)
				b.state = "fly"
				b.timer = 3
			elseif b.state == "hop" then
				local k = 1 - math.max(0, b.timer) / 0.35
				hop = math.sin(k * math.pi) * 0.8
				b.pos += CFrame.Angles(0, b.yaw, 0).LookVector * dt * 6
				if b.timer <= 0 then
					b.state = "idle"
					b.timer = 0.5 + math.random() * 1.5
				end
			else
				peck = if math.sin(t * 9 + b.yaw) > 0.7 then 1 else 0
				if b.timer <= 0 then
					b.state = "hop"
					b.yaw += (math.random() - 0.5) * 2
					b.timer = 0.35
				end
			end
		end
		local flap = if b.state == "fly" then math.sin(t * 40) * 0.3 else 0
		local base = CFrame.new(b.pos + Vector3.new(0, 0.3 + hop, 0)) * CFrame.Angles(0, b.yaw, 0)
		for i, pc in b.pieces do
			local cf = base * pc.offset
			if peck > 0 and i >= 2 and i <= 7 then
				cf = base * CFrame.new(0, -0.25, -0.15) * pc.offset
			end
			if flap ~= 0 and i == 1 then
				cf = cf * CFrame.Angles(0, 0, flap)
			end
			pc.part.CFrame = cf
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- Butterflies, dragonflies, drifting pollen / dandelion seeds and fireflies (all around the local player)
-------------------------------------------------------------------------------------------------------------
local life = Instance.new("Folder")
life.Name = "AmbientLife"
life.Parent = workspace

local HIDDEN = CFrame.new(0, -500, 0)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GLOW = FxIds.glow or SPARKLE
local BUTTERFLY_COLORS = {
	Color3.fromRGB(255, 212, 50), -- sunny yellow
	Color3.fromRGB(70, 160, 255), -- sky blue
	Color3.fromRGB(255, 125, 35), -- orange
}
local SWAMP_ZONE = 0 -- dragonflies live here
for i, def in Config.ZONES do
	if def.style == "reeds" then
		SWAMP_ZONE = i
	end
end

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

-- every critter part is moved in one BulkMoveTo per frame
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local function queue(p: BasePart, cf: CFrame)
	table.insert(moveParts, p)
	table.insert(moveCFrames, cf)
end

-- A random point around `at` (inside the run's side walls), `y0..y1` above the ground.
local function around(at: Vector3, r0: number, r1: number, y0: number, y1: number): Vector3
	local a = math.random() * math.pi * 2
	local r = rand(r0, r1)
	local x = at.X + math.cos(a) * r
	if State.isRun() then
		x = math.clamp(x, -46, 46)
	end
	return Vector3.new(x, at.Y - 3 + rand(y0, y1), at.Z + math.sin(a) * r)
end

-- A wing hinged on the body's long axis: side = 1 right, -1 left; `flap` lifts it (radians).
type Wing = { part: BasePart, side: number, z: number, half: number }
local function wing(m: Instance, side: number, size: Vector3, z: number, color: Color3): Wing
	return { part = part(m, size, color), side = side, z = z, half = size.X / 2 }
end
local function placeWing(w: Wing, base: CFrame, flap: number)
	queue(w.part, base * CFrame.new(0, 0, w.z) * CFrame.Angles(0, 0, w.side * flap) * CFrame.new(w.side * w.half, 0, 0))
end

---------------------------------------------------------------------------- butterflies
type Butterfly = { body: BasePart, wings: { Wing }, pos: Vector3, vel: Vector3, yaw: number, target: Vector3, perch: boolean, resting: boolean, timer: number, phase: number }
local butterflies: { Butterfly } = {}
for i = 1, 7 do
	local color = BUTTERFLY_COLORS[(i - 1) % #BUTTERFLY_COLORS + 1]
	local hind = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local m = Instance.new("Model")
	m.Name = "Butterfly"
	local b: Butterfly = {
		body = part(m, Vector3.new(0.14, 0.14, 0.7), Color3.fromRGB(45, 35, 30)),
		wings = {
			wing(m, 1, Vector3.new(0.7, 0.05, 0.55), -0.12, color),
			wing(m, -1, Vector3.new(0.7, 0.05, 0.55), -0.12, color),
			wing(m, 1, Vector3.new(0.5, 0.05, 0.42), 0.24, hind),
			wing(m, -1, Vector3.new(0.5, 0.05, 0.42), 0.24, hind),
		},
		pos = HIDDEN.Position,
		vel = Vector3.zero,
		yaw = 0,
		target = HIDDEN.Position,
		perch = false,
		resting = false,
		timer = 0,
		phase = math.random() * 10,
	}
	m.Parent = life
	table.insert(butterflies, b)
end

-- Next place to go: often a grass clump to rest on, otherwise somewhere in the air near you.
local function nextTarget(b: Butterfly, at: Vector3)
	local perch = if math.random() < 0.35 then Wind.perch() else nil
	if perch and (perch - at).Magnitude > 5 then
		b.target = perch + Vector3.new(0, 0.15, 0)
		b.perch = true
	else
		b.target = around(at, 6, 24, 1.5, 5)
		b.perch = false
	end
end

local function updateButterfly(b: Butterfly, dt: number, t: number, at: Vector3)
	if (b.pos - at).Magnitude > 55 then
		-- wandered off (or just spawned): come back in from somewhere around you
		b.pos = around(at, 24, 34, 2, 5)
		b.resting = false
		nextTarget(b, at)
	end
	local flap
	if b.resting then
		b.timer -= dt
		flap = 1.25 + math.sin(t * 1.6 + b.phase) * 0.3 -- wings up, slowly opening and closing
		if b.timer <= 0 or (b.pos - at).Magnitude < 4.5 then
			b.resting = false
			b.vel = Vector3.new(0, 3, 0)
			nextTarget(b, at)
		end
	else
		flap = 0.2 + math.sin(t * 20 + b.phase) * 0.95
		local to = b.target - b.pos
		local d = to.Magnitude
		if d < (if b.perch then 0.3 else 1.5) then
			if b.perch then
				b.resting = true
				b.timer = rand(3, 9)
				b.pos = b.target
				b.vel = Vector3.zero
			else
				nextTarget(b, at)
			end
		else
			-- a fluttery path: head for the target with a wandering sideways wobble
			local wobble = Vector3.new(math.noise(t * 0.7, b.phase), math.noise(b.phase, t * 0.9) * 0.6, math.noise(t * 0.7, b.phase + 5))
			local speed = if b.perch and d < 3 then 1.8 else 4.2
			local want = (to.Unit + wobble * (if b.perch and d < 3 then 0.2 else 0.9)).Unit * speed
			b.vel = b.vel:Lerp(want, math.min(1, dt * 2))
			b.pos += b.vel * dt
			if b.vel.X * b.vel.X + b.vel.Z * b.vel.Z > 0.05 then
				b.yaw = math.atan2(-b.vel.X, -b.vel.Z)
			end
		end
	end
	local bob = if b.resting then 0 else math.sin(t * 5 + b.phase) * 0.12
	local base = CFrame.new(b.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, b.yaw, 0)
	queue(b.body, base)
	for _, w in b.wings do
		placeWing(w, base, flap)
	end
end

---------------------------------------------------------------------------- dragonflies (swamp)
type Dragonfly = { parts: { BasePart }, wings: { Wing }, pos: Vector3, from: Vector3, target: Vector3, yaw: number, timer: number, dur: number, darting: boolean, phase: number }
local dragonflies: { Dragonfly } = {}
for i = 1, 4 do
	local m = Instance.new("Model")
	m.Name = "Dragonfly"
	local bodyColor = if i % 2 == 0 then Color3.fromRGB(40, 190, 185) else Color3.fromRGB(70, 120, 230)
	local wingColor = Color3.fromRGB(215, 240, 255)
	local wings = {
		wing(m, 1, Vector3.new(0.95, 0.03, 0.2), -0.12, wingColor),
		wing(m, -1, Vector3.new(0.95, 0.03, 0.2), -0.12, wingColor),
		wing(m, 1, Vector3.new(0.85, 0.03, 0.18), 0.12, wingColor),
		wing(m, -1, Vector3.new(0.85, 0.03, 0.18), 0.12, wingColor),
	}
	for _, w in wings do
		w.part.Transparency = 0.45
	end
	table.insert(dragonflies, {
		parts = {
			part(m, Vector3.new(0.12, 0.12, 1.3), bodyColor), -- body (tail toward +Z)
			part(m, Vector3.new(0.26, 0.24, 0.26), bodyColor:Lerp(Color3.new(0, 0, 0), 0.3)), -- head
		},
		wings = wings,
		pos = HIDDEN.Position,
		from = HIDDEN.Position,
		target = HIDDEN.Position,
		yaw = 0,
		timer = 0,
		dur = 1,
		darting = false,
		phase = math.random() * 10,
	})
	m.Parent = life
end

local dragonsHidden = false
local function updateDragonfly(f: Dragonfly, dt: number, t: number, at: Vector3)
	if (f.pos - at).Magnitude > 40 then
		f.pos = around(at, 10, 20, 1.5, 4.5)
		f.darting = false
		f.timer = rand(0.3, 1.5)
	end
	f.timer -= dt
	if f.darting then
		-- quick dart, easing out
		local k = 1 - math.max(0, f.timer) / f.dur
		f.pos = f.from:Lerp(f.target, 1 - (1 - k) * (1 - k))
		if f.timer <= 0 then
			f.darting = false
			f.timer = rand(0.5, 2.2)
		end
	elseif f.timer <= 0 then
		local to = around(f.pos, 3, 10, 1.5, 4.5)
		if (to - at).Magnitude > 22 then
			to = around(at, 4, 16, 1.5, 4.5)
		end
		f.from, f.target = f.pos, Vector3.new(to.X, at.Y - 3 + math.clamp(to.Y - (at.Y - 3), 1.5, 4.5), to.Z)
		f.dur = math.max(0.15, (f.target - f.from).Magnitude / 22)
		f.timer = f.dur
		f.darting = true
		local dir = f.target - f.from
		f.yaw = math.atan2(-dir.X, -dir.Z)
	end
	local hover = if f.darting then 0 else math.sin(t * 7 + f.phase) * 0.08
	local base = CFrame.new(f.pos + Vector3.new(0, hover, 0)) * CFrame.Angles(0, f.yaw, 0)
	queue(f.parts[1], base * CFrame.new(0, 0, 0.35))
	queue(f.parts[2], base * CFrame.new(0, 0, -0.42))
	local flap = math.sin(t * 55 + f.phase) * 0.35
	for i, w in f.wings do
		placeWing(w, base, if i <= 2 then flap else -flap)
	end
end

---------------------------------------------------------------------------- motes: pollen, seeds, fireflies
-- Invisible boxes that follow you; their particles stay in the world (not locked), so you walk through them.
local function moteBox(size: Vector3): Part
	local p = part(life, size, Color3.new(1, 1, 1))
	p.Name = "MoteBox"
	p.Transparency = 1
	return p
end
local function emitter(parent: Instance, texture: string, color: Color3, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, size),
		NumberSequenceKeypoint.new(0.85, size * 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.WindAffectsDrag = true -- drifts with workspace.GlobalWind (set in Environment)
	e.Parent = parent
	return e
end
local highBox = moteBox(Vector3.new(80, 12, 80))
local lowBox = moteBox(Vector3.new(44, 5, 44))

local pollen = emitter(highBox, GLOW, Color3.fromRGB(255, 244, 196), 0.13)
pollen.LightEmission = 0.6
pollen.LightInfluence = 0.4
pollen.Transparency = NumberSequence.new(0.15)
pollen.Lifetime = NumberRange.new(6, 10)
pollen.Speed = NumberRange.new(0.15, 0.5)
pollen.Drag = 0.6
pollen.Acceleration = Vector3.new(0, 0.03, 0)

local seeds = emitter(highBox, SPARKLE, Color3.fromRGB(255, 255, 250), 0.26)
seeds.LightEmission = 0.25
seeds.LightInfluence = 0.6
seeds.Transparency = NumberSequence.new(0.1)
seeds.Lifetime = NumberRange.new(9, 13)
seeds.Speed = NumberRange.new(0.3, 0.7)
seeds.Drag = 0.4
seeds.Acceleration = Vector3.new(0, -0.02, 0)

local fireflies = emitter(lowBox, GLOW, Color3.fromRGB(215, 255, 110), 0.3)
fireflies.LightEmission = 1
fireflies.LightInfluence = 0
fireflies.Brightness = 2
fireflies.Lifetime = NumberRange.new(4, 7)
fireflies.Speed = NumberRange.new(0.3, 0.9)
fireflies.Drag = 0.8
fireflies.WindAffectsDrag = false
fireflies.Acceleration = Vector3.new(0, 0.05, 0)
-- blinking: the glow swells and fades a few times over its life
fireflies.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.12, 0.32),
	NumberSequenceKeypoint.new(0.25, 0.04),
	NumberSequenceKeypoint.new(0.42, 0.34),
	NumberSequenceKeypoint.new(0.58, 0.05),
	NumberSequenceKeypoint.new(0.75, 0.3),
	NumberSequenceKeypoint.new(1, 0),
})

-- per zone: { pollen rate, pollen colour, seed rate, firefly rate }
local MOTES: { [string]: { any } } = {
	base = { 14, Color3.fromRGB(255, 244, 196), 3, 0 },
	wheat = { 26, Color3.fromRGB(255, 220, 130), 2, 0 }, -- golden chaff in the air
	reeds = { 6, Color3.fromRGB(220, 245, 230), 0, 10 },
	jungle = { 18, Color3.fromRGB(215, 255, 175), 1, 8 }, -- spores
}
local moteZone = -1
local function setMotes(zone: number)
	moteZone = zone
	local def = Config.ZONES[zone]
	local m = (def and MOTES[def.style]) or MOTES.base
	pollen.Rate = m[1]
	pollen.Color = ColorSequence.new(m[2])
	seeds.Rate = m[3]
	fireflies.Rate = m[4]
end

local function focusPos(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return root.Position
	end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position
end

RunService.Heartbeat:Connect(function(dt)
	local at = focusPos()
	if not at then
		return
	end
	local t = os.clock()
	local zone = if State.isRun() then ZoneMood.zone else 0
	if zone ~= moteZone then
		setMotes(zone)
	end
	local ground = at.Y - 3
	highBox.CFrame = CFrame.new(at.X, ground + 6, at.Z)
	lowBox.CFrame = CFrame.new(at.X, ground + 2.8, at.Z)

	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, b in butterflies do
		updateButterfly(b, dt, t, at)
	end
	if zone ~= 0 and zone == SWAMP_ZONE then
		dragonsHidden = false
		for _, f in dragonflies do
			updateDragonfly(f, dt, t, at)
		end
	elseif not dragonsHidden then
		dragonsHidden = true
		for _, f in dragonflies do
			f.pos = HIDDEN.Position
			for _, p in f.parts do
				queue(p, HIDDEN)
			end
			for _, w in f.wings do
				queue(w.part, HIDDEN)
			end
		end
	end
	workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)

return Ambient
