--!strict
-- FILM: the camera, the clock and the picture for the cutscenes (client/Intro, client/Ending), shot like a movie:
--   * shots: each is a function of k (0..1 through the shot) and t (seconds in) giving the camera's CFrame, its
--     field of view and, if it likes, what to focus on; Film.run plays one for a length of film time;
--   * lenses: Film.mm(35) is a 35 mm lens's field of view (long lenses for faces, wide ones for places);
--   * a handheld drift (smooth noise; Film.hand(amount)), shake that fades (Film.shake(trauma)), zoom punches,
--     whip pans with a blur, a focus pull (depth of field follows the subject), freeze frames;
--   * the film's own clock: Film.speed(scale, ramp) for slow motion (actors and timed events follow it);
--     Film.at(seconds, fn) runs fn that far into the film from now;
--   * the picture: colour grades (Film.grade), the light (time of day, exposure, haze; Film.light), a vignette,
--     flashes, motion blur; the lighting is ours while a film plays (client/BiomeLight pauses) and goes back after.
-- "Reduce camera shake" (the CalmCamera attribute) turns the shake, punches and whips right down.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Film = {}
local player = Players.LocalPlayer

local UP = Vector3.yAxis
Film.UP = UP

-------------------------------------------------------------------------------------------------------------
-- small maths
-------------------------------------------------------------------------------------------------------------
function Film.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Film.unit(v: Vector3, fallback: Vector3): Vector3
	return if v.Magnitude > 1e-3 then v.Unit else fallback
end

-- easing: inOut (cubic), out (cubic), inn (cubic), smooth (smoothstep), sine (in-out), expo out
function Film.inOut(k: number): number
	k = math.clamp(k, 0, 1)
	return if k < 0.5 then 4 * k * k * k else 1 - (-2 * k + 2) ^ 3 / 2
end
function Film.out(k: number): number
	return 1 - (1 - math.clamp(k, 0, 1)) ^ 3
