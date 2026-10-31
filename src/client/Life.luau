-- A world that moves (client): the wind you can see.
--   * Trees and bushes near you sway in the breeze, gusts rolling through them: the part-built ones (server/HubKit
--     Tree / Bush models) move their leaves about the top of the trunk, the voxel MeshParts (Tree_*, Bush_*, the
--     giant cherry and pine) turn about their foot. Everything always goes back to where the server put it.
--   * Wind ribbons: faint white streaks that curl through the air past you now and then.
--   * Leaves (petals, snowflakes, embers... by area) drift down from the canopy around you.
--   * A flock of birds flaps across the sky now and then.
-- Works in the lobby and in runs. Capped and cheap: nothing collides, nothing blocks clicks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Zones = require(Shared:WaitForChild("Zones"))
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local State = require(script.Parent.State)
local PhonePerf = require(script.Parent.PhonePerf)

local Life = {}
local player = Players.LocalPlayer

local WIND = Vector3.new(0.8, 0, 0.6).Unit -- where the wind blows to
local SWAY_RADIUS = 130 -- (Potato Mode: 60)
local SWAY_BUDGET = 400 -- swaying parts moved per frame at most (a part-built tree is about six leaf blocks)

local folder = Instance.new("Folder")
folder.Name = "Life"
folder.Parent = workspace

local function focus(): Vector3?
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position
end

-- gusts: a slow swell plus waves rolling across the land in the wind's direction
local function gust(pos: Vector3, t: number): number
	local along = pos:Dot(WIND)
	return 0.55 + 0.3 * math.sin(t * 0.35) + 0.35 * math.max(0, math.sin(along * 0.025 - t * 1.6))
end

-------------------------------------------------------------------------------------------------------------
-- swaying trees and bushes
-------------------------------------------------------------------------------------------------------------
type Sway = { part: BasePart, base: CFrame, foot: Vector3, amp: number, phase: number, last: CFrame? }
local sways: { [BasePart]: Sway } = {}
local swayList: { Sway } = {}
local swayCursor = 1

local function swayAmp(name: string): number?
	if string.sub(name, 1, 5) == "Tree_" then
		return math.rad(0.9)
	elseif string.sub(name, 1, 5) == "Bush_" then
		return math.rad(2)
	elseif name == "Landmark_cherry" or name == "Landmark_elderpine" then
		return math.rad(0.5)
	elseif name == "BuntingFlag" then
		return math.rad(14) -- the hubs' bunting flutters (it swings from its top edge)
	end
	return nil
end

