-- Boss effects (client only), from the owner's VFX_Spec.md (data in client/BossVfxSpec):
--   * each boss's own particles (pollen, seeds, bees, petals, sand, chaff, embers, spores, runes ...), glowing halos
--     and lights on its att_* points, following the animated model; the rage form multiplies the rates, swaps the
--     colours and switches on its rage-only effects
--   * the shared aura: a glow on the ground under it and motes rising round its base
--   * ground warnings for every move (red disc + dashed ring that turns, filling up until the hit; rings and long
--     strips too) and the impacts: dust burst in the boss's dust colours, a shockwave ring, VFX Forge rocks
--   * the weak spot glowing while the boss is open, and the juice boxes (heals)
--   * round 2 (owner, 26 Oct): projectiles arcing out of the boss onto their warning circles (seeds, bees, sand,
--     straw, petals, slime, embers, runes), and the patches that stay on the floor (thorns, sand traps, fire,
--     slime / ember / rune pools)
-- Counts follow VFXLib's Budget (phones get fewer); at most 3 PointLights per boss.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local BossMoves = require(Shared:WaitForChild("BossMoves"))
local Tex = table.clone(require(Shared:WaitForChild("BossFxIds")) :: { [string]: string })
-- (owner, 29 Oct, of the white dandelion seeds round the Dandelion King: "white parts are still there with the boss";
-- the flat seed sprite with its hair-thin lines was "very low quality") every seed in the fights is soft glowing
-- fluff instead, as in the films (client/FilmVfx): the round glow, about half the size, lit a little from within
Tex.seed = Tex.glow
local SEED_SIZE = 0.55
local Spec = require(script.Parent.BossVfxSpec)
local PHONE = require(script.Parent.PhonePerf).on -- phones: lighter hits (owner, 26 Oct)
local BossView = require(script.Parent.BossView)
local Sound = require(script.Parent.Sound)
local SoundConfig = require(Shared:WaitForChild("Config")) -- (29 Oct) boss move cues

local VFXLib = ReplicatedStorage:WaitForChild("VFXLib", 10)
local Budget = VFXLib and (require((VFXLib :: Instance):WaitForChild("Budget")) :: any)
local Assets = VFXLib and (require((VFXLib :: Instance):WaitForChild("Assets")) :: any)
local Forge = VFXLib and (require((VFXLib :: Instance):WaitForChild("Forge")) :: any)

local BossVfx = {}
BossVfx.shake = nil :: ((number, number) -> ())? -- client/Fx plugs its camera shake in here

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "BossVfx"
folder.Parent = workspace

local KIT = 2.2 -- the spec's studs are the design kit's (its boss was 1/KIT of the model's units)

local function hex(h: string): Color3
	local ok, c = pcall(Color3.fromHex, h)
	return if ok then c else Color3.new(1, 1, 1)
end

local function colors(list: { string }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(hex(list[1]))
	end
	local keys = {}
	for i, h in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), hex(h)))
	end
	return ColorSequence.new(keys)
end

local function rate(r: number): number
	return if Budget then Budget.Rate(r) else r
end

local function count(n: number): number
	return if Budget then Budget.Count(n) else n
end

local function host(name: string, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.one * 0.2
	p.Parent = folder
	return p
end

-------------------------------------------------------------------------------------------------------------
-- the boss's own effects
-------------------------------------------------------------------------------------------------------------
type Em = { e: ParticleEmitter, def: any, host: Part, at: string, base: number, wobble: boolean, phase: number, orbit: number? }
type Glow = { gui: BillboardGui, img: ImageLabel, def: any, host: Part, at: string, size: number, phase: number }
type Light = { light: PointLight, def: any, host: Part, at: string }

local live: any = nil

local function makeEmitter(def: any, k: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	-- (30 Oct) a sprite from shared/BossFxIds, or one of VFXLib's (Star4, RingThin, SmokePuff4x4 ... by name)
	e.Texture = Tex[def.tex] or (Assets and Assets[def.tex]) or Tex.dot
	if def.flip then
		pcall(function()
			e.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[def.flip]
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end)
	end
	e.LightEmission = if def.add then 1 elseif def.tex == "seed" then 0.45 else 0
	e.LightInfluence = if def.add then 0 else 1
	e.Brightness = if def.add then 1.4 else 1
	e.Lifetime = NumberRange.new(def.life[1], def.life[2])
	local fluff = if def.tex == "seed" then SEED_SIZE else 1
	local a, b = def.size[1] * k * fluff, def.size[2] * k * fluff
	local avg, env = (a + b) / 2, (b - a) / 2
	if def.twinkle then
		-- a glint: pops up to full size partway through its life and shrinks away
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, avg, env), NumberSequenceKeypoint.new(1, 0) })
	elseif def.grow then
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, avg * def.grow[1], env), NumberSequenceKeypoint.new(1, avg * def.grow[2], env) })
	else
		local endK = def.size[3] or 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, avg, env), NumberSequenceKeypoint.new(1, avg * endK, env * endK) })
	end
	local alpha = def.alpha or 1
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 1 - alpha),
		NumberSequenceKeypoint.new(0.75, 1 - alpha * 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = colors(def.colors)
	e.Speed = NumberRange.new(def.speed[1] * k, def.speed[2] * k)
	e.EmissionDirection = if def.dir == "down" then Enum.NormalId.Bottom elseif def.dir == "side" then Enum.NormalId.Front else Enum.NormalId.Top
	local spread = def.spread or 20
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = (def.accel or Vector3.zero) * k
	e.Drag = def.drag or 0
	local spin = math.deg(def.spin or 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-spin, spin)
	e.LockedToPart = false
	if def.box then
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end
	return e
end

local function emitterHosts(v: any, def: any, k: number, out: { Em })
	local names: { string }
	if def.at:sub(1, 4) == "att_" then
		names = BossView.attAll(def.at)
	else
		names = { def.at }
	end
	local hosts = if def.at == "orbit" then 4 else #names
	for i = 1, hosts do
		local name = names[math.min(i, #names)] or def.at
		local size = if def.box then def.box * k else Vector3.one * 0.2
		if def.at == "ring" then
			size = Vector3.new(0.2, def.radius[2] * 2 * k, def.radius[2] * 2 * k)
		end
		local h = host("Em_" .. def.tex, size)
		local e = makeEmitter(def, k)
		if def.at == "ring" then
			e.Shape = Enum.ParticleEmitterShape.Disc
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.ShapePartial = 1 - def.radius[1] / def.radius[2]
		end
		local base = def.rate / (if def.at == "orbit" then 4 else 1)
		e.Rate = if def.rage == "only" then 0 else rate(base)
		e.Parent = h
		table.insert(out, { e = e, def = def, host = h, at = name, base = base, wobble = def.wobble == true, phase = math.random() * 10, orbit = if def.at == "orbit" then (i - 1) / 4 * math.pi * 2 else nil })
	end
end

local function glowHosts(def: any, k: number, out: { Glow })
	for _, name in BossView.attAll(def.at) do
		local h = host("Glow")
		local gui = Instance.new("BillboardGui")
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Size = UDim2.fromScale(def.size * k, def.size * k)
		gui.Adornee = h
		gui.Enabled = not def.rageOnly
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = Tex.glow
		img.ImageColor3 = hex(def.color)
		img.ImageTransparency = 1 - (def.alpha or 0.7)
		img.Parent = gui
		gui.Parent = h
		table.insert(out, { gui = gui, img = img, def = def, host = h, at = name, size = def.size * k, phase = math.random() * 6 })
	end
end

local function lightHosts(def: any, k: number, out: { Light })
	if #out >= 3 then
		return
	end
	local names = BossView.attAll(def.at)
	if #names == 0 then
		return
	end
	local h = host("Light")
	local l = Instance.new("PointLight")
	l.Color = hex(def.color)
	l.Brightness = def.brightness or 1
	l.Range = 14 * k
	l.Shadows = false
	l.Enabled = not def.rageOnly
	l.Parent = h
	table.insert(out, { light = l, def = def, host = h, at = names[1] })
end

-- the shared aura: a glow on the ground, a darker pool, motes rising round the base
local function aura(v: any, accent: Color3, k: number)
	local foot = math.max(v.rig.bounds[2][1], v.rig.bounds[2][3]) * v.scale
	local pool = host("AuraPool", Vector3.new(foot * 3.2, 0.05, foot * 3.2))
	local d1 = Instance.new("Decal")
	d1.Face = Enum.NormalId.Top
	d1.Texture = Tex.glow
	d1.Color3 = accent:Lerp(Color3.new(0, 0, 0), 0.75)
	d1.Transparency = 0.45
	d1.Parent = pool
	local glow = host("AuraGlow", Vector3.new(foot * 2.4, 0.05, foot * 2.4))
	local d2 = Instance.new("Decal")
	d2.Face = Enum.NormalId.Top
	d2.Texture = Tex.glow
	d2.Color3 = accent
	d2.Transparency = 0.68
	d2.Parent = glow
	local motesHost = host("AuraMotes", Vector3.new(0.4, foot * 1.9, foot * 1.9))
	local m = Instance.new("ParticleEmitter")
	m.Texture = Tex.dot
	m.LightEmission = 1
	m.LightInfluence = 0
	m.Shape = Enum.ParticleEmitterShape.Disc
	m.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	m.EmissionDirection = Enum.NormalId.Top
	m.Lifetime = NumberRange.new(Spec.shared.moteLife[1], Spec.shared.moteLife[2])
	m.Speed = NumberRange.new(1.5 * k, 3 * k)
	m.SpreadAngle = Vector2.new(12, 12)
	m.Size = NumberSequence.new(0.45 * k, 0)
	m.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(1, 0.6) })
	m.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
	m.Rate = rate(Spec.shared.moteRate)
	m.Parent = motesHost
	-- (30 Oct, owner: "make them look cool and high quality") a rune circle and a thin ring turning on the floor under
	-- it, glints rising with the motes, and (not on phones) a faint column of energy going up through it
	local function floorDecal(name: string, size: number, tex: string?, color: Color3, t: number): (Part, Decal)
		local p = host(name, Vector3.new(size, 0.05, size))
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = tex or Tex.glow
		d.Color3 = color
		d.Transparency = t
		d.Parent = p
		return p, d
	end
	local rune, runeDecal = floorDecal("AuraRune", foot * 2.1, Assets and Assets.RuneCircle, accent, 0.55)
	local ring, ringDecal = floorDecal("AuraRing", foot * 2.9, Assets and Assets.RingThin, accent, 0.45)
	local glint = Instance.new("ParticleEmitter")
	glint.Texture = (Assets and Assets.Star4) or Tex.spark
	glint.LightEmission = 1
	glint.LightInfluence = 0
	glint.Shape = Enum.ParticleEmitterShape.Disc
	glint.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	glint.EmissionDirection = Enum.NormalId.Top
	glint.Lifetime = NumberRange.new(1.2, 2.2)
	glint.Speed = NumberRange.new(2 * k, 4.5 * k)
	glint.SpreadAngle = Vector2.new(8, 8)
	glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.9 * k, 0.3 * k), NumberSequenceKeypoint.new(1, 0) })
	glint.Rotation = NumberRange.new(0, 360)
	glint.RotSpeed = NumberRange.new(-90, 90)
	glint.Color = ColorSequence.new(Color3.new(1, 1, 1), accent)
	glint.Rate = rate(5)
	glint.Parent = motesHost
	local column, beam
	if not PHONE then
		column = host("AuraColumn")
		local a0 = Instance.new("Attachment")
		a0.Parent = column
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, v.height * 1.25, 0)
		a1.Parent = column
		beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Texture = (Assets and Assets.EnergyNoise) or Tex.smoke
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = 0.35
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Width0 = foot * 1.7
		beam.Width1 = foot * 0.6
		beam.Segments = 1
		beam.Color = ColorSequence.new(accent)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1) })
		beam.Parent = column
	end
	return { pool = pool, glow = glow, glowDecal = d2, motes = m, motesHost = motesHost, glint = glint,
		rune = rune, runeDecal = runeDecal, ring = ring, ringDecal = ringDecal, column = column, beam = beam, spin = 0 }
