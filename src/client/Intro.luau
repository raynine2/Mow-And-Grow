-- The run's opening cutscene, the first time you're in a new run. A short film in the village before you start:
--   1. a low shot skimming through the overgrown Sunny Meadow, then a crane up over the sea of grass;
--   2. the party: a copy of each player's avatar lined up in the village, the camera passing face by face while
--      each does an emote and their name pops up;
--   3. Mayor Thistlewick on his soapbox: "Mowers! At last!", a sepia flashback of the valley before the grass
--      came (the first area's grass hidden on this client), the grass looming back, "Mow it ALL!";
--   4. a supply crate slams down in front of the party, bursts open, and the title card lands;
--   5. a dip to black and you're in first person, ready to go.
-- SKIP ends it at any moment. Once it has played (or been skipped) the server remembers it for this run ("Seen"
-- remote), so it doesn't play again on a rejoin. The actors and props are client/IntroCast, the screen
-- (letterbox, speech, cards) client/IntroUi.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MowALawn = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(MowALawn:WaitForChild("Config"))
local HitFx = require(script.Parent.HitFx)
local IntroCast = require(script.Parent.IntroCast)
local IntroUi = require(script.Parent.IntroUi)
local Sound = require(script.Parent.Sound)
local Soundscape = require(script.Parent.Soundscape)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Intro = {}
local player = Players.LocalPlayer

local UP = Vector3.yAxis
local GREEN = Color3.fromRGB(110, 220, 70)
local GOLD = Color3.fromRGB(255, 214, 60)
local RED = Color3.fromRGB(230, 70, 70)
local MAYOR = "MAYOR THISTLEWICK"
local TIMEOUT = 50 -- whatever happens, you get your camera and controls back by now

local playing = false
local played = false
local worldReady = false

-------------------------------------------------------------------------------------------------------------
-- helpers
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

local controls: any = nil
local function getControls(): any
	if not controls then
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			if module then
				controls = ((require :: any)(module)):GetControls()
			end
		end)
	end
	return controls
end

-------------------------------------------------------------------------------------------------------------
-- the camera: the current shot is a function of k (0..1 through the shot) giving a CFrame and a field of view
-------------------------------------------------------------------------------------------------------------
type ShotFn = (k: number) -> (CFrame, number)
local shot: ShotFn? = nil
local shotStart, shotLen = 0, 1
local shakeUntil, shakePower = 0, 0
local onFrame: { (t: number) -> () } = {}

local function shake(power: number, time: number)
	shakePower = power
	shakeUntil = os.clock() + time
end

local function render()
	local cam = workspace.CurrentCamera
	local fn = shot
	if not cam or not fn then
		return
	end
	local now = os.clock()
	local cf, fov = fn(math.clamp((now - shotStart) / shotLen, 0, 1))
	if now < shakeUntil then
		local p = shakePower * (shakeUntil - now)
		cf *= CFrame.Angles((math.random() - 0.5) * p * 0.06, (math.random() - 0.5) * p * 0.06, (math.random() - 0.5) * p * 0.03)
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf
	cam.FieldOfView = fov
	for _, f in onFrame do
		f(now)
	end
end

-- Play a shot for `len` seconds. Returns false if the cutscene was skipped meanwhile.
local function run(len: number, fn: ShotFn): boolean
	shot = fn
	shotStart = os.clock()
	shotLen = len
	local done = shotStart + len
	while os.clock() < done do
		if not playing then
			return false
		end
		task.wait()
	end
	return playing
end

-------------------------------------------------------------------------------------------------------------
-- where everything is (built from the map, so it follows Config / the generated world)
-------------------------------------------------------------------------------------------------------------
type Plan = {
	hub: Vector3,
	gate: Vector3,
	entry: Vector3,
	fwd: Vector3,
	right: Vector3,
	dirIn: Vector3,
	cast: Vector3,
	mayorAt: Vector3,
	m0: Vector3,
	m1: Vector3,
	thick: Vector3, -- the middle of the thickest patch of grass near the way in
	dirK: Vector3, -- from the way in toward it
	areaName: string,
}

local function clumpSpots(): { Vector3 }
	local spots = {}
	local grass = workspace:FindFirstChild("Grass1", true)
	if grass then
		for _, d in grass:GetDescendants() do
			if d:IsA("Model") and d.Name == "Clump" then
				table.insert(spots, d:GetPivot().Position)
			end
		end
	end
	return spots
end

