-- FUNNY MOMENTS on screen (5 Nov, owner: "make your friends laugh"). server/Funny decides who and when; this draws
-- it on every client, and on the victim's own client moves them (they own their character's physics).
--   "funnySquash" { ids, time, pos }   flattened like a pancake: a flat copy of each body (the real one is hidden on
--                                      this screen), stars circling the head, BONK!, a thud and a squish; the victim
--                                      can't walk; then it springs back up with a bounce.
--   "funnyBonk"   { pos, by, to, word, color }  a squeak, a word above them, a little star burst
--   "funnyNudge"  { vel }              (victim only) the tiny knock-back, capped here again
--   "funnySpit"   { phase, id, mouth, out, to, word }  "gulp": the machine swallows them (hidden, rumble, GULP!);
--                                      "spit": out of the chute in a burst of clippings, YUCK! / SHREDDED!
--   "funnyLaunch" { from, to, apex }   (victim only) the arc from the chute to the landing spot
-- Never on the victim's screen while a film or the egg hatch has it (camera Scriptable, HatchActive). Particles:
-- none in Potato Mode, half on phones. All tuning is Config.FUNNY.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Fx = require(script.Parent.Fx)
local SellFx = require(script.Parent.SellFx)
local Potato = require(script.Parent.Potato)
local PhonePerf = require(script.Parent.PhonePerf)

local Funny = {}
local player = Players.LocalPlayer
local CFG = Config.FUNNY

local folder = Instance.new("Folder")
folder.Name = "FunnyFx"
folder.Parent = workspace

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function charOf(userId: number): Model?
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

local function rootOf(char: Model?): BasePart?
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function camDist(pos: Vector3): number
	local cam = workspace.CurrentCamera
	return if cam then (cam.CFrame.Position - pos).Magnitude else 0
end

-- A sound from this spot: softer further away, nothing past 110 studs.
local function soundAt(pos: Vector3, key: string?, pitch: number, volume: number?)
	if not key or not Config.SOUNDS[key] then
		return
	end
	local d = camDist(pos)
	if d > 110 then
		return
	end
	Sound.playAt(key, pitch * rand(0.95, 1.05), (volume or 1) * math.clamp(1.2 - d / 100, 0.2, 1))
end

-- How many particles: none in Potato Mode, half on phones.
local function particles(n: number): number
	if Potato.on then
		return 0
	end
	return if PhonePerf.on then math.floor(n / 2) else n
end

-- Is this screen busy with something that owns the player (a film, the egg hatch, being downed)?
local function busy(): boolean
	local cam = workspace.CurrentCamera
	return (cam ~= nil and cam.CameraType == Enum.CameraType.Scriptable)
		or player:GetAttribute("HatchActive") == true
		or player:GetAttribute("Downed") ~= nil
end

-------------------------------------------------------------------------------------------------------------
-- holding your own controls (squash, the arc): PlayerModule's controls off, back on when the last hold ends
-------------------------------------------------------------------------------------------------------------
local controls: any = nil
local function getControls(): any
	if not controls then
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			if module then
				controls = ((require :: any)(module)):GetControls()
			end
		end)
	end
	return controls
end

local holdUntil = 0
local holding = false
local function holdControls(seconds: number)
	holdUntil = math.max(holdUntil, os.clock() + seconds)
	local c = getControls()
	if not c then
		return
	end
	if not holding then
		holding = true
		pcall(function()
			c:Disable()
		end)
	end
	task.delay(seconds + 0.02, function()
		if not holding or os.clock() < holdUntil then
			return
		end
		holding = false
		-- (a film that started meanwhile has the camera and its own controls: it hands them back itself)
		local cam = workspace.CurrentCamera
		if not (cam and cam.CameraType == Enum.CameraType.Scriptable) then
			pcall(function()
				c:Enable()
			end)
		end
	end)
end

-- Keep the root's sideways speed for `seconds` (the humanoid would brake it), then let go. Stops on landing.
local function carry(root: BasePart, flatVel: Vector3, seconds: number)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
		local t = os.clock() - t0
		local landed = t > 0.15 and hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air
		if t > seconds or not root.Parent or landed or root.Anchored then
			conn:Disconnect()
			return
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(flatVel.X, v.Y, flatVel.Z)
	end)
end

