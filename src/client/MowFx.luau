-- Mowing juice (client). Small and soft on purpose: the mowing itself is the show.
--   * Lawn stripes: every mower (push mowers and ride-ons, yours and other players' nearby) leaves a pale or dark
--     band of freshly cut lawn behind it, toned by which way it went, like a real striped lawn. They fade after a
--     while. Only on grass, never on paths or the yard.
--   * The side chute: a plume of clippings out of the deck while the mower is actually cutting, and a faint dust
--     at the wheels while it rolls.
--   * A clump going down under a mower: a soft grass-green ring rolls out over the ground (a VFX Forge mesh effect:
--     Model > Start/End parts, played with VFXLib.Forge) and a few cut blades drift down.
--   * The Mega Scythe: a few violet wisps rise off every clump it bites, the reaper's touch.
-- Pooled: the stripe parts are reused, one chute per mower, nothing left running when a mower goes away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local FxIds = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxIds")) :: { [string]: string }
local VFXLib = ReplicatedStorage:WaitForChild("VFXLib")
local Assets = require(VFXLib:WaitForChild("Assets"))
local Forge = require(VFXLib:WaitForChild("Forge"))

local MowFx = {}
local player = Players.LocalPlayer

local STRIPE_MAX = 260 -- stripe pieces alive at once (all mowers together)
local STRIPE_STEP = 1.3 -- studs between pieces
local STRIPE_LIFE = 14 -- seconds a stripe stays before fading
local STRIPE_FADE = 2.5
local NEAR = 110 -- mowers further than this from the camera are left alone
local GRASS_DEFAULT = Color3.fromRGB(110, 190, 70)

local folder = Instance.new("Folder")
folder.Name = "MowFx"
folder.Parent = workspace

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include

local function groundFilter()
	local world = workspace:FindFirstChild("World")
	local ground = world and world:FindFirstChild("Ground")
	groundRay.FilterDescendantsInstances = if ground then { ground, workspace.Terrain } else { workspace.Terrain }
end

-------------------------------------------------------------------------------------------------------------
-- lawn stripes
-------------------------------------------------------------------------------------------------------------
type Stripe = { part: Part, born: number, fading: boolean }
local stripes: { Stripe } = {}
local nextStripe = 1
local layer = 0 -- each new piece sits a hair higher, so crossing stripes never flicker

local function stripePart(): Stripe
	local s = stripes[nextStripe]
	if not s then
		local p = Instance.new("Part")
		p.Name = "Stripe"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		s = { part = p, born = 0, fading = false }
		stripes[nextStripe] = s
	end
	nextStripe = nextStripe % STRIPE_MAX + 1
	return s
end

-- Lay one piece of stripe from `a` to `b` (both on the ground), `width` wide.
local function layStripe(a: Vector3, b: Vector3, width: number, color: Color3)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if d.Magnitude < 0.05 then
		return
	end
	layer = (layer + 1) % 40
	local s = stripePart()
	local mid = (a + b) / 2
	s.part.Size = Vector3.new(width, 0.05, d.Magnitude + 0.5)
	s.part.CFrame = CFrame.lookAt(mid, mid + d) + Vector3.new(0, 0.03 + layer * 0.0015, 0)
	s.part.Color = color
	s.part.Transparency = 0.45
	s.born = os.clock()
	s.fading = false
end

-- The stripe's tone: mowing one way bends the grass light, the other way dark (the axis you're mostly moving along
-- decides, so straight passes up and down a lawn alternate like the real thing).
local function stripeColor(ground: Color3, dir: Vector3): Color3
	local along = if math.abs(dir.X) > math.abs(dir.Z) then dir.X else dir.Z
	if along >= 0 then
		return ground:Lerp(Color3.fromRGB(240, 250, 215), 0.12)
	end
	return Color3.new(ground.R * 0.84, ground.G * 0.88, ground.B * 0.82)
end

-------------------------------------------------------------------------------------------------------------
-- the side chute (one per mower)
-------------------------------------------------------------------------------------------------------------
type Chute = { part: Part, clips: ParticleEmitter, dust: ParticleEmitter }

