local m = game.ServerScriptService.MowALawn.Outposts
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "21484 1601836981" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	w:SetAttribute("HubR" .. z, R)
]======], [======[	w:SetAttribute("HubR" .. z, CampDress.RADIUS)
]======] },
	{ [======[	f.Parent = w
	w:SetAttribute("Hub" .. z, base)
]======], [======[	f.Parent = w
	-- (29 Oct) the rest of the camp: server/CampDress (the old name board is the arch's sign now)
	local CampDress = require(script.Parent.CampDress)
	local ok, err = pcall(CampDress.dress, {
		w = w,
		f = f,
		z = z,
		base = base,
		top = top,
		fwd = fwd,
		right = right,
		R = R,
		rng = rng,
		info = info,
		glow = th.glow,
		lanternPost = function(parent: Instance, p: Vector3, out: Vector3)
			lanternPost(parent, p, out, th)
		end,
	})
	if not ok then
		warn(("[Outposts] area %d dressing: %s"):format(z, tostring(err)))
	end
	w:SetAttribute("Hub" .. z, base)
]======] },
	{ [======[		special(f, at(-9, 9, -fwd), th, rng)
	end
	signboard(f, at(7, 13, fwd), string.upper(def.name) .. " CAMP")
	-- lantern posts round the edge (not in front of the stalls)
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		local dir = (fwd * math.cos(a) + right * math.sin(a))
		if dir:Dot(fwd) > -0.7 then
			lanternPost(f, base + dir * (R - 1.5), dir, th)
		end
]======], [======[		special(f, at(-11, 8, -fwd), th, rng)
]======] },
	{ [======[	bench(f, at(-12, 2, right))
]======], [======[	bench(f, at(-14.5, 1, right))
]======] },
	{ [======[local R = 20 -- the plaza's radius
]======], [======[local R = 24 -- the plaza's radius (20 until 29 Oct)
]======] },
	{ [======[-- The plaza's centre and radius go on the World as attributes Hub<z> / HubR<z>: no grass grows there
]======], [======[-- (29 Oct, owner: "remake every zone hub except 1 to make it a bit bigger and ... feel more alive") the plaza is
-- 24 studs round now and server/CampDress dresses the camp: an entrance arch, a signpost, a notice board, a well, a
-- market cart, banners and lamps on the plaza; round it a house, tents by a fire, the area's landmark and animals,
-- and gnome villagers (Blender models: server/CampProps; client/CampLife animates them).
-- The camp's centre and radius go on the World as attributes Hub<z> / HubR<z>: no grass grows there
]======] },
	{ [======[--   * lantern posts round the edge, two log benches and a signboard with the area's name;
]======], [======[--   * lantern posts round the edge and two log benches (the name is on server/CampDress's arch now);
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "22170 1737268933" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
