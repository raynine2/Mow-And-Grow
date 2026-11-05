-- THE FINALE, "YOU" (Films v2, 5 Nov 2026). The owner scrapped the old ending's film (client/Ending's own, kept:
-- Config.FILMS_V2.on = false brings it back) and asked for one "like an anime fight", with the end boss coming in
-- "like Toji in the domain"; his answers: the end boss is the player's own dark copy ("a fight against yourself"),
-- ~60 s, bracket subtitles, no voices. Story and shot list: docs/FilmsV2.md. ~60 s, cut to the same licensed track as
-- the opening (Config.FILM_SOUNDS.animeCharge, 100 BPM) in three pieces, with silence between:
--   M1, the track from 45.0 (film 0..30): the quiet bars, the build and its hit at 60.08, the realm; it fades out.
--   silence (film 30..42): the copy walks in.
--   M2, the track from 126.0 (film 42..53.5): Rayan's attack is caught on its hit at 127.45; the copy's snip lands on
--       the drop at 132.08 (the very beat the player's punch landed on in the opening).
--   M3, the track from 181.9 (film 54..): its last hit at 182.5 slams the card in, and it rings out.
--   A. MORNING: sunrise over the mown meadow; the player walks out of the gold dust, cut on the beats; Rayan: "Every
--      last blade."
--   B. ONE LEFT: a pink shard twitches in the stubble. Rayan opens his realm: white, then an endless gold lawn under a
--      gold glass sky, the eight guardians standing round it. "Nowhere to run." The shard rips a tear in it.
--   C. YOU: nothing comes out. A footstep. A black foot on the gold, pink pixels rippling out. The player's DARK COPY
--      walks in, calm; the player's face; the copy's face, theirs, black, magenta eyes. "There's no glitch in it."
--      "It's just... you?"
--   D. THE LESSON: Rayan attacks; the copy catches the blades bare-handed, takes the shears, throws him; one snip on
--      the drop: the realm's sky breaks, its strongest guardian falls. The copy looks into the lens: "Thanks for the
--      lesson." Black. YOU. THE FINAL FIGHT, COMING SOON.
-- Each shot names the reference shot it's built on (the owner's videos): SR = "Sukuna Raid Intro" (MobWshN54vo, at
-- its seconds), TSB = "Unlimited Flexworks" (qRjNRrKiaTc), BL = the Blue Lock cutscenes (_SaVIYa7dnI).
-- Finale.prepare() builds everything under the black cover, Finale.play() runs it, Finale.stop() takes it all away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local MowALawn = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(MowALawn:WaitForChild("Config")) :: any
local BossMoves = require(MowALawn:WaitForChild("BossMoves")) :: any
local FxIds = require(MowALawn:WaitForChild("FxIds")) :: { [string]: string }
local Film = require(script.Parent.Film)
local FilmAudio = require(script.Parent.FilmAudio)
local IntroUi = require(script.Parent.IntroUi)
local AnimeFx = require(script.Parent.AnimeFx)
local Puppet = require(script.Parent.Puppet)
local Shears = require(script.Parent.Shears)
local FilmSet = require(script.Parent.FilmSet)
local PackFx = require(script.Parent.PackFx)

local Finale = {}
local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 40, 170)
local HOT = Color3.fromRGB(255, 120, 220)
local GOLD = Color3.fromRGB(255, 200, 70)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local INK = Color3.fromRGB(14, 10, 20)
local SUN = Color3.fromRGB(255, 196, 140)
local UP = Vector3.yAxis

-- the beats (film seconds), and where the three pieces of the track start (above)
local M1_AT, M2_AT, M3_AT = 45.0, 126.0, 181.9
local T = {
	sun = 0.68, feet = 3.08, fist = 3.68, walk = 4.28, back = 5.48, rayan = 6.68, valley = 8.48,
	build = 10.2, oneLeft = 11.6, raise = 12.68, realm = 15.08, guard = 17.48, nowhere = 18.68, twitch = 20.48,
	flee = 21.68, rip = 24.68, look = 27.08, quiet = 30.0,
	step1 = 32.0, step2 = 32.78, walkIn = 33.56, react = 35.6, step3 = 36.5, face = 37.4, glitch = 39.4, you = 41.0,
	attack = 42.0, catch = 43.45, take = 44.2, thrown = 45.5, lift = 46.6, snip = 48.08, fall = 49.1, turn = 51.0,
	black = 53.5, m3 = 54.0, card = 54.6, soon = 57.0, out = 60.0,
}
Finale.T = T

