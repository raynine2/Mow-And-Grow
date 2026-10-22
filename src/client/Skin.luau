-- The art kit for the remade UI (Oct 2026): the ForgeGUI frames in assets/icons/ui_*.png drawn as 9-slice images,
-- and the motion that makes them feel alive (shine sweeps, sparkles, hover/press juice, idle bob, "+N" pops).
-- Every frame falls back to a plain wooden box while its image isn't uploaded yet (Config.ICONS[key] == ""),
-- so the game never breaks on a missing picture.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)

local Skin = {}

-- Source size, the 9-slice centre and the flat face inside the frame (left, top, right, bottom insets), all in the
-- PNG's own pixels. Measured on the exported art (tools: scratchpad measure script, 22 Oct 2026).
type FrameDef = { w: number, h: number, slice: Rect, face: { number }, fallback: Color3, radius: number, rect: Vector2? }
Skin.FRAMES = {
	ui_plate = { w = 1024, h = 307, slice = Rect.new(160, 70, 864, 237), face = { 63, 64, 64, 59 }, fallback = Color3.fromRGB(240, 170, 60), radius = 999 },
	ui_bar = { w = 1024, h = 165, slice = Rect.new(90, 60, 934, 105), face = { 47, 52, 49, 44 }, fallback = Color3.fromRGB(60, 34, 14), radius = 999 },
	-- (the card PNG has near-invisible padding under the frame, so only its top 408 rows are used)
	ui_card = { w = 768, h = 408, rect = Vector2.new(768, 408), slice = Rect.new(170, 115, 690, 345), face = { 128, 66, 64, 52 }, fallback = Color3.fromRGB(255, 240, 205), radius = 18 },
	ui_banner = { w = 1024, h = 445, slice = Rect.new(190, 190, 834, 380), face = { 40, 160, 40, 50 }, fallback = Color3.fromRGB(230, 160, 80), radius = 14 },
	ui_tile = { w = 489, h = 512, slice = Rect.new(90, 90, 399, 422), face = { 76, 80, 74, 98 }, fallback = Color3.fromRGB(240, 210, 160), radius = 16 },
	ui_tile_gold = { w = 506, h = 512, slice = Rect.new(90, 100, 416, 430), face = { 70, 85, 70, 95 }, fallback = Color3.fromRGB(255, 205, 50), radius = 16 },
	ui_badge = { w = 512, h = 501, slice = Rect.new(140, 120, 372, 380), face = { 110, 100, 106, 92 }, fallback = Color3.fromRGB(196, 124, 62), radius = 999 },
	-- the window kit (shop pass, 22 Oct 2026): white/grey art is tinted with ImageColor3 (it multiplies)
	ui_button = { w = 1024, h = 416, slice = Rect.new(110, 100, 914, 306), face = { 30, 22, 30, 52 }, fallback = Color3.fromRGB(240, 240, 240), radius = 12 },
	ui_inset = { w = 1024, h = 586, slice = Rect.new(110, 110, 914, 476), face = { 80, 88, 80, 62 }, fallback = Color3.fromRGB(160, 102, 56), radius = 14 },
	ui_pcard = { w = 747, h = 1024, slice = Rect.new(120, 130, 627, 894), face = { 84, 92, 84, 92 }, fallback = Color3.fromRGB(230, 150, 40), radius = 18 },
	ui_ribbon = { w = 1024, h = 178, slice = Rect.new(140, 40, 884, 140), face = { 125, 14, 125, 42 }, fallback = Color3.fromRGB(240, 240, 240), radius = 6 },
	ui_sign = { w = 1024, h = 436, slice = Rect.new(140, 120, 884, 300), face = { 48, 48, 48, 70 }, fallback = Color3.fromRGB(240, 222, 200), radius = 14 },
} :: { [string]: FrameDef }

local function artId(key: string): string?
	local id = Config.ICONS and Config.ICONS[key]
	if id and id ~= "" then
		return id
	end
	return nil
end
Skin.has = function(key: string): boolean
	return artId(key) ~= nil
end

