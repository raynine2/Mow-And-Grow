-- LAWN LEGEND (Mythic) - the card: a crown of green leaves set with red roses and a lucky four-leaf clover. Gimmick:
-- Hot Streak, each clump cut in a streak adds +5% power (up to +60%: the player attribute ClassStreak, 0..60) and it
-- fades 2.5 s after you stop, so the class burns hotter the longer the streak. Aura, built from ForgeGUI props and the
-- VFX Forge layers in Loop_LawnLegend:
--   - the card's crown on your head: the ForgeGUI leaf-and-rose wreath (ll_wreath, gold clover at the front) lying on
--     your head; it drops on with a spin when the aura forms and burns with the streak
--   - the same wreath as a big halo (7 studs), high over and behind your head (above the follow camera's line to
--     you, so it never covers you), tipped back a little; real fire climbs it as the streak heats (bottom, sides, top)
--   - wings of fire: two layered rows of the feathered wing art on each shoulder, crimson #C8102E to orange at the
--     back, orange to gold #FFB300 in front, their colours flickering, with real flames burning along every feather of
--     the back row; they unfold when the aura forms, beat slowly and spread wider with the streak
--   - a fire spiral: a double helix of beams round you to twice your height (crimson at the bottom, gold at the top,
--     turning), with flames running up each strand
--   - the ForgeGUI rose-wreath emblem under you, three crisp line rings over it (a gold rim, a rose-red dashed ring and
--     a gold dashed ring round the fire heart, turning opposite ways); the heartbeat sends a crimson ring then a gold
--     one racing out from its rim
--   - the Hot Streak meter: twelve embers set round the emblem's wreath, dull sparks until the streak lights them, one
--     per +5%: a lit one burns with a small flame
--   - embers and rose petals, a ring of fire round your feet, burning footsteps when you run
-- Rose red, leaf green, gold and flame: the card's own colours (its pink backdrop is the Mythic rarity's colour, so it
-- isn't used). All the fire is recoloured gold-to-crimson with low light emission so it stays crimson and gold on a
-- sunny lawn instead of blooming to white.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local FX = H.FX
	local E = H.E
	local LOOP = "Loop_LawnLegend"
	local CRIM = rgb(200, 16, 46) -- #C8102E
	local ROSE = rgb(222, 34, 50)
	local FLAME = rgb(255, 110, 20)
	local GOLD = rgb(255, 179, 0) -- #FFB300
	local GOLD_L = rgb(255, 214, 110)
	local EMBER = rgb(150, 34, 20)
	-- every flame: gold where it's born, cooling to flame orange and crimson (no white core)
	local FIRE = K.seq(GOLD, FLAME, CRIM)

	-- the streak, 0..60 (+% power)
	local function streakOf(f): number
		local v = if f.player then f.player:GetAttribute("ClassStreak") else nil
		return math.clamp(tonumber(v) or 0, 0, 60)
	end
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
	local function join(into: { ParticleEmitter }, list: { ParticleEmitter })
		for _, e in list do
			table.insert(into, e)
		end
	end
	-- a Forge fire layer recoloured so it keeps its colour in daylight (low light emission, capped brightness)
	local function fire(list: { ParticleEmitter }, glow: number?): { ParticleEmitter }
		for _, e in list do
			e.Color = FIRE
			e.LightEmission = glow or 0.4
			e.Brightness = 1.3
		end
		return list
	end
	local function sparks(list: { ParticleEmitter }, colors: ColorSequence): { ParticleEmitter }
		for _, e in list do
			e.Color = colors
			e.LightEmission = 0.5
			e.Brightness = 1.4
		end
		return list
	end

	return function()
		local a = H.aura(H.RANK.Mythic, ROSE)
		local streak, heat = 0, 0 -- the streak (0..60) and its heat (0..1, smoothed)
		H.job(a, function(self, f)
			streak = streakOf(f)
			heat += (streak / 60 - heat) * 0.08
		end)

		-- the ground: the ForgeGUI rose-wreath emblem (leaves, red roses, the clover, a heart of fire) turning slowly, and
		-- three crisp line rings over it (Sol's RNG look): a gold rim, a rose-red dashed ring outside it turning one way,
		-- a gold dashed ring round the fire heart turning the other
		local EMB = 15
		local EMB_SPIN = -0.05
		H.sigil(a, EMB, T.embLawnLegend, WHITE, 0.2, EMB_SPIN, 0.12, 0.9, 1.05)
		H.glowRing(a, EMB * 0.5, GOLD, 0.42, 0, 0.15, 1.1)
		K.groundRing(a, EMB * 0.5 + 0.85, 0.13, ROSE, 1.5, 0.4, 0.35, true, 0.16)
		K.groundRing(a, EMB * 0.27, 0.11, GOLD, 1.5, 0.45, -0.55, true, 0.17)

		-- the heartbeat's rings: a crimson ring (lub) then a gold one (dub) racing out from the emblem's rim and fading
		local beats = {}
		for i, c in { CRIM, GOLD } do
			local p, imgs = H.plate(a.model, 1, T.ringCrisp, c, 1, false, 1.2)
			local lift = 0.19 + 0.01 * i
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(0, lift, 0))
			end)
			beats[i] = { p = p, imgs = imgs, t0 = -99, done = true }
		end
		local function beat(i: number, t: number)
			beats[i].t0 = t
			beats[i].done = false
		end
		H.job(a, function(self, f)
			for _, b in beats do
				if not b.done then
					local k = (f.t - b.t0) / 0.85
					if k >= 1 then
						b.done = true
						for _, img in b.imgs do
							img.ImageTransparency = 1
						end
					else
						local r = EMB * 0.5 + 6.5 * (1 - (1 - k) ^ 3)
						local s = r * 2 / 0.92
						b.p.Size = Vector3.new(s, 0.05, s)
						for _, img in b.imgs do
							img.ImageTransparency = 0.15 + 0.85 * k
						end
					end
				end
			end
		end)

		-- the Hot Streak meter: twelve embers set round the emblem's wreath (turning with it): dull dark-red sparks until
		-- the streak lights them, one per +5%; a lit one burns with a small flame and throws sparks
		local SLOT_R = EMB * 0.37
		local slotFire, slotSparks = {}, {}
		for i = 1, 12 do
			local th = (i - 1) / 12 * math.pi * 2
			local p = K.piece(a.model, Vector3.new(0.5, 0.3, 0.5))
			K.move(a, p, function(f)
				return CFrame.new(f.feet) * CFrame.Angles(0, f.t * EMB_SPIN + th, 0) * CFrame.new(SLOT_R, 0.35, 0)
			end)
			slotFire[i] = fire(H.layer(a, LOOP, "Fire", p, false, 0.42))
			setRate(a, slotFire[i], 0)
			slotSparks[i] = sparks(H.layer(a, LOOP, "Embers", p, false, 0.6), K.seq(rgb(190, 60, 30), EMBER))
			setRate(a, slotSparks[i], 0.7)
		end

		-- the crown (the card's): the ForgeGUI leaf-and-rose wreath lying on your head, its front face up and its gold
		-- clover at the front, tipped a little toward whoever's in front of you, its band made deeper so it reads as a
		-- crown and not a flat ring; it sways a little, drops on with a spin when the aura forms and burns with the
		-- streak (a flare off it for every +5%)
		local CROWN = 2.3
		local crown = H.prop(a.body, "ll_wreath", CROWN)
		local cs = H.propSize("ll_wreath", CROWN)
		if crown:IsA("MeshPart") then
			crown.Size = Vector3.new(cs.X, cs.Y, cs.Z * 2)
		end
		local LIE = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(102), 0, 0) -- (face up, clover forward, tipped)
		local crownCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.45) / 0.7)
			local y = 0.25 + 0.05 * math.sin(f.t * 1.6) + 3 * (1 - k)
			return CFrame.new(f.head + Vector3.new(0, y, 0)) * f.yaw * CFrame.Angles(0, (1 - k) * 5 + math.rad(5) * math.sin(f.t * 0.7), 0) * LIE
		end)
		K.move(a, crown, crownCF)
		local crownGlint = E(crown, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 1, life = { 0.4, 0.6 }, speed = { 0.2, 0.4 }, size = 0.4, spread = 180, light = 0.6, bright = 1.2 })
		K.addEmitter(a, crownGlint)
		H.detail(a, crownGlint)
		local crownFire = fire(H.layer(a, LOOP, "Fire", crown, false, 0.35))
		local crownFlare = fire(H.layer(a, LOOP, "Flare", crown, false, 0.25))

		-- the halo: the same wreath, big (7 studs), high over and behind your head (its lowest leaves level with the top
		-- of your head, above the follow camera's line to you, so it never covers you), tipped back a little. Real fire
		-- climbs it as the streak heats: its bottom burns first, then its sides, then its top. Rose petals drift off it.
		-- It rises out of the ground when the aura forms. Your own aura: a touch fainter (0.3) while the camera is behind
		-- you.
		local HALO = 7
		local halo = H.prop(a.body, "ll_wreath", HALO)
		local hs = H.propSize("ll_wreath", HALO)
		local haloCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.25) / 0.95)
			local rise = f.head.Y - f.root.Position.Y -- (the top of your head over your root)
			local y = rise + hs.Y * 0.5 + 0.1 + 0.1 * math.sin(f.t * 1.1) - 8 * (1 - k)
			return f.root * CFrame.new(0, y, 2.2) * CFrame.Angles(math.rad(15), 0, math.rad(2) * math.sin(f.t * 0.6))
		end)
		K.move(a, halo, haloCF)
		-- (the fire's holders on the wreath: its bottom, its two sides, its top)
		local BAND = hs.X * 0.39 -- (the middle of the wreath's band, from its centre)
		local function onHalo(size: Vector3, off: CFrame): BasePart
			local p = K.piece(a.body, size)
			K.move(a, p, function(f)
				return haloCF(f) * off
			end)
			return p
		end
		local haloLow = onHalo(Vector3.new(BAND * 1.3, 0.5, 0.5), CFrame.new(0, -BAND * 0.92, 0))
		local haloSides = {
			onHalo(Vector3.new(0.5, BAND * 1.1, 0.5), CFrame.new(-BAND * 0.95, -0.1, 0)),
			onHalo(Vector3.new(0.5, BAND * 1.1, 0.5), CFrame.new(BAND * 0.95, -0.1, 0)),
		}
		local haloTop = onHalo(Vector3.new(BAND * 1.2, 0.5, 0.5), CFrame.new(0, BAND * 0.92, 0))
		local fireLow = fire(H.layer(a, LOOP, "Fire", haloLow, false, 1.9))
		local fireSides = {}
		for _, p in haloSides do
			join(fireSides, fire(H.layer(a, LOOP, "Fire", p, false, 1.7)))
		end
		local fireTop = fire(H.layer(a, LOOP, "Fire", haloTop, false, 1.5))
		local haloFlare = fire(H.layer(a, LOOP, "Flare", haloLow, false, 0.5))
		local haloPetals = H.layer(a, LOOP, "Petals", halo, false, 1)
		setRate(a, haloPetals, 1.5)
		for _, e in haloPetals do
			H.detail(a, e)
		end

		-- wings of fire: two layered rows of the feathered wing art on each shoulder (a big back row shaded crimson to
		-- orange, a smaller front row shaded orange to gold, fanned a little lower), their colours flickering, and on every
		-- feather of the back row a line of real flames (the Forge fire, locked to the feather so the wing keeps its shape
		-- while it burns). Lifted to the shoulders, set back and spread sideways (clear of you from behind); they unfold
		-- when the aura forms, beat slowly, and spread wider with the streak.
		local WING = 6.2 -- (the back row's art square: the wing fills about 0.85 of its width)
		local FRONT_ROW = 0.78 -- (the front row's size, as a share of the back row's)
		local wingS = WING -- (the back row's size now: grows with the streak)
		local function wingCF(f, side: number, row: number): CFrame
			local k = ease((f.t - a.born - 0.3) / 0.9)
			local flap = math.rad(8) + math.rad(7) * math.sin(f.t * 2.1 + row * 0.5) + math.rad(75) * (1 - k)
			local s = if row == 1 then wingS else wingS * FRONT_ROW
			local tilt = math.rad(if row == 1 then 12 else -4) * k
			-- (the art's shoulder joint sits 0.43 of its width from its centre: it's put at your shoulder blade)
			return f.root * CFrame.new(side * 0.45, 1.3, if row == 1 then 1.05 else 0.85) * CFrame.Angles(0, -side * flap, side * tilt) * CFrame.new(side * s * 0.43, 0.15 * s / WING, 0)
		end
		local rows = {}
		local wingPlates, grads = {}, {}
		for row = 1, 2 do
			local L = perFrame(function(f): CFrame
				return wingCF(f, -1, row)
			end)
			local R = perFrame(function(f): CFrame
				return wingCF(f, 1, row)
			end)
			local function at(f, side: number): CFrame
				return if side < 0 then L(f) else R(f)
			end
			rows[row] = at
			local plates = H.wings(a, T.wingBladeL, T.wingBladeR, WHITE, if row == 1 then WING else WING * FRONT_ROW, 1.05, at)
			for _, p in plates do
				table.insert(wingPlates, { p = p, k = if row == 1 then 1 else FRONT_ROW })
				local gui = p:FindFirstChildOfClass("SurfaceGui")
				local img = gui and gui:FindFirstChildOfClass("ImageLabel")
				if img then
					local g = Instance.new("UIGradient")
					g.Color = if row == 1 then K.seq(CRIM, ROSE, FLAME) else K.seq(FLAME, GOLD, GOLD)
					g.Rotation = if img.Image == T.wingBladeL then 135 else 45
					g.Transparency = if row == 1 then ns(0, 0, 0.7, 0.05, 1, 0.3) else ns(0, 0.15, 1, 0.4)
					g.Parent = img
					table.insert(grads, g)
				end
			end
		end
		-- (the colours flicker: each gradient's band shifts a little, all out of step)
		H.job(a, function(self, f)
			for i, g in grads do
				g.Offset = Vector2.new(0.05 * math.sin(f.t * 9 + i * 1.7), 0.06 * math.sin(f.t * 6.5 + i * 2.3))
			end
		end)
		-- (the flames along each back-row feather: from its root on the wing's arm to its tip, in shares of the art's
		-- size, for the left wing; the right wing mirrors them)
		local FEATHERS = { { 0.4, 0.02, 0.36, -0.2 }, { 0.25, 0.17, 0.2, -0.19 }, { 0.08, 0.3, 0.03, -0.17 }, { -0.1, 0.37, -0.14, -0.14 }, { -0.28, 0.37, -0.3, -0.1 }, { -0.42, 0.33, -0.46, -0.06 } }
		local wingFire, wingEmbers = {}, {}
		for _, side in { -1, 1 } do
			for _, fd in FEATHERS do
				local x0, y0, x1, y1 = fd[1], fd[2], fd[3], fd[4]
				local mx, my = (x0 + x1) / 2, (y0 + y1) / 2
				local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
				local turn = CFrame.Angles(0, 0, -side * math.atan2(y1 - y0, x1 - x0))
				local p = K.piece(a.body, Vector3.new(len * WING * 0.9, 0.3, 0.3))
				K.move(a, p, function(f)
					return rows[1](f, side) * CFrame.new(-side * mx * wingS, my * wingS, 0) * turn
				end)
				for _, e in fire(H.layer(a, LOOP, "WingFire", p, false, 1.5)) do
					e.LockedToPart = true
					e.Speed = NumberRange.new(0.3, 0.8)
					table.insert(wingFire, e)
				end
			end
			local span = K.piece(a.body, Vector3.new(WING * 0.7, WING * 0.35, 0.3))
			K.move(a, span, function(f)
				return rows[1](f, side) * CFrame.new(0, 0.08 * wingS, 0)
			end)
			local we = sparks(H.layer(a, LOOP, "Embers", span, false, 0.8), K.seq(GOLD_L, FLAME))
			for _, e in we do
				H.detail(a, e)
			end
			join(wingEmbers, we)
		end

		-- the fire spiral: a double helix of fire round you from your feet to twice your height (wide at the bottom,
		-- narrowing up), each strand a ribbon of beams running crimson at the bottom through flame orange to gold at the
		-- top and fading out there, the whole helix turning round you; a flame runs up each strand twice over, shedding
		-- fire. It rises out of the ground when the aura forms and burns wider with the streak.
		local SPIRAL_H, TURNS, SEGS, PERIOD = 10, 2, 28, 2.1
		local helix = H.feetPiece(a, Vector3.new(0.2, 0.2, 0.2), 0.25, 1.3)
		local function hpos(u: number, strand: number): Vector3
			local th = u * TURNS * math.pi * 2 + strand * math.pi
			local r = 2.8 - 1.1 * u
			return Vector3.new(math.cos(th) * r, u * SPIRAL_H, math.sin(th) * r)
		end
		local function hue(u: number): Color3
			return if u < 0.5 then CRIM:Lerp(FLAME, u * 2) else FLAME:Lerp(GOLD, u * 2 - 1)
		end
		local helixAtts, helixBeams = {}, {}
		for strand = 0, 1 do
			local prev = H.att(helix, hpos(0, strand))
			table.insert(helixAtts, { at = prev, u = 0, strand = strand })
			for i = 1, SEGS do
				local u0, u1 = (i - 1) / SEGS, i / SEGS
				local at1 = H.att(helix, hpos(u1, strand))
				table.insert(helixAtts, { at = at1, u = u1, strand = strand })
				local b = H.beam(prev, at1, { colors = ColorSequence.new(hue(u0), hue(u1)), w0 = 0.38 * (1 - 0.5 * u0), w1 = 0.38 * (1 - 0.5 * u1), trans = NumberSequence.new(0.3 + 0.65 * u0 ^ 3, 0.3 + 0.65 * u1 ^ 3), light = 0.5, bright = 1.2, segments = 2 })
				table.insert(helixBeams, { b = b, u0 = u0, u1 = u1 })
				prev = at1
			end
		end
		local helixK = -1
		H.job(a, function(self, f)
			local k = ease((f.t - self.born - 0.15) / 1.1)
			if k ~= helixK then
				helixK = k
				for _, h in helixAtts do
					local p = hpos(h.u, h.strand)
					h.at.Position = Vector3.new(p.X * (0.35 + 0.65 * k), p.Y * math.max(0.02, k), p.Z * (0.35 + 0.65 * k))
				end
			end
		end)
		local riderFire = {}
		for i = 1, 4 do
			local p = K.piece(a.body, Vector3.new(0.4, 0.4, 0.4))
			local strand = (i - 1) % 2
			local phase = math.floor((i - 1) / 2) * 0.5
			K.move(a, p, function(f)
				local u = ((f.t - a.born) / PERIOD + phase) % 1
				local k = ease((f.t - a.born - 0.15) / 1.1)
				local hp = hpos(u, strand)
				return CFrame.new(f.feet + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, f.t * 1.3, 0) * CFrame.new(hp.X * (0.35 + 0.65 * k), hp.Y * k, hp.Z * (0.35 + 0.65 * k))
			end)
			join(riderFire, fire(H.layer(a, LOOP, "Fire", p, false, 0.75)))
		end

		-- embers and rose petals round you, a ring of fire round your feet (it roars with the streak), and burning
		-- footsteps while you run
		local around = K.bodyBox(a, Vector3.new(4.2, 4.6, 4.2), 0.2)
		local embers = sparks(H.layer(a, LOOP, "Embers", around, false, 0.9), K.seq(GOLD_L, FLAME))
		local petals = H.layer(a, LOOP, "Petals", around, false, 1)
		setRate(a, petals, 2)
		for _, e in petals do
			H.detail(a, e)
		end
		local feetRing = H.feetPiece(a, Vector3.new(3.4, 0.5, 3.4), 0.4)
		local feetFire = fire(H.layer(a, LOOP, "Fire", feetRing, false, 0.7))
		for _, e in feetFire do
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		end
		local steps = H.feetPiece(a, Vector3.new(1.4, 0.3, 1.4), 0.3)
		fire(H.layer(a, LOOP, "Fire", steps, true, 0.55))

		-- the streak's heat drives the wings (wider), the fire climbing the halo, the crown's fire, the spiral and the
		-- fire at your feet (rates kept low: colour over bloom)
		local function climb(h: number, from: number, to: number): number
			return math.clamp((h - from) / (to - from), 0, 1)
		end
		local shownWing = -1
		local function applyHeat(h: number)
			wingS = WING * (0.85 + 0.3 * h)
			if math.abs(wingS - shownWing) > 0.05 then
				shownWing = wingS
				for _, w in wingPlates do
					w.p.Size = Vector3.new(wingS * w.k, 0.05, wingS * w.k)
				end
			end
			for _, hb in helixBeams do
				hb.b.Width0 = 0.38 * (1 - 0.5 * hb.u0) * (0.85 + 0.45 * h)
				hb.b.Width1 = 0.38 * (1 - 0.5 * hb.u1) * (0.85 + 0.45 * h)
			end
			setRate(a, wingFire, 3 + 4 * h)
			setRate(a, wingEmbers, 2 + 3 * h)
			setRate(a, fireLow, 3 + 14 * h)
			setRate(a, fireSides, 14 * climb(h, 0.2, 0.7))
			setRate(a, fireTop, 12 * climb(h, 0.5, 0.9))
			setRate(a, crownFire, 3 * h)
			setRate(a, riderFire, 3 + 5 * h)
			setRate(a, feetFire, 1.5 + 7 * h)
			setRate(a, embers, 3 + 4 * h)
		end
		applyHeat(0)
		local lastHeat = 0
		H.job(a, function(self, f)
			if math.abs(heat - lastHeat) >= 0.02 then
				lastHeat = heat
				applyHeat(heat)
			end
		end)
		-- the meter: one ember lights per +5% (a flare off the crown as it does), they go dull as the streak fades
		local lit = 0
		H.job(a, function(self, f)
			local n = math.floor(streak / 5 + 0.001)
			if n == lit then
				return
			end
			for i = 1, 12 do
				local on, was = i <= n, i <= lit
				if on ~= was then
					setRate(a, slotFire[i], if on then 2.5 else 0)
					setRate(a, slotSparks[i], if on then 2.5 else 0.7)
					if on then
						emit(slotFire[i], 3)
						emit(slotSparks[i], 5)
					end
				end
			end
			if n > lit then
				emit(crownFlare, 1)
			end
			lit = n
		end)

		-- your own aura with the camera behind you: the halo and the wings go fainter, so they never hide you
		local behind = false
		H.job(a, function(self, f)
			local b = false
			if f.player ~= nil and f.player == H.player then
				local cam = workspace.CurrentCamera
				b = cam ~= nil and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3
			end
			if b ~= behind then
				behind = b
				-- (4 Nov, checked in the lab's run view: at 0.3 the halo and the wings still hid you; now the halo goes
				-- 0.6 see-through and the wings half)
				halo.LocalTransparencyModifier = if b then 0.6 else 0
				for _, wp in wingPlates do
					local gui = wp.p:FindFirstChildOfClass("SurfaceGui")
					local img = gui and gui:FindFirstChildOfClass("ImageLabel")
					if img then
						img.ImageTransparency = if b then 0.5 else 0
					end
				end
			end
		end)

		K.outline(a, FLAME, 0.25)
		K.light(a, FLAME, 0.7, 14)
		H.lightJob(a, 0.15)

		-- the heartbeat (lub-dub) every 1.5 s: a crimson ring then a gold one race out from the emblem's rim, the light
		-- throbs, the outline flashes; a hot streak spits a few flares off the halo on every beat
		local throb, dub = 0, math.huge
		H.every(a, 1.5, function(self, f)
			if f.ground > 0.3 then
				beat(1, f.t)
			end
			dub = f.t + 0.24
			throb = 1
			self.lightKick = 1.3 + 0.5 * heat
			if self.outline then
				self.outline.OutlineTransparency = 0
			end
			if heat > 0.35 then
				emit(haloFlare, math.floor(1 + 2 * heat))
			end
		end)
		H.job(a, function(self, f)
			if f.t >= dub then
				dub = math.huge
				throb = math.max(throb, 0.7)
				if f.ground > 0.3 then
					beat(2, f.t)
				end
			end
			throb *= 0.9
			local o = self.outline
			if o and o.OutlineTransparency < 0.25 then
				o.OutlineTransparency = math.min(0.25, o.OutlineTransparency + 0.01)
			end
		end)

		-- the entrance: the crown drops on, the halo rises, the wings unfold and the spiral climbs (their movers above);
		-- rings race out, fire bursts round your feet, petals and embers fly; as the halo arrives it flares up
		local settleAt = math.huge
		H.job(a, function(self, f)
			if f.t >= settleAt then
				settleAt = math.huge
				emit(haloFlare, 4)
				emit(haloPetals, 8)
				emit(fireLow, 6)
				emit(crownFlare, 2)
				beat(1, f.t)
				throb = 1.2
				self.lightKick = 1.6
			end
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 26, ROSE, 1, 0)
			K.pulse(feet, 1, 17, GOLD, 0.75, 0.12)
			emit(feetFire, 12)
			emit(petals, 16)
			emit(embers, 14)
			emit(wingFire, 3)
			settleAt = os.clock() + 0.85
			self.lightKick = 1.8
		end
		return a
	end
end
