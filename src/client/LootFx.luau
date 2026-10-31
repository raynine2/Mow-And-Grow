-- Loot on the ground (server/Loot): new drops pop up out of the cut grass, land with a squash and bounce, gems
-- spin and bob. When you pick something up, a copy of it is sucked into you along an arc, spinning and
-- shrinking, ends in a little sparkle with a bloop that climbs in pitch as you hoover up a pile, and then flies
-- on to the HUD (Hud "lootPicked"). A new Index entry gets a notice.
-- Everything here is only for looks; the server decides what's picked up.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local FxIds = require(ReplicatedStorage.MowALawn:WaitForChild("FxIds")) :: { [string]: string }
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local UI = require(script.Parent.UI)
local WeaponVfx = require(script.Parent.WeaponVfx) -- (28 Oct) the glint of a gem popping out of the stump

local LootFx = {}
local player = Players.LocalPlayer

type Pop = { model: Model | BasePart, target: CFrame, t: number, scale: number? }
local pops: { Pop } = {}
local spinners: { [Instance]: CFrame } = {}

-- (28 Oct, owner's brief: "a gem pops up from the stump") set below, once bodyColor exists
local gemGlint: (Instance, Vector3) -> () = function() end

local function pivotOf(m: Instance): CFrame?
	if m:IsA("Model") then
		return m:GetPivot()
	elseif m:IsA("BasePart") then
		return m.CFrame
	end
	return nil
end

local function setPivot(m: Instance, cf: CFrame)
	if m:IsA("Model") then
		m:PivotTo(cf)
	elseif m:IsA("BasePart") then
		m.CFrame = cf
	end
end

-- Drops that just went (picked up): a copy of each, kept a moment so the pickup can fly it to you. The server
-- removes the drop as it sends the pickup, so the copy is taken as it goes.
type Ghost = { copy: Instance, pos: Vector3, at: number }
local gone: { Ghost } = {}

-- A new drop: hop up out of the grass and land on its spot (0.35 s), squashing on landing. Gems float and
-- spin after that.
local function onDrop(m: Instance)
	local target = pivotOf(m)
	if not target then
		return
	end
	-- (30 Oct, multiplayer check) someone else's drop: only they can pick it up (server/Loot), so here it shows faded
	-- instead of looking like yours and then doing nothing when you walk over it
	local owner = m:GetAttribute("Owner")
	if type(owner) == "number" and owner ~= player.UserId then
		local parts: { Instance } = if m:IsA("BasePart") then { m } else {}
		for _, d in m:GetDescendants() do
			table.insert(parts, d)
		end
		for _, d in parts do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0.6
			end
		end
	end
	if m:GetAttribute("Spin") then
		spinners[m] = target
		gemGlint(m, target.Position)
	end
	table.insert(pops, { model = m :: any, target = target, t = 0 })
	setPivot(m, target * CFrame.new(0, -1, 0))
	m.Destroying:Connect(function()
		spinners[m] = nil
		if m:GetAttribute("Owner") == player.UserId then
			local ok, copy = pcall(function()
				m.Archivable = true
				return m:Clone()
			end)
			if ok and copy then
				local at = pivotOf(m)
				table.insert(gone, { copy = copy, pos = if at then at.Position else target.Position, at = os.clock() })
			end
		end
	end)
end

local function watch(folder: Instance)
	folder.ChildAdded:Connect(onDrop)
end

-- the Loot folder lives in the run's World folder (each World: in Studio the lobby's is replaced by the run's)
local function watchWorld(world: Instance)
	local function check(c: Instance)
		if c.Name == "Loot" and c:IsA("Folder") then
			watch(c)
		end
	end
	world.ChildAdded:Connect(check)
	for _, c in world:GetChildren() do
		check(c)
	end
end
workspace.ChildAdded:Connect(function(c)
	if c.Name == "World" then
		watchWorld(c)
	end
end)
local firstWorld = workspace:FindFirstChild("World")
if firstWorld then
	watchWorld(firstWorld)
end

RunService.RenderStepped:Connect(function(dt)
	for i = #pops, 1, -1 do
		local p = pops[i]
		p.t += dt
		local k = math.min(p.t / 0.35, 1)
		local m = p.model
		if not m.Parent or p.t >= 0.6 then
			if m.Parent then
				if m:IsA("Model") then
					m:ScaleTo(p.scale or 1)
				end
				if not spinners[m] then
					setPivot(m, p.target)
				end
			end
			table.remove(pops, i)
		elseif k < 1 then
			-- a little arc: up 1.6 studs and back down, with a tumble, stretched tall while it flies
			local h = -1 + 2.6 * math.sin(k * math.pi) + k
			setPivot(m, p.target * CFrame.new(0, h, 0) * CFrame.Angles(0, (1 - k) * 3, 0))
		elseif m:IsA("Model") and not spinners[m] then
			-- landed: squash flat and bounce back (a quick damped spring on its size)
			p.scale = p.scale or m:GetScale()
			local u = p.t - 0.35
			m:ScaleTo((p.scale :: number) * (1 - 0.22 * math.exp(-u * 12) * math.cos(u * 30)))
			setPivot(m, p.target)
		end
	end
	local now = os.clock()
	-- (only the ones you could see turning: far drops stay still)
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	local far = if Players.LocalPlayer:GetAttribute("Potato") then 50 else 110
	for m, base in spinners do
		if m.Parent and (base.Position - eye).Magnitude < far then
			setPivot(m, base * CFrame.new(0, math.sin(now * 2.4) * 0.35, 0) * CFrame.Angles(0, now * 2, 0))
		end
	end
end)

-- A little burst of sparkles where a pickup lands in you.
local function sparkle(pos: Vector3, color: Color3)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = FxIds.spark or FxIds.glow or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.new(1, 1, 0.9), color)
	e.LightEmission = 0.6
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 0.3)
	e.Lifetime = NumberRange.new(0.25, 0.4)
	e.Speed = NumberRange.new(6, 11)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 5
	e.Parent = a
	e:Emit(9)
	Debris:AddItem(a, 0.6)
