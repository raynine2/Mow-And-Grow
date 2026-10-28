-- The run's opening film (owner, 28 Oct: "remake it ... make it feel like a real movie with a story attached to
-- it"), the first time you're in a new run. Under a minute, told by Mayor Thistlewick (client/MayorRig). Remade
-- twice that day after the owner saw it ("show that grass grows", "show a boss when it mentions a boss"; then "it's
-- not his fault", "show it like JJK ... domain clash", "you don't have to show everything", "use impact frames")
-- and two LLM councils on it: whatever the story says happens, you see happen, and nothing is a list.
--   I.   ONCE UPON A TIME: a golden storybook memory of the valley before the grass came, mowed neat as a pin; the
--        Mayor proud on his soapbox, tipping his hat... the picture glitches; his eyes snap open, up at the sky;
--   II.  THE GLITCH: out in the meadow the gentle Dandelion King stands in the sun; above him the sky tears open in
--        pink and a spark drops out of it, straight into him [an impact frame]. The clash (client/FilmPanels): three
--        tall panels slam in, a guardian in each in its own colour (the King, and two of the others as shadows:
--        you meet them later), a pink fracture rips across them and every eye snaps pink. It isn't their fault;
--   III. THE SEEDS: the King, pink in his eyes, takes a huge breath and BLOWS his seeds over the valley. Seeds
--        drift down round the Mayor and the grass rises out of the soil, up and up, over his soapbox, up to his
--        moustache (a still, low, daylight shot); then the camera cranes up as the growth rolls out over the land;
--   IV.  PRESENT DAY: the Mayor alone, looking out at the wall of grass ("If only someone could help us...");
--        footsteps behind him;
--   V.   THE MOWERS: the party (copies of everyone's avatars) walks up in slow motion, the camera passes face by
--        face, the Mayor whirls round ("Mowers! At LAST!"), then points: "Mow it ALL... and set the guardians FREE!";
--   VI.  the supply crate slams down [an impact frame] (it blows his hat off), the title lands on the music's hit;
--        far beyond the meadow the sky tears again and an eye opens in the dark, looking at us; then you're in first
--        person, ready to go.
-- The Mayor talks in client/Babble's mumble (Config.FILM.babble; the text-to-speech voice is gone), the
-- narration is storybook text over the pictures; subtitles always. Camera, light and grade: client/Film; music
-- and sound: client/FilmAudio (licensed library audio only). SKIP ends it at any moment. Once it has played (or
-- been skipped) the server remembers it for this run ("Seen" remote), so it doesn't play again on a rejoin.
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

-- the story (N: storybook narration over the pictures) and the Mayor's lines (L), in this order. Short: the
-- pictures tell the rest.
local LINES = {
	N1 = "Once upon a time, our valley was the tidiest lawn in all the land.",
	N2 = "Every blade trimmed. Every hedge just so.",
	N3 = "Until the day something fell out of the sky...",
	N3b = "...and got into the valley's gentle guardians.",
	N4 = "...and the grass never stopped GROWING!",
	L1 = "If only someone could help us...",
	L2 = "Mowers! At LAST, you've come!",
	L4 = "Mow it ALL... and set the guardians FREE!",
}
local ORDER = { "N1", "N2", "N3", "N3b", "N4", "L1", "L2", "L4" }

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
		mayorAt = cast + fwd * 11,
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
}

-------------------------------------------------------------------------------------------------------------
-- I. ONCE UPON A TIME
-------------------------------------------------------------------------------------------------------------
local function pastScenes(P: Plan, m: IntroCast.Mayor): boolean
	IntroCast.hideGrass(true)
	Film.light(LOOKS.past, 0)
	Film.grade("story", 0)
	Film.glow(0.35, 30, 0.1)
	Film.vignette(0.65, 0)
	IntroUi.film(true)
	bed("ambBirds", 1.4, 2)
	local story = FilmAudio.music("storyMusic", { fade = 2.5, volume = 0.95 })
	FilmAudio.muffle(0.22, 0.1)
	IntroUi.fade(1, 1.6)
	local face = unit(flat(P.thick - P.mayorAt), P.fwd)
	local side = face:Cross(UP)
	m.act("proud")
	m.mood("happy")
	m.look(P.thick + UP * 6)
	-- 1A: high over the neat valley, sinking slowly toward the village
	Film.at(0.9, function()
		speak("N1", true)
	end)
	local a = P.thick + P.dirK * 34 + UP * 58 + side * 26
	local b = P.thick - P.dirK * 6 + UP * 30 + side * 10
	local target = P.cast:Lerp(P.mayorAt, 0.5) + UP * 2
	local ok = Film.run(5.0, function(k)
		local e = sine(k)
		local pos = a:Lerp(b, e)
		return Film.look(pos, target:Lerp(P.mayorAt + UP * 4, e)), Film.mm(24 + 6 * e), P.mayorAt
	end, { hand = 0.2 })
	if not ok then
		return false
	end
	-- 1B: the Mayor in his prime, proud on his soapbox, looking out over his lawn; he tips his hat to it
	Film.at(0.3, function()
		speak("N2", true)
	end)
	Film.at(2.1, function()
		m.act("tipHat")
		Film.at(1.3, function()
			m.act("proud")
		end)
	end)
	local head = m.face()
	local yaw = freeYaw(function(y)
		local d = turn(face, y)
		return { head + d * 9 + d:Cross(UP) * 3.5 - UP * 1.2 }
	end, function()
		return head
	end, { 30, -30, 55, -55, 10, -10 })
	local d0 = turn(face, yaw)
	local s0 = d0:Cross(UP)
	ok = Film.run(4.8, function(k)
		local e = inOut(k)
		local f = m.face()
		local pos = f + d0 * (10.5 - 2.6 * e) + s0 * 3.4 - UP * (1.6 - 0.5 * e)
		return Film.look(pos, f - UP * (1.1 - 0.5 * e)), Film.mm(40 + 10 * e), f
	end, { hand = 0.25 })
	if not ok then
		return false
	end
	-- 1C: close on his face, content... the picture glitches (the music stutters and dies); his eyes snap open, up
	m.closeEyes(true)
	Film.at(1.1, function()
		if story then
			story.tapeStop(0.9)
		end
		FilmAudio.glitch(0.7)
		Glitch.burst(0.5, 0.22)
		Film.freeze(0.12)
		FilmAudio.sfx("synthWhomp", { pitch = 0.6, volume = 0.8 })
		Film.shake(0.2, 1.4)
	end)
	Film.at(1.45, function()
		m.closeEyes(false)
		m.mood("surprised")
		m.act("shock")
		m.look(P.thick + P.dirK * 30 + UP * 60)
	end)
	return Film.run(2.1, function(k, t)
		local f = m.face()
		local push = if t < 1.6 then 0 else out((t - 1.6) / 0.5) * 0.9
		local pos = f + d0 * (4.8 - push) + s0 * 0.9 + UP * 0.1
		return Film.look(pos, f + UP * 0.05), Film.mm(85), f
	end, { hand = 0.15 })
end

-------------------------------------------------------------------------------------------------------------
-- II. THE GLITCH and III. THE SEEDS (owner, 28 Oct: "show that grass grows", "show a boss when it mentions a
-- boss", then "it's not his fault", "show it like JJK ... domain clash"; the councils: the grass needs a cause you
-- can see, growing only reads in daylight with the camera still, the cause is the pink: show it arrive)
-------------------------------------------------------------------------------------------------------------
local fxParts: { Instance } = {} -- the seed clouds, the spark and the King's eye glints (in the set: they go with it)
local fxStops: { () -> () } = {} -- their per-frame updates
local overgrown: ((number) -> ())? = nil -- sinks the film-only tall grass round the soapbox
local bossShown = false -- (this film showed a boss model: client/BossView is the fights' too)
local bossesOk = true -- (false when a fight's boss is in client/BossView as the film starts: it's left alone)
local corrupt: Corruption.Handle? = nil -- the tear in the sky
local clash: FilmPanels.Clash? = nil

local function clearFx()
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
	e.Texture = FxIds.seed or "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 248, 222))
	e.LightEmission = 0.15
	local s = o.scale or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 0.45 * s) })
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

