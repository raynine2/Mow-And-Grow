-- Pets following players: every client draws every player's equipped critters (player attribute "Pets", set by
-- server/Pets) as small blocky models. Client-only, anchored, no collisions; far-away pets are hidden (no-lag rule).
-- PetFollow.build(look) is also used for anything else that wants a critter model.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local PetFollow = {}

local BLACK = Color3.fromRGB(25, 22, 28)
local WHITE = Color3.fromRGB(250, 250, 250)
local VIEW_DISTANCE = 150

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- Build a critter. Root = the body; everything is placed relative to it (front = -Z).
function PetFollow.build(look): Model
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
type Follower = { model: Model, flies: boolean, cf: CFrame, phase: number, parts: { { part: BasePart, rel: CFrame } } }
local folder = Instance.new("Folder")
folder.Name = "PetFollowers"
folder.Parent = workspace
local followers: { [Player]: { Follower } } = {}
local FLYING = { bee = true, butterfly = true }

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
			local root = m.PrimaryPart :: BasePart
			local rel = {}
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(rel, { part = d, rel = root.CFrame:ToObjectSpace(d.CFrame) })
				end
			end
			m.Parent = folder
			table.insert(fs, { model = m, flies = FLYING[def.look.kind] == true, cf = CFrame.new(), phase = i * 1.7, parts = rel })
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
local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local alpha = 1 - math.exp(-dt * 8)
	for p, fs in followers do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local far = not root or (root.Position - camPos).Magnitude > VIEW_DISTANCE
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
			local bob = if f.flies then 2.6 + math.sin(t * 3 + f.phase) * 0.35 else 0.6 + math.abs(math.sin(t * 6 + f.phase)) * 0.35
			local target = Vector3.new(slot.X, groundY + bob, slot.Z)
			local pos = f.cf.Position:Lerp(target, alpha)
			if (f.cf.Position - target).Magnitude > 40 then
				pos = target -- teleported / respawned: snap
			end
			local moving = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			local look = if moving.Magnitude > 0.3 then moving.Unit else flat.LookVector
			f.cf = CFrame.lookAt(pos, pos + look)
			for _, pr in f.parts do
				pr.part.CFrame = f.cf * pr.rel
			end
		end
	end
end)

return PetFollow
