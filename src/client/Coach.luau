-- The first two minutes, impossible to get lost in. Until you've bought your first upgrade (Hold) in your first
-- run, a card at the bottom of the screen gives you one step at a time, and the world points at it:
--   1. PUNCH THE GRASS      the nearest clump glows and the yellow arrow (client/Guide) floats over it
--   2. PICK UP YOUR GRASS   the arrow over your bundles on the ground
--   3. FILL YOUR BAG        back to the nearest clump, with your bag count on the card
--   4. SELL YOUR GRASS      the arrow over the shredder and a flowing dotted trail on the ground to it
--   5. BUY AN UPGRADE       an arrow beside the UPGRADES button; in the window, the Hold card glows
-- Each step is read from the live state (bag, bundles on the ground, coins, upgrades), so it always matches
-- what's happening, also after a rejoin. Finishing gets a "You're a natural!" and the quest list takes over.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local Coach = {}
local player = Players.LocalPlayer
local C = UI.colors

type Step = { id: string, title: string, sub: string, target: Vector3?, lift: number?, clump: Model?, trail: boolean? }

-------------------------------------------------------------------------------------------------------------
-- what's in the world
-------------------------------------------------------------------------------------------------------------
local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isClump(m: Instance): boolean
	return m:IsA("Model") and (m.Name == "Clump" or (m.Name:sub(1, 5) == "tuft_" and m.Name:sub(-4) ~= "_cut"))
end

-- Uncut clumps in the open areas: { model, zone }, refreshed every couple of seconds.
type Clump = { model: Model, z: number }
local clumps: { Clump } = {}
local clumpsAt = 0
local function refreshClumps()
	clumpsAt = os.clock()
	table.clear(clumps)
	local world = workspace:FindFirstChild("World")
	local grass = world and world:FindFirstChild("Grass")
	if not grass then
		return
	end
	for _, zf in grass:GetChildren() do
		local z = tonumber(zf.Name:match("(%d+)$")) or 1
		for _, d in zf:GetDescendants() do
			if isClump(d) then
				table.insert(clumps, { model = d :: Model, z = z })
			end
		end
	end
end

local function nearestClump(from: Vector3, maxZone: number): Model?
	if os.clock() - clumpsAt > 2 then
		refreshClumps()
	end
	local best, bestD = nil, math.huge
	for _, c in clumps do
		if c.z <= maxZone and c.model.Parent then
			local p = c.model:GetPivot().Position
			local d = (p - from).Magnitude
			if d < bestD then
				best, bestD = c.model, d
			end
		end
	end
	return best
end

local function nearestDrop(from: Vector3): Vector3?
	local world = workspace:FindFirstChild("World")
	local loot = world and world:FindFirstChild("Loot")
	if not loot then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in loot:GetChildren() do
		if m:GetAttribute("Owner") == player.UserId then
			local p = if m:IsA("Model") then m:GetPivot().Position elseif m:IsA("BasePart") then m.Position else nil
			if p then
				local d = (p - from).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
	end
	return best
end

local function nearestSell(from: Vector3): Vector3?
	local w = State.world
	if not w then
		return nil
	end
	local best = w.sellPos
	local bestD = if best then (best - from).Magnitude else math.huge
	for _, spot in w.sellSpots or {} do
		local d = (spot - from).Magnitude
		if d < bestD then
			best, bestD = spot, d
		end
	end
	return best
end

-------------------------------------------------------------------------------------------------------------
-- which step
-------------------------------------------------------------------------------------------------------------
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local finished = false -- finished in this session (or never needed)
local shownThisSession = false

local function holdLevel(run: any): number
	return (run.upgrades and run.upgrades.hold) or 0
end

-- Is this a player who still needs the coach? (first run, Hold not bought yet, not an old hand)
local function needed(d: any): boolean
	local run = d.run
	if not run or d.mode ~= "Run" then
		return false
	end
	local s = d.stats or {}
	return (s.runs or 0) == 0 and (s.cut or 0) < 400 and holdLevel(run) < 1
end

local function pick(): Step?
	local d = State.data
	local w = State.world
	local root = myRoot()
	if not d or not w or w.loading or not root or not needed(d) then
		return nil
	end
	local run = d.run
	local max = d.carryMax or Config.BASE_CARRY
	local here = root.Position
	local stats = d.stats or {}
	local function clumpStep(id: string, title: string, sub: string): Step
		local m = nearestClump(here, run.zone or 1)
		local h = if m then (m:GetAttribute("Height") :: number? or 6) else 0
		return { id = id, title = title, sub = sub, target = if m then m:GetPivot().Position else nil, lift = h + 2, clump = m }
	end
	if (stats.cut or 0) == 0 and run.carry == 0 and (run.ground or 0) == 0 then
		return clumpStep("punch", "PUNCH THE GRASS", if touch then "Aim at a clump and tap to chop it down" else "Aim at a clump and click to chop it down")
	end
	if not d.endless and run.carry >= max then
		return { id = "sell", title = "SELL YOUR GRASS", sub = "Your bag is full! Follow the trail and step on SELL at the shredder", target = nearestSell(here), lift = 4, trail = true }
	end
	if (run.ground or 0) > 0 then
		local drop = nearestDrop(here)
		if drop then
			return { id = "collect", title = "PICK UP YOUR GRASS", sub = "Walk over the bundles to put them in your bag", target = drop, lift = 2 }
		end
	end
	local holdCost = Config.upgradeCost("hold", 0)
	if run.coins >= holdCost then
		return { id = "upgrade", title = "BUY YOUR FIRST UPGRADE", sub = if touch then "Tap UPGRADES and buy HOLD: keep chopping while you hold" else "Press TAB and buy HOLD: keep chopping while you hold the button" }
	end
	return clumpStep("fill", ("FILL YOUR BAG   %d / %d"):format(run.carry + (run.ground or 0), max), "Chop more grass, then sell it at the shredder for coins")
