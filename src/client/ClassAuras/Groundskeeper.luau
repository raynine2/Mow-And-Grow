-- GROUNDSKEEPER (Rare) - the card: a steel sickle with a wooden handle, a blue cap and a tied bundle of cut grass; the
-- keeper of a sports pitch. Gimmick: Tidy Up, when a clump falls the 2 nearest clumps take a free hit. Aura: a two-tone
-- mown, striped circle under you in a crisp chalk-white frame (the pitch's lines) with four little blue corner flags on
-- its rim; one big sickle (a pale steel blade with a bright edge on a wooden handle with a blue grip) held upright at
-- hip height, orbiting you with its hooked blade leading, a chalk-white trail off its tip, clippings fountaining up
-- where it cuts and a freshly mown two-tone stripe fading out on the ground behind it; two big tied bundles of cut grass
-- (the 2 Tidy Up free hits) circling you at chest height that flash white, swell to 1.3x and lunge at the clump when
-- Tidy Up lands; a thin chalk ring round your waist; chalk light rising off the rim; twinkles; a faint fresh aura.
-- Walking leaves a two-tone mow stripe.
return function(H)
	local K, T, rgb, ns, ease, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.WHITE
	local BFX = H.BFX
	local E = H.E
	local CHALK = rgb(240, 255, 245) -- chalk white, like the lines on a pitch
	local STRIPE = rgb(60, 175, 80) -- the darker mown stripe
	local HEDGE = rgb(70, 150, 60)
	local WOOD = rgb(150, 100, 55)
	local WOOD_D = rgb(95, 60, 35)
	local STEEL = rgb(200, 208, 222) -- the blade's pale steel
	local STEEL_D = rgb(120, 125, 138) -- the collar
	local CAP = rgb(60, 130, 225) -- the groundskeeper's blue cap (the grip, the corner flags)
	local MOWN_L = rgb(150, 225, 100) -- the fresh-cut stripe: a light pass and a dark pass
	local MOWN_D = rgb(80, 170, 70)
	local SHEAF = rgb(95, 190, 70) -- the grass bundles
	local SHEAF_L = rgb(160, 235, 105)
	local SHEAF_CUT = rgb(205, 220, 125)
	local TAN = rgb(215, 170, 100) -- their ties
	local UPR = CFrame.Angles(0, 0, math.rad(90)) -- (stands a cylinder up)

	return function()
		local a = H.aura(H.RANK.Rare, CHALK)
		H.sigil(a, 9.5, T.cLawn, WHITE, 0, 0.05, 0.12, 0.7, 1.1)
		H.glowRing(a, 5.15, CHALK, 0.15, 0, 0.15, 1.3)
		-- the sickle: held upright (the handle at your hip, the blade at your chest), orbiting you with its hooked blade
		-- leading and turned a little outwards, rocking as it cuts
		local R = 3.3
		local SPIN = 1.1
		local function grow(f): number
			return ease((f.t - a.born) / 0.6)
		end
		local function sickleCF(f): CFrame
			local th = f.t * SPIN
			local bob = 0.12 * math.sin(f.t * 2.2)
			return CFrame.new(f.root.Position + Vector3.new(0, 0.35 + bob, 0)) * CFrame.Angles(0, -th, 0) * CFrame.new(R * grow(f), 0, 0) * CFrame.Angles(0, math.rad(115), 0) * CFrame.Angles(0, 0, math.rad(7) * math.sin(f.t * 2.4))
		end
		-- (one solid tool, every piece overlapping the next: a wooden handle with a blue grip and a dark knob, a steel
		-- collar and tang, then the blade curving up and over from the tang to a point)
		local knob = H.solid(a.body, Vector3.one * 0.38, WOOD_D, Enum.Material.Wood)
		knob.Shape = Enum.PartType.Ball
		local pieces = {
			{ H.cyl(a.body, 2, 0.28, WOOD, Enum.Material.Wood), CFrame.new(0, -1.35, 0) * UPR },
			{ H.cyl(a.body, 0.45, 0.33, CAP), CFrame.new(0, -1.95, 0) * UPR },
			{ knob, CFrame.new(0, -2.38, 0) },
			{ H.cyl(a.body, 0.42, 0.34, STEEL_D, Enum.Material.Metal, 0.2), CFrame.new(0, -0.17, 0) * UPR },
			{ H.solid(a.body, Vector3.new(0.3, 0.5, 0.09), STEEL_D, Enum.Material.Metal, 0.2), CFrame.new(-0.06, 0.08, 0) },
		}
		-- the blade: a crescent in the sickle's plane, wide at the tang, tightening to a point; its bright edge on the
		-- inside of the curve (the plane's normal is -Z so H.blade puts the edge there)
		local pts = {}
		for j = 0, 10 do
			local t = j / 10
			local th = t * 3.6
			table.insert(pts, Vector3.new(-1.15 + 1.15 * (1 - 0.15 * t) * math.cos(th), 0.05 + (1 - 0.1 * t) * math.sin(th), 0))
		end
		for _, pc in H.blade(a.body, pts, 0.5, 0.07, 0.1, STEEL, Enum.Material.Metal, CHALK, -Vector3.zAxis) do
			table.insert(pieces, pc)
		end
		H.rig(a, sickleCF, pieces)
		-- a chalk-white trail off the tip, clippings flicked off it
		local tipPos = pts[#pts]
		local tip = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, tip, function(f)
			return sickleCF(f) * CFrame.new(tipPos)
		end)
		H.trailed(tip, K.seq(WHITE, CHALK, CHALK), 0.6, 0.35)
		local flick = E(tip, { tex = BFX.strand, colors = K.seq(rgb(150, 230, 90), HEDGE), rate = 5, life = { 0.4, 0.7 }, speed = { 2, 4 }, size = 0.38, accel = Vector3.new(0, -16, 0), spin = 260, spread = 60, light = 0, bright = 1 })
		K.addEmitter(a, flick)
		H.detail(a, flick)
		-- clippings fountaining up off the ground where the blade cuts
		local cutter = K.piece(a.body, Vector3.new(1, 0.2, 1))
		K.move(a, cutter, function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, -(f.t * SPIN + 0.25), 0) * CFrame.new((R + 0.4) * grow(f), 0, 0)
		end)
		local fountain = E(cutter, { tex = BFX.strand, colors = K.seq(rgb(170, 240, 110), HEDGE), rate = 10, life = { 0.8, 1.1 }, speed = { 6, 9 }, size = 0.42, accel = Vector3.new(0, -16, 0), spin = 300, spread = 22, light = 0, bright = 1 })
		K.addEmitter(a, fountain)
		-- the freshly mown stripe behind it: a two-tone band of cut grass on the ground (a light and a dark pass, the
		-- way a pitch is mown), fading out the further back it is
		local BANDS, DTH = 7, 0.17
		for k = 1, BANDS do
			local base = 0.1 + 0.8 * (k - 1) / BANDS
			for side = -1, 1, 2 do
				local rad = R + 0.35 + side * 0.32
				local strip = H.solid(a.model, Vector3.new(0.64, 0.04, rad * DTH + 0.04), if side < 0 then MOWN_L else MOWN_D)
				strip.Transparency = base
				table.insert(a.fades, { part = strip, base = base })
				K.move(a, strip, function(f)
					local th = f.t * SPIN - (k - 0.5) * DTH
					return CFrame.new(f.feet + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, -th, 0) * CFrame.new(rad * grow(f), 0, 0)
				end)
			end
		end
		-- the two Tidy Up bundles (the 2 free hits): big tied sheaves of cut grass circling you at chest height. When
		-- Tidy Up lands they flash white, swell to 1.3x and lunge at the clump that fell
		local tidyAt = -10
		local lunge = Vector3.zero
		local lungeDir, lungeDist = Vector3.zero, 0
		local scale = 1
		local sheafParts = {} -- { part, size, color }
		local halos = {}
		for i = 1, 2 do
			local core = H.cyl(a.body, 1.7, 0.74, SHEAF)
			local list = {
				{ core, CFrame.identity },
				{ H.ellipsoid(a.body, Vector3.new(0.8, 1.1, 1.1), SHEAF_L), CFrame.new(0.95, 0.05, 0) }, -- the leafy end, splayed
				{ H.ellipsoid(a.body, Vector3.new(0.42, 0.86, 0.86), SHEAF_CUT), CFrame.new(-0.86, 0, 0) }, -- the cut ends
				{ H.cyl(a.body, 0.26, 0.84, TAN), CFrame.identity }, -- the tie
				{ H.ellipsoid(a.body, Vector3.new(0.3, 0.26, 0.36), TAN), CFrame.new(0, 0.43, 0) }, -- its knot
				{ H.solid(a.body, Vector3.new(0.7, 0.05, 0.16), SHEAF_L), CFrame.new(1.35, 0.32, 0.12) * CFrame.Angles(0.3, 0.25, 0.55) }, -- stray blades
				{ H.solid(a.body, Vector3.new(0.6, 0.05, 0.14), SHEAF), CFrame.new(1.3, -0.25, -0.18) * CFrame.Angles(-0.4, -0.3, -0.45) },
			}
			local tr = H.trailed(core, K.seq(WHITE, CHALK), 0.35, 0.3)
			local halo = E(core, { tex = K.FX.glow, colors = K.seq(rgb(200, 255, 160)), rate = 2, life = { 0.6, 0.9 }, speed = { 0, 0 }, size = 2.8, spread = 0, light = 1, bright = 0.8, lock = true, trans = ns(0, 1, 0.4, 0.75, 1, 1) })
			H.detail(a, tr, halo)
			halos[i] = halo
			local off = (i - 1) * math.pi
			local function sheafCF(f): CFrame
				local k = ease((f.t - a.born - 0.3) / 0.6)
				local th = -f.t * 1.3 + off
				local r = 2.35 * k
				local pos = f.root.Position + lunge + Vector3.new(math.cos(th) * r, 1 + 0.22 * math.sin(f.t * 2.6 + off), math.sin(th) * r)
				return CFrame.new(pos) * CFrame.Angles(0, -th, 0) * CFrame.Angles(math.rad(12) * math.sin(f.t * 2 + off), math.rad(90), 0)
			end
			for _, pc in list do
				local part, o = pc[1] :: BasePart, pc[2] :: CFrame
				table.insert(sheafParts, { part = part, size = part.Size, color = part.Color })
				K.move(a, part, function(f)
					return sheafCF(f) * CFrame.new(o.Position * scale) * o.Rotation
				end)
			end
		end
		-- the Tidy Up pulse: white fading back to grass, size 1 -> 1.3 -> 1, out to the clump and back (0.6 s)
		local pulsing = false
		H.job(a, function(self, f)
			local p = (f.t - tidyAt) / 0.6
			if p >= 0 and p < 1 then
				pulsing = true
				scale = 1 + 0.3 * math.sin(math.pi * p ^ 0.6)
				lunge = lungeDir * (lungeDist * math.sin(math.pi * p))
				local w = 1 - p
				for _, sp in sheafParts do
					sp.part.Size = sp.size * scale
					sp.part.Color = sp.color:Lerp(WHITE, w)
					sp.part.Material = if w > 0.15 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				end
			elseif pulsing then
				pulsing = false
				scale = 1
				lunge = Vector3.zero
				for _, sp in sheafParts do
					sp.part.Size = sp.size
					sp.part.Color = sp.color
					sp.part.Material = Enum.Material.SmoothPlastic
				end
			end
		end)
		-- four corner flags on the rim of the pitch (blue like the cap, on chalk-white posts), turning with the circle;
		-- they rise out of the ground as the aura forms and tuck away while you run (and on phones / Potato Mode)
		local flags = {}
		for i = 1, 4 do
			local phi = (i - 0.5) / 4 * math.pi * 2
			local post = H.cyl(a.model, 1.8, 0.1, CHALK)
			local flag = H.solid(a.model, Vector3.new(0.62, 0.4, 0.04), CAP)
			table.insert(flags, post)
			table.insert(flags, flag)
			local function baseCF(f): CFrame
				local k = ease((f.t - a.born - 0.4) / 0.6)
				return CFrame.new(f.feet) * CFrame.Angles(0, f.t * 0.05, 0) * CFrame.new(math.cos(phi) * 5.15, -1.9 * (1 - k), math.sin(phi) * 5.15) * CFrame.Angles(0, -phi, 0)
			end
			K.move(a, post, function(f)
				return baseCF(f) * CFrame.new(0, 0.9, 0) * UPR
			end)
			K.move(a, flag, function(f)
				return baseCF(f) * CFrame.Angles(0, math.rad(90) + 0.35 * math.sin(f.t * 4 + i * 1.7), 0) * CFrame.new(0.33, 1.58, 0) * CFrame.Angles(0, 0.3 * math.sin(f.t * 6 + i), 0)
			end)
		end
		local flagHide = -1
		H.job(a, function(self, f)
			local hide = if self.lowNow then 1 else math.floor(math.clamp((1 - f.calm) * 1.6, 0, 1) * 10 + 0.5) / 10
			if hide ~= flagHide then
				flagHide = hide
				for _, p in flags do
					p.LocalTransparencyModifier = hide
				end
			end
		end)
		-- a thin chalk-white ring round your waist, chalk light rising off the rim, crisp twinkles, a faint cool aura
		local h = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		local waist = K.beamRing(h, 2.6, 0.09, K.seq(WHITE, CHALK, WHITE), 4, 0.05, 24, false)
		for _, b in waist do
			b.LightEmission = 1
		end
		K.move(a, h, function(f)
			return CFrame.new(f.root.Position + Vector3.new(0, -0.4, 0)) * CFrame.Angles(math.rad(8), 0, math.rad(5)) * CFrame.Angles(0, f.t * 0.6, 0)
		end)
		local rise = H.updraft(a, 4.6, K.seq(WHITE, CHALK, MOWN_L), 5, T.streak, 0.7)
		H.detail(a, rise)
		local body = K.bodyBox(a, Vector3.new(4, 5, 4), 0)
		local shine = E(body, { tex = T.glint, flip = 4, colors = K.seq(WHITE, CHALK), rate = 5, life = { 0.6, 0.9 }, speed = { 0, 0.2 }, size = 0.8, spread = 180, light = 1, bright = 2 })
		K.addEmitter(a, shine)
		H.shell(a, K.seq(WHITE, CHALK, STRIPE), 4, 0.85)
		K.feetTrail(a, K.seq(rgb(170, 240, 110), rgb(70, 150, 55)))
		local kick = H.feetPiece(a, Vector3.new(1.4, 0.2, 1.4), 0.1)
		K.addEmitter(a, E(kick, { tex = BFX.strand, colors = K.seq(rgb(150, 230, 90), HEDGE), rate = 12, life = { 0.4, 0.7 }, speed = { 2.5, 5 }, size = 0.45, accel = Vector3.new(0, -24, 0), spin = 300, spread = 45, light = 0 }), true)
		K.light(a, CHALK, 0.8, 10)
		H.lightJob(a, 0)
		-- Tidy Up: the bundles flash, swell and lunge at the clump that fell; clippings fly
		H.gimmick(a, { tidy = true }, 16, function(self, d)
			local to = d.pos - self.rootPos
			to = Vector3.new(to.X, 0, to.Z)
			lungeDir = if to.Magnitude > 0.1 then to.Unit else Vector3.zero
			lungeDist = math.min(3, to.Magnitude)
			tidyAt = os.clock()
			self.lightKick = 2
			shine:Emit(8)
			fountain:Emit(8)
			for _, hl in halos do
				hl:Emit(3)
			end
		end)
		-- the form: a chalk circle stamps down, clippings fly, the bundles flash
		a.onForm = function(self, feet)
			K.pulse(feet, 1, 12, CHALK, 0.7, 0.05)
			K.pulse(feet, 1, 7, WHITE, 0.5, 0.2)
			shine:Emit(12)
			fountain:Emit(8)
			lungeDist = 0
			tidyAt = os.clock() + 0.5
		end
		return a
	end
end
