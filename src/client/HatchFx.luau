-- The egg hatch: tap-to-open at the hatching shrine (the owner's reference: a TikTok "spirits hatching" clip).
-- The camera cuts to a shrine built just for the hatch (client-only, far from the map): a rock altar with a glowing
-- plate, two huge curved claws arching over it, stone pillars with purple fire, autumn pines blurred behind.
-- The egg floats on the plate under a pulsing TAP TO OPEN. Every tap punches it (white starburst, sparks, a tick that
-- climbs in pitch); some taps UPGRADE it: a swirl of crescent slashes in the next rarity's colour wraps the egg and the
-- egg turns that colour, climbing the rarity ladder until it reaches what's really inside. The last tap blows it open
-- in a white star explosion, a black silhouette of the critter rises out of the light, then flashes into colour in a
-- swirl of slashes. The result screen slams in: rarity bar + chance, the name huge, NEW! in yellow, and at the bottom
-- the price, + MORE GEMS, HATCH AGAIN and LEAVE. No tap for a while taps for you (nobody gets stuck).
-- 3 / 10 eggs float in a row and climb together (each stops at its own rarity).
-- API (unchanged): HatchFx.play(eggId, ids, fresh, onDone); HatchFx.busy; HatchFx.timeScale.
-- HatchFx.after is set before onDone runs: "again" / "gems" when the player picked those buttons, else nil.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local PartBuild = require(Shared:WaitForChild("PartBuild"))
local okIcons, IconIds = pcall(require, Shared:FindFirstChild("IconIds"))
local VFXLib = ReplicatedStorage:FindFirstChild("VFXLib")
local okAssets, Assets = pcall(function()
	return require((VFXLib :: Instance):WaitForChild("Assets"))
end)
local modules = script.Parent
local PetFollow = require(modules:WaitForChild("PetFollow"))
local Sound = require(modules:WaitForChild("Sound"))
local Confetti = require(modules:WaitForChild("Confetti"))
local State = require(modules:WaitForChild("State"))

local HatchFx = {}
HatchFx.busy = false
HatchFx.timeScale = 1
HatchFx.after = nil :: string?

local TEX = if okAssets and type(Assets) == "table" then Assets.Tex else {}
local ICONS = if okIcons and type(IconIds) == "table" then IconIds else {}
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FEW = if MOBILE then 0.6 else 1
local FONT = (Config.UI and Config.UI.font) or Enum.Font.FredokaOne
local INK = Color3.fromRGB(28, 18, 30)
local WHITE = Color3.new(1, 1, 1)

local LADDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local RANK = {}
for i, r in LADDER do
	RANK[r] = i
end
local NAME = { Mythic = "MYTHICAL" }

-- the shrine sits far from the map so nothing of the world gets in the way
local ORIGIN = CFrame.new(0, 2600, 9000)
local PLATE_Y = 3.7
local CAM_REST = Vector3.new(0, 7.2, 17.5)
local CAM_LOOK = Vector3.new(0, 5.6, 0)
local AUTO_TAP = 2.6 -- seconds without a tap before it taps for you
local TAP_GAP = 0.16

local function rarityColor(r: string, t: number?): Color3
	if r == "Secret" then
		return Color3.fromHSV(((t or os.clock()) * 0.4) % 1, 0.7, 1)
	end
	return Config.RARITY_COLORS[r] or WHITE
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function easeOutBack(x: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-------------------------------------------------------------------------------------------------------------
-- builders
-------------------------------------------------------------------------------------------------------------
local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Speed = NumberRange.new(0)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

-- a voxel pine like the reference's background (three stacked, shrinking, turned blocks)
local function pine(parent: Instance, at: Vector3, h: number, color: Color3)
	part(parent, Vector3.new(0.9, h * 0.35, 0.9) * (h / 10), CFrame.new(at + Vector3.new(0, h * 0.16, 0)), Color3.fromRGB(90, 60, 40))
	for i = 0, 2 do
		local w = h * (0.62 - i * 0.16)
		local y = h * (0.32 + i * 0.22)
		part(parent, Vector3.new(w, h * 0.24, w), CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(45 * (i % 2) + 10), 0), color:Lerp(Color3.new(1, 1, 1), i * 0.06))
	end
end

-- one claw: a chain of tapering blocks that rises from the ground and curls in over the altar
local function claw(parent: Instance, side: number)
	local col = Color3.fromRGB(235, 120, 55)
	local n = 8
	local pos = Vector3.new(7.4 * side, 0, 0.6)
	local ang = math.rad(-10)
	for i = 1, n do
		local a = i / n
		local len = 2.0 - a * 0.45
		local w = 2.8 * (1 - a * 0.8)
		ang += math.rad(3 + a * a * 30) -- straight-ish trunk, the hook at the tip
		local dir = Vector3.new(-math.sin(ang) * side, math.cos(ang), 0)
		local mid = pos + dir * (len / 2)
		local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
		part(parent, Vector3.new(w, len + 0.25, w * 0.8), ORIGIN * cf, col:Lerp(Color3.fromRGB(255, 200, 120), a * 0.6))
		pos += dir * len
	end
	-- a small spur near the base, like the reference
	local spur = CFrame.new(5.4 * side, 1.6, 1.4) * CFrame.Angles(0, 0, math.rad(-35 * side))
	part(parent, Vector3.new(0.9, 2.6, 0.8), ORIGIN * spur, Color3.fromRGB(250, 160, 80))
end

local function brazier(parent: Instance, x: number)
	local stone = Color3.fromRGB(205, 200, 210)
	local base = CFrame.new(x, 0, -2.2)
	part(parent, Vector3.new(1.8, 0.6, 1.8), ORIGIN * base * CFrame.new(0, 0.3, 0), stone:Lerp(Color3.new(0, 0, 0), 0.15))
	part(parent, Vector3.new(5, 1.1, 1.1), ORIGIN * base * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), stone, nil, Enum.PartType.Cylinder)
	part(parent, Vector3.new(1.7, 0.5, 1.7), ORIGIN * base * CFrame.new(0, 5.6, 0), stone)
	local bowl = part(parent, Vector3.new(1.4, 0.5, 1.4), ORIGIN * base * CFrame.new(0, 6.05, 0), Color3.fromRGB(70, 50, 80))
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 0.4, 0)
	att.Parent = bowl
	local flame = emitter(att, {
		Texture = TEX.FlameToon4x4 or SPARKLE,
		FlipbookLayout = if TEX.FlameToon4x4 then Enum.ParticleFlipbookLayout.Grid4x4 else Enum.ParticleFlipbookLayout.None,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		Color = ColorSequence.new(Color3.fromRGB(230, 120, 255), Color3.fromRGB(120, 40, 220)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(2.5, 4),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 22 * FEW,
		Brightness = 2,
	})
	flame.Enabled = true
	light(bowl, Color3.fromRGB(190, 90, 255), 2, 9)
end

type Stage = {
	folder: Folder,
	cam: Camera,
	oldType: Enum.CameraType,
	oldCF: CFrame,
	camCF: CFrame,
	shake: number,
	gui: ScreenGui,
	dof: DepthOfFieldEffect,
	cc: ColorCorrectionEffect,
	plateLight: PointLight,
	rays: ImageLabel,
	raysBoard: BillboardGui,
	mood: { [string]: any },
	hiddenGuis: { ScreenGui },
	confetti: { Instance }?,
	moodSet: { [string]: any },
	bloom: { [Instance]: { number } },
}

local function buildShrine(): Stage
	local cam = workspace.CurrentCamera
	local folder = Instance.new("Folder")
	folder.Name = "HatchShrine"
	-- ground
	part(folder, Vector3.new(2, 140, 140), ORIGIN * CFrame.new(0, -1, -20) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 82, 52), Enum.Material.Grass, Enum.PartType.Cylinder)
	part(folder, Vector3.new(1, 17, 17), ORIGIN * CFrame.new(0, -0.45, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(92, 62, 46), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	-- the altar: chunky dark-red rock blocks, the glowing plate on top
	local rock = Color3.fromRGB(96, 40, 36)
	local rng = Random.new(7)
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local r = 1.7 + rng:NextNumber() * 0.6
		local h = 2.2 + rng:NextNumber() * 1.3
		part(folder, Vector3.new(1.6 + rng:NextNumber(), h, 1.6 + rng:NextNumber()), ORIGIN * CFrame.new(math.cos(a) * r, h / 2, math.sin(a) * r) * CFrame.Angles(0, a + rng:NextNumber(), math.rad(rng:NextNumber() * 10 - 5)), rock:Lerp(Color3.fromRGB(80, 30, 30), rng:NextNumber() * 0.6))
	end
	part(folder, Vector3.new(3.4, 3.2, 3.4), ORIGIN * CFrame.new(0, 1.7, 0), rock)
	part(folder, Vector3.new(0.5, 4.6, 4.6), ORIGIN * CFrame.new(0, PLATE_Y - 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 60, 45), nil, Enum.PartType.Cylinder)
	local plate = part(folder, Vector3.new(0.12, 3.7, 3.7), ORIGIN * CFrame.new(0, PLATE_Y - 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, Enum.PartType.Cylinder)
	local plateLight = light(plate, Color3.fromRGB(255, 150, 70), 1.6, 12)
	-- rubble steps in front, bones scattered
	for i = -2, 2 do
		part(folder, Vector3.new(1.4, 0.9, 1.2), ORIGIN * CFrame.new(i * 1.3, 0.45, 3.1 + math.abs(i) * 0.2) * CFrame.Angles(0, i * 0.3, 0), rock:Lerp(Color3.new(0, 0, 0), 0.25))
	end
	local bone = Color3.fromRGB(245, 225, 200)
	for _, b in { { 3.6, 2.4, 20 }, { -3.8, 2.8, -30 }, { 4.6, 3.6, 70 }, { -2.6, 3.9, 50 } } do
		part(folder, Vector3.new(1.6, 0.35, 0.35), ORIGIN * CFrame.new(b[1], 0.2, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0), bone)
		part(folder, Vector3.new(0.55, 0.55, 0.55), ORIGIN * CFrame.new(b[1] + 0.7, 0.3, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0), bone)
	end
	part(folder, Vector3.new(1.4, 1.2, 1.3), ORIGIN * CFrame.new(3.4, 0.6, 2.2) * CFrame.Angles(0, -0.5, 0), bone) -- a skull
	claw(folder, -1)
	claw(folder, 1)
	brazier(folder, -4.3)
	brazier(folder, 4.3)
	-- autumn pines behind, out of focus
	local pal = { Color3.fromRGB(190, 120, 46), Color3.fromRGB(170, 82, 40), Color3.fromRGB(200, 152, 62), Color3.fromRGB(40, 72, 82) }
	for i = 1, 30 do
		local x = rng:NextNumber(-40, 40)
		local z = rng:NextNumber(-48, -14)
		pine(folder, (ORIGIN * CFrame.new(x, 0, z)).Position, rng:NextNumber(10, 18), pal[rng:NextInteger(1, #pal)])
	end
	-- a few at the sides, set well back and low so they frame the shrine without crowding it
	for i = 1, 6 do
		pine(folder, (ORIGIN * CFrame.new((if i % 2 == 0 then 1 else -1) * rng:NextNumber(16, 26), 0, rng:NextNumber(-12, -4))).Position, rng:NextNumber(8, 12), pal[rng:NextInteger(1, #pal)])
	end
	-- the dusk sky: the game's painted skybox doesn't follow the clock, so the shrine gets its own backdrop, walls
	-- far behind with a deep-blue gradient (unlit, so it reads like a sky), blurred by the depth of field
	local function skyWall(cf: CFrame, w: number, h: number)
		local p = part(folder, Vector3.new(w, h, 1), ORIGIN * cf, Color3.fromRGB(20, 26, 70))
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.LightInfluence = 0
		sg.CanvasSize = Vector2.new(64, 64)
		sg.Parent = p
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = WHITE
		f.Parent = sg
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 38)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(16, 22, 66)),
			ColorSequenceKeypoint.new(0.78, Color3.fromRGB(36, 46, 116)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 80, 156)),
		})
		g.Parent = f
	end
	-- one wall, big enough to fill the whole view (the camera only ever looks this way); Front faces the shrine
	skyWall(CFrame.new(0, 70, -75) * CFrame.Angles(0, math.pi, 0), 700, 170)
	-- rays behind the reveal (hidden until then)
	local raysAnchor = part(folder, Vector3.one, ORIGIN * CFrame.new(0, PLATE_Y + 3.2, -1.5), WHITE)
	raysAnchor.Transparency = 1
	local raysBoard = Instance.new("BillboardGui")
	raysBoard.Adornee = raysAnchor
	raysBoard.LightInfluence = 0
	raysBoard.Size = UDim2.fromScale(0, 0)
	raysBoard.Parent = raysAnchor
	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Size = UDim2.fromScale(1, 1)
	rays.Image = (Config.ICONS and Config.ICONS.ui_rays ~= "" and Config.ICONS.ui_rays) or ICONS.ui_rays or TEX.VS_Starburst or ""
	rays.ImageTransparency = 1
	rays.Parent = raysBoard
	folder.Parent = cam

	local s = {} :: Stage
	s.folder = folder
	s.cam = cam
	s.oldType = cam.CameraType
	s.oldCF = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	s.camCF = ORIGIN * CFrame.lookAt(CAM_REST + Vector3.new(0, 1.5, 7), CAM_LOOK)
	cam.CFrame = s.camCF
	s.shake = 0
	s.plateLight = plateLight
	s.rays = rays
	s.raysBoard = raysBoard
	s.dof = Instance.new("DepthOfFieldEffect")
	s.dof.Name = "HatchDOF"
	s.dof.FocusDistance = 17
	s.dof.InFocusRadius = 6
	s.dof.NearIntensity = 0
	s.dof.FarIntensity = 0.8
	s.dof.Parent = Lighting
	s.cc = Instance.new("ColorCorrectionEffect")
	s.cc.Name = "HatchGrade"
	s.cc.Saturation = 0.2
	s.cc.Contrast = 0.08
	s.cc.TintColor = Color3.fromRGB(235, 228, 255)
	s.cc.Parent = Lighting
	-- dusk at the shrine like the reference (deep blue sky, warm lights): the world's lighting is put back on close
	s.mood = {}
	local MOOD = { ClockTime = 19.4, Brightness = 1.4, ExposureCompensation = -0.15, Ambient = Color3.fromRGB(96, 84, 128), OutdoorAmbient = Color3.fromRGB(92, 96, 150) }
	for prop, v in MOOD do
		s.mood[prop] = (Lighting :: any)[prop];
		(Lighting :: any)[prop] = v
	end
	s.moodSet = MOOD
	s.bloom = {}
	for _, b in Lighting:GetChildren() do
		if b:IsA("Atmosphere") then
			s.bloom[b] = { b.Density, b.Haze }
			b.Density = 0
			b.Haze = 0
		elseif b:IsA("BloomEffect") then
			s.bloom[b] = { b.Intensity, b.Threshold }
			b.Intensity = math.min(b.Intensity, 0.35)
			b.Threshold = math.max(b.Threshold, 1.5)
		elseif b:IsA("SunRaysEffect") then
			s.bloom[b] = { b.Intensity, b.Spread }
			b.Intensity = 0
		end
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	s.gui = Instance.new("ScreenGui")
	s.gui.Name = "HatchGui"
	s.gui.IgnoreGuiInset = true
	s.gui.DisplayOrder = 60
	s.gui.ResetOnSpawn = false
	-- every other screen (HUD, banners, the DEV button) steps aside: only the shrine and the hatch UI on screen.
	-- The confetti layer comes along (it lives in the main UI screen), and goes back on close.
	s.hiddenGuis = {}
	s.confetti = nil
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			local c = g:FindFirstChild("Confetti")
			if c and c:IsA("Frame") then
				s.confetti = { c, g }
				c.Parent = s.gui
			end
			g.Enabled = false
			table.insert(s.hiddenGuis, g)
		end
	end
	s.gui.Parent = playerGui
	return s
end

-------------------------------------------------------------------------------------------------------------
-- screen bits
-------------------------------------------------------------------------------------------------------------
local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, stroke: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.ZIndex = 5
	if stroke and stroke > 0 then
		local st = Instance.new("UIStroke")
		st.Thickness = stroke
		st.Color = INK
		st.Parent = l
	end
	l.Parent = parent
	return l
end

local function flash(s: Stage, color: Color3, strength: number, time: number?)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - strength
	f.ZIndex = 1
	f.Parent = s.gui
	TweenService:Create(f, TweenInfo.new(time or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.delay((time or 0.4) + 0.05, f.Destroy, f)
end

local function scaled(gui: GuiObject, from: number): UIScale
	local sc = Instance.new("UIScale")
	sc.Scale = from
	sc.Parent = gui
	return sc
end

-- TAP TO OPEN with a pointing hand, pulsing
local function tapPrompt(s: Stage, k: number): Frame
	local f = Instance.new("Frame")
	f.Name = "TapPrompt"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Position = UDim2.new(0.5, 0, 1, -40 * k)
	f.Size = UDim2.fromOffset(200 * k, 90 * k)
	f.Parent = s.gui
	label(f, "TAP TO", UDim2.new(0.6, 0, 0.26, 0), UDim2.fromScale(0.42, 0.18), WHITE, 2 * k)
	label(f, "OPEN", UDim2.new(0.7, 0, 0.5, 0), UDim2.fromScale(0.42, 0.6), WHITE, 3 * k)
	local hand = label(f, "👆", UDim2.new(0.3, 0, 0.6, 0), UDim2.fromScale(0.86, 0.62), WHITE, 0)
	hand.Rotation = -25
	local sc = scaled(f, 0)
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		while f.Parent do
			local t = os.clock()
			if sc.Scale > 0.95 then
				sc.Scale = 1 + math.sin(t * 6) * 0.05
			end
			hand.Position = UDim2.fromScale(0.86 + math.sin(t * 6) * 0.015, 0.62 + math.abs(math.sin(t * 6)) * 0.06)
			task.wait()
		end
	end)
	return f
end

-------------------------------------------------------------------------------------------------------------
-- eggs
-------------------------------------------------------------------------------------------------------------
type Egg = {
	index: number,
	pet: any,
	rank: number,
	fresh: boolean,
	chance: number,
	path: { string }, -- the rarities it climbs through, first = its starting colour
	step: number,
	tier: string,
	home: CFrame,
	scale: number,
	model: Model,
	baseColors: { [BasePart]: Color3 },
	hl: Highlight,
	aura: ImageLabel,
	auraBoard: BillboardGui,
	att: Attachment,
	fxPart: Part,
	glow: PointLight,
	punch: number,
	tilt: number,
	burst: boolean,
	petModel: Model?,
	petColors: { [BasePart]: Color3 },
	petMats: { [BasePart]: Enum.Material },
	petScale: number,
	petT: number,
	revealed: boolean,
	tag: BillboardGui?,
}

local function eggModel(eggId: string, color: Color3): Model
	local m = PartBuild.get(if eggId == "GoldenEgg" then "egg_golden" else "egg_garden")
	if m then
		return m
	end
	m = Instance.new("Model")
	local p = part(m, Vector3.new(3, 3.8, 3), CFrame.new(0, 1.9, 0), color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return m
end

-- the climb: from the lowest rarity this egg can give up to the critter's own, through the rarities in between
-- that the egg holds (Mythic only shows on the way to a Secret)
local function climb(eggDef, target: string): { string }
	local has, low = {}, 99
	for _, row in eggDef.pets do
		local p = Config.pet(row[1])
		if p and RANK[p.rarity] then
			has[p.rarity] = true
			low = math.min(low, RANK[p.rarity])
		end
	end
	local top = RANK[target] or 1
	low = math.min(low, top)
	local path = {}
	for r = low, top do
		local name = LADDER[r]
		if r == low or r == top or has[name] or (name == "Mythic" and target == "Secret") then
			table.insert(path, name)
		end
	end
	return path
end

local function chanceOf(eggDef, id: string): number
	local luck = (State.data and State.data.hatchLuck) or 1
	for _, r in Config.eggOdds(eggDef, luck) do
		if r[1] == id then
			return r[2]
		end
	end
	return 0
end

local function pctText(x: number): string
	local p = x * 100
	if p >= 10 then
		return ("%d%%"):format(math.floor(p + 0.5))
	elseif p >= 1 then
		return (("%.1f"):format(p):gsub("%.0$", "")) .. "%"
	end
	return (("%.2f"):format(p):gsub("0+$", ""):gsub("%.$", "")) .. "%"
end

local function tint(e: Egg, tier: string, t: number)
	local c = rarityColor(tier, t)
	for p, base in e.baseColors do
		p.Color = base:Lerp(c, 0.62)
	end
	e.hl.FillColor = c
	e.hl.OutlineColor = c:Lerp(WHITE, 0.6)
	e.aura.ImageColor3 = c
	e.glow.Color = c
end

local function layout(n: number): { { x: number, y: number, scale: number } }
	local out = {}
	if n == 1 then
		return { { x = 0, y = 0, scale = 1.25 } }
	end
	local rows = if n > 5 then 2 else 1
	local perRow = math.ceil(n / rows)
	local scale = if rows == 1 then 0.8 else 0.58
	local gap = if rows == 1 then 3.4 else 2.7
	for i = 1, n do
		local row = (i - 1) // perRow
		local col = (i - 1) % perRow
		local inRow = math.min(perRow, n - row * perRow)
		table.insert(out, { x = (col - (inRow - 1) / 2) * gap, y = if rows == 1 then 0.2 else (if row == 0 then 2.6 else 0), scale = scale })
	end
	return out
end

local function makeEggs(s: Stage, eggDef, ids: { string }, fresh: { boolean }?): { Egg }
	local list = {}
	for i, sp in layout(#ids) do
		local def = Config.pet(ids[i])
		if not def then
			continue
		end
		local m = eggModel(eggDef.id, eggDef.color)
		local bb = m:GetBoundingBox()
		m.WorldPivot = bb
		m:ScaleTo(sp.scale)
		local baseColors = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CastShadow = false
				baseColors[d] = d.Color
			end
		end
		local hl = Instance.new("Highlight")
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.FillTransparency = 0.55
		hl.OutlineTransparency = 0.25
		hl.Parent = m
		m.Parent = s.folder
		local home = ORIGIN * CFrame.new(sp.x, PLATE_Y + 2.1 * sp.scale + sp.y, 0)
		local fxPart = part(s.folder, Vector3.one, home, WHITE)
		fxPart.Transparency = 1
		local att = Instance.new("Attachment")
		att.Parent = fxPart
		local glow = light(fxPart, WHITE, 1.4, 10 * sp.scale)
		local auraBoard = Instance.new("BillboardGui")
		auraBoard.Adornee = fxPart
		auraBoard.LightInfluence = 0
		auraBoard.Size = UDim2.fromScale(7.5 * sp.scale, 7.5 * sp.scale)
		auraBoard.StudsOffsetWorldSpace = Vector3.new(0, 0, -1.2)
		auraBoard.Parent = fxPart
		local aura = Instance.new("ImageLabel")
		aura.BackgroundTransparency = 1
		aura.Size = UDim2.fromScale(1, 1)
		aura.Image = TEX.Glow or ICONS.glow_soft or SPARKLE
		aura.ImageTransparency = 0.5
		aura.Parent = auraBoard
		local path = climb(eggDef, def.rarity)
		local e: Egg = {
			index = i,
			pet = def,
			rank = RANK[def.rarity] or 1,
			fresh = fresh ~= nil and fresh[i] == true,
			chance = chanceOf(eggDef, def.id),
			path = path,
			step = 1,
			tier = path[1],
			home = home,
			scale = sp.scale,
			model = m,
			baseColors = baseColors,
			hl = hl,
			aura = aura,
			auraBoard = auraBoard,
			att = att,
			fxPart = fxPart,
			glow = glow,
			punch = 0,
			tilt = 0,
			burst = false,
			petModel = nil,
			petColors = {},
			petMats = {},
			petScale = 1,
			petT = 0,
			revealed = false,
			tag = nil,
		}
		tint(e, e.tier, 0)
		m:PivotTo(home * CFrame.new(0, 8, 0))
		table.insert(list, e)
	end
	return list
end

-------------------------------------------------------------------------------------------------------------
-- effects
-------------------------------------------------------------------------------------------------------------
local function starburst(e: Egg, color: Color3, size: number, life: number)
	local sb = emitter(e.att, {
		Texture = TEX.VS_Starburst or TEX.Star4 or SPARKLE,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.35), NumberSequenceKeypoint.new(0.35, size), NumberSequenceKeypoint.new(1, size * 1.15) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(life),
		Rotation = NumberRange.new(0, 360),
		Brightness = 3,
		ZOffset = 2,
	})
	sb:Emit(2)
	task.delay(life + 0.1, sb.Destroy, sb)
end

local function sparks(e: Egg, color: Color3, n: number)
	local sp = emitter(e.att, {
		Texture = TEX.Spark or SPARKLE,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * e.scale), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(16 * e.scale, 30 * e.scale),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		Brightness = 3,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		ZOffset = 2,
	})
	sp:Emit(math.floor(n * FEW))
	task.delay(0.8, sp.Destroy, sp)
end

-- the swirl: crescent slashes spinning round the egg in the new colour, plus a ring
local function swirl(e: Egg, color: Color3, big: number)
	local cr = emitter(e.att, {
		Texture = TEX.VS_Crescent8x8 or TEX.Slash or TEX.RingThin or SPARKLE,
		FlipbookLayout = if TEX.VS_Crescent8x8 then Enum.ParticleFlipbookLayout.Grid8x8 else Enum.ParticleFlipbookLayout.None,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(color:Lerp(WHITE, 0.25), color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5 * e.scale * big), NumberSequenceKeypoint.new(1, 9 * e.scale * big) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.7),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(380, 560),
		Brightness = 4,
		ZOffset = 1,
	})
	cr:Emit(math.max(3, math.floor(6 * FEW)))
	local ring = emitter(e.att, {
		Texture = TEX.RingShock or TEX.RingThin or SPARKLE,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * e.scale), NumberSequenceKeypoint.new(1, 10 * e.scale * big) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5),
		Brightness = 3,
	})
	ring:Emit(1)
	task.delay(0.9, function()
		cr:Destroy()
		ring:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the critter: silhouette rises, then colour
-------------------------------------------------------------------------------------------------------------
local function spawnPet(s: Stage, e: Egg)
	local m = PetFollow.build(e.pet.look)
	local bb, size = m:GetBoundingBox()
	m.WorldPivot = bb
	e.petScale = (3.2 * e.scale * (1 + (e.rank - 1) * 0.05)) / math.max(size.X, size.Y, size.Z, 0.1)
	m:ScaleTo(e.petScale * 0.2)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
			e.petColors[d] = d.Color
			e.petMats[d] = d.Material
			d.Color = Color3.new(0, 0, 0)
			d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d:SetAttribute("T0", d.Transparency)
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
	local hl = Instance.new("Highlight")
	hl.Name = "Silhouette"
	hl.FillColor = Color3.new(0, 0, 0)
	hl.FillTransparency = 0
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
	m:PivotTo(e.home * CFrame.new(0, -1.2 * e.scale, 0))
	m.Parent = s.folder
	e.petModel = m
	e.petT = 0
end

local function colourPet(e: Egg)
	local m = e.petModel
	if not m then
		return
	end
	for p, c in e.petColors do
		p.Color = c
		p.Material = e.petMats[p] or p.Material
	end
	for _, d in m:GetDescendants() do
		if (d:IsA("Decal") or d:IsA("Texture")) and d:GetAttribute("T0") ~= nil then
			d.Transparency = d:GetAttribute("T0")
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = true
		end
	end
	local hl = m:FindFirstChild("Silhouette") :: Highlight?
	if hl then
		hl.FillColor = rarityColor(e.pet.rarity)
		hl.FillTransparency = 0.2
		TweenService:Create(hl, TweenInfo.new(0.5), { FillTransparency = 1 }):Play()
		task.delay(0.55, hl.Destroy, hl)
	end
	e.revealed = true
end

local function updatePet(e: Egg, dt: number)
	local m = e.petModel
	if not m then
		return
	end
	e.petT += dt
	local t = e.petT
	-- rise out of the light (ease out), grow in, then bob and turn slowly
	local rise = 1 - (1 - clamp01(t / 0.75)) ^ 3
	local grow = if t < 0.5 then easeOutBack(clamp01(t / 0.5)) else 1
	local pop = if e.revealed then math.exp(-math.max(0, t - 0.9) * 7) * 0.18 else 0
	local y = -1.2 * e.scale + rise * (1.9 * e.scale) + math.sin(t * 2.2) * 0.18 * e.scale * clamp01(t - 0.8)
	local yaw = math.sin(t * 0.9) * math.rad(18)
	m:ScaleTo(math.max(0.02, e.petScale * math.max(grow, 0.05) * (1 + pop)))
	m:PivotTo(e.home * CFrame.new(0, y, 0) * CFrame.Angles(0, math.pi + yaw, 0))
end

-------------------------------------------------------------------------------------------------------------
-- the result screen
-------------------------------------------------------------------------------------------------------------
local function button(parent: Instance, text: string, top: Color3, bottom: Color3, size: UDim2, pos: UDim2, k: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = WHITE
	b.Text = ""
	b.ZIndex = 6
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12 * k)
	c.Parent = b
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = b
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Thickness = 3 * k
	st.Color = INK
	st.Parent = b
	local l = label(b, text, UDim2.new(0.88, 0, 0.62, 0), UDim2.fromScale(0.5, 0.5), WHITE, 2.5 * k)
	l.ZIndex = 7
	local sc = scaled(b, 1)
	b.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		Sound.play("click")
		onClick()
	end)
	return b
end

local function againInfo(eggDef, n: number): (string, boolean, string?)
	-- the price line under HATCH AGAIN, whether you can afford it, and the product to prompt (Robux eggs)
	if eggDef.currency == "gems" then
		local cost = (eggDef.price or 0) * n
		local gems = (State.data and State.data.gems) or 0
		return tostring(cost), gems >= cost, nil
	end
	local key = nil
	for _, pr in eggDef.products or {} do
		if pr.count == n then
			key = pr.key
		end
	end
	key = key or (eggDef.products and eggDef.products[1] and eggDef.products[1].key)
	local product = key and Config.PRODUCTS and Config.PRODUCTS[key]
	return if product then "R$ " .. tostring(product.robux) else "", true, key
end

local function resultScreen(s: Stage, eggDef, eggs: { Egg }, best: Egg, onPick: (string) -> ())
	local vp = s.cam.ViewportSize
	local k = math.clamp(vp.Y / 720, 0.6, 1.6)
	local root = Instance.new("Frame")
	root.Name = "Result"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 4
	root.Parent = s.gui
	local color = rarityColor(best.pet.rarity)
	-- the rarity bar: rarity on the left, its chance on the right
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 34 * k)
	bar.Size = UDim2.fromOffset(330 * k, 30 * k)
	bar.BackgroundColor3 = Color3.fromRGB(20, 14, 24)
	bar.BackgroundTransparency = 0.25
	bar.Name = "RarityBar"
	bar.ZIndex = 5
	bar.Parent = root
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8 * k)
	bc.Parent = bar
	local rname = NAME[best.pet.rarity] or string.upper(best.pet.rarity)
	local rl = label(bar, rname, UDim2.new(0.6, 0, 0.7, 0), UDim2.fromScale(0.33, 0.5), color, 1.5 * k)
	rl.TextXAlignment = Enum.TextXAlignment.Left
	local pl = label(bar, pctText(best.chance), UDim2.new(0.3, 0, 0.7, 0), UDim2.fromScale(0.82, 0.5), WHITE, 1.5 * k)
	pl.TextXAlignment = Enum.TextXAlignment.Right
	if best.pet.rarity == "Secret" then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 150, 255)),
		})
		g.Parent = rl
		rl.TextColor3 = WHITE
	end
	-- the name, huge, slams in
	local nm = label(root, string.upper(best.pet.name), UDim2.fromOffset(560 * k, 66 * k), UDim2.new(0.5, 0, 0, 104 * k), WHITE, 4 * k)
	local nsc = scaled(nm, 2.4)
	TweenService:Create(nsc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if #eggs > 1 then
		-- under the name (and under NEW! when there is one)
		label(root, ("x%d HATCHED"):format(#eggs), UDim2.fromOffset(200 * k, 24 * k), UDim2.new(0.5, 0, 0, (if best.fresh then 186 else 152) * k), Color3.fromRGB(230, 220, 255), 2 * k)
	end
	if best.fresh then
		local new = label(root, "NEW!", UDim2.fromOffset(120 * k, 34 * k), UDim2.new(0.5, 0, 0, 152 * k), Color3.fromRGB(255, 222, 40), 3 * k)
		local s2 = scaled(new, 0)
		TweenService:Create(s2, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.15), { Scale = 1 }):Play()
		task.spawn(function()
			while new.Parent do
				new.Rotation = math.sin(os.clock() * 5) * 4
				task.wait()
			end
		end)
	end
	-- the bottom row: price, + MORE GEMS, HATCH AGAIN, LEAVE (they rise in)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Size = UDim2.fromOffset(620 * k, 120 * k)
	row.Position = UDim2.new(0.5, 0, 1, 140 * k)
	row.Name = "Buttons"
	row.ZIndex = 5
	row.Parent = root
	local n = #eggs
	local price, afford, _ = againInfo(eggDef, n)
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.17)
	pill.Size = UDim2.fromOffset(104 * k, 26 * k)
	pill.BackgroundColor3 = Color3.fromRGB(20, 14, 24)
	pill.BackgroundTransparency = 0.25
	pill.ZIndex = 5
	pill.Parent = row
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(1, 0)
	pc.Parent = pill
	local pt = label(pill, price, UDim2.new(0.62, 0, 0.75, 0), UDim2.fromScale(0.6, 0.5), if afford then WHITE else Color3.fromRGB(255, 110, 110), 1.5 * k)
	pt.TextXAlignment = Enum.TextXAlignment.Left
	if eggDef.currency == "gems" then
		local gi = Instance.new("ImageLabel")
		gi.BackgroundTransparency = 1
		gi.AnchorPoint = Vector2.new(0.5, 0.5)
		gi.Position = UDim2.fromScale(0.18, 0.5)
		gi.Size = UDim2.fromOffset(22 * k, 22 * k)
		gi.Image = ICONS.gem or ""
		gi.ZIndex = 6
		gi.Parent = pill
	end
	local purpleTop, purpleBot = Color3.fromRGB(196, 110, 255), Color3.fromRGB(122, 50, 210)
	button(row, "+ MORE GEMS", purpleTop, purpleBot, UDim2.fromOffset(120 * k, 46 * k), UDim2.fromScale(0.12, 0.66), k, function()
		onPick("gems")
	end).Name = "MoreGems"
	local again = button(row, "HATCH AGAIN", if afford then purpleTop else Color3.fromRGB(160, 150, 170), if afford then purpleBot else Color3.fromRGB(110, 100, 120), UDim2.fromOffset(300 * k, 64 * k), UDim2.fromScale(0.5, 0.62), k, function()
		onPick("again")
	end)
	again.Name = "HatchAgain"
	button(row, "LEAVE", Color3.fromRGB(196, 110, 60), Color3.fromRGB(140, 70, 36), UDim2.fromOffset(120 * k, 46 * k), UDim2.fromScale(0.88, 0.66), k, function()
		onPick("leave")
	end).Name = "Leave"
	TweenService:Create(row, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.2), { Position = UDim2.new(0.5, 0, 1, -18 * k) }):Play()
	-- several eggs: a small tag over each critter
	if n > 1 then
		for _, e in eggs do
			local g = Instance.new("BillboardGui")
			g.Adornee = e.fxPart
			g.LightInfluence = 0
			g.Size = UDim2.fromOffset(120 * k, 34 * k)
			-- on the altar's lip, in front of the rocks (AlwaysOnTop billboards don't draw from under the camera)
			g.StudsOffsetWorldSpace = Vector3.new(0, -1.3, 3.6)
			g.Parent = e.fxPart -- (in the world, so it draws with the critter)
			local a = label(g, e.pet.name, UDim2.fromScale(1, 0.58), UDim2.fromScale(0.5, 0.3), WHITE, 2 * k)
			a.ZIndex = 1
			local b = label(g, NAME[e.pet.rarity] or string.upper(e.pet.rarity), UDim2.fromScale(0.8, 0.42), UDim2.fromScale(0.5, 0.8), rarityColor(e.pet.rarity), 1.5 * k)
			b.ZIndex = 1
			e.tag = g
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- close
-------------------------------------------------------------------------------------------------------------
local function close(s: Stage, after: string?, onDone: (() -> ())?)
	HatchFx.after = after
	for _, g in s.gui:GetDescendants() do
		if g:IsA("UIScale") then
			TweenService:Create(g, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		end
	end
	flash(s, Color3.new(0, 0, 0), 1, 0.45)
	task.delay(0.12, function()
		s.folder:Destroy()
		s.dof:Destroy()
		s.cc:Destroy()
		for prop, v in s.mood do
			(Lighting :: any)[prop] = v
		end
		for b, v in s.bloom do
			if b:IsA("BloomEffect") then
				b.Intensity, b.Threshold = v[1], v[2]
			elseif b:IsA("SunRaysEffect") then
				b.Intensity = v[1]
			elseif b:IsA("Atmosphere") then
				b.Density, b.Haze = v[1], v[2]
			end
		end
		s.cam.CameraType = s.oldType
		s.cam.CFrame = s.oldCF
	end)
	task.delay(0.5, function()
		if s.confetti and s.confetti[2].Parent then
			s.confetti[1].Parent = s.confetti[2]
		end
		s.gui:Destroy()
		for _, g in s.hiddenGuis do
			if g.Parent then
				g.Enabled = true
			end
		end
		HatchFx.busy = false
		if onDone then
			onDone()
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- main
-------------------------------------------------------------------------------------------------------------
-- Play the hatch. `fresh[i]` = pet i is new to this player (NEW! badge). `onDone` runs after it closes.
function HatchFx.play(eggId: string, ids: { string }, fresh: { boolean }?, onDone: (() -> ())?)
	local eggDef = Config.egg(eggId)
	if not eggDef or #ids == 0 then
		if onDone then
			onDone()
		end
		return
	end
	HatchFx.busy = true
	HatchFx.after = nil
	local s = buildShrine()
	local eggs = makeEggs(s, eggDef, ids, fresh)
	local best = eggs[1]
	local upgrades = 0
	for _, e in eggs do
		if e.rank > best.rank then
			best = e
		end
		upgrades = math.max(upgrades, #e.path - 1)
	end
	-- the taps: a couple of plain punches first, then one upgrade per tap, then the tap that opens it
	local plan = {}
	local plain = math.max(1, 3 - upgrades)
	for _ = 1, plain do
		table.insert(plan, "punch")
	end
	for _ = 1, upgrades do
		table.insert(plan, "up")
	end
	table.insert(plan, "open")
	local vp = s.cam.ViewportSize
	local k = math.clamp(vp.Y / 720, 0.6, 1.6)

	local phase = "intro"
	local t, tapIdx, lastTap, openAt = 0, 0, 0, 0
	local prompt: Frame? = nil
	local finished = false
	local conn, input

	local function finish(choice: string)
		if finished then
			return
		end
		finished = true
		conn:Disconnect()
		input:Disconnect()
		RunService:UnbindFromRenderStep("HatchCam")
		HatchFx.tap = nil
		HatchFx.pick = nil
		local after = if choice == "leave" then nil else choice
		close(s, after, onDone)
		if choice == "again" then
			local _, _, product = againInfo(eggDef, #ids)
			task.delay(0.55, function()
				if eggDef.currency == "gems" then
					State.fire("Hatch", eggDef.id, if #ids == 3 then 3 else 1)
				elseif product then
					State.fire("Prompt", "product", product)
				end
			end)
		elseif choice == "gems" then
			task.delay(0.55, function()
				local ok, UI = pcall(require, modules:FindFirstChild("UI"))
				if ok and UI and UI.open then
					UI.open("Store")
				end
			end)
		end
	end

	local function doTap()
		if phase ~= "tap" or t - lastTap < TAP_GAP then
			return
		end
		lastTap = t
		tapIdx += 1
		local what = plan[tapIdx] or "open"
		local pitch = 0.9 + tapIdx * 0.08
		if what == "open" then
			phase = "burst"
			openAt = t
			if prompt then
				local sc = prompt:FindFirstChildOfClass("UIScale")
				if sc then
					TweenService:Create(sc, TweenInfo.new(0.15), { Scale = 0 }):Play()
				end
				task.delay(0.2, prompt.Destroy, prompt)
			end
			Sound.play("burst")
			Sound.playAt("slam", 1, 0.9)
			for _, e in eggs do
				e.burst = true
				starburst(e, WHITE, 11 * e.scale, 0.55)
				sparks(e, rarityColor(e.pet.rarity, t), 30)
				e.model:Destroy()
				e.aura.ImageTransparency = 0
				e.aura.ImageColor3 = WHITE
				TweenService:Create(e.auraBoard, TweenInfo.new(0.25), { Size = UDim2.fromScale(14 * e.scale, 14 * e.scale) }):Play()
				TweenService:Create(e.aura, TweenInfo.new(0.9), { ImageColor3 = rarityColor(e.pet.rarity), ImageTransparency = 0.55 }):Play()
				e.glow.Color = WHITE
				e.glow.Brightness = 2.5
				spawnPet(s, e)
			end
			flash(s, WHITE, 0.9, 0.6)
			s.shake = 1
			return
		end
		Sound.playAt("click", pitch, 0.9)
		Sound.playAt("punch", pitch, 0.6)
		for _, e in eggs do
			e.punch = 1
			e.tilt = (math.random() - 0.5) * 2
			starburst(e, WHITE, 4.5 * e.scale, 0.28)
			sparks(e, rarityColor(e.tier, t), 10)
			if what == "up" and e.step < #e.path then
				e.step += 1
				e.tier = e.path[e.step]
				local c = rarityColor(e.tier, t)
				tint(e, e.tier, t)
				swirl(e, c, 1)
				e.punch = 1.5
			end
		end
		if what == "up" then
			Sound.playAt("upgrade", pitch, 0.9)
			local c = rarityColor(best.tier, t)
			flash(s, c, 0.35, 0.35)
			s.plateLight.Color = c
			if RANK[best.tier] >= RANK.Legendary then
				Sound.play("rareChime")
				s.shake = math.max(s.shake, 0.55)
			end
		end
		s.shake = math.max(s.shake, 0.3)
	end

	HatchFx.tap = doTap -- (tests: tap / pick a result button from code)
	HatchFx.pick = function(choice: string)
		if phase == "result" then
			finish(choice)
		end
	end

	-- the camera is placed after every other camera step (Roblox's, CameraView's feel, the run intro / ClassRoom /
	-- boss cams sit at +1 / +2), every frame, so nothing can take it back mid-hatch; Focus on the shrine so lighting
	-- and detail render there, not round the character
	RunService:BindToRenderStep("HatchCam", Enum.RenderPriority.Camera.Value + 10, function()
		if s.cam.CameraType ~= Enum.CameraType.Scriptable then
			s.cam.CameraType = Enum.CameraType.Scriptable
		end
		s.cam.CFrame = s.camCF
		s.cam.Focus = ORIGIN * CFrame.new(CAM_LOOK)
		if Lighting.ClockTime ~= s.moodSet.ClockTime then
			Lighting.ClockTime = s.moodSet.ClockTime -- (a day/night script would drag it back)
		end
	end)

	input = UserInputService.InputBegan:Connect(function(io, processed)
		if phase == "tap" then
			local tap = io.UserInputType == Enum.UserInputType.MouseButton1
				or io.UserInputType == Enum.UserInputType.Touch
				or io.KeyCode == Enum.KeyCode.ButtonA
				or io.KeyCode == Enum.KeyCode.Space
				or io.KeyCode == Enum.KeyCode.Return
			if tap and not (processed and io.UserInputType == Enum.UserInputType.Keyboard) then
				doTap()
			end
		elseif phase == "result" then
			if io.KeyCode == Enum.KeyCode.ButtonB or io.KeyCode == Enum.KeyCode.Escape then
				finish("leave")
			elseif io.KeyCode == Enum.KeyCode.ButtonX then
				finish("again")
			end
		end
	end)

	conn = RunService.RenderStepped:Connect(function(dt)
		dt *= HatchFx.timeScale
		t += dt
		-- camera: a short push-in at the start, then a slow drift; shake decays
		local push = 1 - (1 - clamp01(t / 0.7)) ^ 3
		local camPos = (CAM_REST + Vector3.new(0, 1.5, 7)):Lerp(CAM_REST, push) + Vector3.new(math.sin(t * 0.4) * 0.25, 0, 0)
		if phase == "result" then
			camPos += Vector3.new(0, 0, -math.min(1.2, (t - openAt) * 0.25))
		end
		local base = ORIGIN * CFrame.lookAt(camPos, CAM_LOOK)
		s.shake = math.max(0, s.shake - dt * 2.4)
		local j = s.shake * s.shake
		s.camCF = base * CFrame.Angles((math.random() - 0.5) * 0.04 * j, (math.random() - 0.5) * 0.04 * j, (math.random() - 0.5) * 0.03 * j)

		if phase == "intro" and t > 0.75 then
			phase = "tap"
			lastTap = t
			prompt = tapPrompt(s, k)
		end
		if phase == "tap" and t - lastTap > AUTO_TAP then
			doTap()
		end

		-- the eggs: drop in, then float, bob, turn; a tap punches them (scale + tilt that springs back)
		for _, e in eggs do
			if e.burst then
				continue
			end
			local drop = 1 - clamp01(t / 0.55)
			local land = if t > 0.55 then math.exp(-(t - 0.55) * 8) * math.sin((t - 0.55) * 22) * 0.12 else 0
			e.punch = math.max(0, e.punch - dt * 5)
			local p = e.punch
			local sc = e.scale * (1 + p * 0.16 - land * 0.5)
			local bob = math.sin(t * 2.4 + e.index) * 0.22 * e.scale
			local yaw = t * 0.6 + e.index
			local tilt = e.tilt * p * math.rad(14)
			e.model:ScaleTo(math.max(0.05, sc))
			e.model:PivotTo(e.home * CFrame.new(0, drop * drop * 8 + bob, 0) * CFrame.Angles(0, yaw, tilt))
			if e.tier == "Secret" then
				tint(e, "Secret", t)
			end
			e.auraBoard.Size = UDim2.fromScale(7.5 * e.scale * (1 + p * 0.25 + math.sin(t * 3) * 0.04), 7.5 * e.scale * (1 + p * 0.25 + math.sin(t * 3) * 0.04))
			e.glow.Brightness = 1.4 + p * 2
		end

		if phase == "burst" or phase == "result" then
			local since = t - openAt
			for _, e in eggs do
				updatePet(e, dt)
				e.glow.Brightness = math.max(1.2, e.glow.Brightness - dt * 4)
			end
			-- the silhouette has risen: flash it into colour in a swirl of slashes, then the result
			if phase == "burst" and since > 0.95 then
				phase = "result"
				for _, e in eggs do
					local c = rarityColor(e.pet.rarity, t)
					colourPet(e)
					swirl(e, c, 1.35)
					starburst(e, c, 8 * e.scale, 0.4)
					sparks(e, c, 26)
				end
				local c = rarityColor(best.pet.rarity, t)
				flash(s, c, 0.55, 0.5)
				s.shake = 0.7 + best.rank * 0.06
				s.plateLight.Color = c
				s.plateLight.Brightness = 3
				s.rays.ImageColor3 = c
				TweenService:Create(s.rays, TweenInfo.new(0.4), { ImageTransparency = 0.55 }):Play()
				if best.rank >= RANK.Legendary then
					Sound.play("victory")
					Sound.play("rareChime")
					Confetti.burst(math.floor(70 * FEW))
				elseif best.rank >= RANK.Epic then
					Sound.play("reveal")
					Confetti.burst(math.floor(35 * FEW))
				else
					Sound.play("reveal")
				end
				resultScreen(s, eggDef, eggs, best, finish)
			end
			if phase == "result" then
				local size = 12 + best.rank * 2
				s.raysBoard.Size = UDim2.fromScale(size, size)
				s.rays.Rotation = t * 18
				if best.pet.rarity == "Secret" then
					s.rays.ImageColor3 = rarityColor("Secret", t)
				end
			end
		end
	end)
end

return HatchFx
