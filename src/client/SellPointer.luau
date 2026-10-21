-- When your bag is full: a chunky yellow arrow (the same look as client/Guide's arrow) that floats beside you at
-- knee height and points flat along the ground toward the nearest place to sell (the hub's shredder or a
-- drop-off), bobbing and nudging forward so it catches the eye. It fades away once you're at the sell pad.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local SellPointer = {}
local player = Players.LocalPlayer

local RADIUS = 5.5 -- how far from you it floats
local HEIGHT = -1.4 -- below the HumanoidRootPart (about knee height)
local NEAR = 14 -- hide it this close to the sell spot

local arrow = Instance.new("Model")
arrow.Name = "SellPointer"
local function brick(size: Vector3, offset: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = UI.colors.yellow
	p.Size = size
	p.Transparency = 1
	p:SetAttribute("Offset", offset)
	p.Parent = arrow
	return p
end
-- lying flat, pointing along -Z: a shaft and a stepped brick head
brick(Vector3.new(0.9, 0.6, 2.6), Vector3.new(0, 0, 1.3))
brick(Vector3.new(3.2, 0.6, 0.9), Vector3.new(0, 0, -0.45))
brick(Vector3.new(2.1, 0.6, 0.9), Vector3.new(0, 0, -1.35))
brick(Vector3.new(1.0, 0.6, 0.9), Vector3.new(0, 0, -2.25))
local outline = Instance.new("Highlight")
outline.FillTransparency = 1
outline.OutlineColor = Color3.fromRGB(56, 32, 16)
outline.DepthMode = Enum.HighlightDepthMode.Occluded
outline.Enabled = false
outline.Parent = arrow
arrow.Parent = workspace

-- the nearest sell spot, or nil when the bag isn't full
local function sellTarget(from: Vector3): Vector3?
	local d = State.data
	local run = d and d.run
	local w = State.world
	if not run or not w or w.loading or not d.carryMax or run.carry < d.carryMax then
		return nil
	end
	local best: Vector3? = w.sellPos
	local bestD = if best then (best - from).Magnitude else math.huge
	for _, spot in w.sellSpots or {} do
		local dd = (spot - from).Magnitude
		if dd < bestD then
			best, bestD = spot, dd
		end
	end
	return best
end

local shown = 0 -- 0..1, eased so it fades in and out
local yaw = 0

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = root and select(2, pcall(sellTarget, root.Position))
	local flat: Vector3? = nil
	if root and typeof(target) == "Vector3" then
		local d = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if d.Magnitude > NEAR then
			flat = d.Unit
		end
	end
	shown = math.clamp(shown + (if flat then dt * 4 else -dt * 4), 0, 1)
	outline.Enabled = shown > 0.05
	if shown <= 0 or not root then
		for _, p in arrow:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
		return
	end
	if flat then
		-- turn smoothly toward the target
		local want = math.atan2(-flat.X, -flat.Z)
		local diff = (want - yaw + math.pi) % (2 * math.pi) - math.pi
		yaw += diff * math.min(1, dt * 10)
	end
	local t = os.clock()
	local dir = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local nudge = math.abs(math.sin(t * 4)) * 0.8 -- a little forward push, like it's tugging you along
	local pos = root.Position + dir * (RADIUS + nudge) + Vector3.new(0, HEIGHT + math.sin(t * 3) * 0.2, 0)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	for _, p in arrow:GetChildren() do
		if p:IsA("BasePart") then
			p.CFrame = base * CFrame.new(p:GetAttribute("Offset") :: Vector3)
			p.Transparency = 1 - shown
		end
	end
end)

return SellPointer
