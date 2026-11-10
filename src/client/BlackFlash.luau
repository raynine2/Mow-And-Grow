-- BLACK FLASH (10 Nov 2026, owner: "make a 10% chance for a black flash every time you punch a clump with fist and
-- only fist, make a cool animation with some of the audio that we added, use fx and vfx from the new pack if it fits",
-- with a clip from another Roblox game as the feel he wants: a white pop, then the picture goes red with black
-- lightning bursting out). Our own take on that feel, our own shapes, colours and sounds.
-- The server rolls it (server/Run onSwing, Config.BLACK_FLASH: Bare Hands only, the punch must land on a clump, its
-- damage x mult) and sends Fx "blackFlash" { pos, by, mult } to everyone in the run.
--   yours:   a hit-stop, a white pop, an impact frame (the picture tinted red, contrast crushed) for a beat, black
--            lightning cracks with a red glow bursting out of the clump, red rays and sparks (the SoulShroud pack's
--            RedRift / InkCrack / Sparks when it's in the place), a camera punch and shake, BLACK FLASH! slammed on
--            screen, three of our sounds layered (punch, zapStrike, bossThud, pitched down)
--   others': the lightning and the sounds, smaller and quieter (within earshot)
-- "Reduce camera shake" (CalmCamera) gets a softer tint, no white pop and no shake; Potato Mode fewer bolts and no
-- pack effects.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config")) :: any
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local CameraView = require(script.Parent.CameraView)
local PackFx = require(script.Parent.PackFx) :: any
local Potato = require(script.Parent.Potato) :: any

local player = Players.LocalPlayer

local RED = Color3.fromRGB(255, 28, 48)
local DEEP = Color3.fromRGB(150, 0, 20)
local INK = Color3.fromRGB(6, 2, 8)
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local function calm(): boolean
	return player:GetAttribute("CalmCamera") == true
end

local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, delay: number?): Tween
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end

local fxFolder: Folder? = nil
local function folder(): Folder
	local f = fxFolder
	if not f or not f.Parent then
		f = Instance.new("Folder")
		f.Name = "BlackFlashFx"
		f.Parent = workspace
		fxFolder = f
	end
	return f :: Folder
end

