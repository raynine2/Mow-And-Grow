-- Client-only juice: grass clippings, mutation reveals, coin showers, boss telegraphs and hits, banners, shake.
-- Rules (from the Steal a Package review): one focus per moment, show it in the world first, let sound
-- replace text, never stack two messages about the same thing.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local ViewModel = require(script.Parent.ViewModel)

local Fx = {}
local player = Players.LocalPlayer
local C = UI.colors

local folder = Instance.new("Folder")
folder.Name = "ClientFx"
folder.Parent = workspace

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(pos: Vector3, dist: number): boolean
	local r = myRoot()
	return r ~= nil and (r.Position - pos).Magnitude <= dist
end

local function fxPart(size: Vector3, color: Color3, cf: CFrame, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Parent = folder
	return p
end

-------------------------------------------------------------------------------------------------------------
-- arcs: pieces fly up and out, then drop back to the ground and shrink away
-------------------------------------------------------------------------------------------------------------
type ArcOpts = { count: number, color: Color3, size: Vector3, height: number, spread: number, life: number, neon: boolean?, groundY: number? }
function Fx.arc(pos: Vector3, o: ArcOpts)
	local ground = o.groundY or (pos.Y - 0.5)
	for _ = 1, o.count do
		local s = o.size * (0.75 + math.random() * 0.5)
		local start = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local p = fxPart(s, o.color, start, o.neon)
		local angle = math.random() * math.pi * 2
		local dist = o.spread * (0.35 + math.random() * 0.65)
		local apex = pos + Vector3.new(math.cos(angle) * dist * 0.55, o.height * (0.6 + math.random() * 0.5), math.sin(angle) * dist * 0.55)
		local land = Vector3.new(pos.X + math.cos(angle) * dist, ground + s.Y / 2, pos.Z + math.sin(angle) * dist)
		local up = o.life * 0.42
		local down = o.life - up
		local spin = CFrame.Angles(math.random() * 4, math.random() * 4, math.random() * 4)
		TweenService:Create(p, TweenInfo.new(up, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(apex) * spin }):Play()
		task.delay(up, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(down, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land) * spin * spin, Size = s * 0.15 }):Play()
			end
		end)
		Debris:AddItem(p, o.life + 0.05)
	end
end

-- Floating world text that pops, rises and fades.
function Fx.floatText(pos: Vector3, text: string, color: Color3, scale: number?)
	local anchor = fxPart(Vector3.one * 0.2, color, CFrame.new(pos + Vector3.new(0, 2, 0)))
	anchor.Transparency = 1
	local s = scale or 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220 * s, 56 * s)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = UI.text(gui, text, UDim2.fromScale(1, 1), { color = color, stroke = 3 })
	UI.bounce(label)
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) }):Play()
	task.delay(0.75, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(anchor, 1.2)
end

-- Flat disc on the ground (Roblox cylinders run along X, so turn it on its side).
local function disc(pos: Vector3, radius: number, color: Color3, transparency: number, thickness: number?): Part
	local p = fxPart(Vector3.new(thickness or 0.2, radius * 2, radius * 2), color, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), true)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = transparency
	return p
end

function Fx.ring(pos: Vector3, radius: number, color: Color3, life: number)
	local p = disc(pos + Vector3.new(0, 0.35, 0), 1, color, 0.15)
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.05)
end

-- Camera shake through Humanoid.CameraOffset (never fights the camera script).
local shakeUntil, shakePower = 0, 0
function Fx.shake(power: number, time: number)
	shakeUntil = math.max(shakeUntil, os.clock() + time)
	shakePower = math.max(shakePower, power)
end
RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local left = shakeUntil - os.clock()
	if left > 0 then
		local p = shakePower * math.min(1, left * 3) * 0.12
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * p, (math.random() - 0.5) * p, 0)
	elseif shakePower > 0 then
		shakePower = 0
		hum.CameraOffset = Vector3.zero
	end
end)

