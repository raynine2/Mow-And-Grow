-- The supply crate that ends the run's opening cutscene (client/IntroCast.crate hands the drop to this module).
-- Owner, 27 Oct: "change the model of the box the Mayor drops, make it look cool with vfx and higher quality while
-- matching the game's style, make it with ForgeGUI; use VFX Forge for the vfx".
--   * The crate and its lid are ForgeGUI models (ReplicatedStorage.IntroProps.CrateBody / CrateLid; Roblox assets
--     128223254178409 and 83914580740447 on the owner's account): a chunky wooden crate with green metal corners
--     and a gold star, full of coins, grass clippings and gems, and its matching lid.
--   * The effects are VFX Forge effects (ReplicatedStorage.VFXLib.Forge -> ForgeEmit) wherever Forge has the effect
--     type: mesh effects for the ground rings and the shadow, Forge shockwave rings for the turf chunks, Forge
--     shockwave debris for the coins (real physics), Forge mesh effects (neon cylinders) for the light pillar, and
--     Forge particle bursts.
--     The crate's own motion (fall, squash, rattle, lid flight) is moved by hand. Without Forge the same layers
--     play by hand.
-- Timeline:
--   fall (0.55 s)  a gold ring closes in on the landing spot and a soft shadow grows under the crate; the crate
--                  streaks down, trailing gold sparkles and turning to show its star
--   impact         white impact frame, squash and stretch, a flash, two shockwave rings, turf chunks popping out of
--                  the ground round it (they take the ground's own colour), a toon dust ring and flying grass
--   rattle (0.3 s) the crate shudders, the lid lifts a little and gold light leaks from under it
--   pop            the lid flies off spinning, a light pillar and two starbursts, coins and sparkles fountain out,
--                  grass clippings drift down, a warm light washes over the party
--   idle           the open crate glows: rising motes, coins twinkling, a breathing light (until IntroCast clears
--                  the set, which destroys everything here)
-- Phones: every count and rate goes through VFXLib.Budget.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sound = require(script.Parent:WaitForChild("Sound"))

local VFXLib = ReplicatedStorage:FindFirstChild("VFXLib")
local okAssets, Assets = pcall(function()
	return require((VFXLib :: Instance):WaitForChild("Assets", 5) :: ModuleScript)
end)
local okForge, Forge = pcall(function()
	return require((VFXLib :: Instance):WaitForChild("Forge", 5) :: ModuleScript)
end)
local okBudget, Budget = pcall(function()
	return require((VFXLib :: Instance):WaitForChild("Budget", 5) :: ModuleScript)
end)
local okFx, FxIds = pcall(function()
	return require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxIds", 5) :: ModuleScript)
end)

local TEX: { [string]: string } = if okAssets and type(Assets) == "table" then Assets.Tex else {}
local FX: { [string]: string } = if okFx and type(FxIds) == "table" then FxIds else {}
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local GOLD = Color3.fromRGB(255, 200, 45)
local GOLD_LIGHT = Color3.fromRGB(255, 232, 140)
local WARM = Color3.fromRGB(255, 247, 225)
local GRASS = Color3.fromRGB(110, 215, 70)
local DUST = Color3.fromRGB(222, 200, 160)

local FALL = 0.55 -- seconds from the sky to the ground
local DROP = 70 -- studs it falls

local IntroCrate = {}

-------------------------------------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------------------------------------
local function count(n: number): number
	if okBudget and type(Budget) == "table" then
		return Budget.Count(n)
	end
	return n
end

local function rate(n: number): number
	if okBudget and type(Budget) == "table" then
		return Budget.Rate(n)
	end
	return n
end

local function seq(...: number): NumberSequence
	local a = { ... }
	local kp = {}
	for i = 1, #a, 2 do
		table.insert(kp, NumberSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return NumberSequence.new(kp)
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, repeats: number?, reverse: boolean?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, repeats or 0, reverse or false), props)
	t:Play()
	return t
end

-- An invisible anchored part that holds attachments, emitters and lights.
local function holderPart(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- A one-shot burst the way VFX Forge reads one: EmitCount (and EmitDelay) attributes on the emitter.
local function burst(parent: Instance, n: number, delay: number, props: { [string]: any }): ParticleEmitter
	local e = emitter(parent, props)
	e:SetAttribute("EmitCount", count(n))
	if delay > 0 then
		e:SetAttribute("EmitDelay", delay)
	end
	return e
end

local function forgeEmit(root: Instance): boolean
	return okForge and type(Forge) == "table" and Forge.Emit ~= nil and Forge.Emit(root)
end

-- Play every burst under `root` with VFX Forge; by hand when Forge isn't there.
local function play(root: Instance)
	if forgeEmit(root) then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local n = d:GetAttribute("EmitCount") or 1
			task.delay(d:GetAttribute("EmitDelay") or 0, function()
				if d.Parent then
					d:Emit(n)
				end
			end)
		elseif d:IsA("Beam") then
			local life = d:GetAttribute("EffectDuration")
			d.Width0 = d:GetAttribute("Width0_End") or d.Width0
			d.Width1 = d:GetAttribute("Width1_End") or d.Width1
			d.Enabled = true
			task.delay(if typeof(life) == "NumberRange" then life.Max else 1, function()
				if d.Parent then
					d.Enabled = false
				end
			end)
		end
	end
end

-- A flat decal on the ground that grows or shrinks and fades: a VFX Forge mesh effect (a Model with Start and End
-- parts; Forge tweens the size and the decal's fade from one to the other). The template sits outside the
-- workspace and Forge plays a copy of it.
local function groundDecal(holder: Instance, at: CFrame, texture: string, color: Color3, from: number, to: number, duration: number, t0: number, t1: number, delay: number?)
	local fx = Instance.new("Model")
	fx.Name = "CrateGroundFx"
	fx:SetAttribute("EffectDuration", NumberRange.new(duration, duration))
	fx:SetAttribute("Decal_StartTransparency", t0)
	fx:SetAttribute("Decal_EndTransparency", t1)
	if delay and delay > 0 then
		fx:SetAttribute("EmitDelay", delay)
	end
	local function plane(name: string, size: number): Part
		local p = holderPart(fx, name, Vector3.new(size, 0.05, size), at)
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = texture
		d.Color3 = color
		d.Parent = p
		return p
	end
	local start = plane("Start", from)
	plane("End", to)
	fx.Parent = ReplicatedStorage
	if not forgeEmit(fx) then
		task.delay(delay or 0, function()
			local p = start:Clone()
			p.Parent = holder
			local d = p:FindFirstChildOfClass("Decal") :: Decal
			d.Transparency = t0
			tween(p, duration, { Size = Vector3.new(to, 0.05, to) })
			tween(d, duration, { Transparency = t1 }, Enum.EasingStyle.Linear)
			Debris:AddItem(p, duration + 0.1)
		end)
	end
	task.delay((delay or 0) + duration + 0.6, function()
		fx:Destroy()
	end)
end

-- A neon part that grows, moves and fades from Start to End: a VFX Forge mesh effect without a decal (Forge fades
-- the part itself). Used for the light pillar (neon keeps its colour in full sunlight, where additive glow washes
-- out over the sunlit paving).
local function partFx(holder: Instance, startCf: CFrame, endCf: CFrame, from: Vector3, to: Vector3, color: Color3, duration: number, t0: number, t1: number)
	local fx = Instance.new("Model")
	fx.Name = "CratePillar"
	fx:SetAttribute("EffectDuration", NumberRange.new(duration, duration))
	fx:SetAttribute("Part_Transparency_Start", t0)
	fx:SetAttribute("Part_Transparency_End", t1)
	local function piece(name: string, size: Vector3, cf: CFrame): Part
		local p = holderPart(fx, name, size, cf)
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = t0
		return p
	end
	local start = piece("Start", from, startCf)
	piece("End", to, endCf)
	fx.Parent = ReplicatedStorage
	if not forgeEmit(fx) then
		local p = start:Clone()
		p.Parent = holder
		tween(p, duration, { Size = to, CFrame = endCf, Transparency = t1 })
		Debris:AddItem(p, duration + 0.1)
	end
	task.delay(duration + 0.6, function()
		fx:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the layers
-------------------------------------------------------------------------------------------------------------
-- fall: the target ring closing in and the shadow growing, both landing with the crate
local function telegraph(holder: Instance, ground: Vector3)
	local at = CFrame.new(ground + Vector3.new(0, 0.04, 0))
	groundDecal(holder, at, TEX.RingThin or TEX.VS_Ring or SPARKLE, GOLD, 12, 4.6, FALL, 1, 0)
	groundDecal(holder, at * CFrame.new(0, -0.01, 0), TEX.Glow or SPARKLE, Color3.new(0, 0, 0), 2, 7, FALL, 1, 0.12)
end

-- the crate's own fall streak: a gold trail and sparkles that stop when it lands
local function fallStreak(body: BasePart): () -> ()
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-body.Size.X * 0.42, body.Size.Y * 0.35, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(body.Size.X * 0.42, body.Size.Y * 0.35, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(GOLD_LIGHT, GOLD)
	trail.Transparency = seq(0, 0.35, 1, 1)
	trail.WidthScale = seq(0, 1, 1, 0.3)
	trail.Lifetime = 0.2
	trail.LightEmission = 0.5
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = body
	local sparks = emitter(a0.Parent :: Instance, {
		Texture = TEX.Star4 or SPARKLE,
		Color = ColorSequence.new(WARM, GOLD),
		LightEmission = 0.6,
		Size = seq(0, 0.7, 1, 0),
		Transparency = seq(0, 0, 0.8, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = rate(45),
	})
	sparks.Enabled = true
	return function()
		trail.Enabled = false
		sparks.Enabled = false
	end
end

-- impact: flash, two shockwave rings, turf chunks, a toon dust ring and flying grass
local function impact(holder: Instance, ground: Vector3, size: Vector3)
	local at = CFrame.new(ground + Vector3.new(0, 0.06, 0))
	groundDecal(holder, at, TEX.RingShock or TEX.VS_Ring or SPARKLE, WARM, 3, 26, 0.45, 0, 1)
	groundDecal(holder, at * CFrame.new(0, 0.01, 0), TEX.RingThin or TEX.VS_Ring or SPARKLE, GOLD, 2, 17, 0.7, 0.1, 1, 0.06)
	-- turf chunks: a Forge shockwave ring of rocks that take the ground's colour and material, pop up and sink
	if okForge and type(Forge) == "table" and Forge.Ring then
		local ring = Forge.Ring(ground, {
			Radius = size.X * 0.5 + 2.6,
			Segments = 9,
			MinSize = Vector3.new(1, 0.6, 1.1),
			MaxSize = Vector3.new(1.7, 1.15, 1.8),
			Duration = 0.9,
		})
		if ring then
			Debris:AddItem(ring, 5)
		end
	end
	-- the flash and the grass, from the middle
	local mid = holderPart(holder, "ImpactBurst", Vector3.one * 0.2, CFrame.new(ground + Vector3.new(0, 1, 0)))
	local att = Instance.new("Attachment")
	att.Parent = mid
	burst(att, 1, 0, {
		Texture = TEX.Glow or SPARKLE,
		Color = ColorSequence.new(WARM),
		LightEmission = 0.7,
		Size = seq(0, 3, 0.3, 13, 1, 15),
		Transparency = seq(0, 0.15, 1, 1),
		Lifetime = NumberRange.new(0.22),
		Speed = NumberRange.new(0),
		ZOffset = 2,
	})
	burst(att, 16, 0, {
		Texture = FX.splinter or SPARKLE,
		Color = ColorSequence.new(GRASS, Color3.fromRGB(80, 185, 55)),
		LightInfluence = 0.6,
		Size = seq(0, 0.45, 1, 0.3),
		Transparency = seq(0, 0, 0.8, 0, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(16, 26),
		SpreadAngle = Vector2.new(65, 65),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -55, 0),
		Drag = 1,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
	})
	-- the dust: a flat ring of toon smoke rolling outward along the ground
	local ringPart = holderPart(holder, "DustRing", Vector3.new(size.X + 0.6, 0.2, size.Z + 0.6), CFrame.new(ground + Vector3.new(0, 0.5, 0)))
	local smoke = TEX.VS_ToonSmoke4x4 or TEX.SmokePuff4x4
	burst(ringPart, 20, 0, {
		Texture = smoke or SPARKLE,
		FlipbookLayout = if smoke then Enum.ParticleFlipbookLayout.Grid4x4 else Enum.ParticleFlipbookLayout.None,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(DUST),
		LightInfluence = 0.5,
		Size = seq(0, 1.6, 1, 4.2),
		Transparency = seq(0, 0.1, 0.7, 0.35, 1, 1),
		Lifetime = NumberRange.new(0.7, 1),
		Speed = NumberRange.new(14, 22),
		Drag = 5,
		Acceleration = Vector3.new(0, 2.5, 0),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	play(mid)
	play(ringPart)
	Debris:AddItem(mid, 2)
	Debris:AddItem(ringPart, 2)
end

-- the coins: Forge shockwave debris (real physics: they arc up, bounce on the ground, shrink away)
local function coins(holder: Instance, at: Vector3, away: Vector3)
	local anchor = holderPart(holder, "CoinFountain", Vector3.one * 0.2, CFrame.lookAt(at, at + away))
	local att = Instance.new("Attachment")
	att:AddTag("Shockwave")
	att.Parent = anchor
	local folder = Instance.new("Folder")
	folder.Name = "Debris"
	folder.Parent = att
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.18, 0.8, 0.8)
	coin.Color = Color3.fromRGB(255, 176, 22)
	coin.Material = Enum.Material.SmoothPlastic
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin:SetAttribute("InheritanceEnabled", false)
	local n = count(16)
	coin:SetAttribute("Amount", NumberRange.new(n, n))
	coin:SetAttribute("Lifetime", NumberRange.new(1.3, 2))
	coin:SetAttribute("Airtime", NumberRange.new(0.6, 0.85))
	coin:SetAttribute("LinearMagnitude", NumberRange.new(7, 11))
	coin:SetAttribute("AngularMagnitude", NumberRange.new(12, 26))
	coin:SetAttribute("MinSize", Vector3.new(0.18, 0.75, 0.75))
	coin:SetAttribute("MaxSize", Vector3.new(0.2, 0.9, 0.9))
	coin:SetAttribute("MinDirection", Vector3.new(-1, 0.8, -1))
	coin:SetAttribute("MaxDirection", Vector3.new(1, 1.3, 1))
	coin:SetAttribute("SizeScaleEnd", Vector3.zero)
	coin:SetAttribute("Size_Duration", 0.35)
	coin:SetAttribute("Transparency_Start", 0)
	coin:SetAttribute("Transparency_End", 0)
	coin.Parent = folder
	if not forgeEmit(anchor) then
		-- by hand: the same coins, thrown with physics
		for _ = 1, n do
			local c = coin:Clone()
			c.Anchored = false
			c.CanCollide = true
			c.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			c.Parent = holder
			local a = math.random() * math.pi * 2
			c.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 9, 34 + math.random() * 16, math.sin(a) * 9)
			c.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, 0)
			Debris:AddItem(c, 2.4)
		end
	end
	Debris:AddItem(anchor, 6)
end

-- the pop: a light pillar, two starbursts, sparkles, streaks and grass clippings, and the warm light
local function popBurst(holder: Instance, top: Vector3): Part
	local base = holderPart(holder, "PopBurst", Vector3.one * 0.2, CFrame.new(top))
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	-- the light pillar: two Forge neon cylinders that shoot up, widen and fade (a gold one and a white core)
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X
	-- (it starts tall and thin, so its top is already out of the shot, and swells out as it fades)
	partFx(holder, CFrame.new(top + Vector3.new(0, 11, 0)) * up, CFrame.new(top + Vector3.new(0, 17, 0)) * up, Vector3.new(22, 1.4, 1.4), Vector3.new(34, 4.8, 4.8), GOLD_LIGHT, 0.8, 0.4, 1)
	partFx(holder, CFrame.new(top + Vector3.new(0, 11, 0)) * up, CFrame.new(top + Vector3.new(0, 17, 0)) * up, Vector3.new(22, 0.5, 0.5), Vector3.new(34, 1.7, 1.7), WARM, 0.55, 0.1, 1)
	-- rays: two starbursts turning opposite ways behind the crate
	burst(a0, 1, 0, {
		Texture = TEX.VS_Starburst or TEX.Glow or SPARKLE,
		Color = ColorSequence.new(GOLD_LIGHT, GOLD),
		LightEmission = 0.3,
		Size = seq(0, 0, 0.12, 11, 1, 14),
		Transparency = seq(0, 0, 0.5, 0.3, 1, 1),
		Lifetime = NumberRange.new(1.3),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(30, 30),
		ZOffset = -2,
	})
	burst(a0, 1, 0, {
		Texture = TEX.VS_Starburst or TEX.Glow or SPARKLE,
		Color = ColorSequence.new(WARM),
		LightEmission = 0.5,
		Size = seq(0, 0, 0.12, 7, 1, 9),
		Transparency = seq(0, 0.1, 0.5, 0.35, 1, 1),
		Lifetime = NumberRange.new(1.1),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-45, -45),
		ZOffset = -1.5,
	})
	burst(a0, 1, 0, {
		Texture = TEX.Glow or SPARKLE,
		Color = ColorSequence.new(WARM),
		LightEmission = 0.7,
		Size = seq(0, 2, 0.3, 10, 1, 11),
		Transparency = seq(0, 0.1, 1, 1),
		Lifetime = NumberRange.new(0.35),
		Speed = NumberRange.new(0),
		ZOffset = 1,
	})
	burst(a0, 34, 0, {
		Texture = TEX.Star4 or SPARKLE,
		Color = ColorSequence.new(WARM, GOLD),
		LightEmission = 0.6,
		Size = seq(0, 0.9, 0.7, 0.6, 1, 0),
		Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Lifetime = NumberRange.new(1.1, 1.6),
		Speed = NumberRange.new(22, 34),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -38, 0),
		Drag = 0.8,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
	})
	burst(a0, 22, 0, {
		Texture = TEX.Spark or SPARKLE,
		Color = ColorSequence.new(WARM, GOLD_LIGHT),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = seq(0, 0.45, 1, 0),
		Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.55),
		Speed = NumberRange.new(30, 46),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 3,
	})
	burst(a0, 26, 0.03, {
		Texture = FX.splinter or SPARKLE,
		Color = ColorSequence.new(GRASS, Color3.fromRGB(150, 235, 90)),
		LightInfluence = 0.6,
		Size = seq(0, 0.45, 1, 0.35),
		Transparency = seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = NumberRange.new(1.6, 2.4),
		Speed = NumberRange.new(16, 26),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -12, 0),
		Drag = 2.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-160, 160),
	})
	-- the warm light that washes over the party, then settles into the idle glow
	local light = Instance.new("PointLight")
	light.Color = GOLD_LIGHT
	light.Range = 16
	light.Brightness = 0
	light.Shadows = false
	light.Parent = a0
	tween(light, 0.08, { Brightness = 3 })
	task.delay(0.08, function()
		if light.Parent then
			tween(light, 0.9, { Brightness = 0.8 }, Enum.EasingStyle.Sine)
		end
	end)
	task.delay(1.1, function()
		if light.Parent then
			tween(light, 1.6, { Brightness = 1.3 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 8, true)
		end
	end)
	play(base)
	return base
end

-- idle: motes rising out of the open crate and coins twinkling on the heap
local function idleGlow(holder: Instance, top: Vector3, size: Vector3)
	local heap = holderPart(holder, "HeapGlow", Vector3.new(size.X * 0.7, 0.3, size.Z * 0.7), CFrame.new(top))
	emitter(heap, {
		Texture = TEX.Glow or SPARKLE,
		Color = ColorSequence.new(GOLD_LIGHT),
		LightEmission = 0.6,
		Size = seq(0, 0, 0.3, 0.35, 1, 0),
		Transparency = seq(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(1.5, 2.4),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(18, 18),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = rate(9),
		Enabled = true,
	})
	emitter(heap, {
		Texture = TEX.Star4 or SPARKLE,
		Color = ColorSequence.new(WARM),
		LightEmission = 1,
		Size = seq(0, 0, 0.5, 0.75, 1, 0),
		Lifetime = NumberRange.new(0.45, 0.6),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = rate(5),
		Enabled = true,
	})
end

-------------------------------------------------------------------------------------------------------------
-- the crate itself
-------------------------------------------------------------------------------------------------------------
local function templates(): (MeshPart?, MeshPart?)
	local f = ReplicatedStorage:FindFirstChild("IntroProps")
	local body = f and f:FindFirstChild("CrateBody")
	local lid = f and f:FindFirstChild("CrateLid")
	if body and body:IsA("MeshPart") and lid and lid:IsA("MeshPart") then
		return body, lid
	end
	return nil, nil
end

-- Are the ForgeGUI crate models in the place?
function IntroCrate.ready(): boolean
	local body = templates()
	return body ~= nil
end

-- squash and stretch after the landing: { time, width, height } keys, eased between
local SQUASH = { { 0, 1, 1 }, { 0.06, 1.16, 0.74 }, { 0.18, 0.94, 1.1 }, { 0.34, 1, 1 } }
local function squashAt(t: number): (number, number)
	for i = 1, #SQUASH - 1 do
		local a, b = SQUASH[i], SQUASH[i + 1]
		if t <= b[1] then
			local k = (t - a[1]) / (b[1] - a[1])
			k = 0.5 - math.cos(k * math.pi) * 0.5
			return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
		end
	end
	return 1, 1
end

-- The lid's flight: up and back away from the camera, spinning, then it fades out.
local function flyLid(lid: MeshPart, from: CFrame, away: Vector3)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-lid.Size.X * 0.4, 0, 0)
	a0.Parent = lid
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(lid.Size.X * 0.4, 0, 0)
	a1.Parent = lid
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(GOLD_LIGHT)
	trail.Transparency = seq(0, 0.5, 1, 1)
	trail.Lifetime = 0.18
	trail.LightEmission = 0.7
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = lid
	local side = away:Cross(Vector3.yAxis)
	local v = Vector3.new(0, 46, 0) + away * 9 + side * (math.random() * 6 - 3)
	local spin = Vector3.new(7, 1.5, 4) * (if math.random() < 0.5 then -1 else 1)
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > 1.45 or not lid.Parent then
			if conn then
				conn:Disconnect()
			end
			lid:Destroy()
			return
		end
		local pos = from.Position + v * t + Vector3.new(0, -47.5 * t * t, 0)
		lid.CFrame = CFrame.new(pos) * from.Rotation * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
	end)
	task.delay(0.95, function()
		if lid.Parent then
			tween(lid, 0.45, { Transparency = 1 })
		end
	end)
