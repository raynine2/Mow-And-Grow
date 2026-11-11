-- A bouncing brick arrow that shows the next thing to do, so nobody is ever lost:
--   lobby, never played  -> the SOLO pad
--   run, nothing cut yet -> the grass
--   bag full             -> the nearest Shredder's SELL ring (the hub's or the drop-off)
--   can afford next tool -> the Tool Shop
--   away from your area  -> back to it ("GO MOW!" / "NEXT AREA!")
-- (11 Nov) with one big word over it, and a pointer at the screen's edge when it's off the screen
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Coach = require(script.Parent.Coach)
local Device = require(script.Parent.Device)

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
	p.Transparency = 1 -- (10 Nov, owner's screenshot: before its first target it stood half in the plaza's middle)
	p.TopSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Offset", offset)
	p.Parent = arrow
	return p
end
-- shaft + stepped point (a little brick pyramid pointing down)
local shaft = brick(Vector3.new(1.4, 3, 1.4), Vector3.new(0, 3.4, 0), C.yellow)
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
ring.Transparency = 1 -- (shown by the loop below once there's a target)
ring.Size = Vector3.new(0.2, 8, 8)
ring.Parent = arrow
-- a dark cartoon outline keeps the plain yellow arrow readable against the grass and the sky
local outline = Instance.new("Highlight")
outline.FillTransparency = 1
outline.OutlineColor = Color3.fromRGB(56, 32, 16)
outline.DepthMode = Enum.HighlightDepthMode.Occluded
outline.Parent = arrow
arrow.Parent = workspace

-- (11 Nov, owner: "help dumb people a bit more, kids tend to not think a lot") the arrow says what to do there in
-- one big word ("SELL!", "NEW TOOL!", "GO MOW!"), always on top so a hill or a tree can't hide it
local tag = Instance.new("BillboardGui")
tag.Name = "GuideWord"
tag.Adornee = shaft
tag.AlwaysOnTop = true
tag.LightInfluence = 0
tag.Size = if Device.phone then UDim2.fromOffset(190, 40) else UDim2.fromOffset(250, 52)
tag.StudsOffset = Vector3.new(0, 3.2, 0)
tag.Enabled = false
tag.Parent = arrow
local tagText = Instance.new("TextLabel")
tagText.BackgroundTransparency = 1
tagText.Size = UDim2.fromScale(1, 1)
tagText.Font = C.font
tagText.TextScaled = true
tagText.TextColor3 = Color3.fromRGB(255, 236, 120)
tagText.TextStrokeColor3 = Color3.fromRGB(56, 32, 16)
tagText.TextStrokeTransparency = 0
tagText.Parent = tag
local tagStroke = Instance.new("UIStroke")
tagStroke.Thickness = 3
tagStroke.Color = Color3.fromRGB(56, 32, 16)
tagStroke.Parent = tagText

local target: Vector3? = nil
local word: string? = nil -- (11 Nov) what the arrow says over it, and the screen-edge pointer
local targetLift = 7 -- how high the arrow floats over the target (the coach lifts it over tall clumps)

local function findPart(path: { string }): BasePart?
	local node: Instance? = workspace:FindFirstChild("World")
	for _, name in path do
		node = node and node:FindFirstChild(name, true)
	end
	return if node and node:IsA("BasePart") then node else nil
end

local function pickTarget(): (Vector3?, string?)
	local d = State.data
	if not d then
		return nil
	end
	if d.mode == "Lobby" then
		if d.stats and d.stats.runs == 0 and not d.run then
			-- (4 Nov lobby remake) a free win first: the daily reward's bay at the rewards stall, a few steps from the
			-- spawn; once it's claimed, the SOLO pad
			if d.daily and d.daily.ready then
				for _, z in game:GetService("CollectionService"):GetTagged("LobbyPadZone") do
					if z:GetAttribute("Claim") == "daily" and z:IsA("Model") then
						local p = z:GetPivot().Position
						return Vector3.new(p.X, 0, p.Z), "FREE GIFT!"
					end
				end
			end
			local pad = findPart({ "PadInfo1" })
			if pad then
				return Vector3.new(pad.Position.X, 0, pad.Position.Z), "PLAY!"
			end
			return nil
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
		return best, "SELL!"
	end
	if w.boss then
		return nil
	end
	-- (6 Nov) the area is mowed and its boss waits: the arrow shows the summon pad (it pointed nowhere)
	if w.bossWaiting and typeof(w.bossPad) == "Vector3" then
		return Vector3.new(w.bossPad.X, 0, w.bossPad.Z), "FIGHT THE BOSS!"
	end
	local ni = Config.nextToolIndex(run, d.tools)
	local nextTool = ni and Config.TOOLS[ni]
	if nextTool and run.coins >= nextTool.cost and run.carry == 0 then
		local shop = findPart({ "TOOL SHOP", "Counter" })
		if shop then
			return Vector3.new(shop.Position.X, 0, shop.Position.Z) + shop.CFrame.LookVector * 5, "NEW TOOL!"
		end
	end
	if d.stats and d.stats.cut == 0 then
		return Config.zoneEntry(math.clamp(w.zone or 1, 1, #Config.ZONES)), "MOW!"
	end
	-- (11 Nov, owner: "help dumb people a bit more") away from the area you're mowing (in the village after a sale, or
	-- a new area just opened): the arrow leads you back to it
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local z = math.clamp(w.zone or 1, 1, #Config.ZONES)
	if root then
		local here = Config.zoneAt(root.Position)
		if here >= 0 and here ~= z then
			return Config.zoneEntry(z), if here < z and here > 0 then "NEXT AREA!" else "GO MOW!"
		end
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.25)
		if not UI.gui.Enabled then
			-- no arrow in a film: the intro (a first-timer's now plays mid-run, after the first sale, with the coach
			-- still on: report #1), a boss's entrance and the ending all hide the HUD
			target, word = nil, nil
		-- while the first-run coach (client/Coach) is on, the arrow shows its step
		elseif Coach.active() then
			local p, lift = Coach.target()
			target, targetLift, word = p, lift or 7, Coach.word()
		else
			local ok, res, w = pcall(pickTarget)
			target, targetLift, word = if ok then res else nil, 7, if ok then w else nil
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
		if shown == nil then
			return -- (9 Nov: already hidden, nothing to do this frame)
		end
		shown = nil
		tag.Enabled = false
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
	local bob = (math.sin(t * 1.8) + 1) * 0.35 -- (9 Nov, owner: calmer; it bounced 1.6 studs three times a second)
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
	tag.Enabled = word ~= nil and fade > 0.05
	tagText.Text = word or ""
	tagText.TextTransparency = 1 - fade
	tagStroke.Transparency = 1 - fade
	for _, p in arrow:GetChildren() do
		if not p:IsA("BasePart") then
			continue -- the outline Highlight
		end
		local part = p :: BasePart
		if part == ring then
			local s = 7 + math.sin(t * 1.5) * 0.25
			part.Size = Vector3.new(0.2, s, s)
			part.CFrame = CFrame.new(at + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
			part.Transparency = 1 - 0.3 * fade
		else
			part.CFrame = base * CFrame.new(part:GetAttribute("Offset") :: Vector3)
			part.Transparency = 1 - fade
		end
	end
end)

-- (11 Nov, owner: "help dumb people a bit more") when the arrow is off the screen (behind you, or far to the side) a
-- big yellow pointer sits at the screen's edge on the side to turn to, with the arrow's word next to it. A kid who
-- doesn't think to turn the camera around still sees which way to go.
local edgeGui = Instance.new("ScreenGui")
edgeGui.Name = "MowALawnGuideEdge"
edgeGui.ResetOnSpawn = false
edgeGui.IgnoreGuiInset = true -- (so the frame's pixels are the camera's viewport pixels)
edgeGui.ScreenInsets = Enum.ScreenInsets.None
edgeGui.DisplayOrder = 1 -- over the HUD (it hides while a window is open)
edgeGui.Enabled = false
edgeGui.Parent = player:WaitForChild("PlayerGui")
local edgeScale = Instance.new("UIScale")
local pointer = Instance.new("Frame")
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.BackgroundTransparency = 1
pointer.Size = UDim2.fromOffset(110, 68)
pointer.Parent = edgeGui
edgeScale.Parent = pointer
-- the glossy gold arrow the coach points at UPGRADES with (owner, 4 Nov: "do it like this exact"), pointing right; the
-- pointer turns it to the target. Its uploaded picture, else the same pixels (shared/ArrowPixels), else bricks.
local arrowIcon = (Config.ICONS :: any).arrow_point :: string?
local arrowImg = Instance.new("ImageLabel")
arrowImg.BackgroundTransparency = 1
arrowImg.Size = UDim2.fromScale(1, 1)
arrowImg.ScaleType = Enum.ScaleType.Fit
if arrowIcon and arrowIcon ~= "" then
	arrowImg.Image = arrowIcon
else
	local ok, res = pcall(function()
		local px = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("ArrowPixels")) :: any
		local EncodingService = game:GetService("EncodingService")
		local raw = EncodingService:DecompressBuffer(EncodingService:Base64Decode(buffer.fromstring(px.data)), Enum.CompressionAlgorithm.Zstd)
		local img = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(px.w, px.h) })
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(px.w, px.h), raw)
		return Content.fromObject(img)
	end)
	if ok then
		arrowImg.ImageContent = res
	else
		arrowImg.Visible = false
		local shaftF = UI.frame({ size = UDim2.fromOffset(56, 22), pos = UDim2.fromOffset(8, 23), color = C.yellow, parent = pointer, radius = 4, outline = 3 })
		local head = UI.frame({ size = UDim2.fromOffset(40, 40), pos = UDim2.fromOffset(52, 14), color = C.yellow, parent = pointer, radius = 4, outline = 3 })
		head.Rotation = 45
		head.ZIndex = shaftF.ZIndex + 1
	end
