-- GOAT MAN (Secret, the rarest) - the card: a white goat with big golden curled ram horns and black sunglasses, chewing
-- a blade of grass: "the G.O.A.T." (its purple backdrop is the Secret rarity's colour, not the goat's: the aura is gold,
-- grass green and wool-white). Gimmick: Graze, you eat grass as you walk: the clumps within 7 studs take a nibble every
-- 0.75 s. Aura, built from ForgeGUI props and the VFX Forge layers in Loop_GoatMan:
--   - the ForgeGUI meadow emblem under you, exactly as wide as the Graze (radius 7), four crisp gold and grass line
--     rings turning over it in both directions, a curtain of light rising off its rim
--   - Graze, the spectacle: a dense storm of thick green grass blades torn up at the rim of the Graze and spiralling
--     up into your mouth (wilder while you walk); every bite a bold gold ring snaps in from the rim, a gold ring pops
--     round your mouth and grass bursts from it (you keep chewing slowly while you stand)
--   - the card's horns, worn: the ForgeGUI ram horns (gm_horns_gold, else gm_horns), big, polished gold with a pale
--     gold rim glow, their band on your crown and their curls framing your shoulders like the card's goat (never over
--     your head or behind you, so the follow camera always sees you); a glint sweeps across them; white wool puffs at
--     their roots and on your shoulders
--   - oversized 3D sunglasses (gm_shades) with a hard gold glint sweeping across them; a blade of grass you chew
--   - a big polished gold halo, a thin gold ring turning round your legs like a gyroscope (gold sparkles riding it), an
--     always-on column of golden light (26 studs, a soft haze in it) with gold motes falling down it, gold wisps
--     behind you, a gold heartbeat
-- (Council: nothing blows out to white: deep golds, low light emission.)
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local FX, BFX = H.FX, H.BFX
	local E = H.E
	local LOOP = "Loop_GoatMan"
	local GOLD = rgb(255, 196, 60)
	local GOLD_D = rgb(240, 158, 30) -- deep gold (rings, halo glow: keeps its colour instead of bleaching to white)
	local GOLD_L = rgb(255, 230, 150)
	local HALO = rgb(255, 222, 130) -- the halo's polished gold (Metal)
	local PALE = rgb(255, 236, 160) -- the gold pieces' rim glow (pulls the props' orange toward gold)
	local GRASS = rgb(110, 215, 75)
	local GRASS_L = rgb(185, 255, 140)
	local BLADE, BLADE_M, BLADE_D = rgb(120, 220, 70), rgb(70, 170, 45), rgb(50, 130, 35) -- the grazed blades
	local CHEW = rgb(95, 210, 60)
	local CHEW_L = rgb(140, 230, 85)
	local GRAZE_R, GRAZE_EVERY = 7, 0.75 -- server/ClassPerks GRAZE_RADIUS, GRAZE_EVERY
	local IDLE_CHEW = 1.5 -- standing still you keep chewing, slower

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
	-- gold sparkles that stay gold (no white core, low light emission)
	local function tame(list: { ParticleEmitter })
		for _, e in list do
			e.Color = K.seq(GOLD_L, GOLD)
			e.LightEmission = 0.5
			e.Brightness = 1.4
		end
	end
	-- a flat ground piece that grows in from nothing (overshooting a touch) every time the aura forms
	local function growIn(a: any, p: BasePart, size: number, delay: number, dur: number)
		local shown = -1
		H.job(a, function(self, f)
			local k = (f.t - self.born - delay) / dur
			local s = if k >= 1 then size else math.max(0.1, size * ease(k))
			if s ~= shown then
				shown = s
				p.Size = Vector3.new(s, 0.05, s)
			end
		end)
	end
	-- the golden ram horns prop: gm_horns_gold when it's there, else gm_horns; its texture's tint pulled toward a pale
	-- gold and its own glow kept low (the council read the full glow as orange plastic)
	local function hornProp(parent: Instance, size: number): (BasePart, Vector3)
		local key = "gm_horns_gold"
		local p = H.prop(parent, key, size)
		if not p:IsA("MeshPart") then
			p:Destroy()
			key = "gm_horns"
			p = H.prop(parent, key, size)
		end
		local sa: any = p:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			pcall(function()
				sa.Color = rgb(255, 242, 205)
			end)
			pcall(function()
				sa.EmissiveStrength = 0.35
			end)
			pcall(function()
				sa.EmissiveTint = PALE
			end)
		end
		return p, H.propSize(key, size)
	end

	return function()
		local a = H.aura(H.RANK.Secret, GOLD)
		-- every gold piece (the horns, the halo) sits in one model, so one Highlight gives them all a pale-gold sheen and
		-- rim glow (it pulls the horn prop's orange to gold; checked in the lab)
		local goldModel = Instance.new("Model")
		goldModel.Name = "Gold"
		goldModel.Parent = a.body
		local goldGlow = Instance.new("Highlight")
		goldGlow.Adornee = goldModel
		goldGlow.FillColor = rgb(255, 220, 110)
		goldGlow.FillTransparency = 0.56
		goldGlow.OutlineColor = rgb(255, 244, 200)
		goldGlow.OutlineTransparency = 0.25
		goldGlow.DepthMode = Enum.HighlightDepthMode.Occluded
		goldGlow.Parent = a.body
		H.detail(a, goldGlow)

		-- the ground: the ForgeGUI meadow emblem (golden ram horns round a tuft of grass, a gold rim of grass tufts),
		-- exactly as wide as the Graze (the badge fills 98% of its image), on a faint green glow
		local _, _, meadowGuis = H.glowDisc(a, GRAZE_R * 2.4, BFX.glow, rgb(120, 220, 80), 0.8, 0, 0.07, 0.9)
		H.detail(a, meadowGuis[1])
		H.sigil(a, GRAZE_R * 2 / 0.98, T.embGoatMan, WHITE, 0.18, 0.04, 0.12, 1, 1.05)
		-- four crisp line rings over it (the Secret's stack), turning both ways: gold on the Graze's rim, deep gold just
		-- outside it, grass green and pale gold inside
		for _, rg in {
			{ GRAZE_R + 0.05, GOLD, 0.35, 0.1, 0.16, 0.1 },
			{ GRAZE_R + 0.9, GOLD_D, 0.5, -0.14, 0.15, 0.25 },
			{ 4.7, GRASS_L, 0.45, 0.2, 0.17, 0.4 },
			{ 2.7, GOLD_L, 0.5, -0.3, 0.18, 0.55 },
			-- (4 Nov: two wide outer rings, so the Secret's footprint is the biggest of the ten from afar)
			{ GRAZE_R + 2.8, GOLD, 0.55, 0.1, 0.15, 0.1 },
			{ GRAZE_R + 4.6, GOLD_L, 0.62, -0.08, 0.14, 0 },
		} do
			local p = H.glowRing(a, rg[1], rg[2], rg[3], rg[4], rg[5], 1.15)
			growIn(a, p, rg[1] * 2 / 0.92, rg[6], 0.8)
		end
		-- a curtain of light rising off the rim of the Graze (low light emission, so it stays gold)
		local curtain = H.updraft(a, GRAZE_R, K.seq(GOLD_L, GOLD), 6, T.streak, 0.8)
		curtain.LightEmission = 0.4
		K.bright(curtain, 1)
		H.detail(a, curtain)

		-- Graze: a dense storm of thick green grass blades torn up at the rim of the Graze and swept in to you. The layer's
		-- cylinder is the Graze, lying low on the lawn; it turns and the blades are locked to it, so they spiral in, rising
		-- as they come (they reach your mouth as they die). Each blade is a leaf stretched long and thin along its flight
		-- (thick, not a thin line; checked in the lab), lit by the scene like real grass. Wilder while you walk.
		local grazeBox = K.piece(a.model, Vector3.new(GRAZE_R * 2, 0.5, GRAZE_R * 2))
		K.move(a, grazeBox, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, f.t * 1.3, 0)
		end)
		local grass = H.layer(a, LOOP, "Grass", grazeBox, false, 1)
		for _, e in grass do
			e.LockedToPart = true
			e.Speed = NumberRange.new(7.4, 8.2)
			e.Lifetime = NumberRange.new(0.84, 0.92)
			e.Acceleration = Vector3.new(0, 9.5, 0)
			e.Drag = 0
			e.SpreadAngle = Vector2.new(4, 4)
			e.Orientation = Enum.ParticleOrientation.VelocityParallel
			e.Texture = BFX.leaf
			e.Squash = NumberSequence.new(0.9)
			e.Size = ns(0, 0.72, 0.6, 0.82, 1, 0.3)
			e.Color = K.seq(BLADE, BLADE_M, BLADE_D)
			e.Transparency = ns(0, 1, 0.1, 0, 0.8, 0.1, 1, 1)
			e.LightEmission = 0.05
			e.LightInfluence = 0.5
			e.Brightness = 1.2
		end
		setRate(a, grass, 22)
		-- each bite: a bold gold ring snaps in from the rim of the Graze (two crisp rings side by side make it thick; it
		-- shows only while it moves)
		local chompParts, chompImgs = {}, {}
		for i, k in { 1, 0.955 } do
			local p, imgs = H.plate(a.model, 2, T.ringCrisp, if i == 1 then GOLD_D else GOLD, 1, false, 1.3)
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(0, 0.22 + i * 0.01, 0))
			end)
			chompParts[i] = { p = p, k = k }
			table.insert(chompImgs, imgs[1])
		end

		-- the horns (the card), worn like the card's goat: the ForgeGUI golden ram horns, big (7.4 studs, a quarter wider so
		-- the curls clear your arms), their band on the crown of your head and their curls framing your shoulders. Never
		-- over your head or behind you, so the follow camera always sees you (checked in the lab: the giant back horns
		-- swallowed the player in back and run). They drop on with a spin when the aura forms; a gold glint sweeps across
		-- them every 3 s, sparkles drift off them, white wool puffs at their roots.
		local HORNS = 7.4
		local horns, hz0 = hornProp(goldModel, HORNS)
		local hz = Vector3.new(hz0.X * 1.25, hz0.Y, hz0.Z)
		if horns:IsA("MeshPart") then
			horns.Size = hz
		end
		local hornCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.5) / 0.7)
			local top = f.head.Y - f.headCF.Position.Y -- (the top of the head over its centre)
			-- (the joint behind your neck, the tops level with the top of your head: your head shows front and back;
			-- checked in the lab)
			-- (4 Nov: 0.6 higher and 0.3 further back, so the curls frame the shoulders instead of the chest)
			return f.headCF * CFrame.new(0, top + 0.5 - hz.Y * 0.5 + 3 * (1 - k), 1.5) * CFrame.Angles(0, (1 - k) * 6.3, 0)
		end)
		K.move(a, horns, hornCF)
		-- (4 Nov, for your own camera only: while the camera is close behind you the horns and their gold sheen go half
		-- see-through, so they never hide you in the follow camera; checked in the lab's run view)
		local hornFaded = false
		local LocalPlayer = game:GetService("Players").LocalPlayer
		H.job(a, function(self, f)
			local cam = workspace.CurrentCamera
			local behind = false
			if cam and f.player == LocalPlayer then
				local toCam = cam.CFrame.Position - f.root.Position
				behind = toCam.Magnitude < 22 and toCam.Unit:Dot(f.root.LookVector) < -0.2
			end
			if behind ~= hornFaded then
				hornFaded = behind
				horns.LocalTransparencyModifier = if behind then 0.5 else 0
				goldGlow.FillTransparency = if behind then 0.85 else 0.56
			end
		end)
		local hornSparkle = H.layer(a, LOOP, "Sparkle", horns, false, 0.6)
		tame(hornSparkle)
		setRate(a, hornSparkle, 3)
		-- the glint: a run of gold stars across the front of the horns, along their top, from one curl to the other
		local HG_EVERY, HG_SWEEP = 3, 0.6
		local hornGlintAt = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
		K.move(a, hornGlintAt, function(f)
			local u = math.min(1, (f.t % HG_EVERY) / HG_SWEEP) * 2 - 1
			return hornCF(f) * CFrame.new(u * hz.X * 0.4, hz.Y * (0.36 - 0.14 * u * u), -hz.Z * 0.3)
		end)
		local hornGlint = E(hornGlintAt, { tex = T.glint, flip = 4, colors = K.seq(GOLD_L, GOLD), rate = 0, life = { 0.3, 0.45 }, speed = { 0, 0.2 }, size = 1, spread = 180, light = 0.5, bright = 1.4 })
		hornGlint.ZOffset = 1.5 -- (drawn in front of the horn it runs along)
		H.detail(a, hornGlint)
		local hornGlintOn = false
		H.job(a, function(self, f)
			local on = (f.t % HG_EVERY) < HG_SWEEP
			if on ~= hornGlintOn then
				hornGlintOn = on
				hornGlint.Rate = if on then 28 else 0
			end
		end)
		-- white wool: puffs at the horns' roots and on both shoulders (the goat's fleece)
		local roots = K.piece(a.body, Vector3.new(hz.X * 0.18, 0.3, hz.Z * 0.5))
		K.move(a, roots, function(f)
			return hornCF(f) * CFrame.new(0, hz.Y * 0.32, 0)
		end)
		local wool = H.layer(a, LOOP, "Wool", roots, false, 0.45)
		setRate(a, wool, 1)
		for _, side in { -1, 1 } do
			local shoulder = K.piece(a.body, Vector3.new(0.9, 0.5, 0.9))
			K.move(a, shoulder, function(f)
				return f.root * CFrame.new(side * 1.05, 1.35, 0.1)
			end)
			local w = H.layer(a, LOOP, "Wool", shoulder, false, 0.65)
			setRate(a, w, 2.4)
			for _, e in w do
				table.insert(wool, e)
			end
		end

		-- the sunglasses: oversized ForgeGUI shades on your face (lenses to the front, arms back over your ears, twice as
		-- wide as your head like the card's); they slide down onto your eyes when the aura forms, and a hard gold glint
		-- sweeps across them every 2.2 s with a star where it leaves the lens
		local SHADES = 3 -- (its longest side is the arms)
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
		local SWEEP, EVERY = 0.4, 2.2
		local glint = H.solid(a.body, Vector3.new(0.22, sz.Y * 0.9, 0.02), rgb(255, 228, 140), Enum.Material.Neon)
		glint.Transparency = 1
		K.move(a, glint, function(f)
			local p = (f.t % EVERY) / SWEEP
			local x = if p < 1 then (p - 0.5) * sz.X * 0.85 else sz.X * 0.42
			return faceCF(f) * CFrame.new(x, 0, -0.18) * CFrame.Angles(0, 0, math.rad(-28))
		end)
		local twinkle = E(glint, { tex = T.glint, flip = 4, colors = K.seq(GOLD_L, GOLD), rate = 0, life = { 0.35, 0.5 }, speed = { 0, 0 }, size = 1.3, spread = 0, light = 0.5, bright = 1.4 })
		twinkle.ZOffset = 0.5
		local glintOn = false
		H.job(a, function(self, f)
			local on = (f.t % EVERY) < SWEEP
			if on ~= glintOn then
				glintOn = on
				glint.Transparency = if on then 0.1 else 1
				twinkle:Emit(1) -- (a star where the glint enters and leaves the lens)
			end
		end)

		-- the blade of grass you chew: a long one out of the corner of your mouth and a short one under it, wagging;
		-- each bite bursts grass from your mouth and pops a gold ring round it
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
		local chompFx = H.layer(a, LOOP, "Chomp", mouth, false, 0.9)
		-- the gold ring that pops round your mouth on each bite (both faces, so it shows from above and below)
		local biteRing, biteImgs = H.plate(a.body, 1, T.ringCrisp, GOLD_D, 1, true, 1.3)
		K.move(a, biteRing, function(f)
			return CFrame.new(mouthCF(f).Position) * f.yaw
		end)
		-- a big polished gold halo over your horns (a ring of gold, a soft gold glow round it), sparkling; it drops in
		-- when the aura forms
		local haloCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 1) / 0.6)
			-- (its front edge tilted up, so it reads as a ring from in front and below, not a line)
			return CFrame.new(f.head + Vector3.new(0, 1.7 + 0.07 * math.sin(f.t * 1.7) + 3 * (1 - k), 0)) * f.yaw * CFrame.Angles(math.rad(14), 0, 0)
		end)
		H.rig(a, function(f)
			return haloCF(f) * CFrame.Angles(math.pi / 2, 0, 0) -- (the loop is built standing up: lay it flat)
		end, H.loop(goldModel, 1.15, 0.16, 20, HALO, Enum.Material.Metal))
		local haloPart = K.piece(a.body, Vector3.new(2.4, 0.3, 2.4))
		K.move(a, haloPart, haloCF)
		local haloBeams = K.beamRing(haloPart, 1.15, 0.42, K.seq(GOLD, GOLD_D, GOLD), 1.6, 0.45, 20, false)
		for _, b in haloBeams do
			b.LightEmission = 0.3
			H.detail(a, b)
		end
		local haloSparkle = H.layer(a, LOOP, "Sparkle", haloPart, false, 0.6)
		tame(haloSparkle)
		setRate(a, haloSparkle, 3)

		-- a thin gold ring turning round your legs below the horns' curls like a gyroscope (its tilt turns with it, so it
		-- wobbles), gold sparkles riding it (checked in the lab: rings higher up crossed the horns)
		local function ringCF(r: number, y: number, tilt: number, spin: number): (any) -> CFrame
			return perFrame(function(f): CFrame
				local k = ease((f.t - a.born - 0.6) / 0.8)
				return CFrame.new(f.root.Position + Vector3.new(0, y, 0)) * CFrame.Angles(0, f.t * spin, 0) * CFrame.Angles(math.rad(tilt) * k, 0, 0)
			end)
		end
		local waistCF = ringCF(3.6, -0.8, 14, 0.7)
		for _, g in { { 3.6, waistCF } } do
			local holder = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, holder, g[2])
			local beams = K.beamRing(holder, g[1], 0.16, K.seq(GOLD, GOLD_D, GOLD), 2, 0.25, 32, false)
			for _, b in beams do
				b.LightEmission = 0.3
			end
		end

		-- the column of golden light from above, always on (standing or walking): 26 studs of slow-flowing gold light, a
		-- light veil over your body so you still show, strongest above your head, fading out high up; a soft gold haze
		-- drifting down inside it and gold motes falling through it
		local pillar = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, pillar, function(f)
			return CFrame.new(f.feet)
		end)
		-- (4 Nov, checked in the lab: the old column never showed. A beam with Segments 1 only takes its transparency
		-- at its two ends, and both ends were 1, so the whole thing was invisible; and T.energy's hard band read as a
		-- panel. Now three untextured beams, wide and faint to narrow and bright, each with 16 segments: a soft-edged
		-- column of light, strongest just above your head, fading out at the feet and high up.)
		-- (`v` 1 standing, a little fainter while you run)
		-- (faint over your body, full from just above your head; tuned in the lab: thicker hid the player)
		local function colSeq(base: number, v: number): NumberSequence
			local o = base * v
			return ns(0, 1, 0.14, 1 - o * 0.3, 0.3, 1 - o, 0.65, math.min(1, 1 - o + 0.03), 1, 1)
		end
		local c0, c1 = H.att(pillar, Vector3.new(0, 0.3, 0)), H.att(pillar, Vector3.new(0, 26, 0))
		local COL_LAYERS = { { 7, 5.6, 0.15 }, { 4, 3, 0.24 }, { 1.6, 1.2, 0.42 } } -- (width at the feet, at the top, opacity)
		local colBeams: { Beam } = {}
		for _, L in COL_LAYERS do
			local b = H.beam(c0, c1, { colors = K.seq(Color3.fromRGB(255, 196, 70), Color3.fromRGB(255, 232, 150)), w0 = L[1], w1 = L[2], trans = colSeq(L[3], 1), light = 0.25, bright = 1.3, segments = 16 })
			table.insert(colBeams, b)
		end
		H.detail(a, colBeams[1])
		local lastV = -1
		H.job(a, function(self, f)
			local v = 0.8 + 0.2 * f.calm
			if math.abs(v - lastV) > 0.03 then
				lastV = v
				for i, b in colBeams do
					b.Transparency = colSeq(COL_LAYERS[i][3], v)
				end
			end
		end)
		local colBox = K.piece(a.body, Vector3.new(3, 16, 3))
		K.move(a, colBox, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 13, 0))
		end)
		local haze = E(colBox, { tex = FX.glow, colors = K.seq(GOLD, GOLD_D), rate = 3, life = { 2.5, 3.5 }, speed = { 0.5, 1 }, dir = Enum.NormalId.Bottom, size = 4, grow = true, spread = 10, light = 0.4, bright = 1, trans = ns(0, 1, 0.3, 0.8, 1, 1) })
		K.addEmitter(a, haze)
		H.detail(a, haze)
		local motes = H.layer(a, LOOP, "Motes", colBox, false, 1.8)
		for _, e in motes do
			e.LightEmission = 0.5
			e.Brightness = 1.4
		end
		setRate(a, motes, 12)

		-- gold sparkles round you and riding the waist ring (3+ studs out), soft gold wisps rising from behind you (behind,
		-- so they frame you rather than cover you)
		local body = K.bodyBox(a, Vector3.new(3.6, 5, 3), 0)
		local sparkle = H.layer(a, LOOP, "Sparkle", body, false, 0.8)
		tame(sparkle)
		setRate(a, sparkle, 3)
		local orbit = K.piece(a.body, Vector3.new(7.2, 0.3, 7.2))
		K.move(a, orbit, waistCF)
		local orbitSparkle = H.layer(a, LOOP, "Sparkle", orbit, false, 0.7)
		tame(orbitSparkle)
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
		local wisps = E(behind, { tex = T.wisp, colors = K.seq(GOLD_L, GOLD, GOLD_D), rate = 4, life = { 0.6, 1 }, speed = { 1.5, 2.6 }, size = 1.1, accel = Vector3.new(0, 2, 0), spread = 8, light = 0.3, bright = 1, orient = Enum.ParticleOrientation.FacingCameraWorldUp, trans = ns(0, 1, 0.25, 0.5, 1, 1), sizeSeq = ns(0, 0.55, 0.4, 1.1, 1, 0.3) })
		K.addEmitter(a, wisps)
		H.detail(a, wisps)
		-- grass and gold kicked up as you walk
		local kick = H.feetPiece(a, Vector3.new(1.2, 0.3, 1.2), 0.3)
		K.addEmitter(a, E(kick, { tex = BFX.strand, colors = K.seq(BLADE, BLADE_M), rate = 10, life = { 0.5, 0.8 }, speed = { 3, 6 }, size = 0.6, accel = Vector3.new(0, -25, 0), spin = 300, spread = 45, light = 0, bright = 1 }), true)
		K.addEmitter(a, E(kick, { tex = T.glint, flip = 4, colors = K.seq(GOLD_L, GOLD), rate = 6, life = { 0.5, 0.9 }, speed = { 1, 3 }, size = 0.6, accel = Vector3.new(0, 1, 0), spread = 60, light = 0.4, bright = 1.2 }), true)

		-- the Graze at work: while you walk you bite every 0.75 s (a bite the server reports near you lands at once and sets
		-- the beat), standing you chew slower; each bite snaps the gold ring in from the rim, pops the gold ring round your
		-- mouth and bursts grass from it; the grass stream storms while you walk
		local lastBite, chompAt, wantBite = -10, -10, false
		local walkingNow, chompShown, biteShown = false, false, false
		local function bite(t: number)
			chompAt = t
			emit(chompFx, 8)
		end
		H.job(a, function(self, f)
			local walking = f.calm < 0.5
			if walking ~= walkingNow then
				walkingNow = walking
				setRate(a, grass, if walking then 40 else 22)
			end
			if wantBite then
				wantBite = false
				if f.t - lastBite > 0.3 then
					bite(f.t)
				end
				lastBite = f.t
			elseif f.t - lastBite >= (if walking then GRAZE_EVERY else IDLE_CHEW) then
				lastBite = f.t
				bite(f.t)
			end
			local k = (f.t - chompAt) / 0.45
			if k >= 0 and k <= 1 then
				local s = GRAZE_R * (1 - 0.85 * smooth(k)) * 2 / 0.92
				for _, c in chompParts do
					c.p.Size = Vector3.new(s * c.k, 0.05, s * c.k)
				end
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
			local b = (f.t - chompAt) / 0.35
			if b >= 0 and b <= 1 then
				local s = 0.6 + 2.4 * smooth(b)
				biteRing.Size = Vector3.new(s, 0.05, s)
				for _, img in biteImgs do
					img.ImageTransparency = 0.2 + 0.8 * b * b
				end
				biteShown = true
			elseif biteShown then
				biteShown = false
				for _, img in biteImgs do
					img.ImageTransparency = 1
				end
			end
		end)
		H.gimmick(a, { graze = true }, 9, function()
			wantBite = true
		end)

		K.outline(a, GOLD, 0.35)
		K.light(a, GOLD, 0.7, 14)
		H.lightJob(a, 0.1)
		-- a gold and grass trail behind your feet (low light emission, so it stays gold)
		local trailAt = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		local ft = K.trail(trailAt, Vector3.new(-0.85, 0.15, 0), Vector3.new(0.85, 0.15, 0), K.seq(GOLD, GOLD_D, GRASS), 0.55, 0.3)
		K.bright(ft, 1.2)
		K.move(a, trailAt, function(f)
			return CFrame.new(f.feet) * f.yaw
		end)

		-- the heartbeat: a gold ring races out over the ground, the gold pieces flash, the halo sparkles, the light
		-- swells
		local throb = 0
		H.every(a, 1.8, function(self, f)
			if f.ground > 0.3 then
				K.pulse(f.feet, 2, 17, GOLD_D, 1, 0.25)
			end
			self.lightKick = 1.4
			throb = 1
			emit(haloSparkle, 3)
		end)
		local lastThrob = -1
		H.job(a, function(self, f)
			throb *= 0.9
			if math.abs(throb - lastThrob) > 0.01 then
				lastThrob = throb
				local k = math.min(throb, 1.6)
				goldGlow.FillTransparency = math.max(0, 0.56 - 0.12 * k)
				goldGlow.OutlineTransparency = math.max(0, 0.25 - 0.15 * k)
			end
		end)

		-- the entrance: the horns drop on, the shades slide down, the halo drops in, the gold rings tilt up, the emblem
		-- and its rings grow in (their movers above); rings race out, the bite rings snap in, grass, wool and motes
		-- burst; as the horns settle they flash and their glint runs
		local settleAt = math.huge
		H.job(a, function(self, f)
			if f.t >= settleAt then
				settleAt = math.huge
				hornGlint:Emit(14)
				emit(hornSparkle, 6)
				throb = 1.6
				self.lightKick = 1.6
			end
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 22, GOLD_D, 1.1, 0.15)
			K.pulse(feet, 1, 15, GRASS_L, 0.85, 0.25)
			emit(grass, 30)
			emit(chompFx, 10)
			emit(wool, 4)
			emit(motes, 12)
			chompAt = os.clock()
			settleAt = os.clock() + 1.05
			self.lightKick = 1.8
		end
		return a
	end
end
