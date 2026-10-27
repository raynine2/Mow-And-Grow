-- CLUMP WOUNDS (owner, 28 Oct, about Chop A Forest's trees: every hit carves a hole right where you hit, the hole
-- grows with each hit, it's pale fresh wood inside with stepped edges, and at the end the top snaps off; "yes" to
-- the grass version. Round 2, same night: "make the hit look progressive to the tree, look at the video and check
-- every frame of it").
-- What the clip shows, frame by frame (120 fps): the hole is there on the very frame the fist lands, right where
-- the crosshair is; it is a lumpy blob, not a neat oval; pale wood in the middle, a stepped ring, a torn rim; lit
-- from above, so its top inner wall is in shade and its floor catches the light (that is what makes it read as a
-- hole); every hit makes it wider and taller, so after 4-5 hits it spans the trunk; a hit higher or lower starts a
-- second hole that grows into the first; at the end it wraps round and the top goes.
-- Our voxel clumps get the same on their stalk, drawn in voxels so it matches them. The stalk is a 3 x 3 voxel
-- column (6 voxels tall); the cut is drawn in half-voxels, so its skin unrolls into 24 columns all the way round
-- and 12 rows up the stalk:
--   * every hit adds to the wound under your crosshair (the side it came from, the height you aimed at); a hit
--     somewhere else starts a second wound there, and they grow into each other
--   * a wound is a lumpy blob on that unrolled skin that grows wider and taller with every hit (fast at first,
--     so even the first hit on a tough clump shows), until the wounds meet round the back and it falls
--   * its voxels come in three rings and three heights: the pale fresh middle sits lowest, the step next, the torn
--     rim stands proud; the upper inner wall is shaded and the lower one lit, and the middle has a faint grain
--   * each new voxel pops in white and settles to its colour, so every hit visibly lands; the wound leans, wobbles
--     and falls over with the clump (client/HitFx's lean carries it, client/Fx's falling copy takes it along)
-- Colours come from the area's real grass (shared/Zones palette: the voxel meshes are painted from it), or the
-- mutation's colour. Fed by the server's "chip" (client/Fx's chip handler). Only your own hits, only hand tools:
-- auto tools and mowers chip too many clumps at once. At most MAX_ACTIVE clumps carry a wound at a time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("MowALawn")
local Config = require(Shared:WaitForChild("Config"))
local Zones = require(Shared:WaitForChild("Zones")) :: any
local HitFx = require(script.Parent.HitFx)
local State = require(script.Parent.State)

local ClumpWound = {}
local player = Players.LocalPlayer

local CREAM = Color3.fromRGB(250, 246, 214) -- the inside of a fresh-cut stem
local PITH = Color3.fromRGB(240, 248, 206) -- (28 Oct) the pale lime-cream pith every cut shows
local WHITE = Color3.new(1, 1, 1)
local SHADE = Color3.fromRGB(26, 40, 30)
-- The cut is drawn in half-voxels (rounder than whole ones on a stalk only 3 voxels wide): 6 per face, 24 round.
local PER_FACE = 6
local COLS = PER_FACE * 4
local ROWS = 12 -- half-voxel rows up the 6-voxel stalk
local MAX_ACTIVE = 6
-- how far each ring stands off the bark (in stalk voxels): the pale middle lowest, the step next, the torn rim
-- highest, so it reads as a bowl
local RAISE = { [0] = 0.02, [1] = 0.11, [2] = 0.23 }
local NORMALS = { Vector3.zAxis, Vector3.xAxis, -Vector3.zAxis, -Vector3.xAxis }

type Side = { g: number, row: number, cut: number, seed: number, sa: number, sb: number }
-- (28 Oct, council: "every weapon a different wound") how each hand tool's cut is shaped: wider round the stalk
-- (sa) or taller (sb). Fists punch a round bite, scissors a neat small snip, the sickle a wide curved bite, the
-- Mega Scythe a long low band.
local SHAPE: { [string]: { number } } = {
	Hands = { 1, 1 },
	Scissors = { 0.8, 0.78 },
	Sickle = { 1.3, 0.72 },
	MegaScythe = { 1.65, 0.55 },
}
type Cell = { part: BasePart, rank: number, tone: number }
type Tones = { floorLit: Color3, floor: Color3, grain: Color3, floorShade: Color3, stepLit: Color3, stepShade: Color3, rimLit: Color3, rimShade: Color3 }
type Wound = { sides: { Side }, cells: { [number]: Cell }, r0: number, v: number, R: number, tones: Tones }
local wounds: { [Model]: Wound } = {}
local active = 0

local function luma(c: Color3): number
	return 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
end

local function mul(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- The colour the area's clumps are painted (the voxel meshes share one texture, painted from the Zones palette).
local function grassOf(z: number?, mut: string?, fallback: Color3?): Color3
	if mut and mut ~= "None" then
		local m = Config.mutation(mut)
		if m and m.color then
			return m.color
		end
	end
	local def = Zones.list and Zones.list[z or 1]
	local pal = def and def.palette
	if pal and pal.grass and pal.grass[1] then
		return pal.grass[1]
	end
	local zone = Config.ZONES[z or 1] or Config.ZONES[1]
	return fallback or zone.tint or zone.grass[1]
end

local function tones(base: Color3): Tones
	-- (28 Oct, council round: "the inside must be the brightest thing on the clump, never darker than the stalk")
	-- the fresh inside of a cut grass stem is one pale lime-cream pith in every area, a touch of the area's colour
	-- in it; the walls a step darker; a dark rim line round the cut fakes the shadow at its edge (like Chop's dark
	-- bark round pale wood). All baked into colours, so it reads the same on low graphics.
	local inside = PITH:Lerp(base, 0.14)
	local _ = luma
	return {
		floorLit = inside:Lerp(WHITE, 0.25), -- the floor of the cut catches the light
		floor = inside,
		grain = mul(inside, 0.92), -- faint fibres running up the stem
		floorShade = mul(inside, 0.85), -- the top inner wall, a step darker (still far lighter than the stalk)
		stepLit = inside:Lerp(base, 0.35),
		stepShade = mul(inside:Lerp(base, 0.45), 0.86),
		rimLit = mul(base, 0.86), -- the torn rim: a darker line round the cut
		rimShade = mul(base, 0.68),
	}
end

-- distance between two columns round the stalk
local function circ(a: number, b: number): number
	local d = math.abs(a - b) % COLS
	return math.min(d, COLS - d)
end

-- a fixed little bump per cell and wound (-1..1): the lumpy edge of a torn cut
local function bump(g: number, row: number, seed: number): number
	local h = math.sin(g * 12.9898 + row * 78.233 + seed * 37.719) * 43758.5453
	return (h - math.floor(h)) * 2 - 1
end

-- The column (0..23) a hit from local direction (lx, lz) lands on: 6 per face, faces +Z, +X, -Z, -X in turn, each
-- counted toward the next face so the columns run on round the corners.
local function columnOf(lx: number, lz: number, R: number, v: number): number
	local face
	if math.abs(lz) >= math.abs(lx) then
		face = if lz > 0 then 0 else 2
	else
		face = if lx > 0 then 1 else 3
	end
	local s = math.max(math.abs(lx), math.abs(lz), 1e-4)
	local onSkin = Vector3.new(lx / s * R, 0, lz / s * R)
	local tc = onSkin:Dot(NORMALS[(face + 1) % 4 + 1])
	return face * PER_FACE + math.clamp(math.floor((tc + R) / (v / 2)), 0, PER_FACE - 1)
end

-- Where a wound voxel sits in the clump's upright pose, and its size.
local function cellPose(w: Wound, g: number, row: number, rank: number): (CFrame, Vector3)
	local v, R = w.v, w.R
	local h = v / 2 -- a half-voxel cell
	local face, i = g // PER_FACE, g % PER_FACE
	local n = NORMALS[face + 1]
	local t = NORMALS[(face + 1) % 4 + 1]
	local raise = RAISE[rank] * v
	local thick = raise + 0.06 * v -- sunk a little into the bark, so no gap shows
	local pos = n * (R + raise - thick / 2) + t * (-R + (i + 0.5) * h) + Vector3.new(0, (row + 0.5) * h, 0)
	return CFrame.lookAt(pos, pos + n), Vector3.new(h * 1.04, h * 1.04, thick)
end

-- tone ids: 1 floor lit, 2 floor, 3 grain, 4 floor shade, 5 step lit, 6 step shade, 7 rim lit, 8 rim shade
local function toneColor(tn: Tones, id: number): Color3
	return if id == 1 then tn.floorLit
		elseif id == 2 then tn.floor
		elseif id == 3 then tn.grain
		elseif id == 4 then tn.floorShade
		elseif id == 5 then tn.stepLit
		elseif id == 6 then tn.stepShade
		elseif id == 7 then tn.rimLit
		else tn.rimShade
end

-- `up`: where the cell sits in its wound, -1 (bottom edge) .. 1 (top edge)
-- `big`: the wound is tall enough to show a shaded top wall (a small first bite is all bright pith)
local function toneFor(rank: number, up: number, g: number, row: number, big: boolean?): number
	if rank == 0 then
		if big and up > 0.42 then
			return 4 -- the top inner wall, in shade
		elseif up < -0.3 then
			return 1 -- the floor, lit
		end
		return if (g + row // 3) % 3 == 0 then 3 else 2 -- fibres running up the stem
	elseif rank == 1 then
		return if big and up > 0.05 then 6 else 5
	end
	return if up > 0.15 then 8 else 7
end

local function addCell(m: Model, w: Wound, key: number, rank: number, tone: number)
	local g, row = key // 16, key % 16
	local rel, size = cellPose(w, g, row, rank)
	local p = Instance.new("Part")
	p.Name = "Wound"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local color = toneColor(w.tones, tone)
	HitFx.attach(m, p, rel, size) -- (before it's parented: the lean remembers its full size, not the pop-in one)
	-- pop in: small and white-hot, then out to full size and its own colour (the fresh cut, just made)
	p.Size = size * Vector3.new(0.35, 0.35, 1)
	p.Color = color:Lerp(WHITE, 0.75)
	p.Parent = m
	TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = color }):Play()
	local old = w.cells[key]
	if old then
		old.part:Destroy()
	end
	w.cells[key] = { part = p, rank = rank, tone = tone }
end

-- How far a wound has spread for how much of the clump it has cut: quick at first (the first hit on a tough clump
-- still shows a proper bite), then on round the stalk.
local function spread(cut: number): (number, number)
	-- (tuned in play, 28 Oct, then the council: "front-load it": even the first hit on a 10-hit clump opens a real
	-- bite, about half the face with its rim; mid-way it spans the face; at the end it wraps round)
	local c = math.clamp(cut * 1.04, 0, 1)
	return 2.0 + 8.4 * c ^ 1.25, 1.9 + 3.3 * c ^ 1.1 -- round the stalk (columns), up and down (rows)
end

local function draw(m: Model, w: Wound)
	local want: { [number]: number } = {}
	local wantUp: { [number]: number } = {}
	local wantBig: { [number]: boolean } = {}
	for _, s in w.sides do
		local a, b = spread(s.cut)
		a, b = a * s.sa, b * s.sb
		for g = 0, COLS - 1 do
			local dg = circ(g, s.g)
			if dg <= a + 1 then
				for row = 1, ROWS - 1 do
					local dr = row - s.row
					local e = math.sqrt((dg / a) ^ 2 + (dr / b) ^ 2) * (1 + 0.15 * bump(g, row, s.seed))
					if e <= 1 then
						local rank = if e < 0.45 then 0 elseif e < 0.76 then 1 else 2
						local key = g * 16 + row
						if want[key] == nil or rank < want[key] then
							want[key] = rank
							wantUp[key] = math.clamp(dr / b, -1, 1)
							wantBig[key] = b >= 2.6
						end
					end
				end
			end
		end
	end
	for key, rank in want do
		local cell = w.cells[key]
		local tone = toneFor(rank, wantUp[key], key // 16, key % 16, wantBig[key])
		if not cell or rank < cell.rank then
			addCell(m, w, key, rank, tone) -- new, or cut deeper: a paler, lower voxel
		elseif cell.tone ~= tone and cell.rank == rank then
			-- the wound grew past it: its shading moves with the new shape (top wall / floor)
			cell.tone = tone
			cell.part.Color = toneColor(w.tones, tone)
		end
	end
end

-- Is the player cutting with an auto tool or a mower?
local function autoCutting(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then
		return true
	end
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ToolId")
	if not id then
		return false
	end
	for _, t in Config.TOOLS do
		if t.id == id and t.kind == "auto" then
			return true
		end
	end
	return false
end

local function forget(m: Model)
	if wounds[m] then
		wounds[m] = nil
		active -= 1
	end
end

-- The half-voxel row your crosshair is on, where the view line meets the stalk (nil when you aren't looking at it:
-- the other clumps a wide swing catches get their cut at chest height).
local function aimRow(base: CFrame, w: Wound): number?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local eye, look = cam.CFrame.Position, cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local to = Vector3.new(base.X - eye.X, 0, base.Z - eye.Z)
	if flat.Magnitude < 0.05 or to.Magnitude < 0.05 then
		return nil
	end
	-- looking at this stalk? (within its width, seen from here)
	local off = to.Magnitude * math.sqrt(math.max(0, 1 - (to.Unit:Dot(flat.Unit)) ^ 2))
	if to.Unit:Dot(flat.Unit) < 0.5 or off > w.R + 1.2 then
		return nil
	end
	local t = math.max(0, to.Magnitude - w.R) / flat.Magnitude
	local y = eye.Y + look.Y * t - base.Y
	return math.clamp(math.floor(y / (w.v / 2)), 2, ROWS - 3)
end

-- A hit that didn't cut the clump down yet (the server's "chip": model, from, dealt, max, z, mut).
function ClumpWound.hit(d)
	local m = d.model
	if typeof(m) ~= "Instance" or not m:IsA("Model") or not m.Parent then
		return
	end
	local R = m:GetAttribute("Stalk")
	if type(R) ~= "number" or R <= 0 or typeof(d.from) ~= "Vector3" or not d.max or d.max <= 0 or autoCutting() then
		return
	end
	local w = wounds[m]
	if not w then
		if active >= MAX_ACTIVE then
			for other in wounds do
				if not other.Parent then
					forget(other)
				end
			end
			if active >= MAX_ACTIVE then
				return
			end
		end
		local hgt = m:GetAttribute("Height")
		local v = R / 1.5
		-- without an aim, the cut sits at chest height, where your fist lands (server/Field puts the hits there too)
		local lift = math.min((if type(hgt) == "number" then hgt else 7) * 0.17, 2.8)
		w = { sides = {}, cells = {}, r0 = math.clamp(math.floor(lift / (v / 2)) + 2, 4, 9), v = v, R = R, tones = tones(grassOf(d.z, d.mut, d.color)) }
		wounds[m] = w
		active += 1
		m.AncestryChanged:Connect(function(_, parent)
			if not parent then
				forget(m)
			end
		end)
	end
	local base = HitFx.base(m)
	local rel = base:VectorToObjectSpace(Vector3.new(d.from.X - base.X, 0, d.from.Z - base.Z))
	local g = columnOf(rel.X, rel.Z, w.R, w.v)
	local row = aimRow(base, w) or w.r0
	local side: Side? = nil
	for _, s in w.sides do
		if circ(s.g, g) <= 4 and math.abs(s.row - row) <= 2 then
			side = s
			break
		end
	end
	if not side then
		local char = player.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		local shape = SHAPE[tool and tool:GetAttribute("ToolId") or "Hands"] or SHAPE.Hands
		side = { g = g, row = row, cut = 0, seed = math.random() * 100, sa = shape[1], sb = shape[2] }
		table.insert(w.sides, side :: Side)
	end
	local s = side :: Side
	s.cut += (if type(d.dealt) == "number" then d.dealt else d.max * 0.25) / d.max
	draw(m, w)
end

-- (28 Oct, council: "give the stump something to look at") the stump you leave: a ring of darker fibre bundles
-- round a hollow core on its pale cut face (grass stems are tubes; Chop's stumps show rings). Only for clumps you
-- cut; the dots are parented to the stump, so they go when it regrows.
local function ringStump(stub: BasePart, tn: Tones)
	local v = stub.Size.Y / 2 -- the stubble is two voxels tall
	local rot = stub.CFrame.Rotation
	local top = stub.Position + Vector3.new(0, stub.Size.Y / 2 + 0.02, 0)
	local function dot(off: Vector3, s: number, color: Color3, delay: number)
		local p = Instance.new("Part")
		p.Name = "StumpRing"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = Vector3.new(0.02, 0.05, 0.02)
		p.CFrame = CFrame.new(top + rot:VectorToWorldSpace(off)) * rot
		p.Parent = stub
		TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), { Size = Vector3.new(s, 0.05, s) }):Play()
	end
	dot(Vector3.zero, v * 0.62, mul(tn.floor, 0.7), 0) -- the hollow core
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		dot(Vector3.new(math.cos(a), 0, math.sin(a)) * v * 1.02, v * 0.26, mul(tn.floor, 0.8), 0.04 * i)
	end
end

State.on("fx", function(kind, d)
	if kind ~= "fell" or type(d) ~= "table" or d.by ~= player.UserId then
		return
	end
	local m = d.model
	local patch = typeof(m) == "Instance" and m.Parent
	if not patch then
		return
	end
	local w = wounds[m]
	local tn = if w then w.tones else tones(grassOf(d.z, d.mut, d.color))
	task.spawn(function()
		local deadline = os.clock() + 3
		while os.clock() < deadline and patch.Parent do
			for _, ch in patch:GetChildren() do
				if ch:IsA("BasePart") and ch.Name:sub(1, 8) == "Stubble_" then
					ringStump(ch, tn)
					return
				end
			end
			task.wait(0.1)
		end
	end)
end)

return ClumpWound
