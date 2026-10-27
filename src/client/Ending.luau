-- The ending (owner, 27 Oct: "if you defeat the final boss make a cool fitting ending story with a cinematic
-- cutscene, very ending-cinematic, with end credits at the end where it prompts you to go to the next world or do
-- the same mission again, or ???"). Played on every client when the last area's boss falls (server/Run sends
-- runComplete with `ending = true`). It closes the story the opening cutscene (client/Intro) starts: Mayor
-- Thistlewick's valley, overgrown since "the grass came back and never stopped growing", is mowed bare at last.
--   1. STARLIGHT ISLES: a slow orbit round the last arena, "the last wild grass in the valley... is gone";
--   2. THE VALLEY: a long flight back over all eight areas, now mowed in stripes, each name ticking off;
--   3. SPAWN VILLAGE: the Mayor and the whole party (copies of everyone's avatars), cheers and fireworks;
--   4. THE TWIST: a hush, one strange glowing sprout pushes up out of the meadow... "THE END...?";
--   5. the credits roll (the party "starring", the bosses as the cast, the makers), then the end screen:
--      PLAY AGAIN (back to the lobby for a new run) and a locked "???" (the next world, not out yet).
-- SKIP jumps to the end screen. The actors and the letterbox / speech / title cards are the opening's own
-- (client/IntroCast, client/IntroUi), so both films look alike.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MowALawn = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(MowALawn:WaitForChild("Config"))
local Format = require(MowALawn:WaitForChild("Format"))
local IntroCast = require(script.Parent.IntroCast)
local IntroUi = require(script.Parent.IntroUi)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Skin = require(script.Parent.Skin)
local Confetti = require(script.Parent.Confetti)

local Ending = {}
local player = Players.LocalPlayer

local UP = Vector3.yAxis
local GREEN = Color3.fromRGB(110, 220, 70)
local GOLD = Color3.fromRGB(255, 214, 60)
local RED = Color3.fromRGB(230, 70, 70)
local MYSTERY = Color3.fromRGB(170, 110, 255)
local MAYOR = "MAYOR THISTLEWICK"
local MAKERS_FALLBACK = "The Mow And Grow team" -- the credits name the game's owner (group or user) when they can

local playing = false
local played = false

-------------------------------------------------------------------------------------------------------------
-- helpers and the camera (the same way client/Intro films: a shot is a function of k, 0..1, giving a CFrame
-- and a field of view)
-------------------------------------------------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function unit(v: Vector3, fallback: Vector3): Vector3
	return if v.Magnitude > 0.01 then v.Unit else fallback
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return if k < 0.5 then 4 * k * k * k else 1 - (-2 * k + 2) ^ 3 / 2
end

local function easeOut(k: number): number
	return 1 - (1 - math.clamp(k, 0, 1)) ^ 3
end

type ShotFn = (k: number) -> (CFrame, number)
local shot: ShotFn? = nil
local shotStart, shotLen, clock = 0, 1, 0
local shakeUntil, shakePower = 0, 0
local onFrame: { (t: number) -> () } = {}

local function shake(power: number, time: number)
	shakePower = power
	shakeUntil = os.clock() + time
end

local function render(dt: number)
	local cam = workspace.CurrentCamera
	local fn = shot
	if not cam or not fn then
		return
	end
	clock += dt
	local cf, fov = fn(math.clamp((clock - shotStart) / shotLen, 0, 1))
	local now = os.clock()
	if now < shakeUntil then
		local p = shakePower * (shakeUntil - now)
		cf *= CFrame.Angles((math.random() - 0.5) * p * 0.05, (math.random() - 0.5) * p * 0.05, 0)
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf
	cam.FieldOfView = math.clamp(fov, 15, 100)
	for _, f in onFrame do
		f(now)
	end
end

-- Play a shot for `len` seconds; false if the ending was skipped meanwhile.
local function run(len: number, fn: ShotFn): boolean
	shot = fn
	shotStart = clock
	shotLen = len
	while clock < shotStart + len do
		if not playing then
			return false
		end
		task.wait()
	end
	return playing
end

local function ground(p: Vector3): Vector3
	return IntroCast.ground(p)
end

-- Ask the server to stream in the places the camera will visit.
local function streamIn(spots: { Vector3 })
	local left = #spots
	for _, at in spots do
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(at, 4)
			end)
			left -= 1
		end)
	end
	local deadline = os.clock() + 4
	while left > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

