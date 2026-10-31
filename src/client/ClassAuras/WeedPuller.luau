-- WEED PULLER (Common) - the card: a gloved hand yanking a dandelion out by its roots. Gimmick: Root Rip, every 6th
-- swing hits 8x as hard. Aura: a soil ring under you (cracks, sprouts, dandelions); two uprooted dandelions circling
-- you at the waist, each a flat rosette of toothed leaves on a clod of dirt with a tangle of thin dark roots hanging
-- under it (swaying), one in yellow flower, one gone to a white seed puff shedding seeds; crumbs of dirt falling off
-- the roots and your hands; a soft warm glow. The Root Rip: six sprouts round your feet grow up one per swing, the
-- sixth turns gold when the next swing is the rip, and when it lands they all flash gold and dirt erupts round you.
-- Walking kicks up dirt.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local DIRT = rgb(120, 80, 45)
	local SOIL = rgb(107, 68, 35)
	local CLOD = rgb(92, 60, 34)
	local ROOT = rgb(107, 74, 46) -- #6B4A2E
	local LEAF = rgb(95, 185, 60)
	local STEM = rgb(120, 170, 70)
	local DANDY = rgb(255, 218, 50)
	local PETAL = rgb(255, 190, 25)
	local GOLD = rgb(255, 205, 60)
	local SPROUT_OFF = rgb(80, 118, 50)
	local SPROUT_ON = rgb(130, 225, 80)

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

	-- an uprooted dandelion: a clod of dirt, a flat rosette of toothed leaves on it, a stalk with a yellow flower (or a
	-- white seed puff), a taproot and a tangle of thin dark roots hanging below
	local Z = 1.4 -- (their size: big enough to read from across the lawn)
	local function dandelion(a: any, base: (any) -> CFrame, puff: boolean, phase: number)
		local pieces = {}
		-- the clod of dirt it was torn out with
		local clod = H.ellipsoid(a.body, Vector3.new(0.8, 0.5, 0.75) * Z, CLOD, Enum.Material.Slate)
		table.insert(pieces, { clod, CFrame.new(0, -0.12 * Z, 0) })
		-- the rosette: six leaves lying nearly flat, long and short in turn; the long ones carry two pairs of teeth (a
		-- diamond across the leaf pokes out on both sides), the dandelion's "lion's teeth"
		for i = 1, 6 do
			local long = i % 2 == 0
			local len = if long then 0.82 else 0.6
			local th = i / 6 * math.pi * 2 + phase
			local at = CFrame.Angles(0, th, 0) * CFrame.new(0, 0.1 * Z, -len * 0.5 * Z) * CFrame.Angles(math.rad(14), 0, 0)
			local blade = H.ellipsoid(a.body, Vector3.new(0.24, 0.05, len) * Z, LEAF, Enum.Material.SmoothPlastic)
			table.insert(pieces, { blade, at })
			if long then
				for _, d in { 0.12, -0.16 } do
					local tooth = H.solid(a.body, Vector3.new(0.22, 0.045, 0.22) * Z, LEAF, Enum.Material.SmoothPlastic)
					table.insert(pieces, { tooth, at * CFrame.new(0, 0, d * Z) * CFrame.Angles(0, math.rad(45), 0) })
				end
			end
		end
		-- the stalk
		local stem = H.solid(a.body, Vector3.new(0.08, 0.85, 0.08) * Z, STEM)
		table.insert(pieces, { stem, CFrame.new(0, 0.5 * Z, 0) })
		local top = CFrame.new(0, 0.95 * Z, 0)
		local head: BasePart
		if puff then
			-- gone to seed: a white seed puff
			local ball = H.solid(a.body, Vector3.one * 0.5 * Z, WHITE, Enum.Material.SmoothPlastic)
			ball.Shape = Enum.PartType.Ball
			ball.Transparency = 0.12
			head = ball
			table.insert(pieces, { head, top })
		else
			-- in flower: a yellow dome in a ring of petals (plain, not glowing, so it reads as a flower in daylight)
			head = H.ellipsoid(a.body, Vector3.new(0.42, 0.26, 0.42) * Z, DANDY, Enum.Material.SmoothPlastic)
			table.insert(pieces, { head, top * CFrame.new(0, 0.04 * Z, 0) })
			for i = 1, 8 do
				local petal = H.solid(a.body, Vector3.new(0.1, 0.04, 0.3) * Z, PETAL, Enum.Material.SmoothPlastic)
				table.insert(pieces, { petal, top * CFrame.Angles(0, i / 8 * math.pi * 2, 0) * CFrame.new(0, 0, -0.24 * Z) * CFrame.Angles(math.rad(12), 0, 0) })
			end
		end
		-- the taproot
		local tap = H.solid(a.body, Vector3.new(0.11, 0.75, 0.11) * Z, ROOT, Enum.Material.Wood)
		table.insert(pieces, { tap, CFrame.new(0, -0.62 * Z, 0) * CFrame.Angles(math.rad(5), 0, math.rad(-4)) })
		H.rig(a, base, pieces)
		-- ten thin dark roots hanging out of the clod, splayed a little, their tips curling and swaying (curved beams:
		-- each leaves the clod straight down and curls sideways at the tip)
		local roots, bend = {}, {}
		for i = 1, 10 do
			local th = i / 10 * math.pi * 2 + phase * 2
			local r0 = (0.1 + 0.07 * (i % 3)) * Z
			local len = (0.6 + 0.4 * ((i * 7) % 5) / 4) * Z
			local p0 = Vector3.new(math.cos(th) * r0, -0.16 * Z, math.sin(th) * r0)
			local r1 = r0 + 0.28 * Z
			local p1 = Vector3.new(math.cos(th) * r1, -0.16 * Z - len, math.sin(th) * r1)
			local a0 = H.att(clod, p0)
			a0.CFrame = CFrame.new(p0) * CFrame.Angles(0, 0, -math.pi / 2) -- (its axis points down)
			local a1 = H.att(clod, p1)
			a1.CFrame = CFrame.new(p1) * CFrame.Angles(0, th + math.pi / 2, 0) -- (its axis lies sideways)
			bend[i] = (if i % 2 == 0 then 0.22 else -0.22) * Z
			local b = H.beam(a0, a1, { colors = ColorSequence.new(ROOT), w0 = 0.08 * Z, w1 = 0.025, light = 0, bright = 1, segments = 6, curve0 = 0.25 * Z, curve1 = bend[i] })
			roots[i] = b
			if i > 6 then
				H.detail(a, b)
			end
		end
		H.job(a, function(_, f)
			for i, b in roots do
				b.CurveSize1 = bend[i] + 0.1 * Z * math.sin(f.t * 1.8 + i * 0.9 + phase)
			end
		end)
		-- crumbs of dirt falling out of the clod
		local crumbs = E(clod, { tex = BFX.sand, colors = K.seq(rgb(120, 82, 48), rgb(80, 52, 30)), rate = 3, life = { 0.5, 0.8 }, speed = { 0.2, 0.5 }, size = 0.2, accel = Vector3.new(0, -18, 0), spread = 25, light = 0, bright = 1, dir = Enum.NormalId.Bottom })
		K.addEmitter(a, crumbs)
		H.detail(a, crumbs)
		if puff then
			-- seeds drifting off the puff, and a soft fuzz round it
			local seeds = E(head, { tex = BFX.seed, colors = K.seq(WHITE, rgb(255, 245, 200)), rate = 2.2, life = { 1.6, 2.4 }, speed = { 0.4, 0.9 }, size = 0.32, accel = Vector3.new(0.3, 0.5, 0), drag = 0.5, spin = 40, spread = 50, light = 0.3, bright = 1.3 })
			K.addEmitter(a, seeds)
			local fuzz = E(head, { tex = K.FX.glow, colors = K.seq(WHITE), rate = 1.5, life = { 0.8, 1.2 }, speed = { 0, 0 }, size = 1.1 * Z, spread = 0, light = 0.5, bright = 1, lock = true, trans = ns(0, 1, 0.4, 0.65, 1, 1) })
			K.addEmitter(a, fuzz)
			H.detail(a, fuzz)
		end
	end

	return function()
		local a = H.aura(H.RANK.Common, DIRT)
		H.sigil(a, 7.2, T.cSoil, WHITE, 0, 0.1, 0.12, 0.7, 1.1)
		H.glowRing(a, 3.75, rgb(200, 160, 105), 0.35, 0, 0.14, 1.1)
		-- two uprooted dandelions circling at your waist, swaying, leaning out so you see their flowers
		for i = 1, 2 do
			local off = (i - 1) * math.pi
			dandelion(a, perFrame(function(f)
				local k = ease((f.t - a.born - 0.15 * i) / 0.7)
				local th = f.t * 0.85 + off
				local pos = f.root.Position + Vector3.new(math.cos(th) * 3.1, -0.3 + 0.25 * math.sin(f.t * 1.7 + off) - 2.5 * (1 - k), math.sin(th) * 3.1)
				return CFrame.new(pos) * CFrame.Angles(0, -th, 0) * CFrame.Angles(math.rad(10) * math.sin(f.t * 1.3 + off), 0, math.rad(-16) + math.rad(8) * math.sin(f.t * 1.7 + off))
			end), i == 2, off)
		end
		-- the Root Rip: six sprouts round your feet (about 0.8 studs tall grown) grow up one per swing; when five are up
		-- the sixth turns gold (the next swing is the rip); when the rip lands they all flash gold and spring up
		local grow, want, sprout = {}, {}, {}
		for i = 1, 6 do
			grow[i], want[i] = 0.35, 0.35
			local stalk = H.solid(a.model, Vector3.new(0.09, 0.72, 0.09), SPROUT_OFF)
			local pair = H.ellipsoid(a.model, Vector3.new(0.6, 0.08, 0.26), SPROUT_OFF)
			local th = (i - 1) / 6 * math.pi * 2
			local spot = Vector3.new(math.cos(th) * 2.9, 0, math.sin(th) * 2.9)
			-- (a bud sits mostly in the ground; grown it stands full height)
			K.move(a, stalk, function(f)
				return CFrame.new(f.feet + spot + Vector3.new(0, 0.36 - 0.72 * (1 - grow[i]), 0)) * CFrame.Angles(0, -th, 0)
			end)
			K.move(a, pair, function(f)
				local sway = 0.15 * math.sin(f.t * 2.2 + i)
				return CFrame.new(f.feet + spot + Vector3.new(0, 0.74 - 0.72 * (1 - grow[i]), 0)) * CFrame.Angles(0, -th + sway, sway * 0.6)
			end)
			sprout[i] = { stalk, pair }
		end
		-- gold glints off the sixth sprout while the rip is ready (its rate is set below; not registered, so nothing else
		-- changes it)
		local ripe = E(sprout[6][2], { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD), rate = 0, life = { 0.3, 0.5 }, speed = { 0.4, 1 }, size = 0.55, spread = 180, light = 1, bright = 2.2 })
		local shown = -2
		H.job(a, function(self, f)
			local s = H.swings(f)
			local c = if s == nil then -1 else (if self.ripBase then s - self.ripBase else s) % 6
			local flash = self.ripAt ~= nil and f.t - self.ripAt < 0.6
			local key = if flash then 99 else c
			if key ~= shown then
				shown = key
				for i, pr in sprout do
					local ready = not flash and i == 6 and c == 5
					local lit = flash or (c >= 0 and i <= c)
					local gold = flash or ready
					for _, p in pr do
						p.Color = if gold then GOLD elseif lit then SPROUT_ON else SPROUT_OFF
					end
					pr[2].Material = if gold then Enum.Material.Neon else Enum.Material.SmoothPlastic
					want[i] = if flash then 1.3 elseif ready or lit then 1 else 0.35
				end
				ripe.Rate = if c == 5 and not flash then 10 else 0
			end
			for i = 1, 6 do
				grow[i] += (want[i] - grow[i]) * 0.2
			end
		end)
		local base = H.feetPiece(a, Vector3.new(4, 0.2, 4), 0.15)
		local sprouts = E(base, { tex = BFX.strand, colors = K.seq(rgb(150, 230, 90), LEAF), rate = 3, life = { 1.1, 1.6 }, speed = { 0.5, 1 }, size = 0.7, grow = true, spin = 20, spread = 10, light = 0, bright = 1.1, shape = Enum.ParticleEmitterShape.Disc })
		K.addEmitter(a, sprouts)
		-- a little dust rising round your shins
		local dust = E(base, { tex = BFX.sand, colors = K.seq(rgb(200, 160, 110), rgb(150, 110, 70)), rate = 4, life = { 1.2, 1.8 }, speed = { 0.6, 1.2 }, size = 0.35, accel = Vector3.new(0, 0.3, 0), spread = 15, light = 0, bright = 1, shape = Enum.ParticleEmitterShape.Disc, trans = ns(0, 1, 0.25, 0.35, 1, 1) })
		K.addEmitter(a, dust)
		H.detail(a, dust)
		-- dirt crumbling off both hands
		for _, hand in { "RightHand", "LeftHand" } do
			local h = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
			K.move(a, h, function(f)
				local l = H.limb(f, hand)
				return if l then l.CFrame * CFrame.new(0, -0.3, 0) else f.root
			end)
			local crumbs = E(h, { tex = BFX.sand, colors = K.seq(rgb(120, 82, 48), rgb(80, 52, 30)), rate = 2, life = { 0.5, 0.8 }, speed = { 0.2, 0.6 }, size = 0.18, accel = Vector3.new(0, -14, 0), spread = 40, light = 0, bright = 1 })
			K.addEmitter(a, crumbs)
			H.detail(a, crumbs)
		end
		-- walking: dirt, pebbles, torn weeds and a dust cloud kicked up behind you
		local kick = H.feetPiece(a, Vector3.new(1.4, 0.2, 1.4), 0.1)
		K.addEmitter(a, E(kick, { tex = BFX.sand, colors = K.seq(rgb(130, 90, 54), rgb(85, 56, 32)), rate = 26, life = { 0.4, 0.7 }, speed = { 3, 6 }, size = 0.38, accel = Vector3.new(0, -30, 0), spread = 35, light = 0, bright = 1 }), true)
		K.addEmitter(a, E(kick, { tex = BFX.strand, colors = K.seq(LEAF, rgb(70, 120, 40)), rate = 6, life = { 0.5, 0.8 }, speed = { 4, 7 }, size = 0.65, accel = Vector3.new(0, -25, 0), spin = 300, spread = 40, light = 0, bright = 1 }), true)
		K.addEmitter(a, E(kick, { tex = BFX.smoke or BFX.sand, colors = K.seq(rgb(195, 165, 120)), rate = 7, life = { 0.6, 1 }, speed = { 0.5, 1.5 }, size = 1.6, grow = true, spread = 60, light = 0, bright = 0.9, trans = ns(0, 1, 0.2, 0.6, 1, 1) }), true)
		-- a soft warm glow round you (sunlit earth and gold) and a few golden motes
		H.shell(a, K.seq(rgb(255, 214, 130), rgb(200, 140, 75)), 4, 0.9)
		K.feetTrail(a, K.seq(rgb(190, 140, 90), SOIL))
		-- the rip lands: the sprouts flash gold, dirt erupts round you, the count starts again
		local burst = E(base, { tex = BFX.sand, colors = K.seq(rgb(130, 90, 54), rgb(85, 56, 32)), rate = 0, life = { 0.5, 0.9 }, speed = { 8, 14 }, size = 0.36, accel = Vector3.new(0, -40, 0), spread = 40, light = 0, bright = 1 })
		local geyser = E(base, { tex = BFX.sand, colors = K.seq(rgb(140, 98, 60), rgb(90, 60, 34)), rate = 0, life = { 0.7, 1 }, speed = { 12, 18 }, size = 0.5, accel = Vector3.new(0, -38, 0), spread = 12, light = 0, bright = 1, shape = Enum.ParticleEmitterShape.Disc })
		H.gimmick(a, { rootRip = true }, 14, function(self, d)
			local s = H.swings({ player = self.owner })
			if s then
				self.ripBase = s
			end
			self.ripAt = os.clock()
			burst:Emit(14)
			geyser:Emit(18)
			ripe:Emit(8)
			K.pulse(d.pos, 1, 7, rgb(220, 170, 110), 0.45, 0.2)
			K.pulse(self.rootPos - Vector3.new(0, 2.8, 0), 1, 6.5, GOLD, 0.4, 0.3)
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 8, rgb(210, 160, 100), 0.6, 0.15)
			sprouts:Emit(10)
			burst:Emit(16)
			geyser:Emit(10)
		end
		return a
	end
end
