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
	sky = 2.4, split = 3.6, rise = 4.92, eyes = 5.66, roar = 6.18, feet = 7.14, walk = 8.4, card = 9.72, face = 10.3,
	claw = 11.02, snip1 = 11.32, snip2 = 11.46, snip3 = 11.64, fall = 11.8, reset = 12.6, clang = 14.5, back = 14.9,
	shed = 15.78, up = 17.14, fine = 19.3, stance = 21.0, ring = 22.3, glint = 23.3, ult = 24.08, after = 24.3,
	slide = 25.5, stubs = 26.4, regrow = 27.0, bigger = 28.9, slam = 31.92, streak = 34.4, hero = 35.2,
	resume = 36.0, windup = 36.5, punch = 37.08, shatter = 37.5, pillars = 39.5, eye = 41.0, eyeGo = 41.88,
	rayan = 42.6, rookie = 42.8, free = 44.2, title = 45.92, out = 49.0,
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
local function setFree(t: number)
	freeBase, freeStart = t, os.clock()
	clockMode = "free"
end

local function now(): number
	local t: number
	if clockMode == "music1" and music and music.sound and music.sound.Parent and music.sound.IsPlaying then
		t = music.sound.TimePosition
	elseif clockMode == "music2" and music2 and music2.sound and music2.sound.Parent and music2.sound.IsPlaying and music2.sound.TimePosition >= RESUME_AT - 0.02 then
		t = T.resume + (music2.sound.TimePosition - RESUME_AT)
	else
		t = freeBase + (os.clock() - freeStart)
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
-- I. NIGHT
-------------------------------------------------------------------------------------------------------------
local function night()
	Film.light({
		ClockTime = 0.4,
		Brightness = 2.2,
		ExposureCompensation = 0.25,
		Ambient = Color3.fromRGB(38, 34, 62),
		OutdoorAmbient = Color3.fromRGB(72, 78, 128),
		ColorShift_Top = Color3.fromRGB(150, 170, 255),
		ColorShift_Bottom = Color3.fromRGB(40, 20, 60),
		atmosphere = { Density = 0.36, Offset = 0.15, Haze = 1.6, Glare = 0, Color = Color3.fromRGB(70, 56, 110), Decay = Color3.fromRGB(110, 60, 140) },
	}, 0)
	Film.grade({ Brightness = 0, Contrast = 0.16, Saturation = -0.05, TintColor = Color3.fromRGB(214, 214, 255) }, 0)
	Film.vignette(0.55, 0)
	Film.glow(0.6, 22, 0)
end

