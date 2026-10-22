-- The Create Party window (like Chop A Forest's), opened by the server when you step onto a free PARTY bay in
-- the lobby. Left: CREATE PARTY with the map card (CHAPTER 1, THE LAWN), the difficulty (Normal; harder ones
-- unlock with wins), Peaceful Mode (no night), the party size, BACK and CREATE. Right: SAVED RUNS, with your
-- saved run and a LOAD GAME button. The server checks every choice (server/Lobby).
-- SAVED RUNS is a garden journal: a ring-bound ruled page, your run as a taped-in instant photo with handwritten
-- notes beside it and a stamped difficulty.
-- Drawn with the ForgeGUI kit (client/Skin) once its pictures are uploaded, otherwise with plain frames.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)

local PartyWindow = {}
local player = Players.LocalPlayer

local FONT = Config.UI.font
local INK = Color3.fromRGB(58, 32, 16)
local WOOD = Color3.fromRGB(196, 116, 56)
local PAPER = Color3.fromRGB(246, 218, 168)
local BROWN = Color3.fromRGB(122, 74, 40)
local DARK = Color3.fromRGB(92, 56, 32)
local GREEN = Color3.fromRGB(86, 200, 70)
local RED = Color3.fromRGB(230, 74, 74)
local BLUE = Color3.fromRGB(56, 140, 255)
local WHITE = Color3.new(1, 1, 1)

-------------------------------------------------------------------------------------------------------------
-- small builders
-------------------------------------------------------------------------------------------------------------
local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, t: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = t
	s.Color = color or INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, a: Color3, b: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = 90
	g.Parent = parent
