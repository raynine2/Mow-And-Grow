-- LAWN BARON (Rare) - the card: a black top hat with a green band and a clover, a white glove tipping it, gold coins
-- and cash spilling out. Gimmick: Courier, a full bag sells itself (60%) wherever you are, every 60 s. Aura: a gold coin
-- sigil under you; a big true-black top hat (green band, a four-leaf clover with a gold heart) floating over your head,
-- bobbing and tilting, facing where you face; a white glove hovering by your shoulder that every few seconds reaches up,
-- takes the brim and tips the hat (coins spill out from under it, now and then one pops out of the top); six gold coins
-- spinning round you; green banknotes fluttering down; a gold shimmer; and the Courier clock: twelve gold coins standing
-- round your feet, dim when empty, filling up bright and spinning one by one over the 60 s. When the bag sells itself
-- the glove tips the hat and it gushes a fountain of coins and cash.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local E = H.E
	local smooth = H.smooth
	local GOLD = rgb(255, 190, 50)
	local GOLD_L = rgb(255, 235, 150)
	local GOLD_D = rgb(230, 150, 30) -- a full coin's face
	local DIM = rgb(105, 80, 35) -- an empty coin
	local DIM_D = rgb(80, 60, 28)
	local GREEN = rgb(40, 150, 70) -- the hat's band
	local CLOVER = rgb(80, 220, 90)
	local BLACK = rgb(12, 12, 15) -- the hat: true black, no shine (shine picked up the sky and turned it grey-blue)
	local GLOVE = rgb(250, 250, 250)
	local COOLDOWN = 60 -- server/ClassPerks COURIER_COOLDOWN
	local PIPS = 12
	local TIP_EVERY, TIP_TIME = 6, 1.7 -- the glove tips the hat every 6 s; a tip takes 1.7 s
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- (stands a cylinder up)

	-- `p` of the way through a tip (0..1): how far the glove has reached up (0 at rest, 1 on the brim), and how far the
	-- hat is lifted
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
		H.glowDisc(a, 8, H.BFX.glow, GOLD, 0.6, 0, 0.06, 1)
		H.sigil(a, 9.2, T.sigCoin, rgb(255, 196, 70), 0, 0.14, 0.12, 0.7, 1.15)
		H.glowRing(a, 5.0, GOLD, 0.1, 0, 0.15, 1.3)
		local tipAt = a.born + 0.9 -- (the first tip comes as the aura forms)
		local function tipP(f): number
			return (f.t - tipAt) / TIP_TIME
		end
		-- the top hat (1.3x): a true black crown and brim, a green band, a four-leaf clover with a gold heart on the
		-- front. It bobs and sways over your head facing where you face, cocked a little to the right; when the glove
		-- tips it, it lifts and tilts up on the glove's side
		local S = 1.3
		local function hatCF(f): CFrame
			local k = ease((f.t - a.born - 0.2) / 0.7)
			local lift = liftOf(tipP(f))
			local y = 1.1 + 0.15 * math.sin(f.t * 1.6) + 2 * (1 - k) + 0.45 * lift
			return CFrame.new(f.head + Vector3.new(0, y, 0)) * f.yaw * CFrame.Angles(math.rad(5) * math.sin(f.t * 0.9) + math.rad(10) * lift, math.rad(8) * math.sin(f.t * 0.6), math.rad(-7) + math.rad(22) * lift)
		end
		local hat = {
			{ H.cyl(a.body, 1.05 * S, 1.0 * S, BLACK, Enum.Material.SmoothPlastic, 0), CFrame.new(0, 0.55 * S, 0) * UP }, -- the crown
			{ H.cyl(a.body, 0.09 * S, 1.75 * S, BLACK, Enum.Material.SmoothPlastic, 0), CFrame.new(0, 0.04 * S, 0) * UP }, -- the brim
			{ H.cyl(a.body, 0.24 * S, 1.0 * S + 0.05, GREEN), CFrame.new(0, 0.22 * S, 0) * UP }, -- the band
		}
		-- the clover: four round leaves round a gold heart, on the crown's front just above the band
		local cy, cz = 0.62 * S, -0.5 * S - 0.03
		for i = 0, 3 do
			local ang = math.rad(45 + i * 90)
			local leaf = H.ellipsoid(a.body, Vector3.new(0.28, 0.28, 0.06), CLOVER, Enum.Material.Neon)
			table.insert(hat, { leaf, CFrame.new(math.cos(ang) * 0.14, cy + math.sin(ang) * 0.14, cz) })
		end
		table.insert(hat, { H.ellipsoid(a.body, Vector3.new(0.14, 0.14, 0.08), GOLD, Enum.Material.Neon), CFrame.new(0, cy, cz - 0.02) })
		H.rig(a, hatCF, hat)
		-- a coin pops out of the top now and then; coins spill out from under the brim when it's tipped
		local mouth = K.piece(a.body, Vector3.new(0.7, 0.1, 0.7))
		K.move(a, mouth, function(f)
			return hatCF(f) * CFrame.new(0, 1.15 * S, 0)
		end)
		local pop = E(mouth, { tex = T.coin, colors = K.seq(WHITE), rate = 0.8, life = { 0.8, 1.1 }, speed = { 4, 6 }, size = 0.42, accel = Vector3.new(0, -22, 0), spin = 360, spread = 25, light = 0, bright = 1.1 })
		K.addEmitter(a, pop)
		local under = K.piece(a.body, Vector3.new(1.4, 0.1, 1.4))
		K.move(a, under, function(f)
			return hatCF(f) * CFrame.new(0, -0.1, 0)
		end)
		local spill = E(under, { tex = T.coin, colors = K.seq(WHITE), rate = 0, life = { 0.7, 1 }, speed = { 2, 4 }, size = 0.4, accel = Vector3.new(0, -26, 0), spin = 360, spread = 70, light = 0, bright = 1.1, dir = Enum.NormalId.Bottom })
		K.addEmitter(a, spill)
		-- the white glove (palm, cuff, thumb, four fingers): it hovers by your right shoulder, waving a little, and on a
		-- tip reaches up to the brim's right edge and rides with the hat as it lifts
		local function restCF(f): CFrame
			return CFrame.new(f.root.Position) * f.yaw * CFrame.new(2.1, 1.3 + 0.15 * math.sin(f.t * 1.8), -0.4) * CFrame.Angles(0, 0, math.rad(-12 + 8 * math.sin(f.t * 1.3))) * CFrame.Angles(0, math.rad(-25), 0)
		end
		-- (on the brim's front right: palm towards the hat so you see the back of the glove from the front, fingers
		-- leaning back over the brim)
		local GRIP = CFrame.new(0.75, -0.3, -0.95) * CFrame.Angles(0, math.rad(-35), 0) * CFrame.Angles(math.rad(20), 0, math.rad(10))
		local function gloveCF(f): CFrame
			local k = ease((f.t - a.born - 0.35) / 0.7)
			local rest = restCF(f) * CFrame.new(0, -2 * (1 - k), 0)
			local r = reachOf(tipP(f))
			if r <= 0 then
				return rest
			end
			return rest:Lerp(hatCF(f) * GRIP, r)
		end
		local glove = {
			{ H.solid(a.body, Vector3.new(0.6, 0.62, 0.26), GLOVE), CFrame.identity }, -- the palm
			{ H.cyl(a.body, 0.2, 0.64, GLOVE), CFrame.new(0, -0.4, 0) * UP }, -- the cuff
			{ H.cyl(a.body, 0.38, 0.17, GLOVE), CFrame.new(0.36, 0.02, 0) * CFrame.Angles(0, 0, math.rad(40)) }, -- the thumb
		}
		for j, len in { 0.32, 0.42, 0.46, 0.4 } do -- (little finger to index)
			table.insert(glove, { H.cyl(a.body, len, 0.16, GLOVE), CFrame.new(-0.225 + (j - 1) * 0.15, 0.28 + len / 2, 0) * UP })
		end
		H.rig(a, gloveCF, glove)
		-- six gold coins spinning round you (wide, clear of your arms)
		for i = 1, 6 do
			local coin = H.plate(a.body, 1.2, T.coin, WHITE, 0, true, 1.15)
			local tr = H.trailed(coin, K.seq(GOLD_L, GOLD), 0.35, 0.2)
			if i % 2 == 0 then
				H.detail(a, tr)
			end
			local off = (i - 1) / 6 * math.pi * 2
			K.move(a, coin, function(f)
				local k = ease((f.t - a.born - i * 0.05) / 0.7)
				local th = f.t * 1.05 + off
				local r = 3.25 * k
				local pos = f.root.Position + Vector3.new(math.cos(th) * r, 0.1 + 0.35 * math.sin(f.t * 2 + off), math.sin(th) * r)
				return CFrame.new(pos) * CFrame.Angles(0, f.t * 3 + off, 0) * H.UPRIGHT
			end)
		end
		-- green banknotes fluttering down (small, turning over as they fall), a gold shimmer hugging you
		local rainBox = K.bodyBox(a, Vector3.new(6, 0.5, 6), 4.2)
		local bills = E(rainBox, { tex = T.bill, colors = K.seq(WHITE), rate = 1.4, life = { 2.4, 3 }, speed = { 0.2, 0.5 }, size = 0.55, accel = Vector3.new(0, -1.2, 0), drag = 0.6, spin = 120, spread = 30, light = 0, bright = 1, dir = Enum.NormalId.Bottom, sizeSeq = ns(0, 0.55, 1, 0.45), squash = ns(0, -0.5, 0.25, -0.1, 0.5, -0.5, 0.75, -0.1, 1, -0.5), trans = ns(0, 1, 0.1, 0, 0.8, 0, 1, 1) })
		K.addEmitter(a, bills)
		H.detail(a, bills)
		local body = K.bodyBox(a, Vector3.new(2.6, 4.6, 1.6), -0.2)
		local glints = E(body, { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD_L), rate = 7, life = { 0.5, 0.8 }, speed = { 0, 0.3 }, size = 0.75, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, glints)
		-- the tips: every few seconds, and at once on a Courier (a fountain of coins and cash instead of a trickle)
		local spilled = false
		local big = false
		H.job(a, function(self, f)
			if f.t - tipAt > TIP_EVERY then
				tipAt = f.t
				spilled = false
			end
			if not spilled and tipP(f) >= 0.35 then
				spilled = true
				spill:Emit(if big then 18 else 4)
				if big then
					pop:Emit(24)
					bills:Emit(6)
					glints:Emit(10)
				end
				big = false
			end
		end)
		local function courierTip()
			local p = (os.clock() - tipAt) / TIP_TIME
			big = true
			if p < 0 or p >= 1 then
				tipAt = os.clock()
			end
			spilled = false -- (mid-tip and already spilled: it spills again now, the big one)
		end
		-- the Courier clock: 12 gold coins standing round your feet, dim and still when empty; one more fills every 5 s
		-- (it hops, turns bright gold and spins) until the bag sells itself
		local last = os.clock()
		local lit = 0
		local hopAt = table.create(PIPS, -10)
		local coins = {}
		for i = 1, PIPS do
			local th = (i - 1) / PIPS * math.pi * 2
			local rim = H.cyl(a.model, 0.1, 0.66, DIM)
			local face = H.cyl(a.model, 0.14, 0.46, DIM_D)
			rim.Transparency = 0.45
			face.Transparency = 0.45
			coins[i] = { rim, face }
			local function at(f): CFrame
				local on = i <= lit
				local hop = math.clamp((f.t - hopAt[i]) / 0.4, 0, 1)
				local y = 0.55 + 0.7 * math.sin(math.pi * hop) + (if on then 0.08 * math.sin(f.t * 2.5 + th) else 0)
				local turn = if on then f.t * 2.4 + th else 0
				return CFrame.new(f.feet + Vector3.new(math.cos(th) * 4.15, y, math.sin(th) * 4.15)) * CFrame.Angles(0, -th + turn, 0)
			end
			K.move(a, rim, at)
			K.move(a, face, at)
		end
		H.job(a, function(self, f)
			local c = math.min(PIPS, math.floor((os.clock() - last) / COOLDOWN * PIPS))
			if c == lit then
				return
			end
			for i = lit + 1, c do
				hopAt[i] = f.t
			end
			lit = c
			for i, pc in coins do
				local on = i <= c
				pc[1].Color = if on then GOLD else DIM
				pc[1].Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
				pc[1].Transparency = if on then 0 else 0.45
				pc[2].Color = if on then GOLD_D else DIM_D
				pc[2].Transparency = if on then 0 else 0.45
			end
		end)
		H.shell(a, K.seq(GOLD_L, GOLD), 5, 0.9)
		local kick = H.feetPiece(a, Vector3.new(1, 0.2, 1), 0.4)
		K.addEmitter(a, E(kick, { tex = T.coin, colors = K.seq(WHITE), rate = 7, life = { 0.6, 0.9 }, speed = { 3, 5 }, size = 0.4, accel = Vector3.new(0, -30, 0), spin = 360, spread = 30, light = 0, bright = 1.1 }), true)
		K.feetTrail(a, K.seq(GOLD_L, GOLD))
		K.light(a, GOLD, 0.9, 10)
		H.lightJob(a, 0)
		-- the bag sold itself: the glove tips the hat and it gushes coins and cash; the clock starts again
		H.gimmick(a, { courier = true }, 20, function(self, d)
			if d.by and self.owner and d.by ~= self.owner.UserId then
				return
			end
			last = os.clock()
			courierTip()
			glints:Emit(16)
			self.lightKick = 3
		end)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 12, GOLD, 0.7, 0.05)
			K.pulse(feet, 1, 7, GOLD_L, 0.5, 0.2)
			pop:Emit(14)
			glints:Emit(12)
			bills:Emit(5)
		end
		return a
	end
end
