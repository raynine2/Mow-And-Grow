-- Hit effects, built like the Chop A Forest trailer's chops. Every hit layers:
--   a warm glow + a star flare at the contact point (and a comic shock star for bare-hand punches),
--   jagged splinters shooting out along their flight path, green blade bits spinning away,
--   chunky 3D clippings that tumble and bounce on the ground, a soft dust puff and a few sparkles,
--   a wobble on the clump you hit and a small camera kick.
-- Textures are drawn by tools/fx/make_textures.py and uploaded (shared/FxIds); built-in engine particles are the
-- fallback until they are. Everything here is local to this client.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local UI = require(script.Parent.UI)

local HitFx = {}
local player = Players.LocalPlayer

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX = {
	glow = FxIds.glow or SPARKLE,
	flare = FxIds.flare or SPARKLE,
	burst = FxIds.burst or SPARKLE,
	splinter = FxIds.splinter or SPARKLE,
	blade = FxIds.blade or SPARKLE,
	smoke = FxIds.smoke or SMOKE,
	ring = FxIds.ring or SPARKLE,
	slash = FxIds.slash,
	spark = FxIds.spark or SPARKLE,
}

local folder = Instance.new("Folder")
folder.Name = "HitFx"
folder.Parent = workspace

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function seq(...: number): NumberSequence
	local v = { ... }
	local keys = {}
	for i = 1, #v, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(v[i], v[i + 1]))
	end
	return NumberSequence.new(keys)
end

-------------------------------------------------------------------------------------------------------------
-- particle bursts: a throwaway emitter on an attachment at the spot, emitted once
-------------------------------------------------------------------------------------------------------------
-- `cf` places the attachment; particles fly along its +Y (EmissionDirection Top) inside SpreadAngle.
local function emit(cf: CFrame, count: number, props: { [string]: any })
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.CFrame = cf
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.EmissionDirection = Enum.NormalId.Top
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = a
	e:Emit(count)
	local life = (props.Lifetime :: NumberRange?) or NumberRange.new(1)
	Debris:AddItem(a, life.Max + 0.3)
end

-- The flash where the blow lands: a soft warm glow and a quick star flare on top.
local function flash(pos: Vector3, scale: number)
	local cf = CFrame.new(pos)
	emit(cf, 1, {
		Texture = TEX.glow,
		Color = ColorSequence.new(Color3.fromRGB(255, 246, 214)),
		LightEmission = 1,
		Brightness = 2,
		Size = seq(0, 1.2 * scale, 0.35, 4.2 * scale, 1, 5 * scale),
		Transparency = seq(0, 0.05, 0.5, 0.45, 1, 1),
		Lifetime = NumberRange.new(0.16),
		Speed = NumberRange.new(0),
		ZOffset = 2,
	})
	emit(cf, 1, {
		Texture = TEX.flare,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 1,
		Brightness = 3,
		Size = seq(0, 2 * scale, 1, 5.5 * scale),
		Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.1),
		Rotation = NumberRange.new(-25, 25),
		Speed = NumberRange.new(0),
		ZOffset = 3,
	})
	-- a short real light so the grass around glows for a moment
	local holder = Instance.new("Attachment")
	holder.Parent = workspace.Terrain
	holder.Position = pos
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 236, 190)
	light.Range = 10 * scale
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.18), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 0.25)
end

-- The comic shock star for bare-hand punches.
local function punchStar(pos: Vector3)
	emit(CFrame.new(pos), 1, {
		Texture = TEX.burst,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 226, 150)),
		LightEmission = 0.6,
		Size = seq(0, 0.6, 0.4, 3.2, 1, 3.8),
		Transparency = seq(0, 0, 0.6, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.15),
		Rotation = NumberRange.new(0, 360),
		Speed = NumberRange.new(0),
		ZOffset = 2.5,
	})
end

-- Jagged splinters shooting out of the hit, stretched along their flight (the trailer's yellow shards).
local function splinters(cf: CFrame, color: Color3, count: number, power: number)
	emit(cf, count, {
		Texture = TEX.splinter,
		Color = ColorSequence.new(UI.shade(color, 1.45), UI.shade(color, 1.1)),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		LightEmission = 0.25,
		Size = seq(0, 0.35, 0.15, 1.1 * power, 1, 0.2),
		Transparency = seq(0, 0, 0.7, 0, 1, 1),
		Lifetime = NumberRange.new(0.22, 0.36),
		Speed = NumberRange.new(20 * power, 34 * power),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 5,
		Acceleration = Vector3.new(0, -20, 0),
		ZOffset = 1,
	})
end

-- Flat green blade bits that spin away and fall (cheap, so there can be many).
local function blades(cf: CFrame, color: Color3, count: number, power: number)
	emit(cf, count, {
		Texture = TEX.blade,
		Color = ColorSequence.new(UI.shade(color, 1.25), UI.shade(color, 0.85)),
		LightInfluence = 0.6,
		Size = seq(0, 0.55 * power, 0.8, 0.5 * power, 1, 0),
		Transparency = seq(0, 0, 0.75, 0, 1, 1),
		Lifetime = NumberRange.new(0.6, 1.0),
		Speed = NumberRange.new(9 * power, 17 * power),
		SpreadAngle = Vector2.new(85, 85),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-500, 500),
		Drag = 1.6,
		Acceleration = Vector3.new(0, -42, 0),
	})
