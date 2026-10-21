-- The big moments, so they feel like events and not just a line of text:
--   - Moments.reveal: a rare grass mutation shows itself. A light pillar shoots up in its colour with a ring and
--     rising sparks, and a magic chime plays (higher for rarer kinds). For your own find from Rainbow up, a short
--     slow-motion beat: the view pushes in and holds, the colours drain for a blink and flood back, the music
--     and ambience dip, your hands freeze, and a card names the find with its odds. Toxic and Galaxy add
--     confetti and a shake.
--   - Moments.areaCleared: an area is fully mowed. A reward card bounces in with its coins and gems counting up
--     (bloops climbing in pitch), confetti, a fanfare, a ring of sparkles round you, and the coins fly to the HUD.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local FxIds = require(Shared:WaitForChild("FxIds")) :: { [string]: string }
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local CameraView = require(script.Parent.CameraView)
local Confetti = require(script.Parent.Confetti)
local Soundscape = require(script.Parent.Soundscape)

local Moments = {}
local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "Moments"
folder.Parent = workspace

local TIER = { Golden = 1, Rainbow = 2, Diamond = 3, Toxic = 4, Galaxy = 5 }

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function glowPart(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- A flat ring on the ground at `pos` that spreads out to `radius` and fades.
local function groundRing(pos: Vector3, color: Color3, radius: number, time: number)
	local up = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local disc = glowPart(Vector3.new(0.1, 2, 2), up, color, Enum.PartType.Cylinder)
	disc.Transparency = 0.2
	tween(disc, time, { Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(disc, time + 0.1)
end

-- Sparks rising from `pos` (a one-off burst).
local function sparks(pos: Vector3, color: Color3, count: number, height: number)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = FxIds.spark or FxIds.glow or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 0.2)
	e.Lifetime = NumberRange.new(0.9, 1.6)
	e.Speed = NumberRange.new(height * 0.5, height)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, -height * 0.4, 0)
	e.Drag = 1.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 2)
end