end
function Film.inn(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * k
end
function Film.smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end
function Film.sine(k: number): number
	return 0.5 - 0.5 * math.cos(math.clamp(k, 0, 1) * math.pi)
end
function Film.expo(k: number): number
	k = math.clamp(k, 0, 1)
	return if k >= 1 then 1 else 1 - 2 ^ (-10 * k)
end

-- the vertical field of view of a lens of `mm` millimetres (full-frame film: 24 mm tall)
function Film.mm(mm: number): number
	return math.deg(2 * math.atan(12 / mm))
end

-- A point along a Catmull-Rom spline through `pts` (k 0..1 over the whole path).
function Film.spline(pts: { Vector3 }, k: number): Vector3
	local n = #pts
	if n == 1 then
		return pts[1]
	end
	local f = math.clamp(k, 0, 1) * (n - 1)
	local i = math.min(math.floor(f), n - 2)
	local u = f - i
	local p0 = pts[math.max(i, 1)]
	local p1 = pts[i + 1]
	local p2 = pts[i + 2]
	local p3 = pts[math.min(i + 3, n)]
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

-- A camera at `pos` looking at `target`, rolled `roll` degrees (a Dutch angle).
function Film.look(pos: Vector3, target: Vector3, roll: number?): CFrame
	local cf = CFrame.lookAt(pos, target)
	if roll and roll ~= 0 then
		cf *= CFrame.Angles(0, 0, math.rad(roll))
	end
	return cf
end

local function calm(): boolean
	return player:GetAttribute("CalmCamera") == true
end

-------------------------------------------------------------------------------------------------------------
-- state
-------------------------------------------------------------------------------------------------------------
export type ShotFn = (k: number, t: number) -> (CFrame, number, Vector3?)
export type ShotOpts = {
	cut: string?, -- "whip" (a fast pan in with a blur), "smash" (a jolt) or nil (a clean cut)
	hand: number?, -- the handheld drift for this shot (default: Film.hand's)
	near: number?, -- depth of field: blur in front of the subject (0..1)
	far: number?, -- and behind it (0..1); both nil: a gentle default by the lens
	radius: number?, -- how deep the sharp zone is, studs (default by distance)
	dir: number?, -- whip direction: 1 or -1
}

Film.playing = false
local clock = 0
local timeScale = 1
local scaleFrom, scaleTo, scaleStart, scaleLen = 1, 1, 0, 0
local shot: ShotFn? = nil
local shotOpts: ShotOpts = {}
local shotStart, shotLen = 0, 1
local handBase = 0.5
local trauma = 0
local traumaDecay = 1.2
local fovPunch = 0
local whipT = -1
local whipDir = 1
local freezeUntil = 0
local frozenCf: CFrame? = nil
local frameFns: { (dt: number, t: number) -> () } = {}
local failedFns: { [any]: boolean } = {} -- (each one that errors is reported once)
local timed: { { at: number, fn: () -> () } } = {}
local lastCf = CFrame.identity
local focusDist = 30
local dof: DepthOfFieldEffect? = nil
local blur: BlurEffect? = nil
local blurAmount = 0
local savedFov = 70

-- the film's clock (seconds of film time since Film.start)
function Film.now(): number
	return clock
end

function Film.scale(): number
	return timeScale
end

-- Slow motion (or fast): ease the clock's speed to `scale` over `ramp` seconds of real time.
function Film.speed(scale: number, ramp: number?)
	scaleFrom, scaleTo, scaleStart, scaleLen = timeScale, scale, os.clock(), ramp or 0
	if (ramp or 0) <= 0 then
		timeScale = scale
	end
end

-- The handheld drift for the shots that don't set their own (0 = a tripod, 1 = shoulder-mounted).
function Film.hand(amount: number)
	handBase = amount
end

-- Camera shake: `trauma` 0..1 (0.3 a rumble, 0.6 a slam, 1 an earthquake); it fades at `decay` per second.
function Film.shake(amount: number, decay: number?)
	local k = if calm() then 0.3 else 1
	trauma = math.clamp(math.max(trauma, amount * k), 0, 1)
	traumaDecay = decay or 1.2
end

-- A zoom punch: the view snaps in by `deg` and eases back.
function Film.punch(deg: number)
	fovPunch = math.max(fovPunch, deg * (if calm() then 0.35 else 1))
end

-- The picture sticks for `time` real seconds (a glitch stutter).
function Film.freeze(time: number)
	freezeUntil = os.clock() + time
	frozenCf = lastCf
end

-- Run `fn` once the film's clock is `delay` seconds on from now (slow motion stretches it).
function Film.at(delay: number, fn: () -> ())
	table.insert(timed, { at = clock + delay, fn = fn })
end

-- Call `fn(dt, t)` every frame with the film's (scaled) dt, until the film ends. Returns a remover.
function Film.every(fn: (dt: number, t: number) -> ()): () -> ()
	table.insert(frameFns, fn)
	return function()
		local i = table.find(frameFns, fn)
		if i then
			table.remove(frameFns, i)
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- keeping the camera out of walls: if something solid is between the subject and the camera, slide the camera in
-- toward the subject (quick in, slow out)
-------------------------------------------------------------------------------------------------------------
local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude
sight.IgnoreWater = true

-- What the camera may look through: the film's sets, the grass, everyone's characters (call again when things change).
function Film.refreshSight(extra: { Instance }?)
	local skip: { Instance } = {}
	for _, name in { "IntroSet", "EndingSet", "Corruption", "FilmSet" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	local w = workspace:FindFirstChild("World")
	local grass = w and w:FindFirstChild("Grass")
	if grass then
		table.insert(skip, grass)
	end
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(skip, pl.Character)
		end
	end
	for _, e in extra or {} do
		table.insert(skip, e)
	end
	sight.FilterDescendantsInstances = skip
end

export type View = { pull: number }

function Film.view(): View
	return { pull = 0 }
end

function Film.clear(cam: Vector3, target: Vector3, view: View): Vector3
	local d = cam - target
	local dist = d.Magnitude
	local want = 0
	if dist > 1 then
		local hit = workspace:Raycast(target, d, sight)
		if hit then
			want = math.clamp(1 - (hit.Distance - 2.5) / dist, 0, 0.92)
		end
	end
	view.pull += (want - view.pull) * (if want > view.pull then 0.6 else 0.06)
	return cam - d * view.pull
end

-- Whether `from` can see `to` (nothing solid between them, a little past `from` too).
function Film.sees(from: Vector3, to: Vector3): boolean
	local dir = from - to
	if dir.Magnitude < 0.05 then
		return true
	end
	return workspace:Raycast(to, dir + dir.Unit * 2.5, sight) == nil
end

-------------------------------------------------------------------------------------------------------------
-- the picture: grade, light, vignette, flashes (a ScreenGui under the films' own, IntroCinema = 20)
-------------------------------------------------------------------------------------------------------------
local gui: ScreenGui? = nil
local vignette: { Frame } = {}
local grade: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local savedLight: { [string]: any }? = nil
local savedAtmo: { [string]: any }? = nil
local savedEffects: { [Instance]: boolean } = {}
local lightFrom: { [string]: any } = {}
local lightTo: { [string]: any } = {}
local lightStart, lightLen = 0, 0
local atmoTween: Tween? = nil
local LIGHT_KEYS = { "ClockTime", "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom" }

local function screen(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "FilmPicture"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 19
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	-- the vignette: four soft dark bands round the edges
	table.clear(vignette)
	local function edge(size: UDim2, pos: UDim2, rotation: number)
		local e = Instance.new("Frame")
		e.BorderSizePixel = 0
		e.BackgroundColor3 = Color3.new(0, 0, 0)
		e.BackgroundTransparency = 1
		e.Size = size
		e.Position = pos
		e.ZIndex = 1
		local gr = Instance.new("UIGradient")
		gr.Rotation = rotation
		gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.75), NumberSequenceKeypoint.new(1, 1) })
		gr.Parent = e
		e.Parent = g
		table.insert(vignette, e)
	end
	edge(UDim2.fromScale(0.32, 1), UDim2.fromScale(0, 0), 0)
	edge(UDim2.fromScale(0.32, 1), UDim2.fromScale(0.68, 0), 180)
	edge(UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0), 90)
	edge(UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0.62), -90)
	return g