end

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function frame(parent: Instance, size: UDim2, pos: UDim2, color: Color3, r: number?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if r then
		corner(f, r)
	end
	f.Parent = parent
	return f
end

local function text(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?, strokeT: number?, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = t
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	if strokeT and strokeT > 0 then
		local s = Instance.new("UIStroke")
		s.Thickness = strokeT
		s.Color = INK
		s.Parent = l
	end
	l.Parent = parent
	return l
end

-- A chunky button: the tinted ForgeGUI button art (its lip is in the picture), or a drawn one with a lip under it.
local function button(parent: Instance, label: string, size: UDim2, pos: UDim2, color: Color3, onClick: () -> ()): TextButton
	local art = Skin.has("ui_button")
	if not art then
		local lip = frame(parent, size, pos + UDim2.fromOffset(0, 5), shade(color, 0.62), 12)
		lip.Name = label .. "Lip"
	end
	local b = Instance.new("TextButton")
	b.Name = label
	b.AutoButtonColor = false
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Text = ""
	if art then
		b.BackgroundTransparency = 1
		local px = Vector2.new(if size.X.Scale > 0 then 260 else size.X.Offset, size.Y.Offset)
		local a = Skin.frame(b, "ui_button", px, { name = "Art", boost = 1.7, tint = color })
		a.Size = UDim2.fromScale(1, 1)
	else
		corner(b, 12)
		stroke(b, 3)
		gradient(b, shade(color, 1.18), shade(color, 0.92))
	end
	text(b, label, UDim2.new(1, -16, 0.56, 0), UDim2.new(0, 8, if art then 0.14 else 0.19, 0), WHITE, 2.5)
	b.Parent = parent
	b.MouseButton1Down:Connect(function()
		b.Position = pos + UDim2.fromOffset(0, 3)
	end)
	b.MouseButton1Up:Connect(function()
		b.Position = pos
	end)
	b.MouseLeave:Connect(function()
		b.Position = pos
	end)
	b.Activated:Connect(onClick)
	return b
end

local function setButtonColor(b: TextButton, color: Color3)
	b.BackgroundColor3 = color
	local art = b:FindFirstChild("Art")
	if art and art:IsA("ImageLabel") then
		art.ImageColor3 = color
	end
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(shade(color, 1.18), shade(color, 0.92))
	end
	local lip = b.Parent and b.Parent:FindFirstChild(b.Name .. "Lip") :: Frame?
	if lip then
		lip.BackgroundColor3 = shade(color, 0.62)
	end
end

-- A wooden board (the window's two panels): the ForgeGUI plank sign (or an orange log frame round a paper page),
-- with the grass strip and daisies the other windows have.
local function board(parent: Instance, title: string, size: UDim2, pos: UDim2): Frame
	if Skin.has("ui_sign") then
		local outer = frame(parent, size, pos, WOOD)
		outer.BackgroundTransparency = 1
		local a = Skin.frame(outer, "ui_sign", Vector2.new(size.X.Offset, size.Y.Offset), { name = "Art", maxScale = 0.5 })
		a.Size = UDim2.new(1, 24, 1, 24)
		a.Position = UDim2.fromOffset(-12, -12)
		local page = frame(outer, UDim2.new(1, -28, 1, -28), UDim2.fromOffset(14, 14), PAPER)
		page.BackgroundTransparency = 1
		if Skin.has("ui_grass") then
			local strip = frame(outer, UDim2.new(1, 20, 0, 46), UDim2.new(0, -10, 1, 20), WHITE)
			strip.BackgroundTransparency = 1
			strip.AnchorPoint = Vector2.new(0, 1)
			strip.ClipsDescendants = true
			strip.ZIndex = 5
			local gw = math.floor(46 * 921 / 271)
			for x = 0, size.X.Offset + 20, gw - 14 do
				local g = Instance.new("ImageLabel")
				g.BackgroundTransparency = 1
				g.Image = Config.ICONS.ui_grass
				g.ScaleType = Enum.ScaleType.Fit
				g.Size = UDim2.fromOffset(gw, 46)
				g.Position = UDim2.fromOffset(x, 0)
				g.ZIndex = 5
				g.Parent = strip
			end
		end
		text(parent, title, UDim2.new(size.X.Scale, size.X.Offset, 0, 52), pos - UDim2.fromOffset(0, 62), WHITE, 4)
		return page
	end
	local outer = frame(parent, size, pos, WOOD, 22)
	stroke(outer, 4)
	gradient(outer, Color3.fromRGB(222, 140, 70), Color3.fromRGB(176, 98, 44))
	local page = frame(outer, UDim2.new(1, -28, 1, -28), UDim2.fromOffset(14, 14), PAPER, 14)
	stroke(page, 3, Color3.fromRGB(150, 90, 46))
	gradient(page, Color3.fromRGB(252, 228, 180), Color3.fromRGB(236, 200, 146))
	text(parent, title, UDim2.new(size.X.Scale, size.X.Offset, 0, 52), pos - UDim2.fromOffset(0, 62), WHITE, 4)
	return page
end

-------------------------------------------------------------------------------------------------------------
-- the map card: a little painting of the lawn
-------------------------------------------------------------------------------------------------------------
-- CHAPTER 1 / THE LAWN, the page arrows (one chapter for now) and dots, over the picture
local function mapCardTop(card: Frame, parent: Instance)
	local chapter = frame(card, UDim2.fromOffset(150, 30), UDim2.new(0.5, -75, 1, -86), Color3.fromRGB(70, 44, 26), 15)
	chapter.BackgroundTransparency = 0.1
	text(chapter, "CHAPTER 1", UDim2.new(1, -16, 0.7, 0), UDim2.new(0, 8, 0.15, 0), Color3.fromRGB(255, 186, 80), 0)
	text(card, "THE LAWN", UDim2.new(1, -40, 0, 46), UDim2.new(0, 20, 1, -54), WHITE, 4)
	for side = -1, 1, 2 do
		local arrow = frame(card, UDim2.fromOffset(46, 52), UDim2.new(if side < 0 then 0 else 1, if side < 0 then 10 else -56, 0.5, -40), BLUE, 12)
		stroke(arrow, 3)
		gradient(arrow, Color3.fromRGB(96, 170, 255), Color3.fromRGB(40, 110, 230))
		text(arrow, if side < 0 then "<" else ">", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), WHITE, 2)
		arrow.BackgroundTransparency = 0.25
	end
	for i = 0, 1 do
		local dot = frame(parent, UDim2.fromOffset(if i == 0 then 30 else 16, 14), UDim2.new(0.5, -26 + i * 40, 0, 218), if i == 0 then Color3.fromRGB(190, 220, 190) else Color3.fromRGB(60, 50, 44), 7)
		stroke(dot, 2)
	end
end

local function mapCard(parent: Instance)
	local card = frame(parent, UDim2.new(1, -28, 0, 196), UDim2.fromOffset(14, 14), Color3.fromRGB(150, 210, 255), 16)
	card.ClipsDescendants = true
	stroke(card, 4)
	gradient(card, Color3.fromRGB(110, 190, 255), Color3.fromRGB(220, 242, 255))
	if Skin.has("scene_lawn") then
		-- the ForgeGUI painting of the meadow (sky, windmill, a mowed stripe) instead of the drawn hills
		local art = Instance.new("ImageLabel")
		art.Name = "Painting"
		art.BackgroundTransparency = 1
		art.Image = Config.ICONS.scene_lawn
		art.ScaleType = Enum.ScaleType.Crop
		art.Size = UDim2.fromScale(1, 1)
		corner(art, 14)
		art.Parent = card
		mapCardTop(card, parent)
		return
	end
	local rng = Random.new(5)
	for i = 0, 15 do
		local h = rng:NextNumber(0.24, 0.42)
		frame(card, UDim2.fromScale(0.1, h), UDim2.fromScale(i * 0.068 - 0.03, 0.46 - h * 0.6), Color3.fromRGB(40, 112 + (i % 3) * 16, 54), 40)
	end
	local field = frame(card, UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.5), Color3.fromRGB(110, 205, 70))
	gradient(field, Color3.fromRGB(150, 228, 96), Color3.fromRGB(80, 176, 54))
	for row = 0, 3 do
		local s = 0.035 + row * 0.022
		local n = 13 - row * 2
		for i = 0, n - 1 do
			local x = (i + (row % 2) * 0.5) / n
			local clump = frame(field, UDim2.fromScale(s, s * 3.2), UDim2.fromScale(x - s / 2, 0.06 + row * 0.22), Color3.fromRGB(60, 160 + row * 12, 50), 30)
			frame(clump, UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.25, 0.05), Color3.fromRGB(160, 236, 96), 20)
		end
	end
	mapCardTop(card, parent)
