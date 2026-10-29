local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "45794 319622153" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	ctx.plazaTaken = {}
]======], [======[]======] },
	{ [======[		if cf and size and Vector2.new(cf.Position.X - ctx.base.X, cf.Position.Z - ctx.base.Z).Magnitude < ctx.R + 6 then
			add(cf, size)
		end
]======], [======[		if cf and size and Vector2.new(cf.Position.X - ctx.base.X, cf.Position.Z - ctx.base.Z).Magnitude < ctx.R + 6 then
			if d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
				-- the pad's round steps (discs on their side): round
				table.insert(ctx.plazaTaken :: { Disc }, { at = Vector2.new(cf.Position.X, cf.Position.Z), r = math.max(size.Y, size.Z) / 2 })
			else
				add(cf, size)
			end
		end
]======] },
	{ [======[	end
	local pads = ctx.w:FindFirstChild("Pads")
]======], [======[	end
	ctx.plazaTaken = {}
	local pads = ctx.w:FindFirstChild("Pads")
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "46062 1653425206" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
