-- The camp's Tool Shop and Garage, built from blocks in the world's voxel look (owner, 27 Oct: "the house and the
-- normal garage is bugged and i dont like the design ... remake it in voxel style that we have but not too much,
-- fitting and interactable to go inside"; then: "looks low quality ... needs to be high quality with good detail,
-- a bit bigger, more detail, and it doesn't have to be so bright").
--
-- A proper log lodge rather than a box: logs with chinking between the rows and end-grain log ends at the
-- corners, a stone plinth, a fine stepped shingle roof with drip edges, barge boards and a ridge beam, board gables
-- with a louvre vent, deep windows with lintels, plank shutters and planters, a timber door frame with iron-strapped
-- double doors, a porch with knee braces, railings and a hanging sign, a stone chimney, firewood, barrels and
-- crates; inside: rafters, a chandelier, shelves of goods. The garage matches it, with a roll-up door, a work deck,
-- workbench, tool wall, tool cabinet, tyres and a shop lamp. The blocks wear Studio-made pixel textures
-- (MaterialService.AssistantMaterials: MowVoxelLog, MowVoxelStone1, MowVoxelMetal3) on the logs, stone and door,
-- so they match the voxel trees; without them they fall back to plain colours.
--
-- Both are walk-in: the shop's double door swings open when someone comes near, the garage door rolls up. The
-- doors don't collide, so they never trap anyone. RunBuilder still places the tool displays, prompts, the mower
-- spawn and the gas pump (CampBuildings.PUMP is where the pump goes beside the wider garage).
--
-- Coordinates are in the building's own space: `at` is RunBuilder's spot for it (where the old model stood),
-- front = at.LookVector (-Z), y = 0 is the ground.
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Models = require(script.Parent.Models)

local CampBuildings = {}
CampBuildings.ON = true
CampBuildings.PUMP = CFrame.new(13.6, 0, -7) -- the gas pump, in the garage's space

local ROW = 1.6 -- one log (with its chinking)
local T = 1.4 -- wall thickness

-- the pixel textures (MaterialVariant name, its base material). Only the logs, the stone and the garage door wear
-- one; boards, shingles and trim are plain blocks in a few close tones (textures everywhere looked too busy).
local SKIN: { [string]: { any } } = {
	log = { "MowVoxelLog", Enum.Material.Wood },
	stone = { "MowVoxelStone1", Enum.Material.Cobblestone },
	metal = { "MowVoxelMetal3", Enum.Material.CorrodedMetal },
}
local hasSkin: { [string]: boolean } = {}

-- Tints over the textures: soft, a little weathered (owner: "doesn't have to be so bright").
local C = {
	log = Color3.fromRGB(236, 214, 190),
	logEnd = Color3.fromRGB(228, 198, 158),
	ring = Color3.fromRGB(126, 92, 64),
	chink = Color3.fromRGB(160, 148, 126),
	timber = Color3.fromRGB(92, 66, 50), -- plain (no texture): beams, frames, rails
	board = Color3.fromRGB(150, 112, 80),
	stone = Color3.fromRGB(226, 226, 220),
	roof = Color3.fromRGB(118, 64, 52),
	floor = Color3.fromRGB(162, 124, 90),
	iron = Color3.fromRGB(54, 52, 52),
	shutter = Color3.fromRGB(84, 98, 90),
	glass = Color3.fromRGB(128, 100, 66),
	metal = Color3.fromRGB(196, 200, 204),
	stripe = Color3.fromRGB(196, 156, 50),
	leaf = Color3.fromRGB(66, 112, 56),
	soil = Color3.fromRGB(70, 52, 40),
	lamp = Color3.fromRGB(255, 196, 120),
}

type Ctx = { parent: Instance, at: CFrame, rng: Random }

-------------------------------------------------------------------------------------------------------------
-- blocks
-------------------------------------------------------------------------------------------------------------
local function jitter(rng: Random, c: Color3, amt: number): Color3
	local k = 1 + (rng:NextNumber() * 2 - 1) * amt
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- `look`: a SKIN name (pixel texture), or a Material.
local function blockAt(ctx: Ctx, name: string, cf: CFrame, size: Vector3, color: Color3, look: any?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = ctx.at * cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if type(look) == "string" then
		local s = SKIN[look]
		if s then
			if hasSkin[look] == nil then
				hasSkin[look] = MaterialService:FindFirstChild(s[1], true) ~= nil
			end
			if hasSkin[look] then
				p.Material = s[2]
				p.MaterialVariant = s[1]
			else
				p.Color = color:Lerp(Color3.new(0, 0, 0), 0.2)
			end
		end
	elseif typeof(look) == "EnumItem" then
		p.Material = look
	end
	p.Parent = ctx.parent
	return p
end

local function block(ctx: Ctx, name: string, centre: Vector3, size: Vector3, color: Color3, look: any?): Part
	return blockAt(ctx, name, CFrame.new(centre), size, color, look)
end

-- Decoration: no collisions or queries.
local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- An upright cylinder (Roblox cylinders run along X).
local function cylinder(ctx: Ctx, name: string, centre: Vector3, h: number, d: number, color: Color3, look: any?): Part
	local p = blockAt(ctx, name, CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, d, d), color, look)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- [a, b] split into pieces between minL and maxL long (the last one never shorter than minL).
local function chop(rng: Random, a: number, b: number, minL: number, maxL: number): { { number } }
	local out = {}
	local x = a
	while b - x > 0.01 do
		local len = math.min(rng:NextNumber(minL, maxL), b - x)
		if b - (x + len) < minL then
			len = b - x
		end
		table.insert(out, { x, x + len })
		x += len
	end
	return out
end

-- [a, b] without the holes (each { from, to }).
local function subtract(a: number, b: number, holes: { { number } }): { { number } }
	local out = { { a, b } }
	for _, h in holes do
		local next = {}
		for _, s in out do
			if h[2] <= s[1] or h[1] >= s[2] then
				table.insert(next, s)
			else
				if h[1] > s[1] then
					table.insert(next, { s[1], h[1] })
				end
				if h[2] < s[2] then
					table.insert(next, { h[2], s[2] })
				end
			end
		end
		out = next
	end
	return out
end

-------------------------------------------------------------------------------------------------------------
-- log walls
-------------------------------------------------------------------------------------------------------------
-- box = { x = outer half-width, z0 = front outer z, z1 = back outer z, floor = floor top, rows = number of logs }
-- holes(wall, row) -> { { from, to } } for "front", "back", "left" (-X), "right" (+X)
type Box = { x: number, z0: number, z1: number, floor: number, rows: number }

-- One row on one wall (along X at z = fixed, or along Z at x = fixed), from a to b minus holes: the chinking line
-- set back under the logs, and the logs in long pieces.
local function logRun(ctx: Ctx, alongX: boolean, fixed: number, y0: number, a: number, b: number, holes: { { number } })
	local function at(along: number, y: number, len: number, h: number, depth: number): (Vector3, Vector3)
		if alongX then
			return Vector3.new(along, y, fixed), Vector3.new(len, h, depth)
		end
		return Vector3.new(fixed, y, along), Vector3.new(depth, h, len)
	end
	for _, s in subtract(a, b, holes) do
		local len = s[2] - s[1]
		if len > 0.05 then
			local cp, cs = at((s[1] + s[2]) / 2, y0 + 0.13, len, 0.26, T - 0.5)
			block(ctx, "Chink", cp, cs, C.chink)
			for _, piece in chop(ctx.rng, s[1], s[2], 3.5, 8) do
				local lp, ls = at((piece[1] + piece[2]) / 2, y0 + 0.26 + (ROW - 0.26) / 2, piece[2] - piece[1], ROW - 0.26, T)
				-- turned on its long axis so the texture's grain runs along the log
				local rot = if alongX then CFrame.Angles(0, 0, math.rad(90)) else CFrame.Angles(math.rad(90), 0, 0)
				local rs = if alongX then Vector3.new(ls.Y, ls.X, ls.Z) else Vector3.new(ls.X, ls.Z, ls.Y)
				blockAt(ctx, "Log", CFrame.new(lp) * rot, rs, jitter(ctx.rng, C.log, 0.05), "log")
			end
		end
	end
end

-- A log end sticking out past a corner: the stub, a darker ring and a lighter heart on its end face.
local function logEnd(ctx: Ctx, centre: Vector3, out: Vector3, len: number, y0: number)
	local h = ROW - 0.3
	local across = Vector3.new(math.abs(out.Z), 0, math.abs(out.X)) -- along the face, flat
	local size = out:Abs() * len + across * (T - 0.12) + Vector3.yAxis * h
	block(ctx, "LogEnd", centre + Vector3.new(0, y0 + 0.26 + h / 2, 0), size, jitter(ctx.rng, C.logEnd, 0.05), "log")
	local face = centre + out * (len / 2) + Vector3.new(0, y0 + 0.26 + h / 2, 0)
	deco(block(ctx, "LogRing", face + out * 0.03, out:Abs() * 0.06 + across * (T - 0.55) + Vector3.yAxis * (h - 0.45), C.ring))
	deco(block(ctx, "LogHeart", face + out * 0.06, out:Abs() * 0.06 + across * (T - 0.95) + Vector3.yAxis * (h - 0.85), C.logEnd:Lerp(C.ring, 0.25)))
end

local function logBox(ctx: Ctx, box: Box, holes: (string, number) -> { { number } })
	local xw, zf, zb = box.x - T / 2, box.z0 + T / 2, box.z1 - T / 2
	local stick = 1.1
	for r = 0, box.rows - 1 do
		local y0 = box.floor + r * ROW
		local long = r % 2 == 0 -- even rows: the front and back logs run through the corners and stick out
		local xa = if long then -box.x else -box.x + T
		local za, zb2 = if long then box.z0 + T else box.z0, if long then box.z1 - T else box.z1
		logRun(ctx, true, zf, y0, xa, -xa, holes("front", r))
		logRun(ctx, true, zb, y0, xa, -xa, holes("back", r))
		logRun(ctx, false, -xw, y0, za, zb2, holes("left", r))
		logRun(ctx, false, xw, y0, za, zb2, holes("right", r))
		for _, sx in { -1, 1 } do
			if long then
				for _, z in { zf, zb } do
					logEnd(ctx, Vector3.new(sx * (box.x + stick / 2), 0, z), Vector3.new(sx, 0, 0), stick, y0)
				end
			else
				logEnd(ctx, Vector3.new(sx * xw, 0, box.z0 - stick / 2), Vector3.new(0, 0, -1), stick, y0)
				logEnd(ctx, Vector3.new(sx * xw, 0, box.z1 + stick / 2), Vector3.new(0, 0, 1), stick, y0)
			end
		end
	end
end

-- A stone plinth under the walls (down into the ground so a slope never shows a gap), the fill under the floor and
-- the floor boards.
local function footing(ctx: Ctx, box: Box, floorColor: Color3, boards: boolean)
	local top, d = box.floor, 3
	local zc, zl = (box.z0 + box.z1) / 2, box.z1 - box.z0
	local function stone(c: Vector3, s: Vector3)
		local dip = ctx.rng:NextNumber(0, 0.12)
		block(ctx, "Plinth", c - Vector3.new(0, dip / 2, 0), s - Vector3.new(0, dip, 0), jitter(ctx.rng, C.stone, 0.06), "stone")
	end
	for _, piece in chop(ctx.rng, -box.x - 0.35, box.x + 0.35, 2.4, 4.4) do
		for _, z in { box.z0 + 0.5, box.z1 - 0.5 } do
			stone(Vector3.new((piece[1] + piece[2]) / 2, (top - d) / 2, z), Vector3.new(piece[2] - piece[1] - 0.05, top + d, T + 0.7))
		end
	end
	for _, piece in chop(ctx.rng, box.z0 + 1.2, box.z1 - 1.2, 2.4, 4.4) do
		for _, sx in { -1, 1 } do
			stone(Vector3.new(sx * (box.x - 0.35), (top - d) / 2, (piece[1] + piece[2]) / 2), Vector3.new(T + 0.7, top + d, piece[2] - piece[1] - 0.05))
		end
	end
	block(ctx, "FloorFill", Vector3.new(0, (top - 0.4 - d) / 2, zc), Vector3.new(box.x * 2 - 1, top - 0.4 + d, zl - 1), C.stone)
	if boards then
		local w = 2
		for x = -box.x + T, box.x - T - 0.01, w do
			local wx = math.min(w, box.x - T - x)
			for _, piece in chop(ctx.rng, box.z0 + T, box.z1 - T, 6, 11) do
				block(ctx, "FloorBoard", Vector3.new(x + wx / 2, top - 0.2, (piece[1] + piece[2]) / 2), Vector3.new(wx - 0.05, 0.4, piece[2] - piece[1] - 0.05), jitter(ctx.rng, floorColor, 0.06), "plank")
			end
		end
	else
		for _, piece in chop(ctx.rng, box.z0 + T, box.z1 - T, 2.6, 3.8) do
			for _, half in { -1, 1 } do
				local wx = box.x - T
				block(ctx, "FloorSlab", Vector3.new(half * wx / 2, top - 0.2, (piece[1] + piece[2]) / 2), Vector3.new(wx - 0.1, 0.4, piece[2] - piece[1] - 0.1), jitter(ctx.rng, floorColor, 0.04), Enum.Material.Concrete)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- stepped shingle roof
-------------------------------------------------------------------------------------------------------------
-- a0/a1: the eaves across the ridge; b0/b1: the ends along it (overhangs included); alongX: the ridge runs along X.
type Roof = { top: number, a0: number, a1: number, b0: number, b1: number, steps: number, rise: number, alongX: boolean }

-- A block placed in the roof's own axes: `a` across the ridge, `b` along it.
local function rpart(ctx: Ctx, roof: Roof, name: string, a: number, b: number, y: number, sa: number, sy: number, sb: number, color: Color3, look: any?): Part
	if roof.alongX then
		return block(ctx, name, Vector3.new(b, y, a), Vector3.new(sb, sy, sa), color, look)
	end
	return block(ctx, name, Vector3.new(a, y, b), Vector3.new(sa, sy, sb), color, look)
end

local function steppedRoof(ctx: Ctx, roof: Roof)
	local run = (roof.a1 - roof.a0) / 2 / roof.steps
	local bl, bm = roof.b1 - roof.b0, (roof.b0 + roof.b1) / 2
	for i = 0, roof.steps - 1 do
		local y0 = roof.top + i * roof.rise
		local tint = C.roof:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.06)
		for _, side in { -1, 1 } do
			local outer = if side < 0 then roof.a0 + i * run else roof.a1 - i * run
			local inner = outer - side * run
			local lo, hi = math.min(outer, inner), math.max(outer, inner)
			for _, piece in chop(ctx.rng, roof.b0, roof.b1, 2.4, 4.6) do
				rpart(ctx, roof, "Roof", (lo + hi) / 2, (piece[1] + piece[2]) / 2, y0 + roof.rise / 2, hi - lo, roof.rise, piece[2] - piece[1], jitter(ctx.rng, tint, 0.08), "roof")
			end
			-- the drip edge: a dark line along each row of shingles
			rpart(ctx, roof, "RoofEdge", outer + side * 0.12, bm, y0 + 0.12, 0.3, 0.5, bl + 0.1, C.timber)
			-- barge boards over the shingle ends at both gables
			for _, bEnd in { roof.b0 - 0.22, roof.b1 + 0.22 } do
				rpart(ctx, roof, "Barge", (lo + hi) / 2, bEnd, y0 + roof.rise / 2 - 0.05, hi - lo + 0.12, roof.rise + 0.12, 0.44, C.timber)
			end
		end
	end
	local mid = (roof.a0 + roof.a1) / 2
	local yTop = roof.top + roof.steps * roof.rise
	rpart(ctx, roof, "RidgeBeam", mid, bm, yTop + 0.35, run * 1.8, 0.7, bl + 0.9, C.timber)
	rpart(ctx, roof, "RidgeCap", mid, bm, yTop + 0.85, run * 1.1, 0.3, bl + 1.1, C.roof:Lerp(Color3.new(0, 0, 0), 0.2), "roof")
	return run
