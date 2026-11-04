--!strict
-- THE STARTING CAMP'S PAVING, REDONE (owner, 4 Nov, standing in the camp: "the bricks and the random lanterns and plants
-- ... remove it or wtf"; then, with the camp on grass: "it looks so clumpy now ... very sloppy, i liked the bricks but
-- they had bad quality"). In the run's copy of the world (server/RunWorld.build, before server/WalkPlates lays its
-- plates), the camp's hand-laid paving (Hub.CampTiles: 0.3-stud stones on 8 x 8 bed blocks) keeps its layout but gets
-- the voxel kit's tile look (tools/blender/voxel/kit.py: every block a lighter bevelled rim round a slightly darker
-- face): each stone a warm sandstone in one of four close tones, its rim lighter, a thin top plate inset in its own
-- tone; the beds between them dark grout, so every stone reads; the stones along the paving's edge a shade darker, a
-- border where it meets the grass. (It was flat orange plastic on an orange bed.) The camp's loose lantern posts
-- (Hub.CampDecor) go; the buildings keep their own lamps. The flower beds, lantern ring and bunting were
-- server/HubSquare (off). Studio's saved world is untouched: CampGround.ON = false gives the old paving back.
local CampGround = {}

CampGround.ON = true

local TONES = {
	Color3.fromRGB(230, 178, 104),
	Color3.fromRGB(218, 166, 94),
	Color3.fromRGB(238, 190, 118),
	Color3.fromRGB(208, 156, 88),
}
local RIM = 0.18 -- how much lighter a stone's rim is than its face (toward white)
local INSET = 0.28 -- the rim's width, studs
local GROUT = Color3.fromRGB(92, 68, 50)
local BORDER = Color3.fromRGB(120, 92, 64) -- the edge stones lean this way
local BORDER_K = 0.45

local function hash(x: number, z: number, seed: number): number
	local n = math.sin(x * 12.9898 + z * 78.233 + seed * 37.719) * 43758.5453
	return n - math.floor(n)
end

-- Is (x, z) over one of the beds?
local function onBed(beds: { BasePart }, x: number, z: number): boolean
	for _, b in beds do
		local l = b.CFrame:PointToObjectSpace(Vector3.new(x, b.Position.Y, z))
		if math.abs(l.X) <= b.Size.X / 2 and math.abs(l.Z) <= b.Size.Z / 2 then
			return true
		end
	end
	return false
end