-- the places. The meadow (FilmSet.meadow's own frame: +X east, -Z north, the ground at 0; the sun rises in the east):
local P_FROM = Vector3.new(30, 0, -26) -- the player walks in from here (out of the sunrise)
local P_TO = Vector3.new(4, 0, -23) -- to here, beside Rayan
local R_AT = Vector3.new(-1, 0, -21) -- Rayan, waiting, looking out at the sunrise
local BESIDE = Vector3.new(-0.5, 0, -25.6) -- the player beside him (north of him), the two looking at the sunrise
local SHARD_AT = Vector3.new(1.5, 0.35, -16.5) -- the last pink shard, in the stubble behind them
-- the realm (FilmSet.realm's frame: the middle at 0, the guardians in a ring 58 out, the gold glass sky 300 out):
local G_R = Vector3.new(-3, 0, 6) -- Rayan
local G_P = Vector3.new(3, 0, 6) -- the player
local G_SHARD = Vector3.new(0, 0.6, -2)
local TEAR = Vector3.new(0, 0, -62) -- the tear (between two guardians, its foot on the ground)
local TEAR_H = 44
local C_STOP = Vector3.new(0, 0, -18.6) -- where the copy stops (24 studs from them)
local COPY_RATE = 0.64 -- its walk (cycles a second): ~2.2 studs a second, a footfall every 0.78 s

-------------------------------------------------------------------------------------------------------------
-- state
-------------------------------------------------------------------------------------------------------------
local S: any = nil -- the meadow
local G: any = nil -- the realm
local R: any = nil -- Rayan
local H: any = nil -- the player
local C: any = nil -- the player's dark copy
local SH: any = nil -- the shears
local shard: Model? = nil
local tear: any = nil
local stage: Folder? = nil
local skyWas: Vector3? = nil -- (the sky turned for the sunrise, put back by Finale.stop)
local playing = false
local prepared = false
local conns: { RBXScriptConnection } = {}
local events: { { at: number, fn: () -> () } } = {}
local tracks: { [string]: (dt: number, t: number) -> () } = {}
local music: { [number]: any } = {}
local clockMode = "free"
local freeBase, freeStart = 0, 0
local lastNow, lastAdvance, lastPos = 0, 0, -1
local rate = 1
local held: number? = nil
local shearsMode = "shoulder"
local shearsOpen = 0
local copyEyes: { BasePart } = {}
local copyGlow: Highlight? = nil
local studioControls: () -> ()

local function mv(v: Vector3, y: number?): Vector3
	return (S.at * CFrame.new(v.X, y or v.Y, v.Z)).Position
end
local function gv(v: Vector3, y: number?): Vector3
	return (G.at * CFrame.new(v.X, y or v.Y, v.Z)).Position
end
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-------------------------------------------------------------------------------------------------------------
-- the clock: the track's own position while a piece of it plays, the plain clock in the silences
-------------------------------------------------------------------------------------------------------------
local function setFree(t: number)
	freeBase, freeStart = t, os.clock()
	clockMode = "free"
end

local PIECES = { { at = M1_AT, from = 0 }, { at = M2_AT, from = T.attack }, { at = M3_AT, from = T.m3 } }

local function now(): number
	if held then
		return held
	end
	local t: number
	local piece = tonumber(string.match(clockMode, "^m(%d)$"))
	local cue = piece and music[piece]
	local s = cue and cue.sound
	if piece and s and s.Parent and s.IsPlaying and s.TimePosition >= PIECES[piece].at - 0.02 then
		t = PIECES[piece].from + (s.TimePosition - PIECES[piece].at)
		-- (the plain clock kept level with the track, so when the track ends it carries on from here: tested in
		-- Studio, after the last piece ended it ran on from where it was last set, half a minute back, and jumped)
		freeBase, freeStart = t, os.clock()
	else
		t = freeBase + (os.clock() - freeStart) * rate
	end
	-- (a stalled or finished track: the plain clock takes over from where it was)
	if clockMode ~= "free" then
		if t ~= lastPos then
			lastPos = t
			lastAdvance = os.clock()
		elseif os.clock() - lastAdvance > 0.5 then
			setFree(lastNow)
			t = lastNow
		end
	end
	if t < lastNow then
		t = lastNow
	end
	lastNow = t
	return t
end
Finale.now = now

-- start piece `i` of the track (the clock follows it)
local function playPiece(i: number, volume: number?)
	local cue = FilmAudio.music(Config.FILMS_V2.music, { fade = 0, at = PIECES[i].at, loop = false, volume = volume or 1 })
	music[i] = cue
	lastPos, lastAdvance = -1, os.clock()
	clockMode = "m" .. i
end

local function after(t: number, fn: () -> ())
	table.insert(events, { at = t, fn = fn })
end

local function waitUntil(t: number): boolean
	while playing and now() < t do
		task.wait()
	end
	return playing
end

-------------------------------------------------------------------------------------------------------------
-- shots: cut to a shot that runs until film time `untilT`; what stands in the lens's way is hidden every frame
-------------------------------------------------------------------------------------------------------------
local clearView: (cf: CFrame, focus: Vector3?, extra: { Vector3 }?) -> ()
local tryCam: any = nil
-- (opts.keep: a function giving more points to keep the view to clear, for a shot with two subjects apart)
local function shot(untilT: number, fn: (k: number, t: number) -> (CFrame, number, Vector3?), opts: any?): boolean
	if not playing then
		return false
	end
	local keep = opts and opts.keep
	Film.cut(math.max(untilT - now(), 0.05), function(k: number, t: number)
		local cf, fov, focus = fn(k, t)
		if tryCam then
			cf, fov, focus = tryCam.cf, tryCam.fov, tryCam.focus
		end
		clearView(cf, focus, if keep and not tryCam then keep() else nil)
		return cf, fov, focus
	end, opts)
	return waitUntil(untilT)
end

local mm = Film.mm
local look = Film.look
local ease = { out = Film.out, inn = Film.inn, inOut = Film.inOut, smooth = Film.smooth }

-- a puppet standing at `p` facing `q` (world points; on the ground at p's height)
local function standW(pup: any, p: Vector3, q: Vector3)
	local dir = flat(q - p)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, -1)
	end
	pup.root = CFrame.lookAt(p, p + dir) + Vector3.new(0, -pup.ground, 0)
end
local function headCf(pup: any): CFrame
	local h = pup:part("Head")
	return if h then (pup.world[h] or h.CFrame) else pup.root * CFrame.new(0, 1.5, 0)
end
local function headOf(pup: any): Vector3
	return headCf(pup).Position
end
local function eyesOf(pup: any, side: number?, up: number?): Vector3
	local h = pup:part("Head")
	local size = if h then h.Size else Vector3.new(1.2, 1.2, 1.2)
	return (headCf(pup) * CFrame.new(side or 0, size.Y * (up or 0.06), -size.Z * 0.5)).Position
end
local function chestOf(pup: any): CFrame
	local c = pup:part("UpperTorso")
	return if c then (pup.world[c] or c.CFrame) else pup.root
end
local function groundOf(pup: any): number
	return pup.root.Position.Y + pup.ground
end

local function sfx(key: string, volume: number?, pitch: number?)
	FilmAudio.sfx(key, { volume = volume, pitch = pitch })
end

local function fx(name: string, where: CFrame | Vector3, opts: any?): Model?
	local o = opts or {}
	o.force = true
	o.soft = if o.soft == nil then true else o.soft
	local ok, m = pcall(PackFx.play, name, where, o)
	return if ok then m else nil
end

local function stageFolder(): Folder
	if stage and stage.Parent then
		return stage
	end
	local f = Instance.new("Folder")
	f.Name = "FinaleStage"
	f.Parent = workspace
	stage = f
	return f
end

local function neon(size: Vector3, cf: CFrame, color: Color3, alpha: number?): Part
	local p = FilmSet.block(stageFolder(), size, cf, color, Enum.Material.Neon, "Fx")
	p.Transparency = alpha or 0
	p.CastShadow = false
	return p
end

local function fadeOut(p: BasePart, time: number, grow: Vector3?)
	local goal: any = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(time + 0.05, function()
		p:Destroy()
	end)
end

-- a light that flares and fades (a hit, a crash, a tear)
local function burst(pos: Vector3, color: Color3, brightness: number, range: number, life: number)
	local holder = Instance.new("Part")
	holder.Name = "Burst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(pos)
	holder.Parent = stageFolder()
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = holder
	TweenService:Create(l, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	task.delay(life + 0.1, function()
		holder:Destroy()
	end)
end

-- a key light for close-ups (nil: off)
local keyPart: Part? = nil
local function key(pos: Vector3?, color: Color3?, brightness: number?, range: number?)
	if not keyPart or not keyPart.Parent then
		local p = Instance.new("Part")
		p.Name = "KeyLight"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one * 0.2
		local l = Instance.new("PointLight")
		l.Shadows = false
		l.Parent = p
		p.Parent = stageFolder()
		keyPart = p
	end
	local kp = keyPart :: Part
	local l = kp:FindFirstChildOfClass("PointLight") :: PointLight
	if not pos then
		l.Enabled = false
		return
	end
	kp.Position = pos
	l.Enabled = true
	l.Color = color or WHITE
	l.Brightness = brightness or 1.5
	l.Range = range or 10
end

-------------------------------------------------------------------------------------------------------------
-- the lens's way kept clear: the meadow's stubble and props, the realm's gold tufts, the guardians' feet
-------------------------------------------------------------------------------------------------------------
local hidden: { [BasePart]: boolean } = {}
local function hideIf(parts: { BasePart }, on: boolean)
	for _, p in parts do
		if on ~= (hidden[p] == true) then
			hidden[p] = if on then true else nil
			p.LocalTransparencyModifier = if on then 1 else 0
		end
	end
end
local function inTheWay(q: Vector3, r: number, p: Vector3, dir: Vector3?, segLen: number): boolean
	if (q - p).Magnitude < r + 1 then
		return true
	end
	if dir then
		local along = (q - p):Dot(dir)
		if along > 0 and along < segLen - r * 0.5 - 1 then
			return ((q - p) - dir * along).Magnitude < r * 0.8
		end
	end
	return false
end
-- the lines from the lens to what it's looking at (the focus, and a shot's extra points)
local sightDirs: { Vector3 } = {}
local sightLens: { number } = {}
local function blocks(q: Vector3, r: number, p: Vector3): boolean
	if #sightDirs == 0 then
		return inTheWay(q, r, p, nil, 0)
	end
	for i, dir in sightDirs do
		if inTheWay(q, r, p, dir, sightLens[i]) then
			return true
		end
	end
	return false
end
clearView = function(cf: CFrame, focus: Vector3?, extra: { Vector3 }?)
	local p = cf.Position
	table.clear(sightDirs)
	table.clear(sightLens)
	for _, q in { focus, table.unpack(extra or {}) } do
		local seg = q - p
		local len = seg.Magnitude
		if len > 0.01 then
			table.insert(sightDirs, seg / len)
			table.insert(sightLens, len)
		end
	end
	if S and (p - S.at.Position).Magnitude < 600 then
		for _, pr in S.props or {} do
			if pr.radius < 24 then
				local on = blocks(if pr.follow then pr.follow.Position else pr.center, pr.radius, p)
				if on ~= pr.hidden then
					pr.hidden = on
					for _, part in pr.parts do
						part.LocalTransparencyModifier = if on then 1 else 0
					end
				end
			end
		end
		for _, t in S.tufts do
			local part = t.part
			if part and part.Parent then
				hideIf(t.parts or { part }, blocks(t.at.Position, 1.6 * t.scale, p))
			end
		end
	end
	if G and G.tuftParts and (p - G.at.Position).Magnitude < 600 then
		for _, rec in G.tuftParts do
			hideIf(rec.parts, blocks(rec.at, rec.r, p))
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the cast
-------------------------------------------------------------------------------------------------------------
local function playerModel(): Model?
	local char = player.Character
	if not char then
		return nil
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, m = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not m then
		return nil
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
			d:Destroy()
		elseif d.Name == "BundleStack" then
			d:Destroy()
		end
	end
	return m
end

local function ownerModel(): Model?
	local cast = ReplicatedStorage:FindFirstChild("FilmCast")
	local m = cast and cast:FindFirstChild("Owner")
	if m and m:IsA("Model") then
		return m
	end
	return playerModel()
end

-- The dark copy: the player's own body, every part ink-black (their clothes' shapes, no colours), no face, a magenta
-- outline, two magenta eyes that glow (placed on the face each frame).
local function darken(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = INK
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
			d.VertexColor = Vector3.new(0.06, 0.04, 0.08)
		elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		elseif d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local hl = Instance.new("Highlight")
	hl.Name = "Glitch"
	hl.FillTransparency = 1
	hl.OutlineColor = PINK
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
end

local function makeEyes(parent: Instance): { BasePart }
	local out = {}
	for i = 1, 2 do
		-- (thin slits slanting down to the middle: tested in Studio, two flat level bars on a black block head looked
		-- like another game's monster, and with their inner ends raised they looked worried, not angry)
		local e = FilmSet.block(parent, Vector3.new(0.25, 0.055, 0.05), CFrame.identity, Color3.fromRGB(255, 70, 210), Enum.Material.Neon, "CopyEye")
		e.CastShadow = false
		local l = Instance.new("PointLight")
		l.Color = PINK
		l.Range = 3
		l.Brightness = 1.2
		l.Shadows = false
		l.Parent = e
		out[i] = e
	end
	return out
end

local function placeEyes()
	if not C or #copyEyes == 0 then
		return
	end
	local h = C:part("Head")
	local hc = headCf(C)
	local size = if h then h.Size else Vector3.new(1.2, 1.2, 1.2)
	if copyGlow then
		copyGlow.Enabled = C.shown
	end
	for i, e in copyEyes do
		local side = if i == 1 then -0.2 else 0.2
		e.CFrame = hc * CFrame.new(side * size.X / 1.2, size.Y * 0.07, -size.Z * 0.5 - 0.02) * CFrame.Angles(0, 0, math.rad(if i == 1 then -15 else 15))
		e.LocalTransparencyModifier = if C.shown then 0 else 1
	end
end

-------------------------------------------------------------------------------------------------------------
-- the shears follow whoever holds them
-------------------------------------------------------------------------------------------------------------
local corrupt = 0 -- (0..1: how far the copy's black has crept up the blades)
local function placeShears()
	if not SH or not R then
		return
	end
	local mode = shearsMode
	if mode == "hidden" then
		SH:show(false)
		return
	end
	SH:show(true)
	if mode == "shoulder" then
		local rh = R:grip("Right").Position
		local chest = chestOf(R)
		local dir = (-chest.LookVector * 0.82 + UP * 0.52 + chest.RightVector * 0.12).Unit
		SH:hold(rh, dir, chest.RightVector, 4)
	elseif mode == "raise" then
		-- held up high in his right hand, the blades to the sky, open
		local rh = R:grip("Right").Position
		local root = R.root
		SH:hold(rh, (UP * 0.9 + root.LookVector * 0.25).Unit, root.RightVector, shearsOpen)
	elseif mode == "lunge" then
		-- both hands, the blades straight ahead, open
		local rh, lh = R:grip("Right").Position, R:grip("Left").Position
		local fwd = flat(R.root.LookVector).Unit
		SH:grip2(rh, lh, fwd + UP * 0.05)
	elseif mode == "caught" then
		-- shut, the tips in the copy's raised hand, Rayan's hands on the handles
		local tip = C:grip("Right").Position
		local rh = R:grip("Right").Position
		local d = tip - rh
		local dir = if d.Magnitude > 0.1 then d.Unit else R.root.LookVector
		SH:place(CFrame.lookAt(tip - dir * Shears.BLADE, tip, R.root.RightVector), 0)
	elseif mode == "copy" then
		-- in the copy's right hand, held up before it
		local rh = C:grip("Right").Position
		local chest = chestOf(C)
		SH:hold(rh, (UP * 0.8 + chest.LookVector * 0.45).Unit, chest.RightVector, shearsOpen)
	end
end

-------------------------------------------------------------------------------------------------------------
-- props: the last shard, the tear, the copy's footprints
-------------------------------------------------------------------------------------------------------------
-- the last pink shard: a little pink crystal, a light in it
local function makeShard(at: Vector3): Model
	-- the game's own gem (the gem drop, client/LootFx), cut pink: tested in Studio, three neon blocks read as a little
	-- figure or a white slab, the faceted gem reads as a crystal at once
	local gem = FilmSet.prop("gem_drop", CFrame.new(at - Vector3.new(0, 0.7, 0)), 0.8, stageFolder())
	if gem then
		gem.Name = "LastShard"
		local glow: BasePart? = nil
		for _, d in gem:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
				if d.Material == Enum.Material.Neon then
					d.Color = HOT
					glow = glow or d
				elseif d.Color.R > 0.3 then
					d.Color = Color3.fromRGB(255, 140, 215) -- (its light facets)
				else
					d.Color = Color3.fromRGB(190, 20, 130) -- (its dark ones)
				end
			end
		end
		local l = Instance.new("PointLight")
		l.Color = PINK
		l.Range = 8
		l.Brightness = 2
		l.Shadows = false
		l.Parent = glow or gem:FindFirstChildWhichIsA("BasePart", true)
		return gem
	end
	local m = Instance.new("Model")
	m.Name = "LastShard"
	-- (without the gem: a small crystal cluster growing up out of one point)
	local base = at - Vector3.new(0, 0.75, 0)
	local function piece(size: Vector3, from: Vector3, dir: Vector3, twist: number, color: Color3, name: string): BasePart
		local d = dir.Unit
		local r = d:Cross(Vector3.new(0.3, 0.1, 1)).Unit
		local cf = CFrame.fromMatrix(from + d * (size.Y / 2), r, d) * CFrame.Angles(0, twist, 0)
		return FilmSet.block(m, size, cf, color, Enum.Material.Neon, name)
	end
	local a = piece(Vector3.new(0.5, 1.7, 0.5), base, Vector3.new(0.1, 1, -0.06), math.rad(45), HOT, "Core")
	local b = piece(Vector3.new(0.32, 0.95, 0.32), base + Vector3.new(0.14, 0.05, 0.06), Vector3.new(0.6, 1, 0.2), math.rad(30), PINK, "Spur")
	local c = piece(Vector3.new(0.28, 0.75, 0.28), base + Vector3.new(-0.12, 0.05, -0.08), Vector3.new(-0.55, 1, -0.3), math.rad(10), PINK, "Spur")
	for _, p in { a, b, c } do
		p.CastShadow = false
	end
	local l = Instance.new("PointLight")
	l.Color = PINK
	l.Range = 8
	l.Brightness = 2
	l.Shadows = false
	l.Parent = a
	m.PrimaryPart = a
	m.Parent = stageFolder()
	return m
end

-- A footstep's effects are particles, not parts (tested in Studio: neon ring segments seen from the ground read as
-- planks of light): one emitter function at a spot on the ground, gone after 3 s.
local function stepEmitter(at: Vector3): (string, { [string]: any }, number) -> ()
	local p = FilmSet.block(stageFolder(), Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), WHITE, Enum.Material.SmoothPlastic, "Step")
	p.Transparency = 1
	local a = Instance.new("Attachment")
	a.Parent = p
	task.delay(3, function()
		p:Destroy()
	end)
	return function(tex: string, props: { [string]: any }, count: number)
		local e = Instance.new("ParticleEmitter")
		e.Texture = tex
		e.Rate = 0
		e.EmissionDirection = Enum.NormalId.Top
		e.LightInfluence = 0
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = a
		e:Emit(count)
	end
end
-- a flat ring running out over the ground from a step (TSB's walk-in)
local function stepRing(emitter: (string, { [string]: any }, number) -> (), color: Color3, glow: number)
	emitter(FxIds.ring, {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, -- (flat on the ground)
		Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(1.1),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(color),
		LightEmission = glow,
	}, 1)
end
-- a step in the morning: a soft gold ring spreading over the ground, gold motes kicked up into the low sun, a little dust
local function goldStep(at: Vector3)
	local emitter = stepEmitter(at)
	stepRing(emitter, Color3.fromRGB(255, 214, 120), 1)
	emitter(FxIds.glow, {
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(1.2, 3),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -0.6, 0),
		Drag = 1.5,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.04) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 150)),
		LightEmission = 1,
	}, 14)
	emitter(FxIds.poof, {
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(1, 2.2),
		SpreadAngle = Vector2.new(80, 20),
		Drag = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(230, 190, 150)),
		LightEmission = 0.2,
		LightInfluence = 0.6,
	}, 5)
