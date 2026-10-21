-- Sound effects and music. Ids live in Config.SOUNDS (licensed audio only: Roblox-owned assets or the
-- engine's built-in rbxasset sounds). A missing id is silent, never an error.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local Sound = {}

local group = Instance.new("SoundGroup")
group.Name = "MowALawnSfx"
group.Volume = 0.8
group.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "MowALawnMusic"
musicGroup.Volume = 0.35
musicGroup.Parent = SoundService

local templates: { [string]: Sound } = {}
for key, def in Config.SOUNDS do
	if def.id and def.id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Sfx_" .. key
		s.SoundId = def.id
		s.Volume = def.volume or 0.5
		s.SoundGroup = group
		s.Parent = SoundService
		templates[key] = s
	end
end

local lastPlayed: { [string]: number } = {}

-- Play a one-shot. `pitchVariation` randomises the pitch a little so repeated sounds don't drone; `volume`
-- scales the sound's own volume (a softer copy for other players' hits, say).
function Sound.play(key: string, pitchVariation: number?, volume: number?)
	local t = templates[key]
	if not t then
		return
	end
	local now = os.clock()
	local def = Config.SOUNDS[key]
	if (lastPlayed[key] or 0) + (def.gap or 0.03) > now then
		return
	end
	lastPlayed[key] = now
	local s = t:Clone()
	local v = pitchVariation or 0
	s.PlaybackSpeed = (def.pitch or 1) * (1 + (math.random() * 2 - 1) * v)
	s.Volume *= volume or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, math.max(2, (s.TimeLength > 0 and s.TimeLength or 2) + 0.5))
end

-- Play a one-shot at an exact pitch (rising coin ticks, combo notes).
function Sound.playAt(key: string, pitch: number, volume: number?)
	local t = templates[key]
	if not t then
		return
	end
	local s = t:Clone()
	s.PlaybackSpeed = pitch
	s.Volume *= volume or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, math.max(2, (s.TimeLength > 0 and s.TimeLength or 2) + 0.5))
end

-- Background music: loops one track per mode, cross-fading when the mode changes.
local current: Sound? = nil
function Sound.music(key: string?)
	local def = key and Config.SOUNDS[key]
	if current then
		local old = current
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		task.delay(1.6, function()
			old:Destroy()
		end)
		current = nil
	end
	if not def or not def.id or def.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Music"
	s.SoundId = def.id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = musicGroup
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2), { Volume = def.volume or 0.5 }):Play()
	current = s
end

-- A looping sound attached to a part (mower engines). Returns the Sound so the caller can stop it.
function Sound.loop(key: string, parent: Instance): Sound?
	local def = Config.SOUNDS[key]
	if not def or not def.id or def.id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Looped = true
	s.Volume = def.volume or 0.4
	s.RollOffMaxDistance = 80
	s.SoundGroup = group
	s.Parent = parent
	s:Play()
	return s
end

return Sound
