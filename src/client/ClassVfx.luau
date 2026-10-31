-- ClassVfx (31 Oct, owner: "rework the classes when u equip them like aura and fx and vfx u can use these and use
-- forge gui", then "as of now we only see fx and stuff in 3rd person but make it cool in first person pls").
-- Built on the other session's class auras (client/ClassAuras, through client/RarityFx: each class's props, ground
-- sigil and particle shell stay as they are), with the owner's five VFX packs (shared/AuraPacks) recoloured per
-- class (Config.CLASS_VFX):
--   * BODY: a LoveAura-pack aura on every player's character (emitters on the HumanoidRootPart, so nothing is moved
--     by a script each frame): the rarer the class, the more layers (Common: a soft glow and rising motes; Mythic and
--     Secret: the full set with flame flipbooks, lightning flicks and crescents). Other players' auras switch off
--     past FAR studs; phones and Potato Mode get the first layers only.
--   * FIRST PERSON (your own): your body aura would sit in your face, so it switches off while your camera is in your
--     head (like ClassAuras' body pieces) and your first-person hands (client/ViewModel's "Arms") carry it instead:
--     flames licking up off both fists and sparks rising, in the class's colours, more the rarer it is; the screen's
--     corners carry the class's ForgeGUI corner art (Config.CLASS_VFX[id].corner) and its colour, faintly.
--   * EQUIP: when anyone's "Class" changes near you, a burst at their feet: the EvilFloor pack's ground circle (rings,
--     ripple, crescents) and the Explosion pack's burst (crescents, a ground flash, shards, sparks), and for
--     Legendary and up the Big Beam pack's pillar of light. Your own equip also flashes the screen in its colours,
--     grows the corner art in, flares your hands, kicks the camera's field of view and plays the reveal sound.
--   * GIMMICKS: your own class's gimmick going off (server/ClassPerks "classFx": Root Rip, Reap Wave, Titan Stomp...)
--     flares your hands and the corners for a moment.
-- Client only, cosmetic. ClassVfx.preview(id) plays the equip burst on you (Studio checks).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Packs = require(Shared:WaitForChild("AuraPacks")) :: any
local Potato = require(script.Parent.Potato)
local PhonePerf = require(script.Parent.PhonePerf)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)

local ClassVfx = {}
local player = Players.LocalPlayer

local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local FAR = 110 -- other players' body auras switch off past this (studs from the camera)
local BURST_FAR = 160 -- equip bursts further than this aren't played

type Pal = { main: Color3, second: Color3, glow: Color3, dark: Color3, rainbow: boolean?, corner: string? }

local function rankOf(id: string?): number
	local c = id and Config.class(id)
	return if c then RANK[c.rarity] or 1 else 1
end
local function palOf(id: string?): Pal
	return (Config.CLASS_VFX :: any)[id or ""] or (Config.CLASS_VFX :: any).WeedPuller
end
local function lowFx(): boolean
	return Potato.on or PhonePerf.on
end