end

-- (30 Oct) the rage burst, once as the rage form breaks out: a white flash, a shockwave ring racing out over the floor,
-- sparks, glints and a puff of dark smoke
local function rageBurst(v: any, accent: Color3, k: number)
	local base: CFrame? = v.base
	if not base then
		return
	end
	local feet = base.Position
	local chest = feet + Vector3.new(0, v.height * 0.55, 0)
	local foot = math.max(v.rig.bounds[2][1], v.rig.bounds[2][3]) * v.scale
	local fire = Color3.fromRGB(255, 96, 48)
	-- the shockwave on the floor
	local wave = host("RageWave", Vector3.new(foot, 0.05, foot))
	wave.CFrame = CFrame.new(feet + Vector3.new(0, 0.12, 0))
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = (Assets and Assets.RingShock) or Tex.glow
	d.Color3 = fire
	d.Transparency = 0.05
	d.Parent = wave
	TweenService:Create(wave, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(foot * 7, 0.05, foot * 7) }):Play()
	TweenService:Create(d, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	-- the burst itself
	local h = host("RageBurst")
	h.CFrame = CFrame.new(chest)
	local function burst(tex: string?, n: number, life: { number }, size: NumberSequence, speed: { number }, color: ColorSequence, add: boolean, extra: ((ParticleEmitter) -> ())?)
		local e = Instance.new("ParticleEmitter")
		e.Texture = tex or Tex.dot
		e.LightEmission = if add then 1 else 0
		e.LightInfluence = if add then 0 else 1
		e.Lifetime = NumberRange.new(life[1], life[2])
		e.Size = size
		e.Speed = NumberRange.new(speed[1] * k, speed[2] * k)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-120, 120)
		e.Color = color
		e.Rate = 0
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) })
		if extra then
			extra(e)
		end
		e.Parent = h
		e:Emit(count(n))
	end
	burst(Tex.glow, 3, { 0.18, 0.28 }, NumberSequence.new(foot * 0.6, foot * 2.2), { 0, 0 }, ColorSequence.new(Color3.new(1, 1, 1), fire), true)
	burst((Assets and Assets.Spark) or Tex.spark, 40, { 0.5, 0.9 }, NumberSequence.new(0.9 * k, 0), { 18, 40 }, ColorSequence.new(Color3.fromRGB(255, 220, 120), fire), true, function(e)
		e.Drag = 3
		e.Acceleration = Vector3.new(0, -12 * k, 0)
	end)
	burst((Assets and Assets.SmokePuff4x4) or Tex.smoke, 10, { 0.9, 1.4 }, NumberSequence.new(3 * k, 7 * k), { 4, 10 }, ColorSequence.new(Color3.fromRGB(40, 24, 30), Color3.fromRGB(70, 40, 40)), false, function(e)
		e.Drag = 2.5
		pcall(function()
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end)
	end)
	burst((Assets and Assets.Star4) or Tex.spark, 14, { 0.4, 0.8 }, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2.4 * k), NumberSequenceKeypoint.new(1, 0) }), { 6, 16 }, ColorSequence.new(accent, Color3.new(1, 1, 1)), true)
	Debris:AddItem(wave, 1)
	Debris:AddItem(h, 2)
end

function BossVfx.start(z: number, arenaCentre: Vector3?)
	BossVfx.stop()
	local v = BossView.get()
	if not v then
		return
	end
	local spec = Spec.bosses[v.style or v.rigName] or Spec.bosses[v.rigName]
	if not spec then
		return
	end
	local k = v.scale / KIT
	BossVfx.setStyle(v.style or v.rigName)
	local L = { z = z, k = k, spec = spec, ems = {} :: { Em }, glows = {} :: { Glow }, lights = {} :: { Light }, rage = false, t = 0, arena = arenaCentre, stones = nil :: any }
	local accent = hex(spec.accent)
	L.aura = aura(v, accent, k)
	for _, def in spec.emitters do
		emitterHosts(v, def, k, L.ems)
	end
	for _, def in spec.glows or {} do
		glowHosts(def, k, L.glows)
	end
	for _, def in spec.lights or {} do
		lightHosts(def, k, L.lights)
	end
	live = L
end

function BossVfx.stop()
	if live then
		for _, e in live.ems do
			e.host:Destroy()
		end
		for _, g in live.glows do
			g.host:Destroy()
		end
		for _, l in live.lights do
			l.host:Destroy()
		end
		if live.aura then
			live.aura.pool:Destroy()
			live.aura.glow:Destroy()
			live.aura.motesHost:Destroy()
			live.aura.rune:Destroy()
			live.aura.ring:Destroy()
			if live.aura.column then
				live.aura.column:Destroy()
			end
		end
		if live.stones then
			for _, s in live.stones do
				s:Destroy()
			end
		end
		live = nil
	end
end

-- The rage form: rates up, colours swap, rage-only effects on, lights and glows blend over 0.3 s.
function BossVfx.setRage(on: boolean)
	local L = live
	if not L or L.rage == on then
		return
	end
	L.rage = on
	for _, em in L.ems do
		local d = em.def
		local mult = if d.rage == "only" then (if on then 1 else 0) elseif type(d.rage) == "number" and on then d.rage else 1
		em.e.Rate = rate(em.base * mult)
		if d.rageColors then
			em.e.Color = colors(if on then d.rageColors else d.colors)
		end
		if on and d.rage == "only" then
			em.e:Emit(count(8))
		end
	end
	for _, g in L.glows do
		local d = g.def
		g.gui.Enabled = (not d.rageOnly) or on
		if d.rageColor then
			TweenService:Create(g.img, TweenInfo.new(0.3), { ImageColor3 = hex(if on then d.rageColor else d.color) }):Play()
		end
		g.size = d.size * L.k * (if on then d.rageSize or 1 else 1)
	end
	for _, l in L.lights do
		local d = l.def
		l.light.Enabled = (not d.rageOnly) or on
		TweenService:Create(l.light, TweenInfo.new(0.3), {
			Color = hex(if on and d.rageColor then d.rageColor else d.color),
			Brightness = if on then d.rageBrightness or d.brightness or 1 else d.brightness or 1,
		}):Play()
	end
	if L.aura then
		L.aura.motes.Rate = rate(Spec.shared.moteRate * (if on then Spec.shared.moteRage else 1))
		local accent = hex(L.spec.accent)
		L.aura.motes.Color = if on then ColorSequence.new(hex(Spec.shared.rageMote), accent) else ColorSequence.new(accent, Color3.new(1, 1, 1))
		-- (30 Oct) the floor runes and the column burn rage-red, and the glints come faster
		local col = if on then hex(Spec.shared.rageMote) else accent
		TweenService:Create(L.aura.runeDecal, TweenInfo.new(0.4), { Color3 = col, Transparency = if on then 0.3 else 0.55 }):Play()
		TweenService:Create(L.aura.ringDecal, TweenInfo.new(0.4), { Color3 = col }):Play()
		L.aura.glint.Rate = rate(if on then 12 else 5)
		L.aura.glint.Color = ColorSequence.new(Color3.new(1, 1, 1), col)
		if L.aura.beam then
			L.aura.beam.Color = ColorSequence.new(col)
		end
		if on then
			local v = BossView.get()
			if v then
				rageBurst(v, accent, L.k)
			end
		end
	end
	-- the Jungle Titan's temple stones
	local st = L.spec.stones
	if on and st and not L.stones then
		L.stones = {}
		for i = 1, st.count do
			local s = Instance.new("Part")
			s.Name = "TempleStone"
			s.Anchored = true
			s.CanCollide = false
			s.CanQuery = false
			s.Material = Enum.Material.Slate
			s.Color = Color3.fromRGB(120, 130, 110)
			s.Size = Vector3.one * st.size * L.k * 1.6
			s:SetAttribute("Phase", (i - 1) / st.count * math.pi * 2)
			s.Parent = folder
			table.insert(L.stones, s)
		end
	end
end

