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
local TweenService = game:GetService("TweenService")

local MowALawn = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(MowALawn:WaitForChild("Config"))
local HitFx = require(script.Parent.HitFx)
local IntroCast = require(script.Parent.IntroCast)
local IntroUi = require(script.Parent.IntroUi)
local Glitch = require(script.Parent.Glitch) -- (27 Oct) world 2's sneak peek
local Demon = require(script.Parent.Demon)
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
-- the film's own clock: it runs slower during a slow-motion moment (the crate's impact)
local simNow = 0
local timeScale = 1
-- every cut whips in: the new shot starts swung a little to one side and snaps onto its mark
local WHIP_TIME = 0.3
local whipFrom: CFrame? = nil
local whipSide = 1
local fovPunch = 0

local function shake(power: number, time: number)
	shakePower = power
	shakeUntil = os.clock() + time
end

-- Slow motion for `realTime` seconds (scale 0.25 = a quarter speed).
local function slowMo(scale: number, realTime: number)
	timeScale = scale
	task.delay(realTime, function()
		timeScale = 1
	end)
end

-- A zoom punch on a hit (the field of view snaps in by `amount` degrees and eases back).
local function punch(amount: number)
	fovPunch = amount
end

local function render(dt: number)
	local cam = workspace.CurrentCamera
	local fn = shot
	if not cam or not fn then
		return
	end
	-- (tests: the Workspace attribute IntroTestSpeed slows or freezes the film, e.g. 0 to look at a frame)
	local test = workspace:GetAttribute("IntroTestSpeed")
	simNow += dt * timeScale * (if type(test) == "number" then test else 1)
	local cf, fov = fn(math.clamp((simNow - shotStart) / shotLen, 0, 1))
	local since = simNow - shotStart
	if whipFrom and since < WHIP_TIME then
		local k = since / WHIP_TIME
		cf *= (whipFrom :: CFrame):Lerp(CFrame.identity, 1 - (1 - k) ^ 3)
	end
	local now = os.clock()
	if now < shakeUntil then
		local p = shakePower * (shakeUntil - now)
		cf *= CFrame.Angles((math.random() - 0.5) * p * 0.06, (math.random() - 0.5) * p * 0.06, (math.random() - 0.5) * p * 0.03)
	end
	fovPunch *= math.exp(-dt * 6)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf
	cam.FieldOfView = math.clamp(fov - fovPunch, 15, 100)
	for _, f in onFrame do
		f(now)
	end
end

-- Play a shot for `len` seconds of film time. A new shot whips in with a whoosh unless `still` (a shot that
-- carries straight on from the last one). Returns false if the cutscene was skipped meanwhile.
local function run(len: number, fn: ShotFn, still: boolean?): boolean
	shot = fn
	shotStart = simNow
	shotLen = len
	if still then
		whipFrom = nil
	else
		whipSide = -whipSide
		whipFrom = CFrame.Angles(math.rad(-4), math.rad(24) * whipSide, math.rad(-7) * whipSide)
		Sound.play("whoosh", 0.12, 0.45)
	end
	while simNow < shotStart + len do
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
				local at = d:GetPivot().Position
				if Config.zoneAt(at) == 1 then -- the meadow itself, not the grass round the village
					table.insert(spots, at)
				end
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
	-- the camp in area 1 (server/RunWorld.moveVillageToCamp): the party gathers there, the grass is all round it
	local w = workspace:FindFirstChild("World")
	local camp = w and w:GetAttribute("CampCenter")
	local from = entry
	if typeof(camp) == "Vector3" then
		local facing = w and w:GetAttribute("CampFacing")
		hub = camp
		fwd = if typeof(facing) == "Vector3" then facing else fwd
		cast = IntroCast.ground(camp + fwd * 2)
		from = camp
	end
	local spots = {}
	for _, at in clumpSpots() do
		if (at - from).Magnitude < 220 then
			table.insert(spots, at)
		end
	end
	local thick = thickest(spots, from) or (from + dirIn * 60)
	thick = IntroCast.ground(thick)
	local dirK = unit(flat(thick - from), dirIn)
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

