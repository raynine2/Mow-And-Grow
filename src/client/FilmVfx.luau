--!strict
-- FilmVfx (29 Oct; owner's brief, 28 Oct: "remake the VFX of the films with the VFX Forge plugin ... rebuild each one
-- in VFX Forge as a template in ReplicatedStorage.FilmVFX.<Name>, played from the film scripts through the Emit
-- module ... keep the old code as the fallback ... lower budgets on phones and in Potato Mode, client-only,
-- everything cleaned up when the film ends or is skipped").
-- Plays the films' VFX Forge templates (ReplicatedStorage.FilmVFX.<Name>: built by
-- ServerStorage.MowALawnTools.BuildFilmVfx, editable in VFX Forge) with the plugin's own Emit Module
-- (ReplicatedStorage.EmitModule; its VFX-DL licence allows runtime game use only, so only the game's own scripts may
-- load it). The films keep their timing (Film.at) and their sounds (client/FilmAudio).
--   FilmVfx.play(name, at, opts?) -> the playing clone, or nil when the module or the template is missing: the film
--     then plays its old effect. `at`: a CFrame or a position. opts:
--       scale   size (the whole template: parts, particles, rings, debris, beams)
--       color   recolours the template's Tint layers (a firework's colour, the area's colour)
--       follow  a part the effect rides on (the falling spark, an eye, someone being lifted)
--       screen  studs in front of the camera: the effect stays in front of it (a burst over the picture)
--       hold    seconds for the template's Hold layers (how long a shot needs them)
--       life    seconds before it's removed (default: the template's Life)
--   FilmVfx.stop(clone)   ends one early (its quick flashes run out at once, everything else goes)
--   FilmVfx.clear()       ends everything the films made (the films' end and SKIP)
--   FilmVfx.lead(name)    seconds of build-up before a template's hit (its Lead attribute)
-- Phones and Potato Mode get fewer particles, chunks and copies, and no Optional layers (FilmVfx.budget()).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Potato = require(script.Parent.Potato)
local PhonePerf = require(script.Parent.PhonePerf)

local FilmVfx = {}

local api: any = nil
local failed = false
local live: { [Model]: { RBXScriptConnection | string } } = {}
local holder: Folder? = nil
local nextId = 0

-- The plugin's Emit Module, initialised once (nil if it's missing or broken).
local function emitApi(): any
	if api or failed then
		return api
	end
	local m = ReplicatedStorage:FindFirstChild("EmitModule")
	if not (m and m:IsA("ModuleScript")) then
		failed = true
		return nil
	end
	local ok, res = pcall(require, m)
	if not ok or type(res) ~= "table" or type(res.emit) ~= "function" then
		warn("FilmVfx: EmitModule didn't load: " .. tostring(res))
		failed = true
		return nil
	end
	local okInit, err = pcall(res.init)
	if not okInit then
		warn("FilmVfx: EmitModule.init failed: " .. tostring(err))
		failed = true
		return nil
	end
	api = res
	return api
end

local function folder(): Folder
	if holder and holder.Parent then
		return holder
	end
	local f = Instance.new("Folder")
	f.Name = "FilmVfxLive"
	f.Archivable = false
	f.Parent = workspace
	holder = f
	return f
end

function FilmVfx.template(name: string): Model?
	local f = ReplicatedStorage:FindFirstChild("FilmVFX")
	local t = f and f:FindFirstChild(name)
	if t and t:IsA("Model") and t.PrimaryPart then
		return t
	end
	return nil
end

-- True when FilmVfx.play(name) would play.
function FilmVfx.has(name: string): boolean
	return RunService:IsClient() and FilmVfx.template(name) ~= nil and emitApi() ~= nil
end

function FilmVfx.lead(name: string): number
	local t = FilmVfx.template(name)
	local l = t and t:GetAttribute("Lead")
	return if type(l) == "number" then l else 0
end

-- 1 on a PC; less on phones, low graphics and in Potato Mode.
function FilmVfx.budget(): number
	if Potato.on then
		return 0.35
	end
	if PhonePerf.on then
		return 0.55
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if ok and level ~= 0 and level <= 3 then
		return 0.6
	end
	return 1
end

