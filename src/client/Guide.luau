-- A bouncing brick arrow that shows the next thing to do, so nobody is ever lost:
--   lobby, never played  -> the SOLO pad
--   run, nothing cut yet -> the grass
--   bag full             -> the Shredder's SELL ring
--   can afford next tool -> the Tool Shop
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Guide = {}
local C = UI.colors

local arrow = Instance.new("Model")
arrow.Name = "GuideArrow"
local function brick(size: Vector3, offset: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
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
ring.Material = Enum.Material.Neon
ring.Color = C.yellow
ring.Transparency = 0.5
ring.Size = Vector3.new(0.2, 8, 8)
ring.Parent = arrow
arrow.Parent = workspace

local target: Vector3? = nil

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
		return w.sellPos
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
		return Vector3.new(0, 0, Config.zoneStartZ(w.zone or 1) + 6)
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.4)
		local ok, res = pcall(pickTarget)
		target = if ok then res else nil
	end
end)

RunService.RenderStepped:Connect(function()
	if not target then
		for _, p in arrow:GetChildren() do
			(p :: BasePart).Transparency = 1
		end
		return
	end
	local t = os.clock()
	local bob = math.abs(math.sin(t * 3.2)) * 1.6
	local base = CFrame.new(target + Vector3.new(0, 7 + bob, 0)) * CFrame.Angles(0, t * 1.5, 0)
	for _, p in arrow:GetChildren() do
		local part = p :: BasePart
		if part == ring then
			local s = 7 + math.sin(t * 4) * 1
			part.Size = Vector3.new(0.2, s, s)
			part.CFrame = CFrame.new(target + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
			part.Transparency = 0.55
		else
			part.CFrame = base * CFrame.new(part:GetAttribute("Offset") :: Vector3)
			part.Transparency = 0
		end
	end
end)

return Guide
