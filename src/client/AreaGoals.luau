-- AREA GOALS (the report "Making Mow A Lawn feel as satisfying as Chop A Forest", 28 Oct, #9 and #16; owner 27 Oct
-- "do it"; tuning in Config.AREA_FINISH and Config.RUN_MEDALS):
--   * a ding and a "25% MOWED!" pop under the run card as the area passes each share in Config.AREA_FINISH.dings
--     (PowerWash Simulator's "ding" per finished part)
--   * the last few clumps of an area (the final `glowAt` share) glow, with a tall beam over each, so nobody hunts
--     for them; at `autoAt` the server mows what's left (server/Field finishLeftovers) and this says so
--   * the run medal you're on course for sits beside the run timer (Gold under 60 min, then Silver, Bronze), and
--     the one you earned shows at the end of a run (the ending's end screen shows it there: client/Ending)
-- Server events arrive through client/Fx's "fx" signal (State); the area numbers through the world state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local AreaGoals = {}
local player = Players.LocalPlayer
local F = Config.AREA_FINISH

local function runCard(): GuiObject?
	local hud = UI.gui:FindFirstChild("Hud")
	return hud and hud:FindFirstChild("RunInfo") :: GuiObject?
end

-------------------------------------------------------------------------------------------------------------
-- dings as the area fills up
-------------------------------------------------------------------------------------------------------------
local lastZone, lastPct = nil :: number?, nil :: number?

local function dingPop(text: string)
	local card = runCard()
	local label = UI.text(UI.gui, text, UDim2.fromOffset(300, 40), { stroke = 3, color = Color3.fromRGB(170, 240, 110) })
	label.Name = "AreaDing"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.ZIndex = 30
	if card and card.Visible then
		local p, s = card.AbsolutePosition, card.AbsoluteSize
		local sc = UI.gui:FindFirstChildOfClass("UIScale")
		local k = if sc then sc.Scale else 1
		label.Position = UDim2.fromOffset((p.X + s.X / 2) / k, (p.Y + s.Y + 6) / k)
	else
		label.Position = UDim2.new(0.5, 0, 0, 120)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.6, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		label:Destroy()
	end)
end

local function checkDings(w)
	local pct = w.cut / math.max(1, w.total)
	if w.zone ~= lastZone then
		lastZone, lastPct = w.zone, pct -- (joining part-way, or a new area: no dings for what was already mowed)
		return
	end
	local before = lastPct or pct
	lastPct = pct
	-- (a big jump, a black hole say, dings once: for the highest share it passed)
	local passed: number? = nil
	for _, t in F.dings do
		if before < t and pct >= t then
			passed = t
		end
	end
	if passed then
		dingPop(("%d%% MOWED!"):format(math.floor(passed * 100 + 0.5)))
		Sound.playAt("rareChime", 1 + passed * 0.5, 0.7) -- each ding a little higher
	end
end

-------------------------------------------------------------------------------------------------------------
-- the last few clumps glow
-------------------------------------------------------------------------------------------------------------
local MAX_HIGHLIGHTS = 10 -- (Roblox draws at most 31 Highlights at once; leave room for everything else)
type Glow = { model: Model, beam: BasePart, light: Highlight? }
local glowing: { [Model]: Glow } = {}
local glowZone: number? = nil
local told: { [number]: boolean } = {}

local function isClump(m: Instance): boolean
	return m:IsA("Model") and (m.Name == "Clump" or (m.Name:sub(1, 5) == "tuft_" and m.Name:sub(-4) ~= "_cut"))
end

local function standing(zone: number): { Model }
	local out = {}
	local world = workspace:FindFirstChild("World")
	local grass = world and world:FindFirstChild("Grass")
	local area = grass and grass:FindFirstChild("Grass" .. zone)
	if not area then
		return out
	end
	for _, patch in area:GetChildren() do
		for _, m in patch:GetChildren() do
			if isClump(m) then
				table.insert(out, m :: Model)
			end
		end
	end
	return out
end

local function unglow(m: Model)
	local g = glowing[m]
	if g then
		g.beam:Destroy()
		if g.light then
			g.light:Destroy()
		end
		glowing[m] = nil
	end
end

local function clearGlow()
	for m in glowing do
		unglow(m)
	end
	glowZone = nil
end

local function glow(m: Model, lights: number): boolean
	local cf, size = m:GetBoundingBox()
	local beam = Instance.new("Part")
	beam.Name = "LastClumpBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 236, 120)
	beam.Transparency = 0.55
	beam.Size = Vector3.new(0.7, 70, 0.7)
	beam.CFrame = CFrame.new(cf.Position.X, cf.Position.Y + size.Y / 2 + 35, cf.Position.Z)
	beam.Parent = workspace
	local light: Highlight? = nil
	if lights < MAX_HIGHLIGHTS then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 236, 120)
		h.FillTransparency = 0.7
		h.OutlineColor = Color3.fromRGB(255, 255, 255)
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Adornee = m
		h.Parent = beam
		light = h
	end
	glowing[m] = { model = m, beam = beam, light = light }
	return light ~= nil
