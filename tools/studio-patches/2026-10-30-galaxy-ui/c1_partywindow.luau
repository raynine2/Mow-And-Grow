local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.PartyWindow
local s = m.Source
if string.find(s, [======[local function boardTitle(]======], 1, true) then
	return m.Name .. " already has this patch"
end
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local edits = {
	{ [======[local BLUE = Color3.fromRGB(56, 140, 255)
local WHITE = Color3.new(1, 1, 1)
]======], [======[local BLUE = Color3.fromRGB(56, 140, 255)
local WHITE = Color3.new(1, 1, 1)

-- (30 Oct, owner: "remake the ui ... to a grass galaxy theme") Under Config.UI.theme "galaxy" the window is the night
-- sky in a rim of grass like the others: a grass-green ribbon for each panel's name, the wood colours violet and
-- night blue, and SAVED RUNS a glass card with a picture of your run's area instead of the paper journal.
local GALAXY = Config.UI.theme == "galaxy"
local NIGHT = Color3.fromRGB(30, 18, 70)
local GLASS = Color3.fromRGB(44, 26, 96)
local LEAF = Color3.fromRGB(126, 222, 64)
local STAR = Color3.fromRGB(240, 234, 255)
local DIM = Color3.fromRGB(196, 182, 240)
local LILAC = Color3.fromRGB(120, 92, 214)
if GALAXY then
	INK = Color3.fromRGB(22, 10, 48)
	BROWN = Color3.fromRGB(92, 64, 168)
	DARK = Color3.fromRGB(52, 36, 104)
	BLUE = Color3.fromRGB(128, 84, 236)
end
]======] },
	{ [======[-- A wooden board (the window's two panels):]======], [======[-- The panel's name. Grass-galaxy: a grass-green ribbon across the board's top rim (twinkling sparkles at its
-- ends) and a soft violet glow behind the board; otherwise big words above it.
local function twinkle(img: GuiObject, period: number)
	if img:IsA("ImageLabel") then
		TweenService:Create(img, TweenInfo.new(period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.75 }):Play()
	end
end

local function boardTitle(parent: Instance, title: string, size: UDim2, pos: UDim2)
	if not (GALAXY and Skin.has("gg_ribbon")) then
		text(parent, title, UDim2.new(size.X.Scale, size.X.Offset, 0, 52), pos - UDim2.fromOffset(0, 62), WHITE, 4)
		return
	end
	if Skin.has("glow_soft") then
		local glow = UI.icon(parent, "glow_soft", 10, pos + UDim2.fromOffset(size.X.Offset / 2, size.Y.Offset / 2), Vector2.new(0.5, 0.5))
		glow.Name = "Glow"
		glow.Size = UDim2.fromOffset(size.X.Offset + 170, size.Y.Offset + 170)
		glow.ZIndex = 0
		if glow:IsA("ImageLabel") then
			glow.ScaleType = Enum.ScaleType.Stretch
			glow.ImageColor3 = Color3.fromRGB(150, 96, 255)
			glow.ImageTransparency = 0.45
		end
	end
	local w = math.min(size.X.Offset - 70, 170 + #title * 19)
	local r = Instance.new("Frame")
	r.Name = "Title"
	r.BackgroundTransparency = 1
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Size = UDim2.fromOffset(w, 66)
	r.Position = pos + UDim2.fromOffset(size.X.Offset / 2, -6)
	r.ZIndex = 8
	r.Parent = parent
	local _art, face = Skin.frame(r, "gg_ribbon", Vector2.new(w, 66), { name = "Art", tint = LEAF, maxScale = 0.42 })
	text(face, title, UDim2.new(1, -16, 0.84, 0), UDim2.new(0, 8, 0.06, 0), WHITE, 3.5)
	if Skin.has("sparkle") then
		for i, p in { { 0, 2, 26 }, { 1, 8, 20 }, { 1, -6, 30 } } do
			local s = UI.icon(r, "sparkle", p[3], UDim2.new(p[1], (if p[1] == 0 then -8 else 8) + i, 0, p[2]), Vector2.new(0.5, 0.5))
			twinkle(s, 0.9 + i * 0.35)
		end
	end
end

-- A wooden board (the window's two panels):]======] },
	{ [======[		text(parent, title, UDim2.new(size.X.Scale, size.X.Offset, 0, 52), pos - UDim2.fromOffset(0, 62), WHITE, 4)
		return page
	end
	local outer = frame(parent, size, pos, WOOD, 22)]======], [======[		boardTitle(parent, title, size, pos)
		return page
	end
	local outer = frame(parent, size, pos, WOOD, 22)]======] },
	{ [======[	local chapter = frame(card, UDim2.fromOffset(150, 30), UDim2.new(0.5, -75, 1, -86), Color3.fromRGB(70, 44, 26), 15)
	chapter.BackgroundTransparency = 0.1
]======], [======[	local chapter = frame(card, UDim2.fromOffset(150, 30), UDim2.new(0.5, -75, 1, -86), if GALAXY then NIGHT else Color3.fromRGB(70, 44, 26), 15)
	chapter.BackgroundTransparency = 0.1
	if GALAXY then
		stroke(chapter, 2, LEAF)
	end
]======] },
	{ [======[		gradient(arrow, Color3.fromRGB(96, 170, 255), Color3.fromRGB(40, 110, 230))]======], [======[		if GALAXY then
			gradient(arrow, Color3.fromRGB(176, 136, 255), Color3.fromRGB(96, 52, 210))
		else
			gradient(arrow, Color3.fromRGB(96, 170, 255), Color3.fromRGB(40, 110, 230))
		end]======] },
	{ [======[if i == 0 then Color3.fromRGB(190, 220, 190) else Color3.fromRGB(60, 50, 44), 7)]======], [======[if i == 0 then (if GALAXY then LEAF else Color3.fromRGB(190, 220, 190)) else (if GALAXY then GLASS else Color3.fromRGB(60, 50, 44)), 7)]======] },
	{ [======[	text(page, "DIFFICULTY", UDim2.fromOffset(160, 22), UDim2.fromOffset(18, 236), Color3.fromRGB(120, 70, 34), 0, Enum.TextXAlignment.Left)]======], [======[	text(page, "DIFFICULTY", UDim2.fromOffset(160, 22), UDim2.fromOffset(18, 236), if GALAXY then LEAF else Color3.fromRGB(120, 70, 34), if GALAXY then 2 else 0, Enum.TextXAlignment.Left)]======] },
	{ [======[	text(card, "A calm run - no night, just you and the grass", UDim2.fromOffset(220, 18), UDim2.fromOffset(60, 40), Color3.fromRGB(240, 210, 170), 0, Enum.TextXAlignment.Left)]======], [======[	text(card, "A calm run - no night, just you and the grass", UDim2.fromOffset(220, 18), UDim2.fromOffset(60, 40), if GALAXY then DIM else Color3.fromRGB(240, 210, 170), 0, Enum.TextXAlignment.Left)]======] },
	{ [======[		local c = frame(card, UDim2.fromOffset(120, 24), UDim2.fromOffset(14 + (i - 1) * 130, 68), Color3.fromRGB(70, 42, 24), 8)
		text(c, chip, UDim2.new(1, -10, 0.8, 0), UDim2.new(0, 5, 0.1, 0), Color3.fromRGB(230, 200, 160), 0)]======], [======[		local c = frame(card, UDim2.fromOffset(120, 24), UDim2.fromOffset(14 + (i - 1) * 130, 68), if GALAXY then NIGHT else Color3.fromRGB(70, 42, 24), if GALAXY then 12 else 8)
		if GALAXY then
			stroke(c, 1.5, LILAC)
		end
		text(c, chip, UDim2.new(1, -10, 0.8, 0), UDim2.new(0, 5, 0.1, 0), if GALAXY then STAR else Color3.fromRGB(230, 200, 160), 0)]======] },
	{ [======[	button(card, "-", UDim2.fromOffset(42, 42), UDim2.new(1, -164, 0, 6), Color3.fromRGB(230, 200, 150), function()]======], [======[	button(card, "-", UDim2.fromOffset(42, 42), UDim2.new(1, -164, 0, 6), if GALAXY then LILAC else Color3.fromRGB(230, 200, 150), function()]======] },
	{ [======[	local box = frame(card, UDim2.fromOffset(54, 46), UDim2.new(1, -114, 0, 8), Color3.fromRGB(40, 26, 18), 10)]======], [======[	local box = frame(card, UDim2.fromOffset(54, 46), UDim2.new(1, -114, 0, 8), if GALAXY then NIGHT else Color3.fromRGB(40, 26, 18), 10)
	if GALAXY then
		stroke(box, 2, LEAF)
	end]======] },
	{ [======[	button(card, "+", UDim2.fromOffset(42, 42), UDim2.new(1, -54, 0, 6), Color3.fromRGB(230, 200, 150), function()]======], [======[	button(card, "+", UDim2.fromOffset(42, 42), UDim2.new(1, -54, 0, 6), if GALAXY then LILAC else Color3.fromRGB(230, 200, 150), function()]======] },
	{ [======[local JOURNAL = Skin.has("ui_page")]======], [======[local JOURNAL = Skin.has("ui_page") and not GALAXY]======] },
	{ [======[		text(page, "Your runs save by themselves - jump back in", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 14), Color3.fromRGB(150, 90, 40), 0)]======], [======[		text(page, "Your runs save by themselves - jump back in", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 14), if GALAXY then DIM else Color3.fromRGB(150, 90, 40), 0)]======] },
	{ [======[local function fillRuns(run: { [string]: any }?, now: number)
	local list = refs.runs :: Frame
	list:ClearAllChildren()
]======], [======[-------------------------------------------------------------------------------------------------------------
-- SAVED RUNS under the grass-galaxy theme (30 Oct): your run on a glass card (a picture of its area with the area
-- and the difficulty on it, your face, the clumps cut and the time played, LOAD GAME), or an empty card with the moon.
-------------------------------------------------------------------------------------------------------------
local DIFF_COLOR = { Normal = Color3.fromRGB(86, 200, 70), Hard = Color3.fromRGB(245, 146, 40), Expert = Color3.fromRGB(232, 64, 84) }

-- the difficulty's name as the window shows it (Config.DIFFICULTY's label when the place has one)
local function diffName(id: string?): string
	local defs = (Config :: any).DIFFICULTY
	local d = defs and (defs[id or "Normal"] or defs.Normal)
	return string.upper(if d and d.label then d.label else (id or "Normal"))
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return ("%dh %02dm"):format(s // 3600, (s % 3600) // 60)
	end
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function short(n: number): string
	if n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

-- your face in a grass-green ring
local function headshot(parent: Instance, size: number, pos: UDim2): Frame
	local ring = frame(parent, UDim2.fromOffset(size, size), pos, LEAF, size // 2)
	ring.Name = "Face"
	stroke(ring, 3)
	local head = Instance.new("ImageLabel")
	head.Size = UDim2.new(1, -8, 1, -8)
	head.Position = UDim2.fromOffset(4, 4)
	head.BackgroundColor3 = GLASS
	corner(head, size // 2)
	head.Parent = ring
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then
			head.Image = img
		end
	end)
	return ring
end

-- a night-glass pill: an icon and a number with its word
local function statChip(parent: Instance, pic: string, value: string, word: string, pos: UDim2, w: number)
	local chip = frame(parent, UDim2.fromOffset(w, 44), pos, NIGHT, 14)
	chip.Name = "Stat"
	chip.BackgroundTransparency = 0.1
	stroke(chip, 2, LILAC)
	UI.icon(chip, pic, 34, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5))
	text(chip, value, UDim2.new(1, -54, 0, 22), UDim2.fromOffset(48, 4), STAR, 2, Enum.TextXAlignment.Left)
	text(chip, word, UDim2.new(1, -54, 0, 14), UDim2.fromOffset(48, 26), DIM, 0, Enum.TextXAlignment.Left)
end

local function starRun(list: Frame, run: { [string]: any }, now: number)
	local W = 384
	local card = Skin.frame(list, "gg_card", Vector2.new(W, 414), { name = "RunCard", maxScale = 0.32 })
	card.Position = UDim2.fromOffset(0, 0)
	-- the area's picture, a night shade over its foot so the words read
	local zoneN = run.zone or 1
	local zone = Config.ZONES[zoneN]
	local pic = Instance.new("ImageLabel")
	pic.Name = "Picture"
	pic.BackgroundColor3 = Color3.fromRGB(90, 160, 80)
	pic.Image = Config.ICONS.scene_lawn or ""
	pic.ScaleType = Enum.ScaleType.Crop
	pic.Size = UDim2.fromOffset(W - 36, 186)
	pic.Position = UDim2.fromOffset(18, 18)
	corner(pic, 16)
	stroke(pic, 3)
	pic.Parent = card
	local veil = frame(pic, UDim2.fromScale(1, 1), UDim2.new(), NIGHT, 16)
	veil.Name = "Veil"
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.1) })
	fade.Parent = veil
	local area = frame(pic, UDim2.fromOffset(124, 30), UDim2.fromOffset(10, 10), NIGHT, 15)
	area.BackgroundTransparency = 0.15
	stroke(area, 2, LEAF)
	text(area, ("AREA %d / %d"):format(zoneN, #Config.ZONES), UDim2.new(1, -16, 0.66, 0), UDim2.new(0, 8, 0.17, 0), LEAF, 0)
	local dc = DIFF_COLOR[run.difficulty or "Normal"] or DIFF_COLOR.Normal
	local diff = frame(pic, UDim2.fromOffset(116, 32), UDim2.new(1, -126, 0, 9), dc, 16)
	stroke(diff, 3)
	gradient(diff, shade(dc, 1.2), shade(dc, 0.82))
	text(diff, diffName(run.difficulty), UDim2.new(1, -16, 0.7, 0), UDim2.new(0, 8, 0.14, 0), WHITE, 2)
	text(pic, string.upper(zone and zone.name or "The Lawn"), UDim2.new(1, -112, 0, 34), UDim2.new(0, 96, 1, -46), WHITE, 3, Enum.TextXAlignment.Left)
	-- you, and the run
	headshot(card, 76, UDim2.fromOffset(26, 160))
	text(card, "SOLO RUN", UDim2.fromOffset(250, 30), UDim2.fromOffset(112, 212), WHITE, 2.5, Enum.TextXAlignment.Left)
	text(card, "started " .. ago(run.started or now, now), UDim2.fromOffset(250, 18), UDim2.fromOffset(112, 244), DIM, 0, Enum.TextXAlignment.Left)
	local half = math.floor((W - 36 - 10) / 2)
	statChip(card, "clover", short(run.cut or 0), "clumps cut", UDim2.fromOffset(18, 272), half)
	statChip(card, "stopwatch", clock(run.time or 0), "played", UDim2.fromOffset(28 + half, 272), half)
	local b = button(card, "LOAD GAME", UDim2.fromOffset(W - 36, 64), UDim2.fromOffset(18, 330), GREEN, function()
		State.fire("Party", "load")
		close()
	end)
	b.ZIndex = 2
	-- what's next
	local nextZone = Config.ZONES[zoneN + 1]
	if nextZone then
		local line = frame(list, UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 428), WHITE)
		line.BackgroundTransparency = 1
		local s = UI.icon(line, "sparkle", 22, UDim2.new(0, 22, 0.5, 0), Vector2.new(0.5, 0.5))
		twinkle(s, 1.1)
		text(line, "Next up: " .. nextZone.name, UDim2.new(1, -50, 1, 0), UDim2.fromOffset(40, 0), LEAF, 2, Enum.TextXAlignment.Left)
	end
end

local function noRuns(list: Frame)
	local card = Skin.frame(list, "gg_card", Vector2.new(384, 290), { name = "Empty", maxScale = 0.32 })
	if card:IsA("ImageLabel") then
		card.ImageTransparency = 0.15
	end
	local moon = UI.icon(card, "moon", 118, UDim2.new(0.5, 0, 0, 26), Vector2.new(0.5, 0))
	moon.Rotation = -8
	for i, p in { { -96, 50, 30 }, { 92, 36, 24 }, { 74, 126, 20 }, { -70, 140, 16 } } do
		local s = UI.icon(card, "sparkle", p[3], UDim2.new(0.5, p[1], 0, p[2]), Vector2.new(0.5, 0.5))
		twinkle(s, 0.8 + i * 0.3)
	end
	text(card, "NO SAVED RUNS YET", UDim2.new(1, -60, 0, 34), UDim2.fromOffset(30, 162), WHITE, 3)
	text(card, "Start one on the left - it shows up here.", UDim2.new(1, -70, 0, 20), UDim2.fromOffset(35, 206), DIM, 0)
	text(card, "Your run saves by itself.", UDim2.new(1, -70, 0, 18), UDim2.fromOffset(35, 234), LEAF, 0)
end

local function fillRuns(run: { [string]: any }?, now: number)
	local list = refs.runs :: Frame
	list:ClearAllChildren()
	if GALAXY then
		if run then
			starRun(list, run, now)
		else
			noRuns(list)
		end
		return
	end
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "NOT CHANGED: edit " .. k .. " not found once in " .. m.Name
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
