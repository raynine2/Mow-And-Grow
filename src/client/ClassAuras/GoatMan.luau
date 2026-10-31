-- GOAT MAN (Secret) - the class: a white goat with big golden curled ram horns and black sunglasses, chewing a blade
-- of grass, "the G.O.A.T." (the card's dark purple is the Secret rarity's colour, not the goat's, so the aura doesn't
-- use it: it's gold, grass and wool-white). Gimmick: Graze, you eat grass as you walk: every clump within 7 studs takes
-- a hit every 0.75 s. Aura: a meadow emblem under you exactly as wide as your Graze (two golden ram horns round a
-- gold-edged grass tuft, a gold rim of grass tufts); big solid golden ram horns curling off your head, tufts of white
-- wool at their roots and glints at their tips; big black sunglasses on your face that a gold glint sweeps across; a
-- bright green blade of grass sticking out of your mouth that you chew; grass blades streaming in from the rim of the
-- Graze and vanishing into you (a storm of them while you walk, a gold "chomp" ring every bite); two giant spirit horns
-- of solid gold beads curling up behind you like wings, ridged light and dark, swaying slowly with a faint glow behind
-- them; a column of golden light; a ring of white wool puffs round your feet and soft wool clouds; gold sparkles; a gold
-- halo turning over your head; a heartbeat of gold. Gold outline. (council r3: the glow washed the goat out, so the
-- bloom, sparkles, light and column are ~40% softer than in r3.)
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local GOLD = rgb(255, 196, 60)
	local GOLD_L = rgb(255, 238, 170)
	local HORN = rgb(255, 208, 95)
	local HORN_D = rgb(205, 140, 55)
	local GRASS = rgb(110, 215, 75)
	local GRASS_L = rgb(185, 255, 140)
	local CHEW = rgb(80, 215, 45) -- the chewed blade (Neon, so it reads bright green)
	local CHEW_L = rgb(130, 235, 80)
	local WOOL = rgb(250, 248, 240)
	local SHADE = rgb(18, 18, 22)
	local SMOKE = BFX.smoke or FX.smoke
	local GRAZE_R, GRAZE_EVERY = 7, 0.75 -- server/ClassPerks GRAZE_RADIUS, GRAZE_EVERY

	-- a horn spiral in a flat plane: starts thick at the inner top, sweeps up, out, down and curls in to a thin tip
	local function spiral(n: number, cx: number, cy: number, r0: number, r1: number, side: number): { Vector3 }
		local pts = {}
		for i = 0, n do
			local t = i / n
			local phi = -0.75 + t * 1.35 * math.pi * 2
			local rr = r0 + (r1 - r0) * t
			table.insert(pts, Vector3.new(side * (cx + rr * math.sin(phi)), cy + rr * math.cos(phi), 0))
		end
		return pts
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

	return function()
		local a = H.aura(H.RANK.Secret, GOLD)
		-- the meadow emblem: as wide as the Graze, on a soft green glow, a gold ring at its edge and a faint one inside
		H.glowDisc(a, GRAZE_R * 2.5, BFX.glow, rgb(90, 200, 70), 0.6, 0, 0.07, 0.9)
		H.sigil(a, GRAZE_R * 2 / 0.98, T.cGoat, WHITE, 0, 0.12, 0.12, 1.1, 1.1)
		H.glowRing(a, GRAZE_R * 1.03, GOLD, 0.15, 0, 0.16, 1.15)
		H.glowRing(a, GRAZE_R * 0.55, GOLD_L, 0.6, 0, 0.15, 1.05)
		local twinkle = E(H.feetPiece(a, Vector3.new(GRAZE_R * 1.8, 0.2, GRAZE_R * 1.8), 0.25), { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 6, life = { 0.5, 0.9 }, speed = { 0, 0.2 }, size = 0.6, spread = 0, light = 0.7, bright = 1.2, shape = Enum.ParticleEmitterShape.Disc })
		K.addEmitter(a, twinkle)
		H.detail(a, twinkle)
		-- the ram horns: thick solid golden spirals (ridged, tapering) with a faint warm glow, curling back and round from
		-- the top of your head
		local hornCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.4) / 0.8)
			return f.headCF * CFrame.new(0, 0.2 + 0.6 * (1 - k), 0)
		end)
		local hornHolder = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, hornHolder, hornCF)
		local tips = {}
		for _, s in { -1, 1 } do
			-- (a spiral in a plane turned 45 degrees out and back, so it shows its curl from the front and the side: it
			-- starts at the top of the head, sweeps up, out and back, down past the ear and curls round to the cheek)
			local e1 = Vector3.new(0, 1, 0)
			local e2 = Vector3.new(s * 0.72, 0, 0.7)
			local centre = Vector3.new(s * 0.9, 0.05, 0.15)
			local core = {}
			for k = 0, 14 do
				local tt = k / 14
				local phi = -0.45 + tt * math.pi * 1.7
				local rr = 0.85 - 0.6 * tt
				table.insert(core, centre + Vector3.new(s * 0.25 * tt, 0, 0) + (e1 * math.cos(phi) + e2 * math.sin(phi)) * rr)
			end
			H.chain(hornHolder, core, { colors = K.seq(GOLD_L, GOLD), w0 = 1.3, w1 = 0.25, trans = NumberSequence.new(0.86), light = 0.6, bright = 0.9 })
			local pieces = {}
			for k, p in core do
				local tt = (k - 1) / (#core - 1)
				local ball = H.solid(a.body, Vector3.one * (0.78 - 0.58 * tt), if k % 2 == 0 then HORN else HORN_D, Enum.Material.Metal, 0.25)
				ball.Shape = Enum.PartType.Ball
				table.insert(pieces, { ball, CFrame.new(p) })
			end
			H.rig(a, hornCF, pieces)
			table.insert(tips, core[#core])
		end
		local tipSparks = {}
		for i, p in tips do
			local sp = E(H.att(hornHolder, p), { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 3, life = { 0.6, 1 }, speed = { 0.2, 0.6 }, size = 0.6, spread = 180, light = 0.7, bright = 1.4 })
			K.addEmitter(a, sp)
			tipSparks[i] = sp
		end
		-- tufts of white wool round the roots of the horns (the goat's fleece), soft wool drifting off them
		local tufts = {}
		for _, s in { -1, 1 } do
			table.insert(tufts, { H.ellipsoid(a.body, Vector3.new(0.75, 0.5, 0.75), WOOL), CFrame.new(s * 0.55, 0.6, -0.05) })
			table.insert(tufts, { H.ellipsoid(a.body, Vector3.new(0.5, 0.38, 0.5), WOOL), CFrame.new(s * 0.82, 0.8, 0.2) })
			local puff = E(H.att(hornHolder, Vector3.new(s * 0.65, 0.65, 0)), { tex = SMOKE, colors = K.seq(WOOL), rate = 1.2, life = { 1, 1.5 }, speed = { 0.2, 0.4 }, size = 0.6, grow = true, accel = Vector3.new(0, 0.5, 0), spin = 20, spread = 60, light = 0.1, bright = 1.1, trans = ns(0, 1, 0.3, 0.4, 1, 1) })
			K.addEmitter(a, puff)
			H.detail(a, puff)
		end
		H.rig(a, hornCF, tufts)

		-- the sunglasses on your face (council r3: 1.2x bigger, black lenses, a top bar and arms back to the ears; a gold
		-- glint sweeps across them every few seconds)
		local faceCF = perFrame(function(f): CFrame
			local head = H.limb(f, "Head")
			local z = if head then head.Size.Z / 2 + 0.04 else 0.64
			return f.headCF * CFrame.new(0, 0.12, -z)
		end)
		local lensL = H.solid(a.body, Vector3.new(0.53, 0.31, 0.06), SHADE, Enum.Material.Glass, 0.35)
		local lensR = H.solid(a.body, Vector3.new(0.53, 0.31, 0.06), SHADE, Enum.Material.Glass, 0.35)
		local bridge = H.solid(a.body, Vector3.new(1.1, 0.075, 0.06), SHADE, Enum.Material.SmoothPlastic)
		local armL = H.solid(a.body, Vector3.new(0.06, 0.07, 0.7), SHADE, Enum.Material.SmoothPlastic)
		local armR = H.solid(a.body, Vector3.new(0.06, 0.07, 0.7), SHADE, Enum.Material.SmoothPlastic)
		H.rig(a, faceCF, {
			{ lensL, CFrame.new(-0.3, 0, 0) },
			{ lensR, CFrame.new(0.3, 0, 0) },
			{ bridge, CFrame.new(0, 0.12, 0) },
			{ armL, CFrame.new(-0.62, 0.1, 0.36) },
			{ armR, CFrame.new(0.62, 0.1, 0.36) },
		})
		local glint = H.solid(a.body, Vector3.new(0.085, 0.34, 0.02), GOLD_L, Enum.Material.Neon)
		K.move(a, glint, function(f)
			local p = (f.t % 3.2) / 0.45
			local x = if p < 1 then -0.58 + 1.16 * p else 9
			return faceCF(f) * CFrame.new(x, 0, -0.045) * CFrame.Angles(0, 0, math.rad(-30))
		end)
		local glintOn: boolean? = nil
		H.job(a, function(self, f)
			local on = (f.t % 3.2) < 0.45
			if on ~= glintOn then
				glintOn = on
				glint.Transparency = if on then 0 else 1
			end
		end)
		-- the blade of grass you chew: a long bright green blade sticking out of the corner of your mouth and a shorter
		-- one drooping under it, wagging as you chew
		local mouthCF = perFrame(function(f): CFrame
			local chew = math.sin(f.t * 9)
			return faceCF(f) * CFrame.new(0.2, -0.42 + 0.03 * chew, 0.08) * CFrame.Angles(0, 0, math.rad(6) * chew)
		end)
		local mainBlade = H.blade(a.body, { Vector3.new(0, 0, 0), Vector3.new(0.45, 0.04, -0.15), Vector3.new(0.85, -0.05, -0.22), Vector3.new(1.15, -0.28, -0.2) }, 0.22, 0.05, 0.05, CHEW, Enum.Material.Neon, nil, Vector3.zAxis)
		local sideBlade = H.blade(a.body, { Vector3.new(0, -0.02, 0), Vector3.new(0.3, -0.14, -0.12), Vector3.new(0.52, -0.37, -0.15), Vector3.new(0.66, -0.64, -0.1) }, 0.16, 0.04, 0.05, CHEW_L, Enum.Material.SmoothPlastic, nil, Vector3.zAxis)
		for _, pc in mainBlade do
			local part = pc[1] :: BasePart
			part.Reflectance = 0
		end
		for _, pc in sideBlade do
			local part = pc[1] :: BasePart
			part.Reflectance = 0
			H.detail(a, part)
		end
		H.rig(a, mouthCF, mainBlade)
		H.rig(a, mouthCF, sideBlade)
		-- Graze: grass streaming in from the rim of the Graze to be eaten; a storm of it while you walk, a chomp ring each bite
		local mouth = K.piece(a.body, Vector3.new(GRAZE_R * 2, 1.2, GRAZE_R * 2))
		K.move(a, mouth, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.6, 0))
		end)
		local graze = E(mouth, { tex = BFX.strand, colors = K.seq(GRASS_L, GRASS, GOLD_L), rate = 4, life = { 0.85, 1 }, speed = { 7, 8 }, size = 0.6, spin = 260, spread = 0, light = 0.3, bright = 1.4, shape = Enum.ParticleEmitterShape.Cylinder, inward = true, surface = true, trans = ns(0, 1, 0.15, 0, 0.85, 0, 1, 1) })
		K.addEmitter(a, graze)
		local lastBite = 0
		H.job(a, function(self, f)
			local walking = f.calm < 0.5
			graze.Rate = if walking then 30 else 5
			if walking and f.t - lastBite >= GRAZE_EVERY then
				lastBite = f.t
				K.pulse(f.feet, GRAZE_R * 2, 2, GOLD, 0.4, 0.3)
			end
		end)
		-- two giant spirit horns curling up behind you like wings, breathing and swaying slowly: each a tube of solid
		-- gold beads (council r3: no longer neon, so the spiral reads), thick at the root and tapering, ridged light and
		-- dark like a ram's horn, with a faint glow behind
		local spiritCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.5) / 1)
			return f.root * CFrame.new(0, 0.9 + 0.12 * math.sin(f.t * 1.3) - 2 * (1 - k), 1.4) * CFrame.Angles(math.rad(-8), math.rad(6) * math.sin(f.t * 0.7), 0)
		end)
		local spirit = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, spirit, spiritCF)
		for _, side in { -1, 1 } do
			local pts = spiral(32, 2.25, 2.2, 2.45, 0.65, side)
			local beads = {}
			for k, p in pts do
				local tt = (k - 1) / (#pts - 1)
				local bead = H.solid(a.body, Vector3.one * (1 - 0.66 * tt), if k % 3 == 0 then HORN_D else HORN, Enum.Material.Metal, 0.2)
				bead.Shape = Enum.PartType.Ball
				table.insert(beads, { bead, CFrame.new(p) })
				if k % 6 == 2 or k % 6 == 4 then
					H.detail(a, bead)
				end
			end
			H.rig(a, spiritCF, beads)
			local glow = H.chain(spirit, pts, { colors = K.seq(GOLD_L, GOLD), w0 = 1.9, w1 = 0.5, trans = NumberSequence.new(0.9), light = 0.6, bright = 0.9, zoff = -0.05 })
			for _, b in glow do
				H.detail(a, b)
			end
			local ts = E(H.att(spirit, pts[#pts]), { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 3, life = { 0.6, 1 }, speed = { 0.2, 0.5 }, size = 0.7, spread = 180, light = 0.7, bright = 1.3 })
			K.addEmitter(a, ts)
			H.detail(a, ts)
		end
		-- a gold halo turning over your head
		local halo = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, halo, function(f)
			local k = ease((f.t - a.born - 0.6) / 0.7)
			return CFrame.new(f.head + Vector3.new(0, 1.55 + 0.08 * math.sin(f.t * 1.6) + 2 * (1 - k), 0)) * CFrame.Angles(0, f.t * 0.8, 0)
		end)
		local hb = K.beamRing(halo, 0.95, 0.16, K.seq(GOLD_L, GOLD, GOLD_L), 1.8, 0.05, 20, false)
		for _, b in hb do
			b.LightEmission = 0.6
		end
		local hs = E(halo, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 3, life = { 0.4, 0.7 }, speed = { 0.2, 0.6 }, size = 0.5, spread = 180, light = 0.7, bright = 1.2 })
		K.addEmitter(a, hs)
		H.detail(a, hs)
		-- the column of golden light (fades while you run), golden motes falling down it
		local pillar = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, pillar, function(f)
			return CFrame.new(f.feet) * CFrame.Angles(0, f.t * 0.3, 0)
		end)
		local pBeams = {}
		for i = 1, 2 do
			pBeams[i] = H.beam(H.att(pillar, Vector3.new(0, 0.3, 0)), H.att(pillar, Vector3.new(0, 18, 0)), { colors = K.seq(GOLD_L, GOLD), w0 = 3.6, w1 = 1.2, trans = ns(0, 0.65, 0.5, 0.8, 1, 1), tex = if i == 1 then T.stripBody else T.energy, texMode = Enum.TextureMode.Stretch, texSpeed = 0.5 + i * 0.3, light = 0.5, bright = 0.85 })
		end
		H.detail(a, pBeams[2])
		local lastG = -1
		H.job(a, function(self, f)
			local g = f.calm
			if math.abs(g - lastG) > 0.03 then
				lastG = g
				local b0 = 1 - 0.36 * g
				local seq = ns(0, b0, 0.5, b0 + (1 - b0) * 0.4, 1, 1)
				for _, b in pBeams do
					b.Transparency = seq
				end
			end
		end)
		local fall = K.piece(a.body, Vector3.new(2.5, 0.5, 2.5))
		K.move(a, fall, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 15, 0))
		end)
		local motes = E(fall, { tex = T.streak, colors = K.seq(WHITE, GOLD_L, GOLD), rate = 6, life = { 0.9, 1.2 }, speed = { 12, 16 }, size = 0.8, spread = 3, light = 0.6, bright = 1.2, dir = Enum.NormalId.Bottom, orient = Enum.ParticleOrientation.VelocityParallel, trans = ns(0, 1, 0.2, 0.1, 1, 1) })
		K.addEmitter(a, motes)
		H.detail(a, motes)
		-- a ring of white wool puffs round your feet (the goat's fleece), rising out of the ground when the aura forms and
		-- turning slowly, soft wool clouds rolling off it
		for i = 1, 8 do
			local big = i % 2 == 1
			local th0 = (i - 1) / 8 * math.pi * 2
			local pieces = { { H.ellipsoid(a.model, if big then Vector3.new(1.3, 0.8, 1.1) else Vector3.new(0.95, 0.6, 0.85), WOOL), CFrame.new() } }
			if big then
				table.insert(pieces, { H.ellipsoid(a.model, Vector3.new(0.7, 0.5, 0.65), WOOL), CFrame.new(0.2, 0.38, -0.1) })
			end
			H.rig(a, function(f)
				local k = ease((f.t - a.born - 0.2) / 0.6)
				local th = th0 + f.t * 0.25
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * 1.9, 0.4 + 0.08 * math.sin(f.t * 1.6 + i) - 1.2 * (1 - k), math.sin(th) * 1.9)) * CFrame.Angles(0, -th, 0)
			end, pieces)
		end
		local fleece = E(H.feetPiece(a, Vector3.new(4, 0.3, 4), 0.35), { tex = SMOKE, colors = K.seq(WOOL), rate = 3, life = { 1.4, 2 }, speed = { 0.2, 0.5 }, size = 1.2, grow = true, accel = Vector3.new(0, 0.3, 0), spin = 20, spread = 40, light = 0.05, bright = 1, shape = Enum.ParticleEmitterShape.Disc, trans = ns(0, 1, 0.3, 0.5, 1, 1) })
		K.addEmitter(a, fleece)
		H.detail(a, fleece)
		-- wool-white puffs drifting off you, gold sparkles, the aura itself (softer than r3)
		local body = K.bodyBox(a, Vector3.new(4.5, 5, 4.5), 0)
		local wool = E(body, { tex = SMOKE, colors = K.seq(WOOL), rate = 2.5, life = { 1.6, 2.2 }, speed = { 0.2, 0.5 }, size = 1.1, grow = true, accel = Vector3.new(0, 0.4, 0), spin = 20, spread = 180, light = 0.1, bright = 1.1, trans = ns(0, 1, 0.3, 0.45, 1, 1) })
		K.addEmitter(a, wool)
		H.detail(a, wool)
		local dust = E(body, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L, GOLD), rate = 6, life = { 0.9, 1.5 }, speed = { 0.2, 0.7 }, size = 0.45, spread = 180, light = 0.7, bright = 1.3 })
		K.addEmitter(a, dust)
		local haze, wisps = H.shell(a, K.seq(GOLD_L, GOLD, rgb(150, 220, 90)), 6, 0.85)
		K.bright(haze, 0.85)
		K.bright(wisps, 1)
		local updraft = H.updraft(a, GRAZE_R * 0.9, K.seq(WHITE, GOLD_L, GOLD), 8)
		K.bright(updraft, 1.2)
		-- the heartbeat: a gold ring and a white starburst
		local burstAt = H.feetPiece(a, Vector3.new(0.4, 0.4, 0.4), 2.6)
		local starburst = E(burstAt, { tex = T.flash, colors = K.seq(WHITE), rate = 0, life = { 0.25, 0.35 }, speed = { 0, 0 }, size = 7, light = 0.8, bright = 0.9, sizeSeq = ns(0, 1.5, 0.3, 7, 1, 0), trans = ns(0, 0.35, 1, 1) })
		H.every(a, 1.8, function(self, f)
			if f.ground > 0.3 then
				K.pulse(f.feet, 2, 16, GOLD, 1, 0.25)
			end
			self.lightKick = 1.6
		end)
		K.feetTrail(a, K.seq(GOLD_L, GOLD, GRASS))
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.3, 1.2), 0.3)
		K.addEmitter(a, E(kick, { tex = BFX.strand, colors = K.seq(GRASS_L, GRASS), rate = 10, life = { 0.5, 0.8 }, speed = { 3, 6 }, size = 0.55, accel = Vector3.new(0, -25, 0), spin = 300, spread = 45, light = 0, bright = 1 }), true)
		K.addEmitter(a, E(kick, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 8, life = { 0.5, 0.9 }, speed = { 1, 3 }, size = 0.6, accel = Vector3.new(0, 1, 0), spread = 60, light = 0.7, bright = 1.3 }), true)
		K.outline(a, GOLD, 0.25)
		K.light(a, GOLD, 1, 16)
		H.lightJob(a, 0.1)
		H.gimmick(a, { graze = true }, 6, function(self, d)
			lastBite = os.clock()
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 24, GOLD, 1.1, 0.1)
			K.pulse(feet, 1, 16, GRASS_L, 0.8, 0.15)
			K.pulse(feet, 1, 9, WHITE, 0.5, 0.3)
			starburst:Emit(1)
			dust:Emit(18)
			graze:Emit(40)
			fleece:Emit(10)
			for _, sp in tipSparks do
				sp:Emit(8)
			end
			self.lightKick = 2.5
		end
		return a
	end
end