-- Fewer particles / chunks / copies; the Optional layers go below 0.6.
local function trim(m: Model, s: number)
	if s >= 0.999 then
		return
	end
	local drop = {}
	for _, d in m:GetDescendants() do
		if s < 0.6 and d:GetAttribute("Optional") then
			table.insert(drop, d)
			continue
		end
		local n = d:GetAttribute("EmitCount")
		if type(n) == "number" and n > 1 then
			d:SetAttribute("EmitCount", math.max(1, math.floor(n * s + 0.5)))
		end
		local amount = d:GetAttribute("Amount")
		if typeof(amount) == "NumberRange" then
			d:SetAttribute("Amount", NumberRange.new(math.max(1, math.floor(amount.Min * s)), math.max(1, math.floor(amount.Max * s))))
		end
		local seg = d:GetAttribute("Segments")
		if type(seg) == "number" then
			d:SetAttribute("Segments", math.max(5, math.floor(seg * s + 0.5)))
		end
		local rate = d:GetAttribute("Rate")
		if type(rate) == "number" then
			d:SetAttribute("Rate", rate * s)
		end
		if d:IsA("ParticleEmitter") and d.Rate > 0 then
			d.Rate *= s
		end
	end
	for _, d in drop do
		d:Destroy()
	end
end

-- Sizes everything: the parts and particles (Model:ScaleTo) and the distances VFX Forge keeps in attributes.
local function resize(m: Model, s: number)
	if math.abs(s - 1) < 0.001 then
		return
	end
	m:ScaleTo(m:GetScale() * s)
	for _, d in m:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Grower") then
			-- (ScaleTo scaled the model itself: its grow-to sizes follow)
			for _, k in { "Scale_Start", "Scale_End" } do
				local v = d:GetAttribute(k)
				if type(v) == "number" then
					d:SetAttribute(k, v * s)
				end
			end
		end
		for _, k in { "Radius", "InheritanceRadius", "Width0_Start", "Width0_End", "Width1_Start", "Width1_End" } do
			local v = d:GetAttribute(k)
			if type(v) == "number" then
				d:SetAttribute(k, v * s)
			end
		end
		for _, k in { "MinSize", "MaxSize", "Offset_Start", "Offset_End", "BaseOffset" } do
			local v = d:GetAttribute(k)
			if typeof(v) == "Vector3" then
				d:SetAttribute(k, v * s)
			end
		end
		local lin = d:GetAttribute("LinearMagnitude")
		if typeof(lin) == "NumberRange" then
			d:SetAttribute("LinearMagnitude", NumberRange.new(lin.Min * s, lin.Max * s))
		end
	end
end

-- Recolours the layers marked Tint.
local function tint(m: Model, color: Color3)
	for _, d in m:GetDescendants() do
		if not d:GetAttribute("Tint") then
			continue
		end
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			local kp = d.Color.Keypoints
			-- (keep a white-hot start if the layer has one)
			if #kp >= 2 and kp[1].Value == Color3.new(1, 1, 1) then
				d.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, kp[1].Value), ColorSequenceKeypoint.new(math.min(0.3, kp[2].Time), color), ColorSequenceKeypoint.new(1, color) })
			else
				d.Color = ColorSequence.new(color)
			end
		elseif d:IsA("Model") then
			for _, p in d:GetChildren() do
				if p:IsA("BasePart") then
					p.Color = color
				end
			end
		elseif d:IsA("BasePart") or d:IsA("Light") then
			(d :: any).Color = color
		end
	end
end

local function finish(m: Model)
	local hooks = live[m]
	live[m] = nil
	if hooks then
		for _, h in hooks do
			if typeof(h) == "RBXScriptConnection" then
				h:Disconnect()
			else
				RunService:UnbindFromRenderStep(h)
			end
		end
	end
	if m.Parent then
		m:Destroy()
	end
end

export type Opts = {
	scale: number?,
	color: Color3?,
	follow: BasePart?,
	screen: number?,
	hold: number?,
	life: number?,
}

-- (Studio only, for screenshots of a flash inside a film) setting the workspace attribute FilmVfxFreeze to
-- "<template>[;delay]" stops the next play of that template in place `delay` s in (default 0.1) and holds the camera
-- still for 5 s. Returns how long the clone has to stay (0 = not frozen).
local function studioFreeze(name: string, m: Model): number
	local v = workspace:GetAttribute("FilmVfxFreeze")
	if type(v) ~= "string" then
		return 0
	end
	local want, delay = string.match(v, "^([^;]+);?(.*)$")
	if want ~= name then
		return 0
	end
	workspace:SetAttribute("FilmVfxFreeze", nil)
	local after = tonumber(delay) or 0.1
	task.delay(after, function()
		if not m.Parent then
			return
		end
		for _, d in m:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.TimeScale = 0.01
			elseif d:IsA("Model") and d:FindFirstChild("Start") then
				d:SetAttribute("SpeedOverride", 0.01)
			end
		end
		local cam = workspace.CurrentCamera
		local cf, fov = cam.CFrame, cam.FieldOfView
		RunService:BindToRenderStep("FilmVfxFreezeCam", Enum.RenderPriority.Last.Value, function()
			local c = workspace.CurrentCamera
			if c then
				c.CFrame = cf
				c.FieldOfView = fov
			end
		end)
		workspace:SetAttribute("FilmVfxFrozen", name)
		task.delay(5, function()
			RunService:UnbindFromRenderStep("FilmVfxFreezeCam")
			workspace:SetAttribute("FilmVfxFrozen", nil)
		end)
	end)
	return after + 6