end

-------------------------------------------------------------------------------------------------------------
-- the window
-------------------------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PartyWindow"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Enabled = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
local holder = frame(gui, UDim2.fromOffset(980, 720), UDim2.fromScale(0.5, 0.5), WHITE)
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.BackgroundTransparency = 1
local scaler = Instance.new("UIScale")
scaler.Parent = holder
local function rescale()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	scaler.Scale = math.clamp(math.min(vp.X / 1040, vp.Y / 780) * (UI.size or Config.UI_SIZE or 1), 0.4, 1.1)
end

local choice = { pad = 0, size = Config.PARTY_MAX, difficulty = "Normal", peaceful = false }
local open = false
local refs: { [string]: any } = {}

local function close()
	open = false
	gui.Enabled = false
end

local DIFFS = { { id = "Normal", label = "NORMAL", wins = 0 }, { id = "Hard", label = "HARD", wins = 1 }, { id = "Expert", label = "EXPERT", wins = 5 } }

local function refresh()
	for _, d in DIFFS do
		local b = refs["diff" .. d.id] :: TextButton?
		if b then
			local locked = (refs.wins or 0) < d.wins
			setButtonColor(b, if choice.difficulty == d.id then GREEN elseif locked then DARK else BROWN)
			local l = b:FindFirstChildOfClass("TextLabel")
			if l then
				l.Text = if locked then ("🔒 %d WIN%s"):format(d.wins, if d.wins == 1 then "" else "S") else d.label
			end
		end
	end
	setButtonColor(refs.off, if choice.peaceful then BROWN else RED)
	setButtonColor(refs.on, if choice.peaceful then GREEN else BROWN)
	refs.size.Text = tostring(choice.size)
	refs.people.Text = string.rep("👤", choice.size)
