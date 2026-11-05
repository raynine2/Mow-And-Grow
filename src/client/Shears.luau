-- THE GOLDEN SHEARS (Films v2, 5 Nov 2026): Rayan's weapon, a pair of giant gold hedge shears built from parts in the
-- game's blocky style, for the films only (this client). Two halves cross at a pivot bolt; each half is a long gold
-- shaft with a black grip at the hand end and a broad blade beyond the pivot, a white-hot edge on the side that cuts.
--   Shears.new(parent?) -> Shears
--   sh:grip2(rh, lh, fwd)            held in two hands (wrist points, world): the handles run from the hands to the
--                                    pivot, so spreading the hands opens the blades, bringing them together shuts them
--   sh:hold(at, dir, up, open?)      held in one hand at `at` (world), the shears pointing along `dir`, open degrees
--   sh:place(pivot, open)            put the pivot frame (LookVector = the blades' way, UpVector = the bolt's axis)
--   sh:trail(on) / sh:glow(k) / sh:tips() -> (Vector3, Vector3) / sh:show(on) / sh:destroy()
local Shears = {}

local GOLD = Color3.fromRGB(255, 194, 62)
local GOLD_DARK = Color3.fromRGB(196, 132, 34)
local EDGE = Color3.fromRGB(255, 246, 214)
local GRIP = Color3.fromRGB(28, 22, 30)
local HANDLE = 2.0 -- hand to pivot
local BLADE = 4.6 -- pivot to tip
local STACK = 0.08 -- each half sits this far off the middle, along the bolt
Shears.HANDLE = HANDLE
Shears.BLADE = BLADE

local function part(model: Model, size: Vector3, color: Color3, material: Enum.Material, kind: string?): BasePart
	local p: BasePart = if kind == "wedge" then Instance.new("WedgePart") elseif kind == "cyl" then Instance.new("Part") else Instance.new("Part")
	if kind == "cyl" then
		(p :: Part).Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- One half, in its own frame: the pivot at the origin, the blade toward -Z, the handle toward +Z, the bolt along Y,
