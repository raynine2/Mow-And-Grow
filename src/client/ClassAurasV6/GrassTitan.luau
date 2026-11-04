-- GRASS TITAN (Legendary). The card: a giant mossy boulder-and-vine foot with daisies stomping a striped lawn, a green
-- shockwave ring. Gimmick: Titan Stomp, landing from a jump hits every clump within 12 studs twice (every 4 s).
-- Built from the ForgeGUI props (gt_foot, gt_slab, gt_boulder, gt_crown), the ForgeGUI stone-rune emblem and the VFX
-- Forge layers of Loop_GrassTitan (Pebbles, Moss, Rise, Quake), in deep emerald on a dark pool so it doesn't wash out
-- into the lawn:
--   - the titan's foot: a giant ghostly mossy stone foot hovering high behind you, side on (toes to your right). While
--     the stomp is ready it hangs poised, toes up, glowing; on a Titan Stomp it slams down behind you (a shockwave out
--     to the reach, dust, pebbles) and rises again as the stomp recharges. Seen from behind (your own camera) it goes
--     see-through so it never hides you
--   - six standing rune stones (menhirs) round you at the stomp's reach (12 studs), runes facing you. They rise out of
--     the ground as the stomp recharges and their runes light up when it's ready; a stomp crashes them back into the
--     ground. The ones between the camera and you stay sunk, so they frame you instead of hiding you
--   - chunky cracked boulder boots on both feet, a vine winding up each leg out of them; they glow while the stomp is
--     ready. Every running step lands like a quake: a green ring, dust and glowing cracks under that boot
--   - the stone rune crown floating over your head, its runes glowing, on a ring of glowing runes
--   - the stone-rune emblem on a dark emerald pool, three thin emerald line rings turning over it, green light rising
--     off it, and the stomp's reach (12 studs) drawn as a bright line with a dark edge (a dim ring growing back out to
--     it while the stomp recharges)
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local LOOP = "Loop_GrassTitan"
	local EMERALD = rgb(40, 200, 110) -- the glowing cracks' deep emerald: the aura's own colour
	local JADE = rgb(150, 245, 180) -- pale jade: bright cores and lines
	local LEAF = rgb(90, 215, 120)
	local DEEP = rgb(12, 58, 36) -- the dark emerald pool and the dark edges
	local VINE_L, VINE_D = rgb(150, 225, 95), rgb(62, 140, 50)
	local DIM = rgb(36, 84, 58) -- the reach ring while the stomp recharges
	local DARK = rgb(95, 100, 95) -- the boots' tint while it recharges (on props that can take a tint)
	local RADIUS, COOLDOWN = 12, 4 -- server/ClassPerks STOMP_RADIUS, STOMP_COOLDOWN
	local BOOT = Vector3.new(1.75, 1.62, 2.55) -- a boulder boot: the round boulder stretched heel to toe
	local FOOT_L = 9 -- the titan's foot, heel to toe
	local FOOT_BACK, FOOT_UP = 4.6, 6.2 -- poised: this far behind you, its sole this high over the ground
	local FALL = 0.12 -- the foot's slam down
	local CRASH = 0.35 -- the rune stones crashing into the ground after a stomp
	local SLAB_H = { 5.6, 6.2, 5.3, 6.0, 5.5, 6.3 } -- the rune stones' heights

	-- a value worked out once per frame (several pieces ask for it)
	local function once(base: (any) -> any): (any) -> any
		local lastT, last = -1, nil
		return function(f)
			if f.t ~= lastT then
				lastT = f.t
				last = base(f)
			end
			return last
		end
	end
	-- a prop's SurfaceAppearance (tint, glow), if it has one
	local function saOf(p: BasePart): Instance?
		return p:FindFirstChildOfClass("SurfaceAppearance")
	end
	local function setSA(sa: Instance?, prop: string, v: any)
		if sa then
			pcall(function()
				(sa :: any)[prop] = v
			end)
		end
	end
	-- how far the foot and crown drop `dt` seconds after a running step lands (a small jolt)...
	local function jolt(dt: number): number
		if dt < 0 or dt > 0.5 then
			return 0
		end
		return 0.2 * math.exp(-dt * 9) * math.sin(dt * 34)
	end
	-- ...and how the crown jumps after a stomp lands (0 to 1: up, then bouncing back)
	local function bounce(dt: number): number
		local k = dt / 1.1
		if k < 0 or k >= 1 then
			return 0
		end
		if k < 0.14 then
			return math.sin(k / 0.14 * math.pi / 2)
		end
		return math.exp(-(k - 0.14) * 5) * math.cos((k - 0.14) * 14)
	end

	return function()
		local a = H.aura(H.RANK.Legendary, EMERALD)
		local lastStomp = -100 -- (os.clock of the last Titan Stomp: everything lights up again over COOLDOWN)
		local slamAt = -100 -- the foot's last slam (it lands FALL later)
		local landPending = false
		local stepAt = -100 -- the last running step (the foot and crown jolt)
		local function recharge(t: number): number
			return math.clamp((t - lastStomp) / COOLDOWN, 0, 1)
		end

		-- THE GROUND: a dark emerald pool (so the green glows against it), a soft emerald glow, the stone-rune emblem
		-- (grows in), three thin line rings turning over it, green light rising off it
		H.glowDisc(a, 15.5, BFX.glow, DEEP, 0.3, 0, 0.05, 1)
		H.glowDisc(a, 12.5, BFX.glow, EMERALD, 0.66, 0, 0.07, 1)
		H.sigil(a, 10, T.embGrassTitan, WHITE, 0.18, 0, 0.12, 0.9, 1.1)
		H.glowRing(a, 4.45, JADE, 0.5, 0.3, 0.15, 1)
		H.glowRing(a, 5.2, EMERALD, 0.4, -0.2, 0.16, 1)
		H.glowRing(a, 6.1, LEAF, 0.5, 0.14, 0.17, 1)
		local riseHold = H.feetPiece(a, Vector3.new(6.4, 0.2, 6.4), 0.3)
		local rise = H.layer(a, LOOP, "Rise", riseHold)
		for _, e in rise do
			e.ShapePartial = 0 -- (as H.updraft: a flat cone, so the streaks rise off the whole circle)
			e.Color = K.seq(rgb(195, 255, 215), EMERALD)
			e.LightEmission = 0.75
		end
		-- the stomp's reach: a bright line with a dark edge at 12 studs while the stomp is ready (the readiness job)
		local reachDark = H.glowRing(a, RADIUS + 0.15, DEEP, 0.35, 0, 0.13, 1)
		local reach, reachImgs = H.glowRing(a, RADIUS, JADE, 0.3, 0, 0.16, 1.1)

		-- THE BOULDER BOOTS (the card's stomping foot): chunky cracked rock with moss and daisies, each with its own light
		-- and sparks for the readiness, a vine winding up the leg out of it and a dust holder on the ground under it
		local boots = {}
		local quakes = {}
		for i, foot in { "RightFoot", "LeftFoot" } do
			local side = if i == 1 then 1 else -1
			local footAt = once(function(f): CFrame
				local l = H.limb(f, foot)
				if l then
					return l.CFrame * CFrame.new(side * 0.22, 0.62 - l.Size.Y / 2, -0.15)
				end
				return f.root * CFrame.new(side * 0.7, -2.38, -0.15)
			end)
			local boot = H.prop(a.body, "gt_boulder", BOOT.Z)
			boot.Size = BOOT
			K.move(a, boot, footAt)
			local sparks = E(boot, { tex = FX.spark, colors = K.seq(JADE, EMERALD), rate = 4, life = { 0.4, 0.8 }, speed = { 0.6, 1.6 }, size = 0.22, grow = true, accel = Vector3.new(0, 2.5, 0), spread = 180, light = 0.8, bright = 1.5 })
			local light = Instance.new("PointLight")
			light.Color = EMERALD
			light.Range = 7
			light.Brightness = 1.6
			light.Shadows = false
			light.Parent = boot
			H.detail(a, sparks, light)
			H.layer(a, LOOP, "Moss", boot, false, 0.8)
			local quakeHold = K.piece(a.model, Vector3.new(1.4, 0.2, 1.4))
			K.move(a, quakeHold, function(f)
				local p = footAt(f).Position
				return CFrame.new(p.X, f.feet.Y - 0.1, p.Z)
			end)
			local quake = H.layer(a, LOOP, "Quake", quakeHold)
			for _, e in quake do
				table.insert(quakes, e)
			end
			local vineHold = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, vineHold, footAt)
			local pts = {}
			for k = 0, 6 do
				local u = k / 6
				local th = side * u * math.pi * 2.3 + 0.5
				local r = 0.66 - 0.12 * u
				pts[k + 1] = Vector3.new(math.cos(th) * r, 0.6 + u * 1.6, math.sin(th) * r)
			end
			for _, b in H.chain(vineHold, pts, { colors = K.seq(VINE_L, VINE_D), w0 = 0.34, w1 = 0.14, tex = T.vineStrip, texLen = 1.2, light = 0.15, bright = 1.2 }) do
				H.detail(a, b)
			end
			local sa = saOf(boot)
			table.insert(boots, { part = boot, at = footAt, sparks = sparks, light = light, quake = quake, tint = function(c: Color3)
				setSA(sa, "Color", c)
			end })
		end
		-- the boots grow out of the ground round your feet when the aura forms
		local grown = false
		H.job(a, function(self, f)
			local life = f.t - self.born
			if life > 0.8 then
				if not grown then
					grown = true
					for _, b in boots do
						b.part.Size = BOOT
					end
				end
				return
			end
			grown = false
			local k = math.max(0.05, ease(life / 0.5))
			for _, b in boots do
				b.part.Size = BOOT * k
			end
		end)
		-- the cracks a running step leaves: two sets of thin glowing fissures (one per boot), left where you stepped
		-- and fading
		local cracks = {}
		for c = 1, 2 do
			local cr = { at = CFrame.new(0, -1000, 0), born = -100, tr = 1, parts = {} }
			for s = 1, 5 do
				local len = 0.8 + 0.3 * ((s * 7 + c) % 4)
				local p = H.solid(a.model, Vector3.new(0.13, 0.05, len), EMERALD, Enum.Material.Neon)
				p.Transparency = 1
				local off = CFrame.Angles(0, s / 5 * math.pi * 2 + c * 0.6 + 0.3 * math.sin(s * 3.1), 0) * CFrame.new(0, 0, -len / 2 - 0.3)
				K.move(a, p, function(f)
					return cr.at * off
				end)
				table.insert(cr.parts, p)
			end
			cracks[c] = cr
		end
		H.job(a, function(self, f)
			for _, cr in cracks do
				local age = f.t - cr.born
				local tr = if age < 0.75 then 0.15 + 0.85 * smooth(age / 0.75) else 1
				if math.abs(tr - cr.tr) > 0.04 or (tr == 1 and cr.tr ~= 1) then
					cr.tr = tr
					for _, p in cr.parts do
						p.Transparency = tr
					end
				end
			end
		end)

		-- THE TITAN'S FOOT (ForgeGUI, toes at its -Z, sole down): ghostly (see-through, a deep emerald glow and a dark
		-- edge), hovering high behind you side on with its toes to your right, swaying. Ready: poised, toes up. A stomp:
		-- it slams flat onto the ground behind you, holds, then rises as the stomp recharges (hanging lower and dimmer
		-- until it's ready). It drops in from the sky when the aura forms.
		local foot = H.prop(a.body, "gt_foot", FOOT_L)
		local fs = H.propSize("gt_foot", FOOT_L)
		local footSA = saOf(foot)
		if foot:IsA("MeshPart") then
			foot.Transparency = 0.25
		end
		setSA(footSA, "Color", rgb(200, 255, 215)) -- (a pale ghostly green)
		local FOOT_TURN = CFrame.Angles(0, -math.pi / 2, 0) -- (toes to your right: side on, it reads as a foot)
		-- 0 = flat on the ground, 1 = poised
		local function footLift(t: number): number
			local dt = t - slamAt
			if dt >= 0 and dt < FALL then
				local k = dt / FALL
				return 1 - k * k
			elseif dt >= FALL and dt < FALL + 0.4 then
				return 0
			end
			local hang = 0.62 + 0.38 * smooth(recharge(t))
			local up = if dt >= 0 then smooth((dt - FALL - 0.4) / 1.1) else 1
			return hang * up
		end
		local footCF = once(function(f): CFrame
			local k = ease((f.t - a.born - 0.05) / 0.8)
			local lift = footLift(f.t)
			local y = fs.Y * 0.5 + FOOT_UP * lift + 0.18 * math.sin(f.t * 1.2) * lift + 14 * (1 - k) - 0.6 * jolt(f.t - stepAt)
			local tilt = math.rad(13) * lift + 0.04 * math.sin(f.t * 0.9) -- (toes up while poised, flat as it lands)
			return CFrame.new(f.feet) * f.yaw * CFrame.new(0, y, FOOT_BACK) * FOOT_TURN * CFrame.Angles(tilt, 0, 0.03 * math.sin(f.t * 0.7))
		end)
		K.move(a, foot, footCF)
		local footGlow = E(foot, { tex = BFX.glow, colors = K.seq(EMERALD, DEEP), rate = 3, life = { 0.8, 1.2 }, speed = { 0, 0 }, size = 4.2, spread = 0, light = 0.6, bright = 1, lock = true, trans = ns(0, 1, 0.4, 0.78, 1, 1) })
		K.addEmitter(a, footGlow)
		local pebbles = H.layer(a, LOOP, "Pebbles", foot, false, 1.5)
		H.layer(a, LOOP, "Moss", foot, false, 1.3)
		local ghost = Instance.new("Highlight") -- (the ghostly look: an emerald sheen and a dark edge)
		ghost.Adornee = foot
		ghost.FillColor = EMERALD
		ghost.FillTransparency = 0.82
		ghost.OutlineColor = DEEP:Lerp(EMERALD, 0.35)
		ghost.OutlineTransparency = 0.25
		ghost.DepthMode = Enum.HighlightDepthMode.Occluded
		ghost.Parent = a.body
		H.detail(a, ghost)
		-- dust where it lands
		local dustHold = K.piece(a.model, Vector3.new(6, 0.3, 4))
		K.move(a, dustHold, function(f)
			local p = footCF(f).Position
			return CFrame.new(p.X, f.feet.Y, p.Z) * f.yaw
		end)
		local footDust = H.layer(a, LOOP, "Quake", dustHold, false, 1.6)
		-- your own camera behind you: the foot goes see-through so it never hides you
		local faded = false
		H.job(a, function(self, f)
			local cam = workspace.CurrentCamera
			local behind = f.player ~= nil and f.player == H.player and cam ~= nil and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3
			if behind ~= faded then
				faded = behind
				foot.LocalTransparencyModifier = if behind then 0.55 else 0
				ghost.FillTransparency = if behind then 0.94 else 0.82
				ghost.OutlineTransparency = if behind then 0.7 else 0.25
			end
		end)

		-- THE RUNE STONES (ForgeGUI menhirs, the rune on their -Z face): six round you at the stomp's reach, runes facing
		-- you. They stand while the stomp is ready (runes lit), crash into the ground when a stomp lands and rise again
		-- as it recharges; they sink while you run, and the ones on the camera's side of you stay down so they never
		-- hide you. They rise out of the ground one after another when the aura forms.
		local camDir = once(function(f): Vector3 -- (from you towards the camera, flat)
			local cam = workspace.CurrentCamera
			if not cam then
				return Vector3.zero
			end
			local d = cam.CFrame.Position - f.feet
			d = Vector3.new(d.X, 0, d.Z)
			if d.Magnitude < 1 then
				return Vector3.zero
			end
			return d.Unit
		end)
		local standing = once(function(f): number -- (how far all of them stand, before the camera's say)
			local dl = f.t - slamAt - FALL
			local r
			if dl >= 0 and dl < CRASH then
				r = 1 - smooth(dl / CRASH)
			else
				r = smooth((recharge(f.t) - 0.15) / 0.85)
			end
			return r * smooth((f.calm - 0.25) / 0.6)
		end)
		local slabs = {}
		for i = 1, 6 do
			local th = (i - 0.5) / 6 * math.pi * 2
			local slab = H.prop(a.model, "gt_slab", SLAB_H[i])
			local ss = H.propSize("gt_slab", SLAB_H[i])
			local dir = Vector3.new(math.cos(th), 0, math.sin(th))
			local turn = CFrame.Angles(0.05 * math.sin(i * 2.3), math.pi / 2 - th, 0.05 * math.cos(i * 1.7)) -- (-Z towards you)
			K.move(a, slab, function(f)
				local cd = camDir(f)
				local camK = 1 - smooth((dir.X * cd.X + dir.Z * cd.Z - 0.15) / 0.5)
				local formK = math.min(1, ease((f.t - a.born - 0.25 - 0.07 * i) / 0.7))
				local up = standing(f) * camK * formK
				local dl = f.t - slamAt - FALL - 0.02 * i
				local shake = if dl > 0 and dl < CRASH then 0.12 * math.sin(dl * 60) else 0
				local y = f.feet.Y - 0.45 + ss.Y / 2 - (ss.Y + 0.6) * (1 - up)
				return CFrame.new(f.feet.X + dir.X * RADIUS + shake, y, f.feet.Z + dir.Z * RADIUS) * turn
			end)
			-- the rune's glow on its face (lit while the stomp is ready)
			local glowAt = H.att(slab, Vector3.new(0, ss.Y * 0.08, -ss.Z / 2 - 0.15))
			local glow = E(glowAt, { tex = BFX.glow, colors = K.seq(JADE, EMERALD), rate = 1.2, life = { 0.8, 1.2 }, speed = { 0, 0 }, size = 2.4, spread = 0, light = 0.6, bright = 1, lock = true, trans = ns(0, 1, 0.4, 0.7, 1, 1) })
			H.detail(a, glow)
			table.insert(slabs, { part = slab, sa = saOf(slab), glow = glow })
		end

		-- THE CROWN: the stone rune crown floating over your head, turning slowly, its runes glowing, on a ring of glowing
		-- runes with gem glints; it drops in from above when the aura forms and jumps when a stomp lands
		local CROWN = 2.95
		local crown = H.prop(a.body, "gt_crown", CROWN)
		local cs = H.propSize("gt_crown", CROWN)
		setSA(saOf(crown), "EmissiveStrength", 2.5)
		local crownAt = once(function(f): CFrame
			local k = ease((f.t - a.born - 0.1) / 0.6)
			local hop = 0.5 * bounce(f.t - slamAt - FALL) + 0.6 * jolt(f.t - stepAt)
			local up = cs.Y * 0.5 + 0.4 + 0.1 * math.sin(f.t * 1.5) + 3 * (1 - k) + hop
			return CFrame.new(f.head + Vector3.new(0, up, 0)) * f.yaw * CFrame.Angles(0.06 * math.sin(f.t * 1.1), f.t * 0.5, 0.06 * math.cos(f.t * 0.9))
		end)
		K.move(a, crown, crownAt)
		local band = K.piece(a.body, Vector3.new(2.7, 0.4, 2.7))
		K.move(a, band, function(f)
			return crownAt(f) * CFrame.new(0, -cs.Y * 0.5 - 0.05, 0)
		end)
		local runes = K.beamRing(band, 1.33, 0.28, K.seq(JADE, EMERALD), 3, 0.05, 12, false)
		for _, b in runes do
			b.Texture = T.runeStrip
			b.TextureMode = Enum.TextureMode.Stretch
			b.LightEmission = 0.7
			H.detail(a, b)
		end
		local glints = E(band, { tex = T.glint, flip = 4, colors = K.seq(WHITE, JADE), rate = 2.5, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 0.5, spread = 180, light = 0.8, bright = 1.6 })
		K.addEmitter(a, glints)
		H.detail(a, glints)

		-- TITAN STOMP READINESS: dark right after a stomp, lighting up as it recharges (the reach ring grows back out to
		-- 12 studs, dim; the foot rises, the rune stones climb out of the ground), then bright again when it's ready
		-- (the reach flashes, the runes and the foot glow, the boots spark)
		local shown = -1
		H.job(a, function(self, f)
			local c = recharge(f.t)
			local ready = c >= 1
			if not ready then
				local d = (2.5 + (RADIUS - 2.5) * smooth(c)) * 2 / 0.92
				reach.Size = Vector3.new(d, 0.05, d)
				reachDark.Size = Vector3.new(d + 0.33, 0.05, d + 0.33)
			end
			local q = if ready then 1 else math.floor(c * 24) / 24
			if q == shown then
				return
			end
			local first = shown < 0
			shown = q
			local col = DIM:Lerp(JADE, q * q)
			for _, img in reachImgs do
				img.ImageColor3 = col
			end
			if ready then
				local d = RADIUS * 2 / 0.92
				reach.Size = Vector3.new(d, 0.05, d)
				reachDark.Size = Vector3.new(d + 0.33, 0.05, d + 0.33)
			end
			for _, b in boots do
				b.light.Brightness = if ready then 1.6 else 0.15 + 0.5 * q
				b.sparks.Rate = if ready then 4 else 0
				b.tint(if ready then WHITE else DARK:Lerp(WHITE, q * 0.5))
			end
			for _, s in slabs do
				setSA(s.sa, "EmissiveStrength", if ready then 3 else 0.4 + q)
				s.glow.Rate = if ready then 1.2 else 0
			end
			setSA(footSA, "EmissiveStrength", if ready then 3 else 0.5 + 1.5 * q)
			footGlow.Rate = if ready then 3 else 1
			if ready and not first then
				K.pulse(f.feet, RADIUS * 2 - 5, RADIUS * 2, EMERALD, 0.5, 0.2)
				for _, b in boots do
					b.sparks:Emit(10)
				end
				for _, s in slabs do
					s.glow:Emit(2)
				end
				footGlow:Emit(3)
				self.lightKick = 1.8
			end
		end)
		-- while it's ready and you stand, a faint ring runs out to the reach every few seconds
		H.every(a, 3, function(self, f)
			if f.t - lastStomp > COOLDOWN and f.calm > 0.6 then
				K.pulse(f.feet, RADIUS * 2 - 4, RADIUS * 2 + 0.4, EMERALD, 1, 0.6)
			end
		end)
		-- every running step lands like a quake, left and right in turn: a green ring, dust and glowing cracks under
		-- that boot (the cracks stay where you stepped)
		local nextFoot = 1
		H.every(a, 0.4, function(self, f)
			if f.calm > 0.5 then
				return
			end
			nextFoot = 3 - nextFoot
			local b = boots[nextFoot]
			local p = b.at(f).Position
			K.pulse(Vector3.new(p.X, f.feet.Y, p.Z), 1, 7, EMERALD, 0.45, 0.3)
			for _, e in b.quake do
				e:Emit(4)
			end
			local cr = cracks[nextFoot]
			cr.at = CFrame.new(p.X, f.feet.Y - 0.2, p.Z) * CFrame.Angles(0, (f.t * 3.7) % (math.pi * 2), 0)
			cr.born = f.t
			stepAt = f.t
		end)

		H.shell(a, K.seq(JADE, EMERALD), 6, 1)
		K.feetTrail(a, K.seq(JADE, EMERALD))
		K.outline(a, EMERALD, 0.35)
		K.light(a, EMERALD, 1.2, 14)
		H.lightJob(a, 0.08)
		-- the Titan Stomp: the foot slams down behind you; as it lands, a shockwave out to the reach, the rune stones
		-- crash into the ground, dust and pebbles everywhere
		H.gimmick(a, { stomp = true }, 8, function(self, d)
			local now = os.clock()
			lastStomp = now
			slamAt = now
			landPending = true
			self.lightKick = 1.6
		end)
		H.job(a, function(self, f)
			if not landPending or f.t < slamAt + FALL then
				return
			end
			landPending = false
			self.lightKick = 3
			K.pulse(f.feet, 1, RADIUS * 2, EMERALD, 0.7, 0)
			K.pulse(f.feet, 1, 10, JADE, 0.4, 0.3)
			for _, e in quakes do
				e:Emit(10)
			end
			for _, e in footDust do
				e:Emit(14)
			end
			for _, e in pebbles do
				e:Emit(8)
			end
			for _, e in rise do
				e:Emit(10)
			end
		end)
		-- the entrance: a quake (the boots grow, the rune stones rise out of the ground, the crown drops in, the titan's
		-- foot comes down out of the sky) and a shockwave out to the reach
		a.onForm = function(self, feet)
			K.pulse(feet, 1, RADIUS * 2, EMERALD, 0.9, 0)
			K.pulse(feet, 1, 12, JADE, 0.55, 0.25)
			for _, e in quakes do
				e:Emit(10)
			end
			for _, b in boots do
				b.sparks:Emit(8)
			end
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