-------------------------------------------------------------------------------------------------------------
-- where everything is
-------------------------------------------------------------------------------------------------------------
type Plan = { arena: Vector3, areas: { { pos: Vector3, name: string } }, camp: Vector3, fwd: Vector3, right: Vector3, cast: Vector3, mayorAt: Vector3, sprout: Vector3 }

local function plan(): Plan
	local n = #Config.ZONES
	local w = workspace:FindFirstChild("World")
	local arenas = w and w:FindFirstChild("Arenas")
	local a = arenas and arenas:FindFirstChild("Arena" .. n)
	local arena = if a and a:IsA("Model") then a:GetPivot().Position else Config.zoneCentre(n)
	local areas = {}
	for z = n, 1, -1 do
		local def = Config.ZONES[z]
		table.insert(areas, { pos = Config.zoneCentre(z), name = if def and def.name then def.name else ("Area " .. z) })
	end
	-- the camp in area 1, where the opening gathered the party
	local camp = w and w:GetAttribute("CampCenter")
	local facing = w and w:GetAttribute("CampFacing")
	local campPos = if typeof(camp) == "Vector3" then camp else Config.zoneCentre(0)
	local fwd = if typeof(facing) == "Vector3" then unit(flat(facing), Vector3.zAxis) else unit(flat(Config.zoneCentre(1) - campPos), Vector3.zAxis)
	local cast = ground(campPos + fwd * 2)
	-- the sprout: out in the first meadow, where the story began
	local meadow = Config.zoneCentre(1)
	local sprout = ground(campPos:Lerp(meadow, 0.55))
	return {
		arena = arena,
		areas = areas,
		camp = campPos,
		fwd = fwd,
		right = fwd:Cross(UP),
		cast = cast,
		mayorAt = cast + fwd * 11,
		sprout = sprout,
	}
end

-------------------------------------------------------------------------------------------------------------
-- props: fireworks over the camp, and the sprout
-------------------------------------------------------------------------------------------------------------
local set: Folder? = nil
local function propFolder(): Folder
	if set and set.Parent then
		return set
	end
	local f = Instance.new("Folder")
	f.Name = "EndingSet"
	f.Parent = workspace
	set = f
	return f
end

