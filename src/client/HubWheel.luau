--!strict
-- THE FREE DAILY WHEEL (10 Nov 2026; owner picked "8"; remodelled the same day: "make the models with blender ... the
-- stud voxel style", design: the Claude Design canvas "Mow And Grow Hub Remodel"). A little fair stall at the hub's
-- WheelSpot (server/HubFun), built from studded bricks (shared/HubBricks, the Blender models wheel_booth + wheel):
-- candy-stripe posts, a striped scalloped canopy, a purple marquee in a gold frame (FREE SPIN!, or the countdown after
-- a spin), the odds on a chalkboard on the right, a red pointer over the wheel. The wheel: eight smooth slices in half
-- studs (Config.HUB_FUN.prizes, gems) in a studded wooden rim, bulbs round it that chase while it waits.
-- SPIN asks the server (it picks the prize and adds the gems; Fx "hubSpin" { index, gems }), then the wheel spins ~5 s,
-- ticking past each slice, and stops on that prize: the bulbs flash in its colour, confetti, a notice. Free, once a
-- UTC day (player attribute HubSpinNext). Only in the lobby; each player sees their own wheel spin.
local HubWheel = {}
task.spawn(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer
	local here = script.Parent
	local Shared = ReplicatedStorage:WaitForChild("MowALawn")
	local Config = require(Shared:WaitForChild("Config"))
	local Format = require(Shared:WaitForChild("Format"))
	local HubBricks = require(Shared:WaitForChild("HubBricks")) :: any
	local State = require(here:WaitForChild("State"))
	local UI = require(here:WaitForChild("UI")) :: any
	local Sound = require(here:WaitForChild("Sound")) :: any
	if not Config.HUB_FUN or not Config.HUB_FUN.on then
		return
	end
	local PRIZES = Config.HUB_FUN.prizes
	local N = #PRIZES
	local SLICE = 2 * math.pi / N
	local R = 6.8 -- the wheel's radius (the Blender model: 13.6 half studs)
	local FONT = Config.UI and Config.UI.font or Enum.Font.FredokaOne
	local INK = Color3.fromRGB(30, 26, 40)
	local WHITE = Color3.new(1, 1, 1)
	local GOLD = Color3.fromRGB(255, 214, 80)
	local WARM = Color3.fromRGB(255, 240, 180)
	local HOT = Color3.fromRGB(255, 120, 80)

	local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
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

	-- a flat, see-through part with a SurfaceGui on its front: text on a model's face
	local function face(parent: Instance, size: Vector2, cf: CFrame, ppS: number?): SurfaceGui
		local p = part(parent, Vector3.new(size.X, size.Y, 0.05), cf, WHITE)
		p.Transparency = 1
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = ppS or 50
		g.LightInfluence = 0
		g.Parent = p
		return g
	end

	local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, stroke: number?): TextLabel
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = size
		t.Position = pos
		t.Font = FONT
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		t.Parent = parent
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = stroke or 3
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
	local function rim(center: CFrame, a: number, r: number, z: number?): CFrame
		return center * CFrame.new(-math.sin(a) * r, math.cos(a) * r, z or 0)
	end

	-- the odds on the chalkboard
	local function odds(f: Folder, at: Vector3, rot: CFrame)
		local total = 0
		for _, p in PRIZES do
			total += p.weight
		end
		local g = face(f, Vector2.new(7.6, 9.6), CFrame.new(at) * rot * CFrame.new(0, 0, -0.06), 32)
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 2)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = g
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.Parent = g
		local head = label(g, "PRIZES & ODDS", UDim2.new(1, 0, 0, 34), UDim2.new(), GOLD)
		head.LayoutOrder = 0
		for i = N, 1, -1 do
			local p = PRIZES[i]
			local row = Instance.new("Frame")
			row.LayoutOrder = N - i + 1
			row.Size = UDim2.new(0.88, 0, 0, 30)
			row.BackgroundTransparency = 1
			row.Parent = g
			label(row, p.board or (Format.commas(p.gems or 0) .. " 💎"), UDim2.fromScale(0.62, 1), UDim2.new(), p.color, 2).TextXAlignment = Enum.TextXAlignment.Left
			label(row, (math.floor(p.weight / total * 1000 + 0.5) / 10) .. "%", UDim2.fromScale(0.38, 1), UDim2.fromScale(0.62, 0), Color3.fromRGB(245, 236, 214), 2).TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	local function build(spot: BasePart): Wheel
		local f = Instance.new("Folder")
		f.Name = "HubWheel"
		f.Parent = workspace
		local at = spot.CFrame
		local rot = at.Rotation
		local _, anchors = HubBricks.build("wheel_booth", at, f)
		-- the wheel: its own model, half a stud in front of the crossbar, turning round its middle
		local center = CFrame.new(anchors.wheel :: Vector3) * rot
		local wheelModel = HubBricks.build("wheel", center * CFrame.new(0, 0, -0.5), f, { collide = false })
		local turning = {}
		for _, p in wheelModel:GetChildren() do
			if p:IsA("BasePart") then
				p.CanQuery = false
				table.insert(turning, p)
			end
		end
		-- the prizes on the slices, reading out from the middle
		for i, p in PRIZES do
			local mid = (i - 1) * SLICE
			local g = face(f, Vector2.new(R * 0.56, 1.2), center * CFrame.Angles(0, 0, mid) * CFrame.new(0, R * 0.6, -0.56) * CFrame.Angles(0, 0, math.rad(90)), 50)
			label(g, p.slice or (Format.commas(p.gems or 0) .. " 💎"), UDim2.fromScale(1, 1), UDim2.new(), WHITE, 3)
			table.insert(turning, g.Parent :: BasePart)
		end
		local capText = face(f, Vector2.new(2.2, 1), center * CFrame.new(0, 0, -0.56), 50)
		label(capText, "FREE", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(232, 68, 58), 2)
		-- bulbs on the rim (they turn too)
		local lights = {}
		for k = 1, N * 2 do
			local b = part(f, Vector3.new(0.5, 0.5, 0.5), rim(center, (k - 0.5) * SLICE / 2, R - 0.45, -0.62), WARM, Enum.Material.Neon)
			b.Shape = Enum.PartType.Ball
			table.insert(lights, b)
			table.insert(turning, b)
		end
		-- the marquee: FREE SPIN! / the countdown
		local marquee = anchors.marquee :: Vector3
		local mg = face(f, Vector2.new(13, 4.4), CFrame.new(marquee) * rot * CFrame.new(0, 0, -0.06), 50)
		local title = label(mg, "FREE SPIN!", UDim2.fromScale(1, 0.64), UDim2.fromScale(0, 0.02), GOLD, 4)
		local sub = label(mg, "once a day", UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.66), WHITE, 3)
		-- bulbs round the marquee: along its top and down its sides
		local spots = {}
		for k = 0, 14 do
			table.insert(spots, Vector3.new(-7 + k, 26.8, -3.3))
		end
		for y = 21.5, 25.5 do
			table.insert(spots, Vector3.new(-7.8, y, -3.3))
			table.insert(spots, Vector3.new(7.8, y, -3.3))
		end
		for k, s in spots do
			local b = part(f, Vector3.new(0.45, 0.45, 0.45), at * CFrame.new(s), if k % 2 == 0 then HOT else WARM, Enum.Material.Neon)
			b.Shape = Enum.PartType.Ball
			table.insert(lights, b)
		end
		odds(f, anchors.odds :: Vector3, rot)
		-- a warm light in the booth
		local lightPart = part(f, Vector3.new(0.2, 0.2, 0.2), at * CFrame.new(0, 15, -3), WHITE)
		lightPart.Transparency = 1
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 220, 160)
		pl.Range = 16
		pl.Brightness = 1.2
		pl.Parent = lightPart
		-- SPIN
		local promptPart = part(f, Vector3.new(1, 1, 1), CFrame.new(anchors.prompt :: Vector3), WHITE)
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
		local rotNow = w.center * CFrame.Angles(0, 0, ang)
		for _, t in w.turning do
			t.p.CFrame = rotNow * t.off
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
				b.Color = if (k + math.floor(os.clock() * 10)) % 2 == 0 then WARM else HOT
			end
			pose(w)
			RunService.Heartbeat:Wait()
		end
		ang = a0 + total
		pose(w)
		spinning = false
		-- the prize
		local prize = PRIZES[i]
		local big = gems >= 100 or prize.egg ~= nil or (prize.gold or 0) >= 600
		pcall(Sound.play, if big then "rareChime" else "purchase", 0.05)
		pcall(function()
			require(here:WaitForChild("Confetti")).burst(if big then 80 else 30)
		end)
		-- (11 Nov) the prize can be gems, a free egg (it hatches now) or 2x gold for your next run
		local what = if prize.egg then ("a free %s!"):format(prize.board or "egg")
			elseif prize.gold then ("2x gold for %d minutes in your next run!"):format(math.floor(prize.gold / 60))
			else ("+%s gems from the Free Wheel"):format(Format.commas(gems))
		pcall(UI.notice, "YOU WON!", what, nil, 3)
		task.spawn(function()
			for _ = 1, 8 do
				for _, b in w.lights do
					b.Color = PRIZES[i].color:Lerp(WHITE, 0.3)
				end
				task.wait(0.15)
				for _, b in w.lights do
					b.Color = WARM
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
				w.title.Text = "NEXT SPIN"
				w.sub.Text = Format.clock(left)
				w.prompt.ActionText = "Come back later"
			else
				w.title.Text = "FREE SPIN!"
				w.sub.Text = "once a day"
				w.prompt.ActionText = "Spin!"
			end
		end
		-- idle: the bulbs chase round
		if not spinning then
			for k, b in w.lights do
				b.Color = if (k + math.floor(now * 3)) % 4 == 0 then HOT else WARM
			end
		end
	end)
end)
return HubWheel
