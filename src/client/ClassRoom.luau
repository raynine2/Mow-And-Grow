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
-- THE ABDUCTION (owner, 27 Oct: "keep it and add a crop circle and a UFO beam" - the lore hook: aliens steal lawns):
--   * a torn-off patch of lawn floats under the avatar, dirt and roots hanging off it, a glowing crop circle pressed
--     into the grass (slowly turning), clippings and motes lifting off it
--   * a little saucer hangs above (rim lights chasing round, a tiny alien in the dome) and pours a light beam down
--     over the avatar: the avatar is being beamed up, so it hovers in the beam instead of flying at the camera
--   * the picked card's class aura (client/RarityFx) plays on the avatar; picking a card flashes the crop circle and
--     the beam and fires a VFX Forge burst
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VFX = require(ReplicatedStorage:WaitForChild("VFXLib"))
local MenuFX = require(script.Parent.MenuFX)
local FxIds = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxIds")) :: { [string]: string }
local RarityFx: any = nil -- the class auras (loaded lazily: it builds its own HUD bits on require)

local ClassRoom = {}

-- (6 Nov, owner: "the background should be like the egg background") the egg hatch's scene (client/HatchSpace: the
-- floating lawn torn out of the valley, the world 2 rift, the home planet, the watching eyes, drifting debris) is
-- built behind the avatar, turned to face this room's camera; the avatar hovers over its pedestal in the UFO's beam.
-- Without that module (it isn't in every copy of the game) the old star room is built instead.
local spaceScene: any = nil
local ISLAND_DROP = -2.6 -- the island's origin under the room's: its plate (PLATE_Y up) sits just under the avatar's feet
local ISLAND_PLATE_Y = 3.7

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
local rune: GuiObject? = nil -- the crop circle (turns slowly)
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
-- the abduction scene's moving bits
local UFO_AT = Vector3.new(8.2, 4.9, 3) -- the saucer: left of the avatar, in the free space under the VS panel (first
-- tried up beside the title: the VS panel and the title covered it there) (6 Nov, owner: "u can't really see the ufo ... why is everything in the middle": straight
-- behind, the title and the avatar covered it); it leans toward the avatar and its beam slants down onto it
local UFO_TILT = CFrame.Angles(math.rad(-8), 0, math.rad(-14)) -- leaning toward the avatar, its top a little to us
local VORTEX_AT = Vector3.new(66, 2, 130) -- far behind the saucer (on screen just behind it): its halo
local ufoParts: { { part: BasePart, off: CFrame } } = {} -- every saucer part and where it sits on the saucer
local ufoLights: { BasePart } = {} -- the rim bulbs (they chase round)
local beams: { Beam } = {}
local beamBase: { number } = {} -- each beam's resting transparency (the flash goes back to it)
local circleArt: { ImageLabel } = {} -- the crop circle's glowing pieces (flashed on a pick)
local beamLight: SpotLight? = nil
local classAura: string? = nil -- the class whose aura the avatar wears
local auraOff: (() -> ())? = nil

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
	earth = "rbxassetid://122328487953962", -- ForgeGUI, 27 Oct: the Earth the lawn was taken from, far below
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

-------------------------------------------------------------------------------------------------------------
-- the abduction: a torn-off lawn patch with a crop circle, a saucer above it and its light beam
-------------------------------------------------------------------------------------------------------------
local TURF_TOP = 0.4 -- the grass surface (the avatar's feet hover ~1.5 studs above it)
local TURF_R = 6.5
local CIRCLE = rgb(110, 236, 255) -- the summoning circle's glow (6 Nov, "a bit messy": cyan like the beam and the saucer's trim; the mint green was a fourth colour)
local BEAM = rgb(150, 245, 255)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder part stood on its end

local function disc(m: Instance, r: number, h: number, y: number, color: Color3, material: Enum.Material): Part
	return part(m, Vector3.new(h, r * 2, r * 2), CFrame.new(0, y, 0.6) * UPRIGHT, color, material, Enum.PartType.Cylinder)
end

-- the crop circle: pressed-flat rings in the grass, three satellite circles on spokes, a dotted outer ring; it glows
local function cropCircle(top: BasePart)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.CanvasSize = Vector2.new(512, 512)
	g.Parent = top
	local turn = Instance.new("Frame")
	turn.Name = "CropCircle"
	turn.BackgroundTransparency = 1
	turn.Size = UDim2.fromScale(1, 1)
	turn.Parent = g
	rune = turn
	local function img(image: string, size: number, x: number, y: number, tr: number, color: Color3?): ImageLabel
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.Image = image
		i.ImageColor3 = color or CIRCLE
		i.ImageTransparency = tr
		i.Size = UDim2.fromScale(size, size)
		i.Position = UDim2.fromScale(x, y)
		i.AnchorPoint = Vector2.new(0.5, 0.5)
		i.Parent = turn
		table.insert(circleArt, i)
		i:SetAttribute("Rest", tr)
		return i
	end
	img(Tex.Glow, 1.05, 0.5, 0.5, 0.78) -- the soft glow the whole circle sits in
	img(Tex.RingThin, 0.92, 0.5, 0.5, 0.05)
	img(Tex.RingThin, 0.86, 0.5, 0.5, 0.5)
	img(Tex.RingThin, 0.5, 0.5, 0.5, 0.1)
	img(Tex.RingThin, 0.2, 0.5, 0.5, 0.05)
	img(Tex.Glow, 0.16, 0.5, 0.5, 0.25, Color3.new(1, 1, 1))
	for k = 0, 2 do
		local a = math.rad(k * 120 - 90)
		local x, y = 0.5 + math.cos(a) * 0.35, 0.5 + math.sin(a) * 0.35
		img(Tex.RingThin, 0.17, x, y, 0.05)
		img(Tex.Glow, 0.1, x, y, 0.35)
		-- a spoke from the middle ring out to the satellite
		local spoke = Instance.new("Frame")
		spoke.BorderSizePixel = 0
		spoke.BackgroundColor3 = CIRCLE
		spoke.BackgroundTransparency = 0.25
		spoke.AnchorPoint = Vector2.new(0.5, 0.5)
		spoke.Size = UDim2.fromScale(0.012, 0.11)
		spoke.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.205, 0.5 + math.sin(a) * 0.205)
		spoke.Rotation = math.deg(a) + 90
		spoke:SetAttribute("Rest", 0.25)
		spoke.Parent = turn
	end
	for k = 0, 23 do -- the dotted ring just inside the edge
		local a = math.rad(k * 15)
		img(Tex.Glow, 0.035, 0.5 + math.cos(a) * 0.41, 0.5 + math.sin(a) * 0.41, 0.15)
	end