-- One paving stone in the kit's look: smooth, its rim `face` lightened, a thin top plate inset in `face` itself.
-- (Also the areas' paths: server/WorldLook.)
function CampGround.pave(s: BasePart, face: Color3)
	s.Material = Enum.Material.SmoothPlastic
	s.MaterialVariant = ""
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Color = face:Lerp(Color3.new(1, 1, 1), RIM)
	local top = Instance.new("Part")
	top.Name = "StoneTop"
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.CanTouch = false
	top.CastShadow = false
	top.Material = Enum.Material.SmoothPlastic
	top.TopSurface = Enum.SurfaceType.Smooth
	top.BottomSurface = Enum.SurfaceType.Smooth
	top.Size = Vector3.new(math.max(0.2, s.Size.X - INSET * 2), 0.04, math.max(0.2, s.Size.Z - INSET * 2))
	-- (its top 0.005 over the stone's: no flicker, and no step for the feet over server/WalkPlates' plate)
	top.CFrame = s.CFrame * CFrame.new(0, s.Size.Y / 2 - 0.015, 0)
	top.Color = face
	top.Parent = s.Parent
end

CampGround.TONES = TONES
CampGround.BORDER = BORDER
CampGround.BORDER_K = BORDER_K

-- THE BUILDINGS SQUARE WITH THE GROUND (owner, 4 Nov: "i dont like how the buildings are mixed with the ground", and
-- on a band of kerb stones round them, tried first: "het ziet er niet echt uit man die tegels om het gebouw"). The
-- camp's paving and the world's terraces are square to the world, but the Tool Shop and the Garage stood turned (73
-- and -17 degrees, where the saved map has them), so stones ran in under their walls at a slant and the terraces cut
-- across their corners. Now each is turned about its middle to the nearest square angle (90 and 0), and the paving
-- simply runs up to its walls in straight lines like a real square. Then:
--   * paving stones well inside its walls go (they poked up through the floors);
--   * where a corner still stands in a raised terrace (the shop's chimney corner; the world's ground is 8-stud
--     cells), those cells drop to the camp's level, a clean notch square with the walls; the cells' small decorations
--     come down with them, and a cell with anything else on it stays;
--   * the Garage turns to face the Tool Shop across the square (owner, after it was first squared to face the same way
--     as before: "je loopt de huis uit ziet een garage de zijkant"), the two fronts looking at each other, and moves
--     6 studs toward the square's middle and 2 out of its front, clear of the meadow boss arena's raised ground behind
--     it (its back, workbench and deck stood inside it; measured, nothing stands where it goes).
-- Its prompts, pump and mower spawn move with it. The rest of the camp's pieces stood at the same slant (the bag stand
-- at 163, the shredder at 73, its sell pad at -17): each turns about its own middle to the nearest square angle too.
-- The saved map is untouched: CampGround.SQUARE = false undoes it all.
-- `foot`: the building's footprint in its "0Anchor" frame (-Z is the front), measured in Studio.
type Rect = { x0: number, x1: number, z0: number, z1: number }
CampGround.SQUARE = true
local SQUARE_UP: { [string]: { yaw: number, forward: number?, move: Vector3?, foot: Rect } } = {
	-- (its front, -Z, looks west across the square)
	["TOOL SHOP"] = { yaw = 90, foot = { x0 = -28.5, x1 = 25.5, z0 = -16, z1 = 26.8 } },
	-- (its front looks east, at the Tool Shop's)
	Garage = { yaw = -90, forward = 2, move = Vector3.new(0, 0, -6), foot = { x0 = -11.5, x1 = 11.8, z0 = -9.5, z1 = 14.5 } },
}
-- units whose every model (with the loose parts nearest it) turns about its own pivot
local SQUARE_PIECES = { "BAG STAND", "Shredder" }
local CAMP_Y = 4.3 -- the camp's ground (the paving's beds)
local CELL = 8

-- Moves everything in `inst` by the world transform `delta` (models by their pivot, loose parts by their CFrame).
local function moveTree(inst: Instance, delta: CFrame)
	for _, c in inst:GetChildren() do
		if c:IsA("Model") then
			c:PivotTo(delta * c:GetPivot())
		elseif c:IsA("BasePart") then
			c.CFrame = delta * c.CFrame
		elseif c:IsA("Folder") then
			moveTree(c, delta)
		end
	end
end

local function inRect(at: CFrame, r: Rect, p: Vector3, grow: number): boolean
	local l = at:PointToObjectSpace(p)
	return l.X > r.x0 - grow and l.X < r.x1 + grow and l.Z > r.z0 - grow and l.Z < r.z1 + grow
end

