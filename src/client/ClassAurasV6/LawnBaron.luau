-- LAWN BARON (Rare): the rich lawn owner. Card: a black top hat with a green band and a clover, a white glove tipping
-- it, gold coins and cash spilling out. Gimmick: Courier, every 60 s your bag sells itself wherever you are.
-- The aura (v6b, built round ForgeGUI props and VFX Forge layers):
--   ground   the ForgeGUI gold-coin emblem (a clover on a gold coin, coins and banknotes round it) turning slowly on a
--            soft gold glow, two thin gold line rings turning opposite ways
--   hat      the 3D top hat floating well over your head, facing where you face, bobbing and cocked to one side
--   glove    the 3D white glove waiting at the hat's brim; every 4.5 s it takes the brim and tips the hat (it lifts
--            and tilts) and coins spray out from under the brim
--   Courier  twelve real coins (flat discs with the coin picture on both faces) standing on the gold line round your
--            feet, turning edge-on. Empty ones are dull bronze and turn slowly; one more turns gold every 5 s (it
--            hops and spins faster, its rim glowing softly) to the next Courier, and a full ring ripples. When the bag
--            sells itself all twelve flip up into a coin fountain, banknotes rain down slowly, the glove tips the hat
--            and it gushes coins, then the coins go back to bronze to count again
--   body     banknotes fluttering down, gold glints, a soft gold glow; running kicks up coins and leaves a gold trail
return function(H)
	local K, T, rgb, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ease, H.smooth, H.WHITE
	local LOOP = "Loop_LawnBaron" -- (the VFX Forge particle layers)
	local GOLD = rgb(255, 190, 50) -- a lit coin's face
	local GOLD_L = rgb(255, 235, 150)
	local GOLD_D = rgb(222, 138, 30) -- a lit coin's rim: a soft half glow, darker than the face so it can't bloom to a blob
	local BRONZE = rgb(122, 86, 46) -- an empty coin: dull bronze
	local BRONZE_D = rgb(84, 58, 32)
	local BRONZE_TINT = rgb(150, 108, 66) -- (multiplies the gold coin picture down to bronze)
	local COOLDOWN = 60 -- server/ClassPerks COURIER_COOLDOWN
	local PIPS = 12 -- (one coin per 5 s)
	local RC = 4.95 -- the gold line and the Courier coins standing on it
	local TIP_EVERY, TIP_TIME = 4.5, 1.6 -- the glove tips the hat every 4.5 s; a tip takes 1.6 s
	local HS = 2.4 -- the hat's size
	local LIFT = 1.05 -- how far the hat floats over your head
	local GS = 1.95 -- the glove's size
	local FLIP = 1.35 -- a Courier coin flip (up, two turns, down)

	-- one value worked out once a frame, however many pieces ride on it
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
	-- `p` of the way through a tip (0..1): how far the glove has reached to the brim (0 waiting, 1 holding it) ...
	local function reachOf(p: number): number
		if p <= 0 or p >= 1 then
			return 0
		elseif p < 0.22 then
			return smooth(p / 0.22)
		elseif p < 0.78 then
			return 1
		end
		return smooth((1 - p) / 0.22)
	end
	-- ... and how far the hat is lifted and tilted
	local function liftOf(p: number): number
		if p <= 0.2 or p >= 0.8 then
			return 0
		elseif p < 0.4 then
			return smooth((p - 0.2) / 0.2)
		elseif p < 0.6 then
			return 1
		end
		return smooth((0.8 - p) / 0.2)
	end

	return function()
		local a = H.aura(H.RANK.Rare, GOLD)

		-- THE GROUND: a soft gold glow, the coin emblem (ForgeGUI art in its own colours) turning slowly, two thin gold
		-- line rings turning opposite ways (the inner one is the line the Courier coins stand on)
		H.glowDisc(a, 11, H.BFX.glow, GOLD, 0.74, 0, 0.06, 1)
		H.sigil(a, 9.2, T.embLawnBaron, WHITE, 0.2, 0.04, 0.12, 0.7, 1.05)
		H.glowRing(a, RC, GOLD, 0.42, 0.12, 0.15, 1)
		H.glowRing(a, 5.6, GOLD_L, 0.5, -0.2, 0.16, 1)

		-- the tips: every 4.5 s (the first as the aura forms); `big` = a Courier's, a gush instead of a spray
		local tipAt = a.born + 1
		local spilled, big = false, false
		local function tipP(t: number): number
			return (t - tipAt) / TIP_TIME
		end
		-- (filled further down: the tip and the Courier burst them)
		local bills: { ParticleEmitter } = {}
		local rain: { ParticleEmitter } = {}
		local glints: { ParticleEmitter } = {}

		-- THE HAT (ForgeGUI, the clover badge on its front): floating well over your head facing where you face,
		-- bobbing, swaying and cocked to the right; it drops in from above as the aura forms. On a tip it lifts,
		-- tilts up on the glove's side and nods forward.
		local hat = H.prop(a.body, "lb_tophat", HS)
		local hs = H.propSize("lb_tophat", HS)
		local hatBase = perFrame(function(f) -- (where it floats between tips)
			local k = ease((f.t - a.born - 0.15) / 0.7)
			local y = hs.Y * 0.5 + LIFT + 0.12 * math.sin(f.t * 1.7) + 3 * (1 - k)
			return CFrame.new(f.head + Vector3.new(0, y, 0)) * f.yaw * CFrame.Angles(math.rad(4) * math.sin(f.t * 1.1), math.rad(8) * math.sin(f.t * 0.6), math.rad(-7))
		end)
		local hatCF = perFrame(function(f)
			local lift = liftOf(tipP(f.t))
			if lift <= 0 then
				return hatBase(f)
			end
			return hatBase(f) * CFrame.new(0.15 * lift, 0.45 * lift, -0.1 * lift) * CFrame.Angles(0.3 * lift, 0, 0.4 * lift)
		end)
		K.move(a, hat, hatCF)
		-- a coin pops out of the top now and then (VFX Forge); on a Courier a fountain of them
		local mouth = K.piece(a.body, Vector3.new(0.8, 0.1, 0.8))
		K.move(a, mouth, function(f)
			return hatCF(f) * CFrame.new(0, hs.Y * 0.5 + 0.05, 0)
		end)
		local pop = H.layer(a, LOOP, "Coins", mouth)
		-- coins spraying out from under the lifted brim, out and down on the glove's side (bursts only)
		local SPILL = CFrame.new(hs.X * 0.25, -hs.Y * 0.42, -hs.Z * 0.25) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(0, 0, math.rad(-115))
		local under = K.piece(a.body, Vector3.new(0.9, 0.1, 0.9))
		K.move(a, under, function(f)
			return hatCF(f) * SPILL
		end)
		local spill = H.layer(a, LOOP, "Coins", under)
		burstOnly(a, spill)

		-- THE GLOVE (ForgeGUI, fingers up): waiting just under the brim's front right edge, riding with the hat. On a
		-- tip it takes the brim (fingers over it) and lifts the hat with it. It rises in from below as the aura forms.
		local glove = H.prop(a.body, "lb_glove", GS)
		local GRIP = CFrame.new(hs.X * 0.44, -hs.Y * 0.5 - 0.2, -hs.Z * 0.44) * CFrame.Angles(0, math.rad(-45), 0) * CFrame.Angles(math.rad(25), 0, 0)
		local REST = GRIP * CFrame.new(0.3, -0.5, 0.1) * CFrame.Angles(0, 0, math.rad(-12))
		local gloveCF = perFrame(function(f)
			local k = ease((f.t - a.born - 0.35) / 0.7)
			local rest = hatBase(f) * REST * CFrame.new(0, 0.07 * math.sin(f.t * 1.8) - 2.2 * (1 - k), 0) * CFrame.Angles(0, 0, 0.06 * math.sin(f.t * 1.3))
			local r = reachOf(tipP(f.t))
			if r <= 0 then
				return rest
			end
			return rest:Lerp(hatCF(f) * GRIP, r)
		end)
		K.move(a, glove, gloveCF)
		H.detail(a, H.trailed(glove, K.seq(WHITE, GOLD_L), 0.3, 0.35)) -- (a white swish as it reaches)
		-- the tip: coins spray from the brim once the hat is up
		H.job(a, function(self, f)
			if f.t - tipAt > TIP_EVERY then
				tipAt = f.t
				spilled = false
			end
			if not spilled and tipP(f.t) >= 0.34 then
				spilled = true
				if big then
					emit(spill, 14)
					emit(pop, 16)
					emit(bills, 5)
					emit(glints, 12)
				else
					emit(spill, 7)
					emit(glints, 3)
				end
				big = false
			end
		end)

		-- THE COURIER CLOCK: twelve coins standing on the gold line, turning edge-on (flat discs with the coin picture
		-- on both faces). Empty ones are dull bronze and turn slowly. One more turns gold every 5 s: it hops, spins
		-- faster and its rim glows softly. A full ring ripples (the bag is about to sell itself). When it sells, all
		-- twelve flip up into a coin fountain, then go back to bronze one after another and count again. They pop up
		-- out of the ground as the aura forms.
		local last = os.clock()
		local lit, shown = 0, 0 -- coins counted / coins painted gold (all twelve through a Courier's flip)
		local hopAt = table.create(PIPS, -10)
		local turnOf = table.create(PIPS, 0)
		local flipAt = -10 -- the last Courier (or the entrance): every coin flips up
		local holdTill = -10 -- (they stay gold through the flip)
		local coins = {}
		local fountain: { ParticleEmitter } = {}
		for i = 1, PIPS do
			local th = (i - 1) / PIPS * math.pi * 2
			turnOf[i] = i * 0.9
			local face = H.cyl(a.model, 0.14, 1.0, BRONZE, Enum.Material.SmoothPlastic) -- the coin (its faces look out sideways)
			local rim = H.cyl(a.model, 0.07, 1.1, BRONZE_D, Enum.Material.SmoothPlastic) -- its edge, standing proud round it
			local pics = {}
			for _, side in { Enum.NormalId.Right, Enum.NormalId.Left } do
				local d = Instance.new("Decal")
				d.Face = side
				d.Texture = T.coin
				d.Color3 = BRONZE_TINT
				d.Parent = face
				table.insert(pics, d)
			end
			coins[i] = { face = face, rim = rim, pics = pics }
			local at = perFrame(function(f)
				local k = ease((f.t - a.born - 0.3 - i * 0.04) / 0.5)
				local hop = math.clamp((f.t - hopAt[i]) / 0.45, 0, 1)
				local y = 0.75 - 1.1 * (1 - k) + 0.6 * math.sin(math.pi * hop)
				if lit >= PIPS and f.t > holdTill then
					y += 0.14 * math.max(0, math.sin(f.t * 5 - i * 0.52))
				end
				local cf = CFrame.new(f.feet + Vector3.new(math.cos(th) * RC, y, math.sin(th) * RC)) * CFrame.Angles(0, turnOf[i], 0)
				local fk = (f.t - flipAt - i * 0.045) / FLIP
				if fk > 0 and fk < 1 then -- (flipped up like a tossed coin: up and over twice, then down)
					cf = cf * CFrame.new(0, 3 * math.sin(math.pi * fk), 0) * CFrame.Angles(0, 0, fk * math.pi * 4)
				end
				return cf
			end)
			K.move(a, face, at)
			K.move(a, rim, at)
			-- the fountain: each coin throws a few more up as it flips (VFX Forge, bursts only, thrown higher)
			local fl = H.layer(a, LOOP, "Coins", face)
			burstOnly(a, fl)
			for _, e in fl do
				e.Speed = NumberRange.new(9, 12)
				e.Acceleration = Vector3.new(0, -24, 0)
				e.SpreadAngle = Vector2.new(15, 15)
				table.insert(fountain, e)
			end
		end
		-- gold (lit) or bronze (empty): only written when the count changes
		local function paint(c: number)
			for i, pc in coins do
				local on = i <= c
				pc.face.Color = if on then GOLD else BRONZE
				pc.face.Material = if on then Enum.Material.Metal else Enum.Material.SmoothPlastic
				pc.face.Reflectance = if on then 0.12 else 0
				pc.rim.Color = if on then GOLD_D else BRONZE_D
				pc.rim.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
				pc.rim.Transparency = if on then 0.45 else 0
				for _, d in pc.pics do
					d.Color3 = if on then WHITE else BRONZE_TINT
				end
			end
		end
		local lastT = os.clock()
		H.job(a, function(self, f)
			-- the turning (empty coins slowly, gold ones faster)
			local dt = math.clamp(f.t - lastT, 0, 0.1)
			lastT = f.t
			for i = 1, PIPS do
				turnOf[i] += dt * (if i <= shown then 2.6 else 0.7)
			end
			if f.t < holdTill then
				return
			end
			local c = math.clamp(math.floor((f.t - last) / COOLDOWN * PIPS), 0, PIPS)
			if c == lit and c == shown then
				return
			end
			local was = math.max(lit, shown)
			if c > was then
				for i = was + 1, c do
					hopAt[i] = f.t
				end
			else -- (the bag sold: they go back to bronze one after another, each with a hop)
				for i = c + 1, was do
					hopAt[i] = f.t + i * 0.035
				end
			end
			lit = c
			shown = c
			paint(c)
		end)

		-- THE BODY: banknotes fluttering down from over your head (VFX Forge, detail), a slow rain of them on a
		-- Courier, gold glints round you, a soft gold glow
		bills = H.layer(a, LOOP, "Bills", K.bodyBox(a, Vector3.new(6, 0.4, 6), 3.8))
		H.detail(a, table.unpack(bills))
		rain = H.layer(a, LOOP, "Bills", K.bodyBox(a, Vector3.new(7.5, 0.4, 7.5), 4.4))
		burstOnly(a, rain)
		glints = H.layer(a, LOOP, "Glints", K.bodyBox(a, Vector3.new(3, 4.6, 2.2), -0.1))
		H.shell(a, K.seq(GOLD_L, GOLD), 4, 0.9)
		K.light(a, GOLD, 0.9, 10)
		H.lightJob(a, 0)
		-- running: coins kicked up at your feet, a gold trail behind you
		H.layer(a, LOOP, "Kick", H.feetPiece(a, Vector3.new(1.2, 0.2, 1.2), 0.3), true)
		K.feetTrail(a, K.seq(GOLD_L, GOLD))

		-- Courier (the bag sold itself): all twelve coins flip up into a coin fountain, banknotes rain down slowly, the
		-- glove tips the hat and it gushes coins and cash; then the clock starts again
		H.gimmick(a, { courier = true }, 20, function(self, d)
			if d.by and self.owner and d.by ~= self.owner.UserId then
				return
			end
			local now = os.clock()
			last = now
			flipAt = now
			holdTill = now + FLIP + 0.7
			shown = PIPS
			paint(PIPS)
			emit(fountain, 4)
			emit(rain, 16)
			local p = tipP(now)
			if p < 0 or p >= 1 then
				tipAt = now
			end
			spilled = false -- (mid-tip and already spilled: it spills again now, the big one)
			big = true
			emit(glints, 16)
			self.lightKick = 2.5
		end)
		-- the entrance: the hat drops in, the glove rises, the coins pop up out of the ground and flip once, glints
		-- burst, then the glove tips the hat and it gushes coins. The clock counts from here (in game the aura forms as
		-- it's built).
		a.onForm = function(self, feet)
			local now = os.clock()
			last = now
			tipAt = now + 0.9
			flipAt = now + 0.45
			spilled = false
			big = true
			emit(glints, 10)
		end
		return a
	end
end