end

-- Drop the crate onto `ground` (a point on the ground). It turns its star toward the camera as it lands. Calls
-- `onLand()` the moment it hits and `onOpen()` (if given) just after it bursts open. Everything goes in `holder`
-- (the cutscene's set, cleared when it ends).
function IntroCrate.drop(holder: Instance, ground: Vector3, face: Vector3, onLand: () -> (), onOpen: (() -> ())?): Model
	local bodyT, lidT = templates()
	assert(bodyT and lidT, "IntroCrate: the crate models are missing")
	local m = Instance.new("Model")
	m.Name = "SupplyCrate"
	m.Parent = holder
	local body = bodyT:Clone()
	local lid = lidT:Clone()
	body.Parent = m
	lid.Parent = m
	m.PrimaryPart = body
	local size = body.Size
	local lidSize = lid.Size
	local rim = body:GetAttribute("RimFromTop") or 0.36
	-- the star faces the camera when it lands (the camera is already on its crate shot by now)
	local toCam = workspace.CurrentCamera.CFrame.Position - ground
	toCam = Vector3.new(toCam.X, 0, toCam.Z)
	local front = if toCam.Magnitude > 1 then toCam.Unit else face
	local floor = CFrame.lookAt(ground, ground + front)
	local function place(at: CFrame, w: number, h: number, lift: number)
		body.Size = Vector3.new(size.X * w, size.Y * h, size.Z * w)
		body.CFrame = at * CFrame.new(0, size.Y * h / 2, 0)
		lid.Size = Vector3.new(lidSize.X * w, lidSize.Y, lidSize.Z * w)
		lid.CFrame = at * CFrame.new(0, size.Y * h - rim + lidSize.Y / 2 + lift, 0)
	end

	telegraph(holder, ground)
	local stopStreak = fallStreak(body)
	local start = os.clock()
	task.spawn(function()
		-- fall
		while m.Parent do
			local k = math.min(1, (os.clock() - start) / FALL)
			local spin = (1 - k) * 1.3
			place(floor * CFrame.new(0, DROP * (1 - k * k), 0) * CFrame.Angles(spin * 0.25, spin, spin * 0.3), 1, 1, 0)
			if k >= 1 then
				break
			end
			task.wait()
		end
		if not m.Parent then
			return
		end
		stopStreak()
		onLand()
		-- impact
		impact(holder, ground, size)
		local hl = Instance.new("Highlight")
		hl.FillColor = WARM
		hl.FillTransparency = 0.1
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = m
		tween(hl, 0.25, { FillTransparency = 1 })
		tween(hl, 0.4, { OutlineTransparency = 1 })
		Debris:AddItem(hl, 0.45)
		local settle = os.clock()
		while m.Parent and os.clock() - settle < SQUASH[#SQUASH][1] do
			local w, h = squashAt(os.clock() - settle)
			place(floor, w, h, 0)
			task.wait()
		end
		place(floor, 1, 1, 0)
		-- rattle: the crate shudders, the lid lifts and light leaks out from under it
		local seam = holderPart(m, "Seam", Vector3.new(size.X * 0.94, 0.12, size.Z * 0.94), floor * CFrame.new(0, size.Y - rim + 0.1, 0))
		seam.Material = Enum.Material.Neon
		seam.Color = GOLD_LIGHT
		tween(seam, 0.3, { Transparency = 0.1 }, Enum.EasingStyle.Linear)
		local leak = Instance.new("PointLight")
		leak.Color = GOLD_LIGHT
		leak.Range = 10
		leak.Brightness = 0
		leak.Parent = seam
		tween(leak, 0.3, { Brightness = 1.5 }, Enum.EasingStyle.Linear)
		local rattle = os.clock()
		while m.Parent and os.clock() - rattle < 0.3 do
			local k = (os.clock() - rattle) / 0.3
			local j = 0.03 + 0.05 * k
			local shake = CFrame.Angles((math.random() - 0.5) * j, (math.random() - 0.5) * j, (math.random() - 0.5) * j)
			place(floor * shake, 1, 1, 0.08 + 0.3 * k + math.random() * 0.08)
			task.wait()
		end
		if not m.Parent then
			return
		end
		place(floor, 1, 1, 0)
		seam:Destroy()
		-- pop
		Sound.play("burst", 0.05, 0.9)
		Sound.play("rareChime", 0, 0.6)
		local top = ground + Vector3.new(0, size.Y - rim, 0)
		flyLid(lid, lid.CFrame, -front)
		popBurst(holder, top)
		coins(holder, top + Vector3.new(0, 0.6, 0), -front)
		idleGlow(holder, top, size)
		if onOpen then
			task.delay(0.3, onOpen)
		end
		-- a little recoil as the lid goes
		local recoil = os.clock()
		while m.Parent and os.clock() - recoil < 0.2 do
			local k = (os.clock() - recoil) / 0.2
			local s = math.sin(k * math.pi)
			body.Size = Vector3.new(size.X * (1 + 0.06 * s), size.Y * (1 - 0.08 * s), size.Z * (1 + 0.06 * s))
			body.CFrame = floor * CFrame.new(0, body.Size.Y / 2, 0)
			task.wait()
		end
		if m.Parent then
			body.Size = size
			body.CFrame = floor * CFrame.new(0, size.Y / 2, 0)
		end
	end)
	return m
end

return IntroCrate
