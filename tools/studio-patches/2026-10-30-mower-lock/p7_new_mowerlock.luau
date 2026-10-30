-- Creates client/MowerLock in Studio (a new ModuleScript, exactly git's text). Run in Edit mode.
local src = [=====[
-- MowerLock (30 Oct, owner: "for game release i want to close of the mower system including gas etc and release it in
-- a later update so i want you to put a lock in it like holografic with high fx qaulity dont slop ... just a lock on
-- it"). While Config.MOWERS_LOCKED is on (the server refuses every way in: shared/Config), every place the mowers live
-- wears a holographic padlock, and its prompt is switched off:
--   * the run's garage (its prompt opens the "Mowers" window), every gas pump (prompts with the Pump attribute: the
--     camp's and each area camp's), and the lobby's garage (its prompt opens the "Garage" window)
-- The lock: a padlock drawn as a hologram, a ForceField skin over a wireframe of neon edges, a glowing core, a bright
-- keyhole and a curved shackle. It turns slowly and bobs, a scan line sweeps up through it, now and then it glitches
-- (a jump sideways, a flicker), and data motes drift up off it. Under it a projector ring on the ground throws a
-- cone of light up to it (the films' pillar texture) and pulses rings out over the ground. "COMING SOON" floats over
-- it in our title style. Walk up to one: it flashes red, shakes and refuses (the "denied" sound), and a note says the
-- mowers come in a future update.
-- Client only, cosmetic. The locks near the camera move; far ones stand still. Potato Mode / phones: fewer particles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)
local Potato = require(script.Parent.Potato)
local PhonePerf = require(script.Parent.PhonePerf)

local MowerLock = {}

if not Config.MOWERS_LOCKED then
	return MowerLock
end

local player = Players.LocalPlayer
local CYAN = Color3.fromRGB(70, 220, 255)
local DEEP = Color3.fromRGB(40, 110, 255)
local PALE = Color3.fromRGB(200, 250, 255)
local DENY = Color3.fromRGB(255, 60, 80)
local GOLD = Color3.fromRGB(255, 236, 110)
local ORANGE = Color3.fromRGB(255, 140, 30)
local INK = Color3.fromRGB(30, 25, 45)
local FONT = (Config.UI and Config.UI.font) or Enum.Font.FredokaOne
local TEX = { -- (the films' VFX Forge textures: ReplicatedStorage.FilmVFX)
	pillar = "rbxassetid://106542030103669",
	ring = "rbxassetid://89007417158215",
	glow = "rbxassetid://108494962291607",
	mote = "rbxassetid://87871024708004",
	star = "rbxassetid://104954625098154",
}
-- the padlock, in studs at size 1: the body, and the shackle's arc over it
local BODY = Vector3.new(4, 3.2, 1)
local ARC_R, ARC_T, LEG = 1.25, 0.42, 0.85
local EDGE = 0.11
local ACTIVE = 260 -- locks this close to the camera move
local NEAR = 9 -- walk this close (plus its size) and it refuses

local folder = Instance.new("Folder")
folder.Name = "MowerLocks"
folder.Parent = workspace

type Lock = {
	root: BasePart,
	scan: BasePart,
	core: BasePart,
	keyhole: { BasePart },
	light: PointLight,
	burst: ParticleEmitter,
	model: Model,
	centre: Vector3,
	s: number,
	phase: number,
	nextGlitch: number,
	glitchUntil: number,
	denyUntil: number,
	inside: boolean,
}

local locks: { [ProximityPrompt]: Lock } = {}
local lastNote = 0

local function lowFx(): boolean
	return Potato.on or PhonePerf.on == true
end

local function seq(points: { { number } }): NumberSequence
	local k = {}
	for _, p in points do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(k)
end

-------------------------------------------------------------------------------------------------------------
-- building
-------------------------------------------------------------------------------------------------------------
local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material, transparency: number): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	p.CastShadow = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a piece of the lock, held to the root at `offset` (the root moves; the pieces follow)
local function piece(lock: Model, root: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, transparency: number): Part
	local p = part(lock, size, color, material, transparency)
	p.CFrame = root.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	return p
end

-- the wireframe: the body's 12 edges in neon (the front and back faces brighter than the sides)
local function wireframe(lock: Model, root: BasePart, s: number)
	local hx, hy, hz = BODY.X * s / 2, BODY.Y * s / 2, BODY.Z * s / 2
	local e = EDGE * s
	for _, z in { -hz, hz } do
		local alpha = if z < 0 then 0 else 0.35
		for _, y in { -hy, hy } do
			piece(lock, root, Vector3.new(BODY.X * s + e, e, e), CFrame.new(0, y, z), PALE, Enum.Material.Neon, alpha)
		end
		for _, x in { -hx, hx } do
			piece(lock, root, Vector3.new(e, BODY.Y * s + e, e), CFrame.new(x, 0, z), PALE, Enum.Material.Neon, alpha)
		end
	end
	for _, x in { -hx, hx } do
		for _, y in { -hy, hy } do
			piece(lock, root, Vector3.new(e, e, BODY.Z * s), CFrame.new(x, y, 0), CYAN, Enum.Material.Neon, 0.2)
		end
	end
	-- two bands across the front, like a padlock's casing
	for _, y in { -0.62, 0.62 } do
		piece(lock, root, Vector3.new(BODY.X * s * 0.92, e * 0.7, e * 0.7), CFrame.new(0, y * s * 1.6, -hz - e * 0.4), CYAN, Enum.Material.Neon, 0.45)
	end
end

-- the shackle: a half ring of ForceField with a neon core, and the two legs down into the body
local function shackle(lock: Model, root: BasePart, s: number)
	local top = BODY.Y * s / 2
	local r, t = ARC_R * s, ARC_T * s
	local cy = top + LEG * s
	local n = 14
	for i = 0, n - 1 do
		local a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
		local mid = (a0 + a1) / 2
		local len = 2 * r * math.sin((a1 - a0) / 2) + t * 0.32
		local at = CFrame.new(math.cos(mid) * r, cy + math.sin(mid) * r, 0) * CFrame.Angles(0, 0, mid + math.pi / 2)
		piece(lock, root, Vector3.new(len, t, t), at, CYAN, Enum.Material.ForceField, 0)
		piece(lock, root, Vector3.new(len, t * 0.32, t * 0.32), at, PALE, Enum.Material.Neon, 0.1)
	end
	for _, x in { -r, r } do
		local at = CFrame.new(x, top + LEG * s / 2 - 0.05 * s, 0)
		piece(lock, root, Vector3.new(t, LEG * s + 0.1 * s, t), at, CYAN, Enum.Material.ForceField, 0)
		piece(lock, root, Vector3.new(t * 0.32, LEG * s + 0.1 * s, t * 0.32), at, PALE, Enum.Material.Neon, 0.1)
	end
end

-- the keyhole on the front: a round head and a tapering slot, the brightest thing on the lock
local function keyhole(lock: Model, root: BasePart, s: number): { BasePart }
	local z = -BODY.Z * s / 2 - 0.06 * s
	local head = piece(lock, root, Vector3.new(0.12 * s, 0.78 * s, 0.78 * s), CFrame.new(0, 0.28 * s, z) * CFrame.Angles(0, math.rad(90), 0), PALE, Enum.Material.Neon, 0)
	head.Shape = Enum.PartType.Cylinder
	local slot = piece(lock, root, Vector3.new(0.34 * s, 0.85 * s, 0.12 * s), CFrame.new(0, -0.3 * s, z), PALE, Enum.Material.Neon, 0)
	return { head, slot }
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	local any = e :: any
	for k, v in props do
		any[k] = v
	end
	e.Parent = parent
	return e
end

local function body(lock: Model, root: BasePart, s: number): (BasePart, PointLight)
	piece(lock, root, BODY * s, CFrame.new(), CYAN, Enum.Material.ForceField, 0)
	local core = piece(lock, root, Vector3.new(BODY.X * 0.84, BODY.Y * 0.8, BODY.Z * 0.4) * s, CFrame.new(), DEEP, Enum.Material.Neon, 0.78)
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Brightness = 1.8
	light.Range = 12 * s
	light.Shadows = false
	light.Parent = core
	-- data motes drifting up off it
	emitter(core, {
		Texture = TEX.star,
		Color = ColorSequence.new(CYAN, PALE),
		Rate = if lowFx() then 2 else 6,
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(1.2, 2.6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 35),
		Rotation = NumberRange.new(0, 90),
		Size = seq({ { 0, 0.05 * s }, { 0.3, 0.32 * s }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
	})
	return core, light
end

-- the projector: a ring on the ground, the cone of light from it up to the lock, rings pulsing out
local function projector(lock: Model, root: BasePart, ground: Vector3, radius: number, s: number): ParticleEmitter
	local base = part(lock, Vector3.new(0.2, radius * 2, radius * 2), CYAN, Enum.Material.Neon, 0.15)
	base.Anchored = true
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(ground + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local inner = part(lock, Vector3.new(0.24, radius * 2 - 0.5 * s, radius * 2 - 0.5 * s), Color3.fromRGB(14, 22, 38), Enum.Material.SmoothPlastic, 0.25)
	inner.Anchored = true
	inner.Shape = Enum.PartType.Cylinder
	inner.CFrame = base.CFrame
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	a0.WorldPosition = ground + Vector3.new(0, 0.3, 0)
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -BODY.Y * s / 2, 0)
	a1.Parent = root
	for _, b in { { w0 = 0.8, w1 = 4.4, alpha = 0.62, speed = 0.5, col = CYAN }, { w0 = 0.35, w1 = 2.2, alpha = 0.45, speed = 1.2, col = PALE } } do
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Texture = TEX.pillar
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 6 * s
		beam.TextureSpeed = b.speed
		beam.Width0 = b.w0 * s
		beam.Width1 = b.w1 * s
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 12
		beam.Color = ColorSequence.new(b.col)
		beam.Transparency = seq({ { 0, b.alpha }, { 0.8, b.alpha + (1 - b.alpha) * 0.4 }, { 1, 0.95 } })
		beam.Parent = base
	end
	-- rings pulsing out flat over the ground
	local pulse = emitter(a0, {
		Texture = TEX.ring,
		Color = ColorSequence.new(CYAN),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Rate = if lowFx() then 0.4 else 0.8,
		Lifetime = NumberRange.new(1.6),
		Size = seq({ { 0, radius * 0.9 }, { 1, radius * 2.6 } }),
		Transparency = seq({ { 0, 0.3 }, { 1, 1 } }),
	})
	return pulse
end

-- "COMING SOON" over it, in our title style (gold over orange, the dark outline)
local function sign(lock: Model, centre: Vector3, s: number)
	local anchor = part(lock, Vector3.new(0.2, 0.2, 0.2), CYAN, Enum.Material.SmoothPlastic, 1)
	anchor.Anchored = true
	anchor.CFrame = CFrame.new(centre + Vector3.new(0, (BODY.Y / 2 + LEG + ARC_R + 1.9) * s, 0))
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.new(9 * s, 0, 2.7 * s, 0)
	g.LightInfluence = 0
	g.MaxDistance = 150
	g.Parent = anchor
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = FONT
	title.Text = "COMING SOON"
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.52, GOLD),
		ColorSequenceKeypoint.new(0.56, ORANGE),
		ColorSequenceKeypoint.new(1, Color3.new(ORANGE.R * 0.85, ORANGE.G * 0.85, ORANGE.B * 0.85)),
	})
	grad.Parent = title
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = 3
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = title
	title.Parent = g
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(1, 0.34)
	sub.Position = UDim2.fromScale(0, 0.64)
	sub.BackgroundTransparency = 1
	sub.Font = FONT
	sub.Text = "Ride-on mowers & gas: next update"
	sub.TextScaled = true
	sub.TextColor3 = PALE
	local st2 = Instance.new("UIStroke")
	st2.Color = INK
	st2.Thickness = 2
	st2.Parent = sub
	sub.Parent = g
end

local function ground(at: Vector3): Vector3
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { folder }
	if player.Character then
		table.insert(skip, player.Character)
	end
	rp.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), rp)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

