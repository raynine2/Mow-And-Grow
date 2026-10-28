-- The actors and props of the films (client/Intro, client/Ending), all built on this client only:
--   * the party: a copy of every player's avatar, each doing emotes on cue; they can walk in (with their own
--     walk), drop in, turn their heads to look at something;
--   * Mayor Thistlewick (client/MayorRig: the voxel sculpture on its rig) on his soapbox;
--   * the supply crate that drops from the sky and bursts open.
-- It can also hide the real characters (so nobody wanders through a shot) and, for the flashback, every clump
-- of grass in the first area (the valley "before the grass came"), and bring it back in a wave.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MayorRig = require(script.Parent.MayorRig)

local IntroCast = {}

-- the ForgeGUI supply crate and its VFX Forge effects (client/IntroCrate; owner 27 Oct); the brick crate below is
-- the fallback when its models aren't in the place
local IntroCrate: any = nil
do
	local mod = script.Parent:FindFirstChild("IntroCrate")
	local ok, res = pcall(require, mod)
	if mod and ok then
		IntroCrate = res
	end
end

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
	local ignore: { Instance } = {}
	if set and set.Parent then
		table.insert(ignore, set)
	end
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
export type Actor = {
	model: Model,
	head: BasePart?,
	name: string,
	spot: CFrame, -- where it stands in the line (feet), facing its way
	play: (kind: string) -> (),
	tag: () -> (),
	drop: (onLand: (foot: Vector3) -> ()) -> (),
	walk: (from: Vector3, time: number, onStep: ((foot: Vector3) -> ())?) -> (),
	look: (target: Vector3?) -> (),
	turnTo: (dir: Vector3) -> (),
	show: () -> (),
	update: (dt: number, timeScale: number) -> (),
}

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
	local final = cf * CFrame.new(0, lift, 0)
	clone:PivotTo(final) -- (not in the world until it drops in: IntroCast Actor.drop)
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
	-- Fall from the sky onto its spot (a quick ease-in), then call onLand with the point under its feet.
	local function drop(onLand: (foot: Vector3) -> ())
		local high = 34
		clone:PivotTo(final * CFrame.new(0, high, 0))
		clone.Parent = folder()
		run(animationOf(char, "fall") or idleId, true)
		local start = os.clock()
		local fall = 0.42
		task.spawn(function()
			while clone.Parent do
				local k = math.min(1, (os.clock() - start) / fall)
				clone:PivotTo(final * CFrame.new(0, high * (1 - k * k), 0))
				if k >= 1 then
					break
				end
				task.wait()
			end
			if clone.Parent then
				run(idleId, true)
				onLand(cf.Position)
			end
		end)
	end
	-- Walk in from `from` to its spot over `time` seconds of film time (with its own walk), then stand and idle.
	local walking: { from: Vector3, to: Vector3, t: number, len: number, onStep: ((Vector3) -> ())?, stride: number }? = nil
	local walkId = animationOf(char, "walk") or animationOf(char, "run")
	local function walk(from: Vector3, time: number, onStep: ((foot: Vector3) -> ())?)
		local g = IntroCast.ground(from)
		walking = { from = g, to = cf.Position, t = 0, len = math.max(time, 0.1), onStep = onStep, stride = 0 }
		local dir = cf.Position - g
		dir = Vector3.new(dir.X, 0, dir.Z)
		clone:PivotTo(CFrame.lookAt(g, g + (if dir.Magnitude > 0.01 then dir else cf.LookVector)) * CFrame.new(0, lift, 0))
		clone.Parent = folder()
		run(walkId or idleId, true)
	end
	-- Turn its head toward a point (nil: straight ahead); R15 only.
	local headPart = clone:FindFirstChild("Head")
	local neck = (if headPart then headPart:FindFirstChild("Neck") else nil) :: Instance?
	-- (28 Oct) avatars now joint with AnimationConstraints, whose C0 is read-only (setting it threw every frame and
	-- stopped the film's camera with it): their neck turns by its torso-side attachment instead
	local neckAtt: Attachment? = if neck and neck:IsA("AnimationConstraint") then neck.Attachment0 else nil
	local neckBase = if neckAtt then neckAtt.CFrame elseif neck and neck:IsA("Motor6D") then neck.C0 else CFrame.identity
	local lookAt: Vector3? = nil
	local yawNow, pitchNow = 0, 0
	local function look(target: Vector3?)
		lookAt = target
	end
	local lastPos: Vector3? = nil
	local function update(dt: number, timeScale: number)
		local w = walking
		if w then
			w.t += dt
			local k = math.clamp(w.t / w.len, 0, 1)
			-- (easing into the last steps)
			local e = if k < 0.8 then k / 0.8 * 0.85 else 0.85 + (1 - (1 - (k - 0.8) / 0.2) ^ 2) * 0.15
			local p = w.from:Lerp(w.to, e)
			local g = Vector3.new(p.X, IntroCast.ground(p).Y, p.Z)
			local dir = w.to - w.from
			dir = Vector3.new(dir.X, 0, dir.Z)
			local face = if k >= 1 then cf.LookVector else (if dir.Magnitude > 0.01 then dir.Unit else cf.LookVector)
			clone:PivotTo(CFrame.lookAt(g, g + face) * CFrame.new(0, lift, 0))
			if lastPos then
				w.stride += (g - lastPos).Magnitude
				if w.stride > 2.1 then
					w.stride = 0
					if w.onStep then
						w.onStep(g)
					end
				end
			end
			lastPos = g
			local speed = (w.to - w.from).Magnitude / w.len
			local tr = current
			if tr then
				pcall(function()
					tr:AdjustSpeed(math.clamp(speed / 9, 0.45, 1.4) * timeScale)
				end)
			end
			if k >= 1 then
				walking = nil
				lastPos = nil
				clone:PivotTo(final)
				run(idleId, true)
			end
		else
			local tr = current
			if tr then
				pcall(function()
					tr:AdjustSpeed(timeScale)
				end)
			end
		end
		if neck and neck.Parent then
			local wantYaw, wantPitch = 0, 0
			local h = head
			if lookAt and h then
				local root2 = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
				local base = if root2 then root2.CFrame else clone:GetPivot()
				local rel = base:VectorToObjectSpace(lookAt - h.Position)
				local flat = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
				wantYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -1.1, 1.1)
				wantPitch = math.clamp(math.atan2(rel.Y, math.max(flat, 0.01)), -0.5, 0.45)
			end
			local a = math.min(1, dt * 6)
			yawNow += (wantYaw - yawNow) * a
			pitchNow += (wantPitch - pitchNow) * a
			local turned = neckBase * CFrame.Angles(pitchNow, yawNow, 0)
			if neckAtt then
				neckAtt.CFrame = turned
			elseif neck:IsA("Motor6D") then
				(neck :: Motor6D).C0 = turned
			end
		end
	end
	local function show()
		clone:PivotTo(final)
		clone.Parent = folder()
	end
	-- Turn on the spot to face a flat direction (where it stands from now on).
	local function turnTo(dir: Vector3)
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		if flatDir.Magnitude < 0.01 then
			return
		end
		local p = final.Position
		final = CFrame.lookAt(p, p + flatDir)
		if not walking then
			clone:PivotTo(final)
		end
	end
	return {
		model = clone,
		head = head,
		name = p.DisplayName,
		spot = cf,
		play = play,
		tag = if head then nameTag(head, p.DisplayName) else function() end,
		drop = drop,
		walk = walk,
		look = look,
		turnTo = turnTo,
		show = show,
		update = update,
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
-- Mayor Thistlewick (client/MayorRig) on his soapbox
-------------------------------------------------------------------------------------------------------------
export type Mayor = MayorRig.Mayor

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

-- The Mayor on his soapbox at `pos`, facing `face`. opts: client/MayorRig's (lite, scale).
function IntroCast.mayor(pos: Vector3, face: Vector3, opts: { lite: boolean?, scale: number? }?): Mayor
	local f = folder()
	local ground = IntroCast.ground(pos)
	local boxH = 1.5
	local flatFace = Vector3.new(face.X, 0, face.Z)
	if flatFace.Magnitude < 0.01 then
		flatFace = Vector3.zAxis
	end
	local base = CFrame.lookAt(ground, ground + flatFace)
	local box = Instance.new("Model")
	box.Name = "Soapbox"
	box.Parent = f
	placeAll(crateParts(box, Vector3.new(3.4, boxH, 3.0), Color3.fromRGB(176, 122, 70), Color3.fromRGB(112, 72, 38)), base * CFrame.new(0, boxH / 2, 0))
	return MayorRig.new(f, base * CFrame.new(0, boxH, 0), opts)
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
function IntroCast.crate(pos: Vector3, face: Vector3, onLand: () -> (), onOpen: (() -> ())?)
	if IntroCrate and IntroCrate.ready() then
		return IntroCrate.drop(folder(), IntroCast.ground(pos), face, onLand, onOpen)
	end
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
		if onOpen then
			onOpen()
		end
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
	-- (client/ViewModel shows your held tool again every frame in third person; this tells it not to)
	Players.LocalPlayer:SetAttribute("CastHidden", if on then true else nil)
	if on then
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char then
				for _, d in char:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = 1
						table.insert(hiddenChars, d)
					elseif d:IsA("BillboardGui") and d.Enabled then
						-- name tags (VIP) would float in the shots
						d.Enabled = false
						table.insert(hiddenChars, d)
					end
				end
			end
		end
	else
		for _, d in hiddenChars do
			if d:IsA("BillboardGui") then
				d.Enabled = true
			elseif d.Parent then
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

-- The hidden grass comes back in a wave rolling out from `origin` (nearest first) over `time` seconds; `onWave(k)`
-- is called as it goes (0..1), for the film's sound and shake.
function IntroCast.growGrass(origin: Vector3, time: number, onWave: ((k: number) -> ())?)
	local list = table.clone(hiddenGrass)
	table.clear(hiddenGrass)
	local dist: { [BasePart]: number } = {}
	for _, p in list do
		dist[p] = (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
	end
	table.sort(list, function(a, b)
		return dist[a] < dist[b]
	end)
	task.spawn(function()
		local n = #list
		local done = 0
		local t0 = os.clock()
		while done < n do
			local k = math.clamp((os.clock() - t0) / math.max(time, 0.05), 0, 1)
			-- quick at first, easing at the far edge
			local upto = math.floor(n * (1 - (1 - k) ^ 2))
			while done < upto do
				done += 1
				local p = list[done]
				if p.Parent then
					p.LocalTransparencyModifier = 0
				end
			end
			if onWave then
				onWave(k)
			end
			if k >= 1 then
				break
			end
			task.wait()
		end
		for i = done + 1, n do
			local p = list[i]
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- grass that GROWS (owner, 28 Oct: "why don't you show that grass grows"): blades rise out of the soil from their
-- roots and spring up a little past their size, instead of just appearing. The real clumps are the server's
-- (other players may be mowing them), so they are only ever hidden and shown: what grows is a film-only copy of
-- each one, standing exactly where it is, swapped for the real one the moment it's full size.
-------------------------------------------------------------------------------------------------------------
local standIns: { [BasePart]: BasePart } = {} -- real part -> its growing copy
local growGen = 0 -- bumps when the growing is cut short (settleGrass)

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- A film-only copy of a clump part (or any mesh), with nothing that can be touched, hit or seen through walls.
local function prop(src: BasePart): BasePart
	local c = src:Clone()
	for _, ch in c:GetChildren() do
		ch:Destroy()
	end
	c.Anchored = true
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.LocalTransparencyModifier = 0
	return c
end

-- The copy of `real` squashed into a seed at its root; grow(real) raises it and then swaps it for the real one.
local function plant(real: BasePart)
	local c = prop(real)
	local size, cf = real.Size, real.CFrame
	c.Size = Vector3.new(size.X * 0.3, 0.05, size.Z * 0.3)
	c.CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.025, 0) -- (the clumps stand upright: local Y is up)
	c.Parent = folder()
	standIns[real] = c
end

local function grow(real: BasePart, time: number, gen: number)
	local c = standIns[real]
	if not c or not c.Parent then
		return
	end
	local tw = tween(c, time, { Size = real.Size, CFrame = real.CFrame }, Enum.EasingStyle.Back)
	tw.Completed:Once(function()
		if gen == growGen and standIns[real] == c then
			standIns[real] = nil
			c:Destroy()
			if real.Parent then
				real.LocalTransparencyModifier = 0
			end
		end
	end)
end

-- Cut the growing short: the copies go, and every real clump that was waiting is shown (the film is over or was
-- skipped; hideGrass(false) shows anything still hidden).
function IntroCast.settleGrass()
	growGen += 1
	for real, c in standIns do
		c:Destroy()
		if real.Parent then
			real.LocalTransparencyModifier = 0
		end
	end
	table.clear(standIns)
end

-- The hidden grass grows back in a wave rolling out from `origin` over `time` seconds. The `count` clumps nearest
-- `focus` (where the camera looks) rise out of the ground over about a second each, with a springy overshoot; the
-- rest just appear as the wave passes them (too far off to see them grow). `onWave(k)` is called as it goes (0..1).
-- (The clumps stay on the hidden list: hideGrass(false) at the end shows any the wave hadn't reached yet.)
function IntroCast.sproutGrass(origin: Vector3, focus: Vector3, time: number, onWave: ((k: number) -> ())?, count: number?)
	local gen = growGen
	local list = table.clone(hiddenGrass)
	local fromFocus: { [BasePart]: number } = {}
	local fromOrigin: { [BasePart]: number } = {}
	for _, p in list do
		fromFocus[p] = flatDist(p.Position, focus)
		fromOrigin[p] = flatDist(p.Position, origin)
	end
	local near = table.clone(list)
	table.sort(near, function(a, b)
		return fromFocus[a] < fromFocus[b]
	end)
	for i = 1, math.min(count or 160, #near) do
		plant(near[i])
	end
	table.sort(list, function(a, b)
		return fromOrigin[a] < fromOrigin[b]
	end)
	local far = if #list > 0 then math.max(fromOrigin[list[#list]], 1) else 1
	task.spawn(function()
		local n, done = #list, 0
		local t0 = os.clock()
		while done < n and gen == growGen do
			local k = math.clamp((os.clock() - t0) / math.max(time, 0.05), 0, 1)
			local reach = far * (1 - (1 - k) ^ 1.6) -- (fast at first, easing out at the far edge)
			while done < n and (fromOrigin[list[done + 1]] <= reach or k >= 1) do
				done += 1
				local p = list[done]
				if p.Parent then
					if standIns[p] then
						grow(p, 0.8 + math.random() * 0.6, gen)
					else
						p.LocalTransparencyModifier = 0
					end
				end
			end
			if onWave then
				onWave(k)
			end
			if k >= 1 then
				break
			end
			task.wait()
		end
	end)
end

-- Tall film-only grass rising round a spot (it swallows what stands there): `count` clumps copied from the real
-- meadow's, in a ring of `radius` (none closer than `inner`), growing from the soil to about `height` studs over
-- `time` seconds, the nearest first. Returns a function that sinks them back into the ground and removes them.
function IntroCast.overgrow(at: Vector3, radius: number, height: number, count: number, time: number, inner: number?): (time: number) -> ()
	local grass = workspace:FindFirstChild("Grass1", true)
	local template: MeshPart? = nil
	if grass then
		for _, d in grass:GetDescendants() do
			-- (a standing clump's mesh, not a cut patch's stubble)
			if d:IsA("MeshPart") and d.Transparency < 1 and d.Size.Y > 0.5 and d.Parent and d.Parent.Name == "Clump" then
				template = d
				break
			end
		end
	end
	local made: { { part: BasePart, size: Vector3, cf: CFrame } } = {}
	local function remove(t: number)
		for _, g in made do
			if g.part.Parent then
				tween(g.part, t, { Size = Vector3.new(g.size.X * 0.3, 0.05, g.size.Z * 0.3), CFrame = g.cf * CFrame.new(0, -g.size.Y / 2 + 0.025, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(g.part, t + 0.05)
			end
		end
		table.clear(made)
	end
	if not template then
		return remove
	end
	local f = folder()
	local k = height / math.max(template.Size.Y, 0.1)
	local full = template.Size * k
	local r0 = math.clamp(inner or 0, 0, radius * 0.9)
	for i = 1, count do
		local a = i / count * math.pi * 2 + math.random() * 0.6
		local r = r0 + (radius - r0) * math.sqrt(math.random())
		local spot = IntroCast.ground(at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		local c = prop(template)
		local size = full * (0.8 + math.random() * 0.4)
		local cf = CFrame.new(spot) * CFrame.Angles(0, math.random() * math.pi * 2, 0) * CFrame.new(0, size.Y / 2, 0)
		c.Size = Vector3.new(size.X * 0.3, 0.05, size.Z * 0.3)
		c.CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.025, 0)
		c.Parent = f
		table.insert(made, { part = c, size = size, cf = cf })
		task.delay(time * ((r - r0) / math.max(radius - r0, 0.1)) * 0.5, function()
			if c.Parent then
				tween(c, time * 0.55, { Size = size, CFrame = cf }, Enum.EasingStyle.Back)
			end
		end)
	end
	return remove
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
	IntroCast.settleGrass()
	IntroCast.hideGrass(false)
	IntroCast.clearSet()
end

return IntroCast
