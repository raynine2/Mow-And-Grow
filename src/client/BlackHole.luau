-- The CLASSES black hole (client). server/BlackHole builds the stand; this makes it move and makes it a door:
--   * the accretion disk's spirals turn (outside slow, the hot middle fast), the halo breathes, the photon ring
--     shimmers, the abyss swirls, chunks of meadow orbit and bob, the sign floats, and every few seconds a gravity
--     pulse sweeps in over the ground
--   * bits of the meadow (grass, dirt, stone, gold, a few glowing chips) orbit in the disk and spiral in, faster
--     as they fall, fading as they cross the horizon (only while you're near)
--   * JUMP IN (or the prompt in front): you're pulled in on a spiral, tumbling, while the screen warps (wider view,
--     a violet swirl, speed lines, blur, colours drained) and the dark closes in from the middle; a flash, and the
--     Classes window opens (the space class room, client/ClassRoom). Meanwhile your avatar waits inside the event
--     horizon, so everyone else just sees you vanish into it.
--   * Close the window: the hole throws you back out the front in a front flip, with a shock ring, a burst of
--     sparks and a whoosh. Other players going in or out get a smaller gulp / burst on your screen too.
-- Jumping near it helps a little: in the air within a few studs, you're drawn towards it.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)

local BlackHole = {}

local player = Players.LocalPlayer
local NEAR = 160 -- the stand animates while the camera is this close
local REACH = 1.4 -- the jump-in sphere: the horizon plus this
local ASSIST = 9 -- in the air within this (flat studs): drawn towards the hole
local PULL = 1.15 -- seconds to be pulled in
local THROW = 0.55 -- seconds to be thrown out
local COOLDOWN = 2.5

local TEX = {
	spark = "rbxassetid://83908233620100",
	star = "rbxassetid://116900531496449",
	shock = "rbxassetid://106841140676000",
	spiral = "rbxassetid://8210105100",
	lines = "rbxassetid://110976543463529",
	glow = "rbxassetid://125552447014366",
}
local CHIPS = {
	{ Color3.fromRGB(88, 158, 44), Enum.Material.Grass },
	{ Color3.fromRGB(120, 190, 60), Enum.Material.Grass },
	{ Color3.fromRGB(116, 82, 52), Enum.Material.Ground },
	{ Color3.fromRGB(150, 150, 160), Enum.Material.Slate },
	{ Color3.fromRGB(226, 176, 74), Enum.Material.Metal },
	{ Color3.fromRGB(170, 120, 255), Enum.Material.Neon },
	{ Color3.fromRGB(120, 225, 255), Enum.Material.Neon },
}
local CHIP_COUNT = 22

local function potato(): boolean
	return player:GetAttribute("Potato") == true
end

-------------------------------------------------------------------------------------------------------------
-- the stands
-------------------------------------------------------------------------------------------------------------
type Chip = { part: BasePart, r: number, a: number, h: number, spin: Vector3, born: number }
type Stand = {
	core: BasePart,
	folder: Instance,
	radius: number,
	disk: number,
	tilt: number,
	spins: { { img: ImageLabel, speed: number } },
	lens: { [string]: ImageLabel },
	chunks: { { model: Model, r: number, a: number, y: number, turn: CFrame, phase: number } },
	nextPulse: number,
	sign: BillboardGui?,
	chips: { Chip },
	chipFolder: Folder?,
	burst: ParticleEmitter?,
	boost: number, -- spin-up after someone goes in or out (decays)
	inside: { [Player]: boolean },
}

local stands: { [BasePart]: Stand } = {}
local rng = Random.new()

local function centre(s: Stand): CFrame
	return s.core.CFrame
end
-- the floor in the middle of the stand, facing its front
local function floor(s: Stand): CFrame
	local h = s.core:GetAttribute("HoleY")
	return s.core.CFrame * CFrame.new(0, -(if type(h) == "number" then h else 10), 0)
end
local function tiltCf(s: Stand): CFrame
	return s.core.CFrame * CFrame.Angles(math.rad(s.tilt), 0, 0)
end

