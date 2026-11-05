-- THE OPENING, "FIRST CUT" (Films v2, 5 Nov 2026). The owner scrapped the old opening (client/Intro's own film, kept:
-- Config.FILMS_V2.on = false brings it back) and asked for "a real powerful intro ... like an anime fight like
-- sukuna vs mahoraga", with his avatar as the town's owner and "a cool moment" for the player. Story and shot list:
-- docs/FilmsV2.md. ~49 s, cut to the music (Config.FILM_SOUNDS.animeCharge, 100 BPM; film time = the track's time
-- until the blackout, then the track again from 131.0 so the player's punch lands on its drop at 132.08):
--   I.   NIGHT: the valley, pink cracks across the sky; the ground splits; the Glitch Demon heaves itself up and roars.
--   II.  RAYAN, the valley's owner, walks in dragging giant gold shears; his name card on the beat. "You're on my
--        lawn." The claw comes down; he's gone; three cuts from three sides: the arm drops.
--   III. THE RESET: the arm's pieces lift, fly back and lock on, a pink loading ring spins over its head. "...It grows
--        back." The same cut CLANGS off; a backhand in slow motion sends him through his shed.
--   IV.  He gets up, cracks his neck. "Fine. Let's mow." Silence, a gold ring round him, ONE snip: white. A beat. The
--        whole field slides apart at one height, the demon too. Pink pixels pour back: it rises again, BIGGER, and
--        its fists come down on him. Black. A heartbeat.
--   V.   A streak from the sky: THE PLAYER lands between them. Eyes. The fist goes back. One punch on the drop: the
--        fists, then the whole demon, shatter; eight pink shards fly off to the eight lands. Its last eye looks the
--        player over and zips away. Rayan: "Not bad, rookie." "Free them. Mow it ALL." The title slams in.
-- Built on this client from scratch: the set (client/FilmSet), the people (client/Puppet: the owner's avatar from
-- server/FilmCast, the player's own), the shears (client/Shears), the demon (client/Demon), the 2D layer
-- (client/AnimeFx). Opening.prepare() loads everything under the black cover, Opening.play() runs it,
-- Opening.stop() takes it all away (the end, or SKIP).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config")) :: any
local Film = require(script.Parent.Film)
local FilmAudio = require(script.Parent.FilmAudio)
local IntroUi = require(script.Parent.IntroUi)
local AnimeFx = require(script.Parent.AnimeFx)
local Puppet = require(script.Parent.Puppet)
local Shears = require(script.Parent.Shears)
local FilmSet = require(script.Parent.FilmSet)
local Demon = require(script.Parent.Demon)
local PackFx = require(script.Parent.PackFx)
local FilmVfx = require(script.Parent.FilmVfx)

local Opening = {}
local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 40, 170)
local GOLD = Color3.fromRGB(255, 200, 70)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local UP = Vector3.yAxis

-- the beats (film seconds; up to the blackout = the track's seconds)
local T = {
	sky = 2.4, split = 3.6, rise = 4.92, eyes = 5.66, roar = 6.18, feet = 7.14, walk = 8.4, card = 9.72,
	clawUp = 10.6, claw = 11.12, snip1 = 11.32, snip2 = 11.46, snip3 = 11.64, fall = 11.8, eye = 12.6,
	reset = 13.4, clang = 14.5, back = 14.9, shed = 15.78, wreck = 16.4, up = 17.14, fine = 19.3,
	stance = 21.0, ring = 22.3, glint = 23.3, ult = 24.08, after = 24.3, slide = 25.5, stubs = 26.4,
	regrow = 27.0, bigger = 28.9, slam = 31.92, streak = 34.4, hero = 35.2, resume = 36.0, windup = 36.5,
	punch = 37.08, shatter = 37.5, pillars = 39.5, lastEye = 41.0, eyeGo = 41.88, rayan = 42.6, rookie = 42.8,
	free = 44.2, title = 45.92, out = 49.0,
}
local RESUME_AT = 131.0 -- (the track's position the second part starts from: its drop at 132.08 = T.punch)
Opening.T = T

-- the places (the set's own frame, client/FilmSet: +X east, -Z north, the ground at 0)
local DEMON_AT = Vector3.new(0, 0, -52)
local R1 = Vector3.new(-5, 0, -30) -- Rayan stops here, the demon's claws a few studs ahead
local R2 = Vector3.new(-19, 0, -36) -- where he lands after the three cuts
local SHED = Vector3.new(-31, 0, -6)
local R3 = Vector3.new(-25, 0, -11) -- out of the wreck: the ultimate's middle
local RING = 60
local CUT_Y = 3 -- everything in the ring is cut at this height
local BIG_AT = Vector3.new(-14, 0, -32) -- the bigger demon rises here, over him
local P1 = Vector3.new(-22, 0, -15) -- the player lands here, between Rayan and the fists
local SCALE, BIG_SCALE = 1.2, 1.55

-------------------------------------------------------------------------------------------------------------
-- state
-------------------------------------------------------------------------------------------------------------
local S: any = nil -- the set
local R: any = nil -- Rayan (a puppet)
local H: any = nil -- the hero: the player (a puppet)
local SH: any = nil -- the shears
local D: any = nil -- the demon
local D2: any = nil -- the bigger demon
local stage: Folder? = nil -- (the film's loose things: rings, shards, the eye)
local playing = false
local prepared = false
local conns: { RBXScriptConnection } = {}
local events: { { at: number, fn: () -> () } } = {}
local tracks: { [string]: (dt: number, t: number) -> () } = {}
local music: any = nil
local music2: any = nil
local clockMode = "free"
local freeBase, freeStart = 0, 0
local lastNow, lastAdvance, lastPos = 0, 0, -1
local shearsMode = "drag"
local shearsOpen = 0
local demonPose: any = {} -- what the films' hooks do to the demons this frame
local armParts: (d: any, side: string) -> { BasePart }
local studioControls: () -> ()

local function W(x: number, y: number, z: number): CFrame
	return S.at * CFrame.new(x, y, z)
end
local function V(x: number, y: number, z: number): Vector3
	return (S.at * CFrame.new(x, y, z)).Position
end
local function at(v: Vector3, y: number?): Vector3
	return V(v.X, y or v.Y, v.Z)
end
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-------------------------------------------------------------------------------------------------------------
-- the clock: the music's own position while it plays (so cuts land on its beats even if a frame drops or an
-- impact frame holds the picture), the plain clock in between
-------------------------------------------------------------------------------------------------------------
local rate = 1 -- (Studio's fast-forward: the plain clock runs this many times faster)
local held: number? = nil -- (Studio's hold: the film stopped dead at this time)

local function setFree(t: number)
	freeBase, freeStart = t, os.clock()
	clockMode = "free"
end

local function now(): number
	if held then
		return held
	end
	local t: number
	if clockMode == "music1" and music and music.sound and music.sound.Parent and music.sound.IsPlaying then
		t = music.sound.TimePosition
	elseif clockMode == "music2" and music2 and music2.sound and music2.sound.Parent and music2.sound.IsPlaying and music2.sound.TimePosition >= RESUME_AT - 0.02 then
		t = T.resume + (music2.sound.TimePosition - RESUME_AT)
	else
		t = freeBase + (os.clock() - freeStart) * rate
	end
	-- (a stalled track: if the music hasn't moved for half a second, the plain clock takes over from here)
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
Opening.now = now

local function after(t: number, fn: () -> ())
	table.insert(events, { at = t, fn = fn })
end

local function waitUntil(t: number): boolean
	while playing and now() < t do
		task.wait()
	end
	return playing
end

-- cut to a shot that runs until film time `untilT` (k 0..1 over it), and wait for it
local function shot(untilT: number, fn: (k: number, t: number) -> (CFrame, number, Vector3?), opts: any?): boolean
	if not playing then
		return false
	end
	Film.cut(math.max(untilT - now(), 0.05), fn, opts)
	return waitUntil(untilT)
end

-------------------------------------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------------------------------------
local mm = Film.mm
local look = Film.look
local ease = { out = Film.out, inn = Film.inn, inOut = Film.inOut, smooth = Film.smooth, expo = Film.expo }

-- a puppet standing at `p` (set space, on the ground) facing `q`
local function stand(pup: any, p: Vector3, q: Vector3)
	local a, b = at(p, 0), at(q, 0)
	local dir = flat(b - a)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, -1)
	end
	pup.root = CFrame.lookAt(a, a + dir) + Vector3.new(0, -pup.ground, 0)
end

-- the head / chest of a puppet (world), for aiming cameras
local function headOf(pup: any): Vector3
	local h = pup:part("Head")
	return if h then (pup.world[h] or h.CFrame).Position else pup.root.Position + Vector3.new(0, 1.5, 0)
end
local function chestOf(pup: any): CFrame
	local c = pup:part("UpperTorso")
	return if c then (pup.world[c] or c.CFrame) else pup.root
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
	f.Name = "OpeningStage"
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

-------------------------------------------------------------------------------------------------------------
-- the cast
-------------------------------------------------------------------------------------------------------------
-- A copy of the player's character to act with (nothing of theirs that runs, no bundles, no effects).
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

-- Rayan: the owner's avatar (server/FilmCast); if it isn't there, the player's own look stands in.
local function ownerModel(): Model?
	local cast = ReplicatedStorage:FindFirstChild("FilmCast")
	local m = cast and cast:FindFirstChild("Owner")
	if m and m:IsA("Model") then
		return m
	end
	return playerModel()
end

-- the blocks of a demon's arm (upper and fore), for an impact frame's silhouettes (a few hundred, not thousands)
armParts = function(d: any, side: string): { BasePart }
	local out = {}
	local roots = {}
	for _, name in { "Root_arm" .. side, "Root_fore" .. side } do
		local r = d.model:FindFirstChild(name)
		if r then
			roots[r] = true
		end
	end
	for _, p in d.model:GetChildren() do
		if p:IsA("BasePart") then
			local w = p:FindFirstChildOfClass("WeldConstraint")
			if w and roots[w.Part0] then
				table.insert(out, p)
			end
		end
	end
	return out
end

-------------------------------------------------------------------------------------------------------------
-- the demons' poses on top of their own (one hook, reading demonPose)
-------------------------------------------------------------------------------------------------------------
-- (world rotation about a point)
local function about(p: Vector3, rot: CFrame): CFrame
	return CFrame.new(p) * rot * CFrame.new(-p)
end

local function hookFor(d: any): (frames: { CFrame }, idx: { [string]: number }, t: number) -> ()
	return function(frames, idx, _t)
		local P = demonPose[d]
		if not P then
			return
		end
		local body = frames[idx.body]
		local right = body.RightVector
		-- leaning in (the whole of it tips forward over its waist)
		if P.lean and P.lean ~= 0 then
			local rot = about(body.Position, CFrame.fromAxisAngle(right, -math.rad(P.lean)))
			for i = 1, #frames do
				frames[i] = rot * frames[i]
			end
			body = frames[idx.body]
		end
		-- an arm swung about its shoulder: P.armR / P.armL = { pitch = degrees down-forward, yaw = degrees in }
		for _, side in { "R", "L" } do
			local a = P["arm" .. side]
			if a then
				local arm, fore = idx["arm" .. side], idx["fore" .. side]
				local sh = frames[arm].Position
				local s = if side == "R" then 1 else -1
				local rot = about(sh, CFrame.fromAxisAngle(body.UpVector, math.rad((a.yaw or 0) * s)) * CFrame.fromAxisAngle(right, -math.rad(a.pitch or 0)))
				frames[arm] = rot * frames[arm]
				frames[fore] = rot * frames[fore]
			end
		end
		-- the severed right arm: carried off by a world transform (falling, lying, flying back)
		if P.cutM then
			frames[idx.armR] = P.cutM * frames[idx.armR]
			frames[idx.foreR] = P.cutM * frames[idx.foreR]
		end
		-- the top half sliding off (after split): a world transform on the top and everything on it
		if P.top then
			for _, name in { "top", "head", "jaw", "armL", "armR", "foreL", "foreR", "wingL", "wingR", "frags" } do
				local i = idx[name]
				if i then
					frames[i] = P.top * frames[i]
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the shears follow Rayan's hands
-------------------------------------------------------------------------------------------------------------
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
	local rh = R:grip("Right").Position
	local root = R.root
	local chest = chestOf(R)
	if mode == "two" then
		SH:grip2(rh, R:grip("Left").Position, chest.LookVector)
	elseif mode == "drag" then
		-- trailing behind him, the tip on the ground
		local back = -root.LookVector
		local h = math.max(rh.Y - (root.Position.Y + R.ground) - 0.2, 0.5)
		local len = Shears.HANDLE + Shears.BLADE
		local along = math.sqrt(math.max(len * len - h * h, 1))
		local dir = (back * along + root.RightVector * 0.8 - UP * h).Unit
		SH:hold(rh, dir, root.RightVector, 0)
	elseif mode == "shoulder" then
		-- over his right shoulder, the blades behind him
		local dir = (-chest.LookVector * 0.82 + UP * 0.52 + chest.RightVector * 0.12).Unit
		SH:hold(rh, dir, chest.RightVector, 4)
	elseif mode == "out" then
		-- held out to his right side, level
		local dir = (root.RightVector * 0.9 + root.LookVector * 0.35 - UP * 0.12).Unit
		SH:hold(rh, dir, UP, shearsOpen)
	end
end

-------------------------------------------------------------------------------------------------------------
-- preparing (under the black cover)
-------------------------------------------------------------------------------------------------------------
local SOUNDS = {
	"animeCharge", "rumble", "riseDark", "demonSwell", "growl", "growl2", "roar", "impact", "slam", "boom", "bigHit",
	"titleHit", "swipe", "crate", "crate2", "thud", "whomp", "synthWhomp", "heartbeat", "sting", "suck", "swell",
	"servo", "whoosh", "hit", "punch", "burst", "slice", "bladeSlash", "bladeDraw", "bladeHit", "bladeClang",
	"stepGrass", "stepThud", "eggCrack", "ambWind", "eerie", "zapCharge", "zapStrike", "lunge", "chip",
}

-- Build everything (yields; a few seconds at most). Returns false if it couldn't.
function Opening.prepare(): boolean
	Opening.stop()
	local V2 = Config.FILMS_V2
	local base = CFrame.new(V2.setAt)
	FilmAudio.begin(SOUNDS)
	-- the music must be loaded before the first frame (the film follows its clock)
	local probe = Instance.new("Sound")
	probe.SoundId = Config.FILM_SOUNDS[V2.music].id
	probe.Volume = 0
	probe.Parent = game:GetService("SoundService") -- (a sound loads, and says so, only in the game)
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ probe })
		end)
	end)
	S = FilmSet.meadow(base)
	Demon.preload(Demon.lite())
	local folder = Instance.new("Folder")
	folder.Name = "OpeningDemons"
	D = Demon.new(CFrame.lookAt(at(DEMON_AT, 0), at(DEMON_AT + Vector3.new(0, 0, 1), 0)), SCALE, folder, { yieldEvery = 400 })
	D.hook = hookFor(D)
	demonPose[D] = {}
	folder.Parent = workspace
	D.update(0)
	local folder2 = Instance.new("Folder")
	folder2.Name = "OpeningDemon2"
	local bigFace = at(R3, 0)
	local bigAt = at(BIG_AT, 0)
	D2 = Demon.new(CFrame.lookAt(bigAt, Vector3.new(bigFace.X, bigAt.Y, bigFace.Z)), BIG_SCALE, folder2, { yieldEvery = 400 })
	D2.hook = hookFor(D2)
	demonPose[D2] = {}
	D2.folder = folder2
	-- the people
	local rm = ownerModel()
	local hm = playerModel()
	if rm then
		R = Puppet.new(rm, { name = "Rayan", parent = workspace })
	end
	if hm then
		H = Puppet.new(hm, { name = "Hero", parent = workspace })
		hm:Destroy()
	end
	if rm and rm.Parent == nil then
		rm:Destroy()
	end
	SH = Shears.new(workspace)
	-- (models and textures in view before the first frame)
	pcall(function()
		local list: { Instance } = { probe }
		if R then
			table.insert(list, R.model)
		end
		if H then
			table.insert(list, H.model)
		end
		ContentProvider:PreloadAsync(list)
	end)
	local t0 = os.clock()
	while not probe.IsLoaded and os.clock() - t0 < 6 do
		task.wait(0.05)
	end
	probe:Destroy()
	prepared = R ~= nil and H ~= nil
	return prepared
end

-------------------------------------------------------------------------------------------------------------
-- THE SHOTS. Each names the reference shot it's built on (the owner's reference videos, frames compared side by
-- side): SR = "Sukuna Raid Intro" (MobWshN54vo, at its seconds), TSB = "Unlimited Flexworks" (qRjNRrKiaTc),
-- BL = the Blue Lock cutscenes (_SaVIYa7dnI).
-------------------------------------------------------------------------------------------------------------
-- the lens's helpers: tall grass by the lens hidden, a key light for close-ups, cel-shaded slash arcs
-------------------------------------------------------------------------------------------------------------
local clearR = 4
local hiddenTufts: { [BasePart]: boolean } = {}
local function clearGrass()
	local cam = workspace.CurrentCamera
	if not cam or not S then
		return
	end
	local p = cam.CFrame.Position
	for _, t in S.tufts do
		local part = t.part
		if part and part.Parent then
			local hide = (t.at.Position - p).Magnitude < clearR + 2.4 * t.scale
			if hide ~= (hiddenTufts[part] == true) then
				hiddenTufts[part] = if hide then true else nil
				part.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
	end
end

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

-- A cel-shaded slash (SR 15.2: flat streaks of light): a crescent of white-hot segments with a gold rim, in the plane
-- facing `normal` through `center`, from a0 to a1 degrees, `radius` studs; it flashes, then thins away.
local function slashArc(center: Vector3, normal: Vector3, up: Vector3, radius: number, a0: number, a1: number, color: Color3?)
	local n = 16
	local f = CFrame.lookAt(center, center + normal, up)
	for i = 0, n - 1 do
		local k0, k1 = i / n, (i + 1) / n
		local g0, g1 = math.rad(a0 + (a1 - a0) * k0), math.rad(a0 + (a1 - a0) * k1)
		local p0 = (f * CFrame.new(math.cos(g0) * radius, math.sin(g0) * radius, 0)).Position
		local p1 = (f * CFrame.new(math.cos(g1) * radius, math.sin(g1) * radius, 0)).Position
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude
		local thick = 0.2 + math.sin(math.pi * (k0 + k1) / 2) * radius * 0.16
		local cf = CFrame.lookAt(mid, p1, f.LookVector)
		local core = neon(Vector3.new(thick, 0.12, len + 0.15), cf, WHITE, 0)
		local rim = neon(Vector3.new(thick * 1.9, 0.08, len + 0.3), cf * CFrame.new(0, -0.05, 0), color or GOLD, 0.35)
		fadeOut(core, 0.24, Vector3.new(0.05, 0.12, len))
		fadeOut(rim, 0.3, Vector3.new(0.05, 0.08, len))
	end
end

-------------------------------------------------------------------------------------------------------------
-- I. NIGHT
-------------------------------------------------------------------------------------------------------------
local function night()
	Film.light({
		ClockTime = 0.4,
		Brightness = 2.4,
		ExposureCompensation = 0.3,
		Ambient = Color3.fromRGB(52, 46, 84),
		OutdoorAmbient = Color3.fromRGB(96, 98, 156),
		ColorShift_Top = Color3.fromRGB(160, 176, 255),
		ColorShift_Bottom = Color3.fromRGB(60, 30, 80),
		atmosphere = { Density = 0.34, Offset = 0.12, Haze = 1.4, Glare = 0, Color = Color3.fromRGB(86, 66, 132), Decay = Color3.fromRGB(122, 70, 150) },
	}, 0)
	Film.grade({ Brightness = 0, Contrast = 0.18, Saturation = 0, TintColor = Color3.fromRGB(222, 218, 255) }, 0)
	Film.vignette(0.5, 0)
	Film.glow(0.7, 22, 0)
end

local function actI(): boolean
	night()
	IntroUi.letterbox(true, 0)
	IntroUi.fade(1, 1.2)
	FilmAudio.amb("ambWind", 0.9, 1.5)
	FilmAudio.amb("eerie", 0.5, 2)
	tracks.sky = function(_dt, t)
		local tt = now()
		local k = if tt < T.sky then (tt / T.sky) * 0.3 elseif tt < T.split then 0.3 + (tt - T.sky) / (T.split - T.sky) * 0.7 else 1
		S.crackSky(k, t)
	end
	after(T.sky, function()
		sfx("servo", 0.5, 0.6)
		FilmAudio.glitch(0.5)
	end)
	-- 1. [SR 0.2, low behind the debris] the valley from the ground behind the path's fence and a lantern, the sky
	-- starting to crack; a slow slide right
	clearR = 1.5
	if not shot(T.sky, function(k)
		local p = V(-3.2 + k * 1.6, 1.15 + k * 0.15, 31)
		return look(p, V(1 + k * 1.6, 13, -60)), mm(26), V(0, 4, -20)
	end, { hand = 0.3 }) then
		return false
	end
	-- 2. [SR 4.2, a Dutch angle up at the sky] the cracks spreading over the windmill
	clearR = 4
	if not shot(T.split, function(k)
		local p = V(24, 1, -14)
		return look(p, V(44.8 + k * 6, 41.4 + k * 4, -111.8), -12), mm(26), V(20, 300, -640)
	end, { hand = 0.4 }) then
		return false
	end
	-- 3. [SR 11.2, darkness and one light] low along the ground at the fissure: pink light up out of the cracks, the
	-- rocks trembling
	for i, g in S.glow do
		task.delay(i * 0.04, function()
			if g.Parent then
				TweenService:Create(g, TweenInfo.new(0.35), { Transparency = 0 }):Play()
				local pl = g:FindFirstChildOfClass("PointLight")
				if pl then
					TweenService:Create(pl, TweenInfo.new(0.6), { Brightness = 2.5 }):Play()
				end
			end
		end)
	end
	TweenService:Create(S.pinkLight, TweenInfo.new(1), { Brightness = 3 }):Play()
	sfx("rumble", 1.2)
	sfx("demonSwell", 0.9)
	Film.shake(0.25, 0.3)
	tracks.rim = function()
		local tt = now()
		S.lift(math.clamp((tt - T.split) / 1.3, 0, 1) * 0.3 + math.clamp((tt - T.rise) / 0.6, 0, 1) * 0.7)
	end
	fx("Dust", at(DEMON_AT, 0.5), { scale = 2.2 })
	if not shot(T.rise, function(k)
		local p = V(8 - k * 1.2, 0.75, -39.5 - k * 1.5)
		return look(p, V(0, 0.6, -52), -4), mm(30), V(0, 0, -52)
	end, { hand = 0.7 }) then
		return false
	end
	-- 4. [SR 7.2, scale] IT RISES, seen whole from the ground far off, rocks flying, eyes lighting
	D.state.rise = 0.05
	tracks.demonRise = function()
		local tt = now()
		D.state.rise = 0.05 + ease.out(math.clamp((tt - T.rise) / 1.15, 0, 1)) * 0.95
		D.state.eyes = ease.out(math.clamp((tt - T.eyes) / 0.18, 0, 1))
		D.state.roar = math.clamp((tt - T.roar) / 0.25, 0, 1) * (1 - math.clamp((tt - T.roar - 1.1) / 0.6, 0, 1) * 0.8)
	end
	sfx("impact", 1.2)
	sfx("riseDark", 1.0)
	Film.shake(0.7, 0.9)
	pcall(FilmVfx.play, "DemonRise", at(DEMON_AT, 0), { scale = 1.4 })
	after(T.eyes, function()
		sfx("sting", 0.9)
		Film.punch(4)
	end)
	if not shot(T.roar, function(k)
		local p = V(6, 1.2, -6 + k * 1.2)
		return look(p, V(0, 22 + k * 4, -52), 3), mm(19), V(0, 24, -52)
	end, { hand = 0.4 }) then
		return false
	end
	-- 5. [SR 5.7, an extreme close-up with speed lines] the roar, in its face
	sfx("roar", 1.4, 0.8)
	sfx("growl", 1.1, 0.7)
	Film.shake(0.85, 1.0)
	pcall(FilmVfx.play, "DemonRoar", D.head() * CFrame.new(0, 0, -6), { scale = 1.3 })
	D.glitchNow(0.12)
	local stopLines = AnimeFx.lines(WHITE, 0.45)
	if not shot(T.feet, function(k)
		local e = D.eyes()
		local p = e + Vector3.new(-5 + k * 0.8, -3.5, 15 - k * 2)
		return look(p, e + Vector3.new(0, -2.5, 0), 12), mm(32), e
	end, { hand = 0.3 }) then
		return false
	end
	stopLines()
	return true
end

-------------------------------------------------------------------------------------------------------------
-- II. RAYAN
-------------------------------------------------------------------------------------------------------------
local walkFrom, walkTo = Vector3.new(-1.5, 0, -17), R1

local function walkTrack()
	R:pose("drag", 0)
	R:walk(1, 1.5, "cool", false)
	R:look(at(DEMON_AT, 26), 0.6)
	shearsMode = "drag"
	local nextStep, nextSpark = 0, 0
	tracks.walk = function()
		local tt = now()
		local k = math.clamp((tt - T.feet) / (T.card - T.feet), 0, 1)
		stand(R, walkFrom:Lerp(walkTo, k), DEMON_AT)
		if tt >= nextStep and k < 1 then
			nextStep = tt + 0.33
			sfx("stepGrass", 0.8, 0.9 + math.random() * 0.15)
		end
		if tt >= nextSpark and k < 1 then
			nextSpark = tt + 0.1
			local a, b = SH:tips()
			fx("Sparks", if a.Y < b.Y then a else b, { scale = 0.35, color = GOLD })
		end
	end
end

local function actII(): boolean
	walkTrack()
	sfx("bladeDraw", 0.8, 0.7)
	-- 6. [BL, a low tracking shot] in front of him at boot height, backing away as he comes: his boots, the shears
	-- scraping along behind him, sparks; the demon's pink light rims him
	clearR = 4
	key(nil)
	if not shot(T.walk, function(_k)
		local root = R.root
		local g = root.Position.Y + R.ground
		local p = root.Position + root.LookVector * 4.4 + root.RightVector * 0.9
		p = Vector3.new(p.X, g + 0.45, p.Z)
		local target = root.Position + Vector3.new(0, -1.3, 0)
		return look(p, target, -2), mm(26), target
	end, { hand = 0.5 }) then
		return false
	end
	-- 7. [SR 29.3, over the shoulder] low behind him: his back big on the left, the colossus ahead
	AnimeFx.sub("You're on my *lawn*.", 1.25)
	if not shot(T.card, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 3.6 + root.RightVector * 1.5 + Vector3.new(0, -0.9 - k * 0.3, 0)
		return look(p, at(DEMON_AT, 27), 2), mm(22), at(DEMON_AT, 26)
	end, { hand = 0.4 }) then
		return false
	end
	-- 8. [SR 6.7, a silhouette against the moon] THE CARD: he swings the shears up onto his shoulder on the beat,
	-- black against a huge moon
	tracks.walk = nil
	R:walk(0)
	stand(R, R1, DEMON_AT)
	R:pose("shoulder", 0.14, "snap")
	R:look(nil)
	shearsMode = "shoulder"
	sfx("swingBlade", 1.2, 0.8)
	sfx("bladeDraw", 1, 1.1)
	AnimeFx.card(Config.FILMS_V2.ownerName, Config.FILMS_V2.ownerTitle, GOLD, 1.5)
	Film.punch(3)
	local moonPos = S.moon.Position
	if not shot(T.clawUp, function(k)
		local chest = chestOf(R).Position + Vector3.new(0, 0.6, 0)
		local dir = (moonPos - chest).Unit
		local p = chest - dir * (7.5 - k * 0.6) + Vector3.new(0, -0.4, 0)
		return look(p, chest:Lerp(moonPos, 0.002)), mm(40), chest
	end, { hand = 0.2 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the exchange: the claw, three cuts, the arm drops
-------------------------------------------------------------------------------------------------------------
local function exchange(): boolean
	-- 9. [SR 11.2, a dark shape fills the frame] low behind him: the claw goes up, and comes down on him; he's gone
	-- a frame before it lands
	local P = demonPose[D]
	tracks.claw = function()
		local tt = now()
		local up = ease.out(math.clamp((tt - T.clawUp) / 0.35, 0, 1))
		local down = ease.inn(math.clamp((tt - (T.claw - 0.16)) / 0.16, 0, 1))
		P.lean = down * 14
		P.armR = { pitch = -45 * up * (1 - down) + 25 * down, yaw = 6 * up + 16 * down }
	end
	sfx("growl2", 1.0, 0.8)
	after(T.claw - 0.25, function()
		sfx("whoosh", 1.2, 0.6)
	end)
	after(T.claw - 0.04, function()
		R:ghost(WHITE, 0.45, 0.3)
		R:show(false)
		shearsMode = "hidden"
	end)
	after(T.claw, function()
		sfx("slam", 1.3)
		sfx("thud", 1.0, 0.7)
		Film.shake(0.7, 1.6)
		fx("GroundSlam", at(R1, 0.3), { scale = 1.6 })
		fx("Dust", at(R1, 0.5), { scale = 2.2 })
	end)
	if not shot(T.snip1, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 5 + root.RightVector * 2.2 + Vector3.new(0, -2.2, 0)
		return look(p, root.Position + root.LookVector * 6 + Vector3.new(0, 12 - k * 4, 0), 6), mm(20), root.Position
	end, { hand = 0.6 }) then
		return false
	end
	-- 10-12. [SR 15.2 / 18.25: flat slash streaks, a white smear] three cuts along the arm lying in the dirt, three
	-- angles, each with a slash of light across the arm and a smear across the frame
	tracks.claw = nil
	local shoulder = D.frame("armR").Position
	local elbow = D.frame("foreR").Position
	local fore = D.frame("foreR").LookVector
	local body = at(DEMON_AT, 14)
	local cuts = { shoulder:Lerp(elbow, 0.45), elbow, elbow + fore * 9 }
	local lift = { 3.2, 2.2, 1.4 }
	local angles = { -32, 18, 64 }
	local times = { T.snip1, T.snip2, T.snip3, T.fall }
	R:show(true)
	shearsMode = "two"
	SH:trail(true)
	for i = 1, 3 do
		local c = cuts[i]
		local out = Vector3.new(c.X - body.X, 0, c.Z - body.Z)
		out = if out.Magnitude > 0.1 then out.Unit else Vector3.new(-1, 0, 0)
		local side = out:Cross(UP).Unit * (if i == 2 then -1 else 1)
		local p = c + out * 4 + side * 2 + UP * lift[i]
		R.root = CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z))
		R:pose("leapOpen", 0)
		R:pose("snipShut", 0.06, "snap")
		R:update(0)
		if i > 1 then
			R:ghost(WHITE, 0.6, 0.25)
		end
		AnimeFx.smear(angles[i] + 180 * (i % 2), if i % 2 == 0 then 1 else -1)
		task.delay(0.04, function()
			AnimeFx.slash(angles[i], { y = 0.5, life = 0.1, width = 0.02 })
		end)
		sfx("bladeSlash", 1.1, 0.95 + i * 0.07)
		sfx("slice", 0.9, 0.8 + i * 0.1)
		slashArc(c, (p - c).Unit, UP:Lerp(side, 0.4).Unit, 5, -70 + i * 40, 110 + i * 40)
		fx("CorruptHit", c, { scale = 0.9 })
		Film.shake(0.35, 3)
		local camOff = ({ Vector3.new(3, -4, 0), Vector3.new(0, 2, 0), Vector3.new(0, 5, 0) })[i]
		local roll = ({ -14, 10, -4 })[i]
		if not shot(times[i + 1], function(_k)
			local cp = p + (p - c).Unit * 7 + side * 4 + camOff
			return look(cp, p:Lerp(c, 0.4), roll), mm(28), p
		end, { hand = 0.15 }) then
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the arm falls; his eye; the reset
-------------------------------------------------------------------------------------------------------------
local function armFalls(): boolean
	local P = demonPose[D]
	local pivot = D.frame("armR").Position
	local land = at(Vector3.new(-26, 0, -40), 0)
	local fallStart = now()
	tracks.armFall = function()
		local k = math.clamp((now() - fallStart) / 0.5, 0, 1)
		local e = ease.inn(k)
		local drop = (Vector3.new(land.X, pivot.Y * 0.2 + land.Y * 0.8, land.Z) - pivot) * e + Vector3.new(0, 3 * math.sin(k * math.pi), 0)
		local rot = about(pivot, CFrame.fromAxisAngle(Vector3.zAxis, math.rad(-60 * e)) * CFrame.fromAxisAngle(Vector3.xAxis, math.rad(20 * e)))
		P.cutM = CFrame.new(drop) * rot
	end
	after(T.fall + 0.5, function()
		sfx("slam", 1.0, 0.8)
		Film.shake(0.45, 2)
		fx("Dust", land, { scale = 2.4 })
	end)
	sfx("burst", 1.0, 0.7)
	sfx("roar", 1.2, 1.15)
	D.glitchNow(0.15)
	D.state.roar = 0.6
	fx("CorruptHit", pivot, { scale = 1.6 })
	-- 13. [SR 16.0, the small figure and the big thing] he lands low in the foreground, the arm crashes behind him
	SH:trail(false)
	stand(R, R2, DEMON_AT)
	R:pose("landCut", 0.08, "snap")
	shearsMode = "out"
	shearsOpen = 12
	sfx("stepThud", 1.2, 0.8)
	fx("DustKick", at(R2, 0.3), { scale = 1.2 })
	if not shot(T.eye, function(k)
		local root = R.root
		local p = root.Position + root.LookVector * 3.4 - root.RightVector * 5.5 + Vector3.new(0, -2.0, 0)
		return look(p, root.Position:Lerp(land, 0.45) + Vector3.new(0, 1.5, 0), -3), mm(22), root.Position
	end, { hand = 0.5 }) then
		return false
	end
	-- 14. [SR 9.7, an extreme close-up of an eye] his eye, pink light flickering on it as the arm twitches
	R:pose("stand", 0.4)
	R:look(at(Vector3.new(-14, 10, -46)), 1)
	local flick = 0
	tracks.flicker = function()
		flick += 1
		local h = headOf(R)
		key(h + R.root.LookVector * 1.6 + Vector3.new(0, 0.6, 0), PINK, if flick % 7 < 3 then 2.6 else 0.6, 6)
	end
	if not shot(T.reset, function(k)
		local h = headOf(R)
		local root = R.root
		local p = h + root.LookVector * (1.6 - k * 0.2) + root.RightVector * 0.12 + Vector3.new(0, 0.12, 0)
		return look(p, h + root.RightVector * 0.18 + Vector3.new(0, 0.12, 0)), mm(85), h
	end, { hand = 0.12 }) then
		return false
	end
	tracks.flicker = nil
	key(nil)
	return true
end

-- A pink loading ring over a demon's head (it adapts): eight pixels lighting in turn, then all, then gone.
local function loadingRing(d: any, from: number, done: number)
	local head = d.model:FindFirstChild("Root_head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Adapt"
	bb.Size = UDim2.fromScale(14 * d.scale, 14 * d.scale)
	bb.StudsOffset = Vector3.new(0, 30 * d.scale, 0)
	bb.LightInfluence = 0
	bb.Adornee = head
	bb.Parent = head
	local dots = {}
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromScale(0.16, 0.16)
		f.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.38, 0.5 + math.sin(a) * 0.38)
		f.BackgroundColor3 = PINK
		f.BackgroundTransparency = 0.75
		f.Parent = bb
		dots[i] = f
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1.6, 0.28)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 1.02)
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 196, 236)
	label.Text = ""
	label.Parent = bb
	local name = "ring" .. tostring(d)
	tracks[name] = function()
		local tt = now()
		if tt < from then
			bb.Enabled = false
			return
		end
		bb.Enabled = true
		if tt < done then
			local lit = math.floor((tt - from) * 14) % 8 + 1
			for i, f in dots do
				local dist = (lit - i) % 8
				f.BackgroundTransparency = if dist == 0 then 0 elseif dist == 1 then 0.35 elseif dist == 2 then 0.6 else 0.85
			end
			label.Text = string.format("ADAPTING %d%%", math.clamp(math.floor((tt - from) / (done - from) * 100), 0, 99))
		elseif tt < done + 0.7 then
			for _, f in dots do
				f.BackgroundTransparency = if math.floor((tt - done) * 12) % 2 == 0 then 0 else 0.3
			end
			label.Text = "ADAPTED"
		else
			bb:Destroy()
			tracks[name] = nil
		end
	end
	after(done, function()
		sfx("zapStrike", 0.7, 1.6)
		sfx("chip", 1, 1.4)
	end)
