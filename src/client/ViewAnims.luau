-- ViewAnims: the first-person hands' swings as real keyframed animation (owner, 28 Oct: "make these animations look
-- organic and high quality", brief: "snappy but weighty, alternating combo with a finisher, breathing + fidgets, a
-- tiny hit-stop on every hit"). Built on fwjelaa's animation method (FWJ STUDIOS): key poses, an ease that shapes
-- the move FROM a key to the next, accelerate into contact and stop hard on it, overshoot 8-15 % and settle, ease
-- only on the way out, arcs through 3+ keys, overlap (the body leads, the hands follow), moving holds, never frozen.
--
-- Channels (offsets from the rest pose, in ViewModel's design units, camera space: x right, y up, z back):
--   R / L  the right / left hand: p (position), r (pitch, yaw, roll degrees), b (where the elbow points: a direction
--          the forearm runs back along, its length 0..1 = how much it overrides the straight arm), roll (the fist
--          turning about the forearm, degrees)
--   B      the body: the whole view model turns about the shoulders (r) and shifts (p)
--   T      the tool: its own extra turn (scissor blades opening in r.x, a spin in r.y ...); for other tools p lifts
--          it out of the hand and r turns it about its middle (a sickle tossed and caught)
-- A clip also carries `add` channels: reactions laid ON TOP of whatever that channel is doing (the guard hand
-- tucking in while the other one punches), so a hand's own recovery is never cut off.
--
-- client/ViewModel calls update(dt) every frame, then pose(channel); client/HitFx asks plan() when you swing, so
-- the predicted impact lands on the clip's contact frame. Everything runs on an animation clock that stops during
-- a hit-stop (the hands hang on the contact frame), so the freeze never changes the timing that follows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local State = require(script.Parent.State)

local ViewAnims = {}

local FPS = 60
local FADE = 7 -- frames a new clip takes to blend in over what a channel was doing (30 Oct: was 4, owner "smoother")

export type Pose = { p: Vector3, r: Vector3, b: Vector3, roll: number }
type Key = { f: number, ease: string, pose: Pose }
type Clip = {
	name: string,
	len: number, -- frames
	hit: number?, -- contact frame (the Hit marker)
	stop: number?, -- hit-stop on contact, frames
	chain: number, -- the frame from which the next swing can start without looking rushed (sets the speed-up)
	finisher: boolean?,
	main: string?, -- the channel that strikes (its contact frame is the hit)
	trail: { number }?, -- (28 Oct) frames {from, to} of the main channel's strike when a blade draws its trail
	ch: { [string]: { Key } },
	add: { [string]: { Key } }?,
	inspect: boolean?, -- (29 Oct) an inspect (Y): any swing, a tool switch or getting on a mower cancels it
	pivot: Vector3?, -- (inspects) what the I channel turns about, in studs from the camera
	sounds: { { any } }?, -- (inspects) { frame, Config.SOUNDS key, volume } played as the clip passes the frame
	airless: boolean?, -- (31 Oct) a swing at nothing sweeps straight through, without the hit-stop (ViewAnims.airSwing)
	letGo: boolean?, -- (31 Oct) the left hand lets go of a two-handed item: L's roll 0..100 (ViewAnims.letGo)
}

local ZERO: Pose = { p = Vector3.zero, r = Vector3.zero, b = Vector3.zero, roll = 0 }

-- P(x, y, z, pitch, yaw, roll, bend, fistRoll)
local function P(x: number?, y: number?, z: number?, rx: number?, ry: number?, rz: number?, b: Vector3?, roll: number?): Pose
	return { p = Vector3.new(x or 0, y or 0, z or 0), r = Vector3.new(rx or 0, ry or 0, rz or 0), b = b or Vector3.zero, roll = roll or 0 }
end

local function mirrorPose(p: Pose): Pose
	return { p = Vector3.new(-p.p.X, p.p.Y, p.p.Z), r = Vector3.new(p.r.X, -p.r.Y, -p.r.Z), b = Vector3.new(-p.b.X, p.b.Y, p.b.Z), roll = -p.roll }
end

-------------------------------------------------------------------------------------------------------------
-- easing: shapes the move from a key to the next (fwjelaa: "accelerate into contact, ease only on the way out")
-------------------------------------------------------------------------------------------------------------
local EASE: { [string]: (number) -> number } = {
	linear = function(u)
		return u
	end,
	hold = function(_)
		return 0
	end,
	["in"] = function(u)
		return u * u * u
	end,
	out = function(u)
		local v = 1 - u
		return 1 - v * v * v
	end,
	inout = function(u)
		return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2
	end,
	quadIn = function(u)
		return u * u
	end,
	quadOut = function(u)
		return 1 - (1 - u) * (1 - u)
	end,
	expoIn = function(u)
		return if u <= 0 then 0 else 2 ^ (10 * u - 10)
	end,
	expoOut = function(u)
		return if u >= 1 then 1 else 1 - 2 ^ (-10 * u)
	end,
	sine = function(u)
		return -(math.cos(math.pi * u) - 1) / 2
	end,
	backOut = function(u)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
	end,
}

-- Hermite through the keys with time-aware tangents (a Catmull-Rom that respects uneven key spacing), so a hand
-- travels in an arc through 3+ keys instead of a straight line from pose to pose. Monotone per axis (Fritsch-Carlson):
-- where the motion turns back (a wind-up, an overshoot) the curve stops dead on the key instead of wobbling past it.
local function tangent(a: number, b: number, c: number, ta: number, tb: number, tc: number, d: number): number
	-- the slope at b (per frame) scaled to the segment of `d` frames
	local s1 = (b - a) / math.max(1e-3, tb - ta)
	local s2 = (c - b) / math.max(1e-3, tc - tb)
	if s1 * s2 <= 0 then
		return 0 -- a turning point: stop on the key
	end
	local m = (b - a + c - b) / math.max(1e-3, tc - ta)
	local lim = 3 * math.min(math.abs(s1), math.abs(s2))
	if math.abs(m) > lim then
		m = math.sign(m) * lim
	end
	return m * d
end

local function spline(keys: { Key }, i: number, u: number, get: (Pose) -> Vector3): Vector3
	local k1, k2 = keys[i], keys[i + 1]
	local k0 = keys[i - 1]
	local k3 = keys[i + 2]
	local p1, p2 = get(k1.pose), get(k2.pose)
	local d = k2.f - k1.f
	local t1, t2
	if k0 then
		local p0 = get(k0.pose)
		t1 = Vector3.new(tangent(p0.X, p1.X, p2.X, k0.f, k1.f, k2.f, d), tangent(p0.Y, p1.Y, p2.Y, k0.f, k1.f, k2.f, d), tangent(p0.Z, p1.Z, p2.Z, k0.f, k1.f, k2.f, d))
	else
		t1 = Vector3.zero -- a clip starts from rest
	end
	if k3 then
		local p3 = get(k3.pose)
		t2 = Vector3.new(tangent(p1.X, p2.X, p3.X, k1.f, k2.f, k3.f, d), tangent(p1.Y, p2.Y, p3.Y, k1.f, k2.f, k3.f, d), tangent(p1.Z, p2.Z, p3.Z, k1.f, k2.f, k3.f, d))
	else
		t2 = Vector3.zero -- and ends at rest
	end
	local u2, u3 = u * u, u * u * u
	return p1 * (2 * u3 - 3 * u2 + 1) + t1 * (u3 - 2 * u2 + u) + p2 * (-2 * u3 + 3 * u2) + t2 * (u3 - u2)
end

local function getP(p: Pose): Vector3
	return p.p
end
-- (30 Oct, owner: "make the m1 animation smoother for each weapon") turns and bends ride the same smooth curve
-- through the keys as the moves (they were straight lines between keys, so a swing's turn changed speed with a jolt
-- at every key)
local function getR(p: Pose): Vector3
	return p.r
end
local function getB(p: Pose): Vector3
	return p.b
end

local function lerpPose(a: Pose, b: Pose, w: number): Pose
	return { p = a.p:Lerp(b.p, w), r = a.r:Lerp(b.r, w), b = a.b:Lerp(b.b, w), roll = a.roll + (b.roll - a.roll) * w }
end

local function addPose(a: Pose, b: Pose): Pose
	return { p = a.p + b.p, r = a.r + b.r, b = a.b + b.b, roll = a.roll + b.roll }
end

-- A channel's pose at frame t of its keys.
local function rawKeys(keys: { Key }, t: number): Pose
	local n = #keys
	if t <= keys[1].f then
		return keys[1].pose
	end
	if t >= keys[n].f then
		return keys[n].pose
	end
	local i = 1
	while i < n and keys[i + 1].f <= t do
		i += 1
	end
	local k1, k2 = keys[i], keys[i + 1]
	local u = (t - k1.f) / math.max(1e-3, k2.f - k1.f)
	local e = (EASE[k1.ease] or EASE.linear)(u)
	if k1.ease == "hold" then
		return k1.pose
	end
	return {
		p = spline(keys, i, e, getP),
		r = spline(keys, i, e, getR),
		b = spline(keys, i, e, getB),
		roll = k1.pose.roll + (k2.pose.roll - k1.pose.roll) * e,
	}
end

-- (30 Oct, owner: "make the m1 animation smoother for each weapon") every channel is read through a short soft
-- average (5 samples a frame apart, weights 1 4 6 4 1): the eased segments met at their keys with a jolt in speed,
-- which this rounds off without moving the timing (the contact frame stays the contact frame)
local SMOOTH = { { -2, 1 / 16 }, { -1, 4 / 16 }, { 0, 6 / 16 }, { 1, 4 / 16 }, { 2, 1 / 16 } }
local function sampleKeys(keys: { Key }, t: number): Pose
	local p, r, b, roll = Vector3.zero, Vector3.zero, Vector3.zero, 0
	for _, w in SMOOTH do
		local q = rawKeys(keys, t + w[1])
		p += q.p * w[2]
		r += q.r * w[2]
		b += q.b * w[2]
		roll += q.roll * w[2]
	end
	return { p = p, r = r, b = b, roll = roll }
end

-------------------------------------------------------------------------------------------------------------
-- clip building
-------------------------------------------------------------------------------------------------------------
-- keys: { {frame, ease, pose}, ... } (frames at 60 fps)
local function K(list: { any }): { Key }
	local out = {}
	for _, k in list do
		table.insert(out, { f = k[1], ease = k[2], pose = k[3] })
	end
	return out
end

local CLIPS: { [string]: Clip } = {}

local function define(c: Clip)
	CLIPS[c.name] = c
end

-- The left-hand twin of a right-hand clip: hands swapped, every pose mirrored, the body turning the other way.
local function mirrorClip(c: Clip, name: string): Clip
	local swap = { R = "L", L = "R", B = "B", T = "T" }
	local function mirrorSet(set: { [string]: { Key } }?): { [string]: { Key } }?
		if not set then
			return nil
		end
		local out = {}
		for chName, keys in set do
			local mk = {}
			for _, k in keys do
				table.insert(mk, { f = k.f, ease = k.ease, pose = mirrorPose(k.pose) })
			end
			out[swap[chName] or chName] = mk
		end
		return out
	end
	return {
		name = name,
		len = c.len,
		hit = c.hit,
		stop = c.stop,
		chain = c.chain,
		finisher = c.finisher,
		airless = c.airless,
		main = c.main and swap[c.main],
		ch = mirrorSet(c.ch) :: { [string]: { Key } },
		add = mirrorSet(c.add),
	}
end

-------------------------------------------------------------------------------------------------------------
-- BARE HANDS (owner's brief: left-right jabs, a hook / uppercut finisher every 4th hit with a bigger burst, a small
-- camera kick and a short freeze; a soft white smear on the fast frames). Reference: Chop A Forest's punches (the
-- fist snaps from the bottom corner up toward the middle of the view in 3-4 frames, holds, drifts back).
-- Snappy M1 timing (fwjelaa cheat sheet): wind-up 2-3 f, strike 3 f, hold 3, recover ~18 -> 27 f clips; the hook
-- and uppercut: wind-up 5 + a moving 3 f telegraph, strike 4 f, hit-stop 6 f, recover ~30 f.
-------------------------------------------------------------------------------------------------------------
-- (positions are added to REST_R; the fist's screen spot at contact is about 58 % across, 60 % down: Chop's)
define({
	name = "JabR",
	main = "R",
	len = 27,
	hit = 5,
	stop = 2,
	chain = 19,
	ch = {
		R = K({
			{ 0, "out", P() },
			{ 2, "quadIn", P(0.16, -0.2, 0.42, -12, -8, 6, nil, 4) }, -- cock it: back, down, wrist turned in
			{ 5, "linear", P(-1.12, 1.52, -1.72, 14, 16, -26, nil, -24) }, -- contact: the corkscrew lands
			{ 7, "out", P(-1.22, 1.63, -1.86, 16, 18, -30, nil, -28) }, -- overshoot ~8 %
			{ 11, "inout", P(-1.08, 1.47, -1.64, 12, 15, -25, nil, -23) }, -- settle, starting back
			{ 18, "inout", P(-0.46, 0.58, -0.62, 5, 6, -10, nil, -8) }, -- coming home lower than it went out (an arc)
			{ 27, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 2, "in", P(0.02, -0.02, 0.04, 0, -1.6, -0.6) }, -- the shoulders coil right
			{ 5, "linear", P(-0.04, 0, -0.1, -0.8, 3.2, 1.2) }, -- and turn into the punch
			{ 8, "out", P(-0.05, 0, -0.12, -1, 3.8, 1.4) },
			{ 15, "inout", P(-0.02, 0, -0.05, -0.4, 1.8, 0.6) },
			{ 27, "linear", P() },
		}),
	},
	add = {
		-- the other fist tucks in toward the chin as the body turns
		L = K({
			{ 0, "out", P() },
			{ 5, "out", P(0.12, 0.16, 0.34, -6, 0, 4) },
			{ 13, "inout", P(0.1, 0.13, 0.28, -5, 0, 3) },
			{ 27, "linear", P() },
		}),
	},
})
CLIPS.JabL = mirrorClip(CLIPS.JabR, "JabL")