end

-- The vignette's strength (0 = none, 1 = heavy), eased over `time`.
function Film.vignette(strength: number, time: number?)
	screen()
	for _, e in vignette do
		TweenService:Create(e, TweenInfo.new(time or 0.6, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 - math.clamp(strength, 0, 1) * 0.85 }):Play()
	end
end

-- A flash of colour over the picture (a cut, an impact, a camera flash), fading over `time`.
function Film.flash(color: Color3?, strength: number, time: number)
	local g = screen()
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1 - math.clamp(strength * (if calm() then 0.5 else 1), 0, 1)
	f.ZIndex = 5
	f.Parent = g
	TweenService:Create(f, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.delay(time + 0.05, function()
		f:Destroy()
	end)
end

-- GRADES: the film's colour correction (over the world's own)
local GRADES: { [string]: { [string]: any } } = {
	none = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) },
	story = { Brightness = 0.04, Contrast = 0.12, Saturation = -0.38, TintColor = Color3.fromRGB(255, 226, 186) }, -- a warm old storybook
	gloom = { Brightness = -0.05, Contrast = 0.18, Saturation = -0.32, TintColor = Color3.fromRGB(214, 226, 240) }, -- cold and grey
	dusk = { Brightness = 0.01, Contrast = 0.14, Saturation = 0.06, TintColor = Color3.fromRGB(255, 222, 196) }, -- golden hour
	hero = { Brightness = 0.02, Contrast = 0.16, Saturation = 0.14, TintColor = Color3.fromRGB(255, 244, 228) }, -- rich and warm
	night = { Brightness = -0.06, Contrast = 0.2, Saturation = -0.22, TintColor = Color3.fromRGB(196, 210, 255) }, -- blue night
	dream = { Brightness = 0.06, Contrast = -0.04, Saturation = -0.1, TintColor = Color3.fromRGB(255, 240, 222) }, -- soft and bright
}

