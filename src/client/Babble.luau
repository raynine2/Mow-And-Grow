--!strict
-- BABBLE: Mayor Thistlewick's voice in the films (owner, 28 Oct: the text-to-speech voice was "very bland and AI
-- rubbish"). He talks in a made-up mumble, one short licensed sound per syllable, pitched along the line like real
-- speech: CAPS words and "!" louder and higher, a lift at the end of a question, a fall at the end of a sentence,
-- pauses at "," "." and "...". The subtitles carry the words, so it works in every language and on muted phones.
-- Which sound he uses: Config.FILM.babble ("bassoon", "kazoo", "tuba", "hum"; "none" = subtitles only). The DEV
-- panel's MAYOR VOICE button tries them out one after the other (this device only, until the owner picks one).
-- Licensed library audio only (APM Music, Pro Sound Effects); each sound's loud part was measured in Studio.
--
--   Babble.prepare()             start loading the voice's sounds (the film's black cover is up)
--   Babble.line(text, opts?)     -> its length (s), a loudness function (0..1) for his jaw (client/MayorRig.speak)
--                                   opts: pitch (x), volume (x)
--   Babble.stop()                cut him off
--   Babble.voice() / Babble.setVoice(name) / Babble.cycle() / Babble.label(name)
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local Babble = {}

-- one syllable's sound: the asset, where its note starts and ends (s), a loudness trim
type Bit = { id: number, from: number, to: number, gain: number? }
type Voice = { label: string, bits: { Bit }, pitch: number, volume: number }

