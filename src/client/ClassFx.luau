-- The classes' gimmicks on screen (server/ClassPerks sends "classFx"). Each class's gimmick looks like the class
-- (owner, 27 Oct: "every class UNIQUE ... its OWN GIMMICK that MATCHES THEIR CLASS"), and its name pops up:
--   rootRip   Weed Puller        a clump yanked out: a burst of dirt, roots flung, a little pop ring
--   tidy      Groundskeeper      a rake's sweep going round the spot, leaves gathered up, a twinkle of "all tidy"
--   courier   Lawn Baron         gold coins popping up and spinning, glints, "COURIER +123"
--   reapWave  Hedge Reaper       two purple scythe crescents racing out, dark wisps
--   stomp     Grass Titan        a shockwave, rock shards thrown up and falling, dust, a little camera shake
--   midas     Ultimate Gardener  a column of gold light on the clump, gold sparkles
--   graze     Goat Man           grass pulled in to be eaten (cheap: it fires every half second)
-- It also sends the Grass Titan's stomp: landing from a jump (the server checks the class and the cooldown).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Format = require(Shared:WaitForChild("Format"))
local FX = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local BFX = require(Shared:WaitForChild("BossFxIds")) :: { [string]: string }
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local ClassFx = {}
local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "ClassFx"
folder.Parent = workspace

local WHITE = Color3.new(1, 1, 1)
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(size: Vector3, cf: CFrame, color: Color3, transparency: number?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0
	p.Parent = folder
	return p
end

-- a flat texture at `pos` growing to `to` studs across and fading, turning `spin` turns on the way
local function spread(pos: Vector3, tex: string, color: Color3, from: number, to: number, time: number, spin: number?)
	local p = part(Vector3.new(from, 0.05, from), CFrame.new(pos + Vector3.new(0, 0.35, 0)), WHITE, 1)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = tex
	d.Color3 = color
	d.Transparency = 0.05
	d.Parent = p
	local ti = TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(p, ti, { Size = Vector3.new(to, 0.05, to), CFrame = p.CFrame * CFrame.Angles(0, (spin or 0) * math.pi * 2, 0) }):Play()
	TweenService:Create(d, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(p, time + 0.1)
end

type Burst = { tex: string, colors: { Color3 }, n: number, life: { number }, speed: { number }, size: number, grav: number?, spread: number?, spin: number?, light: number?, drag: number?, grow: boolean? }
-- one burst of particles from a small box at `pos`
local function burst(pos: Vector3, o: Burst)
	local h = part(Vector3.new(1, 0.4, 1), CFrame.new(pos + Vector3.new(0, 0.5, 0)), WHITE, 1)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = o.tex
	local kps = {}
	for i, c in o.colors do
		table.insert(kps, ColorSequenceKeypoint.new(if #o.colors == 1 then 0 else (i - 1) / (#o.colors - 1), c))
	end
	if #kps == 1 then
		table.insert(kps, ColorSequenceKeypoint.new(1, o.colors[1]))
	end
	e.Color = ColorSequence.new(kps)
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.SpreadAngle = Vector2.new(o.spread or 45, o.spread or 45)
	e.Acceleration = Vector3.new(0, o.grav or -30, 0)
	e.Drag = o.drag or 0.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.spin or 200), o.spin or 200)
	e.Size = if o.grow
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, o.size), NumberSequenceKeypoint.new(1, 0) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.size * 0.3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = o.light or 0
	e.LightInfluence = if (o.light or 0) > 0 then 0 else 1
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = h
	e:Emit(o.n)
	Debris:AddItem(h, o.life[2] + 0.2)
end

-- the gimmick's name popping up over the spot
local function word(pos: Vector3, text: string, color: Color3)
	if text == "" then
		return
	end
	local a = part(Vector3.one * 0.2, CFrame.new(pos + Vector3.new(0, 5, 0)), WHITE, 1)
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(240, 54)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 120
	g.Parent = a
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = rgb(30, 20, 10)
	st.Parent = t
	t.Parent = g
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = g
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(a, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = a.CFrame + Vector3.new(0, 4, 0) }):Play()
	task.delay(0.8, function()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(a, 1.2)
end

local function near(pos: Vector3, dist: number): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude < dist
end

-------------------------------------------------------------------------------------------------------------
-- each class's gimmick
-------------------------------------------------------------------------------------------------------------
local LOOK: { [string]: (Vector3, number, any) -> () } = {}

-- Weed Puller: yanked out by the roots
LOOK.rootRip = function(pos)
	local dirt = rgb(120, 82, 52)
	burst(pos, { tex = BFX.sand, colors = { rgb(160, 115, 70), dirt }, n = 26, life = { 0.5, 0.9 }, speed = { 10, 18 }, size = 0.55, grav = -45, spread = 35 })
	burst(pos, { tex = BFX.strand, colors = { rgb(150, 110, 70), rgb(100, 70, 45) }, n = 8, life = { 0.7, 1.1 }, speed = { 12, 20 }, size = 1.1, grav = -40, spread = 30, spin = 500 })
	burst(pos, { tex = BFX.leaf, colors = { rgb(110, 180, 60) }, n = 8, life = { 0.8, 1.2 }, speed = { 8, 14 }, size = 0.6, grav = -20, spread = 50 })
	spread(pos, FX.ring, rgb(190, 140, 90), 1, 6, 0.4)
	word(pos, "ROOT RIP!", rgb(220, 160, 100))
	if near(pos, 60) then
		Sound.play("slam", 0.05, 0.5)
	end
end

-- Groundskeeper: swept tidy
LOOK.tidy = function(pos, r)
	local green = rgb(160, 230, 120)
	-- the rake's sweep: a curved swoosh going once round the spot
	local h = part(Vector3.new(0.2, 0.05, 0.2), CFrame.new(pos + Vector3.new(0, 0.4, 0)), WHITE, 1)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(r * 0.25, 0, 0)
	a0.Parent = h
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, r * 0.55)
	a1.Parent = h
	local bm = Instance.new("Beam")
	bm.Attachment0, bm.Attachment1 = a0, a1
	bm.CurveSize0, bm.CurveSize1 = r * 0.4, -r * 0.1
	bm.Width0, bm.Width1 = 0.1, 1.2
	bm.FaceCamera = true
	bm.Segments = 14
	bm.Color = ColorSequence.new(WHITE, green)
	bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	bm.LightEmission = 0.5
	bm.Parent = h
	TweenService:Create(h, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = h.CFrame * CFrame.Angles(0, -math.pi * 2, 0) }):Play()
	Debris:AddItem(h, 0.6)
	burst(pos, { tex = BFX.leaf, colors = { green, rgb(100, 170, 60) }, n = 10, life = { 0.6, 1 }, speed = { 4, 8 }, size = 0.5, grav = -8, spread = 70, drag = 2 })
	burst(pos, { tex = FX.flare, colors = { WHITE, rgb(120, 200, 255) }, n = 8, life = { 0.3, 0.6 }, speed = { 2, 6 }, size = 0.9, grav = 0, spread = 80, grow = true, light = 1 })
	word(pos, "TIDY UP!", green)