-- A frame of `key` at a fixed design size (Vector2, in the 1280x720 layout units). Returns the frame and its
-- "face": an empty Frame over the flat inside, where content goes. `stretch` = 9-slice it (cards, plates, bars);
-- otherwise the picture is fitted whole (badges, tiles). `boost` draws the border that much thicker (small buttons
-- would get a hairline outline otherwise), `maxScale` caps it (big boxes would get a huge rim), `tint` colours it.
type FrameProps = { pos: UDim2?, anchor: Vector2?, name: string?, stretch: boolean?, boost: number?, maxScale: number?, tint: Color3? }
function Skin.frame(parent: Instance, key: string, size: Vector2, props: FrameProps?): (GuiObject, Frame)
	local o = props or {}
	local def = Skin.FRAMES[key]
	local id = artId(key)
	local k = math.min(size.X / def.w, size.Y / def.h)
	local holder: GuiObject
	if id then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = id
		if def.rect then
			img.ImageRectSize = def.rect
		end
		if o.tint then
			img.ImageColor3 = o.tint
		end
		if o.stretch ~= false then
			img.ScaleType = Enum.ScaleType.Slice
			img.SliceCenter = def.slice
			-- keep the border as thick as the art drawn at the frame's smaller dimension (times `boost`), but never so
			-- thick that the corners of the 9-slice overlap
			local sl = def.slice
			k = math.min(size.X / def.w, size.Y / def.h) * (o.boost or 1)
			k = math.min(k, size.Y / (sl.Min.Y + def.h - sl.Max.Y), size.X / (sl.Min.X + def.w - sl.Max.X))
			if o.maxScale then
				k = math.min(k, o.maxScale)
			end
			img.SliceScale = k
		else
			img.ScaleType = Enum.ScaleType.Fit
		end
		holder = img
	else
		local f = UI.frame({ size = UDim2.fromOffset(size.X, size.Y), color = def.fallback, parent = nil, radius = def.radius, outline = 4 })
		;(f:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(74, 44, 20)
		UI.gradient(f, def.fallback)
		holder = f
	end
	holder.Name = o.name or key
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.Position = o.pos or UDim2.new()
	holder.AnchorPoint = o.anchor or Vector2.zero
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	local l, t, r, b = def.face[1] * k, def.face[2] * k, def.face[3] * k, def.face[4] * k
	face.Position = UDim2.fromOffset(l, t)
	face.Size = UDim2.new(1, -(l + r), 1, -(t + b))
	face.Parent = holder
	holder.Parent = parent
	return holder, face
end

-- A bar: the wooden groove frame with a coloured fill inside its face. Returns the frame, the fill (set its
-- Size.X.Scale) and a centred label on top.
function Skin.bar(parent: Instance, size: Vector2, color: Color3, props: { pos: UDim2?, anchor: Vector2?, name: string? }?): (GuiObject, Frame, TextLabel)
	local holder, face = Skin.frame(parent, "ui_bar", size, props)
	face.ClipsDescendants = true
	UI.corner(face, 999)
	local fill = UI.frame({ size = UDim2.fromScale(0, 1), color = color, parent = face, radius = 999, outline = 0, name = "Fill" })
	UI.gradient(fill, color)
	-- the glossy top half that makes the fill look like candy
	local gloss = UI.frame({ size = UDim2.new(1, -8, 0.38, 0), pos = UDim2.new(0, 4, 0.08, 0), color = Color3.new(1, 1, 1), parent = fill, radius = 999, outline = 0, name = "Gloss" })
	gloss.BackgroundTransparency = 0.62
	local label = UI.text(holder, "", UDim2.new(1, -24, 0, size.Y * 0.62), { pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), stroke = 2.5 })
	label.ZIndex = holder.ZIndex + 3
	return holder, fill, label
end

-------------------------------------------------------------------------------------------------------------
-- motion
-------------------------------------------------------------------------------------------------------------
-- Skin's own scales are named "Pop": UI's juice engine (one UIScale per object it drives every frame for the click
-- squash, hover grow and idle breath) skips those, so the two never fight over the same scale.
local function popScale(obj: GuiObject): UIScale
	local s = obj:FindFirstChild("Pop") :: UIScale?
	if not s then
		local n = Instance.new("UIScale")
		n.Name = "Pop"
		n.Parent = obj
		s = n
	end
	return s :: UIScale
end

-- Hover grows it and tips the art a little; the click squash and click sound come from UI (every button gets them).
function Skin.press(button: GuiButton, target: GuiObject?)
	local obj = target or button
	local function tilt(rot: number)
		TweenService:Create(obj, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Rotation = rot }):Play()
	end
	if UI.hoverGrow then
		UI.hoverGrow(button, 1.08)
	end
	button.MouseEnter:Connect(function()
		tilt(-3)
	end)
	button.MouseLeave:Connect(function()
		tilt(0)
	end)
end

-- A light streak that sweeps across `face` every `every` seconds (first after `delay`). The streak is clipped to
-- the face, rounded by `radius`.
function Skin.shine(face: GuiObject, every: number?, delay: number?, radius: number?)
	local clip = Instance.new("Frame")
	clip.Name = "Shine"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = face.ZIndex + 4
	clip.Parent = face
	UI.corner(clip, radius or 999)
	local band = Instance.new("Frame")
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Size = UDim2.new(0.28, 0, 2.4, 0)
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(-0.4, 0.5)
	band.Rotation = 22
	band.ZIndex = clip.ZIndex
	band.Parent = clip
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0.45),
		NumberSequenceKeypoint.new(0.55, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = band
	task.spawn(function()
		task.wait(delay or 0)
		while clip.Parent do
			if face.Visible then
				band.Position = UDim2.fromScale(-0.4, 0.5)
				TweenService:Create(band, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(1.4, 0.5) }):Play()
			end
			task.wait(every or 4)
		end
	end)
	return clip