end

-------------------------------------------------------------------------------------------------------------
-- the card
-------------------------------------------------------------------------------------------------------------
local card = Instance.new("CanvasGroup")
card.Name = "Coach"
card.AnchorPoint = Vector2.new(0.5, 1)
card.Position = UDim2.new(0.5, 0, 1, -150)
card.Size = UDim2.fromOffset(560, 92)
card.BackgroundTransparency = 1
card.GroupTransparency = 1
card.Visible = false
card.ZIndex = 20
card.Parent = UI.gui
local wood = UI.planks(card, UDim2.new(1, 0, 1, 0), UDim2.new(), nil, 18)
wood.ZIndex = 20
local badge = UI.frame({ size = UDim2.fromOffset(64, 64), pos = UDim2.fromOffset(14, 14), color = C.yellow, parent = card, radius = 999, outline = 3, name = "Badge" })
badge.ZIndex = 21
local num = UI.text(badge, "1", UDim2.new(1, -10, 1, -10), { pos = UDim2.fromOffset(5, 5), stroke = 3 })
num.ZIndex = 22
local title = UI.text(card, "", UDim2.new(1, -110, 0, 44), { pos = UDim2.fromOffset(92, 6), align = Enum.TextXAlignment.Left, stroke = 3.5 })
title.ZIndex = 21
UI.gradient(title, C.yellow)
local sub = UI.text(card, "", UDim2.new(1, -110, 0, 30), { pos = UDim2.fromOffset(92, 52), align = Enum.TextXAlignment.Left, stroke = 2 })
sub.ZIndex = 21
local scale = Instance.new("UIScale")
scale.Parent = card

local ORDER = { punch = 1, collect = 2, fill = 3, sell = 4, upgrade = 5 }
local shownId: string? = nil