-- A part-built tree or bush (server/HubKit: a Model named Tree or Bush): its leaves sway together about the top
-- of the trunk (a bush's about its foot), the trunk stays put.
local function trackModel(m: Model)
	local trunk = m:FindFirstChild("Trunk") :: BasePart?
	local pivot: Vector3
	local amp: number
	if trunk then
		pivot = trunk.Position + Vector3.new(0, trunk.Size.X / 2, 0) -- a trunk is an upright cylinder: its length is X
		amp = math.rad(3.2) * math.clamp(4 / trunk.Size.Y, 0.45, 1.2) -- thick (big) trees move less
	else
		local cf, size = m:GetBoundingBox()
		pivot = cf.Position - Vector3.new(0, size.Y / 2, 0)
		amp = math.rad(4.5)
	end
	local phase = (pivot.X * 0.37 + pivot.Z * 0.71) % (math.pi * 2)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and not sways[p] and (p.Name == "Leaves" or p.Name == "Flower") then
			local s: Sway = { part = p, base = p.CFrame, foot = pivot, amp = amp, phase = phase }
			sways[p] = s
			table.insert(swayList, s)
		end
	end
end

local function track(d: Instance)
	if d:IsA("Model") and (d.Name == "Tree" or d.Name == "Bush") then
		trackModel(d)
		return
	end
	if not d:IsA("BasePart") or sways[d] or not (d:IsA("MeshPart") or d.Name == "BuntingFlag") then
		return
	end
	local amp = swayAmp(d.Name)
	if not amp then
		return
	end
	local hang = d.Name == "BuntingFlag" -- turns about its top edge (the rope), not its foot
	local s: Sway = {
		part = d,
		base = d.CFrame,
		foot = if hang then d.Position + Vector3.new(0, d.Size.Y / 2, 0) else (d.CFrame * CFrame.new(0, -d.Size.Y / 2, 0)).Position,
		amp = if hang then amp else amp * math.clamp(30 / d.Size.Y, 0.5, 1.3), -- big trees move less
		phase = (d.Position.X * 0.37 + d.Position.Z * 0.71) % (math.pi * 2),
	}
	sways[d] = s
	table.insert(swayList, s)
end

local function watchWorld(world: Instance)
	for _, d in world:GetDescendants() do
		track(d)
	end
	world.DescendantAdded:Connect(track)
end

task.spawn(function()
	while true do
		local world = workspace:FindFirstChild("World")
		if world and not world:GetAttribute("LifeWatched") then
			world:SetAttribute("LifeWatched", true)
			table.clear(sways)
			table.clear(swayList)
			watchWorld(world)
		end
		task.wait(2)
	end
end)

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

-- Only what's near you sways: the near list is picked out of the whole list twice a second (walking every
-- leaf in the world each frame cost more than the swaying), and a part leaving it is put back home once.
local nearList: { Sway } = {}
local nearSet: { [Sway]: boolean } = {}
local nearAt: Vector3? = nil
local nearClock = 0
local function swayRadius(): number
	-- (29 Oct, phones: "stable 60 fps") a phone sways the trees near you only
	return if player:GetAttribute("Potato") then 60 elseif PhonePerf.on then 80 else SWAY_RADIUS
end
local function pickNear(at: Vector3)
	local r = swayRadius() + 20
	local fresh: { [Sway]: boolean } = {}
	table.clear(nearList)
	for _, s in swayList do
		if (s.foot - at).Magnitude <= r and s.part:IsDescendantOf(workspace) then
			table.insert(nearList, s)
			fresh[s] = true
		end
	end
	for s in nearSet do
		if not fresh[s] and s.last and s.last ~= s.base and s.part.Parent then
			table.insert(moveParts, s.part)
			table.insert(moveCFrames, s.base)
			s.last = s.base
		end
	end
	nearSet = fresh
end

local function swayStep(at: Vector3, t: number)
	if t - nearClock > 0.5 or not nearAt or (at - nearAt).Magnitude > 15 then
		nearClock = t
		nearAt = at
		pickNear(at)
	end
	local n = #nearList
	if n == 0 then
		return
	end
	local axis = Vector3.yAxis:Cross(WIND) -- tips lean downwind
	local radius = swayRadius()
	local budget = if player:GetAttribute("Potato") then 150 elseif PhonePerf.on then 180 else SWAY_BUDGET
	local done = 0
	local tries = 0
	while done < budget and tries < n do
		tries += 1
		if swayCursor > n then
			swayCursor = 1
		end
		local s = nearList[swayCursor]
		swayCursor += 1
		local p = s.part
		if not p.Parent then
			continue
		end
		-- someone else moved it (a rebuilt world, a cutscene): take its new place as home
		if s.last and (p.Position - s.last.Position).Magnitude > 0.5 then
			local shift = p.Position - s.last.Position
			s.base = p.CFrame
			if p.Name == "Leaves" or p.Name == "Flower" then
				s.foot += shift -- part of a tree that moved: keep its pivot with it
			else
				s.foot = if p.Name == "BuntingFlag" then p.Position + Vector3.new(0, p.Size.Y / 2, 0) else (p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)).Position
			end
		end
		local d = (s.foot - at).Magnitude
		local cf: CFrame
		if d > radius then
			if s.last == s.base then
				continue
			end
			cf = s.base
		else
			local fade = math.clamp((radius - d) / 30, 0, 1)
			local g = gust(s.foot, t)
			local angle = s.amp * fade * (g + 0.35 * math.sin(t * 1.9 + s.phase))
			cf = CFrame.new(s.foot) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-s.foot) * s.base
		end
		table.insert(moveParts, p)
		table.insert(moveCFrames, cf)
		s.last = cf
		done += 1
	end