local function addStand(core: BasePart)
	if stands[core] or not core:GetAttribute("BlackHole") then
		return
	end
	local folder = core.Parent :: Instance
	local s: Stand = {
		core = core,
		folder = folder,
		radius = (core:GetAttribute("Radius") :: number?) or 3.4,
		disk = (core:GetAttribute("Disk") :: number?) or 12,
		tilt = (core:GetAttribute("Tilt") :: number?) or 14,
		spins = {},
		lens = {},
		chunks = {},
		nextPulse = 0,
		sign = nil,
		chips = {},
		boost = 0,
		inside = {},
	}
	local disk = folder:FindFirstChild("Disk")
	for _, sg in (if disk then disk:GetChildren() else {}) do
		if sg:IsA("SurfaceGui") then
			local dir = if sg.Face == Enum.NormalId.Bottom then -1 else 1
			for name, speed in { Outer = -22, Mid = -55, Hot = -130, Haze = -8 } do
				local img = sg:FindFirstChild(name)
				if img and img:IsA("ImageLabel") then
					table.insert(s.spins, { img = img, speed = speed * dir })
				end
			end
		end
	end
	local well = folder:FindFirstChild("Well")
	local wg = well and well:FindFirstChild("WellGui")
	for name, speed in { Rune = 10, Ring = -28, Vortex = 70, Vortex2 = 125 } do
		local img = wg and wg:FindFirstChild(name)
		if img and img:IsA("ImageLabel") then
			table.insert(s.spins, { img = img, speed = speed })
		end
	end
	local lens = core:FindFirstChild("Lens")
	for _, name in { "Halo", "Swirl", "Arc", "Photon" } do
		local img = lens and lens:FindFirstChild(name)
		if img and img:IsA("ImageLabel") then
			s.lens[name] = img
		end
	end
	for i, c in folder:GetChildren() do
		if c.Name == "Chunk" and c:IsA("Model") then
			local turn = c:GetAttribute("Turn")
			table.insert(s.chunks, {
				model = c,
				r = (c:GetAttribute("OrbitR") :: number?) or 8,
				a = (c:GetAttribute("OrbitA") :: number?) or i,
				y = (c:GetAttribute("OrbitY") :: number?) or 4,
				turn = if typeof(turn) == "CFrame" then turn else CFrame.identity,
				phase = i * 1.7,
			})
		end
	end
	local spot = folder:FindFirstChild("SignSpot")
	local sign = spot and spot:FindFirstChild("Sign")
	s.sign = if sign and sign:IsA("BillboardGui") then sign else nil
	stands[core] = s
	core.Destroying:Once(function()
		local st = stands[core]
		if st and st.chipFolder then
			st.chipFolder:Destroy()
		end
		stands[core] = nil
	end)
end

