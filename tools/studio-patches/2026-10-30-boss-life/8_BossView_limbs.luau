local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossView
local s = m.Source
if string.find(s, [======[BossLife.setup]======], 1, true) then
	return m.Name .. " already has this patch"
end
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local edits = {
	{ [======[			local info = byName[d.Name]
]======], [======[			local info = byName[d.Name]
			-- (30 Oct, owner: "the arms ... dont move") a jointed boss: its pieces carry a `Limb` attribute (head, armL,
			-- armR, body, base) instead of a line in the rig; client/BossLife turns them about their joints
			local limb = d:GetAttribute("Limb")
			if not info and type(limb) == "string" then
				info = { n = d.Name, g = "body", mat = "tex" }
			end
]======] },
	{ [======[					pin = pin,
				})]======], [======[					pin = pin,
					limb = if type(limb) == "string" then limb else nil,
				})]======] },
	{ [======[	for _, p in parts do
		applyLook(v, p, false)
	end
	model.Parent = folder
]======], [======[	for _, p in parts do
		applyLook(v, p, false)
	end
	BossLife.setup(v) -- (30 Oct) a jointed boss: its limbs' joints, its disc carried flat
	model.Parent = folder
]======] },
	{ [======[		elseif g and p.grow > 0.001 then
			local ax, ay, az, at = g[1], g[2], g[3], g[4]
			local c = p.c
			local centre = ax * c.X + ay * c.Y + az * c.Z + at
			local x = ax * p.rx.X + ay * p.rx.Y + az * p.rx.Z
			local y = ax * p.ry.X + ay * p.ry.Y + az * p.ry.Z
			local z = ax * p.rz.X + ay * p.rz.Y + az * p.rz.Z
]======], [======[		elseif p.flat then
			-- (30 Oct) a jointed boss's disc goes where it goes, never leaning or squashing
			n += 1
			list[n] = p.part
			cfs[n] = BossLife.flatCf(v, p, base)
		elseif g and p.grow > 0.001 then
			local ax, ay, az, at = g[1], g[2], g[3], g[4]
			local c, rx, ry, rz = p.c, p.rx, p.ry, p.rz
			local hip = 0
			if p.limb then
				-- (30 Oct) a jointed boss's limb turns about its joint first (arms swing, the head looks round), and
				-- the body leans about its hips (the top of its disc)
				c, rx, ry, rz = BossLife.turn(v, p)
				hip = v.hip or 0
			end
			local centre = ax * c.X + ay * (c.Y - hip) + az * c.Z + at + Vector3.new(0, hip, 0)
			local x = ax * rx.X + ay * rx.Y + az * rx.Z
			local y = ax * ry.X + ay * ry.Y + az * ry.Z
			local z = ax * rz.X + ay * rz.Y + az * rz.Z
]======] },
	{ [======[	local p = a.p
	return v.base * (g[1] * p.X + g[2] * p.Y + g[3] * p.Z + g[4])
]======], [======[	local p = a.p
	if v.limbs then
		-- (30 Oct) on a jointed boss a point follows its limb (the eyes turn with the head)
		return v.base * BossLife.attPoint(v, a, g)
	end
	return v.base * (g[1] * p.X + g[2] * p.Y + g[3] * p.Z + g[4])
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "NOT CHANGED: edit " .. k .. " not found once in " .. m.Name
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