end

-- Picking up a pile climbs a scale: each bloop a step higher, back to the bottom after a pause.
local pickStep, pickAt = 0, 0
local STEPS = { 1, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888, 2 } -- a major scale
local function pickSound(kind: string)
	local now = os.clock()
	pickStep = if now - pickAt < 0.9 then math.min(pickStep + 1, #STEPS) else 1
	pickAt = now
	Sound.playAt("pickup", STEPS[pickStep] * (if kind == "gem" then 1.25 else 1))
	if kind == "gem" then
		Sound.play("reveal", 0.1, 0.6)
	end
end

local function bodyColor(m: Instance): Color3
	local best, size = nil, 0
	for _, p in (if m:IsA("BasePart") then { m } else m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > size then
				best, size = p, v
			end
		end
	end
	return if best then (best :: BasePart).Color else Color3.fromRGB(120, 200, 80)
end

-- a glint, a soft glow and sparkles in the gem's colour as it hops out (client/WeaponVfx "GemPop")
gemGlint = function(m: Instance, at: Vector3)
	local color = bodyColor(m)
	task.delay(0.12, WeaponVfx.gemPop, at + Vector3.new(0, 1.6, 0), color) -- (near the top of its hop)
end

-- Fly a copy of the picked-up drop into you: a hop up and an arc that homes in on your middle, spinning and
-- shrinking, then a sparkle and the bloop; the HUD's icon takes over from where it was last on screen.
local function suck(copy: Instance, from: Vector3, d: any)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, p in (if copy:IsA("BasePart") then { copy } else copy:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	local scale0 = if copy:IsA("Model") then copy:GetScale() else 1
	local color = bodyColor(copy)
	copy.Parent = workspace
	local T = 0.32
	local born = os.clock()
	local handed = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - born) / T)
		local goal = if root and root.Parent then root.Position + Vector3.new(0, 0.4, 0) else from
		local e = k * k * (3 - 2 * k)
		local pos = from:Lerp(goal, e) + Vector3.new(0, math.sin(k * math.pi) * 2.2, 0)
		local cf = CFrame.new(pos) * CFrame.Angles(k * 4, k * 9, 0)
		if copy:IsA("Model") then
			copy:PivotTo(cf)
			copy:ScaleTo(scale0 * math.max(0.05, 1 - 0.75 * k))
		elseif copy:IsA("BasePart") then
			copy.CFrame = cf
		end
		if not handed and k >= 0.55 then
			handed = true
			State.emit("lootPicked", pos, d.kind, d.gems)
		end
		if k >= 1 then
			conn:Disconnect()
			copy:Destroy()
			sparkle(goal, color)
			pickSound(d.kind)
		end
	end)
end

-- The copy of this drop, taken when the server removed it (nearest to the pickup spot). If the removal hasn't
-- reached us yet, look once more a moment later; failing that, skip the flight.
local function pickup(d: any, again: boolean)
	local now = os.clock()
	local best, bestD = nil, 3
	for i = #gone, 1, -1 do
		local g = gone[i]
		if now - g.at > 1 then
			g.copy:Destroy()
			table.remove(gone, i)
		else
			local dd = Vector3.new(g.pos.X - d.pos.X, 0, g.pos.Z - d.pos.Z).Magnitude
			if dd < bestD then
				best, bestD = i, dd
			end
		end
	end
	if best then
		local g = table.remove(gone, best) :: Ghost
		suck(g.copy, g.pos, d)
	elseif again then
		task.delay(0.06, pickup, d, false)
	else
		State.emit("lootPicked", d.pos, d.kind, d.gems)
		pickSound(d.kind)
	end
end

State.on("fx", function(kind, d)
	if kind == "pickup" then
		pickup(d, true)
	elseif kind == "indexNew" then
		local zone = Config.ZONES[d.z]
		local name = (if d.mut == "None" then "" else d.mut .. " ") .. (if zone then zone.grassName else "Grass")
		UI.notice("New in your Index!", ("%s   +%d gems"):format(name, d.gems or 0), "clover")
	end
end)

local _ = player
return LootFx
