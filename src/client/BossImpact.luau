--!strict
-- BOSS IMPACT (10 Nov 2026; owner: "finetune and make the fx for the bosses more fitting and more climatic and
-- pretty"). The weight under every boss hit, laid over client/BossVfx's own bursts:
--   * slam: a white-hot core that pops and is gone (an impact frame), two shock rings (a quick white one, a slower
--     one in the boss's colour), chunky studded blocks of the floor kicked up in an arc (they bounce once and
--     sink: the game's block look), and a dark mark left on the floor that fades
--   * ice: the Frost Thornback's own hit (ice shards, frost mist, a cold flash) instead of the sand geyser it
--     borrowed
--   * rage: the moment a boss goes into its rage form: the picture flushes in its warning colour and settles,
--     a pillar of light, a big ring and an eruption of blocks
-- Cheap on purpose: one Heartbeat loop moves every flying block and only runs while there are blocks in the air;
-- at most MAX_BLOCKS at once (phones half); nothing in Potato Mode but the core and the rings.
-- Studio: the Workspace attribute FxSlow (a number, e.g. 8) plays all of it that many times slower, to look at.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Tex = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("BossFxIds")) :: { [string]: string }
local PHONE = require(script.Parent.PhonePerf).on
local Potato = require(script.Parent.Potato)

local VFXLib = ReplicatedStorage:FindFirstChild("VFXLib")
local Assets = VFXLib and VFXLib:FindFirstChild("Assets") and (require(VFXLib:FindFirstChild("Assets") :: ModuleScript) :: any)
local RING_THIN = (Assets and Assets.Tex and Assets.Tex.RingThin) or Tex.glow
local RING_SHOCK = (Assets and Assets.Tex and Assets.Tex.RingShock) or Tex.glow

local BossImpact = {}

local WHITE = Color3.new(1, 1, 1)
local EARTH = Color3.fromRGB(112, 76, 48)
local MAX_BLOCKS = if PHONE then 40 else 90

local folder: Folder? = nil
local function root(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "BossImpact"
	f.Parent = workspace
	folder = f
	return f
end

-- Studio only: everything this many times slower (the Workspace attribute FxSlow), to look at it
local function slow(): number
	if not RunService:IsStudio() then
		return 1
	end
	local s = workspace:GetAttribute("FxSlow")
	return if type(s) == "number" and s > 0 then s else 1
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Material = mat
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = root()
	return p
end

local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	TweenService:Create(o, TweenInfo.new(t * slow(), style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

-- a flat decal on the floor that grows from `from` to `to` studs across while it fades
local function floorRing(pos: Vector3, tex: string, color: Color3, from: number, to: number, time: number, alpha: number, lift: number)
	local p = part("Ring", Vector3.new(from, 0.05, from), CFrame.new(pos + Vector3.new(0, lift, 0)), color, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = tex
	d.Color3 = color
	d.Transparency = alpha
	d.Parent = p
	tween(p, time, { Size = Vector3.new(to, 0.05, to) }, Enum.EasingStyle.Quart)
	tween(d, time, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(p, time * slow() + 0.1)
end

-- the white-hot core of a hit: a glowing ball that pops open and is gone in a blink
local function core(pos: Vector3, r: number, accent: Color3)
	local p = part("Core", Vector3.one * r * 0.3, CFrame.new(pos + Vector3.new(0, r * 0.12, 0)), accent:Lerp(WHITE, 0.65), Enum.Material.Neon, Enum.PartType.Ball)
	p.Transparency = 0.05
	tween(p, 0.2, { Size = Vector3.one * r * 1.15, Transparency = 1, Color = accent }, Enum.EasingStyle.Quart)
	Debris:AddItem(p, 0.2 * slow() + 0.05)
end

-- the dark mark a hit leaves on the floor, fading slowly
local function scorch(pos: Vector3, r: number, floor: Color3)
	local p = part("Scorch", Vector3.new(r * 1.7, 0.05, r * 1.7), CFrame.new(pos + Vector3.new(0, 0.07, 0)), floor, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = Tex.glow
	d.Color3 = floor:Lerp(Color3.new(0, 0, 0), 0.6)
	d.Transparency = 0.35
	d.Parent = p
	task.delay(0.6 * slow(), function()
		tween(d, 1.8, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	end)
	Debris:AddItem(p, 2.5 * slow())
end

-------------------------------------------------------------------------------------------------------------
-- flying blocks: one loop for all of them, running only while some are in the air
-------------------------------------------------------------------------------------------------------------
type Block = { p: BasePart, vel: Vector3, spin: Vector3, floor: number, bounced: boolean, born: number, life: number, size: Vector3 }
local blocks: { Block } = {}
local loop: RBXScriptConnection? = nil
local GRAVITY = Vector3.new(0, -70, 0)

local function step(dt: number)
	dt /= slow()
	local now = os.clock()
	for i = #blocks, 1, -1 do
		local b = blocks[i]
		local age = (now - b.born) / slow()
		if age > b.life or not b.p.Parent then
			b.p:Destroy()
			table.remove(blocks, i)
			continue
		end
		b.vel += GRAVITY * dt
		local cf = b.p.CFrame
		local pos = cf.Position + b.vel * dt
		local half = b.size.Y / 2
		if pos.Y - half < b.floor then
			pos = Vector3.new(pos.X, b.floor + half, pos.Z)
			if b.bounced then
				b.vel = Vector3.zero
				b.spin = Vector3.zero
			else
				b.bounced = true
				b.vel = Vector3.new(b.vel.X * 0.45, -b.vel.Y * 0.3, b.vel.Z * 0.45)
				b.spin *= 0.4
			end
		end
		local rot = cf.Rotation * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
		-- the last 30% of its life it sinks into the floor
		local sink = math.clamp((age / b.life - 0.7) / 0.3, 0, 1)
		b.p.CFrame = CFrame.new(pos - Vector3.new(0, sink * b.size.Y, 0)) * rot
	end
	if #blocks == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

-- `n` studded blocks of the floor (colour `floor`, a shade or two either way) kicked up round `pos`
local function kick(pos: Vector3, r: number, n: number, floor: Color3, power: number)
	if Potato.on then
		return
	end
	n = math.min(math.floor(n * (if PHONE then 0.5 else 1)), MAX_BLOCKS - #blocks)
	for i = 1, n do
		local a = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local s = (0.55 + math.random() * 0.6) * math.clamp(r / 8, 0.7, 1.6)
		local size = Vector3.new(s, s * (0.6 + math.random() * 0.5), s)
		local shade = 0.75 + math.random() * 0.35
		-- every other block is the earth under the floor (green on green read as nothing)
		local base = if i % 2 == 0 then floor:Lerp(EARTH, 0.8) else floor
		local c = Color3.new(math.min(1, base.R * shade), math.min(1, base.G * shade), math.min(1, base.B * shade))
		local at = pos + out * r * (0.15 + math.random() * 0.45) + Vector3.new(0, size.Y / 2, 0)
		local p = part("Block", size, CFrame.new(at) * CFrame.Angles(0, a, 0), c, Enum.Material.Plastic)
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
		local up = (16 + math.random() * 14) * power
		local side = (6 + math.random() * 10) * power
		table.insert(blocks, {
			p = p,
			vel = out * side + Vector3.new(0, up, 0),
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14,
			floor = pos.Y,
			bounced = false,
			born = os.clock(),
			life = 1.4 + math.random() * 0.5,
			size = size,
		})
	end
	if not loop and #blocks > 0 then
		loop = RunService.Heartbeat:Connect(step)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the moments
-------------------------------------------------------------------------------------------------------------
-- A hit landing at `pos` with radius `r`. `strong`: a real slam (the full set); otherwise a lighter one (one of
-- many landing at once: a ring of bursts, a line of them).
function BossImpact.slam(pos: Vector3, r: number, accent: Color3, floor: Color3?, strong: boolean?)
	local fl = floor or Color3.fromRGB(110, 170, 80)
	core(pos, if strong then r else r * 0.6, accent)
	floorRing(pos, RING_THIN, accent:Lerp(WHITE, 0.6), r * 0.4, r * 2.6, 0.3, 0.05, 0.16)
	if strong then
		floorRing(pos, RING_SHOCK, accent, r * 0.5, r * 3.4, 0.7, 0.2, 0.14)
		scorch(pos, r, fl)
		kick(pos, r, math.clamp(math.floor(r * 0.9), 5, 12), fl, 1)
	else
		kick(pos, r, 3, fl, 0.7)
	end
end

-- The Frost Thornback's own hit: ice shards stabbing up, a cold flash and frost mist.
function BossImpact.ice(pos: Vector3, r: number, light: boolean?)
	local ice = Color3.fromRGB(200, 240, 255)
	core(pos, r * 0.8, Color3.fromRGB(160, 230, 255))
	if not light and not Potato.on then
		local n = if PHONE then 4 else 7
		for i = 1, n do
			local a = (i - 1) / n * math.pi * 2 + math.random() * 0.6
			local d = r * (0.2 + 0.55 * math.random())
			local h = 3 + math.random() * 3
			local base = pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			local lean = CFrame.Angles(math.rad(math.random(-28, 28)), a, math.rad(math.random(-28, 28)))
			local up = CFrame.new(base + Vector3.new(0, h / 2 - 0.3, 0)) * lean
			local p = part("Shard", Vector3.new(0.9, h, 0.9), up - Vector3.new(0, h, 0), ice, Enum.Material.Ice)
			p.Transparency = 0.15
			tween(p, 0.12, { CFrame = up }, Enum.EasingStyle.Back)
			task.delay(0.7 * slow(), function()
				if p.Parent then
					tween(p, 0.4, { CFrame = up - Vector3.new(0, h, 0), Transparency = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
			Debris:AddItem(p, 1.3 * slow())
		end
	end
	-- frost mist rolling out low
	local h = part("Frost", Vector3.new(0.2, r * 1.2, r * 1.2), CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), ice, Enum.Material.SmoothPlastic)
	h.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = Tex.smoke
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Right
	e.SpreadAngle = Vector2.new(80, 80)
	e.Lifetime = NumberRange.new(0.9, 1.5)
	e.Speed = NumberRange.new(r * 0.6, r * 1.2)
	e.Drag = 3
	e.Acceleration = Vector3.new(0, -1, 0)
	e.Size = NumberSequence.new(r * 0.25, r * 0.55)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 230, 255))
	e.LightInfluence = 0.6
	e.TimeScale = 1 / slow()
	e.Parent = h
	e:Emit(if PHONE or light then 5 else 10)
	Debris:AddItem(h, 1.7 * slow())
end

-- The rage form breaking out at `feet` (`size` studs across): the picture flushes in the boss's warning colour, a
-- pillar of light, a big ring and an eruption of blocks.
local flushing = false
function BossImpact.rage(feet: Vector3, size: number, warn: Color3, floor: Color3?)
	local fl = floor or Color3.fromRGB(110, 170, 80)
	core(feet + Vector3.new(0, size * 0.15, 0), size * 0.5, warn)
	floorRing(feet, RING_THIN, warn:Lerp(WHITE, 0.5), size * 0.3, size * 3, 0.45, 0, 0.18)
	floorRing(feet, RING_SHOCK, warn, size * 0.4, size * 4.2, 1.0, 0.1, 0.16)
	scorch(feet, size * 0.6, fl)
	kick(feet, size * 0.5, 16, fl, 1.25)
	-- the pillar: a column of light that shoots up and thins away
	local h = size * 3
	local col = part("RagePillar", Vector3.new(size * 0.5, 1, size * 0.5), CFrame.new(feet + Vector3.new(0, 0.5, 0)), warn:Lerp(WHITE, 0.3), Enum.Material.Neon, Enum.PartType.Cylinder)
	col.CFrame = CFrame.new(feet + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	col.Size = Vector3.new(1, size * 0.5, size * 0.5)
	col.Transparency = 0.1
	tween(col, 0.25, { Size = Vector3.new(h, size * 0.35, size * 0.35), CFrame = CFrame.new(feet + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, Enum.EasingStyle.Quart)
	task.delay(0.25 * slow(), function()
		if col.Parent then
			tween(col, 0.6, { Size = Vector3.new(h, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	Debris:AddItem(col, 0.9 * slow())
	-- the picture: a flush of the warning colour that settles (one at a time)
	if not flushing then
		flushing = true
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BossRageFlush"
		cc.TintColor = WHITE
		cc.Parent = Lighting
		local tint = WHITE:Lerp(warn, 0.35)
		tween(cc, 0.12, { TintColor = tint, Contrast = 0.18, Saturation = 0.15, Brightness = 0.06 })
		task.delay(0.2 * slow(), function()
			tween(cc, 0.9, { TintColor = WHITE, Contrast = 0, Saturation = 0, Brightness = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.delay(0.95 * slow(), function()
				cc:Destroy()
				flushing = false
			end)
		end)
	end
end

-- (10 Nov) the pieces, for client/BossMoveFx (each attack's own touch)
BossImpact.kit = {
	part = part,
	tween = tween,
	slow = slow,
	core = core,
	floorRing = floorRing,
	scorch = scorch,
	kick = kick,
	RING_THIN = RING_THIN,
	RING_SHOCK = RING_SHOCK,
}

return BossImpact