local function newChute(): Chute
	local p = Instance.new("Part")
	p.Name = "Chute"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.4, 0.4, 1.2)
	p.Parent = folder
	local clips = Instance.new("ParticleEmitter")
	clips.Name = "Clippings"
	clips.Texture = FxIds.splinter or "rbxasset://textures/particles/sparkles_main.dds"
	clips.EmissionDirection = Enum.NormalId.Right
	clips.Shape = Enum.ParticleEmitterShape.Box
	clips.Rate = 0
	clips.Lifetime = NumberRange.new(0.45, 0.85)
	clips.Speed = NumberRange.new(8, 13)
	clips.SpreadAngle = Vector2.new(22, 30)
	clips.Acceleration = Vector3.new(0, -32, 0)
	clips.Drag = 1.6
	clips.Rotation = NumberRange.new(0, 360)
	clips.RotSpeed = NumberRange.new(-320, 320)
	clips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0.14) })
	clips.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
	clips.LightEmission = 0.05
	clips.Parent = p
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = Assets.Tex.Glow
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rate = 0
	dust.Lifetime = NumberRange.new(1, 1.6)
	dust.Speed = NumberRange.new(0.6, 1.6)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Drag = 1
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.82), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(Color3.fromRGB(236, 240, 200))
	dust.LightInfluence = 1
	dust.Parent = p
	return { part = p, clips = clips, dust = dust }
end

