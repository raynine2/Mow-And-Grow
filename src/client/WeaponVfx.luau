-- WeaponVfx: every weapon's hit, rebuilt from the owner's Chop A Forest clip frame by frame (owner, 28 Oct: "each
-- weapon a high quality effect like this video so it feels immersive"; brief: "Chop A Forest look: soft, chunky,
-- bright, bloom; normal hit medium; the big ring flash + bloom + star sparkles only on mutated clumps").
--   * the particle layers live in ReplicatedStorage.WeaponVfxPresets (VFX Forge style: Attachment + emitter +
--     EmitCount; built by ServerStorage.MowALawnTools.BuildWeaponVfx). Copies are pooled here and re-aimed per hit.
--   * code draws what needs exact timing: chunky bits flying at the camera, the screen-wide glow of a reveal.
--   * the hit lands where your crosshair meets the clump (the stalk you're aiming at), not a fixed spot.
--   * phones, low graphics and Potato Mode get fewer particles and no screen glow (brief: "never slow on phones").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local FxTex = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxTex"))
local UI = require(script.Parent.UI)
-- (28 Oct) the auto tools' jolt in your hands when they bite (client/AutoFeel)
local AutoFeel = require(script.Parent.AutoFeel)

local WeaponVfx = {}
local player = Players.LocalPlayer

local presets = ReplicatedStorage:WaitForChild("WeaponVfxPresets", 15)

-------------------------------------------------------------------------------------------------------------
-- quality
-------------------------------------------------------------------------------------------------------------
local isPhone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function graphicsLow(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and level ~= 0 and level <= 3
end
local lowCache, lowAt = false, -10
local function low(): boolean
	local now = os.clock()
	if now - lowAt > 2 then
		lowAt = now
		lowCache = isPhone or graphicsLow() or player:GetAttribute("Potato") == true
	end
	return lowCache
end
WeaponVfx.low = low

-- The most a burst authored `authored` studs across may be scaled to at `at` so it covers no more than `share` of the
-- view's height (28 Oct, tested in play: you stand right at a stalk, ~3 studs away, where the authored puff filled
-- two thirds of the screen; Chop A Forest's covers about a fifth). Far away it keeps its full size.
local function viewFit(at: Vector3, authored: number, share: number): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 1
	end
	local d = (cam.CFrame.Position - at).Magnitude
	local viewH = 2 * d * math.tan(math.rad(cam.FieldOfView) / 2)
	return viewH * share / authored
end
WeaponVfx.viewFit = viewFit

local function countFor(base: number): number
	if base <= 0 then
		return 0
	end
	return if low() then math.max(1, math.floor(base * 0.5 + 0.5)) else base
end

-------------------------------------------------------------------------------------------------------------
-- pooled emitter copies
-------------------------------------------------------------------------------------------------------------
type Slot = { a: Attachment, e: ParticleEmitter, color: ColorSequence, size: NumberSequence }
local pools: { [string]: { i: number, list: { Slot } } } = {}
local POOL_N = 3

local function slot(presetName: string, layer: Attachment): Slot?
	local key = presetName .. "/" .. layer.Name
	local p = pools[key]
	if not p then
		p = { i = 0, list = {} }
		for _ = 1, POOL_N do
			local a = layer:Clone()
			local e = a:FindFirstChildOfClass("ParticleEmitter")
			if not e then
				a:Destroy()
				return nil
			end
			a.Parent = workspace.Terrain
			table.insert(p.list, { a = a, e = e, color = e.Color, size = e.Size })
		end
		pools[key] = p
	end
	p.i = p.i % #p.list + 1
	return p.list[p.i]
end

local function lighter(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 0.92), k)
end

local function tintSeq(base: ColorSequence, grass: Color3?, tg: number, mut: Color3?, tm: number): ColorSequence
	if tg >= 1 and grass then
		-- the clump's own greens: a lighter blade turning to the grass colour
		local top = lighter(grass, 0.28)
		if mut and tm > 0 then
			top = top:Lerp(mut, tm)
			grass = grass:Lerp(mut, tm)
		end
		return ColorSequence.new(top, grass :: Color3)
	end
	if (tg <= 0 or not grass) and (tm <= 0 or not mut) then
		return base
	end
	local keys = {}
	for _, k in base.Keypoints do
		local c = k.Value
		if grass and tg > 0 then
			c = c:Lerp(lighter(grass, 0.3), tg)
		end
		if mut and tm > 0 then
			c = c:Lerp(lighter(mut, 0.15), tm)
		end
		table.insert(keys, ColorSequenceKeypoint.new(k.Time, c))
	end
	return ColorSequence.new(keys)
end

local sizeCache: { [NumberSequence]: { [number]: NumberSequence } } = {}
local function scaleSeq(base: NumberSequence, k: number): NumberSequence
	k = math.floor(k * 10 + 0.5) / 10
	if k == 1 then
		return base
	end
	local byK = sizeCache[base]
	if not byK then
		byK = {}
		sizeCache[base] = byK
	end
	local s = byK[k]
	if not s then
		local keys = {}
		for _, kp in base.Keypoints do
			table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
		end
		s = NumberSequence.new(keys)
		byK[k] = s
	end
	return s
end

export type BurstOpts = { grass: Color3?, mut: Color3?, scale: number?, finisher: boolean?, countMul: number?, upCf: CFrame?, swingCf: CFrame?, lite: boolean?, rot: { [string]: number }? }

-- Emit every layer of a preset at `cf` (particles fly along its +Y). Layers that need a finisher or a mutated clump
-- only show then; optional ones are dropped on phones and low graphics. `lite`: someone else's hit, only the layers
-- marked Lite (the puff, a few blades). `rot`: a layer's particle angle for this burst, by layer name (a snip's cut
-- line lies along the snip).
function WeaponVfx.burst(presetName: string, cf: CFrame, o: BurstOpts)
	local preset = presets and presets:FindFirstChild(presetName)
	if not preset then
		return
	end
	-- (28 Oct, tested in play: a layer's ZOffset pulls it toward the camera to stay in front of the clump, but right
	-- up against a stalk it pulled the reveal's glow ball behind the camera and it vanished: never past 0.7 studs
	-- short of the camera)
	local cam = workspace.CurrentCamera
	local maxZ = if cam then math.max(0, (cam.CFrame.Position - cf.Position).Magnitude - 0.7) else 99
	for _, layer in preset:GetChildren() do
		if not layer:IsA("Attachment") then
			continue
		end
		local e0 = layer:FindFirstChildOfClass("ParticleEmitter")
		if not e0 then
			continue
		end
		if e0:GetAttribute("Finisher") and not o.finisher then
			continue
		end
		if e0:GetAttribute("Mutated") and not o.mut then
			continue
		end
		if e0:GetAttribute("Optional") and low() then
			continue
		end
		if o.lite and not e0:GetAttribute("Lite") then
			continue
		end
		local s = slot(presetName, layer)
		if not s then
			continue
		end
		-- (a layer with Aim = "up" flies up and out toward you instead of straight at you; Aim = "swing" flies the way
		-- the blade went)
		local aim = e0:GetAttribute("Aim")
		local base = if aim == "up" and o.upCf then o.upCf elseif aim == "swing" and o.swingCf then o.swingCf else cf
		s.a.WorldCFrame = base * layer.CFrame
		s.e.Color = tintSeq(s.color, o.grass, e0:GetAttribute("TintGrass") :: number? or 0, o.mut, e0:GetAttribute("TintMut") :: number? or 0)
		s.e.Size = if e0:GetAttribute("ScaleWithClump") then scaleSeq(s.size, o.scale or 1) else s.size
		s.e.ZOffset = math.min(e0.ZOffset, maxZ)
		local r = o.rot and o.rot[layer.Name]
		s.e.Rotation = if r then NumberRange.new(r, r) else e0.Rotation
		local n = math.floor(countFor(e0:GetAttribute("EmitCount") :: number? or 1) * (o.countMul or 1) + 0.5)
		local delay = e0:GetAttribute("EmitDelay") :: number? or 0
		if n > 0 then
			if delay > 0 then
				task.delay(delay, function()
					s.e:Emit(n)
				end)
			else
				s.e:Emit(n)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- where the blow lands: the crosshair's ray against the clump's stalk (the notch is carved there too), else the
-- old "contact" spot on its near side
-------------------------------------------------------------------------------------------------------------
function WeaponVfx.impact(m: Model?, foot: Vector3, ground: number, fallback: Vector3): (Vector3, Vector3)
	local cam = workspace.CurrentCamera
	if not cam then
		return fallback, Vector3.yAxis
	end
	local o = cam.CFrame.Position
	local toCam = (o - fallback)
	toCam = if toCam.Magnitude > 1e-3 then toCam.Unit else Vector3.zAxis
	if not m then
		return fallback, toCam
	end
	local stalk = m:GetAttribute("Stalk") :: number? or ((m:GetAttribute("Radius") :: number? or 1.6) * 0.45)
	local h = m:GetAttribute("Height") :: number? or 6
	local d = cam.CFrame.LookVector
	local ox, oz = o.X - foot.X, o.Z - foot.Z
	local r = stalk * 1.1
	local a = d.X * d.X + d.Z * d.Z
	local b = 2 * (ox * d.X + oz * d.Z)
	local c = ox * ox + oz * oz - r * r
	local disc = b * b - 4 * a * c
	if a > 1e-6 and disc >= 0 then
		local t = (-b - math.sqrt(disc)) / (2 * a)
		if t > 0.5 and t < 30 then
			local p = o + d * t
			if p.Y >= ground + 0.3 and p.Y <= ground + h * 0.8 then
				local n = Vector3.new(p.X - foot.X, 0, p.Z - foot.Z)
				n = if n.Magnitude > 1e-3 then n.Unit else toCam
				return p + n * 0.15, (o - p).Unit
			end
		end
	end
	return fallback, toCam
end

-------------------------------------------------------------------------------------------------------------
-- chunky bits that fly at the camera (Chop A Forest's wood chips; ours are voxel grass): out of the blow, spinning,
-- sailing just past your face and gone before they could clip into the view. Pooled parts, one updater.
-------------------------------------------------------------------------------------------------------------
local bitsFolder = Instance.new("Folder")
bitsFolder.Name = "WeaponVfxBits"
bitsFolder.Parent = workspace

type Bit = { part: Part, from: Vector3, to: Vector3, lift: number, life: number, born: number, spin: Vector3, rot: CFrame, size: Vector3, toCam: boolean }
local freeBits: { Part } = {}
local liveBits: { Bit } = {}
local BIT_MAX = 36

local function newBit(): Part
	local p = table.remove(freeBits)
	if p then
		return p
	end
	p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

-- `tones`: the clump's colours; `glow`: a mutated clump's colour (neon bits); `scatter`: none fly at the camera (a
-- burst away from you, like a felled top landing)
function WeaponVfx.bits(from: Vector3, tones: { Color3 }, count: number, size: number, glow: Color3?, speed: number?, scatter: boolean?)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local n = countFor(count)
	local c = cam.CFrame
	for i = 1, n do
		if #liveBits >= BIT_MAX then
			break
		end
		local p = newBit()
		p.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Color = if glow then glow:Lerp(Color3.new(1, 1, 1), rand(0, 0.35)) else tones[math.random(1, #tones)]
		local s = rand(0.34, 0.6) * size
		local sz = Vector3.new(s, s * rand(0.75, 1), s * rand(0.8, 1.15))
		p.Size = sz
		p.Transparency = 0
		local rot = CFrame.Angles(rand(0, 6.28), rand(0, 6.28), rand(0, 6.28))
		p.CFrame = CFrame.new(from) * rot
		p.Parent = bitsFolder
		-- every other bit flies past the camera, the rest scatter out to the sides and drop
		local toCam = i % 3 ~= 0 and not scatter
		local side = if i % 2 == 0 then 1 else -1
		local to
		if toCam then
			to = c.Position + c.RightVector * side * rand(1.2, 2.6) + c.UpVector * rand(-1.3, 1.0) + c.LookVector * rand(0.5, 1.4)
		else
			local out = (c.Position - from)
			out = Vector3.new(out.X, 0, out.Z).Unit
			local across = out:Cross(Vector3.yAxis)
			to = from + across * side * rand(2.5, 4.5) + out * rand(0.5, 2) + Vector3.new(0, -rand(0.5, 1.5), 0)
		end
		table.insert(liveBits, {
			part = p,
			from = from,
			to = to,
			lift = rand(0.6, 2.0),
			life = rand(0.26, 0.38) * (speed or 1) * (if toCam then 1 else 1.6),
			born = os.clock(),
			spin = Vector3.new(rand(-13, 13), rand(-13, 13), rand(-13, 13)),
			rot = rot,
			size = sz,
			toCam = toCam,
		})
	end
end

RunService.RenderStepped:Connect(function()
	if #liveBits == 0 then
		return
	end
	local now = os.clock()
	for i = #liveBits, 1, -1 do
		local b = liveBits[i]
		local age = now - b.born
		local k = age / b.life
		if k >= 1 or not b.part.Parent then
			b.part.Parent = nil
			table.insert(freeBits, b.part)
			table.remove(liveBits, i)
			continue
		end
		-- fast out of the clump, easing as it passes you
		local e = 1 - (1 - k) * (1 - k)
		local pos = b.from:Lerp(b.to, e) + Vector3.new(0, math.sin(k * math.pi) * b.lift, 0)
		b.part.CFrame = CFrame.new(pos) * b.rot * CFrame.Angles(b.spin.X * age, b.spin.Y * age, b.spin.Z * age)
		b.part.Size = b.size * (1 - 0.35 * k)
		b.part.Transparency = if k > 0.72 then (k - 0.72) / 0.28 else 0
	end
end)

-------------------------------------------------------------------------------------------------------------
-- the screen glow of a golden moment (soft: a wash of the colour, never a white-out; skipped on phones)
-------------------------------------------------------------------------------------------------------------
local washGui = Instance.new("Frame")
washGui.Name = "RevealWash"
washGui.BackgroundTransparency = 1
washGui.Size = UDim2.fromScale(1, 1)
washGui.ZIndex = 4
washGui.Parent = UI.gui

function WeaponVfx.wash(at: Vector3, color: Color3, strength: number)
	if low() then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local sp, on = cam:WorldToViewportPoint(at)
	local vs = cam.ViewportSize
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = FxTex.glow
	img.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25)
	img.ImageTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = if on then UDim2.fromOffset(sp.X, sp.Y) else UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromOffset(vs.Y * 1.1, vs.Y * 1.1)
	img.ZIndex = 4
	img.Parent = washGui
	local peak = 1 - 0.5 * math.clamp(strength, 0, 1) -- at most half opaque
	TweenService:Create(img, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageTransparency = peak, Size = UDim2.fromOffset(vs.Y * 2.2, vs.Y * 2.2) }):Play()
	task.delay(0.12, function()
		TweenService:Create(img, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { ImageTransparency = 1, Size = UDim2.fromOffset(vs.Y * 2.8, vs.Y * 2.8) }):Play()
	end)
	task.delay(0.95, function()
		img:Destroy()
	end)
	-- the scene's own bloom swells and settles
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom and not bloom:GetAttribute("Swelling") then
		bloom:SetAttribute("Swelling", true)
		local i0, s0 = bloom.Intensity, bloom.Size
		TweenService:Create(bloom, TweenInfo.new(0.1), { Intensity = i0 + 0.6 * strength, Size = s0 + 16 * strength }):Play()
		task.delay(0.12, function()
			local t = TweenService:Create(bloom, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Intensity = i0, Size = s0 })
			t:Play()
			t.Completed:Wait()
			bloom:SetAttribute("Swelling", nil)
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the hits
-------------------------------------------------------------------------------------------------------------
export type HitInfo = {
	pos: Vector3, -- the clump's foot
	ground: number,
	contact: Vector3, -- the old contact spot (fallback)
	grass: Color3,
	tones: { Color3 },
	clump: Model?,
	scale: number,
	finisher: boolean?,
	mut: Color3?,
	timber: boolean?, -- a felled top landing (client/Fx "fell")
	dir: Vector3?, -- the way it fell
	clip: string?, -- the swing's clip (client/ViewAnims), when it was one
}

-- (the last blow's spot: a reveal that follows it bursts where the fist landed, not at the clump's foot)
local lastHit: { foot: Vector3, at: Vector3, t: number }? = nil

-- Where your last blow on the clump standing at `foot` landed (nil if it wasn't just now).
function WeaponVfx.lastImpact(foot: Vector3, within: number?): Vector3?
	local h = lastHit
	if h and os.clock() - h.t < (within or 1.5) and Vector3.new(h.foot.X - foot.X, 0, h.foot.Z - foot.Z).Magnitude < 2.5 then
		return h.at
	end
	return nil
end

-- Bare hands (Chop A Forest's punch): a lumpy cream puff there at once with a bright core, chunky bits at the
-- camera, loose blades popping out and fluttering down, a faint flash; the finisher adds a shock ring and puffs
-- thrown round the blow and twice the bits.
local function punch(info: HitInfo): boolean
	local at, toCam = WeaponVfx.impact(info.clump, info.pos, info.ground, info.contact)
	lastHit = { foot = info.pos, at = at, t = os.clock() }
	local sc = math.clamp(info.scale, 1, 2) ^ 0.6
	-- (the puff covers about a fifth of the view however close you stand, a finisher's a bit more)
	local size = math.clamp(math.min(sc * (if info.finisher then 1.35 else 1), viewFit(at, 2.5, if info.finisher then 0.3 else 0.22)), 0.3, 2)
	-- the puff and flash sit just in front of the surface, facing you
	local face = CFrame.lookAt(at + toCam * 0.35, at + toCam * 2) * CFrame.Angles(-math.rad(90), 0, 0)
	-- blades pop out up and toward you, then flutter down
	local flat = Vector3.new(toCam.X, 0, toCam.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local upCf = CFrame.lookAt(at, at + flat) * CFrame.Angles(math.rad(-35), 0, 0)
	WeaponVfx.burst("Punch", face, { grass = info.grass, mut = info.mut, scale = size, finisher = info.finisher, upCf = upCf, countMul = if info.finisher then 1.6 else 1 })
	WeaponVfx.bits(at + toCam * 0.3, info.tones, if info.finisher then 6 else 3, math.min(sc, 1.2), info.mut)
	return true
end

-- Scissors (brief: "bright X glint, thin cut line across the stalk, confetti snippets"): the blades shut in a crisp X
-- of light where your crosshair meets the stalk, a thin bright line lies along the cut (a steep diagonal for the
-- second, rolled snip), fine snippets pop out and flutter down. No dust: it's a clean cut. The double-snip finisher
-- adds a little ring and more snippets.
local SNIP_TILT: { [string]: number } = { SnipA = -7, SnipB = -30, SnipDouble = -12 }
local function snip(info: HitInfo): boolean
	local at, toCam = WeaponVfx.impact(info.clump, info.pos, info.ground, info.contact)
	lastHit = { foot = info.pos, at = at, t = os.clock() }
	local sc = math.clamp(info.scale, 1, 2) ^ 0.5
	local size = math.clamp(math.min(sc * (if info.finisher then 1.3 else 1), viewFit(at, 2.2, if info.finisher then 0.3 else 0.24)), 0.3, 2)
	local face = CFrame.lookAt(at + toCam * 0.3, at + toCam * 2) * CFrame.Angles(-math.rad(90), 0, 0)
	local flat = Vector3.new(toCam.X, 0, toCam.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local upCf = CFrame.lookAt(at, at + flat) * CFrame.Angles(math.rad(-30), 0, 0)
	local tilt = (info.clip and SNIP_TILT[info.clip]) or -7
	WeaponVfx.burst("Snip", face, {
		grass = info.grass,
		mut = info.mut,
		scale = size,
		finisher = info.finisher,
		upCf = upCf,
		countMul = if info.finisher then 1.5 else 1,
		rot = { CutLine = 90 + tilt + rand(-3, 3), XGlint = 45 + rand(-10, 10) },
	})
	WeaponVfx.bits(at + toCam * 0.3, info.tones, if info.finisher then 3 else 1, math.min(sc, 1) * 0.7, info.mut)
	return true
end

-- Sickle (brief: "blades fan sideways + a dust puff at the bite"; the thin silver crescent is the blade's own trail,
-- client/ViewModel): a small dust puff and a soft glow where the blade bites, a thin bright streak lying along the cut,
-- and a fan of blades thrown out sideways the way the swing went (left for the forehand, right for the backhand, down
-- to the left for the high finisher), a couple of chunky bits. The finisher adds a ring and a burst of blades.
type SwingWay = { side: number, drop: number }
local SWEEP: { [string]: SwingWay } = {
	SweepF = { side = -1, drop = 0.08 },
	SweepB = { side = 1, drop = 0.08 },
	SweepX = { side = -1, drop = 0.75 },
}
-- (a blade's cut: the sickle's sweep, the scythe's reap) `authored` / `share`: the burst's authored size and the share of
-- the view it may cover up close (client/WeaponVfx viewFit); `bitsN`: chunky bits (a finisher gets two more)
local function bladeCut(info: HitInfo, presetName: string, ways: { [string]: SwingWay }, first: string, authored: number, share: number, bitsN: number): boolean
	local at, toCam = WeaponVfx.impact(info.clump, info.pos, info.ground, info.contact)
	lastHit = { foot = info.pos, at = at, t = os.clock() }
	local cam = workspace.CurrentCamera
	local sc = math.clamp(info.scale, 1, 2) ^ 0.5
	local size = math.clamp(math.min(sc * (if info.finisher then 1.3 else 1), viewFit(at, authored, if info.finisher then share * 1.35 else share)), 0.3, 2)
	local face = CFrame.lookAt(at + toCam * 0.3, at + toCam * 2) * CFrame.Angles(-math.rad(90), 0, 0)
	local sw = (info.clip and ways[info.clip]) or ways[first]
	-- the way the blade went: across the view (down too for the finisher), a little toward you
	local right = if cam then cam.CFrame.RightVector else Vector3.xAxis
	local up = if cam then cam.CFrame.UpVector else Vector3.yAxis
	local dir = (right * sw.side - up * sw.drop + toCam * 0.35).Unit
	local across = dir:Cross(toCam)
	across = if across.Magnitude > 1e-3 then across.Unit else up
	local swingCf = CFrame.fromMatrix(at + toCam * 0.25, across, dir) -- (particles fly along +Y)
	local flat = Vector3.new(toCam.X, 0, toCam.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local upCf = CFrame.lookAt(at, at + flat) * CFrame.Angles(math.rad(-35), 0, 0)
	-- the streak's angle on screen: along the swing (the spark texture stands upright at 0)
	local sx, sy = dir:Dot(right), dir:Dot(up)
	if sx < 0 then
		sx, sy = -sx, -sy
	end
	local streak = 90 - math.deg(math.atan2(sy, sx)) + rand(-4, 4)
	WeaponVfx.burst(presetName, face, {
		grass = info.grass,
		mut = info.mut,
		scale = size,
		finisher = info.finisher,
		upCf = upCf,
		swingCf = swingCf,
		countMul = if info.finisher then 1.5 else 1,
		rot = { Streak = streak },
	})
	WeaponVfx.bits(at + toCam * 0.3, info.tones, if info.finisher then bitsN + 2 else bitsN, math.min(sc, 1.1) * 0.8, info.mut)
	return true
end
local function sweep(info: HitInfo): boolean
	return bladeCut(info, "Sweep", SWEEP, "SweepF", 2.4, 0.22, 2)
end

-- Mega Scythe (brief: "a big wide two-handed reap; lavender magic petals theme rebuilt in high quality; heavy: a small
-- freeze on contact, a camera kick, a bigger burst"; the wide lavender sweep is the blade's own trail, client/ViewModel):
-- a bigger puff and a lavender glow at the cut, a long bright streak along the reap, a spray of blades and lavender
-- petals the way it went, magic sparkles. The finisher adds a ring and petals bursting all round.
local REAP: { [string]: SwingWay } = {
	ReapF = { side = -1, drop = 0.05 },
	ReapB = { side = 1, drop = 0.05 },
	ReapBig = { side = -1, drop = 0.8 },
}
local function reap(info: HitInfo): boolean
	return bladeCut(info, "Reap", REAP, "ReapF", 3.2, 0.28, 4)
end

-- A clump you felled, its top landing (owner's brief: "fall dust: medium, drifts away within ~0.6 s"; the clip's
-- sideways dust): low dust rolling out the way it fell, blades and a few leaves thrown up, chunky bits scattering
-- away along the ground. (The fallen top's white pop is HitFx's.) Other cuts (mowers, one-hit tufts) keep the old look.
local function cut(info: HitInfo): boolean
	if not info.timber then
		return false
	end
	local dir = info.dir or Vector3.zAxis
	local sc = math.clamp(info.scale, 1, 2.2)
	local foot = Vector3.new(info.pos.X, info.ground + 0.35, info.pos.Z)
	WeaponVfx.land(foot, dir, info.grass, sc)
	local d = Vector3.new(dir.X, 0, dir.Z)
	d = if d.Magnitude > 1e-3 then d.Unit else Vector3.zAxis
	local up = CFrame.lookAt(foot, foot + d + Vector3.new(0, 2.2, 0)) * CFrame.Angles(-math.rad(90), 0, 0)
	WeaponVfx.burst("Fall", up, { grass = info.grass, scale = math.clamp(math.min(sc ^ 0.5, viewFit(foot, 0.7, 0.09)), 0.35, 1.5), countMul = 0.6 })
	WeaponVfx.bits(foot + Vector3.new(0, 0.6, 0), info.tones, 4, sc ^ 0.6, info.mut, 1.2, true)
	return true
end

-- The auto tools (brief: "Push Mower: jolts when it chews a clump; Weed Whacker: kicks back on a hit; Laser Mower: hot
-- glowing cut, small sparks, a little bloom; mower clippings: bursts on contact"). Every clump in reach is bitten each
-- tick (Config.TICK), so a busy field asks for a dozen bursts at once: the first few of a tick get the full look, a
-- couple more a light one, the rest nothing (brief: "never slow on phones"); clumps behind you aren't drawn. Each bite
-- jolts the tool in your hands (client/AutoFeel), the first of a tick hardest.
type AutoLook = { preset: string, kind: string, authored: number, share: number, height: number, bits: number }
local AUTO: { [string]: AutoLook } = {
	autoPush = { preset = "Mow", kind = "push", authored = 2.4, share = 0.2, height = 0.45, bits = 1 },
	autoWhack = { preset = "Whack", kind = "whack", authored = 2.2, share = 0.18, height = 0.6, bits = 0 },
	autoLaser = { preset = "Zap", kind = "laser", authored = 2.3, share = 0.2, height = 0.75, bits = 0 },
}
local bites = { t = -10, n = 0 } -- (this tick's bites so far)
local function autoBite(event: string, info: HitInfo): boolean
	local a = AUTO[event]
	local now = os.clock()
	if now - bites.t > 0.18 then
		bites.t, bites.n = now, 0
	end
	bites.n += 1
	AutoFeel.chew(a.kind, if bites.n == 1 then 1 else 0.35)
	local cam = workspace.CurrentCamera
	local h = math.clamp(info.scale, 1, 2)
	local at = Vector3.new(info.pos.X, info.ground + a.height * h, info.pos.Z)
	if not cam or cam.CFrame.LookVector:Dot(at - cam.CFrame.Position) < 0 then
		return true -- (behind you)
	end
	local full = if low() then 2 else 3
	if bites.n > full + 2 then
		return true
	end
	local lite = bites.n > full
	local toCam = cam.CFrame.Position - at
	toCam = if toCam.Magnitude > 1e-3 then toCam.Unit else Vector3.zAxis
	local face = CFrame.lookAt(at + toCam * 0.3, at + toCam * 2) * CFrame.Angles(-math.rad(90), 0, 0)
	local flat = Vector3.new(toCam.X, 0, toCam.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local upCf = CFrame.lookAt(at, at + flat) * CFrame.Angles(math.rad(-52), 0, 0)
	local size = math.clamp(math.min(h ^ 0.5, viewFit(at, a.authored, a.share)), 0.3, 1.6)
	WeaponVfx.burst(a.preset, face, { grass = info.grass, mut = info.mut, scale = size, upCf = upCf, swingCf = upCf, lite = lite, countMul = if lite then 0.6 else 1 })
	if a.bits > 0 and not lite then
		WeaponVfx.bits(at + toCam * 0.25, info.tones, a.bits, 0.55, info.mut)
	end
	return true
end
local function autoPush(info: HitInfo): boolean
	return autoBite("autoPush", info)
end
local function autoWhack(info: HitInfo): boolean
	return autoBite("autoWhack", info)
end
local function autoLaser(info: HitInfo): boolean
	return autoBite("autoLaser", info)
end

local HANDLERS: { [string]: (HitInfo) -> boolean } = {
	punch = punch,
	snip = snip,
	sweep = sweep,
	reap = reap,
	cut = cut,
	autoPush = autoPush,
	autoWhack = autoWhack,
	autoLaser = autoLaser,
}

-- Draw `event` (a tool's hit) if this module owns it. Returns true when it did (HitFx then skips its old layers);
-- a handler can pass (false) on a case it leaves to the old look.
function WeaponVfx.hit(event: string, info: HitInfo): boolean
	local h = HANDLERS[event]
	if not h then
		return false
	end
	return h(info) ~= false
end

-- Someone else's hit near you (owner's brief: "other players see a lighter version of your effects"): the puff and
-- a few blades where their blow landed, facing you; no chips at your camera, no flash, no shake. Returns false for a
-- weapon not rebuilt here (client/Fx then plays its old look, which is lighter for others too).
local OTHER_PRESET: { [string]: string } = { punch = "Punch", snip = "Snip", sweep = "Sweep", reap = "Reap", autoPush = "Mow", autoWhack = "Whack", autoLaser = "Zap" }
function WeaponVfx.other(event: string, at: Vector3, grass: Color3, mut: Color3?, scale: number): boolean
	local presetName = OTHER_PRESET[event]
	if not presetName then
		return false
	end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - at).Magnitude > 90 then
		return true
	end
	local toCam = (cam.CFrame.Position - at).Unit
	local face = CFrame.lookAt(at + toCam * 0.35, at + toCam * 2) * CFrame.Angles(-math.rad(90), 0, 0)
	local flat = Vector3.new(toCam.X, 0, toCam.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local upCf = CFrame.lookAt(at, at + flat) * CFrame.Angles(math.rad(-35), 0, 0)
	local size = math.clamp(math.min(math.clamp(scale, 1, 2) ^ 0.6, viewFit(at, 2.5, 0.22)), 0.3, 2)
	WeaponVfx.burst(presetName, face, { grass = grass, mut = mut, scale = size, upCf = upCf, swingCf = upCf, countMul = 0.5, lite = true })
	return true
end

function WeaponVfx.owns(event: string): boolean
	return HANDLERS[event] ~= nil
end

-- The first hit on a mutated clump (the owner's GOLDEN! moment): a glow ball, a soft ring rolling out, star
-- sparkles and a slow glow over the screen, in the mutation's colour. `strong`: your own find, close by.
function WeaponVfx.reveal(at: Vector3, color: Color3, scale: number, strong: boolean)
	local cam = workspace.CurrentCamera
	local toCam = if cam then (cam.CFrame.Position - at).Unit else Vector3.zAxis
	local face = CFrame.lookAt(at + toCam * 0.5, at + toCam * 2) * CFrame.Angles(-math.rad(90), 0, 0)
	-- (up close the glow ball peaks at under half the view, never a white-out; the ring rolls on out past the edges)
	WeaponVfx.burst("Reveal", face, { mut = color, scale = math.clamp(math.min(math.clamp(scale, 1, 2) ^ 0.5, viewFit(face.Position, 6, 0.45)), 0.2, 2) })
	if strong then
		task.delay(0.06, WeaponVfx.wash, at, color, 1)
	end
end

-- (28 Oct) which auto tool is in your hands (its bite kind), if one is
local AUTO_KIND: { [string]: string } = { PushMower = "push", WeedWhacker = "whack", LaserMower = "laser" }
local function autoHeld(): string?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ToolId")
	return if type(id) == "string" then AUTO_KIND[id] else nil
end

-- A felled clump's top going over: blades and a few leaves burst out of it at `at`, flying along `dir` (up and over).
-- (client/Fx calls this for your own; an auto tool that brought it down jolts in your hands: client/AutoFeel)
-- (28 Oct, tested in play: a mower's tick kills most clumps outright, and a kill sends no hit, only the fall; the
-- laser mower kills everything it touches. So an auto tool's kill is its bite too: `foot`, where the clump stood,
-- gets the tool's look: the mower's clippings, the whacker's flecks, the laser's hot cut, sparks and bloom.)
local AUTO_EVENT: { [string]: string } = { push = "autoPush", whack = "autoWhack", laser = "autoLaser" }
function WeaponVfx.fall(at: Vector3, dir: Vector3, grass: Color3, scale: number, foot: Vector3?)
	local kind = autoHeld()
	if kind and foot then
		local info = { pos = foot, ground = foot.Y, contact = foot, grass = grass, tones = { grass, grass:Lerp(Color3.new(0, 0, 0), 0.25) }, scale = scale }
		autoBite(AUTO_EVENT[kind], info :: any)
	elseif kind then
		AutoFeel.chew(kind, 1)
	end
	local d = Vector3.new(dir.X, 0, dir.Z)
	d = if d.Magnitude > 1e-3 then d.Unit else Vector3.zAxis
	-- (28 Oct, tested in play: you stand ~3 studs from the stalk, so the burst starts on its far side and goes up and
	-- away the way the top falls, never back at you, each blade and leaf a small part of the view)
	local from = at + d * 0.8
	local cf = CFrame.lookAt(from, from + d + Vector3.new(0, 0.9, 0)) * CFrame.Angles(-math.rad(90), 0, 0)
	local size = math.clamp(math.min(math.clamp(scale, 1, 2) ^ 0.5, viewFit(from, 0.7, 0.09)), 0.35, 1.5)
	WeaponVfx.burst("Fall", cf, { grass = grass, scale = size, countMul = if size < 0.8 then 0.7 else 1 })
end

-- A gem popping out of the stump (owner's brief: "a gem pops up from the stump, spins and flies to the counter";
-- client/LootFx does the hop, spin and pickup): a star glint, a soft glow and a few sparkles in the gem's colour.
function WeaponVfx.gemPop(at: Vector3, color: Color3)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - at).Magnitude > 120 then
		return
	end
	local toCam = if cam then (cam.CFrame.Position - at).Unit else Vector3.zAxis
	local face = CFrame.lookAt(at + toCam * 0.4, at + toCam * 2) * CFrame.Angles(-math.rad(90), 0, 0)
	WeaponVfx.burst("GemPop", face, { mut = color, scale = math.clamp(viewFit(at, 3.2, 0.3), 0.3, 1) })
end

-- Where the top lands: low dust rolling out along the ground (`dir`: the way it fell), gone in ~0.6 s.
function WeaponVfx.land(at: Vector3, dir: Vector3, grass: Color3, scale: number)
	local d = Vector3.new(dir.X, 0, dir.Z)
	d = if d.Magnitude > 1e-3 then d.Unit else Vector3.zAxis
	local cf = CFrame.lookAt(at, at + d + Vector3.new(0, 0.35, 0)) * CFrame.Angles(-math.rad(90), 0, 0)
	WeaponVfx.burst("Land", cf, { grass = grass, scale = math.clamp(math.min(math.clamp(scale, 1, 2.2) ^ 0.6, viewFit(at, 3.2, 0.4)), 0.4, 2) })
end

return WeaponVfx
