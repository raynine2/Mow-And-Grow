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
local WAIST_Y = 9.5 -- (and the demon at its waist: cut at the grass's height only its feet stayed, and the slide
-- read as the whole of it moving)
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

-- cut to a shot that runs until film time `untilT` (k 0..1 over it), and wait for it. Every frame, just before the
-- picture is taken, whatever stands in the lens's way is hidden (clearView: tall grass, props, the demons' blocks).
-- opts.props = false keeps the props (a shot framed through them on purpose).
local lastFocus: Vector3? = nil
local clearView: (cf: CFrame, focus: Vector3?, opts: any) -> ()
local tryCam: any = nil -- (Studio: a camera tried out by hand while the film is held, { cf, fov, focus })
local function shot(untilT: number, fn: (k: number, t: number) -> (CFrame, number, Vector3?), opts: any?): boolean
	if not playing then
		return false
	end
	local o = opts or {}
	Film.cut(math.max(untilT - now(), 0.05), function(k: number, t: number)
		local cf, fov, focus = fn(k, t)
		if tryCam then
			cf, fov, focus = tryCam.cf, tryCam.fov, tryCam.focus
		end
		lastFocus = focus
		clearView(cf, focus, o)
		return cf, fov, focus
	end, opts)
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
-- the head's own frame (its LookVector: where the face looks, after a look() has turned it)
local function headCf(pup: any): CFrame
	local h = pup:part("Head")
	return if h then (pup.world[h] or h.CFrame) else pup.root * CFrame.new(0, 1.5, 0)
end
-- a point on the face at the eyes' height (`up` of the head's height over its middle, 0.06 if not given; Rayan's
-- face has them right at the middle), on its front, `side` studs to the face's own right: close-ups aim here, along
-- the head's own look, so a turned or tipped head stays framed
local function eyesOf(pup: any, side: number?, up: number?): Vector3
	local h = pup:part("Head")
	local size = if h then h.Size else Vector3.new(1.2, 1.2, 1.2)
	return (headCf(pup) * CFrame.new(side or 0, size.Y * (up or 0.06), -size.Z * 0.5)).Position
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
		-- (the blades kept level, a touch up: along the chest's own look, which leans forward in the low stances,
		-- they went down into the ground)
		local fwd = flat(chest.LookVector)
		fwd = if fwd.Magnitude > 0.1 then fwd.Unit else root.LookVector
		SH:grip2(rh, R:grip("Left").Position, fwd + UP * 0.1)
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

-- (round 2, owner: "u cant really tell whats going on": in the night the demon was a black blob of blocks) calm (no
-- glitch jumps of its own), its hide lifted toward violet, and its whole silhouette outlined in pink
local DEMON_LOOK = { yieldEvery = 400, calm = true, lift = 0.32, outline = Color3.fromRGB(255, 90, 200) }

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
	D = Demon.new(CFrame.lookAt(at(DEMON_AT, 0), at(DEMON_AT + Vector3.new(0, 0, 1), 0)), SCALE, folder, DEMON_LOOK)
	D.hook = hookFor(D)
	demonPose[D] = {}
	folder.Parent = workspace
	D.update(0)
	local folder2 = Instance.new("Folder")
	folder2.Name = "OpeningDemon2"
	local bigFace = at(R3, 0)
	local bigAt = at(BIG_AT, 0)
	D2 = Demon.new(CFrame.lookAt(bigAt, Vector3.new(bigFace.X, bigAt.Y, bigFace.Z)), BIG_SCALE, folder2, DEMON_LOOK)
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
-- the lens's helpers: what's in its way hidden, a key light for close-ups, cel-shaded slash arcs
-------------------------------------------------------------------------------------------------------------
local clearR = 4
local hiddenTufts: { [BasePart]: boolean } = {}
clearView = function(cf: CFrame, focus: Vector3?, opts: any)
	if not S then
		return
	end
	local p = cf.Position
	local f = focus
	local seg = if f then f - p else nil
	local segLen = if seg then seg.Magnitude else 0
	local dir = if seg and segLen > 0.01 then seg / segLen else nil
	-- the demons' blocks right at the lens (it never looks out from inside one)
	if D then
		D.nearClip(p, 0.8)
	end
	if D2 and D2.folder and D2.folder.Parent then
		D2.nearClip(p, 0.8)
	end
	-- the props: one the lens is in, or one between it and the subject
	for _, pr in S.props or {} do
		local hide = false
		if opts.props ~= false and pr.radius < 24 then
			local d = (if pr.follow then pr.follow.Position else pr.center) - p
			if d.Magnitude < pr.radius + 1 then
				hide = true
			elseif dir then
				local along = d:Dot(dir)
				if along > 0 and along < segLen - pr.radius * 0.5 - 1 then
					hide = (d - dir * along).Magnitude < pr.radius * 0.8
				end
			end
		end
		if hide ~= pr.hidden then
			pr.hidden = hide
			for _, part in pr.parts do
				part.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
	end
	-- the tall grass by the lens, and in its line of sight
	for _, t in S.tufts do
		local part = t.part
		if part and part.Parent then
			local q = t.at.Position
			local hide = (q - p).Magnitude < clearR + 2.4 * t.scale
			if not hide and dir then
				-- (in the way between the lens and the subject, short of the subject itself)
				local along = (q - p):Dot(dir)
				if along > 0 and along < segLen - 2 then
					local off = (q - p) - dir * along
					hide = Vector3.new(off.X, math.max(0, math.abs(off.Y) - 2.5 * t.scale), off.Z).Magnitude < 1.2 + 2.0 * t.scale
				end
			end
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

-------------------------------------------------------------------------------------------------------------
-- I. NIGHT
-------------------------------------------------------------------------------------------------------------
local function night()
	-- (round 2: a brighter night: the fight was played out in the dark, the owner saw only flashes)
	Film.light({
		ClockTime = 0.4,
		Brightness = 2.8,
		ExposureCompensation = 0.65,
		Ambient = Color3.fromRGB(70, 62, 108),
		OutdoorAmbient = Color3.fromRGB(118, 120, 182),
		ColorShift_Top = Color3.fromRGB(160, 176, 255),
		ColorShift_Bottom = Color3.fromRGB(60, 30, 80),
		atmosphere = { Density = 0.34, Offset = 0.12, Haze = 1.4, Glare = 0, Color = Color3.fromRGB(86, 66, 132), Decay = Color3.fromRGB(122, 70, 150) },
	}, 0)
	Film.grade({ Brightness = 0, Contrast = 0.18, Saturation = 0, TintColor = Color3.fromRGB(222, 218, 255) }, 0)
	Film.vignette(0.5, 0)
	Film.glow(0.45, 22, 0)
end

-------------------------------------------------------------------------------------------------------------
-- (round 2, owner 5 Nov: "i didnt like how the boss spawned", "doe iets inspired by jjk en de refrence videos")
-- THE SUMMONING: the ground under the cracked sky goes black, pixel by pixel, into a pool of nothing; a pink loading
-- ring draws itself round it, its eight pixels lighting in turn; on 100% a giant hand bursts up out of the black
-- and slams down on the edge; eyes open in the dark; it hauls itself out and roars, and the ring shatters. (A
-- shadow summoning in a ritual circle, as jujutsu anime do it; the ring is the demon's own sign, the loading ring
-- that spins over its head when it adapts.)
-------------------------------------------------------------------------------------------------------------
local POOL_R = 17 -- studs: the black pool round where it comes up
local RING_R = 21 -- the loading ring round the pool
local summon: any = nil -- { tiles, segs, dots, light }

-- (Studio, for whoever tunes the film: a workspace attribute Tune_<name> = a number overrides a value while it plays)
local function tune(name: string, default: number): number
	if RunService:IsStudio() then
		local v = workspace:GetAttribute("Tune_" .. name)
		if type(v) == "number" then
			return v
		end
	end
	return default
end