-- The right hook: wind out and up with the elbow high, a held coil, then the fist sweeps flat across the view with
-- the forearm level (elbow out to the right) and the body unwinding behind it.
define({
	name = "HookR",
	main = "R",
	len = 48,
	hit = 13,
	stop = 6,
	chain = 26,
	finisher = true,
	ch = {
		R = K({
			{ 0, "out", P() },
			-- wind up at the right edge where you can see it: fist by the temple, elbow lifted out to the side
			{ 6, "linear", P(0.3, 1.5, 0.3, -6, -30, 30, Vector3.new(0.55, -0.55, 0.6), 10) },
			{ 9, "in", P(0.42, 1.6, 0.38, -6, -36, 34, Vector3.new(0.6, -0.5, 0.6), 12) }, -- a moving hold (the telegraph)
			{ 11, "linear", P(-0.9, 1.75, -0.9, 2, 10, -40, Vector3.new(1, -0.1, 0.35), -40) }, -- sweeping across
			{ 13, "linear", P(-1.9, 1.6, -1.3, 6, 46, -74, Vector3.new(1, 0, 0.12), -68) }, -- contact: forearm level
			{ 15, "out", P(-2.3, 1.52, -1.18, 4, 54, -82, Vector3.new(1, 0, 0.1), -74) }, -- carried through
			{ 22, "inout", P(-2.1, 1.4, -1.12, 4, 46, -72, Vector3.new(0.9, 0, 0.2), -66) },
			{ 33, "inout", P(-0.9, 0.55, -0.45, 0, 12, -18, Vector3.new(0.3, 0, 0.1), -16) },
			{ 48, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 6, "linear", P(0.1, -0.04, 0.1, 0.5, -6.5, -2) },
			{ 9, "in", P(0.12, -0.05, 0.12, 0.6, -7.5, -2.4) },
			{ 13, "linear", P(-0.1, 0, -0.16, -1.6, 6, 3) },
			{ 16, "out", P(-0.12, 0, -0.18, -1.8, 8, 3.4) },
			{ 25, "inout", P(-0.06, 0, -0.1, -0.9, 4, 1.8) },
			{ 48, "linear", P() },
		}),
	},
	add = {
		L = K({
			{ 0, "out", P() },
			{ 6, "out", P(-0.08, 0.08, 0.2, -3, 0, -2) },
			{ 13, "out", P(0.22, 0.24, 0.42, -8, 0, 6) },
			{ 25, "inout", P(0.18, 0.2, 0.36, -6, 0, 5) },
			{ 48, "linear", P() },
		}),
	},
})

-- The right uppercut: sink and drop the fist low by the hip (elbow down), a held coil, then the fist rises up the
-- middle with the forearm upright and the body rising behind it.
define({
	name = "UpperR",
	main = "R",
	len = 48,
	hit = 13,
	stop = 6,
	chain = 26,
	finisher = true,
	ch = {
		R = K({
			{ 0, "out", P() },
			-- sink: the fist drops low toward the middle, elbow down (it dips out of view and comes back up)
			{ 6, "linear", P(-0.35, -0.38, 0.2, 18, -8, 8, Vector3.new(0.2, -1, 0.2) * 0.75, 18) },
			{ 9, "in", P(-0.4, -0.45, 0.24, 20, -9, 10, Vector3.new(0.2, -1, 0.2) * 0.8, 20) }, -- telegraph
			{ 11, "linear", P(-1.15, 0.9, -0.75, -14, 9, -10, Vector3.new(0.12, -1, 0.25).Unit, 30) }, -- rising
			{ 13, "linear", P(-1.55, 2.3, -1.4, -38, 14, -16, Vector3.new(0.1, -1, 0.3).Unit, 40) }, -- contact, forearm up
			{ 15, "out", P(-1.6, 2.62, -1.35, -46, 15, -18, Vector3.new(0.1, -1, 0.3).Unit, 42) }, -- carried up
			{ 22, "inout", P(-1.55, 2.42, -1.32, -40, 14, -16, Vector3.new(0.1, -1, 0.3).Unit * 0.9, 38) },
			{ 34, "inout", P(-0.6, 0.75, -0.42, -10, 5, -5, Vector3.new(0.05, -1, 0.2) * 0.3, 10) },
			{ 48, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 6, "linear", P(0.04, -0.16, 0.06, 2.6, -4, -1.2) }, -- sink
			{ 9, "in", P(0.05, -0.18, 0.07, 3, -4.6, -1.4) },
			{ 13, "linear", P(-0.05, 0.14, -0.12, -3.2, 5, 1.6) }, -- rise into it
			{ 16, "out", P(-0.06, 0.18, -0.14, -3.8, 5.6, 1.8) },
			{ 26, "inout", P(-0.03, 0.08, -0.06, -1.6, 2.6, 0.8) },
			{ 48, "linear", P() },
		}),
	},
	add = {
		L = K({
			{ 0, "out", P() },
			{ 13, "out", P(0.2, 0.22, 0.38, -7, 0, 5) },
			{ 26, "inout", P(0.16, 0.18, 0.32, -5, 0, 4) },
			{ 48, "linear", P() },
		}),
	},
})

-- Fidgets while you stand around (brief: "flex the fists").
define({
	name = "FlexHands", -- both fists come up and in, clench twice (a quick roll), then settle back down
	len = 72,
	chain = 72,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 14, "out", P(-0.42, 0.62, -0.12, 0, 10, -12, nil, -22) },
			{ 18, "inout", P(-0.44, 0.64, -0.1, 0, 12, -14, nil, -36) },
			{ 22, "inout", P(-0.42, 0.62, -0.12, 0, 10, -12, nil, -20) },
			{ 26, "inout", P(-0.44, 0.65, -0.1, 0, 12, -14, nil, -38) },
			{ 30, "inout", P(-0.42, 0.62, -0.12, 0, 10, -12, nil, -22) },
			{ 46, "inout", P(-0.38, 0.56, -0.1, 0, 9, -11, nil, -18) }, -- a moving hold
			{ 72, "linear", P() },
		}),
		L = K({
			{ 0, "inout", P() },
			{ 15, "out", P(0.4, 0.58, -0.1, 0, -10, 12, nil, 22) },
			{ 19, "inout", P(0.42, 0.6, -0.08, 0, -12, 14, nil, 36) },
			{ 23, "inout", P(0.4, 0.58, -0.1, 0, -10, 12, nil, 20) },
			{ 27, "inout", P(0.42, 0.61, -0.08, 0, -12, 14, nil, 38) },
			{ 31, "inout", P(0.4, 0.58, -0.1, 0, -10, 12, nil, 22) },
			{ 47, "inout", P(0.36, 0.52, -0.08, 0, -9, 11, nil, 18) },
			{ 72, "linear", P() },
		}),
		B = K({
			{ 0, "inout", P() },
			{ 16, "inout", P(0, -0.02, 0, 1.6, 0, 0) },
			{ 46, "inout", P(0, -0.02, 0, 1.2, 0, 0) },
			{ 72, "linear", P() },
		}),
	},
})

define({
	name = "BounceHands", -- a boxer's bounce: the fists bob twice and a small shadow jab with each hand
	len = 64,
	chain = 64,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 8, "inout", P(-0.1, 0.28, -0.05, 0, 0, -4) },
			{ 16, "inout", P(0, 0.06, 0, 0, 0, 0) },
			{ 22, "in", P(0.06, 0.1, 0.12, -4, 0, 2) },
			{ 26, "out", P(-0.6, 0.7, -0.9, 6, 8, -14, nil, -14) }, -- a little shadow jab
			{ 34, "inout", P(-0.08, 0.2, -0.05, 0, 0, -3) },
			{ 46, "inout", P(0, 0.08, 0, 0, 0, 0) },
			{ 64, "linear", P() },
		}),
		L = K({
			{ 0, "inout", P() },
			{ 9, "inout", P(0.1, 0.26, -0.05, 0, 0, 4) },
			{ 17, "inout", P(0, 0.05, 0, 0, 0, 0) },
			{ 36, "in", P(-0.06, 0.1, 0.12, -4, 0, -2) },
			{ 40, "out", P(0.6, 0.68, -0.88, 6, -8, 14, nil, 14) },
			{ 48, "inout", P(0.08, 0.18, -0.05, 0, 0, 3) },
			{ 64, "linear", P() },
		}),
		B = K({
			{ 0, "inout", P() },
			{ 8, "inout", P(0, 0.05, 0, 0, 0, 0) },
			{ 16, "inout", P(0, -0.03, 0, 0, 0, 0) },
			{ 26, "out", P(0, 0, -0.04, 0, 1.6, 0.6) },
			{ 40, "out", P(0, 0, -0.04, 0, -1.6, -0.6) },
			{ 64, "linear", P() },
		}),
	},
})

-------------------------------------------------------------------------------------------------------------
-- SCISSORS (owner's brief: "quick snip-snips (thrust in, blades visibly open and close, pull back), fastest
-- weapon"; fidget: "spin the scissors"). The T channel is the scissors themselves: r.X = how far the blades are
-- open (degrees, 0 = shut), r.Y = a twirl about the finger. Every snip opens wide on the way in and slams shut on the
-- contact frame; the hand thrusts at the crosshair (the blade tips reach it) and pulls back.
-------------------------------------------------------------------------------------------------------------
local function OPEN(deg: number, spin: number?): Pose
	return P(0, 0, 0, deg, spin or 0, 0)
end

define({
	name = "SnipA",
	main = "R",
	len = 22,
	hit = 6,
	stop = 2,
	chain = 15,
	ch = {
		R = K({
			{ 0, "out", P() },
			{ 3, "quadIn", P(0.12, -0.14, 0.3, -6, -3, 3) }, -- cock it back a touch
			{ 6, "linear", P(-0.19, 1.2, -1.02, -2, 18, -10) }, -- thrust in: the tips at the crosshair (tuned 28 Oct, wire capture)
			{ 8, "out", P(-0.24, 1.26, -1.12, -3, 20, -11) }, -- carries a little past
			{ 12, "inout", P(-0.16, 1.13, -0.95, -2, 15, -9) }, -- settle
			{ 22, "linear", P() },
		}),
		T = K({
			{ 0, "out", OPEN(0) },
			{ 3, "linear", OPEN(40) }, -- open wide on the way in
			{ 5, "in", OPEN(46) },
			{ 6, "out", OPEN(0) }, -- SNIP: shut on the contact frame
			{ 22, "linear", OPEN(0) },
		}),
		B = K({
			{ 0, "out", P() },
			{ 3, "in", P(0.01, -0.01, 0.03, 0, -0.8, -0.3) },
			{ 6, "linear", P(-0.02, 0, -0.06, -0.6, 1.6, 0.5) },
			{ 10, "out", P(-0.025, 0, -0.07, -0.7, 1.9, 0.6) },
			{ 22, "linear", P() },
		}),
	},
	add = {
		L = K({
			{ 0, "out", P() },
			{ 6, "out", P(0.05, 0.08, 0.15, -3, 0, 2) },
			{ 22, "linear", P() },
		}),
	},
})

define({
	name = "SnipB", -- the second snip: lower, with the wrist rolled, a diagonal cut
	main = "R",
	len = 22,
	hit = 6,
	stop = 2,
	chain = 15,
	ch = {
		R = K({
			{ 0, "out", P() },
			{ 3, "quadIn", P(0.16, -0.06, 0.3, -4, -4, 10, nil, 6) },
			{ 6, "linear", P(-0.41, 1.02, -1.0, -4, 12, 22, nil, 18) },
			{ 8, "out", P(-0.47, 1.06, -1.1, -5, 14, 25, nil, 20) },
			{ 12, "inout", P(-0.37, 0.98, -0.92, -4, 10, 20, nil, 16) },
			{ 22, "linear", P() },
		}),
		T = K({
			{ 0, "out", OPEN(0) },
			{ 3, "linear", OPEN(38) },
			{ 5, "in", OPEN(44) },
			{ 6, "out", OPEN(0) },
			{ 22, "linear", OPEN(0) },
		}),
		B = K({
			{ 0, "out", P() },
			{ 3, "in", P(0.01, -0.01, 0.03, 0.3, -1, -0.5) },
			{ 6, "linear", P(-0.02, -0.01, -0.06, -0.4, 2, 1) },
			{ 10, "out", P(-0.025, -0.01, -0.07, -0.5, 2.3, 1.2) },
			{ 22, "linear", P() },
		}),
	},
	add = {
		L = K({
			{ 0, "out", P() },
			{ 6, "out", P(0.06, 0.06, 0.14, -3, 0, 2) },
			{ 22, "linear", P() },
		}),
	},
})

define({
	name = "SnipDouble", -- the finisher: snip-SNIP, the second one deeper, held a beat
	main = "R",
	len = 36,
	hit = 13,
	stop = 5,
	chain = 24,
	finisher = true,
	ch = {
		R = K({
			{ 0, "out", P() },
			{ 4, "quadIn", P(0.15, -0.12, 0.32, -6, -4, 4) },
			{ 7, "linear", P(-0.29, 0.72, -0.85, -3, 12, -8) }, -- the first snip, half way in
			{ 9, "inout", P(-0.21, 0.62, -0.66, -2, 9, -6) }, -- re-cock without going home
			{ 13, "linear", P(-0.11, 1.31, -1.26, -4, 16, -10) }, -- the second, deeper: contact
			{ 16, "out", P(-0.18, 1.36, -1.36, -5, 18, -11) },
			{ 24, "inout", P(-0.05, 1.21, -1.1, -3, 13, -8) },
			{ 36, "linear", P() },
		}),
		T = K({
			{ 0, "out", OPEN(0) },
			{ 4, "linear", OPEN(42) },
			{ 6, "in", OPEN(46) },
			{ 7, "out", OPEN(0) }, -- snip
			{ 9, "linear", OPEN(42) },
			{ 12, "in", OPEN(50) },
			{ 13, "out", OPEN(0) }, -- SNIP
			{ 36, "linear", OPEN(0) },
		}),
		B = K({
			{ 0, "out", P() },
			{ 4, "in", P(0.01, -0.01, 0.04, 0.2, -1, -0.4) },
			{ 7, "linear", P(-0.01, 0, -0.04, -0.4, 1, 0.3) },
			{ 13, "linear", P(-0.04, 0, -0.1, -1, 2.6, 0.9) },
			{ 17, "out", P(-0.045, 0, -0.11, -1.1, 2.9, 1) },
			{ 36, "linear", P() },
		}),
	},
	add = {
		L = K({
			{ 0, "out", P() },
			{ 13, "out", P(0.08, 0.1, 0.2, -4, 0, 3) },
			{ 36, "linear", P() },
		}),
	},
})

-- Fidgets: a twirl round the finger, and a couple of snips at the air.
define({
	name = "SpinScissors",
	len = 54,
	chain = 54,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 8, "out", P(-0.12, 0.3, 0.05, -8, 4, -4) },
			{ 32, "inout", P(-0.14, 0.32, 0.04, -8, 4, -4) },
			{ 54, "linear", P() },
		}),
		T = K({
			{ 0, "inout", OPEN(0, 0) },
			{ 8, "inout", OPEN(0, 0) },
			{ 32, "out", OPEN(0, 360) }, -- one full turn about the finger, slowing as it comes round
			{ 54, "linear", OPEN(0, 360) },
		}),
	},
})

