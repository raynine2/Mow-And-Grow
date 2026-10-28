-- WALK PLATES (owner, 28 Oct: "the character still bugs when walking, it goes up and down, maybe because of that
-- platform"): paving with its stones standing proud of the bed makes a walking character step up and down at every
-- joint, every few studs. The run camp's hand-made paving (Workspace.World.Hub.CampTiles: 0.3-stud stones on 8x8
-- bed blocks) and the lobby's walks (server/HubPaths: 0.2-stud stones on "Path" beds) both do it. This puts one
-- invisible plate on top of each bed that carries stones, level with their tops: the feet walk on a flat floor and
-- the paving looks exactly the same (nothing hand-made is changed). The other areas' camps (server/Outposts) have
-- the same joints in their plazas (0.22 deep), and the boardwalk camps have gaps between their planks (0.4 deep,
-- measured in Studio on 28 Oct: a 0.16-0.24 stud bob walking over them): their rows get a plate each too.
--
--   WalkPlates.cover(root)   every CampTiles / Paths-with-Stones folder / Outpost plaza under `root` (once each)
local WalkPlates = {}

-- The stones lying on top of `bed` (a stone's bottom on the bed's top, its middle inside the bed's outline).
local function stonesOn(bed: BasePart, stones: { BasePart }): (number, number)
	local n, thick = 0, 0
	local round = bed.Shape == Enum.PartType.Cylinder
	-- the bed's top face (a cylinder on its side has its round faces along X: X points up)
	local up = if round then bed.CFrame.RightVector else bed.CFrame.UpVector
	local half = if round then bed.Size.X / 2 else bed.Size.Y / 2
	local top = bed.Position + up * half
	for _, s in stones do
		local bottom = s.Position - Vector3.yAxis * (s.Size.Y / 2)
		if math.abs(bottom.Y - top.Y) < 0.06 then
			local inside
			if round then
				inside = Vector2.new(s.Position.X - bed.Position.X, s.Position.Z - bed.Position.Z).Magnitude <= bed.Size.Y / 2
			else
				local l = bed.CFrame:PointToObjectSpace(Vector3.new(s.Position.X, bed.Position.Y, s.Position.Z))
				inside = math.abs(l.X) <= bed.Size.X / 2 and math.abs(l.Z) <= bed.Size.Z / 2
			end
			if inside then
				n += 1
				thick = math.max(thick, s.Size.Y)
			end
		end
	end
	return n, thick
end

local function plate(bed: BasePart, h: number)
	local p = Instance.new("Part")
	p.Name = "WalkPlate"
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Locked = true
	if bed.Shape == Enum.PartType.Cylinder then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(h, bed.Size.Y, bed.Size.Z)
		p.CFrame = bed.CFrame * CFrame.new(bed.Size.X / 2 + h / 2, 0, 0)
	else
		p.Size = Vector3.new(bed.Size.X, h, bed.Size.Z)
		p.CFrame = bed.CFrame * CFrame.new(0, bed.Size.Y / 2 + h / 2, 0)
	end
	p.Parent = bed.Parent
end

local function coverFolder(folder: Instance, beds: { BasePart }, stones: { BasePart }): number
	if folder:GetAttribute("WalkPlates") then
		return 0
	end
	folder:SetAttribute("WalkPlates", true)
	local made = 0
	for _, bed in beds do
		local n, thick = stonesOn(bed, stones)
		if n > 0 and thick > 0.02 then
			plate(bed, thick)
			made += 1
		end
	end
	return made
end

-- The area camps' plazas (server/Outposts): a 4-stud grid of "Tile"s standing 0.22 proud of their "TileBed"s, with
-- 0.35-stud joints between them. One plate per row of beds (level with the tiles' tops), not one per cell.
local function coverTiles(folder: Instance): number
	if folder:GetAttribute("WalkPlates") then
		return 0
	end
	folder:SetAttribute("WalkPlates", true)
	local tiles: { BasePart } = {}
	local cells = {}
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Tile" then
			table.insert(tiles, p)
		end
	end
	for _, bed in folder:GetChildren() do
		if bed:IsA("BasePart") and bed.Name == "TileBed" and math.abs(bed.CFrame.RightVector.X) > 0.999 then
			local bedTop = bed.Position.Y + bed.Size.Y / 2
			for _, t in tiles do
				local d = t.Position - bed.Position
				local h = t.Position.Y + t.Size.Y / 2 - bedTop
				if math.abs(d.X) < 0.3 and math.abs(d.Z) < 0.3 and h > 0.02 and h < 1 then
					table.insert(cells, { x = bed.Position.X, z = bed.Position.Z, y = bedTop, h = h, sx = bed.Size.X, sz = bed.Size.Z })
					break
				end
			end
		end
	end
	-- rows: the same height, depth and line; merged where the beds touch end to end
	table.sort(cells, function(a, b)
		if math.abs(a.y - b.y) > 0.005 then
			return a.y < b.y
		elseif math.abs(a.z - b.z) > 0.005 then
			return a.z < b.z
		end
		return a.x < b.x
	end)
	local made = 0
	local i = 1
	while i <= #cells do
		local a = cells[i]
		local j = i
		while cells[j + 1] do
			local b, c = cells[j], cells[j + 1]
			if math.abs(c.y - b.y) < 0.005 and math.abs(c.z - b.z) < 0.005 and math.abs(c.h - b.h) < 0.005 and math.abs(c.sz - b.sz) < 0.01 and math.abs((c.x - b.x) - (b.sx + c.sx) / 2) < 0.02 then
				j += 1
			else
				break
			end
		end
		local z = cells[j]
		local x0, x1 = a.x - a.sx / 2, z.x + z.sx / 2
		local p = Instance.new("Part")
		p.Name = "WalkPlate"
		p.Anchored = true
		p.CanCollide = true
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Locked = true
		p.Size = Vector3.new(x1 - x0, a.h, a.sz)
		p.CFrame = CFrame.new((x0 + x1) / 2, a.y + a.h / 2, a.z)
		p.Parent = folder
		made += 1
		i = j + 1
	end
	return made
end

-- The boardwalk camps (server/Outposts' plank theme): three 1.22-stud planks a 4-stud cell, 0.1-0.14 studs apart, with
-- stone or ground 0.4 under the gaps. One plate per row of planks (where they're less than 0.3 apart), level with their
-- tops and as deep as the cell, so the rows touch.
local function coverPlanks(folder: Instance): number
	if folder:GetAttribute("WalkPlates") then
		return 0
	end
	folder:SetAttribute("WalkPlates", true)
	local planks: { BasePart } = {}
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Plank" and math.abs(p.CFrame.RightVector.X) > 0.999 then
			table.insert(planks, p)
		end
	end
	local function top(p: BasePart): number
		return p.Position.Y + p.Size.Y / 2
	end
	table.sort(planks, function(a, b)
		if math.abs(top(a) - top(b)) > 0.005 then
			return top(a) < top(b)
		elseif math.abs(a.Position.Z - b.Position.Z) > 0.005 then
			return a.Position.Z < b.Position.Z
		end
		return a.Position.X < b.Position.X
	end)
	local made = 0
	local i = 1
	while i <= #planks do
		local a = planks[i]
		local j = i
		while planks[j + 1] do
			local b, c = planks[j], planks[j + 1]
			local gap = (c.Position.X - c.Size.X / 2) - (b.Position.X + b.Size.X / 2)
			if math.abs(top(c) - top(b)) < 0.005 and math.abs(c.Position.Z - b.Position.Z) < 0.005 and math.abs(c.Size.Z - b.Size.Z) < 0.01 and gap > -0.05 and gap < 0.3 then
				j += 1
			else
				break
			end
		end
		local z = planks[j]
		local x0, x1 = a.Position.X - a.Size.X / 2, z.Position.X + z.Size.X / 2
		local h = a.Size.Y
		local p = Instance.new("Part")
		p.Name = "WalkPlate"
		p.Anchored = true
		p.CanCollide = true
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Locked = true
		p.Size = Vector3.new(x1 - x0, h, a.Size.Z + 0.12)
		p.CFrame = CFrame.new((x0 + x1) / 2, top(a) - h / 2, a.Position.Z)
		p.Parent = folder
		made += 1
		i = j + 1
	end
	return made
end

-- Every paving under `root`: hand-made CampTiles (Bed + Stone parts), HubPaths walks (Path parts + a Stones folder) and
-- the area camps' plazas (Outpost<z> models: Tile + TileBed parts, or boardwalk Planks).
function WalkPlates.cover(root: Instance?): number
	if not root then
		return 0
	end
	local made = 0
	for _, f in root:GetDescendants() do
		if f.Name == "CampTiles" then
			local beds, stones = {}, {}
			for _, p in f:GetDescendants() do
				if p:IsA("BasePart") then
					if p.Name == "Bed" then
						table.insert(beds, p)
					elseif p.Name == "Stone" then
						table.insert(stones, p)
					end
				end
			end
			made += coverFolder(f, beds, stones)
		elseif f.Name == "Paths" and f:FindFirstChild("Stones") then
			local beds, stones = {}, {}
			for _, p in f:GetChildren() do
				if p:IsA("BasePart") and p.Name == "Path" then
					table.insert(beds, p)
				end
			end
			for _, p in (f :: any).Stones:GetChildren() do
				if p:IsA("BasePart") then
					table.insert(stones, p)
				end
			end
			made += coverFolder(f, beds, stones)
		elseif string.match(f.Name, "^Outpost%d+$") and f:FindFirstChild("TileBed") then
			made += coverTiles(f)
		elseif string.match(f.Name, "^Outpost%d+$") and f:FindFirstChild("Plank") then
			made += coverPlanks(f)
		end
	end
	return made
end

return WalkPlates
