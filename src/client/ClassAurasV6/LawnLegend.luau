-- LAWN LEGEND (Mythic) - the card: a crown of green leaves set with red roses and a lucky four-leaf clover. Gimmick:
-- Hot Streak, each clump cut in a streak adds +5% power (up to +60%: the player attribute ClassStreak, 0..60) and it
-- fades 2.5 s after you stop, so the class burns hotter the longer the streak. Aura, built from ForgeGUI props and the
-- VFX Forge layers in Loop_LawnLegend:
--   - the 3D rose-and-leaf crown (ll_crown) floating over your head; it drops on with a spin when the aura forms
--   - the same crown, huge, behind you as a halo: a fiery glow on it, a gold ring round it, a warm light behind, fire
--     licking up it as the streak heats, rose petals drifting off it
--   - great wings of fire: five flaming feathers a side (~10 studs tip to tip), slim quills of light running crimson at
--     your shoulder to gold at the tip; they unfold when the aura forms, beat slowly and blaze harder with the streak
--   - a fire spiral: three flames climbing round you to twice your height, each trailing a ribbon of fire
--   - the ForgeGUI rose-wreath emblem under you, twelve embers round its rim catching fire one per +5% of the streak
--   - embers and rose petals, a ring of fire round your feet, burning footsteps when you run, a heartbeat (lub-dub)
-- Rose red, leaf green, gold and flame: the card's own colours (its pink backdrop is the Mythic rarity's colour, so it
-- isn't used). Nothing big and bright sits on the body itself, so the avatar still shows (council: no wash-out).
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local FX = H.FX
	local E = H.E
	local LOOP = "Loop_LawnLegend"
	local CRIM = rgb(176, 16, 42)
	local ROSE = rgb(222, 34, 50)
	local FLAME = rgb(255, 120, 30)
	local GOLD = rgb(255, 196, 60)
	local GOLD_L = rgb(255, 236, 160)
	local EMBER = rgb(110, 26, 20)

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
	-- a glow over a prop (a Highlight on it alone), under the aura so it goes and comes with it
	local function glowOn(a: any, part: BasePart, fill: Color3, edge: Color3, fillT: number, edgeT: number): Highlight?
		if not part:IsA("MeshPart") then
			return nil -- (the prop is missing: an invisible stand-in, nothing to light)
		end
		local hl = Instance.new("Highlight")
		hl.Adornee = part
		hl.FillColor = fill
		hl.FillTransparency = fillT
		hl.OutlineColor = edge
		hl.OutlineTransparency = edgeT
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = a.body
		H.detail(a, hl)
		return hl
	end

	return function()
		local a = H.aura(H.RANK.Mythic, ROSE)
		local streak, heat = 0, 0 -- the streak (0..60) and its heat (0..1, smoothed)
		H.job(a, function(self, f)
			streak = streakOf(f)
			heat += (streak / 60 - heat) * 0.08
		end)

		-- the ground: the ForgeGUI rose-wreath emblem (leaves, red roses, the clover, a heart of fire) turning slowly, a
		-- gold ring round its rim
		local EMB = 15
		H.sigil(a, EMB, T.embLawnLegend, WHITE, 0.18, -0.05, 0.12, 0.9, 1.05)
		H.glowRing(a, EMB * 0.5, GOLD, 0.3, 0, 0.15, 1.2)

		-- the Hot Streak counter: twelve embers round the emblem, one catching fire per +5% of the streak
		local PIP_R = EMB * 0.5 + 0.65
		local pips, pipFire = {}, {}
		for i = 1, 12 do
			local p = K.piece(a.model, Vector3.one * 0.3, EMBER, 0.45)
			p.Shape = Enum.PartType.Ball
			local th = (i - 1) / 12 * math.pi * 2
			K.move(a, p, function(f)
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * PIP_R, 0.32, math.sin(th) * PIP_R))
			end)
			pips[i] = p
			pipFire[i] = H.layer(a, LOOP, "Fire", p, false, 0.5)
			setRate(a, pipFire[i], 0)
		end

		-- the crown (the card): the ForgeGUI rose-and-leaf crown floating over your head, swaying a little; it drops on
		-- with a spin when the aura forms, glints, and burns with the streak (a flare off it for every +5%)
		local CROWN = 1.8
		local crown = H.prop(a.body, "ll_crown", CROWN)
		local cs = H.propSize("ll_crown", CROWN)
		local crownCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.45) / 0.7)
			local y = cs.Y / 2 + 0.3 + 0.06 * math.sin(f.t * 1.6) + 3 * (1 - k)
			return CFrame.new(f.head + Vector3.new(0, y, 0)) * f.yaw * CFrame.Angles(0, (1 - k) * 5 + math.rad(8) * math.sin(f.t * 0.7), 0)
		end)
		K.move(a, crown, crownCF)
		local crownGlint = E(crown, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 2, life = { 0.4, 0.7 }, speed = { 0.2, 0.5 }, size = 0.55, spread = 180, light = 1, bright = 1.8 })
		K.addEmitter(a, crownGlint)
		local crownFire = H.layer(a, LOOP, "Fire", crown, false, 0.45)
		local crownFlare = H.layer(a, LOOP, "Flare", crown, false, 0.35)

		-- the halo: the same crown, huge, floating behind you with a fiery glow on it (stronger with the streak), a gold
		-- ring round it and a warm light behind it (seen from the front only); fire licks up it as the streak heats and
		-- rose petals drift off it. It rises out of the ground when the aura forms.
		local HALO = 6.6
		local halo = H.prop(a.body, "ll_crown", HALO)
		local hs = H.propSize("ll_crown", HALO)
		local haloCF = perFrame(function(f): CFrame
			local k = ease((f.t - a.born - 0.25) / 0.95)
			local rise = f.head.Y - f.root.Position.Y -- (the top of your head over your root)
			local y = rise + 0.35 + 0.12 * math.sin(f.t * 1.1) - 7 * (1 - k)
			-- (far enough back that the wings pass in front of it)
			return f.root * CFrame.new(0, y, 2.4) * CFrame.Angles(math.rad(-6), 0, math.rad(2) * math.sin(f.t * 0.6))
		end)
		K.move(a, halo, haloCF)
		local haloGlow = glowOn(a, halo, rgb(255, 150, 50), GOLD_L, 0.74, 0.35)
		local RING_R = math.max(hs.X, hs.Y) * 0.6
		local ring, ringImgs = H.plate(a.body, RING_R * 2 / 0.92, T.ringCrisp, GOLD, 0.3, true, 1.3)
		K.move(a, ring, function(f)
			return haloCF(f) * CFrame.new(0, 0, hs.Z * 0.5 + 0.25) * H.UPRIGHT
		end)
		local warm, _, warmGuis = H.plate(a.body, RING_R * 2.4, FX.glow, FLAME, 0.6, false, 1)
		K.move(a, warm, function(f)
			return haloCF(f) * CFrame.new(0, 0, hs.Z * 0.5 + 0.5) * CFrame.Angles(math.rad(-90), 0, 0)
		end)
		H.detail(a, warmGuis[1])
		local haloTop = K.piece(a.body, Vector3.new(hs.X * 0.8, hs.Y * 0.3, 0.6))
		K.move(a, haloTop, function(f)
			return haloCF(f) * CFrame.new(0, hs.Y * 0.28, 0)
		end)
		local haloFire = H.layer(a, LOOP, "Fire", haloTop, false, 1.3)
		local haloFlare = H.layer(a, LOOP, "Flare", haloTop, false, 1)
		local haloPetals = H.layer(a, LOOP, "Petals", halo, false, 1.1)
		setRate(a, haloPetals, 2)
		for _, e in haloPetals do
			H.detail(a, e)
		end

		-- wings of fire: five flaming feathers a side fanned out from your shoulders, each a slim quill of light (crimson at
		-- the root to gold at the tip) with fire burning along it, shorter quills between them, fire at the roots and
		-- embers over the wing. They unfold when the aura forms, beat slowly and blaze harder with the streak.
		local FEATHERS = { { 68, 3.6 }, { 45, 4.6 }, { 22, 5.1 }, { -1, 4.6 }, { -24, 3.5 } } -- (degrees up from level, length)
		local function wingCF(f, side: number): CFrame
			local k = ease((f.t - a.born - 0.3) / 0.9)
			-- (folded back along you at first; open, they sweep back only a little, staying in front of the halo)
			local flap = math.rad(10 + 78 * (1 - k)) + math.rad(6) * math.sin(f.t * 2.1)
			local lift = math.rad(4) * math.sin(f.t * 2.1 + 0.7)
			return f.root * CFrame.new(side * 0.35, 1.05, 0.62) * CFrame.Angles(0, -side * flap, 0) * CFrame.Angles(0, 0, side * lift)
		end
		local quills, wingFire, rootFire, wingEmbers = {}, {}, {}, {}
		for _, side in { -1, 1 } do
			local wcf = perFrame(function(f): CFrame
				return wingCF(f, side)
			end)
			local hub = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
			K.move(a, hub, wcf)
			for j, fd in FEATHERS do
				local ang, len = math.rad(fd[1]), fd[2]
				local dir = Vector3.new(side * math.cos(ang), math.sin(ang), 0)
				-- (the quill)
				table.insert(quills, H.beam(H.att(hub, dir * 0.2), H.att(hub, dir * len), { colors = K.seq(CRIM, ROSE, FLAME, GOLD, GOLD_L), w0 = 0.42, w1 = 0.1, trans = ns(0, 0.25, 0.65, 0.05, 1, 0.45), light = 0.6, bright = 1.3 }))
				-- (a shorter quill between this feather and the next fills the wing)
				local nx = FEATHERS[j + 1]
				if nx then
					local ca = math.rad((fd[1] + nx[1]) / 2)
					local cdir = Vector3.new(side * math.cos(ca), math.sin(ca), 0)
					local cb = H.beam(H.att(hub, cdir * 0.2), H.att(hub, cdir * (len + nx[2]) * 0.3), { colors = K.seq(CRIM, ROSE, FLAME, GOLD), w0 = 0.34, w1 = 0.08, trans = ns(0, 0.3, 0.6, 0.15, 1, 0.55), light = 0.6, bright = 1.2 })
					H.detail(a, cb)
				end
				-- (the fire along the feather: a box lying along it, its local Y kept pointing up on both wings)
				local holder = K.piece(a.body, Vector3.new(len * 0.75, 0.5, 0.35))
				local turn = if side > 0 then CFrame.Angles(0, 0, ang) else CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, ang)
				local off = CFrame.new(dir * (0.3 + len * 0.45)) * turn
				K.move(a, holder, function(f)
					return wcf(f) * off
				end)
				join(wingFire, H.layer(a, LOOP, "WingFire", holder, false, 0.85 + 0.15 * len / 5.1))
			end
			local rootBox = K.piece(a.body, Vector3.new(1.7, 2.2, 0.4))
			K.move(a, rootBox, function(f)
				return wcf(f) * CFrame.new(side * 0.9, 0.45, 0)
			end)
			join(rootFire, H.layer(a, LOOP, "Fire", rootBox, false, 1.05))
			local span = K.piece(a.body, Vector3.new(3.6, 3.8, 0.4))
			K.move(a, span, function(f)
				return wcf(f) * CFrame.new(side * 2.7, 0.9, 0)
			end)
			local we = H.layer(a, LOOP, "Embers", span, false, 0.9)
			for _, e in we do
				H.detail(a, e)
			end
			join(wingEmbers, we)
		end

		-- the fire spiral: three flames climbing one spiral round you, from your feet to twice your height (wide at the
		-- bottom, narrowing up), each trailing a ribbon of fire (gold at its head, crimson at its tail) and shedding
		-- flames. A ribbon thins to nothing at the top before its flame starts again at the bottom. It rises out of the
		-- ground when the aura forms and burns wider with the streak.
		local SPIRAL_H, TURNS, PERIOD = 9.6, 2.25, 1.9
		local riders, riderFire = {}, {}
		for i = 1, 3 do
			local p = K.piece(a.body, Vector3.new(0.35, 0.35, 0.35))
			local tr = K.trail(p, Vector3.new(0, 0.4, 0), Vector3.new(0, -0.4, 0), K.seq(GOLD_L, GOLD, FLAME, ROSE, CRIM), 0.5, 0.6)
			tr.Enabled = false -- (switched on once the aura is in place, so no streak runs in from where it was built)
			local phase = (i - 1) / 3
			local function uOf(f): number
				return ((f.t - a.born) / PERIOD + phase) % 1
			end
			K.move(a, p, function(f)
				local u = uOf(f)
				local k = ease((f.t - a.born - 0.15) / 1.1)
				local r = (2.7 - 1.05 * u) * (0.35 + 0.65 * k)
				local th = u * TURNS * math.pi * 2
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * r, (0.25 + u * SPIRAL_H) * k, math.sin(th) * r))
			end)
			join(riderFire, H.layer(a, LOOP, "Fire", p, false, 0.75))
			riders[i] = { trail = tr, a0 = tr.Attachment0, a1 = tr.Attachment1, uOf = uOf }
		end
		local trailsOn, lastPos, lastLife = false, Vector3.zero, -1
		H.job(a, function(self, f)
			local here = f.root.Position
			local jumped = (here - lastPos).Magnitude > 30 -- (a teleport: wipe the ribbons rather than draw one across)
			lastPos = here
			if not trailsOn and f.t - self.born > 0.2 then
				trailsOn = true
				for _, r in riders do
					r.trail.Enabled = true
				end
			end
			local life = 0.5 - 0.25 * (1 - f.calm) -- (shorter while you run)
			local setLife = math.abs(life - lastLife) > 0.03
			if setLife then
				lastLife = life
			end
			local wk = 0.85 + 0.45 * heat
			for _, r in riders do
				if jumped then
					r.trail:Clear()
				end
				if setLife then
					r.trail.Lifetime = life
				end
				local u = r.uOf(f)
				local w = (0.5 - 0.18 * u) * math.clamp(math.min(u / 0.08, (1 - u) / 0.1), 0, 1) * wk
				r.a0.Position = Vector3.new(0, w, 0)
				r.a1.Position = Vector3.new(0, -w, 0)
			end
		end)

		-- embers and rose petals round you, a ring of fire round your feet (it roars with the streak), and burning
		-- footsteps while you run
		local around = K.bodyBox(a, Vector3.new(4.2, 4.6, 4.2), 0.2)
		local embers = H.layer(a, LOOP, "Embers", around, false, 1)
		local petals = H.layer(a, LOOP, "Petals", around, false, 1.1)
		for _, e in petals do
			H.detail(a, e)
		end
		local feetRing = H.feetPiece(a, Vector3.new(3.4, 0.5, 3.4), 0.4)
		local feetFire = H.layer(a, LOOP, "Fire", feetRing, false, 0.8)
		for _, e in feetFire do
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		end
		local steps = H.feetPiece(a, Vector3.new(1.4, 0.3, 1.4), 0.3)
		H.layer(a, LOOP, "Fire", steps, true, 0.6)

		-- the streak's heat drives the wings, the halo's fire, the crown's fire, the spiral and the fire at your feet
		local function applyHeat(h: number)
			for _, q in quills do
				q.Width0 = 0.42 * (1 + 0.35 * h)
				q.Width1 = 0.1 * (1 + 1.2 * h)
				K.bright(q, 1.3 + 0.8 * h)
			end
			setRate(a, wingFire, 7 + 5 * h)
			setRate(a, rootFire, 6 + 10 * h)
			setRate(a, wingEmbers, 4 + 6 * h)
			setRate(a, haloFire, 4 + 22 * h)
			setRate(a, crownFire, 9 * h)
			setRate(a, riderFire, 6 + 10 * h)
			setRate(a, feetFire, 2 + 14 * h)
			setRate(a, embers, 6 + 8 * h)
		end
		applyHeat(0)
		local lastHeat = 0
		H.job(a, function(self, f)
			if math.abs(heat - lastHeat) >= 0.02 then
				lastHeat = heat
				applyHeat(heat)
			end
		end)
		-- the counter: one ember lights per +5% (a flare off the crown as it does), they go out as the streak fades
		local lit = 0
		H.job(a, function(self, f)
			local n = math.floor(streak / 5 + 0.001)
			if n == lit then
				return
			end
			for i, p in pips do
				local on, was = i <= n, i <= lit
				if on ~= was then
					p.Color = if on then GOLD else EMBER
					p.Transparency = if on then 0 else 0.45
					p.Size = Vector3.one * (if on then 0.42 else 0.3)
					setRate(a, pipFire[i], if on then 3 else 0)
					if on then
						emit(pipFire[i], 4)
					end
				end
			end
			if n > lit then
				emit(crownFlare, 2)
			end
			lit = n
		end)

		K.outline(a, FLAME, 0.2)
		K.light(a, FLAME, 1, 15)
		H.lightJob(a, 0.15)
		K.feetTrail(a, K.seq(GOLD, FLAME, CRIM))

		-- the heartbeat (lub-dub): a rose-red ring then a gold one race out over the ground, the halo's ring and glow and
		-- the light throb, the outline flashes; a hot streak spits flares off the halo on every beat
		local throb, dub = 0, math.huge
		H.every(a, 1.5, function(self, f)
			if f.ground > 0.3 then
				K.pulse(f.feet, 2, 16 + heat * 8, ROSE, 0.8, 0.1)
			end
			dub = f.t + 0.24
			throb = 1
			self.lightKick = 1.5 + 0.8 * heat
			if self.outline then
				self.outline.OutlineTransparency = 0
			end
			if heat > 0.35 then
				emit(haloFlare, math.floor(2 + 5 * heat))
			end
		end)
		local lastFill = -1
		H.job(a, function(self, f)
			if f.t >= dub then
				dub = math.huge
				throb = math.max(throb, 0.7)
				if f.ground > 0.3 then
					K.pulse(f.feet, 2, 10 + heat * 5, GOLD, 0.6, 0.3)
				end
			end
			throb *= 0.9
			local beat = math.min(throb, 1)
			local fill = math.clamp(0.74 - 0.26 * heat - 0.22 * beat, 0.2, 1)
			if math.abs(fill - lastFill) > 0.01 then
				lastFill = fill
				if haloGlow then
					haloGlow.FillTransparency = fill
					haloGlow.OutlineTransparency = 0.35 - 0.35 * beat
				end
				for _, img in ringImgs do
					img.ImageTransparency = 0.3 - 0.25 * beat
				end
			end
			local o = self.outline
			if o and o.OutlineTransparency < 0.2 then
				o.OutlineTransparency = math.min(0.2, o.OutlineTransparency + 0.01)
			end
		end)

		-- the entrance: the crown drops on, the halo rises, the wings unfold and the spiral climbs (their movers above);
		-- rings race out, fire bursts round your feet, petals and embers fly; as the halo arrives it blazes up
		local settleAt = math.huge
		H.job(a, function(self, f)
			if f.t >= settleAt then
				settleAt = math.huge
				emit(haloFlare, 14)
				emit(haloPetals, 10)
				emit(crownFlare, 5)
				throb = 1.4
				self.lightKick = 2.2
			end
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 26, ROSE, 1, 0)
			K.pulse(feet, 1, 17, GOLD, 0.75, 0.12)
			K.pulse(feet, 1, 9, WHITE, 0.5, 0.25)
			emit(feetFire, 16)
			emit(petals, 20)
			emit(embers, 18)
			emit(rootFire, 8)
			settleAt = os.clock() + 0.85
			self.lightKick = 2.6
		end
		return a
	end
end