-- The King's eyes burn the demon's pink from now on (glowing balls on his eye points, every frame).
local function pinkEyes(H: number)
	local names = BossView.attAll("att_eye")
	local glints: { BasePart } = {}
	for i in names do
		local g = setPart("DemonGlint", Vector3.one * math.max(0.7, H * 0.045), CFrame.new())
		g.Shape = Enum.PartType.Ball
		g.Material = Enum.Material.Neon
		g.Color = FilmPanels.PINK
		g.Transparency = 0
		if i == 1 then
			local l = Instance.new("PointLight")
			l.Color = FilmPanels.PINK
			l.Range = H * 0.6
			l.Brightness = 3
			l.Shadows = false
			l.Parent = g
		end
		table.insert(glints, g)
	end
	table.insert(fxStops, Film.every(function()
		for i, name in names do
			local at = BossView.attWorld(name)
			if at and glints[i] then
				glints[i].CFrame = CFrame.new(at)
			end
		end
	end))
end

-- the low shot of him from the camp side: a turn that's clear of the camp's houses and trees
local function kingYaw(kingFeet: Vector3, toCamp: Vector3, H: number): Vector3
	local yaw = freeYaw(function(y)
		return { kingFeet + turn(toCamp, y) * (H * 1.6) + UP * 2.4 }
	end, function()
		return kingFeet + UP * (H * 0.9)
	end, { 0, 15, -15, 30, -30, 45, -45 })
	return turn(toCamp, yaw)
