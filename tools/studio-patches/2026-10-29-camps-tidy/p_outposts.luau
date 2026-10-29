local m = game.ServerScriptService.MowALawn.Outposts
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "22170 1737268933" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	local special = SPECIAL[th.special]
	if special then
		special(f, at(-11, 8, -fwd), th, rng)
	end
]======], [======[]======] },
	{ [======[	-- benches either side and the special corner across the plaza
]======], [======[	-- benches either side (the special corner is gone: owner, 29 Oct, "remove unneccerary stuff")
]======] },
	{ [======[	plaza(f, base, top, th, ground, rng)
]======], [======[	local arena = Config.BOSS_ARENAS and Config.BOSS_ARENAS[z]
	local avoid = if arena then { at = Vector2.new(arena.x, arena.z), r = (Config.BOSS_ARENA_RADIUS or 70) + 3 } else nil
	plaza(f, base, top, th, ground, rng, avoid)
]======] },
	{ [======[			if Vector2.new(i * CELL, j * CELL).Magnitude <= R then
]======], [======[			-- (`avoid`: the boss arena next to the isles' camp; its rim would cut through the paving)
			if Vector2.new(i * CELL, j * CELL).Magnitude <= R and not (avoid and (Vector2.new(x, z) - avoid.at).Magnitude < avoid.r + CELL * 0.75) then
]======] },
	{ [======[local function plaza(f: Instance, c: Vector3, top: number, th: Theme, groundParts: { Instance }, rng: Random)
]======], [======[local function plaza(f: Instance, c: Vector3, top: number, th: Theme, groundParts: { Instance }, rng: Random, avoid: { at: Vector2, r: number }?)
]======] },
	{ [======[

local Zones = require(ReplicatedStorage.MowALawn.Zones)
]======], [======[

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
]======] },
	{ [======[--   * lantern posts round the edge and two log benches (the name is on server/CampDress's arch now);
--   * one thing of its own per area: a hay yard, a blossom tree, a campfire ring, a stilt-lamp boardwalk with
--     mushrooms, an ice-crystal fire pit, a forge with braziers, a star-crystal cluster.
-- (29 Oct, owner: "remake every zone hub except 1 to make it a bit bigger and ... feel more alive") the plaza is
-- 24 studs round now and server/CampDress dresses the camp: an entrance arch, a signpost, a notice board, a well, a
-- market cart, banners and lamps on the plaza; round it a house, tents by a fire, the area's landmark and animals,
-- and gnome villagers (Blender models: server/CampProps; client/CampLife animates them).
]======], [======[--   * two log benches (lamp posts and the name: server/CampDress);
--   * (until 29 Oct) one thing of its own per area (SPECIAL below: a hay yard, a blossom tree, a campfire ring,
--     mushrooms, an ice-crystal fire pit, a forge, a star-crystal cluster); the camp's landmark does that now.
-- (29 Oct, owner: "remake every zone hub except 1 to make it a bit bigger and ... feel more alive"; 21:13, "its very
-- messy and just cluttered fix it and remove unneccerary stuff") the plaza is 24 studs round now, on the flat
-- clearing shared/WorldPlan keeps round every pad (and never inside the boss arena next to it), and
-- server/CampDress adds an entrance arch and lamp posts, a house, the area's landmark and animals round it and
-- three gnome villagers (Blender models: server/CampProps; client/CampLife animates them).
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "22649 1525364530" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
