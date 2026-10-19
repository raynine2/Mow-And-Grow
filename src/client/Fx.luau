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
local HitFx = require(script.Parent.HitFx)
local CameraView = require(script.Parent.CameraView)
local FxIds = require(ReplicatedStorage.MowALawn:WaitForChild("FxIds")) :: { [string]: string }
local SellFx = require(script.Parent.SellFx)
local Confetti = require(script.Parent.Confetti)
local BossFx = require(script.Parent.BossFx)

local Fx = {}
local player = Players.LocalPlayer
local C = UI.colors

local folder = Instance.new("Folder")
folder.Name = "ClientFx"
folder.Parent = workspace

-- The id of the tool in this player's hand ("Hands" for bare hands).
local function heldToolId(): string?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ToolId") :: string?
end

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

-- Camera shake (CameraView owns the camera offset, so shakes from everywhere add up instead of fighting).
function Fx.shake(power: number, time: number)
	CameraView.shake(power, time)
end

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

-- Boss fights (intro cinematic, HP bar, hits, slams, death) live in client/BossFx; it shakes the camera with ours.
BossFx.shake = Fx.shake

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
	local mine = d.by == player.UserId
	-- the clump comes apart: splinters, blade bits, tumbling clippings, dust, a ground ring
	HitFx.play("cut", d.pos, color, mine, nil, Config.ZONES[d.z] and Config.ZONES[d.z].style)
	if mine then
		(Fx :: any).hideHp()
		State.emit("bundleGained", d.pos, d.mut)
		local now = os.clock()
		if now - lastCutSound > 0.07 then
			lastCutSound = now
			Sound.play("cut", 0.12)
		end
	end
end

-- One HP bar that follows the patch you're cutting (like "Oak 2.5/6 HP" in Chop A Forest).
local hpAnchor = fxPart(Vector3.one * 0.2, Color3.new(1, 1, 1), CFrame.new(0, -100, 0))
hpAnchor.Transparency = 1
local hpGui = Instance.new("BillboardGui")
hpGui.Size = UDim2.fromOffset(190, 46)
hpGui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
hpGui.AlwaysOnTop = true
hpGui.LightInfluence = 0
hpGui.MaxDistance = 60
hpGui.Adornee = hpAnchor
hpGui.Enabled = false
hpGui.Parent = hpAnchor
local hpName = UI.text(hpGui, "", UDim2.new(1, 0, 0, 18), { stroke = 1.5 })
local hpTrack = UI.frame({ size = UDim2.new(1, 0, 0, 20), pos = UDim2.fromOffset(0, 22), color = Color3.fromRGB(30, 30, 34), parent = hpGui, radius = 10, outline = 2 })
local hpFill = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(255, 150, 40), parent = hpTrack, radius = 10, outline = 0 })
UI.gradient(hpFill, Color3.fromRGB(255, 160, 50))
local hpText = UI.text(hpTrack, "", UDim2.new(1, -8, 1, -4), { pos = UDim2.fromOffset(4, 2), stroke = 1.5 })
hpText.ZIndex = 3
local hpShownAt = 0
function Fx.hideHp()
	hpGui.Enabled = false
