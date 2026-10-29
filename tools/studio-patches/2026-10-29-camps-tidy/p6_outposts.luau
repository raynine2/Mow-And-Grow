local m = game.ServerScriptService.MowALawn.Outposts
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "25816 1841533535" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	-- benches either side (the special corner is gone: owner, 29 Oct, "remove unneccerary stuff")
]======], [======[]======] },
	{ [======[		gasPump(f, base + right * 16 + fwd * -4, info, -right)
]======], [======[		gasPump(f, at(16, -4).Position, info, turned(-right))
]======] },
	{ [======[	-- (29 Oct, owner: "why is the middle so close to the stores": they stood against the pad's 9-stud ring) set back
	-- on the bigger plaza, an open ring round the pad
]======], [======[]======] },
	{ [======[		local p = base + right * x + fwd * zz
		return CFrame.lookAt(p, p + (face or fwd))
]======], [======[		local p = base + turned(right * x + fwd * zz)
		return CFrame.lookAt(p, p + turned(face or fwd))
]======] },
	{ [======[	-- the two stalls behind the pad, facing it; the gas pump to one side
]======], [======[	-- the two stalls behind the pad, facing it; the gas pump to one side; a bench either side. (29 Oct, owner: "why is
	-- the middle so close to the stores": they stood against the pad's 9-stud ring; now set back on the bigger plaza,
	-- an open ring round the pad.) All of it turns round the pad, as one, until none of it stands in the boss arena
	-- (the isles' camp has the arena right behind it).
	local PIECES = { { -7.5, -16, 6.5 }, { 7.5, -16, 6.5 }, { 16, -4, 2.5 }, { -16, 2, 3 }, { 16, 5, 3 } }
	local cosT, sinT = 1, 0
	if avoid then
		for _, deg in { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } do
			local a = math.rad(deg)
			local clear = true
			for _, pc in PIECES do
				local x, zz = pc[1] * math.cos(a) + pc[2] * math.sin(a), -pc[1] * math.sin(a) + pc[2] * math.cos(a)
				local p = base + right * x + fwd * zz
				if (Vector2.new(p.X, p.Z) - avoid.at).Magnitude < avoid.r + pc[3] + 2 then
					clear = false
				end
			end
			if clear then
				cosT, sinT = math.cos(a), math.sin(a)
				break
			end
		end
	end
	local function turned(v: Vector3): Vector3
		local x, zz = v:Dot(right), v:Dot(fwd)
		return right * (x * cosT + zz * sinT) + fwd * (-x * sinT + zz * cosT)
	end
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "26701 412766151" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