local function actI(): boolean
	night()
	IntroUi.letterbox(true, 0)
	IntroUi.fade(1, 1.4)
	FilmAudio.amb("ambWind", 0.9, 1.5)
	FilmAudio.amb("eerie", 0.5, 2)
	-- the sky starts to crack
	tracks.sky = function(_dt, t)
		local tt = now()
		local k = if tt < T.sky then (tt / T.sky) * 0.3 elseif tt < T.split then 0.3 + (tt - T.sky) / (T.split - T.sky) * 0.7 else 1
		S.crackSky(k, t)
	end
	after(T.sky, function()
		sfx("servo", 0.5, 0.6)
		FilmAudio.glitch(0.5)
	end)
	-- 1. the valley from the grass by the path, pushing in
	if not shot(T.sky, function(k)
		local p = V(6.5, 1.5 + k * 0.3, 34 - k * 2)
		return look(p, V(0, 20 + k * 3, -60)), mm(24), V(0, 6, -40)
	end) then
		return false
	end
	-- 2. the cracks spreading across the sky, the windmill against them
	if not shot(T.split, function(k)
		local p = V(-4, 2, 6)
		return look(p, V(40 + k * 14, 150 + k * 18, -640), 4), mm(40), V(0, 300, -640)
	end) then
		return false
	end
	-- 3. the ground splits: pink light up out of the cracks, the rocks lift, the ground shakes
	for i, g in S.glow do
		task.delay(i * 0.04, function()
			if g.Parent then
				TweenService:Create(g, TweenInfo.new(0.35), { Transparency = 0.05 }):Play()
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
		local p = V(10 - k * 1.5, 1.1, -33 - k * 2)
		return look(p, V(0, 0.5, -52), -5), mm(32), V(0, 0, -52)
	end, { hand = 0.8 }) then
		return false
	end
	-- 4. IT RISES: from the cracks up into the sky, eyes lighting, the roar
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
	after(T.roar, function()
		sfx("roar", 1.4, 0.8)
		sfx("growl", 1.1, 0.7)
		Film.shake(0.85, 1.0)
		pcall(FilmVfx.play, "DemonRoar", D.head() * CFrame.new(0, 0, -6), { scale = 1.3 })
		D.glitchNow(0.12)
	end)
	if not shot(T.feet, function(k)
		local p = V(3, 1.0, -13 + k * 1.5)
		return look(p, V(0, 18 + k * 8, -52), 2), mm(18), V(0, 24, -52)
	end, { hand = 0.4 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- II. RAYAN
-------------------------------------------------------------------------------------------------------------
local walkFrom, walkTo = Vector3.new(-1.5, 0, -17), R1

local function walkTrack()
	-- he walks the last stretch to R1, dragging the shears (sparks off the tip), from T.feet to T.card
	R:pose("drag", 0)
	R:walk(1, 1.5, "cool", false)
	R:look(at(DEMON_AT, 26), 0.6)
	shearsMode = "drag"
	local nextStep, nextSpark = 0, 0
	tracks.walk = function()
		local tt = now()
		local k = math.clamp((tt - T.feet) / (T.card - T.feet), 0, 1)
		local p = walkFrom:Lerp(walkTo, k)
		stand(R, p, DEMON_AT)
		if tt >= nextStep and k < 1 then
			nextStep = tt + 0.4
			sfx("stepGrass", 0.8, 0.9 + math.random() * 0.15)
		end
		if tt >= nextSpark and k < 1 then
			nextSpark = tt + 0.12
			local a, b = SH:tips()
			local tip = if a.Y < b.Y then a else b
			fx("Sparks", tip, { scale = 0.35, color = GOLD })
		end
	end
end

local function actII(): boolean
	walkTrack()
	sfx("bladeDraw", 0.8, 0.7)
	-- 5. his feet on the path, the shears' tip scraping along behind
	if not shot(T.walk, function(k, _t)
		local root = R.root
		local p = root.Position + root.LookVector * 3.4 + root.RightVector * 1.6
		p = Vector3.new(p.X, S.at.Position.Y + 0.7, p.Z)
		local target = root.Position - root.LookVector * 1.2 + Vector3.new(0, -2.4, 0)
		return look(p, target, -3), mm(30), target
	end, { hand = 0.6 }) then
		return false
	end
	-- 6. behind him, low: a small man walking at a colossus
	if not shot(T.card, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * (5.5 - k * 0.6) + root.RightVector * 1.4 + Vector3.new(0, -1.9, 0)
		return look(p, at(DEMON_AT, 22 + k * 3), 3), mm(21), root.Position
	end, { hand = 0.5 }) then
		return false
	end
	-- 7. THE CARD: he swings the shears up onto his shoulder on the beat
	tracks.walk = nil
	R:walk(0)
	stand(R, R1, DEMON_AT)
	R:pose("shoulder", 0.14, "snap")
	shearsMode = "shoulder"
	sfx("swingBlade", 1.2, 0.8)
	sfx("bladeDraw", 1, 1.1)
	AnimeFx.card(Config.FILMS_V2.ownerName, Config.FILMS_V2.ownerTitle, GOLD, 1.75)
	Film.punch(3)
	if not shot(T.face, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 4.6 + root.RightVector * 2.2 + Vector3.new(0, -2.2, 0)
		return look(p, at(DEMON_AT, 24 - k * 2), 6), mm(24), headOf(R)
	end, { hand = 0.3 }) then
		return false
	end
	-- 7b. his face: "You're on my lawn."
	AnimeFx.sub("You're on my lawn.", 1.3)
	if not shot(T.claw, function(k)
		local hd = headOf(R)
		local root = R.root
		local p = hd + root.LookVector * (3.6 - k * 0.3) + root.RightVector * 0.9 + Vector3.new(0, -0.15, 0)
		return look(p, hd + Vector3.new(0, -0.05, 0)), mm(60), hd
	end, { hand = 0.25 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the exchange: the claw, three cuts, the arm drops
-------------------------------------------------------------------------------------------------------------
-- (where Rayan is for each of the three cuts: in the air round the demon's right arm (the west side))
local SNIPS = {
	{ at = Vector3.new(-12, 15, -45), face = Vector3.new(-14, 15, -52), roll = -20 },
	{ at = Vector3.new(-21, 9, -44), face = Vector3.new(-14, 8, -49), roll = 25 },
	{ at = Vector3.new(-8, 4, -38), face = Vector3.new(-15, 3, -40), roll = 0 },
}

local function placeAir(pup: any, p: Vector3, face: Vector3)
	local a, b = at(p), at(face)
	local dir = flat(b - a)
	pup.root = CFrame.lookAt(a, a + (if dir.Magnitude > 0.01 then dir else Vector3.new(0, 0, -1)))
end

local function exchange(): boolean
	-- 8. the claw comes down on him (from the side, wide); he's gone a frame before it lands
	local P = demonPose[D]
	tracks.claw = function()
		local tt = now()
		local k = math.clamp((tt - (T.claw - 0.12)) / 0.2, 0, 1)
		P.lean = ease.inn(k) * 14
		P.armR = { pitch = ease.inn(k) * 22, yaw = ease.inn(k) * 18 }
	end
	sfx("whoosh", 1.2, 0.6)
	sfx("growl2", 1.0, 0.8)
	after(T.claw + 0.07, function()
		R:ghost(WHITE, 0.45, 0.3)
		R:show(false)
		SH:show(false)
		shearsMode = "hidden"
	end)
	after(T.claw + 0.12, function()
		sfx("slam", 1.3)
		sfx("thud", 1.0, 0.7)
		Film.shake(0.6, 1.6)
		fx("GroundSlam", at(R1, 0.3), { scale = 1.6 })
		fx("Dust", at(R1, 0.5), { scale = 2.0 })
	end)
	if not shot(T.snip1, function(k)
		local p = V(14, 3.5 - k * 0.5, -20)
		return look(p, V(-6, 5, -34)), mm(22), at(R1, 2)
	end, { hand = 0.6 }) then
		return false
	end
	-- 9-11. three cuts, three angles, a white slash each
	tracks.claw = nil
	R:show(true)
	shearsMode = "two"
	SH:trail(true)
	local angles = { -32, 18, 64 }
	local cams = {
		function(p: Vector3)
			return look(p + Vector3.new(4, -6, 7), p + Vector3.new(0, 1, 0), -14), mm(26)
		end,
		function(p: Vector3)
			return look(p + Vector3.new(-6, 1, 3), p + Vector3.new(1, 0, -1), 12), mm(32)
		end,
		function(p: Vector3)
			return look(p + Vector3.new(5, 4, 5), p + Vector3.new(-1, -1, -1), -6), mm(24)
		end,
	}
	local times = { T.snip1, T.snip2, T.snip3, T.fall }
	for i = 1, 3 do
		local s = SNIPS[i]
		placeAir(R, s.at, s.face)
		R:pose("leapOpen", 0)
		R:pose("snipShut", 0.07, "snap")
		R:update(0)
		local cutAt = at(s.at) + (at(s.face) - at(s.at)).Unit * 3
		AnimeFx.slash(angles[i], { y = 0.48 + (i - 2) * 0.06, life = 0.1 })
		sfx("bladeSlash", 1.1, 0.95 + i * 0.07)
		sfx("slice", 0.9, 0.8 + i * 0.1)
		fx(if i == 2 then "SlashX" else "Slash", CFrame.lookAt(cutAt, cutAt + Vector3.new(0, 0, 1)) * CFrame.Angles(0, 0, math.rad(angles[i])), { scale = 1.6, color = WHITE })
		fx("CorruptHit", cutAt, { scale = 0.9 })
		Film.shake(0.35, 3)
		local p0 = at(s.at)
		if not shot(times[i + 1], function(_k)
			local cf, fov = cams[i](p0)
			return cf, fov, p0
		end, { hand = 0.2 }) then
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the arm falls; the reset
-------------------------------------------------------------------------------------------------------------
local function armFalls(): boolean
	-- the right arm comes away whole from the shoulder and falls, turning
	local P = demonPose[D]
	local pivot = D.frame("armR").Position
	local land = at(Vector3.new(-26, 0, -40), 0)
	local fallStart = now()
	tracks.armFall = function()
		local k = math.clamp((now() - fallStart) / 0.55, 0, 1)
		local e = ease.inn(k)
		local drop = (Vector3.new(land.X, pivot.Y * 0.25 + land.Y * 0.75, land.Z) - pivot) * e + Vector3.new(0, 4 * math.sin(k * math.pi), 0)
		local rot = about(pivot, CFrame.fromAxisAngle(Vector3.zAxis, math.rad(-70 * e)) * CFrame.fromAxisAngle(Vector3.xAxis, math.rad(25 * e)))
		P.cutM = CFrame.new(drop) * rot
	end
	after(T.fall + 0.55, function()
		sfx("slam", 1.0, 0.8)
		Film.shake(0.45, 2)
		fx("Dust", land, { scale = 2.4 })
	end)
	sfx("burst", 1.0, 0.7)
	sfx("roar", 1.2, 1.15)
	D.glitchNow(0.15)
	D.state.roar = 0.6
	-- he lands low, shears out
	SH:trail(false)
	stand(R, R2, DEMON_AT)
	R:pose("landCut", 0.08, "snap")
	shearsMode = "out"
	shearsOpen = 10
	sfx("stepThud", 1.2, 0.8)
	fx("DustKick", at(R2, 0.3), { scale = 1.2 })
	-- 12. wide: him in the foreground, the arm dropping behind
	if not shot(T.reset, function(k)
		local p = V(-8 + k * 1.5, 2.2, -22)
		return look(p, V(-20, 6, -42)), mm(26), at(R2, 2)
	end, { hand = 0.5 }) then
		return false
	end
	return true
end

-- A pink loading ring over the demon's head (it adapts): eight pixels lighting in turn, then all, then gone.
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
	bb.AlwaysOnTop = false
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
	tracks["ring" .. tostring(d)] = function()
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
			tracks["ring" .. tostring(d)] = nil
		end
	end
	after(done, function()
		sfx("zapStrike", 0.7, 1.6)
		sfx("chip", 1, 1.4)
	end)
end

local function reset(): boolean
	-- 13. the pieces lift off the ground, hang, fly back and lock on; the ring spins; "...It grows back."
	local P = demonPose[D]
	local backFrom, backTo = T.reset + 0.25, T.reset + 1.0
	tracks.armFall = nil
	local m0 = P.cutM or CFrame.identity
	local lean0, arm0 = P.lean or 0, P.armR or { pitch = 0, yaw = 0 }
	tracks.armBack = function()
		local tt = now()
		if tt < backFrom then
			-- (it twitches on the ground)
			local j = if math.random() < 0.3 then CFrame.new((math.random() - 0.5) * 0.6, math.random() * 0.4, 0) else CFrame.identity
			P.cutM = j * m0
		else
			local k = ease.inOut(math.clamp((tt - backFrom) / (backTo - backFrom), 0, 1))
			P.cutM = m0:Lerp(CFrame.identity, k)
			-- (and the body settles back up out of the lunge)
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
	loadingRing(D, T.reset + 0.35, T.reset + 1.45)
	after(T.reset + 0.75, function()
		AnimeFx.sub("...It grows back.", 1.3)
	end)
	R:pose("stand", 0.4)
	shearsMode = "out"
	shearsOpen = 0
	R:look(at(DEMON_AT, 16), 1)
	if not shot(T.clang, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 4.2 + root.RightVector * 2.4 + Vector3.new(0, 1.3, 0)
		return look(p, at(Vector3.new(-14, 12 + k * 3, -52))), mm(30), at(Vector3.new(-14, 10, -50))
	end, { hand = 0.4 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- CLANG; the backhand; through the shed
-------------------------------------------------------------------------------------------------------------
local function clang(): boolean
	-- 14. the same cut clangs off: sparks, a jolt, an impact frame
	local s = SNIPS[2]
	placeAir(R, Vector3.new(-17, 6, -42), Vector3.new(-14, 6, -49))
	R:pose("snipOpen", 0)
	R:pose("jolt", 0.1, "snap")
	R:update(0)
	shearsMode = "two"
	local hit = at(Vector3.new(-15, 7, -46))
	sfx("bladeClang", 1.4, 0.9)
	sfx("hit", 1.0, 0.6)
	fx("Sparks", hit, { scale = 1.6, color = GOLD })
	fx("Hit", hit, { scale = 1.0 })
	task.delay(0.03, function()
		AnimeFx.impact({ R.model, SH.model, table.unpack(armParts(D, "R")) }, "neg", { hold = 0.1, at = hit })
	end)
	Film.shake(0.5, 2.5)
	if not shot(T.back, function(k)
		local p = hit + Vector3.new(5.5, -1.2, 6.5)
		return look(p, hit + Vector3.new(-0.5, 0, 0), 8), mm(34), hit
	end, { hand = 0.3 }) then
		return false
	end
	-- 15. the backhand, in slow motion: the arm swings out, he's hit, an impact frame, he flies
	local P = demonPose[D]
	local swingT = T.back
	tracks.backhand = function()
		local tt = now()
		local k = math.clamp((tt - swingT) / 0.5, 0, 1)
		P.armR = { pitch = -10 * ease.out(k), yaw = -55 * ease.inOut(k) }
		P.lean = 6 * k
	end
	Film.speed(0.3, 0.1)
	sfx("whoosh", 1.2, 0.5)
	local flyFrom = at(Vector3.new(-17, 6, -42))
	local flyTo = at(SHED + Vector3.new(-2, 2, -1))
	local hitT = T.back + 0.32
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
		local p = flyFrom:Lerp(flyTo, k) + UP * math.sin(k * math.pi) * 3
		local dir = (flyTo - flyFrom).Unit
		R.root = CFrame.lookAt(p, p - dir) * CFrame.Angles(0, 0, math.rad(k * 220))
		if math.random() < 0.35 then
			R:ghost(Color3.fromRGB(255, 220, 160), 0.7, 0.2)
		end
	end
	if not shot(T.shed - 0.3, function(k)
		local p = at(Vector3.new(-6, 4, -28)) + Vector3.new(0, 0, 0)
		local target = R.root.Position:Lerp(flyFrom, 0.3)
		return look(p, target, -4), mm(24), R.root.Position
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
	local shed = S.shed
	if not shed then
		return
	end
	local parts = {}
	for _, d in shed:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local rng = Random.new(7)
	for _, p in parts do
		local out = (p.Position - from)
		out = Vector3.new(out.X, 0, out.Z)
		local dir = (if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis) + Vector3.new(0, rng:NextNumber(0.3, 1.2), 0)
		local dist = rng:NextNumber(4, 16)
		local goal = (p.CFrame + dir * dist + Vector3.new(0, -rng:NextNumber(0, 3), 0)) * CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2))
		TweenService:Create(p, TweenInfo.new(rng:NextNumber(0.5, 1.1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
	end
end

local function shed(): boolean
	-- 16. through the shed: the bricks blow out, dust, he's down in the wreck
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
	if not shot(T.shed + 0.25, function(k)
		local p = at(SHED + Vector3.new(14, 3, 13))
		return look(p, R.root.Position:Lerp(at(SHED, 2), 0.5)), mm(22), R.root.Position
	end, { hand = 0.6 }) then
		return false
	end
	stopLines()
	tracks.fly = nil
	-- down in the wreck
	stand(R, SHED + Vector3.new(-1, 0, 2), SHED + Vector3.new(10, 0, -6))
	R:pose("down", 0)
	return true
end

-------------------------------------------------------------------------------------------------------------
-- IV. "FINE. LET'S MOW."
-------------------------------------------------------------------------------------------------------------
local function getsUp(): boolean
	-- 17. the dust settles; he gets up; cracks his neck
	shearsMode = "out"
	shearsOpen = 0
	R:look(nil)
	after(T.up, function()
		R:pose("kneel", 0.35)
		sfx("crate2", 0.6, 1.2)
	end)
	after(T.up + 0.7, function()
		stand(R, SHED + Vector3.new(2, 0, 1), R3 + Vector3.new(6, 0, -10))
		R:pose("stand", 0.5)
	end)
	after(T.up + 1.35, function()
		R:pose("crackL", 0.08, "snap")
		sfx("eggCrack", 0.8, 0.75)
	end)
	after(T.up + 1.75, function()
		R:pose("crackR", 0.08, "snap")
		sfx("eggCrack", 0.9, 0.65)
	end)
	if not shot(T.fine, function(k)
		local p = at(SHED + Vector3.new(8, 1.2 + k * 0.3, -3))
		return look(p, headOf(R) + Vector3.new(0, -0.8, 0), 3), mm(32), headOf(R)
	end, { hand = 0.35 }) then
		return false
	end
	-- 18. close: "Fine. Let's mow." the shears come down into both hands
	R:pose("cool", 0.2)
	R:look(at(BIG_AT + Vector3.new(0, 0, -16), 22), 0.7)
	AnimeFx.sub("Fine. Let's mow.", 1.5)
	after(T.fine + 0.9, function()
		shearsMode = "two"
		R:pose("snipShut", 0.25)
		sfx("bladeDraw", 1.0, 0.9)
	end)
	if not shot(T.stance, function(k)
		local hd = headOf(R)
		local root = R.root
		local p = hd + root.LookVector * (3.3 - k * 0.4) - root.RightVector * 1.0 + Vector3.new(0, -0.2, 0)
		return look(p, hd), mm(58), hd
	end, { hand = 0.2 }) then
		return false
	end
	return true
end

local function stance(): boolean
	-- 19. silence; he walks out of the wreck into the stance; the gold ring draws round him; the edge glints
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
	-- 19a. low and wide, in front
	if not shot(T.ring, function(k)
		local p = at(R3 + Vector3.new(6 - k * 1, 1.4, -7))
		return look(p, at(R3, 2.2), -4), mm(24), at(R3, 2)
	end, { hand = 0.3 }) then
		return false
	end
	-- 19b. from high above: the ring draws itself round him, the demon inside it
	local ring = {}
	local n = 72
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = at(R3 + Vector3.new(math.cos(a) * RING, 0.15, math.sin(a) * RING))
		local seg = neon(Vector3.new(RING * 2 * math.pi / n + 0.6, 0.15, 0.9), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), GOLD, 1)
		ring[i] = seg
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
		local p = c + Vector3.new(0, 150 - k * 12, 0.01)
		return CFrame.lookAt(p, c, Vector3.new(0, 0, -1)), mm(30), c
	end) then
		return false
	end
	-- 19c. the edge glints
	local a, b = SH:tips()
	fx("Glint", a:Lerp(SH.pivot.Position, 0.4), { scale = 1.2 })
	sfx("chip", 0.8, 2)
	if not shot(T.ult, function(k)
		local piv = SH.pivot.Position
		local p = piv + R.root.RightVector * 2.6 + R.root.LookVector * 1.4 + Vector3.new(0, 0.5, 0)
		return look(p, piv:Lerp(a, 0.35)), mm(55), piv
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
	-- 20. ONE SNIP: white
	music.fade(1, 0.05)
	R:pose("ultCut", 0.06, "snap")
	AnimeFx.cover(WHITE, 0, 0, "white")
	AnimeFx.slash(0, { y = 0.5, life = 0.16, width = 0.02 })
	sfx("bladeSlash", 1.5, 0.7)
	sfx("boom", 1.0, 0.8)
	sfx("bigHit", 0.9, 0.7)
	Film.shake(0.6, 2)
	tracks.glow = nil
	SH:glow(0.3)
	AnimeFx.cover(WHITE, 1, 0.6, "white")
	-- 21. after: still. a thin gold line through everything at one height
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
	-- 22. everything above the line slides apart: the grass mown flat, the demon's top half off its waist
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
	-- 22a. wide and low from the side: the top half slides off and falls
	if not shot(T.stubs, function(k)
		local p = at(Vector3.new(26, 2.5, -14))
		return look(p, at(DEMON_AT + Vector3.new(-2, 0, 6), 14 - k * 6)), mm(22), at(DEMON_AT, 10)
	end, { hand = 0.5 }) then
		return false
	end
	-- 22b. low in the stubble, clippings still in the air, Rayan beyond, still in his follow-through
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
	-- 23. pink pixels pour off the fallen half into a new one rising over him
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
	-- 24. BIGGER: it roars over him; its fists go up, and come down
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
	-- 24a. low behind him: it towers
	if not shot(T.bigger + 1.4, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 4.4 - root.RightVector * 1.5 + Vector3.new(0, -2.0, 0)
		return look(p, at(BIG_AT, 30 + k * 6), -6), mm(18), at(BIG_AT, 30)
	end, { hand = 0.6 }) then
		return false
	end
	-- 24b. the fists coming down, from beside him, looking up
	if not shot(T.slam, function(k)
		local root = R.root
		local p = root.Position + root.RightVector * 4 - root.LookVector * 1.5 + Vector3.new(0, -2.3, 0)
		return look(p, root.Position + root.LookVector * 6 + Vector3.new(0, 14 - k * 8, 0), 8), mm(20), headOf(R)
	end, { hand = 0.7 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- V. THE PLAYER
-------------------------------------------------------------------------------------------------------------
local function blackout(): boolean
	-- 25. black. silence. a heartbeat.
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
	-- 26. a gold streak out of the sky between them: impact, the fists thrown back up
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
	if not shot(T.hero, function(k)
		local p = at(P1 + Vector3.new(16, 6, 14))
		return look(p, at(P1, 4 + k * 4)), mm(24), land
	end, { hand = 0.6, cut = "smash" }) then
		return false
	end
	-- 27. the dust clears: the player in the crater, Rayan behind, the fists above
	if not shot(T.resume, function(k)
		local p = at(P1 + Vector3.new(-7 + k, 1.2, 6))
		return look(p, at(P1 + Vector3.new(2, 0, -4), 4.5 + k * 1.5), -3), mm(28), at(P1, 2)
	end, { hand = 0.4 }) then
		return false
	end
	return true
end

local function punch(): boolean
	-- 28. the music back on its pickup: the player's eyes; up out of the crouch; the fist goes back
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
		local p = hd + root.LookVector * 2.4 + Vector3.new(0, -0.15, 0)
		return look(p, hd + Vector3.new(0, 0.05, 0)), mm(85 - k * 10), hd
	end, { hand = 0.15 }) then
		return false
	end
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
		local p = root.Position - root.LookVector * 3.2 + root.RightVector * 2.3 + Vector3.new(0, -2.2, 0)
		return look(p, root.Position + root.LookVector * 4 + Vector3.new(0, 9 - k * 3, 0), -8), mm(22), headOf(H)
	end, { hand = 0.4 }) then
		return false
	end
	stopLines()
	if gold then
		pcall(function()
			gold:Destroy()
		end)
	end
	-- 29. THE PUNCH: on the drop
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
	-- 30. it cracks with light, and shatters from the middle; eight pink shards fly off over the hills
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
	-- 31. far and high: eight pink pillars rise from the eight lands round the valley
	sfx("sting", 1.1, 0.8)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.3
		local p = at(BIG_AT) + Vector3.new(math.cos(a) * 420, 0, math.sin(a) * 420)
		task.delay(i * 0.08, function()
			fx("DarkPillar", p, { scale = 6, color = PINK, hold = 4, life = 6 })
			fx("LightPillar", p, { scale = 5, color = PINK, hold = 4, life = 6 })
		end)
	end
	if not shot(T.eye, function(k)
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
	-- 32. one eye left: it hovers in front of the player's face, looks them over, and zips away
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
	-- 33. Rayan, on his feet beside the player: "Not bad, rookie." "Free them. Mow it ALL."
	stand(R, P1 + Vector3.new(-3.6, 0, 2.2), P1 + Vector3.new(4, 0, -12))
	R:pose("shoulder", 0)
	shearsMode = "shoulder"
	R:look(headOf(H), 0.8)
	H:look(nil)
	stand(H, P1, P1 + Vector3.new(4, 0, -12))
	H:pose("cool", 0)
	after(T.rookie, function()
		AnimeFx.sub("Not bad, rookie.", 1.3)
	end)
	after(T.free, function()
		R:look(at(P1 + Vector3.new(6, 0, -30), 8), 0.8)
		AnimeFx.sub("Free them. Mow it ALL.", 1.6)
	end)
	if not shot(T.title, function(k)
		local mid = (headOf(R) + headOf(H)) / 2
		local face = H.root.LookVector
		local p = mid + face * (7.2 - k * 0.6) + Vector3.new(0, -0.6, 0) + H.root.RightVector * -0.8
		return look(p, mid + Vector3.new(0, -0.3, 0)), mm(38), mid
	end, { hand = 0.3 }) then
		return false
	end
	return true
end

local function title(): boolean
	-- 34. THE TITLE: the logo slams in on the hit; behind it, the two of them and the pink pillars on the hills
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