-------------------------------------------------------------------------------------------------------------
-- the mowers in view
-------------------------------------------------------------------------------------------------------------
type Mower = { model: Model, last: Vector3?, chute: Chute, width: number, cutAt: number, color: Color3, seen: number }
local mowers: { [Model]: Mower } = {}
local myCutAt = 0 -- your own mower cut something just now (the server's chips say so)
local lastGrass = GRASS_DEFAULT

-- Where the mower's deck meets the ground (CFrame facing its front), and its width.
local function deckOf(m: Model): (CFrame?, number)
	if m.Name == "PushMowerModel" then
		-- push mowers ride 4.3 studs in front of the character on the ground (server/Tools; 3.4 until 28 Oct, when
		-- the mower moved out to where your hands hold its bar); the model's own pivot doesn't follow its welded
		-- parts, so go by the character
		local char = m.Parent
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then
			return nil, 0
		end
		return root.CFrame * CFrame.new(0, -(hum.HipHeight + root.Size.Y / 2), -4.3), 2.6
	end
	local body = m.PrimaryPart
	if not body then
		return nil, 0
	end
	local _, size = m:GetBoundingBox()
	-- (report #12) a zero-turn's wide deck leaves a wide stripe (server/Mowers sets Swath from Config.MOWERS)
	local swath = m:GetAttribute("Swath") :: number?
	return body.CFrame * CFrame.new(0, -1.2, -size.Z * 0.3), swath or math.min(size.X * 0.9, 8)
end

local function collect(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		local m = p.Character and p.Character:FindFirstChild("PushMowerModel")
		if m and m:IsA("Model") then
			table.insert(list, m)
		end
	end
	local world = workspace:FindFirstChild("World")
	local rides = world and world:FindFirstChild("Mowers")
	if rides then
		for _, m in rides:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart then
				table.insert(list, m)
			end
		end
	end
	return list
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then
		return
	end
	acc = 0
	local now = os.clock()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	groundFilter()
	for _, m in collect() do
		local deck, width = deckOf(m)
		if not deck or (deck.Position - cam.CFrame.Position).Magnitude > NEAR then
			continue
		end
		local st = mowers[m]
		if not st then
			st = { model = m, last = nil, chute = newChute(), width = width, cutAt = 0, color = lastGrass, seen = now }
			mowers[m] = st
		end
		st.seen = now
		local mine = m:IsDescendantOf(player.Character or folder) or m:GetAttribute("Owner") == player.UserId
		local cutting = now - (if mine then myCutAt else st.cutAt) < 0.7
		local pos = deck.Position
		local moved = if st.last then Vector3.new(pos.X - st.last.X, 0, pos.Z - st.last.Z) else Vector3.zero
		local speed = moved.Magnitude / (1 / 30)
		-- the chute sits on the deck's right side, blowing out sideways
		st.chute.part.CFrame = deck * CFrame.new(width * 0.5, 0.5, 0)
		st.chute.clips.Rate = if cutting and speed > 0.5 then 34 else (if cutting then 12 else 0)
		st.chute.clips.Color = ColorSequence.new(st.color:Lerp(Color3.new(1, 1, 0.85), 0.15), st.color)
		st.chute.dust.Rate = if speed > 2 then math.min(2 + speed * 0.25, 7) else 0
		-- stripes: a piece every STRIPE_STEP studs, only on grass
		if not st.last then
			st.last = pos
		elseif moved.Magnitude >= STRIPE_STEP then
			local from, to = st.last, pos
			st.last = pos
			if moved.Magnitude < 12 then -- (a teleport is no stripe)
				local hit = workspace:Raycast(to + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), groundRay)
				-- (Potato Mode makes the ground smooth plastic: its real material is kept in PotatoMat)
				if hit and (hit.Material == Enum.Material.Grass or hit.Instance:GetAttribute("PotatoMat") == "Grass") then
					local y = hit.Position.Y
					layStripe(Vector3.new(from.X, y, from.Z), Vector3.new(to.X, y, to.Z), width, stripeColor(hit.Instance.Color, moved.Unit))
				end
			end
		end
	end
	-- mowers gone or out of range: drop their chutes
	for m, st in mowers do
		if not m.Parent or now - st.seen > 0.5 then
			st.chute.part:Destroy()
			mowers[m] = nil
		end
	end
	-- old stripes fade away
	for _, s in stripes do
		if not s.fading and s.born > 0 and now - s.born > STRIPE_LIFE then
			s.fading = true
			TweenService:Create(s.part, TweenInfo.new(STRIPE_FADE), { Transparency = 1 }):Play() -- (from its 0.45)
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- a clump going down under a mower: a soft ring rolls out, a few blades drift down
-------------------------------------------------------------------------------------------------------------
-- The ring is a VFX Forge mesh effect (Model with Start/End parts; Forge tweens size and the decal's fade between
-- them). Built once, moved and re-emitted each time.
local ringFx = Instance.new("Model")
ringFx.Name = "SoftRing"
ringFx:SetAttribute("EffectDuration", NumberRange.new(0.55, 0.65))
ringFx:SetAttribute("Decal_StartTransparency", 0.35)
ringFx:SetAttribute("Decal_EndTransparency", 1)
local function ringPart(name: string, size: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(size, 0.05, size)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = Assets.Tex.RingThin
	d.Parent = p
	p.Parent = ringFx
	return p
end
local ringStart = ringPart("Start", 2.5)
local ringEnd = ringPart("End", 11)
ringFx.Parent = ReplicatedStorage -- a template outside the workspace: Forge plays a copy of it

local holder = Instance.new("Part")
holder.Name = "MowFxHolder"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.one
holder.Parent = folder
local blades = Instance.new("ParticleEmitter")
blades.Name = "Blades"
blades.Texture = FxIds.splinter or "rbxasset://textures/particles/sparkles_main.dds"
blades.Enabled = false
blades.Shape = Enum.ParticleEmitterShape.Sphere
blades.Lifetime = NumberRange.new(1.4, 2.2)
blades.Speed = NumberRange.new(3, 6)
blades.SpreadAngle = Vector2.new(50, 50)
blades.EmissionDirection = Enum.NormalId.Top
blades.Acceleration = Vector3.new(0, -3.5, 0) -- they float down slowly, like cut grass in the air
blades.Drag = 2.2
blades.Rotation = NumberRange.new(0, 360)
blades.RotSpeed = NumberRange.new(-120, 120)
blades.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.18) })
blades.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.1), NumberSequenceKeypoint.new(1, 1) })
blades.Parent = holder