end

-- One four-point twinkle star (two rounded bars), popped in and out once.
local function twinkle(parent: GuiObject, pos: UDim2, size: number, color: Color3?)
	local star = Instance.new("Frame")
	star.Name = "Twinkle"
	star.BackgroundTransparency = 1
	star.Size = UDim2.fromOffset(size, size)
	star.Position = pos
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.ZIndex = parent.ZIndex + 6
	for _, s in { Vector2.new(1, 0.22), Vector2.new(0.22, 1) } do
		local bar = UI.frame({ size = UDim2.fromScale(s.X, s.Y), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = color or Color3.new(1, 1, 1), parent = star, radius = 999, outline = 0 })
		bar.ZIndex = star.ZIndex
	end
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = star
	star.Parent = parent
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(star, TweenInfo.new(0.7, Enum.EasingStyle.Linear), { Rotation = 90 }):Play()
	task.delay(0.42, function()
		local out = TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		out:Play()
		out.Completed:Wait()
		star:Destroy()
	end)
end
Skin.twinkle = twinkle

-- Keeps sparkles twinkling around `obj` while it's on screen (rare items, the selected tool, ready rewards).
-- Returns a function that stops them.
function Skin.sparkles(obj: GuiObject, rate: number?, color: Color3?): () -> ()
	local alive = true
	task.spawn(function()
		local rng = Random.new()
		while alive and obj.Parent do
			if obj.Visible and obj.AbsoluteSize.X > 0 then
				twinkle(obj, UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.05, 0.9)), rng:NextInteger(10, 18), color)
			end
			task.wait((rate or 0.5) * rng:NextNumber(0.6, 1.4))
		end
	end)
	return function()
		alive = false
	end
end

-- A burst of sparkles all at once (a buy, a claim, a level up).
function Skin.burst(obj: GuiObject, count: number?, color: Color3?)
	local rng = Random.new()
	for _ = 1, count or 8 do
		twinkle(obj, UDim2.fromScale(rng:NextNumber(-0.1, 1.1), rng:NextNumber(-0.1, 1.1)), rng:NextInteger(12, 24), color)
	end
end

-- Gentle idle float: objects listed here bob up and down around their own position (one RenderStepped for all).
local bobbing: { { obj: GuiObject, base: UDim2, amp: number, speed: number, phase: number } } = {}
function Skin.bob(obj: GuiObject, amp: number?, speed: number?)
	table.insert(bobbing, { obj = obj, base = obj.Position, amp = amp or 3, speed = speed or 2, phase = #bobbing * 0.9 })
end
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i = #bobbing, 1, -1 do
		local b = bobbing[i]
		if not b.obj.Parent then
			table.remove(bobbing, i)
		else
			b.obj.Position = b.base + UDim2.fromOffset(0, math.sin(t * b.speed + b.phase) * b.amp)
		end
	end
end)

-- A red "something new" dot that pulses. Toggle it with .Visible.
function Skin.dot(parent: GuiObject, pos: UDim2, size: number?): Frame
	local d = UI.frame({ size = UDim2.fromOffset(size or 22, size or 22), pos = pos, anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(232, 69, 60), parent = parent, radius = 999, outline = 3, name = "Dot" })
	;(d:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(90, 20, 16)
	d.ZIndex = parent.ZIndex + 8
	local s = popScale(d)
	TweenService:Create(s, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.25 }):Play()
	d.Visible = false
	return d
end

-- "+250" that pops out of `obj`, rises and fades.
function Skin.floatText(obj: GuiObject, text: string, color: Color3?)
	local label = UI.text(obj, text, UDim2.fromOffset(180, 34), { pos = UDim2.new(1, -40, 0.1, 0), anchor = Vector2.new(0, 0.5), color = color or Color3.fromRGB(120, 255, 90), stroke = 3, align = Enum.TextXAlignment.Left })
	label.ZIndex = obj.ZIndex + 10
	local s = Instance.new("UIScale")
	s.Scale = 0.4
	s.Parent = label
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = label.Position - UDim2.fromOffset(0, 42) }):Play()
	task.delay(0.55, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		label:Destroy()
	end)
end

-- Pop an object in from nothing (a window, a card), with an overshoot.
function Skin.popIn(obj: GuiObject, delay: number?)
	local s = popScale(obj)
	s.Scale = 0.3
	task.delay(delay or 0, function()
		TweenService:Create(s, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

return Skin