end

-- 2A: out in the meadow the gentle Dandelion King stands in the sun (low on the camp side, looking up past him at
-- the sky); above him the sky tears open in pink and a spark drops out of it, straight into him [an impact frame]:
-- he staggers and changes (client/BossView's rage, carrying on under the clash). Returns where he stands.
local function glitchScene(P: Plan, m: IntroCast.Mayor): (boolean, Vector3)
	local moves = BossMoves.get(1)
	local H = moves.height
	local toCamp = -P.dirK
	local kingFeet = IntroCast.ground(P.thick + P.dirK * 30)
	IntroUi.film(false)
	Film.flash(Color3.new(1, 1, 1), 0.35, 0.3)
	Film.grade("hero", 0.5)
	Film.glow(0.15, 24, 0.6)
	Film.vignette(0.45, 0.6)
	Film.light(LOOKS.day, 0.6)
	FilmAudio.muffle(0, 0.2)
	bed("ambWind", 1.4, 1.5)
	m.look(kingFeet + UP * H * 0.7)
	if bossesOk then
		showBoss(1, kingFeet, toCamp)
		BossView.critters("intro", 2)
	end
	local d0 = kingYaw(kingFeet, toCamp, H)
	local camAt = IntroCast.ground(kingFeet + d0 * (H * 1.6)) + UP * 2.4
	local head = kingFeet + UP * (H * 0.8)
	local sky = kingFeet - d0 * (H * 0.7) + UP * (H * 3.1)
	local C = Corruption.new(kingFeet)
	corrupt = C
	Film.at(0.35, function()
		speak("N3", true)
	end)
	Film.at(0.7, function()
		C.rift(sky, d0, H * 1.5, 0.45)
		FilmAudio.glitch(0.6)
		Glitch.burst(0.4, 0.18)
		FilmAudio.sfx("synthWhomp", { volume = 0.7, pitch = 0.5 })
	end)
	-- the spark: out of the tear, falling faster and faster, a pink streak behind it
	local spark = setPart("Spark", Vector3.one * math.max(1.2, H * 0.06), CFrame.new(sky))
	spark.Shape = Enum.PartType.Ball
	spark.Material = Enum.Material.Neon
	spark.Color = FilmPanels.PINK
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, 0)
	a0.Parent = spark
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.5, 0)
	a1.Parent = spark
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 214, 240), FilmPanels.PINK)
	trail.LightEmission = 1
	trail.Lifetime = 0.35
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Enabled = false
	trail.Parent = spark
	local glow = Instance.new("PointLight")
	glow.Color = FilmPanels.PINK
	glow.Range = 18
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = spark
	local FALL_AT, HIT_AT = 1.45, 2.65
	local t0 = Film.now()
	local hit = false
	table.insert(fxStops, Film.every(function(_: number, now: number)
		local t = now - t0
		if hit or t < FALL_AT then
			return
		end
		local k = math.clamp((t - FALL_AT) / (HIT_AT - FALL_AT), 0, 1)
		spark.Transparency = 0
		trail.Enabled = true
		glow.Brightness = 5
		local aim = if bossesOk then BossView.attWorld("att_head_center") or head else head
		spark.CFrame = CFrame.new(sky:Lerp(aim, k * k))
	end))
	-- a build... a moment of silence... then the hit
	Film.at(0.7, function()
		FilmAudio.riser("riseDark", HIT_AT - 0.3 - 0.7, { volume = 0.6 })
	end)
	Film.at(HIT_AT - 0.3, function()
		FilmAudio.duck(1, 0.12)
	end)
	Film.at(HIT_AT, function()
		hit = true
		spark.Transparency = 1
		trail.Enabled = false
		glow.Brightness = 0
		FilmAudio.sfx("impact", { volume = 0.95, pitch = 0.8 })
		FilmAudio.sfx("synthWhomp", { volume = 0.8, pitch = 0.45 })
		FilmPanels.impact(if bossesOk then { bossModel() } else {}, { at = head })
		Film.shake(0.55, 1.4)
		if bossesOk then
			-- the pink gets in: he staggers, kneels and changes, while the clash plays
			BossView.act("rage")
			pinkEyes(H)
		end
		task.delay(0.4, function()
			if playing then
				FilmAudio.duck(0, 0.4)
			end
		end)
	end)
	local ok = Film.run(HIT_AT + 0.3, function(k, t)
		-- up at the tear, then down with the spark onto him
		local e = Film.smooth((t - FALL_AT) / (HIT_AT - FALL_AT))
		local look = (sky - UP * (H * 0.6)):Lerp(head + UP * (H * 0.25), e)
		return Film.look(camAt - d0 * (k * 1.2), look), Film.mm(20 + 4 * e), look
	end, { hand = 0.3 })
	return ok, kingFeet