end

-- Lawn Baron: the bag sold itself
LOOK.courier = function(pos, _r, d)
	local gold = rgb(255, 196, 60)
	for i = 1, 9 do
		local c = part(Vector3.new(0.15, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(240, 180, 40), 0, Enum.Material.Metal)
		c.Shape = Enum.PartType.Cylinder
		c.Reflectance = 0.3
		local ang = i / 9 * math.pi * 2
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang)) * (2.5 + math.random() * 2)
		local up = c.CFrame + out * 0.5 + Vector3.new(0, 3.5 + math.random() * 1.5, 0)
		TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = up * CFrame.Angles(math.pi * 3, 0, 0) }):Play()
		task.delay(0.35, function()
			TweenService:Create(c, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up + out * 0.5 - Vector3.new(0, 4, 0), Transparency = 1 }):Play()
		end)
		Debris:AddItem(c, 0.9)
	end
	burst(pos + Vector3.new(0, 2, 0), { tex = FX.flare, colors = { WHITE, gold }, n = 12, life = { 0.3, 0.6 }, speed = { 3, 8 }, size = 1, grav = 0, spread = 90, grow = true, light = 1 })
	word(pos, if d and d.coins then "COURIER +" .. Format.short(d.coins) else "COURIER!", gold)
	if near(pos, 60) then
		Sound.play("sell", 0.05, 0.6)
	end
end

-- Hedge Reaper: two scythe crescents racing out
LOOK.reapWave = function(pos, r)
	local purple = rgb(170, 90, 255)
	spread(pos, FX.slash, rgb(210, 170, 255), 2, r * 2.2, 0.45, 0.6)
	task.delay(0.08, function()
		spread(pos, FX.slash, purple, 2, r * 1.8, 0.45, -0.5)
	end)
	spread(pos, FX.ring, purple, 2, r * 2.1, 0.5)
	burst(pos, { tex = BFX.smoke, colors = { purple, rgb(60, 20, 90) }, n = 10, life = { 0.8, 1.2 }, speed = { 3, 6 }, size = 2, grav = 1, spread = 80, drag = 1.5, light = 0.3 })
	burst(pos, { tex = BFX.leaf, colors = { rgb(90, 70, 120), rgb(70, 120, 50) }, n = 12, life = { 0.8, 1.2 }, speed = { 10, 16 }, size = 0.5, grav = -12, spread = 85, spin = 500 })
	word(pos, "REAP WAVE!", rgb(200, 150, 255))
	if near(pos, 60) then
		Sound.play("slice", 0.05, 0.7)
	end
