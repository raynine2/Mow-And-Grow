-- GROUNDSKEEPER (Rare): the keeper of a sports pitch. Card: a steel sickle with a wooden handle, a blue cap and a tied
-- bundle of cut grass. Gimmick: Tidy Up, when a clump falls the 2 nearest clumps take a free hit.
-- The aura (v6, built round ForgeGUI props and VFX Forge layers):
--   ground   the ForgeGUI pitch emblem (mown stripes in a chalk circle, a sickle and a bundle) turning slowly, framed by
--            a glowing chalk line; chalk dust puffs off the line and (detail) chalk light rises off it
--   sickle   the 3D sickle held upright at hip height by your right side; every few seconds it sweeps right round you,
--            leaning into the cut, with a chalk-white trail; clippings flick off its blade
--   bundles  two tied bundles of cut grass (the 2 Tidy Up free hits) circling you at head height; when Tidy Up lands
--            they flash white, swell and jump out at the clumps one after the other, in a burst of glints
--   body     a soft chalk-and-grass glow and a fresh breeze of sparkles; running kicks up clippings and leaves a mown
--            stripe behind you
return function(H)
	local K, T, rgb, ns, ease, smooth, WHITE = H.K, H.T, H.rgb, H.ns, H.ease, H.smooth, H.WHITE
	local E = H.E
	local LOOP = "Loop_Groundskeeper" -- (the VFX Forge particle layers)
	local CHALK = rgb(240, 255, 245) -- chalk white, like a pitch's lines
	local MOWN_L = rgb(150, 225, 100) -- the light and dark mown stripes
	local MOWN_D = rgb(70, 160, 65)
	local SHEAF = rgb(90, 185, 65) -- the grass bundles
	local SHEAF_L = rgb(165, 235, 110)
	local SHEAF_D = rgb(60, 140, 50)
	local TWINE = rgb(200, 120, 50) -- their orange-brown tie
	local UPR = CFrame.Angles(0, 0, math.rad(90)) -- (stands a cylinder up)

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
	-- a tied bundle of cut grass made of parts (until its ForgeGUI prop exists), standing up: eight long blades
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

	return function()
		local a = H.aura(H.RANK.Rare, CHALK)

		-- THE GROUND: the pitch emblem (ForgeGUI art in its own colours) turning slowly, a glowing chalk line just
		-- outside it, chalk dust puffing off the line, chalk light rising off it (detail)
		H.sigil(a, 9.6, T.embGroundskeeper, WHITE, 0.2, 0.04, 0.12, 0.7, 1.05)
		H.glowRing(a, 5.05, CHALK, 0.1, 0, 0.16, 1.3)
		local line = H.feetPiece(a, Vector3.new(10.1, 0.3, 10.1), 0.25)
		local chalk = H.layer(a, LOOP, "Chalk", line)
		H.detail(a, H.updraft(a, 5.05, K.seq(WHITE, CHALK, MOWN_L), 4, T.streak, 0.6))

		-- THE SICKLE (ForgeGUI): held upright at hip height by your right side, its flat face to your front and back,
		-- the blade's hook pointing away from you, leaning out a little and rocking gently. Every 4 s, after resting
		-- 1.8 s, it whips right round you (past your front, your left, behind you and back), leaning into the cut, and
		-- settles again: its trail draws a long white arc. It drops in from above as the aura forms.
		local SZ = 3.4
		local sickle = H.prop(a.body, "gk_sickle", SZ)
		local ss = H.propSize("gk_sickle", SZ)
		local R, REST, SWEEP, HOLD = 3.4, math.rad(60), 4, 0.45
		-- (the blade's hook is taken to curl towards the prop's +X, so it points out; to point it in, CFrame.Angles(0, math.pi, 0))
		local HOOK = CFrame.identity
		local sweepFrac, sweepK = 0, 0 -- how far through this round (0..1) and how fast the sweep is going (0..1.5)
		local sickleCF = perFrame(function(f)
			local k = ease((f.t - a.born - 0.1) / 0.7)
			local u = (f.t - a.born) / SWEEP
			sweepFrac = u - math.floor(u)
			local s = math.max(0, (sweepFrac - HOLD) / (1 - HOLD)) -- (0 while it rests, then 0..1 through the sweep)
			sweepK = 6 * s * (1 - s)
			local rock = 0.08 * math.sin(math.pi * math.min(1, sweepFrac / HOLD)) * math.sin(f.t * 2.6) -- (side to side, only while resting)
			local ang = REST - 2 * math.pi * smooth(s) -- (0 = in front of you, 90 deg = your right)
			local y = 0.05 + 0.1 * math.sin(f.t * 2.1) + 3 * (1 - k)
			-- (round the orbit: X points out from you, so the flat face looks along the way it moves)
			return CFrame.new(f.root.Position + Vector3.new(0, y, 0)) * f.yaw * CFrame.Angles(0, math.pi / 2 - ang, 0) * CFrame.new(R * k, 0, 0) * CFrame.Angles(-0.15 * sweepK, 0, -0.12 + rock) * HOOK
		end)
		K.move(a, sickle, sickleCF)
		-- its chalk-white trail: a band along the blade, so each sweep leaves a white arc round you
		K.trail(sickle, Vector3.new(0, ss.Y * 0.1, 0), Vector3.new(0, ss.Y * 0.45, 0), K.seq(WHITE, CHALK), 0.45, 1)
		-- clippings flicking up off the blade (VFX Forge), a handful more as it cuts past your front
		local BLADE = Vector3.new(0, ss.Y * 0.28, 0)
		local flick = K.piece(a.body, Vector3.new(0.8, 0.3, 0.8))
		K.move(a, flick, function(f)
			return CFrame.new(sickleCF(f) * BLADE)
		end)
		local clippings = H.layer(a, LOOP, "Clippings", flick)
		local FRONT = HOLD + (1 - HOLD) * 0.26 -- (where the sweep passes your front)
		local lastFrac = 0
		H.job(a, function(self, f)
			if lastFrac < FRONT and sweepFrac >= FRONT then
				emit(clippings, 6)
			end
			lastFrac = sweepFrac
		end)

		-- THE BUNDLES: the two Tidy Up free hits, tied bundles of cut grass circling you at head height (above the
		-- sickle's reach), bobbing and turning. Each is the ForgeGUI prop "gk_bundle" when it exists, else built from
		-- parts. When Tidy Up lands each flashes white, swells to 1.3x, twirls and jumps out at a clump, the second a
		-- beat after the first.
		local FLASH = 0.65
		local bundles = {}
		for i = 1, 2 do
			local b = { at = -10, fired = true, dir = Vector3.zero, scale = 1, pulsing = false, parts = {}, glints = {}, halo = (nil :: any) }
			bundles[i] = b
			local off = (i - 1) * math.pi
			b.cf = perFrame(function(f)
				local k = ease((f.t - a.born - 0.25 - 0.12 * i) / 0.7)
				local th = -f.t * 0.95 + off
				local r = 2.55 * k
				local p = (f.t - b.at) / FLASH
				local jump, twirl = Vector3.zero, 0
				b.scale = 1
				if p >= 0 and p < 1 then
					local s = math.sin(math.pi * p)
					jump = b.dir * (1.8 * s) + Vector3.new(0, 1.1 * s, 0)
					twirl = 2 * math.pi * smooth(p)
					b.scale = 1 + 0.3 * math.sin(math.pi * p ^ 0.6)
				end
				local pos = f.root.Position + jump + Vector3.new(math.cos(th) * r, 2.75 + 0.15 * math.sin(f.t * 2.3 + off) + 3 * (1 - k), math.sin(th) * r)
				-- (leaning out a little, turning slowly on the spot)
				return CFrame.new(pos) * CFrame.Angles(0, -th, 0) * CFrame.Angles(0, 0, -0.2) * CFrame.Angles(0, f.t * 0.8 + twirl, 0)
			end)
			local prop = H.prop(a.body, "gk_bundle", 2)
			local real = prop:IsA("MeshPart") -- (missing, H.prop gives an invisible stand-in: build the bundle from parts)
			local list: { { any } } = { { prop, CFrame.identity } }
			if not real then
				for _, pc in sheaf(a.body) do
					table.insert(list, pc)
				end
			end
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
			b.halo = E(core, { tex = K.FX.glow, colors = K.seq(rgb(235, 255, 220)), rate = 0, life = { 0.35, 0.5 }, speed = { 0, 0 }, size = 2.8, spread = 0, light = 1, bright = 1, lock = true, trans = ns(0, 0.15, 1, 1) })
			H.detail(a, b.halo)
		end
		-- the flash: white fading back to grass, swelling 1 -> 1.3 -> 1 (only while it plays)
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
			end
		end)

		-- THE BODY: a fresh breeze of sparkles drifting up round you (VFX Forge, detail), a soft chalk-and-grass glow
		H.layer(a, LOOP, "Fresh", K.bodyBox(a, Vector3.new(4.6, 5, 4.6), 0.3))
		H.shell(a, K.seq(WHITE, CHALK, MOWN_L), 3.5, 0.85)
		K.light(a, rgb(225, 255, 225), 0.8, 10)
		H.lightJob(a, 0)
		-- running: clippings kicked up at your feet, a fresh mown stripe behind you
		H.layer(a, LOOP, "Kick", H.feetPiece(a, Vector3.new(1.6, 0.2, 1.6), 0.15), true)
		K.feetTrail(a, K.seq(MOWN_L, MOWN_D))

		-- Tidy Up: the bundles flash, swell and jump at two clumps either side of the one that fell; clippings fly
		H.gimmick(a, { tidy = true }, 16, function(self, d)
			local to = d.pos - self.rootPos
			to = Vector3.new(to.X, 0, to.Z)
			local dir = if to.Magnitude > 0.1 then to.Unit else Vector3.zero
			local now = os.clock()
			for i, b in bundles do
				b.dir = CFrame.Angles(0, (i - 1.5) * 0.7, 0) * dir
				b.at = now + (i - 1) * 0.15
				b.fired = false
			end
			self.lightKick = 2
			emit(clippings, 6)
		end)
		-- the entrance: the sickle and the bundles swoop in (their movers), clippings and chalk dust burst, then the
		-- bundles flash one after the other as they arrive
		a.onForm = function(self, feet)
			local now = os.clock()
			for i, b in bundles do
				b.dir = Vector3.zero
				b.at = now + 0.85 + (i - 1) * 0.15
				b.fired = false
			end
			emit(clippings, 10)
			emit(chalk, 10)
		end
		return a
	end
end
