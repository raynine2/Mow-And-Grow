-- HEDGE REAPER (Epic). The card: a reaper's scythe, its long snath wrapped in a flowering vine, cutting a hedge in one
-- sweep. (The card's purple is the Epic rarity's colour, so it isn't used: the aura is hedge green, bramble dark, the
-- scythe's pale steel and the mint ghost-light of its edge, pushed toward cyan-white so it doesn't sink into the lawn.)
-- Gimmick: Reap Wave, every 8th swing sends a wave that hits every clump round you.
-- The aura, built round ForgeGUI pieces:
--   ground     the bramble emblem (thorns round a dark pool, a mint crescent) in a pall of dark mist, a crisp mint
--              rim, ghost-light rising off the rim to above your head
--   scythe     the vine-wrapped scythe hovering on a slant at your back (petals drift off the vine, the steel
--              glints); every 4 s it swings down off your back and sweeps a full circle round you, a mint crescent
--              trail behind its blade
--   hedges     a ring of eight trimmed hedges standing on the emblem's thorns: the sweep cuts each one as it passes
--              (leaves fly, a mint slash) and they grow back; they sink into the ground while you run
--   souls      mint soul fire rising off your shoulders, soul orbs circling you on trails, a ghostly body glow
--   Reap Wave  eight soul flames round your feet, one lit per swing (your own swings; small dim embers otherwise).
--              The wave makes the scythe sweep at once, cuts every hedge, rolls a ghost ring out and starts the
--              flames again.
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local HEDGE = rgb(45, 135, 60)
	local HEDGE_D = rgb(12, 40, 22)
	local MINT = rgb(110, 255, 215)
	local GHOST = rgb(175, 255, 240)
	local GHOST_W = rgb(232, 255, 252)
	local BLOOM = rgb(255, 170, 215) -- the vine's flowers
	local SOUL = K.seq(GHOST_W, rgb(120, 255, 220), rgb(30, 120, 90)) -- soul fire: white-hot to deep mint
	local TAU = math.pi * 2

	local SCYTHE = 7.2 -- the scythe's length (about 1.4x your height)
	-- (GUESS) the side of the prop its blade hooks to (+1 = +X). The sweep turns that way so the blade's tip leads;
	-- set -1 if the screenshots show the blade dragging backwards.
	local BLADE = 1
	local HEDGES, HEDGE_R, HEDGE_SIZE = 8, 5, 1.7 -- the hedge ring: how many, its radius, each hedge's width
	local CUT_Y = 1 -- the blade's height over the ground in the sweep: the hedges are trimmed down to it
	local TILT = math.rad(22) -- in the sweep the snath slopes this much, from your chest down to the blade
	local SWEEP_EVERY, SWEEP_TIME, WAVE_TIME = 4, 1.2, 0.8
	local PIP_R = 3.3 -- the ring of eight soul flames
	-- a soul flame lit, and unlit (a small dim ember)
	local LIT_SIZE, LIT_TR = ns(0, 0.75, 0.35, 1.15, 1, 0.2), ns(0, 0.2, 0.6, 0.35, 1, 1)
	local DIM_SIZE, DIM_TR = ns(0, 0.35, 0.35, 0.5, 1, 0.1), ns(0, 0.55, 0.6, 0.7, 1, 1)

	return function()
		local a = H.aura(H.RANK.Epic, MINT)
		local function emit(list: { ParticleEmitter }, n: number)
			for _, e in list do
				e:Emit(n)
			end
		end

		-- THE GROUND: the bramble emblem turning slowly, a crisp mint rim round it, a faint ring through the soul
		-- flames, dark mist rolling off the hedge ring, ghost-light rising off the rim (a ring of wisps up past your head)
		H.sigil(a, 11.6, T.embHedgeReaper, WHITE, 0.18, -0.08, 0.12, 0.8, 1.15)
		H.glowRing(a, HEDGE_R + 0.95, MINT, 0.3, 0, 0.16, 1.3)
		H.glowRing(a, PIP_R, GHOST, 0.62, 0, 0.15, 1.2)
		local mistRing = H.feetPiece(a, Vector3.new(HEDGE_R * 2, 0.6, HEDGE_R * 2), 0.3)
		local mist = H.layer(a, "Loop_HedgeReaper", "Mist", mistRing, false, 0.8) -- (a touch smaller: it pools round the hedges' feet)
		local riseRing = H.feetPiece(a, Vector3.new(HEDGE_R * 2 + 1.4, 0.2, HEDGE_R * 2 + 1.4), 0.2)
		local rise = E(riseRing, { tex = T.wisp, colors = K.seq(GHOST_W, GHOST, MINT), rate = 9, life = { 0.9, 1.3 }, speed = { 3, 4.5 }, size = 1.1, accel = Vector3.new(0, 1.5, 0), spread = 0, light = 1, bright = 1.8, shape = Enum.ParticleEmitterShape.Disc, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.2, 0.3, 1, 1), sizeSeq = ns(0, 0.5, 0.4, 1.25, 1, 0.2) })
		rise.ShapePartial = 0.8 -- (the disc's outer fifth only: a ring)
		K.addEmitter(a, rise)

		-- THE SCYTHE (ForgeGUI hr_scythe: flat in its XY plane, the snath along Y, the blade at the top)
		local scy = H.prop(a.body, "hr_scythe", SCYTHE)
		local S = H.propSize("hr_scythe", SCYTHE)
		local BLADE_PT = Vector3.new(BLADE * 0.12 * S.X, 0.36 * S.Y, 0) -- (about the middle of the blade)
		-- the sweep pose, in a frame at your feet turned to the sweep's angle (+Z the way the snath points): the snath
		-- slopes from your chest out and down, the blade lying almost flat at hedge height, its tip leading
		local down = Vector3.new(0, -math.sin(TILT), math.cos(TILT))
		local SWEEP_POSE = CFrame.fromMatrix(Vector3.new(0, CUT_Y, HEDGE_R) - Vector3.xAxis * BLADE_PT.X - down * BLADE_PT.Y, Vector3.xAxis, down)
		local LEAN = -BLADE * math.rad(28) -- (at rest its top leans the way the blade hooks: the blade hangs past your shoulder)
		-- At rest it hovers on a slant at your back, bobbing (it drops in from above with a spin as the aura forms);
		-- in a sweep it swings down into the sweep pose and goes a full circle. Worked out once a frame (the trail, the
		-- slash and the hedge cuts all read it).
		local sweepAt, sweepLen, nextSweep = -1e9, SWEEP_TIME, 0
		local cT, cCF, cPhi, cP = -1, CFrame.identity, 0, 2
		local function scythe(f): CFrame
			if f.t == cT then
				return cCF
			end
			local k = ease((f.t - a.born - 0.1) / 0.8)
			local cf = f.root
				* CFrame.new(0, 0.9 + 0.15 * math.sin(f.t * 1.3) + 4 * (1 - k), 1.25)
				* CFrame.Angles(math.rad(8), 0, LEAN + math.rad(3) * math.sin(f.t * 0.8))
				* CFrame.Angles(0, (1 - k) * TAU, 0)
			local p = (f.t - sweepAt) / sweepLen
			local phi = 0
			if p >= 0 and p < 1 then
				phi = (p - math.sin(p * TAU) / TAU) * TAU -- (eases in and out, fastest halfway round)
				local blend = smooth(p / 0.14) * smooth((1 - p) / 0.14)
				cf = cf:Lerp(CFrame.new(f.feet) * f.yaw * CFrame.Angles(0, BLADE * phi, 0) * SWEEP_POSE, blend)
			end
			cT, cCF, cPhi, cP = f.t, cf, phi, p
			return cf
		end
		K.move(a, scy, scythe)
		-- the mint crescent trail behind the blade (only while it sweeps)
		local trail = K.trail(scy, Vector3.new(0, 0.47 * S.Y, 0), Vector3.new(0, 0.2 * S.Y, 0), K.seq(GHOST_W, MINT, HEDGE), 0.4, 1)
		trail.Enabled = false
		-- a mint slash where it cuts each hedge
		local slashAt = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, slashAt, function(f)
			return scythe(f) * CFrame.new(BLADE_PT)
		end)
		local slash = E(slashAt, { tex = T.crescent, flip = 4, colors = K.seq(GHOST_W, MINT), rate = 0, life = { 0.3, 0.4 }, speed = { 0, 0 }, size = 3, spread = 0, light = 1, bright = 2.2, sizeSeq = ns(0, 2.6, 1, 4.6), trans = ns(0, 0, 0.6, 0.15, 1, 1) })
		-- glints on the steel, pink and white petals drifting off the flowering vine
		local glints = E(H.att(scy, BLADE_PT), { tex = T.glint, flip = 4, colors = K.seq(WHITE, GHOST), rate = 2.5, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 0.9, spread = 180, light = 1, bright = 2.2 })
		local petals = E(H.att(scy, Vector3.new(0, -0.1 * S.Y, 0)), { tex = BFX.petal, colors = K.seq(BLOOM, WHITE), rate = 1.6, life = { 1.6, 2.2 }, speed = { 0.3, 0.8 }, size = 0.3, accel = Vector3.new(0, -0.8, 0), spin = 120, spread = 180, light = 0.2, bright = 1.2 })
		K.addEmitter(a, glints)
		K.addEmitter(a, petals)
		H.detail(a, glints, petals)

		-- THE HEDGES (ForgeGUI hr_hedge, a touch taller than the prop): a ring of eight on the emblem's thorns, each with
		-- its own burst of cut leaves (they sprout up one after another as the aura forms)
		local hedges = {}
		for i = 1, HEDGES do
			local p = H.prop(a.model, "hr_hedge", HEDGE_SIZE)
			local full = H.propSize("hr_hedge", HEDGE_SIZE) * Vector3.new(1, 1.3, 1)
			p.Size = full * 0.05
			local h = { th = (i - 0.5) / HEDGES * TAU, part = p, full = full, cut = 0, vis = 0, s = 0.05, tall = 0.05, y = full.Y * 0.025 }
			h.trim = H.layer(a, "Loop_HedgeReaper", "Trim", p)
			K.move(a, p, function(f)
				return CFrame.new(f.feet) * f.yaw * CFrame.Angles(0, BLADE * h.th, 0) * CFrame.new(0, h.y - 0.25, HEDGE_R)
			end)
			hedges[i] = h
		end
		-- the sweeps (every 4 s, the first a second after the aura forms), the trail, and the cuts: the blade cuts
		-- each hedge as it passes (it drops to blade height, leaves fly, a slash) and it grows back over ~2 s; running
		-- sinks them all into the ground
		local lastT: number? = nil
		local lastPhi = 0
		H.job(a, function(self, f)
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
			end
			local away = math.clamp((1 - f.calm) * 1.6, 0, 1)
			for i, h in hedges do
				if sweeping and h.th > lastPhi and h.th <= cPhi and h.vis > 0.5 then
					h.cut = 1
					emit(h.trim, 8)
					slash:Emit(1)
				end
				h.cut = math.max(0, h.cut - dt / 1.8)
				h.vis = ease((age - 0.05 - i * 0.05) / 0.55) * (1 - away)
				local s = math.max(0.05, h.vis)
				local tall = s * (1 - 0.4 * math.min(1, h.cut * 1.6))
				if math.abs(s - h.s) > 0.008 or math.abs(tall - h.tall) > 0.008 then
					h.s, h.tall = s, tall
					h.part.Size = h.full * Vector3.new(s, tall, s)
					h.y = h.full.Y * tall / 2
				end
			end
			lastPhi = if sweeping then cPhi else 0
		end)

		-- THE REAP WAVE's charge: eight soul flames round your feet, one lit per swing (your own swings: other
		-- players' aren't sent, so theirs stay embers); the eighth swing is the wave
		local function reapCount(f): number?
			local s = H.swings(f)
			if s == nil then
				return nil
			end
			return ((a.reapBase and s - a.reapBase) or s) % 8
		end
		local pips = H.pips(a, 8, PIP_R, rgb(28, 82, 70), GHOST, 0.36, reapCount)
		local pipFire = {}
		for i, p in pips do
			pipFire[i] = E(p, { tex = T.flame, flip = 4, colors = SOUL, rate = 1.5, life = { 0.45, 0.65 }, speed = { 0.8, 1.4 }, size = 0.5, accel = Vector3.new(0, 3, 0), spread = 6, light = 0.8, bright = 1.5, rot = { -12, 12 }, sizeSeq = DIM_SIZE, trans = DIM_TR })
		end
		H.detail(a, table.unpack(pipFire))
		local lastLit = -2
		H.job(a, function(self, f)
			local c = reapCount(f) or 0
			if c == lastLit then
				return
			end
			lastLit = c
			for i, fl in pipFire do
				local on = i <= c
				fl.Rate = if on then 7 else 1.5
				fl.Size = if on then LIT_SIZE else DIM_SIZE
				fl.Transparency = if on then LIT_TR else DIM_TR
			end
		end)

		-- THE SOULS: mint soul fire rising off both shoulders (clear of your face), soul orbs drifting round you, three
		-- soul wisps circling on long trails, a ghostly body glow and a mint outline (the body itself isn't tinted)
		local soulFire = {}
		for _, side in { -1, 1 } do
			local sh = K.piece(a.body, Vector3.new(0.7, 0.3, 0.6))
			K.move(a, sh, function(f)
				return f.root * CFrame.new(side * 1.2, 1.35, 0.3)
			end)
			for _, e in H.layer(a, "Loop_HedgeReaper", "SoulFire", sh) do
				table.insert(soulFire, e)
			end
		end
		H.layer(a, "Loop_HedgeReaper", "Orbs", K.bodyBox(a, Vector3.new(4.2, 5, 4.2), 0))
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
				local r = 2.6 + 0.3 * math.cos(f.t * 1.1 + off)
				return CFrame.new(f.root.Position + Vector3.new(math.cos(th) * r, 0.4 + 1.6 * math.sin(f.t * 0.9 + off), math.sin(th) * r))
			end)
		end
		H.shell(a, K.seq(GHOST, MINT), 7, 1)
		local hl = K.outline(a, GHOST, 0.35)
		if hl then
			hl.FillTransparency = 1
		end
		K.light(a, MINT, 1.1, 12)
		H.lightJob(a, 0.25)
		-- running: a ghostly trail at your feet and wisps kicked up
		K.feetTrail(a, K.seq(GHOST, MINT, HEDGE_D))
		local kick = H.feetPiece(a, Vector3.new(1.4, 0.3, 1.4), 0.3)
		K.addEmitter(a, E(kick, { tex = T.wisp, colors = K.seq(GHOST, MINT), rate = 10, life = { 0.5, 0.8 }, speed = { 1, 2.5 }, size = 1.1, accel = Vector3.new(0, 3, 0), spread = 40, light = 1, bright = 1.6 }), true)

		-- THE WAVE (the server's reapWave near you): souls burst out, a ghost ring rolls out past the hedges, the
		-- scythe sweeps at once (unless it's mid-sweep already), every hedge is cut, the flames flare and start again
		local burstAt = H.feetPiece(a, Vector3.new(2, 0.3, 2), 0.3)
		local burst = E(burstAt, { tex = T.wisp, colors = SOUL, rate = 0, life = { 0.6, 1 }, speed = { 8, 12 }, size = 1.3, accel = Vector3.new(0, 4, 0), drag = 2, spread = 80, light = 1, bright = 1.8 })
		H.gimmick(a, { reapWave = true }, 16, function(self, d)
			local s = H.swings({ player = self.owner })
			if s then
				self.reapBase = s
			end
			local now = os.clock()
			if now - sweepAt >= sweepLen then
				sweepAt, sweepLen, nextSweep = now, WAVE_TIME, now + SWEEP_EVERY
			end
			for _, h in hedges do
				if h.vis > 0.5 then
					h.cut = 1
					emit(h.trim, 6)
				end
			end
			burst:Emit(18)
			emit(pipFire, 5)
			K.pulse(self.rootPos - Vector3.new(0, 2.7, 0), 2, HEDGE_R * 2 + 10, GHOST, 0.75, 0)
			self.lightKick = 3
		end)

		-- the entrance (the hedges sprout, the scythe drops in spinning, then sweeps): two rings and a burst of souls
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 15, MINT, 0.8, 0)
			K.pulse(feet, 1, 10, GHOST_W, 0.55, 0.25)
			burst:Emit(14)
			emit(soulFire, 8)
			emit(mist, 3)
			self.lightKick = 3
		end
		return a
	end
end