end

local function difficultyRow(page: Frame)
	text(page, "DIFFICULTY", UDim2.fromOffset(160, 22), UDim2.fromOffset(18, 236), Color3.fromRGB(120, 70, 34), 0, Enum.TextXAlignment.Left)
	for i, d in DIFFS do
		refs["diff" .. d.id] = button(page, d.label, UDim2.fromOffset(118, 58), UDim2.fromOffset(14 + (i - 1) * 128, 262), BROWN, function()
			if (refs.wins or 0) >= d.wins then
				choice.difficulty = d.id
				refresh()
			end
		end)
	end
end

-- A brown box on the page: the ForgeGUI sunken wood box (UI.section), or a drawn one.
local function box(parent: Instance, size: UDim2, pos: UDim2): Frame
	if Skin.has("ui_inset") then
		return UI.section(parent, size, pos)
	end
	local card = frame(parent, size, pos, Color3.fromRGB(110, 66, 36), 14)
	stroke(card, 3)
	return card
end

local function peacefulRow(page: Frame)
	local card = box(page, UDim2.new(1, -28, 0, 104), UDim2.fromOffset(14, 334))
	text(card, "🕊️", UDim2.fromOffset(44, 44), UDim2.fromOffset(10, 10), WHITE, 0)
	text(card, "PEACEFUL MODE", UDim2.fromOffset(190, 28), UDim2.fromOffset(60, 10), WHITE, 2, Enum.TextXAlignment.Left)
	text(card, "A calm run - no night, just you and the grass", UDim2.fromOffset(220, 18), UDim2.fromOffset(60, 40), Color3.fromRGB(240, 210, 170), 0, Enum.TextXAlignment.Left)
	refs.off = button(card, "OFF", UDim2.fromOffset(52, 40), UDim2.new(1, -118, 0, 12), RED, function()
		choice.peaceful = false
		refresh()
	end)
	refs.on = button(card, "ON", UDim2.fromOffset(52, 40), UDim2.new(1, -62, 0, 12), BROWN, function()
		choice.peaceful = true
		refresh()
	end)
	for i, chip in { "🌙 No night", "🏆 Wins count" } do
		local c = frame(card, UDim2.fromOffset(120, 24), UDim2.fromOffset(14 + (i - 1) * 130, 68), Color3.fromRGB(70, 42, 24), 8)
		text(c, chip, UDim2.new(1, -10, 0.8, 0), UDim2.new(0, 5, 0.1, 0), Color3.fromRGB(230, 200, 160), 0)
	end
end

local function partyRow(page: Frame)
	local card = box(page, UDim2.new(1, -28, 0, 62), UDim2.fromOffset(14, 450))
	text(card, "PARTY", UDim2.fromOffset(80, 28), UDim2.fromOffset(14, 17), WHITE, 2, Enum.TextXAlignment.Left)
	refs.people = text(card, "", UDim2.fromOffset(110, 30), UDim2.fromOffset(100, 16), Color3.fromRGB(255, 220, 160), 0)
	button(card, "-", UDim2.fromOffset(42, 42), UDim2.new(1, -164, 0, 6), Color3.fromRGB(230, 200, 150), function()
		choice.size = math.max(1, choice.size - 1)
		refresh()
	end)
	local box = frame(card, UDim2.fromOffset(54, 46), UDim2.new(1, -114, 0, 8), Color3.fromRGB(40, 26, 18), 10)
	refs.size = text(box, "", UDim2.fromScale(0.7, 0.75), UDim2.fromScale(0.15, 0.12), WHITE, 0)
	button(card, "+", UDim2.fromOffset(42, 42), UDim2.new(1, -54, 0, 6), Color3.fromRGB(230, 200, 150), function()
		choice.size = math.min(Config.PARTY_MAX, choice.size + 1)
		refresh()
	end)