-- The light pillar: a beam of the mutation's colour with a white core, shooting up and fading.
local function pillar(foot: Vector3, color: Color3, tier: number)
	local h = 30 + tier * 8
	local w = 1.6 + tier * 0.45
	local base = CFrame.new(foot) * CFrame.Angles(0, 0, math.rad(90))
	local beam = glowPart(Vector3.new(0.1, w, w), base, color, Enum.PartType.Cylinder)
	beam.Transparency = 0.25
	local core = glowPart(Vector3.new(0.1, w * 0.4, w * 0.4), base, Color3.new(1, 1, 1), Enum.PartType.Cylinder)
	core.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18 + tier * 3
	light.Brightness = 3
	light.Shadows = false
	light.Parent = beam
	local grow = 0.22
	for _, p in { beam, core } do
		tween(p, grow, { Size = Vector3.new(h, p.Size.Y, p.Size.Z), CFrame = base * CFrame.new(h / 2, 0, 0) }, Enum.EasingStyle.Quart)
	end
	local life = 1 + tier * 0.25
	task.delay(grow + 0.15, function()
		tween(beam, life, { Transparency = 1, Size = Vector3.new(h, w * 0.3, w * 0.3) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		tween(core, life * 0.8, { Transparency = 1, Size = Vector3.new(h, 0.05, 0.05) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		tween(light, life, { Brightness = 0 })
	end)
	Debris:AddItem(beam, grow + life + 0.4)
	Debris:AddItem(core, grow + life + 0.4)
end

-- The chance of a mutation, as "1 in N".
local function oneIn(id: string): string
	local total, w = 0, 0
	for _, m in Config.MUTATIONS do
		total += m.weight
		if m.id == id then
			w = m.weight
		end
	end
	if w <= 0 then
		return ""
	end
	return "1 in " .. Format.short(math.floor(total / w + 0.5))
end

-------------------------------------------------------------------------------------------------------------
-- the slow-motion beat
-------------------------------------------------------------------------------------------------------------
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "MomentGrade"
grade.Parent = Lighting

local function musicDip(time: number)
	local g = SoundService:FindFirstChild("MowALawnMusic") :: SoundGroup?
	if not g then
		return
	end
	local full = g:GetAttribute("FullVolume") or g.Volume
	g:SetAttribute("FullVolume", full)
	tween(g, 0.15, { Volume = full * 0.25 })
	task.delay(time, function()
		tween(g, 0.8, { Volume = full }, Enum.EasingStyle.Sine)
	end)
end

local function slowBeat(color: Color3, tier: number)
	local hold = 0.22 + tier * 0.06
	CameraView.focus(4 + tier * 1.6, 0.12, hold, 0.5)
	State.emit("hitstop", 0.1 + tier * 0.03) -- your hands hang in the air for a moment
	-- the colour drains for a blink, then floods back tinted with the find
	grade.Saturation = 0
	grade.TintColor = Color3.new(1, 1, 1)
	tween(grade, 0.12, { Saturation = -0.55 })
	task.delay(0.12 + hold * 0.5, function()
		grade.Saturation = 0.35
		grade.TintColor = Color3.new(1, 1, 1):Lerp(color, 0.25)
		tween(grade, 0.9, { Saturation = 0, TintColor = Color3.new(1, 1, 1) }, Enum.EasingStyle.Sine)
	end)
	musicDip(0.4 + hold)
	Soundscape.duck(0.7, 0.4 + hold)
end

-------------------------------------------------------------------------------------------------------------
-- cards (top middle of the screen)
-------------------------------------------------------------------------------------------------------------
local layer = Instance.new("Frame")
layer.Name = "Moments"
layer.BackgroundTransparency = 1
layer.Size = UDim2.fromScale(1, 1)
layer.ZIndex = 55
layer.Parent = UI.gui

local current: CanvasGroup? = nil

-- A card that bounces in at the top middle and fades away after `life` seconds. Returns it to fill.
local function card(width: number, height: number, life: number, y: number?): CanvasGroup
	if current then
		current:Destroy()
	end
	local g = Instance.new("CanvasGroup")
	g.Name = "MomentCard"
	g.BackgroundTransparency = 1
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, y or 0.3)
	g.Size = UDim2.fromOffset(width, height)
	g.ZIndex = 55
	g.Parent = layer
	current = g
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = g
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(life, function()
		if g.Parent then
			tween(g, 0.35, { GroupTransparency = 1 })
			tween(sc, 0.35, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(g, 0.4)
		end
	end)
	return g
end

-- A soft spinning glow behind a card.
local function rays(parent: GuiObject, color: Color3, size: number)
	local img = Instance.new("ImageLabel")
	img.Name = "Rays"
	img.BackgroundTransparency = 1
	img.Image = FxIds.flare or FxIds.glow or ""
	img.ImageColor3 = color
	img.ImageTransparency = 0.25
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromOffset(size, size)
	img.ZIndex = 54
	img.Parent = parent
	local spin
	spin = RunService.RenderStepped:Connect(function(dt)
		if not img.Parent then
			spin:Disconnect()
			return
		end
		img.Rotation += dt * 25
	end)
	return img
end

-------------------------------------------------------------------------------------------------------------
-- rare reveal
-------------------------------------------------------------------------------------------------------------
-- d: { pos, mut, by } from server/Field (pos = the clump's turf, half a stud above its ground).
function Moments.reveal(d: any)
	local m = Config.mutation(d.mut)
	local tier = TIER[d.mut or ""]
	if not m.color or not tier then
		return
	end
	local root = myRoot()
	local dist = if root then (root.Position - d.pos).Magnitude else 0
	if dist > 160 then
		return
	end
	local mine = d.by == player.UserId or (d.by == nil and dist < 14)
	local foot = d.pos - Vector3.new(0, 0.5, 0)
	pillar(foot, m.color, tier)
	groundRing(foot, m.color, 6 + tier * 2, 0.7)
	sparks(foot + Vector3.new(0, 1, 0), m.color, 10 + tier * 6, 14 + tier * 3)
	Sound.playAt("rareChime", 0.85 + tier * 0.09, if mine then 1 else 0.4)
	if not mine then
		return
	end
	if tier >= 3 then
		Sound.play("reveal", 0.05, 0.8)
	end
	if tier >= 2 then
		slowBeat(m.color, tier)
		local c = card(360, 96, 2.6 + tier * 0.2, 0.22)
		rays(c, m.color, 260)
		local name = UI.text(c, (m.id :: string):upper() .. " GRASS!", UDim2.new(1, 0, 0, 52), { pos = UDim2.fromOffset(0, 4), stroke = 3.5 })
		name.ZIndex = 56
		UI.gradient(name, m.color)
		local sub = UI.text(c, ("x%d VALUE   ·   %s"):format(m.mult or 1, oneIn(m.id)), UDim2.new(1, 0, 0, 28), { pos = UDim2.fromOffset(0, 60), stroke = 2.5 })
		sub.ZIndex = 56
	end
	if tier >= 4 then
		Confetti.burst(40 + (tier - 4) * 50)
		CameraView.shake(1.5, 0.3)
	end
end

-------------------------------------------------------------------------------------------------------------
-- area cleared
-------------------------------------------------------------------------------------------------------------
-- d: { title, coins, gems } from server/Run (kind = "area").
function Moments.areaCleared(d: any)
	local gold = UI.colors.yellow
	local c = card(440, 190, 2.9, 0.3) -- gone just as the next area's UNLOCKED banner arrives (3 s)
	rays(c, gold, 420)
	local panel = UI.frame({ size = UDim2.new(1, -40, 1, -50), pos = UDim2.fromOffset(20, 44), color = Color3.fromRGB(255, 246, 222), parent = c, radius = 18, outline = 3 })
	panel.ZIndex = 56
	local title = UI.text(c, d.title or "AREA CLEARED!", UDim2.new(1, 0, 0, 50), { pos = UDim2.fromOffset(0, 0), stroke = 4 })
	title.ZIndex = 58
	UI.gradient(title, gold)
	local rows = {}
	for i, row in { { "coin", d.coins or 0 }, { "gem", d.gems or 0 } } do
		local y = 22 + (i - 1) * 52
		local icon = UI.icon(panel, row[1], 40, UDim2.fromOffset(70, y))
		icon.ZIndex = 57
		for _, x in icon:GetDescendants() do
			if x:IsA("GuiObject") then
				x.ZIndex = 57
			end
		end
		local t = UI.text(panel, "+0", UDim2.fromOffset(220, 40), { pos = UDim2.fromOffset(122, y), align = Enum.TextXAlignment.Left, stroke = 3 })
		t.ZIndex = 57
		t.TextColor3 = if row[1] == "coin" then gold else UI.colors.purple
		table.insert(rows, { label = t, amount = row[2] })
	end
	-- fanfare, confetti, a ring of sparkles round you
	Sound.play("victory")
	Sound.playAt("rareChime", 1.2, 0.7)
	Confetti.burst(140)
	task.delay(0.5, Confetti.burst, 90)
	CameraView.kick(3)
	local root = myRoot()
	if root then
		local foot = root.Position - Vector3.new(0, 2.8, 0)
		groundRing(foot, gold, 16, 0.9)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			sparks(foot + Vector3.new(math.cos(a) * 4, 0.5, math.sin(a) * 4), gold, 6, 12)
		end
	end
	-- the numbers count up, each tick a bloop a step higher
	task.delay(0.35, function()
		local steps = 12
		for s = 1, steps do
			local k = s / steps
			local e = 1 - (1 - k) * (1 - k)
			for _, r in rows do
				r.label.Text = "+" .. Format.short(math.floor(r.amount * e + 0.5))
			end
			Sound.playAt("pickup", 1 + s * 0.06, 0.6)
			task.wait(0.07)
		end
		for _, r in rows do
			UI.bounce(r.label)
		end
		Sound.play("purchase")
		State.emit("flyCoins", 12)
	end)
end

return Moments