end
arrowImg.Parent = pointer
local edgeWord = Instance.new("TextLabel")
edgeWord.AnchorPoint = Vector2.new(0.5, 0.5)
edgeWord.BackgroundTransparency = 1
edgeWord.Size = UDim2.fromOffset(200, 38)
edgeWord.Font = C.font
edgeWord.TextScaled = true
edgeWord.TextColor3 = Color3.fromRGB(255, 236, 120)
edgeWord.TextStrokeTransparency = 0
edgeWord.TextStrokeColor3 = Color3.fromRGB(56, 32, 16)
edgeWord.Parent = edgeGui
local edgeWordScale = Instance.new("UIScale")
edgeWordScale.Parent = edgeWord

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local at = shown
	if not at or not cam or not root or not UI.gui.Enabled or UI.anyOpen()
		or ((root.Position - at) * Vector3.new(1, 0, 1)).Magnitude < 12
	then
		edgeGui.Enabled = false
		return
	end
	local vp = cam.ViewportSize
	local sp = cam:WorldToViewportPoint(at + Vector3.new(0, shownLift, 0))
	-- margins: clear of the top bar, the hotbar along the bottom and a phone's rounded corners
	local k = math.clamp(vp.Y / 720, 0.55, 1.4) * (if Device.phone then 1.15 else 1)
	local mx, top, bottom = 60 * k, math.max(60 * k, Device.topInset() + 40 * k), 130 * k
	local inside = sp.Z > 0 and sp.X > mx and sp.X < vp.X - mx and sp.Y > top and sp.Y < vp.Y - bottom
	if inside then
		edgeGui.Enabled = false
		return
	end
	local mid = Vector2.new(vp.X / 2, vp.Y * 0.5)
	local dir = Vector2.new(sp.X, sp.Y) - mid
	if sp.Z <= 0 then
		-- behind you: left or right, the way to turn (pointing down read as "go back")
		local side = cam.CFrame.RightVector:Dot(at - cam.CFrame.Position)
		dir = Vector2.new(if side >= 0 then 1 else -1, 0)
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, 1)
	end
	local unit = dir.Unit
	-- on an oval around you, not at the screen's edge: a phone's edges are full of HUD (coins, bag, side buttons, the
	-- hotbar) and the pointer vanished behind them in the first test
	local rx, ry = vp.X * 0.22, vp.Y * 0.3
	local r = 1 / math.sqrt((unit.X / rx) ^ 2 + (unit.Y / ry) ^ 2)
	local nudge = math.sin(os.clock() * 6) * 6 * k -- a little poke toward the target
	local pos = mid + unit * (r + nudge)
	edgeGui.Enabled = true
	edgeScale.Scale = k
	pointer.Position = UDim2.fromOffset(pos.X, pos.Y)
	pointer.Rotation = math.deg(math.atan2(unit.Y, unit.X))
	edgeWord.Visible = word ~= nil
	edgeWord.Text = word or ""
	edgeWordScale.Scale = k
	-- the word just inside the pointer, under it (over it at the bottom edge)
	local wpos = mid + unit * (r - 60 * k)
	edgeWord.Position = UDim2.fromOffset(wpos.X, wpos.Y + (if unit.Y > 0.7 then -46 * k else 50 * k))
end)

return Guide