end

local function turfPatch(m: Instance, rng: Random)
	local grass = disc(m, TURF_R, 0.9, TURF_TOP - 0.45, rgb(92, 176, 62), Enum.Material.Grass)
	grass.Name = "Turf"
	disc(m, TURF_R + 0.15, 0.5, TURF_TOP - 1.05, rgb(70, 132, 48), Enum.Material.Grass) -- the darker turf edge
	-- torn-off earth hanging under it, narrowing to a point (a floating island of lawn)
	for k, r in { TURF_R - 0.2, TURF_R - 1.6, TURF_R - 3.1, 2.2, 1 } do
		disc(m, r, 0.95, TURF_TOP - 1.6 - (k - 1) * 0.85, if k % 2 == 0 then rgb(112, 76, 46) else rgb(128, 88, 54), Enum.Material.Ground)
	end
	-- chunky dirt clods and roots hanging off the underside
	for _ = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1.2, TURF_R - 1.5)
		local s = rng:NextNumber(0.5, 1.1)
		local clod = part(m, Vector3.new(s, s * 1.4, s), CFrame.new(math.cos(a) * r, TURF_TOP - 2.4 - rng:NextNumber(0, 1.4), 0.6 + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)), rgb(104, 70, 42), Enum.Material.Ground)
		clod.Name = "Clod"
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(TURF_R - 2.2, TURF_R - 0.6)
		local len = rng:NextNumber(1.2, 2.4)
		part(m, Vector3.new(0.18, len, 0.18), CFrame.new(math.cos(a) * r, TURF_TOP - 1.6 - len / 2, 0.6 + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), rgb(170, 140, 100), Enum.Material.Wood).Name = "Root"
	end
	-- uncut tufts round the rim (the crop circle is pressed flat, the edge still stands)
	for k = 0, 17 do
		local a = math.rad(k * 20 + rng:NextNumber(-6, 6))
		local r = TURF_R - rng:NextNumber(0.2, 0.7)
		local h = rng:NextNumber(0.5, 0.9)
		local tuft = Instance.new("WedgePart")
		tuft.Anchored, tuft.CanCollide, tuft.CanQuery, tuft.CanTouch, tuft.CastShadow = true, false, false, false, false
		tuft.Size = Vector3.new(0.5, h, 0.5)
		tuft.CFrame = ORIGIN * CFrame.new(math.cos(a) * r, TURF_TOP + h / 2, 0.6 + math.sin(a) * r) * CFrame.Angles(0, -a + math.pi / 2, 0)
		tuft.Color = if k % 3 == 0 then rgb(120, 200, 80) else rgb(98, 182, 66)
		tuft.Material = Enum.Material.SmoothPlastic
		tuft.Parent = m
	end
	-- the crop circle on a thin glass sheet just above the grass
	local sheet = part(m, Vector3.new(TURF_R * 2 - 0.6, 0.05, TURF_R * 2 - 0.6), CFrame.new(0, TURF_TOP + 0.04, 0.6), Color3.new(1, 1, 1))
	sheet.Name = "CropCircle"
	sheet.Transparency = 1
	cropCircle(sheet)
	light(sheet, CIRCLE, 10, 0.9)
	-- clippings and motes lifting off the patch into the beam
	local lift = part(m, Vector3.new(TURF_R * 1.5, 0.1, TURF_R * 1.5), CFrame.new(0, TURF_TOP + 0.2, 0.6), Color3.new(1, 1, 1))
	lift.Transparency = 1
	lift.Name = "Lift"
	emitter(lift, {
		Texture = FxIds.splinter, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(rgb(140, 225, 95), rgb(90, 175, 60)), LightInfluence = 0.4, LightEmission = 0,
		Size = seq(0, 0.35, 1, 0.25), Transparency = seq(0, 1, 0.12, 0, 0.8, 0.2, 1, 1),
		Lifetime = NumberRange.new(3.5, 5), Speed = NumberRange.new(1.2, 2.4), Acceleration = Vector3.new(0, 0.8, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), SpreadAngle = Vector2.new(12, 12), Rate = Budget.Rate(5),
	})
	emitter(lift, {
		Texture = Tex.Glow, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(BEAM), LightEmission = 0.5, Size = seq(0, 0.12, 0.5, 0.3, 1, 0),
		Transparency = seq(0, 1, 0.2, 0.3, 1, 1), Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(2, 3.5), Rate = Budget.Rate(8),
	})
