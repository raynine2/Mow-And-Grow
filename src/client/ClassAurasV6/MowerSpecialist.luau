-- MOWER SPECIALIST (Epic). The card: a bright orange ride-on mower with black wheels, a puff of exhaust. (The card's
-- purple is the Epic rarity's colour, so it isn't used: the aura is the mower's orange, steel, white-hot sparks,
-- light-grey exhaust and fresh green clippings.) Gimmick: Turbo Deck, ride-on mowers cut 25% wider, drive 15% faster
-- and burn 40% less fuel.
-- The aura, built round ForgeGUI pieces:
--   deck    the ForgeGUI mower-deck emblem (orange deck, bright steel blade) under you, revving up as the aura forms
--           and spinning so fast it blurs (two faint copies trail it); white-hot sparks fly off its rim along the
--           spin, clippings are flung out, heat rises off it; three crisp rings (hot orange, deck orange, steel)
--   mower   the card's subject: the ForgeGUI orange ride-on mower doing turbo laps round the deck, leaning into the
--           turn, mowing a fresh light-green stripe ring behind it, exhaust puffs out the back and clippings spitting
--           out its side
--   engine  the ForgeGUI orange engine pack on your back, buzzing, its pipe over your head: light-grey cartoon puffs,
--           and every 3 s a backfire (an orange flame plume over your shoulder, seen from the front too, a flash, a
--           pop, the pack jolts; the mower backfires with it). Your own pack goes half see-through with the camera
--           behind you.
--   Turbo   run and it kicks in: the mower laps faster and its stripe gets a quarter wider (the wider cut), the deck
--           spins faster, extra sparks, a fountain of clippings up to twice your height behind you, flame spitting
--           from the pipe, speed lines streaming past you
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local ORANGE = rgb(242, 107, 29) -- the card's mower orange
	local HOT = rgb(255, 140, 40)
	local HOT_L = rgb(255, 220, 150)
	local STEEL = rgb(200, 210, 222)
	local MOWN = rgb(205, 250, 145) -- a freshly mown stripe
	local MOWN_D = rgb(150, 225, 95)
	local PUFF = rgb(240, 240, 244) -- light-grey cartoon exhaust
	local PUFF_D = rgb(185, 186, 196)
	local LEAF = K.seq(rgb(170, 240, 105), rgb(70, 150, 50))
	local TAU = math.pi * 2

	local DECK_D = 11 -- the deck emblem's width
	local RIM_R = DECK_D / 2 - 0.15 -- where the sparks fly off
	local LAP_R = 6.5 -- the mower's lap, just outside the deck
	local MOWER = 2.5 -- the mower's length
	local STRIPE = 1.7 -- the mown stripe's width (a quarter wider in Turbo)
	local LAP_IDLE, LAP_RUN = TAU / 2.6, TAU / 1.5 -- the mower's laps (rad/s)
	local ENGINE = 4.6 -- the engine pack's height (1.2x: its pipe over your head)
	-- (GUESS, from the v6a back shot: the pack sat sideways) the prop's straps are on its +Z side and the engine faces
	-- -Z, so it's turned round to put the straps on your back. Turn it by another half turn if it's on back to front.
	local TURN = CFrame.Angles(0, math.pi, 0)

	return function()
		local a = H.aura(H.RANK.Epic, HOT)
		local function emit(list: { ParticleEmitter }, n: number)
			for _, e in list do
				e:Emit(n)
			end
		end

		-- the deck's spin (it revs up as the aura forms; Turbo spins it faster still) and the mower's lap
		local angle, spin, turbo, lap = 0, 0, 0, 0
		local lastT: number? = nil
		H.job(a, function(self, f)
			local dt = if lastT then math.clamp(f.t - lastT, 0, 0.1) else 0
			lastT = f.t
			turbo += ((1 - f.calm) - turbo) * math.min(1, dt * 4)
			spin = 1.5 + 12 * smooth((f.t - self.born) / 1.4) + 8 * turbo
			angle = (angle + dt * spin) % TAU
			lap = (lap + dt * (LAP_IDLE + (LAP_RUN - LAP_IDLE) * turbo)) % TAU
		end)

		-- THE DECK: the emblem, a blurred copy under it and a fainter one (each lags by a slice of the turn, so the faster
		-- it spins the longer the blur); three crisp rings: hot orange on the painted ring, deck orange at the rim, steel
		-- out past the mower's lap. All of it grows in as the aura forms.
		local grows = {}
		local function deckPlate(tr: number, lift: number, lag: number): { SurfaceGui }
			local p, imgs, guis = H.plate(a.model, DECK_D, T.embMowerSpecialist, WHITE, tr, false, 1.1)
			for _, img in imgs do
				table.insert(a.glowFades, { img = img, base = tr })
			end
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(0, lift, 0)) * CFrame.Angles(0, angle - lag * spin, 0)
			end)
			table.insert(grows, { part = p, d = DECK_D })
			return guis
		end
		H.detail(a, table.unpack(deckPlate(0.62, 0.11, 0.024)))
		H.detail(a, table.unpack(deckPlate(0.45, 0.115, 0.012)))
		deckPlate(0.15, 0.12, 0)
		for _, rg in { { 2.6, HOT, 0.45, 0.4 }, { RIM_R + 0.1, ORANGE, 0.35, -0.25 }, { LAP_R + 1.15, STEEL, 0.5, 0.15 } } do
			local p = H.glowRing(a, rg[1], rg[2], rg[3], rg[4], 0.14, 1.2)
			table.insert(grows, { part = p, d = rg[1] * 2 / 0.92 })
		end
		local lastG = -1
		H.job(a, function(self, f)
			local g = math.max(0.02, ease((f.t - self.born) / 0.7))
			if math.abs(g - lastG) < 0.004 then
				return
			end
			lastG = g
			for _, gp in grows do
				gp.part.Size = Vector3.new(gp.d * g, 0.05, gp.d * g)
			end
		end)
		-- white-hot sparks flying off the rim along the spin (four nozzles turning with the blade, each aimed along
		-- the rim and a little up: ~40/s, short and thin)
		local hub = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, hub, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, angle, 0)
		end)
		local sparks = {}
		for i = 1, 4 do
			local th = (i - 1) / 4 * TAU
			local radial = Vector3.new(math.cos(th), 0, math.sin(th))
			local along = (Vector3.new(math.sin(th), 0, -math.cos(th)) + Vector3.new(0, 0.3, 0)).Unit
			local at = Instance.new("Attachment")
			at.CFrame = CFrame.fromMatrix(radial * RIM_R, radial, along)
			at.Parent = hub
			local e = E(at, { tex = T.streak, colors = K.seq(WHITE, HOT_L, HOT), rate = 10, life = { 0.15, 0.25 }, speed = { 16, 22 }, size = 0.45, accel = Vector3.new(0, -20, 0), spread = 12, light = 1, bright = 1.5, orient = Enum.ParticleOrientation.VelocityParallel, sizeSeq = ns(0, 0.45, 1, 0.05), trans = ns(0, 0, 0.7, 0.2, 1, 1) })
			K.addEmitter(a, e)
			table.insert(sparks, e)
		end
		-- clippings flung off the rim (and sparks out of it while you run), heat rising off the deck
		local rimBox = H.feetPiece(a, Vector3.new(DECK_D, 0.3, DECK_D), 0.35)
		local clips = H.layer(a, "Loop_MowerSpecialist", "Clippings", rimBox)
		H.detail(a, table.unpack(H.layer(a, "Loop_MowerSpecialist", "Sparks", rimBox, true)))
		H.detail(a, H.updraft(a, RIM_R - 0.4, K.seq(HOT_L, HOT), 5, T.streak, 0.6))

		-- THE MOWER (ForgeGUI ms_mower: front +X, up +Y): turbo laps round the deck the way the blade spins, leaning into
		-- the turn and bouncing (it drives in on a spiral as the aura forms); without the prop, an orange block
		local mower = H.prop(a.model, "ms_mower", MOWER)
		local M = H.propSize("ms_mower", MOWER)
		if not mower:IsA("MeshPart") then
			local b = mower :: Part
			b.Size = Vector3.new(MOWER, MOWER * 0.6, MOWER * 0.65)
			b.Material = Enum.Material.SmoothPlastic
			b.Color = ORANGE
			b.Transparency = 0
			M = b.Size
		end
		K.move(a, mower, function(f)
			local k = ease((f.t - a.born - 0.2) / 0.9)
			local r = LAP_R + 8 * (1 - k)
			local th = lap - 2 * (1 - k)
			local pos = f.feet + Vector3.new(math.cos(th) * r, M.Y / 2 - 0.1 + 0.06 * math.abs(math.sin(f.t * 19)), -math.sin(th) * r)
			local ahead = Vector3.new(-math.sin(th), 0, -math.cos(th)) -- (its +X along the lap; its +Z then points out)
			return CFrame.fromMatrix(pos, ahead, Vector3.yAxis) * CFrame.Angles(-math.rad(9), 0, math.rad(2) * math.sin(f.t * 23))
		end)
		-- the fresh light-green stripe it mows (flat on the lawn, ~a lap long)
		local stripe = K.trail(mower, Vector3.new(-0.42 * M.X, -M.Y / 2 + 0.12, -STRIPE / 2), Vector3.new(-0.42 * M.X, -M.Y / 2 + 0.12, STRIPE / 2), K.seq(MOWN, MOWN_D), 2.2, 0.15)
		stripe.FaceCamera = false
		stripe.Transparency = ns(0, 0.2, 0.7, 0.45, 1, 1)
		stripe.WidthScale = ns(0, 1, 1, 1)
		K.bright(stripe, 1.1)
		local s0, s1 = stripe.Attachment0, stripe.Attachment1
		-- (GUESS) its exhaust: the back of the prop, high up; clippings spit out of its outer side (+Z)
		local mPuffs = E(H.att(mower, Vector3.new(-0.45 * M.X, 0.3 * M.Y, 0)), { tex = FX.poof, flip = 4, colors = K.seq(PUFF, PUFF_D), rate = 5, life = { 0.7, 1 }, speed = { 1, 2 }, size = 1, accel = Vector3.new(0, 1.5, 0), spread = 25, light = 0, bright = 1, sizeSeq = ns(0, 0.5, 1, 1.4), trans = ns(0, 0.1, 0.7, 0.3, 1, 1) })
		local mClips = E(H.att(mower, Vector3.new(0, -0.2 * M.Y, 0.5 * M.Z)), { tex = BFX.strand, colors = LEAF, rate = 14, life = { 0.5, 0.8 }, speed = { 6, 10 }, size = 0.42, accel = Vector3.new(0, -25, 0), spin = 400, spread = 25, dir = Enum.NormalId.Back, light = 0, bright = 1.1 })
		local mFire = E(H.att(mower, Vector3.new(-0.5 * M.X, 0.3 * M.Y, 0)), { tex = T.flame, flip = 4, colors = K.seq(HOT_L, HOT, rgb(170, 50, 20)), rate = 0, life = { 0.2, 0.3 }, speed = { 3, 5 }, size = 0.9, spread = 15, dir = Enum.NormalId.Top, light = 0.8, bright = 1.5 })
		K.addEmitter(a, mPuffs)
		K.addEmitter(a, mClips)
		H.detail(a, mPuffs)
		-- Turbo: the stripe a quarter wider (the wider cut)
		local lastW = -1
		H.job(a, function(self, f)
			local w = STRIPE * (1 + 0.25 * turbo) / 2
			if math.abs(w - lastW) > 0.02 then
				lastW = w
				s0.Position = Vector3.new(s0.Position.X, s0.Position.Y, -w)
				s1.Position = Vector3.new(s1.Position.X, s1.Position.Y, w)
			end
		end)

		-- THE ENGINE PACK (ForgeGUI ms_engine) on your back: it swoops in from behind as the aura forms, buzzes while it
		-- runs and jolts on a backfire (worked out once a frame)
		local engine = H.prop(a.body, "ms_engine", ENGINE)
		local S = H.propSize("ms_engine", ENGINE)
		-- (GUESS) the exhaust pipe's tip: the top of the prop, over the engine end
		local PIPE = Vector3.new(0, 0.5 * S.Y, -0.3 * S.Z)
		local DEPTH = 0.6 + 0.15 * S.Z -- (its back plate just behind your back, the straps round your shoulders)
		local kickAt = -10
		local eT, eCF = -1, CFrame.identity
		local function engineCF(f): CFrame
			if f.t ~= eT then
				local k = ease((f.t - a.born - 0.15) / 0.7)
				local kick = 0.22 * math.exp((kickAt - f.t) * 9)
				eT = f.t
				eCF = f.root
					* CFrame.new(0.03 * math.sin(f.t * 57), 0.85 + 0.05 * math.sin(f.t * 2.2) + 0.02 * math.sin(f.t * 43) + kick + 2.5 * (1 - k), DEPTH + 3 * (1 - k))
					* CFrame.Angles(math.rad(6) + kick, 0, 0)
					* TURN
			end
			return eCF
		end
		K.move(a, engine, engineCF)
		-- your own pack goes half see-through while the camera is behind you
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
				engine.LocalTransparencyModifier = m
			end
		end)
		-- the exhaust: light-grey cartoon puffs from the pipe; the backfire's flame plume (big enough to show over your
		-- shoulder from the front), flash and pop ring; heat glowing round the pack
		local pipeAt = H.att(engine, PIPE)
		local puffs = E(pipeAt, { tex = FX.poof, flip = 4, colors = K.seq(PUFF, PUFF_D), rate = 3.5, life = { 1, 1.4 }, speed = { 2, 3.5 }, size = 1.5, accel = Vector3.new(0, 1, 0), drag = 0.5, spread = 12, light = 0, bright = 1, sizeSeq = ns(0, 0.7, 0.5, 1.5, 1, 1.9), trans = ns(0, 0.05, 0.6, 0.2, 1, 1) })
		K.addEmitter(a, puffs)
		local backfire = H.layer(a, "Loop_MowerSpecialist", "Backfire", engine, false, 1.7, PIPE)
		H.layer(a, "Loop_MowerSpecialist", "Heat", engine)
		local flash = E(H.att(engine, PIPE + Vector3.new(0, 0.5, 0)), { tex = T.flash, colors = K.seq(HOT_L, HOT), rate = 0, life = { 0.1, 0.14 }, speed = { 0, 0 }, size = 2, spread = 0, light = 0.8, bright = 1.6, sizeSeq = ns(0, 1.2, 0.3, 2.2, 1, 0.6) })
		local popRing = E(pipeAt, { tex = FX.ring, colors = K.seq(HOT_L, ORANGE), rate = 0, life = { 0.25, 0.3 }, speed = { 0, 0 }, size = 2.5, spread = 0, light = 0.7, bright = 1.4, sizeSeq = ns(0, 0.4, 1, 3), trans = ns(0, 0.1, 1, 1) })
		-- a backfire every 3 s (the mower's with it)
		H.every(a, 3, function(self, f)
			if f.t - self.born < 1 then
				return
			end
			kickAt = f.t
			emit(backfire, 8)
			puffs:Emit(4)
			flash:Emit(1)
			popRing:Emit(1)
			mFire:Emit(6)
			mPuffs:Emit(3)
			self.lightKick = 1.6
		end)

		-- THE TURBO (running): a fountain of clippings up to twice your height behind you, flame spitting from the pipe,
		-- speed lines streaming back past you
		local spout = K.piece(a.model, Vector3.new(1.6, 0.3, 1.6))
		K.move(a, spout, function(f)
			return CFrame.new(f.feet) * f.yaw * CFrame.new(0, 0.3, 1.2)
		end)
		local fountain = E(spout, { tex = BFX.strand, colors = LEAF, rate = 28, life = { 1.2, 1.5 }, speed = { 19, 24 }, size = 0.5, accel = Vector3.new(0, -24, 0), spin = 400, spread = 18, light = 0, bright = 1.1 })
		K.addEmitter(a, fountain, true)
		H.detail(a, fountain)
		local lineBox = K.piece(a.body, Vector3.new(3.6, 4.4, 0.6))
		K.move(a, lineBox, function(f)
			return CFrame.new(f.root.Position) * f.yaw
		end)
		local lines = E(lineBox, { tex = T.streak, colors = K.seq(WHITE, HOT_L), rate = 22, life = { 0.16, 0.26 }, speed = { 10, 15 }, size = 1.4, spread = 3, dir = Enum.NormalId.Back, light = 0.9, bright = 1.5, orient = Enum.ParticleOrientation.VelocityParallel, trans = ns(0, 0.6, 0.3, 0.25, 1, 1) })
		K.addEmitter(a, lines, true)
		H.detail(a, lines)
		local nextJet = 0
		H.job(a, function(self, f)
			if turbo > 0.4 and f.t >= nextJet then
				nextJet = f.t + 0.25
				emit(backfire, 1)
			end
		end)

		-- a soft orange glow round the body, a hot trail at your feet, an orange outline and light
		H.shell(a, K.seq(HOT_L, ORANGE), 5, 0.85)
		K.feetTrail(a, K.seq(HOT_L, HOT, rgb(160, 60, 20)))
		local hl = K.outline(a, HOT, 0.45)
		if hl then
			hl.FillTransparency = 1
		end
		K.light(a, HOT, 0.7, 12)
		H.lightJob(a, 0.35)

		-- the entrance (the deck grows in and revs up, the mower drives in on a spiral, the pack swoops onto your back):
		-- hot rings, a shower of sparks and clippings, the engine coughing into life with a backfire, a rev
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 16, ORANGE, 0.6, 0.05)
			K.pulse(feet, 1, 10, HOT_L, 0.45, 0.25)
			emit(sparks, 6)
			emit(clips, 12)
			emit(backfire, 8)
			puffs:Emit(4)
			flash:Emit(1)
			popRing:Emit(1)
			kickAt = os.clock()
			self.lightKick = 2.2
			pcall(function()
				local cam = workspace.CurrentCamera
				if cam and (cam.CFrame.Position - feet).Magnitude < 40 then
					K.Sound.play("whackerRev", 0.05, 0.35)
				end
			end)
		end
		return a
	end
end