end

-- Vertical boards filling a gable (at `at` along the ridge axis, between lo and hi across it) up under each step.
local function gableBoards(ctx: Ctx, roof: Roof, at: number, lo: number, hi: number, out: number)
	local run = (roof.a1 - roof.a0) / 2 / roof.steps
	local x = lo
	while x < hi - 0.01 do
		local w = math.min(1.25, hi - x)
		local c = x + w / 2
		local steps = math.min(math.floor(math.min(c - roof.a0, roof.a1 - c) / run), roof.steps)
		local h = steps * roof.rise
		if h > 0.05 then
			rpart(ctx, roof, "GableBoard", c, at, roof.top + h / 2, w - 0.07, h, T - 0.3, jitter(ctx.rng, C.board, 0.07), "plank")
		end
		x += w
	end
	-- a louvred vent high in the gable
	local vy = roof.top + roof.steps * roof.rise * 0.52
	local mid = (roof.a0 + roof.a1) / 2
	local face = at + out * (T / 2 - 0.05)
	rpart(ctx, roof, "VentFrame", mid, face, vy, 2.6, 2.4, 0.3, C.timber)
	deco(rpart(ctx, roof, "Vent", mid, face + out * 0.05, vy, 2.0, 1.8, 0.3, Color3.fromRGB(34, 28, 24)))
	for k = -1, 1 do
		deco(rpart(ctx, roof, "VentSlat", mid, face + out * 0.18, vy + k * 0.55, 2.0, 0.22, 0.12, C.timber))
	end
end