define({
	name = "SnipAir",
	len = 44,
	chain = 44,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 8, "out", P(-0.2, 0.32, -0.15, -6, 4, -3) },
			{ 30, "inout", P(-0.18, 0.3, -0.12, -6, 4, -3) },
			{ 44, "linear", P() },
		}),
		T = K({
			{ 0, "inout", OPEN(0) },
			{ 10, "out", OPEN(30) },
			{ 14, "in", OPEN(0) },
			{ 19, "out", OPEN(28) },
			{ 23, "in", OPEN(0) },
			{ 44, "linear", OPEN(0) },
		}),
	},
})

-------------------------------------------------------------------------------------------------------------
-- SICKLE (owner's brief: "forehand / backhand flat sweeps; a thin silver crescent trail that fades fast; blades fan
-- sideways + a dust puff at the bite"; fidget: "toss the sickle"). The swings are flat and fast: the hand winds out to
-- one side with the wrist turned back, a moving hold (the telegraph), then whips across the view so the curved blade
-- passes through the crosshair on the contact frame and carries well through. The backhand turns the wrist over so
-- the hook leads the other way. The finisher is a high diagonal: raised over the shoulder, a held coil, then down
-- through the stalk to the lower left. `trail`: the frames client/ViewModel draws the blade's crescent on.
-------------------------------------------------------------------------------------------------------------
define({
	name = "SweepF", -- forehand: right to left
	main = "R",
	len = 32,
	hit = 9,
	stop = 3,
	chain = 22,
	trail = { 6, 13 },
	ch = {
		-- (tuned 28 Oct with wire captures of the uploaded sickle, whose blade curls up out of the handle: the wrist
		-- rolls ~70-80 so the hook leads to the left, and the blade's back passes the crosshair on the contact frame)
		R = K({
			{ 0, "out", P() },
			{ 4, "linear", P(1.05, 0.43, 0.45, 8, -48, 62) }, -- wound out to the right, the blade turned back
			{ 6, "in", P(1.15, 0.48, 0.5, 8, -53, 66) }, -- a moving hold, then it goes: accelerate into the cut
			{ 8, "linear", P(0.6, 0.63, -0.85, 2, -29, 74) }, -- whipping across
			{ 9, "linear", P(0.2, 0.95, -1.05, 0, -9, 78) }, -- contact: the blade through the crosshair
			{ 11, "out", P(-0.5, 1.35, -0.85, 14, 26, 80) }, -- carried through to the left, level
			{ 13, "inout", P(-0.85, 1.3, -0.75, 18, 36, 80) },
			{ 20, "inout", P(-0.75, 1.15, -0.65, 14, 32, 78) }, -- a moving hang
			{ 32, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 4, "linear", P(0.06, -0.01, 0.06, 0.4, -5, -1.4) }, -- the shoulders coil right
			{ 6, "in", P(0.07, -0.01, 0.07, 0.5, -5.6, -1.6) },
			{ 9, "linear", P(-0.08, 0, -0.1, -0.8, 5, 1.8) }, -- and unwind into the cut
			{ 13, "out", P(-0.1, 0, -0.12, -1, 6.4, 2.2) },
			{ 32, "linear", P() },
		}),
	},
	add = {
		L = K({
			{ 0, "out", P() },
			{ 6, "out", P(0.1, 0.08, 0.2, -4, 0, 3) },
			{ 12, "inout", P(-0.08, 0.04, 0.1, -2, 0, -2) },
			{ 32, "linear", P() },
		}),
	},
})

define({
	name = "SweepB", -- backhand: left to right, the wrist turned over so the hook leads to the right
	main = "R",
	len = 32,
	hit = 9,
	stop = 3,
	chain = 22,
	trail = { 6, 13 },
	ch = {
		R = K({
			{ 0, "out", P() },
			{ 4, "linear", P(-1.45, 1.37, -0.2, 6, 88, -62) }, -- across to the middle, the blade cocked to the left
			{ 6, "in", P(-1.55, 1.52, -0.18, 6, 91, -66) },
			{ 8, "linear", P(-1.0, 1.3, -0.85, 2, 81, -74) },
			{ 9, "linear", P(-0.6, 1.18, -1.05, 0, 70, -78) }, -- contact
			{ 11, "out", P(0.05, 1.35, -0.85, 14, -26, -80) }, -- whipped through to the right
			{ 13, "inout", P(0.35, 1.3, -0.75, 18, -36, -80) },
			{ 20, "inout", P(0.3, 1.15, -0.65, 14, -32, -78) },
			{ 32, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 4, "linear", P(-0.06, -0.01, 0.06, 0.4, 5, 1.4) },
			{ 6, "in", P(-0.07, -0.01, 0.07, 0.5, 5.6, 1.6) },
			{ 9, "linear", P(0.08, 0, -0.1, -0.8, -5, -1.8) },
			{ 13, "out", P(0.1, 0, -0.12, -1, -6.4, -2.2) },
			{ 32, "linear", P() },
		}),
	},
	add = {
		-- the free hand drops out of the way of the arm crossing over
		L = K({
			{ 0, "out", P() },
			{ 4, "out", P(0.18, -0.12, 0.3, -5, 0, 4) },
			{ 12, "inout", P(0.05, -0.04, 0.12, -2, 0, 1) },
			{ 32, "linear", P() },
		}),
	},
})

define({
	name = "SweepX", -- the finisher: a high diagonal down through the stalk
	main = "R",
	len = 46,
	hit = 13,
	stop = 5,
	chain = 26,
	finisher = true,
	trail = { 10, 17 },
	ch = {
		R = K({
			{ 0, "out", P() },
			{ 6, "linear", P(0.55, 1.7, 0.35, 38, -40, 100) }, -- raised high on the right, the blade over the shoulder
			{ 10, "in", P(0.62, 1.82, 0.4, 42, -44, 108) }, -- the coil, held (the telegraph)
			{ 12, "linear", P(0.75, 2.15, -0.6, 18, -14, 118) },
			{ 13, "linear", P(0.89, 2.18, -1.15, -4, 18, 135) }, -- contact: the hook down through the crosshair
			{ 16, "out", P(-1.36, 1.56, -0.95, -30, 44, 140) }, -- carried down to the lower left
			{ 24, "inout", P(-1.65, 1.68, -0.9, -26, 40, 136) },
			{ 46, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 6, "linear", P(0.08, 0.04, 0.1, -1.5, -6, -2) },
			{ 10, "in", P(0.09, 0.05, 0.11, -1.8, -7, -2.4) },
			{ 13, "linear", P(-0.1, -0.06, -0.16, 2.6, 6, 2.6) },
			{ 16, "out", P(-0.12, -0.08, -0.18, 3.2, 7.5, 3) },
			{ 25, "inout", P(-0.06, -0.04, -0.1, 1.6, 4, 1.6) },
			{ 46, "linear", P() },
		}),
	},
	add = {
		L = K({
			{ 0, "out", P() },
			{ 6, "out", P(-0.06, 0.06, 0.15, -3, 0, -2) },
			{ 13, "out", P(0.2, 0.18, 0.36, -7, 0, 5) },
			{ 25, "inout", P(0.16, 0.15, 0.3, -5, 0, 4) },
			{ 46, "linear", P() },
		}),
	},
})

-- Fidgets: a toss and catch (the sickle flips once in the air: the T channel lifts and turns it about its middle),
-- and a look along the blade with a flick to shake the grass off.
define({
	name = "TossSickle",
	len = 60,
	chain = 60,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 10, "inout", P(0.02, -0.18, 0.05, -6, 0, 0) }, -- dip
			{ 14, "out", P(0, 0.32, -0.08, -14, 0, 0) }, -- flick up: let go
			{ 22, "inout", P(0, 0.14, 0, -4, 0, 0) },
			{ 36, "in", P(0, 0.1, 0, -2, 0, 0) },
			{ 40, "out", P(0.02, -0.2, 0.06, 6, 0, 0) }, -- the catch: the hand gives with the weight
			{ 48, "inout", P(0, 0.04, 0, -1, 0, 0) },
			{ 60, "linear", P() },
		}),
		T = K({
			{ 0, "linear", P() },
			{ 14, "out", P() }, -- leaves the hand at the top of the flick
			{ 27, "in", P(0, 1.7, 0.15, -180, 0, 0) }, -- rising, slowing, half a turn
			{ 40, "linear", P(0, 0, 0, -360, 0, 0) }, -- falling back into the hand
			{ 60, "linear", P(0, 0, 0, -360, 0, 0) },
		}),
	},
})

define({
	name = "CheckBlade",
	len = 64,
	chain = 64,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 14, "out", P(-0.55, 0.55, 0.3, 8, 28, -72) }, -- turned to look along the blade
			{ 22, "inout", P(-0.58, 0.6, 0.28, 6, 32, -78) },
			{ 38, "inout", P(-0.52, 0.56, 0.3, 10, 26, -70) }, -- a moving hold
			{ 44, "in", P(-0.3, 0.42, 0.12, 4, 12, -30) },
			{ 47, "out", P(0.1, 0.2, -0.12, -12, -14, 14) }, -- a flick to shake the grass off
			{ 64, "linear", P() },
		}),
	},
})

-------------------------------------------------------------------------------------------------------------
-- MEGA SCYTHE (owner's brief: "a big wide two-handed reap (~180 deg) with a slow heavy wind-up; lavender magic petals;
-- heavy: a small freeze on contact, a camera kick, a bigger burst"). Rebuilt 28 Oct from wire captures: the scythe's
-- blade hooks right over its shaft, so a reap that pointed the shaft at the view showed the blade edge-on (a stick with
-- no blade). Now the grip hand (R) lowers the scythe to the swing's height and the body (B) carries the whole arch
-- across the view FACE-ON (the crescent and its glowing inner edge always readable): a quick pull back to one side and
-- a slow heavy load into the coil, a moving hold, then the reap along a smooth arc through the crosshair (the blade's
-- mid-edge exactly on it at the contact frame) and out to the other side with an overshoot. The strike's keys are
-- sampled every 2 frames from a parabola through the contact (so the blade's trail draws one clean curve, never a kink)
-- with a time warp that puts the top speed on the contact frame. The forehand and the return reap draw a shallow smile;
-- the finisher a rainbow diagonal from high over the right shoulder down to the lower left. The other fist rides the
-- shaft (client/ViewModel).
-------------------------------------------------------------------------------------------------------------
-- (30 Oct, owner: "it's like holding a knife the wrong way") with the blade standing out from the shaft's end (server/
-- PartModels/tool_scythe) the reaps are carried by the body TURNING (yaw), like a real mower's stroke, not banking
-- (roll): every B key below is the 28 Oct key with x * 0.6, y * 0.3, pitch * 0.5, yaw * 2.7, roll * 0.25 (the
-- finisher x * 0.5, y and z * 0.75, yaw * 2.2, roll * 0.33), so the timing and the arcs stay as they were tuned
-- but the fists stay low and the blade sweeps flat and face-on across the view.
-- (30 Oct, owner: "fix this animation", Rivals-style grip in client/ViewModel) with the fists in the middle, the
-- keys out on the LEFT (yaw > 0) are the keys above with x, yaw and roll * 0.75 and the body leaning in (z - 0.018 *
-- yaw): turned the full way, the blade swung within a third of a stud of the camera and filled the screen.
-- (30 Oct, the snath now across both fists) and the keys out on the RIGHT (yaw < 0, all three reaps) are the keys
-- above with x * 0.5, pitch * 0.7, yaw and roll * 0.6 and the body leaning in (z - 0.03 * |yaw|): pulled the whole way
-- back, the snath's butt end swung through the camera.
-- (30 Oct, owner: "copy the position and angle of the scythe in the arms and also the animations + the inspect
-- animation", Rivals' Bat Scythe / Cryo Scythe, youtube.com/shorts/LEhSHMiq9cE, studied frame by frame) Rivals' scythe
-- swings are quick flat reaps that leave the view: the scythe drops out of sight to one side, the snath swings up
-- pointing ahead, the blade sweeps flat across through the crosshair and is gone off the other side, and a beat later
-- it comes back up into the rest. Here the R channel carries the whole scythe (client/ViewModel: the right fist moves,
-- in studs / DIST, and the scythe turns about it in camera axes: a yaw sweeps the head across, a pitch lifts it ahead,
-- a roll tips it), B adds a little body turn, T spins the blade round the snath. The keys before these (28-30 Oct)
-- are in the project doc.
-- forehand, right to left (Rivals' second swing): whipped down out of sight and up on the right, the blade spun
-- round its snath (T) so it leads, then reaped flat across the view to the left and gone
define({
	name = "ReapF",
	main = "R",
	len = 60,
	hit = 17,
	-- (31 Oct, owner: "make the scythe's m1 smoother") a shorter hit-stop (was 7), none at all on a swing at nothing,
	-- and the dip out of sight eased in over 4 frames, not dropped 3 studs in 3 (from rest it jumped 60 % of the way
	-- in its first frame)
	stop = 4,
	airless = true,
	chain = 34,
	trail = { 13, 22 },
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 4, "linear", P(0.35, -2.5, 0.3, -32, -32, -10) },
			{ 7, "linear", P(0.8, -2, 0.3, -12, -86, -14) },
			{ 9, "out", P(0.65, -0.75, 0.15, 8, -106, -12) },
			{ 12, "linear", P(0.62, -0.55, 0.12, 10, -112, -12) },
			{ 14, "linear", P(0.45, -0.2, 0, 16, -90, -6) },
			{ 17, "linear", P(0, 0, -0.05, 20, -45) },
			{ 20, "linear", P(-0.45, -0.1, 0, 16, -5, 6) },
			{ 23, "out", P(-0.95, -0.7, 0.1, 6, 35, 14) },
			{ 40, "inout", P(-1, -0.8, 0.1, 5, 38, 14) },
			{ 60, "linear", P() },
		}),
		T = K({
			{ 0, "linear", P() },
			{ 2, "inout", P() },
			{ 6, "inout", P(0, 0, 0, 0, 0, 180) },
			{ 40, "inout", P(0, 0, 0, 0, 0, 180) },
			{ 52, "inout", P() },
			{ 60, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 12, "inout", P(0, 0, 0, 0, -6, -2) },
			{ 17, "linear", P() },
			{ 23, "out", P(0, 0, 0, 0, 8, 2) },
			{ 40, "inout", P(0, 0, 0, 0, 8, 2) },
			{ 60, "linear", P() },
		}),
	},
})

