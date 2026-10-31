-- MOWER SPECIALIST (Epic) - the card: a bright orange ride-on mower with black wheels, puffing exhaust; the ride-on mower
-- expert. Gimmick: Turbo Deck, ride-on mowers cut 25% wider, drive 15% faster and burn 40% less fuel (client/ClassFx draws
-- the Turbo Deck on the mower you ride). Aura: the mower's cutting deck under you (dark steel, a white-hot orange rim),
-- its steel blade revving up when it forms and spinning so fast it blurs, sparks spraying off its teeth, clippings
-- flying; run and the Turbo kicks in: the blade spins faster, the sparks thicken and the cut ring widens by a quarter.
-- On your back the mower's big orange engine (a rounded hood, a finned cylinder head, a grille, black wheels with gold
-- hubs) with two chrome exhaust stacks rising above your shoulders (smoke puffs, flame tips on a backfire every 3 s) and
-- two chunky gears meshing behind it that peek out either side of you; the mower's steering wheel floating in front of
-- you, turning; an orange heat aura and outline; speed lines when you run.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local ORANGE = rgb(242, 107, 29) -- the card's mower orange (#F26B1D)
	local HOT = rgb(255, 140, 40)
	local HOT_L = rgb(255, 220, 150)
	local DECK = rgb(43, 46, 51) -- dark steel (#2B2E33)
	local TEETH = rgb(154, 163, 173) -- steel (#9AA3AD)
	local CHROME = rgb(214, 220, 228)
	local RUBBER = rgb(28, 28, 32)
	local GOLD = rgb(255, 200, 60)
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing upright)
	local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder lying front to back)

	-- a chunky gear in its rig's XY plane (it turns about Z): a coloured disc, a dark steel web, a hub and n square teeth
	-- (their pitch circle is r + 0.1). Returns its pieces for H.rig.
	local function gear(parent: Instance, r: number, n: number, thick: number, color: Color3, hub: Color3): { { BasePart | CFrame } }
		local pieces = {
			{ H.cyl(parent, thick, r * 2, color, Enum.Material.Metal, 0.2), ALONG_Z },
			{ H.cyl(parent, thick + 0.06, r * 1.3, DECK, Enum.Material.Metal, 0.1), ALONG_Z },
			{ H.cyl(parent, thick + 0.16, r * 0.45, hub, Enum.Material.Metal, 0.35), ALONG_Z },
		}
		local tw = 2 * math.pi * (r + 0.1) / n * 0.5
		for k = 0, n - 1 do
			local th = k / n * math.pi * 2
			table.insert(pieces, { H.solid(parent, Vector3.new(0.32, tw, thick), color, Enum.Material.Metal, 0.2), CFrame.Angles(0, 0, th) * CFrame.new(r + 0.1, 0, 0) })
		end
		return pieces
	end

	return function()
		local a = H.aura(H.RANK.Epic, HOT)
		-- the blade's spin: revs up as the aura forms, faster still while you run (the Turbo)
		local angle = 0
		local turbo = 0 -- (0 standing .. 1 running)
		local lastT: number? = nil
		H.job(a, function(self, f)
			local k = H.smooth((f.t - self.born) / 1.4)
			local dt = if lastT then math.clamp(f.t - lastT, 0, 0.1) else 0
			lastT = f.t
			turbo += ((1 - f.calm) - turbo) * math.min(1, dt * 4)
			angle += dt * (2 + 13 * k + 9 * turbo)
		end)
		-- the deck: a solid dark steel housing under the blade (so the blade's holes show steel, not grass)
		local deck = H.cyl(a.model, 0.12, 10.4, DECK, Enum.Material.Metal, 0.1)
		K.move(a, deck, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.06, 0)) * UP
		end)
		-- the steel blade, and two fainter copies trailing it (the blur of its teeth)
		local blade = H.plate(a.model, 10, T.saw, TEETH, 0, false, 1.3)
		local blurs = {}
		for n = 1, 2 do
			local g, _, gguis = H.plate(a.model, 10, T.saw, CHROME, 0.45 + n * 0.17, false, 1.3)
			H.detail(a, gguis[1])
			blurs[n] = g
			K.move(a, g, function(f)
				return CFrame.new(f.feet + Vector3.new(0, 0.13 + n * 0.01, 0)) * CFrame.Angles(0, angle - n * 0.13, 0)
			end)
		end
		K.move(a, blade, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, angle, 0)
		end)
		local grown = false
		H.job(a, function(self, f)
			if grown then
				return
			end
			local k = (f.t - self.born) / 0.8
			local s = math.max(0.1, 10 * ease(k))
			blade.Size = Vector3.new(s, 0.05, s)
			for _, g in blurs do
				g.Size = Vector3.new(s, 0.05, s)
			end
			deck.Size = Vector3.new(0.12, s * 1.04, s * 1.04)
			grown = k >= 1
		end)
		-- the rim: white-hot orange at the deck's edge; the outer ring widens by a quarter with the Turbo
		local rimR = 5.2
		local rim = H.glowRing(a, rimR, HOT, 0.05, 0, 0.175, 1.4)
		H.glowRing(a, 5.0, HOT_L, 0.45, 0, 0.165, 1.3)
		-- sparks off the teeth (four points round the rim, spinning with the blade, ~40 a second) and clippings
		local rimHolder = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, rimHolder, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, angle, 0)
		end)
		local sparks = {}
		for k = 0, 3 do
			local th = k / 4 * math.pi * 2
			local at = H.att(rimHolder, Vector3.new(math.cos(th) * 4.9, 0, math.sin(th) * 4.9))
			at.Orientation = Vector3.new(0, -math.deg(th), 0)
			local s = E(at, { tex = T.streak, colors = K.seq(WHITE, HOT_L, HOT), rate = 10, life = { 0.25, 0.35 }, speed = { 15, 25 }, size = 0.9, accel = Vector3.new(0, -35, 0), spread = 30, light = 0.8, bright = 2.6, dir = Enum.NormalId.Front, orient = Enum.ParticleOrientation.VelocityParallel, sizeSeq = ns(0, 0.9, 1, 0.08) })
			K.addEmitter(a, s)
			if k % 2 == 1 then
				H.detail(a, s)
			end
			sparks[k + 1] = s
		end
		local clipBase = H.feetPiece(a, Vector3.new(9, 0.2, 9), 0.3)
		local clips = E(clipBase, { tex = BFX.strand, colors = K.seq(rgb(150, 230, 90), rgb(70, 140, 50)), rate = 10, life = { 0.4, 0.7 }, speed = { 3, 6 }, size = 0.4, accel = Vector3.new(0, -22, 0), spin = 400, spread = 60, light = 0, bright = 1, shape = Enum.ParticleEmitterShape.Disc })
		K.addEmitter(a, clips)
		local lastTurbo = -1
		H.job(a, function(self, f)
			if math.abs(turbo - lastTurbo) < 0.04 then
				return
			end
			lastTurbo = turbo
			local d = rimR * 2 / 0.92 * (1 + 0.25 * turbo)
			rim.Size = Vector3.new(d, 0.05, d)
			for _, s in sparks do
				s.Rate = 10 + 5 * turbo
			end
		end)

		-- the engine on your back (worked out once per frame: ~50 pieces ride it), rising into place as the aura forms
		local ecT, ecCF = -1, CFrame.identity
		local function engineCF(f): CFrame
			if f.t == ecT then
				return ecCF
			end
			local k = ease((f.t - a.born - 0.2) / 0.7)
			local buzz = 0.025 * math.sin(f.t * 55)
			ecT, ecCF = f.t, f.root * CFrame.new(buzz, -1.5 * (1 - k), 0)
			return ecCF
		end
		-- (a block under a rounded hood, a grille on the back, a finned cylinder head on top, black wheels with gold
		-- hubs at the bottom corners, two chrome stacks rising past your shoulders)
		local engine = {
			{ H.solid(a.body, Vector3.new(1.95, 1.1, 0.9), ORANGE, Enum.Material.SmoothPlastic, 0.05), CFrame.new(0, 0.35, 1.3) },
			{ H.cyl(a.body, 1.95, 0.9, ORANGE, Enum.Material.SmoothPlastic, 0.05), CFrame.new(0, 0.9, 1.3) },
			{ H.cyl(a.body, 0.62, 0.55, DECK, Enum.Material.Metal), CFrame.new(0, 1.55, 1.3) * UP },
		}
		for n = 0, 3 do
			table.insert(engine, { H.cyl(a.body, 0.07, 1.0, TEETH, Enum.Material.Metal, 0.2), CFrame.new(0, 1.4 + n * 0.14, 1.3) * UP })
		end
		for n = 0, 2 do
			table.insert(engine, { H.solid(a.body, Vector3.new(1.35, 0.12, 0.06), DECK, Enum.Material.Metal), CFrame.new(0, 0.62 - n * 0.24, 1.76) })
		end
		for _, side in { -1, 1 } do
			table.insert(engine, { H.cyl(a.body, 0.42, 1.15, RUBBER, Enum.Material.SmoothPlastic), CFrame.new(side * 1.18, -0.45, 1.3) })
			table.insert(engine, { H.cyl(a.body, 0.46, 0.45, GOLD, Enum.Material.Metal, 0.2), CFrame.new(side * 1.18, -0.45, 1.3) })
			table.insert(engine, { H.cyl(a.body, 2.3, 0.28, CHROME, Enum.Material.Metal, 0.4), CFrame.new(side * 0.75, 2.0, 1.15) * UP })
			table.insert(engine, { H.cyl(a.body, 0.14, 0.38, DECK, Enum.Material.Metal, 0.1), CFrame.new(side * 0.75, 3.12, 1.15) * UP })
		end
		H.rig(a, engineCF, engine)
		-- the exhaust: smoke puffing out of both stacks, flame tips on a backfire
		local puffs, jets = {}, {}
		for _, side in { -1, 1 } do
			local tipP = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, tipP, function(f)
				return engineCF(f) * CFrame.new(side * 0.75, 3.25, 1.15)
			end)
			local puff = E(tipP, { tex = BFX.smoke or FX.smoke, colors = K.seq(rgb(190, 190, 195), rgb(110, 110, 115)), rate = 2.5, life = { 0.7, 1.1 }, speed = { 2, 3 }, size = 0.9, grow = true, accel = Vector3.new(0, 1.5, 0), spread = 12, light = 0, bright = 1, trans = ns(0, 0.5, 0.2, 0.35, 1, 1) })
			K.addEmitter(a, puff)
			local jet = E(tipP, { tex = T.flame, flip = 4, colors = K.seq(rgb(255, 240, 200), HOT, rgb(160, 50, 20)), rate = 0, life = { 0.25, 0.4 }, speed = { 5, 7 }, size = 1.3, spread = 8, light = 1, bright = 1.9 })
			table.insert(puffs, puff)
			table.insert(jets, jet)
		end
		-- two chunky gears meshing behind the engine (a big steel one, a smaller orange one), big enough to show either
		-- side of you from the front; they turn with the blade, the small one faster by the ratio of their teeth
		local GA, GB = Vector3.new(-1.15, 1.3, 0.72), Vector3.new(1.1, 1.08, 0.72)
		local RA, RB, NA, NB = 1.2, 0.81, 10, 7
		local alpha = math.atan2(GB.Y - GA.Y, GB.X - GA.X)
		local phaseB = alpha * (1 + NA / NB) + math.pi + math.pi / NB -- (a gap of B meets each tooth of A)
		H.rig(a, function(f)
			return engineCF(f) * CFrame.new(GA) * CFrame.Angles(0, 0, angle * 0.3)
		end, gear(a.body, RA, NA, 0.22, CHROME, GOLD))
		H.rig(a, function(f)
			return engineCF(f) * CFrame.new(GB) * CFrame.Angles(0, 0, -angle * 0.3 * NA / NB + phaseB)
		end, gear(a.body, RB, NB, 0.22, ORANGE, CHROME))
		-- a backfire every few seconds: flame out of both stacks, a puff of smoke
		H.every(a, 3.2, function(self, f)
			if f.t - self.born > 1 then
				for _, j in jets do
					j:Emit(5)
				end
				for _, p in puffs do
					p:Emit(2)
				end
				self.lightKick = 1.6
			end
		end)

		-- the mower's steering wheel floating in front of you, tilted like a ride-on's and turning: a chrome rim, three
		-- dark spokes, an orange hub with a gold cap, the column going down into the dash
		local wcT, wcCF = -1, CFrame.identity
		local function wheelCF(f): CFrame
			if f.t == wcT then
				return wcCF
			end
			local k = ease((f.t - a.born - 0.35) / 0.7)
			local steer = 0.35 * math.sin(f.t * 0.9) + 0.15 * math.sin(f.t * 2.3)
			wcT, wcCF = f.t, f.root * CFrame.new(0, 0.35 + 0.08 * math.sin(f.t * 1.7), -1.45 - 1.5 * (1 - k)) * CFrame.Angles(math.rad(-50), 0, 0) * CFrame.Angles(0, 0, steer)
			return wcCF
		end
		local wheel = H.loop(a.body, 0.6, 0.14, 12, CHROME, Enum.Material.Metal)
		for _, th in { 0, math.pi, math.pi * 1.5 } do
			table.insert(wheel, { H.solid(a.body, Vector3.new(0.52, 0.11, 0.08), DECK, Enum.Material.Metal), CFrame.Angles(0, 0, th) * CFrame.new(0.3, 0, 0) })
		end
		local cap = H.solid(a.body, Vector3.new(0.17, 0.17, 0.17), GOLD, Enum.Material.Neon)
		cap.Shape = Enum.PartType.Ball
		local column = H.cyl(a.body, 1.1, 0.14, DECK, Enum.Material.Metal)
		H.detail(a, column)
		table.insert(wheel, { H.cyl(a.body, 0.18, 0.4, ORANGE, Enum.Material.SmoothPlastic), ALONG_Z })
		table.insert(wheel, { cap, CFrame.new(0, 0, 0.1) })
		table.insert(wheel, { column, CFrame.new(0, 0, -0.62) * ALONG_Z })
		H.rig(a, wheelCF, wheel)

		H.shell(a, K.seq(HOT_L, HOT), 6, 0.95)
		local body = K.bodyBox(a, Vector3.new(3.5, 4, 1), 0)
		local lines = E(body, { tex = T.streak, colors = K.seq(WHITE, HOT_L), rate = 24, life = { 0.18, 0.28 }, speed = { 0.5, 1 }, size = 1.8, spread = 0, light = 1, bright = 1.6, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 0.5, 0.5, 0.3, 1, 1) })
		K.addEmitter(a, lines, true)
		K.feetTrail(a, K.seq(HOT_L, HOT, rgb(160, 60, 20)))
		K.outline(a, HOT, 0.4)
		K.light(a, HOT, 1, 12)
		H.lightJob(a, 0.35)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 14, HOT, 0.6, 0.05)
			for _, s in sparks do
				s:Emit(10)
			end
			for _, j in jets do
				j:Emit(8)
			end
			clips:Emit(18)
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
