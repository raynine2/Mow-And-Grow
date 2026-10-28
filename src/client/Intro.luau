-- The run's opening film (owner, 28 Oct: "remake it ... make it feel like a real movie with a story attached to
-- it"), the first time you're in a new run. About a minute, told by Mayor Thistlewick (client/MayorRig):
--   I.   ONCE UPON A TIME: a golden storybook memory of the valley before the grass came, mowed neat as a pin; the
--        Mayor proud on his soapbox... a rumble, his eyes snap open;
--   II.  THE GRASS CAME BACK: the grass bursts up across the meadow in a wave, we skim through it low, then rise
--        over a sea of it ("...and it never stopped GROWING");
--   III. PRESENT DAY: the Mayor alone, looking out at the wall of grass ("If only someone could help us...");
--        footsteps behind him;
--   IV.  THE MOWERS: the party (copies of everyone's avatars) walks up in slow motion, the camera passes face by
--        face, the Mayor whirls round ("Mowers! At LAST!");
--   V.   THE PLEA: eight lands, eight guardians; he points at the grass: "Mow it ALL... and save our valley!";
--   VI.  the supply crate slams down, the title lands on the music's hit; a glitch: something far beyond the
--        meadow opens its eyes; then you're in first person, ready to go.
-- The Mayor speaks his lines (client/FilmVoice; subtitles always). Camera, light and grade: client/Film; music and
-- sound: client/FilmAudio (licensed library audio only). SKIP ends it at any moment. Once it has played (or been
-- skipped) the server remembers it for this run ("Seen" remote), so it doesn't play again on a rejoin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MowALawn = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(MowALawn:WaitForChild("Config"))
local HitFx = require(script.Parent.HitFx)
local IntroCast = require(script.Parent.IntroCast)
local IntroUi = require(script.Parent.IntroUi)
local Film = require(script.Parent.Film)
local FilmAudio = require(script.Parent.FilmAudio)
local FilmVoice = require(script.Parent.FilmVoice)
local Glitch = require(script.Parent.Glitch)
local Demon = require(script.Parent.Demon)
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

-- the Mayor's lines (made into speech ahead of time, in this order)
local LINES = {
	N1 = "Once upon a time, our valley was the tidiest lawn in all the land.",
	N2 = "Every blade trimmed. Every hedge just so.",
	N3 = "Then, one night... the grass came back.",
	N4 = "And it never... stopped... GROWING!",
	L1 = "If only someone could help us...",
	L2 = "Mowers! At LAST, you've come!",
	L3 = "The grass has swallowed our whole valley. Eight lands... and eight terrible guardians.",
	L4 = "Mow it ALL... and save our valley!",
}
local ORDER = { "N1", "N2", "N3", "N4", "L1", "L2", "L3", "L4" }

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

-- Say line `key` (narrated = a voice over the pictures, not his lips). Returns how long it takes.
local function speak(key: string, narrated: boolean?, quiet: boolean?): number
	local text = LINES[key]
	local len, level = FilmVoice.play(text)
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
	if len then
		FilmAudio.duck(if quiet then 0.6 else 0.42, 0.25)
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
	local ok = Film.run(6.2, function(k)
		local e = sine(k)
		local pos = a:Lerp(b, e)
		return Film.look(pos, target:Lerp(P.mayorAt + UP * 4, e)), Film.mm(24 + 6 * e), P.mayorAt
	end, { hand = 0.2 })
	if not ok then
		return false
	end
	-- 1B: the Mayor in his prime, proud on his soapbox, looking out over his lawn
	Film.at(0.3, function()
		speak("N2", true)
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
	ok = Film.run(5.4, function(k)
		local e = inOut(k)
		local f = m.face()
		local pos = f + d0 * (10.5 - 2.6 * e) + s0 * 3.4 - UP * (1.6 - 0.5 * e)
		return Film.look(pos, f - UP * (1.1 - 0.5 * e)), Film.mm(40 + 10 * e), f
	end, { hand = 0.25 })
	if not ok then
		return false
	end
	-- 1C: close on his face, content... a rumble; his eyes snap open
	m.closeEyes(true)
	Film.at(1.25, function()
		if story then
			story.tapeStop(1.1)
		end
		FilmAudio.sfx("rumble", { volume = 1.1 })
		FilmAudio.sfx("synthWhomp", { pitch = 0.6, volume = 0.8 })
		Film.shake(0.25, 1.2)
	end)
	Film.at(1.6, function()
		m.closeEyes(false)
		m.mood("surprised")
		m.act("shock")
		m.look(P.thick + P.dirK * 40 - UP * 2)
	end)
	return Film.run(2.3, function(k, t)
		local f = m.face()
		local push = if t < 1.6 then 0 else out((t - 1.6) / 0.5) * 0.9
		local pos = f + d0 * (4.8 - push) + s0 * 0.9 + UP * 0.1
		return Film.look(pos, f + UP * 0.05), Film.mm(85), f
	end, { hand = 0.15 })
end

-------------------------------------------------------------------------------------------------------------
-- II. THE GRASS CAME BACK
-------------------------------------------------------------------------------------------------------------
local function grassScenes(P: Plan, m: IntroCast.Mayor): boolean
	-- 2A: down at the edge of the bare meadow, the grass bursts up in a wave rolling toward us
	IntroUi.film(false)
	Film.flash(Color3.new(1, 1, 1), 0.5, 0.35)
	Film.grade("gloom", 1.6)
	Film.glow(0.1, 24, 1)
	Film.vignette(0.55, 1)
	Film.light(LOOKS.night, 1.6)
	FilmAudio.muffle(0, 0.2)
	FilmAudio.sfx("impact", { volume = 1 })
	FilmAudio.music("darkMusic", { fade = 0.6 })
	bed("ambWind", 1.6, 1.5)
	FilmAudio.sfx("leaves", { volume = 1.3 })
	Film.at(0.35, function()
		speak("N3", true)
	end)
	local camAt = IntroCast.ground(P.m0 - P.dirK * 7) + UP * 1.5
	local origin = P.thick + P.dirK * 70
	local wavedAt = 0
	IntroCast.growGrass(origin, 2.8, function(k: number)
		Film.shake(0.12 + k * 0.32, 0.6)
		if k - wavedAt > 0.22 and playing then
			wavedAt = k
			FilmAudio.sfx("brush", { volume = 0.8 + k * 0.5, pitch = 0.75 + math.random() * 0.3 })
			local burstAt = origin:Lerp(camAt, k * 0.9)
			HitFx.play("bossRise", IntroCast.ground(burstAt + P.dirK:Cross(UP) * (math.random() - 0.5) * 20), Color3.fromRGB(80, 170, 60), false)
		end
	end)
	Film.at(2.9, function()
		FilmAudio.sfx("slam", { volume = 0.7, pitch = 0.9 })
		Film.shake(0.5, 1.4)
		Film.punch(5)
	end)
	m.act("idle")
	m.mood("neutral")
	local ok = Film.run(3.8, function(k)
		local pos = camAt + P.dirK * (k * 2.5) + UP * (k * 0.4)
		return Film.look(pos, P.thick + UP * (2.5 + k * 1.5), 6 - k * 3), Film.mm(18), P.thick
	end, { hand = 0.7 })
	if not ok then
		return false
	end
	-- 2B: skimming low between the stalks
	Film.at(0.2, function()
		speak("N4", true)
	end)
	Film.at(2.55, function()
		FilmAudio.sfx("impact", { volume = 0.8, pitch = 0.85 })
		Film.punch(4)
	end)
	ok = Film.run(3.0, function(k)
		local p = P.m0:Lerp(P.m1, k * 0.5 + inOut(k) * 0.5)
		local look = p + P.dirK * 20 + UP * (2.5 + k * 2)
		return Film.look(p, look, math.sin(k * math.pi) * 3), Film.mm(22), look
	end, { hand = 1 })
	if not ok then
		return false
	end
	-- 2C: rising up and back over the sea of grass
	local craneYaw = freeYaw(function(y)
		return { P.thick - turn(P.dirK, y) * 34 + UP * 38 }
	end, function()
		return P.thick + UP * 20
	end, { 0, 15, -15, 30, -30, 45, -45 })
	local top = P.thick - turn(P.dirK, craneYaw) * 34 + UP * 38
	local far = P.thick + turn(P.dirK, craneYaw) * 40
	Film.at(1.6, function()
		IntroUi.caption("Present day", 3.2)
	end)
	Film.at(2.3, function()
		-- far off, something flickers
		FilmAudio.glitch(0.25)
		Glitch.burst(0.18, 0.12)
	end)
	return Film.run(3.4, function(k)
		local e = inOut(k)
		local p = P.m1:Lerp(top, e)
		local look = (P.m1 + P.dirK * 20 + UP * 4.5):Lerp(far, e)
		return Film.look(p, look), Film.mm(24 - 4 * e), far
	end, { hand = 0.45 })
end

-------------------------------------------------------------------------------------------------------------
-- III. PRESENT DAY: the Mayor, alone
-------------------------------------------------------------------------------------------------------------
local function worryScenes(P: Plan, m: IntroCast.Mayor): boolean
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
	local ok = Film.run(4.5, function(k)
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
	local walkLen = 3.8
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
	local len = math.clamp(1.15 * n + 1.6, 3.0, 6.5)
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
-- V. THE PLEA
-------------------------------------------------------------------------------------------------------------
local function pleaScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	-- 5A: "the grass has swallowed our whole valley..."
	m.act("present")
	m.mood("worried")
	m.look(P.cast + UP * 3.5)
	local d3 = 0
	Film.at(0.2, function()
		d3 = speak("L3")
		Film.at(1.6, function()
			m.act("talk")
		end)
	end)
	local ok = Film.run(3.4, function(k)
		local f = m.face()
		local pos = f - P.fwd * (10.5 - 1.5 * inOut(k)) + P.right * 2.8 - UP * 1.8
		return Film.look(pos, f - UP * 1.4), Film.mm(38), f
	end, { hand = 0.3 })
	if not ok then
		return false
	end
	-- 5B: the valley he means: a long lens across the endless grass, slowly panning
	FilmAudio.sfx("sting", { volume = 0.5 })
	local side = P.dirK:Cross(UP)
	local camAt = P.thick - P.dirK * 46 + UP * 15 + side * 12
	ok = Film.run(math.max(3.0, d3 - 3.2), function(k)
		local look = P.thick + P.dirK * 95 + side * (-30 + 60 * sine(k)) + UP * 3
		return Film.look(camAt + side * (k * 2), look), Film.mm(100), look
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- 5C: he whirls round and points at the grass: "Mow it ALL!"
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
	local riserDone = false
	Film.at(0.5, function()
		if not riserDone then
			riserDone = true
			FilmAudio.riser("rise", 5.2, { volume = 0.8 })
		end
	end)
	return Film.run(4.8, function(k)
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
		FilmAudio.sfx("whoosh", { volume = 1.4, pitch = 0.55 })
		IntroCast.crate(mid, -P.fwd, function()
			if not playing then
				return
			end
			Film.shake(0.75, 1.1)
			Film.speed(0.25, 0)
			task.delay(0.55, function()
				Film.speed(1, 0.5)
			end)
			Film.punch(12)
			Film.flash(Color3.new(1, 1, 1), 0.6, 0.35)
			FilmAudio.sfx("crate", { volume = 1.2 })
			FilmAudio.sfx("impact", { volume = 1 })
			FilmAudio.sfx("bigHit", { volume = 0.8 })
			local g = IntroCast.ground(mid)
			for i = 1, 5 do
				local a = i / 5 * math.pi * 2
				HitFx.play("bossRise", g + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.6, Color3.fromRGB(150, 118, 80), false)
			end
			m.act("cheer")
			m.mood("happy")
			m.hop(0.6)
			for _, actor in actors do
				actor.play("cheer")
			end
		end, function()
			-- the title lands once the crate has burst open (owner 27 Oct: the crate's reveal was hidden under it)
			if not playing then
				return
			end
			closeTitle = IntroUi.title(P.areaName:upper(), Config.GAME_NAME:upper(), "Mow it ALL to open the next area!")
			FilmAudio.sfx("titleHit", { volume = 1 })
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

-- A sneak peek of world 2 (owner, 27 Oct: "have this boss sneak peek in the first cutscene"): the picture glitches
-- and for a moment, far beyond the meadow on a blood-dark horizon, the glitch demon (client/Demon) looms up and
-- its eyes ignite... then it snaps back.
local function peekScene(P: Plan): boolean
	FilmAudio.glitch(0.8)
	Glitch.burst(0.9, 0.35)
	Film.shake(0.35, 2)
	FilmAudio.sfx("demonSwell", { volume = 1 })
	Film.wait(0.3)
	if not playing then
		Glitch.clear()
		return false
	end
	local far = IntroCast.ground(P.thick + P.dirK * 230)
	local demon = Demon.new(CFrame.lookAt(far, far - P.dirK), 2.4, nil, { lite = true }) -- (far off: the light build)
	demon.state.rise = 0.82
	demon.state.glitch = 1
	local ungrade = Glitch.grade({ Brightness = -0.32, Contrast = 0.55, Saturation = -0.65, TintColor = Color3.fromRGB(255, 118, 150) }, 0.12)
	Glitch.static(0.35, 1.7)
	FilmAudio.sfx("growl", { volume = 1, pitch = 0.7 })
	local t0 = os.clock()
	local remove = Film.every(function()
		demon.update(os.clock() - t0)
	end)
	local caption = Glitch.text(nil, "...something is waking up", UDim2.fromScale(0.42, 0.045), UDim2.fromScale(0.5, 0.8), Color3.fromRGB(255, 150, 200))
	local from = P.thick - P.dirK * 14 + UP * 9
	local ok = Film.run(1.8, function(k)
		if k > 0.2 and demon.state.eyes < 1 then
			demon.state.eyes = 1
			FilmAudio.sfx("growl2", { volume = 0.8, pitch = 0.8 })
		end
		local eyes = demon.eyes()
		return Film.look(from, eyes - UP * (10 - k * 3)), 21 - k * 5, eyes
	end, { hand = 0.2 })
	caption.stop()
	Glitch.burst(1, 0.3)
	FilmAudio.glitch(1)
	remove()
	demon.destroy()
	ungrade(0.15)
	Film.wait(0.2)
	Glitch.clear()
	return ok and playing
end

-- Dip to black and land in your own eyes.
local function homeScene(): boolean
	IntroUi.fade(0, 0.3)
	Film.wait(0.32)
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

local function finish()
	if not playing then
		return
	end
	playing = false
	Film.stop(STEP)
	FilmVoice.clear()
	FilmAudio.finish(1.2)
	Glitch.clear()
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
	State.fire("Seen", "intro")
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
	if not pastScenes(P, m) then
		return
	end
	if not grassScenes(P, m) then
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
		if workspace:GetAttribute("IntroTestSpeed") == nil then
			finish()
		end
	end)
	-- the black cover is up: the Mayor's voice starts being made, the sounds load, the far places stream in
	local lines = {}
	for _, k in ORDER do
		table.insert(lines, { text = LINES[k], who = "mayor" })
	end
	FilmVoice.prepare(lines)
	FilmAudio.begin({ "storyMusic", "darkMusic", "lonelyMusic", "heroMusic", "impact", "slam", "rumble", "leaves", "brush", "crate", "bigHit", "titleHit", "rise", "swipe", "sting", "demonSwell", "growl", "growl2", "servo", "thud", "synthWhomp" })
	local entry = Config.zoneEntry(1)
	local hub = Config.zoneCentre(0)
	local inward = (Config.zoneCentre(1) - entry).Unit
	local w = workspace:FindFirstChild("World")
	local camp = w and w:GetAttribute("CampCenter")
	streamIn({ entry, entry + inward * 50, entry + inward * 110, if typeof(camp) == "Vector3" then camp else hub:Lerp(entry, 0.4) })
	FilmVoice.waitFor(LINES.N1, 1.5)
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

return Intro
