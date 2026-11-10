--!strict
-- THE FREE DAILY WHEEL (10 Nov 2026; owner picked "8"). A big brick wheel at the hub's WheelSpot (server/HubFun):
-- eight coloured slices (Config.HUB_FUN.prizes, gems), a red pointer on top, lights round the rim, the odds on a
-- board beside it, and over it FREE SPIN! or the time to the next one. SPIN asks the server (it picks the prize and
-- adds the gems; Fx "hubSpin" { index, gems }), then the wheel spins ~5 s, ticking past each slice, and stops on that
-- prize: the lights flash, confetti, a notice. Free, once a UTC day (player attribute HubSpinNext). Only in the
-- lobby; each player sees their own wheel spin.
local HubWheel = {}
task.spawn(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer
	local here = script.Parent
	local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
	local Format = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Format"))
	local State = require(here:WaitForChild("State"))
	local UI = require(here:WaitForChild("UI")) :: any
	local Sound = require(here:WaitForChild("Sound")) :: any
	if not Config.HUB_FUN or not Config.HUB_FUN.on then
		return
	end
	local PRIZES = Config.HUB_FUN.prizes
	local N = #PRIZES
	local SLICE = 2 * math.pi / N
	local R = 6 -- the wheel's radius
	local HIGH = 8.5 -- its middle above the ground
	local FONT = Config.UI and Config.UI.font or Enum.Font.FredokaOne
	local INK = Color3.fromRGB(30, 26, 40)
	local WOOD = Color3.fromRGB(120, 78, 46)
	local WHITE = Color3.new(1, 1, 1)

	local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, cls: string?, mat: Enum.Material?): BasePart
		local p = Instance.new((cls or "Part") :: any) :: BasePart
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	-- a flat triangle a, b, c (world points), `w` thick: two wedges
	local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, w: number, color: Color3): { BasePart }
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		local w1 = part(parent, Vector3.new(w, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, "WedgePart")
		local w2 = part(parent, Vector3.new(w, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, "WedgePart")
		return { w1, w2 }
	end

	local function label(p: BasePart, text: string, size: number, color: Color3?, face: Enum.NormalId?): TextLabel
		local g = Instance.new("SurfaceGui")
		g.Face = face or Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.LightInfluence = 0
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = FONT
		t.Text = text
		t.TextColor3 = color or WHITE
		t.TextSize = size
		t.Parent = g
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = 4
		s.Parent = t
		return t
	end

	type Wheel = {
		folder: Folder,
		center: CFrame,
		turning: { { p: BasePart, off: CFrame } },
		lights: { BasePart },
		title: TextLabel,
		sub: TextLabel,
		prompt: ProximityPrompt,
	}
	local wheel: Wheel? = nil
	local ang = 0 -- the wheel's turn (radians)
	local spinning = false
	local waiting = false

	-- a point on the wheel's face: angle from the top, counter-clockwise as you look at it
	local function rim(center: CFrame, a: number, r: number, z: number?): Vector3
		return center * Vector3.new(-math.sin(a) * r, math.cos(a) * r, z or 0)
	end

	local function oddsBoard(f: Folder, spot: CFrame)
		local total = 0
		for _, p in PRIZES do
			total += p.weight
		end
		local board = part(f, Vector3.new(5.4, 7.6, 0.5), spot * CFrame.new(R + 4.6, 4.6, 0), WOOD, nil, Enum.Material.WoodPlanks)
		part(f, Vector3.new(0.6, 4.6, 0.6), spot * CFrame.new(R + 4.6, 0.6, 0.3), WOOD, nil, Enum.Material.WoodPlanks)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.LightInfluence = 0
		g.Parent = board
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 4)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = g
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 12)
		pad.Parent = g
		local head = Instance.new("TextLabel")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, 46)
		head.Font = FONT
		head.Text = "PRIZES & ODDS"
		head.TextColor3 = Color3.fromRGB(255, 214, 80)
		head.TextSize = 38
		head.Parent = g
		local hs = Instance.new("UIStroke")
		hs.Color = INK
		hs.Thickness = 3
		hs.Parent = head
		-- the best prize first
		for i = N, 1, -1 do
			local p = PRIZES[i]
			local row = Instance.new("TextLabel")
			row.LayoutOrder = N - i + 1
			row.Size = UDim2.new(0.86, 0, 0, 36)
			row.BackgroundColor3 = p.color
			row.Font = FONT
			row.Text = ("%s gems   ·   %s%%"):format(Format.commas(p.gems), (math.floor(p.weight / total * 1000 + 0.5) / 10))
			row.TextColor3 = WHITE
			row.TextSize = 28
			row.Parent = g
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 10)
			c.Parent = row
			local s = Instance.new("UIStroke")
			s.Color = INK
			s.Thickness = 2.5
			s.Parent = row
		end
	end

	local function build(spot: BasePart): Wheel
		local f = Instance.new("Folder")
		f.Name = "HubWheel"
		f.Parent = workspace
		local at = spot.CFrame
		local center = at * CFrame.new(0, HIGH, 0)
		local turning = {}
		-- the stand: a base, two posts, the round back
		part(f, Vector3.new(9, 1.2, 4), at * CFrame.new(0, 0.6, 0.6), Color3.fromRGB(245, 236, 214))
		for _, x in { -R + 0.4, R - 0.4 } do
			part(f, Vector3.new(0.9, HIGH, 0.9), at * CFrame.new(x * 0.55, HIGH / 2, 0.9), WOOD, nil, Enum.Material.WoodPlanks)
		end
		part(f, Vector3.new(0.6, (R + 0.9) * 2, (R + 0.9) * 2), center * CFrame.new(0, 0, 0.55) * CFrame.Angles(0, math.rad(90), 0), WOOD, nil, Enum.Material.WoodPlanks).Shape = Enum.PartType.Cylinder
		-- the slices and their prizes
		for i, p in PRIZES do
			local mid = (i - 1) * SLICE
			local a0, a1 = mid - SLICE / 2, mid + SLICE / 2
			for _, w in triangle(f, center.Position, rim(center, a0, R), rim(center, a1, R), 0.5, p.color) do
				table.insert(turning, w)
			end
			local tag = part(f, Vector3.new(R * 0.62, 1.1, 0.05), center * CFrame.Angles(0, 0, mid) * CFrame.new(0, R * 0.6, -0.3) * CFrame.Angles(0, 0, math.rad(90)), WHITE)
			tag.Transparency = 1
			label(tag, Format.commas(p.gems) .. " 💎", 40)
			table.insert(turning, tag)
			-- a thin white line between slices
			local line = part(f, Vector3.new(0.12, R, 0.56), center * CFrame.Angles(0, 0, a0) * CFrame.new(0, R / 2, 0), WHITE)
			table.insert(turning, line)
		end
		-- the hub: FREE in the middle
		local cap = part(f, Vector3.new(0.7, 2.6, 2.6), center * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, math.rad(90), 0), WHITE)
		;(cap :: Part).Shape = Enum.PartType.Cylinder
		local capText = part(f, Vector3.new(2.4, 1, 0.05), center * CFrame.new(0, 0, -0.68), WHITE)
		capText.Transparency = 1
		label(capText, "FREE", 34, Color3.fromRGB(255, 90, 90))
		-- lights round the rim (they turn too)
		local lights = {}
		for k = 1, N * 2 do
			local b = part(f, Vector3.new(0.55, 0.55, 0.55), CFrame.new(rim(center, (k - 0.5) * SLICE / 2, R + 0.45, -0.1)), Color3.fromRGB(255, 240, 180), nil, Enum.Material.Neon)
			;(b :: Part).Shape = Enum.PartType.Ball
			table.insert(lights, b)
			table.insert(turning, b)
		end
		-- the pointer on top (still)
		triangle(f, rim(center, 0.12, R + 1.7, -0.45), rim(center, -0.12, R + 1.7, -0.45), rim(center, 0, R - 0.7, -0.45), 0.4, Color3.fromRGB(235, 50, 50))
		oddsBoard(f, at)
		-- FREE SPIN! / the countdown, over it
		local bbPart = part(f, Vector3.new(1, 1, 1), center * CFrame.new(0, R + 3.4, 0), WHITE)
		bbPart.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(300, 74)
		bb.MaxDistance = 110
		bb.LightInfluence = 0
		bb.Parent = bbPart
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0.6, 0)
		title.Font = FONT
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 214, 80)
		title.Text = "FREE SPIN!"
		title.Parent = bb
		local ts = Instance.new("UIStroke")
		ts.Color = INK
		ts.Thickness = 3
		ts.Parent = title
		local sub = title:Clone()
		sub.Position = UDim2.fromScale(0, 0.6)
		sub.Size = UDim2.new(1, 0, 0.4, 0)
		sub.TextColor3 = WHITE
		sub.Text = "once a day"
		sub.Parent = bb
		-- SPIN
		local promptPart = part(f, Vector3.new(1, 1, 1), at * CFrame.new(0, 3, -1.5), WHITE)
		promptPart.Transparency = 1
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Spin!"
		pp.ObjectText = "Free Wheel"
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 14
		pp.RequiresLineOfSight = false
		pp.Parent = promptPart
		local w: Wheel = { folder = f, center = center, turning = {}, lights = lights, title = title, sub = sub, prompt = pp }
		for _, p in turning do
			table.insert(w.turning, { p = p, off = center:ToObjectSpace(p.CFrame) })
		end
		pp.Triggered:Connect(function()
			local nxt = player:GetAttribute("HubSpinNext")
			if spinning or waiting then
				return
			end
			if type(nxt) == "number" and nxt > workspace:GetServerTimeNow() then
				UI.toast(("Next free spin in %s"):format(Format.clock(nxt - workspace:GetServerTimeNow())), "yellow")
				return
			end
			waiting = true
			State.fire("HubFun", "spin")
			task.delay(4, function()
				waiting = false -- (no answer: you can try again)
			end)
		end)
		return w
	end

	local function pose(w: Wheel)
		local rot = w.center * CFrame.Angles(0, 0, ang)
		for _, t in w.turning do
			t.p.CFrame = rot * t.off
		end
	end

	-- spin to slice i: a few whole turns, then easing out onto it, a tick for every slice that goes by
	local function spinTo(w: Wheel, i: number, gems: number)
		spinning = true
		local a0 = ang
		local want = -((i - 1) * SLICE)
		local delta = (want - a0) % (2 * math.pi)
		local total = delta + 2 * math.pi * 5
		local dur = 5
		local t0 = os.clock()
		local lastSlice = math.floor((a0 + SLICE / 2) / SLICE)
		while os.clock() - t0 < dur do
			if wheel ~= w then
				spinning = false
				return
			end
			local t = (os.clock() - t0) / dur
			ang = a0 + total * (1 - (1 - t) ^ 4)
			local s = math.floor((ang + SLICE / 2) / SLICE)
			if s ~= lastSlice then
				lastSlice = s
				pcall(Sound.playAt, "click", 1.6 + math.random() * 0.2, 0.5)
			end
			for k, b in w.lights do
				b.Color = if (k + math.floor(os.clock() * 10)) % 2 == 0 then Color3.fromRGB(255, 240, 180) else Color3.fromRGB(255, 120, 80)
			end
			pose(w)
			RunService.Heartbeat:Wait()
		end
		ang = a0 + total
		pose(w)
		spinning = false
		-- the prize
		local big = gems >= 100
		pcall(Sound.play, if big then "rareChime" else "purchase", 0.05)
		pcall(function()
			require(here:WaitForChild("Confetti")).burst(if big then 80 else 30)
		end)
		pcall(UI.notice, "YOU WON!", ("+%s gems from the Free Wheel"):format(Format.commas(gems)), nil, 3)
		task.spawn(function()
			for _ = 1, 8 do
				for _, b in w.lights do
					b.Color = PRIZES[i].color:Lerp(WHITE, 0.3)
				end
				task.wait(0.15)
				for _, b in w.lights do
					b.Color = Color3.fromRGB(255, 240, 180)
				end
				task.wait(0.15)
			end
		end)
	end

	State.on("fx", function(kind: string, payload: any)
		local w = wheel
		if kind ~= "hubSpin" or not w then
			return
		end
		waiting = false
		if payload.index and payload.gems then
			task.spawn(spinTo, w, payload.index, payload.gems)
		elseif payload.wait then
			UI.toast(("Next free spin in %s"):format(Format.clock(payload.wait - workspace:GetServerTimeNow())), "yellow")
		end
	end)

	local lastText = 0
	RunService.Heartbeat:Connect(function()
		local world = workspace:FindFirstChild("World")
		local fun = world and world:FindFirstChild("HubFun")
		local spot = fun and fun:FindFirstChild("WheelSpot") :: BasePart?
		if not spot or State.isRun() then
			if wheel then
				wheel.folder:Destroy()
				wheel = nil
			end
			return
		end
		if not wheel then
			wheel = build(spot)
			pose(wheel :: Wheel)
		end
		local w = wheel :: Wheel
		local now = os.clock()
		if now - lastText > 0.5 then
			lastText = now
			local nxt = player:GetAttribute("HubSpinNext")
			local left = if type(nxt) == "number" then nxt - workspace:GetServerTimeNow() else 0
			if left > 0 then
				w.title.Text = "NEXT FREE SPIN"
				w.sub.Text = Format.clock(left)
				w.prompt.ActionText = "Come back later"
			else
				w.title.Text = "FREE SPIN!"
				w.sub.Text = "once a day"
				w.prompt.ActionText = "Spin!"
			end
		end
		-- idle: the lights chase round
		if not spinning then
			for k, b in w.lights do
				b.Color = if (k + math.floor(now * 3)) % 4 == 0 then Color3.fromRGB(255, 120, 80) else Color3.fromRGB(255, 240, 180)
			end
		end
	end)
end)
return HubWheel
