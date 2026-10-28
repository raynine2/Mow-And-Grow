-- Far grass, drawn cheap (the report's #15: grass for phones). A voxel clump is one mesh of about 1,900
-- triangles, and a run's areas hold some 700 of them: about 1.3 million triangles, most of what the game draws.
-- On phones and tablets (client/PhonePerf) and in Potato Mode, only the clumps near you (or near the camera) are the
-- real mesh; further out each one is a stand-in of three blocks in the clump's own colours: its stalk, the bottom of
-- its tuft and the wide top (36 triangles). The world is split in squares; a square changes over as a whole, and
-- only a few dozen clumps change per frame, so nothing hitches.
--
-- The real clump stays where it is (its model, its collider, its attributes), only its mesh is taken out of the
-- world on this screen while it's far, so everything that looks for clumps still finds them (client/Wind, Coach,
-- AreaGoals). A clump something is working on (client/ClumpCarve's cut, a wound) is never swapped, and a film
-- (client/IntroCast) holds everything real while it plays: GrassLod.hold.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PhonePerf = require(script.Parent.PhonePerf)
local Potato = require(script.Parent.Potato)

local GrassLod = {}
local player = Players.LocalPlayer

local NEAR = 70 -- studs (flat) from you or the camera: the real clumps
local FAR = 85 -- a square further than this turns to stand-ins (the gap stops clumps flickering at the edge)
local CELL = 48 -- the squares
local STEP = 0.25 -- seconds between checks
local BUDGET = 40 -- clumps turned to stand-ins per frame at most (turning back to real is never held up)

-- The stand-in of each clump mesh: three blocks, { x, y, z offset, x, y, z size } as fractions of the mesh's size, and
-- the colour. Measured from the meshes themselves (assets/models/MowClumps.fbx and its atlas, 28 Oct): the stalk
-- (the lowest third), the bottom of the tuft, and its wide top, each trimmed of the odd stray blade.
local SHAPES: { [string]: { any } } = {
	Clump_blossom_1 = { { -0.03, -0.33, -0.03, 0.31, 0.34, 0.31, Color3.fromRGB(65, 140, 73) }, { -0.06, -0.01, -0.06, 0.50, 0.30, 0.50, Color3.fromRGB(74, 164, 86) }, { -0.06, 0.32, -0.03, 0.75, 0.36, 0.81, Color3.fromRGB(117, 182, 118) } },
	Clump_blossom_2 = { { 0.04, -0.33, 0.03, 0.36, 0.34, 0.31, Color3.fromRGB(65, 142, 74) }, { 0.04, -0.01, 0.03, 0.50, 0.30, 0.56, Color3.fromRGB(78, 170, 89) }, { 0.04, 0.32, 0.06, 0.79, 0.36, 0.75, Color3.fromRGB(125, 178, 122) } },
	Clump_ember_1 = { { -0.03, -0.33, -0.03, 0.31, 0.34, 0.31, Color3.fromRGB(52, 42, 46) }, { -0.06, -0.01, -0.06, 0.50, 0.30, 0.50, Color3.fromRGB(72, 58, 64) }, { -0.06, 0.32, -0.03, 0.75, 0.36, 0.81, Color3.fromRGB(106, 73, 65) } },
	Clump_ember_2 = { { 0.04, -0.33, 0.03, 0.36, 0.34, 0.31, Color3.fromRGB(54, 43, 48) }, { 0.04, -0.01, 0.03, 0.50, 0.30, 0.56, Color3.fromRGB(71, 57, 63) }, { 0.04, 0.32, 0.06, 0.79, 0.36, 0.75, Color3.fromRGB(115, 75, 63) } },
	Clump_frost_1 = { { 0.00, -0.33, 0.04, 0.33, 0.34, 0.36, Color3.fromRGB(187, 194, 200) }, { -0.03, -0.01, 0.07, 0.53, 0.30, 0.57, Color3.fromRGB(220, 234, 248) }, { -0.03, 0.32, 0.04, 0.80, 0.36, 0.79, Color3.fromRGB(227, 238, 248) } },
	Clump_frost_2 = { { -0.03, -0.33, 0.00, 0.31, 0.34, 0.33, Color3.fromRGB(187, 195, 201) }, { -0.03, -0.01, 0.00, 0.44, 0.30, 0.47, Color3.fromRGB(216, 232, 248) }, { 0.00, 0.32, -0.03, 0.75, 0.36, 0.80, Color3.fromRGB(229, 239, 249) } },
	Clump_isles_1 = { { -0.03, -0.33, -0.03, 0.31, 0.34, 0.31, Color3.fromRGB(137, 106, 198) }, { -0.06, -0.01, -0.06, 0.50, 0.30, 0.50, Color3.fromRGB(157, 118, 240) }, { -0.06, 0.32, -0.03, 0.75, 0.36, 0.81, Color3.fromRGB(175, 158, 245) } },
	Clump_isles_2 = { { 0.04, -0.33, 0.03, 0.36, 0.34, 0.31, Color3.fromRGB(138, 106, 202) }, { 0.04, -0.01, 0.03, 0.50, 0.30, 0.56, Color3.fromRGB(164, 125, 242) }, { 0.04, 0.32, 0.06, 0.79, 0.36, 0.75, Color3.fromRGB(170, 163, 246) } },
	Clump_meadow_1 = { { 0.00, -0.33, 0.04, 0.33, 0.34, 0.36, Color3.fromRGB(38, 126, 51) }, { -0.03, -0.01, 0.07, 0.53, 0.30, 0.57, Color3.fromRGB(52, 163, 67) }, { -0.03, 0.32, 0.04, 0.80, 0.36, 0.79, Color3.fromRGB(57, 173, 73) } },
	Clump_meadow_2 = { { -0.03, -0.33, 0.00, 0.31, 0.34, 0.33, Color3.fromRGB(37, 126, 50) }, { -0.03, -0.01, 0.00, 0.44, 0.30, 0.47, Color3.fromRGB(51, 162, 66) }, { 0.00, 0.32, -0.03, 0.75, 0.36, 0.80, Color3.fromRGB(58, 176, 74) } },
	Clump_pine_1 = { { 0.00, -0.33, 0.04, 0.33, 0.34, 0.36, Color3.fromRGB(32, 119, 87) }, { -0.03, -0.01, 0.07, 0.53, 0.30, 0.57, Color3.fromRGB(44, 153, 112) }, { -0.03, 0.32, 0.04, 0.80, 0.36, 0.79, Color3.fromRGB(48, 162, 120) } },
	Clump_pine_2 = { { -0.03, -0.33, 0.00, 0.31, 0.34, 0.33, Color3.fromRGB(31, 118, 86) }, { -0.03, -0.01, 0.00, 0.44, 0.30, 0.47, Color3.fromRGB(43, 151, 111) }, { 0.00, 0.32, -0.03, 0.75, 0.36, 0.80, Color3.fromRGB(50, 165, 122) } },
	Clump_swamp_1 = { { -0.03, -0.33, -0.03, 0.31, 0.34, 0.31, Color3.fromRGB(84, 112, 44) }, { -0.06, -0.01, -0.06, 0.50, 0.30, 0.50, Color3.fromRGB(96, 131, 51) }, { -0.06, 0.32, -0.03, 0.75, 0.36, 0.81, Color3.fromRGB(114, 140, 62) } },
	Clump_swamp_2 = { { 0.04, -0.33, 0.03, 0.36, 0.34, 0.31, Color3.fromRGB(84, 113, 44) }, { 0.04, -0.01, 0.03, 0.50, 0.30, 0.56, Color3.fromRGB(101, 136, 54) }, { 0.04, 0.32, 0.06, 0.79, 0.36, 0.75, Color3.fromRGB(113, 134, 60) } },
	Clump_wheat_1 = { { -0.03, -0.33, -0.07, 0.31, 0.34, 0.33, Color3.fromRGB(189, 144, 50) }, { -0.03, -0.01, 0.00, 0.56, 0.30, 0.60, Color3.fromRGB(231, 179, 65) }, { 0.00, 0.32, -0.03, 0.75, 0.36, 0.80, Color3.fromRGB(241, 206, 102) } },
	Clump_wheat_2 = { { -0.03, -0.33, 0.00, 0.31, 0.34, 0.33, Color3.fromRGB(183, 138, 46) }, { -0.06, -0.01, -0.03, 0.50, 0.30, 0.53, Color3.fromRGB(226, 171, 59) }, { -0.03, 0.32, -0.03, 0.69, 0.36, 0.80, Color3.fromRGB(240, 202, 94) } },
}

type Cell = { centre: Vector3, entries: { [Entry]: boolean }, lite: boolean }
type Entry = {
	model: Model,
	cell: Cell,
	lite: boolean, -- drawn as its stand-in now
	out: { [BasePart]: Instance }, -- the parts taken out of the world, and where they go back
	stand: { BasePart }?, -- the stand-in's blocks (made the first time they're needed, kept after)
	shape: { any }?,
	lookCf: CFrame?, -- the mesh's frame and size, read while it was in the world
	lookSize: Vector3?,
}