local function seg(a: Vector3, b: Vector3, w: number, color: Color3, neon: boolean, alpha: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = alpha
	p.Size = Vector3.new(w, w, math.max((b - a).Magnitude, 0.05))
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = folder()
	return p
end

-- One jagged crack of black lightning from `from` along `dir`, glowing red round its core, with a fork or two.
local function bolt(from: Vector3, dir: Vector3, len: number, width: number, life: number)
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = dir:Cross(side).Unit
	local parts: { Part } = {}
	local a = from
	local n = 5
	for i = 1, n do
		local t = i / n
		local jitter = (side * (math.random() - 0.5) + up * (math.random() - 0.5)) * len * 0.28
		local b = from + dir * len * t + jitter * (if i == n then 0.5 else 1)
		local w = width * (1 - t * 0.65)
		table.insert(parts, seg(a, b, w, INK, false, 0))
		table.insert(parts, seg(a, b, w * 2.1, RED, true, 0.3))
		if i > 1 and i < n and math.random() < 0.5 then
			local fd = (dir + side * (math.random() - 0.5) * 1.8 + up * (math.random() - 0.5)).Unit
			local fb = b + fd * len * (0.2 + math.random() * 0.15)
			table.insert(parts, seg(b, fb, w * 0.6, INK, false, 0))
			table.insert(parts, seg(b, fb, w * 1.3, RED, true, 0.4))
		end
		a = b
	end
	for _, p in parts do
		-- they hold for a beat, then thin out and fade
		tween(p, life * 0.6, { Transparency = 1, Size = Vector3.new(p.Size.X * 0.15, p.Size.Y * 0.15, p.Size.Z) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, life * 0.4)
		Debris:AddItem(p, life + 0.15)
	end
end

-- A thin red ray shooting out of the hit and fading.
local function ray(from: Vector3, dir: Vector3, len: number, life: number)
	local p = seg(from, from + dir * 0.1, 0.12, RED, true, 0.1)
	local goal = from + dir * len
	tween(p, life * 0.35, { Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((from + goal) / 2, goal) }, Enum.EasingStyle.Quart)
	tween(p, life * 0.65, { Transparency = 1, Size = Vector3.new(0.02, 0.02, len * 1.15) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, life * 0.35)
	Debris:AddItem(p, life + 0.15)
end

-- A direction mostly outward round the hit, a little up or down.
local function outward(): Vector3
	local a = math.random() * math.pi * 2
	return Vector3.new(math.cos(a), (math.random() - 0.35) * 0.9, math.sin(a)).Unit
end

local function world(pos: Vector3, mine: boolean)
	local potato = Potato.on == true
	local bolts = if potato then 3 elseif mine then 9 else 5
	local size = if mine then 1 else 0.7
	for _ = 1, bolts do
		bolt(pos, outward(), (6 + math.random() * 5) * size, 0.45 * size, 0.55)
	end
	if not potato then
		for _ = 1, (if mine then 10 else 5) do
			ray(pos, outward(), (10 + math.random() * 8) * size, 0.45)
		end
		-- a second, smaller crackle a moment later (the lightning keeps biting)
		task.delay(0.12, function()
			for _ = 1, math.ceil(bolts / 2) do
				bolt(pos, outward(), (4 + math.random() * 3) * size, 0.3 * size, 0.4)
			end
		end)
		-- the pack's pieces, when it's in the place (each call is a no-op otherwise)
		pcall(PackFx.play, "RedRift", pos, { scale = 0.9 * size })
		pcall(PackFx.play, "Sparks", pos, { scale = 1.1 * size, color = RED })
		local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), (function()
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { folder(), player.Character :: any }
			return rp
		end)())
		if hit then
			pcall(PackFx.play, "InkCrack", CFrame.new(hit.Position + Vector3.new(0, 0.05, 0)), { scale = 1.2 * size })
		end
	end
	-- a red light that pops and dies
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = pos
	holder.Parent = folder()
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 22 * size
	light.Brightness = 6
	light.Parent = holder
	tween(light, 0.45, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.1)
	Debris:AddItem(holder, 0.7)
end

local gui: ScreenGui? = nil
local function screenGui(): ScreenGui
	local g = gui
	if not g or not g.Parent then
		g = Instance.new("ScreenGui")
		g.Name = "BlackFlash"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 60
		g.Parent = player:WaitForChild("PlayerGui")
		gui = g
	end
	return g :: ScreenGui
end

local function cover(color: Color3, alpha: number, life: number, z: number)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = screenGui()
	tween(f, life, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(f, life + 0.1)
end

local function title(mult: number)
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.3)
	root.Size = UDim2.fromOffset(700, 140)
	root.Rotation = -7
	root.ZIndex = 5
	root.Parent = screenGui()
	local scale = Instance.new("UIScale")
	scale.Scale = 1.9
	scale.Parent = root
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.72, 0)
	t.FontFace = HEAVY
	t.Text = "BLACK FLASH!"
	t.TextScaled = true
	t.TextColor3 = INK
	t.ZIndex = 6
	t.Parent = root
	local s = Instance.new("UIStroke")
	s.Color = RED
	s.Thickness = 5
	s.Parent = t
	local m = Instance.new("TextLabel")
	m.BackgroundTransparency = 1
	m.Position = UDim2.fromScale(0, 0.7)
	m.Size = UDim2.new(1, 0, 0.3, 0)
	m.FontFace = HEAVY
	m.Text = ("x%s DAMAGE"):format(tostring(mult))
	m.TextScaled = true
	m.TextColor3 = Color3.new(1, 1, 1)
	m.ZIndex = 6
	m.Parent = root
	local s2 = Instance.new("UIStroke")
	s2.Color = INK
	s2.Thickness = 3
	s2.Parent = m
	-- slammed in, a little shudder, then gone
	tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.16, function()
		for i = 1, 4 do
			root.Position = UDim2.new(0.5, math.random(-6, 6), 0.3, math.random(-5, 5))
			task.wait(0.03)
		end
		root.Position = UDim2.fromScale(0.5, 0.3)
	end)
	for _, l in { t, m } do
		tween(l, 0.35, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.85)
	end
	tween(s, 0.35, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.85)
	tween(s2, 0.35, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.85)
	tween(scale, 0.35, { Scale = 1.15 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.85)
	Debris:AddItem(root, 1.3)
end

-- The impact frame: the whole picture tinted red with the contrast crushed for a beat, then back.
local function impactFrame()
	local soft = calm()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BlackFlashGrade"
	cc.TintColor = if soft then Color3.fromRGB(255, 170, 175) else Color3.fromRGB(255, 70, 80)
	cc.Contrast = if soft then 0.25 else 0.85
	cc.Saturation = if soft then -0.2 else -0.65
	cc.Brightness = if soft then 0 else -0.06
	cc.Parent = Lighting
	tween(cc, 0.4, { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0, Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.2)
	Debris:AddItem(cc, 0.7)
	if not soft then
		cover(Color3.new(1, 1, 1), 0.1, 0.09, 1) -- the white pop
		task.delay(0.05, function()
			cover(DEEP, 0.55, 0.45, 2)
		end)
	else
		cover(DEEP, 0.8, 0.35, 2)
	end
end

local function sounds(mine: boolean, pos: Vector3)
	local vol = 1
	if not mine then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local d = if root then (root.Position - pos).Magnitude else 999
		if d > 120 then
			return
		end
		vol = 0.45 * (1 - d / 160)
	end
	pcall(Sound.playAt, "punch", 0.72, 1.25 * vol)
	pcall(Sound.playAt, "bossThud", 1.2, 0.8 * vol)
	task.delay(0.03, function()
		pcall(Sound.playAt, "zapStrike", 0.78, 1.5 * vol)
	end)
	task.delay(0.1, function()
		pcall(Sound.playAt, "zapStrike", 1.15, 0.7 * vol)
	end)
end

local function play(d: any)
	if type(d) ~= "table" or typeof(d.pos) ~= "Vector3" then
		return
	end
	local mine = d.by == player.UserId
	sounds(mine, d.pos)
	world(d.pos, mine)
	if mine then
		State.emit("hitstop", 0.1) -- the hand sticks in the clump for a beat
		impactFrame()
		title(tonumber(d.mult) or 2.5)
		pcall(CameraView.kick, 7)
		pcall(CameraView.shake, 6, 0.35)
		pcall(CameraView.buzz, 0.7, 0.2)
	end
end

State.on("fx", function(kind: string, d: any)
	if kind == "blackFlash" then
		play(d)
	end
end)

return { play = play }