-- One big banner at a time: a new one replaces the old one.
local currentBanner: Frame? = nil
function Fx.banner(text: string, color: Color3, time: number, sub: string?)
	if currentBanner then
		currentBanner:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "Banner"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(900, 150)
	holder.Position = UDim2.fromScale(0.5, 0.27)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.ZIndex = 40
	holder.Parent = UI.gui
	currentBanner = holder
	local t = UI.text(holder, text, UDim2.new(1, 0, 0, 92), { color = Color3.new(1, 1, 1), stroke = 5 })
	t.ZIndex = 40
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(color, 1.35), UI.shade(color, 0.9))
	g.Rotation = 90
	g.Parent = t
	if sub then
		local s = UI.text(holder, sub, UDim2.new(1, 0, 0, 40), { pos = UDim2.fromOffset(0, 98), stroke = 3 })
		s.ZIndex = 40
	end
	UI.bounce(holder)
	task.delay(time, function()
		if holder.Parent then
			local fade = TweenInfo.new(0.3)
			for _, d in holder:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, fade, { Transparency = 1 }):Play()
				end
			end
			task.wait(0.32)
			holder:Destroy()
		end
		if currentBanner == holder then
			currentBanner = nil
		end
	end)
end

-- The trailer's hit: a bright white flash and a soft dust puff where the blow lands.
function Fx.impact(pos: Vector3, tint: Color3?)
	local anchor = fxPart(Vector3.one * 0.2, Color3.new(1, 1, 1), CFrame.new(pos))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5, 5)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.2, 0.2)
	glow.BackgroundColor3 = Color3.fromRGB(255, 250, 225)
	glow.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = glow
	glow.Parent = gui
	TweenService:Create(glow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }):Play()
	-- puff: a few soft balls that swell and fade
	for _ = 1, 3 do
		local b = fxPart(Vector3.one * 0.8, tint or Color3.fromRGB(245, 240, 220), CFrame.new(pos + Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)))
		b.Shape = Enum.PartType.Ball
		b.Material = Enum.Material.SmoothPlastic
		b.Transparency = 0.35
		TweenService:Create(b, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 2.4, Transparency = 1, CFrame = b.CFrame + Vector3.new(0, 1.2, 0) }):Play()
		Debris:AddItem(b, 0.5)
	end
	Debris:AddItem(anchor, 0.25)
end

-- Quick white flash on a model (boss hits).
local function flash(model: Instance)
	local h = model:FindFirstChild("HitFlash") :: Highlight?
	if not h then
		local n = Instance.new("Highlight")
		n.Name = "HitFlash"
		n.FillColor = Color3.new(1, 1, 1)
		n.OutlineTransparency = 1
		n.DepthMode = Enum.HighlightDepthMode.Occluded
		n.Parent = model
		h = n
	end
	local hl = h :: Highlight
	hl.FillTransparency = 0.25
	TweenService:Create(hl, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
end

local function bossModel(): Model?
	local world = workspace:FindFirstChild("World")
	local holder = world and world:FindFirstChild("Boss")
	return holder and holder:FindFirstChildOfClass("Model")
end

-------------------------------------------------------------------------------------------------------------
-- server fx events
-------------------------------------------------------------------------------------------------------------
local handlers = {}
local lastCutSound = 0

handlers.cut = function(d)
	if not near(d.pos, 140) then
		return
	end
	local m = Config.mutation(d.mut or "None")
	local color = m.color or d.color
	-- clippings: thin blades that fly and land
	Fx.arc(d.pos + Vector3.new(0, 1.2, 0), { count = if m.id == "None" then 7 else 14, color = color, size = Vector3.new(0.25, 1.1, 0.25), height = 4, spread = 4, life = 0.7, neon = m.id == "Galaxy" or m.id == "Toxic" })
	if d.by == player.UserId then
		Fx.impact(d.pos + Vector3.new(0, 1.4, 0))
		State.emit("bundleGained", d.pos, d.mut)
		local now = os.clock()
		if now - lastCutSound > 0.07 then
			lastCutSound = now
			Sound.play("cut", 0.12)
		end
	end
end

handlers.chip = function(d)
	-- flat clippings (like the trailer's wood chips) + flash + puff
	Fx.arc(d.pos + Vector3.new(0, 1.5, 0), { count = 4, color = UI.shade(d.color, 1.3), size = Vector3.new(0.5, 0.08, 0.3), height = 3, spread = 3, life = 0.5 })
	Fx.impact(d.pos + Vector3.new(0, 1.6, 0))
	Sound.play("chip", 0.15)
end

handlers.topOff = function(d)
	-- the knocked-off top tumbles away and lands
	if not near(d.pos, 120) then
		return
	end
	local p = fxPart(d.size, d.color, CFrame.new(d.pos))
	p.Material = Enum.Material.Grass
	local angle = math.random() * math.pi * 2
	local land = Vector3.new(d.pos.X + math.cos(angle) * 3, 0.3 + d.size.Y / 2, d.pos.Z + math.sin(angle) * 3)
	local apex = d.pos:Lerp(land, 0.4) + Vector3.new(0, 2, 0)
	TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(apex) * CFrame.Angles(math.rad(60), 0, 0) }):Play()
	task.delay(0.2, function()
		TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land) * CFrame.Angles(math.rad(90), 0, math.rad(20)) }):Play()
	end)
	task.delay(1.2, function()
		TweenService:Create(p, TweenInfo.new(0.4), { Size = d.size * 0.1 }):Play()
	end)
	Debris:AddItem(p, 1.7)