end

-- (4 Nov, owner: "remake the model 3d and make it better its from classes its hella ugly rn") The saucer is a real
-- modelled one now: ReplicatedStorage.MowALawnModels.ufo_saucer (made in Studio: a silver hull, a glass dome, a ring of
-- coloured bulbs, a glowing belly), fitted to the old saucer's size and hung in the same spot. The blocky one below is
-- only built when that model isn't in the place.
-- THE SAUCER, in voxels, v2 (6 Nov, owner on v1: "it's so bad", a washed-out pink stack; he wants "even more hype").
-- A gunmetal war-saucer: 0.4-stud cells in a lens profile (every row of a disc its own part, the tone stepping a
-- hair between neighbours so the cells read), dark underneath and lit on top (the owner's vault: three tones, shadows
-- toward blue), a hard cyan neon trim line round the widest rim, a ring of magenta windows on the upper slope, 20
-- chasing rim lights, a spinning ring of lights under the belly, a gold collar and a stepped glass dome with its
-- little alien. Neon only for lights, no shadows.
local UFO_CELL = 0.4
local UFO_SCALE = 0.62 -- (small enough to sit beside the title, not under it)
local spinRing: { { part: BasePart, a: number, r: number, y: number } } = {}
local beamTop: BasePart? = nil
local function saucer(m: Instance)
	local S = UFO_SCALE
	local function add(size: Vector3, off: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, tr: number?): Part
		local p = part(m, size, CFrame.new(UFO_AT) * off, color, material, shape)
		p.Transparency = tr or 0
		p.Name = "Ufo"
		table.insert(ufoParts, { part = p, off = off })
		return p
	end
	local layer = 0
	local function disc(r: number, y: number, h: number, color: Color3, material: Enum.Material?, tr: number?)
		layer += 1
		local n = math.floor(r / UFO_CELL)
		for i = -n, n - 1 do
			local x = (i + 0.5) * UFO_CELL
			local half = math.floor(math.sqrt(math.max(r * r - x * x, 0)) / UFO_CELL) * UFO_CELL
			if half > 0 then
				-- (rows alternate a hair lighter / darker, offset per layer: the voxel grain)
				local k = if (i + layer) % 2 == 0 then 1.06 else 0.94
				local c = if material == nil then Color3.new(math.min(color.R * k, 1), math.min(color.G * k, 1), math.min(color.B * k, 1)) else color
				add(Vector3.new(UFO_CELL - 0.025, h, half * 2) * S, CFrame.new(x * S, y * S, 0), c, material, nil, tr)
			end
		end
	end
	local NEON, GLASS = Enum.Material.Neon, Enum.Material.Glass
	local CYAN, MAGENTA = rgb(70, 240, 255), rgb(255, 60, 190)
	-- the belly: a glowing core, the dark underside stepping out
	disc(1.6, -1.25, 0.4, CYAN, NEON, 0)
	disc(2.6, -0.9, 0.4, rgb(30, 32, 50))
	disc(3.8, -0.5, 0.4, rgb(44, 48, 74))
	disc(5.0, -0.1, 0.4, rgb(62, 68, 100))
	-- the widest rim and its neon trim line
	disc(6.2, 0.3, 0.4, rgb(86, 94, 130))
	disc(6.35, 0.56, 0.12, CYAN, NEON, 0)
	-- the top, lit in steps toward a cool white
	disc(5.8, 0.75, 0.4, rgb(112, 120, 160))
	disc(4.9, 1.15, 0.4, rgb(150, 158, 196))
	disc(3.9, 1.55, 0.4, rgb(190, 198, 230))
	disc(2.9, 1.9, 0.3, rgb(255, 196, 80)) -- the gold collar
	for _, d in { { 2.6, 2.3 }, { 2.4, 2.7 }, { 2.1, 3.1 }, { 1.6, 3.5 }, { 0.9, 3.85 } } do
		disc(d[1], d[2], 0.4, rgb(140, 225, 255), GLASS, 0.5)
	end
	-- the windows on the upper slope
	for k = 0, 11 do
		local a = math.rad(k * 30 + 15)
		add(Vector3.new(0.5, 0.26, 0.12) * S, CFrame.new(math.cos(a) * 4.45 * S, 1.2 * S, math.sin(a) * 4.45 * S) * CFrame.Angles(0, -a + math.pi / 2, 0), MAGENTA, NEON)
	end
	-- the alien
	local GREEN, GREEN2 = rgb(126, 236, 104), rgb(84, 186, 80)
	add(Vector3.new(0.9, 0.8, 0.7) * S, CFrame.new(0, 2.45 * S, 0.1 * S), GREEN2)
	add(Vector3.new(1.1, 0.95, 0.95) * S, CFrame.new(0, 3.25 * S, 0), GREEN)
	for _, x in { -0.26, 0.26 } do
		add(Vector3.new(0.32, 0.4, 0.1) * S, CFrame.new(x * S, 3.3 * S, -0.5 * S), rgb(12, 10, 22))
		add(Vector3.new(0.1, 0.1, 0.06) * S, CFrame.new((x - 0.06) * S, 3.42 * S, -0.56 * S), Color3.new(1, 1, 1), NEON)
	end
	-- the rim lights, chasing (updateAbduction)
	local bulbColors = { CYAN, MAGENTA, Color3.new(1, 1, 1), MAGENTA }
	for k = 0, 19 do
		local a = math.rad(k * 18)
		local b = add(Vector3.new(0.42, 0.36, 0.42) * S, CFrame.new(math.cos(a) * 6.3 * S, 0.3 * S, math.sin(a) * 6.3 * S) * CFrame.Angles(0, -a, 0), bulbColors[k % 4 + 1], NEON)
		table.insert(ufoLights, b)
	end
	-- the spinning ring of lights under the belly (moved every frame by updateAbduction)
	for k = 0, 9 do
		local a = math.rad(k * 36)
		local b = add(Vector3.new(0.4, 0.3, 0.4) * S, CFrame.new(math.cos(a) * 3.2 * S, -0.75 * S, math.sin(a) * 3.2 * S), if k % 2 == 0 then CYAN else MAGENTA, NEON)
		table.insert(spinRing, { part = b, a = a, r = 3.2 * S, y = -0.75 * S })
	end
	-- light: the belly over the beam, a cool sheen on the hull, the beam's spot down over the avatar
	local belly = add(Vector3.one, CFrame.new(0, -1.5 * S, 0), Color3.new(1, 1, 1), nil, nil, 1)
	light(belly, CYAN, 12, 2)
	local hullLight = add(Vector3.one, CFrame.new(0, 3.5 * S, -5 * S), Color3.new(1, 1, 1), nil, nil, 1)
	light(hullLight, rgb(190, 220, 255), 9, 0.7)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 50
	spot.Range = 30
	spot.Brightness = 1.1
	spot.Color = CYAN
	spot.Shadows = false
	spot.Parent = belly
	beamLight = spot
