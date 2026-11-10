-- BLACK FLASH (10 Nov 2026, owner: "make a chance for a black flash every time you punch a clump with fist and only
-- fist, make a cool animation with some of the audio that we added, use fx and vfx from the new pack if it fits").
-- Our own look: black lightning with a faint red halo bursting out of what you punched.
-- (10 Nov 23:20, owner: "the black flash feels like an epileptic attack, change it to a calmer thing and not a visual
-- block") CALM: no white pop, no full-screen colour, no tint of the picture, no shake, nothing flickering; only a
-- soft red glow creeping in at the screen's edges and out again, and a small title at the top.
-- The server rolls it (server/Run onSwing, Config.BLACK_FLASH: Bare Hands only) and sends Fx "blackFlash"
-- { pos, by, coins? (a clump: its coins x50, paid), boss? (a boss: the damage multiplier) } to everyone in the run.
--   yours:   a short hit-stop, the lightning, red rays, the pack's Sparks and a ground crack (InkCrack) when the pack
--            is in the place, a small camera kick, the edge glow, "BLACK FLASH! +N coins" / "x10 BOSS DAMAGE",
--            three of our sounds layered (punch, bossThud, zapStrike, pitched down)
--   others': the lightning and the sounds, smaller and quieter (within earshot)
-- Potato Mode: fewer bolts, no pack effects.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local CameraView = require(script.Parent.CameraView)
local PackFx = require(script.Parent.PackFx) :: any
local Potato = require(script.Parent.Potato) :: any

local player = Players.LocalPlayer

local RED = Color3.fromRGB(255, 28, 48)
local INK = Color3.fromRGB(6, 2, 8)
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

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

-- One jagged crack of black lightning from `from` along `dir` with a faint red halo and a fork or two (looked at in
-- Studio: a thick red glow drowned the black, so the halo is faint). It holds, then thins out and fades smoothly.
local function bolt(from: Vector3, dir: Vector3, len: number, width: number, life: number)
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = dir:Cross(side).Unit
	local parts: { Part } = {}
	local a = from
	local n = 7
	for i = 1, n do
		local t = i / n
		local jitter = (side * (math.random() - 0.5) + up * (math.random() - 0.5)) * len * 0.18
		local b = from + dir * len * t + jitter * (if i == n then 0.5 else 1)
		local w = width * (1 - t * 0.7)
		table.insert(parts, seg(a, b, w, INK, false, 0))
		table.insert(parts, seg(a, b, w * 1.2, RED, true, 0.9))
		if i > 1 and i < n and math.random() < 0.4 then
			local fd = (dir + side * (math.random() - 0.5) * 1.8 + up * (math.random() - 0.5)).Unit
			local fb = b + fd * len * 0.22
			table.insert(parts, seg(b, fb, w * 0.6, INK, false, 0))
			table.insert(parts, seg(b, fb, w * 0.75, RED, true, 0.9))
		end
		a = b
	end
	for _, p in parts do
		tween(p, life * 0.6, { Transparency = 1, Size = Vector3.new(p.Size.X * 0.2, p.Size.Y * 0.2, p.Size.Z) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, life * 0.4)
		Debris:AddItem(p, life + 0.15)
	end
end

-- A thin red ray growing out of the hit and fading.
local function ray(from: Vector3, dir: Vector3, len: number, life: number)
	local p = seg(from, from + dir * 0.1, 0.08, RED, true, 0.35)
	local goal = from + dir * len
	tween(p, life * 0.4, { Size = Vector3.new(0.08, 0.08, len), CFrame = CFrame.lookAt((from + goal) / 2, goal) }, Enum.EasingStyle.Quart)
	tween(p, life * 0.6, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, life * 0.4)
	Debris:AddItem(p, life + 0.15)
end

-- A direction mostly outward round the hit, a little up or down.
local function outward(): Vector3
	local a = math.random() * math.pi * 2
	return Vector3.new(math.cos(a), (math.random() - 0.35) * 0.9, math.sin(a)).Unit
end

local function world(pos: Vector3, mine: boolean)
	local potato = Potato.on == true
	local size = if mine then 1 else 0.7
	for _ = 1, (if potato then 3 elseif mine then 7 else 4) do
		bolt(pos, outward(), (7 + math.random() * 5) * size, 0.43 * size, 0.8)
	end
	if not potato then
		for _ = 1, (if mine then 6 else 3) do
			ray(pos, outward(), (8 + math.random() * 6) * size, 0.7)
		end
		-- the pack's pieces, when it's in the place (each call is a no-op otherwise)
		pcall(PackFx.play, "Sparks", pos, { scale = 0.9 * size, color = RED })
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { folder(), player.Character :: any }
		local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), rp)
		if hit then
			pcall(PackFx.play, "InkCrack", CFrame.new(hit.Position + Vector3.new(0, 0.05, 0)), { scale = 1.1 * size })
		end
	end
	-- a soft red light that swells and dies (no pop)
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
	light.Range = 16 * size
	light.Brightness = 0
	light.Parent = holder
	tween(light, 0.15, { Brightness = 2 })
	tween(light, 0.6, { Brightness = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0.2)
	Debris:AddItem(holder, 1)
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

-- A soft red glow at the screen's four edges, in and out (the middle stays clear).
local function edgeGlow()
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screenGui()
	local edges: { Frame } = {}
	for _, e in { { 0, 0, 1, 0.14, 90 }, { 0, 0.86, 1, 0.14, -90 }, { 0, 0, 0.1, 1, 0 }, { 0.9, 0, 0.1, 1, 180 } } do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = RED
		f.BackgroundTransparency = 1
		f.Position = UDim2.fromScale(e[1], e[2])
		f.Size = UDim2.fromScale(e[3], e[4])
		f.Parent = root
		local g = Instance.new("UIGradient")
		g.Rotation = e[5]
		g.Transparency = NumberSequence.new(0.35, 1)
		g.Parent = f
		table.insert(edges, f)
	end
	for _, f in edges do
		tween(f, 0.18, { BackgroundTransparency = 0.45 }, Enum.EasingStyle.Sine)
		tween(f, 0.7, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0.35)
	end
	Debris:AddItem(root, 1.2)
end

-- "BLACK FLASH!" small at the top, with what it gave you under it; fades in and out.
local function title(sub: string)
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.17)
	root.Size = UDim2.fromOffset(340, 64)
	root.Parent = screenGui()
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = root
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.62, 0)
	t.FontFace = HEAVY
	t.Text = "BLACK FLASH!"
	t.TextScaled = true
	t.TextColor3 = INK
	t.TextTransparency = 1
	t.Parent = root
	local s = Instance.new("UIStroke")
	s.Color = RED
	s.Thickness = 3
	s.Transparency = 1
	s.Parent = t
	local m = Instance.new("TextLabel")
	m.BackgroundTransparency = 1
	m.Position = UDim2.fromScale(0, 0.62)
	m.Size = UDim2.new(1, 0, 0.38, 0)
	m.FontFace = HEAVY
	m.Text = sub
	m.TextScaled = true
	m.TextColor3 = Color3.fromRGB(255, 225, 120)
	m.TextTransparency = 1
	m.Parent = root
	local s2 = Instance.new("UIStroke")
	s2.Color = INK
	s2.Thickness = 2
	s2.Transparency = 1
	s2.Parent = m
	tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	for _, l in { t, m } do
		tween(l, 0.15, { TextTransparency = 0 })
		tween(l, 0.4, { TextTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 1.2)
	end
	for _, st in { s, s2 } do
		tween(st, 0.15, { Transparency = 0 })
		tween(st, 0.4, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 1.2)
	end
	Debris:AddItem(root, 1.8)
end

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
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
	pcall(Sound.playAt, "punch", 0.72, 1.2 * vol)
	pcall(Sound.playAt, "bossThud", 1.2, 0.7 * vol)
	task.delay(0.03, function()
		pcall(Sound.playAt, "zapStrike", 0.78, 1.3 * vol)
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
		State.emit("hitstop", 0.08) -- the hand sticks for a beat
		edgeGlow()
		local sub = if tonumber(d.boss) then ("x%d BOSS DAMAGE"):format(tonumber(d.boss) :: number)
			elseif tonumber(d.coins) and (tonumber(d.coins) :: number) > 0 then "+" .. comma(tonumber(d.coins) :: number) .. " COINS"
			else ""
		title(sub)
		pcall(CameraView.kick, 3)
	end
end

State.on("fx", function(kind: string, d: any)
	if kind == "blackFlash" then
		play(d)
	end
end)

return { play = play }
