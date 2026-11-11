-- (5 Nov, owner after the balance review: "Daily + weekly quests", "Rebirth / prestige") The QUESTS window (the QUESTS
-- side button, Q), in the lobby and in runs:
--   left:  REBIRTH STARS: your stars, title and bonus, the next title with a bar, how runs give stars
--   right: DAILY QUESTS and WEEKLY QUESTS, three each: picture, goal, a progress bar, the gems, a CLAIM button, and a
--          countdown to the next ones (00:00 UTC each day, Monday 00:00 UTC each week)
-- Everything comes from the server (snapshot `quests` from server/QuestBoard, `rebirth` from server/Rebirth); a claim
-- asks the server ("Progress" "claim"), which checks it. Hud lights the button's red dot while something is claimable.
-- Also here: the Rebirth Stars card (client/Moments.rebirth) once a finished run's stars come in (in the lobby after
-- the ending film; at once in a run that ends without one), and the quest-claimed card.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Moments = require(script.Parent.Moments)

local QuestsWindow = {}
local C = UI.colors
local W = UI.wood
local GOLD = Color3.fromRGB(255, 200, 50)
local GREEN = Color3.fromRGB(70, 200, 80)
local GREY = Color3.fromRGB(120, 115, 135)
local ROW = Color3.fromRGB(58, 34, 112)