-- per frame (called by client/BossCine's heartbeat after BossView moved the model)
local function update(dt: number)
	local L = live
	local v = BossView.get()
	if not L or not v or not v.base then
		return
	end
	L.t += dt
	local base: CFrame = v.base
	local up = base.Rotation
	local k = L.k
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	local function put(p: BasePart, cf: CFrame)
		table.insert(parts, p)
		table.insert(cfs, cf)
	end
	local feet = base.Position
	local floorY = feet.Y
	for _, em in L.ems do
		local d = em.def
		local pos: Vector3
		if d.at == "sky" then
			pos = feet + Vector3.new(0, ((d.y1 or 24) - (d.box and d.box.Y or 0) / 2) * k, 0)
		elseif d.at == "base" then
			pos = feet + Vector3.new(0, (d.y0 or 1) * k, 0)
		elseif d.at == "arena" then
			pos = (L.arena or feet) + Vector3.new(0, (d.y0 or 4) * k, 0)
		elseif d.at == "ring" then
			pos = Vector3.new(feet.X, floorY + 0.4, feet.Z)
		elseif d.at == "orbit" then
			em.orbit = (em.orbit or 0) + dt * (d.orbitSpeed or 8) / (d.radius[1] * k)
			local r = (d.radius[1] + d.radius[2]) / 2 * k
			local h = (d.high[1] + math.random() * (d.high[2] - d.high[1])) * k
			pos = feet + Vector3.new(math.cos(em.orbit :: number) * r, h, math.sin(em.orbit :: number) * r)
		else
			pos = BossView.attWorld(em.at) or feet
		end
		local cf = if d.at == "ring" then CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) else CFrame.new(pos) * up
		put(em.host, cf)
		if em.wobble then
			local t = L.t + em.phase
			em.e.Acceleration = (d.accel or Vector3.zero) * k + Vector3.new(math.sin(t * 3.1), math.cos(t * 2.3) * 0.6, math.sin(t * 2.7 + 1)) * 6 * k
		end
	end
	for _, g in L.glows do
		local pos = BossView.attWorld(g.at)
		if pos then
			put(g.host, CFrame.new(pos))
		end
		local d = g.def
		local s = g.size * (1 + (d.pulse or 0) * math.sin(L.t * (d.rate or 2) + g.phase))
		g.gui.Size = UDim2.fromScale(s, s)
	end
	for _, l in L.lights do
		local pos = BossView.attWorld(l.at)
		if pos then
			put(l.host, CFrame.new(pos))
		end
		local d = l.def
		if d.flicker then
			local b = if L.rage then d.rageBrightness or d.brightness or 1 else d.brightness or 1
			l.light.Brightness = b * (1 + (math.random() - 0.5) * 2 * d.flicker)
		end
	end
	if L.aura then
		local flatCf = CFrame.new(feet.X, floorY + 0.07, feet.Z)
		put(L.aura.pool, flatCf - Vector3.new(0, 0.02, 0))
		put(L.aura.glow, flatCf)
		put(L.aura.motesHost, CFrame.new(feet.X, floorY + 0.3, feet.Z) * CFrame.Angles(0, 0, math.rad(90)))
		L.aura.glowDecal.Transparency = 0.68 + 0.06 * math.sin(L.t * 2)
		L.aura.spin += dt * (if L.rage then 0.9 else 0.3)
		put(L.aura.rune, CFrame.new(feet.X, floorY + 0.09, feet.Z) * CFrame.Angles(0, L.aura.spin, 0))
		put(L.aura.ring, CFrame.new(feet.X, floorY + 0.08, feet.Z) * CFrame.Angles(0, -L.aura.spin * 1.6, 0))
		if L.aura.column then
			put(L.aura.column, CFrame.new(feet.X, floorY + 0.2, feet.Z))
		end
	end
	if L.stones then
		local st = L.spec.stones
		for _, s in L.stones do
			local a = s:GetAttribute("Phase") + L.t * 0.6
			local pos = feet + Vector3.new(math.cos(a) * st.radius * k, st.high * k + math.sin(L.t * 1.3 + a) * k, math.sin(a) * st.radius * k)
			put(s, CFrame.new(pos) * CFrame.Angles(L.t * 0.9 + a, L.t * 1.3, a))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(update, dt)
	if not ok then
		warn("[BossVfx] " .. tostring(err))
	end
end)