end

-- Plays template `name` at `at`. Returns the clone, or nil (then play the old effect).
function FilmVfx.play(name: string, at: CFrame | Vector3, opts: Opts?): Model?
	if not RunService:IsClient() then
		return nil
	end
	local t = FilmVfx.template(name)
	local a = t and emitApi()
	if not (t and a) then
		return nil
	end
	local o: Opts = opts or {}
	local cam = workspace.CurrentCamera
	local cf = if typeof(at) == "Vector3" then CFrame.new(at) else at
	if o.screen and cam then
		cf = cam.CFrame * CFrame.new(0, 0, -o.screen)
	end
	local m = t:Clone()
	trim(m, FilmVfx.budget())
	resize(m, o.scale or 1)
	if o.color then
		tint(m, o.color)
	end
	if o.hold then
		for _, d in m:GetDescendants() do
			if d:GetAttribute("Hold") then
				d:SetAttribute("EffectDuration", NumberRange.new(o.hold))
			end
		end
	end
	m:PivotTo(cf)
	m.Parent = folder()
	local hooks: { RBXScriptConnection | string } = {}
	live[m] = hooks
	local follow = o.follow
	if o.screen then
		nextId += 1
		local id = "FilmVfxScreen" .. nextId
		local dist = o.screen
		RunService:BindToRenderStep(id, Enum.RenderPriority.Camera.Value + 3, function()
			local c = workspace.CurrentCamera
			if c and m.Parent then
				m:PivotTo(c.CFrame * CFrame.new(0, 0, -dist))
			end
		end)
		table.insert(hooks, id)
	elseif follow then
		local rel = follow.CFrame:ToObjectSpace(cf)
		table.insert(hooks, RunService.RenderStepped:Connect(function()
			if follow.Parent and m.Parent then
				m:PivotTo(follow.CFrame * rel)
			end
		end))
	end
	local ok, err = pcall(a.emit, m)
	if not ok then
		warn("FilmVfx: emit " .. name .. " failed: " .. tostring(err))
		finish(m)
		return nil
	end
	local life = o.life or (t:GetAttribute("Life") :: number?) or 4
	if RunService:IsStudio() then
		life = math.max(life, studioFreeze(name, m))
	end
	task.delay(life, function()
		if live[m] then
			finish(m)
		end
	end)
	return m
end

-- Ends one early: its quick flashes run out at once (VFX Forge's speed override), the rest goes with the clone.
function FilmVfx.stop(m: Model?)
	if not (m and live[m]) then
		return
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Model") and d:FindFirstChild("Start") then
			d:SetAttribute("SpeedOverride", 1e4)
			if d:GetAttribute("Enabled") ~= nil then
				d:SetAttribute("Enabled", false)
			end
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	local hooks = live[m]
	live[m] = {} -- (still tracked: clear() can take it)
	task.delay(0.1, function()
		if live[m] then
			live[m] = hooks
			finish(m)
		end
	end)
end

-- Ends everything the films made.
function FilmVfx.clear()
	for m in live do
		FilmVfx.stop(m)
	end
end

-- (Studio only, for checking a template on screen) setting the workspace attribute FilmVfxPreview to
-- "<template>[;scale]" plays it 40 studs in front of the camera, a little low; an empty string clears it.
if RunService:IsStudio() and RunService:IsClient() then
	workspace:GetAttributeChangedSignal("FilmVfxPreview"):Connect(function()
		local v = workspace:GetAttribute("FilmVfxPreview")
		if type(v) ~= "string" or v == "" then
			FilmVfx.clear()
			return
		end
		local name, scale = string.match(v, "^([^;]+);?(.*)$")
		local cam = workspace.CurrentCamera
		if name and cam then
			local at = cam.CFrame * CFrame.new(0, -6, -40)
			FilmVfx.play(name, CFrame.lookAt(at.Position, cam.CFrame.Position), { scale = tonumber(scale) or 1 })
		end
	end)
end

return FilmVfx