end

-- pink pixels popping up off the ground round a point (a footstep, a twitch)
local function pixels(at: Vector3, count: number, spread: number)
	local rng = Random.new()
	for _ = 1, count do
		local off = Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread))
		-- (small: tested in Studio, at 0.4 studs they were blocks as big as the shard's spurs)
		local s = rng:NextNumber(0.1, 0.24)
		local p = neon(Vector3.one * s, CFrame.new(at + off + Vector3.new(0, s / 2, 0)), if rng:NextNumber() < 0.75 then PINK else Color3.fromRGB(90, 230, 255), 0)
		local goal = CFrame.new(at + off * 1.4 + Vector3.new(0, rng:NextNumber(0.8, 2.6), 0))
		TweenService:Create(p, TweenInfo.new(rng:NextNumber(0.35, 0.7), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal, Transparency = 1 }):Play()
		task.delay(0.75, function()
			p:Destroy()
		end)
	end
end

-- The tear in the realm: a tall jagged rift of black, its edge white-hot and pink, a light pouring out of it. It
-- opens from a slit (tear.open(k) 0..1), flickers (tear.update(t)).
local function makeTear(base: Vector3, facing: Vector3): any
	local f = CFrame.lookAt(base, base + facing)
	local folder = Instance.new("Folder")
	folder.Name = "Tear"
	folder.Parent = stageFolder()
	local rng = Random.new(31)
	local rows = 18
	local spans: { { core: BasePart, rimL: BasePart, rimR: BasePart, y: number, w: number, jag: number } } = {}
	for i = 0, rows - 1 do
		local k = (i + 0.5) / rows
		local y = k * TEAR_H
		local w = math.sin(math.pi * k) ^ 0.7 * 9 + rng:NextNumber(-0.8, 0.8)
		local jag = rng:NextNumber(-1.2, 1.2)
		local core = FilmSet.block(folder, Vector3.new(1, TEAR_H / rows + 0.1, 0.6), f, Color3.fromRGB(4, 0, 8), Enum.Material.SmoothPlastic, "Void")
		core.CastShadow = false
		local rimL = FilmSet.block(folder, Vector3.new(0.5, TEAR_H / rows + 0.3, 0.7), f, Color3.fromRGB(255, 160, 235), Enum.Material.Neon, "Rim")
		local rimR = FilmSet.block(folder, Vector3.new(0.5, TEAR_H / rows + 0.3, 0.7), f, Color3.fromRGB(255, 160, 235), Enum.Material.Neon, "Rim")
		rimL.CastShadow, rimR.CastShadow = false, false
		table.insert(spans, { core = core, rimL = rimL, rimR = rimR, y = y, w = math.max(w, 0.6), jag = jag })
	end
	local glow = FilmSet.block(folder, Vector3.new(1, 1, 1), f * CFrame.new(0, TEAR_H / 2, 2), PINK, Enum.Material.Neon, "Glow")
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 220)
	light.Range = 60
	light.Brightness = 0
	light.Shadows = false
	light.Parent = glow
	local api: any = { folder = folder, frame = f, open = 0 }
	function api.place(k: number)
		api.open = k
		for _, s in spans do
			local w = s.w * k
			local x = s.jag * k
			local cy = s.y
			s.core.Size = Vector3.new(math.max(w * 2 - 0.4, 0.05), s.core.Size.Y, 0.6)
			s.core.CFrame = f * CFrame.new(x, cy, 0)
			s.rimL.CFrame = f * CFrame.new(x - w, cy, 0) * CFrame.Angles(0, 0, math.rad(s.jag * 8))
			s.rimR.CFrame = f * CFrame.new(x + w, cy, 0) * CFrame.Angles(0, 0, math.rad(-s.jag * 8))
			local vis = if k > 0.01 then 0 else 1
			s.core.Transparency = vis
			s.rimL.Transparency = vis
			s.rimR.Transparency = vis
		end
		light.Brightness = k * 3
	end
	function api.update(t: number)
		if api.open <= 0.01 then
			return
		end
		for i, s in spans do
			local fl = 0.5 + 0.5 * math.noise(t * 6, i * 0.9)
			s.rimL.Color = Color3.fromRGB(255, 120, 220):Lerp(WHITE, fl)
			s.rimR.Color = Color3.fromRGB(255, 120, 220):Lerp(WHITE, 1 - fl)
		end
		light.Brightness = api.open * (2.4 + math.noise(t * 4, 3.3) * 1.2)
	end
	api.place(0)
	return api
end

-------------------------------------------------------------------------------------------------------------
-- preparing (under the black cover)
-------------------------------------------------------------------------------------------------------------
local SOUNDS = {
	"animeCharge", "ambBirds", "ambWind", "eerie", "drone", "stepGrass", "stepThud", "bossThud", "bladeDraw", "bladeSlash",
	"bladeClang", "bladeHit", "swingBlade", "whoosh", "lunge", "punch", "hit", "slam", "boom", "bigHit", "burst", "swell",
	"sting", "suck", "servo", "zapCharge", "zapStrike", "bhHum", "bhWarp", "bhPull", "eggCrack", "chip", "heartbeat",
	"rumble", "titleHit", "riseDark", "growl",
}