end

-- the light beam: three beams (a wide soft cone, a drifting energy layer, a bright core) from the belly to the patch
local function lightBeam(m: Instance)
	local top = part(m, Vector3.one, CFrame.new(UFO_AT + Vector3.new(-0.25, -0.85, 0)), Color3.new(1, 1, 1))
	top.Transparency = 1
	top.Name = "BeamTop"
	beamTop = top
	local bottom = part(m, Vector3.one, CFrame.new(0, TURF_TOP + 0.1, 0.6), Color3.new(1, 1, 1))
	bottom.Transparency = 1
	bottom.Name = "BeamBottom"
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = top, bottom
	local function beam(w0: number, w1: number, tex: string?, tr: NumberSequence, emission: number, speed: number?): Beam
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera = true
		b.Segments = 12
		b.Width0, b.Width1 = w0, w1
		b.Color = ColorSequence.new(rgb(120, 245, 255), Color3.new(1, 1, 1))
		b.LightEmission = emission
		b.LightInfluence = 0
		b.Transparency = tr
		if tex then
			b.Texture = tex
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 6
			b.TextureSpeed = speed or 0.4
		else
			-- (checked in Studio: a beam with no texture has hard straight sides, a flat sheet; the glow softens them)
			b.Texture = Tex.Glow
			b.TextureMode = Enum.TextureMode.Stretch
		end
		b.Parent = top
		table.insert(beams, b)
		table.insert(beamBase, tr.Keypoints[1].Value)
		return b
	end
	-- (6 Nov, "even more hype": the soft cone read as a grey sheet; now every layer glows, a spiral twists up it)
	beam(2.4, 11, nil, seq(0, 0.6, 0.6, 0.78, 1, 0.9), 1) -- the soft cone
	beam(2.0, 9.5, Tex.EnergyNoise, seq(0, 0.7, 0.5, 0.8, 1, 0.9), 1, -0.6) -- energy drifting up it
	beam(1.7, 8, Tex.VS_Spiral or Tex.EnergyNoise, seq(0, 0.55, 0.5, 0.7, 1, 0.9), 1, -1.1) -- the spiral
	beam(0.8, 3, nil, seq(0, 0.15, 0.7, 0.45, 1, 0.8), 1) -- the hot core
	-- rings of light sliding up the beam
	local rings = part(m, Vector3.new(2, 0.1, 2), CFrame.new(0, TURF_TOP + 0.3, 0.6), Color3.new(1, 1, 1))
	rings.Transparency = 1
	rings.Name = "BeamRings"
	emitter(rings, {
		Texture = Tex.RingThin, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(BEAM), LightEmission = 0.4, Size = seq(0, 6, 1, 1.6), Transparency = seq(0, 1, 0.15, 0.55, 1, 1),
		Lifetime = NumberRange.new(2.4, 2.4), Speed = NumberRange.new(4.6, 4.6), SpreadAngle = Vector2.zero, Rate = Budget.Rate(0.7),
	})
	-- sparks streaming up the beam into the saucer
	emitter(rings, {
		Texture = Tex.Spark, Shape = Enum.ParticleEmitterShape.Disc, EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(90, 240, 255)), LightEmission = 1, Size = seq(0, 0.35, 1, 0.05),
		Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(4, 4), Rate = Budget.Rate(30),
	})