end

-------------------------------------------------------------------------------------------------------------
-- wind ribbons
-------------------------------------------------------------------------------------------------------------
type Ribbon = { part: Part, trail: Trail, start: Vector3, t0: number, life: number, curl: number, seed: number, active: boolean }
local ribbons: { Ribbon } = {}

local function makeRibbon(): Ribbon
	local p = Instance.new("Part")
	p.Name = "WindRibbon"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(0, -500, 0)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.07, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.07, 0)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.7
	tr.LightEmission = 0
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1))
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.6), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	tr.Enabled = false
	tr.Parent = p
	p.Parent = folder
	return { part = p, trail = tr, start = Vector3.zero, t0 = 0, life = 0, curl = 0, seed = 0, active = false }
end

for _ = 1, 3 do
	table.insert(ribbons, makeRibbon())
end

-- after Potato Mode: only the ribbons in flight leave a trail
require(script.Parent.Potato).changed(function(on)
	if not on then
		for _, r in ribbons do
			r.trail.Enabled = r.active
		end
	end
end)

local function ribbonStep(at: Vector3, t: number)
	for _, r in ribbons do
		if not r.active then
			-- a new gust now and then, starting upwind of you
			if math.random() < 0.012 then
				local side = Vector3.yAxis:Cross(WIND)
				r.start = at - WIND * 45 + side * (math.random() * 60 - 30) + Vector3.new(0, math.random(2, 14), 0)
				r.t0 = t
				r.life = 2 + math.random()
				r.curl = if math.random() < 0.35 then 1 else 0
				r.seed = math.random() * 10
				r.active = true
				r.part.CFrame = CFrame.new(r.start)
				r.trail:Clear()
				r.trail.Enabled = true
			end
		else
			local k = (t - r.t0) / r.life
			if k >= 1 then
				r.active = false
				r.trail.Enabled = false
			else
				local side = Vector3.yAxis:Cross(WIND)
				local dist = k * 90
				local wob = math.sin(k * 6 + r.seed) * 2.5
				local pos = r.start + WIND * dist + side * wob + Vector3.new(0, math.sin(k * 4 + r.seed) * 1.5, 0)
				if r.curl > 0 and k > 0.4 and k < 0.6 then
					-- a little loop in the middle of the gust
					local a = (k - 0.4) / 0.2 * math.pi * 2
					pos += Vector3.new(0, (1 - math.cos(a)) * 2.5, 0) - WIND * math.sin(a) * 2.5
				end
				table.insert(moveParts, r.part)
				table.insert(moveCFrames, CFrame.new(pos))
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- leaves drifting down
-------------------------------------------------------------------------------------------------------------
local leafBox = Instance.new("Part")
leafBox.Name = "LeafBox"
leafBox.Anchored = true
leafBox.CanCollide = false
leafBox.CanQuery = false
leafBox.CanTouch = false
leafBox.Transparency = 1
leafBox.Size = Vector3.new(90, 1, 90)
leafBox.Parent = folder
local leaves = Instance.new("ParticleEmitter")
leaves.Texture = FxIds.splinter
leaves.Rate = 4 -- (was 10: leaves were always crossing the view; owner, 27 Oct: "cluttered")
leaves.Lifetime = NumberRange.new(6, 9)
leaves.Speed = NumberRange.new(0.5, 1.5)
leaves.SpreadAngle = Vector2.new(180, 180)
leaves.Acceleration = Vector3.new(WIND.X * 2.2, -1.6, WIND.Z * 2.2)
leaves.Drag = 0.6
leaves.Size = NumberSequence.new(0.45)
leaves.Rotation = NumberRange.new(0, 360)
leaves.RotSpeed = NumberRange.new(-160, 160)
leaves.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.05), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 1) })
leaves.LightInfluence = 1
leaves.Parent = leafBox

