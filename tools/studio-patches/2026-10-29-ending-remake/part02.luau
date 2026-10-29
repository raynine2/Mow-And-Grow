local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end

local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	buf = Instance.new("Folder")
	buf.Name = "ClaudePatchBuf"
	buf.Parent = ss
end
local function put(name, text, want)
	if hashOf(text) ~= want then
		return name .. " garbled"
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
	return nil
end
local bad = {}
local function chk(r)
	if r then
		table.insert(bad, r)
	end
end
chk(put("o36", [======[	-- 3B: footsteps; the Mowers walk up out of the sunset; he turns
	local walk = 4.2
	for i, actor in actors do
		local from = walkFrom(actor.spot.Position, -P.fwd)
		Film.at((i - 1) * 0.15, function()
			actor.walk(from, walk - (i - 1) * 0.15, function()
				FilmAudio.sfx("stepGrass", { volume = 1.3, pitch = 0.9 })
				FilmAudio.sfx("thud", { volume = 0.22, pitch = 0.85 + math.random() * 0.1 })
			end)
		end)
	end
	Film.at(0.9, function()
		m.mood("surprised")
		m.act("idle")
		m.turn(-P.fwd, 1.0)
		m.look(P.cast + UP * 3)
	end)
	view = Film.view()
	ok = Film.run(walk, function(k)
		-- over his shoulder, toward them
		local f = m.face()
		local pos = f + face * 4.6 + P.right * 2.2 + UP * 0.6
		local target = P.cast - P.fwd * (6 - 6 * k) + UP * 3
		return Film.look(Film.clear(pos, target, view), target), Film.mm(50), target
	end, { hand = 0.35, far = 0.2 })
	if not ok then
		return false
	end
	-- 3C: his face: "You... you actually DID it!"
]======], "953 1402749882"))
chk(put("n36", [======[	-- 3C: his face: "You... you actually DID it!" (a medium close-up: his voxel face reads at this size, as in the
	-- opening)
]======], "126 111805614"))
chk(put("o37", [======[		local pos = f - face * (8.5 - 1.2 * inOut(k)) + P.right * 3.2 + UP * 0.8
		return Film.look(Film.clear(pos, f, view), f + face * 14 - UP * 2), Film.mm(45), f
]======], "160 1671502802"))
chk(put("n37", [======[		local pos = f + d0 * (8.5 - 1.0 * inOut(k)) - UP * 0.6
		return Film.look(pos, f - UP * 0.5), Film.mm(45), f
	end, { hand = 0.25 })
	if not ok then
		return false
	end
	-- 3B: THUD. Behind him the Mowers drop out of the sky one after another, each in a puff of dust; he jumps and
	-- spins round (from the side, wide: him in front, them landing behind him)
	local mid = P.cast:Lerp(P.mayorAt, 0.5)
	local sgn = 1
	for _, s in { 1, -1 } do
		local cam = mid + P.right * (s * 15) + P.fwd * 1.5 + UP * 3.2
		if not inside(cam) and sees(cam, mid + UP * 3) and sees(cam, P.cast + UP * 3) and sees(cam, P.mayorAt + UP * 6) then
			sgn = s
			break
		end
	end
	for i, actor in actors do
		Film.at(0.2 + (i - 1) * 0.16, function()
			FilmAudio.sfx("swipe2", { volume = 0.6, pitch = 0.7 + i * 0.05 })
			actor.drop(function(at: Vector3)
				if not Film.playing then
					return
				end
				FilmAudio.sfx("thud", { volume = 1.1, pitch = 0.8 + math.random() * 0.1 })
				Film.shake(0.35, 2.4)
				-- (one small puff each: more hid the Mowers on the opening's contact sheet)
				HitFx.play("bossSlamDust", at, Color3.fromRGB(196, 168, 120), false)
				actor.play("emote")
			end)
		end)
	end
	Film.at(0.7, function()
		m.hop(0.7)
		m.mood("surprised")
		m.act("shock")
		m.turn(-P.fwd, 0.45)
		m.look(P.cast + UP * 3)
		FilmAudio.sfx("whomp", { volume = 0.7, pitch = 1.5 })
	end)
	ok = Film.run(2.6, function(k)
		local pos = mid + P.right * (sgn * (15 - 1.5 * k)) + P.fwd * 1.5 + UP * 3.2
		return Film.look(pos, mid + UP * 3.2), Film.mm(26), mid
]======], "1538 1834177469"))
chk(put("o38", [======[	local ok = Film.run(4.2, function(k)
]======], "38 1223840263"))
chk(put("n38", [======[	-- 3A: the Mayor alone on his soapbox at sunset, looking out over his meadow, waiting (in front of him, off to one
	-- side, on his face)
	local head = m.face()
	local yaw = 30
	for _, y in { 30, -30, 45, -45, 20, -20, 60, -60 } do
		local cam = head + turn(face, y) * 8.5 - UP * 0.6
		if not inside(cam) and sees(cam, head) then
			yaw = y
			break
		end
	end
	local d0 = turn(face, yaw)
	local ok = Film.run(2.6, function(k)
]======], "428 1226445160"))
chk(put("o39", [======[	-- 3A: the Mayor alone on his soapbox at sunset, looking out over his mowed meadow
	local view = Film.view()
]======], "110 1500795605"))
chk(put("n39", [======[]======], "0 0"))
chk(put("o40", [======[	bed("amb", "ambWind", 1, 1.5)
	local face = P.fwd
]======], "51 2027559271"))
chk(put("n40", [======[	bed("amb", "ambWind", 1, 1.5)
	stopCue("flight", 3)
	local face = P.fwd
]======], "73 656077605"))
chk(put("o41", [======[	Film.glow(0.3, 30, 0.2)
	bed("amb", "ambWind", 1, 1.5)
]======], "56 1984082277"))
chk(put("n41", [======[	Film.glow(0.3, 30, 0.2)
	Film.vignette(0.45, 0.2)
	bed("amb", "ambWind", 1, 1.5)
]======], "82 707580070"))
chk(put("o42", [======[local function walkFrom(spot: Vector3, back: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	local s = workspace:FindFirstChild("IntroSet")
	if s then
		table.insert(skip, s)
	end
	local w = workspace:FindFirstChild("World")
	local g = w and w:FindFirstChild("Grass")
	if g then
		table.insert(skip, g)
	end
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(skip, pl.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	for _, dist in { 15, 11, 8, 5 } do
		if not workspace:Raycast(spot + UP * 2.5, back * dist, params) then
			return spot + back * dist
		end
	end
	return spot + back * 3
end

]======], "723 980680338"))
chk(put("n42", [======[]======], "0 0"))
chk(put("o43", [======[-- III. HOMECOMING
]======], "19 1468242472"))
chk(put("n43", [======[-- III. HOMECOMING (29 Oct: no walking; the Mowers come home the way they came in the opening, out of the sky)
]======], "111 1337662716"))
chk(put("o44", [======[	table.insert(pts, P.camp + UP * 58 - P.fwd * 40)
	local legs = #pts - 1
	local named = {}
	local len = 13
	return Film.run(len, function(k)
		local e = cruise(k)
		local pos = Film.spline(pts, e)
		local ahead = Film.spline(pts, math.min(1, e + 0.06))
		local i = math.clamp(math.floor(e * legs) + 1, 1, legs)
		local u = e * legs - (i - 1)
		local area = P.areas[i]
		if area and not named[i] and u > 0.15 then
			named[i] = true
			IntroUi.lowerThird(string.upper(area.name), "MOWED", GREEN, 1.6)
			FilmAudio.sfx("rareChime", { volume = 0.35, pitch = 0.8 + i * 0.07 })
		end
		-- bank into the turns
		local d1 = flat(ahead - pos)
		local d2 = flat(Film.spline(pts, math.min(1, e + 0.12)) - ahead)
		local bank = 0
		if d1.Magnitude > 0.1 and d2.Magnitude > 0.1 then
			bank = math.clamp(d1.Unit:Cross(d2.Unit).Y * 60, -12, 12)
		end
		return Film.look(pos, ahead - UP * 62, bank), Film.mm(20), ahead - UP * 60
	end, { hand = 0.25 })
]======], "938 1948195637"))
chk(put("n44", [======[	guardianOff()
	return true
]======], "28 1205326720"))
chk(put("o45", [======[	local pts = {}
	for i, area in P.areas do
		table.insert(pts, area.pos + UP * (78 - (i % 2) * 14))
]======], "100 2045967802"))
chk(put("n45", [======[	guardianShown = true
	for i, c in cameos do
		local mv = BossMoves.get(c.z)
		local def = Config.ZONES[c.z]
		local last = i == #cameos
		BossView.show(mv.rig, CFrame.lookAt(c.feet, c.feet + c.toCam), guardianScale(c.z), mv)
		-- (it stands tall, then bows: client/BossView's "freed" without the kneeling)
		BossView.act("freed", { free = -1, nod = 0.3, fade = 99 })
		Film.at(0.1, function()
			local name = if def and def.name then def.name else ("Area " .. c.z)
			local who = if def and def.boss then def.boss.name else mv.rig
			IntroUi.lowerThird(string.upper(name), who .. " ~ free", GREEN, if last then 1.6 else 1.0)
			FilmAudio.sfx("rareChime", { volume = 0.4, pitch = 0.8 + i * 0.08 })
		end)
		local H = c.H
		local roll = if i % 2 == 0 then 4 else -4
		local ok = Film.run(if last then 1.7 else CAMEO, function(k)
			local h = BossView.attWorld("att_head_center") or (c.feet + UP * (H * 0.8))
			local pos = h + c.toCam * (H * (1.05 - 0.08 * k)) + c.side * (H * 0.28) - UP * (H * 0.12)
			return Film.look(pos, h - UP * (H * 0.04), roll * (1 - k)), Film.mm(38), h
		end, { cut = if i > 1 then "whip" else nil, hand = 0.25 })
		if not ok then
			return false
		end
]======], "1178 1175373943"))
chk(put("o46", [======[	bed("amb", "ambBirds", 1.2, 2)
	Film.at(1.0, function()
		speak("E2", true)
]======], "77 246574589"))
chk(put("n46", [======[	bed("amb", "ambBirds", 1.2, 2)
	Film.at(0.3, function()
		speak("E2", true)
]======], "77 1279627992"))
chk(put("o47", [======[local function valleyScenes(P: Plan): boolean
	Film.light(LOOKS.day, 0)
	Film.glow(0.25, 28, 0.6)
	Film.grade("hero", 0.8)
	stopCue("calm", 2.5)
	cue("flight", "flightMusic", { fade = 2.5 })
]======], "191 110051821"))
chk(put("n47", [======[-- Where a guardian stands (its arena's middle) and its camera (clear of the scenery, the sun on its face).
local function cameoPlan(P: Plan, z: number, sun: Vector3): Cameo
	local H = BossMoves.get(z).height
	local feet = ground(arenaOf(z))
	local base = unit(flat(P.camp - feet), P.fwd)
	local best: Cameo = { z = z, feet = feet, toCam = base, side = base:Cross(UP), H = H }
	local bestScore = -math.huge
	local h = feet + UP * (H * 0.8)
	for _, y in YAWS do
		local toCam = turn(base, y)
		for _, s in { 1, -1 } do
			local side = toCam:Cross(UP) * s
			local cam = h + toCam * (H * 1.05) + side * (H * 0.28) - UP * (H * 0.12)
			local score = 2 * math.max(0, toCam:Dot(sun))
			if inside(cam) then
				score -= 8
			end
			if sees(cam, h) then
				score += 3
			end
			for _, t in { feet + UP * (H * 0.45), h + side * (H * 0.35), h - side * (H * 0.35) } do
				if sees(cam, t) then
					score += 1
				end
			end
			if score > bestScore then
				bestScore = score
				best = { z = z, feet = feet, toCam = toCam, side = side, H = H }
			end
		end
	end
	return best
end

local function valleyScenes(P: Plan, cameos: { Cameo }): boolean
	Film.light(LOOKS.golden, 0)
	Film.grade("dream", 0)
	Film.glow(0.25, 28, 0.3)
	Film.vignette(0.35, 0.3)
	stopCue("calm", 2)
	cue("flight", "flightMusic", { fade = 1.5 })
]======], "1309 911006060"))
chk(put("o48", [======[	return v * (k - a / 2)
]======], "24 662603959"))
chk(put("n48", [======[	for i = #zs, 2, -1 do
		local j = math.random(1, i)
		zs[i], zs[j] = zs[j], zs[i]
	end
	local list = {}
	for i = 1, math.min(3, #zs) do
		table.insert(list, zs[i])
	end
	if n > 1 then
		table.insert(list, 1)
	end
	return list
]======], "227 1324331024"))
chk(put("o49", [======[-- (owner, 28 Oct: the area names "overlap when you show everything") the flight keeps one speed over the areas and
-- eases only at its two ends, so every area gets the same moment (about 1.4 s) for its name; the names come one at
-- a time (client/IntroUi.lowerThird). A cubic ease had raced over the middle ones half a second apart.
local function cruise(k: number): number
	local a = 0.14 -- (the share of the flight spent speeding up, and slowing down)
	k = math.clamp(k, 0, 1)
	local v = 1 / (1 - a)
	if k < a then
		return v * k * k / (2 * a)
	elseif k > 1 - a then
		local r = 1 - k
		return 1 - v * r * r / (2 * a)
]======], "624 1958617135"))
chk(put("n49", [======[type Cameo = { z: number, feet: Vector3, toCam: Vector3, side: Vector3, H: number }
local CAMEO = 1.15 -- seconds each (the King's is longer)

-- Three of the guardians between the first and the last, at random (a different three each time), then the King.
local function cameoZones(): { number }
	local n = #Config.ZONES
	local zs = {}
	for z = 2, n - 1 do
		table.insert(zs, z)
]======], "380 1572355968"))
chk(put("o50", [======[-- II. THE VALLEY BREATHES: the flight back over every area to the village
]======], "75 349421065"))
chk(put("n50", [======[-- II. THE VALLEY BREATHES (owner, 29 Oct, of both films: "the camera just pans to the ground": the flight back over
-- every area looked down at the ground for thirteen seconds): the guardians back home in their own lands, free, in
-- their own colours, one after another, each standing tall and bowing as its land's name comes up (the opening
-- showed the pink falling on them). The Dandelion King last: the one it fell on first.
]======], "433 357480984"))
chk(put("o51", [======[	if mote then
		mote:Destroy()
]======], "31 967615398"))
chk(put("n51", [======[	if light then
		light:Destroy()
]======], "33 1352004356"))
return "part 2/5 (edits 36-51): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
