local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	buf = Instance.new("Folder")
	buf.Name = "ClaudePatchBuf"
	buf.Parent = ss
end
local bad = {}
local function put(name, text, want)
	if hashOf(text) ~= want then
		table.insert(bad, name .. " garbled")
		return
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
end

put("CampLife.1", [====[-- The area camps come alive (owner, 29 Oct: "make it feel more alive and not so boring"): server/CampDress tags
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
			table.insert(group, if type(g) == "string" then g else nil)
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
]====], "8990 1368495504")
return "part 11/13 (CampLife.1): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