function Film.grade(name: string, time: number?)
	local goal = GRADES[name] or GRADES.none
	local cc = grade
	if not cc or not cc.Parent then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "FilmGrade"
		made.Parent = Lighting
		grade = made
		cc = made
	end
	assert(cc)
	if (time or 0) <= 0 then
		for k, val in goal do
			(cc :: any)[k] = val
		end
	else
		TweenService:Create(cc, TweenInfo.new(time or 1, Enum.EasingStyle.Sine), goal):Play()
	end
end

-- The glow: bloom intensity (0..1) and size, eased.
function Film.glow(intensity: number, size: number?, time: number?)
	local b = bloom
	if not b or not b.Parent then
		local made = Instance.new("BloomEffect")
		made.Name = "FilmBloom"
		made.Threshold = 0.9
		made.Intensity = 0
		made.Size = 24
		made.Parent = Lighting
		bloom = made
		b = made
	end
	assert(b)
	TweenService:Create(b, TweenInfo.new(time or 0.8, Enum.EasingStyle.Sine), { Intensity = intensity, Size = size or 24 }):Play()
end

-- The light: { ClockTime, Brightness, ExposureCompensation, Ambient, OutdoorAmbient, ColorShift_Top,
-- ColorShift_Bottom, atmosphere = { Density, Haze, Glare, Color, Decay, Offset } }, eased over `time`. ClockTime is
-- held every frame (the server's clock writes it too).
function Film.light(goal: { [string]: any }, time: number?)
	-- (what an earlier call set and this one doesn't mention stays where it was going)
	local keep = lightTo
	lightFrom = {}
	lightTo = {}
	for k, v in keep do
		lightFrom[k] = v
		lightTo[k] = v
	end
	for _, k in LIGHT_KEYS do
		if goal[k] ~= nil then
			lightFrom[k] = (Lighting :: any)[k]
			lightTo[k] = goal[k]
		end
	end
	lightStart, lightLen = os.clock(), math.max(time or 0, 0)
	local atmo = goal.atmosphere
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo and a then
		if atmoTween then
			atmoTween:Cancel()
		end
		local tw = TweenService:Create(a, TweenInfo.new(math.max(time or 0, 0.01), Enum.EasingStyle.Sine), atmo)
		tw:Play()
		atmoTween = tw
	end
end

local function lerpValue(a: any, b: any, k: number): any
	if typeof(a) == "number" then
		return a + (b - a) * k
	elseif typeof(a) == "Color3" then
		return (a :: Color3):Lerp(b, k)
	end
	return if k >= 1 then b else a
end

local function stepLight()
	if next(lightTo) == nil then
		return
	end
	local k = if lightLen <= 0 then 1 else Film.sine((os.clock() - lightStart) / lightLen)
	for key, goal in lightTo do
		local want = lerpValue(lightFrom[key], goal, k)
		local cur = (Lighting :: any)[key]
		if key == "ClockTime" then
			-- (the short way round the clock)
			local from = lightFrom[key] :: number
			local diff = ((goal :: number) - from + 12) % 24 - 12
			want = (from + diff * k) % 24
			if math.abs(cur - want) > 0.004 then
				Lighting.ClockTime = want
			end
		elseif typeof(want) == "number" then
			if math.abs(cur - want) > 1e-3 then
				(Lighting :: any)[key] = want
			end
		elseif cur ~= want then
			(Lighting :: any)[key] = want
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the render step
-------------------------------------------------------------------------------------------------------------
local function setFocus(cam: Camera, cf: CFrame, focus: Vector3?, dt: number)
	local d = dof
	if not d or not d.Parent then
		return
	end
	local o = shotOpts
	local dist = if focus then (focus - cf.Position).Magnitude else 60
	focusDist += (dist - focusDist) * math.min(1, dt * 7)
	d.FocusDistance = math.clamp(focusDist, 0, 200)
	d.InFocusRadius = math.clamp(o.radius or (focusDist * 0.22 + 1.2), 0.5, 50)
	local fov = cam.FieldOfView
	-- longer lenses (narrow views) blur the background more, like real ones
	local auto = math.clamp((40 - fov) / 30, 0, 1)
	d.FarIntensity = o.far or (0.12 + auto * 0.35)
	d.NearIntensity = o.near or (auto * 0.25)
end

local function render(dt: number)
	local cam = workspace.CurrentCamera
	if not cam or not Film.playing then
		return
	end
	local now = os.clock()
	-- the clock
	if scaleLen > 0 then
		local k = math.clamp((now - scaleStart) / scaleLen, 0, 1)
		timeScale = scaleFrom + (scaleTo - scaleFrom) * Film.sine(k)
		if k >= 1 then
			scaleLen = 0
		end
	end
	local test = workspace:GetAttribute("IntroTestSpeed")
	local fdt = dt * timeScale * (if type(test) == "number" then test else 1)
	local frozen = now < freezeUntil
	if not frozen then
		clock += fdt
	end
	stepLight()
	-- timed events
	if #timed > 0 then
		local due: { () -> () } = {}
		for i = #timed, 1, -1 do
			local e = timed[i]
			if clock >= e.at then
				table.insert(due, e.fn)
				table.remove(timed, i)
			end
		end
		for i = #due, 1, -1 do
			task.spawn(due[i])
		end
	end
	-- the actors (one that errors doesn't stop the camera: it's reported once and the film carries on)
	if not frozen then
		for _, f in frameFns do
			local ok, err = pcall(f, fdt, clock)
			if not ok and not failedFns[f] then
				failedFns[f] = true
				warn("[Film] " .. tostring(err))
			end
		end
	end
	local fn = shot
	if not fn then
		return
	end
	if frozen and frozenCf then
		cam.CFrame = frozenCf
		return
	end
	local t = clock - shotStart
	local cf, fov, focus = fn(math.clamp(t / shotLen, 0, 1), t)
	-- handheld: slow smooth drift in rotation (a breathing operator), a touch of position
	local hand = shotOpts.hand or handBase
	if hand > 0 then
		local a = hand * (if calm() then 0.4 else 1)
		local rx = (math.noise(clock * 0.31, 1.3) * 0.7 + math.noise(clock * 1.07, 7.7) * 0.22) * a
		local ry = (math.noise(clock * 0.27, 4.1) * 0.9 + math.noise(clock * 0.93, 2.2) * 0.25) * a
		local rz = (math.noise(clock * 0.23, 9.9) * 0.5) * a
		cf *= CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
	end
	-- shake (trauma squared, so small knocks stay small)
	if trauma > 0 then
		local s = trauma * trauma
		local q = now * 24
		cf *= CFrame.Angles(math.rad(math.noise(q, 1.7) * 3.2 * s), math.rad(math.noise(q, 5.3) * 3.2 * s), math.rad(math.noise(q, 9.1) * 2.4 * s))
		trauma = math.max(0, trauma - traumaDecay * dt)
	end
	-- a whip pan in: the shot starts swung to one side and snaps onto its mark, blurred
	if whipT >= 0 then
		local k = (now - whipT) / 0.26
		if k >= 1 then
			whipT = -1
		else
			local e = 1 - Film.out(k)
			cf *= CFrame.Angles(0, math.rad(32 * whipDir * e), math.rad(-6 * whipDir * e))
		end
	end
	fovPunch *= math.exp(-dt * 7)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf
	cam.FieldOfView = math.clamp(fov - fovPunch, 6, 100)
	lastCf = cf
	setFocus(cam, cf, focus, dt)
	-- motion blur fades
	if blur and blur.Parent then
		blurAmount *= math.exp(-dt * 9)
		blur.Size = blurAmount
	end
end

-- Play a shot for `len` seconds of film time. Returns false if the film was stopped meanwhile.
function Film.run(len: number, fn: ShotFn, opts: ShotOpts?): boolean
	shot = fn
	shotOpts = opts or {}
	shotStart = clock
	shotLen = math.max(len, 0.01)
	local cut = shotOpts.cut
	if cut == "whip" and not calm() then
		whipT = os.clock()
		whipDir = shotOpts.dir or (if math.random() < 0.5 then 1 else -1)
		blurAmount = 14
	elseif cut == "smash" then
		Film.shake(0.45, 2.5)
		Film.punch(6)
	end
	while Film.playing and clock < shotStart + shotLen do
		task.wait()
	end
	return Film.playing
end

-- Wait `len` seconds of film time (the current shot carries on). False if the film was stopped.
function Film.wait(len: number): boolean
	local untilT = clock + len
	while Film.playing and clock < untilT do
		task.wait()
	end
	return Film.playing
end

-- A blur pulse (a whip, a hit), fading quickly.
function Film.blur(size: number)
	if calm() then
		size *= 0.4
	end
	blurAmount = math.max(blurAmount, size)
end

-------------------------------------------------------------------------------------------------------------
-- start and stop
-------------------------------------------------------------------------------------------------------------
-- Take over the camera and the light. `name`: the render step's name.
function Film.start(name: string)
	Film.playing = true
	clock = 0
	timeScale, scaleLen = 1, 0
	shot = nil
	shotOpts = {}
	trauma, fovPunch, whipT, freezeUntil, blurAmount = 0, 0, -1, 0, 0
	table.clear(frameFns)
	table.clear(failedFns)
	table.clear(timed)
	handBase = 0.5
	local cam0 = workspace.CurrentCamera
	savedFov = if cam0 and cam0.FieldOfView > 20 and cam0.FieldOfView < 100 then cam0.FieldOfView else 70
	-- the light is ours: BiomeLight pauses, and everything we touch is put back after
	player:SetAttribute("BiomeLightOff", true)
	savedLight = {}
	for _, k in LIGHT_KEYS do
		(savedLight :: any)[k] = (Lighting :: any)[k]
	end
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a then
		savedAtmo = { Density = a.Density, Haze = a.Haze, Glare = a.Glare, Color = a.Color, Decay = a.Decay, Offset = a.Offset }
	end
	-- our own depth of field and motion blur (the world's depth of field is switched off meanwhile)
	table.clear(savedEffects)
	for _, e in Lighting:GetChildren() do
		if e:IsA("DepthOfFieldEffect") or e:IsA("BlurEffect") then
			savedEffects[e] = e.Enabled
			e.Enabled = false
		end
	end
	local d = Instance.new("DepthOfFieldEffect")
	d.Name = "FilmFocus"
	d.FarIntensity = 0.15
	d.NearIntensity = 0
	d.FocusDistance = 30
	d.InFocusRadius = 20
	d.Parent = Lighting
	dof = d
	local b = Instance.new("BlurEffect")
	b.Name = "FilmBlur"
	b.Size = 0
	b.Parent = Lighting
	blur = b
	screen()
	Film.vignette(0.35, 0)
	Film.grade("none", 0)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, render)
end

-- Give everything back. `name`: the render step's name Film.start was given.
function Film.stop(name: string)
	Film.playing = false
	shot = nil
	table.clear(frameFns)
	table.clear(timed)
	pcall(function()
		RunService:UnbindFromRenderStep(name)
	end)
	for _, e in { dof, blur, grade, bloom } do
		if e then
			e:Destroy()
		end
	end
	dof, blur, grade, bloom = nil, nil, nil, nil
	for e, on in savedEffects do
		if e.Parent then
			(e :: any).Enabled = on
		end
	end
	table.clear(savedEffects)
	table.clear(lightTo)
	if atmoTween then
		atmoTween:Cancel()
		atmoTween = nil
	end
	if savedLight then
		for k, val in savedLight :: { [string]: any } do
			pcall(function()
				(Lighting :: any)[k] = val
			end)
		end
		savedLight = nil
	end
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a and savedAtmo then
		for k, val in savedAtmo :: { [string]: any } do
			(a :: any)[k] = val
		end
	end
	savedAtmo = nil
	player:SetAttribute("BiomeLightOff", nil)
	if gui then
		gui:Destroy()
		gui = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = savedFov
	end
end

-- The camera's last frame (for cutting to a new shot that starts where the last one ended).
function Film.lastFrame(): CFrame
	return lastCf
end

return Film