end

local function buildLeft()
	local page = board(holder, "CREATE PARTY", UDim2.fromOffset(470, 640), UDim2.fromOffset(0, 70))
	mapCard(page)
	difficultyRow(page)
	peacefulRow(page)
	partyRow(page)
	button(page, "BACK", UDim2.fromOffset(150, 66), UDim2.fromOffset(14, 528), RED, function()
		State.fire("Party", "cancel", choice.pad)
		close()
	end)
	button(page, "CREATE", UDim2.new(1, -192, 0, 66), UDim2.fromOffset(178, 528), GREEN, function()
		State.fire("Party", "create", choice.pad, choice.size, choice.difficulty, choice.peaceful)
		close()
	end)
end

local function ago(started: number, now: number): string
	local s = math.max(0, now - started)
	if s < 3600 then
		return ("%dm ago"):format(math.floor(s / 60))
	elseif s < 86400 then
		return ("%dh ago"):format(math.floor(s / 3600))
	end
	return ("%dd ago"):format(math.floor(s / 86400))
end

local HAND = Enum.Font.PatrickHand -- handwriting, for the journal
local PEN = Color3.fromRGB(40, 58, 120) -- blue ballpoint
local JOURNAL = Skin.has("ui_page")

-- handwritten text in blue pen
local function hand(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3?, rot: number?): TextLabel
	local l = text(parent, t, size, pos, color or PEN, 0, Enum.TextXAlignment.Left)
	l.Font = HAND
	l.Rotation = rot or 0
	return l
end

-- the journal page: the ForgeGUI page with binder rings down its left edge, faint ruled lines and a red margin
local function journalPage(page: Frame)
	local art = Skin.frame(page, "ui_page", Vector2.new(412, 612), { name = "Journal", maxScale = 0.3 })
	art.Size = UDim2.new(1, 8, 1, 8)
	art.Position = UDim2.fromOffset(-4, -4)
	art.ZIndex = 1
	for y = 64, 560, 30 do
		local line = frame(page, UDim2.new(1, -48, 0, 2), UDim2.fromOffset(28, y), Color3.fromRGB(150, 190, 230))
		line.BackgroundTransparency = 0.45
		line.ZIndex = 2
	end
	local margin = frame(page, UDim2.new(0, 2, 1, -40), UDim2.fromOffset(52, 20), Color3.fromRGB(230, 110, 110))
	margin.BackgroundTransparency = 0.35
	margin.ZIndex = 2
	if Skin.has("ring") then
		for i = 0, 6 do
			local ring = UI.icon(page, "ring", 34, UDim2.fromOffset(-14, 40 + i * 82))
			ring.Size = UDim2.fromOffset(18, 34)
			ring.ZIndex = 5
		end
	end
end

local function buildRight()
	local page = board(holder, "SAVED RUNS", UDim2.fromOffset(440, 640), UDim2.fromOffset(530, 70))
	if JOURNAL then
		journalPage(page)
		hand(page, "Your runs save by themselves - jump back in!", UDim2.new(1, -90, 0, 26), UDim2.fromOffset(62, 22), nil, -1).ZIndex = 3
	else
		text(page, "Your runs save by themselves - jump back in", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 14), Color3.fromRGB(150, 90, 40), 0)
	end
	local list = frame(page, UDim2.new(1, -28, 1, -60), UDim2.fromOffset(14, 46), WHITE)
	list.BackgroundTransparency = 1
	list.ZIndex = 3
	refs.runs = list
