-- A bouncing brick arrow that shows the next thing to do, so nobody is ever lost:
--   lobby, never played  -> the SOLO pad
--   run, nothing cut yet -> the grass
--   bag full             -> the nearest Shredder's SELL ring (the hub's or the drop-off)
--   can afford next tool -> the Tool Shop
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Coach = require(script.Parent.Coach)

local Guide = {}
local C = UI.colors
local player = Players.LocalPlayer

local arrow = Instance.new("Model")
arrow.Name = "GuideArrow"
local function brick(size: Vector3, offset: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic -- not neon: the bloom blew it up into a yellow blob
	p.Color = color
	p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Offset", offset)
	p.Parent = arrow
	return p
end
-- shaft + stepped point (a little brick pyramid pointing down)
brick(Vector3.new(1.4, 3, 1.4), Vector3.new(0, 3.4, 0), C.yellow)
brick(Vector3.new(4.2, 1, 4.2), Vector3.new(0, 1.6, 0), C.yellow)
brick(Vector3.new(2.8, 1, 2.8), Vector3.new(0, 0.6, 0), C.yellow)
brick(Vector3.new(1.4, 1, 1.4), Vector3.new(0, -0.4, 0), C.yellow)
local ring = Instance.new("Part")
ring.Anchored = true
ring.CanCollide = false
ring.CanQuery = false
ring.CanTouch = false
ring.CastShadow = false
ring.Shape = Enum.PartType.Cylinder
ring.Material = Enum.Material.SmoothPlastic
ring.Color = C.yellow
ring.Transparency = 0.5
ring.Size = Vector3.new(0.2, 8, 8)
ring.Parent = arrow
-- a dark cartoon outline keeps the plain yellow arrow readable against the grass and the sky
local outline = Instance.new("Highlight")
outline.FillTransparency = 1
outline.OutlineColor = Color3.fromRGB(56, 32, 16)
outline.DepthMode = Enum.HighlightDepthMode.Occluded
outline.Parent = arrow
arrow.Parent = workspace

local target: Vector3? = nil
local targetLift = 7 -- how high the arrow floats over the target (the coach lifts it over tall clumps)

local function findPart(path: { string }): BasePart?
	local node: Instance? = workspace:FindFirstChild("World")
	for _, name in path do
		node = node and node:FindFirstChild(name, true)
	end
	return if node and node:IsA("BasePart") then node else nil
end

local function pickTarget(): Vector3?
	local d = State.data
	if not d then
		return nil
	end
	if d.mode == "Lobby" then
		if d.stats and d.stats.runs == 0 and not d.run then
			local pad = findPart({ "PadInfo1" })
			return if pad then Vector3.new(pad.Position.X, 0, pad.Position.Z) else nil
		end
		return nil
	end
	local run = d.run
	local w = State.world
	if not run or not w or w.loading then
		return nil
	end
	if run.carry >= d.carryMax and w.sellPos then
		-- the nearest shredder: the hub's or the drop-off
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local best = w.sellPos
		if root and w.sellSpots then
			local bestD = math.huge
			for _, spot in w.sellSpots do
				local dd = (spot - root.Position).Magnitude
				if dd < bestD then
					best, bestD = spot, dd
				end
			end
		end
		return best
	end
	if w.boss then
		return nil
	end
	local nextTool = Config.TOOLS[run.tool + 1]
	if nextTool and run.coins >= nextTool.cost and run.carry == 0 then
		local shop = findPart({ "TOOL SHOP", "Counter" })
		if shop then
			return Vector3.new(shop.Position.X, 0, shop.Position.Z) + shop.CFrame.LookVector * 5
		end
	end
	if d.stats and d.stats.cut == 0 then
		return Config.zoneEntry(math.clamp(w.zone or 1, 1, #Config.ZONES))
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.25)
		-- while the first-run coach (client/Coach) is on, the arrow shows its step
		if Coach.active() then
			local p, lift = Coach.target()
			target, targetLift = p, lift or 7
		else
			local ok, res = pcall(pickTarget)
			target, targetLift = if ok then res else nil, 7
		end
	end
end)

-- where the arrow is drawn: it glides to a new target instead of jumping there (a new target far away, or the
-- first one, it's put on straight away)
local shown: Vector3? = nil
local shownLift = 7
RunService.RenderStepped:Connect(function(dt)
	outline.Enabled = target ~= nil
	if not target then
		shown = nil
		for _, p in arrow:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
		return
	end
	if not shown or (shown - target).Magnitude > 80 then
		shown, shownLift = target, targetLift
	else
		local k = 1 - math.exp(-dt * 7)
		shown = shown:Lerp(target, k)
		shownLift += (targetLift - shownLift) * k
	end
	local at = shown :: Vector3
	local t = os.clock()
	local bob = math.abs(math.sin(t * 3.2)) * 1.6
	-- turned to face the camera instead of spinning (side-on, the spinning arrow read as a flat yellow bar)
	local cam = workspace.CurrentCamera
	local look = if cam then (cam.CFrame.Position - at) * Vector3.new(1, 0, 1) else Vector3.zero
	local yaw = if look.Magnitude > 0.1 then math.atan2(look.X, look.Z) else 0
	local base = CFrame.new(at + Vector3.new(0, shownLift + bob, 0)) * CFrame.Angles(0, yaw, 0)
	-- right at the target (the coach's clump glow already shows it) the arrow fades out
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = if root then ((root.Position - at) * Vector3.new(1, 0, 1)).Magnitude else 999
	local fade = math.clamp((near - 9) / 6, 0, 1)
	outline.Enabled = fade > 0.5
	for _, p in arrow:GetChildren() do
		if not p:IsA("BasePart") then
			continue -- the outline Highlight
		end
		local part = p :: BasePart
		if part == ring then
			local s = 7 + math.sin(t * 4) * 1
			part.Size = Vector3.new(0.2, s, s)
			part.CFrame = CFrame.new(at + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
			part.Transparency = 1 - 0.45 * fade
		else
			part.CFrame = base * CFrame.new(part:GetAttribute("Offset") :: Vector3)
			part.Transparency = 1 - fade
		end
	end
end)

return Guide