local function showCard(step: Step?)
	if not step then
		if card.Visible then
			TweenService:Create(card, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
			task.delay(0.26, function()
				if shownId == nil then
					card.Visible = false
				end
			end)
		end
		shownId = nil
		return
	end
	title.Text = step.title
	sub.Text = step.sub
	if step.id ~= shownId then
		local first = shownId == nil
		shownId = step.id
		num.Text = tostring(ORDER[step.id] or 1)
		card.Visible = true
		TweenService:Create(card, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if not first then
			Sound.play("pickup", 0.05) -- a little "next!"
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- markers: the clump glow, the trail, the HUD arrow, the Hold card glow
-------------------------------------------------------------------------------------------------------------
local glow = Instance.new("Highlight")
glow.Name = "CoachGlow"
glow.FillColor = C.yellow
glow.OutlineColor = C.yellow
glow.FillTransparency = 1
glow.OutlineTransparency = 1
glow.DepthMode = Enum.HighlightDepthMode.Occluded
glow.Parent = workspace

local trailFolder = Instance.new("Folder")
trailFolder.Name = "CoachTrail"
trailFolder.Parent = workspace
local DOTS = 18
local SPACING = 3.2
local dots: { Part } = {}
for i = 1, DOTS do
	local p = Instance.new("Part")
	p.Name = "Dot"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.SmoothPlastic
	p.Color = C.yellow
	p.Size = Vector3.new(0.12, 1.1, 1.1)
	p.Transparency = 1
	p.Parent = trailFolder
	dots[i] = p
end
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude

local function hideTrail()
	for _, p in dots do
		p.Transparency = 1
	end
end

local function drawTrail(from: Vector3, to: Vector3)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local len = flat.Magnitude
	if len < 8 then
		hideTrail()
		return
	end
	local dir = flat.Unit
	local skip: { Instance } = { trailFolder }
	if player.Character then
		table.insert(skip, player.Character)
	end
	groundRay.FilterDescendantsInstances = skip
	local flow = (os.clock() * 6) % SPACING -- the dots slide toward the target
	for i, p in dots do
		local along = 2.5 + (i - 1) * SPACING + flow
		if along > len - 3 then
			p.Transparency = 1
			continue
		end
		local x = from + dir * along
		local hit = workspace:Raycast(Vector3.new(x.X, from.Y + 6, x.Z), Vector3.new(0, -20, 0), groundRay)
		local y = if hit then hit.Position.Y else from.Y - 2.8
		p.CFrame = CFrame.new(x.X, y + 0.1, x.Z) * CFrame.Angles(0, 0, math.rad(90))
		-- fade in near you and out toward the end of the visible stretch
		local k = (i - 1) / DOTS
		p.Transparency = 0.15 + 0.7 * k * k
	end
end

-- the arrow beside the UPGRADES button (pointing right, at it)
local hudArrow = Instance.new("Frame")
hudArrow.Name = "CoachArrow"
hudArrow.BackgroundTransparency = 1
hudArrow.Size = UDim2.fromOffset(70, 40)
hudArrow.AnchorPoint = Vector2.new(1, 0.5)
hudArrow.Visible = false
hudArrow.ZIndex = 30
hudArrow.Parent = UI.gui
local shaft = UI.frame({ size = UDim2.fromOffset(40, 16), pos = UDim2.fromOffset(0, 12), color = C.yellow, parent = hudArrow, radius = 4, outline = 3 })
shaft.ZIndex = 30
local head = UI.frame({ size = UDim2.fromOffset(28, 28), pos = UDim2.fromOffset(36, 6), color = C.yellow, parent = hudArrow, radius = 4, outline = 3 })
head.Rotation = 45
head.ZIndex = 31

local function findButton(name: string): GuiObject?
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	for _, d in pg:GetDescendants() do
		if d:IsA("TextButton") and d.Name == name and d.Visible then
			return d
		end
	end
	return nil
end

-- the Hold card in the open Upgrades window
local cardGlow = Instance.new("UIStroke")
cardGlow.Name = "CoachGlow"
cardGlow.Color = C.yellow
cardGlow.Thickness = 0
cardGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function holdCard(): GuiObject?
	if not UI.isOpen("Upgrades") then
		return nil
	end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local holdName = (Config.upgrade("hold") or { name = "Hold" }).name
	for _, d in (pg and pg:GetDescendants() or {}) do
		if d:IsA("TextLabel") and d.Text == holdName and d.Visible then
			-- the card: the first ancestor frame big enough to be one
			local a = d.Parent
			while a and a:IsA("GuiObject") do
				if a:IsA("Frame") and a.AbsoluteSize.X >= 150 and a.AbsoluteSize.Y >= 60 then
					return a
				end
				a = a.Parent
			end
		end
	end
	return nil
end

-------------------------------------------------------------------------------------------------------------
-- run it
-------------------------------------------------------------------------------------------------------------
local step: Step? = nil
Coach.step = nil :: Step?

-- What client/Guide's arrow should point at while the coach is on: (position, height above it) or nil.
function Coach.target(): (Vector3?, number?)
	if step and step.target then
		return step.target, step.lift
	end
	return nil, nil
end

-- Is the coach running (so other hints stay out of the way)?
function Coach.active(): boolean
	return step ~= nil
end

local function cutsceneOn(): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and cam.CameraType ~= Enum.CameraType.Custom -- the run's fly-over intro
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local ok, res = pcall(pick)
		local s = if ok then res else nil
		if s and cutsceneOn() then
			s = nil
		end
		if s then
			shownThisSession = true
		elseif shownThisSession and not finished then
			-- the coach was on and the last step got done: Hold is bought
			local d = State.data
			if d and d.run and holdLevel(d.run) >= 1 then
				finished = true
				UI.toast("You're a natural! Follow your quests (top left) from here.", "green")
				Sound.play("upgrade")
			end
		end
		step = s
		Coach.step = s
		showCard(s)
	end
end)

RunService.RenderStepped:Connect(function()
	local s = step
	local t = os.clock()
	-- the clump glow
	if s and s.clump and s.clump.Parent then
		glow.Adornee = s.clump
		glow.OutlineTransparency = 0.1 + 0.35 * (0.5 + 0.5 * math.sin(t * 5))
		glow.FillTransparency = 0.82 + 0.1 * math.sin(t * 5)
	else
		glow.Adornee = nil
	end
	-- the trail
	local root = myRoot()
	if s and s.trail and s.target and root then
		drawTrail(root.Position, s.target)
	else
		hideTrail()
	end
	-- the HUD arrow, then the Hold card once the window is open
	local wantArrow = false
	if s and s.id == "upgrade" then
		local c = holdCard()
		if c then
			cardGlow.Parent = c
			cardGlow.Thickness = 4 + 2 * math.sin(t * 6)
		else
			cardGlow.Parent = nil
			local b = findButton("UPGRADES")
			if b then
				wantArrow = true
				local pos = b.AbsolutePosition
				local size = b.AbsoluteSize
				hudArrow.Position = UDim2.fromOffset(pos.X - 6 - math.abs(math.sin(t * 4)) * 14, pos.Y + size.Y * 0.4)
			end
		end
	else
		cardGlow.Parent = nil
	end
	hudArrow.Visible = wantArrow
end)

return Coach
