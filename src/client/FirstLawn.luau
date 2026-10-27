-- FIRST LAWN (the report "Making Mow A Lawn feel as satisfying as Chop A Forest", 28 Oct, #1 and #13; owner 27 Oct
-- "do it"; tuning in Config.FIRST_TIMER):
--   * the lobby: a brand-new player gets a card "YOUR FIRST LAWN IS READY!" counting down to a solo run
--     (server/Lobby sends them), with GO NOW and STAY IN LOBBY
--   * a first-timer's first run: once the loaned starter tool goes back (at their first sale, after the intro film)
--     a note says it was a loan and what to buy first
--   * every tool or Grasp you buy shows its reach: a ring on the ground grows from the old size to the new one
-- Server events arrive through client/Fx's "fx" signal (State), so this needs nothing from Fx itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local FirstLawn = {}
local player = Players.LocalPlayer
local C = UI.colors

-------------------------------------------------------------------------------------------------------------
-- the lobby: off to your first lawn
-------------------------------------------------------------------------------------------------------------
local card: Frame? = nil

local function closeCard()
	if card then
		card:Destroy()
		card = nil
	end
end

local function showCountdown(seconds: number)
	closeCard()
	local f = UI.frame({ size = UDim2.fromOffset(560, 210), pos = UDim2.fromScale(0.5, 0.42), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(58, 38, 24), parent = UI.gui, radius = 22, outline = 4, name = "FirstLawn" })
	f.ZIndex = 45
	card = f
	local title = UI.text(f, "YOUR FIRST LAWN IS READY!", UDim2.new(1, -30, 0, 48), { pos = UDim2.fromOffset(15, 14), stroke = 3.5, color = Color3.fromRGB(150, 235, 90) })
	title.ZIndex = 46
	local sub = UI.text(f, "", UDim2.new(1, -30, 0, 30), { pos = UDim2.fromOffset(15, 68), stroke = 2 })
	sub.ZIndex = 46
	local go = UI.button(f, "GO NOW", C.green, UDim2.fromOffset(210, 60), function()
		State.fire("Seen", "firstLawn", "go")
		sub.Text = "Off you go!"
	end, { pos = UDim2.new(0.5, -10, 1, -18), anchor = Vector2.new(1, 1), name = "Go" })
	go.ZIndex = 47
	local stay = UI.button(f, "STAY IN LOBBY", Color3.fromRGB(120, 110, 130), UDim2.fromOffset(210, 60), function()
		State.fire("Seen", "firstLawn", "stay")
		closeCard()
	end, { pos = UDim2.new(0.5, 10, 1, -18), anchor = Vector2.new(0, 1), name = "Stay" })
	stay.ZIndex = 47
	UI.bounce(f)
	Sound.play("purchase", 0.05, 0.6)
	task.spawn(function()
		local left = seconds
		while card == f and left > 0 do
			sub.Text = ("Grab a mower and mow it! Taking you there in %d..."):format(left)
			task.wait(1)
			left -= 1
		end
		if card == f then
			sub.Text = "Off you go!"
			task.wait(6)
			if card == f then
				closeCard()
			end
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the end of the loan (after the intro film, which starts a moment after the first sale)
-------------------------------------------------------------------------------------------------------------
local function loanOver(d)
	local t0 = os.clock()
	while os.clock() - t0 < 60 do
		local data = State.data
		local cam = workspace.CurrentCamera
		local filmDone = data and data.run and data.run.introSeen and not data.run.tutorial
		if (filmDone or os.clock() - t0 > 45) and UI.gui.Enabled and cam and cam.CameraType == Enum.CameraType.Custom then
			break
		end
		task.wait(0.5)
	end
	task.wait(1.2)
	local sub = if d.next and d.cost
		then ("Now earn your own: %s cost %s coins in the cabin"):format(d.next, Format.short(d.cost))
		else "Now earn your own tools in the cabin"
	UI.notice(("The %s was on loan!"):format(d.name or "mower"), sub, "coin")
	Sound.play("rareChime", 0.05, 0.7)
end

-------------------------------------------------------------------------------------------------------------
-- your reach, growing on the ground
-------------------------------------------------------------------------------------------------------------
local function reachRing(from: number, to: number, color: Color3?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or to <= 0 then
		return
	end
	local foot = root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2 - 0.15, 0)
	local anchor = Instance.new("Part")
	anchor.Name = "ReachRing"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(foot)
	anchor.Parent = workspace
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	ring.CFrame = CFrame.Angles(math.rad(90), 0, 0) -- lying flat
	ring.Height = 0.15
	ring.Radius = math.max(0.5, from)
	ring.InnerRadius = math.max(0.2, from - 0.4)
	ring.Color3 = color or Color3.fromRGB(255, 225, 90)
	ring.Transparency = 0.15
	ring.AlwaysOnTop = false
	ring.ZIndex = 1
	ring.Parent = anchor
	local grow = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(ring, grow, { Radius = to, InnerRadius = math.max(0.2, to - 0.4) }):Play()
	task.delay(1.4, function()
		TweenService:Create(ring, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.wait(0.55)
		anchor:Destroy()
	end)
end
FirstLawn.reachRing = reachRing

State.on("fx", function(kind: string, d: any)
	if kind == "firstLawn" then
		showCountdown(math.max(1, math.floor(d and d.seconds or 6)))
	elseif kind == "loanOver" then
		task.spawn(loanOver, d or {})
	elseif kind == "purchase" and d and d.ring then
		reachRing(d.ring.from or 0, d.ring.to or 0, d.ring.color)
	elseif kind == "loading" then
		closeCard()
	end
end)

return FirstLawn
