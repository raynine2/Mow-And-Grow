-- WALK PLATES (owner, 28 Oct: "the character still bugs when walking, it goes up and down, maybe because of that
-- platform"): paving with its stones standing proud of the bed makes a walking character step up and down at every
-- joint, every few studs. The run camp's hand-made paving (Workspace.World.Hub.CampTiles: 0.3-stud stones on 8x8
-- bed blocks) and the lobby's walks (server/HubPaths: 0.2-stud stones on "Path" beds) both do it. This puts one
-- invisible plate on top of each bed that carries stones, level with their tops: the feet walk on a flat floor and
-- the paving looks exactly the same (nothing hand-made is changed).
--
--   WalkPlates.cover(root)   every CampTiles / Paths-with-Stones folder under `root` (once per folder)
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

-- Every paving under `root`: hand-made CampTiles (Bed + Stone parts) and HubPaths walks (Path parts + a Stones folder).
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
		end
	end
	return made
end

return WalkPlates
