-- Draws shared/WorldPlan as a top-down picture (PPM), to check the layout without Studio.
-- lune run tools/world/plan.luau <out.ppm>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local env = setmetatable({ Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3 }, { __index = _G })
local function load(path)
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
	return fn()
end
local Zones = load("src/shared/Zones.luau")
local WorldPlan = load("src/shared/WorldPlan.luau")

local t0 = os.clock()
local plan = WorldPlan.make(Zones)
local t1 = os.clock()

local S = 4
local W, H = plan.nx * S, plan.nz * S
local img = table.create(W * H, { 0, 0, 0 })
local function px(x, y, c)
	if x >= 1 and x <= W and y >= 1 and y <= H then
		img[(y - 1) * W + x] = c
	end
end
local function shade(col, h)
	local k = math.clamp(0.75 + h / 120, 0.45, 1.25)
	return { math.clamp(math.floor(col.R * 255 * k), 0, 255), math.clamp(math.floor(col.G * 255 * k), 0, 255), math.clamp(math.floor(col.B * 255 * k), 0, 255) }
end
local counts = {}
for i = 1, plan.nx do
	for j = 1, plan.nz do
		local c = plan.cells[i][j]
		counts[c.kind] = (counts[c.kind] or 0) + 1
		local col
		if c.kind == "zone" then
			local def = Zones.region(c.region)
			local base = if (c.h // Zones.STEP) % 2 == 0 then def.palette.ground else def.palette.ground2
			col = shade(base, c.h)
		elseif c.kind == "rock" then
			col = shade(Zones.region(c.near).palette.rock, c.h - 10)
		elseif c.kind == "sea" or c.kind == "void" then
			col = { 30, 110, 190 }
		elseif c.kind == "chasm" then
			col = { 20, 40, 70 }
		elseif c.kind == "cut" then
			col = { 90, 80, 70 }
		end
		for dx = 0, S - 1 do
			for dy = 0, S - 1 do
				px((i - 1) * S + 1 + dx, (j - 1) * S + 1 + dy, col)
			end
		end
	end
end
local function toPix(p)
	local B = Zones.BOUNDS
	return math.floor((p.X - B.minX) / Zones.CELL * S), math.floor((p.Y - B.minZ) / Zones.CELL * S)
end
local function dot(p, r, col)
	local x, y = toPix(p)
	for dx = -r, r do
		for dy = -r, r do
			if dx * dx + dy * dy <= r * r then
				px(x + dx, y + dy, col)
			end
		end
	end
end
for _, cor in plan.corridors do
	for t = 0, 1, 0.02 do
		dot(cor.a:Lerp(cor.b, t), 2, if cor.chasm then { 255, 210, 60 } else { 255, 255, 255 })
	end
	dot(cor.a:Lerp(cor.b, 0.5), 5, { 255, 200, 0 })
end
for _, pad in plan.pads do
	dot(pad.at, 4, { 0, 255, 255 })
end
for _, patch in plan.patches do
	for _, b in patch.blobs do
		local x, y = toPix(b.at)
		local r = math.floor(b.r / Zones.CELL * S)
		for a = 0, 360, 4 do
			px(x + math.floor(math.cos(math.rad(a)) * r), y + math.floor(math.sin(math.rad(a)) * r), { 255, 255, 255 })
		end
	end
end
for _, def in Zones.list do
	dot(def.landmark.at, 6, { 255, 0, 80 })
end

local parts = {}
table.insert(parts, ("P3\n%d %d\n255\n"):format(W, H))
local buf = table.create(W * H)
for k = 1, W * H do
	local c = img[k]
	buf[k] = c[1] .. " " .. c[2] .. " " .. c[3]
end
table.insert(parts, table.concat(buf, "\n"))
fs.writeFile(process.args[1] or "plan.ppm", table.concat(parts))

-- stats
local zr = WorldPlan.rects(plan, function(c)
	return c.kind ~= "void" and c.kind ~= "sea" and (c.kind .. ":" .. tostring(c.region or c.near) .. ":" .. (c.h // Zones.STEP) % 2) or nil
end)
print(("plan %.2fs, %d x %d cells, ground rects %d"):format(t1 - t0, plan.nx, plan.nz, #zr))
for k, v in counts do
	print(k, v)
end
for _, cor in plan.corridors do
	local len = (cor.b - cor.a).Magnitude
	print(("corridor -> %d %s: len %.0f, ha %d hb %d, slope %.2f"):format(cor.zone, cor.gate, len, cor.ha, cor.hb, math.abs(cor.hb - cor.ha) / len))
end
print("patches", #plan.patches)
