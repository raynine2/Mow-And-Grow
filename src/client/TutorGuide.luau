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
-- v2 (owner: "maak het veel mooier", after a look at how other games do it): bubbles that fit their line and pop
-- in and out, key words in gold, a soft talking blip in each guide's own pitch (Animal Crossing), an emote by the
-- head ("!" new step, "?" stuck, hearts and stars), hints that get shorter while you're stuck, a hop and sparkles
-- in their colour when they cheer, a thin outline in their colour, and a skip pill with both their faces.
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

	-- (v3, owner: "make him have walking animations, very goofy so kids like it") each guide walks in one of
	-- Roblox's own animation packs (made by Roblox, free for every game): RAYAN the Cartoony pack, BRRBRR the Bubbly
	-- one; on top of that a waddle (a side-to-side sway and a bounce in step), and when you stand still they goof
	-- around now and then (a dance, a laugh, a spin, a look around)
	local PACKS = {
		cartoony = { walk = 742640026, run = 742638842, idle = 742637544, look = 742638445 },
		bubbly = { walk = 910034870, run = 910025107, idle = 910004836 },
	}
	local SHARED = {
		wave = 507770239,
		cheer = 507770677,
		point = 507770453,
		dance1 = 507771019,
		dance2 = 507776043,
		dance3 = 507777268,
		laugh = 507770818,
	}
	local LOOPED = { walk = true, run = true, idle = true, dance1 = true, dance2 = true, dance3 = true }
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
		emote: BillboardGui,
		sayUntil: number,
		busyUntil: number,
		hopAt: number,
		voice: number, -- the pitch of their talking blips
		pack: string,
		animator: Animator,
		loaded: boolean,
		speed: number, -- how fast they moved last frame
		phase: number, -- the waddle's step
		spinAt: number,
		nextGoof: number,
		gestureToken: number,
		goofing: boolean, -- the gesture playing is a goof (a dance), stopped when they walk off
	}

	local folder = Instance.new("Folder")
	folder.Name = "TutorGuides"
	local guides: { Guide } = {}
	local lead: Guide? = nil
	local side: Guide? = nil

	-- (v2, owner: "maak het veel mooier") the bubble: sized to its line, pops in and out with a bounce, a soft
	-- shadow, the guide's name tag in their colour, key words in gold; next to the head an emote pops for a moment
	-- ("!" new step, "?" when you're stuck, a heart or a star when they cheer)
	local FONT = (UI.colors and UI.colors.font) or Enum.Font.FredokaOne
	local MAXW = if Device.touch then 230 else 290
	local TEXT = if Device.touch then 17 else 20
	local PAPER = Color3.fromRGB(255, 251, 240)
	local function corner(p: Instance, r: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = p
	end
	local function stroke(p: Instance, th: number, border: boolean?)
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = th
		if border then
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		end
		s.Parent = p
	end

	local function bubbleFor(def: any, head: BasePart): (BillboardGui, TextLabel)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Speech"
		bb.Adornee = head
		bb.Size = UDim2.fromOffset(MAXW + 30, 170)
		bb.StudsOffset = Vector3.new(0, 2.4, 0) -- (low enough to stay on screen from close by)
		bb.AlwaysOnTop = false -- (seen in Studio: an AlwaysOnTop bubble on these client-made avatars never drew)
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		bb.ResetOnSpawn = false
		bb.ZIndexBehavior = Enum.ZIndexBehavior.Global
		bb.Enabled = false
		local box = Instance.new("Frame")
		box.Name = "Box"
		box.AnchorPoint = Vector2.new(0.5, 1)
		box.Position = UDim2.new(0.5, 0, 1, -14)
		box.Size = UDim2.fromOffset(200, 56)
		box.BackgroundColor3 = PAPER
		box.ZIndex = 3
		box.Parent = bb
		corner(box, 16)
		stroke(box, 3)
		local pop = Instance.new("UIScale")
		pop.Name = "Pop"
		pop.Parent = box
		-- a soft shadow under it
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.Position = UDim2.fromOffset(0, 6)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.BackgroundColor3 = INK
		shadow.BackgroundTransparency = 0.7
		shadow.ZIndex = 1
		shadow.Parent = box
		corner(shadow, 16)
		-- the tail (behind the box, so only its point shows)
		local tail = Instance.new("Frame")
		tail.Name = "Tail"
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.new(0.5, 0, 1, 1)
		tail.Size = UDim2.fromOffset(16, 16)
		tail.Rotation = 45
		tail.BackgroundColor3 = PAPER
		tail.BorderSizePixel = 0
		tail.ZIndex = 2
		tail.Parent = box
		stroke(tail, 3)
		-- the name tag on the top edge, in the guide's colour
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.AnchorPoint = Vector2.new(0, 0.5)
		name.Position = UDim2.fromOffset(12, 0)
		name.Size = UDim2.fromOffset(0, 24)
		name.AutomaticSize = Enum.AutomaticSize.X
		name.BackgroundColor3 = def.color or Color3.fromRGB(255, 196, 60)
		name.Font = FONT
		name.Text = "  " .. tostring(def.label or def.key) .. "  "
		name.TextColor3 = INK
		name.TextSize = 16
		name.ZIndex = 5
		name.Parent = box
		corner(name, 9)
		stroke(name, 2, true)
		local sheen = Instance.new("UIGradient")
		sheen.Rotation = 90
		sheen.Color = ColorSequence.new(WHITE, Color3.fromRGB(205, 205, 205))
		sheen.Parent = name
		local t = Instance.new("TextLabel")
		t.Name = "Line"
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(15, 16)
		t.Size = UDim2.new(1, -30, 1, -24)
		t.Font = FONT
		t.RichText = true
		t.TextColor3 = INK
		t.TextSize = TEXT
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.Text = ""
		t.ZIndex = 4
		t.Parent = box
		bb.Parent = head
		return bb, t
	end

	local EMOTE = { ["!"] = "!", ["?"] = "?", heart = "♥", star = "★" }
	local function emoteFor(def: any, head: BasePart): BillboardGui
		local bb = Instance.new("BillboardGui")
		bb.Name = "Emote"
		bb.Adornee = head
		bb.Size = UDim2.fromOffset(60, 60)
		bb.StudsOffset = Vector3.new(1.6, -0.1, 0) -- (beside the head: higher up, the bubble covered it)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		bb.Enabled = false
		local dot = Instance.new("TextLabel")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(40, 40)
		dot.BackgroundColor3 = def.color or Color3.fromRGB(255, 196, 60)
		dot.Font = FONT
		dot.TextColor3 = INK
		dot.TextSize = 28
		dot.Text = "!"
		dot.Parent = bb
		corner(dot, 20)
		stroke(dot, 3, true)
		local s = Instance.new("UIScale")
		s.Parent = dot
		bb.Parent = head
		return bb
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
		-- a thin outline in their colour: they read as "the guides", not as other players
		local hl = Instance.new("Highlight")
		hl.Name = "GuideOutline"
		hl.FillTransparency = 1
		hl.OutlineColor = (def.color or WHITE):Lerp(WHITE, 0.25)
		hl.OutlineTransparency = 0.35
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = m
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
			emote = emoteFor(def, head),
			sayUntil = 0,
			busyUntil = 0,
			hopAt = -10,
			voice = if def.lead then 1.45 else 1.85,
			pack = def.pack or (if def.lead then "cartoony" else "bubbly"),
			animator = animator,
			loaded = false,
			speed = 0,
			phase = 0,
			spinAt = -10,
			nextGoof = os.clock() + 8,
			gestureToken = 0,
			goofing = false,
		}
		m.Parent = folder
		return g
	end

	-- (v3) the tracks load once the body is in the world: loaded while it wasn't, they never played (seen in
	-- Studio: length 0, weight 0, the guides stood stiff)
	local function loadTracks(g: Guide)
		if g.loaded then
			return
		end
		g.loaded = true
		local list = table.clone(SHARED)
		for k, id in PACKS[g.pack] or PACKS.cartoony do
			list[k] = id
		end
		for k, id in list do
			local a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://" .. id
			local ok, track = pcall(function()
				return g.animator:LoadAnimation(a)
			end)
			if ok and track then
				track.Looped = LOOPED[k] == true
				track.Priority = if k == "walk" or k == "run" or k == "idle" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
				g.tracks[k] = track
			end
		end
		g.playing = nil
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

	local function gesture(g: Guide, k: string, dur: number?, goof: boolean?)
		local t = g.tracks[k]
		if not t then
			return
		end
		g.goofing = goof == true
		g.gestureToken += 1
		local token = g.gestureToken
		t:Play(0.1)
		local len = dur or math.min(if t.Length > 0 then t.Length else 1.5, 2.2)
		g.busyUntil = os.clock() + len
		task.delay(len, function()
			if g.gestureToken == token and t.IsPlaying then
				t:Stop(0.25)
			end
		end)
	end

	-- stop a gesture early (they set off walking)
	local function stopGesture(g: Guide)
		g.gestureToken += 1
		for k, t in g.tracks do
			if not (k == "walk" or k == "run" or k == "idle") and t.IsPlaying then
				t:Stop(0.2)
			end
		end
		g.busyUntil = 0
		g.goofing = false
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
	local TextService = game:GetService("TextService")
	local talkToken: { [Guide]: number } = {}
	local function popOf(g: Guide): UIScale?
		local box = g.bubble:FindFirstChild("Box")
		return box and box:FindFirstChild("Pop") :: UIScale?
	end

	-- key words in gold: write them as {TAB} in a line
	local function richOf(line: string): (string, string)
		local plain = line:gsub("[{}]", "")
		local rich = line:gsub("{(.-)}", '<font color="#D98A00">%1</font>')
		return rich, plain
	end

	local function say(g: Guide?, line: string, hold: number?)
		if not g then
			return
		end
		talkToken[g] = (talkToken[g] or 0) + 1
		local token = talkToken[g]
		local rich, plain = richOf(line)
		-- the box fits the line (one short line = a small bubble)
		local ok, size = pcall(TextService.GetTextSize, TextService, plain, TEXT, FONT, Vector2.new(MAXW - 30, 400))
		local w = if ok then math.clamp(size.X + 32, 130, MAXW) else MAXW
		local h = if ok then size.Y + 28 else 70
		local box = g.bubble:FindFirstChild("Box") :: Frame?
		if box then
			box.Size = UDim2.fromOffset(w, h)
		end
		local pop = popOf(g)
		if pop then
			pop.Scale = if g.bubble.Enabled then 0.88 else 0.35
			TweenService:Create(pop, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		g.bubble.Enabled = true
		g.text.Text = rich
		g.text.MaxVisibleGraphemes = 0
		local life = (hold or 2.6) + #plain * 0.045
		g.sayUntil = os.clock() + life
		task.spawn(function()
			local n = utf8.len(plain) or #plain
			local i = 0
			while i < n do
				if talkToken[g] ~= token then
					return
				end
				i += 2
				g.text.MaxVisibleGraphemes = i
				-- (Animal Crossing's way) a soft blip every few letters in their own voice
				if i % 4 == 0 and plain:sub(i, i) ~= " " then
					pcall(Sound.playAt, "click", g.voice + (math.random() - 0.5) * 0.25, 0.32)
				end
				task.wait(1 / 48)
			end
			g.text.MaxVisibleGraphemes = -1
			task.wait(life)
			if talkToken[g] == token then
				local p = popOf(g)
				if p then
					TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
					task.wait(0.17)
				end
				if talkToken[g] == token then
					g.bubble.Enabled = false
				end
			end
		end)
	end

	local function quiet()
		for _, g in guides do
			talkToken[g] = (talkToken[g] or 0) + 1
			g.bubble.Enabled = false
			g.emote.Enabled = false
		end
	end

	-- a little icon pops next to the head for a moment
	local emoteToken: { [Guide]: number } = {}
	local function emote(g: Guide?, kind: string)
		if not g then
			return
		end
		emoteToken[g] = (emoteToken[g] or 0) + 1
		local token = emoteToken[g]
		local dot = g.emote:FindFirstChild("Dot") :: TextLabel?
		local s = dot and dot:FindFirstChildOfClass("UIScale")
		if not dot or not s then
			return
		end
		dot.Text = EMOTE[kind] or kind
		dot.Rotation = -18
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.BackgroundTransparency = 0
		dot.TextTransparency = 0
		local st0 = dot:FindFirstChildOfClass("UIStroke")
		if st0 then
			st0.Transparency = 0
		end
		s.Scale = 0.2
		g.emote.Enabled = true
		TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		task.delay(1.4, function()
			if emoteToken[g] ~= token then
				return
			end
			local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(dot, info, { Position = UDim2.fromScale(0.5, 0.15), BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			local st = dot:FindFirstChildOfClass("UIStroke")
			if st then
				TweenService:Create(st, info, { Transparency = 1 }):Play()
			end
			task.wait(0.36)
			if emoteToken[g] == token then
				g.emote.Enabled = false
			end
		end)
	end

	local function click(): string
		return if Device.touch then "Tap" else "Click"
	end

	-- what the lead says when a step starts (n = 0), and what the other one adds (nil = nothing); stuck on a step,
	-- the reminders get shorter each time (n = 1, then 2+), like a good hint system does
	local function stepLines(id: string, n: number?): (string?, string?)
		local k = math.min(n or 0, 2)
		local tab = if Device.touch then "{UPGRADES}" else "{TAB}"
		local L: { [string]: { string } } = {
			mow = { "Yo! Walk into that {glowing grass} to mow it.", "Just walk right through the {glowing grass}.", "Walk into the {grass}!" },
			punch = { "Yo! " .. click() .. " that {glowing clump} to cut it.", "Go on, " .. click():lower() .. " the {glowing clump}.", click() .. " it!" },
			collect = { "Nice! Walk over your {bundles} to grab them.", "Your {bundles} are on the ground. Grab 'em!", "Grab the {bundles}!" },
			fill = { "Keep cutting till your {bag} is full.", "More grass! Fill that {bag} up.", "Keep mowing!" },
			sell = { "Bag's full! Follow me to the {shredder}.", "This way! Step on {SELL}.", "Over here!" },
			upgrade = { (if Device.touch then "Tap " else "Press ") .. tab .. " and buy {Swing Speed}. Trust me.", "Open " .. tab .. ", grab {Swing Speed}.", tab .. ", {Swing Speed}!" },
		}
		local B: { [string]: string } = {
			mow = "Grass = {coins}. Easy money.",
			punch = "Grass = {coins}. Easy money.",
			sell = "Cha-ching time!",
			upgrade = "You'll cut way faster.",
		}
		local list = L[id]
		if not list then
			return nil, nil
		end
		return list[k + 1], if k == 0 then B[id] else nil
	end

	-------------------------------------------------------------------------------------------------------------
	-- skip
	-------------------------------------------------------------------------------------------------------------
	local skipped = false
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipGuide"
	skipBtn.AnchorPoint = Vector2.new(1, 1)
	skipBtn.Position = UDim2.new(1, -16, 1, -150)
	skipBtn.Size = UDim2.fromOffset(176, 42)
	skipBtn.BackgroundColor3 = Color3.fromRGB(40, 34, 52)
	skipBtn.BackgroundTransparency = 0.1
	skipBtn.Font = FONT
	skipBtn.Text = ""
	skipBtn.Visible = false
	skipBtn.AutoButtonColor = true
	do
		-- (v2) a pill with both guides' faces: "these two are your guide; skip them"
		corner(skipBtn, 21)
		local s = Instance.new("UIStroke")
		s.Color = WHITE
		s.Transparency = 0.55
		s.Thickness = 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = skipBtn
		for i, def in GUIDES do
			if i > 2 then
				break
			end
			local face = Instance.new("ImageLabel")
			face.Name = "Face" .. i
			face.AnchorPoint = Vector2.new(0, 0.5)
			face.Position = UDim2.new(0, 5 + (i - 1) * 22, 0.5, 0)
			face.Size = UDim2.fromOffset(32, 32)
			face.BackgroundColor3 = def.color or WHITE
			face.ZIndex = 3 - i
			face.Parent = skipBtn
			corner(face, 16)
			local fs = Instance.new("UIStroke")
			fs.Color = Color3.fromRGB(40, 34, 52)
			fs.Thickness = 2
			fs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			fs.Parent = face
			task.spawn(function()
				local ok, img = pcall(Players.GetUserThumbnailAsync, Players, def.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				if ok and img then
					face.Image = img
				end
			end)
		end
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(62, 0)
		label.Size = UDim2.new(1, -70, 1, 0)
		label.Font = FONT
		label.Text = if Device.touch then "SKIP GUIDE ✕" else "SKIP GUIDE [H]" -- (in first person the mouse is locked: H)
		label.TextColor3 = WHITE
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = skipBtn
	end
	skipBtn.Parent = UI.gui

	-------------------------------------------------------------------------------------------------------------
	-- walking
	-------------------------------------------------------------------------------------------------------------
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- (v3) the ground near your own height: from 25 studs up they landed on roofs and stall tops (seen in Studio)
	local refY: number? = nil
	local function ground(at: Vector3): number?
		local char = player.Character
		rayParams.FilterDescendantsInstances = { folder, char :: any }
		local from = (refY or at.Y) + 4
		local hit = workspace:Raycast(Vector3.new(at.X, from, at.Z), Vector3.new(0, -40, 0), rayParams)
		return hit and hit.Position.Y
	end

	-- (v2) a puff of smoke with sparkles in the guide's colour (arriving, leaving), or just the sparkles (cheering)
	local function burst(at: Vector3, color: Color3, smoke: boolean)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(3, 0.2, 3)
		p.CFrame = CFrame.new(at)
		p.Parent = workspace
		if smoke then
			local e = Instance.new("ParticleEmitter")
			e.Enabled = false
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Lifetime = NumberRange.new(0.45, 0.75)
			e.Speed = NumberRange.new(5, 9)
			e.SpreadAngle = Vector2.new(180, 15)
			e.Acceleration = Vector3.new(0, 4, 0)
			e.Drag = 5
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 3.2) })
			e.Transparency = NumberSequence.new(0.2, 1)
			e.Color = ColorSequence.new(WHITE, color:Lerp(WHITE, 0.6))
			e.Parent = p
			e:Emit(14)
		end
		local s = Instance.new("ParticleEmitter")
		s.Enabled = false
		s.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		s.LightEmission = 0.8
		s.Lifetime = NumberRange.new(0.5, 0.9)
		s.Speed = NumberRange.new(7, 12)
		s.SpreadAngle = Vector2.new(70, 70)
		s.EmissionDirection = Enum.NormalId.Top
		s.Acceleration = Vector3.new(0, -14, 0)
		s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		s.Color = ColorSequence.new(color:Lerp(WHITE, 0.3))
		s.Parent = p
		s:Emit(if smoke then 10 else 16)
		Debris:AddItem(p, 1.2)
	end
	local function poof(at: Vector3, color: Color3?)
		burst(at + Vector3.new(0, 1, 0), color or WHITE, true)
	end

	-- (v2) a little hop (arriving, a new step, cheering): the body goes up and down once
	local HOP = 0.42
	local function hopY(g: Guide): number
		local t = os.clock() - g.hopAt
		return if t >= 0 and t < HOP then math.sin(math.pi * t / HOP) * 1.3 else 0
	end

	local function place(g: Guide, at: Vector3, yaw: number)
		local y = ground(at) or at.Y
		local up = g.hum.HipHeight + g.root.Size.Y / 2
		g.pos = Vector3.new(at.X, y, at.Z)
		g.yaw = yaw
		g.model:PivotTo(CFrame.new(g.pos + Vector3.new(0, up + hopY(g), 0)) * CFrame.Angles(0, yaw, 0))
	end

	local function yawOf(v: Vector3): number
		return math.atan2(-v.X, -v.Z)
	end

	-- (v3) the waddle on top of the walk: a side-to-side sway and a bounce in step (more the faster they go), a lean
	-- when they run, and a spin when they goof around
	local function goofyPose(g: Guide, dt: number): CFrame
		local k = math.clamp(g.speed / 12, 0, 1)
		g.phase += dt * (3 + g.speed * 0.5)
		local roll = math.sin(g.phase) * 0.14 * k
		local bob = math.abs(math.sin(g.phase)) * 0.45 * k
		local lean = -0.1 * math.clamp((g.speed - 10) / 10, 0, 1)
		local t = (os.clock() - g.spinAt) / 0.6
		local spin = if t >= 0 and t < 1 then (1 - math.cos(math.pi * t)) * math.pi else 0
		return CFrame.new(0, bob, 0) * CFrame.Angles(lean, spin, roll)
	end

	-- (10 Nov) the same bodies, bubbles, emotes and moves for the guides standing in the hub (client/HubGuides)
	TutorGuide.kit = {
		build = build,
		loadTracks = loadTracks,
		play = play,
		gesture = gesture,
		stopGesture = stopGesture,
		say = say,
		emote = emote,
		burst = burst,
		poof = poof,
		hopY = hopY,
		goofyPose = goofyPose,
	}

	local function walkTo(g: Guide, want: Vector3, face: Vector3?, dt: number)
		local flatPos = Vector3.new(g.pos.X, 0, g.pos.Z)
		local flatWant = Vector3.new(want.X, 0, want.Z)
		local d = flatWant - flatPos
		local dist = d.Magnitude
		if dist > 60 then
			-- left far behind (a teleport, the mower): pop over to you
			poof(g.pos, g.def.color)
			place(g, want, g.yaw)
			poof(g.pos, g.def.color)
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
		g.speed += (speed - g.speed) * math.min(1, dt * 8)
		local up = g.hum.HipHeight + g.root.Size.Y / 2
		g.model:PivotTo(CFrame.new(g.pos + Vector3.new(0, up + hopY(g), 0)) * CFrame.Angles(0, yaw, 0) * goofyPose(g, dt))
		-- the bubble bobs a touch while it's up (alive, not pasted on)
		if g.bubble.Enabled then
			g.bubble.StudsOffset = Vector3.new(0, 2.4 + math.sin(os.clock() * 2.4) * 0.07, 0)
		end
		if g.goofing and g.speed > 4 and os.clock() < g.busyUntil then
			stopGesture(g) -- off they go: no dancing on the move
		end
		if os.clock() > g.busyUntil then
			if g.speed > 2 then
				local run = g.speed > 16
				play(g, if run then "run" else "walk")
				local t = g.tracks[if run then "run" else "walk"]
				if t then
					t:AdjustSpeed(if run then math.clamp(g.speed / 20, 0.8, 1.4) else math.clamp(g.speed / 9, 0.7, 1.7))
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
	local nagged = 0 -- reminders said for this step
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

	-- (v2) only a real cutscene (the camera away from the player for half a second) sends them off, not a blip
	local camAwaySince: number? = nil
	local function cutsceneOn(): boolean
		local cam = workspace.CurrentCamera
		if cam ~= nil and cam.CameraType ~= Enum.CameraType.Custom then
			camAwaySince = camAwaySince or os.clock()
			return os.clock() - (camAwaySince :: number) > 0.5
		end
		camAwaySince = nil
		return false
	end

	local function bringOut(root: BasePart)
		out = true
		folder.Parent = workspace
		refY = root.Position.Y - 1
		for _, g in guides do
			loadTracks(g)
		end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
		local right = Vector3.new(-look.Z, 0, look.X)
		-- (v2) they pop in with a hop, the lead waves hello
		local now = os.clock()
		if lead then
			lead.hopAt = now
			place(lead, root.Position + look * 10 + right * 3, yawOf(-look))
			poof(lead.pos, lead.def.color)
			gesture(lead, "wave")
		end
		if side then
			side.hopAt = now + 0.15
			place(side, root.Position + look * 3 - right * 4, yawOf(-look))
			poof(side.pos, side.def.color)
		end
	end

	-- (v3) goofing around while you stand still: now and then a dance, a laugh, a spin or a look around
	local GOOFS = { "dance1", "dance2", "dance3", "laugh", "spin", "spin", "look" }
	local LAUGHS = { "Hehehe!", "Hahaha!", "Hehe." }
	local function goof(g: Guide, now: number)
		if now < g.nextGoof or g.speed > 1.5 or g.bubble.Enabled or now < g.busyUntil then
			return
		end
		g.nextGoof = now + 7 + math.random() * 6
		local k = GOOFS[math.random(1, #GOOFS)]
		if k == "look" and not g.tracks.look then
			k = "spin"
		end
		if k == "spin" then
			g.spinAt = now
			g.hopAt = now
			pcall(Sound.playAt, "whoosh", 1.3 + math.random() * 0.2, 0.5)
		elseif k == "laugh" then
			gesture(g, "laugh", 1.6, true)
			if math.random() < 0.6 then
				say(g, LAUGHS[math.random(1, #LAUGHS)], 0.3)
			end
		elseif k == "look" then
			gesture(g, "look", 2.4, true)
			emote(g, "?")
		else
			gesture(g, k, 2.8, true)
			emote(g, "♪")
		end
	end

	-- (v2) a cheer: the dance, a hop, sparkles in their colour and a heart or a star by the head
	local function cheer(g: Guide?, icon: string)
		if not g then
			return
		end
		gesture(g, "cheer")
		g.hopAt = os.clock()
		burst(g.pos + Vector3.new(0, 3.5, 0), g.def.color or WHITE, false)
		emote(g, icon)
	end

	local function putAway()
		if not out then
			return
		end
		out = false
		quiet()
		for _, g in guides do
			poof(g.pos, g.def.color)
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
		say(lead, "You're a {natural}! We'll see you around.", 1.5)
		if lead then
			gesture(lead, "wave")
			lead.hopAt = os.clock()
			emote(lead, "heart")
		end
		task.delay(1.2, function()
			say(side, "Bye bye!", 0.8)
			if side then
				gesture(side, "wave")
				emote(side, "heart")
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
		refY = p.Y - 1
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
		for _, g in guides do
			goof(g, now)
		end

		-- what to say
		local s = Coach.step
		local id = s and s.id
		if id and id ~= lastStep then
			lastStep = id
			stepSaidAt = now
			nagged = 0
			local a, b = stepLines(id, 0)
			if a then
				say(lead, a)
				emote(lead, "!")
				if lead then
					lead.hopAt = now
					if target and (target - p).Magnitude > 14 then
						gesture(lead, "point") -- "over there"
					end
				end
			end
			if b and side then
				task.delay(1.6, function()
					if out and lastStep == id then
						say(side, b)
					end
				end)
			end
		elseif id and now - stepSaidAt > (if nagged == 0 then 18 else 14) then
			-- stuck on a step a while: a "?" and the hint again, shorter each time
			stepSaidAt = now
			nagged += 1
			local a = stepLines(id, nagged)
			if a then
				say(lead, a)
				emote(lead, "?")
			end
		end

		-- reacting to what you do
		local d = State.data
		local run = d and d.run
		local stats = d and d.stats
		if stats and not seenCut and (stats.cut or 0) > 0 then
			seenCut = true
			say(side, "LET'S GO! {First cut!}", 1.2)
			cheer(side, "star")
		end
		if run then
			local max = d.carryMax or Config.BASE_CARRY
			if not seenFull and run.carry >= max then
				seenFull = true
				say(side, "Bag's {FULL}. Look at that!", 1.2)
				emote(side, "!")
			end
			if lastCoins and run.coins > lastCoins and seenFull and not seenSale then
				seenSale = true
				say(side, "Look at that {money}!", 1.2)
				cheer(side, "heart")
				task.delay(0.5, function()
					if out then
						cheer(lead, "star")
					end
				end)
			end
			lastCoins = run.coins
		end
	end)
end)
return TutorGuide
