return {
	_about = "Hit effects (client/HitFx). Each event is a list of layers. 'sprite' layers are BillboardGui images (size in exact studs; flipbook textures play their 16 frames over the lifetime); 'particles' layers are ParticleEmitter bursts (property names in lowercase); 'clippings' are the Blender fx_clip models thrown with real physics (Roblox gravity is 196.2, so they need big upward speeds). Colours are [r,g,b] or grass / grassLight / grassPale / grassDark (follow the clump's colour). 'at': contact (where the fist or blade lands: the clump's near side, a bit below your eyes, a little to the right), base (the clump's foot, raised by 'height'), top. 'dir': out (toward you, tilted 'tilt' degrees from straight up), up, none. Render any event with tools/preview/fx_sim.py to judge it frame by frame. 'pop' (cut only): a copy of the clump flashes white, swells by 'grow' and shrinks away while the stubble appears. Boss events (client/BossFx; the colour is the boss's or the zone's ground): bossHit, bossRise (dust at its feet while it climbs out), bossSlam / bossSlamDust (the slam's centre and its rim), bossDeath (the pop). 'at': point = exactly at pos, raised by 'height'. Heights are above the ground under the clump, and every size scales up for the big voxel clumps (client/HitFx Ctx).",
	auto = {
		flash = 0.2,
		hitstop = 0,
		kick = 0,
		layers = {
			{
				acceleration = {
					0,
					-42,
					0,
				},
				at = "base",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 5,
				dir = "up",
				drag = 1.6,
				height = 0.8,
				kind = "particles",
				lifetime = {
					0.5,
					0.8,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "blades",
				rotSpeed = {
					-500,
					500,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.35,
					},
					{
						0.8,
						0.3,
					},
					{
						1,
						0,
					},
				},
				speed = {
					9,
					15,
				},
				spread = {
					60,
					60,
				},
				texture = "blade",
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "base",
				brightness = 1.25,
				color = {
					{
						0,
						{
							255,
							252,
							236,
						},
					},
					{
						1,
						{
							240,
							244,
							222,
						},
					},
				},
				count = 1,
				flipbook = true,
				height = 0.9,
				kind = "sprite",
				lifetime = {
					0.4,
					0.5,
				},
				name = "poof",
				offset = 0.4,
				rise = 1.4,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.8,
					},
					{
						1,
						1.7,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.2,
					},
					{
						1,
						0.4,
					},
				},
			},
			{
				acceleration = {
					0,
					-9,
					0,
				},
				at = "crown",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 3,
				dir = "up",
				drag = 2.2,
				height = 0.8,
				kind = "particles",
				lifetime = {
					1.2,
					1.9,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "crownBlades",
				rotSpeed = {
					-220,
					220,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.5,
					},
					{
						0.8,
						0.45,
					},
					{
						1,
						0,
					},
				},
				speed = {
					3,
					7,
				},
				spread = {
					180,
					180,
				},
				texture = "blade",
				transparency = {
					{
						0,
						0,
					},
					{
						0.85,
						0,
					},
					{
						1,
						1,
					},
				},
			},
		},
		wobble = 0.6,
	},
	bossDeath = {
		flash = 0,
		hitstop = 0,
		kick = 0,
		layers = {
			{
				at = "point",
				brightness = 3,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				kind = "sprite",
				lifetime = {
					0.35,
					0.35,
				},
				name = "glow",
				size = {
					{
						0,
						4,
					},
					{
						0.25,
						18,
					},
					{
						1,
						22,
					},
				},
				texture = "glow",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.2,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.5,
			},
			{
				at = "point",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.3,
					0.3,
				},
				name = "impact",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						6,
					},
					{
						1,
						20,
					},
				},
				texture = "impact",
				transparency = {
					{
						0,
						0.05,
					},
					{
						0.5,
						0.35,
					},
					{
						1,
						1,
					},
				},
				zOffset = 2,
			},
			{
				at = "point",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				kind = "sprite",
				lifetime = {
					0.2,
					0.2,
				},
				name = "star",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						4,
					},
					{
						0.4,
						20,
					},
					{
						1,
						24,
					},
				},
				texture = "burst",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.3,
					},
					{
						1,
						1,
					},
				},
				zOffset = 2.5,
			},
			{
				acceleration = {
					0,
					-12,
					0,
				},
				at = "point",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 50,
				dir = "up",
				drag = 3,
				kind = "particles",
				lifetime = {
					0.6,
					1.2,
				},
				lightEmission = 1,
				lightInfluence = 0,
				name = "sparkles",
				rotation = {
					0,
					90,
				},
				size = {
					{
						0,
						1.4,
					},
					{
						1,
						0,
					},
				},
				speed = {
					30,
					60,
				},
				spread = {
					180,
					180,
				},
				texture = "spark",
				zOffset = 2,
			},
			{
				acceleration = {
					0,
					-30,
					0,
				},
				at = "point",
				brightness = 1.4,
				color = {
					{
						0,
						{
							255,
							255,
							220,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 30,
				dir = "up",
				drag = 5,
				kind = "particles",
				lifetime = {
					0.3,
					0.5,
				},
				lightEmission = 0.3,
				lightInfluence = 0,
				name = "splinters",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						1,
					},
					{
						0.15,
						3.2,
					},
					{
						1,
						0.6,
					},
				},
				speed = {
					60,
					95,
				},
				spread = {
					180,
					180,
				},
				texture = "splinter",
				transparency = {
					{
						0,
						0,
					},
					{
						0.7,
						0,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.5,
			},
			{
				acceleration = {
					0,
					-40,
					0,
				},
				at = "point",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 30,
				dir = "up",
				drag = 1.2,
				kind = "particles",
				lifetime = {
					1,
					1.6,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "blades",
				rotSpeed = {
					-500,
					500,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1.5,
					},
					{
						0.8,
						1.3,
					},
					{
						1,
						0,
					},
				},
				speed = {
					25,
					45,
				},
				spread = {
					180,
					180,
				},
				texture = "blade",
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "point",
				brightness = 1.3,
				color = {
					{
						0,
						{
							255,
							252,
							240,
						},
					},
					{
						1,
						"grassPale",
					},
				},
				count = 6,
				delay = 0.03,
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.7,
					0.9,
				},
				name = "poof",
				offset = 4,
				rise = 3,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						5,
					},
					{
						1,
						11,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.05,
					},
					{
						1,
						0.35,
					},
				},
				zOffset = 1,
			},
			{
				at = "base",
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 1,
				dir = "up",
				height = 0.3,
				kind = "particles",
				lifetime = {
					0.5,
					0.5,
				},
				lightEmission = 0.6,
				lightInfluence = 0,
				name = "ring",
				orientation = "VelocityPerpendicular",
				size = {
					{
						0,
						4,
					},
					{
						1,
						40,
					},
				},
				speed = {
					0.01,
					0.01,
				},
				texture = "ring",
				transparency = {
					{
						0,
						0.1,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "point",
				count = 24,
				kind = "clippings",
				mineCount = 24,
				otherCount = 24,
				out = {
					4,
					16,
				},
				side = 30,
				size = 2,
				up = {
					40,
					70,
				},
			},
		},
		wobble = 0,
	},
	bossHit = {
		flash = 0.35,
		hitstop = 0.05,
		kick = 1.8,
		layers = {
			{
				at = "contact",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							248,
							222,
						},
					},
					{
						1,
						{
							255,
							226,
							160,
						},
					},
				},
				kind = "sprite",
				lifetime = {
					0.14,
					0.14,
				},
				name = "glow",
				size = {
					{
						0,
						1.5,
					},
					{
						0.3,
						3.6,
					},
					{
						1,
						4.2,
					},
				},
				texture = "glow",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.2,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.5,
			},
			{
				at = "contact",
				brightness = 1.6,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						{
							255,
							232,
							170,
						},
					},
				},
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.176,
					0.176,
				},
				name = "impact",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						2.2,
					},
					{
						1,
						5.5,
					},
				},
				texture = "impact",
				transparency = {
					{
						0,
						0.05,
					},
					{
						0.5,
						0.4,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.8,
			},
			{
				at = "contact",
				brightness = 1.6,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				kind = "sprite",
				lifetime = {
					0.11,
					0.11,
				},
				name = "star",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1.2,
					},
					{
						0.4,
						3.2,
					},
					{
						1,
						3.6,
					},
				},
				texture = "burst",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.35,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.6,
			},
			{
				acceleration = {
					0,
					-30,
					0,
				},
				at = "contact",
				brightness = 1.3,
				color = {
					{
						0,
						{
							252,
							255,
							200,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 12,
				dir = "out",
				drag = 6,
				kind = "particles",
				lifetime = {
					0.2,
					0.32,
				},
				lightEmission = 0.3,
				lightInfluence = 0,
				name = "splinters",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						0.5,
					},
					{
						0.15,
						1.6,
					},
					{
						1,
						0.3,
					},
				},
				speed = {
					40,
					60,
				},
				spread = {
					75,
					75,
				},
				texture = "splinter",
				tilt = 45,
				transparency = {
					{
						0,
						0,
					},
					{
						0.7,
						0,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				acceleration = {
					0,
					-42,
					0,
				},
				at = "contact",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 8,
				dir = "out",
				drag = 1.4,
				kind = "particles",
				lifetime = {
					0.7,
					1,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "blades",
				rotSpeed = {
					-500,
					500,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.9,
					},
					{
						0.8,
						0.8,
					},
					{
						1,
						0,
					},
				},
				speed = {
					22,
					34,
				},
				spread = {
					75,
					75,
				},
				texture = "blade",
				tilt = 40,
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "contact",
				brightness = 1.25,
				color = {
					{
						0,
						{
							255,
							252,
							236,
						},
					},
					{
						1,
						"grassPale",
					},
				},
				count = 2,
				delay = 0.02,
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.45,
					0.6,
				},
				name = "poof",
				offset = 1,
				rise = 3,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1.8,
					},
					{
						1,
						4,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.05,
					},
					{
						1,
						0.3,
					},
				},
				zOffset = 1.2,
			},
			{
				at = "contact",
				count = 4,
				kind = "clippings",
				mineCount = 4,
				otherCount = 2,
				out = {
					6,
					14,
				},
				side = 12,
				size = 1.3,
				up = {
					30,
					44,
				},
			},
		},
		wobble = 0,
	},
	bossRise = {
		flash = 0,
		hitstop = 0,
		kick = 0,
		layers = {
			{
				at = "base",
				brightness = 1.1,
				color = {
					{
						0,
						"grassPale",
					},
					{
						1,
						"grassLight",
					},
				},
				count = 3,
				delay = 0.05,
				flipbook = true,
				height = 1.2,
				kind = "sprite",
				lifetime = {
					0.7,
					0.9,
				},
				name = "poof",
				offset = 2.5,
				rise = 4,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						4,
					},
					{
						1,
						8.5,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.05,
					},
					{
						1,
						0.35,
					},
				},
				zOffset = 0.5,
			},
			{
				acceleration = {
					0,
					-80,
					0,
				},
				at = "base",
				color = {
					{
						0,
						"grassDark",
					},
					{
						1,
						"grass",
					},
				},
				count = 10,
				dir = "up",
				drag = 1,
				height = 1,
				kind = "particles",
				lifetime = {
					0.45,
					0.7,
				},
				lightEmission = 0,
				lightInfluence = 0.8,
				name = "clods",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						0.7,
					},
					{
						0.2,
						1.7,
					},
					{
						1,
						0.8,
					},
				},
				speed = {
					25,
					40,
				},
				spread = {
					50,
					50,
				},
				texture = "splinter",
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "base",
				color = {
					{
						0,
						{
							255,
							250,
							230,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 1,
				dir = "up",
				height = 0.2,
				kind = "particles",
				lifetime = {
					0.45,
					0.45,
				},
				lightEmission = 0.4,
				lightInfluence = 0,
				name = "ring",
				orientation = "VelocityPerpendicular",
				size = {
					{
						0,
						2,
					},
					{
						1,
						14,
					},
				},
				speed = {
					0.01,
					0.01,
				},
				texture = "ring",
				transparency = {
					{
						0,
						0.2,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "base",
				count = 3,
				height = 1.5,
				kind = "clippings",
				mineCount = 3,
				otherCount = 3,
				out = {
					2,
					6,
				},
				side = 14,
				size = 1.2,
				up = {
					40,
					56,
				},
			},
		},
		wobble = 0,
	},
	bossSlam = {
		flash = 0,
		hitstop = 0,
		kick = 0,
		layers = {
			{
				at = "base",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							248,
							222,
						},
					},
					{
						1,
						{
							255,
							226,
							160,
						},
					},
				},
				height = 1.5,
				kind = "sprite",
				lifetime = {
					0.16,
					0.16,
				},
				name = "glow",
				size = {
					{
						0,
						4,
					},
					{
						0.3,
						9,
					},
					{
						1,
						10,
					},
				},
				texture = "glow",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.2,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.5,
			},
			{
				at = "base",
				brightness = 1.5,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						{
							255,
							232,
							170,
						},
					},
				},
				flipbook = true,
				height = 2,
				kind = "sprite",
				lifetime = {
					0.22,
					0.22,
				},
				name = "impact",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						4,
					},
					{
						1,
						10,
					},
				},
				texture = "impact",
				transparency = {
					{
						0,
						0.05,
					},
					{
						0.5,
						0.4,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				acceleration = {
					0,
					-90,
					0,
				},
				at = "base",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grassDark",
					},
				},
				count = 18,
				dir = "up",
				drag = 1.5,
				height = 1,
				kind = "particles",
				lifetime = {
					0.45,
					0.75,
				},
				lightEmission = 0,
				lightInfluence = 0.8,
				name = "clods",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						0.6,
					},
					{
						0.15,
						1.8,
					},
					{
						1,
						0.6,
					},
				},
				speed = {
					40,
					60,
				},
				spread = {
					60,
					60,
				},
				texture = "splinter",
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "base",
				brightness = 1.1,
				color = {
					{
						0,
						"grassPale",
					},
					{
						1,
						"grassLight",
					},
				},
				count = 4,
				delay = 0.03,
				flipbook = true,
				height = 1.5,
				kind = "sprite",
				lifetime = {
					0.6,
					0.8,
				},
				name = "poof",
				offset = 2.5,
				rise = 3,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						3,
					},
					{
						1,
						7.5,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.05,
					},
					{
						1,
						0.35,
					},
				},
				zOffset = 0.5,
			},
			{
				at = "base",
				count = 6,
				height = 1.5,
				kind = "clippings",
				mineCount = 6,
				otherCount = 6,
				out = {
					2,
					8,
				},
				side = 18,
				size = 1.3,
				up = {
					45,
					65,
				},
			},
		},
		wobble = 0,
	},
	bossSlamDust = {
		flash = 0,
		hitstop = 0,
		kick = 0,
		layers = {
			{
				at = "base",
				brightness = 1.1,
				color = {
					{
						0,
						"grassPale",
					},
					{
						1,
						"grassLight",
					},
				},
				count = 2,
				delay = 0.04,
				flipbook = true,
				height = 1,
				kind = "sprite",
				lifetime = {
					0.55,
					0.75,
				},
				name = "poof",
				offset = 1,
				rise = 2.5,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						2.5,
					},
					{
						1,
						5.5,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.05,
					},
					{
						1,
						0.35,
					},
				},
				zOffset = 0.5,
			},
			{
				acceleration = {
					0,
					-80,
					0,
				},
				at = "base",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grassDark",
					},
				},
				count = 4,
				dir = "up",
				drag = 1,
				height = 0.6,
				kind = "particles",
				lifetime = {
					0.35,
					0.55,
				},
				lightEmission = 0,
				lightInfluence = 0.8,
				name = "clods",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						0.5,
					},
					{
						0.2,
						1.2,
					},
					{
						1,
						0.5,
					},
				},
				speed = {
					18,
					28,
				},
				spread = {
					40,
					40,
				},
				texture = "splinter",
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
		},
		wobble = 0,
	},
	cut = {
		flash = 0,
		hitstop = 0.07,
		kick = 2,
		layers = {
			{
				at = "contact",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							248,
							222,
						},
					},
					{
						1,
						{
							255,
							226,
							160,
						},
					},
				},
				kind = "sprite",
				lifetime = {
					0.16,
					0.16,
				},
				mineOnly = true,
				name = "glow",
				size = {
					{
						0,
						0.8,
					},
					{
						0.3,
						2,
					},
					{
						1,
						2.3,
					},
				},
				texture = "glow",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.25,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				at = "base",
				brightness = 1.5,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						{
							255,
							232,
							170,
						},
					},
				},
				flipbook = true,
				height = 1.6,
				kind = "sprite",
				lifetime = {
					0.192,
					0.192,
				},
				name = "impact",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1.4,
					},
					{
						1,
						3.2,
					},
				},
				texture = "impact",
				transparency = {
					{
						0,
						0.05,
					},
					{
						0.5,
						0.45,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				acceleration = {
					0,
					-20,
					0,
				},
				at = "base",
				brightness = 1.3,
				color = {
					{
						0,
						{
							252,
							255,
							200,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 10,
				dir = "up",
				drag = 6,
				height = 1.4,
				kind = "particles",
				lifetime = {
					0.24,
					0.36,
				},
				lightEmission = 0.3,
				lightInfluence = 0,
				name = "splinters",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						0.25,
					},
					{
						0.15,
						0.9,
					},
					{
						1,
						0.15,
					},
				},
				speed = {
					22,
					34,
				},
				spread = {
					85,
					85,
				},
				texture = "splinter",
				transparency = {
					{
						0,
						0,
					},
					{
						0.7,
						0,
					},
					{
						1,
						1,
					},
				},
				zOffset = 0.5,
			},
			{
				acceleration = {
					0,
					-42,
					0,
				},
				at = "base",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 14,
				dir = "up",
				drag = 1.4,
				height = 1.4,
				kind = "particles",
				lifetime = {
					0.7,
					1.05,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "blades",
				rotSpeed = {
					-500,
					500,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.45,
					},
					{
						0.8,
						0.4,
					},
					{
						1,
						0,
					},
				},
				speed = {
					11,
					18,
				},
				spread = {
					75,
					75,
				},
				texture = "blade",
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "base",
				brightness = 1.25,
				color = {
					{
						0,
						{
							255,
							252,
							236,
						},
					},
					{
						1,
						{
							240,
							244,
							222,
						},
					},
				},
				count = 3,
				delay = 0.03,
				flipbook = true,
				height = 1.1,
				kind = "sprite",
				lifetime = {
					0.5,
					0.65,
				},
				name = "poof",
				offset = 0.9,
				rise = 2,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1.2,
					},
					{
						1,
						2.6,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.05,
					},
					{
						1,
						0.3,
					},
				},
				zOffset = 0.6,
			},
			{
				at = "base",
				color = {
					{
						0,
						{
							250,
							255,
							220,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 1,
				dir = "up",
				height = 0.15,
				kind = "particles",
				lifetime = {
					0.32,
					0.32,
				},
				lightEmission = 0.6,
				lightInfluence = 0,
				name = "ring",
				orientation = "VelocityPerpendicular",
				size = {
					{
						0,
						1,
					},
					{
						1,
						6,
					},
				},
				speed = {
					0.01,
					0.01,
				},
				texture = "ring",
				transparency = {
					{
						0,
						0.15,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "base",
				count = 8,
				height = 1.5,
				kind = "clippings",
				mineCount = 8,
				otherCount = 4,
				out = {
					1,
					5,
				},
				side = 11,
				size = 0.7,
				up = {
					30,
					44,
				},
			},
			{
				at = "base",
				count = 9,
				height = 1.5,
				kind = "chunks",
				mineOnly = true,
				name = "chunks",
				size = 1.7,
				speed = 1.3,
			},
		},
		pop = {
			grow = 1.2,
			growTime = 0.06,
			shrinkTime = 0.16,
			white = 0.8,
		},
		wobble = 0,
	},
	hit = {
		flash = 0.3,
		hitstop = 0.06,
		kick = 1,
		layers = {
			{
				at = "contact",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							248,
							222,
						},
					},
					{
						1,
						{
							255,
							226,
							160,
						},
					},
				},
				kind = "sprite",
				lifetime = {
					0.12,
					0.12,
				},
				name = "glow",
				size = {
					{
						0,
						0.8,
					},
					{
						0.3,
						1.9,
					},
					{
						1,
						2.2,
					},
				},
				texture = "glow",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.2,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				at = "contact",
				brightness = 1.5,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						{
							255,
							232,
							170,
						},
					},
				},
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.144,
					0.144,
				},
				name = "impact",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1.2,
					},
					{
						1,
						3,
					},
				},
				texture = "impact",
				transparency = {
					{
						0,
						0.05,
					},
					{
						0.5,
						0.45,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.2,
			},
			{
				acceleration = {
					0,
					-20,
					0,
				},
				at = "contact",
				brightness = 1.3,
				color = {
					{
						0,
						{
							252,
							255,
							200,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 8,
				dir = "out",
				drag = 6,
				kind = "particles",
				lifetime = {
					0.18,
					0.3,
				},
				lightEmission = 0.3,
				lightInfluence = 0,
				name = "splinters",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						0.2,
					},
					{
						0.15,
						0.75,
					},
					{
						1,
						0.15,
					},
				},
				speed = {
					18,
					28,
				},
				spread = {
					75,
					75,
				},
				texture = "splinter",
				tilt = 45,
				transparency = {
					{
						0,
						0,
					},
					{
						0.7,
						0,
					},
					{
						1,
						1,
					},
				},
				zOffset = 0.5,
			},
			{
				at = "contact",
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						{
							255,
							240,
							200,
						},
					},
				},
				count = 1,
				dir = "out",
				kind = "particles",
				lifetime = {
					0.16,
					0.16,
				},
				lightEmission = 0.6,
				lightInfluence = 0,
				name = "shock",
				orientation = "VelocityPerpendicular",
				size = {
					{
						0,
						0.4,
					},
					{
						1,
						2.6,
					},
				},
				speed = {
					0.01,
					0.01,
				},
				texture = "ring",
				tilt = 90,
				transparency = {
					{
						0,
						0.1,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.1,
			},
			{
				acceleration = {
					0,
					-42,
					0,
				},
				at = "contact",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 6,
				dir = "out",
				drag = 1.6,
				kind = "particles",
				lifetime = {
					0.55,
					0.85,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "blades",
				rotSpeed = {
					-500,
					500,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.35,
					},
					{
						0.8,
						0.3,
					},
					{
						1,
						0,
					},
				},
				speed = {
					8,
					14,
				},
				spread = {
					80,
					80,
				},
				texture = "blade",
				tilt = 40,
				transparency = {
					{
						0,
						0,
					},
					{
						0.8,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "contact",
				brightness = 1.25,
				color = {
					{
						0,
						{
							255,
							252,
							236,
						},
					},
					{
						1,
						{
							240,
							244,
							222,
						},
					},
				},
				count = 2,
				delay = 0.02,
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.4,
					0.5,
				},
				name = "poof",
				offset = 0.45,
				rise = 1.6,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1,
					},
					{
						1,
						2.4,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.08,
					},
					{
						1,
						0.3,
					},
				},
				zOffset = 0.6,
			},
			{
				at = "contact",
				count = 4,
				kind = "clippings",
				out = {
					1,
					4,
				},
				side = 9,
				size = 0.6,
				up = {
					26,
					38,
				},
			},
			{
				at = "contact",
				count = 6,
				kind = "chunks",
				name = "chunks",
				size = 1,
			},
			{
				acceleration = {
					0,
					-9,
					0,
				},
				at = "crown",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 8,
				dir = "up",
				drag = 2.2,
				height = 0.8,
				kind = "particles",
				lifetime = {
					1.2,
					1.9,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "crownBlades",
				rotSpeed = {
					-220,
					220,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.5,
					},
					{
						0.8,
						0.45,
					},
					{
						1,
						0,
					},
				},
				speed = {
					3,
					7,
				},
				spread = {
					180,
					180,
				},
				texture = "blade",
				transparency = {
					{
						0,
						0,
					},
					{
						0.85,
						0,
					},
					{
						1,
						1,
					},
				},
			},
			{
				at = "contact",
				kind = "marks",
				length = 2.4,
				life = 1.1,
				name = "marks",
			},
		},
		wobble = 1,
	},
	punch = {
		flash = 0.3,
		hitstop = 0.05,
		kick = 1,
		layers = {
			{
				at = "contact",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							248,
							222,
						},
					},
					{
						1,
						{
							255,
							226,
							160,
						},
					},
				},
				kind = "sprite",
				lifetime = {
					0.12,
					0.12,
				},
				name = "glow",
				size = {
					{
						0,
						0.8,
					},
					{
						0.3,
						1.9,
					},
					{
						1,
						2.2,
					},
				},
				texture = "glow",
				transparency = {
					{
						0,
						0,
					},
					{
						0.5,
						0.2,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				at = "contact",
				brightness = 1.5,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						{
							255,
							232,
							170,
						},
					},
				},
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.144,
					0.144,
				},
				name = "impact",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1.2,
					},
					{
						1,
						3,
					},
				},
				texture = "impact",
				transparency = {
					{
						0,
						0.05,
					},
					{
						0.5,
						0.45,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.2,
			},
			{
				at = "contact",
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						{
							255,
							240,
							200,
						},
					},
				},
				count = 1,
				dir = "out",
				kind = "particles",
				lifetime = {
					0.16,
					0.16,
				},
				lightEmission = 0.6,
				lightInfluence = 0,
				name = "shock",
				orientation = "VelocityPerpendicular",
				size = {
					{
						0,
						0.4,
					},
					{
						1,
						2.6,
					},
				},
				speed = {
					0.01,
					0.01,
				},
				texture = "ring",
				tilt = 90,
				transparency = {
					{
						0,
						0.1,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1.1,
			},
			{
				acceleration = {
					0,
					-20,
					0,
				},
				at = "contact",
				brightness = 1.3,
				color = {
					{
						0,
						{
							252,
							255,
							200,
						},
					},
					{
						1,
						"grassLight",
					},
				},
				count = 6,
				dir = "out",
				drag = 6,
				kind = "particles",
				lifetime = {
					0.18,
					0.28,
				},
				lightEmission = 0.3,
				lightInfluence = 0,
				name = "splinters",
				orientation = "VelocityParallel",
				size = {
					{
						0,
						0.2,
					},
					{
						0.15,
						0.65,
					},
					{
						1,
						0.15,
					},
				},
				speed = {
					16,
					24,
				},
				spread = {
					70,
					70,
				},
				texture = "splinter",
				tilt = 48,
				transparency = {
					{
						0,
						0,
					},
					{
						0.7,
						0,
					},
					{
						1,
						1,
					},
				},
				zOffset = 0.5,
			},
			{
				at = "contact",
				brightness = 1.25,
				color = {
					{
						0,
						{
							255,
							252,
							236,
						},
					},
					{
						1,
						{
							240,
							244,
							222,
						},
					},
				},
				count = 2,
				delay = 0.02,
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.42,
					0.55,
				},
				name = "poof",
				offset = 0.45,
				rise = 1.6,
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						1,
					},
					{
						1,
						2.4,
					},
				},
				texture = "poof",
				transparency = {
					{
						0,
						0.05,
					},
					{
						1,
						0.3,
					},
				},
				zOffset = 0.6,
			},
			{
				at = "contact",
				count = 4,
				kind = "clippings",
				out = {
					1,
					4,
				},
				side = 9,
				size = 0.6,
				up = {
					26,
					38,
				},
			},
			{
				at = "contact",
				count = 5,
				kind = "chunks",
				name = "chunks",
				size = 1,
			},
			{
				acceleration = {
					0,
					-9,
					0,
				},
				at = "crown",
				color = {
					{
						0,
						"grassLight",
					},
					{
						1,
						"grass",
					},
				},
				count = 8,
				dir = "up",
				drag = 2.2,
				height = 0.8,
				kind = "particles",
				lifetime = {
					1.2,
					1.9,
				},
				lightEmission = 0,
				lightInfluence = 0.6,
				name = "crownBlades",
				rotSpeed = {
					-220,
					220,
				},
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						0.5,
					},
					{
						0.8,
						0.45,
					},
					{
						1,
						0,
					},
				},
				speed = {
					3,
					7,
				},
				spread = {
					180,
					180,
				},
				texture = "blade",
				transparency = {
					{
						0,
						0,
					},
					{
						0.85,
						0,
					},
					{
						1,
						1,
					},
				},
			},
		},
		wobble = 1,
	},
	reveal = {
		flash = 0.6,
		hitstop = 0,
		kick = 0,
		layers = {
			{
				at = "top",
				brightness = 3,
				color = {
					{
						0,
						"grass",
					},
					{
						1,
						"grass",
					},
				},
				kind = "sprite",
				lifetime = {
					0.35,
					0.35,
				},
				name = "glow",
				size = {
					{
						0,
						1.5,
					},
					{
						0.3,
						4.5,
					},
					{
						1,
						5,
					},
				},
				texture = "glow",
				transparency = {
					{
						0,
						0,
					},
					{
						0.6,
						0.4,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				at = "top",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grass",
					},
				},
				flipbook = true,
				kind = "sprite",
				lifetime = {
					0.256,
					0.256,
				},
				name = "impact",
				rotation = {
					0,
					360,
				},
				size = {
					{
						0,
						2,
					},
					{
						1,
						5,
					},
				},
				texture = "impact",
				transparency = {
					{
						0,
						0.05,
					},
					{
						0.5,
						0.45,
					},
					{
						1,
						1,
					},
				},
				zOffset = 1,
			},
			{
				acceleration = {
					0,
					-6,
					0,
				},
				at = "top",
				brightness = 2,
				color = {
					{
						0,
						{
							255,
							255,
							255,
						},
					},
					{
						1,
						"grass",
					},
				},
				count = 22,
				dir = "up",
				drag = 3,
				kind = "particles",
				lifetime = {
					0.4,
					0.8,
				},
				lightEmission = 1,
				lightInfluence = 0,
				name = "sparkles",
				rotation = {
					0,
					90,
				},
				size = {
					{
						0,
						0.45,
					},
					{
						1,
						0,
					},
				},
				speed = {
					8,
					15,
				},
				spread = {
					180,
					180,
				},
				texture = "spark",
				zOffset = 1,
			},
		},
		wobble = 0,
	},
}