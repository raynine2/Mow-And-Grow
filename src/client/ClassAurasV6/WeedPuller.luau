-- WEED PULLER (Common). The card: a gloved hand yanking a dandelion out by its roots. Gimmick: Root Rip, every 6th
-- swing hits 8x. The aura, built round the card:
--   - the ForgeGUI soil emblem under you (a white dandelion clock over its roots, cracked earth, dandelions round the
--     rim) with one thin sprout-green line ring turning round it
--   - two big ForgeGUI uprooted dandelions (yellow flower, toothed leaves, a clod of soil) circling your waist 3+ studs
--     out, long roots dangling and swinging under their clods: they bob, sway and tilt, linger at your sides and pass
--     quickly in front and behind, so they never sit on you; brown dirt crumbles off their clods in a little crumb
--     trail and white dandelion fluff drifts off their flowers
--   - the card itself: a brown work glove at your front right yanking dandelions out of the soil on a loop: a dandelion
--     sprouts, the glove grabs it, tugs twice, yanks it out roots and all, shakes the dirt off and tosses it away
--   - the Root Rip counter: six two-leaf seedlings standing on the emblem's rim: dull dark green and closed while
--     waiting, each swing lights the next one (it hops, opens its leaves and glows Neon green), with five lit the sixth
--     glows gold and sparkles
--   - the Root Rip: the glove yanks a dandelion right out with a burst of 20 clods of dirt and a puff of dandelion seeds;
--     the six seedlings are torn out and grow back, the two dandelions jerk up, leaves erupt and a gold ring flashes out
--   - white dandelion fluff round you, dirt crumbling off your hands, a dirt trail and dirt kicked up when you walk
-- Small and grounded (it's the Common), but every piece is the card's. (Council: the dirt is lit like dirt, not glowing,
-- and nothing blooms.)
return function(H)
	local K, T, rgb, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ease, H.smooth, H.WHITE
	local BFX = H.BFX
	local LOOP = "Loop_WeedPuller" -- its VFX Forge particle layers

	-- colours: the soil, the dandelion's yellow, the sprouts' three states, the Root Rip's gold, the card's glove
	local SOIL = rgb(112, 74, 42)
	local CRUMB, CRUMB_D = rgb(120, 84, 52), rgb(78, 52, 32) -- dirt crumbs (lit by the scene, so they read as dirt)
	local ROOT, ROOT_D = rgb(168, 120, 70), rgb(104, 70, 40) -- the dangling roots
	local RING_G = rgb(150, 235, 95) -- the line ring (a sprout's green)
	local GOLD = rgb(255, 200, 55) -- the Root Rip
	local GLOVE = rgb(150, 110, 70) -- the card's brown work glove (tints the white glove prop)
	local LEAF_DIM, STEM_DIM = rgb(62, 112, 40), rgb(56, 96, 36) -- a seedling not counted yet (dull dark green)
	local LEAF_LIT, STEM_LIT = rgb(70, 210, 45), rgb(60, 160, 40) -- counted (Neon bright green)
	local LEAF_GOLD, STEM_GOLD = rgb(245, 175, 35), rgb(200, 140, 35) -- the 6th: the next swing is the rip
	local GLOW_LIT = rgb(140, 235, 90)

	local EMBLEM = 7 -- the soil emblem's width (studs)
	local RING_R = EMBLEM / 2 + 0.3 -- the line ring, just outside the emblem's rim
	local DAND = 3.0 -- an uprooted dandelion's height (the prop's longest side)
	local RX, RZ = 3.5, 3.1 -- the dandelions' orbit: out at your sides, in front and behind (clear of the body)
	local SPROUT_R = 3.0 -- where the six sprouts stand (on the emblem's rim)
	local BIG = 2.6 -- the dandelion the glove yanks out
	local GLOVE_H = 1.5 -- the glove's height
	local RIP_SPOT = Vector3.new(2.1, 0, -1.7) -- where the glove pulls weeds (front right of you, so you still show)
	local LOOP_T = 4.6 -- one weed pulled every 4.6 s
	local T_YANK = 2.0 -- when in the loop it's yanked out (a Root Rip jumps straight to it)

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
	-- dirt that looks like dirt: dark brown, lit by the scene (not glowing), no light of its own
	local function dirt(list: { ParticleEmitter })
		for _, e in list do
			e.Color = K.seq(CRUMB, CRUMB_D)
			e.LightEmission = 0
			e.LightInfluence = 1
			e.Brightness = 1
		end
	end

	return function()
		local a = H.aura(H.RANK.Common, SOIL)
		a.tugAt, a.tugAmp, a.tugDur = -99, 0, 1 -- the dandelions' current jerk
		a.ripAt = -99 -- when the last Root Rip landed
		a.loopAt = os.clock() -- the glove's weed-pulling loop (a Root Rip moves it on to the yank)

		-- the ForgeGUI soil emblem under you, turning slowly, and one thin sprout-green line ring round it turning the
		-- other way (a ring of beams: LightEmission 0.3, so it keeps its colour)
		local emblem = H.glowDisc(a, EMBLEM, T.embWeedPuller, WHITE, 0.2, 0.05, 0.12, 1.1)
		growIn(a, emblem, EMBLEM, 0.7)
		K.groundRing(a, RING_R, 0.12, RING_G, 2, 0.35, -0.12, true, 0.15)

		-- two big uprooted dandelions circling your waist. They go round with your facing and linger at your sides
		-- (passing quickly in front and behind), so they frame you instead of covering you; they bob, swing and tilt like
		-- they've just been pulled, and turn on their stalks so the leaves and roots show from every side. They burst up
		-- out of the ground when the aura forms, tug on every swing and jerk right up, spinning, when the Root Rip lands.
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
				local y = -0.1 + 0.32 * math.sin(f.t * 1.4 + off) + a.tugAmp * jerk(tk) - 3 * (1 - k)
				local pos = f.root.Position + f.yaw * Vector3.new(math.cos(ph) * RX * r, y, math.sin(ph) * RZ * r)
				-- (swinging like it hangs from your hand: top leaning out and to and fro; then turning on its own stalk)
				return CFrame.new(pos)
					* f.yaw
					* CFrame.Angles(0, -ph, 0)
					* CFrame.Angles(0.2 * math.sin(f.t * 1.3 + off), 0, math.rad(-12) + math.rad(12) * math.sin(f.t * 1.7 + off))
					* CFrame.Angles(0, f.t * 0.6 + off + whirl + (1 - k) * 6, 0)
			end)
			K.move(a, d, at)
			-- its clod (the bottom of the prop): turns with it, so the roots under it swing
			local clod = K.piece(a.body, Vector3.new(0.4, 0.15, 0.4) * size)
			K.move(a, clod, function(f)
				return at(f) * CFrame.new(0, -0.27 * size, 0)
			end)
			-- long roots dangling under the clod, curling
			for r = 1, 3 do
				local ang = r / 3 * math.pi * 2 + i
				local top = H.att(clod, Vector3.new(math.cos(ang) * 0.1 * size, -0.04 * size, math.sin(ang) * 0.1 * size))
				local tip = H.att(clod, Vector3.new(math.cos(ang) * 0.24 * size, -(0.38 + 0.08 * r) * size, math.sin(ang) * 0.24 * size))
				H.beam(top, tip, { colors = K.seq(ROOT, ROOT_D), w0 = 0.11, w1 = 0.03, light = 0, bright = 1, segments = 6, curve0 = 0.3 * (r - 2), curve1 = 0.25 })
			end
			-- brown dirt crumbling off it, leaving a little trail of crumbs as it goes round
			local list = H.layer(a, LOOP, "Crumbs", clod, false, 0.65)
			dirt(list)
			setRate(a, list, 4)
			for _, e in list do
				table.insert(crumbs, e)
			end
			local trail = K.trail(clod, Vector3.new(0, 0.12, 0), Vector3.new(0, -0.12, 0), K.seq(CRUMB, CRUMB_D), 0.45, 0)
			K.bright(trail, 1)
			trail.Texture = BFX.sand
			trail.TextureMode = Enum.TextureMode.Wrap
			trail.TextureLength = 0.4
			H.detail(a, trail)
			-- white dandelion fluff drifting off its flower (at the top)
			local head = K.piece(a.body, Vector3.new(0.24, 0.1, 0.24) * size)
			K.move(a, head, function(f)
				return CFrame.new(at(f) * Vector3.new(0, 0.44 * size, 0))
			end)
			setRate(a, H.layer(a, LOOP, "Seeds", head), 2.4)
		end

		-- the Root Rip counter: six two-leaf seedlings (a stem and two leaves in a V, ~1.3 studs) standing on the emblem's
		-- rim. Waiting: dull dark green, leaves half closed, no glow. Each swing lights the next one: it hops, opens its
		-- leaves wide, turns Neon bright green and a green glow lights under it. With five lit the sixth glows gold and
		-- sparkles (the next swing is the rip). When the rip lands they are all torn out of the ground, fly up spinning
		-- and grow back out of the soil, and the count starts again. (Other players' swings aren't sent to us, so their
		-- seedlings just wait; their rips still tear them out.)
		local LEAF = Vector3.new(0.78, 0.09, 0.44)
		local sprouts = {}
		for i = 1, 6 do
			local th = (i - 1) / 6 * math.pi * 2 + 0.35
			local spot = Vector3.new(math.cos(th) * SPROUT_R, 0, math.sin(th) * SPROUT_R)
			local turn = th * 2.3 + i -- (each faces its own way)
			local s = { lvl = 0, want = 0, litAt = -99, y = -1.4, spin = 0, key = -9, shown = true }
			s.stem = H.cyl(a.model, 0.84, 0.15, STEM_DIM)
			s.leaves = { H.ellipsoid(a.model, LEAF * 0.85, LEAF_DIM), H.ellipsoid(a.model, LEAF * 0.85, LEAF_DIM) }
			s.parts = { s.stem, s.leaves[1], s.leaves[2] }
			local base = perFrame(function(f)
				local sway = 0.08 * math.sin(f.t * 2.1 + i * 1.3)
				return CFrame.new(f.feet + spot + Vector3.new(0, 0.1 + s.y, 0)) * CFrame.Angles(sway, turn + s.spin, sway * 0.6)
			end)
			K.move(a, s.stem, function(f)
				return base(f) * CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2)
			end)
			for side = 1, 2 do
				local sign = if side == 1 then 1 else -1
				K.move(a, s.leaves[side], function(f)
					local ang = 0.3 + 0.42 * s.lvl -- (half closed while waiting, open wide when lit)
					return base(f) * CFrame.new(0, 0.82, 0) * CFrame.Angles(0, 0, ang * sign) * CFrame.new(0.36 * sign, 0, 0)
				end)
			end
			-- its glow, flat on the emblem under it (only when lit)
			local g, imgs = H.plate(a.model, 1.6, BFX.glow, GLOW_LIT, 1, false, 1.1)
			K.move(a, g, function(f)
				return CFrame.new(f.feet + spot + Vector3.new(0, 0.17, 0))
			end)
			s.img = imgs[1]
			sprouts[i] = s
		end
		-- gold sparkles off the sixth seedling while the rip is ready (its rate is set below; not registered with the
		-- core, so nothing else changes it)
		local ripe = H.E(sprouts[6].stem, { tex = T.glint, flip = 4, colors = K.seq(GOLD, rgb(240, 160, 30)), rate = 0, life = { 0.35, 0.55 }, speed = { 0.5, 1.2 }, size = 0.5, spread = 180, light = 0.5, bright = 1.4 })
		H.detail(a, ripe)

		-- the card: a brown work glove at your front right pulling weeds on a loop. A dandelion sprouts out of the soil,
		-- the glove comes down and grabs it by the leaves, tugs twice, yanks it out with its clod and roots, shakes the
		-- dirt off, tosses it away (spinning, shrinking, seeds puffing off) and rises back to wait for the next one.
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
		local bigReal = big:IsA("MeshPart") -- (a missing prop is an invisible stand-in: it is never shown)
		if bigReal then
			big.Transparency = 1
		end
		local ripBase = perFrame(function(f): CFrame
			return CFrame.new(f.feet + f.yaw * RIP_SPOT) * f.yaw * CFrame.Angles(0, math.rad(-35), 0)
		end)
		-- heights of the dandelion's centre over your feet: deep in the soil, planted (clod and roots under the soil, the
		-- leaves on it), held up (roots clear of the soil)
		local DEEP, PLANT, HOLD = -0.3 - 0.55 * h, -0.3 + 0.2 * h, -0.3 + 0.5 * h + 0.5
		local function loopT(f): number
			return (f.t - a.loopAt) % LOOP_T
		end
		local ripCF = perFrame(function(f): CFrame
			local tau = loopT(f)
			local base = ripBase(f)
			if tau < 0.5 then -- sprouting up out of the soil
				return base * CFrame.new(0, DEEP + (PLANT - DEEP) * ease(tau / 0.5), 0)
			elseif tau < 1 then -- waiting for the glove
				return base * CFrame.new(0, PLANT, 0)
			elseif tau < T_YANK then -- tugged twice, its leaves straining
				local y = PLANT + 0.25 * (jerk((tau - 1) / 0.45) + jerk((tau - 1.5) / 0.45))
				return base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, 0.08 * math.sin(tau * 30) * (y - PLANT) * 4)
			elseif tau < 2.3 then -- yanked out, the clod and roots coming out last
				return base * CFrame.new(0, PLANT + (HOLD - PLANT) * ease((tau - T_YANK) / 0.3), 0)
			elseif tau < 3.1 then -- held up and shaken, dirt raining off the roots
				local u = (tau - 2.3) / 0.8
				return base * CFrame.new(0, HOLD + 0.12 * math.sin(u * math.pi), 0) * CFrame.Angles(0, 0, math.sin(tau * 42) * 0.22 * (1 - u))
			elseif tau < 3.7 then -- tossed up and away, spinning
				local u = (tau - 3.1) / 0.6
				return base * CFrame.new(1.4 * u, HOLD + 4 * u - 1.5 * u * u, 0) * CFrame.Angles(0, u * 8, -u * 1.6)
			end
			return base * CFrame.new(0, DEEP, 0) -- (gone; the next one sprouts)
		end)
		K.move(a, big, ripCF)
		-- the glove: beside the stalk, palm toward it, fingers up round the leaves. It hovers over the weed, comes down
		-- to grab it, pulls with it, lets go with a flick and rises back to hover.
		local GRIP = CFrame.new(0, 0.1 * h, 0) * CFrame.new(0.32, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(12))
		local HOVER = PLANT + 1.5
		K.move(a, glove, function(f)
			local tau = loopT(f)
			local base = ripBase(f)
			local bob = 0.1 * math.sin(f.t * 2.2)
			if tau >= 1 and tau < 3.1 then
				return ripCF(f) * GRIP -- (gripping it)
			elseif tau >= 0.5 and tau < 1 then -- reaching down to it
				local y = HOVER + bob + (PLANT - HOVER - bob) * smooth((tau - 0.5) / 0.5)
				return base * CFrame.new(0, y, 0) * GRIP
			elseif tau >= 3.1 and tau < 3.7 then -- the flick, then back up
				local u = (tau - 3.1) / 0.6
				return base * CFrame.new(0, HOLD + (HOVER - HOLD) * smooth(u), 0) * GRIP * CFrame.Angles(-0.7 * math.sin(math.min(1, u * 2) * math.pi), 0, 0)
			end
			return base * CFrame.new(0, HOVER + bob, 0) * GRIP -- (hovering, waiting)
		end)
		-- the yanked dandelion's seeds (puffed off when it's shaken and tossed) and its clod's dirt
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
		local bigCrumbs = H.layer(a, LOOP, "Crumbs", bigClod, false, 0.9)
		dirt(bigCrumbs)
		setRate(a, bigCrumbs, 0)
		-- the soil bursting where it comes out (clods of dirt)
		local spotPart = K.piece(a.model, Vector3.new(1.2, 0.3, 1.2))
		K.move(a, spotPart, function(f)
			return ripBase(f) * CFrame.new(0, 0.2, 0)
		end)
		local spurt = H.E(spotPart, { tex = BFX.sand, colors = K.seq(CRUMB, CRUMB_D), rate = 0, life = { 0.5, 0.9 }, speed = { 5, 10 }, size = 0.42, accel = Vector3.new(0, -35, 0), spread = 32, spin = 200, light = 0, bright = 1 })
		dirt({ spurt })

		-- the counter and the weed-pulling loop, every frame
		local ripeRate = 0
		local bigShown, bigScale, stage = false, 1, -1
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
					y = -1.4 * (1 - ease((d - 0.72) / 0.48))
				end
				-- sprouting one after another when the aura forms; a hop when lit
				local g = (f.t - self.born - 0.3 - i * 0.08) / 0.45
				if g < 1 then
					y -= 1.4 * (1 - ease(g))
				end
				y += 0.16 * jerk((f.t - s.litAt) / 0.35)
				s.y, s.spin = y, spin
				if vis ~= s.shown then
					s.shown = vis
					for _, p in s.parts do
						p.Transparency = if vis then 0 else 1
					end
				end
				-- its look: dull dark green and a size smaller waiting, Neon green and full size lit, gold for the rip
				local key = if flash or ready then 2 elseif up then 1 elseif c < 0 then -1 else 0
				if key ~= s.key then
					s.key = key
					local lit = key >= 1
					s.stem.Color = if key == 2 then STEM_GOLD elseif lit then STEM_LIT else STEM_DIM
					s.stem.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
					for _, lf in s.leaves do
						lf.Color = if key == 2 then LEAF_GOLD elseif lit then LEAF_LIT else LEAF_DIM
						lf.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
						lf.Size = LEAF * (if lit then 1.1 else 0.85)
					end
					s.img.ImageColor3 = if key == 2 then GOLD else GLOW_LIT
					s.img.ImageTransparency = if key == 2 then 0.2 elseif lit then 0.35 else 1
				end
				if ready then
					s.img.ImageTransparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(f.t * 7))
				end
			end
			local r = if c == 5 and not flash then 6 else 0
			if r ~= ripeRate then
				ripeRate = r
				ripe.Rate = r
			end

			-- the glove's loop: the dandelion shown while it's up, dirt off each tug and the yank, seeds when it's shaken
			-- and tossed, the dandelion shrinking away as it flies
			local tau = loopT(f)
			local show = bigReal and tau < 3.7
			if show ~= bigShown then
				bigShown = show
				big.Transparency = if show then 0 else 1
			end
			local st = if tau < 1 then 0 elseif tau < 1.5 then 1 elseif tau < T_YANK then 2 elseif tau < 2.3 then 3 elseif tau < 3.1 then 4 elseif tau < 3.7 then 5 else 6
			if st ~= stage then
				stage = st
				if st == 1 or st == 2 then
					spurt:Emit(2)
				elseif st == 3 then
					spurt:Emit(8)
					emit(bigCrumbs, 6)
				elseif st == 4 then
					emit(bigCrumbs, 8)
					emit(bigSeeds, 5)
				elseif st == 5 then
					emit(bigSeeds, 12)
				end
			end
			local sc = if st == 5 then 1 - 0.75 * smooth((tau - 3.1) / 0.6) else 1
			if math.abs(sc - bigScale) > 0.02 or (sc == 1 and bigScale ~= 1) then
				bigScale = sc
				big.Size = bigSize * sc
			end
		end)

		-- the rip's eruption round you: torn leaves (its Forge layer) and a geyser of dirt out of the whole emblem
		local ringPart = H.feetPiece(a, Vector3.new(5.4, 0.3, 5.4), 0.25)
		local ripLeaves = H.layer(a, LOOP, "Rip", ringPart)
		local geyser = H.E(ringPart, { tex = BFX.sand, colors = K.seq(CRUMB, CRUMB_D), rate = 0, life = { 0.6, 1 }, speed = { 9, 15 }, size = 0.4, accel = Vector3.new(0, -40, 0), spread = 18, light = 0, bright = 1 })
		dirt({ geyser })
		-- dirt kicked up when you walk, and a dirt trail behind you
		local kickAt = H.feetPiece(a, Vector3.new(1.4, 0.2, 1.4), 0.1)
		dirt(H.layer(a, LOOP, "Kick", kickAt, true, 0.85))
		local trailAt = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		local ft = K.trail(trailAt, Vector3.new(-0.7, 0.12, 0), Vector3.new(0.7, 0.12, 0), K.seq(CRUMB, CRUMB_D), 0.5, 0)
		K.bright(ft, 1)
		K.move(a, trailAt, function(f)
			return CFrame.new(f.feet) * f.yaw
		end)
		-- a few dirt crumbs off both hands (the card's gloved hand that pulled it)
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
			local list = H.layer(a, LOOP, "Crumbs", hp, false, 0.5)
			dirt(list)
			setRate(a, list, 1.5)
			H.detail(a, table.unpack(list))
		end
		-- white dandelion fluff drifting round you
		local fluff = H.layer(a, LOOP, "Seeds", K.bodyBox(a, Vector3.new(4, 4.4, 4), 0), false, 0.9)
		setRate(a, fluff, 2)
		for _, e in fluff do
			H.detail(a, e)
		end

		-- the Root Rip lands near you: the count starts again, the glove yanks a dandelion right out with a burst of 20
		-- clods and a puff of seeds, the seedlings are torn out (above), the circling dandelions yank up, leaves erupt,
		-- a gold ring flashes out
		H.gimmick(a, { rootRip = true }, 14, function(self, d)
			local s = H.swings({ player = self.owner })
			if s then
				self.ripBase = s
			end
			local now = os.clock()
			self.ripAt = now
			self.loopAt = now - T_YANK
			self.tugAt, self.tugAmp, self.tugDur = now, 1.3, 1
			spurt:Emit(20)
			emit(bigSeeds, 24)
			emit(ripLeaves, 14)
			emit(crumbs, 8)
			geyser:Emit(14)
			ripe:Emit(10)
			K.pulse(self.feetPos or (self.rootPos - Vector3.new(0, 2.7, 0)), 1, 7.5, GOLD, 0.5, 0.15)
		end)

		-- the entrance: the emblem grows in, the dandelions burst up out of the ground and fly out to circle you, the
		-- seedlings come up one after another, dirt and leaves burst up (the core plays the Form_WeedPuller burst too)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 8, CRUMB, 0.6, 0.12)
			emit(ripLeaves, 12)
			geyser:Emit(16)
		end
		return a
	end
end