-- the return, left to right (Rivals' first swing): dropped out of sight to the lower left, then the snath swings up
-- pointing ahead and the blade sweeps flat through the crosshair and out of the view to the right
define({
	name = "ReapB",
	main = "R",
	len = 56,
	hit = 15,
	stop = 3, -- (31 Oct, smoother: was 5, and none on a swing at nothing; the dip eases in from rest)
	airless = true,
	chain = 30,
	trail = { 11, 20 },
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 5, "inout", P(-0.6, -1.4, 0.3, 0, 30, 20) },
			{ 9, "linear", P(-0.65, -1.2, 0.3, 2, 32, 20) },
			{ 12, "linear", P(-0.35, -0.15, 0.05, 14, -5, 6) },
			{ 15, "linear", P(0, 0, -0.05, 20, -45) },
			{ 18, "linear", P(0.45, -0.1, 0, 16, -90, -5) },
			{ 21, "out", P(0.95, -0.7, 0.1, 6, -135, -10) },
			{ 36, "inout", P(1, -0.8, 0.1, 5, -138, -10) },
			{ 56, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 9, "inout", P(0, 0, 0, 0, 6, 2) },
			{ 15, "linear", P() },
			{ 21, "out", P(0, 0, 0, 0, -8, -2) },
			{ 36, "inout", P(0, 0, 0, 0, -8, -2) },
			{ 56, "linear", P() },
		}),
	},
})

-- the finisher: heaved up high on the left, the blade's face to you, then chopped down through the crosshair and out
-- to the lower right
define({
	name = "ReapBig",
	main = "R",
	len = 72,
	hit = 26,
	stop = 5, -- (31 Oct, smoother: was 9, and none on a swing at nothing)
	airless = true,
	chain = 40,
	finisher = true,
	trail = { 21, 31 },
	ch = {
		R = K({
			{ 0, "out", P() },
			{ 10, "inout", P(-0.5, -0.6, 0.2, 35, -10, -25) },
			{ 18, "linear", P(-0.55, -0.55, 0.22, 40, -12, -28) },
			{ 21, "linear", P(-0.55, -0.55, 0.22, 41, -12, -29) },
			{ 22, "linear", P(-0.45, -0.35, 0.1, 38, -22, -18) },
			{ 24, "linear", P(-0.2, -0.15, 0, 30, -40, -5) },
			{ 26, "linear", P(0.05, -0.1, -0.05, 18, -55, 5) },
			{ 28, "linear", P(0.35, -0.3, 0, 0, -75, 10) },
			{ 31, "out", P(0.9, -1.2, 0.15, -20, -110, 10) },
			{ 48, "inout", P(0.95, -1.3, 0.15, -21, -112, 10) },
			{ 72, "linear", P() },
		}),
		B = K({
			{ 0, "out", P() },
			{ 18, "inout", P(0, 0.05, 0.05, 4, 4) },
			{ 22, "linear", P(0, 0.06, 0.05, 5, 5) },
			{ 26, "linear", P() },
			{ 31, "out", P(0, -0.05, 0, -5, -8, -2) },
			{ 48, "inout", P(0, -0.05, 0, -5, -8, -2) },
			{ 72, "linear", P() },
		}),
	},
})

-- Fidget: a twirl, the scythe spun once round its own shaft (T turns it about its middle).
define({
	name = "ScytheTwirl",
	len = 70,
	chain = 70,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 10, "out", P(0, 0.15, 0, -6, 0, 0) },
			{ 50, "inout", P(0, 0.15, 0, -6, 0, 0) },
			{ 70, "linear", P() },
		}),
		T = K({
			{ 0, "linear", P() },
			{ 10, "inout", P() },
			{ 50, "linear", P(0, 0, 0, 0, 0, 360) },
			{ 70, "linear", P(0, 0, 0, 0, 0, 360) },
		}),
	},
})

-------------------------------------------------------------------------------------------------------------
-- INSPECT (owner, 29 Oct: "make an inspect animation for every weapon ... Keybind Y on pc and a small button on mobile
-- ... scissors could have an inspect animation of a butterfly knife from CSGO ... make it so you can spam the
-- animation"). Built like CS2's inspects: the item comes up into the middle of the view, turns to show one face, a
-- moving hold (it never freezes), rolls over to show the other, then drops home with a little weight. The I channel
-- moves the whole first-person rig (hands and item together) about the clip's `pivot`, so it works for every item,
-- keyframed or not; R / L / T add each item's own flourish on top. Pressing Y again restarts it at once; a swing, a
-- tool switch or getting on a mower cancels it (client/Inspect, client/ViewModel).
-------------------------------------------------------------------------------------------------------------
-- Scissors: a butterfly-knife show. Brought up, two quick flips (the shears spin round the finger, blades flaring
-- open and snapping shut each half turn), a look along the side with the fist rolled, then two more flips and home.
-- (30 Oct, owner: "make the scissors inspect slower, look at CS:GO knife inspects, copy the butterfly knife one",
-- studied off CS2's butterfly inspect) CS's butterfly: brought up to the middle-right, three fast flips round the
-- fingers, then it settles OPEN, its handles splayed round the hand, and the hand turns it slowly to admire the blade
-- for about two seconds; then two flips snap it shut and it drops home. Here the shears' blades stand in for the
-- handles: open wide through the admiring hold, the fist rolled over to show the side.
define({
	name = "InspectScissors",
	inspect = true,
	-- a swish as each flip goes round, a click as the shears snap shut
	-- (30 Oct, owner: "it's about how fast the scissors spin, that has to be slowed down") each half turn now takes 18
	-- frames (0.3 s, about CS2's butterfly flips), was 6 frames at 1.33x (~4x as fast); four half turns up front, two to
	-- close
	sounds = {
		{ 27, "swingBlade", 0.12 },
		{ 45, "swingBlade", 0.12 },
		{ 63, "swingBlade", 0.12 },
		{ 81, "swingBlade", 0.12 },
		{ 92, "click", 0.25 },
		{ 179, "swingBlade", 0.12 },
		{ 197, "swingBlade", 0.12 },
		{ 206, "click", 0.3 },
	},
	pivot = Vector3.new(1.0, -1.5, -2.2),
	len = 240,
	chain = 240,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 18, "inout", P(-0.9, 0.8, 0.5, 6, 10, 0) }, -- up into the middle-right, closer
			{ 90, "inout", P(-0.95, 0.82, 0.52, 6, 12, 0) },
			{ 104, "inout", P(-1.0, 0.9, 0.55, 8, 18, -8) }, -- settled open: the admiring hold
			{ 168, "inout", P(-1.05, 0.95, 0.58, 10, 24, -12) }, -- (turning it slowly)
			{ 206, "inout", P(-0.95, 0.85, 0.5, 6, 10, 0) },
			{ 226, "out", P(0.05, -0.05, 0, -2, 0, 0) }, -- home, with a little dip
			{ 240, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 18, "inout", P(0, 0, 0, -6, 0, 0) },
			{ 27, "inout", P(0, 0.04, 0, -12, 0, -20, nil, 30) }, -- the wrist rocks with each flip
			{ 45, "inout", P(0, 0.04, 0, -12, 0, 20, nil, -30) },
			{ 63, "inout", P(0, 0.04, 0, -12, 0, -20, nil, 30) },
			{ 81, "inout", P(0, 0.04, 0, -12, 0, 20, nil, -30) },
			{ 92, "inout", P(0, 0, 0, -6, 0, 0) },
			{ 104, "inout", P(0, 0.03, 0, -12, 10, -35, nil, 70) }, -- rolled over to show the blade's side
			{ 168, "inout", P(0, 0.03, 0, -14, 14, -42, nil, 78) },
			{ 179, "inout", P(0, 0.05, 0, -16, 0, -15, nil, 20) },
			{ 197, "inout", P(0, 0.05, 0, -16, 0, 15, nil, -20) },
			{ 206, "inout", P(0, 0, 0, -6, 0, 0) },
			{ 240, "linear", P() },
		}),
		T = K({
			{ 0, "linear", OPEN(0, 0) },
			{ 18, "linear", OPEN(0, 0) }, -- (30 Oct: an even roll through the flips, not a dash in the middle of each)
			{ 36, "linear", OPEN(70, 180) }, -- half a turn, the blades flaring
			{ 54, "linear", OPEN(20, 360) },
			{ 72, "linear", OPEN(70, 540) },
			{ 90, "inout", OPEN(55, 720) }, -- caught open
			{ 104, "inout", OPEN(60, 720) },
			{ 168, "linear", OPEN(66, 720) },
			{ 188, "linear", OPEN(75, 900) },
			{ 206, "inout", OPEN(0, 1080) }, -- snapped shut
			{ 240, "linear", OPEN(0, 1080) },
		}),
	},
})

-- Bare hands: the right fist comes up to be looked at and turned over, then the left, then they meet and the
-- knuckles crack.
define({
	name = "InspectHands",
	inspect = true,
	sounds = { { 126, "chip", 0.35 } }, -- the knuckles crack
	pivot = Vector3.new(0, -1.5, -2.2),
	len = 180,
	chain = 180,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 14, "inout", P(0, 0.2, 0.2, 4, 0, 0) },
			{ 160, "inout", P(0, 0.22, 0.22, 5, 0, 0) },
			{ 180, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 16, "out", P(-0.9, 0.5, 0.1, -10, -30, -20) }, -- up and in, turned to look at it
			{ 40, "inout", P(-0.95, 0.55, 0.08, -12, -36, -60, nil, -50) }, -- turned over
			{ 64, "inout", P(-0.9, 0.5, 0.1, -10, -30, -10, nil, 10) },
			{ 74, "out", P(-0.6, 0.3, 0.02, -4, -20, 0) }, -- makes room for the left
			{ 104, "inout", P(-0.6, 0.28, 0, -4, -18, 0) },
			{ 120, "inout", P(-1.85, 0.34, 0.05, -6, -15, 0) }, -- the fists meet
			{ 126, "out", P(-1.87, 0.3, 0.05, -6, -15, -12, nil, 25) }, -- crack
			{ 134, "inout", P(-1.85, 0.34, 0.05, -6, -15, 0) },
			{ 180, "linear", P() },
		}),
		L = K({
			{ 0, "inout", P() },
			{ 60, "inout", P(0.05, 0.05, 0) },
			{ 76, "out", P(0.9, 0.5, 0.1, -10, 30, 20) }, -- the left's turn
			{ 96, "inout", P(0.95, 0.55, 0.08, -12, 36, 60, nil, 50) },
			{ 110, "inout", P(0.9, 0.48, 0.08, -8, 30, 10) },
			{ 120, "inout", P(1.9, 0.34, 0.05, -6, 15, 0) },
			{ 126, "out", P(1.92, 0.3, 0.05, -6, 15, 12, nil, -25) },
			{ 134, "inout", P(1.9, 0.34, 0.05, -6, 15, 0) },
			{ 180, "linear", P() },
		}),
	},
})

-- Sickle: a look along the blade, a flick up and a spin through the air, caught, and the back of the blade shown.
define({
	name = "InspectSickle",
	inspect = true,
	sounds = { { 66, "swingBlade", 0.15 }, { 88, "chip", 0.3 } }, -- the toss, the catch
	pivot = Vector3.new(1.0, -1.5, -2.2),
	len = 180,
	chain = 180,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 16, "inout", P(-1.0, 0.75, 0.5, 6, 10, 0) },
			{ 150, "inout", P(-1.05, 0.8, 0.52, 8, 13, -3) },
			{ 166, "out", P(0.03, -0.03, 0, -2, 0, 0) },
			{ 180, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 18, "out", P(-0.5, 0.5, 0.25, 8, 30, -70) }, -- along the blade
			{ 50, "inout", P(-0.52, 0.54, 0.25, 6, 34, -76) },
			{ 62, "in", P(-0.3, 0.4, 0.15, 0, 10, -20) },
			{ 66, "out", P(-0.2, 0.5, 0.05, -10, 0, 0) }, -- flick: let go
			{ 84, "inout", P(-0.2, 0.42, 0.05, -4, 0, 0) },
			{ 88, "out", P(-0.22, 0.3, 0.08, 4, 0, 0) }, -- the catch gives with the weight
			{ 100, "inout", P(-0.4, 0.45, 0.2, 4, -30, 60) }, -- the back of the blade
			{ 140, "inout", P(-0.42, 0.48, 0.2, 6, -34, 66) },
			{ 180, "linear", P() },
		}),
		T = K({
			{ 0, "linear", P() },
			{ 66, "out", P() },
			{ 77, "in", P(0, 0.9, 0.1, -180, 0, 0) }, -- up, slowing, half a turn
			{ 88, "linear", P(0, 0, 0, -360, 0, 0) }, -- back into the hand
			{ 180, "linear", P(0, 0, 0, -360, 0, 0) },
		}),
	},
})