end

local function updateGlow(w)
	local left = w.total - w.cut
	local limit = math.ceil(w.total * (1 - F.glowAt) - 1e-6)
	if w.boss or left <= 0 or left > limit or w.total <= 0 then
		clearGlow()
		return
	end
	if glowZone ~= w.zone then
		clearGlow()
		glowZone = w.zone
	end
	local now = standing(w.zone)
	local still: { [Model]: boolean } = {}
	local lights = 0
	for _, g in glowing do
		if g.light then
			lights += 1
		end
	end
	for _, m in now do
		still[m] = true
		if not glowing[m] and glow(m, lights) then
			lights += 1
		end
	end
	for m in glowing do
		if not still[m] or not m.Parent then
			unglow(m)
		end
	end
	if not told[w.zone] and #now > 0 then
		told[w.zone] = true
		UI.toast(("Only %d clump%s left: follow the beams!"):format(#now, if #now == 1 then "" else "s"), "yellow")
	end
end

-------------------------------------------------------------------------------------------------------------
-- run medals: the one you're on course for, by the timer
-------------------------------------------------------------------------------------------------------------
local chip: TextLabel? = nil
local runTime, runTimeAt = -1, 0

local function medalChip(): TextLabel?
	if chip and chip.Parent then
		return chip
	end
	local card = runCard()
	if not card then
		return nil
	end
	local t = UI.text(card, "", UDim2.fromOffset(150, 30), { pos = UDim2.fromOffset(4, 8), align = Enum.TextXAlignment.Left, stroke = 2.5 })
	t.Name = "MedalGoal"
	t.ZIndex = 8
	chip = t
	return t
end

local function updateChip()
	local d = State.data
	local w = State.world
	local label = medalChip()
	if not label then
		return
	end
	local peaceful = w and w.night and w.night.peaceful
	if not State.isRun() or not d or not d.run or runTime < 0 or peaceful then
		label.Visible = false
		return
	end
	local now = runTime + math.min(os.clock() - runTimeAt, 5)
	for _, m in Config.RUN_MEDALS do
		if now < m.minutes * 60 then
			label.Visible = true
			-- (29 Oct) a Hard / Expert run says so in front of the medal
			local diff = Config.DIFFICULTY[ReplicatedStorage:GetAttribute("Difficulty") or "Normal"]
			if diff and diff.label ~= "MEDIUM" then
				label.Text = ("%s %s %d:00"):format(diff.label, m.name:upper(), m.minutes) -- (fits the chip on one line)
			else
				label.Text = ("%s under %d:00"):format(m.name:upper(), m.minutes)
			end
			label.TextColor3 = m.color
			return
		end
	end
	label.Visible = false
end

local function medalReveal(id: string)
	for _, m in Config.RUN_MEDALS do
		if m.id == id then
			UI.notice(("%s RUN MEDAL!"):format(m.name:upper()), ("You finished the run in under %d minutes"):format(m.minutes), "star")
			Sound.play("rareChime", 0.03, 0.9)
			return
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- wiring
-------------------------------------------------------------------------------------------------------------
State.on("world", function(w)
	if not w or w.mode ~= "Run" or not w.total or w.loading then
		clearGlow()
		return
	end
	if not w.boss then
		checkDings(w)
	end
	updateGlow(w)
end)

State.on("data", function(d)
	if d and d.run and d.run.time then
		runTime, runTimeAt = d.run.time, os.clock()
	end
end)

State.on("fx", function(kind: string, d: any)
	if kind == "autoFinish" and d then
		UI.notice("THE LAST CLUMPS MOWED THEMSELVES!", ("%d clump%s, +%s coins"):format(d.count or 0, if d.count == 1 then "" else "s", Format.short(d.coins or 0)), "coin")
		Sound.play("purchase", 0.05, 0.8)
	elseif kind == "runComplete" and d and d.medal and not d.ending then
		task.delay(2.5, medalReveal, d.medal)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local ok = pcall(updateChip)
		if not ok then
			chip = nil
		end
		-- clumps cut since the last world update stop glowing at once
		for m in glowing do
			if not m.Parent then
				unglow(m)
			end
		end
	end
end)

return AreaGoals