-------------------------------------------------------------------------------------------------------------
-- the packs' data -> live emitters and beams
-------------------------------------------------------------------------------------------------------------
-- a NumberSequence from {{time, value, envelope}}, values times k (clamped to 0..1 for transparency)
local function seq(keys: { { number } }, k: number, unit: boolean?): NumberSequence
	local list = {}
	local last = -1
	for i, kp in keys do
		local t = if i == 1 then 0 elseif i == #keys then 1 else math.clamp(kp[1], 0, 1)
		if t > last then
			local v = kp[2] * k
			local e = math.max(0, (kp[3] or 0) * k)
			if unit then
				v = math.clamp(v, 0, 1)
				e = math.min(e, v, 1 - v)
			end
			table.insert(list, NumberSequenceKeypoint.new(t, v, e))
			last = t
		end
	end
	if #list == 1 then
		table.insert(list, NumberSequenceKeypoint.new(1, list[1].Value, list[1].Envelope))
	elseif list[#list].Time < 1 then
		list[#list] = NumberSequenceKeypoint.new(1, list[#list].Value, list[#list].Envelope)
	end
	return NumberSequence.new(list)
end

local function range(r: { number }, k: number): NumberRange
	local a, b = r[1] * k, r[2] * k
	return NumberRange.new(math.min(a, b), math.max(a, b))
end

-- The packs' colours (pink, red, blue) turned into the class's: dark keys -> its dark, near-white keys -> its glow,
-- coloured keys -> its main and second colours in turn (so a flame runs from one to the other over its life).
-- `hue` (0..1, the Secret class): a rainbow colour instead of main/second.
local function recolor(keys: { { number } }, pal: Pal, hue: number?): ColorSequence
	local list = {}
	local last = -1
	for i, kp in keys do
		local t = if i == 1 then 0 elseif i == #keys then 1 else math.clamp(kp[1], 0, 1)
		if t > last then
			local _, s, v = Color3.new(kp[2], kp[3], kp[4]):ToHSV()
			local col: Color3
			if v < 0.18 then
				col = pal.dark
			elseif s < 0.22 then
				col = Color3.new(1, 1, 1):Lerp(pal.glow, 0.65)
			else
				local base = if hue then Color3.fromHSV((hue + i * 0.09) % 1, 0.75, 1) elseif i % 2 == 1 then pal.main else pal.second
				local h2, s2, v2 = base:ToHSV()
				col = Color3.fromHSV(h2, s2, math.clamp(math.max(v, 0.6) * v2, 0, 1))
			end
			table.insert(list, ColorSequenceKeypoint.new(t, col))
			last = t
		end
	end
	if #list == 1 then
		table.insert(list, ColorSequenceKeypoint.new(1, list[1].Value))
	elseif list[#list].Time < 1 then
		list[#list] = ColorSequenceKeypoint.new(1, list[#list].Value)
	end
	return ColorSequence.new(list)
end

local ENUMS: { [string]: any } = {
	EmissionDirection = Enum.NormalId,
	Shape = Enum.ParticleEmitterShape,
	ShapeInOut = Enum.ParticleEmitterShapeInOut,
	ShapeStyle = Enum.ParticleEmitterShapeStyle,
	Orientation = Enum.ParticleOrientation,
	FlipbookLayout = Enum.ParticleFlipbookLayout,
	FlipbookMode = Enum.ParticleFlipbookMode,
	TextureMode = Enum.TextureMode,
}
local PLAIN = { "Drag", "ZOffset", "VelocityInheritance", "TimeScale", "ShapePartial", "FlipbookStartRandom", "WindAffectsDrag" }

-- scale: size, speed and pull; rate: emission; bright: the brightest it may be; life: lifetime; lock: LockedToPart
type Opts = { scale: number?, rate: number?, bright: number?, life: number?, lock: boolean?, hue: number?, trans: number? }

local function setEnums(inst: Instance, d: any)
	for k, en in ENUMS do
		local v = d[k]
		if type(v) == "string" then
			pcall(function()
				(inst :: any)[k] = en[v]
			end)
		end
	end
end

local function emitter(d: any, parent: Instance, pal: Pal, o: Opts): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	local s = o.scale or 1
	e.Texture = d.Texture or ""
	if d.Color then
		e.Color = recolor(d.Color, pal, o.hue)
	end
	if d.Transparency then
		local tr = seq(d.Transparency, 1, true)
		if o.trans then -- (fainter: every key pushed toward clear)
			local kps = {}
			for _, kp in tr.Keypoints do
				table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value + (1 - kp.Value) * (o.trans :: number), 0))
			end
			tr = NumberSequence.new(kps)
		end
		e.Transparency = tr
	end
	if d.Size then
		e.Size = seq(d.Size, s)
	end
	if d.Squash then
		e.Squash = seq(d.Squash, 1)
	end
	if d.Lifetime then
		e.Lifetime = range(d.Lifetime, o.life or 1)
	end
	if d.Speed then
		e.Speed = range(d.Speed, s)
	end
	for _, k in { "Rotation", "RotSpeed", "FlipbookFramerate" } do
		if d[k] then
			(e :: any)[k] = range(d[k], 1)
		end
	end
	e.Rate = (d.Rate or 0) * (o.rate or 1)
	-- (the packs use LightEmission outside 0..1 and Brightness up to 150: Roblox keeps 0..1, and past a few it
	-- burns to white in our bright daylight)
	e.LightEmission = math.clamp(d.LightEmission or 0, 0, 1)
	e.LightInfluence = math.clamp(d.LightInfluence or 0, 0, 1)
	e.Brightness = math.min(d.Brightness or 1, o.bright or 5)
	for _, k in PLAIN do
		if d[k] ~= nil then
			(e :: any)[k] = d[k]
		end
	end
	setEnums(e, d)
	if d.Acceleration then
		e.Acceleration = Vector3.new(d.Acceleration[1], d.Acceleration[2], d.Acceleration[3]) * s
	end
	if d.SpreadAngle then
		e.SpreadAngle = Vector2.new(d.SpreadAngle[1], d.SpreadAngle[2])
	end
	e.LockedToPart = if o.lock ~= nil then o.lock else d.LockedToPart == true
	e.Parent = parent
	return e
end

local function beam(d: any, a0: Attachment, a1: Attachment, pal: Pal, o: Opts): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = d.Texture or ""
	if d.Color then
		b.Color = recolor(d.Color, pal, o.hue)
	end
	if d.Transparency then
		b.Transparency = seq(d.Transparency, 1, true)
	end
	local s = o.scale or 1
	b.Width0 = (d.Width0 or 1) * s
	b.Width1 = (d.Width1 or 1) * s
	b.TextureLength = d.TextureLength or 1
	b.TextureSpeed = d.TextureSpeed or 0
	b.LightEmission = math.clamp(d.LightEmission or 1, 0, 1)
	b.LightInfluence = 0
	b.Brightness = math.min(d.Brightness or 1, o.bright or 5)
	b.Segments = math.clamp(d.Segments or 10, 1, 40)
	b.FaceCamera = d.FaceCamera ~= false
	b.ZOffset = d.ZOffset or 0
	setEnums(b, d)
	b.Parent = a0
	return b
end

-- the pack entries named `name` (or every entry for "*"), in pack order
local function pick(pack: string, names: { string }): { any }
	local out = {}
	for _, d in Packs[pack] or {} do
		for _, n in names do
			if d.n == n then
				table.insert(out, d)
				break
			end
		end
	end
	return out
end

-------------------------------------------------------------------------------------------------------------
-- the body aura (every player) and the first-person hands (you)
-------------------------------------------------------------------------------------------------------------
-- The packs' textures that suit a garden (the LoveAura pack is mostly hearts: none of those), with their own
-- flipbooks; how each moves is ours (the packs' own settings are for one big skill, not an aura worn all day).
local TEX = {
	mote = { "rbxassetid://12942158384" }, -- LoveAura: a soft glowing dot
	star = { "rbxassetid://17062452122" }, -- LoveAura: a four-point sparkle
	spike = { "rbxassetid://17538052796" }, -- LoveAura: a tall thin flare
	bolt = { "rbxassetid://118305486979110", "Grid4x4" }, -- LoveAura: lightning flicks
	bloom = { "rbxassetid://102776387242988", "Grid4x4" }, -- LoveAura: blossoms opening
	petal = { "rbxassetid://13802408466", "Grid4x4" }, -- LoveAura: petals tumbling
	runes = { "rbxassetid://11910560348", "Grid4x4", "Loop" }, -- EvilFloor: glowing runes
	circle = { "rbxassetid://13399941667" }, -- EvilFloor: an ornate magic circle
	swirl = { "rbxassetid://12403112662" }, -- EvilFloor: a wind ring
	ring = { "rbxassetid://98115819941329" }, -- EvilFloor: a ring of sparkles
	flame = { "rbxassetid://16694134286", "Grid4x4" }, -- Explosion: a flame
}

-- One layer: tex (TEX key), from (the rarity rank it joins at), only (these classes only, from any rank), at
-- ("body": the HumanoidRootPart's 2 x 2 x 1, "feet": a point on the ground, locked to it), col ("main", "second",
-- "glow", "grad": main into second, "hot": glow into main), then sizes (keys {time, size}), rate, life, speed,
-- up (pull up, studs/s^2), spread, spin (deg/s), bright, light, flat (lies on the ground, turning), lock, fade
-- (keys {time, transparency}), drag.
type Layer = { [string]: any }
local FADE = { { 0, 1 }, { 0.15, 0.1 }, { 0.75, 0.25 }, { 1, 1 } }
local BODY_LAYERS: { Layer } = {
	{ tex = "mote", from = 1, at = "body", col = "grad", sizes = { { 0, 0 }, { 0.3, 0.32 }, { 1, 0 } }, rate = 7, life = { 1.2, 2 }, speed = { 1, 2.4 }, up = 2.2, spread = 30, bright = 2, light = 1 },
	{ tex = "star", from = 1, at = "body", col = "glow", sizes = { { 0, 0 }, { 0.5, 0.55 }, { 1, 0 } }, rate = 2.5, life = { 0.35, 0.6 }, speed = { 0, 0.2 }, spin = 60, bright = 3, light = 1 },
	{ tex = "bloom", only = { Gardener = true, UltimateGardener = true }, at = "body", col = "second", sizes = { { 0, 0.2 }, { 0.5, 0.5 }, { 1, 0.35 } }, rate = 2.2, life = { 1.2, 1.8 }, speed = { 0.4, 1 }, up = 0.5, spread = 180, spin = 40, bright = 1.4, light = 0.4, fade = FADE },
	{ tex = "petal", only = { LawnLegend = true, Gardener = true }, at = "body", col = "main", sizes = { { 0, 0.32 }, { 1, 0.24 } }, rate = 3, life = { 1.6, 2.6 }, speed = { 1, 2.5 }, up = -0.8, spread = 180, spin = 120, bright = 1.4, light = 0.3, drag = 1, fade = FADE },
	{ tex = "runes", from = 3, at = "body", col = "main", sizes = { { 0, 0 }, { 0.2, 0.42 }, { 0.8, 0.36 }, { 1, 0 } }, rate = 2.6, life = { 1.4, 2.2 }, speed = { 0.6, 1.2 }, up = 0.6, spread = 35, bright = 2.4, light = 1 },
	{ tex = "flame", from = 4, at = "body", col = "grad", sizes = { { 0, 0.5 }, { 0.35, 1.25 }, { 1, 0.3 } }, rate = 8, life = { 0.55, 0.85 }, speed = { 2.5, 4.5 }, up = 3, spread = 12, bright = 2.2, light = 0.85, orient = "VelocityParallel", fade = { { 0, 0.6 }, { 0.2, 0.15 }, { 1, 1 } } },
	{ tex = "spike", from = 4, at = "body", col = "hot", sizes = { { 0, 0 }, { 0.4, 1.3 }, { 1, 0 } }, rate = 2, life = { 0.15, 0.25 }, speed = { 0, 0 }, bright = 3, light = 1 },
	{ tex = "circle", from = 5, at = "feet", col = "main", sizes = { { 0, 6.2 }, { 1, 6.8 } }, rate = 0.55, life = { 3, 3 }, spin = 22, flat = true, bright = 2, light = 1, lock = true, fade = { { 0, 1 }, { 0.25, 0.35 }, { 0.75, 0.35 }, { 1, 1 } } },
	{ tex = "bolt", from = 5, at = "body", col = "hot", sizes = { { 0, 0.9 }, { 1, 1.5 } }, rate = 3, life = { 0.2, 0.35 }, speed = { 0, 0 }, bright = 3, light = 1, rot = true },
	{ tex = "swirl", from = 6, at = "feet", col = "second", sizes = { { 0, 4.5 }, { 1, 7.5 } }, rate = 1.1, life = { 1, 1.2 }, spin = 120, flat = true, bright = 2, light = 1, lock = true, fade = { { 0, 1 }, { 0.3, 0.3 }, { 1, 1 } } },
	{ tex = "flame", from = 6, at = "body", col = "hot", sizes = { { 0, 0.35 }, { 0.4, 0.9 }, { 1, 0.2 } }, rate = 6, life = { 0.4, 0.7 }, speed = { 4, 6 }, up = 4, spread = 25, bright = 2.4, light = 1, orient = "VelocityParallel", fade = { { 0, 0.5 }, { 0.25, 0.1 }, { 1, 1 } } },
	{ tex = "ring", from = 7, at = "feet", col = "glow", sizes = { { 0, 3 }, { 1, 8.5 } }, rate = 1.3, life = { 1.1, 1.3 }, spin = 40, flat = true, bright = 2.5, light = 1, lock = true, fade = { { 0, 0.4 }, { 1, 1 } } },
	{ tex = "petal", from = 7, at = "body", col = "grad", sizes = { { 0, 0.3 }, { 1, 0.22 } }, rate = 4, life = { 1.5, 2.4 }, speed = { 1.5, 3 }, up = -0.5, spread = 180, spin = 140, bright = 1.6, light = 0.5, drag = 1, fade = FADE },
}
local LOW_LAYERS = 3 -- phones / Potato Mode: only this many layers (the cheapest first)

-- the first-person hands: small, on the fists, most of it stuck to them (so turning doesn't smear it)
local HAND_LAYERS: { Layer } = {
	{ tex = "mote", from = 1, col = "main", sizes = { { 0, 0.22 }, { 1, 0.3 } }, rate = 5, life = { 0.3, 0.5 }, speed = { 0, 0 }, bright = 1.6, light = 1, lock = true, fade = { { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } } },
	{ tex = "mote", from = 1, col = "grad", sizes = { { 0, 0 }, { 0.3, 0.07 }, { 1, 0 } }, rate = 9, life = { 0.5, 0.9 }, speed = { 0.2, 0.6 }, up = 0.9, spread = 60, bright = 2.2, light = 1 },
	{ tex = "star", from = 2, col = "glow", sizes = { { 0, 0 }, { 0.5, 0.16 }, { 1, 0 } }, rate = 3, life = { 0.2, 0.4 }, speed = { 0, 0 }, spin = 90, bright = 2.6, light = 1, lock = true },
	{ tex = "flame", from = 3, col = "grad", sizes = { { 0, 0.1 }, { 0.35, 0.2 }, { 1, 0.05 } }, rate = 12, life = { 0.25, 0.45 }, speed = { 0.3, 0.7 }, up = 1.2, spread = 15, bright = 2, light = 0.9, orient = "VelocityParallel", fade = { { 0, 0.6 }, { 0.2, 0.15 }, { 1, 1 } } },
	{ tex = "runes", from = 3, col = "main", sizes = { { 0, 0 }, { 0.2, 0.1 }, { 1, 0 } }, rate = 2.5, life = { 0.8, 1.2 }, speed = { 0.15, 0.35 }, up = 0.3, spread = 60, bright = 2.2, light = 1 },
	{ tex = "petal", only = { LawnLegend = true, Gardener = true }, col = "main", sizes = { { 0, 0.07 }, { 1, 0.05 } }, rate = 3, life = { 0.8, 1.3 }, speed = { 0.2, 0.5 }, up = -0.2, spread = 180, spin = 160, bright = 1.4, light = 0.3, fade = FADE },
	{ tex = "bolt", from = 5, col = "hot", sizes = { { 0, 0.14 }, { 1, 0.24 } }, rate = 3.5, life = { 0.15, 0.3 }, speed = { 0, 0 }, bright = 2.8, light = 1, lock = true, rot = true },
	{ tex = "spike", from = 6, col = "hot", sizes = { { 0, 0 }, { 0.4, 0.3 }, { 1, 0 } }, rate = 2.5, life = { 0.15, 0.25 }, speed = { 0, 0 }, bright = 3, light = 1, lock = true },
}

local function colorsFor(col: string, pal: Pal, hue: number?): ColorSequence
	if hue then
		local a, b = Color3.fromHSV(hue, 0.7, 1), Color3.fromHSV((hue + 0.18) % 1, 0.7, 1)
		return ColorSequence.new(if col == "glow" then Color3.new(1, 1, 1):Lerp(a, 0.3) else a, b)
	end
	if col == "main" then
		return ColorSequence.new(pal.main)
	elseif col == "second" then
		return ColorSequence.new(pal.second)
	elseif col == "glow" then
		return ColorSequence.new(pal.glow)
	elseif col == "hot" then
		return ColorSequence.new(pal.glow, pal.main)
	end
	return ColorSequence.new(pal.main, pal.second)
end

local function keys(list: { { number } }, k: number, unit: boolean?): NumberSequence
	local t = {}
	for _, kp in list do
		table.insert(t, { kp[1], kp[2], 0 })
	end
	return seq(t, k, unit)
end

-- a layer -> a live emitter on `parent`, sizes and speeds times `k`
local function layer(L: Layer, parent: Instance, pal: Pal, k: number, hue: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "ClassVfx"
	e.Enabled = false
	local t = TEX[L.tex]
	e.Texture = t[1]
	if t[2] then
		e.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[t[2]]
		e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[t[3] or "OneShot"]
		e.FlipbookStartRandom = t[3] == "Loop"
	end
	e.Color = colorsFor(L.col, pal, hue)
	e.Size = keys(L.sizes, k)
	e.Transparency = keys(L.fade or { { 0, 0.15 }, { 1, 1 } }, 1, true)
	e.Rate = L.rate
	e.Lifetime = NumberRange.new(L.life[1], L.life[2])
	local sp = L.speed or { 0, 0 }
	e.Speed = NumberRange.new(sp[1] * k, sp[2] * k)
	e.Acceleration = Vector3.new(0, (L.up or 0) * k, 0)
	e.SpreadAngle = Vector2.new(L.spread or 0, L.spread or 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.LightEmission = L.light or 1
	e.LightInfluence = 0
	e.Brightness = L.bright or 2
	e.Drag = L.drag or 0
	e.LockedToPart = L.lock == true
	if L.spin then
		e.RotSpeed = NumberRange.new(-L.spin, L.spin)
	end
	if L.spin or L.rot then
		e.Rotation = NumberRange.new(0, 360)
	end
	if L.flat then
		-- (lying on the ground: perpendicular to a tiny upward drift)
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		e.Speed = NumberRange.new(0.01, 0.01)
		e.Acceleration = Vector3.zero
		e.SpreadAngle = Vector2.zero
		e.RotSpeed = NumberRange.new(L.spin or 0, L.spin or 0)
	elseif L.orient then
		e.Orientation = (Enum.ParticleOrientation :: any)[L.orient]
	end
	e.Parent = parent
	return e
end

local function allowed(L: Layer, id: string, rank: number): boolean
	if L.only then
		return L.only[id] == true
	end
	return rank >= (L.from or 1)
end

type Worn = {
	player: Player,
	char: Model,
	id: string,
	emitters: { ParticleEmitter },
	holder: Attachment?,
	on: boolean,
}
local worn: { [Player]: Worn } = {}

local function clear(w: Worn)
	for _, e in w.emitters do
		e:Destroy()
	end
	table.clear(w.emitters)
	if w.holder then
		w.holder:Destroy()
		w.holder = nil
	end
end

local function hueFor(pal: Pal, i: number): number?
	return if pal.rainbow then (i * 0.13) % 1 else nil
end

local function buildBody(w: Worn)
	clear(w)
	local root = w.char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = w.char:FindFirstChildOfClass("Humanoid")
	if not root then
		return
	end
	local pal = palOf(w.id)
	local rank = rankOf(w.id)
	-- the ground point: under the HumanoidRootPart, where the feet are (it moves with you)
	local feet = Instance.new("Attachment")
	feet.Name = "ClassVfxFeet"
	local hip = if hum and hum.RigType == Enum.HumanoidRigType.R15 then hum.HipHeight else 2
	feet.Position = Vector3.new(0, -(root.Size.Y / 2 + hip) + 0.15, 0)
	feet.Parent = root
	w.holder = feet
	local count = 0
	for i, L in BODY_LAYERS do
		if allowed(L, w.id, rank) and not (lowFx() and count >= LOW_LAYERS) then
			local e = layer(L, if L.at == "feet" then feet else root, pal, 1, hueFor(pal, i))
			table.insert(w.emitters, e)
			count += 1
		end
	end
	w.on = false
end

local function setOn(w: Worn, on: boolean)
	if w.on == on then
		return
	end
	w.on = on
	for _, e in w.emitters do
		e.Enabled = on
	end
end

-------------------------------------------------------------------------------------------------------------
-- first person: the hands and the screen corners
-------------------------------------------------------------------------------------------------------------
local hands = { id = nil :: string?, list = {} :: { ParticleEmitter }, arms = nil :: Instance? }
local function clearHands()
	for _, e in hands.list do
		e:Destroy()
	end
	table.clear(hands.list)
	hands.arms = nil
	hands.id = nil
end

local function buildHands(arms: Instance, id: string)
	clearHands()
	hands.arms = arms
	hands.id = id
	local pal = palOf(id)
	local rank = rankOf(id)
	for _, side in { "Right", "Left" } do
		local hand = arms:FindFirstChild(side .. "Hand") or arms:FindFirstChild(side .. " Arm")
		if hand and hand:IsA("BasePart") then
			local at = Instance.new("Attachment")
			at.Name = "ClassVfxHand"
			-- (an R6 arm is the whole arm: its fist is the bottom end)
			at.Position = if hand.Name:find("Arm") then Vector3.new(0, -hand.Size.Y / 2, 0) else Vector3.zero
			at.Parent = hand
			local n = 0
			for i, L in HAND_LAYERS do
				if allowed(L, id, rank) and not (lowFx() and n >= 2) then
					local e = layer(L, at, pal, 1, hueFor(pal, i))
					e.Enabled = true
					table.insert(hands.list, e)
					n += 1
				end
			end
		end
	end
end

-- the screen: a coloured glow round the edges and the corner art
local gui = Instance.new("ScreenGui")
gui.Name = "ClassVfx"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -5 -- (under the HUD)
gui.Parent = player:WaitForChild("PlayerGui")
-- the edges: four soft gradients in the class's colour, thickest at the screen's rim
local edges: { Frame } = {}
for _, spec in {
	{ UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0), 90 }, -- top
	{ UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.8), -90 }, -- bottom
	{ UDim2.fromScale(0.14, 1), UDim2.fromScale(0, 0), 0 }, -- left
	{ UDim2.fromScale(0.14, 1), UDim2.fromScale(0.86, 0), 180 }, -- right
} do
	local f = Instance.new("Frame")
	f.Name = "Edge"
	f.BorderSizePixel = 0
	f.Size = spec[1]
	f.Position = spec[2]
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGradient")
	g.Rotation = spec[3]
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.7), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	f.Parent = gui
	table.insert(edges, f)
end
local corners: { ImageLabel } = {}
for i, spot in { { 0, 0, 0 }, { 1, 0, 90 }, { 1, 1, 180 }, { 0, 1, 270 } } do
	local c = Instance.new("ImageLabel")
	c.Name = "Corner" .. i
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(spot[1], spot[2])
	c.Position = UDim2.fromScale(spot[1], spot[2])
	c.Size = UDim2.fromScale(0.2, 0.2)
	c.Rotation = spot[3]
	c.ImageTransparency = 1
	c.Parent = gui
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = c
	table.insert(corners, c)
end
local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.BorderSizePixel = 0
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.Parent = gui

local screen = { id = nil :: string?, flare = 0, base = 1 }
local function setScreen(id: string?)
	screen.id = id
	local pal = palOf(id)
	local rank = rankOf(id)
	-- the resting look: the edges tinted faintly, stronger the rarer (never more than a hint)
	screen.base = 0.93 - rank * 0.02
	for _, f in edges do
		f.BackgroundColor3 = pal.main
	end
	for _, c in corners do
		c.Image = pal.corner or ""
		c.ImageColor3 = Color3.new(1, 1, 1)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the equip burst
-------------------------------------------------------------------------------------------------------------
local live = Instance.new("Folder")
live.Name = "ClassVfxLive"
live.Parent = workspace

local GROUND = { "Shock", "WaterRippleMain", "crescents", "leftover1", "Lines", "Dots", "GroundFlower" }
local BURST = { "Crescents", "Ground", "Cres", "Spark", "SparkOnGround", "Shard", "ToonLightning5", "Crescent" }
local BEAM = { "MainBeam1", "ShadeBeam1", "ShadeBeam2" }

-- fire each burst emitter the pack's way (EmitCount after EmitDelay), scaled by the budget
local function fire(e: ParticleEmitter, d: any, budget: number)
	local n = math.max(1, math.floor((d.EmitCount or math.max(1, (d.Rate or 5) * 0.2)) * budget + 0.5))
	task.delay(d.EmitDelay or 0, function()
		if e.Parent then
			e:Emit(n)
		end
	end)
end

-- a short-lived anchored holder at `cf` (a part sized `box` for volume emitters, else a point)
local function holder(cf: CFrame, box: Vector3?, life: number): BasePart
	local p = Instance.new("Part")
	p.Name = "ClassVfxBurst"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = box or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = live
	Debris:AddItem(p, life)
	return p
end

local function burst(feet: Vector3, id: string, scale: number)
	local pal = palOf(id)
	local rank = rankOf(id)
	local budget = if lowFx() then 0.4 else 1
	local k = scale * (0.75 + rank * 0.06)
	-- the ground circle, lying on the ground
	local g = holder(CFrame.new(feet + Vector3.new(0, 0.15, 0)), nil, 4)
	for i, d in pick("EvilFloor", GROUND) do
		local e = emitter(d, g, pal, { scale = k * 0.32, bright = 4, hue = hueFor(pal, i) })
		fire(e, d, budget)
	end
	-- the burst round the body
	local b = holder(CFrame.new(feet + Vector3.new(0, 2.6, 0)), nil, 4)
	for i, d in pick("Explosion", BURST) do
		if rank >= 3 or i <= 4 then
			local e = emitter(d, b, pal, { scale = k * 0.16, bright = 4, life = 0.8, hue = hueFor(pal, i) })
			fire(e, d, budget)
		end
	end
	-- Legendary and up: a pillar of light up out of the ground
	if rank >= RANK.Legendary then
		local base = holder(CFrame.new(feet), nil, 2.2)
		local a0 = Instance.new("Attachment")
		a0.Parent = base
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 60, 0)
		a1.Parent = base
		local seen = {}
		for i, d in pick("BigBeam", BEAM) do
			if not seen[d.n] then
				seen[d.n] = true
				local bm = beam(d, a0, a1, pal, { scale = 0.11 * scale * (1 + (rank - 5) * 0.2), bright = 3, hue = hueFor(pal, i) })
				bm.FaceCamera = true
				local w0 = bm.Width0
				bm.Width0, bm.Width1 = w0 * 0.2, w0 * 0.05
				TweenService:Create(bm, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Width0 = w0, Width1 = w0 * 0.6 }):Play()
				task.delay(0.9, function()
					if bm.Parent then
						TweenService:Create(bm, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
					end
				end)
			end
		end
		local light = Instance.new("PointLight")
		light.Color = pal.main
		light.Range = 22
		light.Brightness = 3
		light.Parent = base
		TweenService:Create(light, TweenInfo.new(2), { Brightness = 0 }):Play()
	end
end

-- your own equip, on top of the burst: the screen and your hands
local function equipScreen(id: string)
	local pal = palOf(id)
	local rank = rankOf(id)
	flash.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(pal.main, 0.35)
	flash.BackgroundTransparency = 0.35 - rank * 0.03
	TweenService:Create(flash, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	screen.flare = 1
	for _, c in corners do
		c.Size = UDim2.fromScale(0.05, 0.05)
		TweenService:Create(c, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.2, 0.2) }):Play()
	end
	local cam = workspace.CurrentCamera
	if cam then
		local fov = cam.FieldOfView
		cam.FieldOfView = fov + 6
		TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
	end
	for _, e in hands.list do
		e:Emit(6 + rank * 2)
	end
	pcall(Sound.play, "reveal")
	if rank >= RANK.Legendary then
		pcall(Sound.play, "hatchLegend", nil, 0.6)
	end
end

-------------------------------------------------------------------------------------------------------------
-- who wears what
-------------------------------------------------------------------------------------------------------------
local function wear(p: Player, fresh: boolean)
	local id = p:GetAttribute("Class")
	local char = p.Character
	local old = worn[p]
	if old and (old.char ~= char or old.id ~= id) then
		clear(old)
		worn[p] = nil
		old = nil
	end
	if type(id) ~= "string" or not char then
		return
	end
	if not old then
		local w: Worn = { player = p, char = char, id = id, emitters = {}, holder = nil, on = false }
		worn[p] = w
		buildBody(w)
	end
	if p == player then
		setScreen(id)
		hands.id = nil -- (the hands are rebuilt for the new class next frame)
	end
	-- a real switch (not joining or respawning): the burst
	if fresh then
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cam = workspace.CurrentCamera
		if root and cam and (root.Position - cam.CFrame.Position).Magnitude < BURST_FAR then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local hip = if hum and hum.RigType == Enum.HumanoidRigType.R15 then hum.HipHeight else 2
			burst(root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0), id, 1)
			if p == player then
				equipScreen(id)
			end
		end
	end
