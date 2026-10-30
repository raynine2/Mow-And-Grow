-- NEWS window: the updates list on the left (icon, title, "3d ago", a NEW badge) and the chosen update on the
-- right (a dark banner with UPDATE and date pills, title, description and a big icon; the change list with
-- green diamond bullets; a big green PLAY button that closes the window). Updates live in Config.NEWS.
-- In the lobby it opens by itself once when there's an update you haven't seen (data.stats.newsSeen).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local State = require(script.Parent.State)

local NewsWindow = {}
local C = UI.colors
local W = UI.wood
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local GREEN = Color3.fromRGB(70, 200, 80)

local function newest(): number
	local id = 0
	for _, n in Config.NEWS do
		id = math.max(id, n.id)
	end
	return id
end

local function ago(t: number): string
	local s = math.max(0, os.time() - t)
	if s < 3600 then
		return "just now"
	elseif s < 86400 then
		return (s // 3600) .. "h ago"
	end
	return (s // 86400) .. "d ago"
end

local function dateText(t: number): string
	local d = os.date("!*t", t) :: any
	return ("%s %d, %d"):format(MONTHS[d.month], d.day, d.year)
end

local function pill(parent: Instance, text: string, color: Color3, pos: UDim2, width: number): GuiObject
	if Skin.has("ui_button") then
		local p, face = Skin.frame(parent, "ui_button", Vector2.new(width, 36), { pos = pos, name = "Pill", boost = 1.6, tint = color })
		UI.text(face, text, UDim2.fromScale(1, 1), { stroke = 2 })
		return p
	end
	local p = UI.frame({ size = UDim2.fromOffset(width, 32), pos = pos, color = color, parent = parent, radius = 16, outline = 3, name = "Pill" })
	UI.gradient(p, color)
	UI.text(p, text, UDim2.new(1, -16, 1, -10), { pos = UDim2.fromOffset(8, 5), stroke = 2 })
	return p
end

-- One entry in the left list.
local function entry(list: Instance, order: number, n, selected: boolean, isNew: boolean, onClick: () -> ())
	-- (grass-galaxy: the others violet like the windows' tabs, not the garden kit's brown)
	local color = if selected then W.tabOn elseif C.theme == "galaxy" then W.tabWood else Color3.fromRGB(176, 120, 72)
	-- a tinted ForgeGUI tile (the picked one bright, with a ring and sparkles)
	local b = Skin.tile(color, selected, Vector2.new(272, 78))
	b.Name = "News_" .. n.id
	b.LayoutOrder = order
	UI.icon(b, n.icon or "news", 52, UDim2.fromOffset(12, 10))
	-- (a small NEW badge in the corner: the tilted ribbon covered the title and was cut off by the list)
	UI.text(b, n.title, UDim2.new(1, if isNew then -146 else -84, 0, 30), { pos = UDim2.fromOffset(70, 8), align = Enum.TextXAlignment.Left, stroke = 2.5 })
	UI.text(b, ago(n.time), UDim2.new(1, -84, 0, 20), { pos = UDim2.fromOffset(70, 40), align = Enum.TextXAlignment.Left, color = W.cream, stroke = 1.5 })
	if isNew then
		local badge = UI.frame({ size = UDim2.fromOffset(58, 24), pos = UDim2.new(1, -8, 0, 8), anchor = Vector2.new(1, 0), color = Color3.fromRGB(230, 50, 60), parent = b, radius = 8, outline = 2, name = "NewBadge" })
		UI.text(badge, "NEW", UDim2.new(1, -6, 1, -4), { pos = UDim2.fromOffset(3, 2), stroke = 1.5 })
	end
	UI.raise(b, 4)
	b.MouseButton1Click:Connect(onClick)
	b.Parent = list
end

local function bullets(box: ScrollingFrame, n)
	UI.clear(box)
	for i, line in n.bullets or {} do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -10, 0, 30)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = i
		row.Parent = box
		UI.icon(row, "diamondBullet", 22, UDim2.fromOffset(4, 4))
		-- one text size for every line (scaled text made short lines big and long lines tiny); long lines wrap
		local t = UI.text(row, line, UDim2.new(1, -40, 0, 26), { pos = UDim2.fromOffset(36, 2), align = Enum.TextXAlignment.Left, color = W.cream, stroke = 2, textSize = 19 })
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.TextYAlignment = Enum.TextYAlignment.Top
	end
end

local function scroller(parent: Instance, size: UDim2, pos: UDim2, padding: number): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = size
	s.Position = pos
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = W.cream
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = s
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = s
	return s
end

-- The dark banner on the right; returns a function that fills it with an update.
local function bannerArea(panel: Frame)
	local base = Color3.fromRGB(34, 70, 40)
	local b = UI.frame({ size = UDim2.fromOffset(676, 200), pos = UDim2.fromOffset(332, 16), color = base, parent = panel, radius = 18, outline = 4, name = "Banner" })
	;(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(24, 18, 12)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(60, 120, 60), Color3.fromRGB(20, 44, 26))
	g.Rotation = 25
	g.Parent = b
	if Skin.has("ui_pcard") then
		-- the ForgeGUI wood-rimmed card; the green lawn (with mowed stripes and rays behind the picture) fills it
		b.BackgroundTransparency = 1
		;(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
		local _a, face = Skin.frame(b, "ui_pcard", Vector2.new(676, 200), { name = "Art", maxScale = 0.22 })
		local inner = UI.frame({ size = UDim2.fromScale(1, 1), color = base, parent = face, radius = 10, outline = 0, name = "Inner" })
		inner.ClipsDescendants = true
		local ig = Instance.new("UIGradient")
		ig.Color = ColorSequence.new(Color3.fromRGB(70, 140, 66), Color3.fromRGB(24, 56, 30))
		ig.Rotation = 25
		ig.Parent = inner
		Skin.stripes(inner)
		Skin.rays(inner, Color3.fromRGB(255, 240, 160), 300, UDim2.new(1, -100, 0.5, 0), 22)
		Skin.shine(inner, 7, 1, 10)
	end
	local art = Instance.new("Frame")
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromOffset(170, 170)
	art.Position = UDim2.new(1, -14, 0.5, 0)
	art.AnchorPoint = Vector2.new(1, 0.5)
	art.Parent = b
	local title = UI.text(b, "", UDim2.new(1, -230, 0, 58), { pos = UDim2.fromOffset(26, 62), align = Enum.TextXAlignment.Left, stroke = 4 })
	local desc = UI.text(b, "", UDim2.new(1, -230, 0, 48), { pos = UDim2.fromOffset(26, 124), align = Enum.TextXAlignment.Left, color = W.cream, stroke = 2 })
	local pills = Instance.new("Frame")
	pills.BackgroundTransparency = 1
	pills.Size = UDim2.new(1, -200, 0, 40)
	pills.Position = UDim2.fromOffset(24, 20)
	pills.Parent = b
	return function(n)
		UI.clear(pills)
		local updWidth = 30 + #n.update * 14
		pill(pills, n.update, Color3.fromRGB(255, 140, 30), UDim2.new(), updWidth)
		pill(pills, dateText(n.time), Color3.fromRGB(70, 60, 50), UDim2.fromOffset(updWidth + 10, 0), 150)
		title.Text = string.upper(n.title)
		desc.Text = n.desc or ""
		UI.clear(art)
		local pic = UI.icon(art, n.icon or "news", 150, UDim2.fromOffset(10, 10))
		Skin.bob(pic, 4, 1.4)
	end
end

function NewsWindow.build()
	local w = UI.window("News", "News", nil, { size = Vector2.new(1064, 600) })
	w.list.Visible = false
	local panel = w.panel :: Frame
	local left = UI.section(panel, UDim2.fromOffset(300, 528), UDim2.fromOffset(16, 16))
	UI.text(left, "UPDATES", UDim2.new(1, -30, 0, 36), { pos = UDim2.fromOffset(15, 10), color = W.cream, stroke = 2.5 })
	local list = scroller(left, UDim2.new(1, -8, 1, -56), UDim2.fromOffset(4, 50), 12)
	local fill = bannerArea(panel)
	local box = UI.section(panel, UDim2.fromOffset(440, 312), UDim2.fromOffset(332, 232))
	local bulletBox = scroller(box, UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), 6)
	UI.button(panel, "PLAY", GREEN, UDim2.fromOffset(220, 96), function()
		UI.close()
	end, { pos = UDim2.fromOffset(1008, 544), anchor = Vector2.new(1, 1), name = "Play" })
	local clover = UI.icon(panel, "clover", 130, UDim2.fromOffset(898, 250), Vector2.new(0.5, 0))
	Skin.bob(clover, 4, 1.6)
	UI.text(panel, "Thanks for playing!",UDim2.fromOffset(220, 30), { pos = UDim2.fromOffset(1008, 400), anchor = Vector2.new(1, 0), color = W.brownText, stroke = 0 })

	local selectedId = newest()
	local seenAtOpen: number? = nil
	UI.onWindowChanged.Event:Connect(function(name)
		-- (with deferred events the close that comes before the News window opens can arrive after it opened)
		if name ~= "News" and not UI.isOpen("News") then
			seenAtOpen = nil
		end
	end)
	w.refresh = function()
		local d = State.data
		local seen = if d and d.stats then d.stats.newsSeen or 0 else 0
		if seenAtOpen == nil then
			seenAtOpen = seen
			selectedId = newest()
			if d and seen < newest() then
				State.fire("Seen", "news", newest())
			end
		end
		UI.clear(list)
		local chosen = Config.NEWS[#Config.NEWS]
		for i = #Config.NEWS, 1, -1 do
			local n = Config.NEWS[i]
			if n.id == selectedId then
				chosen = n
			end
			entry(list, #Config.NEWS - i + 1, n, n.id == selectedId, n.id > (seenAtOpen :: number), function()
				selectedId = n.id
				w.refresh()
			end)
		end
		if chosen then
			fill(chosen)
			bullets(bulletBox, chosen)
		end
	end

	-- open once by itself in the lobby when there's news you haven't seen
	local autoDone = false
	State.on("data", function(d)
		if autoDone or State.isRun() or not d or not d.stats then
			return
		end
		autoDone = true
		-- (report #1) not for a brand-new player: they're on their way to their first lawn (client/FirstLawn); the
		-- news can wait until they've played
		if (d.stats.newsSeen or 0) < newest() and not d.newPlayer then
			task.delay(2.5, function()
				if not UI.isOpen("News") then
					UI.open("News")
				end
			end)
		end
	end)
	return w
end

return NewsWindow
