local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "45119 1380540149" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[			if ok then
				return pts
]======], [======[			if ok then
				return pts
			end
		end
	end
	for _, rr in { 16, 17.5, 14.5, 19, 13 } do
		for _, mid in { 0, 30, -30, 60, -60, 90, -90 } do
			local pts = {}
			for k = -3, 3 do
				table.insert(pts, ctx.base + dirAt(ctx, mid + k * 30) * rr)
			end
			local ok = true
			for k = 1, 6 do
				ok = ok and walkable(ctx, pts[k], pts[k + 1])
			end
			if ok then
				-- there and back: 1..7, then 6..2 (the loop closes from 2 to 1)
				for k = 6, 2, -1 do
					table.insert(pts, pts[k])
				end
				return pts
]======] },
	{ [======[				local a, b = pts[k], pts[k % 8 + 1]
				local n = math.ceil((b - a).Magnitude / 1.25)
				for s = 0, n - 1 do
					ok = ok and onPlaza(ctx, a:Lerp(b, s / n), 1.0)
				end
]======], [======[				ok = ok and walkable(ctx, pts[k], pts[k % 8 + 1])
]======] },
	{ [======[	for _, rr in { 17.5, 16, 19, 14.5, 20.5, 13 } do
]======], [======[	for _, rr in { 17.5, 16, 19, 14.5, 20.5 } do
]======] },
	{ [======[-- The walk round the plaza: eight points on a circle with every step of the way paved and clear (the first circle
-- that works, nil if none does).
]======], [======[-- every step from a to b paved and clear
local function walkable(ctx: Ctx, a: Vector3, b: Vector3): boolean
	local n = math.ceil((b - a).Magnitude / 1.25)
	for s = 0, n do
		if not onPlaza(ctx, a:Lerp(b, s / n), 1.0) then
			return false
		end
	end
	return true
end

-- The walk round the plaza: eight points on a circle with every step of the way paved and clear; else back and forth
-- along half a circle in front of the stalls (the first that works, nil if none does).
]======] },
	{ [======[		if (q - t.at).Magnitude < r + t.r + 3 then
]======], [======[		if (q - t.at).Magnitude < r + t.r + 8 then
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "45798 1572776351" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
