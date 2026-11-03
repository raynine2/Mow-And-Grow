-- LAWN BARON (Rare): the rich lawn owner. Card: a black top hat with a green band and a clover, a white glove tipping
-- it, gold coins and cash spilling out. Gimmick: Courier, every 60 s your bag sells itself wherever you are.
-- The aura (v6, built round ForgeGUI props and VFX Forge layers):
--   ground   the ForgeGUI gold-coin emblem (a clover, a top hat, a rim of coins and banknotes) turning slowly on a warm
--            gold glow, ringed by a gold line
--   hat      the 3D top hat floating over your head, facing where you face, bobbing and cocked to one side; now and
--            then a coin pops out of the top
--   glove    the 3D white glove hovering by your right shoulder; every 6 s it reaches up, takes the brim and tips the
--            hat (it lifts and tilts) and coins tumble out from under it
--   Courier  twelve gold coins standing on the gold line round your feet, dim when empty; one more lights up (it hops,
--            turns bright gold and spins) every 5 s to the next Courier, and a full ring ripples. When the bag sells
--            itself the glove tips the hat and it gushes coins and cash, and the coins go dim to count again
--   body     banknotes fluttering down, gold glints, a soft gold glow; running kicks up coins and leaves a gold trail
return function(H)
	local K, T, rgb, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ease, H.smooth, H.WHITE
	local LOOP = "Loop_LawnBaron" -- (the VFX Forge particle layers)
	local GOLD = rgb(255, 190, 50) -- the coins
	local GOLD_L = rgb(255, 235, 150)
	local GOLD_D = rgb(230, 150, 30) -- a lit coin's face
	local DIM = rgb(105, 80, 35) -- an empty coin
	local DIM_D = rgb(80, 60, 28)
	local COOLDOWN = 60 -- server/ClassPerks COURIER_COOLDOWN
	local PIPS = 12 -- (one coin per 5 s)
	local RC = 4.95 -- the gold line and the Courier coins standing on it
	local TIP_EVERY, TIP_TIME = 6, 1.8 -- the glove tips the hat every 6 s; a tip takes 1.8 s

	-- one CFrame worked out once a frame, however many pieces ride on it
	local function perFrame(fn: (any) -> CFrame): (any) -> CFrame
		local at, cf = -1, CFrame.identity
		return function(f): CFrame
			if f.t ~= at then
				at = f.t
				cf = fn(f)
			end
			return cf
		end
	end
	local function emit(list: { ParticleEmitter }, n: number)
		for _, e in list do
			e:Emit(n)
		end
	end
	-- a copy of a looping layer that only ever bursts (its rate stays off when the aura sets its rates)
	local function burstOnly(a: any, list: { ParticleEmitter })
		for _, e in list do
			e.Rate = 0
			for _, em in a.emitters do
				if em.e == e then
					em.rate = 0
				end
			end
		end
	end
	-- `p` of the way through a tip (0..1): how far the glove has reached up to the brim (0 at rest, 1 holding it) ...
	local function reachOf(p: number): number
		if p <= 0 or p >= 1 then
			return 0
		elseif p < 0.25 then
			return smooth(p / 0.25)
		elseif p < 0.78 then
			return 1
		end
		return smooth((1 - p) / 0.22)
	end
	-- ... and how far the hat is lifted and tilted
	local function liftOf(p: number): number
		if p <= 0.22 or p >= 0.8 then
			return 0
		elseif p < 0.42 then
			return smooth((p - 0.22) / 0.2)
		elseif p < 0.6 then
			return 1
		end
		return smooth((0.8 - p) / 0.2)
	end

	return function()
		local a = H.aura(H.RANK.Rare, GOLD)

		-- THE GROUND: a warm gold glow, the coin emblem (ForgeGUI art in its own colours) turning slowly, a gold line
		-- just outside it
		H.glowDisc(a, 11, H.BFX.glow, GOLD, 0.6, 0, 0.06, 1)
		H.sigil(a, 9.2, T.embLawnBaron, WHITE, 0.2, 0.04, 0.12, 0.7, 1.05)
		H.glowRing(a, RC, GOLD, 0.1, 0, 0.15, 1.3)

		-- the tips: every 6 s (the first as the aura forms); `big` = a Courier's, a gush instead of a trickle
		local tipAt = a.born + 1
		local spilled, big = false, false
		local function tipP(t: number): number
			return (t - tipAt) / TIP_TIME
		end

		-- THE HAT (ForgeGUI, the clover badge on its front): floating over your head facing where you face, bobbing,
		-- swaying and cocked to the right. On a tip it lifts, tilts up on the glove's side and nods forward. It drops
		-- in from above as the aura forms.
		local HS = 2.3
		local hat = H.prop(a.body, "lb_tophat", HS)
		local hs = H.propSize("lb_tophat", HS)
		local hatCF = perFrame(function(f)
			local k = ease((f.t - a.born - 0.15) / 0.7)
			local lift = liftOf(tipP(f.t))
			local y = hs.Y * 0.5 + 0.5 + 0.12 * math.sin(f.t * 1.7) + 3 * (1 - k) + 0.5 * lift
			return CFrame.new(f.head + Vector3.new(0, y, 0)) * f.yaw * CFrame.new(0.15 * lift, 0, -0.1 * lift) * CFrame.Angles(math.rad(4) * math.sin(f.t * 1.1) + 0.3 * lift, math.rad(8) * math.sin(f.t * 0.6), math.rad(-7) + 0.4 * lift)
		end)
		K.move(a, hat, hatCF)
		-- a coin pops out of the top now and then (VFX Forge); on a Courier a fountain of them
		local mouth = K.piece(a.body, Vector3.new(0.8, 0.1, 0.8))
		K.move(a, mouth, function(f)
			return hatCF(f) * CFrame.new(0, hs.Y * 0.5 + 0.05, 0)
		end)
		local pop = H.layer(a, LOOP, "Coins", mouth)
		-- coins tumbling out from under the lifted brim, out and down on the glove's side (bursts only)
		local SPILL = CFrame.new(hs.X * 0.25, -hs.Y * 0.42, -hs.Z * 0.25) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(0, 0, math.rad(-115))
		local under = K.piece(a.body, Vector3.new(0.9, 0.1, 0.9))
		K.move(a, under, function(f)
			return hatCF(f) * SPILL
		end)
		local spill = H.layer(a, LOOP, "Coins", under)
		burstOnly(a, spill)

		-- THE GLOVE (ForgeGUI, fingers up): hovering by your right shoulder, waving a little. On a tip it reaches up to
		-- the brim's front right edge, fingers over it, and rides with the hat as it lifts. It rises in from below as
		-- the aura forms.
		local glove = H.prop(a.body, "lb_glove", 1.5)
		local GRIP = CFrame.new(hs.X * 0.44, -hs.Y * 0.5 - 0.2, -hs.Z * 0.44) * CFrame.Angles(0, math.rad(-45), 0) * CFrame.Angles(math.rad(25), 0, 0)
		local gloveCF = perFrame(function(f)
			local k = ease((f.t - a.born - 0.35) / 0.7)
			local rest = CFrame.new(f.root.Position) * f.yaw * CFrame.new(2.4, 1.05 + 0.14 * math.sin(f.t * 1.8) - 2.5 * (1 - k), -0.55) * CFrame.Angles(0, math.rad(-12), math.rad(8 + 7 * math.sin(f.t * 1.3)))
			local r = reachOf(tipP(f.t))
			if r <= 0 then
				return rest
			end
			return rest:Lerp(hatCF(f) * GRIP, r)
		end)
		K.move(a, glove, gloveCF)
		H.detail(a, H.trailed(glove, K.seq(WHITE, GOLD_L), 0.3, 0.35)) -- (a white swish as it reaches)
		-- the tip: the coins tumble out once the hat is up
		local bills: { ParticleEmitter } = {}
		local glints: { ParticleEmitter } = {}
		H.job(a, function(self, f)
			if f.t - tipAt > TIP_EVERY then
				tipAt = f.t
				spilled = false
			end
			if not spilled and tipP(f.t) >= 0.36 then
				spilled = true
				if big then
					emit(spill, 14)
					emit(pop, 16)
					emit(bills, 6)
					emit(glints, 12)
				else
					emit(spill, 5)
				end
				big = false
			end
		end)

		-- THE COURIER CLOCK: twelve gold coins standing on the gold line, facing out, dim and still when empty. One more
		-- fills every 5 s: it hops, turns bright gold and spins. A full ring ripples (the bag is about to sell itself);
		-- when it does they go dim one after another and count again. They pop up out of the ground as the aura forms.
		local last = os.clock()
		local lit = 0
		local hopAt = table.create(PIPS, -10)
		local coins = {}
		for i = 1, PIPS do
			local th = (i - 1) / PIPS * math.pi * 2
			local rim = H.cyl(a.model, 0.13, 0.9, DIM) -- the edge (glows when lit)
			local face = H.cyl(a.model, 0.18, 0.62, DIM_D) -- the face, standing proud of it
			rim.Transparency = 0.45
			face.Transparency = 0.45
			coins[i] = { rim, face }
			local at = perFrame(function(f)
				local k = ease((f.t - a.born - 0.3 - i * 0.04) / 0.5)
				local hop = math.clamp((f.t - hopAt[i]) / 0.45, 0, 1)
				local y = 0.6 - 0.9 * (1 - k) + 0.75 * math.sin(math.pi * hop) -- (standing on the gold line)
				if lit >= PIPS then
					y += 0.14 * math.max(0, math.sin(f.t * 5 - i * 0.52))
				end
				local turn = -th + (if i <= lit then (f.t - hopAt[i]) * 2.4 else 0)
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * RC, y, math.sin(th) * RC)) * CFrame.Angles(0, turn, 0)
			end)
			K.move(a, rim, at)
			K.move(a, face, at)
		end
		H.job(a, function(self, f)
			local c = math.clamp(math.floor((f.t - last) / COOLDOWN * PIPS), 0, PIPS)
			if c == lit then
				return
			end
			if c > lit then
				for i = lit + 1, c do
					hopAt[i] = f.t
				end
			else -- (the bag sold: they go dim one after another, each with a hop)
				for i = c + 1, lit do
					hopAt[i] = f.t + i * 0.035
				end
			end
			lit = c
			for i, pc in coins do
				local on = i <= c
				pc[1].Color = if on then GOLD else DIM
				pc[1].Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
				pc[1].Transparency = if on then 0 else 0.45
				pc[2].Color = if on then GOLD_D else DIM_D
				pc[2].Material = if on then Enum.Material.Metal else Enum.Material.SmoothPlastic
				pc[2].Transparency = if on then 0 else 0.45
			end
		end)

		-- THE BODY: banknotes fluttering down from over your head (VFX Forge, detail), gold glints round you, a soft
		-- gold glow
		bills = H.layer(a, LOOP, "Bills", K.bodyBox(a, Vector3.new(6, 0.4, 6), 3.8))
		H.detail(a, table.unpack(bills))
		glints = H.layer(a, LOOP, "Glints", K.bodyBox(a, Vector3.new(3, 4.6, 2.2), -0.1))
		H.shell(a, K.seq(GOLD_L, GOLD), 4, 0.9)
		K.light(a, GOLD, 0.9, 10)
		H.lightJob(a, 0)
		-- running: coins kicked up at your feet, a gold trail behind you
		H.layer(a, LOOP, "Kick", H.feetPiece(a, Vector3.new(1.2, 0.2, 1.2), 0.3), true)
		K.feetTrail(a, K.seq(GOLD_L, GOLD))

		-- Courier (the bag sold itself): the glove tips the hat and it gushes coins and cash; the clock starts again
		H.gimmick(a, { courier = true }, 20, function(self, d)
			if d.by and self.owner and d.by ~= self.owner.UserId then
				return
			end
			local now = os.clock()
			last = now
			local p = tipP(now)
			if p < 0 or p >= 1 then
				tipAt = now
			end
			spilled = false -- (mid-tip and already spilled: it spills again now, the big one)
			big = true
			emit(glints, 16)
			self.lightKick = 3
		end)
		-- the entrance: the hat drops in, the glove rises, the coins pop up (their movers), glints burst, then the
		-- glove tips the hat and it gushes coins. The clock counts from here (in game the aura forms as it's built).
		a.onForm = function(self, feet)
			local now = os.clock()
			last = now
			tipAt = now + 0.9
			spilled = false
			big = true
			emit(glints, 10)
		end
		return a
	end
end