end

local function reset(): boolean
	-- 15. the pieces lift off the ground, hang, fly back and lock on; the ring spins; "...It grows back."
	local P = demonPose[D]
	local backFrom, backTo = T.reset + 0.15, T.reset + 0.75
	tracks.armFall = nil
	local m0 = P.cutM or CFrame.identity
	local lean0, arm0 = P.lean or 0, P.armR or { pitch = 0, yaw = 0 }
	tracks.armBack = function()
		local tt = now()
		if tt < backFrom then
			local j = if math.random() < 0.3 then CFrame.new((math.random() - 0.5) * 0.6, math.random() * 0.4, 0) else CFrame.identity
			P.cutM = j * m0
		else
			local k = ease.inOut(math.clamp((tt - backFrom) / (backTo - backFrom), 0, 1))
			P.cutM = m0:Lerp(CFrame.identity, k)
			P.lean = lean0 * (1 - k)
			P.armR = { pitch = arm0.pitch * (1 - k), yaw = arm0.yaw * (1 - k) }
		end
		if tt >= backTo then
			P.cutM, P.armR, P.lean = nil, nil, 0
			tracks.armBack = nil
		end
	end
	after(backFrom, function()
		sfx("suck", 1.2, 1.3)
		D.glitchNow(0.2)
		FilmAudio.glitch(0.6)
	end)
	after(backTo, function()
		sfx("crate", 0.9, 1.5)
		sfx("synthWhomp", 1.0, 1.2)
		D.glitchNow(0.12)
		fx("CorruptHit", D.frame("armR").Position, { scale = 1.4 })
		Film.flash(PINK, 0.4, 0.25)
	end)
	loadingRing(D, T.reset + 0.1, T.reset + 0.95)
	after(T.reset + 0.25, function()
		AnimeFx.sub("...It grows *back*.", 1.15)
	end)
	shearsMode = "out"
	shearsOpen = 0
	-- (wide enough for the ring over its head and him small below)
	if not shot(T.clang, function(k)
		local p = at(R2 + Vector3.new(14, 3, 12))
		return look(p, at(Vector3.new(-10, 30 + k * 4, -50)), 2), mm(20), at(Vector3.new(-12, 20, -50))
	end, { hand = 0.4 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- CLANG; the backhand; through the shed; down in the wreck
-------------------------------------------------------------------------------------------------------------
local function clang(): boolean
	-- 16. [TSB 6.5, a black-and-white impact frame] the same cut clangs off the arm: sparks, a jolt
	local elbow = D.frame("foreR").Position
	local body = at(DEMON_AT, 10)
	local out = Vector3.new(elbow.X - body.X, 0, elbow.Z - body.Z).Unit
	local p = elbow + out * 4.2 + UP * 0.5
	R.root = CFrame.lookAt(p, Vector3.new(elbow.X, p.Y, elbow.Z))
	R:pose("snipOpen", 0)
	R:pose("jolt", 0.1, "snap")
	R:update(0)
	shearsMode = "two"
	local hit = elbow + out * 1.2
	sfx("bladeClang", 1.4, 0.9)
	sfx("hit", 1.0, 0.6)
	fx("Sparks", hit, { scale = 1.6, color = GOLD })
	fx("Hit", hit, { scale = 1.0 })
	task.delay(0.03, function()
		AnimeFx.impact({ R.model, SH.model, table.unpack(armParts(D, "R")) }, "neg", { hold = 0.1, at = hit })
	end)
	Film.shake(0.5, 2.5)
	if not shot(T.back, function(_k)
		local side = out:Cross(UP).Unit
		local cp = hit + out * 7 + side * 3.5 + UP * 1.5
		return look(cp, hit:Lerp(p, 0.4), 8), mm(30), hit
	end, { hand = 0.3 }) then
		return false
	end
	-- 17. [SR 22.33, a white burst; TSB 7.5, a red ink burst] the backhand in slow motion: the arm swings out, he's
	-- hit, an impact frame, he flies
	local P = demonPose[D]
	tracks.backhand = function()
		local k = math.clamp((now() - T.back) / 0.45, 0, 1)
		P.armR = { pitch = -10 * ease.out(k), yaw = -55 * ease.inOut(k) }
		P.lean = 6 * k
	end
	Film.speed(0.3, 0.1)
	sfx("whoosh", 1.2, 0.5)
	local flyFrom = p
	local flyTo = at(SHED + Vector3.new(-2, 2, -1))
	local hitT = T.back + 0.3
	after(hitT, function()
		AnimeFx.impact({ R.model, SH.model, table.unpack(armParts(D, "R")) }, "red", { hold = 0.12, at = flyFrom })
		sfx("punch", 1.2, 0.7)
		sfx("bigHit", 0.8, 0.9)
		Film.shake(0.8, 1.6)
		R:pose("flung", 0.06, "snap")
		R:shake(1)
		shearsMode = "out"
	end)
	tracks.fly = function()
		local tt = now()
		if tt < hitT then
			return
		end
		local k = math.clamp((tt - hitT) / (T.shed - hitT), 0, 1)
		local q = flyFrom:Lerp(flyTo, k) + UP * math.sin(k * math.pi) * 3
		local dir = (flyTo - flyFrom).Unit
		R.root = CFrame.lookAt(q, q - dir) * CFrame.Angles(0, 0, math.rad(k * 220))
		if math.random() < 0.35 then
			R:ghost(Color3.fromRGB(255, 220, 160), 0.7, 0.2)
		end
	end
	if not shot(T.shed - 0.25, function(_k)
		local mid = flyFrom:Lerp(flyTo, 0.3)
		local side = (flyTo - flyFrom):Cross(UP).Unit
		local cp = mid + side * 16 + UP * 3
		return look(cp, R.root.Position:Lerp(mid, 0.5), -4), mm(26), R.root.Position
	end, { hand = 0.3 }) then
		return false
	end
	Film.speed(1, 0.15)
	tracks.backhand = nil
	P.armR, P.lean = nil, 0
	return true
end

-- the shed's bricks fly apart, away from where he came in
local function blowShed(from: Vector3)
	local shedModel = S.shed
	if not shedModel then
		return
	end
	local rng = Random.new(7)
	for _, p in shedModel:GetDescendants() do
		if p:IsA("BasePart") then
			local out = (p.Position - from)
			out = Vector3.new(out.X, 0, out.Z)
			local dir = (if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis) + Vector3.new(0, rng:NextNumber(0.3, 1.2), 0)
			local goal = (p.CFrame + dir * rng:NextNumber(4, 16) + Vector3.new(0, -rng:NextNumber(0, 3), 0)) * CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2))
			TweenService:Create(p, TweenInfo.new(rng:NextNumber(0.5, 1.1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
		end
	end
end

local function shed(): boolean
	-- 18. [SR 16.0, wide] through the shed: the bricks blow out, dust
	local hitAt = at(SHED + Vector3.new(6, 2, 0))
	after(T.shed - 0.1, function()
		blowShed(hitAt)
		sfx("crate", 1.3, 0.8)
		sfx("crate2", 1.2, 0.6)
		sfx("thud", 1.3, 0.6)
		sfx("slam", 1.0, 0.7)
		Film.shake(0.7, 1.4)
		fx("Dust", at(SHED, 2), { scale = 3.2 })
		fx("Rocks", at(SHED, 1), { scale = 1.6 })
	end)
	local stopLines = AnimeFx.lines(WHITE, 0.55)
	clearR = 6
	if not shot(T.wreck, function(_k)
		local cp = at(SHED + Vector3.new(16, 3.5, 15))
		return look(cp, at(SHED, 3)), mm(26), at(SHED, 2)
	end, { hand = 0.6 }) then
		return false
	end
	stopLines()
	tracks.fly = nil
	-- 19. [SR 2.2, from straight above, a slow turn in] down on his back in the wreck, dust drifting
	stand(R, SHED + Vector3.new(-1, 0, 2), SHED + Vector3.new(10, 0, -6))
	R:pose("down", 0)
	shearsMode = "out"
	shearsOpen = 0
	fx("Dust", at(SHED + Vector3.new(-1, 0, 2), 1), { scale = 2 })
	if not shot(T.up, function(k)
		local c = R.root.Position + Vector3.new(0, -1.5, 0)
		local a = math.rad(20 + k * 25)
		local cp = c + Vector3.new(math.cos(a) * 0.4, 13 - k * 3, math.sin(a) * 0.4)
		return CFrame.lookAt(cp, c, Vector3.new(math.cos(a + 1.2), 0, math.sin(a + 1.2))), mm(34), c
	end, { hand = 0.1 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- IV. "FINE. LET'S MOW."
-------------------------------------------------------------------------------------------------------------
local function getsUp(): boolean
	-- 20. he gets up out of the wreck and cracks his neck, the pink glow behind him
	R:look(nil)
	R:pose("kneel", 0.35)
	sfx("crate2", 0.6, 1.2)
	after(T.up + 0.65, function()
		stand(R, SHED + Vector3.new(2, 0, 1), R3 + Vector3.new(6, 0, -10))
		R:pose("stand", 0.5)
	end)
	after(T.up + 1.35, function()
		R:pose("crackL", 0.07, "snap")
		sfx("eggCrack", 0.8, 0.75)
	end)
	after(T.up + 1.8, function()
		R:pose("crackR", 0.07, "snap")
		sfx("eggCrack", 0.9, 0.65)
	end)
	clearR = 4
	if not shot(T.fine, function(k)
		local h = headOf(R)
		local root = R.root
		local cp = root.Position + root.LookVector * 6.5 + root.RightVector * 1.8 + Vector3.new(0, -1.6 + k * 0.3, 0)
		key(cp:Lerp(h, 0.6) + Vector3.new(0, 1, 0), Color3.fromRGB(255, 190, 220), 1.2, 9)
		return look(cp, h + Vector3.new(0, -1.2, 0), 3), mm(30), h
	end, { hand = 0.35 }) then
		return false
	end
	-- 21. [SR 24.0, a low close-up of a set face] "Fine. Let's mow." the shears come down into both hands
	R:pose("cool", 0.2)
	R:look(at(DEMON_AT, 20), 0.6)
	AnimeFx.sub("Fine. Let's *mow*.", 1.5)
	after(T.fine + 0.9, function()
		shearsMode = "two"
		R:pose("snipShut", 0.25)
		sfx("bladeDraw", 1.0, 0.9)
	end)
	if not shot(T.stance, function(k)
		local h = headOf(R)
		local root = R.root
		local cp = h + root.LookVector * (3.6 - k * 0.4) - root.RightVector * 0.9 + Vector3.new(0, -1.1, 0)
		key(h + root.LookVector * 2 + Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 230, 210), 1.4, 8)
		return look(cp, h + Vector3.new(0, 0.1, 0)), mm(50), h
	end, { hand = 0.2 }) then
		return false
	end
	key(nil)
	return true
end

local function stance(): boolean
	-- 22. silence; he steps out into the stance; wind sucked in toward him
	music.fade(0.05, 0.7)
	FilmAudio.riser("riseDark", T.ult - now(), { volume = 1.1 })
	after(T.stance + 0.1, function()
		sfx("suck", 1.0, 0.7)
	end)
	stand(R, R3, DEMON_AT)
	R:pose("ultStance", 0.35, "inOut")
	shearsMode = "two"
	SH:glow(0)
	local glowFrom = now()
	tracks.glow = function()
		SH:glow(math.clamp((now() - glowFrom) / 2.8, 0, 1))
	end
	local wind = fx("WindVortex", at(R3, 1), { scale = 1.6, hold = 3, stream = true })
	if not shot(T.ring, function(k)
		local cp = at(R3 + Vector3.new(6 - k, 1.3, -7))
		return look(cp, at(R3, 2.2), -4), mm(24), at(R3, 2)
	end, { hand = 0.3 }) then
		return false
	end
	-- 23. [SR 2.2, from straight above] the gold ring draws itself round him, the demon inside it
	local ring = {}
	local n = 72
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = at(R3 + Vector3.new(math.cos(a) * RING, 0.15, math.sin(a) * RING))
		ring[i] = neon(Vector3.new(RING * 2 * math.pi / n + 0.6, 0.15, 0.9), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), GOLD, 1)
	end
	local ringFrom = now()
	tracks.ring = function()
		local k = math.clamp((now() - ringFrom) / 0.8, 0, 1)
		for i, seg in ring do
			seg.Transparency = if i / n <= k then 0.1 else 1
		end
	end
	sfx("zapCharge", 1.0, 0.7)
	if not shot(T.glint, function(k)
		local c = at(R3 + Vector3.new(14, 0, -22))
		local cp = c + Vector3.new(0, 150 - k * 12, 0.01)
		return CFrame.lookAt(cp, c, Vector3.new(0, 0, -1)), mm(30), c
	end) then
		return false
	end
	-- 24. [TSB 28.5, the technique's title card] the edge glints; the technique's name
	local a = SH:tips()
	fx("Glint", a:Lerp(SH.pivot.Position, 0.4), { scale = 1.2 })
	sfx("chip", 0.8, 2)
	AnimeFx.technique("ONE SNIP", "the Owner's ultimate", GOLD, 0.62)
	if not shot(T.ult, function(_k)
		local piv = SH.pivot.Position
		local cp = piv + R.root.RightVector * 2.6 + R.root.LookVector * 1.4 + Vector3.new(0, 0.5, 0)
		return look(cp, piv:Lerp(a, 0.35)), mm(55), piv
	end, { hand = 0.15 }) then
		return false
	end
	if wind then
		pcall(function()
			wind:Destroy()
		end)
	end
	tracks.ring = nil
	S.ring = ring
	return true
end

local function snip(): boolean
	-- 25. [SR 18.25, a white smear; TSB, whiteouts] ONE SNIP: white
	music.fade(1, 0.05)
	R:pose("ultCut", 0.06, "snap")
	AnimeFx.smear(-4, 1)
	AnimeFx.cover(WHITE, 0, 0, "white")
	AnimeFx.slash(0, { y = 0.5, life = 0.2, width = 0.025 })
	sfx("bladeSlash", 1.5, 0.7)
	sfx("boom", 1.0, 0.8)
	sfx("bigHit", 0.9, 0.7)
	Film.shake(0.6, 2)
	tracks.glow = nil
	SH:glow(0.3)
	AnimeFx.cover(WHITE, 1, 0.6, "white")
	-- 26. [SR 25.3, the still aftermath] still. a thin gold line through everything at one height
	local disc = neon(Vector3.new(0.12, RING * 2, RING * 2), W(R3.X, CUT_Y, R3.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 236, 170), 0.15)
	local okShape = pcall(function()
		disc.Shape = Enum.PartType.Cylinder
	end)
	if not okShape then
		disc.Size = Vector3.new(RING * 2, 0.12, RING * 2)
		disc.CFrame = W(R3.X, CUT_Y, R3.Z)
	end
	S.disc = disc
	music.fade(0.35, 0.3)
	for _, seg in S.ring or {} do
		fadeOut(seg, 0.8)
	end
	if not shot(T.slide, function(k)
		local p = at(R3 + Vector3.new(-5, 1.6, 8))
		return look(p, at(BIG_AT + Vector3.new(4, 0, -12), 6 + k), 1), mm(26), at(R3, 2)
	end, { hand = 0.2 }) then
		return false
	end
	return true
end

local function slide(): boolean
	-- 27. everything above the line slides apart: the grass mown flat, the demon's top half off its waist
	if S.disc then
		fadeOut(S.disc, 0.4)
	end
	local cut = S.mow(R3, RING)
	for i = 1, math.min(#cut, 30) do
		local p = cut[math.random(1, #cut)]
		fx(if i % 2 == 0 then "GrassTuft" else "GrassStreak", p + Vector3.new(0, 1.5, 0), { scale = 0.9, color = Color3.fromRGB(110, 190, 70) })
	end
	sfx("bladeHit", 1.2, 0.8)
	sfx("rustle", 1.4, 0.8)
	sfx("brush", 1.2, 0.9)
	D.split(CUT_Y / SCALE)
	local P = demonPose[D]
	local slideFrom = now()
	local pivot = at(DEMON_AT, CUT_Y)
	tracks.split = function()
		local k = math.clamp((now() - slideFrom) / 1.25, 0, 1)
		local e = ease.inn(k)
		local away = (at(DEMON_AT, 0) - at(R3, 0)).Unit
		local tip = CFrame.fromAxisAngle(UP:Cross(away).Unit, math.rad(62 * e))
		P.top = CFrame.new(away * (2 + 10 * e) + Vector3.new(0, -CUT_Y * e, 0)) * about(pivot + away * 8, tip)
	end
	D.state.roar = 0.3
	D.glitchNow(0.2)
	after(slideFrom + 1.2, function()
		sfx("slam", 1.3, 0.6)
		sfx("rumble", 1.0)
		Film.shake(0.7, 1.4)
		fx("Dust", at(DEMON_AT + Vector3.new(0, 0, -16), 1), { scale = 3.5 })
	end)
	-- the lanterns in the ring lose their tops
	for _, l in S.lanterns do
		if l.top and (flat(l.top.Position) - flat(at(R3, 0))).Magnitude < RING then
			local goal = l.top.CFrame * CFrame.new(math.random(-2, 2), -l.top.Position.Y + S.at.Position.Y + 0.5, math.random(-2, 2)) * CFrame.Angles(1.2, 0, 0.6)
			TweenService:Create(l.top, TweenInfo.new(0.6, Enum.EasingStyle.Bounce), { CFrame = goal }):Play()
		end
	end
	-- 27a. [SR 7.2, scale] wide and low from the side: the top half slides off and falls
	if not shot(T.stubs, function(k)
		local p = at(Vector3.new(26, 2.5, -14))
		return look(p, at(DEMON_AT + Vector3.new(-2, 0, 6), 14 - k * 6)), mm(22), at(DEMON_AT, 10)
	end, { hand = 0.5 }) then
		return false
	end
	-- 28. low in the stubble, clippings still in the air, Rayan beyond, still in his follow-through
	if not shot(T.regrow, function(k)
		local p = at(R3 + Vector3.new(3, 0.6, 6 - k))
		return look(p, at(R3, 1.6)), mm(35), at(R3, 2)
	end, { hand = 0.3 }) then
		return false
	end
	return true
end

-- the fallen top dissolves into pink pixels that pour into the bigger one rising
local function pixelStream(from: Vector3, to: Vector3, time: number)
	local rng = Random.new()
	for _ = 1, 26 do
		local p = neon(Vector3.one * rng:NextNumber(0.6, 1.6), CFrame.new(from + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(0, 14), rng:NextNumber(-10, 10))), if rng:NextNumber() < 0.7 then PINK else Color3.fromRGB(80, 230, 255), 0)
		local mid = (p.Position + to) / 2 + Vector3.new(0, rng:NextNumber(6, 18), 0)
		local delay = rng:NextNumber(0, time * 0.4)
		task.delay(delay, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(time * 0.5, Enum.EasingStyle.Sine), { Position = mid }):Play()
				task.delay(time * 0.5, function()
					if p.Parent then
						TweenService:Create(p, TweenInfo.new(time * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(4, 30), 0), Transparency = 1 }):Play()
					end
				end)
			end
		end)
		task.delay(time + 0.2, function()
			p:Destroy()
		end)
	end
end

local function regrow(): boolean
	-- 29. pink pixels pour off the fallen half into a new one rising over him
	pixelStream(at(DEMON_AT + Vector3.new(0, 0, -12), 4), at(BIG_AT, 10), 1.8)
	FilmAudio.glitch(0.8)
	sfx("suck", 1.2, 0.8)
	sfx("demonSwell", 1.1, 0.9)
	music.fade(0.7, 1.2)
	local f2 = D2.folder
	f2.Parent = workspace
	D2.state.rise = 0
	D2.update(0)
	fx("Crater", at(BIG_AT, 0.2), { scale = 2.2, color = PINK })
	fx("CorruptOrb", at(BIG_AT, 6), { scale = 2 })
	tracks.d2rise = function()
		local tt = now()
		D2.state.rise = ease.out(math.clamp((tt - T.regrow) / 1.9, 0, 1)) * 0.55 + ease.out(math.clamp((tt - T.bigger) / 0.6, 0, 1)) * 0.45
		D2.state.eyes = math.clamp((tt - T.bigger) / 0.15, 0, 1)
		D2.state.roar = math.clamp((tt - T.bigger) / 0.2, 0, 1) * (1 - math.clamp((tt - T.bigger - 1.0) / 0.4, 0, 1))
	end
	loadingRing(D2, T.regrow + 0.2, T.bigger)
	R:pose("stand", 0.5)
	R:look(at(BIG_AT, 30), 1)
	shearsMode = "out"
	shearsOpen = 0
	if not shot(T.bigger, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 5 + root.RightVector * 2.6 + Vector3.new(0, -1.6, 0)
		return look(p, at(BIG_AT, 10 + k * 12), 5), mm(21), at(BIG_AT, 12)
	end, { hand = 0.5 }) then
		return false
	end
	-- the old one is gone
	tracks.split = nil
	pcall(function()
		D.model.Parent:Destroy()
	end)
	D = nil
	return true
end

local function bigger(): boolean
	-- 30. BIGGER: it roars over him; its fists go up, and come down
	sfx("roar", 1.5, 0.65)
	sfx("growl", 1.2, 0.6)
	sfx("impact", 1.1)
	Film.shake(0.9, 1.0)
	pcall(FilmVfx.play, "DemonRoar", D2.head() * CFrame.new(0, 0, -8), { scale = 1.6 })
	R:pose("lookUp", 0.3)
	local P = demonPose[D2]
	tracks.raise = function()
		local tt = now()
		local up = ease.out(math.clamp((tt - (T.bigger + 1.2)) / 0.8, 0, 1))
		local down = ease.inn(math.clamp((tt - (T.slam - 0.32)) / 0.32, 0, 1))
		local pitch = -60 * up * (1 - down) + 30 * down
		P.armR = { pitch = pitch, yaw = 14 * down }
		P.armL = { pitch = pitch, yaw = 14 * down }
		P.lean = 18 * down
	end
	after(T.slam - 0.45, function()
		R:pose("brace", 0.2)
		sfx("whoosh", 1.3, 0.45)
	end)
	-- 30a. [SR 7.2, scale] low behind him: it towers
	if not shot(T.bigger + 1.4, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 4.4 - root.RightVector * 1.5 + Vector3.new(0, -2.0, 0)
		return look(p, at(BIG_AT, 30 + k * 6), -6), mm(18), at(BIG_AT, 30)
	end, { hand = 0.6 }) then
		return false
	end
	-- 31. [SR 11.2, dark shapes over a lit face] his face from low in front, looking up; the fists' shadow coming
	-- down over the top of the frame
	if not shot(T.slam, function(k)
		local h = headOf(R)
		local root = R.root
		local cp = h + root.LookVector * 3.4 + root.RightVector * 0.8 + Vector3.new(0, -2.0, 0)
		key(h + root.LookVector * 2 + Vector3.new(0, -1, 0), PINK, 1.6, 8)
		return look(cp, h + Vector3.new(0, 1.2 + k * 0.6, 0), 6), mm(32), h
	end, { hand = 0.7 }) then
		return false
	end
	key(nil)
	return true
end

-------------------------------------------------------------------------------------------------------------
-- V. THE PLAYER
-------------------------------------------------------------------------------------------------------------
local function blackout(): boolean
	-- 32. [SR 26.3, black and silence] black. silence. a heartbeat.
	music.stop(0.04)
	clockMode = "free"
	setFree(T.slam)
	FilmAudio.hush(0.1)
	AnimeFx.cover(BLACK, 0, 0, "black")
	after(T.slam + 0.7, function()
		sfx("heartbeat", 1.2)
	end)
	after(T.slam + 1.5, function()
		sfx("heartbeat", 1.4)
	end)
	-- (meanwhile: the fists hang just over him; the player isn't there yet)
	tracks.raise = nil
	local P = demonPose[D2]
	P.armR = { pitch = 18, yaw = 14 }
	P.armL = { pitch = 18, yaw = 14 }
	P.lean = 12
	if H then
		H:show(false)
	end
	if not shot(T.streak, function()
		local root = R.root
		return look(root.Position + Vector3.new(6, 2, 6), root.Position), mm(30), root.Position
	end) then
		return false
	end
	return true
end

local function streak(): boolean
	-- 33. a gold streak out of the sky between them: impact, the fists thrown back up
	AnimeFx.cover(BLACK, 1, 0, "black")
	local land = at(P1, 0)
	local beam = neon(Vector3.new(1.6, 420, 1.6), CFrame.new(land + Vector3.new(0, 210, 0)), Color3.fromRGB(255, 230, 150), 0)
	fadeOut(beam, 0.35, Vector3.new(0.2, 420, 0.2))
	fx("GoldBeam", land, { scale = 2.2, color = GOLD })
	sfx("zapStrike", 1.3, 0.7)
	sfx("boom", 1.3, 0.9)
	sfx("slam", 1.4, 0.8)
	task.delay(0.05, function()
		Film.flash(WHITE, 0.8, 0.4)
		Film.shake(1, 1.2)
		fx("Crater", land, { scale = 2.0, color = GOLD })
		fx("GroundRing", land, { scale = 3.0, color = GOLD })
		fx("Dust", land + Vector3.new(0, 1, 0), { scale = 3 })
	end)
	if H then
		H:show(true)
		stand(H, P1, BIG_AT)
		H:pose("heroLand", 0)
	end
	R:pose("kneel", 0.2)
	local P = demonPose[D2]
	local throwFrom = now()
	tracks.throwBack = function()
		local k = ease.out(math.clamp((now() - throwFrom) / 0.5, 0, 1))
		P.armR = { pitch = 18 - 58 * k, yaw = 14 }
		P.armL = { pitch = 18 - 58 * k, yaw = 14 }
		P.lean = 12 - 16 * k
	end
	clearR = 7
	if not shot(T.hero, function(k)
		local p = at(P1 + Vector3.new(18, 5, 16))
		return look(p, at(P1, 5 + k * 5)), mm(22), land
	end, { hand = 0.6, cut = "smash" }) then
		return false
	end
	-- 34. [SR 30.5, the figure low in the haze] the dust clears: the player in the crater, Rayan behind, the fists
	-- hanging over them
	clearR = 4
	if not shot(T.resume, function(k)
		local root = H.root
		local cp = root.Position + root.LookVector * 7 + root.RightVector * 4.5 + Vector3.new(0, -2.4, 0)
		return look(cp, root.Position + Vector3.new(0, 1.5 + k * 2, 0), -4), mm(24), root.Position
	end, { hand = 0.4 }) then
		return false
	end
	return true
end

local function punch(): boolean
	-- 35. [SR 9.7, the eye] the music back on its pickup: the player's eyes
	music2 = FilmAudio.music(Config.FILMS_V2.music, { fade = 0, at = RESUME_AT, loop = false, volume = 1.05 })
	clockMode = "music2"
	lastAdvance = os.clock()
	tracks.throwBack = nil
	local P = demonPose[D2]
	H:pose("heroRise", 0.3)
	H:look(at(BIG_AT, 18), 1)
	if not shot(T.windup, function(k)
		local hd = headOf(H)
		local root = H.root
		local p = hd + root.LookVector * (2.2 - k * 0.3) + Vector3.new(0, 0.05, 0)
		key(hd + root.LookVector * 1.4 + Vector3.new(0, 0.8, 0), Color3.fromRGB(255, 220, 150), 2, 6)
		return look(p, hd + Vector3.new(0, 0.12, 0)), mm(85), hd
	end, { hand = 0.12 }) then
		return false
	end
	-- 36. [SR 24.0, a low close-up, set] up out of the crouch, the fist goes back; gold gathers on it
	H:pose("windup", 0.25, "out")
	sfx("zapCharge", 1.2, 1.1)
	local gold = fx("GoldBurst", H:grip("Right").Position, { scale = 0.6 })
	local stopLines = AnimeFx.lines(GOLD, 0.6)
	-- (the fists come down again to meet it)
	local downFrom = now()
	tracks.slam2 = function()
		local k = ease.inn(math.clamp((now() - downFrom) / (T.punch - downFrom), 0, 1))
		P.armR = { pitch = -40 + 58 * k, yaw = 14 }
		P.armL = { pitch = -40 + 58 * k, yaw = 14 }
		P.lean = -4 + 16 * k
	end
	if not shot(T.punch, function(k)
		local root = H.root
		local h = headOf(H)
		local cp = root.Position + root.LookVector * 4.5 - root.RightVector * 1.2 + Vector3.new(0, -2.2, 0)
		key(h + root.LookVector * 2.5, GOLD, 1.8, 8)
		return look(cp, h + Vector3.new(0, -0.6 + k * 0.4, 0), 7), mm(26), h
	end, { hand = 0.4 }) then
		return false
	end
	stopLines()
	if gold then
		pcall(function()
			gold:Destroy()
		end)
	end
	-- 37. [SR 18.95, the fist big in front] THE PUNCH: on the drop
	tracks.slam2 = nil
	H:pose("punch", 0.05, "snap")
	sfx("punch", 1.6, 0.6)
	sfx("bigHit", 1.2, 0.75)
	sfx("boom", 1.2, 0.7)
	Film.shake(1, 0.9)
	local fist = H:grip("Right").Position
	fx("RingBurst", fist, { scale = 2.4, color = GOLD })
	fx("Shock", fist, { scale = 2.6, color = GOLD })
	task.defer(function()
		local subjects = { H.model, R.model, SH.model }
		for _, p in armParts(D2, "R") do
			table.insert(subjects, p)
		end
		for _, p in armParts(D2, "L") do
			table.insert(subjects, p)
		end
		AnimeFx.impact(subjects, "strobe", { states = { "gold", "ink", "neg", "gold", "ink" }, per = 0.055, at = fist })
	end)
	-- the fists burst
	P.armR = { pitch = -50, yaw = 14 }
	P.armL = { pitch = -50, yaw = 14 }
	P.lean = -8
	if not shot(T.shatter, function(k)
		local root = H.root
		local f = H:grip("Right").Position
		local cp = f + root.LookVector * (2.4 + k * 0.6) + root.RightVector * 0.4 + Vector3.new(0, 0.3, 0)
		key(f + root.LookVector * 1.2, GOLD, 3, 8)
		return look(cp, headOf(H):Lerp(f, 0.35), -6), mm(24), f
	end, { hand = 0.3 }) then
		return false
	end
	key(nil)
	return true
end

-- the demon breaks up: its blocks fly off from the middle, and eight pink shards streak away to the eight lands
local function shatter(d: any)
	local samples = d.samples(if Demon.lite() then 60 else 130)
	local centre = d.model:FindFirstChild("Root_body")
	local c = if centre then (centre :: BasePart).Position + Vector3.new(0, 14 * d.scale, 0) else at(BIG_AT, 20)
	d.folder.Parent = nil
	local rng = Random.new()
	for _, s in samples do
		local p = FilmSet.block(stageFolder(), s.size * rng:NextNumber(0.8, 1.6), s.cf, s.color, Enum.Material.SmoothPlastic, "Shard")
		p.CastShadow = false
		if rng:NextNumber() < 0.35 then
			p.Material = Enum.Material.Neon
			p.Color = if rng:NextNumber() < 0.7 then PINK else Color3.fromRGB(255, 200, 236)
		end
		local out = (p.Position - c)
		out = if out.Magnitude > 0.1 then out.Unit else UP
		local goal = (p.CFrame + out * rng:NextNumber(18, 50) + Vector3.new(0, rng:NextNumber(-10, 20), 0)) * CFrame.Angles(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
		TweenService:Create(p, TweenInfo.new(rng:NextNumber(0.9, 1.8), Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = goal }):Play()
		task.delay(rng:NextNumber(1.2, 2.2), function()
			if p.Parent then
				fadeOut(p, 0.6)
			end
		end)
	end
	-- the eight shards: up and away over the horizon, each to its own land
	S.shards = {}
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.3
		local p = neon(Vector3.new(1.4, 3.6, 1.4), CFrame.new(c), PINK, 0)
		local trail0 = Instance.new("Attachment")
		trail0.Position = Vector3.new(0, 1.2, 0)
		trail0.Parent = p
		local trail1 = Instance.new("Attachment")
		trail1.Position = Vector3.new(0, -1.2, 0)
		trail1.Parent = p
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = trail0, trail1
		tr.Lifetime = 0.6
		tr.LightEmission = 1
		tr.Color = ColorSequence.new(Color3.fromRGB(255, 196, 236), PINK)
		tr.Transparency = NumberSequence.new(0, 1)
		tr.FaceCamera = true
		tr.Parent = p
		local far = c + Vector3.new(math.cos(a) * 420, 0, math.sin(a) * 420)
		local goal = Vector3.new(far.X, S.at.Position.Y + 30, far.Z)
		local mid = c:Lerp(goal, 0.5) + Vector3.new(0, 110, 0)
		local from = c
		local start = os.clock()
		local dur = 1.6 + i * 0.06
		task.spawn(function()
			while p.Parent and os.clock() - start < dur do
				local k = (os.clock() - start) / dur
				local q = from:Lerp(mid, k):Lerp(mid:Lerp(goal, k), k)
				p.CFrame = CFrame.lookAt(q, q + (mid:Lerp(goal, k) - from:Lerp(mid, k))) * CFrame.Angles(math.pi / 2, 0, 0)
				task.wait()
			end
			if p.Parent then
				p.Transparency = 1
				table.insert(S.shards, goal)
			end
		end)
	end
end

local function breakUp(): boolean
	-- 38. [SR 16.95, a burst of light at the horizon] it cracks with light, and shatters from the middle; eight pink
	-- shards fly off over the hills
	D2.glitchNow(0.2)
	after(T.punch + 0.15, function()
		Film.flash(WHITE, 0.6, 0.3)
		D2.glitchNow(0.25)
		sfx("servo", 1, 0.5)
	end)
	after(T.shatter, function()
		shatter(D2)
		sfx("burst", 1.4, 0.6)
		sfx("boom", 1.2, 0.55)
		FilmAudio.glitch(1)
		Film.shake(0.8, 1.2)
		fx("PinkBurst", at(BIG_AT, 20), { scale = 3 })
		fx("CorruptOrb", at(BIG_AT, 18), { scale = 3 })
	end)
	if not shot(T.pillars, function(k)
		local root = H.root
		local p = root.Position - root.LookVector * 6.5 - root.RightVector * 2.2 + Vector3.new(0, -1.4 + k * 1.2, 0)
		return look(p, at(BIG_AT, 18 + k * 14), -3), mm(20), at(BIG_AT, 16)
	end, { hand = 0.5 }) then
		return false
	end
	-- 39. [SR 7.2, far and high] eight pink pillars rise from the eight lands round the valley
	sfx("sting", 1.1, 0.8)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.3
		local p = at(BIG_AT) + Vector3.new(math.cos(a) * 420, 0, math.sin(a) * 420)
		task.delay(i * 0.08, function()
			fx("DarkPillar", p, { scale = 6, color = PINK, hold = 4, life = 6 })
			fx("LightPillar", p, { scale = 5, color = PINK, hold = 4, life = 6 })
		end)
	end
	if not shot(T.lastEye, function(k)
		local p = at(P1 + Vector3.new(30, 60 + k * 10, 60))
		return look(p, at(P1 + Vector3.new(-80, 0, -200), 40)), mm(22), at(P1, 0)
	end, { hand = 0.2 }) then
		return false
	end
	return true
end

-- the demon's last eye, hovering before the player
local function eyeProp(): Model
	local m = Instance.new("Model")
	m.Name = "LastEye"
	local f = stageFolder()
	local ball = FilmSet.block(m, Vector3.new(1.6, 1.6, 1.6), CFrame.identity, Color3.fromRGB(255, 120, 200), Enum.Material.Neon, "Ball")
	ball.Shape = Enum.PartType.Ball
	local slit = FilmSet.block(m, Vector3.new(0.18, 1.1, 0.3), CFrame.new(0, 0, -0.7), Color3.fromRGB(20, 0, 20), Enum.Material.SmoothPlastic, "Slit")
	local glow = FilmSet.block(m, Vector3.new(3.4, 3.4, 3.4), CFrame.identity, PINK, Enum.Material.Neon, "Glow")
	glow.Shape = Enum.PartType.Ball
	glow.Transparency = 0.82
	local l = Instance.new("PointLight")
	l.Color = PINK
	l.Range = 10
	l.Brightness = 2
	l.Parent = ball
	m.PrimaryPart = ball
	m.Parent = f
	slit.CFrame = ball.CFrame * CFrame.new(0, 0, -0.7)
	return m
end

local function lastEye(): boolean
	-- 40. [SR 31.5, the one glowing eye in the dark] one eye left: it hovers in front of the player's face, looks
	-- them over, and zips away
	local eye = eyeProp()
	local hd = headOf(H)
	local face = H.root.LookVector
	local home = hd + face * 3.2 + Vector3.new(0, 0.4, 0)
	H:pose("cool", 0.4)
	H:look(home, 1)
	sfx("servo", 0.8, 1.4)
	tracks.eye = function(_dt, t)
		local tt = now()
		local p = home + Vector3.new(math.sin(t * 2.3) * 0.6, math.sin(t * 3.1) * 0.25, 0)
		if tt >= T.eyeGo then
			local k = (tt - T.eyeGo) / 0.35
			p = p:Lerp(p + Vector3.new(40, 160, -120), math.clamp(k, 0, 1) ^ 2)
		end
		-- it looks the player over: down to the feet, up to the face
		local scan = hd + Vector3.new(0, -2 + math.sin(t * 1.7) * 2, 0)
		eye:PivotTo(CFrame.lookAt(p, scan))
	end
	after(T.eyeGo, function()
		sfx("whoosh", 1.3, 1.5)
		sfx("zapStrike", 0.8, 1.8)
	end)
	if not shot(T.rayan, function(k)
		local p = hd - face * 2.6 + H.root.RightVector * 1.6 + Vector3.new(0, 0.3, 0)
		return look(p, home:Lerp(hd, 0.35)), mm(45), home
	end, { hand = 0.25 }) then
		return false
	end
	tracks.eye = nil
	eye:Destroy()
	return true
end

local function rookie(): boolean
	-- 41. [SR 29.3, over the shoulder] Rayan, on his feet beside the player: "Not bad, rookie." "Free them. Mow it
	-- ALL."
	stand(R, P1 + Vector3.new(-3.6, 0, 2.2), P1 + Vector3.new(4, 0, -12))
	R:pose("shoulder", 0)
	shearsMode = "shoulder"
	R:look(headOf(H), 0.8)
	H:look(nil)
	stand(H, P1, P1 + Vector3.new(4, 0, -12))
	H:pose("cool", 0)
	after(T.rookie, function()
		AnimeFx.sub("Not bad, *rookie*.", 1.3)
	end)
	-- 41a. over Rayan's shoulder (his hair and the shears big on the left) onto the player
	if not shot(T.free - 0.05, function(k)
		local rh = headOf(R)
		local hh = headOf(H)
		local toH = (hh - rh).Unit
		local side = toH:Cross(UP).Unit
		local cp = rh - toH * 2.2 - side * 0.9 + Vector3.new(0, 0.35, 0)
		key(hh - toH * 2 + Vector3.new(0, 1, 0), Color3.fromRGB(255, 226, 200), 1.4, 8)
		return look(cp, hh + Vector3.new(0, -0.2, 0)), mm(42 + k * 4), hh
	end, { hand = 0.25 }) then
		return false
	end
	-- 41b. the two of them from behind, low, looking out at the pink pillars on the hills: "Free them. Mow it ALL."
	key(nil)
	after(T.free, function()
		R:look(at(P1 + Vector3.new(6, 0, -30), 8), 0.8)
		AnimeFx.sub("Free them. Mow it *ALL*.", 1.6)
	end)
	if not shot(T.title, function(k)
		local mid = (R.root.Position + H.root.Position) / 2
		local face = H.root.LookVector
		local cp = mid - face * (6.5 + k * 0.8) + H.root.RightVector * 0.6 + Vector3.new(0, -1.8, 0)
		return look(cp, mid + face * 40 + Vector3.new(0, 9, 0), 2), mm(26), mid
	end, { hand = 0.3 }) then
		return false
	end
	return true
end

local function title(): boolean
	-- 42. THE TITLE: the logo slams in on the hit; behind it, the two of them and the pink pillars on the hills
	AnimeFx.logo()
	sfx("titleHit", 1.3)
	sfx("boom", 0.9, 0.8)
	after(T.title + 1.6, function()
		if music2 then
			music2.stop(2.2)
		end
	end)
	if not shot(T.out, function(k)
		local mid = (R.root.Position + H.root.Position) / 2
		local back = -H.root.LookVector
		local p = mid + back * (9 + k * 4) + Vector3.new(0, 3 + k * 5, 0)
		return look(p, mid - back * 60 + Vector3.new(0, 24, 0)), mm(26), mid
	end, { hand = 0.25 }) then
		return false
	end
	IntroUi.fade(0, 0.6)
	task.wait(0.6)
	return true
end

-------------------------------------------------------------------------------------------------------------
-- playing
-------------------------------------------------------------------------------------------------------------
local function frame(dt: number, t: number)
	if R then
		R:update(dt)
	end
	if H and H.shown then
		H:update(dt)
	end
	placeShears()
	if D then
		D.update(t)
	end
	if D2 and D2.folder and D2.folder.Parent then
		D2.update(t)
	end
	for _, fn in tracks do
		fn(dt, t)
	end
	clearGrass()
end

-- (Studio only, for whoever builds the film) workspace attributes:
--   FilmFastTo = t   runs everything 4x up to film time t (the music too), then normal
--   FilmHoldAt = t   stops the film dead at time t (music paused, the picture held) until the attribute is cleared
local function musicSounds(): { Sound }
	local out = {}
	for _, m in { music, music2 } do
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
			print(string.format("[Opening] HOLD at %.2f", held))
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

-- Run the opening (Film.start has been called; IntroUi is open with its black cover up). Returns when it's done or
-- stopped.
function Opening.play()
	if not prepared then
		if not Opening.prepare() then
			return
		end
	end
	playing = true
	table.clear(events)
	-- the events, on the film's (music's) clock, every frame (even while an impact frame holds the picture)
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
	Film.hand(0.35)
	R.root = W(0, 3, 30)
	stand(R, walkFrom, DEMON_AT)
	R:pose("drag", 0)
	if H then
		H:show(false)
	end
	-- the music from its first bar, the clock on it
	music = FilmAudio.music(Config.FILMS_V2.music, { fade = 0, loop = false })
	lastNow, lastPos, lastAdvance = 0, -1, os.clock()
	setFree(0)
	clockMode = "music1"
	local steps = { actI, actII, exchange, armFalls, reset, clang, shed, getsUp, stance, snip, slide, regrow, bigger, blackout, streak, punch, breakUp, lastEye, rookie, title }
	for _, step in steps do
		if not playing then
			break
		end
		local ok, err = pcall(step)
		if not ok then
			warn("[Opening] " .. tostring(err))
		elseif err == false then
			break
		end
	end
	playing = false
end

-- Take everything away (the end, or SKIP). Safe to call any time.
function Opening.stop()
	playing = false
	prepared = false
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	table.clear(events)
	table.clear(tracks)
	table.clear(demonPose)
	AnimeFx.clear()
	for _, thing in { R, H, SH } do
		pcall(function()
			thing:destroy()
		end)
	end
	R, H, SH = nil, nil, nil
	for _, d in { D, D2 } do
		pcall(function()
			local f = d.folder or d.model.Parent
			d.destroy()
			if f and f:IsA("Folder") then
				f:Destroy()
			end
		end)
	end
	D, D2 = nil, nil
	local f = workspace:FindFirstChild("OpeningDemons")
	if f then
		f:Destroy()
	end
	if S then
		pcall(S.destroy)
		S = nil
	end
	if stage then
		stage:Destroy()
		stage = nil
	end
	music, music2 = nil, nil
	clockMode = "free"
end

return Opening
