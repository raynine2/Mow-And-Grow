local m = game.ServerScriptService.MowALawn.CampDress
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "42967 834704693" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		for _, deg in { 0, 12, -12, 24, -24, 36, -36 } do
]======], [======[		for _, da in { 0, 12, -12, 24, -24, 36, -36 } do
			local deg = e + da
]======] },
	{ [======[local function arch(ctx: Ctx, name: string)
	for _, dist in { ctx.R - 3.6, ctx.R - 4.8, ctx.R - 6, ctx.R - 7.5 } do
]======], [======[local function arch(ctx: Ctx, name: string)
	local e = entrance(ctx)
	for _, dist in { ctx.R - 3.6, ctx.R - 4.8, ctx.R - 6, ctx.R - 7.5 } do
]======] },
	{ [======[-- The entrance arch toward the area's middle, its two feet and the way through on the paving.
]======], [======[-- Where the busiest path comes in (degrees from the area's middle; 0 when no path does): the arch goes there.
local function entrance(ctx: Ctx): number
	local bins: { [number]: { number } } = {}
	local visuals = ctx.w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			if isPath(d) then
				local v = (d :: BasePart).Position - ctx.base
				local dist = Vector2.new(v.X, v.Z).Magnitude
				if dist > ctx.R + 2 and dist < ctx.R + 18 then
					local deg = math.deg(math.atan2(v:Dot(ctx.right), v:Dot(ctx.fwd)))
					local k = math.floor(deg / 20 + 0.5)
					bins[k] = bins[k] or {}
					table.insert(bins[k], deg)
				end
			end
		end
	end
	local best, most = nil, 0
	for _, list in bins do
		if #list > most then
			best, most = list, #list
		end
	end
	if not best then
		return 0
	end
	-- the bin's middle (angles near +-180 are kept on one side)
	local s, c = 0, 0
	for _, deg in best do
		s += math.sin(math.rad(deg))
		c += math.cos(math.rad(deg))
	end
	return math.deg(math.atan2(s, c))
end

-- The entrance arch where the path comes in, its two feet and the way through on the paving.
]======] },
	{ [======[		table.insert(boxes, { cf = cf, hx = size.X / 2, hz = size.Z / 2 })
]======], [======[		table.insert(boxes, footprint(cf, size))
]======] },
	{ [======[	for _, da in { 0, 12, -12, 24, -24, 36, -36, 50, -50, 65, -65 } do
]======], [======[	for _, da in TURNS do
]======] },
	{ [======[-- A spot for something halfW x halfD round angle `deg` from the area's middle and `r` from the pad: on ground that's
-- there, not too steep, free (above); its front toward the plaza. nil if there's none.
]======], [======[-- the turns to try round a wanted angle, nearest first: 0, 10, -10, 20, -20 ... 180
local TURNS = { 0 }
for k = 10, 170, 10 do
	table.insert(TURNS, k)
	table.insert(TURNS, -k)
end
table.insert(TURNS, 180)

-- A spot for something halfW x halfD round angle `deg` from the area's middle (or the nearest free angle) and `r`
-- from the pad: on ground that's there, not too steep, free (above); its front toward the plaza. nil if there's none.
]======] },
	{ [======[			if isFlat(d) then
]======], [======[			if isPath(d) then
]======] },
	{ [======[	-- the paths (flat tiles in World.Visuals) and the areas' landmarks
]======], [======[	-- the paths (tiles in World.Visuals) and the areas' landmarks
]======] },
	{ [======[			table.insert(list, { cf = cf, hx = size.X / 2, hz = size.Z / 2 })
]======], [======[			table.insert(list, footprint(cf, size))
]======] },
	{ [======[	return d:IsA("BasePart") and d.Size.Y <= 0.6 and math.max(d.Size.X, d.Size.Z) <= 8
end
]======], [======[	return d:IsA("BasePart") and d.Size.Y <= 0.6 and math.max(d.Size.X, d.Size.Z) <= 8
end

-- a path tile (WorldArt's 3.1 x 0.3 x 3.1 paving): built round, never on
local function isPath(d: Instance): boolean
	return d:IsA("BasePart") and math.abs(d.Size.Y - 0.3) < 0.05 and math.abs(d.Size.X - 3.1) < 0.05 and math.abs(d.Size.Z - 3.1) < 0.05
end

-- A box's footprint on the ground (its most upright axis is its height: a disc lying on its side, a stall).
local function footprint(cf: CFrame, size: Vector3): Box
	local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local half = { size.X / 2, size.Y / 2, size.Z / 2 }
	local up = 1
	for i = 2, 3 do
		if math.abs(axes[i].Y) > math.abs(axes[up].Y) then
			up = i
		end
	end
	local a = if up == 1 then 2 else 1
	local b = if up == 3 then 2 else 3
	local u = Vector3.new(axes[a].X, 0, axes[a].Z)
	u = if u.Magnitude > 1e-3 then u.Unit else Vector3.xAxis
	return { cf = CFrame.fromMatrix(cf.Position, u, UP), hx = half[a], hz = half[b] }
end
]======] },
	{ [======[-- a path tile (World.Visuals: WorldArt's flat 3.1 x 0.3 x 3.1 paving) or other flat ground cover: kept, built round
]======], [======[-- flat ground cover in World.Visuals (path tiles, the 8 x 8 grass squares, flowers): never cleared away
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "45119 1380540149" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