end

-- the platform (v2): a voxel chunk of lawn torn out of the valley, floating; a glowing summoning circle on top
local function voxelPlatform(m: Instance, rng: Random)
	local CELL = 1
	local R = 6.2
	local n = math.floor(R / CELL)
	for ix = -n, n - 1 do
		for iz = -n, n - 1 do
			local x, z = (ix + 0.5) * CELL, (iz + 0.5) * CELL
			local d = math.sqrt(x * x + z * z)
			if d <= R + rng:NextNumber(-0.5, 0.3) then
				local green = if (ix + iz) % 2 == 0 then rgb(96, 186, 72) else rgb(80, 164, 62)
				part(m, Vector3.new(CELL - 0.06, 0.5, CELL - 0.06), CFrame.new(x, TURF_TOP - 0.25 + rng:NextNumber(-0.04, 0.04), z), green)
				-- the earth under it, longer toward the middle, stepping down to a stone tip
				local depth = math.max(1, math.floor((R - d) * 0.9 + rng:NextNumber(0, 1.5)))
				for k = 1, depth do
					local c = if k == 1 then rgb(122, 84, 52) elseif k < depth - 1 then rgb(98, 66, 42) else rgb(92, 88, 104)
					part(m, Vector3.new(CELL, 1, CELL), CFrame.new(x, TURF_TOP - 0.5 - (k - 0.5), z), c)
				end
			end
		end
	end
	-- the summoning circle: a thin sheet just above the grass with the crop circle's rings and the rune circle
	local top = part(m, Vector3.new(R * 2.1, 0.05, R * 2.1), CFrame.new(0, TURF_TOP + 0.04, 0), Color3.new(1, 1, 1)) -- (not Glass: checked in Studio, an invisible Glass sheet still drew as a dark square)
	top.Transparency = 1
	cropCircle(top)
end

-- the vortex behind the saucer: the world 2 glitch hole (client/GlitchHole), big, high, straight behind
local hole: any = nil
local function vortex(m: Instance)
	local mod = script.Parent:FindFirstChild("GlitchHole")
	if not mod then
		return
	end
	local okReq, GlitchHole = pcall(require, mod)
	if not okReq then
		return
	end
	local ok, h = pcall(GlitchHole.new, (ORIGIN * CFrame.new(VORTEX_AT)).Position, Vector3.new(-0.3, -0.15, -1).Unit, 15, m)
	if ok then
		hole = h
	end
end

local finishBuild: (m: Model) -> Model
local function build()
	local m = Instance.new("Model")
	m.Name = "ClassRoom"
	local rng = Random.new(2026)
	for i = 1, #FACES do
		starWall(m, i, rng)
	end

	-- planets: a big ringed violet giant upper right, a small amber one with a moon out at the far left (owner, 27
	-- Oct: it used to sit right behind the STOCK / OWNED tabs)
	-- (6 Nov, owner: "it's a bit messy": the planets and the moon went; the vortex is the one big thing in the sky)

	-- asteroids drifting through, near and far
	for _ = 1, 6 do
		local far = true
		local pos = Vector3.new(rng:NextNumber(-70, 70), rng:NextNumber(-25, 35), rng:NextNumber(if far then 40 else 12, if far then 140 else 40))
		if math.abs(pos.X) < 12 and math.abs(pos.Y - 4) < 9 then
			pos += Vector3.new(if pos.X < 0 then -16 else 16, 0, 0) -- keep the avatar clear
		end
		rock(m, rng, pos, rng:NextNumber(if far then 3 else 1.2, if far then 9 else 3))
	end

	-- space dust drifting past (the warp streaks went with the abduction: the avatar hovers in the beam now)
	local dust = part(m, Vector3.new(70, 40, 1), CFrame.new(0, 5, 60), Color3.new(1, 1, 1))
	dust.Transparency = 1
	emitter(dust, {
		Texture = Tex.Glow, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front,
		Color = ColorSequence.new(rgb(190, 170, 255)), LightEmission = 0.8, Size = seq(0, 0.12, 1, 0.3), Transparency = seq(0, 1, 0.2, 0.35, 1, 1),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(12, 22), Rate = Budget.Rate(18),
	})

	-- the abduction: the lawn patch with its crop circle, the saucer and its light beam
	voxelPlatform(m, rng)
	vortex(m)
	saucer(m)
	lightBeam(m)
	return finishBuild(m)
end