end

-- 2B: the clash (owner: "show it like JJK Yuta domain clash", "you don't have to show everything"). Three tall
-- panels slam in, a guardian in each in its own colour: the King in the middle, two of the others either side as
-- shadows (a different two each run: you meet them in their own lands); a pink fracture rips across them and every
-- eye snaps pink.
local function clashScene(): boolean
	local left = math.random(2, 4)
	local right = math.random(5, math.max(5, #Config.ZONES))
	local c = FilmPanels.clash({ { z = left, silhouette = true }, { z = 1 }, { z = right, silhouette = true } })
	if not c then
		return true
	end
	clash = c
	IntroUi.hush()
	table.insert(fxStops, Film.every(c.update))
	local function slamSound(pitch: number)
		FilmAudio.sfx("slam", { volume = 0.6, pitch = pitch })
		FilmAudio.sfx("whomp", { volume = 0.5, pitch = pitch * 0.9 })
	end
	Film.at(0.1, function()
		c.slam(1)
		slamSound(0.95)
	end)
	Film.at(0.55, function()
		c.slam(3)
		slamSound(0.85)
	end)
	Film.at(1.0, function()
		c.slam(2)
		FilmAudio.sfx("impact", { volume = 0.7, pitch = 1.05 })
	end)
	Film.at(1.15, function()
		speak("N3b", true)
	end)
	Film.at(1.85, function()
		c.corrupt()
		FilmAudio.glitch(1)
		Glitch.burst(0.55, 0.22)
		FilmAudio.sfx("demonSwell", { volume = 0.75 })
	end)
	Film.at(2.35, function()
		FilmAudio.duck(1, 0.08)
	end)
	Film.at(2.55, function()
		c.snap()
		FilmAudio.sfx("bigHit", { volume = 0.75, pitch = 0.8 })
		FilmAudio.sfx("growl2", { volume = 0.6, pitch = 0.75 })
		task.delay(0.3, function()
			if playing then
				FilmAudio.duck(0, 0.5)
			end
		end)
	end)
	Film.at(3.75, function()
		c.out(0.35)
		FilmAudio.sfx("swipe", { volume = 0.9, pitch = 0.8 })
	end)
	-- (behind the panels the camera holds still: none of the world shows until they fly off)
	local hold = Film.lastFrame()
	local ok = Film.run(4.1, function()
		return hold, Film.mm(24), nil
	end, { hand = 0 })
	clash = nil
	return ok
end

-- 2C: back in the meadow the King, changed, the pink burning in his eyes, fills up with a huge breath... and BLOWS
-- his seeds over the valley.
local function kingScenes(P: Plan, m: IntroCast.Mayor, kingFeet: Vector3): boolean
	local moves = BossMoves.get(1)
	local H = moves.height
	local toCamp = -P.dirK
	darkCue = FilmAudio.music("darkMusic", { fade = 0.4 })
	m.look(kingFeet + UP * H * 0.7)
	if not bossesOk then
		return true -- (a fight is on: straight to the growing)
	end
	local d0 = kingYaw(kingFeet, toCamp, H)
	BossView.critters("intro", 3)
	Film.at(0.1, function()
		BossView.act("blow", { land = 0.9, hold = 1.4 })
		local inhale = FilmAudio.sfx("suck", { volume = 0.55, pitch = 1.3 })
		task.delay(0.9, function()
			FilmAudio.fadeOut(inhale, 0.15)
		end)
	end)
	local mouth0 = BossView.attWorld("att_head_center") or (kingFeet + UP * H * 0.8)
	local feet = IntroCast.ground(P.mayorAt)
	local light = PhonePerf.on or Potato.on -- (fewer seeds on phones)
	Film.at(1.0, function()
		local mouth = BossView.attWorld("att_head_center") or mouth0
		local aim = unit((feet + UP * 6) - mouth, toCamp)
		local burst = seedCloud(CFrame.lookAt(mouth, mouth + aim), Vector3.new(H * 0.22, H * 0.22, 1), { rate = if light then 300 else 520, speed = NumberRange.new(30, 55), spread = Vector2.new(26, 16), life = NumberRange.new(2.6, 4), scale = 2.2 })
		task.delay(1.1, function()
			burst.Rate = 40
		end)
		-- the seeds already coming down over the Mayor, for the next shot
		seedCloud(CFrame.new(feet + UP * 15 + P.dirK * 3), Vector3.new(40, 1, 40), { rate = if light then 50 else 90, speed = NumberRange.new(3, 6), spread = Vector2.new(25, 25), life = NumberRange.new(4, 6), face = Enum.NormalId.Bottom, scale = 1.5 })
		FilmAudio.sfx("swipe", { volume = 1.1, pitch = 0.5 })
		leavesSound = FilmAudio.sfx("leaves", { volume = 1 }) -- (faded out when "present day" starts)
		Film.shake(0.35, 1.2)
	end)
	local side = d0:Cross(UP)
	local camB = mouth0 + d0 * (H * 0.55) - UP * (H * 0.12) + side * (H * 0.12)
	return Film.run(2.8, function(k)
		local head = BossView.attWorld("att_head_center") or mouth0
		return Film.look(camB + d0 * (k * 1.5), head), Film.mm(40), head
	end, { hand = 0.3 })
end

-- 2C: the seeds drift down round the Mayor... and the grass rises out of the soil, over his soapbox, up to his
-- moustache: a still, low shot in plain daylight (the council: growth only reads when it swallows something of a
-- size you know). He looks round at us and blinks. 2D: the camera cranes up as the growth rolls on to the horizon.
local function growScenes(P: Plan, m: IntroCast.Mayor, kingFeet: Vector3): boolean
	local light = PhonePerf.on or Potato.on
	local feet = IntroCast.ground(P.mayorAt)
	local toKing = unit(flat(kingFeet - feet), P.dirK)
	m.act("shock")
	m.mood("scared")
	m.look(feet + UP * 16 + toKing * 5)
	-- the shot: from his side, low (knees), far enough back for the box, him and his hat; clear of the houses
	local yaw = freeYaw(function(y)
		return { feet + turn(toKing:Cross(UP), y) * 12 + UP * 1.8 }
	end, function()
		return feet + UP * 3.6
	end, { 0, 20, -20, 40, -40, 180, 160, -160, 60, -60, 140, -140 })
	local d = turn(toKing:Cross(UP), yaw)
	local camAt = feet + d * 12 + UP * 1.8
	local look = feet + UP * 3.6
	local rustle: Sound? = nil
	Film.at(0.6, function()
		-- the real meadow, from his feet out to the horizon (the clumps behind him, in the shot, rise out of the soil) ...
		IntroCast.sproutGrass(feet, feet - d * 14, 6.5, nil, if light then 70 else 150)
		-- ... and the tall grass that swallows him
		overgrown = IntroCast.overgrow(feet, 6.5, 7, if light then 18 else 30, 2.8, 1.9)
		rustle = FilmAudio.sfx("leaves", { volume = 1.3 })
		for i = 0, 5 do
			Film.at(i * 0.4, function()
				FilmAudio.sfx("brush", { volume = 0.7 + i * 0.1, pitch = 0.8 + i * 0.05 })
			end)
		end
	end)
	Film.at(1.1, function()
		m.look(feet + toKing * 3)
		m.act("cower")
	end)
	Film.at(2.0, function()
		speak("N4", true)
	end)
	Film.at(2.4, function()
		m.act("shock")
	end)
	Film.at(3.4, function()
		FilmAudio.sfx("whomp", { volume = 0.7, pitch = 0.8 })
		FilmAudio.fadeOut(rustle, 1.2)
	end)
	Film.at(3.7, function()
		-- swallowed up to his moustache: he looks round at us. Blink. Blink.
		m.act("idle")
		m.mood("neutral")
		m.look(camAt)
		for _, t in { 0.5, 0.75 } do
			Film.at(t, function()
				m.closeEyes(true)
				Film.at(0.1, function()
					m.closeEyes(false)
				end)
			end)
		end
	end)
	local ok = Film.run(5.0, function(k)
		local fov = Film.mm(28 + 4 * Film.smooth(k))
		return CFrame.lookAt(camAt, look), fov, look
	end, { hand = 0.04 })
	if not ok then
		return false
	end
	-- 2D: up and back over the land, the growth rolling on to the horizon
	local craneYaw = freeYaw(function(y)
		return { P.thick - turn(P.dirK, y) * 34 + UP * 38 }
	end, function()
		return P.thick + UP * 20
	end, { 0, 15, -15, 30, -30, 45, -45 })
	local top = P.thick - turn(P.dirK, craneYaw) * 34 + UP * 38
	local far = P.thick + turn(P.dirK, craneYaw) * 40
	Film.at(1.2, function()
		IntroUi.caption("Present day", 3.2)
	end)
	return Film.run(2.8, function(k)
		local e = inOut(k)
		local p = camAt:Lerp(top, e)
		local at = look:Lerp(far, e)
		return Film.look(p, at), Film.mm(28 - 6 * e), far
	end, { hand = 0.45 })
end

-------------------------------------------------------------------------------------------------------------
-- III. PRESENT DAY: the Mayor, alone
-------------------------------------------------------------------------------------------------------------
local function worryScenes(P: Plan, m: IntroCast.Mayor): boolean
	if darkCue then
		darkCue.stop(2)
		darkCue = nil
	end
	FilmAudio.fadeOut(leavesSound, 1.5)
	leavesSound = nil
	-- (years later: the King is back in his own land, the seeds have settled, the camp is cleared round the Mayor)
	if bossShown then
		BossView.hide()
	end
	clearFx()
	if overgrown then
		overgrown(0.01)
		overgrown = nil
	end
	m.mood("neutral")
	Film.light(LOOKS.now, 0)
	Film.grade("gloom", 0)
	Film.vignette(0.5, 0)
	local lonely = FilmAudio.music("lonelyMusic", { fade = 2.5 })
	local face = unit(flat(P.thick - P.mayorAt), P.fwd)
	m.act("lookOut")
	m.mood("sad")
	m.look(P.thick + UP * 4)
	-- 3A: over his shoulder, out at the wall of grass
	Film.at(1.2, function()
		m.act("sigh")
		speak("L1", false, true)
	end)
	local head = m.face()
	local yaw = freeYaw(function(y)
		local d = turn(-face, y)
		return { head + d * 5.2 + d:Cross(UP) * 2.2 + UP * 0.4 }
	end, function()
		return head + face * 18
	end, { 35, -35, 20, -20, 55, -55 })
	local back = turn(-face, yaw)
	local side = back:Cross(UP)
	local ok = Film.run(3.9, function(k)
		local f = m.face()
		local pos = f + back * (5.6 - 1.2 * inOut(k)) + side * 2.0 + UP * 0.5
		return Film.look(pos, f + face * 18 - UP * 2), Film.mm(50), f + face * 30
	end, { hand = 0.3, far = 0.2 })
	if not ok then
		return false
	end
	-- 3B: his face in profile... footsteps behind him; his eyes flick round; he turns
	local footAt = P.cast - P.fwd * 12
	Film.at(1.1, function()
		for i = 0, 2 do
			Film.at(i * 0.45, function()
				FilmAudio.sfx("thud", { volume = 0.45 + i * 0.12, pitch = 0.85 + math.random() * 0.1 })
				FilmAudio.sfx("stepGrass", { volume = 1.4 })
			end)
		end
	end)
	Film.at(1.5, function()
		m.mood("surprised")
		m.look(footAt + UP * 4)
	end)
	Film.at(2.4, function()
		m.act("idle")
		m.turn(-P.fwd, 0.9)
		if lonely then
			lonely.stop(1.2)
		end
	end)
	return Film.run(3.0, function(k)
		local f = m.face()
		local pos = f + side * 4.4 + face * 1.6 + UP * 0.15
		return Film.look(pos, f), Film.mm(85), f
	end, { hand = 0.2 })
end

-------------------------------------------------------------------------------------------------------------
-- IV. THE MOWERS
-------------------------------------------------------------------------------------------------------------
-- How far back each actor can start its walk (nothing in the way at chest height).
local function walkFrom(spot: Vector3, back: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	local set = workspace:FindFirstChild("IntroSet")
	if set then
		table.insert(skip, set)
	end
	local w = workspace:FindFirstChild("World")
	local g = w and w:FindFirstChild("Grass")
	if g then
		table.insert(skip, g)
	end
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(skip, pl.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	local from = spot + UP * 2.5
	for _, dist in { 15, 11, 8, 5 } do
		if not workspace:Raycast(from, back * dist, params) then
			return spot + back * dist
		end
	end
	return spot + back * 3
end

local function heroScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	Film.light(LOOKS.hero, 0)
	Film.grade("hero", 0)
	Film.glow(0.22, 26, 0.4)
	Film.vignette(0.35, 0)
	heroCue = FilmAudio.music("heroMusic", { fade = 0.3 })
	bed("ambBirds", 1.0, 2)
	local n = #actors
	-- 4A: they walk up in slow motion, low and wide, the light behind them
	Film.speed(0.55, 0.35)
	local walkLen = 3.4
	for i, actor in actors do
		local spot = actor.spot.Position
		local from = walkFrom(spot, -P.fwd)
		Film.at((i - 1) * 0.12, function()
			actor.walk(from, walkLen - (i - 1) * 0.12, function()
				FilmAudio.sfx("stepGrass", { volume = 1.2, pitch = 0.75 })
				FilmAudio.sfx("thud", { volume = 0.25, pitch = 0.7 + math.random() * 0.1 })
			end)
		end)
	end
	Film.at(1.0, function()
		IntroUi.lowerThird("THE MOWERS", if n == 1 then "One mower. One valley." else n .. " mowers. One valley.", GOLD, 3.2)
	end)
	local ok = Film.run(walkLen, function(k)
		local pos = P.cast + P.fwd * (6.8 - 1.4 * k) + UP * (1.0 + 0.5 * k) + P.right * 0.8
		local look = P.cast - P.fwd * (4 - 3 * k) + UP * (3.0 + 0.6 * k)
		return Film.look(pos, look, -2 + k * 2), Film.mm(20 + 4 * k), P.cast - P.fwd * (3 - 3 * k) + UP * 3
	end, { hand = 0.35 })
	if not ok then
		return false
	end
	-- 4B: along the line, face by face; each one strikes a pose as the camera reaches them
	Film.speed(1, 0.4)
	for _, actor in actors do
		actor.look(m.face())
	end
	local first, last = actors[1] and actors[1].head, actors[n] and actors[n].head
	local headY = if first then first.Position.Y + 0.3 else P.cast.Y + 4.8
	local a = (if first then flat(first.Position) else flat(P.cast)) - P.right * 2.6
	local b = (if last then flat(last.Position) else flat(P.cast)) + P.right * 2.6
	local done = {}
	local len = math.clamp(1.05 * n + 1.6, 3.0, 5.2)
	ok = Film.run(len, function(k)
		local along = flat(a):Lerp(flat(b), inOut(k))
		local p = Vector3.new(along.X, headY, along.Z) + P.fwd * 7.6
		local look = Vector3.new(along.X, headY - 0.25, along.Z) - P.right * 0.4
		for i, actor in actors do
			local h = actor.head
			if h and not done[i] and (flat(h.Position) - along):Dot(P.right) < 1.6 then
				done[i] = true
				actor.look(nil)
				actor.play("emote")
				actor.tag()
				FilmAudio.sfx("rareChime", { volume = 0.35, pitch = 0.9 + i * 0.06 })
			end
		end
		return Film.look(p, look), Film.mm(45), look
	end, { hand = 0.3 })
	if not ok then
		return false
	end
	IntroCast.untag()
	-- 4C: whip round to the Mayor: delight
	FilmAudio.sfx("swipe", { volume = 0.9 })
	Film.blur(14)
	m.look(P.cast + UP * 3)
	m.mood("happy")
	Film.at(0.15, function()
		m.act("cheer")
		m.hop(0.55)
		speak("L2")
	end)
	return Film.run(2.6, function(k)
		local f = m.face()
		local pos = f - P.fwd * (5.2 - 0.8 * out(k)) + P.right * 1.3 - UP * 0.3
		return Film.look(pos, f - UP * 0.2), Film.mm(65), f
	end, { cut = "whip", hand = 0.3 })
end

-------------------------------------------------------------------------------------------------------------
-- V. THE PLEA: he whirls round and points at the grass: "Mow it ALL... and set the guardians FREE!" (the roll call of
-- all eight guardians that stood here is gone: owner, 28 Oct, "you don't have to show everything"; the clash
-- shows three, the rest wait in their own lands)
-------------------------------------------------------------------------------------------------------------
local function pleaScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	local toGrass = unit(flat(P.thick - P.mayorAt), P.fwd)
	m.turn(toGrass, 0.5)
	m.mood("stern")
	Film.at(0.25, function()
		m.act("point")
		m.look(P.thick + UP * 3)
		speak("L4")
	end)
	for _, actor in actors do
		actor.look(P.thick + UP * 3)
	end
	-- (owner, 28 Oct: a riser here came in loud and harsh under his line: the line and the music carry it now)
	return Film.run(4.4, function(k)
		local pos = P.cast - P.fwd * (6.2 - 1.6 * inOut(k)) + UP * (5.2 + 0.6 * k) + P.right * 3.0
		local look = P.mayorAt + UP * 5 + toGrass * 6 * k
		return Film.look(pos, look), Film.mm(26), P.mayorAt + UP * 5
	end, { hand = 0.4 })
end

-------------------------------------------------------------------------------------------------------------
-- VI. the crate, the title, the glitch
-------------------------------------------------------------------------------------------------------------
local function crateScene(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	IntroUi.hush()
	local mid = P.cast + P.fwd * 5.5
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
			FilmPanels.impact(subjects, { color = Color3.fromRGB(255, 150, 40), at = IntroCast.ground(mid) + UP * 2 })
			task.delay(0.3, function()
				if playing then
					FilmAudio.duck(0, 0.6)
				end
			end)
			-- (one solid hit, not a pile of them: stacked hits got too loud)
			FilmAudio.sfx("crate", { volume = 0.9 })
			FilmAudio.sfx("impact", { volume = 0.6 })
			local g = IntroCast.ground(mid)
			for i = 1, 5 do
				local a = i / 5 * math.pi * 2
				HitFx.play("bossRise", g + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.6, Color3.fromRGB(150, 118, 80), false)
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
		end)
	end)
	local look = mid + UP * 2.5
	local crateYaw = freeYaw(function(y)
		local r, f = turn(P.right, y), turn(P.fwd, y)
		return { mid + r * 19 - f * 4 + UP * 5, mid + r * 16 - f * 4 + UP * 6.5 }
	end, function()
		return look
	end, { 0, 180, 20, -20, 160, -160, 40, -40 })
	local cr, cf = turn(P.right, crateYaw), turn(P.fwd, crateYaw)
	local ok = Film.run(4.6, function(k)
		local p = mid + cr * (19 - k * 3) - cf * 4 + UP * (6.5 + k * 1.5)
		return Film.look(p, look), Film.mm(30), look
	end, { hand = 0.3 })
	if closeTitle then
		closeTitle(0.3)
	end
	return ok
end

-- The top of the tallest grass clump within `radius` studs (sideways) of `at`. (The clumps can't be hit by a
-- raycast, so the camera checks can't see them.)
local function grassTop(at: Vector3, radius: number): number
	local top = -math.huge
	local grass = workspace:FindFirstChild("Grass1", true)
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
local function peekFrom(P: Plan, yaw: number): Vector3
	local f = P.thick - turn(P.dirK, yaw) * 14
	return Vector3.new(f.X, math.max(f.Y + 9, grassTop(f, 16) + 3), f.Z)
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
	Film.wait(0.25)
	if not playing then
		Glitch.clear()
		return false
	end
	-- (the first turn with nothing solid between the camera and the tear, nor beside it in the frame)
	local yaw = freeYaw(function(y)
		return { peekFrom(P, y) }
	end, function(y)
		return P.thick + turn(P.dirK, y) * 150 + UP * 70
	end, { 0, 30, -30, 60, -60, 90, -90 }, 25)
	local dirK = turn(P.dirK, yaw)
	local from = peekFrom(P, yaw)
	local far = P.thick + dirK * 150 + UP * 70
	local toCam = unit(from - far, -dirK)
	local C = Corruption.new(far)
	C.rift(far, toCam, 70, 0.3)
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
	local ungrade = Glitch.grade({ Brightness = -0.32, Contrast = 0.55, Saturation = -0.65, TintColor = Color3.fromRGB(255, 118, 150) }, 0.12)
	Glitch.static(0.3, 1.6)
	local caption = Glitch.text(nil, "...something is watching", UDim2.fromScale(0.42, 0.045), UDim2.fromScale(0.5, 0.8), Color3.fromRGB(255, 150, 200))
	local opened = false
	local ok = Film.run(1.9, function(k)
		local open = math.clamp((k - 0.22) / 0.18, 0, 1)
		if open > 0 and not opened then
			opened = true
			FilmAudio.sfx("growl2", { volume = 0.8, pitch = 0.8 })
			FilmAudio.sfx("sting", { volume = 0.6, pitch = 0.9 })
		end
		-- (it glares, then narrows)
		local o = open * (1 - 0.35 * math.clamp((k - 0.75) / 0.25, 0, 1))
		eye.place(far + toCam * 2, toCam, 16, o)
		dark.Transparency = if o > 0.02 then 0 else 1
		dark.Size = Vector3.new(27, 15 * o + 0.05, 0.2)
		dark.CFrame = CFrame.lookAt(far + toCam * 1.4, far + toCam * 3)
		return Film.look(from, far - UP * (8 - k * 6)), 24 - k * 6, far
	end, { hand = 0.2 })
	caption.stop()
	eye.destroy()
	dark:Destroy()
	C.destroy()
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
	local actors = IntroCast.party(P.cast, P.fwd, P.right)
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
	if startAt == "glitch" then
		-- (the DEV panel's OPENING: CLASH starts here)
		IntroCast.hideGrass(true)
		IntroUi.fade(1, 0.6)
	elseif not pastScenes(P, m) then
		return
	end
	local ok, kingFeet = glitchScene(P, m)
	if not ok or not clashScene() then
		return
	end
	if not kingScenes(P, m, kingFeet) then
		return
	end
	if not growScenes(P, m, kingFeet) then
		return
	end
	if not worryScenes(P, m) then
		return
	end
	if not heroScenes(P, m, actors) then
		return
	end
	if not pleaScenes(P, m, actors) then
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
	FilmAudio.begin({ "storyMusic", "darkMusic", "lonelyMusic", "heroMusic", "impact", "slam", "rumble", "leaves", "brush", "crate", "bigHit", "titleHit", "swipe", "sting", "demonSwell", "growl", "growl2", "servo", "thud", "synthWhomp", "suck", "whomp", "roar", "riseDark" })
	-- (the guardians' models and textures for the King and the roll call)
	task.spawn(function()
		local models = ReplicatedStorage:FindFirstChild("BossModels")
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
