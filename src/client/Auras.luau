--!strict
-- THE CLASS AURAS, REMADE (owner, 4 Nov: "remake elke aura met classes ... gebruik obsidian vault", every class a
-- completely new idea, the free Weed Puller a small subtle one; before that, on the old Weed Puller aura: "very bad and
-- just screen bullshit"). Replaces client/RarityFx's class auras and client/ClassVfx's body glow, first-person fists,
-- screen corners and equip burst (both skip classes while Config.AURAS_V2 is on).
--
-- The rules (deep research + the LihFolk vault, "VFX Readability and Value"):
--   * Rarer = one more CHANNEL, not bigger particles: Common one small emitter, only while you walk; Uncommon a second
--     colour always there; Rare a trail; Epic beams or a flipbook; Legendary something that changes over time or
--     touches the world; Mythic a light and an equip chime; Secret its own motion (inward) and a quiet idle beat.
--   * Everything sits on the character's own parts (attachments inside it), so Roblox's camera hides it in your own
--     first person: nothing ever on your screen. No ground rings, no ScreenGui, no Highlight. Effects hug the body
--     (about 1.5 studs) below Mythic; only Mythic and Secret reach above the head.
--   * Value: a dark saturated ink layer, the body colour, a thin bright core, one accent hue; nothing washes the body
--     (rims and specks, never a sphere round it); a light sits above and behind, low and short.
--   * Budget: total particles per second by tier (3, 6, 10, 16, 24, 32, 40). Other players' auras: full within 40
--     studs, a third of the particles and no beams, trails or lights to 100, off past that; past 12 full auras the
--     rest drop a level; Potato Mode drops everyone's a level. Checked 10 times a second, not every frame.
--   * Textures: the game's own uploads (shared/FxTex, the class aura set), tinted here. Sounds: the game's licensed
--     ones (Config.SOUNDS).
--
-- The ten (Common to Secret):
--   Weed Puller       Clover Kick       little clover leaves kicked up from your heels as you walk; nothing standing still
--   Gardener          Morning Dew       dew drops falling from your shoulders, now and then a glint
--   Groundskeeper     Stripe Painter    a fresh mowing stripe trails behind your feet, clippings flicking off it
--   Lawn Baron        Gilded Pollen     slow gold pollen rising off you, a gold sheen off your swinging hand, a coin glint
--   Hedge Reaper      Bramble Veins     two thorny vines curling over your back to your shoulders, dark leaf shards
--   Mower Specialist  Chute Exhaust     green clipping puffs out of your back like a mower chute, sparks at your heels
--   Grass Titan       Living Turf       grass blades sprouting from your shoulders, a tuft springing up at every step
--   Ultimate Gardener Four Seasons      blossom, leaf, amber and frost in turn, every 8 seconds, a ribbon down your back
--   Lawn Legend       Midnight Meadow   a purple and teal aurora rising behind your shoulders, fireflies, a soft light
--   Goat Man          The Grazer        the grass round your feet drawn in to you as if grazed, two crescent horns of
--                                       light over your head, a little munch every 10 seconds
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config")) :: any
local FxTex = require(Shared:WaitForChild("FxTex")) :: any

local Auras = {}

local player = Players.LocalPlayer
local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
-- the class aura texture set (uploaded for this game, 31 Oct; see client/ClassAuras)
local T = {
	coin = "rbxassetid://128871336135848",
	vine = "rbxassetid://89987547908830",
	energy = "rbxassetid://101387044982652",
	glint = "rbxassetid://93030574875002", -- 4x4 flipbook
	wisp = "rbxassetid://126327675942159",
}

local NEAR, FAR = 40, 100
local MAX_FULL = 12

local potato = false
pcall(function()
	local Potato = require(script.Parent:WaitForChild("Potato", 5) :: ModuleScript) :: any
	potato = Potato.on == true
	Potato.changed(function(on)
		potato = on == true
	end)
end)

-------------------------------------------------------------------------------------------------------------
-- building blocks
-------------------------------------------------------------------------------------------------------------
type Em = { e: ParticleEmitter, rate: number, walk: boolean? }
export type Aura = {
	char: Model,
	root: BasePart,
	hum: Humanoid?,
	made: { Instance },
	ems: { Em },
	extras: { Instance }, -- beams, trails, lights: only at full detail
	tick: ((Aura, number, number) -> ())?, -- (aura, seconds since the last tick, detail level)
	level: number,
	moving: boolean,
	own: boolean,
	lastPos: Vector3?,
	walked: number,
	clock: number,
	state: { [string]: any },
}

local function ns(...: number): NumberSequence
	local v = { ... }
	local kps = {}
	for i = 1, #v, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(v[i], v[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function cs(...: Color3): ColorSequence
	local v = { ... }
	if #v == 1 then
		return ColorSequence.new(v[1])
	end
	local kps = {}
	for i, c in v do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#v - 1), c))
	end
	return ColorSequence.new(kps)
end

local function part(a: Aura, names: { string }): BasePart?
	for _, n in names do
		local p = a.char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- An attachment of ours in `p` at `pos` (its own frame).
local function att(a: Aura, p: BasePart, name: string, pos: Vector3): Attachment
	local at = Instance.new("Attachment")
	at.Name = "Aura_" .. name
	at.Position = pos
	at.Parent = p
	table.insert(a.made, at)
	return at
end

-- At your feet, `up` studs over the ground (0.35 if not given: lower, and what's kicked up falls straight into the
-- floor and is never seen; tested 4 Nov).
local function feet(a: Aura, name: string, x: number?, z: number?, up: number?): Attachment
	local drop = (if a.hum then a.hum.HipHeight else 2) + a.root.Size.Y / 2 - (up or 0.35)
	return att(a, a.root, name, Vector3.new(x or 0, -drop, z or 0))
end

local function torso(a: Aura): BasePart
	return part(a, { "UpperTorso", "Torso" }) or a.root
end

local function head(a: Aura): BasePart
	return part(a, { "Head" }) or a.root
end

-- The shoulder tops (left, right).
local function shoulders(a: Aura): (Attachment, Attachment)
	local t = torso(a)
	local w, h = t.Size.X / 2, t.Size.Y / 2
	return att(a, t, "ShoulderL", Vector3.new(-w, h - 0.1, 0.1)), att(a, t, "ShoulderR", Vector3.new(w, h - 0.1, 0.1))
end

local function back(a: Aura, up: number?): Attachment
	local t = torso(a)
	return att(a, t, "Back", Vector3.new(0, up or 0.2, t.Size.Z / 2 + 0.05))
end

type EmOpts = {
	tex: string,
	color: ColorSequence,
	size: NumberSequence,
	rate: number,
	life: NumberRange,
	speed: NumberRange,
	spread: Vector2?,
	accel: Vector3?,
	drag: number?,
	light: number?,
	bright: number?,
	trans: NumberSequence?,
	rot: NumberRange?,
	spin: NumberRange?,
	dir: Enum.NormalId?,
	orient: Enum.ParticleOrientation?,
	squash: NumberSequence?,
	flip: boolean?, -- a 4x4 flipbook, played once
	walk: boolean?, -- only while walking
}

local function emitter(a: Aura, parent: Instance, o: EmOpts): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Texture = o.tex
	e.Color = o.color
	e.Size = o.size
	e.Rate = o.rate
	e.Lifetime = o.life
	e.Speed = o.speed
	e.SpreadAngle = o.spread or Vector2.new(20, 20)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.LightEmission = o.light or 0
	e.Brightness = o.bright or 1
	e.Transparency = o.trans or ns(0, 1, 0.15, 0, 0.75, 0, 1, 1) -- fade in and out: no popping
	e.Rotation = o.rot or NumberRange.new(0, 360)
	e.RotSpeed = o.spin or NumberRange.new(-60, 60)
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.Orientation = o.orient or Enum.ParticleOrientation.FacingCamera
	if o.squash then
		e.Squash = o.squash
	end
	if o.flip then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.LockedToPart = false
	e.Parent = parent
	table.insert(a.made, e)
	table.insert(a.ems, { e = e, rate = o.rate, walk = o.walk })
	return e
end

local function extra(a: Aura, inst: Instance)
	table.insert(a.made, inst)
	table.insert(a.extras, inst)
end

local function beam(a: Aura, a0: Attachment, a1: Attachment, o: { tex: string, color: ColorSequence, w0: number, w1: number, c0: number?, c1: number?, trans: NumberSequence?, light: number?, speed: number?, len: number? }): Beam
	local b = Instance.new("Beam")
	b.Name = "Aura"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = o.tex
	b.Color = o.color
	b.Width0 = o.w0
	b.Width1 = o.w1
	b.CurveSize0 = o.c0 or 0
	b.CurveSize1 = o.c1 or 0
	b.Transparency = o.trans or ns(0, 0.4, 1, 0.4)
	b.LightEmission = o.light or 0
	b.TextureSpeed = o.speed or 0
	b.TextureLength = o.len or 1
	b.TextureMode = Enum.TextureMode.Stretch
	b.FaceCamera = true
	b.Segments = 12
	b.Parent = a0.Parent
	extra(a, b)
	return b
end

local function trail(a: Aura, a0: Attachment, a1: Attachment, o: { tex: string, color: ColorSequence, life: number, trans: NumberSequence, light: number?, face: boolean? }): Trail
	local t = Instance.new("Trail")
	t.Name = "Aura"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Texture = o.tex
	t.Color = o.color
	t.Lifetime = o.life
	t.Transparency = o.trans
	t.LightEmission = o.light or 0
	t.MinLength = 0.15 -- draws only while moving
	t.FaceCamera = o.face == true
	t.Parent = a0.Parent
	extra(a, t)
	return t
end

-- A light above and behind the head, low and short (the vault: effect lights colour whatever is nearest).
local function light(a: Aura, color: Color3, range: number, bright: number)
	local at = att(a, head(a), "Light", Vector3.new(0, 2.6, 1.6))
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = bright
	l.Shadows = false
	l.Parent = at
	extra(a, l)
end

-------------------------------------------------------------------------------------------------------------
-- the ten
-------------------------------------------------------------------------------------------------------------
local BUILD: { [string]: (Aura) -> () } = {}

-- Common: one emitter, ~3/s, only while walking, at the heels. Nothing standing still, nothing on the ground.
BUILD.WeedPuller = function(a)
	emitter(a, feet(a, "Heels", 0, 0.4), {
		tex = FxTex.leaf,
		color = cs(C(76, 158, 62), C(150, 214, 92)),
		size = ns(0, 0.34, 1, 0.05),
		rate = 3,
		life = NumberRange.new(0.6, 0.85),
		speed = NumberRange.new(4.5, 6.5),
		spread = Vector2.new(35, 35),
		accel = Vector3.new(0, -16, 0),
		dir = Enum.NormalId.Top,
		spin = NumberRange.new(-180, 180),
		walk = true,
	})
end

-- Uncommon: dew drops off both shoulders (cool white-cyan on a deep teal ink), a rare glint.
BUILD.Gardener = function(a)
	local l, r = shoulders(a)
	for _, at in { l, r } do
		emitter(a, at, {
			tex = FxTex.glow,
			color = cs(C(235, 252, 255), C(120, 214, 240), C(30, 110, 140)),
			size = ns(0, 0.42, 0.7, 0.34, 1, 0.12),
			rate = 5,
			life = NumberRange.new(0.7, 0.95),
			speed = NumberRange.new(0.3, 0.8),
			spread = Vector2.new(50, 50),
			accel = Vector3.new(0, -9, 0),
			orient = Enum.ParticleOrientation.VelocityParallel,
			squash = ns(0, 0.5, 1, 0.9), -- drops, stretching as they fall
			light = 0.35,
			spin = NumberRange.new(0, 0),
		})
	end
	emitter(a, att(a, torso(a), "Glint", Vector3.new(0, 0.4, 0)), {
		tex = SPARKLE,
		color = cs(C(200, 245, 255)),
		size = ns(0, 0, 0.3, 0.8, 1, 0),
		rate = 2,
		life = NumberRange.new(0.35, 0.5),
		speed = NumberRange.new(0, 0),
		spread = Vector2.new(180, 180),
		light = 0.2,
		spin = NumberRange.new(0, 0),
	})
end

-- Rare: a fresh mowing stripe behind your feet (a flat trail, light over a darker rim) and clippings flicking off it.
BUILD.Groundskeeper = function(a)
	local l = feet(a, "StripeL", -0.75, 0.2, 0.12)
	local r = feet(a, "StripeR", 0.75, 0.2, 0.12)
	trail(a, l, r, {
		tex = FxTex.smear,
		color = cs(C(170, 236, 120), C(96, 182, 70), C(46, 112, 44)),
		life = 0.85,
		trans = ns(0, 0.2, 0.6, 0.5, 1, 1),
	})
	emitter(a, feet(a, "Clip", 0, 0.6), {
		tex = FxTex.blade,
		color = cs(C(150, 222, 96), C(64, 140, 52)),
		size = ns(0, 0.45, 1, 0.15),
		rate = 6,
		life = NumberRange.new(0.4, 0.6),
		speed = NumberRange.new(2.5, 4),
		spread = Vector2.new(40, 40),
		accel = Vector3.new(0, -18, 0),
		spin = NumberRange.new(-240, 240),
		walk = true,
	})
	emitter(a, feet(a, "Drift", 0, 0, 1.2), {
		tex = FxTex.blade,
		color = cs(C(190, 245, 140), C(110, 190, 80)),
		size = ns(0, 0, 0.2, 0.42, 1, 0),
		rate = 2.5,
		life = NumberRange.new(1, 1.4),
		speed = NumberRange.new(0.4, 0.8),
		spread = Vector2.new(180, 30),
		accel = Vector3.new(0, 0.3, 0),
		drag = 0.6,
		spin = NumberRange.new(-90, 90),
	})
	emitter(a, feet(a, "Chalk", 0, 0.9), {
		tex = FxTex.glow,
		color = cs(C(240, 255, 235)),
		size = ns(0, 0.12, 1, 0),
		rate = 2,
		life = NumberRange.new(0.3, 0.45),
		speed = NumberRange.new(0.5, 1),
		light = 0.1,
		walk = true,
	})
end

-- Rare: slow gold pollen rising off you, a gold sheen off your swinging hand, a coin glint now and then.
BUILD.LawnBaron = function(a)
	emitter(a, att(a, torso(a), "Pollen", Vector3.new(0, -0.2, 0)), {
		tex = FxTex.glow,
		color = cs(C(255, 244, 190), C(242, 193, 78), C(150, 96, 20)),
		size = ns(0, 0, 0.2, 0.48, 1, 0.16),
		rate = 8,
		life = NumberRange.new(1.4, 2),
		speed = NumberRange.new(0.5, 1),
		spread = Vector2.new(70, 70),
		accel = Vector3.new(0, 0.6, 0),
		drag = 0.6,
		light = 0.45,
		spin = NumberRange.new(0, 0),
	})
	local hand = part(a, { "RightHand", "Right Arm" })
	if hand then
		local h0 = att(a, hand, "Sheen0", Vector3.new(0, 0.35, 0))
		local h1 = att(a, hand, "Sheen1", Vector3.new(0, -0.35, 0))
		trail(a, h0, h1, {
			tex = FxTex.trail,
			color = cs(C(255, 240, 170), C(242, 193, 78)),
			life = 0.25,
			trans = ns(0, 0.3, 1, 1),
			light = 0.3,
			face = true,
		})
	end
	emitter(a, att(a, torso(a), "Coin", Vector3.new(0, 0.2, 0)), {
		tex = T.coin,
		color = cs(WHITE),
		size = ns(0, 0, 0.2, 0.75, 1, 0.45),
		rate = 1.6,
		life = NumberRange.new(0.8, 1.1),
		speed = NumberRange.new(1, 1.6),
		spread = Vector2.new(50, 50),
		accel = Vector3.new(0, -2, 0),
		spin = NumberRange.new(-90, 90),
	})
end

-- Epic: two thorny vines curling over your back to your shoulders (beams that breathe), dark leaf shards.
BUILD.HedgeReaper = function(a)
	local b = back(a, 0.1)
	local t = torso(a)
	local root = att(a, t, "VineRoot", Vector3.new(0, -0.7, t.Size.Z / 2 + 0.1))
	local vines = {}
	for i, sx in { -1, 1 } do
		-- (up over the shoulder and a little forward, so it shows from behind and from the front)
		local tip = att(a, t, "VineTip" .. i, Vector3.new(sx * (t.Size.X / 2 + 0.25), t.Size.Y / 2 + 0.7, -0.2))
		table.insert(vines, beam(a, root, tip, {
			tex = T.vine,
			color = cs(C(110, 190, 110), C(60, 120, 70)),
			w0 = 0.9,
			w1 = 0.55,
			c0 = sx * 1.2,
			c1 = 0.8,
			trans = ns(0, 0, 1, 0.15),
		}))
	end
	a.state.vines = vines
	emitter(a, b, {
		tex = FxTex.leaf,
		color = cs(C(46, 94, 58), C(26, 52, 34)),
		size = ns(0, 0.45, 1, 0.16),
		rate = 6,
		life = NumberRange.new(0.8, 1.2),
		speed = NumberRange.new(1, 2),
		spread = Vector2.new(60, 60),
		accel = Vector3.new(0, -6, 0),
		spin = NumberRange.new(90, 180),
		dir = Enum.NormalId.Back,
		light = 0,
	})
	emitter(a, b, {
		tex = SPARKLE,
		color = cs(C(184, 150, 255), C(107, 63, 160)),
		size = ns(0, 0, 0.3, 0.3, 1, 0),
		rate = 3,
		life = NumberRange.new(0.4, 0.6),
		speed = NumberRange.new(0.3, 0.8),
		spread = Vector2.new(120, 120),
		light = 0.3,
		spin = NumberRange.new(0, 0),
	})
	emitter(a, b, {
		tex = T.wisp,
		color = cs(C(80, 40, 120), C(40, 16, 64)),
		size = ns(0, 0.6, 1, 1.6),
		rate = 4,
		life = NumberRange.new(0.9, 1.3),
		speed = NumberRange.new(0.6, 1.2),
		spread = Vector2.new(25, 25),
		accel = Vector3.new(0, 1.2, 0),
		trans = ns(0, 1, 0.25, 0.35, 1, 1),
		light = 0.2,
		spin = NumberRange.new(-30, 30),
	})
	a.tick = function(au, _, _)
		local k = math.sin(au.clock * math.pi) -- one breath every 2 s
		for i, v in au.state.vines do
			v.CurveSize0 = (if i == 1 then -1 else 1) * (1 + 0.4 * k)
		end
	end
end

-- Epic: green clipping puffs out of your back like a mower's chute (a flipbook), sparks at your heels when you run.
BUILD.MowerSpecialist = function(a)
	local b = back(a, -0.1)
	emitter(a, b, {
		tex = FxTex.puff,
		color = cs(C(160, 226, 110), C(86, 160, 60)),
		size = ns(0, 0.9, 1, 2),
		rate = 5,
		life = NumberRange.new(0.5, 0.7),
		speed = NumberRange.new(2.5, 3.5),
		spread = Vector2.new(15, 15),
		dir = Enum.NormalId.Back,
		drag = 3,
		accel = Vector3.new(0, 1.5, 0),
		flip = true,
		light = 0.3,
		trans = ns(0, 0.1, 1, 1),
	})
	emitter(a, b, {
		tex = FxTex.blade,
		color = cs(C(150, 222, 96), C(56, 120, 44)),
		size = ns(0, 0.42, 1, 0.16),
		rate = 6,
		life = NumberRange.new(0.5, 0.8),
		speed = NumberRange.new(3, 5),
		spread = Vector2.new(25, 25),
		dir = Enum.NormalId.Back,
		accel = Vector3.new(0, -14, 0),
		spin = NumberRange.new(-240, 240),
	})
	emitter(a, feet(a, "Sparks", 0, 0.5), {
		tex = FxTex.spark,
		color = cs(C(255, 236, 190), C(216, 67, 47)),
		size = ns(0, 0.2, 1, 0),
		rate = 10,
		life = NumberRange.new(0.15, 0.3),
		speed = NumberRange.new(6, 10),
		spread = Vector2.new(30, 30),
		dir = Enum.NormalId.Back,
		accel = Vector3.new(0, -30, 0),
		orient = Enum.ParticleOrientation.VelocityParallel,
		squash = ns(0, 1.5, 1, 1.5),
		light = 0.5,
		spin = NumberRange.new(0, 0),
		walk = true,
	})
end

-- Legendary: grass blades sprouting from your shoulders, and a tuft springing up at each step that grows and withers.
BUILD.GrassTitan = function(a)
	local l, r = shoulders(a)
	for _, s in { l, r } do
		emitter(a, s, {
			tex = FxTex.blade,
			color = cs(C(150, 220, 90), C(76, 140, 43), C(36, 76, 26)),
			size = ns(0, 0, 0.25, 1.1, 1, 0.8),
			rate = 6,
			life = NumberRange.new(1, 1.4),
			speed = NumberRange.new(0.4, 0.8),
			spread = Vector2.new(25, 25),
			orient = Enum.ParticleOrientation.FacingCameraWorldUp,
			squash = ns(0, 0.5, 1, 0.4),
			rot = NumberRange.new(-35, 35),
			spin = NumberRange.new(0, 0),
			light = 0.2,
		})
	end
	local stepAt = feet(a, "Step", 0, 0, 0.55) -- (half a blade up: particles are drawn round their centre)
	local tuft = emitter(a, stepAt, {
		tex = FxTex.blade,
		color = cs(C(110, 180, 64), C(76, 140, 43), C(107, 74, 43)),
		size = ns(0, 0, 0.35, 1, 1, 0),
		rate = 0,
		life = NumberRange.new(1.2, 1.5),
		speed = NumberRange.new(0.1, 0.3),
		spread = Vector2.new(15, 15),
		orient = Enum.ParticleOrientation.FacingCameraWorldUp,
		squash = ns(0, 0.6, 1, 0.5),
		rot = NumberRange.new(-30, 30),
		spin = NumberRange.new(0, 0),
	})
	beam(a, l, r, {
		tex = FxTex.smear,
		color = cs(C(124, 196, 72)),
		w0 = 0.5,
		w1 = 0.5,
		c0 = 0.8,
		c1 = -0.8,
		trans = ns(0, 0.7, 0.5, 0.55, 1, 0.7),
		light = 0.4,
	})
	a.tick = function(au, _, level)
		if level > 0 and au.walked >= 2.6 then
			au.walked = 0
			tuft:Emit(if level == 2 then 5 else 2)
		end
	end
end

-- Legendary: four seasons in turn, 8 seconds each: spring blossom, summer leaves, autumn amber, winter frost.
local SEASONS = {
	{ tex = FxTex.petal, c = { C(255, 214, 230), C(247, 168, 196), C(160, 60, 100) } },
	{ tex = FxTex.leaf, c = { C(170, 236, 110), C(76, 160, 60), C(30, 80, 34) } },
	{ tex = FxTex.leaf, c = { C(255, 200, 110), C(232, 137, 43), C(120, 50, 20) } },
	{ tex = FxTex.star, c = { C(255, 255, 255), C(221, 243, 255), C(80, 130, 190) } },
}
BUILD.UltimateGardener = function(a)
	local t = att(a, torso(a), "Season", Vector3.new(0, 1, 0))
	local fall = emitter(a, t, {
		tex = SEASONS[1].tex,
		color = cs(table.unpack(SEASONS[1].c)),
		size = ns(0, 0, 0.15, 0.45, 1, 0.3),
		rate = 10,
		life = NumberRange.new(1.4, 1.8),
		speed = NumberRange.new(1, 1.8),
		spread = Vector2.new(80, 80),
		accel = Vector3.new(0, -2.5, 0),
		drag = 0.8,
		spin = NumberRange.new(-120, 120),
		light = 0.3,
	})
	local burst = emitter(a, t, {
		tex = SEASONS[1].tex,
		color = cs(table.unpack(SEASONS[1].c)),
		size = ns(0, 0.35, 1, 0),
		rate = 0,
		life = NumberRange.new(0.6, 0.9),
		speed = NumberRange.new(4, 6),
		spread = Vector2.new(180, 180),
		drag = 4,
		spin = NumberRange.new(-200, 200),
		light = 0.4,
	})
	local glint = emitter(a, t, {
		tex = SPARKLE,
		color = cs(SEASONS[1].c[1]),
		size = ns(0, 0, 0.3, 0.3, 1, 0),
		rate = 3,
		life = NumberRange.new(0.4, 0.6),
		speed = NumberRange.new(0.2, 0.6),
		spread = Vector2.new(180, 180),
		light = 0.5,
		spin = NumberRange.new(0, 0),
	})
	local b0 = back(a, 0.6)
	local b1 = att(a, a.root, "Ribbon", Vector3.new(0, -2.2, 1.6))
	local ribbon = beam(a, b0, b1, {
		tex = FxTex.trail,
		color = cs(SEASONS[1].c[2], SEASONS[1].c[1]),
		w0 = 1.3,
		w1 = 0.3,
		c0 = 1.2,
		trans = ns(0, 0.3, 1, 1),
		light = 0.5,
		speed = 0.4,
	})
	a.state.season = 1
	a.tick = function(au, _, level)
		local s = math.floor(au.clock / 8) % 4 + 1
		if s ~= au.state.season then
			au.state.season = s
			local sea = SEASONS[s]
			for _, e in { fall, burst } do
				e.Texture = sea.tex
				e.Color = cs(table.unpack(sea.c))
			end
			glint.Color = cs(sea.c[1])
			ribbon.Color = cs(sea.c[2], sea.c[1])
			if level > 0 then
				burst:Emit(if level == 2 then 8 else 3)
			end
		end
	end
end

-- Mythic: a calm aurora rising behind your shoulders (two slow scrolling beams), fireflies, a soft light; an equip chime.
BUILD.LawnLegend = function(a)
	local t = torso(a)
	local w = t.Size.X / 2
	-- (the curtain rises from just over your shoulders, a stud behind you, so from behind it stands over your head
	-- instead of washing over you; the vault: rims, not washes)
	for i, sx in { -1, 1 } do
		-- (leaning out into a V over your head, wavy, so from any side it reads as a crown of light, not two posts)
		local function pair(name: string, back: number): (Attachment, Attachment)
			return att(a, t, name .. i, Vector3.new(sx * w * 0.8, t.Size.Y / 2 + 0.5, t.Size.Z / 2 + back)),
				att(a, t, name .. "Top" .. i, Vector3.new(sx * w * 2.5, t.Size.Y / 2 + 5.6, t.Size.Z / 2 + back + 1.2))
		end
		-- the night behind it: a deep violet band (the dark value layer, saturated, never grey)
		local b0, b1 = pair("Night", 1.3)
		beam(a, b0, b1, {
			tex = FxTex.smear,
			color = cs(C(56, 20, 112), C(80, 26, 150)),
			w0 = 1.1,
			w1 = 2.6,
			c0 = sx * 1.4,
			c1 = sx * -1.2,
			trans = ns(0, 1, 0.25, 0.4, 0.7, 0.5, 1, 1),
			light = 0,
		})
		-- the lights over it, scrolling up
		local a0, a1 = pair("Aurora", 0.9)
		local glow = beam(a, a0, a1, {
			tex = T.energy,
			color = cs(C(170, 90, 255), C(80, 180, 255), C(60, 255, 210)),
			w0 = 0.9,
			w1 = 2.4,
			c0 = sx * 1.4,
			c1 = sx * -1.2,
			trans = ns(0, 0.9, 0.2, 0, 0.75, 0.1, 1, 1),
			light = 1,
			speed = 0.6,
		})
		pcall(function()
			(glow :: any).Brightness = 2.2
		end)
		-- and its bright edge: a thin white-teal core down the middle
		local c0, c1 = pair("AuroraCore", 0.8)
		beam(a, c0, c1, {
			tex = FxTex.trail,
			color = cs(C(230, 255, 250), C(150, 255, 230)),
			w0 = 0.15,
			w1 = 0.7,
			c0 = sx * 1.4,
			c1 = sx * -1.2,
			trans = ns(0, 1, 0.25, 0.2, 0.7, 0.35, 1, 1),
			light = 1,
		})
	end
	emitter(a, att(a, t, "Fireflies", Vector3.new(0, 0.6, 0.6)), {
		tex = FxTex.glow,
		color = cs(C(220, 255, 210), C(63, 224, 197)),
		size = ns(0, 0, 0.2, 0.18, 0.8, 0.18, 1, 0),
		rate = 8,
		life = NumberRange.new(1.6, 2.4),
		speed = NumberRange.new(0.4, 1),
		spread = Vector2.new(180, 180),
		drag = 0.5,
		accel = Vector3.new(0, 0.4, 0),
		light = 1,
		spin = NumberRange.new(0, 0),
	})
	emitter(a, att(a, t, "Ink", Vector3.new(0, 0.2, 0.5)), {
		tex = FxTex.glow,
		color = cs(C(60, 24, 96), C(40, 16, 70)),
		size = ns(0, 0, 0.3, 0.45, 1, 0.3),
		rate = 3,
		life = NumberRange.new(1, 1.4),
		speed = NumberRange.new(0.3, 0.6),
		spread = Vector2.new(60, 60),
		dir = Enum.NormalId.Back,
		trans = ns(0, 1, 0.3, 0.55, 1, 1),
		spin = NumberRange.new(0, 0),
	})
	light(a, C(170, 230, 220), 6, 0.5)
	if a.own then
		pcall(function()
			local Sound = require(script.Parent:WaitForChild("Sound", 2) :: ModuleScript) :: any
			Sound.play("rareChime", 0.05, 0.35)
		end)
	end
end

-- Secret: the grass round your feet drawn in to you as if grazed (the only aura moving inward), two crescent horns of
-- light over your head, a little munch every 10 seconds.
BUILD.GoatMan = function(a)
	-- a flat ring-shaped emitter at your feet: grass spawning out on its edge and flowing in (no ring drawn)
	local disc = Instance.new("Part")
	disc.Name = "Aura_Graze"
	disc.Size = Vector3.new(7, 0.4, 7)
	disc.Transparency = 1
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Massless = true
	disc.CastShadow = false
	local drop = (if a.hum then a.hum.HipHeight else 2) + a.root.Size.Y / 2 - 0.3
	disc.CFrame = a.root.CFrame * CFrame.new(0, -drop, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = disc
	weld.Part1 = a.root
	weld.Parent = disc
	disc.Parent = a.char
	table.insert(a.made, disc)
	local graze = emitter(a, disc, {
		tex = FxTex.blade,
		color = cs(C(170, 236, 110), C(90, 170, 60), C(40, 80, 30)),
		size = ns(0, 0.6, 1, 0.15),
		rate = 14,
		life = NumberRange.new(0.85, 1),
		speed = NumberRange.new(3.3, 3.6),
		spread = Vector2.new(0, 0),
		orient = Enum.ParticleOrientation.FacingCameraWorldUp,
		spin = NumberRange.new(0, 0),
		light = 0.3,
	})
	graze.Shape = Enum.ParticleEmitterShape.Sphere
	graze.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	graze.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	-- the horns: two big crescents over the head, each three layers (the vault: a dark ink edge, the body, a thin
	-- white-hot core), gem-cyan glints at the tips
	local h = head(a)
	for i, sx in { -1, 1 } do
		local h0 = att(a, h, "Horn" .. i, Vector3.new(sx * 0.5, 0.75, 0))
		local h1 = att(a, h, "HornTip" .. i, Vector3.new(sx * 2.1, 2.4, 0.7))
		for _, layer in {
			{ C(70, 46, 18), 1.0, 0.25, 0 }, -- ink
			{ C(255, 226, 140), 0.75, 0.16, 0.5 }, -- bone gold
			{ C(255, 255, 255), 0.28, 0.06, 1 }, -- core
		} do
			beam(a, h0, h1, {
				tex = FxTex.smear,
				color = cs(layer[1]),
				w0 = layer[2],
				w1 = layer[3],
				c0 = 1.6,
				c1 = -0.9,
				trans = ns(0, 0, 1, 0.05),
				light = layer[4],
			})
		end
		emitter(a, h1, {
			tex = SPARKLE,
			color = cs(C(52, 224, 255)),
			size = ns(0, 0, 0.3, 0.7, 1, 0),
			rate = 2.5,
			life = NumberRange.new(0.4, 0.6),
			speed = NumberRange.new(0, 0.3),
			spread = Vector2.new(180, 180),
			light = 1,
			spin = NumberRange.new(0, 0),
		})
	end
	-- gold motes rising off you
	emitter(a, att(a, torso(a), "Gold", Vector3.new(0, -0.6, 0.3)), {
		tex = FxTex.glow,
		color = cs(C(255, 245, 200), C(255, 205, 70), C(160, 100, 20)),
		size = ns(0, 0, 0.2, 0.35, 1, 0),
		rate = 6,
		life = NumberRange.new(1.2, 1.7),
		speed = NumberRange.new(1, 2),
		spread = Vector2.new(50, 50),
		accel = Vector3.new(0, 1, 0),
		drag = 0.5,
		light = 0.8,
		spin = NumberRange.new(0, 0),
	})
	emitter(a, att(a, torso(a), "Motes", Vector3.new(0, 0.3, 0.4)), {
		tex = FxTex.glow,
		color = cs(C(220, 255, 200), C(52, 224, 255)),
		size = ns(0, 0, 0.2, 0.16, 1, 0),
		rate = 5,
		life = NumberRange.new(1.2, 1.8),
		speed = NumberRange.new(0.4, 0.9),
		spread = Vector2.new(180, 180),
		accel = Vector3.new(0, 0.5, 0),
		light = 1,
		spin = NumberRange.new(0, 0),
	})
	light(a, C(200, 255, 230), 8, 0.6)
	-- the munch: every 10 s a pulse of grass drawn in, and a quiet bite (heard only close by)
	local munch = Instance.new("Sound")
	munch.Name = "Aura_Munch"
	pcall(function()
		munch.SoundId = (Config.SOUNDS.bhPop or {}).id or ""
	end)
	munch.Volume = 0.25
	munch.PlaybackSpeed = 1.35
	munch.RollOffMaxDistance = 30
	munch.Parent = a.root
	table.insert(a.made, munch)
	a.state.nextMunch = 10
	a.tick = function(au, _, level)
		if au.clock >= au.state.nextMunch then
			au.state.nextMunch = au.clock + 10
			if level == 2 then
				graze:Emit(10)
				if munch.SoundId ~= "" then
					munch:Play()
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- wearing them
-------------------------------------------------------------------------------------------------------------
local worn: { [any]: Aura } = {}

local function drop(key: any)
	local a = worn[key]
	if not a then
		return
	end
	worn[key] = nil
	for _, inst in a.made do
		inst:Destroy()
	end
end

local function attach(key: any, char: Model, classId: any, own: boolean)
	drop(key)
	local build = if type(classId) == "string" then BUILD[classId] else nil
	if not build then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local a: Aura = {
		char = char,
		root = root,
		hum = char:FindFirstChildOfClass("Humanoid"),
		made = {},
		ems = {},
		extras = {},
		tick = nil,
		level = 2,
		moving = false,
		own = own,
		lastPos = nil,
		walked = 0,
		clock = 0,
		state = {},
	}
	local ok, err = pcall(build, a)
	if not ok then
		warn("[Auras] " .. tostring(classId) .. ": " .. tostring(err))
		for _, inst in a.made do
			inst:Destroy()
		end
		return
	end
	worn[key] = a
end

local function wear(p: Player)
	local char = p.Character
	if not char then
		drop(p)
		return
	end
	attach(p, char, p:GetAttribute("Class"), p == player)
end

-- Class `classId`'s aura on any rig (the classes cabin's mannequin, a test dummy): returns a function that takes it off.
function Auras.preview(char: Model, classId: string): () -> ()
	attach(char, char, classId, false)
	return function()
		drop(char)
	end
end

function Auras.on(): boolean
	return Config.AURAS_V2 == true
end

-------------------------------------------------------------------------------------------------------------
-- detail and walking, 10 times a second
-------------------------------------------------------------------------------------------------------------
local function setLevel(a: Aura, level: number)
	for _, m in a.ems do
		local on = level > 0 and (not m.walk or a.moving)
		m.e.Enabled = on
		m.e.Rate = if level == 2 then m.rate else m.rate * 0.3
	end
	for _, x in a.extras do
		local on = level == 2
		if x:IsA("Beam") or x:IsA("Trail") or x:IsA("Light") then
			(x :: any).Enabled = on
		end
	end
	a.level = level
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	local step = acc
	acc = 0
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	-- nearest first, so the 12 full ones are the closest
	local list = {}
	for key, a in worn do
		if not a.root.Parent then
			drop(key)
			continue
		end
		table.insert(list, { a = a, d = (a.root.Position - camPos).Magnitude })
	end
	table.sort(list, function(x, y)
		return x.d < y.d
	end)
	local full = 0
	for _, it in list do
		local a: Aura = it.a
		local level = if it.d < NEAR then 2 elseif it.d < FAR then 1 else 0
		if a.own then
			level = 2
		end
		if level == 2 and not a.own then
			full += 1
			if full > MAX_FULL then
				level = 1
			end
		end
		if potato and level == 2 then
			level = 1
		end
		local pos = a.root.Position
		if a.lastPos then
			local flat = Vector3.new(pos.X - a.lastPos.X, 0, pos.Z - a.lastPos.Z).Magnitude
			if flat < 10 then -- (not a teleport)
				a.walked += flat
			end
		end
		a.lastPos = pos
		-- walking: the body's own speed (works for other players too, whose MoveDirection this client doesn't get)
		local v = a.root.AssemblyLinearVelocity
		local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 2
		if level ~= a.level or moving ~= a.moving or not a.state.set then
			a.moving = moving
			a.state.set = true
			setLevel(a, level)
		end
		a.clock += step
		if a.tick then
			local ok, err = pcall(a.tick, a, step, level)
			if not ok then
				warn("[Auras] tick: " .. tostring(err))
				a.tick = nil
			end
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- every player's class
-------------------------------------------------------------------------------------------------------------
if Config.AURAS_V2 then
	local function watchPlayer(p: Player)
		p:GetAttributeChangedSignal("Class"):Connect(function()
			wear(p)
		end)
		p.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 10)
			char:WaitForChild("Humanoid", 10)
			task.wait(0.5) -- (the R15 parts and their sizes settle)
			wear(p)
		end)
		if p.Character then
			task.spawn(wear, p)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(drop)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
end

return Auras
