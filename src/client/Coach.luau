-- The first two minutes, impossible to get lost in. Until you've bought your first upgrade (Hold) in your first
-- run, a card at the bottom of the screen gives you one step at a time, and the world points at it:
--   1. MOW THE GRASS        the nearest clump glows and the yellow arrow (client/Guide) floats over it (with the
--                           dotted trail leading there when it's far, like from the village). A first-timer's
--                           loaned Push Mower (Config.FIRST_TIMER) is told to walk into it; hand tools to click.
--                           (report 28 Oct: no "punch" or "chop": they're Chop A Forest's words, this is mowing)
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
local Skin = require(script.Parent.Skin)

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

-- The clump the arrow is on. It stays the target until it's cut, or until another clump is a lot nearer (you
-- walked away from it): re-picking the nearest one every check made the arrow hop from clump to clump as you
-- walked (owner, 27 Oct: "the arrow keeps swapping on different grass").
local stuck: Model? = nil
local function nearestClump(from: Vector3, maxZone: number): Model?
	if os.clock() - clumpsAt > 2 then
		refreshClumps()
	end
	local best, bestD = nil, math.huge
	for _, c in clumps do
		-- (checked again: one cut since the list was made is no target any more)
		if c.z <= maxZone and c.model.Parent and isClump(c.model) then
			local p = c.model:GetPivot().Position
			local d = (p - from).Magnitude
			if d < bestD then
				best, bestD = c.model, d
			end
		end
	end
	local keep = stuck
	if keep and keep.Parent and isClump(keep) then
		local d = (keep:GetPivot().Position - from).Magnitude
		if d < bestD * 2 + 15 then
			return keep
		end
	end
	stuck = best
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

-- What the tool in your hands is: "auto" (walk into the grass) or "swing" (click), or nil.
local function heldKind(): string?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("Kind") :: string?
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
		local at = if m then m:GetPivot().Position else nil
		-- far from the grass (you spawn in the village): the trail leads the way
		local far = at ~= nil and Vector3.new(at.X - here.X, 0, at.Z - here.Z).Magnitude > 40
		if far then
			sub = "Follow the trail to the grass, then " .. sub:sub(1, 1):lower() .. sub:sub(2)
		end
		return { id = id, title = title, sub = sub, target = at, lift = h + 2, clump = m, trail = far }
	end
	local auto = heldKind() == "auto" or run.loaner ~= nil
	if (stats.cut or 0) == 0 and run.carry == 0 and (run.ground or 0) == 0 then
		if auto then
			return clumpStep("mow", "MOW THE GRASS", "Walk into the grass to mow it: grass sells for coins!")
		end
		return clumpStep("punch", "MOW THE GRASS", if touch then "Tap a clump to cut it: grass sells for coins!" else "Click a clump to cut it: grass sells for coins!")
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
		return { id = "upgrade", title = "BUY YOUR FIRST UPGRADE", sub = if touch then "Tap UPGRADES and buy HOLD: keep cutting, earn faster" else "Press TAB and buy HOLD: keep cutting, earn coins faster" }
	end
	return clumpStep("fill", ("FILL YOUR BAG   %d / %d"):format(run.carry + (run.ground or 0), max), if auto then "Mow more grass, then sell it at the shredder for coins" else "Cut more grass, then sell it at the shredder for coins")
end

-------------------------------------------------------------------------------------------------------------
-- the card
-------------------------------------------------------------------------------------------------------------
local card = Instance.new("CanvasGroup")
card.Name = "Coach"
card.AnchorPoint = Vector2.new(0.5, 0.5) -- placed every frame (see placeCard): big at the bottom, then docked top left
card.Position = UDim2.new(0.5, 0, 1, -196)
card.Size = UDim2.fromOffset(620, 150)
card.BackgroundTransparency = 1
card.GroupTransparency = 1
card.Visible = false
card.ZIndex = 20
card:SetAttribute("StackBase", 150) -- UI's bottom stack tells us our slot here instead of moving us
card:SetAttribute("Dock", 0)
card.Parent = UI.gui
-- the hanging wooden sign (ui_banner art), a picture of what this step is about, "STEP 2/5", title and why
local sign, face = Skin.frame(card, "ui_banner", Vector2.new(620, 150), { name = "Sign" })
sign.ZIndex = 20
-- the sign fades away as the card docks, so up by the quest it's just the picture and the text
local woodParts: { { inst: GuiObject, bg: number, img: number? } } = {}
for _, d in { sign, table.unpack(sign:GetDescendants()) } do
	if d:IsA("GuiObject") and d ~= face and not d:IsDescendantOf(face) then
		table.insert(woodParts, { inst = d, bg = d.BackgroundTransparency, img = if d:IsA("ImageLabel") then d.ImageTransparency else nil })
	end
