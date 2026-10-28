-- The ending (owner, 27 Oct: "if you defeat the final boss make a cool fitting ending story with a cinematic
-- cutscene ... with end credits at the end where it prompts you to go to the next world or do the same mission
-- again"; 28 Oct: "remake it ... make it feel like a real movie with a story attached to it"). Played on every
-- client when the last area's boss falls (server/Run sends runComplete with `ending = true`). It closes the story
-- the opening film (client/Intro) starts: Mayor Thistlewick's valley, overgrown since "the grass came back and
-- never stopped growing", is mowed at last.
--   I.   THE LAST BLADE: silence over the last arena; a glow rises from where the last guardian fell and the
--        sunlight breaks through ("The last wild grass in the valley... was gone.");
--   II.  THE VALLEY BREATHES: a long flight back over every area, mowed in stripes, each name ticking off;
--   III. HOMECOMING: the Mayor alone on his soapbox; footsteps; he turns: the Mowers are back ("You... you
--        actually DID it!");
--   IV.  THE CELEBRATION: cheering, music, confetti, fireworks over the village at dusk, and the group photo
--        ("Everyone... say GRASS!"), frozen for a moment as a snapshot;
--   V.   THE TWIST (owner, 27 Oct: "teasing world 2, a corrupt world with a demon glitch type of enemy and boss"):
--        night, peace and quiet... the picture glitches, the music dies, a heartbeat; the meadow splits open in
--        neon, corruption bursts across it, the sky tears, and a colossal glitch demon (client/Demon) heaves itself
--        out of the ground, opens its eyes, speaks ("This valley... is MINE.") and roars:
--        WORLD 2, THE CORRUPTED VALLEY, COMING SOON;
--   VI.  the credits roll with music (the party "starring", the bosses as the cast, the makers), then the end
--        screen: PLAY AGAIN (back to the lobby for a new run) and a locked "???" (world 2, not out yet).
-- Camera, light and grade: client/Film; music and sound: client/FilmAudio (licensed library audio); the Mayor's
-- voice: client/FilmVoice; the actors and the screen: client/IntroCast, client/IntroUi, as in the opening. SKIP
-- jumps to the end screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MowALawn = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(MowALawn:WaitForChild("Config"))
local Format = require(MowALawn:WaitForChild("Format"))
local IntroCast = require(script.Parent.IntroCast)
local IntroUi = require(script.Parent.IntroUi)
local Film = require(script.Parent.Film)
local FilmAudio = require(script.Parent.FilmAudio)
local FilmVoice = require(script.Parent.FilmVoice)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local Confetti = require(script.Parent.Confetti)
local Glitch = require(script.Parent.Glitch) -- (27 Oct) world 2's corruption: screen glitches
local Demon = require(script.Parent.Demon) -- the glitch demon
local Corruption = require(script.Parent.Corruption) -- the meadow splitting open, the sky tearing

-- the VFX Lab's camera effects (ReplicatedStorage.VFXLib, in the place only): the anime impact frame
local CameraFX: any = nil
pcall(function()
	local lib = ReplicatedStorage:FindFirstChild("VFXLib")
	local m = lib and lib:FindFirstChild("CameraFX")
	if m then
		CameraFX = require(m)
	end
end)

local Ending = {}
local player = Players.LocalPlayer

local UP = Vector3.yAxis
local GREEN = Color3.fromRGB(110, 220, 70)
local GOLD = Color3.fromRGB(255, 214, 60)
local MYSTERY = Color3.fromRGB(170, 110, 255)
local MAYOR = "Mayor Thistlewick"
local MAKERS_FALLBACK = "The Mow And Grow team" -- the credits name the game's owner (group or user) when they can
local STEP = "MowEnding"

local playing = false -- (the credits' own flag: they can be skipped too)
local played = false

local LINES = {
	E1 = "And just like that... the last wild grass in the valley was gone.",
	E2 = "Meadow by meadow, hill by hill... the whole valley could breathe again.",
	E3 = "You... you actually DID it!",
	E4 = "Every meadow, every hill, every last blade... MOWED!",
	E5 = "Spawn Village is SAVED! Now, everyone... say GRASS!",
	E6 = "Ahh... peace and quiet. At last.",
	E8 = "W-what was THAT?!",
	D1 = "This valley... is MINE.",
}
local ORDER = { "E1", "E2", "E3", "E4", "E5", "E6", "E8" }

local flat, unit = Film.flat, Film.unit
local inOut, out, sine = Film.inOut, Film.out, Film.sine

local function ground(p: Vector3): Vector3
	return IntroCast.ground(p)
end

-- Ask the server to stream in the places the camera will visit.
local function streamIn(spots: { Vector3 })
	local left = #spots
	for _, at in spots do
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(at, 4)
			end)
			left -= 1
		end)
	end
	local deadline = os.clock() + 4
	while left > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

-------------------------------------------------------------------------------------------------------------
-- where everything is
-------------------------------------------------------------------------------------------------------------
type Plan = { arena: Vector3, areas: { { pos: Vector3, name: string } }, camp: Vector3, fwd: Vector3, right: Vector3, cast: Vector3, mayorAt: Vector3, sprout: Vector3 }

local function plan(): Plan
	local n = #Config.ZONES
	local w = workspace:FindFirstChild("World")
	local arenas = w and w:FindFirstChild("Arenas")
	local a = arenas and arenas:FindFirstChild("Arena" .. n)
	local arena = if a and a:IsA("Model") then a:GetPivot().Position else Config.zoneCentre(n)
	local areas = {}
	for z = n, 1, -1 do
		local def = Config.ZONES[z]
		table.insert(areas, { pos = Config.zoneCentre(z), name = if def and def.name then def.name else ("Area " .. z) })
	end
	-- the camp in area 1, where the opening gathered the party
	local camp = w and w:GetAttribute("CampCenter")
	local facing = w and w:GetAttribute("CampFacing")
	local campPos = if typeof(camp) == "Vector3" then camp else Config.zoneCentre(0)
	local fwd = if typeof(facing) == "Vector3" then unit(flat(facing), Vector3.zAxis) else unit(flat(Config.zoneCentre(1) - campPos), Vector3.zAxis)
	local cast = ground(campPos + fwd * 2)
	-- out in the first meadow, where the story began: where world 2's corruption breaks through (the twist)
	local meadow = Config.zoneCentre(1)
	local sprout = ground(campPos:Lerp(meadow, 0.55))
	return {
		arena = arena,
		areas = areas,
		camp = campPos,
		fwd = fwd,
		right = fwd:Cross(UP),
		cast = cast,
		mayorAt = cast + fwd * 11,
		sprout = sprout,
	}
end

-------------------------------------------------------------------------------------------------------------
-- props: a folder for the film's own things, fireworks that light up the village
-------------------------------------------------------------------------------------------------------------
local set: Folder? = nil
local function propFolder(): Folder
	if set and set.Parent then
		return set
	end
	local f = Instance.new("Folder")
	f.Name = "EndingSet"
	f.Parent = workspace
	set = f
	return f
end

local function spark(pos: Vector3, color: Color3, size: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one * size
	p.Position = pos
	p.Parent = propFolder()
	return p
end

local FIREWORK_COLORS = { GOLD, Color3.fromRGB(255, 110, 150), Color3.fromRGB(110, 220, 255), GREEN, Color3.fromRGB(255, 150, 60), Color3.fromRGB(200, 140, 255) }
local function firework(at: Vector3, big: boolean?)
	local color = FIREWORK_COLORS[math.random(1, #FIREWORK_COLORS)]
	local rise = spark(at - UP * 30, color, 0.6)
	TweenService:Create(rise, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at }):Play()
	FilmAudio.sfx("swingHand", { volume = 0.9, pitch = 0.55 + math.random() * 0.15 }) -- (the whistle up)
	task.delay(0.8, function()
		rise:Destroy()
		if not Film.playing then
			return
		end
		FilmAudio.sfx("boom", { volume = if big then 1 else 0.6 + math.random() * 0.3, pitch = 1.25 + math.random() * 0.35 })
		-- the burst lights up everything round it
		local glow = spark(at, color, 0.2)
		glow.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 60
		light.Brightness = if big then 10 else 6
		light.Shadows = false
		light.Parent = glow
		TweenService:Create(light, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		task.delay(1.2, function()
			glow:Destroy()
		end)
		local n = if big then 26 else 18
		for i = 1, n do
			local th = i / n * math.pi * 2
			local ph = (math.random() - 0.5) * 1.6
			local dir = Vector3.new(math.cos(th) * math.cos(ph), math.sin(ph), math.sin(th) * math.cos(ph))
			local s = spark(at, color, 0.6)
			local reach = if big then 15 else 11
			TweenService:Create(s, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at + dir * reach - UP * 3.5, Size = Vector3.one * 0.12, Transparency = 1 }):Play()
			task.delay(1.45, function()
				s:Destroy()
			end)
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- dialogue
-------------------------------------------------------------------------------------------------------------
local mayor: IntroCast.Mayor? = nil
local music: { [string]: FilmAudio.Cue } = {}

local function cue(name: string, key: string, opts: any): FilmAudio.Cue?
	local c = FilmAudio.music(key, opts)
	if c then
		music[name] = c
	end
	return c
end

local function stopCue(name: string, time: number?, tape: boolean?)
	local c = music[name]
	if c then
		music[name] = nil
		if tape then
			c.tapeStop(time or 0.8)
		else
			c.stop(time)
		end
	end
end

-- An ambience bed in a slot ("amb", "crowd"): the slot's last bed fades out as the new one fades in.
local function bed(slot: string, key: string?, volume: number?, fade: number?)
	stopCue(slot, fade or 1.5)
	if key then
		local c = FilmAudio.amb(key, volume, fade)
		if c then
			music[slot] = c
		end
	end
end

-- Say line `key` (narrated: a voice over the pictures). Returns how long it takes.
local function speak(key: string, narrated: boolean?, text: string?): number
	local line = LINES[key]
	local len, level = FilmVoice.play(line)
	local dur = len or math.clamp(#line * 0.062, 1.8, 5.5)
	if narrated then
		IntroUi.narrate(text or line, dur + 0.6)
	else
		IntroUi.say(if key == "D1" then "???" else MAYOR, text or line, dur + 0.7)
		local m = mayor
		if m and key ~= "D1" then
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
		FilmAudio.duck(0.42, 0.25)
		task.delay(dur, function()
			if Film.playing then
				FilmAudio.duck(0, 0.8)
			end
		end)
	end
	return dur
end

-- the anime impact frame (VFXLib) on a big hit, or just a soft flash ("Reduce camera shake": the soft one)
local function impact(color: Color3)
	if CameraFX and player:GetAttribute("CalmCamera") ~= true then
		pcall(CameraFX.ImpactFrame, { Color = color, Duration = 0.35 })
	else
		Film.flash(Color3.new(1, 1, 1), 0.35, 0.3)
	end
end

local LOOKS = {
	morning = { ClockTime = 8.2, ExposureCompensation = 0.15, atmosphere = { Density = 0.26, Haze = 1.2, Glare = 0.8 } },
	day = { ClockTime = 13.5, ExposureCompensation = 0.05, atmosphere = { Density = 0.25, Haze = 0.9, Glare = 0.5 } },
	golden = { ClockTime = 17.4, ExposureCompensation = 0.05, atmosphere = { Density = 0.28, Haze = 1.4, Glare = 1.0 } },
	dusk = { ClockTime = 18.35, ExposureCompensation = -0.1, atmosphere = { Density = 0.32, Haze = 1.8, Glare = 0.6 } },
	night = { ClockTime = 21.6, ExposureCompensation = -0.35, atmosphere = { Density = 0.36, Haze = 1.2, Glare = 0 } },
}

-------------------------------------------------------------------------------------------------------------
-- I. THE LAST BLADE
-------------------------------------------------------------------------------------------------------------
local function lastBladeScenes(P: Plan): boolean
	Film.light(LOOKS.morning, 0)
	Film.grade("dream", 0)
	Film.glow(0.3, 30, 0.1)
	Film.vignette(0.45, 0)
	IntroUi.fade(1, 1.6)
	cue("calm", "calmMusic", { fade = 3 })
	bed("amb", "ambWind", 1.2, 2)
	Film.at(1.2, function()
		speak("E1", true)
	end)
	Film.at(0.9, function()
		IntroUi.lowerThird(string.upper(P.areas[1].name), "The last guardian has fallen.", GREEN, 3.6)
	end)
	-- 1A: high and slow round the last arena, dust settling
	local ok = Film.run(5.6, function(k)
		local a = math.rad(200 + k * 50)
		local r = 70 - sine(k) * 10
		local pos = P.arena + Vector3.new(math.cos(a) * r, 36 + k * 6, math.sin(a) * r)
		return Film.look(pos, P.arena + UP * 6), Film.mm(32), P.arena
	end, { hand = 0.2 })
	if not ok then
		return false
	end
	-- 1B: down where it fell, a glow rises... and the sun breaks through
	local g = ground(P.arena)
	local mote = spark(g + UP * 1, Color3.fromRGB(255, 244, 196), 0.9)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 236, 180)
	light.Range = 22
	light.Brightness = 3
	light.Parent = mote
	TweenService:Create(mote, TweenInfo.new(4.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = g + UP * 70, Size = Vector3.one * 0.3 }):Play()
	FilmAudio.sfx("swell", { volume = 0.9 })
	FilmAudio.sfx("rareChime", { volume = 0.5, pitch = 0.8 })
	Film.at(2.6, function()
		Film.light({ ExposureCompensation = 0.45 }, 1.4)
		Film.glow(0.55, 40, 1.2)
		FilmAudio.sfx("rareChime", { volume = 0.6, pitch = 1.1 })
	end)
	local camAt = g + Vector3.new(14, 2.2, 10)
	Film.refreshSight()
	local view = Film.view()
	ok = Film.run(4.2, function(k)
		local e = inOut(k)
		local target = mote.Position:Lerp(g + UP * (8 + 50 * e), 0.5)
		return Film.look(Film.clear(camAt - UP * (0.6 * e), g + UP * 2, view), target), Film.mm(35 - 10 * e), mote.Position
	end, { hand = 0.3 })
	mote:Destroy()
	return ok
end

-------------------------------------------------------------------------------------------------------------
-- II. THE VALLEY BREATHES: the flight back over every area to the village
-------------------------------------------------------------------------------------------------------------
local function valleyScenes(P: Plan): boolean
	Film.light(LOOKS.day, 0)
	Film.glow(0.25, 28, 0.6)
	Film.grade("hero", 0.8)
	stopCue("calm", 2.5)
	cue("flight", "flightMusic", { fade = 2.5 })
	bed("amb", "ambBirds", 1.2, 2)
	Film.at(1.0, function()
		speak("E2", true)
	end)
	local pts = {}
	for i, area in P.areas do
		table.insert(pts, area.pos + UP * (78 - (i % 2) * 14))
	end
	table.insert(pts, P.camp + UP * 58 - P.fwd * 40)
	local legs = #pts - 1
	local named = {}
	local len = 12
	return Film.run(len, function(k)
		local e = inOut(k)
		local pos = Film.spline(pts, e)
		local ahead = Film.spline(pts, math.min(1, e + 0.06))
		local i = math.clamp(math.floor(e * legs) + 1, 1, legs)
		local u = e * legs - (i - 1)
		local area = P.areas[i]
		if area and not named[i] and u > 0.15 then
			named[i] = true
			IntroUi.lowerThird(string.upper(area.name), "MOWED", GREEN, 1.5)
			FilmAudio.sfx("rareChime", { volume = 0.35, pitch = 0.8 + i * 0.07 })
		end
		-- bank into the turns
		local d1 = flat(ahead - pos)
		local d2 = flat(Film.spline(pts, math.min(1, e + 0.12)) - ahead)
		local bank = 0
		if d1.Magnitude > 0.1 and d2.Magnitude > 0.1 then
			bank = math.clamp(d1.Unit:Cross(d2.Unit).Y * 60, -12, 12)
		end
		return Film.look(pos, ahead - UP * 62, bank), Film.mm(20), ahead - UP * 60
	end, { hand = 0.25 })
end

-------------------------------------------------------------------------------------------------------------
-- III. HOMECOMING
-------------------------------------------------------------------------------------------------------------
local function walkFrom(spot: Vector3, back: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	local s = workspace:FindFirstChild("IntroSet")
	if s then
		table.insert(skip, s)
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
	for _, dist in { 15, 11, 8, 5 } do
		if not workspace:Raycast(spot + UP * 2.5, back * dist, params) then
			return spot + back * dist
		end
	end
	return spot + back * 3
end

local function homeScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	Film.light(LOOKS.golden, 0)
	Film.grade("dusk", 0)
	Film.glow(0.3, 30, 0.2)
	bed("amb", "ambWind", 1, 1.5)
	local face = P.fwd
	m.act("lookOut")
	m.mood("neutral")
	m.look(P.mayorAt + face * 40 + UP * 3)
	-- 3A: the Mayor alone on his soapbox at sunset, looking out over his mowed meadow
	local view = Film.view()
	Film.refreshSight()
	local ok = Film.run(4.2, function(k)
		local f = m.face()
		local pos = f - face * (8.5 - 1.2 * inOut(k)) + P.right * 3.2 + UP * 0.8
		return Film.look(Film.clear(pos, f, view), f + face * 14 - UP * 2), Film.mm(45), f
	end, { hand = 0.3 })
	if not ok then
		return false
	end
	-- 3B: footsteps; the Mowers walk up out of the sunset; he turns
	local walk = 4.2
	for i, actor in actors do
		local from = walkFrom(actor.spot.Position, -P.fwd)
		Film.at((i - 1) * 0.15, function()
			actor.walk(from, walk - (i - 1) * 0.15, function()
				FilmAudio.sfx("stepGrass", { volume = 1.3, pitch = 0.9 })
				FilmAudio.sfx("thud", { volume = 0.22, pitch = 0.85 + math.random() * 0.1 })
			end)
		end)
	end
	Film.at(0.9, function()
		m.mood("surprised")
		m.act("idle")
		m.turn(-P.fwd, 1.0)
		m.look(P.cast + UP * 3)
	end)
	view = Film.view()
	ok = Film.run(walk, function(k)
		-- over his shoulder, toward them
		local f = m.face()
		local pos = f + face * 4.6 + P.right * 2.2 + UP * 0.6
		local target = P.cast - P.fwd * (6 - 6 * k) + UP * 3
		return Film.look(Film.clear(pos, target, view), target), Film.mm(50), target
	end, { hand = 0.35, far = 0.2 })
	if not ok then
		return false
	end
	-- 3C: his face: "You... you actually DID it!"
	for _, actor in actors do
		actor.look(m.face())
	end
	m.mood("happy")
	Film.at(0.2, function()
		m.act("present")
		speak("E3")
	end)
	Film.at(1.6, function()
		m.hop(0.5)
	end)
	return Film.run(3.4, function(k)
		local f = m.face()
		local pos = f - P.fwd * (5.4 - 0.9 * out(k)) - P.right * 1.2 - UP * 0.25
		return Film.look(pos, f - UP * 0.15), Film.mm(70), f
	end, { hand = 0.25 })
end

-------------------------------------------------------------------------------------------------------------
-- IV. THE CELEBRATION
-------------------------------------------------------------------------------------------------------------
-- The group photo: a white flash, the picture stops, a snapshot frame with a caption, then it's put away.
local function snapshot()
	local g = Instance.new("ScreenGui")
	g.Name = "EndingSnapshot"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 21
	g.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.48)
	frame.Size = UDim2.fromScale(0.62, 0.62)
	frame.BackgroundTransparency = 1
	frame.Rotation = -3
	frame.Parent = g
	local edge = Instance.new("UIStroke")
	edge.Thickness = 14
	edge.Color = Color3.fromRGB(252, 248, 238)
	edge.Parent = frame
	local cap = Instance.new("TextLabel")
	cap.AnchorPoint = Vector2.new(0.5, 0)
	cap.Position = UDim2.new(0.5, 0, 1, 10)
	cap.Size = UDim2.new(1, 28, 0, 52)
	cap.BackgroundColor3 = Color3.fromRGB(252, 248, 238)
	cap.BorderSizePixel = 0
	cap.FontFace = Font.new("rbxasset://fonts/families/PatrickHand.json")
	cap.TextScaled = true
	cap.TextColor3 = Color3.fromRGB(70, 56, 40)
	cap.Text = "The Mowers ~ heroes of the valley!"
	cap.Parent = frame
	local sc = Instance.new("UIScale")
	sc.Scale = 1.15
	sc.Parent = frame
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.1, function()
		TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 1.4), Rotation = 8 }):Play()
		task.delay(0.55, function()
			g:Destroy()
		end)
	end)
