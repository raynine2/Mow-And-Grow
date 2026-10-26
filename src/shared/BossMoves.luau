-- How each of the 8 bosses fights (the owner's boss brief, 26 Oct: claude.ai project doc
-- `claude/boss-revamp-brief.md`): its rig (the Blender model in ReplicatedStorage.BossModels + shared/BossRigs),
-- its size, 3 moves in phase 1 and 2 more in phase 2 (the rage form, from 50% HP), its weak spot, its arena's look
-- and the words of its cutscenes. server/Boss runs the fight from this; client/BossView, BossCine and BossVfx draw
-- it.
--
-- Every boss has its OWN five moves (owner, 26 Oct: "make every boss have unique attacks, not the same recycled
-- attacks with just different effects"): no two bosses share a move. Each move names its `kind`; server/Boss runs it
-- and checks the hits, client/BossVfx draws the warning and the move itself. `punish = true`: the boss is stuck
-- afterwards and its weak spot glows (x2.5 damage). `pose`: what the boss's body does (client/BossView).
--   Dandelion King   slam (one big circle) | drift (seed puffs float across the arena in lanes) | cross (+ of strips)
--                    | beam (a pollen beam turns round it) | adds (seedlings chase you)
--   Hive Keeper      homing (bees chase you, outrun them or swat them) | hedges (rows of thorn walls with a gap,
--                    rolling outwards) | combo (3 punches stepping at you) | hazard (thorn carpet) | safe (pollen
--                    fills the arena: stand in a flower)
--   Sand-Trap Shell  roll (giant golf balls bounce off the wall) | wave (sand waves roll out: JUMP them) | cone (rake
--                    swipe in front) | sink (sand traps: stand in one too long and you're stuck) | burrow (it digs
--                    under you and bursts out)
--   Scarecrow        fan (3 pitchfork tines) | dive (crows swoop across in lines) | lob (chaff thrown at you) |
--                    spread (fires that grow) | rings (crop circles: alternating bands)
--   Sakura           spiral (petals land in a spiral) | sweep (snap lunge) | orbit (lantern wisps circle out) |
--                    ring (hug it or run) | leap (jumps on you)
--   Bog              grid (checkerboard geysers) | bounce (a slime blob hops after you) | stalk (vines burst where
--                    you stand, again and again) | turrets (sprouts that spit) | tide (the bog floods in from the edge)
--   Harvest Reaper   swing (scythe arc across the front) | mines (pumpkin bombs with a fuse) | dash (charges
--                    through, leaves fire) | adds (jack-o'-minions that explode) | mark (a reaper mark follows you,
--                    then locks)
--   Jungle Titan     star (cracks in 6 directions, twice) | meteors (rune meteors all over) | pillars (stone pillars
--                    rise and stay) | laser (rune lasers aim at you) | gaze (hide behind a pillar or get hit)
-- Times are seconds; `tele` is the warning time (BossMoves.curve). Every boss after the first is a bit quicker
-- (boss 1 is the gentle tutorial, owner round 2). Shapes and moving things share their maths below
-- (BossMoves.inShape, BossMoves.moverShapes) so the server's hits and the client's drawing always agree.
local BossMoves = {}

-- the shared tuning (research: telegraphs 1.2-1.5 s, never under 0.8 s; punish windows 2-4 s; phase 2 at 50 %)
BossMoves.TELE = 1.3 -- phase 1 warning
BossMoves.TELE2 = 0.95 -- phase 2 warning
BossMoves.PUNISH = 2.8 -- seconds the boss stays open (weak spot glowing) after a slam, sweep or leap
BossMoves.WEAK_MULT = 2.5 -- damage x this while it's open
BossMoves.GAP = 1.2 -- rest between moves (phase 2: x0.6)
BossMoves.RAGE_AT = 0.5 -- phase 2 starts at this fraction of HP
BossMoves.INTRO_FIRST = 8 -- the first intro of each boss on a server
BossMoves.INTRO_AGAIN = 2.5 -- short version after that
BossMoves.RAGE_TIME = 5.2 -- the phase-2 cutscene (the boss can't be hurt)
BossMoves.DEATH_TIME = 3.2 -- the death cutscene, then the rewards
BossMoves.JOIN_WINDOW = 10 -- seconds after the summon before the arena gate closes
BossMoves.SUMMON_HOLD = 1.2 -- stand on the summon pad this long to start the fight
BossMoves.STUN = 1.2 -- a hit knocks you back and stuns you this long
-- damage to players (100 HP each, server/BossFighters)
BossMoves.DAMAGE = {
	slam = 30, drift = 14, cross = 26, beam = 22, adds = 12,
	homing = 16, hedges = 24, combo = 22, hazard = 8, safe = 30,
	roll = 22, wave = 20, cone = 30, sink = 16, burrow = 34,
	fan = 26, dive = 18, lob = 18, spread = 6, rings = 26,
	spiral = 18, sweep = 30, orbit = 16, ring = 28, leap = 35,
	grid = 24, bounce = 20, stalk = 22, turrets = 14, tide = 7,
	swing = 30, mines = 26, dash = 30, boom = 24, mark = 34,
	star = 28, meteors = 26, pillars = 20, laser = 30, gaze = 40,
}
BossMoves.HAZARD_TICK = 0.6 -- a hazard / pool / fire / flood hurts this often while you stand in it
BossMoves.JUMP_CLEAR = 4.2 -- studs your middle must be above the floor to jump over a wave

BossMoves.list = {
	{
		rig = "dandelion",
		height = 36, -- studs, top of the model
		title = "Ruler of the Unmowed Lawn",
		lines = { intro = "Who dares trim my kingdom?!", rage = "My crown... MY SEEDS! GET THEM!", death = "I'll... grow... back..." },
		intro = "rise", -- client/BossCine: how it appears
		weak = "att_scepter_core", -- the glowing weak spot (an att_* point of the rig)
		arena = "meadow",
		dust = { "9C6E44", "C39A6A", "7A5434" },
		ring = "FFE46A", -- shockwave colour
		moves = {
			{ kind = "slam", name = "Scepter Smash", radius = 12, punish = true, pose = "strike" },
			{ kind = "drift", name = "Puff Parade", gap = 13, r = 3.5, speed = 15, waves = 2, look = "puff", pose = "volley" },
			{ kind = "cross", name = "Royal Decree", width = 10, pose = "stomp" },
		},
		moves2 = {
			{ kind = "beam", name = "Crown Spin", width = 7, turn = 5.2, speed = 0.95, look = "pollen", pose = "spin" },
			{ kind = "adds", name = "Seedling Squad", count = 3, minion = "seedling", hp = 2, ai = "chase" },
		},
	},
	{
		rig = "bramble",
		height = 37,
		title = "Hive Keeper of the Hedge",
		lines = { intro = "You smell like cut grass. I HATE that smell.", rage = "Okay, NOW the bees are angry!", death = "Bzzz... bzz... bye." },
		intro = "burst",
		weak = "att_hive_center",
		arena = "hedge",
		dust = { "7A5A30", "9C7A48", "6F9A3E" },
		ring = "FF4D6D",
		moves = {
			{ kind = "homing", name = "Bee Line", count = 3, minion = "bee", hp = 1, speed = 12, life = 6.5, pose = "volley" },
			{ kind = "hedges", name = "Hedge Rows", rows = 3, width = 7, gap = 15, step = 0.6, pose = "stomp" },
			{ kind = "combo", name = "Knuckle Combo", radius = 8, hits = 3, step = 0.45, punish = true, pose = "strike" },
		},
		moves2 = {
			{ kind = "hazard", name = "Thorn Carpet", radius = 8, count = 4, every = 0.25, life = 7, look = "thorns", pose = "volley" },
			{ kind = "safe", name = "Pollen Bomb", spots = 3, r = 8, extra = 1.6, look = "pollen", pose = "stomp" },
		},
	},
	{
		rig = "bunker",
		height = 34,
		title = "The Sand-Trap Shell",
		lines = { intro = "Fore! ...Just kidding. FIVE!", rage = "You hit a nerve. And a spine. Several spines.", death = "Hole... in... one..." },
		intro = "dig",
		weak = "att_flag_wound",
		arena = "bunker",
		dust = { "EBD796", "D8C27C", "F4E4B0" },
		ring = "FFE14D",
		moves = {
			{ kind = "roll", name = "Fore!", count = 3, r = 4.5, speed = 30, look = "golfball", pose = "strike" },
			{ kind = "wave", name = "Sand Wave", waves = 2, band = 3, speed = 22, every = 1.2, pose = "stomp" },
			{ kind = "cone", name = "Rake Swipe", r = 36, angle = 120, punish = true, pose = "strike" },
		},
		moves2 = {
			{ kind = "sink", name = "Sand Traps", radius = 9, count = 3, every = 0.3, life = 9, look = "sand", pose = "volley" },
			{ kind = "burrow", name = "Shell Ambush", radius = 13, chase = 2.4, punish = true, pose = "burrow" },
		},
	},
	{
		rig = "harvest",
		height = 40,
		title = "The Scarecrow's Hunger",
		lines = { intro = "Fresh produce! Oh wait, that's YOU.", rage = "The crows warned me about you!", death = "Should've... stayed... a scarecrow..." },
		intro = "rise",
		weak = "att_nectar",
		arena = "cornfield",
		dust = { "A87A48", "C49A6C", "F0C850" },
		ring = "F0C850",
		moves = {
			{ kind = "fan", name = "Pitchfork Thrust", tines = 3, spread = 18, width = 5, length = 58, punish = true, pose = "strike" },
			{ kind = "dive", name = "Crow Dive", count = 4, r = 4, speed = 46, every = 0.55, look = "crow", pose = "volley" },
			{ kind = "lob", name = "Chaff Storm", radius = 6, count = 7, every = 0.2, ammo = "strand", flight = 1.0, from = "att_nectar", pose = "volley" },
		},
		moves2 = {
			{ kind = "spread", name = "Field Fire", count = 2, r0 = 3, r1 = 15, grow = 5, life = 9, look = "fire", pose = "stomp" },
			{ kind = "rings", name = "Crop Circles", bands = 3, band = 7, pose = "stomp" },
		},
	},
	{
		rig = "sakura",
		height = 40,
		title = "Bloom of a Thousand Teeth",
		lines = { intro = "Such pretty petals. Such pointy teeth.", rage = "Petal season is OVER! Red season begins!", death = "Wilting... so... gracefully..." },
		intro = "bloom",
		weak = "att_lantern_core",
		arena = "sakura",
		dust = { "FFB6D8", "FFFFFF", "C49A6C" },
		ring = "FF9FCD",
		moves = {
			{ kind = "spiral", name = "Petal Spiral", arms = 2, count = 8, r = 5.5, step = 0.11, ammo = "petal", pose = "volley" },
			{ kind = "sweep", name = "Snap Lunge", length = 44, width = 12, punish = true, pose = "strike" },
			{ kind = "orbit", name = "Lantern Wisps", n = 6, r = 3.5, dur = 5.5, spin = 1.2, look = "wisp", pose = "volley" },
		},
		moves2 = {
			{ kind = "ring", name = "Petal Blizzard", inner = 4, outer = 22, pose = "stomp" },
			{ kind = "leap", name = "Blossom Leap", radius = 13, punish = true, pose = "leap" },
		},
	},
	{
		rig = "bog",
		height = 43,
		title = "Terror of the Deep Bog",
		lines = { intro = "Mind the mud. And the vines. And ME.", rage = "The swamp is BOILING and so am I!", death = "Glub... glub... glub." },
		intro = "surface",
		weak = "att_eye",
		arena = "swamp",
		dust = { "7CD45A", "50966A", "C8FFA0" },
		ring = "9DFF5A",
		moves = {
			{ kind = "grid", name = "Geyser Field", tile = 12, gap = 1.3, pose = "stomp" },
			{ kind = "bounce", name = "Slime Hopper", hops = 4, r = 7, hop = 0.85, ammo = "bubble", pool = 3, pose = "volley" },
			{ kind = "stalk", name = "Strangle Vines", times = 4, r = 6, step = 0.75, punish = true, pose = "volley" },
		},
		moves2 = {
			{ kind = "turrets", name = "Swamp Sprouts", count = 3, minion = "sprout", hp = 3, ai = "turret", every = 2.4, life = 18, pose = "stomp" },
			{ kind = "tide", name = "Rising Bog", keep = 16, tin = 3.2, hold = 2.2, tout = 1.4, pose = "stomp" },
		},
	},
	{
		rig = "hollow",
		height = 45,
		title = "The Harvest Moon Reaper",
		lines = { intro = "It's pumpkin season. YOU'RE the pie.", rage = "Light me up? Bad idea. LIGHT ME UP!", death = "Happy... harvest..." },
		intro = "rise",
		weak = "att_ember_heart",
		arena = "pumpkin",
		dust = { "C49A6C", "A87A48", "E8C060" },
		ring = "FFB060",
		moves = {
			{ kind = "swing", name = "Reaper Swing", r = 34, slices = 3, arc = 210, step = 0.16, punish = true, pose = "strike" },
			{ kind = "mines", name = "Jack Bombs", count = 5, radius = 9, every = 0.15, fuse = 2.2, flight = 0.9, ammo = "flame", pose = "volley" },
			{ kind = "dash", name = "Hellfire Dash", width = 11, over = 10, trail = 5, punish = true, pose = "dash" },
		},
		moves2 = {
			{ kind = "adds", name = "Jack-o'-Minions", count = 4, minion = "pumpkin", hp = 2, ai = "boom", blast = 7 },
			{ kind = "mark", name = "Reaper's Mark", r = 11, follow = 3, lock = 1.0, pose = "stomp" },
		},
	},
	{
		rig = "jungle",
		height = 48,
		title = "Guardian of the Lost Temple",
		lines = { intro = "Ten thousand years I waited. For a GARDENER?!", rage = "The runes burn gold! The temple wakes!", death = "The jungle... is yours... gardener." },
		intro = "awaken",
		weak = "att_rune_core",
		arena = "ruins",
		dust = { "7A5A38", "9C7A58", "5A4228" },
		ring = "3FFFD0",
		moves = {
			{ kind = "star", name = "Temple Quake", arms = 6, width = 8, second = 0.8, punish = true, pose = "stomp" },
			{ kind = "meteors", name = "Rune Meteors", count = 10, radius = 8, spread = 3.0, ammo = "glyph", pose = "volley" },
			{ kind = "pillars", name = "Stone Pillars", count = 4, r = 4, stay = 10, pose = "stomp" },
		},
		moves2 = {
			{ kind = "laser", name = "Rune Lasers", aim = 1.6, width = 6, shots = 2, punish = true, pose = "aim" },
			{ kind = "gaze", name = "Titan's Gaze", charge = 3.2, pose = "aim" },
		},
	},
}

-- The difficulty curve (owner, round 2: boss 1 is a gentle tutorial, then each is faster, overlaps more and
-- leaves less time to punish). Index = area.
BossMoves.CURVE = {
	tele = { 1.75, 1.6, 1.5, 1.42, 1.36, 1.3, 1.25, 1.2 }, -- phase-1 warning (phase 2: x TELE2 / TELE)
	gap = { 2.1, 1.8, 1.55, 1.4, 1.25, 1.15, 1.05, 1.0 }, -- rest between moves (x0.6 in phase 2)
	punish = { 3.8, 3.5, 3.2, 3.0, 2.8, 2.7, 2.5, 2.4 }, -- seconds the weak spot stays open
	damage = { 0.6, 0.75, 0.85, 0.95, 1.0, 1.05, 1.1, 1.15 }, -- x BossMoves.DAMAGE
}

-- This area's numbers: { tele, tele2, gap, punish, damage }.
function BossMoves.curve(z: number): { tele: number, tele2: number, gap: number, punish: number, damage: number }
	local C = BossMoves.CURVE
	local i = math.clamp(z, 1, #C.tele)
	local tele = C.tele[i]
	return {
		tele = tele,
		tele2 = math.max(0.85, tele * BossMoves.TELE2 / BossMoves.TELE),
		gap = C.gap[i],
		punish = C.punish[i],
		damage = C.damage[i],
	}
end

function BossMoves.get(z: number): any
	return BossMoves.list[math.clamp(z, 1, #BossMoves.list)]
end


-------------------------------------------------------------------------------------------------------------
-- shapes on the floor (server/Boss hits, client/BossVfx draws): every shape has `type`, `pos` and `land` (s)
--   circle {r} | ring {inner, outer} | strip {dir, length, width} (starts at pos, runs along dir)
--   sector {dir, r, half (radians), inner} | square {size, yaw}
--   safe {r = the arena's radius, safes = {{pos, r}}, shadows = {strip}}: everything EXCEPT the safe spots
-------------------------------------------------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inStrip(s: any, d: Vector3): boolean
	local dir = s.dir :: Vector3
	local along = d:Dot(dir)
	local side = math.abs(d:Dot(Vector3.new(-dir.Z, 0, dir.X)))
	return along >= -2 and along <= s.length and side <= s.width / 2 + 1
end

function BossMoves.inShape(s: any, p: Vector3): boolean
	local d = flat(p - s.pos)
	local t = s.type
	if t == "circle" then
		return d.Magnitude <= s.r + 1
	elseif t == "ring" then
		return d.Magnitude >= s.inner - 1 and d.Magnitude <= s.outer + 1
	elseif t == "strip" then
		return inStrip(s, d)
	elseif t == "sector" then
		local m = d.Magnitude
		if m > s.r + 1 or m < (s.inner or 0) - 1 then
			return false
		end
		if m < 1 then
			return true
		end
		local cosA = math.clamp((d / m):Dot(s.dir), -1, 1)
		return math.acos(cosA) <= s.half + math.atan(1.5 / math.max(m, 1))
	elseif t == "square" then
		local cf = CFrame.Angles(0, s.yaw or 0, 0)
		local l = cf:VectorToObjectSpace(d)
		return math.abs(l.X) <= s.size / 2 + 1 and math.abs(l.Z) <= s.size / 2 + 1
	elseif t == "safe" then
		if d.Magnitude > s.r + 2 then
			return false
		end
		for _, c in s.safes or {} do
			if flat(p - c.pos).Magnitude <= c.r - 0.5 then
				return false
			end
		end
		for _, sh in s.shadows or {} do
			if inStrip(sh, flat(p - sh.pos)) then
				return false
			end
		end
		return true
	end
	return false
end

-------------------------------------------------------------------------------------------------------------
-- things that move (seed puffs, golf balls, crows, beams, sand waves, wisps, the flood, growing fires): `type`,
-- `t0` (server time it starts) and its numbers; both sides work out where it is at any moment from these
--   line  {pts = {Vector3}, speed, r}           a ball along a path (each corner a bounce)
--   beam  {o, a0, w (rad/s), len, width, dur}   a strip turning round o
--   wave  {o, r0, speed, band, rmax}            a ring rolling outwards (jump it)
--   orbit {o, n, a0, w, r0, r1, dur, r}         n balls circling o, spiralling out
--   tide  {o, rmax, rmin, tin, hold, tout}      everything outside a circle that shrinks in, holds, goes back
--   grow  {pos, r0, r1, grow, dur}              a patch that spreads
-------------------------------------------------------------------------------------------------------------
local function pathLen(pts: { Vector3 }): number
	local n = 0
	for i = 2, #pts do
		n += (pts[i] - pts[i - 1]).Magnitude
	end
	return n
end

function BossMoves.moverDur(m: any): number
	local t = m.type
	if t == "line" then
		return pathLen(m.pts) / m.speed
	elseif t == "wave" then
		return (m.rmax - m.r0) / m.speed
	elseif t == "tide" then
		return m.tin + m.hold + m.tout
	end
	return m.dur or 1
end

-- where a line's ball is `dist` studs along its path
function BossMoves.along(pts: { Vector3 }, dist: number): (Vector3, Vector3)
	for i = 2, #pts do
		local seg = pts[i] - pts[i - 1]
		local len = seg.Magnitude
		if dist <= len or i == #pts then
			local dir = if len > 0 then seg / len else Vector3.zAxis
			return pts[i - 1] + dir * math.min(dist, len), dir
		end
		dist -= len
	end
	return pts[1], Vector3.zAxis
end

-- the radius of the dry middle of a flood `t` s in
function BossMoves.tideR(m: any, t: number): number
	if t < m.tin then
		local u = t / m.tin
		return m.rmax + (m.rmin - m.rmax) * (1 - (1 - u) ^ 2)
	elseif t < m.tin + m.hold then
		return m.rmin
	end
	local u = math.clamp((t - m.tin - m.hold) / m.tout, 0, 1)
	return m.rmin + (m.rmax - m.rmin) * u * u
end

-- The shapes a mover covers `t` s after it started ({} before it starts / after it ends).
function BossMoves.moverShapes(m: any, t: number): { any }
	if t < 0 or t > BossMoves.moverDur(m) then
		return {}
	end
	local ty = m.type
	if ty == "line" then
		local pos = BossMoves.along(m.pts, t * m.speed)
		return { { type = "circle", pos = pos, r = m.r } }
	elseif ty == "beam" then
		local a = m.a0 + m.w * t
		return { { type = "strip", pos = m.o, dir = Vector3.new(math.sin(a), 0, math.cos(a)), length = m.len, width = m.width } }
	elseif ty == "wave" then
		local r = m.r0 + m.speed * t
		return { { type = "ring", pos = m.o, inner = r - m.band / 2, outer = r + m.band / 2 } }
	elseif ty == "orbit" then
		local out = {}
		local u = t / m.dur
		local r = m.r0 + (m.r1 - m.r0) * u
		for i = 1, m.n do
			local a = m.a0 + (i - 1) / m.n * math.pi * 2 + m.w * t
			table.insert(out, { type = "circle", pos = m.o + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r), r = m.r })
		end
		return out
	elseif ty == "tide" then
		return { { type = "ring", pos = m.o, inner = BossMoves.tideR(m, t), outer = m.rmax + 30 } }
	elseif ty == "grow" then
		local u = math.clamp(t / m.grow, 0, 1)
		return { { type = "circle", pos = m.pos, r = m.r0 + (m.r1 - m.r0) * (1 - (1 - u) ^ 2) } }
	end
	return {}
end

return BossMoves