-- Mega Scythe: the reaper's twirl (31 Oct, owner: "change the inspect completely, make it look cool and flashy, a
-- different pose, organic, high quality"; the earlier ones turned the scythe about your fist with both hands on it, so
-- the left arm crossed the view or the blade went edge-on: they're in the project doc). Now the left hand LETS GO (L:
-- its roll is how far, 0..100, its p where the fist drops to, out of the view), the right hand brings the scythe up in
-- front of you (R moves the fist to the inspect's pivot) and the whole thing is spun round that fist like a baton
-- (I's roll about the pivot), twice, the blade drawing its lavender trail; it stops stood up on end, the blade hooked
-- over the top of the view like a reaper's, and is admired there, swaying, the blade glinting (T rocks it round the
-- snath); then it's swung on round and down into the hold, the left hand catches the snath, and its weight settles.
local SCY_SHOW = P(0.35, 0.1, 0.25, 10, 8, -125) -- (an older presenting pose, R)
local SCY_DROP = P(-0.6, -3.0, 0.6, 0, 0, 0) -- (L) where the left fist goes when it lets go: down out of the view
local SCY_UP = P(-0.24, 1.21, -0.76) -- (R) the fist up in front of you, at the pivot (0.3, -0.8, -2.9)
local SCY_PIVOT = Vector3.new(0.3, -0.8, -2.9)
local function letGoKeys(off: number, back: number, len: number): { Key }
	return K({
		{ 0, "inout", P() },
		{ off, "out", { p = SCY_DROP.p, r = Vector3.zero, b = Vector3.zero, roll = 100 } },
		{ back - 12, "in", { p = SCY_DROP.p, r = Vector3.zero, b = Vector3.zero, roll = 100 } },
		{ back, "out", P() }, -- caught the snath again
		{ len, "linear", P() },
	})
end
define({
	name = "InspectScythe",
	inspect = true,
	letGo = true,
	main = "I", -- (its spins draw the blade's trail)
	trail = { 22, 62 },
	sounds = {
		{ 28, "swingBlade", 0.16 },
		{ 37, "swingBlade", 0.18 },
		{ 46, "swingBlade", 0.2 },
		{ 54, "swingBlade", 0.18 },
		{ 62, "chip", 0.32 }, -- stopped dead, stood on end
		{ 164, "swingBlade", 0.2 },
		{ 182, "chip", 0.22 }, -- the left hand back on the snath
		{ 200, "stepThud", 0.24 },
	},
	pivot = SCY_PIVOT,
	len = 214,
	chain = 214,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 14, "out", P(-0.24, 1.26, -0.78, 4, 0, 0) }, -- up in front of you, a touch past
			{ 22, "inout", SCY_UP },
			-- (the wrist works the spin: the fist rocks and circles a little with each turn, the scythe turning in its
			-- fingers; the arm itself stays put)
			{ 31, "inout", P(-0.31, 1.25, -0.76, 0, 0, 0, nil, -18) },
			{ 40, "inout", P(-0.22, 1.15, -0.76, 0, 0, 0, nil, 14) },
			{ 49, "inout", P(-0.31, 1.25, -0.76, 0, 0, 0, nil, -18) },
			{ 58, "inout", P(-0.24, 1.19, -0.76, 0, 0, 0, nil, 8) },
			{ 70, "inout", P(-0.22, 1.24, -0.74, 6, -4, 0, nil, -4) }, -- tipped toward you
			{ 136, "inout", P(-0.22, 1.27, -0.74, 8, -6, 0, nil, -6) },
			{ 150, "inout", SCY_UP },
			{ 163, "inout", P(-0.16, 0.8, -0.6, -1, 0, 0, nil, -14) }, -- the wrist turning it down
			{ 176, "out", P(0, -0.05, 0, -2, 0, 0) }, -- swung down into the hold
			{ 188, "inout", P(0, 0.02, 0, 0, 0, 0) },
			{ 200, "out", P(0, -0.04, 0, -1, 0, 0) }, -- its weight settles
			{ 214, "linear", P() },
		}),
		I = K({
			{ 0, "inout", P() },
			{ 16, "inout", P(0, 0, 0, 0, 0, 20) }, -- wound back
			{ 22, "in", P(0, 0, 0, 0, 0, 24) },
			{ 40, "linear", P(0, 0, 0, 0, 0, -360) },
			{ 58, "out", P(0, 0, 0, 0, 0, -812) }, -- twice round and on to stand it up, a touch past
			{ 68, "inout", P(0, 0, 0, 0, 0, -797) }, -- stopped, stood on end
			{ 104, "inout", P(0, 0, 0, 3, -5, -802) }, -- (swaying)
			{ 140, "inout", P(0, 0, 0, -2, 4, -799) },
			{ 150, "in", P(0, 0, 0, 0, 0, -790) }, -- wound for the swing down
			{ 176, "out", P(0, 0, 0, 0, 0, -1086) }, -- on round and down into the hold
			{ 190, "inout", P(0, 0, 0, 0, 0, -1078) },
			{ 214, "linear", P(0, 0, 0, 0, 0, -1080) },
		}),
		L = letGoKeys(10, 182, 214),
		T = K({
			{ 0, "linear", P() },
			{ 68, "inout", P() },
			{ 94, "inout", P(0, 0, 0, 0, 0, -16) }, -- the blade turned to catch the light
			{ 118, "inout", P(0, 0, 0, 0, 0, 12) },
			{ 140, "inout", P() },
			{ 214, "linear", P() },
		}),
		B = K({
			{ 0, "inout", P() },
			{ 12, "inout", P(0, -0.01, 0, 1.5, 1.5, 1) },
			{ 30, "inout", P(0, 0.015, 0, -1.5, -1.5, -1) },
			{ 52, "inout", P(0, 0.01, 0, -1, 0, 0) },
			{ 63, "out", P(0, -0.025, 0, 2.2, 1, 1) }, -- the stop
			{ 84, "inout", P(0, 0.01, 0, -0.5, 0, 0) },
			{ 140, "inout", P(0, 0.015, 0, -1, -0.5, 0) },
			{ 168, "inout", P(0, -0.01, 0, 1, 1.5, 0.5) },
			{ 200, "out", P(0, -0.035, 0, 2.5, 0, 0) },
			{ 214, "linear", P() },
		}),
	},
})

-- Push mower / laser mower: tipped back on its wheels to look underneath at the blade, turned a little each way, then
-- set down with a thump.
define({
	name = "InspectPush",
	inspect = true,
	sounds = { { 110, "stepThud", 0.45 } }, -- set down
	pivot = Vector3.new(0, -1.65, -2.4),
	len = 160,
	chain = 160,
	ch = {
		I = K({
			{ 0, "inout", P() },
			{ 22, "out", P(0, 0.35, 0.3, 45, 0, 0) },
			{ 60, "inout", P(0, 0.4, 0.34, 50, 8, 6) },
			{ 84, "inout", P(0, 0.38, 0.32, 47, -8, -6) },
			{ 104, "in", P(0, 0.05, 0, 4, 0, 0) },
			{ 110, "out", P(0, -0.07, 0, -3, 0, 0) }, -- thump
			{ 126, "inout", P(0, 0.02, 0, 1, 0, 0) },
			{ 160, "linear", P() },
		}),
	},
})

-- Weed whacker: the head brought up into view and turned one way then the other.
define({
	name = "InspectWhacker",
	inspect = true,
	pivot = Vector3.new(1.1, -1.85, -1.7),
	len = 170,
	chain = 170,
	ch = {
		I = K({
			{ 0, "inout", P() },
			{ 22, "out", P(-0.6, 0.35, 0.3, 30, 20, 10) },
			{ 80, "inout", P(-0.62, 0.38, 0.32, 34, 24, 12) },
			{ 100, "inout", P(-0.5, 0.4, 0.3, 26, -15, -12) },
			{ 140, "inout", P(-0.52, 0.42, 0.3, 28, -18, -14) },
			{ 160, "out", P(0.03, -0.03, 0, -2, 0, 0) },
			{ 170, "linear", P() },
		}),
	},
})

-- Anything else you can hold (the guns, a crate prize): up into the middle, one face, the other, home.
define({
	name = "InspectItem",
	inspect = true,
	pivot = Vector3.new(1.0, -1.5, -2.2),
	len = 170,
	chain = 170,
	ch = {
		I = K({
			{ 0, "inout", P() },
			{ 18, "out", P(-0.9, 0.7, 0.4, 10, 35, 20) },
			{ 62, "inout", P(-1.0, 0.75, 0.45, 14, 42, 26) },
			{ 82, "inout", P(-0.8, 0.8, 0.35, -8, -20, -55) },
			{ 124, "inout", P(-0.85, 0.82, 0.38, -10, -26, -60) },
			{ 146, "in", P(-0.1, 0.1, 0.05, 2, 4, 4) },
			{ 156, "out", P(0.04, -0.05, 0, -2, 0, 0) },
			{ 170, "linear", P() },
		}),
	},
})

-------------------------------------------------------------------------------------------------------------
-- (30 Oct, owner: "give every weapon including the scythe 2 very rare animations that are low chance of showing
-- up") RARE INSPECTS, like CS2's: each inspect has a 1 in 25 chance (RARE_CHANCE) to play one of its item's two rare
-- variants instead (RARE below), with a chime. Same rules as the inspects above.
-------------------------------------------------------------------------------------------------------------
-- Bare hands, rare 1: shadow boxing: up into a guard, jab, cross, jab, hook, jab, uppercut, back down.
define({
	name = "InspectHandsShadow",
	inspect = true,
	sounds = { { 18, "swingHand", 0.5 }, { 36, "swingHand", 0.5 }, { 52, "swingHand", 0.5 }, { 70, "swingHand", 0.5 }, { 86, "swingHand", 0.5 }, { 100, "swingHand", 0.5 } },
	pivot = Vector3.new(0, -1.5, -2.2),
	len = 150,
	chain = 150,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 10, "inout", P(0, 0.15, 0.2, 3) },
			{ 130, "inout", P(0, 0.15, 0.2, 3) },
			{ 150, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 12, "out", P(-0.5, 0.95, 0.1, -6, -12, -10) }, -- the guard
			{ 30, "inout", P(-0.5, 0.95, 0.1, -6, -12, -10) },
			{ 36, "out", P(-0.9, 1, -0.9, -4, -6, 0) }, -- cross
			{ 44, "inout", P(-0.5, 0.95, 0.1, -6, -12, -10) },
			{ 64, "inout", P(-0.5, 0.95, 0.1, -6, -12, -10) },
			{ 70, "out", P(-1.4, 1.05, -0.4, -6, -50, -30, nil, 30) }, -- hook
			{ 80, "inout", P(-0.5, 0.95, 0.1, -6, -12, -10) },
			{ 94, "inout", P(-0.5, 0.9, 0.1, -6, -12, -10) },
			{ 100, "out", P(-0.7, 1.45, -0.4, 30, -10, -10) }, -- uppercut
			{ 110, "inout", P(-0.5, 0.95, 0.1, -6, -12, -10) },
			{ 150, "linear", P() },
		}),
		L = K({
			{ 0, "inout", P() },
			{ 12, "out", P(0.5, 1, 0.1, -6, 12, 10) },
			{ 18, "out", P(0.75, 1.05, -0.95, -4, 6, 0) }, -- jab
			{ 26, "inout", P(0.5, 1, 0.1, -6, 12, 10) },
			{ 46, "inout", P(0.5, 1, 0.1, -6, 12, 10) },
			{ 52, "out", P(0.75, 1.05, -0.95, -4, 6, 0) }, -- jab
			{ 60, "inout", P(0.5, 1, 0.1, -6, 12, 10) },
			{ 80, "inout", P(0.5, 1, 0.1, -6, 12, 10) },
			{ 86, "out", P(0.75, 1.05, -0.95, -4, 6, 0) }, -- jab
			{ 94, "inout", P(0.5, 1, 0.1, -6, 12, 10) },
			{ 150, "linear", P() },
		}),
	},
})

-- Bare hands, rare 2: a double flex, the fists pumped three times, then slammed together.
define({
	name = "InspectHandsFlex",
	inspect = true,
	sounds = { { 114, "chip", 0.45 } },
	pivot = Vector3.new(0, -1.5, -2.2),
	len = 160,
	chain = 160,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 16, "inout", P(0, -0.1, 0.25, 8) },
			{ 140, "inout", P(0, -0.1, 0.25, 8) },
			{ 160, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 20, "out", P(-0.2, 1.1, 0.4, -30, -40, -60, nil, 20) }, -- up, the forearm raised
			{ 30, "inout", P(-0.22, 1.15, 0.4, -34, -42, -64) },
			{ 36, "inout", P(-0.18, 1.08, 0.4, -28, -38, -56) },
			{ 42, "inout", P(-0.22, 1.15, 0.4, -34, -42, -64) },
			{ 48, "inout", P(-0.18, 1.08, 0.4, -28, -38, -56) },
			{ 54, "inout", P(-0.22, 1.15, 0.4, -34, -42, -64) },
			{ 90, "inout", P(-0.2, 1.12, 0.4, -32, -40, -62) },
			{ 110, "in", P(-1.8, 0.4, 0, -6, -15, 0) }, -- the fists meet
			{ 114, "out", P(-1.82, 0.36, 0, -6, -15, -12, nil, 25) },
			{ 124, "inout", P(-1.8, 0.4, 0, -6, -15, 0) },
			{ 160, "linear", P() },
		}),
		L = K({
			{ 0, "inout", P() },
			{ 20, "out", P(0.2, 1.1, 0.4, -30, 40, 60, nil, -20) },
			{ 30, "inout", P(0.22, 1.15, 0.4, -34, 42, 64) },
			{ 36, "inout", P(0.18, 1.08, 0.4, -28, 38, 56) },
			{ 42, "inout", P(0.22, 1.15, 0.4, -34, 42, 64) },
			{ 48, "inout", P(0.18, 1.08, 0.4, -28, 38, 56) },
			{ 54, "inout", P(0.22, 1.15, 0.4, -34, 42, 64) },
			{ 90, "inout", P(0.2, 1.12, 0.4, -32, 40, 62) },
			{ 110, "in", P(1.85, 0.4, 0, -6, 15, 0) },
			{ 114, "out", P(1.87, 0.36, 0, -6, 15, 12, nil, -25) },
			{ 124, "inout", P(1.85, 0.4, 0, -6, 15, 0) },
			{ 160, "linear", P() },
		}),
	},
})

