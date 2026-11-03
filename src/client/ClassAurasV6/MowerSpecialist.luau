-- MOWER SPECIALIST (Epic). The card: a bright orange ride-on mower with black wheels, a puff of exhaust. (The card's
-- purple is the Epic rarity's colour, so it isn't used: the aura is the mower's orange, black rubber, steel, white-hot
-- sparks, grey exhaust and fresh green clippings.) Gimmick: Turbo Deck, ride-on mowers cut 25% wider, drive 15% faster
-- and burn 40% less fuel.
-- The aura, built round ForgeGUI pieces:
--   blade   the mower's blade under you: the ForgeGUI mower-blade emblem inside a steel saw ring, revving up as the
--           aura forms and spinning so fast it blurs (two faint copies trail it), a white-hot orange rim; sparks
--           spray off the rim, clippings are flung out, heat rises off it; the mower's four black wheels stand at
--           the deck's corners (big ones behind)
--   engine  the ForgeGUI orange engine pack on your back, buzzing; exhaust smoke puffs from its pipe and every 3 s it
--           backfires (a flash, a flame, a puff of smoke, the pack jolts); heat glowing round it
--   Turbo   run and it kicks in: the blade spins faster and its rim widens by a quarter (the wider cut), the sparks
--           and clippings double, the exhaust spits flame, speed lines stream past you, the wheels bounce, and you
--           leave a fresh-mown stripe behind you
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local E = H.E
	local ORANGE = rgb(242, 107, 29) -- the card's mower orange
	local HOT = rgb(255, 140, 40)
	local HOT_L = rgb(255, 220, 150)
	local STEEL = rgb(172, 180, 190)
	local CHROME = rgb(214, 220, 228)
	local RUBBER = rgb(30, 30, 34)
	local MOWN = rgb(200, 248, 140) -- a freshly mown stripe
	local TAU = math.pi * 2

	local ENGINE = 3.8 -- the engine pack's height (the exhaust pipe's tip about level with the top of your head)
	-- (GUESS, from the prop booth) the side of the prop its back plate and straps are on (+1 = +X): turned to face your
	-- back, so the engine and its pipe face away. Set -1 if the screenshots show the pack on back to front.
	local STRAPS = 1
	local TURN = CFrame.Angles(0, STRAPS * math.pi / 2, 0)
	local BLADE_D, SAW_D = 10.6, 12.4 -- the blade emblem's width, the saw ring's (its teeth show round the emblem)
	local RIM_R = SAW_D / 2 -- the rim, where the sparks fly off
	local WHEEL_R = 6.7 -- the wheels stand just outside it

	return function()
		local a = H.aura(H.RANK.Epic, HOT)
		local function emit(list: { ParticleEmitter }, n: number)
			for _, e in list do
				e:Emit(n)
			end
		end

		-- the blade's spin: it revs up as the aura forms, and the Turbo (running) spins it faster still
		local angle, spin, turbo = 0, 0, 0
		local lastT: number? = nil
		H.job(a, function(self, f)
			local dt = if lastT then math.clamp(f.t - lastT, 0, 0.1) else 0
			lastT = f.t
			turbo += ((1 - f.calm) - turbo) * math.min(1, dt * 4)
			spin = 1.5 + 12 * smooth((f.t - self.born) / 1.4) + 8 * turbo
			angle = (angle + dt * spin) % TAU
		end)

		-- THE BLADE: the steel saw ring at the bottom, a blurred copy of the emblem under the emblem itself and a faint
		-- one over it (each copy lags by a slice of the turn, so the faster it spins the longer the blur); all of it
		-- grows in as the aura forms
		local plates = {}
		local function bladePlate(d: number, tex: string, color: Color3, tr: number, lift: number, lag: number): { SurfaceGui }
			local p, imgs, guis = H.plate(a.model, d, tex, color, tr, false, 1.2)
			for _, img in imgs do
				table.insert(a.glowFades, { img = img, base = tr })
			end
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(0, lift, 0)) * CFrame.Angles(0, angle - lag * spin, 0)
			end)
			table.insert(plates, { part = p, d = d })
			return guis
		end
		bladePlate(SAW_D, T.saw, STEEL, 0.2, 0.09, 0)
		H.detail(a, table.unpack(bladePlate(BLADE_D, T.embMowerSpecialist, WHITE, 0.45, 0.115, 0.011)))
		bladePlate(BLADE_D, T.embMowerSpecialist, WHITE, 0.15, 0.13, 0)
		H.detail(a, table.unpack(bladePlate(BLADE_D, T.embMowerSpecialist, WHITE, 0.8, 0.145, 0.022)))
		-- the rim: white-hot orange round the saw's teeth (it widens by a quarter with the Turbo: the wider cut), a
		-- fainter line at the emblem's edge
		local rim = H.glowRing(a, RIM_R, HOT, 0.05, 0, 0.175, 1.4)
		local edge = H.glowRing(a, BLADE_D / 2 - 0.1, HOT_L, 0.45, 0, 0.165, 1.3)
		-- sparks spraying off the rim and clippings flung out (both fly off the edge of a flat cylinder as wide as the
		-- rim), as many again while you run; heat rising off the blade
		local rimBox = H.feetPiece(a, Vector3.new(SAW_D, 0.3, SAW_D), 0.35)
		local sparks = H.layer(a, "Loop_MowerSpecialist", "Sparks", rimBox)
		local clips = H.layer(a, "Loop_MowerSpecialist", "Clippings", rimBox)
		H.layer(a, "Loop_MowerSpecialist", "Sparks", rimBox, true)
		H.detail(a, table.unpack(H.layer(a, "Loop_MowerSpecialist", "Clippings", rimBox, true)))
		H.detail(a, H.updraft(a, RIM_R - 0.6, K.seq(HOT_L, HOT), 6, T.streak, 0.7))
		local lastG, lastW = -1, -1
		H.job(a, function(self, f)
			local g = math.max(0.02, ease((f.t - self.born) / 0.7))
			local w = 1 + 0.25 * turbo
			if math.abs(g - lastG) < 0.004 and math.abs(w - lastW) < 0.004 then
				return
			end
			lastG, lastW = g, w
			for _, pl in plates do
				pl.part.Size = Vector3.new(pl.d * g, 0.05, pl.d * g)
			end
			local dr = RIM_R * 2 / 0.92 * g * w
			rim.Size = Vector3.new(dr, 0.05, dr)
			local de = (BLADE_D - 0.2) / 0.92 * g
			edge.Size = Vector3.new(de, 0.05, de)
			rimBox.Size = Vector3.new(SAW_D * g * w, 0.3, SAW_D * g * w)
		end)
		-- the mower's four black wheels at the deck's corners (big ones behind, small ones in front: orange hubs,
		-- chrome caps); they drop in as the aura forms and bounce with the Turbo
		for _, wh in { { -1, -1, 0.62 }, { 1, -1, 0.62 }, { -1, 1, 0.85 }, { 1, 1, 0.85 } } do
			local side, fb, r = wh[1], wh[2], wh[3]
			local x, z = side * WHEEL_R * math.sin(math.rad(40)), fb * WHEEL_R * math.cos(math.rad(40))
			local wT, wCF = -1, CFrame.identity
			H.rig(a, function(f)
				if f.t ~= wT then
					local k = ease((f.t - a.born - 0.25) / 0.5)
					local bump = 0.07 * turbo * math.abs(math.sin(f.t * 17 + x + z))
					wT, wCF = f.t, CFrame.new(f.feet) * f.yaw * CFrame.new(x, r - 0.28 + bump + 3 * (1 - k), z)
				end
				return wCF
			end, {
				{ H.cyl(a.model, 0.62, r * 2, RUBBER, Enum.Material.SmoothPlastic), CFrame.identity },
				{ H.cyl(a.model, 0.08, r * 1.2, ORANGE, Enum.Material.SmoothPlastic, 0.1), CFrame.new(side * 0.33, 0, 0) },
				{ H.cyl(a.model, 0.1, r * 0.45, CHROME, Enum.Material.Metal, 0.3), CFrame.new(side * 0.4, 0, 0) },
			})
		end

		-- THE ENGINE PACK (ForgeGUI ms_engine) on your back: it swoops in from behind as the aura forms, buzzes while it
		-- runs and jolts on a backfire (worked out once a frame)
		local engine = H.prop(a.body, "ms_engine", ENGINE)
		local S = H.propSize("ms_engine", ENGINE)
		-- (GUESS) its exhaust pipe's tip: the top of the prop, a little toward the engine side
		local PIPE = Vector3.new(-STRAPS * 0.12 * S.X, 0.48 * S.Y, 0)
		local DEPTH = 0.55 + 0.25 * S.X -- (its back plate just behind your back, the straps round your shoulders)
		local kickAt = -10
		local eT, eCF = -1, CFrame.identity
		local function engineCF(f): CFrame
			if f.t ~= eT then
				local k = ease((f.t - a.born - 0.15) / 0.7)
				local kick = 0.22 * math.exp((kickAt - f.t) * 9)
				eT = f.t
				eCF = f.root
					* CFrame.new(0.03 * math.sin(f.t * 57), 0.5 + 0.05 * math.sin(f.t * 2.2) + 0.02 * math.sin(f.t * 43) + kick + 2.5 * (1 - k), DEPTH + 3 * (1 - k))
					* CFrame.Angles(math.rad(6) + kick, 0, 0)
					* TURN
			end
			return eCF
		end
		K.move(a, engine, engineCF)
		-- the exhaust: smoke puffing out of the pipe, the backfire's flame and flash, heat glowing round the pack
		local smoke = H.layer(a, "Loop_MowerSpecialist", "Smoke", engine, false, 1.3, PIPE)
		local backfire = H.layer(a, "Loop_MowerSpecialist", "Backfire", engine, false, 1.3, PIPE)
		H.layer(a, "Loop_MowerSpecialist", "Heat", engine)
		local flash = E(H.att(engine, PIPE + Vector3.new(0, 0.35, 0)), { tex = T.flash, colors = K.seq(WHITE, HOT_L, HOT), rate = 0, life = { 0.1, 0.14 }, speed = { 0, 0 }, size = 2.8, spread = 0, light = 1, bright = 2.6, sizeSeq = ns(0, 1.6, 0.3, 2.8, 1, 0.8) })
		-- a backfire every 3 s
		H.every(a, 3, function(self, f)
			if f.t - self.born < 1 then
				return
			end
			kickAt = f.t
			emit(backfire, 7)
			emit(smoke, 3)
			flash:Emit(1)
			self.lightKick = 1.8
		end)

		-- THE TURBO (running): flame spitting from the exhaust, speed lines streaming back past you, a fresh-mown
		-- stripe left on the lawn behind you
		local stripeAt = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, stripeAt, function(f)
			return CFrame.new(f.feet) * f.yaw
		end)
		local stripe = K.trail(stripeAt, Vector3.new(-2.4, 0.05, 0), Vector3.new(2.4, 0.05, 0), K.seq(MOWN, rgb(150, 225, 95)), 0.9, 0.1)
		stripe.FaceCamera = false -- (flat on the lawn)
		stripe.Transparency = ns(0, 0.3, 0.6, 0.5, 1, 1)
		stripe.WidthScale = ns(0, 1, 1, 0.9)
		K.bright(stripe, 1.1)
		stripe.Enabled = false
		local lineBox = K.piece(a.body, Vector3.new(3.6, 4.4, 0.6))
		K.move(a, lineBox, function(f)
			return CFrame.new(f.root.Position) * f.yaw
		end)
		local lines = E(lineBox, { tex = T.streak, colors = K.seq(WHITE, HOT_L), rate = 22, life = { 0.16, 0.26 }, speed = { 10, 15 }, size = 1.4, spread = 3, dir = Enum.NormalId.Back, light = 1, bright = 1.8, orient = Enum.ParticleOrientation.VelocityParallel, trans = ns(0, 0.6, 0.3, 0.25, 1, 1) })
		K.addEmitter(a, lines, true)
		H.detail(a, lines)
		local nextJet = 0
		H.job(a, function(self, f)
			local on = turbo > 0.4
			if on ~= stripe.Enabled then
				stripe.Enabled = on
			end
			if on and f.t >= nextJet then
				nextJet = f.t + 0.12
				emit(backfire, 1)
			end
		end)

		-- a hot glow round the body, a hot trail at your feet, an orange outline and light
		H.shell(a, K.seq(HOT_L, HOT), 6, 0.95)
		K.feetTrail(a, K.seq(HOT_L, HOT, rgb(160, 60, 20)))
		local hl = K.outline(a, HOT, 0.4)
		if hl then
			hl.FillTransparency = 0.95
		end
		K.light(a, HOT, 1, 13)
		H.lightJob(a, 0.35)

		-- the entrance (the blade grows in and revs up, the wheels drop, the pack swoops onto your back): hot rings, a
		-- shower of sparks and clippings, the engine coughing into life with a backfire, a rev
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 16, HOT, 0.6, 0.05)
			K.pulse(feet, 1, 10, HOT_L, 0.45, 0.25)
			emit(sparks, 14)
			emit(clips, 12)
			emit(backfire, 8)
			emit(smoke, 4)
			flash:Emit(1)
			kickAt = os.clock()
			self.lightKick = 2.5
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
