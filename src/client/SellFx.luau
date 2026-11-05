-- Selling, as a show: your bundles fly off your back one after another in arcs into the Giant Grass Shredder,
-- the machine rumbles and sprays shredded grass out of its chute, a fountain of real gold coins pours out of
-- the tray, bounces on the ground and then gets pulled into you, ticking up the coin counter. A big golden
-- "+coins" pops over the machine. Client-only; the server already did the selling.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local BundleVoxel = require(Shared:WaitForChild("BundleVoxel"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local SellFx = {}
local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "SellFx"
folder.Parent = workspace

local GOLD = Color3.fromRGB(255, 198, 40)
local COIN_PHYS = PhysicalProperties.new(2, 0.6, 0.45)

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function zoneGrass(): Color3
	local z = (State.world and State.world.zone) or 1
	local def = Config.ZONES[z] or Config.ZONES[1]
	return def.grass[1]
end

-- Runs fn(t) every frame for `time` seconds (t goes 0..1), then done().
local function animate(time: number, fn: (number) -> (), done: (() -> ())?)
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / time)
		local ok = pcall(fn, t)
		if t >= 1 or not ok then
			conn:Disconnect()
			if done then
				done()
			end
		end
	end)
end

local function burst(pos: Vector3, count: number, props: { [string]: any })
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 2)
end

-------------------------------------------------------------------------------------------------------------
-- the machine
-------------------------------------------------------------------------------------------------------------
local function shredderModel(): Model?
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local s = hub and hub:FindFirstChild("Shredder")
	local m = s and s:FindFirstChild("shredder")
	return if m and m:IsA("Model") then m else nil
end

local rumbleUntil = 0
local rumbling = false
local function rumble(time: number)
	rumbleUntil = math.max(rumbleUntil, os.clock() + time)
	local m = shredderModel()
	if rumbling or not m then
		return
	end
	rumbling = true
	local base = m:GetPivot()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local left = rumbleUntil - os.clock()
		if left <= 0 or not m.Parent then
			conn:Disconnect()
			rumbling = false
			if m.Parent then
				m:PivotTo(base)
			end
			return
		end
		local k = math.min(1, left * 3) * 0.09
		m:PivotTo(base * CFrame.new(rand(-k, k), rand(0, k), rand(-k, k)) * CFrame.Angles(rand(-k, k) * 0.2, 0, rand(-k, k) * 0.2))
	end)
end

