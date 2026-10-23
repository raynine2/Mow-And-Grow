-- The CLASSES kiosk's hologram (client only). Above the projector lens (server/RunBuilder puts a "HoloLens" part
-- with the ClassHolo attribute there) a see-through class card floats in a soft cone of light: the rarest class in
-- the booth's stock first, then the others, 3 s each, each card flipping in with a scan shimmer. Under the art:
-- the class name and its rarity, and the restock clock. Two thin rings turn slowly round the lens, a few stars drift
-- up through the light. When the stock rolls over: a white flash, a ring pulse out over the platform, a soft chime
-- and "NEW CARDS!" on the card. It only animates while you're within NEAR studs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local Assets = require(ReplicatedStorage:WaitForChild("VFXLib"):WaitForChild("Assets"))

local ClassHolo = {}

local NEAR = 90
local SLIDE = 3
local CARD = Vector2.new(4.2, 5.6) -- studs
local LIFT = 4.6 -- card centre above the lens
local HOLO = Color3.fromRGB(176, 140, 255)
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

local function part(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
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

-- the booth's stock, rarest first
local function stock(): ({ any }, number, number)
	local now = workspace:GetServerTimeNow()
	local window = math.floor(now / Config.STOCK_WINDOW)
	local list = {}
	for _, id in Config.classStock(window) do
		local c = Config.class(id)
		if c then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return (RANK[a.rarity] or 0) > (RANK[b.rarity] or 0)
	end)
	return list, window, Config.STOCK_WINDOW - (now % Config.STOCK_WINDOW)
end

type Face = { art: ImageLabel, name: TextLabel, rarity: TextLabel, clock: TextLabel, stroke: UIStroke, glow: ImageLabel, shimmer: Frame, flash: Frame, news: TextLabel, holder: Frame }