-- How close a straight dolly from a to b passes to any clump (sideways distance).
local function clearance(a: Vector3, b: Vector3, spots: { Vector3 }): number
	local ab = flat(b - a)
	local len2 = math.max(ab:Dot(ab), 0.01)
	local best = math.huge
	for _, s in spots do
		local k = math.clamp(flat(s - a):Dot(ab) / len2, 0, 1)
		local d = (flat(s - a) - ab * k).Magnitude
		if d < best then
			best = d
		end
	end
	return best
end

-- The thickest patch of grass near the way in: the clump with the most neighbours (closer ones win ties),
-- and the middle of that bunch.
local function thickest(spots: { Vector3 }, entry: Vector3): Vector3?
	local best, bestScore = nil, -math.huge
	for _, a in spots do
		local n, sum = 0, Vector3.zero
		for _, b in spots do
			if (flat(a - b)).Magnitude < 22 then
				n += 1
				sum += b
			end
		end
		local score = n - (a - entry).Magnitude * 0.02
		if score > bestScore then
			best, bestScore = sum / n, score
		end
	end
	return best
end

-- The low dolly into that patch: pick the line with the most room between the stalks.
local function meadowLine(thick: Vector3, dirK: Vector3, spots: { Vector3 }): (Vector3, Vector3)
	local side = dirK:Cross(UP)
	local bestA, bestB, bestRoom = thick - dirK * 16, thick - dirK * 2, -1
	for _, back in { 20, 16, 12 } do
		for off = -12, 12, 3 do
			local a = thick - dirK * back + side * off
			local b = a + dirK * 14
			local room = clearance(a, b, spots)
			if room > bestRoom + 0.5 then
				bestA, bestB, bestRoom = a, b, room
			end
		end
	end
	local ga, gb = IntroCast.ground(bestA), IntroCast.ground(bestB)
	return ga + UP * 2.4, gb + UP * 2.8
end

local function plan(): Plan
	local hub = Config.zoneCentre(0)
	local entry = Config.zoneEntry(1)
	local gate = entry
	for _, g in Config.gates() do
		if g.b == 1 then
			gate = g.pos
		end
	end
	local fwd = unit(flat(gate - hub), Vector3.zAxis)
	local dirIn = unit(flat(Config.zoneCentre(1) - entry), fwd)
	local cast = IntroCast.ground(hub:Lerp(gate, 0.42))
	local spots = {}
	for _, at in clumpSpots() do
		if (at - entry).Magnitude < 220 then
			table.insert(spots, at)
		end
	end
	local thick = thickest(spots, entry) or (entry + dirIn * 60)
	thick = IntroCast.ground(thick)
	local dirK = unit(flat(thick - entry), dirIn)
	local m0, m1 = meadowLine(thick, dirK, spots)
	local def = Config.ZONES[1]
	return {
		hub = hub,
		gate = gate,
		entry = entry,
		fwd = fwd,
		right = fwd:Cross(UP),
		dirIn = dirIn,
		cast = cast,
		mayorAt = cast + fwd * 11,
		m0 = m0,
		m1 = m1,
		thick = thick,
		dirK = dirK,
		areaName = if def and def.name then def.name else "Area 1",
	}
end

-- Ask the server to stream in the places the camera will visit (the map streams around your character).
local function streamIn(spots: { Vector3 })
	local left = #spots
	for _, at in spots do
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(at, 3)
			end)
			left -= 1
		end)
	end
	local deadline = os.clock() + 3
	while left > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the film, shot by shot
-------------------------------------------------------------------------------------------------------------
local sepia: ColorCorrectionEffect? = nil

local function flashback(on: boolean)
	IntroUi.flash(0.8, 0.45)
	IntroUi.film(on)
	IntroCast.hideGrass(on)
	if on then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "IntroSepia"
		cc.Saturation = -0.85
		cc.Contrast = 0.15
		cc.Brightness = 0.04
		cc.TintColor = Color3.fromRGB(255, 222, 172)
		cc.Parent = workspace.CurrentCamera
		sepia = cc
	elseif sepia then
		sepia:Destroy()
		sepia = nil
	end
end

-- 1. the meadow: skim low through the stalks, then crane up over the whole sea of grass
local function meadowShots(P: Plan): boolean
	task.delay(0.6, function()
		if playing then
			IntroUi.lowerThird(P.areaName:upper(), "Nobody has mowed here in years...", GREEN, 3.4)
		end
	end)
	Sound.play("whoosh", 0.1, 0.3)
	local ok = run(3.0, function(k)
		local p = P.m0:Lerp(P.m1, k * 0.5 + ease(k) * 0.5)
		local look = p + P.dirK * 20 + UP * (2.5 + k * 2)
		return CFrame.lookAt(p, look) * CFrame.Angles(0, 0, math.sin(k * math.pi) * 0.05), 62
	end)
	if not ok then
		return false
	end
	local top = P.thick - P.dirK * 34 + UP * 38
	local far = P.thick + P.dirK * 40
	return run(2.6, function(k)
		local e = ease(k)
		local p = P.m1:Lerp(top, e)
		local look = (P.m1 + P.dirK * 20 + UP * 4.5):Lerp(far, e)
		return CFrame.lookAt(p, look), 62 + e * 8
	end)