end

-- Grass Titan: the ground answers
LOOK.stomp = function(pos, r)
	local moss = rgb(140, 220, 70)
	spread(pos, FX.ring, rgb(200, 170, 110), 2, r * 2.2, 0.5)
	spread(pos, FX.burst, moss, 2, r * 1.2, 0.35)
	burst(pos, { tex = BFX.sand, colors = { rgb(180, 150, 110), rgb(120, 90, 60) }, n = 30, life = { 0.7, 1.2 }, speed = { 8, 16 }, size = 1.2, grav = -12, spread = 80, drag = 1.5 })
	for i = 1, 8 do
		local ang = i / 8 * math.pi * 2 + math.random() * 0.4
		local s = 0.6 + math.random() * 0.6
		local shard = part(Vector3.new(s, s * 1.3, s), CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), rgb(115, 108, 98), 0, Enum.Material.Slate)
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang)) * (r * 0.4 + math.random() * 2)
		local apex = shard.CFrame + out * 0.5 + Vector3.new(0, 4 + math.random() * 2, 0)
		TweenService:Create(shard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = apex * CFrame.Angles(2, 1, 0) }):Play()
		task.delay(0.3, function()
			TweenService:Create(shard, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = apex + out * 0.5 - Vector3.new(0, 5, 0), Transparency = 1 }):Play()
		end)
		Debris:AddItem(shard, 0.75)
	end
	word(pos, "STOMP!", rgb(200, 255, 120))
	if near(pos, 60) then
		Sound.play("slam", 0.05, 0.8)
	end
	-- a short camera shake when it's close
	local cam = workspace.CurrentCamera
	if cam and near(pos, 25) then
		task.spawn(function()
			for i = 1, 6 do
				local k = (7 - i) / 6
				cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * 1.6 * k), math.rad((math.random() - 0.5) * 1.6 * k), 0)
				task.wait()
			end
		end)
	end
end

-- Ultimate Gardener: a golden clump revealed
LOOK.midas = function(pos)
	local gold = rgb(255, 205, 40)
	local col = part(Vector3.new(14, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), gold, 0.2)
	col.Shape = Enum.PartType.Cylinder
	TweenService:Create(col, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(14, 0.1, 0.1), Transparency = 1 }):Play()
	Debris:AddItem(col, 0.9)
	spread(pos, FX.burst, gold, 2, 9, 0.6, 0.3)
	burst(pos, { tex = FX.spark, colors = { WHITE, gold }, n = 20, life = { 0.6, 1.1 }, speed = { 4, 10 }, size = 0.6, grav = -4, spread = 60, grow = true, light = 1 })
	burst(pos, { tex = BFX.petal, colors = { WHITE, gold }, n = 10, life = { 0.8, 1.3 }, speed = { 5, 9 }, size = 0.5, grav = -6, spread = 70, drag = 1.5, light = 0.5 })
	word(pos, "MIDAS TOUCH!", gold)
	if near(pos, 60) then
		Sound.play("rareChime", 0.05, 0.7)
	end
end

-- Goat Man: grass pulled in to be eaten
LOOK.graze = function(pos, r)
	local h = part(Vector3.new(r * 1.6, 0.6, r * 1.6), CFrame.new(pos + Vector3.new(0, 0.4, 0)), WHITE, 1)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = BFX.strand
	e.Color = ColorSequence.new(rgb(160, 235, 100), rgb(90, 170, 60))
	e.Lifetime = NumberRange.new(0.35, 0.45)
	e.Speed = NumberRange.new(0.5, 1)
	e.Size = NumberSequence.new(0.45, 0.1)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.Parent = h
	e:Emit(6)
	Debris:AddItem(h, 0.6)
end

State.on("fx", function(kind: string, d: any)
	if kind ~= "classFx" or type(d) ~= "table" then
		return
	end
	local look = LOOK[d.kind]
	if not look or typeof(d.pos) ~= "Vector3" then
		return
	end
	look(d.pos, d.r or 6, d)
end)

-- the Grass Titan's stomp: a jump that lands
local function watch(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local jumped = false
	hum.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Jumping then
			jumped = true
		elseif new == Enum.HumanoidStateType.Landed then
			if jumped and State.data and State.data.class == "GrassTitan" then
				State.fire("ClassAct", "stomp")
			end
			jumped = false
		elseif new == Enum.HumanoidStateType.Seated or new == Enum.HumanoidStateType.Swimming then
			jumped = false
		end
	end)
end
if player.Character then
	task.spawn(watch, player.Character)
end
player.CharacterAdded:Connect(watch)

return ClassFx