-------------------------------------------------------------------------------------------------------------
-- hiding a real character on this screen (the pancake / inside the shredder stand in for it)
-------------------------------------------------------------------------------------------------------------
local hidden: { [Model]: number } = {}
local function hide(char: Model, seconds: number)
	local first = hidden[char] == nil
	hidden[char] = math.max(hidden[char] or 0, os.clock() + seconds)
	if not first then
		return
	end
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local done = os.clock() >= (hidden[char] or 0) or not char.Parent
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = if done then 0 else 1
			end
		end
		if done then
			hidden[char] = nil
			conn:Disconnect()
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the pancake: an anchored copy of the body, its parts squeezed toward the ground every frame
-------------------------------------------------------------------------------------------------------------
type Item = { part: BasePart, rel: CFrame, size: Vector3, meshes: { { mesh: SpecialMesh, scale: Vector3 } } }

local function stripCopy(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("Animator") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			d:Destroy()
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		hum.EvaluateStateMachine = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.PlatformStand = true
	end
end

local function copyOf(char: Model): Model?
	local was = char.Archivable
	char.Archivable = true
	local ok, m = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not m then
		return nil
	end
	m.Name = "Pancake"
	stripCopy(m)
	return m
end

-- The floor under a character (its foot point), facing the way it faces.
local function footFrame(char: Model, root: BasePart): CFrame
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { char, folder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), rp)
	local y = if hit then hit.Position.Y else root.Position.Y - 3
	local look = root.CFrame.LookVector
	local f = Vector3.new(look.X, 0, look.Z)
	f = if f.Magnitude > 0.1 then f.Unit else Vector3.zAxis
	local at = Vector3.new(root.Position.X, y, root.Position.Z)
	return CFrame.lookAt(at, at + f)
end

local function itemsOf(m: Model, base: CFrame): { Item }
	local items: { Item } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local meshes = {}
			for _, c in d:GetChildren() do
				if c:IsA("SpecialMesh") then
					table.insert(meshes, { mesh = c, scale = c.Scale })
				end
			end
			table.insert(items, { part = d, rel = base:ToObjectSpace(d.CFrame), size = d.Size, meshes = meshes })
		end
	end
	return items
end

-- the squeeze along each of the part's own axes when the body is scaled (w, k, w) in the foot's frame
local function axisScale(rot: CFrame, w: number, k: number): Vector3
	local s = Vector3.new(w, k, w)
	return Vector3.new((rot.RightVector * s).Magnitude, (rot.UpVector * s).Magnitude, (rot.LookVector * s).Magnitude)
end

local function place(items: { Item }, base: CFrame, w: number, k: number)
	local parts, cfs = {}, {}
	for _, it in items do
		local p = it.rel.Position
		local rot = it.rel.Rotation
		local sc = axisScale(rot, w, k)
		it.part.Size = it.size * sc
		for _, ms in it.meshes do
			ms.mesh.Scale = ms.scale * sc
		end
		table.insert(parts, it.part)
		table.insert(cfs, base * CFrame.new(p.X * w, p.Y * k, p.Z * w) * rot)
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- (flat, wide) at time t of `total`: squash in fast, wobble while flat, spring back with an overshoot
local function squashCurve(t: number, total: number, flat: number, wide: number): (number, number, number)
	local inT, outT = 0.12, 0.45
	if t < inT then
		local e = 1 - (1 - t / inT) ^ 2
		return 1 + (wide - 1) * e, 1 + (flat - 1) * e, 0
	elseif t < total - outT then
		local wob = 1 + 0.07 * math.sin(t * 18)
		return wide, flat * wob, 0
	end
	local u = math.clamp((t - (total - outT)) / outT, 0, 1)
	local spring = math.exp(-5 * u) * math.cos(11 * u)
	local lift = 1.3 * math.max(0, math.sin(math.pi * math.min(1, u * 1.7)))
	return 1 + (wide - 1) * spring, 1 + (flat - 1) * spring, lift
end

local function starRing(at: Vector3, count: number, life: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = folder
	local guis = {}
	for i = 1, count do
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(34, 34)
		g.LightInfluence = 0
		g.MaxDistance = 90
		g.Adornee = anchor
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "★"
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = if i % 2 == 0 then Color3.fromRGB(255, 240, 120) else Color3.fromRGB(255, 200, 40)
		t.TextStrokeTransparency = 0.2
		t.Parent = g
		g.Parent = anchor
		guis[i] = g
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > life or not anchor.Parent then
			conn:Disconnect()
			anchor:Destroy()
			return
		end
		for i, g in guis do
			local a = t * 5 + i * math.pi * 2 / count
			g.StudsOffsetWorldSpace = Vector3.new(math.cos(a) * 1.4, 0.25 * math.sin(a * 2), math.sin(a) * 1.4)
		end
	end)
	return anchor
