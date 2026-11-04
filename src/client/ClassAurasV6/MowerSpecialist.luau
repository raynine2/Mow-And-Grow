-- MOWER SPECIALIST (Epic). The card: a bright orange ride-on mower with black wheels, a puff of exhaust. (The card's
-- purple is the Epic rarity's colour, so it isn't used: the aura is the mower's orange, steel, chrome, hot sparks,
-- light-grey exhaust and fresh green clippings.) Gimmick: Turbo Deck, ride-on mowers cut 25% wider, drive 15% faster
-- and burn 40% less fuel.
-- The aura, built round ForgeGUI pieces (round 3: no white bloom, no body outline):
--   deck    the ForgeGUI mower-deck emblem (orange deck, steel) under you with a real 3D two-arm steel mower blade
--           spinning on it so fast its tips smear into motion-blur arcs; hot sparks fly off the rim along the spin,
--           heat rises off it; three crisp rings (hot orange, deck orange, steel at the blade's tips)
--   mower   the card's subject: the ForgeGUI orange ride-on mower, big (about two-thirds your height), doing turbo
--           laps round the deck, leaning into the turn, carving a striped mown trail (light and dark green bands that
--           fade) with clippings spraying out behind and beside it and exhaust puffing out the back
--   engine  the ForgeGUI orange engine pack on your back (clear of your torso) with a tall chrome exhaust stack rising
--           over your right shoulder: a plume of light-grey cartoon puffs climbs off it, and every 3 s it backfires
--           (an orange flame jet, a flash, a pop ring, the pack jolts; the mower backfires with it)
--   Turbo   run and it kicks in: the mower laps faster and its stripe gets a quarter wider (the wider cut), the blade
--           spins faster, more sparks, a fountain of clippings up to twice your height behind you, flame spitting
--           from the stack, speed lines streaming past you
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local ORANGE = rgb(242, 107, 29) -- the card's mower orange
	local HOT = rgb(255, 140, 40)
	local HOT_L = rgb(255, 205, 120) -- the palest the fire gets (never white)
	local STEEL = rgb(178, 188, 200)
	local CHROME = rgb(214, 220, 228)
	local IRON = rgb(52, 55, 62)
	local MOWN = rgb(200, 245, 140) -- the mown stripes: light and dark bands
	local MOWN_D = rgb(105, 185, 70)
	local PUFF = rgb(226, 227, 233) -- light-grey cartoon exhaust
	local PUFF_D = rgb(165, 168, 178)
	local LEAF = K.seq(rgb(170, 240, 105), rgb(70, 150, 50))
	local FIRE = K.seq(HOT_L, HOT, rgb(200, 60, 20))
	local TAU = math.pi * 2

	local DECK_D = 11 -- the deck emblem's width
	local RIM_R = DECK_D / 2 - 0.15 -- where the sparks fly off
	local BLADE_L = 8.2 -- the 3D blade's length, tip to tip
	local LAP_R = 7.3 -- the mower's lap (its inner side just clears the deck)
	local MOWER = 5 -- the mower's length (about two-thirds your height tall)
	local STRIPE = 1.9 -- the mown stripe's width (a quarter wider in Turbo)
	local LAP_IDLE, LAP_RUN = TAU / 3.2, TAU / 2 -- the mower's laps (rad/s)
	local ENGINE = 4.2 -- the engine pack's height
	-- (GUESS, from the v6a back shot) the prop's straps are on its +Z side and the engine faces -Z, so it's turned
	-- round to put the straps on your back (v6b looked right)
	local TURN = CFrame.Angles(0, math.pi, 0)

	return function()
		local a = H.aura(H.RANK.Epic, HOT)
		local function emit(list: { ParticleEmitter }, n: number)
			for _, e in list do
				e:Emit(n)
			end
		end

		-- the blade's spin (it revs up as the aura forms; Turbo spins it faster still) and the mower's lap
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

		-- THE DECK: the emblem turning with the blade (a faint copy lagging behind it blurs it), three crisp rings; all
		-- of it grows in as the aura forms
		local grows = {}
		local function deckPlate(tr: number, lift: number, lag: number): { SurfaceGui }
			local p, imgs, guis = H.plate(a.model, DECK_D, T.embMowerSpecialist, WHITE, tr, false, 1.05)
			for _, img in imgs do
				table.insert(a.glowFades, { img = img, base = tr })
			end
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(0, lift, 0)) * CFrame.Angles(0, angle - lag * spin, 0)
			end)
			table.insert(grows, { part = p, d = DECK_D })
			return guis
		end
		H.detail(a, table.unpack(deckPlate(0.55, 0.11, 0.015)))
		deckPlate(0.15, 0.12, 0)
		for _, rg in { { 2.6, HOT, 0.5, 0.4 }, { BLADE_L / 2 + 0.2, STEEL, 0.5, -0.3 }, { RIM_R + 0.1, ORANGE, 0.4, 0.15 } } do
			local p = H.glowRing(a, rg[1], rg[2], rg[3], rg[4], 0.14, 1.05)
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
		-- the 3D mower blade: a two-arm steel bar with a chrome cutting edge, lifted wing tips, an iron hub and a chrome
		-- bolt, spinning with the deck; each tip smears a flat steel motion-blur arc behind it
		local bar = H.solid(a.model, Vector3.new(BLADE_L, 0.14, 0.95), STEEL, Enum.Material.Metal, 0.2)
		local pieces = {
			{ bar, CFrame.identity },
			{ H.solid(a.model, Vector3.new(BLADE_L, 0.16, 0.14), CHROME, Enum.Material.Metal, 0.4), CFrame.new(0, 0.01, -0.45) },
			{ H.cyl(a.model, 0.3, 1.6, IRON, Enum.Material.Metal), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2) },
			{ H.cyl(a.model, 0.42, 0.6, CHROME, Enum.Material.Metal, 0.4), CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, math.pi / 2) },
		}
		for _, side in { -1, 1 } do
			-- (the wing tips lift toward the trailing side: the "sail" that throws the clippings up)
			local wing = H.solid(a.model, Vector3.new(1.2, 0.12, 0.5), STEEL, Enum.Material.Metal, 0.2)
			table.insert(pieces, { wing, CFrame.new(side * (BLADE_L / 2 - 0.6), 0.12, 0.35) * CFrame.Angles(math.rad(-30), 0, 0) })
		end
		local bT, bCF = -1, CFrame.identity
		H.rig(a, function(f)
			if f.t ~= bT then
				local g = math.max(0.02, ease((f.t - a.born - 0.1) / 0.6))
				bT, bCF = f.t, CFrame.new(f.feet + Vector3.new(0, 0.22 - 2 * (1 - g), 0)) * CFrame.Angles(0, angle, 0)
			end
			return bCF
		end, pieces)
		for _, side in { -1, 1 } do
			local blur = K.trail(bar, Vector3.new(side * (BLADE_L / 2 - 1.8), 0.08, 0), Vector3.new(side * BLADE_L / 2, 0.08, 0), K.seq(CHROME, STEEL), 0.09, 0.15)
			blur.FaceCamera = false -- (flat on the deck)
			blur.Transparency = ns(0, 0.45, 1, 1)
			blur.WidthScale = ns(0, 1, 1, 1)
			K.bright(blur, 1.1)
		end
		-- hot sparks flying off the rim along the spin (four nozzles turning with the blade, each aimed along the rim and
		-- a little up: ~40/s, as many again while you run)
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
			for _, run in { false, true } do
				local e = E(at, { tex = T.streak, colors = K.seq(HOT_L, HOT, ORANGE), rate = if run then 8 else 10, life = { 0.25, 0.35 }, speed = { 14, 18 }, size = 0.45, accel = Vector3.new(0, -25, 0), spread = 12, light = 0.6, bright = 1.3, orient = Enum.ParticleOrientation.VelocityParallel, sizeSeq = ns(0, 0.45, 1, 0.05), trans = ns(0, 0, 0.7, 0.2, 1, 1) })
				K.addEmitter(a, e, run)
				if not run then
					table.insert(sparks, e)
				end
			end
		end
		local heat = H.updraft(a, RIM_R - 0.4, K.seq(HOT_L, HOT), 4, T.streak, 0.6)
		heat.LightEmission = 0.4
		K.bright(heat, 1.3)
		H.detail(a, heat)

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
			local pos = f.feet + Vector3.new(math.cos(th) * r, M.Y / 2 - 0.1 + 0.08 * math.abs(math.sin(f.t * 17)), -math.sin(th) * r)
			local ahead = Vector3.new(-math.sin(th), 0, -math.cos(th)) -- (its +X along the lap; its +Z then points out)
			return CFrame.fromMatrix(pos, ahead, Vector3.yAxis) * CFrame.Angles(-math.rad(7), 0, math.rad(1.5) * math.sin(f.t * 23))
		end)
		-- the striped mown trail it carves (flat on the lawn, half its width, light and dark bands, fading)
		local bands = {}
		for i = 0, 5 do
			local col = if i % 2 == 0 then MOWN else MOWN_D
			table.insert(bands, ColorSequenceKeypoint.new(i / 6 + (if i == 0 then 0 else 0.002), col))
			table.insert(bands, ColorSequenceKeypoint.new((i + 1) / 6 - (if i == 5 then 0 else 0.002), col))
		end
		local stripe = K.trail(mower, Vector3.new(-0.42 * M.X, -M.Y / 2 + 0.12, -STRIPE / 2), Vector3.new(-0.42 * M.X, -M.Y / 2 + 0.12, STRIPE / 2), ColorSequence.new(bands), 1.3, 0.1)
		stripe.FaceCamera = false
		stripe.Transparency = ns(0, 0.5, 0.6, 0.65, 1, 1)
		stripe.WidthScale = ns(0, 1, 1, 0.8)
		K.bright(stripe, 1)
		local s0, s1 = stripe.Attachment0, stripe.Attachment1
		-- clippings spraying out behind it (-X) and out of its outer side (+Z); (GUESS) its exhaust at the back, high up
		local mSpray = E(H.att(mower, Vector3.new(-0.5 * M.X, -0.25 * M.Y, 0)), { tex = BFX.strand, colors = LEAF, rate = 16, life = { 0.4, 0.6 }, speed = { 5, 8 }, size = 0.45, accel = Vector3.new(0, -22, 0), spin = 400, spread = 30, dir = Enum.NormalId.Left, light = 0, bright = 1.1 })
		local mClips = E(H.att(mower, Vector3.new(0, -0.25 * M.Y, 0.5 * M.Z)), { tex = BFX.strand, colors = LEAF, rate = 8, life = { 0.4, 0.6 }, speed = { 4, 7 }, size = 0.42, accel = Vector3.new(0, -22, 0), spin = 400, spread = 25, dir = Enum.NormalId.Back, light = 0, bright = 1.1 })
		local mPuffs = E(H.att(mower, Vector3.new(-0.45 * M.X, 0.32 * M.Y, 0.2 * M.Z)), { tex = FX.poof, flip = 4, colors = K.seq(PUFF, PUFF_D), rate = 4, life = { 0.8, 1.1 }, speed = { 1.5, 2.5 }, size = 1.4, accel = Vector3.new(0, 1.5, 0), spread = 25, light = 0, bright = 1, sizeSeq = ns(0, 0.6, 1, 1.8), trans = ns(0, 0.15, 0.7, 0.35, 1, 1) })
		-- its backfire: the VFX Forge Backfire layer at its exhaust, recoloured orange and toned down (no white core)
		local mFire = H.layer(a, "Loop_MowerSpecialist", "Backfire", mower, false, 1.2, Vector3.new(-0.5 * M.X, 0.32 * M.Y, 0.2 * M.Z))
		for _, e in mFire do
			e.Color = FIRE
			e.LightEmission = 0.4
			K.bright(e, 1.3)
		end
		K.addEmitter(a, mSpray)
		K.addEmitter(a, mClips)
		K.addEmitter(a, mPuffs)
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

		-- THE ENGINE PACK (ForgeGUI ms_engine) on your back, half a stud further back than before (clear of your torso):
		-- it swoops in from behind as the aura forms, buzzes while it runs and jolts on a backfire. The pack's frame
		-- (before it's turned round) also carries the chrome stack. Worked out once a frame.
		local engine = H.prop(a.body, "ms_engine", ENGINE)
		local S = H.propSize("ms_engine", ENGINE)
		local DEPTH = 1.1 + 0.15 * S.Z -- (its back plate behind your back, the straps round your shoulders)
		local kickAt = -10
		local pT, pCF = -1, CFrame.identity
		local function packCF(f): CFrame
			if f.t ~= pT then
				local k = ease((f.t - a.born - 0.15) / 0.7)
				local kick = 0.22 * math.exp((kickAt - f.t) * 9)
				pT = f.t
				pCF = f.root
					* CFrame.new(0.03 * math.sin(f.t * 57), 0.6 + 0.05 * math.sin(f.t * 2.2) + 0.02 * math.sin(f.t * 43) + kick + 2.5 * (1 - k), DEPTH + 3 * (1 - k))
					* CFrame.Angles(math.rad(6) + kick, 0, 0)
			end
			return pCF
		end
		K.move(a, engine, function(f)
			return packCF(f) * TURN
		end)
		-- the chrome exhaust stack: a bracket on the pack's top right corner, a tall chrome pipe with a dark heat shield
		-- rising past your right shoulder, a bent tip pointing up and back, a dark cap (offsets in the pack's frame:
		-- +X your right, +Y up, +Z back)
		local STACK = Vector3.new(1, 1.5, 0.3) -- (the stack's foot)
		local RISE = 2.8 -- (how high the straight pipe goes)
		local bend = Vector3.new(0.35, 0.6, 0.72).Unit
		local top = STACK + Vector3.new(0, RISE, 0)
		local function along(from: Vector3, dir: Vector3, len: number): CFrame
			local mid = from + dir * (len / 2)
			return CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's X along `dir`)
		end
		local function upright(from: Vector3, len: number): CFrame
			return CFrame.new(from + Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2) -- (X straight up)
		end
		local tip = H.cyl(a.body, 1.1, 0.42, CHROME, Enum.Material.Metal, 0.35)
		local stackPieces = {
			{ H.solid(a.body, Vector3.new(0.6, 0.3, 0.6), IRON, Enum.Material.Metal), CFrame.new(STACK) },
			{ H.cyl(a.body, RISE + 0.1, 0.42, CHROME, Enum.Material.Metal, 0.35), upright(STACK, RISE + 0.1) },
			{ H.cyl(a.body, 1.3, 0.54, IRON, Enum.Material.DiamondPlate), upright(STACK + Vector3.new(0, 0.6, 0), 1.3) },
			{ tip, along(top - bend * 0.12, bend, 1.1) },
			{ H.cyl(a.body, 0.3, 0.58, IRON, Enum.Material.Metal), along(top + bend * 0.9, bend, 0.3) },
		}
		H.rig(a, packCF, stackPieces)
		-- your own pack and stack fade a touch while the camera is behind you
		local ghostNow = -1
		H.job(a, function(self, f)
			local m = 0
			if f.player ~= nil and f.player == H.player then
				local cam = workspace.CurrentCamera
				if cam and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3 then
					m = 0.3
				end
			end
			if m ~= ghostNow then
				ghostNow = m
				engine.LocalTransparencyModifier = m
			end
		end)
		-- the exhaust, out of the stack's tip (the tip's own +X points out of it): a tall plume of light-grey cartoon
		-- puffs; the backfire's orange flame jet, a small flash and a pop ring
		local outlet = H.att(tip, Vector3.new(0.75, 0, 0))
		local puffs = E(outlet, { tex = FX.poof, flip = 4, colors = K.seq(PUFF, PUFF_D), rate = 4, life = { 1.6, 2.1 }, speed = { 3, 4.5 }, size = 1.8, accel = Vector3.new(0, 2.2, 0), drag = 0.6, spread = 10, dir = Enum.NormalId.Right, light = 0, bright = 1, sizeSeq = ns(0, 0.7, 0.5, 1.8, 1, 2.6), trans = ns(0, 0.15, 0.6, 0.3, 1, 1) })
		K.addEmitter(a, puffs)
		local jet = E(outlet, { tex = T.flame, flip = 4, colors = FIRE, rate = 0, life = { 0.3, 0.45 }, speed = { 6, 9 }, size = 1.7, spread = 12, dir = Enum.NormalId.Right, light = 0.4, bright = 1.3, rot = { -15, 15 }, sizeSeq = ns(0, 0.8, 0.3, 1.7, 1, 0.3) })
		local flash = E(outlet, { tex = T.flash, colors = K.seq(rgb(255, 190, 90), HOT), rate = 0, life = { 0.1, 0.14 }, speed = { 0, 0 }, size = 1.5, spread = 0, light = 0.4, bright = 1.3, sizeSeq = ns(0, 0.9, 0.3, 1.6, 1, 0.5) })
		local popRing = E(outlet, { tex = FX.ring, colors = K.seq(HOT, ORANGE), rate = 0, life = { 0.25, 0.3 }, speed = { 0, 0 }, size = 2.5, spread = 0, light = 0.4, bright = 1.3, sizeSeq = ns(0, 0.4, 1, 3), trans = ns(0, 0.15, 1, 1) })
		-- a backfire every 3 s (the mower's with it)
		H.every(a, 3, function(self, f)
			if f.t - self.born < 1 then
				return
			end
			kickAt = f.t
			jet:Emit(10)
			puffs:Emit(3)
			flash:Emit(1)
			popRing:Emit(1)
			emit(mFire, 6)
			mPuffs:Emit(3)
			self.lightKick = 1.5
		end)

		-- THE TURBO (running): a fountain of clippings up to twice your height behind you, flame spitting from the
		-- stack, speed lines streaming back past you
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
		local lines = E(lineBox, { tex = T.streak, colors = K.seq(rgb(255, 225, 180), HOT_L), rate = 22, life = { 0.16, 0.26 }, speed = { 10, 15 }, size = 1.4, spread = 3, dir = Enum.NormalId.Back, light = 0.4, bright = 1.2, orient = Enum.ParticleOrientation.VelocityParallel, trans = ns(0, 0.6, 0.3, 0.3, 1, 1) })
		K.addEmitter(a, lines, true)
		H.detail(a, lines)
		local nextJet = 0
		H.job(a, function(self, f)
			if turbo > 0.4 and f.t >= nextJet then
				nextJet = f.t + 0.25
				jet:Emit(2)
			end
		end)

		-- a hot trail at your feet and a soft orange light (no body outline, no body glow)
		K.feetTrail(a, K.seq(HOT_L, HOT, rgb(160, 60, 20)))
		K.light(a, HOT, 0.5, 10)
		H.lightJob(a, 0.35)

		-- the entrance (the deck grows in, the blade rises and revs up, the mower drives in on a spiral, the pack
		-- swoops onto your back): hot rings, a shower of sparks and clippings, the engine coughing into life, a rev
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 16, ORANGE, 0.6, 0.05)
			K.pulse(feet, 1, 10, HOT, 0.45, 0.25)
			emit(sparks, 6)
			mSpray:Emit(10)
			jet:Emit(8)
			puffs:Emit(4)
			flash:Emit(1)
			popRing:Emit(1)
			kickAt = os.clock()
			self.lightKick = 2
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
