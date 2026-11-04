-- WEED PULLER (Common). The card: a gloved hand yanking a dandelion out by its roots. Gimmick: Root Rip, every 6th
-- swing hits 8x. The aura, built round the card:
--   - the ForgeGUI soil emblem under you (a white dandelion clock over its roots, cracked earth, dandelions round the
--     rim) with one crisp dandelion-yellow line ring turning round it
--   - two big ForgeGUI uprooted dandelions (yellow flower, toothed leaves, a clod of soil with dangling roots) circling
--     your waist 3+ studs out: they linger at your sides and pass quickly in front and behind, so they never sit on
--     you; dirt crumbles off their clods in a little crumb trail and seeds drift off their flowers
--   - the Root Rip counter: six chunky sprouts standing on the emblem's rim, dull and drooping until counted; each swing
--     lights the next one (it perks up, green and glowing), with five lit the sixth glows gold and sparkles
--   - the Root Rip: the card's yellow glove bursts up out of the soil yanking a big dandelion out by the roots, shakes
--     the dirt off it and flings it away in a puff of seeds; the six sprouts are torn out and grow back, the two
--     dandelions jerk up, dirt and leaves erupt and a gold ring flashes out
--   - a warm earthy glow, golden motes, dirt crumbling off your hands, a dirt trail and dirt kicked up when you walk
-- Small and grounded (it's the Common), but every piece is the card's.
return function(H)
	local K, T, rgb, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ease, H.smooth, H.WHITE
	local BFX = H.BFX
	local LOOP = "Loop_WeedPuller" -- its VFX Forge particle layers

	-- colours: the soil, the dandelion's yellow, the sprouts' three states, the Root Rip's gold, the card's glove
	local SOIL = rgb(112, 74, 42)
	local SOIL_L = rgb(172, 126, 80)
	local DAND_Y = rgb(255, 214, 80) -- the line ring (the dandelion's yellow)
	local GOLD = rgb(255, 200, 55) -- the Root Rip
	local GLOVE = rgb(255, 188, 64) -- the card's yellow gardening glove (tints the white glove prop)
	local LEAF_DIM, STEM_DIM = rgb(118, 140, 72), rgb(96, 114, 58) -- a sprout not counted yet (dull olive)
	local LEAF_LIT, STEM_LIT = rgb(95, 205, 55), rgb(80, 165, 50) -- counted (glowing green)
	local LEAF_GOLD, STEM_GOLD = rgb(245, 175, 35), rgb(215, 150, 40) -- the 6th: the next swing is the rip
	local GLOW_DIM, GLOW_LIT = rgb(105, 150, 70), rgb(140, 235, 90)

	local EMBLEM = 7 -- the soil emblem's width (studs)
	local RING_R = EMBLEM / 2 + 0.3 -- the line ring, just outside the emblem's rim
	local DAND = 3.3 -- an uprooted dandelion's height (the prop's longest side)
	local RX, RZ = 3.5, 3.1 -- the dandelions' orbit: out at your sides, in front and behind (clear of the body)
	local SPROUT_R = 3.0 -- where the six sprouts stand (on the emblem's rim)
	local BIG = 2.8 -- the dandelion the glove rips out
	local GLOVE_H = 1.7 -- the glove's height
	local RIP_SPOT = Vector3.new(2.1, 0, -1.7) -- where the glove bursts up (front right of you, so you still show)

	-- a placement worked out once per frame (several pieces ride on it)
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
	-- a quick jerk up that settles back (a tug on each swing, a big yank on the Root Rip): 0 -> 1 -> 0 over k = 0..1
	local function jerk(k: number): number
		if k <= 0 or k >= 1 then
			return 0
		elseif k < 0.15 then
			local u = k / 0.15
			return 1 - (1 - u) * (1 - u)
		end
		return 1 - smooth((k - 0.15) / 0.85)
	end
	-- a flat ground piece that grows in from nothing (overshooting a touch) every time the aura forms
	local function growIn(a: any, p: BasePart, size: number, dur: number)
		local shown = -1
		H.job(a, function(self, f)
			local k = (f.t - self.born) / dur
			local s = if k >= 1 then size else math.max(0.1, size * ease(k))
			if s ~= shown then
				shown = s
				p.Size = Vector3.new(s, 0.05, s)
			end
		end)
	end
	-- set a layer's rate (client/RarityFx keeps each emitter's own rate and puts it back when you start or stop
	-- running, so that is changed too)
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
		local a = H.aura(H.RANK.Common, SOIL)
		a.tugAt, a.tugAmp, a.tugDur = -99, 0, 1 -- the dandelions' current jerk
		a.ripAt = -99 -- when the last Root Rip landed
		a.ripStage = 2 -- how far the glove's yank has got (0 burst up, 1 shaken, 2 flung)

		-- the ForgeGUI soil emblem under you, turning slowly, and one crisp line ring round it turning the other way
		local emblem = H.glowDisc(a, EMBLEM, T.embWeedPuller, WHITE, 0.2, 0.05, 0.12, 1.1)
		growIn(a, emblem, EMBLEM, 0.7)
		local ring = H.glowRing(a, RING_R, DAND_Y, 0.45, -0.12, 0.15, 1.2)
		growIn(a, ring, RING_R * 2 / 0.92, 0.85)

		-- two big uprooted dandelions circling your waist. They go round with your facing and linger at your sides
		-- (passing quickly in front and behind), so they frame you instead of covering you; they bob, sway and turn on
		-- their stalks so the leaves and dangling roots show from every side. They burst up out of the ground when the
		-- aura forms, tug on every swing and jerk right up, spinning, when the Root Rip lands.
		local crumbs: { ParticleEmitter } = {}
		for i = 1, 2 do
			local off = (i - 1) * math.pi
			local size = DAND * (if i == 1 then 1 else 0.9)
			local d = H.prop(a.body, "wp_dandelion", size)
			local at = perFrame(function(f)
				local k = ease((f.t - a.born - 0.1 * i) / 0.8)
				local u = f.t * 0.7 + off
				local ph = u - 0.35 * math.sin(2 * u) -- (slow at your sides, quick in front and behind)
				local r = 0.3 + 0.7 * k
				local tk = (f.t - a.tugAt) / a.tugDur
				local whirl = if a.tugAmp > 1 and tk > 0 and tk < 1 then smooth(tk) * math.pi * 2 else 0
				local y = -0.1 + 0.2 * math.sin(f.t * 1.6 + off) + a.tugAmp * jerk(tk) - 3 * (1 - k)
				local pos = f.root.Position + f.yaw * Vector3.new(math.cos(ph) * RX * r, y, math.sin(ph) * RZ * r)
				-- (top leaning out a little, swaying; then turning on its own stalk)
				return CFrame.new(pos)
					* f.yaw
					* CFrame.Angles(0, -ph, 0)
					* CFrame.Angles(0.1 * math.sin(f.t * 1.3 + off), 0, math.rad(-12) + math.rad(6) * math.sin(f.t * 1.7 + off))
					* CFrame.Angles(0, f.t * 0.6 + off + whirl + (1 - k) * 6, 0)
			end)
			K.move(a, d, at)
			-- dirt crumbling off its clod (the bottom of the prop), leaving a little trail of crumbs as it goes round
			local clod = K.piece(a.body, Vector3.new(0.4, 0.15, 0.4) * size)
			K.move(a, clod, function(f)
				return CFrame.new(at(f) * Vector3.new(0, -0.27 * size, 0))
			end)
			local list = H.layer(a, LOOP, "Crumbs", clod)
			setRate(a, list, 7)
			for _, e in list do
				table.insert(crumbs, e)
			end
			local trail = K.trail(clod, Vector3.new(0, 0.15, 0), Vector3.new(0, -0.15, 0), K.seq(SOIL_L, SOIL), 0.5, 0)
			K.bright(trail, 1)
			trail.Texture = BFX.sand
			trail.TextureMode = Enum.TextureMode.Wrap
			trail.TextureLength = 0.4
			H.detail(a, trail)
			-- seeds drifting off its flower (at the top)
			local head = K.piece(a.body, Vector3.new(0.24, 0.1, 0.24) * size)
			K.move(a, head, function(f)
				return CFrame.new(at(f) * Vector3.new(0, 0.44 * size, 0))
			end)
			setRate(a, H.layer(a, LOOP, "Seeds", head), 2.4)
		end

		-- the Root Rip counter: six chunky sprouts (a stem and two leaves, ~1 stud) standing on the emblem's rim, a glow
		-- under each. Waiting: dull olive, leaves drooping. Each swing lights the next one: it hops, perks its leaves up
		-- and glows green. With five lit the sixth glows gold and sparkles (the next swing is the rip). When the rip
		-- lands they are all torn out of the ground, fly up spinning and grow back out of the soil, and the count starts
		-- again. (Other players' swings aren't sent to us, so their sprouts just wait; their rips still tear them out.)
		local sprouts = {}
		for i = 1, 6 do
			local th = (i - 1) / 6 * math.pi * 2 + 0.35
			local spot = Vector3.new(math.cos(th) * SPROUT_R, 0, math.sin(th) * SPROUT_R)
			local turn = th * 2.3 + i -- (each faces its own way)
			local s = { lvl = 0, want = 0, litAt = -99, y = -1.1, spin = 0, key = -9, shown = true }
			s.stem = H.cyl(a.model, 0.62, 0.17, STEM_DIM)
			s.leaves = { H.ellipsoid(a.model, Vector3.new(0.66, 0.16, 0.38), LEAF_DIM), H.ellipsoid(a.model, Vector3.new(0.66, 0.16, 0.38), LEAF_DIM) }
			s.parts = { s.stem, s.leaves[1], s.leaves[2] }
			local base = perFrame(function(f)
				local sway = 0.08 * math.sin(f.t * 2.1 + i * 1.3)
				return CFrame.new(f.feet + spot + Vector3.new(0, 0.1 + s.y, 0)) * CFrame.Angles(sway, turn + s.spin, sway * 0.6)
			end)
			K.move(a, s.stem, function(f)
				return base(f) * CFrame.new(0, 0.31, 0) * CFrame.Angles(0, 0, math.pi / 2)
			end)
			for side = 1, 2 do
				local sign = if side == 1 then 1 else -1
				K.move(a, s.leaves[side], function(f)
					local ang = -0.3 + 0.85 * s.lvl -- (droops while waiting, perks up when lit)
					return base(f) * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, ang * sign) * CFrame.new(0.3 * sign, 0, 0)
				end)
			end
			-- its glow, flat on the emblem under it
			local g, imgs = H.plate(a.model, 1.6, BFX.glow, GLOW_DIM, 1, false, 1.1)
			K.move(a, g, function(f)
				return CFrame.new(f.feet + spot + Vector3.new(0, 0.17, 0))
			end)
			s.img = imgs[1]
			sprouts[i] = s
		end
		-- gold sparkles off the sixth sprout while the rip is ready (its rate is set below; not registered with the core,
		-- so nothing else changes it)
		local ripe = H.E(sprouts[6].stem, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD), rate = 0, life = { 0.35, 0.55 }, speed = { 0.5, 1.2 }, size = 0.5, spread = 180, light = 0.8, bright = 1.6 })
		H.detail(a, ripe)

		-- the Root Rip payoff (the card): the yellow glove bursts up out of the soil at the front right of you, gripping a
		-- big dandelion by the stalk and yanking it out with its clod and roots; it shakes the dirt off, then flings it
		-- up and away (spinning, shrinking, seeds puffing off) and sinks back into the soil. Hidden the rest of the time.
		local big = H.prop(a.model, "wp_dandelion", BIG)
		local bigSize = big.Size
		local h = bigSize.Y
		local glove = H.prop(a.model, "lb_glove", GLOVE_H)
		local sa = glove:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			pcall(function()
				(sa :: any).Color = GLOVE
			end)
		end
		-- (a missing prop is an invisible stand-in: only real props are shown and hidden)
		local yankers: { BasePart } = {}
		for _, p in { big, glove } do
			if p:IsA("MeshPart") then
				p.Transparency = 1
				table.insert(yankers, p)
			end
		end
		local ripBase = perFrame(function(f): CFrame
			return CFrame.new(f.feet + f.yaw * RIP_SPOT) * f.yaw * CFrame.Angles(0, math.rad(-35), 0)
		end)
		local HOLD = h * 0.5 + 0.45 -- (held up with its roots clear of the soil)
		local ripCF = perFrame(function(f): CFrame
			local d = f.t - a.ripAt
			local base = ripBase(f)
			if d < 0 or d >= 1.6 then
				return base * CFrame.new(0, -h, 0)
			elseif d < 0.3 then -- bursts up out of the soil, the clod and roots coming out last
				return base * CFrame.new(0, -h * 0.55 + (HOLD + h * 0.55) * ease(d / 0.3), 0)
			elseif d < 0.95 then -- held up and shaken, dirt raining off the roots
				local u = (d - 0.3) / 0.65
				return base * CFrame.new(0, HOLD + 0.15 * math.sin(u * math.pi), 0) * CFrame.Angles(0, 0, math.sin(d * 42) * 0.22 * (1 - u))
			end
			-- flung up and away, spinning
			local u = (d - 0.95) / 0.65
			return base * CFrame.new(1.4 * u, HOLD + 4.2 * u - 1.5 * u * u, 0) * CFrame.Angles(0, u * 8, -u * 1.6)
		end)
		K.move(a, big, ripCF)
		-- the glove grips the stalk just over the clod (palm toward the stalk, fingers up and in a little)
		local GRIP = CFrame.new(0.34, -0.2 * h, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(12))
		K.move(a, glove, function(f)
			local d = f.t - a.ripAt
			if d >= 0.95 and d < 1.6 then
				-- lets go with a flick of the wrist and sinks back into the soil
				local u = (d - 0.95) / 0.65
				return ripBase(f) * CFrame.new(0, HOLD - 3.4 * u * u, 0) * GRIP * CFrame.Angles(-0.7 * math.min(1, u * 3), 0, 0)
			end
			return ripCF(f) * GRIP
		end)
		-- the big dandelion's seeds (puffed off when it's shaken and flung) and its clod's dirt
		local bigHead = K.piece(a.model, Vector3.new(0.5, 0.3, 0.5))
		K.move(a, bigHead, function(f)
			return CFrame.new(ripCF(f) * Vector3.new(0, 0.42 * h, 0))
		end)
		local bigSeeds = H.layer(a, LOOP, "Seeds", bigHead, false, 1.2)
		setRate(a, bigSeeds, 0)
		local bigClod = K.piece(a.model, Vector3.new(0.7, 0.3, 0.7))
		K.move(a, bigClod, function(f)
			return CFrame.new(ripCF(f) * Vector3.new(0, -0.3 * h, 0))
		end)
		local bigCrumbs = H.layer(a, LOOP, "Crumbs", bigClod, false, 1.3)
		setRate(a, bigCrumbs, 0)
		-- the soil bursting where it comes up
		local spotPart = K.piece(a.model, Vector3.new(1.4, 0.3, 1.4))
		K.move(a, spotPart, function(f)
			return ripBase(f) * CFrame.new(0, 0.25, 0)
		end)
		local spurt = H.E(spotPart, { tex = BFX.sand, colors = K.seq(SOIL_L, SOIL), rate = 0, life = { 0.5, 0.9 }, speed = { 6, 11 }, size = 0.4, accel = Vector3.new(0, -35, 0), spread = 30, light = 0, bright = 1 })

		-- the counter and the yank, every frame
		local ripeRate = 0
		local yankShown, yankScale = false, 1
		local lastS: number? = nil
		local lastT = 0
		H.job(a, function(self, f)
			local dt = math.clamp(f.t - lastT, 0, 0.1)
			lastT = f.t
			self.feetPos = f.feet
			local sw = H.swings(f)
			if sw ~= nil and lastS ~= nil and sw > lastS then
				-- a swing: the dandelions tug and shed a little dirt (unless the rip's big yank is playing)
				if not (self.tugAmp > 1 and f.t - self.tugAt < self.tugDur) then
					self.tugAt, self.tugAmp, self.tugDur = f.t, 0.32, 0.4
					emit(crumbs, 3)
				end
			end
			lastS = sw
			local c = if sw == nil then -1 else (sw - (self.ripBase or 0)) % 6
			local rk = f.t - self.ripAt
			local flash = rk >= 0 and rk < 0.7
			for i, s in sprouts do
				local ready = c == 5 and i == 6 and not flash
				local up = flash or ready or (c >= 0 and i <= c)
				local target = if up then 1 else 0
				if target > s.want then
					s.litAt = f.t -- (it hops)
				end
				s.want = target
				s.lvl += (target - s.lvl) * math.min(1, dt * 10)
				-- the rip: torn out and flung up spinning, gone, then grown back up out of the soil
				local d = rk - (i - 1) * 0.04
				local y, spin, vis = 0, 0, true
				if d >= 0 and d < 0.6 then
					local u = d / 0.6
					y = 3 * (1 - (1 - u) * (1 - u))
					spin = u * 9
				elseif d >= 0.6 and d < 0.72 then
					vis = false
				elseif d >= 0.72 and d < 1.2 then
					y = -1.1 * (1 - ease((d - 0.72) / 0.48))
				end
				-- sprouting one after another when the aura forms; a hop when lit
				local g = (f.t - self.born - 0.3 - i * 0.08) / 0.45
				if g < 1 then
					y -= 1.1 * (1 - ease(g))
				end
				y += 0.14 * jerk((f.t - s.litAt) / 0.35)
				s.y, s.spin = y, spin
				if vis ~= s.shown then
					s.shown = vis
					for _, p in s.parts do
						p.Transparency = if vis then 0 else 1
					end
				end
				-- its look: dull waiting (none of the glow for other players), green when lit, gold for the rip
				local key = if flash or ready then 2 elseif up then 1 elseif c < 0 then -1 else 0
				if key ~= s.key then
					s.key = key
					local lit = key >= 1
					s.stem.Color = if key == 2 then STEM_GOLD elseif lit then STEM_LIT else STEM_DIM
					for _, lf in s.leaves do
						lf.Color = if key == 2 then LEAF_GOLD elseif lit then LEAF_LIT else LEAF_DIM
						lf.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
					end
					s.img.ImageColor3 = if key == 2 then GOLD elseif lit then GLOW_LIT else GLOW_DIM
					s.img.ImageTransparency = if key == 2 then 0.15 elseif lit then 0.3 elseif key == 0 then 0.8 else 1
				end
				if ready then
					s.img.ImageTransparency = 0.12 + 0.25 * (0.5 + 0.5 * math.sin(f.t * 7))
				end
			end
			local r = if c == 5 and not flash then 6 else 0
			if r ~= ripeRate then
				ripeRate = r
				ripe.Rate = r
			end

			-- the glove's yank: shown while it plays, dirt shaken off, seeds flung, the dandelion shrinking away
			local show = rk >= 0 and rk < 1.6
			if show ~= yankShown then
				yankShown = show
				for _, p in yankers do
					p.Transparency = if show then 0 else 1
				end
			end
			if show and self.ripStage < 1 and rk >= 0.3 then
				self.ripStage = 1
				emit(bigCrumbs, 14)
				emit(bigSeeds, 10)
			elseif show and self.ripStage < 2 and rk >= 0.95 then
				self.ripStage = 2
				emit(bigSeeds, 18)
				emit(bigCrumbs, 6)
			end
			local sc = if show and rk >= 0.95 then 1 - 0.75 * smooth((rk - 0.95) / 0.65) else 1
			if math.abs(sc - yankScale) > 0.02 or (sc == 1 and yankScale ~= 1) then
				yankScale = sc
				big.Size = bigSize * sc
			end
		end)

		-- the rip's eruption round you: torn leaves (its Forge layer) and a geyser of dirt out of the whole emblem
		local ringPart = H.feetPiece(a, Vector3.new(5.4, 0.3, 5.4), 0.25)
		local ripLeaves = H.layer(a, LOOP, "Rip", ringPart)
		local geyser = H.E(ringPart, { tex = BFX.sand, colors = K.seq(SOIL_L, SOIL), rate = 0, life = { 0.6, 1 }, speed = { 9, 15 }, size = 0.42, accel = Vector3.new(0, -40, 0), spread = 18, light = 0, bright = 1 })
		-- dirt kicked up when you walk, and a dirt trail behind you
		local kickAt = H.feetPiece(a, Vector3.new(1.4, 0.2, 1.4), 0.1)
		H.layer(a, LOOP, "Kick", kickAt, true)
		local trailAt = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		local ft = K.trail(trailAt, Vector3.new(-0.7, 0.12, 0), Vector3.new(0.7, 0.12, 0), K.seq(SOIL_L, SOIL), 0.5, 0.1)
		K.bright(ft, 1)
		K.move(a, trailAt, function(f)
			return CFrame.new(f.feet) * f.yaw
		end)
		-- dirt crumbling off both hands (the card's gloved hand that pulled it)
		for _, hand in { "RightHand", "LeftHand" } do
			local hp = K.piece(a.body, Vector3.new(0.35, 0.35, 0.35))
			K.move(a, hp, function(f)
				local l = H.limb(f, hand)
				if not l then
					return f.root
				end
				-- (an R6 arm is a long block: its hand is at the bottom)
				return l.CFrame * CFrame.new(0, if l.Size.Y > 1.2 then -0.85 else -0.1, 0)
			end)
			H.detail(a, table.unpack(H.layer(a, LOOP, "Crumbs", hp, false, 0.75)))
		end
		-- a soft, earthy glow on the body (sunlit dandelion gold fading to soil) and golden motes round you
		H.shell(a, K.seq(rgb(255, 222, 140), rgb(205, 150, 85)), 2.6, 0.8)
		H.layer(a, LOOP, "Motes", K.bodyBox(a, Vector3.new(3.4, 4.4, 3.4), -0.2))

		-- the Root Rip lands near you: the count starts again, the glove yanks the big dandelion out, the sprouts are
		-- torn out (above), the circling dandelions yank up, dirt and leaves erupt, a gold ring flashes out
		H.gimmick(a, { rootRip = true }, 14, function(self, d)
			local s = H.swings({ player = self.owner })
			if s then
				self.ripBase = s
			end
			local now = os.clock()
			self.ripAt = now
			self.ripStage = 0
			self.tugAt, self.tugAmp, self.tugDur = now, 1.3, 1
			emit(ripLeaves, 16)
			emit(crumbs, 10)
			geyser:Emit(18)
			spurt:Emit(16)
			ripe:Emit(10)
			K.pulse(self.feetPos or (self.rootPos - Vector3.new(0, 2.7, 0)), 1, 7.5, GOLD, 0.5, 0.15)
		end)

		-- the entrance: the emblem and ring grow in, the dandelions burst up out of the ground and fly out to circle you,
		-- the sprouts come up one after another, dirt and leaves burst up (the core plays the Form_WeedPuller burst too)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 8, SOIL_L, 0.6, 0.12)
			emit(ripLeaves, 12)
			geyser:Emit(16)
		end
		return a
	end
end
