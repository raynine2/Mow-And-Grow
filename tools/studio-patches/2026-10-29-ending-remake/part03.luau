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
chk(put("o52", [======[	local head = feet + UP * (H * 0.8)
	ok = Film.run(4.6, function(k)
		local m = mote
		local up = if m then m.Position else head
		local e = Film.smooth((k - 0.35) / 0.65)
		local target = head:Lerp(up, e)
		return Film.look(lowCam - side * (H * 0.1 * k), target, -2), Film.mm(30 - 6 * e), target
]======], "297 785961377"))
chk(put("n52", [======[	Film.at(2.9, function()
		Film.flash(Color3.fromRGB(255, 246, 222), 0.9, 0.7)
	end)
	local ok = Film.run(3.4, function(k)
		local look = feet + UP * (H * (0.5 + 0.35 * inOut(k)))
		return Film.look(camAt + d * (0.8 * k), look, -2), Film.mm(20), look
]======], "251 133534544"))
chk(put("o53", [======[		FilmVfx.play("SunBreak", CFrame.lookAt(chest + UP * 85, lowCam)) -- (VFX Forge: the sun breaking through)
]======], "108 1475002468"))
chk(put("n53", [======[		FilmVfx.play("SunBreak", CFrame.lookAt(chest + UP * 85, camAt)) -- (VFX Forge: the sun breaking through)
		for i, a in mowers do
			task.delay((i - 1) * 0.1, function()
				a.look(feet + UP * (H * 1.4))
				a.play("wave")
			end)
		end
]======], "238 1326874632"))
chk(put("o54", [======[	end)
	Film.at(2.4, function()
		Film.light({ ExposureCompensation = 0.45 }, 1.4)
]======], "82 293781425"))
chk(put("n54", [======[	end)
	Film.at(1.3, function()
		Film.light({ ExposureCompensation = 0.45 }, 1.4)
]======], "82 310612192"))
chk(put("o55", [======[		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 236, 180)
		light.Range = 26
		light.Brightness = 4
		light.Parent = m
		TweenService:Create(m, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = chest + UP * 80, Size = Vector3.one * 0.4 }):Play()
		mote = m
]======], "317 747954088"))
chk(put("n55", [======[		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 236, 180)
		pl.Range = 30
		pl.Brightness = 4
		pl.Shadows = false
		pl.Parent = m
		TweenService:Create(m, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = chest + UP * 90, Size = Vector3.one * 0.4 }):Play()
		light = m
]======], "324 841551978"))
chk(put("o56", [======[	ok = Film.run(2.2, function(k)
		local pos = feet + d * (H * (K[2] + 0.1 * k)) + side * (H * 0.15) + UP * (H * 0.6)
		return Film.look(pos, feet + UP * (H * 0.62)), Film.mm(40), chest
	end, { hand = 0.35 })
	if not ok then
		return false
	end
	-- 1C: it bows its head to us... and goes up into the sky as light; the sun breaks through
	Film.at(0.3, function()
		IntroUi.lowerThird(string.upper(P.areas[1].name), "The last guardian is free.", GREEN, 3.6)
	end)
	Film.at(0.6, function()
		speak("E1", true)
	end)
	local mote: Part? = nil
	Film.at(1.6, function()
]======], "562 2030595160"))
chk(put("n56", [======[	local camAt = pc + d * 10.8 - side * gap + UP * 1.4
	local light: Part? = nil
	Film.at(0.45, function()
]======], "105 813080068"))
chk(put("o57", [======[	local side = d:Cross(UP)
	local lowCam = feet + d * (H * K[3]) - side * (H * 0.35) + UP * (H * 0.15)
	if BossView.get() ~= nil then
		Film.at(0.9, function()
			IntroUi.lowerThird(string.upper(P.areas[1].name), "The last guardian is free.", GREEN, 3.6)
			cue("calm", "calmMusic", { fade = 3 })
		end)
		Film.at(1.2, function()
			speak("E1", true)
		end)
		Film.grade("dream", 1.5)
		return lightRises(feet, lowCam, 5)
	end
	guardianShown = true
	BossView.show(moves.rig, CFrame.lookAt(feet, feet + d), guardianScale(n), moves)
	BossView.rageNow()
	-- (its own clock: kneeling till 3.75 s, the nod at 6.3 s, gone into the light from 7.4 s)
	BossView.act("freed", { free = 3.75, nod = 6.3, fade = 7.4 })
	guardianPinkEyes(H)
	local chest = feet + UP * (H * 0.55)
	local drone = FilmAudio.sfx("drone", { volume = 0.35, pitch = 0.8 })
	for _, t in { 0.7, 1.9, 2.9 } do
		Film.at(t, function()
			Glitch.burst(0.25, 0.1)
			FilmAudio.glitch(0.3)
		end)
	end
	-- 1A: beaten, on its knees, the glitch twitching in it; we creep in
	local ok = Film.run(3.6, function(k)
		local e = inOut(k)
		local pos = feet + d * (H * (K[1] - 0.35 * e)) + side * (H * 0.5) + UP * (H * 0.3)
		return Film.look(pos, feet + UP * (H * 0.5)), Film.mm(35), chest
	end, { hand = 0.25 })
	if not ok then
		return false
	end
	-- 1B: the pink tears out of it
	Film.at(0.15, function()
		FilmPanels.impact({ BossView.get() and BossView.get().model }, { color = GOLD, at = chest })
		FilmAudio.glitch(1)
		FilmAudio.sfx("bigHit", { volume = 0.6, pitch = 0.9 })
		FilmAudio.sfx("swell", { volume = 0.8 })
		FilmAudio.fadeOut(drone, 0.6)
		Film.shake(0.5, 0.6)
		glitchOut(feet, H)
		eyesOut()
		BossView.calmNow()
		Film.grade("dream", 0.9)
		Film.glow(0.3, 30, 0.9)
		cue("calm", "calmMusic", { fade = 2 })
]======], "1775 775241889"))
chk(put("n57", [======[	-- 1D: it goes up as light... the sun breaks through over the Mowers; low behind them, looking up
	Film.at(0.2, function()
		speak("E1", true)
		if alone then
			IntroUi.lowerThird(string.upper(P.areas[1].name), "The last guardian is free.", GREEN, 3.2)
		end
]======], "261 566921081"))
chk(put("o58", [======[		end
		if score > bestScore then
			d, bestScore, K = dir, score, ks
]======], "70 1356442785"))
chk(put("n58", [======[		end)
		local mid = feet:Lerp(pc, 0.5)
		local sd = side * A.s
		local look = feet:Lerp(pc, 0.3) + UP * (H * 0.42)
		ok = Film.run(2.8, function(k)
			local pos = mid + sd * (H * (1.15 - 0.05 * k)) + d * (H * 0.1) + UP * (H * 0.2)
			return Film.look(pos, look), Film.mm(24), look
		end, { hand = 0.3 })
		if not ok then
			return false
]======], "338 1232869283"))
chk(put("o59", [======[	-- The camera side: the turn where all three shots see it clearly, each from as far back as it can (Studio's test:
	-- the low shot stood behind the arena's wall). A shot's camera, `k` times its height away:
	local SHOTS = {
		{ dists = { 2.4, 2.0, 1.7 }, side = 0.5, up = 0.3 }, -- 1A, wide
		{ dists = { 1.45, 1.25 }, side = 0.15, up = 0.6 }, -- 1B, medium
		{ dists = { 1.9, 1.5, 1.25 }, side = -0.35, up = 0.15 }, -- 1C, low
	}
	local looks = { feet + UP * (H * 0.55), feet + UP * (H * 0.95), feet + UP * (H * 0.1) }
	local toCamp = unit(flat(P.camp - feet), P.fwd)
	local d, bestScore, K = toCamp, -math.huge, { 2.4, 1.45, 1.9 }
	for _, y in { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } do
		local dir = CFrame.Angles(0, math.rad(y), 0):VectorToWorldSpace(toCamp)
		local sd = dir:Cross(UP)
		local score = 0
		local ks = {}
		for i, sh in SHOTS do
			ks[i] = sh.dists[#sh.dists]
			for _, k in sh.dists do
				local s = shotScore(feet + dir * (H * k) + sd * (H * sh.side) + UP * (H * sh.up), looks, 35)
				if s >= 5 then
					ks[i] = k
					score += 10 + s + k
					break
				end
]======], "1103 1105705460"))
chk(put("n59", [======[	local chest = feet + UP * (H * 0.45)
	-- (the cameras behind the Mowers look through a gap in their row: 4.4 studs apart, the middle one in the middle)
	local gap = if #mowers % 2 == 1 then 2.2 else 0
	-- the Mowers, where they beat it, facing it
	for _, a in mowers do
		a.show()
		a.look(feet + UP * (H * 0.6))
	end
	-- (a fight's boss still in client/BossView, e.g. a DEV preview in a fight: it's left alone, just the light)
	local alone = BossView.get() ~= nil
	if not alone then
		guardianShown = true
		BossView.show(moves.rig, CFrame.lookAt(feet, feet + d), guardianScale(n), moves)
		BossView.rageNow()
		-- (its own clock: kneeling till 3.3 s, the bow at 5.6 s, gone into the light from 7.9 s)
		BossView.act("freed", { free = 3.3, nod = 5.6, fade = 7.9 })
		guardianPinkEyes(H)
		local function head(): Vector3
			return BossView.attWorld("att_head_center") or (feet + UP * (H * 0.65))
		end
		local drone = FilmAudio.sfx("drone", { volume = 0.35, pitch = 0.8 })
		for _, t in { 0.7, 1.9, 2.7 } do
			Film.at(t, function()
				Glitch.burst(0.25, 0.1)
				FilmAudio.glitch(0.3)
				BossView.flinch(false)
			end)
		end
		-- 1A: beaten, on its knees in front of the Mowers, the glitch twitching in it; low behind them, creeping in
		local ok = Film.run(3.0, function(k)
			local pos = pc + d * (8 - 1.6 * inOut(k)) + side * gap + UP * 2.6
			return Film.look(pos, chest + UP * (H * 0.05)), Film.mm(35), chest
		end, { hand = 0.25 })
		if not ok then
			return false
		end
		-- 1B: close on its face: the pink tears out of it [an impact frame, in gold]; its own colours come back
		Film.at(0.3, function()
			local v = BossView.get()
			FilmPanels.impact({ v and v.model }, { color = GOLD, at = chest })
			FilmAudio.glitch(1)
			FilmAudio.sfx("bigHit", { volume = 0.6, pitch = 0.9 })
			FilmAudio.sfx("swell", { volume = 0.8 })
			FilmAudio.fadeOut(drone, 0.6)
			Film.shake(0.5, 0.6)
			glitchOut(feet, H)
			eyesOut()
			BossView.calmNow()
			Film.grade("dream", 0.9)
			Film.glow(0.3, 30, 0.9)
			cue("calm", "calmMusic", { fade = 2 })
		end)
		ok = Film.run(1.6, function(k)
			local h = head()
			local pos = h + d * (H * (0.6 + 0.06 * k)) + side * (H * 0.12) - UP * (H * 0.06)
			return Film.look(pos, h), Film.mm(40), h
		end, { hand = 0.35 })
		if not ok then
			return false
		end
		-- 1C: from the side, wide: it stands up tall over the Mowers... and bows its head to them; they cheer
		Film.at(0.3, function()
			IntroUi.lowerThird(string.upper(P.areas[1].name), "The last guardian is free.", GREEN, 3.2)
		end)
		Film.at(1.5, function()
			for i, a in mowers do
				task.delay((i - 1) * 0.08, function()
					a.play("cheer")
				end)
]======], "2655 1986851869"))
chk(put("o60", [======[	local H = moves.height
	local feet = ground(P.arena)
]======], "54 1212980911"))
chk(put("n60", [======[	local H, feet, d, side, pc = A.H, A.feet, A.d, A.side, A.party
]======], "64 1686259733"))
chk(put("o61", [======[local function lastBladeScenes(P: Plan): boolean
]======], "49 1495677589"))
chk(put("n61", [======[local function lastBladeScenes(P: Plan, A: ArenaPlan, mowers: { IntroCast.Actor }): boolean
]======], "92 508971469"))
return "part 3/5 (edits 52-61): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