-------------------------------------------------------------------------------------------------------------
-- ground warnings
-------------------------------------------------------------------------------------------------------------
local RED = Color3.fromRGB(255, 46, 46) -- the warning fill (each boss's own red, setStyle)
local RING_RED = Color3.fromRGB(255, 59, 59) -- the turning dashes / outlines (the boss's colour)
local PX = 6 -- canvas pixels per stud

-------------------------------------------------------------------------------------------------------------
-- each boss's own look for its attacks (owner, 26 Oct: "each boss has to have its unique pattern and effects"):
-- the warnings carry its colour and a pattern of its own (seeds, leaves, sand, straw, petals, bubbles, flames,
-- runes), and every hit bursts its own way (seed fluff, thorn spikes, sand geysers, chaff and feathers, petal
-- blooms, slime splashes, ember blasts, rune shards)
-------------------------------------------------------------------------------------------------------------
local STYLE: { [string]: { tex: string, accent: string, fx: string, warn: string } } = {
	dandelion = { tex = "seed", accent = "FFE46A", fx = "fluff", warn = "FF5A3C" },
	bramble = { tex = "leaf", accent = "FF4D6D", fx = "thorns", warn = "E0284A" },
	bunker = { tex = "sand", accent = "FFE14D", fx = "geyser", warn = "FF7A1A" },
	frost = { tex = "sand", accent = "9FE8FF", fx = "geyser", warn = "3FA0FF" }, -- (29 Oct) the Frost Thornback
	harvest = { tex = "strand", accent = "F0C850", fx = "chaff", warn = "E8501E" },
	sakura = { tex = "petal", accent = "FF9FCD", fx = "bloom", warn = "FF3D8B" },
	bog = { tex = "bubble", accent = "9DFF5A", fx = "splash", warn = "C8E62A" },
	hollow = { tex = "flame", accent = "FFB060", fx = "embers", warn = "FF4A00" },
	jungle = { tex = "glyph", accent = "3FFFD0", fx = "runes", warn = "FF3355" },
}
local style = STYLE.dandelion

local function setStyle(rig: string?)
	style = (rig and STYLE[rig]) or STYLE.dandelion
	RED = hex(style.warn)
	RING_RED = hex(style.accent)
end

BossVfx.setStyle = setStyle -- (BossVfx.start, above, calls it through here)

local function warnColor(): Color3
	return hex(style.warn)
end

local function accentColor(): Color3
	return hex(style.accent)
end

-- the boss's pattern laid over a warning (tiled, faint, clipped round when `round`)
local function motif(g: Instance, round: boolean?)
	local img = Instance.new("ImageLabel")
	img.Name = "Motif"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Tex[style.tex] or Tex.dot
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(5 * 6, 5 * 6)
	img.ImageColor3 = accentColor()
	img.ImageTransparency = 0.72
	img.ZIndex = 2
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = img
	end
	img.Parent = g
	return img
end


local function canvas(pos: Vector3, w: number, h: number, yaw: number?): (Part, SurfaceGui)
	local p = host("Telegraph", Vector3.new(w, 0.05, h))
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, yaw or 0, 0)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PX
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	g.Parent = p
	return p, g
end

local function disc(parent: Instance, d: number, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(d, d)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

-- 18 dashes round a circle of diameter d px, in a holder that turns
local function dashes(parent: Instance, d: number, color: Color3): Frame
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(d, d)
	holder.BackgroundTransparency = 1
	local n = 18
	local len = math.pi * d / n * 0.55
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2
		local dash = Instance.new("Frame")
		dash.AnchorPoint = Vector2.new(0.5, 0.5)
		dash.Size = UDim2.fromOffset(len, math.max(3, d * 0.022))
		dash.Position = UDim2.new(0.5, math.cos(a) * d / 2, 0.5, math.sin(a) * d / 2)
		dash.Rotation = math.deg(a) + 90
		dash.BackgroundColor3 = color
		dash.BackgroundTransparency = 0.1
		dash.BorderSizePixel = 0
		dash.Parent = holder
	end
	holder.Parent = parent
	return holder
end

type Warn = { part: Part, start: number, land: number, spin: Frame?, spin2: Frame?, fill: Frame?, fillStroke: UIStroke?, fade: { Frame } }
local warns: { Warn } = {}

local function circleWarn(s: any, start: number): Warn
	local d = s.r * 2
	local p, g = canvas(s.pos, d + 2, d + 2)
	local px = d * PX
	local base = disc(g, px, RED, 0.72)
	local fill = disc(g, 0, RED, 0.55)
	local spin = dashes(g, px, RING_RED)
	local m = motif(g, true)
	m.Size = UDim2.fromOffset(px, px)
	m.AnchorPoint = Vector2.new(0.5, 0.5)
	m.Position = UDim2.fromScale(0.5, 0.5)
	return { part = p, start = start, land = s.land, spin = spin, fill = fill, fade = { base, spin } }
end

local function ringWarn(s: any, start: number): Warn
	local d = s.outer * 2
	local p, g = canvas(s.pos, d + 2, d + 2)
	local band = (s.outer - s.inner) * PX
	local mid = (s.outer + s.inner) * PX
	local f = disc(g, mid, RED, 1)
	local st = Instance.new("UIStroke")
	st.Color = RED
	st.Thickness = band
	st.Transparency = 0.72
	st.Parent = f
	local f2 = disc(g, s.outer * 2 * PX - 2, RED, 1)
	local st2 = Instance.new("UIStroke")
	st2.Color = RED
	st2.Thickness = 0
	st2.Transparency = 0.5
	st2.Parent = f2
	local spin = dashes(g, s.outer * 2 * PX, RING_RED)
	local spin2 = dashes(g, s.inner * 2 * PX, RING_RED)
	return { part = p, start = start, land = s.land, spin = spin, spin2 = spin2, fillStroke = st2, band = band, fade = { spin, spin2 } } :: any
end

local function stripWarn(s: any, start: number): Warn
	local dir = s.dir
	local mid = s.pos + dir * (s.length / 2)
	local yaw = math.atan2(dir.X, dir.Z)
	local p, g = canvas(mid, s.width, s.length, yaw)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = RED
	f.BackgroundTransparency = 0.72
	f.BorderSizePixel = 0
	local st = Instance.new("UIStroke")
	st.Color = RING_RED
	st.Thickness = 4
	st.Transparency = 0.1
	st.Parent = f
	f.Parent = g
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1) -- the canvas's bottom edge is the boss's end (Top face: -Z up the canvas)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = RED
	fill.BackgroundTransparency = 0.55
	fill.BorderSizePixel = 0
	fill.Parent = g
	motif(g)
	return { part = p, start = start, land = s.land, fill = fill, strip = true, fade = { f } } :: any
end

-- a flat coloured panel on the floor, turned so its length runs along world `dir` (each piece its own part, so the
-- drawing can't come out mirrored or turned)
local function panel(pos: Vector3, w: number, len: number, dir: Vector3?, color: Color3, tr: number, dy: number?): (Part, Frame)
	local yaw = if dir then math.atan2(dir.X, dir.Z) else 0
	local p, g = canvas(pos + Vector3.new(0, dy or 0, 0), w, len, yaw)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = tr
	f.BorderSizePixel = 0
	f.Parent = g
	return p, f
end

-- a pie slice (rake swipe, scythe arc): thin wedges fanned out from the boss
local function sectorWarn(s: any, start: number): Warn
	local half = s.half
	local n = math.max(3, math.ceil(math.deg(half * 2) / 6))
	local base = math.atan2(s.dir.X, s.dir.Z)
	local parts, frames = {}, {}
	for i = 1, n do
		local a = base - half + (i - 0.5) / n * half * 2
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local w = 2 * s.r * math.tan(half / n) + 0.4
		local p, f = panel(s.pos + dir * (s.r / 2), w, s.r, dir, RED, 0.8, i * 0.002)
		table.insert(parts, p)
		table.insert(frames, f)
	end
	local main = parts[1]
	for i = 2, #parts do
		parts[i].Parent = main -- one part to remove when it lands
	end
	return {
		part = main,
		start = start,
		land = s.land,
		fade = {},
		update = function(u, a)
			for _, f in frames do
				f.BackgroundTransparency = 1 - (0.2 + 0.4 * u) * a
			end
		end,
	} :: any
end

-- a floor tile (geyser field)
local function squareWarn(s: any, start: number): Warn
	local p, g = canvas(s.pos, s.size, s.size, s.yaw)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = RED
	f.BackgroundTransparency = 0.75
	f.BorderSizePixel = 0
	local st = Instance.new("UIStroke")
	st.Color = RING_RED
	st.Thickness = 3
	st.Transparency = 0.2
	st.Parent = f
	f.Parent = g
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(0, 0)
	fill.BackgroundColor3 = RED
	fill.BackgroundTransparency = 0.5
	fill.BorderSizePixel = 0
	fill.Parent = g
	motif(g)
	return {
		part = p,
		start = start,
		land = s.land,
		fade = { f },
		update = function(u)
			fill.Size = UDim2.fromScale(u, u)
		end,
	} :: any
end

-- everything is hit except the safe spots (green) and the shadows behind pillars
local SAFE_GREEN = Color3.fromRGB(90, 255, 120)
local function safeWarn(s: any, start: number): Warn
	local d = s.r * 2
	local p, g = canvas(s.pos, d + 2, d + 2)
	local base = disc(g, d * PX, RED, 0.8)
	local m = motif(g, true)
	m.Size = UDim2.fromOffset(d * PX, d * PX)
	m.AnchorPoint = Vector2.new(0.5, 0.5)
	m.Position = UDim2.fromScale(0.5, 0.5)
	local greens = {}
	for _, c in s.safes or {} do
		local cp, cg = canvas(c.pos + Vector3.new(0, 0.03, 0), c.r * 2 + 2, c.r * 2 + 2)
		local f = disc(cg, c.r * 2 * PX, SAFE_GREEN, 0.35)
		local st = Instance.new("UIStroke")
		st.Color = Color3.new(1, 1, 1)
		st.Thickness = 4
		st.Parent = f
		cp.Parent = p
		table.insert(greens, f)
	end
	for _, sh in s.shadows or {} do
		local len = math.min(sh.length, s.r * 2)
		local sp, f = panel(sh.pos + sh.dir * (len / 2), sh.width, len, sh.dir, SAFE_GREEN, 0.45, 0.03)
		sp.Parent = p
		table.insert(greens, f)
	end
	return {
		part = p,
		start = start,
		land = s.land,
		fade = {},
		update = function(u, a)
			base.BackgroundTransparency = 1 - (0.15 + 0.45 * u) * a
			for _, f in greens do
				f.BackgroundTransparency = 1 - (0.6 + 0.3 * math.sin(os.clock() * 8)) * a
			end
		end,
	} :: any
end

RunService.RenderStepped:Connect(function(dt)
	local t = workspace:GetServerTimeNow()
	for i = #warns, 1, -1 do
		local w: any = warns[i]
		local u = (t - w.start) / math.max(0.05, w.land)
		if u >= 1 then
			w.part:Destroy()
			table.remove(warns, i)
		else
			local a = math.clamp(u * 3, 0, 1) -- fades in over the first third
			if w.spin then
				w.spin.Rotation += math.deg(0.6 * dt)
			end
			if w.spin2 then
				w.spin2.Rotation -= math.deg(0.6 * dt)
			end
			if w.fill then
				if w.strip then
					w.fill.Size = UDim2.fromScale(1, u)
				else
					local full = (w.part.Size.X - 2) * PX
					w.fill.Size = UDim2.fromOffset(full * u, full * u)
				end
			end
			if w.fillStroke then
				w.fillStroke.Thickness = w.band * u
			end
			if w.update then
				w.update(u, a)
			end
			for _, o in w.fade do
				local full = o:GetAttribute("Full")
				if full == nil then
					full = o.BackgroundTransparency
					o:SetAttribute("Full", full)
				end
				o.BackgroundTransparency = 1 - (1 - full) * a
				for _, c in o:GetChildren() do
					if c:IsA("Frame") then
						c.BackgroundTransparency = 1 - 0.9 * a
					end
				end
			end
		end
	end
end)

-- A move's warning shapes, from the server's message (times relative to msg.at).
function BossVfx.warn(msg: any)
	for _, s in msg.shapes do
		local w: Warn
		if s.type == "circle" then
			w = circleWarn(s, msg.at)
		elseif s.type == "ring" then
			w = ringWarn(s, msg.at)
		elseif s.type == "sector" then
			w = sectorWarn(s, msg.at)
		elseif s.type == "square" then
			w = squareWarn(s, msg.at)
		elseif s.type == "safe" then
			w = safeWarn(s, msg.at)
		else
			w = stripWarn(s, msg.at)
		end
		table.insert(warns, w)
	end
	-- a warning sound for the first shape near you
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and msg.shapes[1] and ((root.Position - msg.shapes[1].pos).Magnitude < 60 or msg.shapes[1].type == "safe") then
		Sound.play("warn", 0.05, 0.7)
	end
end

-------------------------------------------------------------------------------------------------------------
-- impacts
-------------------------------------------------------------------------------------------------------------
local function dust(pos: Vector3, radius: number, cols: { string }, n: number?)
	local h = host("Dust", Vector3.new(0.2, radius * 1.6, radius * 1.6))
	h.CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = Tex.smoke
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(radius * 1.2, radius * 2.6)
	e.Drag = 3.5
	e.Acceleration = Vector3.new(0, -3, 0)
	local s = radius * 0.32
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.5), NumberSequenceKeypoint.new(1, s * 1.4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Color = colors(cols)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = h
	e:Emit(count(n or 27))
	Debris:AddItem(h, 1.2)
end

local function shockwave(pos: Vector3, radius: number, color: Color3)
	local p = host("Shock", Vector3.new(radius * 0.6, 0.05, radius * 0.6))
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0))
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = if Assets then Assets.Tex.RingShock else Tex.glow
	d.Color3 = color
	d.Transparency = 0.65
	d.Parent = p
	local ti = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, ti, { Size = Vector3.new(radius * 3.8, 0.05, radius * 3.8) }):Play()
	TweenService:Create(d, ti, { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.6)
end

local lastShake = 0
local function shakeFor(pos: Vector3, power: number)
	if os.clock() - lastShake < 0.08 then
		return -- many shapes landing together (geyser field, star cracks): one shake
	end
	lastShake = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local d = (root.Position - pos).Magnitude
	if d < 90 then
		local k = 1 - d / 90
		if BossVfx.shake then
			BossVfx.shake(power * k, 0.35)
		end
	end
end

-- (owner, 29 Oct: "double check if every sound of every boss attack fits, dont keep copy and pasting the same
-- loud BOOM sound ... make it satisfying and minimal") Each move lands with its own short, soft cue, quieter
-- the further away you are; only the heavy moves (a slam, a leap, the quake) get the boss's real slam. Many
-- shapes landing together (a geyser field, a lob of seeds) make one sound, not a drum roll.
-- { key, pitch, volume, fallback key while the key isn't in Config.SOUNDS yet }
type Cue = { any }
local CUE: { [string]: Cue } = {
	slam = { "slam", 1.0, 0.55 }, -- Scepter Smash: the one real boom
	leap = { "slam", 1.12, 0.5 }, -- Blossom Leap
	star = { "slam", 0.9, 0.5 }, -- Temple Quake
	burrow = { "fellLand", 0.75, 0.6 }, -- Shell Ambush: the shell bursting up out of the sand
	combo = { "punch", 0.8, 0.5 }, -- Knuckle Combo: three meaty knuckle thumps
	cone = { "swingBlade", 0.75, 0.55 }, -- Rake Swipe
	sweep = { "lunge", 1.0, 0.55, "swingBlade" }, -- Snap Lunge (31 Oct: the owner's dash whoosh; was a low blade swish)
	swing = { "bladeSlash", 0.92, 0.5, "slice" }, -- Reaper Swing (31 Oct: the owner's katana slash, one per slice; was a slice)
	fan = { "slice", 1.05, 0.4 }, -- Pitchfork Thrust
	cross = { "bossWhomp", 0.9, 0.45, "burst" }, -- Royal Decree
	ring = { "bossWhomp", 1.05, 0.4, "burst" }, -- Petal Blizzard
	rings = { "bossWhomp", 0.95, 0.4, "burst" }, -- Crop Circles
	wave = { "rustle", 0.7, 0.5 }, -- Sand Wave
	hedges = { "fellCrunch", 0.9, 0.45 }, -- Hedge Rows
	safe = { "burst", 0.75, 0.5 }, -- Pollen Bomb: a soft pollen poof
	grid = { "burst", 1.2, 0.35 }, -- Geyser Field: bubbly pops
	tide = { "bossWhomp", 0.7, 0.45, "burst" }, -- Rising Bog
	laser = { "zapBeam", 1.0, 0.45, "bossZap" }, -- Rune Lasers (31 Oct: the owner's energy beam; was a zap)
	gaze = { "zapStrike", 0.95, 0.6, "bossZap" }, -- Titan's Gaze firing (31 Oct: the owner's lightning strike)
	dash = { "fireBurst", 0.85, 0.55, "whoosh" }, -- Hellfire Dash (31 Oct: the owner's fire burst; was a whoosh)
	mark = { "bladeHit", 0.9, 0.55, "bossThud" }, -- Reaper's Mark (31 Oct: the scythe strikes where it locked; was a thud)
	-- (31 Oct) the Reaper's pumpkins go off with the owner's fire burst. The 5th field is the shortest gap between two
	-- of them (5 Jack Bombs 0.15 s apart make 2 bursts, not 5).
	mines = { "fireBurst", 1.08, 0.38, "bossThud", 0.45 }, -- Jack Bombs
	boom = { "fireBurst", 0.95, 0.5, "bossThud", 0.3 }, -- a Jack-o'-Minion blowing up
	pillars = { "bossThud", 0.7, 0.5, "fellLand" }, -- Stone Pillars
	intro = { "slam", 0.85, 0.6 }, -- the boss landing in its intro
}
-- small things raining down (lobs, meteors, dives, mines, bounces, spirals, hazards): a light tap each
local TAP: Cue = { "bossThud", 1.15, 0.28, "chip" }
local lastCue: { [string]: number } = {}
local lastAnyCue = 0
local function cue(kind: string, pos: Vector3)
	local now = os.clock()
	local gap = (CUE[kind] and CUE[kind][5]) or 0.12
	if now - (lastCue[kind] or 0) < gap or now - lastAnyCue < 0.05 then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local d = (root.Position - pos).Magnitude
	if d > 110 then
		return
	end
	lastCue[kind] = now
	lastAnyCue = now
	local c = CUE[kind] or TAP
	local key = c[1]
	if not SoundConfig.SOUNDS[key] and c[4] then
		key = c[4]
	end
	local k = 1 - d / 110
	Sound.playAt(key, c[2] * (0.95 + math.random() * 0.1), c[3] * (0.35 + 0.65 * k))
end

-- a one-shot spray of particles at `pos`
local function spray(pos: Vector3, r: number, o: any)
	local h = host("Spray", Vector3.new(0.2, r * 1.4, r * 1.4))
	h.CFrame = CFrame.new(pos + Vector3.new(0, o.y or 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = Tex[o.tex] or Tex.dot
	e.LightEmission = if o.add then 1 else 0
	e.LightInfluence = if o.add then 0 else 1
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Right -- the host is turned: Right points up
	e.SpreadAngle = Vector2.new(o.spread or 35, o.spread or 35)
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.Acceleration = Vector3.new(0, o.grav or -20, 0)
	e.Drag = o.drag or 0.5
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * (o.endSize or 0.2)) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.75, 0.25), NumberSequenceKeypoint.new(1, 1) })
	e.Color = colors(o.colors)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.spin or 180), o.spin or 180)
	e.Parent = h
	e:Emit(count(math.max(1, math.floor(o.n))))
	Debris:AddItem(h, o.life[2] + 0.3)
end

-- spikes / shards that stab up out of the floor and sink back
local function spikes(pos: Vector3, r: number, n: number, color: Color3, mat: Enum.Material, tall: number, glow: Color3?)
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2 + math.random() * 0.5
		local d = r * (0.25 + 0.6 * math.random())
		local base = pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local h = tall * (0.6 + 0.6 * math.random())
		local p = Instance.new("WedgePart")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(0.9, h, 1.2)
		p.Color = color
		p.Material = mat
		local lean = CFrame.Angles(math.rad(math.random(-25, 25)), a, math.rad(math.random(-25, 25)))
		local up = CFrame.new(base + Vector3.new(0, h / 2 - 0.2, 0)) * lean
		p.CFrame = up - Vector3.new(0, h, 0)
		p.Parent = folder
		if glow then
			local sel = Instance.new("SelectionBox")
			sel.Adornee = p
			sel.Color3 = glow
			sel.LineThickness = 0.06
			sel.SurfaceTransparency = 1
			sel.Parent = p
		end
		TweenService:Create(p, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = up }):Play()
		task.delay(0.55, function()
			TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up - Vector3.new(0, h, 0) }):Play()
		end)
		Debris:AddItem(p, 1)
	end
