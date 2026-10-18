-- Combo streaks: every clump you cut within a couple of seconds of the last one adds to a combo. From x3 a big
-- counter shows above the hotbar: it punches bigger on every cut, its colour climbs through the tiers (white,
-- gold, orange, hot pink, then an animated rainbow at x50+), each cut ticks a note a little higher, and a bar
-- under it drains until the streak runs out. Milestones (x10, x25, x50, x100) get a banner. Purely for show:
-- combos don't change any rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Fx = require(script.Parent.Fx)

local Combo = {}
local _ = ReplicatedStorage

local WINDOW = 2.4 -- seconds you have to cut the next clump
local SHOW_FROM = 3

local TIERS = {
	{ from = 3, top = Color3.fromRGB(255, 255, 255), bottom = Color3.fromRGB(205, 225, 255) },
	{ from = 10, top = Color3.fromRGB(255, 244, 140), bottom = Color3.fromRGB(255, 190, 40) },
	{ from = 25, top = Color3.fromRGB(255, 200, 110), bottom = Color3.fromRGB(255, 110, 30) },
	{ from = 50, top = Color3.fromRGB(255, 150, 210), bottom = Color3.fromRGB(235, 50, 120) },
}
local MILESTONES = {
	[10] = { "NICE CUTS!", Color3.fromRGB(255, 220, 80) },
	[25] = { "GRASS GOBLIN!", Color3.fromRGB(255, 150, 50) },
	[50] = { "MOWING MACHINE!", Color3.fromRGB(255, 90, 160) },
	[100] = { "LAWN LEGEND!", Color3.fromRGB(170, 120, 255) },
}

-------------------------------------------------------------------------------------------------------------
-- the counter
-------------------------------------------------------------------------------------------------------------
local holder = Instance.new("Frame")
holder.Name = "Combo"
holder.BackgroundTransparency = 1
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -150)
holder.Size = UDim2.fromOffset(260, 110)
holder.Visible = false
holder.Parent = UI.gui
local scale = Instance.new("UIScale")
scale.Parent = holder

local count = UI.text(holder, "x0", UDim2.new(1, 0, 0, 70), { color = Color3.new(1, 1, 1), stroke = 4.5 })
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Parent = count
UI.text(holder, "COMBO", UDim2.new(1, 0, 0, 24), { pos = UDim2.fromOffset(0, 68), color = Color3.new(1, 1, 1), stroke = 2.5 })
local track = UI.frame({ size = UDim2.new(0.6, 0, 0, 8), pos = UDim2.new(0.2, 0, 0, 98), color = Color3.fromRGB(30, 30, 34), parent = holder, radius = 4, outline = 2 })
local fill = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(255, 220, 80), parent = track, radius = 4, outline = 0 })

local combo = 0
local best = 0
local lastCut = 0

local function tierOf(n: number)
	local t = TIERS[1]
	for _, tier in TIERS do
		if n >= tier.from then
			t = tier
		end
	end
	return t
end

local function punch()
	scale.Scale = 1.4
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	count.Rotation = (math.random() - 0.5) * 14
	TweenService:Create(count, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
end

local function finish()
	if combo >= 5 then
		-- a short "x12 COMBO!" farewell that floats up and fades
		local ghost = UI.text(UI.gui, ("x%d COMBO!"):format(combo), UDim2.fromOffset(320, 50), { color = Color3.new(1, 1, 1), stroke = 3 })
		ghost.AnchorPoint = Vector2.new(0.5, 1)
		ghost.Position = holder.Position
		local g = gradient:Clone()
		g.Parent = ghost
		TweenService:Create(ghost, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = holder.Position - UDim2.fromOffset(0, 60), TextTransparency = 1 }):Play()
		local st = ghost:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.9), { Transparency = 1 }):Play()
		end
		task.delay(1, function()
			ghost:Destroy()
		end)
	end
	combo = 0
	holder.Visible = false
end

local function addCut()
	local now = os.clock()
	combo = if now - lastCut <= WINDOW then combo + 1 else 1
	lastCut = now
	best = math.max(best, combo)
	if combo < SHOW_FROM then
		return
	end
	holder.Visible = true
	count.Text = "x" .. combo
	local tier = tierOf(combo)
	gradient.Color = ColorSequence.new(tier.top, tier.bottom)
	fill.BackgroundColor3 = tier.bottom
	punch()
	-- a note that climbs with the streak (wraps every two octaves so it never gets silly)
	Sound.playAt("click", 0.9 + (combo % 24) * 0.05)
	local m = MILESTONES[combo]
	if m then
		Fx.banner(m[1], m[2], 1.6, ("x%d combo"):format(combo))
		Sound.play("purchase")
	end
end

State.on("bundleGained", function()
	addCut()
end)

RunService.RenderStepped:Connect(function()
	if combo == 0 then
		return
	end
	local left = WINDOW - (os.clock() - lastCut)
	if left <= 0 then
		finish()
		return
	end
	if holder.Visible then
		fill.Size = UDim2.fromScale(left / WINDOW, 1)
		if combo >= 50 then
			-- rainbow tier: the gradient slides through the colours
			local h = (os.clock() * 0.6) % 1
			gradient.Color = ColorSequence.new(Color3.fromHSV(h, 0.55, 1), Color3.fromHSV((h + 0.15) % 1, 0.85, 1))
		end
	end
end)

function Combo.best(): number
	return best
end

return Combo
