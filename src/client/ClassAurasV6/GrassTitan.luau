-- GRASS TITAN (Legendary). The card: a giant mossy boulder-and-vine foot with daisies stomping a striped lawn, a green
-- shockwave ring. Gimmick: Titan Stomp, landing from a jump hits every clump within 12 studs twice (every 4 s).
-- Built from the ForgeGUI props (gt_boulder, gt_crown), the ForgeGUI stone-rune emblem and the VFX Forge layers of
-- Loop_GrassTitan (Pebbles, Moss, Rise, Quake):
--   - mossy boulder boots on both feet, a vine winding up each leg out of them. While the Titan Stomp is ready the boots
--     glow green (a green haze, green light, sparks off their cracks); right after a stomp they go dark and light up
--     again as it recharges
--   - the stomp's reach (12 studs) drawn on the ground while it's ready; while it recharges a dim ring grows out to it
--   - three big mossy boulders floating in a crescent behind you in a green glow, shedding pebbles and moss; small
--     rocks circling your waist on green trails
--   - the stone rune crown floating over your head on a ring of glowing runes
--   - the stone-rune emblem under you in a soft green glow, a ring of mossy standing stones round it (they hop when a
--     stomp lands, sink into the ground while you run), green light rising off it
--   - every running step lands like a quake (a green ring and dust under that boot, the rocks jolt); a stomp slams the
--     floating rocks down, flings pebbles and sends a shockwave out to the reach
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX, FX = H.BFX, H.FX
	local E = H.E
	local LOOP = "Loop_GrassTitan"
	local GLOW = rgb(150, 255, 105) -- the glowing cracks' green
	local MOSS = rgb(95, 190, 65) -- moss green: the aura's own colour
	local VINE_L, VINE_D = rgb(150, 225, 95), rgb(62, 140, 50)
	local DIM = rgb(78, 104, 74) -- the reach ring while the stomp recharges
	local DARK = rgb(95, 100, 95) -- the boots' tint while it recharges (on props that can take a tint)
	local RADIUS, COOLDOWN = 12, 4 -- server/ClassPerks STOMP_RADIUS, STOMP_COOLDOWN
	local BOOT = Vector3.new(1.3, 1.12, 1.72) -- a boulder boot: the round boulder stretched heel to toe
	-- the crescent of boulders behind you: angle from straight behind (rad), height over your middle, size, distance out
	-- (the middle one rides high, clear of the crown, so the crown reads against the sky)
	local CRESCENT = { { -1.2, 1.5, 1.7, 3.2 }, { 0, 4.7, 2.1, 2.7 }, { 1.2, 1.5, 1.7, 3.2 } }
	-- the small rocks circling your waist: size, distance out, height
	local DEBRIS = { { 0.55, 2.35, -0.35 }, { 0.42, 2.6, 0.05 }, { 0.62, 2.45, -0.6 }, { 0.38, 2.7, 0.2 }, { 0.5, 2.3, -0.15 }, { 0.45, 2.55, -0.5 } }

	-- a base worked out once per frame (several pieces ask for it)
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
	-- tints a prop through its SurfaceAppearance, where it has one (a MeshPart's own texture can't be tinted)
	local function tinter(p: BasePart): (Color3) -> ()
		local sa = p:FindFirstChildOfClass("SurfaceAppearance")
		return function(c: Color3)
			if sa then
				pcall(function()
					(sa :: any).Color = c
				end)
			end
		end
	end
	-- how far the floating rocks drop `dt` seconds after a running step lands (a small jolt)...
	local function jolt(dt: number): number
		if dt < 0 or dt > 0.5 then
			return 0
		end
		return 0.2 * math.exp(-dt * 9) * math.sin(dt * 34)
	end
	-- ...and after a stomp (0 to 1: slammed down, then bouncing back)
	local function slam(dt: number): number
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
		local a = H.aura(H.RANK.Legendary, MOSS)
		local lastStomp = -100 -- (os.clock of the last Titan Stomp: the boots light up again over COOLDOWN)
		local stepAt, slamAt = -100, -100 -- the last running step and the last stomp (the floating rocks jolt / slam)
		local centre = once(function(f): CFrame
			return CFrame.new(f.root.Position) * f.yaw
		end)
		local drop = once(function(f): CFrame
			return CFrame.new(0, -(jolt(f.t - stepAt) + 1.7 * slam(f.t - slamAt)), 0)
		end)

		-- the ground: a soft green glow, the stone-rune emblem (grows in), green light rising off it
		H.glowDisc(a, 13.5, BFX.glow, MOSS, 0.45, 0, 0.07, 1)
		H.sigil(a, 10, T.embGrassTitan, WHITE, 0.18, 0, 0.12, 0.9, 1.1)
		local riseHold = H.feetPiece(a, Vector3.new(6.4, 0.2, 6.4), 0.3)
		local rise = H.layer(a, LOOP, "Rise", riseHold)
		for _, e in rise do
			e.ShapePartial = 0 -- (as H.updraft: a flat cone, so the streaks rise off the whole circle)
		end
		-- the stomp's reach: bright at 12 studs while the stomp is ready (the readiness job below)
		local reach, reachImgs = H.glowRing(a, RADIUS, GLOW, 0.35, 0, 0.16, 1.3)

		-- the boulder boots (the card's stomping foot), each with its own glow, light and sparks for the readiness, a
		-- vine winding up the leg out of it and a dust holder on the ground under it (the quake of each step)
		local boots = {}
		local quakes, pebbles = {}, {}
		for i, foot in { "RightFoot", "LeftFoot" } do
			local side = if i == 1 then 1 else -1
			local footAt = once(function(f): CFrame
				local l = H.limb(f, foot)
				if l then
					return l.CFrame * CFrame.new(side * 0.05, 0.42 - l.Size.Y / 2, -0.1)
				end
				return f.root * CFrame.new(side * 0.5, -2.55, -0.1)
			end)
			local boot = H.prop(a.body, "gt_boulder", BOOT.Z)
			boot.Size = BOOT
			K.move(a, boot, footAt)
			local haze = E(boot, { tex = BFX.glow, colors = K.seq(GLOW, MOSS), rate = 5, life = { 0.5, 0.8 }, speed = { 0, 0 }, size = 2.6, spread = 0, light = 1, bright = 1, lock = true, trans = ns(0, 1, 0.4, 0.7, 1, 1) })
			local sparks = E(boot, { tex = FX.spark, colors = K.seq(WHITE, GLOW), rate = 4, life = { 0.4, 0.8 }, speed = { 0.6, 1.6 }, size = 0.2, grow = true, accel = Vector3.new(0, 2.5, 0), spread = 180, light = 1, bright = 2 })
			local light = Instance.new("PointLight")
			light.Color = GLOW
			light.Range = 7
			light.Brightness = 1.8
			light.Shadows = false
			light.Parent = boot
			H.detail(a, sparks, light)
			H.layer(a, LOOP, "Moss", boot, false, 0.8)
			local quakeHold = K.piece(a.model, Vector3.new(1.2, 0.2, 1.2))
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
				local r = 0.68 - 0.1 * u
				pts[k + 1] = Vector3.new(math.cos(th) * r, 0.3 + u * 1.5, math.sin(th) * r)
			end
			for _, b in H.chain(vineHold, pts, { colors = K.seq(VINE_L, VINE_D), w0 = 0.34, w1 = 0.14, tex = T.vineStrip, texLen = 1.2, light = 0.15, bright = 1.2 }) do
				H.detail(a, b)
			end
			table.insert(boots, { part = boot, at = footAt, haze = haze, sparks = sparks, light = light, quake = quake, tint = tinter(boot) })
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

		-- three big boulders floating in a crescent behind you (the middle one high over your head), swaying and turning
		-- slowly with the moss kept on top; they rise out of the ground when the aura forms
		for i, s in CRESCENT do
			local rock = H.prop(a.body, "gt_boulder", s[3])
			local ph = i * 2.1
			K.move(a, rock, function(f)
				local k = ease((f.t - a.born - 0.06 * i) / 0.7)
				local ang = s[1] + 0.07 * math.sin(f.t * 0.45 + ph)
				local y = (s[2] + 0.2 * math.sin(f.t * 1.1 + ph)) * k - 3.3 * (1 - k)
				return drop(f) * centre(f) * CFrame.new(math.sin(ang) * s[4], y, math.cos(ang) * s[4]) * CFrame.Angles(0.12 * math.sin(f.t * 0.6 + ph), f.t * 0.3 + ph, 0.1 * math.cos(f.t * 0.5 + ph))
			end)
			for _, e in H.layer(a, LOOP, "Pebbles", rock, false, s[3] / 2) do
				table.insert(pebbles, e)
				if i ~= 2 then
					H.detail(a, e)
				end
			end
			if i == 2 then
				H.layer(a, LOOP, "Moss", rock)
			end
			-- held up by the titan's power: a green glow round each boulder, green motes rising off it
			K.addEmitter(a, E(rock, { tex = BFX.glow, colors = K.seq(GLOW, MOSS), rate = 2.5, life = { 0.6, 0.9 }, speed = { 0, 0 }, size = s[3] * 1.7, spread = 0, light = 1, bright = 1, lock = true, trans = ns(0, 1, 0.4, 0.78, 1, 1) }))
			local motes = E(rock, { tex = FX.spark, colors = K.seq(WHITE, GLOW), rate = 2, life = { 0.8, 1.2 }, speed = { 0.3, 0.8 }, size = 0.18, grow = true, accel = Vector3.new(0, 1.5, 0), spread = 180, light = 1, bright = 2 })
			K.addEmitter(a, motes)
			H.detail(a, motes)
		end
		-- small rocks circling your waist on a tilted ring, green trails behind them (pulled round by the titan's weight)
		local belt = once(function(f): CFrame
			return CFrame.new(f.root.Position) * CFrame.Angles(math.rad(10), 0, math.rad(-6)) * CFrame.Angles(0, f.t * 1.0, 0)
		end)
		for i, d in DEBRIS do
			local pebble = H.prop(a.body, "gt_boulder", d[1])
			local th = (i - 1) / #DEBRIS * math.pi * 2
			K.move(a, pebble, function(f)
				local r = d[2] * ease((f.t - a.born - 0.1 - 0.04 * i) / 0.6)
				return drop(f) * belt(f) * CFrame.new(math.cos(th) * r, d[3] + 0.12 * math.sin(f.t * 1.7 + i), math.sin(th) * r) * CFrame.Angles(0.3 * math.sin(f.t + i), f.t * 0.9 + i, 0.2 * math.cos(f.t * 0.8 + i))
			end)
			local trail = H.trailed(pebble, K.seq(GLOW, MOSS), 0.9, d[1] * 0.45)
			H.detail(a, pebble, trail)
		end
		-- a ring of mossy standing stones round the emblem (the boulder stood on end), rising out of the ground when the
		-- aura forms; they hop when a stomp lands and sink into the ground while you run
		for i = 1, 6 do
			local th = (i - 0.5) / 6 * math.pi * 2
			local h = 1.15 + 0.3 * ((i * 5) % 3) / 2
			local stone = H.prop(a.model, "gt_boulder", 1)
			stone.Size = Vector3.new(0.78, h, 0.64)
			local turn = CFrame.Angles(0.08 * math.sin(i * 2.3), math.pi / 2 - th, 0.08 * math.cos(i * 1.7))
			K.move(a, stone, function(f)
				local k = ease((f.t - a.born - 0.15 - 0.05 * i) / 0.6)
				local dt = (f.t - slamAt - 0.03 * i) / 0.45
				local hop = if dt > 0 and dt < 1 then 0.9 * math.sin(dt * math.pi) else 0
				local y = f.feet.Y - 0.5 + h / 2 - (h + 0.4) * math.max(1 - k, 1 - f.calm) + hop
				return CFrame.new(f.feet.X + math.cos(th) * 5.6, y, f.feet.Z + math.sin(th) * 5.6) * turn
			end)
		end

		-- the stone rune crown floating over your head, turning slowly, on a ring of glowing runes with gem glints; it
		-- drops in from above when the aura forms and hops when a stomp lands
		local crownAt = once(function(f): CFrame
			local k = ease((f.t - a.born - 0.1) / 0.6)
			local hop = 0.5 * slam(f.t - slamAt) + 0.6 * jolt(f.t - stepAt)
			local up = 0.95 + 0.1 * math.sin(f.t * 1.5) + 3 * (1 - k) + hop
			return CFrame.new(f.head + Vector3.new(0, up, 0)) * f.yaw * CFrame.Angles(0.06 * math.sin(f.t * 1.1), f.t * 0.5, 0.06 * math.cos(f.t * 0.9))
		end)
		local crown = H.prop(a.body, "gt_crown", 2.1)
		K.move(a, crown, crownAt)
		local band = K.piece(a.body, Vector3.new(1.9, 0.4, 1.9))
		K.move(a, band, function(f)
			return crownAt(f) * CFrame.new(0, -0.7, 0)
		end)
		local runes = K.beamRing(band, 0.95, 0.2, K.seq(GLOW, MOSS), 3, 0.05, 12, false)
		for _, b in runes do
			b.Texture = T.runeStrip
			b.TextureMode = Enum.TextureMode.Stretch
			b.LightEmission = 1
			H.detail(a, b)
		end
		local glints = E(band, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GLOW), rate = 2.5, life = { 0.4, 0.7 }, speed = { 0, 0.2 }, size = 0.45, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, glints)
		H.detail(a, glints)

		-- Titan Stomp readiness: dark right after a stomp, lighting up as it recharges (the reach ring grows back out
		-- to 12 studs, dim), then bright again when it's ready (the reach flashes, the boots puff green)
		local shown = -1
		H.job(a, function(self, f)
			local c = math.clamp((f.t - lastStomp) / COOLDOWN, 0, 1)
			local ready = c >= 1
			if not ready then
				local d = (2.5 + (RADIUS - 2.5) * smooth(c)) * 2 / 0.92
				reach.Size = Vector3.new(d, 0.05, d)
			end
			local q = if ready then 1 else math.floor(c * 24) / 24
			if q == shown then
				return
			end
			local first = shown < 0
			shown = q
			local col = DIM:Lerp(GLOW, q * q)
			for _, img in reachImgs do
				img.ImageColor3 = col
			end
			if ready then
				local d = RADIUS * 2 / 0.92
				reach.Size = Vector3.new(d, 0.05, d)
			end
			for _, b in boots do
				b.light.Brightness = if ready then 1.8 else 0.15 + 0.5 * q
				b.haze.Rate = if ready then 5 else 0
				b.sparks.Rate = if ready then 4 else 0
				b.tint(if ready then WHITE else DARK:Lerp(WHITE, q * 0.5))
			end
			if ready and not first then
				K.pulse(f.feet, RADIUS * 2 - 5, RADIUS * 2, GLOW, 0.5, 0.2)
				for _, b in boots do
					b.haze:Emit(3)
					b.sparks:Emit(10)
				end
				self.lightKick = 1.8
			end
		end)
		-- while it's ready and you stand, a faint ring runs out to the reach every few seconds
		H.every(a, 3, function(self, f)
			if f.t - lastStomp > COOLDOWN and f.calm > 0.6 then
				K.pulse(f.feet, RADIUS * 2 - 4, RADIUS * 2 + 0.4, GLOW, 1, 0.6)
			end
		end)
		-- every running step lands like a quake, left and right in turn: a green ring and dust under that boot
		local nextFoot = 1
		H.every(a, 0.4, function(self, f)
			if f.calm > 0.5 then
				return
			end
			nextFoot = 3 - nextFoot
			local b = boots[nextFoot]
			local p = b.at(f).Position
			K.pulse(Vector3.new(p.X, f.feet.Y, p.Z), 1, 7, GLOW, 0.45, 0.3)
			for _, e in b.quake do
				e:Emit(4)
			end
			stepAt = f.t
		end)

		H.shell(a, K.seq(GLOW, MOSS), 6, 1)
		K.feetTrail(a, K.seq(GLOW, MOSS))
		K.outline(a, GLOW, 0.35)
		K.light(a, GLOW, 1.2, 14)
		H.lightJob(a, 0.08)
		-- the Titan Stomp landing: the rocks slam down, a shockwave out to the reach, dust and pebbles everywhere
		H.gimmick(a, { stomp = true }, 8, function(self, d)
			lastStomp = os.clock()
			slamAt = lastStomp
			self.lightKick = 3
			local feet = self.rootPos - Vector3.new(0, 2.7, 0)
			K.pulse(feet, 1, RADIUS * 2, GLOW, 0.7, 0)
			K.pulse(feet, 1, 10, WHITE, 0.4, 0.3)
			for _, e in quakes do
				e:Emit(10)
			end
			for _, e in pebbles do
				e:Emit(6)
			end
			for _, e in rise do
				e:Emit(10)
			end
		end)
		-- the entrance: a quake (the boots grow, the boulders rise out of the ground, the crown drops in) and a
		-- shockwave out to the reach
		a.onForm = function(self, feet)
			K.pulse(feet, 1, RADIUS * 2, GLOW, 0.9, 0)
			K.pulse(feet, 1, 12, WHITE, 0.55, 0.25)
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
