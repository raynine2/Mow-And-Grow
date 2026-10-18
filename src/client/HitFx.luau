-- Hit effects, built like the Chop A Forest trailer's chops. The look of every event (punch, blade hit, auto
-- tool, cut, mutation reveal) is data in shared/FxPresets.json: layered particle bursts (a hot glow, an impact
-- flipbook, splinters stretched along their flight, spinning blade bits, a cartoon smoke poof) plus chunky 3D
-- clippings that tumble and bounce, a white flash and a wobble on the clump, a hit-stop and a camera kick.
-- tools/preview/fx_sim.py renders the same presets in Blender, so changes can be judged frame by frame.
--
-- Your own swings are predicted: the impact plays on the frame your fist or blade connects instead of waiting
-- for the server; the server's "chip" for that clump then only updates the HP bar.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local Presets = require(Shared:WaitForChild("FxPresets")) :: any
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local HitFx = {}
local player = Players.LocalPlayer

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local function tex(key: string): string
	return FxIds[key] or (if key == "poof" or key == "smoke" then SMOKE else SPARKLE)
end

local folder = Instance.new("Folder")
folder.Name = "HitFx"
folder.Parent = workspace

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

-------------------------------------------------------------------------------------------------------------
-- preset data -> Roblox values
-------------------------------------------------------------------------------------------------------------
local function rgb(v: { number }): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

-- A colour stop is [r,g,b] or a word that follows the clump's colour.
local function stopColor(v: any, grass: Color3): Color3
	if type(v) == "table" then
		return rgb(v)
	elseif v == "grassLight" then
		return UI.shade(grass, 1.45):Lerp(Color3.new(1, 1, 0.9), 0.25)
	elseif v == "grassPale" then
		return UI.shade(grass, 1.6):Lerp(Color3.new(1, 1, 0.92), 0.5)
	elseif v == "grassDark" then
		return UI.shade(grass, 0.75)
	end
	return grass
end

local function colorSeq(stops: { any }, grass: Color3): ColorSequence
	local keys = {}
	for _, s in stops do
		table.insert(keys, ColorSequenceKeypoint.new(s[1], stopColor(s[2], grass)))
	end
	return ColorSequence.new(keys)
end

local function numSeq(stops: { any }?, default: number): NumberSequence
	if not stops then
		return NumberSequence.new(default)
	end
	local keys = {}
	for _, s in stops do
		table.insert(keys, NumberSequenceKeypoint.new(s[1], s[2]))
	end
	return NumberSequence.new(keys)
end

local function range(v: { number }?, default: number): NumberRange
	return if v then NumberRange.new(v[1], v[2]) else NumberRange.new(default)
end

