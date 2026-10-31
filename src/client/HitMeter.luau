-- HIT METER (owner, 28 Oct: Chop A Forest registers every hit and shows how far the tree is chopped under the
-- crosshair, "Oak 3/4.6 HP"; "copy that but make it look soothing and make it match our mowing grass aesthetic").
-- A soft leaf-green pill just under the middle of the screen while you cut a clump:
--   * the grass's name on top, "3 / 5" in the bar
--   * the fill is the grass that's left: fresh green when the clump is whole, ripening to lime and then wheat gold
--     as it's cut down (no alarm reds)
--   * a pale "just cut" sliver behind the fill that eases away a beat after each hit (Chop's white chunk, slower
--     and softer)
--   * every hit: a gentle swell of the bar, a soft glow over the fill and a little leaf drifting off its end
--   * the last hit: the bar empties, "Fresh cut!" floats up in soft gold and the meter fades away
-- Fed by the server's "chip" (client/Fx's chip handler calls HitMeter.hit) and our own "mow" (the clump cut down).
-- Auto tools and mowers cut too many clumps at once for one bar, so they don't show it. Tweens only: nothing runs
-- per frame, idle or not.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local HitMeter = {}
local player = Players.LocalPlayer

local W, H = 280, 22 -- the bar
local FULL = Color3.fromRGB(118, 214, 104) -- a whole clump: fresh grass
local MID = Color3.fromRGB(196, 226, 102) -- half cut: lime
local LOW = Color3.fromRGB(240, 210, 118) -- nearly cut: wheat gold
local CREAM = Color3.fromRGB(250, 246, 226)
local MOSS = Color3.fromRGB(30, 52, 34)
local GOLD = Color3.fromRGB(255, 226, 140)

local function colorAt(r: number): Color3
	if r >= 0.5 then
		return MID:Lerp(FULL, (r - 0.5) / 0.5)
	end
	return LOW:Lerp(MID, math.max(r, 0) / 0.5)
end

