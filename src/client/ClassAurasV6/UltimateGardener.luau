-- ULTIMATE GARDENER (Legendary). The card: a golden watering can pouring liquid gold. Gimmick: Midas Touch, every 20th
-- clump you uncover is a Golden mutation. Built from the ForgeGUI ornate golden watering can (ug_can), the ForgeGUI
-- sunburst emblem and the VFX Forge layers of Loop_UltimateGardener (Pour, Petals, Pollen, Rays, Midas):
--   - the golden watering can circling you at chest height, glinting, tipped to pour: a stream of liquid gold (a gold
--     beam and drops) down to the ground, golden sprouts popping up, a gold puddle and gold ripples where it lands.
--     When Midas Touch lands it tips right over and gushes, and the aura flares gold
--   - a sunflower halo up and back from your head, sparkling, turning in a ring of sun rays
--   - golden vine wings (a leafy green vine along their top edges, a soft gold glow round their rims, sparkles),
--     breathing slowly
--   - light falling on you from above (sun shafts and falling rays), gold petals and pollen
--   - the sunburst emblem under you in a warm glow
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local LOOP = "Loop_UltimateGardener"
	local SUN = rgb(255, 200, 60)
	local SUN_L = rgb(255, 238, 165)
	local GOLD = rgb(255, 188, 45)
	local AMBER = rgb(235, 135, 25)
	local LEAF = rgb(95, 175, 60)
	local LEAF_L = rgb(150, 215, 85)
	-- the watering can. Its frame: -Z is where the spout points, +Y is up; CAN_TURN turns the prop into that frame.
	-- GUESS: the prop's spout is at its -Z end (its front). If the gold pours out of the wrong end in the screenshots,
	-- set CAN_TURN to CFrame.Angles(0, math.pi, 0) for a spout at +Z, CFrame.Angles(0, math.rad(90), 0) for +X or
	-- CFrame.Angles(0, math.rad(-90), 0) for -X (and SPOUT's reach to match the prop).
	local CAN = 2.5 -- its longest side (studs)
	local CAN_TURN = CFrame.identity
	local SPOUT = Vector3.new(0, 0.1, -0.46) * CAN -- the spout's rose (where the gold leaves), in the can's frame
	local RISE = math.rad(30) -- the spout rises this steeply out of the can: the stream leaves the rose along it
	local TILT = math.rad(40) -- the can leans forward this far to pour
	local LEAD = math.rad(50) -- the spout points out from you and this far ahead, the way the can travels
	local ORBIT = 3.4 -- the can's distance from you (round a point a little in front of you, clear of the wings)
	local HURRY = math.rad(135) -- where on its round the can moves fastest (behind you on your left; 0 = your right)
	local WING = 5.2
	-- the top edge of the left wing's art (u, v), root to tip: the vine runs along it
	local EDGE = { { 0.92, 0.47 }, { 0.8, 0.34 }, { 0.68, 0.24 }, { 0.55, 0.17 }, { 0.42, 0.135 }, { 0.3, 0.135 }, { 0.2, 0.2 }, { 0.12, 0.31 } }
	local UPRIGHT = H.UPRIGHT
	local FRONT = CFrame.Angles(math.rad(-90), 0, 0) * CFrame.Angles(0, math.pi, 0) -- (as H.wings' front plates)

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

	return function()
		local a = H.aura(H.RANK.Legendary, SUN)
		local tipAt = -100 -- (os.clock when the can last tipped right over: Midas Touch)
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

		-- the ground: a warm glow, the sunburst emblem (grows in, turning slowly), a light gold rim
		H.glowDisc(a, 13, BFX.glow, SUN, 0.5, 0, 0.07, 1)
		H.sigil(a, 10.5, T.embUltimateGardener, WHITE, 0.15, 0.05, 0.12, 0.9, 1.1)
		H.glowRing(a, 5.7, SUN_L, 0.3, 0, 0.15, 1.3)

		-- the golden watering can circling you, spout out and ahead, leaning forward to pour; it swoops down from over
		-- your head when the aura forms. It lingers at your front right (in view, clear of your body) and hurries past
		-- behind you.
		local canCF = once(function(f): CFrame
			local life = f.t - a.born
			local k = ease((life - 0.05) / 0.85)
			local u = life * 0.5 + 5
			local th = u + 0.5 * math.sin(u - HURRY)
			local base = CFrame.new(f.root.Position) * f.yaw
			local pos = (base * CFrame.new(math.cos(th) * ORBIT * k, 1.25 + 0.18 * math.sin(f.t * 1.4) + 4 * (1 - k), -0.5 + math.sin(th) * ORBIT * k)).Position
			local out = th + LEAD
			local dir = base:VectorToWorldSpace(Vector3.new(math.cos(out), 0, math.sin(out)))
			return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-(TILT + math.rad(85) * tipped(f.t)), 0, 0)
		end)
		local can = H.prop(a.body, "ug_can", CAN)
		K.move(a, can, function(f)
			return canCF(f) * CAN_TURN
		end)
		local shine = E(can, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 3, life = { 0.3, 0.5 }, speed = { 0, 0.1 }, size = 0.7, spread = 180, light = 1, bright = 2 })
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
		local landCF = once(function(f): CFrame
			local s = spoutCF(f)
			local out = s.LookVector
			local p = s.Position
			return CFrame.new(p.X + out.X * 1.5, f.feet.Y + 0.05, p.Z + out.Z * 1.5)
		end)
		local land = K.piece(a.model, Vector3.new(1.4, 0.2, 1.4))
		K.move(a, land, landCF)
		-- the stream of liquid gold: a solid gold beam arcing from the rose down into the ground, a flowing sheen on it
		local from = H.att(spout, Vector3.zero)
		from.CFrame = CFrame.Angles(0, math.pi / 2, 0) -- (its axis, local X, runs along the outflow)
		local to = H.att(land, Vector3.zero)
		to.CFrame = CFrame.Angles(0, 0, -math.pi / 2) -- (its axis points down: the stream falls into the ground)
		local stream = H.beam(from, to, { colors = K.seq(SUN_L, GOLD, AMBER), w0 = 0.45, w1 = 0.32, light = 0.45, bright = 1.4, segments = 14, curve0 = 0.9, curve1 = 1.6 })
		local sheen = H.beam(from, to, { colors = K.seq(WHITE, SUN_L, SUN), w0 = 0.6, w1 = 0.42, trans = NumberSequence.new(0.45), light = 0.8, bright = 1.4, segments = 14, curve0 = 0.9, curve1 = 1.6, tex = T.energy, texLen = 1.4, texSpeed = 2.5, zoff = 0.02 })
		H.detail(a, sheen)
		-- golden sprouts popping up where it lands (they stay put, so the can leaves a ring of them), splashes, a puddle
		local sprouts = E(land, { tex = BFX.leaf, colors = K.seq(SUN_L, GOLD), rate = 9, life = { 1.1, 1.5 }, speed = { 0.2, 0.5 }, size = 0.8, grow = true, spread = 10, light = 0.35, bright = 1.6, orient = Enum.ParticleOrientation.FacingCameraWorldUp, rot = { -15, 15 } })
		K.addEmitter(a, sprouts)
		local splash = E(land, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 5, life = { 0.3, 0.5 }, speed = { 1, 2.5 }, size = 0.55, spread = 60, light = 1, bright = 1.8 })
		K.addEmitter(a, splash)
		H.detail(a, splash)
		local puddle = H.plate(a.model, 2.2, BFX.glow, GOLD, 0.3, false, 1.2)
		K.move(a, puddle, function(f)
			return landCF(f) * CFrame.new(0, 0.03, 0)
		end)
		-- gold ripples running out from where it lands (once the can is in place; not for far players or phones)
		H.every(a, 0.75, function(self, f)
			if not self.lowNow and f.t - self.born > 1 then
				K.pulse(landCF(f).Position, 0.4, 3.4, GOLD, 0.65, 0.35)
			end
		end)

		-- the sunflower halo, raised up and back from your head (not over it), turning inside a ring of sun rays; both
		-- grow in when the aura forms
		local rays, _, rayGuis = H.plate(a.body, 5.4, T.sigSun, SUN_L, 0.3, true, 1.3)
		local flower = H.plate(a.body, 3.1, T.sunflower, WHITE, 0, true, 1.1)
		H.detail(a, rayGuis[1], rayGuis[2])
		local sunGlints = E(flower, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 2.5, life = { 0.4, 0.7 }, speed = { 0, 0.3 }, size = 0.6, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, sunGlints)
		H.detail(a, sunGlints)
		local function haloAt(f, back: number): Vector3
			return (f.headCF * CFrame.new(0, 1.35 + 0.08 * math.sin(f.t * 1.3), back)).Position
		end
		K.move(a, rays, function(f)
			return H.facing(haloAt(f, 1.5), f, -f.t * 0.2)
		end)
		K.move(a, flower, function(f)
			return H.facing(haloAt(f, 1.45), f, f.t * 0.3)
		end)
		local settled = false
		H.job(a, function(self, f)
			local life = f.t - self.born
			if life > 1.4 then
				if not settled then
					settled = true
					rays.Size = Vector3.new(5.4, 0.05, 5.4)
					flower.Size = Vector3.new(3.1, 0.05, 3.1)
				end
				return
			end
			settled = false
			local k = math.max(0.02, ease((life - 0.15) / 0.8))
			rays.Size = Vector3.new(5.4 * k, 0.05, 5.4 * k)
			flower.Size = Vector3.new(3.1 * k, 0.05, 3.1 * k)
		end)

		-- golden vine wings, breathing slowly and held out to the sides, unfolding from your back when the aura forms
		local function wingBase(f, side: number): CFrame
			local k = ease((f.t - a.born - 0.2) / 0.8)
			local flap = math.rad(6) + math.rad(9) * math.sin(f.t * 1.6)
			return f.root * CFrame.new(side * 0.3, 1.05, 0.72) * CFrame.Angles(0, -side * flap, side * math.rad(10) * k) * CFrame.new(side * (0.2 + 2.4 * k), 0.6, 0)
		end
		local wingL = once(function(f): CFrame
			return wingBase(f, -1)
		end)
		local wingR = once(function(f): CFrame
			return wingBase(f, 1)
		end)
		local function wingCF(f, side: number): CFrame
			return if side < 0 then wingL(f) else wingR(f)
		end
		H.wings(a, T.wingVineL, T.wingVineR, rgb(255, 214, 110), WING, 1.2, wingCF)
		for _, side in { -1, 1 } do
			-- a soft gold glow round each wing's rim: a bigger, faint copy of the wing just behind it, on each side (one
			-- sided plates, so from either side the wing itself covers it and only the rim shows)
			for _, face in { "back", "front" } do
				local tex = if (face == "back") == (side > 0) then T.wingVineR else T.wingVineL
				local p, imgs, guis = H.plate(a.body, WING * 1.18, tex, SUN_L, 0.62, false, 1.6)
				local off = if face == "back" then CFrame.new(side * 0.3, 0.15, -0.12) * UPRIGHT else CFrame.new(side * 0.3, 0.15, 0.09) * FRONT
				K.move(a, p, function(f)
					return wingCF(f, side) * off
				end)
				H.detail(a, guis[1])
			end
			-- a leafy green vine along the wing's top edge (drawn over the wing from both sides), solid leaves off it,
			-- sparkles drifting off the feathers
			local function at(u: number, v: number): Vector3
				return Vector3.new(-side * (u - 0.5) * WING, (0.5 - v) * WING, 0)
			end
			local holder = K.piece(a.body, Vector3.new(WING * 0.75, WING * 0.6, 0.3))
			K.move(a, holder, function(f)
				return wingCF(f, side)
			end)
			local pts = {}
			for i, e in EDGE do
				pts[i] = at(e[1], e[2] + 0.025)
			end
			for _, b in H.chain(holder, pts, { colors = K.seq(LEAF_L, LEAF), w0 = 0.5, w1 = 0.32, tex = T.vineStrip, texLen = 2, light = 0.15, bright = 1.2, zoff = 0.12 }) do
				H.detail(a, b)
			end
			for k, e in { { 0.8, 0.34, 1 }, { 0.6, 0.19, -1 }, { 0.42, 0.135, 1 }, { 0.24, 0.17, -1 } } do
				local leaf = H.ellipsoid(a.body, Vector3.new(0.56, 0.26, 0.1), if k % 2 == 0 then LEAF else LEAF_L, Enum.Material.SmoothPlastic)
				local off = CFrame.new(at(e[1], e[2] + 0.025) + Vector3.new(0, e[3] * 0.2, -0.015)) * CFrame.Angles(0, 0, e[3] * side * math.rad(45))
				K.move(a, leaf, function(f)
					return wingCF(f, side) * off
				end)
				H.detail(a, leaf)
			end
			local sparkle = E(holder, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 3, life = { 0.6, 1 }, speed = { 0.2, 0.6 }, size = 0.5, accel = Vector3.new(0, -1, 0), spread = 180, light = 1, bright = 2 })
			K.addEmitter(a, sparkle)
			H.detail(a, sparkle)
		end

		-- light falling on you from above: four soft sun shafts and rays of light falling through them
		local sky = K.piece(a.body, Vector3.new(4.6, 0.2, 4.6))
		K.move(a, sky, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 10, 0)) * CFrame.Angles(0, f.t * 0.15, 0)
		end)
		H.layer(a, LOOP, "Rays", sky)
		for i = 1, 4 do
			local th = i / 4 * math.pi * 2 + 0.4
			local top = H.att(sky, Vector3.new(math.cos(th) * 1.2, 7, math.sin(th) * 1.2))
			local bot = H.att(sky, Vector3.new(math.cos(th) * 2.4, -9.8, math.sin(th) * 2.4))
			local b = H.beam(top, bot, { colors = K.seq(SUN_L, SUN), w0 = 2.2, w1 = 5, trans = ns(0, 1, 0.3, 0.65, 0.9, 0.7, 1, 1), tex = T.stripBody, texMode = Enum.TextureMode.Stretch, texSpeed = -0.3, light = 0.7, bright = 1.3 })
			if i % 2 == 0 then
				H.detail(a, b)
			end
		end
		-- gold petals and pollen round you; the Midas Touch's glints; petals kicked up when you run
		local around = K.bodyBox(a, Vector3.new(5, 5.5, 5), 0)
		local petals = H.layer(a, LOOP, "Petals", around)
		H.layer(a, LOOP, "Pollen", around)
		local midasBody = H.layer(a, LOOP, "Midas", around, false, 1.2)
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.2, 1.2), 0.15)
		K.addEmitter(a, E(kick, { tex = BFX.petal, colors = K.seq(SUN_L, SUN), rate = 9, life = { 0.6, 1 }, speed = { 2, 4 }, size = 0.5, accel = Vector3.new(0, -6, 0), spin = 200, spread = 50, light = 0.3 }), true)

		H.shell(a, K.seq(GOLD, SUN), 6, 1)
		K.feetTrail(a, K.seq(SUN_L, SUN, AMBER))
		K.outline(a, SUN, 0.35)
		K.light(a, SUN, 1.3, 14)
		H.lightJob(a, 0.08)
		-- while the can is tipped over the stream runs thicker and gold gushes out of the rose
		local width, gushed = -1, 0
		H.job(a, function(self, f)
			local tp = tipped(f.t)
			local g = 1 + 0.9 * tp
			if math.abs(g - width) > 0.01 then
				width = g
				stream.Width0, stream.Width1 = 0.45 * g, 0.32 * g
				sheen.Width0, sheen.Width1 = 0.6 * g, 0.42 * g
			end
			if tp > 0.6 and f.t - gushed > 0.05 then
				gushed = f.t
				for _, e in pour do
					e:Emit(2)
				end
			end
		end)
		-- Midas Touch: the can tips right over and gushes gold, golden sprouts burst up, the whole aura flares gold
		H.gimmick(a, { midas = true }, 30, function(self, d)
			tipAt = os.clock()
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
			sprouts:Emit(14)
			splash:Emit(10)
			self.lightKick = 3
			K.pulse(self.rootPos - Vector3.new(0, 2.7, 0), 1, 14, GOLD, 0.6, 0.25)
		end)
		-- the entrance: gold rings, petals and glints, the can swooping in and tipping over to gush as it arrives
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 17, SUN, 0.9, 0)
			K.pulse(feet, 1, 11, GOLD, 0.6, 0.35)
			tipAt = os.clock() + 0.45
			for _, e in petals do
				e:Emit(12)
			end
			for _, e in midasBody do
				e:Emit(8)
			end
			sprouts:Emit(10)
			self.lightKick = 2
		end
		return a
	end
end