end

-- a flat flash on the floor in the boss's colour
local function flash(pos: Vector3, r: number, color: Color3)
	local p = host("Flash", Vector3.new(r * 2, 0.05, r * 2))
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.18, 0))
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = Tex.glow
	d.Color3 = color
	d.Transparency = 0.2
	d.Parent = p
	TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.6)
end

-- this boss's hit at one spot (`light`: one of many landing at once, keep it cheap)
local function burst(pos: Vector3, r: number, light: boolean?)
	local k = (if light then 0.35 else 1) * (if PHONE then 0.5 else 1)
	local fx = style.fx
	light = light or PHONE -- no thorn / stone spikes on phones
	if fx == "fluff" then
		-- dandelion seeds blown up and drifting down, a puff of yellow pollen
		spray(pos, r, { tex = "seed", colors = { "FFFFFF", "FFF6D0" }, n = 22 * k, size = 1.4 * SEED_SIZE, life = { 1.4, 2.4 }, speed = { 8, 18 }, grav = -3, drag = 2, spread = 50 })
		spray(pos, r, { tex = "smoke", colors = { "FFE46A", "FFF2A8" }, n = 10 * k, size = r * 0.45, endSize = 1.8, life = { 0.5, 0.9 }, speed = { 3, 8 }, grav = 0, drag = 3, spread = 80 })
	elseif fx == "thorns" then
		-- bramble thorns stab out of the floor, leaves fly
		if not light then
			spikes(pos, r, 7, Color3.fromRGB(70, 55, 35), Enum.Material.Wood, 5)
		end
		spray(pos, r, { tex = "leaf", colors = { "4E8A2E", "6FB043" }, n = 16 * k, size = 1.3, life = { 0.7, 1.2 }, speed = { 12, 22 }, grav = -30, spread = 60 })
	elseif fx == "geyser" then
		-- a column of sand shoots up and rains back down
		spray(pos, r * 0.5, { tex = "sand", colors = { "F4E4B0", "D8C27C" }, n = 34 * k, size = 1.6, life = { 0.8, 1.3 }, speed = { 30, 48 }, grav = -70, spread = 12, drag = 0.2 })
		spray(pos, r, { tex = "smoke", colors = { "EBD796", "D8C27C" }, n = 10 * k, size = r * 0.5, endSize = 1.6, life = { 0.6, 1 }, speed = { 4, 10 }, grav = -2, drag = 3, spread = 85 })
	elseif fx == "chaff" then
		-- straw and crow feathers, a lick of flame
		spray(pos, r, { tex = "strand", colors = { "F0C850", "C49A6C" }, n = 20 * k, size = 1.6, life = { 0.8, 1.4 }, speed = { 12, 24 }, grav = -25, spread = 55 })
		spray(pos, r, { tex = "strand", colors = { "1E1E26", "3A3A44" }, n = 8 * k, size = 1.4, life = { 1, 1.6 }, speed = { 6, 12 }, grav = -6, drag = 1.5, spread = 70 })
		spray(pos, r * 0.5, { tex = "flame", colors = { "FFB040", "FF5A1A" }, n = 6 * k, size = 2, life = { 0.3, 0.6 }, speed = { 4, 9 }, grav = 8, add = true, spread = 30 })
	elseif fx == "bloom" then
		-- a blossom bursts open: petals swirl out, a pink flash
		spray(pos, r, { tex = "petal", colors = { "FFB6D8", "FFFFFF", "FF8FC0" }, n = 26 * k, size = 1.5, life = { 1, 1.8 }, speed = { 10, 20 }, grav = -4, drag = 1.6, spread = 75, spin = 360 })
		flash(pos, r, Color3.fromRGB(255, 160, 210))
	elseif fx == "splash" then
		-- slime splashes up in droplets, a green ring of mud
		spray(pos, r, { tex = "bubble", colors = { "9DFF5A", "50966A" }, n = 22 * k, size = 1.2, life = { 0.6, 1.1 }, speed = { 16, 30 }, grav = -55, spread = 40, add = true })
		spray(pos, r, { tex = "smoke", colors = { "50663A", "7CD45A" }, n = 8 * k, size = r * 0.4, endSize = 1.5, life = { 0.5, 0.9 }, speed = { 3, 7 }, grav = 0, drag = 3, spread = 85 })
	elseif fx == "embers" then
		-- a fiery blast, black smoke, embers floating up
		spray(pos, r * 0.6, { tex = "flame", colors = { "FFE080", "FF8A20", "C83000" }, n = 18 * k, size = r * 0.3, endSize = 1.6, life = { 0.35, 0.7 }, speed = { 6, 14 }, grav = 10, add = true, spread = 50 })
		spray(pos, r, { tex = "smoke", colors = { "2A2420", "4A3A30" }, n = 8 * k, size = r * 0.4, endSize = 1.8, life = { 0.8, 1.3 }, speed = { 4, 9 }, grav = 4, drag = 2, spread = 70 })
		spray(pos, r, { tex = "spark", colors = { "FFB060", "FF6A20" }, n = 14 * k, size = 0.6, life = { 1, 1.8 }, speed = { 4, 10 }, grav = 6, add = true, spread = 80, drag = 1 })
	elseif fx == "runes" then
		-- stone shards burst up, cyan runes rise and fade
		if not light then
			spikes(pos, r, 6, Color3.fromRGB(122, 130, 108), Enum.Material.Slate, 4, Color3.fromRGB(63, 255, 208))
		end
		spray(pos, r, { tex = "glyph", colors = { "3FFFD0", "B0FFF0" }, n = 12 * k, size = 1.8, life = { 0.9, 1.4 }, speed = { 4, 9 }, grav = 4, add = true, drag = 1.2, spread = 30, spin = 40 })
		flash(pos, r, Color3.fromRGB(63, 255, 208))
	end
end

-- A shape lands (client side, timed from the warning).
function BossVfx.impact(z: number, s: any, kind: string, floorColor: Color3?)
	local def = BossMoves.get(z)
	local ring = accentColor()
	cue(kind, s.pos)
	if s.type == "circle" then
		burst(s.pos, s.r)
		dust(s.pos, s.r, def.dust, 10)
		shockwave(s.pos, s.r, ring)
		if (kind == "slam" or kind == "leap" or kind == "burrow") and Forge and Forge.Ring then
			pcall(Forge.Ring, s.pos, { Radius = s.r * 0.75, Segments = 10, Color = floorColor or Color3.fromRGB(120, 100, 80), MinSize = Vector3.new(1.6, 1, 1.6), MaxSize = Vector3.new(2.8, 2, 2.8), Duration = 0.9 })
		end
		shakeFor(s.pos, if s.r < 6 then 3 else 8)
	elseif s.type == "square" then
		if math.random() < 0.5 then
			burst(s.pos, s.size * 0.4, true) -- half the tiles of a geyser field burst (dozens land at once)
		end
		shakeFor(s.pos, 5)
	elseif s.type == "sector" then
		for i = 1, 3 do
			burst(s.pos + s.dir * (s.r * i / 4), s.r * 0.3, i ~= 2)
		end
		shockwave(s.pos + s.dir * s.r * 0.5, s.r * 0.6, ring)
		shakeFor(s.pos, 8)
	elseif s.type == "safe" then
		shockwave(s.pos, s.r * 0.6, ring)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local d = s.r * (0.3 + 0.55 * math.random())
			burst(s.pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), 8, true)
		end
		burst(s.pos, 12)
		shakeFor(s.pos, 9)
	elseif s.type == "ring" then
		local r = (s.inner + s.outer) / 2
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			burst(s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), (s.outer - s.inner) * 0.5, i % 2 == 0)
		end
		shockwave(s.pos, s.outer, ring)
		shockwave(s.pos, r, ring)
		shakeFor(s.pos, 9)
	else
		local dir = s.dir
		local n = math.clamp(math.floor(s.length / 12), 2, 6)
		for i = 0, n - 1 do
			burst(s.pos + dir * (s.length * (i + 0.5) / n), s.width * 0.55, i % 2 == 1)
		end
		shockwave(s.pos + dir * s.length * 0.5, s.width, ring)
		shakeFor(s.pos + dir * s.length * 0.3, 8)
	end
end