end

local function pancake(char: Model, total: number)
	local root = rootOf(char)
	if not root or camDist(root.Position) > 160 then
		return
	end
	local c = CFG.squash
	local base = footFrame(char, root)
	local m = copyOf(char)
	if not m then
		return
	end
	local items = itemsOf(m, base)
	m.Parent = folder
	hide(char, total)
	local head = char:FindFirstChild("Head") :: BasePart?
	local headRel = if head then base:ToObjectSpace(head.CFrame).Position else Vector3.new(0, 4.5, 0)
	local starAt = base * Vector3.new(headRel.X * c.wide, 1.6, headRel.Z * c.wide)
	starRing(starAt, c.stars, total - 0.35)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= total or not m.Parent then
			conn:Disconnect()
			m:Destroy()
			return
		end
		local w, k, lift = squashCurve(t, total, c.flat, c.wide)
		local ok = pcall(place, items, base + Vector3.new(0, lift, 0), w, k)
		if not ok then
			conn:Disconnect()
			m:Destroy()
		end
	end)
	task.delay(total - 0.45, function()
		soundAt(root.Position, c.boing, c.boingPitch, 0.8)
	end)
end

local function onSquash(d: any)
	local c = CFG.squash
	local total = math.clamp(tonumber(d.time) or c.time, 0.5, 4)
	for _, id in (if type(d.ids) == "table" then d.ids else {}) do
		local char = charOf(id)
		local root = rootOf(char)
		if char and root then
			pancake(char, total)
			soundAt(root.Position, c.sound, c.soundPitch)
			soundAt(root.Position, c.squish, c.squishPitch, 0.8)
			Fx.popWord(root.Position, c.word, c.wordColor)
			if id == player.UserId and not busy() then
				holdControls(total)
				Fx.shake(0.6, 0.3)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- bonk
-------------------------------------------------------------------------------------------------------------
local function starBurst(pos: Vector3, count: number)
	local n = particles(count)
	if n <= 0 then
		return
	end
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = FxIds.spark or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 190, 40))
	e.LightEmission = 0.6
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(8, 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Drag = 4
	e.Parent = a
	e:Emit(n)
	Debris:AddItem(a, 1.2)
end

local function onBonk(d: any)
	local c = CFG.bonk
	local pos = d.pos
	if typeof(pos) ~= "Vector3" or camDist(pos) > 120 then
		return
	end
	local victim = rootOf(charOf(tonumber(d.to) or 0))
	local at = if victim then victim.Position + Vector3.new(0, 2.5, 0) else pos
	soundAt(at, c.sound, c.soundPitch)
	soundAt(at, c.thud, c.thudPitch, c.thudVolume)
	Fx.popWord(at, tostring(d.word or "BONK!"), if typeof(d.color) == "Color3" then d.color else c.wordColors[1])
	starBurst(at, c.stars)
	if d.to == player.UserId or d.by == player.UserId then
		Fx.shake(0.25, 0.15)
	end
end

local function onNudge(d: any)
	local c = CFG.bonk
	local root = rootOf(player.Character)
	local vel = d.vel
	if not root or typeof(vel) ~= "Vector3" or busy() or root.Anchored then
		return
	end
	local side = Vector3.new(vel.X, 0, vel.Z)
	if side.Magnitude > c.speed then
		side = side.Unit * c.speed
	end
	local up = math.clamp(vel.Y, 0, c.hop)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(side.X, math.max(v.Y, up), side.Z)
	carry(root, side, 0.3)
end

-------------------------------------------------------------------------------------------------------------
-- shredder spit-out
-------------------------------------------------------------------------------------------------------------
-- the machine nearest a spot (any Model named "shredder" in the world), found once and kept a while
local machines: { Model } = {}
local machinesAt = -100
local function machineNear(pos: Vector3): Model?
	if os.clock() - machinesAt > 30 then
		machinesAt = os.clock()
		table.clear(machines)
		local world = workspace:FindFirstChild("World")
		for _, d in (if world then world:GetDescendants() else {}) do
			if d:IsA("Model") and d.Name == "shredder" then
				table.insert(machines, d)
			end
		end
	end
	local best, bestD = nil, 18
	for _, m in machines do
		if m.Parent then
			local dd = (m:GetPivot().Position - pos).Magnitude
			if dd < bestD then
				best, bestD = m, dd
			end
		end
	end
	return best
end

local rumbling: { [Model]: boolean } = {}
local function rumble(pos: Vector3, time: number)
	local m = machineNear(pos)
	if not m or rumbling[m] then
		return
	end
	rumbling[m] = true
	local home = m:GetPivot()
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= time or not m.Parent then
			conn:Disconnect()
			rumbling[m] = nil
			if m.Parent then
				m:PivotTo(home)
			end
			return
		end
		local k = 0.12 * math.min(1, (time - t) * 3)
		m:PivotTo(home * CFrame.new(rand(-k, k), rand(0, k), rand(-k, k)) * CFrame.Angles(rand(-k, k) * 0.2, 0, rand(-k, k) * 0.2))
	end)
