-- THE RUN'S EXTRAS on screen (owner, 29 Oct, after balance pass 2: "Elder Clump", "Golden Hour", "speed challenges
-- per area", "mower upgrades", "party bonus"); server/RunEvents runs them, the numbers are in Config.
--   * chips along the top of the screen: GOLDEN HOUR with its countdown, the area's SPEED CHALLENGE clock and its
--     gems, and the PARTY BONUS while 2+ players are in the run (hidden in a boss fight)
--   * Golden Hour: the picture glows gold while it lasts, and a banner says it started
--   * Elder Clumps: a name and an HP bar over each (everyone's hits show), a gold beam to find it by, banners when one
--     grows in a new area and when one falls
-- (the mower upgrades are cards in the Upgrades window: client/Windows draws Config.UPGRADES' "Mower" section)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local RunEvents = {}
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 208, 64)
local GREEN = Color3.fromRGB(150, 236, 110)
local GREY = Color3.fromRGB(205, 205, 205)
local WHITE = Color3.fromRGB(255, 250, 235)
local RED = Color3.fromRGB(255, 120, 100)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function clock(sec: number): string
	sec = math.max(0, math.floor(sec + 0.5))
	return ("%d:%02d"):format(sec // 60, sec % 60)
end

-------------------------------------------------------------------------------------------------------------
-- the chips along the top
-------------------------------------------------------------------------------------------------------------
local bar = Instance.new("Frame")
bar.Name = "RunExtras"
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 8)
bar.Size = UDim2.fromOffset(820, 40)
bar.Parent = UI.gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

type Chip = { frame: Frame, label: TextLabel }

local function makeChip(name: string, order: number, width: number): Chip
	local f = UI.frame({ size = UDim2.fromOffset(width, 36), color = Color3.fromRGB(74, 48, 28), parent = bar, radius = 12, outline = 3, name = name })
	f.LayoutOrder = order
	f.BackgroundTransparency = 0.12
	f.Visible = false
	local label = UI.text(f, "", UDim2.new(1, -16, 1, -6), { pos = UDim2.fromOffset(8, 3), color = WHITE, stroke = 2.5 })
	label.ZIndex = f.ZIndex + 1
	return { frame = f, label = label }
end

local goldenChip = makeChip("GoldenHour", 1, 270)
local challengeChip = makeChip("SpeedChallenge", 2, 290)
local partyChip = makeChip("PartyBonus", 3, 240)

-- the chip's gold shimmer while Golden Hour is on
local shimmer = Instance.new("UIGradient")
shimmer.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 20)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 160, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 80, 20)),
})
shimmer.Offset = Vector2.new(-1, 0)
shimmer.Parent = goldenChip.frame
goldenChip.frame.BackgroundColor3 = Color3.new(1, 1, 1) -- (the gradient is its colour)
TweenService:Create(shimmer, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }):Play()

-------------------------------------------------------------------------------------------------------------
-- Golden Hour: the picture glows gold
-------------------------------------------------------------------------------------------------------------
local tint: ColorCorrectionEffect? = nil
local goldenOn = false

local function goldenLook(on: boolean)
	if on == goldenOn then
		return
	end
	goldenOn = on
	local t = tint
	if not t or not t.Parent then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "GoldenHourTint"
		made.Parent = Lighting
		tint = made
		t = made
	end
	assert(t)
	TweenService:Create(t, TweenInfo.new(if on then 1.2 else 2.5, Enum.EasingStyle.Sine), {
		TintColor = if on then Color3.fromRGB(255, 236, 198) else Color3.new(1, 1, 1),
		Saturation = if on then 0.14 else 0,
		Brightness = if on then 0.03 else 0,
	}):Play()
end

-------------------------------------------------------------------------------------------------------------
-- the area speed challenge: workspace attribute Challenge = "zone|end server time|gems|on/won/late"
-------------------------------------------------------------------------------------------------------------
type Challenge = { z: number, ends: number, gems: number, state: string, since: number }
local challenge: Challenge? = nil