-- Play a move's impacts at their land times.
function BossVfx.playImpacts(z: number, msg: any, floorColor: Color3?)
	-- (31 Oct, owner's vfx_sfx_all.zip) the Titan's Gaze charging up: the owner's electric charge, timed to fade
	-- out as the gaze fires
	if msg.kind == "gaze" and msg.shapes[1] then
		local lead = msg.at + msg.shapes[1].land - workspace:GetServerTimeNow() - 2.1
		task.delay(math.max(0, lead), function()
			if live then
				Sound.play("zapCharge", 0.03)
			end
		end)
	end
	for _, s in msg.shapes do
		local wait = msg.at + s.land - workspace:GetServerTimeNow()
		task.delay(math.max(0, wait), function()
			if live then
				BossVfx.impact(z, s, msg.kind, floorColor)
			end
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the weak spot, heal flowers
-------------------------------------------------------------------------------------------------------------
local weakGui: BillboardGui? = nil
function BossVfx.open(z: number, len: number)
	local L = live
	if not L then
		return
	end
	local name = BossMoves.get(z).weak
	local h = host("WeakSpot")
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromScale(9 * L.k, 9 * L.k)
	gui.Adornee = h
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Tex.glow
	img.ImageColor3 = Color3.fromRGB(255, 240, 120)
	img.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1.6, 0.35)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "WEAK SPOT!"
	label.TextColor3 = Color3.fromRGB(255, 240, 120)
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(120, 40, 0)
	st.Parent = label
	label.Parent = gui
	gui.Parent = h
	weakGui = gui
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local pos = BossView.attWorld(name)
		if t > len or not live or not pos then
			conn:Disconnect()
			h:Destroy()
			if weakGui == gui then
				weakGui = nil
			end
			return
		end
		h.CFrame = CFrame.new(pos)
		local pulse = 1 + 0.18 * math.sin(t * 10)
		gui.Size = UDim2.fromScale(9 * L.k * pulse, 9 * L.k * pulse)
		img.ImageTransparency = 0.15 + 0.15 * math.sin(t * 10)
		label.TextTransparency = if t > len - 0.5 then (t - (len - 0.5)) * 2 else 0
	end)
end

-- the heal flowers the boss sheds: a glow, sparkles and a bob
local function dressHeal(f: BasePart)
	if f:GetAttribute("Dressed") then
		return
	end
	f:SetAttribute("Dressed", true)
	-- a juice box (owner, round 2): the server's part is the box; a label band, a bendy straw, a +30 tag, sparkles
	local function bit(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
		local b = Instance.new("Part")
		b.Anchored = false
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Massless = true
		b.Size = size
		b.Color = color
		b.Material = mat or Enum.Material.SmoothPlastic
		b.CFrame = f.CFrame * cf
		local w = Instance.new("WeldConstraint")
		w.Part0 = f
		w.Part1 = b
		w.Parent = b
		b.Parent = f
		return b
	end
	local sz = f.Size
	bit(Vector3.new(sz.X + 0.04, sz.Y * 0.42, sz.Z + 0.04), CFrame.new(0, -0.05, 0), Color3.fromRGB(255, 255, 255))
	bit(Vector3.new(sz.X * 0.5, sz.Y * 0.2, sz.Z + 0.08), CFrame.new(0, -0.05, 0), Color3.fromRGB(110, 210, 80))
	bit(Vector3.new(0.18, 1.3, 0.18), CFrame.new(sz.X * 0.22, sz.Y / 2 + 0.6, 0), Color3.fromRGB(255, 90, 140))
	bit(Vector3.new(0.18, 0.18, 0.7), CFrame.new(sz.X * 0.22, sz.Y / 2 + 1.2, -0.3), Color3.fromRGB(255, 90, 140))
	local att = Instance.new("Attachment")
	att.Parent = f
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex.spark
	e.LightEmission = 1
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.new(1, 1, 1))
	e.Size = NumberSequence.new(0.7, 0)
	e.Lifetime = NumberRange.new(0.8, 1.3)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Rate = rate(6)
	e.Parent = att
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 7)
	gui.LightInfluence = 0
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Tex.glow
	img.ImageColor3 = Color3.fromRGB(255, 200, 110)
	img.ImageTransparency = 0.45
	img.ZIndex = 0
	img.Parent = gui
	gui.Parent = f
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(70, 30)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 120
	local plus = Instance.new("TextLabel")
	plus.BackgroundTransparency = 1
	plus.Size = UDim2.fromScale(1, 1)
	plus.Font = Enum.Font.FredokaOne
	plus.TextScaled = true
	plus.Text = "+" .. tostring(f:GetAttribute("Heal") or 30)
	plus.TextColor3 = Color3.fromRGB(140, 255, 150)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(20, 60, 20)
	st.Parent = plus
	plus.Parent = tag
	tag.Parent = f
end

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") and d.Name == "HealFlower" then
		dressHeal(d)
	end
end)

function BossVfx.healBurst(pos: Vector3)
	local h = host("HealBurst")
	h.CFrame = CFrame.new(pos)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = Tex.spark
	e.LightEmission = 1
	e.Color = ColorSequence.new(Color3.fromRGB(140, 255, 160))
	e.Size = NumberSequence.new(1.2, 0)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = h
	e:Emit(count(20))
	Debris:AddItem(h, 1.2)
end

-- the rage form's burst of its effects (the moment the parts sprout)
function BossVfx.rageBurst()
	local L = live
	local v = BossView.get()
	if not L or not v or not v.base then
		return
	end
	shockwave(v.base.Position, 30 * L.k, hex(Spec.shared.rageMote))
	dust(v.base.Position, 14 * L.k, BossMoves.get(L.z).dust)
end

-------------------------------------------------------------------------------------------------------------
-- projectiles and floor patches (round 2)
-------------------------------------------------------------------------------------------------------------
-- what a patch looks like: a tinted floor disc and what rises off it
local PATCH = {
	thorns = { color = Color3.fromRGB(70, 110, 45), tex = "leaf", rise = Color3.fromRGB(150, 60, 50), add = false },
	sand = { color = Color3.fromRGB(225, 200, 130), tex = "sand", rise = Color3.fromRGB(240, 220, 160), add = false },
	ice = { color = Color3.fromRGB(200, 236, 255), tex = "sand", rise = Color3.fromRGB(235, 250, 255), add = false },
	fire = { color = Color3.fromRGB(255, 110, 30), tex = "flame", rise = Color3.fromRGB(255, 170, 60), add = true },
	bubble = { color = Color3.fromRGB(110, 200, 80), tex = "bubble", rise = Color3.fromRGB(170, 255, 140), add = true },
	flame = { color = Color3.fromRGB(255, 110, 30), tex = "flame", rise = Color3.fromRGB(255, 170, 60), add = true },
	glyph = { color = Color3.fromRGB(63, 255, 208), tex = "glyph", rise = Color3.fromRGB(140, 255, 230), add = true },
}

type Shot = { part: BasePart, from: Vector3, to: Vector3, start: number, len: number, height: number }
local shots: { Shot } = {}

local function launchFrom(msg: any, s: any): Vector3
	if msg.fromPos then
		return msg.fromPos -- a minion's spit, the slime blob's last bounce
	end
	if msg.sky then
		return s.pos + Vector3.new(-26, 95, 18) -- meteors fall from the sky
	end
	local v = BossView.get()
	local p = msg.from and BossView.attWorld(msg.from)
	if p then
		return p
	end
	if v and v.base then
		return v.base.Position + Vector3.new(0, BossView.height() * 0.7, 0)
	end
	return msg.cf.Position + Vector3.new(0, 20, 0)
end

local function shot(msg: any, s: any)
	local L = live
	local k = if L then L.k else 2
	local p = host("Shot", Vector3.one * 0.4)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2.6 * k, 2.6 * k)
	gui.LightInfluence = 0
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Tex[msg.ammo] or Tex.dot
	img.Parent = gui
	gui.Parent = p
	local att = Instance.new("Attachment")
	att.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex[msg.ammo] or Tex.dot
	e.LightEmission = if msg.ammo == "flame" or msg.ammo == "glyph" then 1 else 0
	e.Size = NumberSequence.new(0.9 * k, 0)
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(0, 1)
	e.Rate = rate(30)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Parent = att
	if msg.big then
		gui.Size = UDim2.fromScale(5.5 * k, 5.5 * k)
	end
	local from = launchFrom(msg, s)
	local flight = msg.flight or 1
	local land = s.land - (msg.fuse or 0)
	table.insert(shots, { part = p, from = from, to = s.pos + Vector3.new(0, 0.6, 0), start = msg.at + land - flight, len = flight, height = if msg.sky then 0 else 10 + (from - s.pos).Magnitude * 0.25 })
	if msg.fuse then
		-- a pumpkin bomb sits there, blinking faster and faster, until it blows
		task.delay(math.max(0, msg.at + land - workspace:GetServerTimeNow()), function()
			local b = Instance.new("Part")
			b.Name = "Bomb"
			b.Shape = Enum.PartType.Ball
			b.Size = Vector3.one * 3.2
			b.Anchored = true
			b.CanCollide = false
			b.CanQuery = false
			b.CanTouch = false
			b.Color = Color3.fromRGB(240, 120, 30)
			b.Material = Enum.Material.SmoothPlastic
			b.CFrame = CFrame.new(s.pos + Vector3.new(0, 1.5, 0))
			b.Parent = folder
			local stem = Instance.new("Part")
			stem.Size = Vector3.new(0.5, 0.9, 0.5)
			stem.Anchored = true
			stem.CanCollide = false
			stem.CanQuery = false
			stem.Color = Color3.fromRGB(80, 110, 40)
			stem.CFrame = b.CFrame * CFrame.new(0, 1.8, 0)
			stem.Parent = b
			local untilT = msg.at + s.land
			task.spawn(function()
				while b.Parent and workspace:GetServerTimeNow() < untilT do
					local left = untilT - workspace:GetServerTimeNow()
					b.Material = if b.Material == Enum.Material.Neon then Enum.Material.SmoothPlastic else Enum.Material.Neon
					task.wait(math.clamp(left * 0.18, 0.05, 0.3))
				end
				b:Destroy()
			end)
		end)
	end
	p.CFrame = CFrame.new(from)
end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for i = #shots, 1, -1 do
		local sh = shots[i]
		local u = (t - sh.start) / sh.len
		if u >= 1 or not sh.part.Parent then
			sh.part:Destroy()
			table.remove(shots, i)
		else
			u = math.max(0, u)
			local pos = sh.from:Lerp(sh.to, u) + Vector3.new(0, sh.height * 4 * u * (1 - u), 0)
			sh.part.CFrame = CFrame.new(pos)
		end
	end
end)

-- A lob's shots: each leaves the boss `flight` s before it lands on its circle.
function BossVfx.projectiles(msg: any)
	for _, s in msg.shapes do
		local leave = msg.at + s.land - (msg.fuse or 0) - (msg.flight or 1) - workspace:GetServerTimeNow()
		task.delay(math.max(0, leave), function()
			if live then
				shot(msg, s)
				Sound.playAt("cut", 0.7 + math.random() * 0.3, 0.25)
			end
		end)
	end
