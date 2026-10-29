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
chk(put("o62", [======[-- 1C without a guardian (or after it): a light rises from where it stood and the sun breaks through
local function lightRises(feet: Vector3, camAt: Vector3, len: number): boolean
	local mote = spark(feet + UP * 1, Color3.fromRGB(255, 244, 196), 0.9)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 236, 180)
	light.Range = 22
	light.Brightness = 3
	light.Parent = mote
	TweenService:Create(mote, TweenInfo.new(len, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = feet + UP * 70, Size = Vector3.one * 0.3 }):Play()
	FilmAudio.sfx("swell", { volume = 0.9 })
	FilmAudio.sfx("rareChime", { volume = 0.5, pitch = 0.8 })
	-- (VFX Forge) the light's trail, the pillar where it rose from, then the sun breaking through
	FilmVfx.play("GoldRise", mote.CFrame, { follow = mote })
	FilmVfx.play("GoldPillar", CFrame.new(feet))
	Film.at(len * 0.6, function()
		Film.light({ ExposureCompensation = 0.45 }, 1.4)
		Film.glow(0.55, 40, 1.2)
		FilmAudio.sfx("rareChime", { volume = 0.6, pitch = 1.1 })
		FilmVfx.play("SunBreak", CFrame.lookAt(feet + UP * 85, camAt))
	end)
	local view = Film.view()
	local ok = Film.run(len, function(k)
		local e = inOut(k)
		local target = mote.Position:Lerp(feet + UP * (8 + 50 * e), 0.5)
		return Film.look(Film.clear(camAt - UP * (0.6 * e), feet + UP * 2, view), target), Film.mm(35 - 10 * e), mote.Position
	end, { hand = 0.3 })
	mote:Destroy()
	return ok
]======], "1421 1499573242"))
chk(put("n62", [======[-- Where the last guardian kneels and where the Mowers stand in front of it (in its arena), turned so that all of the
-- scene's shots see them (the ruins' pillars, the trees round the arena: the scenery's boxes), with the morning sun
-- on its face. `d`: from the guardian toward the Mowers (and the cameras behind them); `s`: the side 1C films from.
type ArenaPlan = { feet: Vector3, d: Vector3, side: Vector3, s: number, H: number, party: Vector3 }
local function arenaPlan(P: Plan): ArenaPlan
	local n = #Config.ZONES
	local H = BossMoves.get(n).height
	local feet = ground(P.arena)
	local toCamp = unit(flat(P.camp - feet), P.fwd)
	local sun = sunAt(LOOKS.morning.ClockTime)
	local chest, head, high = feet + UP * (H * 0.4), feet + UP * (H * 0.65), feet + UP * (H * 1.05)
	local best: ArenaPlan = { feet = feet, d = toCamp, side = toCamp:Cross(UP), s = 1, H = H, party = ground(feet + toCamp * (H * 0.8)) }
	local bestScore = -math.huge
	for _, y in YAWS do
		local d = turn(toCamp, y)
		local side = d:Cross(UP)
		local pc = ground(feet + d * (H * 0.8))
		local score = 2 * math.max(0, d:Dot(sun))
		-- the Mowers stand on the arena's floor, not up a step or in a pillar
		if math.abs(pc.Y - feet.Y) > 4 then
			score -= 6
		end
		for _, k in { -6, 0, 6 } do
			local p = pc + side * k
			if blocked(p + UP * 0.6, p + UP * 6) then
				score -= 4
			end
		end
		-- 1A and 1D: low behind them
		for _, cam in { pc + d * 8 + side * 2.2 + UP * 2.6, pc + d * 10.8 - side * 2.4 + UP * 1.4 } do
			if inside(cam) then
				score -= 6
			end
			for _, t in { chest, head, high } do
				if sees(cam, t) then
					score += 1
				end
			end
		end
		-- 1B: close on its face
		local camB = head + d * (H * 0.6) + side * (H * 0.12)
		if inside(camB) then
			score -= 4
		elseif sees(camB, head) then
			score += 1
		end
		-- 1C: from one side or the other, wide
		local mid = feet:Lerp(pc, 0.5)
		local bestC, sC = -math.huge, 1
		for _, s in { 1, -1 } do
			local camC = mid + side * (s * H * 1.15) + d * (H * 0.1) + UP * (H * 0.2)
			local sc = if inside(camC) then -4 else 0
			for _, t in { chest, head, pc + UP * 2.5 } do
				if sees(camC, t) then
					sc += 1
				end
			end
			if sc > bestC then
				bestC, sC = sc, s
			end
		end
		score += bestC
		if score > bestScore then
			bestScore = score
			best = { feet = feet, d = d, side = side, s = sC, H = H, party = pc }
		end
	end
	return best
]======], "2393 269167065"))
chk(put("o63", [======[			local fx = g.Parent and FilmVfx.play("PinkEye", g.CFrame, { follow = g, scale = H / 14 })
]======], "93 832000371"))
chk(put("n63", [======[			local fx = g.Parent and FilmVfx.play("PinkEye", g.CFrame, { follow = g, scale = H / 22 })
]======], "93 858782480"))
chk(put("o64", [======[		if i == 1 then
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 40, 170)
			l.Range = H * 0.6
			l.Brightness = 3
			l.Shadows = false
			l.Parent = g
		end
]======], "183 262250313"))
chk(put("n64", [======[]======], "0 0"))
chk(put("o65", [======[	for i in names do
		local g = spark(Vector3.zero, Color3.fromRGB(255, 40, 170), math.max(0.7, H * 0.045))
]======], "107 712391079"))
chk(put("n65", [======[	for _ in names do
		local g = spark(Vector3.zero, Color3.fromRGB(255, 40, 170), math.max(0.5, H * 0.03))
]======], "106 1878216535"))
chk(put("o66", [======[-- the glitch's pink in its eyes (glowing balls on its eye points, every frame)
]======], "80 1624680270"))
chk(put("n66", [======[-- the glitch's pink in its eyes (small glowing balls on its eye points, every frame). (29 Oct, as the opening's: with
-- a light on them and bigger, the guardians' faces read as pink blobs on the contact sheet.)
]======], "213 2100103267"))
chk(put("o67", [======[-- (owner, 28 Oct evening: the ending began on "just a blank ground") 1A: the last guardian kneels in its arena,
-- beaten, the glitch still in it (its corrupted colours, pink eyes, twitching). 1B: the pink tears out of it in a
-- spray of glitch blocks [an impact frame, in gold]: its own colours come back and it straightens up. 1C: it bows its
-- head to us... and goes up into the sky as light, and the sun breaks through. (If a fight's boss is still in
-- client/BossView, it's left alone: just the light rising.)
]======], "519 1266840875"))
chk(put("n67", [======[-- (owner, 28 Oct evening: the ending began on "just a blank ground"; 29 Oct: "do the same u did for intro for the
-- outro") 1A: in its arena the last guardian kneels in front of the Mowers, beaten, the glitch still in it (its
-- corrupted colours, pink eyes, twitching); low behind the Mowers we creep in. 1B: close on its face the pink tears
-- out of it in a spray of glitch blocks [an impact frame, in gold]: its own colours come back. 1C: from the side,
-- wide: it stands up tall over the Mowers... and bows its head to them; they cheer. 1D: low behind them again: it
-- goes up as light and the sun breaks through. (If a fight's boss is still in client/BossView, it's left alone:
-- just the Mowers and the light.)
]======], "723 67650719"))
chk(put("o68", [======[	local arenas = w and w:FindFirstChild("Arenas")
	local a = arenas and arenas:FindFirstChild("Arena" .. n)
	local arena = if a and a:IsA("Model") then a:GetPivot().Position else Config.zoneCentre(n)
]======], "199 829905722"))
chk(put("n68", [======[	local arena = arenaOf(n)
]======], "26 142533758"))
chk(put("o69", [======[-------------------------------------------------------------------------------------------------------------
type Plan = { arena: Vector3, areas: { { pos: Vector3, name: string } }, camp: Vector3, fwd: Vector3, right: Vector3, cast: Vector3, mayorAt: Vector3, sprout: Vector3 }
]======], "279 1999811245"))
chk(put("n69", [======[-------------------------------------------------------------------------------------------------------------
-- Where area z's guardian was fought: its arena's middle.
local function arenaOf(z: number): Vector3
	local w = workspace:FindFirstChild("World")
	local arenas = w and w:FindFirstChild("Arenas")
	local a = arenas and arenas:FindFirstChild("Arena" .. z)
	if a and a:IsA("Model") then
		return a:GetPivot().Position
	end
	local at = w and w:GetAttribute("Arena" .. z)
	if typeof(at) == "Vector3" then
		return at
	end
	return Config.zoneCentre(z)
end

type Plan = { arena: Vector3, areas: { { pos: Vector3, name: string } }, camp: Vector3, fwd: Vector3, right: Vector3, cast: Vector3, mayorAt: Vector3, sprout: Vector3 }
]======], "730 1901997856"))
chk(put("o70", [======[			end
		end
	end
	return score
]======], "32 703294129"))
chk(put("n70", [======[			end
		end
	end
	if inside(p) then
		score -= 6
	end
	return score
]======], "69 1211103865"))
chk(put("o71", [======[			if not Film.sees(p + (cf * CFrame.Angles(0, math.rad(a), 0)).LookVector * 30, p) then
]======], "89 1630390468"))
chk(put("n71", [======[			if not sees(p + (cf * CFrame.Angles(0, math.rad(a), 0)).LookVector * 30, p) then
]======], "84 1423310099"))
chk(put("o72", [======[		if Film.sees(p, t) then
]======], "26 1127429189"))
chk(put("n72", [======[		if sees(p, t) then
]======], "21 1353450533"))
chk(put("o73", [======[-- degrees either side of the first target) with something solid within 30 studs of the lens. (Studio's test, 28 Oct:
-- the hole half behind a roof, and half the frame filled by whatever stood beside the camera.)
]======], "214 338867709"))
chk(put("n73", [======[-- degrees either side of the first target) with something solid within 30 studs of the lens, 6 off if it stands
-- inside something. (Studio's test, 28 Oct: the hole half behind a roof, and half the frame filled by whatever
-- stood beside the camera.)
]======], "254 1285361409"))
return "part 4/5 (edits 62-73): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
