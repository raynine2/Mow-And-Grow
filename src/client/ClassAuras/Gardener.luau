-- GARDENER (Uncommon) - the card: a green-gloved hand holding red pruning shears, snipping a stem, leaves flying.
-- Gimmick: Green Thumb, bundles fly to you from much further away. Aura: a vine wreath with pink and yellow flowers under
-- you on a soft green glow, its eight flowers standing up off the ground as real blooms that pop up in turn; big red
-- pruning shears (two curved steel blades, red handles ending in loop grips, a gold pivot bolt) circling you at chest
-- height, turned to the camera, snapping shut on a green stem every 1.4 s (leaves burst off each snip, the stem grows
-- back); leaves and green wisps swirling round your chest; both hands glowing green and shedding leaves (the green
-- thumb, the card's green glove); a thick leafy vine twining up your legs; flowers popping up at your feet; and your
-- Green Thumb reach drawn as a faint ring far out round you, leaves drifting in from it (your own aura only: it's big).
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local LEAF = rgb(95, 190, 60)
	local LEAF_L = rgb(170, 235, 110)
	local LEAF_D = rgb(60, 145, 45)
	local PINK = rgb(255, 140, 200)
	local POLLEN = rgb(255, 215, 60)
	local RED = rgb(215, 35, 40)
	local STEEL = rgb(200, 208, 220)
	local EDGE = rgb(235, 245, 255)
	local GOLD = rgb(255, 196, 60)
	local REACH = 14 -- server/ClassPerks MAGNET_BONUS (studs further than everyone else)
	local SIGIL = 8.2
	local SPIN = 0.12 -- (the wreath's turn, rad/s)

	-- a placement worked out once per frame (a rig asks for it once per piece)
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
		local a = H.aura(H.RANK.Uncommon, LEAF)
		H.glowDisc(a, 8.5, BFX.glow, rgb(120, 220, 90), 0.55, 0, 0.06, 1.1)
		H.sigil(a, SIGIL, T.cVine, WHITE, 0, SPIN, 0.12, 0.7, 1.1)
		-- the wreath's flowers stand up off the ground as real blooms (pink and yellow in turn, as drawn on the wreath,
		-- turning with it) and pop up one after another round the ring
		local flowerR = SIGIL / 2 * 0.83
		for i = 1, 8 do
			local th0 = (i - 1) / 8 * math.pi * 2
			local bloom = H.ellipsoid(a.model, Vector3.new(0.78, 0.2, 0.78), if i % 2 == 1 then PINK else POLLEN, Enum.Material.SmoothPlastic)
			local eye = H.solid(a.model, Vector3.one * 0.26, rgb(255, 250, 225), Enum.Material.SmoothPlastic)
			eye.Shape = Enum.PartType.Ball
			local spot = perFrame(function(f)
				local k = ease((f.t - a.born) / 0.7)
				local th = th0 - f.t * SPIN
				local pop = math.max(0, math.sin(f.t * 1.6 - i * 0.785)) ^ 4
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * flowerR * k, 0.2 + 0.25 * pop, math.sin(th) * flowerR * k))
			end)
			K.move(a, bloom, spot)
			K.move(a, eye, function(f)
				return spot(f) * CFrame.new(0, 0.08, 0)
			end)
			H.detail(a, bloom, eye)
		end

		-- the pruning shears: two curved steel blades with bright cutting edges, red handles ending in loop grips, a gold
		-- pivot bolt; about 3.2 studs long, circling you at chest height, always turned to the camera (with a little sway)
		-- so the snip reads from every side
		local snip = 0 -- 0 open .. 1 shut
		local S = 0.92
		local shearsCF = perFrame(function(f)
			local k = ease((f.t - a.born - 0.2) / 0.7)
			local th = f.t * 0.75
			local pos = f.root.Position + Vector3.new(math.cos(th) * 3.4 * k, 0.8 + 0.2 * math.sin(f.t * 1.4), math.sin(th) * 3.4 * k)
			local cam = workspace.CurrentCamera
			local eye = if cam then cam.CFrame.Position else pos + f.yaw.LookVector * 10
			if (eye - pos).Magnitude < 0.1 then
				eye = pos + Vector3.zAxis
			end
			return CFrame.lookAt(pos, eye) * CFrame.Angles(0, 0.35 * math.sin(f.t * 0.9), math.rad(-38) + 0.12 * math.sin(f.t * 1.3))
		end)
		-- each half: a blade bulging out to its own side and curving back to the tip (shut, the two make a beak), and on
		-- the far side of the pivot a red handle with a loop grip; the halves swing open and shut about the bolt
		for _, s in { -1, 1 } do
			local z = s * 0.05
			local pieces = H.blade(a.body, {
				Vector3.new(0, -0.1, z) * S,
				Vector3.new(s * 0.09, 0.5, z) * S,
				Vector3.new(s * 0.04, 1.15, z) * S,
				Vector3.new(-s * 0.12, 1.6, z) * S,
			}, 0.44 * S, 0.1 * S, 0.08, STEEL, Enum.Material.Metal, EDGE, Vector3.new(0, 0, -s))
			local handle = H.blade(a.body, {
				Vector3.new(0, -0.05, z * 2) * S,
				Vector3.new(-s * 0.14, -0.6, z * 2) * S,
				Vector3.new(-s * 0.24, -1.15, z * 2) * S,
				Vector3.new(-s * 0.22, -1.6, z * 2) * S,
			}, 0.36 * S, 0.32 * S, 0.2, RED, Enum.Material.SmoothPlastic, nil, Vector3.zAxis)
			local grip = H.loop(a.body, 0.3 * S, 0.14, 6, RED, Enum.Material.SmoothPlastic, CFrame.new(Vector3.new(-s * 0.23, -1.9, z * 2) * S))
			for _, pc in handle do
				table.insert(pieces, pc)
			end
			for _, pc in grip do
				table.insert(pieces, pc)
			end
			H.rig(a, perFrame(function(f)
				return shearsCF(f) * CFrame.Angles(0, 0, -s * math.rad(30) * (1 - snip))
			end), pieces)
		end
		-- the gold pivot bolt (a short cylinder pointing at the camera)
		local bolt = H.cyl(a.body, 0.42, 0.34 * S, GOLD, Enum.Material.Metal, 0.3)
		K.move(a, bolt, function(f)
			return shearsCF(f) * CFrame.Angles(0, math.pi / 2, 0)
		end)
		-- the stem being cut: it runs across the jaws with a leaf at its end, is snipped through and grows back
		local stem = H.cyl(a.body, 1.5 * S, 0.13, LEAF_D, Enum.Material.SmoothPlastic)
		local stemLeaf = H.ellipsoid(a.body, Vector3.new(0.55, 0.3, 0.05), LEAF, Enum.Material.SmoothPlastic)
		K.move(a, stem, function(f)
			return shearsCF(f) * CFrame.new(0, 0.8 * S, 0)
		end)
		K.move(a, stemLeaf, function(f)
			return shearsCF(f) * CFrame.new(0.95 * S, 0.95 * S, 0) * CFrame.Angles(0, 0, math.rad(30))
		end)
		-- a short streak off the blade tips
		local tip = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, tip, function(f)
			return shearsCF(f) * CFrame.new(0, 1.6 * S, 0)
		end)
		H.trailed(tip, K.seq(WHITE, LEAF_L), 0.15, 0.16)
		local jaw = K.piece(a.body, Vector3.new(0.5, 0.5, 0.5))
		K.move(a, jaw, function(f)
			return shearsCF(f) * CFrame.new(0, 0.8 * S, 0)
		end)
		local snipLeaves = E(jaw, { tex = BFX.leaf, colors = K.seq(LEAF_L, LEAF), rate = 0, life = { 0.6, 1 }, speed = { 3, 6 }, size = 0.5, accel = Vector3.new(0, -6, 0), drag = 2, spin = 300, spread = 180, light = 0, bright = 1.2 })
		local snipSpark = E(jaw, { tex = T.glint, flip = 4, colors = K.seq(WHITE), rate = 0, life = { 0.2, 0.3 }, speed = { 0, 0 }, size = 1, spread = 0, light = 1, bright = 2 })
		-- snip every 1.4 s: snap shut, hold, ease open, wait; the stem is cut on the snap and grows back after
		local cutAt, cut = 0, false
		H.job(a, function(self, f)
			local ph = ((f.t - self.born) % 1.4) / 1.4
			local prev = snip
			if ph < 0.1 then
				snip = (ph / 0.1) ^ 2
			elseif ph < 0.24 then
				snip = 1
			elseif ph < 0.62 then
				snip = 1 - H.smooth((ph - 0.24) / 0.38)
			else
				snip = 0
			end
			if prev < 0.9 and snip >= 0.9 then
				cutAt, cut = f.t, true
				stem.Transparency = 1
				stemLeaf.Transparency = 1
				snipLeaves:Emit(7)
				snipSpark:Emit(1)
			elseif cut and f.t - cutAt > 0.5 then
				cut = false
				stem.Transparency = 0
				stemLeaf.Transparency = 0
			end
		end)

		-- leaves riding the breeze round your chest, with short green streaks
		for i = 1, 6 do
			local leaf = H.plate(a.body, 1.1, BFX.leaf, if i % 2 == 0 then LEAF else LEAF_L, 0, true, 1.1)
			local tr = H.trailed(leaf, K.seq(LEAF_L, LEAF), 0.3, 0.2)
			H.detail(a, tr)
			local off = (i - 1) / 6 * math.pi * 2
			K.move(a, leaf, function(f)
				local k = ease((f.t - a.born - i * 0.04) / 0.8)
				local th = -f.t * 1.3 + off
				local r = (2.1 + 0.25 * math.sin(f.t * 1.1 + off)) * k
				local pos = f.root.Position + Vector3.new(math.cos(th) * r, 0.55 + 0.35 * math.sin(f.t * 1.8 + off * 2), math.sin(th) * r)
				return CFrame.new(pos) * CFrame.Angles(math.sin(f.t * 2 + off) * 0.6, -th, math.cos(f.t * 2.3 + off) * 0.5)
			end)
		end
		-- the leaf-wisp aura: leaves and green wisps swirling round your chest (they ride a turning ring)
		local swirl = K.piece(a.body, Vector3.new(2.6, 1.8, 2.6))
		K.move(a, swirl, function(f)
			return CFrame.new(f.root.Position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, f.t * 2.4, 0)
		end)
		local swirlLeaves = E(swirl, { tex = BFX.leaf, colors = K.seq(LEAF_L, LEAF), rate = 12, life = { 0.9, 1.3 }, speed = { 0.2, 0.6 }, size = 0.6, sizeSeq = ns(0, 0.4, 0.5, 0.8, 1, 0.3), accel = Vector3.new(0, 0.8, 0), spin = 160, spread = 10, light = 0, bright = 1.2, shape = Enum.ParticleEmitterShape.Cylinder, surface = true, lock = true, trans = ns(0, 1, 0.15, 0, 0.8, 0.2, 1, 1) })
		local swirlWisps = E(swirl, { tex = T.wisp, colors = K.seq(LEAF_L, LEAF), rate = 6, life = { 0.6, 0.9 }, speed = { 0.2, 0.5 }, size = 0.9, accel = Vector3.new(0, 1.5, 0), spread = 10, light = 0.6, bright = 1.4, shape = Enum.ParticleEmitterShape.Cylinder, surface = true, lock = true, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.2, 0.35, 1, 1) })
		K.addEmitter(a, swirlLeaves)
		K.addEmitter(a, swirlWisps)
		H.detail(a, swirlWisps)
		-- the green thumb: both hands glow green and shed leaves (the card's green glove)
		for _, hand in { "RightHand", "LeftHand" } do
			local h = K.piece(a.body, Vector3.new(0.5, 0.5, 0.5))
			K.move(a, h, function(f)
				local l = H.limb(f, hand)
				if not l then
					return f.root
				end
				-- (an R6 arm is a long block: its hand is at the bottom)
				return l.CFrame * CFrame.new(0, if l.Size.Y > 1.2 then -0.8 else -0.1, 0)
			end)
			local glow = E(h, { tex = K.FX.glow, colors = K.seq(LEAF_L, LEAF), rate = 5, life = { 0.4, 0.6 }, speed = { 0, 0 }, size = 1.3, spread = 0, light = 1, bright = 1.3, lock = true, trans = ns(0, 1, 0.3, 0.4, 1, 1) })
			local shed = E(h, { tex = BFX.leaf, colors = K.seq(LEAF_L, LEAF), rate = 3, life = { 0.6, 1 }, speed = { 0.6, 1.4 }, size = 0.4, accel = Vector3.new(0, -3, 0), drag = 1, spin = 240, spread = 180, light = 0, bright = 1.2 })
			local motes = E(h, { tex = T.glint, flip = 4, colors = K.seq(WHITE, LEAF_L), rate = 3, life = { 0.4, 0.7 }, speed = { 0.2, 0.6 }, size = 0.35, spread = 180, light = 1, bright = 2 })
			K.addEmitter(a, glow)
			K.addEmitter(a, shed)
			K.addEmitter(a, motes)
			H.detail(a, motes)
		end
		-- a thick leafy vine twining up your legs to your waist: two strands, and leaves standing off them
		do
			local holder = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			local vineCF = perFrame(function(f)
				return CFrame.new(f.root.Position) * CFrame.Angles(0, f.t * 0.6, 0)
			end)
			K.move(a, holder, vineCF)
			local leaves = {}
			for strand = 0, 1 do
				local pts = {}
				for k = 0, 12 do
					local tt = k / 12
					local th = tt * math.pi * 2.5 + strand * math.pi
					local r = 1.05 - 0.25 * tt
					local p = Vector3.new(math.cos(th) * r, -2.8 + tt * 3.4, math.sin(th) * r)
					table.insert(pts, p)
					if k == 3 or k == 7 or k == 11 then
						local out = Vector3.new(math.cos(th), 0, math.sin(th))
						local leaf = H.ellipsoid(a.body, Vector3.new(0.32, 0.05, 0.62), if k == 7 then LEAF_L else LEAF, Enum.Material.SmoothPlastic)
						table.insert(leaves, { leaf, CFrame.lookAt(p, p + out) * CFrame.Angles(math.rad(30), 0, 0) * CFrame.new(0, 0, -0.3) })
					end
				end
				local vine = H.chain(holder, pts, { colors = K.seq(LEAF_L, LEAF), w0 = 0.95, w1 = 0.35, tex = T.vineStrip, texLen = 1.4, texSpeed = 0.35, light = 0.4, bright = 1.4 })
				if strand == 1 then
					for _, b in vine do
						H.detail(a, b)
					end
				end
			end
			H.rig(a, vineCF, leaves)
		end
		local body = K.bodyBox(a, Vector3.new(4, 4, 4), -0.2)
		local pollen = E(body, { tex = T.glint, flip = 4, colors = K.seq(POLLEN, WHITE), rate = 4, life = { 1.2, 1.8 }, speed = { 0.2, 0.6 }, size = 0.4, accel = Vector3.new(0, 0.5, 0), spread = 180, light = 1, bright = 1.8 })
		K.addEmitter(a, pollen)
		H.detail(a, pollen)
		local bed = H.feetPiece(a, Vector3.new(5, 0.2, 5), 0.25)
		local blooms = E(bed, { tex = BFX.petal, colors = K.seq(PINK, POLLEN, PINK), rate = 4, life = { 0.9, 1.4 }, speed = { 0.6, 1.2 }, size = 0.75, grow = true, spin = 60, spread = 15, light = 0.3, bright = 1.3, shape = Enum.ParticleEmitterShape.Disc })
		K.addEmitter(a, blooms)
		-- Green Thumb: your reach, a faint ring of leaves far out, and leaves drifting in from it (your own aura)
		local reach, rimgs, rguis = H.glowDisc(a, (REACH + 4) * 2 / 0.92, T.ringCrisp, LEAF_L, 0.72, 0.05, 0.16, 1)
		local inbound = H.feetPiece(a, Vector3.new((REACH + 4) * 2, 1, (REACH + 4) * 2), 0.8)
		local pull = E(inbound, { tex = BFX.leaf, colors = K.seq(LEAF_L, LEAF), rate = 3, life = { 1.6, 2 }, speed = { 9, 11 }, size = 0.5, spin = 200, spread = 0, light = 0, bright = 1.2, shape = Enum.ParticleEmitterShape.Cylinder, inward = true, surface = true, trans = ns(0, 1, 0.15, 0.2, 0.85, 0.3, 1, 1) })
		K.addEmitter(a, pull)
		local mine = nil
		H.job(a, function(self, f)
			local own = f.player ~= nil and f.player == H.player
			if own ~= mine then
				mine = own
				for _, g in rguis do
					g.Enabled = own
				end
				pull.Enabled = own
			end
		end)
		H.shell(a, K.seq(LEAF_L, LEAF), 5, 0.95)
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.2, 1.2), 0.1)
		K.addEmitter(a, E(kick, { tex = BFX.petal, colors = K.seq(PINK, POLLEN, WHITE), rate = 9, life = { 0.6, 1 }, speed = { 1.5, 3 }, size = 0.5, accel = Vector3.new(0, -6, 0), spin = 200, spread = 50, light = 0.2 }), true)
		K.feetTrail(a, K.seq(LEAF_L, LEAF))
		K.light(a, LEAF, 0.8, 10)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 10, LEAF_L, 0.7, 0.1)
			blooms:Emit(14)
			snipLeaves:Emit(10)
			pollen:Emit(10)
			swirlLeaves:Emit(12)
		end
		_ = reach
		_ = rimgs
		return a
	end
end
