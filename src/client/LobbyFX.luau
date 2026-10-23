-- Lobby ambience and touches (client), all driven by tags the lobby map carries (server/LobbyKit):
--   LobbyFX spots: "motes" (dust drifting over the clearing), "sparkle" (chests, stall pads), "mist", "bats"
--   LobbyLantern: flickering lantern lights near the camera
--   LobbyPadZone: stepping on a glowing pad plays a VFX Forge sparkle burst and opens its Window
--   LobbyBoard: the YOU row (from this player's "LB_<key>" attribute, server/LobbyBoards)
--   LobbyCountdown: the event board's "??? ARRIVES IN" timer; its "Get Notified" prompt asks for notifications
-- Particle amounts follow VFXLib's Budget (phones get fewer; the bats are skipped on low).
local CollectionService = game:GetService("CollectionService")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VFX = require(ReplicatedStorage:WaitForChild("VFXLib"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local Tex = VFX.Assets.Tex
local Budget = VFX.Budget

local LobbyFX = {}

local function seq(...: number): NumberSequence
	local pts = { ... }
	local kps = {}
	for i = 1, #pts, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(pts[i], pts[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-------------------------------------------------------------------------------------------------------------
-- ambient spots
-------------------------------------------------------------------------------------------------------------
local bats: { { parts: { BasePart }, centre: Vector3, phase: number, r: number } } = {}

local function makeBat(): { BasePart }
	local function piece(size: Vector3): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Color = Color3.fromRGB(46, 30, 60)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = workspace
		return p
	end
	return { piece(Vector3.new(0.5, 0.45, 0.8)), piece(Vector3.new(1.3, 0.08, 0.7)), piece(Vector3.new(1.3, 0.08, 0.7)) }
end

local function onSpot(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local kind = spot:GetAttribute("Kind")
	local color = spot:GetAttribute("Color")
	local c = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 240, 190)
	if kind == "motes" then
		emitter(spot, {
			Texture = Tex.Glow, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(Color3.fromRGB(255, 244, 200)), LightEmission = 0.8,
			Size = seq(0, 0.12, 0.5, 0.26, 1, 0.1), Transparency = seq(0, 1, 0.25, 0.35, 0.75, 0.4, 1, 1),
			Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0.15, 0.12, 0), Drag = 0.4, Rate = Budget.Rate(16),
		})
	elseif kind == "sparkle" then
		emitter(spot, {
			Texture = Tex.Star4, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(c, Color3.new(1, 1, 1)), LightEmission = 1,
			Size = seq(0, 0, 0.3, 0.45, 1, 0), Transparency = seq(0, 0.1, 1, 0.6),
			Lifetime = NumberRange.new(0.9, 1.6), Speed = NumberRange.new(0.6, 1.6), SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
			Rate = Budget.Rate(5),
		})
	elseif kind == "mist" then
		emitter(spot, {
			Texture = Tex.SmokePuff4x4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Shape = Enum.ParticleEmitterShape.Box, Color = ColorSequence.new(Color3.fromRGB(235, 225, 255)),
			Size = seq(0, 2.5, 1, 5), Transparency = seq(0, 1, 0.3, 0.7, 1, 1), Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(60, 60), Rate = Budget.Rate(1.5),
		})
	elseif kind == "bats" and not Budget.IsLow() then
		for i = 1, 3 do
			table.insert(bats, { parts = makeBat(), centre = spot.Position, phase = i * 2.1, r = 4 + i * 1.3 })
		end
	end
end

local function offSpot(spot: Instance)
	if spot:GetAttribute("Kind") == "bats" then
		for i = #bats, 1, -1 do
			if (bats[i].centre - (spot :: BasePart).Position).Magnitude < 0.5 then
				for _, p in bats[i].parts do
					p:Destroy()
				end
				table.remove(bats, i)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- glowing pads: a VFX Forge burst, and the stall's window
-------------------------------------------------------------------------------------------------------------
-- A one-shot sparkle fountain + flash, built the way VFX Forge reads a burst (ParticleEmitter + EmitCount
-- attribute) and played with Forge's emit module; plain Emit() when Forge isn't there.
local function burst(pos: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = "PadBurst"
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(pos)
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local stars = emitter(att, {
		Texture = Tex.Star4, Color = ColorSequence.new(Color3.new(1, 1, 1), color), LightEmission = 1, Enabled = false,
		Size = seq(0, 0.7, 1, 0), Transparency = seq(0, 0, 0.7, 0.2, 1, 1), Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(8, 15), SpreadAngle = Vector2.new(55, 55), EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -16, 0), Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
	})
	stars:SetAttribute("EmitCount", Budget.Count(22))
	local flash = emitter(att, {
		Texture = Tex.Glow, Color = ColorSequence.new(color), LightEmission = 1, Enabled = false,
		Size = seq(0, 1, 1, 9), Transparency = seq(0, 0.25, 1, 1), Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0),
	})
	flash:SetAttribute("EmitCount", 1)
	anchor.Parent = workspace
	if not VFX.Forge.Emit(anchor) then
		stars:Emit(Budget.Count(22))
		flash:Emit(1)
	end
	task.delay(2.5, function()
		anchor:Destroy()
	end)
end
LobbyFX.burst = burst

type Zone = { model: Model, cf: CFrame, size: Vector3, window: string?, claim: string?, color: Color3, inside: boolean, sized: number }
local zones: { [Instance]: Zone } = {}

local function onZone(m: Instance)
	if not m:IsA("Model") then
		return
	end
	local cf, size = m:GetBoundingBox()
	local w = m:GetAttribute("Window")
	local c = m:GetAttribute("Color")
	local claim = m:GetAttribute("Claim")
	zones[m] = {
		model = m,
		cf = cf,
		size = size,
		window = if type(w) == "string" then w else nil,
		claim = if type(claim) == "string" then claim else nil,
		color = if typeof(c) == "Color3" then c else Color3.new(1, 1, 1),
		inside = false,
		sized = os.clock(),
	}
end

local function checkZones()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local now = os.clock()
	for m, z in zones do
		if not m.Parent then
			zones[m] = nil
			continue
		end
		-- measure again now and then: with streaming the pad's parts arrive after the model (an empty model
		-- measures 0 x 0), and a saved map can move the pad after it's tagged
		if now - z.sized > 1 then
			z.sized = now
			z.cf, z.size = z.model:GetBoundingBox()
		end
		local p = z.cf:PointToObjectSpace(root.Position)
		local inside = math.abs(p.X) <= z.size.X / 2 and math.abs(p.Z) <= z.size.Z / 2 and p.Y > -1 and p.Y < 6
		if inside ~= z.inside then
			z.inside = inside
			if inside then
				burst(Vector3.new(root.Position.X, z.cf.Position.Y + 0.3, root.Position.Z), z.color)
				if z.claim then
					-- walk-on reward (the daily bay): the server gives it if it's ready, or says when it will be
					State.fire("Claim", z.claim)
				elseif z.window then
					UI.open(z.window)
				end
			elseif not z.claim and z.window and UI.isOpen(z.window) then
				UI.close()
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- leaderboards' YOU rows, the event countdown, Get Notified
-------------------------------------------------------------------------------------------------------------
local function fillYou(board: Instance)
	local key = board:GetAttribute("Key")
	local gui = board:FindFirstChildWhichIsA("SurfaceGui")
	local you = gui and gui:FindFirstChild("You")
	if type(key) ~= "string" or not you then
		return
	end
	local parts = string.split(tostring(player:GetAttribute("LB_" .. key) or "-|-"), "|");
	(you :: any).Rank.Text = parts[1] or "-";
	(you :: any).Value.Text = parts[2] or "-";
	(you :: any).PlayerName.Text = "YOU - " .. player.DisplayName;
	(you :: any).Icon.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(player.UserId)
