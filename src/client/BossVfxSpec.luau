-- The boss effects from the owner's VFX_Spec.md (26 Oct), as data for client/BossVfx. Sizes, speeds, boxes and
-- gravity are "kit studs" (the design kit's boss was about 1/2.2 of ours): BossVfx multiplies them by the boss's
-- scale / 2.2. Rates are per second (VFXLib's Budget scales them down on phones).
-- Emitter fields:
--   at      an att_* point (all numbered copies too: att_eye -> att_eye, att_eye_2 ...), or "base" (the feet),
--           "sky" (a box above the boss), "arena" (the arena floor) or "orbit" (points circling the boss)
--   box     the spawn box (x, y, z kit studs; y0..y1 for "sky"), else a point
--   tex     a sprite (shared/BossFxIds), add = additive glow (LightEmission 1) else lit
--   rate, rage (rate x this in the rage form; "only" = rage form only), life {a, b}, size {a, b[, end x]},
--   grow {from x, to x} (size over life instead of shrinking), colors / rageColors (hex), speed {a, b},
--   dir "up" | "down" | "side", spread (degrees), accel (Vector3), drag, spin (rad/s), alpha (peak opacity)
-- Glows (billboard halos): at, size, color, rageColor, alpha, pulse (fraction), rate (rad/s), rageSize (x),
-- rageOnly. Lights: at, color, rageColor, brightness, rageBrightness, flicker, rageOnly (at most 3 are used).
local V3 = Vector3.new

local Spec = {}

Spec.shared = {
	moteRate = 16,
	moteRage = 2.5,
	moteLife = { 2, 3.6 },
	rageMote = "FF5A3A",
}

Spec.bosses = {
	dandelion = {
		accent = "FFE46A",
		emitters = {
			{ at = "att_head_center", box = V3(14.8, 12.6, 10), tex = "dot", add = true, rate = 10, rage = 2, life = { 2.5, 4.5 }, size = { 0.29, 0.51, 0.2 },
				colors = { "FFE46A", "FFF3B0" }, rageColors = { "FF9A3A", "FFCF6A" }, speed = { 0.14, 0.7 }, dir = "up", spread = 40, drag = 0.3 },
			{ at = "att_crown_tip", tex = "seed", rate = 1.4, rage = 3, life = { 4, 6.5 }, size = { 1, 1.4, 1 }, colors = { "FFFFFF" },
				speed = { 0.6, 1.4 }, dir = "up", spread = 50, accel = V3(0.34, 0.06, 0.14), drag = 0.4, spin = 0.4 },
			-- (30 Oct) seed puffs swirling slowly up round him, and golden pollen glinting
			{ at = "orbit", radius = { 7, 9 }, high = { 1.5, 8 }, orbitSpeed = 4, tex = "seed", rate = 10, rage = 2, life = { 2.5, 3.5 }, size = { 0.9, 1.3, 1 },
				colors = { "FFFFFF" }, speed = { 0.4, 1 }, dir = "up", spread = 40, accel = V3(0, 0.4, 0), drag = 0.5, spin = 0.6 },
			{ at = "att_head_center", box = V3(16, 14, 12), tex = "Star4", add = true, twinkle = true, rate = 8, rage = 2, life = { 0.6, 1.2 }, size = { 0.9, 1.5 },
				colors = { "FFF3B0", "FFE46A" }, rageColors = { "FFB040", "FF8A30" }, speed = { 0, 0.3 }, dir = "up", spread = 180, spin = 1.5 },
		},
		glows = {
			{ at = "att_scepter_core", size = 6.3, color = "FFE14D", rageColor = "FFB020", alpha = 0.9, pulse = 0.12, rate = 3, rageSize = 1.4 },
			{ at = "att_eye", size = 1.9, color = "7CFF4D", rageColor = "FF3020", alpha = 0.55, pulse = 0.1, rate = 2 },
		},
		lights = {
			{ at = "att_scepter_core", color = "FFE39A", rageColor = "FF8A30", brightness = 1.5, rageBrightness = 2.2, flicker = 0.05 },
			{ at = "att_head_center", color = "FFF1B0", rageColor = "FF5020", brightness = 0.8, rageBrightness = 1.2 },
		},
	},
	bramble = {
		accent = "FF4D6D",
		emitters = {
			{ at = "att_hive_mouth", tex = "bee", rate = 6, rage = 2.5, life = { 2.5, 4 }, size = { 0.8, 1, 1 }, colors = { "FFFFFF" },
				speed = { 1.5, 4.5 }, dir = "side", spread = 70, drag = 0.6, wobble = true },
			{ at = "sky", box = V3(34, 19, 30), y1 = 28, tex = "petal", rate = 7, rage = 1.8, life = { 4, 7 }, size = { 0.6, 0.9, 1 },
				colors = { "FF9CC4", "FFFFFF", "FFC3DA", "E8302A" }, rageColors = { "FF2040", "D0203A", "FF9CC4" },
				speed = { 0.75, 1.9 }, dir = "down", spread = 20, accel = V3(0, -0.56, 0), spin = 2 },
			{ at = "att_hive_center", box = V3(4, 4, 4), tex = "dot", add = true, rate = 3, life = { 2, 3 }, size = { 0.3, 0.5, 0.2 },
				colors = { "FFE070" }, speed = { 0.2, 0.6 }, dir = "up", spread = 60 },
			-- (30 Oct) pollen puffs off its shoulders and honey glinting round the hive
			{ at = "att_head_center", box = V3(14, 8, 12), tex = "smoke", add = true, rate = 3, rage = 2, life = { 1.5, 2.5 }, size = { 1, 1.6 }, grow = { 0.5, 1.4 },
				alpha = 0.5, colors = { "FFE070", "FFF0A0" }, speed = { 0.2, 0.6 }, dir = "up", spread = 90, drag = 1 },
			{ at = "att_hive_center", box = V3(6, 6, 6), tex = "Star4", add = true, twinkle = true, rate = 6, rage = 2, life = { 0.5, 1 }, size = { 0.7, 1.1 },
				colors = { "FFC43A", "FFF0A0" }, speed = { 0.2, 0.8 }, dir = "up", spread = 180, spin = 1.5 },
		},
		glows = {
			{ at = "att_eye", size = 3, color = "FF4D6D", alpha = 0.6, pulse = 0.1, rate = 2, rageSize = 1.15 },
			{ at = "att_throat", size = 3.4, color = "FF3040", alpha = 0.22, pulse = 0.15, rate = 2.5 },
		},
		lights = {
			{ at = "att_eye", color = "FF4D6D", brightness = 1, rageBrightness = 1.6 },
			{ at = "att_throat", color = "FF3040", brightness = 0.8, flicker = 0.15 },
		},
	},
	bunker = {
		accent = "FFE14D",
		emitters = {
			{ at = "att_flag_wound", tex = "dot", add = true, rate = 6, rage = 2, life = { 1.2, 2.2 }, size = { 0.4, 0.67, 0.3 },
				colors = { "FFE14D", "FFF0A0" }, speed = { 2, 4.7 }, dir = "up", spread = 35, accel = V3(0, 1.3, 0) },
			{ at = "base", box = V3(16, 3, 16), y0 = 2, tex = "sand", rate = 22, life = { 0.8, 1.4 }, size = { 0.2, 0.33, 1 },
				colors = { "EBD796", "D8C27C", "F4E4B0" }, speed = { 0, 0.5 }, dir = "down", spread = 20, accel = V3(0, -20, 0) },
			{ at = "att_spine_tip", tex = "spark", add = true, rate = 2.4, rage = "only", life = { 0.6, 1 }, size = { 0.5, 0.84, 0.2 },
				colors = { "FF8A20", "FFB040" }, speed = { 0.5, 1.5 }, dir = "up", spread = 30, accel = V3(0, 5, 0) },
		},
		glows = {
			{ at = "att_eye", size = 3, color = "FFE14D", rageColor = "FF3020", alpha = 0.7, pulse = 0.08, rate = 2, rageSize = 1.3 },
			{ at = "att_flag_wound", size = 5.3, color = "FFE14D", alpha = 0.75, pulse = 0.15, rate = 3 },
			{ at = "att_spine_tip", size = 2.7, color = "FF8A20", alpha = 0.8, pulse = 0.2, rate = 4, rageOnly = true },
		},
		lights = {
			{ at = "att_flag_wound", color = "FFE14D", brightness = 1.4, flicker = 0.08 },
			{ at = "att_eye", color = "FFE14D", rageColor = "FF3020", brightness = 0.9, rageBrightness = 1.4 },
		},
	},
	-- (29 Oct) the Frost Thornback (the golf shell, frozen for Frost Peaks): snow sifting off it, an icy glow
	frost = {
		accent = "9FE8FF",
		emitters = {
			{ at = "att_flag_wound", tex = "dot", add = true, rate = 6, rage = 2, life = { 1.2, 2.2 }, size = { 0.4, 0.67, 0.3 },
				colors = { "9FE8FF", "E8FBFF" }, speed = { 2, 4.7 }, dir = "up", spread = 35, accel = V3(0, 1.3, 0) },
			{ at = "base", box = V3(16, 3, 16), y0 = 2, tex = "sand", rate = 22, life = { 0.8, 1.4 }, size = { 0.2, 0.33, 1 },
				colors = { "FFFFFF", "DDF2FF", "BFE4FF" }, speed = { 0, 0.5 }, dir = "down", spread = 20, accel = V3(0, -20, 0) },
			{ at = "att_spine_tip", tex = "spark", add = true, rate = 2.4, rage = "only", life = { 0.6, 1 }, size = { 0.5, 0.84, 0.2 },
				colors = { "7FE0FF", "FFFFFF" }, speed = { 0.5, 1.5 }, dir = "up", spread = 30, accel = V3(0, 5, 0) },
			-- (30 Oct) snowflakes swirling round it, an icy mist on the floor, frost glinting
			{ at = "orbit", radius = { 8, 11 }, high = { 1, 9 }, orbitSpeed = 6, tex = "Star4", add = true, rate = 16, rage = 2, life = { 1.6, 2.6 }, size = { 0.4, 0.7, 0.6 },
				colors = { "FFFFFF", "DDF6FF" }, speed = { 0, 0.5 }, dir = "down", spread = 180, spin = 2 },
			{ at = "base", box = V3(30, 1, 30), y0 = 1.2, tex = "smoke", rate = 2.5, rage = 2, life = { 5, 7 }, size = { 6, 9, 1 }, alpha = 0.3,
				colors = { "BFE8FF", "E8FBFF" }, speed = { 0.2, 0.4 }, dir = "side", spread = 180 },
			{ at = "att_head_center", box = V3(16, 10, 16), tex = "Star4", add = true, twinkle = true, rate = 8, rage = 2, life = { 0.5, 1 }, size = { 0.7, 1.2 },
				colors = { "E8FBFF", "7FE0FF" }, speed = { 0, 0.2 }, dir = "up", spread = 180, spin = 1.5 },
		},
		glows = {
			{ at = "att_eye", size = 3, color = "7FF0FF", rageColor = "FFFFFF", alpha = 0.7, pulse = 0.08, rate = 2, rageSize = 1.3 },
			{ at = "att_flag_wound", size = 5.3, color = "9FE8FF", alpha = 0.75, pulse = 0.15, rate = 3 },
			{ at = "att_spine_tip", size = 2.7, color = "7FE0FF", alpha = 0.8, pulse = 0.2, rate = 4, rageOnly = true },
		},
		lights = {
			{ at = "att_flag_wound", color = "9FE8FF", brightness = 1.4, flicker = 0.08 },
			{ at = "att_eye", color = "7FF0FF", rageColor = "FFFFFF", brightness = 0.9, rageBrightness = 1.4 },
		},
	},
	harvest = {
		accent = "F0C850",
		emitters = {
			{ at = "att_coat_hem", tex = "strand", rate = 4, rage = 1.6, life = { 3, 5 }, size = { 0.55, 0.9, 1 },
				colors = { "F0C850", "E0B040", "FFE08A" }, speed = { 0.3, 1 }, dir = "side", spread = 80, accel = V3(0.14, -0.83, 0), drag = 0.6, spin = 2 },
			{ at = "att_cuff", tex = "strand", rate = 1, rage = 1.6, life = { 3, 5 }, size = { 0.55, 0.9, 1 },
				colors = { "F0C850", "E0B040", "FFE08A" }, speed = { 0.3, 1 }, dir = "side", spread = 80, accel = V3(0.14, -0.83, 0), drag = 0.6, spin = 2 },
			{ at = "base", box = V3(22, 8.3, 22), y0 = 5.5, tex = "dot", add = true, rate = 8, life = { 2.5, 4 }, size = { 0.22, 0.39, 0.2 },
				colors = { "F7D672", "FFF0B0" }, speed = { 0.1, 0.4 }, dir = "up", spread = 90 },
			{ at = "att_nectar", tex = "dot", rate = 1.6, life = { 0.9, 1.3 }, size = { 0.44, 0.55, 1 }, colors = { "FFD06A" },
				speed = { 0, 0.3 }, dir = "down", spread = 10, accel = V3(0, -25, 0) },
			{ at = "att_coat_hem", tex = "flame", add = true, rate = 40, rage = "only", life = { 0.6, 1.1 }, size = { 0.7, 1.25, 0.1 },
				colors = { "FF8A20", "FFB040", "FF5A10" }, speed = { 1.7, 3.9 }, dir = "up", spread = 25, accel = V3(0, 6.9, 0), box = V3(5, 0.5, 5) },
			-- (30 Oct) straw whirling round him and warm glints in the dust
			{ at = "orbit", radius = { 8, 10 }, high = { 1, 6 }, orbitSpeed = 6, tex = "strand", rate = 8, rage = 2, life = { 1.5, 2.5 }, size = { 0.6, 0.9, 1 },
				colors = { "F0C850", "E0B040", "FFE08A" }, speed = { 0, 0.4 }, dir = "side", spread = 180, spin = 3 },
			{ at = "base", box = V3(22, 10, 22), y0 = 6, tex = "Star4", add = true, twinkle = true, rate = 6, rage = 2, life = { 0.7, 1.3 }, size = { 0.7, 1.2 },
				colors = { "FFE08A", "FFF6D0" }, speed = { 0, 0.2 }, dir = "up", spread = 180, spin = 1.5 },
		},
		glows = {
			{ at = "att_eye", size = 2.1, color = "FFE14D", rageColor = "FF3020", alpha = 0.6, pulse = 0.1, rate = 2 },
			{ at = "att_trigger_tip", size = 1.1, color = "FFE14D", rageColor = "FF8A20", alpha = 0.8, pulse = 0.3, rate = 4 },
		},
		lights = {
			{ at = "att_eye", color = "FFE14D", brightness = 0.9 },
			{ at = "att_nectar", color = "FF6A7A", rageColor = "FF4A20", brightness = 0.8 },
			{ at = "att_coat_hem", color = "FF7A20", brightness = 1.8, flicker = 0.25, rageOnly = true },
		},
	},
	sakura = {
		accent = "FF9FCD",
		emitters = {
			{ at = "sky", box = V3(29, 17, 29), y1 = 26, tex = "petal", rate = 18, rage = 1.5, life = { 6, 9 }, size = { 0.52, 0.75, 1 },
				colors = { "FFB6D8", "FFC0DD", "FFFFFF", "FF9FCD" }, rageColors = { "D0204A", "E83060", "A01840" },
				speed = { 0.9, 1.7 }, dir = "down", spread = 25, accel = V3(0.6, -0.35, 0), spin = 2.5 },
			{ at = "att_lantern_core", tex = "dot", add = true, rate = 6, rage = 5, life = { 1.2, 1.8 }, size = { 0.23, 0.38, 0.2 },
				colors = { "FFB070", "FF8A40" }, rageColors = { "DDF0FF", "B8E0FF" }, speed = { 0.3, 1 }, dir = "up", spread = 30, accel = V3(0, 1.7, 0) },
			{ at = "orbit", radius = { 9.3, 11.3 }, high = { 1.2, 7 }, orbitSpeed = 9.3, tex = "petal", rate = 60, rage = "only", life = { 1.6, 2.4 },
				size = { 0.58, 0.87, 1 }, colors = { "D0204A", "FF4070", "FFB6D8" }, speed = { 0, 0.5 }, dir = "side", spread = 180, spin = 4 },
			-- (30 Oct) petals swirling round it and soft pink glints
			{ at = "orbit", radius = { 8, 10 }, high = { 1, 8 }, orbitSpeed = 5, tex = "petal", rate = 14, rage = 1.5, life = { 1.6, 2.6 }, size = { 0.5, 0.75, 1 },
				colors = { "FFB6D8", "FFFFFF", "FF9FCD" }, rageColors = { "D0204A", "FF4070" }, speed = { 0, 0.4 }, dir = "side", spread = 180, spin = 3 },
			{ at = "att_head_center", box = V3(18, 16, 14), tex = "Star4", add = true, twinkle = true, rate = 8, rage = 2, life = { 0.6, 1.1 }, size = { 0.8, 1.3 },
				colors = { "FFD0E8", "FFFFFF" }, rageColors = { "FF4070", "FFB6D8" }, speed = { 0, 0.3 }, dir = "up", spread = 180, spin = 1.5 },
		},
		glows = {
			{ at = "att_lantern_core", size = 7.5, color = "FF8A4A", rageColor = "B8E0FF", alpha = 0.85, pulse = 0.1, rate = 2.5, rageSize = 1.3 },
			{ at = "att_toro_light", size = 2.9, color = "FFC870", alpha = 0.6, pulse = 0.05, rate = 1.5 },
			{ at = "att_eye", size = 2, color = "FFD0E8", rageColor = "FF3040", alpha = 0.55, pulse = 0.1, rate = 2 },
		},
		lights = {
			{ at = "att_lantern_core", color = "FF8A4A", rageColor = "B8E0FF", brightness = 1.6, rageBrightness = 2.4, flicker = 0.12 },
		},
	},
	bog = {
		accent = "9DFF5A",
		emitters = {
			{ at = "att_catkin", tex = "smoke", add = true, rate = 0.5, rage = 2, life = { 4, 6 }, size = { 0.66, 1.06, 1 },
				colors = { "E8F8D0", "C8E8A0" }, speed = { 0.5, 1.3 }, dir = "up", spread = 30, drag = 1.5, spin = 0.5 },
			{ at = "att_slime_tip", tex = "dot", rate = 1, rage = 2, life = { 0.7, 0.9 }, size = { 0.42, 0.53, 1 }, colors = { "7CD45A", "9DFF5A" },
				speed = { 0, 0.3 }, dir = "down", spread = 10, accel = V3(0, -24, 0) },
			{ at = "ring", radius = { 5.5, 10 }, tex = "bubble", add = true, rate = 8, rage = 5, life = { 1, 1.6 }, size = { 0.4, 0.92 }, grow = { 0.4, 1.2 },
				colors = { "9DFF5A", "C8FFA0" }, speed = { 0.3, 0.8 }, dir = "up", spread = 10 },
			{ at = "base", box = V3(30, 1, 30), y0 = 1.5, tex = "smoke", rate = 2.5, rage = 2, life = { 5, 7 }, size = { 6.9, 9.5, 1 }, alpha = 0.35,
				colors = { "5A8A78", "6A9A88" }, rageColors = { "5AAA50", "7ACA60" }, speed = { 0.2, 0.4 }, dir = "side", spread = 180 },
			{ at = "arena", box = V3(50, 13, 50), y0 = 7, tex = "dot", add = true, rate = 5, life = { 3, 5 }, size = { 0.37, 0.53, 0.3 },
				colors = { "E8FF70", "B8FF5A" }, speed = { 0.3, 1 }, dir = "side", spread = 180, wobble = true },
			-- (30 Oct) toxic glints popping off the pool
			{ at = "ring", radius = { 5, 9 }, tex = "Star4", add = true, twinkle = true, rate = 6, rage = 3, life = { 0.4, 0.8 }, size = { 0.6, 1 },
				colors = { "C8FF70", "9DFF5A" }, speed = { 0.5, 1.5 }, dir = "up", spread = 20 },
		},
		glows = {
			{ at = "att_eye", size = 3.3, color = "9DFF5A", alpha = 0.75, pulse = 0.12, rate = 2.5, rageSize = 1.35 },
		},
		lights = {
			{ at = "att_eye", color = "9DFF5A", brightness = 1.2, rageBrightness = 2 },
		},
	},
	hollow = {
		accent = "FFB060",
		emitters = {
			{ at = "att_head_top", tex = "spark", add = true, rate = 14, rage = 4, life = { 1.6, 2.4 }, size = { 0.36, 0.6, 0 },
				colors = { "FFB040", "FF8A1A", "FFE08A" }, speed = { 4.5, 9 }, dir = "up", spread = 30, accel = V3(0, 3.6, 0), drag = 1.5, spin = 2 },
			{ at = "att_eye", tex = "smoke", rate = 2, life = { 2, 2.8 }, size = { 1.2, 1.8 }, grow = { 0.6, 2.2 }, alpha = 0.45,
				colors = { "8A8078", "A49A90" }, speed = { 1, 2 }, dir = "up", spread = 20 },
			{ at = "att_eye", tex = "flame", add = true, rate = 6, life = { 0.3, 0.45 }, size = { 1.2, 1.8, 0.3 },
				colors = { "FFD23A", "FF9A3A", "FFF0A0" }, speed = { 1.5, 3 }, dir = "up", spread = 15 },
			{ at = "att_mouth", tex = "flame", add = true, rate = 6, life = { 0.3, 0.45 }, size = { 1.2, 1.8, 0.3 },
				colors = { "FFD23A", "FF9A3A", "FFF0A0" }, speed = { 1.5, 3 }, dir = "up", spread = 25 },
			{ at = "sky", box = V3(20, 6, 20), y1 = 22, tex = "maple", rate = 3.5, life = { 4.5, 6.5 }, size = { 0.9, 1.35, 1 },
				colors = { "D8401A", "F08A2A", "F0C040" }, speed = { 0.5, 1.2 }, dir = "down", spread = 30, spin = 1.6, wobble = true },
			{ at = "att_head_top", tex = "flame", add = true, rate = 70, rage = "only", life = { 0.6, 1 }, size = { 2.1, 3.6, 0.15 },
				colors = { "FF8A20", "FFB040", "FF5A10", "FFD23A" }, speed = { 4.5, 9 }, dir = "up", spread = 25, accel = V3(0, 9, 0), box = V3(4, 0.5, 4) },
			-- (30 Oct) embers whirling up round it and smoke curling off the scorched ground
			{ at = "orbit", radius = { 7, 9 }, high = { 0.5, 7 }, orbitSpeed = 5, tex = "spark", add = true, rate = 14, rage = 2.5, life = { 1.2, 2 }, size = { 0.35, 0.6, 0 },
				colors = { "FFB040", "FF6A1A", "FFE08A" }, speed = { 0.5, 1.5 }, dir = "up", spread = 40, accel = V3(0, 2, 0) },
			{ at = "base", box = V3(20, 2, 20), y0 = 1, tex = "smoke", rate = 2, life = { 3, 4.5 }, size = { 2.5, 4 }, grow = { 0.6, 1.6 }, alpha = 0.3,
				colors = { "3A302A", "5A4A40" }, speed = { 0.5, 1.2 }, dir = "up", spread = 20 },
		},
		glows = {
			{ at = "att_eye", size = 3.9, color = "FFD23A", alpha = 0.7, pulse = 0.15, rate = 5 },
			{ at = "att_mouth", size = 7.2, color = "FFB030", alpha = 0.6, pulse = 0.12, rate = 6 },
			{ at = "att_ember_heart", size = 4.2, color = "FF8A1A", alpha = 0.8, pulse = 0.2, rate = 3 },
		},
		lights = {
			{ at = "att_head_inside", color = "FF9A3A", rageColor = "FF7A20", brightness = 1.6, rageBrightness = 3, flicker = 0.18 },
			{ at = "att_ember_heart", color = "FF8A1A", brightness = 1.2, flicker = 0.1 },
		},
	},
	jungle = {
		accent = "3FFFD0",
		emitters = {
			{ at = "att_rune_core", box = V3(8, 10, 5), tex = "glyph", add = true, rate = 12, rage = 2.5, life = { 1.5, 2.6 }, size = { 0.64, 1.03, 0 },
				colors = { "3FFFD0", "8AFFE4" }, rageColors = { "FFC43A", "FFE08A" }, speed = { 1, 2.6 }, dir = "side", spread = 90, drag = 1, spin = 1 },
			{ at = "sky", box = V3(30, 4, 30), y1 = 28, tex = "leaf", rate = 2.2, life = { 5, 7 }, size = { 1, 1.5, 1 },
				colors = { "1EA03C", "3FAE3A", "6AD878" }, speed = { 0.5, 1.2 }, dir = "down", spread = 30, spin = 1.5, wobble = true },
			-- (30 Oct) fireflies drifting over the arena and runes circling it
			{ at = "arena", box = V3(50, 12, 50), y0 = 5, tex = "dot", add = true, rate = 6, life = { 3, 5 }, size = { 0.3, 0.45, 0.4 },
				colors = { "7FD8FF", "3FFFD0" }, speed = { 0.3, 1 }, dir = "side", spread = 180, wobble = true },
			{ at = "orbit", radius = { 7, 9 }, high = { 2, 10 }, orbitSpeed = 3, tex = "glyph", add = true, rate = 4, rage = 2, life = { 1.5, 2.5 }, size = { 0.9, 1.3, 0 },
				colors = { "3FFFD0", "8AFFE4" }, rageColors = { "FFC43A", "FFE08A" }, speed = { 0, 0.3 }, dir = "up", spread = 30, spin = 0.5 },
		},
		glows = {
			{ at = "att_rune_core", size = 6.7, color = "3FFFD0", rageColor = "FFC43A", alpha = 0.8, pulse = 0.12, rate = 2.5, rageSize = 1.3 },
			{ at = "att_eye", size = 2.6, color = "3FFFD0", rageColor = "FFC43A", alpha = 0.75, pulse = 0.08, rate = 2 },
		},
		lights = {
			{ at = "att_rune_core", color = "3FFFD0", rageColor = "FFC43A", brightness = 1.6, rageBrightness = 2.4, flicker = 0.05 },
			{ at = "att_eye", color = "3FFFD0", rageColor = "FFC43A", brightness = 0.8 },
		},
		stones = { count = 7, radius = 10.8, high = 16.7, size = 1.3 }, -- rage form: temple stones orbit it
	},
}

return Spec