-- the cutting edge on the +X side (`edgeSide` -1 puts it on -X, for the other half).
local function half(model: Model, edgeSide: number): ({ BasePart }, { CFrame }, BasePart)
	local parts, rels = {}, {}
	local function add(p: BasePart, rel: CFrame)
		table.insert(parts, p)
		table.insert(rels, rel)
	end
	local w = 0.66 -- blade width at the root
	local t = 0.13 -- blade thickness (along the bolt)
	local body = BLADE - 1.5
	-- the blade's body, a little narrower toward the tip side (two steps), then the point
	add(part(model, Vector3.new(w, t, body * 0.55), GOLD, Enum.Material.Metal), CFrame.new(0, 0, -(0.25 + body * 0.275)))
	add(part(model, Vector3.new(w * 0.86, t, body * 0.45), GOLD, Enum.Material.Metal), CFrame.new(-edgeSide * w * 0.07, 0, -(0.25 + body * 0.55 + body * 0.225)))
	-- the point: a wedge laid flat (its triangle in the blade's plane), the long side on the cutting edge
	local tip = part(model, Vector3.new(t, w * 0.86, 1.5), GOLD, Enum.Material.Metal, "wedge")
	add(tip, CFrame.new(-edgeSide * w * 0.07, 0, -(0.25 + body + 0.75)) * CFrame.Angles(0, 0, math.rad(90 * edgeSide)) * CFrame.Angles(0, math.pi, 0))
	-- the back of the blade, a darker spine
	add(part(model, Vector3.new(0.12, t + 0.06, body), GOLD_DARK, Enum.Material.Metal), CFrame.new(-edgeSide * (w / 2 - 0.05), 0, -(0.25 + body / 2)))
	-- the cutting edge, white-hot
	local edge = part(model, Vector3.new(0.07, t + 0.02, BLADE - 0.5), EDGE, Enum.Material.Neon)
	add(edge, CFrame.new(edgeSide * (w / 2 - 0.02), 0, -(0.25 + (BLADE - 0.5) / 2)) * CFrame.Angles(0, math.rad(-edgeSide * 3.2), 0))
	-- the shaft to the hand, a gold collar, the black grip, a gold cap
	add(part(model, Vector3.new(0.28, 0.28, HANDLE - 1.1), GOLD, Enum.Material.Metal), CFrame.new(0, 0, (HANDLE - 1.1) / 2 + 0.1))
	add(part(model, Vector3.new(0.42, 0.42, 0.22), GOLD, Enum.Material.Metal), CFrame.new(0, 0, HANDLE - 1.0))
	add(part(model, Vector3.new(0.34, 0.34, 0.95), GRIP, Enum.Material.Fabric), CFrame.new(0, 0, HANDLE - 0.45))
	add(part(model, Vector3.new(0.44, 0.44, 0.16), GOLD, Enum.Material.Metal), CFrame.new(0, 0, HANDLE + 0.06))
	return parts, rels, edge
end

export type Shears = any

function Shears.new(parent: Instance?): Shears
	local model = Instance.new("Model")
	model.Name = "GoldenShears"
	local pa, ra, edgeA = half(model, 1)
	local pb, rb, edgeB = half(model, -1)
	-- the bolt (on half A) with a gem
	local bolt = part(model, Vector3.new(0.5, 0.86, 0.86), GOLD_DARK, Enum.Material.Metal, "cyl")
	table.insert(pa, bolt)
	table.insert(ra, CFrame.new(0, -STACK, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local gem = part(model, Vector3.new(0.6, 0.36, 0.36), EDGE, Enum.Material.Neon, "cyl")
	table.insert(pa, gem)
	table.insert(ra, CFrame.new(0, -STACK, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 7
	light.Brightness = 0.6
	light.Shadows = false
	light.Parent = bolt
	-- trails off the tips
	local trails = {}
	for _, edge in { edgeA, edgeB } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0, -edge.Size.Z / 2)
		a0.Parent = edge
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0, -edge.Size.Z / 2 + 2.2)
		a1.Parent = edge
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Lifetime = 0.16
		tr.MinLength = 0.05
		tr.FaceCamera = true
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Color = ColorSequence.new(EDGE, GOLD)
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		tr.Enabled = false
		tr.Parent = edge
		table.insert(trails, tr)
	end
	local parts: { BasePart } = {}
	local rels: { CFrame } = {}
	local side: { number } = {}
	for i, p in pa do
		table.insert(parts, p)
		table.insert(rels, ra[i])
		table.insert(side, 1)
	end
	for i, p in pb do
		table.insert(parts, p)
		table.insert(rels, rb[i])
		table.insert(side, -1)
	end
	model.Parent = parent or workspace
	local self: any = {
		model = model,
		parts = parts,
		rels = rels,
		side = side,
		cfs = table.create(#parts, CFrame.identity),
		edges = { edgeA, edgeB },
		light = light,
		trails = trails,
		pivot = CFrame.identity,
		open = 0,
		shown = true,
	}
	return setmetatable(self, { __index = Shears })
end

-- The pivot frame (LookVector: where the blades point; UpVector: the bolt) and how far open, in degrees.
function Shears.place(self: any, pivot: CFrame, open: number)
	self.pivot = pivot
	self.open = open
	local half = math.rad(open / 2)
	local fa = pivot * CFrame.Angles(0, half, 0) * CFrame.new(0, STACK, 0)
	local fb = pivot * CFrame.Angles(0, -half, 0) * CFrame.new(0, -STACK, 0)
	for i, p in self.parts do
		self.cfs[i] = (if self.side[i] > 0 then fa else fb) * self.rels[i]
	end
	workspace:BulkMoveTo(self.parts, self.cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Two hands on the handles: half A's grip at the right wrist, half B's at the left; the bolt where both handles meet.
function Shears.grip2(self: any, rh: Vector3, lh: Vector3, fwd: Vector3)
	local span = rh - lh
	local s = span.Magnitude
	local u = if s > 1e-3 then span / s else Vector3.xAxis
	local f = fwd - u * fwd:Dot(u)
	f = if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
	local mid = (rh + lh) / 2
	local reach = math.sqrt(math.max(HANDLE * HANDLE - (s / 2) ^ 2, 0.04))
	local p = mid + f * reach
	local up = u:Cross(f)
	-- open: the angle between the two handles (the blades open just as wide)
	local da = (p - rh).Unit
	local db = (p - lh).Unit
	local open = math.deg(math.acos(math.clamp(da:Dot(db), -1, 1)))
	self:place(CFrame.lookAt(p, p + f, up), open)
end

-- One hand: the right half's grip at `at`, the shears pointing along `dir` (the bolt across `up`), open degrees.
function Shears.hold(self: any, at: Vector3, dir: Vector3, up: Vector3, open: number?)
	local d = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.zAxis
	local o = open or 0
	-- (the pivot sits a handle's length along the gripped half; the pair's middle line is turned half the opening away
	-- from it)
	local p = at + d * HANDLE
	self:place(CFrame.lookAt(p, p + d, up) * CFrame.Angles(0, math.rad(-o / 2), 0), o)
end

function Shears.trail(self: any, on: boolean)
	for _, t in self.trails do
		t.Enabled = on
	end
end

-- The edges' glow and the bolt's light: 0 normal, 1 blazing (the ultimate).
function Shears.glow(self: any, k: number)
	self.light.Brightness = 0.6 + k * 4
	self.light.Range = 7 + k * 10
	for _, e in self.edges do
		e.Color = EDGE:Lerp(Color3.new(1, 1, 1), k)
		e.Size = Vector3.new(0.07 + k * 0.08, e.Size.Y, e.Size.Z)
	end
end

-- Where the two tips are (world).
function Shears.tips(self: any): (Vector3, Vector3)
	local half = math.rad(self.open / 2)
	local a = self.pivot * CFrame.Angles(0, half, 0) * CFrame.new(0, 0, -BLADE)
	local b = self.pivot * CFrame.Angles(0, -half, 0) * CFrame.new(0, 0, -BLADE)
	return a.Position, b.Position
end

function Shears.show(self: any, on: boolean)
	if self.shown == on then
		return
	end
	self.shown = on
	for _, p in self.parts do
		p.LocalTransparencyModifier = if on then 0 else 1
	end
	self.light.Enabled = on
end

function Shears.destroy(self: any)
	self.model:Destroy()
end

return Shears