end

-- Your run as a journal entry: an instant photo of the meadow taped in at a tilt, handwritten notes beside it, the
-- difficulty as a rubber stamp, and LOAD GAME at the bottom of the page.
local function journalRun(list: Frame, run: { [string]: any }, now: number)
	local photo = Instance.new("Frame")
	photo.Name = "Photo"
	photo.BackgroundTransparency = 1
	photo.Size = UDim2.fromOffset(176, 186)
	photo.Position = UDim2.fromOffset(46, 20)
	photo.Rotation = -5
	photo.ZIndex = 4
	photo.Parent = list
	local pic = Instance.new("ImageLabel")
	pic.Name = "Picture"
	pic.BackgroundColor3 = Color3.fromRGB(150, 200, 120)
	pic.Image = Config.ICONS.scene_lawn or ""
	pic.ScaleType = Enum.ScaleType.Crop
	pic.Size = UDim2.fromScale(0.8, 0.68)
	pic.Position = UDim2.fromScale(0.1, 0.075)
	pic.ZIndex = 4
	pic.Parent = photo
	if Skin.has("polaroid") then
		local frameArt = UI.icon(photo, "polaroid", 186, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		frameArt.Size = UDim2.fromScale(1, 1)
		frameArt.ZIndex = 5
		-- the photo shows through the polaroid's grey window: draw the picture on top, inside it
		pic.ZIndex = 6
	end
	hand(photo, ("Area %d"):format(run.zone or 1), UDim2.new(0.8, 0, 0, 24), UDim2.fromScale(0.1, 0.8), Color3.fromRGB(60, 60, 70)).ZIndex = 7
	Skin.tape(photo, UDim2.new(0.5, 0, 0, -2), 84, 6)
	-- your face, clipped in the photo's corner like a sticker
	local face = frame(photo, UDim2.fromOffset(46, 46), UDim2.new(1, -30, 0, 96), WHITE, 23)
	face.ZIndex = 8
	stroke(face, 3)
	local head = Instance.new("ImageLabel")
	head.Size = UDim2.new(1, -6, 1, -6)
	head.Position = UDim2.fromOffset(3, 3)
	head.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
	head.ZIndex = 9
	corner(head, 20)
	head.Parent = face
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			head.Image = img
		end
	end)
	-- the notes
	local nextZone = Config.ZONES[(run.zone or 1) + 1]
	local lines = {
		{ "Solo run", 30, Color3.fromRGB(30, 40, 90) },
		{ ("Area %d of %d"):format(run.zone or 1, #Config.ZONES), 24 },
		{ ("%d clumps cut"):format(run.cut or 0), 24 },
		{ "started " .. ago(run.started or now, now), 24 },
	}
	local y = 22
	for _, l in lines do
		hand(list, l[1], UDim2.fromOffset(150, l[2]), UDim2.fromOffset(238, y), l[3]).ZIndex = 4
		y += l[2] + 6
	end
	-- NORMAL, stamped in green ink
	local stamp = frame(list, UDim2.fromOffset(96, 40), UDim2.fromOffset(250, 150), WHITE, 10)
	stamp.BackgroundTransparency = 1
	stamp.Rotation = 10
	stamp.ZIndex = 4
	local ss = stroke(stamp, 3, Color3.fromRGB(60, 150, 70))
	ss.Transparency = 0.15
	local st = text(stamp, "NORMAL", UDim2.new(1, -10, 1, -10), UDim2.fromOffset(5, 5), Color3.fromRGB(60, 150, 70), 0)
	st.TextTransparency = 0.15
	st.ZIndex = 5
	if nextZone then
		hand(list, "Next up: " .. nextZone.name .. "!", UDim2.new(1, -60, 0, 26), UDim2.fromOffset(48, 236), Color3.fromRGB(180, 70, 60), -2).ZIndex = 4
	end
	local b = button(list, "LOAD GAME", UDim2.new(1, -60, 0, 60), UDim2.fromOffset(44, 290), GREEN, function()
		State.fire("Party", "load")
		close()
	end)
	b.ZIndex = 6
end

local function fillRuns(run: { [string]: any }?, now: number)
	local list = refs.runs :: Frame
	list:ClearAllChildren()
	if not run then
		if JOURNAL then
			hand(list, "No saved runs yet...", UDim2.new(1, -80, 0, 32), UDim2.fromOffset(48, 46)).ZIndex = 4
			hand(list, "Start one on the left and it shows up here.", UDim2.new(1, -80, 0, 24), UDim2.fromOffset(48, 86), Color3.fromRGB(110, 110, 130)).ZIndex = 4
			if Skin.has("daisy") then
				local d = UI.icon(list, "daisy", 90, UDim2.fromOffset(150, 150))
				d.ZIndex = 4
				d.Rotation = -10
			end
		else
			text(list, "No saved runs yet", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 40), Color3.fromRGB(150, 100, 60), 0)
		end
		return
	end
	if JOURNAL then
		journalRun(list, run, now)
		return
	end
	local card = box(list, UDim2.new(1, 0, 0, 196), UDim2.fromOffset(0, 0))
	local face = frame(card, UDim2.fromOffset(44, 44), UDim2.fromOffset(14, 12), WHITE, 22)
	local photo = Instance.new("ImageLabel")
	photo.Size = UDim2.new(1, -6, 1, -6)
	photo.Position = UDim2.fromOffset(3, 3)
	photo.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
	corner(photo, 20)
	photo.Parent = face
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			photo.Image = img
		end
	end)
	text(card, "SOLO RUN", UDim2.fromOffset(200, 30), UDim2.fromOffset(68, 18), WHITE, 2, Enum.TextXAlignment.Left)
	local chips = { { "NORMAL", GREEN }, { ("🌿 %d clumps"):format(run.cut or 0), Color3.fromRGB(70, 42, 24) }, { "🕒 " .. ago(run.started or now, now), Color3.fromRGB(70, 42, 24) } }
	local x = 14
	for _, c in chips do
		local w = if c[1] == "NORMAL" then 80 else 118
		local chip = frame(card, UDim2.fromOffset(w, 26), UDim2.fromOffset(x, 66), c[2], 8)
		stroke(chip, 2)
		text(chip, c[1], UDim2.new(1, -10, 0.78, 0), UDim2.new(0, 5, 0.11, 0), WHITE, 0)
		x += w + 8
	end
	text(card, ("Area %d of %d"):format(run.zone or 1, #Config.ZONES), UDim2.fromOffset(200, 20), UDim2.fromOffset(14, 102), Color3.fromRGB(240, 210, 170), 0, Enum.TextXAlignment.Left)
	button(card, "LOAD GAME", UDim2.new(1, -28, 0, 54), UDim2.fromOffset(14, 128), GREEN, function()
		State.fire("Party", "load")
		close()
	end)
end

buildLeft()
buildRight()

function PartyWindow.open(d: { [string]: any })
	choice.pad = d.pad
	choice.size = math.clamp(tonumber(d.max) or Config.PARTY_MAX, 1, Config.PARTY_MAX)
	choice.difficulty = "Normal"
	choice.peaceful = false
	refs.wins = tonumber(d.wins) or 0
	fillRuns(d.run, tonumber(d.now) or os.time())
	refresh()
	rescale()
	open = true
	gui.Enabled = true
	holder.Position = UDim2.fromScale(0.5, 0.56)
	TweenService:Create(holder, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

State.on("fx", function(kind, d)
	if kind == "partySetup" then
		PartyWindow.open(d)
	elseif kind == "partySetupClose" and open and d.pad == choice.pad then
		close()
	elseif kind == "loading" then
		close()
	end
end)

return PartyWindow
