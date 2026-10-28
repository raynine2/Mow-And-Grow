--!strict
-- FILM AUDIO: the sound of the cutscenes (client/Intro, client/Ending). Music cues that fade in and out (and can
-- start partway in), ambience beds, one-shot effects, risers timed to land on a hit, the music dipping under
-- dialogue and going muffled (a memory, a shock), a "tape stop" when the music dies, and glitches cut from a
-- licensed sound. Ids: Config.FILM_SOUNDS (and Config.SOUNDS). The game's own music and ambience fade out while a
-- film plays and come back after.
--
--   FilmAudio.begin(keys?)            take over (and start loading the keys a film will use)
--   FilmAudio.music(key, opts) -> Cue   opts: volume (x the sound's), fade, at (start position), speed, loop
--   FilmAudio.amb(key, volume, fade) -> Cue   a looping bed
--   FilmAudio.sfx(key, opts)          opts: volume, pitch, at
--   FilmAudio.riser(key, landIn, opts)  starts a riser so its end lands `landIn` seconds from now
--   FilmAudio.duck(amount, time)      the music dips (0 = full, 1 = silent) for dialogue
--   FilmAudio.muffle(amount, time)    the music goes dull and far away (0 = clear)
--   FilmAudio.glitch(power)           a burst of digital stutter
--   FilmAudio.finish(fade)            everything out, the game's audio back
--   Cue: fade(volume, time), stop(time?), tapeStop(time), sound
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local FilmAudio = {}

type Def = { id: string, volume: number?, len: number?, pitch: number? }

local function def(key: string): Def?
	local d = (Config.FILM_SOUNDS :: any)[key] or (Config.SOUNDS :: any)[key]
	if d and d.id and d.id ~= "" then
		return d
	end
	return nil
end

local music: SoundGroup? = nil
local sfx: SoundGroup? = nil
local amb: SoundGroup? = nil
local eq: EqualizerSoundEffect? = nil
local live: { Sound } = {}
local quieted: { [SoundGroup]: number } = {}
local MUSIC_VOL, SFX_VOL, AMB_VOL = 0.6, 0.9, 0.55
local duckLevel = 0

local function group(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		g.Volume = volume
		return g
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Volume = volume
	made.Parent = SoundService
	return made
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	TweenService:Create(obj, TweenInfo.new(math.max(time, 0.01), style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), props):Play()
end

-- Take over: the film's sound groups up, the game's music and ambience faded out. `keys`: sounds to load now.
function FilmAudio.begin(keys: { string }?)
	music = group("FilmMusic", MUSIC_VOL)
	sfx = group("FilmSfx", SFX_VOL)
	amb = group("FilmAmb", AMB_VOL)
	duckLevel = 0
	local e = (music :: SoundGroup):FindFirstChildOfClass("EqualizerSoundEffect")
	if not e then
		local made = Instance.new("EqualizerSoundEffect")
		made.HighGain, made.MidGain, made.LowGain = 0, 0, 0
		made.Parent = music
		e = made
	end
	eq = e
	for _, name in { "MowALawnMusic", "MowALawnAmbience" } do
		local g = SoundService:FindFirstChild(name)
		if g and g:IsA("SoundGroup") and quieted[g] == nil then
			quieted[g] = g.Volume
			tween(g, 0.9, { Volume = 0 })
		end
	end
	if keys then
		task.spawn(function()
			local list: { Instance } = {}
			for _, k in keys do
				local d = def(k)
				if d then
					local s = Instance.new("Sound")
					s.SoundId = d.id
					table.insert(list, s)
				end
			end
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end)
	end
end

local function track(s: Sound)
	table.insert(live, s)
	s.Destroying:Connect(function()
		local i = table.find(live, s)
		if i then
			table.remove(live, i)
		end
	end)
end

export type Cue = {
	sound: Sound,
	fade: (volume: number, time: number) -> (),
	stop: (time: number?) -> (),
	tapeStop: (time: number) -> (),
}

local function cue(s: Sound, full: number): Cue
	local stopped = false
	local c: Cue
	c = {
		sound = s,
		fade = function(volume: number, time: number)
			if not stopped then
				tween(s, time, { Volume = full * volume })
			end
		end,
		stop = function(time: number?)
			if stopped then
				return
			end
			stopped = true
			local t = time or 0.8
			tween(s, t, { Volume = 0 })
			task.delay(t + 0.05, function()
				s:Destroy()
			end)
		end,
		-- the music dies: it slows and drops in pitch to nothing
		tapeStop = function(time: number)
			if stopped then
				return
			end
			stopped = true
			tween(s, time, { PlaybackSpeed = 0.12, Volume = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(time + 0.05, function()
				s:Destroy()
			end)
		end,
	}
	return c
end

local function make(key: string, into: SoundGroup?, volume: number, loop: boolean): (Sound?, number)
	local d = def(key)
	if not d or not into then
		return nil, 0
	end
	local s = Instance.new("Sound")
	s.Name = "Film_" .. key
	s.SoundId = d.id
	s.Looped = loop
	s.SoundGroup = into
	s.PlaybackSpeed = d.pitch or 1
	s.Parent = SoundService
	track(s)
	return s, (d.volume or 0.5) * volume
end

-- start a sound at a position (once it has loaded, so the position takes)
local function startAt(s: Sound, at: number?)
	if not at or at <= 0 then
		s:Play()
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while s.Parent and not s.IsLoaded and os.clock() - t0 < 3 do
			task.wait()
		end
		if s.Parent then
			s.TimePosition = at
			s:Play()
		end
	end)
end

-- A music cue. opts: volume (x the sound's own), fade (seconds in), at (start position), speed, loop (default on)
function FilmAudio.music(key: string, opts: { volume: number?, fade: number?, at: number?, speed: number?, loop: boolean? }?): Cue?
	local o = opts or {}
	local s, full = make(key, music, o.volume or 1, if o.loop == nil then true else o.loop :: boolean)
	if not s then
		return nil
	end
	if o.speed then
		s.PlaybackSpeed = o.speed
	end
	local fade = o.fade or 1.2
	s.Volume = if fade > 0 then 0 else full
	startAt(s, o.at)
	if fade > 0 then
		tween(s, fade, { Volume = full })
	end
	return cue(s, full)
end

-- A looping ambience bed, faded in.
function FilmAudio.amb(key: string, volume: number?, fade: number?): Cue?
	local s, full = make(key, amb, volume or 1, true)
	if not s then
		return nil
	end
	s.Volume = 0
	s:Play()
	tween(s, fade or 1.5, { Volume = full })
	return cue(s, full)
end

-- A one-shot. opts: volume (x the sound's own), pitch, at (start position in the sound)
function FilmAudio.sfx(key: string, opts: { volume: number?, pitch: number?, at: number? }?): Sound?
	local o = opts or {}
	local s, full = make(key, sfx, o.volume or 1, false)
	if not s then
		return nil
	end
	s.Volume = full
	if o.pitch then
		s.PlaybackSpeed = o.pitch
	end
	startAt(s, o.at)
	local d = def(key)
	local len = (d and d.len) or 8
	task.delay(len / math.max(s.PlaybackSpeed, 0.1) + 1, function()
		s:Destroy()
	end)
	return s
end

-- A riser timed so that its end lands `landIn` seconds from now (it starts partway in if there isn't time).
function FilmAudio.riser(key: string, landIn: number, opts: { volume: number?, pitch: number? }?): Sound?
	local d = def(key)
	if not d then
		return nil
	end
	local pitch = (opts and opts.pitch) or 1
	local len = (d.len or 8) / pitch
	local o = { volume = opts and opts.volume, pitch = pitch, at = nil :: number? }
	if landIn >= len then
		task.delay(landIn - len, function()
			FilmAudio.sfx(key, o)
		end)
		return nil
	end
	o.at = (len - landIn) * pitch
	return FilmAudio.sfx(key, o)
end

-- The music dips under dialogue: 0 = full, 1 = silent.
function FilmAudio.duck(amount: number, time: number?)
	duckLevel = math.clamp(amount, 0, 1)
	local m = music
	if m then
		tween(m, time or 0.35, { Volume = MUSIC_VOL * (1 - duckLevel) })
	end
end

-- The music goes dull and far away (a memory, a ringing shock): 0 = clear, 1 = very muffled.
function FilmAudio.muffle(amount: number, time: number?)
	local e = eq
	if e then
		tween(e, time or 0.6, { HighGain = -40 * amount, MidGain = -14 * amount, LowGain = 2 * amount })
	end
end

-- A burst of digital stutter: tiny slices of a licensed machine sound, pitched about (power 0..1).
function FilmAudio.glitch(power: number)
	local d = def("servo")
	if not d then
		return
	end
	local hits = 2 + math.floor(power * 4 + 0.5)
	task.spawn(function()
		for _ = 1, hits do
			local s, full = make("servo", sfx, 0.6 + power * 0.6, false)
			if not s then
				return
			end
			s.Volume = full
			s.PlaybackSpeed = 0.8 + math.random() * 1.1
			startAt(s, math.random() * ((d.len or 10) - 0.5))
			local life = 0.04 + math.random() * 0.06
			task.delay(life, function()
				s:Destroy()
			end)
			task.wait(life + math.random() * 0.03)
		end
	end)
end

-- Everything out (over `fade` seconds) and the game's music and ambience back.
function FilmAudio.finish(fade: number?)
	local t = fade or 1.2
	for _, s in table.clone(live) do
		tween(s, t, { Volume = 0 })
		task.delay(t + 0.05, function()
			s:Destroy()
		end)
	end
	for g, vol in quieted do
		if g.Parent then
			tween(g, 2, { Volume = vol })
		end
	end
	table.clear(quieted)
	if eq then
		tween(eq, 0.3, { HighGain = 0, MidGain = 0, LowGain = 0 })
	end
	duckLevel = 0
	local m = music
	if m then
		tween(m, 0.3, { Volume = MUSIC_VOL })
	end
end

return FilmAudio
