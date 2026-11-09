--!strict
-- BOSS MOVE FX (10 Nov 2026; owner, after the first boss pass: "Ja verdiep je meer met elke attack"). Every boss
-- attack that lands gets one touch of its own on top of the shared hit (client/BossVfx burst + client/BossImpact
-- slam), so each reads as what it is:
--   Dandelion King  Scepter Smash: the floor cracks, seed fluff fountains up | Royal Decree: a gold carpet of
--                   light along each line, glints | Jack-o'-Minion boom / Spit: see below
--   Harvest Maw     Pitchfork Thrust: a straw-gold stab along each tine | Chaff Storm: a puff of straw |
--                   Crop Circles: the wheat flattened in a gold ring, chaff flying up off it
--   Sakura Snapjaw  Petal Spiral: a pink pop | Snap Lunge: a pink slash along the lunge, petals behind |
--                   Petal Blizzard: petals fountaining round the ring | Blossom Leap: cracks and a petal geyser
--   Bramble Brute   Hedge Rows: a wall of leaf blocks bursting along each row | Knuckle Combo: cracks under each
--                   punch | Pollen Bomb: a yellow mushroom of pollen
--   Bog Strangler   Geyser Field: a water spout (a third of the tiles) | Slime Hopper / Spit: a slime splat |
--                   Strangle Vines: green vines stab up
--   Frost Thornback Ice Rake: an icy arc swept across the cone | Frost Traps: a frost ring | Ice Ambush: icy cracks
--   Hollow Harvest  Reaper Swing: a burning arc swept across each slice | Jack Bombs / minion boom: a ring of fire
--                   | Hellfire Dash: a line of fire and a scorched streak | Reaper's Mark: a rune and a blade of
--                   light stabbing down
--   Jungle Titan    Temple Quake: cracks along every arm | Rune Meteors: a rune flash | Stone Pillars: stone
--                   blocks | Rune Lasers: a cyan streak burnt into the floor | Titan's Gaze: a rune circle and a
--                   flash where you weren't hiding
-- Kept short and light: most of it is gone in under a second, and many shapes landing at once (a geyser field,
-- meteors) only get a few. Nothing extra on phones' busiest moves; Potato Mode skips the particles.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tex = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("BossFxIds")) :: { [string]: string }
local BossImpact = require(script.Parent.BossImpact)
local PHONE = require(script.Parent.PhonePerf).on
local Potato = require(script.Parent.Potato)

local VFXLib = ReplicatedStorage:FindFirstChild("VFXLib")
local Assets = VFXLib and VFXLib:FindFirstChild("Assets") and (require(VFXLib:FindFirstChild("Assets") :: ModuleScript) :: any)
local RUNE = (Assets and Assets.Tex and Assets.Tex.RuneCircle) or Tex.glyph

local K = BossImpact.kit
local part, tween, slow = K.part, K.tween, K.slow

local BossMoveFx = {}

local WHITE = Color3.new(1, 1, 1)
local function C(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local GOLD, STRAW, PINK, LEAF, POLLEN = C(255, 214, 90), C(240, 200, 90), C(255, 150, 200), C(70, 150, 60), C(255, 228, 90)
local SLIME, ICE, FIRE, EMBER, RUNE_C, STONE = C(130, 220, 80), C(190, 236, 255), C(255, 120, 40), C(255, 70, 20), C(63, 255, 208), C(122, 130, 108)

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
end

-------------------------------------------------------------------------------------------------------------
-- the pieces
-------------------------------------------------------------------------------------------------------------
-- particles from a spot: `up` (studs a second) straight up with `spread` degrees round it
type Burst = { tex: string, colors: { Color3 }, n: number, size: number, endSize: number?, life: { number }, speed: { number }, spread: number?, grav: number?, drag: number?, add: boolean?, spin: number?, area: number? }
local function burst(pos: Vector3, o: Burst)
	if Potato.on then
		return
	end
	local a = o.area or 0.2
	local h = part("Burst", Vector3.new(0.2, a, a), CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), WHITE, Enum.Material.SmoothPlastic)
	h.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = o.tex
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Right -- (the host is turned: Right points up)
	e.SpreadAngle = Vector2.new(o.spread or 20, o.spread or 20)
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.Acceleration = Vector3.new(0, o.grav or -30, 0)
	e.Drag = o.drag or 0.6
	e.Size = NumberSequence.new(o.size, o.size * (o.endSize or 0.3))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) })
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
	e:Emit(math.max(1, math.floor(o.n * (if PHONE then 0.5 else 1))))
	Debris:AddItem(h, (o.life[2] + 0.3) * slow())
end