-- the avatar's aura, the room's lights; the same over either background
function finishBuild(m: Model): Model

	-- the aura round the avatar (recoloured per card) and wisps streaming up off it into the beam
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
		Texture = Tex.Glow, Color = ColorSequence.new(rgb(170, 90, 255)), LightEmission = 0.5, EmissionDirection = Enum.NormalId.Top,
		Size = seq(0, 1.1, 1, 0.2), Transparency = seq(0, 0.75, 1, 1), Lifetime = NumberRange.new(1.4, 1.9), Speed = NumberRange.new(2.5, 4),
		SpreadAngle = Vector2.new(14, 14), Rate = Budget.Rate(12), Drag = 0.5,
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
	-- (6 Nov) a proper three-point set: a warm key high on the camera's left, a soft cool fill low on its right, and
	-- two strong rims behind (violet left, cyan right) that cut the avatar out of the night; a warm bounce from below
	local function spotAt(pos: Vector3, color: Color3, range: number, brightness: number, angle: number)
		local p = part(m, Vector3.one, CFrame.lookAt(pos, FLOAT), Color3.new(1, 1, 1))
		p.Transparency = 1
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = angle
		spot.Range = range
		spot.Brightness = brightness
		spot.Color = color
		spot.Shadows = false
		spot.Parent = p
	end
	spotAt(Vector3.new(-5, 9, -9), rgb(255, 236, 214), 22, 1.6, 45) -- key
	spotAt(Vector3.new(6, 3.5, -8), rgb(170, 200, 255), 18, 0.45, 60) -- fill
	spotAt(Vector3.new(-5, 7, 6), rgb(170, 100, 255), 14, 2.4, 50) -- rim, violet
	spotAt(Vector3.new(5, 6, 6), rgb(70, 215, 255), 14, 2.1, 50) -- rim, cyan
	lamp(Vector3.new(3, -1.5, -3), rgb(255, 160, 100), 8, 0.5) -- bounce

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
	if auraOff then -- (the class aura is worn by the old clone: take it off first)
		auraOff()
		auraOff = nil
	end
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
	local pitch = math.rad(-2) + math.rad(3) * wave(t, 5.3, 1.1) -- hovering upright in the beam (it used to lean in, flying)
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
	-- (a little higher than before, so the crop circle on the patch reads, and wide enough to catch the saucer)
	{ pos = Vector3.new(0, 6.4, -16), look = Vector3.new(0, 4.4, 0), fov = 60 }, -- front (the one the screen opens on)
	-- (6 Nov: the three-quarter and low shots swung the saucer behind the title or out of the frame; the composition
	-- is set for this view, so the camera only breathes a little around it)
	{ pos = Vector3.new(-1.2, 6.8, -16.4), look = Vector3.new(0.4, 4.6, 0), fov = 59 },
	{ pos = Vector3.new(1.0, 6.0, -15.6), look = Vector3.new(0.2, 4.4, 0), fov = 61 },
}
local GLIDE = 3 -- seconds a move between framings takes (Sine InOut)
local camFrom, camTo = 1, 1
local camMoveStart, camNext = 0, 0

local kickT, kickAmp = -10, 1
local function kickCamera(amp: number)
	kickT, kickAmp = os.clock(), amp
