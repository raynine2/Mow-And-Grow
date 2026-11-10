--!strict
-- TUTOR GUIDE (10 Nov 2026). The owner sent a video ("replace boring text tutorials with NPC avatars that guide
-- players through your game, react to their actions, and teach them as they play; keep it fast and skippable") and
-- picked: two guides wearing his own avatar and brrbrr's (Config.TUTOR_GUIDES, built by server/GuideAvatars.server),
-- walking with you, instead of the step card.
--
-- While client/Coach's first-run tutorial is on, the two walk beside you (only you see them):
--   * the lead (RAYAN) walks a few steps ahead toward the next goal (Coach.target: the glowing clump, your bundles,
--     the shredder) and says what to do in a speech bubble over his head; when you're there he waits beside you
--   * the other (BRRBRR) walks at your side and reacts: your first cut, a full bag, your first sale
-- Coach's card stays hidden while they're out (Coach.cardHidden); the arrow, the glow and the trail stay. They
-- step aside during cutscenes and boss fights, wave goodbye when the tutorial's done, and a SKIP button sends them
-- home (the card doesn't come back: the arrow keeps pointing). If the avatars can't be built, the old card shows.
-- (A module required by Client.client, so it shares client/Coach with the game: as a LocalScript of its own it got
-- a second Coach, with a second card, arrow and trail.)
local TutorGuide = {}
task.spawn(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")

	local player = Players.LocalPlayer
	local here = script.Parent
	local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
	local State = require(here:WaitForChild("State"))

	local GUIDES = (Config :: any).TUTOR_GUIDES or {}
	if #GUIDES == 0 then
		return
	end

	-- wait until the game's own client has started (the coach needs its UI)
	repeat
		task.wait(0.5)
	until State.data ~= nil
	local Coach = require(here:WaitForChild("Coach")) :: any
	local Device = require(here:WaitForChild("Device")) :: any
	local Sound = require(here:WaitForChild("Sound")) :: any
	local UI = require(here:WaitForChild("UI")) :: any

	local ANIM = {
		walk = "rbxassetid://507777826",
		idle = "rbxassetid://507766388",
		wave = "rbxassetid://507770239",
		cheer = "rbxassetid://507770677",
		point = "rbxassetid://507770453",
	}
	local SPEED = 24 -- studs a second at most (you run ~16-24)
	local WHITE = Color3.new(1, 1, 1)
	local INK = Color3.fromRGB(30, 26, 40)

	-------------------------------------------------------------------------------------------------------------
	-- the bodies
	-------------------------------------------------------------------------------------------------------------
	type Guide = {
		def: any,
		model: Model,
		root: BasePart,
		hum: Humanoid,
		tracks: { [string]: AnimationTrack },
		playing: string?,
		pos: Vector3,
		yaw: number,
		bubble: BillboardGui,
		text: TextLabel,
		sayUntil: number,
		busyUntil: number,
	}

	local folder = Instance.new("Folder")
	folder.Name = "TutorGuides"
	local guides: { Guide } = {}
	local lead: Guide? = nil
	local side: Guide? = nil

	local function bubbleFor(def: any, head: BasePart): (BillboardGui, TextLabel)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Speech"
		bb.Adornee = head
		bb.Size = UDim2.fromOffset(if Device.touch then 230 else 280, 96)
		bb.StudsOffset = Vector3.new(0, 2.2, 0) -- (low enough to stay on screen from close by)
		bb.AlwaysOnTop = false -- (seen in Studio: an AlwaysOnTop bubble on these client-made avatars never drew)
		bb.MaxDistance = 70
		bb.LightInfluence = 0
		bb.ResetOnSpawn = false
		bb.Enabled = false
		local box = Instance.new("Frame")
		box.Name = "Box"
		box.AnchorPoint = Vector2.new(0.5, 1)
		box.Position = UDim2.fromScale(0.5, 1)
		box.Size = UDim2.new(1, 0, 0, 60)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.BackgroundColor3 = WHITE
		box.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = box
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 3
		stroke.Parent = box
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 16)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = box
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.AnchorPoint = Vector2.new(0, 0.5)
		name.Position = UDim2.new(0, 0, 0, -16)
		name.Size = UDim2.fromOffset(0, 22)
		name.AutomaticSize = Enum.AutomaticSize.X
		name.BackgroundColor3 = def.color or Color3.fromRGB(255, 196, 60)
		name.Font = (UI.colors and UI.colors.font) or Enum.Font.FredokaOne
		name.Text = "  " .. tostring(def.label or def.key) .. "  "
		name.TextColor3 = INK
		name.TextSize = 16
		name.Parent = box
		local nc = Instance.new("UICorner")
		nc.CornerRadius = UDim.new(0, 8)
		nc.Parent = name
		local ns = Instance.new("UIStroke")
		ns.Color = INK
		ns.Thickness = 2
		ns.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ns.Parent = name
		local t = Instance.new("TextLabel")
		t.Name = "Line"
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 0)
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.Font = (UI.colors and UI.colors.font) or Enum.Font.FredokaOne
		t.TextColor3 = INK
		t.TextSize = if Device.touch then 17 else 19
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = ""
		t.Parent = box
		-- the little tail under the bubble
		local tail = Instance.new("Frame")
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.new(0.5, 0, 1, 8)
		tail.Size = UDim2.fromOffset(14, 14)
		tail.Rotation = 45
		tail.BackgroundColor3 = WHITE
		tail.BorderSizePixel = 0
		tail.ZIndex = 0
		tail.Parent = box
		local ts = Instance.new("UIStroke")
		ts.Color = INK
		ts.Thickness = 3
		ts.Parent = tail
		bb.Parent = head
		return bb, t
	end

	local function build(def: any, template: Model): Guide?
		local m = template:Clone()
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = m:FindFirstChildOfClass("Humanoid")
		local head = m:FindFirstChild("Head") :: BasePart?
		if not root or not hum or not head then
			m:Destroy()
			return nil
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				d.Anchored = d == root
			end
		end
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = hum
		local bb, t = bubbleFor(def, head)
		local g: Guide = {
			def = def,
			model = m,
			root = root,
			hum = hum,
			tracks = {},
			playing = nil,
			pos = Vector3.zero,
			yaw = 0,
			bubble = bb,
			text = t,
			sayUntil = 0,
			busyUntil = 0,
		}
		for k, id in ANIM do
			local a = Instance.new("Animation")
			a.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(a)
			end)
			if ok and track then
				track.Looped = k == "walk" or k == "idle"
				track.Priority = if k == "walk" or k == "idle" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
				g.tracks[k] = track
			end
		end
		m.Parent = folder
		return g
	end

	local function play(g: Guide, k: string)
		if g.playing == k then
			return
		end
		local old = g.playing and g.tracks[g.playing]
		if old then
			old:Stop(0.2)
		end
		local t = g.tracks[k]
		if t then
			t:Play(0.2)
		end
		g.playing = k
	end

	local function gesture(g: Guide, k: string)
		local t = g.tracks[k]
		if t then
			t:Play(0.1)
			g.busyUntil = os.clock() + math.min(t.Length > 0 and t.Length or 1.5, 2.2)
		end
	end

	-- the guides' bodies, once the server has built them (up to ~15 s; none = the old card stays)
	local ready = false
	task.spawn(function()
		local src = ReplicatedStorage:WaitForChild("MowALawnGuides", 30)
		if not src then
			return
		end
		for _, def in GUIDES do
			local template = src:WaitForChild(def.key, 15) :: Model?
			if template then
				local g = build(def, template)
				if g then
					table.insert(guides, g)
					if def.lead and not lead then
						lead = g
					elseif not side then
						side = g
					end
				end
			end
		end
		if not lead and side then
			lead, side = side, nil
		end
		ready = lead ~= nil
	end)

	-------------------------------------------------------------------------------------------------------------
	-- talking
	-------------------------------------------------------------------------------------------------------------
	local talkToken: { [Guide]: number } = {}
	local function say(g: Guide?, line: string, hold: number?)
		if not g then
			return
		end
		talkToken[g] = (talkToken[g] or 0) + 1
		local token = talkToken[g]
		g.bubble.Enabled = true
		g.text.Text = line
		g.text.MaxVisibleGraphemes = 0
		local box = g.bubble:FindFirstChild("Box") :: Frame?
		if box then
			box.Size = UDim2.new(0.85, 0, 0, 60)
			TweenService:Create(box, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0, 60) }):Play()
		end
		pcall(Sound.play, "click", 0.1, 0.6)
		local life = (hold or 2.6) + #line * 0.045
		g.sayUntil = os.clock() + life
		task.spawn(function()
			local n = utf8.len(line) or #line
			for i = 1, n, 2 do
				if talkToken[g] ~= token then
					return
				end
				g.text.MaxVisibleGraphemes = i + 1
				task.wait(1 / 55)
			end
			g.text.MaxVisibleGraphemes = -1
			task.wait(life)
			if talkToken[g] == token then
				g.bubble.Enabled = false
			end
		end)
	end

	local function quiet()
		for _, g in guides do
			talkToken[g] = (talkToken[g] or 0) + 1
			g.bubble.Enabled = false
		end
	end

	local function click(): string
		return if Device.touch then "Tap" else "Click"
	end

	-- what the lead says when a step starts, and what the other one adds (nil = nothing)
	local function stepLines(id: string): (string?, string?)
		if id == "mow" then
			return "Yo! Walk into that glowing grass to mow it.", "Grass = coins. Easy money."
		elseif id == "punch" then
			return "Yo! " .. click() .. " that glowing clump to cut it.", "Grass = coins. Easy money."
		elseif id == "collect" then
			return "Nice! Now walk over your bundles to grab them.", nil
		elseif id == "fill" then
			return "Keep cutting till your bag is full.", nil
		elseif id == "sell" then
			return "Bag's full! Follow me to the shredder.", "Cha-ching time!"
		elseif id == "upgrade" then
			return if Device.touch then "Tap UPGRADES and buy Swing Speed. Trust me." else "Press TAB and buy Swing Speed. Trust me.", "You'll cut way faster."
		end
		return nil, nil
	end

	-------------------------------------------------------------------------------------------------------------
	-- skip
	-------------------------------------------------------------------------------------------------------------
	local skipped = false
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipGuide"
	skipBtn.AnchorPoint = Vector2.new(1, 1)
	skipBtn.Position = UDim2.new(1, -16, 1, -150)
	skipBtn.Size = UDim2.fromOffset(128, 34)
	skipBtn.BackgroundColor3 = Color3.fromRGB(40, 34, 52)
	skipBtn.BackgroundTransparency = 0.15
	skipBtn.Font = (UI.colors and UI.colors.font) or Enum.Font.FredokaOne
	skipBtn.Text = if Device.touch then "SKIP GUIDE  ✕" else "SKIP GUIDE [H]" -- (in first person the mouse is locked: H)
	skipBtn.TextColor3 = WHITE
	skipBtn.TextSize = 16
	skipBtn.Visible = false
	skipBtn.AutoButtonColor = true
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = skipBtn
		local s = Instance.new("UIStroke")
		s.Color = WHITE
		s.Transparency = 0.6
		s.Thickness = 1.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = skipBtn
	end
	skipBtn.Parent = UI.gui

	-------------------------------------------------------------------------------------------------------------
	-- walking
	-------------------------------------------------------------------------------------------------------------
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function ground(at: Vector3): number?
		local char = player.Character
		rayParams.FilterDescendantsInstances = { folder, char :: any }
		local hit = workspace:Raycast(at + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), rayParams)
		return hit and hit.Position.Y
	end

	local function poof(at: Vector3)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.new(4, 0.2, 4)
		p.CFrame = CFrame.new(at)
		p.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Speed = NumberRange.new(4, 8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(1.6, 3)
		e.Transparency = NumberSequence.new(0.3, 1)
		e.Color = ColorSequence.new(WHITE)
		e.Parent = p
		e:Emit(12)
		Debris:AddItem(p, 1)
	end

	local function place(g: Guide, at: Vector3, yaw: number)
		local y = ground(at) or at.Y
		local up = g.hum.HipHeight + g.root.Size.Y / 2
		g.pos = Vector3.new(at.X, y, at.Z)
		g.yaw = yaw
		g.model:PivotTo(CFrame.new(g.pos + Vector3.new(0, up, 0)) * CFrame.Angles(0, yaw, 0))
	end

	local function yawOf(v: Vector3): number
		return math.atan2(-v.X, -v.Z)
	end

	local function walkTo(g: Guide, want: Vector3, face: Vector3?, dt: number)
		local flatPos = Vector3.new(g.pos.X, 0, g.pos.Z)
		local flatWant = Vector3.new(want.X, 0, want.Z)
		local d = flatWant - flatPos
		local dist = d.Magnitude
		if dist > 60 then
			-- left far behind (a teleport, the mower): pop over to you
			poof(g.pos)
			place(g, want, g.yaw)
			poof(g.pos)
			return
		end
		local step = math.min(dist, SPEED * dt * math.clamp(dist / 4, 0.25, 1))
		local moved = if dist > 0.05 then d.Unit * step else Vector3.zero
		local nextAt = g.pos + moved
		local speed = moved.Magnitude / math.max(dt, 1e-3)
		local yawWant = g.yaw
		if speed > 2 then
			yawWant = yawOf(d)
		elseif face then
			local f = Vector3.new(face.X - g.pos.X, 0, face.Z - g.pos.Z)
			if f.Magnitude > 0.5 then
				yawWant = yawOf(f)
			end
		end
		local dy = (yawWant - g.yaw + math.pi) % (2 * math.pi) - math.pi
		local yaw = g.yaw + dy * math.min(1, dt * 10)
		local y = ground(nextAt) or g.pos.Y
		g.pos = Vector3.new(nextAt.X, g.pos.Y + (y - g.pos.Y) * math.min(1, dt * 14), nextAt.Z)
		g.yaw = yaw
		local up = g.hum.HipHeight + g.root.Size.Y / 2
		g.model:PivotTo(CFrame.new(g.pos + Vector3.new(0, up, 0)) * CFrame.Angles(0, yaw, 0))
		if os.clock() > g.busyUntil then
			if speed > 2 then
				play(g, "walk")
				local t = g.tracks.walk
				if t then
					t:AdjustSpeed(math.clamp(speed / 14, 0.6, 1.8))
				end
			else
				play(g, "idle")
			end
		end
	end

	-------------------------------------------------------------------------------------------------------------
	-- the loop
	-------------------------------------------------------------------------------------------------------------
	local out = false -- are the guides in the world
	local lastStep: string? = nil
	local stepSaidAt = 0
	local seenCut = false
	local seenFull = false
	local seenSale = false
	local lastCoins: number? = nil
	local everOn = false
	local leaving = false

	local function myRoot(): BasePart?
		local char = player.Character
		return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	local function cutsceneOn(): boolean
		local cam = workspace.CurrentCamera
		return cam ~= nil and cam.CameraType ~= Enum.CameraType.Custom
	end

	local function bringOut(root: BasePart)
		out = true
		folder.Parent = workspace
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
		local right = Vector3.new(-look.Z, 0, look.X)
		if lead then
			place(lead, root.Position + look * 10 + right * 3, yawOf(-look))
			poof(lead.pos)
		end
		if side then
			place(side, root.Position + look * 3 - right * 4, yawOf(-look))
			poof(side.pos)
		end
	end

	local function putAway()
		if not out then
			return
		end
		out = false
		quiet()
		for _, g in guides do
			poof(g.pos)
		end
		folder.Parent = nil
	end

	local function skip()
		if skipped or not skipBtn.Visible then
			return
		end
		skipped = true
		skipBtn.Visible = false
		putAway()
		-- the card stays away too: the arrow, the glow and the trail keep showing the way
		Coach.cardHidden = true
	end
	skipBtn.Activated:Connect(skip)
	game:GetService("UserInputService").InputBegan:Connect(function(input: InputObject, typing: boolean)
		if not typing and input.KeyCode == Enum.KeyCode.H then
			skip()
		end
	end)

	-- the goodbye: both wave, then go
	local function goodbye()
		if leaving or not out then
			return
		end
		leaving = true
		skipBtn.Visible = false
		say(lead, "You're a natural! We'll see you around.", 1.5)
		if lead then
			gesture(lead, "wave")
		end
		task.delay(1.2, function()
			say(side, "Bye bye!", 0.8)
			if side then
				gesture(side, "wave")
			end
		end)
		task.delay(4.2, function()
			putAway()
			Coach.cardHidden = false
		end)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		if not ready or skipped then
			return
		end
		local root = myRoot()
		local active = Coach.active() and State.isRun()
		local blocked = cutsceneOn() or (State.world ~= nil and State.world.boss ~= nil)
		if active then
			everOn = true
		end
		-- done = the first upgrade is bought (Coach's own finish line), not just the coach pausing for a cutscene
		local d0 = State.data
		local done = d0 ~= nil and d0.run ~= nil and d0.run.upgrades ~= nil and (d0.run.upgrades.swing or 0) >= 1
		if not active then
			if everOn and out and not leaving and done and not blocked then
				goodbye()
			elseif not out and not leaving then
				Coach.cardHidden = false
			end
			if not out then
				skipBtn.Visible = false
			end
		end
		if leaving then
			if out and root then
				-- stand still and wave
				for _, g in guides do
					walkTo(g, g.pos, root.Position, dt)
				end
			end
			return
		end
		if blocked and out then
			putAway() -- a cutscene, a boss fight, loading: step aside (back after)
		end
		if not active or not root then
			return
		end
		-- the card is ours while the tutorial runs (so it doesn't flash back during a cutscene)
		Coach.cardHidden = true
		if blocked then
			putAway()
			skipBtn.Visible = false
			return
		end
		if not out then
			bringOut(root)
			lastStep = nil
		end
		skipBtn.Visible = true

		local p = root.Position
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
		local right = Vector3.new(-look.Z, 0, look.X)
		local target = Coach.target()
		local now = os.clock()

		-- the lead: a few steps ahead toward the goal, or beside you facing you when you're there
		if lead then
			local want, face
			if target and Vector3.new(target.X - p.X, 0, target.Z - p.Z).Magnitude > 14 then
				local dir = Vector3.new(target.X - p.X, 0, target.Z - p.Z).Unit
				local side2 = Vector3.new(-dir.Z, 0, dir.X)
				want = p + dir * 10 + side2 * 3
				face = target
			else
				want = p + look * 10 + right * 3.5
				face = p
			end
			walkTo(lead, want, face, dt)
		end
		-- the other: at your side, a little behind
		if side then
			walkTo(side, p - look * 1.5 - right * 4.5, p + look * 10, dt)
		end

		-- what to say
		local s = Coach.step
		local id = s and s.id
		if id and id ~= lastStep then
			lastStep = id
			stepSaidAt = now
			local a, b = stepLines(id)
			if a then
				say(lead, a)
				if lead and id == "sell" then
					gesture(lead, "point")
				end
			end
			if b and side then
				task.delay(1.6, function()
					if out and lastStep == id then
						say(side, b)
					end
				end)
			end
		elseif id and now - stepSaidAt > 22 then
			-- stuck on a step a while: say it again
			stepSaidAt = now
			local a = stepLines(id)
			if a then
				say(lead, a)
			end
		end

		-- reacting to what you do
		local d = State.data
		local run = d and d.run
		local stats = d and d.stats
		if stats and not seenCut and (stats.cut or 0) > 0 then
			seenCut = true
			say(side, "LET'S GO! First cut!", 1.2)
			if side then
				gesture(side, "cheer")
			end
		end
		if run then
			local max = d.carryMax or Config.BASE_CARRY
			if not seenFull and run.carry >= max then
				seenFull = true
				say(side, "Bag's FULL. Look at that!", 1.2)
			end
			if lastCoins and run.coins > lastCoins and seenFull and not seenSale then
				seenSale = true
				say(side, "Look at that money!", 1.2)
				if side then
					gesture(side, "cheer")
				end
			end
			lastCoins = run.coins
		end
	end)
end)
return TutorGuide