-------------------------------------------------------------------------------------------------------------
-- windows, lamps, small props
-------------------------------------------------------------------------------------------------------------
-- Board-and-batten shutter (w wide, h tall) centred at `cf` (-Z out).
local function shutter(ctx: Ctx, cf: CFrame, w: number, h: number)
	for k = 0, 2 do
		deco(blockAt(ctx, "Shutter", cf * CFrame.new(-w / 2 + (k + 0.5) * w / 3, 0, 0), Vector3.new(w / 3 - 0.06, h, 0.25), jitter(ctx.rng, C.shutter, 0.06), "plank"))
	end
	local dark = C.shutter:Lerp(Color3.new(0, 0, 0), 0.3)
	for _, sy in { -1, 1 } do
		deco(blockAt(ctx, "ShutterBatten", cf * CFrame.new(0, sy * h * 0.32, -0.17), Vector3.new(w - 0.2, 0.4, 0.12), dark, "plank"))
	end
	local len = math.sqrt((w - 0.5) ^ 2 + (h * 0.64) ^ 2)
	deco(blockAt(ctx, "ShutterBrace", cf * CFrame.new(0, 0, -0.17) * CFrame.Angles(0, 0, math.atan2(w - 0.5, h * 0.64)), Vector3.new(0.3, len, 0.1), dark, "plank"))
end

local FLOWERS = { Color3.fromRGB(210, 96, 110), Color3.fromRGB(232, 212, 120), Color3.fromRGB(226, 226, 220), Color3.fromRGB(160, 110, 190), Color3.fromRGB(226, 140, 90) }

