--!strict
-- PackFx (4 Nov; owner, with the SoulShroud Ultimate VFX Pack attached: "remake vfx with this pack use them and also
-- remake some boss attack with this and trailer", picked the hit / mow effects, all 8 bosses with 1-2 attacks each,
-- the lobby / zones ambience, and the intro and the ending; "no not auras"; "make it revertable tho so if i dont like
-- it it can be reverted").
-- Plays the pack's effects, laid ON TOP of the game's own effects (nothing old is removed):
--   * the templates are in the place, not in git (the pack is paid and the repo is public): ReplicatedStorage.PackVFX,
--     made from ServerStorage.SoulShroudPack by server/PackVfxBuild (edit mode:
--     require(game.ServerScriptService.MowALawn.PackVfxBuild).build()).
--   * Config.SOULSHROUD_VFX = false turns every one of them off: the game then looks exactly as before. Removing
--     ReplicatedStorage.PackVFX does the same.
-- API (client only; every call is a no-op when it's off or the template is missing):
--   PackFx.on()                         is it on
--   PackFx.play(name, at, opts?)        a one-shot: its emitters run `hold` s, its meshes grow and fade. -> the clone
--      opts: scale, color (recolours it, keeping white cores light), hold, life, follow (a part it rides on)
--   PackFx.loop(name, at, opts?)        stays on until handle.stop() (ambience)
--   PackFx.hit(event, pos, grass, mine, scale, opts)   a hit / cut / boss hit (client/HitFx)
--   PackFx.reveal(at, color, scale)     a mutation found (client/Fx)
--   PackFx.boss(z, kind, shape, color)  a boss attack landing (client/BossVfx)
--   PackFx.film(name, cf, opts)         the films' moments (client/FilmVfx)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config")) :: any
local Potato = require(script.Parent.Potato) :: any
local PhonePerf = require(script.Parent.PhonePerf) :: any

local PackFx = {}

local live: { [Instance]: boolean } = {}
local liveCount = 0
local holder: Folder? = nil

function PackFx.on(): boolean
	return Config.SOULSHROUD_VFX == true and RunService:IsClient() and ReplicatedStorage:FindFirstChild("PackVFX") ~= nil
end

local function template(name: string): Model?
	local f = ReplicatedStorage:FindFirstChild("PackVFX")
	local t = f and f:FindFirstChild(name)
	if t and t:IsA("Model") and t.PrimaryPart then
		return t
	end
	return nil
end

function PackFx.has(name: string): boolean
	return PackFx.on() and template(name) ~= nil
end

-- 1 on a PC; less on phones, low graphics and in Potato Mode
local function budget(): number
	if Potato.on then
		return 0.3
	end
	if PhonePerf.on then
		return 0.5
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if ok and level ~= 0 and level <= 3 then
		return 0.6
	end
	return 1
end

-- at most this many effects at once (ambience loops don't count)
local function cap(): number
	if Potato.on then
		return 6
	end
	return if PhonePerf.on then 12 else 28
end

local function folder(): Folder
	if holder and holder.Parent then
		return holder
	end
	local f = Instance.new("Folder")
	f.Name = "PackFxLive"
	f.Archivable = false
	f.Parent = workspace
	holder = f
	return f
end

-- (owner, 4 Nov: "the cutscenes are blinding") the pack glows hard: no layer is brighter than this. (Its
-- LightEmission stays: the pack's glowing layers are drawn additively, where a dark colour is see-through; less
-- LightEmission would show their dark squares.)
local BRIGHT_MAX = 2.5
local WHITE = Color3.new(1, 1, 1)

-- A colour moved over to `color` at the same brightness: dark stays dark (see-through when additive), a saturated
-- layer takes the colour at full strength, the white-hot cores stay whitish.
local function shade(c: Color3, color: Color3): Color3
	local v = math.max(c.R, c.G, c.B)
	if v < 0.06 then
		return c
	end
	local w = math.min(c.R, c.G, c.B) / v -- 0 = a pure colour, 1 = white / grey
	local cm = math.max(color.R, color.G, color.B, 0.05)
	local t = Color3.new(color.R / cm * v, color.G / cm * v, color.B / cm * v)
	return t:Lerp(Color3.new(v, v, v), w * 0.7)
end

local function tintSeq(seq: ColorSequence, color: Color3): ColorSequence
	local kp = {}
	for _, k in seq.Keypoints do
		table.insert(kp, ColorSequenceKeypoint.new(k.Time, shade(k.Value, color)))
	end
	return ColorSequence.new(kp)
end

-- Gets a clone ready: tinted, softened, thinned for the budget, scaled.
local function prepare(t: Model, o: any): Model
	local m = t:Clone()
	local b = budget()
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			if d.Brightness > BRIGHT_MAX then
				d.Brightness = BRIGHT_MAX
			end
			d.Rate *= b * (o.rate or 1)
			if o.color and not d:GetAttribute("NoTint") then
				d.Color = tintSeq(d.Color, o.color)
			end
		elseif d:IsA("Beam") or d:IsA("Trail") then
			local e = d :: any
			e.Enabled = false
			if o.color and not d:GetAttribute("NoTint") then
				e.Color = tintSeq(e.Color, o.color)
			end
		elseif d:IsA("Light") then
			d.Enabled = false
			if o.color then
				d.Color = o.color
			end
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if o.color and d:IsA("MeshPart") and not d:GetAttribute("NoTint") then
				d.Color = shade(d.Color, o.color)
			end
		end
	end
	local s = (o.scale or 1) * ((m:GetAttribute("Scale") :: number?) or 1)
	if math.abs(s - 1) > 0.001 then
		m:ScaleTo(m:GetScale() * s)
	end
	return m
end

local function finish(m: Instance)
	if live[m] then
		live[m] = nil
		liveCount -= 1
	end
	if m.Parent then
		m:Destroy()
	end
end

-- The longest a particle of `m` lives.
local function longest(m: Instance): number
	local l = 0
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			l = math.max(l, d.Lifetime.Max / math.max(0.05, d.TimeScale))
		end
	end
	return l
end

-- Turns the emitters, beams and lights on (and off again after `hold`; never when hold is nil).
local function run(m: Model, hold: number?)
	local list = {}
	local burst = (m:GetAttribute("Burst") :: number?) or 1
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
			(d :: any).Enabled = true
			table.insert(list, d)
			-- (a quick burst emits at once too, so even a 0.05 s hold shows a full puff)
			if hold and d:IsA("ParticleEmitter") then
				local n = math.max(1, math.floor(d.Rate * math.max(hold, 0.12) * burst + 0.5))
				d:Emit(math.min(n, 40))
				d.Enabled = false
			end
		end
	end
	if hold then
		task.delay(hold, function()
			for _, d in list do
				if d.Parent and not d:IsA("ParticleEmitter") then
					(d :: any).Enabled = false
				end
			end
		end)
	end
end

-- The pack's mesh shapes (shock domes, ice spikes, slash arcs) grow from small and fade out.
local function grow(m: Model, time: number)
	local from = (m:GetAttribute("GrowFrom") :: number?) or 0.35
	for _, d in m:GetDescendants() do
		if d:IsA("MeshPart") or (d:IsA("BasePart") and d:FindFirstChildOfClass("Decal")) then
			local p = d :: BasePart
			if p:GetAttribute("Host") then
				continue
			end
			local size, cf = p.Size, p.CFrame
			local tr = p.Transparency
			p.Size = size * from
			TweenService:Create(p, TweenInfo.new(time * 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = size, CFrame = cf }):Play()
			TweenService:Create(p, TweenInfo.new(time * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, time * 0.4), { Transparency = 1 }):Play()
			for _, dc in p:GetChildren() do
				if dc:IsA("Decal") or dc:IsA("Texture") then
					TweenService:Create(dc, TweenInfo.new(time * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, time * 0.4), { Transparency = 1 }):Play()
				end
			end
			if tr >= 1 then
				p.Transparency = 1
			end
		end
	end
end

export type Opts = {
	scale: number?,
	color: Color3?,
	hold: number?,
	life: number?,
	follow: BasePart?,
	force: boolean?, -- plays even past the cap (a film's big moment)
	rate: number?, -- x its particle rate (the ambience runs the pack's weather thinner)
}

-- Plays template `name` once at `at`. Returns the clone, or nil.
function PackFx.play(name: string, at: CFrame | Vector3, opts: Opts?): Model?
	if not PackFx.on() then
		return nil
	end
	local o: any = opts or {}
	if liveCount >= cap() and not o.force then
		return nil
	end
	local t = template(name)
	if not t then
		return nil
	end
	local m = prepare(t, o)
	local cf = if typeof(at) == "Vector3" then CFrame.new(at) else at
	if t:GetAttribute("Face") then
		cf *= CFrame.Angles(math.pi / 2, 0, 0) -- (a flat disc stood up, facing the way it's played)
	end
	m:PivotTo(cf)
	m.Parent = folder()
	live[m] = true
	liveCount += 1
	local hold = o.hold or (t:GetAttribute("Hold") :: number?) or 0.12
	local life = o.life or (t:GetAttribute("Life") :: number?) or (hold + longest(m) + 0.2)
	if t:GetAttribute("Grow") then
		grow(m, (t:GetAttribute("GrowTime") :: number?) or math.min(life, 1.2))
	end
	run(m, hold)
	local follow = o.follow
	local conn: RBXScriptConnection? = nil
	if follow then
		local rel = follow.CFrame:ToObjectSpace(cf)
		conn = RunService.RenderStepped:Connect(function()
			if follow.Parent and m.Parent then
				m:PivotTo(follow.CFrame * rel)
			end
		end)
	end
	task.delay(life, function()
		if conn then
			conn:Disconnect()
		end
		finish(m)
	end)
	return m
end

export type Loop = { model: Model?, stop: (fade: number?) -> (), move: (cf: CFrame) -> () }

-- Starts template `name` running at `at` until the handle's stop().
function PackFx.loop(name: string, at: CFrame | Vector3, opts: Opts?): Loop
	local none: Loop = { model = nil, stop = function() end, move = function() end }
	if not PackFx.on() then
		return none
	end
	local t = template(name)
	if not t then
		return none
	end
	local m = prepare(t, opts or {})
	m:PivotTo(if typeof(at) == "Vector3" then CFrame.new(at) else at)
	m.Parent = folder()
	run(m, nil)
	local h: Loop = none
	h = {
		model = m,
		stop = function(fade: number?)
			for _, d in m:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Light") then
					(d :: any).Enabled = false
				end
			end
			task.delay(fade or longest(m), function()
				if m.Parent then
					m:Destroy()
				end
			end)
		end,
		move = function(cf: CFrame)
			if m.Parent then
				m:PivotTo(cf)
			end
		end,
	}
	return h
end

-------------------------------------------------------------------------------------------------------------
-- what plays where
-------------------------------------------------------------------------------------------------------------
-- Your own hits: a small burst in the grass's colour (at most ~8 a second); a combo finisher a big one; a cut a
-- swirl of clippings; boss hits a spiky burst in the boss's colour.
local lastHit = 0
function PackFx.hit(event: string, pos: Vector3, grass: Color3, mine: boolean, scale: number, opts: any?)
	if not PackFx.on() then
		return
	end
	local o = opts or {}
	local s = math.clamp(scale or 1, 0.8, 2.2)
	local up = Vector3.new(0, 1.6 * s, 0)
	local light = grass:Lerp(WHITE, 0.25)
	if event == "cut" then
		PackFx.play("Cut", pos + up, { color = light, scale = 0.55 * s })
		return
	elseif event == "bossHit" then
		PackFx.play("BossHit", pos, { color = grass:Lerp(WHITE, 0.2), scale = 0.8 })
		return
	elseif event == "bossDeath" then
		PackFx.play("BossDeath", pos, { color = grass, scale = 1.4, force = true })
		return
	elseif event == "bossSlam" then
		PackFx.play("Shock", pos + Vector3.new(0, 0.4, 0), { scale = 1.2 })
		return
	elseif string.sub(event, 1, 4) == "boss" or event == "reveal" then
		return
	end
	if not mine then
		return
	end
	local now = os.clock()
	if o.finisher then
		lastHit = now
		PackFx.play("HitBig", pos + up, { color = light, scale = 0.6 * s })
		PackFx.play("Shock", pos + Vector3.new(0, 0.3, 0), { scale = 0.45 * s })
		return
	end
	if now - lastHit < 0.12 then
		return
	end
	lastHit = now
	PackFx.play("Hit", pos + up, { color = if o.mut then o.mut else light, scale = 0.45 * s })
end

-- A mutation found: a star flash and a magic circle in its colour.
function PackFx.reveal(at: Vector3, color: Color3, scale: number)
	if not PackFx.on() then
		return
	end
	PackFx.play("Reveal", at, { color = color, scale = 0.7 * math.clamp(scale, 1, 2), force = true })
	PackFx.play("Shock", at - Vector3.new(0, 1.5, 0), { color = color, scale = 0.5 * math.clamp(scale, 1, 2), force = true })
end

-- (owner: "all 8, 1-2 attacks each") the signature attacks of each boss, by move kind (no two bosses share one;
-- shared/BossMoves). Each entry: the templates and how each sits on the attack's shape:
--   at = "centre" (the shape's middle) | "line" (along a line / sector, `n` copies) | "edge" (round the ring)
--   size = studs the template covers at scale 1 (it's scaled to the shape), tint = the boss's colour or a fixed one
local BOSS: { [string]: { any } } = {
	-- 1 Dandelion King
	slam = { { "Shock", at = "centre", size = 14 }, { "GoldBurst", at = "centre", size = 18, tint = "ring" }, { "Dome", at = "centre", size = 80, tint = "ring" } },
	cross = { { "GoldBurst", at = "line", n = 4, size = 14, tint = "ring" } },
	-- 2 Harvest Maw
	fan = { { "Slash", at = "line", n = 3, size = 30, tint = "ring" } },
	spread = { { "FireBurst", at = "centre", size = 22 } },
	-- 3 Sakura Snapjaw
	leap = { { "Shock", at = "centre", size = 14 }, { "PinkBurst", at = "centre", size = 16 }, { "Dome", at = "centre", size = 80, tint = Color3.fromRGB(255, 160, 205) } },
	ring = { { "PinkBurst", at = "edge", n = 6, size = 14 } },
	-- 4 Bramble Brute
	combo = { { "BigBurst", at = "centre", size = 16, tint = "ring" }, { "Rocks", at = "centre", size = 40 } },
	safe = { { "Explosion", at = "centre", size = 120, tint = "ring" } },
	-- 5 Bog Strangler
	grid = { { "Splash", at = "centre", size = 45, tint = Color3.fromRGB(120, 200, 110) } },
	stalk = { { "Spikes", at = "centre", size = 40, tint = Color3.fromRGB(90, 170, 80) } },
	-- 6 Frost Thornback
	cone = { { "IceSpikes", at = "centre", size = 190 } },
	burrow = { { "IceSplash", at = "centre", size = 50 }, { "Shock", at = "centre", size = 14 } },
	-- 7 Hollow Harvest
	swing = { { "Slash", at = "line", n = 2, size = 30, tint = Color3.fromRGB(255, 90, 40) } },
	dash = { { "FireBurst", at = "line", n = 3, size = 22 } },
	-- 8 Jungle Titan
	star = { { "Shock", at = "centre", size = 14 }, { "Rocks", at = "centre", size = 40 } },
	laser = { { "Beam", at = "beam", size = 200, tint = "ring" } },
	gaze = { { "Beam", at = "beam", size = 200, tint = Color3.fromRGB(150, 255, 210) } },
}

-- A shape's middle, a direction and a size in studs.
local function shapeInfo(s: any): (Vector3, Vector3, number, number)
	local dir = s.dir or Vector3.new(0, 0, -1)
	if s.type == "circle" or s.type == "safe" then
		return s.pos, dir, (s.r or 8) * 2, 0
	elseif s.type == "ring" then
		return s.pos, dir, (s.outer or 20) * 2, 0
	elseif s.type == "square" then
		return s.pos, dir, s.size or 12, 0
	elseif s.type == "sector" then
		return s.pos + dir * (s.r or 20) * 0.5, dir, (s.r or 20), s.r or 20
	end
	local len = s.length or 30
	return s.pos + dir * len * 0.5, dir, s.width or 8, len
end

function PackFx.boss(kind: string, s: any, ring: Color3)
	if not PackFx.on() then
		return
	end
	local list = BOSS[kind]
	if not list then
		return
	end
	local mid, dir, size, len = shapeInfo(s)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	for _, e in list do
		local name = e[1]
		local color: Color3? = if e.tint == "ring" then ring elseif typeof(e.tint) == "Color3" then e.tint else nil
		local sc = size / e.size
		if e.at == "centre" then
			PackFx.play(name, CFrame.lookAt(mid, mid + flat), { color = color, scale = math.clamp(sc, 0.15, 3) })
		elseif e.at == "edge" then
			local r = size * 0.4
			for i = 1, e.n do
				local a = i / e.n * math.pi * 2
				local p = s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				PackFx.play(name, p, { color = color, scale = math.clamp(size / 3 / e.size * 2, 0.3, 1.5) })
			end
		elseif e.at == "line" then
			local start = mid - flat * (len * 0.5)
			for i = 1, e.n do
				local p = start + flat * (len * (i - 0.5) / e.n)
				PackFx.play(name, CFrame.lookAt(p, p + flat), { color = color, scale = math.clamp(math.max(size, len / e.n) / e.size, 0.3, 2.5) })
			end
		elseif e.at == "beam" then
			-- the template runs from its root along -Z (server/PackVfxBuild): from the beam's start, its length
			local from = mid - flat * (len * 0.5) + Vector3.new(0, 3, 0)
			local t = template(name)
			local tl = (t and t:GetAttribute("Length") :: number?) or e.size
			PackFx.play(name, CFrame.lookAt(from, from + flat), { color = color, scale = math.clamp(len / tl, 0.1, 1.5) })
		end
	end
end

-- (owner: "intro én ending") the films' moments: each named FilmVfx moment also plays its pack effects
local FILM: { [string]: { any } } = {
	SkyTear = { { "Portal", scale = 2.2 } },
	HoleOpen = { { "BlackHole", scale = 2.5 }, { "Explosion", scale = 0.35, color = Color3.fromRGB(160, 70, 255) } },
	HoleDisk = { { "BlackHole", scale = 2.5, life = 12 } },
	SparkHit = { { "Star", scale = 1.2 } },
	KingBurst = { { "BigBurst", scale = 1.2, color = Color3.fromRGB(255, 225, 90) }, { "Shock", scale = 1 } },
	SeedBlast = { { "Wind", scale = 0.25, color = Color3.fromRGB(255, 250, 235) } },
	CrateLand = { { "Shock", scale = 0.7 } },
	GoldPillar = { { "GoldBeam", scale = 1.2, color = Color3.fromRGB(255, 215, 90), up = true } },
	GoldRise = { { "Reveal", scale = 1, color = Color3.fromRGB(255, 215, 90) } },
	SunBreak = { { "Star", scale = 2.5 } },
	Firework = { { "BigBurst", scale = 1.1, tint = true } },
	ConfettiPop = { { "GoldBurst", scale = 0.7 } },
	GlitchTearOut = { { "PurpleBurst", scale = 1.6 }, { "Portal", scale = 1.4 } },
	LumpTear = { { "Rocks", scale = 0.3 } },
}

function PackFx.film(name: string, cf: CFrame, opts: any?)
	if not PackFx.on() then
		return
	end
	local list = FILM[name]
	if not list then
		return
	end
	local o = opts or {}
	local k = o.scale or 1
	for _, e in list do
		-- (a beam template runs along -Z: `up` stands it up into a pillar)
		PackFx.play(e[1], if e.up then CFrame.new(cf.Position) * CFrame.Angles(math.pi / 2, 0, 0) else cf, {
			scale = e.scale * k,
			color = if e.tint then o.color else e.color,
			life = if e.life and o.life then o.life else e.life,
			follow = o.follow,
			force = true,
		})
	end
end

-- Ends everything playing (a film's SKIP).
function PackFx.clear()
	for m in live do
		finish(m)
	end
end

-- (Studio only, to look at one) the workspace attribute PackFxPreview = "<template>[;scale[;r,g,b]]" plays it 30
-- studs in front of the camera.
if RunService:IsStudio() and RunService:IsClient() then
	workspace:GetAttributeChangedSignal("PackFxPreview"):Connect(function()
		local v = workspace:GetAttribute("PackFxPreview")
		if type(v) ~= "string" or v == "" then
			return
		end
		local name, scale, col = string.match(v, "^([^;]+);?([^;]*);?(.*)$")
		local cam = workspace.CurrentCamera
		if not (name and cam) then
			return
		end
		local r, g, b = string.match(col or "", "(%d+),(%d+),(%d+)")
		local at = cam.CFrame * CFrame.new(0, -4, -30)
		PackFx.play(name, CFrame.new(at.Position), {
			scale = tonumber(scale) or 1,
			color = if r then Color3.fromRGB(tonumber(r) :: number, tonumber(g) :: number, tonumber(b) :: number) else nil,
			force = true,
		})
	end)
end

return PackFx