end

local function watch(p: Player)
	local last = p:GetAttribute("Class")
	p:GetAttributeChangedSignal("Class"):Connect(function()
		local now = p:GetAttribute("Class")
		local fresh = last ~= nil and now ~= last
		last = now
		wear(p, fresh)
	end)
	p.CharacterAdded:Connect(function()
		task.wait(0.5)
		wear(p, false)
	end)
	if p.Character then
		task.defer(wear, p, false)
	end
end
for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p)
	local w = worn[p]
	if w then
		clear(w)
		worn[p] = nil
	end
end)

-- your own class's gimmick going off: the hands and the screen flare
State.on("fx", function(kind: string, d: any)
	if kind ~= "classFx" or type(d) ~= "table" or typeof(d.pos) ~= "Vector3" then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - d.pos).Magnitude > 14 then
		return
	end
	screen.flare = math.max(screen.flare, 0.6)
	for _, e in hands.list do
		e:Emit(4)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- every frame: who's near, first person or not, the hands, the screen's breathing
-------------------------------------------------------------------------------------------------------------
local function firstPerson(char: Model?, camPos: Vector3): boolean
	local head = char and char:FindFirstChild("Head") :: BasePart?
	return head ~= nil and (head.Position - camPos).Magnitude < 2.6
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local mine = worn[player]
	local fp = mine ~= nil and firstPerson(mine.char, camPos)
	for p, w in worn do
		local root = w.char.PrimaryPart
		local near = root ~= nil and (root.Position - camPos).Magnitude < FAR
		setOn(w, near and not (p == player and fp))
	end
	-- the hands: built on client/ViewModel's arms while you're in first person with a class
	local arms = if fp and mine then cam:FindFirstChild("ViewModel") and (cam :: any).ViewModel:FindFirstChild("Arms") else nil
	if arms and mine and (hands.arms ~= arms or hands.id ~= mine.id or not arms:FindFirstChild("ClassVfxHand", true)) then
		buildHands(arms, mine.id)
	elseif not arms and #hands.list > 0 then
		clearHands()
	end
	-- the screen: a faint rest, a flare that fades (equip, gimmicks); only in first person
	screen.flare = math.max(0, screen.flare - dt * 0.9)
	local t = os.clock()
	local show = fp and screen.id ~= nil
	local rest = if show then screen.base - 0.015 * math.sin(t * 1.6) else 1
	local tr = if show then math.min(rest, 1 - screen.flare * 0.55) else 1
	for _, f in edges do
		f.BackgroundTransparency = tr
	end
	for _, c in corners do
		c.ImageTransparency = if show and c.Image ~= "" then math.min(0.35 + 0.05 * math.sin(t * 1.6), 1 - screen.flare) else 1
	end
end)

-- Studio checks: play your class's equip burst (or `id`'s)
function ClassVfx.preview(id: string?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cls = id or player:GetAttribute("Class")
	if root and type(cls) == "string" then
		burst(root.Position - Vector3.new(0, 3, 0), cls, 1)
		equipScreen(cls)
	end
end

return ClassVfx