end

-- 2. the party, face by face, each with an emote and their name
local function partyShots(P: Plan, actors: { IntroCast.Actor }): boolean
	local n = #actors
	if n == 0 then
		return playing
	end
	IntroUi.lowerThird("THE MOWERS", if n == 1 then "One mower. One valley." else n .. " mowers. One valley.", GOLD, 2.8)
	local first, last = actors[1].head, actors[n].head
	local headY = if first then first.Position.Y + 0.3 else P.cast.Y + 4.8
	local a = (if first then flat(first.Position) else flat(P.cast)) - P.right * 2.6
	local b = (if last then flat(last.Position) else flat(P.cast)) + P.right * 2.6
	local done = {}
	local len = math.clamp(1.25 * n + 1.8, 3.2, 7)
	return run(len, function(k)
		local along = flat(a):Lerp(flat(b), ease(k))
		local p = Vector3.new(along.X, headY, along.Z) + P.fwd * 7.8
		local look = Vector3.new(along.X, headY - 0.25, along.Z) - P.right * 0.4
		-- each actor reacts as the camera reaches them
		for i, actor in actors do
			local h = actor.head
			if h and not done[i] and (flat(h.Position) - along):Dot(P.right) < 1.6 then
				done[i] = true
				actor.play("emote")
				actor.tag()
				Sound.playAt("pickup", 0.9 + i * 0.08, 0.25)
			end
		end
		return CFrame.lookAt(p, look), 44
	end)
end

-- 3. the mayor's story: hello, the flashback, the grass now, "mow it all"
local function mayorShots(P: Plan, mayor: IntroCast.Mayor, mode: { value: string }): boolean
	local head = mayor.head.Position
	local front = -P.fwd -- he faces the party
	mode.value = "talk"
	IntroUi.say(MAYOR, "Mowers! At last, you've come!")
	IntroUi.lowerThird(MAYOR, "Mayor of Spawn Village", RED, 2.4)
	local ok = run(2.6, function(k)
		local d = 7.5 - easeOut(k) * 2
		local p = head + front * d + P.right * 1.8 - UP * 1.4
		return CFrame.lookAt(p, head - UP * 0.4), 50
	end)
	if not ok then
		return false
	end
	-- the flashback: the valley before the grass came
	mode.value = "idle"
	flashback(true)
	IntroUi.say(MAYOR, "Long ago, this valley was the tidiest lawn in the land...", 34)
	ok = run(3.8, function(k)
		local e = ease(k)
		local side = P.dirK:Cross(UP)
		local p = (P.thick - P.dirK * 46 + UP * 26 - side * 14):Lerp(P.thick - P.dirK * 26 + UP * 20 + side * 10, e)
		return CFrame.lookAt(p, P.thick + P.dirK * 25), 58
	end)
	flashback(false)
	if not ok then
		return false
	end
	-- the grass now: a dolly zoom (pull back while zooming in) so the meadow looms up behind the gate
	IntroUi.say(MAYOR, "Then the grass came back... and it NEVER stopped growing!")
	Sound.playAt("rustle", 0.55, 0.7)
	shake(1.2, 3)
	local subject = P.thick + UP * 4
	local width = 2 * 16 * math.tan(math.rad(37))
	ok = run(3.0, function(k)
		local d = 16 + ease(k) * 26
		local p = subject - P.dirK * d + UP * (1 + k * 1.5)
		local fov = math.deg(2 * math.atan(width / (2 * d)))
		return CFrame.lookAt(p, subject + UP * 2), fov
	end)
	if not ok then
		return false
	end
	-- "mow it all": over the party's shoulders, the mayor pointing at the gate
	mode.value = "point"
	IntroUi.say(MAYOR, "Mow it ALL... and our valley is saved!")
	return run(2.6, function(k)
		local p = P.cast - P.fwd * (6 - k * 1.5) + UP * 5.5 + P.right * 3.2
		return CFrame.lookAt(p, P.mayorAt + UP * 4 + P.right * -0.6), 60
	end)
end