end

handlers.reveal = function(d)
	local m = Config.mutation(d.mut)
	if not near(d.pos, 160) or not m.color then
		return
	end
	Fx.arc(d.pos + Vector3.new(0, 1.5, 0), { count = 16, color = m.color, size = Vector3.new(0.6, 0.6, 0.6), height = 7, spread = 6, life = 0.9, neon = true })
	Fx.ring(d.pos, 9, m.color, 0.55)
	Fx.floatText(d.pos + Vector3.new(0, 2, 0), m.id:upper() .. "!", m.color, 1.25)
	Sound.play("reveal")
end

handlers.gems = function(d)
	Fx.floatText(d.pos + Vector3.new(0, 4, 0), "+" .. d.amount .. " GEMS", C.purple, 0.9)
end

handlers.sell = function(d)
	-- coins pour out of the chute, the HUD counter fills from them
	if d.out then
		Fx.arc(d.out + Vector3.new(0, 1, 0), { count = math.min(24, 6 + d.count), color = C.yellow, size = Vector3.new(0.9, 0.25, 0.9), height = 6, spread = 7, life = 0.9, neon = false })
	end
	State.emit("flyCoins", math.min(12, 3 + d.count))
	Sound.play("sell")
end

handlers.shred = function(d)
	if d.pos and near(d.pos, 150) then
		Fx.arc(d.pos + Vector3.new(0, 1, 0), { count = math.min(24, 8 + d.count * 2), color = Color3.fromRGB(150, 230, 80), size = Vector3.new(0.3, 0.9, 0.3), height = 9, spread = 5, life = 0.8 })
	end
end

handlers.telegraph = function(d)
	-- outline ring + an inner disc that fills up until the slam
	local edge = disc(d.pos + Vector3.new(0, 0.25, 0), d.radius, C.red, 0.35, 0.25)
	local base = disc(d.pos + Vector3.new(0, 0.2, 0), d.radius - 0.6, Color3.fromRGB(255, 220, 220), 0.6, 0.2)
	local fill = disc(d.pos + Vector3.new(0, 0.3, 0), 0.5, C.red, 0.25, 0.3)
	TweenService:Create(fill, TweenInfo.new(d.delay, Enum.EasingStyle.Linear), { Size = Vector3.new(0.3, (d.radius - 0.6) * 2, (d.radius - 0.6) * 2) }):Play()
	for _, p in { edge, base, fill } do
		Debris:AddItem(p, d.delay + 0.05)
	end
	if near(d.pos, d.radius + 4) then
		Sound.play("warn")
	end
end

handlers.slam = function(d)
	Fx.ring(d.pos, d.radius * 1.3, Color3.fromRGB(255, 245, 220), 0.45)
	Fx.arc(d.pos + Vector3.new(0, 0.5, 0), { count = 14, color = Color3.fromRGB(150, 105, 60), size = Vector3.new(0.9, 0.9, 0.9), height = 6, spread = d.radius, life = 0.8 })
	if near(d.pos, d.radius + 40) then
		Fx.shake(8, 0.35)
		Sound.play("slam")
	end
