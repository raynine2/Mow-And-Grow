-- The class room (client only), like Chop A Forest's class screen: while the CLASSES window is open the camera cuts
-- to a dark magic room high above the map, with your avatar (a clone, playing its idle) on a glowing, turning
-- rune circle in front of a purple-roofed log cabin: candles with toon flames, a bubbling cauldron, pink
-- crystals, purple sparkles and an aura in the picked card's rarity colour. Built once on first open, taken
-- out of the world while closed. Particle rates follow VFXLib's Budget (phones get fewer).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VFX = require(ReplicatedStorage:WaitForChild("VFXLib"))

local ClassRoom = {}

local player = Players.LocalPlayer
local Tex = VFX.Assets.Tex
local Budget = VFX.Budget
local ORIGIN = CFrame.new(0, 1400, 0) -- the room's floor centre; the avatar faces -Z (toward the camera)

local room: Model? = nil
local avatar: Model? = nil
local aura: { ParticleEmitter } = {}
local auraLight: PointLight? = nil
local rune: ImageLabel? = nil
local grade: ColorCorrectionEffect? = nil
local spin: RBXScriptConnection? = nil
local shown = false

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

-- A candle (bottom at `x, z`): wax, a toon flame, sometimes a warm light.
local function candle(m: Instance, x: number, z: number, h: number, lit: boolean)
	local wax = part(m, Vector3.new(h, 0.9, 0.9), CFrame.new(x, 1 + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), rgb(246, 238, 226), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(h / 2 + 0.35, 0, 0)
	tip.Parent = wax
	emitter(tip, {
		Texture = Tex.FlameToon4x4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(24), Color = ColorSequence.new(rgb(255, 214, 120), rgb(255, 140, 40)), LightEmission = 1,
		Size = NumberSequence.new(0.7), Lifetime = NumberRange.new(0.45), Speed = NumberRange.new(0), Rate = 3, LockedToPart = true,
	})
	if lit then
		light(wax, rgb(255, 180, 110), 10, 1.2)
	end
end

local function build()
	local m = Instance.new("Model")
	m.Name = "ClassRoom"
	local dark = rgb(14, 10, 26)
	-- night: a dark grassy floor, a box that hides the sky, and dark pines behind the cabin
	part(m, Vector3.new(140, 1, 110), CFrame.new(0, 0, 10), rgb(34, 46, 40), Enum.Material.Grass)
	part(m, Vector3.new(140, 1, 110), CFrame.new(0, 70, 10), dark)
	for _, x in { -70, 70 } do
		part(m, Vector3.new(1, 70, 110), CFrame.new(x, 35, 10), dark)
	end
	part(m, Vector3.new(140, 70, 1), CFrame.new(0, 35, 64), dark)
	part(m, Vector3.new(140, 70, 1), CFrame.new(0, 35, -44), dark)
	local pineRng = Random.new(3)
	for i = 0, 11 do
		local x = -44 + i * 8 + pineRng:NextNumber(-2, 2)
		if math.abs(x) < 14 then
			continue
		end
		local z, h = pineRng:NextNumber(14, 30), pineRng:NextNumber(16, 26)
		part(m, Vector3.new(1.4, h * 0.3, 1.4), CFrame.new(x, h * 0.15, z), rgb(36, 26, 34), Enum.Material.Wood)
		for t = 0, 3 do
			local w = (1 - t / 4) * h * 0.42 + 1.5
			part(m, Vector3.new(w, h * 0.26, w), CFrame.new(x, h * 0.3 + t * h * 0.19, z) * CFrame.Angles(0, t * 0.7, 0), rgb(30, 44, 52), Enum.Material.Grass)
		end
	end

	-- the little log cabin right behind the circle: log walls with big log ends, a purple A-frame roof with logs in
	-- the gable, two star banners and a glowing teal window
	local logC, endC, z0 = rgb(150, 104, 76), rgb(214, 172, 124), 8.5
	part(m, Vector3.new(21, 8.4, 0.6), CFrame.new(0, 4.2, z0 + 0.7), rgb(70, 46, 40), Enum.Material.WoodPlanks)
	for i = 0, 6 do
		local y = 0.6 + i * 1.2
		part(m, Vector3.new(22.5, 1.2, 1.2), CFrame.new(0, y, z0), logC, Enum.Material.Wood, Enum.PartType.Cylinder)
		for _, x in { -11.4, 11.4 } do
			part(m, Vector3.new(0.3, 1.25, 1.25), CFrame.new(x, y, z0), endC, Enum.Material.Wood, Enum.PartType.Cylinder)
		end
	end
	for i = 0, 4 do
		local hw = 10.5 * (1 - (i + 0.6) / 5.4)
		part(m, Vector3.new(hw * 2, 1.1, 1.1), CFrame.new(0, 8.95 + i * 1.1, z0), logC, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	local pitch = math.atan(6.4 / 12.6)
	local slabLen = math.sqrt(12.6 ^ 2 + 6.4 ^ 2) + 0.6
	for side = -1, 1, 2 do
		local cf = CFrame.new(side * 6.3, 11.4, z0 + 5) * CFrame.Angles(0, 0, -side * pitch)
		part(m, Vector3.new(slabLen, 0.9, 13), cf, rgb(108, 66, 196), Enum.Material.RoofShingles)
		part(m, Vector3.new(slabLen, 0.7, 0.7), cf * CFrame.new(0, -0.1, -6.6), rgb(60, 40, 30), Enum.Material.Wood)
	end
	part(m, Vector3.new(1.3, 1.3, 13.4), CFrame.new(0, 14.5, z0 + 5), rgb(60, 40, 30), Enum.Material.Wood)
	part(m, Vector3.new(4, 6.4, 0.3), CFrame.new(0, 3.6, z0 - 0.75), rgb(56, 36, 30), Enum.Material.WoodPlanks)
	local win = part(m, Vector3.new(3, 2.8, 0.25), CFrame.new(-6.2, 3.8, z0 - 0.75), rgb(70, 220, 190), Enum.Material.Neon)
	light(win, rgb(70, 220, 190), 10, 0.9)
	part(m, Vector3.new(3.8, 3.6, 0.3), CFrame.new(-6.2, 3.8, z0 - 0.65), rgb(72, 46, 110), Enum.Material.Wood)
	for _, x in { -5.2, 5.2 } do
		local banner = part(m, Vector3.new(3.2, 4.6, 0.15), CFrame.new(x, 8.6, z0 - 0.85), rgb(40, 20, 80), Enum.Material.Fabric)
		part(m, Vector3.new(3.6, 0.25, 0.25), CFrame.new(x, 10.95, z0 - 0.85), rgb(220, 170, 70), Enum.Material.Metal)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 2.5
		gui.CanvasSize = Vector2.new(100, 144)
		gui.Parent = banner
		for k = 1, 6 do -- a starry fabric
			local dot = Instance.new("Frame")
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = rgb(200, 170, 255)
			dot.BackgroundTransparency = 0.4
			dot.Size = UDim2.fromOffset(4, 4)
			dot.Position = UDim2.fromOffset((k * 37) % 92 + 4, (k * 53) % 130 + 6)
			dot.Parent = gui
		end
		local star = Instance.new("ImageLabel")
		star.BackgroundTransparency = 1
		star.Image = Tex.Star4
		star.ImageColor3 = rgb(255, 214, 90)
		star.Size = UDim2.fromOffset(84, 84)
		star.Position = UDim2.fromScale(0.5, 0.45)
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Parent = gui
	end

	-- the octagon stone platform with a step, and the rune circle on it (an image that turns slowly)
	for _, a in { 0, math.rad(45) } do
		part(m, Vector3.new(15.5, 1.3, 15.5), CFrame.new(0, 1, 0) * CFrame.Angles(0, a, 0), rgb(96, 90, 116), Enum.Material.Slate)
		part(m, Vector3.new(19, 0.7, 19), CFrame.new(0, 0.35, 0) * CFrame.Angles(0, a, 0), rgb(70, 64, 88), Enum.Material.Slate)
	end
	local runePart = part(m, Vector3.new(14, 0.1, 14), CFrame.new(0, 1.7, 0), Color3.new(1, 1, 1))
	runePart.Transparency = 1
	local rg = Instance.new("SurfaceGui")
	rg.Face = Enum.NormalId.Top
	rg.LightInfluence = 0
	rg.Brightness = 3
	rg.CanvasSize = Vector2.new(512, 512)
	rg.Parent = runePart
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = Tex.Glow
	glow.ImageColor3 = rgb(190, 90, 255)
	glow.ImageTransparency = 0.35
	glow.Size = UDim2.fromScale(1.15, 1.15)
	glow.Position = UDim2.fromScale(-0.075, -0.075)
	glow.Parent = rg
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = Tex.RuneCircle
	img.ImageColor3 = rgb(215, 130, 255)
	img.Size = UDim2.fromScale(1, 1)
	img.Parent = rg
	rune = img
	light(runePart, rgb(200, 110, 255), 16, 2.2)

	-- candles round the platform's edge (none between the camera and the avatar)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + 0.2
		local x, z = math.cos(a) * 7.6, math.sin(a) * 7.6
		if z > -3 or math.abs(x) > 5 then
			candle(m, x, z, 0.9 + (i % 3) * 0.6, i % 4 == 0)
		end
	end

	-- the cauldron on its tripod (screen left: the camera looks along +Z, so +X is on the left) with green smoke, and a table of potions behind it
	local pot = part(m, Vector3.new(5, 4, 5), CFrame.new(12.5, 2.6, 3), rgb(30, 28, 36), Enum.Material.Metal, Enum.PartType.Ball)
	part(m, Vector3.new(0.4, 4.4, 4.4), CFrame.new(12.5, 4.4, 3) * CFrame.Angles(0, 0, math.rad(90)), rgb(40, 38, 46), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, Vector3.new(0.3, 3.8, 3.8), CFrame.new(12.5, 4.5, 3) * CFrame.Angles(0, 0, math.rad(90)), rgb(90, 255, 130), Enum.Material.Neon, Enum.PartType.Cylinder)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		part(m, Vector3.new(0.35, 3, 0.35), CFrame.new(12.5 + math.cos(a) * 2, 1.3, 3 + math.sin(a) * 2) * CFrame.Angles(math.cos(a) * 0.3, 0, math.sin(a) * 0.3), rgb(30, 28, 36), Enum.Material.Metal)
	end
	local brew = Instance.new("Attachment")
	brew.Position = Vector3.new(0, 2.1, 0)
	brew.Parent = pot
	emitter(brew, {
		Texture = Tex.SmokePuff4x4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(rgb(120, 255, 150)), LightEmission = 0.5, Size = seq(0, 1.5, 1, 5), Transparency = seq(0, 0.25, 1, 1),
		Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(15, 15), Rate = Budget.Rate(4),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(-0.6, 0, 0),
	})
	light(pot, rgb(110, 255, 140), 12, 1.6)
	part(m, Vector3.new(5, 0.3, 2.2), CFrame.new(15.5, 2.4, 6.5), rgb(110, 74, 48), Enum.Material.WoodPlanks)
	for _, x in { 17.6, 13.4 } do
		part(m, Vector3.new(0.3, 2.3, 0.3), CFrame.new(x, 1.15, 6.5), rgb(80, 52, 34), Enum.Material.Wood)
	end
	for k, c in { rgb(255, 120, 220), rgb(120, 220, 255), rgb(255, 230, 120) } do
		local x = 13.8 + k * 1.3
		local bottle = part(m, Vector3.new(0.9, 1.4, 0.9), CFrame.new(x, 3.25, 6.5), rgb(235, 240, 255), Enum.Material.Glass)
		bottle.Transparency = 0.35
		part(m, Vector3.new(0.7, 0.8, 0.7), CFrame.new(x, 3.05, 6.5), c, Enum.Material.Neon)
		part(m, Vector3.new(0.35, 0.5, 0.35), CFrame.new(x, 4.2, 6.5), rgb(235, 240, 255), Enum.Material.Glass).Transparency = 0.35
	end

	-- pink crystals (screen right)
	local crystalRng = Random.new(5)
	for i = 1, 7 do
		local h = crystalRng:NextNumber(2.5, 6.5)
		local c = part(m, Vector3.new(1.2, h, 1.2), CFrame.new(-11.5 + crystalRng:NextNumber(-2.5, 2), h * 0.45, 4 + crystalRng:NextNumber(-2, 2)) * CFrame.Angles(crystalRng:NextNumber(-0.45, 0.45), crystalRng:NextNumber(0, 3), crystalRng:NextNumber(-0.45, 0.45)), rgb(240, 120, 235), Enum.Material.Neon)
		c.Transparency = 0.12
		if i == 1 then
			light(c, rgb(240, 110, 230), 12, 1.6)
		end
	end

	-- sparkles and motes in the air
	local air = part(m, Vector3.new(32, 13, 16), CFrame.new(0, 7, 2), Color3.new(1, 1, 1))
	air.Transparency = 1
	emitter(air, {
		Texture = Tex.Star4, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(rgb(230, 180, 255), Color3.new(1, 1, 1)), LightEmission = 1, Size = seq(0, 0, 0.5, 0.45, 1, 0),
		Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.2, 0.8), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
		Rate = Budget.Rate(9),
	})
	emitter(air, {
		Texture = Tex.Glow, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(rgb(200, 150, 255)), LightEmission = 0.8, Size = seq(0, 0.12, 0.5, 0.25, 1, 0.08), Transparency = seq(0, 1, 0.3, 0.3, 1, 1),
		Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180), Rate = Budget.Rate(10),
	})

	-- the aura round the avatar (recoloured per card)
	local core = part(m, Vector3.new(2.2, 4.6, 1.4), CFrame.new(0, 4.3, 0.4), Color3.new(1, 1, 1))
	core.Transparency = 1
	table.insert(aura, emitter(core, {
		Texture = Tex.Glow, Shape = Enum.ParticleEmitterShape.Box, Color = ColorSequence.new(rgb(170, 90, 255)), LightEmission = 1,
		Size = seq(0, 0.5, 0.5, 0.9, 1, 0), Transparency = seq(0, 0.8, 0.4, 0.7, 1, 1), Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(2, 3.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6), Rate = Budget.Rate(8),
	}))
	table.insert(aura, emitter(core, {
		Texture = Tex.Spark, Shape = Enum.ParticleEmitterShape.Box, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Size = seq(0, 0.2, 1, 0), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(4, 8), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8), Rate = Budget.Rate(6),
	}))
	auraLight = light(core, rgb(170, 90, 255), 7, 0.9) -- a rim on the avatar, not a wash over the cabin

	-- a soft key light from the camera side so the avatar reads
	local key = part(m, Vector3.one, CFrame.new(0, 8, -8), Color3.new(1, 1, 1))
	key.Transparency = 1
	light(key, rgb(255, 230, 255), 18, 1.4)
	room = m
	return m
