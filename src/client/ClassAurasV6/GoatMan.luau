-- GOAT MAN (Secret, the rarest) - the card: a white goat with big golden curled ram horns and black sunglasses, chewing
-- a blade of grass: "the G.O.A.T." (its purple backdrop is the Secret rarity's colour, not the goat's: the aura is gold,
-- grass green and wool-white). Gimmick: Graze, you eat grass as you walk: every clump within 7 studs takes a hit every
-- 0.75 s. Aura, built from ForgeGUI props and the VFX Forge layers in Loop_GoatMan:
--   - the ForgeGUI meadow emblem under you, exactly as wide as the Graze (radius 7), on a soft green glow, a gold ring
--     on its rim and a curtain of light rising off that rim
--   - grass blades swirling in from the rim of the Graze into you, from the ground up to your chest: a storm of them
--     while you walk, and every bite a gold ring snaps in from the rim and grass bursts at your mouth
--   - the 3D golden ram horns (gm_horns) on your head, wool puffing off their roots; the 3D sunglasses (gm_shades) on
--     your face with a glint sweeping across them; a blade of grass you chew
--   - the same horns giant and glowing behind you like wings, gold wisps and sparkles rising off them
--   - a gold halo over your horns, a column of golden light with motes falling down it, wool-white puffs round your
--     feet, gold sparkles and a ring of them orbiting your waist, gold wisps rising from behind you, a gold heartbeat
-- (Council: the old glow washed the goat out, so nothing big and bright sits on the body; the column is faint there.)
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local FX, BFX = H.FX, H.BFX
	local E = H.E
	local LOOP = "Loop_GoatMan"
	local GOLD = rgb(255, 196, 60)
	local GOLD_L = rgb(255, 238, 170)
	local GRASS = rgb(110, 215, 75)
	local GRASS_L = rgb(185, 255, 140)
	local CHEW = rgb(95, 210, 60)
	local CHEW_L = rgb(140, 230, 85)
	local GRAZE_R, GRAZE_EVERY = 7, 0.75 -- server/ClassPerks GRAZE_RADIUS, GRAZE_EVERY

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

	return function()
		local a = H.aura(H.RANK.Secret, GOLD)

		-- the ground: the ForgeGUI meadow emblem (golden ram horns round a tuft of grass, a gold rim of grass tufts),
		-- exactly as wide as the Graze (the badge fills 98% of its image), a gold ring on its rim
		-- (a soft green glow under it, so the meadow shines a little past its rim)
		local _, _, meadowGuis = H.glowDisc(a, GRAZE_R * 2.4, BFX.glow, rgb(120, 220, 80), 0.7, 0, 0.07, 0.9)
		H.detail(a, meadowGuis[1])
		H.sigil(a, GRAZE_R * 2 / 0.98, T.embGoatMan, WHITE, 0.15, 0.05, 0.12, 1, 1.05)
		H.glowRing(a, GRAZE_R, GOLD, 0.2, 0, 0.16, 1.25)
		-- a curtain of light rising off the rim of the Graze
		local curtain = H.updraft(a, GRAZE_R, K.seq(WHITE, GOLD_L, GOLD), 9, T.streak, 0.8)
		K.bright(curtain, 1.3)
		H.detail(a, curtain)

		-- Graze: grass blades swirling in from the rim of the Graze into you, from the ground up to your chest. The
		-- layer's cylinder is the Graze; it turns and the blades are locked to it, so they spiral in, rising a little
		-- toward you. A storm of them while you walk.
		local grazeBox = K.piece(a.model, Vector3.new(GRAZE_R * 2, 2.6, GRAZE_R * 2))
		K.move(a, grazeBox, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, f.t * 1.3, 0)
		end)
		local grass = H.layer(a, LOOP, "Grass", grazeBox, false, 1.2)
		for _, e in grass do
			e.LockedToPart = true
			e.Acceleration = Vector3.new(0, 4, 0)
		end
		setRate(a, grass, 18)
		-- each bite: a gold ring snaps in from the rim of the Graze (it shows only while it moves)
		local chomp, chompImgs = H.plate(a.model, 2, T.ringCrisp, GOLD, 1, false, 1.4)
		K.move(a, chomp, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.22, 0))
		end)

		-- the horns (the card): the ForgeGUI golden ram horns on your head, their band on the crown of your head and the
		-- curls round your ears, glinting; they drop on with a spin when the aura forms. Wool puffs off their roots.
		local HORNS = 2.9
		local horns = H.prop(a.body, "gm_horns", HORNS)
		local hz = H.propSize("gm_horns", HORNS)
		local hornCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.5) / 0.7)
			local top = f.head.Y - f.headCF.Position.Y -- (the top of the head over its centre)
			-- (the band sits a quarter of the way down the prop: put it on top of the head)
			return f.headCF * CFrame.new(0, top + 0.05 - hz.Y * 0.25 + 2.5 * (1 - k), 0.06) * CFrame.Angles(0, (1 - k) * 6.3, 0)
		end)
		K.move(a, horns, hornCF)
		local hornSparkle = H.layer(a, LOOP, "Sparkle", horns, false, 0.5)
		setRate(a, hornSparkle, 2)
		local roots = K.piece(a.body, Vector3.new(hz.X * 0.45, 0.3, hz.Z * 0.6))
		K.move(a, roots, function(f)
			return hornCF(f) * CFrame.new(0, hz.Y * 0.2, 0)
		end)
		local tuft = H.layer(a, LOOP, "Wool", roots, false, 0.35)
		setRate(a, tuft, 1.5)
		for _, e in tuft do
			H.detail(a, e)
		end

		-- the sunglasses: the ForgeGUI shades on your face (lenses to the front, arms back over your ears); they slide down
		-- onto your eyes when the aura forms, and a gold glint sweeps across them every few seconds
		local SHADES = 1.5 -- (its longest side is the arms)
		local shades = H.prop(a.body, "gm_shades", SHADES)
		local sz = H.propSize("gm_shades", SHADES)
		local faceCF = perFrame(function(f): CFrame
			local head = H.limb(f, "Head")
			local half = if head then head.Size.Z / 2 else 0.6
			return f.headCF * CFrame.new(0, 0.1, -half) -- (eye level on the face)
		end)
		K.move(a, shades, function(f)
			local k = ease((f.t - a.born - 0.85) / 0.5)
			return faceCF(f) * CFrame.new(0, 0.8 * (1 - k), sz.Z / 2 - 0.12)
		end)
		local SWEEP, EVERY = 0.4, 3.2
		local glint = H.solid(a.body, Vector3.new(0.08, sz.Y * 0.9, 0.02), GOLD_L, Enum.Material.Neon)
		glint.Transparency = 1
		K.move(a, glint, function(f)
			local p = (f.t % EVERY) / SWEEP
			local x = if p < 1 then (p - 0.5) * sz.X * 0.85 else 0
			return faceCF(f) * CFrame.new(x, 0, -0.16) * CFrame.Angles(0, 0, math.rad(-28))
		end)
		local twinkle = E(glint, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 0, life = { 0.35, 0.5 }, speed = { 0, 0 }, size = 0.7, spread = 0, light = 0.8, bright = 1.8 })
		local glintOn = false
		H.job(a, function(self, f)
			local on = (f.t % EVERY) < SWEEP
			if on ~= glintOn then
				glintOn = on
				glint.Transparency = if on then 0.1 else 1
				if not on then
					twinkle:Emit(1) -- (a star where the glint leaves the lens)
				end
			end
		end)

		-- the blade of grass you chew: a long one out of the corner of your mouth and a short one under it, wagging;
		-- each bite bursts grass from your mouth
		local mouthCF = perFrame(function(f): CFrame
			local chew = math.sin(f.t * 8)
			return faceCF(f) * CFrame.new(0.22, -0.42 + 0.03 * chew, 0.04) * CFrame.Angles(0, 0, math.rad(5) * chew)
		end)
		local long = H.blade(a.body, { Vector3.new(0, 0, 0), Vector3.new(0.42, 0.05, -0.12), Vector3.new(0.8, -0.03, -0.18), Vector3.new(1.06, -0.25, -0.16) }, 0.2, 0.05, 0.05, CHEW, Enum.Material.SmoothPlastic, nil, Vector3.zAxis)
		local short = H.blade(a.body, { Vector3.new(0, -0.02, 0), Vector3.new(0.28, -0.13, -0.1), Vector3.new(0.48, -0.34, -0.12), Vector3.new(0.6, -0.6, -0.08) }, 0.15, 0.04, 0.05, CHEW_L, Enum.Material.SmoothPlastic, nil, Vector3.zAxis)
		for _, pc in long do
			local part = pc[1] :: BasePart
			part.Reflectance = 0
		end
		for _, pc in short do
			local part = pc[1] :: BasePart
			part.Reflectance = 0
			H.detail(a, part)
		end
		H.rig(a, mouthCF, long)
		H.rig(a, mouthCF, short)
		local mouth = K.piece(a.body, Vector3.new(0.35, 0.35, 0.35))
		K.move(a, mouth, mouthCF)
		local chompFx = H.layer(a, LOOP, "Chomp", mouth, false, 0.8)

		-- a gold halo over your horns, sparkling; it drops in when the aura forms
		local haloPart = K.piece(a.body, Vector3.new(1.8, 0.3, 1.8))
		K.move(a, haloPart, function(f)
			local k = ease((f.t - a.born - 1) / 0.6)
			-- (its front edge tilted up, so it reads as a ring from in front and below, not a line)
			return CFrame.new(f.head + Vector3.new(0, 1.3 + 0.07 * math.sin(f.t * 1.7) + 3 * (1 - k), 0)) * f.yaw * CFrame.Angles(math.rad(14), 0, 0)
		end)
		local haloBeams = K.beamRing(haloPart, 0.85, 0.15, K.seq(GOLD_L, GOLD, GOLD_L), 1.9, 0.05, 18, false)
		for _, b in haloBeams do
			b.LightEmission = 0.55
		end
		local haloSparkle = H.layer(a, LOOP, "Sparkle", haloPart, false, 0.6)
		setRate(a, haloSparkle, 3)

		-- the spirit horns: the same golden ram horns, giant, behind you like wings, with a gold glow on them (a Highlight
		-- on that prop alone), gold wisps and sparkles rising off them and a soft light behind them (seen from the front
		-- only). They rise out of the ground when the aura forms, breathe and sway slowly, and flash on the heartbeat.
		local SPIRIT = 11
		local spirit = H.prop(a.body, "gm_horns", SPIRIT)
		local ss = H.propSize("gm_horns", SPIRIT)
		local spiritCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.3) / 1.1)
			local rise = f.head.Y - f.root.Position.Y -- (the top of your head over your root)
			local y = rise + 0.6 - ss.Y * 0.25 + 0.15 * math.sin(f.t * 1.2) - 7.5 * (1 - k)
			return f.root * CFrame.new(0, y, ss.Z * 0.5 + 0.9) * CFrame.Angles(math.rad(-2) + math.rad(1.5) * math.sin(f.t * 0.9), math.rad(4) * math.sin(f.t * 0.55), 0)
		end)
		K.move(a, spirit, spiritCF)
		local glow: Highlight? = nil
		if spirit:IsA("MeshPart") then
			local hl = Instance.new("Highlight")
			hl.Adornee = spirit
			hl.FillColor = GOLD_L
			hl.FillTransparency = 0.68
			hl.OutlineColor = rgb(255, 246, 205)
			hl.OutlineTransparency = 0.25
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = a.body
			H.detail(a, hl)
			glow = hl
		end
		local spiritSparkle = H.layer(a, LOOP, "Sparkle", spirit, false, 1.1)
		setRate(a, spiritSparkle, 6)
		local spiritWisps = E(spirit, { tex = T.wisp, colors = K.seq(WHITE, GOLD_L, GOLD), rate = 4, life = { 0.8, 1.2 }, speed = { 1, 2 }, size = 1.4, accel = Vector3.new(0, 1.5, 0), spread = 10, light = 0.5, bright = 1.2, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.3, 0.45, 1, 1), sizeSeq = ns(0, 0.7, 0.4, 1.4, 1, 0.3) })
		K.addEmitter(a, spiritWisps)
		H.detail(a, spiritWisps)
		local backlight, _, backGuis = H.plate(a.body, 13, FX.glow, GOLD, 0.62, false, 1)
		K.move(a, backlight, function(f)
			return spiritCF(f) * CFrame.new(0, ss.Y * 0.1, ss.Z * 0.5 + 0.3) * CFrame.Angles(math.rad(-90), 0, 0)
		end)
		H.detail(a, backGuis[1])

		-- the column of golden light (faint over your body so you still show, strongest above your head, dimmer while you
		-- run), golden motes falling down it
		local pillar = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, pillar, function(f)
			return CFrame.new(f.feet)
		end)
		-- (along its 26 studs: faint up to your head, then clear above it, fading out high up; `v` 1 standing)
		local function colSeq(v: number): NumberSequence
			return ns(0, 1, 0.04, 1 - 0.12 * v, 0.18, 1 - 0.14 * v, 0.3, 1 - 0.32 * v, 0.6, 1 - 0.28 * v, 1, 1)
		end
		local c0, c1 = H.att(pillar, Vector3.new(0, 0.2, 0)), H.att(pillar, Vector3.new(0, 26, 0))
		local colA = H.beam(c0, c1, { colors = K.seq(GOLD, GOLD_L, WHITE), w0 = 4.6, w1 = 2.4, trans = colSeq(1), tex = T.stripBody, texMode = Enum.TextureMode.Stretch, texSpeed = 0.4, light = 0.45, bright = 0.8 })
		local colB = H.beam(c0, c1, { colors = K.seq(GOLD_L, WHITE), w0 = 1.5, w1 = 0.8, trans = colSeq(1), tex = T.energy, texMode = Enum.TextureMode.Stretch, texSpeed = 0.9, light = 0.5, bright = 0.9 })
		H.detail(a, colB)
		local lastV = -1
		H.job(a, function(self, f)
			local v = 0.35 + 0.65 * f.calm
			if math.abs(v - lastV) > 0.03 then
				lastV = v
				local seq = colSeq(v)
				colA.Transparency = seq
				colB.Transparency = seq
			end
		end)
		local sky = K.piece(a.body, Vector3.new(3, 0.6, 3))
		K.move(a, sky, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 15, 0))
		end)
		local motes = H.layer(a, LOOP, "Motes", sky, false, 2)
		setRate(a, motes, 12)

		-- wool-white puffs round your feet (the goat's fleece), gold sparkles round you and a ring of them orbiting your
		-- waist, soft gold wisps rising from behind you (behind, so they frame you rather than cover you)
		local woolRing = H.feetPiece(a, Vector3.new(5, 0.8, 5), 0.5)
		local wool = H.layer(a, LOOP, "Wool", woolRing, false, 1)
		setRate(a, wool, 5)
		local body = K.bodyBox(a, Vector3.new(3.6, 5, 3), 0)
		local sparkle = H.layer(a, LOOP, "Sparkle", body, false, 0.8)
		setRate(a, sparkle, 4)
		local orbit = K.piece(a.body, Vector3.new(6.4, 0.3, 6.4))
		K.move(a, orbit, function(f)
			return CFrame.new(f.root.Position) * CFrame.Angles(math.rad(8), f.t * 0.9, 0)
		end)
		local orbitSparkle = H.layer(a, LOOP, "Sparkle", orbit, false, 0.7)
		for _, e in orbitSparkle do
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			e.LockedToPart = true
			H.detail(a, e)
		end
		setRate(a, orbitSparkle, 8)
		local behind = K.piece(a.body, Vector3.new(3.4, 4.6, 0.8))
		K.move(a, behind, function(f)
			return f.root * CFrame.new(0, 0.2, 0.75)
		end)
		local wisps = E(behind, { tex = T.wisp, colors = K.seq(WHITE, GOLD_L, GOLD), rate = 6, life = { 0.6, 1 }, speed = { 1.5, 2.6 }, size = 1.3, accel = Vector3.new(0, 2, 0), spread = 8, light = 0.45, bright = 1.15, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.25, 0.4, 1, 1), sizeSeq = ns(0, 0.6, 0.4, 1.3, 1, 0.3) })
		K.addEmitter(a, wisps)
		H.detail(a, wisps)
		-- grass and gold kicked up as you walk
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.3, 1.2), 0.3)
		K.addEmitter(a, E(kick, { tex = BFX.strand, colors = K.seq(GRASS_L, GRASS), rate = 10, life = { 0.5, 0.8 }, speed = { 3, 6 }, size = 0.55, accel = Vector3.new(0, -25, 0), spin = 300, spread = 45, light = 0, bright = 1 }), true)
		K.addEmitter(a, E(kick, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 7, life = { 0.5, 0.9 }, speed = { 1, 3 }, size = 0.6, accel = Vector3.new(0, 1, 0), spread = 60, light = 0.7, bright = 1.3 }), true)

		-- the Graze at work: while you walk you bite every 0.75 s (a bite the server reports near you lands at once and sets
		-- the beat); each bite snaps the gold ring in and bursts grass at your mouth; the grass storms while you walk
		local lastBite, chompAt, wantBite = -10, -10, false
		local walkingNow, chompShown = false, false
		local function bite(t: number)
			chompAt = t
			emit(chompFx, 6)
		end
		H.job(a, function(self, f)
			local walking = f.calm < 0.5
			if walking ~= walkingNow then
				walkingNow = walking
				setRate(a, grass, if walking then 38 else 18)
			end
			if wantBite then
				wantBite = false
				if f.t - lastBite > 0.3 then
					bite(f.t)
				end
				lastBite = f.t
			elseif walking and f.t - lastBite >= GRAZE_EVERY then
				lastBite = f.t
				bite(f.t)
			end
			local k = (f.t - chompAt) / 0.32
			if k >= 0 and k <= 1 then
				local s = GRAZE_R * (1 - 0.85 * smooth(k)) * 2 / 0.92
				chomp.Size = Vector3.new(s, 0.05, s)
				for _, img in chompImgs do
					img.ImageTransparency = 0.15 + 0.85 * k * k
				end
				chompShown = true
			elseif chompShown then
				chompShown = false
				for _, img in chompImgs do
					img.ImageTransparency = 1
				end
			end
		end)
		H.gimmick(a, { graze = true }, 9, function()
			wantBite = true
		end)

		K.outline(a, GOLD, 0.25)
		K.light(a, GOLD, 1, 16)
		H.lightJob(a, 0.1)
		K.feetTrail(a, K.seq(GOLD_L, GOLD, GRASS))

		-- the heartbeat: a gold ring races out over the ground, the spirit horns flash and sparkle, the light swells
		local throb = 0
		H.every(a, 1.8, function(self, f)
			if f.ground > 0.3 then
				K.pulse(f.feet, 2, 17, GOLD, 1, 0.2)
			end
			self.lightKick = 1.6
			throb = 1
			emit(spiritSparkle, 4)
		end)
		local lastThrob = -1
		H.job(a, function(self, f)
			throb *= 0.9
			if glow and math.abs(throb - lastThrob) > 0.01 then
				lastThrob = throb
				local k = math.min(throb, 1.6)
				glow.FillTransparency = math.max(0, 0.68 - 0.22 * k)
				glow.OutlineTransparency = math.max(0, 0.25 - 0.25 * k)
			end
		end)

		-- the entrance: the horns drop on, the shades slide down, the spirit horns rise and the halo drops in (their
		-- movers above); rings race out, the bite ring snaps in, grass, wool and motes burst; as the spirit horns arrive
		-- they flash and sparkle
		local settleAt = math.huge
		H.job(a, function(self, f)
			if f.t >= settleAt then
				settleAt = math.huge
				emit(spiritSparkle, 18)
				emit(hornSparkle, 6)
				throb = 1.6
				self.lightKick = 2.2
			end
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 26, GOLD, 1.2, 0.05)
			K.pulse(feet, 1, 17, GRASS_L, 0.85, 0.15)
			K.pulse(feet, 1, 10, WHITE, 0.55, 0.3)
			emit(grass, 36)
			emit(chompFx, 10)
			emit(wool, 8)
			emit(motes, 12)
			chompAt = os.clock()
			settleAt = os.clock() + 1.05
			self.lightKick = 2.6
		end
		return a
	end
end