-- Shredded grass sprays up out of the top of the machine.
local function spray(mouth: Vector3, amount: number)
	local grass = zoneGrass()
	local at = mouth + Vector3.new(0, 1.5, 0)
	burst(at, math.min(30, 6 + amount * 3), {
		Texture = FxIds.blade or "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(UI.shade(grass, 1.35), UI.shade(grass, 0.9)),
		LightInfluence = 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(16, 26),
		SpreadAngle = Vector2.new(30, 30),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-400, 400),
		Drag = 1.2,
		Acceleration = Vector3.new(0, -40, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
	if FxIds.poof then
		burst(at, 2, {
			Texture = FxIds.poof,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(Color3.fromRGB(240, 248, 220)),
			LightInfluence = 0.3,
			Size = NumberSequence.new(1.6, 3.2),
			Transparency = NumberSequence.new(0.1, 0.3),
			Lifetime = NumberRange.new(0.5, 0.7),
			Speed = NumberRange.new(4, 7),
			SpreadAngle = Vector2.new(25, 25),
			Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Top,
		})
	end
end

SellFx.spray = spray -- (5 Nov) client/Funny's shredder spit-out sprays the same clippings

-------------------------------------------------------------------------------------------------------------
-- bundles fly from your back into the hopper
-------------------------------------------------------------------------------------------------------------
local function bundleModel(): Model
	local models = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = models and models:FindFirstChild("bundle")
	local m: Model
	-- the voxel bundle of the area you're in (shared/BundleVoxel, 4 Nov: the same as the ones on your back), turning
	-- about its middle
	local vb = BundleVoxel.make((State.world and State.world.zone) or 1, nil, 2.4)
	if vb.PrimaryPart then
		m = vb
		m.WorldPivot = vb.PrimaryPart.CFrame
	elseif template and template:IsA("Model") then
		m = template:Clone()
	else
		m = Instance.new("Model")
		local p = Instance.new("Part")
		p.Size = Vector3.new(2.8, 1.4, 1.4)
		p.Color = zoneGrass()
		p.Material = Enum.Material.Grass
		p.Parent = m
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	m.Parent = folder
	return m
end

local function throwBundle(from: Vector3, to: Vector3, delay: number, onLand: () -> ())
	task.delay(delay, function()
		local m = bundleModel()
		local dist = (to - from).Magnitude
		local ctrl = from:Lerp(to, 0.5) + Vector3.new(0, 5 + dist * 0.18, 0)
		local spinAxis = Vector3.new(rand(-1, 1), rand(-1, 1), rand(-1, 1)).Unit
		Sound.play("whoosh", 0.2)
		animate(0.42, function(t)
			local a, b = from:Lerp(ctrl, t), ctrl:Lerp(to, t)
			local p = a:Lerp(b, t)
			local s = 1 - 0.35 * t * t -- shrinks a little as it drops into the hopper
			m:PivotTo(CFrame.new(p) * CFrame.fromAxisAngle(spinAxis, t * 9))
			m:ScaleTo(math.max(0.05, 0.9 * s))
		end, function()
			m:Destroy()
			onLand()
		end)
	end)
end

-------------------------------------------------------------------------------------------------------------
-- coins: a fountain of real coins, then pulled into you
-------------------------------------------------------------------------------------------------------------
local liveCoins = 0
local MAX_COINS = 40
local pitchStep = 0
-- (5 Nov, the Nintendo pass: Mario's coins ring up a real scale and the run never drops back mid-streak) the coins
-- coming into you climb a major pentatonic run from the start of each sale and ring on its top two notes once there
-- (it used to slide up 12 steps and fall back to the bottom in the middle of a sale); the sale's last coin rings the
-- octave over the top with a sparkle
local RUN = { 1, 1.122, 1.26, 1.498, 1.682, 2, 2.245, 2.52 }
local saleLeft = 0
local function coinNote(): number
	pitchStep += 1
	if pitchStep <= #RUN then
		return RUN[pitchStep]
	end
	return RUN[#RUN - 1 + (pitchStep % 2)]
end
-- (coins land in bunches, several on one frame: their ticks go out on a steady beat instead, like a counter
-- ringing up, never more than one every TICK s)
local TICK = 0.055
local nextTick = 0
local function tick(key: string, pitch: number, volume: number?)
	local now = os.clock()
	nextTick = math.max(nextTick, now)
	local wait = nextTick - now
	nextTick += TICK
	if wait < 0.005 then
		Sound.playAt(key, pitch, volume)
	else
		task.delay(wait, Sound.playAt, key, pitch, volume)
	end
end

local function coinPart(): Part
	local c = Instance.new("Part")
	c.Shape = Enum.PartType.Cylinder
	c.Size = Vector3.new(0.22, 1.05, 1.05)
	c.Color = GOLD
	c.Material = Enum.Material.SmoothPlastic
	c.Reflectance = 0.25
	c.CanQuery = false
	c.CanTouch = false
	c.CustomPhysicalProperties = COIN_PHYS
	c.TopSurface = Enum.SurfaceType.Smooth
	c.BottomSurface = Enum.SurfaceType.Smooth
	return c
end

local function collect(c: Part)
	c.Anchored = true
	local from = c.Position
	local spin = CFrame.Angles(0, 0, 0)
	animate(0.32, function(t)
		local root = myRoot()
		local target = if root then root.Position + Vector3.new(0, 1.2, 0) else from
		local e = t * t
		c.CFrame = CFrame.new(from:Lerp(target, e)) * spin * CFrame.Angles(0, t * 20, math.rad(90))
		c.Size = Vector3.new(0.22, 1.05, 1.05) * (1 - 0.6 * e)
	end, function()
		local pos = c.Position
		c:Destroy()
		liveCoins -= 1
		burst(pos, 3, {
			Texture = FxIds.spark or "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 160)),
			LightEmission = 1,
			Size = NumberSequence.new(0.5, 0),
			Lifetime = NumberRange.new(0.2, 0.35),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(180, 180),
		})
		tick("click", coinNote())
		if pitchStep % 2 == 0 then
			State.emit("flyCoins", 1)
		end
		saleLeft -= 1
		if saleLeft == 0 then
			tick("pickup", 2, 0.8) -- the last coin in: the octave, and the counter's done
		end
	end)
end

local function fountain(out: Vector3, away: Vector3, amount: number)
	local n = math.clamp(5 + amount * 2, 6, 30)
	pitchStep = 0
	saleLeft = math.min(n, MAX_COINS - liveCoins)
	for i = 1, n do
		if liveCoins >= MAX_COINS then
			return
		end
		liveCoins += 1
		task.delay((i - 1) * 0.025, function()
			local c = coinPart()
			c.CFrame = CFrame.new(out + Vector3.new(rand(-0.5, 0.5), 0.6, rand(-0.5, 0.5))) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
			c.Parent = folder
			local side = away:Cross(Vector3.yAxis)
			c.AssemblyLinearVelocity = away * rand(8, 17) + side * rand(-7, 7) + Vector3.new(0, rand(34, 50), 0)
			c.AssemblyAngularVelocity = Vector3.new(rand(-30, 30), rand(-30, 30), rand(-30, 30))
			task.delay(rand(0.75, 1.1), function()
				if c.Parent then
					collect(c)
				end
			end)
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the big golden "+coins" over the machine
-------------------------------------------------------------------------------------------------------------
local function moneyPop(pos: Vector3, coins: number)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = pos
	local gui = Instance.new("BillboardGui")
	gui.Adornee = a
	gui.Size = UDim2.fromScale(12, 3.2)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Parent = a
	local label = UI.text(gui, "+" .. Format.commas(coins), UDim2.fromScale(1, 1), { color = Color3.new(1, 1, 1), stroke = 4 })
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 245, 150), Color3.fromRGB(255, 170, 30))
	g.Rotation = 90
	g.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	animate(1.6, function(t)
		a.Position = pos + Vector3.new(0, 3 * (1 - (1 - t) ^ 2), 0)
		if t > 0.7 then
			local f = (t - 0.7) / 0.3
			label.TextTransparency = f
			local st = label:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = f
			end
		end
	end, function()
		a:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the whole show
-------------------------------------------------------------------------------------------------------------
-- d: { coins, count, from = hopper mouth, out = coin tray } (server "sell" fx, sent to the seller only)
function SellFx.sell(d: { [string]: any })
	local mouth: Vector3? = d.from
	local out: Vector3? = d.out
	local root = myRoot()
	if not mouth or not out or not root then
		State.emit("flyCoins", math.min(12, 3 + (d.count or 1)))
		Sound.play("sell")
		return
	end
	local count = math.min(12, d.count or 1)
	local landed = 0
	local away = Vector3.new(out.X - mouth.X, 0, out.Z - mouth.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
	for i = 1, count do
		local back = root.CFrame * CFrame.new(rand(-0.3, 0.3), 1.2 + i * 0.3, 1.1)
		throwBundle(back.Position, mouth + Vector3.new(0, 0.5, 0), (i - 1) * 0.07, function()
			landed += 1
			rumble(0.35)
			spray(mouth, 1)
			-- (5 Nov) each bundle into the hopper a step higher (do, re, mi ...): the build-up before the payout
			local chip = Config.SOUNDS.chip
			local steps = { 1, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888 }
			local step = if landed <= #steps then steps[landed] else steps[#steps - 1 + (landed % 2)] -- (then la, ti, la ...)
			Sound.playAt("chip", (if chip then chip.pitch or 1 else 1) * step, 0.8)
			if landed == count then
				-- the last bundle is in: the machine coughs up the money
				task.delay(0.15, function()
					spray(mouth, count)
					fountain(out, away, count)
					moneyPop(mouth + Vector3.new(0, 4, 0), d.coins or 0)
					Sound.play("sell")
				end)
			end
		end)
	end
end

-- Other players' sales: just the machine's rumble and spray (no coins for you).
function SellFx.shred(d: { [string]: any })
	if d.pos then
		rumble(0.5)
		spray(d.pos, math.min(6, d.count or 1))
	end
end

return SellFx