-- A number sequence's value at k (0..1).
local function numAt(stops: { any }?, k: number, default: number): number
	if not stops then
		return default
	end
	if k <= stops[1][1] then
		return stops[1][2]
	end
	for i = 1, #stops - 1 do
		local a, b = stops[i], stops[i + 1]
		if k <= b[1] then
			return a[2] + (b[2] - a[2]) * (k - a[1]) / math.max(b[1] - a[1], 1e-6)
		end
	end
	return stops[#stops][2]
end

local function colorAt(stops: { any }, k: number, grass: Color3): Color3
	if k <= stops[1][1] then
		return stopColor(stops[1][2], grass)
	end
	for i = 1, #stops - 1 do
		local a, b = stops[i], stops[i + 1]
		if k <= b[1] then
			return stopColor(a[2], grass):Lerp(stopColor(b[2], grass), (k - a[1]) / math.max(b[1] - a[1], 1e-6))
		end
	end
	return stopColor(stops[#stops][2], grass)
end

-------------------------------------------------------------------------------------------------------------
-- where an effect sits on a clump
-------------------------------------------------------------------------------------------------------------
local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Flat direction from the clump toward you (the side you hit).
local function outFrom(pos: Vector3): Vector3
	local root = myRoot()
	local d = if root then Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z) else Vector3.zAxis
	return if d.Magnitude > 0.1 then d.Unit else Vector3.zAxis
end

local function anchorFor(layer: any, pos: Vector3, out: Vector3): CFrame
	local at: Vector3
	if layer.at == "contact" then
		-- where the fist / blade lands: the clump's near side, a bit below your eyes, a little to the right
		local cam = workspace.CurrentCamera
		local eyeY = if cam then cam.CFrame.Position.Y else 4.5
		local right = out:Cross(Vector3.yAxis) -- your right, seen from where you stand
		at = Vector3.new(pos.X, math.clamp(eyeY - 1.6, 1.2, 3.2), pos.Z) + out * 1.3 - right * 0.35
	elseif layer.at == "top" then
		at = Vector3.new(pos.X, layer.height or 3.2, pos.Z)
	elseif layer.at == "point" then
		-- exactly at `pos` (boss effects pass a point on the boss), raised by `height`
		at = pos + Vector3.new(0, layer.height or 0, 0)
	else
		at = Vector3.new(pos.X, layer.height or 0.6, pos.Z)
	end
	if layer.dir == "out" then
		return CFrame.lookAt(at, at + out) * CFrame.Angles(-math.rad(layer.tilt or 60), 0, 0)
	end
	return CFrame.new(at)
end

-------------------------------------------------------------------------------------------------------------
-- layers
-------------------------------------------------------------------------------------------------------------
-- One particle burst: a throwaway emitter on an attachment, emitted once, particles fly along its +Y.
local function particles(layer: any, cf: CFrame, grass: Color3)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.CFrame = cf
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.EmissionDirection = Enum.NormalId.Top
	e.Texture = tex(layer.texture)
	if layer.flipbook and FxIds[layer.texture] then
		e.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[layer.flipbook]
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Color = colorSeq(layer.color, grass)
	e.Size = numSeq(layer.size, 1)
	e.Transparency = numSeq(layer.transparency, 0)
	if layer.squash then
		e.Squash = numSeq(layer.squash, 0)
	end
	e.Lifetime = range(layer.lifetime, 0.5)
	e.Speed = range(layer.speed, 0)
	e.Rotation = range(layer.rotation, 0)
	e.RotSpeed = range(layer.rotSpeed, 0)
	local sp = layer.spread or { 0, 0 }
	e.SpreadAngle = Vector2.new(sp[1], sp[2])
	e.Drag = layer.drag or 0
	local ac = layer.acceleration or { 0, 0, 0 }
	e.Acceleration = Vector3.new(ac[1], ac[2], ac[3])
	e.Orientation = (Enum.ParticleOrientation :: any)[layer.orientation or "FacingCamera"]
	e.LightEmission = layer.lightEmission or 0
	e.LightInfluence = layer.lightInfluence or 0
	e.Brightness = layer.brightness or 1
	e.ZOffset = layer.zOffset or 0
	e.Parent = a
	e:Emit(layer.count or 1)
	Debris:AddItem(a, (layer.lifetime and layer.lifetime[2] or 1) + 0.3)
end

-- One image that always faces you, its size exact in studs (a BillboardGui), animated every frame: size,
-- transparency and colour over its life, and the flipbook's 16 frames (4x4 grid of a 1024 image).
local function spriteOne(layer: any, cf: CFrame, grass: Color3)
	local off = layer.offset or 0
	local start = cf.Position + Vector3.new(rand(-off, off), rand(-off, off) * 0.6, rand(-off, off))
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = start
	local gui = Instance.new("BillboardGui")
	gui.Adornee = a
	gui.LightInfluence = 0
	gui.Brightness = layer.brightness or 1
	gui.AlwaysOnTop = false
	gui.StudsOffset = Vector3.new(0, 0, layer.zOffset or 0)
	gui.Size = UDim2.fromScale(0.01, 0.01)
	gui.Parent = a
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = tex(layer.texture)
	local rot = layer.rotation or { 0, 0 }
	img.Rotation = rand(rot[1], rot[2])
	local flip = layer.flipbook == true and FxIds[layer.texture] ~= nil
	if flip then
		img.ImageRectSize = Vector2.new(256, 256)
	end
	img.Parent = gui
	local lt = layer.lifetime or { 0.3, 0.3 }
	local life = rand(lt[1], lt[2])
	local born = os.clock()
	local conn: RBXScriptConnection
	local function step()
		local age = os.clock() - born
		local k = age / life
		if k >= 1 then
			conn:Disconnect()
			a:Destroy()
			return
		end
		local size = numAt(layer.size, k, 1)
		gui.Size = UDim2.fromScale(size, size)
		img.ImageTransparency = numAt(layer.transparency, k, 0)
		img.ImageColor3 = colorAt(layer.color, k, grass)
		if flip then
			local f = math.min(15, math.floor(k * 16))
			img.ImageRectOffset = Vector2.new((f % 4) * 256, (f // 4) * 256)
		end
		a.Position = start + Vector3.new(0, (layer.rise or 0) * age, 0)
	end
	conn = RunService.RenderStepped:Connect(step)
	step()
end

local function sprite(layer: any, cf: CFrame, grass: Color3)
	for i = 1, layer.count or 1 do
		local wait = (layer.delay or 0) * (i - 1)
		if wait > 0 then
			task.delay(wait, spriteOne, layer, cf, grass)
		else
			spriteOne(layer, cf, grass)
		end
	end
end

-- Chunky 3D clippings (Blender fx_clip_a/b/c, white body tinted with the grass colour), simulated on this
-- client so they really tumble and bounce. Brick wedges until the models are uploaded.
local live = 0
local MAX_LIVE = 60
local CLIP_PHYS = PhysicalProperties.new(0.5, 0.8, 0.3)
local CLIPS = { "fx_clip_a", "fx_clip_b", "fx_clip_c" }

local function clipBody(grass: Color3, scale: number): BasePart
	local models = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = models and models:FindFirstChild(CLIPS[math.random(1, #CLIPS)])
	local tint = UI.shade(grass, rand(0.9, 1.25))
	if template and template:IsA("Model") then
		local m = template:Clone()
		m:ScaleTo(scale * rand(0.85, 1.2))
		local body: BasePart? = nil
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and p.Color == Color3.new(1, 1, 1) then
				body = p
			end
		end
		if body then
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") then
					p.Anchored = false
					p.CanQuery = false
					p.CanTouch = false
					p.CastShadow = true
					if p == body then
						p.Color = tint
						p.CustomPhysicalProperties = CLIP_PHYS
					else
						p.CanCollide = false
						p.Massless = true
						local w = Instance.new("WeldConstraint")
						w.Part0 = body
						w.Part1 = p
						w.Parent = p
					end
				end
			end
			m.Parent = folder
			return body
		end
		m:Destroy()
	end
	local p = Instance.new("WedgePart")
	p.Size = Vector3.new(0.45, 0.15, 0.9) * scale
	p.Color = tint
	p.Material = Enum.Material.SmoothPlastic
	p.CanQuery = false
	p.CanTouch = false
	p.CustomPhysicalProperties = CLIP_PHYS
	p.Parent = folder
	return p
end

local function clippings(layer: any, cf: CFrame, out: Vector3, grass: Color3, count: number)
	local o = layer.out or { 6, 12 }
	local u = layer.up or { 10, 16 }
	for _ = 1, count do
		if live >= MAX_LIVE then
			return
		end
		live += 1
		local body = clipBody(grass, layer.size or 1)
		local holder = body.Parent :: Instance
		body.CFrame = CFrame.new(cf.Position + Vector3.new(rand(-0.4, 0.4), rand(-0.3, 0.3), rand(-0.4, 0.4))) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		local side = Vector3.new(rand(-1, 1), 0, rand(-1, 1)) * (layer.side or 6)
		body.AssemblyLinearVelocity = out * rand(o[1], o[2]) + side + Vector3.new(0, rand(u[1], u[2]), 0)
		body.AssemblyAngularVelocity = Vector3.new(rand(-22, 22), rand(-22, 22), rand(-22, 22))
		local stay = rand(1.2, 1.8)
		task.delay(stay, function()
			if body.Parent then
				body.Anchored = true
				for _, p in (if holder:IsA("Model") then holder:GetChildren() else { body }) do
					if p:IsA("BasePart") then
						TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
					end
				end
			end
		end)
		task.delay(stay + 0.35, function()
			live -= 1
			if holder:IsA("Model") then
				holder:Destroy()
			else
				body:Destroy()
			end
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the clump: find it, flash it white, wobble it
-------------------------------------------------------------------------------------------------------------
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function grassFolder(): Instance?
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Grass")
end

local function clumpOf(part: Instance): Model?
	local m = part:FindFirstAncestorOfClass("Model")
	while m and not (m.Name:sub(1, 5) == "tuft_" and m.Name:sub(-4) ~= "_cut") do
		m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
	end
	return m
end

local function clumpAt(pos: Vector3, radius: number): Model?
	local grass = grassFolder()
	if not grass then
		return nil
	end
	overlap.FilterDescendantsInstances = { grass }
	local best, bestD = nil, math.huge
	for _, part in workspace:GetPartBoundsInRadius(Vector3.new(pos.X, 1.5, pos.Z), radius, overlap) do
		local m = clumpOf(part)
		if m then
			local p = m:GetPivot().Position
			local d = Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local highlight = Instance.new("Highlight")
highlight.Name = "HitFlash"
highlight.FillColor = Color3.new(1, 1, 1)
highlight.FillTransparency = 1
highlight.OutlineTransparency = 1
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Parent = folder
local function flashClump(m: Model, amount: number)
	highlight.Adornee = m
	highlight.FillTransparency = 1 - amount
	TweenService:Create(highlight, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 }):Play()
end

local wobbling: { [Model]: boolean } = {}
local function wobble(m: Model, away: Vector3, strength: number)
	if wobbling[m] then
		return
	end
	wobbling[m] = true
	local base = m:GetPivot()
	local axis = Vector3.yAxis:Cross(away)
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > 0.55 or not m.Parent then
			conn:Disconnect()
			wobbling[m] = nil
			if m.Parent then
				m:PivotTo(base)
			end
			return
		end
		-- a damped spring: snaps away, swings back past upright, settles; a little squash on the first frames
		local angle = math.rad(14 * strength) * math.exp(-t * 8) * math.cos(t * 24)
		m:PivotTo(CFrame.new(base.Position) * CFrame.fromAxisAngle(axis, angle) * base.Rotation)
	end)
end

-- The cut "pop": a copy of the clump (its Blender model) flashes white, swells a little and shrinks away, so
-- the clump bursts instead of just disappearing (the server has already swapped it for stubble).
local function pop(spec: any, pos: Vector3, style: string?)
	local models = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = style and models and models:FindFirstChild("tuft_" .. style)
	if not (template and template:IsA("Model")) then
		return
	end
	local m = template:Clone()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	m:PivotTo(CFrame.new(pos.X, 0.02, pos.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 1 - (spec.white or 0.7)
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = m
	m.Parent = folder
	local grow, t1, t2 = spec.grow or 1.15, spec.growTime or 0.05, spec.shrinkTime or 0.13
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - born
		if t >= t1 + t2 then
			conn:Disconnect()
			m:Destroy()
			return
		end
		local s = if t < t1 then 1 + (grow - 1) * (t / t1) else grow * (1 - ((t - t1) / t2) ^ 2)
		m:ScaleTo(math.max(0.02, s))
	end)
end

-------------------------------------------------------------------------------------------------------------
-- camera kick and hit-stop
-------------------------------------------------------------------------------------------------------------
local BASE_FOV = 70
local function kick(amount: number)
	local cam = workspace.CurrentCamera
	if not cam or amount <= 0 then
		return
	end
	cam.FieldOfView = BASE_FOV - amount
	TweenService:Create(cam, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = BASE_FOV }):Play()
end

-------------------------------------------------------------------------------------------------------------
-- play an event
-------------------------------------------------------------------------------------------------------------
-- event: punch / hit / auto / cut / reveal, or a boss event (client/BossFx). pos: the clump's foot. grass: its
-- colour (or the mutation's / the boss's).
function HitFx.play(event: string, pos: Vector3, grass: Color3, mine: boolean, clump: Model?, style: string?)
	local preset = Presets[event]
	if not preset then
		return
	end
	if preset.pop then
		pop(preset.pop, pos, style)
	end
	local out = outFrom(pos)
	for _, layer in preset.layers do
		if layer.mineOnly and not mine then
			continue
		end
		local cf = anchorFor(layer, pos, out)
		if layer.kind == "particles" then
			particles(layer, cf, grass)
		elseif layer.kind == "sprite" then
			sprite(layer, cf, grass)
		elseif layer.kind == "clippings" then
			local n = if mine then (layer.mineCount or layer.count) else (layer.otherCount or math.ceil(layer.count / 2))
			clippings(layer, cf, out, grass, n)
		end
	end
	if mine then
		local m = clump or clumpAt(pos, 2.5)
		if m then
			if (preset.flash or 0) > 0 then
				flashClump(m, preset.flash)
			end
			if (preset.wobble or 0) > 0 then
				wobble(m, -out, preset.wobble)
			end
		end
		if event == "punch" or event == "hit" or event == "auto" then
			Sound.play("chip", 0.15)
		end
		kick(preset.kick or 0)
		if (preset.hitstop or 0) > 0 then
			State.emit("hitstop", preset.hitstop)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- prediction: your own swing plays its impact the moment it lands
-------------------------------------------------------------------------------------------------------------
local predicted: { { pos: Vector3, at: number } } = {}
local STRIKE_DELAY = 0.11 -- seconds from the swing to contact (ViewModel's jab / chop reach the clump here)

local function clumpColor(m: Model): Color3
	-- the clump's main grass colour: its biggest part
	local best, size = nil, 0
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > size then
				best, size = p, v
			end
		end
	end
	return if best then best.Color else Color3.fromRGB(90, 170, 60)
end

-- Called when you swing a hand tool. Mirrors the server's reach: centre a little ahead of you, tool radius.
function HitFx.swing(toolId: string?)
	local def = nil
	for _, t in Config.TOOLS do
		if t.id == toolId then
			def = t
		end
	end
	local root = myRoot()
	local d = State.data
	if not def or def.kind ~= "swing" or not root or not d or not d.run or d.run.carry >= (d.carryMax or 1) then
		return
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then
		return
	end
	local centre = root.Position + look.Unit * def.radius * 0.45
	local m = clumpAt(centre, def.radius)
	if not m then
		return
	end
	local pos = m:GetPivot().Position
	table.insert(predicted, { pos = pos, at = os.clock() })
	task.delay(STRIKE_DELAY, function()
		if m.Parent then
			HitFx.play(if toolId == "Hands" then "punch" else "hit", pos, clumpColor(m), true, m)
		end
	end)
end

-- Was this hit already drawn by a prediction? (Then the server's chip only updates the HP bar.)
function HitFx.wasPredicted(pos: Vector3): boolean
	local now = os.clock()
	for i = #predicted, 1, -1 do
		local p = predicted[i]
		if now - p.at > 0.8 then
			table.remove(predicted, i)
		elseif Vector3.new(p.pos.X - pos.X, 0, p.pos.Z - pos.Z).Magnitude < 2 then
			table.remove(predicted, i)
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------------------------------------
-- blade swipe across the view (scissors, sickle, scythe): three claw streaks
-------------------------------------------------------------------------------------------------------------
local slashLayer = Instance.new("Frame")
slashLayer.Name = "SlashLayer"
slashLayer.BackgroundTransparency = 1
slashLayer.Size = UDim2.fromScale(1, 1)
slashLayer.ZIndex = 5
slashLayer.Parent = UI.gui
function HitFx.slash(color: Color3?)
	local image = FxIds.claw or FxIds.slash
	if not image then
		return
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = image
	img.ImageColor3 = color or Color3.new(1, 1, 1)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.55 + rand(-0.02, 0.02), 0.55 + rand(-0.02, 0.02))
	img.Size = UDim2.fromScale(0.42, 0.42)
	img.SizeConstraint = Enum.SizeConstraint.RelativeYY
	img.Rotation = rand(-55, -35)
	img.ImageTransparency = 0
	img.ZIndex = 5
	img.Parent = slashLayer
	local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(img, info, { Size = UDim2.fromScale(0.7, 0.7), Rotation = img.Rotation + 22, ImageTransparency = 1 }):Play()
	Debris:AddItem(img, 0.2)
end

return HitFx