-- Keeping the camera out of buildings and trees (the camp and the meadow change as the map is edited): a shot is
-- laid out round its subject at a turn (yaw, degrees); the first turn whose camera spots all see the subject wins.
local function turn(v: Vector3, deg: number): Vector3
	return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v)
end

local function sees(from: Vector3, to: Vector3): boolean
	local skip: { Instance } = {}
	local set = workspace:FindFirstChild("IntroSet")
	if set then
		table.insert(skip, set)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.IgnoreWater = true
	-- a little past the camera too, so it doesn't sit flush against a wall
	local dir = from - to
	return workspace:Raycast(to, dir + dir.Unit * 2.5, params) == nil
end

local YAWS = { 0, 25, -25, 50, -50, 75, -75, 100, -100, 130, -130, 160, -160, 180 }

-- The turn (from `yaws`, default YAWS, earlier ones win ties) whose spots(yaw) see `target(yaw)` best: every spot
-- must see it, and with `spread` the points that far to its left and right count too (so nothing sits at the
-- edges of the frame either). If no turn is clear, the one that comes closest.
local function freeYaw(spots: (number) -> { Vector3 }, target: (number) -> Vector3, yaws: { number }?, spread: number?): number
	local list = yaws or YAWS
	local best, bestScore = list[1], -1
	for _, y in list do
		local score = 0
		local t = target(y)
		for _, at in spots(y) do
			if sees(at, t) then
				score += 2
			end
			if spread then
				local side = (t - at):Cross(UP)
				side = if side.Magnitude > 0.01 then side.Unit * spread else Vector3.zero
				score += (if sees(at, t + side) then 1 else 0) + (if sees(at, t - side) then 1 else 0)
			end
		end
		if score > bestScore then
			best, bestScore = y, score
		end
	end
	return best
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
	local craneYaw = freeYaw(function(y)
		return { P.thick - turn(P.dirK, y) * 34 + UP * 38 }
	end, function()
		return P.thick + UP * 20
	end, { 0, 15, -15, 30, -30, 45, -45 })
	local top = P.thick - turn(P.dirK, craneYaw) * 34 + UP * 38
	local far = P.thick + turn(P.dirK, craneYaw) * 40
	return run(2.6, function(k)
		local e = ease(k)
		local p = P.m1:Lerp(top, e)
		local look = (P.m1 + P.dirK * 20 + UP * 4.5):Lerp(far, e)
		return CFrame.lookAt(p, look), 62 + e * 8
	end, true)
end

