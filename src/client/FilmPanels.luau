-- FILM PANELS (owner, 28 Oct: "show it like JJK ... domain clash", "use impact frames that JJK / One Piece use",
-- "end credits, maybe take inspiration from JJK"): the films' anime pieces, drawn in 2D on this client only.
--   * THE CLASH (client/Intro): tall panels split by black brush strokes, each a close-up of one guardian lit in its
--     own colour (its 3D model in a ViewportFrame, the camera pushing in), slammed in one after another; then a
--     pink fracture rips across all of them and every eye snaps pink (the glitch got into them: it's not their
--     fault).
--   * IMPACT FRAMES (both films): for a split second the picture turns to flat silhouettes, black on white, then
--     black on a colour, with speed lines (copies of the subjects in a full-screen ViewportFrame, seen from the
--     film's own camera), while the film's clock sticks (a hit-stop). Rare on purpose: at most MAX_IMPACTS a film
--     and never closer than GAP seconds apart; "Reduce camera shake" gets a soft flash instead.
--   * PAGES (client/Ending's credits, an anime ending): calm panels of the party and the freed guardians in their
--     own colours, their names on plates, a heading over them; title and text pages for the rest.
-- Our own shapes and colours only (no show's characters, symbols, lettering or drawings). ViewportFrames don't draw
-- glow, particles or Highlights, so every glow here is a UI image behind the model.
--
--   FilmPanels.reset()                          a new film: the impact frames' budget starts again
--   FilmPanels.boss(z, rage?, height?) -> Still a guardian as a still model (FilmPanels.avatar(player), .copy(model))
--   FilmPanels.impact(subjects, opts?) -> bool  an impact frame (opts: color, hold, at = the lines' centre)
--   FilmPanels.clash(list) -> Clash             { slam(i), corrupt(), snap(), out(time), update(dt), destroy() }
--   FilmPanels.credits() -> Credits             { page(items, heading), title(big, small), text(heading, lines),
--                                                 update(dt), destroy() }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local BossMoves = require(Shared:WaitForChild("BossMoves"))
local BossRig = require(Shared:WaitForChild("BossRig"))
local Film = require(script.Parent.Film)
local IntroUi = require(script.Parent.IntroUi)
local Potato = require(script.Parent.Potato)

local FilmPanels = {}
local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local PINK = Color3.fromRGB(255, 40, 170) -- world 2's corruption (client/Corruption, client/Demon)
local HOT = Color3.fromRGB(255, 214, 240)
FilmPanels.PINK = PINK

-- (the game's own textures, as the CLASSES black hole uses them: a soft round glow, radial speed lines)
local TEX = {
	glow = "rbxassetid://125552447014366",
	lines = "rbxassetid://110976543463529",
}

local MAX_IMPACTS = 5
local GAP = 0.6
local Z_PANELS = 3 -- under the letterbox bars (4) and the subtitles / SKIP layer (5) of client/IntroUi
local Z_CREDITS = 4 -- (over the bars: the credits fill the screen)

local function calm(): boolean
	return player:GetAttribute("CalmCamera") == true
end

local function light(): boolean
	return Potato.on or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function frame(parent: Instance, name: string, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function image(parent: Instance, name: string, tex: string, color: Color3, transparency: number, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = tex
	i.ImageColor3 = color
	i.ImageTransparency = transparency
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	i.ZIndex = z
	i.Parent = parent
	return i
end

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local BRUSH = Font.new("rbxasset://fonts/families/PermanentMarker.json")

local function label(parent: Instance, text: string, font: Font, size: UDim2, pos: UDim2, z: number, stroke: number?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = font
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = WHITE
	t.Size = size
	t.Position = pos
	t.ZIndex = z
	t.Parent = parent
	if stroke and stroke > 0 then
		local s = Instance.new("UIStroke")
		s.Thickness = stroke
		s.Color = BLACK
		s.Parent = t
	end
	return t
end

-- the screen's height over its width (for strokes that lean)
local function aspect(gui: ScreenGui): number
	local a = gui.AbsoluteSize
	return if a.X > 0 then a.Y / a.X else 9 / 16
end

-------------------------------------------------------------------------------------------------------------
-- the models
-------------------------------------------------------------------------------------------------------------
export type Still = { model: Model, face: Vector3, eyes: { Vector3 }, height: number }

local function hex(h: string): Color3
	local ok, c = pcall(Color3.fromHex, h)
	return if ok then c else Color3.new(1, 0, 1)
end

-- A guardian (area z's boss) as a still model for a ViewportFrame: standing at the origin facing -Z, `height`
-- studs tall, in its own colours (rage: the corrupted colours and its rage parts, as in its fight).
function FilmPanels.boss(z: number, rage: boolean?, height: number?): Still?
	local moves = BossMoves.get(z)
	local rig = moves and BossRig.load(moves.rig)
	local models = ReplicatedStorage:FindFirstChild("BossModels")
	local template = models and moves and models:FindFirstChild(moves.rig)
	if not rig or not template then
		return nil
	end
	local h = height or 10
	local scale = h / math.max(rig.bounds[2][2] or 7, 0.1)
	local model = template:Clone() :: Model
	model:ScaleTo(scale)
	model:PivotTo(CFrame.new())
	local byName = {}
	for _, info in rig.parts do
		byName[info.n] = info
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			local info = byName[d.Name]
			if info then
				local looks = rig.looks[info.mat]
				local lk = looks and (if rage then looks.r else looks.n)
				if lk then
					d.Color = hex(lk.c)
					pcall(function()
						d.Material = (Enum.Material :: any)[lk.m]
					end)
					d.Transparency = lk.t or 0
				end
				if info.rage and not rage then
					d.Transparency = 1
				end
			end
		elseif d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	local eyes: { Vector3 } = {}
	local head: Vector3? = nil
	for _, a in rig.atts do
		local p = Vector3.new(a.p[1], a.p[2], a.p[3]) * scale
		if a.n == "att_eye" or string.sub(a.n, 1, 8) == "att_eye_" then
			table.insert(eyes, p)
		elseif a.n == "att_head_center" then
			head = p
		end
	end
	local face = head
	if not face and #eyes > 0 then
		local sum = Vector3.zero
		for _, e in eyes do
			sum += e
		end
		face = sum / #eyes
	end
	return { model = model, face = face or Vector3.new(0, h * 0.8, 0), eyes = eyes, height = h }
end

-- A copy of a player's avatar (as it stands right now), at the origin facing -Z.
function FilmPanels.avatar(p: Player): Still?
	local char = p.Character
	if not char then
		return nil
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, clone = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not clone then
		return nil
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	clone:PivotTo(CFrame.new())
	local head = clone:FindFirstChild("Head")
	local face = if head and head:IsA("BasePart") then head.Position + Vector3.new(0, 0.05, 0) else Vector3.new(0, 1.5, 0)
	return { model = clone, face = face, eyes = {}, height = 5.2 }
end

-- A copy of any model (the Mayor) at the origin, facing where it faced; `face` is a point on it (world space).
function FilmPanels.copy(model: Model, face: Vector3, height: number): Still?
	local ok, clone = pcall(function()
		return model:Clone()
	end)
	if not ok or not clone then
		return nil
	end
	local pivot = model:GetPivot()
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	clone:PivotTo(CFrame.new())
	return { model = clone, face = pivot:PointToObjectSpace(face), eyes = {}, height = height }
end

-------------------------------------------------------------------------------------------------------------
-- impact frames
-------------------------------------------------------------------------------------------------------------
local impacts = 0
local lastImpact = -math.huge

function FilmPanels.reset()
	impacts = 0
	lastImpact = -math.huge
end

export type ImpactOpts = { color: Color3?, hold: number?, at: Vector3? }

-- An impact frame: `subjects` (models or parts in the world) as flat black silhouettes, seen from the film's camera
-- right now, on white and then on `color` (default the corruption's pink), with speed lines bursting from `at` (a
-- point in the world; default the first subject). The film's clock sticks for the length of it. Returns false
-- when only a soft flash stood in (too soon after the last, the film's budget spent, or "Reduce camera shake").
function FilmPanels.impact(subjects: { Instance? }, opts: ImpactOpts?): boolean
	local o = opts or {}
	local gui = IntroUi.gui()
	local cam = workspace.CurrentCamera
	local now = os.clock()
	if calm() or not gui or not cam or impacts >= MAX_IMPACTS or now - lastImpact < GAP then
		Film.flash(WHITE, 0.3, 0.25)
		return false
	end
	impacts += 1
	lastImpact = now
	local hold = o.hold or 0.14
	local color = o.color or PINK
	local root = Instance.new("Frame")
	root.Name = "ImpactFrame"
	root.BackgroundColor3 = WHITE
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Z_PANELS
	-- where the speed lines burst from: the subject on screen
	local centre = UDim2.fromScale(0.5, 0.5)
	local first = subjects[1]
	local at = o.at or (if first and first:IsA("Model") then first:GetPivot().Position elseif first and first:IsA("BasePart") then first.Position else nil)
	if at then
		local sp, onScreen = cam:WorldToViewportPoint(at)
		if onScreen then
			local vs = cam.ViewportSize
			centre = UDim2.fromScale(sp.X / math.max(vs.X, 1), sp.Y / math.max(vs.Y, 1))
		end
	end
	local lines = image(root, "Lines", TEX.lines, BLACK, 0, 1)
	lines.SizeConstraint = Enum.SizeConstraint.RelativeXX
	lines.Size = UDim2.fromScale(2.2, 2.2)
	lines.Position = centre
	lines.Rotation = math.random(0, 359)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Silhouettes"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.ImageColor3 = BLACK
	vp.Ambient = WHITE
	vp.LightColor = WHITE
	vp.ZIndex = 2
	vp.Parent = root
	local vcam = Instance.new("Camera")
	vcam.CFrame = cam.CFrame
	vcam.FieldOfView = cam.FieldOfView
	vcam.Parent = vp
	vp.CurrentCamera = vcam
	for _, s in subjects do
		if s and s.Parent then
			local ok, c = pcall(function()
				return (s :: Instance):Clone()
			end)
			if ok and c then
				c.Parent = vp
			end
		end
	end
	root.Parent = gui
	Film.freeze(hold)
	-- the second half: black on the colour, the lines turned white, the frame knocked sideways
	task.delay(hold * 0.5, function()
		if root.Parent then
			root.BackgroundColor3 = color
			lines.ImageColor3 = WHITE
			lines.Rotation += 23
			root.Position = UDim2.fromOffset(math.random(-14, 14), math.random(-8, 8))
		end
	end)
	task.delay(hold, function()
		root:Destroy()
		if Film.playing then
			Film.flash(WHITE, 0.45, 0.22)
		end
	end)
	return true
end

-------------------------------------------------------------------------------------------------------------
-- panels
-------------------------------------------------------------------------------------------------------------
type Panel = {
	root: Frame,
	vp: ViewportFrame,
	cam: Camera,
	eyeVp: ViewportFrame?,
	eyeCam: Camera?,
	glow: ImageLabel,
	lines: ImageLabel,
	wash: Frame,
	flash: Frame,
	still: Still?,
	color: Color3,
	fov: number,
	dist: number,
	focus: Vector3,
	side: number,
	drift: number,
	push: number,
	t: number,
	spin: number,
	silhouette: boolean,
	static: boolean, -- (the camera holds: the ViewportFrame draws once)
}

-- One panel from x0 to x1 (shares of the width), dark with a wash of `color`, its glow behind the face. `calmLook`:
-- the credits' soft pastel version (no speed lines).
local function newPanel(parent: Instance, x0: number, x1: number, color: Color3, calmLook: boolean?): Panel
	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.BackgroundColor3 = if calmLook then color:Lerp(WHITE, 0.55) else color:Lerp(BLACK, 0.62)
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Position = UDim2.fromScale(x0, 0)
	root.Size = UDim2.fromScale(x1 - x0, 1)
	root.ZIndex = 1
	root.Parent = parent
	local wash = frame(root, "Wash", if calmLook then WHITE else color, 0, 1)
	local g = Instance.new("UIGradient")
	g.Rotation = -90 -- (0 at the bottom)
	g.Transparency = if calmLook
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.75), NumberSequenceKeypoint.new(1, 0.35) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.62), NumberSequenceKeypoint.new(1, 0.95) })
	g.Parent = wash
	local lines = image(root, "Lines", TEX.lines, color:Lerp(WHITE, 0.45), if calmLook then 1 else 0.68, 2)
	lines.SizeConstraint = Enum.SizeConstraint.RelativeYY
	lines.Size = UDim2.fromScale(2.6, 2.6)
	lines.Position = UDim2.fromScale(0.5, 0.4)
	local glow = image(root, "Glow", TEX.glow, if calmLook then WHITE else color, if calmLook then 0.25 else 0.05, 3)
	glow.SizeConstraint = Enum.SizeConstraint.RelativeYY
	glow.Size = UDim2.fromScale(1.1, 1.1)
	glow.Position = UDim2.fromScale(0.5, 0.4)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "View"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = if calmLook then Color3.fromRGB(150, 150, 160) else color:Lerp(Color3.fromRGB(60, 60, 70), 0.55)
	vp.LightColor = if calmLook then WHITE else WHITE:Lerp(color, 0.3)
	vp.LightDirection = Vector3.new(-0.55, -0.75, 1)
	vp.ZIndex = 4
	vp.Parent = root
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	-- the dark top and bottom of the panel
	local shade = frame(root, "Shade", BLACK, 0, 6)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = if calmLook
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.45) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.24, 1), NumberSequenceKeypoint.new(0.76, 1), NumberSequenceKeypoint.new(1, 0.1) })
	sg.Parent = shade
	local flash = frame(root, "Flash", WHITE, 1, 7)
	return {
		root = root,
		vp = vp,
		cam = cam,
		eyeVp = nil,
		eyeCam = nil,
		glow = glow,
		lines = lines,
		wash = wash,
		flash = flash,
		still = nil,
		color = color,
		fov = 30,
		dist = 10,
		focus = Vector3.zero,
		side = 0,
		drift = 0,
		push = 0.14,
		t = 0,
		spin = if calmLook then 0 else 14,
		silhouette = false,
		static = false,
	}
end

-- where the panel's camera is: in front of the face (the model faces -Z), turned `side` degrees, pushing in
local function place(p: Panel)
	local k = math.clamp(p.t / 4.5, 0, 1)
	local e = 1 - (1 - k) * (1 - k)
	local d = p.dist * (1 + p.push * 0.5 - p.push * e)
	local yaw = math.rad(p.side + p.drift * e)
	local cf = CFrame.lookAt(p.focus + Vector3.new(math.sin(yaw) * d, d * 0.06, -math.cos(yaw) * d), p.focus)
	p.cam.CFrame = cf
	local ec = p.eyeCam
	if ec then
		ec.CFrame = cf
	end
end

type StillOpts = { silhouette: boolean?, side: number?, drift: number?, span: number?, low: number? }

-- Put `still` in the panel (the last one goes): `span` studs of it in view round its face, the face about 40% down.
local function setStill(p: Panel, still: Still?, o: StillOpts?)
	local opts = o or {}
	if p.still then
		p.still.model:Destroy()
	end
	if p.eyeVp then
		p.eyeVp:Destroy()
		p.eyeVp, p.eyeCam = nil, nil
	end
	p.still = still
	if not still then
		return
	end
	local span = opts.span or still.height * 0.42
	p.dist = span / (2 * math.tan(math.rad(p.fov / 2)))
	p.focus = still.face - Vector3.new(0, span * (opts.low or 0.12), 0)
	p.side = opts.side or 0
	p.drift = opts.drift or 0
	p.silhouette = opts.silhouette == true
	p.vp.ImageColor3 = if p.silhouette then BLACK else WHITE
	still.model.Parent = p.vp
	place(p)
end

-- Eyes that glow `color` over the model (drawn on top: they show on a silhouette too).
local function lightEyes(p: Panel, color: Color3)
	local still = p.still
	if not still or #still.eyes == 0 then
		return
	end
	if p.eyeVp then
		p.eyeVp:Destroy()
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Eyes"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = WHITE
	vp.LightColor = WHITE
	vp.ZIndex = 5
	local cam = Instance.new("Camera")
	cam.FieldOfView = p.fov
	cam.CFrame = p.cam.CFrame
	cam.Parent = vp
	vp.CurrentCamera = cam
	local holder = Instance.new("Model")
	-- (Studio's test, 28 Oct: round balls with a white middle looked like googly eyes.) Narrow almonds slanted down
	-- toward the middle of the face, a white-hot slit in each and a thin streak of light through it, all facing the
	-- panel's camera. ViewportFrames draw no glow, so the streak stands in for it.
	local view = cam.CFrame
	local mid = view:PointToObjectSpace(still.face).X
	local w = still.height * 0.07
	local function piece(name: string, at: Vector3, rot: CFrame, size: Vector3, c: Color3, round: boolean, transparency: number)
		local b = Instance.new("Part")
		b.Name = name
		b.Anchored = true
		b.Material = Enum.Material.Neon
		b.Color = c
		b.Transparency = transparency
		b.Size = size
		b.CFrame = CFrame.new(at) * rot
		if round then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = b
		end
		b.Parent = holder
	end
	for _, e in still.eyes do
		local slant = if view:PointToObjectSpace(e).X < mid then -0.3 else 0.3
		local rot = view.Rotation * CFrame.Angles(0, 0, slant)
		local front = e - view.LookVector * (still.height * 0.03)
		piece("Eye", front, rot, Vector3.new(w, w * 0.4, w * 0.3), color, true, 0)
		piece("Slit", front - view.LookVector * (w * 0.08), rot, Vector3.new(w * 0.55, w * 0.12, w * 0.3), HOT, true, 0)
		piece("Streak", front - view.LookVector * (w * 0.12), rot, Vector3.new(w * 3.2, w * 0.05, 0.02), HOT, false, 0.25)
	end
	holder.Parent = vp
	vp.Parent = p.root
	p.eyeVp, p.eyeCam = vp, cam
end

local function stepPanel(p: Panel, dt: number)
	p.t += dt
	if not p.static then
		place(p)
	end
	if p.spin ~= 0 then
		p.lines.Rotation += p.spin * dt
	end
	p.glow.Size = UDim2.fromScale(1.1 + 0.05 * math.sin(p.t * 3.1), 1.1 + 0.05 * math.sin(p.t * 3.1))
end

-- A black brush stroke down the screen at x (share of the width), leaning `deg` degrees (clockwise: its top to the
-- right): a wide stroke, a second one a touch off, and ragged bristles off its edges.
local function slash(parent: Instance, x: number, deg: number, width: number, ratio: number, rng: Random, z: number)
	local tilt = math.tan(math.rad(deg))
	for i, w in { width, width * 0.8 } do
		local main = Instance.new("Frame")
		main.Name = "Stroke"
		main.AnchorPoint = Vector2.new(0.5, 0.5)
		main.BackgroundColor3 = BLACK
		main.BorderSizePixel = 0
		main.Position = UDim2.fromScale(x + (i - 1) * width * 0.18, 0.5)
		main.Size = UDim2.fromScale(w, 1.3)
		main.Rotation = deg + (i - 1) * 1.2
		main.ZIndex = z
		main.Parent = parent
	end
	for i = 1, 9 do
		local y = rng:NextNumber(0.03, 0.97)
		local side = if i % 2 == 0 then 1 else -1
		local cx = x + (0.5 - y) * ratio * tilt
		local w = width * rng:NextNumber(0.2, 0.55)
		local b = Instance.new("Frame")
		b.Name = "Bristle"
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.BackgroundColor3 = BLACK
		b.BorderSizePixel = 0
		b.Position = UDim2.fromScale(cx + side * (width * 0.5 + w * 0.15), y)
		b.Size = UDim2.fromScale(w, rng:NextNumber(0.04, 0.16))
		b.Rotation = deg + rng:NextNumber(-5, 5)
		b.ZIndex = z
		b.Parent = parent
	end
end

-------------------------------------------------------------------------------------------------------------
-- the clash
-------------------------------------------------------------------------------------------------------------
export type Clash = {
	slam: (i: number) -> (),
	caption: (text: string) -> (),
	corrupt: () -> (),
	snap: () -> (),
	out: (time: number) -> (),
	update: (dt: number) -> (),
	destroy: () -> (),
}

local function guardianColor(z: number): Color3
	local def = Config.ZONES[z]
	local b = def and def.boss
	return if b and b.color then b.color else WHITE
end

-- Three tall panels, left to right, one guardian each (`list`: { z, silhouette }), hidden until slammed in.
function FilmPanels.clash(list: { { z: number, silhouette: boolean? } }): Clash?
	local gui = IntroUi.gui()
	if not gui then
		return nil
	end
	local root = frame(gui, "Clash", BLACK, 0, Z_PANELS)
	local ratio = aspect(gui)
	local rng = Random.new()
	local edges = { 0, 0.345, 0.655, 1 }
	local panels: { Panel } = {}
	local shown: { boolean } = {}
	-- (Studio's test and the owner, 28 Oct evening: at 4.4 studs the King's face filled his panel to the edges and the
	-- shadows either side were black blobs) the middle one: his head and crown; the outer two: head and shoulders,
	-- so their shapes read against their colour
	local spans: { number } = {}
	for i, item in list do
		local p = newPanel(root, edges[i], edges[i + 1], guardianColor(item.z))
		p.root.Visible = false
		spans[i] = if item.silhouette then 8 else 6.2
		-- the outer two turned in toward the middle, the middle one square on
		setStill(p, FilmPanels.boss(item.z, false, 10), { silhouette = item.silhouette, side = (i - 2) * -22, drift = (i - 2) * 6, span = spans[i], low = if item.silhouette then 0.06 else 0.1 })
		panels[i] = p
	end
	slash(root, 0.345, 7, 0.052, ratio, rng, 8)
	slash(root, 0.655, 7, 0.052, ratio, rng, 8)
	local tearUntil = 0
	local kick = 0 -- the whole picture shaking (pixels), decays
	local handle = {} :: Clash

	function handle.slam(i: number)
		local p = panels[i]
		if not p then
			return
		end
		shown[i] = true
		p.root.Visible = true
		local from = if i % 2 == 1 then -1.05 else 1.05
		p.root.Position = UDim2.fromScale(p.root.Position.X.Scale, from)
		tween(p.root, 0.13, { Position = UDim2.fromScale(p.root.Position.X.Scale, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		p.flash.BackgroundTransparency = 0
		task.delay(0.13, function()
			tween(p.flash, 0.3, { BackgroundTransparency = 1 })
			kick = 14
		end)
	end

	-- The narration in a box of its own, as a manga's caption (owner, 28 Oct evening: the line floating over the panels
	-- looked "bugged with the text"): white with a black edge, top left under the letterbox bar, tilted a little; it
	-- pops in and goes with the panels.
	function handle.caption(text: string)
		local old = root:FindFirstChild("Caption")
		if old then
			old:Destroy()
		end
		local box = frame(root, "Caption", WHITE, 0, 12)
		box.AnchorPoint = Vector2.new(0, 0)
		box.Position = UDim2.fromScale(0.03, IntroUi.bar() + 0.03)
		box.Size = UDim2.fromScale(0.44, 0.085)
		box.Rotation = -1.5
		local edge = Instance.new("UIStroke")
		edge.Thickness = 3
		edge.Color = BLACK
		edge.Parent = box
		local t = label(box, text, BOLD, UDim2.fromScale(0.92, 0.62), UDim2.fromScale(0.04, 0.19), 13, 0)
		t.TextColor3 = BLACK
		t.TextXAlignment = Enum.TextXAlignment.Left
		local sc = Instance.new("UIScale")
		sc.Scale = 0.6
		sc.Parent = box
		tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	-- one straight piece of the crack from pa to pb (pixels), `thick` wide, drawn after `delay` s
	local function crackBit(pa: Vector2, pb: Vector2, thick: number, delay: number)
		local mid = (pa + pb) / 2
		local len = (pb - pa).Magnitude
		local ang = math.deg(math.atan2(pb.Y - pa.Y, pb.X - pa.X))
		task.delay(delay, function()
			if not root.Parent then
				return
			end
			for _, s in { { PINK, thick }, { HOT, math.max(2, thick / 3) } } do
				local f = Instance.new("Frame")
				f.Name = "Fracture"
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.BackgroundColor3 = s[1]
				f.BorderSizePixel = 0
				f.Position = UDim2.fromOffset(mid.X, mid.Y)
				f.Size = UDim2.fromOffset(len + s[2], s[2])
				f.Rotation = ang
				f.ZIndex = 9
				f.Parent = root
			end
		end)
	end

	-- the glitch gets in: a pink fracture rips across every panel, the picture tears, the glows turn pink, and the
	-- lit ones change to their corrupted colours. (Owner, 28 Oct evening, a screenshot of it: the crack ran straight
	-- through the King's eyes.) The crack runs low, under the faces, falling a little left to right, with branches.
	function handle.corrupt()
		local n = 10
		local pts = {}
		for i = 0, n do
			table.insert(pts, Vector2.new(-0.02 + i / n * 1.04, 0.6 + i / n * 0.08 + rng:NextNumber(-0.045, 0.045)))
		end
		local abs = root.AbsoluteSize
		local w, h = math.max(abs.X, 1), math.max(abs.Y, 1)
		for i = 1, n do
			local a, b = pts[i], pts[i + 1]
			local d = math.abs(i - n / 2 - 0.5)
			crackBit(Vector2.new(a.X * w, a.Y * h), Vector2.new(b.X * w, b.Y * h), 9, d * 0.025)
			-- every other joint sends a thin branch off up or down
			if i % 2 == 0 then
				local from = Vector2.new(b.X * w, b.Y * h)
				local dir = Vector2.new(rng:NextNumber(0.4, 1) * (if rng:NextNumber() < 0.5 then -1 else 1), if i % 4 == 0 then -1 else 1).Unit
				local len = h * rng:NextNumber(0.08, 0.16)
				local kink = from + dir * len * 0.5 + Vector2.new(rng:NextNumber(-1, 1), 0) * len * 0.15
				crackBit(from, kink, 5, d * 0.025 + 0.05)
				crackBit(kink, kink + dir * len * 0.5, 3, d * 0.025 + 0.08)
			end
		end
		tearUntil = os.clock() + 0.35
		kick = 18
		for i, p in panels do
			tween(p.glow, 0.25, { ImageColor3 = PINK })
			tween(p.lines, 0.25, { ImageColor3 = HOT })
			tween(p.wash, 0.25, { BackgroundColor3 = PINK })
			p.spin = 40
			if not p.silhouette and list[i] then
				setStill(p, FilmPanels.boss(list[i].z, true, 10), { side = p.side, drift = p.drift, span = spans[i], low = 0.1 })
			end
		end
	end

	-- every eye snaps pink; for a blink the panels go to flat black silhouettes on white, then on pink
	function handle.snap()
		for _, p in panels do
			lightEyes(p, PINK)
		end
		local saved = {}
		for i, p in panels do
			saved[i] = p.root.BackgroundColor3
			p.root.BackgroundColor3 = WHITE
			p.wash.Visible = false
			p.glow.Visible = false
			p.lines.ImageColor3 = BLACK
			p.vp.ImageColor3 = BLACK
		end
		root.BackgroundColor3 = WHITE
		kick = 24
		task.delay(0.07, function()
			for _, p in panels do
				p.root.BackgroundColor3 = PINK
				p.lines.ImageColor3 = WHITE
			end
			root.BackgroundColor3 = PINK
		end)
		task.delay(0.15, function()
			root.BackgroundColor3 = BLACK
			for i, p in panels do
				p.root.BackgroundColor3 = saved[i]
				p.wash.Visible = true
				p.glow.Visible = true
				p.lines.ImageColor3 = HOT
				p.vp.ImageColor3 = if p.silhouette then BLACK else WHITE
				p.flash.BackgroundTransparency = 0.2
				tween(p.flash, 0.35, { BackgroundTransparency = 1 })
			end
		end)
	end

	-- off they fly: the outer panels out to the sides, the middle one up, the black behind fading to the film
	function handle.out(time: number)
		for i, p in panels do
			local x = p.root.Position.X.Scale
			local goal = if i == 1 then UDim2.fromScale(x - 0.5, 0) elseif i == #panels then UDim2.fromScale(x + 0.5, 0) else UDim2.fromScale(x, -1.1)
			tween(p.root, time, { Position = goal }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		end
		for _, d in root:GetChildren() do
			if d:IsA("Frame") and d.Name ~= "Panel" then
				tween(d, time * 0.7, { BackgroundTransparency = 1 })
			end
		end
		local cap = root:FindFirstChild("Caption")
		if cap then
			for _, d in cap:GetDescendants() do
				if d:IsA("TextLabel") then
					tween(d, time * 0.6, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					tween(d, time * 0.6, { Transparency = 1 })
				end
			end
		end
		tween(root, time, { BackgroundTransparency = 1 })
		task.delay(time + 0.05, function()
			handle.destroy()
		end)
	end

	function handle.update(dt: number)
		if not root.Parent then
			return
		end
		local tearing = os.clock() < tearUntil
		for i, p in panels do
			if shown[i] then
				stepPanel(p, dt)
				-- the picture tears: the panels' contents jump sideways for a frame or two
				p.vp.Position = if tearing and math.random() < 0.5 then UDim2.fromOffset(math.random(-16, 16), 0) else UDim2.new()
			end
		end
		if kick > 0.5 then
			root.Position = UDim2.fromOffset((math.random() - 0.5) * kick, (math.random() - 0.5) * kick * 0.6)
			kick *= math.exp(-dt * 10)
		elseif kick > 0 then
			kick = 0
			root.Position = UDim2.new()
		end
	end

	function handle.destroy()
		root:Destroy()
	end

	return handle
end

-------------------------------------------------------------------------------------------------------------
-- the credits: an anime ending's pages
-------------------------------------------------------------------------------------------------------------
export type PageItem = { still: Still?, color: Color3, name: string, sub: string?, side: number?, span: number?, low: number?, hold: boolean? }

export type Credits = {
	page: (items: { PageItem }, heading: string) -> (),
	title: (big: string, small: string?) -> (),
	text: (heading: string, lines: { string }) -> (),
	update: (dt: number) -> (),
	destroy: () -> (),
}

-- The credits' screen (over the whole picture). Each new page slides the last one off to the left and comes in
-- from the right; slow white specks drift up over everything.
function FilmPanels.credits(): Credits?
	local gui = IntroUi.gui()
	if not gui then
		return nil
	end
	local root = frame(gui, "Credits", Color3.fromRGB(14, 12, 20), 0, Z_CREDITS)
	root.ClipsDescendants = true
	local ratio = aspect(gui)
	local rng = Random.new()
	local current: Frame? = nil
	local panels: { Panel } = {}
	local specks: { { f: Frame, v: number, sway: number, ph: number } } = {}
	for _ = 1, if light() then 10 else 18 do
		local f = frame(root, "Speck", WHITE, rng:NextNumber(0.35, 0.7), 20)
		local s = rng:NextInteger(3, 7)
		f.Size = UDim2.fromOffset(s, s)
		f.Rotation = rng:NextNumber(0, 90)
		f.Position = UDim2.fromScale(rng:NextNumber(0, 1), rng:NextNumber(0, 1))
		table.insert(specks, { f = f, v = rng:NextNumber(0.02, 0.05), sway = rng:NextNumber(0.004, 0.012), ph = rng:NextNumber(0, 6) })
	end
	local handle = {} :: Credits

	-- the next page: the old one slides off left, the new one in from the right
	local function turn(): Frame
		local old = current
		if old then
			tween(old, 0.55, { Position = UDim2.fromScale(-1.05, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
			task.delay(0.6, function()
				old:Destroy()
			end)
		end
		table.clear(panels)
		local page = frame(root, "Page", BLACK, 1, 1)
		page.Position = UDim2.fromScale(if old then 1.05 else 0, 0)
		if old then
			tween(page, 0.55, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
		end
		current = page
		return page
	end

	-- a heading at the top left, in a brush hand, with a stripe of colour under it
	local function heading(page: Frame, text: string, color: Color3)
		local h = label(page, text, BRUSH, UDim2.fromScale(0.5, 0.075), UDim2.fromScale(0.04, 0.045), 12, 2)
		h.TextXAlignment = Enum.TextXAlignment.Left
		local bar = frame(page, "Stripe", color, 0, 11)
		bar.Size = UDim2.fromScale(0, 0.012)
		bar.Position = UDim2.fromScale(0.04, 0.128)
		tween(bar, 0.6, { Size = UDim2.fromScale(0.26, 0.012) }, Enum.EasingStyle.Quart)
	end

	function handle.page(items: { PageItem }, head: string)
		local page = turn()
		local n = math.max(#items, 1)
		local edges = {}
		for i = 0, n do
			table.insert(edges, i / n)
		end
		for i, it in items do
			local p = newPanel(page, edges[i], edges[i + 1], it.color, true)
			p.push = 0.08
			setStill(p, it.still, { side = it.side or ((i - (n + 1) / 2) * -10), drift = 8, span = it.span, low = it.low })
			p.static = it.hold == true -- (a heavy model: its camera holds, so it's drawn once)
			-- the name plate: a dark band at the bottom, the name big, the line under it small
			local plate = frame(p.root, "Plate", BLACK, 0.35, 8)
			plate.Size = UDim2.fromScale(1, 0.2)
			plate.Position = UDim2.fromScale(0, 0.8)
			local nm = label(plate, string.upper(it.name), HEAVY, UDim2.fromScale(0.86, 0.42), UDim2.fromScale(0.07, 0.1), 9, 2)
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(WHITE, it.color:Lerp(WHITE, 0.35))
			g.Rotation = 90
			g.Parent = nm
			if it.sub and it.sub ~= "" then
				local sb = label(plate, it.sub, BOLD, UDim2.fromScale(0.86, 0.24), UDim2.fromScale(0.07, 0.58), 9, 0)
				sb.TextColor3 = Color3.fromRGB(230, 226, 240)
			end
			-- in one after another, from below
			p.root.Position = UDim2.fromScale(edges[i], 1.05)
			task.delay(0.25 + (i - 1) * 0.09, function()
				if p.root.Parent then
					tween(p.root, 0.5, { Position = UDim2.fromScale(edges[i], 0) }, Enum.EasingStyle.Back)
				end
			end)
			table.insert(panels, p)
		end
		for i = 1, n - 1 do
			slash(page, edges[i + 1], 7, 0.03, ratio, rng, 10)
		end
		heading(page, head, (items[1] and items[1].color) or WHITE)
	end

	function handle.title(big: string, small: string?)
		local page = turn()
		local t = label(page, big, HEAVY, UDim2.fromScale(0.8, 0.16), UDim2.fromScale(0.1, 0.36), 12, 4)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 110)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 236, 110)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 150, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 110, 30)),
		})
		g.Rotation = 90
		g.Parent = t
		local sc = Instance.new("UIScale")
		sc.Scale = 1.25
		sc.Parent = t
		tween(sc, 0.8, { Scale = 1 }, Enum.EasingStyle.Quart)
		local stroke = frame(page, "Brush", WHITE, 0, 11)
		stroke.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke.Position = UDim2.fromScale(0.5, 0.56)
		stroke.Size = UDim2.fromScale(0, 0.012)
		stroke.Rotation = -2
		tween(stroke, 0.7, { Size = UDim2.fromScale(0.5, 0.012) }, Enum.EasingStyle.Quart)
		if small then
			local s = label(page, small, BRUSH, UDim2.fromScale(0.6, 0.06), UDim2.fromScale(0.2, 0.6), 12, 0)
			s.TextColor3 = Color3.fromRGB(230, 226, 240)
		end
	end

	function handle.text(head: string, lines: { string })
		local page = turn()
		heading(page, head, Color3.fromRGB(255, 214, 60))
		for i, l in lines do
			local t = label(page, l, BOLD, UDim2.fromScale(0.84, 0.055), UDim2.fromScale(0.08, 0.2 + (i - 1) * 0.075), 12, 1.5)
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.TextTransparency = 1
			-- (its black outline fades in with it: on its own it showed the lines as black letters first)
			local edge = t:FindFirstChildOfClass("UIStroke")
			if edge then
				edge.Transparency = 1
			end
			task.delay(0.3 + i * 0.12, function()
				if t.Parent then
					tween(t, 0.5, { TextTransparency = 0 })
					if edge then
						tween(edge, 0.5, { Transparency = 0 })
					end
				end
			end)
		end
	end

	function handle.update(dt: number)
		if not root.Parent then
			return
		end
		for _, p in panels do
			stepPanel(p, dt)
		end
		local now = os.clock()
		for _, s in specks do
			local pos = s.f.Position
			local y = pos.Y.Scale - s.v * dt
			if y < -0.03 then
				y = 1.03
			end
			s.f.Position = UDim2.fromScale(pos.X.Scale + math.sin(now * 0.8 + s.ph) * s.sway * dt, y)
		end
	end

	function handle.destroy()
		root:Destroy()
	end

	return handle
end

return FilmPanels
