-- The area camps come alive (owner, 29 Oct: "make it feel more alive and not so boring"): server/CampDress tags
-- what moves and this animates it here, only near the camera (the parts are the server's, moved on this client):
--   * CampSpin: a group turning round an axis (the windmill's sails);
--   * CampSway: groups swaying in the wind (banners, the watchtower's flag);
--   * CampSweep: the telescope slowly panning the sky; CampPump: the forge's bellows;
--   * CampBob: bobbing (the rowing boat, floating crystals);
--   * CampCritter: chickens, frogs, koi, owls, penguins, salamanders, wisps going about their day;
--   * CampVillager: gnome villagers who walk their round, sit by the fire, work (rake, water, chop, fish, shovel,
--     hammer, stargaze), turn to look at you, wave when you come near and say a line (Config.CAMP_LINES).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local player = Players.LocalPlayer
local NEAR = 150 -- animate within this many studs of the camera
local TAGS = { "CampSpin", "CampSway", "CampSweep", "CampPump", "CampBob", "CampCritter", "CampVillager" }

type Rig = {
	model: Model,
	kind: string,
	base: CFrame,
	parts: { BasePart },
	offs: { CFrame },
	group: { string? }, -- each part's group
	pivots: { [string]: CFrame }, -- group -> its pivot in the model's space
	gx: { [string]: CFrame }, -- this frame's turn of each group (about its pivot)
	moves: { string }, -- the groups its Group_<name> attributes name
	dead: boolean?,
	root: CFrame, -- this frame's model frame
	t0: number,
	rng: Random,
	active: boolean,
	state: { [string]: any },
}

local rigs: { [Model]: Rig } = {}
local active: { Rig } = {}

local function attr(m: Instance, k: string, default: any): any
	local v = m:GetAttribute(k)
	if v == nil then
		return default
	end
	return v
end

local function build(m: Model, kind: string): Rig?
	local parts, offs, group = {}, {}, {}
	local base = m:GetPivot()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offs, base:ToObjectSpace(d.CFrame))
			local g = d:GetAttribute("G")
			-- set by the part's own index: table.insert(group, nil) adds nothing, which slid every later group name
			-- onto the wrong part (the windmill's tower turned with its sails, villagers' arms moved as heads)
			group[#parts] = if type(g) == "string" then g else nil
		end
	end
	if #parts == 0 then
		return nil
	end
	local want = m:GetAttribute("NParts")
	if type(want) == "number" and #parts < want then
		return nil -- not all streamed in yet
	end
	local pivots = {}
	for k, v in m:GetAttributes() do
		if string.sub(k, 1, 6) == "Pivot_" and typeof(v) == "Vector3" then
			pivots[string.sub(k, 7)] = CFrame.new(v)
		end
	end
	local seed = attr(m, "Seed", math.random(1, 9999))
	local moves = {}
	for k, v in m:GetAttributes() do
		if string.sub(k, 1, 6) == "Group_" and v == true then
			table.insert(moves, string.sub(k, 7))
		end
	end
	return {
		model = m,
		kind = kind,
		base = base,
		parts = parts,
		offs = offs,
		group = group,
		pivots = pivots,
		gx = {},
		moves = moves,
		root = base,
		t0 = os.clock() + (seed % 100) * 0.13,
		rng = Random.new(seed),
		active = false,
		state = {},
	}
end

-- group g turned by `rot` (in the model's axes) about its pivot
local function turn(r: Rig, g: string, rot: CFrame)
	local p = r.pivots[g]
	if p then
		r.gx[g] = p * rot * p:Inverse()
	end
end

local pl: { BasePart } = {}
local cfs: { CFrame } = {}
local function apply(r: Rig)
	table.clear(pl)
	table.clear(cfs)
	for i, p in r.parts do
		local g = r.group[i]
		local x = g and r.gx[g]
		pl[i] = p
		cfs[i] = if x then r.root * x * r.offs[i] else r.root * r.offs[i]
	end
	workspace:BulkMoveTo(pl, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function playerRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function yawTo(from: Vector3, to: Vector3): number?
	local d = flat(to - from)
	if d.Magnitude < 0.05 then
		return nil
	end
	return math.atan2(-d.X, -d.Z) -- the yaw that turns -Z (the front) toward d
end

local function lerpAngle(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * math.clamp(k, 0, 1)
end

-------------------------------------------------------------------------------------------------------------
-- speech bubbles
-------------------------------------------------------------------------------------------------------------
local lastTalk = 0
local function say(r: Rig, text: string)
	local head: BasePart? = nil
	for i, p in r.parts do
		if r.group[i] == "Head" and (not head or p.Size.Magnitude > head.Size.Magnitude) then
			head = p
		end
	end
	if not head then
		return
	end
	local old = head:FindFirstChild("Talk")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Talk"
	bb.Size = UDim2.fromOffset(230, 56)
	bb.StudsOffset = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 48
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = Color3.fromRGB(255, 250, 238)
	box.BackgroundTransparency = 1
	box.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(70, 46, 30)
	stroke.Transparency = 1
	stroke.Parent = box
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -16, 1, -10)
	t.Position = UDim2.fromOffset(8, 5)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(70, 46, 30)
	t.TextTransparency = 1
	t.Text = text
	t.Parent = box
	bb.Parent = head
	local inInfo = TweenInfo.new(0.25)
	TweenService:Create(box, inInfo, { BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(stroke, inInfo, { Transparency = 0 }):Play()
	TweenService:Create(t, inInfo, { TextTransparency = 0 }):Play()
	task.delay(3.6, function()
		if bb.Parent then
			local outInfo = TweenInfo.new(0.4)
			TweenService:Create(box, outInfo, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(stroke, outInfo, { Transparency = 1 }):Play()
			TweenService:Create(t, outInfo, { TextTransparency = 1 }):Play()
			task.wait(0.45)
			bb:Destroy()
		end
	end)
end

local function lineFor(r: Rig): string?
	local lines = Config.CAMP_LINES
	if type(lines) ~= "table" then
		return nil
	end
	local list = lines[attr(r.model, "Area", "")] or lines.any
	if type(list) ~= "table" or #list == 0 then
		return nil
	end
	local n = r.state.line or r.rng:NextInteger(1, #list)
	r.state.line = n % #list + 1
	return list[n]
end

-------------------------------------------------------------------------------------------------------------
-- the movers
-------------------------------------------------------------------------------------------------------------
local function groupsOf(r: Rig): { string }
	return r.moves
end

local function sparks(at: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(at)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 120, 40))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.25, 0.05)
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Speed = NumberRange.new(6, 11)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Rate = 0
	e.Parent = p
	p.Parent = workspace
	e:Emit(10)
	task.delay(0.7, function()
		p:Destroy()
	end)
end

local UPDATE: { [string]: (Rig, number, number) -> () } = {}

UPDATE.CampSpin = function(r, t, _)
	local axis = attr(r.model, "Axis", Vector3.new(0, 0, -1))
	local speed = math.rad(attr(r.model, "Speed", 30))
	for _, g in groupsOf(r) do
		turn(r, g, CFrame.fromAxisAngle(axis.Unit, t * speed))
	end
end

UPDATE.CampSway = function(r, t, _)
	local amp = math.rad(attr(r.model, "Amp", 6))
	local axis = attr(r.model, "Axis", Vector3.xAxis)
	local ph = attr(r.model, "Phase", 0)
	for i, g in groupsOf(r) do
		local k = ph + i * 1.3
		local a = amp * (math.sin(t * 2.2 + k) * 0.7 + math.sin(t * 5.3 + k * 1.7) * 0.3)
		turn(r, g, CFrame.fromAxisAngle(axis.Unit, a) * CFrame.Angles(0, a * 0.4, 0))
	end
end

UPDATE.CampSweep = function(r, t, _)
	local amp = math.rad(attr(r.model, "Amp", 30))
	local f = attr(r.model, "Freq", 0.05) * math.pi * 2
	for _, g in groupsOf(r) do
		turn(r, g, CFrame.Angles(0, amp * math.sin(t * f), 0) * CFrame.Angles(math.rad(6) * math.sin(t * f * 1.7), 0, 0))
	end
end

UPDATE.CampPump = function(r, t, _)
	local amp = math.rad(attr(r.model, "Amp", 10))
	local f = attr(r.model, "Freq", 0.7) * math.pi * 2
	for _, g in groupsOf(r) do
		turn(r, g, CFrame.Angles(0, 0, amp * math.max(0, math.sin(t * f))))
	end
end

UPDATE.CampBob = function(r, t, _)
	local amp = attr(r.model, "Amp", 0.3)
	local f = attr(r.model, "Freq", 0.3) * math.pi * 2
	local spin = math.rad(attr(r.model, "Spin", 0))
	local roll = math.rad(attr(r.model, "Roll", 0))
	r.root = r.base * CFrame.new(0, amp * math.sin(t * f), 0) * CFrame.Angles(0, spin * t, roll * math.sin(t * f * 0.8 + 1))
end

-- critters --------------------------------------------------------------------------------------------------
local function newTarget(r: Rig, home: Vector3, range: number)
	local a = r.rng:NextNumber(0, math.pi * 2)
	local d = math.sqrt(r.rng:NextNumber()) * range
	r.state.target = home + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

UPDATE.CampCritter = function(r, t, dt)
	local m = r.model
	local s = r.state
	local kind = attr(m, "Kind", "walk")
	local home: Vector3 = attr(m, "Home", r.base.Position)
	local range = attr(m, "Range", 4)
	local speed = attr(m, "Speed", 1.5)
	if not s.pos then
		s.pos = Vector3.new(r.base.Position.X, home.Y, r.base.Position.Z)
		local _, yaw = r.base:ToOrientation()
		s.yaw = yaw
		s.wait = r.rng:NextNumber(0, 2)
		s.hop = 0
	end
	if kind == "perch" then
		-- an owl: its head glances about, and at you when you're near
		local you = playerRoot()
		local want = s.look or 0
		if you and (you.Position - s.pos).Magnitude < 26 then
			local y = yawTo(s.pos, you.Position)
			if y then
				want = math.clamp(((y - s.yaw + math.pi) % (2 * math.pi)) - math.pi, -1.9, 1.9)
			end
		elseif t > (s.next or 0) then
			s.next = t + r.rng:NextNumber(1.5, 4)
			s.look = r.rng:NextNumber(-1.6, 1.6)
			want = s.look
		end
		s.head = lerpAngle(s.head or 0, want, dt * 6)
		turn(r, "Head", CFrame.Angles(0, s.head, 0))
		r.root = CFrame.new(s.pos) * CFrame.Angles(0, s.yaw, 0)
		return
	end
	if kind == "float" then
		local ph = (attr(m, "Seed", 1) % 97) * 0.37
		local p = home + Vector3.new(math.sin(t * 0.31 + ph) * range, math.sin(t * 0.9 + ph * 2) * 1.2, math.cos(t * 0.23 + ph * 1.3) * range)
		r.root = CFrame.new(p)
		return
	end
	if kind == "swim" then
		-- koi: a lazy loop round the pond, wiggling
		local ph = (attr(m, "Seed", 1) % 97) * 0.21
		local w = speed / math.max(range * 0.75, 0.5)
		local a = t * w + ph
		local p = home + Vector3.new(math.cos(a) * range * 0.75, 0, math.sin(a) * range * 0.55)
		local ahead = home + Vector3.new(math.cos(a + 0.1) * range * 0.75, 0, math.sin(a + 0.1) * range * 0.55)
		local y = yawTo(p, ahead) or 0
		r.root = CFrame.new(p) * CFrame.Angles(0, y + math.sin(t * 7) * 0.18, 0)
		return
	end
	-- walk / hop / waddle / crawl: to a spot, a pause, another spot
	if s.wait > 0 then
		s.wait -= dt
		if kind == "walk" then
			-- a chicken pecks while it stands
			local peck = math.max(0, math.sin(t * 9)) * (if math.sin(t * 0.9 + s.yaw) > 0 then 1 else 0)
			turn(r, "Head", CFrame.Angles(-peck * 0.7, 0, 0))
		end
		if s.wait <= 0 then
			newTarget(r, home, range)
		end
		r.root = CFrame.new(s.pos) * CFrame.Angles(0, s.yaw, 0)
		return
	end
	if not s.target then
		newTarget(r, home, range)
	end
	local to = s.target :: Vector3
	local d = flat(to - s.pos)
	local want = yawTo(s.pos, to) or s.yaw
	s.yaw = lerpAngle(s.yaw, want, dt * 5)
	local lift, roll = 0, 0
	if kind == "hop" then
		-- frogs move in hops
		s.hop += dt * 1.8
		local ph = s.hop % 1
		if ph < 0.5 and d.Magnitude > 0.01 then
			lift = math.sin(ph / 0.5 * math.pi) * 0.55
			s.pos += d.Unit * math.min(d.Magnitude, speed * 2.2 * dt)
		end
	else
		if d.Magnitude > 0.01 then
			s.pos += d.Unit * math.min(d.Magnitude, speed * dt)
		end
		if kind == "waddle" then
			roll = math.sin(t * 9) * 0.14
			turn(r, "armL", CFrame.Angles(0, 0, -0.25 - math.sin(t * 9) * 0.15))
			turn(r, "armR", CFrame.Angles(0, 0, 0.25 - math.sin(t * 9) * 0.15))
		elseif kind == "crawl" then
			s.yaw += math.sin(t * 11) * dt * 1.2
		elseif kind == "walk" then
			lift = math.abs(math.sin(t * 10)) * 0.08
			turn(r, "Head", CFrame.Angles(math.sin(t * 10) * 0.12, 0, 0))
		end
	end
	if d.Magnitude < 0.25 then
		s.wait = if kind == "hop" then r.rng:NextNumber(0.6, 2.5) else r.rng:NextNumber(1, 4.5)
		s.hop = 0
	end
	r.root = CFrame.new(s.pos + Vector3.new(0, lift, 0)) * CFrame.Angles(0, s.yaw, roll)
end

-- villagers -------------------------------------------------------------------------------------------------
local function parsePath(m: Model, y: number): { Vector3 }
	local out = {}
	local s = m:GetAttribute("Path")
	if type(s) ~= "string" then
		return out
	end
	for x, z in string.gmatch(s, "(-?[%d%.]+),(-?[%d%.]+)") do
		table.insert(out, Vector3.new(tonumber(x) :: number, y, tonumber(z) :: number))
	end
	return out
end

local function legs(r: Rig, swing: number)
	turn(r, "legL", CFrame.Angles(swing, 0, 0))
	turn(r, "legR", CFrame.Angles(-swing, 0, 0))
end

UPDATE.CampVillager = function(r, t, dt)
	local m = r.model
	local s = r.state
	local act = attr(m, "Act", "idle")
	local work = attr(m, "Work", "")
	if not s.pos then
		s.pos = r.base.Position
		local _, yaw = r.base:ToOrientation()
		s.yaw, s.home = yaw, yaw
		s.path = parsePath(m, r.base.Position.Y)
		s.i = 1
		s.wait = r.rng:NextNumber(0.5, 3)
		s.head = 0
	end
	local you = playerRoot()
	local dist = if you then (you.Position - s.pos).Magnitude else math.huge
	local walking = false
	local bob = 0
	-- walking the round
	if act == "walk" and #s.path > 1 then
		if s.wait > 0 then
			s.wait -= dt
		else
			local to = s.path[s.i]
			local d = flat(to - s.pos)
			if d.Magnitude < 0.3 then
				s.i = s.i % #s.path + 1
				s.wait = if r.rng:NextNumber() < 0.5 then r.rng:NextNumber(1.5, 4.5) else 0
			else
				walking = true
				local want = yawTo(s.pos, to) or s.yaw
				s.yaw = lerpAngle(s.yaw, want, dt * 6)
				s.pos += d.Unit * math.min(d.Magnitude, 3.4 * dt)
			end
		end
	end
	if walking then
		local w = t * 9
		legs(r, math.sin(w) * 0.5)
		turn(r, "armL", CFrame.Angles(-math.sin(w) * 0.4, 0, 0))
		turn(r, "armR", CFrame.Angles(math.sin(w) * 0.4, 0, 0))
		bob = math.abs(math.sin(w)) * 0.12
		s.head = lerpAngle(s.head, 0, dt * 4)
		turn(r, "Head", CFrame.Angles(0, s.head, 0))
	else
		-- standing (or sitting, or at work): turn to you when you're close, look at you, wave and say hello
		if act == "sit" then
			legs(r, 0)
			turn(r, "legL", CFrame.Angles(math.rad(85), 0, 0))
			turn(r, "legR", CFrame.Angles(math.rad(85), 0, 0))
		else
			legs(r, 0)
		end
		local want = 0
		if you and dist < 18 then
			local y = yawTo(s.pos, you.Position)
			if y then
				local rel = ((y - s.yaw + math.pi) % (2 * math.pi)) - math.pi
				want = math.clamp(rel, -1.2, 1.2)
				if act == "idle" and dist < 10 then
					-- the whole body turns toward you
					s.yaw = lerpAngle(s.yaw, y, dt * 2.5)
				end
			end
		elseif act == "idle" then
			s.yaw = lerpAngle(s.yaw, s.home, dt * 1.5)
			want = math.sin(t * 0.5) * 0.5
		end
		s.head = lerpAngle(s.head, want, dt * 5)
		local headPitch = if work == "gaze" and dist > 12 then 0.45 else 0
		turn(r, "Head", CFrame.Angles(headPitch, s.head, 0))
		-- the arms
		local waving = s.waveUntil and t < s.waveUntil
		if waving then
			turn(r, "armR", CFrame.Angles(0, 0, math.rad(150) + math.sin(t * 16) * 0.3))
			turn(r, "armL", CFrame.Angles(0, 0, 0))
		elseif act == "work" and dist > 7 then
			local k = t * 2 * math.pi
			if work == "chop" then
				local a = (t * 0.9) % 1
				local up = if a < 0.6 then a / 0.6 else 1 - (a - 0.6) / 0.4
				turn(r, "armR", CFrame.Angles(math.rad(40 + 110 * up), 0, 0))
				turn(r, "armL", CFrame.Angles(math.rad(30 + 60 * up), 0, 0))
			elseif work == "hammer" then
				local a = (t * 1.3) % 1
				local up = if a < 0.7 then a / 0.7 else 1 - (a - 0.7) / 0.3
				turn(r, "armR", CFrame.Angles(math.rad(45 + 90 * up), 0, 0))
				if a >= 0.97 and not s.struck then
					s.struck = true
					local hand = r.model:FindFirstChild("Hand") :: BasePart?
					if hand then
						sparks(hand.Position + Vector3.new(0, -0.6, 0))
					end
				elseif a < 0.9 then
					s.struck = false
				end
			elseif work == "rake" or work == "shovel" then
				local a = math.sin(k * 0.6)
				turn(r, "armR", CFrame.Angles(math.rad(35) + a * 0.35, 0, 0))
				turn(r, "armL", CFrame.Angles(math.rad(35) + a * 0.35, 0, 0))
				bob = math.abs(a) * 0.08
			elseif work == "water" then
				turn(r, "armR", CFrame.Angles(math.rad(65) + math.sin(k * 0.4) * 0.15, 0, 0))
			elseif work == "fish" then
				turn(r, "armR", CFrame.Angles(math.rad(40) + math.sin(k * 0.3) * 0.05 + (if (t % 9) < 0.4 then 0.35 else 0), 0, 0))
			elseif work == "gaze" then
				turn(r, "armR", CFrame.Angles(math.rad(20), 0, 0))
			end
		elseif act == "sit" then
			turn(r, "armL", CFrame.Angles(math.rad(25), 0, 0))
			turn(r, "armR", CFrame.Angles(math.rad(25) + math.max(0, math.sin(t * 0.7)) * 0.4, 0, 0))
		else
			-- breathing
			turn(r, "armL", CFrame.Angles(math.sin(t * 1.4) * 0.05, 0, -0.06))
			turn(r, "armR", CFrame.Angles(-math.sin(t * 1.4) * 0.05, 0, 0.06))
		end
		bob += math.sin(t * 1.4) * 0.02
	end
	-- hello: a wave and a line when you come near (one villager at a time)
	if you and dist < 11 then
		if not s.near and (s.saidAt == nil or os.clock() - s.saidAt > 25) and os.clock() - lastTalk > 5 then
			s.saidAt = os.clock()
			lastTalk = os.clock()
			s.waveUntil = t + 1.6
			local line = lineFor(r)
			if line then
				say(r, line)
			end
		end
		s.near = true
	elseif dist > 15 then
		s.near = false
	end
	r.root = CFrame.new(s.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, s.yaw, 0)
end

-------------------------------------------------------------------------------------------------------------
-- keeping track of what's streamed in, and the loop
-------------------------------------------------------------------------------------------------------------
local function add(m: Instance, kind: string)
	if not m:IsA("Model") or rigs[m] then
		return
	end
	task.spawn(function()
		for _ = 1, 8 do
			if not m.Parent then
				return
			end
			local r = build(m, kind)
			if r then
				rigs[m] = r
				return
			end
			task.wait(1)
		end
	end)
end

local function remove(m: Instance)
	if m:IsA("Model") and rigs[m] then
		rigs[m] = nil
	end
end

for _, tag in TAGS do
	for _, m in CollectionService:GetTagged(tag) do
		add(m, tag)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
		add(m, tag)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

-- which rigs are near the camera (every half second)
task.spawn(function()
	while true do
		task.wait(0.5)
		local cam = workspace.CurrentCamera
		local at = cam and cam.CFrame.Position or Vector3.zero
		table.clear(active)
		for m, r in rigs do
			if not m.Parent then
				rigs[m] = nil
			elseif (r.base.Position - at).Magnitude < NEAR then
				table.insert(active, r)
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, r in active do
		local f = UPDATE[r.kind]
		if f and not r.dead and r.model.Parent then
			local ok, err = pcall(f, r, now - r.t0, math.min(dt, 0.1))
			if ok then
				apply(r)
			else
				warn("[CampLife] " .. r.kind .. ": " .. tostring(err))
				r.dead = true
				rigs[r.model] = nil
			end
		end
	end
end)

return {}
