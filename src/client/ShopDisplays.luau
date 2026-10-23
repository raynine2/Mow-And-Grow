-- The camp's little touches (client only):
--   * Tool Shop displays (server/RunBuilder: Folders "ToolDisplay" with a ToolId): the status lamp and the price
--     follow you - green OWNED, yellow when you can afford it, grey when you can't yet. Walk up to one and its tool
--     turns slowly on the spot with a soft outline, so you can see what it is.
--   * The camp fountain (model with the Fountain attribute): a gentle water spray from its top, drips off the bowl.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local Assets = require(ReplicatedStorage:WaitForChild("VFXLib"):WaitForChild("Assets"))
local State = require(script.Parent.State)

local ShopDisplays = {}
local player = Players.LocalPlayer

local GREEN = Color3.fromRGB(110, 230, 90)
local YELLOW = Color3.fromRGB(255, 206, 60)
local GREY = Color3.fromRGB(150, 150, 160)
local NEAR = 9

type Display = { folder: Instance, id: string, index: number, cost: number, item: Model?, base: CFrame?, lamp: BasePart?, price: TextLabel? }
local displays: { Display } = {}

local function toolIndex(id: string): (number, any)
	for i, t in Config.TOOLS do
		if t.id == id then
			return i, t
		end
	end
	return 0, nil
end

local function scan()
	table.clear(displays)
	for _, f in workspace:GetDescendants() do
		if f.Name == "ToolDisplay" and f:GetAttribute("ToolId") then
			local id = f:GetAttribute("ToolId") :: string
			local i, def = toolIndex(id)
			if def then
				local item: Model? = nil
				for _, c in f:GetChildren() do
					if c:IsA("Model") and c:GetAttribute("DisplayItem") then
						item = c
					end
				end
				local priceGui = f:FindFirstChild("PriceText")
				local price = priceGui and priceGui:FindFirstChildWhichIsA("TextLabel", true)
				table.insert(displays, { folder = f, id = id, index = i, cost = def.cost, item = item, base = item and item:GetPivot(), lamp = f:FindFirstChild("StatusLamp") :: BasePart?, price = price })
			end
		end
	end
end

local function refresh()
	local d = State.data
	local run = d and d.run
	for _, s in displays do
		local owned = run ~= nil and s.index <= (run.tool or 0)
		local afford = run ~= nil and (run.coins or 0) >= s.cost
		local col = if owned then GREEN elseif afford then YELLOW else GREY
		if s.lamp then
			s.lamp.Color = col
			s.lamp.Material = if owned or afford then Enum.Material.Neon else Enum.Material.Glass
			s.lamp.Transparency = if owned or afford then 0.35 else 0.15
		end
		if s.price then
			s.price.Text = if owned then "OWNED" else "$" .. Format.commas(s.cost)
			s.price.TextColor3 = if owned then GREEN elseif afford then Color3.fromRGB(150, 245, 100) else Color3.fromRGB(200, 196, 190)
		end
	end
end

State.on("data", refresh)

-- (a whole-workspace scan is a hitch in a big world: only scan again when the world changes or a display
-- turns up, not on a timer)
local displaysDirty = true
workspace.DescendantAdded:Connect(function(d)
	if d.Name == "ToolDisplay" then
		displaysDirty = true
	end
end)
task.spawn(function()
	local scannedWorld: Instance? = nil
	while true do
		local world = workspace:FindFirstChild("World")
		if #displays > 0 and not displays[1].folder.Parent then
			table.clear(displays)
			displaysDirty = true
		end
		if world and (displaysDirty or world ~= scannedWorld) then
			displaysDirty = false
			scannedWorld = world
			scan()
			refresh()
		end
		task.wait(2)
	end
end)