end

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
	-- (6 Nov, "more umph") the arrival and every pick punch the lens: the FOV snaps in and eases back, a short shake
	local kick = math.clamp(1 - (os.clock() - kickT) / 0.45, 0, 1)
	kick = kick * kick
	local jolt = CFrame.new((math.noise(os.clock() * 30, 1) * 0.35) * kick * kickAmp, (math.noise(2, os.clock() * 30) * 0.35) * kick * kickAmp, 0)
	cam.FieldOfView = fa + (fb - fa) * k - kick * 7 * kickAmp
	cam.CFrame = cf * drift * shake * jolt
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
	-- (owner, 27 Oct: "top notch but not too much for mobile": no shadows, no extra post effects - a darker violet fill so
	-- the key / rim / beam lights shape the avatar, a little environment light so the metal saucer and the avatar's
	-- shiny bits pick up the sky, and a soft bloom that only catches the neon: bulbs, the beam's belly, the circle)
	setLit(Lighting, {
		-- (6 Nov, owner: "the overall lighting of the classes screen is kinda bad and sloppy": a high violet fill made
		-- everything one flat blue-purple; now a darker, cooler fill so the key, the rims and the beam do the shaping)
		ClockTime = 0, Brightness = 0, Ambient = rgb(46, 42, 72), OutdoorAmbient = rgb(40, 38, 66), ExposureCompensation = 0.15,
		EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.8, FogEnd = 100000, FogStart = 99999,
	})
	if spaceScene and spaceScene.mood then
		-- (the egg screen's own night: its island and the avatar lit the way the pets are there)
		setLit(Lighting, spaceScene.mood)
	end
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") then
			setLit(c, { Density = 0, Haze = 0, Glare = 0 })
		elseif c:IsA("SunRaysEffect") then
			setLit(c, { Enabled = false })
		elseif c:IsA("ColorCorrectionEffect") and c.Name ~= "ClassRoomGrade" then
			-- (the world's own grades stacked on the room's and tinted everything a washed blue)
			setLit(c, { Enabled = false })
		elseif c:IsA("BloomEffect") then
			setLit(c, { Intensity = 0.45, Size = 28, Threshold = 0.95 }) -- (owner, 28 Oct: skin glowed white; keep bloom off skin) -- soft: 1.1 blew white clothes out into neon
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

-------------------------------------------------------------------------------------------------------------
-- the abduction, every frame: the saucer bobs and wobbles, its bulbs chase round, the beam breathes; a pick flashes
-- the beam and the crop circle (fading over 0.9 s)
-------------------------------------------------------------------------------------------------------------
local flashT = -10
local beamSeqs: { NumberSequence } = {}
-- (6 Nov, owner: "make it with more umph") THE ARRIVAL: every time the screen opens the saucer swoops in from far
-- off to the right and brakes over the island (0.85 s, Back out, with a whoosh); then the beam SLAMS down: a white
-- flash in the belly, a shockwave ring racing across the lawn, a lens punch and a thud. A pick does the same flash in
-- its rarity colour, and the bulbs blink in that colour.
local ARRIVE = 0.85
local nextBolt = 0
local arriveT = -10
local landed = true
local pickColor: Color3? = nil
local pickT = -10
local SWOOP_FROM = Vector3.new(36, 10, 50)

local function shockwave(color: Color3, big: boolean)
	local m = room
	if not m then
		return
	end
	local y = ISLAND_DROP + ISLAND_PLATE_Y + 0.12
	for i, r in { (if big then 30 else 20), (if big then 18 else 12) } do
		local ring = part(m, Vector3.new(0.12, 1, 1), CFrame.new(0, y + i * 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.Transparency = 0.15
		TweenService:Create(ring, TweenInfo.new(0.55 + i * 0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, r, r), Transparency = 1 }):Play()
		task.delay(0.9, function()
			ring:Destroy()
		end)
	end
	-- a column of light up the beam
	-- (checked in Studio: 3.6 wide at 0.35 it washed the avatar out to pure white; thin and quick, it reads as a flash)
	local col = part(m, Vector3.new(14, 1.6, 1.6), CFrame.new(0, y + 7, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	col.Transparency = 0.55
	TweenService:Create(col, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(14, 0.1, 0.1), Transparency = 1 }):Play()
	task.delay(0.6, function()
		col:Destroy()
	end)
end

local LightningMod: any = nil
local AnimeFxMod: any = nil
local function bolt(a: Vector3, b: Vector3, color: Color3, width: number?)
	if LightningMod == nil then
		local ok, res = pcall(require, ReplicatedStorage:WaitForChild("VFXLib"):WaitForChild("Lightning"))
		LightningMod = if ok then res else false
	end
	if LightningMod then
		pcall(LightningMod.Strike, ORIGIN * a, ORIGIN * b, { Color = color, Width = width or 0.4, Duration = 0.3, Flickers = 3, Branches = 2, Jag = 0.35 })
	end
end
local function anime(): any
	if AnimeFxMod == nil then
		local mod = script.Parent:FindFirstChild("AnimeFx")
		local ok, res = pcall(function()
			return require(mod :: any)
		end)
		AnimeFxMod = if ok then res else false
	end
	return AnimeFxMod
end
-- an anime impact frame of the avatar (black and white for a beat), with speed lines rushing in behind
local function impactFrame(lines: number)
	local A = anime()
	if not A then
		return
	end
	pcall(A.impact, { avatar }, "neg", { hold = 0.09 })
	if lines > 0 then
		local ok, stop = pcall(A.lines, Color3.new(1, 1, 1), 0.35)
		if ok and stop then
			task.delay(lines, stop)
		end
	end
end

local function landBeam(color: Color3, big: boolean)
	flashT = os.clock()
	shockwave(color, big)
	kickCamera(if big then 1.2 else 0.7)
	-- lightning down the beam into the circle's edge
	local belly = UFO_AT + Vector3.new(-0.25, -1.0, 0)
	for k = 1, (if big then 4 else 2) do
		local a = math.random() * math.pi * 2
		bolt(belly, Vector3.new(math.cos(a) * 5, TURF_TOP + 0.1, math.sin(a) * 5), color, if big then 0.5 else 0.35)
	end
	if big then
		impactFrame(0.45)
		if hole then
			pcall(hole.glitch, 0.35)
		end
	end
	pcall(function()
		local Sound = require(script.Parent.Sound) :: any
		Sound.play("slam", 0.05, if big then 0.55 else 0.4)
		if big then
			Sound.play("reveal", 0, 0.35)
		end
	end)
end

local function updateAbduction(t: number)
	-- the swoop in: from far off to the right, braking over the island with a little overshoot, banking as it comes
	local a = math.clamp((os.clock() - arriveT) / ARRIVE, 0, 1)
	local e = TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local swoop = SWOOP_FROM * (1 - e)
	local bank = CFrame.Angles(0, 0, math.rad(-28) * (1 - e))
	-- (6 Nov, owner: "make it move") it flies a slow figure eight round its spot, bobs, rocks, and spins on its axis;
	-- the beam's top rides with its belly
	local fly = Vector3.new(math.sin(t * 0.55) * 1.6, math.sin(t * 1.1) * 0.7 + math.sin(t * 1.9) * 0.15, math.cos(t * 0.55) * 0.9)
	local lean = CFrame.Angles(math.rad(6) * math.cos(t * 0.55), 0, math.rad(-7) * math.cos(t * 0.55)) -- (it banks into its turns)
	local tilted = ORIGIN * CFrame.new(UFO_AT + swoop + fly) * bank * UFO_TILT * lean
	local ufo = tilted * CFrame.Angles(0, t * 0.9, 0)
	for _, u in ufoParts do
		u.part.CFrame = ufo * u.off
	end
	if beamTop then
		beamTop.CFrame = tilted * CFrame.new(0, -0.85, 0)
	end
	for _, sr in spinRing do
		local ang = sr.a + t * 2.4
		sr.part.CFrame = ufo * CFrame.new(math.cos(ang) * sr.r, sr.y, math.sin(ang) * sr.r)
	end
	-- now and then the vortex throws a bolt across the sky, or onto the saucer
	if landed and os.clock() > nextBolt then
		-- (only from the vortex onto the saucer, every 3.5-6 s: bolts all over the sky made it messy)
		nextBolt = os.clock() + 3.5 + math.random() * 2.5
		local from = VORTEX_AT + Vector3.new(math.random(-6, 6), math.random(-4, 4), -6)
		bolt(from, UFO_AT + Vector3.new(math.random(-1, 1), 1.6, 1), rgb(255, 80, 210), 0.45)
	end
	if not landed and a >= 1 then
		landed = true
		landBeam(BEAM, true)
	end
	local n = #ufoLights
	local pk = math.clamp(1 - (os.clock() - pickT) / 1.2, 0, 1)
	for i, b in ufoLights do
		b.Transparency = if (t * 9 - i) % n < 4 then 0 else 0.55
		if pickColor then
			-- a pick: all bulbs blink in its colour, then back to their own
			local base = b:GetAttribute("Base")
			if base == nil then
				b:SetAttribute("Base", b.Color)
				base = b.Color
			end
			b.Color = (base :: Color3):Lerp(pickColor, pk)
			if pk > 0 then
				b.Transparency = if math.floor(os.clock() * 14) % 2 == 0 then 0 else 0.4
			end
		end
	end
	local f = math.clamp(1 - (os.clock() - flashT) / 0.9, 0, 1)
	f = f * f
	-- (no beam until the saucer has arrived)
	local off = if landed then 0 else 1
	local shift = 0.04 * math.sin(t * 2.2) - f * 0.4 + off
	for i, b in beams do
		local base = beamSeqs[i]
		if not base then
			base = b.Transparency
			beamSeqs[i] = base
		end
		local k = {}
		for _, kp in base.Keypoints do
			table.insert(k, NumberSequenceKeypoint.new(kp.Time, math.clamp(kp.Value + shift, 0, 1)))
		end
		b.Transparency = NumberSequence.new(k)
	end
	if f > 0 or flashT > 0 then
		for _, img in circleArt do
			img.ImageTransparency = (img:GetAttribute("Rest") or 0) * (1 - f * 0.85)
		end
		if beamLight then
			beamLight.Brightness = 0.8 + f * 1.6
		end
		if f <= 0 then
			flashT = 0 -- settled: stop touching them every frame
		end
	end
end

-- the picked card's class aura (client/RarityFx) on the avatar clone
local function wearClassAura()
	if auraOff then
		auraOff()
		auraOff = nil
	end
	if not (shown and avatar and classAura) then
		return
	end
	if RarityFx == nil then
		local m = script.Parent:FindFirstChild("RarityFx")
		local ok, res = pcall(function()
			return require(m :: any)
		end)
		RarityFx = if ok then res else false
	end
	if RarityFx and RarityFx.preview then
		local ok, off = pcall(RarityFx.preview, avatar, classAura)
		if ok then
			auraOff = off
		end
	end
end

-- A card was picked: its class aura goes on the avatar, the beam and the crop circle flash, a VFX Forge burst.
function ClassRoom.setClass(classId: string?)
	if classId == classAura and auraOff then
		return
	end
	local changed = classId ~= classAura
	classAura = classId
	wearClassAura()
	if changed and shown and classId then
		local color = if auraLight then auraLight.Color else BEAM
		MenuFX.burst((ORIGIN * CFrame.new(FLOAT)).Position, color, { size = 0.7 })
		if landed then
			pickColor, pickT = color, os.clock()
			landBeam(color, false)
		end
	end
end

-- Show the room and point the camera at the avatar. `color` = the picked card's rarity colour.
function ClassRoom.show(color: Color3?)
	local m = room or build()
	m.Parent = workspace
	placeAvatar()
	ClassRoom.setAura(color or rgb(170, 90, 255))
	spaceLighting()
	shown = true
	wearClassAura()
	arriveT, landed = os.clock(), false
	nextBolt = os.clock() + 1.5
	if hole then
		pcall(hole.open, 0.7)
	end
	pcall(function()
		local Sound = require(script.Parent.Sound) :: any
		Sound.play("bhPull", 0.05, 0.5)
	end)
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
			TweenService:Create(g, TweenInfo.new(0.06), { TintColor = rgb(246, 242, 255), Saturation = 0.1, Contrast = 0.16, Brightness = 0 }):Play()
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
			updateAbduction(t)
			if hole then
				pcall(hole.update, dt)
			end
			if spaceScene and spaceScene.update then
				pcall(spaceScene.update, dt, now)
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
	-- (a rare card landing: the anime beat, lightning in its colour, the vortex glitches)
	impactFrame(if big then 0.6 else 0.35)
	landBeam(color, true)
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
	if auraOff then
		auraOff()
		auraOff = nil
	end
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