end

-- grass clippings pouring off you as you fly
local function clippingsOn(root: BasePart, count: number)
	local n = particles(count)
	if n <= 0 then
		return
	end
	local grass = Config.ZONES[(State.world and State.world.zone) or 1] or Config.ZONES[1]
	local color = grass.grass[1]
	local a = Instance.new("Attachment")
	a.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = FxIds.blade or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.3))
	e.LightInfluence = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(5, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-400, 400)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Parent = a
	e:Emit(n)
	task.delay(0.25, function()
		if e.Parent then
			e:Emit(math.floor(n / 2))
		end
	end)
	Debris:AddItem(a, 1.6)
end

local function onSpit(d: any)
	local c = CFG.spit
	local mouth, out = d.mouth, d.out
	if typeof(mouth) ~= "Vector3" or typeof(out) ~= "Vector3" or camDist(mouth) > 150 then
		return
	end
	local char = charOf(tonumber(d.id) or 0)
	if d.phase == "gulp" then
		local time = math.clamp(tonumber(d.time) or c.gulpTime, 0.2, 3)
		if char then
			hide(char, time)
		end
		rumble(mouth, time + 0.3)
		if particles(1) > 0 then
			SellFx.spray(mouth, 4)
		end
		soundAt(mouth, c.gulpSound, c.gulpPitch)
		Fx.popWord(mouth, c.gulpWord, c.wordColor)
	elseif d.phase == "spit" then
		if particles(1) > 0 then
			SellFx.spray(out, 8)
		end
		local root = rootOf(char)
		if root then
			clippingsOn(root, c.clippings)
		end
		soundAt(out, c.spitSound, c.spitPitch)
		soundAt(out, c.splat, c.splatPitch, 0.8)
		Fx.popWord(out + Vector3.new(0, 2, 0), tostring(d.word or "YUCK!"), c.wordColor)
	end
end

-- (victim only) the arc from the chute onto the landing spot the server picked (none: a little hop out)
local function onLaunch(d: any)
	local root = rootOf(player.Character)
	if not root or typeof(d.from) ~= "Vector3" then
		return
	end
	-- the server unanchors us just before this: wait for that to arrive
	local t0 = os.clock()
	while root.Anchored and os.clock() - t0 < 1 do
		task.wait()
	end
	if root.Anchored or not root.Parent then
		return
	end
	local g = workspace.Gravity
	local from = root.Position
	local to = if typeof(d.to) == "Vector3" then (d.to :: Vector3) + Vector3.new(0, 3, 0) else from + root.CFrame.LookVector * 3
	local apexY = math.max(from.Y, to.Y) + math.clamp(tonumber(d.apex) or CFG.spit.apex, 2, 14)
	local vy = math.sqrt(2 * g * (apexY - from.Y))
	local flight = vy / g + math.sqrt(2 * math.max(0.1, apexY - to.Y) / g)
	local side = Vector3.new(to.X - from.X, 0, to.Z - from.Z) / flight
	if side.Magnitude > 40 then
		side = side.Unit * 40 -- (never a fling: a landing spot is at most ~13 studs off)
	end
	root.AssemblyLinearVelocity = Vector3.new(side.X, vy, side.Z)
	holdControls(flight + 0.15)
	carry(root, side, flight + 0.1)
end

State.on("fx", function(kind: string, d: any)
	local h = if kind == "funnySquash" then onSquash
		elseif kind == "funnyBonk" then onBonk
		elseif kind == "funnyNudge" then onNudge
		elseif kind == "funnySpit" then onSpit
		elseif kind == "funnyLaunch" then onLaunch
		else nil
	if h and type(d) == "table" then
		local ok, err = pcall(h, d)
		if not ok then
			warn("[Funny] " .. kind .. ": " .. tostring(err))
		end
	end
end)

return Funny
