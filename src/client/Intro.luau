-- The run's opening film, the first time you're in a new run. Remade on 29 Oct (owner: "I still don't think the
-- ending and intro is worth watching ... sometimes the camera just pans to the ground or just some useless thing",
-- "think about chop a forest and vv ultimatum, their intros are so good and worth watching, it's unique"; and of the
-- drawn clash panels, "the purple nonsense, it's so low quality"). About 35 seconds, no walking, no establishing
-- pans: every shot has someone in it doing something, and every shot was checked on a contact sheet in Studio
-- (client/FilmSheet) before the owner saw it.
--   I.   A PERFECT DAY: Mayor Thistlewick on his soapbox, eyes shut, savouring his perfect lawn; pink light flickers
--        over his face and his eyes snap open;
--   II.  THE GLITCH: over his shoulder, far out across the bare meadow, the gentle Dandelion King; the sky tears open
--        over him and a spark drops out of it onto his head [an impact frame]; his eyes burn pink; the same pink falls
--        on two more guardians (their own models, close up: it isn't their fault); the King breathes in and BLOWS his
--        seeds straight at us;
--   III. SWALLOWED: the seeds drift down round the Mayor and the grass erupts round him, over his head; his hat pops
--        out of the top. Silence. He bursts up out of the grass: "MOWERRRS!!!";
--   IV.  THE MOWERS: out of the sky, one after the other, the party lands in the camp (copies of everyone's avatars),
--        each with their name slammed up beside them; the whole line, low and wide; the Mayor points: "Mow it ALL...
--        and set the guardians FREE!";
--   V.   the supply crate slams down [an impact frame], the title lands; far beyond the meadow the sky tears again and
--        an eye opens in the dark; then you're in first person, ready to go.
-- The Mayor talks in client/Babble's mumble (Config.FILM.babble); subtitles always. Camera, light and grade:
-- client/Film; music and sound: client/FilmAudio; the effects: client/FilmVfx (VFX Forge templates, the old code
-- as the fallback). SKIP ends it at any moment. Once it has played (or been skipped) the server remembers it for
-- this run ("Seen" remote), so it doesn't play again on a rejoin.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MowALawn = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(MowALawn:WaitForChild("Config"))
local BossMoves = require(MowALawn:WaitForChild("BossMoves"))
local BossRig = require(MowALawn:WaitForChild("BossRig"))
local FxIds = require(MowALawn:WaitForChild("BossFxIds")) :: { [string]: string }
local Babble = require(script.Parent.Babble)
local BossView = require(script.Parent.BossView)
local PhonePerf = require(script.Parent.PhonePerf)
local Potato = require(script.Parent.Potato)
local HitFx = require(script.Parent.HitFx)
local IntroCast = require(script.Parent.IntroCast)
local IntroUi = require(script.Parent.IntroUi)
local Film = require(script.Parent.Film)
local FilmAudio = require(script.Parent.FilmAudio)
local FilmVoice = require(script.Parent.FilmVoice)
local Glitch = require(script.Parent.Glitch)
local Corruption = require(script.Parent.Corruption)
local FilmPanels = require(script.Parent.FilmPanels)
local GlitchHole = require(script.Parent.GlitchHole)
local FilmVfx = require(script.Parent.FilmVfx) -- (29 Oct) the effects as VFX Forge templates (old ones: the fallback)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Intro = {}
local player = Players.LocalPlayer

local UP = Vector3.yAxis
local GOLD = Color3.fromRGB(255, 214, 60)
local MAYOR = "Mayor Thistlewick"
local TIMEOUT = 120 -- whatever happens, you get your camera and controls back by now
local STEP = "MowIntro"

local playing = false
local played = false
local worldReady = false
local previewing = false -- (a replay from the DEV panel: the server isn't told it was seen)
local startAt: string? = nil -- (a DEV replay from a later beat: Intro.preview)
local generation = 0 -- bumps every showing

-- what's said, in this order (N: a narration line over the pictures; L: the Mayor). Short: the pictures tell it.
local LINES = {
	L0 = "Ahh... not a blade out of place.",
	N3b = "...and it got into the valley's guardians.",
	L1 = "...help?",
	L2 = "MOWERRRS!!!",
	L4 = "Mow it ALL... and set the guardians FREE!",
}
local ORDER = { "L0", "N3b", "L1", "L2", "L4" }

local flat, unit = Film.flat, Film.unit
local inOut, out, sine = Film.inOut, Film.out, Film.sine

local controls: any = nil
local function getControls(): any
	if not controls then
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			if module then
				controls = ((require :: any)(module)):GetControls()
			end
		end)
	end
	return controls
end

-------------------------------------------------------------------------------------------------------------
-- where everything is (built from the map, so it follows Config / the generated world)
-------------------------------------------------------------------------------------------------------------
type Plan = {
	hub: Vector3,
	gate: Vector3,
	entry: Vector3,
	fwd: Vector3,
	right: Vector3,
	dirIn: Vector3,
	cast: Vector3,
	mayorAt: Vector3,
	m0: Vector3,
	m1: Vector3,
	thick: Vector3, -- the middle of the thickest patch of grass near the way in
	dirK: Vector3, -- from the camp toward it
	areaName: string,
}

local function clumpSpots(): { Vector3 }
	local spots = {}
	local grass = workspace:FindFirstChild("Grass1", true)
	if grass then
		for _, d in grass:GetDescendants() do
			if d:IsA("Model") and d.Name == "Clump" then
				local at = d:GetPivot().Position
				if Config.zoneAt(at) == 1 then -- the meadow itself, not the grass round the village
					table.insert(spots, at)
				end
			end
		end
	end
	return spots
end

-- How close a straight dolly from a to b passes to any clump (sideways distance).
local function clearance(a: Vector3, b: Vector3, spots: { Vector3 }): number
	local ab = flat(b - a)
	local len2 = math.max(ab:Dot(ab), 0.01)
	local best = math.huge
	for _, s in spots do
		local k = math.clamp(flat(s - a):Dot(ab) / len2, 0, 1)
		local d = (flat(s - a) - ab * k).Magnitude
		if d < best then
			best = d
		end
	end
	return best
end

-- The thickest patch of grass near the way in: the clump with the most neighbours (closer ones win ties),
-- and the middle of that bunch.
local function thickest(spots: { Vector3 }, entry: Vector3): Vector3?
	local best, bestScore = nil, -math.huge
	for _, a in spots do
		local n, sum = 0, Vector3.zero
		for _, b in spots do
			if (flat(a - b)).Magnitude < 22 then
				n += 1
				sum += b
			end
		end
		local score = n - (a - entry).Magnitude * 0.02
		if score > bestScore then
			best, bestScore = sum / n, score
		end
	end
	return best
end

-- The low dolly into that patch: pick the line with the most room between the stalks.
local function meadowLine(thick: Vector3, dirK: Vector3, spots: { Vector3 }): (Vector3, Vector3)
	local side = dirK:Cross(UP)
	local bestA, bestB, bestRoom = thick - dirK * 16, thick - dirK * 2, -1
	for _, back in { 20, 16, 12 } do
		for off = -12, 12, 3 do
			local a = thick - dirK * back + side * off
			local b = a + dirK * 14
			local room = clearance(a, b, spots)
			if room > bestRoom + 0.5 then
				bestA, bestB, bestRoom = a, b, room
			end
		end
	end
	local ga, gb = IntroCast.ground(bestA), IntroCast.ground(bestB)
	return ga + UP * 2.4, gb + UP * 2.8
end

local function plan(): Plan
	local hub = Config.zoneCentre(0)
	local entry = Config.zoneEntry(1)
	local gate = entry
	for _, g in Config.gates() do
		if g.b == 1 then
			gate = g.pos
		end
	end
	local fwd = unit(flat(gate - hub), Vector3.zAxis)
	local dirIn = unit(flat(Config.zoneCentre(1) - entry), fwd)
	local cast = IntroCast.ground(hub:Lerp(gate, 0.42))
	-- the camp in area 1 (server/RunWorld.moveVillageToCamp): the party gathers there, the grass is all round it
	local w = workspace:FindFirstChild("World")
	local camp = w and w:GetAttribute("CampCenter")
	local from = entry
	if typeof(camp) == "Vector3" then
		local facing = w and w:GetAttribute("CampFacing")
		hub = camp
		fwd = if typeof(facing) == "Vector3" then unit(flat(facing), fwd) else fwd
		cast = IntroCast.ground(camp + fwd * 2)
		from = camp
	end
	local spots = {}
	for _, at in clumpSpots() do
		if (at - from).Magnitude < 220 then
			table.insert(spots, at)
		end
	end
	local thick = thickest(spots, from) or (from + dirIn * 60)
	thick = IntroCast.ground(thick)
	local dirK = unit(flat(thick - from), dirIn)
	local m0, m1 = meadowLine(thick, dirK, spots)
	local def = Config.ZONES[1]
	return {
		hub = hub,
		gate = gate,
		entry = entry,
		fwd = fwd,
		right = fwd:Cross(UP),
		dirIn = dirIn,
		cast = cast,
		mayorAt = cast + fwd * 15, -- (room between him and the party for the crate)
		m0 = m0,
		m1 = m1,
		thick = thick,
		dirK = dirK,
		areaName = if def and def.name then def.name else "Area 1",
	}
end

-- Ask the server to stream in the places the camera will visit (the map streams around your character).
local function streamIn(spots: { Vector3 })
	local left = #spots
	for _, at in spots do
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(at, 3)
			end)
			left -= 1
		end)
	end
	local deadline = os.clock() + 3
	while left > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

