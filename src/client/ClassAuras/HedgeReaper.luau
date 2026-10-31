-- HEDGE REAPER (Epic) - the class: a hooded reaper whose scythe's wooden handle is wrapped in a flowering vine, cutting a
-- hedge in one sweep (the card's purple is the Epic rarity's colour, not the reaper's: the aura is hedge green, bramble
-- dark, a pale steel blade and mint ghost-light). Gimmick: Reap Wave, every 8th swing sends a wave that hits every clump
-- round you. Aura: a ring of bramble thorns on a dark pool under you, dark fog; the great scythe (half again your height:
-- a solid pale-steel crescent with a thin glowing mint edge on a wooden handle wrapped in a vine in pink and white
-- flower) hovering on a slant at your back, that every 5 s swings down off your back and sweeps a full circle round you;
-- a ring of six tall clipped hedges that the sweep trims as it passes (leaves fly, a ghost ring rolls out, they grow
-- back); cyan-white soul-fire rising off the top of your head and your shoulders (clear of your face) and off your
-- hands, mint soul orbs on trails, ghost-light rising off the thorn ring; and eight soul flames round your feet that
-- light up swing by swing to the Reap Wave (the wave trims every hedge at once).
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local HEDGE = rgb(45, 135, 60)
	local HEDGE_TOP = rgb(75, 165, 80)
	local HEDGE_L = rgb(150, 235, 140)
	local HEDGE_D = rgb(10, 38, 18)
	local STEEL = rgb(208, 224, 220) -- the pale steel blade
	local BLOOM = rgb(255, 170, 215)
	local MINT = rgb(110, 255, 215)
	local GHOST = rgb(175, 255, 240) -- mint pushed toward cyan-white (the ghost-light)
	local GHOST_W = rgb(232, 255, 252)
	local WOOD = rgb(100, 60, 38)
	local CORD = rgb(185, 130, 75)
	local VINE = rgb(90, 175, 70)
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing along its rig's Y)
	-- the scythe's sweep pose (in a frame at your root turned to the sweep's angle): the handle slopes from just over
	-- your head down and out to the hedge ring, the blade lying along the ring at hedge height, its tip leading
	local SWEEP_EVERY, SWEEP_TIME = 5, 1.1
	local SWEEP_POSE = CFrame.fromMatrix(Vector3.new(0, 0.8, 2.44), Vector3.new(-1, 0, 0), Vector3.new(0, -0.774, 0.632).Unit)
	local HEDGES, HEDGE_R = 6, 4.6

	return function()
		local a = H.aura(H.RANK.Epic, HEDGE)
		H.sigil(a, 10.5, T.cThorn, WHITE, 0, -0.18, 0.12, 0.8, 1.1)
		H.glowRing(a, 5.6, MINT, 0.35, 0, 0.16, 1.2)
		local fogBase = H.feetPiece(a, Vector3.new(8, 0.3, 8), 0.3)
		local fog = E(fogBase, { tex = BFX.smoke or FX.smoke, colors = K.seq(rgb(18, 48, 26), rgb(6, 20, 10)), rate = 6, life = { 2.2, 3 }, speed = { 0.2, 0.5 }, size = 3.4, grow = true, spin = 20, spread = 70, light = 0, bright = 1, shape = Enum.ParticleEmitterShape.Disc, trans = ns(0, 1, 0.3, 0.4, 1, 1) })
		K.addEmitter(a, fog)

		-- the scythe: at rest it hovers on a slant at your back (blade over your shoulder, hooking down); every 5 s it
		-- swings down into the sweep pose and goes a full circle round you. (Worked out once per frame: ~45 pieces ride it.)
		local cacheT, cacheCF = -1, CFrame.identity
		local function scytheCF(f): CFrame
			if f.t == cacheT then
				return cacheCF
			end
			local k = ease((f.t - a.born - 0.3) / 0.8)
			local cf = f.root * CFrame.new(0.25, 0.85 + 0.15 * math.sin(f.t * 1.3) + 3 * (1 - k), 1.0) * CFrame.Angles(0, math.pi, math.rad(-32))
			local p = ((f.t - a.born) % SWEEP_EVERY) / SWEEP_TIME
			if p < 1 then
				local b = H.smooth(p / 0.15) * H.smooth((1 - p) / 0.15)
				local phi = H.smooth(p) * math.pi * 2
				local sweep = CFrame.new(f.root.Position) * f.yaw * CFrame.Angles(0, -phi, 0) * SWEEP_POSE
				cf = cf:Lerp(sweep, b)
			end
			cacheT, cacheCF = f.t, cf
			return cf
		end
		local holder = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, holder, scytheCF)
		-- the handle: a long wooden shaft (6.2 studs) with a hand grip, two cord bindings, a steel collar at the top and
		-- a glowing mint pommel
		local pommel = H.solid(a.body, Vector3.new(0.36, 0.36, 0.36), GHOST, Enum.Material.Neon)
		pommel.Shape = Enum.PartType.Ball
		local pieces = {
			{ H.cyl(a.body, 6.2, 0.26, WOOD, Enum.Material.Wood), UP },
			{ pommel, CFrame.new(0, -3.15, 0) },
			{ H.cyl(a.body, 0.42, 0.34, STEEL, Enum.Material.Metal, 0.25), CFrame.new(0, 2.92, 0) * UP },
			{ H.cyl(a.body, 0.2, 0.33, CORD, Enum.Material.Fabric), CFrame.new(0, 2.15, 0) * UP },
			{ H.cyl(a.body, 0.2, 0.33, CORD, Enum.Material.Fabric), CFrame.new(0, -1.3, 0) * UP },
			{ H.cyl(a.body, 0.7, 0.2, WOOD, Enum.Material.Wood), CFrame.new(0.38, 0.5, 0) },
		}
		-- the blade: a solid pale-steel crescent from the collar out over a crest and hooking down to a point, wide at
		-- the heel and tapering, a thin glowing mint edge along the inside of the curve (the plane's normal is +Z, so
		-- H.blade puts the edge on the concave side)
		local bpts = {}
		for k = 0, 11 do
			local t = k / 11
			table.insert(bpts, Vector3.new(-0.25 + 4.1 * t - 0.6 * t ^ 3, 2.95 + 0.9 * math.sin(math.pi * 0.85 * t) - 2.0 * t ^ 2.2, 0))
		end
		for _, pc in H.blade(a.body, bpts, 1.0, 0.08, 0.12, STEEL, Enum.Material.Metal, MINT, Vector3.zAxis) do
			-- (each segment a touch longer, so the outside of the curve shows no notches between them)
			local part = pc[1] :: BasePart
			part.Size += Vector3.new(0, 0, part.Size.X * 0.22)
			table.insert(pieces, pc)
		end
		H.rig(a, scytheCF, pieces)
		-- the vine wrapped round the handle, in flower (pink and white) with a few leaves
		local vpts = {}
		for k = 0, 26 do
			local tt = k / 26
			local th = tt * math.pi * 10
			table.insert(vpts, Vector3.new(math.cos(th) * 0.17, -2.9 + tt * 5.6, math.sin(th) * 0.17))
		end
		H.chain(holder, vpts, { colors = K.seq(rgb(120, 210, 90), VINE), w0 = 0.12, w1 = 0.09, light = 0.25, bright = 1.2 })
		local deco = {}
		for n, k in { 3, 7, 11, 15, 19, 23 } do
			local fl = H.solid(a.body, Vector3.new(0.26, 0.26, 0.26), if n % 2 == 0 then WHITE else BLOOM, Enum.Material.Neon)
			fl.Shape = Enum.PartType.Ball
			table.insert(deco, { fl, CFrame.new(vpts[k + 1] * Vector3.new(1.5, 1, 1.5)) })
		end
		for _, k in { 5, 9, 17, 21 } do
			local v = vpts[k + 1]
			local leaf = H.solid(a.body, Vector3.new(0.3, 0.05, 0.16), rgb(110, 200, 80), Enum.Material.SmoothPlastic)
			table.insert(deco, { leaf, CFrame.new(v * Vector3.new(1.7, 1, 1.7)) * CFrame.Angles(0, -math.atan2(v.Z, v.X), math.rad(30)) })
		end
		H.rig(a, scytheCF, deco)
		-- a mint ghost trail off the tip (it draws the sweep's arc), a few ghost wisps at the tip, glints on the steel
		local TIP = bpts[#bpts]
		local tip = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, tip, function(f)
			return scytheCF(f) * CFrame.new(TIP)
		end)
		H.trailed(tip, K.seq(GHOST, MINT, HEDGE), 0.35, 0.7)
		local slashFx = E(tip, { tex = T.wisp, colors = K.seq(GHOST, MINT), rate = 4, life = { 0.4, 0.7 }, speed = { 0.2, 0.6 }, size = 0.7, spread = 180, light = 1, bright = 1.6 })
		K.addEmitter(a, slashFx)
		H.detail(a, slashFx)
		local steel = K.piece(a.body, Vector3.new(3.4, 1.4, 0.2))
		K.move(a, steel, function(f)
			return scytheCF(f) * CFrame.new(1.5, 2.9, 0)
		end)
		local glints = E(steel, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GHOST), rate = 4, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 0.55, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, glints)
		H.detail(a, glints)

		-- a ring of six tall clipped hedges round you (they fade while you run): each a box with softened corners (two
		-- crossed blocks) and a rounded top, a pink bloom on it. The sweep trims each one as it passes: it's cut down,
		-- its top clipped flat and fresh green, leaves fly, and it grows back over two seconds.
		local hedges = {}
		for i = 1, HEDGES do
			local th = (i - 0.5) / HEDGES * math.pi * 2
			local wide = H.solid(a.body, Vector3.new(1.2, 1.45, 1.0), HEDGE, Enum.Material.Grass)
			local deep = H.solid(a.body, Vector3.new(1.0, 1.45, 1.2), HEDGE, Enum.Material.Grass)
			local cap = H.ellipsoid(a.body, Vector3.new(1.14, 0.36, 1.14), HEDGE_TOP, Enum.Material.Grass)
			local bloom = H.solid(a.body, Vector3.new(0.22, 0.22, 0.22), BLOOM, Enum.Material.Neon)
			bloom.Shape = Enum.PartType.Ball
			local h = { th = th, cut = 0, sized = false, parts = { wide, deep, cap, bloom } }
			hedges[i] = h
			local function at(f): CFrame
				return CFrame.new(f.feet) * f.yaw * CFrame.Angles(0, -th, 0) * CFrame.new(0, 0, HEDGE_R)
			end
			K.move(a, wide, function(f)
				return at(f) * CFrame.new(0, 0.725 * (1 - 0.4 * h.cut), 0)
			end)
			K.move(a, deep, function(f)
				return at(f) * CFrame.new(0, 0.725 * (1 - 0.4 * h.cut), 0)
			end)
			K.move(a, cap, function(f)
				return at(f) * CFrame.new(0, 1.45 * (1 - 0.4 * h.cut), 0)
			end)
			K.move(a, bloom, function(f)
				return at(f) * CFrame.new(0.4, 1.45 * (1 - 0.4 * h.cut) + 0.1, -0.38)
			end)
			local leafBox = K.piece(a.body, Vector3.new(1.2, 0.5, 1.2))
			K.move(a, leafBox, function(f)
				return at(f) * CFrame.new(0, 1.3, 0)
			end)
			h.leaves = E(leafBox, { tex = BFX.leaf, colors = K.seq(rgb(150, 230, 110), HEDGE), rate = 0, life = { 0.6, 1 }, speed = { 4, 8 }, size = 0.5, accel = Vector3.new(0, -10, 0), drag = 2, spin = 300, spread = 70, light = 0, bright = 1.2 })
		end
		local lastPhi = 0
		local lastHide = -1
		local lastCycle = -1
		H.job(a, function(self, f)
			local age = f.t - self.born
			local p = (age % SWEEP_EVERY) / SWEEP_TIME
			local phi = if p < 1 then H.smooth(p) * math.pi * 2 else 0
			-- each sweep rolls a ghost ring out to the hedges
			local cycle = math.floor(age / SWEEP_EVERY)
			if cycle ~= lastCycle then
				lastCycle = cycle
				if cycle > 0 and not self.lowNow then
					K.pulse(f.feet, 2, HEDGE_R * 2 + 2, GHOST, 0.9, 0.3)
				end
			end
			for _, h in hedges do
				if p < 1 and h.th > lastPhi and h.th <= phi then
					h.cut = 1
					h.leaves:Emit(8)
				elseif h.cut > 0 then
					h.cut = math.max(0, h.cut - 0.008)
				end
				if h.cut > 0 or h.sized then
					h.sized = h.cut > 0
					local s = 1 - 0.4 * h.cut
					h.parts[1].Size = Vector3.new(1.2, 1.45 * s, 1.0)
					h.parts[2].Size = Vector3.new(1.0, 1.45 * s, 1.2)
					h.parts[3].Size = Vector3.new(1.14, 0.36 * (1 - 0.6 * h.cut), 1.14)
					h.parts[3].Color = HEDGE_TOP:Lerp(HEDGE_L, h.cut)
				end
			end
			lastPhi = phi
			local hide = math.floor(math.clamp((1 - f.calm) * 1.6, 0, 1) * 20 + 0.5) / 20
			if hide ~= lastHide then
				lastHide = hide
				for _, h in hedges do
					for _, part in h.parts do
						part.LocalTransparencyModifier = hide
					end
				end
			end
		end)

		-- the Reap Wave: eight soul flames round your feet, one lit per swing (a little cyan-white flame burns on each lit
		-- one); the eighth swing is the wave
		local function reapCount(f): number?
			local s = H.swings(f)
			if s == nil then
				return nil
			end
			return ((a.reapBase and s - a.reapBase) or s) % 8
		end
		local pips = H.pips(a, 8, 3.5, rgb(35, 70, 60), GHOST, 0.4, reapCount)
		local pipFire = {}
		for i, p in pips do
			local fl = E(p, { tex = T.flame, flip = 4, colors = K.seq(GHOST_W, MINT, HEDGE_D), rate = 0, life = { 0.4, 0.6 }, speed = { 1, 1.8 }, size = 0.7, accel = Vector3.new(0, 3, 0), spread = 8, light = 0.8, bright = 1.6, rot = { -15, 15 } })
			pipFire[i] = fl
			H.detail(a, fl)
		end
		local lastLit = -2
		H.job(a, function(self, f)
			local c = reapCount(f) or -1
			if c ~= lastLit then
				lastLit = c
				for i, fl in pipFire do
					fl.Rate = if i <= c then 5 else 0
				end
			end
		end)
		-- mint soul orbs spiralling up and down on long trails
		for i = 1, 3 do
			local orb = K.piece(a.body, Vector3.new(0.38, 0.38, 0.38), GHOST, 0)
			orb.Shape = Enum.PartType.Ball
			local tr = H.trailed(orb, K.seq(GHOST_W, MINT, HEDGE), 1, 0.35)
			if i == 3 then
				H.detail(a, orb, tr)
			end
			local off = (i - 1) / 3 * math.pi * 2
			K.move(a, orb, function(f)
				local th = -f.t * 1.6 + off
				local y = 1.8 * math.sin(f.t * 0.9 + off)
				local r = 2.4 + 0.3 * math.cos(f.t * 0.9 + off)
				return CFrame.new(f.root.Position + Vector3.new(math.cos(th) * r, y, math.sin(th) * r))
			end)
		end
		-- soul-fire: a crown of cyan-white ghost flames rising off the top of your head and off both shoulders (it starts
		-- above your hair and beside your head, so your face stays clear), and off your hands
		local FIRE = K.seq(GHOST_W, GHOST, rgb(40, 170, 150))
		local crown = K.piece(a.body, Vector3.new(0.8, 0.2, 0.8))
		K.move(a, crown, function(f)
			return CFrame.new(f.head + Vector3.new(0, 0.5, 0)) * f.yaw
		end)
		local fire = E(crown, { tex = T.flame, flip = 4, colors = FIRE, rate = 10, life = { 0.6, 0.9 }, speed = { 1.8, 2.8 }, size = 1.4, accel = Vector3.new(0, 3, 0), spread = 6, light = 0.6, bright = 1.7, rot = { -12, 12 }, trans = ns(0, 0.3, 0.5, 0.35, 1, 1), sizeSeq = ns(0, 0.9, 0.3, 1.5, 1, 0.4) })
		K.addEmitter(a, fire)
		for _, side in { -1, 1 } do
			local sh = K.piece(a.body, Vector3.new(0.5, 0.2, 0.5))
			K.move(a, sh, function(f)
				return f.root * CFrame.new(side * 1.15, 1.45, 0.1)
			end)
			local sf = E(sh, { tex = T.flame, flip = 4, colors = FIRE, rate = 7, life = { 0.5, 0.8 }, speed = { 1.6, 2.4 }, size = 1, accel = Vector3.new(0, 3, 0), spread = 6, light = 0.6, bright = 1.6, rot = { -12, 12 }, trans = ns(0, 0.3, 0.5, 0.4, 1, 1), sizeSeq = ns(0, 0.6, 0.3, 1.1, 1, 0.3) })
			K.addEmitter(a, sf)
			H.detail(a, sf)
		end
		for _, hand in { "RightHand", "LeftHand" } do
			local h = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
			K.move(a, h, function(f)
				local l = H.limb(f, hand)
				return if l then l.CFrame else f.root
			end)
			local hf = E(h, { tex = T.flame, flip = 4, colors = K.seq(GHOST_W, MINT, HEDGE_D), rate = 6, life = { 0.4, 0.6 }, speed = { 1, 2 }, size = 1, accel = Vector3.new(0, 4, 0), spread = 10, light = 1, bright = 1.4, rot = { -15, 15 } })
			K.addEmitter(a, hf)
			H.detail(a, hf)
		end
		H.shell(a, K.seq(GHOST, MINT, HEDGE), 8, 1)
		H.updraft(a, 4.8, K.seq(GHOST_W, GHOST, MINT), 9, T.wisp, 1.1)
		K.feetTrail(a, K.seq(GHOST, MINT, HEDGE_D))
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.3, 1.2), 0.3)
		K.addEmitter(a, E(kick, { tex = T.wisp, colors = K.seq(GHOST, MINT), rate = 9, life = { 0.5, 0.8 }, speed = { 1, 2.5 }, size = 1.1, accel = Vector3.new(0, 3, 0), spread = 40, light = 1, bright = 1.6 }), true)
		-- a mint outline only: the body itself isn't tinted
		local hl = K.outline(a, GHOST, 0.35)
		if hl then
			hl.FillTransparency = 1
		end
		K.light(a, MINT, 1.1, 12)
		H.lightJob(a, 0.25)
		local base = H.feetPiece(a, Vector3.new(2, 0.3, 2), 0.3)
		local burst = E(base, { tex = T.wisp, colors = K.seq(GHOST_W, MINT, HEDGE), rate = 0, life = { 0.6, 1 }, speed = { 8, 12 }, size = 1.3, accel = Vector3.new(0, 4, 0), drag = 2, spread = 80, light = 1, bright = 1.8 })
		-- the wave: soul burst, every hedge trimmed at once, the flames start again
		H.gimmick(a, { reapWave = true }, 16, function(self, d)
			local s = H.swings({ player = self.owner })
			if s then
				self.reapBase = s
			end
			burst:Emit(16)
			for _, h in hedges do
				h.cut = 1
				h.leaves:Emit(6)
			end
			self.lightKick = 3
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 14, HEDGE_L, 0.8, 0)
			K.pulse(feet, 1, 9, GHOST, 0.55, 0.2)
			fire:Emit(10)
			fog:Emit(4)
			burst:Emit(12)
			self.lightKick = 3
		end
		return a
	end
end
