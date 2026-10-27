-- The class room (client only), SPACE edition: while the CLASSES window is open the camera cuts to deep space high
-- above the map. Your avatar (a clone) floats there in a zero-g pose, flying forward through the stars:
--   * a star-box all round (six far walls painted with stars and slowly turning nebulae), two planets (one ringed)
--     and a moon turning in the distance, asteroids tumbling past
--   * warp streaks and dust rushing past the avatar, a comet tail of its card's colour streaming behind it; no
--     platform - it floats free
--   * the body is alive (the organic-animation notes): torso leads, chest / arms / head / legs follow on lagged sines,
--     a slow bob, sway and roll, and now and then a slow showy turn
--   * a cinematic camera: always drifting a little (handheld noise), and every 9-13 s it glides (3 s Sine InOut) to
--     another framing - front, three-quarter low, three-quarter high, a low hero shot. Never a cut, never fast.
-- Lighting is changed locally while the room shows (night, cool ambient, no haze / sun rays) and put back on close.
-- Particle rates follow VFXLib's Budget (phones get fewer).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VFX = require(ReplicatedStorage:WaitForChild("VFXLib"))
local MenuFX = require(script.Parent.MenuFX)

local ClassRoom = {}

local player = Players.LocalPlayer
local Tex = VFX.Assets.Tex
local Budget = VFX.Budget
local ORIGIN = CFrame.new(0, 1400, 0) -- the room's centre; the avatar faces -Z (toward the camera)
local FLOAT = Vector3.new(0, 4.4, 0) -- where the avatar's middle floats

local room: Model? = nil
local avatar: Model? = nil
local aura: { ParticleEmitter } = {}
local tail: { ParticleEmitter } = {}
local auraLight: PointLight? = nil
local rune: ImageLabel? = nil
local halo: BasePart? = nil
local grade: ColorCorrectionEffect? = nil
local blur: DepthOfFieldEffect? = nil
local step: RBXScriptConnection? = nil
local shown = false
local openToken = 0
local spinners: { { inst: Instance, speed: Vector3 } } = {} -- planets / asteroids turning each frame
local drifters: { { part: BasePart, img: ImageLabel?, vel: Vector3, spin: Vector3 } } = {}
local nebulae: { GuiObject } = {}
local savedLighting: { [Instance]: { [string]: any } } = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = ORIGIN * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function seq(...: number): NumberSequence
	local v = { ... }
	local k = {}
	for i = 1, #v, 2 do
		table.insert(k, NumberSequenceKeypoint.new(v[i], v[i + 1]))
	end
	return NumberSequence.new(k)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- A glow sprite that always faces the camera (nebula puffs, planet atmospheres, star flares).
local function glowBoard(parent: BasePart, size: number, color: Color3, transparency: number, image: string?): ImageLabel
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.MaxDistance = 100000
	bb.Parent = parent
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = image or Tex.Glow
	img.ImageColor3 = color
	img.ImageTransparency = transparency
	img.Size = UDim2.fromScale(1, 1)
	img.Parent = bb
	return img
end

