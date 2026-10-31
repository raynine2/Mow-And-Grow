-- Boss fights on the client (the owner's boss brief, 26 Oct): listens to server/Boss's events and plays them with
-- client/BossView (the model), BossVfx (effects) and BossFx (the HP bar, title cards, letterbox):
--   * the boss waking (a light beam over its arena's summon pad and a title card)
--   * the intro cutscene: 7-8 s the first time on a server (rises out of the ground, low hero shots, a name card
--     with its funny title, one funny line, the roar), 2.5 s after that; a SKIP button: everyone in the arena
--     has to press it
--   * moves: ground warnings, anticipation / strike / slump poses, leaps, impacts; the weak spot when it's open
--   * the phase-2 cutscene (~5 s): it staggers and kneels, the rage parts sprout piece by piece, colours shift,
--     a roar with a shockwave; the music speeds up
--   * the death cutscene (~3 s): it reels and wilts away, BOSS DEFEATED!, confetti
--   * being knocked out (a teammate can pick you up), juice boxes; the HP bars are over everyone's heads now
--     (client/BossPlayers, round 2), minions are client/BossAdds
-- Letterbox bars and a hidden HUD during the cutscenes. Cosmetic only: everything is wrapped so the camera and
-- the controls always come back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local BossMoves = require(Shared:WaitForChild("BossMoves"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local BossFx = require(script.Parent.BossFx)
local BossView = require(script.Parent.BossView)
local BossVfx = require(script.Parent.BossVfx)
local BossAdds = require(script.Parent.BossAdds) -- the minions
local Omen = require(script.Parent.BossOmen) -- (30 Oct) the scary wake-up, the roar's impact frames
require(script.Parent.BossPlayers) -- HP bars over every fighter's head, dizzy stars (round 2)

local BossCine = {}

local player = Players.LocalPlayer
local mirror = ReplicatedStorage:WaitForChild("MowALawnBoss", 30)
local C = UI.colors

local function now(): number
	return workspace:GetServerTimeNow()
end

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function try(label: string, fn: (...any) -> (), ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[BossCine] " .. label .. ": " .. tostring(err))
	end
end

local function zoneColor(z: number): Color3
	local ok, c = pcall(Color3.fromHex, BossMoves.get(z).ring or "FFFFFF")
	return if ok then c else Color3.new(1, 1, 1)
end

-------------------------------------------------------------------------------------------------------------
-- screen: the skip button, your HP bar, the knocked-out overlay, toasts
-------------------------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BossCine"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")
local scale = Instance.new("UIScale")
scale.Parent = gui
local function rescale()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.5)
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

-- SKIP (everyone in the arena must press it): the button counts the votes, "SKIP 1/3" (round 2)
local skip = UI.button(gui, "SKIP", C.purple or Color3.fromRGB(150, 90, 255), UDim2.fromOffset(170, 52), function()
	State.fire("Boss", "skip")
end, { pos = UDim2.new(1, -24, 1, -110), anchor = Vector2.new(1, 1), name = "Skip" })
skip.Visible = false
local skipNote = UI.text(skip, "", UDim2.new(1, 0, 0, 22), { pos = UDim2.new(0, 0, 1, 4), stroke = 2 })
local function setSkipLabel(text: string)
	local l = skip:FindFirstChild("Label", true) :: TextLabel?
	if l then
		l.Text = text
	end
end
UserInputService.InputBegan:Connect(function(input, processed)
	if skip.Visible and not processed and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
		State.fire("Boss", "skip")
	end
end)

-- your HP in a fight (player attributes from server/BossFighters)
local hpRoot = Instance.new("Frame")
hpRoot.Name = "MyBossHp"
hpRoot.AnchorPoint = Vector2.new(0.5, 1)
hpRoot.Position = UDim2.new(0.5, 0, 1, -128)
hpRoot.Size = UDim2.fromOffset(300, 34)
hpRoot.BackgroundTransparency = 1
hpRoot.Visible = false
hpRoot.Parent = gui
local hpTrack = UI.frame({ size = UDim2.fromScale(1, 1), color = Color3.fromRGB(28, 22, 36), parent = hpRoot, radius = 10, outline = 3 })
local hpFill = UI.frame({ size = UDim2.new(1, -6, 1, -6), pos = UDim2.fromOffset(3, 3), color = Color3.fromRGB(90, 220, 90), parent = hpTrack, radius = 8, outline = 0 })
local hpLabel = UI.text(hpTrack, "", UDim2.new(1, -12, 1, -6), { pos = UDim2.fromOffset(6, 3), stroke = 2.5 })
hpLabel.ZIndex = 3

local downRoot = Instance.new("Frame")
downRoot.Name = "Downed"
downRoot.Size = UDim2.fromScale(1, 1)
downRoot.BackgroundColor3 = Color3.fromRGB(60, 0, 10)
downRoot.BackgroundTransparency = 1
downRoot.Visible = false
downRoot.Parent = gui
local downTitle = UI.text(downRoot, "KNOCKED OUT!", UDim2.fromOffset(700, 80), { pos = UDim2.fromScale(0.5, 0.36), anchor = Vector2.new(0.5, 0.5), stroke = 5 })
local downSub = UI.text(downRoot, "", UDim2.fromOffset(700, 40), { pos = UDim2.fromScale(0.5, 0.45), anchor = Vector2.new(0.5, 0.5), stroke = 3 })
local reviveBar = UI.frame({ size = UDim2.fromOffset(320, 18), pos = UDim2.fromScale(0.5, 0.51), anchor = Vector2.new(0.5, 0.5), color = Color3.fromRGB(28, 22, 36), parent = downRoot, radius = 9, outline = 3 })
local reviveFill = UI.frame({ size = UDim2.fromScale(0, 1), color = Color3.fromRGB(120, 255, 140), parent = reviveBar, radius = 9, outline = 0 })

local function updateMyHp()
	local hp = player:GetAttribute("BossHP")
	local max = player:GetAttribute("BossMaxHP")
	if type(hp) ~= "number" or type(max) ~= "number" then
		hpRoot.Visible = false
		downRoot.Visible = false
		return
	end
	hpRoot.Visible = false -- round 2: the bar is over your head (client/BossPlayers)
	local k = math.clamp(hp / math.max(1, max), 0, 1)
	tween(hpFill, 0.15, { Size = UDim2.new(k, -6 * k, 1, -6) })
	hpFill.BackgroundColor3 = if k > 0.5 then Color3.fromRGB(90, 220, 90) elseif k > 0.25 then Color3.fromRGB(255, 190, 60) else Color3.fromRGB(240, 60, 60)
	hpLabel.Text = ("HP  %d / %d"):format(hp, max)
	local downed = player:GetAttribute("Downed")
	if type(downed) == "number" then
		downRoot.Visible = true
		downRoot.BackgroundTransparency = 0.72
		downSub.Text = ("A teammate can pick you up... getting up at the gate in %d"):format(math.max(0, math.ceil(downed)))
		reviveFill.Size = UDim2.fromScale(math.clamp(player:GetAttribute("ReviveProgress") or 0, 0, 1), 1)
	else
		downRoot.Visible = false
	end
end
for _, a in { "BossHP", "BossMaxHP", "Downed", "ReviveProgress" } do
	player:GetAttributeChangedSignal(a):Connect(updateMyHp)
end

local function toast(text: string, color: Color3?)
	local label = UI.text(gui, text, UDim2.fromOffset(760, 40), { pos = UDim2.new(0.5, 0, 0, 150), anchor = Vector2.new(0.5, 0), stroke = 3 })
	label.TextColor3 = color or Color3.new(1, 1, 1)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = label
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.4, function()
		tween(label, 0.4, { TextTransparency = 1 })
		task.delay(0.45, label.Destroy, label)
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the camera: shots relative to the boss (it moves while rising), eased, with the camera and controls always
-- given back
-------------------------------------------------------------------------------------------------------------
type Shot = { t0: number, t1: number, from: { Vector3 }, to: { Vector3 }, shake: number? } -- { offset, look } in boss space (studs / H)
local cine = { token = 0, active = false, conn = nil :: RBXScriptConnection?, savedHud = true }

local function controls(on: boolean)
	-- never wait here (this place has no PlayerModule: a WaitForChild hung endCine and left the letterbox and
	-- the hidden HUD on after every cutscene)
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return
	end
	pcall(function()
		local pm = require(module :: any)
		local c = pm:GetControls()
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end)
end

local function ease(k: number): number
	return if k < 0.5 then 4 * k * k * k else 1 - (-2 * k + 2) ^ 3 / 2
end

local function endCine(token: number?)
	if token and token ~= cine.token then
		return
	end
	if cine.conn then
		cine.conn:Disconnect()
		cine.conn = nil
	end
	if not cine.active then
		return
	end
	cine.active = false
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
	controls(true)
	BossFx.letterbox(false)
	BossFx.cinematic = false
	UI.gui.Enabled = cine.savedHud
	skip.Visible = false
	BossFx.showBar(true)
	updateMyHp()
end

-- The camera stays inside the arena's wall and in front of anything between it and the boss (a boss turned
-- towards the gate put the phase-2 shots outside, behind the gate and the trees).
local camRay = RaycastParams.new()
camRay.FilterType = Enum.RaycastFilterType.Exclude
local function keepInside(pos: Vector3, look: Vector3, centre: Vector3?): Vector3
	if centre then
		local d = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)
		local maxD = Config.BOSS_ARENA_RADIUS - 6
		if d.Magnitude > maxD then
			d = d.Unit * maxD
			pos = Vector3.new(centre.X + d.X, pos.Y, centre.Z + d.Z)
		end
	end
	local ignore: { Instance } = {}
	local v = BossView.get()
	if v and v.model then
		table.insert(ignore, v.model)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, name in { "BossVfx", "BossAdds", "BossPlayers", "BossSpeech" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	camRay.FilterDescendantsInstances = ignore
	local dir = pos - look
	local hit = workspace:Raycast(look, dir, camRay)
	if hit and hit.Instance.Transparency < 0.9 then
		pos = hit.Position - dir.Unit * 1.5
	end
	return pos
end

-- Film a cutscene of `len` s with `shots` (offsets in boss space: x right, y up, z forward, x H), only for players
-- near the arena. Returns the token (nil when this player isn't watching).
local function film(len: number, shots: { Shot }, arenaCentre: Vector3?): number?
	local root = myRoot()
	if not root or not arenaCentre or (root.Position - arenaCentre).Magnitude > Config.BOSS_ARENA_RADIUS + 60 then
		return nil
	end
	endCine()
	cine.token += 1
	local token = cine.token
	cine.active = true
	cine.savedHud = if UI.gui.Enabled == nil then true else UI.gui.Enabled
	UI.gui.Enabled = false
	BossFx.cinematic = true
	BossFx.showBar(false)
	hpRoot.Visible = false
	BossFx.letterbox(true)
	controls(false)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local function at(spec: { Vector3 }, base: CFrame, H: number): (Vector3, Vector3)
		local o, l = spec[1], spec[2]
		local p = base * Vector3.new(o.X * H, o.Y * H, -o.Z * H)
		local look = base * Vector3.new(l.X * H, l.Y * H, -l.Z * H)
		return p, look
	end
	cine.conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > len + 0.2 then
			endCine(token)
			return
		end
		local base = BossView.cframe()
		local H = BossView.height()
		if not base or H <= 0 then
			return
		end
		-- the boss's facing without its lean / jitter
		local flatBase = CFrame.new(base.Position) * CFrame.Angles(0, select(2, base:ToEulerAnglesYXZ()), 0)
		local shot = shots[#shots]
		for _, s in shots do
			if t >= s.t0 and t < s.t1 then
				shot = s
				break
			end
		end
		local k = ease(math.clamp((t - shot.t0) / math.max(0.01, shot.t1 - shot.t0), 0, 1))
		local p0, l0 = at(shot.from, flatBase, H)
		local p1, l1 = at(shot.to, flatBase, H)
		local pos = p0:Lerp(p1, k)
		local look = l0:Lerp(l1, k)
		pos = keepInside(pos, look, arenaCentre)
		local sh = shot.shake or 0
		if sh > 0 then
			pos += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * sh
		end
		cam.CFrame = CFrame.lookAt(pos, look)
	end)
	-- a safety net: the camera always comes back
	task.delay(len + 1.5, endCine, token)
	return token
end

-- a speech bubble over the boss, typed out
local function say(text: string?, len: number)
	if not text or text == "" then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "BossSpeech"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(420, 110)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = anchor
	bb.Parent = anchor
	local bubble = UI.frame({ size = UDim2.fromScale(1, 0.82), color = Color3.new(1, 1, 1), parent = bb, radius = 22, outline = 4 })
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 1, 2)
	tail.Size = UDim2.fromOffset(26, 26)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.new(1, 1, 1)
	tail.BorderSizePixel = 0
	tail.Parent = bubble
	local label = UI.text(bubble, "", UDim2.new(1, -28, 1, -16), { pos = UDim2.fromOffset(14, 8), stroke = 0 })
	label.TextColor3 = Color3.fromRGB(30, 22, 36)
	label.ZIndex = 3
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = bubble
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local base = BossView.cframe()
		if not base or t > len then
			conn:Disconnect()
			anchor:Destroy()
			return
		end
		anchor.CFrame = CFrame.new(base.Position + Vector3.new(0, BossView.height() * 1.08, 0))
		local n = math.floor(t * 40)
		label.Text = text:sub(1, n)
		if t > len - 0.3 then
			sc.Scale = math.max(0, (len - t) / 0.3)
		end
	end)
end

-------------------------------------------------------------------------------------------------------------
-- the music
-------------------------------------------------------------------------------------------------------------
local function music(on: boolean, fast: boolean?)
	if on then
		local cur = SoundService:FindFirstChild("Music") :: Sound?
		if not (cur and cur.SoundId == Config.SOUNDS.bossMusic.id) then
			Sound.music("bossMusic")
		end
		task.delay(0.1, function()
			for _, s in SoundService:GetChildren() do
				if s:IsA("Sound") and s.Name == "Music" and s.SoundId == Config.SOUNDS.bossMusic.id then
					tween(s, 1.2, { PlaybackSpeed = if fast then 1.12 else 1 })
				end
			end
		end)
	else
		Sound.music("musicRun")
	end
end

-------------------------------------------------------------------------------------------------------------
-- the fight's events
-------------------------------------------------------------------------------------------------------------
local fight = { z = 0, arena = nil :: Vector3?, beam = nil :: Instance?, floor = nil :: Color3? }

local function floorColor(z: number): Color3?
	local world = workspace:FindFirstChild("World")
	local arenas = world and world:FindFirstChild("Arenas")
	local a = arenas and arenas:FindFirstChild("Arena" .. z)
	local f = a and a:FindFirstChild("Floor") :: BasePart?
	return f and f.Color
end

local function clearBeam()
	if fight.beam then
		fight.beam:Destroy()
		fight.beam = nil
	end
end

-- a light beam over the summon pad, seen from across the area
local function beam(pos: Vector3, color: Color3)
	clearBeam()
	local p = Instance.new("Part")
	p.Name = "SummonBeam"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.55
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(160, 5, 5)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace
	fight.beam = p
	task.spawn(function()
		while p.Parent do
			local t = os.clock()
			p.Transparency = 0.5 + 0.15 * math.sin(t * 3)
			task.wait(0.05)
		end
	end)
end

local function startView(rig: string, cf: CFrame, sc: number, z: number, arena: Vector3?)
	fight.z = z
	fight.arena = arena
	fight.floor = floorColor(z)
	BossView.show(rig, cf, sc, BossMoves.get(z)) -- (29 Oct) with the area's skin (the Frost Thornback)
	local home = mirror and mirror:GetAttribute("Home")
	if typeof(home) == "CFrame" then
		BossView.setHome(home)
	end
	BossVfx.start(z, arena)
end

local H: { [string]: (any) -> () } = {}

H.bossReady = function(d)
	-- (30 Oct, owner: "make better fx with boss spawning to make it feel more scary") client/BossOmen: the eye, the
	-- bleeding screen, the summoning circle and dark beam on the pad, the thorned banner (it plays the roar too); the old
	-- beam and card when it can't
	local ok, shown = pcall(Omen.awake, d)
	if ok and shown then
		clearBeam()
		return
	end
	beam(d.pos, zoneColor(d.z))
	local card = BossFx.titleCard("BOSS AWAKE", d.name:upper(), "Stand on the glowing pad in its arena to fight!", 0.3, zoneColor(d.z))
	BossFx.fadeCard(card, 3)
	Sound.play("roar", 0.05, 0.6)
end

H.bossIntro = function(d)
	clearBeam()
	Omen.clear()
	BossFx.resetHp()
	startView(d.rig, d.cf, d.scale, d.z, d.arena)
	BossFx.setPhase(1)
	local len = d.len
	local left = len - (now() - d.at)
	BossView.act("intro", { len = left, kind = BossMoves.get(d.z).intro })
	BossView.critters("intro", left)
	music(true, false)
	local shots: { Shot }
	if d.first and left > 4 then
		shots = {
			{ t0 = 0, t1 = 2.6, from = { Vector3.new(0.15, 0.25, 2.2), Vector3.new(0, 0.2, 0) }, to = { Vector3.new(0.1, 0.18, 1.7), Vector3.new(0, 0.35, 0) }, shake = 0.25 },
			{ t0 = 2.6, t1 = 4.6, from = { Vector3.new(0.75, 0.05, 1.1), Vector3.new(0, 0.7, 0) }, to = { Vector3.new(0.55, 0.08, 1.0), Vector3.new(0, 0.75, 0) } },
			{ t0 = 4.6, t1 = left - 1.1, from = { Vector3.new(-0.2, 0.62, 0.95), Vector3.new(0, 0.72, 0) }, to = { Vector3.new(-0.12, 0.66, 0.78), Vector3.new(0, 0.74, 0) }, shake = 0.35 },
			{ t0 = left - 1.1, t1 = left, from = { Vector3.new(-0.12, 0.66, 0.78), Vector3.new(0, 0.74, 0) }, to = { Vector3.new(0, 0.55, 1.9), Vector3.new(0, 0.45, 0) } },
		}
	else
		shots = {
			{ t0 = 0, t1 = left * 0.7, from = { Vector3.new(0.3, 0.35, 1.5), Vector3.new(0, 0.55, 0) }, to = { Vector3.new(0.15, 0.5, 1.1), Vector3.new(0, 0.7, 0) }, shake = 0.3 },
			{ t0 = left * 0.7, t1 = left, from = { Vector3.new(0.15, 0.5, 1.1), Vector3.new(0, 0.7, 0) }, to = { Vector3.new(0, 0.55, 1.9), Vector3.new(0, 0.45, 0) } },
		}
	end
	local token = film(left, shots, d.arena)
	if token then
		skip.Visible = true
		skipNote.Text = ""
		setSkipLabel("SKIP")
	end
	-- dust as it climbs out, the name card, the line, the roar
	task.delay(0.2, function()
		BossVfx.impact(d.z, { type = "circle", pos = d.cf.Position, r = 16 }, "intro", fight.floor)
	end)
	local cardAt = if d.first then 3.2 else 0.3
	task.delay(math.max(0, cardAt - (len - left)), function()
		if cine.token == token or not token then
			local card = BossFx.titleCard(d.title or "BOSS", d.name:upper(), "", 0.24, zoneColor(d.z))
			BossFx.shakeCard(card, 6, 0.35)
			BossFx.fadeCard(card, if d.first then 3 else 1.6)
		end
	end)
	if d.first then
		task.delay(math.max(0, 4.8 - (len - left)), say, d.line, 2.6)
		task.delay(math.max(0, 5.4 - (len - left)), function()
			Sound.play("roar", 0.05, 1)
			Omen.roar(d.z) -- (the impact frames)
			if BossVfx.shake then
				BossVfx.shake(10, 0.8)
			end
		end)
	else
		task.delay(0.6, function()
			Sound.play("roar", 0.05, 0.9)
			Omen.roar(d.z, true)
		end)
	end
end

H.bossSkipVotes = function(d)
	setSkipLabel(("SKIP %d/%d"):format(d.yes, d.need))
end

H.bossSkip = function(_d)
	endCine()
	local v = BossView.get()
	if v then
		v.action = nil
		v.lift.x, v.lift.target = 0, 0
		v.size.x, v.size.target = 1, 1
	end
end

-- A move: its warnings, impacts, projectiles, floor patches and moving things, and what the boss's body does
-- (`pose`: strike, volley, stomp, leap, spin, burrow, erupt, dash, aim; "none" for minions' attacks).
H.bossMove = function(d)
	local z = fight.z
	if not BossView.get() then
		-- joined mid-fight
		local cf = mirror and mirror:GetAttribute("Cf") or d.cf
		startView(mirror:GetAttribute("Rig"), cf, mirror:GetAttribute("Scale") or 5, mirror:GetAttribute("Z") or 1, nil)
		z = fight.z
	end
	local pose = d.pose or "strike"
	if pose ~= "none" then
		BossView.setTarget(d.cf)
	end
	BossVfx.warn(d)
	BossVfx.playImpacts(z, d, fight.floor)
	if d.ammo then
		BossVfx.projectiles(d)
	end
	BossVfx.patches(d) -- hazards, sand traps and pools stay on the floor
	if d.movers then
		BossVfx.movers(d)
	end
	if pose == "none" then
		return
	end
	local elapsed = now() - d.at
	local first = d.shapes[1]
	local last = d.shapes[#d.shapes]
	local land = 1
	if first then
		land = (if pose == "volley" then last.land else first.land) - elapsed
	elseif d.movers and d.movers[1] then
		local t0 = math.huge
		for _, m in d.movers do
			t0 = math.min(t0, m.t0)
		end
		land = t0 - now()
	end
	local open = if d.punish then BossMoves.curve(z).punish else 0
	local args = { land = land, open = open, twist = d.twist or 0, air = d.air or 0.9 }
	if pose == "spin" and d.movers and d.movers[1] then
		args.len = BossMoves.moverDur(d.movers[1])
	elseif pose == "burrow" then
		args.len = 30
	end
	BossView.act(pose, args)
	if pose == "leap" and d.from and d.to and first then
		BossView.leap(d.from, d.to, d.at + first.land - (d.air or 0.9), d.air or 0.9)
	elseif pose == "dash" and d.from and d.to and first then
		BossView.leap(d.from, d.to, d.at + first.land - 0.3, 0.3, 0.8)
	elseif pose == "erupt" and d.to then
		BossView.teleport(d.to)
	end
end

H.bossAim = function(d)
	BossVfx.aim(d)
	BossView.act("aim", { land = d.len - (now() - d.at), open = 0 })
end

H.bossTrail = function(d)
	BossVfx.trail(d)
end

H.bossOpen = function(d)
	BossVfx.open(fight.z, d.len - (now() - d.at))
end

H.bossRage = function(d)
	local left = d.len - (now() - d.at)
	BossView.act("rage", {})
	BossView.critters("rage", left)
	BossFx.setPhase(2)
	music(true, true)
	local token = film(left, {
		{ t0 = 0, t1 = 1, from = { Vector3.new(0.5, 0.3, 1.5), Vector3.new(0, 0.6, 0) }, to = { Vector3.new(0.45, 0.32, 1.35), Vector3.new(0, 0.55, 0) } },
		{ t0 = 1, t1 = 2.2, from = { Vector3.new(-0.55, 0.25, 1.15), Vector3.new(0, 0.45, 0) }, to = { Vector3.new(-0.45, 0.3, 1.0), Vector3.new(0, 0.5, 0) }, shake = 0.2 },
		{ t0 = 2.2, t1 = 3.3, from = { Vector3.new(0.2, 0.15, 1.3), Vector3.new(0, 0.6, 0) }, to = { Vector3.new(0.1, 0.1, 1.7), Vector3.new(0, 0.7, 0) }, shake = 0.3 },
		{ t0 = 3.3, t1 = 4.3, from = { Vector3.new(0, 0.55, 0.95), Vector3.new(0, 0.75, 0) }, to = { Vector3.new(0, 0.5, 1.15), Vector3.new(0, 0.75, 0) }, shake = 0.9 },
		{ t0 = 4.3, t1 = left, from = { Vector3.new(0, 0.5, 1.15), Vector3.new(0, 0.75, 0) }, to = { Vector3.new(0, 0.55, 2), Vector3.new(0, 0.45, 0) } },
	}, fight.arena)
	task.delay(math.max(0, 2.2 - (d.len - left)), function()
		BossVfx.setRage(true)
		BossVfx.rageBurst()
		Sound.play("burst", 0.05, 0.8)
	end)
	-- (31 Oct, owner's vfx_sfx_all.zip) a dark riser whose boom (1.17 s in) lands with the roar
	if d.len - left < 2.13 then
		task.delay(2.13 - (d.len - left), function()
			Sound.play("rageRise", 0.02)
		end)
	end
	task.delay(math.max(0, 3.3 - (d.len - left)), function()
		Sound.play("roar", 0.02, 1)
		BossFx.screenFlash(Color3.fromRGB(255, 60, 40), 0.55, 0.5)
		local v = BossView.get()
		if v and v.base then
			BossVfx.impact(fight.z, { type = "ring", pos = v.base.Position, inner = 6, outer = 40 }, "ring", fight.floor)
		end
		local card = BossFx.titleCard("PHASE 2", (mirror and mirror:GetAttribute("Name") or "BOSS"):upper(), "", 0.24, Color3.fromRGB(255, 70, 50))
		BossFx.shakeCard(card, 10, 0.5)
		BossFx.fadeCard(card, 1.4)
	end)
	task.delay(math.max(0, 0.6 - (d.len - left)), say, d.line, 2.4)
	if not token then
		toast("The boss is transforming!", Color3.fromRGB(255, 120, 90))
	end
end

H.bossDeath = function(d)
	local left = d.len - (now() - d.at)
	BossView.act("death", { len = left })
	film(left + 0.6, {
		{ t0 = 0, t1 = 0.6, from = { Vector3.new(0.4, 0.45, 1.3), Vector3.new(0, 0.6, 0) }, to = { Vector3.new(0.38, 0.45, 1.25), Vector3.new(0, 0.6, 0) }, shake = 0.4 },
		{ t0 = 0.6, t1 = left + 0.6, from = { Vector3.new(0.6, 0.35, 1.4), Vector3.new(0, 0.45, 0) }, to = { Vector3.new(0.9, 0.7, 2.1), Vector3.new(0, 0.2, 0) } },
	}, fight.arena)
	BossFx.screenFlash(Color3.new(1, 1, 1), 0.7, 0.4)
	say(d.line, math.min(2.4, left))
	task.delay(math.max(0, left - 0.4), function()
		local v = BossView.get()
		if v and v.base then
			BossVfx.impact(fight.z, { type = "ring", pos = v.base.Position, inner = 4, outer = 30 }, "ring", fight.floor)
		end
		BossVfx.stop()
		BossView.hide()
		BossFx.defeatedCard(d.name or "")
		music(false)
		-- the HP bar goes with it (it stayed up at "0 / max" over the next area's unlock)
		task.delay(1.5, BossFx.showBar, false)
	end)
end

H.bossReset = function(d)
	endCine()
	BossAdds.clear()
	BossVfx.clearMovers()
	BossVfx.stop()
	BossView.hide()
	BossFx.showBar(false)
	music(false)
	local name = Config.ZONES[d.z] and Config.ZONES[d.z].boss.name or "The boss"
	local card = BossFx.titleCard("WIPED OUT", name:upper() .. " WINS", "It went back to sleep. Step on the pad to try again!", 0.3, Color3.fromRGB(200, 60, 60))
	BossFx.fadeCard(card, 3)
end

-- the minions (round 2)
local MINION_COLOR = { bee = Color3.fromRGB(255, 210, 60), seedling = Color3.fromRGB(250, 250, 240), crow = Color3.fromRGB(40, 40, 50), sprout = Color3.fromRGB(120, 190, 80), pumpkin = Color3.fromRGB(255, 140, 40) }
H.bossAddPop = function(d)
	BossVfx.puff(d.pos, MINION_COLOR[d.look] or Color3.new(1, 1, 1), if d.burrow then 6 else 14)
	Sound.playAt(if d.burrow then "cut" else "burst", 1.1 + math.random() * 0.2, 0.35)
end
H.bossAddHit = function(d)
	BossVfx.puff(d.pos, Color3.new(1, 1, 1), 5)
	Sound.playAt("hit", 1.2, 0.3)
end
H.bossAddBite = function(d)
	BossVfx.puff(d.pos, Color3.fromRGB(255, 90, 90), 4)
end
H.bossAddsClear = function(_d)
	BossAdds.clear()
	BossVfx.clearMovers()
end

H.bossHit = function(d)
	BossView.flinch(d.weak == true)
end

H.bossHurt = function(_d)
	BossFx.screenFlash(Color3.fromRGB(255, 30, 30), 0.45, 0.35)
	Sound.play("hurt", 0.1)
end

H.fighterDown = function(d)
	if d.userId ~= player.UserId then
		toast(d.name .. " is knocked out! Stand next to them to pick them up", Color3.fromRGB(255, 200, 90))
	else
		Sound.play("hurt", 0, 1)
	end
end

H.fighterUp = function(d)
	if d.userId == player.UserId then
		toast(if d.revived then "Back on your feet!" else "Back up at the gate!", Color3.fromRGB(140, 255, 150))
	end
end

H.bossHeal = function(d)
	BossVfx.healBurst(d.pos)
	if d.userId == player.UserId then
		Sound.play("pickup", 0.05)
	end
end

State.on("fx", function(kind: string, payload: any)
	local h = H[kind]
	if h then
		try(kind, h, payload)
	end
end)

-- the server turned or moved it
if mirror then
	mirror:GetAttributeChangedSignal("Cf"):Connect(function()
		local cf = mirror:GetAttribute("Cf")
		if typeof(cf) == "CFrame" then
			BossView.setTarget(cf)
		end
	end)
	-- joining while a boss is out
	task.defer(function()
		if mirror:GetAttribute("Active") and mirror:GetAttribute("State") ~= "dying" and mirror:GetAttribute("Rig") then
			try("late", function()
				startView(mirror:GetAttribute("Rig"), mirror:GetAttribute("Cf"), mirror:GetAttribute("Scale") or 5, mirror:GetAttribute("Z") or 1, nil)
				if (mirror:GetAttribute("Phase") or 1) >= 2 then
					BossView.rageNow()
					BossVfx.setRage(true)
					BossFx.setPhase(2)
				end
				music(true, (mirror:GetAttribute("Phase") or 1) >= 2)
			end)
		end
	end)
end

BossVfx.shake = BossFx.shake
task.defer(function()
	BossVfx.shake = BossFx.shake
end)

return BossCine