-- Drops the raised ground cells under footprint `r` (frame `at`) to the camp's level. The world's ground is merged
-- boxes ("Floor", grass on top, over "FloorSide", earth to the bottom) made of 8-stud cells: each box crossing the
-- footprint is cut into runs of cells, the ones under it lowered. Returns how many cells dropped.
local function notch(w: Instance, at: CFrame, r: Rect, keep: Instance): number
	local ground = w:FindFirstChild("Ground")
	if not ground then
		return 0
	end
	local visuals = w:FindFirstChild("Visuals")
	local sides: { BasePart } = {}
	for _, p in ground:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "FloorSide" then
			table.insert(sides, p)
		end
	end
	local dropped = 0
	for _, f in ground:GetDescendants() do
		if not f:IsA("BasePart") or f.Name ~= "Floor" or f.Position.Y + f.Size.Y / 2 < CAMP_Y + 0.5 then
			continue
		end
		local top = f.Position.Y + f.Size.Y / 2
		local dh = top - CAMP_Y
		local alongX = f.Size.X >= f.Size.Z
		local len = if alongX then f.Size.X else f.Size.Z
		local n = math.floor(len / CELL + 0.5)
		if n < 1 then
			continue
		end
		-- which cells drop (any of their corners or middle under the footprint, nothing but decorations on them)
		local low = {}
		local any = false
		for k = 0, n - 1 do
			local off = -len / 2 + (k + 0.5) * CELL
			local c = f.Position + (if alongX then Vector3.new(off, 0, 0) else Vector3.new(0, 0, off))
			local under = false
			for _, d in { Vector3.zero, Vector3.new(-3.9, 0, -3.9), Vector3.new(3.9, 0, -3.9), Vector3.new(-3.9, 0, 3.9), Vector3.new(3.9, 0, 3.9) } do
				if inRect(at, r, c + d, 0.5) then
					under = true
					break
				end
			end
			if under then
				local clear = true
				for _, q in workspace:GetPartBoundsInBox(CFrame.new(c.X, top + 2, c.Z), Vector3.new(7.6, 3.4, 7.6)) do
					if not q:IsDescendantOf(ground) and not q:IsDescendantOf(keep) and not (visuals and q:IsDescendantOf(visuals)) and q.Transparency < 1 then
						local m = q:FindFirstAncestorOfClass("Model")
						if not (m and m:FindFirstChildOfClass("Humanoid")) then
							clear = false
							break
						end
					end
				end
				low[k] = clear
				any = any or clear
			end
		end
		if not any then
			continue
		end
		-- its earth below: the FloorSide with the same footprint
		local side: BasePart? = nil
		for _, q in sides do
			if math.abs(q.Position.X - f.Position.X) < 0.05 and math.abs(q.Position.Z - f.Position.Z) < 0.05 and math.abs(q.Size.X - f.Size.X) < 0.05 and math.abs(q.Size.Z - f.Size.Z) < 0.05 then
				side = q
				break
			end
		end
		-- cut into runs of cells, each run one box (and its earth), the dropped runs lower
		local k = 0
		while k < n do
			local dropRun = low[k] == true
			local k2 = k
			while k2 + 1 < n and (low[k2 + 1] == true) == dropRun do
				k2 += 1
			end
			local a0 = -len / 2 + k * CELL
			local a1 = -len / 2 + (k2 + 1) * CELL
			local mid = (a0 + a1) / 2
			local runLen = a1 - a0
			local shift = if alongX then Vector3.new(mid, 0, 0) else Vector3.new(0, 0, mid)
			local down = if dropRun then dh else 0
			for _, src in { f, side } do
				if src then
					local c = src:Clone()
					local h = if src == f then src.Size.Y else src.Size.Y - down
					local sy = if src == f then src.Position.Y - down else src.Position.Y - down / 2
					c.Size = if alongX then Vector3.new(runLen, h, src.Size.Z) else Vector3.new(src.Size.X, h, runLen)
					c.CFrame = CFrame.new(Vector3.new(src.Position.X, sy, src.Position.Z) + shift)
					c.Parent = src.Parent
				end
			end
			if dropRun then
				dropped += k2 - k + 1
				-- the small decorations on those cells come down too
				if visuals then
					local box = CFrame.new(f.Position.X + shift.X, top + 2, f.Position.Z + shift.Z)
					local size = if alongX then Vector3.new(runLen - 0.1, 3.4, f.Size.Z - 0.1) else Vector3.new(f.Size.X - 0.1, 3.4, runLen - 0.1)
					local moved = {}
					for _, q in workspace:GetPartBoundsInBox(box, size) do
						local m = q:FindFirstAncestorOfClass("Model")
						local thing: Instance = if m and m:IsDescendantOf(visuals) then m else q
						if q:IsDescendantOf(visuals) and not moved[thing] then
							moved[thing] = true
							if thing:IsA("Model") then
								thing:PivotTo(thing:GetPivot() - Vector3.new(0, dh, 0))
							elseif thing:IsA("BasePart") then
								thing.CFrame -= Vector3.new(0, dh, 0)
							end
						end
					end
				end
			end
			k = k2 + 1
		end
		f:Destroy()
		if side then
			side:Destroy()
		end
	end
	return dropped
end

type Move = { at: Vector3, r: number, delta: CFrame }

