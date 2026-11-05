-- Loot on the ground (server/Loot): new drops pop up out of the cut grass, land with a squash and bounce, gems
-- spin and bob. When you pick something up, a copy of it is sucked into you along an arc, spinning and
-- shrinking, ends in a little sparkle with a bloop that climbs in pitch as you hoover up a pile, and then flies
-- on to the HUD (Hud "lootPicked"). A new Index entry gets a notice.
-- Everything here is only for looks; the server decides what's picked up.
-- (5 Nov, grass toys, Config.GRASS_TOYS) A bundle someone runs into is kicked by the server (server/Loot): here it
-- hops and tumbles from where it was to where it went, with a little grass puff and a rustle. Jumping onto a bundle
-- bounces your own character up like a little trampoline (smaller each bounce in a row) and squashes the bundle.
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
local TOYS = Config.GRASS_TOYS
local bundles: { [Model]: boolean } = {} -- bundles on the ground (for jumping on)
type Roll = { model: Model, from: Vector3, to: CFrame, t: number, axis: Vector3, scale: number? }
local rolls: { Roll } = {}
local onKick: (Model, number?) -> () = function() end -- set below, once the puff exists

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
	if m:IsA("Model") and m.Name == "Bundle" then
		bundles[m] = true
		m:GetAttributeChangedSignal("Kick"):Connect(function()
			onKick(m)
		end)
	end
	m.Destroying:Connect(function()
		spinners[m] = nil
		bundles[m :: any] = nil
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

-- A kicked bundle's hop-and-roll: from where it was to where the server put it, along a low arc, tumbling over
-- forwards, then the landing squash (the pops' spring). Covers the server's snap.
local function stepRolls(dt: number)
	for i = #rolls, 1, -1 do
		local r = rolls[i]
		r.t += dt
		local m = r.model
		local k = math.min(r.t / TOYS.kickTime, 1)
		if not m.Parent then
			table.remove(rolls, i)
		elseif k >= 1 then
			table.remove(rolls, i)
			setPivot(m, r.to)
			table.insert(pops, { model = m, target = r.to, t = 0.35, scale = r.scale })
		else
			local e = 1 - (1 - k) * (1 - k) -- fast off the foot, slowing as it lands
			local pos = r.from:Lerp(r.to.Position, e) + Vector3.new(0, math.sin(k * math.pi) * TOYS.kickHop, 0)
			-- one full tumble over forwards that ends upright in its final turn
			local roll = CFrame.fromAxisAngle(r.axis, (1 - e) * -math.pi * 2)
			setPivot(m, CFrame.new(pos) * roll * r.to.Rotation)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	stepRolls(dt)
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

-------------------------------------------------------------------------------------------------------------
-- grass toys: kicked bundles and jumping on them (Config.GRASS_TOYS)
-------------------------------------------------------------------------------------------------------------
-- A little puff of grass bits where a kicked bundle leaves the ground (none in Potato Mode).
local function puff(pos: Vector3, color: Color3)
	if player:GetAttribute("Potato") then
		return
	end
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = pos + Vector3.new(0, 0.3, 0)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = FxIds.splinter or FxIds.glow or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 0.85), 0.2), color)
	e.LightInfluence = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.55)
	e.Speed = NumberRange.new(4, 8)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Parent = a
	e:Emit(7)
	Debris:AddItem(a, 0.8)
end

-- the camera's distance to `pos`: sounds and puffs only for kicks you could see
local function nearCam(pos: Vector3, within: number): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude < within
end

-- Stop whatever `m` is doing (its landing squash, an earlier roll): back at full size and on its resting spot.
-- Returns that size and spot.
local function settleBundle(m: Model): (number, CFrame)
	local scale, rest = m:GetScale(), m:GetPivot()
	for i = #pops, 1, -1 do
		if pops[i].model == m then
			scale, rest = pops[i].scale or scale, pops[i].target
			table.remove(pops, i)
		end
	end
	for i = #rolls, 1, -1 do
		if rolls[i].model == m then
			scale, rest = rolls[i].scale or scale, rolls[i].to
			table.remove(rolls, i)
		end
	end
	m:ScaleTo(scale)
	setPivot(m, rest)
	return scale, rest
