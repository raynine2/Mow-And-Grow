-- THE GOLDEN SHEARS (Films v2, 5 Nov 2026): Rayan's weapon, a pair of giant gold scissors, for the films only (this
-- client). (Round 2, owner: "the sciccors i dont like ... make some better model", "voxel voor de schaar": they're voxels
-- now, in the game's voxel style, drawn in tools/blender/voxel/shears.py -> client/ShearsShape: a broad gold blade
-- with a white-hot edge and a dark fuller, a round pivot plate with a green gem, a dark wrapped grip, a big gold finger
-- ring.) Two halves cross at the pivot; the second is the first turned 180 degrees about the blade, its blade against
-- the first one's.
--   Shears.new(parent?) -> Shears
--   sh:grip2(rh, lh, fwd)            held in two hands (wrist points, world): the handles run from the hands to the
--                                    pivot, so spreading the hands opens the blades, bringing them together shuts them
--   sh:hold(at, dir, up, open?)      held in one hand at `at` (world), the shears pointing along `dir`, open degrees
--   sh:place(pivot, open)            put the pivot frame (LookVector = the blades' way, UpVector = the bolt's axis)
--   sh:trail(on) / sh:glow(k) / sh:tips() -> (Vector3, Vector3) / sh:show(on) / sh:destroy()
local Shape = require(script.Parent.ShearsShape)

local Shears = {}

local EDGE = Color3.fromRGB(255, 248, 220)
local GOLD = Color3.fromRGB(255, 196, 64)
local VOXEL = Shape.VOXEL
local HANDLE = Shape.HANDLE -- the pivot to the ring's middle (the hand)
local BLADE = Shape.BLADE -- the pivot to the tip
local TIP_X = Shape.TIP_X
local STACK = 0 -- (each half's blade lies on its own side of the middle plane already)
Shears.HANDLE = HANDLE
Shears.BLADE = BLADE

local COLOURS: { [string]: { color: Color3, neon: boolean } } = {}
for name, e in Shape.PALETTE do
	COLOURS[name] = { color = Color3.fromRGB(e[1], e[2], e[3]), neon = e[4] }
end

local function part(model: Model, size: Vector3, color: Color3, neon: boolean): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = not neon
	p.Parent = model
	return p
end

-- an invisible helper riding on a half (the trail's attachments at the tip, the bolt's light)
local function helper(model: Model, name: string): Part
	local p = part(model, Vector3.one * 0.1, GOLD, false)
	p.Name = name
	p.Transparency = 1
	p.CastShadow = false
	return p
end

-- One half, in its own frame (the pivot at the origin, the blade toward -Z, the ring toward +Z, the bolt along Y, the
-- cutting edge on +X); `turned` = the other half (turned 180 degrees about Z: its edge on -X, its layers below).
local function half(model: Model, turned: boolean): ({ BasePart }, { CFrame }, { BasePart }, BasePart)
	local parts, rels, edges = {}, {}, {}
	local turn = if turned then CFrame.Angles(0, 0, math.pi) else CFrame.identity
	local shift = Shape.SHIFT
	for _, b in Shape.BOXES do
		local c = COLOURS[b[7]] or COLOURS.gold
		local size = Vector3.new(b[4], b[5], b[6]) * VOXEL
		local centre = (Vector3.new(b[1], b[2], b[3]) + Vector3.new(b[4], b[5], b[6]) / 2 + shift) * VOXEL
		local p = part(model, size, c.color, c.neon)
		p.Name = b[7]
		table.insert(parts, p)
		table.insert(rels, turn * CFrame.new(centre))
		if b[7] == "edge" then
			table.insert(edges, p)
		end
	end
	-- the tip, for the trail (a0 at the point, a1 back along the blade)
	local tip = helper(model, "Tip")
	table.insert(parts, tip)
	table.insert(rels, turn * CFrame.new(TIP_X, VOXEL / 2, -BLADE))
	return parts, rels, edges, tip
end

export type Shears = any

function Shears.new(parent: Instance?): Shears
	local model = Instance.new("Model")
	model.Name = "GoldenShears"
	local pa, ra, edgesA, tipA = half(model, false)
	local pb, rb, edgesB, tipB = half(model, true)
	-- the bolt's light (over the gem)
	local bolt = helper(model, "Bolt")
	table.insert(pa, bolt)
	table.insert(ra, CFrame.new(0, VOXEL * 3, 0))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 9
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = bolt
	-- trails off the tips
	local trails = {}
	for _, tip in { tipA, tipB } do
		local a0 = Instance.new("Attachment")
		a0.Parent = tip
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0, 2.2)
		a1.Parent = tip
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
		tr.Parent = tip
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
	local edges = {}
	for _, e in edgesA do
		table.insert(edges, e)
	end
	for _, e in edgesB do
		table.insert(edges, e)
	end
	model.Parent = parent or workspace
	local self: any = {
		model = model,
		parts = parts,
		rels = rels,
		side = side,
		cfs = table.create(#parts, CFrame.identity),
		edges = edges,
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
	self.light.Brightness = 1.4 + k * 4
	self.light.Range = 9 + k * 10
	for _, e in self.edges do
		e.Color = EDGE:Lerp(Color3.new(1, 1, 1), k)
	end
end

-- Where the two tips are (world).
function Shears.tips(self: any): (Vector3, Vector3)
	local half = math.rad(self.open / 2)
	local a = self.pivot * CFrame.Angles(0, half, 0) * CFrame.new(TIP_X, 0, -BLADE)
	local b = self.pivot * CFrame.Angles(0, -half, 0) * CFrame.new(-TIP_X, 0, -BLADE)
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