-- cracks running out across the floor from `pos`: dark jagged lines with a hot glow in them that cools
local function cracks(pos: Vector3, r: number, n: number, glow: Color3, dark: Color3?, dir: Vector3?, half: number?)
	local d = dark or C(40, 30, 24)
	for i = 1, n do
		local a = if dir then math.atan2(dir.X, dir.Z) + (math.random() * 2 - 1) * (half or 0.2) else (i - 1) / n * math.pi * 2 + math.random() * 0.5
		local at = pos
		local len = r * (0.55 + math.random() * 0.45)
		local segs = 3
		for k = 1, segs do
			a += (math.random() - 0.5) * 0.7
			local step = len / segs
			local fwd = Vector3.new(math.sin(a), 0, math.cos(a))
			local mid = at + fwd * step / 2 + Vector3.new(0, 0.09 + k * 0.004, 0)
			local w = 0.55 * (1 - (k - 1) / segs * 0.6)
			local cf = CFrame.lookAt(mid, mid + fwd)
			local line = part("Crack", Vector3.new(w, 0.05, 0.05), cf, d, Enum.Material.SmoothPlastic)
			local hot = part("CrackGlow", Vector3.new(w * 0.4, 0.06, 0.05), cf + Vector3.new(0, 0.01, 0), glow, Enum.Material.Neon)
			local delay = (k - 1) * 0.04
			task.delay(delay * slow(), function()
				tween(line, 0.06, { Size = Vector3.new(w, 0.05, step) }, Enum.EasingStyle.Linear)
				tween(hot, 0.06, { Size = Vector3.new(w * 0.4, 0.06, step) }, Enum.EasingStyle.Linear)
				task.delay(0.35 * slow(), function()
					tween(hot, 0.5, { Transparency = 1, Color = d })
				end)
				task.delay(1.1 * slow(), function()
					tween(line, 0.8, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				end)
			end)
			Debris:AddItem(line, 2.2 * slow())
			Debris:AddItem(hot, 1.2 * slow())
			at += fwd * step
		end
	end
end

-- a glowing stab of light along a strip: it shoots out from the start, flashes and leaves a fading streak
local function streak(pos: Vector3, dir: Vector3, length: number, width: number, color: Color3, trail: Color3?)
	local f = flat(dir)
	local w = math.max(0.6, width * 0.3)
	local startCf = CFrame.lookAt(pos + Vector3.new(0, 0.2, 0), pos + Vector3.new(0, 0.2, 0) + f)
	local beam = part("Streak", Vector3.new(w, 0.12, 0.2), startCf, color:Lerp(WHITE, 0.4), Enum.Material.Neon)
	beam.Transparency = 0.05
	tween(beam, 0.09, { Size = Vector3.new(w, 0.12, length), CFrame = startCf * CFrame.new(0, 0, -length / 2) }, Enum.EasingStyle.Quart)
	task.delay(0.12 * slow(), function()
		tween(beam, 0.35, { Size = Vector3.new(0.1, 0.12, length), Transparency = 1, Color = color })
	end)
	Debris:AddItem(beam, 0.55 * slow())
	if trail then
		local mark = part("StreakMark", Vector3.new(width * 0.55, 0.05, length), startCf * CFrame.new(0, -0.08, -length / 2), trail, Enum.Material.SmoothPlastic)
		mark.Transparency = 0.45
		task.delay(0.5 * slow(), function()
			tween(mark, 1.3, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end)
		Debris:AddItem(mark, 2 * slow())
	end
end

-- a burning / icy arc swept across a slice: segments light up one after another round the arc, then cool
local function crescent(pos: Vector3, dir: Vector3, r: number, half: number, color: Color3, hot: Color3, time: number)
	local base = math.atan2(flat(dir).X, flat(dir).Z)
	local n = math.clamp(math.floor(math.deg(half * 2) / 9), 6, 24)
	local rad = r * 0.72
	for i = 1, n do
		local a = base - half + (i - 0.5) / n * half * 2
		local chord = 2 * rad * math.sin(half / n) + 0.4
		local at = pos + Vector3.new(math.sin(a) * rad, 0.25, math.cos(a) * rad)
		local cf = CFrame.lookAt(at, at + Vector3.new(math.cos(a), 0, -math.sin(a)))
		local seg = part("Arc", Vector3.new(r * 0.28, 0.12, chord), cf, hot, Enum.Material.Neon)
		seg.Transparency = 1
		task.delay((i - 1) / n * time * slow(), function()
			seg.Transparency = 0.05
			tween(seg, 0.35, { Transparency = 1, Color = color, Size = Vector3.new(r * 0.1, 0.12, chord) })
		end)
		Debris:AddItem(seg, (time + 0.45) * slow())
	end
end

-- a rune circle on the floor that turns, flares and fades
local function rune(pos: Vector3, r: number, color: Color3, time: number?)
	local t = time or 0.8
	local p = part("Rune", Vector3.new(r * 1.4, 0.05, r * 1.4), CFrame.new(pos + Vector3.new(0, 0.2, 0)), color, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = RUNE
	d.Color3 = color
	d.Transparency = 0.05
	d.Parent = p
	tween(p, t, { Size = Vector3.new(r * 2.4, 0.05, r * 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(120), 0) }, Enum.EasingStyle.Quart)
	tween(d, t, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(p, t * slow() + 0.1)
end

-- a blade of light stabbing down from the sky onto a spot
local function stab(pos: Vector3, h: number, color: Color3)
	local w = 1.2
	local top = CFrame.new(pos + Vector3.new(0, h * 1.5, 0))
	local p = part("Stab", Vector3.new(w, h, w * 0.25), top, color:Lerp(WHITE, 0.5), Enum.Material.Neon)
	p.Transparency = 0.1
	tween(p, 0.08, { CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.1 * slow(), function()
		tween(p, 0.3, { Size = Vector3.new(0.1, h, 0.05), Transparency = 1, Color = color })
	end)
	Debris:AddItem(p, 0.5 * slow())
end

-- a splat that stays on the floor a while (slime, sap)
local function splat(pos: Vector3, r: number, color: Color3, life: number)
	local p = part("Splat", Vector3.new(r * 1.6, 0.05, r * 1.6), CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.random() * 6.3, 0), color, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = Tex.bubble
	d.Color3 = color
	d.Transparency = 0.15
	d.Parent = p
	for _ = 1, 5 do
		local a = math.random() * math.pi * 2
		local s = r * (0.15 + math.random() * 0.2)
		local at = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * r * (0.5 + math.random() * 0.5) + Vector3.new(0, 0.1, 0)
		local blob = part("SplatBlob", Vector3.new(0.12, s, s), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		blob.Transparency = 0.2
		task.delay(life * 0.6 * slow(), function()
			tween(blob, life * 0.4, { Transparency = 1 })
		end)
		Debris:AddItem(blob, life * slow() + 0.1)
	end
	task.delay(life * 0.6 * slow(), function()
		tween(d, life * 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(p, life * slow() + 0.1)
end

-- vines / thorns / stone stabbing up out of the floor and sinking back
local function spears(pos: Vector3, r: number, n: number, color: Color3, mat: Enum.Material, tall: number, tip: Color3?)
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2 + math.random() * 0.6
		local d = r * (0.15 + 0.55 * math.random())
		local h = tall * (0.6 + 0.6 * math.random())
		local base = pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local lean = CFrame.Angles(math.rad(math.random(-22, 22)), a, math.rad(math.random(-22, 22)))
		local up = CFrame.new(base + Vector3.new(0, h / 2 - 0.2, 0)) * lean
		local p = part("Spear", Vector3.new(0.8, h, 0.8), up - Vector3.new(0, h, 0), color, mat)
		local t: BasePart? = nil
		if tip then
			t = part("SpearTip", Vector3.new(0.5, 0.6, 0.5), up * CFrame.new(0, h / 2, 0) - Vector3.new(0, h, 0), tip, Enum.Material.Neon)
		end
		tween(p, 0.12, { CFrame = up }, Enum.EasingStyle.Back)
		if t then
			tween(t, 0.12, { CFrame = up * CFrame.new(0, h / 2, 0) }, Enum.EasingStyle.Back)
		end
		task.delay(0.65 * slow(), function()
			tween(p, 0.35, { CFrame = up - Vector3.new(0, h, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			if t then
				tween(t, 0.35, { CFrame = up * CFrame.new(0, h / 2, 0) - Vector3.new(0, h, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		Debris:AddItem(p, 1.1 * slow())
		if t then
			Debris:AddItem(t, 1.1 * slow())
		end
	end
end

-- a ring of fire running out over the floor
local function fireRing(pos: Vector3, r: number)
	K.floorRing(pos, K.RING_SHOCK, FIRE, r * 0.4, r * 2.4, 0.45, 0.05, 0.15)
	burst(pos, { tex = Tex.flame, colors = { C(255, 230, 120), FIRE, EMBER }, n = 14, size = r * 0.28, endSize = 0.4, life = { 0.3, 0.6 }, speed = { r * 1.6, r * 2.6 }, spread = 85, grav = 6, drag = 3, add = true, area = r * 0.5 })
	burst(pos, { tex = Tex.spark, colors = { C(255, 200, 100), EMBER }, n = 12, size = 0.5, life = { 0.8, 1.4 }, speed = { 8, 16 }, spread = 50, grav = -8, add = true })
end

-- a strip's points every `step` studs (for things laid along a line)
local function along(s: any, step: number, max: number): { Vector3 }
	local out = {}
	local n = math.clamp(math.floor(s.length / step), 1, max)
	for i = 0, n - 1 do
		table.insert(out, s.pos + flat(s.dir) * (s.length * (i + 0.5) / n))
	end
	return out
end

-------------------------------------------------------------------------------------------------------------
-- each attack's touch, by the move's kind (shape `s`, the boss's colour `accent`, the arena floor `floor`)
-------------------------------------------------------------------------------------------------------------
local SIG: { [string]: (s: any, accent: Color3, floor: Color3) -> () } = {}

-- Dandelion King
SIG.slam = function(s)
	cracks(s.pos, s.r * 1.1, 7, POLLEN)
	burst(s.pos, { tex = Tex.glow, colors = { WHITE, C(255, 248, 210) }, n = 16, size = 0.9, endSize = 0.5, life = { 1.4, 2.2 }, speed = { 20, 34 }, spread = 22, grav = -10, drag = 1.4, add = true })
end
SIG.cross = function(s)
	streak(s.pos, s.dir, s.length, s.width, GOLD, C(200, 160, 60))
	for _, p in along(s, 14, 5) do
		burst(p, { tex = Tex.spark, colors = { WHITE, GOLD }, n = 4, size = 0.8, life = { 0.4, 0.8 }, speed = { 6, 12 }, spread = 40, grav = -4, add = true })
	end
end
-- Harvest Maw
SIG.fan = function(s)
	streak(s.pos, s.dir, s.length, s.width, STRAW, C(150, 110, 50))
	burst(s.pos + flat(s.dir) * s.length * 0.85, { tex = Tex.strand, colors = { STRAW, C(196, 154, 108) }, n = 10, size = 1.4, life = { 0.8, 1.3 }, speed = { 10, 18 }, spread = 50, grav = -25 })
end
SIG.lob = function(s)
	burst(s.pos, { tex = Tex.strand, colors = { STRAW, C(196, 154, 108) }, n = 6, size = 1.2, life = { 0.6, 1 }, speed = { 8, 14 }, spread = 60, grav = -25 })
end
SIG.rings = function(s)
	local r = (s.inner + s.outer) / 2
	K.floorRing(s.pos, K.RING_THIN, GOLD, r * 1.8, r * 2.15, 0.6, 0, 0.18)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + math.random() * 0.4
		burst(s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), { tex = Tex.strand, colors = { STRAW, GOLD }, n = 4, size = 1.2, life = { 0.7, 1.1 }, speed = { 10, 18 }, spread = 25, grav = -25 })
	end
end
-- Sakura Snapjaw
SIG.spiral = function(s)
	burst(s.pos, { tex = Tex.petal, colors = { PINK, WHITE }, n = 5, size = 1.1, life = { 0.7, 1.1 }, speed = { 6, 12 }, spread = 60, grav = -6, drag = 1.5, spin = 300 })
end
SIG.sweep = function(s)
	streak(s.pos, s.dir, s.length, s.width, PINK, C(200, 90, 140))
	for _, p in along(s, 12, 4) do
		burst(p, { tex = Tex.petal, colors = { PINK, WHITE, C(255, 120, 180) }, n = 6, size = 1.3, life = { 1, 1.6 }, speed = { 6, 12 }, spread = 70, grav = -3, drag = 1.8, spin = 360 })
	end
end
SIG.ring = function(s)
	local r = (s.inner + s.outer) / 2
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		burst(s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), { tex = Tex.petal, colors = { PINK, WHITE }, n = 5, size = 1.3, life = { 1.2, 1.8 }, speed = { 14, 22 }, spread = 18, grav = -6, drag = 1.2, spin = 360 })
	end
end
SIG.leap = function(s)
	cracks(s.pos, s.r * 1.1, 6, PINK)
	burst(s.pos, { tex = Tex.petal, colors = { PINK, WHITE, C(255, 120, 180) }, n = 24, size = 1.5, life = { 1.4, 2.2 }, speed = { 24, 40 }, spread = 25, grav = -10, drag = 1.2, spin = 360 })
end
-- Bramble Brute
SIG.hedges = function(s, _, floor)
	for _, p in along(s, 9, 6) do
		K.kick(p, s.width * 0.6, 3, LEAF, 0.9)
		burst(p, { tex = Tex.leaf, colors = { LEAF, C(110, 176, 67) }, n = 5, size = 1.2, life = { 0.7, 1.1 }, speed = { 10, 18 }, spread = 40, grav = -25 })
	end
	local _ = floor
end
SIG.combo = function(s)
	cracks(s.pos, s.r, 4, C(255, 110, 80))
end
SIG.safe = function(s)
	-- Pollen Bomb: a mushroom of pollen; Titan's Gaze (also a "safe" shape) has its own below
	burst(s.pos, { tex = Tex.glow, colors = { POLLEN, C(255, 246, 180) }, n = 26, size = 3, endSize = 1.6, life = { 1, 1.6 }, speed = { 18, 30 }, spread = 14, grav = -6, drag = 1.6, add = true })
	burst(s.pos + Vector3.new(0, 10, 0), { tex = Tex.smoke, colors = { POLLEN, C(240, 220, 140) }, n = 12, size = 5, endSize = 1.4, life = { 1, 1.6 }, speed = { 6, 12 }, spread = 90, grav = -2, drag = 2.5 })
end
-- Bog Strangler
local gridN = 0
SIG.grid = function(s)
	gridN += 1
	if gridN % 3 ~= 0 then
		return -- (dozens of tiles at once: a spout on every third)
	end
	burst(s.pos, { tex = Tex.bubble, colors = { C(160, 230, 255), SLIME }, n = 8, size = 1, life = { 0.6, 1 }, speed = { 26, 40 }, spread = 8, grav = -60, add = true })
end
SIG.bounce = function(s)
	splat(s.pos, s.r * 0.8, SLIME, 3)
end
SIG.turrets = function(s)
	splat(s.pos, s.r * 0.8, SLIME, 2.5)
end
SIG.stalk = function(s)
	spears(s.pos, s.r, if PHONE then 3 else 5, C(60, 110, 50), Enum.Material.Grass, 5, C(150, 255, 100))
end
-- Frost Thornback
SIG.cone = function(s)
	crescent(s.pos, s.dir, s.r, s.half, ICE, WHITE, 0.18)
	cracks(s.pos, s.r * 0.6, 4, ICE, C(70, 110, 140), s.dir, s.half)
end
SIG.sink = function(s)
	K.floorRing(s.pos, K.RING_THIN, ICE, s.r * 0.5, s.r * 2.2, 0.5, 0, 0.18)
end
SIG.burrow = function(s)
	cracks(s.pos, s.r * 1.2, 7, ICE, C(60, 100, 130))
end
-- Hollow Harvest
SIG.swing = function(s)
	crescent(s.pos, s.dir, s.r, s.half, EMBER, C(255, 220, 140), 0.12)
end
SIG.mines = function(s)
	fireRing(s.pos, s.r)
end
SIG.boom = function(s)
	fireRing(s.pos, s.r)
end
SIG.dash = function(s)
	streak(s.pos, s.dir, s.length, s.width, FIRE, C(40, 24, 20))
	for _, p in along(s, 8, 6) do
		burst(p, { tex = Tex.flame, colors = { C(255, 220, 120), FIRE, EMBER }, n = 4, size = 2, endSize = 0.3, life = { 0.4, 0.8 }, speed = { 4, 10 }, spread = 30, grav = 10, add = true })
	end
end
SIG.mark = function(s)
	rune(s.pos, s.r, EMBER, 0.9)
	stab(s.pos, 18, C(255, 150, 60))
end
-- Jungle Titan
SIG.star = function(s)
	cracks(s.pos, s.length * 0.5, 2, RUNE_C, C(50, 56, 46), s.dir, 0.12)
end
SIG.meteors = function(s)
	rune(s.pos, s.r * 0.8, RUNE_C, 0.6)
end
SIG.pillars = function(s)
	K.kick(s.pos, s.r * 1.5, 6, STONE, 1.1)
end
SIG.laser = function(s)
	streak(s.pos, s.dir, s.length, s.width, RUNE_C, C(30, 60, 55))
end
SIG.gaze = function(s)
	rune(s.pos, s.r * 0.5, RUNE_C, 1.2)
end

-- One shape of a move landing (client/BossVfx.impact calls this after its own burst).
function BossMoveFx.play(kind: string, s: any, accent: Color3, floor: Color3)
	local f = SIG[kind]
	if not f or not s or typeof(s.pos) ~= "Vector3" then
		return
	end
	local ok, err = pcall(f, s, accent, floor)
	if not ok then
		warn("[BossMoveFx] " .. kind .. ": " .. tostring(err))
	end
end

return BossMoveFx
