-- GROUNDSKEEPER (Rare): the keeper of a sports pitch. Card: a steel sickle with a wooden handle, a blue cap and a tied
-- bundle of cut grass. Gimmick: Tidy Up, when a clump falls the 2 nearest clumps take a free hit.
-- The aura (v6c, built round ForgeGUI props and VFX Forge layers):
--   ground    the ForgeGUI pitch emblem (mown stripes, a chalk centre circle) turning slowly, dressed in 3D like a
--             real pitch: a chalk halfway line and centre circle, four orange corner flags waving on its rim, a dashed
--             chalk ring turning the other way over it; two crisp chalk-white line rings round it; chalk dust puffs
--             off the rim and (detail) chalk light rises off it
--   carousel  the 3D sickle (1.5x) and the two ForgeGUI grass bundles (the 2 Tidy Up free hits) stand round you: the
--             sickle at your front right, one bundle at your left at shoulder height, one at your back left at hip
--             height. Every 4 s the sickle whips right round you and the bundles ride round with it, so nothing ever
--             cuts through anything; its crisp chalk-white trail sheds chalk dust and flying clippings
--   cap       the card's blue cap worn on your head
--   Tidy Up   white chalk lines zap from the bundles to the two struck clumps, a white flash, a chalk ring and
--             clippings there; the bundles flash, swell, twirl and hop hard at them
--   body      a chalk-dust swirl (two chalk ribbons spiralling round you), grass clippings flicking up round your
--             feet, a fresh breeze of sparkles, a soft grass-and-chalk glow; running kicks up clippings and leaves a
--             mown stripe behind you
-- With your own follow camera behind you, the sickle and the bundles go a little see-through in your back half.
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local E = H.E
	local LOOP = "Loop_Groundskeeper" -- (the VFX Forge particle layers)
	local CHALK = rgb(240, 255, 245) -- chalk white, like a pitch's lines
	local MOWN_L = rgb(150, 225, 100) -- the light and dark mown stripes
	local MOWN_D = rgb(70, 160, 65)
	local SHEAF = rgb(90, 185, 65) -- the grass bundles (the part-built stand-in)
	local SHEAF_L = rgb(165, 235, 110)
	local SHEAF_D = rgb(60, 140, 50)
	local TWINE = rgb(200, 120, 50) -- their orange-brown tie
	local CAP = rgb(40, 120, 235) -- the card's blue cap: the one colour that isn't grass or chalk
	local CAP_L = rgb(140, 195, 255)
	local FLAG = rgb(245, 150, 45) -- the corner flags, in the bundles' orange tie colour
	local UPR = CFrame.Angles(0, 0, math.rad(90)) -- (stands a cylinder up)

	-- the carousel: where each piece rests round you (0 = in front of you, 90 deg = your right), how far out, how high
	-- over your middle. The orbits stay 3 studs or more out, clear of your body.
	local SICKLE_REST, SICKLE_R, SICKLE_Y = math.rad(70), 3.7, 0.25
	local SPOTS = {
		{ rest = math.rad(-60), r = 3, y = 0.95 }, -- your left, shoulder high
		{ rest = math.rad(-160), r = 3, y = -0.45 }, -- your back left, hip high
	}
	local SWEEP, HOLD = 4, 0.5 -- a round every 4 s: resting for half of it, then the whip right round you
	local SZ = 5 -- the sickle's height (1.5x)
	local BSZ = 2.5 -- the bundles' height (1.3x)
	local CAPSZ = 1.45 -- the cap's longest side
	local EMB_SPIN = 0.04 -- how fast the emblem turns (its 3D chalk lines and flags turn with it)
	local FADE = 0.35 -- how see-through the big pieces go for your own camera behind you (mild)
	local FLASH = 0.65 -- a bundle's Tidy Up jump
	local LINE = 0.6 -- a Tidy Up chalk line's life

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
	-- a tied bundle of cut grass made of parts (only if its ForgeGUI prop is missing), standing up: eight long blades
	-- gathered through an orange-brown tie with a knot, crossing there with a twist so the bundle splays out at both
	-- ends (a sheaf's hourglass), round a dark core. Offsets are from the tie (about 1.9 studs tall, 1.2 across).
	local function sheaf(parent: Instance): { { any } }
		local list = {
			{ H.cyl(parent, 1.5, 0.5, SHEAF_D), UPR }, -- the core
			{ H.cyl(parent, 0.26, 0.68, TWINE), UPR }, -- the tie
			{ H.ellipsoid(parent, Vector3.new(0.3, 0.24, 0.2), TWINE), CFrame.new(0, 0.02, -0.35) }, -- its knot
		}
		for j = 0, 7 do -- the blades
			local blade = H.solid(parent, Vector3.new(0.07, 2.1, 0.2), if j % 3 == 0 then MOWN_L elseif j % 3 == 1 then SHEAF else SHEAF_L)
			table.insert(list, { blade, CFrame.Angles(0, j * math.pi / 4, 0) * CFrame.new(0.28, 0, 0) * CFrame.Angles(0.45, 0, 0) })
		end
		return list
	end
	-- the card's blue cap made of parts (only if its ForgeGUI prop is missing): a blue crown, a lighter brim to the
	-- front (-Z), a white button on top
	local function capParts(parent: Instance): { { any } }
		return {
			{ H.ellipsoid(parent, Vector3.new(1.2, 0.75, 1.25), CAP), CFrame.new(0, 0.1, 0.05) },
			{ H.ellipsoid(parent, Vector3.new(1, 0.12, 0.85), CAP_L), CFrame.new(0, -0.18, -0.6) },
			{ H.ellipsoid(parent, Vector3.new(0.18, 0.12, 0.18), WHITE), CFrame.new(0, 0.48, 0.05) },
		}
	end
	-- your own follow camera behind you: these pieces go half see-through while they're in your back half
	local function backFader(a: any, parts: { BasePart })
		local faded = {}
		H.job(a, function(self, f)
			local cam = workspace.CurrentCamera
			local behind = f.player ~= nil and f.player == H.player and cam ~= nil and cam.CFrame.LookVector:Dot(f.root.LookVector) > 0.3
			local look, at = f.root.LookVector, f.root.Position
			for i, p in parts do
				local fade = behind and (p.CFrame.Position - at):Dot(look) < 0.6
				if fade ~= (faded[i] == true) then
					faded[i] = fade
					p.LocalTransparencyModifier = if fade then FADE else 0
				end
			end
		end)
	end

	return function()
		local a = H.aura(H.RANK.Rare, CHALK)

		-- THE GROUND: the pitch emblem (ForgeGUI art in its own colours) turning slowly; two crisp chalk-white line
		-- rings round it (its glowing chalk rim); chalk dust puffing off the line, chalk light rising off it (detail)
		H.sigil(a, 9.6, T.embGroundskeeper, WHITE, 0.2, EMB_SPIN, 0.12, 0.7, 1.05)
		H.glowRing(a, 5.1, CHALK, 0.35, 0.12, 0.16, 1.05)
		H.glowRing(a, 5.65, CHALK, 0.5, -0.09, 0.15, 1)
		-- the pitch's chalk markings in 3D, turning with the emblem: the halfway line across it, the centre circle (thin
		-- chalk lines over the painted one), four corner flags on its rim waving; over it a dashed chalk ring turning the
		-- other way
		local pitchCF = perFrame(function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, f.t * EMB_SPIN, 0)
		end)
		local pitch: { { any } } = { { H.solid(a.model, Vector3.new(8.6, 0.04, 0.14), CHALK), CFrame.identity } }
		for k = 0, 3 do
			local th = (k + 0.5) * math.pi / 2
			table.insert(pitch, { H.cyl(a.model, 1.5, 0.09, CHALK), CFrame.Angles(0, th, 0) * CFrame.new(4.5, 0.75, 0) * UPR })
			local flag = H.solid(a.model, Vector3.new(0.04, 0.42, 0.62), FLAG)
			K.move(a, flag, function(f)
				return pitchCF(f) * CFrame.Angles(0, th, 0) * CFrame.new(4.5, 1.25, 0) * CFrame.Angles(0, 0.35 * math.sin(f.t * 3 + k * 1.7), 0) * CFrame.new(0, 0, 0.33)
			end)
		end
		H.rig(a, pitchCF, pitch)
		local circle = K.piece(a.model, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, circle, function(f)
			return pitchCF(f) * CFrame.new(0, 0.03, 0)
		end)
		local ringAtts = {}
		for k = 1, 16 do
			local th = k / 16 * math.pi * 2
			ringAtts[k] = H.att(circle, Vector3.new(math.cos(th) * 1.42, 0, math.sin(th) * 1.42))
		end
		for k = 1, 16 do
			H.beam(ringAtts[k], ringAtts[k % 16 + 1], { colors = K.seq(CHALK), w0 = 0.13, light = 0.1, bright = 1 })
		end
		local dashCF = perFrame(function(f)
			return CFrame.new(f.feet + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, -f.t * 0.5, 0)
		end)
		local dashes: { { any } } = {}
		for k = 1, 14 do
			table.insert(dashes, { H.solid(a.model, Vector3.new(0.16, 0.06, 1), CHALK), CFrame.Angles(0, k / 14 * math.pi * 2, 0) * CFrame.new(4.15, 0, 0) })
		end
		H.rig(a, dashCF, dashes)
		local line = H.feetPiece(a, Vector3.new(10.2, 0.3, 10.2), 0.25)
		local chalk = H.layer(a, LOOP, "Chalk", line, false, 0.7)
		H.detail(a, H.updraft(a, 5.1, K.seq(CHALK, MOWN_L), 3, T.streak, 0.45))

		-- THE CAROUSEL: how far through this round (0..1), how far round the whip has gone, how fast it's going
		-- (0..1.5), and a gentle sway while everything rests. Worked out once a frame.
		local stateAt, turn, sweepK, sweepFrac, sway = -1, 0, 0, 0, 0
		local function tickState(f)
			if f.t == stateAt then
				return
			end
			stateAt = f.t
			local u = (f.t - a.born) / SWEEP
			sweepFrac = u - math.floor(u)
			local s = math.max(0, (sweepFrac - HOLD) / (1 - HOLD)) -- (0 while resting, then 0..1 through the whip)
			sweepK = 6 * s * (1 - s)
			turn = 2 * math.pi * smooth(s)
			sway = math.rad(6) * math.sin(math.pi * math.min(1, sweepFrac / HOLD)) * math.sin(f.t * 1.3)
		end
		-- a place on the carousel: X points out from you, Y up, -Z along the way the whip goes
		local function orbit(f, rest: number, r: number, y: number): CFrame
			local ang = rest - turn + sway
			return CFrame.new(f.root.Position + Vector3.new(0, y, 0)) * f.yaw * CFrame.Angles(0, math.pi / 2 - ang, 0) * CFrame.new(r, 0, 0)
		end

		-- THE SICKLE (ForgeGUI): standing upright at your front right, its flat face along the way it goes, the
		-- blade's hook pointing away from you, rocking gently; in the whip it leans into the cut. It drops in from above
		-- as the aura forms.
		local sickle = H.prop(a.body, "gk_sickle", SZ)
		local ss = H.propSize("gk_sickle", SZ)
		-- (the blade's hook is taken to curl towards the prop's +X, so it points out; to point it in, CFrame.Angles(0, math.pi, 0))
		local HOOK = CFrame.identity
		local sickleCF = perFrame(function(f)
			tickState(f)
			local k = ease((f.t - a.born - 0.1) / 0.7)
			local y = SICKLE_Y + 0.1 * math.sin(f.t * 2.1) + 3 * (1 - k)
			return orbit(f, SICKLE_REST, SICKLE_R * (0.5 + 0.5 * k), y) * CFrame.Angles(-0.15 * sweepK, 0, -0.1 + 0.04 * math.sin(f.t * 2.6)) * HOOK
		end)
		K.move(a, sickle, sickleCF)
		-- its trail: a crisp chalk-white band (0.8 studs) off the top of the blade, tapering away in 0.4 s; hardly any
		-- light emission, so it stays chalk white over the grass instead of glowing green
		local EDGE_A, EDGE_B = Vector3.new(ss.X * 0.05, ss.Y * 0.3, 0), Vector3.new(ss.X * 0.05, ss.Y * 0.46, 0)
		local trail = K.trail(sickle, EDGE_A, EDGE_B, K.seq(WHITE, CHALK), 0.4, 0.1)
		trail.Transparency = ns(0, 0, 0.5, 0.3, 1, 1)
		trail.WidthScale = ns(0, 1, 1, 0.2)
		K.bright(trail, 1)
		-- chalk dust and clippings shed off the blade through the whip (emitted by hand below)
		local tip = K.piece(a.body, Vector3.new(0.3, 0.3, 0.3))
		local TIP = (EDGE_A + EDGE_B) / 2
		K.move(a, tip, function(f)
			return CFrame.new(sickleCF(f) * TIP)
		end)
		local dust = E(tip, { tex = K.FX.smoke, colors = K.seq(WHITE, CHALK), rate = 0, life = { 0.45, 0.7 }, speed = { 0.2, 0.8 }, size = 0.55, grow = true, accel = Vector3.new(0, -1.5, 0), spread = 180, light = 0.25, bright = 1.1, trans = ns(0, 1, 0.2, 0.45, 1, 1) })
		H.detail(a, dust)
		local chips = E(tip, { tex = K.BFX.strand, colors = K.seq(MOWN_L, MOWN_D), rate = 0, life = { 0.5, 0.8 }, speed = { 2, 4 }, size = 0.4, accel = Vector3.new(0, -22, 0), spin = 400, spread = 70, light = 0, bright = 1 })
		-- clippings flicking up off the blade all the time (VFX Forge), a handful more as it whips past your front
		local BLADE = Vector3.new(0, ss.Y * 0.28, 0)
		local flick = K.piece(a.body, Vector3.new(0.8, 0.3, 0.8))
		K.move(a, flick, function(f)
			return CFrame.new(sickleCF(f) * BLADE)
		end)
		local clippings = H.layer(a, LOOP, "Clippings", flick)
		local FRONT = HOLD + (1 - HOLD) * 0.28 -- (where the whip passes your front)
		local lastFrac, shedAt = 0, 0
		H.job(a, function(self, f)
			tickState(f)
			if lastFrac < FRONT and sweepFrac >= FRONT then
				emit(clippings, 6)
			end
			lastFrac = sweepFrac
			if sweepK > 0.35 and f.t - shedAt > 0.04 then
				shedAt = f.t
				if not self.lowNow then
					dust:Emit(1)
				end
				chips:Emit(2)
			end
		end)
		-- the card's blue cap (ForgeGUI "gk_cap", brim to the front) worn on your head, tipped back a touch (never on
		-- the blade: there it read as a lollipop)
		local cap = H.prop(a.body, "gk_cap", CAPSZ)
		local cs = H.propSize("gk_cap", CAPSZ)
		local CAP_ON = CFrame.new(0, 0.38 + cs.Y * 0.5, 0.04) * CFrame.Angles(0.1, 0, 0)
		local capPieces: { { any } } = { { cap, CFrame.identity } }
		if not cap:IsA("MeshPart") then
			for _, pc in capParts(a.body) do
				table.insert(capPieces, pc)
			end
		end
		H.rig(a, function(f)
			return f.headCF * CAP_ON
		end, capPieces)

		-- THE BUNDLES: the two Tidy Up free hits, the ForgeGUI tied grass bundles riding the carousel at shoulder and
		-- hip height, bobbing and turning on the spot (built from parts only if the prop is missing). When Tidy Up lands
		-- a chalk line snaps from each to its clump, and each flashes, swells to 1.3x, twirls and jumps at it, the
		-- second a beat after the first.
		local bundles = {}
		local faders: { BasePart } = { sickle }
		for i, spot in SPOTS do
			local b = { at = -10, fired = true, dir = Vector3.zero, scale = 1, pulsing = false, parts = {}, glints = {}, halo = (nil :: any), lineAt = -10, lineOn = false, flashed = true, target = Vector3.zero, line = (nil :: any), hit = (nil :: any), chips = (nil :: any), cf = (nil :: any) }
			bundles[i] = b
			b.cf = perFrame(function(f)
				tickState(f)
				local k = ease((f.t - a.born - 0.25 - 0.12 * i) / 0.7)
				local p = (f.t - b.at) / FLASH
				local jump, twirl = Vector3.zero, 0
				b.scale = 1
				if p >= 0 and p < 1 then
					local s = math.sin(math.pi * p)
					jump = b.dir * (2.4 * s) + Vector3.new(0, 1.8 * s, 0)
					twirl = 2 * math.pi * smooth(p)
					b.scale = 1 + 0.3 * math.sin(math.pi * p ^ 0.6)
				end
				local y = spot.y + 0.15 * math.sin(f.t * 2.3 + i * 2) + 3 * (1 - k)
				-- (leaning out a little, turning slowly on the spot)
				return (orbit(f, spot.rest, spot.r * (0.5 + 0.5 * k), y) + jump) * CFrame.Angles(0, 0, -0.1) * CFrame.Angles(0, f.t * 0.8 + twirl, 0)
			end)
			local prop = H.prop(a.body, "gk_bundle", BSZ)
			local real = prop:IsA("MeshPart") -- (missing, H.prop gives an invisible stand-in: build the bundle from parts)
			local list: { { any } } = { { prop, CFrame.identity } }
			if not real then
				for _, pc in sheaf(a.body) do
					table.insert(list, pc)
				end
			end
			table.insert(faders, prop)
			for n, pc in list do
				local part, o = pc[1] :: BasePart, pc[2] :: CFrame
				table.insert(b.parts, { part = part, size = part.Size, color = part.Color, material = part.Material, tint = n > 1 })
				K.move(a, part, function(f)
					local base = b.cf(f)
					local s = b.scale
					if s == 1 then
						return base * o
					end
					return base * CFrame.new(o.Position * s) * o.Rotation
				end)
			end
			-- the flash's glints (VFX Forge) and a soft white glow round the bundle (detail)
			local core = if real then prop else list[2][1] :: BasePart
			b.glints = H.layer(a, LOOP, "Tidy", core)
			b.halo = E(core, { tex = K.FX.glow, colors = K.seq(rgb(235, 255, 220)), rate = 0, life = { 0.35, 0.5 }, speed = { 0, 0 }, size = 3.2, spread = 0, light = 0.9, bright = 1, lock = true, trans = ns(0, 0.15, 1, 1) })
			H.detail(a, b.halo)
			-- Tidy Up's chalk line, from the bundle to its clump: a ground piece parks on that clump while the line shows
			-- (under your feet otherwise), with a white flash and clippings there
			local spotPart = K.piece(a.model, Vector3.new(0.4, 0.4, 0.4))
			K.move(a, spotPart, function(f)
				if f.t - b.lineAt > LINE + 0.5 then
					return CFrame.new(f.feet)
				end
				return CFrame.new(b.target)
			end)
			b.line = H.beam(H.att(core, Vector3.zero), H.att(spotPart, Vector3.zero), { colors = K.seq(WHITE, CHALK), w0 = 0.42, w1 = 0.3, trans = NumberSequence.new(1), light = 0.3, bright = 1.2 })
			b.hit = E(spotPart, { tex = T.glint, flip = 4, colors = K.seq(WHITE, CHALK), rate = 0, life = { 0.3, 0.45 }, speed = { 0, 0.4 }, size = 2.6, spread = 180, light = 0.8, bright = 1.4 })
			b.chips = E(spotPart, { tex = K.BFX.strand, colors = K.seq(MOWN_L, MOWN_D), rate = 0, life = { 0.5, 0.8 }, speed = { 4, 7 }, size = 0.45, accel = Vector3.new(0, -25, 0), spin = 400, spread = 55, light = 0, bright = 1 })
		end
		-- the flash: the stand-in's blades white fading back to grass, every piece swelling 1 -> 1.3 -> 1 (only while
		-- it plays); the chalk line drawn out to the clump in 0.1 s, a flash, a chalk ring and clippings there as it
		-- lands, then fading
		H.job(a, function(self, f)
			for _, b in bundles do
				local p = (f.t - b.at) / FLASH
				if not b.fired and p >= 0 then
					b.fired = true
					emit(b.glints, 8)
					if not self.lowNow then
						b.halo:Emit(2)
					end
				end
				if p >= 0 and p < 1 then
					b.pulsing = true
					local w = 1 - p
					for _, pc in b.parts do
						pc.part.Size = pc.size * b.scale
						if pc.tint then
							pc.part.Color = pc.color:Lerp(WHITE, w)
							pc.part.Material = if w > 0.25 then Enum.Material.Neon else pc.material
						end
					end
				elseif b.pulsing then
					b.pulsing = false
					for _, pc in b.parts do
						pc.part.Size = pc.size
						if pc.tint then
							pc.part.Color = pc.color
							pc.part.Material = pc.material
						end
					end
				end
				local q = f.t - b.lineAt
				if q >= 0 and q < LINE then
					b.lineOn = true
					if q < 0.1 then
						local fr = math.clamp(q / 0.1, 0.02, 0.96)
						b.line.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(fr, 0), NumberSequenceKeypoint.new(fr + 0.03, 1), NumberSequenceKeypoint.new(1, 1) })
					else
						if not b.flashed then
							b.flashed = true
							b.hit:Emit(2)
							b.chips:Emit(8)
							if not self.lowNow then
								K.pulse(b.target, 0.5, 3.4, CHALK, 0.45, 0.15)
							end
						end
						b.line.Transparency = NumberSequence.new(smooth((q - 0.25) / (LINE - 0.25)))
					end
				elseif b.lineOn then
					b.lineOn = false
					b.line.Transparency = NumberSequence.new(1)
				end
			end
		end)
		backFader(a, faders)

		-- THE BODY: a chalk-dust swirl, two thin chalk ribbons spiralling round you (2.5 studs out), rising and falling,
		-- chalk dust puffing off them (detail)
		local swirl = K.piece(a.body, Vector3.new(0.2, 0.2, 0.2))
		K.move(a, swirl, function(f)
			return CFrame.new(f.root.Position + Vector3.new(0, -0.4 + 1.5 * math.sin(f.t * 0.9), 0)) * CFrame.Angles(0, -f.t * 2.4, 0)
		end)
		for _, side in { 1, -1 } do
			local at = Vector3.new(2.5 * side, 0.6 * side, 0)
			local ribbon = K.trail(swirl, at - Vector3.new(0, 0.07, 0), at + Vector3.new(0, 0.07, 0), K.seq(WHITE, CHALK), 0.7, 0.1)
			ribbon.Transparency = ns(0, 0.15, 0.6, 0.6, 1, 1)
			local puff = E(H.att(swirl, at), { tex = K.FX.smoke, colors = K.seq(CHALK), rate = 8, life = { 0.6, 0.9 }, speed = { 0, 0.2 }, size = 0.45, grow = true, spread = 180, light = 0.15, bright = 1, trans = ns(0, 1, 0.25, 0.55, 1, 1) })
			K.addEmitter(a, puff)
			H.detail(a, puff)
		end
		-- grass clippings flicking up round your feet
		K.addEmitter(a, E(H.feetPiece(a, Vector3.new(3.4, 0.2, 3.4), 0.2), { tex = K.BFX.strand, colors = K.seq(MOWN_L, MOWN_D), rate = 4, life = { 0.5, 0.8 }, speed = { 3, 5 }, size = 0.4, accel = Vector3.new(0, -25, 0), spin = 400, spread = 30, light = 0, bright = 1 }))
		-- a fresh breeze of sparkles drifting up round you (VFX Forge, detail), a soft grass-and-chalk glow
		H.layer(a, LOOP, "Fresh", K.bodyBox(a, Vector3.new(4.6, 5, 4.6), 0.3))
		H.shell(a, K.seq(CHALK, MOWN_L, SHEAF), 3.5, 0.75)
		K.light(a, rgb(225, 255, 225), 0.8, 10)
		H.lightJob(a, 0)
		-- running: clippings kicked up at your feet, a fresh mown stripe behind you
		H.layer(a, LOOP, "Kick", H.feetPiece(a, Vector3.new(1.6, 0.2, 1.6), 0.15), true)
		K.feetTrail(a, K.seq(MOWN_L, MOWN_D))

		-- Tidy Up: chalk lines snap from the bundles to the two struck clumps (they aren't sent, so they're taken to sit
		-- either side of the one that fell, a little past it), and the bundles flash, swell and jump at them
		H.gimmick(a, { tidy = true }, 16, function(self, d)
			local to = d.pos - self.rootPos
			to = Vector3.new(to.X, 0, to.Z)
			local dir = if to.Magnitude > 0.1 then to.Unit else Vector3.new(0, 0, -1)
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local now = os.clock()
			for i, b in bundles do
				b.target = d.pos + side * (if i == 1 then 1.8 else -1.8) + dir * 1.2 + Vector3.new(0, 0.4, 0)
				local tb = b.target - self.rootPos
				tb = Vector3.new(tb.X, 0, tb.Z)
				b.dir = if tb.Magnitude > 0.1 then tb.Unit else dir
				b.at = now + (i - 1) * 0.15
				b.fired = false
				b.lineAt = b.at
				b.flashed = false
			end
			self.lightKick = 2
			emit(clippings, 6)
		end)
		-- the entrance: the sickle, its cap and the bundles swoop in (their movers), a chalk ring stamps out, clippings
		-- and chalk dust burst, then the bundles flash one after the other as they arrive
		a.onForm = function(self, feet)
			local now = os.clock()
			for i, b in bundles do
				b.dir = Vector3.zero
				b.at = now + 0.85 + (i - 1) * 0.15
				b.fired = false
			end
			K.pulse(feet, 1, 11, CHALK, 0.55, 0.35)
			emit(clippings, 10)
			emit(chalk, 10)
		end
		return a
	end
end