-- Scissors, rare 1: the fan: spun round the finger four times without a stop, blades fluttering, snapped shut.
define({
	name = "InspectScissorsFan",
	inspect = true,
	sounds = { { 24, "swingBlade", 0.12 }, { 48, "swingBlade", 0.12 }, { 72, "swingBlade", 0.12 }, { 96, "swingBlade", 0.12 }, { 118, "swingBlade", 0.12 }, { 130, "click", 0.35 } },
	pivot = Vector3.new(1.0, -1.5, -2.2),
	len = 176,
	chain = 176,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 18, "inout", P(-0.9, 0.8, 0.5, 6, 10, 0) },
			{ 140, "inout", P(-0.95, 0.85, 0.52, 8, 14, -4) },
			{ 160, "out", P(0.05, -0.05, 0, -2) },
			{ 176, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 18, "inout", P(0, 0, 0, -6) },
			{ 60, "inout", P(0, 0.04, 0, -10, 0, -15, nil, 20) },
			{ 100, "inout", P(0, 0.04, 0, -10, 0, 15, nil, -20) },
			{ 130, "out", P(0, 0.08, 0, -18) }, -- the catch
			{ 140, "inout", P(0, 0, 0, -6) },
			{ 176, "linear", P() },
		}),
		T = K({
			{ 0, "linear", OPEN(0, 0) },
			{ 18, "linear", OPEN(0, 0) },
			{ 40, "linear", OPEN(60, 270) }, -- (30 Oct: slowed, ~800 deg/s, was ~4x that)
			{ 60, "linear", OPEN(30, 540) },
			{ 80, "linear", OPEN(70, 810) },
			{ 100, "linear", OPEN(30, 1080) },
			{ 120, "linear", OPEN(70, 1350) },
			{ 130, "inout", OPEN(0, 1440) },
			{ 176, "linear", OPEN(0, 1440) },
		}),
	},
})

-- Scissors, rare 2: the barber: brought right up close and snipped five times fast, then a flourish.
define({
	name = "InspectScissorsSnip",
	inspect = true,
	sounds = { { 27, "click", 0.3 }, { 37, "click", 0.3 }, { 47, "click", 0.3 }, { 57, "click", 0.3 }, { 66, "click", 0.35 }, { 86, "swingBlade", 0.12 } },
	pivot = Vector3.new(1.0, -1.5, -2.2),
	len = 150,
	chain = 150,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 16, "inout", P(-1.1, 0.95, 0.9, 10, 18, -6) },
			{ 110, "inout", P(-1.12, 0.98, 0.92, 12, 22, -10) },
			{ 130, "out", P(0.05, -0.05, 0, -2) },
			{ 150, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 16, "inout", P(0, 0, 0, -8, 0, -20, nil, 30) },
			{ 110, "inout", P(0, 0.02, 0, -10, 4, -24, nil, 34) },
			{ 150, "linear", P() },
		}),
		T = K({
			{ 0, "linear", OPEN(0) },
			{ 16, "in", OPEN(0) },
			{ 22, "out", OPEN(70) },
			{ 27, "in", OPEN(0) },
			{ 32, "out", OPEN(70) },
			{ 37, "in", OPEN(0) },
			{ 42, "out", OPEN(75) },
			{ 47, "in", OPEN(0) },
			{ 52, "out", OPEN(75) },
			{ 57, "in", OPEN(0) },
			{ 62, "out", OPEN(80) },
			{ 66, "in", OPEN(0) },
			{ 80, "in", OPEN(0) },
			{ 86, "out", OPEN(40, 180) },
			{ 94, "inout", OPEN(0, 360) },
			{ 150, "linear", OPEN(0, 360) },
		}),
	},
})

-- Sickle, rare 1: tossed and caught twice, the second higher with two turns.
define({
	name = "InspectSickleDouble",
	inspect = true,
	sounds = { { 28, "swingBlade", 0.15 }, { 50, "chip", 0.3 }, { 66, "swingBlade", 0.15 }, { 96, "chip", 0.35 } },
	pivot = Vector3.new(1.0, -1.5, -2.2),
	len = 180,
	chain = 180,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 16, "inout", P(-1.0, 0.75, 0.5, 6, 10, 0) },
			{ 150, "inout", P(-1.05, 0.8, 0.52, 8, 13, -3) },
			{ 166, "out", P(0.03, -0.03, 0, -2) },
			{ 180, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 18, "out", P(-0.3, 0.4, 0.15, 0, 10, -20) },
			{ 24, "in", P(-0.3, 0.38, 0.15, 0, 10, -20) },
			{ 28, "out", P(-0.2, 0.5, 0.05, -10) }, -- flick
			{ 46, "inout", P(-0.2, 0.42, 0.05, -4) },
			{ 50, "out", P(-0.22, 0.3, 0.08, 4) }, -- catch
			{ 62, "in", P(-0.3, 0.4, 0.15, 0, 10, -20) },
			{ 66, "out", P(-0.2, 0.55, 0.05, -12) }, -- a harder flick
			{ 92, "inout", P(-0.2, 0.42, 0.05, -4) },
			{ 96, "out", P(-0.22, 0.28, 0.08, 5) }, -- catch
			{ 110, "inout", P(-0.4, 0.45, 0.2, 4, -30, 60) },
			{ 140, "inout", P(-0.42, 0.48, 0.2, 6, -34, 66) },
			{ 180, "linear", P() },
		}),
		T = K({
			{ 0, "linear", P() },
			{ 28, "out", P() },
			{ 39, "in", P(0, 0.9, 0.1, -180) },
			{ 50, "linear", P(0, 0, 0, -360) },
			{ 66, "out", P(0, 0, 0, -360) },
			{ 81, "in", P(0, 1.15, 0.15, -720) }, -- (30 Oct: lower so the sickle stays out of the camera)
			{ 96, "linear", P(0, 0, 0, -1080) },
			{ 180, "linear", P(0, 0, 0, -1080) },
		}),
	},
})

-- Sickle, rare 2: the gunslinger: spun round the finger four times like a revolver, then three turns back.
define({
	name = "InspectSickleTwirl",
	inspect = true,
	sounds = { { 26, "swingBlade", 0.12 }, { 38, "swingBlade", 0.12 }, { 48, "swingBlade", 0.12 }, { 78, "swingBlade", 0.12 }, { 90, "swingBlade", 0.12 } },
	pivot = Vector3.new(1.0, -1.5, -2.2),
	len = 170,
	chain = 170,
	ch = {
		I = K({
			{ 0, "out", P() },
			{ 16, "inout", P(-0.9, 0.7, 0.45, 6, 10, 0) },
			{ 140, "inout", P(-0.95, 0.74, 0.47, 8, 13, -3) },
			{ 156, "out", P(0.03, -0.03, 0, -2) },
			{ 170, "linear", P() },
		}),
		R = K({
			{ 0, "inout", P() },
			{ 16, "inout", P(-0.2, 0.35, 0.05, -4) },
			{ 140, "inout", P(-0.22, 0.38, 0.05, -6, 4, 4) },
			{ 170, "linear", P() },
		}),
		T = K({
			{ 0, "linear", P() },
			{ 18, "in", P() },
			{ 50, "linear", P(0, 0, 0, -1440) },
			{ 60, "out", P(0, 0, 0, -1440) },
			{ 70, "in", P(0, 0, 0, -1440) },
			{ 100, "inout", P(0, 0, 0, -360) },
			{ 170, "linear", P(0, 0, 0, -360) },
		}),
	},
})

-- Mega Scythe, rare 1: the baton: the twirl three times round and faster, a hop of the wrist, and swung down.
-- (31 Oct: rebuilt on the twirl, see InspectScythe)
define({
	name = "InspectScytheBaton",
	inspect = true,
	letGo = true,
	main = "I",
	trail = { 20, 62 },
	sounds = {
		{ 26, "swingBlade", 0.16 }, { 33, "swingBlade", 0.18 }, { 40, "swingBlade", 0.2 }, { 47, "swingBlade", 0.2 },
		{ 54, "swingBlade", 0.18 }, { 62, "chip", 0.32 }, { 158, "swingBlade", 0.2 }, { 176, "chip", 0.22 }, { 194, "stepThud", 0.24 },
	},
	pivot = SCY_PIVOT,
	len = 208,
	chain = 208,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 14, "out", P(-0.24, 1.26, -0.78, 4, 0, 0) },
			{ 22, "inout", SCY_UP },
			{ 29, "inout", P(-0.31, 1.25, -0.76, 0, 0, 0, nil, -18) },
			{ 36, "inout", P(-0.22, 1.15, -0.76, 0, 0, 0, nil, 14) },
			{ 43, "inout", P(-0.31, 1.25, -0.76, 0, 0, 0, nil, -18) },
			{ 50, "inout", P(-0.22, 1.15, -0.76, 0, 0, 0, nil, 14) },
			{ 58, "inout", P(-0.24, 1.19, -0.76, 0, 0, 0, nil, 8) },
			{ 70, "inout", P(-0.22, 1.24, -0.74, 6, -4, 0, nil, -4) },
			{ 130, "inout", P(-0.22, 1.27, -0.74, 8, -6, 0, nil, -6) },
			{ 140, "out", P(-0.24, 1.36, -0.76, 4, 0, 0) }, -- the wrist hops
			{ 146, "inout", SCY_UP },
			{ 158, "inout", P(-0.16, 0.8, -0.6, -1, 0, 0, nil, -14) },
			{ 170, "out", P(0, -0.05, 0, -2, 0, 0) },
			{ 182, "inout", P(0, 0.02, 0, 0, 0, 0) },
			{ 194, "out", P(0, -0.04, 0, -1, 0, 0) },
			{ 208, "linear", P() },
		}),
		I = K({
			{ 0, "inout", P() },
			{ 14, "inout", P(0, 0, 0, 0, 0, 20) },
			{ 20, "in", P(0, 0, 0, 0, 0, 24) },
			{ 38, "linear", P(0, 0, 0, 0, 0, -540) },
			{ 58, "out", P(0, 0, 0, 0, 0, -1172) }, -- three times round and stood up
			{ 68, "inout", P(0, 0, 0, 0, 0, -1157) },
			{ 104, "inout", P(0, 0, 0, 3, -5, -1162) },
			{ 134, "inout", P(0, 0, 0, -2, 4, -1159) },
			{ 146, "in", P(0, 0, 0, 0, 0, -1150) },
			{ 170, "out", P(0, 0, 0, 0, 0, -1446) },
			{ 184, "inout", P(0, 0, 0, 0, 0, -1438) },
			{ 208, "linear", P(0, 0, 0, 0, 0, -1440) },
		}),
		L = letGoKeys(10, 176, 208),
		T = K({
			{ 0, "linear", P() },
			{ 68, "inout", P() },
			{ 92, "inout", P(0, 0, 0, 0, 0, -16) },
			{ 114, "inout", P(0, 0, 0, 0, 0, 12) },
			{ 134, "inout", P() },
			{ 208, "linear", P() },
		}),
		B = K({
			{ 0, "inout", P() },
			{ 12, "inout", P(0, -0.01, 0, 1.5, 1.5, 1) },
			{ 34, "inout", P(0, 0.015, 0, -1.5, -2, -1) },
			{ 63, "out", P(0, -0.025, 0, 2.2, 1, 1) },
			{ 84, "inout", P(0, 0.01, 0, -0.5, 0, 0) },
			{ 162, "inout", P(0, -0.01, 0, 1, 1.5, 0.5) },
			{ 194, "out", P(0, -0.035, 0, 2.5, 0, 0) },
			{ 208, "linear", P() },
		}),
	},
})

-- Mega Scythe, rare 2: the toss: the twirl once round and stood on end, then thrown straight up off the hand,
-- spinning round its snath (T: up its line), caught one-handed with a dip, admired, and swung down into the hold.
-- (31 Oct: rebuilt on the twirl)
define({
	name = "InspectScytheToss",
	inspect = true,
	letGo = true,
	main = "I",
	trail = { 22, 50 },
	sounds = {
		{ 28, "swingBlade", 0.16 }, { 38, "swingBlade", 0.18 }, { 64, "swingBlade", 0.2 }, { 72, "swingBlade", 0.16 },
		{ 92, "stepThud", 0.3 }, { 172, "swingBlade", 0.2 }, { 190, "chip", 0.22 }, { 208, "stepThud", 0.24 },
	},
	pivot = SCY_PIVOT,
	len = 222,
	chain = 222,
	ch = {
		R = K({
			{ 0, "inout", P() },
			{ 14, "out", P(-0.24, 1.26, -0.78, 4, 0, 0) },
			{ 22, "inout", SCY_UP },
			{ 31, "inout", P(-0.31, 1.25, -0.76, 0, 0, 0, nil, -18) },
			{ 40, "inout", P(-0.22, 1.15, -0.76, 0, 0, 0, nil, 14) },
			{ 46, "inout", P(-0.24, 1.19, -0.76, 0, 0, 0, nil, 4) },
			{ 56, "in", P(-0.24, 1.0, -0.76) }, -- dips to throw
			{ 60, "out", P(-0.24, 1.55, -0.76) }, -- up it goes
			{ 86, "inout", P(-0.24, 1.4, -0.76) },
			{ 92, "out", P(-0.24, 1.05, -0.76, -3, 0, 0) }, -- caught, the weight giving
			{ 110, "inout", P(-0.22, 1.24, -0.74, 6, -4, 0) },
			{ 146, "inout", P(-0.22, 1.27, -0.74, 8, -6, 0) },
			{ 158, "inout", SCY_UP },
			{ 171, "inout", P(-0.16, 0.8, -0.6, -1, 0, 0, nil, -14) },
			{ 184, "out", P(0, -0.05, 0, -2, 0, 0) },
			{ 196, "inout", P(0, 0.02, 0, 0, 0, 0) },
			{ 208, "out", P(0, -0.04, 0, -1, 0, 0) },
			{ 222, "linear", P() },
		}),
		I = K({
			{ 0, "inout", P() },
			{ 16, "inout", P(0, 0, 0, 0, 0, 20) },
			{ 22, "in", P(0, 0, 0, 0, 0, 24) },
			{ 46, "out", P(0, 0, 0, 0, 0, -450) }, -- once round and stood up
			{ 54, "inout", P(0, 0, 0, 0, 0, -437) },
			{ 146, "inout", P(0, 0, 0, -2, 4, -439) },
			{ 158, "in", P(0, 0, 0, 0, 0, -430) },
			{ 184, "out", P(0, 0, 0, 0, 0, -726) },
			{ 198, "inout", P(0, 0, 0, 0, 0, -718) },
			{ 222, "linear", P(0, 0, 0, 0, 0, -720) },
		}),
		L = letGoKeys(10, 190, 222),
		T = K({
			{ 0, "linear", P() },
			{ 58, "out", P() },
			{ 74, "in", P(0, 0, -4, 0, 0, -540) }, -- up the line of its snath, slowing, spinning
			{ 90, "linear", P(0, 0, 0, 0, 0, -1080) }, -- back into the hand
			{ 222, "linear", P(0, 0, 0, 0, 0, -1080) },
		}),
		B = K({
			{ 0, "inout", P() },
			{ 12, "inout", P(0, -0.01, 0, 1.5, 1.5, 1) },
			{ 56, "in", P(0, -0.02, 0, 1.5, 0, 0) },
			{ 62, "out", P(0, 0.02, 0, -2, 0, 0) },
			{ 86, "inout", P(0, 0.01, 0, -1, 0, 0) },
			{ 94, "out", P(0, -0.05, 0, 3, 0, 0) }, -- the catch
			{ 120, "inout", P(0, 0, 0, 0, 0.5, 0) },
			{ 176, "inout", P(0, -0.01, 0, 1, 1.5, 0.5) },
			{ 208, "out", P(0, -0.035, 0, 2.5, 0, 0) },
			{ 222, "linear", P() },
		}),
	},
})