-- A planter box (w wide) with leafy mounds and flowers, its middle at `cf`.
local function planter(ctx: Ctx, cf: CFrame, w: number)
	blockAt(ctx, "Planter", cf, Vector3.new(w, 1.0, 1.0), jitter(ctx.rng, C.board, 0.05), "plank")
	deco(blockAt(ctx, "Soil", cf * CFrame.new(0, 0.48, 0), Vector3.new(w - 0.25, 0.08, 0.75), C.soil))
	local n = math.max(2, math.floor(w / 0.85))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * w / n
		local s = ctx.rng:NextNumber(0.55, 0.85)
		deco(blockAt(ctx, "Leaves", cf * CFrame.new(x, 0.5 + s / 2, ctx.rng:NextNumber(-0.12, 0.12)), Vector3.one * s, jitter(ctx.rng, C.leaf, 0.12)))
		if i % 2 == 1 then
			deco(blockAt(ctx, "Flower", cf * CFrame.new(x + 0.1, 0.5 + s + 0.15, 0), Vector3.one * 0.38, FLOWERS[ctx.rng:NextInteger(1, #FLOWERS)]))
		end
	end
end

-- A window in a log wall: `cf` is the middle of the hole on the wall's centre line, its -Z facing out.
local function window(ctx: Ctx, cf: CFrame, w: number, h: number, flowers: boolean)
	local o = -T / 2
	local function part(name: string, off: Vector3, size: Vector3, color: Color3, look: any?)
		return blockAt(ctx, name, cf * CFrame.new(off), size, color, look)
	end
	part("Lintel", Vector3.new(0, h / 2 + 0.4, -0.1), Vector3.new(w + 2.4, 0.8, T + 0.5), C.timber)
	part("Sill", Vector3.new(0, -h / 2 - 0.2, -0.25), Vector3.new(w + 1.4, 0.4, T + 0.8), C.timber)
	for _, sx in { -1, 1 } do
		part("WindowPost", Vector3.new(sx * (w / 2 + 0.25), 0, -0.05), Vector3.new(0.5, h, T + 0.3), C.timber)
		deco(part("SillBracket", Vector3.new(sx * (w / 2 - 0.3), -h / 2 - 0.7, o - 0.3), Vector3.new(0.35, 0.6, 0.5), C.timber))
		shutter(ctx, cf * CFrame.new(sx * (w / 2 + 0.55 + w / 4), 0, o - 0.2), w / 2, h)
	end
	local glass = part("WindowGlass", Vector3.new(0, 0, 0.05), Vector3.new(w, h, 0.12), C.glass, Enum.Material.SmoothPlastic)
	glass.Transparency = 0.35
	deco(part("Mullion", Vector3.new(0, 0, -0.1), Vector3.new(0.28, h, 0.16), C.timber))
	deco(part("Mullion", Vector3.new(0, 0, -0.1), Vector3.new(w, 0.28, 0.16), C.timber))
	if flowers then
		planter(ctx, cf * CFrame.new(0, -h / 2 - 0.4 - 0.55, o - 0.75), w + 0.6)
	end
end

local function pointLight(parent: BasePart, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 210, 160)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

-- A small iron lantern hanging from a chain (amber glass, no neon: the hub's bloom blows neon up).
local function hangingLantern(ctx: Ctx, top: Vector3, drop: number, brightness: number?)
	deco(block(ctx, "Chain", top - Vector3.new(0, drop / 2, 0), Vector3.new(0.12, drop, 0.12), C.iron))
	local y = top.Y - drop
	deco(block(ctx, "LanternCap", Vector3.new(top.X, y - 0.2, top.Z), Vector3.new(1.0, 0.35, 1.0), C.iron))
	local core = deco(block(ctx, "LanternGlass", Vector3.new(top.X, y - 0.9, top.Z), Vector3.new(0.7, 1.0, 0.7), C.lamp, Enum.Material.SmoothPlastic))
	core.Transparency = 0.15
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			deco(block(ctx, "LanternBar", Vector3.new(top.X + sx * 0.38, y - 0.9, top.Z + sz * 0.38), Vector3.new(0.12, 1.1, 0.12), C.iron))
		end
	end
	deco(block(ctx, "LanternBase", Vector3.new(top.X, y - 1.5, top.Z), Vector3.new(0.9, 0.22, 0.9), C.iron))
	pointLight(core, 12, brightness or 0.35)
end

local function smoke(ctx: Ctx, at: Vector3)
	local spot = deco(block(ctx, "ChimneySmoke", at, Vector3.one, Color3.new(1, 1, 1)))
	spot.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(225, 225, 225), Color3.fromRGB(180, 180, 185))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 4
	e.Speed = NumberRange.new(2, 3)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = Vector3.new(1.2, 0.4, 0.8)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Parent = spot
end

local function barrel(ctx: Ctx, base: Vector3, h: number)
	local d = h * 0.72
	cylinder(ctx, "Barrel", base + Vector3.new(0, h / 2, 0), h, d, jitter(ctx.rng, C.board, 0.06), "plank")
	for _, f in { 0.18, 0.82 } do
		deco(cylinder(ctx, "Hoop", base + Vector3.new(0, h * f, 0), 0.22, d + 0.08, C.iron))
	end
	deco(cylinder(ctx, "BarrelLid", base + Vector3.new(0, h + 0.02, 0), 0.06, d - 0.25, C.timber))
end

local function crate(ctx: Ctx, cf: CFrame, s: number)
	blockAt(ctx, "Crate", cf, Vector3.one * s, jitter(ctx.rng, C.board, 0.07), "plank")
	for _, f in { -1, 1 } do
		deco(blockAt(ctx, "CrateBand", cf * CFrame.new(0, f * (s / 2 - 0.15), -s / 2 - 0.02), Vector3.new(s + 0.04, 0.3, 0.1), C.timber))
		deco(blockAt(ctx, "CrateBand", cf * CFrame.new(f * (s / 2 - 0.15), 0, -s / 2 - 0.02), Vector3.new(0.3, s + 0.04, 0.1), C.timber))
	end
	deco(blockAt(ctx, "CrateBrace", cf * CFrame.new(0, 0, -s / 2 - 0.04) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.28, s * 1.25, 0.08), C.timber))
end

-- Chop A Forest's sign style text on the -Z face of `part`.
local function signText(part: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.6
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(240, 206, 110), Color3.fromRGB(222, 128, 48))
	grad.Rotation = 90
	grad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(56, 32, 18)
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

-- A framed board (w x h) facing -Z at `cf`, with the TOOL SHOP / GARAGE text or the crossed-scythes badge.
local function signBoard(ctx: Ctx, cf: CFrame, w: number, h: number, text: string?)
	local board = blockAt(ctx, "SignBoard", cf, Vector3.new(w, h, 0.4), jitter(ctx.rng, C.board, 0.04), "plank")
	for _, s in { -1, 1 } do
		deco(blockAt(ctx, "SignFrame", cf * CFrame.new(0, s * (h / 2 - 0.15), -0.22), Vector3.new(w + 0.1, 0.3, 0.12), C.timber))
		deco(blockAt(ctx, "SignFrame", cf * CFrame.new(s * (w / 2 - 0.15), 0, -0.22), Vector3.new(0.3, h + 0.1, 0.12), C.timber))
	end
	if text then
		signText(board, text)
		return
	end
	local face = cf * CFrame.new(0, -0.1, -0.3)
	local handle = Color3.fromRGB(150, 104, 66)
	local blade = Color3.fromRGB(190, 196, 200)
	for _, sx in { -1, 1 } do
		local tilt = face * CFrame.Angles(0, 0, math.rad(sx * 40))
		deco(blockAt(ctx, "BadgeHandle", tilt, Vector3.new(0.3, h * 0.82, 0.12), handle))
		deco(blockAt(ctx, "BadgeBlade", tilt * CFrame.new(-sx * 0.6, h * 0.38, 0), Vector3.new(1.2, 0.36, 0.12), blade))
		deco(blockAt(ctx, "BadgeBlade", tilt * CFrame.new(-sx * 1.2, h * 0.3, 0), Vector3.new(0.36, 0.45, 0.12), blade))
		deco(blockAt(ctx, "BadgeGrip", tilt * CFrame.new(0, -h * 0.12, -0.02), Vector3.new(0.5, 0.22, 0.12), C.timber))
	end
end

-------------------------------------------------------------------------------------------------------------
-- doors that open when someone comes near
-------------------------------------------------------------------------------------------------------------
-- Each mover is kept relative to its group's sensor part, so the doors still work after the saved map moved the
-- building (MapStore moves every part of a piece together).
type Mover = { part: BasePart, closed: CFrame, open: CFrame, closedSize: Vector3?, openSize: Vector3? }
type Group = { sensor: BasePart, radius: number, movers: { Mover }, isOpen: boolean }
local groups: { Group } = {}
local running = false

local function anyoneNear(pos: Vector3, r: number): boolean
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - pos).Magnitude < r then
			return true
		end
	end
	return false
end

local function setOpen(g: Group, open: boolean)
	g.isOpen = open
	local info = TweenInfo.new(if open then 0.5 else 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, m in g.movers do
		local goal: { [string]: any } = { CFrame = g.sensor.CFrame * (if open then m.open else m.closed) }
		if m.closedSize and m.openSize then
			goal.Size = if open then m.openSize else m.closedSize
		end
		TweenService:Create(m.part, info, goal):Play()
	end
end

local function startDoors()
	if running or not RunService:IsRunning() then
		return
	end
	running = true
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, g in groups do
				if g.sensor:IsDescendantOf(workspace) then
					local near = anyoneNear(g.sensor.Position, g.radius)
					if near ~= g.isOpen then
						setOpen(g, near)
					end
				end
			end
		end
	end)
end

local function doorGroup(ctx: Ctx, sensorLocal: CFrame, radius: number): (Group, CFrame)
	local sensor = deco(blockAt(ctx, "DoorSensor", sensorLocal, Vector3.one, Color3.new(1, 1, 1)))
	sensor.Transparency = 1
	local g: Group = { sensor = sensor, radius = radius, movers = {}, isOpen = false }
	table.insert(groups, g)
	startDoors()
	return g, sensorLocal:Inverse()
end

-------------------------------------------------------------------------------------------------------------
-- the Tool Shop
-------------------------------------------------------------------------------------------------------------
-- The back wall stays where the displays RunBuilder puts in expect it (inner face at z 14.3, floor at 0.75, the
-- pedestals at x +-9); the room is wider, deeper toward the front and taller than the old cabin.
local SHOP: Box = { x = 21, z0 = -8.6, z1 = 15.7, floor = 0.75, rows = 9 }
local SHOP_DOOR = { hw = 4.2, rows = 7 }
local SHOP_WIN = { front = { -13.2, 13.2 }, w = 6, side = 4, sideW = 5 }
local PORCH = { z0 = -16.2, hx = 13.4 }

local function shopHoles(wall: string, r: number): { { number } }
	local out = {}
	if wall == "front" then
		if r < SHOP_DOOR.rows then
			table.insert(out, { -SHOP_DOOR.hw, SHOP_DOOR.hw })
		end
		if r >= 2 and r <= 5 then
			for _, x in SHOP_WIN.front do
				table.insert(out, { x - SHOP_WIN.w / 2, x + SHOP_WIN.w / 2 })
			end
		end
	elseif (wall == "left" or wall == "right") and r >= 2 and r <= 5 then
		table.insert(out, { SHOP_WIN.side - SHOP_WIN.sideW / 2, SHOP_WIN.side + SHOP_WIN.sideW / 2 })
	end
	return out
end

-- The door frame (posts, a heavy lintel on corbels, a stone threshold) and two iron-strapped plank leaves that
-- swing in.
local function shopDoor(ctx: Ctx)
	local zc, y, hw = SHOP.z0 + T / 2, SHOP.floor, SHOP_DOOR.hw
	local h = SHOP_DOOR.rows * ROW
	for _, sx in { -1, 1 } do
		block(ctx, "DoorPost", Vector3.new(sx * (hw + 0.45), y + h / 2, zc - 0.05), Vector3.new(0.9, h, T + 0.5), C.timber)
		block(ctx, "Corbel", Vector3.new(sx * (hw + 0.95), y + h - 0.4, zc - T / 2 - 0.45), Vector3.new(0.8, 0.8, 0.8), C.timber)
	end
	block(ctx, "DoorLintel", Vector3.new(0, y + h + 0.55, zc - 0.1), Vector3.new(2 * hw + 3.6, 1.1, T + 0.8), C.timber)
	block(ctx, "Threshold", Vector3.new(0, y - 0.15, zc - 0.3), Vector3.new(2 * hw + 1.6, 0.4, T + 1.2), jitter(ctx.rng, C.stone, 0.04), "stone")
	local g, inv = doorGroup(ctx, CFrame.new(0, y + 3, zc), 13)
	local lw = hw - 0.05
	local wood = C.board:Lerp(C.timber, 0.3)
	for _, sx in { -1, 1 } do
		local hinge = CFrame.new(sx * hw, y + h / 2, zc)
		local swing = CFrame.Angles(0, math.rad(if sx < 0 then -100 else 100), 0)
		local bits = {}
		for k = 0, 2 do
			table.insert(bits, { "DoorPlank", CFrame.new(-sx * (k + 0.5) * lw / 3, 0, 0), Vector3.new(lw / 3 - 0.05, h - 0.1, 0.35), jitter(ctx.rng, wood, 0.06), "plank" })
		end
		for _, f in { -0.3, 0.3 } do
			table.insert(bits, { "DoorBatten", CFrame.new(-sx * lw / 2, f * h, -0.24), Vector3.new(lw - 0.3, 0.55, 0.14), C.timber, "plank" })
			table.insert(bits, { "DoorStrap", CFrame.new(-sx * lw * 0.38, f * h, -0.34), Vector3.new(lw * 0.76, 0.22, 0.07), C.iron })
		end
		table.insert(bits, { "DoorHandle", CFrame.new(-sx * (lw - 0.55), -0.4, -0.32), Vector3.new(0.28, 1.0, 0.2), C.iron })
		for _, b in bits do
			local closed = hinge * b[2]
			local p = deco(blockAt(ctx, b[1], closed, b[3], b[4], b[5]))
			table.insert(g.movers, { part = p, closed = inv * closed, open = inv * hinge * swing * b[2] })
		end
	end
end

local function railing(ctx: Ctx, a: Vector3, b: Vector3, y: number)
	local d = b - a
	local len = d.Magnitude
	local mid = (a + b) / 2
	local rot = CFrame.lookAt(mid, mid + d) -- -Z along the rail
	local function rail(dy: number, s: number)
		blockAt(ctx, "Rail", rot * CFrame.new(0, 0, 0) + Vector3.new(0, y + dy - mid.Y, 0), Vector3.new(s, s, len), C.timber)
	end
	rail(3.0, 0.38)
	rail(0.55, 0.3)
	local n = math.max(1, math.floor(len / 1.0))
	for i = 1, n - 1 do
		local p = a + d * (i / n)
		deco(block(ctx, "Baluster", Vector3.new(p.X, y + 1.8, p.Z), Vector3.new(0.3, 2.3, 0.3), C.board:Lerp(C.timber, 0.4), "plank"))
	end
end

local function shopPorch(ctx: Ctx, withSign: boolean)
	local y, z1, z0, hx = SHOP.floor, SHOP.z0, PORCH.z0, PORCH.hx
	block(ctx, "PorchBase", Vector3.new(0, (y - 0.4 - 3) / 2, (z0 + z1) / 2), Vector3.new(2 * hx, y - 0.4 + 3, z1 - z0), jitter(ctx.rng, C.stone, 0.04), "stone")
	for z = z0, z1 - 0.01, 1.25 do
		local wz = math.min(1.25, z1 - z)
		for _, piece in chop(ctx.rng, -hx, hx, 6, 11) do
			block(ctx, "Deck", Vector3.new((piece[1] + piece[2]) / 2, y - 0.2, z + wz / 2), Vector3.new(piece[2] - piece[1] - 0.05, 0.4, wz - 0.06), jitter(ctx.rng, C.floor, 0.06), "plank")
		end
	end
	block(ctx, "DeckFascia", Vector3.new(0, y - 0.4, z0 - 0.12), Vector3.new(2 * hx + 0.2, 0.6, 0.25), C.timber)
	for k = 1, 2 do
		local top = y - k * 0.25
		block(ctx, "Step", Vector3.new(0, (top - 3) / 2, z0 - (k - 0.5) * 1.1), Vector3.new(9.6 + k * 0.6, top + 3, 1.1), jitter(ctx.rng, C.stone, 0.05), "stone")
	end
	-- posts with knee braces, the beam, the lean-to roof
	local pz, beamY = z0 + 0.65, y + 11.0
	for _, sx in { -1, 1 } do
		local px = sx * (hx - 0.65)
		block(ctx, "PostFoot", Vector3.new(px, y + 0.3, pz), Vector3.new(1.6, 0.6, 1.6), jitter(ctx.rng, C.stone, 0.05), "stone")
		block(ctx, "PorchPost", Vector3.new(px, (y + beamY) / 2, pz), Vector3.new(1.2, beamY - y, 1.2), C.timber)
		deco(blockAt(ctx, "KneeBrace", CFrame.new(px - sx * 1.1, beamY - 1.0, pz) * CFrame.Angles(0, 0, math.rad(sx * 45)), Vector3.new(0.45, 2.9, 0.45), C.timber))
		railing(ctx, Vector3.new(px - sx * 0.6, 0, pz), Vector3.new(sx * 4.9, 0, pz), y)
		railing(ctx, Vector3.new(px, 0, pz + 0.6), Vector3.new(px, 0, z1), y)
	end
	block(ctx, "PorchBeam", Vector3.new(0, beamY + 0.55, pz), Vector3.new(2 * hx + 0.8, 1.1, 1.3), C.timber)
	local roof = { top = beamY + 1.1, a0 = z0 - 0.9, a1 = z1, b0 = -hx - 1, b1 = hx + 1, steps = 3, rise = 0.7, alongX = true }
	local run = (roof.a1 - roof.a0) / 3
	for i = 0, 2 do
		local lo = roof.a0 + i * run
		local yy = roof.top + i * roof.rise
		for _, piece in chop(ctx.rng, roof.b0, roof.b1, 2.4, 4.6) do
			rpart(ctx, roof, "Roof", (lo + roof.a1) / 2, (piece[1] + piece[2]) / 2, yy + roof.rise / 2, roof.a1 - lo, roof.rise, piece[2] - piece[1], jitter(ctx.rng, C.roof, 0.08), "roof")
		end
		rpart(ctx, roof, "RoofEdge", lo - 0.12, 0, yy + 0.12, 0.3, 0.5, roof.b1 - roof.b0 + 0.1, C.timber)
		for _, bEnd in { roof.b0 - 0.22, roof.b1 + 0.22 } do
			rpart(ctx, roof, "Barge", lo + run / 2, bEnd, yy + roof.rise / 2, run + 0.1, roof.rise + 0.1, 0.44, C.timber)
		end
	end
	-- the hanging sign over the steps, and a lantern either side of it
	for _, sx in { -1, 1 } do
		deco(block(ctx, "SignChain", Vector3.new(sx * 2.4, beamY - 0.45, pz), Vector3.new(0.12, 0.9, 0.12), C.iron))
		hangingLantern(ctx, Vector3.new(sx * 7.5, beamY, pz), 1.0)
	end
	signBoard(ctx, CFrame.new(0, beamY - 2.4, pz), if withSign then 9 else 6, 3.1, if withSign then "TOOL SHOP" else nil)
end

-- Outside: the stone chimney up the left gable, firewood under the eave, barrels and crates by the porch, a rake
-- and a shovel by the door, planters either side of it.
local function shopYard(ctx: Ctx, top: number, ridge: number)
	local cx = -(SHOP.x + 1.5)
	local layers = math.ceil((ridge + 2) / 1.6)
	for i = 0, layers - 1 do
		local w = if i < 4 then 3.6 elseif i == layers - 1 then 3.3 else 2.8
		block(ctx, "Chimney", Vector3.new(cx - (if i < 4 then 0.2 else 0), -0.6 + i * 1.6 + 0.8, 11), Vector3.new(w, 1.6, w), jitter(ctx.rng, C.stone, 0.08), "stone")
	end
	block(ctx, "ChimneyCap", Vector3.new(cx, -0.6 + layers * 1.6 + 0.2, 11), Vector3.new(3.6, 0.4, 3.6), C.stone:Lerp(Color3.new(0, 0, 0), 0.25), "stone")
	smoke(ctx, Vector3.new(cx, -0.6 + layers * 1.6 + 1.2, 11))
	-- firewood: round logs stacked under the eave of the left wall
	for row = 0, 3 do
		for k = 0, 7 - (row % 2) do
			local z = -6.2 + k * 0.85 + (row % 2) * 0.42
			local p = blockAt(ctx, "Firewood", CFrame.new(-(SHOP.x + 1.3), 0.4 + row * 0.78, z), Vector3.new(2.2, 0.8, 0.8), jitter(ctx.rng, C.logEnd, 0.1), "log")
			p.Shape = Enum.PartType.Cylinder
		end
	end
	barrel(ctx, Vector3.new(-PORCH.hx - 1.6, 0, -13.4), 2.6)
	barrel(ctx, Vector3.new(-PORCH.hx - 1.3, 0, -11.2), 2.4)
	crate(ctx, CFrame.new(PORCH.hx + 1.7, 1.1, -13.2) * CFrame.Angles(0, math.rad(8), 0), 2.2)
	crate(ctx, CFrame.new(PORCH.hx + 1.6, 2.2 + 0.85, -13.1) * CFrame.Angles(0, math.rad(-12), 0), 1.7)
	crate(ctx, CFrame.new(PORCH.hx + 1.4, 0.8, -10.8), 1.6)
	-- planters either side of the door
	for _, sx in { -1, 1 } do
		planter(ctx, CFrame.new(sx * 6.4, SHOP.floor + 0.5, SHOP.z0 - 0.9), 2.4)
	end
	-- a rake and a shovel leaning on the left wall, in front of the firewood
	local wx = -(SHOP.x + 0.75)
	local rake = CFrame.new(wx, 2.6, -7.2) * CFrame.Angles(0, 0, math.rad(-12))
	deco(blockAt(ctx, "ToolHandle", rake, Vector3.new(0.22, 5.2, 0.22), C.board))
	deco(blockAt(ctx, "RakeHead", rake * CFrame.new(0, 2.6, 0), Vector3.new(0.25, 0.25, 1.8), C.iron))
	for k = -3, 3 do
		deco(blockAt(ctx, "RakeTine", rake * CFrame.new(0, 2.85, k * 0.27), Vector3.new(0.08, 0.4, 0.08), C.iron))
	end
	local shovel = CFrame.new(wx, 2.9, -8.0) * CFrame.Angles(0, 0, math.rad(-10))
	deco(blockAt(ctx, "ToolHandle", shovel, Vector3.new(0.22, 4.4, 0.22), C.board))
	deco(blockAt(ctx, "ShovelGrip", shovel * CFrame.new(0, 2.3, 0), Vector3.new(0.2, 0.2, 0.7), C.board))
	deco(blockAt(ctx, "ShovelBlade", shovel * CFrame.new(0, -2.5, 0), Vector3.new(0.12, 1.1, 0.9), C.metal:Lerp(C.iron, 0.4)))
	local _ = top
end

-- A shelf of goods against a side wall: `cf` is its middle on the floor, -Z facing the room.
local GOODS = { Color3.fromRGB(150, 176, 160), Color3.fromRGB(176, 120, 86), Color3.fromRGB(206, 186, 140), Color3.fromRGB(120, 140, 170), Color3.fromRGB(170, 96, 80) }
local function shelf(ctx: Ctx, cf: CFrame, w: number)
	for _, sx in { -1, 1 } do
		blockAt(ctx, "ShelfSide", cf * CFrame.new(sx * w / 2, 3.2, 0), Vector3.new(0.3, 6.4, 1.3), C.timber)
	end
	for _, sy in { 0.5, 2.6, 4.7, 6.4 } do
		blockAt(ctx, "ShelfBoard", cf * CFrame.new(0, sy, 0), Vector3.new(w, 0.22, 1.3), C.board, "plank")
		if sy < 6 then
			local x = -w / 2 + 0.5
			while x < w / 2 - 0.5 do
				local kind = ctx.rng:NextInteger(1, 3)
				local s = ctx.rng:NextNumber(0.6, 1.0)
				local c = GOODS[ctx.rng:NextInteger(1, #GOODS)]
				if kind == 1 then
					local jar = deco(blockAt(ctx, "Jar", cf * CFrame.new(x + s / 2, sy + 0.11 + s * 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(s * 1.2, s * 0.8, s * 0.8), c, Enum.Material.SmoothPlastic))
					jar.Shape = Enum.PartType.Cylinder
				elseif kind == 2 then
					deco(blockAt(ctx, "Sack", cf * CFrame.new(x + s / 2, sy + 0.11 + s * 0.55, 0), Vector3.new(s, s * 1.1, s * 0.9), Color3.fromRGB(196, 170, 128), Enum.Material.Fabric))
				else
					deco(blockAt(ctx, "Box", cf * CFrame.new(x + s / 2, sy + 0.11 + s * 0.4, 0), Vector3.new(s, s * 0.8, s), jitter(ctx.rng, C.board, 0.1), "plank"))
				end
				x += s + 0.25
			end
		end
	end
end

-- The shop counter against the front wall, right of the door: a board front with battens, a brass till, a ledger,
-- scales and a jar of seeds (owner, 27 Oct: "make the inside of the houses a bit better").
local function shopCounter(ctx: Ctx)
	local y = SHOP.floor
	local z = SHOP.z0 + T + 1.0
	local cx = 8.6
	local brass = Color3.fromRGB(176, 140, 64)
	block(ctx, "Counter", Vector3.new(cx, y + 1.5, z), Vector3.new(5.6, 3.0, 1.7), jitter(ctx.rng, C.board, 0.04))
	block(ctx, "CounterTop", Vector3.new(cx, y + 3.15, z + 0.1), Vector3.new(6.2, 0.3, 2.1), C.timber)
	for k = -2, 2 do
		deco(block(ctx, "CounterBatten", Vector3.new(cx + k * 1.3, y + 1.5, z + 0.88), Vector3.new(0.25, 2.8, 0.1), C.timber))
	end
	local ty = y + 3.3
	block(ctx, "Till", Vector3.new(cx - 1.6, ty + 0.45, z), Vector3.new(1.3, 0.9, 1.0), brass, Enum.Material.Metal)
	deco(block(ctx, "TillDrawer", Vector3.new(cx - 1.6, ty + 0.2, z + 0.52), Vector3.new(1.1, 0.25, 0.05), brass:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal))
	deco(block(ctx, "TillKeys", Vector3.new(cx - 1.6, ty + 0.92, z + 0.2), Vector3.new(1.0, 0.1, 0.5), Color3.fromRGB(230, 222, 200)))
	deco(block(ctx, "Ledger", Vector3.new(cx + 0.3, ty + 0.06, z + 0.1), Vector3.new(1.2, 0.12, 0.9), Color3.fromRGB(110, 40, 40)))
	deco(block(ctx, "LedgerPages", Vector3.new(cx + 0.3, ty + 0.13, z + 0.1), Vector3.new(1.1, 0.03, 0.8), Color3.fromRGB(236, 228, 206)))
	deco(block(ctx, "ScaleBase", Vector3.new(cx + 1.9, ty + 0.08, z - 0.1), Vector3.new(0.8, 0.15, 0.6), brass, Enum.Material.Metal))
	deco(block(ctx, "ScalePost", Vector3.new(cx + 1.9, ty + 0.6, z - 0.1), Vector3.new(0.12, 0.9, 0.12), brass, Enum.Material.Metal))
	deco(block(ctx, "ScaleBeam", Vector3.new(cx + 1.9, ty + 1.05, z - 0.1), Vector3.new(1.4, 0.08, 0.08), brass, Enum.Material.Metal))
	for _, sx in { -1, 1 } do
		deco(block(ctx, "ScalePan", Vector3.new(cx + 1.9 + sx * 0.65, ty + 0.75, z - 0.1), Vector3.new(0.6, 0.06, 0.6), brass, Enum.Material.Metal))
	end
	local jar = deco(blockAt(ctx, "SeedJar", CFrame.new(cx + 1.0, ty + 0.45, z - 0.55) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.9, 0.6, 0.6), Color3.fromRGB(150, 176, 150), Enum.Material.Glass))
	jar.Shape = Enum.PartType.Cylinder
	jar.Transparency = 0.3
end

-- Small things that make the room lived in: herb bundles and rope coils hanging from the tie beams, two more roof
-- purlins, a wall lamp on each side wall, a doormat.
local function shopDetails(ctx: Ctx, top: number)
	local y = SHOP.floor
	local n = 0
	for _, x in { -14, -7, 7, 14 } do
		for _, z in { -2, 9 } do
			n += 1
			local hang = top - 0.9
			deco(block(ctx, "String", Vector3.new(x, hang - 0.4, z), Vector3.new(0.08, 0.8, 0.08), C.timber))
			if n % 2 == 0 then
				deco(block(ctx, "Herbs", Vector3.new(x, hang - 1.3, z), Vector3.new(0.7, 1.1, 0.7), jitter(ctx.rng, Color3.fromRGB(104, 132, 70), 0.12), Enum.Material.Grass))
			else
				local coil = deco(blockAt(ctx, "RopeCoil", CFrame.new(x, hang - 1.4, z), Vector3.new(0.35, 1.2, 1.2), Color3.fromRGB(176, 146, 100), Enum.Material.Fabric))
				coil.Shape = Enum.PartType.Cylinder
			end
		end
	end
	for _, z in { -3.5, 10.5 } do
		block(ctx, "Purlin", Vector3.new(0, top - 0.45, z), Vector3.new(2 * (SHOP.x - T), 0.8, 0.8), C.timber)
	end
	for _, sx in { -1, 1 } do
		local wx = sx * (SHOP.x - T - 0.2)
		deco(block(ctx, "SconceBack", Vector3.new(wx, y + 7, 7.4), Vector3.new(0.2, 1.2, 0.8), C.timber))
		deco(block(ctx, "SconceArm", Vector3.new(wx - sx * 0.45, y + 7, 7.4), Vector3.new(0.7, 0.15, 0.15), C.iron))
		local glow = deco(block(ctx, "SconceGlass", Vector3.new(wx - sx * 0.8, y + 7.25, 7.4), Vector3.new(0.5, 0.7, 0.5), C.lamp, Enum.Material.SmoothPlastic))
		glow.Transparency = 0.15
		pointLight(glow, 12, 0.3)
	end
	deco(block(ctx, "Doormat", Vector3.new(0, y + 0.03, SHOP.z0 + T + 1.0), Vector3.new(5.5, 0.06, 1.6), Color3.fromRGB(120, 92, 60), Enum.Material.Fabric))
end

local function shopInside(ctx: Ctx, top: number)
	local y = SHOP.floor
	local zi0, zi1 = SHOP.z0 + T, SHOP.z1 - T
	local xi = SHOP.x - T
	-- a woven rug down the aisle
	deco(block(ctx, "Rug", Vector3.new(0, y + 0.04, (zi0 + zi1) / 2 - 1.5), Vector3.new(5.4, 0.08, zi1 - zi0 - 6), Color3.fromRGB(112, 52, 46), Enum.Material.Fabric))
	deco(block(ctx, "Rug", Vector3.new(0, y + 0.06, (zi0 + zi1) / 2 - 1.5), Vector3.new(3.8, 0.08, zi1 - zi0 - 7.6), Color3.fromRGB(150, 116, 70), Enum.Material.Fabric))
	-- tie beams front to back, a ridge beam and the chandelier
	for _, x in { -14, -7, 0, 7, 14 } do
		block(ctx, "TieBeam", Vector3.new(x, top - 0.45, (zi0 + zi1) / 2), Vector3.new(0.9, 0.9, zi1 - zi0), C.timber)
	end
	block(ctx, "Purlin", Vector3.new(0, top - 0.45, 3), Vector3.new(2 * xi, 0.8, 0.8), C.timber)
	local cy = top - 3
	deco(block(ctx, "Chain", Vector3.new(0, (top - 0.9 + cy) / 2, 3), Vector3.new(0.14, top - 0.9 - cy, 0.14), C.iron))
	for _, s in { -1, 1 } do
		deco(block(ctx, "ChandelierBar", Vector3.new(0, cy, 3 + s * 2), Vector3.new(4.4, 0.35, 0.35), C.timber))
		deco(block(ctx, "ChandelierBar", Vector3.new(s * 2, cy, 3), Vector3.new(0.35, 0.35, 4.4), C.timber))
	end
	local core: BasePart? = nil
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local c = deco(block(ctx, "Candle", Vector3.new(sx * 2, cy + 0.55, 3 + sz * 2), Vector3.new(0.4, 0.75, 0.4), C.lamp, Enum.Material.SmoothPlastic))
			core = core or c
		end
	end
	if core then
		pointLight(core, 26, 0.55)
	end
	-- shelves of goods on both side walls, barrels and crates in the front corners
	for _, sx in { -1, 1 } do
		for _, z in { -2.6, 10.6 } do
			shelf(ctx, CFrame.new(sx * (xi - 0.7), y, z) * CFrame.Angles(0, math.rad(sx * 90), 0), 4.4)
		end
		barrel(ctx, Vector3.new(sx * (xi - 1.2), y, zi0 + 1.2), 2.6)
	end
	crate(ctx, CFrame.new(-(xi - 3.2), y + 1, zi0 + 1.1) * CFrame.Angles(0, math.rad(10), 0), 2)
end

-- The Tool Shop at `at`. `withSign`: TOOL SHOP on the hanging sign (else a crossed-scythes badge).
function CampBuildings.shop(parent: Instance, at: CFrame, withSign: boolean?): boolean
	local building = Instance.new("Model")
	building.Name = "ShopBuilding"
	building.Parent = parent
	local ctx: Ctx = { parent = building, at = at, rng = Random.new(2710) }
	footing(ctx, SHOP, C.floor, true)
	logBox(ctx, SHOP, shopHoles)
	for _, x in SHOP_WIN.front do
		window(ctx, CFrame.new(x, SHOP.floor + 4 * ROW, SHOP.z0 + T / 2), SHOP_WIN.w, 4 * ROW, true)
	end
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(sx * (SHOP.x - T / 2), SHOP.floor + 4 * ROW, SHOP_WIN.side) * CFrame.Angles(0, math.rad(-90 * sx), 0)
		window(ctx, cf, SHOP_WIN.sideW, 4 * ROW, true)
	end
	shopDoor(ctx)
	local top = SHOP.floor + SHOP.rows * ROW
	local roof: Roof = { top = top, a0 = SHOP.z0 - 2.6, a1 = SHOP.z1 + 2.6, b0 = -SHOP.x - 2.4, b1 = SHOP.x + 2.4, steps = 12, rise = 0.85, alongX = true }
	steppedRoof(ctx, roof)
	for _, sx in { -1, 1 } do
		gableBoards(ctx, roof, sx * (SHOP.x - T / 2), SHOP.z0, SHOP.z1, sx)
	end
	shopPorch(ctx, withSign == true)
	shopYard(ctx, top, top + roof.steps * roof.rise)
	shopInside(ctx, top)
	shopCounter(ctx)
	shopDetails(ctx, top)
	-- a lantern post at each front corner of the porch, the lantern hanging toward the steps
	for _, sx in { -1, 1 } do
		Models.place("lantern_post", building, at * CFrame.new(sx * (PORCH.hx + 0.6), 0, PORCH.z0 - 1.6) * CFrame.Angles(0, math.rad(sx * 90), 0), 0.9, true)
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the Garage
-------------------------------------------------------------------------------------------------------------
-- The mower spawns in the middle (RunBuilder: at * (0, 2, 0)); the gas pump stands at CampBuildings.PUMP.
local GARAGE: Box = { x = 10, z0 = -9, z1 = 10, floor = 0.4, rows = 8 }
local GARAGE_DOOR = { hw = 7.4, rows = 6 }
local DECK = { z = 4.6, top = 2.0 } -- the work deck along the back (the camp's grass terrace rises under it)

local function garageHoles(wall: string, r: number): { { number } }
	if wall == "front" and r < GARAGE_DOOR.rows then
		return { { -GARAGE_DOOR.hw, GARAGE_DOOR.hw } }
	elseif (wall == "left" or wall == "right") and r >= 3 and r <= 4 then
		return { { -2.2, 2.2 } }
	end
	return {}
end

local function rollUpDoor(ctx: Ctx)
	local hw = GARAGE_DOOR.hw
	local bottom, top = GARAGE.floor, GARAGE.floor + GARAGE_DOOR.rows * ROW
	local zc = GARAGE.z0 + T / 2
	local z = GARAGE.z0 + T - 0.3
	-- the frame: posts, a heavy header on corbels, guide rails
	for _, sx in { -1, 1 } do
		block(ctx, "DoorPost", Vector3.new(sx * (hw + 0.45), (bottom + top) / 2, zc - 0.05), Vector3.new(0.9, top - bottom, T + 0.5), C.timber)
		block(ctx, "Corbel", Vector3.new(sx * (hw + 0.95), top - 0.4, GARAGE.z0 - 0.45), Vector3.new(0.8, 0.8, 0.8), C.timber)
		deco(block(ctx, "DoorRail", Vector3.new(sx * (hw - 0.15), (bottom + top) / 2, z + 0.25), Vector3.new(0.3, top - bottom, 0.4), C.iron))
	end
	block(ctx, "DoorHeader", Vector3.new(0, top + 0.6, zc - 0.1), Vector3.new(2 * hw + 3.6, 1.2, T + 0.8), C.timber)
	block(ctx, "DoorDrum", Vector3.new(0, top - 0.5, z + 0.45), Vector3.new(2 * hw, 1.0, 1.2), C.iron)
	-- metal slats that all roll up into the drum
	local g, inv = doorGroup(ctx, CFrame.new(0, 3, GARAGE.z0), 15)
	local w = 2 * hw - 0.3
	local h = top - 1.0 - bottom
	local n = 8
	local sh = h / n
	-- (turned on their long axis so the texture's ribs run across the door)
	local turn = CFrame.Angles(0, 0, math.rad(90))
	local slatOpen = CFrame.new(0, top - 1.0, z) * turn
	for i = 0, n - 1 do
		local closed = CFrame.new(0, bottom + (i + 0.5) * sh, z) * turn
		local slat = deco(blockAt(ctx, "RollDoor", closed, Vector3.new(sh - 0.06, w, 0.22), jitter(ctx.rng, C.metal, 0.03), "metal"))
		table.insert(g.movers, { part = slat, closed = inv * closed, open = inv * slatOpen, closedSize = slat.Size, openSize = Vector3.new(0.1, w, 0.22) })
	end
	local barClosed = CFrame.new(0, bottom + 0.25, z - 0.12)
	local bar = deco(blockAt(ctx, "RollDoorBar", barClosed, Vector3.new(w, 0.5, 0.3), C.stripe))
	table.insert(g.movers, { part = bar, closed = inv * barClosed, open = inv * CFrame.new(0, top - 1.3, z - 0.12) })
	local handleClosed = CFrame.new(0, bottom + 0.75, z - 0.25)
	local handle = deco(blockAt(ctx, "RollDoorHandle", handleClosed, Vector3.new(1.4, 0.25, 0.2), C.iron))
	table.insert(g.movers, { part = handle, closed = inv * handleClosed, open = inv * CFrame.new(0, top - 0.8, z - 0.25) })
end

-- A rolling tool cabinet: red body, drawer lines, handles, little wheels. `cf` is the middle of its foot.
local function toolCabinet(ctx: Ctx, cf: CFrame)
	local red = Color3.fromRGB(150, 56, 48)
	blockAt(ctx, "ToolCabinet", cf * CFrame.new(0, 2.0, 0), Vector3.new(2.6, 3.4, 1.6), red, Enum.Material.Metal)
	for k = 0, 4 do
		local dy = 0.75 + k * 0.62
		deco(blockAt(ctx, "Drawer", cf * CFrame.new(0, dy, -0.81), Vector3.new(2.4, 0.5, 0.05), red:Lerp(Color3.new(0, 0, 0), 0.18), Enum.Material.Metal))
		deco(blockAt(ctx, "DrawerPull", cf * CFrame.new(0, dy, -0.86), Vector3.new(1.0, 0.12, 0.08), C.metal, Enum.Material.Metal))
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			deco(blockAt(ctx, "Caster", cf * CFrame.new(sx * 1.05, 0.15, sz * 0.55), Vector3.new(0.3, 0.3, 0.3), C.iron))
		end
	end
end

-- More of a working garage (owner, 27 Oct: better insides): garden tools in a rack on the left wall, a shelf of
-- paint cans over the tyres, a green clippings bin by the door, seed sacks on the deck.
local function garageDetails(ctx: Ctx)
	local y = GARAGE.floor
	local xi = GARAGE.x - T
	-- the tool rack (front of the left wall)
	local rx = -(xi - 0.2)
	block(ctx, "ToolRack", Vector3.new(rx, y + 5.2, -6.2), Vector3.new(0.3, 0.4, 2.8), C.timber)
	block(ctx, "ToolRack", Vector3.new(rx, y + 1.0, -6.2), Vector3.new(0.3, 0.4, 2.8), C.timber)
	local tools = {
		{ -7.2, C.board, Vector3.new(0.25, 0.25, 1.3), C.iron }, -- rake
		{ -6.2, Color3.fromRGB(176, 140, 90), Vector3.new(0.4, 0.7, 1.0), Color3.fromRGB(196, 170, 110) }, -- broom
		{ -5.2, C.board, Vector3.new(0.12, 0.9, 0.8), C.metal:Lerp(C.iron, 0.4) }, -- spade
	}
	for _, t in tools do
		local cf = CFrame.new(rx + 0.45, y + 3.2, t[1]) * CFrame.Angles(0, 0, math.rad(-5))
		deco(blockAt(ctx, "ToolHandle", cf, Vector3.new(0.2, 5.0, 0.2), t[2]))
		deco(blockAt(ctx, "ToolHead", cf * CFrame.new(0, -2.6, 0), t[3], t[4]))
	end
	-- paint cans on a shelf over the tyres (right wall)
	local sx = xi - 0.5
	block(ctx, "Shelf", Vector3.new(sx, y + 5.0, -5.0), Vector3.new(1.0, 0.2, 3.4), C.timber)
	for k, c in { Color3.fromRGB(70, 120, 170), Color3.fromRGB(200, 180, 70), Color3.fromRGB(170, 70, 60), Color3.fromRGB(230, 230, 224) } do
		local can = deco(blockAt(ctx, "PaintCan", CFrame.new(sx, y + 5.45, -6.6 + k * 0.75) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.7, 0.62, 0.62), c, Enum.Material.Metal))
		can.Shape = Enum.PartType.Cylinder
	end
	-- the clippings bin by the door
	local bin = Color3.fromRGB(62, 120, 70)
	block(ctx, "ClippingsBin", Vector3.new(-6.4, y + 1.35, -6.6), Vector3.new(1.8, 2.7, 1.8), bin)
	block(ctx, "BinLid", Vector3.new(-6.4, y + 2.8, -6.55), Vector3.new(1.95, 0.2, 1.95), bin:Lerp(Color3.new(0, 0, 0), 0.2))
	deco(block(ctx, "BinGrass", Vector3.new(-6.4, y + 2.95, -6.5), Vector3.new(1.3, 0.25, 1.3), Color3.fromRGB(90, 160, 60), Enum.Material.Grass))
	-- seed sacks on the deck
	for k = 0, 1 do
		block(ctx, "SeedSack", Vector3.new(6.8, DECK.top + 0.8, 6.0 + k * 1.3), Vector3.new(1.4, 1.6, 1.1), jitter(ctx.rng, Color3.fromRGB(200, 176, 132), 0.05), Enum.Material.Fabric)
	end
end

local function garageInside(ctx: Ctx, top: number)
	local y = GARAGE.floor
	local xi, zb = GARAGE.x - T, GARAGE.z1 - T
	-- yellow bay lines and two old oil stains
	for _, sx in { -1, 1 } do
		deco(block(ctx, "BayLine", Vector3.new(sx * 4.8, y + 0.03, -1.5), Vector3.new(0.35, 0.06, 11), C.stripe))
	end
	for _, s in { { -1.2, -2.5, 2.2 }, { 1.6, 1.0, 1.4 } } do
		local stain = deco(blockAt(ctx, "OilStain", CFrame.new(s[1], y + 0.02, s[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.04, s[3], s[3] * 1.3), Color3.fromRGB(58, 58, 60)))
		stain.Shape = Enum.PartType.Cylinder
		stain.Transparency = 0.35
	end
	block(ctx, "Apron", Vector3.new(0, -0.9, GARAGE.z0 - 0.9), Vector3.new(2 * GARAGE.x, 2.2, 1.8), jitter(ctx.rng, C.stone, 0.04), "stone")
	-- the raised work deck along the back
	block(ctx, "WorkDeck", Vector3.new(0, (DECK.top - 0.3 - 0.6) / 2, (DECK.z + zb) / 2), Vector3.new(2 * xi, DECK.top - 0.3 + 0.6, zb - DECK.z), C.timber)
	for _, piece in chop(ctx.rng, -xi, xi, 3, 6) do
		block(ctx, "DeckBoard", Vector3.new((piece[1] + piece[2]) / 2, DECK.top - 0.15, (DECK.z + zb) / 2), Vector3.new(piece[2] - piece[1] - 0.05, 0.3, zb - DECK.z), jitter(ctx.rng, C.floor, 0.06), "plank")
	end
	-- workbench with drawers and a vise, a tool wall over it
	local by, bz = DECK.top, zb - 1.15
	block(ctx, "Workbench", Vector3.new(-3, by + 2.7, bz), Vector3.new(7, 0.45, 2.1), jitter(ctx.rng, C.board, 0.05), "plank")
	block(ctx, "BenchBody", Vector3.new(-5.2, by + 1.25, bz), Vector3.new(2.4, 2.5, 1.9), C.timber)
	for k = 0, 1 do
		deco(block(ctx, "DrawerPull", Vector3.new(-5.2, by + 0.8 + k * 1.0, bz - 0.98), Vector3.new(0.8, 0.14, 0.08), C.iron))
	end
	block(ctx, "BenchLeg", Vector3.new(0.3, by + 1.25, bz), Vector3.new(0.45, 2.5, 1.7), C.timber)
	deco(block(ctx, "Vise", Vector3.new(-1, by + 3.25, bz - 0.7), Vector3.new(0.9, 0.7, 1.0), Color3.fromRGB(70, 92, 140), Enum.Material.Metal))
	deco(block(ctx, "Pegboard", Vector3.new(-3, by + 5.6, zb - 0.06), Vector3.new(7.2, 3.6, 0.12), Color3.fromRGB(176, 150, 112), "plank"))
	local tools = {
		{ -5.8, Vector3.new(0.3, 2.2, 0.15), C.metal },
		{ -5.0, Vector3.new(0.5, 1.4, 0.15), Color3.fromRGB(160, 60, 52) },
		{ -4.0, Vector3.new(0.25, 2.6, 0.15), C.board },
		{ -3.1, Vector3.new(0.9, 0.35, 0.15), C.metal },
		{ -2.1, Vector3.new(0.35, 2.0, 0.15), C.metal },
		{ -1.2, Vector3.new(0.6, 1.0, 0.15), C.stripe },
		{ -0.3, Vector3.new(0.3, 1.8, 0.15), C.board },
	}
	for _, t in tools do
		deco(block(ctx, "PegTool", Vector3.new(t[1], by + 5.6, zb - 0.18), t[2], t[3], Enum.Material.Metal))
	end
	toolCabinet(ctx, CFrame.new(3.4, by, zb - 1.0))
	-- tyres and jerrycans in the corner
	for i = 0, 3 do
		local cf = CFrame.new(7, y + 0.35 + i * 0.72, -6.4) * CFrame.Angles(0, 0, math.rad(90))
		local tyre = blockAt(ctx, "Tyre", cf, Vector3.new(0.68, 2.6, 2.6), Color3.fromRGB(38, 38, 40), Enum.Material.Rubber)
		tyre.Shape = Enum.PartType.Cylinder
	end
	local hub = deco(blockAt(ctx, "TyreHub", CFrame.new(7, y + 0.35 + 3 * 0.72 + 0.02, -6.4) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.7, 1.2, 1.2), C.metal, Enum.Material.Metal))
	hub.Shape = Enum.PartType.Cylinder
	for k, c in { Color3.fromRGB(150, 56, 48), Color3.fromRGB(70, 110, 70) } do
		local cz = -3.6 + k * 1.1
		block(ctx, "Jerrycan", Vector3.new(7.9, y + 0.9, cz), Vector3.new(0.7, 1.8, 1.0), c, Enum.Material.Metal)
		deco(block(ctx, "JerrycanGrip", Vector3.new(7.9, y + 1.95, cz), Vector3.new(0.25, 0.3, 0.7), c, Enum.Material.Metal))
	end
	-- a hose reel on the left wall
	local reel = deco(blockAt(ctx, "HoseReel", CFrame.new(-(xi - 0.35), y + 4.6, -4), Vector3.new(0.6, 1.9, 1.9), Color3.fromRGB(70, 120, 76), Enum.Material.Rubber))
	reel.Shape = Enum.PartType.Cylinder
	-- rafters and a hanging shop lamp
	for _, z in { -5.5, -1, 3.5, 8 } do
		block(ctx, "TieBeam", Vector3.new(0, top - 0.45, z), Vector3.new(2 * xi, 0.9, 0.9), C.timber)
	end
	local ly = top - 2.6
	deco(block(ctx, "Chain", Vector3.new(0, (top - 0.9 + ly) / 2, -1), Vector3.new(0.12, top - 0.9 - ly, 0.12), C.iron))
	deco(block(ctx, "LampShade", Vector3.new(0, ly, -1), Vector3.new(1.6, 0.5, 1.6), Color3.fromRGB(70, 92, 84), Enum.Material.Metal))
	local bulb = deco(block(ctx, "LampBulb", Vector3.new(0, ly - 0.35, -1), Vector3.new(0.6, 0.3, 0.6), C.lamp, Enum.Material.SmoothPlastic))
	bulb.Name = "LampGlow"
	pointLight(bulb, 18, 0.5)
end

-- The Garage at `at` (the mower spawns in the middle, the roll-up door faces at.LookVector).
function CampBuildings.garage(parent: Instance, at: CFrame): boolean
	local building = Instance.new("Model")
	building.Name = "GarageBuilding"
	building.Parent = parent
	local ctx: Ctx = { parent = building, at = at, rng = Random.new(2711) }
	footing(ctx, GARAGE, Color3.fromRGB(150, 150, 146), false)
	logBox(ctx, GARAGE, garageHoles)
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(sx * (GARAGE.x - T / 2), GARAGE.floor + 4 * ROW, 0) * CFrame.Angles(0, math.rad(-90 * sx), 0)
		window(ctx, cf, 4.4, 2 * ROW, sx < 0)
	end
	rollUpDoor(ctx)
	local top = GARAGE.floor + GARAGE.rows * ROW
	local roof: Roof = { top = top, a0 = -GARAGE.x - 2.2, a1 = GARAGE.x + 2.2, b0 = GARAGE.z0 - 1.9, b1 = GARAGE.z1 + 1.9, steps = 10, rise = 0.85, alongX = false }
	steppedRoof(ctx, roof)
	gableBoards(ctx, roof, GARAGE.z0 + T / 2, -GARAGE.x, GARAGE.x, -1)
	gableBoards(ctx, roof, GARAGE.z1 - T / 2, -GARAGE.x, GARAGE.x, 1)
	-- the GARAGE board on the front gable, under the vent, on two brackets
	signBoard(ctx, CFrame.new(0, top + 1.9, GARAGE.z0 - 0.3), 8.4, 2.4, "GARAGE")
	for _, sx in { -1, 1 } do
		deco(block(ctx, "SignBracket", Vector3.new(sx * 3.2, top + 0.55, GARAGE.z0 - 0.3), Vector3.new(0.4, 0.5, 0.8), C.timber))
	end
	garageInside(ctx, top)
	garageDetails(ctx)
	-- outside: an oil drum and a crate by the side wall, a tyre leaning on it
	local drum = blockAt(ctx, "OilDrum", CFrame.new(-(GARAGE.x + 1.6), 1.4, -6.2) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(2.8, 1.9, 1.9), Color3.fromRGB(140, 58, 48), Enum.Material.Metal)
	drum.Shape = Enum.PartType.Cylinder
	crate(ctx, CFrame.new(-(GARAGE.x + 1.6), 1, -3.6) * CFrame.Angles(0, math.rad(-8), 0), 2)
	local tyre = blockAt(ctx, "Tyre", CFrame.new(GARAGE.x + 1.25, 1.3, 4) * CFrame.Angles(0, 0, math.rad(-12)), Vector3.new(0.7, 2.6, 2.6), Color3.fromRGB(38, 38, 40), Enum.Material.Rubber)
	tyre.Shape = Enum.PartType.Cylinder
	return true
end

return CampBuildings
