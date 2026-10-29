-- The ending (owner, 27 Oct: "if you defeat the final boss make a cool fitting ending story with a cinematic
-- cutscene ... with end credits at the end where it prompts you to go to the next world or do the same mission
-- again"; 28 Oct: "remake it ... make it feel like a real movie with a story attached to it"). Played on every
-- client when the last area's boss falls (server/Run sends runComplete with `ending = true`). It closes the story
-- the opening film (client/Intro) starts: Mayor Thistlewick's valley, overgrown since the pink got into its
-- guardians, is mowed at last.
-- Remade on 29 Oct the way the opening was (owner: "do the same u did for intro for the outro"; of both films:
-- "sometimes the camera just pans to the ground or just some useless thing"): no flight over the ground, no walking,
-- no shot of nothing. Every shot has someone in it doing something; the cameras keep out of the trees and the ruins
-- (the scenery as boxes: a raycast goes through most of it); every shot was checked on a contact sheet in Studio
-- (client/FilmSheet).
--   I.   THE LAST BLADE: in its arena the last guardian kneels in front of the Mowers (copies of everyone's avatars,
--        where they beat it), the glitch still in it; close on its face the pink TEARS out of it [an impact frame, in
--        gold]; its own colours come back, it stands up tall over them... and bows; then it goes up as light and the
--        sun breaks through over the Mowers ("And just like that... the last wild grass in the valley was gone.");
--   II.  THE VALLEY BREATHES: the guardians back home in their own lands, free, in their own colours, one after
--        another, each bowing as its land's name comes up; the Dandelion King last, the one the pink fell on first;
--   III. HOMECOMING: sunset; the Mayor alone on his soapbox, looking out over his meadow... THUD: behind him the Mowers
--        drop out of the sky one after another, as they did in the opening; he spins round: "You... you actually DID
--        it!";
--   IV.  THE CELEBRATION: cheering, confetti, fireworks over the camp at dusk, and the group photo ("Everyone... say
--        GRASS!"), frozen for a moment as a snapshot;
--   V.   THE CREDITS (owner, 28 Oct: "end credits, maybe take inspiration from JJK"): an anime ending, calm
--        after the party: STARRING the party, each in a panel of their own colour; the eight guardians, free at
--        last, in their own colours; the Mayor "as himself"; the makers (client/FilmPanels);
--   VI.  AFTER THE CREDITS (owner, 27 Oct: "teasing world 2, a corrupt world with a demon glitch type of enemy and
--        boss"; 28 Oct: "make the entrance of the corrupted guy cooler, maybe he's coming out of a glitch black
--        hole that's sucking the island up ... and captures the island and the players"): night, peace and
--        quiet... the picture stutters; over the meadow a black hole tears open in pink (client/GlitchHole); it
--        pulls lumps of the island up into it, then the Mowers and the Mayor; an eye opens in the dark; the glitch
--        demon (client/Demon) heaves itself up out of the hole: "This valley... is MINE."; it roars and the hole
--        swallows everything. TO BE CONTINUED; WORLD 2, THE CORRUPTED VALLEY, COMING SOON; your progress is safe.
--        Then the end screen: PLAY AGAIN (back to the lobby for a new run) and a locked "???" (world 2).
-- Impact frames (client/FilmPanels) on the guardian set free and the three big hits after the credits. Camera, light
-- and grade: client/Film; music and sound: client/FilmAudio (licensed library audio); the effects: client/FilmVfx
-- (VFX Forge templates, the old code as the fallback); the Mayor's mumble: client/Babble; the actors and the screen:
-- client/IntroCast, client/IntroUi, as in the opening. SKIP jumps to the scene after the credits (from the film or
-- the credits); that scene always plays, and SKIP comes back on its last title, for the end screen.
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
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
local Babble = require(script.Parent.Babble) -- (28 Oct) the Mayor's mumble voice
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local Confetti = require(script.Parent.Confetti)
local Glitch = require(script.Parent.Glitch) -- (27 Oct) world 2's corruption: screen glitches
local Demon = require(script.Parent.Demon) -- the glitch demon
local Corruption = require(script.Parent.Corruption) -- the sky tearing, lightning
local GlitchHole = require(script.Parent.GlitchHole) -- (28 Oct) the black hole it comes out of
local FilmPanels = require(script.Parent.FilmPanels) -- (28 Oct) the impact frames, the credits' pages
local BossMoves = require(MowALawn:WaitForChild("BossMoves"))
local BossRig = require(MowALawn:WaitForChild("BossRig"))
local BossView = require(script.Parent.BossView) -- (28 Oct evening) the last guardian, freed, in the first scene
local FilmVfx = require(script.Parent.FilmVfx) -- (29 Oct) the effects as VFX Forge templates (old ones: the fallback)
local HitFx = require(script.Parent.HitFx) -- (29 Oct) the dust where the Mowers land

local Ending = {}
local player = Players.LocalPlayer

local UP = Vector3.yAxis
local GREEN = Color3.fromRGB(110, 220, 70)
local GOLD = Color3.fromRGB(255, 214, 60)
local MYSTERY = Color3.fromRGB(170, 110, 255)
local MAYOR = "Mayor Thistlewick"
local MAKERS_FALLBACK = "The Mow And Grow team" -- the credits name the game's owner (group or user) when they can
local STEP = "MowEnding"

local played = false
-- what SKIP does: in the film it jumps to the scene after the credits; in the credits, the same; that scene always
-- plays (owner, 28 Oct evening: "if you skip it should show you the end teaser"), SKIP comes back on its last title
-- and goes to the end screen
local chapter = "film" -- "film" | "skip" | "credits" | "teaser" | "title"
local skippedAll = false

local LINES = {
	E1 = "And just like that... the last wild grass in the valley was gone.",
	E2 = "Meadow by meadow, hill by hill... the whole valley could breathe again.",
	E3 = "You... you actually DID it!",
	E4 = "Every meadow, every hill, every last blade... MOWED!",
	E5 = "The valley is SAVED! Now, everyone... say GRASS!",
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
-- keeping the camera out of the scenery (29 Oct, as client/Intro does): most of the trees and props can't be hit
-- by a raycast (CanQuery is off on them), so Film.sees can't see them. The scenery round the film's places is
-- taken as boxes, in a grid (Ending.play builds it under the black cover, and drops it at the end).
-------------------------------------------------------------------------------------------------------------
type Box = { cf: CFrame, h: Vector3, p: Vector3, r: number }
type Boxes = { list: { Box }, grid: { [number]: { number } }, mark: { [number]: number }, tick: number }
local CELL = 32
local scenery: Boxes? = nil

local function cellOf(v: number): number
	return math.floor(v / CELL)
end

-- The scenery within `r` studs (sideways) of any of `places`, as boxes. Thousands of parts: spread over frames.
local function sceneryBoxes(places: { { at: Vector3, r: number } }): Boxes
	local B: Boxes = { list = {}, grid = {}, mark = {}, tick = 0 }
	local world = workspace:FindFirstChild("World")
	local n = 0
	for _, name in { "Visuals", "Hub", "Ground", "Gates", "Patches", "Ways", "Pads", "Arenas" } do
		local f = world and world:FindFirstChild(name)
		if f then
			for _, d in f:GetDescendants() do
				n += 1
				if n % 3000 == 0 then
					task.wait()
				end
				if d:IsA("BasePart") and d.Transparency < 0.95 and d.Size.Magnitude > 3 then
					local p = d.Position
					local near = false
					for _, pl in places do
						if flat(p - pl.at).Magnitude < pl.r then
							near = true
							break
						end
					end
					if near then
						local cf, h = d.CFrame, d.Size / 2
						table.insert(B.list, { cf = cf, h = h, p = p, r = h.Magnitude })
						local id = #B.list
						-- (the cells its upright bounding box covers)
						local ex = math.abs(cf.XVector.X) * h.X + math.abs(cf.YVector.X) * h.Y + math.abs(cf.ZVector.X) * h.Z
						local ez = math.abs(cf.XVector.Z) * h.X + math.abs(cf.YVector.Z) * h.Y + math.abs(cf.ZVector.Z) * h.Z
						for ix = cellOf(p.X - ex), cellOf(p.X + ex) do
							for iz = cellOf(p.Z - ez), cellOf(p.Z + ez) do
								local key = ix * 65536 + iz
								local cell = B.grid[key]
								if cell then
									table.insert(cell, id)
								else
									B.grid[key] = { id }
								end
							end
						end
					end
				end
			end
		end
	end
	return B
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

-- Whether the line from `a` to `b` goes through any of the scenery's boxes.
local function blocked(a: Vector3, b: Vector3): boolean
	local B = scenery
	if not B then
		return false
	end
	B.tick += 1
	local tick = B.tick
	local ab = b - a
	local len2 = math.max(ab:Dot(ab), 1e-6)
	for ix = cellOf(math.min(a.X, b.X)), cellOf(math.max(a.X, b.X)) do
		for iz = cellOf(math.min(a.Z, b.Z)), cellOf(math.max(a.Z, b.Z)) do
			local cell = B.grid[ix * 65536 + iz]
			if cell then
				for _, id in cell do
					if B.mark[id] ~= tick then
						B.mark[id] = tick
						local bx = B.list[id]
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
				end
			end
		end
	end
	return false
end

-- Whether a camera at `p` would stand inside something of the scenery.
local function inside(p: Vector3): boolean
	return blocked(p - UP * 0.1, p + UP * 0.1)
end

-- Whether `from` sees `to`: nothing solid between them (a raycast: the ground, the buildings) and none of the
-- scenery's boxes either (the trees and props a raycast goes through).
local function sees(from: Vector3, to: Vector3): boolean
	return Film.sees(from, to) and not blocked(from, to)
end

local function turn(v: Vector3, deg: number): Vector3
	return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v)
end

local YAWS = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 }

-- Which way the sun lies (flat) at `clock` o'clock, to keep faces in the light: read with the clock set for a
-- moment (the film sets its own light afterwards).
local function sunAt(clock: number): Vector3
	local was = Lighting.ClockTime
	Lighting.ClockTime = clock
	local d = Lighting:GetSunDirection()
	Lighting.ClockTime = was
	return unit(flat(d), Vector3.zAxis)
end

-- How well a camera at `p` sees a shot: 2 for each of `targets` in sight, 1 off for each edge of the frame (`half`
-- degrees either side of the first target) with something solid within 30 studs of the lens, 6 off if it stands
-- inside something. (Studio's test, 28 Oct: the hole half behind a roof, and half the frame filled by whatever
-- stood beside the camera.)
local function shotScore(p: Vector3, targets: { Vector3 }, half: number): number
	local score = 0
	for _, t in targets do
		if sees(p, t) then
			score += 2
		end
	end
	if (targets[1] - p).Magnitude > 0.5 then
		local cf = CFrame.lookAt(p, targets[1])
		for _, a in { -half, half } do
			if not sees(p + (cf * CFrame.Angles(0, math.rad(a), 0)).LookVector * 30, p) then
				score -= 1
			end
		end
	end
	if inside(p) then
		score -= 6
	end
	return score
end

-- The camera spot from `list` that sees the shot best (earlier ones win ties).
local function bestSpot(list: { Vector3 }, targets: { Vector3 }, half: number?): Vector3
	local best, bestScore = list[1], -math.huge
	for _, p in list do
		local s = shotScore(p, targets, half or 35)
		if s > bestScore then
			best, bestScore = p, s
		end
	end
	return best
end

-------------------------------------------------------------------------------------------------------------
-- where everything is
-------------------------------------------------------------------------------------------------------------
-- Where area z's guardian was fought: its arena's middle.
local function arenaOf(z: number): Vector3
	local w = workspace:FindFirstChild("World")
	local arenas = w and w:FindFirstChild("Arenas")
	local a = arenas and arenas:FindFirstChild("Arena" .. z)
	if a and a:IsA("Model") then
		return a:GetPivot().Position
	end
	local at = w and w:GetAttribute("Arena" .. z)
	if typeof(at) == "Vector3" then
		return at
	end
	return Config.zoneCentre(z)
end

type Plan = { arena: Vector3, areas: { { pos: Vector3, name: string } }, camp: Vector3, fwd: Vector3, right: Vector3, cast: Vector3, mayorAt: Vector3, sprout: Vector3 }

local function plan(): Plan
	local n = #Config.ZONES
	local w = workspace:FindFirstChild("World")
	local arena = arenaOf(n)
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

local filmGen = 0 -- (bumps when SKIP restarts the film: a rocket already up doesn't burst into the next scene)
local FIREWORK_COLORS = { GOLD, Color3.fromRGB(255, 110, 150), Color3.fromRGB(110, 220, 255), GREEN, Color3.fromRGB(255, 150, 60), Color3.fromRGB(200, 140, 255) }
local function firework(at: Vector3, big: boolean?)
	local color = FIREWORK_COLORS[math.random(1, #FIREWORK_COLORS)]
	-- (VFX Forge's firework: the rocket, the burst, its light; the old one below if it's missing)
	if FilmVfx.play("Firework", at, { color = color, scale = if big then 1.25 else 1 }) then
		FilmAudio.sfx("swingHand", { volume = 0.9, pitch = 0.55 + math.random() * 0.15 }) -- (the whistle up)
		local gen = filmGen
		task.delay(0.8, function()
			if Film.playing and gen == filmGen then
				FilmAudio.sfx("boom", { volume = if big then 1 else 0.6 + math.random() * 0.3, pitch = 1.25 + math.random() * 0.35 })
			end
		end)
		return
	end
	local rise = spark(at - UP * 30, color, 0.6)
	TweenService:Create(rise, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at }):Play()
	FilmAudio.sfx("swingHand", { volume = 0.9, pitch = 0.55 + math.random() * 0.15 }) -- (the whistle up)
	local gen = filmGen
	task.delay(0.8, function()
		rise:Destroy()
		if not Film.playing or gen ~= filmGen then
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
	local tts = len ~= nil
	local babbling = false
	if not len and not narrated and key ~= "D1" then
		-- (the Mayor talks in client/Babble's mumble; the narration is storybook text over the pictures)
		len, level = Babble.line(line)
		babbling = Babble.voice() ~= "none"
	end
	local dur = len or math.clamp(#line * 0.062, 1.8, 5.5)
	if key == "D1" and not tts then
		-- (no voice for the demon, owner 28 Oct evening: Config.FILM.demonVoice) its words over a low growl
		FilmAudio.sfx("growl", { volume = 0.9, pitch = 0.5 })
	end
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
	if tts or babbling then
		FilmAudio.duck(if babbling then 0.28 else 0.42, 0.25)
		task.delay(dur, function()
			if Film.playing then
				FilmAudio.duck(0, 0.8)
			end
		end)
	end
	return dur
end

local LOOKS = {
	morning = { ClockTime = 8.2, ExposureCompensation = 0.15, atmosphere = { Density = 0.26, Haze = 1.2, Glare = 0.8 } },
	day = { ClockTime = 13.5, ExposureCompensation = 0.05, atmosphere = { Density = 0.25, Haze = 0.9, Glare = 0.5 } },
	golden = { ClockTime = 17.4, ExposureCompensation = 0.05, atmosphere = { Density = 0.28, Haze = 1.4, Glare = 1.0 } },
	dusk = { ClockTime = 18.35, ExposureCompensation = -0.1, atmosphere = { Density = 0.32, Haze = 1.8, Glare = 0.6 } },
	night = { ClockTime = 21.6, ExposureCompensation = -0.2, atmosphere = { Density = 0.36, Haze = 1.2, Glare = 0 } },
}

-------------------------------------------------------------------------------------------------------------
-- I. THE LAST BLADE: the last guardian, free
-------------------------------------------------------------------------------------------------------------
-- (owner, 28 Oct evening: the ending began on "just a blank ground"; 29 Oct: "do the same u did for intro for the
-- outro") 1A: in its arena the last guardian kneels in front of the Mowers, beaten, the glitch still in it (its
-- corrupted colours, pink eyes, twitching); low behind the Mowers we creep in. 1B: close on its face the pink tears
-- out of it in a spray of glitch blocks [an impact frame, in gold]: its own colours come back. 1C: from the side,
-- wide: it stands up tall over the Mowers... and bows its head to them; they cheer. 1D: low behind them again: it
-- goes up as light and the sun breaks through. (If a fight's boss is still in client/BossView, it's left alone:
-- just the Mowers and the light.)
local guardianShown = false
local guardianEyes: { BasePart } = {}
local guardianEyesStop: (() -> ())? = nil
local guardianEyesFx: { Model } = {} -- (VFX Forge: the glints riding on them)

local function eyesOut()
	if guardianEyesStop then
		guardianEyesStop()
		guardianEyesStop = nil
	end
	for _, fx in guardianEyesFx do
		FilmVfx.stop(fx)
	end
	table.clear(guardianEyesFx)
	for _, g in guardianEyes do
		g:Destroy()
	end
	table.clear(guardianEyes)
end

local function guardianOff()
	eyesOut()
	if guardianShown then
		guardianShown = false
		BossView.hide()
	end
end

-- its scale for its fight height (as server/Boss and client/Intro work it out)
local function guardianScale(z: number): number
	local moves = BossMoves.get(z)
	local rig = BossRig.load(moves.rig)
	local h = if rig then rig.bounds[2][2] else 7
	return moves.height / math.max(1, h)
end

-- the glitch's pink in its eyes (small glowing balls on its eye points, every frame). (29 Oct, as the opening's: with
-- a light on them and bigger, the guardians' faces read as pink blobs on the contact sheet.)
local function guardianPinkEyes(H: number)
	eyesOut()
	local names = BossView.attAll("att_eye")
	for _ in names do
		local g = spark(Vector3.zero, Color3.fromRGB(255, 40, 170), math.max(0.4, H * 0.02))
		g.Shape = Enum.PartType.Ball
		table.insert(guardianEyes, g)
	end
	guardianEyesStop = Film.every(function()
		for i, name in names do
			local at = BossView.attWorld(name)
			if at and guardianEyes[i] then
				guardianEyes[i].CFrame = CFrame.new(at)
			end
		end
	end)
	-- (VFX Forge) each eye burning pink, riding on its glint (placed next frame)
	local eyes = table.clone(guardianEyes)
	task.defer(function()
		for _, g in eyes do
			-- (29 Oct, the ending's contact sheet: at H / 22 the close-up's eyes were two big pink glows)
			local fx = g.Parent and FilmVfx.play("PinkEye", g.CFrame, { follow = g, scale = H / 34 })
			if fx then
				table.insert(guardianEyesFx, fx)
			end
		end
	end)
end

-- the glitch tearing out of it: blocks of pink, cyan, white and void flung out of its body, spinning and fading
local function glitchOut(feet: Vector3, H: number)
	-- (VFX Forge's version; the old tweened blocks if it's missing)
	if FilmVfx.play("GlitchTearOut", CFrame.new(feet + UP * (H * 0.55)), { scale = H / 14 }) then
		return
	end
	local colors = { Color3.fromRGB(255, 40, 170), Color3.fromRGB(60, 240, 255), Color3.fromRGB(255, 214, 240), Color3.fromRGB(22, 8, 30) }
	local mid = feet + UP * (H * 0.55)
	for _ = 1, 26 do
		local from = feet + UP * (H * (0.2 + math.random() * 0.7)) + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * (H * 0.45)
		local dir = unit(from - mid + UP * (H * 0.25), UP)
		local c = colors[math.random(1, #colors)]
		local p = spark(from, c, H * (0.035 + math.random() * 0.05))
		if c == colors[4] then
			p.Material = Enum.Material.SmoothPlastic
		end
		local t = 0.7 + math.random() * 0.6
		TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = from + dir * (H * (0.7 + math.random() * 0.9)),
			Orientation = Vector3.new(math.random(-180, 180), math.random(-180, 180), 0),
			Size = Vector3.one * 0.05,
			Transparency = 1,
		}):Play()
		task.delay(t + 0.05, function()
			p:Destroy()
		end)
	end
end

-- Where the last guardian kneels and where the Mowers stand in front of it (in its arena), turned so that all of the
-- scene's shots see them (the ruins' pillars, the trees round the arena: the scenery's boxes), with the morning sun
-- on its face. `d`: from the guardian toward the Mowers (and the cameras behind them); `s`: the side 1C films from.
type ArenaPlan = { feet: Vector3, d: Vector3, side: Vector3, s: number, H: number, party: Vector3 }
local function arenaPlan(P: Plan): ArenaPlan
	local n = #Config.ZONES
	local H = BossMoves.get(n).height
	local feet = ground(P.arena)
	local toCamp = unit(flat(P.camp - feet), P.fwd)
	local sun = sunAt(LOOKS.morning.ClockTime)
	local chest, head, high = feet + UP * (H * 0.4), feet + UP * (H * 0.65), feet + UP * (H * 1.05)
	local best: ArenaPlan = { feet = feet, d = toCamp, side = toCamp:Cross(UP), s = 1, H = H, party = ground(feet + toCamp * (H * 0.8)) }
	local bestScore = -math.huge
	for _, y in YAWS do
		local d = turn(toCamp, y)
		local side = d:Cross(UP)
		local pc = ground(feet + d * (H * 0.8))
		local score = 2 * math.max(0, d:Dot(sun))
		-- the Mowers stand on the arena's floor, not up a step or in a pillar
		if math.abs(pc.Y - feet.Y) > 4 then
			score -= 6
		end
		for _, k in { -6, 0, 6 } do
			local p = pc + side * k
			if blocked(p + UP * 0.6, p + UP * 6) then
				score -= 4
			end
		end
		-- 1A and 1D: low behind them
		for _, cam in { pc + d * 8 + side * 2.2 + UP * 2.6, pc + d * 10.8 - side * 2.4 + UP * 1.4 } do
			if inside(cam) then
				score -= 6
			end
			for _, t in { chest, head, high } do
				if sees(cam, t) then
					score += 1
				end
			end
		end
		-- 1B: close on its face
		local camB = head + d * (H * 0.6) + side * (H * 0.12)
		if inside(camB) then
			score -= 4
		elseif sees(camB, head) then
			score += 1
		end
		-- 1C: from one side or the other, wide
		local mid = feet:Lerp(pc, 0.5)
		local bestC, sC = -math.huge, 1
		for _, s in { 1, -1 } do
			local camC = mid + side * (s * H * 1.15) + d * (H * 0.1) + UP * (H * 0.2)
			local sc = if inside(camC) then -4 else 0
			for _, t in { chest, head, pc + UP * 2.5 } do
				if sees(camC, t) then
					sc += 1
				end
			end
			if sc > bestC then
				bestC, sC = sc, s
			end
		end
		score += bestC
		if score > bestScore then
			bestScore = score
			best = { feet = feet, d = d, side = side, s = sC, H = H, party = pc }
		end
	end
	return best
end

local function lastBladeScenes(P: Plan, A: ArenaPlan, mowers: { IntroCast.Actor }): boolean
	local n = #Config.ZONES
	local moves = BossMoves.get(n)
	local H, feet, d, side, pc = A.H, A.feet, A.d, A.side, A.party
	Film.light(LOOKS.morning, 0)
	Film.grade("gloom", 0)
	Film.glow(0.12, 24, 0.1)
	Film.vignette(0.55, 0)
	IntroUi.fade(1, 1.2)
	bed("amb", "ambWind", 1.2, 2)
	-- "the last wild grass in the valley was gone": mowed by now, but not in a DEV preview (Studio's test, 28 Oct
	-- evening: the shots were full of it)
	IntroCast.hideGrass(true, n)
	Film.refreshSight()
	local chest = feet + UP * (H * 0.45)
	-- (the cameras behind the Mowers look through a gap in their row: 4.4 studs apart, the middle one in the middle)
	local gap = if #mowers % 2 == 1 then 2.2 else 0
	-- the Mowers, where they beat it, facing it
	for _, a in mowers do
		a.show()
		a.look(feet + UP * (H * 0.6))
	end
	-- (a fight's boss still in client/BossView, e.g. a DEV preview in a fight: it's left alone, just the light)
	local alone = BossView.get() ~= nil
	if not alone then
		guardianShown = true
		BossView.show(moves.rig, CFrame.lookAt(feet, feet + d), guardianScale(n), moves)
		BossView.rageNow()
		-- (its own clock: kneeling till 3.3 s, the bow at 5.6 s, gone into the light from 7.9 s)
		BossView.act("freed", { free = 3.3, nod = 5.6, fade = 7.9 })
		guardianPinkEyes(H)
		local function head(): Vector3
			return BossView.attWorld("att_head_center") or (feet + UP * (H * 0.65))
		end
		local drone = FilmAudio.sfx("drone", { volume = 0.35, pitch = 0.8 })
		for _, t in { 0.7, 1.9, 2.7 } do
			Film.at(t, function()
				Glitch.burst(0.25, 0.1)
				FilmAudio.glitch(0.3)
				BossView.flinch(false)
			end)
		end
		-- 1A: beaten, on its knees in front of the Mowers, the glitch twitching in it; low behind them, creeping in
		local ok = Film.run(3.0, function(k)
			local pos = pc + d * (8 - 1.6 * inOut(k)) + side * gap + UP * 2.6
			return Film.look(pos, chest + UP * (H * 0.05)), Film.mm(35), chest
		end, { hand = 0.25 })
		if not ok then
			return false
		end
		-- 1B: close on its face: the pink tears out of it [an impact frame, in gold]; its own colours come back
		Film.at(0.3, function()
			local v = BossView.get()
			FilmPanels.impact({ v and v.model }, { color = GOLD, at = chest })
			FilmAudio.glitch(1)
			FilmAudio.sfx("bigHit", { volume = 0.6, pitch = 0.9 })
			FilmAudio.sfx("swell", { volume = 0.8 })
			FilmAudio.fadeOut(drone, 0.6)
			Film.shake(0.5, 0.6)
			glitchOut(feet, H)
			eyesOut()
			BossView.calmNow()
			Film.grade("dream", 0.9)
			Film.glow(0.3, 30, 0.9)
			cue("calm", "calmMusic", { fade = 2 })
		end)
		ok = Film.run(1.6, function(k)
			local h = head()
			local pos = h + d * (H * (0.6 + 0.06 * k)) + side * (H * 0.12) - UP * (H * 0.06)
			return Film.look(pos, h), Film.mm(40), h
		end, { hand = 0.35 })
		if not ok then
			return false
		end
		-- 1C: from the side, wide: it stands up tall over the Mowers... and bows its head to them; they cheer
		Film.at(0.3, function()
			IntroUi.lowerThird(string.upper(P.areas[1].name), "The last guardian is free.", GREEN, 3.2)
		end)
		Film.at(1.5, function()
			for i, a in mowers do
				task.delay((i - 1) * 0.08, function()
					a.play("cheer")
				end)
			end
		end)
		local mid = feet:Lerp(pc, 0.5)
		local sd = side * A.s
		local look = feet:Lerp(pc, 0.3) + UP * (H * 0.42)
		ok = Film.run(2.8, function(k)
			local pos = mid + sd * (H * (1.15 - 0.05 * k)) + d * (H * 0.1) + UP * (H * 0.2)
			return Film.look(pos, look), Film.mm(24), look
		end, { hand = 0.3 })
		if not ok then
			return false
		end
	end
	-- 1D: it goes up as light... the sun breaks through over the Mowers; low behind them, looking up
	Film.at(0.2, function()
		speak("E1", true)
		if alone then
			IntroUi.lowerThird(string.upper(P.areas[1].name), "The last guardian is free.", GREEN, 3.2)
		end
	end)
	local camAt = pc + d * 10.8 - side * gap + UP * 1.4
	local light: Part? = nil
	Film.at(0.45, function()
		local m = spark(chest, Color3.fromRGB(255, 244, 196), 1.2)
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 236, 180)
		pl.Range = 30
		pl.Brightness = 4
		pl.Shadows = false
		pl.Parent = m
		TweenService:Create(m, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = chest + UP * 90, Size = Vector3.one * 0.4 }):Play()
		light = m
		FilmAudio.sfx("swell", { volume = 0.9 })
		FilmAudio.sfx("rareChime", { volume = 0.5, pitch = 0.8 })
		-- (VFX Forge) the light's gold trail, and the pillar where it stood
		FilmVfx.play("GoldRise", m.CFrame, { follow = m, scale = math.max(1, H / 14) })
		FilmVfx.play("GoldPillar", CFrame.new(feet), { scale = H / 14 })
	end)
	Film.at(1.3, function()
		Film.light({ ExposureCompensation = 0.45 }, 1.4)
		Film.glow(0.55, 40, 1.2)
		FilmAudio.sfx("rareChime", { volume = 0.6, pitch = 1.1 })
		FilmVfx.play("SunBreak", CFrame.lookAt(chest + UP * 85, camAt)) -- (VFX Forge: the sun breaking through)
		for i, a in mowers do
			task.delay((i - 1) * 0.1, function()
				a.look(feet + UP * (H * 1.4))
				a.play("wave")
			end)
		end
	end)
	Film.at(2.9, function()
		Film.flash(Color3.fromRGB(255, 246, 222), 0.9, 0.7)
	end)
	local ok = Film.run(3.4, function(k)
		local look = feet + UP * (H * (0.5 + 0.35 * inOut(k)))
		return Film.look(camAt + d * (0.8 * k), look, -2), Film.mm(20), look
	end, { hand = 0.3 })
	if light then
		light:Destroy()
	end
	guardianOff()
	return ok
end

-------------------------------------------------------------------------------------------------------------
-- II. THE VALLEY BREATHES (owner, 29 Oct, of both films: "the camera just pans to the ground": the flight back over
-- every area looked down at the ground for thirteen seconds): the guardians back home in their own lands, free, in
-- their own colours, one after another, each standing tall and bowing as its land's name comes up (the opening
-- showed the pink falling on them). The Dandelion King last: the one it fell on first.
-------------------------------------------------------------------------------------------------------------
type Cameo = { z: number, feet: Vector3, toCam: Vector3, side: Vector3, H: number }
local CAMEO = 1.15 -- seconds each (the King's is longer)

-- Three of the guardians between the first and the last, at random (a different three each time), then the King.
local function cameoZones(): { number }
	local n = #Config.ZONES
	local zs = {}
	for z = 2, n - 1 do
		table.insert(zs, z)
	end
	for i = #zs, 2, -1 do
		local j = math.random(1, i)
		zs[i], zs[j] = zs[j], zs[i]
	end
	local list = {}
	for i = 1, math.min(3, #zs) do
		table.insert(list, zs[i])
	end
	if n > 1 then
		table.insert(list, 1)
	end
	return list
end

-- Where a guardian stands (its arena's middle) and its camera (clear of the scenery, the sun on its face).
local function cameoPlan(P: Plan, z: number, sun: Vector3): Cameo
	local H = BossMoves.get(z).height
	local feet = ground(arenaOf(z))
	local base = unit(flat(P.camp - feet), P.fwd)
	local best: Cameo = { z = z, feet = feet, toCam = base, side = base:Cross(UP), H = H }
	local bestScore = -math.huge
	local h = feet + UP * (H * 0.8)
	for _, y in YAWS do
		local toCam = turn(base, y)
		for _, s in { 1, -1 } do
			local side = toCam:Cross(UP) * s
			local cam = h + toCam * (H * 1.05) + side * (H * 0.28) - UP * (H * 0.12)
			local score = 2 * math.max(0, toCam:Dot(sun))
			if inside(cam) then
				score -= 8
			end
			if sees(cam, h) then
				score += 3
			end
			for _, t in { feet + UP * (H * 0.45), h + side * (H * 0.35), h - side * (H * 0.35) } do
				if sees(cam, t) then
					score += 1
				end
			end
			if score > bestScore then
				bestScore = score
				best = { z = z, feet = feet, toCam = toCam, side = side, H = H }
			end
		end
	end
	return best
end

local function valleyScenes(P: Plan, cameos: { Cameo }): boolean
	Film.light(LOOKS.golden, 0)
	Film.grade("dream", 0)
	Film.glow(0.25, 28, 0.3)
	Film.vignette(0.35, 0.3)
	stopCue("calm", 2)
	cue("flight", "flightMusic", { fade = 1.5 })
	bed("amb", "ambBirds", 1.2, 2)
	Film.at(0.3, function()
		speak("E2", true)
	end)
	guardianShown = true
	for i, c in cameos do
		local mv = BossMoves.get(c.z)
		local def = Config.ZONES[c.z]
		local last = i == #cameos
		BossView.show(mv.rig, CFrame.lookAt(c.feet, c.feet + c.toCam), guardianScale(c.z), mv)
		-- (it stands tall, then bows: client/BossView's "freed" without the kneeling)
		BossView.act("freed", { free = -1, nod = 0.3, fade = 99 })
		Film.at(0.1, function()
			local name = if def and def.name then def.name else ("Area " .. c.z)
			local who = if def and def.boss then def.boss.name else mv.rig
			IntroUi.lowerThird(string.upper(name), who .. " ~ free", GREEN, if last then 1.6 else 1.0)
			FilmAudio.sfx("rareChime", { volume = 0.4, pitch = 0.8 + i * 0.08 })
		end)
		local H = c.H
		local roll = if i % 2 == 0 then 4 else -4
		local ok = Film.run(if last then 1.7 else CAMEO, function(k)
			local h = BossView.attWorld("att_head_center") or (c.feet + UP * (H * 0.8))
			local pos = h + c.toCam * (H * (1.05 - 0.08 * k)) + c.side * (H * 0.28) - UP * (H * 0.12)
			return Film.look(pos, h - UP * (H * 0.04), roll * (1 - k)), Film.mm(38), h
		end, { cut = "whip", hand = 0.25 }) -- (whipped in: its first frames, while the guardian is put in place, are a blur)
		if not ok then
			return false
		end
	end
	guardianOff()
	return true
end

-------------------------------------------------------------------------------------------------------------
-- III. HOMECOMING (29 Oct: no walking; the Mowers come home the way they came in the opening, out of the sky)
-------------------------------------------------------------------------------------------------------------
local function homeScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	Film.light(LOOKS.golden, 0)
	Film.grade("dusk", 0)
	Film.glow(0.3, 30, 0.2)
	Film.vignette(0.45, 0.2)
	bed("amb", "ambWind", 1, 1.5)
	stopCue("flight", 3)
	local face = P.fwd
	m.act("lookOut")
	m.mood("neutral")
	m.look(P.mayorAt + face * 40 + UP * 3)
	Film.refreshSight()
	-- 3A: the Mayor alone on his soapbox at sunset, looking out over his meadow, waiting (in front of him, off to one
	-- side, on his face)
	local head = m.face()
	local yaw = 30
	for _, y in { 30, -30, 45, -45, 20, -20, 60, -60 } do
		local cam = head + turn(face, y) * 8.5 - UP * 0.6
		if not inside(cam) and sees(cam, head) then
			yaw = y
			break
		end
	end
	local d0 = turn(face, yaw)
	local ok = Film.run(2.6, function(k)
		local f = m.face()
		local pos = f + d0 * (8.5 - 1.0 * inOut(k)) - UP * 0.6
		return Film.look(pos, f - UP * 0.5), Film.mm(45), f
	end, { hand = 0.25 })
	if not ok then
		return false
	end
	-- 3B: THUD. Behind him the Mowers drop out of the sky one after another, each in a puff of dust; he jumps and
	-- spins round (from the side, wide: him in front, them landing behind him)
	local mid = P.cast:Lerp(P.mayorAt, 0.5)
	local sgn = 1
	for _, s in { 1, -1 } do
		local cam = mid + P.right * (s * 15) + P.fwd * 1.5 + UP * 3.2
		if not inside(cam) and sees(cam, mid + UP * 3) and sees(cam, P.cast + UP * 3) and sees(cam, P.mayorAt + UP * 6) then
			sgn = s
			break
		end
	end
	for i, actor in actors do
		Film.at(0.2 + (i - 1) * 0.16, function()
			FilmAudio.sfx("swipe2", { volume = 0.6, pitch = 0.7 + i * 0.05 })
			actor.drop(function(at: Vector3)
				if not Film.playing then
					return
				end
				FilmAudio.sfx("thud", { volume = 1.1, pitch = 0.8 + math.random() * 0.1 })
				Film.shake(0.35, 2.4)
				-- (one small puff each: more hid the Mowers on the opening's contact sheet)
				HitFx.play("bossSlamDust", at, Color3.fromRGB(196, 168, 120), false)
				actor.play("emote")
			end)
		end)
	end
	Film.at(0.7, function()
		m.hop(0.7)
		m.mood("surprised")
		m.act("shock")
		m.turn(-P.fwd, 0.45)
		m.look(P.cast + UP * 3)
		FilmAudio.sfx("whomp", { volume = 0.7, pitch = 1.5 })
	end)
	ok = Film.run(2.6, function(k)
		local pos = mid + P.right * (sgn * (15 - 1.5 * k)) + P.fwd * 1.5 + UP * 3.2
		return Film.look(pos, mid + UP * 3.2), Film.mm(26), mid
	end, { hand = 0.3 })
	if not ok then
		return false
	end
	-- 3C: his face: "You... you actually DID it!" (a medium close-up: his voxel face reads at this size, as in the
	-- opening)
	for _, actor in actors do
		actor.look(m.face())
	end
	m.mood("happy")
	Film.at(0.2, function()
		m.act("present")
		speak("E3")
	end)
	Film.at(1.5, function()
		m.hop(0.5)
	end)
	return Film.run(2.8, function(k)
		local f = m.face()
		local pos = f - P.fwd * (8.5 - 1.0 * out(k)) - P.right * 1.8 - UP * 0.5
		return Film.look(pos, f - UP * 0.2), Film.mm(45), f
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

-- Which side of the camp's line (P.right, +1 or -1) a camera `dist` studs out to the side of `at` sees it from.
local function clearSide(P: Plan, at: Vector3, dist: number, up: number, back: number?): number
	for _, s in { 1, -1 } do
		local cam = at + P.right * (s * dist) - P.fwd * (back or 0) + UP * up
		if not inside(cam) and sees(cam, at + UP * 3) then
			return s
		end
	end
	return 1
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
	local mid = P.cast:Lerp(P.mayorAt, 0.5)
	local s4 = clearSide(P, mid, 17, 2.6, 2)
	Film.at(1.0, function()
		-- (VFX Forge's confetti cannons by the party, firing toward the camera's side; the old screen confetti if
		-- they're missing)
		local spot = ground(mid)
		if not FilmVfx.play("ConfettiPop", CFrame.lookAt(spot, spot + P.right * s4)) then
			Confetti.burst(140)
		end
	end)
	Film.at(2.4, function()
		m.act("cheer")
		m.hop(0.6)
	end)
	local view = Film.view()
	local ok = Film.run(3.8, function(k)
		local pos = mid + P.right * (s4 * (17 - 2 * k)) - P.fwd * 2 + UP * (2.6 + k)
		return Film.look(Film.clear(pos, mid + UP * 3, view), mid + UP * 3.2), Film.mm(28), mid
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- 4B: dusk; fireworks over the camp, lighting everyone up; low, looking up past the Mayor
	Film.light(LOOKS.dusk, 1.2)
	Film.grade("dusk", 1)
	local sky = P.mayorAt + P.fwd * 22 + UP * 36
	for i = 0, 4 do
		Film.at(0.2 + i * 0.5, function()
			firework(sky + P.right * math.random(-30, 30) + P.fwd * math.random(-10, 12) + UP * math.random(-5, 9), i == 4)
		end)
	end
	m.act("wave")
	m.look(sky)
	local f0 = m.face()
	local sideB = if inside(f0 - P.fwd * 9 + P.right * 2.6 - UP * 3.6) then -1 else 1
	-- (the Mayor along the bottom of the picture, the fireworks over him: the contact sheet's first try ended on the
	-- sky alone)
	ok = Film.run(4.2, function(k)
		local f = m.face()
		local pos = f - P.fwd * 9 + P.right * (2.6 * sideB) - UP * 3.6
		local target = f:Lerp(sky, 0.16 + 0.1 * k)
		return Film.look(pos, target, -4 * sideB), Film.mm(20), sky
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- 4C: the group photo: everyone turns to us; "say GRASS!"; flash, the picture stops
	local mid2 = P.cast:Lerp(P.mayorAt, 0.5)
	local s5 = clearSide(P, mid2, 17, 4.6)
	local camPos = mid2 + P.right * (s5 * 17) + UP * 4.6
	for _, actor in actors do
		actor.turnTo(P.right * s5)
		actor.look(camPos)
		actor.play("wave")
	end
	m.act("present")
	m.look(camPos)
	m.turn(P.right * s5, 0.5)
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
		local pos = camPos + P.right * (s5 * 2 * (1 - inOut(k)))
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
-- V. THE CREDITS (owner, 28 Oct: "end credits, maybe take inspiration from JJK"): an anime ending, calm after the
-- party, on the film's own screen (client/FilmPanels): the title; STARRING the party, each in a panel of their own
-- colour; the eight guardians, free at last, in their own colours (the pink gone from their eyes), three to a page,
-- Mayor Thistlewick "as himself"; the makers; THANK YOU FOR PLAYING. SKIP jumps to what comes after them.
-------------------------------------------------------------------------------------------------------------
local PARTY_COLORS = {
	Color3.fromRGB(255, 196, 60),
	Color3.fromRGB(110, 200, 255),
	Color3.fromRGB(150, 230, 110),
	Color3.fromRGB(255, 130, 170),
	Color3.fromRGB(190, 150, 255),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(110, 230, 200),
	Color3.fromRGB(235, 235, 245),
}
local PAGE = 3.6 -- seconds a page stays up
local creditsSkipped = false
local makersList: { string }? = nil -- (looked up while the film plays: the web calls take a moment)

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

-- The pages, in order (each a function that puts its page up).
local function creditPages(m: IntroCast.Mayor?, cr: FilmPanels.Credits): { () -> () }
	local pages: { () -> () } = {}
	-- (the Mayor is thousands of blocks: copied once, now, while the title page is up)
	local mayorStill = if m then FilmPanels.copy(m.model, m.face(), 6) else nil
	table.insert(pages, function()
		cr.title(string.upper(Config.GAME_NAME or "Mow And Grow"), "the valley is mowed... for now")
	end)
	-- STARRING: the party, four to a page
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	local n = math.min(#list, 8)
	for i = 1, n, 4 do
		local group = {}
		for j = i, math.min(i + 3, n) do
			table.insert(group, list[j])
		end
		table.insert(pages, function()
			local items: { FilmPanels.PageItem } = {}
			for j, pl in group do
				table.insert(items, { still = FilmPanels.avatar(pl), color = PARTY_COLORS[(i + j - 2) % #PARTY_COLORS + 1], name = pl.DisplayName, sub = "@" .. pl.Name, span = 3.4, low = 0.18 })
			end
			cr.page(items, if i == 1 then "STARRING" else "AND STARRING")
		end)
	end
	-- the guardians, free at last: three to a page; the Mayor with the last ones
	local count = #Config.ZONES
	for i = 1, count, 3 do
		table.insert(pages, function()
			local items: { FilmPanels.PageItem } = {}
			for z = i, math.min(i + 2, count) do
				local def = Config.ZONES[z]
				local boss = def and def.boss
				local mv = BossMoves.get(z)
				table.insert(items, {
					still = FilmPanels.boss(z, false, 10),
					color = if boss and boss.color then boss.color else Color3.new(1, 1, 1),
					name = if boss then boss.name else mv.rig,
					sub = mv.title or "",
					span = 7.5,
					low = 0.42,
				})
			end
			if #items < 3 and mayorStill then
				table.insert(items, { still = mayorStill, color = GOLD, name = "Mayor Thistlewick", sub = "as himself", span = 3.4, low = 0.2, hold = true })
			end
			cr.page(items, if i == 1 then "THE GUARDIANS ~ FREE AT LAST" else "THE GUARDIANS")
		end)
	end
	table.insert(pages, function()
		cr.text("MADE BY", makersList or { MAKERS_FALLBACK })
	end)
	table.insert(pages, function()
		cr.text("SPECIAL THANKS", { "Every blade of grass that was mowed in the making of this valley", "And you, for playing" })
	end)
	table.insert(pages, function()
		cr.title("THANK YOU FOR PLAYING!", nil)
	end)
	return pages
end

local function creditsScenes(m: IntroCast.Mayor?): boolean
	creditsSkipped = false
	local cr = FilmPanels.credits()
	if not cr then
		return Film.playing
	end
	IntroUi.hush()
	IntroUi.letterbox(false, 0.6)
	IntroUi.fade(1, 0.5) -- (from the DEV panel's ENDING: CREDITS the black cover is still up)
	stopCue("party", 1.5)
	bed("crowd", nil, 1.5)
	bed("amb", nil, 1.5)
	cue("credits", "creditsMusic", { fade = 1.2 })
	local stop = Film.every(cr.update)
	for _, show in creditPages(m, cr) do
		if creditsSkipped or not Film.playing then
			break
		end
		show()
		local t0 = os.clock()
		while Film.playing and not creditsSkipped and os.clock() - t0 < PAGE do
			task.wait()
		end
	end
	-- (to black, then the screen goes)
	IntroUi.fade(0, 0.6)
	stopCue("credits", 1.2)
	task.wait(0.65)
	stop()
	cr.destroy()
	return Film.playing
end

-------------------------------------------------------------------------------------------------------------
-- VI. AFTER THE CREDITS: THE GLITCH HOLE (owner, 28 Oct: "make the entrance of the corrupted guy cooler, maybe he's
-- coming out of a glitch black hole that's sucking the island up ... and captures the island and the players"; the
-- council: after the credits, as an anime does, so being captured isn't followed by cheerful credits)
--   night, peace and quiet... the picture stutters; "W-what was THAT?!"; over the meadow the sky tears and a black
--   hole bursts open in pink [an impact frame]; it pulls: lumps of the island tear out and spiral in; the Mowers are
--   lifted off their feet, the Mayor too, and pulled in [an impact frame]; in the dark an eye opens; the glitch
--   demon heaves itself up out of the hole and speaks ("This valley... is MINE."); it roars and the hole swells over
--   everything [an impact frame]. TO BE CONTINUED; WORLD 2, THE CORRUPTED VALLEY, COMING SOON; and a word that
--   nothing you earned is lost.
-------------------------------------------------------------------------------------------------------------
local corrupt: Corruption.Handle? = nil
local hole: GlitchHole.Hole? = nil
local demon: Demon.Demon? = nil
local stage: { at: Vector3, toward: Vector3, sky: Vector3 }? = nil
local ungrade: ((number?) -> ())? = nil
local HOLE_R = 30 -- the hole's horizon (studs)
local HOLE_UP = 82 -- how high over the meadow it opens
local DEMON_SCALE = 1.35

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
						if not sees(at + off + UP * 1.5, at + off + UP * 70) then
							score += 6
						end
					end
					for _, cam in { at - toward * 30 + UP * 3 - side * 6, at - toward * 40 + UP * 14 + side * 22, at - toward * 50 + UP * 3 + side * 10, at - toward * 72 + UP * 22 + side * 20 } do
						for _, h in { 4, 22, 42 } do
							if not sees(cam, at + UP * h) then
								score += 4
							end
						end
						if not sees(cam + UP * 0.5, cam + UP * 60) then
							score += 2 -- (under a roof or a tree)
						end
					end
					-- the hole, seen from where the party stands in the camp (Studio's test, 28 Oct: from in front of
					-- the Tool Shop, its roof hid the bottom half of the hole)
					local dirS = unit(flat(at - P.cast), P.fwd)
					local sky = at + UP * HOLE_UP
					for _, cam in { P.cast - dirS * 11 + UP * 2.2, P.cast + UP * 3 } do
						for _, h in { -HOLE_R * 0.9, 0 } do
							if not sees(cam, sky + UP * h) then
								score += 5
							end
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

-- Where the hole opens and the demon, built for it in steps (a few hundred blocks a frame) and kept out of the
-- world until it comes out. Called while the credits roll (or as the scene starts, after a SKIP). Yields.
local preparing = false
local teaserGen = 0 -- (bumps when the film stops: a search still running then is dropped)
local function prepareTeaser(P: Plan)
	if stage or preparing then
		return
	end
	preparing = true
	local gen = teaserGen
	local at, toward = twistStage(P)
	if gen ~= teaserGen then
		return
	end
	local sky = at + UP * HOLE_UP
	stage = { at = at, toward = toward, sky = sky }
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(at, 4)
		end)
	end)
	-- It faces the camp and comes up out of the top of the hole, a little in front of it: its waist ends at the rim,
	-- so the whole demon shows (owner, 28 Oct night: "I can't see the demon well through the black hole ... maybe it
	-- sits a bit above it"; it used to stand in the middle of the black ball, waist deep in it).
	local toCamp = unit(flat(P.cast - sky), -toward)
	local riseAt = sky + UP * (HOLE_R * 0.85) + toCamp * (HOLE_R * 0.35)
	;(stage :: any).rise = riseAt
	local base = CFrame.lookAt(riseAt, riseAt + toCamp)
	local d = Demon.new(base, DEMON_SCALE, Instance.new("Folder"), { yieldEvery = 250 })
	d.state.rise = 0.42
	if gen == teaserGen and Film.playing and not demon then
		demon = d
	else
		d.destroy()
	end
	if gen == teaserGen then
		preparing = false
	end
end

-- The black screen at the very end: TO BE CONTINUED..., then WORLD 2 / THE CORRUPTED VALLEY / COMING SOON,
-- glitching, and the word that the valley and everything you earned are safe (the council: a kid who sees the island
-- and their avatar swallowed thinks their progress is gone).
local function worldTwoTitle(): boolean
	chapter = "title"
	IntroUi.skipShown(true)
	local W = Config.WORLD2
	local holder = Instance.new("ScreenGui")
	holder.Name = "WorldTwoTitle"
	holder.IgnoreGuiInset = true
	holder.ResetOnSpawn = false
	holder.DisplayOrder = 21 -- over the film (IntroCinema 20), under the glitches (22)
	holder.Parent = player:WaitForChild("PlayerGui")
	local veil = Instance.new("Frame")
	veil.Name = "WorldTwoVeil"
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(4, 0, 8)
	veil.BackgroundTransparency = 0
	veil.ZIndex = 1
	veil.Parent = holder
	-- TO BE CONTINUED, low on the right, in a brush hand
	local tbc = Instance.new("TextLabel")
	tbc.Name = "ToBeContinued"
	tbc.BackgroundTransparency = 1
	tbc.AnchorPoint = Vector2.new(1, 1)
	tbc.Position = UDim2.fromScale(0.94, 0.86)
	tbc.Size = UDim2.fromScale(0.5, 0.09)
	tbc.FontFace = Font.new("rbxasset://fonts/families/PermanentMarker.json")
	tbc.TextScaled = true
	tbc.TextXAlignment = Enum.TextXAlignment.Right
	tbc.TextColor3 = Color3.new(1, 1, 1)
	tbc.Text = "TO BE CONTINUED..."
	tbc.TextTransparency = 1
	tbc.ZIndex = 2
	tbc.Parent = holder
	TweenService:Create(tbc, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	FilmAudio.sfx("sting", { volume = 0.8, pitch = 0.8 })
	local ok = Film.run(1.9, function()
		return Film.lastFrame(), 70, nil
	end, { hand = 0 })
	if not ok then
		holder:Destroy()
		return false
	end
	TweenService:Create(tbc, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	Glitch.static(0.3, 0)
	Glitch.burst(1, 0.3)
	FilmAudio.glitch(1)
	FilmAudio.sfx("impact", { volume = 1, pitch = 0.8 })
	FilmAudio.sfx("bigHit", { volume = 0.7, pitch = 0.75 })
	local big = Glitch.text(holder, W.title, UDim2.fromScale(0.7, 0.2), UDim2.fromScale(0.5, 0.36), Color3.fromRGB(255, 70, 150))
	local name = Glitch.text(holder, W.name, UDim2.fromScale(0.6, 0.075), UDim2.fromScale(0.5, 0.52), nil)
	local soon: { stop: () -> () }? = nil
	Film.at(1.1, function()
		soon = Glitch.text(holder, W.soon, UDim2.fromScale(0.34, 0.05), UDim2.fromScale(0.5, 0.63), Color3.fromRGB(150, 245, 255))
		FilmAudio.sfx("slam", { volume = 0.7, pitch = 0.8 })
		FilmAudio.glitch(0.6)
		Glitch.burst(0.7, 0.2)
	end)
	Film.at(1.9, function()
		local safe = Instance.new("TextLabel")
		safe.Name = "Safe"
		safe.BackgroundTransparency = 1
		safe.AnchorPoint = Vector2.new(0.5, 0.5)
		safe.Position = UDim2.fromScale(0.5, 0.78)
		safe.Size = UDim2.fromScale(0.7, 0.04)
		safe.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		safe.TextScaled = true
		safe.TextColor3 = Color3.fromRGB(220, 230, 255)
		safe.Text = "Don't worry: your valley and everything you earned are safe!"
		safe.TextTransparency = 1
		safe.ZIndex = 3
		safe.Parent = holder
		TweenService:Create(safe, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	end)
	Film.at(2.6, function()
		FilmAudio.sfx("growl", { volume = 0.9, pitch = 0.6 })
	end)
	ok = Film.run(4.8, function()
		return Film.lastFrame(), 70, nil
	end, { hand = 0 })
	big.stop()
	name.stop()
	if soon then
		soon.stop()
	end
	holder:Destroy()
	return ok
end

-- T1-T3: night; the Mayor content on his soapbox... the picture stutters; "W-what was THAT?!"
local function nightScenes(P: Plan, m: IntroCast.Mayor): boolean
	IntroUi.letterbox(true, 0.6)
	Film.light(LOOKS.night, 0)
	Film.grade("night", 0)
	Film.glow(0.15, 24, 0.2)
	Film.vignette(0.55, 0)
	bed("amb", "ambWind", 0.8, 1)
	m.act("proud")
	m.mood("happy")
	m.look(nil)
	m.turn(P.fwd, 0.01)
	IntroUi.fade(1, 1.2)
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
	-- it stutters: the picture sticks and splits, his line breaks up, a heartbeat
	FilmVoice.stop()
	Babble.stop()
	Film.freeze(0.34)
	Film.shake(0.45, 1)
	Glitch.burst(0.85, 0.5)
	FilmVfx.play("NightStutter", CFrame.new(), { screen = 9 }) -- (VFX Forge: glitch bars over the picture)
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
	m.closeEyes(false)
	m.mood("scared")
	m.act("shock")
	Film.at(0.15, function()
		speak("E8")
	end)
	return Film.run(2.4, function(k)
		local f = m.face()
		-- (29 Oct, the contact sheet: at 65 mm and 5.6 studs his voxel face was just blocks)
		local pos = f + face * (9 - 1.2 * k) - P.right * 1.8 + UP * 0.1
		return Film.look(pos, f - UP * 0.3, -8 + k * 3), Film.mm(45), f
	end, { hand = 0.9 })
end

-- the party as silhouettes for an impact frame (not the Mayor: a voxel sculpture of thousands of blocks is too
-- many to copy in the blink of a hit)
local function castOf(actors: { IntroCast.Actor }, extra: Instance?): { Instance? }
	local list: { Instance? } = { extra }
	for _, a in actors do
		table.insert(list, a.model)
	end
	return list
end

-- T4-T6: the hole bursts open; it pulls the island up; it takes the Mowers and the Mayor
local function holeScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	local st = stage :: { at: Vector3, toward: Vector3, sky: Vector3 }
	local sky = st.sky
	local dirS = unit(flat(st.at - P.cast), P.fwd) -- from the camp toward the hole
	local hside = dirS:Cross(UP)
	-- (VFX Forge plays its halo, disk, falling sparks and shock ring: the hole leaves out its own)
	local forgeHole = FilmVfx.has("HoleDisk") and FilmVfx.has("HoleHalo")
	local H = GlitchHole.new(sky, -dirS, HOLE_R, propFolder(), { bare = forgeHole })
	hole = H
	Film.every(H.update)
	local C = Corruption.new(st.at)
	corrupt = C
	ungrade = Glitch.grade(nil, 3)
	-- everyone turns to look
	m.turn(dirS, 0.7)
	m.look(sky)
	for _, a in actors do
		a.turnTo(dirS)
		a.look(sky)
	end
	-- T4: low behind them, looking out over the meadow: the sky tears... and a black hole bursts open in it
	Film.refreshSight()
	local holeEdges = { sky, sky - UP * (HOLE_R * 0.9), sky + hside * (HOLE_R * 1.3), sky - hside * (HOLE_R * 1.3) }
	local camA = bestSpot({
		P.cast - dirS * 11 + hside * 4 + UP * 2.2,
		P.cast - dirS * 9 - hside * 6 + UP * 3,
		P.cast - dirS * 15 + UP * 6,
		P.cast + hside * 13 + UP * 3,
		P.cast - hside * 13 + UP * 3,
		P.cast - dirS * 14 + hside * 8 + UP * 10,
		P.cast - dirS * 14 - hside * 8 + UP * 10,
	}, { sky, holeEdges[2], holeEdges[3], holeEdges[4], P.cast + UP * 3 }, 40)
	Film.at(0.5, function()
		-- (VFX Forge's tear; the old one if it's missing)
		if not FilmVfx.play("SkyTear", CFrame.lookAt(sky, sky - dirS), { scale = 64 / 40 }) then
			C.rift(sky, -dirS, 64, 0.4)
		end
		FilmAudio.glitch(0.8)
		Glitch.burst(0.5, 0.2)
		FilmAudio.sfx("synthWhomp", { volume = 0.8, pitch = 0.45 })
		FilmAudio.riser("riseDark", 0.6, { volume = 0.6 }) -- (it ends just before the hit: a beat of silence)
	end)
	Film.at(1.15, function()
		FilmAudio.duck(1, 0.1)
		stopCue("heart", 0.3)
	end)
	Film.at(1.4, function()
		H.open(1.0)
		FilmVfx.play("HoleOpen", H.diskCf, { scale = HOLE_R / 30 })
		if forgeHole then
			FilmVfx.play("HoleDisk", H.diskCf, { scale = HOLE_R / 30, life = 90 })
			FilmVfx.play("HoleHalo", CFrame.new(sky), { scale = HOLE_R / 30, life = 90 })
		end
		FilmPanels.impact(castOf(actors, nil), { at = sky })
		FilmAudio.sfx("impact", { volume = 1, pitch = 0.7 })
		FilmAudio.sfx("bigHit", { volume = 0.6, pitch = 0.6 })
		Film.shake(0.6, 0.8)
		cue("dread", "dreadMusic", { fade = 0.8 })
		bed("amb", "eerie", 1.2, 1.5)
		task.delay(0.35, function()
			if Film.playing then
				FilmAudio.duck(0, 0.6)
			end
		end)
	end)
	local ok = Film.run(3.6, function(k)
		local look = sky:Lerp(P.cast + UP * 3, 0.3 - 0.15 * k)
		return Film.look(camA + UP * (k * 0.8), look, -2), Film.mm(20), look
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- T5: it pulls: lumps of the island tear out of the meadow, round and up into it; lightning; the wind
	H.chunks(st.at, 55, 44, 3.4)
	H.chunks(P.cast:Lerp(st.at, 0.35), 26, 14, 3.6)
	-- (VFX Forge) the ground tearing where the lumps come out
	for i, spot in { { st.at, 0, 30 }, { st.at, 0.7, 40 }, { st.at, 1.4, 22 }, { P.cast:Lerp(st.at, 0.35), 0.4, 14 } } do
		Film.at(spot[2] :: number, function()
			local a = math.random() * math.pi * 2
			local r = math.random() * (spot[3] :: number)
			FilmVfx.play("LumpTear", CFrame.new(ground((spot[1] :: Vector3) + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))), { scale = if i == 4 then 0.8 else 1.2 })
		end)
	end
	FilmAudio.sfx("bhPull", { volume = 1, pitch = 0.55 })
	FilmAudio.sfx("rumble", { volume = 1.1 })
	FilmAudio.sfx("drone", { volume = 0.8 })
	Film.shake(0.4, 0.15)
	for i = 0, 3 do
		Film.at(0.4 + i * 0.85, function()
			local strike = st.at + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40))
			C.bolt(sky + Vector3.new(math.random(-20, 20), -HOLE_R, math.random(-20, 20)), strike)
			FilmVfx.play("BoltHit", CFrame.new(ground(strike)), { scale = 1.4 }) -- (VFX Forge: where it strikes)
			FilmAudio.sfx("boom", { volume = 0.5, pitch = 0.55 + math.random() * 0.15 })
		end)
	end
	local mid = P.cast:Lerp(st.at, 0.55)
	local look5 = st.at:Lerp(sky, 0.42)
	local camB = bestSpot({
		mid + hside * 75 + UP * 16,
		mid - hside * 75 + UP * 16,
		mid + hside * 55 - dirS * 30 + UP * 24,
		mid - hside * 55 - dirS * 30 + UP * 24,
		mid + hside * 70 + UP * 34,
		mid - hside * 70 + UP * 34,
	}, { look5, sky, holeEdges[2], st.at + UP * 4 }, 40)
	local view = Film.view()
	ok = Film.run(4.0, function(k)
		local target = look5 + UP * (k * 6)
		return Film.look(Film.clear(camB + dirS * (k * 6), target, view), target), Film.mm(20), target
	end, { hand = 0.5 })
	if not ok then
		return false
	end
	-- T6: their feet leave the ground: the Mowers tumble up and away into it, the Mayor's hat goes, then him
	for i, a in actors do
		a.play("fall")
		H.take(function()
			return a.model:GetPivot()
		end, function(cf: CFrame)
			a.model:PivotTo(cf)
		end, 2.7 - math.min(i, 6) * 0.05, 0.15 + (i - 1) * 0.16)
		-- (VFX Forge) the glitch round them as they go
		Film.at(0.15 + (i - 1) * 0.16, function()
			local root = a.model.PrimaryPart or a.model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				FilmVfx.play("LiftAura", root.CFrame, { follow = root })
			end
		end)
	end
	m.act("shock")
	m.mood("scared")
	Film.at(0.3, function()
		m.hatPop(5)
		FilmAudio.sfx("swipe", { volume = 0.8, pitch = 0.7 })
	end)
	H.take(function()
		return m.root
	end, function(cf: CFrame)
		m.place(cf)
	end, 2.4, 0.75)
	Film.at(2.75, function()
		FilmPanels.impact(castOf(actors, H.horizon), { at = sky })
		FilmAudio.sfx("impact", { volume = 0.9, pitch = 0.9 })
		FilmAudio.sfx("growl2", { volume = 0.7, pitch = 0.6 })
	end)
	local camC = bestSpot({
		P.cast - dirS * 10 + UP * 1.4,
		P.cast - dirS * 8 + hside * 5 + UP * 2,
		P.cast + hside * 10 + UP * 2,
		P.cast - hside * 10 + UP * 2,
		P.cast - dirS * 12 + UP * 6,
	}, { P.cast + UP * 3, sky, holeEdges[2] }, 40)
	return Film.run(3.4, function(k)
		local e = Film.smooth(k * 1.2)
		local look = (P.cast + UP * 3):Lerp(sky, e)
		return Film.look(camC, look, 3 * (1 - k)), Film.mm(22 - 4 * e), look
	end, { hand = 0.5 })
end

-- T7-T10: an eye opens in the dark; the demon heaves itself up out of the hole and speaks; it roars and the hole
-- swells over everything
local function demonScenes(P: Plan): boolean
	local st = stage :: { at: Vector3, toward: Vector3, sky: Vector3 }
	local H = hole :: GlitchHole.Hole
	local sky = st.sky
	local dirS = unit(flat(st.at - P.cast), P.fwd)
	local riseAt = (st :: any).rise or (sky + UP * 8) -- (where the demon comes up: prepareTeaser)
	-- T7: close on the hole from the camp side: in the dark, an eye opens and looks at us
	H.eye(true)
	FilmAudio.riser("suck", 0.55, { volume = 0.8 })
	local camE = sky - dirS * (HOLE_R * 3.6) - UP * 10
	Film.at(0.55, function()
		local toCam = unit(camE - sky, -dirS)
		FilmVfx.play("EyeOpen", CFrame.lookAt(sky + toCam * (HOLE_R * 1.05), camE), { scale = HOLE_R * 1.15 / 16 }) -- (VFX Forge)
		FilmAudio.sfx("growl2", { volume = 1, pitch = 0.7 })
		FilmAudio.sfx("impact", { volume = 0.7, pitch = 1.1 })
		Film.punch(6)
		Film.shake(0.4, 1.4)
		Glitch.burst(0.6, 0.2)
	end)
	local ok = Film.run(2.2, function(k)
		return Film.look(camE + dirS * (k * 6), sky), Film.mm(45 + 10 * k), sky
	end, { hand = 0.3 })
	if not ok then
		return false
	end
	-- T8: it heaves itself up out of the hole: horns, a skull, shoulders, claws; low from the camp, looking up
	H.eye(false)
	local waited = os.clock()
	while Film.playing and not demon and os.clock() - waited < 2 do
		task.wait()
	end
	if not Film.playing then
		return false
	end
	local d = demon
	if not d then
		return true
	end
	d.model.Parent = propFolder()
	d.state.glitch = 0.5
	d.update(0)
	local t0 = os.clock()
	Film.every(function()
		d.update(os.clock() - t0)
	end)
	FilmAudio.sfx("growl", { volume = 1.1, pitch = 0.55 })
	FilmAudio.sfx("rumble", { volume = 1.2, pitch = 0.8 })
	FilmAudio.sfx("slam", { volume = 1, pitch = 0.6 })
	Film.shake(0.7, 0.2)
	FilmVfx.play("DemonRise", CFrame.new(riseAt), { scale = HOLE_R / 30 }) -- (VFX Forge: smoke, blocks)
	local hside = dirS:Cross(UP)
	local camF = bestSpot({
		P.cast - dirS * 6 + UP * 2,
		P.cast + UP * 3,
		P.cast + dirS * 20 + UP * 2,
		P.cast + hside * 12 + UP * 3,
		P.cast - hside * 12 + UP * 3,
	}, { riseAt + UP * 30, sky + UP * HOLE_R * 0.4, sky - UP * (HOLE_R * 0.9) }, 25)
	ok = Film.run(4.4, function(k)
		d.state.rise = 0.42 + 0.53 * inOut(math.clamp(k / 0.8, 0, 1))
		if k > 0.45 and d.state.eyes < 1 then
			d.state.eyes = 1
			FilmAudio.sfx("growl2", { volume = 1, pitch = 0.7 })
		end
		if math.random() < 0.05 then
			Glitch.burst(0.3, 0.08)
		end
		local target = riseAt + UP * (4 + d.state.rise * 30)
		return Film.look(camF, target, -3), Film.mm(30), target
	end, { hand = 0.6 })
	if not ok then
		return false
	end
	-- T9: it speaks
	local toCam = unit(flat(P.cast - sky), -dirS)
	local side = toCam:Cross(UP)
	Film.at(0.2, function()
		speak("D1")
		FilmAudio.sfx("drone", { volume = 0.7, pitch = 0.7 })
	end)
	ok = Film.run(3.2, function(k)
		local eyes = d.eyes()
		return Film.look(eyes + toCam * (34 - k * 4) - side * 3 - UP * 4, eyes - UP * 3, -5 + k * 3), Film.mm(35), eyes
	end, { hand = 0.4 })
	if not ok then
		return false
	end
	-- T10: the roar: pull back hard; the hole swells over it, over everything [an impact frame]; black
	d.state.glitch = 1
	-- (VFX Forge: the roar's rings, lines and shards laid over the picture, an impact frame: placed in the world, the
	-- hole in front of the camera hid them)
	FilmVfx.play("DemonRoar", CFrame.new(), { screen = 14, scale = 0.35 })
	-- (kept below the pain line: stacked roars and hits got too loud)
	FilmAudio.sfx("roar", { volume = 1.1, pitch = 0.55 })
	FilmAudio.sfx("roar", { volume = 0.8, pitch = 0.78 })
	FilmAudio.sfx("bigHit", { volume = 0.6, pitch = 0.7 })
	Film.shake(1, 0.5)
	Film.punch(12)
	Glitch.burst(1, 0.6)
	FilmAudio.glitch(1)
	Film.at(1.0, function()
		H.grow(3.4, 1.8)
		-- (VFX Forge: the final swell, laid over the picture: by now the hole has swallowed the view)
		FilmVfx.play("HoleSwell", CFrame.new(), { screen = 12, scale = 0.14 })
		FilmAudio.sfx("bhPull", { volume = 1, pitch = 0.45 })
	end)
	Film.at(2.3, function()
		FilmPanels.impact({ H.horizon }, { at = sky })
	end)
	Film.at(2.55, function()
		IntroUi.fade(0, 0.3)
	end)
	local view = Film.view()
	ok = Film.run(3.0, function(k)
		d.state.roar = math.clamp(k / 0.25, 0, 1)
		local e = 1 - (1 - k) ^ 4
		local eyes = d.eyes()
		local near = eyes + toCam * 30 + side * 3
		local far = P.cast + UP * 3
		local target = eyes:Lerp(sky, e)
		return Film.look(Film.clear(near:Lerp(far, e), target, view), target), 34 + e * 36, target
	end, { hand = 0.6 })
	if not ok then
		return false
	end
	return worldTwoTitle()
end

local function teaserScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
	-- (where it opens and the demon: normally ready long before, while the credits rolled)
	task.spawn(prepareTeaser, P)
	if not nightScenes(P, m) then
		return false
	end
	local waited = os.clock()
	while Film.playing and not stage and os.clock() - waited < 3 do
		task.wait()
	end
	if not Film.playing then
		return false
	end
	if not stage then
		local sky = P.sprout + UP * HOLE_UP
		stage = { at = P.sprout, toward = unit(flat(P.sprout - P.cast), P.fwd), sky = sky }
	end
	if not holeScenes(P, m, actors) then
		return false
	end
	return demonScenes(P)
end

-------------------------------------------------------------------------------------------------------------
-- the end screen (its own ScreenGui, over everything)
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
	local blurb = UI.text(face, "The valley is mowed... then the glitch came for it. To be continued in world 2!", UDim2.new(1, -40, 0, 26), { pos = UDim2.fromOffset(20, 114), stroke = 0, color = Color3.fromRGB(140, 96, 60) })
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

-- (29 Oct, the contact sheet: the arenas' "MOW THE AREA TO WAKE THE BOSS" labels floated over the shots) the world's
-- floating labels are off while the film plays (on this client only)
local hiddenLabels: { BillboardGui } = {}
local function worldLabels(on: boolean)
	if on then
		for _, g in hiddenLabels do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenLabels)
		return
	end
	local w = workspace:FindFirstChild("World")
	if w then
		for _, d in w:GetDescendants() do
			if d:IsA("BillboardGui") and d.Enabled then
				d.Enabled = false
				table.insert(hiddenLabels, d)
			end
		end
	end
end

-- The film is over (or skipped): clear the set, give the camera and the light back.
local function stopFilm()
	guardianOff()
	worldLabels(true)
	FilmVfx.clear()
	Film.stop(STEP)
	FilmVoice.clear()
	Babble.stop()
	IntroCast.cleanup()
	IntroUi.close()
	-- world 2's corruption, the hole, the demon, the glitches, the grade
	if corrupt then
		corrupt.destroy()
		corrupt = nil
	end
	if hole then
		hole.destroy()
		hole = nil
	end
	if demon then
		demon.destroy() -- (if it never came out, it was never in the set)
		demon = nil
	end
	stage = nil
	preparing = false
	teaserGen += 1
	scenery = nil
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

type Cast = { m: IntroCast.Mayor, actors: { IntroCast.Actor }, arena: { IntroCast.Actor } }

-- The Mayor and the party (copies of everyone's avatars), moving every frame of the film.
local function castUpdates(c: Cast)
	Film.every(function(dt: number)
		c.m.update(dt)
		local s = Film.scale()
		for _, actor in c.actors do
			actor.update(dt, s)
		end
		for _, actor in c.arena do
			actor.update(dt, s)
		end
	end)
end

local function film(P: Plan, c: Cast, A: ArenaPlan, cameos: { Cameo }): boolean
	IntroUi.letterbox(true, 0.8)
	local ok = lastBladeScenes(P, A, c.arena)
	-- (the Mowers at the arena go; the camp's come home later, out of the sky)
	for _, a in c.arena do
		a.model:Destroy()
	end
	table.clear(c.arena)
	if not ok then
		return false
	end
	if not valleyScenes(P, cameos) then
		return false
	end
	if not homeScenes(P, c.m, c.actors) then
		return false
	end
	return partyScenes(P, c.m, c.actors)
end

-- Play the ending. `d`: the server's runComplete data ({ gems, time, best, wait }); d.from = "credits" (the DEV
-- panel) starts at the credits.
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
	chapter = if d.from == "credits" then "credits" else "film"
	skippedAll = false
	creditsSkipped = false
	local skipReady = 0 -- (SKIP is ignored for a second after each press: a double tap skips one chapter, not two)
	IntroUi.open(function()
		if os.clock() < skipReady then
			return
		end
		skipReady = os.clock() + 1
		if chapter == "film" then
			chapter = "skip"
			Film.playing = false
		elseif chapter == "credits" then
			creditsSkipped = true
		elseif chapter == "title" then
			skippedAll = true
			Film.playing = false
		end -- (in the teaser itself SKIP is hidden and does nothing: a second tap can't skip it)
	end)
	IntroUi.fade(0, 0.8)
	-- the black cover is up: the voices start being made, the sounds load, the far places stream in, the makers'
	-- names are looked up for the credits
	local lines = {}
	for _, k in ORDER do
		table.insert(lines, { text = LINES[k], who = "mayor" })
	end
	table.insert(lines, { text = LINES.D1, who = "demon" })
	FilmVoice.prepare(lines)
	FilmAudio.begin({ "calmMusic", "flightMusic", "partyMusic", "dreadMusic", "creditsMusic", "heartbeat", "swell", "boom", "crowd", "applause", "impact", "slam", "bigHit", "rumble", "growl", "growl2", "suck", "drone", "revStop", "revBuild", "eerie", "servo", "whomp", "thud", "sting", "bhPull", "roar", "riseDark", "swipe2", "rareChime" })
	task.spawn(function()
		makersList = makers()
	end)
	local P = plan()
	local zones = cameoZones()
	local spots = { P.arena, P.camp, P.sprout }
	for _, a in P.areas do
		table.insert(spots, a.pos)
	end
	for _, z in zones do
		table.insert(spots, arenaOf(z))
	end
	-- (the guardians' models, their paint and meshes, load while the cover is up)
	local models = ReplicatedStorage:FindFirstChild("BossModels")
	if models then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(models:GetChildren())
			end)
		end)
	end
	streamIn(spots)
	-- the scenery round the camp and the arenas, as boxes (the cameras keep out of it), and the shots' plans
	local places = { { at = P.camp, r = 260 }, { at = P.arena, r = 150 } }
	for _, z in zones do
		table.insert(places, { at = arenaOf(z), r = 120 })
	end
	Film.refreshSight() -- (what the plans' raycasts look through: the characters, the grass, the film's sets)
	scenery = sceneryBoxes(places)
	local A = arenaPlan(P)
	local sun = sunAt(LOOKS.golden.ClockTime)
	local cameos: { Cameo } = {}
	for _, z in zones do
		table.insert(cameos, cameoPlan(P, z, sun))
	end
	Babble.prepare()
	if (Config.FILM :: any).voice ~= false then
		FilmVoice.waitFor(LINES.E1, 1.5)
	end
	Film.start(STEP)
	FilmPanels.reset()
	worldLabels(false)
	-- (he faces out over his meadow at first; the Mowers at the arena face the last guardian)
	local c: Cast = { m = IntroCast.mayor(P.mayorAt, P.fwd), actors = IntroCast.party(P.cast, P.fwd, P.right), arena = IntroCast.party(A.party, -A.d, (-A.d):Cross(UP)) }
	mayor = c.m
	Film.refreshSight()
	castUpdates(c)
	IntroCast.hideCharacters(true)
	local function run(fn: (...any) -> boolean, ...): boolean
		local good, res = pcall(fn, ...)
		if not good then
			warn("[Ending] " .. tostring(res))
		end
		return good and res == true
	end
	-- I-IV: the film
	if chapter == "film" then
		run(film, P, c, A, cameos)
	end
	-- V: the credits (and while they roll, the hole's place is chosen and the demon built)
	if chapter == "film" or chapter == "credits" then
		chapter = "credits"
		task.spawn(prepareTeaser, P)
		run(creditsScenes, c.m)
	end
	-- VI: after the credits (SKIP in the film lands here too)
	if not skippedAll then
		chapter = "teaser"
		IntroUi.skipShown(false)
		guardianOff()
		if not Film.playing then
			-- (skipped out of the film: start the camera and the light afresh, under the black cover)
			IntroUi.fade(0, 0.2)
			for name in table.clone(music) do
				stopCue(name, 0.3) -- (the party's music and the crowd don't carry on into the night)
			end
			FilmAudio.hush(0.3) -- (and the applause, the whistles, the booms)
			FilmVfx.clear() -- (and the film's VFX Forge effects)
			filmGen += 1
			IntroUi.hush()
			task.wait(0.2)
			Film.stop(STEP)
			Film.start(STEP)
			Film.refreshSight()
			castUpdates(c)
		end
		for _, actor in c.actors do
			if not actor.model.Parent then
				actor.show()
			end
		end
		if not skippedAll then
			run(teaserScenes, P, c.m, c.actors)
		end
	end
	IntroUi.fade(0, 0.4)
	task.wait(0.45)
	stopFilm()
	FilmAudio.hush(0.8)
	cue("end", "calmMusic", { fade = 2, volume = 0.7 })
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

-- The DEV panel's PLAY ENDING: the whole ending, the credits, the scene after them and the end screen, on this
-- client only, without finishing the run (nobody is sent anywhere; BACK TO GAME on the end screen carries on).
-- `from` = "credits" starts at the credits.
function Ending.preview(from: string?)
	task.spawn(Ending.play, { gems = 0, time = 0, preview = true, from = from })
end

return Ending