-- 2. the party, face by face, each with an emote and their name
local function partyShots(P: Plan, actors: { IntroCast.Actor }): boolean
	local n = #actors
	if n == 0 then
		return playing
	end
	-- they drop in from the sky one after another, landing hard in a puff of dust
	for i, actor in actors do
		task.delay(0.35 + (i - 1) * 0.32, function()
			if not playing then
				return
			end
			actor.drop(function(foot: Vector3)
				if not playing then
					return
				end
				shake(1.4, 0.35)
				punch(6)
				Sound.play("slam", 0.08, 0.7)
				Sound.play("fellLand", 0.1, 0.5)
				HitFx.play("bossRise", foot, Color3.fromRGB(150, 118, 80), false)
				actor.play("cheer")
			end)
		end)
	end
	-- off to one side of the mayor (he stands between the party and the camp centre)
	local dropYaw = freeYaw(function(y)
		return { P.cast + turn(P.fwd, y) * 16 + UP * 2.6 }
	end, function()
		return P.cast + UP * 4
	end, { 60, -60, 80, -80, 45, -45, 100, -100 })
	local dropDir = turn(P.fwd, dropYaw)
	local wideFrom = P.cast + dropDir * 16 + UP * 2.6
	local okDrop = run(1.0 + 0.32 * n, function(k)
		local p = wideFrom + dropDir * (-2.5 * ease(k)) + UP * (0.8 * k)
		return CFrame.lookAt(p, P.cast + UP * 4.2), 64
	end)
	if not okDrop then
		return false
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
	IntroUi.lowerThird(MAYOR, "Mayor of Spawn Village", RED, 1.9)
	local ok = run(2.6, function(k)
		local d = 13 - easeOut(k) * 2
		local p = head + front * d + P.right * 2.4 - UP * 1.4
		return CFrame.lookAt(p, head - UP * 0.6), 50
	end)
	if not ok then
		return false
	end
	-- the flashback: the valley before the grass came
	mode.value = "idle"
	flashback(true)
	IntroUi.say(MAYOR, "Long ago, this valley was the tidiest lawn in the land...", 34)
	local function flashPath(y: number): (Vector3, Vector3, Vector3)
		local d = turn(P.dirK, y)
		local side = d:Cross(UP)
		return P.thick - d * 46 + UP * 30 - side * 14, P.thick - d * 26 + UP * 24 + side * 10, P.thick + d * 25
	end
	local flashYaw = freeYaw(function(y)
		local a, b = flashPath(y)
		return { a, a:Lerp(b, 0.5), b }
	end, function()
		return P.thick + UP * 20
	end, nil, 36)
	local fa, fb, flook = flashPath(flashYaw)
	ok = run(3.8, function(k)
		return CFrame.lookAt(fa:Lerp(fb, ease(k)), flook), 58
	end)
	flashback(false)
	if not ok then
		return false
	end
	-- the grass now: a dolly zoom (pull back while zooming in) so the meadow looms up behind the gate
	IntroUi.say(MAYOR, "Then the grass came back... and it NEVER stopped growing!")
	Sound.playAt("rustle", 0.55, 0.7)
	shake(1.2, 3)
	local subject = P.thick + UP * 15
	local zoomYaw = freeYaw(function(y)
		local d = turn(P.dirK, y)
		return { subject - d * 16 + UP * 4, subject - d * 29 + UP * 4.6, subject - d * 42 + UP * 5.5 }
	end, function()
		return subject
	end, nil, 24)
	local zoomDir = turn(P.dirK, zoomYaw)
	local width = 2 * 16 * math.tan(math.rad(37))
	ok = run(3.0, function(k)
		local d = 16 + ease(k) * 26
		local p = subject - zoomDir * d + UP * (4 + k * 1.5)
		local fov = math.deg(2 * math.atan(width / (2 * d)))
		return CFrame.lookAt(p, subject + UP * 1), fov
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
			shake(2.6, 0.7)
			slowMo(0.22, 0.45)
			punch(14)
			IntroUi.flash(0.75, 0.3)
			Sound.playAt("slam", 0.45, 1)
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
		end, function()
			-- the title lands once the crate has burst open (owner 27 Oct: the new crate's reveal was hidden under it)
			if not playing then
				return
			end
			closeTitle = IntroUi.title(P.areaName:upper(), Config.GAME_NAME:upper(), "Mow it ALL to open the next area!")
			Sound.play("victory", 0, 0.5)
		end)
	end)
	local look = mid + UP * 2.5
	local crateYaw = freeYaw(function(y)
		local r, f = turn(P.right, y), turn(P.fwd, y)
		return { mid + r * 19 - f * 4 + UP * 5, mid + r * 16 - f * 4 + UP * 6.5 }
	end, function()
		return look
	end, { 0, 180, 20, -20, 160, -160, 40, -40 })
	local cr, cf = turn(P.right, crateYaw), turn(P.fwd, crateYaw)
	local ok = run(4.3, function(k)
		local p = mid + cr * (19 - k * 3) - cf * 4 + UP * (6.5 + k * 1.5)
		return CFrame.lookAt(p, look), 58
	end)
	if closeTitle then
		closeTitle(0.3)
	end
	return ok
end

