-- LAWN LEGEND (Mythic) - the card: the legend's crown, a green wreath of leaves set with red roses and a lucky
-- four-leaf clover. Gimmick: Hot Streak, each clump you cut in a streak adds +5% power (up to +60%) and it fades 2.5 s
-- after you stop, so the class burns hotter the longer the streak. Aura: the crown floating on your head (twelve
-- leaves, four petal roses, the clover and a gold gem), its leaves turning fire-gold one per +5% of your streak; the
-- same wreath as a great halo turning behind you (leaves, six petal roses, a gold ring) with fire licking round it as
-- the streak builds; wings of fire (five flaming feathers a side, ~9 studs tip to tip, crimson at the root to gold at
-- the tips) that unfold when the aura forms and blaze harder with the streak; a fire spiral coiling round you from your
-- feet to twice your height; fire round your feet; a big rose-wreath sigil with a heart of fire; embers and rose
-- petals; a heartbeat. Rose red, leaf green, gold and flame (the card's own colours; its pink backdrop is the Mythic
-- rarity's colour, so it isn't used).
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local CRIM = rgb(176, 16, 42)
	local RED = rgb(225, 35, 45)
	local FLAME = rgb(255, 120, 30)
	local GOLD = rgb(255, 196, 60)
	local GOLD_L = rgb(255, 238, 160)
	local LEAF = rgb(80, 170, 70)
	local LEAF_D = rgb(45, 120, 50)
	local ROSE = rgb(215, 30, 45)
	local ROSE_L = rgb(240, 70, 80)
	local ROSE_D = rgb(140, 12, 28)
	local CS = 1.3 -- the crown's scale (council r3: bigger)

	local function streakOf(f): number
		local v = if f.player then f.player:GetAttribute("ClassStreak") else nil
		return math.clamp(tonumber(v) or 0, 0, 60)
	end
	-- `fn(f)` worked out once a frame, however many pieces hang off it
	local function perFrame(fn: (any) -> CFrame): (any) -> CFrame
		local lastT, last = -1, CFrame.identity
		return function(f)
			if f.t ~= lastT then
				lastT = f.t
				last = fn(f)
			end
			return last
		end
	end
	-- a rose: a dark red heart, a ring of petals curled tight round it and a ring of broad cupped petals opening out
	-- (small curved ellipsoids); it faces along local -Z. Returns its pieces for H.rig: the heart, the inner petals,
	-- then the outer petals.
	local function rose(parent: Instance, s: number, nIn: number, nOut: number): { { BasePart | CFrame } }
		local pieces = {}
		table.insert(pieces, { H.ellipsoid(parent, Vector3.new(0.26, 0.26, 0.24) * s, ROSE_D), CFrame.new(0, 0, -0.06 * s) })
		for k = 1, nIn do
			local ang = k / nIn * math.pi * 2 + 0.5
			local petal = H.ellipsoid(parent, Vector3.new(0.2, 0.24, 0.07) * s, CRIM)
			table.insert(pieces, { petal, CFrame.Angles(0, 0, ang - math.pi / 2) * CFrame.new(0, 0.1 * s, -0.03 * s) * CFrame.Angles(math.rad(-55), 0, 0) })
		end
		for k = 1, nOut do
			local ang = k / nOut * math.pi * 2
			local petal = H.ellipsoid(parent, Vector3.new(0.3, 0.3, 0.07) * s, if k % 2 == 0 then ROSE_L else ROSE)
			table.insert(pieces, { petal, CFrame.Angles(0, 0, ang - math.pi / 2) * CFrame.new(0, 0.2 * s, 0.03 * s) * CFrame.Angles(math.rad(-32), 0, 0) })
		end
		return pieces
	end
	-- the colour of fire from the root (0, crimson) through flame to the tip (1, gold)
	local function fireAt(u: number): Color3
		if u < 0.5 then
			return CRIM:Lerp(FLAME, u * 2)
		end
		return FLAME:Lerp(GOLD, (u - 0.5) * 2)
	end

	return function()
		local a = H.aura(H.RANK.Mythic, CRIM)
		-- the ground: a big rose-wreath sigil (the clover, a heart of fire) on a crimson glow, a gold ring at its rim
		H.glowDisc(a, 14.5, BFX.glow, CRIM, 0.5, 0, 0.06, 1)
		H.sigil(a, 16.25, T.cLegend, WHITE, 0, -0.16, 0.12, 1, 1.1)
		H.glowRing(a, 8.3, GOLD, 0.25, 0, 0.15, 1.3)
		local heat = 0 -- the streak, 0..1 (smoothed)
		H.job(a, function(self, f)
			heat += (streakOf(f) / 60 - heat) * 0.08
		end)

		-- the crown on your head (the card): a wreath of leaves with four red petal roses and a four-leaf clover jewel at
		-- the front; the Hot Streak sets it alight, one leaf turning to fire-gold per +5% (twelve leaves = +60%)
		local crownCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.4) / 0.7)
			return CFrame.new(f.head + Vector3.new(0, 0.6 + 0.08 * math.sin(f.t * 1.5) + 2 * (1 - k), 0)) * f.yaw * CFrame.Angles(math.rad(-8), 0, 0)
		end)
		local band = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, band, crownCF)
		local bandBeams = K.beamRing(band, 0.95 * CS, 0.14 * CS, K.seq(rgb(70, 140, 55)), 3, 0.05, 16, false)
		for _, b in bandBeams do
			b.LightEmission = 0.3
		end
		local leaves = {}
		for i = 1, 12 do
			local th = (i - 0.5) / 12 * math.pi * 2
			local leaf, imgs = H.plate(a.body, 0.8 * CS, BFX.leaf, LEAF, 0, true, 1.15)
			leaves[i] = imgs
			K.move(a, leaf, function(f)
				return crownCF(f) * CFrame.Angles(0, -th, 0) * CFrame.new(0, 0.12 * CS, -0.98 * CS) * CFrame.Angles(math.rad(70), 0, math.rad(20))
			end)
		end
		local ROSE_AT = { 0.5, 2.1, 3.7, 5.3 } -- (radians round the crown: front-right, back-right, back-left, front-left)
		for _, th in ROSE_AT do
			-- (each rose sits on the leaves facing out and a little up)
			local at = CFrame.Angles(0, -th, 0) * CFrame.new(0, 0.22 * CS, -1.04 * CS) * CFrame.Angles(math.rad(25), 0, th)
			H.rig(a, function(f)
				return crownCF(f) * at
			end, rose(a.body, 0.95, 2, 5))
		end
		local clover = {}
		for k = 1, 4 do
			local ang = k / 4 * math.pi * 2 + math.pi / 4
			local lobe = H.solid(a.body, Vector3.one * 0.17 * CS, rgb(70, 220, 90), Enum.Material.Neon)
			lobe.Shape = Enum.PartType.Ball
			table.insert(clover, { lobe, CFrame.new(math.cos(ang) * 0.11 * CS, (0.3 + math.sin(ang) * 0.11) * CS, -1.06 * CS) })
		end
		local gem = H.solid(a.body, Vector3.one * 0.1 * CS, GOLD, Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
		table.insert(clover, { gem, CFrame.new(0, 0.3 * CS, -1.12 * CS) })
		H.rig(a, crownCF, clover)
		local crownSpark = E(band, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD), rate = 2, life = { 0.4, 0.7 }, speed = { 0.3, 0.8 }, size = 0.7, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, crownSpark)
		local crownFire = E(band, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 235, 170), FLAME, CRIM), rate = 0, life = { 0.35, 0.55 }, speed = { 1, 2 }, size = 0.9, accel = Vector3.new(0, 4, 0), spread = 25, light = 0.8, bright = 1.6 })
		K.addEmitter(a, crownFire)
		local lit = -1
		H.job(a, function(self, f)
			local n = math.floor(streakOf(f) / 5 + 0.001)
			if n == lit then
				return
			end
			if n > lit and lit >= 0 then
				crownSpark:Emit(4)
				crownFire:Emit(3)
			end
			lit = n
			for i, imgs in leaves do
				local on = i <= n
				for _, img in imgs do
					img.ImageColor3 = if on then rgb(255, 205, 90) else LEAF
				end
			end
			crownSpark.Rate = 2 + n
			crownFire.Rate = n * 0.8
		end)

		-- the same wreath as a great halo turning slowly behind you: leaves all the way round, six petal roses, a gold
		-- ring inside; fire licks round it as the streak builds
		local HALO_R = 2.1
		local haloCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.35) / 0.8)
			local pos = (f.root * CFrame.new(0, 1.7 + 0.1 * math.sin(f.t * 1.2) - 3 * (1 - k), 1.3)).Position
			return H.facing(pos, f, f.t * 0.25)
		end)
		local glowRing, _, gguis = H.plate(a.body, HALO_R * 2 / 0.92 * 0.82, T.ringCrisp, GOLD, 0.1, true, 1.4)
		K.move(a, glowRing, haloCF)
		H.detail(a, gguis[1], gguis[2])
		for i = 1, 16 do
			local th = i / 16 * math.pi * 2
			local tilt = math.rad(if i % 2 == 0 then 35 else -35)
			local leaf = H.plate(a.body, 1.15, BFX.leaf, if i % 2 == 0 then LEAF else LEAF_D, 0, true, 1.15)
			K.move(a, leaf, function(f)
				return haloCF(f) * CFrame.Angles(0, -th, 0) * CFrame.new(HALO_R, 0, 0) * CFrame.Angles(0, tilt, 0)
			end)
			if i % 2 == 1 then
				H.detail(a, leaf)
			end
		end
		for i = 1, 6 do
			local th = (i - 0.5) / 6 * math.pi * 2
			-- (each rose faces out of the back of the halo, turned on its own axis so no two look the same)
			local at = CFrame.Angles(0, -th, 0) * CFrame.new(HALO_R, 0, 0) * CFrame.Angles(math.rad(90), 0, th)
			local pieces = rose(a.body, 1.3, 2, 5)
			H.rig(a, function(f)
				return haloCF(f) * at
			end, pieces)
			H.detail(a, pieces[2][1] :: BasePart, pieces[3][1] :: BasePart)
		end
		local haloHub = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, haloHub, haloCF)
		local haloFire = {}
		for i = 1, 3 do
			local th = i / 3 * math.pi * 2
			local fe = E(H.att(haloHub, Vector3.new(math.cos(th) * HALO_R, 0, math.sin(th) * HALO_R)), { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 235, 170), FLAME, CRIM), rate = 1, life = { 0.4, 0.6 }, speed = { 0.4, 1 }, size = 1, accel = Vector3.new(0, 4, 0), spread = 30, light = 0.8, bright = 1.6, rot = { -20, 20 } })
			K.addEmitter(a, fe)
			H.detail(a, fe)
			haloFire[i] = fe
		end

		-- wings of fire: five flaming feathers a side fanned out from your shoulders (~9 studs tip to tip), each a ribbon
		-- of light running crimson at the root to gold at the tip with flames dancing along it (crimson flames over the
		-- roots, gold ones out to the tips); they unfold when the aura forms, beat slowly and blaze harder with the streak
		local FEATHERS = { { 62, 3.4 }, { 40, 4.1 }, { 17, 4.4 }, { -6, 3.8 }, { -28, 2.9 } } -- (degrees up from level, length)
		local FW0, FW1 = 0.8, 0.5 -- (a feather's width at the root and the tip)
		local function wingCF(f, side: number): CFrame
			local k = ease((f.t - a.born - 0.3) / 0.8)
			local flap = math.rad(14 + 66 * (1 - k)) + math.rad(8) * math.sin(f.t * 2.2)
			local lift = math.rad(5) * math.sin(f.t * 2.2 + 0.6)
			return f.root * CFrame.new(side * 0.4, 1.1, 0.75) * CFrame.Angles(0, -side * flap, 0) * CFrame.Angles(0, 0, side * lift)
		end
		local featherBeams, tipFire, rootFire = {}, {}, {}
		for _, side in { -1, 1 } do
			local wcf = perFrame(function(f): CFrame
				return wingCF(f, side)
			end)
			local hub = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, hub, wcf)
			for j, fd in FEATHERS do
				local ang, len = math.rad(fd[1]), fd[2]
				local dir = Vector3.new(side * math.cos(ang), math.sin(ang), 0)
				local b = H.beam(H.att(hub, dir * 0.25), H.att(hub, dir * len), { colors = K.seq(CRIM, RED, FLAME, GOLD, GOLD_L), w0 = FW0, w1 = FW1, trans = ns(0, 0.3, 0.6, 0.1, 1, 0.5), tex = T.stripBody, texMode = Enum.TextureMode.Stretch, texSpeed = 0.6, light = 1, bright = 1.4 })
				table.insert(featherBeams, b)
				-- (a shorter covert feather between this one and the next fills the body of the wing)
				local nx = FEATHERS[j + 1]
				if nx then
					local ca = math.rad((fd[1] + nx[1]) / 2)
					local cdir = Vector3.new(side * math.cos(ca), math.sin(ca), 0)
					local cb = H.beam(H.att(hub, cdir * 0.2), H.att(hub, cdir * (len + nx[2]) * 0.3), { colors = K.seq(CRIM, RED, FLAME, GOLD), w0 = FW0 * 0.9, w1 = FW1 * 0.7, trans = ns(0, 0.35, 0.6, 0.15, 1, 0.55), tex = T.stripBody, texMode = Enum.TextureMode.Stretch, texSpeed = 0.6, light = 1, bright = 1.4 })
					H.detail(a, cb)
				end
				-- (the outer half of the feather, its local X along the feather and its local Y kept pointing up)
				local seg = K.piece(a.body, Vector3.new(len * 0.55, 0.3, 0.3))
				local turn = if side > 0 then CFrame.Angles(0, 0, ang) else CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, ang)
				local off = CFrame.new(dir * len * 0.72) * turn
				K.move(a, seg, function(f)
					return wcf(f) * off
				end)
				local tf = E(seg, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 250, 210), GOLD, FLAME), rate = 4, life = { 0.35, 0.5 }, speed = { 0.2, 0.6 }, size = 1.3, accel = Vector3.new(0, 3, 0), spread = 180, light = 0.85, bright = 1.6, rot = { -15, 15 }, lock = true })
				K.addEmitter(a, tf)
				H.detail(a, tf)
				table.insert(tipFire, tf)
			end
			local rootBox = K.piece(a.body, Vector3.new(1.9, 2.4, 0.35))
			K.move(a, rootBox, function(f)
				return wcf(f) * CFrame.new(side * 0.95, 0.4, 0)
			end)
			local rf = E(rootBox, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 140, 90), RED, CRIM, ROSE_D), rate = 7, life = { 0.35, 0.55 }, speed = { 0.2, 0.6 }, size = 1.5, accel = Vector3.new(0, 3, 0), spread = 180, light = 0.85, bright = 1.6, rot = { -15, 15 }, lock = true })
			K.addEmitter(a, rf)
			table.insert(rootFire, rf)
		end

		-- the fire spiral: two ribbons of fire coiling round you from your feet to twice your height (crimson low, gold
		-- high), turning so they seem to climb, flames racing up them; it rises out of the ground when the aura forms and
		-- burns brighter, wider and denser the hotter the streak
		local SPIRAL_H, TURNS, NSEG = 10, 2.25, 26
		local function coilAt(u: number, off: number): Vector3
			local r = 2.5 - 0.9 * u
			local th = off + u * TURNS * math.pi * 2
			return Vector3.new(math.cos(th) * r, 0.25 + u * SPIRAL_H, math.sin(th) * r)
		end
		local function edge(u: number): number -- (the ribbons fade in at the bottom and out at the top)
			return math.clamp(math.min(u / 0.08, (1 - u) / 0.22), 0, 1)
		end
		local coilCF = perFrame(function(f): CFrame
			return CFrame.new(f.feet) * CFrame.Angles(0, f.t * 2.4, 0)
		end)
		local coil = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, coil, coilCF)
		local coilK = 0 -- how far the spiral has risen (formation)
		local coilAtts, coilBeams = {}, {}
		for s = 0, 1 do
			local off = s * math.pi
			local prev: Attachment? = nil
			for i = 0, NSEG do
				local u = i / NSEG
				local at = H.att(coil, Vector3.new(0, 0, 0))
				table.insert(coilAtts, { at = at, u = u, off = off })
				if prev then
					local u0 = (i - 1) / NSEG
					local b = H.beam(prev, at, { colors = ColorSequence.new(fireAt(u0), fireAt(u)), w0 = 0.45, w1 = 0.45, trans = NumberSequence.new(1), tex = T.stripBody, texMode = Enum.TextureMode.Stretch, texSpeed = 0.8, light = 1, bright = 1.5 })
					table.insert(coilBeams, { b = b, u0 = u0, u1 = u })
				end
				prev = at
			end
		end
		local riders = {}
		for i = 1, 3 do
			local src = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
			local off = (i % 2) * math.pi
			K.move(a, src, function(f)
				local u = (f.t * 0.3 + i / 3) % 1
				local p = coilAt(u, off)
				return coilCF(f) * CFrame.new(p.X, p.Y * coilK, p.Z)
			end)
			local fe = E(src, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 230, 150), FLAME, CRIM), rate = 5, life = { 0.4, 0.6 }, speed = { 0.3, 0.8 }, size = 1.2, accel = Vector3.new(0, 3, 0), spread = 180, light = 0.8, bright = 1.6, rot = { -20, 20 } })
			K.addEmitter(a, fe)
			riders[i] = fe
			if i == 3 then
				H.detail(a, fe)
			end
		end
		local grown = false
		H.job(a, function(self, f)
			if grown then
				return
			end
			local kk = (f.t - self.born - 0.2) / 1.1
			coilK = ease(kk)
			for _, ca in coilAtts do
				local p = coilAt(ca.u, ca.off)
				local w = 0.3 + 0.7 * coilK
				ca.at.Position = Vector3.new(p.X * w, p.Y * coilK, p.Z * w)
			end
			grown = kk >= 1
		end)

		-- fire off your body, embers and rose petals drifting round you
		local torso = K.bodyBox(a, Vector3.new(1.8, 2.8, 1.2), -0.3)
		local fire = E(torso, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 230, 170), FLAME, CRIM), rate = 11, life = { 0.5, 0.8 }, speed = { 1.5, 2.8 }, size = 1.8, accel = Vector3.new(0, 3, 0), spread = 12, light = 0.75, bright = 1.6, rot = { -15, 15 }, trans = ns(0, 0.35, 0.5, 0.4, 1, 1) })
		K.addEmitter(a, fire)
		local around = K.bodyBox(a, Vector3.new(4, 4, 4), 0)
		local embers = E(around, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD, FLAME), rate = 7, life = { 1, 1.6 }, speed = { 0.8, 1.6 }, size = 0.38, accel = Vector3.new(0, 1.5, 0), spread = 30, light = 1, bright = 2 })
		K.addEmitter(a, embers)
		H.detail(a, embers)
		local petals = E(around, { tex = BFX.petal, colors = K.seq(ROSE_L, ROSE, CRIM), rate = 2, life = { 1.8, 2.6 }, speed = { 0.3, 0.8 }, size = 0.45, accel = Vector3.new(0, -0.5, 0), drag = 1, spin = 150, spread = 180, light = 0.2, bright = 1.2 })
		K.addEmitter(a, petals)
		H.detail(a, petals)
		-- the Hot Streak fire at your feet: a flicker standing still, roaring as the streak builds
		local base = H.feetPiece(a, Vector3.new(2.6, 0.2, 2.6), 0.3)
		local streakFire = E(base, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 230, 150), FLAME, CRIM), rate = 3, life = { 0.45, 0.8 }, speed = { 2, 4 }, size = 1.2, accel = Vector3.new(0, 4, 0), spread = 15, light = 1, bright = 1.6, rot = { -15, 15 } })
		local burst = E(base, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 230, 150), FLAME, CRIM), rate = 0, life = { 0.5, 0.8 }, speed = { 8, 12 }, size = 1.5, drag = 3, spread = 80, light = 1, bright = 1.6 })

		-- the streak's heat drives the wings, the spiral, the halo fire and the fire at your feet
		local lastHeat = -1
		H.job(a, function(self, f)
			if math.abs(heat - lastHeat) < 0.02 then
				return
			end
			lastHeat = heat
			local h = heat
			for _, b in featherBeams do
				b.Width0 = FW0 * (1 + 0.35 * h)
				b.Width1 = FW1 * (1 + 0.6 * h)
				K.bright(b, 1.4 + h)
			end
			for _, fe in tipFire do
				fe.Rate = 4 + 5 * h
				fe.Size = NumberSequence.new(1.3 + 0.5 * h)
			end
			for _, fe in rootFire do
				fe.Rate = 7 + 9 * h
				fe.Size = NumberSequence.new(1.5 + 0.6 * h)
			end
			local alpha = 0.5 + 0.45 * h
			local wk = 0.85 + 0.5 * h
			for _, cb in coilBeams do
				cb.b.Transparency = NumberSequence.new(1 - edge(cb.u0) * alpha, 1 - edge(cb.u1) * alpha)
				cb.b.Width0 = (0.7 - 0.3 * cb.u0) * wk
				cb.b.Width1 = (0.7 - 0.3 * cb.u1) * wk
			end
			for _, fe in riders do
				fe.Rate = 5 + 10 * h
			end
			for _, fe in haloFire do
				fe.Rate = 1 + 6 * h
			end
			streakFire.Rate = 6 + 34 * h
			streakFire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 + h * 1.6), NumberSequenceKeypoint.new(1, 0.1) })
		end)
		H.shell(a, K.seq(rgb(255, 210, 170), RED, CRIM), 9, 1.1)
		H.updraft(a, 7.6, K.seq(WHITE, GOLD, FLAME), 10)
		-- the heartbeat: a crimson ring, the light and outline throb
		H.every(a, 1.5, function(self, f)
			if f.ground > 0.3 then
				K.pulse(f.feet, 2, 17 + heat * 7, RED, 0.8, 0.05)
			end
			self.lightKick = 2 + heat
			if self.outline then
				self.outline.OutlineTransparency = 0
			end
		end)
		H.job(a, function(self, f)
			local o = self.outline
			if o and o.OutlineTransparency < 0.15 then
				o.OutlineTransparency = math.min(0.15, o.OutlineTransparency + 0.01)
			end
		end)
		K.feetTrail(a, K.seq(GOLD, FLAME, CRIM))
		K.outline(a, RED, 0.15)
		K.light(a, FLAME, 1.5, 16)
		H.lightJob(a, 0.12)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 24, RED, 1, 0)
			K.pulse(feet, 1, 15, GOLD, 0.7, 0.15)
			K.pulse(feet, 1, 9, WHITE, 0.5, 0.25)
			burst:Emit(18)
			fire:Emit(10)
			embers:Emit(16)
			petals:Emit(24)
			for _, rf in rootFire do
				rf:Emit(8)
			end
			self.lightKick = 3.5
		end
		return a
	end
end