-- reaper wisps (Mega Scythe hits)
local wisps = Instance.new("ParticleEmitter")
wisps.Name = "Wisps"
wisps.Texture = Assets.Tex.Glow
wisps.Enabled = false
wisps.Shape = Enum.ParticleEmitterShape.Sphere
wisps.Lifetime = NumberRange.new(0.8, 1.3)
wisps.Speed = NumberRange.new(2, 4)
wisps.SpreadAngle = Vector2.new(25, 25)
wisps.EmissionDirection = Enum.NormalId.Top
wisps.Acceleration = Vector3.new(0, 3, 0)
wisps.Drag = 1.5
wisps.LightEmission = 0.8
wisps.LightInfluence = 0
wisps.Color = ColorSequence.new(Color3.fromRGB(230, 200, 255), Color3.fromRGB(140, 80, 255))
wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.2) })
wisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(1, 1) })
wisps.Parent = holder

local function softRing(pos: Vector3, color: Color3)
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), groundRay)
	local y = if hit then hit.Position.Y + 0.06 else pos.Y + 0.06
	local tint = color:Lerp(Color3.new(1, 1, 0.9), 0.45)
	for _, p in { ringStart, ringEnd } do
		p.CFrame = CFrame.new(pos.X, y, pos.Z)
		;(p:FindFirstChildOfClass("Decal") :: Decal).Color3 = tint
	end
	if not Forge.Emit(ringFx) then
		-- no Forge: the same ring by hand
		local p = ringStart:Clone()
		p.Parent = folder
		local d = p:FindFirstChildOfClass("Decal") :: Decal
		d.Transparency = 0.35
		TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = ringEnd.Size }):Play()
		TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		task.delay(0.65, p.Destroy, p)
	end
end

local function nearMower(pos: Vector3): Mower?
	for _, st in mowers do
		local deck = deckOf(st.model)
		if deck and Vector3.new(deck.Position.X - pos.X, 0, deck.Position.Z - pos.Z).Magnitude < 12 then
			return st
		end
	end
	return nil
end

local function heldId(): string?
	local char = player.Character
	local t = char and char:FindFirstChildOfClass("Tool")
	return t and t:GetAttribute("ToolId") :: string?
end

State.on("fx", function(kind, d)
	if type(d) ~= "table" or typeof(d.pos) ~= "Vector3" then
		return
	end
	if typeof(d.color) == "Color3" then
		lastGrass = d.color
	end
	-- a clump that drops in one go is a "fell" (it topples, then lands as a "cut" drawn by client/Fx itself)
	local mineFell = kind == "fell" and d.by == player.UserId
	if kind == "chip" or mineFell then
		local id = heldId()
		if id == "PushMower" or id == "LaserMower" or id == "WeedWhacker" or (player.Character and player.Character:FindFirstChildOfClass("Humanoid") and (player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid).SeatPart) then
			myCutAt = os.clock()
			for _, st in mowers do
				st.color = lastGrass
			end
		elseif id == "MegaScythe" then
			holder.CFrame = CFrame.new(d.pos + Vector3.new(0, 1.5, 0))
			wisps:Emit(5)
		end
	end
	if kind == "fell" then
		-- under a mower: the ring rolls out when it lands
		local at = if typeof(d.land) == "Vector3" then d.land else d.pos
		local st = nearMower(d.pos)
		if st then
			st.cutAt = os.clock()
			local color = if typeof(d.color) == "Color3" then d.color else GRASS_DEFAULT
			task.delay(if type(d.time) == "number" then d.time else 0.7, function()
				softRing(at, color)
				holder.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
				blades.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 0.85), 0.2), color)
				blades:Emit(6)
			end)
		end
	elseif kind == "cut" then
		local st = nearMower(d.pos)
		if st then
			st.cutAt = os.clock()
			local color = if typeof(d.color) == "Color3" then d.color else GRASS_DEFAULT
			softRing(d.pos, color)
			holder.CFrame = CFrame.new(d.pos + Vector3.new(0, 1, 0))
			blades.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 0.85), 0.2), color)
			blades:Emit(6)
		elseif d.by == player.UserId and heldId() == "MegaScythe" then
			holder.CFrame = CFrame.new(d.pos + Vector3.new(0, 2, 0))
			wisps:Emit(9)
		end
	end
end)

return MowFx