end
local woodStrokes: { { inst: UIStroke, t: number } } = {}
for _, d in sign:GetDescendants() do
	if d:IsA("UIStroke") and not d:IsDescendantOf(face) then
		table.insert(woodStrokes, { inst = d, t = d.Transparency })
	end
end
local woodFade = -1
local function fadeWood(a: number)
	if math.abs(a - woodFade) < 0.01 then
		return
	end
	woodFade = a
	for _, w in woodParts do
		w.inst.BackgroundTransparency = w.bg + (1 - w.bg) * a
		if w.img then
			(w.inst :: ImageLabel).ImageTransparency = w.img + (1 - w.img) * a
		end
	end
	for _, s in woodStrokes do
		s.inst.Transparency = s.t + (1 - s.t) * a
	end
end
local pic = Instance.new("Frame")
pic.Name = "Pic"
pic.BackgroundTransparency = 1
pic.Size = UDim2.fromOffset(78, 78)
pic.Position = UDim2.new(0, 8, 0.5, 0)
pic.AnchorPoint = Vector2.new(0, 0.5)
pic.Parent = face
Skin.bob(pic, 2.5, 2.4)
local num = UI.text(face, "STEP 1/5", UDim2.fromOffset(140, 18), { pos = UDim2.fromOffset(96, 2), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 220, 90), stroke = 2 })
local title = UI.text(face, "", UDim2.new(1, -104, 0, 34), { pos = UDim2.fromOffset(96, 20), align = Enum.TextXAlignment.Left, stroke = 3.5 })
UI.gradient(title, C.yellow)
-- (two lines, wrapped: on one line the long hints shrank too small to read, on phones especially)
-- (it fills the sign down to its bottom edge and no further: a long hint used to run out under the wood, owner 27 Oct)
local sub = UI.text(face, "", UDim2.new(1, -110, 1, -60), { pos = UDim2.fromOffset(96, 56), align = Enum.TextXAlignment.Left, stroke = 2 })
sub.TextWrapped = true
sub.TextYAlignment = Enum.TextYAlignment.Top
local subMax = Instance.new("UITextSizeConstraint")
subMax.MaxTextSize = 21 -- (a short hint stays its old size instead of filling both lines)
subMax.Parent = sub
local scale = Instance.new("UIScale")
scale.Parent = card
local STEP_ICON = { punch = "hands", mow = "pushmower", collect = "bundle", fill = "backpack", sell = "coin", upgrade = "upgrade" }

-- A new step shows big at the bottom for a few seconds, then shrinks and glides up under the quest tracker
-- (top left) so it never sits on top of a menu. Opening any window docks it straight away.
local CARD_W, CARD_H = 620, 150
local BIG_FOR = 4.5 -- seconds a new step stays big at the bottom
local DOCK_SCALE = 0.6
local pop = Instance.new("NumberValue") -- the pop-in bounce
pop.Value = 1
local dock = Instance.new("NumberValue") -- 0 = big at the bottom, 1 = docked under the quest
local dockGoal = 0
local bigUntil = 0

local function setDock(goal: number)
	if goal == dockGoal then
		return
	end
	dockGoal = goal
	TweenService:Create(dock, TweenInfo.new(if goal == 1 then 0.55 else 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Value = goal }):Play()
end