end
function Fx.hpBar(pos: Vector3, label: string, hp: number, max: number)
	hpAnchor.CFrame = CFrame.new(pos)
	hpName.Text = label
	hpFill.Size = UDim2.fromScale(math.clamp(hp / math.max(max, 1), 0, 1), 1)
	hpText.Text = Format.short(math.max(hp, 0) * 10 // 1 / 10) .. "/" .. Format.short(max) .. " HP"
	hpGui.Enabled = true
	hpShownAt = os.clock()
	task.delay(1.6, function()
		if os.clock() - hpShownAt >= 1.55 then
			hpGui.Enabled = false
		end
	end)
end

handlers.chip = function(d)
	if d.label then
		Fx.hpBar(d.pos, d.label, d.hp, d.max)
	end
	-- your swing already drew this hit the moment it landed (HitFx prediction); auto tools and extra targets
	-- of a wide swing are drawn now
	if not HitFx.wasPredicted(d.pos) then
		local id = heldToolId()
		local auto = false
		for _, t in Config.TOOLS do
			if t.id == id and t.kind == "auto" then
				auto = true
			end
		end
		HitFx.play(if auto then "auto" elseif id == "Hands" then "punch" else "hit", d.pos, d.color, true)
	end
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
	HitFx.play("reveal", d.pos, m.color, true)
	Fx.floatText(d.pos + Vector3.new(0, 2, 0), m.id:upper() .. "!", m.color, 1.25)
	Sound.play("reveal")
end

handlers.gems = function(d)
	Fx.floatText(d.pos + Vector3.new(0, 4, 0), "+" .. d.amount .. " GEMS", C.purple, 0.9)
end

handlers.sell = function(d)
	-- bundles fly into the shredder, it rumbles and sprays grass, coins fountain out and fly to you (SellFx)
	SellFx.sell(d)
end

handlers.shred = function(d)
	-- someone else's sale (yours is drawn by handlers.sell)
	if d.pos and d.by ~= player.UserId and near(d.pos, 150) then
		SellFx.shred(d)
	end
end

handlers.telegraph = function(d)
	-- a red zone that fills up and pulses faster until the slam (BossFx)
	BossFx.telegraph(d)
	if near(d.pos, d.radius + 4) then
		Sound.play("warn")
	end
end

handlers.slam = function(d)
	-- dust all round the rim, flying dirt, a shock ring (BossFx); the closer you are, the harder it shakes
	BossFx.slam(d)
	if near(d.pos, d.radius + 40) then
		Fx.shake(if near(d.pos, d.radius + 8) then 10 else 6, 0.4)
		Sound.play("slam")
	end
end

handlers.knock = function(d)
	local r = myRoot()
	if r then
		r.AssemblyLinearVelocity = d.dir * 70 + Vector3.new(0, 40, 0)
	end
	Fx.shake(10, 0.4)
	BossFx.knock()
	Sound.play("hurt")
end

handlers.bossSpawn = function(d)
	-- the intro cinematic: the boss climbs out of the ground, title card, roar (skippable)
	BossFx.intro(d)
end

handlers.bossHit = function(d)
	-- impact, white flash, damage number, the top HP bar
	BossFx.hit(d)
	Sound.play("hit", 0.1)
end

handlers.bossDown = function(d)
	-- freeze, swell, pop, "BOSS DEFEATED!" + confetti
	BossFx.down(d)
end

-- personal boss reward: under the "BOSS DEFEATED!" card, or its own banner if that isn't up
handlers.reward = function(d)
	if BossFx.reward(d) then
		return
	end
	Fx.banner(d.title, C.green, 3, ("+%s coins   +%d gems"):format(Format.short(d.coins), d.gems))
	State.emit("flyCoins", 10)
end

-- The log gate rumbles and sinks into the ground, dust bursting along its foot (the server hides it after).
local function sinkGate(z: number)
	local world = workspace:FindFirstChild("World")
	local zoneFolder = world and world:FindFirstChild("Zone" .. z)
	local gate = zoneFolder and zoneFolder:FindFirstChild("Gate" .. z)
	if not gate then
		return
	end
	local parts = {}
	local gz = 0
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") and (p.Transparency < 1 or p:FindFirstChildOfClass("SurfaceGui")) then
			table.insert(parts, { part = p, cf = p.CFrame })
			gz = p.Position.Z
		end
	end
	if #parts == 0 then
		return
	end
	local function dust(x: number)
		local a = Instance.new("Attachment")
		a.Parent = workspace.Terrain
		a.Position = Vector3.new(x, 0.8, gz)
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Texture = FxIds.poof or "rbxasset://textures/particles/smoke_main.dds"
		if FxIds.poof then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
		e.Color = ColorSequence.new(Color3.fromRGB(225, 205, 170))
		e.LightInfluence = 0.4
		e.Size = NumberSequence.new(2.5, 5)
		e.Transparency = NumberSequence.new(0.1, 0.4)
		e.Lifetime = NumberRange.new(0.7, 1)
		e.Speed = NumberRange.new(3, 7)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = a
		e:Emit(2)
		Debris:AddItem(a, 1.5)
	end
	Fx.shake(2.5, 2.2)
	Sound.playAt("slam", 0.45)
	local start = os.clock()
	local nextDust = 0
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / 2.3)
		local sink = 14 * t * t * (3 - 2 * t)
		local k = (1 - t) * 0.25
		for _, e in parts do
			if e.part.Parent then
				e.part.CFrame = e.cf * CFrame.new((math.random() - 0.5) * k, -sink, (math.random() - 0.5) * k)
			end
		end
		if os.clock() > nextDust and t < 0.85 then
			nextDust = os.clock() + 0.12
			dust(math.random(-46, 46))
		end
		if t >= 1 then
			conn:Disconnect()
		end
	end)
end

handlers.zoneOpen = function(d)
	Fx.banner(("ZONE %d: %s"):format(d.zone, d.name:upper()), C.yellow, 2.6, "The gate is open!")
	Sound.play("purchase")
	sinkGate(d.zone)
end

handlers.runComplete = function(d)
	local time = if (d.time or 0) > 0 then "  Time " .. Format.clock(d.time) .. (if d.best then "  NEW BEST!" else "") else ""
	Fx.banner("RUN COMPLETE!", C.yellow, 10, ("+%d gems.%s Back to the lobby soon..."):format(d.gems or 0, time))
	Sound.play("victory")
	Confetti.burst(160)
	task.delay(0.8, Confetti.burst, 120)
	task.delay(1.8, Confetti.burst, 120)
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

-- blade tools draw a crescent swipe across the view; bare hands punch (ViewModel animates it)
local SLASH_COLOR = {
	Scissors = Color3.new(1, 1, 1),
	Sickle = Color3.fromRGB(225, 235, 255),
	MegaScythe = Color3.fromRGB(200, 150, 255),
}
State.on("swing", function()
	local id = heldToolId()
	HitFx.swing(id)
	local color = SLASH_COLOR[id or ""]
	if color then
		task.delay(0.08, HitFx.slash, color)
	end
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