-- (round 2) the tall grass where the fight happens is trampled flat: from the low angles it hid the hits, the hand on
-- the ground, the landings (the pool's own grass goes into the black as it spreads)
local function clearArena()
	local spots = { { DEMON_AT, 31 }, { R1, 9 }, { R2, 9 }, { R3, 9 }, { P1, 10 }, { SHED + Vector3.new(8, 0, 0), 8 } }
	for _, t in S.tufts do
		local q = t.at.Position
		local here = Vector3.new(q.X, 0, q.Z) - Vector3.new(S.at.Position.X, 0, S.at.Position.Z)
		local inPool = (here - Vector3.new(DEMON_AT.X, 0, DEMON_AT.Z)).Magnitude < POOL_R + 1.5
		local hide = false
		for _, sp in spots do
			if (here - Vector3.new(sp[1].X, 0, sp[1].Z)).Magnitude < sp[2] then
				hide = true
				break
			end
		end
		if hide and not inPool then
			for _, part in t.parts or { t.part } do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
		end
	end
end

local function buildSummon()
	local rng = Random.new(404)
	local tiles = {}
	local step = 2
	for x = -POOL_R, POOL_R, step do
		for z = -POOL_R, POOL_R, step do
			local d = math.sqrt(x * x + z * z)
			if d <= POOL_R - 0.6 + rng:NextNumber(-1.2, 1.2) then
				local p = neon(Vector3.new(step + 0.04, 0.1, step + 0.04), W(DEMON_AT.X + x, 0.2, DEMON_AT.Z + z), BLACK, 1)
				p.Name = "Void"
				table.insert(tiles, { part = p, d = math.max(d + rng:NextNumber(-2.5, 2.5), 0) })
			end
		end
	end
	local segs = {}
	local n = 56
	for i = 0, n - 1 do
		local a0, a1 = (i / n) * math.pi * 2, ((i + 1) / n) * math.pi * 2
		local p0 = Vector3.new(math.sin(a0) * RING_R, 0, math.cos(a0) * RING_R)
		local p1 = Vector3.new(math.sin(a1) * RING_R, 0, math.cos(a1) * RING_R)
		local mid = DEMON_AT + (p0 + p1) / 2
		local cf = CFrame.lookAt(at(mid, 0.25), at(DEMON_AT + p1, 0.25))
		table.insert(segs, neon(Vector3.new(0.5, 0.12, (p1 - p0).Magnitude + 0.12), cf, PINK, 1))
	end
	local dots = {}
	for j = 0, 7 do
		-- (from the front, going round: the first lights nearest the lens of the top shot's "12 o'clock")
		local a = math.pi + j / 8 * math.pi * 2
		local p = neon(Vector3.new(0.3, 3.4, 3.4), W(DEMON_AT.X + math.sin(a) * RING_R, 0.3, DEMON_AT.Z + math.cos(a) * RING_R) * CFrame.Angles(0, 0, math.rad(90)), PINK, 1)
		p.Shape = Enum.PartType.Cylinder
		p.Name = "LoadPixel"
		table.insert(dots, p)
	end
	local holder = neon(Vector3.one * 0.2, W(DEMON_AT.X, 6, DEMON_AT.Z), PINK, 1)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(235, 110, 255)
	light.Range = 46
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	-- (the tall grass inside it goes into the black as it spreads)
	local swallow = {}
	for _, t in S.tufts do
		local q = t.at.Position
		local d = (Vector3.new(q.X, 0, q.Z) - Vector3.new(at(DEMON_AT, 0).X, 0, at(DEMON_AT, 0).Z)).Magnitude
		if d < POOL_R + 1.5 then
			table.insert(swallow, { tuft = t, d = d })
		end
	end
	summon = { tiles = tiles, segs = segs, dots = dots, light = light, lit = 0, swallow = swallow }
	-- (the old fissure's broken rocks go under the ground: the pool comes up out of flat ground)
	for _, r in S.rim do
		r.part.CFrame = r.cf - Vector3.new(0, 9, 0)
	end
end

-- the pool spreading (k 0..1), the ring drawing itself round (k2 0..1)
local function stepSummon(k: number, k2: number)
	if not summon then
		return
	end
	local reach = k * (POOL_R + 3)
	for _, t in summon.tiles do
		local want = if t.d <= reach then 0 else 1
		if t.part.Transparency ~= want then
			t.part.Transparency = want
		end
	end
	for _, w in summon.swallow do
		if not w.gone and w.d <= reach then
			w.gone = true
			for _, part in w.tuft.parts or { w.tuft.part } do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
		end
	end
	local nSeg = #summon.segs
	for i, s in summon.segs do
		local want = if i / nSeg <= k2 then 0.15 else 1
		if s.Transparency ~= want then
			s.Transparency = want
		end
	end
	local lit = math.clamp(math.floor(k2 * 8 + 0.001), 0, 8)
	while summon.lit < lit do
		summon.lit += 1
		local dot = summon.dots[summon.lit]
		dot.Transparency = 0
		sfx("chip", 0.9, 0.85 + summon.lit * 0.07)
	end
	summon.light.Brightness = 0.3 + k2 * 1.4
end

-- the ring breaks: its pixels and line fly out and fade (the roar's blast)
local function breakSummon()
	if not summon then
		return
	end
	local c = at(DEMON_AT, 0)
	for _, p in summon.dots do
		local out = (p.Position - c) * Vector3.new(1, 0, 1)
		out = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
		TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = p.CFrame + out * 16 + Vector3.new(0, 7, 0),
			Transparency = 1,
		}):Play()
	end
	for _, s in summon.segs do
		local out = (s.Position - c) * Vector3.new(1, 0, 1)
		out = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
		TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = s.CFrame + out * 10 + Vector3.new(0, 3, 0),
			Transparency = 1,
		}):Play()
	end
	TweenService:Create(summon.light, TweenInfo.new(1.2), { Brightness = 0.6 }):Play()
end