-- Keeping the camera out of buildings and trees (the camp and the meadow change as the map is edited): a shot is
-- laid out round its subject at a turn (yaw, degrees); the first turn whose camera spots all see the subject wins.
local function turn(v: Vector3, deg: number): Vector3
	return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v)
end

local YAWS = { 0, 25, -25, 50, -50, 75, -75, 100, -100, 130, -130, 160, -160, 180 }

-- The turn (from `yaws`, default YAWS, earlier ones win ties) whose spots(yaw) see `target(yaw)` best: every spot
-- must see it, and with `spread` the points that far to its left and right count too (so nothing sits at the
-- edges of the frame either). If no turn is clear, the one that comes closest.
local function freeYaw(spots: (number) -> { Vector3 }, target: (number) -> Vector3, yaws: { number }?, spread: number?): number
	local list = yaws or YAWS
	local best, bestScore = list[1], -1
	for _, y in list do
		local score = 0
		local t = target(y)
		for _, at in spots(y) do
			if Film.sees(at, t) then
				score += 2
			end
			if spread then
				local side = (t - at):Cross(UP)
				side = if side.Magnitude > 0.01 then side.Unit * spread else Vector3.zero
				score += (if Film.sees(at, t + side) then 1 else 0) + (if Film.sees(at, t - side) then 1 else 0)
			end
		end
		if score > bestScore then
			best, bestScore = y, score
		end
	end
	return best
end

-------------------------------------------------------------------------------------------------------------
-- dialogue: the Mayor's voice (if it's ready), his jaw, the subtitle, the music dipping under it
-------------------------------------------------------------------------------------------------------------
local mayor: IntroCast.Mayor? = nil
local heroCue: FilmAudio.Cue? = nil
local darkCue: FilmAudio.Cue? = nil
local leavesSound: Sound? = nil
local ambBed: FilmAudio.Cue? = nil

-- The ambience bed: the last one fades out as the new one fades in.
local function bed(key: string?, volume: number?, fade: number?)
	if ambBed then
		ambBed.stop(fade or 1.5)
		ambBed = nil
	end
	if key then
		ambBed = FilmAudio.amb(key, volume, fade)
	end
end