-- what drifts down in each area
local FALL = {
	meadow = { Color3.fromRGB(110, 190, 70), Color3.fromRGB(150, 210, 80) },
	wheat = { Color3.fromRGB(240, 150, 50), Color3.fromRGB(250, 200, 80) },
	blossom = { Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 230, 240) },
	pine = { Color3.fromRGB(80, 150, 100), Color3.fromRGB(140, 110, 70) },
	swamp = { Color3.fromRGB(120, 150, 60), Color3.fromRGB(90, 120, 50) },
	frost = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 240, 255) },
	ember = { Color3.fromRGB(70, 60, 64), Color3.fromRGB(255, 120, 40) },
	isles = { Color3.fromRGB(190, 150, 255), Color3.fromRGB(130, 240, 255) },
}
local fallId = ""
local function setFall(id: string)
	if id == fallId then
		return
	end
	fallId = id
	local c = FALL[id] or FALL.meadow
	leaves.Color = ColorSequence.new(c[1], c[2])
	leaves.LightEmission = if id == "ember" or id == "isles" then 0.6 else 0
end

-------------------------------------------------------------------------------------------------------------
-- a flock crossing the sky
-------------------------------------------------------------------------------------------------------------
type Bird = { body: Part, wings: { Part }, offset: Vector3, phase: number }
local flock: { Bird } = {}
local flockStart = Vector3.zero
local flockDir = WIND
local flockT0 = -100
local FLOCK_TIME = 22

local function voxel(size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = CFrame.new(0, -500, 0)
	p.Parent = folder
	return p
end

for i = 1, 7 do
	local row = math.ceil((i - 1) / 2)
	local sideN = if i == 1 then 0 elseif i % 2 == 0 then -1 else 1
	table.insert(flock, {
		body = voxel(Vector3.new(0.9, 0.7, 1.8), Color3.fromRGB(250, 250, 250)),
		wings = { voxel(Vector3.new(1.8, 0.2, 0.9), Color3.fromRGB(230, 230, 236)), voxel(Vector3.new(1.8, 0.2, 0.9), Color3.fromRGB(230, 230, 236)) },
		offset = Vector3.new(sideN * row * 4, row * 0.6, row * 4),
		phase = i * 0.7,
	})
end

local function flockStep(at: Vector3, t: number)
	local k = (t - flockT0) / FLOCK_TIME
	if k > 1 then
		if math.random() < 0.003 then
			local a = math.random() * math.pi * 2
			flockDir = Vector3.new(math.cos(a), 0, math.sin(a))
			flockStart = at - flockDir * 160 + Vector3.new(0, math.random(38, 60), 0) + Vector3.yAxis:Cross(flockDir) * (math.random() * 80 - 40)
			flockT0 = t
		end
		return
	end
	local lead = flockStart + flockDir * (k * 320)
	local look = CFrame.lookAt(lead, lead + flockDir)
	for _, b in flock do
		local base = look * CFrame.new(b.offset.X, b.offset.Y + math.sin(t * 1.3 + b.phase) * 0.6, b.offset.Z)
		local flap = math.sin(t * 9 + b.phase) * 0.7
		table.insert(moveParts, b.body)
		table.insert(moveCFrames, base)
		table.insert(moveParts, b.wings[1])
		table.insert(moveCFrames, base * CFrame.new(-0.4, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.9, 0, 0))
		table.insert(moveParts, b.wings[2])
		table.insert(moveCFrames, base * CFrame.new(0.4, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.9, 0, 0))
	end
end

-------------------------------------------------------------------------------------------------------------
local leafTick = 0
RunService.Heartbeat:Connect(function(dt)
	local at = focus()
	if not at then
		return
	end
	local t = os.clock()
	table.clear(moveParts)
	table.clear(moveCFrames)
	swayStep(at, t)
	ribbonStep(at, t)
	flockStep(at, t)
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	leafTick += dt
	if leafTick > 0.25 then
		leafTick = 0
		leafBox.CFrame = CFrame.new(at.X, at.Y + 22, at.Z) - WIND * 10
		local z = if State.isRun() then Zones.zoneAt(at) else 0
		local def = z and Zones.list[z]
		setFall(if def then def.id else "meadow")
	end
end)

return Life
