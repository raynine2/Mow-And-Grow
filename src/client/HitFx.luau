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
local CameraView = require(script.Parent.CameraView)

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

local function numSeq(stops: { any }?, default: number, mul: number?): NumberSequence
	local k = mul or 1
	if not stops then
		return NumberSequence.new(default * k)
	end
	local keys = {}
	for _, s in stops do
		table.insert(keys, NumberSequenceKeypoint.new(s[1], s[2] * k))
	end
	return NumberSequence.new(keys)
end

local function range(v: { number }?, default: number, mul: number?): NumberRange
	local k = mul or 1
	return if v then NumberRange.new(v[1] * k, v[2] * k) else NumberRange.new(default * k)
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

-- Where an effect is drawn: g = the ground's height under the clump (the generated world has raised terraces,
-- so heights in the presets are above the ground, not above y = 0), s = how big the clump is (the presets are
-- sized for a small tuft; the big voxel clumps get bigger bursts), r = the clump's radius (its near side), h = its
-- height (the "crown" anchor drops blades from its top).
type Ctx = { g: number, s: number, r: number, h: number, stalk: number? }

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(pos: Vector3): number
	local skip: { Instance } = { folder }
	local world = workspace:FindFirstChild("World")
	for _, name in { "Grass", "Loot" } do
		local f = world and world:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	if player.Character then
		table.insert(skip, player.Character)
	end
	if workspace.CurrentCamera then
		table.insert(skip, workspace.CurrentCamera)
	end
	groundRay.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(pos + Vector3.new(0, 2.5, 0), Vector3.new(0, -9, 0), groundRay)
	return if hit then hit.Position.Y else pos.Y
end

local function anchorFor(layer: any, pos: Vector3, out: Vector3, ctx: Ctx): CFrame
	local at: Vector3
	local g, sc = ctx.g, ctx.s
	if layer.at == "contact" then
		-- where the fist / blade lands: the clump's near side, a bit below your eyes, a little to the right
		local cam = workspace.CurrentCamera
		local eyeY = if cam then cam.CFrame.Position.Y else g + 4.5
		local right = out:Cross(Vector3.yAxis) -- your right, seen from where you stand
		-- a stalk clump is hit on its stalk's surface (you stand right at it), others on their near side
		local reach = if ctx.stalk then ctx.stalk + 0.35 else math.max(1.3, ctx.r * 0.85)
		at = Vector3.new(pos.X, math.clamp(eyeY - 1.6, g + 1.2, g + 3.2 * sc), pos.Z) + out * reach - right * 0.35
	elseif layer.at == "top" then
		at = Vector3.new(pos.X, g + (layer.height or 3.2) * sc, pos.Z)
	elseif layer.at == "crown" then
		-- up in the clump's top, a little toward you
		at = Vector3.new(pos.X, g + ctx.h * (layer.height or 0.8), pos.Z) + out * ctx.r * 0.3
	elseif layer.at == "point" then
		-- exactly at `pos` (boss effects pass a point on the boss), raised by `height`
		at = pos + Vector3.new(0, layer.height or 0, 0)
	else
		at = Vector3.new(pos.X, g + (layer.height or 0.6) * sc, pos.Z)
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
local function particles(layer: any, cf: CFrame, grass: Color3, sc: number)
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
	e.Size = numSeq(layer.size, 1, sc)
	e.Transparency = numSeq(layer.transparency, 0)
	if layer.squash then
		e.Squash = numSeq(layer.squash, 0)
	end
	e.Lifetime = range(layer.lifetime, 0.5)
	e.Speed = range(layer.speed, 0, math.sqrt(sc))
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
	e:Emit(math.round((layer.count or 1) * math.min(sc, 1.6)))
	Debris:AddItem(a, (layer.lifetime and layer.lifetime[2] or 1) + 0.3)
end