local function actI(): boolean
	night()
	clearArena()
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
	-- 3. [SR 2.0, straight down at the ground, a slow push in] THE POOL: the ground goes black pixel by pixel, a pink
	-- loading ring draws itself round it, its eight pixels lighting one by one; the world drains of colour
	buildSummon()
	Film.grade({ Brightness = 0, Contrast = 0.26, Saturation = -0.5, TintColor = Color3.fromRGB(214, 206, 255) }, 0.8)
	sfx("rumble", 1.0)
	sfx("suck", 0.8, 0.6)
	FilmAudio.glitch(0.4)
	local poolFrom, poolLen = T.split, 0.95
	local ringFrom, ringLen = T.split + 0.12, 1.08
	tracks.summon = function()
		local tt = now()
		stepSummon(ease.out(math.clamp((tt - poolFrom) / poolLen, 0, 1)), math.clamp((tt - ringFrom) / ringLen, 0, 1))
		if tt >= T.rise then
			tracks.summon = nil
		end
	end
	after(T.rise - 0.2, function()
		sfx("zapCharge", 0.9, 1.5)
		for _, p in summon.dots do
			p.Color = WHITE
		end
	end)
	clearR = 4
	if not shot(T.rise, function(k)
		local c = at(DEMON_AT, 0)
		local e = ease.inOut(k)
		local p = c + Vector3.new(0, tune("TopUp", 96) - e * 18, 8 - e * 2)
		return look(p, c + Vector3.new(0, 0, 1.5), 18 * e), mm(tune("TopMM", 30)), c
	end, { hand = 0.25 }) then
		return false
	end
	-- 4. [SR 9.5: something big comes up into the frame] ON 100%: A HAND bursts up out of the black and slams down on
	-- the pool's edge, close in front of the lens
	for _, p in summon.dots do
		p.Color = PINK
	end
	local P = demonPose[D]
	-- (the body stays deep under the black while the arm, lifted up out of it on its own, bursts up and comes down on
	-- the edge; then the body climbs up to it, the hand planted, as if it hauls itself out by it)
	local slamAt = T.rise + tune("SlamDelay", 0.3)
	local shootLen = 0.13
	tracks.demonRise = function()
		local tt = now()
		if not D or tt > T.roar + 2 then
			tracks.demonRise = nil
			return
		end
		local hidden, r1 = tune("RiseHidden", 0), tune("RiseHead", 0.52)
		local rise
		if tt < T.eyes then
			rise = hidden
		elseif tt < T.roar then
			rise = hidden + (r1 - hidden) * ease.out(math.clamp((tt - T.eyes) / 0.3, 0, 1))
		else
			rise = r1 + (1 - r1) * ease.out(math.clamp((tt - T.roar) / 0.55, 0, 1))
		end
		D.state.rise = rise
		D.state.eyes = ease.out(math.clamp((tt - (T.eyes + 0.1)) / 0.12, 0, 1))
		D.state.roar = math.clamp((tt - T.roar - 0.12) / 0.25, 0, 1) * (1 - math.clamp((tt - T.roar - 1.2) / 0.6, 0, 1) * 0.8)
		-- the arm: shot up out of the black, then down onto the edge; held there while the body comes up to it
		local shoot = ease.out(math.clamp((tt - T.rise) / shootLen, 0, 1))
		local slam = ease.inn(math.clamp((tt - (T.rise + shootLen)) / (slamAt - T.rise - shootLen), 0, 1))
		local free = ease.inOut(math.clamp((tt - T.roar) / 0.4, 0, 1))
		local lift = math.max(tune("ArmLift", 41) * shoot - (rise - hidden) * D.height * 1.05, 0)
		local pitch = tune("ArmUp", -172) * (1 - slam) + tune("HandPitch", -100) * slam
		if tt < T.rise then
			pitch = 30
		end
		P.armR = { pitch = pitch * (1 - free), yaw = tune("HandYaw", 8) * (1 - free) }
		P.cutM = if lift > 0.01 and free < 1 then CFrame.new(0, lift * (1 - free), 0) else nil
		P.lean = tune("Lean", 10) * (1 - free)
	end
	sfx("impact", 1.3)
	sfx("riseDark", 1.0)
	sfx("boom", 0.9, 0.6)
	Film.shake(0.6, 0.9)
	Film.flash(WHITE, 0.5, 0.18)
	pcall(FilmVfx.play, "DemonRise", at(DEMON_AT, 0), { scale = 1.4 })
	after(slamAt, function()
		sfx("slam", 1.4, 0.6)
		sfx("thud", 1.2, 0.6)
		Film.shake(0.9, 1.3)
		local hand = D.frame("foreR").Position
		local spot = Vector3.new(hand.X, at(DEMON_AT, 0).Y + 0.4, hand.Z)
		fx("GroundSlam", spot, { scale = 1.8 })
		fx("Dust", spot, { scale = 2.4 })
		AnimeFx.hit(spot + Vector3.new(0, 2, 0), PINK, 10, true)
		pcall(function()
			AnimeFx.impact(armParts(D, "R"), "neg", { hold = 0.08, at = spot })
		end)
	end)
	clearR = 5
	if not shot(T.eyes, function(k)
		-- (low in front of where the hand comes down, tested in Studio: the hand big on the left, planted on the pool's
		-- edge, the black and the ring behind it)
		local p = V(tune("HandCamX", 2) - k * 1, tune("HandCamY", 3.2), tune("HandCamZ", -8) - k * 1.5)
		return look(p, V(-12, 6.5, -46), -4), mm(tune("HandMM", 30)), V(-12, 3, -44)
	end, { hand = 0.5 }) then
		return false
	end
	-- 5. [SR 31.3: one eye burning in the dark] its head comes up out of the black, close; the eyes snap open
	after(T.eyes + 0.08, function()
		sfx("sting", 0.9)
		sfx("growl2", 0.9, 0.6)
		Film.punch(4)
	end)
	if not shot(T.roar, function(k)
		local e = D.eyes()
		local fwd = flat(D.head().LookVector)
		fwd = if fwd.Magnitude > 0.1 then fwd.Unit else Vector3.zAxis
		local p = e + fwd * (tune("EyeCamDist", 30) - k * 4) + Vector3.new(tune("EyeCamSide", 5), tune("EyeCamUp", -3), 0)
		-- (never under the ground: as its head comes up out of the pool the eyes are only a few studs over it)
		local floor = at(DEMON_AT, 0).Y + 1.6
		if p.Y < floor then
			p = Vector3.new(p.X, floor, p.Z)
		end
		return look(p, e + Vector3.new(0, -1, 0), 4), mm(tune("EyeMM", 38)), e
	end, { hand = 0.35 }) then
		return false
	end
	-- 6. [SR 4.0, wide and low, the whole of it against the sky] it hauls itself out and ROARS: the blast shatters the
	-- ring, the colour comes back
	sfx("roar", 1.4, 0.8)
	sfx("growl", 1.1, 0.7)
	sfx("boom", 1.1, 0.5)
	Film.shake(0.85, 1.0)
	Film.grade({ Brightness = 0, Contrast = 0.18, Saturation = 0, TintColor = Color3.fromRGB(222, 218, 255) }, 0.5)
	after(T.roar + 0.12, function()
		breakSummon()
		pcall(FilmVfx.play, "DemonRoar", D.head() * CFrame.new(0, 0, -6), { scale = 1.3 })
		fx("GroundRing", at(DEMON_AT, 0.5), { scale = 4.0, color = PINK })
		D.glitchNow(0.1)
	end)
	local stopLines = AnimeFx.lines(WHITE, 0.4)
	clearR = 6
	if not shot(T.feet, function(k)
		local c = at(DEMON_AT, 0)
		local e = ease.out(k)
		local p = c + Vector3.new(-18 + e * 2, tune("RoarCamY", 7.5), tune("RoarCamZ", 54) - e * 6)
		return look(p, c + Vector3.new(0, tune("RoarAimY", 21) + e * 3, 0), 2), mm(tune("RoarMM", 21)), c + Vector3.new(0, 22, 0)
	end, { hand = 0.4 }) then
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
	R:show(true)
	walkTrack()
	sfx("bladeDraw", 0.8, 0.7)
	-- 6. [BL, a low tracking shot] beside him at knee height, keeping pace: the gold shears dragging big across the
	-- frame from his hand, his boots, sparks off the tip (from the front, pass 2 saw only his legs)
	clearR = 4
	key(nil)
	if not shot(T.walk, function(_k)
		local root = R.root
		local g = root.Position.Y + R.ground
		local p = root.Position + root.RightVector * 9.5 + root.LookVector * 1.3
		p = Vector3.new(p.X, g + 1.1, p.Z)
		local target = root.Position - root.LookVector * 2.6
		target = Vector3.new(target.X, g + 1.2, target.Z)
		return look(p, target, -1.5), mm(35), target
	end, { hand = 0.4 }) then
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
	AnimeFx.card(Config.FILMS_V2.ownerName, Config.FILMS_V2.ownerTitle, GOLD, 1.5, "主")
	Film.punch(3)
	local moonPos = S.moon.Position
	if not shot(T.clawUp, function(k)
		local chest = chestOf(R).Position + Vector3.new(0, 0.4, 0)
		local dir = (moonPos - chest).Unit
		local p = chest - dir * (30 - k * 2)
		return look(p, chest), mm(85), chest
	end, { hand = 0.15 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the exchange: the claw, three cuts, the arm drops
-------------------------------------------------------------------------------------------------------------
local function exchange(): boolean
	-- (round 2, after the reference's fight, frame by frame: SR 7.1-8.6, one tracking shot that runs WITH the two of
	-- them past the skyscrapers; every shot one clear thing, half a second or more; the old version cut to four
	-- angles in 0.7 s and the owner couldn't tell what happened)
	-- 9. [SR 11.2, a dark shape fills the frame] low behind him: the claw goes up over him... and comes down
	local P = demonPose[D]
	tracks.claw = function()
		local tt = now()
		local up = ease.out(math.clamp((tt - T.clawUp) / 0.35, 0, 1))
		local down = ease.inn(math.clamp((tt - (T.claw - 0.16)) / 0.16, 0, 1))
		-- (round 2: it leans right over and the claw reaches the ground where he stood; it stopped ~15 studs short)
		-- (pitch: + swings it back, - forward; measured in Studio: -28 with a 22 lean and 44 in puts the claw on him)
		P.lean = down * tune("ClawLean", 22)
		P.armR = { pitch = tune("ClawRaise", -110) * up * (1 - down) + tune("ClawPitch", -28) * down, yaw = 6 * up + tune("ClawYaw", 44) * down }
	end
	sfx("growl2", 1.0, 0.8)
	after(T.claw - 0.25, function()
		sfx("whoosh", 1.2, 0.6)
	end)
	if not shot(T.claw - 0.07, function(k)
		local root = R.root
		local claw = D.frame("foreR").Position
		local p = root.Position - root.LookVector * 6.5 + root.RightVector * 3.2 + Vector3.new(0, -2.2, 0)
		return look(p, root.Position:Lerp(claw, 0.5 + k * 0.1) + Vector3.new(0, 2, 0), 6), mm(20), root.Position
	end, { hand = 0.5 }) then
		return false
	end
	-- 10. [SR 9.85, wide: the small figure and where it goes] from the side, wide: the claw slams down where he stood,
	-- and a gold streak shoots up its arm (he's already on it)
	local run = {} -- the arm's top, hand to shoulder, as it lies after the slam (read once it's down)
	local function armPath()
		local fr, ar = D.frame("foreR"), D.frame("armR")
		local elbow, shoulder = fr.Position, ar.Position
		local hand = elbow - fr.UpVector * tune("ForeLen", 15)
		-- (the side he runs on: up, and toward the lens's side, square to the arm; on its steep upper part straight up
		-- put him inside it)
		local lensSide = flat(elbow - at(DEMON_AT, elbow.Y))
		lensSide = if lensSide.Magnitude > 0.1 then lensSide.Unit else Vector3.new(-1, 0, 0)
		local function top(p: Vector3, along: Vector3): Vector3
			local want = UP + lensSide * 0.8
			local n = want - along * want:Dot(along)
			n = if n.Magnitude > 0.05 then n.Unit else UP
			return p + n * tune("ArmTop", 4.4)
		end
		local a1 = (elbow - hand).Unit
		local a2 = (shoulder - elbow).Unit
		local reachUp = tune("RunUp", 0.55)
		run = {
			top(hand:Lerp(elbow, 0.15), a1), top(hand:Lerp(elbow, 0.55), a1), top(elbow, a1:Lerp(a2, 0.5).Unit),
			top(elbow:Lerp(shoulder, reachUp * 0.55), a2), top(elbow:Lerp(shoulder, reachUp), a2),
		}
	end
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
		AnimeFx.hit(at(R1, 2), PINK, 9, true)
		armPath()
		-- the streak: from where he stood up onto the arm
		local a, b = at(R1, 1.5), run[1]
		local mid = (a + b) / 2
		local beam = neon(Vector3.new(0.5, 0.5, (b - a).Magnitude), CFrame.lookAt(mid, b), Color3.fromRGB(255, 226, 140), 0)
		fadeOut(beam, 0.3, Vector3.new(0.05, 0.05, (b - a).Magnitude))
		sfx("lunge", 1.1, 1.2)
	end)
	-- (high behind where he stood, tested in Studio: from the side its own body hid the arm; from here the arm comes
	-- down the frame at us, the dust where he was, and the streak runs up it)
	local wideAim = V(tune("WideAimX", -6), tune("WideAimY", 5), tune("WideAimZ", -38))
	local wideFrom = V(tune("WideX", 6), tune("WideY", 26), tune("WideZ", 2))
	if not shot(T.claw + 0.16, function(k)
		return look(wideFrom + Vector3.new(0, k * 1.2, k * 1.5), wideAim, 0), tune("WideFov", 52), wideAim
	end, { hand = 0.3 }) then
		return false
	end
	-- 11. [SR 7.1-8.6, the camera running with them] he runs UP THE ARM, the camera running beside him; three snips,
	-- three cuts of light across the arm behind him
	if #run == 0 then
		armPath()
	end
	local runFrom, runTo = T.claw + 0.16, T.fall - 0.08
	-- (where along the path he is: the three snips on the beats, at the wrist, the elbow, the upper arm)
	local keys = { { runFrom, 0 }, { T.snip1, 0.24 }, { T.snip2, 0.5 }, { T.snip3, 0.8 }, { runTo, 1 } }
	local function along(tt: number): number
		for i = 1, #keys - 1 do
			local a, b = keys[i], keys[i + 1]
			if tt <= b[1] then
				return a[2] + (b[2] - a[2]) * math.clamp((tt - a[1]) / (b[1] - a[1]), 0, 1)
			end
		end
		return 1
	end
	local function pathAt(s: number): (Vector3, Vector3)
		local n = #run
		local f = math.clamp(s, 0, 1) * (n - 1)
		local i = math.clamp(math.floor(f) + 1, 1, n - 1)
		local p = run[i]:Lerp(run[i + 1], f - (i - 1))
		local dir = (run[i + 1] - run[i])
		return p, if dir.Magnitude > 0.01 then dir.Unit else UP
	end
	R:show(true)
	shearsMode = "two"
	SH:trail(true)
	R:pose("snipOpen", 0)
	local lastGhost = 0
	tracks.run = function()
		local tt = now()
		local p, dir = pathAt(along(tt))
		local flatDir = flat(dir)
		flatDir = if flatDir.Magnitude > 0.05 then flatDir.Unit else Vector3.zAxis
		-- (standing on the arm's top, leaning into the run, facing up it)
		R.root = CFrame.lookAt(p + UP * -R.ground, p + UP * -R.ground + flatDir) * CFrame.Angles(math.rad(-8), 0, 0)
		if tt - lastGhost > 0.045 then
			lastGhost = tt
			R:ghost(Color3.fromRGB(255, 214, 120), 0.6, 0.22)
		end
		if tt >= runTo then
			tracks.run = nil
		end
	end
	local function cutAt(i: number)
		local s = keys[i + 1][2]
		local c, dir = pathAt(s)
		local side = dir:Cross(UP)
		side = if side.Magnitude > 0.05 then side.Unit else Vector3.xAxis
		R:pose("snipShut", 0.07, "snap")
		task.delay(0.12, function()
			if playing and R then
				R:pose("snipOpen", 0.1, "out")
			end
		end)
		local centre = c - UP * tune("CutDepth", 3.4)
		-- (round 2: the reference's flat cuts: a white crescent over a gold one where the blades bite, along the way
		-- their tips close, carried along with the shears, and a hit bursting on the arm. Tested in Studio: he runs so
		-- fast that anything left where he cut is off the frame in a frame or two)
		local function bite(): Vector3
			local ta, tb = SH:tips()
			return SH.pivot.Position:Lerp((ta + tb) / 2, 0.6)
		end
		local ta, tb = SH:tips()
		local b0 = bite()
		if (ta - tb).Magnitude < 0.6 then
			local across = (UP * (if i == 2 then -1 else 1) + side * 0.6).Unit
			ta, tb = b0 + across * 2, b0 - across * 2
		end
		AnimeFx.cut(b0, ta, tb, GOLD, tune("CutSize", 6.5), bite)
		AnimeFx.hit(b0, PINK, tune("CutHit", 4), i == 3)
		fx("CorruptHit", centre, { scale = 1.0 })
		sfx("bladeSlash", 1.2, 0.95 + i * 0.08)
		sfx("slice", 1.0, 0.8 + i * 0.12)
		Film.shake(0.35, 3)
		Film.flash(WHITE, 0.35, 0.08)
		AnimeFx.slash(({ -32, 18, 64 })[i], { y = 0.5, life = 0.08, width = 0.02 })
	end
	after(T.snip1, function()
		cutAt(1)
	end)
	after(T.snip2, function()
		cutAt(2)
	end)
	after(T.snip3, function()
		cutAt(3)
	end)
	local stopLines = AnimeFx.lines(Color3.fromRGB(255, 240, 200), 0.35)
	clearR = 3
	-- (one steady side for the whole run, on the arm's outside, away from its body: the camera runs level with him)
	local runFlat = flat(run[#run] - run[1])
	runFlat = if runFlat.Magnitude > 0.1 then runFlat.Unit else Vector3.new(0, 0, -1)
	local runSide = runFlat:Cross(UP).Unit
	if runSide:Dot(run[1] - at(DEMON_AT, run[1].Y)) < 0 then
		runSide = -runSide
	end
	if not shot(T.fall, function(_k)
		local p = pathAt(along(now()))
		local cp = p + runSide * tune("RunCamSide", 13) + UP * tune("RunCamUp", 1.5) - runFlat * tune("RunCamBack", 5)
		return look(cp, p + runFlat * 4 + UP * 1.2, -4), mm(tune("RunCamMM", 26)), p
	end, { hand = 0.35 }) then
		return false
	end
	stopLines()
	tracks.run = nil
	tracks.claw = nil
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
	-- 13. [SR 16.0, the small figure and the big thing] he drops in off its shoulder and lands low in the foreground,
	-- the arm crashes behind him (round 2: he came down in one piece, not from nowhere)
	local leapFrom = R.root.Position
	local leapT0 = now()
	local landT = leapT0 + 0.3
	local landCf = CFrame.lookAt(at(R2, 0), at(DEMON_AT, 0))
	R:pose("leapOpen", 0.08, "out")
	shearsMode = "two"
	tracks.leap = function()
		local tt = now()
		local k = math.clamp((tt - leapT0) / (landT - leapT0), 0, 1)
		local goal = landCf.Position + UP * (-R.ground)
		local pos = leapFrom:Lerp(goal, ease.inOut(k)) + UP * math.sin(k * math.pi) * 3
		R.root = CFrame.lookAt(pos, pos + landCf.LookVector)
		if k >= 1 then
			tracks.leap = nil
			stand(R, R2, DEMON_AT)
			R:pose("landCut", 0.1, "snap")
			SH:trail(false)
			shearsMode = "out"
			shearsOpen = 12
			sfx("stepThud", 1.2, 0.8)
			fx("DustKick", at(R2, 0.3), { scale = 1.2 })
			Film.shake(0.3, 3)
		end
	end
	-- (from above his right shoulder, tested in Studio: him crouched in the middle, the shears' bolt glowing below,
	-- the arm and the demon's dark bulk behind him)
	if not shot(T.eye, function(k)
		local base = at(R2, 0)
		local p = base + Vector3.new(8 + k * 0.6, 6 + k * 0.4, 7 + k * 0.6)
		return look(p, base + Vector3.new(-6, 2, -5.5), -3), mm(26), at(R2, 2)
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
		-- (his right eye: a bandage covers the left; seen through the strands of his fringe, tested in Studio)
		local hc = headCf(R)
		local e = eyesOf(R, 0.26, 0)
		local p = e + hc.LookVector * (2.0 - k * 0.25) + hc.RightVector * 0.3 - hc.UpVector * 0.12
		return CFrame.lookAt(p, e, hc.UpVector), mm(85), e
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
	bb.StudsOffset = Vector3.new(0, 22.5 * d.scale, 0) -- (over its head and horns, the words between the two)
	bb.LightInfluence = 0
	bb.Adornee = head
	bb.Parent = head
	-- a loading spinner (the glitch thinking): eight rounded dots, a bright one chasing round, a faint ring behind
	local rim = Instance.new("Frame")
	rim.BackgroundTransparency = 1
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.fromScale(0.76, 0.76)
	rim.Parent = bb
	local rimCorner = Instance.new("UICorner")
	rimCorner.CornerRadius = UDim.new(0.5, 0)
	rimCorner.Parent = rim
	local rimStroke = Instance.new("UIStroke")
	rimStroke.Color = PINK
	rimStroke.Thickness = 3
	rimStroke.Transparency = 0.55
	rimStroke.Parent = rim
	local dots = {}
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 - math.pi / 2
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromScale(0.17, 0.17)
		f.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.38, 0.5 + math.sin(a) * 0.38)
		f.BackgroundColor3 = PINK
		f.BackgroundTransparency = 0.5
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = bb
		dots[i] = f
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1.8, 0.2)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.97)
	-- (plain white capitals with a thin outline, like the films' other words; client/TextStyle leaves it alone)
	label:SetAttribute("KeepFont", true)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.2
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
				f.BackgroundTransparency = if dist == 0 then 0 elseif dist == 1 then 0.2 elseif dist == 2 then 0.4 else 0.6
				f.BackgroundColor3 = if dist == 0 then Color3.fromRGB(255, 236, 248) else PINK
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
	-- (low from the south-west past the shed's log wall, tested in Studio: the whole demon against the sky's pink
	-- cracks, the loading ring over its head, the arm flying back in; from close below it read as dark noise)
	if not shot(T.clang, function(k)
		local p = at(Vector3.new(-22 + k * 1.5, 3, 8 - k * 2))
		return look(p, at(Vector3.new(-6, 30 + k * 2, -52)), 2), mm(27), at(Vector3.new(-8, 20, -52))
	end, { hand = 0.4 }) then
		return false
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- CLANG; the backhand; through the shed; down in the wreck
-------------------------------------------------------------------------------------------------------------
local function clang(): boolean
	-- 16. [TSB 6.5, a black-and-white impact frame] the same cut clangs off the arm: sparks, a jolt. He comes down on
	-- top of the forearm (it sticks out sideways from the elbow along its root's -Y, ~15 studs, ~8 thick: placed
	-- beside the elbow he stood inside it)
	local fr = D.frame("foreR")
	local elbow = fr.Position
	local axis = elbow - fr.UpVector * 7
	local p = axis + UP * 6.2
	R.root = CFrame.lookAt(p, Vector3.new(elbow.X, p.Y, elbow.Z))
	R:pose("snipOpen", 0)
	R:pose("jolt", 0.1, "snap")
	R:update(0)
	shearsMode = "two"
	local hit = axis + UP * 3.6
	sfx("bladeClang", 1.4, 0.9)
	sfx("hit", 1.0, 0.6)
	fx("Sparks", hit, { scale = 1.6, color = GOLD })
	fx("Hit", hit, { scale = 1.0 })
	AnimeFx.hit(hit, GOLD, 6, true)
	task.delay(0.03, function()
		AnimeFx.impact({ R.model, SH.model, table.unpack(armParts(D, "R")) }, "neg", { hold = 0.1, at = hit })
	end)
	Film.shake(0.5, 2.5)
	-- (from low in front of the arm, tested in Studio: him over it against the sky's cracks, the arm's dark bulk
	-- under him)
	if not shot(T.back, function(k)
		local cp = axis + Vector3.new(-9 - k * 0.5, 1, 11 + k * 0.5)
		return look(cp, axis + UP * 5, -6), mm(28), p
	end, { hand = 0.3 }) then
		return false
	end
	-- 17. [SR 20.35-21.35: the hit at the lens] (round 2) from behind him, looking up at its face: it glares, the arm
	-- he's standing on WHIPS and throws him (its other hand can't reach that far round: measured in Studio), straight
	-- at the lens
	local P = demonPose[D]
	local hitT = T.back + 0.3
	tracks.backhand = function()
		local tt = now()
		local whip = ease.out(math.clamp((tt - (hitT - 0.07)) / 0.13, 0, 1))
		local settle = ease.inOut(math.clamp((tt - hitT - 0.15) / 0.5, 0, 1))
		P.armR = { pitch = tune("WhipPitch", -38) * whip * (1 - settle * 0.6), yaw = tune("WhipYaw", -30) * whip * (1 - settle * 0.6) }
		P.lean = 7 * whip
	end
	sfx("whoosh", 1.3, 0.45)
	local flyFrom = p
	local flyTo = at(SHED + Vector3.new(-2, 2, -1))
	local flyDir = (flyTo - flyFrom).Unit
	after(hitT, function()
		AnimeFx.impact({ R.model, SH.model, table.unpack(armParts(D, "R")) }, "red", { hold = 0.12, at = flyFrom })
		sfx("punch", 1.3, 0.7)
		sfx("bigHit", 0.9, 0.9)
		Film.shake(0.9, 1.6)
		Film.flash(WHITE, 0.6, 0.12)
		AnimeFx.hit(flyFrom + UP, WHITE, 7, true)
		R:pose("flung", 0.06, "snap")
		R:shake(1)
		shearsMode = "out"
	end)
	-- (behind him, low, on the side away from it: the hand comes in from the right of the frame at him)
	local away = -flyDir
	if not shot(hitT, function(k)
		local cp = flyFrom - flyDir * tune("SwatCamBack", -9) + UP * tune("SwatCamUp", 0.5) + flyDir:Cross(UP).Unit * tune("SwatCamSide", 3)
		local aim = flyFrom:Lerp(D.eyes(), 0.35) + UP * k
		return look(cp, aim, 4), mm(tune("SwatMM", 22)), flyFrom
	end, { hand = 0.4 }) then
		return false
	end
	-- 17b. [SR 22.6-23.6: the camera flies with him past the buildings] he flies, the camera flying beside him, the
	-- shed coming up behind him
	tracks.fly = function()
		local tt = now()
		if tt < hitT then
			return
		end
		local k = math.clamp((tt - hitT) / (T.shed - hitT), 0, 1)
		local q = flyFrom:Lerp(flyTo, k) + UP * math.sin(k * math.pi) * 3
		R.root = CFrame.lookAt(q, q - flyDir) * CFrame.Angles(0, 0, math.rad(k * 220))
		if os.clock() - (R.lastGhost or 0) > 0.06 then
			R.lastGhost = os.clock()
			R:ghost(Color3.fromRGB(255, 220, 160), 0.78, 0.2)
		end
	end
	local flySide = flyDir:Cross(UP).Unit
	if flySide:Dot(Vector3.zAxis) < 0 then
		flySide = -flySide
	end
	local stopFly = AnimeFx.lines(WHITE, 0.4)
	if not shot(T.shed - 0.12, function(_k)
		local q = R.root.Position
		local cp = q + flySide * tune("FlyCamSide", 12) + UP * 2.6 - flyDir * tune("FlyCamBack", 5)
		return look(cp, q + flyDir * 4, -5), mm(26), q
	end, { hand = 0.5 }) then
		return false
	end
	stopFly()
	tracks.backhand = nil
	P.armR, P.lean = nil, 0
	return true
end

-- a flash of light that fades (a crash, a hit): lights up what's round it for a moment
local function burst(pos: Vector3, color: Color3, brightness: number, range: number, life: number)
	local holder = Instance.new("Part")
	holder.Name = "Burst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
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

-- a brick lying flat on the ground at `at` (its thinnest side down), turned `yaw`
local function restOn(p: BasePart, at: Vector3, yaw: number): CFrame
	local s = p.Size
	local turn = if s.X <= s.Y and s.X <= s.Z then CFrame.Angles(0, 0, math.rad(90)) elseif s.Z <= s.Y then CFrame.Angles(math.rad(90), 0, 0) else CFrame.identity
	local half = math.min(s.X, s.Y, s.Z) / 2
	return CFrame.new(at.X, S.at.Position.Y + half, at.Z) * CFrame.Angles(0, yaw, 0) * turn
end

-- the shed's bricks fly apart, away from where he came in, and come down round the wreck (left in the air, they
-- hung over every shot after)
local debris: { { part: BasePart, rest: CFrame } } = {}
local function blowShed(from: Vector3)
	local shedModel = S.shed
	if not shedModel then
		return
	end
	local rng = Random.new(7)
	table.clear(debris)
	for _, p in shedModel:GetDescendants() do
		if p:IsA("BasePart") then
			local out = (p.Position - from)
			out = Vector3.new(out.X, 0, out.Z)
			local dir = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
			local dist = rng:NextNumber(4, 16)
			local up = (p.CFrame + dir * dist * 0.55 + Vector3.new(0, rng:NextNumber(2, 7), 0)) * CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2))
			local rest = restOn(p, p.Position + dir * dist, rng:NextNumber(0, math.pi * 2))
			table.insert(debris, { part = p, rest = rest })
			-- (a brick between a lens and its subject is hidden like any prop)
			if S.props then
				table.insert(S.props, { parts = { p }, follow = p, center = p.Position, radius = p.Size.Magnitude / 2, hidden = false })
			end
			local t1 = rng:NextNumber(0.35, 0.55)
			TweenService:Create(p, TweenInfo.new(t1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = up }):Play()
			task.delay(t1, function()
				if p.Parent then
					TweenService:Create(p, TweenInfo.new(rng:NextNumber(0.3, 0.45), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = rest }):Play()
				end
			end)
		end
	end
end

-- (the ultimate) the wreck's bricks near him lift off the ground and hang, turning slowly; dropDebris lets go
local lifted: { { part: BasePart, rest: CFrame } } = {}
local function liftDebris(center: Vector3, radius: number, time: number)
	local rng = Random.new(11)
	table.clear(lifted)
	for _, d in debris do
		local p = d.part
		if p.Parent and (flat(p.Position) - flat(center)).Magnitude < radius and p.Size.Magnitude < 12 then
			table.insert(lifted, d)
			local goal = (d.rest + Vector3.new(0, rng:NextNumber(1.5, 5), 0)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5))
			TweenService:Create(p, TweenInfo.new(time * rng:NextNumber(0.7, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = goal }):Play()
		end
	end
end
local function dropDebris()
	for _, d in lifted do
		if d.part.Parent then
			TweenService:Create(d.part, TweenInfo.new(0.35 + math.random() * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = d.rest }):Play()
		end
	end
	table.clear(lifted)
end

local function shed(): boolean
	-- 18. [SR 16.0, wide] through the shed: the bricks blow out, dust
	local hitAt = at(SHED + Vector3.new(6, 2, 0))
	after(T.shed - 0.1, function()
		blowShed(hitAt)
		burst(hitAt + Vector3.new(0, 2, 0), Color3.fromRGB(255, 196, 140), 7, 36, 0.7)
		sfx("crate", 1.3, 0.8)
		sfx("crate2", 1.2, 0.6)
		sfx("thud", 1.3, 0.6)
		sfx("slam", 1.0, 0.7)
		Film.shake(0.7, 1.4)
		Film.flash(Color3.fromRGB(255, 226, 190), 0.45, 0.14)
		-- (the dust a beat later, small and behind the shed: the pack's dust cloud is a solid mesh that, big and in
		-- front, filled the frame like a dark rock)
		task.delay(0.18, function()
			fx("Dust", at(SHED + Vector3.new(-7, 0, -4), 1), { scale = 0.9 })
		end)
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
	-- (broken planks lying round him: the shed's own bricks flew out away from him)
	local rngW = Random.new(3)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + rngW:NextNumber(-0.3, 0.3)
		local r = rngW:NextNumber(2.2, 4.5)
		local size = Vector3.new(rngW:NextNumber(0.6, 1.1), rngW:NextNumber(0.25, 0.4), rngW:NextNumber(2.5, 5))
		local pos = at(SHED + Vector3.new(-1 + math.cos(a) * r, 0, 2 + math.sin(a) * r))
		local tilt = CFrame.Angles(rngW:NextNumber(-0.25, 0.25), 0, rngW:NextNumber(-0.2, 0.2))
		FilmSet.block(stageFolder(), size, CFrame.new(pos + Vector3.new(0, size.Y / 2 + 0.05, 0)) * CFrame.Angles(0, rngW:NextNumber(0, 6.28), 0) * tilt, Color3.fromRGB(122, 86, 58):Lerp(Color3.fromRGB(70, 48, 34), rngW:NextNumber()), Enum.Material.WoodPlanks, "Plank")
	end
	fx("Dust", at(SHED + Vector3.new(-1, 0, 2), 1), { scale = 2 })
	if not shot(T.up, function(k)
		-- (centred between his chest and his head: on his hips, pass 2 cut his head off)
		local c = chestOf(R).Position:Lerp(headOf(R), 0.35)
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
		-- (a little more from his right: the figure on his chest stood in front of his face straight on)
		local cp = root.Position + root.LookVector * 6.0 + root.RightVector * 2.9 + Vector3.new(0, -1.3 + k * 0.3, 0)
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
	-- (the wreck's bricks round him lift and hang while he gathers it; they drop when the cut lands)
	liftDebris(at(R3, 0), 22, 2.6)
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
	-- 23. [SR 2.2, from straight above] (6 Nov, owner: "the fx of the snip ult like the golden circle feels low
	-- quality ... take inspiration of jjk": it was 72 gold dashes drawing a circle) HIS DOMAIN: from his feet the ground
	-- goes ink-black in one rush out to the ring, a razor-thin white edge riding its front; as it closes, a
	-- black-and-white impact frame, and a storm of hairline cuts flicks across the black floor (a cursed technique's
	-- slashes before the one that matters); the edge cools to gold and hums. The camera turns slowly overhead.
	local ring = {}
	local centre = at(R3, 0.12)
	local floor = Instance.new("Part")
	floor.Name = "DomainFloor"
	floor.Anchored = true
	floor.CanCollide = false
	floor.CanQuery = false
	floor.CanTouch = false
	floor.CastShadow = false
	floor.Shape = Enum.PartType.Cylinder
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(6, 4, 10)
	floor.Size = Vector3.new(0.12, 0.1, 0.1)
	floor.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
	floor.Parent = stageFolder()
	table.insert(ring, floor)
	-- the edge: one thin continuous ring of short segments (white-hot while it runs, gold once it's out)
	local n = 120
	local edge = {}
	for i = 1, n do
		local seg = neon(Vector3.new(0.5, 0.18, 0.32), CFrame.new(centre), WHITE, 1)
		edge[i] = seg
		table.insert(ring, seg)
	end
	local function placeEdge(r: number, alpha: number, color: Color3)
		local len = r * 2 * math.pi / n + 0.12
		for i, seg in edge do
			local a = (i / n) * math.pi * 2
			local p = centre + Vector3.new(math.cos(a) * r, 0.06, math.sin(a) * r)
			seg.Size = Vector3.new(len, 0.18, 0.32)
			seg.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a)))
			seg.Transparency = alpha
			seg.Color = color
		end
	end
	local ringFrom = now()
	local SPREAD = 0.34 -- seconds from his feet to the ring
	tracks.ring = function()
		local k = math.clamp((now() - ringFrom) / SPREAD, 0, 1)
		local r = math.max(RING * (1 - (1 - k) ^ 4), 0.2) -- (expo out: a rush, then it brakes at the rim)
		floor.Size = Vector3.new(0.12, r * 2, r * 2)
		local cool = math.clamp((now() - ringFrom - SPREAD) / 0.5, 0, 1)
		local hum = 0.12 + math.sin((now() - ringFrom) * 18) * 0.06 * cool
		placeEdge(r, hum, WHITE:Lerp(GOLD, cool))
	end
	sfx("suck", 1.1, 0.6)
	sfx("swell", 0.9, 0.8)
	-- it closes: the impact frame, the hum, the storm of cuts
	after(ringFrom + SPREAD, function()
		sfx("titleHit", 1.0, 0.75)
		sfx("bladeClang", 0.8, 1.6)
		Film.shake(0.25, 3)
		AnimeFx.impact({ R.model, SH.model }, "neg", { hold = 0.09, at = at(R3, 2) })
		local rng = Random.new(23)
		for i = 1, 26 do
			task.delay(0.05 + i * 0.011, function()
				if not floor.Parent then
					return
				end
				local a = rng:NextNumber(0, math.pi * 2)
				local r0 = rng:NextNumber(4, RING * 0.55)
				local p = centre + Vector3.new(math.cos(a) * r0, 0.08, math.sin(a) * r0)
				local dir = Vector3.new(math.cos(a + rng:NextNumber(0.9, 2.2)), 0, math.sin(a + rng:NextNumber(0.9, 2.2))).Unit
				local len = rng:NextNumber(10, 30)
				local cut = neon(Vector3.new(0.14, 0.06, len), CFrame.lookAt(p, p + dir), WHITE, 0)
				table.insert(ring, cut)
				TweenService:Create(cut, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Color = GOLD, Transparency = 0.45 }):Play()
				if i % 6 == 0 then
					sfx("swipe", 0.35, rng:NextNumber(1.4, 1.9))
				end
			end)
		end
	end)
	if not shot(T.glint, function(k)
		local c = at(R3 + Vector3.new(10, 0, -16))
		local cp = c + Vector3.new(0, 150 - k * 16, 0.01)
		local turn = math.rad(-8 + k * 16) -- (a slow turn overhead)
		return CFrame.lookAt(cp, c, Vector3.new(math.sin(turn), 0, -math.cos(turn))), mm(30), c
	end) then
		return false
	end
	-- 24. [TSB 28.5, the technique's title card] the edge glints; the technique's name
	local a = SH:tips()
	fx("Glint", a:Lerp(SH.pivot.Position, 0.4), { scale = 1.2 })
	sfx("chip", 0.8, 2)
	AnimeFx.technique("ONE SNIP", "the Owner's ultimate", GOLD, 0.62, "断")
	if not shot(T.ult, function(_k)
		-- (framed on the blades where they are each frame, from the side away from his body: aimed at where the tips
		-- were when the shot began, pass 2 saw only the ground)
		local ta, tb = SH:tips()
		local piv = SH.pivot.Position
		local mid = (ta + tb) / 2
		local along = mid - piv
		along = if along.Magnitude > 0.1 then along.Unit else R.root.LookVector
		local side = along:Cross(UP)
		side = if side.Magnitude > 0.1 then side.Unit else R.root.RightVector
		local target = piv:Lerp(mid, 0.3)
		local root = R.root.Position
		if (target + side * 3 - root).Magnitude < (target - side * 3 - root).Magnitude then
			side = -side
		end
		-- (tested in Studio: the open blades white-hot in his hands, his arm on the left; closer, the glow was all
		-- there was)
		local cp = target + side * 7 + UP * 2.0 - along * 3.5
		return look(cp, target + UP * 0.6, -6), mm(39), target
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
	do
		local mid = at(R3, CUT_Y + 1)
		local cam = workspace.CurrentCamera
		local right = if cam then flat(cam.CFrame.RightVector) else Vector3.xAxis
		right = if right.Magnitude > 0.1 then right.Unit else Vector3.xAxis
		-- (the crescent over the whiteout, its middle ink, after the white comes up)
		task.defer(function()
			AnimeFx.cutScreen(mid + Vector3.new(0, 2, 0), mid - right * 30, mid + right * 30, GOLD, Color3.fromRGB(26, 16, 30))
		end)
	end
	AnimeFx.smear(-4, 1)
	AnimeFx.cover(WHITE, 0, 0, "white")
	AnimeFx.slash(0, { y = 0.5, life = 0.2, width = 0.025 })
	-- (6 Nov, owner: "take inspiration of jjk") over the white, ink hairline cuts snap across the frame one after
	-- another at every angle, like a cutting technique's slashes in a negative frame
	do
		local rng = Random.new(25)
		for i = 1, 9 do
			task.delay(0.025 + i * 0.022, function()
				AnimeFx.slash(rng:NextNumber(-70, 70), {
					x = rng:NextNumber(0.2, 0.8),
					y = rng:NextNumber(0.2, 0.8),
					life = 0.22,
					width = rng:NextNumber(0.006, 0.014),
					color = Color3.fromRGB(14, 8, 18),
				})
			end)
		end
	end
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
		local disc = S.disc
		task.delay(0.5, function()
			fadeOut(disc, 0.5)
		end)
	end
	dropDebris()
	local cut = S.mow(at(R3, 0), RING) -- (the tufts' places are world positions: given R3 itself, nothing was cut)
	for i = 1, math.min(#cut, 30) do
		local p = cut[math.random(1, #cut)]
		fx(if i % 2 == 0 then "GrassTuft" else "GrassStreak", p + Vector3.new(0, 1.5, 0), { scale = 0.9, color = Color3.fromRGB(110, 190, 70) })
	end
	sfx("bladeHit", 1.2, 0.8)
	sfx("rustle", 1.4, 0.8)
	sfx("brush", 1.2, 0.9)
	D.split(WAIST_Y / SCALE)
	-- the cut face: a glowing slab left on its legs where it was cut, seen as the top slides off (in the dark, without
	-- it the slide read as the whole thing just leaning)
	local cutFace = neon(Vector3.new(19, 0.3, 15), D.frame("body") * CFrame.new(0, WAIST_Y, 1.3), Color3.fromRGB(255, 150, 226), 0.05)
	burst(cutFace.Position + Vector3.new(0, 3, 0), PINK, 5, 44, 1.6)
	task.delay(2.6, function()
		fadeOut(cutFace, 0.5)
	end)
	local P = demonPose[D]
	local slideFrom = now()
	local pivot = at(DEMON_AT, WAIST_Y)
	tracks.split = function()
		local k = math.clamp((now() - slideFrom) / 1.25, 0, 1)
		local e = ease.inn(k)
		local away = (at(DEMON_AT, 0) - at(R3, 0)).Unit
		local tip = CFrame.fromAxisAngle(UP:Cross(away).Unit, math.rad(62 * e))
		P.top = CFrame.new(away * (2 + 10 * e) + Vector3.new(0, -WAIST_Y * 0.8 * e, 0)) * about(pivot + away * 8, tip)
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
	-- 27a. [SR 7.2, scale] wide and low, square to the way it slides (from the east): the top half slides off its
	-- waist and falls
	if not shot(T.stubs, function(k)
		local p = at(Vector3.new(44 - k * 2, 4, -34))
		return look(p, at(DEMON_AT + Vector3.new(0, 0, -2), 13 - k * 4)), mm(23), at(DEMON_AT, 10)
	end, { hand = 0.5 }) then
		return false
	end
	-- 28. low in the stubble, clippings still in the air, Rayan beyond, still in his follow-through
	-- (further back than at first, tested in Studio: all of him in the follow-through, the blade's edge glowing)
	if not shot(T.regrow, function(k)
		local p = at(R3 + Vector3.new(5.5, 0.6, 12.5 - k))
		return look(p, at(R3 + Vector3.new(-0.5, 0, -0.5), 2.6)), mm(33), at(R3, 2)
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
	-- (from further behind him, tested in Studio: all of him small against the new one taking shape; from close his
	-- back filled the frame)
	if not shot(T.bigger, function(k)
		local root = R.root
		local p = root.Position - root.LookVector * 10 + root.RightVector * 4.5 + Vector3.new(0, -2.3, 0)
		return look(p, at(BIG_AT, 13 + k * 8), 4), mm(20), at(BIG_AT, 12)
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
	-- 31. [SR 11.2, dark shapes over a lit face] his face turned up to us, seen from where the fists are coming
	-- (from low in front, the figure on his chest and his raised arm hid it); their shadow swallows the frame
	after(T.slam - 0.35, function()
		AnimeFx.cover(BLACK, 0.05, 0.33, "shadow")
	end)
	if not shot(T.slam, function(k)
		local h = headOf(R)
		local root = R.root
		local cp = h + Vector3.new(0, 3.2 - k * 0.5, 0) + root.LookVector * 1.3 + root.RightVector * 0.5
		key(h + Vector3.new(0, 2, 0) + root.LookVector * 1, PINK, 1.6, 8)
		return look(cp, h, 4), mm(33), h
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
	AnimeFx.cover(BLACK, 1, 0, "shadow")
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
		-- (wide and low in front, tested in Studio: them in the crater low in the frame, the giant fist over them in the
		-- corner; aimed higher, the frame was empty sky)
		local cp = root.Position + root.LookVector * 6 + root.RightVector * 3.5 + Vector3.new(0, -2.0, 0)
		return look(cp, root.Position + Vector3.new(0, 1.6 + k * 0.6, 0), -4), mm(19), root.Position
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
		local hc = headCf(H)
		local e = eyesOf(H, 0)
		local p = e + hc.LookVector * (2.3 - k * 0.3) + hc.UpVector * 0.03
		key(e + hc.LookVector * 1.4 + hc.UpVector * 0.8, Color3.fromRGB(255, 220, 150), 2, 6)
		return CFrame.lookAt(p, e, hc.UpVector), mm(85), e
	end, { hand = 0.12 }) then
		return false
	end
	-- 36. [SR 16.0, the small figure and the big thing] up out of the crouch, the fist goes back, gold gathers on it,
	-- and the giant fists come down at him: from low at his side, wide (close in, the blocky arms read as nothing)
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
		-- (round 2: closer, him big on the left, the fists coming down ahead of him: wide, the two of them were specks
		-- under a mass of blocks)
		-- (low behind the two of them, tested in Studio: them small at the bottom, the giant and its fists over them)
		local cp = root.Position + root.RightVector * tune("WindCamSide", 1) - root.LookVector * (tune("WindCamBack", 12.5) - k * 1.5)
		cp = Vector3.new(cp.X, at(P1, 0).Y + tune("WindCamUp", 2.2), cp.Z)
		key(h + root.LookVector * 2.5, GOLD, 1.8, 8)
		return look(cp, root.Position + root.LookVector * 4 + Vector3.new(0, tune("WindAimUp", 3.2) + k * 1.5, 0), 2), tune("WindFov", 64), h
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
	-- (the hit bursts as the strobe's impact frames end: under them it was never seen)
	after(T.punch + 0.27, function()
		AnimeFx.hit(fist, GOLD, 12, true)
	end)
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
	-- (tested in Studio: the fist big in the middle, his face over it, lit gold; the giant fists it meets, right at
	-- the lens, are hidden by the near clip)
	if not shot(T.shatter, function(k)
		local root = H.root
		local f = H:grip("Right").Position
		-- (round 2: from the side, the whole of him, the arm straight into the fist; right at the fist it was a wall of
		-- his own shoulder and hair)
		local cp = root.Position + root.RightVector * tune("PunchCamSide", 17) - root.LookVector * (3 - k) + Vector3.new(0, tune("PunchCamUp", 2.5), 0)
		key(f + root.LookVector * 1.2, GOLD, 3, 8)
		return look(cp, root.Position + root.LookVector * 5 + Vector3.new(0, 4 + k * 0.8, 0), -6), mm(tune("PunchMM", 20)), f
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
		-- (light from where it burst, over everything round it: dark, the shards read as specks)
		burst(at(BIG_AT, 18), Color3.fromRGB(255, 120, 220), 9, 140, 1.4)
		sfx("burst", 1.4, 0.6)
		sfx("boom", 1.2, 0.55)
		FilmAudio.glitch(1)
		Film.shake(0.8, 1.2)
		fx("PinkBurst", at(BIG_AT, 20), { scale = 3 })
		fx("CorruptOrb", at(BIG_AT, 18), { scale = 3 })
	end)
	-- (from behind his right: from behind his left the lens sat on Rayan's head, kneeling there)
	if not shot(T.pillars, function(k)
		local root = H.root
		local p = root.Position - root.LookVector * 3.5 + root.RightVector * 5.5 + Vector3.new(0, -1.5 + k * 1.2, 0)
		return look(p, at(BIG_AT, 18 + k * 14), -3), mm(20), at(BIG_AT, 16)
	end, { hand = 0.5 }) then
		return false
	end
	-- 39. [SR 7.2, far and high] eight pink pillars rise from the eight lands round the valley (beams of neon behind
	-- the hills, where the shards came down; they stay up to the end)
	sfx("sting", 1.1, 0.8)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.3
		local base = at(BIG_AT) + Vector3.new(math.cos(a) * 560, -20, math.sin(a) * 560)
		local height = 900
		local core = neon(Vector3.new(1, 9, 9), CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 214, 240), 0)
		local halo = neon(Vector3.new(1, 30, 30), CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)), PINK, 0.55)
		for _, b in { core, halo } do
			pcall(function()
				b.Shape = Enum.PartType.Cylinder
			end)
			local goal = { Size = Vector3.new(height, b.Size.Y, b.Size.Z), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }
			task.delay(i * 0.09, function()
				if b.Parent then
					TweenService:Create(b, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal):Play()
				end
			end)
		end
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
	-- (over the player's head from higher and wider, tested in Studio: the back of their head on the left, the eye in
	-- the middle, the pink cracks and pillars behind; lower and closer, the shoulder filled the frame)
	if not shot(T.rayan, function(k)
		local p = hd - face * (2.4 + k * 0.3) + H.root.RightVector * 2.1 + Vector3.new(0, 1.0, 0)
		return look(p, home + Vector3.new(0, -0.3, 0)), mm(33), home
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
	-- 41a. the two of them from in front, side by side: Rayan turned to the player, the shears on his shoulder, a
	-- pink pillar between them far off (over his shoulder, his hair filled the frame and the player's face was away)
	clearR = 6
	if not shot(T.free - 0.05, function(k)
		local mid = (R.root.Position + H.root.Position) / 2
		local face = H.root.LookVector
		local cp = mid + face * (7.5 - k * 0.6) + Vector3.new(0, 0.9, 0)
		key(mid + face * 3 + Vector3.new(0, 3, 0), Color3.fromRGB(255, 226, 200), 1.2, 10)
		return look(cp, mid + Vector3.new(0, 1.7, 0)), mm(37), mid + Vector3.new(0, 1.7, 0)
	end, { hand = 0.25 }) then
		return false
	end
	clearR = 4
	-- 41b. the two of them from behind, low, looking out at the pink pillars on the hills: "Free them. Mow it ALL."
	key(nil)
	after(T.free, function()
		R:look(at(P1 + Vector3.new(6, 0, -30), 8), 0.8)
		AnimeFx.sub("Free them. Mow it *ALL*.", 1.6)
	end)
	if not shot(T.title, function(k)
		local mid = (R.root.Position + H.root.Position) / 2
		local face = H.root.LookVector
		local cp = mid - face * (8.5 + k * 0.8) + H.root.RightVector * 0.6 + Vector3.new(0, -2.0, 0)
		return look(cp, mid + face * 40 + Vector3.new(0, 12, 0), 2), mm(24), mid
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
	-- (6 Nov, owner: "you don't see him well because of the scissors") a blade in front of his face / body goes
	-- see-through (client/Shears.reveal)
	local cam = workspace.CurrentCamera
	if SH and R and cam then
		SH:reveal(cam.CFrame, headCf(R), chestOf(R), dt)
	end
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
		-- FilmTryCam = "x,y,z,tx,ty,tz[,fov[,roll]]" (set coordinates): look through another lens (Opening.tryCam)
		local tc = workspace:GetAttribute("FilmTryCam")
		if type(tc) == "string" and tc ~= "" then
			local n = {}
			for x in string.gmatch(tc, "[^,]+") do
				table.insert(n, tonumber(x) or 0)
			end
			if #n >= 6 then
				Opening.tryCam(Vector3.new(n[1], n[2], n[3]), Vector3.new(n[4], n[5], n[6]), n[7], n[8])
			end
		elseif tryCam then
			tryCam = nil
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
	R:show(false)
	shearsMode = "hidden"
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

-- (Studio, for whoever frames the shots) while the film is held: look through another lens (set coordinates, as
-- the shots use them), nil to give the shot its own back; and the cast, to measure from.
function Opening.tryCam(from: Vector3?, to: Vector3?, fov: number?, roll: number?)
	if not RunService:IsStudio() then
		return
	end
	if not from or not to or not S then
		tryCam = nil
		return
	end
	local a, b = V(from.X, from.Y, from.Z), V(to.X, to.Y, to.Z)
	tryCam = { cf = look(a, b, roll or 0), fov = fov or 40, focus = b }
end
function Opening.cast(): any
	return { S = S, R = R, H = H, D = D, D2 = D2, SH = SH, T = T, now = now, V = V, held = function()
		return held
	end, playing = function()
		return playing
	end }
end

-- Take everything away (the end, or SKIP). Safe to call any time.
function Opening.stop()
	-- (the lens stays where it is: the last shot's function is called every frame until the next film cuts, and it
	-- looked at the cast this takes away: "attempt to index nil with 'root'" every frame through the credits)
	pcall(function()
		if Film.playing then
			local cam = workspace.CurrentCamera
			local cf, fov = cam.CFrame, cam.FieldOfView
			Film.cut(0.05, function()
				return cf, fov, cf.Position + cf.LookVector * 10
			end)
		end
	end)
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
	summon = nil
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