end

-- A soft puff of grass dust.
local function dust(pos: Vector3, color: Color3, scale: number)
	emit(CFrame.new(pos), math.floor(3 * scale + 0.5), {
		Texture = TEX.smoke,
		Color = ColorSequence.new(UI.shade(color, 1.6):Lerp(Color3.new(1, 0.97, 0.88), 0.55)),
		LightInfluence = 0.4,
		Size = seq(0, 1 * scale, 1, 3.6 * scale),
		Transparency = seq(0, 0.45, 0.4, 0.6, 1, 1),
		Lifetime = NumberRange.new(0.45, 0.75),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Drag = 4,
		Acceleration = Vector3.new(0, 1.5, 0),
	})
end

local function sparkles(pos: Vector3, color: Color3, count: number)
	emit(CFrame.new(pos), count, {
		Texture = TEX.spark,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Brightness = 2,
		Size = seq(0, 0.5, 1, 0),
		Lifetime = NumberRange.new(0.3, 0.55),
		Speed = NumberRange.new(7, 14),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Acceleration = Vector3.new(0, -8, 0),
		Rotation = NumberRange.new(0, 90),
		ZOffset = 1.5,
	})
end

-- A shock ring lying flat on the ground (big cuts).
local function groundRing(pos: Vector3, color: Color3, radius: number)
	emit(CFrame.new(pos.X, 0.15, pos.Z), 1, {
		Texture = TEX.ring,
		Color = ColorSequence.new(color),
		LightEmission = 0.8,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = seq(0, 0.5, 1, radius),
		Transparency = seq(0, 0.1, 1, 1),
		Lifetime = NumberRange.new(0.35),
		Speed = NumberRange.new(0.01),
	})
end

-------------------------------------------------------------------------------------------------------------
-- chunky 3D clippings: real little parts, simulated on this client, that tumble and bounce
-------------------------------------------------------------------------------------------------------------
local live = 0
local MAX_LIVE = 70
local CLIP_PHYS = PhysicalProperties.new(0.4, 0.7, 0.35)

local function clippings(pos: Vector3, out: Vector3, color: Color3, count: number, power: number)
	for _ = 1, count do
		if live >= MAX_LIVE then
			return
		end
		live += 1
		local p = Instance.new(if math.random() < 0.5 then "WedgePart" else "Part")
		p.Size = Vector3.new(rand(0.3, 0.55), rand(0.12, 0.2), rand(0.6, 1.1)) * math.sqrt(power)
		-- mostly blade green, some with the pale fresh-cut colour
		p.Color = if math.random() < 0.3 then UI.shade(color, 1.55):Lerp(Color3.fromRGB(240, 245, 200), 0.4) else UI.shade(color, rand(0.85, 1.2))
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanQuery = false
		p.CanTouch = false
		p.CustomPhysicalProperties = CLIP_PHYS
		p.CFrame = CFrame.new(pos + Vector3.new(rand(-0.4, 0.4), rand(-0.3, 0.3), rand(-0.4, 0.4))) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		p.Parent = folder
		local side = Vector3.new(rand(-1, 1), 0, rand(-1, 1)) * 6
		p.AssemblyLinearVelocity = (out * rand(7, 14) + side + Vector3.new(0, rand(11, 19), 0)) * power
		p.AssemblyAngularVelocity = Vector3.new(rand(-25, 25), rand(-25, 25), rand(-25, 25))
		local stay = rand(1.1, 1.7)
		task.delay(stay, function()
			if p.Parent then
				p.Anchored = true
				TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = p.Size * 0.05 }):Play()
			end
		end)
		task.delay(stay + 0.4, function()
			live -= 1
			p:Destroy()
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the clump you hit wobbles away from you and springs back
-------------------------------------------------------------------------------------------------------------
local wobbling: { [Model]: boolean } = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function clumpAt(pos: Vector3): Model?
	local world = workspace:FindFirstChild("World")
	local grass = world and world:FindFirstChild("Grass")
	if not grass then
		return nil
	end
	overlap.FilterDescendantsInstances = { grass }
	for _, part in workspace:GetPartBoundsInRadius(Vector3.new(pos.X, 1, pos.Z), 2, overlap) do
		local m = part:FindFirstAncestorOfClass("Model")
		while m and not (m.Name:sub(1, 5) == "tuft_" and m.Name:sub(-4) ~= "_cut") do
			m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
		end
		if m then
			return m
		end
	end
	return nil
end

local function wobble(pos: Vector3, away: Vector3, strength: number)
	local m = clumpAt(pos)
	if not m or wobbling[m] then
		return
	end
	wobbling[m] = true
	local base = m:GetPivot()
	local axis = away:Cross(Vector3.yAxis)
	if axis.Magnitude < 1e-3 then
		axis = Vector3.xAxis
	end
	axis = -axis.Unit
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > 0.5 or not m.Parent then
			conn:Disconnect()
			wobbling[m] = nil
			if m.Parent then
				m:PivotTo(base)
			end
			return
		end
		-- a damped spring: tips away fast, swings back past upright, settles
		local angle = math.rad(13 * strength) * math.exp(-t * 9) * math.cos(t * 26)
		m:PivotTo(CFrame.new(base.Position) * CFrame.fromAxisAngle(axis, angle) * base.Rotation)
	end)
