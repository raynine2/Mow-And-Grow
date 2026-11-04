-- GRASS TITAN (Legendary). The card: a giant mossy boulder-and-vine foot with daisies stomping a striped lawn, a green
-- shockwave ring. Gimmick: Titan Stomp, landing from a jump hits every clump within 12 studs twice (every 4 s).
-- Built from the ForgeGUI props (gt_foot, gt_slab, gt_boulder, gt_crown), the ForgeGUI stone-rune emblem and the VFX
-- Forge layers of Loop_GrassTitan (Pebbles, Moss, Rise, Quake), in deep emerald on a dark pool so it doesn't wash out
-- into the lawn (v6c):
--   - the titan's foot: a big mossy stone foot hovering beside you on your left, low and a little behind (out of the
--     camera's line), toes pointing away from you. While the stomp is ready it lifts every 5 s and slams down onto
--     the reach ring (a green shockwave there, dust, a ripple along the ring), then floats back. On a Titan Stomp it
--     slams straight down at once, and the shockwave runs out to the full reach
--   - six standing rune stones (menhirs) round you, runes facing you, linked to the emblem by glowing rune lines. They
--     rise out of the ground as the stomp recharges and their runes pulse when it's ready; a stomp crashes them back
--     into the ground. The ones between the camera and you stay sunk, so they frame you instead of hiding you
--   - chunky cracked boulder boots on both feet (lying on their sides: the cracked grey stone on top, moss and
--     daisies facing out), a vine winding up each leg out of them; their cracks glow while the stomp is ready. Every
--     running step lands like a quake: a green ring, dust and glowing cracks under that boot
--   - the stone rune crown floating over your head: a low stone ring with four thick rune slabs standing on it
--   - the stone-rune emblem on a dark emerald pool, glowing green cracks across it (pulsing while the stomp is ready),
--     three thin emerald line rings turning over it, green light rising off it and round your body, and the stomp's
--     reach (12 studs) drawn as a crisp pulsing line with a dark edge (a dim ring growing back out to it while the
--     stomp recharges)
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local LOOP = "Loop_GrassTitan"
	local EMERALD = rgb(40, 200, 110) -- the glowing cracks' deep emerald: the aura's own colour
	local JADE = rgb(150, 245, 180) -- pale jade: bright cores and lines
	local LEAF = rgb(90, 215, 120)
	local DEEP = rgb(12, 58, 36) -- the dark emerald pool and the dark edges
	local VINE_L, VINE_D = rgb(150, 225, 95), rgb(62, 140, 50)
	local DIM = rgb(36, 84, 58) -- the reach ring while the stomp recharges
	local DARK = rgb(95, 100, 95) -- the boots' tint while it recharges (on props that can take a tint)
	local STONE = rgb(245, 240, 215) -- (the foot's tint: mossy grey-green, warmed so the stone never reads blue)
	local DUST = K.seq(rgb(150, 155, 135), rgb(95, 100, 88)) -- (the quake dust: grey-moss, not a yellow cloud)
	local RADIUS, COOLDOWN = 12, 4 -- server/ClassPerks STOMP_RADIUS, STOMP_COOLDOWN
	-- a boulder boot, lying on its side: X up, Y out to the side (the moss), Z heel to toe
	local BOOT = Vector3.new(1.9, 2.3, 3.1)
	local FOOT_L = 6 -- the titan's foot, heel to toe
	local WIND, DROP, HOLD, BACK = 0.55, 0.13, 0.4, 1.0 -- a slam: lift, drop, stay down, float back
	local IDLE_EVERY = 5 -- while the stomp is ready (and you stand) the foot slams every 5 s
	local RS = 9 -- the rune stones' ring
	local SLAB_H = { 5.0, 5.6, 4.8, 5.4, 5.0, 5.7 } -- their heights
	local CRASH = 0.35 -- the rune stones crashing into the ground after a stomp

	-- a value worked out once per frame (several pieces ask for it)
	local function once(base: (any) -> any): (any) -> any
		local lastT, last = -1, nil
		return function(f)
			if f.t ~= lastT then
				lastT = f.t
				last = base(f)
			end
			return last
		end
	end
	-- a prop's SurfaceAppearance (tint, glow), if it has one
	local function saOf(p: BasePart): Instance?
		return p:FindFirstChildOfClass("SurfaceAppearance")
	end
	local function setSA(sa: Instance?, prop: string, v: any)
		if sa then
			pcall(function()
				(sa :: any)[prop] = v
			end)
		end
	end
	-- a looping layer at its own rate (the aura keeps it there)
	local function setRate(a: any, list: { ParticleEmitter }, rate: number)
		for _, e in list do
			e.Rate = rate
			for _, em in a.emitters do
				if em.e == e then
					em.rate = rate
				end
			end
		end
	end
	-- beam transparencies, made once (they're swapped in as things pulse)
	local TR = {}
	for i = 0, 20 do
		TR[i] = NumberSequence.new(i / 20)
	end
	local function trOf(x: number): NumberSequence
		return TR[math.clamp(math.floor(x * 20 + 0.5), 0, 20)]
	end
	-- how far the foot and crown drop `dt` seconds after a running step lands (a small jolt)...
	local function jolt(dt: number): number
		if dt < 0 or dt > 0.5 then
			return 0
		end
		return 0.2 * math.exp(-dt * 9) * math.sin(dt * 34)
	end
	-- ...and how the crown jumps after a stomp lands (0 to 1: up, then bouncing back)
	local function bounce(dt: number): number
		local k = dt / 1.1
		if k < 0 or k >= 1 then
			return 0
		end
		if k < 0.14 then
			return math.sin(k / 0.14 * math.pi / 2)
		end
		return math.exp(-(k - 0.14) * 5) * math.cos((k - 0.14) * 14)
	end

	return function()
		local a = H.aura(H.RANK.Legendary, EMERALD)
		local lastStomp = -100 -- (os.clock of the last Titan Stomp: everything lights up again over COOLDOWN)
		local crashAt = -100 -- when that stomp's foot landed (the rune stones crash)
		local stepAt = -100 -- the last running step (the foot and crown jolt)
		local function recharge(t: number): number
			return math.clamp((t - lastStomp) / COOLDOWN, 0, 1)
		end
		local feetCF = once(function(f): CFrame
			return CFrame.new(f.feet)
		end)

		-- THE GROUND: a dark emerald pool (so the green glows against it), a soft emerald glow, the stone-rune emblem
		-- (grows in), three thin line rings turning over it
		H.glowDisc(a, 15.5, BFX.glow, DEEP, 0.3, 0, 0.05, 1)
		H.glowDisc(a, 12.5, BFX.glow, EMERALD, 0.66, 0, 0.07, 1)
		H.sigil(a, 10, T.embGrassTitan, WHITE, 0.18, 0, 0.12, 0.9, 1.1)
		H.glowRing(a, 4.45, JADE, 0.5, 0.3, 0.15, 1)
		H.glowRing(a, 5.2, EMERALD, 0.4, -0.2, 0.16, 1)
		H.glowRing(a, 6.1, LEAF, 0.5, 0.14, 0.17, 1)
		-- glowing green cracks running out across the emblem's stone (they pulse while the stomp is ready)
		local cracks: { BasePart } = {}
		for k = 1, 5 do
			local a0 = k / 5 * math.pi * 2 + 0.35
			local pts = {}
			for j = 0, 3 do
				local ang = a0 + (if j == 0 then 0 else 0.2 * math.sin(k * 3.7 + j * 2.1))
				local r = 0.9 + j * 1.13
				pts[j + 1] = Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
			end
			for j = 1, 3 do
				local p0, p1 = pts[j], pts[j + 1]
				local seg = H.solid(a.model, Vector3.new(0.17 - 0.03 * j, 0.04, (p1 - p0).Magnitude + 0.06), EMERALD, Enum.Material.Neon)
				local off = CFrame.new(0, 0.155, 0) * CFrame.lookAt((p0 + p1) / 2, p1)
				K.move(a, seg, function(f)
					return feetCF(f) * off
				end)
				table.insert(cracks, seg)
			end
		end
		-- green light rising off the emblem, and closer in round your body
		local rise = H.layer(a, LOOP, "Rise", H.feetPiece(a, Vector3.new(6.4, 0.2, 6.4), 0.3))
		local bodyRise = H.layer(a, LOOP, "Rise", H.feetPiece(a, Vector3.new(2.8, 0.2, 2.8), 0.3))
		setRate(a, bodyRise, 10)
		for _, list in { rise, bodyRise } do
			for _, e in list do
				e.ShapePartial = 0 -- (as H.updraft: a flat cone, so the streaks rise off the whole circle)
				e.Color = K.seq(rgb(195, 255, 215), EMERALD)
				e.LightEmission = 0.4
				K.bright(e, 1.5)
			end
		end
		-- the stomp's reach: a soft line with a dark edge (dim and growing back out while the stomp recharges), and a
		-- crisp pulsing line on top while it's ready (the readiness and pulse jobs)
		local reachDark = H.glowRing(a, RADIUS + 0.15, DEEP, 0.35, 0, 0.13, 1)
		local reach, reachImgs = H.glowRing(a, RADIUS, JADE, 0.45, 0, 0.16, 1)
		local line = K.beamRing(H.feetPiece(a, Vector3.new(0.2, 0.05, 0.2), 0.19), RADIUS, 0.26, K.seq(JADE), 3, 0.15, 36, false)

		-- THE BOULDER BOOTS (the card's stomping foot): chunky cracked rock lying on its side (the cracked grey stone on
		-- top, moss and daisies facing out), each with its own light and sparks for the readiness, a vine winding up the
		-- leg out of it, pebbles crumbling off it and a dust holder on the ground under it
		local boots = {}
		local quakes = {}
		for i, foot in { "RightFoot", "LeftFoot" } do
			local side = if i == 1 then 1 else -1
			local roll = CFrame.Angles(0, 0, -side * math.pi / 2) -- (its moss side faces out)
			local footAt = once(function(f): CFrame
				local l = H.limb(f, foot)
				if l then
					return l.CFrame * CFrame.new(side * 0.45, 0.72 - l.Size.Y / 2, -0.2)
				end
				return f.root * CFrame.new(side * 0.95, -2.28, -0.2)
			end)
			local boot = H.prop(a.body, "gt_boulder", BOOT.Z)
			boot.Size = BOOT
			K.move(a, boot, function(f)
				return footAt(f) * roll
			end)
			local sparks = E(boot, { tex = FX.spark, colors = K.seq(JADE, EMERALD), rate = 4, life = { 0.4, 0.8 }, speed = { 0.6, 1.6 }, size = 0.22, grow = true, accel = Vector3.new(0, 2.5, 0), spread = 180, light = 0.6, bright = 1.3 })
			local light = Instance.new("PointLight")
			light.Color = EMERALD
			light.Range = 7
			light.Brightness = 1.6
			light.Shadows = false
			light.Parent = boot
			H.detail(a, sparks, light)
			H.layer(a, LOOP, "Pebbles", boot, false, 0.7)
			local quakeHold = K.piece(a.model, Vector3.new(1.6, 0.2, 1.6))
			K.move(a, quakeHold, function(f)
				local p = footAt(f).Position
				return CFrame.new(p.X, f.feet.Y - 0.1, p.Z)
			end)
			local quake = H.layer(a, LOOP, "Quake", quakeHold)
			for _, e in quake do
				table.insert(quakes, e)
			end
			local vineHold = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, vineHold, footAt)
			local pts = {}
			for k = 0, 6 do
				local u = k / 6
				local th = side * u * math.pi * 2.3 + 0.5
				local r = 0.66 - 0.12 * u
				pts[k + 1] = Vector3.new(math.cos(th) * r, 0.8 + u * 1.6, math.sin(th) * r)
			end
			for _, b in H.chain(vineHold, pts, { colors = K.seq(VINE_L, VINE_D), w0 = 0.34, w1 = 0.14, tex = T.vineStrip, texLen = 1.2, light = 0.15, bright = 1.2 }) do
				H.detail(a, b)
			end
			local sa = saOf(boot)
			table.insert(boots, { part = boot, at = footAt, sparks = sparks, light = light, quake = quake, sa = sa })
		end
		-- the boots grow out of the ground round your feet when the aura forms
		local grown = false
		H.job(a, function(self, f)
			local life = f.t - self.born
			if life > 0.8 then
				if not grown then
					grown = true
					for _, b in boots do
						b.part.Size = BOOT
					end
				end
				return
			end
			grown = false
			local k = math.max(0.05, ease(life / 0.5))
			for _, b in boots do
				b.part.Size = BOOT * k
			end
		end)
		-- the cracks a running step (or a slam) leaves: two sets of thin glowing fissures, left where they landed and
		-- fading
		local stepCracks = {}
		for c = 1, 2 do
			local cr = { at = CFrame.new(0, -1000, 0), born = -100, tr = 1, parts = {} }
			for s = 1, 5 do
				local len = 0.8 + 0.3 * ((s * 7 + c) % 4)
				local p = H.solid(a.model, Vector3.new(0.13, 0.05, len), EMERALD, Enum.Material.Neon)
				p.Transparency = 1
				local off = CFrame.Angles(0, s / 5 * math.pi * 2 + c * 0.6 + 0.3 * math.sin(s * 3.1), 0) * CFrame.new(0, 0, -len / 2 - 0.3)
				K.move(a, p, function(f)
					return cr.at * off
				end)
				table.insert(cr.parts, p)
			end
			stepCracks[c] = cr
		end
		H.job(a, function(self, f)
			for _, cr in stepCracks do
				local age = f.t - cr.born
				local tr = if age < 0.75 then 0.15 + 0.85 * smooth(age / 0.75) else 1
				if math.abs(tr - cr.tr) > 0.04 or (tr == 1 and cr.tr ~= 1) then
					cr.tr = tr
					for _, p in cr.parts do
						p.Transparency = tr
					end
				end
			end
		end)

		-- THE TITAN'S FOOT (ForgeGUI, toes at its -Z, sole down): solid mossy stone with glowing cracks, hovering beside
		-- you on your left, low and a little behind, toes pointing away from you, swaying. A slam: it lifts out over the
		-- reach ring, drops onto it, stays down a moment and floats back (a Titan Stomp: straight down at once). It
		-- comes down out of the sky when the aura forms.
		local foot = H.prop(a.body, "gt_foot", FOOT_L)
		local fs = H.propSize("gt_foot", FOOT_L)
		local footSA = saOf(foot)
		setSA(footSA, "Color", STONE)
		local TURN = CFrame.Angles(0, math.pi / 2, 0) -- (toes out to your left: side on to the cameras, it reads as a foot)
		local function pose(p: Vector3, tilt: number): CFrame
			return CFrame.new(p) * TURN * CFrame.Angles(tilt, 0, 0)
		end
		local HOVER = pose(Vector3.new(-5.0, 3.8, 3.0), math.rad(10)) -- (toes up a little: poised)
		local RAISED = pose(Vector3.new(-9.5, 7.0, 4.2), math.rad(22))
		local DOWN = pose(Vector3.new(-11.0, fs.Y * 0.5 - 0.1, 4.6), 0) -- (flat on the reach ring)
		local slamAt, slamWind, slamBig, landed = -100, WIND, false, true
		local nextIdle = a.born + 1.6
		local function slamOver(t: number): boolean
			return t - slamAt >= slamWind + DROP + HOLD + BACK
		end
		local footCF = once(function(f): CFrame
			local kf = ease((f.t - a.born - 0.05) / 0.8)
			local p = f.t - slamAt
			local cf
			if p < 0 or slamOver(f.t) then
				cf = HOVER * CFrame.new(0, 0.2 * math.sin(f.t * 1.2), 0) * CFrame.Angles(0.04 * math.sin(f.t * 0.9), 0, 0.03 * math.sin(f.t * 0.7))
			elseif p < slamWind then
				cf = HOVER:Lerp(RAISED, smooth(p / slamWind))
			elseif p < slamWind + DROP then
				local k = (p - slamWind) / DROP
				cf = (if slamWind > 0 then RAISED else HOVER):Lerp(DOWN, k * k)
			elseif p < slamWind + DROP + HOLD then
				cf = DOWN
			else
				cf = DOWN:Lerp(HOVER, smooth((p - slamWind - DROP - HOLD) / BACK))
			end
			return CFrame.new(f.feet) * f.yaw * CFrame.new(0, 12 * (1 - kf) - 0.5 * jolt(f.t - stepAt), 0) * cf
		end)
		K.move(a, foot, footCF)
		local footGlow = E(foot, { tex = BFX.glow, colors = K.seq(EMERALD, DEEP), rate = 2, life = { 0.8, 1.2 }, speed = { 0, 0 }, size = 3, spread = 0, light = 0.35, bright = 1, lock = true, trans = ns(0, 1, 0.4, 0.8, 1, 1) })
		K.addEmitter(a, footGlow)
		local pebbles = H.layer(a, LOOP, "Pebbles", foot)
		H.layer(a, LOOP, "Moss", foot, false, 0.9)
		-- dust where it lands
		local dustHold = K.piece(a.model, Vector3.new(5, 0.3, 3.5))
		K.move(a, dustHold, function(f)
			local p = footCF(f).Position
			return CFrame.new(p.X, f.feet.Y, p.Z) * f.yaw
		end)
		local footDust = H.layer(a, LOOP, "Quake", dustHold, false, 1.4)
		for _, list in { quakes, footDust } do
			for _, e in list do
				e.Color = DUST
				e.LightEmission = 0
			end
		end
		-- your own camera behind you: the foot fades a little (it's out of the camera's line anyway)
		local faded = false
		H.job(a, function(self, f)
			local cam = workspace.CurrentCamera
			local behind = f.player ~= nil and f.player == H.player and cam ~= nil and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3
			if behind ~= faded then
				faded = behind
				foot.LocalTransparencyModifier = if behind then 0.25 else 0
			end
		end)

		-- THE RUNE STONES (ForgeGUI menhirs, the rune on their -Z face): six round you, runes facing you, each linked to
		-- the emblem by a glowing rune line. They stand while the stomp is ready (runes pulsing), crash into the ground
		-- when a stomp lands and rise again as it recharges; they sink while you run, and the ones on the camera's side
		-- of you stay down so they never hide you. They rise out of the ground one after another when the aura forms.
		local camDir = once(function(f): Vector3 -- (from you towards the camera, flat)
			local cam = workspace.CurrentCamera
			if not cam then
				return Vector3.zero
			end
			local d = cam.CFrame.Position - f.feet
			d = Vector3.new(d.X, 0, d.Z)
			if d.Magnitude < 1 then
				return Vector3.zero
			end
			return d.Unit
		end)
		local standing = once(function(f): number -- (how far all of them stand, before the camera's say)
			local dl = f.t - crashAt
			local r
			if f.t >= lastStomp and dl < 0 then
				r = 1 -- (the foot is still coming down)
			elseif dl >= 0 and dl < CRASH then
				r = 1 - smooth(dl / CRASH)
			else
				r = smooth((recharge(f.t) - 0.2) / 0.8)
			end
			return r * smooth((f.calm - 0.25) / 0.6)
		end)
		local spokeHold = H.feetPiece(a, Vector3.new(0.2, 0.05, 0.2), 0.16)
		local slabs = {}
		for i = 1, 6 do
			local th = (i - 0.5) / 6 * math.pi * 2
			local slab = H.prop(a.model, "gt_slab", SLAB_H[i])
			local ss = H.propSize("gt_slab", SLAB_H[i])
			local dir = Vector3.new(math.cos(th), 0, math.sin(th))
			local turn = CFrame.Angles(0.05 * math.sin(i * 2.3), math.pi / 2 - th, 0.05 * math.cos(i * 1.7)) -- (-Z towards you)
			K.move(a, slab, function(f)
				local cd = camDir(f)
				local camK = 1 - smooth((dir.X * cd.X + dir.Z * cd.Z - 0.15) / 0.5)
				local formK = math.min(1, ease((f.t - a.born - 0.25 - 0.07 * i) / 0.7))
				local up = standing(f) * camK * formK
				local dl = f.t - crashAt - 0.02 * i
				local shake = if dl > 0 and dl < CRASH then 0.12 * math.sin(dl * 60) else 0
				local y = f.feet.Y - 0.45 + ss.Y / 2 - (ss.Y + 0.6) * (1 - up)
				return CFrame.new(f.feet.X + dir.X * RS + shake, y, f.feet.Z + dir.Z * RS) * turn
			end)
			-- the rune's glow on its face (lit while the stomp is ready)
			local glowAt = H.att(slab, Vector3.new(0, ss.Y * 0.08, -ss.Z / 2 - 0.15))
			local glow = E(glowAt, { tex = BFX.glow, colors = K.seq(JADE, EMERALD), rate = 1.2, life = { 0.8, 1.2 }, speed = { 0, 0 }, size = 2.2, spread = 0, light = 0.4, bright = 1, lock = true, trans = ns(0, 1, 0.4, 0.7, 1, 1) })
			H.detail(a, glow)
			-- the rune line from the emblem's rim to its foot (it follows the stone down into the ground)
			local rim = H.att(spokeHold, Vector3.new(dir.X * 5.3, 0, dir.Z * 5.3))
			local base = H.att(slab, Vector3.new(0, -ss.Y / 2 + 0.55, -ss.Z / 2 - 0.05))
			local spoke = H.beam(rim, base, { colors = K.seq(JADE, EMERALD), w0 = 0.5, w1 = 0.6, tex = T.runeStrip, texLen = 2.2, texSpeed = 1.2, light = 0.4, bright = 1.3, trans = TR[5] })
			table.insert(slabs, { part = slab, sa = saOf(slab), glow = glow, spoke = spoke })
		end

		-- THE CROWN: the stone rune crown floating over your head, turning slowly: its ring kept low (its own thin
		-- stones squashed to stubs) with four thick rune slabs standing on it, runes glowing outwards, and gem glints;
		-- it drops in from above when the aura forms and jumps when a stomp lands
		local CROWN = 3.0
		local crown = H.prop(a.body, "gt_crown", CROWN)
		local cs = H.propSize("gt_crown", CROWN)
		local ch = cs.Y * 0.45
		crown.Size = Vector3.new(cs.X, ch, cs.Z)
		setSA(saOf(crown), "EmissiveStrength", 2)
		local crownAt = once(function(f): CFrame
			local k = ease((f.t - a.born - 0.1) / 0.6)
			local hop = 0.5 * bounce(f.t - crashAt) + 0.6 * jolt(f.t - stepAt)
			local up = ch * 0.5 + 0.35 + 0.1 * math.sin(f.t * 1.5) + 3 * (1 - k) + hop
			return CFrame.new(f.head + Vector3.new(0, up, 0)) * f.yaw * CFrame.Angles(0.05 * math.sin(f.t * 1.1), f.t * 0.5, 0.05 * math.cos(f.t * 0.9))
		end)
		K.move(a, crown, crownAt)
		for i = 1, 4 do
			local th = (i - 1) / 4 * math.pi * 2 + math.pi / 4
			local st = H.prop(a.body, "gt_slab", 1.4)
			local sz = H.propSize("gt_slab", 1.4)
			local off = CFrame.new(math.cos(th) * 1.2, ch * 0.5 + sz.Y * 0.5 - 0.15, math.sin(th) * 1.2) * CFrame.Angles(0, -th - math.pi / 2, 0) * CFrame.Angles(-0.12, 0, 0)
			K.move(a, st, function(f)
				return crownAt(f) * off
			end)
			setSA(saOf(st), "EmissiveStrength", 2.5)
		end
		local band = K.piece(a.body, Vector3.new(2.7, 0.4, 2.7))
		K.move(a, band, function(f)
			return crownAt(f) * CFrame.new(0, -ch * 0.5, 0)
		end)
		local glints = E(band, { tex = T.glint, flip = 4, colors = K.seq(WHITE, JADE), rate = 2.5, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 0.5, spread = 180, light = 0.6, bright = 1.4 })
		K.addEmitter(a, glints)
		H.detail(a, glints)

		-- TITAN STOMP READINESS: dark right after a stomp, lighting up as it recharges (the reach ring grows back out to
		-- 12 studs, dim; the rune stones climb out of the ground), then bright again when it's ready (the reach
		-- flashes, the runes, cracks and foot glow, the boots spark)
		local shown = -1
		H.job(a, function(self, f)
			local c = recharge(f.t)
			local ready = c >= 1
			if not ready then
				local d = (2.5 + (RADIUS - 2.5) * smooth(c)) * 2 / 0.92
				reach.Size = Vector3.new(d, 0.05, d)
				reachDark.Size = Vector3.new(d + 0.33, 0.05, d + 0.33)
			end
			local q = if ready then 1 else math.floor(c * 24) / 24
			if q == shown then
				return
			end
			local first = shown < 0
			shown = q
			local col = DIM:Lerp(JADE, q * q)
			for _, img in reachImgs do
				img.ImageColor3 = col
			end
			if ready then
				local d = RADIUS * 2 / 0.92
				reach.Size = Vector3.new(d, 0.05, d)
				reachDark.Size = Vector3.new(d + 0.33, 0.05, d + 0.33)
			end
			for _, b in boots do
				b.light.Brightness = if ready then 1.6 else 0.15 + 0.5 * q
				b.sparks.Rate = if ready then 4 else 0
				setSA(b.sa, "Color", if ready then WHITE else DARK:Lerp(WHITE, q * 0.5))
			end
			for _, s in slabs do
				s.glow.Rate = if ready then 1.2 else 0
				s.spoke.Transparency = if ready then TR[5] else trOf(0.85 - 0.3 * q)
			end
			if not ready then -- (while it's ready the pulse job makes them glow)
				for _, s in slabs do
					setSA(s.sa, "EmissiveStrength", 0.4 + q)
				end
				for _, b in boots do
					setSA(b.sa, "EmissiveStrength", 0.4 + q)
				end
				setSA(footSA, "EmissiveStrength", 0.5 + 1.2 * q)
			end
			footGlow.Rate = if ready then 2 else 0.8
			if ready and not first then
				K.pulse(f.feet, RADIUS * 2 - 5, RADIUS * 2, EMERALD, 0.5, 0.2)
				for _, b in boots do
					b.sparks:Emit(10)
				end
				for _, s in slabs do
					s.glow:Emit(2)
				end
				footGlow:Emit(3)
				self.lightKick = 1.8
			end
		end)
		-- while it's ready: the emblem's cracks and the crisp reach line pulse, the rune stones', boots' and foot's
		-- cracks glow and pulse with them (all dimmer while you run, like the ground). Only written when it changes.
		local pulseKey = -100
		H.job(a, function(self, f)
			local ready = recharge(f.t) >= 1
			local lvl = if ready then math.floor((0.5 + 0.5 * math.sin(f.t * 3.4)) * 8 + 0.5) else -1
			local g = math.floor((0.5 + 0.5 * f.calm) * 4 + 0.5)
			local key = lvl * 10 + g
			if key == pulseKey then
				return
			end
			pulseKey = key
			local k = if ready then lvl / 8 else 0
			local gk = g / 4
			local crackTr = 1 - (1 - (if ready then 0.55 - 0.45 * k else 0.75)) * gk
			for _, p in cracks do
				p.Transparency = crackTr
			end
			local lineTr = if ready then trOf(1 - (1 - (0.45 - 0.35 * k)) * gk) else TR[20]
			for _, b in line do
				b.Transparency = lineTr
			end
			if ready then
				local em = 1.8 + 1.6 * k
				for _, s in slabs do
					setSA(s.sa, "EmissiveStrength", em)
				end
				for _, b in boots do
					setSA(b.sa, "EmissiveStrength", em)
				end
				setSA(footSA, "EmissiveStrength", em)
			end
		end)

		-- THE SLAMS. While the stomp is ready and you stand, the foot slams onto the reach ring every 5 s; a Titan Stomp
		-- slams it straight down at once. As it lands: a shockwave and dust where it hits, cracks in the ground; for a
		-- Titan Stomp the shockwave runs out to the full reach, the rune stones crash and pebbles fly
		H.job(a, function(self, f)
			if f.t < nextIdle or not landed or not slamOver(f.t) or recharge(f.t) < 1 or f.calm < 0.6 then
				return
			end
			slamAt, slamWind, slamBig, landed = f.t, WIND, false, false
			nextIdle = f.t + IDLE_EVERY
		end)
		H.job(a, function(self, f)
			if landed or f.t < slamAt + slamWind + DROP then
				return
			end
			landed = true
			local p = footCF(f).Position
			local hit = Vector3.new(p.X, f.feet.Y, p.Z)
			K.pulse(hit, 1, if slamBig then 12 else 8, EMERALD, 0.5, 0.1)
			for _, e in footDust do
				e:Emit(if slamBig then 14 else 7)
			end
			for _, e in pebbles do
				e:Emit(if slamBig then 8 else 4)
			end
			local cr = stepCracks[1]
			cr.at = CFrame.new(hit.X, f.feet.Y - 0.2, hit.Z) * CFrame.Angles(0, (f.t * 3.7) % (math.pi * 2), 0)
			cr.born = f.t
			if slamBig then
				self.lightKick = 3
				K.pulse(f.feet, 1, RADIUS * 2, EMERALD, 0.7, 0)
				K.pulse(f.feet, 1, 10, JADE, 0.4, 0.3)
				for _, e in quakes do
					e:Emit(10)
				end
				for _, e in rise do
					e:Emit(10)
				end
			else
				K.pulse(f.feet, RADIUS * 2 - 3, RADIUS * 2 + 1, JADE, 0.6, 0.3) -- (a ripple along the reach ring)
				self.lightKick = 1.5
			end
		end)
		-- every running step lands like a quake, left and right in turn: a green ring, dust and glowing cracks under
		-- that boot (the cracks stay where you stepped)
		local nextFoot = 1
		H.every(a, 0.4, function(self, f)
			if f.calm > 0.5 then
				return
			end
			nextFoot = 3 - nextFoot
			local b = boots[nextFoot]
			local p = b.at(f).Position
			K.pulse(Vector3.new(p.X, f.feet.Y, p.Z), 1, 7, EMERALD, 0.45, 0.3)
			for _, e in b.quake do
				e:Emit(4)
			end
			local cr = stepCracks[nextFoot]
			cr.at = CFrame.new(p.X, f.feet.Y - 0.2, p.Z) * CFrame.Angles(0, (f.t * 3.7) % (math.pi * 2), 0)
			cr.born = f.t
			stepAt = f.t
		end)

		H.shell(a, K.seq(JADE, EMERALD), 6, 1)
		-- running: a soft emerald trail at your feet (not a white streak)
		local trailAt = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		K.trail(trailAt, Vector3.new(-0.9, 0.15, 0), Vector3.new(0.9, 0.15, 0), K.seq(EMERALD, DEEP), 0.5, 0.35)
		K.move(a, trailAt, function(f)
			return CFrame.new(f.feet) * f.yaw
		end)
		K.outline(a, EMERALD, 0.35)
		K.light(a, EMERALD, 1.2, 14)
		H.lightJob(a, 0.08)
		-- the Titan Stomp: the foot slams straight down (the slam jobs play its landing)
		H.gimmick(a, { stomp = true }, 8, function(self, d)
			local now = os.clock()
			lastStomp = now
			crashAt = now + DROP
			slamAt, slamWind, slamBig, landed = now, 0, true, false
			nextIdle = now + COOLDOWN + 2
			self.lightKick = 1.6
		end)
		-- the entrance: a quake (the boots grow, the rune stones rise out of the ground, the crown drops in, the titan's
		-- foot comes down out of the sky and soon slams) and a shockwave out to the reach
		a.onForm = function(self, feet)
			K.pulse(feet, 1, RADIUS * 2, EMERALD, 0.9, 0)
			K.pulse(feet, 1, 12, JADE, 0.55, 0.25)
			for _, e in quakes do
				e:Emit(4)
			end
			for _, b in boots do
				b.sparks:Emit(8)
			end
			nextIdle = os.clock() + 1.3
			self.lightKick = 3
			pcall(function()
				local cam = workspace.CurrentCamera
				if cam and (cam.CFrame.Position - feet).Magnitude < 40 then
					K.Sound.play("bossThud", 0.05, 0.3)
				end
			end)
		end
		return a
	end
end
