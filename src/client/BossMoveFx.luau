--!strict
-- BOSS MOVE FX, v2 (10 Nov 2026). The owner on the first version: "Now don't make it sloppy revamp it better", "maak
-- ook gebruik van de vfx pack", "maak het echt echt pro"; picked what was sloppy: too much at once, thin black
-- crack lines, hard blocky neon streaks and arcs.
--
-- Every boss attack that lands is now ONE designed moment instead of six stacked layers. client/BossVfx.impact
-- hands the attack here first; when this plays it, the old layers (the sprite burst, the dust, the extra
-- shockwaves, the SoulShroud theme burst, BossImpact's slam) are skipped. Each recipe is built from a few pieces,
-- in the same order a hand-made effect is: a short bright pop where it lands -> the attack's own shape (cracked
-- ground, a soft slash, a hedge, vines, ice ...) -> what's thrown off (studded blocks, petals, straw, embers) -> what
-- it leaves (a fading mark). The SoulShroud pack (client/PackFx) gives the hero piece where it fits the boss:
-- the gold fire ring, petals, grass blades, water, ice, fire.
--
-- The pieces (all animated in and out, all in the game's block look or soft glow; no hairline cracks, no neon bars):
--   heave    the floor cracks open in studded slabs that tilt up along jagged lines, a glowing seam in each crack
--            that cools to dark, then the slabs settle back
--   streak   a soft glowing slash along a line (three layered glows: colour, bright, white core), shooting out from
--            the start, then fading; optionally a mark left on the floor
--   arc      the same soft glow swept round a slice (tapered at both ends), segment by segment
--   wall     a row of studded blocks bursting up out of the floor along a line and sinking back (Hedge Rows)
--   columns  studded columns growing out of the floor with a glowing tip (vines, stone)
--   pop      a soft glow on the floor that flares and fades, and one thin ring rolling out
--   puff     one themed particle burst (pollen, petals, straw, embers, water ...)
--   pack     one SoulShroud effect, fitted to the size of the hit
-- v5 (owner: "Meer umph bij alles"): every landing punches the camera in (a short FOV kick, more the heavier the
-- hit and the closer you are) and the heavy ones add a deep sub-thud under their own sound; the floor cracks
-- open taller and steeper, more blocks fly harder, the pops, lights, smoke and slashes are all bigger and
-- brighter, and the impact frame bites harder.
-- v4 (owner: "bij elke boss"): every boss's heavy hit gets the smoke ring and the impact frame, and slashes and
-- sweeps light the arena too.
-- v3 (10 Nov, owner: "Make it even better"): every pop lights up the arena round it (a real light, the boss's
-- colour), the heavy ones roll a ring of toon smoke out over the floor and give one impact frame (the picture
-- flattens for a blink; never with "Reduce camera shake"), slashes throw sparks off their length, and the slabs of
-- a crack kick up dust as they break.
-- Budget: phones get fewer slabs / blocks / particles; Potato Mode no particles and no pack effects (the shapes stay,
-- they're cheap). Studio: the Workspace attribute FxSlow slows it all down (client/BossImpact).
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tex = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("BossFxIds")) :: { [string]: string }
local BossImpact = require(script.Parent.BossImpact)
local PackFx = require(script.Parent.PackFx)
local PHONE = require(script.Parent.PhonePerf).on
local Potato = require(script.Parent.Potato)
local CameraView = require(script.Parent.CameraView)
local Sound = require(script.Parent.Sound)

local VFXLib = ReplicatedStorage:FindFirstChild("VFXLib")
local Assets = VFXLib and VFXLib:FindFirstChild("Assets") and (require(VFXLib:FindFirstChild("Assets") :: ModuleScript) :: any)
local RUNE = (Assets and Assets.Tex and Assets.Tex.RuneCircle) or Tex.glyph
local TOON_SMOKE = (Assets and Assets.Tex and (Assets.Tex.VS_ToonSmoke4x4 or Assets.Tex.SmokePuff4x4)) or Tex.smoke
local SMOKE_FLIP = Assets and Assets.Tex and (Assets.Tex.VS_ToonSmoke4x4 or Assets.Tex.SmokePuff4x4) and true or false

local K0 = BossImpact.kit
local part, tween, slow = K0.part, K0.tween, K0.slow
-- (v5) the same kit, but every throw of blocks is a bigger, harder one
local K = table.clone(K0)
K.kick = function(pos: Vector3, r: number, n: number, color: Color3, power: number)
	K0.kick(pos, r, math.ceil(n * 1.4), color, power * 1.2)
end

local BossMoveFx = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local function C(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local GOLD, STRAW, PINK, LEAF, POLLEN = C(255, 214, 90), C(240, 200, 90), C(255, 150, 200), C(86, 160, 64), C(255, 228, 90)
local SLIME, ICE, FIRE, EMBER, RUNE_C, STONE = C(140, 225, 90), C(170, 228, 255), C(255, 130, 40), C(255, 80, 30), C(63, 255, 208), C(122, 130, 108)
local EARTH = C(112, 76, 48)
local Q = if PHONE then 0.5 else 1 -- how much of the countable things (slabs, blocks, particles) phones get

local function flat(v: Vector3?): Vector3
	if not v then
		return Vector3.zAxis
	end
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
end

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

-------------------------------------------------------------------------------------------------------------
-- the pieces
-------------------------------------------------------------------------------------------------------------
-- a decal lying on the floor (Tex.glow by default), on an invisible plate
local function plate(cf: CFrame, w: number, l: number, color: Color3, alpha: number, tex: string?): (BasePart, Decal)
	local p = part("Glow", Vector3.new(w, 0.05, l), cf, color, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = tex or Tex.glow
	d.Color3 = color
	d.Transparency = alpha
	d.Parent = p
	return p, d
end

-- a soft glow that flares on the floor and fades, and one thin ring rolling out from it
local function pop(pos: Vector3, r: number, color: Color3, ring: boolean?)
	local disc = part("Pop", Vector3.new(0.06, r * 0.6, r * 0.6), CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), color:Lerp(WHITE, 0.55), Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.Transparency = 0.15
	tween(disc, 0.3, { Size = Vector3.new(0.06, r * 2.1, r * 2.1), Transparency = 1, Color = color }, Enum.EasingStyle.Quart)
	Debris:AddItem(disc, 0.35 * slow())
	-- (v3) a real light: the arena round the hit lights up in its colour for a moment
	local l = Instance.new("PointLight")
	l.Color = color:Lerp(WHITE, 0.25)
	l.Range = math.clamp(r * 3, 12, 60)
	l.Brightness = 0
	l.Shadows = false
	l.Parent = disc
	tween(l, 0.04, { Brightness = 10 }, Enum.EasingStyle.Linear)
	task.delay(0.05 * slow(), function()
		tween(l, 0.3, { Brightness = 0 }, Enum.EasingStyle.Quad)
	end)
	if ring ~= false then
		K.floorRing(pos, K.RING_THIN, color:Lerp(WHITE, 0.5), r * 0.6, r * 2.8, 0.4, 0.1, 0.22)
	end
end

-- (v4) the same light on its own (slashes and sweeps, which have no pop)
local function lightAt(pos: Vector3, r: number, color: Color3)
	local h = part("Light", Vector3.one * 0.2, CFrame.new(pos + Vector3.new(0, 1.5, 0)), WHITE, Enum.Material.SmoothPlastic)
	h.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = color:Lerp(WHITE, 0.25)
	l.Range = math.clamp(r, 10, 55)
	l.Brightness = 0
	l.Shadows = false
	l.Parent = h
	tween(l, 0.04, { Brightness = 8 }, Enum.EasingStyle.Linear)
	task.delay(0.05 * slow(), function()
		tween(l, 0.35, { Brightness = 0 }, Enum.EasingStyle.Quad)
	end)
	Debris:AddItem(h, 0.5 * slow())
end

-- a fading mark left on the floor
local function mark(cf: CFrame, w: number, l: number, color: Color3, alpha: number, life: number)
	local _, d = plate(cf + Vector3.new(0, 0.07, 0), w, l, color, alpha)
	task.delay(life * 0.45 * slow(), function()
		tween(d, life * 0.55, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	end)
	Debris:AddItem(d.Parent :: Instance, life * slow() + 0.1)
end

-- (v3) a ring of toon smoke rolling out low over the floor from `pos` (`r` = how far it rolls), in `tint`: a puff
-- thrown outward from each of `n` points round the hit
local function smokeRing(pos: Vector3, r: number, tint: Color3, n: number?)
	if Potato.on then
		return
	end
	local count = math.max(6, math.floor((n or 14) * Q))
	for i = 1, count do
		local a = i / count * math.pi * 2 + math.random() * 0.3
		local d = Vector3.new(math.sin(a), 0, math.cos(a))
		local at = pos + d * r * 0.2 + Vector3.new(0, 0.7, 0)
		local h = part("SmokeRing", Vector3.one * 0.2, CFrame.lookAt(at, at + d), WHITE, Enum.Material.SmoothPlastic)
		h.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Texture = TOON_SMOKE
		if SMOKE_FLIP then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
		e.EmissionDirection = Enum.NormalId.Front
		e.SpreadAngle = Vector2.new(14, 4)
		e.Lifetime = NumberRange.new(0.75, 1.1)
		e.Speed = NumberRange.new(r * 2.9, r * 3.9)
		e.Drag = 3
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.26), NumberSequenceKeypoint.new(0.4, r * 0.52), NumberSequenceKeypoint.new(1, r * 0.64) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(tint:Lerp(WHITE, 0.35), tint)
		e.LightInfluence = 0.7
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.TimeScale = 1 / slow()
		e.Parent = h
		e:Emit(1)
		Debris:AddItem(h, 1.3 * slow())
	end
end

-- (v4) one smoke ring for a move whose shapes all land together (a fan of tines, the arms of a star)
local lastRingAt: Vector3? = nil
local lastRingT = 0
local function smokeRingOnce(pos: Vector3, r: number, tint: Color3, n: number?)
	if lastRingAt and os.clock() - lastRingT < 0.3 and (lastRingAt - pos).Magnitude < 4 then
		return
	end
	lastRingAt, lastRingT = pos, os.clock()
	smokeRing(pos, r, tint, n)
end

-- (v3) one impact frame for the heaviest hits near you: the picture flattens (contrast up, colour out) for a blink
-- and eases back. Never with "Reduce camera shake", at most one every 0.7 s.
local lastFrame = 0
local function impactFrame(pos: Vector3)
	local player = Players.LocalPlayer
	if Potato.on or player:GetAttribute("CalmCamera") == true or os.clock() - lastFrame < 0.7 then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - pos).Magnitude > 60 then
		return
	end
	lastFrame = os.clock()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BossImpactFrame"
	cc.Contrast = 0.65
	cc.Saturation = -0.9
	cc.Brightness = 0.14
	cc.Parent = Lighting
	task.delay(0.06 * slow(), function()
		tween(cc, 0.22, { Contrast = 0, Saturation = 0, Brightness = 0 }, Enum.EasingStyle.Quad)
	end)
	Debris:AddItem(cc, 0.3 * slow())
end

-- (v3) sparks thrown off along a line (a slash's length), out to the sides and up
local function sparksAlong(from: Vector3, f: Vector3, len: number, color: Color3, n: number)
	if Potato.on then
		return
	end
	local mid = from + f * len * 0.5 + Vector3.new(0, 0.4, 0)
	local h = part("Sparks", Vector3.new(0.6, 0.6, len * 0.8), CFrame.lookAt(mid, mid + f), WHITE, Enum.Material.SmoothPlastic)
	h.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = Tex.spark
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(70, 70)
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(8, 18)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 2
	e.Size = NumberSequence.new(0.45, 0.05)
	e.Transparency = NumberSequence.new(0, 1)
	e.Color = ColorSequence.new(WHITE, color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.TimeScale = 1 / slow()
	e.Parent = h
	e:Emit(math.max(3, math.floor(n * Q)))
	Debris:AddItem(h, 0.9 * slow())
end

-- one themed particle burst; `up` 0 = straight up in a cone of `spread` degrees
type Puff = { tex: string, colors: { Color3 }, n: number, size: number, endSize: number?, life: { number }, speed: { number }, spread: number?, grav: number?, drag: number?, add: boolean?, spin: number?, area: number?, y: number?, flip: boolean? }
local function puff(pos: Vector3, o: Puff)
	if Potato.on then
		return
	end
	local a = o.area or 0.2
	local h = part("Puff", Vector3.new(0.2, a, a), CFrame.new(pos + Vector3.new(0, o.y or 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), WHITE, Enum.Material.SmoothPlastic)
	h.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = o.tex
	if o.flip then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Right -- (the host is turned: Right points up)
	e.SpreadAngle = Vector2.new(o.spread or 20, o.spread or 20)
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.Acceleration = Vector3.new(0, o.grav or -30, 0)
	e.Drag = o.drag or 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size * 0.6), NumberSequenceKeypoint.new(0.15, o.size), NumberSequenceKeypoint.new(1, o.size * (o.endSize or 0.3)) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.65, 0.25), NumberSequenceKeypoint.new(1, 1) })
	local seq = {}
	for i, c in o.colors do
		table.insert(seq, ColorSequenceKeypoint.new(if #o.colors == 1 then 0 else (i - 1) / (#o.colors - 1), c))
	end
	if #seq == 1 then
		table.insert(seq, ColorSequenceKeypoint.new(1, o.colors[1]))
	end
	e.Color = ColorSequence.new(seq)
	e.LightEmission = if o.add then 1 else 0
	e.LightInfluence = if o.add then 0 else 1
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.spin or 120), o.spin or 120)
	e.TimeScale = 1 / slow()
	e.Parent = h
	e:Emit(math.max(1, math.floor(o.n * Q)))
	Debris:AddItem(h, (o.life[2] + 0.3) * slow())
end

-- one SoulShroud effect, fitted: `ref` = how many studs across it is at scale 1
local function pack(name: string, cf: CFrame | Vector3, across: number, ref: number, color: Color3?)
	if Potato.on or not PackFx.on() then
		return
	end
	pcall(PackFx.play, name, cf, { scale = math.clamp(across / ref, 0.15, 3), color = color })
end

-- the floor cracking open: studded slabs tilting up either side of jagged cracks with a glowing seam in each
-- `arms` cracks out from `pos`, `len` studs long; `dir` + `spread` (radians either side) aim them, else all round
local function heave(pos: Vector3, len: number, arms: number, glow: Color3, floor: Color3, dir: Vector3?, spread: number?)
	local segs = if PHONE then 3 else 4
	arms = math.max(1, math.floor(arms * (if PHONE then 0.7 else 1) + 0.5))
	local base = if dir then math.atan2(flat(dir).X, flat(dir).Z) else math.random() * math.pi * 2
	for i = 1, arms do
		local a = if dir then base + (if arms == 1 then 0 else ((i - 1) / (arms - 1) * 2 - 1) * (spread or 0.3)) else base + (i - 1) / arms * math.pi * 2 + (math.random() - 0.5) * 0.5
		local at = pos
		local armLen = len * (0.85 + math.random() * 0.35)
		for k = 1, segs do
			a += (math.random() - 0.5) * 0.55
			local step = armLen / segs
			local fwd = Vector3.new(math.sin(a), 0, math.cos(a))
			local side = Vector3.new(fwd.Z, 0, -fwd.X)
			local mid = at + fwd * step / 2
			local w = math.clamp(len * 0.23, 1.7, 3.6) * (1 - (k - 1) / segs * 0.5)
			local delay = (k - 1) * 0.035 + (i - 1) * 0.008
			-- the seam: hot, then cooling to a dark crack
			local seamCf = CFrame.lookAt(mid + Vector3.new(0, 0.06, 0), mid + Vector3.new(0, 0.06, 0) + fwd)
			local seam = part("Seam", Vector3.new(w * 0.38, 0.06, 0.05), seamCf, glow:Lerp(WHITE, 0.1), Enum.Material.Neon)
			-- the slabs: rise out of the floor tilted away from the crack, then settle back
			local slabs = {}
			for _, sgn in { -1, 1 } do
				local tilt = math.rad(22 + math.random() * 20) * sgn
				local h = 0.85
				local p = mid + side * sgn * (w * 0.42) + Vector3.new(0, 0.1, 0)
				local up = CFrame.lookAt(p, p + fwd) * CFrame.Angles(0, 0, -tilt)
				local down = up - Vector3.new(0, h + 0.1, 0)
				local s = part("Slab", Vector3.new(w * 0.56, h, step * 0.96), down, shade(floor, 0.82 + math.random() * 0.22), Enum.Material.Plastic)
				s.TopSurface = Enum.SurfaceType.Studs
				table.insert(slabs, { p = s, up = up, down = down })
			end
			if k == 2 then
				-- (v3) dust kicked up where the floor breaks
				puff(mid, { tex = TOON_SMOKE, colors = { floor:Lerp(WHITE, 0.45), floor:Lerp(EARTH, 0.4) }, n = 2, size = w * 1.3, endSize = 1.6, life = { 0.6, 0.9 }, speed = { 2, 5 }, spread = 40, grav = 1, drag = 3, flip = SMOKE_FLIP })
			end
			task.delay(delay * slow(), function()
				tween(seam, 0.07, { Size = Vector3.new(w * 0.38, 0.06, step + 0.15) }, Enum.EasingStyle.Linear)
				for _, sl in slabs do
					tween(sl.p, 0.14, { CFrame = sl.up }, Enum.EasingStyle.Back)
				end
				task.delay(0.3 * slow(), function()
					tween(seam, 0.55, { Color = shade(glow, 0.25):Lerp(BLACK, 0.4) }, Enum.EasingStyle.Sine)
				end)
				task.delay(1.25 * slow(), function()
					tween(seam, 0.35, { Transparency = 1 })
					for _, sl in slabs do
						tween(sl.p, 0.45, { CFrame = sl.down }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end
				end)
			end)
			Debris:AddItem(seam, 1.8 * slow())
			for _, sl in slabs do
				Debris:AddItem(sl.p, 1.85 * slow())
			end
			at += fwd * step
		end
	end
end

-- a beam lying flat on the floor from local point p0 to p1 of `host` (widths at each end), additive
local function flatBeam(host: BasePart, p0: Vector3, p1: Vector3, w0: number, w1: number, color: Color3, alpha: number, glow: number?): Beam
	local d = (p1 - p0)
	d = if d.Magnitude > 1e-3 then d.Unit else Vector3.zAxis
	local side = Vector3.new(d.Z, 0, -d.X)
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.fromMatrix(p0, d, side) -- (a beam's width runs along its attachments' Y: lying flat)
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.fromMatrix(p1, d, side)
	a1.Parent = host
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = 0, 0
	b.FaceCamera = false
	b.Segments = 1
	b.LightEmission = glow or 1 -- (the outer glow isn't additive, so its colour still shows on a bright floor)
	b.LightInfluence = 0
	b.Brightness = 2
	b.Color = ColorSequence.new(color)
	b.Transparency = NumberSequence.new(alpha)
	b:SetAttribute("W0", w0)
	b:SetAttribute("W1", w1)
	b.Parent = host
	return b
end

-- the slash's three glows: wide colour, bright, white core (width factor, colour lerp to white, alpha, additive)
local LAYERS = { { 1.6, 0, 0.5, 0 }, { 0.7, 0.3, 0.15, 0.5 }, { 0.22, 1, 0, 1 } }

-- flare a set of beams in (widths 0 -> full), hold, then thin them out to nothing
local function flare(beams: { Beam }, inT: number, hold: number, outT: number, delay: number?)
	task.delay((delay or 0) * slow(), function()
		for _, b in beams do
			tween(b, inT, { Width0 = b:GetAttribute("W0") :: number, Width1 = b:GetAttribute("W1") :: number }, Enum.EasingStyle.Quart)
		end
		task.delay((inT + hold) * slow(), function()
			for _, b in beams do
				tween(b, outT, { Width0 = 0, Width1 = 0, Brightness = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
	end)
end

local function beamHost(at: Vector3): BasePart
	local h = part("SlashHost", Vector3.one * 0.2, CFrame.new(at), WHITE, Enum.Material.SmoothPlastic)
	h.Transparency = 1
	return h
end

-- a glowing slash along a line: thickest a little way in, tapering to points at both ends (an anime slash), it
-- flares in and thins away; optionally a mark left on the floor
local function streak(from: Vector3, dir: Vector3, len: number, w: number, color: Color3, markColor: Color3?)
	w *= 1.3 -- (v5: more umph)
	local f = flat(dir)
	local y = Vector3.new(0, 0.25, 0)
	local host = beamHost(from + y)
	local mid = f * len * 0.38
	local beams = {}
	for _, L in LAYERS do
		local c = color:Lerp(WHITE, L[2])
		table.insert(beams, flatBeam(host, mid, Vector3.zero, w * L[1], 0.05, c, L[3], L[4]))
		table.insert(beams, flatBeam(host, mid, f * len, w * L[1], 0.05, c, L[3], L[4]))
	end
	flare(beams, 0.06, 0.06, 0.32)
	Debris:AddItem(host, 0.6 * slow())
	sparksAlong(from, f, len, color, math.clamp(len * 0.4, 6, 20))
	lightAt(from + f * len * 0.5, len * 0.9, color)
	if markColor then
		mark(CFrame.lookAt(from + f * len / 2, from + f * len), w * 1.1, len, markColor, 0.35, 2)
	end
end

-- the same glow swept round a slice: centre `pos`, aimed `dir`, radius `r`, `half` radians either side; a crescent
-- (thick in the middle, pointed at both ends) drawn from one end to the other over `sweep` seconds
local function arc(pos: Vector3, dir: Vector3, r: number, half: number, w: number, color: Color3, sweep: number)
	w *= 1.3 -- (v5: more umph)
	local base = math.atan2(flat(dir).X, flat(dir).Z)
	local n = math.clamp(math.floor(math.deg(half * 2) / 4), 12, 40)
	local host = beamHost(pos + Vector3.new(0, 0.25, 0))
	local function P(u: number): Vector3
		local a = base - half + u * half * 2
		return Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
	end
	local function W(u: number): number
		return math.sin(u * math.pi) ^ 0.8 * w + 0.05
	end
	for i = 0, n - 1 do
		local u0, u1 = i / n, (i + 1) / n
		local beams = {}
		for _, L in LAYERS do
			table.insert(beams, flatBeam(host, P(u0), P(u1), W(u0) * L[1], W(u1) * L[1], color:Lerp(WHITE, L[2]), L[3], L[4]))
		end
		flare(beams, 0.05, 0.05, 0.3, u0 * sweep)
	end
	lightAt(pos + flat(dir) * r, r * 1.6, color)
	Debris:AddItem(host, (sweep + 0.5) * slow())
end

-- studded blocks bursting up out of the floor along a line and sinking back (a hedge springing up)
local function wall(from: Vector3, dir: Vector3, len: number, w: number, colors: { Color3 }, tall: number)
	local f = flat(dir)
	local side = Vector3.new(f.Z, 0, -f.X)
	local n = math.clamp(math.floor(len / 2.6 * Q), 3, 16)
	local step = len / n
	for i = 1, n do
		for _, off in { -0.25, 0.25 } do
			local h = tall * (0.65 + math.random() * 0.45)
			local s = math.min(step * 1.05, w * 0.55)
			local at = from + f * (step * (i - 0.5)) + side * (off * w + (math.random() - 0.5) * 0.4)
			local up = CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.random() * 0.3, 0)
			local down = up - Vector3.new(0, h + 0.2, 0)
			local b = part("Hedge", Vector3.new(s, h, s), down, colors[math.random(1, #colors)], Enum.Material.Plastic)
			b.TopSurface = Enum.SurfaceType.Studs
			local delay = (i - 1) / n * 0.18
			task.delay(delay * slow(), function()
				tween(b, 0.16, { CFrame = up }, Enum.EasingStyle.Back)
				task.delay(0.75 * slow(), function()
					tween(b, 0.4, { CFrame = down }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end)
			end)
			Debris:AddItem(b, (delay + 1.3) * slow())
		end
	end
end

-- studded columns growing out of the floor with a glowing tip, then sinking (vines, stone)
local function columns(pos: Vector3, r: number, n: number, color: Color3, tip: Color3?, tall: number, mat: Enum.Material?)
	n = math.max(2, math.floor(n * Q + 0.5))
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2 + math.random() * 0.5
		local d = r * (0.2 + 0.5 * math.random())
		local h = tall * (0.65 + 0.5 * math.random())
		local s = 0.9 + math.random() * 0.4
		local base = pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local lean = CFrame.Angles(math.rad(math.random(-14, 14)), a, math.rad(math.random(-14, 14)))
		local up = CFrame.new(base + Vector3.new(0, h / 2 - 0.2, 0)) * lean
		local down = up - Vector3.new(0, h + 0.4, 0)
		local p = part("Column", Vector3.new(s, h, s), down, shade(color, 0.85 + math.random() * 0.25), mat or Enum.Material.Plastic)
		p.TopSurface = Enum.SurfaceType.Studs
		local t: BasePart? = nil
		if tip then
			t = part("Tip", Vector3.one * s * 0.7, down * CFrame.new(0, h / 2 + s * 0.35, 0), tip, Enum.Material.Neon)
		end
		local delay = (i - 1) * 0.04
		task.delay(delay * slow(), function()
			tween(p, 0.16, { CFrame = up }, Enum.EasingStyle.Back)
			if t then
				tween(t, 0.16, { CFrame = up * CFrame.new(0, h / 2 + s * 0.35, 0) }, Enum.EasingStyle.Back)
			end
			task.delay(0.7 * slow(), function()
				tween(p, 0.4, { CFrame = down }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				if t then
					tween(t, 0.4, { CFrame = down * CFrame.new(0, h / 2 + s * 0.35, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
		end)
		Debris:AddItem(p, (delay + 1.25) * slow())
		if t then
			Debris:AddItem(t, (delay + 1.25) * slow())
		end
	end
end

-- a rune circle on the floor that turns, flares and fades
local function rune(pos: Vector3, r: number, color: Color3, time: number)
	local p, d = plate(CFrame.new(pos + Vector3.new(0, 0.2, 0)), r * 1.5, r * 1.5, color, 0.05, RUNE)
	tween(p, time, { Size = Vector3.new(r * 2.3, 0.05, r * 2.3), CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(90), 0) }, Enum.EasingStyle.Quart)
	tween(d, time, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(p, time * slow() + 0.1)
end

-- a blade of light stabbing down onto a spot (soft glow, not a bar)
local function stab(pos: Vector3, h: number, color: Color3)
	local top = pos + Vector3.new(0, h * 1.6, 0)
	local p = part("Stab", Vector3.new(0.9, h, 0.9), CFrame.new(top), color:Lerp(WHITE, 0.6), Enum.Material.Neon, Enum.PartType.Cylinder)
	p.CFrame = CFrame.new(top) * CFrame.Angles(0, 0, math.rad(90))
	p.Size = Vector3.new(h, 0.9, 0.9)
	p.Transparency = 0.15
	tween(p, 0.09, { CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.1 * slow(), function()
		tween(p, 0.35, { Size = Vector3.new(h, 0.05, 0.05), Transparency = 1, Color = color })
	end)
	Debris:AddItem(p, 0.55 * slow())
end

-- points every `step` studs along a strip (at most `max`)
local function along(s: any, step: number, max: number): { Vector3 }
	local out = {}
	local n = math.clamp(math.floor(s.length / step), 1, max)
	for i = 0, n - 1 do
		table.insert(out, s.pos + flat(s.dir) * (s.length * (i + 0.5) / n))
	end
	return out
end

-- the floor and the earth under it, for thrown blocks
local function dirt(floor: Color3): Color3
	return floor:Lerp(EARTH, 0.65)
end

-------------------------------------------------------------------------------------------------------------
-- the recipes, by the move's kind: (shape, the boss's colour, the arena floor) -> how hard to shake (0 = none)
-------------------------------------------------------------------------------------------------------------
type Recipe = (s: any, accent: Color3, floor: Color3) -> number
local R: { [string]: Recipe } = {}

-- a boss landing (its intro): the ground breaks under it
R.intro = function(s, accent, floor)
	pop(s.pos, s.r, accent)
	heave(s.pos, s.r * 1.1, 8, accent, floor)
	smokeRing(s.pos, s.r * 1.2, dirt(floor):Lerp(WHITE, 0.3), 20)
	impactFrame(s.pos)
	K.kick(s.pos, s.r * 0.8, 12, dirt(floor), 1.2)
	pack("DustKick", s.pos, s.r * 2, 10)
	return 9
end

-- Dandelion King ------------------------------------------------------------------------------------------
-- Scepter Smash: the ground splits in gold, a ring of golden fire, seed fluff thrown up
R.slam = function(s, _, floor)
	pop(s.pos, s.r, GOLD)
	heave(s.pos, s.r * 1.05, 6, GOLD, floor)
	smokeRing(s.pos, s.r, C(235, 220, 170), 16)
	impactFrame(s.pos)
	pack("FlameRing", s.pos, s.r * 1.6, 10, C(255, 225, 90))
	K.kick(s.pos, s.r * 0.6, 7, dirt(floor), 1)
	puff(s.pos, { tex = Tex.glow, colors = { WHITE, C(255, 248, 210) }, n = 14, size = 0.8, endSize = 0.5, life = { 1.6, 2.4 }, speed = { 18, 30 }, spread = 25, grav = -8, drag = 1.6, add = true })
	return 8
end
-- Royal Decree: a gold slash of light down each line, leaving a gold glow
R.cross = function(s)
	streak(s.pos, s.dir, s.length, s.width * 0.5, GOLD, C(200, 160, 50))
	return 4
end

-- Harvest Maw ---------------------------------------------------------------------------------------------
-- Pitchfork Thrust: a straw-gold stab down each tine, the floor cracked open at its point
R.fan = function(s, _, floor)
	streak(s.pos, s.dir, s.length, s.width * 0.7, STRAW, C(150, 110, 50))
	local tipAt = s.pos + flat(s.dir) * s.length * 0.92
	heave(tipAt, 5, 3, FIRE, floor, s.dir, 0.6)
	K.kick(tipAt, 3, 3, dirt(floor), 0.8)
	-- (v4, owner: "bij elke boss") the Harvest Maw's heavy hit: the thrust kicks smoke off its feet, one impact frame
	smokeRingOnce(s.pos, 10, C(210, 180, 120), 14)
	impactFrame(s.pos + flat(s.dir) * s.length * 0.5)
	return 6
end
-- Chaff Storm: each bundle of straw lands with a soft puff
R.lob = function(s)
	pop(s.pos, s.r * 0.7, STRAW, false)
	puff(s.pos, { tex = Tex.strand, colors = { STRAW, C(196, 154, 108) }, n = 7, size = 1.3, life = { 0.7, 1.1 }, speed = { 8, 14 }, spread = 60, grav = -26, spin = 200 })
	return 2
end
-- Crop Circles: the wheat flattens in a ring of gold light, chaff thrown up off it
R.rings = function(s)
	local mid = (s.inner + s.outer) / 2
	K.floorRing(s.pos, K.RING_THIN, GOLD, mid * 1.6, mid * 2.2, 0.55, 0, 0.22)
	pack("RingBurst", s.pos, mid * 2, 6.5, C(255, 200, 90))
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + math.random() * 0.4
		puff(s.pos + Vector3.new(math.cos(a) * mid, 0, math.sin(a) * mid), { tex = Tex.strand, colors = { STRAW, GOLD }, n = 4, size = 1.2, life = { 0.7, 1.1 }, speed = { 10, 16 }, spread = 25, grav = -25, spin = 200 })
	end
	return 5
end

-- Sakura Snapjaw ------------------------------------------------------------------------------------------
-- Petal Spiral: each petal shot lands with a pink pop
R.spiral = function(s)
	pop(s.pos, s.r * 0.7, PINK, false)
	puff(s.pos, { tex = Tex.petal, colors = { PINK, WHITE }, n = 5, size = 1.1, life = { 0.8, 1.2 }, speed = { 6, 11 }, spread = 60, grav = -5, drag = 1.6, spin = 300 })
	return 0
end
-- Snap Lunge: a pink slash down the lunge, petals torn up behind it
R.sweep = function(s, _, floor)
	streak(s.pos, s.dir, s.length, s.width * 0.55, PINK, C(200, 100, 150))
	pack("Petals", s.pos + flat(s.dir) * s.length * 0.5, s.width * 1.6, 8, PINK)
	for _, p in along(s, 14, 3) do
		K.kick(p, s.width * 0.4, 2, dirt(floor), 0.7)
	end
	return 6
end
-- Petal Blizzard: petals fountain up all round the ring
R.ring = function(s)
	local mid = (s.inner + s.outer) / 2
	K.floorRing(s.pos, K.RING_THIN, PINK, mid * 1.4, mid * 2.4, 0.5, 0.1, 0.22)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		puff(s.pos + Vector3.new(math.cos(a) * mid, 0, math.sin(a) * mid), { tex = Tex.petal, colors = { PINK, WHITE, C(255, 120, 180) }, n = 6, size = 1.3, life = { 1.2, 1.8 }, speed = { 14, 22 }, spread = 16, grav = -6, drag = 1.3, spin = 360 })
	end
	return 5
end
-- Blossom Leap: it lands, the ground cracks pink, a geyser of petals
R.leap = function(s, _, floor)
	pop(s.pos, s.r, PINK)
	heave(s.pos, s.r, 6, PINK, floor)
	smokeRing(s.pos, s.r, C(255, 220, 235), 16)
	impactFrame(s.pos)
	pack("Petals", s.pos, s.r * 2, 8, PINK)
	K.kick(s.pos, s.r * 0.6, 7, dirt(floor), 1.1)
	return 9
end

-- Bramble Brute -------------------------------------------------------------------------------------------
-- Hedge Rows: a real hedge bursts up along each row and sinks back
R.hedges = function(s)
	wall(s.pos, s.dir, s.length, s.width, { C(62, 128, 52), C(80, 150, 60), C(98, 170, 70) }, 3.2)
	pack("GreenImpact", s.pos + flat(s.dir) * s.length * 0.5, s.width * 1.4, 5, C(150, 235, 90))
	return 5
end
-- Knuckle Combo: each punch dents the floor
R.combo = function(s, _, floor)
	pop(s.pos, s.r, C(255, 130, 90))
	heave(s.pos, s.r * 0.9, 4, C(255, 120, 70), floor)
	smokeRing(s.pos, s.r * 0.8, dirt(floor):Lerp(WHITE, 0.35), 8)
	impactFrame(s.pos) -- (v4: the Bramble Brute's punches; at most one a 0.7 s, so the first and the last)
	K.kick(s.pos, s.r * 0.5, 4, dirt(floor), 0.9)
	return 7
end
-- Pollen Bomb: everything outside the safe spots is swallowed by a golden cloud of pollen
R.safe = function(s)
	K.floorRing(s.pos, K.RING_SHOCK, POLLEN, s.r * 0.3, s.r * 2.2, 0.6, 0.1, 0.2)
	pack("Explosion", s.pos, s.r * 1.6, 131, POLLEN)
	lightAt(s.pos, s.r * 2, POLLEN)
	smokeRing(s.pos, math.min(s.r * 0.7, 18), C(250, 230, 150), 18)
	impactFrame(s.pos)
	puff(s.pos, { tex = Tex.glow, colors = { POLLEN, C(255, 246, 180) }, n = 18, size = 3, endSize = 1.5, life = { 1, 1.5 }, speed = { s.r * 0.6, s.r * 1.1 }, spread = 85, grav = 2, drag = 2.2, add = true, area = s.r * 0.3 })
	return 7
end

-- Bog Strangler -------------------------------------------------------------------------------------------
-- Geyser Field: a water spout on every third tile (dozens land at once)
local gridN = 0
R.grid = function(s)
	gridN += 1
	if gridN % 3 ~= 0 then
		return 3
	end
	puff(s.pos, { tex = Tex.bubble, colors = { C(200, 240, 255), SLIME }, n = 9, size = 1.1, life = { 0.6, 1 }, speed = { 26, 38 }, spread = 7, grav = -60, add = true })
	pop(s.pos, s.size * 0.4, C(150, 220, 200), false)
	return 3
end
-- Slime Hopper / a sprout's spit: a slime splat that stays a moment
local function slime(s: any): number
	pop(s.pos, s.r * 0.8, SLIME, false)
	pack("WaterSwirl", s.pos, s.r * 1.6, 8, SLIME)
	mark(CFrame.new(s.pos) * CFrame.Angles(0, math.random() * 6.3, 0), s.r * 1.5, s.r * 1.5, shade(SLIME, 0.7), 0.25, 2.5)
	return 3
end
R.bounce = slime
R.turrets = slime
-- Strangle Vines: vines burst up out of the bog where you stood
R.stalk = function(s)
	pop(s.pos, s.r, SLIME, false)
	columns(s.pos, s.r, 5, C(60, 120, 50), C(160, 255, 110), 5)
	-- (v4) the Bog Strangler's heavy hit: bog muck rolling out, one impact frame
	smokeRing(s.pos, s.r * 1.2, C(120, 140, 80), 12)
	impactFrame(s.pos)
	return 5
end

-- Frost Thornback -----------------------------------------------------------------------------------------
-- Ice Rake: an icy slash swept across the cone, ice shards and frost in its wake
R.cone = function(s, _, floor)
	arc(s.pos, s.dir, s.r * 0.65, s.half, math.max(3, s.r * 0.12), ICE, 0.16)
	heave(s.pos + flat(s.dir) * 4, s.r * 0.6, 3, ICE, floor, s.dir, s.half * 0.7)
	BossImpact.ice(s.pos + flat(s.dir) * s.r * 0.55, 8, true)
	smokeRing(s.pos, 10, C(225, 242, 255), 14)
	impactFrame(s.pos + flat(s.dir) * s.r * 0.4)
	return 7
end
-- Frost Traps: the ice forms where it lands
R.sink = function(s)
	pop(s.pos, s.r, ICE)
	pack("IceSplash", s.pos, s.r * 1.8, 30, ICE)
	return 4
end
-- Ice Ambush: it bursts up through the ice
R.burrow = function(s, _, floor)
	pop(s.pos, s.r, ICE)
	heave(s.pos, s.r, 7, ICE, floor)
	smokeRing(s.pos, s.r, C(225, 242, 255), 18)
	impactFrame(s.pos)
	BossImpact.ice(s.pos, s.r * 0.8, false)
	K.kick(s.pos, s.r * 0.5, 8, C(230, 245, 255), 1.2)
	return 9
end

-- Hollow Harvest ------------------------------------------------------------------------------------------
-- Reaper Swing: a burning slash swept across each slice, embers in its wake
R.swing = function(s)
	arc(s.pos, s.dir, s.r * 0.7, s.half, math.max(3, s.r * 0.11), EMBER, 0.1)
	puff(s.pos + flat(s.dir) * s.r * 0.7, { tex = Tex.spark, colors = { C(255, 210, 120), EMBER }, n = 10, size = 0.5, life = { 0.7, 1.2 }, speed = { 6, 12 }, spread = 70, grav = 6, add = true })
	return 6
end
-- Jack Bombs, a Jack-o'-Minion going off: a fireball, a scorch
local function blast(s: any, floor: Color3): number
	pop(s.pos, s.r, FIRE)
	pack("FireBurst", s.pos, s.r * 1.4, 23.5, FIRE)
	smokeRing(s.pos, s.r * 0.9, C(70, 50, 45), 10)
	mark(CFrame.new(s.pos), s.r * 1.6, s.r * 1.6, C(40, 22, 16), 0.3, 2.4)
	K.kick(s.pos, s.r * 0.5, 4, dirt(floor), 1)
	return 6
end
R.mines = function(s, _, floor)
	return blast(s, floor)
end
R.boom = function(s, _, floor)
	return blast(s, floor)
end
-- Hellfire Dash: a line of fire down its path and the scorched streak it leaves
R.dash = function(s)
	streak(s.pos, s.dir, s.length, s.width * 0.6, FIRE, C(40, 22, 16))
	for _, p in along(s, 9, 5) do
		puff(p, { tex = Tex.flame, colors = { C(255, 225, 130), FIRE, EMBER }, n = 4, size = 2.2, endSize = 0.3, life = { 0.4, 0.8 }, speed = { 3, 8 }, spread = 25, grav = 10, add = true })
	end
	return 7
end
-- Reaper's Mark: a rune locks on, then a blade of light comes down on it
R.mark = function(s, _, floor)
	rune(s.pos, s.r, EMBER, 0.9)
	stab(s.pos, 20, C(255, 160, 70))
	heave(s.pos, s.r * 0.7, 4, EMBER, floor)
	-- (v4) the Hollow Harvest's heavy hit: ash rolling out from the blade, one impact frame
	pop(s.pos, s.r, EMBER, false)
	smokeRing(s.pos, s.r * 1.1, C(70, 50, 45), 14)
	impactFrame(s.pos)
	return 7
end

-- Jungle Titan --------------------------------------------------------------------------------------------
-- Temple Quake: a glowing cyan crack runs down every arm of the star
R.star = function(s, _, floor)
	heave(s.pos, s.length * 0.55, 1, RUNE_C, floor, s.dir, 0)
	K.kick(s.pos + flat(s.dir) * s.length * 0.45, 3, 3, STONE, 0.9)
	-- (v4) the Jungle Titan's heavy hit: stone dust rolling out from its feet (once for all the arms), one impact frame
	smokeRingOnce(s.pos, 14, C(170, 175, 160), 18)
	lightAt(s.pos, 40, RUNE_C)
	impactFrame(s.pos)
	return 7
end
-- Rune Meteors: a rune flares where each lands, stone thrown up
R.meteors = function(s)
	rune(s.pos, s.r * 0.75, RUNE_C, 0.6)
	pop(s.pos, s.r * 0.8, RUNE_C, false)
	K.kick(s.pos, s.r * 0.4, 3, STONE, 0.9)
	return 4
end
-- Stone Pillars: they punch up out of the floor
R.pillars = function(s)
	pop(s.pos, s.r, RUNE_C, false)
	smokeRing(s.pos, s.r * 1.4, C(170, 175, 160), 10)
	K.kick(s.pos, s.r * 1.4, 6, STONE, 1.1)
	return 5
end
-- Rune Lasers: a cyan streak burnt into the floor
R.laser = function(s)
	streak(s.pos, s.dir, s.length, s.width * 0.55, RUNE_C, C(20, 70, 60))
	return 5
end
-- Titan's Gaze: a rune circle flares under it, the light washes out over everything you didn't hide from
R.gaze = function(s)
	rune(s.pos, s.r * 0.35, RUNE_C, 1.2)
	K.floorRing(s.pos, K.RING_SHOCK, RUNE_C, s.r * 0.3, s.r * 2.2, 0.8, 0.1, 0.2)
	return 8
end

-- (v5) the umph you feel: the camera punches in (an FOV kick, client/CameraView: more for heavier hits and the
-- closer you are; "Reduce camera shake" softens it there) and a heavy hit drops a deep sub-thud under its sound
local lastPunch = 0
local function punch(s: any, power: number)
	if power <= 0 or os.clock() - lastPunch < 0.12 then
		return
	end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local at = if s.type == "strip" and s.dir and s.length then s.pos + flat(s.dir) * s.length * 0.4 else s.pos
	local d = (root.Position - at).Magnitude
	if d > 90 then
		return
	end
	lastPunch = os.clock()
	local k = 1 - d / 90
	pcall(CameraView.kick, power * 0.75 * k)
	if power >= 7 then
		pcall(Sound.playAt, "bossThud", 0.55 + math.random() * 0.08, 0.9 * k)
	end
end

-- Play attack `kind`'s landing for shape `s` (client/BossVfx.impact). Returns how hard to shake the camera, or nil
-- when this attack has no recipe here (BossVfx then plays its old layers).
function BossMoveFx.play(kind: string, s: any, accent: Color3, floor: Color3): number?
	local f = R[kind]
	if not f or not s or typeof(s.pos) ~= "Vector3" then
		return nil
	end
	-- a Pollen Bomb and the Titan's Gaze are both "safe" shapes: the gaze has its own recipe by its kind
	local ok, shake = pcall(f, s, accent, floor)
	if not ok then
		warn("[BossMoveFx] " .. kind .. ": " .. tostring(shake))
		return 0
	end
	punch(s, shake)
	return shake
end

return BossMoveFx
