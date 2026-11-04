-- LAWN LEGEND (Mythic) - the card: a crown of green leaves set with red roses and a lucky four-leaf clover. Gimmick:
-- Hot Streak, each clump cut in a streak adds +5% power (up to +60%: the player attribute ClassStreak, 0..60) and it
-- fades 2.5 s after you stop, so the class burns hotter the longer the streak. Aura, built from ForgeGUI props and the
-- VFX Forge layers in Loop_LawnLegend:
--   - the card's crown on your head: the ForgeGUI leaf-and-rose wreath (ll_wreath, gold clover at the front) lying on
--     your head; it drops on with a spin when the aura forms and its roses burn with the streak
--   - the same wreath, big and hollow, as a halo 2 studs behind you and 1.5 up, semi-transparent (you show through it,
--     and through its hollow middle); fire climbs it as the streak heats (bottom, then sides, then the top), a thin gold
--     ring round it, a warm glow in it seen from the front. Your own aura: fainter still while the camera is behind you.
--   - wings of fire: six flame feathers a side, curved ribbons of flowing fire running crimson at your shoulder to gold
--     at the tip, a gold core in each, fire burning along them; they unfold when the aura forms, beat slowly, and grow
--     longer, wider and brighter with the streak (~7 studs tip to tip cold, ~9 at +60%)
--   - a fire spiral: a double helix of flames climbing round you to twice your height, each strand trailing fire
--   - the ForgeGUI rose-wreath emblem under you; three crisp line rings over it (a gold rim, a rose-red dashed ring and
--     a gold dashed ring round the fire heart, turning opposite ways)
--   - the Hot Streak meter: twelve 3D roses set round the emblem's wreath, dark buds that ignite one per +5% (a lit
--     rose glows crimson and burns)
--   - embers and rose petals, a ring of fire round your feet, burning footsteps when you run, a heartbeat (lub-dub)
-- Rose red, leaf green, gold and flame: the card's own colours (its pink backdrop is the Mythic rarity's colour, so it
-- isn't used). Fire stays crimson-to-gold, not white: low light emission, darker cores, no starburst rays.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local FX = H.FX
	local E = H.E
	local LOOP = "Loop_LawnLegend"
	local CRIM = rgb(176, 16, 42)
	local ROSE = rgb(222, 34, 50)
	local FLAME = rgb(255, 120, 30)
	local GOLD = rgb(255, 196, 60)
	local GOLD_L = rgb(255, 236, 160)
	local LEAF = rgb(70, 160, 60)
	local BUD = rgb(120, 20, 34) -- an unlit rose

	-- the streak, 0..60 (+% power)
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
	-- set a layer's rate. client/RarityFx keeps each emitter's own rate and puts it back when you start or stop running,
	-- so that is changed too.
	local function setRate(a: any, list: { ParticleEmitter }, rate: number)
		for _, e in list do
			for _, em in a.emitters do
				if em.e == e then
					em.rate = rate
					break
				end
			end
			e.Rate = rate
		end
	end
	local function emit(list: { ParticleEmitter }, n: number)
		for _, e in list do
			e:Emit(n)
		end
	end
	local function join(into: { ParticleEmitter }, list: { ParticleEmitter })
		for _, e in list do
			table.insert(into, e)
		end
	end

	return function()
		local a = H.aura(H.RANK.Mythic, ROSE)
		local streak, heat = 0, 0 -- the streak (0..60) and its heat (0..1, smoothed)
		H.job(a, function(self, f)
			streak = streakOf(f)
			heat += (streak / 60 - heat) * 0.08
		end)
		-- your own aura with the camera behind you: the big pieces behind you go fainter (0..1, set by a job below)
		local behind = false

		-- the ground: the ForgeGUI rose-wreath emblem (leaves, red roses, the clover, a heart of fire) turning slowly, and
		-- three crisp line rings over it (Sol's RNG look): a gold rim, a rose-red dashed ring outside it turning one way,
		-- a gold dashed ring round the fire heart turning the other
		local EMB = 15
		local EMB_SPIN = -0.05
		H.sigil(a, EMB, T.embLawnLegend, WHITE, 0.2, EMB_SPIN, 0.12, 0.9, 1.05)
		H.glowRing(a, EMB * 0.5, GOLD, 0.42, 0, 0.15, 1.15)
		K.groundRing(a, EMB * 0.5 + 0.85, 0.13, ROSE, 1.6, 0.4, 0.35, true, 0.16)
		K.groundRing(a, EMB * 0.27, 0.11, GOLD, 1.6, 0.45, -0.55, true, 0.17)

		-- the Hot Streak meter: twelve roses set round the emblem's wreath (turning with it), dark buds on a pair of leaves
		-- until the streak lights them, one per +5%: a lit rose glows crimson and burns
		local ROSE_R = EMB * 0.37
		local roses, roseFire = {}, {}
		for i = 1, 12 do
			local th = (i - 1) / 12 * math.pi * 2
			local head = H.ellipsoid(a.model, Vector3.new(0.85, 0.62, 0.85), BUD, Enum.Material.SmoothPlastic)
			local leaves = H.ellipsoid(a.model, Vector3.new(1.35, 0.12, 0.5), LEAF, Enum.Material.SmoothPlastic)
			H.rig(a, function(f): CFrame
				return CFrame.new(f.feet) * CFrame.Angles(0, f.t * EMB_SPIN + th, 0) * CFrame.new(ROSE_R, 0, 0)
			end, {
				{ head, CFrame.new(0, 0.45, 0) },
				{ leaves, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, math.rad(90), 0) },
			})
			roses[i] = head
			roseFire[i] = H.layer(a, LOOP, "Fire", head, false, 0.45)
			setRate(a, roseFire[i], 0)
		end

		-- the crown (the card's): the ForgeGUI leaf-and-rose wreath lying on your head, its front face up and its gold
		-- clover at the front, tipped a little toward whoever's in front of you, its band made deeper so it reads as a
		-- crown and not a flat ring; it sways a little, drops on with a spin when the aura forms and burns with the
		-- streak (a flare off it for every +5%)
		local CROWN = 2.3
		local crown = H.prop(a.body, "ll_wreath", CROWN)
		local cs = H.propSize("ll_wreath", CROWN)
		if crown:IsA("MeshPart") then
			crown.Size = Vector3.new(cs.X, cs.Y, cs.Z * 2)
		end
		local LIE = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(102), 0, 0) -- (face up, clover forward, tipped)
		local crownCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.45) / 0.7)
			local y = 0.25 + 0.05 * math.sin(f.t * 1.6) + 3 * (1 - k)
			return CFrame.new(f.head + Vector3.new(0, y, 0)) * f.yaw * CFrame.Angles(0, (1 - k) * 5 + math.rad(5) * math.sin(f.t * 0.7), 0) * LIE
		end)
		K.move(a, crown, crownCF)
		local crownGlint = E(crown, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 1, life = { 0.4, 0.6 }, speed = { 0.2, 0.4 }, size = 0.45, spread = 180, light = 1, bright = 1.3 })
		K.addEmitter(a, crownGlint)
		H.detail(a, crownGlint)
		local crownFire = H.layer(a, LOOP, "Fire", crown, false, 0.4)
		local crownFlare = H.layer(a, LOOP, "Flare", crown, false, 0.25)

		-- the halo: the same wreath, big and hollow, 2 studs behind you and 1.5 up, semi-transparent (you show through it
		-- and through its middle), a thin gold ring round it and a warm glow in it (seen from the front only). Fire climbs
		-- it as the streak heats: its bottom burns first, then its sides, then its top. Rose petals drift off it. It rises
		-- out of the ground when the aura forms.
		local HALO = 5.8
		local halo = H.prop(a.body, "ll_wreath", HALO)
		local hs = H.propSize("ll_wreath", HALO)
		if halo:IsA("MeshPart") then
			halo.Transparency = 0.35
		end
		local haloCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.25) / 0.95)
			local rise = f.head.Y - f.root.Position.Y -- (the top of your head over your root)
			local y = rise + 1.5 + 0.12 * math.sin(f.t * 1.1) - 8 * (1 - k)
			return f.root * CFrame.new(0, y, 2) * CFrame.Angles(math.rad(-8), 0, math.rad(2) * math.sin(f.t * 0.6))
		end)
		K.move(a, halo, haloCF)
		local RING_R = hs.X * 0.56
		local ring, ringImgs = H.plate(a.body, RING_R * 2 / 0.92, T.ringCrisp, GOLD, 0.45, true, 1.2)
		K.move(a, ring, function(f)
			return haloCF(f) * CFrame.new(0, 0, hs.Z * 0.5 + 0.2) * H.UPRIGHT
		end)
		local warm, _, warmGuis = H.plate(a.body, RING_R * 2.1, FX.glow, FLAME, 0.74, false, 1)
		K.move(a, warm, function(f)
			return haloCF(f) * CFrame.new(0, 0, hs.Z * 0.5 + 0.45) * CFrame.Angles(math.rad(-90), 0, 0)
		end)
		H.detail(a, warmGuis[1])
		-- (the fire's holders on the wreath: its bottom, its two sides, its top)
		local BAND = hs.X * 0.39 -- (the middle of the wreath's band, from its centre)
		local function onHalo(size: Vector3, off: CFrame): BasePart
			local p = K.piece(a.body, size)
			K.move(a, p, function(f)
				return haloCF(f) * off
			end)
			return p
		end
		local haloLow = onHalo(Vector3.new(BAND * 1.3, 0.5, 0.4), CFrame.new(0, -BAND * 0.92, 0))
		local haloSides = {
			onHalo(Vector3.new(0.5, BAND * 1.1, 0.4), CFrame.new(-BAND * 0.95, -0.1, 0)),
			onHalo(Vector3.new(0.5, BAND * 1.1, 0.4), CFrame.new(BAND * 0.95, -0.1, 0)),
		}
		local haloTop = onHalo(Vector3.new(BAND * 1.2, 0.5, 0.4), CFrame.new(0, BAND * 0.92, 0))
		local fireLow = H.layer(a, LOOP, "Fire", haloLow, false, 0.9)
		local fireSides = {}
		for _, p in haloSides do
			join(fireSides, H.layer(a, LOOP, "Fire", p, false, 0.85))
		end
		local fireTop = H.layer(a, LOOP, "Fire", haloTop, false, 0.8)
		local haloFlare = H.layer(a, LOOP, "Flare", haloLow, false, 0.55)
		local haloPetals = H.layer(a, LOOP, "Petals", halo, false, 1.1)
		setRate(a, haloPetals, 2)
		for _, e in haloPetals do
			H.detail(a, e)
		end

		-- wings of fire: six flame feathers a side fanned out from your shoulder blades (lifted, pushed back, starting
		-- clear of your back), each a curved ribbon of flowing fire (crimson at the root to gold at the tip, fading out at
		-- the tip like a flame's tongue) with a thin gold core and fire burning along it. They unfold when the aura forms,
		-- beat slowly, and grow longer, wider and brighter with the streak.
		local FEATHERS = { { 76, 2.7 }, { 56, 3.4 }, { 36, 3.8 }, { 16, 3.6 }, { -4, 3.0 }, { -24, 2.4 } } -- (degrees up, length)
		local INNER = 0.55 -- (each feather starts this far out from its wing's root)
		local BEND = 0.35 -- (each feather leaves the root sideways and sweeps up: its curve, as a share of its length)
		local RIB_T = ns(0, 0.4, 0.12, 0.12, 0.65, 0.18, 1, 0.92)
		local RIB_T_BACK = ns(0, 0.75, 0.12, 0.5, 0.65, 0.55, 1, 0.95)
		local CORE_T = ns(0, 0.5, 0.2, 0.25, 0.8, 0.6, 1, 1)
		local CORE_T_BACK = ns(0, 0.8, 0.2, 0.6, 0.8, 0.8, 1, 1)
		local function wingCF(f, side: number): CFrame
			local k = ease((f.t - a.born - 0.3) / 0.9)
			-- (folded back along you at first; open, they sweep back only a little)
			local flap = math.rad(12 + 76 * (1 - k)) + math.rad(6) * math.sin(f.t * 2.1)
			local lift = math.rad(4) * math.sin(f.t * 2.1 + 0.7)
			return f.root * CFrame.new(side * 0.5, 1.3, 0.85) * CFrame.Angles(0, -side * flap, 0) * CFrame.Angles(0, 0, side * lift)
		end
		local feathers, wingFire, rootFire, wingEmbers = {}, {}, {}, {}
		for _, side in { -1, 1 } do
			local wcf = perFrame(function(f): CFrame
				return wingCF(f, side)
			end)
			local hub = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, hub, wcf)
			for _, fd in FEATHERS do
				local ang, len = math.rad(fd[1]), fd[2]
				local dir = Vector3.new(side * math.cos(ang), math.sin(ang), 0)
				local a0 = H.att(hub, dir * INNER)
				local a1 = H.att(hub, dir * len)
				local fe = { side = side, dir = dir, len = len, L = len, a1 = a1 }
				-- (the flame ribbon: flowing fire along it, and its gold core on top)
				fe.ribbon = H.beam(a0, a1, { colors = K.seq(CRIM, ROSE, FLAME, GOLD), w0 = 0.8, w1 = 0.14, trans = RIB_T, light = 0.35, bright = 1.05, tex = T.energy, texLen = 2.4, texSpeed = 1.4, segments = 10, curve0 = side * BEND * len, curve1 = 0 })
				fe.core = H.beam(a0, a1, { colors = K.seq(FLAME, GOLD, GOLD_L), w0 = 0.22, w1 = 0.04, trans = CORE_T, light = 0.7, bright = 1.1, segments = 10, curve0 = side * BEND * len, curve1 = 0, zoff = 0.05 })
				-- (the fire along the feather: a box lying along its bow, its local Y kept pointing up on both wings)
				local holder = K.piece(a.body, Vector3.new(len * 0.7, 0.45, 0.35))
				local turn = if side > 0 then CFrame.Angles(0, 0, ang) else CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, ang)
				K.move(a, holder, function(f)
					local mid = dir * (INNER + fe.L) * 0.5 + Vector3.new(side * 0.375 * BEND * fe.L, 0, 0)
					return wcf(f) * CFrame.new(mid) * turn
				end)
				join(wingFire, H.layer(a, LOOP, "WingFire", holder, false, 0.75 + 0.15 * len / 3.8))
				table.insert(feathers, fe)
			end
			local rootBox = K.piece(a.body, Vector3.new(1.4, 1.8, 0.4))
			K.move(a, rootBox, function(f)
				return wcf(f) * CFrame.new(side * 1.1, 0.5, 0)
			end)
			join(rootFire, H.layer(a, LOOP, "Fire", rootBox, false, 0.85))
			local span = K.piece(a.body, Vector3.new(3.2, 3.4, 0.4))
			K.move(a, span, function(f)
				return wcf(f) * CFrame.new(side * 2.4, 0.9, 0)
			end)
			local we = H.layer(a, LOOP, "Embers", span, false, 0.9)
			for _, e in we do
				H.detail(a, e)
			end
			join(wingEmbers, we)
		end

		-- the fire spiral: a double helix of fire climbing round you from your feet to twice your height (wide at the
		-- bottom, narrowing up). Each strand is two flames half a climb apart, each trailing a ribbon of fire (gold at its
		-- head, crimson at its tail) and shedding flames, so the strands read nearly whole. A ribbon thins to nothing at
		-- the top before its flame starts again at the bottom. It rises out of the ground when the aura forms and burns
		-- wider with the streak.
		local SPIRAL_H, TURNS, PERIOD = 10, 2, 2.1
		local riders, riderFire = {}, {}
		for i = 1, 4 do
			local p = K.piece(a.body, Vector3.new(0.35, 0.35, 0.35))
			local tr = K.trail(p, Vector3.new(0, 0.4, 0), Vector3.new(0, -0.4, 0), K.seq(GOLD_L, GOLD, FLAME, ROSE, CRIM), 0.85, 0.6)
			K.bright(tr, 1.25)
			tr.Enabled = false -- (switched on once the aura is in place, so no streak runs in from where it was built)
			local strand = (i - 1) % 2
			local phase = math.floor((i - 1) / 2) * 0.5
			local function uOf(f): number
				return ((f.t - a.born) / PERIOD + phase) % 1
			end
			K.move(a, p, function(f)
				local u = uOf(f)
				local k = ease((f.t - a.born - 0.15) / 1.1)
				local r = (2.9 - 0.9 * u) * (0.35 + 0.65 * k)
				local th = u * TURNS * math.pi * 2 + strand * math.pi
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * r, (0.25 + u * SPIRAL_H) * k, math.sin(th) * r))
			end)
			join(riderFire, H.layer(a, LOOP, "Fire", p, false, 0.7))
			riders[i] = { trail = tr, a0 = tr.Attachment0, a1 = tr.Attachment1, uOf = uOf }
		end
		local trailsOn, lastPos, lastLife = false, Vector3.zero, -1
		H.job(a, function(self, f)
			local here = f.root.Position
			local jumped = (here - lastPos).Magnitude > 30 -- (a teleport: wipe the ribbons rather than draw one across)
			lastPos = here
			if not trailsOn and f.t - self.born > 0.2 then
				trailsOn = true
				for _, r in riders do
					r.trail.Enabled = true
				end
			end
			local life = 0.85 - 0.45 * (1 - f.calm) -- (shorter while you run)
			local setLife = math.abs(life - lastLife) > 0.03
			if setLife then
				lastLife = life
			end
			local wk = 0.85 + 0.45 * heat
			for _, r in riders do
				if jumped then
					r.trail:Clear()
				end
				if setLife then
					r.trail.Lifetime = life
				end
				local u = r.uOf(f)
				local w = (0.55 - 0.2 * u) * math.clamp(math.min(u / 0.08, (1 - u) / 0.1), 0, 1) * wk
				r.a0.Position = Vector3.new(0, w, 0)
				r.a1.Position = Vector3.new(0, -w, 0)
			end
		end)

		-- embers and rose petals round you, a ring of fire round your feet (it roars with the streak), and burning
		-- footsteps while you run
		local around = K.bodyBox(a, Vector3.new(4.2, 4.6, 4.2), 0.2)
		local embers = H.layer(a, LOOP, "Embers", around, false, 1)
		local petals = H.layer(a, LOOP, "Petals", around, false, 1.1)
		for _, e in petals do
			H.detail(a, e)
		end
		local feetRing = H.feetPiece(a, Vector3.new(3.4, 0.5, 3.4), 0.4)
		local feetFire = H.layer(a, LOOP, "Fire", feetRing, false, 0.8)
		for _, e in feetFire do
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		end
		local steps = H.feetPiece(a, Vector3.new(1.4, 0.3, 1.4), 0.3)
		H.layer(a, LOOP, "Fire", steps, true, 0.6)

		-- the streak's heat drives the wings (longer, wider, brighter), the fire climbing the halo, the crown's fire, the
		-- spiral and the fire at your feet
		local function climb(h: number, from: number, to: number): number
			return math.clamp((h - from) / (to - from), 0, 1)
		end
		local function applyHeat(h: number)
			local g = 0.85 + 0.4 * h
			for _, fe in feathers do
				local L = fe.len * g
				fe.L = L
				fe.a1.Position = fe.dir * L
				fe.ribbon.CurveSize0 = fe.side * BEND * L
				fe.core.CurveSize0 = fe.side * BEND * L
				fe.ribbon.Width0 = 0.8 * (1 + 0.35 * h)
				fe.ribbon.Width1 = 0.14 * (1 + 0.8 * h)
				fe.core.Width0 = 0.22 * (1 + 0.3 * h)
				K.bright(fe.ribbon, 1.05 + 0.45 * h)
			end
			setRate(a, wingFire, 3.5 + 4.5 * h)
			setRate(a, rootFire, 3 + 7 * h)
			setRate(a, wingEmbers, 4 + 6 * h)
			setRate(a, fireLow, 2 + 9 * h)
			setRate(a, fireSides, 10 * climb(h, 0.25, 0.75))
			setRate(a, fireTop, 10 * climb(h, 0.6, 1))
			setRate(a, crownFire, 5 * h)
			setRate(a, riderFire, 3 + 6 * h)
			setRate(a, feetFire, 2 + 14 * h)
			setRate(a, embers, 6 + 8 * h)
		end
		applyHeat(0)
		local lastHeat = 0
		H.job(a, function(self, f)
			if math.abs(heat - lastHeat) >= 0.02 then
				lastHeat = heat
				applyHeat(heat)
			end
		end)
		-- the meter: one rose lights per +5% (a flare off the crown as it does), they go dark as the streak fades
		local lit = 0
		H.job(a, function(self, f)
			local n = math.floor(streak / 5 + 0.001)
			if n == lit then
				return
			end
			for i, head in roses do
				local on, was = i <= n, i <= lit
				if on ~= was then
					head.Color = if on then ROSE else BUD
					head.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
					head.Size = if on then Vector3.new(0.95, 0.7, 0.95) else Vector3.new(0.85, 0.62, 0.85)
					setRate(a, roseFire[i], if on then 2 else 0)
					if on then
						emit(roseFire[i], 4)
					end
				end
			end
			if n > lit then
				emit(crownFlare, 1)
			end
			lit = n
		end)

		-- your own aura with the camera behind you: the halo and its ring go fainter and the wings thin out, so you're
		-- never hidden from the follow camera
		H.job(a, function(self, f)
			local b = false
			if f.player ~= nil and f.player == H.player then
				local cam = workspace.CurrentCamera
				b = cam ~= nil and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3
			end
			if b ~= behind then
				behind = b
				halo.LocalTransparencyModifier = if b then 0.5 else 0
				for _, fe in feathers do
					fe.ribbon.Transparency = if b then RIB_T_BACK else RIB_T
					fe.core.Transparency = if b then CORE_T_BACK else CORE_T
				end
			end
		end)

		K.outline(a, FLAME, 0.2)
		K.light(a, FLAME, 0.9, 15)
		H.lightJob(a, 0.15)
		K.feetTrail(a, K.seq(GOLD, FLAME, CRIM))

		-- the heartbeat (lub-dub): a rose-red ring then a gold one race out over the ground, the halo's ring and the light
		-- throb, the outline flashes; a hot streak spits a few flares off the halo on every beat
		local throb, dub = 0, math.huge
		H.every(a, 1.5, function(self, f)
			if f.ground > 0.3 then
				K.pulse(f.feet, 2, 16 + heat * 8, ROSE, 0.8, 0.1)
			end
			dub = f.t + 0.24
			throb = 1
			self.lightKick = 1.4 + 0.6 * heat
			if self.outline then
				self.outline.OutlineTransparency = 0
			end
			if heat > 0.35 then
				emit(haloFlare, math.floor(1 + 2.5 * heat))
			end
		end)
		local lastRingT = -1
		H.job(a, function(self, f)
			if f.t >= dub then
				dub = math.huge
				throb = math.max(throb, 0.7)
				if f.ground > 0.3 then
					K.pulse(f.feet, 2, 10 + heat * 5, GOLD, 0.6, 0.3)
				end
			end
			throb *= 0.9
			local beat = math.min(throb, 1)
			local rt = math.clamp(0.45 - 0.2 * beat + (if behind then 0.3 else 0), 0, 1)
			if math.abs(rt - lastRingT) > 0.01 then
				lastRingT = rt
				for _, img in ringImgs do
					img.ImageTransparency = rt
				end
			end
			local o = self.outline
			if o and o.OutlineTransparency < 0.2 then
				o.OutlineTransparency = math.min(0.2, o.OutlineTransparency + 0.01)
			end
		end)

		-- the entrance: the crown drops on, the halo rises, the wings unfold and the spiral climbs (their movers above);
		-- rings race out, fire bursts round your feet, petals and embers fly; as the halo arrives it flares up
		local settleAt = math.huge
		H.job(a, function(self, f)
			if f.t >= settleAt then
				settleAt = math.huge
				emit(haloFlare, 6)
				emit(haloPetals, 10)
				emit(fireLow, 8)
				emit(crownFlare, 2)
				throb = 1.2
				self.lightKick = 1.8
			end
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 26, ROSE, 1, 0)
			K.pulse(feet, 1, 17, GOLD, 0.75, 0.12)
			K.pulse(feet, 1, 9, WHITE, 0.5, 0.25)
			emit(feetFire, 16)
			emit(petals, 20)
			emit(embers, 18)
			emit(rootFire, 6)
			settleAt = os.clock() + 0.85
			self.lightKick = 2
		end
		return a
	end
end
