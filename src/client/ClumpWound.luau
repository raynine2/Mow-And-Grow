-- CLUMP WOUNDS (owner, 28 Oct, about Chop A Forest's trees: every hit carves a hole right where you hit, the hole
-- grows with each hit, it's pale fresh wood inside with stepped edges, and at the end the top snaps off; "yes" to
-- the grass version).
-- Our voxel clumps get the same on their stalk, drawn in voxels so it matches them. The stalk is a 3 x 3 voxel
-- column; the cut is drawn in half-voxels, so its skin unrolls into 24 columns all the way round:
--   * every hit adds to the wound on the side it came from; a hit from another side starts a second wound there
--   * a wound is an oval on that unrolled skin that grows wider (round the stalk) and taller with every hit, until
--     the wounds meet round the back: a pale band, the stalk nearly through, and then it falls
--   * its voxels come in three soft tones and three heights: the pale fresh middle sits lowest and the torn green
--     rim stands proud, so it reads as a bowl cut into the stem (Chop's stepped edges)
--   * each new voxel pops in, and the wound leans, wobbles and falls over with the clump (client/HitFx's lean
--     carries it, client/Fx's falling copy takes it along)
-- Fed by the server's "chip" (client/Fx's chip handler). Only your own hits, only hand tools: auto tools and mowers
-- chip too many clumps at once. At most MAX_ACTIVE clumps carry a wound at a time (cheap on phones).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local HitFx = require(script.Parent.HitFx)

local ClumpWound = {}
local player = Players.LocalPlayer

local CREAM = Color3.fromRGB(246, 242, 206) -- the inside of a fresh-cut stem
-- The cut is drawn in half-voxels (rounder than whole ones on a stalk only 3 voxels wide): 6 per face, 24 round.
local PER_FACE = 6
local COLS = PER_FACE * 4
local MAX_ACTIVE = 6
-- how far each ring stands off the bark (in stalk voxels): the pale middle lowest, the step next, the shaded lip of
-- the bark highest, so it reads as a bowl
local RAISE = { [0] = 0.02, [1] = 0.08, [2] = 0.18 }
local NORMALS = { Vector3.zAxis, Vector3.xAxis, -Vector3.zAxis, -Vector3.xAxis }

type Side = { g: number, cut: number }
type Cell = { part: BasePart, rank: number }
type Tones = { pith: Color3, fiber: Color3, stepLit: Color3, stepShade: Color3, lipLit: Color3, lipShade: Color3 }
type Wound = { sides: { Side }, cells: { [number]: Cell }, r0: number, v: number, R: number, tones: Tones }
local wounds: { [Model]: Wound } = {}
local active = 0

local function tones(z: number?, mut: string?): Tones
	local zone = Config.ZONES[z or 1] or Config.ZONES[1]
	local grass: Color3 = zone.tint or zone.grass[1]
	if mut and mut ~= "None" then
		local m = Config.mutation(mut)
		if m and m.color then
			grass = m.color
		end
	end
	local shade = Color3.fromRGB(24, 46, 22)
	-- lit from above: the upper side of the cut is in shadow, the lower side catches the light (that's what makes
	-- it read as a hollow); the fresh middle has faint stem fibres
	return {
		pith = grass:Lerp(CREAM, 0.8),
		fiber = grass:Lerp(CREAM, 0.68),
		stepLit = grass:Lerp(CREAM, 0.55),
		stepShade = grass:Lerp(shade, 0.22),
		lipLit = grass:Lerp(CREAM, 0.18),
		lipShade = grass:Lerp(shade, 0.5),
	}
end

-- distance between two columns round the stalk
local function circ(a: number, b: number): number
	local d = math.abs(a - b) % COLS
	return math.min(d, COLS - d)
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

local function addCell(m: Model, w: Wound, key: number, rank: number)
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
	local dr = row - w.r0
	local tn = w.tones
	p.Color = if rank == 0 then (if (g + row * 2) % 5 == 0 then tn.fiber else tn.pith)
		elseif rank == 1 then (if dr > 0 then tn.stepShade else tn.stepLit)
		else (if dr >= 0 then tn.lipShade else tn.lipLit)
	HitFx.attach(m, p, rel, size) -- (before it's parented: the lean remembers its full size, not the pop-in one)
	-- pop in
	p.Size = size * Vector3.new(0.35, 0.35, 1)
	p.Parent = m
	TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()
	local old = w.cells[key]
	if old then
		old.part:Destroy()
	end
	w.cells[key] = { part = p, rank = rank }
end

local function draw(m: Model, w: Wound)
	local want: { [number]: number } = {}
	for _, s in w.sides do
		local c = math.clamp(s.cut * 1.1, 0, 1)
		local a = 1.4 + 8.6 * c -- round the stalk (half-voxel columns)
		local b = 1.4 + 3.2 * c -- up and down (half-voxel rows)
		for g = 0, COLS - 1 do
			local dg = circ(g, s.g)
			if dg <= a then
				for row = 2, 11 do -- the stalk's half-voxel rows above its foot, below the leaves
					local dr = row - w.r0
					local e = math.sqrt((dg / a) ^ 2 + (dr / b) ^ 2)
					if e <= 1 then
						local rank = if e < 0.42 then 0 elseif e < 0.74 then 1 else 2
						local key = g * 16 + row
						if want[key] == nil or rank < want[key] then
							want[key] = rank
						end
					end
				end
			end
		end
	end
	for key, rank in want do
		local cell = w.cells[key]
		if not cell or rank < cell.rank then
			addCell(m, w, key, rank) -- new, or cut deeper: a paler, lower voxel
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
		-- the cut sits at chest height, where your fist lands (server/Field puts the hits there too)
		local lift = math.min((if type(hgt) == "number" then hgt else 7) * 0.17, 2.8)
		w = { sides = {}, cells = {}, r0 = math.clamp(math.floor(lift / (v / 2)) + 2, 4, 9), v = v, R = R, tones = tones(d.z, d.mut) }
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
	local side: Side? = nil
	for _, s in w.sides do
		if circ(s.g, g) <= 4 then
			side = s
			break
		end
	end
	if not side then
		side = { g = g, cut = 0 }
		table.insert(w.sides, side :: Side)
	end
	local s = side :: Side
	s.cut += (if type(d.dealt) == "number" then d.dealt else d.max * 0.25) / d.max
	draw(m, w)
end

return ClumpWound
