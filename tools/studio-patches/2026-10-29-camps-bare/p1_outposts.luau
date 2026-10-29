local m = game.ServerScriptService.MowALawn.Outposts
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "26701 412766151" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	w:SetAttribute("HubR" .. z, CampDress.RADIUS)
]======], [======[	w:SetAttribute("HubR" .. z, hubR)
]======] },
	{ [======[	-- (29 Oct) the rest of the camp: server/CampDress (the old name board is the arch's sign now)
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
]======], [======[	-- (29 Oct) the rest of the camp: server/CampDress, when it's on (DRESS_CAMPS); else the camp is the plaza
	local hubR = R
	if DRESS_CAMPS then
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
		hubR = CampDress.RADIUS
]======] },
	{ [======[local R = 24 -- the plaza's radius (20 until 29 Oct)
local CELL = 4 -- paving grid
]======], [======[local R = 24 -- the plaza's radius (20 until 29 Oct)
local DRESS_CAMPS = false -- server/CampDress's arch, lamp posts, house, landmark, animals, villagers (off: see above)
local CELL = 4 -- paving grid
]======] },
	{ [======[-- clearing shared/WorldPlan keeps round every pad (and never inside the boss arena next to it), and
-- server/CampDress adds an entrance arch and lamp posts, a house, the area's landmark and animals round it and
-- three gnome villagers (Blender models: server/CampProps; client/CampLife animates them).
]======], [======[-- clearing shared/WorldPlan keeps round every pad (and never inside the boss arena next to it). server/CampDress
-- added an entrance arch and lamp posts, a house, the area's landmark and animals round it and three gnome villagers
-- (Blender models: server/CampProps; client/CampLife animates them): off since 29 Oct 22:37 (owner: "remove houses
-- and the dumb shit u added", then picked all of it), DRESS_CAMPS below brings it back.
]======] },
	{ [======[--     mushrooms, an ice-crystal fire pit, a forge, a star-crystal cluster); the camp's landmark does that now.
]======], [======[--     mushrooms, an ice-crystal fire pit, a forge, a star-crystal cluster).
]======] },
	{ [======[--   * two log benches (lamp posts and the name: server/CampDress);
]======], [======[--   * two log benches;
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "26961 421549389" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