local cells: { [number]: Cell } = {}
local entries: { [Model]: Entry } = {}
local grass: Instance? = nil
local conns: { RBXScriptConnection } = {}
local folder: Folder? = nil
local held = false
local quiet = false -- set while we move parts ourselves (so our own moves aren't taken for new or removed parts)
local queue: { Entry } = {}
local queued: { [Entry]: boolean } = {}

local function active(): boolean
	return (PhonePerf.on or Potato.on) and not held
end

local function isClump(inst: Instance): boolean
	-- (the same rule as client/Wind: the generated world's voxel clumps, and the toy tufts)
	return inst:IsA("Model") and (inst.Name == "Clump" or (inst.Name:sub(1, 5) == "tuft_" and inst.Name:sub(-4) ~= "_cut"))
end

local function cellOf(pos: Vector3): Cell
	local cx, cz = math.floor(pos.X / CELL), math.floor(pos.Z / CELL)
	local key = (cx + 2000) * 8192 + (cz + 2000)
	local c = cells[key]
	if not c then
		c = { centre = Vector3.new((cx + 0.5) * CELL, pos.Y, (cz + 0.5) * CELL), entries = {}, lite = false }
		cells[key] = c
	end
	return c
end

-- the parts of a clump you can see (not its invisible collider)
local function seen(model: Model): { BasePart }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "StalkCollider" then
			table.insert(list, d)
		end
	end
	return list
end

-- Something else is working on it (a cut in progress swaps the mesh for pieces: client/ClumpCarve, ClumpWound), or
-- it's one of an area's last clumps, glowing for you to find (client/AreaGoals): leave it real.
local function busy(model: Model, parts: { BasePart }): boolean
	if #parts ~= 1 or model:GetAttribute("LastClump") then
		return true
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "StalkCollider" and d.Transparency >= 1 then
			return true -- (the real mesh hidden on this screen: carve pieces stand in for it)
		end
	end
	return false
end

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "GrassStandIns"
	f.Parent = workspace
	folder = f
	return f
end

local function block(color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "StandIn"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	return p
end

local function showStand(e: Entry)
	local cf, size = e.lookCf, e.lookSize
	if not cf or not size then
		return
	end
	local shape = e.shape or SHAPES.Clump_meadow_1
	if not e.stand then
		local list = {}
		for _, b in shape do
			table.insert(list, block(b[7]))
		end
		e.stand = list
	end
	local f = getFolder()
	for i, b in shape do
		local p = (e.stand :: { BasePart })[i]
		p.Size = Vector3.new(math.max(0.2, b[4] * size.X), math.max(0.2, b[5] * size.Y), math.max(0.2, b[6] * size.Z))
		p.CFrame = cf * CFrame.new(b[1] * size.X, b[2] * size.Y, b[3] * size.Z)
		p.Parent = f
	end
end

local function hideStand(e: Entry)
	if e.stand then
		for _, p in e.stand do
			p.Parent = nil
		end
	end
end

-- Real -> stand-in: the mesh out of the world, the blocks in.
local function toLite(e: Entry)
	if e.lite or not e.model.Parent then
		return
	end
	local parts = seen(e.model)
	if #parts == 0 or busy(e.model, parts) then
		return
	end
	local mesh = parts[1]
	e.lookCf, e.lookSize = mesh.CFrame, mesh.Size
	e.shape = SHAPES[mesh.Name]
	quiet = true
	for _, p in parts do
		e.out[p] = p.Parent :: Instance
		p.Parent = nil
	end
	quiet = false
	e.lite = true
	showStand(e)
end

-- Stand-in -> real.
local function toReal(e: Entry)
	if not e.lite then
		return
	end
	e.lite = false
	hideStand(e)
	quiet = true
	for p, parent in e.out do
		-- (the server may have removed it meanwhile: then it stays gone)
		pcall(function()
			if parent.Parent then
				p.Parent = parent
			end
		end)
	end
	quiet = false
	table.clear(e.out)
end

local function forget(e: Entry)
	hideStand(e)
	if e.stand then
		for _, p in e.stand do
			p:Destroy()
		end
		e.stand = nil
	end
	-- a removed clump's mesh we were holding goes too
	for p in e.out do
		pcall(function()
			p:Destroy()
		end)
	end
	table.clear(e.out)
	e.cell.entries[e] = nil
	entries[e.model] = nil
end

local function track(inst: Instance)
	if quiet then
		return
	end
	if isClump(inst) then
		local m = inst :: Model
		if not entries[m] then
			local cell = cellOf(m:GetPivot().Position)
			local e: Entry = { model = m, cell = cell, lite = false, out = {} }
			entries[m] = e
			cell.entries[e] = true
			if cell.lite and active() then
				queued[e] = true
				table.insert(queue, e)
			end
		end
		return
	end
	-- a part arriving in a clump that's a stand-in now (streamed in late, or a server change): out it goes too
	if inst:IsA("BasePart") then
		local m = inst:FindFirstAncestorWhichIsA("Model")
		while m and not isClump(m) do
			m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
		end
		local e = m and entries[m :: Model]
		if e and e.lite and inst.Transparency < 1 and inst.Name ~= "StalkCollider" then
			quiet = true
			e.out[inst] = inst.Parent :: Instance
			inst.Parent = nil
			quiet = false
		end
	end
end

local function untrack(inst: Instance)
	if quiet then
		return
	end
	local e = entries[inst :: any]
	if e then
		forget(e)
	end
end

local function hook()
	if grass and grass:IsDescendantOf(workspace) then
		return
	end
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	for _, e in entries do
		forget(e)
	end
	table.clear(cells)
	table.clear(queue)
	table.clear(queued)
	local world = workspace:FindFirstChild("World")
	grass = world and world:FindFirstChild("Grass")
	if not grass then
		return
	end
	for _, d in (grass :: Instance):GetDescendants() do
		track(d)
	end
	table.insert(conns, (grass :: Instance).DescendantAdded:Connect(track))
	table.insert(conns, (grass :: Instance).DescendantRemoving:Connect(untrack))
end

-- Everything real again, now (Potato Mode off, a film starting).
local function allReal()
	table.clear(queue)
	table.clear(queued)
	for _, e in entries do
		toReal(e)
	end
	for _, c in cells do
		c.lite = false
	end
end

local function focusPoints(): { Vector3 }
	local list = {}
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(list, cam.CFrame.Position)
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		table.insert(list, root.Position)
	end
	return list
end

local HALF = CELL * 0.71 -- from a square's middle to its corner
local function check()
	local points = focusPoints()
	if #points == 0 then
		return
	end
	for _, c in cells do
		local d = math.huge
		for _, p in points do
			local dx, dz = c.centre.X - p.X, c.centre.Z - p.Z
			d = math.min(d, math.sqrt(dx * dx + dz * dz))
		end
		d -= HALF
		if c.lite and d < NEAR then
			-- coming close: real at once (a stand-in up close would show)
			c.lite = false
			for e in c.entries do
				toReal(e)
			end
		elseif not c.lite and d > FAR then
			c.lite = true
		end
		if c.lite then
			-- keep its clumps in step: one that was busy when the square turned is tried again, one that has just
			-- become one of the last glowing clumps turns real
			for e in c.entries do
				if e.lite then
					if e.model:GetAttribute("LastClump") then
						toReal(e)
					end
				elseif not queued[e] then
					queued[e] = true
					table.insert(queue, e)
				end
			end
		end
	end
end

local wasActive = false
local checkAt = 0
local hookAt = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - hookAt > 1 then
		hookAt = now
		hook()
	end
	local on = active()
	if on ~= wasActive then
		wasActive = on
		if not on then
			allReal()
		end
	end
	if not on or not grass then
		return
	end
	if now - checkAt >= STEP then
		checkAt = now
		check()
	end
	-- turn the queued ones into stand-ins, a few per frame
	local n = 0
	while n < BUDGET and #queue > 0 do
		local e = table.remove(queue) :: Entry
		queued[e] = nil
		if e.cell.lite and entries[e.model] == e then
			toLite(e)
			n += 1
		end
	end
end)

-- Films (client/IntroCast.hideCharacters): every clump real for the whole film (its cameras fly all over, and it
-- hides and grows the grass itself), back to normal after.
function GrassLod.hold(on: boolean)
	if on == held then
		return
	end
	held = on
	if on then
		allReal()
	end
end

return GrassLod