local function readChallenge()
	local raw = workspace:GetAttribute("Challenge")
	if type(raw) ~= "string" then
		challenge = nil
		return
	end
	local z, ends, gems, state = string.match(raw, "^(%d+)|([%d%.]+)|(%d+)|(%a+)$")
	if not z then
		challenge = nil
		return
	end
	local zn, sn = tonumber(z) :: number, state :: string
	local before = challenge
	if before and before.z == zn and before.state == sn then
		return
	end
	challenge = { z = zn, ends = tonumber(ends) :: number, gems = tonumber(gems) :: number, state = sn, since = os.clock() }
end
workspace:GetAttributeChangedSignal("Challenge"):Connect(readChallenge)
readChallenge()

-------------------------------------------------------------------------------------------------------------
-- every quarter second: the chips
-------------------------------------------------------------------------------------------------------------
local function update()
	local w = State.world
	local inRun = State.isRun() and w ~= nil and w.mode == "Run" and not w.loading
	local fight = w ~= nil and w.boss ~= nil
	-- Golden Hour
	local untilT = workspace:GetAttribute("GoldenHourUntil")
	local goldenLeft = if type(untilT) == "number" then untilT - serverNow() else 0
	goldenLook(inRun and goldenLeft > 0)
	local G = Config.GOLDEN_HOUR
	goldenChip.frame.Visible = inRun and goldenLeft > 0 and not fight
	if goldenChip.frame.Visible then
		goldenChip.label.Text = ("GOLDEN HOUR %s  -  %dx MUTATIONS"):format(clock(goldenLeft), if G then G.luck else 3)
		goldenChip.label.TextColor3 = GOLD
	end
	-- the speed challenge
	local c = challenge
	local showC = false
	if inRun and not fight and c then
		if c.state == "on" then
			local left = c.ends - serverNow()
			showC = left > 0
			challengeChip.label.Text = ("SPEED CHALLENGE %s  -  +%d GEMS"):format(clock(left), c.gems)
			challengeChip.label.TextColor3 = if left < 30 and math.floor(os.clock() * 2) % 2 == 0 then RED else WHITE
		elseif c.state == "won" and os.clock() - c.since < 8 then
			showC = true
			challengeChip.label.Text = ("CHALLENGE BEATEN!  +%d GEMS"):format(c.gems)
			challengeChip.label.TextColor3 = GREEN
		elseif c.state == "late" and os.clock() - c.since < 6 then
			showC = true
			challengeChip.label.Text = "SPEED CHALLENGE MISSED"
			challengeChip.label.TextColor3 = GREY
		end
	end
	challengeChip.frame.Visible = showC
	-- the party bonus
	local P = Config.PARTY_BONUS
	local others = #Players:GetPlayers() - 1
	partyChip.frame.Visible = inRun and not fight and P ~= nil and others > 0
	if partyChip.frame.Visible and P then
		local pct = math.floor(math.min(P.max, P.per * others) * 100 + 0.5)
		partyChip.label.Text = ("PARTY BONUS  +%d%% COINS"):format(pct)
		partyChip.label.TextColor3 = GREEN
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local ok, err = pcall(update)
		if not ok then
			warn("[RunEvents] " .. tostring(err))
			task.wait(2)
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- Elder Clumps: a name and an HP bar over each, and a gold beam to find it by
-------------------------------------------------------------------------------------------------------------
type Elder = { bb: BillboardGui, fill: Frame, hp: TextLabel, beam: BasePart, conns: { RBXScriptConnection } }
local elders: { [Instance]: Elder } = {}