local function build(centre: Vector3, floor: Vector3, ringRadius: number, s: number): Lock
	local lock = Instance.new("Model")
	lock.Name = "MowerLock"
	local root = part(lock, Vector3.new(0.2, 0.2, 0.2), CYAN, Enum.Material.SmoothPlastic, 1)
	root.Name = "Root"
	root.Anchored = true
	root.CFrame = CFrame.new(centre)
	lock.PrimaryPart = root
	local core, light = body(lock, root, s)
	wireframe(lock, root, s)
	shackle(lock, root, s)
	local holes = keyhole(lock, root, s)
	local burst = projector(lock, root, floor, ringRadius, s)
	-- the scan line: sweeps up through the lock (moved each frame, not welded)
	local scan = part(lock, Vector3.new(BODY.X * 1.18, 0.06, BODY.Z * 1.5) * s, PALE, Enum.Material.Neon, 0.25)
	scan.Anchored = true
	sign(lock, centre, s)
	lock.Parent = folder
	return {
		root = root,
		scan = scan,
		core = core,
		keyhole = holes,
		light = light,
		burst = burst,
		model = lock,
		centre = centre,
		s = s,
		phase = math.random() * 10,
		nextGlitch = os.clock() + 2 + math.random() * 4,
		glitchUntil = 0,
		denyUntil = 0,
		inside = false,
	}