-- Push mower / laser mower, rare 1: a wheelie: tipped right back on its wheels, swung left, right, left, slammed down.
define({
	name = "InspectPushWheelie",
	inspect = true,
	sounds = { { 118, "stepThud", 0.5 } },
	pivot = Vector3.new(0, -1.65, -2.4),
	len = 170,
	chain = 170,
	ch = {
		I = K({
			{ 0, "inout", P() },
			{ 20, "out", P(0, 0.5, 0.4, 60) },
			{ 40, "inout", P(0, 0.55, 0.42, 62, 25, 8) },
			{ 60, "inout", P(0, 0.55, 0.42, 62, -25, -8) },
			{ 80, "inout", P(0, 0.55, 0.42, 62, 25, 8) },
			{ 100, "inout", P(0, 0.5, 0.4, 60) },
			{ 112, "in", P(0, 0.05, 0, 4) },
			{ 118, "out", P(0, -0.09, 0, -4) }, -- slam
			{ 134, "inout", P(0, 0.02, 0, 1) },
			{ 170, "linear", P() },
		}),
	},
})

-- Push mower / laser mower, rare 2: revved: it shakes like an engine on full throttle, then is lifted and slammed down.
define({
	name = "InspectPushRev",
	inspect = true,
	sounds = { { 110, "stepThud", 0.5 } },
	pivot = Vector3.new(0, -1.65, -2.4),
	len = 160,
	chain = 160,
	ch = {
		I = K({
			{ 0, "inout", P() },
			{ 14, "out", P(0, 0.1, 0.1, 8) },
			{ 17, "linear", P(0, 0.11, 0.1, 9, 1, 3) },
			{ 20, "linear", P(0, 0.1, 0.1, 8, -1, -3) },
			{ 23, "linear", P(0, 0.11, 0.1, 9, 1, 3) },
			{ 26, "linear", P(0, 0.1, 0.1, 8, -1, -3) },
			{ 29, "linear", P(0, 0.11, 0.1, 9, 1, 3) },
			{ 32, "linear", P(0, 0.1, 0.1, 8, -1, -3) },
			{ 35, "linear", P(0, 0.11, 0.1, 9, 1, 3) },
			{ 38, "linear", P(0, 0.1, 0.1, 8, -1, -3) },
			{ 41, "linear", P(0, 0.11, 0.1, 9, 1, 3) },
			{ 44, "linear", P(0, 0.1, 0.1, 8, -1, -3) },
			{ 60, "inout", P(0, 0.12, 0.12, 10) },
			{ 80, "out", P(0, 0.6, 0.35, 35) }, -- lifted
			{ 96, "inout", P(0, 0.65, 0.38, 38) },
			{ 104, "in", P(0, 0.05, 0, 4) },
			{ 110, "out", P(0, -0.1, 0, -5) }, -- slammed down
			{ 126, "inout", P(0, 0.02, 0, 1) },
			{ 160, "linear", P() },
		}),
	},
})

-- Weed whacker, rare 1: played like a guitar: swung across your body and strummed.
define({
	name = "InspectWhackerGuitar",
	inspect = true,
	sounds = { { 40, "rustle", 0.3 }, { 48, "rustle", 0.3 }, { 60, "rustle", 0.3 }, { 68, "rustle", 0.3 } },
	pivot = Vector3.new(1.1, -1.85, -1.7),
	len = 150,
	chain = 150,
	ch = {
		I = K({
			{ 0, "inout", P() },
			{ 22, "out", P(-1.0, 0.6, 0.4, 10, 0, -70) },
			{ 40, "inout", P(-1.0, 0.62, 0.4, 12, 0, -74) },
			{ 44, "inout", P(-1.0, 0.58, 0.4, 8, 0, -66) },
			{ 48, "inout", P(-1.0, 0.62, 0.4, 12, 0, -74) },
			{ 52, "inout", P(-1.0, 0.58, 0.4, 8, 0, -66) },
			{ 60, "inout", P(-1.0, 0.62, 0.4, 12, 0, -74) },
			{ 64, "inout", P(-1.0, 0.58, 0.4, 8, 0, -66) },
			{ 68, "inout", P(-1.0, 0.62, 0.4, 12, 0, -74) },
			{ 72, "inout", P(-1.0, 0.58, 0.4, 8, 0, -66) },
			{ 110, "inout", P(-1.02, 0.64, 0.42, 14, 6, -76) },
			{ 130, "out", P(0.03, -0.03, 0, -2) },
			{ 150, "linear", P() },
		}),
	},
})

-- Weed whacker, rare 2: spun a full turn in front of you like a baton, then held up to look at.
define({
	name = "InspectWhackerSpin",
	inspect = true,
	sounds = { { 30, "swingBlade", 0.18 }, { 52, "swingBlade", 0.18 } },
	pivot = Vector3.new(1.1, -1.85, -1.7),
	len = 160,
	chain = 160,
	ch = {
		I = K({
			{ 0, "inout", P() },
			{ 20, "out", P(-0.6, 0.4, 0.3, 20) },
			{ 70, "linear", P(-0.6, 0.4, 0.3, 20, 0, -360) },
			{ 80, "inout", P(-0.6, 0.4, 0.3, 20, 0, -360) },
			{ 120, "inout", P(-0.62, 0.42, 0.32, 30, 20, -348) },
			{ 140, "out", P(0.03, -0.03, 0, -2, 0, -360) },
			{ 160, "linear", P(0, 0, 0, 0, 0, -360) },
		}),
	},
})

-- An inspect cut short: every channel it moved goes home quickly (blended from wherever it was).
define({
	name = "InspectCancel",
	len = 10,
	chain = 10,
	ch = {
		I = K({ { 0, "linear", P() }, { 10, "linear", P() } }),
	},
})

local INSPECT: { [string]: string } = {
	Hands = "InspectHands",
	Scissors = "InspectScissors",
	Sickle = "InspectSickle",
	MegaScythe = "InspectScythe",
	PushMower = "InspectPush",
	LaserMower = "InspectPush",
	WeedWhacker = "InspectWhacker",
}
-- (30 Oct, owner: "make the inspect of the scissors a bit slower") playback speed per tool's inspect (default 1)
-- (30 Oct, owner: "change the scissors inspect speed to match the csgo one") the scissors' clip is timed like CS2's
-- butterfly inspect itself now (4 s, its flips 0.3 s each), so it plays at 1
local INSPECT_RATE: { [string]: number } = {}
-- (30 Oct) each item's two rare inspects, one of which plays instead, 1 time in RARE_CHANCE
local RARE: { [string]: { string } } = {
	Hands = { "InspectHandsShadow", "InspectHandsFlex" },
	Scissors = { "InspectScissorsFan", "InspectScissorsSnip" },
	Sickle = { "InspectSickleDouble", "InspectSickleTwirl" },
	MegaScythe = { "InspectScytheBaton", "InspectScytheToss" },
	PushMower = { "InspectPushWheelie", "InspectPushRev" },
	LaserMower = { "InspectPushWheelie", "InspectPushRev" },
	WeedWhacker = { "InspectWhackerGuitar", "InspectWhackerSpin" },
}
local RARE_CHANCE = 25

-------------------------------------------------------------------------------------------------------------
-- combos, fidgets per tool
-------------------------------------------------------------------------------------------------------------
-- (jab with the lead hand first, the power hand finishes; the finisher alternates hook / uppercut)
local COMBO: { [string]: { string } } = {
	Hands = { "JabL", "JabR", "JabL", "HookR", "JabL", "JabR", "JabL", "UpperR" },
	Scissors = { "SnipA", "SnipB", "SnipA", "SnipDouble" },
	Sickle = { "SweepF", "SweepB", "SweepF", "SweepX" },
	MegaScythe = { "ReapF", "ReapB", "ReapF", "ReapBig" },
}
local FIDGETS: { [string]: { string } } = {
	Hands = { "FlexHands", "BounceHands" },
	Scissors = { "SpinScissors", "SnipAir" },
	Sickle = { "TossSickle", "CheckBlade" },
	MegaScythe = { "ScytheTwirl" },
}

-------------------------------------------------------------------------------------------------------------
-- playback
-------------------------------------------------------------------------------------------------------------
type Track = { clip: Clip, keys: { Key }, start: number, rate: number, prev: Track?, prevT: number? }
local tracks: { [string]: Track? } = {} -- the clip each channel is playing
local adds: { [string]: Track? } = {} -- additive reactions per channel
local clock = 0 -- the animation clock: stops during a hit-stop
local frozen = 0 -- seconds of hit-stop left
local pendingHit: { track: Track, frame: number }? = nil
local trailTrack: Track? = nil -- (28 Oct) the strike whose blade draws a trail
local freezeListeners: { (number) -> () } = {} -- (28 Oct) client/BodyAnims holds your body's swing on a hit-stop too

local cueTrack: Track? = nil -- (29 Oct) the clip whose sound cues are playing (inspects)
local cueFrame = 0
local SoundMod: any = nil

local combo: { [string]: number } = {}
local lastSwing = -10
local airAt = -10 -- (31 Oct) when client/HitFx last said a swing hits nothing (ViewAnims.airSwing)
local lastTool: string? = nil
local idleSince = 0
local nextFidget = 8 + math.random() * 4
local fidgetCount = 0

local function cooldownOf(toolId: string?): number
	local mult = State.data and State.data.swing or 1 -- Swing Speed upgrades (Input and the server use the same)
	for _, def in Config.TOOLS do
		if def.id == toolId then
			return (def.cooldown or 0.4) * mult
		end
	end
	return 0.4 * mult
end

local function frameOf(tr: Track): number
	return (clock - tr.start) * FPS * tr.rate
end

local function trackPose(tr: Track, depth: number?): Pose
	local t = frameOf(tr)
	local pose = sampleKeys(tr.keys, t)
	local prev = tr.prev
	if prev and t < FADE then
		-- blend in over what the channel was doing (still moving, so nothing snaps)
		-- (31 Oct, owner: "make the m1 smoother") over what it was REALLY showing: the old clip with its own blend still
		-- running. It used to blend from the old clip's raw keys, so a swing started while the last one was still
		-- blending in (fast clicks, a swing out of an inspect: the inspect goes home over InspectCancel first) jumped
		-- to wherever that clip's keys were, a visible pop.
		local w = t / FADE
		w = w * w * (3 - 2 * w)
		local from = if (depth or 0) < 4 then trackPose(prev, (depth or 0) + 1) else sampleKeys(prev.keys, frameOf(prev))
		if tr.clip.inspect or tr.clip.name == "InspectCancel" then
			-- (29 Oct) out of an inspect's spins (whole turns): blend the short way round, never unwinding them
			local function wrap(a: number, b: number): number
				return b + ((a - b + 180) % 360 - 180)
			end
			from = { p = from.p, r = Vector3.new(wrap(from.r.X, pose.r.X), wrap(from.r.Y, pose.r.Y), wrap(from.r.Z, pose.r.Z)), b = from.b, roll = wrap(from.roll, pose.roll) }
		end
		return lerpPose(from, pose, w)
	end
	return pose
end

local function start(clip: Clip, rate: number)
	for chName, keys in clip.ch do
		local old = tracks[chName]
		local tr: Track = { clip = clip, keys = keys, start = clock, rate = rate }
		if old and frameOf(old) < old.clip.len then
			-- (31 Oct) the old track itself, its own blend and all (trackPose); one that's done blending lets go of its
			-- own old one, so the chain never grows
			if old.prev and frameOf(old) >= FADE then
				old.prev = nil
			end
			tr.prev = old
			tr.prevT = frameOf(old)
		end
		tracks[chName] = tr
	end
	for chName, keys in clip.add or {} do
		adds[chName] = { clip = clip, keys = keys, start = clock, rate = rate }
	end
	local main = clip.main and tracks[clip.main]
	trailTrack = if clip.trail and main then main else nil
	-- (29 Oct) an inspect's sound cues follow its first channel
	local firstCh = next(clip.ch)
	cueTrack = if clip.sounds and firstCh then tracks[firstCh] else nil
	cueFrame = -1
	if clip.hit and (clip.stop or 0) > 0 and main then
		pendingHit = { track = main, frame = clip.hit }
	else
		pendingHit = nil
	end
end

export type Plan = { clip: string, contact: number, finisher: boolean, rate: number, index: number }
local lastPlan: Plan? = nil
local lastPlanAt = -10
local lastPlanTool: string? = nil

-- What your next swing with `toolId` plays: the clip, when it lands (seconds) and whether it's a finisher.
-- Asked by HitFx (to time the impact) and by ViewModel (to play it) for the same swing, so it answers the same
-- thing to both within the same moment.
function ViewAnims.plan(toolId: string?): Plan?
	local list = toolId and COMBO[toolId]
	if not list then
		return nil
	end
	local now = os.clock()
	if lastPlan and lastPlanTool == toolId and now - lastPlanAt < 0.05 then
		return lastPlan
	end
	local cd = cooldownOf(toolId)
	local i = combo[toolId :: string] or 0
	if now - lastSwing > cd + 0.75 or lastTool ~= toolId then
		i = 0 -- a pause or a new tool starts the combo over
	end
	i = i % #list + 1
	local clip = CLIPS[list[i]]
	-- faster swings (Swing Speed) play the clip faster, never slower than authored
	local rate = math.clamp((clip.chain / FPS) / math.max(cd, 0.05), 1, 2.6)
	local plan: Plan = { clip = clip.name, contact = (clip.hit or 0) / FPS / rate, finisher = clip.finisher == true, rate = rate, index = i }
	lastPlan, lastPlanAt, lastPlanTool = plan, now, toolId
	return plan