-- One side of the card (a SurfaceGui on the card part).
local function face(card: Part, side: Enum.NormalId): Face
	local gui = Instance.new("SurfaceGui")
	gui.Face = side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Brightness = 0.85
	gui.AlwaysOnTop = false
	gui.Parent = card
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = Color3.fromRGB(30, 18, 66)
	holder.BackgroundTransparency = 0.55
	holder.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Transparency = 0.35
	stroke.Color = HOLO
	stroke.Parent = holder
	-- a soft inner glow behind the art
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = Assets.Tex.Glow
	glow.ImageTransparency = 0.78
	glow.Size = UDim2.fromScale(1.2, 0.9)
	glow.Position = UDim2.fromScale(0.5, 0.36)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Parent = holder
	local art = Instance.new("ImageLabel")
	art.BackgroundTransparency = 1
	art.ScaleType = Enum.ScaleType.Crop
	art.Size = UDim2.new(1, -28, 0.6, 0)
	art.Position = UDim2.fromOffset(14, 14)
	art.ImageTransparency = 0.18
	art.Parent = holder
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 12)
	ac.Parent = art
	local function label(y: number, h: number, size: number, font: Enum.Font): TextLabel
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -20, 0, h)
		t.Position = UDim2.new(0, 10, 0.6, y)
		t.Font = font
		t.TextSize = size
		t.TextScaled = false
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = "" -- (not Roblox's default "Label" before the first card is set)
		t.Parent = holder
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(26, 12, 56)
		s.Thickness = 3
		s.Parent = t
		return t
	end
	local name = label(26, 50, 40, Enum.Font.LuckiestGuy)
	name.TextScaled = true
	local rarity = label(80, 34, 30, Enum.Font.GothamBold)
	local clock = label(132, 30, 24, Enum.Font.GothamBold)
	clock.TextColor3 = Color3.fromRGB(214, 200, 255)
	-- the scan shimmer: a bright band that sweeps down the card on every change
	local shimmer = Instance.new("Frame")
	shimmer.BackgroundColor3 = Color3.new(1, 1, 1)
	shimmer.BorderSizePixel = 0
	shimmer.Size = UDim2.new(1, 0, 0.18, 0)
	shimmer.Position = UDim2.fromScale(0, -0.2)
	shimmer.BackgroundTransparency = 0.82
	shimmer.Parent = holder
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sg.Rotation = 90
	sg.Parent = shimmer
	holder.ClipsDescendants = true
	-- fine scanlines over everything
	for i = 0, 22 do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0
		l.BackgroundColor3 = HOLO
		l.BackgroundTransparency = 0.88
		l.Size = UDim2.new(1, 0, 0, 2)
		l.Position = UDim2.fromScale(0, i / 23)
		l.Parent = holder
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 5
	flash.Parent = holder
	local news = Instance.new("TextLabel")
	news.BackgroundTransparency = 1
	news.Size = UDim2.new(1, 0, 0.22, 0)
	news.Position = UDim2.fromScale(0.5, 0.32)
	news.AnchorPoint = Vector2.new(0.5, 0.5)
	news.Font = Enum.Font.LuckiestGuy
	news.TextScaled = true
	news.Text = "NEW CARDS!"
	news.TextColor3 = Color3.fromRGB(255, 236, 140)
	news.TextTransparency = 1
	news.ZIndex = 6
	news.Parent = holder
	local ns = Instance.new("UIStroke")
	ns.Color = Color3.fromRGB(60, 24, 100)
	ns.Thickness = 4
	ns.Transparency = 1
	ns.Parent = news
	return { art = art, name = name, rarity = rarity, clock = clock, stroke = stroke, glow = glow, shimmer = shimmer, flash = flash, news = news, holder = holder }
end

type Holo = { lens: BasePart, folder: Folder, card: Part, faces: { Face }, rings: { Part }, beams: { Beam }, motes: ParticleEmitter, light: PointLight, chime: Sound, slide: number, slideAt: number, window: number, flip: number, lastChime: number, shown: string? }
local holos: { [BasePart]: Holo } = {}

local function ring(name: string, size: number, cf: CFrame, parent: Instance, transparency: number): Part
	local p = part(name, Vector3.new(size, 0.05, size), cf, parent)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = Assets.Tex.RingThin
	d.Color3 = HOLO
	d.Transparency = transparency
	d.Parent = p
	local d2 = d:Clone()
	d2.Face = Enum.NormalId.Bottom
	d2.Parent = p
	return p
end

local function build(lens: BasePart): Holo
	local folder = Instance.new("Folder")
	folder.Name = "ClassHolo"
	folder.Parent = workspace
	local base = CFrame.new(lens.Position) * (lens.CFrame - lens.Position)
	local card = part("Card", Vector3.new(CARD.X, CARD.Y, 0.05), base * CFrame.new(0, LIFT, 0), folder)
	local faces = { face(card, Enum.NormalId.Front), face(card, Enum.NormalId.Back) }
	-- the cone of light: two crossed beams from the lens up to the card's bottom edge
	local a0 = Instance.new("Attachment")
	a0.Parent = part("BeamBase", Vector3.one * 0.2, base * CFrame.new(0, 0.1, 0), folder)
	local top = part("BeamTop", Vector3.one * 0.2, base * CFrame.new(0, LIFT, 0), folder)
	local beams = {}
	for i = 1, 2 do
		local a1 = Instance.new("Attachment")
		a1.Parent = top
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = Assets.Tex.Glow
		b.TextureMode = Enum.TextureMode.Stretch
		b.Color = ColorSequence.new(Color3.fromRGB(230, 214, 255), HOLO)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.68), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 0.97) })
		b.Width0 = 1.1
		b.Width1 = CARD.X * 1.15
		b.LightEmission = 0.3
		b.LightInfluence = 0
		b.FaceCamera = i == 1
		b.Segments = 1
		b.Parent = top
		table.insert(beams, b)
	end
	-- the two turning rings round the lens
	local rings = {
		ring("RingA", 3.2, base * CFrame.new(0, 0.12, 0), folder, 0.55),
		ring("RingB", 2.2, base * CFrame.new(0, 0.55, 0), folder, 0.7),
	}
	-- stars drifting up through the light
	local moteHolder = part("Motes", Vector3.new(1.6, 0.2, 1.6), base * CFrame.new(0, 0.4, 0), folder)
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = Assets.Tex.Star4
	motes.Rate = 1.6
	motes.Lifetime = NumberRange.new(2.4, 3.4)
	motes.Speed = NumberRange.new(1.2, 2)
	motes.SpreadAngle = Vector2.new(12, 12)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-40, 40)
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.22), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	motes.Color = ColorSequence.new(Color3.fromRGB(255, 244, 210), HOLO)
	motes.LightEmission = 0.35
	motes.LightInfluence = 0
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.Parent = moteHolder
	local light = Instance.new("PointLight")
	light.Color = HOLO
	light.Brightness = 0.3
	light.Range = 8
	light.Parent = card
	local chime = Instance.new("Sound")
	chime.SoundId = Config.SOUNDS.rareChime or ""
	chime.Volume = 0.22
	chime.RollOffMaxDistance = 45
	chime.RollOffMinDistance = 8
	chime.Parent = card
	return { lens = lens, folder = folder, card = card, faces = faces, rings = rings, beams = beams, motes = motes, light = light, chime = chime, slide = 1, slideAt = 0, window = -1, flip = 0, lastChime = 0, shown = nil }
end

local function setClass(h: Holo, c)
	local rc = Config.RARITY_COLORS[c.rarity] or HOLO
	for _, f in h.faces do
		f.art.Image = Config.ICONS["scene_" .. c.id] or ""
		f.name.Text = c.name:upper()
		f.rarity.Text = string.upper(c.rarity)
		f.rarity.TextColor3 = rc
		f.stroke.Color = rc:Lerp(HOLO, 0.4)
		f.glow.ImageColor3 = rc
		-- the scan shimmer sweeps down
		f.shimmer.Position = UDim2.fromScale(0, -0.2)
		TweenService:Create(f.shimmer, TweenInfo.new(0.55, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(0, 1.05) }):Play()
	end
	h.light.Color = rc:Lerp(HOLO, 0.5)
	h.shown = c.id
