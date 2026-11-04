-- ULTIMATE GARDENER (Legendary). The card: a golden watering can pouring liquid gold. Gimmick: Midas Touch, every 20th
-- clump you uncover is a Golden mutation. Built from ForgeGUI props (the ornate golden watering can ug_can, the golden
-- vine wings ug_wings), the ForgeGUI sunburst emblem and the VFX Forge layers of Loop_UltimateGardener (Pour, Petals,
-- Pollen, Rays, Midas):
--   - the golden watering can circling you wide at shoulder height, glinting, tipped to pour a thick glossy stream of
--     liquid gold (an amber-gold beam round a white-hot flowing core) back in onto the emblem, where it splashes, a
--     gold puddle ripples and 3D golden shoots with green leaves pop up and sink again (the can leaves a ring of them
--     as it goes). When Midas Touch lands it tips right over and gushes, a ring of shoots bursts up and a gold wave
--     washes up over your body
--   - the golden vine wings (one ForgeGUI pair, about 2.5x your height across) rising from your back, flapping
--     slowly, liquid gold dripping off them, sparkles
--   - a sunflower halo high up behind your head, green leaves fanning out behind its petals, turning in sun rays
--   - the ground: the sunburst emblem over an amber shade, a pool of liquid gold over its seed heart under your feet,
--     three crisp line rings (amber outlines round the pool and the rim, gold outside), liquid-gold ripples spreading
--     out over it
--   - light from above: a warm god-ray column standing on you with gold motes falling through it; gold petals, pollen
-- With your own follow camera behind you, the wings, the halo and the can (in your back half) go a little see-through.
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local LOOP = "Loop_UltimateGardener"
	local SUN = rgb(255, 200, 60)
	local SUN_L = rgb(255, 232, 150)
	local GOLD = rgb(255, 184, 40)
	local AMBER = rgb(225, 125, 20) -- the shading, so the gold isn't one yellow blob
	local BRONZE = rgb(150, 80, 15) -- the darkest amber (the sprouts' stems)
	local LEAF = rgb(80, 165, 55) -- the green leaves (sprouts, the halo), so the gold isn't all one yellow
	local LEAF_L = rgb(140, 210, 80)
	local UPR = CFrame.Angles(0, 0, math.rad(90)) -- (stands a cylinder up)
	-- the watering can. Its frame: -Z is where the spout points, +Y is up; CAN_TURN turns the prop into that frame.
	-- (the v6a shots showed the spout at the prop's -Z end, the gold leaving the rose: kept)
	local CAN = 2.6 -- its longest side (studs; 28% smaller than v6b's, which hid you up close)
	local CAN_TURN = CFrame.identity
	local SPOUT = Vector3.new(0, 0.1, -0.46) * CAN -- the spout's rose (where the gold leaves), in the can's frame
	local RISE = math.rad(30) -- the spout rises this steeply out of the can: the stream leaves the rose along it
	local TILT = math.rad(40) -- the can leans forward this far to pour
	-- the spout points ahead (the way the can travels) and back in towards you, so from the wide orbit the gold still
	-- lands on the emblem, about 4.3 studs out (90 deg = straight ahead, 180 = straight at you)
	local LEAD = math.rad(135)
	local ORBIT = 5.8 -- the can's distance from you (round a point a little in front of you; +2 on v6b, clear of you)
	local CAN_Y = 1.6 -- its height over your middle: shoulder height
	local HURRY = math.rad(135) -- where on its round the can moves fastest (behind you on your left; 0 = your right)
	-- the wings: one prop, both wings spread along X, their roots meeting at the bottom middle, facing -Z
	local WSPAN = 12.9 -- their span (1.4x v6b's)
	local WING_TURN = CFrame.Angles(0, math.pi, 0) -- (turned round so their face looks back, at the follow camera)
	-- the golden sprouts where the gold lands
	local NSPROUT, SPROUT_LIFE, SPROUT_EVERY = 6, 2.6, 0.45
	local FADE = 0.3 -- how see-through the big pieces go for your own camera behind you (mild: they're also kept off its line)

	-- a base worked out once per frame (several pieces ask for it)
	local function once(base: (any) -> CFrame): (any) -> CFrame
		local lastT, last = -1, CFrame.identity
		return function(f)
			if f.t ~= lastT then
				lastT = f.t
				last = base(f)
			end
			return last
		end
	end
	-- your own follow camera is behind you
	local function camBehind(f): boolean
		if f.player == nil or f.player ~= H.player then
			return false
		end
		local cam = workspace.CurrentCamera
		return cam ~= nil and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3
	end

	return function()
		local a = H.aura(H.RANK.Legendary, SUN)
		local tipAt = -100 -- (os.clock when the can last tipped right over: Midas Touch)
		local waveAt = -100 -- (os.clock when the last gold wave started up your body)
		-- how far the can is tipped over `t`: 0 pouring, 1 tipped right over (up fast, held, then settling back)
		local function tipped(t: number): number
			local k = (t - tipAt) / 1.7
			if k < 0 or k >= 1 then
				return 0
			end
			if k < 0.12 then
				return smooth(k / 0.12)
			end
			if k < 0.5 then
				return 1
			end
			return 1 - smooth((k - 0.5) / 0.5)
		end

		-- THE GROUND: an amber shade, the sunburst emblem (grows in, turning slowly), a pool of liquid gold over its
		-- red-brown seed heart under your feet (it read as a red disc), three crisp line rings turning opposite ways
		-- (amber round the pool and the emblem's rim: its outlines; gold outside), and liquid-gold ripples spreading out
		-- over the emblem from your feet
		H.glowDisc(a, 12.5, BFX.glow, AMBER, 0.6, 0, 0.07, 1)
		H.sigil(a, 10.5, T.embUltimateGardener, WHITE, 0.2, 0.05, 0.12, 0.9, 1.05)
		H.glowDisc(a, 4.2, BFX.glow, GOLD, 0, 0, 0.135, 1)
		H.glowRing(a, 1.6, AMBER, 0.3, 0.2, 0.15, 1)
		H.glowRing(a, 5.3, AMBER, 0.35, -0.1, 0.16, 1.05)
		H.glowRing(a, 6.2, GOLD, 0.45, 0.07, 0.15, 1.1)
		local ripples = {}
		for i = 1, 3 do
			local p, imgs = H.plate(a.model, 2.2, T.ringCrisp, GOLD, 1, false, 1.15)
			local lift = 0.17 + i * 0.004
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(0, lift, 0))
			end)
			ripples[i] = { part = p, img = imgs[1] }
		end
		local RIPPLE, ripHidden = 2.4, false
		H.job(a, function(self, f)
			if self.lowNow then
				if not ripHidden then
					ripHidden = true
					for _, r in ripples do
						r.img.ImageTransparency = 1
					end
				end
				return
			end
			ripHidden = false
			for i, r in ripples do
				-- (each ring: from 1 stud out to the emblem's rim in 2.4 s, slowing as it goes, fading out)
				local k = ((f.t - self.born) / RIPPLE + (i - 1) / 3) % 1
				local d = 2.2 + 9.5 * (1 - (1 - k) ^ 2)
				r.part.Size = Vector3.new(d, 0.05, d)
				r.img.ImageTransparency = if k < 0.12 then 1 - 0.6 * (k / 0.12) else 0.4 + 0.6 * ((k - 0.12) / 0.88) ^ 1.4
			end
		end)

		-- THE CAN: circling you at shoulder height, spout out and ahead, leaning forward to pour; it swoops down from
		-- over your head when the aura forms. It lingers at your front right (in view, clear of your body) and hurries
		-- past behind you.
		local canCF = once(function(f): CFrame
			local life = f.t - a.born
			local k = ease((life - 0.05) / 0.85)
			local u = life * 0.5 + 5
			local th = u + 0.5 * math.sin(u - HURRY)
			local base = CFrame.new(f.root.Position) * f.yaw
			local pos = (base * CFrame.new(math.cos(th) * ORBIT * k, CAN_Y + 0.18 * math.sin(f.t * 1.4) + 4 * (1 - k), -0.5 + math.sin(th) * ORBIT * k)).Position
			local out = th + LEAD
			local dir = base:VectorToWorldSpace(Vector3.new(math.cos(out), 0, math.sin(out)))
			return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-(TILT + math.rad(85) * tipped(f.t)), 0, 0)
		end)
		local can = H.prop(a.body, "ug_can", CAN)
		K.move(a, can, function(f)
			return canCF(f) * CAN_TURN
		end)
		local shine = E(can, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 2, life = { 0.3, 0.5 }, speed = { 0, 0.1 }, size = 0.8, spread = 180, light = 0.9, bright = 1.5 })
		K.addEmitter(a, shine)
		H.detail(a, shine)
		-- the spout's rose: its -Z runs along the outflow (the Pour layer's drops leave along it)
		local spoutCF = once(function(f): CFrame
			return canCF(f) * CFrame.new(SPOUT) * CFrame.Angles(RISE, 0, 0)
		end)
		local spout = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
		K.move(a, spout, spoutCF)
		local pour = H.layer(a, LOOP, "Pour", spout)
		local midasCan = H.layer(a, LOOP, "Midas", can)
		-- where the stream lands: a little out past the rose, on the ground
		local landPos = Vector3.zero
		local landCF = once(function(f): CFrame
			local s = spoutCF(f)
			local out = s.LookVector
			local p = s.Position
			landPos = Vector3.new(p.X + out.X * 1.5, f.feet.Y, p.Z + out.Z * 1.5)
			return CFrame.new(landPos + Vector3.new(0, 0.05, 0))
		end)
		local land = K.piece(a.model, Vector3.new(1.4, 0.2, 1.4))
		K.move(a, land, landCF)
		-- the stream of liquid gold: a thick amber-gold beam arcing from the rose down onto the emblem, a narrow white-hot
		-- core flowing down its middle (detail), so it reads as glossy liquid rather than a light streak
		local from = H.att(spout, Vector3.zero)
		from.CFrame = CFrame.Angles(0, math.pi / 2, 0) -- (its axis, local X, runs along the outflow)
		local to = H.att(land, Vector3.zero)
		to.CFrame = CFrame.Angles(0, 0, -math.pi / 2) -- (its axis points down: the stream falls into the ground)
		local W_OUT0, W_OUT1, W_CORE0, W_CORE1 = 0.62, 0.42, 0.24, 0.15
		local stream = H.beam(from, to, { colors = K.seq(GOLD, AMBER, GOLD), w0 = W_OUT0, w1 = W_OUT1, light = 0.25, bright = 1.25, segments = 16, curve0 = 0.9, curve1 = 1.6 })
		local core = H.beam(from, to, { colors = K.seq(WHITE, rgb(255, 248, 210), SUN_L), w0 = W_CORE0, w1 = W_CORE1, trans = ns(0, 0.05, 1, 0.25), light = 0.4, bright = 1.3, segments = 16, curve0 = 0.9, curve1 = 1.6, tex = T.energy, texLen = 1.4, texSpeed = 2.5, zoff = 0.03 })
		H.detail(a, core)
		-- where it lands: gold droplets splashing up, glints (detail), a gold puddle
		local drops = E(land, { tex = BFX.dot, colors = K.seq(SUN_L, GOLD), rate = 7, life = { 0.3, 0.5 }, speed = { 2, 3.5 }, size = 0.2, accel = Vector3.new(0, -25, 0), spread = 45, light = 0.35, bright = 1.3 })
		K.addEmitter(a, drops)
		local splash = E(land, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 3, life = { 0.3, 0.5 }, speed = { 1, 2.5 }, size = 0.5, spread = 60, light = 0.8, bright = 1.4 })
		K.addEmitter(a, splash)
		H.detail(a, splash)
		local puddle = H.plate(a.model, 2, BFX.glow, GOLD, 0.45, false, 1)
		K.move(a, puddle, function(f)
			return landCF(f) * CFrame.new(0, 0.03, 0)
		end)
		-- gold ripples running out from where it lands (once the can is in place; not for far players or phones)
		H.every(a, 0.75, function(self, f)
			if not self.lowNow and f.t - self.born > 1 then
				K.pulse(landCF(f).Position, 0.4, 3.4, GOLD, 0.65, 0.35)
			end
		end)

		-- THE GOLDEN SPROUTS: six 3D shoots (a gold stem, two green leaves, a pointed gold bud; 1.9 studs tall) that
		-- pop up out of the emblem where the stream lands, with a glint, and sink back 2.6 s later, so the can leaves a
		-- ring of them as it goes. Out of use they wait hidden under your feet. (Not for far players or phones.)
		local sprouts = {}
		for i = 1, NSPROUT do
			local s = { at = -100, pos = Vector3.zero, yaw = 0, shown = true, parts = {} }
			sprouts[i] = s
			local base = once(function(f): CFrame
				local age = f.t - s.at
				if age < 0 or age >= SPROUT_LIFE then
					return CFrame.new(f.feet - Vector3.new(0, 3, 0))
				end
				local up = if age < 0.3 then ease(age / 0.3) else 1 - smooth((age - (SPROUT_LIFE - 0.5)) / 0.5)
				return CFrame.new(s.pos + Vector3.new(0, 1.9 * (up - 1), 0)) * CFrame.Angles(0, s.yaw + 0.5 * age, 0)
			end)
			local pieces = {
				{ H.cyl(a.model, 1.6, 0.18, BRONZE:Lerp(GOLD, 0.6), Enum.Material.SmoothPlastic, 0.15), CFrame.new(0, 0.78, 0) * UPR },
				{ H.ellipsoid(a.model, Vector3.new(1.05, 0.12, 0.46), LEAF), CFrame.new(0.48, 0.92, 0) * CFrame.Angles(0, 0, math.rad(28)) },
				{ H.ellipsoid(a.model, Vector3.new(1.05, 0.12, 0.46), LEAF_L), CFrame.new(-0.48, 1.2, 0) * CFrame.Angles(0, 0, math.rad(-28)) },
				{ H.ellipsoid(a.model, Vector3.new(0.3, 0.62, 0.3), SUN), CFrame.new(0, 1.75, 0) },
			}
			H.rig(a, base, pieces)
			for _, pc in pieces do
				table.insert(s.parts, pc[1])
			end
		end
		local nextSprout = 1
		local function sproutAt(pos: Vector3, t: number)
			local s = sprouts[nextSprout]
			nextSprout = nextSprout % NSPROUT + 1
			s.at = t
			s.pos = pos
			s.yaw = math.random() * math.pi * 2
		end
		H.every(a, SPROUT_EVERY, function(self, f)
			if not self.lowNow and f.t - self.born > 1 then
				local p = landCF(f).Position
				sproutAt(Vector3.new(p.X + (math.random() - 0.5) * 0.7, f.feet.Y, p.Z + (math.random() - 0.5) * 0.7), f.t)
				splash:Emit(1)
			end
		end)
		H.job(a, function(self, f)
			for _, s in sprouts do
				local alive = f.t >= s.at and f.t - s.at < SPROUT_LIFE
				if alive ~= s.shown then
					s.shown = alive
					for _, p in s.parts do
						p.LocalTransparencyModifier = if alive then 0 else 1
					end
				end
			end
		end)

		-- THE SUNFLOWER HALO: high up and well back from your head (clear of your cap from the front), turning inside
		-- a ring of sun rays; both grow in when the aura forms. From behind, the flower sits in front of its rays.
		local rays, rayImgs, rayGuis = H.plate(a.body, 5, T.sigSun, SUN, 0.45, true, 1.1)
		local flower, flowerImgs = H.plate(a.body, 3.1, T.sunflower, WHITE, 0, true, 1.05)
		H.detail(a, rayGuis[1], rayGuis[2])
		local sunGlints = E(flower, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 2, life = { 0.4, 0.7 }, speed = { 0, 0.3 }, size = 0.6, spread = 180, light = 0.9, bright = 1.5 })
		K.addEmitter(a, sunGlints)
		H.detail(a, sunGlints)
		local function haloAt(f, back: number): Vector3
			return (f.headCF * CFrame.new(0, 2.25 + 0.08 * math.sin(f.t * 1.3), back)).Position
		end
		K.move(a, rays, function(f)
			return H.facing(haloAt(f, 2.95), f, -f.t * 0.2)
		end)
		local flowerCF = once(function(f): CFrame
			return H.facing(haloAt(f, 3.05), f, f.t * 0.3)
		end)
		K.move(a, flower, flowerCF)
		-- six green leaves fanning out from behind the flower's petals, turning with it (green in the gold)
		local haloLeaves = {}
		for k = 1, 6 do
			local leaf = H.ellipsoid(a.body, Vector3.new(1.05, 0.08, 0.44), if k % 2 == 0 then LEAF else LEAF_L)
			table.insert(haloLeaves, { leaf, CFrame.Angles(0, (k - 0.5) / 6 * math.pi * 2, 0) * CFrame.new(1.85, -0.04, 0) })
		end
		H.rig(a, flowerCF, haloLeaves)

		-- THE WINGS: the ForgeGUI golden vine wings, their roots on your back between your shoulder blades (owner, 4 Nov:
		-- "fix the model with the wing so its attached to the back of my body": they hung 1.6 studs off you), leaning back
		-- a little, flapping slowly (they tip back and forth, rise and fall, and spread and close a
		-- little); they grow out of your back when the aura forms. Liquid gold drips off them.
		local wings = H.prop(a.body, "ug_wings", WSPAN)
		-- (4 Nov: the wing mesh is one-sided, so from behind (your own follow camera) it vanished: drawn from both sides)
		pcall(function()
			(wings :: any).DoubleSided = true
		end)
		local ws = H.propSize("ug_wings", WSPAN)
		local wingK, flap = 0, 0
		local wingCF = once(function(f): CFrame
			wingK = math.max(0.05, ease((f.t - a.born - 0.2) / 0.8))
			flap = math.sin(f.t * 1.5)
			return f.root * CFrame.new(0, 0.95 + 0.12 * flap, 0.7) * CFrame.Angles(math.rad(6) + math.rad(5) * flap, 0, 0) * CFrame.new(0, (ws.Y * 0.5 - 0.55) * wingK, 0) * WING_TURN
		end)
		K.move(a, wings, wingCF)
		-- (GUESS: the wing tips at the top outer corners, the lowest feathers lower in; check the drips leave the wings)
		for _, at in { Vector3.new(0.46, 0.3, 0), Vector3.new(-0.46, 0.3, 0), Vector3.new(0.34, -0.22, 0), Vector3.new(-0.34, -0.22, 0) } do
			local tipAtt = H.att(wings, Vector3.new(at.X * ws.X, at.Y * ws.Y, 0))
			local drip = E(tipAtt, { tex = BFX.dot, colors = K.seq(SUN_L, GOLD, AMBER), rate = 2.5, life = { 0.7, 1 }, speed = { 0, 0.3 }, size = 0.24, accel = Vector3.new(0, -14, 0), spread = 10, light = 0.55, bright = 1.4, dir = Enum.NormalId.Bottom, orient = Enum.ParticleOrientation.FacingCameraWorldUp, squash = ns(0, -0.2, 0.4, -0.7, 1, -0.4) })
			K.addEmitter(a, drip)
			if at.Y < 0 then
				H.detail(a, drip)
			end
		end
		local wingBox = K.piece(a.body, Vector3.new(ws.X * 0.8, ws.Y * 0.7, 0.4))
		K.move(a, wingBox, wingCF)
		local sparkle = E(wingBox, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 4, life = { 0.5, 0.9 }, speed = { 0.1, 0.4 }, size = 0.5, spread = 180, light = 0.8, bright = 1.5 })
		K.addEmitter(a, sparkle)
		H.detail(a, sparkle)

		-- the halo and the wings grow in as the aura forms; then the wings' spread breathes with the flap (not for far
		-- players or phones: there they hold still)
		local settled, still = false, false
		H.job(a, function(self, f)
			local life = f.t - self.born
			if life > 1.4 then
				if not settled then
					settled = true
					rays.Size = Vector3.new(5, 0.05, 5)
					flower.Size = Vector3.new(3.1, 0.05, 3.1)
				end
				if self.lowNow then
					if not still then
						still = true
						wings.Size = ws
					end
				else
					still = false
					wings.Size = Vector3.new(ws.X * (0.95 + 0.05 * flap), ws.Y, ws.Z)
				end
				return
			end
			settled = false
			local k = math.max(0.02, ease((life - 0.15) / 0.8))
			rays.Size = Vector3.new(5 * k, 0.05, 5 * k)
			flower.Size = Vector3.new(3.1 * k, 0.05, 3.1 * k)
			wings.Size = ws * wingK
		end)
		-- your own follow camera behind you: the wings and the halo go a little see-through, and the can while it's in
		-- your back half (mild: they're also kept off the camera's line)
		local fadeOn, canFaded = false, false
		H.job(a, function(self, f)
			local behind = camBehind(f)
			if behind ~= fadeOn then
				fadeOn = behind
				wings.LocalTransparencyModifier = if behind then FADE else 0
				for _, img in rayImgs do
					img.ImageTransparency = if behind then 0.45 + 0.55 * FADE else 0.45
				end
				for _, img in flowerImgs do
					img.ImageTransparency = if behind then FADE else 0
				end
			end
			local cf = behind and (can.CFrame.Position - f.root.Position):Dot(f.root.LookVector) < 0.6
			if cf ~= canFaded then
				canFaded = cf
				can.LocalTransparencyModifier = if cf then FADE else 0
			end
		end)

		-- LIGHT FROM ABOVE: a warm god-ray column standing on you, a soft glow texture stretched up its length (it runs
		-- from 6 studs underground to 22 up, so it's brightest from your shoulders to 14 studs up and fades out at the
		-- top), a narrower shaft in it over your head, gold motes falling slowly down through it and rays of light
		local column = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, column, function(f)
			return CFrame.new(f.feet)
		end)
		local colLow, colTop = H.att(column, Vector3.new(0, -6, 0)), H.att(column, Vector3.new(0, 22, 0))
		H.beam(colLow, colTop, { colors = K.seq(GOLD, SUN, SUN_L), w0 = 6, w1 = 4, trans = NumberSequence.new(0.5), tex = K.FX.glow, texMode = Enum.TextureMode.Stretch, texLen = 1, light = 0.5, bright = 1.1 })
		local shaft = H.beam(H.att(column, Vector3.new(0, 3, 0)), colTop, { colors = K.seq(SUN_L, SUN), w0 = 1.8, w1 = 1.3, trans = NumberSequence.new(0.45), tex = K.FX.glow, texMode = Enum.TextureMode.Stretch, texLen = 1, light = 0.5, bright = 1.2 })
		H.detail(a, shaft)
		local sky = K.piece(a.body, Vector3.new(3, 0.4, 3))
		K.move(a, sky, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 15, 0)) * CFrame.Angles(0, f.t * 0.15, 0)
		end)
		K.addEmitter(a, E(sky, { tex = BFX.dot, colors = K.seq(SUN_L, GOLD), rate = 6, life = { 5, 6.5 }, speed = { 1.6, 2.4 }, size = 0.16, accel = Vector3.new(0, -0.15, 0), dir = Enum.NormalId.Bottom, spread = 8, light = 0.3, bright = 1.2 }))
		H.layer(a, LOOP, "Rays", sky)
		-- gold petals and pollen round you; the Midas Touch's glints; petals kicked up when you run
		local around = K.bodyBox(a, Vector3.new(5, 5.5, 5), 0)
		local petals = H.layer(a, LOOP, "Petals", around)
		H.layer(a, LOOP, "Pollen", around)
		local midasBody = H.layer(a, LOOP, "Midas", around, false, 1.2)
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.2, 1.2), 0.15)
		K.addEmitter(a, E(kick, { tex = BFX.petal, colors = K.seq(SUN_L, SUN, AMBER), rate = 9, life = { 0.6, 1 }, speed = { 2, 4 }, size = 0.5, accel = Vector3.new(0, -6, 0), spin = 200, spread = 50, light = 0.3 }), true)

		-- THE BODY: a gold-to-amber glow, a mown trail, an amber outline (a darker edge round the gold), a warm light
		H.shell(a, K.seq(SUN_L, GOLD, AMBER), 5, 0.8)
		K.feetTrail(a, K.seq(GOLD, AMBER, BRONZE))
		local hl = K.outline(a, AMBER, 0.45)
		K.light(a, SUN, 1.1, 14)
		H.lightJob(a, 0.08)

		-- THE GOLD WAVE (Midas Touch): a ring of light and a gold glow rising from your feet to over your head, your
		-- body turning gold behind it and back
		local waveRing, waveRingImgs = H.plate(a.body, 3.8, T.ringCrisp, SUN_L, 1, true, 1.2)
		local waveGlow, waveGlowImgs = H.plate(a.body, 3.4, BFX.glow, GOLD, 1, true, 1)
		local WAVE = 0.9
		local function waveCF(f): CFrame
			local p = math.clamp((f.t - waveAt) / WAVE, 0, 1)
			return CFrame.new(f.root.Position + Vector3.new(0, -2.6 + 5.6 * smooth(p), 0)) * CFrame.Angles(0, f.t, 0)
		end
		K.move(a, waveRing, waveCF)
		K.move(a, waveGlow, waveCF)
		local waving = false
		H.job(a, function(self, f)
			local p = (f.t - waveAt) / WAVE
			if p >= 0 and p < 1.6 then
				waving = true
				local edge = if p < 1 then 1 - smooth((p - 0.75) / 0.25) else 0
				for _, img in waveRingImgs do
					img.ImageTransparency = 1 - 0.85 * edge
				end
				for _, img in waveGlowImgs do
					img.ImageTransparency = 1 - 0.5 * edge
				end
				local g = if p < 0.6 then smooth(p / 0.6) else 1 - smooth((p - 0.6) / 1)
				if hl then
					hl.FillColor = GOLD
					hl.FillTransparency = 0.92 - 0.5 * g
				end
			elseif waving then
				waving = false
				for _, img in waveRingImgs do
					img.ImageTransparency = 1
				end
				for _, img in waveGlowImgs do
					img.ImageTransparency = 1
				end
				if hl then
					hl.FillColor = AMBER
					hl.FillTransparency = 0.92
				end
			end
		end)

		-- while the can is tipped over the stream runs thicker and gold gushes out of the rose
		local width, gushed = -1, 0
		H.job(a, function(self, f)
			local tp = tipped(f.t)
			local g = 1 + 0.9 * tp
			if math.abs(g - width) > 0.01 then
				width = g
				stream.Width0, stream.Width1 = W_OUT0 * g, W_OUT1 * g
				core.Width0, core.Width1 = W_CORE0 * g, W_CORE1 * g
			end
			if tp > 0.6 and f.t - gushed > 0.05 then
				gushed = f.t
				for _, e in pour do
					e:Emit(2)
				end
			end
		end)
		-- Midas Touch: the can tips right over and gushes gold, a ring of golden sprouts bursts up where it lands, a gold
		-- wave washes up over your body, the whole aura flares gold
		H.gimmick(a, { midas = true }, 30, function(self, d)
			local now = os.clock()
			tipAt = now
			waveAt = now
			for _, e in pour do
				e:Emit(20)
			end
			for _, e in midasCan do
				e:Emit(16)
			end
			for _, e in midasBody do
				e:Emit(12)
			end
			for _, e in petals do
				e:Emit(8)
			end
			if not self.lowNow then
				for j = 1, NSPROUT do
					local th = j / NSPROUT * math.pi * 2
					sproutAt(landPos + Vector3.new(math.cos(th) * 1.3, 0, math.sin(th) * 1.3), now + j * 0.04)
				end
			end
			drops:Emit(12)
			splash:Emit(10)
			self.lightKick = 3
			K.pulse(self.rootPos - Vector3.new(0, 2.7, 0), 1, 14, GOLD, 0.6, 0.35)
		end)
		-- the entrance: gold rings, petals and glints, the can swooping in and tipping over to gush as it arrives, a gold
		-- wave up your body
		a.onForm = function(self, feet)
			local now = os.clock()
			K.pulse(feet, 1, 15, SUN, 0.9, 0.35)
			K.pulse(feet, 1, 11, AMBER, 0.6, 0.45)
			tipAt = now + 0.45
			waveAt = now + 0.3
			for _, e in petals do
				e:Emit(12)
			end
			for _, e in midasBody do
				e:Emit(8)
			end
			drops:Emit(8)
			self.lightKick = 2
		end
		return a
	end
end