end

player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 3) == "LB_" then
		for _, b in CollectionService:GetTagged("LobbyBoard") do
			fillYou(b)
		end
	end
end)

local function countdown(holder: Instance)
	local ends = holder:GetAttribute("EndsAt")
	local gui = holder:FindFirstChildWhichIsA("BillboardGui")
	local label = gui and gui:FindFirstChild("Time") :: TextLabel?
	if type(ends) ~= "number" or not label then
		return
	end
	local left = math.floor(ends - workspace:GetServerTimeNow())
	if left <= 0 then
		label.Text = "IT'S HERE!"
		return
	end
	label.Text = ("%dD %02dH %02dM %02dS"):format(left // 86400, (left % 86400) // 3600, (left % 3600) // 60, left % 60)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("Notify") ~= true then
		return
	end
	local ok, can = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	if ok and can then
		pcall(function()
			ExperienceNotificationService:PromptOptIn()
		end)
	else
		UI.toast("You'll see it here first - check back when the timer ends!", "yellow")
	end
end)

-------------------------------------------------------------------------------------------------------------
-- wiring
-------------------------------------------------------------------------------------------------------------
local function watch(tagName: string, added: (Instance) -> (), removed: ((Instance) -> ())?)
	for _, inst in CollectionService:GetTagged(tagName) do
		task.spawn(added, inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(added)
	if removed then
		CollectionService:GetInstanceRemovedSignal(tagName):Connect(removed)
	end
end

watch("LobbyFX", onSpot, offSpot)
watch("LobbyPadZone", onZone, function(m)
	zones[m] = nil
end)
watch("LobbyBoard", fillYou)

local lanterns: { [BasePart]: { light: PointLight, base: number, seed: number } } = {}
watch("LobbyLantern", function(core)
	local light = core:FindFirstChildOfClass("PointLight")
	if core:IsA("BasePart") and light then
		lanterns[core] = { light = light, base = light.Brightness, seed = math.random() * 100 }
	end
end, function(core)
	lanterns[core :: BasePart] = nil
end)

local acc, slow = 0, 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	-- bats circle the event board, flapping
	for _, b in bats do
		local a = t * 1.3 + b.phase
		local pos = b.centre + Vector3.new(math.cos(a) * b.r, math.sin(t * 1.7 + b.phase) * 0.8, math.sin(a) * b.r)
		local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
		local flap = math.sin(t * 14 + b.phase) * 0.7
		b.parts[1].CFrame = cf
		b.parts[2].CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.85, 0, 0)
		b.parts[3].CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.85, 0, 0)
	end
	acc += dt
	if acc < 1 / 15 then
		return
	end
	acc = 0
	checkZones()
	-- lanterns flicker (only the ones near the camera)
	local cam = workspace.CurrentCamera.CFrame.Position
	for core, l in lanterns do
		if (core.Position - cam).Magnitude < 140 then
			l.light.Brightness = l.base * (0.82 + 0.18 * math.noise(t * 3, l.seed) + 0.1 * math.sin(t * 9 + l.seed))
		end
	end
	slow += 1
	if slow % 15 == 0 then
		for _, h in CollectionService:GetTagged("LobbyCountdown") do
			countdown(h)
		end
	end
end)

return LobbyFX