end

local function newDeal(h: Holo)
	for _, f in h.faces do
		f.flash.BackgroundTransparency = 0.45
		TweenService:Create(f.flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		f.news.TextTransparency = 0
		;(f.news:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0
		f.news.Size = UDim2.new(0.4, 0, 0.09, 0)
		TweenService:Create(f.news, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0.22, 0) }):Play()
		task.delay(2.2, function()
			TweenService:Create(f.news, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(f.news:FindFirstChildOfClass("UIStroke") :: UIStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
	end
	-- a ring pulse out over the platform
	local base = h.rings[1].CFrame
	local pulse = ring("Pulse", 3, base, h.folder, 0.1)
	local d1, d2 = pulse:FindFirstChildOfClass("Decal") :: Decal, pulse:GetChildren()[2] :: Decal
	d1.Color3 = Color3.fromRGB(255, 240, 200)
	TweenService:Create(pulse, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(15, 0.05, 15) }):Play()
	for _, d in { d1, d2 } do
		TweenService:Create(d, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	end
	task.delay(1, pulse.Destroy, pulse)
	h.motes:Emit(14)
	h.chime.Volume = 0.45
	h.chime:Play()
	h.lastChime = os.clock()
end

local function setVisible(h: Holo, on: boolean)
	for _, f in h.faces do
		(f.holder.Parent :: SurfaceGui).Enabled = on
	end
	for _, b in h.beams do
		b.Enabled = on
	end
	for _, r in h.rings do
		for _, d in r:GetChildren() do
			if d:IsA("Decal") then
				d.Transparency = if on then (if r.Name == "RingA" then 0.55 else 0.7) else 1
			end
		end
	end
	h.motes.Enabled = on
	h.light.Enabled = on
end

local function scan()
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("ClassHolo") and not holos[d] then
			local h = build(d)
			holos[d] = h
			-- show a card straight away (the loop only fills it in once you're near)
			local list = stock()
			if list[1] then
				setClass(h, list[1])
			end
		end
	end
	for lens, h in holos do
		if not lens.Parent then
			h.folder:Destroy()
			holos[lens] = nil
		end
	end
end

task.spawn(function()
	while true do
		pcall(scan)
		task.wait(3)
	end
end)

local lastClock = 0
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam or next(holos) == nil then
		return
	end
	local now = os.clock()
	local list, window, left
	for _, h in holos do
		local near = (h.lens.Position - cam.CFrame.Position).Magnitude < NEAR
		if near ~= h.card:GetAttribute("On") then
			h.card:SetAttribute("On", near)
			setVisible(h, near)
		end
		if not near then
			continue
		end
		if not list then
			list, window, left = stock()
		end
		if #list == 0 then
			continue
		end
		if window ~= h.window then
			local first = h.window == -1
			h.window = window
			h.slide = 1
			h.slideAt = now
			setClass(h, list[1])
			if not first then
				newDeal(h)
			end
		elseif now - h.slideAt > SLIDE then
			h.slide = h.slide % #list + 1
			h.slideAt = now
			h.flip = now
		end
		-- the card flips edge-on and back as it changes (it swaps half way)
		local fk = now - h.flip
		local turn = 0
		if fk < 0.36 then
			-- 0 -> 90 degrees (edge on) -> swap -> back from -90 to 0
			local k = fk / 0.36
			turn = if k < 0.5 then k * 2 * math.rad(90) else -(1 - k) * 2 * math.rad(90)
			if fk >= 0.18 and h.shown ~= list[h.slide].id then
				setClass(h, list[h.slide])
			end
		end
		-- gentle float: bob, sway towards you a little, faint flicker
		local base = CFrame.new(h.lens.Position) * (h.lens.CFrame - h.lens.Position)
		local sway = math.sin(now * 0.7) * math.rad(14)
		h.card.CFrame = base * CFrame.new(0, LIFT + math.sin(now * 1.3) * 0.12, 0) * CFrame.Angles(0, sway + turn, 0)
		local flick = if math.random() < 0.01 then 0.06 else 0
		for _, f in h.faces do
			f.holder.BackgroundTransparency = 0.55 + flick
		end
		h.rings[1].CFrame = base * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, now * 0.4, 0)
		h.rings[2].CFrame = base * CFrame.new(0, 0.55 + math.sin(now * 1.1) * 0.08, 0) * CFrame.Angles(0, -now * 0.7, 0)
		-- the clock, a few times a second
		if now - lastClock > 0.25 then
			for _, f in h.faces do
				f.clock.Text = "NEW CARDS IN " .. Format.clock(left)
			end
		end
		-- a soft chime now and then while you're close
		if now - h.lastChime > 14 and (h.lens.Position - cam.CFrame.Position).Magnitude < 30 then
			h.lastChime = now
			h.chime.Volume = 0.18
			h.chime.PlaybackSpeed = 0.9 + math.random() * 0.2
			h.chime:Play()
		end
	end
	if now - lastClock > 0.25 then
		lastClock = now
	end
	local _ = dt
end)

return ClassHolo