local function removeElder(holder: Instance)
	local e = elders[holder]
	if not e then
		return
	end
	elders[holder] = nil
	for _, c in e.conns do
		c:Disconnect()
	end
	e.bb:Destroy()
	TweenService:Create(e.beam, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	task.delay(0.65, function()
		e.beam:Destroy()
	end)
end

local function addElder(holder: Instance)
	if elders[holder] or not holder:IsA("Model") then
		return
	end
	local spot = holder:FindFirstChild("Spot")
	if not spot or not spot:IsA("BasePart") then
		return
	end
	local max = (holder:GetAttribute("ElderMax") or 1) :: number
	local height = (holder:GetAttribute("ElderHeight") or 20) :: number
	if ((holder:GetAttribute("ElderHP") or 0) :: number) <= 0 then
		return
	end
	-- the name and the HP bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "ElderBar"
	bb.Adornee = spot
	bb.Size = UDim2.fromOffset(240, 62)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height + 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 500
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local title = UI.text(bb, "ELDER CLUMP", UDim2.new(1, 0, 0, 28), { color = GOLD, stroke = 3 })
	title.ZIndex = 2
	local back = UI.frame({ size = UDim2.new(1, -20, 0, 22), pos = UDim2.fromOffset(10, 32), color = Color3.fromRGB(40, 26, 14), parent = bb, radius = 8, outline = 2 })
	local fill = UI.frame({ size = UDim2.fromScale(1, 1), color = GOLD, parent = back, radius = 8, outline = 0 })
	UI.gradient(fill, GOLD)
	local hp = UI.text(back, "", UDim2.fromScale(1, 1), { color = WHITE, stroke = 2 })
	hp.ZIndex = fill.ZIndex + 2
	bb.Parent = player:WaitForChild("PlayerGui")
	-- the beam
	local beam = Instance.new("Part")
	beam.Name = "ElderBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = GOLD
	beam.Transparency = 0.45
	beam.Size = Vector3.new(1.4, 160, 1.4)
	beam.CFrame = CFrame.new(spot.Position + Vector3.new(0, height + 84, 0))
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
	local e: Elder = { bb = bb, fill = fill, hp = hp, beam = beam, conns = {} }
	elders[holder] = e
	local function show()
		local now = (holder:GetAttribute("ElderHP") or 0) :: number
		if now <= 0 then
			removeElder(holder)
			return
		end
		local k = math.clamp(now / math.max(max, 1), 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.max(k, 0.02), 1) }):Play()
		hp.Text = ("%s / %s"):format(Format.short(math.ceil(now)), Format.short(max))
	end
	table.insert(e.conns, holder:GetAttributeChangedSignal("ElderHP"):Connect(show))
	table.insert(e.conns, holder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeElder(holder)
		end
	end))
	show()
end

CollectionService:GetInstanceAddedSignal("ElderClump"):Connect(addElder)
CollectionService:GetInstanceRemovedSignal("ElderClump"):Connect(removeElder)
for _, holder in CollectionService:GetTagged("ElderClump") do
	task.spawn(addElder, holder)
end

-------------------------------------------------------------------------------------------------------------
-- banners
-------------------------------------------------------------------------------------------------------------
State.on("fx", function(kind: string, d: any)
	if kind == "goldenHour" then
		UI.notice("GOLDEN HOUR!", ("%dx mutation luck for %d seconds: cut all you can!"):format(d.luck or 3, d.length or 45), "star")
		Sound.play("rareChime", 0.02, 1)
	elseif kind == "elderUp" then
		UI.notice("AN ELDER CLUMP GROWS!", ("Somewhere in the %s: follow the gold beam and chop it down together"):format(d.name or "new area"), "star")
		Sound.play("reveal", 0.03, 0.8)
	elseif kind == "elderDown" then
		local who = if d.mine then "You felled it!" else ("%s felled it!"):format(d.by or "Someone")
		UI.notice("ELDER CLUMP DOWN!", ("%s +%s coins, +%d gems"):format(who, Format.short(d.coins or 0), d.gems or 0), "coin")
		Sound.play("victory", 0, 0.8)
	elseif kind == "challenge" and d.won then
		UI.notice("SPEED CHALLENGE BEATEN!", ("You cleared it in time: +%d gems"):format(d.gems or 0), "star")
		Sound.play("rareChime", 0.02, 1)
	end
end)

return RunEvents