end

local function partyScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	-- 4A: "Every meadow, every hill... MOWED!" the party cheers, the music kicks in
	stopCue("flight", 1.2)
	cue("party", "partyMusic", { fade = 0.4 })
	bed("crowd", "crowd", 0.9, 1.2)
	FilmAudio.sfx("applause", { volume = 1 })
	m.act("fist")
	Film.at(0.2, function()
		speak("E4")
	end)
	for i, actor in actors do
		Film.at(0.3 + i * 0.12, function()
			actor.look(nil)
			actor.play("cheer")
		end)
	end
	Film.at(1.0, function()
		Confetti.burst(140)
	end)
	Film.at(2.6, function()
		m.act("cheer")
		m.hop(0.6)
	end)
	local mid = P.cast:Lerp(P.mayorAt, 0.5)
	local view = Film.view()
	local ok = Film.run(4.6, function(k)
		local pos = mid + P.right * (17 - 2 * k) - P.fwd * 2 + UP * (2.6 + k)
		return Film.look(Film.clear(pos, mid + UP * 3, view), mid + UP * 3.2), Film.mm(28), mid
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- 4B: dusk; fireworks over the village, lighting everyone up; low, looking up past the Mayor
	Film.light(LOOKS.dusk, 1.2)
	Film.grade("dusk", 1)
	local sky = P.mayorAt + P.fwd * 22 + UP * 36
	for i = 0, 8 do
		Film.at(0.2 + i * 0.5, function()
			firework(sky + P.right * math.random(-30, 30) + P.fwd * math.random(-10, 12) + UP * math.random(-5, 9), i == 8)
		end)
	end
	m.act("wave")
	m.look(sky)
	ok = Film.run(4.8, function(k)
		local f = m.face()
		local pos = f - P.fwd * 7 + P.right * 2.6 - UP * 3.4
		local target = f:Lerp(sky, 0.35 + 0.25 * k)
		return Film.look(pos, target, -4), Film.mm(24), sky
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- 4C: the group photo: everyone turns to us; "say GRASS!"; flash, the picture stops
	local mid2 = P.cast:Lerp(P.mayorAt, 0.5)
	local camPos = mid2 + P.right * 17 + UP * 4.6
	for _, actor in actors do
		actor.turnTo(P.right)
		actor.look(camPos)
		actor.play("wave")
	end
	m.act("present")
	m.look(camPos)
	m.turn(P.right, 0.5)
	Film.at(0.3, function()
		local d = speak("E5")
		Film.at(math.min(math.max(d - 0.25, 1.5), 4.4), function()
			m.act("cheer")
			for _, actor in actors do
				actor.play("cheer")
			end
			Film.at(0.35, function()
				Film.flash(Color3.new(1, 1, 1), 1, 0.5)
				FilmAudio.sfx("whomp", { volume = 0.8, pitch = 1.8 })
				Film.speed(0, 0)
				snapshot()
				task.delay(2.3, function()
					Film.speed(1, 0.3)
				end)
			end)
		end)
	end)
	local look = mid2 + UP * 3.6
	local photoView = Film.view()
	ok = Film.run(5.4, function(k)
		local pos = camPos + P.right * (2 * (1 - inOut(k)))
		return Film.look(Film.clear(pos, look, photoView), look), Film.mm(32), look
	end, { hand = 0.2 })
	-- (the frozen moment lasts 2.3 s of real time)
	local t0 = os.clock()
	while Film.playing and Film.scale() < 0.99 and os.clock() - t0 < 3 do
		task.wait()
	end
	return ok and Film.playing
end

-------------------------------------------------------------------------------------------------------------
-- V. THE TWIST: world 2 is coming
-------------------------------------------------------------------------------------------------------------
local corrupt: Corruption.Handle? = nil
local demon: Demon.Demon? = nil
local demonReady = false -- (it's built in steps while the twist begins)
local ungrade: ((number?) -> ())? = nil

-- Where world 2 breaks through: the clearest patch of meadow round the camp (out of the camp, on level ground),
-- with nothing standing between the twist's camera spots and the demon. The grass doesn't count (it's mowed by
-- the end). Scored over a ring of spots, both ways round (looking out from the camp, or back at it). Yields.
local function twistStage(P: Plan): (Vector3, Vector3)
	Film.refreshSight()
	local bestAt, bestToward, best = P.sprout, unit(flat(P.sprout - P.cast), P.fwd), math.huge
	for i = 0, 23 do
		local a = math.rad(i * 15)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		for _, d in { 100, 125, 150 } do
			local at = ground(P.camp + dir * d)
			if math.abs(at.Y - P.cast.Y) < 12 then
				for _, toward in { dir, -dir } do
					local side = toward:Cross(UP)
					local score = math.abs(at.Y - P.cast.Y) * 0.5
					-- room for it: nothing overhead where it stands (a tree, a roof) across its shoulders
					for _, off in { Vector3.zero, side * 12, -side * 12, toward * 8 } do
						if not Film.sees(at + off + UP * 1.5, at + off + UP * 70) then
							score += 6
						end
					end
					for _, cam in { at - toward * 30 + UP * 3 - side * 6, at - toward * 40 + UP * 14 + side * 22, at - toward * 50 + UP * 3 + side * 10, at - toward * 72 + UP * 22 + side * 20 } do
						for _, h in { 4, 22, 42 } do
							if not Film.sees(cam, at + UP * h) then
								score += 4
							end
						end
						if not Film.sees(cam + UP * 0.5, cam + UP * 60) then
							score += 2 -- (under a roof or a tree)
						end
					end
					if score < best then
						best, bestAt, bestToward = score, at, toward
					end
				end
			end
		end
		if i % 4 == 3 then
			task.wait()
		end
	end
	return bestAt, bestToward
end

-- The title over black: WORLD 2 / THE CORRUPTED VALLEY / COMING SOON, glitching, the demon's eyes behind it.
local function worldTwoTitle(look: () -> CFrame): boolean
	local W = Config.WORLD2
	local veil = Instance.new("Frame")
	veil.Name = "WorldTwoVeil"
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(4, 0, 8)
	veil.BackgroundTransparency = 0.12 -- (the demon's eyes burn through it)
	veil.ZIndex = 1
	local holder = Instance.new("ScreenGui")
	holder.Name = "WorldTwoTitle"
	holder.IgnoreGuiInset = true
	holder.ResetOnSpawn = false
	holder.DisplayOrder = 21 -- over the film (IntroCinema 20), under the glitches (22)
	holder.Parent = player:WaitForChild("PlayerGui")
	veil.Parent = holder
	Glitch.static(0.3, 0)
	Glitch.burst(1, 0.3)
	FilmAudio.glitch(1)
	FilmAudio.sfx("impact", { volume = 1, pitch = 0.8 })
	FilmAudio.sfx("bigHit", { volume = 0.7, pitch = 0.75 })
	local big = Glitch.text(holder, W.title, UDim2.fromScale(0.7, 0.2), UDim2.fromScale(0.5, 0.4), Color3.fromRGB(255, 70, 150))
	local name = Glitch.text(holder, W.name, UDim2.fromScale(0.6, 0.075), UDim2.fromScale(0.5, 0.56))
	local soon: { stop: () -> () }? = nil
	Film.at(1.1, function()
		soon = Glitch.text(holder, W.soon, UDim2.fromScale(0.34, 0.05), UDim2.fromScale(0.5, 0.67), Color3.fromRGB(150, 245, 255))
		FilmAudio.sfx("slam", { volume = 0.7, pitch = 0.8 })
		FilmAudio.glitch(0.6)
		Glitch.burst(0.7, 0.2)
	end)
	Film.at(2.4, function()
		FilmAudio.sfx("growl", { volume = 0.9, pitch = 0.6 })
	end)
	local ok = Film.run(4.4, function(k)
		local cf = look() * CFrame.new(0, 0, -k * 2)
		return cf, 30, cf.Position + cf.LookVector * 20
	end, { hand = 0.3 })
	big.stop()
	name.stop()
	if soon then
		soon.stop()
	end
	holder:Destroy()
	return ok
end

-- The meadow splits, the corruption spreads, the sky tears, the demon rises, opens its eyes, speaks and roars.
local function worldTwoRise(at: Vector3, toward: Vector3, side: Vector3): boolean
	IntroUi.hush()
	local C = Corruption.new(at)
	corrupt = C
	ungrade = Glitch.grade(nil, 3)
	-- W4: low over the meadow, the ground splits open in neon
	C.fissure(1.6)
	C.cubes(34, 16)
	FilmAudio.sfx("rumble", { volume = 1.2 })
	FilmAudio.sfx("impact", { volume = 0.9, pitch = 0.7 })
	FilmAudio.sfx("fellCrunch", { volume = 1.2, pitch = 0.6 })
	Film.shake(0.5, 0.6)
	Glitch.burst(0.5, 0.25)
	FilmAudio.glitch(0.5)
	Film.at(1.4, function()
		C.bolt(at + UP * 140 + side * 30, at + side * 4)
		FilmAudio.sfx("slam", { volume = 0.8, pitch = 0.7 })
		Film.flash(Color3.fromRGB(255, 200, 240), 0.35, 0.2)
	end)
	Film.refreshSight()
	local view = Film.view()
	local ok = Film.run(3.8, function(k)
		local target = at + UP * (1 + k * 3)
		local p = at - toward * (34 - k * 10) + UP * (2.2 + k * 1.2) - side * 6
		return Film.look(Film.clear(p, target, view), target, 4), Film.mm(30), target
	end, { hand = 0.8 })
	if not ok then
		return false
	end
	-- W5: high and wide, the corruption bursts across the meadow, the sky tears, the storm rolls in
	C.spread(70, 3.2)
	C.canopy(2.5)
	local riftAt = at + toward * 40 + UP * 95
	C.rift(riftAt, -toward, 70, 1.1)
	Glitch.static(0.18, 0)
	cue("dread", "dreadMusic", { fade = 1.5 })
	bed("amb", "eerie", 1.2, 2)
	FilmAudio.sfx("bhPull", { volume = 1, pitch = 0.5 })
	FilmAudio.sfx("drone", { volume = 0.9 })
	Film.shake(0.45, 0.25)
	for i = 0, 3 do
		Film.at(0.6 + i * 0.75, function()
			C.bolt(riftAt + side * math.random(-20, 20) - UP * 10, at + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40)))
			Glitch.burst(0.35, 0.12)
			FilmAudio.sfx("boom", { volume = 0.6, pitch = 0.55 + math.random() * 0.15 })
			Film.flash(Color3.fromRGB(255, 190, 240), 0.25, 0.15)
		end)
	end
	Film.refreshSight()
	view = Film.view()
	ok = Film.run(4.0, function(k)
		local e = inOut(k)
		local target = at + UP * (6 + e * 30)
		local p = (at - toward * 40 + UP * 14 + side * 22):Lerp(at - toward * 82 + UP * 52 + side * 34, e)
		return Film.look(Film.clear(p, target, view), target), Film.mm(24 - 4 * e), target
	end, { hand = 0.5 })
	if not ok then
		return false
	end
	-- W6: it rises. Low, looking up: the horns break the ground and it heaves itself out, shaking everything
	-- (built in steps since the twist began; if it isn't done yet, wait a moment, then build it now)
	local waited = os.clock()
	while Film.playing and not demonReady and os.clock() - waited < 2 do
		task.wait()
	end
	if not Film.playing then
		return false
	end
	local d = demon
	if not d then
		local g = ground(at)
		d = Demon.new(CFrame.lookAt(g, g - toward), 1.5, propFolder())
		demon = d
	end
	assert(d)
	d.state.glitch = 0.4
	local t0 = os.clock()
	Film.every(function()
		d.update(os.clock() - t0)
	end)
	FilmAudio.sfx("growl", { volume = 1.1, pitch = 0.55 })
	FilmAudio.sfx("rumble", { volume = 1.2, pitch = 0.8 })
	FilmAudio.sfx("slam", { volume = 1, pitch = 0.6 })
	Film.shake(0.8, 0.18)
	Film.refreshSight()
	view = Film.view()
	ok = Film.run(4.6, function(k)
		d.state.rise = inOut(math.clamp(k / 0.85, 0, 1)) * 0.86
		if math.random() < 0.05 then
			Glitch.burst(0.3, 0.08)
		end
		local target = at + UP * (6 + d.state.rise * 38)
		return Film.look(Film.clear(at - toward * 50 + UP * 2.5 + side * 10, target, view), target, -3), Film.mm(20), target
	end, { hand = 0.6 })
	if not ok then
		return false
	end
	-- W7: its eyes open (a long suck of sound, then the hit)
	FilmAudio.riser("suck", 0.6, { volume = 0.9 })
	ok = Film.run(1.7, function(k)
		if k > 0.35 and d.state.eyes < 1 then
			d.state.eyes = 1
			impact(Color3.fromRGB(255, 60, 150))
			FilmAudio.sfx("impact", { volume = 1 })
			FilmAudio.sfx("growl2", { volume = 1, pitch = 0.7 })
			Film.punch(8)
			Film.shake(0.65, 1.2)
			Glitch.burst(0.9, 0.3)
		end
		local eyes = d.eyes()
		return Film.look(eyes - toward * (20 - k * 3.5) + side * 2.5 + UP * 0.8, eyes), Film.mm(55), eyes
	end, { hand = 0.3 })
	if not ok then
		return false
	end
	-- W7b: it speaks
	Film.at(0.2, function()
		speak("D1")
		FilmAudio.sfx("drone", { volume = 0.7, pitch = 0.7 })
	end)
	ok = Film.run(3.2, function(k)
		local eyes = d.eyes()
		return Film.look(eyes - toward * (15 - k * 2.5) - side * 1.5 + UP * 0.4, eyes, -5 + k * 3), Film.mm(70), eyes
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- W8: the roar. Pull back hard: jaw wide, arms flung out, lightning everywhere, the picture tearing
	view = Film.view()
	d.state.glitch = 1
	-- (kept below the pain line: stacked roars and hits got too loud)
	FilmAudio.sfx("roar", { volume = 1.1, pitch = 0.55 })
	FilmAudio.sfx("roar", { volume = 0.8, pitch = 0.78 })
	FilmAudio.sfx("growl", { volume = 0.8, pitch = 0.5 })
	FilmAudio.sfx("bigHit", { volume = 0.6, pitch = 0.7 })
	Film.shake(1, 0.5)
	Film.punch(12)
	Glitch.burst(1, 0.6)
	FilmAudio.glitch(1)
	for i = 0, 4 do
		Film.at(0.25 + i * 0.45, function()
			if corrupt then
				corrupt.bolt(riftAt + side * math.random(-25, 25), at + Vector3.new(math.random(-30, 30), 0, math.random(-30, 30)))
				Glitch.burst(0.6, 0.15)
				Film.flash(Color3.fromRGB(255, 190, 240), 0.3, 0.15)
			end
		end)
	end
	ok = Film.run(3.4, function(k)
		d.state.roar = math.clamp(k / 0.25, 0, 1)
		local e = 1 - (1 - k) ^ 4
		local eyes = d.eyes()
		local near = eyes - toward * 16 + side * 2.5
		local far = at - toward * 72 + UP * 22 + side * 20
		local target = eyes:Lerp(at + UP * 38, e)
		return Film.look(Film.clear(near:Lerp(far, e), target, view), target), 34 + e * 36, target
	end, { hand = 0.6 })
	if not ok then
		return false
	end
	-- W9: the title, its eyes burning behind it
	d.state.roar = 0.3
	FilmAudio.sfx("revBuild", { volume = 0.8 })
	return worldTwoTitle(function(): CFrame
		local eyes = d.eyes()
		return CFrame.lookAt(eyes - toward * 24 - UP * 2, eyes)
	end)
end

local function twistScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	-- while the night falls: pick where it breaks through (out in the open meadow) and build the demon there,
	-- hidden under the ground, a few hundred blocks a frame (it rises in W6)
	demonReady = false
	demon = nil
	local stage: { at: Vector3, toward: Vector3 }? = nil
	local folder = propFolder()
	task.spawn(function()
		local at, toward = twistStage(P)
		stage = { at = at, toward = toward }
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(at, 4)
			end)
		end)
		local g = ground(at)
		local d = Demon.new(CFrame.lookAt(g, g - toward), 1.5, folder, { yieldEvery = 250 })
		if Film.playing and folder.Parent and not demon then
			demon = d
			demonReady = true
		else
			d.destroy()
		end
	end)
	-- 5A: night; everyone has gone home; the Mayor, content, alone on his soapbox
	stopCue("party", 2)
	bed("crowd", nil, 2)
	for _, actor in actors do
		actor.model.Parent = nil
	end
	Film.light(LOOKS.night, 0)
	Film.grade("night", 0)
	Film.glow(0.15, 24, 0.2)
	Film.vignette(0.55, 0)
	bed("amb", "ambWind", 0.8, 1)
	m.act("proud")
	m.mood("happy")
	m.look(nil)
	m.turn(P.fwd, 0.01)
	Film.at(0.6, function()
		m.closeEyes(true)
		speak("E6")
	end)
	local face = P.fwd
	local view = Film.view()
	local ok = Film.run(4.0, function(k)
		local f = m.face()
		local pos = f + face * (11 - 2 * inOut(k)) + P.right * 3.6 - UP * 1.2
		return Film.look(Film.clear(pos, f, view), f - UP * 0.8), Film.mm(45), f
	end, { hand = 0.25 })
	if not ok then
		return false
	end
	-- 5B: it stutters. The picture sticks and splits, his line breaks up, the music is gone; a heartbeat
	FilmVoice.stop()
	Film.freeze(0.34)
	Film.shake(0.45, 1)
	Glitch.burst(0.85, 0.5)
	FilmAudio.glitch(1)
	FilmAudio.sfx("revStop", { volume = 0.9 })
	IntroUi.say(MAYOR, "Ahh... p#@ce an% q/!et... a7 l@$t.", 1.4)
	cue("heart", "heartbeat", { fade = 0.8, volume = 1 })
	ok = Film.run(1.4, function(k)
		local f = m.face()
		local pos = f + face * (9 - 0.4 * k) + P.right * 3.6 - UP * 0.8
		return Film.look(pos, f - UP * 0.6, 6), Film.mm(45), f
	end, { hand = 0.6 })
	if not ok then
		return false
	end
	-- 5C: the Mayor, rattled: eyes wide, a Dutch angle
	m.closeEyes(false)
	m.mood("scared")
	m.act("shock")
	Film.at(0.15, function()
		speak("E8")
	end)
	ok = Film.run(2.4, function(k)
		local f = m.face()
		local pos = f + face * (5.6 - 1.2 * k) - P.right * 1.4 + UP * 0.2
		return Film.look(pos, f, -8 + k * 3), Film.mm(65), f
	end, { hand = 0.9 })
	if not ok then
		return false
	end
	-- (the stage is normally chosen long before this)
	local waited = os.clock()
	while Film.playing and not stage and os.clock() - waited < 3 do
		task.wait()
	end
	if not Film.playing then
		return false
	end
	local st = stage or { at = P.sprout, toward = unit(flat(P.sprout - P.cast), P.fwd) }
	m.look(st.at + UP * 20)
	return worldTwoRise(st.at, st.toward, st.toward:Cross(UP))
end

-------------------------------------------------------------------------------------------------------------
-- credits and the end screen (their own ScreenGui, over everything)
-------------------------------------------------------------------------------------------------------------
local screen: ScreenGui? = nil
local function endGui(): ScreenGui
	if screen and screen.Parent then
		return screen
	end
	local g = Instance.new("ScreenGui")
	g.Name = "EndCredits"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 60
	g.Parent = player:WaitForChild("PlayerGui")
	local sc = Instance.new("UIScale")
	local cam = workspace.CurrentCamera
	sc.Scale = if cam then math.clamp(cam.ViewportSize.Y / 900, 0.55, 1.2) else 1
	sc.Parent = g
	screen = g
	return g
end

-- MADE BY: the game's group (Config.GROUP_ID), its owner, then the collaborators listed in
-- Config.CREDITS_TEAM (Roblox usernames: shown as "Display Name (@username)").
local function makers(): { string }
	local list = {}
	-- the studio first: the game's group (Config.GROUP_ID, Atlas Interactive Inc)
	pcall(function()
		if Config.GROUP_ID and Config.GROUP_ID > 0 then
			table.insert(list, game:GetService("GroupService"):GetGroupInfoAsync(Config.GROUP_ID).Name)
		end
	end)
	pcall(function()
		if game.CreatorId > 0 then
			if game.CreatorType == Enum.CreatorType.Group then
				local g = game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId).Name
				if not table.find(list, g) then
					table.insert(list, g)
				end
			else
				local user = Players:GetNameFromUserIdAsync(game.CreatorId)
				local info = game:GetService("UserService"):GetUserInfosByUserIdsAsync({ game.CreatorId })[1]
				table.insert(list, if info and info.DisplayName ~= user then info.DisplayName .. "  (@" .. user .. ")" else user)
			end
		end
	end)
	for _, user in (Config.CREDITS_TEAM or {}) :: { string } do
		local line = user
		pcall(function()
			local id = Players:GetUserIdFromNameAsync(user)
			local info = game:GetService("UserService"):GetUserInfosByUserIdsAsync({ id })[1]
			if info and info.DisplayName ~= info.Username then
				line = info.DisplayName .. "  (@" .. info.Username .. ")"
			elseif info then
				line = info.Username
			end
		end)
		if not table.find(list, line) then
			table.insert(list, line)
		end
	end
	if #list == 0 then
		table.insert(list, MAKERS_FALLBACK)
	end
	return list
end

-- The credit lines: { kind, text } (kind "title" | "head" | "line" | "gap").
local function creditLines(): { { string } }
	local L = {}
	local function add(kind: string, text: string?)
		table.insert(L, { kind, text or "" })
	end
	add("title", string.upper(Config.GAME_NAME or "Mow And Grow"))
	add("gap")
	add("head", "STARRING")
	for _, p in Players:GetPlayers() do
		add("line", p.DisplayName .. "  (@" .. p.Name .. ")")
	end
	add("gap")
	add("head", "AND")
	add("line", "Mayor Thistlewick  as himself")
	add("gap")
	add("head", "THE BOSSES")
	local Moves = require(MowALawn:WaitForChild("BossMoves")) :: any
	for z = 1, #Config.ZONES do
		local def = Config.ZONES[z]
		local b = def and def.boss
		local m = Moves.list[z]
		if b then
			add("line", b.name .. (if m and m.title then "  ·  " .. m.title else ""))
		end
	end
	add("gap")
	add("head", "THE VALLEY")
	for z = 1, #Config.ZONES do
		add("line", Config.ZONES[z].name)
	end
	add("gap")
	add("head", "MADE BY")
	for _, name in makers() do
		add("line", name)
	end
	add("gap")
	add("head", "SPECIAL THANKS")
	add("line", "Every blade of grass that was mowed in the making of this valley")
	add("line", "And you, for playing")
	add("gap")
	add("head", Config.WORLD2.title .. ": " .. Config.WORLD2.name)
	add("line", "Something is waking up...  " .. string.lower(Config.WORLD2.soon))
	add("gap")
	add("gap")
	add("title", "THANK YOU FOR PLAYING!")
	return L
end

-- The credits roll up the screen over a dark sky; `skip` (or the end of the roll) ends it.
local function rollCredits(): boolean
	local g = endGui()
	local bg = Instance.new("Frame")
	bg.Name = "Credits"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	bg.BackgroundTransparency = 0 -- (the film ends on black: no glimpse of the live world before the roll)
	bg.Parent = g
	local roll = Instance.new("Frame")
	roll.BackgroundTransparency = 1
	roll.AnchorPoint = Vector2.new(0.5, 0)
	roll.Size = UDim2.fromOffset(900, 10)
	roll.Parent = bg
	local y = 0
	for _, l in creditLines() do
		local kind, text = l[1], l[2]
		local h = if kind == "title" then 70 elseif kind == "head" then 40 elseif kind == "gap" then 34 else 32
		if kind ~= "gap" then
			local t = UI.text(roll, text, UDim2.new(1, 0, 0, h), { pos = UDim2.fromOffset(0, y), stroke = if kind == "title" then 5 else 2.5 })
			if kind == "title" then
				UI.gradient(t, GOLD)
			elseif kind == "head" then
				t.TextColor3 = GOLD
			end
		end
		y += h + 6
	end
	roll.Size = UDim2.fromOffset(900, y)
	local skip = UI.button(bg, "SKIP  >>", Color3.fromRGB(70, 70, 86), UDim2.fromOffset(150, 48), function()
		playing = false
	end, { pos = UDim2.new(1, -24, 1, -18), anchor = Vector2.new(1, 1), name = "CreditsSkip" })
	local _ = skip
	local view = (g.AbsoluteSize.Y > 0 and g.AbsoluteSize.Y or 800) / ((g:FindFirstChildOfClass("UIScale") :: UIScale).Scale)
	local from, to = view + 20, -y - 20
	local len = math.clamp((view + y) / 55, 18, 40)
	local t0 = os.clock()
	while playing and os.clock() - t0 < len do
		local k = (os.clock() - t0) / len
		roll.Position = UDim2.new(0.5, 0, 0, from + (to - from) * k)
		task.wait()
	end
	return playing
end

-- PLAY AGAIN (back to the lobby: a new run) and "???" (the next world: locked, not out yet).
local function endScreen(d: any)
	local g = endGui()
	local old = g:FindFirstChild("Credits")
	local bg = Instance.new("Frame")
	bg.Name = "EndScreen"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	bg.BackgroundTransparency = 0 -- (straight from black: the credits, or the film's fade)
	bg.Parent = g
	if old then
		old:Destroy()
	end
	local W, H = 620, 380
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(W, H)
	box.Parent = bg
	local _, face = Skin.frame(box, "ui_card", Vector2.new(W, H), { name = "Card" })
	local title = UI.text(face, "THE END...?", UDim2.new(1, 0, 0, 66), { pos = UDim2.fromOffset(0, 6), stroke = 5 })
	UI.gradient(title, GOLD)
	-- (report #16) the run medal you earned (Config.RUN_MEDALS)
	local medal = ""
	for _, m in Config.RUN_MEDALS do
		if m.id == d.medal then
			medal = "   " .. m.name:upper() .. " MEDAL!"
		end
	end
	local time = if (d.time or 0) > 0 then "Run time " .. Format.clock(d.time) .. (if d.best then "   NEW BEST!" else "") .. medal .. "   ·   " else ""
	local stats = UI.text(face, time .. "+" .. Format.short(d.gems or 0) .. " gems", UDim2.new(1, -40, 0, 28), { pos = UDim2.fromOffset(20, 78), stroke = 0, color = Color3.fromRGB(120, 80, 40) })
	local _ = stats
	local blurb = UI.text(face, "The valley is mowed... but something stirs in the corrupted lands beyond.", UDim2.new(1, -40, 0, 26), { pos = UDim2.fromOffset(20, 114), stroke = 0, color = Color3.fromRGB(140, 96, 60) })
	blurb.TextWrapped = true
	local preview = type(d.close) == "function" -- (a preview from the DEV panel: nobody is sent anywhere)
	local chosen = false
	local again: TextButton
	again = UI.button(face, if preview then "BACK TO GAME" else "PLAY AGAIN", GREEN, UDim2.fromOffset(250, 64), function()
		if chosen then
			return
		end
		chosen = true
		Sound.play("purchase")
		if preview then
			d.close()
			return
		end
		again.Text = "SEE YOU THERE!"
		State.fire("Seen", "ending", "again") -- the server sends you back to the lobby for a new run
	end, { pos = UDim2.new(0.5, -14, 0, 176), anchor = Vector2.new(1, 0), name = "PlayAgain" })
	Skin.press(again)
	local mystery = UI.button(face, "? ? ?", Color3.fromRGB(70, 50, 110), UDim2.fromOffset(250, 64), function() end, { pos = UDim2.new(0.5, 14, 0, 176), anchor = Vector2.new(0, 0), name = "NextWorld" })
	local note = UI.text(face, "", UDim2.new(1, -40, 0, 24), { pos = UDim2.fromOffset(20, 252), stroke = 2, color = MYSTERY })
	mystery.Activated:Connect(function()
		Sound.play("denied")
		note.Text = Config.WORLD2.title .. ": " .. Config.WORLD2.name .. ". " .. Config.WORLD2.soon .. ", gardener."
		local base = mystery.Position
		for i = 1, 6 do
			mystery.Position = base + UDim2.fromOffset(if i % 2 == 0 then 6 else -6, 0)
			task.wait(0.04)
		end
		mystery.Position = base
	end)
	-- the "???" breathes a strange purple
	task.spawn(function()
		while mystery.Parent do
			local k = 0.5 + 0.5 * math.sin(os.clock() * 2.5)
			mystery.BackgroundColor3 = Color3.fromRGB(70, 50, 110):Lerp(MYSTERY, k * 0.6)
			task.wait()
		end
	end)
	local left = UI.text(face, "", UDim2.new(1, -40, 0, 22), { pos = UDim2.fromOffset(20, H - 70), stroke = 0, color = Color3.fromRGB(140, 96, 60) })
	local endsAt = (d.receivedAt or os.clock()) + (d.wait or 120)
	task.spawn(function()
		while left.Parent do
			left.Text = if preview then "DEV preview: BACK TO GAME carries on with your run"
				else ("Back to the lobby in %d s"):format(math.max(0, math.ceil(endsAt - os.clock())))
			task.wait(0.25)
		end
	end)
	Skin.popIn(box, 0)
end


-------------------------------------------------------------------------------------------------------------
-- start and end
-------------------------------------------------------------------------------------------------------------
local savedHud = true

local function controls(on: boolean)
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			local c = ((require :: any)(module)):GetControls()
			if on then
				c:Enable()
			else
				c:Disable()
			end
		end
	end)
end

-- The film is over (or skipped): clear the set, give the camera and the light back.
local function stopFilm()
	Film.stop(STEP)
	FilmVoice.clear()
	IntroCast.cleanup()
	IntroUi.close()
	-- world 2's corruption, the demon, the glitches, the grade
	if corrupt then
		corrupt.destroy()
		corrupt = nil
	end
	demon = nil -- (it lives in the set)
	demonReady = false
	if ungrade then
		ungrade(0.3)
		ungrade = nil
	end
	Glitch.clear()
	if set then
		set:Destroy()
		set = nil
	end
	mayor = nil
	for name in table.clone(music) do
		stopCue(name, 1)
	end
end

local function film(P: Plan): boolean
	local actors = IntroCast.party(P.cast, P.fwd, P.right)
	local m = IntroCast.mayor(P.mayorAt, P.fwd) -- (facing out over his meadow at first)
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
	if not lastBladeScenes(P) then
		return false
	end
	if not valleyScenes(P) then
		return false
	end
	if not homeScenes(P, m, actors) then
		return false
	end
	if not partyScenes(P, m, actors) then
		return false
	end
	return twistScenes(P, m, actors)
end

-- Play the ending. `d`: the server's runComplete data ({ gems, time, best, wait }).
function Ending.play(d: any)
	local cam = workspace.CurrentCamera
	if played or not cam then
		return
	end
	played = true
	d.receivedAt = os.clock() -- (the server sends everyone back d.wait seconds after this)
	-- after the boss's own death scene (client/BossFx flies the camera itself): wait for it to hand back
	local t = os.clock()
	task.wait(if d.preview then 0.3 else 5)
	while cam.CameraType ~= Enum.CameraType.Custom and os.clock() - t < 18 do
		task.wait(0.1)
	end
	savedHud = UI.gui.Enabled
	UI.gui.Enabled = false
	controls(false)
	local skipped = false
	IntroUi.open(function()
		skipped = true
		Film.playing = false
	end)
	IntroUi.fade(0, 0.8)
	-- the black cover is up: the voices start being made, the sounds load, the far places stream in
	local lines = {}
	for _, k in ORDER do
		table.insert(lines, { text = LINES[k], who = "mayor" })
	end
	table.insert(lines, { text = LINES.D1, who = "demon" })
	FilmVoice.prepare(lines)
	FilmAudio.begin({ "calmMusic", "flightMusic", "partyMusic", "dreadMusic", "creditsMusic", "heartbeat", "swell", "boom", "crowd", "applause", "impact", "slam", "bigHit", "rumble", "growl", "growl2", "suck", "drone", "revStop", "revBuild", "eerie", "servo", "whomp", "thud" })
	local P = plan()
	local spots = { P.arena, P.camp, P.sprout }
	for _, a in P.areas do
		table.insert(spots, a.pos)
	end
	streamIn(spots)
	FilmVoice.waitFor(LINES.E1, 1.5)
	Film.start(STEP)
	local ok = false
	if not skipped then
		local good, res = pcall(film, P)
		if not good then
			warn("[Ending] " .. tostring(res))
		end
		ok = good and res == true
	end
	IntroUi.fade(0, 0.5)
	task.wait(0.5)
	stopFilm()
	FilmAudio.hush(0.8)
	cue("credits", "creditsMusic", { fade = 1.5 })
	if ok and not skipped then
		playing = true -- (the credits' own flag: their SKIP ends them)
		rollCredits()
		playing = false
	end
	local c = music.credits
	if c then
		c.fade(0.6, 2)
	end
	if d.preview then
		-- (a DEV panel preview: BACK TO GAME on the end screen puts everything back, and it can be played again)
		d.close = function()
			if screen then
				screen:Destroy()
				screen = nil
			end
			FilmAudio.finish(1)
			UI.gui.Enabled = savedHud
			controls(true)
			played = false
		end
	end
	endScreen(d)
	-- you stay on the end screen until you choose or the server sends everyone back; the HUD stays hidden
	local _ = savedHud
end

-- The DEV panel's PLAY ENDING: the whole ending, the credits and the end screen, on this client only, without
-- finishing the run (nobody is sent anywhere; BACK TO GAME on the end screen carries on).
function Ending.preview()
	task.spawn(Ending.play, { gems = 0, time = 0, preview = true })
end

return Ending
