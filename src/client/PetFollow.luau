-- Pets following players: every client draws every player's equipped critters (player attribute "Pets", set by
-- server/Pets) as small blocky models. Client-only, anchored, no collisions; far-away pets are hidden (no-lag rule).
-- PetFollow.build(look) is also used for anything else that wants a critter model.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local PartBuild = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("PartBuild"))

local PetFollow = {}

local BLACK = Color3.fromRGB(25, 22, 28)
local WHITE = Color3.fromRGB(250, 250, 250)
local VIEW_DISTANCE = 150

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- The smooth cartoon critter from Blender (shared/PartModels/pet_<id>, made by tools/blender/models/pet_*.py), if
-- there is one for this look. Its feet are at y = 0; an invisible Root sits 0.6 up (where the blocky ones have
-- their body centre), so both kinds follow the same way.
local function blenderPet(look): Model?
	for _, def in Config.PETS do
		if def.look == look then
			local m = PartBuild.get("pet_" .. string.lower(def.id))
			if m then
				local root = Instance.new("Part")
				root.Name = "Root"
				root.Size = Vector3.new(0.4, 0.4, 0.4)
				root.Transparency = 1
				root.Anchored = true
				root.CanCollide = false
				root.CanQuery = false
				root.CanTouch = false
				root.CFrame = CFrame.new(0, 0.6, 0)
				root.Parent = m
				m.PrimaryPart = root
				m.Name = "Pet"
			end
			return m
		end
	end
	return nil
end

