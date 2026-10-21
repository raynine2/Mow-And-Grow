-- The gates between zones, as THIS player sees them (client). Every player owns different zones, so each client
-- decides locally: a gate you own is open for you (blockers gone, bridge or stones solid), a gate you don't own is
-- shut (blockers solid, the broken bridge a ghost you'd fall through). The server checks where you are anyway.
-- Buying a zone plays its gate's opening: the barrier fades, the rocks crumble, the ice shatters, the bridge
-- builds plank by plank, the stones rise. Village teleport pads dim for zones you don't own yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Zones = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Zones"))
local State = require(script.Parent.State)

local Gates = {}

local owned = 0 -- highest zone this player owns (0 = not known yet)
local opened: { [number]: boolean } = {}
local original: { [BasePart]: { t: number, cf: CFrame } } = {}

local function world(): Instance?
	return workspace:FindFirstChild("World")
end

local function remember(p: BasePart)
	if not original[p] then
		original[p] = { t = p.Transparency, cf = p.CFrame }
	end
end

-- Snap a gate to open/shut without any effect (on join, or when the world loads).
local function setGate(gate: Instance, open: boolean)
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") then
			remember(p)
			local o = original[p]
			if p.Name == "Blocker" then
				p.CanCollide = not open
				p.Transparency = if open then 1 else o.t
				p.CFrame = o.cf
			elseif p.Name == "Walkway" then
				p.CanCollide = open
				p.Transparency = if open then o.t else 0.82
				p.CFrame = o.cf
			end
		end
	end
	local prompt = gate:FindFirstChild("UnlockPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not open
	end
end

-- The opening effect for gate kind `kind`, then it's left open.
local function playOpen(gate: Instance, kind: string)
	local blockers, walk = {}, {}
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") then
			remember(p)
			if p.Name == "Blocker" then
				table.insert(blockers, p)
			elseif p.Name == "Walkway" then
				table.insert(walk, p)
			end
		end
	end
	for _, p in blockers do
		p.CanCollide = false
		local o = original[p]
		if kind == "rockslide" then
			-- boulders tumble down into the ground and vanish
			TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = o.cf * CFrame.new(0, -14, 0) * CFrame.Angles(math.random(), math.random(), 0), Transparency = 1 }):Play()
		elseif kind == "icewall" then
			-- the ice cracks and shatters outward
			TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = p.Size * 1.08, Transparency = 1 }):Play()
		else
			-- a barrier fades away
			TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
		end
	end
	-- bridges build plank by plank, stones rise from below
	if #walk > 1 then
		local first = original[walk[1]].cf.Position
		table.sort(walk, function(a, b)
			return (original[a].cf.Position - first).Magnitude < (original[b].cf.Position - first).Magnitude
		end)
	end
	for i, p in walk do
		local o = original[p]
		p.Transparency = 1
		p.CFrame = o.cf * CFrame.new(0, -6, 0)
		task.delay(0.06 * i, function()
			p.CanCollide = true
			TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = o.cf, Transparency = o.t }):Play()
		end)
	end
	local prompt = gate:FindFirstChild("UnlockPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
end

-- Village pads to zones you don't own yet are dimmed.
local function setPads(level: number)
	local w = world()
	local pads = w and w:FindFirstChild("Pads")
	if not pads then
		return
	end
	for _, p in pads:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("PadKind") == "toZone" then
			local z = p:GetAttribute("Zone") or 99
			local gui = p:FindFirstChildOfClass("SurfaceGui")
			local label = gui and gui:FindFirstChildOfClass("TextLabel")
			if label then
				local def = Zones.list[z]
				label.Text = if z <= level then string.upper(def.name) else "LOCKED"
				label.TextColor3 = if z <= level then Color3.new(1, 1, 1) else Color3.fromRGB(120, 120, 130)
			end
		end
	end
end

local seen: { [Instance]: boolean } = {}

-- `onlyNew`: just the gates we haven't set up yet (they streamed in late)
local function refresh(animate: boolean, onlyNew: boolean?)
	local w = world()
	local gates = w and w:FindFirstChild("Gates")
	if not gates then
		return
	end
	for _, gate in gates:GetChildren() do
		local z = gate:GetAttribute("Zone")
		if type(z) == "number" and not (onlyNew and seen[gate]) then
			seen[gate] = true
			local open = z <= owned
			if open and not opened[z] and animate then
				playOpen(gate, gate:GetAttribute("Kind") or "barrier")
			else
				setGate(gate, open)
			end
			opened[z] = open
		end
	end
	setPads(owned)
end

State.on("data", function(d)
	local level = d and d.run and d.run.zone or 1
	if level ~= owned then
		local first = owned == 0
		owned = level
		refresh(not first)
	end
end)

-- the world may stream in or load after our first state
task.spawn(function()
	while true do
		task.wait(2)
		if owned > 0 then
			refresh(false, true)
		end
	end
end)

return Gates