end

-------------------------------------------------------------------------------------------------------------
-- where they stand: each locked prompt's place
-------------------------------------------------------------------------------------------------------------
local function kindOf(p: ProximityPrompt): string?
	if p:GetAttribute("Pump") then
		return "pump"
	end
	local w = p:GetAttribute("Window")
	if w == "Mowers" then
		return "garage"
	elseif w == "Garage" then
		return "lobbyGarage"
	end
	return nil
end

local function placeFor(kind: string, holder: BasePart): (Vector3, Vector3, number, number)
	if kind == "pump" then
		-- over the pump: a small lock, its projector on the pump's top
		local top = holder.Position + Vector3.new(0, holder.Size.Y / 2, 0)
		local s = 0.62
		return top + Vector3.new(0, (BODY.Y / 2 + 1.6) * s, 0), top, 1.1, s
	elseif kind == "garage" then
		-- in front of the garage's open door: a big lock over the bay
		local floor = ground(holder.Position)
		local s = 1.25
		return floor + Vector3.new(0, (BODY.Y / 2 + 2.6) * s, 0), floor, 3.4, s
	else
		-- the lobby: over the mower on its turntable, the ring round the turntable
		local floor = ground(holder.Position)
		local s = 1.3
		return floor + Vector3.new(0, 4.6 + (BODY.Y / 2 + 1.4) * s, 0), floor, 5.6, s
	end
