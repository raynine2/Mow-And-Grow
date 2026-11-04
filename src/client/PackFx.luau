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
local BossMoves = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("BossMoves")) :: any

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
			if o.soft then
				d.Brightness *= 0.55 -- (films: "the cutscenes are blinding")
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
			-- (owner, 4 Nov: "when i zoom uit a grrey box around me", "when i walk it turns grey") the pack's weather
			-- sits in see-through grey boxes (its emitting volumes): a plain part half see-through or more is hidden
			if not d:IsA("MeshPart") and d.Transparency >= 0.5 then
				d.Transparency = 1
			end
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
		if d:IsA("BasePart") and d.Transparency < 1 then
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
	soft: boolean?, -- dimmer (the films)
	stream: boolean?, -- its emitters stay on for `hold` s (a trail) instead of one burst
	locked: boolean?, -- (a loop) its particles move with it (a glowing eye), not left behind
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
	if o.stream then
		run(m, nil)
		task.delay(hold, function()
			for _, d in m:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Light") then
					(d :: any).Enabled = false
				end
			end
		end)
	else
		run(m, hold)
	end
	local follow = o.follow
	local conn: RBXScriptConnection? = nil
	if follow then
		-- (owner, 4 Nov, of the guardians' pink eyes: "it stays when it moves and it just looks bad") an effect riding
		-- on something keeps its particles on it, not as a trail left in the air
		for _, d in m:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.LockedToPart = true
			end
		end
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
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			-- (ambience follows the camera: what it already let go of stays where it is; an eye keeps its glow on it)
			d.LockedToPart = (opts and opts.locked) == true
		end
	end
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
-- A cut: a small swirl of clippings; a hit on a boss two crossing slash lines. (Plain hits: nothing extra.)
function PackFx.hit(event: string, pos: Vector3, grass: Color3, mine: boolean, scale: number, opts: any?)
	if not PackFx.on() then
		return
	end
	local o = opts or {}
	local s = math.clamp(scale or 1, 0.8, 2.2)
	local up = Vector3.new(0, 1.6 * s, 0)
	local light = grass:Lerp(WHITE, 0.25)
	if event == "cut" then
		PackFx.play("Cut", pos + up, { color = light, scale = 0.35 * s })
		return
	elseif event == "bossHit" then
		-- (two slash lines crossing: no spiky burst; owner: "u just use the supersaiyan effect for everything")
		PackFx.play("SlashX", pos, { color = grass:Lerp(WHITE, 0.35), scale = 0.55 })
		return
	elseif event == "bossSlam" then
		PackFx.play("Shock", pos + Vector3.new(0, 0.4, 0), { scale = 1.2 })
		return
	elseif string.sub(event, 1, 4) == "boss" or event == "reveal" then
		return
	end
	-- (owner, 4 Nov: "the hit fx is too much why do i have to see it going supersaiyen every hit like remove that")
	-- your hits and combo finishers keep only the game's own effects
end

-- A mutation found: a star flash and a magic circle in its colour.
function PackFx.reveal(at: Vector3, color: Color3, scale: number)
	if not PackFx.on() then
		return
	end
	PackFx.play("Reveal", at, { color = color, scale = 0.7 * math.clamp(scale, 1, 2), force = true })
	PackFx.play("Shock", at - Vector3.new(0, 1.5, 0), { color = color, scale = 0.5 * math.clamp(scale, 1, 2), force = true })
end

-- (owner: "all 8, 1-2 attacks each"; then, 4 Nov: "make their attcks more cooler with the new effects u have now")
-- Every boss has a look from the pack (THEME, by rig): every move it makes lands with its burst, sized to the
-- shape, in its colour; it flashes as it winds up (bossCast); its shots fly as glowing orbs (bossShot); its entrance,
-- rage and death get their own. Its signature moves (SIG, rig:kind) get more on top.
local THEME: { [string]: { burst: string, tint: Color3?, ground: string?, groundTint: Color3?, cast: string } } = {
	-- (owner, 4 Nov: "u just use the supersaiyan effect for everything ... look at alot of vfx"): each boss lands with
	-- its own kind of hit, none of them the spiky burst
	dandelion = { burst = "FlameRing", tint = Color3.fromRGB(255, 225, 90), ground = "DustKick", cast = "MagicCircle" }, -- a golden ring of fire
	harvest = { burst = "RingBurst", tint = Color3.fromRGB(255, 150, 50), ground = "Rocks", cast = "MagicCircle" }, -- a fiery ring and a shockwave
	sakura = { burst = "Petals", tint = Color3.fromRGB(255, 160, 210), ground = "GroundRing", groundTint = Color3.fromRGB(255, 170, 215), cast = "MagicCircle" }, -- petals and a ripple
	bramble = { burst = "GreenImpact", tint = Color3.fromRGB(150, 235, 90), ground = "Rocks", cast = "MagicCircle" }, -- grass blades out of a ring
	bog = { burst = "WaterSwirl", tint = Color3.fromRGB(140, 230, 110), ground = "Splash", groundTint = Color3.fromRGB(110, 200, 100), cast = "MagicCircle" }, -- a swirl of swamp water
	bunker = { burst = "BlueSlash", tint = Color3.fromRGB(170, 230, 255), ground = "IceSplash", cast = "MagicCircle" }, -- an icy slash
	hollow = { burst = "InkCrack", ground = "Crater", cast = "MagicCircle" }, -- a red crack in black ink, a crater
	jungle = { burst = "GreenSwirl", tint = Color3.fromRGB(120, 255, 210), ground = "Rocks", cast = "MagicCircle" }, -- a slashed ring
}

-- signature moves: more on top of the theme's burst
--   at = "centre" | "line" (n copies along it) | "edge" (n round the ring) | "beam" (laid along it)
--   size = studs the template covers at scale 1; tint = "ring" (the boss's colour) or a colour
local SIG: { [string]: { any } } = {
	["dandelion:slam"] = { { "Shock", at = "centre", size = 14 }, { "Dome", at = "centre", size = 80, tint = "ring" } },
	["dandelion:beam"] = { { "Beam", at = "beam", size = 200, tint = "ring" } },
	["harvest:fan"] = { { "Slash", at = "line", n = 3, size = 30, tint = Color3.fromRGB(255, 170, 60) } },
	["harvest:spread"] = { { "RingBurst", at = "centre", size = 14 } },
	["harvest:rings"] = { { "Shock", at = "centre", size = 14 } },
	["sakura:leap"] = { { "Shock", at = "centre", size = 14 }, { "Dome", at = "centre", size = 80, tint = Color3.fromRGB(255, 160, 205) } },
	["sakura:sweep"] = { { "Slash", at = "line", n = 2, size = 30, tint = Color3.fromRGB(255, 150, 200) }, { "SlashX", at = "centre", size = 20, tint = Color3.fromRGB(255, 150, 200) } },
	["bramble:combo"] = { { "Shock", at = "centre", size = 14 }, { "GrassStreak", at = "centre", size = 16 } },
	["bramble:safe"] = { { "Explosion", at = "centre", size = 120, tint = Color3.fromRGB(255, 220, 90) } },
	["bog:grid"] = { { "Spikes", at = "centre", size = 50, tint = Color3.fromRGB(90, 190, 90) } },
	["bog:stalk"] = { { "Spikes", at = "centre", size = 40, tint = Color3.fromRGB(90, 170, 80) } },
	["bog:tide"] = { { "Splash", at = "centre", size = 40, tint = Color3.fromRGB(110, 200, 100) } },
	["bunker:cone"] = { { "IceSpikes", at = "centre", size = 190 } },
	["bunker:burrow"] = { { "IceSpikes", at = "centre", size = 190 }, { "Shock", at = "centre", size = 14 } },
	["bunker:sink"] = { { "IceSplash", at = "centre", size = 50 } },
	["hollow:swing"] = { { "Slash", at = "line", n = 2, size = 30, tint = Color3.fromRGB(255, 90, 40) } },
	["hollow:dash"] = { { "InkCrack", at = "line", n = 3, size = 14 } },
	["hollow:mines"] = { { "Crater", at = "centre", size = 20 } },
	["jungle:star"] = { { "Shock", at = "centre", size = 14 } },
	["jungle:laser"] = { { "Beam", at = "beam", size = 200, tint = "ring" } },
	["jungle:gaze"] = { { "Beam", at = "beam", size = 200, tint = Color3.fromRGB(150, 255, 210) } },
	["jungle:meteors"] = { { "Explosion", at = "centre", size = 120, tint = Color3.fromRGB(120, 255, 210) } },
}

local function rigOf(z: number): string
	local ok, def = pcall(BossMoves.get, z)
	return if ok and def and def.rig then def.rig else "dandelion"
end

-- its shockwave colour (shared/BossMoves `ring`)
local function ringOf(z: number): Color3
	local ok, def = pcall(BossMoves.get, z)
	local hex = ok and def and def.ring
	local okc, c = pcall(Color3.fromHex, hex or "FFE46A")
	return if okc then c else Color3.fromRGB(255, 228, 106)
end

-- A shape's middle, a direction and a size in studs (and a length for lines).
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

local function place(e: any, s: any, mid: Vector3, flat: Vector3, size: number, len: number, color: Color3?)
	local name = e[1]
	if e.at == "centre" then
		PackFx.play(name, CFrame.lookAt(mid, mid + flat), { color = color, scale = math.clamp(size / e.size, 0.15, 3) })
	elseif e.at == "edge" then
		local r = size * 0.4
		for i = 1, e.n do
			local a = i / e.n * math.pi * 2
			local p = s.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			PackFx.play(name, p, { color = color, scale = math.clamp(size / 6 / e.size, 0.3, 1.5) })
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

-- A boss attack's shape landing (client/BossVfx.impact, for every move).
function PackFx.boss(z: number, kind: string, s: any, ring: Color3?)
	if not PackFx.on() or kind == "intro" then
		return -- (the entrance has its own: bossMoment)
	end
	ring = ring or ringOf(z)
	local rig = rigOf(z)
	local th = THEME[rig] or THEME.dandelion
	local mid, dir, size, len = shapeInfo(s)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local tint = th.tint or ring :: Color3
	-- the theme's burst on every shape: in the middle, along a line, or round a ring
	if s.type == "ring" then
		place({ th.burst, at = "edge", n = 6, size = 10 }, s, mid, flat, size, len, tint)
	elseif len > 0 then
		place({ th.burst, at = "line", n = math.clamp(math.floor(len / 14), 1, 4), size = 10 }, s, mid, flat, size, len, tint)
	else
		place({ th.burst, at = "centre", size = 10 }, s, mid, flat, size, len, tint)
		if th.ground and size >= 10 then
			place({ th.ground, at = "centre", size = 40 }, s, mid, flat, size, len, th.groundTint)
		end
	end
	for _, e in SIG[rig .. ":" .. kind] or {} do
		place(e, s, mid, flat, size, len, if e.tint == "ring" then ring elseif typeof(e.tint) == "Color3" then e.tint else nil)
	end
end

-- The boss winding up a move: a ring of its colour rolling out on the ground at its feet (a flash at its chest hid
-- its face: the Dandelion King's head glowed white the whole fight).
function PackFx.bossCast(z: number, at: Vector3, size: number, ring: Color3?)
	if not PackFx.on() then
		return
	end
	local th = THEME[rigOf(z)] or THEME.dandelion
	local c = th.tint or ring or ringOf(z)
	PackFx.play(th.cast, at, { color = c, scale = math.clamp(size / 30, 0.5, 1.6) })
	PackFx.play("Shock", at, { color = c, scale = math.clamp(size / 28, 0.5, 1.6) })
end

-- A boss shot in flight: a glowing orb riding on it.
function PackFx.bossShot(z: number, part: BasePart, flight: number, ring: Color3?)
	if not PackFx.on() then
		return
	end
	local th = THEME[rigOf(z)] or THEME.dandelion
	PackFx.play("Orb", part.CFrame, { color = th.tint or ring or ringOf(z), scale = 0.35, follow = part, hold = flight, stream = true, life = flight + 0.6 })
end

-- Its entrance (it climbs out), its rage (phase 2) and its fall.
function PackFx.bossMoment(z: number, what: string, at: Vector3, size: number, ring: Color3?)
	if not PackFx.on() then
		return
	end
	local th = THEME[rigOf(z)] or THEME.dandelion
	local tint = th.tint or ring or ringOf(z)
	local k = math.clamp(size / 30, 0.6, 2.5)
	if what == "intro" then
		-- it lands: a heavy ring, dust, its own hit
		PackFx.play("GroundSlam", at, { scale = k, force = true })
		PackFx.play("DustKick", at, { scale = 1.6 * k, force = true })
		PackFx.play(th.burst, at + Vector3.new(0, 4 * k, 0), { color = tint, scale = 1.1 * k, force = true })
		if th.ground then
			PackFx.play(th.ground, at, { color = th.groundTint, scale = 0.6 * k, force = true })
		end
	elseif what == "rage" then
		-- speed lines, a red crack and a red rift behind it
		PackFx.play("SpeedLines", at + Vector3.new(0, 6 * k, 0), { scale = 1.5 * k, force = true })
		PackFx.play("InkCrack", at + Vector3.new(0, 6 * k, 0), { color = Color3.fromRGB(255, 80, 60), scale = 1.4 * k, force = true })
		PackFx.play("Shock", at, { color = Color3.fromRGB(255, 90, 70), scale = 2 * k, force = true })
		PackFx.play("RedRift", at + Vector3.new(0, 8 * k, 0), { scale = k, force = true })
	elseif what == "death" then
		PackFx.play("BossDeath", at + Vector3.new(0, 4 * k, 0), { color = tint, scale = 1.2 * k, force = true })
		PackFx.play("LightPillar", at, { color = tint, scale = 1.2 * k, force = true })
		PackFx.play("Glint", at + Vector3.new(0, 10 * k, 0), { scale = 1.5 * k, force = true })
	end
end

-- (owner: "intro én ending") the films' moments: each named FilmVfx moment also plays its pack effects
local FILM: { [string]: { any } } = {
	-- (owner, 4 Nov: "look at alot of vfx and fx": every moment has its own look now, none of the spiky bursts)
	-- the opening
	SkyTear = { { "Rift", scale = 2.2 }, { "Glitch", scale = 2 } },
	SparkHit = { { "InkHit", scale = 0.6 }, { "Scribble", scale = 0.5 } },
	KingBurst = { { "InkSwirl", scale = 0.8 }, { "FlameRing", scale = 1.4, color = Color3.fromRGB(255, 225, 90) } },
	SeedBlast = { { "LeafSwirl", scale = 1.2 } },
	BlowFlash = { { "WindVortex", scale = 1 }, { "LeafSwirl", scale = 1.4 } },
	GrassRise = { { "GrassTuft", scale = 1 }, { "GreenImpact", scale = 0.6 }, { "GrassStreak", scale = 0.8 } },
	HeroCall = { { "LightPillar", scale = 1.2, color = Color3.fromRGB(255, 225, 120) }, { "GroundRing", scale = 1, color = Color3.fromRGB(255, 220, 110) } },
	MowerLand = { { "DustKick", scale = 1.4 }, { "GroundRing", scale = 0.7 }, { "Rocks", scale = 0.15 } },
	CrateLand = { { "DustKick", scale = 1.6 }, { "GroundSlam", scale = 0.8 } },
	TitleHit = { { "Glint", scale = 0.8 } },
	EyeOpen = { { "VoidEye", scale = 1 } },
	-- an anime impact frame (client/FilmPanels) in either film
	ImpactFrame = { { "InkSwirl", scale = 0.6 }, { "SpeedLines", scale = 1.2 } },
	-- the ending
	GoldPillar = { { "GoldBeam", scale = 1.2, color = Color3.fromRGB(255, 215, 90), up = true }, { "GroundRing", scale = 1.2, color = Color3.fromRGB(255, 220, 110) } },
	GoldRise = { { "Glint", scale = 1 }, { "Reveal", scale = 1, color = Color3.fromRGB(255, 215, 90) } },
	SunBreak = { { "WhiteFlash", scale = 1.2 }, { "Glint", scale = 1.4 } },
	Firework = { { "Petals", scale = 1.6, tint = true } },
	ConfettiPop = { { "Petals", scale = 1, color = Color3.fromRGB(255, 220, 110) } },
	GlitchTearOut = { { "Glitch", scale = 2.2 }, { "Rift", scale = 1.4 } },
	HoleOpen = { { "BlackHole", scale = 2.5 }, { "Glitch", scale = 3 }, { "Scribble", scale = 1.2 } },
	HoleDisk = { { "BlackHole", scale = 2.5, life = 12 } },
	HoleHalo = { { "Portal", scale = 3, life = 12 } },
	LumpTear = { { "Rocks", scale = 0.3 }, { "Scribble", scale = 0.6 } },
	PinkEye = { { "Orb", scale = 0.12, color = Color3.fromRGB(255, 60, 200), stream = true, hold = 6, life = 6.5 } },
	SparkFall = { { "Orb", scale = 0.3, color = Color3.fromRGB(255, 120, 230), stream = true, hold = 3, life = 3.5 } },
	SeedInhale = { { "Absorb", scale = 1 } },
	SeedDrift = { { "LeafSwirl", scale = 1.6 } },
	NightStutter = { { "Glitch", scale = 1.4 } },
	HoleSwell = { { "BlackHole", scale = 1.2 }, { "Glitch", scale = 2 } },
	-- (4 Nov) the rift a guardian is corrupted through: the twin portal opens behind it (owner: "yes portals is a good
	-- idea"), glitch streaks, and it strikes out of it into its head
	RiftOpen = { { "Rift", scale = 1.6, life = 3.2 }, { "Glitch", scale = 1.6 } },
	-- (a lightning scribble at the rift: a beam from it to the head crossed the guardian's body in the picture)
	RiftStrike = { { "Scribble", scale = 0.7 }, { "Glitch", scale = 1 } },
	BoltHit = { { "Bolt", scale = 0.6, color = Color3.fromRGB(220, 120, 255) }, { "CorruptHit", scale = 0.8 } },
	LiftAura = { { "Orb", scale = 0.4, color = Color3.fromRGB(200, 90, 255), stream = true, hold = 3, life = 3.5 } },
	-- (owner, 4 Nov: "u have to also see the boss fully and not being blovked by a hole") the demon climbs out in front
	-- of its rift: the portal and a dark pillar behind it, a black crater at its feet (owner's pick), the hole's black
	-- ball fades away
	DemonRise = { { "Rift", scale = 3, behind = 18, life = 6 }, { "DarkPillar", scale = 2, behind = 10 }, { "Crater", scale = 2 }, { "Glitch", scale = 2.5, behind = 6 } },
	DemonRoar = { { "SpeedLines", scale = 1.6 }, { "CorruptHit", scale = 1.2 }, { "Shock", scale = 1.2, color = Color3.fromRGB(255, 60, 200) } },
}

-- True when the films' moment `name` is drawn by the pack (client/FilmVfx then leaves its old template out).
function PackFx.filmHas(name: string): boolean
	return PackFx.on() and FILM[name] ~= nil
end

-- Plays a films' moment. -> its first effect's clone (nil when it isn't the pack's)
function PackFx.film(name: string, cf: CFrame, opts: any?): Model?
	if not PackFx.on() then
		return nil
	end
	local list = FILM[name]
	if not list then
		return nil
	end
	local o = opts or {}
	local k = o.scale or 1
	local cam = workspace.CurrentCamera
	if o.screen and cam then
		-- (a moment laid over the picture: in front of the camera)
		cf = cam.CFrame * CFrame.new(0, 0, -o.screen)
		k *= o.screen / 20
	end
	if name == "DemonRise" then
		-- (the black hole's ball would stand in front of the demon)
		for mm in live do
			if mm:IsA("Model") and mm.Name == "BlackHole" then
				for _, d in mm:GetDescendants() do
					if d:IsA("BasePart") then
						TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					end
				end
			end
		end
	end
	local first: Model? = nil
	for _, e in list do
		-- (a beam template runs along -Z: `up` stands it up into a pillar)
		local sc = (e.scale or 1) * k
		if e.fit then
			-- (a beam template laid along -Z, sized to reach `length` studs)
			local t = template(e[1])
			sc = (o.length or 40) / ((t and t:GetAttribute("Length") :: number?) or 200)
		end
		local at = cf
		if e.behind and cam then
			-- (pushed away from the camera, so whatever is at `cf` stands in front of it)
			local away = cf.Position - cam.CFrame.Position
			if away.Magnitude > 0.1 then
				local p = cf.Position + away.Unit * e.behind
				at = CFrame.lookAt(p, cam.CFrame.Position)
			end
		end
		local m = PackFx.play(e[1], if e.up then CFrame.new(at.Position) * CFrame.Angles(math.pi / 2, 0, 0) else at, {
			scale = sc,
			color = if e.tint then o.color else e.color,
			life = if e.life and o.life then o.life else e.life,
			hold = e.hold,
			stream = e.stream,
			follow = o.follow,
			force = true,
			soft = true,
		})
		first = first or m
	end
	return first
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
