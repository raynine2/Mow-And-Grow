-- The actors and props of the run's opening cutscene (client/Intro), all built on this client only:
--   * the party: a copy of every player's avatar, lined up in the village, each doing an emote on cue;
--   * Mayor Thistlewick, the village mayor (our own character, built from bricks), on a soapbox;
--   * the supply crate that drops from the sky and bursts open.
-- It can also hide the real characters (so nobody wanders through a shot) and, for the flashback, every clump
-- of grass in the first area (the valley "before the grass came").
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local IntroCast = {}

local set: Folder? = nil
local hiddenChars: { Instance } = {}
local hiddenGrass: { BasePart } = {}

local function folder(): Folder
	if set and set.Parent then
		return set
	end
	local f = Instance.new("Folder")
	f.Name = "IntroSet"
	f.Parent = workspace
	set = f
	return f
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- The ground under a point (ignores the cast, the characters and anything you can see through).
function IntroCast.ground(pos: Vector3): Vector3
	local ignore: { Instance } = { folder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local from = Vector3.new(pos.X, pos.Y + 120, pos.Z)
	for _ = 1, 6 do
		local hit = workspace:Raycast(from, Vector3.new(0, -400, 0), params)
		if not hit then
			break
		end
		local part = hit.Instance
		local solid = part:IsA("Terrain") or (part:IsA("BasePart") and part.Transparency < 0.9 and part.CanCollide)
		local isGrass = part:FindFirstAncestor("Grass") ~= nil
		if solid and not isGrass then
			return hit.Position
		end
		table.insert(ignore, part)
		params.FilterDescendantsInstances = ignore
	end
	return pos
end

-------------------------------------------------------------------------------------------------------------
-- the party: copies of everyone's avatars
-------------------------------------------------------------------------------------------------------------
export type Actor = { model: Model, head: BasePart?, name: string, play: (kind: string) -> (), tag: () -> () }

local EMOTES = { "wave", "cheer", "point", "dance2", "dance", "dance3" }

local function animationOf(char: Model, name: string): string?
	local animate = char:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(name)
	local a = holder and holder:FindFirstChildWhichIsA("Animation")
	return if a then (a :: Animation).AnimationId else nil
end

local function cloneOf(char: Model): Model?
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
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
	return clone
end

local function nameTag(head: BasePart, text: string): () -> ()
	return function()
		local bb = Instance.new("BillboardGui")
		bb.Name = "IntroName"
		bb.Size = UDim2.fromOffset(240, 44)
		bb.StudsOffset = Vector3.new(0, 1.9, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = head
		bb.Parent = head
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = text
		t.Parent = bb
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Parent = t
		local sc = Instance.new("UIScale")
		sc.Scale = 0
		sc.Parent = t
		tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local function actorFor(p: Player, cf: CFrame, slot: number): Actor?
	local char = p.Character
	if not char then
		return nil
	end
	local clone = cloneOf(char)
	if not clone then
		return nil
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local lift = if hum and hum.RigType == Enum.HumanoidRigType.R15 and root then hum.HipHeight + root.Size.Y / 2 else 3
	clone.Name = "IntroActor"
	clone:PivotTo(cf * CFrame.new(0, lift, 0))
	clone.Parent = folder()
	local animator: Animator? = nil
	if hum then
		animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	end
	local current: AnimationTrack? = nil
	local function run(id: string?, looped: boolean)
		if not animator or not id then
			return
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		pcall(function()
			local track = (animator :: Animator):LoadAnimation(anim)
			track.Looped = looped
			if current then
				current:Stop(0.2)
			end
			track:Play(0.2)
			current = track
		end)
	end
	run(animationOf(char, "idle"), true)
	local idleId = animationOf(char, "idle")
	local head = clone:FindFirstChild("Head") :: BasePart?
	local function play(kind: string)
		local name = if kind == "emote" then EMOTES[(slot - 1) % #EMOTES + 1] else kind
		local id = animationOf(char, name) or animationOf(char, "wave")
		run(id, name:sub(1, 5) == "dance")
		if name:sub(1, 5) ~= "dance" then
			task.delay(2.2, function()
				if clone.Parent then
					run(idleId, true)
				end
			end)
		end
	end
	return {
		model = clone,
		head = head,
		name = p.DisplayName,
		play = play,
		tag = if head then nameTag(head, p.DisplayName) else function() end,
	}
end

-- Line the party up at `centre`, shoulder to shoulder across `right`, facing `fwd`. You stand in the middle.
function IntroCast.party(centre: Vector3, fwd: Vector3, right: Vector3): { Actor }
	local me = Players.LocalPlayer
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	-- put yourself in the middle of the row
	local others = {}
	for _, p in list do
		if p ~= me then
			table.insert(others, p)
		end
	end
	local row = {}
	local half = math.floor(#others / 2)
	for i = 1, half do
		table.insert(row, others[i])
	end
	table.insert(row, me)
	for i = half + 1, #others do
		table.insert(row, others[i])
	end
	local n = math.min(#row, 8)
	local gap = 4.4
	local actors = {}
	for i = 1, n do
		local at = centre + right * ((i - (n + 1) / 2) * gap)
		local ground = IntroCast.ground(at)
		local cf = CFrame.lookAt(ground, ground + fwd)
		local a = actorFor(row[i], cf, i)
		if a then
			table.insert(actors, a)
		end
	end
	return actors
end

-------------------------------------------------------------------------------------------------------------
-- Mayor Thistlewick: a round little mayor in a red coat, gold sash and a tall hat, built from bricks
-------------------------------------------------------------------------------------------------------------
export type Mayor = { model: Model, head: BasePart, update: (t: number, mode: string) -> (), root: CFrame }

local SKIN = Color3.fromRGB(255, 204, 153)
local COAT = Color3.fromRGB(168, 38, 48)
local GOLDC = Color3.fromRGB(245, 196, 52)
local HAT = Color3.fromRGB(34, 30, 38)
local PANTS = Color3.fromRGB(52, 54, 74)

local function brick(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A wooden box with darker edge planks.
local function crateParts(parent: Instance, size: Vector3, wood: Color3, edge: Color3): { [Part]: CFrame }
	local parts: { [Part]: CFrame } = {}
	parts[brick(parent, "Box", size - Vector3.new(0.2, 0.2, 0.2), wood, Enum.Material.WoodPlanks)] = CFrame.new()
	local t = 0.32
	local hx, hy, hz = size.X / 2 - t / 2, size.Y / 2 - t / 2, size.Z / 2 - t / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			parts[brick(parent, "Edge", Vector3.new(t, size.Y, t), edge, Enum.Material.Wood)] = CFrame.new(sx * hx, 0, sz * hz)
		end
		for _, sy in { -1, 1 } do
			parts[brick(parent, "Edge", Vector3.new(t, t, size.Z), edge, Enum.Material.Wood)] = CFrame.new(sx * hx, sy * hy, 0)
			parts[brick(parent, "Edge", Vector3.new(size.X, t, t), edge, Enum.Material.Wood)] = CFrame.new(0, sy * hy, sx * hz)
		end
	end
	-- a diagonal brace on the front and back
	for _, sz in { -1, 1 } do
		local len = math.sqrt(size.X ^ 2 + size.Y ^ 2) * 0.82
		parts[brick(parent, "Brace", Vector3.new(len, t, t * 0.8), edge, Enum.Material.Wood)] = CFrame.new(0, 0, sz * (size.Z / 2 + 0.02)) * CFrame.Angles(0, 0, math.atan2(size.Y, size.X))
	end
	return parts
end

local function placeAll(parts: { [Part]: CFrame }, at: CFrame)
	for p, rel in parts do
		p.CFrame = at * rel
	end
end

-- The mayor stands at `pos` (on a soapbox) facing `face`.
function IntroCast.mayor(pos: Vector3, face: Vector3): Mayor
	local m = Instance.new("Model")
	m.Name = "MayorThistlewick"
	m.Parent = folder()
	local ground = IntroCast.ground(pos)
	local boxH = 1.5
	local boxCf = CFrame.lookAt(ground, ground + face) * CFrame.new(0, boxH / 2, 0)
	placeAll(crateParts(m, Vector3.new(3.4, boxH, 3.0), Color3.fromRGB(176, 122, 70), Color3.fromRGB(112, 72, 38)), boxCf)
	local base = CFrame.lookAt(ground, ground + face) * CFrame.new(0, boxH, 0)
	local S = 1.2 -- a bit bigger than a player

	-- fixed parts: { part, offset from the feet }; the head and what's on it move with the head
	local body: { [Part]: CFrame } = {}
	local face: { [Part]: CFrame } = {}
	local HEAD_Y = 5.15
	local function add(name: string, size: Vector3, color: Color3, at: CFrame, material: Enum.Material?): Part
		local p = brick(m, name, size * S, color, material)
		body[p] = CFrame.new(at.Position * S) * at.Rotation
		return p
	end
	local function onHead(name: string, size: Vector3, color: Color3, at: CFrame, material: Enum.Material?): Part
		local p = brick(m, name, size * S, color, material)
		face[p] = CFrame.new((at.Position - Vector3.new(0, HEAD_Y, 0)) * S) * at.Rotation
		return p
	end
	add("LegL", Vector3.new(0.95, 2, 1), PANTS, CFrame.new(-0.52, 1, 0))
	add("LegR", Vector3.new(0.95, 2, 1), PANTS, CFrame.new(0.52, 1, 0))
	add("ShoeL", Vector3.new(1, 0.4, 1.3), HAT, CFrame.new(-0.52, 0.2, -0.15))
	add("ShoeR", Vector3.new(1, 0.4, 1.3), HAT, CFrame.new(0.52, 0.2, -0.15))
	add("Torso", Vector3.new(2.2, 2.3, 1.3), COAT, CFrame.new(0, 3.15, 0))
	add("Belly", Vector3.new(2.0, 1.2, 1.5), COAT, CFrame.new(0, 2.6, -0.1))
	add("CoatTail", Vector3.new(2.1, 0.9, 1.2), COAT, CFrame.new(0, 1.75, 0.08))
	add("Sash", Vector3.new(0.42, 2.9, 1.56), GOLDC, CFrame.new(0, 3.0, -0.02) * CFrame.Angles(0, 0, math.rad(38)))
	add("Button1", Vector3.new(0.26, 0.26, 0.12), GOLDC, CFrame.new(0.42, 3.55, -0.68), Enum.Material.Neon)
	add("Button2", Vector3.new(0.26, 0.26, 0.12), GOLDC, CFrame.new(-0.42, 2.7, -0.86), Enum.Material.Neon)
	add("Collar", Vector3.new(1.5, 0.3, 1.0), Color3.new(1, 1, 1), CFrame.new(0, 4.35, -0.05))
	local head = onHead("Head", Vector3.new(1.7, 1.6, 1.6), SKIN, CFrame.new(0, HEAD_Y, 0))
	onHead("EyeL", Vector3.new(0.24, 0.34, 0.06), HAT, CFrame.new(-0.36, 5.32, -0.81))
	onHead("EyeR", Vector3.new(0.24, 0.34, 0.06), HAT, CFrame.new(0.36, 5.32, -0.81))
	onHead("Brow", Vector3.new(1.3, 0.16, 0.08), Color3.fromRGB(235, 235, 240), CFrame.new(0, 5.62, -0.81))
	onHead("Nose", Vector3.new(0.36, 0.36, 0.3), Color3.fromRGB(245, 160, 130), CFrame.new(0, 5.02, -0.9))
	onHead("Stache", Vector3.new(1.0, 0.28, 0.2), Color3.fromRGB(240, 240, 245), CFrame.new(0, 4.78, -0.86))
	onHead("StacheL", Vector3.new(0.45, 0.24, 0.18), Color3.fromRGB(240, 240, 245), CFrame.new(-0.62, 4.88, -0.84) * CFrame.Angles(0, 0, math.rad(-28)))
	onHead("StacheR", Vector3.new(0.45, 0.24, 0.18), Color3.fromRGB(240, 240, 245), CFrame.new(0.62, 4.88, -0.84) * CFrame.Angles(0, 0, math.rad(28)))
	onHead("Brim", Vector3.new(2.2, 0.16, 2.1), HAT, CFrame.new(0, 6.02, 0))
	onHead("Hat", Vector3.new(1.4, 1.5, 1.4), HAT, CFrame.new(0, 6.82, 0))
	onHead("HatBand", Vector3.new(1.46, 0.3, 1.46), GOLDC, CFrame.new(0, 6.24, 0))

	-- the arms swing from the shoulders: { upper arm, hand, side }
	local arms = {}
	for _, side in { -1, 1 } do
		local arm = brick(m, if side < 0 then "ArmL" else "ArmR", Vector3.new(0.82, 2.0, 0.85) * S, COAT)
		local hand = brick(m, if side < 0 then "HandL" else "HandR", Vector3.new(0.9, 0.62, 0.9) * S, Color3.new(1, 1, 1))
		table.insert(arms, { arm = arm, hand = hand, side = side })
	end
	m.PrimaryPart = head

	local function pose(t: number, mode: string)
		local talk = mode == "talk" or mode == "point"
		local bob = if talk then math.abs(math.sin(t * 7)) * 0.08 else math.sin(t * 2) * 0.03
		local lean = if mode == "point" then math.rad(-6) else math.sin(t * 1.3) * math.rad(1.5)
		local root = base * CFrame.new(0, bob, 0) * CFrame.Angles(lean, 0, 0)
		for p, rel in body do
			p.CFrame = root * rel
		end
		-- the head nods a little while he talks
		local nod = if talk then math.sin(t * 9) * math.rad(5) else 0
		local headCf = root * CFrame.new(0, 4.35 * S, 0) * CFrame.Angles(nod, math.sin(t * 1.7) * math.rad(4), 0) * CFrame.new(0, (HEAD_Y - 4.35) * S, 0)
		for p, rel in face do
			p.CFrame = headCf * rel
		end
		for _, a in arms do
			local swing, out
			if mode == "point" and a.side > 0 then
				swing, out = math.rad(-95), math.rad(8) -- right arm straight out at the gate
			elseif mode == "cheer" then
				swing, out = math.rad(-160) + math.sin(t * 10 + a.side) * 0.15, math.rad(14) * a.side
			elseif talk then
				swing = math.rad(-30) + math.sin(t * 5 + a.side * 1.7) * math.rad(28)
				out = math.rad(18) * a.side
			else
				swing, out = math.sin(t * 2 + a.side) * math.rad(4), math.rad(6) * a.side
			end
			local shoulder = root * CFrame.new(a.side * 1.5 * S, 4.15 * S, 0) * CFrame.Angles(swing, 0, out)
			a.arm.CFrame = shoulder * CFrame.new(0, -0.9 * S, 0)
			a.hand.CFrame = shoulder * CFrame.new(0, -2.0 * S, 0)
		end
	end
	pose(0, "idle")
	return { model = m, head = head, update = pose, root = base }
end

-------------------------------------------------------------------------------------------------------------
-- the supply crate: falls from the sky, slams down, the lid flies off and coins and clippings burst out
-------------------------------------------------------------------------------------------------------------
local function burstBits(at: Vector3)
	local f = folder()
	local colors = { Color3.fromRGB(255, 214, 60), Color3.fromRGB(255, 236, 120), Color3.fromRGB(110, 220, 70), Color3.fromRGB(80, 190, 60) }
	for i = 1, 26 do
		local coin = i % 2 == 0
		local p = Instance.new("Part")
		p.Name = "Bit"
		p.Size = if coin then Vector3.new(0.9, 0.9, 0.22) else Vector3.new(0.35, 1.2, 0.15)
		p.Color = colors[if coin then (i % 4 == 0 and 2 or 1) else (i % 3 == 0 and 4 or 3)]
		p.Material = if coin then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Parent = f
		local a = math.random() * math.pi * 2
		local out = 10 + math.random() * 14
		p.AssemblyLinearVelocity = Vector3.new(math.cos(a) * out, 42 + math.random() * 26, math.sin(a) * out)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
		Debris:AddItem(p, 2.2)
	end
end

-- Drop the crate onto `pos`. Calls `onLand()` the moment it hits the ground.
function IntroCast.crate(pos: Vector3, face: Vector3, onLand: () -> ())
	local m = Instance.new("Model")
	m.Name = "SupplyCrate"
	m.Parent = folder()
	local size = Vector3.new(4.4, 4.0, 4.4)
	local ground = IntroCast.ground(pos)
	local rest = CFrame.lookAt(ground, ground + face) * CFrame.new(0, size.Y / 2, 0)
	local parts = crateParts(m, size, Color3.fromRGB(196, 140, 76), Color3.fromRGB(120, 76, 40))
	-- a green band and a gold star on the front (the mowing company's supply crate)
	parts[brick(m, "Band", Vector3.new(size.X + 0.06, 0.8, size.Z + 0.06), Color3.fromRGB(90, 200, 60))] = CFrame.new(0, 0.6, 0)
	local lid = brick(m, "Lid", Vector3.new(size.X + 0.3, 0.4, size.Z + 0.3), Color3.fromRGB(120, 76, 40), Enum.Material.Wood)
	local lidRel = CFrame.new(0, size.Y / 2 + 0.2, 0)
	local drop = 70
	local start = os.clock()
	local fall = 0.55
	task.spawn(function()
		while true do
			local k = math.min(1, (os.clock() - start) / fall)
			local y = drop * (1 - k * k)
			local spin = (1 - k) * 1.2
			local at = rest * CFrame.new(0, y, 0) * CFrame.Angles(0, spin, spin * 0.3)
			placeAll(parts, at)
			lid.CFrame = at * lidRel
			if k >= 1 then
				break
			end
			task.wait()
		end
		onLand()
		-- squash and settle
		local settle = os.clock()
		while os.clock() - settle < 0.25 do
			local s = math.sin((os.clock() - settle) / 0.25 * math.pi) * 0.25
			placeAll(parts, rest * CFrame.new(0, -s, 0))
			lid.CFrame = rest * CFrame.new(0, -s, 0) * lidRel
			task.wait()
		end
		placeAll(parts, rest)
		task.wait(0.25)
		-- pop the lid and throw out the goodies
		lid.Anchored = false
		lid.CFrame = rest * lidRel
		lid.AssemblyLinearVelocity = Vector3.new(0, 55, 0) + face * -8
		lid.AssemblyAngularVelocity = Vector3.new(6, 2, 3)
		Debris:AddItem(lid, 2)
		local beam = brick(m, "Glow", Vector3.new(3.6, 1, 3.6), Color3.fromRGB(255, 236, 140), Enum.Material.Neon)
		beam.Transparency = 0.25
		beam.CFrame = rest * CFrame.new(0, size.Y / 2, 0)
		tween(beam, 0.5, { Size = Vector3.new(2.6, 26, 2.6), CFrame = rest * CFrame.new(0, size.Y / 2 + 13, 0), Transparency = 0.6 })
		task.delay(0.5, function()
			tween(beam, 0.8, { Transparency = 1 })
		end)
		burstBits(rest.Position + Vector3.new(0, size.Y / 2 + 0.5, 0))
	end)
	return m
end

-------------------------------------------------------------------------------------------------------------
-- hiding things for the length of the cutscene (this client only)
-------------------------------------------------------------------------------------------------------------
function IntroCast.hideCharacters(on: boolean)
	if on then
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char then
				for _, d in char:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = 1
						table.insert(hiddenChars, d)
					end
				end
			end
		end
	else
		for _, d in hiddenChars do
			if d.Parent then
				(d :: any).LocalTransparencyModifier = 0
			end
		end
		table.clear(hiddenChars)
	end
end

-- The first area's grass, gone for the flashback (and back again after).
function IntroCast.hideGrass(on: boolean)
	if not on then
		for _, p in hiddenGrass do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
		table.clear(hiddenGrass)
		return
	end
	local grass = workspace:FindFirstChild("Grass1", true)
	if not grass then
		return
	end
	for _, d in grass:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			d.LocalTransparencyModifier = 1
			table.insert(hiddenGrass, d)
		end
	end
end

-- Fade the actors' name tags away (once the party shot is over, so they don't sit on the later cards).
function IntroCast.untag()
	local f = set
	if not f then
		return
	end
	for _, d in f:GetDescendants() do
		if d:IsA("BillboardGui") and d.Name == "IntroName" then
			local label = d:FindFirstChildOfClass("TextLabel")
			local sc = label and label:FindFirstChildOfClass("UIScale")
			if sc then
				tween(sc, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			end
			task.delay(0.22, function()
				d:Destroy()
			end)
		end
	end
end

-- Take the actors and props away (the hidden characters and grass stay as they are).
function IntroCast.clearSet()
	if set then
		set:Destroy()
		set = nil
	end
end

function IntroCast.cleanup()
	IntroCast.hideCharacters(false)
	IntroCast.hideGrass(false)
	IntroCast.clearSet()
end

return IntroCast