end

-- You swung: play the planned clip.
-- (28 Oct) client/BodyAnims plays your body's matching swing (what other players see) on every swing and holds it
-- on the same hit-stop
local swingListeners: { (string?, Plan) -> () } = {}
function ViewAnims.onSwing(fn: (string?, Plan) -> ())
	table.insert(swingListeners, fn)
end
function ViewAnims.onFreeze(fn: (number) -> ())
	table.insert(freezeListeners, fn)
end

-- (29 Oct) Inspect: is one playing?
function ViewAnims.inspecting(): boolean
	for _, tr in tracks do
		if tr and tr.clip.inspect and frameOf(tr) < tr.clip.len then
			return true
		end
	end
	return false
end

-- Cut an inspect short: each channel it was moving goes home over a few frames (`except`: an inspect starting over
-- keeps the channels it moves itself, blending them on).
function ViewAnims.cancelInspect(except: Clip?)
	local back = CLIPS.InspectCancel
	for chName, tr in tracks do
		if tr and tr.clip.inspect and tr.clip ~= except then
			local nt: Track = { clip = back, keys = back.ch.I, start = clock, rate = 1 }
			if frameOf(tr) < tr.clip.len then
				if tr.prev and frameOf(tr) >= FADE then
					tr.prev = nil
				end
				nt.prev = tr -- (31 Oct: the track itself, its own blend and all)
				nt.prevT = frameOf(tr)
			end
			tracks[chName] = nt
		end
	end
end

-- Inspect what you're holding (Y / the eye button). Pressing it again restarts it at once (CS2: you can spam it);
-- not mid-swing. Returns the clip it plays (nil: none), and whether it's one of the rare ones.
-- (`force`: a clip name to play, for tests)
function ViewAnims.inspect(toolId: string?, force: string?): (string?, boolean)
	if ViewAnims.busy() then
		return nil, false
	end
	local name = (toolId and INSPECT[toolId]) or "InspectItem"
	local rares = toolId and RARE[toolId]
	local rare = false
	if force and CLIPS[force] then
		name = force
		rare = rares ~= nil and table.find(rares, force) ~= nil
	elseif rares and math.random(RARE_CHANCE) == 1 then
		name = rares[math.random(#rares)]
		rare = true
	end
	local clip = CLIPS[name]
	start(clip, toolId and INSPECT_RATE[toolId] or 1) -- (blends on from wherever the last one was)
	ViewAnims.cancelInspect(clip) -- channels an earlier inspect moved that this one doesn't go home
	idleSince = os.clock()
	return name, rare
end
-- (30 Oct) an item's inspect playback speed (client/RiderPose plays other players' inspects at it too)
function ViewAnims.inspectRate(toolId: string?): number
	return toolId and INSPECT_RATE[toolId] or 1
end

-- What the inspect playing now turns about (studs from the camera; one cut short keeps its pivot while it goes home).
local lastPivot = Vector3.new(1.0, -1.5, -2.2)
function ViewAnims.inspectPivot(): Vector3
	local tr = tracks.I
	if tr and tr.clip.pivot then
		lastPivot = tr.clip.pivot
	end
	return lastPivot
end

-- (30 Oct, owner: "an equip animation for each weapon", snappy like Rivals) The draw: client/ViewModel brings the
-- hands up from below the screen with a little overshoot, and the item's flourish plays on top of that, a little
-- quicker than as a fidget so it reads as a draw: the fists crack, the scissors spin open, the sickle is tossed and
-- caught, the scythe twirls. Not mid-swing (a swing keeps its timing); it cuts an inspect short.
local EQUIP: { [string]: string } = { Hands = "FlexHands", Scissors = "SpinScissors", Sickle = "TossSickle", MegaScythe = "ScytheTwirl" }
local EQUIP_RATE = 1.45
function ViewAnims.equip(toolId: string?): string?
	if not toolId or ViewAnims.busy() then
		return nil
	end
	ViewAnims.cancelInspect()
	local name = EQUIP[toolId]
	local clip = name and CLIPS[name]
	if clip then
		start(clip, EQUIP_RATE)
	end
	-- (31 Oct, owner's vfx_sfx.zip) the Mega Scythe comes out with a ring of steel (the owner's katana draw)
	if toolId == "MegaScythe" then
		SoundMod = SoundMod or require(script.Parent.Sound)
		SoundMod.play("bladeDraw", 0.04)
	elseif toolId == "WeedWhacker" then
		-- (31 Oct, owner's vfx_sfx_all.zip) the whacker is pull-started and revved as it comes out
		SoundMod = SoundMod or require(script.Parent.Sound)
		SoundMod.play("whackerRev", 0.04)
	end
	idleSince = os.clock()
	return name
end

function ViewAnims.swing(toolId: string?): Plan?
	local plan = ViewAnims.plan(toolId)
	if not plan then
		return nil
	end
	ViewAnims.cancelInspect() -- (29 Oct) a swing cuts an inspect short
	combo[toolId :: string] = plan.index
	lastSwing = os.clock()
	lastTool = toolId
	idleSince = os.clock()
	start(CLIPS[plan.clip], plan.rate)
	if CLIPS[plan.clip].airless and os.clock() - airAt < 0.1 then
		pendingHit = nil -- (31 Oct) client/HitFx already said this one swings at nothing
	end
	for _, fn in swingListeners do
		task.spawn(fn, toolId, plan)
	end
	return plan
end

-- (31 Oct, owner: "make the scythe's m1 smoother") client/HitFx found no clump in reach of this swing: an `airless`
-- clip (the Mega Scythe's reaps) sweeps straight through instead of freezing on its contact frame. (Whichever of the
-- two runs first: the swing's start or this.)
function ViewAnims.airSwing()
	airAt = os.clock()
	local ph = pendingHit
	if ph and ph.track.clip.airless and os.clock() - lastSwing < 0.1 then
		pendingHit = nil
	end
end

-- Freeze the hands for `seconds` (a hit-stop from outside: a rare find, a felled clump).
function ViewAnims.freeze(seconds: number)
	frozen = math.max(frozen, seconds)
	for _, fn in freezeListeners do
		task.spawn(fn, frozen)
	end
end

-- Is a swing (not a fidget) still playing?
function ViewAnims.busy(): boolean
	for _, tr in tracks do
		if tr and tr.clip.hit and frameOf(tr) < tr.clip.len then
			return true
		end
	end
	return false
end

-- (29 Oct) How far into a swing the hands are, 0..1: up over its first 6 frames, back down over its last 18. The
-- Mega Scythe blends from its resting hold to the grip its reaps were made for by this.
local debugPose: { clip: Clip, frame: number }? = nil

local function blendIn(f: number, len: number): number
	local a = math.clamp(f / 6, 0, 1)
	local b = math.clamp((len - f) / 18, 0, 1)
	return math.min(a * a * (3 - 2 * a), b * b * (3 - 2 * b))
end

function ViewAnims.swingWeight(): number
	local dp = debugPose
	if dp then
		return if dp.clip.hit then blendIn(dp.frame, dp.clip.len) else 0
	end
	local best = 0
	for _, tr in tracks do
		if tr and tr.clip.hit then
			local f = frameOf(tr)
			local len = tr.clip.len
			if f < len then
				best = math.max(best, blendIn(f, len))
			end
		end
	end
	return best
end

-- Advance the animation clock (ViewModel, once per frame). `idle`: standing still with nothing to do.
function ViewAnims.update(dt: number, toolId: string?, idle: boolean)
	if frozen > 0 then
		frozen -= dt
		if frozen > 0 then
			return
		end
		dt = -frozen -- the part of this frame after the freeze ended
		frozen = 0
	end
	local before = clock
	clock += dt
	-- the hit-stop: stop exactly on the contact frame
	local ph = pendingHit
	if ph then
		local tr = ph.track
		local t1 = (clock - tr.start) * FPS * tr.rate
		if t1 >= ph.frame then
			pendingHit = nil
			local stop = (tr.clip.stop or 0) / FPS
			clock = tr.start + ph.frame / (FPS * tr.rate)
			if clock < before then
				clock = before
			end
			frozen = stop
			for _, fn in freezeListeners do
				task.spawn(fn, stop)
			end
		end
	end
	-- (29 Oct) an inspect's sound cues, as its clip passes them (silent once it's cut short or replaced)
	local ct = cueTrack
	if ct then
		local live = false
		for _, tr in tracks do
			if tr == ct then
				live = true
			end
		end
		if not live then
			cueTrack = nil
		else
			local f = frameOf(ct)
			for _, cue in ct.clip.sounds :: { { any } } do
				if cue[1] > cueFrame and cue[1] <= f then
					SoundMod = SoundMod or require(script.Parent.Sound)
					SoundMod.play(cue[2], 0.06, cue[3])
				end
			end
			cueFrame = f
		end
	end
	-- finished clips hand back to the idle pose
	for chName, tr in tracks do
		if tr and frameOf(tr) >= tr.clip.len then
			tracks[chName] = nil
		end
	end
	for chName, tr in adds do
		if tr and frameOf(tr) >= tr.clip.len then
			adds[chName] = nil
		end
	end
	-- fidgets: after a while standing around with a tool you can fidget with
	local now = os.clock()
	if not idle or ViewAnims.busy() then
		idleSince = now
	elseif toolId and FIDGETS[toolId] and now - idleSince > nextFidget and not next(tracks) then
		local list = FIDGETS[toolId]
		fidgetCount += 1
		start(CLIPS[list[(fidgetCount - 1) % #list + 1]], 1)
		idleSince = now
		nextFidget = 9 + math.random() * 7
	end
end

-- Breathing: the hands rise and fall a little out of step with each other (always on, smaller while swinging).
local function breath(chName: string): Pose
	local t = os.clock()
	local w = 2 * math.pi / 3.4
	if chName == "R" then
		return P(0, 0.05 * math.sin(t * w), 0.03 * math.sin(t * w + 0.6), 1.4 * math.sin(t * w + 0.3), 0.6 * math.sin(t * 0.37), 0.8 * math.sin(t * w * 0.5))
	elseif chName == "L" then
		local s = t * w + 0.9
		return P(0, 0.045 * math.sin(s), 0.03 * math.sin(s + 0.6), 1.2 * math.sin(s + 0.3), -0.6 * math.sin(t * 0.33), -0.8 * math.sin(s * 0.5))
	end
	return ZERO
end

-- (tuning and proof shots) hold one clip on one frame: ViewModel sets it from its DebugClip / DebugFrame attributes
-- (debugPose is declared above ViewAnims.swingWeight)
function ViewAnims.setDebug(clipName: string?, frame: number?)
	debugPose = if clipName and CLIPS[clipName] then { clip = CLIPS[clipName], frame = frame or 0 } else nil
end

-- (28 Oct) Is a blade mid-strike (its clip's trail window)? client/ViewModel draws the blade's trail while it is.
function ViewAnims.trailOn(): boolean
	local dp = debugPose
	if dp then
		local w = dp.clip.trail
		return w ~= nil and dp.frame >= w[1] and dp.frame <= w[2]
	end
	local tr = trailTrack
	if not tr or tracks[tr.clip.main or ""] ~= tr then
		return false
	end
	local w = tr.clip.trail :: { number }
	local f = frameOf(tr)
	return f >= w[1] and f <= w[2]
end

-- (31 Oct) How far the left hand has let go of a two-handed item, 0..1: the L channel's roll (0..100) while a clip
-- with letGo plays it (the scythe's inspects), or while one is going home (InspectCancel).
function ViewAnims.letGo(): number
	local dp = debugPose
	local tr = tracks.L
	local clip = if dp then dp.clip elseif tr then tr.clip else nil
	if not clip or not (clip.letGo or clip.name == "InspectCancel") then
		return 0
	end
	return math.clamp(ViewAnims.pose("L").roll / 100, 0, 1)
end

-- The channel's pose now (offset from the rest pose).
function ViewAnims.pose(chName: string): Pose
	local dp = debugPose
	if dp then
		local keys = dp.clip.ch[chName]
		local held = if keys then sampleKeys(keys, dp.frame) else ZERO
		local ad = dp.clip.add and dp.clip.add[chName]
		return if ad then addPose(held, sampleKeys(ad, dp.frame)) else held
	end
	local tr = tracks[chName]
	local pose = if tr then trackPose(tr) else ZERO
	local ad = adds[chName]
	if ad then
		pose = addPose(pose, sampleKeys(ad.keys, frameOf(ad)))
	end
	local calm = if ViewAnims.busy() then 0.35 else 1
	local b = breath(chName)
	if b ~= ZERO then
		pose = addPose(pose, { p = b.p * calm, r = b.r * calm, b = Vector3.zero, roll = 0 })
	end
	return pose
end

function ViewAnims.hasClip(toolId: string?): boolean
	return toolId ~= nil and COMBO[toolId] ~= nil
end

-- (tests and the dev panel) every clip by name
ViewAnims.CLIPS = CLIPS

-- (30 Oct) for client/RiderPose: a clip's channel at a frame, and the clip a channel is playing now (with its frame),
-- so everyone else sees your third-person scythe move the way your first-person one does
function ViewAnims.sample(clipName: string, chName: string, frame: number): Pose?
	local clip = CLIPS[clipName]
	local keys = clip and clip.ch[chName]
	return if keys then sampleKeys(keys, frame) else nil
end
function ViewAnims.playing(chName: string): (string?, number)
	local tr = tracks[chName]
	if not tr then
		return nil, 0
	end
	local f = frameOf(tr)
	if f >= tr.clip.len then
		return nil, 0
	end
	return tr.clip.name, f
end
-- (tuning in a playtest, from the command bar or Studio tools) the clip helpers, so a clip can be rebuilt live
ViewAnims.dev = { define = define, K = K, P = P, mirror = mirrorClip, COMBO = COMBO, FIDGETS = FIDGETS }

State.on("hitstop", function(duration: number?)
	if duration and duration > 0 then
		ViewAnims.freeze(duration)
	end
end)

return ViewAnims