-- 4. the crate drop and the title
local function crateShot(P: Plan, actors: { IntroCast.Actor }, mode: { value: string }): boolean
	IntroUi.hush()
	local mid = P.cast + P.fwd * 5.5
	local closeTitle: ((number) -> ())? = nil
	task.delay(0.35, function()
		if not playing then
			return
		end
		Sound.play("whoosh", 0.05, 0.5)
		IntroCast.crate(mid, -P.fwd, function()
			if not playing then
				return
			end
			shake(2.2, 0.6)
			Sound.play("slam", 0.05, 1)
			Sound.play("fellLand", 0.1, 0.8)
			local g = IntroCast.ground(mid)
			for i = 1, 5 do
				local a = i / 5 * math.pi * 2
				HitFx.play("bossRise", g + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.6, Color3.fromRGB(150, 118, 80), false)
			end
			mode.value = "cheer"
			for _, actor in actors do
				actor.play("cheer")
			end
			closeTitle = IntroUi.title(P.areaName:upper(), Config.GAME_NAME:upper(), "Mow it ALL to open the next area!")
			Sound.play("victory", 0, 0.5)
		end)
	end)
	local look = mid + UP * 2.5
	local ok = run(3.6, function(k)
		local p = mid + P.right * (19 - k * 3) - P.fwd * 4 + UP * (5 + k * 1.5)
		return CFrame.lookAt(p, look), 58
	end)
	if closeTitle then
		closeTitle(0.3)
	end
	return ok
end

-- 5. dip to black and land in your own eyes
local function homeShot(): boolean
	IntroUi.fade(0, 0.3)
	task.wait(0.32)
	IntroCast.clearSet() -- the characters stay hidden until the end, so your own head isn't in the shot
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return playing
	end
	local look = root.CFrame.LookVector
	local eye = head.Position
	local final = CFrame.lookAt(eye, eye + look)
	IntroUi.letterbox(false, 0.8)
	IntroUi.fade(1, 0.6)
	return run(1.1, function(k)
		local e = easeOut(k)
		local p = (eye - look * 9 + UP * 4):Lerp(eye, e)
		return CFrame.lookAt(p, eye + look * 20):Lerp(final, e), 70
	end)
end

-------------------------------------------------------------------------------------------------------------
-- start and end
-------------------------------------------------------------------------------------------------------------
local savedHud = true

local function finish()
	if not playing then
		return
	end
	playing = false
	shot = nil
	table.clear(onFrame)
	pcall(function()
		RunService:UnbindFromRenderStep("MowIntro")
	end)
	if sepia then
		sepia:Destroy()
		sepia = nil
	end
	IntroCast.cleanup()
	IntroUi.close()
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
	pcall(function()
		local c = getControls()
		if c then
			c:Enable()
		end
	end)
	UI.gui.Enabled = savedHud
	State.fire("Seen", "intro")
end

local function film()
	local P = plan()
	local actors = IntroCast.party(P.cast, P.fwd, P.right)
	local mayor = IntroCast.mayor(P.mayorAt, -P.fwd)
	local mode = { value = "idle" }
	local t0 = os.clock()
	table.insert(onFrame, function(now)
		mayor.update(now - t0, mode.value)
	end)
	IntroCast.hideCharacters(true)
	IntroUi.fade(1, 0.9)
	IntroUi.letterbox(true, 0.6)
	if not meadowShots(P) then
		return
	end
	if not partyShots(P, actors) then
		return
	end
	if not mayorShots(P, mayor, mode) then
		return
	end
	if not crateShot(P, actors, mode) then
		return
	end
	homeShot()
end

local function play()
	local cam = workspace.CurrentCamera
	if playing or played or not cam then
		return
	end
	played = true
	playing = true
	savedHud = UI.gui.Enabled
	UI.gui.Enabled = false
	IntroUi.open(finish)
	pcall(function()
		local c = getControls()
		if c then
			c:Disable()
		end
	end)
	cam.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("MowIntro", Enum.RenderPriority.Camera.Value + 2, render)
	task.delay(TIMEOUT, finish)
	Soundscape.duck(0.5, 4)
	-- the black cover is up: stream in the far-off places the camera visits
	local entry = Config.zoneEntry(1)
	local hub = Config.zoneCentre(0)
	local inward = (Config.zoneCentre(1) - entry).Unit
	streamIn({ entry, entry + inward * 50, entry + inward * 110, hub:Lerp(entry, 0.4) })
	if not playing then
		return
	end
	local ok, err = pcall(film)
	if not ok then
		warn("[Intro] " .. tostring(err))
	end
	finish()
end

local function maybePlay()
	local d = State.data
	if worldReady and State.isRun() and d and d.run and not d.run.introSeen and player.Character then
		task.spawn(play)
	end
end

State.on("world", function(w)
	if w.mode == "Run" and not w.loading then
		worldReady = true
		maybePlay()
	end
end)
State.on("data", maybePlay)

return Intro
