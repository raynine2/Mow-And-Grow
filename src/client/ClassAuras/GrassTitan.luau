-- GRASS TITAN (Legendary) - the card: a giant mossy boulder-and-vine foot with daisies stomping a striped lawn, a green
-- shockwave ring. Gimmick: Titan Stomp, land from a jump and every clump round you (12 studs) takes 2 hits, every 4 s.
-- Aura: chunky mossy boulder boots on both your feet (round stone running heel to toe, mossy toes, a moss cuff, a vine
-- wrapped round with a leaf, daisies on the moss), their cracks glowing green when the stomp is ready (dark while it
-- recharges); the stomp's reach drawn on the ground when it's ready; a stone rune circle with bright runes on a dark
-- pool under you; four round mossy boulders with glowing cracks and daisies hovering in a crescent behind you; a
-- floating stone crown (a stone circlet on a band of glowing runes, five rune stones, small green gems); a vine
-- spiralling up, a rune ring round your waist, green light rising; every running step lands like a quake. Green outline.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local MOSS = rgb(110, 200, 80) -- the aura's green light
	local GLOW = rgb(160, 255, 120) -- glowing cracks, gems and runes
	local DIM = rgb(40, 60, 35) -- a boot crack while the stomp recharges
	local STONE = rgb(125, 116, 102)
	local STONE_D = rgb(90, 84, 74)
	local MOSS_C = rgb(78, 138, 46) -- the moss on the stones
	local VINE = rgb(52, 104, 38)
	local LEAF = rgb(120, 196, 70)
	local RADIUS, COOLDOWN = 12, 4 -- server/ClassPerks STOMP_RADIUS, STOMP_COOLDOWN
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing up)

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
	-- a frame at `pos` whose Y axis points along `n` (out of a curved surface)
	local function along(pos: Vector3, n: Vector3): CFrame
		local u = n.Unit
		return CFrame.lookAt(pos, pos + u, if math.abs(u.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	-- a daisy (a white petal disc, a yellow heart) on a ball's surface: centre c, radius r, facing out along n
	local function daisy(parent: Instance, c: Vector3, r: number, n: Vector3, s: number, into: { { BasePart | CFrame } }): (BasePart, BasePart)
		local cf = along(c + n.Unit * r, n)
		local petals = H.cyl(parent, 0.06 * s, 0.5 * s, WHITE, Enum.Material.SmoothPlastic)
		local heart = H.solid(parent, Vector3.one * 0.2 * s, rgb(255, 205, 40), Enum.Material.Neon)
		heart.Shape = Enum.PartType.Ball
		table.insert(into, { petals, cf * CFrame.new(0, 0.02 * s, 0) * UP })
		table.insert(into, { heart, cf * CFrame.new(0, 0.07 * s, 0) })
		return petals, heart
	end
	-- a glowing crack on a ball's surface (centre c, radius r) through the directions `dirs`: short neon strips laid on
	-- the surface, added to `into` (rig pieces) and to `list`
	local function crack(parent: Instance, c: Vector3, r: number, dirs: { Vector3 }, w: number, into: { { BasePart | CFrame } }, list: { BasePart })
		for i = 1, #dirs - 1 do
			local p0, p1 = c + dirs[i].Unit * r, c + dirs[i + 1].Unit * r
			local n = ((p0 + p1) / 2 - c).Unit
			local mid = c + n * r
			local seg = H.solid(parent, Vector3.new(w, w * 0.7, (p1 - p0).Magnitude + w * 0.6), GLOW, Enum.Material.Neon)
			table.insert(into, { seg, CFrame.lookAt(mid, mid + (p1 - p0), n) })
			table.insert(list, seg)
		end
	end
	-- a round mossy rock (H.rock: stone lumps and a moss cap) turned by `at`; returns its main lump
	local function rock(parent: Instance, s: number, at: CFrame, into: { { BasePart | CFrame } }): BasePart
		local pieces = H.rock(parent, s, STONE, STONE_D, MOSS_C)
		for _, pc in pieces do
			table.insert(into, { pc[1], at * (pc[2] :: CFrame) })
		end
		return pieces[1][1] :: BasePart
	end

	-- a boulder boot (the card's foot) in the foot's frame: a round mossy rock running heel to toe, three mossy toes, a
	-- moss cuff round the ankle, a vine wrapped round it with a leaf, two daisies on the moss, cracks across its toe and
	-- its outer side (side: 1 right foot, -1 left foot)
	local BOOT = 1.3
	local function boot(a: any, side: number, cracks: { BasePart }): ({ { BasePart | CFrame } }, BasePart)
		local parent = a.body
		local pieces = {}
		local main = rock(parent, BOOT, CFrame.Angles(0, math.rad(90), 0), pieces) -- (its lumps run heel to toe)
		for k = -1, 1 do
			local toe = H.solid(parent, Vector3.one * (if k == 0 then 0.5 else 0.42), MOSS_C, Enum.Material.Grass)
			toe.Shape = Enum.PartType.Ball
			table.insert(pieces, { toe, CFrame.new(k * 0.34, -0.36, -0.86 + math.abs(k) * 0.08) })
		end
		table.insert(pieces, { H.cyl(parent, 0.34, 1.0, MOSS_C, Enum.Material.Grass), CFrame.new(0, 0.78, 0.08) * UP })
		-- the vine: a ring wrapped slantwise round the rock (rising to the heel), a leaf on the outer side
		local vine = H.loop(parent, 0.7, 0.13, 6, VINE, Enum.Material.Grass, CFrame.new(0, 0.12, -0.05) * CFrame.Angles(math.rad(68), 0, 0))
		for _, pc in vine do
			table.insert(pieces, pc)
			H.detail(a, pc[1] :: BasePart)
		end
		local leaf = H.ellipsoid(parent, Vector3.new(0.1, 0.46, 0.26), LEAF, Enum.Material.SmoothPlastic)
		table.insert(pieces, { leaf, CFrame.new(side * 0.76, 0.2, 0.12) * CFrame.Angles(math.rad(35), 0, side * math.rad(-15)) })
		H.detail(a, leaf)
		-- daisies on the moss cap (H.rock's cap, turned heel to toe), one on the outer side, one at the front
		local cap, capR = Vector3.new(0, 0.2 * BOOT, -0.02 * BOOT), 0.39 * BOOT
		daisy(parent, cap, capR, Vector3.new(side * 0.7, 0.45, -0.45), 0.85, pieces)
		daisy(parent, cap, capR, Vector3.new(0, 0.5, -0.85), 0.85, pieces)
		-- the cracks: across the toe lump (H.rock's second lump, turned) and down the outer side of the main lump
		local toeLump = Vector3.new(-0.12 * BOOT, -0.08 * BOOT, -0.3 * BOOT)
		crack(parent, toeLump, 0.4 * BOOT, { Vector3.new(side * 0.55, 0.5, -0.7), Vector3.new(side * 0.12, 0.2, -1), Vector3.new(-side * 0.3, 0.05, -1) }, 0.08, pieces, cracks)
		crack(parent, Vector3.zero, 0.5 * BOOT, { Vector3.new(side, 0.45, 0.1), Vector3.new(side, 0.1, -0.15), Vector3.new(side, -0.25, 0.05) }, 0.08, pieces, cracks)
		return pieces, main
	end

	return function()
		local a = H.aura(H.RANK.Legendary, MOSS)
		-- the ground: a dark pool (two layers), the stone rune circle with bright runes, a green rim
		H.glowDisc(a, 13, BFX.glow, rgb(12, 16, 10), 0.05, 0, 0.08, 1)
		H.glowDisc(a, 8, BFX.glow, rgb(8, 12, 6), 0.3, 0, 0.09, 1)
		H.sigil(a, 11, T.sigRune, rgb(150, 255, 110), 0, 0.06, 0.12, 1, 1.5)
		H.glowRing(a, 5.7, GLOW, 0.15, 0, 0.15, 1.3)
		-- the stomp's charge: dark right after a stomp, glowing again by the time it's ready
		local lastStomp = -100
		local function charge(): number
			return math.clamp((os.clock() - lastStomp) / COOLDOWN, 0, 1)
		end
		local _, _, rguis = H.glowDisc(a, RADIUS * 2 / 0.92, T.ringCrisp, GLOW, 0.6, 0, 0.17, 1.2)
		-- mossy boulder boots on both feet (the card's stomping foot); a soft green glow round them when the stomp is ready
		local cracks = {}
		local bootGlow = {}
		for i, foot in { "RightFoot", "LeftFoot" } do
			local side = if i == 1 then 1 else -1
			local pieces, main = boot(a, side, cracks)
			H.rig(a, once(function(f): CFrame
				local l = H.limb(f, foot)
				return if l then l.CFrame * CFrame.new(0, 0.45 - l.Size.Y / 2, 0) else f.root * CFrame.new(side * 0.5, -2.45, 0)
			end), pieces)
			local dust = E(main, { tex = BFX.sand, colors = K.seq(rgb(150, 135, 105), rgb(100, 90, 70)), rate = 2, life = { 0.5, 0.8 }, speed = { 0.2, 0.6 }, size = 0.22, accel = Vector3.new(0, -12, 0), spread = 60, light = 0, bright = 1 })
			K.addEmitter(a, dust)
			H.detail(a, dust)
			local glow = E(main, { tex = BFX.glow, colors = K.seq(GLOW, MOSS), rate = 0, life = { 0.5, 0.8 }, speed = { 0, 0.3 }, size = 2, spread = 180, light = 1, bright = 1, trans = ns(0, 1, 0.4, 0.75, 1, 1) })
			H.detail(a, glow)
			table.insert(bootGlow, glow)
		end
		-- round mossy boulders hovering in a crescent behind you (never in front of your face), glowing cracks and daisies
		-- on them, swaying and turning (the moss stays on top), rising out of the ground when the aura forms
		local ARC = { { -1.3, 0.9, 1.3 }, { -0.45, 3.7, 1.65 }, { 0.45, 3.7, 1.65 }, { 1.3, 0.9, 1.3 } }
		local CRACK_A = { Vector3.new(0.25, 0.35, -1), Vector3.new(-0.05, 0.05, -1), Vector3.new(0.2, -0.3, -1) }
		local CRACK_B = { Vector3.new(0.15, 0.35, 1), Vector3.new(0.1, 0, 1), Vector3.new(0.25, -0.35, 1) }
		local lit = {} -- (the boulders' cracks stay lit)
		for i, spot in ARC do
			local s = spot[3]
			local big = i == 2 or i == 3
			local pieces = {}
			local main = rock(a.body, s, CFrame.identity, pieces)
			crack(a.body, Vector3.zero, 0.5 * s, CRACK_A, 0.06 * s, pieces, lit)
			local cap, capR = Vector3.new(0.02 * s, 0.2 * s, 0), 0.39 * s
			daisy(a.body, cap, capR, Vector3.new(0.3, 0.9, -0.3), 1.1, pieces)
			if big then
				crack(a.body, Vector3.zero, 0.5 * s, CRACK_B, 0.06 * s, pieces, lit)
				daisy(a.body, cap, capR, Vector3.new(-0.35, 0.85, 0.35), 1.1, pieces)
			end
			H.rig(a, once(function(f): CFrame
				local k = ease((f.t - a.born - i * 0.12) / 0.9)
				local ang = spot[1] + 0.12 * math.sin(f.t * 0.6 + i)
				local hgt = (spot[2] + 0.3 * math.sin(f.t * 1.1 + i * 1.7)) * k - 3.5 * (1 - k)
				return f.root * CFrame.new(math.sin(ang) * 3.9, hgt, math.cos(ang) * 3.9) * CFrame.Angles(0.15 * math.sin(f.t * 0.7 + i), f.t * 0.35 + i * 1.7, 0.12 * math.cos(f.t * 0.55 + i))
			end), pieces)
			if not big then
				for _, pc in pieces do
					H.detail(a, pc[1] :: BasePart)
				end
			end
			local grit = E(main, { tex = BFX.sand, colors = K.seq(rgb(150, 135, 105), rgb(100, 90, 70)), rate = 1.5, life = { 0.6, 0.9 }, speed = { 0.2, 0.5 }, size = 0.2, accel = Vector3.new(0, -12, 0), spread = 60, light = 0, bright = 1 })
			K.addEmitter(a, grit)
			H.detail(a, grit)
		end
		-- the boots' cracks and glow follow the stomp's charge; the reach ring shows when it's ready
		local shown = -1
		H.job(a, function(self, f)
			local c = charge()
			local q = if c >= 1 then 1 else math.floor(c * 40) / 40
			if q == shown then
				return
			end
			shown = q
			local col = DIM:Lerp(GLOW, q * q)
			for _, cr in cracks do
				cr.Color = col
			end
			local ready = q >= 1
			for _, g in rguis do
				g.Enabled = ready
			end
			for _, e in bootGlow do
				e.Rate = if ready then 4 else 0
			end
		end)
		-- the stone crown floating over your head: a round stone circlet on a band of glowing runes, five rune stones
		-- standing round it (leaning out, a glowing rune cut in each) and a small green gem between each pair
		local crownCF = once(function(f): CFrame
			local k = ease((f.t - a.born - 0.3) / 0.7)
			return CFrame.new(f.head + Vector3.new(0, 0.55 + 0.08 * math.sin(f.t * 1.6) + 2 * (1 - k), 0)) * CFrame.Angles(0, f.t * 0.4, 0)
		end)
		local CR = 0.8
		local crown = H.loop(a.body, CR, 0.16, 10, STONE_D, Enum.Material.Slate, CFrame.Angles(math.rad(90), 0, 0))
		for i = 1, 5 do
			local th = i / 5 * math.pi * 2
			local at = CFrame.Angles(0, th, 0) * CFrame.new(0, 0, -CR)
			local lean = CFrame.Angles(math.rad(-10), 0, 0)
			table.insert(crown, { H.ellipsoid(a.body, Vector3.new(0.34, 0.68, 0.26), STONE, Enum.Material.Slate), at * CFrame.new(0, 0.3, 0) * lean })
			table.insert(crown, { H.solid(a.body, Vector3.new(0.07, 0.3, 0.05), GLOW, Enum.Material.Neon), at * CFrame.new(0, 0.32, 0) * lean * CFrame.new(0, 0, -0.12) })
			local gem = H.solid(a.body, Vector3.one * 0.2, GLOW, Enum.Material.Neon)
			gem.Shape = Enum.PartType.Ball
			table.insert(crown, { gem, CFrame.Angles(0, th + math.pi / 5, 0) * CFrame.new(0, 0.04, -CR - 0.06) })
		end
		H.rig(a, crownCF, crown)
		local runeHold = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, runeHold, function(f)
			return crownCF(f) * CFrame.new(0, -0.16, 0)
		end)
		local band = K.beamRing(runeHold, CR + 0.02, 0.16, K.seq(GLOW, MOSS), 3, 0.05, 10, false)
		for _, b in band do
			b.Texture = T.runeStrip
			b.TextureMode = Enum.TextureMode.Stretch
			b.LightEmission = 1
		end
		local gemGlint = E(runeHold, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GLOW), rate = 2, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 0.45, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, gemGlint)
		H.detail(a, gemGlint)
		-- a vine spiralling up round you, a rune ring round your waist
		do
			local holder = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			local pts = {}
			for k = 0, 14 do
				local tt = k / 14
				local th = tt * math.pi * 2.6
				local r = 1.8 - 0.4 * tt
				table.insert(pts, Vector3.new(math.cos(th) * r, -2.6 + tt * 5.4, math.sin(th) * r))
			end
			local vines = H.chain(holder, pts, { colors = K.seq(rgb(160, 240, 120), MOSS), w0 = 0.6, w1 = 0.14, tex = T.vineStrip, texLen = 1.4, texSpeed = 0.5, light = 0.4, bright = 1.3 })
			K.move(a, holder, function(f)
				return CFrame.new(f.root.Position) * CFrame.Angles(0, f.t * 0.5, 0)
			end)
			for _, b in vines do
				H.detail(a, b)
			end
		end
		local h = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		local runes = K.beamRing(h, 2.6, 0.45, K.seq(GLOW, MOSS, GLOW), 4, 0.05, 16, false)
		for _, b in runes do
			b.Texture = T.runeStrip
			b.TextureMode = Enum.TextureMode.Stretch
			b.LightEmission = 1
		end
		K.move(a, h, function(f)
			return CFrame.new(f.root.Position + Vector3.new(0, -0.6, 0)) * CFrame.Angles(math.rad(7), 0, math.rad(4)) * CFrame.Angles(0, f.t * 0.5, 0)
		end)
		H.updraft(a, 5.2, K.seq(WHITE, GLOW, MOSS), 6)
		H.shell(a, K.seq(GLOW, MOSS), 7, 1)
		local base = H.feetPiece(a, Vector3.new(6, 0.3, 6), 0.3)
		local dust = E(base, { tex = BFX.sand, colors = K.seq(rgb(200, 180, 140), rgb(130, 115, 90)), rate = 4, life = { 1.4, 2.2 }, speed = { 0.6, 1.4 }, size = 0.35, accel = Vector3.new(0, 0.6, 0), spread = 20, light = 0, bright = 1, shape = Enum.ParticleEmitterShape.Disc })
		K.addEmitter(a, dust)
		H.detail(a, dust)
		-- footfalls: every heavy step while you run lands a ring and a puff of dust
		local stomp = E(H.feetPiece(a, Vector3.new(1.5, 0.2, 1.5), 0.15), { tex = BFX.smoke or BFX.sand, colors = K.seq(rgb(200, 185, 150)), rate = 0, life = { 0.5, 0.8 }, speed = { 3, 5 }, size = 1.4, grow = true, drag = 4, spread = 85, light = 0, bright = 1, trans = ns(0, 0.4, 1, 1) })
		H.every(a, 0.42, function(self, f)
			if f.calm < 0.5 then
				K.pulse(f.feet, 1, 7, GLOW, 0.45, 0.25)
				stomp:Emit(6)
			end
		end)
		K.feetTrail(a, K.seq(GLOW, MOSS))
		K.outline(a, GLOW, 0.3)
		K.light(a, GLOW, 1.2, 13)
		H.lightJob(a, 0.1)
		H.gimmick(a, { stomp = true }, 8, function(self, d)
			lastStomp = os.clock()
			self.lightKick = 3
			stomp:Emit(18)
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 18, GLOW, 0.9, 0)
			K.pulse(feet, 1, 11, WHITE, 0.6, 0.2)
			stomp:Emit(16)
			dust:Emit(20)
			self.lightKick = 3
			pcall(function()
				local cam = workspace.CurrentCamera
				if cam and (cam.CFrame.Position - feet).Magnitude < 40 then
					K.Sound.play("bossThud", 0.05, 0.3)
				end
			end)
		end
		return a
	end
end