end

local function remove(p: ProximityPrompt)
	local l = locks[p]
	if l then
		locks[p] = nil
		l.model:Destroy()
	end
end

local function watch(p: ProximityPrompt)
	if locks[p] then
		return
	end
	local kind = kindOf(p)
	local holder = p.Parent
	if not kind then
		-- (a pump's Pump attribute is set just after its prompt is made: look again when it arrives)
		local c: RBXScriptConnection? = nil
		c = p.AttributeChanged:Connect(function()
			if kindOf(p) then
				if c then
					c:Disconnect()
				end
				watch(p)
			end
		end)
		return
	end
	if not holder or not holder:IsA("BasePart") then
		return
	end
	-- its prompt stays off (the server would refuse it anyway)
	p.Enabled = false
	p:GetPropertyChangedSignal("Enabled"):Connect(function()
		if p.Enabled then
			p.Enabled = false
		end
	end)
	local centre, floor, radius, s = placeFor(kind, holder)
	locks[p] = build(centre, floor, radius, s)
	p.AncestryChanged:Connect(function(_, parent)
		if not parent or not p:IsDescendantOf(workspace) then
			remove(p)
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the motion: turning, bobbing, the scan line, the glitches, refusing you
-------------------------------------------------------------------------------------------------------------
local function refuse(l: Lock, now: number)
	l.denyUntil = now + 0.55
	l.burst:Emit(2)
	Sound.play("denied", 0.05, 0.5)
	if now - lastNote > 8 then
		lastNote = now
		pcall(UI.toast, Config.MOWERS_LOCKED_TEXT, "yellow")
	end
end

local function animate(l: Lock, now: number, me: Vector3?)
	local t = now + l.phase
	local s = l.s
	local offset = Vector3.new(0, math.sin(t * 1.6) * 0.18 * s, 0)
	-- glitch: a jump sideways and a flicker for a few frames, every few seconds
	if now >= l.nextGlitch then
		l.glitchUntil = now + 0.07 + math.random() * 0.06
		l.nextGlitch = now + 2.5 + math.random() * 4
	end
	local glitching = now < l.glitchUntil
	if glitching then
		offset += Vector3.new((math.random() - 0.5) * 0.5 * s, 0, (math.random() - 0.5) * 0.3 * s)
	end
	-- refusing: a hard shake, the core red
	local denying = now < l.denyUntil
	if denying then
		local k = (l.denyUntil - now) / 0.55
		offset += Vector3.new(math.sin(now * 70) * 0.35 * s * k, 0, 0)
	end
	l.root.CFrame = CFrame.new(l.centre + offset) * CFrame.Angles(0, t * 0.55, 0)
	-- the scan line: up through the body and the shackle, then again
	local lo, hi = -BODY.Y * s / 2 - 0.2 * s, (BODY.Y / 2 + LEG + ARC_R) * s
	local k = (t * 0.45) % 1
	l.scan.CFrame = l.root.CFrame * CFrame.new(0, lo + (hi - lo) * k, 0)
	l.scan.Transparency = if glitching then 1 else 0.2 + 0.6 * k
	l.core.Color = if denying then DENY else DEEP
	l.core.Transparency = if denying then 0.45 elseif glitching then 0.55 else 0.78 + 0.06 * math.sin(t * 5)
	l.light.Color = if denying then DENY else CYAN
	l.light.Brightness = if denying then 4 else 1.8 + 0.4 * math.sin(t * 3)
	for _, h in l.keyhole do
		h.Color = if denying then DENY else PALE
	end
	-- walk up to it: it refuses (once each time you come close)
	if me then
		local near = (Vector3.new(me.X, l.centre.Y, me.Z) - l.centre).Magnitude < NEAR * s
		if near and not l.inside then
			refuse(l, now)
		end
		l.inside = near
	end
end

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam or next(locks) == nil then
		return
	end
	local now = os.clock()
	local eye = cam.CFrame.Position
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local me = if hrp then hrp.Position else nil
	for _, l in locks do
		if (l.centre - eye).Magnitude < ACTIVE then
			animate(l, now, me)
		end
	end
end)

for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		task.defer(watch, d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		-- (a frame later: the server sets its attributes right after making it)
		task.defer(watch, d)
	end
end)

return MowerLock
]=====]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "19021 1038508881" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.StarterPlayer.StarterPlayerScripts.MowALawnClient
if folder:FindFirstChild("MowerLock") then
	return "MowerLock is already there: " .. hashOf(folder.MowerLock.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "MowerLock"
m.Source = src
m.Parent = folder
return "MowerLock installed: " .. hashOf(m.Source)