-- Build a critter. Root = the body; everything is placed relative to it (front = -Z).
function PetFollow.build(look): Model
	local smooth = blenderPet(look)
	if smooth then
		return smooth
	end
	local model = Instance.new("Model")
	model.Name = "Pet"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, neon: boolean?, transparency: number?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = offset
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local c, a, glow = look.color, look.accent, look.glow == true
	local kind = look.kind
	local root: Part
	local eyeY, eyeZ, eyeX = 0.15, -0.81, 0.3
	if kind == "bee" then
		root = part("Root", Vector3.new(1.3, 1.1, 1.6), CFrame.new(), c, glow)
		for _, z in { -0.15, 0.45 } do
			part("Stripe", Vector3.new(1.34, 1.14, 0.25), CFrame.new(0, 0, z), a)
		end
		for _, x in { -0.75, 0.75 } do
			part("Wing", Vector3.new(0.9, 0.08, 0.7), CFrame.new(x, 0.65, 0.1) * CFrame.Angles(0, 0, math.rad(x > 0 and -20 or 20)), WHITE, false, 0.35)
		end
		part("Sting", Vector3.new(0.2, 0.2, 0.35), CFrame.new(0, -0.1, 0.95), a)
	elseif kind == "bug" then
		root = part("Root", Vector3.new(1.5, 0.8, 1.7), CFrame.new(), c, glow)
		part("Head", Vector3.new(0.9, 0.6, 0.5), CFrame.new(0, -0.05, -1.05), a)
		part("Line", Vector3.new(0.08, 0.82, 1.7), CFrame.new(), a)
		for _, d in { { -0.4, -0.2 }, { 0.4, -0.2 }, { -0.4, 0.45 }, { 0.4, 0.45 } } do
			part("Dot", Vector3.new(0.3, 0.84, 0.3), CFrame.new(d[1], 0, d[2]), a)
		end
		eyeZ, eyeY = -1.31, 0
	elseif kind == "snail" then
		root = part("Root", Vector3.new(0.8, 0.5, 2), CFrame.new(0, -0.3, 0), c, glow)
		part("Shell", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 0.5, 0.3), a)
		part("Swirl", Vector3.new(1.24, 0.5, 0.5), CFrame.new(0, 0.55, 0.3), shade(a, 0.7))
		for _, x in { -0.2, 0.2 } do
			part("Stalk", Vector3.new(0.12, 0.6, 0.12), CFrame.new(x, 0.25, -0.85), c)
			part("Eye", Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, 0.6, -0.85), BLACK)
		end
		eyeX = 0
	elseif kind == "bunny" then
		root = part("Root", Vector3.new(1.2, 1.1, 1.4), CFrame.new(), c, glow)
		part("Head", Vector3.new(1, 0.95, 0.9), CFrame.new(0, 0.55, -0.6), c)
		for _, x in { -0.25, 0.25 } do
			part("Ear", Vector3.new(0.25, 1, 0.2), CFrame.new(x, 1.45, -0.6), c)
			part("EarIn", Vector3.new(0.13, 0.75, 0.22), CFrame.new(x, 1.45, -0.6), a)
		end
		part("Tail", Vector3.new(0.4, 0.4, 0.3), CFrame.new(0, 0.1, 0.8), WHITE)
		eyeY, eyeZ, eyeX = 0.7, -1.06, 0.25
	elseif kind == "mole" then
		root = part("Root", Vector3.new(1.4, 1, 1.8), CFrame.new(), c, glow)
		part("Nose", Vector3.new(0.4, 0.35, 0.3), CFrame.new(0, -0.05, -1.05), a)
		for _, x in { -0.6, 0.6 } do
			part("Claw", Vector3.new(0.45, 0.2, 0.4), CFrame.new(x, -0.45, -0.75), a)
		end
		eyeY, eyeZ, eyeX = 0.2, -0.91, 0.32
	elseif kind == "hedgehog" then
		root = part("Root", Vector3.new(1.3, 0.9, 1.6), CFrame.new(), a, glow)
		part("Back", Vector3.new(1.5, 0.75, 1.5), CFrame.new(0, 0.3, 0.25), c)
		for i = 0, 5 do
			local x = (i % 3 - 1) * 0.45
			local z = if i < 3 then 0 else 0.55
			part("Spike", Vector3.new(0.25, 0.5, 0.25), CFrame.new(x, 0.8, z) * CFrame.Angles(math.rad(25), 0, 0), shade(c, 0.6))
		end
		part("Nose", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, -0.05, -0.9), BLACK)
		eyeY, eyeZ, eyeX = 0.15, -0.81, 0.3
	elseif kind == "gnome" then
		root = part("Root", Vector3.new(1.1, 1, 1), CFrame.new(), c, false)
		part("Face", Vector3.new(0.9, 0.7, 0.9), CFrame.new(0, 0.8, 0), Color3.fromRGB(250, 205, 170))
		part("Beard", Vector3.new(0.95, 0.7, 0.3), CFrame.new(0, 0.45, -0.45), WHITE)
		part("Nose", Vector3.new(0.25, 0.25, 0.2), CFrame.new(0, 0.75, -0.55), Color3.fromRGB(240, 150, 140))
		part("Hat1", Vector3.new(1, 0.4, 1), CFrame.new(0, 1.3, 0), a, glow)
		part("Hat2", Vector3.new(0.7, 0.4, 0.7), CFrame.new(0, 1.65, 0.05), a, glow)
		part("Hat3", Vector3.new(0.35, 0.4, 0.35), CFrame.new(0, 2, 0.12), a, glow)
		eyeY, eyeZ, eyeX = 0.95, -0.46, 0.2
	elseif kind == "butterfly" then
		root = part("Root", Vector3.new(0.35, 0.35, 1.4), CFrame.new(), BLACK, false)
		for _, x in { -1, 1 } do
			part("WingTop", Vector3.new(1.2, 0.08, 0.9), CFrame.new(x * 0.75, 0.1, -0.3) * CFrame.Angles(0, 0, math.rad(x * -15)), c, glow)
			part("WingLow", Vector3.new(0.9, 0.08, 0.7), CFrame.new(x * 0.6, 0.05, 0.5) * CFrame.Angles(0, 0, math.rad(x * -15)), a, glow)
		end
		eyeY, eyeZ, eyeX = 0.1, -0.71, 0.1
	else
		root = part("Root", Vector3.new(1.2, 1.2, 1.2), CFrame.new(), c, glow)
	end
	if kind ~= "snail" then
		for _, x in { -eyeX, eyeX } do
			part("Eye", Vector3.new(0.2, 0.25, 0.08), CFrame.new(x, eyeY, eyeZ), BLACK)
		end
	end
	model.PrimaryPart = root
	return model
end

-------------------------------------------------------------------------------------------------------------
-- followers
-------------------------------------------------------------------------------------------------------------
type Follower = {
	model: Model,
	flies: boolean,
	cf: CFrame,
	phase: number,
	lift: number,
	parts: { { part: BasePart, rel: CFrame, wing: number } },
	list: { BasePart },
	cfs: { CFrame },
	-- motion state (timing: steps and turns speed up with the player, idle is slow and calm)
	hop: number, -- hop phase, advances with speed
	speed: number, -- smoothed ground speed
	yaw: number, -- smoothed facing
	lookOff: number, -- idle look-around offset (radians)
	lookAt: number, -- when the next idle glance starts
}
local folder = Instance.new("Folder")
folder.Name = "PetFollowers"
folder.Parent = workspace
local followers: { [Player]: { Follower } } = {}
local FLYING = { bee = true, butterfly = true }
-- rarer critters are bigger
local SIZE = { Common = 1, Uncommon = 1.06, Rare = 1.12, Epic = 1.2, Legendary = 1.3, Mythic = 1.38, Secret = 1.46 }
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local okFx, FxIds = pcall(require, ReplicatedStorage.MowALawn:FindFirstChild("FxIds"))
local FX = if okFx and type(FxIds) == "table" then FxIds else {}