for _, d in workspace:GetDescendants() do
	if d.Name == "Singularity" and d:IsA("BasePart") then
		addStand(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d.Name == "Singularity" and d:IsA("BasePart") then
		task.defer(addStand, d) -- (its halo and the disk arrive with it)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- chips of the meadow orbiting and falling in
-------------------------------------------------------------------------------------------------------------
local function respawn(s: Stand, c: Chip, now: number, anywhere: boolean)
	c.r = if anywhere then rng:NextNumber(s.radius + 1, s.disk - 0.5) else rng:NextNumber(s.disk - 2.5, s.disk - 0.3)
	c.a = rng:NextNumber(0, math.pi * 2)
	c.h = rng:NextNumber(-0.7, 0.7)
	c.spin = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
	c.born = now
end

local function makeChips(s: Stand)
	local f = Instance.new("Folder")
	f.Name = "BlackHoleChips"
	f.Parent = workspace
	s.chipFolder = f
	local now = os.clock()
	for i = 1, CHIP_COUNT do
		local look = CHIPS[(i - 1) % #CHIPS + 1]
		local p = Instance.new("Part")
		p.Name = "Chip"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = look[1]
		p.Material = look[2]
		local size = rng:NextNumber(0.35, 0.8)
		p.Size = Vector3.new(size, size * rng:NextNumber(0.6, 1), size)
		p.Parent = f
		local c: Chip = { part = p, r = 0, a = 0, h = 0, spin = Vector3.zero, born = 0 }
		respawn(s, c, now - 2, true)
		table.insert(s.chips, c)
	end
end

local chipParts: { BasePart } = {}
local chipCfs: { CFrame } = {}
local function moveChips(s: Stand, dt: number, now: number)
	if not s.chipFolder then
		makeChips(s)
	end
	local tilt = tiltCf(s)
	local speedUp = 1 + s.boost * 2
	table.clear(chipParts)
	table.clear(chipCfs)
	for _, c in s.chips do
		-- Kepler-ish: closer in, faster round and faster down
		local k = 6 / math.max(c.r, 0.5)
		c.a += 1.6 * k ^ 1.5 * dt * speedUp
		c.r -= 0.55 * k * dt * speedUp
		if c.r <= s.radius - 0.2 then
			respawn(s, c, now, false)
		end
		local t = now - c.born
		local fadeIn = math.clamp(t, 0, 1)
		local fadeOut = math.clamp((c.r - s.radius) / 1.4, 0, 1)
		c.part.Transparency = 1 - fadeIn * fadeOut
		local pos = tilt * Vector3.new(math.cos(c.a) * c.r, c.h * (c.r / s.disk), math.sin(c.a) * c.r)
		table.insert(chipParts, c.part)
		table.insert(chipCfs, CFrame.new(pos) * CFrame.Angles(c.spin.X * now, c.spin.Y * now, c.spin.Z * now))
	end
	workspace:BulkMoveTo(chipParts, chipCfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function hideChips(s: Stand)
	if s.chipFolder then
		s.chipFolder:Destroy()
		s.chipFolder = nil
		table.clear(s.chips)
	end
end

-------------------------------------------------------------------------------------------------------------
-- little effects at a stand: a shock ring, a burst of sparks, a 3D sound
-------------------------------------------------------------------------------------------------------------
local function sound3d(s: Stand, key: string, volume: number?)
	local def = Config.SOUNDS[key]
	if not def or def.id == "" then
		return
	end
	local snd = Instance.new("Sound")
	snd.SoundId = def.id
	snd.Volume = (def.volume or 0.5) * (volume or 1)
	snd.PlaybackSpeed = def.pitch or 1
	snd.RollOffMinDistance = 12
	snd.RollOffMaxDistance = 90
	snd.Parent = s.core
	snd:Play()
	task.delay(4, function()
		snd:Destroy()
	end)
end

local function shock(s: Stand, from: number, to: number, time: number, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Shock"
	bb.Size = UDim2.fromScale(from, from)
	bb.LightInfluence = 0
	bb.Brightness = 3
	bb.MaxDistance = 300
	bb.Parent = s.core
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.shock
	img.ImageColor3 = color
	img.Parent = bb
	local info = TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { Size = UDim2.fromScale(to, to) }):Play()
	TweenService:Create(img, info, { ImageTransparency = 1 }):Play()
	task.delay(time + 0.1, function()
		bb:Destroy()
	end)
end

-- a gravity pulse: a ring sweeping in over the ground to the abyss
local function pulse(s: Stand)
	local ring = Instance.new("Part")
	ring.Name = "GravityPulse"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Size = Vector3.new(30, 0.05, 30)
	ring.CFrame = floor(s) * CFrame.new(0, 0.3, 0)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(256, 256)
	sg.Parent = ring
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.shock
	img.ImageColor3 = Color3.fromRGB(170, 120, 255)
	img.ImageTransparency = 1
	img.Parent = sg
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(6, 0.05, 6) }):Play()
	TweenService:Create(img, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { ImageTransparency = 0.35 }):Play()
	task.delay(0.6, function()
		TweenService:Create(img, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 }):Play()
	end)
	task.delay(1.6, function()
		ring:Destroy()
	end)
end

local function burst(s: Stand, n: number)
	if potato() then
		return
	end
	local e = s.burst
	if not e then
		local made = Instance.new("ParticleEmitter")
		made.Name = "Burst"
		made.Enabled = false
		made.Texture = TEX.spark
		made.LightInfluence = 0
		made.LightEmission = 1
		made.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(150, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 100, 255)),
		})
		made.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		made.Squash = NumberSequence.new(-2.5)
		made.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		made.Lifetime = NumberRange.new(0.5, 0.9)
		made.Speed = NumberRange.new(22, 40)
		made.Drag = 4
		made.Orientation = Enum.ParticleOrientation.VelocityParallel
		made.Shape = Enum.ParticleEmitterShape.Sphere
		made.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		made.Parent = s.core
		s.burst = made
		e = made
	end
	(e :: ParticleEmitter):Emit(n)
end

-------------------------------------------------------------------------------------------------------------
-- the warp on your screen while you fall in
-------------------------------------------------------------------------------------------------------------
type Warp = { gui: ScreenGui, dark: ImageLabel, black: Frame, swirl: ImageLabel, lines: ImageLabel, flash: Frame }
local warp: Warp? = nil