-------------------------------------------------------------------------------------------------------------
-- the star-box: six far walls, each painted with stars (a few bright ones flare) and soft nebula clouds
-------------------------------------------------------------------------------------------------------------
local FACES = {
	-- behind the avatar (the main view). The class camera sways enough to see the side walls too, so the four upright
	-- walls share one look (same top-to-bottom glow, same nebula density): a sparser, darker side wall read as a hard
	-- dark band down both screen edges (the room's "lighting" bug, owner 27 Oct)
	{ CFrame.new(0, 0, 459), Vector3.new(2800, 1500, 2), Enum.NormalId.Front },
	{ CFrame.new(0, 0, -460), Vector3.new(1000, 1000, 2), Enum.NormalId.Back },
	{ CFrame.new(460, 0, 0), Vector3.new(2, 1000, 1000), Enum.NormalId.Left },
	{ CFrame.new(-460, 0, 0), Vector3.new(2, 1000, 1000), Enum.NormalId.Right },
	{ CFrame.new(0, 460, 0), Vector3.new(1000, 2, 1000), Enum.NormalId.Bottom },
	{ CFrame.new(0, -460, 0), Vector3.new(1000, 2, 1000), Enum.NormalId.Top },
}
local NEBULA = { rgb(130, 60, 255), rgb(40, 190, 255), rgb(255, 80, 200), rgb(90, 80, 255), rgb(60, 230, 200) }

local function starWall(m: Instance, i: number, rng: Random)
	local f = FACES[i]
	local wall = part(m, f[2], f[1], rgb(4, 3, 12))
	local gui = Instance.new("SurfaceGui")
	gui.Face = f[3]
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	local cw = if i == 1 then 2600 else 1400
	local ch = if i == 1 then 1400 else 1400
	gui.CanvasSize = Vector2.new(cw, ch)
	gui.Parent = wall
	-- a deep violet glow over the main wall, darker at the rim (the "sky" isn't flat black)
	local base = Instance.new("Frame")
	base.BorderSizePixel = 0
	base.Size = UDim2.fromScale(1, 1)
	base.BackgroundColor3 = Color3.new(1, 1, 1)
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(rgb(26, 14, 60), rgb(4, 3, 14))
	bg.Rotation = if i <= 4 then 90 else rng:NextInteger(0, 360)
	bg.Parent = base
	base.Parent = gui
	-- nebula clouds: big soft glows and a faint plasma texture, each slowly turning and breathing
	for k = 1, if i == 1 then 11 elseif i <= 4 then 7 else 3 do
		local c = NEBULA[rng:NextInteger(1, #NEBULA)]
		local sz = rng:NextInteger(500, 1100)
		local neb = Instance.new("ImageLabel")
		neb.BackgroundTransparency = 1
		neb.Image = if k % 3 == 0 then Tex.VS_Plasma else Tex.Glow
		neb.ImageColor3 = c
		neb.ImageTransparency = if k % 3 == 0 then 0.82 else 0.62
		neb.Size = UDim2.fromOffset(sz, sz * rng:NextNumber(0.55, 0.9))
		neb.Position = UDim2.fromOffset(rng:NextInteger(100, cw - 100), rng:NextInteger(150, ch - 150))
		neb.AnchorPoint = Vector2.new(0.5, 0.5)
		neb.Rotation = rng:NextInteger(0, 360)
		neb.Parent = gui
		table.insert(nebulae, neb)
		TweenService:Create(neb, TweenInfo.new(rng:NextNumber(5, 9), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = math.min(0.95, neb.ImageTransparency + 0.12) }):Play()
	end
	-- stars: many tiny dots, a few bright twinkling flares
	for _ = 1, if i == 1 then 480 elseif i <= 4 then 230 else 150 do
		local d = Instance.new("Frame")
		d.BorderSizePixel = 0
		local s = if rng:NextNumber() < 0.85 then rng:NextInteger(2, 3) else rng:NextInteger(4, 5)
		d.Size = UDim2.fromOffset(s, s)
		d.Position = UDim2.fromOffset(rng:NextInteger(0, cw), rng:NextInteger(0, ch))
		d.BackgroundColor3 = if rng:NextNumber() < 0.2 then rgb(190, 215, 255) elseif rng:NextNumber() < 0.15 then rgb(255, 225, 200) else Color3.new(1, 1, 1)
		d.BackgroundTransparency = rng:NextNumber(0, 0.45)
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(1, 0)
		cr.Parent = d
		d.Parent = gui
	end
	for _ = 1, if i == 1 then 26 elseif i <= 4 then 12 else 6 do
		local fl = Instance.new("ImageLabel")
		fl.BackgroundTransparency = 1
		fl.Image = Tex.Star4
		fl.ImageColor3 = if rng:NextNumber() < 0.5 then rgb(210, 225, 255) else rgb(255, 230, 250)
		local s = rng:NextInteger(14, 28)
		fl.Size = UDim2.fromOffset(s, s)
		fl.AnchorPoint = Vector2.new(0.5, 0.5)
		fl.Position = UDim2.fromOffset(rng:NextInteger(40, cw - 40), rng:NextInteger(40, ch - 40))
		fl.Parent = gui
		TweenService:Create(fl, TweenInfo.new(rng:NextNumber(0.8, 1.8), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber(0, 1.5)), { ImageTransparency = 0.85, Size = UDim2.fromOffset(s * 0.4, s * 0.4), Rotation = 45 }):Play()
	end
end

-- hand-painted sprites (outlined, cel-shaded, same style as the UI icons) uploaded from the art pipeline
local SPRITE = {
	giant = "rbxassetid://76815913357075",
	amber = "rbxassetid://133565391461599",
	moon = "rbxassetid://98933430752834",
	rocks = { "rbxassetid://128375906315387", "rbxassetid://84229473249758", "rbxassetid://84362739504731" },
}

-- a camera-facing painted sprite on an invisible anchor part; depth-tested so rings and rocks pass in front/behind
local function sprite(p: BasePart, image: string, studs: number): ImageLabel
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(studs, studs)
	bb.LightInfluence = 0
	bb.Brightness = 1
	bb.AlwaysOnTop = false
	bb.MaxDistance = 2000
	bb.Adornee = p
	bb.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = image
	img.Size = UDim2.fromScale(1, 1)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb
	return img
end

local function planet(m: Instance, pos: Vector3, size: number, image: string, atmo: Color3, ringed: boolean, spin: number)
	local p = part(m, Vector3.one, CFrame.new(pos), Color3.new(1, 1, 1))
	p.Transparency = 1
	sprite(p, image, size / 0.92) -- the painted disc fills 92% of its square
	glowBoard(p, size * 1.9, atmo, 0.55)
	if ringed then
		local ring = part(m, Vector3.new(size * 2.6, 0.2, size * 2.6), CFrame.new(pos) * CFrame.Angles(math.rad(-18), 0, math.rad(14)), Color3.new(1, 1, 1))
		ring.Transparency = 1
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local rg = Instance.new("SurfaceGui")
			rg.Face = face
			rg.LightInfluence = 0
			rg.Brightness = 1.4
			rg.CanvasSize = Vector2.new(512, 512)
			rg.Parent = ring
			for k, tr in { 0.25, 0.5 } do
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = Tex.RingThin
				img.ImageColor3 = if k == 1 then rgb(220, 200, 255) else rgb(255, 200, 160)
				img.ImageTransparency = tr
				img.Size = UDim2.fromScale(1 - (k - 1) * 0.16, 1 - (k - 1) * 0.16)
				img.Position = UDim2.fromScale(0.5, 0.5)
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Parent = rg
			end
		end
		table.insert(spinners, { inst = ring, speed = Vector3.new(0, 0.05, 0) })
	end
	return p -- the painted sprite carries its own lighting, so the body itself doesn't spin
end

local function rock(m: Instance, rng: Random, pos: Vector3, s: number)
	local main = part(m, Vector3.one, CFrame.new(pos), Color3.new(1, 1, 1))
	main.Transparency = 1
	local img = sprite(main, SPRITE.rocks[rng:NextInteger(1, #SPRITE.rocks)], s * 1.25)
	img.Rotation = rng:NextInteger(0, 359)
	-- far rocks sink into the violet haze a little
	local haze = math.clamp((pos.Z - 40) / 100, 0, 1)
	img.ImageColor3 = Color3.new(1, 1, 1):Lerp(rgb(150, 130, 210), haze * 0.6)
	img.ImageTransparency = haze * 0.25
	table.insert(drifters, {
		part = main,
		img = img,
		vel = Vector3.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-6, -2.5)), -- drifting toward the camera: we fly through them
		spin = Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6)),
	})
end

local function build()
	local m = Instance.new("Model")
	m.Name = "ClassRoom"
	local rng = Random.new(2026)
	for i = 1, #FACES do
		starWall(m, i, rng)
	end

	-- planets: a big ringed violet giant upper left, a small amber one lower right with a moon
	planet(m, Vector3.new(-170, 90, 380), 150, SPRITE.giant, rgb(150, 110, 255), true, 0.03)
	planet(m, Vector3.new(190, -40, 360), 54, SPRITE.amber, rgb(255, 160, 90), false, 0.06)
	planet(m, Vector3.new(232, 0, 330), 14, SPRITE.moon, rgb(200, 210, 255), false, 0.1)

	-- asteroids drifting through, near and far
	for _ = 1, 16 do
		local far = rng:NextNumber() < 0.6
		local pos = Vector3.new(rng:NextNumber(-70, 70), rng:NextNumber(-25, 35), rng:NextNumber(if far then 40 else 12, if far then 140 else 40))
		if math.abs(pos.X) < 12 and math.abs(pos.Y - 4) < 9 then
			pos += Vector3.new(if pos.X < 0 then -16 else 16, 0, 0) -- keep the avatar clear
		end
		rock(m, rng, pos, rng:NextNumber(if far then 3 else 1.2, if far then 9 else 3))
	end

	-- warp streaks + dust rushing past (the avatar flies toward us, so the streaks come from behind it)
	local warp = part(m, Vector3.new(120, 70, 1), CFrame.new(0, 5, 120), Color3.new(1, 1, 1))
	warp.Transparency = 1
	emitter(warp, {
		Texture = Tex.Spark, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Color = ColorSequence.new(rgb(200, 210, 255), Color3.new(1, 1, 1)),
		LightEmission = 1, Size = seq(0, 0.1, 1, 0.35), Transparency = seq(0, 1, 0.15, 0.25, 0.85, 0.3, 1, 1),
		Lifetime = NumberRange.new(1.6, 2.2), Speed = NumberRange.new(70, 110), Rate = Budget.Rate(26),
	})
	local dust = part(m, Vector3.new(70, 40, 1), CFrame.new(0, 5, 60), Color3.new(1, 1, 1))
	dust.Transparency = 1
	emitter(dust, {
		Texture = Tex.Glow, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front,
		Color = ColorSequence.new(rgb(190, 170, 255)), LightEmission = 0.8, Size = seq(0, 0.12, 1, 0.3), Transparency = seq(0, 1, 0.2, 0.35, 1, 1),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(12, 22), Rate = Budget.Rate(18),
	})

	-- (no platform under the avatar: it floats free in space)

	-- the aura round the avatar (recoloured per card) and a comet tail streaming out behind it
	local core = part(m, Vector3.new(2.2, 4.6, 1.4), CFrame.new(FLOAT + Vector3.new(0, 0, 0.4)), Color3.new(1, 1, 1))
	core.Transparency = 1
	core.Name = "AuraCore"
	table.insert(aura, emitter(core, {
		Texture = Tex.Glow, Shape = Enum.ParticleEmitterShape.Box, Color = ColorSequence.new(rgb(170, 90, 255)), LightEmission = 0.5,
		Size = seq(0, 0.5, 0.5, 0.9, 1, 0), Transparency = seq(0, 0.8, 0.4, 0.7, 1, 1), Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(2, 3.5), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(10, 10), Rate = Budget.Rate(10),
	}))
	table.insert(aura, emitter(core, {
		Texture = Tex.Spark, Shape = Enum.ParticleEmitterShape.Box, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = seq(0, 0.2, 1, 0), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 10), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(8, 8), Rate = Budget.Rate(8),
	}))
	table.insert(tail, emitter(core, {
		Texture = Tex.Glow, Color = ColorSequence.new(rgb(170, 90, 255)), LightEmission = 0.5, EmissionDirection = Enum.NormalId.Back,
		Size = seq(0, 1.6, 1, 0.2), Transparency = seq(0, 0.65, 1, 1), Lifetime = NumberRange.new(1.2, 1.6), Speed = NumberRange.new(9, 12),
		SpreadAngle = Vector2.new(4, 4), Rate = Budget.Rate(24), Drag = 1,
	}))
	auraLight = light(core, rgb(170, 90, 255), 8, 1)

	-- lights: a key from the camera side, a violet rim back-left, a cyan rim back-right, a warm planet bounce, and a
	-- soft spot on the avatar's front (owner, 27 Oct: the room's lighting needed fixing: the avatar was a dark
	-- silhouette with only its white bits glowing)
	local function lamp(pos: Vector3, color: Color3, range: number, brightness: number)
		local p = part(m, Vector3.one, CFrame.new(pos), Color3.new(1, 1, 1))
		p.Transparency = 1
		light(p, color, range, brightness)
	end
	lamp(Vector3.new(0, 9, -9), rgb(255, 240, 250), 20, 1)
	do
		local p = part(m, Vector3.one, CFrame.lookAt(Vector3.new(1.5, 6.5, -7), FLOAT), Color3.new(1, 1, 1))
		p.Transparency = 1
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 70
		spot.Range = 16
		spot.Brightness = 0.9
		spot.Color = rgb(255, 244, 236)
		spot.Shadows = false
		spot.Parent = p
	end
	lamp(Vector3.new(-6, 8, 5), rgb(160, 90, 255), 12, 1.3)
	lamp(Vector3.new(6, 6, 5), rgb(60, 210, 255), 12, 1.1)
	lamp(Vector3.new(4, -2, -2), rgb(255, 150, 90), 9, 0.6)

	room = m
	return m
end

-------------------------------------------------------------------------------------------------------------
-- the floating avatar: a clone of your character, no animation tracks - its joints are posed every frame
-------------------------------------------------------------------------------------------------------------
type Joint = { motor: any, base: CFrame } -- a Motor6D, or an AnimationConstraint on avatars with the joint upgrade
local joints: { [string]: Joint } = {}
local avatarHeight = 3
local spinT = -1 -- os.clock() when a showy turn started (-1 = none)
local nextSpin = 0

local function placeAvatar()
	if avatar then
		avatar:Destroy()
		avatar = nil
	end
	table.clear(joints)
	local char = player.Character
	if not char or not room then
		return
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, clone = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not clone then
		return
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Animator") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local hrp = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = true
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
	end
	avatarHeight = if hum and hum.RigType == Enum.HumanoidRigType.R15 then 2.6 else 3
	for _, d in clone:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			joints[d.Name] = { motor = d, base = (d :: any).Transform }
		end
	end
	clone.Parent = room
	avatar = clone
	nextSpin = os.clock() + 7
end

-- one smooth wave: sin with a period and a phase lag (the overlap that makes it organic)
local function wave(t: number, period: number, lag: number): number
	return math.sin((t - lag) / period * math.pi * 2)
end

local function poseJoint(name: string, cf: CFrame)
	local j = joints[name]
	if j then
		j.motor.Transform = cf
	end
end

local function animateAvatar(t: number)
	local a = avatar
	if not a then
		return
	end
	local hrp = a:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	-- the body: bob 0.35 studs (3.2 s), lean toward us as it flies, yaw sway, pitch / roll drift
	local bob = wave(t, 3.2, 0) * 0.35
	local yaw = math.rad(11) * wave(t, 9, 0.6)
	local pitch = math.rad(-9) + math.rad(4) * wave(t, 5.3, 1.1) -- leaning forward = flying at the camera
	local roll = math.rad(4) * wave(t, 6.1, 2.3)
	-- now and then (every 14-20 s) a slow showy turn: a full 360 on the spot, Quint InOut over 1.8 s
	if spinT < 0 and t > nextSpin then
		spinT = t
	end
	local turn = 0
	if spinT >= 0 then
		local k = math.clamp((t - spinT) / 1.8, 0, 1)
		turn = TweenService:GetValue(k, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut) * math.pi * 2
		if k >= 1 then
			spinT = -1
			nextSpin = t + 14 + math.random() * 6
		end
	end
	hrp.CFrame = ORIGIN * CFrame.new(FLOAT + Vector3.new(0, bob - avatarHeight + 3, 0)) * CFrame.Angles(0, yaw + turn, 0) * CFrame.Angles(pitch, 0, roll)
	-- R15: torso leads, chest +0.15 s, arms / head +0.3 s, legs +0.45 s (each on its own period, so it never loops visibly)
	local br = wave(t, 3.6, 0)
	poseJoint("Waist", CFrame.Angles(math.rad(4) + math.rad(2.5) * br, math.rad(3) * wave(t, 7, 0.15), 0))
	poseJoint("Neck", CFrame.Angles(math.rad(-6) + math.rad(3) * wave(t, 4.4, 0.3), math.rad(7) * wave(t, 8, 0.4), math.rad(2) * wave(t, 5, 0.3)))
	poseJoint("LeftShoulder", CFrame.Angles(math.rad(12) + math.rad(6) * wave(t, 3.4, 0.3), 0, math.rad(-28) + math.rad(7) * wave(t, 4.1, 0.35)))
	poseJoint("RightShoulder", CFrame.Angles(math.rad(8) + math.rad(6) * wave(t, 3.7, 0.45), 0, math.rad(30) + math.rad(7) * wave(t, 4.3, 0.2)))
	poseJoint("LeftElbow", CFrame.Angles(math.rad(22) + math.rad(6) * wave(t, 3.4, 0.5), 0, 0))
	poseJoint("RightElbow", CFrame.Angles(math.rad(16) + math.rad(6) * wave(t, 3.7, 0.65), 0, 0))
	poseJoint("LeftWrist", CFrame.Angles(math.rad(8) * wave(t, 3.4, 0.7), 0, 0))
	poseJoint("RightWrist", CFrame.Angles(math.rad(8) * wave(t, 3.7, 0.85), 0, 0))
	poseJoint("LeftHip", CFrame.Angles(math.rad(26) + math.rad(7) * wave(t, 3.9, 0.45), 0, math.rad(-5)))
	poseJoint("RightHip", CFrame.Angles(math.rad(8) + math.rad(7) * wave(t, 4.2, 0.6), 0, math.rad(5)))
	poseJoint("LeftKnee", CFrame.Angles(math.rad(-48) + math.rad(8) * wave(t, 3.9, 0.7), 0, 0))
	poseJoint("RightKnee", CFrame.Angles(math.rad(-22) + math.rad(8) * wave(t, 4.2, 0.85), 0, 0))
	poseJoint("LeftAnkle", CFrame.Angles(math.rad(-14), 0, 0))
	poseJoint("RightAnkle", CFrame.Angles(math.rad(-10), 0, 0))
	-- R6 (the joints live in the Torso with turned C0s, so only small safe drifts)
	poseJoint("Left Shoulder", CFrame.Angles(0, 0, math.rad(-18) + math.rad(6) * wave(t, 3.4, 0.3)))
	poseJoint("Right Shoulder", CFrame.Angles(0, 0, math.rad(18) + math.rad(6) * wave(t, 3.7, 0.45)))
	poseJoint("Left Hip", CFrame.Angles(0, 0, math.rad(-8) + math.rad(5) * wave(t, 3.9, 0.45)))
	poseJoint("Right Hip", CFrame.Angles(0, 0, math.rad(6) + math.rad(5) * wave(t, 4.2, 0.6)))
end

-------------------------------------------------------------------------------------------------------------
-- the camera: framings it glides between (positions relative to the room centre, looking at the avatar)
-------------------------------------------------------------------------------------------------------------
local SHOTS = {
	{ pos = Vector3.new(0, 4.8, -15), look = Vector3.new(0, 4.2, 0), fov = 56 }, -- front (the one the screen opens on)
	{ pos = Vector3.new(-6.5, 2.6, -13.2), look = Vector3.new(0, 4.6, 0), fov = 54 }, -- three-quarter, low, from the left
	{ pos = Vector3.new(6.8, 7.4, -12.6), look = Vector3.new(0, 4.0, 0), fov = 55 }, -- three-quarter, high, from the right
	{ pos = Vector3.new(1.6, 2.4, -12.4), look = Vector3.new(0, 5.0, 0), fov = 52 }, -- low hero shot, a touch closer
}
local GLIDE = 3 -- seconds a move between framings takes (Sine InOut)
local camFrom, camTo = 1, 1
local camMoveStart, camNext = 0, 0

local function shotCF(s): (CFrame, number)
	return ORIGIN * CFrame.lookAt(s.pos, s.look), s.fov
end

local function updateCamera(t: number)
	if t > camNext then
		camFrom = camTo
		local n = camTo
		while n == camTo do
			n = math.random(1, #SHOTS)
		end
		camTo = n
		camMoveStart = t
		camNext = t + GLIDE + 9 + math.random() * 4
	end
	local k = math.clamp((t - camMoveStart) / GLIDE, 0, 1)
	k = TweenService:GetValue(k, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local a, fa = shotCF(SHOTS[camFrom])
	local b, fb = shotCF(SHOTS[camTo])
	local cf = a:Lerp(b, k)
	-- always alive: a slow orbit drift and a little handheld noise (never more than a few tenths of a stud)
	local drift = CFrame.new(math.sin(t * 0.21) * 0.6, math.sin(t * 0.17 + 1) * 0.25, 0)
	local shake = CFrame.Angles(math.noise(t * 0.35, 0.5) * 0.01, math.noise(0.5, t * 0.35) * 0.012, math.noise(t * 0.3, 7.7) * 0.008)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = fa + (fb - fa) * k
	cam.CFrame = cf * drift * shake
end

-------------------------------------------------------------------------------------------------------------
-- local lighting while the room shows (put back exactly on close)
-------------------------------------------------------------------------------------------------------------
local function setLit(inst: Instance, props: { [string]: any })
	local saved = savedLighting[inst] or {}
	for k, v in props do
		if saved[k] == nil then
			saved[k] = (inst :: any)[k]
		end
		(inst :: any)[k] = v
	end
	savedLighting[inst] = saved
end

local function spaceLighting()
	-- pause client/BiomeLight, or it puts the zone's sun (and bloom) back every frame and the avatar blows out white
	player:SetAttribute("BiomeLightOff", true)
	setLit(Lighting, { ClockTime = 0, Brightness = 0, Ambient = rgb(110, 100, 150), OutdoorAmbient = rgb(90, 80, 135), ExposureCompensation = 0, FogEnd = 100000, FogStart = 99999 })
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") then
			setLit(c, { Density = 0, Haze = 0, Glare = 0 })
		elseif c:IsA("SunRaysEffect") then
			setLit(c, { Enabled = false })
		elseif c:IsA("BloomEffect") then
			setLit(c, { Intensity = 0.3, Size = 24, Threshold = 0.95 }) -- soft: 1.1 blew white clothes out into neon
		elseif c:IsA("Sky") then
			setLit(c, { StarCount = 3000, CelestialBodiesShown = false })
		end
	end
end

local function restoreLighting()
	for inst, props in savedLighting do
		if inst.Parent then
			for k, v in props do
				pcall(function()
					(inst :: any)[k] = v
				end)
			end
		end
	end
	table.clear(savedLighting)
	player:SetAttribute("BiomeLightOff", nil)
end

-- Show the room and point the camera at the avatar. `color` = the picked card's rarity colour.
function ClassRoom.show(color: Color3?)
	local m = room or build()
	m.Parent = workspace
	placeAvatar()
	ClassRoom.setAura(color or rgb(170, 90, 255))
	spaceLighting()
	local t0 = os.clock()
	camFrom, camTo, camMoveStart, camNext = 1, 1, 0, 9 + math.random() * 3
	RunService:BindToRenderStep("ClassRoomCamera", Enum.RenderPriority.Camera.Value + 2, function()
		updateCamera(os.clock() - t0)
	end)
	if not grade then
		local g = Instance.new("ColorCorrectionEffect")
		g.Name = "ClassRoomGrade"
		grade = g
	end
	local g = grade :: ColorCorrectionEffect
	g.Parent = Lighting
	-- the lights come on in steps, like Chop A Forest's: cold dark blue, dark purple at 0.45 s, full at 0.65 s
	g.TintColor, g.Saturation, g.Contrast, g.Brightness = rgb(150, 165, 230), -0.45, 0, -0.08
	openToken += 1
	local token = openToken
	task.delay(0.45, function()
		if token == openToken and shown then
			g.TintColor, g.Saturation, g.Brightness = rgb(200, 130, 220), -0.15, -0.12
		end
	end)
	task.delay(0.65, function()
		if token == openToken and shown then
			TweenService:Create(g, TweenInfo.new(0.06), { TintColor = rgb(235, 228, 255), Saturation = 0.2, Contrast = 0.12, Brightness = 0.02 }):Play()
		end
	end)
	if not blur then -- the far star-box softens; the avatar stays sharp
		local b = Instance.new("DepthOfFieldEffect")
		b.Name = "ClassRoomBlur"
		b.FocusDistance = 14
		b.InFocusRadius = 12
		b.FarIntensity = 0.18
		b.NearIntensity = 0
		blur = b
	end
	(blur :: DepthOfFieldEffect).Parent = Lighting
	if not step then
		local last = os.clock()
		step = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local dt = math.min(now - last, 0.1)
			last = now
			local t = now - t0
			if rune then
				rune.Rotation = (rune.Rotation + dt * 14) % 360
			end
			for _, s in spinners do
				local p = s.inst :: BasePart
				p.CFrame = p.CFrame * CFrame.Angles(s.speed.X * dt, s.speed.Y * dt, s.speed.Z * dt)
			end
			for _, d in drifters do
				local p = d.part
				local pos = p.Position + d.vel * dt
				local rel = ORIGIN:PointToObjectSpace(pos)
				if rel.Z < -30 then -- flown past the camera: send it back out far behind the avatar
					pos = ORIGIN * Vector3.new(rel.X, rel.Y, 140)
				end
				p.CFrame = CFrame.new(pos)
				if d.img then
					d.img.Rotation = (d.img.Rotation + d.spin.Z * dt * 40) % 360 -- tumble
				end
			end
			if halo and avatar then
				-- the halo follows the avatar's bob a little behind it
				local hrp = avatar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local y = ORIGIN:PointToObjectSpace(hrp.Position).Y - avatarHeight - 0.8
					halo.CFrame = ORIGIN * CFrame.new(0, y, 0)
				end
			end
			animateAvatar(t)
		end)
	end
	shown = true
end

function ClassRoom.setAura(color: Color3)
	for _, e in aura do
		if e.Texture == Tex.Glow then
			e.Color = ColorSequence.new(color)
		end
	end
	for _, e in tail do
		e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	end
	if auraLight then
		auraLight.Color = color
	end
end

-- the avatar flashes a colour (a rare card landing): aura and tail burst, a VFX Forge burst round it (bigger when
-- the card was bought), its light blooms, then settles
function ClassRoom.pulse(color: Color3, big: boolean?)
	if not shown then
		return
	end
	ClassRoom.setAura(color)
	for _, e in aura do
		e:Emit(14)
	end
	for _, e in tail do
		e:Emit(20)
	end
	MenuFX.burst((ORIGIN * CFrame.new(FLOAT)).Position, color, { size = 0.8, big = big })
	if auraLight then
		local l = auraLight
		l.Brightness = 2.5
		l.Range = 12
		TweenService:Create(l, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 1, Range = 8 }):Play()
	end
end

function ClassRoom.hide()
	if not shown then
		return
	end
	shown = false
	RunService:UnbindFromRenderStep("ClassRoomCamera")
	if step then
		step:Disconnect()
		step = nil
	end
	if room then
		room.Parent = nil
	end
	if avatar then
		avatar:Destroy()
		avatar = nil
	end
	if grade then
		grade.Parent = nil
	end
	if blur then
		blur.Parent = nil
	end
	restoreLighting()
	local cam = workspace.CurrentCamera
	cam.FieldOfView = 70
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
end

return ClassRoom
