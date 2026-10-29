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
chk(put("o1", [======[		run(film, P, c)
]======], "18 416316732"))
chk(put("n1", [======[		run(film, P, c, A, cameos)
]======], "29 562259249"))
chk(put("o2", [======[	local c: Cast = { m = IntroCast.mayor(P.mayorAt, P.fwd), actors = IntroCast.party(P.cast, P.fwd, P.right) } -- (he faces out over his meadow at first)
]======], "152 1566670300"))
chk(put("n2", [======[	-- (he faces out over his meadow at first; the Mowers at the arena face the last guardian)
	local c: Cast = { m = IntroCast.mayor(P.mayorAt, P.fwd), actors = IntroCast.party(P.cast, P.fwd, P.right), arena = IntroCast.party(A.party, -A.d, (-A.d):Cross(UP)) }
]======], "259 1634409016"))
chk(put("o3", [======[	streamIn(spots)
	Babble.prepare()
]======], "35 1107468702"))
chk(put("n3", [======[	streamIn(spots)
	-- the scenery round the camp and the arenas, as boxes (the cameras keep out of it), and the shots' plans
	local places = { { at = P.camp, r = 260 }, { at = P.arena, r = 150 } }
	for _, z in zones do
		table.insert(places, { at = arenaOf(z), r = 120 })
	end
	Film.refreshSight() -- (what the plans' raycasts look through: the characters, the grass, the film's sets)
	scenery = sceneryBoxes(places)
	local A = arenaPlan(P)
	local sun = sunAt(LOOKS.golden.ClockTime)
	local cameos: { Cameo } = {}
	for _, z in zones do
		table.insert(cameos, cameoPlan(P, z, sun))
	end
	Babble.prepare()
]======], "603 881775364"))
chk(put("o4", [======[	end
	streamIn(spots)
]======], "22 726235918"))
chk(put("n4", [======[	end
	for _, z in zones do
		table.insert(spots, arenaOf(z))
	end
	-- (the guardians' models, their paint and meshes, load while the cover is up)
	local models = ReplicatedStorage:FindFirstChild("BossModels")
	if models then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(models:GetChildren())
			end)
		end)
	end
	streamIn(spots)
]======], "361 2022238925"))
chk(put("o5", [======[	local P = plan()
	local spots = { P.arena, P.camp, P.sprout }
]======], "63 1835354536"))
chk(put("n5", [======[	local P = plan()
	local zones = cameoZones()
	local spots = { P.arena, P.camp, P.sprout }
]======], "91 1084516677"))
chk(put("o6", [======[	FilmAudio.begin({ "calmMusic", "flightMusic", "partyMusic", "dreadMusic", "creditsMusic", "heartbeat", "swell", "boom", "crowd", "applause", "impact", "slam", "bigHit", "rumble", "growl", "growl2", "suck", "drone", "revStop", "revBuild", "eerie", "servo", "whomp", "thud", "sting", "bhPull", "roar", "riseDark" })
]======], "315 44621326"))
chk(put("n6", [======[	FilmAudio.begin({ "calmMusic", "flightMusic", "partyMusic", "dreadMusic", "creditsMusic", "heartbeat", "swell", "boom", "crowd", "applause", "impact", "slam", "bigHit", "rumble", "growl", "growl2", "suck", "drone", "revStop", "revBuild", "eerie", "servo", "whomp", "thud", "sting", "bhPull", "roar", "riseDark", "swipe2", "rareChime" })
]======], "338 831522297"))
chk(put("o7", [======[	if not valleyScenes(P) then
]======], "29 680170899"))
chk(put("n7", [======[	if not valleyScenes(P, cameos) then
]======], "37 140779772"))
chk(put("o8", [======[	if not lastBladeScenes(P) then
]======], "32 1822524188"))
chk(put("n8", [======[	local ok = lastBladeScenes(P, A, c.arena)
	-- (the Mowers at the arena go; the camp's come home later, out of the sky)
	for _, a in c.arena do
		a.model:Destroy()
	end
	table.clear(c.arena)
	if not ok then
]======], "207 893083354"))
chk(put("o9", [======[local function film(P: Plan, c: Cast): boolean
]======], "47 145381883"))
chk(put("n9", [======[local function film(P: Plan, c: Cast, A: ArenaPlan, cameos: { Cameo }): boolean
]======], "80 165457587"))
chk(put("o10", [======[			actor.update(dt, s)
		end
	end)
end
]======], "39 937201903"))
chk(put("n10", [======[			actor.update(dt, s)
		end
		for _, actor in c.arena do
			actor.update(dt, s)
		end
	end)
end
]======], "97 455037441"))
chk(put("o11", [======[type Cast = { m: IntroCast.Mayor, actors: { IntroCast.Actor } }
]======], "64 549805225"))
chk(put("n11", [======[type Cast = { m: IntroCast.Mayor, actors: { IntroCast.Actor }, arena: { IntroCast.Actor } }
]======], "92 1421062371"))
chk(put("o12", [======[	teaserGen += 1
	if ungrade then
]======], "33 1407018939"))
chk(put("n12", [======[	teaserGen += 1
	scenery = nil
	if ungrade then
]======], "48 1919963515"))
chk(put("o13", [======[							if not Film.sees(cam, sky + UP * h) then
]======], "48 1467997373"))
chk(put("n13", [======[							if not sees(cam, sky + UP * h) then
]======], "43 926125750"))
chk(put("o14", [======[						if not Film.sees(cam + UP * 0.5, cam + UP * 60) then
]======], "59 241512300"))
chk(put("n14", [======[						if not sees(cam + UP * 0.5, cam + UP * 60) then
]======], "54 1953479112"))
chk(put("o15", [======[							if not Film.sees(cam, at + UP * h) then
]======], "47 1592234635"))
chk(put("n15", [======[							if not sees(cam, at + UP * h) then
]======], "42 1089839243"))
chk(put("o16", [======[						if not Film.sees(at + off + UP * 1.5, at + off + UP * 70) then
]======], "69 1900209972"))
chk(put("n16", [======[						if not sees(at + off + UP * 1.5, at + off + UP * 70) then
]======], "64 1321141835"))
chk(put("o17", [======[		local pos = camPos + P.right * (2 * (1 - inOut(k)))
]======], "54 9379442"))
chk(put("n17", [======[		local pos = camPos + P.right * (s5 * 2 * (1 - inOut(k)))
]======], "59 1679840126"))
chk(put("o18", [======[	m.turn(P.right, 0.5)
]======], "22 54645576"))
chk(put("n18", [======[	m.turn(P.right * s5, 0.5)
]======], "27 1275120132"))
chk(put("o19", [======[		actor.turnTo(P.right)
]======], "24 1288843219"))
chk(put("n19", [======[		actor.turnTo(P.right * s5)
]======], "29 1606609752"))
chk(put("o20", [======[	local camPos = mid2 + P.right * 17 + UP * 4.6
]======], "47 69455452"))
chk(put("n20", [======[	local s5 = clearSide(P, mid2, 17, 4.6)
	local camPos = mid2 + P.right * (s5 * 17) + UP * 4.6
]======], "94 682427982"))
chk(put("o21", [======[		return Film.look(pos, target, -4), Film.mm(24), sky
]======], "54 1571783540"))
chk(put("n21", [======[		return Film.look(pos, target, -4 * sideB), Film.mm(24), sky
]======], "62 1350847949"))
chk(put("o22", [======[		local pos = f - P.fwd * 7 + P.right * 2.6 - UP * 3.4
]======], "55 352872445"))
chk(put("n22", [======[		local pos = f - P.fwd * 7 + P.right * (2.6 * sideB) - UP * 3.4
]======], "65 2075149335"))
chk(put("o23", [======[	ok = Film.run(4.8, function(k)
]======], "32 675584365"))
chk(put("n23", [======[	local f0 = m.face()
	local sideB = if inside(f0 - P.fwd * 7 + P.right * 2.6 - UP * 3.4) then -1 else 1
	ok = Film.run(4.2, function(k)
]======], "136 1691099453"))
chk(put("o24", [======[			firework(sky + P.right * math.random(-30, 30) + P.fwd * math.random(-10, 12) + UP * math.random(-5, 9), i == 8)
]======], "115 1582915564"))
chk(put("n24", [======[			firework(sky + P.right * math.random(-30, 30) + P.fwd * math.random(-10, 12) + UP * math.random(-5, 9), i == 6)
]======], "115 1582913642"))
chk(put("o25", [======[	for i = 0, 8 do
]======], "17 865665643"))
chk(put("n25", [======[	for i = 0, 6 do
]======], "17 863818601"))
chk(put("o26", [======[	-- 4B: dusk; fireworks over the village, lighting everyone up; low, looking up past the Mayor
]======], "95 520915156"))
chk(put("n26", [======[	-- 4B: dusk; fireworks over the camp, lighting everyone up; low, looking up past the Mayor
]======], "92 1550984603"))
chk(put("o27", [======[	local ok = Film.run(4.6, function(k)
		local pos = mid + P.right * (17 - 2 * k) - P.fwd * 2 + UP * (2.6 + k)
]======], "110 1311197030"))
chk(put("n27", [======[	local ok = Film.run(3.8, function(k)
		local pos = mid + P.right * (s4 * (17 - 2 * k)) - P.fwd * 2 + UP * (2.6 + k)
]======], "117 663685139"))
chk(put("o28", [======[	local mid = P.cast:Lerp(P.mayorAt, 0.5)
]======], "41 1151075817"))
chk(put("n28", [======[]======], "0 0"))
chk(put("o29", [======[	end)
	Film.at(2.6, function()
		m.act("cheer")
]======], "48 981588692"))
chk(put("n29", [======[	end)
	Film.at(2.4, function()
		m.act("cheer")
]======], "48 299459281"))
chk(put("o30", [======[		-- (VFX Forge's confetti cannons by the party; the old screen confetti if they're missing)
		local spot = ground(P.cast:Lerp(P.mayorAt, 0.5))
		if not FilmVfx.play("ConfettiPop", CFrame.lookAt(spot, spot + P.right)) then
]======], "223 1754068171"))
chk(put("n30", [======[		-- (VFX Forge's confetti cannons by the party, firing toward the camera's side; the old screen confetti if
		-- they're missing)
		local spot = ground(mid)
		if not FilmVfx.play("ConfettiPop", CFrame.lookAt(spot, spot + P.right * s4)) then
]======], "242 1994171015"))
chk(put("o31", [======[	end
	Film.at(1.0, function()
]======], "30 260162218"))
chk(put("n31", [======[	end
	local mid = P.cast:Lerp(P.mayorAt, 0.5)
	local s4 = clearSide(P, mid, 17, 2.6, 2)
	Film.at(1.0, function()
]======], "113 1433635240"))
chk(put("o32", [======[

local function partyScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
]======], "95 353335200"))
chk(put("n32", [======[

-- Which side of the camp's line (P.right, +1 or -1) a camera `dist` studs out to the side of `at` sees it from.
local function clearSide(P: Plan, at: Vector3, dist: number, up: number, back: number?): number
	for _, s in { 1, -1 } do
		local cam = at + P.right * (s * dist) - P.fwd * (back or 0) + UP * up
		if not inside(cam) and sees(cam, at + UP * 3) then
			return s
		end
	end
	return 1
end

local function partyScenes(P: Plan, m: IntroCast.Mayor, actors: { IntroCast.Actor }): boolean
]======], "493 337291452"))
chk(put("o33", [======[		local pos = f - P.fwd * (5.4 - 0.9 * out(k)) - P.right * 1.2 - UP * 0.25
		return Film.look(pos, f - UP * 0.15), Film.mm(70), f
]======], "130 1999432128"))
chk(put("n33", [======[		local pos = f - P.fwd * (8.5 - 1.0 * out(k)) - P.right * 1.8 - UP * 0.5
		return Film.look(pos, f - UP * 0.2), Film.mm(45), f
]======], "128 1665403180"))
chk(put("o34", [======[	end)
	return Film.run(3.4, function(k)
		local f = m.face()
]======], "61 1142763128"))
chk(put("n34", [======[	end)
	return Film.run(2.8, function(k)
		local f = m.face()
]======], "61 255882404"))
chk(put("o35", [======[	end)
	Film.at(1.6, function()
		m.hop(0.5)
]======], "44 1841994453"))
chk(put("n35", [======[	end)
	Film.at(1.5, function()
		m.hop(0.5)
]======], "44 1104007821"))
return "part 1/5 (edits 1-35): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