local function stroke(obj: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = obj
	return s
end

local function corner(obj: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
end

-------------------------------------------------------------------------------------------------------------
-- the meter
-------------------------------------------------------------------------------------------------------------
local root = Instance.new("CanvasGroup")
root.Name = "HitMeter"
root.AnchorPoint = Vector2.new(0.5, 0)
-- (31 Oct, owner: "some pieces of grass still don't show a hole on your first punch") on a PC screen the cut round
-- the crosshair reached further down than the meter's 52 pixels, and the meter hid the hole's lower half: it now
-- sits a sixth of the screen lower (about the same spot on a phone, where the cut is smaller)
root.Position = UDim2.new(0.5, 0, 0.66, 0) -- under the crosshair, clear of the cut it's carving (28 Oct: was +30, then +52)
root.Size = UDim2.fromOffset(W + 40, 78)
root.BackgroundTransparency = 1
root.GroupTransparency = 1
root.Visible = false
root.ZIndex = 4
root.Parent = UI.gui
local swell = Instance.new("UIScale")
swell.Parent = root

local nameLabel = UI.text(root, "", UDim2.fromOffset(W, 22), { pos = UDim2.fromOffset(20, 12), color = CREAM, stroke = 2 })
stroke(nameLabel, MOSS, 2)
local doneLabel = UI.text(root, "Fresh cut!", UDim2.fromOffset(W, 26), { pos = UDim2.fromOffset(20, 10), color = GOLD, stroke = 2 })
stroke(doneLabel, Color3.fromRGB(70, 60, 24), 2)
doneLabel.TextTransparency = 1
;(doneLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 1

local track = UI.frame({ size = UDim2.fromOffset(W, H), pos = UDim2.fromOffset(20, 40), color = MOSS, transparency = 0.18, parent = root, radius = 0, outline = 0, name = "Track" })
corner(track, H // 2)
stroke(track, CREAM, 2, 0.35)

-- the "just cut" sliver: sits behind the fill and eases down to it after each hit
local ghost = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(232, 252, 214), transparency = 0.15, parent = track, radius = 0, outline = 0, name = "Ghost" })
corner(ghost, H // 2)
local fill = UI.frame({ size = UDim2.fromScale(1, 1), color = FULL, parent = track, radius = 0, outline = 0, name = "Fill" })
corner(fill, H // 2)
fill.ZIndex = 2
local sheen = Instance.new("UIGradient")
sheen.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 214, 200))
sheen.Rotation = 90
sheen.Parent = fill
-- the soft glow over the fill on a hit
local glow = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.new(1, 1, 1), transparency = 1, parent = fill, radius = 0, outline = 0, name = "Glow" })
corner(glow, H // 2)
glow.ZIndex = 3
local hpLabel = UI.text(track, "", UDim2.new(1, -12, 1, -4), { pos = UDim2.fromOffset(6, 2), color = CREAM, stroke = 1.5 })
stroke(hpLabel, MOSS, 1.5)
hpLabel.ZIndex = 4

-- a few leaves that drift off the end of the fill, one per hit
local leaves: { Frame } = {}
for i = 1, 4 do
	local leaf = UI.frame({ size = UDim2.fromOffset(11, 7), anchor = Vector2.new(0.5, 0.5), color = FULL, transparency = 1, parent = root, radius = 0, outline = 0, name = "Leaf" .. i })
	corner(leaf, 6)
	leaf.ZIndex = 5
	table.insert(leaves, leaf)
end
local nextLeaf = 1

-------------------------------------------------------------------------------------------------------------
-- state
-------------------------------------------------------------------------------------------------------------
local current: Instance? = nil -- the clump the meter shows
local currentPos: Vector3? = nil
local lastRatio = 1
local lastAt = 0
local token = 0 -- bumps on every update, so an old fade-out doesn't hide a newer hit
local windowOpen = false

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, delay: number?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end

local function fadeOut(after: number)
	local my = token
	task.delay(after, function()
		if token ~= my then
			return
		end
		tween(root, 0.45, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
		task.delay(0.46, function()
			if token == my then
				root.Visible = false
				current = nil
				currentPos = nil
			end
		end)
	end)
end

local function showUp()
	if not root.Visible or root.GroupTransparency > 0.01 then
		root.Visible = true
		tween(root, 0.16, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
	end
end

-- 4.6 stays "4.6" (Format.short rounds small numbers to whole ones), 5 stays "5", big ones go short ("12K")
local function num(v: number): string
	v = math.max(v, 0)
	if v >= 1000 then
		return Format.short(v)
	end
	local r = math.floor(v * 10 + 0.5) / 10
	if r % 1 == 0 then
		return tostring(math.floor(r))
	end
	return ("%.1f"):format(r)
end
local function hpText(hp: number, max: number): string
	return num(hp) .. " / " .. num(max)
end

-- a leaf drifts off the end of the fill
local function dropLeaf(ratio: number, color: Color3)
	local leaf = leaves[nextLeaf]
	nextLeaf = nextLeaf % #leaves + 1
	local x = 20 + W * math.clamp(ratio, 0.04, 1)
	local side = if math.random() < 0.5 then -1 else 1
	leaf.BackgroundColor3 = color
	leaf.Position = UDim2.fromOffset(x, 40 + H / 2)
	leaf.Rotation = math.random(-30, 30)
	leaf.BackgroundTransparency = 0.05
	tween(leaf, 0.85, {
		Position = UDim2.fromOffset(x + side * math.random(10, 22), 40 + H / 2 - math.random(16, 26)),
		Rotation = leaf.Rotation + side * math.random(50, 110),
		BackgroundTransparency = 1,
	}, Enum.EasingStyle.Sine)
end

-- Is the player cutting with an auto tool or a mower? (Then the meter stays off: too many clumps at once.)
local function autoCutting(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then
		return true
	end
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ToolId")
	if not id then
		return false
	end
	for _, t in Config.TOOLS do
		if t.id == id and t.kind == "auto" then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------------------------------------
-- A hit that didn't cut the clump down yet (the server's "chip": label, hp, max, model, pos).
function HitMeter.hit(d)
	if windowOpen or autoCutting() or not d.max or d.max <= 0 then
		return
	end
	local now = os.clock()
	-- a wide swing chips several clumps in the same instant: keep the first one
	if d.model ~= current and now - lastAt < 0.1 then
		return
	end
	local ratio = math.clamp((d.hp or 0) / d.max, 0, 1)
	token += 1
	if d.model ~= current then
		-- a new clump: start from its own amount, no drain carried over from the last one
		current = d.model
		lastRatio = math.clamp(ratio + (d.dealt or 0) / d.max, ratio, 1)
		ghost.Size = UDim2.fromScale(lastRatio, 1)
		fill.Size = UDim2.fromScale(lastRatio, 1)
		fill.BackgroundColor3 = colorAt(lastRatio)
		nameLabel.TextTransparency = 0
		;(nameLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0
		doneLabel.TextTransparency = 1
		;(doneLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 1
	end
	currentPos = d.pos
	lastAt = now
	nameLabel.Text = d.label or ""
	hpLabel.Text = hpText(d.hp or 0, d.max)
	showUp()
	-- the fill drops at once, the pale sliver follows a beat later
	local col = colorAt(ratio)
	tween(fill, 0.14, { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = col })
	tween(ghost, 0.5, { Size = UDim2.fromScale(ratio, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0.2)
	-- the hit: a soft glow and a gentle swell
	glow.BackgroundTransparency = 0.55
	tween(glow, 0.3, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	swell.Scale = 1
	TweenService:Create(swell, TweenInfo.new(0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), { Scale = 1.05 }):Play()
	dropLeaf(ratio, colorAt(lastRatio))
	lastRatio = ratio
	fadeOut(1.6)
end

-- The clump the meter shows was cut down: empty the bar, "Fresh cut!", fade away.
-- (31 Oct, owner: "it still doesn't make a hole sometimes") Keep the meter off the hole a hit just opened:
-- client/ClumpCarve says where the hole is on screen (0 top .. 1 bottom). Looking down at a clump (from higher
-- ground) the hole is well under the crosshair, right where the meter sat: then the meter goes above the crosshair.
function HitMeter.avoid(y: number)
	if y < 0.56 then
		root.AnchorPoint = Vector2.new(0.5, 0)
		root.Position = UDim2.new(0.5, 0, math.clamp(y + 0.12, 0.66, 0.86), 0)
	else
		root.AnchorPoint = Vector2.new(0.5, 1)
		root.Position = UDim2.new(0.5, 0, math.clamp(y - 0.12, 0.2, 0.4), 0)
	end
end

function HitMeter.done()
	if not current or not root.Visible then
		return
	end
	token += 1
	current = nil
	currentPos = nil
	hpLabel.Text = ""
	tween(fill, 0.16, { Size = UDim2.fromScale(0, 1) })
	tween(ghost, 0.45, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0.12)
	glow.BackgroundTransparency = 0.4
	tween(glow, 0.3, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	dropLeaf(0.05, LOW)
	dropLeaf(0.05, MID)
	-- the name gives way to a soft gold "Fresh cut!" that floats up
	tween(nameLabel, 0.15, { TextTransparency = 1 })
	tween(nameLabel:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.15, { Transparency = 1 })
	doneLabel.Position = UDim2.fromOffset(20, 14)
	doneLabel.TextTransparency = 0
	;(doneLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0
	tween(doneLabel, 0.9, { Position = UDim2.fromOffset(20, 4) }, Enum.EasingStyle.Sine)
	swell.Scale = 1
	TweenService:Create(swell, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), { Scale = 1.07 }):Play()
	fadeOut(0.7)
end

function HitMeter.hide()
	token += 1
	root.Visible = false
	root.GroupTransparency = 1
	current = nil
	currentPos = nil
end

-- our own clump cut down (server/Field's "fell", server/Grass's "mow"; both go to everyone, `by` says who cut it)
State.on("fx", function(kind, d)
	if (kind ~= "fell" and kind ~= "mow") or type(d) ~= "table" or d.by ~= player.UserId then
		return
	end
	local at = currentPos
	local pos = d.pos
	if at and typeof(pos) == "Vector3" and Vector3.new(pos.X - at.X, 0, pos.Z - at.Z).Magnitude < 1.5 then
		HitMeter.done()
	end
end)

UI.onWindowChanged.Event:Connect(function(name)
	windowOpen = name ~= nil
	if windowOpen then
		HitMeter.hide()
	end
end)

return HitMeter
