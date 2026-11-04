-- HEDGE REAPER (Epic). The card: a reaper's scythe, its long snath wrapped in a flowering vine, cutting a hedge in one
-- sweep. (The card's purple is the Epic rarity's colour, so it isn't used: the aura is hedge green, a teal-black pool,
-- the scythe's pale steel and the mint ghost-fire of its edge.)
-- Gimmick: Reap Wave, every 8th swing sends a wave that hits every clump round you.
-- The aura, built round ForgeGUI pieces:
--   ground     the bramble emblem with a teal-black pool of mist inside the hedge ring (the mint scythe and the soul
--              fire glow against it), three crisp mint rings (the inner one dashed and turning)
--   scythe     the vine-wrapped scythe, a third bigger, hovering behind you on a slant: its blade arcs over your head.
--              Every 4 s it twirls a full circle round you overhead, a thick mint crescent trail with a white-hot edge
--              behind its blade (your own: half see-through while the camera is behind you)
--   hedges     eight rounded, flowering topiary bushes (ForgeGUI hr_topiary), knee high, out on the emblem's rim: as the
--              blade passes over each one its top pops off in leaves and petals with a mint slash, and grows back;
--              they sink into the ground while you run
--   souls      tall mint soul fire off your shoulders, soul orbs circling you on trails, a dark shroud round your legs
--   Reap Wave  eight soul flames round your feet, one lit per swing (lit nearly solid, unlit faint). The wave makes the
--              scythe twirl at once, pops every hedge, rolls a ghost ring out and starts the flames again.
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local HEDGE = rgb(45, 135, 60)
	local MINT = rgb(110, 255, 215)
	local GHOST = rgb(175, 255, 240)
	local GHOST_W = rgb(232, 255, 252)
	local POOL = rgb(4, 18, 17) -- the teal-black pool
	local BLOOM = rgb(255, 170, 215) -- the vine's and the topiary's flowers
	local SOUL = K.seq(GHOST_W, rgb(120, 255, 220), rgb(30, 120, 90)) -- soul fire: white-hot to deep mint
	local SOUL_DIM = K.seq(rgb(90, 175, 155), rgb(20, 70, 60))
	local TAU = math.pi * 2

	local SCYTHE = 9.5 -- the scythe's length (a third bigger than before: about twice your height)
	-- (GUESS, from the v6a back shot) the side of the prop its blade hooks to (+1 = +X). The twirl turns that way so
	-- the blade's tip leads; set -1 if the screenshots show the blade dragging backwards.
	local BLADE = 1
	local LEAN = math.rad(50) -- at rest the snath slants from the ground by your right heel up past your left shoulder
	local BACK = 2.6 -- how far behind you it hovers (clear of the follow camera and of your arms in the twirl)
	local HEDGES, HEDGE_R, TOPIARY = 8, 5.5, 2.4 -- the topiary ring: how many, its radius, each bush's longest side
	local SWEEP_EVERY, SWEEP_TIME, WAVE_TIME = 4, 1.2, 0.8
	local PIP_R = 3.3 -- the ring of eight soul flames
	-- a soul flame lit (nearly solid, ~1.2 studs) and unlit (faint)
	local LIT_SIZE, LIT_TR = ns(0, 0.7, 0.35, 1.2, 1, 0.15), ns(0, 0.1, 0.55, 0.2, 1, 1)
	local DIM_SIZE, DIM_TR = ns(0, 0.6, 0.35, 0.95, 1, 0.1), ns(0, 0.8, 0.6, 0.85, 1, 1)

	return function()
		local a = H.aura(H.RANK.Epic, MINT)
		local function emit(list: { ParticleEmitter }, n: number)
			for _, e in list do
				e:Emit(n)
			end
		end

		-- THE GROUND: the bramble emblem turning slowly; a teal-black pool over its middle (a soft dark disc, dark mist
		-- pooling on it, a few soul wisps rising off it); three crisp mint rings: inside the hedges (dashed, turning),
		-- just inside them and just outside them
		H.sigil(a, 11.6, T.embHedgeReaper, WHITE, 0.2, -0.08, 0.12, 0.8, 1)
		H.glowDisc(a, 8.8, FX.glow, POOL, 0.3, 0, 0.145, 1)
		K.groundRing(a, 2.4, 0.09, MINT, 3, 0.35, -0.5, true, 0.17)
		H.glowRing(a, HEDGE_R - 1.35, MINT, 0.42, 0, 0.165, 1.2)
		H.glowRing(a, HEDGE_R + 1.45, GHOST, 0.4, 0, 0.175, 1.2)
		local mistRing = H.feetPiece(a, Vector3.new(8, 0.6, 8), 0.3)
		local mist = H.layer(a, "Loop_HedgeReaper", "Mist", mistRing, false, 0.8)
		local poolPart = H.feetPiece(a, Vector3.new(7, 0.3, 7), 0.25)
		local pool = E(poolPart, { tex = FX.smoke, colors = K.seq(rgb(12, 44, 40), POOL), rate = 5, life = { 2, 3 }, speed = { 0.1, 0.4 }, size = 3.4, spin = 15, spread = 40, light = 0, bright = 1, shape = Enum.ParticleEmitterShape.Disc, trans = ns(0, 1, 0.3, 0.42, 1, 1), sizeSeq = ns(0, 2.4, 1, 4) })
		K.addEmitter(a, pool)
		local rise = E(poolPart, { tex = T.wisp, colors = K.seq(GHOST_W, MINT), rate = 4, life = { 0.9, 1.3 }, speed = { 2, 3.5 }, size = 0.9, accel = Vector3.new(0, 1.2, 0), spread = 0, light = 0.8, bright = 1.3, shape = Enum.ParticleEmitterShape.Disc, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.25, 0.35, 1, 1), sizeSeq = ns(0, 0.4, 0.4, 1.1, 1, 0.2) })
		K.addEmitter(a, rise)
		H.detail(a, pool, rise)

		-- THE SCYTHE (ForgeGUI hr_scythe: flat in its XY plane, the snath along Y, the blade at the top hooking to +X)
		local scy = H.prop(a.body, "hr_scythe", SCYTHE)
		local S = H.propSize("hr_scythe", SCYTHE)
		-- the rest pose, in a frame at your root turned to your facing: the snath's foot by your right heel, its top past
		-- your left shoulder, the blade arcing just over your head (root to feet is ~2.7)
		local c, s = math.cos(LEAN), math.sin(LEAN)
		local footY = -0.38 * S.X * s - 0.5 * S.Y * c -- (the snath's foot after the lean, from the prop's centre)
		local REST = CFrame.new(BLADE * 0.24 * S.Y, -footY - 3.1, BACK) * CFrame.Angles(math.rad(6), 0, BLADE * LEAN)
		-- (GUESS) the blade's middle and its inner edge, as fractions of the prop (from the v6a back shot)
		local MID = Vector3.new(BLADE * 0.15 * S.X, 0.36 * S.Y, 0)
		local EDGE = Vector3.new(BLADE * 0.25 * S.X, 0.26 * S.Y, 0)
		-- straight up in the prop's frame at rest (the trail's attachments sit above and below the blade on it)
		local UPV = Vector3.new(BLADE * s, c, 0)
		-- At rest it hovers, bobbing (it drops in from above with a spin as the aura forms); in a sweep it twirls a full
		-- circle round you, tipping outward a little. Worked out once a frame (the trail and the hedge cuts read it).
		local sweepAt, sweepLen, nextSweep = -1e9, SWEEP_TIME, 0
		local cT, cCF, cPhi, cP = -1, CFrame.identity, 0, 2
		local function scythe(f): CFrame
			if f.t == cT then
				return cCF
			end
			local k = ease((f.t - a.born - 0.1) / 0.8)
			local p = (f.t - sweepAt) / sweepLen
			local phi, blend = 0, 0
			if p >= 0 and p < 1 then
				phi = (p - math.sin(p * TAU) / TAU) * TAU -- (eases in and out, fastest halfway round)
				blend = smooth(p / 0.15) * smooth((1 - p) / 0.15)
			end
			local cf = CFrame.new(f.root.Position + Vector3.new(0, 0.15 * math.sin(f.t * 1.3) + 4 * (1 - k), 0))
				* f.yaw
				* CFrame.Angles(0, BLADE * phi + (1 - k) * TAU, 0)
				* CFrame.Angles(math.rad(16) * blend, 0, math.rad(3) * math.sin(f.t * 0.8))
				* REST
			cT, cCF, cPhi, cP = f.t, cf, phi, p
			return cf
		end
		K.move(a, scy, scythe)
		-- the thick mint crescent trail behind the blade, and a thin white-hot one on its edge (only while it twirls)
		local trail = K.trail(scy, MID + UPV * 0.95, MID - UPV * 0.95, K.seq(GHOST_W, MINT, rgb(30, 120, 90)), 0.45, 0.85)
		trail.Transparency = ns(0, 0.1, 0.5, 0.4, 1, 1)
		trail.WidthScale = ns(0, 1, 1, 0.3)
		K.bright(trail, 1.3)
		trail.Enabled = false
		local edgeTrail = K.trail(scy, EDGE + UPV * 0.14, EDGE - UPV * 0.14, K.seq(WHITE, GHOST_W, MINT), 0.3, 1)
		K.bright(edgeTrail, 1.6)
		edgeTrail.Enabled = false
		-- glints on the steel, pink and white petals drifting off the flowering vine
		local glints = E(H.att(scy, MID), { tex = T.glint, flip = 4, colors = K.seq(WHITE, GHOST), rate = 2.5, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 1, spread = 180, light = 1, bright = 1.8 })
		local petals = E(H.att(scy, Vector3.new(-BLADE * 0.38 * S.X, -0.1 * S.Y, 0)), { tex = BFX.petal, colors = K.seq(BLOOM, WHITE), rate = 1.6, life = { 1.6, 2.2 }, speed = { 0.3, 0.8 }, size = 0.32, accel = Vector3.new(0, -0.8, 0), spin = 120, spread = 180, light = 0.2, bright = 1.2 })
		K.addEmitter(a, glints)
		K.addEmitter(a, petals)
		H.detail(a, glints, petals)
		-- your own scythe goes half see-through while the camera is behind you (it hangs between the camera and you)
		local ghostNow = -1
		H.job(a, function(self, f)
			local m = 0
			if f.player ~= nil and f.player == H.player then
				local cam = workspace.CurrentCamera
				if cam and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3 then
					m = 0.5
				end
			end
			if m ~= ghostNow then
				ghostNow = m
				scy.LocalTransparencyModifier = m
			end
		end)

		-- THE TOPIARY (ForgeGUI hr_topiary: a rounded bush with flowers, base down): a ring of eight on the emblem's rim,
		-- each with a small copy of itself as the top that pops off when cut, its own burst of leaves and of petals
		-- (they sprout up one after another as the aura forms). Without the prop: plain leafy balls.
		local function leafy(p: BasePart)
			if not p:IsA("MeshPart") then
				local b = p :: Part
				b.Shape = Enum.PartType.Ball
				b.Material = Enum.Material.LeafyGrass
				b.Color = HEDGE
				b.Transparency = 0
			end
		end
		local hedges = {}
		for i = 1, HEDGES do
			local p = H.prop(a.model, "hr_topiary", TOPIARY)
			leafy(p)
			local full = H.propSize("hr_topiary", TOPIARY)
			p.Size = full * 0.05
			local top = H.prop(a.model, "hr_topiary", TOPIARY * 0.5)
			leafy(top)
			top.Transparency = 1
			local th = (i - 0.5) / HEDGES * TAU
			local h = { th = th, dx = BLADE * math.sin(th), dz = math.cos(th), part = p, top = top, full = full, cut = 0, vis = 0, s = 0.05, tall = 0.05, popAt = -1e9 }
			h.trim = H.layer(a, "Loop_HedgeReaper", "Trim", p)
			h.bloom = E(p, { tex = BFX.petal, colors = K.seq(BLOOM, WHITE), rate = 0, life = { 0.8, 1.2 }, speed = { 4, 7 }, size = 0.38, accel = Vector3.new(0, -12, 0), spin = 300, spread = 60, light = 0.2, bright = 1.2 })
			local yawOff = i * 0.9 -- (each bush turned its own way)
			local function base(f): CFrame
				return CFrame.new(f.feet) * f.yaw * CFrame.new(h.dx * HEDGE_R, 0, h.dz * HEDGE_R)
			end
			K.move(a, p, function(f)
				return base(f) * CFrame.new(0, h.full.Y * h.tall / 2 - 0.05, 0) * CFrame.Angles(0, yawOff, 0)
			end)
			-- the popped top: up and outward, spinning, then gone (hidden inside the bush the rest of the time)
			K.move(a, top, function(f)
				local k = (f.t - h.popAt) / 0.75
				if k < 0 or k >= 1 then
					return base(f) * CFrame.new(0, 0.3, 0)
				end
				local y = h.full.Y * h.tall + 0.3 + 4.5 * k - 4 * k * k
				return base(f) * CFrame.new(h.dx * 1.6 * k, y, h.dz * 1.6 * k) * CFrame.Angles(k * 5, yawOff, k * 3)
			end)
			hedges[i] = h
		end
		-- a mint slash at each bush the blade cuts (moved there just before it fires)
		local slashAt = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		local slash = E(slashAt, { tex = T.crescent, flip = 4, colors = K.seq(GHOST_W, MINT), rate = 0, life = { 0.3, 0.4 }, speed = { 0, 0 }, size = 3, spread = 0, light = 0.9, bright = 1.6, sizeSeq = ns(0, 2.2, 1, 3.8), trans = ns(0, 0.1, 0.6, 0.25, 1, 1) })
		local function pop(h, f, slashIt: boolean)
			h.cut = 1
			h.popAt = f.t
			h.top.Transparency = 0
			emit(h.trim, 8)
			h.bloom:Emit(5)
			if slashIt then
				local cf = h.part.CFrame
				slashAt.CFrame = CFrame.new(cf.Position + Vector3.new(0, h.full.Y * 0.6, 0))
				slash:Emit(1)
			end
		end
		-- the sweeps (every 4 s, the first a second after the aura forms), the trails and the cuts: the blade pops each
		-- bush's top as it passes over it and the bush grows back over ~2 s; running sinks them all into the ground
		local lastT: number? = nil
		local lastPhi = 0
		local function hedgeJob(self, f)
			local dt = if lastT then math.clamp(f.t - lastT, 0, 0.1) else 0
			lastT = f.t
			local age = f.t - self.born
			if age < 0.25 then
				nextSweep = self.born + 1.1
				sweepAt = -1e9
			elseif f.t >= nextSweep and f.t - sweepAt >= sweepLen then
				sweepAt, sweepLen, nextSweep = f.t, SWEEP_TIME, f.t + SWEEP_EVERY
			end
			scythe(f)
			local sweeping = cP >= 0 and cP < 1
			if sweeping ~= trail.Enabled then
				trail.Enabled = sweeping
				edgeTrail.Enabled = sweeping
			end
			local away = math.clamp((1 - f.calm) * 1.6, 0, 1)
			for i, h in hedges do
				if sweeping and h.th > lastPhi and h.th <= cPhi and h.vis > 0.5 then
					pop(h, f, true)
				end
				h.cut = math.max(0, h.cut - dt / 1.8)
				h.vis = ease((age - 0.05 - i * 0.05) / 0.55) * (1 - away)
				local sz = math.max(0.05, h.vis)
				local tall = sz * (1 - 0.42 * math.min(1, h.cut * 1.6))
				if math.abs(sz - h.s) > 0.008 or math.abs(tall - h.tall) > 0.008 then
					h.s, h.tall = sz, tall
					h.part.Size = h.full * Vector3.new(sz, tall, sz)
				end
				-- the popped top fades out as it falls
				local k = (f.t - h.popAt) / 0.75
				if k >= 0 and k <= 1.2 then
					h.top.Transparency = if k >= 1 then 1 else math.max(0, k * 1.6 - 0.6)
				end
			end
			lastPhi = if sweeping then cPhi else 0
		end
		H.job(a, hedgeJob)

		-- THE REAP WAVE's charge: eight soul flames round your feet, one lit per swing (your own swings: other
		-- players' aren't sent, so theirs stay faint); the eighth swing is the wave
		local function reapCount(f): number?
			local sw = H.swings(f)
			if sw == nil then
				return nil
			end
			return ((a.reapBase and sw - a.reapBase) or sw) % 8
		end
		local pips = H.pips(a, 8, PIP_R, rgb(20, 70, 60), GHOST, 0.3, reapCount)
		local pipFire = {}
		for i, p in pips do
			pipFire[i] = E(p, { tex = T.flame, flip = 4, colors = SOUL_DIM, rate = 3.5, life = { 0.5, 0.7 }, speed = { 0.6, 1 }, size = 0.9, accel = Vector3.new(0, 2.5, 0), spread = 6, light = 0.8, bright = 1.4, rot = { -10, 10 }, sizeSeq = DIM_SIZE, trans = DIM_TR })
		end
		local lastLit = -2
		H.job(a, function(self, f)
			local n = reapCount(f) or 0
			if n == lastLit then
				return
			end
			lastLit = n
			for i, fl in pipFire do
				local on = i <= n
				fl.Rate = if on then 7 else 3.5
				fl.Color = if on then SOUL else SOUL_DIM
				fl.Size = if on then LIT_SIZE else DIM_SIZE
				fl.Transparency = if on then LIT_TR else DIM_TR
			end
		end)

		-- THE SOULS: tall mint soul fire off both shoulders (twice the height it had, toned so it doesn't blow out; a
		-- touch back and out so it clears your face), soul orbs drifting round you, three soul wisps circling on long
		-- trails (clear of your body), a dark shroud round your legs, a thin mint outline (the body itself isn't tinted)
		local soulFire = {}
		for _, side in { -1, 1 } do
			local sh = K.piece(a.body, Vector3.new(0.6, 0.3, 0.5))
			K.move(a, sh, function(f)
				return f.root * CFrame.new(side * 1.35, 1.3, 0.3)
			end)
			for _, e in H.layer(a, "Loop_HedgeReaper", "SoulFire", sh, false, 1.7) do
				e.LightEmission = 0.75
				K.bright(e, 1.25)
				table.insert(soulFire, e)
			end
		end
		H.layer(a, "Loop_HedgeReaper", "Orbs", K.bodyBox(a, Vector3.new(4.6, 5, 4.6), 0))
		for i = 1, 3 do
			local orb = K.piece(a.body, Vector3.new(0.34, 0.34, 0.34), GHOST_W, 0)
			orb.Shape = Enum.PartType.Ball
			local tr = H.trailed(orb, SOUL, 0.9, 0.3)
			if i == 3 then
				H.detail(a, orb, tr)
			end
			local off = (i - 1) / 3 * TAU
			K.move(a, orb, function(f)
				local th = -BLADE * f.t * 1.5 + off
				local r = 3.1 + 0.25 * math.cos(f.t * 1.1 + off)
				return CFrame.new(f.root.Position + Vector3.new(math.cos(th) * r, 0.4 + 1.6 * math.sin(f.t * 0.9 + off), math.sin(th) * r))
			end)
		end
		local shroud = E(K.bodyBox(a, Vector3.new(2.6, 2, 1.8), -1.7), { tex = FX.smoke, colors = K.seq(rgb(16, 52, 46), POOL), rate = 5, life = { 1.2, 1.8 }, speed = { 0.2, 0.6 }, size = 2, accel = Vector3.new(0, 0.5, 0), spin = 20, spread = 60, light = 0, bright = 1, trans = ns(0, 1, 0.3, 0.5, 1, 1) })
		K.addEmitter(a, shroud)
		H.detail(a, shroud)
		local hl = K.outline(a, GHOST, 0.45)
		if hl then
			hl.FillTransparency = 1
		end
		K.light(a, MINT, 0.55, 10)
		H.lightJob(a, 0.25)
		-- running: a ghostly trail at your feet and wisps kicked up
		K.feetTrail(a, K.seq(GHOST, MINT, rgb(12, 40, 22)))
		local kick = H.feetPiece(a, Vector3.new(1.4, 0.3, 1.4), 0.3)
		K.addEmitter(a, E(kick, { tex = T.wisp, colors = K.seq(GHOST, MINT), rate = 10, life = { 0.5, 0.8 }, speed = { 1, 2.5 }, size = 1.1, accel = Vector3.new(0, 3, 0), spread = 40, light = 0.8, bright = 1.4 }), true)

		-- THE WAVE (the server's reapWave near you): souls burst out, a ghost ring rolls out past the hedges, the
		-- scythe twirls at once (unless it's mid-twirl already), every bush's top pops, the flames flare and start again
		local burstAt = H.feetPiece(a, Vector3.new(2, 0.3, 2), 0.3)
		local burst = E(burstAt, { tex = T.wisp, colors = SOUL, rate = 0, life = { 0.6, 1 }, speed = { 8, 12 }, size = 1.3, accel = Vector3.new(0, 4, 0), drag = 2, spread = 80, light = 0.9, bright = 1.6 })
		H.gimmick(a, { reapWave = true }, 16, function(self, d)
			local sw = H.swings({ player = self.owner })
			if sw then
				self.reapBase = sw
			end
			local now = os.clock()
			if now - sweepAt >= sweepLen then
				sweepAt, sweepLen, nextSweep = now, WAVE_TIME, now + SWEEP_EVERY
			end
			local f = { t = now }
			for _, h in hedges do
				if h.vis > 0.5 then
					pop(h, f, false)
				end
			end
			burst:Emit(18)
			emit(pipFire, 5)
			K.pulse(self.rootPos - Vector3.new(0, 2.7, 0), 2, HEDGE_R * 2 + 10, GHOST, 0.75, 0)
			self.lightKick = 3
		end)

		-- the entrance (the bushes sprout, the scythe drops in spinning, then twirls): two rings, a burst of souls, the
		-- dark mist rolling in
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 15, MINT, 0.8, 0)
			K.pulse(feet, 1, 10, GHOST_W, 0.55, 0.25)
			burst:Emit(14)
			emit(soulFire, 8)
			emit(mist, 3)
			pool:Emit(4)
			self.lightKick = 2.5
		end
		return a
	end
end