-- Legendary and up sparkle; Mythic and Secret stand on a soft aura ring; Secret leaves a rainbow trail.
local function petFx(m: Model, def)
	local root = m.PrimaryPart :: BasePart
	local rank = RANK[def.rarity] or 1
	local color = Config.RARITY_COLORS[def.rarity] or Color3.new(1, 1, 1)
	if rank >= RANK.Legendary then
		local e = Instance.new("ParticleEmitter")
		e.Name = "PetSparkle"
		e.Texture = FX.spark or "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = if rank >= RANK.Secret then 6 else 3.5
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(0.4, 1)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 1, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.32), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.15)
		e.LightEmission = 0.6
		e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.Parent = root
	end
	if rank >= RANK.Mythic then
		local ring = Instance.new("Part")
		ring.Name = "AuraRing"
		ring.Size = Vector3.new(3.2, 0.05, 3.2)
		ring.Transparency = 1
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CFrame = root.CFrame * CFrame.new(0, -0.55, 0)
		ring.Parent = m
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = FX.ring or "rbxasset://textures/particles/sparkles_main.dds"
		d.Color3 = color
		d.Transparency = 0.35
		d.Parent = ring
	end
	if rank >= RANK.Secret then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-0.5, 0.3, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0.5, 0.3, 0)
		a1.Parent = root
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Lifetime = 0.6
		tr.LightEmission = 0.5
		tr.Transparency = NumberSequence.new(0.35, 1)
		tr.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 200)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 110)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(110, 230, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 170, 255)),
		})
		tr.Parent = root
	end
end

local function clear(p: Player)
	for _, f in followers[p] or {} do
		f.model:Destroy()
	end
	followers[p] = nil
end

local function rebuild(p: Player)
	clear(p)
	local list = p:GetAttribute("Pets")
	if type(list) ~= "string" or list == "" then
		return
	end
	local fs = {}
	for i, id in string.split(list, ",") do
		local def = Config.pet(id)
		if def then
			local m = PetFollow.build(def.look)
			m.Name = p.Name .. "_" .. id
			local size = SIZE[def.rarity] or 1
			if size ~= 1 then
				m:ScaleTo(size)
			end
			petFx(m, def)
			local root = m.PrimaryPart :: BasePart
			local rel, list, cfs = {}, {}, {}
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					local wing = if d.Name:sub(1, 9) == "AnimWingL" then -1 elseif d.Name:sub(1, 9) == "AnimWingR" then 1 else 0
					table.insert(rel, { part = d, rel = root.CFrame:ToObjectSpace(d.CFrame), wing = wing })
					table.insert(list, d)
					table.insert(cfs, d.CFrame)
				end
			end
			m.Parent = folder
			table.insert(fs, {
				model = m,
				flies = FLYING[def.look.kind] == true,
				cf = CFrame.new(),
				phase = i * 1.7,
				lift = 0.6 * (size - 1),
				parts = rel,
				list = list,
				cfs = cfs,
				hop = 0,
				speed = 0,
				yaw = 0,
				lookOff = 0,
				lookAt = os.clock() + 2 + i * 1.3,
			})
		end
	end
	followers[p] = fs
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuild(p)
	end)
	rebuild(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)
for _, p in Players:GetPlayers() do
	watch(p)
end

-- slots behind the player: middle, left, right
local SLOTS = { Vector3.new(0, 0, 4.2), Vector3.new(-3, 0, 3.2), Vector3.new(3, 0, 3.2) }

-- Shortest signed angle from a to b.
local function angleTo(a: number, b: number): number
	return (b - a + math.pi) % (math.pi * 2) - math.pi
end

-- Idle glance (the timing principle: a slow, careful look to one side, held, then a snappy turn back).
-- Returns the yaw offset `k` seconds into a glance of `dir` (+1 / -1).
local GLANCE = { out = 0.9, hold = 0.8, back = 0.22 }
local function glance(k: number, dir: number): number
	local turn = math.rad(38) * dir
	if k < GLANCE.out then
		local a = k / GLANCE.out
		return turn * (a * a * (3 - 2 * a)) -- slow in, slow out
	elseif k < GLANCE.out + GLANCE.hold then
		return turn
	end
	local a = math.min(1, (k - GLANCE.out - GLANCE.hold) / GLANCE.back)
	return turn * (1 - (1 - (1 - a) ^ 3)) -- quick snap back
