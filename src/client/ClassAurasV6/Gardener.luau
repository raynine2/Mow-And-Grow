-- GARDENER (Uncommon). The card: red pruning shears snipping a stem, leaves flying, a green-gloved hand. Gimmick: Green
-- Thumb, bundles fly to you from much further away. The aura, built round the card: the ForgeGUI vine-wreath emblem
-- under you (pink and yellow flowers, crossed shears) on a soft green glow, a crisp ring round it and a breeze of
-- leaves and petals circling its rim; the ForgeGUI red pruning shears circling you at chest height, turned to the
-- camera, snapping shut on a green sprig every 1.4 s (cut leaves burst off, the blades glint, the light flares, the
-- sprig grows back); leaves riding a breeze round you, knees to head; both hands glowing green and shedding leaves
-- (the green thumb, the card's green glove); a green glow round you; and your Green Thumb reach drawn as a faint ring
-- far out round you with leaves drifting in from it (your own aura only: it's big). Leaves and petals kicked up when
-- you walk. It has more going on than the Weed Puller's: it's the rarer class.
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local BFX = H.BFX
	local LOOP = "Loop_Gardener" -- its VFX Forge particle layers

	-- colours: the leaves, the sprig, the steel blades
	local LEAF = rgb(95, 190, 60)
	local LEAF_L = rgb(175, 240, 110)
	local STEM = rgb(70, 150, 50)
	local STEEL = rgb(235, 245, 255)

	local EMBLEM = 8.2 -- the vine-wreath emblem's width (studs)
	local SHEARS = 3 -- the shears' height (the prop's longest side)
	local ORBIT = 3.3 -- how far out they circle
	local SNIP = 1.4 -- seconds between snips
	local JAW = 0.28 -- where the blades bite: this share of the shears' height above their centre (a guess from the
	-- prop's picture: the gold bolt sits at about 0.13, the blade tips at 0.5)
	local SPRIG = 1.25 -- the length of the sprig held in the jaws
	local REACH = 14 -- server/ClassPerks MAGNET_BONUS (studs further than everyone else)
	local REACH_R = REACH + 4 -- the Green Thumb ring's radius (as the old aura drew it)

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

	return function()
		local a = H.aura(H.RANK.Uncommon, LEAF)

		-- the ground: a soft green glow, the ForgeGUI vine-wreath emblem turning slowly on it, a crisp light-green ring
		-- round its rim
		H.glowDisc(a, EMBLEM + 2.8, BFX.glow, rgb(140, 230, 100), 0.55, 0, 0.06, 1.1)
		local emblem = H.glowDisc(a, EMBLEM, T.embGardener, WHITE, 0.18, 0.06, 0.12, 1.1)
		growIn(a, emblem, EMBLEM, 0.75)
		local rimR = EMBLEM / 2 + 0.25
		local rimRing = H.glowRing(a, rimR, rgb(210, 255, 165), 0.3, 0, 0.14, 1.3)
		growIn(a, rimRing, rimR * 2 / 0.92, 0.9, 0.1)
		-- a breeze of leaves and pink and yellow petals circling the wreath's rim (blowing off it as it turns)
		local rim = K.piece(a.model, Vector3.new(EMBLEM - 0.2, 0.8, EMBLEM - 0.2))
		K.move(a, rim, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, -f.t * 0.7, 0)
		end)
		local rimLeaves = H.layer(a, LOOP, "Swirl", rim)
		local petals = H.layer(a, LOOP, "Petals", rim)
		each(rimLeaves, lock)
		each(petals, lock)
		H.detail(a, table.unpack(petals))

		-- the pruning shears: circling you at chest height, always turned to the camera (blades up, leaning away from
		-- you, with a little sway) so the snip reads from every side. They swoop in from high up, spinning, when the
		-- aura forms.
		local shears = H.prop(a.body, "gd_shears", SHEARS)
		local full = shears.Size
		local at = perFrame(function(f)
			local k = ease((f.t - a.born - 0.15) / 0.9)
			local th = f.t * 0.7
			local rp = f.root.Position
			local r = ORBIT + 5 * (1 - k)
			local pos = rp + Vector3.new(math.cos(th) * r, 0.95 + 0.14 * math.sin(f.t * 1.5) + 4 * (1 - k), math.sin(th) * r)
			local cam = workspace.CurrentCamera
			local camCF = if cam then cam.CFrame else CFrame.new(rp + f.yaw.LookVector * 12)
			local eye = camCF.Position
			if Vector3.new(eye.X - pos.X, 0, eye.Z - pos.Z).Magnitude < 0.3 then
				eye = pos + f.yaw.LookVector * 10
			end
			local side = math.clamp((pos - rp):Dot(camCF.RightVector) / ORBIT, -1, 1)
			local roll = math.rad(30) * side + 0.1 * math.sin(f.t * 1.1) + 6 * (1 - k)
			return CFrame.lookAt(pos, eye) * CFrame.Angles(0, 0.3 * math.sin(f.t * 0.8), roll)
		end)
		K.move(a, shears, at)
		-- a soft steel-to-leaf streak behind the blades as they circle
		local streak = K.trail(shears, Vector3.new(0, 0.12 * SHEARS, 0), Vector3.new(0, 0.46 * SHEARS, 0), K.seq(STEEL, LEAF_L), 0.6, 0.4)
		streak.Transparency = ns(0, 0.45, 1, 1)
		H.detail(a, streak)
		-- the green sprig held across the jaws (a stem with two leaves at its end), cut through on each snip
		local bite = CFrame.new(0, JAW * SHEARS, 0)
		local grow = 1 -- the sprig's length (0 cut .. 1 whole)
		local stem = H.cyl(a.body, SPRIG, 0.11, STEM, Enum.Material.SmoothPlastic)
		local leafA = H.ellipsoid(a.body, Vector3.new(0.5, 0.26, 0.06), LEAF, Enum.Material.SmoothPlastic)
		local leafB = H.ellipsoid(a.body, Vector3.new(0.4, 0.22, 0.06), LEAF_L, Enum.Material.SmoothPlastic)
		local sprigAt = perFrame(function(f)
			return at(f) * bite * CFrame.Angles(0, 0, math.rad(-16))
		end)
		K.move(a, stem, sprigAt)
		K.move(a, leafA, function(f)
			return sprigAt(f) * CFrame.new(SPRIG * 0.5 * grow + 0.12, 0.1, 0) * CFrame.Angles(0, 0, math.rad(35))
		end)
		K.move(a, leafB, function(f)
			return sprigAt(f) * CFrame.new(SPRIG * 0.5 * grow - 0.05, -0.1, 0) * CFrame.Angles(0, 0, math.rad(-40))
		end)
		-- the snip's burst of cut leaves (its Forge layer) and a glint off the blades, both at the jaws
		local jaw = K.piece(a.body, Vector3.new(0.6, 0.6, 0.6))
		K.move(a, jaw, function(f)
			return at(f) * bite
		end)
		local snipFx = H.layer(a, LOOP, "Snip", jaw)
		local glint = H.E(jaw, { tex = T.glint, flip = 4, colors = K.seq(WHITE, LEAF_L), rate = 0, life = { 0.25, 0.35 }, speed = { 0, 0 }, size = 1.5, spread = 0, light = 1, bright = 2.2, sizeSeq = ns(0, 1.5, 1, 1.5) })
		H.detail(a, glint)

		-- leaves riding a breeze round you, knees to head (they ride a turning cylinder, so they swirl round you);
		-- every snip also shakes a puff of cut leaves out of it
		local swirl = K.piece(a.body, Vector3.new(3.4, 4, 3.4))
		K.move(a, swirl, function(f)
			return CFrame.new(f.root.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, f.t * 1.6, 0)
		end)
		local breeze = H.layer(a, LOOP, "Swirl", swirl)
		each(breeze, lock)
		for _ = 1, 2 do
			-- (two more layers: three times as thick, off on phones)
			local more = H.layer(a, LOOP, "Swirl", swirl)
			each(more, lock)
			H.detail(a, table.unpack(more))
		end
		local puff = H.layer(a, LOOP, "Snip", swirl)

		-- snip every 1.4 s (the first one as they arrive): the shears squeeze shut (blades and handles close together,
		-- they're one model so it narrows across), hold, ease open, wait. The sprig is cut on the snap and grows back.
		local shut, cutAt, shown = 0, -99, 0
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
					cutAt = f.t
					each(snipFx, function(e)
						e:Emit(8)
					end)
					each(puff, function(e)
						e:Emit(5)
					end)
					glint:Emit(1)
					self.lightKick = 1.6
				end
				shut = s
				-- (written in tenths: resizing a MeshPart isn't free)
				local q = math.floor(s * 10 + 0.5) / 10
				if q ~= shown then
					shown = q
					shears.Size = Vector3.new(full.X * (1 - 0.48 * q), full.Y, full.Z)
				end
			end
			-- the sprig: gone for a moment once cut, then it grows back out from the jaws
			local g = math.clamp((f.t - cutAt - 0.3) / 0.35, 0, 1)
			if g ~= grow then
				local was = grow
				grow = g
				local hide = if g <= 0 then 1 else 0
				if (was <= 0) ~= (g <= 0) then
					stem.Transparency = hide
					leafA.Transparency = hide
					leafB.Transparency = hide
				end
				stem.Size = Vector3.new(math.max(0.05, SPRIG * g), 0.11, 0.11)
			end
		end)

		-- the green thumb: both hands glow green and shed leaves (the card's green glove)
		for _, hand in { "RightHand", "LeftHand" } do
			local h = K.piece(a.body, Vector3.new(0.45, 0.45, 0.45))
			K.move(a, h, function(f)
				local l = H.limb(f, hand)
				if not l then
					return f.root
				end
				-- (an R6 arm is a long block: its hand is at the bottom)
				return l.CFrame * CFrame.new(0, if l.Size.Y > 1.2 then -0.85 else -0.1, 0)
			end)
			H.layer(a, LOOP, "Thumb", h, false, 1.1)
			H.layer(a, LOOP, "ThumbLeaves", h)
		end
		-- leaves and petals kicked up when you walk
		local kickAt = H.feetPiece(a, Vector3.new(1.4, 0.2, 1.4), 0.1)
		H.layer(a, LOOP, "Kick", kickAt, true)
		H.detail(a, table.unpack(H.layer(a, LOOP, "Petals", kickAt, true)))
		-- a green glow round you, a green light that flares on each snip, a leafy trail when you run
		H.shell(a, K.seq(LEAF_L, LEAF), 6, 1)
		K.light(a, LEAF, 0.9, 11)
		H.lightJob(a, 0.08)
		K.feetTrail(a, K.seq(LEAF_L, LEAF))

		-- Green Thumb: your reach, a faint ring far out round you that grows out to it when the aura forms, and leaves
		-- drifting in from it (your own aura only; off on phones and in Potato Mode)
		local reach, _, reachGuis = H.glowRing(a, REACH_R, LEAF_L, 0.6, 0.02, 0.16, 1.15)
		growIn(a, reach, REACH_R * 2 / 0.92, 1.3, 0.2)
		local inbound = H.feetPiece(a, Vector3.new(REACH_R * 2, 1.2, REACH_R * 2), 0.75)
		local pull = H.E(inbound, { tex = BFX.leaf, colors = K.seq(LEAF_L, LEAF), rate = 4, life = { 1.5, 1.7 }, speed = { 9.5, 11 }, size = 0.55, spin = 220, spread = 0, light = 0, bright = 1.2, shape = Enum.ParticleEmitterShape.Cylinder, inward = true, surface = true, trans = ns(0, 1, 0.12, 0.2, 0.8, 0.3, 1, 1) })
		local ringOn: boolean? = nil
		local pullOn: boolean? = nil
		H.job(a, function(self, f)
			local own = f.player ~= nil and f.player == H.player
			if own ~= ringOn then
				ringOn = own
				for _, g in reachGuis do
					g.Enabled = own
				end
			end
			local leaves = own and not self.lowNow
			if leaves ~= pullOn then
				pullOn = leaves
				pull.Enabled = leaves
			end
		end)

		-- the entrance: the emblem and rings grow in, the reach ring spreads out, the shears swoop in spinning, a burst
		-- of leaves and petals (the core plays the Form_Gardener burst too)
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
		end
		return a
	end
end