end

local function patch(pos: Vector3, r: number, look: string, life: number)
	local def = PATCH[look] or PATCH.thorns
	local disc = Instance.new("Part")
	disc.Name = "Patch"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.15, r * 2, r * 2)
	disc.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = def.color
	disc.Material = if def.add then Enum.Material.Neon else Enum.Material.SmoothPlastic
	disc.Transparency = 1
	disc.Parent = folder
	TweenService:Create(disc, TweenInfo.new(0.25), { Transparency = if def.add then 0.55 else 0.25 }):Play()
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex[def.tex] or Tex.dot
	e.LightEmission = if def.add then 1 else 0
	e.Color = ColorSequence.new(def.rise)
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis is X: Right points up
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(2, 5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rate = rate(4 * r)
	e.Parent = disc
	task.delay(math.max(0.3, life - 0.4), function()
		e.Enabled = false
		TweenService:Create(disc, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		Debris:AddItem(disc, 1.4)
	end)
end

-- A hazard / pool move: each circle leaves a patch on the floor for its life once it lands.
function BossVfx.patches(msg: any)
	local life = msg.life or msg.pool
	if not life then
		return
	end
	local look = msg.look or msg.ammo or "thorns"
	for _, s in msg.shapes do
		local wait = msg.at + s.land - workspace:GetServerTimeNow()
		task.delay(math.max(0, wait), function()
			if live then
				patch(s.pos, s.r * 0.9, look, life)
			end
		end)
	end
end

-- Minions: popping out, getting hit, popping, biting (client/BossAdds draws the minions themselves).
function BossVfx.puff(pos: Vector3, color: Color3, n: number)
	local h = host("Puff")
	h.CFrame = CFrame.new(pos)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = Tex.smoke
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(6, 12)
	e.Drag = 4
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = h
	e:Emit(count(n))
	Debris:AddItem(h, 1)
end

-------------------------------------------------------------------------------------------------------------
-- moving attacks (each boss's own moves, 26 Oct): seed puffs, golf balls, crows, the pollen beam, sand waves,
-- lantern wisps, the bog flood, spreading fires. Where they are comes from shared/BossMoves (the same maths the
-- server hits with), so what you see is what hits you.
-------------------------------------------------------------------------------------------------------------
local Config = require(Shared:WaitForChild("Config"))
local ARENA_R = Config.BOSS_ARENA_RADIUS or 70

local function solid(name: string, shape: Enum.PartType, size: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function glowOn(p: BasePart, color: Color3, size: number)
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(size, size)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Tex.glow
	img.ImageColor3 = color
	img.ImageTransparency = 0.35
	img.Parent = gui
	gui.Parent = p
end

local function trailOn(p: BasePart, tex: string, color: Color3, size: number, rateN: number, add: boolean?)
	local att = Instance.new("Attachment")
	att.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex[tex] or Tex.dot
	e.Color = ColorSequence.new(color)
	e.LightEmission = if add then 1 else 0
	e.Size = NumberSequence.new(size, 0)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rate = rate(rateN)
	e.Parent = att
end

-- the thing that travels: parts with offsets from its middle (`Wing` parts flap)
type Look = { parts: { { part: BasePart, off: CFrame, wing: number? } }, lift: number }
local function look(name: string, r: number): Look
	local out = { parts = {}, lift = r }
	local function add(p: BasePart, off: CFrame?, wing: number?)
		table.insert(out.parts, { part = p, off = off or CFrame.identity, wing = wing })
	end
	if name == "puff" then
		-- a dandelion seed puff: a fluffy white ball, a seed in the middle, drifting fluff
		local b = solid("Puff", Enum.PartType.Ball, Vector3.one * r * 2, Color3.fromRGB(255, 255, 250), Enum.Material.SmoothPlastic)
		b.Transparency = 0.45
		add(b)
		local core = solid("PuffCore", Enum.PartType.Ball, Vector3.one * r * 1.3, Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		core.Transparency = 0.55
		add(core)
		glowOn(b, Color3.fromRGB(255, 250, 210), r * 3.2)
		add(solid("Seed", Enum.PartType.Ball, Vector3.one * r * 0.45, Color3.fromRGB(150, 110, 60)), CFrame.new(0, -r * 0.5, 0))
		trailOn(b, "seed", Color3.fromRGB(255, 255, 240), 1.2 * SEED_SIZE, 10)
		out.lift = r + 1.2
	elseif name == "golfball" then
		local b = solid("GolfBall", Enum.PartType.Ball, Vector3.one * r * 2, Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic)
		add(b)
		trailOn(b, "sand", Color3.fromRGB(235, 215, 150), 2.2, 22)
		out.lift = r
	elseif name == "crow" then
		local body = solid("Crow", Enum.PartType.Ball, Vector3.new(r * 0.9, r * 0.8, r * 1.4), Color3.fromRGB(30, 30, 38))
		add(body)
		add(solid("Head", Enum.PartType.Ball, Vector3.one * r * 0.6, Color3.fromRGB(36, 36, 44)), CFrame.new(0, r * 0.25, -r * 0.7))
		add(solid("Beak", Enum.PartType.Block, Vector3.new(r * 0.15, r * 0.15, r * 0.45), Color3.fromRGB(240, 180, 40)), CFrame.new(0, r * 0.2, -r * 1.1))
		for _, x in { -1, 1 } do
			add(solid("Wing", Enum.PartType.Block, Vector3.new(r * 1.3, r * 0.08, r * 0.7), Color3.fromRGB(24, 24, 30)), CFrame.new(x * r * 0.9, r * 0.1, 0), x)
		end
		trailOn(body, "strand", Color3.fromRGB(60, 60, 70), 1.4, 12)
		out.lift = r + 2.5
	elseif name == "wisp" then
		local b = solid("Wisp", Enum.PartType.Ball, Vector3.one * r * 1.3, Color3.fromRGB(255, 190, 150), Enum.Material.Neon)
		add(b)
		glowOn(b, Color3.fromRGB(255, 150, 200), r * 4)
		trailOn(b, "petal", Color3.fromRGB(255, 190, 220), 1.4, 14, true)
		out.lift = r + 2
	else
		local b = solid("Orb", Enum.PartType.Ball, Vector3.one * r * 2, Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
		add(b)
		out.lift = r
	end
	return out
end

local function placeLook(lk: Look, cf: CFrame, t: number, alpha: number)
	for _, e in lk.parts do
		local off = e.off
		if e.wing then
			off = off * CFrame.Angles(0, 0, math.sin(t * 24) * 0.8 * e.wing)
		end
		e.part.CFrame = cf * off
		e.part.LocalTransparencyModifier = 1 - alpha
	end
end

local function destroyLook(lk: Look)
	for _, e in lk.parts do
		e.part:Destroy()
	end
end

type Mv = { m: any, at: number, dur: number, look: Look?, parts: { BasePart }, gui: any?, spin: number }
local movers: { Mv } = {}
local jumpLabel: TextLabel? = nil
local jumpUntil = 0

local function jumpHint()
	if not jumpLabel then
		local sg = Instance.new("ScreenGui")
		sg.Name = "BossJump"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.62)
		l.Size = UDim2.fromScale(0.3, 0.09)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = "JUMP!"
		l.TextColor3 = Color3.fromRGB(255, 230, 120)
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = Color3.fromRGB(120, 60, 0)
		st.Parent = l
		l.Visible = false
		l.Parent = sg
		sg.Parent = player:WaitForChild("PlayerGui")
		jumpLabel = l
	end
	jumpUntil = os.clock() + 0.35
end

local function waveSegments(n: number): { BasePart }
	local out = {}
	for i = 1, n do
		local p = solid("SandWave", Enum.PartType.Block, Vector3.new(4, 2.6, 3), Color3.fromRGB(232, 210, 145), Enum.Material.Sand)
		p.Transparency = 1
		table.insert(out, p)
	end
	return out
end

-- a big canvas for the bog flood (a ring of water from the dry middle to past the wall)
local function floodCanvas(m: any): (Part, Frame, UIStroke)
	local d = (m.rmax + 4) * 2
	local p, g = canvas(m.o, d, d)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundTransparency = 1
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(70, 140, 70)
	st.Transparency = 0.25
	st.Parent = f
	f.Parent = g
	return p, f, st
end

local function addMover(msg: any, m: any)
	local mv: Mv = { m = m, at = msg.at, dur = BossMoves.moverDur(m), look = nil, parts = {}, gui = nil, spin = 0 }
	local ty = m.type
	if ty == "line" then
		mv.look = look(m.look or "orb", m.r)
		if m.ghost then
			-- the path shows as a red strip until it sets off
			for i = 2, #m.pts do
				local a, b = m.pts[i - 1], m.pts[i]
				local seg = b - a
				if seg.Magnitude > 1 then
					table.insert(warns, stripWarn({ pos = a, dir = seg.Unit, length = seg.Magnitude, width = m.r * 2, land = m.t0 - msg.at }, msg.at))
				end
			end
		end
	elseif ty == "beam" then
		table.insert(warns, stripWarn({ pos = m.o, dir = Vector3.new(math.sin(m.a0), 0, math.cos(m.a0)), length = m.len, width = m.width, land = m.t0 - msg.at }, msg.at))
		local p = solid("Beam", Enum.PartType.Block, Vector3.new(m.width * 0.55, 1.4, m.len), Color3.fromRGB(255, 225, 90), Enum.Material.Neon)
		p.Transparency = 1
		trailOn(p, "seed", Color3.fromRGB(255, 240, 150), 1.6, 40, true)
		local att = p:FindFirstChildOfClass("Attachment")
		local e = att and att:FindFirstChildOfClass("ParticleEmitter")
		if e then
			e.Parent = p
			e.Shape = Enum.ParticleEmitterShape.Box
		end
		mv.parts = { p }
	elseif ty == "wave" then
		mv.parts = waveSegments(44)
	elseif ty == "orbit" then
		mv.gui = {}
		for _ = 1, m.n do
			table.insert(mv.gui, look(m.look or "wisp", m.r))
		end
	elseif ty == "tide" then
		local p, f, st = floodCanvas(m)
		mv.parts = { p }
		mv.gui = { f = f, st = st }
		-- the edge of the dry middle, shown at once
		table.insert(warns, ringWarn({ pos = m.o, inner = m.rmin, outer = m.rmin + 2, land = m.t0 - msg.at }, msg.at))
	elseif ty == "grow" then
		table.insert(warns, circleWarn({ pos = m.pos, r = m.r1, land = m.t0 - msg.at }, msg.at))
		local p = solid("Fire", Enum.PartType.Cylinder, Vector3.new(0.15, 1, 1), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
		p.Transparency = 0.45
		local e = Instance.new("ParticleEmitter")
		e.Texture = Tex.flame
		e.LightEmission = 1
		e.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 80, 20))
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Right
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.5, 1)
		e.Speed = NumberRange.new(3, 7)
		e.Rate = 0
		e.Parent = p
		mv.parts = { p }
	end
	table.insert(movers, mv)
end

local function removeMover(i: number)
	local mv = movers[i]
	if mv.look then
		destroyLook(mv.look)
	end
	if mv.m.type == "orbit" and mv.gui then
		for _, lk in mv.gui do
			destroyLook(lk)
		end
	end
	for _, p in mv.parts do
		p:Destroy()
	end
	table.remove(movers, i)
end

local function stepMover(mv: Mv, now: number, dt: number, me: BasePart?)
	local m = mv.m
	local t = now - m.t0
	local ty = m.type
	local floorY = (m.o or m.pos or (m.pts and m.pts[1]) or Vector3.zero).Y
	if ty == "line" then
		local lk = mv.look :: Look
		local pos, dir = BossMoves.along(m.pts, math.max(0, t) * m.speed)
		local alpha = if t < 0 then math.clamp(1 + t, 0, 1) else 1
		mv.spin += dt * m.speed / math.max(1, m.r)
		local cf = CFrame.lookAt(pos, pos + dir) + Vector3.new(0, lk.lift, 0)
		if m.look == "golfball" then
			cf = cf * CFrame.Angles(-mv.spin, 0, 0) -- rolls
		elseif m.look == "puff" then
			cf = cf + Vector3.new(0, math.sin(now * 3 + m.r) * 0.6, 0)
		end
		placeLook(lk, cf, now, alpha)
	elseif ty == "beam" then
		local p = mv.parts[1]
		local tt = math.clamp(t, 0, mv.dur)
		local a = m.a0 + m.w * tt
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		p.CFrame = CFrame.lookAt(m.o + dir * (m.len / 2), m.o + dir * m.len) + Vector3.new(0, 1.2, 0)
		p.Transparency = if t < 0 then 1 elseif t > mv.dur then 1 else 0.3 + 0.1 * math.sin(now * 20)
		local pe = p:FindFirstChildOfClass("ParticleEmitter")
		if pe then
			pe.Enabled = t >= 0 and t <= mv.dur
		end
		-- (29 Oct) the beam can be jumped: JUMP! when it's about to sweep over you
		if me and m.jump and t >= 0 and t <= mv.dur then
			local rel = Vector3.new(me.Position.X - m.o.X, 0, me.Position.Z - m.o.Z)
			local along = rel:Dot(dir)
			local ahead = (Vector3.new(dir.Z, 0, -dir.X) * math.sign(m.w)):Dot(rel) -- the side the beam is turning towards
			if along > 0 and along < m.len and ahead > -1 and ahead < 9 then
				jumpHint()
			end
		end
		if t >= -0.3 and t <= mv.dur then
			BossView.setTarget(CFrame.lookAt(m.o, m.o + dir))
		end
	elseif ty == "wave" then
		local r = m.r0 + m.speed * math.max(0, t)
		local n = #mv.parts
		local seg = 2 * math.pi * r / n * 1.08
		local centre = live and live.arena
		for i, p in mv.parts do
			local a = (i - 1) / n * math.pi * 2
			local pos = m.o + Vector3.new(math.sin(a) * r, 1.3, math.cos(a) * r)
			local outside = centre and (Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)).Magnitude > ARENA_R - 1
			if t < 0 or t > mv.dur or outside then
				p.Transparency = 1
			else
				p.Transparency = 0.15
				p.Size = Vector3.new(seg, 2.6, m.band)
				p.CFrame = CFrame.new(pos) * CFrame.Angles(0, a, 0)
			end
		end
		if me and t >= 0 and t <= mv.dur then
			local d = Vector3.new(me.Position.X - m.o.X, 0, me.Position.Z - m.o.Z).Magnitude
			if d > r - 1 and d - r < 11 then
				jumpHint()
			end
		end
	elseif ty == "orbit" then
		local shapes = BossMoves.moverShapes(m, math.clamp(t, 0, mv.dur))
		for i, lk in mv.gui do
			local s = shapes[i]
			if s then
				local alpha = if t < 0 then math.clamp(1 + t, 0, 1) elseif t > mv.dur - 0.3 then math.clamp((mv.dur - t) / 0.3, 0, 1) else 1
				placeLook(lk, CFrame.new(s.pos + Vector3.new(0, lk.lift + math.sin(now * 4 + i) * 0.6, 0)), now, alpha)
			end
		end
	elseif ty == "tide" then
		local inner = BossMoves.tideR(m, math.clamp(t, 0, mv.dur))
		local outer = m.rmax + 4
		local g = mv.gui
		g.f.Size = UDim2.fromOffset((inner + outer) * PX, (inner + outer) * PX)
		g.st.Thickness = (outer - inner) * PX
		g.st.Transparency = if t < 0 then 1 else 0.3 + 0.05 * math.sin(now * 3)
		mv.parts[1].CFrame = CFrame.new(m.o + Vector3.new(0, 0.35 + 0.15 * math.sin(now * 2), 0))
	elseif ty == "grow" then
		local p = mv.parts[1]
		local shapes = BossMoves.moverShapes(m, math.clamp(t, 0, mv.dur))
		local s = shapes[1]
		local r = if s and t >= 0 then s.r else 0.1
		p.Size = Vector3.new(0.15, r * 2, r * 2)
		p.CFrame = CFrame.new(m.pos + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Transparency = if t < 0 or t > mv.dur - 0.3 then 1 else 0.45
		local e = p:FindFirstChildOfClass("ParticleEmitter")
		if e then
			e.Rate = if t >= 0 and t < mv.dur - 0.3 then rate(3 * r) else 0
		end
	end
	local _ = floorY
end

RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for i = #movers, 1, -1 do
		local mv = movers[i]
		if now - mv.m.t0 > mv.dur + 0.4 then
			removeMover(i)
		else
			local ok, err = pcall(stepMover, mv, now, dt, me)
			if not ok then
				warn("[BossVfx] mover: " .. tostring(err))
				removeMover(i)
			end
		end
	end
	if jumpLabel then
		local on = os.clock() < jumpUntil
		jumpLabel.Visible = on
		if on then
			jumpLabel.Rotation = math.sin(os.clock() * 30) * 4
		end
	end
end)

-- A move's moving things (msg.movers).
function BossVfx.movers(msg: any)
	for _, m in msg.movers or {} do
		addMover(msg, m)
	end
end

-- Everything moving goes (rage cutscene, death, wipe).
function BossVfx.clearMovers()
	for i = #movers, 1, -1 do
		removeMover(i)
	end
end

-- The Hellfire Dash's trail of fire.
function BossVfx.trail(d: any)
	for dist = 0, d.len, 7 do
		patch(d.from + d.dir * dist, d.width * 0.45, "fire", d.life)
	end
	-- (31 Oct, owner's vfx_sfx.zip) the trail catching and roaring up: the owner's fire tornado, quieter further away
	local mid = d.from + d.dir * (d.len * 0.5)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local far = if root then (root.Position - mid).Magnitude else math.huge
	if far < 110 then
		Sound.playAt("fireSpin", 0.95 + math.random() * 0.1, 0.45 * (0.35 + 0.65 * (1 - far / 110)))
	end
end

-- Rune lasers taking aim: a thin beam from the boss to each target, getting brighter
function BossVfx.aim(d: any)
	local beams = {}
	for _, id in d.ids do
		local who = Players:GetPlayerByUserId(id)
		if who then
			local p = solid("Aim", Enum.PartType.Block, Vector3.new(0.3, 0.3, 1), Color3.fromRGB(63, 255, 208), Enum.Material.Neon)
			p.Transparency = 0.6
			table.insert(beams, { p = p, who = who })
		end
	end
	local untilT = d.at + d.len
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local v = BossView.get()
		if now > untilT or not v or not v.base then
			conn:Disconnect()
			for _, b in beams do
				b.p:Destroy()
			end
			return
		end
		local from = BossView.attWorld(BossMoves.get(live and live.z or 8).weak) or (v.base.Position + Vector3.new(0, BossView.height() * 0.7, 0))
		local u = 1 - (untilT - now) / d.len
		for _, b in beams do
			local root = b.who.Character and b.who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local to = root.Position
				local len = (to - from).Magnitude
				b.p.Size = Vector3.new(0.2 + u * 0.6, 0.2 + u * 0.6, len)
				b.p.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
				b.p.Transparency = 0.7 - 0.5 * u
			end
		end
	end)
	Sound.play("warn", 0.05, 0.6)
end

-- the reaper's mark (a red ring that follows a player) and the Shell Ambush's mound (dirt under the floor)
local followers: { [BasePart]: { part: Part, w: any?, kind: string } } = {}
local function watchMarker(src: BasePart)
	if followers[src] then
		return
	end
	if src.Name == "BossMark" then
		local r = src:GetAttribute("R") or 10
		local w: any = circleWarn({ pos = src.Position, r = r, land = 1e6 }, workspace:GetServerTimeNow())
		followers[src] = { part = w.part, w = w, kind = "mark" }
	elseif src.Name == "BossMound" then
		local p = solid("Mound", Enum.PartType.Ball, Vector3.new(9, 4, 9), Color3.fromRGB(150, 120, 80), Enum.Material.Sand)
		local e = Instance.new("ParticleEmitter")
		e.Texture = Tex.sand
		e.Color = ColorSequence.new(Color3.fromRGB(225, 200, 140))
		e.Size = NumberSequence.new(1.6, 0)
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(4, 9)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Rate = rate(40)
		e.Parent = p
		followers[src] = { part = p, kind = "mound" }
	end
end

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") and (d.Name == "BossMark" or d.Name == "BossMound") then
		watchMarker(d)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	for src, fl in followers do
		if not src:IsDescendantOf(workspace) then
			fl.part:Destroy()
			followers[src] = nil
			continue
		end
		local want = src.Position
		if fl.kind == "mark" then
			local cur = fl.part.Position
			local pos = cur:Lerp(want + Vector3.new(0, 0.12, 0), math.min(1, dt * 12))
			fl.part.CFrame = CFrame.new(pos)
			local w = fl.w
			if w and w.spin then
				w.spin.Rotation += dt * 120
			end
			if w and w.fill then
				local full = (fl.part.Size.X - 2) * PX
				local k = 0.5 + 0.5 * math.sin(os.clock() * 7)
				w.fill.Size = UDim2.fromOffset(full * k, full * k)
			end
		else
			local cur = fl.part.Position
			local pos = cur:Lerp(want + Vector3.new(0, 0.6 + math.sin(os.clock() * 14) * 0.3, 0), math.min(1, dt * 12))
			fl.part.CFrame = CFrame.new(pos)
		end
	end
end)

return BossVfx