-- One image that always faces you, its size exact in studs (a BillboardGui), animated every frame: size,
-- transparency and colour over its life, and the flipbook's 16 frames (4x4 grid of a 1024 image).
local function spriteOne(layer: any, cf: CFrame, grass: Color3, sc: number)
	local off = (layer.offset or 0) * sc
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
		local size = numAt(layer.size, k, 1) * sc
		gui.Size = UDim2.fromScale(size, size)
		img.ImageTransparency = numAt(layer.transparency, k, 0)
		img.ImageColor3 = colorAt(layer.color, k, grass)
		if flip then
			local f = math.min(15, math.floor(k * 16))
			img.ImageRectOffset = Vector2.new((f % 4) * 256, (f // 4) * 256)
		end
		a.Position = start + Vector3.new(0, (layer.rise or 0) * sc * age, 0)
	end
	conn = RunService.RenderStepped:Connect(step)
	step()
end

local function sprite(layer: any, cf: CFrame, grass: Color3, sc: number)
	for i = 1, layer.count or 1 do
		local wait = (layer.delay or 0) * (i - 1)
		if wait > 0 then
			task.delay(wait, spriteOne, layer, cf, grass, sc)
		else
			spriteOne(layer, cf, grass, sc)
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

local function clippings(layer: any, cf: CFrame, out: Vector3, grass: Color3, count: number, sc: number)
	local o = layer.out or { 6, 12 }
	local u = layer.up or { 10, 16 }
	for _ = 1, count do
		if live >= MAX_LIVE then
			return
		end
		live += 1
		local body = clipBody(grass, (layer.size or 1) * math.sqrt(sc))
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

-- Chunks that fly AT you (Chop A Forest's wood chips coming at the camera): blocks of the clump's greens burst
-- out of the contact point and sail just past your face, spinning, shrinking as they go. Not physics: each one
-- follows a short arc to a point beside the camera and is gone before it could clip into the view.
local chunkLive = 0
local function chunks(layer: any, cf: CFrame, grass: Color3, count: number, sc: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local from = cf.Position
	local tones = { stopColor("grassLight", grass), grass, stopColor("grassDark", grass), stopColor("grassPale", grass) }
	local list = {}
	for _ = 1, count do
		if chunkLive >= 40 then
			break
		end
		chunkLive += 1
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = tones[math.random(1, #tones)]
		local s = rand(0.35, 0.75) * (layer.size or 1) * math.sqrt(sc)
		p.Size = Vector3.new(s, s * rand(0.6, 1), s * rand(0.7, 1.2))
		p.CFrame = CFrame.new(from) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		p.Parent = folder
		local c = cam.CFrame
		-- a point beside the camera: off to a side or above/below, a little in front of it
		local side = if math.random() < 0.5 then -1 else 1
		local to = c.Position + c.RightVector * side * rand(1.1, 2.6) + c.UpVector * rand(-1.4, 1.1) + c.LookVector * rand(0.6, 1.6)
		table.insert(list, {
			part = p,
			from = from,
			to = to,
			lift = rand(0.5, 2.2),
			time = rand(0.2, 0.36) * (layer.speed or 1),
			spin = Vector3.new(rand(-14, 14), rand(-14, 14), rand(-14, 14)),
			size = p.Size,
			rot = p.CFrame.Rotation,
		})
	end
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local age = os.clock() - born
		local alive = false
		for _, c in list do
			if not c.part.Parent then
				continue
			end
			local k = age / c.time
			if k >= 1 then
				c.part:Destroy()
				chunkLive -= 1
				continue
			end
			alive = true
			local e = 1 - (1 - k) * (1 - k) -- fast out of the clump, easing as it passes you
			local p = c.from:Lerp(c.to, e) + Vector3.new(0, math.sin(k * math.pi) * c.lift, 0)
			c.part.CFrame = CFrame.new(p) * c.rot * CFrame.Angles(c.spin.X * age, c.spin.Y * age, c.spin.Z * age)
			c.part.Size = c.size * (1 - 0.35 * k)
			c.part.Transparency = if k > 0.7 then (k - 0.7) / 0.3 else 0
		end
		if not alive then
			conn:Disconnect()
		end
	end)
end

-- Slash marks left on the clump where a blade hit it: three white streaks on its face, fading out.
local function marks(layer: any, cf: CFrame, out: Vector3, sc: number)
	local face = CFrame.lookAt(cf.Position, cf.Position + out) * CFrame.Angles(0, 0, math.rad(rand(35, 55)))
	local len = (layer.length or 2.4) * math.sqrt(sc)
	for i = -1, 1 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 255, 240)
		p.Size = Vector3.new(0.14, len * (1 - math.abs(i) * 0.18), 0.06)
		p.CFrame = face * CFrame.new(i * 0.42 * math.sqrt(sc), 0, 0.05)
		p.Transparency = 0.05
		p.Parent = folder
		TweenService:Create(p, TweenInfo.new(layer.life or 1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = Vector3.new(0.04, p.Size.Y, 0.06) }):Play()
		Debris:AddItem(p, (layer.life or 1.1) + 0.1)
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

-- A mowable clump: the generated world's voxel clumps are Models named "Clump" (with Height / Radius
-- attributes), the plots map's are the Blender tuft_<style> models (their stubble is tuft_<style>_cut).
local function isClump(m: Instance): boolean
	return m.Name == "Clump" or (m.Name:sub(1, 5) == "tuft_" and m.Name:sub(-4) ~= "_cut")
end

local function clumpOf(part: Instance): Model?
	local m = part:FindFirstAncestorOfClass("Model")
	while m and not isClump(m) do
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
	for _, part in workspace:GetPartBoundsInRadius(pos + Vector3.new(0, 1.5, 0), radius, overlap) do
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

-- How big an effect should be for this clump (1 = the small tufts the presets were made for).
local function sizeOf(m: Model?): (number, number)
	local r = m and m:GetAttribute("Radius") :: number?
	if not r then
		return 1, 1.3
	end
	return math.clamp(r / 1.6, 1, 2.2), r
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
	TweenService:Create(highlight, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 }):Play()
end

-- A clump you're chopping leans a little further away from you with every hit (like a tree about to go), and
-- wobbles about that lean when it's struck: it squashes down and bulges out on the blow, springs up tall, and
-- settles (squash and stretch, the cartoon way to show a hit). Its upright pose is remembered the first time
-- it moves; every part is placed from that pose, so the squash never drifts.
type PartPose = { part: BasePart, rel: CFrame, size: Vector3 }
type Lean = { base: CFrame, axis: Vector3, angle: number, parts: { PartPose }, squashed: boolean, simple: boolean }
local leans: { [Model]: Lean } = {}
local wobbling: { [Model]: number } = {} -- when its current wobble started
local released: { [Model]: boolean } = {}

local function leanOf(m: Model): Lean
	local l = leans[m]
	if not l then
		local base = m:GetPivot()
		local parts = {}
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(parts, { part = p, rel = base:ToObjectSpace(p.CFrame), size = p.Size })
			end
		end
		-- a clump built of loose stalks (no model) has its parts re-laid by the server on every hit: that one
		-- only leans and wobbles as a whole, no squash
		l = { base = base, axis = Vector3.xAxis, angle = 0, parts = parts, squashed = false, simple = not isClump(m) }
		leans[m] = l
		m.Destroying:Connect(function()
			leans[m] = nil
			wobbling[m] = nil
			released[m] = nil
		end)
	end
	return l
end

-- Put `m` in its lean, tipped a further `extra` radians about `axis`, squashed by `sq` (0 = none; > 0 shorter
-- and wider, < 0 taller and thinner; the volume stays about the same).
local function pose(m: Model, l: Lean, extra: number, axis: Vector3, sq: number?)
	local cf = CFrame.new(l.base.Position) * CFrame.fromAxisAngle(l.axis, l.angle)
	if extra ~= 0 then
		cf = CFrame.fromAxisAngle(axis, extra) * cf.Rotation + cf.Position
	end
	cf *= l.base.Rotation
	if l.simple then
		m:PivotTo(cf)
		return
	end
	local q = sq or 0
	local sy, sx = 1 - q, 1 + q * 0.55
	local resize = q ~= 0 or l.squashed
	for _, e in l.parts do
		if e.part.Parent then
			local r = e.rel.Position
			e.part.CFrame = cf * CFrame.new(r.X * sx, r.Y * sy, r.Z * sx) * e.rel.Rotation
			if resize then
				e.part.Size = Vector3.new(e.size.X * sx, e.size.Y * sy, e.size.Z * sx)
			end
		end
	end
	l.squashed = q ~= 0
	m.WorldPivot = cf
end

-- Lean `m` away from `from` by how much of it is cut (1 - ratio of its HP left).
function HitFx.lean(m: Model?, from: Vector3?, ratio: number?)
	if not m or not m.Parent or released[m] or not from or not ratio then
		return
	end
	local l = leanOf(m)
	local away = Vector3.new(l.base.Position.X - from.X, 0, l.base.Position.Z - from.Z)
	if away.Magnitude > 0.05 then
		local axis = Vector3.yAxis:Cross(away.Unit)
		l.axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	end
	l.angle = math.rad(11) * math.clamp(1 - ratio, 0, 1)
	if not wobbling[m] then
		pose(m, l, 0, l.axis)
	end
end

-- Stop moving `m` (it's falling over: client/Fx animates it from here). Puts it back to its full size and
-- returns its upright pose.
function HitFx.release(m: Model): CFrame?
	released[m] = true
	local l = leans[m]
	if l and l.squashed then
		pose(m, l, 0, l.axis, 0)
	end
	return if l then l.base else nil
end

local function wobble(m: Model, away: Vector3, strength: number)
	if released[m] then
		return
	end
	local l = leanOf(m)
	local axis = Vector3.yAxis:Cross(away)
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	local start = os.clock()
	local running = wobbling[m] ~= nil
	wobbling[m] = start -- a new hit restarts the wobble from the top
	if running then
		return
	end
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - (wobbling[m] or start)
		if t > 0.6 or not m.Parent or released[m] then
			conn:Disconnect()
			wobbling[m] = nil
			if m.Parent and not released[m] then
				pose(m, l, 0, axis, 0)
			end
			return
		end
		-- a damped spring about its lean: snaps away, swings back past it, settles
		local angle = math.rad(14 * strength) * math.exp(-t * 8) * math.cos(t * 24)
		-- squash on the blow, spring up tall, settle (a quicker spring than the sway)
		local sq = 0.2 * strength * math.exp(-t * 9) * math.cos(t * 32)
		pose(m, l, angle, axis, sq)
	end)
end

-- The cut "pop": a copy of the clump flashes white, swells a little and shrinks away, so it bursts instead of
-- just disappearing (the server has already swapped it for stubble). `src` is the fallen clump itself (its
-- copy pops where it lies); without it, the zone's Blender tuft model pops upright at `pos`.
local function pop(spec: any, pos: Vector3, style: string?, src: Model?, g: number)
	local m: Model
	if src then
		m = src:Clone()
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0
			end
		end
		local box = m:GetBoundingBox()
		m.WorldPivot = box -- swell and shrink about its middle
	else
		local models = ReplicatedStorage:FindFirstChild("MowALawnModels")
		local template = style and models and models:FindFirstChild("tuft_" .. style)
		if not (template and template:IsA("Model")) then
			return
		end
		m = template:Clone()
		m:PivotTo(CFrame.new(pos.X, g + 0.02, pos.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		elseif p:IsA("Highlight") then
			p:Destroy()
		end
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 1 - (spec.white or 0.7)
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = m
	m.Parent = folder
	local grow, t1, t2 = spec.grow or 1.15, spec.growTime or 0.05, spec.shrinkTime or 0.13
	local base = m:GetScale() -- a placed clump may already be scaled up
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
		m:ScaleTo(base * math.max(0.02, s))
	end)
end

-------------------------------------------------------------------------------------------------------------
-- camera kick and hit-stop
-------------------------------------------------------------------------------------------------------------
local function kick(amount: number)
	if amount > 0 then
		CameraView.kick(amount) -- CameraView owns the field of view
	end
end

-------------------------------------------------------------------------------------------------------------
-- play an event
-------------------------------------------------------------------------------------------------------------
-- Your hits on one clump climb in pitch (snap, snap, SNAP), so chopping builds up to the cut.
local streak = { clump = nil :: Model?, n = 0, at = 0 }
local function streakPitch(m: Model?): number
	local now = os.clock()
	if m and m == streak.clump and now - streak.at < 1.2 then
		streak.n = math.min(streak.n + 1, 8)
	else
		streak.n = 0
	end
	streak.clump, streak.at = m, now
	return 1 + streak.n * 0.045
end

local function hitSounds(event: string, m: Model?)
	local up = streakPitch(m)
	local chip = Config.SOUNDS.chip
	if event == "punch" then
		Sound.play("punch", 0.12) -- the meaty thud of the fist
		Sound.play("rustle", 0.15) -- the grass crunching
	elseif event == "hit" then
		Sound.play("slice", 0.1) -- the blade going through
		Sound.play("rustle", 0.15)
	elseif event == "auto" then
		Sound.play("rustle", 0.2, 0.45)
	end
	if chip then
		Sound.playAt("chip", (chip.pitch or 1) * up * (0.95 + math.random() * 0.1), if event == "auto" then 0.5 else 1)
	end
end

-- event: punch / hit / auto / cut / reveal, or a boss event (client/BossFx). pos: the clump's foot. grass: its
-- colour (or the mutation's / the boss's). opts.scale: the clump's size (else read off `clump`); opts.pop: the
-- fallen clump, so the cut pops that model where it lies.
function HitFx.play(event: string, pos: Vector3, grass: Color3, mine: boolean, clump: Model?, style: string?, opts: { scale: number?, pop: Model? }?)
	local preset = Presets[event]
	if not preset then
		return
	end
	local m = clump
	if mine and not m and (event == "punch" or event == "hit" or event == "auto") then
		m = clumpAt(pos, 2.5)
	end
	local sc, r = sizeOf(m)
	if opts and opts.scale then
		sc = math.clamp(opts.scale, 1, 2.2)
		r = sc * 1.6
	end
	local g = groundAt(pos)
	local hgt = (m and m:GetAttribute("Height") :: number?) or 6 * sc
	local ctx: Ctx = { g = g, s = sc, r = r, h = hgt, stalk = m and m:GetAttribute("Stalk") :: number? }
	if preset.pop then
		pop(preset.pop, pos, style, opts and opts.pop, g)
	end
	local out = outFrom(pos)
	for _, layer in preset.layers do
		if layer.mineOnly and not mine then
			continue
		end
		local cf = anchorFor(layer, pos, out, ctx)
		if layer.kind == "particles" then
			particles(layer, cf, grass, sc)
		elseif layer.kind == "sprite" then
			sprite(layer, cf, grass, sc)
		elseif layer.kind == "clippings" then
			local n = if mine then (layer.mineCount or layer.count) else (layer.otherCount or math.ceil(layer.count / 2))
			clippings(layer, cf, out, grass, n, sc)
		elseif layer.kind == "chunks" then
			if mine then
				chunks(layer, cf, grass, layer.count or 5, sc)
			end
		elseif layer.kind == "marks" then
			if mine then
				marks(layer, cf, out, sc)
			end
		end
	end
	if mine then
		if m then
			if (preset.flash or 0) > 0 then
				flashClump(m, preset.flash)
			end
			if (preset.wobble or 0) > 0 then
				wobble(m, -out, preset.wobble)
			end
		end
		if event == "punch" or event == "hit" or event == "auto" then
			hitSounds(event, m)
		end
		kick(preset.kick or 0)
		if event == "punch" or event == "hit" then
			CameraView.shake(0.5, 0.09) -- a small jolt through the view on contact
		end
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
-- The clump the server will pick for a swing aimed along `look` (same rule as server/Field hitAim): the one
-- nearest the middle of your view, within reach.
local function aimedClump(rootPos: Vector3, look: Vector3, reach: number): Model?
	local grass = grassFolder()
	if not grass then
		return nil
	end
	overlap.FilterDescendantsInstances = { grass }
	local eye = rootPos + Vector3.new(0, 1.5, 0)
	local seen: { [Model]: boolean } = {}
	local best, bestScore = nil, math.huge
	for _, part in workspace:GetPartBoundsInRadius(rootPos, reach + 12, overlap) do
		local m = clumpOf(part)
		if m and not seen[m] and not released[m] then
			seen[m] = true
			local foot = (leans[m] and leans[m].base or m:GetPivot()).Position
			local radius = m:GetAttribute("Radius") :: number? or 3
			local height = m:GetAttribute("Height") :: number? or 6
			local flat = Vector3.new(foot.X - rootPos.X, 0, foot.Z - rootPos.Z).Magnitude
			if flat - radius <= reach then
				local to = foot + Vector3.new(0, math.min(height * 0.4, 5), 0) - eye
				local d = math.max(to.Magnitude, 0.1)
				local angle = math.acos(math.clamp(to:Dot(look) / d, -1, 1))
				local score = angle - math.atan2(math.max(radius, height * 0.35), d)
				if score < bestScore then
					best, bestScore = m, score
				end
			end
		end
	end
	return if bestScore <= math.rad(14) then best else nil
end

function HitFx.swing(toolId: string?, look: Vector3?)
	local def = nil
	for _, t in Config.TOOLS do
		if t.id == toolId then
			def = t
		end
	end
	local root = myRoot()
	local d = State.data
	-- no swing effect when the bag is full (bundles still on the ground count too)
	if not def or def.kind ~= "swing" or not root or not d or not d.run or (not d.endless and d.run.carry + (d.run.ground or 0) >= (d.carryMax or 1)) then
		return
	end
	local m = aimedClump(root.Position, look or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector) or root.CFrame.LookVector, def.radius)
	if not m then
		return
	end
	local pos = (leans[m] and leans[m].base or m:GetPivot()).Position
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
	-- a big streak across the whole view along the swing (top right to bottom left), and a fainter echo
	local angle = rand(-46, -34)
	for i, alpha in { 0, 0.45 } do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = image
		img.ImageColor3 = color or Color3.new(1, 1, 1)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.56 + (i - 1) * 0.03, 0.5 + (i - 1) * 0.03)
		img.Size = UDim2.fromScale(0.95, 0.95)
		img.SizeConstraint = Enum.SizeConstraint.RelativeYY
		img.Rotation = angle
		img.ImageTransparency = alpha
		img.ZIndex = 5
		img.Parent = slashLayer
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(img, info, { Size = UDim2.fromScale(1.35, 1.35), Position = img.Position + UDim2.fromScale(-0.05, 0.06), ImageTransparency = 1 }):Play()
		Debris:AddItem(img, 0.22)
	end
end

return HitFx
