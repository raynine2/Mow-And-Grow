--!strict
-- FILM VOICE: the Mayor (and once, the glitch demon) speaking their lines out loud in the films, with Roblox's
-- text-to-speech (AudioTextToSpeech, made on this device; Config.FILM). Lines are made ahead, in the order the film
-- gives them, a few a second; a line that isn't ready when its moment comes plays without a voice (its subtitle
-- still shows), so nothing ever waits on it. An analyser on each line gives its loudness, which moves the Mayor's
-- jaw (client/MayorRig.speak).
--
--   FilmVoice.prepare(lines)   lines: { { text, who = "mayor" | "demon" } }, made in that order
--   FilmVoice.ready(text)      whether a line is ready
--   FilmVoice.waitFor(text, s) wait up to s seconds for a line
--   FilmVoice.play(text)       -> its length (seconds) and a loudness function (0..1), or nil if not ready
--   FilmVoice.stop()           cut whatever is speaking
--   FilmVoice.clear()          throw everything away
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local FilmVoice = {}

type Line = {
	text: string,
	who: string,
	tts: any,
	analyzer: any,
	ready: boolean,
	failed: boolean,
	len: number,
}

local lines: { [string]: Line } = {}
local holder: Folder? = nil
local output: any = nil
local generation = 0 -- bumps on clear (an old batch stops making lines)
local speaking: Line? = nil

local function settings(): any
	return Config.FILM or {}
end

local function make(className: string): any
	local ok, inst = pcall(Instance.new, className)
	return if ok then inst else nil
end

local function wire(a: Instance, b: Instance)
	local w = make("Wire")
	if w then
		w.SourceInstance = a
		w.TargetInstance = b
		w.Parent = a
	end
end

local function folder(): Folder
	if holder and holder.Parent then
		return holder
	end
	local f = Instance.new("Folder")
	f.Name = "FilmVoice"
	f.Parent = SoundService
	holder = f
	output = make("AudioDeviceOutput")
	if output then
		output.Parent = f
	end
	return f
end

-- Build one line's voice and its wiring; yields while it's made.
local function build(L: Line, batch: number)
	local cfg = settings()
	local f = folder()
	local tts = make("AudioTextToSpeech")
	if not tts or not output then
		L.failed = true
		return
	end
	local ok = pcall(function()
		tts.Name = "Line"
		tts.Text = L.text
		pcall(function()
			tts.AutoLocalize = false
		end)
		if L.who == "demon" then
			tts.VoiceId = tostring(cfg.demonVoiceId or "9")
			tts.Pitch = -12
			tts.Speed = 0.72
			tts.Volume = 2.2
		else
			tts.VoiceId = tostring(cfg.voiceId or "1")
			tts.Pitch = cfg.voicePitch or 0
			tts.Speed = cfg.voiceSpeed or 1
			tts.Volume = cfg.voiceVolume or 1.5
		end
		tts.Parent = f
		-- the demon's voice goes through a distortion and a big reverb
		local last: Instance = tts
		if L.who == "demon" then
			local dist = make("AudioDistortion")
			local verb = make("AudioReverb")
			if dist then
				pcall(function()
					dist.Level = 0.35
				end)
				dist.Parent = tts
				wire(last, dist)
				last = dist
			end
			if verb then
				pcall(function()
					verb.WetLevel = -4
					verb.DecayTime = 2.8
				end)
				verb.Parent = tts
				wire(last, verb)
				last = verb
			end
		end
		wire(last, output)
		local an = make("AudioAnalyzer")
		if an then
			an.Parent = tts
			wire(tts, an)
			L.analyzer = an
		end
		L.tts = tts
	end)
	if not ok or batch ~= generation then
		L.failed = true
		pcall(function()
			tts:Destroy()
		end)
		return
	end
	local loaded = false
	pcall(function()
		loaded = tts:LoadAsync() == Enum.AssetFetchStatus.Success
	end)
	if batch ~= generation or not loaded then
		L.failed = true
		pcall(function()
			tts:Destroy()
		end)
		return
	end
	L.len = tts.TimeLength or 0
	L.ready = L.len > 0
	L.failed = not L.ready
end

-- Start making the lines (in order, a few a second). Anything already made is kept.
function FilmVoice.prepare(list: { { text: string, who: string? } })
	local cfg = settings()
	if cfg.voice == false then
		return
	end
	local batch = generation
	local todo: { Line } = {}
	for _, item in list do
		local who = item.who or "mayor"
		if who == "demon" and cfg.demonVoice == false then
			continue
		end
		if not lines[item.text] then
			local L: Line = { text = item.text, who = who, tts = nil, analyzer = nil, ready = false, failed = false, len = 0 }
			lines[item.text] = L
			table.insert(todo, L)
		end
	end
	task.spawn(function()
		for _, L in todo do
			if batch ~= generation then
				return
			end
			task.spawn(build, L, batch)
			task.wait(0.3) -- (text-to-speech allows a few requests a second per player)
		end
	end)
end

function FilmVoice.ready(text: string): boolean
	local L = lines[text]
	return L ~= nil and L.ready
end

-- Wait up to `seconds` for a line to be ready (true if it is).
function FilmVoice.waitFor(text: string, seconds: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		local L = lines[text]
		if not L or L.failed then
			return false
		end
		if L.ready then
			return true
		end
		task.wait()
	end
	return FilmVoice.ready(text)
end

-- Speak a line. Returns its length and a loudness function (0..1), or nil if it isn't ready (or voices are off).
function FilmVoice.play(text: string): (number?, (() -> number)?)
	local L = lines[text]
	if not L or not L.ready or not L.tts then
		return nil, nil
	end
	FilmVoice.stop()
	local tts = L.tts
	local ok = pcall(function()
		tts.TimePosition = 0
		tts:Play()
	end)
	if not ok then
		return nil, nil
	end
	speaking = L
	local an = L.analyzer
	local t0 = os.clock()
	local len = L.len
	local function level(): number
		local playing = false
		pcall(function()
			playing = tts.IsPlaying
		end)
		if not playing or os.clock() - t0 > len + 0.2 then
			return 0
		end
		if an then
			local rms = 0
			pcall(function()
				rms = an.RmsLevel
			end)
			return math.clamp(rms * 6, 0, 1)
		end
		-- no analyser: syllables while it plays
		local s = os.clock() * 13
		return math.clamp(math.sin(s) * 0.5 + 0.5, 0, 1) * 0.8
	end
	return len, level
end

function FilmVoice.stop()
	local L = speaking
	speaking = nil
	if L and L.tts then
		pcall(function()
			L.tts:Pause()
		end)
	end
end

function FilmVoice.clear()
	generation += 1
	FilmVoice.stop()
	table.clear(lines)
	if holder then
		holder:Destroy()
		holder = nil
	end
	output = nil
end

return FilmVoice
