-- Edge lines (client): a faint light outline along the edges of the trees, bushes and landmarks, which gives
-- Catch a Brainrot's voxel scenery its crisp look. Kept subtle and off the ground and grass, so the world
-- doesn't look like a hologram. Drawn with SelectionBoxes, only on the
-- blocks near the camera (they're cheap but not free), recycled as you move. Phones get a smaller radius.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local EdgeLines = {}

local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local RADIUS = if MOBILE then 90 else 150
local CAP = if MOBILE then 1400 else 3200
local CELL = 32
local THICK = 0.045

local grid: { [number]: { BasePart } } = {}
local boxes: { [BasePart]: SelectionBox } = {}
local pool: { SelectionBox } = {}
local active = 0
local holder = Instance.new("Folder")
holder.Name = "EdgeLines"
holder.Parent = workspace

local function key(x: number, z: number): number
	return (math.floor(x / CELL) + 2000) * 8192 + (math.floor(z / CELL) + 2000)
end

local function wanted(p: Instance): boolean
	if not p:IsA("BasePart") or p.Transparency >= 0.6 then
		return false
	end
	-- only scenery: trees, bushes, landmarks (World.Visuals); never the ground, paths or grass
	local visuals = p:FindFirstAncestor("Visuals")
	if not visuals or p.Size.Y < 0.6 then
		return false
	end
	local s = p.Size
	if s.X < 0.5 and s.Z < 0.5 then
		return false
	end
	-- skip the invisible helpers, water and the deep column bodies under the floor
	local n = p.Name
	return n ~= "Patch" and n ~= "Water" and not string.find(n, "Side", 1, true) and not string.find(n, "Patch", 1, true) and p.Material ~= Enum.Material.Glass and p.Material ~= Enum.Material.ForceField
end

local function add(p: BasePart)
	local k = key(p.Position.X, p.Position.Z)
	local list = grid[k]
	if not list then
		list = {}
		grid[k] = list
	end
	table.insert(list, p)
end

local function lighter(c: Color3): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * 0.85, math.min(1, v * 1.12 + 0.03))
end

local function attach(p: BasePart)
	if boxes[p] or active >= CAP then
		return
	end
	local b = table.remove(pool)
	if not b then
		b = Instance.new("SelectionBox")
		b.LineThickness = THICK
		b.SurfaceTransparency = 1
		b.Transparency = 0.55
		b.Parent = holder
	end
	b.Color3 = if p.Material == Enum.Material.Neon then Color3.new(1, 1, 1) else lighter(p.Color)
	b.Adornee = p
	b.Visible = true
	boxes[p] = b
	active += 1
end

local function detach(p: BasePart)
	local b = boxes[p]
	if b then
		b.Adornee = nil
		b.Visible = false
		table.insert(pool, b)
		boxes[p] = nil
		active -= 1
	end
end

local function scan(world: Instance)
	for _, d in world:GetDescendants() do
		if wanted(d) then
			add(d :: BasePart)
		end
	end
	world.DescendantAdded:Connect(function(d)
		if wanted(d) then
			add(d :: BasePart)
		end
	end)
end

task.spawn(function()
	local world = workspace:WaitForChild("World", 120)
	if not world then
		return
	end
	scan(world)
	local player = Players.LocalPlayer
	while true do
		task.wait(0.5)
		if player:GetAttribute("EdgeLinesOff") then
			for p in boxes do
				detach(p)
			end
			continue
		end
		local cam = workspace.CurrentCamera
		local at = cam and cam.Focus.Position
		if at then
			-- drop the far ones (and ones that are gone or turned invisible)
			for p in boxes do
				if not p.Parent or p.Transparency >= 0.6 or (p.Position - at).Magnitude > RADIUS + 20 then
					detach(p)
				end
			end
			-- add the near ones, nearest cells first
			local c0x, c0z = math.floor(at.X / CELL), math.floor(at.Z / CELL)
			local r = math.ceil(RADIUS / CELL)
			for ring = 0, r do
				for dx = -ring, ring do
					for dz = -ring, ring do
						if math.max(math.abs(dx), math.abs(dz)) == ring then
							local list = grid[(c0x + dx + 2000) * 8192 + (c0z + dz + 2000)]
							if list then
								for i = #list, 1, -1 do
									local p = list[i]
									if not p.Parent then
										table.remove(list, i)
									elseif not boxes[p] and p.Transparency < 0.6 and (p.Position - at).Magnitude <= RADIUS then
										attach(p)
									end
								end
							end
						end
					end
				end
				if active >= CAP then
					break
				end
			end
		end
	end
end)

return EdgeLines