-- the tool you're looking at turns on the spot
local hl = Instance.new("Highlight")
hl.FillColor = Color3.fromRGB(255, 240, 200)
hl.FillTransparency = 0.88
hl.OutlineColor = Color3.fromRGB(255, 214, 120)
hl.OutlineTransparency = 0.2
hl.DepthMode = Enum.HighlightDepthMode.Occluded
hl.Enabled = false
hl.Parent = workspace
local current: Display? = nil
local spinAngle = 0

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestD = nil, NEAR
	if root then
		for _, s in displays do
			if s.item and s.base then
				local p = s.base.Position
				local d = Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z).Magnitude
				if d < bestD then
					best, bestD = s, d
				end
			end
		end
	end
	if best ~= current then
		if current and current.item and current.base and current.item.Parent then
			current.item:PivotTo(current.base)
		end
		current = best
		spinAngle = 0
		hl.Adornee = if best then best.item else nil
		hl.Enabled = best ~= nil
	end
	if current and current.item and current.base and current.item.Parent then
		spinAngle += dt * 1.1
		-- turn about the vertical through the middle of the tool's box, with a little lift
		local box = current.item:GetBoundingBox()
		local centre = current.base:PointToObjectSpace(box.Position)
		local _ = centre
		local mid = current.base * CFrame.new(current.base:PointToObjectSpace(box.Position))
		local pivotFromMid = mid:ToObjectSpace(current.base)
		local lift = math.min(spinAngle * 0.6, 0.35)
		current.item:PivotTo(CFrame.new(mid.Position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, spinAngle, 0) * (mid - mid.Position) * pivotFromMid)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- the fountain
-------------------------------------------------------------------------------------------------------------
local fountains: { [Instance]: boolean } = {}
local function spray(m: Model)
	if fountains[m] then
		return
	end
	fountains[m] = true
	local top = m:GetPivot() * CFrame.new(0, 5.45, 0)
	local holder = Instance.new("Part")
	holder.Name = "FountainFx"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.4, 0.2, 0.4)
	holder.CFrame = top
	holder.Parent = m
	local jet = Instance.new("ParticleEmitter")
	jet.Name = "Jet"
	jet.Texture = Assets.Tex.Glow
	jet.Rate = 40
	jet.Lifetime = NumberRange.new(0.9, 1.2)
	jet.Speed = NumberRange.new(6.5, 8)
	jet.SpreadAngle = Vector2.new(9, 9)
	jet.Acceleration = Vector3.new(0, -16, 0)
	jet.Drag = 0.4
	jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0.16) })
	jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1) })
	jet.Color = ColorSequence.new(Color3.fromRGB(230, 248, 255), Color3.fromRGB(150, 210, 245))
	jet.LightEmission = 0.25
	jet.LightInfluence = 0.8
	jet.Parent = holder
	-- drips off the rim of the big bowl
	local rim = Instance.new("Part")
	rim.Name = "DripRing"
	rim.Anchored = true
	rim.CanCollide = false
	rim.CanQuery = false
	rim.CanTouch = false
	rim.Transparency = 1
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(0.1, 4.6, 4.6)
	rim.CFrame = m:GetPivot() * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	rim.Parent = m
	local drips = Instance.new("ParticleEmitter")
	drips.Texture = Assets.Tex.Glow
	drips.Shape = Enum.ParticleEmitterShape.Cylinder
	drips.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	drips.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	drips.Rate = 26
	drips.Lifetime = NumberRange.new(0.5, 0.7)
	drips.Speed = NumberRange.new(0.3, 0.8)
	drips.Acceleration = Vector3.new(0, -14, 0)
	drips.Size = NumberSequence.new(0.14)
	drips.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.9) })
	drips.Color = ColorSequence.new(Color3.fromRGB(200, 236, 255))
	drips.LightInfluence = 0.8
	drips.Parent = rim
end

-- once for what's there, then whatever turns up (no whole-workspace scan on a timer)
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("Fountain") then
		task.spawn(spray, d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		task.defer(function()
			if d.Parent and d:GetAttribute("Fountain") then
				spray(d)
			end
		end)
	end
end)
-- forget fountains that are gone (a world rebuild)
task.spawn(function()
	while true do
		task.wait(10)
		for m in fountains do
			if not m.Parent then
				fountains[m] = nil
			end
		end
	end
end)

return ShopDisplays