-- (envelopes measured with an AudioAnalyzer, 28 Oct; quiet ones get a gain so they sit level with the rest)
local VOICES: { [string]: Voice } = {
	-- APM "Bassoon Special B": two short staccato notes; a pompous, comic grandpa of a voice
	bassoon = { label = "BASSOON", pitch = 1, volume = 0.85, bits = {
		{ id = 1846926898, from = 0.04, to = 0.17 },
		{ id = 1846926898, from = 0.4, to = 0.62 },
	} },
	-- APM "Kazoo For Yoo C": three low kazoo phrases (about a man's speaking pitch)
	kazoo = { label = "KAZOO", pitch = 0.95, volume = 0.7, bits = {
		{ id = 1846926430, from = 0.02, to = 0.3 },
		{ id = 1846926430, from = 0.42, to = 0.66 },
		{ id = 1846926430, from = 0.8, to = 1.0 },
	} },
	-- APM "Tuba Tone J": the loud middle of one long note, a brass-band "wah"
	tuba = { label = "TUBA", pitch = 1.2, volume = 1.2, bits = {
		{ id = 1846987125, from = 0.7, to = 1.6 },
	} },
	-- Pro Sound Effects "Male Reaction" 2-5: a man's short closed-mouth "hm"s
	hum = { label = "HUMMING", pitch = 1, volume = 1, bits = {
		{ id = 9116453449, from = 0.13, to = 0.27, gain = 4.5 },
		{ id = 9116453436, from = 0.11, to = 0.23, gain = 3 },
		{ id = 9116453647, from = 0.06, to = 0.17, gain = 6 },
		{ id = 9116453659, from = 0.13, to = 0.32, gain = 1.4 },
	} },
}
Babble.ORDER = { "bassoon", "kazoo", "tuba", "hum", "none" }

local chosen: string? = nil -- (the DEV panel's pick on this device; otherwise Config.FILM.babble)

function Babble.voice(): string
	local cfg = (Config :: any).FILM or {}
	local name = chosen or cfg.babble or "bassoon"
	return if name == "none" or VOICES[name] then name else "bassoon"
end

function Babble.setVoice(name: string)
	chosen = name
end

-- the next voice in Babble.ORDER (the DEV panel's audition); returns its name
function Babble.cycle(): string
	local now = Babble.voice()
	local i = table.find(Babble.ORDER, now) or 0
	local name = Babble.ORDER[i % #Babble.ORDER + 1]
	chosen = name
	return name
end

function Babble.label(name: string): string
	local v = VOICES[name]
	return if v then v.label else "SUBTITLES ONLY"
end

-------------------------------------------------------------------------------------------------------------
-- the sounds: a few copies of each, used in turn (a syllable can start while the last one fades)
-------------------------------------------------------------------------------------------------------------
local COPIES = 4
local holder: Folder? = nil
local group: SoundGroup? = nil
local pools: { [number]: { sounds: { Sound }, next: number } } = {}
local fades: { [Sound]: Tween } = {}
local plays: { [Sound]: number } = {}

-- The voice's own sound group, with a gentle compressor so a shouted word never jumps out of the mix.
local function voiceGroup(): SoundGroup
	if group and group.Parent then
		return group
	end
	local g = SoundService:FindFirstChild("FilmBabble")
	if not (g and g:IsA("SoundGroup")) then
		local made = Instance.new("SoundGroup")
		made.Name = "FilmBabble"
		made.Volume = 0.9
		local c = Instance.new("CompressorSoundEffect")
		c.Threshold = -14
		c.Ratio = 3
		c.Attack = 0.005
		c.Release = 0.12
		c.Parent = made
		made.Parent = SoundService
		g = made
	end
	group = g :: SoundGroup
	return g :: SoundGroup
end

local function pool(id: number): { sounds: { Sound }, next: number }
	local p = pools[id]
	if p and #p.sounds > 0 and p.sounds[1].Parent then
		return p
	end
	if not (holder and holder.Parent) then
		local f = Instance.new("Folder")
		f.Name = "FilmBabbleSounds"
		f.Parent = SoundService
		holder = f
	end
	local list = {}
	for _ = 1, COPIES do
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Volume = 0
		s.SoundGroup = voiceGroup()
		s.Parent = holder
		table.insert(list, s)
	end
	local made = { sounds = list, next = 1 }
	pools[id] = made
	return made
end

-- Start loading the current voice's sounds.
function Babble.prepare()
	local v = VOICES[Babble.voice()]
	if not v then
		return
	end
	local list: { Instance } = {}
	for _, b in v.bits do
		for _, s in pool(b.id).sounds do
			table.insert(list, s)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

-- Whether the current voice's sounds have loaded.
function Babble.ready(): boolean
	local v = VOICES[Babble.voice()]
	if not v then
		return true
	end
	for _, b in v.bits do
		for _, s in pool(b.id).sounds do
			if not s.IsLoaded then
				return false
			end
		end
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- a line into syllables
-------------------------------------------------------------------------------------------------------------
type Syl = { at: number, len: number, pitch: number, loud: number }

-- roughly how many syllables a word has (runs of vowels; a silent final "e" doesn't count)
local function syllables(word: string): number
	local w = string.lower(word)
	local n = 0
	for _ in string.gmatch(w, "[aeiouy]+") do
		n += 1
	end
	if n > 1 and string.sub(w, -1) == "e" and not string.find(w, "[^aeiouy]le$") then
		n -= 1
	end
	return math.clamp(n, 1, 4)
end

local function plan(text: string, base: number): ({ Syl }, number)
	local words = {}
	for word, punct in string.gmatch(text, "([%w']+)([^%w']*)") do
		table.insert(words, { w = word, p = punct })
	end
	local question = string.find(text, "%?%s*$") ~= nil
	local syls: { Syl } = {}
	local t = 0.04
	local n = #words
	local up = false
	for i, wd in words do
		local caps = #wd.w > 1 and wd.w == string.upper(wd.w) and string.find(wd.w, "%a") ~= nil
		local shout = caps or string.find(wd.p, "!") ~= nil
		local count = syllables(wd.w)
		for s = 1, count do
			local len = (0.095 + math.random() * 0.05) * (if caps then 1.45 elseif shout then 1.2 else 1)
			-- the tune: a little up-and-down from syllable to syllable, drifting down over the line
			up = not up
			local pitch = base * (1 - 0.1 * (i - 1) / math.max(n, 1)) * (if up then 1.05 else 0.96) * (1 + (math.random() - 0.5) * 0.1)
			if caps then
				pitch *= 1.14
			end
			if i == n and s == count then
				pitch *= if question then 1.28 else 0.88
			end
			table.insert(syls, { at = t, len = len, pitch = pitch, loud = if caps then 1.3 elseif shout then 1.12 else 0.82 + math.random() * 0.16 })
			t += len + 0.018
		end
		local p = wd.p
		if string.find(p, "%.%.") or string.find(p, "…") then
			t += 0.42
		elseif string.find(p, "[%.!%?]") then
			t += 0.28
		elseif string.find(p, "[,;:]") then
			t += 0.17
		else
			t += 0.045
		end
	end
	return syls, t
end

-------------------------------------------------------------------------------------------------------------
-- speaking
-------------------------------------------------------------------------------------------------------------
local generation = 0 -- bumps on stop (and on every new line): older syllables don't play

local function playSyl(v: Voice, syl: Syl, volume: number, gen: number)
	if gen ~= generation then
		return
	end
	local bit = v.bits[math.random(#v.bits)]
	local p = pool(bit.id)
	local s = p.sounds[p.next]
	p.next = p.next % #p.sounds + 1
	local old = fades[s]
	if old then
		old:Cancel()
		fades[s] = nil
	end
	local mine = (plays[s] or 0) + 1
	plays[s] = mine
	s:Stop()
	s.TimePosition = bit.from
	s.PlaybackSpeed = syl.pitch * v.pitch
	s.Volume = math.min(10, v.volume * (bit.gain or 1) * syl.loud * volume)
	s:Play()
	-- let the note ring for most of the syllable, then fade it out (no clicks, no notes running on)
	local ring = math.min(syl.len * 0.7, (bit.to - bit.from) / s.PlaybackSpeed)
	task.delay(ring, function()
		if plays[s] ~= mine then
			return
		end
		local tw = TweenService:Create(s, TweenInfo.new(math.max(0.04, syl.len * 0.45), Enum.EasingStyle.Quad), { Volume = 0 })
		fades[s] = tw
		tw:Play()
		tw.Completed:Once(function()
			if plays[s] == mine then
				s:Stop()
				fades[s] = nil
			end
		end)
	end)
end

-- Say `text` in the current voice. Returns how long it takes and his jaw's loudness (0..1); with no voice
-- ("none"), the length is still a good one for its subtitle and the loudness flaps the jaw in syllables.
function Babble.line(text: string, opts: { pitch: number?, volume: number? }?): (number, () -> number)
	generation += 1
	local gen = generation
	local name = Babble.voice()
	local v = VOICES[name]
	local syls, len = plan(text, (opts and opts.pitch) or 1)
	local t0 = os.clock()
	if v then
		local volume = (opts and opts.volume) or 1
		for _, syl in syls do
			task.delay(syl.at, playSyl, v, syl, volume, gen)
		end
	end
	local function level(): number
		if gen ~= generation then
			return 0
		end
		local t = os.clock() - t0
		for _, syl in syls do
			if t >= syl.at and t < syl.at + syl.len then
				local k = (t - syl.at) / syl.len
				return math.sin(k * math.pi) ^ 0.6 * math.min(1, syl.loud)
			end
		end
		return 0
	end
	return len, level
end

function Babble.stop()
	generation += 1
	for s, tw in fades do
		tw:Cancel()
		s:Stop()
	end
	table.clear(fades)
	for _, p in pools do
		for _, s in p.sounds do
			if s.IsPlaying then
				s:Stop()
			end
		end
	end
end

return Babble