-- the realm's gold tufts, as boxes the lens can be kept clear of
local function realmTufts(g: any)
	g.tuftParts = {}
	for _, m in g.tufts do
		local parts = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		-- (its box's middle and half its width: tested in Studio, a fixed 1.4 round the foot left the big blades of a
		-- tuft beside the lens filling the lunge's frame)
		local box, size = m:GetBoundingBox()
		table.insert(g.tuftParts, { parts = parts, at = box.Position, r = math.max(size.X, size.Z) * 0.5 })
	end
end

-- The realm's strongest guardian (the last area's), the one that falls.
local function strongest(): any
	if not G or #G.guardians == 0 then
		return nil
	end
	local ok, def = pcall(BossMoves.get, #Config.ZONES)
	local rig = if ok and def then def.rig else nil
	local best = G.guardians[1]
	for _, gd in G.guardians do
		if gd.name == rig then
			return gd
		end
		if gd.size.Y > best.size.Y then
			best = gd
		end
	end
	return best
end

function Finale.prepare(): boolean
	Finale.stop()
	local V2 = Config.FILMS_V2
	FilmAudio.begin(SOUNDS)
	local probe = Instance.new("Sound")
	probe.SoundId = Config.FILM_SOUNDS[V2.music].id
	probe.Volume = 0
	probe.Parent = game:GetService("SoundService")
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ probe })
		end)
	end)
	S = FilmSet.meadow(CFrame.new(V2.setAt), { mown = true })
	S.crackSky(0, 0)
	-- (tested in Studio) the meadow's stubble was laid out for the opening: the morning's walk went straight through
	-- some of it, so the strip he walks and the spots where Rayan and he stand are cleared; and the night's broken
	-- rim round the fissure, sunk in the ground, read as dark planks across the low morning shots
	local walkA, walkB = mv(P_FROM, 0), mv(P_TO, 0)
	local keep = {}
	for _, t in S.tufts do
		local p = Vector3.new(t.at.Position.X, 0, t.at.Position.Z)
		local ab = Vector3.new(walkB.X - walkA.X, 0, walkB.Z - walkA.Z)
		local u = math.clamp((p - Vector3.new(walkA.X, 0, walkA.Z)):Dot(ab) / ab:Dot(ab), 0, 1)
		local onPath = (p - (Vector3.new(walkA.X, 0, walkA.Z) + ab * u)).Magnitude < 3.2
		local nearR = (p - Vector3.new(mv(R_AT, 0).X, 0, mv(R_AT, 0).Z)).Magnitude < 3.5
			or (p - Vector3.new(mv(BESIDE, 0).X, 0, mv(BESIDE, 0).Z)).Magnitude < 3.5
		if onPath or nearR then
			t.model:Destroy()
		else
			table.insert(keep, t)
		end
	end
	S.tufts = keep
	for _, r in S.rim or {} do
		r.part.Transparency = 1
	end
	if S.moon then
		S.moon.Transparency = 1
	end
	if S.moonHalo then
		S.moonHalo.Transparency = 1
	end
	for _, l in S.lanterns or {} do
		for _, d in l.model:GetDescendants() do
			if d:IsA("Light") then
				d.Enabled = false
			end
		end
	end
	G = FilmSet.realm(CFrame.new(V2.realmAt))
	realmTufts(G)
	local rm = ownerModel()
	local hm = playerModel()
	local cm = playerModel()
	if rm then
		R = Puppet.new(rm, { name = "Rayan", parent = workspace })
	end
	if hm then
		H = Puppet.new(hm, { name = "Hero", parent = workspace })
		hm:Destroy()
	end
	if cm then
		darken(cm)
		C = Puppet.new(cm, { name = "Copy", parent = workspace })
		cm:Destroy()
		local hl = C.model:FindFirstChild("Glitch")
		if not hl then
			darken(C.model)
		end
		copyEyes = makeEyes(C.model)
		copyGlow = C.model:FindFirstChild("Glitch") :: Highlight?
		C:show(false)
	end
	if rm and rm.Parent == nil then
		rm:Destroy()
	end
	SH = Shears.new(workspace)
	pcall(function()
		local list: { Instance } = { probe }
		for _, pup in { R, H, C } do
			if pup then
				table.insert(list, pup.model)
			end
		end
		ContentProvider:PreloadAsync(list)
	end)
	local t0 = os.clock()
	while not probe.IsLoaded and os.clock() - t0 < 6 do
		task.wait(0.05)
	end
	probe:Destroy()
	prepared = R ~= nil and H ~= nil and C ~= nil
	return prepared
end

-------------------------------------------------------------------------------------------------------------
-- A. MORNING
-------------------------------------------------------------------------------------------------------------
local function sunrise()
	-- (tested in Studio) the game's cartoon sky turned so the sunrise side is all soft cloud: as it stands, a deep blue
	-- gap in its clouds sat over the east like a blot in the warm haze (Finale.stop turns it back)
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		skyWas = skyWas or sky.SkyboxOrientation
		sky.SkyboxOrientation = Vector3.new(0, 215, 0)
	end
	Film.light({
		ClockTime = 6.45,
		Brightness = 2.6,
		ExposureCompensation = 0.2,
		Ambient = Color3.fromRGB(110, 86, 84),
		OutdoorAmbient = Color3.fromRGB(176, 140, 122),
		ColorShift_Top = Color3.fromRGB(255, 196, 150),
		ColorShift_Bottom = Color3.fromRGB(120, 76, 70),
		atmosphere = { Density = 0.3, Offset = 0.08, Haze = 1.6, Glare = 0.7, Color = Color3.fromRGB(255, 200, 160), Decay = Color3.fromRGB(255, 140, 100) },
	}, 0)
	Film.grade({ Brightness = 0, Contrast = 0.14, Saturation = 0.08, TintColor = Color3.fromRGB(255, 232, 210) }, 0)
	Film.vignette(0.4, 0)
	Film.glow(0.5, 22, 0)
end

local function walkTrack(pup: any, from: Vector3, to: Vector3, t0: number, t1: number, steps: string?)
	local nextStep = 0
	return function()
		local tt = now()
		local k = math.clamp((tt - t0) / (t1 - t0), 0, 1)
		standW(pup, from:Lerp(to, k), to + (to - from).Unit * 5)
		if steps and k < 1 and tt >= nextStep then
			nextStep = tt + 0.55
			sfx(steps, 0.8, 0.9 + math.random() * 0.15)
		end
	end
end