-- "2d 5h", "5h 12m", "12m 30s"
local function left(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local d, h, m = s // 86400, (s // 3600) % 24, (s // 60) % 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %02dm"):format(h, m)
	end
	return ("%dm %02ds"):format(m, s % 60)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-------------------------------------------------------------------------------------------------------------
-- REBIRTH STARS (left)
-------------------------------------------------------------------------------------------------------------
local function rebirthPanel(panel: Frame)
	local R = Config.REBIRTH
	local box = UI.section(panel, UDim2.fromOffset(290, 520), UDim2.fromOffset(16, 16))
	UI.text(box, "REBIRTH STARS", UDim2.new(1, -30, 0, 34), { pos = UDim2.fromOffset(15, 10), color = W.cream, stroke = 2.5 })
	local star = UI.icon(box, "star", 100, UDim2.new(0.5, 0, 0, 50), Vector2.new(0.5, 0))
	Skin.bob(star, 4, 1.5)
	local count = UI.text(box, "0 / 25", UDim2.new(1, -30, 0, 44), { pos = UDim2.fromOffset(15, 154), stroke = 3.5, name = "Count" })
	local title = UI.text(box, "", UDim2.new(1, -30, 0, 30), { pos = UDim2.fromOffset(15, 200), color = GOLD, stroke = 2.5, name = "Title" })
	local bonus = UI.text(box, "", UDim2.new(1, -30, 0, 26), { pos = UDim2.fromOffset(15, 236), color = W.cream, stroke = 2, name = "Bonus" })
	UI.frame({ size = UDim2.new(1, -50, 0, 4), pos = UDim2.fromOffset(25, 274), color = W.cream, parent = box, radius = 2, outline = 0, name = "Divider" })
	UI.text(box, "NEXT TITLE", UDim2.new(1, -30, 0, 24), { pos = UDim2.fromOffset(15, 288), color = W.cream, stroke = 2 })
	local nextText = UI.text(box, "", UDim2.new(1, -30, 0, 28), { pos = UDim2.fromOffset(15, 314), stroke = 2.5, name = "Next" })
	local _, fill, barText = Skin.bar(box, Vector2.new(250, 32), GOLD, { pos = UDim2.fromOffset(20, 350), name = "Bar" })
	local reward = UI.text(box, "", UDim2.new(1, -30, 0, 24), { pos = UDim2.fromOffset(15, 390), color = Color3.fromRGB(220, 180, 255), stroke = 2, name = "Reward" })
	local hint = UI.text(box, "", UDim2.new(1, -30, 0, 70), { pos = UDim2.fromOffset(15, 430), color = W.cream, stroke = 2, name = "Hint" })
	local parts = {}
	for _, id in Config.DIFFICULTY_ORDER do
		local def = Config.DIFFICULTY[id]
		table.insert(parts, ("%s +%d"):format(def and def.label or id, R.starsByDifficulty[id] or 1))
	end
	hint.Text = "Finish a run for stars:\n" .. table.concat(parts, "  ·  ")
	return function(rb)
		rb = if type(rb) == "table" then rb else { stars = 0 }
		local stars = tonumber(rb.stars) or 0
		count.Text = ("%d / %d"):format(stars, R.maxStars)
		title.Text = if rb.title then string.upper(rb.title) else "NO TITLE YET"
		bonus.Text = ("+%d%% COINS   +%d%% GEMS"):format(math.floor(stars * R.coinsPer * 100 + 0.5), math.floor(stars * R.gemsPer * 100 + 0.5))
		if rb.nextAt then
			nextText.Text = ("%s (%d ⭐)"):format(rb.nextTitle or "", rb.nextAt)
			fill.Size = UDim2.fromScale(math.clamp(stars / rb.nextAt, 0, 1), 1)
			barText.Text = ("%d / %d"):format(stars, rb.nextAt)
			reward.Text = ("+%s gems when you get there"):format(Format.commas(rb.nextGems or 0))
		else
			nextText.Text = "EVERY TITLE EARNED!"
			fill.Size = UDim2.fromScale(1, 1)
			barText.Text = "MAX"
			reward.Text = ""
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- DAILY / WEEKLY (right)
-------------------------------------------------------------------------------------------------------------
-- One quest row.
local function questRow(parent: Instance, i: number, period: string, q)
	local ready = q.done and not q.claimed
	local row = UI.frame({ size = UDim2.new(1, -24, 0, 58), pos = UDim2.fromOffset(12, 46 + (i - 1) * 64), color = if ready then Color3.fromRGB(46, 96, 60) else ROW, parent = parent, radius = 12, outline = 2, name = "Quest" .. i })
	;(row:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if ready then GREEN else Color3.fromRGB(24, 14, 48)
	UI.icon(row, q.icon or "quest", 44, UDim2.fromOffset(8, 7))
	UI.text(row, q.text or "", UDim2.fromOffset(300, 24), { pos = UDim2.fromOffset(60, 3), align = Enum.TextXAlignment.Left, stroke = 2 })
	local _, fill, barText = Skin.bar(row, Vector2.new(300, 26), if q.done then GREEN else C.blue, { pos = UDim2.fromOffset(58, 28), name = "Bar" })
	local goal = math.max(1, tonumber(q.goal) or 1)
	fill.Size = UDim2.fromScale(math.clamp((tonumber(q.progress) or 0) / goal, 0, 1), 1)
	barText.Text = if goal >= 100000 then Format.short(q.progress or 0) .. " / " .. Format.short(goal) else Format.commas(q.progress or 0) .. " / " .. Format.commas(goal)
	UI.icon(row, "gem", 30, UDim2.fromOffset(368, 4))
	UI.text(row, "+" .. Format.short(q.gems or 0), UDim2.fromOffset(70, 28), { pos = UDim2.fromOffset(400, 5), align = Enum.TextXAlignment.Left, color = Color3.fromRGB(220, 180, 255), stroke = 2 })
	if q.egg then
		UI.text(row, "+ FREE EGG", UDim2.fromOffset(104, 18), { pos = UDim2.fromOffset(368, 36), align = Enum.TextXAlignment.Left, color = GOLD, stroke = 1.5 })
	end
	local label = if q.claimed then "DONE ✓" else "CLAIM"
	local color = if ready then GREEN elseif q.claimed then Color3.fromRGB(80, 120, 90) else GREY
	-- (11 Nov, phone check: 46 high was 21 points on a phone, small for a thumb) as tall as the row on a phone
	local b = UI.button(row, label, color, UDim2.fromOffset(116, if require(script.Parent.Device).phone then 56 else 46), function()
		if ready then
			State.fire("Progress", "claim", period, q.slot)
		elseif not q.claimed then
			Sound.play("denied")
		end
	end, { pos = UDim2.new(1, -8, 0.5, 0), anchor = Vector2.new(1, 0.5), name = "Claim" })
	if ready then
		Skin.shine(row, 3, i * 0.4, 12)
		UI.breathe(b, 0.04)
	end
end

-- A DAILY or WEEKLY box; returns (fill, tick): fill(view) redraws its rows, tick() its countdown.
local function questBox(panel: Frame, heading: string, period: string, y: number)
	local box = UI.section(panel, UDim2.fromOffset(628, 252), UDim2.fromOffset(318, y))
	UI.text(box, heading, UDim2.fromOffset(300, 32), { pos = UDim2.fromOffset(16, 8), align = Enum.TextXAlignment.Left, color = W.cream, stroke = 2.5 })
	local clock = UI.text(box, "", UDim2.fromOffset(300, 26), { pos = UDim2.new(1, -16, 0, 11), anchor = Vector2.new(1, 0), align = Enum.TextXAlignment.Right, color = W.cream, stroke = 2, name = "Clock" })
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.fromScale(1, 1)
	rows.Parent = box
	local ends = 0
	local function tick()
		if ends > 0 then
			clock.Text = "New quests in " .. left(ends - now())
		end
	end
	local function fill(view)
		UI.clear(rows)
		local list = if type(view) == "table" and type(view.list) == "table" then view.list else {}
		ends = if type(view) == "table" then tonumber(view.ends) or 0 else 0
		for i, q in list do
			questRow(rows, i, period, q)
		end
		if #list == 0 then
			UI.text(rows, "Loading quests...", UDim2.new(1, -40, 0, 30), { pos = UDim2.fromOffset(20, 100), color = W.cream, stroke = 2 })
		end
		tick()
	end
	return fill, tick
end

function QuestsWindow.build()
	local w = UI.window("Quests", "Quests", nil, { size = Vector2.new(1000, 600), gems = true })
	w.list.Visible = false
	local panel = w.panel :: Frame
	local fillStars = rebirthPanel(panel)
	local fillDaily, tickDaily = questBox(panel, "DAILY QUESTS", "daily", 16)
	local fillWeekly, tickWeekly = questBox(panel, "WEEKLY QUESTS", "weekly", 284)
	w.refresh = function()
		local d = State.data
		if not d then
			return
		end
		if d.gems and w.gemText then
			w.gemText.Text = tostring(d.gems)
		end
		fillStars(d.rebirth)
		local qv = if type(d.quests) == "table" then d.quests else {}
		fillDaily(qv.daily)
		fillWeekly(qv.weekly)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.isOpen("Quests") then
				tickDaily()
				tickWeekly()
			end
		end
	end)
	return w
end

-------------------------------------------------------------------------------------------------------------
-- the cards
-------------------------------------------------------------------------------------------------------------
-- A run that ended with the ending film: its stars wait for the lobby (the film, credits and end screen first).
local endingRun = false
State.on("fx", function(kind, d)
	if kind == "runComplete" and type(d) == "table" and d.ending then
		endingRun = true
	elseif kind == "questClaim" and type(d) == "table" then
		Moments.questClaim(d)
	end
end)

local shownKey: string? = nil
State.on("data", function(d)
	local show = type(d) == "table" and type(d.rebirth) == "table" and d.rebirth.show
	if type(show) ~= "table" then
		return
	end
	local key = tostring(show.stars) .. ":" .. tostring(show.got)
	if key == shownKey or (State.isRun() and endingRun) then
		return
	end
	shownKey = key
	task.spawn(function()
		-- (after the RUN COMPLETE banner in a run; in the lobby after the loading screen and the first popups)
		task.wait(if State.isRun() then 4 else 6)
		local t0 = os.clock()
		while (workspace:GetAttribute("FilmPlaying") == true or UI.anyOpen()) and os.clock() - t0 < 30 do
			task.wait(0.5)
		end
		Moments.rebirth(show)
		State.fire("Progress", "starsSeen")
	end)
end)

QuestsWindow.build()

return QuestsWindow