end

handlers.knock = function(d)
	local r = myRoot()
	if r then
		r.AssemblyLinearVelocity = d.dir * 70 + Vector3.new(0, 40, 0)
	end
	Fx.shake(10, 0.4)
	Sound.play("hurt")
end

handlers.bossSpawn = function(d)
	Fx.banner(d.name:upper(), C.red, 2.6, "Dodge the red circles!")
	Fx.shake(6, 1)
	Fx.arc(d.pos, { count = 30, color = Color3.fromRGB(130, 95, 60), size = Vector3.new(1, 1, 1), height = 14, spread = 18, life = 1.1 })
	Sound.play("roar")
end

handlers.bossHit = function(d)
	local m = bossModel()
	if m then
		flash(m)
	end
	Fx.floatText(d.pos + Vector3.new(math.random(-4, 4), math.random(-2, 2), math.random(-4, 4)), "-" .. Format.short(d.amount), C.yellow, 0.75)
	Sound.play("hit", 0.1)
end

handlers.bossDown = function(d)
	Fx.arc(d.pos + Vector3.new(0, 4, 0), { count = 40, color = C.green, size = Vector3.new(1.2, 1.2, 1.2), height = 20, spread = 24, life = 1.4 })
	Fx.ring(d.pos, 32, C.yellow, 0.9)
	Fx.shake(5, 0.6)
	Sound.play("victory")
end

-- personal boss reward (one banner, the rewards underneath)
handlers.reward = function(d)
	Fx.banner(d.title, C.green, 3, ("+%s coins   +%d gems"):format(Format.short(d.coins), d.gems))
	State.emit("flyCoins", 10)
end

handlers.zoneOpen = function(d)
	Fx.banner(("ZONE %d: %s"):format(d.zone, d.name:upper()), C.yellow, 2.6, "The gate is open!")
	Sound.play("purchase")
end

handlers.runComplete = function(d)
	Fx.banner("RUN COMPLETE!", C.yellow, 10, ("+%d gems. Back to the lobby soon..."):format(d.gems or 0))
	Sound.play("victory")
end

handlers.purchase = function(d)
	Sound.play(if d.big then "purchase" else "upgrade")
	local r = myRoot()
	if r and d.item then
		Fx.arc(r.Position + Vector3.new(0, 2, 0), { count = 14, color = C.yellow, size = Vector3.new(0.5, 0.5, 0.5), height = 6, spread = 5, life = 0.8, neon = true })
		Fx.floatText(r.Position + Vector3.new(0, 3, 0), d.item:upper() .. "!", C.yellow, 1.1)
	end
end

handlers.bagFull = function()
	Sound.play("denied")
end

handlers.mowerReady = function(d)
	Fx.ring(d.pos, 8, C.purple, 0.7)
	Fx.arc(d.pos + Vector3.new(0, 1, 0), { count = 12, color = C.purple, size = Vector3.new(0.6, 0.6, 0.6), height = 6, spread = 6, life = 0.8, neon = true })
	Sound.play("purchase")
end

State.on("swing", function()
	task.delay(0.12, ViewModel.slashStreak)
	Sound.play("whoosh", 0.15)
end)

State.on("fx", function(kind, payload)
	local h = handlers[kind]
	if h then
		local ok, err = pcall(h, payload)
		if not ok then
			warn("[Fx] " .. kind .. ": " .. tostring(err))
		end
	end
end)

-- spin the shredder rollers
task.spawn(function()
	local rollers = {}
	local function scan()
		table.clear(rollers)
		local world = workspace:FindFirstChild("World")
		if not world then
			return
		end
		for _, p in world:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("Spin") then
				table.insert(rollers, { part = p, base = p.CFrame, speed = p:GetAttribute("Spin") })
			end
		end
	end
	workspace.ChildAdded:Connect(function(c)
		if c.Name == "World" then
			task.wait(1)
			scan()
		end
	end)
	task.wait(2)
	scan()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for i, r in rollers do
			if r.part.Parent then
				r.part.CFrame = r.base * CFrame.Angles(t * r.speed * (if i % 2 == 0 then 1 else -1), 0, 0)
			end
		end
	end)
end)

return Fx