local questFrame: GuiObject? = nil
local function findQuest(): GuiObject?
	if questFrame and questFrame.Parent then
		return questFrame
	end
	local hud = UI.gui:FindFirstChild("Hud")
	local q = hud and hud:FindFirstChild("Quest")
	questFrame = if q and q:IsA("GuiObject") then q else nil
	return questFrame
end

local function guiScale(): number
	local s = UI.gui:FindFirstChildOfClass("UIScale")
	return if s then s.Scale else 1
end

local function placeCard()
	local s = guiScale()
	local view = UI.gui.AbsoluteSize / s -- screen size in the gui's own (unscaled) units
	local base = card:GetAttribute("StackBase") :: number? or 150
	local bigCenter = Vector2.new(view.X / 2, view.Y - base - CARD_H / 2)
	local q = findQuest()
	local left, top = 22, 74 + 100
	if q then
		local o = UI.gui.AbsolutePosition -- the gui ignores the top bar inset, so its origin sits above the screen's
		local qp = q.AbsolutePosition - o
		left = qp.X / s
		-- under the quest; with no quest showing, take its place
		top = if q.Visible then (qp.Y + q.AbsoluteSize.Y) / s else qp.Y / s
	end
	local dockCenter = Vector2.new(left + CARD_W * DOCK_SCALE / 2, top + 6 + CARD_H * DOCK_SCALE / 2)
	local a = dock.Value
	card:SetAttribute("Dock", a)
	fadeWood(a)
	local c = bigCenter:Lerp(dockCenter, a)
	card.Position = UDim2.fromOffset(c.X, c.Y)
	scale.Scale = pop.Value * (1 + (DOCK_SCALE - 1) * a)
end

local ORDER = { punch = 1, mow = 1, collect = 2, fill = 3, sell = 4, upgrade = 5 }
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
		num.Text = ("STEP %d/5"):format(ORDER[step.id] or 1)
		UI.clear(pic)
		UI.icon(pic, STEP_ICON[step.id] or "clover", 78, UDim2.new())
		Skin.popIn(pic, 0.12)
		card.Visible = true
		TweenService:Create(card, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
		-- each new step gets its moment big at the bottom (unless a menu is open), then docks
		bigUntil = os.clock() + BIG_FOR
		if not UI.anyOpen() then
			setDock(0)
		end
		pop.Value = 0.6
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
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

local foundCard: GuiObject? = nil
local foundButton: GuiObject? = nil
local searchAt = 0
RunService.RenderStepped:Connect(function()
	local s = step
	local t = os.clock()
	-- the card: big for a moment, then docked under the quest (straight away while a menu is open)
	if card.Visible then
		setDock(if UI.anyOpen() or t > bigUntil then 1 else 0)
		placeCard()
		-- fade away while a window is open (docked it sat on the window's title, or on the Potato button)
		if shownId then
			local want = if UI.anyOpen() then 1 else 0
			card.GroupTransparency += (want - card.GroupTransparency) * 0.2
		end
	end
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
		-- (searching the whole PlayerGui every frame was costly: look again 4 times a second)
		if t - searchAt > 0.25 then
			searchAt = t
			foundCard = holdCard()
			foundButton = if foundCard then nil else findButton("UPGRADES")
		end
		local c = if foundCard and foundCard.Parent and UI.isOpen("Upgrades") then foundCard else nil
		if c then
			cardGlow.Parent = c
			cardGlow.Thickness = 4 + 2 * math.sin(t * 6)
		else
			cardGlow.Parent = nil
			local b = if foundButton and foundButton.Parent and foundButton.Visible then foundButton else nil
			if b then
				wantArrow = true
				-- (screen pixels -> the scaled gui's own units, as placeCard does: it used to land far off on big screens)
				local s = guiScale()
				local o = UI.gui.AbsolutePosition
				local pos = b.AbsolutePosition - o
				local size = b.AbsoluteSize
				hudArrow.Position = UDim2.fromOffset((pos.X - 6) / s - math.abs(math.sin(t * 4)) * 14, (pos.Y + size.Y * 0.4) / s)
			end
		end
	else
		cardGlow.Parent = nil
	end
	hudArrow.Visible = wantArrow
end)

return Coach