local function square(parent: Instance, name: string, tex: string, color: Color3, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	i.SizeConstraint = Enum.SizeConstraint.RelativeXX
	i.Size = UDim2.fromScale(0, 0)
	i.Image = tex
	i.ImageColor3 = color
	i.ImageTransparency = 1
	i.ZIndex = z
	i.Parent = parent
	return i
end

local function getWarp(): Warp
	if warp and warp.gui.Parent then
		return warp
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlackHoleWarp"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local lines = square(gui, "Lines", TEX.lines, Color3.fromRGB(230, 220, 255), 1)
	lines.Size = UDim2.fromScale(1.7, 1.7)
	local swirl = square(gui, "Swirl", TEX.spiral, Color3.fromRGB(170, 110, 255), 2)
	swirl.Size = UDim2.fromScale(2.3, 2.3)
	local dark = square(gui, "Dark", TEX.glow, Color3.new(0, 0, 0), 3)
	dark.ImageTransparency = 0
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.ZIndex = 4
	black.Parent = gui
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.fromRGB(235, 225, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 5
	flash.Parent = gui
	warp = { gui = gui, dark = dark, black = black, swirl = swirl, lines = lines, flash = flash }
	return warp :: Warp
end

local cc: ColorCorrectionEffect? = nil
local blur: BlurEffect? = nil
local baseFov = 70

local function screenFx(k: number, now: number)
	-- k: 0 (nothing) .. 1 (fully in)
	local w = getWarp()
	w.gui.Enabled = k > 0
	local a = math.clamp((k - 0.3) / 0.7, 0, 1)
	w.swirl.ImageTransparency = 1 - a * 0.7
	w.swirl.Rotation = now * 260
	w.lines.ImageTransparency = 1 - a * 0.55
	w.lines.Rotation = -now * 90
	local d = math.clamp((k - 0.5) / 0.5, 0, 1)
	w.dark.Size = UDim2.fromScale(d * d * 3.6, d * d * 3.6)
	if not cc then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "BlackHoleCC"
		made.Parent = Lighting
		cc = made
	end
	if not blur and not potato() then
		local made = Instance.new("BlurEffect")
		made.Name = "BlackHoleBlur"
		made.Size = 0
		made.Parent = Lighting
		blur = made
	end
	local c = cc :: ColorCorrectionEffect
	c.Saturation = -0.65 * a
	c.Contrast = 0.3 * a
	c.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 170, 255), a)
	if blur then
		blur.Size = 16 * a * a
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = baseFov + 30 * a * a
	end
end

local function clearScreenFx()
	if cc then
		cc:Destroy()
		cc = nil
	end
	if blur then
		blur:Destroy()
		blur = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = baseFov
	end
end

-------------------------------------------------------------------------------------------------------------
-- going in and coming out
-------------------------------------------------------------------------------------------------------------
local state: "idle" | "pull" | "inside" | "throw" = "idle"
local current: Stand? = nil
local phaseStart = 0
local pullFrom = Vector3.zero
local holdConn: RBXScriptConnection? = nil
local fxConn: RBXScriptConnection? = nil
local cooldownUntil = 0

local function parts(): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if char and hum and hum.Health > 0 and root then
		return char, hum, root
	end
	return nil, nil, nil
end

local function easeIn(k: number): number
	return k * k * (1.6 - 0.6 * k) -- (gentle start, falling fast at the end)
end