local function morning(): boolean
	sunrise()
	IntroUi.letterbox(true, 0)
	FilmAudio.amb("ambBirds", 0.8, 1.5)
	FilmAudio.amb("ambWind", 0.45, 1.5)
	-- Rayan waits on the meadow, the shears on his shoulder, looking out at the sunrise; the player walks in out of it
	standW(R, mv(R_AT, 0), mv(P_FROM, 0))
	R:pose("shoulder", 0)
	shearsMode = "shoulder"
	standW(H, mv(P_FROM, 0), mv(P_TO, 0))
	H:pose("cool", 0)
	H:walk(1, 0.95, "cool", true)
	H:show(true)
	tracks.walk = walkTrack(H, mv(P_FROM, 0), mv(P_TO, 0), T.sun, T.valley, "stepGrass")
	-- (gold dust in the low sun round him)
	local dust = fx("Dust", mv(P_FROM:Lerp(P_TO, 0.4), 1.5), { scale = 2.2, color = Color3.fromRGB(255, 220, 160), hold = 9, stream = true })
	after(T.sun, function()
		IntroUi.fade(1, 0.35)
		sfx("swell", 0.6, 1.2)
	end)
	-- 1. [BL, a long low tracking shot] the valley at sunrise, low over the stubble into the sun; the player a small
	-- figure walking in out of the light
	if not shot(T.feet, function(k)
		local p = mv(Vector3.new(-10 + k * 2.5, 1.3 + k * 0.2, -29))
		return look(p, mv(Vector3.new(40, 4.5, -27)), 0), mm(30), H.root.Position
	end, { hand = 0.3 }) then
		return false
	end
	-- 2. [TSB walk-in: the feet] from the ground in front of him (tested in Studio: from the side his legs filled the
	-- frame): his legs against the sunrise, a boot comes down and a gold ring runs out over the stubble (the copy's
	-- pink rings answer it later)
	after(T.feet + 0.1, function()
		local lf = H.model:FindFirstChild("LeftFoot", true) :: BasePart?
		local rf = H.model:FindFirstChild("RightFoot", true) :: BasePart?
		local foot = if lf and rf then (if lf.Position.Y < rf.Position.Y then lf else rf) else H.root
		goldStep(Vector3.new(foot.Position.X, groundOf(H) + 0.2, foot.Position.Z))
		sfx("stepThud", 0.7, 0.8)
	end)
	if not shot(T.fist, function(k)
		local root = H.root
		local g = groundOf(H)
		local p = root.Position + root.LookVector * (3.7 - k * 0.5) - root.RightVector * 1.4
		p = Vector3.new(p.X, g + 0.28, p.Z)
		local target = Vector3.new(root.Position.X, g + 0.85, root.Position.Z) - root.LookVector * 0.6 + root.RightVector * 0.25
		key(target + root.LookVector * 2.5 - root.RightVector * 1.5 + UP * 1.5, SUN, 1.3, 9)
		return look(p, target, 0), mm(24), target
	end, { hand = 0.2 }) then
		return false
	end
	key(nil)
	-- 3. [SR 27.65: the walk-out's jump cuts, another framing] his face, 3/4 from the front and a little below, tracking
	-- back with him, the sunrise behind his head (tested in Studio: in profile his near arm and his hair hid him)
	if not shot(T.walk, function(k)
		local root = H.root
		local head = headOf(H)
		local p = head + root.LookVector * (5.9 - k * 0.5) + root.RightVector * 2.3 + Vector3.new(0, -0.65, 0)
		return look(p, head + Vector3.new(0, -0.3, 0), 0), mm(45), head
	end, { hand = 0.25 }) then
		return false
	end
	-- 4. [SR 27.65, low and wide] walking at us, the low sun flaring beside him (tested: dead behind him it was hidden)
	if not shot(T.back, function(k)
		local root = H.root
		local p = root.Position + root.LookVector * (9.5 - k) - root.RightVector * 0.7 + Vector3.new(0, -2.3, 0)
		return look(p, root.Position + Vector3.new(0, 1.2, 0) - root.RightVector * 0.3, 2), mm(30), root.Position
	end, { hand = 0.3 }) then
		return false
	end
	-- 5. [SR 29.3, over the shoulder] behind him: Rayan ahead, the shears on his shoulder, the valley beyond (tested:
	-- from closer his back filled the frame and hid Rayan)
	if not shot(T.rayan, function(k)
		local root = H.root
		local p = root.Position - root.LookVector * (5.2 - k * 0.4) + root.RightVector * 2.9 + Vector3.new(0, 1.9, 0)
		return look(p, chestOf(R).Position + Vector3.new(0, 0.2, 0), 1), mm(55), chestOf(R).Position
	end, { hand = 0.3 }) then
		return false
	end
	-- 6. [SR 24.0, a low close-up, set] Rayan, the low sun on his face: "Every last blade."
	R:look(headOf(H), 0.7)
	AnimeFx.sub("Every last *blade*.", 1.6)
	if not shot(T.valley, function(k)
		local hc = headCf(R)
		local e = eyesOf(R, 0.15, 0)
		local p = e + hc.LookVector * (3.2 - k * 0.3) + hc.RightVector * 0.8 - UP * 0.45
		key(e + hc.LookVector * 2 + hc.RightVector * 1.5 + UP * 0.5, SUN, 1.2, 8)
		return look(p, e, 3), mm(55), e
	end, { hand = 0.15 }) then
		return false
	end
	key(nil)
	-- 7. [SR 7.2, scale] the two of them side by side from behind, low, the sun coming up between them (tested in
	-- Studio: with him where his walk ended, Rayan stood right behind him and the two read as one shape)
	tracks.walk = nil
	H:walk(0)
	standW(H, mv(BESIDE, 0), mv(Vector3.new(40, 0, -26), 0))
	H:pose("cool", 0.3)
	R:look(nil)
	if not shot(T.build, function(k)
		local mid = (R.root.Position + H.root.Position) / 2
		local face = H.root.LookVector
		local p = mid - face * (17.5 - k * 1.2) + H.root.RightVector * 0.5 + Vector3.new(0, -1.6, 0)
		return look(p, mid + face * 40 + Vector3.new(0, 5, 0), 1), mm(26), mid
	end, { hand = 0.3 }) then
		return false
	end
	if dust then
		pcall(function()
			dust:Destroy()
		end)
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- B. ONE LEFT
-------------------------------------------------------------------------------------------------------------
local function realmLight()
	Film.light({
		ClockTime = 13.5,
		Brightness = 3,
		ExposureCompensation = 0.15,
		Ambient = Color3.fromRGB(150, 120, 70),
		OutdoorAmbient = Color3.fromRGB(220, 180, 100),
		ColorShift_Top = Color3.fromRGB(255, 220, 140),
		ColorShift_Bottom = Color3.fromRGB(180, 130, 60),
		atmosphere = { Density = 0.36, Offset = 0.2, Haze = 2.4, Glare = 0.4, Color = Color3.fromRGB(255, 214, 140), Decay = Color3.fromRGB(255, 190, 90) },
	}, 0)
	Film.grade({ Brightness = 0, Contrast = 0.12, Saturation = 0.1, TintColor = Color3.fromRGB(255, 240, 210) }, 0)
	Film.glow(0.55, 24, 0)
end

local function shardTwitch(m: Model, base: CFrame, power: number)
	local frames = 0
	return function(_dt, t)
		frames += 1
		local j = power * (0.5 + 0.5 * math.noise(t * 9, 1.7))
		local off = Vector3.new(math.noise(t * 17, 0.3), math.noise(t * 13, 2.1) * 0.5, math.noise(t * 11, 4.4)) * j * 0.25
		m:PivotTo(base * CFrame.new(off) * CFrame.Angles(math.noise(t * 7, 5) * j * 0.6, t * 0.8, math.noise(t * 8, 6) * j * 0.6))
		if frames % 9 == 0 and j > 0.4 then
			pixels(base.Position - Vector3.new(0, 0.3, 0), 2, 0.5)
		end
	end
end

local function oneLeft(): boolean
	-- 8. [SR 31.5, the one glowing eye in the dark] in the stubble behind them: the last pink shard twitches
	shard = makeShard(mv(SHARD_AT))
	local base = (shard :: Model):GetPivot()
	tracks.shard = shardTwitch(shard :: Model, base, 1)
	sfx("servo", 0.7, 1.3)
	FilmAudio.glitch(0.35)
	after(T.build + 0.6, function()
		FilmAudio.glitch(0.5)
	end)
	-- (tested in Studio: from 3 studs on a long lens the shard filled the frame, an abstract white and pink slab; from
	-- low and further it's a small glowing thing in the stubble, the two of them out of focus behind)
	if not shot(T.oneLeft, function(k)
		local p = base.Position + Vector3.new(5.5 - k * 0.8, 0.35, 3.2 - k * 0.4)
		return look(p, base.Position + Vector3.new(0, 0.5, 0), 3), mm(50), base.Position
	end, { hand = 0.1 }) then
		return false
	end
	-- 9. [SR 9.7, an extreme close-up of an eye] Rayan heard it, he turns to it: "One left." (tested: with only his head
	-- turned, his raised arm and the shears came between the lens and his eye)
	standW(R, Vector3.new(R.root.Position.X, groundOf(R), R.root.Position.Z), base.Position)
	R:look(base.Position + Vector3.new(0, 2.2, 0), 1)
	AnimeFx.sub("One *left*.", 1.1)
	if not shot(T.raise, function(k)
		local hc = headCf(R)
		local e = eyesOf(R, 0.26, 0)
		local p = e + hc.LookVector * (2.0 - k * 0.25) + hc.RightVector * 0.3 - hc.UpVector * 0.12
		return CFrame.lookAt(p, e, hc.UpVector), mm(85), e
	end, { hand = 0.12 }) then
		return false
	end
	-- 10. [TSB 28.5, the technique's title card] the shears off his shoulder and up, opening; the light gathers; the
	-- realm's name
	R:look(nil)
	R:pose("raise", 0.18, "snap")
	shearsMode = "raise"
	shearsOpen = 0
	sfx("bladeDraw", 1, 0.8)
	sfx("zapCharge", 1, 0.8)
	FilmAudio.riser("riseDark", T.realm - now(), { volume = 0.9 })
	local openFrom = now()
	tracks.open = function()
		shearsOpen = 60 * ease.out(math.clamp((now() - openFrom) / 0.5, 0, 1))
		SH:glow(math.clamp((now() - openFrom) / 2.2, 0, 1))
	end
	after(T.raise + 0.75, function()
		AnimeFx.technique("ENDLESS LAWN", "the Owner's realm", GOLD, 1.0)
	end)
	after(T.realm - 0.45, function()
		AnimeFx.cover(WHITE, 0, 0.42, "white")
	end)
	if not shot(T.realm, function(k)
		local root = R.root
		local p = root.Position + root.LookVector * (7 - k) + root.RightVector * 1.6 + Vector3.new(0, -2.1, 0)
		return look(p, headOf(R) + Vector3.new(0, 1.6 + k, 0), -4), mm(26), headOf(R)
	end, { hand = 0.3 }) then
		return false
	end
	tracks.open = nil
	return true
end

-- into the realm: everyone moved over under the white
local function enterRealm()
	realmLight()
	AnimeFx.cover(WHITE, 0, 0, "white")
	sfx("boom", 1.2, 0.9)
	sfx("swell", 1, 1)
	Film.shake(0.5, 2)
	standW(R, gv(G_R, 0), gv(TEAR, 0))
	standW(H, gv(G_P, 0), gv(TEAR, 0))
	R:pose("shoulder", 0)
	H:pose("cool", 0)
	shearsMode = "shoulder"
	SH:glow(0)
	tracks.shard = nil
	if shard then
		local base = CFrame.new(gv(G_SHARD))
		shard:PivotTo(base)
		tracks.shard = shardTwitch(shard, base, 0.6)
	end
	FilmAudio.amb("ambWind", 0.25, 0.5)
	AnimeFx.cover(WHITE, 1, 0.55, "white")
end

local function realm(): boolean
	enterRealm()
	-- 11. [TSB, the walk-in's white space; SR 7.2, scale] the realm from high: an endless gold lawn under a gold glass
	-- sky, the eight guardians standing round it, the three small in the middle
	if not shot(T.guard, function(k)
		local e = ease.out(k)
		local p = gv(Vector3.new(4, 62 - e * 30, 84 - e * 26))
		return look(p, gv(Vector3.new(0, 4, -6)), 0), mm(22), gv(Vector3.new(0, 2, 0))
	end, { hand = 0.2 }) then
		return false
	end
	-- 12. [SR 6.7, a silhouette against a huge sky] low at a guardian's feet, looking up at it
	local gd = G.guardians[3] or G.guardians[1]
	if gd then
		if not shot(T.nowhere, function(k)
			local base = gd.at.Position
			local inward = flat(gv(Vector3.zero) - base).Unit
			local p = base + inward * (gd.size.Z * 0.5 + 9) + inward:Cross(UP) * 4 + Vector3.new(0, 1.2, 0)
			return look(p, base + Vector3.new(0, gd.size.Y * (0.75 + k * 0.05), 0), 4), mm(20), base + Vector3.new(0, gd.size.Y * 0.6, 0)
		end, { hand = 0.3 }) then
			return false
		end
	elseif not waitUntil(T.nowhere) then
		return false
	end
	-- 13. [SR 24.0] Rayan: "Nowhere to run."
	AnimeFx.sub("Nowhere to *run*.", 1.6)
	R:look(gv(G_SHARD), 0.8)
	if not shot(T.twitch, function(k)
		local hc = headCf(R)
		local e = eyesOf(R, 0.1, 0)
		-- (tested in Studio: from below his eyes the shears' grip on his shoulder rose over his mouth)
		local p = e + hc.LookVector * (3.4 - k * 0.4) - hc.RightVector * 0.9 + UP * 0.25
		key(e + hc.LookVector * 2 + UP * 1.4, Color3.fromRGB(255, 230, 170), 1.2, 8)
		return look(p, e - UP * 0.15, -3), mm(50), e
	end, { hand = 0.15 }) then
		return false
	end
	key(nil)
	-- 14. [SR 11.2] the shard trembles harder on the gold, pink pixels popping off it
	tracks.shard = shardTwitch(shard :: Model, CFrame.new(gv(G_SHARD)), 1.6)
	FilmAudio.glitch(0.7)
	sfx("servo", 0.9, 0.7)
	if not shot(T.flee, function(k)
		local s = gv(G_SHARD)
		-- (tested in Studio: from 3 studs on a long lens it filled the frame; now the guardians stand behind it)
		local p = s + Vector3.new(-5.2 + k * 0.7, 0.3, 3.8 - k * 0.3)
		return look(p, s + Vector3.new(0, 0.5, 0), -5), mm(45), s
	end, { hand = 0.15 }) then
		return false
	end
	return true
end

-- 15-17: the shard flees and rips the realm open
local function flee(): boolean
	local from = gv(G_SHARD)
	local to = gv(TEAR, TEAR_H * 0.45)
	tracks.shard = function(_dt, t)
		local k = math.clamp((now() - T.flee) / (T.rip - T.flee), 0, 1)
		local e = ease.inn(k)
		local p = from:Lerp(to, e) + Vector3.new(0, math.sin(k * math.pi) * 3 + 0.6, 0)
		if shard then
			shard:PivotTo(CFrame.new(p) * CFrame.Angles(t * 9, t * 11, 0))
		end
	end
	sfx("whoosh", 1, 1.4)
	sfx("zapStrike", 0.6, 1.6)
	R:look(nil)
	H:look(gv(TEAR, 20), 0.8)
	-- 15. [BL, a tracking shot] skimming low over the gold with it toward the guardians' ring
	if not shot(T.rip, function(_k)
		local s = if shard then shard:GetPivot().Position else to
		local p = s + Vector3.new(7, 1.6, 5)
		return look(p, s, -4), mm(30), s
	end, { hand = 0.4 }) then
		return false
	end
	-- 16. [TSB, the black hole with a white ring] it hits the air and rips it: a tear opens, top to bottom
	tracks.shard = nil
	if shard then
		shard:Destroy()
		shard = nil
	end
	tear = makeTear(gv(TEAR, 0), (gv(Vector3.zero) - gv(TEAR)).Unit)
	local openFrom = now()
	tracks.tear = function(_dt, t)
		local k = ease.out(math.clamp((now() - openFrom) / 0.7, 0, 1))
		tear.place(k)
		tear.update(t)
	end
	sfx("bhWarp", 1.2, 0.9)
	sfx("burst", 1.1, 0.6)
	sfx("eggCrack", 1.2, 0.5)
	FilmAudio.glitch(1)
	Film.shake(0.7, 1.5)
	Film.flash(Color3.fromRGB(255, 160, 230), 0.6, 0.35)
	burst(gv(TEAR, TEAR_H * 0.5), HOT, 8, 120, 1.2)
	if not shot(T.look, function(k)
		local p = gv(Vector3.new(7 - k, 3.5, -4 + k))
		return look(p, gv(TEAR, TEAR_H * 0.45), 2), mm(28), gv(TEAR, TEAR_H * 0.4)
	end, { hand = 0.3 }) then
		return false
	end
	-- 17. over their shoulders: the two of them and the tear; the music sinks away
	music[1].fade(0, 2.6)
	FilmAudio.amb("bhHum", 0.6, 2)
	if not shot(T.quiet, function(k)
		local mid = (R.root.Position + H.root.Position) / 2
		local back = -flat(gv(TEAR) - mid).Unit
		local p = mid + back * (6.6 + k * 0.6) + Vector3.new(0, 1.1, 0)
		return look(p, gv(TEAR, TEAR_H * 0.35), 0), mm(30), gv(TEAR, 12)
	end, { hand = 0.25 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- C. YOU
-------------------------------------------------------------------------------------------------------------
local function copyWalk()
	local dirIn = flat(gv(Vector3.zero) - gv(TEAR)).Unit
	local leg1From = gv(TEAR, 0) + dirIn * 1.5
	local leg1To = leg1From + dirIn * 8
	local leg2To = gv(C_STOP, 0)
	local leg2From = leg2To - dirIn * 8.4
	local lastFoot = -1
	return function()
		local tt = now()
		local p: Vector3
		if tt < T.react then
			p = leg1From:Lerp(leg1To, math.clamp((tt - T.step1) / (T.react - T.step1), 0, 1))
		else
			p = leg2From:Lerp(leg2To, math.clamp((tt - T.react) / (T.glitch - T.react), 0, 1))
		end
		standW(C, p, p + dirIn * 5)
		-- (a ripple and a footfall each time a foot comes down: every half cycle of the walk)
		local foot = math.floor((tt - T.step1) * COPY_RATE * 2)
		if tt < T.glitch and foot > lastFoot then
			lastFoot = foot
			local side = if foot % 2 == 0 then -0.5 else 0.5
			local fp = C.root * CFrame.new(side, 0, 0)
			local at = Vector3.new(fp.Position.X, groundOf(C) + 0.05, fp.Position.Z)
			pixels(at, 6, 0.6)
			stepRing(stepEmitter(at + Vector3.new(0, 0.15, 0)), PINK, 0.7)
			sfx("stepThud", 1.2, 0.6)
			sfx("bossThud", 0.35, 1.6)
		end
	end
end

local function you(): boolean
	-- the music is gone; the plain clock from here
	setFree(T.quiet)
	if music[1] then
		music[1].stop(0.2)
	end
	FilmAudio.amb("eerie", 0.6, 1)
	-- 18. [a menace hold] the tear, wide and still: nothing comes out
	if not shot(T.step1, function(k)
		-- (tested in Studio: from 44 studs it filled the frame top to bottom; low in the gold now, the guardians flanking)
		local p = gv(Vector3.new(0.3, 1.3, -4 - k * 0.6))
		return look(p, gv(TEAR, TEAR_H * 0.4), 0), mm(28), gv(TEAR, 10)
	end, { hand = 0.15 }) then
		return false
	end
	-- 19-20. [TSB walk-in: feet, a glowing ring at each step] a footstep: a black foot comes down on the gold
	C:show(true)
	C:pose("cool", 0)
	C:walk(1, COPY_RATE, "cool", true)
	tracks.copy = copyWalk()
	if not shot(T.step2, function(_k)
		local root = C.root
		local g = groundOf(C)
		-- (tested in Studio: from 3 studs the two black legs filled the frame; from the ground, further, the gold
		-- between them and the ring running out)
		local p = root.Position + root.LookVector * 5.2 + root.RightVector * 2.2
		p = Vector3.new(p.X, g + 0.3, p.Z)
		return look(p, Vector3.new(root.Position.X, g + 0.85, root.Position.Z) - root.LookVector * 0.3, 3), mm(30), root.Position
	end, { hand = 0.15 }) then
		return false
	end
	if not shot(T.walkIn, function(_k)
		local root = C.root
		local g = groundOf(C)
		local p = root.Position + root.LookVector * 5.4 - root.RightVector * 2.4
		p = Vector3.new(p.X, g + 0.35, p.Z)
		return look(p, Vector3.new(root.Position.X, g + 0.85, root.Position.Z) - root.LookVector * 0.3, -3), mm(30), root.Position
	end, { hand = 0.15 }) then
		return false
	end
	-- 21. [SR 10.9, a silhouette against the light] it walks at us, the tear's light behind it, calm
	if not shot(T.react, function(k)
		local root = C.root
		local p = root.Position + root.LookVector * (11 - k * 1.5) + Vector3.new(0, -1.4, 0)
		return look(p, root.Position + Vector3.new(0, 1.6, 0), 0), mm(32), root.Position
	end, { hand = 0.2 }) then
		return false
	end
	-- 22. [SR 8.75, the reaction] the player flinches back half a step, a dolly zoom on him (the lens backs off as it
	-- closes in, the realm stretching behind him), the pink of its eyes on his face. (Tested in Studio: an extreme
	-- close-up of the face can't react, most avatars' faces smile, a default smiley filled the frame; and any pose with
	-- his hands up filled it with his arms.)
	H:look(headOf(C), 1)
	sfx("heartbeat", 1.1)
	do
		local from = H.root
		local away = -flat(C.root.Position - H.root.Position).Unit
		tracks.flinch = function()
			local k = ease.out(math.clamp((now() - T.react) / 0.35, 0, 1))
			H.root = from + away * (0.7 * k)
			if k >= 1 then
				tracks.flinch = nil
			end
		end
	end
	if not shot(T.step3, function(k)
		local head = headOf(H)
		local f = flat(C.root.Position - H.root.Position).Unit
		local e = ease.inOut(k)
		local d = 3.2 + e * 4.8
		local p = head + f * d + f:Cross(UP) * (d * 0.2) - UP * 0.35
		key(head + f * 1.6 + UP * 0.6, HOT, 1.4, 6)
		return look(p, head - UP * 0.45, 0), math.deg(2 * math.atan(1.49 / d)), head
	end, { hand = 0.12 }) then
		return false
	end
	key(nil)
	-- 23. its feet again, from low beside them
	if not shot(T.face, function(_k)
		local root = C.root
		local g = groundOf(C)
		local p = root.Position + root.RightVector * 5.6 + root.LookVector * 1.0
		p = Vector3.new(p.X, g + 0.35, p.Z)
		return look(p, Vector3.new(root.Position.X, g + 0.9, root.Position.Z) - root.LookVector * 0.5, 2), mm(30), root.Position
	end, { hand = 0.2 }) then
		return false
	end
	-- 24. [SR 9.7, the extreme close-up] its face: the player's own, ink-black, magenta eyes; still walking in
	C:look(headOf(H), 0.8)
	sfx("sting", 0.8, 0.6)
	FilmAudio.glitch(0.4)
	if not shot(T.glitch, function(k)
		local hc = headCf(C)
		local e = eyesOf(C, 0, 0.07)
		local p = e + hc.LookVector * (2.8 - k * 0.7) + hc.UpVector * 0.02
		key(e + hc.LookVector * 1.6 + UP * 0.4, HOT, 0.8, 5)
		return CFrame.lookAt(p, e, hc.UpVector), mm(70), e
	end, { hand = 0.1 }) then
		return false
	end
	key(nil)
	tracks.copy = nil
	C:walk(0)
	standW(C, gv(C_STOP, 0), gv(Vector3.new(0, 0, 6), 0))
	C:pose("cool", 0.3)
	-- 25. [SR 29.3, over the shoulder] over Rayan's shoulder at it: "There's no glitch in it."
	AnimeFx.sub("There's no *glitch* in it.", 1.5)
	R:look(headOf(C), 1)
	if not shot(T.you, function(k)
		local rh = headOf(R)
		local to = (headOf(C) - rh)
		local dir = flat(to).Unit
		-- (over his left shoulder: tested in Studio, over the right one the shears' grip filled half the frame)
		local p = rh - dir * (2.6 - k * 0.2) - dir:Cross(UP) * 1.2 + Vector3.new(0, 0.25, 0)
		return look(p, headOf(C) - Vector3.new(0, 0.6, 0), -2), mm(40), headOf(C)
	end, { hand = 0.2 }) then
		return false
	end
	-- 26. Rayan: "It's just... you?"
	AnimeFx.sub("It's just... *you*?", 1.3)
	if not shot(T.attack, function(k)
		local hc = headCf(R)
		local e = eyesOf(R, 0.1, 0)
		local p = e + hc.LookVector * (2.6 - k * 0.3) + hc.RightVector * 0.6 - UP * 0.2
		return look(p, e, 2), mm(60), e
	end, { hand = 0.12 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- D. THE LESSON
-------------------------------------------------------------------------------------------------------------
local function darkenShears(k: number)
	corrupt = k
	-- (the black creeps from its hand along the blades: the parts nearest its hand go first)
	local hand = if C then C:grip("Right").Position else SH.pivot.Position
	local far = 0.1
	for _, p in SH.parts do
		far = math.max(far, (p.Position - hand).Magnitude)
	end
	for _, p in SH.parts do
		local base = p:GetAttribute("BaseColor")
		if typeof(base) ~= "Color3" then
			p:SetAttribute("BaseColor", p.Color)
			p:SetAttribute("BaseMaterial", p.Material.Name)
			base = p.Color
		end
		local isEdge = p.Material == Enum.Material.Neon
		local kp = math.clamp(k * 1.7 - (p.Position - hand).Magnitude / far * 0.7, 0, 1)
		p.Color = (base :: Color3):Lerp(if isEdge then HOT else INK, kp)
		if not isEdge and kp > 0.5 then
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0
		end
	end
	SH.light.Color = Color3.fromRGB(255, 220, 140):Lerp(PINK, k)
end

-- the strongest guardian topples outward and crashes down
local function fallGuardian(gd: any, time: number)
	local m = gd.model
	local pivot = m:GetPivot()
	local center = gv(Vector3.zero)
	local out = flat(pivot.Position - center).Unit
	local axis = UP:Cross(out).Unit
	local hinge = pivot.Position + out * (gd.size.Z * 0.35)
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - t0) / time, 0, 1)
		local a = ease.inn(k) * math.rad(84)
		local rot = CFrame.new(hinge) * CFrame.fromAxisAngle(axis, a) * CFrame.new(-hinge)
		m:PivotTo(rot * pivot)
		if k >= 1 and conn then
			conn:Disconnect()
			sfx("slam", 1.4, 0.55)
			sfx("rumble", 1.2, 0.7)
			Film.shake(0.9, 1.2)
			fx("Dust", hinge + out * gd.size.Y * 0.6, { scale = 4 })
			fx("GroundSlam", hinge + out * gd.size.Y * 0.6, { scale = 3 })
		end
	end)
	table.insert(conns, conn)
end

local function lesson(): boolean
	-- the music back, from its piece before the hit
	playPiece(2, 1.05)
	-- 27. [SR 18.25, a white smear; speed lines] Rayan lunges at it, the shears open
	R:look(nil)
	R:pose("leapOpen", 0.08, "snap")
	shearsMode = "lunge"
	SH:trail(true)
	sfx("lunge", 1.2, 0.9)
	sfx("swingBlade", 1.1, 0.8)
	local stopLines = AnimeFx.lines(WHITE, 0.5)
	local fromR = gv(G_R, 0)
	local toR = gv(C_STOP + Vector3.new(0.6, 0, 7.5), 0)
	tracks.lunge = function()
		local k = ease.inn(math.clamp((now() - T.attack) / (T.catch - T.attack), 0, 1))
		standW(R, fromR:Lerp(toR, k) + Vector3.new(0, math.sin(k * math.pi) * 1.2, 0), gv(C_STOP, 0))
	end
	-- (side on, the lens far enough off to hold them both and closing in as he does: tested in Studio, from a fixed
	-- 11 studs they were both out of the frame, one off each side)
	local side = flat(gv(C_STOP, 0) - fromR).Unit:Cross(UP)
	if not shot(T.catch, function(_k)
		local a, b = R.root.Position, C.root.Position
		local mid = a:Lerp(b, 0.5) + Vector3.new(0, 0.6, 0)
		local d = math.max(9, (flat(b - a).Magnitude * 0.5 + 3) / 0.9)
		return look(mid + side * d + Vector3.new(0, -1.2, 0), mid, -4), mm(24), mid
	end, { hand = 0.3, keep = function()
		-- (their legs too: a tuft low in front of it hid them, below the line to its chest)
		return { R.root.Position + UP, R.root.Position - UP * 1.8, C.root.Position + UP, C.root.Position - UP * 1.8 }
	end }) then
		return false
	end
	stopLines()
	-- 28. [TSB 5.7, the white line-art strobe; SR 18.95, the hand in the foreground] it catches the blades in one bare
	-- hand
	tracks.lunge = nil
	standW(R, toR, gv(C_STOP, 0))
	R:pose("snipShut", 0, "snap")
	C:pose("catch", 0, "snap")
	C:look(nil)
	R:update(0)
	C:update(0)
	do
		local tip = C:grip("Right").Position
		local d = flat(R:grip("Right").Position - tip)
		local want = Shears.BLADE + Shears.HANDLE - 0.4
		if d.Magnitude > 0.1 then
			R.root = R.root + d.Unit * (want - d.Magnitude)
			R:update(0)
		end
	end
	shearsMode = "caught"
	SH:trail(false)
	sfx("bladeClang", 1.5, 0.6)
	sfx("bigHit", 1.1, 0.8)
	sfx("hit", 1, 0.6)
	Film.shake(0.9, 1.4)
	local caughtAt = C:grip("Right").Position
	fx("Sparks", caughtAt, { scale = 1.6, color = HOT })
	burst(caughtAt, HOT, 6, 30, 0.8)
	task.defer(function()
		AnimeFx.impact({ C.model, R.model, SH.model }, "strobe", { states = { "ink", "neg", "ink", "neg" }, per = 0.06, at = caughtAt })
	end)
	-- (tested in Studio: from behind its hand its own shoulder filled the frame; from the side, further, the whole
	-- clash: its raised hand on the blades, Rayan pushing, a guardian between them)
	if not shot(T.take, function(k)
		local hand = C:grip("Right").Position
		local rg = R:grip("Right").Position
		local side = flat(rg - hand).Unit:Cross(UP)
		local mid = hand:Lerp(rg, 0.4)
		local p = mid + side * (8 - k * 0.6) + Vector3.new(0, -0.8, 0)
		return look(p, mid + Vector3.new(0, 0.3, 0), 6), mm(28), mid
	end, { hand = 0.2 }) then
		return false
	end
	-- 29. [BL, a close-up] its hand closes on them; the black creeps up the gold
	sfx("suck", 1, 1.3)
	FilmAudio.glitch(0.6)
	local creepFrom = now()
	tracks.creep = function()
		darkenShears(math.clamp((now() - creepFrom) / 1.1, 0, 1))
	end
	-- (tested in Studio: from 3 studs one blade filled the frame; from 6, its black hand on the blades, the dark running
	-- down them to the glowing pivot)
	if not shot(T.thrown, function(k)
		local hand = C:grip("Right").Position
		local mid = hand:Lerp(SH.pivot.Position, 0.4)
		local across = (SH.pivot.Position - hand):Cross(UP)
		local side = if across.Magnitude > 0.1 then across.Unit else C.root.RightVector
		local p = mid + side * (6.2 - k * 0.5) + Vector3.new(0, 0.9, 0)
		return look(p, mid, 5), mm(35), mid
	end, { hand = 0.15 }) then
		return false
	end
	-- 30. it twists them out of his hands and throws him across the gold; the shears are its now
	tracks.creep = nil
	darkenShears(1)
	shearsMode = "copy"
	shearsOpen = 0
	C:pose("inspect", 0.12, "snap")
	R:pose("flung", 0.06, "snap")
	R:shake(1)
	sfx("punch", 1.3, 0.7)
	sfx("whoosh", 1.2, 0.6)
	Film.shake(0.8, 1.5)
	local flyFrom = R.root.Position
	local back = flat(R.root.Position - C.root.Position).Unit
	local flyTo = flyFrom + back * 26 + Vector3.new(0, -0.6, 0)
	tracks.fly = function()
		local k = math.clamp((now() - T.thrown) / 0.9, 0, 1)
		local p = flyFrom:Lerp(flyTo, ease.out(k)) + Vector3.new(0, math.sin(k * math.pi) * 3.5, 0)
		R.root = CFrame.lookAt(p, p - back) * CFrame.Angles(0, 0, math.rad(k * 200))
		if math.random() < 0.3 then
			R:ghost(WHITE, 0.6, 0.2)
		end
		if k >= 1 then
			tracks.fly = nil
			standW(R, flyTo, flyFrom)
			R:pose("down", 0.1)
			sfx("stepThud", 1.4, 0.6)
			fx("Dust", flyTo, { scale = 1.6 })
		end
	end
	-- (tested in Studio: centred nearer it, Rayan flew out of the frame before the shot was half over; now the whole
	-- flight, from it to where he lands past the player)
	if not shot(T.lift, function(k)
		local mid = C.root.Position:Lerp(flyTo, 0.5)
		local side = back:Cross(UP)
		local p = mid + side * (22 - k * 1.5) + Vector3.new(0, 3.0, 0)
		return look(p, mid + Vector3.new(0, 1.8, 0), 2), mm(22), mid
	end, { hand = 0.4, keep = function()
		return { C.root.Position, R.root.Position, H.root.Position, C.root.Position - UP * 1.8, H.root.Position - UP * 1.8 }
	end }) then
		return false
	end
	return true
end

local function snip(): boolean
	-- 31. [the quiet before the drop] it lifts the shears, black now, and opens them; slow
	local openFrom = now()
	tracks.copyOpen = function()
		shearsOpen = 70 * ease.inOut(math.clamp((now() - openFrom) / 1.2, 0, 1))
	end
	sfx("bladeDraw", 1, 0.55)
	sfx("riseDark", 0.7, 1.2)
	if not shot(T.snip, function(k)
		local root = C.root
		local p = root.Position + root.LookVector * (7 - k * 0.8) + root.RightVector * 1.2 + Vector3.new(0, -2.2, 0)
		return look(p, headOf(C) + Vector3.new(0, 1.8, 0), 4), mm(26), headOf(C)
	end, { hand = 0.25 }) then
		return false
	end
	-- 32. [SR 18.25, the white smear; the drop] ONE SNIP, its own: the realm's sky cracks white
	tracks.copyOpen = nil
	shearsOpen = 0
	sfx("bladeSlash", 1.5, 0.6)
	sfx("boom", 1.3, 0.6)
	sfx("bigHit", 1.2, 0.6)
	sfx("eggCrack", 1.4, 0.4)
	AnimeFx.smear(8, -1, HOT)
	AnimeFx.slash(-12, { y = 0.45, life = 0.18, width = 0.03, color = HOT })
	Film.shake(1, 1.2)
	task.defer(function()
		AnimeFx.impact({ C.model, SH.model }, "strobe", { states = { "neg", "red", "neg" }, per = 0.06 })
	end)
	-- (every pane of the sky flashes white with cracks)
	for _, pnl in G.panels do
		pnl.part.Material = Enum.Material.Neon
		pnl.part.Color = Color3.fromRGB(255, 240, 250)
		pnl.part.Transparency = 0.25
	end
	burst(gv(Vector3.new(0, 40, 0)), WHITE, 6, 200, 1)
	-- (from behind it, past its raised shears, up at the sky going white over the realm: tested in Studio, the lens
	-- looked the other way, at the sky beyond the tear, and it wasn't in the shot at all)
	if not shot(T.fall, function(k)
		local root = C.root
		local p = root.Position - root.LookVector * (6 + k) + root.RightVector * 4.6 + Vector3.new(0, -1.5, 0)
		local to = root.Position + root.LookVector * 30 + Vector3.new(0, 16, 0) - root.RightVector * 4
		return look(p, to, 4), mm(24), headOf(C)
	end, { hand = 0.3 }) then
		return false
	end
	-- 33. [SR 7.2, scale; the proof on the strongest thing] the sky falls away in pieces, the dark behind it; the
	-- strongest guardian topples
	G.shatter(2.2)
	Film.light({
		ClockTime = 0.2,
		Brightness = 1.6,
		Ambient = Color3.fromRGB(80, 40, 90),
		OutdoorAmbient = Color3.fromRGB(110, 60, 130),
		ColorShift_Top = Color3.fromRGB(255, 120, 220),
		atmosphere = { Density = 0.4, Offset = 0.1, Haze = 1.6, Glare = 0, Color = Color3.fromRGB(70, 30, 90), Decay = Color3.fromRGB(150, 40, 140) },
	}, 1.4)
	Film.grade({ Brightness = 0, Contrast = 0.2, Saturation = -0.1, TintColor = Color3.fromRGB(240, 210, 255) }, 1.2)
	local gd = strongest()
	if gd then
		fallGuardian(gd, 1.6)
	end
	sfx("burst", 1.2, 0.5)
	sfx("rumble", 1.1, 0.6)
	-- (side on to its fall: tested in Studio, from across the realm it fell away from the lens and just seemed to sink)
	if not shot(T.turn, function(k)
		if not gd then
			local target = gv(Vector3.new(0, 20, -60))
			return look(gv(Vector3.new(-36 + k * 3, 3, 24)), target, 2), mm(22), target
		end
		local base = gd.at.Position
		local out = flat(base - gv(Vector3.zero)).Unit
		local mid = base + out * (gd.size.Y * 0.45) + Vector3.new(0, gd.size.Y * 0.33, 0)
		local p = mid + UP:Cross(out).Unit * (gd.size.Y * 2.2 - k * 2) - out * 4 + Vector3.new(0, -2, 0)
		return look(p, mid, 2), mm(26), mid
	end, { hand = 0.4 }) then
		return false
	end
	return true
end

local function ending(): boolean
	-- 34. [SR 31.3, the villain's face in the dark] it turns and looks into the lens: "Thanks for the lesson."
	music[2].fade(0.3, 0.8)
	C:pose("cool", 0.3)
	shearsMode = "copy"
	local camAt: Vector3? = nil
	after(T.turn + 0.3, function()
		AnimeFx.sub("Thanks for the *lesson*.", 1.9)
	end)
	after(T.black - 0.3, function()
		music[2].fade(0, 0.25)
	end)
	if not shot(T.black, function(k)
		local hc = headCf(C)
		local root = C.root
		local e = eyesOf(C, 0, 0.07)
		if not camAt then
			camAt = e + root.LookVector * 4.2 + root.RightVector * 0.3
		end
		local p = (camAt :: Vector3) + root.LookVector * (-k * 0.6)
		C:look(p, ease.out(math.clamp(k * 2, 0, 1)))
		key(e + root.LookVector * 1.4 + UP * 0.5, HOT, 1, 6)
		return look(p, e, 0), mm(55), e
	end, { hand = 0.1 }) then
		return false
	end
	key(nil)
	-- 35. [SR 26.33, black and silence] black.
	AnimeFx.cover(BLACK, 0, 0, "black")
	if music[2] then
		music[2].stop(0.05)
	end
	FilmAudio.hush(0.1)
	setFree(T.black)
	if not waitUntil(T.m3) then
		return false
	end
	-- 36. the track's last hit: its card
	playPiece(3, 1.1)
	after(T.card, function()
		AnimeFx.cover(BLACK, 1, 0.05, "black")
		AnimeFx.card("YOU", "the last glitch", PINK, 2.2)
		Film.shake(0.6, 1.4)
		sfx("titleHit", 1, 0.8)
	end)
	C:look(nil)
	if not shot(T.soon, function(k)
		local root = C.root
		local p = root.Position + root.LookVector * (10 - k) + root.RightVector * 2 + Vector3.new(0, -2.4, 0)
		return look(p, headOf(C) + Vector3.new(0, 0.8, 0), -5), mm(24), headOf(C)
	end, { hand = 0.2 }) then
		return false
	end
	-- 37. THE FINAL FIGHT. COMING SOON.
	AnimeFx.cover(BLACK, 0, 0.3, "black")
	after(T.soon + 0.35, function()
		AnimeFx.word("THE FINAL FIGHT", "COMING SOON", HOT)
	end)
	if not waitUntil(T.out) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- every frame
-------------------------------------------------------------------------------------------------------------
local function frame(dt: number, t: number)
	for _, pup in { R, H, C } do
		if pup and pup.shown then
			pup:update(dt)
		end
	end
	placeShears()
	placeEyes()
	for _, fn in tracks do
		fn(dt, t)
	end
end

-- (Studio only) workspace attributes: FilmFastTo = t runs 4x up to film time t; FilmHoldAt = t holds the picture
local function musicSounds(): { Sound }
	local out = {}
	for _, m in music do
		if m and m.sound and m.sound.Parent then
			table.insert(out, m.sound)
		end
	end
	return out
end

studioControls = function()
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if not playing then
			return
		end
		local fastTo = workspace:GetAttribute("FilmFastTo")
		local want = if type(fastTo) == "number" and now() < fastTo then 4 else 1
		if want ~= rate and not held then
			local t = now()
			rate = want
			if clockMode == "free" then
				setFree(t)
			end
			for _, snd in musicSounds() do
				snd.PlaybackSpeed = want
			end
			Film.speed(want, 0)
		end
		local holdAt = workspace:GetAttribute("FilmHoldAt")
		if not held and type(holdAt) == "number" and now() >= holdAt then
			held = now()
			for _, snd in musicSounds() do
				snd:Pause()
			end
			Film.speed(0, 0)
			print(string.format("[Finale] HOLD at %.2f", held))
		elseif held and type(holdAt) ~= "number" then
			local t = held
			held = nil
			for _, snd in musicSounds() do
				snd:Resume()
			end
			if clockMode == "free" then
				setFree(t)
			end
			lastAdvance = os.clock()
			Film.speed(rate, 0)
		end
	end))
end

-- Run the finale (Film.start has been called; IntroUi is open with its black cover up). Returns when it's done or
-- stopped.
function Finale.play()
	if not prepared then
		if not Finale.prepare() then
			return
		end
	end
	playing = true
	table.clear(events)
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if not playing or #events == 0 then
			return
		end
		local tt = now()
		for i = #events, 1, -1 do
			local e = events[i]
			if tt >= e.at then
				table.remove(events, i)
				task.spawn(e.fn)
			end
		end
	end))
	if RunService:IsStudio() then
		studioControls()
	end
	Film.every(frame)
	Film.hand(0.3)
	lastNow, lastPos, lastAdvance = 0, -1, os.clock()
	setFree(0)
	playPiece(1, 0.95)
	local steps = { morning, oneLeft, realm, flee, you, lesson, snip, ending }
	for _, step in steps do
		if not playing then
			break
		end
		local ok, err = pcall(step)
		if not ok then
			warn("[Finale] " .. tostring(err))
		elseif err == false then
			break
		end
	end
	playing = false
end

-- (Studio, for whoever frames the shots) while the film is held: look through another lens (world points), nil to
-- give the shot its own back; and the cast, to measure from.
function Finale.tryCam(from: Vector3?, to: Vector3?, fov: number?, roll: number?)
	if not RunService:IsStudio() then
		return
	end
	if not from or not to then
		tryCam = nil
		return
	end
	tryCam = { cf = look(from, to, roll or 0), fov = fov or 40, focus = to }
end
function Finale.cast(): any
	return { S = S, G = G, R = R, H = H, C = C, SH = SH, T = T, now = now, mv = mv, gv = gv, held = function()
		return held
	end, playing = function()
		return playing
	end }
end

-- SKIP: the film stops where it is (Finale.play returns; Finale.stop clears up after).
function Finale.skip()
	playing = false
end

-- Take everything away (the end, or SKIP). Safe to call any time.
function Finale.stop()
	playing = false
	prepared = false
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	table.clear(events)
	table.clear(tracks)
	for _, m in music do
		pcall(function()
			m.stop(0.3)
		end)
	end
	table.clear(music)
	held = nil
	rate = 1
	tryCam = nil
	clockMode = "free"
	key(nil)
	pcall(AnimeFx.clear)
	for _, pup in { R, H, C } do
		if pup then
			pcall(function()
				pup:destroy()
			end)
		end
	end
	R, H, C = nil, nil, nil
	table.clear(copyEyes)
	copyGlow = nil
	if SH then
		SH:destroy()
		SH = nil
	end
	if shard then
		shard:Destroy()
		shard = nil
	end
	tear = nil
	if stage then
		stage:Destroy()
		stage = nil
	end
	keyPart = nil
	for _, set in { S, G } do
		if set then
			pcall(set.destroy)
		end
	end
	S, G = nil, nil
	table.clear(hidden)
	corrupt = 0
	shearsMode = "shoulder"
	if skyWas then
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			sky.SkyboxOrientation = skyWas
		end
		skyWas = nil
	end
end

return Finale
