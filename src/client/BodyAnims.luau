-- BodyAnims: your character's own swings, the ones other players see (and you, from outside: a zoomed-out camera,
-- a cutscene). Owner's brief, 28 Oct: "both first-person hands and matching third-person body animations (fwjelaa
-- kit)". Every first-person clip in client/ViewAnims has an R15 twin made with fwjelaa's animation kit (FWJ STUDIOS)
-- that lands on the same contact frame: the same clip plays here at the same speed and holds on the same hit-stop,
-- so what you feel and what the others see hit together.
--   * upper body only (waist, head, arms): the walk and idle play on underneath, you punch while you walk up.
--   * live servers play the uploaded animations: their ids are in shared/WeaponAnimIds ("mow_<clip>", e.g. mow_JabL;
--     shared/AnimIds is checked first). Studio plays the KeyframeSequences in ReplicatedStorage.MowALawnAnims
--     (R15_Mow_<clip>) first: they load for whoever is testing, while an uploaded animation only loads in an
--     experience its owner has granted it (Creator Hub > the animation > Permissions). A live server without an id
--     plays nothing.
--   * R15 characters only (the kit's rig); R6 avatars keep the default look.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local AnimIds = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("AnimIds")) :: { [string]: string }
local WeaponAnimIds = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("WeaponAnimIds")) :: { [string]: string }
local ViewAnims = require(script.Parent.ViewAnims)

local BodyAnims = {}
local player = Players.LocalPlayer

local FADE_IN = 0.04 -- the swing starts almost at once: its wind-up is already in the clip
local FADE_OUT = 0.12 -- the last swing hands back to the next one / the idle softly

-- id for a first-person clip's twin (false: none)
local ids: { [string]: string | false } = {}
local function idFor(clip: string): string | false
	local known = ids[clip]
	if known ~= nil then
		return known
	end
	local id: string | false = false
	if RunService:IsStudio() then
		local folder = ReplicatedStorage:FindFirstChild("MowALawnAnims")
		local ks = folder and folder:FindFirstChild("R15_Mow_" .. clip)
		if ks and ks:IsA("KeyframeSequence") then
			local ok, temp = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
			end)
			id = if ok and type(temp) == "string" then temp else false
		end
	end
	if not id then
		id = AnimIds["mow_" .. clip] or WeaponAnimIds["mow_" .. clip] or false
	end
	ids[clip] = id
	return id
end

local animatorNow: Animator? = nil
local tracks: { [string]: AnimationTrack } = {}
local current: AnimationTrack? = nil
local currentRate = 1
local serial = 0 -- bumps on every swing, so a stale hit-stop never restarts a newer one

local function animator(): Animator?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local a = if hum and hum.RigType == Enum.HumanoidRigType.R15 then hum:FindFirstChildOfClass("Animator") else nil
	if a ~= animatorNow then
		animatorNow = a
		table.clear(tracks) -- a new character: its own tracks
		current = nil
	end
	return a
end

local function trackFor(clip: string): AnimationTrack?
	local a = animator()
	if not a then
		return nil
	end
	local tr = tracks[clip]
	if tr then
		return tr
	end
	local id = idFor(clip)
	if not id then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	anim.Name = clip -- (30 Oct) client/RiderPose finds your scythe swing by its track's name (Studio's ids are local)
	local ok, loaded = pcall(function()
		return a:LoadAnimation(anim)
	end)
	if not ok or not loaded then
		return nil
	end
	-- over the idle, the walk and a held tool's pose (Animate's tool pose is Action)
	loaded.Priority = Enum.AnimationPriority.Action2
	loaded.Looped = false
	tracks[clip] = loaded
	return loaded
end

ViewAnims.onSwing(function(_toolId: string?, plan: any)
	local tr = trackFor(plan.clip)
	if not tr then
		return
	end
	serial += 1
	if current and current ~= tr and current.IsPlaying then
		current:Stop(FADE_OUT)
	end
	current, currentRate = tr, plan.rate
	if tr.IsPlaying then
		tr.TimePosition = 0 -- the same punch again before the last one ended: start it over
		tr:AdjustSpeed(plan.rate)
	else
		tr:Play(FADE_IN, 1, plan.rate)
	end
end)

-- the hands hang on the contact frame: so does the body
ViewAnims.onFreeze(function(seconds: number)
	local tr = current
	if not tr or not tr.IsPlaying or seconds <= 0 then
		return
	end
	local mine = serial
	tr:AdjustSpeed(0)
	task.delay(seconds, function()
		if serial == mine and tr.IsPlaying then
			tr:AdjustSpeed(currentRate)
		end
	end)
end)

-------------------------------------------------------------------------------------------------------------
-- (28 Oct, brief: "both first-person hands and matching third-person body animations") the auto tools have no
-- swings: while you hold one your body holds it the way your hands do, looped (Action2, over Animate's held-tool pose;
-- an auto tool never swings, so nothing else plays at that priority): both hands on the mower's bar, leaning into it
-- (the push mower and the laser mower: R15_Mow_PushHold), the weed whacker swept low from side to side
-- (R15_Mow_WhackSweep).
-------------------------------------------------------------------------------------------------------------
local HOLD: { [string]: string } = { PushMower = "PushHold", LaserMower = "PushHold", WeedWhacker = "WhackSweep" }
local holding: AnimationTrack? = nil
local holdingName: string? = nil
local function setHold(name: string?)
	if name == holdingName and (name == nil or (holding and holding.IsPlaying)) then
		return
	end
	if holding then
		holding:Stop(0.25)
	end
	holding, holdingName = nil, name
	if not name then
		return
	end
	local tr = trackFor(name)
	if not tr then
		return
	end
	tr.Priority = Enum.AnimationPriority.Action2
	tr.Looped = true
	tr:Play(0.3)
	holding = tr
end
local function refreshHold()
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ToolId")
	setHold(if type(id) == "string" then HOLD[id] else nil)
end
local holdConns: { RBXScriptConnection } = {}
local function watchTools(char: Model)
	for _, c in holdConns do
		c:Disconnect()
	end
	table.clear(holdConns)
	holding, holdingName = nil, nil -- (a new character: its own tracks)
	table.insert(holdConns, char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			task.defer(refreshHold)
		end
	end))
	table.insert(holdConns, char.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") then
			task.defer(refreshHold)
		end
	end))
	task.defer(refreshHold)
end

-- load every twin as the character arrives, so the first punch doesn't wait for its animation
local function preload()
	if not animator() then
		return
	end
	for name in ViewAnims.CLIPS do
		trackFor(name)
	end
	for _, name in HOLD do
		trackFor(name)
	end
end
player.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum:WaitForChild("Animator", 10)
		task.wait(0.5)
		preload()
		watchTools(char)
	end
end)
task.defer(function()
	preload()
	if player.Character then
		watchTools(player.Character)
	end
end)

-- (the dev panel) the twin of every clip, and whether it can play here
function BodyAnims.status(): { [string]: boolean }
	local out = {}
	for name in ViewAnims.CLIPS do
		out[name] = idFor(name) ~= false
	end
	for _, name in HOLD do
		out[name] = idFor(name) ~= false
	end
	return out
end

return BodyAnims