end
local GLANCE_LEN = GLANCE.out + GLANCE.hold + GLANCE.back

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	-- the 3D egg hatch (client/HatchFx) plays right in front of the camera: pets would stand in the shot
	local hatching = cam ~= nil and cam:FindFirstChild("HatchFx") ~= nil
	-- Potato Mode: only your own pets and other players' close by
	local potato = Players.LocalPlayer:GetAttribute("Potato") == true
	for p, fs in followers do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local view = if potato and p ~= Players.LocalPlayer then 45 else VIEW_DISTANCE
		local far = hatching or not root or (root.Position - camPos).Magnitude > view
		for i, f in fs do
			if far then
				if f.model.Parent then
					f.model.Parent = nil
				end
				continue
			end
			if not f.model.Parent then
				f.model.Parent = folder
			end
			local r = root :: BasePart
			local groundY = r.Position.Y - (if hum then hum.HipHeight + r.Size.Y / 2 else 3)
			local flat = CFrame.new(r.Position) * CFrame.Angles(0, select(2, r.CFrame:ToEulerAnglesYXZ()), 0)
			local slot = flat:PointToWorldSpace(SLOTS[((i - 1) % #SLOTS) + 1])
			-- each pet follows a little looser than the one before (overlapping action, not one block)
			local alpha = 1 - math.exp(-dt * (8.5 - i * 1.2))
			local old = f.cf.Position
			local flatTarget = Vector3.new(slot.X, 0, slot.Z)
			local flatPos = Vector3.new(old.X, 0, old.Z):Lerp(flatTarget, alpha)
			local snapped = (Vector3.new(old.X, 0, old.Z) - flatTarget).Magnitude > 40
			if snapped then
				flatPos = flatTarget -- teleported / respawned: snap
				old = Vector3.new(flatPos.X, old.Y, flatPos.Z)
			end
			local step = (flatPos - Vector3.new(old.X, 0, old.Z)).Magnitude / math.max(dt, 1e-3)
			-- speed eases up fast and down slower, so a stop settles instead of freezing
			f.speed += (step - f.speed) * math.min(1, dt * (if step > f.speed then 10 else 4))
			local moving = math.clamp(f.speed / 8, 0, 1)
			-- hops: the faster it goes, the quicker the steps (spacing gets tighter); still = no hopping
			f.hop += dt * (1.2 + f.speed * 0.13) * moving
			local hop = math.abs(math.sin(f.hop * math.pi)) * moving
			local breathe = math.sin(t * 2.1 + f.phase) * 0.5 + 0.5
			local bob = if f.flies
				then 2.6 + math.sin(t * (2.2 + moving * 2) + f.phase) * (0.35 - moving * 0.15)
				else 0.6 + hop * 0.38
			local y = groundY + bob + f.lift
			local pos = Vector3.new(flatPos.X, if snapped then y else old.Y + (y - old.Y) * math.min(1, dt * 20), flatPos.Z)
			-- facing: turn toward where it's going (quicker the faster it moves), else the way the player faces
			local dir = flatTarget - flatPos
			local want = if dir.Magnitude > 0.4 then math.atan2(-dir.X, -dir.Z) else select(2, flat:ToEulerAnglesYXZ())
			f.yaw += angleTo(f.yaw, want) * math.min(1, dt * (3 + moving * 9))
			-- idle glances now and then: slow look away, hold, snap back
			if moving > 0.2 then
				f.lookAt = math.max(f.lookAt, now + 1.5)
				f.lookOff += (0 - f.lookOff) * math.min(1, dt * 10)
			elseif now >= f.lookAt then
				local k = now - f.lookAt
				local side = if (math.floor(f.lookAt) % 2) == 0 then 1 else -1
				f.lookOff = glance(k, side)
				if k > GLANCE_LEN then
					f.lookOff = 0
					f.lookAt = now + 3 + ((f.phase * 7.3 + f.lookAt) % 4)
				end
			end
			f.cf = CFrame.new(pos) * CFrame.Angles(0, f.yaw + f.lookOff, 0)
			-- squash and stretch: squashed as a hop lands, stretched on the way up; idle walkers breathe
			local sy = if f.flies
				then 1 + math.sin(t * 3 + f.phase) * 0.03
				else (0.9 + hop * 0.14) * moving + (1 + (breathe - 0.5) * 0.04) * (1 - moving)
			local sxz = 1 / math.sqrt(sy)
			-- fliers flap faster when they hurry; walkers' little wings only flutter while moving
			local flapRate = if f.flies then 18 + moving * 10 else 8
			local flapAmp = if f.flies then 0.5 + moving * 0.1 else 0.25 * moving
			local flap = math.sin(t * flapRate + f.phase) * flapAmp
			for k, pr in f.parts do
				local rel = pr.rel
				local pos2 = Vector3.new(rel.X * sxz, (rel.Y + 0.6) * sy - 0.6, rel.Z * sxz)
				local cf = CFrame.new(pos2) * rel.Rotation
				if pr.wing ~= 0 then
					local hinge = Vector3.new(0, pos2.Y, pos2.Z)
					cf = CFrame.new(hinge) * CFrame.Angles(0, 0, pr.wing * flap) * CFrame.new(-hinge) * cf
				end
				f.cfs[k] = f.cf * cf
			end
			workspace:BulkMoveTo(f.list, f.cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
end)

return PetFollow