-- Say line `key` (narrated = storybook text over the pictures, not his lips). Returns how long it takes.
local function speak(key: string, narrated: boolean?, quiet: boolean?): number
	local text = LINES[key]
	local len, level = FilmVoice.play(text)
	local tts = len ~= nil
	local babbling = false
	if not len and not narrated then
		-- (owner, 28 Oct: the text-to-speech voice was "AI rubbish": he talks in client/Babble's mumble)
		len, level = Babble.line(text)
		babbling = Babble.voice() ~= "none"
	end
	local dur = len or math.clamp(#text * 0.062, 1.8, 5.5)
	if narrated then
		IntroUi.narrate(text, dur + 0.6)
	else
		IntroUi.say(MAYOR, text, dur + 0.7)
		local m = mayor
		if m then
			if level then
				m.speak(level)
				task.delay(dur + 0.15, function()
					if mayor == m then
						m.speak(nil)
					end
				end)
			else
				m.chatter(dur)
			end
		end
	end
	if tts or babbling then
		FilmAudio.duck(if quiet then 0.6 elseif babbling then 0.28 else 0.42, 0.25)
		task.delay(dur, function()
			if playing then
				FilmAudio.duck(0, 0.8)
			end
		end)
	end
	return dur
end

-------------------------------------------------------------------------------------------------------------
-- the light for each part of the story
-------------------------------------------------------------------------------------------------------------
local LOOKS = {
	past = { ClockTime = 9.6, ExposureCompensation = 0.12, atmosphere = { Density = 0.24, Haze = 0.8, Glare = 0.6 } },
	-- the growing happens in plain daylight (owner, 28 Oct: at dusk, in the gloom, nobody saw it grow)
	day = { ClockTime = 12.2, ExposureCompensation = 0.06, atmosphere = { Density = 0.25, Haze = 0.9, Glare = 0.35 } },
	night = { ClockTime = 18.55, ExposureCompensation = -0.4, atmosphere = { Density = 0.4, Haze = 2.2, Glare = 0 } },
	now = { ClockTime = 15.6, ExposureCompensation = -0.22, atmosphere = { Density = 0.34, Haze = 1.6, Glare = 0.1 } },
	hero = { ClockTime = 16.9, ExposureCompensation = 0.02, atmosphere = { Density = 0.27, Haze = 1.0, Glare = 0.7 } },
	-- the guardians close up (29 Oct, the contact sheet: their bright faces and the pink glow blew out to white)
	boss = { ClockTime = 13.4, ExposureCompensation = -0.55, atmosphere = { Density = 0.26, Haze = 0.7, Glare = 0.05 } },
}

-------------------------------------------------------------------------------------------------------------
-- what the scenes share: the effects, the guardians on the set, the King's pink eyes (owner, 28 Oct: "show that
-- grass grows", "show a boss when it mentions a boss", then "it's not his fault"; the councils: the grass needs a
-- cause you can see, growing only reads in daylight with the camera still, the cause is the pink: show it arrive)
-------------------------------------------------------------------------------------------------------------
local fxParts: { Instance } = {} -- the seed clouds, the spark and the King's eye glints (in the set: they go with it)
local fxStops: { () -> () } = {} -- their per-frame updates
local overgrown: ((number) -> ())? = nil -- sinks the film-only tall grass round the soapbox
local bossShown = false -- (this film showed a boss model: client/BossView is the fights' too)
local bossesOk = true -- (false when a fight's boss is in client/BossView as the film starts: it's left alone)
local corrupt: Corruption.Handle? = nil -- the tear in the sky
local clash: FilmPanels.Clash? = nil
local kingEyesOff: (() -> ())? = nil -- puts out the King's pink eyes
local kingBurst: ParticleEmitter? = nil -- the seeds out of his mouth
local kingFx: { Model } = {} -- (VFX Forge) the seed blast's stream and his aura: they go when he does

local function clearFx()
	FilmVfx.clear()
	for _, stop in fxStops do
		stop()
	end
	table.clear(fxStops)
	for _, p in fxParts do
		p:Destroy()
	end
	table.clear(fxParts)
	if corrupt then
		corrupt.destroy()
		corrupt = nil
	end
	if clash then
		clash.destroy()
		clash = nil
	end
	kingEyesOff = nil
	kingBurst = nil
end

-- The King has done his part: off the set with his pink eyes and his seed spray, at a cut (never in shot). (Owner,
-- 28 Oct evening, a screenshot of the crane shot over the grass with him in it: "this part looks a bit bad".)
local function kingGone()
	if kingEyesOff then
		kingEyesOff()
		kingEyesOff = nil
	end
	if kingBurst then
		kingBurst.Rate = 0
		kingBurst = nil
	end
	for _, fx in kingFx do
		FilmVfx.stop(fx)
	end
	table.clear(kingFx)
	if bossShown then
		bossShown = false
		BossView.hide()
	end
end

-- the boss model client/BossView is showing (for an impact frame's silhouette)
local function bossModel(): Model?
	local f = workspace:FindFirstChild("BossView")
	local m = f and f:FindFirstChildWhichIsA("Model")
	return if m and m:IsA("Model") then m else nil
end

-- a boss model's scale for its fight height (as server/Boss works it out)
local function bossScale(z: number): number
	local moves = BossMoves.get(z)
	local rig = BossRig.load(moves.rig)
	local h = if rig then rig.bounds[2][2] else 7
	return moves.height / math.max(1, h)
end

local function showBoss(z: number, feet: Vector3, facing: Vector3)
	bossShown = true
	BossView.show(BossMoves.get(z).rig, CFrame.lookAt(feet, feet + flat(facing)), bossScale(z))
end

local function setPart(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = workspace:FindFirstChild("IntroSet") or workspace
	table.insert(fxParts, p)
	return p
end

-- Dandelion seeds (the King's own fluff, shared/BossFxIds) from a hidden part, blown out of its `face`.
type Cloud = { rate: number, speed: NumberRange, spread: Vector2, life: NumberRange, face: Enum.NormalId?, scale: number? }
local function seedCloud(cf: CFrame, size: Vector3, o: Cloud): ParticleEmitter
	local p = setPart("Seeds", size, cf)
	local e = Instance.new("ParticleEmitter")
	-- (owner, 29 Oct: the seed sprite was "very low quality" up close: soft glowing fluff, as client/FilmVfx's)
	e.Texture = FxIds.glow or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 250), Color3.fromRGB(255, 246, 222))
	e.LightEmission = 0.45
	local s = o.scale or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.33 * s), NumberSequenceKeypoint.new(1, 0.25 * s) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.85, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = o.life
	e.Rate = o.rate
	e.Speed = o.speed
	e.SpreadAngle = o.spread
	e.EmissionDirection = o.face or Enum.NormalId.Front
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-80, 80)
	e.Drag = 0.7
	e.Acceleration = Vector3.new(0, -1.4, 0)
	e.Parent = p
	return e
end

-- The King's eyes burn the demon's pink from now on (glowing balls on his eye points, every frame). Returns a
-- function that puts them out.
local function pinkEyes(H: number): () -> ()
	local names = BossView.attAll("att_eye")
	local glints: { BasePart } = {}
	for i in names do
		-- (29 Oct, the contact sheet: with a light on them and bigger, the guardians' faces read as pink blobs)
		local g = setPart("DemonGlint", Vector3.one * math.max(0.5, H * 0.03), CFrame.new())
		g.Shape = Enum.PartType.Ball
		g.Material = Enum.Material.Neon
		g.Color = FilmPanels.PINK
		g.Transparency = 0
		table.insert(glints, g)
	end
	local stop = Film.every(function()
		for i, name in names do
			local at = BossView.attWorld(name)
			if at and glints[i] then
				glints[i].CFrame = CFrame.new(at)
			end
		end
	end)
	table.insert(fxStops, stop)
	-- (VFX Forge) each eye snaps on with a glint and a streak and burns, riding on its glint (placed next frame)
	local eyeFx: { Model } = {}
	task.defer(function()
		for _, g in glints do
			local fx = g.Parent and FilmVfx.play("PinkEye", g.CFrame, { follow = g, scale = H / 22 })
			if fx then
				table.insert(eyeFx, fx)
			end
		end
	end)
	return function()
		stop()
		for _, fx in eyeFx do
			FilmVfx.stop(fx)
		end
		for _, g in glints do
			g:Destroy()
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- I. A PERFECT DAY (owner, 29 Oct: "the camera just pans to the ground or just some useless thing", "think about
-- chop a forest and vv ultimatum, their intros are so good and worth watching": no establishing pans, no walking,
-- no shot without someone in it doing something, and every shot checked on a contact sheet: client/FilmSheet)
-------------------------------------------------------------------------------------------------------------
-- The scenery near `near` as boxes: the trees, the camp's props, the hills (CanQuery is off on most of them, so a
-- raycast goes straight through them: Film.sees can't see a tree). Thousands of parts: spread over a few frames.
type Box = { cf: CFrame, h: Vector3, p: Vector3, r: number }
local function sceneryBoxes(near: Vector3, radius: number): { Box }
	local boxes: { Box } = {}
	local world = workspace:FindFirstChild("World")
	local n = 0
	-- (30 Oct: every folder of the world but the grass (hidden in the films), water and the invisible bounds: the
	-- boss arenas and the area camps were missing)
	local skip = { Grass = true, Liquid = true, Bounds = true, Loot = true, Mowers = true, Crawlers = true, Water = true }
	for _, f in (if world then world:GetChildren() else {}) do
		if not skip[f.Name] then
			for _, d in f:GetDescendants() do
				n += 1
				if n % 2000 == 0 then
					task.wait()
				end
				if d:IsA("BasePart") and d.Transparency < 0.95 and d.Size.Magnitude > 3 and flat(d.Position - near).Magnitude < radius then
					table.insert(boxes, { cf = d.CFrame, h = d.Size / 2, p = d.Position, r = d.Size.Magnitude / 2 })
				end
			end
		end
	end
	return boxes
end

-- (one axis of a line-through-a-box test: the part of the line, t0..t1, inside the box's slab on that axis)
local function slab(o: number, v: number, e: number, t0: number, t1: number): (number, number)
	if math.abs(v) < 1e-6 then
		if o < -e or o > e then
			return 1, 0
		end
		return t0, t1
	end
	local u0, u1 = (-e - o) / v, (e - o) / v
	if u0 > u1 then
		u0, u1 = u1, u0
	end
	return math.max(t0, u0), math.min(t1, u1)
end

-- Whether the line from `a` to `b` goes through any of the boxes.
local function blocked(a: Vector3, b: Vector3, boxes: { Box }): boolean
	local ab = b - a
	local len2 = math.max(ab:Dot(ab), 1e-6)
	for _, bx in boxes do
		local t = math.clamp((bx.p - a):Dot(ab) / len2, 0, 1)
		if (a + ab * t - bx.p).Magnitude <= bx.r then
			local la = bx.cf:PointToObjectSpace(a)
			local d = bx.cf:PointToObjectSpace(b) - la
			local t0, t1 = slab(la.X, d.X, bx.h.X, 0, 1)
			if t0 <= t1 then
				t0, t1 = slab(la.Y, d.Y, bx.h.Y, t0, t1)
			end
			if t0 <= t1 then
				t0, t1 = slab(la.Z, d.Z, bx.h.Z, t0, t1)
			end
			if t0 <= t1 then
				return true
			end
		end
	end
	return false
end

-- Where the Dandelion King stands: out in the meadow, 60-110 studs from the Mayor, on the meadow's floor, where the
-- tear shot (over the Mayor's shoulder: tearScene) sees all of him and the sky over him, and not in a tree (29 Oct,
-- two contact sheets: the trees hid him; a raycast can't see them, so the scenery's boxes are checked instead).
local function kingSpot(P: Plan): Vector3
	local H = BossMoves.get(1).height
	local w = workspace:FindFirstChild("World")
	local floor = w and w:FindFirstChild("Ground")
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = if floor then { floor } else {}
	local toward = unit(flat(P.thick - P.mayorAt), P.fwd)
	local boxes = sceneryBoxes(P.mayorAt, 200)
	local best, bestScore = IntroCast.ground(P.thick + P.dirK * 30), -99
	-- (30 Oct, owner: "cant even see dandelion boss in first intro because of house": the tool shop's roof cut
	-- through him: four points up his middle were clear, a thin roof edge sat between two of them. Now 7 heights x
	-- his middle and both sides, and the tear over him, must all be clear (22 lines); the search turns further round
	-- the Mayor (meadow side first) before it settles for the clearest spot.)
	local full = 7 * 3 + 1
	for _, yaw in { 0, -10, 10, -20, 20, -30, 30, -40, 40, -55, 55, -70, 70, -90, 90, -110, 110, -135, 135, -160, 160, 180 } do
		for _, dist in { 78, 88, 68, 100, 58, 112 } do
			local at = P.mayorAt + turn(toward, yaw) * dist
			local hit = workspace:Raycast(at + UP * 200, -UP * 400, rp)
			if hit then
				local feet = hit.Position
				local toCamp = unit(flat(P.mayorAt - feet), -toward)
				local side = toCamp:Cross(UP)
				local eye = P.mayorAt + UP * 8.4 + toCamp * 7.5 - side * 3.6
				local score = 0
				for _, k in { 0.97, 0.83, 0.69, 0.55, 0.41, 0.27, 0.13 } do
					for _, s in { 0, -1, 1 } do
						if not blocked(eye, feet + UP * (H * k) + side * (H * 0.22 * s), boxes) then
							score += 1
						end
					end
				end
				if not blocked(eye, feet + UP * (H * 1.75) + toCamp * (H * 0.3), boxes) then
					score += 1
				end
				for _, s in { 0, 1, -1 } do
					local p = feet + side * (H * 0.25 * s)
					if blocked(p + UP * 1.5, p + UP * H, boxes) then
						score -= 10
					end
				end
				if score > bestScore then
					best, bestScore = feet, score
				end
				if score >= full then
					return best
				end
			end
		end
		task.wait()
	end
	return best
end

-- 1: the Mayor on his soapbox, eyes shut, savouring his perfect lawn (a medium close-up: his voxel face reads at
-- this size and looks like blocks any closer); pink light flickers over his face... his eyes snap open, up at the sky.
local function peaceScene(P: Plan, m: IntroCast.Mayor, kingFeet: Vector3): boolean
	IntroCast.hideGrass(true)
	Film.light(LOOKS.day, 0)
	Film.grade("hero", 0)
	Film.glow(0.18, 26, 0)
	Film.vignette(0.3, 0)
	IntroUi.film(false)
	bed("ambBirds", 1.3, 1.5)
	local story = FilmAudio.music("storyMusic", { fade = 1.2, volume = 0.9 })
	IntroUi.fade(1, 0.9)
	local face = unit(flat(kingFeet - P.mayorAt), P.fwd)
	m.act("proud")
	m.mood("happy")
	m.closeEyes(true)
	m.look(P.mayorAt + face * 30 + UP * 8)
	Film.at(0.5, function()
		speak("L0")
	end)
	Film.at(2.2, function()
		if story then
			story.tapeStop(0.8)
		end
		FilmAudio.glitch(0.45)
		FilmAudio.sfx("synthWhomp", { pitch = 0.6, volume = 0.6 })
		-- the tear's light, from over the camera's shoulder
		local lamp = setPart("TearLight", Vector3.one * 0.2, CFrame.new(m.face() + face * 7 + UP * 6))
		local l = Instance.new("PointLight")
		l.Color = FilmPanels.PINK
		l.Range = 12
		l.Shadows = false
		l.Brightness = 0
		l.Parent = lamp
		table.insert(fxStops, Film.every(function(_: number, now: number)
			l.Brightness = math.max(0, 0.7 + math.noise(now * 11, 4.2) * 1.4)
		end))
	end)
	Film.at(2.55, function()
		m.closeEyes(false)
		m.mood("surprised")
		m.act("shock")
		m.look(kingFeet + UP * 60)
	end)
	local head = m.face()
	local yaw = freeYaw(function(y)
		return { head + turn(face, y) * 9.5 - UP * 0.7 }
	end, function()
		return head
	end, { 28, -28, 40, -40, 15, -15 })
	local d0 = turn(face, yaw)
	return Film.run(3.4, function(k)
		local f = m.face()
		local pos = f + d0 * (9.5 - 1.4 * inOut(k)) - UP * 0.7
		return Film.look(pos, f - UP * 0.8), Film.mm(42), f
	end, { hand = 0.2 })
end

-------------------------------------------------------------------------------------------------------------
-- II. THE GLITCH
-------------------------------------------------------------------------------------------------------------
-- The point a guardian's close-ups frame: its head (att_head_center), else most of the way up it.
local function headOf(feet: Vector3, H: number): Vector3
	return BossView.attWorld("att_head_center") or (feet + UP * (H * 0.8))
end

-- 2: over the Mayor's shoulder, far out across the bare meadow, the gentle Dandelion King stands in the sun. Above
-- him the sky tears open in pink and a spark drops out of it, straight onto his head [an impact frame, black and
-- white]: he staggers and changes (client/BossView's rage). The Mayor, the King and the tear in one picture.
local function tearScene(P: Plan, m: IntroCast.Mayor, kingFeet: Vector3): boolean
	local H = BossMoves.get(1).height
	local toCamp = unit(flat(P.mayorAt - kingFeet), -P.dirK)
	Film.light(LOOKS.day, 0.4)
	Film.glow(0.06, 20, 0.3)
	bed("ambWind", 1.2, 1.2)
	if bossesOk then
		showBoss(1, kingFeet, toCamp)
		BossView.critters("intro", 2)
	end
	local C = Corruption.new(kingFeet)
	corrupt = C
	-- the tear: high over him, a little toward us, facing the camp
	local sky = kingFeet + UP * (H * 1.75) + toCamp * (H * 0.3)
	local head = kingFeet + UP * (H * 0.8)
	local f0 = m.face()
	local camAt = f0 + toCamp * 7.5 - toCamp:Cross(UP) * 3.6 + UP * 1.4
	Film.at(0.35, function()
		if not FilmVfx.play("SkyTear", CFrame.lookAt(sky, camAt), { scale = H * 1.4 / 40 }) then
			C.rift(sky, toCamp, H * 1.4, 0.45)
		end
		FilmAudio.glitch(0.6)
		Glitch.burst(0.35, 0.16)
		FilmAudio.sfx("synthWhomp", { volume = 0.7, pitch = 0.5 })
		darkCue = FilmAudio.music("darkMusic", { fade = 0.6 })
	end)
	-- the spark: out of the tear, falling faster and faster, a pink streak behind it
	local spark = setPart("Spark", Vector3.one * math.max(1.2, H * 0.06), CFrame.new(sky))
	spark.Shape = Enum.PartType.Ball
	spark.Material = Enum.Material.Neon
	spark.Color = FilmPanels.PINK
	local glow = Instance.new("PointLight")
	glow.Color = FilmPanels.PINK
	glow.Range = 22
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = spark
	local FALL_AT, HIT_AT = 1.3, 2.35
	local t0 = Film.now()
	local hit = false
	local sparkFx: Model? = nil
	Film.at(FALL_AT, function()
		sparkFx = FilmVfx.play("SparkFall", spark.CFrame, { follow = spark, scale = math.max(1, H / 14) })
		FilmAudio.riser("riseDark", HIT_AT - FALL_AT - 0.25, { volume = 0.6 })
	end)
	table.insert(fxStops, Film.every(function(_: number, now: number)
		local t = now - t0
		if hit or t < FALL_AT then
			return
		end
		local k = math.clamp((t - FALL_AT) / (HIT_AT - FALL_AT), 0, 1)
		spark.Transparency = 0
		glow.Brightness = 5
		local aim = if bossesOk then headOf(kingFeet, H) else head
		spark.CFrame = CFrame.new(sky:Lerp(aim, k * k))
	end))
	Film.at(HIT_AT - 0.25, function()
		FilmAudio.duck(1, 0.1)
	end)
	Film.at(HIT_AT, function()
		hit = true
		spark.Transparency = 1
		glow.Brightness = 0
		FilmVfx.stop(sparkFx)
		sparkFx = nil
		local hitAt = if bossesOk then headOf(kingFeet, H) else head
		FilmVfx.play("SparkHit", CFrame.lookAt(hitAt, camAt), { scale = H / 14 })
		FilmVfx.play("KingBurst", CFrame.new(kingFeet), { scale = H / 14 })
		FilmAudio.sfx("impact", { volume = 0.95, pitch = 0.8 })
		FilmAudio.sfx("synthWhomp", { volume = 0.8, pitch = 0.45 })
		FilmPanels.impact(if bossesOk then { bossModel() } else {}, { at = hitAt, invert = true })
		Film.shake(0.45, 1.4)
		m.act("cower")
		m.mood("scared")
		if bossesOk then
			BossView.act("rage")
			kingEyesOff = pinkEyes(H)
		end
		task.delay(0.35, function()
			if playing then
				FilmAudio.duck(0, 0.4)
			end
		end)
	end)
	-- (wide: the King's feet to the tear over him; a slow push in)
	local look = kingFeet + UP * (H * 0.95)
	return Film.run(HIT_AT + 0.45, function(k)
		local pos = camAt - toCamp * (k * 1.2)
		return Film.look(pos, look), Film.mm(28), look
	end, { hand = 0.25, far = 0.05 })
end

-- 3: close on the King: the pink burning in his eyes as he heaves (no ground in the picture: up at his face
-- against the sky).
local function eyesScene(P: Plan, kingFeet: Vector3): boolean
	if not bossesOk then
		return true
	end
	local H = BossMoves.get(1).height
	local toCamp = unit(flat(P.mayorAt - kingFeet), -P.dirK)
	local side = toCamp:Cross(UP)
	Film.light(LOOKS.boss, 0)
	Film.glow(0, 16, 0)
	Film.at(0.2, function()
		FilmAudio.sfx("growl", { volume = 0.9, pitch = 0.8 })
	end)
	return Film.run(1.7, function(k)
		local h = headOf(kingFeet, H)
		local pos = h + toCamp * (H * (0.85 - 0.1 * k)) + side * (H * 0.2) - UP * (H * 0.16)
		return Film.look(pos, h + UP * (H * 0.02)), Film.mm(36), h
	end, { hand = 0.35 })
end

-- 4: "...and got into the valley's guardians": the same pink falls on two more of them, one after the other, a
-- close-up each (their own models, up against the sky; a different two each run: you meet them in their own lands).
-- Owner, 29 Oct, of the old drawn panels: "the purple nonsense, it's so low quality": these are the real guardians.
local function othersScene(P: Plan, kingFeet: Vector3): boolean
	if not bossesOk then
		return true
	end
	local toCamp = unit(flat(P.mayorAt - kingFeet), -P.dirK)
	local zs = {}
	for z = 2, #Config.ZONES do
		-- (not the Sakura Snapjaw: pink on pink, under the pink spark, read as a blob)
		if z ~= 3 then
			table.insert(zs, z)
		end
	end
	-- (two of them, at random)
	for i = #zs, 2, -1 do
		local j = math.random(1, i)
		zs[i], zs[j] = zs[j], zs[i]
	end
	IntroUi.narrate(LINES.N3b, 2.0)
	for i = 1, math.min(2, #zs) do
		local z = zs[i]
		local H2 = BossMoves.get(z).height
		if kingEyesOff then
			kingEyesOff()
			kingEyesOff = nil
		end
		showBoss(z, kingFeet, toCamp)
		local side = toCamp:Cross(UP) * (if i == 1 then 1 else -1)
		Film.at(0.18, function()
			local h = headOf(kingFeet, H2)
			FilmVfx.play("SparkHit", CFrame.lookAt(h, h + toCamp), { scale = H2 / 24 })
			FilmAudio.sfx("bigHit", { volume = 0.5, pitch = 0.85 + i * 0.12 })
			FilmAudio.sfx("growl2", { volume = 0.8, pitch = 0.8 + i * 0.1 })
			Film.flash(Color3.new(1, 1, 1), 0.25, 0.15)
			Film.shake(0.3, 2)
			BossView.flinch(true)
			kingEyesOff = pinkEyes(H2)
		end)
		local ok = Film.run(0.95, function(k)
			local h = headOf(kingFeet, H2)
			local pos = h + toCamp * (H2 * (1.15 - 0.06 * k)) + side * (H2 * 0.26) - UP * (H2 * 0.15)
			return Film.look(pos, h, (if i == 1 then 6 else -6)), Film.mm(40), h
		end, { cut = "smash", hand = 0.3 })
		if not ok then
			return false
		end
	end
	-- the King again, changed
	if kingEyesOff then
		kingEyesOff()
		kingEyesOff = nil
	end
	showBoss(1, kingFeet, toCamp)
	BossView.rageNow()
	kingEyesOff = pinkEyes(BossMoves.get(1).height)
	return true
end

-- 5: the King fills up with a huge breath (seeds pulled into his mouth)... and BLOWS them over the valley, straight
-- at us: the screen goes white with seeds.
local function blowScene(P: Plan, kingFeet: Vector3): boolean
	if not bossesOk then
		return true
	end
	local H = BossMoves.get(1).height
	local toCamp = unit(flat(P.mayorAt - kingFeet), -P.dirK)
	local side = toCamp:Cross(UP)
	BossView.critters("intro", 3)
	BossView.act("blow", { land = 0.9, hold = 1.4 })
	local mouth0 = headOf(kingFeet, H)
	FilmVfx.play("SeedInhale", CFrame.new(mouth0), { scale = H / 14 })
	local inhale = FilmAudio.sfx("suck", { volume = 0.55, pitch = 1.3 })
	-- 5A: from the side, his cheeks filling
	local ok = Film.run(0.95, function(k)
		local h = headOf(kingFeet, H)
		local pos = h + side * (H * 0.95) + toCamp * (H * 0.3) - UP * (H * 0.08)
		return Film.look(pos, h), Film.mm(36 + 6 * k), h
	end, { hand = 0.3 })
	FilmAudio.fadeOut(inhale, 0.15)
	if not ok then
		return false
	end
	-- 5B: in front of him as he blows: the seeds come straight at the camera
	local mouth = headOf(kingFeet, H)
	local camAt = mouth + toCamp * (H * 0.85) - UP * (H * 0.18)
	local blast = FilmVfx.play("SeedBlast", CFrame.lookAt(mouth, camAt), { scale = H / 14 })
	if blast then
		table.insert(kingFx, blast)
	else
		local light = PhonePerf.on or Potato.on
		local burst = seedCloud(CFrame.lookAt(mouth, camAt), Vector3.new(H * 0.22, H * 0.22, 1), { rate = if light then 300 else 520, speed = NumberRange.new(30, 55), spread = Vector2.new(26, 16), life = NumberRange.new(2.6, 4), scale = 2.2 })
		kingBurst = burst
	end
	FilmAudio.sfx("swipe", { volume = 1.1, pitch = 0.5 })
	leavesSound = FilmAudio.sfx("leaves", { volume = 1 })
	Film.shake(0.4, 1.2)
	Film.at(0.85, function()
		Film.flash(Color3.new(1, 1, 1), 1, 0.5)
	end)
	return Film.run(1.1, function(k)
		local h = headOf(kingFeet, H)
		return Film.look(camAt - toCamp * (k * 2), h - UP * (H * 0.04)), Film.mm(30), h
	end, { hand = 0.4 })
end

-------------------------------------------------------------------------------------------------------------
-- III. SWALLOWED
-------------------------------------------------------------------------------------------------------------
-- 6: back at the camp the seeds come drifting down round the Mayor... he looks up... and the grass ERUPTS round him,
-- up past his knees, his chest, his nose, over his hat; a beat; his hat pops up out of the top and drops back in.
-- (A still shot from the camp's side, in plain daylight: growth only reads when it swallows something you know.)
local function swallowScene(P: Plan, m: IntroCast.Mayor, kingFeet: Vector3): boolean
	kingGone()
	Film.light(LOOKS.day, 0)
	Film.glow(0.12, 24, 0)
	local light = PhonePerf.on or Potato.on
	local feet = IntroCast.ground(P.mayorAt)
	local face = unit(flat(kingFeet - feet), P.fwd)
	local side = face:Cross(UP)
	m.act("idle")
	m.mood("neutral")
	m.look(feet + face * 6 + UP * 16)
	if not FilmVfx.play("SeedDrift", CFrame.new(feet + UP * 15 + face * 2)) then
		seedCloud(CFrame.new(feet + UP * 15 + face * 2), Vector3.new(30, 1, 30), { rate = if light then 50 else 90, speed = NumberRange.new(3, 6), spread = Vector2.new(25, 25), life = NumberRange.new(4, 6), face = Enum.NormalId.Bottom, scale = 1.5 })
	end
	local rustle: Sound? = nil
	Film.at(1.0, function()
		-- the real meadow behind him rising out of the soil, and the film's own tall grass that swallows him
		IntroCast.sproutGrass(feet, feet + face * 30, 5, nil, if light then 70 else 150)
		overgrown = IntroCast.overgrow(feet, 3.2, 11.5, if light then 10 else 16, 1.5, 0.6)
		m.mood("scared")
		m.act("shock")
		m.look(feet + face * 8 + UP * 4)
		rustle = FilmAudio.sfx("leaves", { volume = 1.3 })
		FilmAudio.sfx("rumble", { volume = 0.8, pitch = 1.2 })
		for i = 0, 4 do
			Film.at(i * 0.25, function()
				FilmAudio.sfx("brush", { volume = 0.8 + i * 0.1, pitch = 0.8 + i * 0.06 })
			end)
		end
	end)
	Film.at(1.6, function()
		m.act("cower")
		m.crouch(0.4)
	end)
	Film.at(2.7, function()
		if darkCue then
			darkCue.stop(0.6)
			darkCue = nil
		end
		FilmAudio.fadeOut(rustle, 0.8)
	end)
	Film.at(3.25, function()
		-- the hat, up out of the top of the grass (he's under it all)
		m.hatPop(9)
		FilmAudio.sfx("whomp", { volume = 0.9, pitch = 1.4 })
	end)
	Film.at(3.9, function()
		speak("L1", false, true)
	end)
	local yaw = freeYaw(function(y)
		local d = turn((face + side * 1.2).Unit, y)
		return { feet + d * 14 + UP * 5 }
	end, function()
		return feet + UP * 5
	end, { 0, 20, -20, 40, -40, 60, -60 })
	local d = turn((face + side * 1.2).Unit, yaw)
	local camAt = feet + d * 14 + UP * 5
	local look = feet + UP * 5.5
	return Film.run(4.8, function(k)
		return CFrame.lookAt(camAt - d * (k * 0.8), look + UP * (k * 1.5)), Film.mm(30), look
	end, { hand = 0.05 })
end

-- 7: silence... then the Mayor bursts up out of the top of the grass, spitting blades, his hat landing back on his
-- head, and yells for help with everything he's got: "MOWERRRS!!!"
local function callScene(P: Plan, m: IntroCast.Mayor, kingFeet: Vector3): boolean
	local feet = IntroCast.ground(P.mayorAt)
	local face = unit(flat(kingFeet - feet), P.fwd)
	local toParty = -face
	m.crouch(0)
	m.act("idle")
	m.mood("stern")
	-- (up on top of the grass: his head and shoulders over it)
	m.place(CFrame.lookAt(feet + UP * 7.2, feet + UP * 7.2 + toParty))
	m.hatPop(2.2)
	FilmAudio.sfx("brush", { volume = 1.2, pitch = 1.1 })
	FilmAudio.sfx("whomp", { volume = 1, pitch = 0.9 })
	Film.shake(0.25, 2)
	Film.at(0.55, function()
		m.act("fist")
		m.look(P.cast + UP * 4 - P.fwd * 30)
		speak("L2")
		heroCue = FilmAudio.music("heroMusic", { fade = 0.2 })
		Film.shake(0.5, 1.6)
		Film.punch(8)
	end)
	local side = toParty:Cross(UP)
	-- (29 Oct, the contact sheet: 7 studs out and below his face, the camera was inside the tall grass round him (its
	-- clumps reach ~8 studs out and ~14 up): now 11-12 studs out and just over the grass, the grass along the bottom)
	return Film.run(2.2, function(k)
		local f = m.face()
		local pos = f + toParty * (12.5 - 1.5 * out(k)) + side * 1.8
		pos = Vector3.new(pos.X, math.max(f.Y + 0.3, feet.Y + 14.5), pos.Z)
		return Film.look(pos, f + UP * 0.4), Film.mm(40), f
	end, { hand = 0.3 })
end

-------------------------------------------------------------------------------------------------------------
-- IV. THE MOWERS
-------------------------------------------------------------------------------------------------------------
-- 8: and they come: out of the sky, one after the other, each Mower lands in the camp in a burst of dust, a
-- close-up and their name slammed up beside them (the party: copies of everyone's avatars; up to four get their own
-- landing, the rest land in the next shot).
local function dropScene(P: Plan, actors: { IntroCast.Actor }): boolean
	for i = 1, math.min(#actors, 4) do
		local actor = actors[i]
		local spot = actor.spot
		local fwd = spot.LookVector
		local foot = spot.Position
		Film.at(0.05, function()
			FilmAudio.sfx("swipe2", { volume = 0.8, pitch = 0.7 + i * 0.05 })
			actor.drop(function(at: Vector3)
				if not playing then
					return
				end
				FilmAudio.sfx("thud", { volume = 1.1, pitch = 0.8 })
				FilmAudio.sfx("impact", { volume = 0.5, pitch = 1.2 })
				Film.shake(0.45, 2.2)
				Film.punch(5)
				-- (one small puff: four of a guardian's rising dust hid the Mower, 29 Oct contact sheet)
				HitFx.play("bossSlamDust", at, Color3.fromRGB(196, 168, 120), false)
				actor.play("emote")
				IntroUi.lowerThird(string.upper(actor.name), "MOWER", GOLD, 1.0)
			end)
		end)
		local s = fwd:Cross(UP) * (if i % 2 == 0 then -1 else 1)
		local ok = Film.run(1.05, function(k)
			local pos = foot + fwd * (7.6 - 0.6 * k) + s * 2.2 + UP * 1.4
			return Film.look(pos, foot + UP * 3.1), Film.mm(32), foot + UP * 3
		end, { cut = if i > 1 then "smash" else nil, hand = 0.25 })
		if not ok then
			return false
		end
	end
	return true
end

-- 9: the Mowers, all of them, in a row: low and wide, the sun behind them, the Mayor in his grass beside them.
local function lineupScene(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }, centre: Vector3): boolean
	local n = #actors
	for i = 5, n do
		local actor = actors[i]
		Film.at(0.05 + (i - 5) * 0.12, function()
			actor.drop(function()
				if playing then
					FilmAudio.sfx("thud", { volume = 0.8, pitch = 0.85 })
					actor.play("emote")
				end
			end)
		end)
	end
	Film.at(0.45, function()
		for _, actor in actors do
			actor.look(nil)
			actor.play("cheer")
		end
	end)
	Film.at(0.3, function()
		IntroUi.lowerThird("THE MOWERS", if n == 1 then "One Mower. One valley." else n .. " Mowers. One valley.", GOLD, 2.3)
	end)
	m.look(centre + UP * 4)
	m.act("cheer")
	m.mood("happy")
	-- (across the line, from in front: far enough back that everyone fits)
	local half = math.max(1, n - 1) * 4.4 / 2 + 2.6
	local dist = math.max(9, half / math.tan(math.rad(34)))
	local dir = (P.fwd * 0.87 + P.right * 0.5).Unit
	return Film.run(2.6, function(k)
		local pos = centre + dir * (dist - 1.2 * k) + UP * 1.5
		return Film.look(pos, centre + UP * 3.6, -3 + 3 * k), Film.mm(24), centre + UP * 3
	end, { hand = 0.3 })
end

-- 10: the Mayor, up on his grass, points at the Mowers: "Mow it ALL... and set the guardians FREE!"
local function pleaScene(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }, kingFeet: Vector3): boolean
	local feet = IntroCast.ground(P.mayorAt)
	local face = unit(flat(kingFeet - feet), P.fwd)
	m.mood("stern")
	-- (facing the Mowers, up on his grass: he points straight at them, and at us)
	Film.at(0.2, function()
		m.act("point")
		m.look(P.cast + UP * 4)
		speak("L4")
	end)
	for _, actor in actors do
		actor.look(m.face())
	end
	local side = face:Cross(UP)
	-- (outside his tall grass and just over it, as in the call)
	return Film.run(2.9, function(k)
		local f = m.face()
		local pos = f - face * (12.5 - 1 * inOut(k)) + side * 3.2
		pos = Vector3.new(pos.X, math.max(f.Y, feet.Y + 14.3), pos.Z)
		return Film.look(pos, f - UP * 0.4), Film.mm(40), f
	end, { hand = 0.3 })
end

-------------------------------------------------------------------------------------------------------------
-- V. the crate, the title, the glitch
-------------------------------------------------------------------------------------------------------------
local function crateScene(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	IntroUi.hush()
	local mid = P.cast + P.fwd * 2.5 -- (between the party, P.cast - fwd * 2, and the Mayor's grass)
	local closeTitle: ((number) -> ())? = nil
	for _, actor in actors do
		actor.look(mid + UP * 2)
	end
	m.look(mid + UP * 2)
	Film.at(0.35, function()
		if not playing then
			return
		end
		FilmAudio.sfx("whoosh", { volume = 1, pitch = 0.55 })
		-- (the music drops out just before it lands: silence, then the hit)
		task.delay(0.38, function()
			if playing then
				FilmAudio.duck(1, 0.1)
			end
		end)
		local crateModel: Model? = nil
		crateModel = IntroCast.crate(mid, -P.fwd, function()
			if not playing then
				return
			end
			Film.shake(0.75, 1.1)
			Film.speed(0.25, 0)
			task.delay(0.55, function()
				Film.speed(1, 0.5)
			end)
			Film.punch(12)
			-- [an impact frame] the crate and the party: black on white, then on orange (not the Mayor: a voxel
			-- sculpture of thousands of blocks is too many to copy in the blink of a hit)
			local subjects: { Instance? } = { crateModel }
			for _, actor in actors do
				table.insert(subjects, actor.model)
			end
			FilmPanels.impact(subjects, { at = IntroCast.ground(mid) + UP * 2, invert = true })
			task.delay(0.3, function()
				if playing then
					FilmAudio.duck(0, 0.6)
				end
			end)
			-- (one solid hit, not a pile of them: stacked hits got too loud)
			FilmAudio.sfx("crate", { volume = 0.9 })
			FilmAudio.sfx("impact", { volume = 0.6 })
			local g = IntroCast.ground(mid)
			-- (VFX Forge's landing: dust, turf, wood bits, coins; the old dust puffs if it's missing)
			if not FilmVfx.play("CrateLand", CFrame.lookAt(g, g - P.fwd)) then
				for i = 1, 5 do
					local a = i / 5 * math.pi * 2
					HitFx.play("bossRise", g + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.6, Color3.fromRGB(150, 118, 80), false)
				end
			end
			-- the blast blows the Mayor's hat clean off; it spins... and lands back on his head. THEN he cheers
			m.hatPop(2.8)
			m.act("shock")
			m.mood("surprised")
			task.delay(0.95, function()
				if playing and mayor == m then
					m.act("cheer")
					m.mood("happy")
					m.hop(0.5)
				end
			end)
			for _, actor in actors do
				actor.play("cheer")
			end
		end, function()
			-- the title lands once the crate has burst open (owner 27 Oct: the crate's reveal was hidden under it)
			if not playing then
				return
			end
			closeTitle = IntroUi.title(P.areaName:upper(), Config.GAME_NAME:upper(), "Mow it ALL to open the next area!")
			FilmAudio.sfx("titleHit", { volume = 0.7 })
			FilmVfx.play("TitleHit", CFrame.new(), { screen = 12 }) -- (VFX Forge: a burst behind the letters)
		end)
	end)
	local look = mid + UP * 2.5
	-- (29 Oct, the contact sheet: from the side, level with the party, the nearest Mower's back filled the picture.
	-- Now in front of them and off to one side (only the side turns, so it never swings round behind them), clear of
	-- the Mayor's tall grass)
	local crateYaw = freeYaw(function(y)
		local r = turn(P.right, y)
		return { mid + r * 12 + P.fwd * 8 + UP * 5, mid + r * 9.5 + P.fwd * 7 + UP * 6.5 }
	end, function()
		return look
	end, { 0, 180, 15, -15, 165, -165, 30, -30 })
	local cr = turn(P.right, crateYaw)
	local ok = Film.run(4.6, function(k)
		local p = mid + cr * (12 - k * 2.5) + P.fwd * (8 - k) + UP * (5 + k * 1.5)
		return Film.look(p, look), Film.mm(30), look
	end, { hand = 0.3 })
	if closeTitle then
		closeTitle(0.3)
	end
	return ok
end

-- The top of the tallest of the meadow's grass clumps (`grass`: its folder) within `radius` studs (sideways) of
-- `at`. (The clumps can't be hit by a raycast, so the camera checks can't see them.)
local function grassTop(grass: Instance?, at: Vector3, radius: number): number
	local top = -math.huge
	if grass then
		for _, d in grass:GetDescendants() do
			if d:IsA("Model") and d.Name == "Clump" and flat(d:GetPivot().Position - at).Magnitude < radius then
				local cf, size = d:GetBoundingBox()
				top = math.max(top, cf.Position.Y + size.Y / 2)
			end
		end
	end
	return top
end

-- The peek's camera, turned `yaw` degrees from straight out past the thick grass: back from it and up over the
-- clumps (12-14 studs tall: in among them, Studio's test on 28 Oct saw nothing but green).
local function peekFrom(P: Plan, yaw: number, grass: Instance?): Vector3
	local f = P.thick - turn(P.dirK, yaw) * 14
	return Vector3.new(f.X, math.max(f.Y + 9, grassTop(grass, f, 16) + 3), f.Z)
end

-- What the peek's camera has to clear: the boxes of the grass, the scenery, the hub and the ground near the thick grass
-- (CanQuery is off on most of them, so a raycast can't see them). Thousands of parts: spread over a few frames.
local function peekBoxes(P: Plan): { { p: Vector3, top: number, r: number } }
	local boxes: { { p: Vector3, top: number, r: number } } = {}
	local world = workspace:FindFirstChild("World")
	local n = 0
	for _, name in { "Grass", "Visuals", "Hub", "Ground" } do
		local f = world and world:FindFirstChild(name)
		if f then
			for _, d in f:GetDescendants() do
				n += 1
				if n % 1500 == 0 then
					task.wait()
				end
				if d:IsA("BasePart") and d.Transparency < 0.95 and d.Size.Magnitude > 4 and flat(d.Position - P.thick).Magnitude < 300 then
					local cf, s = d.CFrame, d.Size
					local halfY = 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
					table.insert(boxes, { p = d.Position, top = d.Position.Y + halfY, r = 0.5 * math.sqrt(s.X * s.X + s.Z * s.Z) })
				end
			end
		end
	end
	return boxes
end

-- A sneak peek of world 2 (owner, 27 Oct: "have this boss sneak peek in the first cutscene"): the picture glitches
-- and far beyond the meadow the sky tears open again; in the dark of the tear an eye opens (the glitch demon's, as in
-- the ending's black hole: client/GlitchHole) and looks straight at us... then it all snaps back. (The council, 28
-- Oct: give the glitch a face and a sound, so on a phone it can't look like lag.)
local function peekScene(P: Plan): boolean
	FilmAudio.glitch(0.8)
	Glitch.burst(0.9, 0.35)
	Film.shake(0.35, 2)
	FilmAudio.sfx("demonSwell", { volume = 1 })
	local t0 = os.clock()
	local boxes = peekBoxes(P) -- (under the glitch, in place of part of its quarter second)
	Film.wait(math.max(0.25 - (os.clock() - t0), 0.03))
	if not playing then
		Glitch.clear()
		return false
	end
	-- (owner, 28 Oct: "fix its framing, it's still off": it was dark, leaves sat at the frame's edge and the tear was off
	-- to the side) The camera first: over the clumps, with nothing solid out toward the frame's corners; then the tear
	-- straight ahead of it, about 20 degrees up in clear sky, framed whole (two thirds of the picture's height) with the
	-- eye in the middle of the picture.
	local grass = workspace:FindFirstChild("Grass1", true)
	-- (29 Oct, Studio: a clump and a meadow tree still filled the picture. The clumps and the scenery can't be hit by a
	-- raycast (CanQuery is off on them), so the camera checks their boxes (peekBoxes): for each way out it rises until it
	-- is over everything in front of it out to 230 studs (the picture's bottom edge is above level), and the way that
	-- needs the least climb wins.)
	local SPREAD = math.tan(math.rad(34)) -- (half the picture's width, and a little more)
	local best: { from: Vector3, far: Vector3 }?, bestLift = nil, math.huge
	for _, y in { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } do
		local dir = turn(P.dirK, y)
		local at = peekFrom(P, y, grass)
		local need = at.Y
		for _, b in boxes do
			local v = flat(b.p - at)
			local ahead = v:Dot(dir)
			local side = (v - dir * ahead).Magnitude
			if v.Magnitude < b.r + 2 then
				need = math.max(need, b.top + 3) -- (right over it)
			elseif ahead > -b.r and ahead < 230 and side - b.r < math.max(ahead, 0) * SPREAD then
				need = math.max(need, b.top + 2)
			end
		end
		local lift = need - at.Y
		if lift < bestLift - 0.5 then
			local from = at + UP * lift
			best, bestLift = { from = from, far = from + dir * 165 + UP * 62 }, lift
		end
	end
	local shot = best :: { from: Vector3, far: Vector3 }
	local from, far = shot.from, shot.far
	local toCam = unit(from - far, -P.dirK)
	local TALL = 70
	-- (two thirds of what shows between the letterbox bars, which cover about a quarter of the picture)
	local fov = math.deg(2 * math.atan(TALL / 0.5 / 2 / (far - from).Magnitude))
	local C = Corruption.new(far)
	-- (VFX Forge's tear; the old one if the template or the module is missing)
	local tear = FilmVfx.play("SkyTear", CFrame.lookAt(far, far + toCam), { scale = TALL / 40 })
	if not tear then
		C.rift(far, toCam, TALL, 0.3)
	end
	local folder = workspace:FindFirstChild("IntroSet") or workspace
	local eye = GlitchHole.eyeProp(folder)
	-- the dark the eye opens in (the tear torn wide round it)
	local dark = Instance.new("Part")
	dark.Name = "PeekDark"
	dark.Anchored = true
	dark.CanCollide = false
	dark.CanQuery = false
	dark.CanTouch = false
	dark.CastShadow = false
	dark.Material = Enum.Material.Neon
	dark.Color = Color3.new(0, 0, 0)
	dark.Transparency = 1
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = dark
	dark.Parent = folder
	local ungrade = Glitch.grade({ Brightness = -0.2, Contrast = 0.45, Saturation = -0.65, TintColor = Color3.fromRGB(222, 214, 255) }, 0.12)
	Glitch.static(0.3, 1.6)
	local caption = Glitch.text(nil, "...something is watching", UDim2.fromScale(0.42, 0.045), UDim2.fromScale(0.5, 0.8), Color3.fromRGB(255, 150, 200))
	local opened = false
	local ok = Film.run(1.9, function(k)
		local open = math.clamp((k - 0.22) / 0.18, 0, 1)
		if open > 0 and not opened then
			opened = true
			FilmAudio.sfx("growl2", { volume = 0.8, pitch = 0.8 })
			FilmAudio.sfx("sting", { volume = 0.6, pitch = 0.9 })
			FilmVfx.play("EyeOpen", CFrame.lookAt(far + toCam * 2.6, far + toCam * 10)) -- (VFX Forge: its glint)
		end
		-- (it glares, then narrows)
		local o = open * (1 - 0.35 * math.clamp((k - 0.75) / 0.25, 0, 1))
		eye.place(far + toCam * 2, toCam, 16, o)
		dark.Transparency = if o > 0.02 then 0 else 1
		dark.Size = Vector3.new(27, 15 * o + 0.05, 0.2)
		dark.CFrame = CFrame.lookAt(far + toCam * 1.4, far + toCam * 3)
		return Film.look(from, far), fov - k * 4, far
	end, { hand = 0.2 })
	caption.stop()
	eye.destroy()
	dark:Destroy()
	C.destroy()
	FilmVfx.stop(tear)
	if not ok or not playing then
		ungrade(0)
		Glitch.clear()
		return false
	end
	Glitch.burst(1, 0.3)
	FilmAudio.glitch(1)
	ungrade(0.15)
	Film.wait(0.2)
	Glitch.clear()
	return playing
end

-- Dip to black and land in your own eyes.
local function homeScene(): boolean
	IntroUi.fade(0, 0.3)
	if not Film.wait(0.32) then
		return false
	end
	IntroCast.clearSet() -- (the characters stay hidden until the end, so your own head isn't in the shot)
	mayor = nil
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return playing
	end
	local look = root.CFrame.LookVector
	local eye = head.Position
	local final = CFrame.lookAt(eye, eye + look)
	Film.grade("none", 0.6)
	Film.vignette(0, 0.6)
	IntroUi.letterbox(false, 0.8)
	IntroUi.fade(1, 0.6)
	return Film.run(1.1, function(k)
		local e = out(k)
		local p = (eye - look * 9 + UP * 4):Lerp(eye, e)
		return CFrame.lookAt(p, eye + look * 20):Lerp(final, e), 70, nil
	end, { hand = 0 })
end

-------------------------------------------------------------------------------------------------------------
-- start and end
-------------------------------------------------------------------------------------------------------------
local savedHud = true
local startedAt = 0 -- (when this showing told the server it started)

local function finish()
	if not playing then
		return
	end
	playing = false
	Film.stop(STEP)
	FilmVoice.clear()
	Babble.stop()
	FilmAudio.finish(1.2)
	Glitch.clear()
	if bossShown then
		bossShown = false
		BossView.hide()
	end
	clearFx()
	overgrown = nil
	IntroCast.cleanup()
	IntroUi.close()
	mayor = nil
	pcall(function()
		local c = getControls()
		if c then
			c:Enable()
		end
	end)
	UI.gui.Enabled = savedHud
	if not previewing then
		-- (the server's "Seen" takes one a second: a very quick SKIP waits a moment so it isn't dropped, or the run
		-- clock would stay held for you)
		task.delay(math.max(0, 1.1 - (os.clock() - startedAt)), function()
			State.fire("Seen", "intro")
		end)
	end
	previewing = false
	startAt = nil
end

local function film()
	local P = plan()
	-- the party lines up a little back from the camp's middle (the crate lands in front of them, the Mayor's grass
	-- beyond it)
	local centre = P.cast - P.fwd * 2
	local actors = IntroCast.party(centre, P.fwd, P.right)
	local m = IntroCast.mayor(P.mayorAt, flat(P.thick - P.mayorAt))
	mayor = m
	Film.refreshSight()
	Film.every(function(dt: number)
		m.update(dt)
		local s = Film.scale()
		for _, actor in actors do
			actor.update(dt, s)
		end
	end)
	IntroCast.hideCharacters(true)
	IntroUi.letterbox(true, 0.8)
	-- (client/BossView shows one boss at a time; if a fight's boss is in it, e.g. a rejoin mid-fight, the film's
	-- guardians stay out of it)
	bossesOk = BossView.get() == nil
	FilmPanels.reset()
	local kingFeet = kingSpot(P)
	if startAt == "glitch" then
		-- (the DEV panel's OPENING: CLASH starts here)
		IntroCast.hideGrass(true)
		IntroUi.fade(1, 0.6)
		Film.grade("hero", 0)
	elseif not peaceScene(P, m, kingFeet) then
		return
	end
	if not tearScene(P, m, kingFeet) or not eyesScene(P, kingFeet) or not othersScene(P, kingFeet) then
		return
	end
	if not blowScene(P, kingFeet) or not swallowScene(P, m, kingFeet) or not callScene(P, m, kingFeet) then
		return
	end
	if not dropScene(P, actors) or not lineupScene(P, m, actors, centre) or not pleaScene(P, m, actors, kingFeet) then
		return
	end
	if not crateScene(P, m, actors) then
		return
	end
	if Config.WORLD2.peek then
		if heroCue then
			heroCue.tapeStop(0.7)
		end
		if not peekScene(P) then
			return
		end
	end
	homeScene()
end

local function play()
	local cam = workspace.CurrentCamera
	if playing or played or not cam then
		return
	end
	played = true
	playing = true
	generation += 1
	local mine = generation
	if not previewing then
		-- your run clock waits while you watch (server/Run: once a run, never more than the film's length)
		startedAt = os.clock()
		State.fire("Seen", "introStart")
	end
	savedHud = UI.gui.Enabled
	UI.gui.Enabled = false
	IntroUi.open(finish)
	pcall(function()
		local c = getControls()
		if c then
			c:Disable()
		end
	end)
	task.delay(TIMEOUT, function()
		-- (only this showing's timeout: a replay from the DEV panel isn't cut short by an older one)
		if generation == mine and workspace:GetAttribute("IntroTestSpeed") == nil then
			finish()
		end
	end)
	-- the black cover is up: the Mayor's voice starts being made, the sounds load, the far places stream in
	local lines = {}
	for _, k in ORDER do
		table.insert(lines, { text = LINES[k], who = "mayor" })
	end
	FilmVoice.prepare(lines)
	Babble.prepare()
	FilmAudio.begin({ "storyMusic", "darkMusic", "heroMusic", "impact", "rumble", "leaves", "brush", "crate", "bigHit", "titleHit", "swipe", "swipe2", "sting", "demonSwell", "growl", "growl2", "thud", "synthWhomp", "suck", "whomp", "riseDark" })
	-- (the guardians' models and textures for the King and the roll call)
	-- (30 Oct, owner: "de bosses spawnen niet goed in of laden niet goed in de trailer en komen later pas": the film
	-- didn't wait for them, so on a fresh client the King's meshes and paint were still downloading when his shots
	-- came up, and he popped in late. The black cover now waits for the King (his shots come first), at most 8 s; the
	-- other guardians load right behind him, before their shots ~5 s later.)
	local kingReady = false
	task.spawn(function()
		local models = ReplicatedStorage:FindFirstChild("BossModels")
		local king = models and models:FindFirstChild(BossMoves.get(1).rig)
		if king then
			pcall(function()
				ContentProvider:PreloadAsync({ king })
			end)
		end
		kingReady = true
		if models then
			pcall(function()
				ContentProvider:PreloadAsync(models:GetChildren())
			end)
		end
	end)
	local entry = Config.zoneEntry(1)
	local hub = Config.zoneCentre(0)
	local inward = (Config.zoneCentre(1) - entry).Unit
	local w = workspace:FindFirstChild("World")
	local camp = w and w:GetAttribute("CampCenter")
	streamIn({ entry, entry + inward * 50, entry + inward * 110, if typeof(camp) == "Vector3" then camp else hub:Lerp(entry, 0.4) })
	if (Config.FILM :: any).voice ~= false then
		FilmVoice.waitFor(LINES.N1, 1.5)
	end
	local waitUntil = os.clock() + 8
	while not kingReady and playing and os.clock() < waitUntil do
		task.wait(0.05)
	end
	if not playing then
		return
	end
	Film.start(STEP)
	local ok, err = pcall(film)
	if not ok then
		warn("[Intro] " .. tostring(err))
	end
	finish()
end

local function maybePlay()
	local d = State.data
	-- (report #1, Config.FIRST_TIMER) a first-timer mows and sells first; the film plays after that first sale (the
	-- server clears run.tutorial a moment after it)
	if worldReady and State.isRun() and d and d.run and not d.run.introSeen and not d.run.tutorial and player.Character then
		task.spawn(play)
	end
end

State.on("world", function(w)
	if w.mode == "Run" and not w.loading then
		worldReady = true
		maybePlay()
	end
end)
State.on("data", maybePlay)

-- The DEV panel's PLAY OPENING: the opening film again, on this client only (the run's "seen it" isn't touched).
-- `from`: "glitch" starts at the sky tearing open (the clash), so the owner sees what changed without the rest.
function Intro.preview(from: string?)
	if playing then
		return
	end
	played = false
	previewing = true
	startAt = from
	task.spawn(play)
end

return Intro
