-- Little life in the world, like the trailer's cardinal: red birds hop around the grass, peck, and flutter
-- away when you come close. Client-only decoration.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local State = require(script.Parent.State)

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

return Ambient
