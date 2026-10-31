-- AutoFeel: the auto tools in your hands, alive (owner's brief, 28 Oct: "Push Mower: push bob + engine rumble, jolts
-- when it chews a clump. Weed Whacker: side-to-side sweep, spinning head blur, kicks back on a hit. Laser Mower: clean
-- cyan sci-fi beam, hot glowing cut, small sparks, a little bloom. Mower clippings: bursts on contact plus a light
-- trickle while running").
--   * client/ViewModel asks for the motion every frame: push() for the mowers (the first-person copy rides on it),
--     whacker() for the weed whacker, spin() for its head.
--   * client/WeaponVfx calls chew() when your tool bites a clump (a hit, or one you bring down): a jolt through the
--     handle, a quick damped spring (peaks in ~60 ms, settles in ~0.3 s with one small rebound), never a shake.
--   * dress() adds the first-person extras to a mower copy: the grass trickle from under the deck while you mow, the
--     laser's light curtain and glow.
-- Everything is smooth sums of sines and a spring: no random jitter (the old buzz flickered at the frame rate).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FxTex = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxTex"))

local AutoFeel = {}
local player = Players.LocalPlayer
local isPhone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-------------------------------------------------------------------------------------------------------------
-- the chew: a damped spring kicked by each bite (x: pitch degrees, y: lift studs, z: back toward you studs;
-- w: a little yaw rattle for the whacker)
-------------------------------------------------------------------------------------------------------------
local K, C = 400, 22 -- stiffness, damping: a peak 0.024 per unit of kick at ~60 ms, settled in ~0.32 s
local pos = Vector3.zero
local vel = Vector3.zero
local yaw, yawVel = 0, 0
local lastChew = -10
local lastStep = os.clock()

-- the kick per tool, as the peak it reaches (divided by the spring's 0.024 response)
local KICK: { [string]: Vector3 } = {
	push = Vector3.new(2.6, 0.03, 0.045), -- the deck bucks a little, the bar shoves back into your hands
	whack = Vector3.new(5, 0.02, 0.07), -- the head kicks up and back off the clump
	laser = Vector3.new(0.6, 0.004, 0.015), -- a soft pulse: it slices, it doesn't chew
}

-- Your tool bit a clump (`kind`: push / whack / laser). Several bites in the same instant add up a little, never into
-- a rattle.
function AutoFeel.chew(kind: string, strength: number?)
	local now = os.clock()
	local s = strength or 1
	if now - lastChew < 0.06 then
		s *= 0.3
	end
	lastChew = now
	local k = KICK[kind] or KICK.push
	vel += (k / 0.024) * s * (0.9 + math.random() * 0.2)
	if kind == "whack" then
		yawVel += (if math.random() < 0.5 then -1 else 1) * (1.6 / 0.024) * s
	end
end

-- Did your tool bite something in the last `within` seconds (the grass trickle runs while it does)?
function AutoFeel.mowing(within: number?): boolean
	return os.clock() - lastChew < (within or 1.2)
end

local function stepSpring()
	local now = os.clock()
	local dt = math.min(0.1, now - lastStep)
	lastStep = now
	local n = math.max(1, math.ceil(dt * 240))
	local h = dt / n
	for _ = 1, n do
		vel += (-pos * K - vel * C) * h
		pos += vel * h
		yawVel += (-yaw * K - yawVel * C) * h
		yaw += yawVel * h
	end
end

local function chewCf(): CFrame
	return CFrame.new(0, pos.Y, pos.Z) * CFrame.Angles(math.rad(pos.X), math.rad(yaw), 0)
end

-------------------------------------------------------------------------------------------------------------
-- the mowers
-------------------------------------------------------------------------------------------------------------
-- The push mower's (and the laser mower's) motion at its grip, in the grip's own frame (x right, y up, z back):
-- `t` the clock, `walk` 0..1.4 how fast you go, `step` your step phase (client/ViewModel's), `laser` for the hover.
--   push mower: the engine's rumble (two fast sines a few hundredths of a stud, never a flicker), a push bob with your
--     steps (a dip and a shove forward on each, the deck rocking side to side), an idle sway when you stand.
--   laser mower: it hovers: a slow smooth float, a faint hum, a little lean forward as you go, no rock.
function AutoFeel.push(t: number, walk: number, step: number, laser: boolean): CFrame
	stepSpring()
	local w = math.clamp(walk, 0, 1.2)
	if laser then
		local float = math.sin(t * 2 * math.pi * 0.9) * 0.022 + math.sin(t * 2 * math.pi * 0.37 + 1.3) * 0.012
		local hum = math.sin(t * 2 * math.pi * 9.5) * 0.0025
		local lean = math.rad(-2.2) * w -- the nose dips a touch as it glides on
		local sway = math.sin(t * 2 * math.pi * 0.45) * math.rad(0.6)
		return CFrame.new(0, float + hum, 0) * CFrame.Angles(lean, 0, sway) * chewCf()
	end
	-- the engine: louder shaking while it cuts
	local load = if AutoFeel.mowing(0.35) then 1.6 else 1
	local r1 = math.sin(t * 2 * math.pi * 13.3) * 0.006 * load
	local r2 = math.sin(t * 2 * math.pi * 8.7 + 0.8) * 0.004 * load
	local rr = math.sin(t * 2 * math.pi * 11.1 + 2.1) * math.rad(0.35) * load
	-- the push: on each step the bar dips and shoves forward, the deck rocks from wheel to wheel
	local dip = -math.abs(math.sin(step)) * 0.05 * w
	local shove = -math.max(0, math.sin(step * 2 - 0.6)) * 0.035 * w
	local rock = math.sin(step) * math.rad(1.6) * w
	local nod = math.sin(step * 2 + 0.4) * math.rad(0.9) * w
	-- standing: the idling engine sways it a little
	local idle = (1 - math.min(1, w * 3)) * math.sin(t * 2 * math.pi * 0.8) * math.rad(0.5)
	return CFrame.new(r2, r1 + dip, shove) * CFrame.Angles(nod + rr, idle * 0.5, rock + idle) * chewCf()
end

-------------------------------------------------------------------------------------------------------------
-- the weed whacker
-------------------------------------------------------------------------------------------------------------
local sweepAmp = 0.6
local sweepPhase = 0
local lastWhack = os.clock()
-- The weed whacker's sweep, at the rear grip in its own frame: side to side about your hands like working an edge
-- (a slow sine, wider and a bit quicker as you walk), the head dipping at the ends of each pass and the shaft rolling
-- into it, plus the kick off a clump.
function AutoFeel.whacker(t: number, walk: number): CFrame
	stepSpring()
	local now = os.clock()
	local dt = math.min(0.1, now - lastWhack)
	lastWhack = now
	local w = math.clamp(walk, 0, 1.2)
	local amp = 0.62 + 0.38 * math.min(1, w)
	sweepAmp += (amp - sweepAmp) * math.min(1, dt * 3)
	sweepPhase += dt * 2 * math.pi * (0.78 + 0.12 * math.min(1, w))
	local s = math.sin(sweepPhase)
	local swing = math.rad(28) * sweepAmp * s
	local dip = math.rad(3.5) * sweepAmp * (s * s) -- the head sinks at the ends of a pass
	local roll = -math.rad(7) * sweepAmp * s
	-- the motor's buzz in the handle
	local buzz = math.sin(t * 2 * math.pi * 15.7) * math.rad(0.25)
	return CFrame.Angles(-dip + buzz, swing, roll) * chewCf()
end

-- How far the whacker's head has spun (radians): fast enough to read as a blur, not so fast it strobes backwards
-- at 60 frames a second (about a third of a turn a frame: 2 blades, so it looks continuous).
function AutoFeel.spin(t: number): number
	return t * 37
end

-------------------------------------------------------------------------------------------------------------
-- first-person extras on a mower copy (client/ViewModel's local copy of the mower you push)
-------------------------------------------------------------------------------------------------------------
type Dressing = { trickles: { ParticleEmitter }, curtain: { BasePart }, glow: PointLight? }
local dressed: { [Model]: Dressing } = setmetatable({}, { __mode = "k" }) :: any

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- `m`: the copy, already scaled (its parts' "VT" attribute is the transparency client/ViewModel shows them at);
-- `laser`: the laser mower.
function AutoFeel.dress(m: Model, laser: boolean)
	if dressed[m] then
		return
	end
	local d: Dressing = { trickles = {}, curtain = {} }
	dressed[m] = d
	local cf, size = m:GetBoundingBox()
	local piv = m:GetPivot()
	local centre = piv:PointToObjectSpace(cf.Position)
	local sc = m:GetScale()
	local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	-- the grass trickle: bits flicking out from under the back of the deck on both sides while you mow
	local low = centre.Y - size.Y / 2 + 0.25 * sc
	for _, side in { -1, 1 } do
		local a = Instance.new("Attachment")
		a.Name = "Trickle"
		a.CFrame = anchor.CFrame:ToObjectSpace(piv * CFrame.new(centre.X + side * size.X * 0.42, low, centre.Z + size.Z * 0.12) * CFrame.Angles(0, 0, math.rad(-62 * side)))
		a.Parent = anchor
		local e = emitter(a, {
			Name = "Trickle",
			Texture = FxTex.blade,
			Rate = 0,
			Lifetime = NumberRange.new(0.35, 0.6),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16 * sc / 0.42), NumberSequenceKeypoint.new(0.8, 0.13 * sc / 0.42), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Color3.fromRGB(150, 214, 96), Color3.fromRGB(86, 158, 58)),
			LightInfluence = 0.6,
			Speed = NumberRange.new(2.2, 3.6),
			SpreadAngle = Vector2.new(28, 22),
			Acceleration = Vector3.new(0, -9, 0),
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-260, 260),
			EmissionDirection = Enum.NormalId.Top,
			LockedToPart = false,
		})
		e:SetAttribute("Share", if side == 1 then 1 else 0.6) -- (the right side, nearer your hand, a bit busier)
		table.insert(d.trickles, e)
	end
	if laser then
		-- the light curtain under the front bar down to the grass, a glowing line where it meets it, a cyan light
		local bar: BasePart? = nil
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon and p.Size.X > 2 * sc and p.Size.Y < 0.2 * sc then
				bar = p
			end
		end
		if bar then
			local barRel = piv:PointToObjectSpace(bar.Position)
			local height = math.max(0.06 * sc, barRel.Y - (centre.Y - size.Y / 2))
			local function sheet(name: string, sz: Vector3, at: Vector3, transp: number, color: Color3)
				local p = Instance.new("Part")
				p.Name = name
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Material = Enum.Material.Neon
				p.Color = color
				p.Size = sz
				p.Transparency = transp
				p.CFrame = piv * CFrame.new(at)
				p:SetAttribute("VT", transp)
				p:SetAttribute("Base", transp)
				p.Parent = m
				table.insert(d.curtain, p)
				return p
			end
			sheet("LaserCurtain", Vector3.new(bar.Size.X * 0.98, height, 0.02 * sc), barRel - Vector3.new(0, height / 2, 0), 0.62, Color3.fromRGB(120, 245, 255))
			sheet("LaserLine", Vector3.new(bar.Size.X * 1.02, 0.03 * sc, 0.09 * sc), Vector3.new(barRel.X, barRel.Y - height + 0.02 * sc, barRel.Z), 0.15, Color3.fromRGB(215, 255, 255))
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(90, 230, 255)
			l.Range = 6 * sc / 0.42
			l.Brightness = 1.2
			l.Shadows = false
			l.Parent = bar
			d.glow = l
		end
	end
end

-- Every frame for the copy you push: the trickle runs while you mow (and walk), the laser curtain shimmers and
-- flares on each slice.
function AutoFeel.tend(m: Model, t: number, walk: number, laser: boolean)
	local d = dressed[m]
	if not d then
		return
	end
	local mowingNow = AutoFeel.mowing(0.9) and walk > 0.08
	local rate = if mowingNow then (if isPhone or player:GetAttribute("Potato") then 7 else 14) else 0
	for _, e in d.trickles do
		e.Rate = rate * (e:GetAttribute("Share") :: number? or 1)
	end
	if laser then
		local flare = math.max(0, 1 - (os.clock() - lastChew) / 0.18)
		local shimmer = 0.04 * math.sin(t * 2 * math.pi * 6.3) + 0.03 * math.sin(t * 2 * math.pi * 2.1 + 1)
		for _, p in d.curtain do
			local base = p:GetAttribute("Base") :: number? or 0.6
			local v = math.clamp(base + shimmer - flare * 0.3, 0, 1)
			p:SetAttribute("VT", v)
			p.Transparency = v
		end
		if d.glow then
			d.glow.Brightness = 1.1 + 0.25 * math.sin(t * 2 * math.pi * 1.7) + flare * 1.6
		end
	end
end

return AutoFeel