end

onKick = function(m: Model, tries: number?)
	local from = m:GetAttribute("KickFrom")
	local yaw = m:GetAttribute("KickYaw")
	if typeof(from) ~= "Vector3" or type(yaw) ~= "number" or not m.Parent then
		return
	end
	-- where the server put it; if its move hasn't reached us yet (still on the old spot), wait a few frames for it
	local pivotNow = m:GetPivot().Position
	local flat = Vector3.new(pivotNow.X - (from :: Vector3).X, 0, pivotNow.Z - (from :: Vector3).Z).Magnitude
	if flat < 0.5 and (tries or 0) < 10 then
		task.delay(0.03, onKick, m, (tries or 0) + 1)
		return
	end
	local to = CFrame.new(pivotNow) * CFrame.Angles(0, yaw :: number, 0)
	local scale = settleBundle(m)
	local dir = Vector3.new(to.X - (from :: Vector3).X, 0, to.Z - (from :: Vector3).Z)
	local axis = if dir.Magnitude > 0.05 then Vector3.yAxis:Cross(dir.Unit) else Vector3.xAxis
	table.insert(rolls, { model = m, from = from :: Vector3, to = to, t = 0, axis = axis, scale = scale })
	setPivot(m, CFrame.new(from :: Vector3) * to.Rotation)
	if nearCam(from :: Vector3, 70) then
		puff(from :: Vector3, bodyColor(m))
		Sound.play(TOYS.kickSound, 0.12, if nearCam(from :: Vector3, 20) then 0.8 else 0.4)
	end
end

-- Jumping on a bundle: your feet coming down onto its top while you fall (bundles don't collide, so this is the
-- moment you'd land on it) sends you back up, once per landing; bounces in a row get smaller until you just land.
local bounceChain, bounceAt = 0, 0
local THICK = 1.2 -- a bundle lying down is about this tall (shared/BundleVoxel.thickness of a 2.6 bundle: 1.16)
local function tryBounce()
	if not TOYS.bounce or next(bundles) == nil then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.SeatPart or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	local v = root.AssemblyLinearVelocity
	if hum.FloorMaterial ~= Enum.Material.Air and now - bounceAt > 0.3 then
		bounceChain = 0 -- back on the ground: the next bounce is a full one
	end
	if v.Y > -4 or now - bounceAt < 0.25 then
		return
	end
	local p = root.Position
	local feet = p.Y - hum.HipHeight - root.Size.Y / 2
	for m in bundles do
		local at = m:GetPivot().Position
		local dx, dz = at.X - p.X, at.Z - p.Z
		if dx * dx + dz * dz < TOYS.bounceRadius * TOYS.bounceRadius and feet <= at.Y + THICK + 0.4 and feet >= at.Y - 0.6 then
			local speed = TOYS.bounceSpeed * TOYS.bounceDecay ^ bounceChain
			if speed < TOYS.bounceMin then
				return
			end
			bounceChain += 1
			bounceAt = now
			root.AssemblyLinearVelocity = Vector3.new(v.X, speed, v.Z)
			-- squash the bundle (the pops' landing spring), unless it's rolling
			local busy = false
			for _, r in rolls do
				busy = busy or r.model == m
			end
			if not busy then
				local scale, rest = settleBundle(m)
				table.insert(pops, { model = m, target = rest, t = 0.35, scale = scale })
			end
			Sound.playAt(TOYS.bounceSound, 0.9 + 0.12 * bounceChain, 0.6)
			return
		end
	end
end
RunService.Heartbeat:Connect(tryBounce)

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
