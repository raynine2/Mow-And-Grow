-- ULTIMATE GARDENER (Legendary) - the card: a golden watering can pouring a stream of liquid gold. Gimmick: Midas
-- Touch, every 20th clump you uncover is a mutation (Golden or better). Aura: an ornate golden watering can (a round
-- body with a domed top, a long spout with a rose, a curved handle, polished gold with bright bands and sun medallions,
-- glinting) circling you and pouring a thick stream of liquid gold down to the ground (droplets and sparkles along it, a
-- gold puddle and little golden sprouts where it lands); a sunburst sigil under you; a sunflower halo turning in a ring
-- of sun rays, up and back from your head; golden wings with leafy green vines along their top edges, breathing; light
-- falling on you from above; pollen and gold petals; a gold aura and outline. When the Midas Touch lands, the can tips
-- right over and gushes, and the whole aura flares gold.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local SUN = rgb(255, 200, 60)
	local SUN_L = rgb(255, 240, 170)
	local GOLD = rgb(255, 196, 50)
	local AMBER = rgb(240, 140, 20)
	local LEAF = rgb(100, 180, 60)
	local LEAF_L = rgb(150, 215, 85)
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing up)
	local SIDE = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder lying along Z)
	-- the can's spout leaves the body low on its outer side and rises at 38 degrees; the rose sits at its end
	local SP0 = Vector3.new(0.62, -0.3, 0)
	local SPA = math.rad(38)
	local SPD = Vector3.new(math.cos(SPA), math.sin(SPA), 0)
	local ROSE = 2.32
	local LEAD = math.rad(55) -- (the spout points out and this far ahead, the way the can travels)
	local function onSpout(d: number): CFrame
		return CFrame.new(SP0 + SPD * d) * CFrame.Angles(0, 0, SPA)
	end
	-- the wings: their size, and the top edge of the left wing's art (u, v), root to tip, where the vine runs
	local WING = 5
	local EDGE = { { 0.92, 0.47 }, { 0.8, 0.34 }, { 0.68, 0.24 }, { 0.55, 0.17 }, { 0.42, 0.135 }, { 0.3, 0.135 }, { 0.2, 0.2 }, { 0.12, 0.31 } }

	-- a group's base worked out once per frame (every part of a rig asks for it)
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
	local function metal(p: BasePart): BasePart -- (polished: a touch of reflection)
		p.Reflectance = 0.3
		return p
	end

	return function()
		local a = H.aura(H.RANK.Legendary, SUN)
		H.glowDisc(a, 10, BFX.glow, SUN, 0.55, 0, 0.06, 1)
		H.sigil(a, 11.5, T.cSun, WHITE, 0, 0.1, 0.12, 1, 1.1)
		H.glowRing(a, 5.9, SUN_L, 0.2, 0, 0.15, 1.3)
		-- the golden watering can (the card): it circles you above your shoulders, spout pointing out, tipped to pour
		local tip = 0 -- extra tip when the Midas Touch lands
		local canCF = once(function(f): CFrame
			local k = ease((f.t - a.born - 0.3) / 0.8)
			local th = f.t * 0.45
			local pos = f.root.Position + Vector3.new(math.cos(th) * 2.8 * k, 1.7 + 0.15 * math.sin(f.t * 1.5), math.sin(th) * 2.8 * k)
			-- local +X (the spout side) points outward and ahead, so it waters the sun ring as it goes; tip forward round
			-- the local Z axis
			return CFrame.new(pos) * CFrame.Angles(0, -th - LEAD, 0) * CFrame.Angles(0, 0, -math.rad(24 + 38 * tip))
		end)
		local body = H.cyl(a.body, 1.1, 1.5, GOLD, Enum.Material.Metal, 0.3)
		local can = {
			{ body, UP }, -- the body
			{ metal(H.ellipsoid(a.body, Vector3.new(1.5, 0.9, 1.5), GOLD, Enum.Material.Metal)), CFrame.new(0, 0.55, 0) }, -- its domed top
			{ metal(H.ellipsoid(a.body, Vector3.new(1.5, 0.36, 1.5), AMBER, Enum.Material.Metal)), CFrame.new(0, -0.55, 0) }, -- its rounded base
			{ H.cyl(a.body, 0.12, 1.58, AMBER, Enum.Material.Metal, 0.3), CFrame.new(0, -0.48, 0) * UP }, -- the foot ring
			{ H.cyl(a.body, 0.1, 1.56, SUN_L, Enum.Material.Neon), CFrame.new(0, 0.18, 0) * UP }, -- a bright band
			{ H.cyl(a.body, 0.07, 1.53, SUN_L, Enum.Material.Neon), CFrame.new(0, 0.55, 0) * UP }, -- the shoulder seam
		}
		-- a sun medallion on each flank: a bright disc with a gold boss
		for _, z in { -1, 1 } do
			table.insert(can, { H.cyl(a.body, 0.06, 0.62, SUN_L, Enum.Material.Neon), CFrame.new(0, -0.08, z * 0.73) * SIDE })
			table.insert(can, { metal(H.ellipsoid(a.body, Vector3.new(0.3, 0.3, 0.12), GOLD, Enum.Material.Metal)), CFrame.new(0, -0.08, z * 0.78) })
		end
		-- the long spout (wide at the body, narrowing past a bright collar) and the rose: a bulb, a wide sprinkler face
		-- and light shining through its holes
		table.insert(can, { H.cyl(a.body, 1.1, 0.34, GOLD, Enum.Material.Metal, 0.3), onSpout(0.55) })
		table.insert(can, { H.cyl(a.body, 1.05, 0.24, GOLD, Enum.Material.Metal, 0.3), onSpout(1.55) })
		table.insert(can, { H.cyl(a.body, 0.08, 0.38, SUN_L, Enum.Material.Neon), onSpout(1.08) })
		table.insert(can, { metal(H.ellipsoid(a.body, Vector3.new(0.42, 0.46, 0.46), GOLD, Enum.Material.Metal)), onSpout(2.06) })
		table.insert(can, { H.cyl(a.body, 0.12, 0.64, SUN_L, Enum.Material.Metal, 0.3), onSpout(2.22) })
		table.insert(can, { H.cyl(a.body, 0.03, 0.5, rgb(255, 250, 225), Enum.Material.Neon), onSpout(2.29) })
		-- the handle: a curved loop over the top and back of the can (the part of the loop inside the can is left out)
		for _, pc in H.loop(a.body, 0.62, 0.15, 12, GOLD, Enum.Material.Metal, CFrame.new(-0.45, 0.8, 0)) do
			local p = (pc[2] :: CFrame).Position
			local r = math.sqrt(p.X * p.X + p.Z * p.Z)
			local inside = if p.Y < 0.55 then r < 0.68 else (r / 0.75) ^ 2 + ((p.Y - 0.55) / 0.45) ^ 2 < 0.8
			local part = pc[1] :: BasePart
			if inside then
				part:Destroy()
			else
				metal(part)
				table.insert(can, pc)
			end
		end
		H.rig(a, canCF, can)
		local shine = E(body, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 3, life = { 0.3, 0.5 }, speed = { 0, 0.1 }, size = 0.7, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, shine)
		H.detail(a, shine)
		-- the pour: a thick stream of liquid gold arcing from the rose down to the ground (a solid gold beam with a
		-- flowing shimmer over it), gold droplets and sparkles along it, a gold puddle and golden sprouts where it lands
		local roseAt = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
		K.move(a, roseAt, function(f)
			return canCF(f) * onSpout(ROSE)
		end)
		local landCF = once(function(f): CFrame
			local cf = canCF(f) * onSpout(ROSE)
			local d = cf.XVector
			return CFrame.new(cf.X + d.X * 1.7, f.feet.Y + 0.05, cf.Z + d.Z * 1.7)
		end)
		local land = K.piece(a.model, Vector3.new(1.4, 0.2, 1.4))
		K.move(a, land, landCF)
		local from = H.att(roseAt, Vector3.zero) -- (its axis runs along the spout, so the stream leaves the rose that way)
		local to = H.att(land, Vector3.zero)
		to.CFrame = CFrame.Angles(0, 0, -math.pi / 2) -- (its axis points down, so the stream falls into the ground)
		local pour = H.beam(from, to, { colors = K.seq(SUN_L, GOLD, AMBER), w0 = 0.55, w1 = 0.4, light = 0.5, bright = 1.4, segments = 14, curve0 = 1.1, curve1 = 2.2 })
		local sheen = H.beam(from, to, { colors = K.seq(SUN_L, SUN, GOLD), w0 = 0.7, w1 = 0.5, trans = NumberSequence.new(0.35), light = 0.8, bright = 1.4, segments = 14, curve0 = 1.1, curve1 = 2.2, tex = T.energy, texLen = 1.6, texSpeed = 2.4, zoff = 0.02 })
		H.detail(a, sheen)
		local stream = E(roseAt, { tex = T.streak, colors = K.seq(SUN_L, GOLD), rate = 12, life = { 0.65, 0.75 }, speed = { 2.2, 2.8 }, size = 0.3, accel = Vector3.new(0, -20, 0), spread = 6, light = 1, bright = 1.6, dir = Enum.NormalId.Right, orient = Enum.ParticleOrientation.VelocityParallel })
		K.addEmitter(a, stream)
		local drops = E(roseAt, { tex = T.glint, flip = 4, colors = K.seq(SUN_L, GOLD), rate = 8, life = { 0.6, 0.75 }, speed = { 2, 3 }, size = 0.45, accel = Vector3.new(0, -20, 0), spread = 14, light = 1, bright = 1.8, dir = Enum.NormalId.Right })
		K.addEmitter(a, drops)
		H.detail(a, drops)
		local puddle = H.plate(a.model, 1.9, BFX.glow, GOLD, 0.3, false, 1.2)
		K.move(a, puddle, function(f)
			return landCF(f) * CFrame.new(0, 0.04, 0)
		end)
		local sprouts = E(land, { tex = BFX.leaf, colors = K.seq(SUN_L, GOLD), rate = 5, life = { 0.8, 1.2 }, speed = { 0.8, 1.6 }, size = 0.6, grow = true, spin = 60, spread = 15, light = 0.6, bright = 1.6, shape = Enum.ParticleEmitterShape.Disc })
		K.addEmitter(a, sprouts)
		local splash = E(land, { tex = T.glint, flip = 4, colors = K.seq(SUN_L, GOLD), rate = 6, life = { 0.3, 0.5 }, speed = { 1, 3 }, size = 0.6, spread = 60, light = 1, bright = 2 })
		K.addEmitter(a, splash)
		-- the halo: a sunflower turning inside a ring of sun rays, raised up and back from your head (not sitting on it)
		local rays, _, rguis = H.plate(a.body, 5.4, T.sigSun, SUN_L, 0.3, true, 1.3)
		local flower = H.plate(a.body, 3.1, T.sunflower, WHITE, 0, true, 1.1)
		H.job(a, function(self, f)
			local k = ease((f.t - self.born - 0.15) / 0.8)
			if k < 1.05 then
				local s1, s2 = math.max(0.1, 5.4 * k), math.max(0.1, 3.1 * k)
				rays.Size = Vector3.new(s1, 0.05, s1)
				flower.Size = Vector3.new(s2, 0.05, s2)
			end
		end)
		local function haloAt(f, back: number): Vector3
			return (f.headCF * CFrame.new(0, 1.35 + 0.08 * math.sin(f.t * 1.4), back)).Position
		end
		K.move(a, rays, function(f)
			return H.facing(haloAt(f, 1.4), f, -f.t * 0.2)
		end)
		K.move(a, flower, function(f)
			return H.facing(haloAt(f, 1.35), f, f.t * 0.35)
		end)
		H.detail(a, rguis[1], rguis[2])
		-- golden vine wings, breathing slowly and held out to the sides (the same from behind and in front)
		local function wingBase(f, side: number): CFrame
			local k = ease((f.t - a.born - 0.25) / 0.8)
			local flap = math.rad(4) + math.rad(8) * math.sin(f.t * 1.7)
			local hinge = f.root * CFrame.new(side * 0.35, 1.0, 0.75)
			return hinge * CFrame.Angles(0, -side * flap, 0) * CFrame.new(side * 2.3 * k, 0.55, 0)
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
		H.wings(a, T.wingVineL, T.wingVineR, rgb(255, 210, 100), WING, 1.2, wingCF)
		for _, side in { -1, 1 } do
			-- a point on the art (u, v) in the wing's own frame (the right wing's art is the left one mirrored)
			local function at(u: number, v: number): Vector3
				return Vector3.new(-side * (u - 0.5) * WING, (0.5 - v) * WING, 0)
			end
			-- a leafy green vine along the wing's top edge (drawn over the wing from both sides), solid leaves off it
			local holder = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, holder, function(f)
				return wingCF(f, side)
			end)
			local pts = {}
			for i, e in EDGE do
				pts[i] = at(e[1], e[2] + 0.025)
			end
			H.chain(holder, pts, { colors = K.seq(LEAF_L, LEAF), w0 = 0.55, w1 = 0.36, tex = T.vineStrip, texLen = 2, light = 0.15, bright = 1.2, zoff = 0.12 })
			local leaves = {}
			for k, e in { { 0.8, 0.34, 1 }, { 0.6, 0.19, -1 }, { 0.42, 0.135, 1 }, { 0.24, 0.17, -1 } } do
				local leaf = H.ellipsoid(a.body, Vector3.new(0.56, 0.26, 0.1), if k % 2 == 0 then LEAF else LEAF_L, Enum.Material.SmoothPlastic)
				local p = at(e[1], e[2] + 0.025) + Vector3.new(0, e[3] * 0.2, -0.015)
				table.insert(leaves, { leaf, CFrame.new(p) * CFrame.Angles(0, 0, e[3] * side * math.rad(45)) })
			end
			H.rig(a, function(f)
				return wingCF(f, side)
			end, leaves)
			local wt = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, wt, function(f)
				return wingCF(f, side) * CFrame.new(side * 1.8, -0.6, 0)
			end)
			local sp = E(wt, { tex = T.glint, flip = 4, colors = K.seq(WHITE, SUN_L), rate = 3, life = { 0.6, 1 }, speed = { 0.2, 0.6 }, size = 0.5, accel = Vector3.new(0, -1, 0), spread = 180, light = 1, bright = 2 })
			K.addEmitter(a, sp)
			H.detail(a, sp)
		end
		-- light falling on you from above
		local sky = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, sky, function(f)
			return CFrame.new(f.feet) * CFrame.Angles(0, f.t * 0.15, 0)
		end)
		for i = 1, 4 do
			local th = i / 4 * math.pi * 2
			local top = H.att(sky, Vector3.new(math.cos(th) * 1.2, 17, math.sin(th) * 1.2))
			local bot = H.att(sky, Vector3.new(math.cos(th) * 2.4, 0.2, math.sin(th) * 2.4))
			local b = H.beam(top, bot, { colors = K.seq(SUN_L, SUN), w0 = 2.2, w1 = 5, trans = ns(0, 1, 0.3, 0.55, 0.9, 0.62, 1, 1), tex = T.stripBody, texMode = Enum.TextureMode.Stretch, texSpeed = -0.3, light = 1, bright = 1.4 })
			if i % 2 == 0 then
				H.detail(a, b)
			end
		end
		-- pollen and gold petals (warm gold, not white: the aura mustn't wash you out)
		local bodyBox = K.bodyBox(a, Vector3.new(5, 5, 5), 0)
		local pollen = E(bodyBox, { tex = T.glint, flip = 4, colors = K.seq(SUN_L, SUN), rate = 6, life = { 1, 1.6 }, speed = { 0.3, 0.8 }, size = 0.45, accel = Vector3.new(0, 0.6, 0), spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, pollen)
		local petals = E(bodyBox, { tex = BFX.petal, colors = K.seq(SUN_L, SUN, AMBER), rate = 3, life = { 2, 3 }, speed = { 0.3, 0.9 }, size = 0.5, accel = Vector3.new(0, -0.6, 0), drag = 1, spin = 150, spread = 180, light = 0.4, bright = 1.3 })
		K.addEmitter(a, petals)
		H.detail(a, petals)
		H.shell(a, K.seq(GOLD, SUN), 6, 1)
		H.updraft(a, 5.4, K.seq(SUN_L, SUN, AMBER), 6)
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.2, 1.2), 0.15)
		K.addEmitter(a, E(kick, { tex = BFX.petal, colors = K.seq(SUN_L, SUN), rate = 9, life = { 0.6, 1 }, speed = { 2, 4 }, size = 0.5, accel = Vector3.new(0, -6, 0), spin = 200, spread = 50, light = 0.3 }), true)
		K.feetTrail(a, K.seq(SUN_L, SUN, AMBER))
		K.outline(a, SUN, 0.3)
		K.light(a, SUN, 1.4, 14)
		H.lightJob(a, 0.08)
		-- the tip settles back after the Midas Touch; while tipped, the stream gushes wider
		H.job(a, function(self, f)
			if tip > 0 then
				tip = math.max(0, tip - 0.015)
				local g = 1 + tip * 0.8
				pour.Width0, pour.Width1 = 0.55 * g, 0.4 * g
				sheen.Width0, sheen.Width1 = 0.7 * g, 0.5 * g
			end
		end)
		H.gimmick(a, { midas = true }, 30, function(self, d)
			tip = 1
			stream:Emit(24)
			drops:Emit(14)
			splash:Emit(12)
			pollen:Emit(12)
			self.lightKick = 3
		end)
		-- the formation: a gold ring, petals, the can tipping to gush (kept warm and soft so you aren't whited out)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 17, SUN, 0.9, 0)
			K.pulse(feet, 1, 11, GOLD, 0.6, 0.35)
			pollen:Emit(8)
			petals:Emit(14)
			tip = 1
			self.lightKick = 2
		end
		return a
	end
end
