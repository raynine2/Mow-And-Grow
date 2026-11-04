-- GARDENER (Uncommon). The card: red pruning shears snipping a stem, leaves flying, a green-gloved hand. Gimmick: Green
-- Thumb, bundles fly to you from much further away. The aura, built round the card:
--   - the ForgeGUI vine-wreath emblem under you (soil with three sprouts in a wreath of pink and yellow flowers) on a
--     soft green glow, one crisp light-green line ring round it, a few small green leaves and pink petals off its rim
--   - the ForgeGUI red pruning shears (5.2 studs, as tall as you) held in the card's green glove, at chest height 3.8
--     studs out on the camera's side of you: they rest at your right, hop over the back of your head to your left,
--     rest, hop back, so they're seen from every side and never cover you. Every 1.4 s they snap shut on a green
--     sprig: a white slash line across the jaws, a burst of cut leaves and stem bits, and the sprig's leafy tip flies
--     off tumbling (the stem grows back)
--   - the green thumb on both hands: a green glow and a green light on each, leaves and a sparkle trail off them
--   - small leaves (three greens) and pink petals riding a breeze close round you, knees to head
--   - your Green Thumb reach (own aura only): a crisp ring of leafy vine far out round you, flowing slowly round, with a
--     dashed green line inside it
-- Leaves and petals kicked up when you walk. It has more going on than the Weed Puller's, less than the Rares'.
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local LOOP = "Loop_Gardener" -- its VFX Forge particle layers

	-- colours: the leaves (lighter than the lawn, so they don't vanish into it), the sprig, the steel, the wreath's pink
	local LEAF = rgb(95, 190, 60)
	local LEAF_L = rgb(185, 245, 120)
	local LIME = rgb(185, 255, 95)
	local STEM = rgb(70, 150, 50)
	local STEEL = rgb(235, 245, 255)
	local GLOVE = rgb(85, 195, 70) -- the card's green glove
	-- three leaf greens (council: pale leaves read as popcorn on the lawn) and the wreath's pink petals
	local GREEN1 = K.seq(rgb(110, 200, 60), rgb(70, 160, 45))
	local GREEN2 = K.seq(rgb(150, 220, 75), rgb(100, 185, 55))
	local GREEN3 = K.seq(rgb(85, 175, 55), rgb(55, 135, 40))
	local PETALS = K.seq(rgb(255, 170, 210), rgb(240, 110, 165))

	local EMBLEM = 8.2 -- the vine-wreath emblem's width (studs)
	local SHEARS = 5.2 -- the shears' height (the prop's longest side): as tall as you
	local ORBIT = 3.8 -- how far out they rest at your sides (clear of your body)
	local HOP = 4.2 -- seconds for a hop right-to-left and back
	local LIFT = 0.7 -- their centre over your root: chest height
	local SNIP = 1.4 -- seconds between snips
	local JAW = 0.28 -- where the blades bite: this share of the shears' height above their centre (a guess from the
	-- prop's picture: the gold bolt sits at about 0.13, the blade tips at 0.5)
	local SPRIG = 1.8 -- the length of the sprig's stem held in the jaws
	local TIP = 0.6 -- its leafy tip (it flies off on each snip)
	local FLY = 0.55 -- how long the cut tip flies
	local REACH = 14 -- server/ClassPerks MAGNET_BONUS (studs further than everyone else)
	local REACH_R = REACH + 4 -- the Green Thumb ring's radius (as the old aura drew it)
	local VINES = 24 -- the reach ring's vine segments

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
	-- a flat ground piece that grows in from nothing (overshooting a touch) every time the aura forms
	local function growIn(a: any, p: BasePart, size: number, dur: number, delay: number?)
		local shown = -1
		H.job(a, function(self, f)
			local k = (f.t - self.born - (delay or 0)) / dur
			local s = if k >= 1 then size else math.max(0.1, size * ease(k))
			if s ~= shown then
				shown = s
				p.Size = Vector3.new(s, 0.05, s)
			end
		end)
	end
	local function each(list: { ParticleEmitter }, fn: (ParticleEmitter) -> ())
		for _, e in list do
			fn(e)
		end
	end
	local function lock(e: ParticleEmitter)
		e.LockedToPart = true -- (rides its holder as it turns: the particles swirl round you)
	end
	-- leaf greens (or pink petals) on a Forge layer, barely glowing (so they keep their colour and don't bloom)
	local function tint(list: { ParticleEmitter }, colors: ColorSequence): { ParticleEmitter }
		for _, e in list do
			e.Color = colors
			e.LightEmission = 0.15
			e.Brightness = 1
		end
		return list
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

	return function()
		local a = H.aura(H.RANK.Uncommon, LEAF)

		-- the ground: a soft green glow, the ForgeGUI vine-wreath emblem turning slowly on it, one crisp light-green line
		-- ring round its rim
		H.glowDisc(a, EMBLEM + 2.6, BFX.glow, rgb(150, 235, 110), 0.68, 0, 0.06, 1)
		local emblem = H.glowDisc(a, EMBLEM, T.embGardener, WHITE, 0.18, 0.06, 0.12, 1.1)
		growIn(a, emblem, EMBLEM, 0.75)
		local rimR = EMBLEM / 2 + 0.3
		local rimRing = H.glowRing(a, rimR, rgb(215, 255, 170), 0.42, 0, 0.14, 1.25)
		growIn(a, rimRing, rimR * 2 / 0.92, 0.9, 0.1)
		-- a few small leaves and the wreath's pink petals circling its rim (blowing off it as it turns)
		local rim = K.piece(a.model, Vector3.new(EMBLEM - 0.6, 0.8, EMBLEM - 0.6))
		K.move(a, rim, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, -f.t * 0.7, 0)
		end)
		local rimLeaves = tint(H.layer(a, LOOP, "Swirl", rim, false, 0.6), GREEN3)
		setRate(a, rimLeaves, 2.5)
		local petals = tint(H.layer(a, LOOP, "Petals", rim, false, 0.7), PETALS)
		setRate(a, petals, 1)
		each(rimLeaves, lock)
		each(petals, lock)

		-- the pruning shears: at chest height on the camera's side of you, always turned to the camera (blades up,
		-- leaning away from you, with a little sway) so the snip reads from every side. They rest at your right, hop in
		-- an arc over the back of your head to your left, rest, and hop back: always beside or above you as seen, never
		-- hidden behind you or covering you. They swoop in from high up, spinning, when the aura forms.
		local shears = H.prop(a.body, "gd_shears", SHEARS)
		local full = shears.Size
		local at = perFrame(function(f)
			local k = ease((f.t - a.born - 0.15) / 0.9)
			local rp = f.root.Position
			local cam = workspace.CurrentCamera
			local camCF = if cam then cam.CFrame else CFrame.lookAt(rp - f.yaw.LookVector * 12 + Vector3.new(0, 4, 0), rp)
			local fwd = Vector3.new(rp.X - camCF.Position.X, 0, rp.Z - camCF.Position.Z)
			fwd = if fwd.Magnitude > 0.3 then fwd.Unit else f.yaw.LookVector
			local right = Vector3.new(-fwd.Z, 0, fwd.X)
			-- (p: -1 resting at your right .. 1 resting at your left; the hop between goes round the far side of you)
			local p = math.clamp(2 * math.sin(f.t * 2 * math.pi / HOP), -1, 1)
			local phi = math.pi / 2 + (math.pi / 2 + 0.15) * p
			local c, s = math.cos(phi), math.sin(phi)
			local over = math.max(0, s) -- (1 at the top of the hop: behind and above your head)
			local r = ORBIT * (1 - 0.35 * over) + 5 * (1 - k)
			local pos = rp + (right * c + fwd * s) * r + Vector3.new(0, LIFT + 2.9 * over + 0.14 * math.sin(f.t * 1.5) + 4 * (1 - k), 0)
			local eye = camCF.Position
			if Vector3.new(eye.X - pos.X, 0, eye.Z - pos.Z).Magnitude < 0.3 then
				eye = pos - fwd * 10
			end
			local roll = math.rad(30) * c + 0.1 * math.sin(f.t * 1.1) + 6 * (1 - k)
			return CFrame.lookAt(pos, eye) * CFrame.Angles(0, 0.3 * math.sin(f.t * 0.8), roll)
		end)
		K.move(a, shears, at)
		-- a short steel-to-leaf streak behind the blades as they circle
		local streak = K.trail(shears, Vector3.new(0, 0.2 * SHEARS, 0), Vector3.new(0, 0.42 * SHEARS, 0), K.seq(STEEL, LEAF), 0.3, 0.3)
		streak.Transparency = ns(0, 0.6, 1, 1)
		K.bright(streak, 1.1)
		H.detail(a, streak)
		-- the card's green-gloved hand gripping the handles (the white glove prop tinted green; fingers across the
		-- handles, in front of them)
		local glove = H.prop(a.body, "lb_glove", SHEARS * 0.36)
		local gloveSA = glove:FindFirstChildOfClass("SurfaceAppearance")
		if gloveSA then
			pcall(function()
				(gloveSA :: any).Color = GLOVE
			end)
		end
		local grip = CFrame.new(0, -0.22 * SHEARS, -0.36) * CFrame.Angles(0, 0, math.rad(-80))
		K.move(a, glove, function(f)
			return at(f) * grip
		end)

		-- the green sprig held across the jaws: a stem with a leafy tip. On a snip the tip flies off tumbling and fades,
		-- a stub is left, and the stem grows back out with a new tip.
		local bite = CFrame.new(0, JAW * SHEARS, 0)
		local grow = 1 -- the stem's length (0.3 a stub .. 1 whole)
		local cutAt, cutCF, cutVel = -99, CFrame.identity, Vector3.zero
		local stem = H.cyl(a.body, SPRIG, 0.12, STEM, Enum.Material.SmoothPlastic)
		local tipStem = H.cyl(a.body, TIP, 0.1, STEM, Enum.Material.SmoothPlastic)
		local leafA = H.ellipsoid(a.body, Vector3.new(0.62, 0.3, 0.07), LEAF_L, Enum.Material.SmoothPlastic)
		local leafB = H.ellipsoid(a.body, Vector3.new(0.5, 0.26, 0.07), LIME, Enum.Material.SmoothPlastic)
		local sprigAt = perFrame(function(f)
			return at(f) * bite * CFrame.Angles(0, 0, math.rad(-16))
		end)
		K.move(a, stem, function(f)
			local len = math.max(0.05, SPRIG * grow)
			return sprigAt(f) * CFrame.new(-SPRIG * 0.45 + len / 2, 0, 0)
		end)
		local tipAt = perFrame(function(f)
			local tau = f.t - cutAt
			if tau >= 0 and tau < FLY then
				local p = cutCF.Position + cutVel * tau + Vector3.new(0, -20 * tau * tau, 0)
				return CFrame.new(p) * (cutCF - cutCF.Position) * CFrame.Angles(tau * 9, tau * 5, tau * 13)
			end
			return sprigAt(f) * CFrame.new(-SPRIG * 0.45 + SPRIG * grow, 0, 0)
		end)
		K.move(a, tipStem, function(f)
			return tipAt(f) * CFrame.new(TIP * 0.5, 0, 0)
		end)
		K.move(a, leafA, function(f)
			return tipAt(f) * CFrame.new(TIP * 0.78, 0.14, 0) * CFrame.Angles(0, 0, math.rad(35))
		end)
		K.move(a, leafB, function(f)
			return tipAt(f) * CFrame.new(TIP * 0.72, -0.12, 0) * CFrame.Angles(0, 0, math.rad(-40))
		end)
		-- the snip's effects at the jaws: a white slash line, a burst of cut leaves (its Forge layer), bits of stem, a glint
		local jaw = K.piece(a.body, Vector3.new(0.6, 0.6, 0.6))
		K.move(a, jaw, function(f)
			return at(f) * bite
		end)
		local snipFx = tint(H.layer(a, LOOP, "Snip", jaw, false, 0.75), GREEN1)
		-- (the slash: a white crescent swept across the jaws, a thin line, not a blob)
		local slash = H.E(jaw, { tex = T.crescent, flip = 4, colors = K.seq(WHITE, rgb(225, 255, 205)), rate = 0, life = { 0.2, 0.24 }, speed = { 0, 0 }, size = 3.4, spread = 0, light = 0.5, bright = 1.3, lock = true, rot = { -40, -20 }, sizeSeq = ns(0, 3.2, 1, 3.6) })
		-- (bits of cut stem flung off)
		local bits = H.E(jaw, { tex = BFX.strand, colors = K.seq(rgb(120, 200, 70), STEM), rate = 0, life = { 0.4, 0.7 }, speed = { 5, 8 }, size = 0.45, spin = 400, spread = 180, accel = Vector3.new(0, -20, 0), light = 0.1, bright = 1 })
		local glint = H.E(jaw, { tex = T.glint, flip = 4, colors = K.seq(WHITE, LEAF_L), rate = 0, life = { 0.25, 0.35 }, speed = { 0, 0 }, size = 1.1, spread = 0, light = 0.7, bright = 1.3, sizeSeq = ns(0, 1.1, 1, 1.1) })
		H.detail(a, glint)

		-- small leaves (three greens) and pink petals riding a breeze close round you, knees to head (they ride a
		-- turning cylinder, so they swirl round you and stay airborne); every snip also shakes a puff of cut leaves out
		local swirl = K.piece(a.body, Vector3.new(3.2, 4, 3.2))
		K.move(a, swirl, function(f)
			return CFrame.new(f.root.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, f.t * 1.6, 0)
		end)
		local breeze = tint(H.layer(a, LOOP, "Swirl", swirl, false, 0.6), GREEN1)
		setRate(a, breeze, 3.5)
		each(breeze, lock)
		-- (a second green, off on phones)
		local more = tint(H.layer(a, LOOP, "Swirl", swirl, false, 0.6), GREEN2)
		setRate(a, more, 3)
		each(more, lock)
		H.detail(a, table.unpack(more))
		local bodyPetals = tint(H.layer(a, LOOP, "Petals", swirl, false, 0.7), PETALS)
		setRate(a, bodyPetals, 1.2)
		each(bodyPetals, lock)
		local puff = tint(H.layer(a, LOOP, "Snip", swirl, false, 0.6), GREEN2)

		-- snip every 1.4 s (the first one as they arrive): the shears squeeze shut (blades and handles close together,
		-- they're one model so it narrows across), hold, ease open, wait. On the snap the sprig's tip flies off and the
		-- stem grows back.
		local shut, shown, tipShown = 0, 0, 0
		H.job(a, function(self, f)
			local ph = ((f.t - self.born - 0.9) % SNIP) / SNIP
			local s
			if ph < 0.05 then
				s = (ph / 0.05) ^ 2
			elseif ph < 0.16 then
				s = 1
			elseif ph < 0.45 then
				s = 1 - smooth((ph - 0.16) / 0.29)
			else
				s = 0
			end
			if s ~= shut then
				if shut < 0.9 and s >= 0.9 then
					-- the snap: the tip (where it is now) flies off outward and up
					cutCF = tipAt(f)
					local rp = f.root.Position
					local out = Vector3.new(cutCF.Position.X - rp.X, 0, cutCF.Position.Z - rp.Z)
					out = if out.Magnitude > 0.1 then out.Unit else f.yaw.LookVector
					cutVel = out * 5 + Vector3.new(0, 7.5, 0)
					cutAt = f.t
					each(snipFx, function(e)
						e:Emit(10)
					end)
					each(puff, function(e)
						e:Emit(4)
					end)
					slash:Emit(1)
					bits:Emit(5)
					glint:Emit(1)
					self.lightKick = 1.5
				end
				shut = s
				-- (written in tenths: resizing a MeshPart isn't free)
				local q = math.floor(s * 10 + 0.5) / 10
				if q ~= shown then
					shown = q
					shears.Size = Vector3.new(full.X * (1 - 0.48 * q), full.Y, full.Z)
				end
			end
			-- the stem: a stub once cut, growing back out after the tip has flown
			local tau = f.t - cutAt
			local g = if tau < 0 then 1 else 0.3 + 0.7 * smooth((tau - 0.6) / 0.4)
			if g ~= grow then
				grow = g
				stem.Size = Vector3.new(math.max(0.05, SPRIG * g), 0.12, 0.12)
			end
			-- the tip: fades at the end of its flight, gone a moment, back on the regrowing stem
			local hide = if tau < 0 or tau >= 0.62 then 0 elseif tau < FLY - 0.15 then 0 elseif tau < FLY then (tau - (FLY - 0.15)) / 0.15 else 1
			hide = math.floor(hide * 10 + 0.5) / 10
			if hide ~= tipShown then
				tipShown = hide
				tipStem.Transparency = hide
				leafA.Transparency = hide
				leafB.Transparency = hide
			end
		end)

		-- the green thumb: both hands glow green (a steady glow sprite and a green light on each), shed leaves and
		-- leave a sparkle trail (the card's green glove)
		for _, hand in { "RightHand", "LeftHand" } do
			local h = K.piece(a.body, Vector3.new(0.4, 0.4, 0.4))
			K.move(a, h, function(f)
				local l = H.limb(f, hand)
				if not l then
					return f.root
				end
				-- (an R6 arm is a long block: its hand is at the bottom)
				return l.CFrame * CFrame.new(0, if l.Size.Y > 1.2 then -0.85 else -0.1, 0)
			end)
			local glow = H.E(h, { tex = FX.glow, colors = K.seq(rgb(175, 255, 120), rgb(90, 215, 60)), rate = 6, life = { 0.4, 0.5 }, speed = { 0, 0 }, size = 1.2, spread = 0, light = 0.8, bright = 1.1, lock = true, sizeSeq = ns(0, 1.05, 1, 1.25), trans = ns(0, 1, 0.2, 0.4, 0.75, 0.45, 1, 1) })
			K.addEmitter(a, glow)
			for _, e in H.layer(a, LOOP, "Thumb", h, false, 0.9) do
				e.Color = K.seq(rgb(170, 255, 120), rgb(80, 200, 60))
				e.LightEmission = 0.6
			end
			local lamp = Instance.new("PointLight")
			lamp.Color = rgb(120, 255, 80)
			lamp.Brightness = 1.6
			lamp.Range = 5
			lamp.Shadows = false
			lamp.Parent = h
			H.detail(a, lamp)
			local leaves = tint(H.layer(a, LOOP, "ThumbLeaves", h, false, 0.75), GREEN1)
			setRate(a, leaves, 2.5)
			local trail = K.trail(h, Vector3.new(0, 0.16, 0), Vector3.new(0, -0.16, 0), K.seq(rgb(200, 255, 150), rgb(90, 215, 60)), 0.4, 0.6)
			trail.Transparency = ns(0, 0.2, 1, 1)
			K.bright(trail, 1.2)
			local sparkle = H.E(h, { tex = T.glint, flip = 4, colors = K.seq(rgb(235, 255, 200), LIME), rate = 3, life = { 0.4, 0.6 }, speed = { 0.2, 0.6 }, size = 0.45, spread = 180, light = 0.7, bright = 1.3 })
			K.addEmitter(a, sparkle)
			H.detail(a, sparkle)
		end
		-- leaves and petals kicked up when you walk
		local kickAt = H.feetPiece(a, Vector3.new(1.4, 0.2, 1.4), 0.1)
		tint(H.layer(a, LOOP, "Kick", kickAt, true, 0.7), GREEN3)
		local kickPetals = tint(H.layer(a, LOOP, "Petals", kickAt, true, 0.7), PETALS)
		H.detail(a, table.unpack(kickPetals))
		-- a green glow round you, a green light that flares on each snip, a leafy trail when you run
		H.shell(a, K.seq(rgb(150, 230, 100), LEAF), 5, 1)
		K.light(a, LEAF, 0.9, 11)
		H.lightJob(a, 0.08)
		K.feetTrail(a, K.seq(LEAF_L, LEAF))

		-- Green Thumb: your reach, drawn far out round you as a crisp ring of leafy vine (green, flowing slowly round,
		-- dimmer while you run) with a dashed green line just inside it, so it reads from above. The vine spreads out to
		-- the reach when the aura forms. Your own aura only. (No leaves fly out there: particles stay near you.)
		local ringHold = H.feetPiece(a, Vector3.new(0.2, 0.2, 0.2), 0.2, 0.03)
		local vineAtts, vines = {}, {}
		for i = 1, VINES do
			local th = (i - 1) / VINES * math.pi * 2
			vineAtts[i] = H.att(ringHold, Vector3.new(math.cos(th), 0, math.sin(th)) * 0.5)
		end
		local chord = 2 * REACH_R * math.sin(math.pi / VINES)
		for i = 1, VINES do
			local b = H.beam(vineAtts[i], vineAtts[i % VINES + 1], { tex = T.vineStrip, texLen = chord, texSpeed = 0.25, colors = K.seq(rgb(120, 225, 70)), w0 = 1.3, trans = NumberSequence.new(0.15), light = 0.3, bright = 1.2 })
			b.Enabled = false
			vines[i] = b
			table.insert(a.fades, { beam = b, base = 0.15 })
		end
		local ringR = -1
		H.job(a, function(self, f)
			local r = REACH_R * math.max(0.03, ease((f.t - self.born - 0.2) / 1.3))
			if math.abs(r - ringR) > 0.01 then
				ringR = r
				for i, at0 in vineAtts do
					local th = (i - 1) / VINES * math.pi * 2
					at0.Position = Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
				end
			end
		end)
		local _, dashes = K.groundRing(a, REACH_R - 0.95, 0.14, rgb(150, 240, 90), 2, 0.3, -0.06, true, 0.22)
		for _, b in dashes do
			b.Enabled = false
			table.insert(vines, b)
		end
		local ringOn: boolean? = nil
		H.job(a, function(self, f)
			local own = f.player ~= nil and f.player == H.player
			if own ~= ringOn then
				ringOn = own
				for _, b in vines do
					b.Enabled = own
				end
			end
		end)

		-- the entrance: the emblem and ring grow in, the reach ring spreads out, the shears swoop in spinning, a burst of
		-- leaves and petals (the core plays the Form_Gardener burst too)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 10, LEAF_L, 0.7, 0.1)
			each(snipFx, function(e)
				e:Emit(14)
			end)
			each(breeze, function(e)
				e:Emit(8)
			end)
			each(rimLeaves, function(e)
				e:Emit(10)
			end)
			each(petals, function(e)
				e:Emit(8)
			end)
			each(bodyPetals, function(e)
				e:Emit(6)
			end)
		end
		return a
	end
end