-- where the root should be right now (and how it's turned)
local function heldCFrame(s: Stand, now: number): CFrame
	local c = centre(s)
	if state == "pull" then
		local k = math.clamp((now - phaseStart) / PULL, 0, 1)
		local e = easeIn(k)
		local axis = tiltCf(s).UpVector
		local from = pullFrom - c.Position
		local turned = CFrame.fromAxisAngle(axis, e * math.pi * 2.6):VectorToWorldSpace(from) * (1 - e)
		local pos = c.Position + turned
		local look = if (c.Position - pos).Magnitude > 0.05 then CFrame.lookAt(pos, c.Position) else CFrame.new(pos)
		return look * CFrame.Angles(-math.pi * 0.5 * e, 0, 0) * CFrame.Angles(0, e * 11, 0)
	elseif state == "throw" then
		local k = math.clamp((now - phaseStart) / THROW, 0, 1)
		local e = 1 - (1 - k) ^ 3
		local front = floor(s).LookVector
		local up = Vector3.yAxis
		local to = floor(s).Position + front * 10.5 + up * 3.2
		local ctrl = c.Position + front * 6 + up * 3
		local a = c.Position:Lerp(ctrl, e)
		local b = ctrl:Lerp(to, e)
		local pos = a:Lerp(b, e)
		return CFrame.lookAt(pos, pos + front) * CFrame.Angles(-(1 - e) * math.pi * 2, 0, 0)
	end
	-- inside: waiting in the middle, out of sight
	return CFrame.new(c.Position) * CFrame.Angles(0, now * 0.5, 0)
end

local function stopHold()
	if holdConn then
		holdConn:Disconnect()
		holdConn = nil
	end
	if fxConn then
		fxConn:Disconnect()
		fxConn = nil
	end
end

local function release(hum: Humanoid?, root: BasePart?, s: Stand?)
	stopHold()
	if hum then
		hum.PlatformStand = false
		hum.AutoRotate = true
		hum.CameraOffset = Vector3.zero
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	if root and s then
		root.AssemblyLinearVelocity = floor(s).LookVector * 9 + Vector3.new(0, 7, 0)
		root.AssemblyAngularVelocity = Vector3.zero
	end
	state = "idle"
	current = nil
	cooldownUntil = os.clock() + COOLDOWN
end

local function hold(s: Stand)
	stopHold()
	holdConn = RunService.PreSimulation:Connect(function()
		local _, hum, root = parts()
		if not (hum and root) then
			return
		end
		root.CFrame = heldCFrame(s, os.clock())
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

local exit: (Stand) -> ()

local function enter(s: Stand)
	local _, hum, root = parts()
	if state ~= "idle" or not (hum and root) or os.clock() < cooldownUntil or hum.SeatPart then
		return
	end
	if UI.isOpen("Classes") then
		return
	end
	state = "pull"
	current = s
	phaseStart = os.clock()
	pullFrom = root.Position
	local cam = workspace.CurrentCamera
	baseFov = if cam and cam.FieldOfView < 90 then cam.FieldOfView else 70
	hum.PlatformStand = true
	hum.AutoRotate = false
	hold(s)
	s.boost = 1
	Sound.play("bhPull")
	Sound.play("bhWarp")
	shock(s, 4, 15, 0.7, Color3.fromRGB(190, 150, 255))
	-- the warp on screen, driven by how far in you are; at the end: black, a flash, the class room
	fxConn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local k = math.clamp((now - phaseStart) / PULL, 0, 1)
		local _, h = parts()
		if h then
			local shake = 0.35 * k * k
			h.CameraOffset = Vector3.new(rng:NextNumber(-shake, shake), rng:NextNumber(-shake, shake), 0)
		end
		screenFx(k, now)
	end)
	task.delay(PULL, function()
		if state ~= "pull" or current ~= s then
			return
		end
		if fxConn then
			fxConn:Disconnect()
			fxConn = nil
		end
		local w = getWarp()
		w.black.BackgroundTransparency = 0
		local _, h = parts()
		if h then
			h.CameraOffset = Vector3.zero
		end
		clearScreenFx() -- (the screen is black: put the view back before the class room takes the camera)
		burst(s, 18)
		sound3d(s, "bhPop", 0.7)
		task.wait(0.12)
		if state ~= "pull" or current ~= s then
			w.gui.Enabled = false
			return
		end
		w.flash.BackgroundTransparency = 0
		UI.open("Classes")
		state = "inside"
		phaseStart = os.clock()
		local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(w.black, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(w.flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		task.delay(0.65, function()
			if w.black.BackgroundTransparency > 0.99 then
				w.gui.Enabled = false
				w.swirl.ImageTransparency = 1
				w.lines.ImageTransparency = 1
				w.dark.Size = UDim2.fromScale(0, 0)
			end
		end)
		-- (no class screen here, e.g. it failed to open: straight back out)
		task.delay(0.3, function()
			if state == "inside" and current == s and not UI.isOpen("Classes") then
				exit(s)
			end
		end)
	end)
end

exit = function(s: Stand)
	if state ~= "inside" then
		return
	end
	state = "throw"
	phaseStart = os.clock()
	s.boost = 1
	Sound.play("bhOut")
	sound3d(s, "bhPop")
	shock(s, 5, 30, 0.8, Color3.fromRGB(150, 225, 255))
	task.delay(0.08, function()
		shock(s, 3, 18, 0.6, Color3.fromRGB(255, 220, 170))
	end)
	burst(s, 40)
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = baseFov + 14
		TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { FieldOfView = baseFov }):Play()
	end
	task.delay(THROW, function()
		if state ~= "throw" or current ~= s then
			return
		end
		local _, hum, root = parts()
		release(hum, root, s)
	end)
end

UI.onWindowChanged.Event:Connect(function()
	-- (signals can arrive late - the "closed" that opening fires first comes after we're inside - so ask the UI
	-- whether the class screen is really shut)
	local s = current
	if state == "inside" and s and not UI.isOpen("Classes") then
		task.defer(exit, s) -- (after the class room has given the camera back)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if not prompt:GetAttribute("BlackHole") then
		return
	end
	local folder = prompt.Parent and prompt.Parent.Parent
	for _, s in stands do
		if s.folder == folder then
			enter(s)
			return
		end
	end
end)

-- a new character (died in there, reset): nothing held, the screen clear
local function reset()
	stopHold()
	clearScreenFx()
	if warp then
		warp.gui.Enabled = false
		warp.black.BackgroundTransparency = 1
		warp.flash.BackgroundTransparency = 1
	end
	state = "idle"
	current = nil
end
player.CharacterAdded:Connect(reset)
player.CharacterRemoving:Connect(reset)

-------------------------------------------------------------------------------------------------------------
-- every frame: animate the near stands, jump-in checks, others going in and out
-------------------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local now = os.clock()
	local camPos = cam.CFrame.Position
	local _, hum, root = parts()
	for _, s in stands do
		local c = centre(s)
		if (camPos - c.Position).Magnitude > NEAR then
			hideChips(s)
			continue
		end
		s.boost = math.max(0, s.boost - dt * 0.6)
		local speedUp = 1 + s.boost * 2.5
		for _, sp in s.spins do
			sp.img.Rotation = (sp.img.Rotation + sp.speed * dt * speedUp) % 360
		end
		local L = s.lens
		if L.Swirl then
			L.Swirl.Rotation = (L.Swirl.Rotation + 34 * dt * speedUp) % 360
		end
		if L.Arc then
			L.Arc.Rotation = (L.Arc.Rotation - 12 * dt * speedUp) % 360
		end
		if L.Halo then
			L.Halo.ImageTransparency = 0.25 + 0.08 * math.sin(now * 1.3) - 0.15 * s.boost
		end
		if L.Photon then
			local sz = 0.47 + 0.008 * math.sin(now * 3.1) + 0.04 * s.boost
			L.Photon.Size = UDim2.fromScale(sz, sz)
			L.Photon.ImageTransparency = 0.05 * (1 + math.sin(now * 7.3))
		end
		local base = floor(s)
		for _, ch in s.chunks do
			local a = ch.a + now * 0.16
			local pos = base * Vector3.new(math.cos(a) * ch.r, ch.y + math.sin(now * 1.1 + ch.phase) * 0.5, math.sin(a) * ch.r)
			ch.model:PivotTo(CFrame.new(pos) * ch.turn * CFrame.Angles(0, now * 0.35 + ch.phase, 0))
		end
		if now >= s.nextPulse and not potato() then
			s.nextPulse = now + 2.6
			pulse(s)
		end
		if s.sign then
			s.sign.StudsOffset = Vector3.new(0, math.sin(now * 1.2) * 0.3, 0)
		end
		if potato() then
			hideChips(s)
		else
			moveChips(s, dt, now)
		end
		-- other players disappearing into it / coming back out
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local inNow = r ~= nil and (r.Position - c.Position).Magnitude < s.radius - 0.3
				if inNow ~= (s.inside[p] == true) then
					s.inside[p] = inNow or nil
					s.boost = 1
					if inNow then
						shock(s, 4, 12, 0.5, Color3.fromRGB(190, 150, 255))
						sound3d(s, "bhPop", 0.5)
					else
						shock(s, 4, 22, 0.7, Color3.fromRGB(150, 225, 255))
						burst(s, 24)
						sound3d(s, "bhOut", 0.6)
					end
				end
			end
		end
		-- you: jump in (or be drawn towards it in the air)
		if state == "idle" and hum and root and now >= cooldownUntil and not hum.SeatPart then
			local to = c.Position - root.Position
			if to.Magnitude < s.radius + REACH then
				enter(s)
			else
				local flat = Vector3.new(to.X, 0, to.Z).Magnitude
				local st = hum:GetState()
				if flat < ASSIST and (st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping) and to.Y > -2 then
					root.AssemblyLinearVelocity += to.Unit * 40 * dt
				end
			end
		end
	end
end)

return BlackHole
