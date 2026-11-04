-- HEDGE REAPER (Epic). The card: a reaper's scythe, its long snath wrapped in a flowering vine, cutting a hedge in one
-- sweep. (The card's purple is the Epic rarity's colour, so it isn't used: the aura is hedge green, a teal-black pool,
-- the scythe's pale steel and the mint ghost-fire of its edge.)
-- Gimmick: Reap Wave, every 8th swing sends a wave that hits every clump round you.
-- The aura, built round ForgeGUI pieces (round 3: no white bloom anywhere, everything mint and dark teal):
--   ground     the bramble emblem with a teal-black pool and dark mist rolling over it, three crisp mint rings (the
--              inner one dashed and turning)
--   scythe     the vine-wrapped scythe, twice your height, standing at your right shoulder like a reaper's: its vine-
--              wrapped snath beside you (seen from the front too), the blade arcing over your head with a glowing mint
--              edge. Every 4 s it twirls a full circle round you overhead, mint crescent afterimages and a mint trail
--              behind its blade. It stays solid (your own fades a touch only while the camera is behind you).
--   hedges     a ring of twelve trimmed hedge blocks (ForgeGUI hr_hedge, cut low and long) out past the emblem: as the
--              blade passes each one its top is sliced off in leaves and petals with a mint slash, leaving a cut gap that
--              grows back; they sink into the ground while you run
--   souls      mint soul flames with dark-teal tongues off your shoulders (clear of your head), soul wisps circling you
--              on trails, a dark shroud round your legs
--   Reap Wave  eight soul candles round your feet, one lit per swing (lit: a tall mint flame; unlit: a small teal one).
--              The wave makes the scythe twirl at once, slices every hedge, rolls a mint shockwave out and starts the
--              candles again.
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local HEDGE = rgb(45, 135, 60)
	local MINT = rgb(110, 255, 215)
	local MINT_L = rgb(170, 255, 230) -- the palest it ever gets (never white)
	local TEAL = rgb(40, 160, 130)
	local TEAL_D = rgb(12, 62, 54)
	local POOL = rgb(4, 18, 17) -- the teal-black pool
	local BLOOM = rgb(255, 170, 215) -- the vine's flowers
	local SOUL = K.seq(MINT_L, MINT, TEAL, TEAL_D) -- soul fire: pale mint core to dark teal
	local SOUL_DIM = K.seq(rgb(80, 175, 150), TEAL_D)
	local EDGE_TEX = "rbxassetid://130447905124051" -- (FxTex.trail: a thin bright core in a soft halo, for beams)
	local TAU = math.pi * 2

	local SCYTHE = 10 -- the scythe's length (twice your height)
	-- (GUESS, from the v6a back shot) the side of the prop its blade hooks to (+1 = +X). It's turned so the blade hooks
	-- over your head from the right; set -1 if the screenshots show the blade hooking away from you.
	local BLADE = 1
	local TILT = math.rad(15) -- the snath leans this much toward your head
	local FOOT = Vector3.new(4, -2.75, 1.3) -- where the snath's foot rests (by the ground, right of your right heel, a little behind)
	local HEDGES, HEDGE_R = 12, 6.4 -- the hedge ring: how many blocks, its radius
	local HEDGE_SIZE = Vector3.new(2.7, 1.2, 1.3) -- each block: long round the ring, low, a stride deep
	local SWEEP_EVERY, SWEEP_TIME, WAVE_TIME = 4, 1.2, 0.8
	local PIP_R = 3.4 -- the ring of eight soul candles
	-- a soul flame lit (tall, mint) and unlit (small, teal, still visible)
	local LIT_SIZE, LIT_TR = ns(0, 0.8, 0.35, 1.35, 1, 0.2), ns(0, 0.1, 0.55, 0.25, 1, 1)
	local DIM_SIZE, DIM_TR = ns(0, 0.5, 0.35, 0.8, 1, 0.1), ns(0, 0.4, 0.6, 0.55, 1, 1)

	return function()
		local a = H.aura(H.RANK.Epic, MINT)
		local function emit(list: { ParticleEmitter }, n: number)
			for _, e in list do
				e:Emit(n)
			end
		end

		-- THE GROUND: the bramble emblem turning slowly; a teal-black pool over its middle (a soft dark disc), dark teal
		-- mist rolling over it to knee height; three crisp mint rings: by your feet (dashed, turning), inside the soul
		-- candles' ring, and just outside the hedges
		H.sigil(a, 11.6, T.embHedgeReaper, WHITE, 0.2, -0.08, 0.12, 0.8, 1)
		H.glowDisc(a, 9, FX.glow, POOL, 0.25, 0, 0.145, 1)
		K.groundRing(a, 2.3, 0.09, MINT, 3, 0.35, -0.5, true, 0.17)
		H.glowRing(a, 4.5, MINT, 0.45, 0, 0.165, 1)
		H.glowRing(a, HEDGE_R + 1.15, TEAL, 0.4, 0, 0.175, 1)
		local mistRing = H.feetPiece(a, Vector3.new(8, 0.6, 8), 0.3)
		local mist = H.layer(a, "Loop_HedgeReaper", "Mist", mistRing, false, 0.8)
		local poolPart = H.feetPiece(a, Vector3.new(7.5, 0.3, 7.5), 0.3)
		local pool = E(poolPart, { tex = FX.smoke, colors = K.seq(rgb(20, 66, 60), rgb(5, 22, 20)), rate = 7, life = { 2, 3 }, speed = { 0.3, 0.7 }, size = 3, accel = Vector3.new(0, 0.25, 0), spin = 15, spread = 40, light = 0, bright = 1, shape = Enum.ParticleEmitterShape.Disc, trans = ns(0, 1, 0.25, 0.3, 1, 1), sizeSeq = ns(0, 2, 1, 3.6) })
		K.addEmitter(a, pool)
		local rise = E(poolPart, { tex = T.wisp, colors = K.seq(MINT, TEAL), rate = 3, life = { 0.9, 1.3 }, speed = { 2, 3 }, size = 0.8, accel = Vector3.new(0, 1, 0), spread = 0, light = 0.4, bright = 1.2, shape = Enum.ParticleEmitterShape.Disc, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.25, 0.4, 1, 1), sizeSeq = ns(0, 0.4, 0.4, 1, 1, 0.2) })
		K.addEmitter(a, rise)
		H.detail(a, rise)

		-- THE SCYTHE (ForgeGUI hr_scythe: flat in its XY plane, the snath along Y, the blade at the top hooking to BLADE)
		local scy = H.prop(a.body, "hr_scythe", SCYTHE)
		local S = H.propSize("hr_scythe", SCYTHE)
		-- the rest pose, in a frame at your root turned to your facing: turned so the blade hooks toward you, leaning in,
		-- the snath's foot placed at FOOT
		local FLIP = if BLADE > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		local c, s = math.cos(TILT), math.sin(TILT)
		local footX = 0.38 * S.X * c + 0.5 * S.Y * s -- (the snath's foot after the turn and the lean, from the centre)
		local footY = 0.38 * S.X * s - 0.5 * S.Y * c
		local REST = CFrame.new(FOOT.X - footX, FOOT.Y - footY, FOOT.Z) * CFrame.Angles(0, 0, TILT) * FLIP
		-- (GUESS, from the v6a back shot) points on the blade as fractions of the prop: its middle, its inner (cutting)
		-- edge from the snath to the tip
		local function bp(fx: number, fy: number): Vector3
			return Vector3.new(BLADE * fx * S.X, fy * S.Y, 0)
		end
		local MID = bp(0.15, 0.36)
		-- straight up, in the prop's own frame at rest (the trail's attachments sit above and below the blade on it)
		local UPV = Vector3.new(-BLADE * s, c, 0)
		-- At rest it hovers, swaying (it drops in from above with a spin as the aura forms); in a sweep it twirls a full
		-- circle round you. Worked out once a frame (the trails, the afterimages and the hedge cuts read it).
		local sweepAt, sweepLen, nextSweep = -1e9, SWEEP_TIME, 0
		local cT, cCF, cPhi, cP = -1, CFrame.identity, 0, 2
		local function scythe(f): CFrame
			if f.t == cT then
				return cCF
			end
			local k = ease((f.t - a.born - 0.1) / 0.8)
			local p = (f.t - sweepAt) / sweepLen
			local phi = 0
			if p >= 0 and p < 1 then
				phi = (p - math.sin(p * TAU) / TAU) * TAU -- (eases in and out, fastest halfway round)
			end
			local cf = CFrame.new(f.root.Position + Vector3.new(0, 0.15 * math.sin(f.t * 1.3) + 4 * (1 - k), 0))
				* f.yaw
				* CFrame.Angles(0, BLADE * phi + (1 - k) * TAU, 0)
				* CFrame.Angles(0, 0, math.rad(2) * math.sin(f.t * 0.8))
				* REST
			cT, cCF, cPhi, cP = f.t, cf, phi, p
			return cf
		end
		K.move(a, scy, scythe)
		-- the blade's glowing mint edge (a soft beam along its cutting edge, always on)
		H.chain(scy, { bp(-0.23, 0.43), bp(0.02, 0.375), bp(0.25, 0.26), bp(0.46, 0.11) }, { colors = K.seq(MINT_L, MINT), w0 = 0.32, w1 = 0.1, trans = ns(0, 0.15, 1, 0.3), light = 0.5, bright = 1.3, tex = EDGE_TEX, texLen = 3 })
		-- the twirl's mint trail behind the blade, and mint crescent afterimages
		local trail = K.trail(scy, MID + UPV * 0.9, MID - UPV * 0.9, K.seq(MINT_L, MINT, TEAL_D), 0.4, 0.4)
		trail.Transparency = ns(0, 0.2, 0.5, 0.5, 1, 1)
		trail.WidthScale = ns(0, 1, 1, 0.3)
		K.bright(trail, 1.2)
		trail.Enabled = false
		local after = E(H.att(scy, MID), { tex = T.crescent, flip = 4, colors = K.seq(MINT, TEAL), rate = 0, life = { 0.3, 0.4 }, speed = { 0, 0 }, size = 4.5, spread = 0, light = 0.4, bright = 1.2, rot = { -15, 15 }, sizeSeq = ns(0, 3.5, 1, 5), trans = ns(0, 0.25, 0.6, 0.5, 1, 1) })
		-- a soft mint glint on the steel, pink and white petals drifting off the flowering vine
		local glints = E(H.att(scy, MID), { tex = T.glint, flip = 4, colors = K.seq(MINT_L, MINT), rate = 1.5, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 0.8, spread = 180, light = 0.5, bright = 1.3 })
		local petals = E(H.att(scy, bp(-0.38, -0.1)), { tex = BFX.petal, colors = K.seq(BLOOM, rgb(255, 225, 240)), rate = 1.6, life = { 1.6, 2.2 }, speed = { 0.3, 0.8 }, size = 0.32, accel = Vector3.new(0, -0.8, 0), spin = 120, spread = 180, light = 0.1, bright = 1.1 })
		K.addEmitter(a, glints)
		K.addEmitter(a, petals)
		H.detail(a, glints, petals)
		-- your own scythe fades a touch while the camera is behind you (it stands to the side, out of the camera's line)
		local ghostNow = -1
		H.job(a, function(self, f)
			local m = 0
			if f.player ~= nil and f.player == H.player then
				local cam = workspace.CurrentCamera
				if cam and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3 then
					m = 0.2
				end
			end
			if m ~= ghostNow then
				ghostNow = m
				scy.LocalTransparencyModifier = m
			end
		end)

		-- THE HEDGES (ForgeGUI hr_hedge, a trimmed boxy hedge, cut low and long): twelve blocks round the ring, each with
		-- a slab of itself as the top that's sliced off, its own burst of leaves and of petals (they sprout up one after
		-- another as the aura forms). Without the prop: leafy blocks.
		local function leafy(p: BasePart)
			if not p:IsA("MeshPart") then
				local b = p :: Part
				b.Material = Enum.Material.LeafyGrass
				b.Color = HEDGE
				b.Transparency = 0
			end
		end
		local TOP_SIZE = HEDGE_SIZE * Vector3.new(0.92, 0.38, 0.92)
		local hedges = {}
		for i = 1, HEDGES do
			local p = H.prop(a.model, "hr_hedge", 2)
			leafy(p)
			p.Size = HEDGE_SIZE * 0.05
			local top = H.prop(a.model, "hr_hedge", 2)
			leafy(top)
			top.Size = TOP_SIZE
			top.Transparency = 1
			local th = (i - 0.5) / HEDGES * TAU
			local h = { th = th, dx = BLADE * math.sin(th), dz = math.cos(th), part = p, top = top, cut = 0, vis = 0, s = 0.05, tall = 0.05, popAt = -1e9 }
			h.trim = H.layer(a, "Loop_HedgeReaper", "Trim", p)
			h.bloom = E(p, { tex = BFX.petal, colors = K.seq(BLOOM, rgb(255, 225, 240)), rate = 0, life = { 0.7, 1 }, speed = { 3, 6 }, size = 0.34, accel = Vector3.new(0, -12, 0), spin = 300, spread = 60, light = 0.1, bright = 1.1 })
			local turn = CFrame.Angles(0, BLADE * th, 0) -- (long side along the ring)
			local function base(f): CFrame
				return CFrame.new(f.feet) * f.yaw * CFrame.new(h.dx * HEDGE_R, 0, h.dz * HEDGE_R)
			end
			K.move(a, p, function(f)
				return base(f) * CFrame.new(0, HEDGE_SIZE.Y * h.tall / 2 - 0.05, 0) * turn
			end)
			-- the sliced-off top: up and outward, tumbling, then gone (hidden inside the block the rest of the time)
			K.move(a, top, function(f)
				local k = (f.t - h.popAt) / 0.75
				if k < 0 or k >= 1 then
					return base(f) * CFrame.new(0, 0.3, 0) * turn
				end
				local y = HEDGE_SIZE.Y * h.tall + TOP_SIZE.Y / 2 + 3.5 * k - 3.5 * k * k
				return base(f) * CFrame.new(h.dx * 1.5 * k, y, h.dz * 1.5 * k) * turn * CFrame.Angles(k * 2.5, 0, k * 1.5)
			end)
			hedges[i] = h
		end
		-- a mint slash at each block the blade cuts (moved there just before it fires)
		local slashAt = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		local slash = E(slashAt, { tex = T.crescent, flip = 4, colors = K.seq(MINT, TEAL), rate = 0, life = { 0.3, 0.4 }, speed = { 0, 0 }, size = 3, spread = 0, light = 0.45, bright = 1.2, sizeSeq = ns(0, 2.2, 1, 3.6), trans = ns(0, 0.15, 0.6, 0.35, 1, 1) })
		local function pop(h, f, slashIt: boolean)
			h.cut = 1
			h.popAt = f.t
			h.top.Transparency = 0
			emit(h.trim, 8)
			h.bloom:Emit(4)
			if slashIt then
				slashAt.CFrame = CFrame.new(h.part.CFrame.Position + Vector3.new(0, HEDGE_SIZE.Y * 0.6, 0))
				slash:Emit(1)
			end
		end
		-- the sweeps (every 4 s, the first a second after the aura forms), the trail, the afterimages and the cuts: the
		-- blade slices each block's top as it passes (it drops to 55% and grows back over ~2.5 s, a cut gap following
		-- the blade round); running sinks them all into the ground
		local lastT: number? = nil
		local lastPhi, nextAfter = 0, 0
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
			end
			if sweeping and f.t >= nextAfter then
				nextAfter = f.t + 0.07
				after:Emit(1)
			end
			local away = math.clamp((1 - f.calm) * 1.6, 0, 1)
			for i, h in hedges do
				if sweeping and h.th > lastPhi and h.th <= cPhi and h.vis > 0.5 then
					pop(h, f, true)
				end
				h.cut = math.max(0, h.cut - dt / 2.5)
				h.vis = ease((age - 0.05 - i * 0.04) / 0.55) * (1 - away)
				local sz = math.max(0.05, h.vis)
				local tall = sz * (1 - 0.45 * math.min(1, h.cut * 1.4))
				if math.abs(sz - h.s) > 0.008 or math.abs(tall - h.tall) > 0.008 then
					h.s, h.tall = sz, tall
					h.part.Size = HEDGE_SIZE * Vector3.new(sz, tall, sz)
				end
				-- the sliced top fades out as it falls
				local k = (f.t - h.popAt) / 0.75
				if k >= 0 and k <= 1.2 then
					h.top.Transparency = if k >= 1 then 1 else math.max(0, k * 1.6 - 0.6)
				end
			end
			lastPhi = if sweeping then cPhi else 0
		end
		H.job(a, hedgeJob)

		-- THE REAP WAVE's charge: eight soul candles round your feet (dark stone stubs), one lit per swing (your own
		-- swings: other players' aren't sent, so theirs stay unlit); the eighth swing is the wave
		local function reapCount(f): number?
			local sw = H.swings(f)
			if sw == nil then
				return nil
			end
			return ((a.reapBase and sw - a.reapBase) or sw) % 8
		end
		local STUB, STUB_LIT = rgb(30, 46, 44), rgb(60, 150, 128)
		local stubs, pipFire = {}, {}
		for i = 1, 8 do
			local stub = H.cyl(a.model, 0.42, 0.45, STUB, Enum.Material.Slate)
			local th = (i - 1) / 8 * TAU
			K.move(a, stub, function(f)
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * PIP_R, 0.33, math.sin(th) * PIP_R)) * CFrame.Angles(0, 0, math.pi / 2)
			end)
			stubs[i] = stub
			-- (the stub's own +X is up: the flame sits on its top and burns along it)
			pipFire[i] = E(H.att(stub, Vector3.new(0.22, 0, 0)), { tex = T.flame, flip = 4, colors = SOUL_DIM, rate = 4, life = { 0.5, 0.7 }, speed = { 0.6, 1 }, size = 0.8, accel = Vector3.new(0, 2.5, 0), spread = 6, dir = Enum.NormalId.Right, light = 0.2, bright = 1.1, rot = { -10, 10 }, sizeSeq = DIM_SIZE, trans = DIM_TR })
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
				fl.Rate = if on then 7 else 4
				fl.Color = if on then SOUL else SOUL_DIM
				fl.Size = if on then LIT_SIZE else DIM_SIZE
				fl.Transparency = if on then LIT_TR else DIM_TR
				fl.LightEmission = if on then 0.4 else 0.2
				stubs[i].Color = if on then STUB_LIT else STUB
			end
		end)

		-- THE SOULS: mint soul flames off both shoulders, with darker teal tongues behind them so they keep their
		-- shape (out and back from your head, low glow: no white); three soul wisps circling on trails (clear of your
		-- body); a dark teal shroud round your legs. No body tint: no outline, only a faint light.
		local soulFire = {}
		for _, side in { -1, 1 } do
			local sh = K.piece(a.body, Vector3.new(0.5, 0.3, 0.4))
			K.move(a, sh, function(f)
				return f.root * CFrame.new(side * 1.45, 1.35, 0.45)
			end)
			table.insert(soulFire, E(sh, { tex = T.flame, flip = 4, colors = SOUL, rate = 7, life = { 0.6, 0.85 }, speed = { 1.8, 3 }, size = 1.5, accel = Vector3.new(0, 4.5, 0), spread = 8, light = 0.4, bright = 0.85, rot = { -12, 12 }, sizeSeq = ns(0, 1, 0.4, 1.5, 1, 0.1), trans = ns(0, 0.15, 0.6, 0.3, 1, 1) }))
			local tongues = E(sh, { tex = T.flame, flip = 4, colors = K.seq(TEAL, TEAL_D), rate = 4, life = { 0.7, 0.9 }, speed = { 1.5, 2.5 }, size = 1.9, accel = Vector3.new(0, 4, 0), spread = 10, light = 0, bright = 1, rot = { -15, 15 }, sizeSeq = ns(0, 1.2, 0.4, 1.9, 1, 0.2), trans = ns(0, 0.35, 0.6, 0.5, 1, 1) })
			tongues.ZOffset = -0.5
			table.insert(soulFire, tongues)
		end
		for _, e in soulFire do
			K.addEmitter(a, e)
		end
		for i = 1, 3 do
			local orb = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
			local tr = H.trailed(orb, K.seq(MINT, TEAL, TEAL_D), 0.8, 0.28)
			tr.LightEmission = 0.4
			local wisp = E(orb, { tex = T.flame, flip = 4, colors = K.seq(MINT, TEAL), rate = 8, life = { 0.25, 0.35 }, speed = { 0.2, 0.5 }, size = 0.55, spread = 20, light = 0.4, bright = 1.1, lock = true })
			K.addEmitter(a, wisp)
			if i == 3 then
				H.detail(a, tr, wisp)
			end
			local off = (i - 1) / 3 * TAU
			K.move(a, orb, function(f)
				local th = -BLADE * f.t * 1.5 + off
				local r = 3.1 + 0.25 * math.cos(f.t * 1.1 + off)
				return CFrame.new(f.root.Position + Vector3.new(math.cos(th) * r, 0.4 + 1.6 * math.sin(f.t * 0.9 + off), math.sin(th) * r))
			end)
		end
		local shroud = E(K.bodyBox(a, Vector3.new(2.6, 2, 1.8), -1.7), { tex = FX.smoke, colors = K.seq(rgb(18, 58, 52), POOL), rate = 6, life = { 1.2, 1.8 }, speed = { 0.2, 0.6 }, size = 2, accel = Vector3.new(0, 0.5, 0), spin = 20, spread = 60, light = 0, bright = 1, trans = ns(0, 1, 0.3, 0.4, 1, 1) })
		K.addEmitter(a, shroud)
		H.detail(a, shroud)
		K.light(a, MINT, 0.2, 6)
		H.lightJob(a, 0.25)
		-- running: a ghostly trail at your feet and wisps kicked up
		K.feetTrail(a, K.seq(MINT, TEAL, rgb(12, 40, 22)))
		local kick = H.feetPiece(a, Vector3.new(1.4, 0.3, 1.4), 0.3)
		K.addEmitter(a, E(kick, { tex = T.wisp, colors = K.seq(MINT, TEAL), rate = 8, life = { 0.5, 0.8 }, speed = { 1, 2.5 }, size = 1, accel = Vector3.new(0, 3, 0), spread = 40, light = 0.4, bright = 1.2 }), true)

		-- THE WAVE (the server's reapWave near you): a mint shockwave rolls out past the hedges, souls burst out, the
		-- scythe twirls at once (unless it's mid-twirl already), every block's top is sliced with a slash, the candles
		-- flare and start again
		local burstAt = H.feetPiece(a, Vector3.new(2, 0.3, 2), 0.3)
		local burst = E(burstAt, { tex = T.flame, flip = 4, colors = SOUL, rate = 0, life = { 0.5, 0.8 }, speed = { 8, 12 }, size = 1.2, accel = Vector3.new(0, 4, 0), drag = 2, spread = 80, light = 0.4, bright = 1.2 })
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
					emit(h.trim, 4)
				end
			end
			local feet = self.rootPos - Vector3.new(0, 2.7, 0)
			K.pulse(feet, 2, HEDGE_R * 2 + 12, MINT, 0.7, 0)
			K.pulse(feet, 1, HEDGE_R * 2 + 4, TEAL, 0.55, 0.15)
			burst:Emit(16)
			emit(pipFire, 5)
			after:Emit(3)
			self.lightKick = 2
		end)

		-- the entrance (the hedges sprout, the scythe drops in spinning, then twirls): mint rings, a burst of souls, the
		-- dark mist rolling in
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 15, MINT, 0.8, 0)
			K.pulse(feet, 1, 10, TEAL, 0.55, 0.25)
			burst:Emit(12)
			emit(soulFire, 6)
			emit(mist, 3)
			pool:Emit(5)
			self.lightKick = 2
		end
		return a
	end
end