-- 4b. A sneak peek of world 2 (owner, 27 Oct: "have this boss sneak peek in the first cutscene"): the picture
-- glitches and for a moment, far beyond the meadow on a blood-dark horizon, the glitch demon (client/Demon) looms
-- up and its eyes ignite... then it snaps back. About two seconds.
local function peekShot(P: Plan): boolean
	Glitch.burst(0.9, 0.35)
	Glitch.stutter("bhWarp", 1.7, 0.5, 4)
	shake(1.2, 0.3)
	task.wait(0.3)
	if not playing then
		Glitch.clear()
		return false
	end
	local far = IntroCast.ground(P.thick + P.dirK * 230)
	local demon = Demon.new(CFrame.lookAt(far, far - P.dirK), 2.4, nil, { lite = true }) -- (far off: the light build)
	demon.state.rise = 0.82
	demon.state.glitch = 1
	local ungrade = Glitch.grade({ Brightness = -0.32, Contrast = 0.55, Saturation = -0.65, TintColor = Color3.fromRGB(255, 118, 150) }, 0.12)
	Glitch.static(0.35, 1.7)
	Sound.playAt("roar", 0.48, 0.5)
	Sound.playAt("slam", 0.35, 0.7)
	local t0 = os.clock()
	local animate = function(now: number)
		demon.update(now - t0)
	end
	table.insert(onFrame, animate)
	local caption = Glitch.text(nil, "...something is waking up", UDim2.fromScale(0.42, 0.045), UDim2.fromScale(0.5, 0.8), Color3.fromRGB(255, 150, 200))
	local from = P.thick - P.dirK * 14 + UP * 9
	local ok = run(1.7, function(k)
		demon.state.eyes = math.clamp((k - 0.2) / 0.12, 0, 1)
		local eyes = demon.eyes()
		return CFrame.lookAt(from, eyes - UP * (10 - k * 3)), 21 - k * 5
	end, true)
	caption.stop()
	Glitch.burst(1, 0.3)
	Glitch.stutter("bhWarp", 2.1, 0.45, 3)
	local i = table.find(onFrame, animate)
	if i then
		table.remove(onFrame, i)
	end
	demon.destroy()
	ungrade(0.15)
	task.wait(0.2)
	Glitch.clear()
	return ok and playing
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
	end, true)
end

-------------------------------------------------------------------------------------------------------------
-- start and end
-------------------------------------------------------------------------------------------------------------
local savedHud = true
local music: Sound? = nil
local quieted: { [Sound]: number } = {}

-- The cutscene's own music; the game's music fades out under it and back after.
local function musicOn()
	local def = Config.SOUNDS.introMusic
	for _, s in game:GetService("SoundService"):GetChildren() do
		if s:IsA("Sound") and s.Name == "Music" then
			quieted[s] = s.Volume
			TweenService:Create(s, TweenInfo.new(0.8), { Volume = 0 }):Play()
		end
	end
	if def and def.id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "IntroMusic"
		s.SoundId = def.id
		s.Volume = def.volume or 0.5
		s.Parent = game:GetService("SoundService")
		s:Play()
		music = s
	end
end

local function musicOff()
	local s = music
	music = nil
	if s then
		TweenService:Create(s, TweenInfo.new(1.2), { Volume = 0 }):Play()
		task.delay(1.3, function()
			s:Destroy()
		end)
	end
	for q, v in quieted do
		if q.Parent then
			TweenService:Create(q, TweenInfo.new(2), { Volume = v }):Play()
		end
	end
	table.clear(quieted)
end

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
	musicOff()
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
	IntroCast.untag()
	if not mayorShots(P, mayor, mode) then
		return
	end
	if not crateShot(P, actors, mode) then
		return
	end
	if Config.WORLD2.peek and not peekShot(P) then
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
	task.delay(TIMEOUT, function()
		if workspace:GetAttribute("IntroTestSpeed") == nil then
			finish()
		end
	end)
	Soundscape.duck(0.5, 4)
	musicOn()
	-- the black cover is up: stream in the far-off places the camera visits
	local entry = Config.zoneEntry(1)
	local hub = Config.zoneCentre(0)
	local inward = (Config.zoneCentre(1) - entry).Unit
	local w = workspace:FindFirstChild("World")
	local camp = w and w:GetAttribute("CampCenter")
	streamIn({ entry, entry + inward * 50, entry + inward * 110, if typeof(camp) == "Vector3" then camp else hub:Lerp(entry, 0.4) })
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
	-- (report #1, Config.FIRST_TIMER) a first-timer mows and sells first; the film plays after that first sale (the
	-- server clears run.tutorial a moment after it)
	if worldReady and State.isRun() and d and d.run and not d.run.introSeen and not d.run.tutorial and player.Character then
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