-- (4 Nov, owner, on the Garage: "LIKE WHY ARE BUILDINGS IN THE GROUND") The ForgeGUI houses stood with their feet at
-- the camp's ground (4.3, the paving's beds) while the paving stones' tops are 0.3 higher and more, so the stones ran
-- up over the bottom of their walls, the roll door and the posts. Each squared-up building now stands ON the paving:
-- everything of it goes up by the gap between its house's foot and the highest stone round it (the house, the room
-- inside, the shelves, the counter, its anchor and walls), but not what stands on the ground in front of it (the
-- shop's little yard, the gas pump).
local STAY_DOWN = { ShopYard = true, gas_pump = true, GasPump = true }
local function liftOnto(unit: Instance, tiles: Instance?, at: CFrame, foot: Rect): number
	local shell = unit:FindFirstChild("ShopShell")
	local body = shell and shell:FindFirstChildWhichIsA("BasePart", true)
	if not body or not tiles then
		return 0
	end
	local bottom = body.Position.Y - body.Size.Y / 2
	local top = -math.huge
	for _, p in tiles:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Stone" and inRect(at, foot, p.Position, 4) then
			top = math.max(top, p.Position.Y + p.Size.Y / 2)
		end
	end
	local lift = top - bottom + 0.02
	if lift < 0.05 or lift > 3 then
		return 0
	end
	local d = CFrame.new(0, lift, 0)
	for _, c in unit:GetChildren() do
		if STAY_DOWN[c.Name] then
			continue
		end
		if c:IsA("Model") then
			c:PivotTo(d * c:GetPivot())
		elseif c:IsA("BasePart") then
			c.CFrame = d * c.CFrame
		elseif c:IsA("Folder") then
			moveTree(c, d)
		end
	end
	return lift
end

-- The positions the run keeps in `info` (pumps, the mower spawn, the shredder's mouth...) follow the piece they belong
-- to: each Vector3 or CFrame within reach of a moved piece's old middle takes the nearest one's move.
local function shiftInfo(info: any, moves: { Move })
	local seen = {}
	local function nearest(p: Vector3): CFrame?
		local best, bestD = nil, math.huge
		for _, m in moves do
			local d = (p - m.at).Magnitude
			if d < m.r and d < bestD then
				best, bestD = m.delta, d
			end
		end
		return best
	end
	local function walk(t: any)
		if seen[t] then
			return
		end
		seen[t] = true
		for k, v in t do
			if k == "world" then
				continue
			end
			if typeof(v) == "Vector3" then
				local d = nearest(v)
				if d then
					t[k] = d * v
				end
			elseif typeof(v) == "CFrame" then
				local d = nearest(v.Position)
				if d then
					t[k] = d * v
				end
			elseif type(v) == "table" then
				walk(v)
			end
		end
	end
	walk(info)
end

-- The smaller pieces standing on the paving (the shredder) sat 0.3 into it the same way: each model of the unit
-- whose lowest part is up to 0.6 under the stones round it goes up onto them.
local function liftPieces(unit: Instance, tiles: Instance?)
	if not tiles then
		return
	end
	for _, m in unit:GetChildren() do
		if not m:IsA("Model") then
			continue
		end
		local cf, size = m:GetBoundingBox()
		local bottom = cf.Position.Y - size.Y / 2
		local top = -math.huge
		for _, p in tiles:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "Stone" then
				local d = Vector3.new(p.Position.X - cf.Position.X, 0, p.Position.Z - cf.Position.Z).Magnitude
				if d < math.max(size.X, size.Z) / 2 + 4 then
					top = math.max(top, p.Position.Y + p.Size.Y / 2)
				end
			end
		end
		local lift = top - bottom + 0.02
		if lift > 0.05 and lift < 0.6 then
			m:PivotTo(m:GetPivot() + Vector3.new(0, lift, 0))
		end
	end
end

-- Turns each model of a unit (with the loose parts nearest it) about its pivot to the nearest square angle.
local function squarePieces(unit: Instance, moves: { Move })
	local groups: { { pivot: CFrame, members: { Instance } } } = {}
	for _, c in unit:GetChildren() do
		if c:IsA("Model") then
			table.insert(groups, { pivot = c:GetPivot(), members = { c } })
		end
	end
	for _, c in unit:GetChildren() do
		if c:IsA("BasePart") then
			local best, bestD = nil, 12
			for _, g in groups do
				local d = (Vector3.new(c.Position.X, 0, c.Position.Z) - Vector3.new(g.pivot.X, 0, g.pivot.Z)).Magnitude
				if d < bestD then
					best, bestD = g, d
				end
			end
			if best then
				table.insert(best.members, c)
			end
		end
	end
	for _, g in groups do
		local _, yaw = g.pivot:ToOrientation()
		local turn = math.rad(math.round(math.deg(yaw) / 90) * 90) - yaw
		if math.abs(turn) < 0.001 then
			continue
		end
		local at = g.pivot.Position
		local delta = CFrame.new(at) * CFrame.Angles(0, turn, 0) * CFrame.new(-at)
		for _, m in g.members do
			if m:IsA("Model") then
				m:PivotTo(delta * m:GetPivot())
			elseif m:IsA("BasePart") then
				m.CFrame = delta * m.CFrame
			end
		end
		table.insert(moves, { at = at, r = 14, delta = delta })
	end
end

-- Squares every building up with the ground (after CampGround.apply). `info`: the run's (RunWorld.build), whose
-- pump and mower spawn positions move with a building. Returns how many buildings and how many ground cells dropped.
function CampGround.squareUp(w: Instance, info: any?): (number, number)
	if not CampGround.ON or not CampGround.SQUARE then
		return 0, 0
	end
	local hub = w:FindFirstChild("Hub")
	if not hub then
		return 0, 0
	end
	local tiles = hub:FindFirstChild("CampTiles")
	local n, cells = 0, 0
	local moves: { Move } = {}
	for unitName, f in SQUARE_UP do
		local unit = hub:FindFirstChild(unitName)
		local anchor = unit and unit:FindFirstChild("0Anchor")
		if not unit or not anchor or not anchor:IsA("BasePart") then
			continue
		end
		local old = anchor.CFrame
		local new = CFrame.new(old.Position + (f.move or Vector3.zero)) * CFrame.Angles(0, math.rad(f.yaw), 0) * CFrame.new(0, 0, -(f.forward or 0))
		local delta = new * old:Inverse()
		moveTree(unit, delta)
		table.insert(moves, { at = old.Position, r = 40, delta = delta })
		local at = CFrame.new(anchor.Position) * anchor.CFrame.Rotation
		-- the paving stones well inside its walls go (and their plates)
		for _, p in (if tiles then tiles:GetDescendants() else {}) do
			if p:IsA("BasePart") and (p.Name == "Stone" or p.Name == "StoneTop") and inRect(at, f.foot, p.Position, -2) then
				p:Destroy()
			end
		end
		cells += notch(w, at, f.foot, unit)
		local lift = liftOnto(unit, tiles, at, f.foot)
		if lift > 0 then
			moves[#moves].delta = CFrame.new(0, lift, 0) * delta
		end
		n += 1
		task.wait()
	end
	for _, name in SQUARE_PIECES do
		local unit = hub:FindFirstChild(name)
		if unit then
			squarePieces(unit, moves)
			liftPieces(unit, tiles)
			n += 1
		end
	end
	if info then
		shiftInfo(info, moves)
	end
	return n, cells
end

-- Returns how many stones were restyled.
function CampGround.apply(w: Instance): number
	if not CampGround.ON then
		return 0
	end
	local hub = w:FindFirstChild("Hub")
	local tiles = hub and hub:FindFirstChild("CampTiles")
	if not hub or not tiles then
		return 0
	end
	local beds: { BasePart } = {}
	local stones: { BasePart } = {}
	for _, p in tiles:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Bed" then
				table.insert(beds, p)
			elseif p.Name == "Stone" then
				table.insert(stones, p)
			end
		end
	end
	for _, b in beds do
		b.Material = Enum.Material.SmoothPlastic
		b.MaterialVariant = ""
		b.Color = GROUT
	end
	for i, s in stones do
		local x, z = s.Position.X, s.Position.Z
		local face = TONES[1 + math.floor(hash(math.floor(x / 4), math.floor(z / 4), 3) * #TONES)]
		if not (onBed(beds, x + 4, z) and onBed(beds, x - 4, z) and onBed(beds, x, z + 4) and onBed(beds, x, z - 4)) then
			face = face:Lerp(BORDER, BORDER_K)
		end
		CampGround.pave(s, face)
		if i % 100 == 0 then
			task.wait()
		end
	end
	local decor = hub:FindFirstChild("CampDecor")
	for _, d in (if decor then decor:GetChildren() else {}) do
		if d.Name == "lantern_post" then
			d:Destroy()
		end
	end
	return #stones
end

return CampGround
