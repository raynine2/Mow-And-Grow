-- WEED PULLER (Common). The card: a gloved hand yanking a dandelion out by its roots. Gimmick: Root Rip, every 6th
-- swing hits 8x. The aura, built round the card: the ForgeGUI soil emblem under you (cracked earth, sprouts and
-- dandelions round its rim); two ForgeGUI uprooted dandelions (yellow flower, toothed leaves, a clod of soil with its
-- roots) bobbing round your waist, dirt crumbling off their clods and seeds drifting off their flowers; six little
-- weeds (the same dandelion, small) planted round your feet: each swing pulls the next one up out of the soil and
-- lights it green, the sixth glows gold (the next swing is the Root Rip); when the rip lands all six are torn right out
-- of the ground and grow back, the two dandelions jerk up and spin, and dirt and torn leaves burst up round you. A warm
-- earthy glow on the body, golden motes, dirt crumbling off your hands, dirt kicked up when you walk. Small and
-- grounded: it's the Common.
return function(H)
	local K, T, rgb, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ease, H.smooth, H.WHITE
	local BFX = H.BFX
	local LOOP = "Loop_WeedPuller" -- its VFX Forge particle layers

	-- colours: the soil the dandelion was pulled out of, the weeds' glow (the props bring their own colours)
	local SOIL = rgb(112, 74, 42)
	local SOIL_L = rgb(172, 126, 80)
	local SPROUT = rgb(140, 235, 90) -- a weed lit by a swing
	local DIM = rgb(105, 150, 70) -- a weed not counted yet
	local GOLD = rgb(255, 205, 60) -- the Root Rip

	local EMBLEM = 6.6 -- the soil emblem's width (studs)
	local DAND = 2.3 -- an uprooted dandelion's height (the prop's longest side)
	local ORBIT = 3.15 -- how far out the two dandelions circle (their leaves clear your arms)
	local WEED = 1.3 -- a weed round your feet, pulled up (it's the same prop, small)
	local WEED_R = 2.65 -- where the six weeds stand (on the emblem's rim, where its little dandelions are drawn)

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
	-- a quick jerk up that settles back (a tug on each swing, a big yank on the Root Rip): 0 -> 1 -> 0 over k = 0..1
	local function jerk(k: number): number
		if k <= 0 or k >= 1 then
			return 0
		elseif k < 0.15 then
			local u = k / 0.15
			return 1 - (1 - u) * (1 - u)
		end
		return 1 - smooth((k - 0.15) / 0.85)
	end
	-- a flat ground piece that grows in from nothing (overshooting a touch) every time the aura forms
	local function growIn(a: any, p: BasePart, size: number, dur: number)
		local shown = -1
		H.job(a, function(self, f)
			local k = (f.t - self.born) / dur
			local s = if k >= 1 then size else math.max(0.1, size * ease(k))
			if s ~= shown then
				shown = s
				p.Size = Vector3.new(s, 0.05, s)
			end
		end)
	end

	return function()
		local a = H.aura(H.RANK.Common, SOIL)
		a.tugAt, a.tugAmp, a.tugDur = -99, 0, 1 -- the dandelions' current jerk
		a.ripAt = -99 -- when the last Root Rip landed

		-- the ForgeGUI soil emblem under you, turning slowly
		local emblem = H.glowDisc(a, EMBLEM, T.embWeedPuller, WHITE, 0.2, 0.05, 0.12, 1.1)
		growIn(a, emblem, EMBLEM, 0.7)

		-- two uprooted dandelions circling your waist, bobbing, swaying and slowly turning (so their toothed leaves and
		-- roots show from every side). They burst up out of the ground when the aura forms, tug on every swing and
		-- jerk right up, spinning, when the Root Rip lands.
		local crumbs: { ParticleEmitter } = {}
		for i = 1, 2 do
			local off = (i - 1) * math.pi
			local size = DAND * (if i == 1 then 1 else 0.9)
			local d = H.prop(a.body, "wp_dandelion", size)
			local at = perFrame(function(f)
				local k = ease((f.t - a.born - 0.1 * i) / 0.8)
				local th = f.t * 0.75 + off
				local r = 0.5 + (ORBIT - 0.5) * k
				local tk = (f.t - a.tugAt) / a.tugDur
				local whirl = if a.tugAmp > 1 and tk > 0 and tk < 1 then smooth(tk) * math.pi * 2 else 0
				local y = -0.35 + 0.22 * math.sin(f.t * 1.6 + off) + a.tugAmp * jerk(tk) - 3 * (1 - k)
				local pos = f.root.Position + Vector3.new(math.cos(th) * r, y, math.sin(th) * r)
				-- (faces out from you, top leaning out a little, swaying; then turns on its own stalk)
				return CFrame.new(pos)
					* CFrame.Angles(0, -th, 0)
					* CFrame.Angles(0.1 * math.sin(f.t * 1.3 + off), 0, math.rad(-12) + math.rad(6) * math.sin(f.t * 1.7 + off))
					* CFrame.Angles(0, f.t * 0.6 + off + whirl + (1 - k) * 6, 0)
			end)
			K.move(a, d, at)
			-- dirt crumbling off its clod (the bottom quarter of the prop)
			local clod = K.piece(a.body, Vector3.new(0.4, 0.15, 0.4) * size)
			K.move(a, clod, function(f)
				return CFrame.new(at(f) * Vector3.new(0, -0.26 * size, 0))
			end)
			for _, e in H.layer(a, LOOP, "Crumbs", clod) do
				table.insert(crumbs, e)
			end
			-- seeds drifting off its flower (at the top)
			local head = K.piece(a.body, Vector3.new(0.24, 0.1, 0.24) * size)
			K.move(a, head, function(f)
				return CFrame.new(at(f) * Vector3.new(0, 0.44 * size, 0))
			end)
			H.layer(a, LOOP, "Seeds", head)
		end

		-- the Root Rip counter: six little weeds planted round your feet. Each swing pulls the next one up out of the
		-- soil (it pops up, roots showing) and lights a green glow under it; with five up the sixth glows gold and
		-- sparkles (the next swing is the rip). When the rip lands they are all torn right out of the ground and fly
		-- up spinning, then grow back as fresh weeds and the count starts again. (Other players' swings aren't sent to
		-- us, so their weeds just stand planted; their rips still tear them out.)
		local ratio = H.propSize("wp_dandelion", 1) -- the prop's size per stud of height (it's loaded above)
		local weeds, glows = {}, {}
		local lvl, yank, spin, hgt, litAt, gkey, want = {}, {}, {}, {}, {}, {}, {}
		for i = 1, 6 do
			local th = (i - 1) / 6 * math.pi * 2 + 0.35
			local spot = Vector3.new(math.cos(th) * WEED_R, 0, math.sin(th) * WEED_R)
			local turn = th * 2.3 + i -- (each faces its own way)
			lvl[i], yank[i], spin[i], hgt[i], litAt[i], gkey[i], want[i] = 0, 0, 0, 0.1, -99, -9, 0
			local w = H.prop(a.model, "wp_dandelion", 0.1)
			K.move(a, w, function(f)
				-- planted: buried to its leaves; pulled up: standing on the soil with its clod and roots out
				local y = 0.12 + hgt[i] * (0.1 + 0.32 * lvl[i]) + yank[i]
				local sway = 0.09 * math.sin(f.t * 2.1 + i * 1.3)
				return CFrame.new(f.feet + spot + Vector3.new(0, y, 0)) * CFrame.Angles(sway, turn + spin[i], sway * 0.6)
			end)
			-- its glow, flat on the emblem under it
			local g, imgs = H.plate(a.model, 1.7, BFX.glow, DIM, 1, false, 1.2)
			K.move(a, g, function(f)
				return CFrame.new(f.feet + spot + Vector3.new(0, 0.17, 0))
			end)
			weeds[i], glows[i] = w, imgs[1]
		end
		-- gold sparkles off the sixth weed while the rip is ready (its rate is set below; not registered with the core,
		-- so nothing else changes it)
		local ripe = H.E(weeds[6], { tex = T.glint, flip = 4, colors = K.seq(WHITE, GOLD), rate = 0, life = { 0.35, 0.55 }, speed = { 0.5, 1.2 }, size = 0.55, spread = 180, light = 1, bright = 2.2 })
		H.detail(a, ripe)
		local ripeRate = 0
		local lastS: number? = nil
		local lastT = 0
		H.job(a, function(self, f)
			local dt = math.clamp(f.t - lastT, 0, 0.1)
			lastT = f.t
			self.feetPos = f.feet
			local s = H.swings(f)
			if s ~= nil and lastS ~= nil and s > lastS then
				-- a swing: the dandelions tug and shed a little dirt (unless the rip's big yank is playing)
				if not (self.tugAmp > 1 and f.t - self.tugAt < self.tugDur) then
					self.tugAt, self.tugAmp, self.tugDur = f.t, 0.32, 0.4
					for _, e in crumbs do
						e:Emit(3)
					end
				end
			end
			lastS = s
			local c = if s == nil then -1 else (s - (self.ripBase or 0)) % 6
			local rk = f.t - self.ripAt
			local flash = rk >= 0 and rk < 0.7
			for i = 1, 6 do
				local ready = c == 5 and i == 6 and not flash
				local up = flash or ready or (c >= 0 and i <= c)
				local target = if up then 1 else 0
				if target > want[i] then
					litAt[i] = f.t -- (it pops up)
				end
				want[i] = target
				lvl[i] += (target - lvl[i]) * math.min(1, dt * 12)
				-- the rip: torn out and flung up spinning, shrinking away, then grown back from the soil
				local m = 1
				local d = rk - (i - 1) * 0.04
				if d >= 0 and d < 0.7 then
					local u = d / 0.7
					yank[i] = 3.2 * (1 - (1 - u) * (1 - u))
					spin[i] = u * 10
					m = 1 - 0.8 * u * u
				else
					yank[i], spin[i] = 0, 0
					if d >= 0.7 and d < 1.15 then
						m = ease((d - 0.7) / 0.45)
					end
				end
				-- sprouting one after another when the aura forms; a pop when pulled up; the gold one a size bigger
				m *= ease((f.t - self.born - 0.3 - i * 0.08) / 0.45)
				local pop = 1 + 0.3 * jerk((f.t - litAt[i]) / 0.35)
				local h = math.max(0.05, WEED * (0.72 + 0.28 * lvl[i]) * (if ready then 1.15 else 1) * pop * m)
				if math.abs(h - hgt[i]) > 0.02 or (h == 0.05 and hgt[i] ~= h) then -- (resizing a MeshPart isn't free)
					hgt[i] = h
					weeds[i].Size = ratio * h
				end
				-- its glow: none for other players, dim waiting, green when pulled up, gold for the rip
				local key = if flash or ready then 2 elseif up then 1 elseif c < 0 then -1 else 0
				local img = glows[i]
				if key ~= gkey[i] then
					gkey[i] = key
					img.ImageColor3 = if key == 2 then GOLD elseif key == 1 then SPROUT else DIM
					img.ImageTransparency = if key == 2 then 0 elseif key == 1 then 0.15 elseif key == 0 then 0.78 else 1
				end
				if ready then
					img.ImageTransparency = 0.25 * (0.5 + 0.5 * math.sin(f.t * 7))
				end
			end
			local r = if c == 5 and not flash then 7 else 0
			if r ~= ripeRate then
				ripeRate = r
				ripe.Rate = r
			end
		end)

		-- the rip's eruption: torn leaves (its Forge layer) and a geyser of dirt out of the whole emblem
		local ring = H.feetPiece(a, Vector3.new(5.4, 0.3, 5.4), 0.25)
		local ripLeaves = H.layer(a, LOOP, "Rip", ring)
		local geyser = H.E(ring, { tex = BFX.sand, colors = K.seq(SOIL_L, SOIL), rate = 0, life = { 0.6, 1 }, speed = { 9, 15 }, size = 0.42, accel = Vector3.new(0, -40, 0), spread = 18, light = 0, bright = 1 })
		-- dirt kicked up when you walk
		local kickAt = H.feetPiece(a, Vector3.new(1.4, 0.2, 1.4), 0.1)
		H.layer(a, LOOP, "Kick", kickAt, true)
		-- dirt crumbling off both hands (the card's gloved hand that pulled it)
		for _, hand in { "RightHand", "LeftHand" } do
			local h = K.piece(a.body, Vector3.new(0.35, 0.35, 0.35))
			K.move(a, h, function(f)
				local l = H.limb(f, hand)
				if not l then
					return f.root
				end
				-- (an R6 arm is a long block: its hand is at the bottom)
				return l.CFrame * CFrame.new(0, if l.Size.Y > 1.2 then -0.85 else -0.1, 0)
			end)
			H.detail(a, table.unpack(H.layer(a, LOOP, "Crumbs", h, false, 0.75)))
		end
		-- a warm, earthy glow on the body (sunlit dandelion gold fading to soil) and golden motes round you
		H.shell(a, K.seq(rgb(255, 222, 140), rgb(205, 150, 85)), 3.5, 0.85)
		H.layer(a, LOOP, "Motes", K.bodyBox(a, Vector3.new(3.4, 4.4, 3.4), -0.2))
		K.feetTrail(a, K.seq(SOIL_L, SOIL))

		-- the Root Rip lands near you: the count starts again, the weeds are torn out (above), the dandelions yank up,
		-- dirt and leaves erupt, a gold ring flashes out
		H.gimmick(a, { rootRip = true }, 14, function(self, d)
			local s = H.swings({ player = self.owner })
			if s then
				self.ripBase = s
			end
			local now = os.clock()
			self.ripAt = now
			self.tugAt, self.tugAmp, self.tugDur = now, 1.3, 1
			for _, e in ripLeaves do
				e:Emit(16)
			end
			for _, e in crumbs do
				e:Emit(10)
			end
			geyser:Emit(22)
			ripe:Emit(10)
			K.pulse(self.feetPos or (self.rootPos - Vector3.new(0, 2.7, 0)), 1, 7.5, GOLD, 0.5, 0.15)
		end)

		-- the entrance: the emblem grows in, the dandelions burst up out of the ground and fly out to circle you, the
		-- weeds sprout one after another, dirt and leaves burst up (the core plays the Form_WeedPuller burst too)
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 8, SOIL_L, 0.6, 0.12)
			for _, e in ripLeaves do
				e:Emit(12)
			end
			geyser:Emit(16)
		end
		return a
	end
end
