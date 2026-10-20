-- STATS window (tabs: Upgrades in a run | Stats | Index): a profile card on the left (headshot in a round
-- wooden frame, names, total playtime) and four big coloured stat cards on the right, with your current
-- boosts underneath. The numbers come from the server snapshot (data.stats); playtime ticks locally between
-- snapshots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local StatsWindow = {}
local W = UI.wood
local player = Players.LocalPlayer

local CARDS = {
	{ key = "cut", title = "Clumps Cut", icon = "stump", color = Color3.fromRGB(70, 150, 240) },
	{ key = "sold", title = "Bundles Sold", icon = "bundle", color = Color3.fromRGB(160, 90, 230) },
	{ key = "coinsEarned", title = "Coins Earned", icon = "coin", color = Color3.fromRGB(80, 190, 80) },
	{ key = "rare", title = "Rare Clumps", icon = "tree", color = Color3.fromRGB(230, 70, 70) },
}

-- "2h 05m", "14m 09s", "45s"
local function playtime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m = s // 3600, (s // 60) % 60
	if h > 0 then
		return ("%dh %02dm"):format(h, m)
	elseif m > 0 then
		return ("%dm %02ds"):format(m, s % 60)
	end
	return s .. "s"
end

-- The round wooden frame with the player's headshot in it.
local function headshot(parent: Instance)
	local ring = UI.frame({ size = UDim2.fromOffset(170, 170), pos = UDim2.new(0.5, 0, 0, 22), anchor = Vector2.new(0.5, 0), color = W.frame, parent = parent, radius = 999, outline = 5, name = "Ring" })
	;(ring:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = W.frameEdge
	UI.grain(ring, W.frame, 30)
	local inner = UI.frame({ size = UDim2.fromOffset(138, 138), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(120, 190, 240), parent = ring, radius = 999, outline = 3, name = "Inner" })
	;(inner:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = W.frameEdge
	local img = Instance.new("ImageLabel")
	img.Name = "Headshot"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ZIndex = inner.ZIndex + 1
	UI.corner(img, 999)
	img.Parent = inner
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then
			img.Image = url
		end
	end)
end

local function profileCard(panel: Frame)
	local card = UI.section(panel, UDim2.fromOffset(290, 470), UDim2.fromOffset(24, 40))
	headshot(card)
	UI.text(card, player.DisplayName, UDim2.new(1, -30, 0, 40), { pos = UDim2.fromOffset(15, 204), stroke = 3, name = "Display" })
	UI.text(card, "@" .. player.Name, UDim2.new(1, -40, 0, 24), { pos = UDim2.fromOffset(20, 246), color = W.cream, stroke = 2, name = "User" })
	UI.frame({ size = UDim2.new(1, -50, 0, 4), pos = UDim2.fromOffset(25, 286), color = W.cream, parent = card, radius = 2, outline = 0, name = "Divider" })
	UI.icon(card, "stopwatch", 64, UDim2.new(0.5, 0, 0, 304), Vector2.new(0.5, 0))
	UI.text(card, "TOTAL PLAYTIME", UDim2.new(1, -40, 0, 30), { pos = UDim2.fromOffset(20, 376), color = W.cream, stroke = 2 })
	return UI.text(card, "0s", UDim2.new(1, -40, 0, 46), { pos = UDim2.fromOffset(20, 408), stroke = 3, name = "Playtime" })
end

-- One big coloured card: title on top, the icon on the left, the number on the right.
local function statCard(panel: Frame, i: number, c): TextLabel
	local col, row = (i - 1) % 2, (i - 1) // 2
	local card = UI.frame({ size = UDim2.fromOffset(290, 190), pos = UDim2.fromOffset(334 + col * 306, 40 + row * 206), color = c.color, parent = panel, radius = 18, outline = 4, name = "Stat_" .. c.key })
	;(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = UI.shade(c.color, 0.45)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(UI.shade(c.color, 1.2), UI.shade(c.color, 0.8))
	g.Rotation = 90
	g.Parent = card
	UI.frame({ size = UDim2.new(1, -16, 0, 6), pos = UDim2.fromOffset(8, 6), color = Color3.new(1, 1, 1), transparency = 0.7, parent = card, radius = 3, outline = 0, name = "Shine" })
	UI.text(card, string.upper(c.title), UDim2.new(1, -24, 0, 40), { pos = UDim2.fromOffset(12, 14), stroke = 3 })
	UI.icon(card, c.icon, 96, UDim2.fromOffset(16, 70))
	return UI.text(card, "0", UDim2.new(1, -136, 0, 70), { pos = UDim2.fromOffset(124, 84), stroke = 3.5, name = "Value" })
end

local function boostLine(d): string
	local best = if (d.bestTime or 0) > 0 then Format.clock(d.bestTime) else "-"
	return ("POWER x%.2f   LUCK x%.2f   SELL x%.2f   RUNS %d   BOSSES %d   BEST %s"):format(
		d.power or 1,
		d.luck or 1,
		d.sell or 1,
		d.stats.runs or 0,
		d.stats.bosses or 0,
		best
	)
end

function StatsWindow.build(tabs)
	local w = UI.window("Stats", "Stats", nil, { tabs = tabs, size = Vector2.new(1000, 580) })
	w.list.Visible = false
	local panel = w.panel :: Frame
	local playText = profileCard(panel)
	local values = {}
	for i, c in CARDS do
		values[c.key] = statCard(panel, i, c)
	end
	local boosts = UI.section(panel, UDim2.fromOffset(596, 58), UDim2.fromOffset(334, 452))
	local boostText = UI.text(boosts, "", UDim2.new(1, -24, 1, -18), { pos = UDim2.fromOffset(12, 9), color = W.cream, stroke = 2 })

	local base, baseAt = 0, os.clock()
	w.refresh = function()
		local d = State.data
		if not d or not d.stats then
			return
		end
		for _, c in CARDS do
			values[c.key].Text = Format.commas(d.stats[c.key] or 0)
		end
		base, baseAt = d.stats.playtime or 0, os.clock()
		playText.Text = playtime(base)
		boostText.Text = boostLine(d)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.isOpen("Stats") then
				playText.Text = playtime(base + os.clock() - baseAt)
			end
		end
	end)
	return w
end

return StatsWindow