end

-------------------------------------------------------------------------------------------------------------
-- camera kick: the view jolts a hair on every hit
-------------------------------------------------------------------------------------------------------------
local kickUntil = 0
local function kick(amount: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if os.clock() < kickUntil then
		return
	end
	kickUntil = os.clock() + 0.12
	local base = 70
	cam.FieldOfView = base - amount
	TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
end

-------------------------------------------------------------------------------------------------------------
-- public
-------------------------------------------------------------------------------------------------------------
local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where on the clump the blow lands: its near side, about chest height.
local function contact(pos: Vector3): (Vector3, Vector3)
	local root = myRoot()
	local toMe = if root then Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z) else Vector3.zAxis
	local out = if toMe.Magnitude > 0.1 then toMe.Unit else Vector3.zAxis
	return Vector3.new(pos.X, 1.9, pos.Z) + out * 1.3, out
end

-- One hit on a patch (the patch is still standing). `punch`: bare hands.
function HitFx.hit(pos: Vector3, color: Color3, punch: boolean)
	local at, out = contact(pos)
	-- particles fly out of the near side, toward you and to the sides
	local spray = CFrame.lookAt(at, at + out) * CFrame.Angles(-math.rad(90) + math.rad(20), 0, 0)
	flash(at, if punch then 0.8 else 1)
	if punch then
		punchStar(at)
	end
	splinters(spray, color, if punch then 6 else 8, 1)
	blades(spray, color, 7, 1)
	clippings(at, out, color, if punch then 3 else 4, 1)
	dust(at, color, 1)
	sparkles(at, Color3.fromRGB(255, 244, 200), 4)
	wobble(pos, -out, 1)
	kick(if punch then 1.6 else 1.2)
end

-- The last hit: the clump comes apart.
function HitFx.cut(pos: Vector3, color: Color3, mine: boolean, glowColor: Color3?)
	local at, out = contact(pos)
	local spray = CFrame.lookAt(at, at + out) * CFrame.Angles(-math.rad(90) + math.rad(35), 0, 0)
	local up = CFrame.new(Vector3.new(pos.X, 1.2, pos.Z))
	if mine then
		flash(at, 1.3)
		kick(2.2)
	end
	splinters(up, color, 12, 1.15)
	blades(up, color, 16, 1.2)
	blades(spray, color, 6, 1)
	clippings(Vector3.new(pos.X, 1.5, pos.Z), out, color, if mine then 9 else 5, 1.1)
	dust(Vector3.new(pos.X, 1, pos.Z), color, 1.6)
	groundRing(pos, UI.shade(color, 1.5), 9)
	sparkles(Vector3.new(pos.X, 2, pos.Z), glowColor or Color3.fromRGB(255, 244, 200), if glowColor then 18 else 8)
end

-- A hidden mutation shows itself: a coloured flash, a burst of sparkles and a ring.
function HitFx.reveal(pos: Vector3, color: Color3)
	local at = Vector3.new(pos.X, 2.2, pos.Z)
	emit(CFrame.new(at), 1, {
		Texture = TEX.glow,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Brightness = 3,
		Size = seq(0, 2, 0.3, 7, 1, 8),
		Transparency = seq(0, 0, 0.6, 0.5, 1, 1),
		Lifetime = NumberRange.new(0.35),
		Speed = NumberRange.new(0),
		ZOffset = 2,
	})
	sparkles(at, color, 26)
	sparkles(at, Color3.new(1, 1, 1), 10)
	groundRing(pos, color, 14)
end

-- A crescent swipe across the view for blade tools (scissors, sickle, scythe).
local slashGui = Instance.new("Frame")
slashGui.Name = "SlashLayer"
slashGui.BackgroundTransparency = 1
slashGui.Size = UDim2.fromScale(1, 1)
slashGui.ZIndex = 5
slashGui.Parent = UI.gui
function HitFx.slash(color: Color3?)
	if not TEX.slash then
		return
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = TEX.slash
	img.ImageColor3 = color or Color3.new(1, 1, 1)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.56 + rand(-0.03, 0.03), 0.52 + rand(-0.03, 0.03))
	img.Size = UDim2.fromScale(0.34, 0.34)
	img.SizeConstraint = Enum.SizeConstraint.RelativeYY
	img.Rotation = rand(-60, -30)
	img.ImageTransparency = 0.05
	img.ZIndex = 5
	img.Parent = slashGui
	local info = TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(img, info, { Size = UDim2.fromScale(0.62, 0.62), Rotation = img.Rotation + 28, ImageTransparency = 1 }):Play()
	Debris:AddItem(img, 0.2)
end

return HitFx