local function spark(pos: Vector3, color: Color3, size: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one * size
	p.Position = pos
	p.Parent = propFolder()
	return p
end

local FIREWORK_COLORS = { GOLD, Color3.fromRGB(255, 110, 150), Color3.fromRGB(110, 220, 255), GREEN, Color3.fromRGB(255, 150, 60) }
local function firework(at: Vector3)
	local color = FIREWORK_COLORS[math.random(1, #FIREWORK_COLORS)]
	local rise = spark(at - UP * 26, color, 0.7)
	TweenService:Create(rise, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at }):Play()
	task.delay(0.7, function()
		rise:Destroy()
		if not playing then
			return
		end
		Sound.play("pickup", 0.3, 0.35)
		for i = 1, 16 do
			local th = i / 16 * math.pi * 2
			local ph = (math.random() - 0.5) * 1.6
			local dir = Vector3.new(math.cos(th) * math.cos(ph), math.sin(ph), math.sin(th) * math.cos(ph))
			local s = spark(at, color, 0.6)
			local t = TweenService:Create(s, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at + dir * 11 - UP * 3, Size = Vector3.one * 0.15, Transparency = 1 })
			t:Play()
			task.delay(1.35, function()
				s:Destroy()
			end)
		end
	end)
end

-- One strange sprout: a stem and two leaves that glow and pulse, growing out of the bare lawn.
local function makeSprout(at: Vector3): (Model, (number) -> ())
	local m = Instance.new("Model")
	m.Name = "Sprout"
	local function piece(size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = size
		p.CFrame = cf
		p.Parent = m
		return p
	end
	local stem = piece(Vector3.new(0.3, 2.4, 0.3), CFrame.new(at + UP * 1.2), Color3.fromRGB(120, 255, 170))
	local l1 = piece(Vector3.new(1.4, 0.15, 0.6), CFrame.new(at + UP * 2.1 + Vector3.new(0.6, 0, 0)) * CFrame.Angles(0, 0, math.rad(25)), MYSTERY)
	local l2 = piece(Vector3.new(1.4, 0.15, 0.6), CFrame.new(at + UP * 2.4 - Vector3.new(0.6, 0, 0)) * CFrame.Angles(0, 0, math.rad(-25)), MYSTERY)
	local light = Instance.new("PointLight")
	light.Color = MYSTERY
	light.Range = 10
	light.Brightness = 0
	light.Parent = stem
	m.Parent = propFolder()
	local base = { [stem] = stem.CFrame, [l1] = l1.CFrame, [l2] = l2.CFrame }
	-- grow: 0 = nothing, 1 = full height; it sways and its glow pulses
	local function grow(k: number)
		local s = math.max(0.02, k)
		for p, cf in base do
			local rel = CFrame.new(at):ToObjectSpace(cf)
			p.CFrame = CFrame.new(at) * CFrame.Angles(math.sin(os.clock() * 2) * 0.08 * k, 0, 0) * CFrame.new(rel.Position * s) * rel.Rotation
		end
		light.Brightness = k * (1.5 + math.sin(os.clock() * 5) * 0.8)
	end
	grow(0)
	return m, grow
end

-------------------------------------------------------------------------------------------------------------
-- the film
-------------------------------------------------------------------------------------------------------------
-- 1. the last arena, slowly orbited from high up
local function arenaShot(P: Plan): boolean
	IntroUi.fade(1, 1.2)
	task.delay(0.8, function()
		if playing then
			IntroUi.lowerThird(string.upper(P.areas[1].name), "The last wild grass in the valley... is gone.", GREEN, 4)
		end
	end)
	return run(6, function(k)
		local a = math.rad(200 + k * 70)
		local r = 70 - ease(k) * 12
		local p = P.arena + Vector3.new(math.cos(a) * r, 34 + k * 10, math.sin(a) * r)
		return CFrame.lookAt(p, P.arena + UP * 6), 50
	end)
end

-- 2. the flight back over the valley, area by area, to the camp
local function valleyShots(P: Plan): boolean
	local pts = {}
	for _, area in P.areas do
		table.insert(pts, area.pos + UP * 85)
	end
	table.insert(pts, P.camp + UP * 60 - P.fwd * 40)
	local legs = #pts - 1
	local named = {}
	IntroUi.say(MAYOR, "...The grass. It's... it's GONE.", 30)
	return run(15, function(k)
		local f = ease(k) * legs
		local i = math.clamp(math.floor(f) + 1, 1, legs)
		local u = f - (i - 1)
		local p = pts[i]:Lerp(pts[i + 1], u)
		local ahead = pts[math.min(i + 1, #pts)]:Lerp(pts[math.min(i + 2, #pts)], u)
		local area = P.areas[i]
		if area and not named[i] and u > 0.15 then
			named[i] = true
			IntroUi.lowerThird(string.upper(area.name), "MOWED", GREEN, 1.6)
			Sound.play("pickup", 0.1, 0.3)
		end
		return CFrame.lookAt(p, ahead - UP * 70), 70
	end)
end

-- 3. the village: the Mayor, the party, the cheering and the fireworks
local function villageShots(P: Plan, mayor: IntroCast.Mayor, actors: { IntroCast.Actor }, mode: { value: string }): boolean
	local head = mayor.head.Position
	local front = -P.fwd
	mode.value = "talk"
	IntroUi.say(MAYOR, "You... you actually did it!")
	IntroUi.lowerThird(MAYOR, "Mayor of Spawn Village", RED, 2)
	local ok = run(3.6, function(k)
		local d = 12 - easeOut(k) * 2.5
		return CFrame.lookAt(head + front * d + P.right * 2.4 - UP * 1.2, head - UP * 0.5), 50
	end)
	if not ok then
		return false
	end
	IntroUi.say(MAYOR, "Every meadow, every hill, every last isle... MOWED!")
	mode.value = "point"
	ok = run(3.8, function(k)
		local p = P.cast - P.fwd * (7 - k * 1.5) + UP * 5 + P.right * 3
		return CFrame.lookAt(p, P.mayorAt + UP * 4), 58
	end)
	if not ok then
		return false
	end
	-- the party cheers, fireworks go up
	mode.value = "cheer"
	for _, actor in actors do
		actor.play("cheer")
	end
	Sound.play("victory", 0, 0.6)
	Confetti.burst(140)
	IntroUi.say(MAYOR, "Spawn Village is SAVED! The tidiest valley in the land, once again!")
	local sky = P.mayorAt + P.fwd * 18 + UP * 34
	for i = 0, 9 do
		task.delay(i * 0.55, function()
			if playing then
				firework(sky + P.right * math.random(-28, 28) + P.fwd * math.random(-10, 10) + UP * math.random(-4, 8))
			end
		end)
	end
	ok = run(3.4, function(k)
		local p = P.cast + P.fwd * (9 - k * 1.5) + UP * (3.5 + k)
		return CFrame.lookAt(p, P.cast + UP * 3), 56
	end)
	if not ok then
		return false
	end
	task.delay(0.4, Confetti.burst, 100)
	return run(5, function(k)
		local e = ease(k)
		local p = (P.cast - P.fwd * 12 + UP * 6):Lerp(P.cast - P.fwd * 34 + UP * 42, e)
		return CFrame.lookAt(p, P.cast:Lerp(sky, 0.4 + e * 0.4)), 62
	end)
end

-- 4. the twist: the music stops, one strange sprout pushes up out of the bare meadow
local function twistShot(P: Plan): boolean
	IntroUi.hush()
	IntroUi.fade(0, 0.5)
	task.wait(0.6)
	if not playing then
		return false
	end
	local _, grow = makeSprout(P.sprout)
	local look = P.sprout + UP * 1.6
	local side = P.right
	IntroUi.fade(1, 0.8)
	shake(0.6, 2.5)
	Sound.play("rustle", 0, 0.6)
	local said = false
	local ok = run(6.5, function(k)
		grow(math.clamp((k - 0.15) / 0.55, 0, 1))
		if k > 0.55 and not said then
			said = true
			Sound.play("reveal", 0, 0.7)
			IntroUi.say(MAYOR, "...Hold on. What's THAT?", 28)
		end
		local d = 11 - ease(k) * 6.5
		local p = look - P.fwd * d + side * (2 - k) + UP * (0.6 + k * 0.4)
		return CFrame.lookAt(p, look), 48 - k * 10
	end)
	if not ok then
		return false
	end
	IntroUi.hush()
	local close = IntroUi.title("THE END", "...?", "Something in the valley is still growing.")
	ok = run(3.6, function(k)
		grow(1)
		local p = look - P.fwd * 4.5 + side + UP * (1 + k * 0.4)
		return CFrame.lookAt(p, look), 38
	end)
	close(0.4)
	return ok
end

-------------------------------------------------------------------------------------------------------------
-- credits and the end screen (their own ScreenGui, over everything)
-------------------------------------------------------------------------------------------------------------
local screen: ScreenGui? = nil
local function endGui(): ScreenGui
	if screen and screen.Parent then
		return screen
	end
	local g = Instance.new("ScreenGui")
	g.Name = "EndCredits"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 60
	g.Parent = player:WaitForChild("PlayerGui")
	local sc = Instance.new("UIScale")
	local cam = workspace.CurrentCamera
	sc.Scale = if cam then math.clamp(cam.ViewportSize.Y / 900, 0.55, 1.2) else 1
	sc.Parent = g
	screen = g
	return g
end

-- MADE BY: the game's group (Config.GROUP_ID), its owner, then the collaborators listed in
-- Config.CREDITS_TEAM (Roblox usernames: shown as "Display Name (@username)").
local function makers(): { string }
	local list = {}
	-- the studio first: the game's group (Config.GROUP_ID, Atlas Interactive Inc)
	pcall(function()
		if Config.GROUP_ID and Config.GROUP_ID > 0 then
			table.insert(list, game:GetService("GroupService"):GetGroupInfoAsync(Config.GROUP_ID).Name)
		end
	end)
	pcall(function()
		if game.CreatorId > 0 then
			if game.CreatorType == Enum.CreatorType.Group then
				local g = game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId).Name
				if not table.find(list, g) then
					table.insert(list, g)
				end
			else
				local user = Players:GetNameFromUserIdAsync(game.CreatorId)
				local info = game:GetService("UserService"):GetUserInfosByUserIdsAsync({ game.CreatorId })[1]
				table.insert(list, if info and info.DisplayName ~= user then info.DisplayName .. "  (@" .. user .. ")" else user)
			end
		end
	end)
	for _, user in (Config.CREDITS_TEAM or {}) :: { string } do
		local line = user
		pcall(function()
			local id = Players:GetUserIdFromNameAsync(user)
			local info = game:GetService("UserService"):GetUserInfosByUserIdsAsync({ id })[1]
			if info and info.DisplayName ~= info.Username then
				line = info.DisplayName .. "  (@" .. info.Username .. ")"
			elseif info then
				line = info.Username
			end
		end)
		if not table.find(list, line) then
			table.insert(list, line)
		end
	end
	if #list == 0 then
		table.insert(list, MAKERS_FALLBACK)
	end
	return list
end

-- The credit lines: { kind, text } (kind "title" | "head" | "line" | "gap").
local function creditLines(): { { string } }
	local L = {}
	local function add(kind: string, text: string?)
		table.insert(L, { kind, text or "" })
	end
	add("title", string.upper(Config.GAME_NAME or "Mow And Grow"))
	add("gap")
	add("head", "STARRING")
	for _, p in Players:GetPlayers() do
		add("line", p.DisplayName .. "  (@" .. p.Name .. ")")
	end
	add("gap")
	add("head", "AND")
	add("line", "Mayor Thistlewick  as himself")
	add("gap")
	add("head", "THE BOSSES")
	local Moves = require(MowALawn:WaitForChild("BossMoves")) :: any
	for z = 1, #Config.ZONES do
		local def = Config.ZONES[z]
		local b = def and def.boss
		local m = Moves.list[z]
		if b then
			add("line", b.name .. (if m and m.title then "  ·  " .. m.title else ""))
		end
	end
	add("gap")
	add("head", "THE VALLEY")
	for z = 1, #Config.ZONES do
		add("line", Config.ZONES[z].name)
	end
	add("gap")
	add("head", "MADE BY")
	for _, name in makers() do
		add("line", name)
	end
	add("gap")
	add("head", "SPECIAL THANKS")
	add("line", "Every blade of grass that was mowed in the making of this valley")
	add("line", "And you, for playing")
	add("gap")
	add("gap")
	add("title", "THANK YOU FOR PLAYING!")
	return L
end

-- The credits roll up the screen over a dark sky; `skip` (or the end of the roll) ends it.
local function rollCredits(): boolean
	local g = endGui()
	local bg = Instance.new("Frame")
	bg.Name = "Credits"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	bg.BackgroundTransparency = 1
	bg.Parent = g
	TweenService:Create(bg, TweenInfo.new(1), { BackgroundTransparency = 0 }):Play()
	local roll = Instance.new("Frame")
	roll.BackgroundTransparency = 1
	roll.AnchorPoint = Vector2.new(0.5, 0)
	roll.Size = UDim2.fromOffset(900, 10)
	roll.Parent = bg
	local y = 0
	for _, l in creditLines() do
		local kind, text = l[1], l[2]
		local h = if kind == "title" then 70 elseif kind == "head" then 40 elseif kind == "gap" then 34 else 32
		if kind ~= "gap" then
			local t = UI.text(roll, text, UDim2.new(1, 0, 0, h), { pos = UDim2.fromOffset(0, y), stroke = if kind == "title" then 5 else 2.5 })
			if kind == "title" then
				UI.gradient(t, GOLD)
			elseif kind == "head" then
				t.TextColor3 = GOLD
			end
		end
		y += h + 6
	end
	roll.Size = UDim2.fromOffset(900, y)
	local skip = UI.button(bg, "SKIP  >>", Color3.fromRGB(70, 70, 86), UDim2.fromOffset(150, 48), function()
		playing = false
	end, { pos = UDim2.new(1, -24, 1, -18), anchor = Vector2.new(1, 1), name = "CreditsSkip" })
	local _ = skip
	local view = (g.AbsoluteSize.Y > 0 and g.AbsoluteSize.Y or 800) / ((g:FindFirstChildOfClass("UIScale") :: UIScale).Scale)
	local from, to = view + 20, -y - 20
	local len = math.clamp((view + y) / 55, 18, 40)
	local t0 = os.clock()
	while playing and os.clock() - t0 < len do
		local k = (os.clock() - t0) / len
		roll.Position = UDim2.new(0.5, 0, 0, from + (to - from) * k)
		task.wait()
	end
	return playing
end

-- PLAY AGAIN (back to the lobby: a new run) and "???" (the next world: locked, not out yet).
local function endScreen(d: any)
	local g = endGui()
	local old = g:FindFirstChild("Credits")
	local bg = Instance.new("Frame")
	bg.Name = "EndScreen"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	bg.BackgroundTransparency = if old then 0 else 1
	bg.Parent = g
	if old then
		old:Destroy()
	else
		TweenService:Create(bg, TweenInfo.new(0.6), { BackgroundTransparency = 0 }):Play()
	end
	local W, H = 620, 380
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(W, H)
	box.Parent = bg
	local _, face = Skin.frame(box, "ui_card", Vector2.new(W, H), { name = "Card" })
	local title = UI.text(face, "THE END...?", UDim2.new(1, 0, 0, 66), { pos = UDim2.fromOffset(0, 6), stroke = 5 })
	UI.gradient(title, GOLD)
	-- (report #16) the run medal you earned (Config.RUN_MEDALS)
	local medal = ""
	for _, m in Config.RUN_MEDALS do
		if m.id == d.medal then
			medal = "   " .. m.name:upper() .. " MEDAL!"
		end
	end
	local time = if (d.time or 0) > 0 then "Run time " .. Format.clock(d.time) .. (if d.best then "   NEW BEST!" else "") .. medal .. "   ·   " else ""
	local stats = UI.text(face, time .. "+" .. Format.short(d.gems or 0) .. " gems", UDim2.new(1, -40, 0, 28), { pos = UDim2.fromOffset(20, 78), stroke = 0, color = Color3.fromRGB(120, 80, 40) })
	local _ = stats
	local blurb = UI.text(face, "The valley is mowed. Mayor Thistlewick sleeps soundly... for now.", UDim2.new(1, -40, 0, 26), { pos = UDim2.fromOffset(20, 114), stroke = 0, color = Color3.fromRGB(140, 96, 60) })
	blurb.TextWrapped = true
	local chosen = false
	local again: TextButton
	again = UI.button(face, "PLAY AGAIN", GREEN, UDim2.fromOffset(250, 64), function()
		if chosen then
			return
		end
		chosen = true
		again.Text = "SEE YOU THERE!"
		Sound.play("purchase")
		State.fire("Seen", "ending", "again") -- the server sends you back to the lobby for a new run
	end, { pos = UDim2.new(0.5, -14, 0, 176), anchor = Vector2.new(1, 0), name = "PlayAgain" })
	Skin.press(again)
	local mystery = UI.button(face, "? ? ?", Color3.fromRGB(70, 50, 110), UDim2.fromOffset(250, 64), function() end, { pos = UDim2.new(0.5, 14, 0, 176), anchor = Vector2.new(0, 0), name = "NextWorld" })
	local note = UI.text(face, "", UDim2.new(1, -40, 0, 24), { pos = UDim2.fromOffset(20, 252), stroke = 2, color = MYSTERY })
	mystery.Activated:Connect(function()
		Sound.play("denied")
		note.Text = "A new world is growing somewhere... Not yet, gardener."
		local base = mystery.Position
		for i = 1, 6 do
			mystery.Position = base + UDim2.fromOffset(if i % 2 == 0 then 6 else -6, 0)
			task.wait(0.04)
		end
		mystery.Position = base
	end)
	-- the "???" breathes a strange purple
	task.spawn(function()
		while mystery.Parent do
			local k = 0.5 + 0.5 * math.sin(os.clock() * 2.5)
			mystery.BackgroundColor3 = Color3.fromRGB(70, 50, 110):Lerp(MYSTERY, k * 0.6)
			task.wait()
		end
	end)
	local left = UI.text(face, "", UDim2.new(1, -40, 0, 22), { pos = UDim2.fromOffset(20, H - 70), stroke = 0, color = Color3.fromRGB(140, 96, 60) })
	local endsAt = (d.receivedAt or os.clock()) + (d.wait or 120)
	task.spawn(function()
		while left.Parent do
			left.Text = ("Back to the lobby in %d s"):format(math.max(0, math.ceil(endsAt - os.clock())))
			task.wait(0.25)
		end
	end)
	Skin.popIn(box, 0)
end

-------------------------------------------------------------------------------------------------------------
-- start and end
-------------------------------------------------------------------------------------------------------------
local savedHud = true
local quieted: { [Sound]: number } = {}
local music: Sound? = nil

local function musicOn()
	for _, s in game:GetService("SoundService"):GetChildren() do
		if s:IsA("Sound") and s.Name == "Music" then
			quieted[s] = s.Volume
			TweenService:Create(s, TweenInfo.new(1), { Volume = 0 }):Play()
		end
	end
	local def = Config.SOUNDS.introMusic
	if def and def.id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "EndingMusic"
		s.SoundId = def.id
		s.Volume = def.volume or 0.5
		s.Parent = game:GetService("SoundService")
		s:Play()
		music = s
	end
end

local function musicDown()
	local s = music
	music = nil
	if s then
		TweenService:Create(s, TweenInfo.new(1.5), { Volume = 0 }):Play()
		task.delay(1.6, function()
			s:Destroy()
		end)
	end
end

local function controls(on: boolean)
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			local c = ((require :: any)(module)):GetControls()
			if on then
				c:Enable()
			else
				c:Disable()
			end
		end
	end)
end

-- The film is over (or skipped): clear the set, give the camera back, show the end screen.
local function stopFilm()
	playing = false
	shot = nil
	table.clear(onFrame)
	pcall(function()
		RunService:UnbindFromRenderStep("MowEnding")
	end)
	IntroCast.cleanup()
	IntroUi.close()
	if set then
		set:Destroy()
		set = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function film(P: Plan): boolean
	local actors = IntroCast.party(P.cast, P.fwd, P.right)
	local mayor = IntroCast.mayor(P.mayorAt, -P.fwd)
	local mode = { value = "idle" }
	local t0 = os.clock()
	table.insert(onFrame, function(now)
		mayor.update(now - t0, mode.value)
	end)
	IntroCast.hideCharacters(true)
	IntroUi.letterbox(true, 0.8)
	if not arenaShot(P) then
		return false
	end
	if not valleyShots(P) then
		return false
	end
	if not villageShots(P, mayor, actors, mode) then
		return false
	end
	return twistShot(P)
end

-- Play the ending. `d`: the server's runComplete data ({ gems, time, best, wait }).
function Ending.play(d: any)
	local cam = workspace.CurrentCamera
	if played or not cam then
		return
	end
	played = true
	d.receivedAt = os.clock() -- (the server sends everyone back d.wait seconds after this)
	-- after the boss's own death scene (client/BossFx flies the camera itself): wait for it to hand back
	local t = os.clock()
	task.wait(5)
	while cam.CameraType ~= Enum.CameraType.Custom and os.clock() - t < 18 do
		task.wait(0.1)
	end
	playing = true
	savedHud = UI.gui.Enabled
	UI.gui.Enabled = false
	controls(false)
	local skipped = false
	IntroUi.open(function()
		skipped = true
		playing = false
	end)
	IntroUi.fade(0, 0.8)
	musicOn()
	local P = plan()
	local spots = { P.arena, P.camp, P.sprout }
	for _, a in P.areas do
		table.insert(spots, a.pos)
	end
	streamIn(spots)
	clock = 0
	RunService:BindToRenderStep("MowEnding", Enum.RenderPriority.Camera.Value + 3, render)
	local ok = playing and film(P)
	IntroUi.fade(0, 0.5)
	task.wait(0.5)
	stopFilm()
	if ok and not skipped then
		playing = true -- (the credits use the same flag: they can still be skipped by the end screen's arrival)
		rollCredits()
		playing = false
	end
	musicDown()
	for q, v in quieted do
		if q.Parent then
			TweenService:Create(q, TweenInfo.new(2), { Volume = v }):Play()
		end
	end
	table.clear(quieted)
	endScreen(d)
	-- you stay on the end screen until you choose or the server sends everyone back; the HUD stays hidden
	local _ = savedHud
end

return Ending