end

-- A copy of your character on the circle, playing your idle animation.
local function placeAvatar()
	if avatar then
		avatar:Destroy()
		avatar = nil
	end
	local char = player.Character
	if not char or not room then
		return
	end
	local idleId: string? = nil
	local animate = char:FindFirstChild("Animate")
	local idle = animate and animate:FindFirstChild("idle")
	local a1 = idle and idle:FindFirstChildWhichIsA("Animation")
	if a1 then
		idleId = (a1 :: Animation).AnimationId
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
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") then
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
	end
	local height = if hum and hum.RigType == Enum.HumanoidRigType.R15 then hum.HipHeight + 1.6 else 3
	clone:PivotTo(ORIGIN * CFrame.new(0, 1.65 + height, 0)) -- facing -Z: toward the camera
	clone.Parent = room
	avatar = clone
	if hum and idleId then
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = idleId
		pcall(function()
			local track = (animator :: Animator):LoadAnimation(anim)
			track.Looped = true
			track:Play()
		end)
	end
end

-- Show the room and point the camera at the avatar. `color` = the picked card's rarity colour.
function ClassRoom.show(color: Color3?)
	local m = room or build()
	m.Parent = workspace
	placeAvatar()
	ClassRoom.setAura(color or Color3.fromRGB(170, 90, 255))
	-- the avatar sits in the middle of the screen, a little low, between the left panel and the big card. The
	-- game's own camera code runs every frame, so the room camera is set again right after it.
	local view = ORIGIN * CFrame.lookAt(Vector3.new(0, 6.6, -16.5), Vector3.new(0, 5.6, 0))
	RunService:BindToRenderStep("ClassRoomCamera", Enum.RenderPriority.Camera.Value + 2, function()
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 52
		cam.CFrame = view
	end)
	if not grade then
		local g = Instance.new("ColorCorrectionEffect")
		g.Name = "ClassRoomGrade"
		g.TintColor = rgb(240, 225, 255)
		g.Saturation = 0.15
		g.Contrast = 0.1
		grade = g
	end
	(grade :: ColorCorrectionEffect).Parent = Lighting
	if not spin then
		spin = RunService.RenderStepped:Connect(function(dt)
			if rune then
				rune.Rotation = (rune.Rotation + dt * 8) % 360
			end
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
	if auraLight then
		auraLight.Color = color
	end
end

function ClassRoom.hide()
	if not shown then
		return
	end
	shown = false
	RunService:UnbindFromRenderStep("ClassRoomCamera")
	if spin then
		spin:Disconnect()
		spin = nil
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
	local cam = workspace.CurrentCamera
	cam.FieldOfView = 70
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
end

return ClassRoom
