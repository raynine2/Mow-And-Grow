-- A camp in every area (owner, 27 Oct: "I want this type of hub in every zone, with the necessary things where you
-- can sell and buy stuff, like Chop A Forest, and do some unique"). Area 1 has the big camp (the village moved
-- into the meadow); every other area gets an outpost round its drop-off pad (World.Pads.DropOff<z>, the sell spot):
--   * a paved plaza level with the pad, built up on stone where the terraced ground falls away (steps at the edge);
--   * the SHOP and UPGRADES stalls (their prompts open the same windows as R and TAB), a gas pump for mowers;
--   * two log benches (lamp posts and the name: server/CampDress);
--   * (until 29 Oct) one thing of its own per area (SPECIAL below: a hay yard, a blossom tree, a campfire ring,
--     mushrooms, an ice-crystal fire pit, a forge, a star-crystal cluster); the camp's landmark does that now.
-- (29 Oct, owner: "remake every zone hub except 1 to make it a bit bigger and ... feel more alive"; 21:13, "its very
-- messy and just cluttered fix it and remove unneccerary stuff") the plaza is 24 studs round now, on the flat
-- clearing shared/WorldPlan keeps round every pad (and never inside the boss arena next to it), and
-- server/CampDress adds an entrance arch and lamp posts, a house, the area's landmark and animals round it and
-- three gnome villagers (Blender models: server/CampProps; client/CampLife animates them).
-- The camp's centre and radius go on the World as attributes Hub<z> / HubR<z>: no grass grows there
-- (RunWorld.patches) and the camera lets you out of first person there (client/CameraView).
-- Built into the run's copy of the world at run start (server/RunWorld.build); nothing in Studio changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local VoxelKit = require(script.Parent.VoxelKit)
local PropKit = require(script.Parent.PropKit)
local Models = require(script.Parent.Models)

local Outposts = {}

local R = 24 -- the plaza's radius (20 until 29 Oct)
local CELL = 4 -- paving grid
local UP = Vector3.yAxis
local part = VoxelKit.part
local C = VoxelKit.C

-- per area: paving (two stone shades and the bed), the awning cloth, lantern glass, and its own corner
type Theme = { tile: { Color3 }, bed: Color3, cloth: Color3, glow: Color3?, plank: boolean?, special: string }
local THEMES: { [string]: Theme } = {
	wheat = { tile = { Color3.fromRGB(222, 190, 120), Color3.fromRGB(204, 170, 104) }, bed = Color3.fromRGB(150, 118, 70), cloth = Color3.fromRGB(226, 128, 44), special = "hayyard" },
	blossom = { tile = { Color3.fromRGB(232, 214, 210), Color3.fromRGB(214, 192, 190) }, bed = Color3.fromRGB(150, 128, 128), cloth = Color3.fromRGB(240, 120, 170), glow = Color3.fromRGB(255, 190, 220), special = "blossomtree" },
	pine = { tile = { Color3.fromRGB(150, 156, 150), Color3.fromRGB(132, 138, 132) }, bed = Color3.fromRGB(86, 90, 86), cloth = Color3.fromRGB(60, 120, 80), special = "campfire" },
	swamp = { tile = { Color3.fromRGB(128, 100, 74), Color3.fromRGB(112, 86, 62) }, bed = Color3.fromRGB(70, 56, 42), cloth = Color3.fromRGB(110, 140, 60), glow = Color3.fromRGB(170, 255, 140), plank = true, special = "mushrooms" },
	frost = { tile = { Color3.fromRGB(214, 226, 238), Color3.fromRGB(194, 208, 224) }, bed = Color3.fromRGB(130, 146, 168), cloth = Color3.fromRGB(70, 130, 210), glow = Color3.fromRGB(200, 236, 255), special = "icepit" },
	ember = { tile = { Color3.fromRGB(78, 70, 72), Color3.fromRGB(64, 58, 60) }, bed = Color3.fromRGB(36, 32, 34), cloth = Color3.fromRGB(200, 70, 40), glow = Color3.fromRGB(255, 150, 70), special = "forge" },
	isles = { tile = { Color3.fromRGB(150, 130, 200), Color3.fromRGB(130, 112, 182) }, bed = Color3.fromRGB(80, 66, 120), cloth = Color3.fromRGB(110, 80, 220), glow = Color3.fromRGB(150, 230, 255), special = "starcrystals" },
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-------------------------------------------------------------------------------------------------------------
-- the plaza
-------------------------------------------------------------------------------------------------------------
local function groundAt(groundParts: { Instance }, x: number, z: number, from: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = groundParts
	local hit = workspace:Raycast(Vector3.new(x, from + 60, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else nil
end

-- (29 Oct, the camps "very messy": a plaza stopped wherever a terrace rose inside it) The terraces rising inside the
-- plaza (+ `margin`) are cut down to it, in the run's copy of the world: each ground block (World.Ground's "Floor" top
-- or "FloorSide" body, on the 8-stud grid) reaching above the paving there is split into its columns and those inside
-- are lowered. A world generated after 29 Oct already has a flat clearing there (shared/WorldPlan, step 5b).
local function levelPlaza(w: Instance, c: Vector3, top: number, margin: number)
	local ground = w:FindFirstChild("Ground")
	if not ground then
		return
	end
	local reach = R + margin
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ground }
	local around = workspace:GetPartBoundsInBox(CFrame.new(c.X, top + 40, c.Z), Vector3.new(reach * 2, 80, reach * 2), params)
	local G = Zones.CELL
	for _, p in around do
		local floor = p.Name == "Floor"
		if (floor or p.Name == "FloorSide") and p.Position.Y + p.Size.Y / 2 > top + 0.05 then
			local x0, z0 = p.Position.X - p.Size.X / 2, p.Position.Z - p.Size.Z / 2
			local nx, nz = math.max(1, math.floor(p.Size.X / G + 0.5)), math.max(1, math.floor(p.Size.Z / G + 0.5))
			local function inside(i: number, j: number): boolean
				return Vector2.new(x0 + (i + 0.5) * G - c.X, z0 + (j + 0.5) * G - c.Z).Magnitude <= reach
			end
			local i0, i1, j0, j1 = math.huge, -math.huge, math.huge, -math.huge
			for i = 0, nx - 1 do
				for j = 0, nz - 1 do
					if inside(i, j) then
						i0, i1, j0, j1 = math.min(i0, i), math.max(i1, i), math.min(j0, j), math.max(j1, j)
					end
				end
			end
			if i0 <= i1 then
				local pTop, pBottom = p.Position.Y + p.Size.Y / 2, p.Position.Y - p.Size.Y / 2
				-- a copy of the block over columns [ia, ib] x [ja, jb], from b up to t
				local function piece(ia: number, ib: number, ja: number, jb: number, t: number, b: number)
					if ia <= ib and ja <= jb and t - b > 0.05 then
						local q = p:Clone()
						q.Size = Vector3.new((ib - ia + 1) * G, t - b, (jb - ja + 1) * G)
						q.CFrame = CFrame.new(x0 + (ia + ib + 1) / 2 * G, (t + b) / 2, z0 + (ja + jb + 1) / 2 * G)
						q.Parent = p.Parent
					end
				end
				-- round the cut: four strips as they were
				piece(0, i0 - 1, 0, nz - 1, pTop, pBottom)
				piece(i1 + 1, nx - 1, 0, nz - 1, pTop, pBottom)
				piece(i0, i1, 0, j0 - 1, pTop, pBottom)
				piece(i0, i1, j1 + 1, nz - 1, pTop, pBottom)
				-- in it, column by column: the top layer down to the ground under the pad (just below the paving), the
				-- body under it stopping below that
				local g = top - 0.02
				for i = i0, i1 do
					for j = j0, j1 do
						if not inside(i, j) then
							piece(i, i, j, j, pTop, pBottom)
						elseif floor then
							piece(i, i, j, j, g, g - p.Size.Y)
						else
							piece(i, i, j, j, math.min(pTop, g - 1.2), pBottom)
						end
					end
				end
				p:Destroy()
			end
		end
	end
end

-- Paving on a 4-stud grid round `c` with its top at `top`; stone underneath where the ground is lower, and a
-- step outside the edge where the drop is more than a step. Cells where the ground is higher (a terrace above)
-- are left as they are.
local function plaza(f: Instance, c: Vector3, top: number, th: Theme, groundParts: { Instance }, rng: Random, avoid: { at: Vector2, r: number }?)
	local solid = true
	local cells: { [string]: boolean } = {}
	local n = math.ceil(R / CELL)
	for i = -n, n do
		for j = -n, n do
			local x, z = c.X + i * CELL, c.Z + j * CELL
			-- (`avoid`: the boss arena next to the isles' camp; its rim would cut through the paving)
			if Vector2.new(i * CELL, j * CELL).Magnitude <= R and not (avoid and (Vector2.new(x, z) - avoid.at).Magnitude < avoid.r + CELL * 0.75) then
				local g = groundAt(groundParts, x, z, top)
				if g and g <= top + 1.2 then
					cells[i .. ":" .. j] = true
					local shade = th.tile[1 + ((i + j) % 2)]
					local col = VoxelKit.jitter(rng, shade, 0.04)
					if th.plank then
						-- a boardwalk: three planks a cell
						for k = -1, 1 do
							part(f, "Plank", CFrame.new(x + k * 1.32, top - 0.2, z), Vector3.new(1.22, 0.4, CELL - 0.1), VoxelKit.jitter(rng, col, 0.06), Enum.Material.Wood, solid)
						end
					else
						part(f, "Tile", CFrame.new(x, top - 0.2, z), Vector3.new(CELL - 0.35, 0.4, CELL - 0.35), col, "stone", solid)
						part(f, "TileBed", CFrame.new(x, top - 0.32, z), Vector3.new(CELL, 0.2, CELL), th.bed, nil, solid)
					end
					if g < top - 0.45 then
						local h = top - 0.4 - (g - 0.6)
						part(f, "Footing", CFrame.new(x, g - 0.6 + h / 2, z), Vector3.new(CELL, h, CELL), VoxelKit.jitter(rng, C.stone, 0.05), "stone", solid)
					end
				end
			end
		end
	end
	-- steps down where the plaza ends above lower ground
	for key in cells do
		local i, j = string.match(key, "(-?%d+):(-?%d+)")
		local ci, cj = tonumber(i) :: number, tonumber(j) :: number
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			if not cells[(ci + d[1]) .. ":" .. (cj + d[2])] then
				local x, z = c.X + (ci + d[1]) * CELL, c.Z + (cj + d[2]) * CELL
				local g = groundAt(groundParts, x, z, top)
				if g and g < top - 1.6 and g > top - 9 then
					local h = (top - g) / 2
					part(f, "Step", CFrame.new(x - d[1] * 0.9, g + h / 2, z - d[2] * 0.9), Vector3.new(if d[1] ~= 0 then 2.2 else CELL, h, if d[2] ~= 0 then 2.2 else CELL), VoxelKit.jitter(rng, C.stone, 0.05), "stone", true)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the shared pieces
-------------------------------------------------------------------------------------------------------------
-- The area's generated market stall (owner, 29 Oct: "remake ... all stands"; ServerStorage.GenProps "stall_<area>",
-- server/Models): a solid counter with the prompt on it and the title on the stall's own name board (the template's
-- SignAt / SignSize). False when it isn't there.
local function genStall(m: Model, cf: CFrame, title: string, window: string, area: string): boolean
	local name = "stall_" .. area
	if not Models.isGen(name) then
		return false
	end
	local s = Models.place(name, m, cf, 1, true)
	if not s then
		return false
	end
	local at, size = s:GetAttribute("CounterAt"), s:GetAttribute("CounterSize")
	local counter = PropKit.collider(m, cf, if typeof(at) == "Vector3" then at else Vector3.new(0, 1.7, -1), if typeof(size) == "Vector3" then size else Vector3.new(9, 3.4, 3))
	counter.Name = "Counter"
	local signAt, signSize = s:GetAttribute("SignAt"), s:GetAttribute("SignSize")
	if typeof(signAt) == "CFrame" and typeof(signSize) == "Vector2" then
		local board = Instance.new("Part")
		board.Name = "Board"
		board.Anchored = true
		board.CanCollide = false
		board.CanQuery = false
		board.CanTouch = false
		board.CastShadow = false
		board.Transparency = 1
		board.Size = Vector3.new(signSize.X, signSize.Y, 0.05)
		board.CFrame = cf * signAt
		board.Parent = m
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front -- (toward the customers)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = title
		t.TextColor3 = Color3.fromRGB(255, 240, 200)
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = Color3.fromRGB(60, 36, 20)
		st.Parent = t
		t.Parent = gui
	end
	PropKit.prompt(counter, "Open", title, window, 10)
	return true
end

-- A market stall in the camp's voxel style: log posts, a plank counter, a striped cloth awning, a board with its
-- name, and a prompt that opens `window`. (The area's generated stall when there is one: genStall.)
local function stall(f: Instance, cf: CFrame, title: string, window: string, th: Theme, rng: Random, area: string)
	local m = Instance.new("Model")
	m.Name = title .. "Stall"
	m.Parent = f
	if genStall(m, cf, title, window, area) then
		return
	end
	local counter = part(m, "Counter", cf * CFrame.new(0, 1.7, 0), Vector3.new(9, 3.4, 3), C.board, Enum.Material.WoodPlanks, true)
	part(m, "CounterTop", cf * CFrame.new(0, 3.55, 0), Vector3.new(9.6, 0.4, 3.6), C.timber, nil, true)
	for _, x in { -4.3, 4.3 } do
		VoxelKit.log(m, cf * CFrame.new(x, 4.2, 1.6) * CFrame.Angles(0, 0, math.rad(90)), 8.4, 0.8, 0.8, C.log)
		VoxelKit.log(m, cf * CFrame.new(x, 3.6, -1.6) * CFrame.Angles(0, 0, math.rad(90)), 7.2, 0.7, 0.7, C.log)
	end
	-- striped awning sloping toward the front
	for i = 0, 5 do
		local col = if i % 2 == 0 then th.cloth else Color3.fromRGB(245, 238, 222)
		part(m, "Awning", cf * CFrame.new(-4.25 + i * 1.7, 8, 0) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(1.7, 0.3, 5.4), col, Enum.Material.Fabric)
	end
	-- the name board on top
	local board = part(m, "Board", cf * CFrame.new(0, 9.4, 1.4), Vector3.new(6.4, 1.6, 0.4), C.timber)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- (toward the customers)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = Color3.fromRGB(255, 236, 190)
	t.Parent = gui
	-- goods on the counter
	for k = -1, 1 do
		VoxelKit.crate(m, cf * CFrame.new(k * 2.6, 4.15, -0.2), 0.8, rng)
	end
	PropKit.prompt(counter, "Open", title, window, 10)
end

local function lanternPost(f: Instance, at: Vector3, out: Vector3, th: Theme)
	-- (29 Oct) the generated lamp post (server/Models: ServerStorage.GenProps), its lantern hanging over the plaza
	-- and lit in the area's glow
	if Models.isGen("lantern_post") then
		local m = Models.place("lantern_post", f, CFrame.lookAt(at, at - out), 0.8, true)
		local core = m and m:FindFirstChild("LanternCore")
		local light = core and core:FindFirstChildOfClass("PointLight")
		if light and th.glow then
			light.Color = th.glow
		end
		return
	end
	local cf = CFrame.lookAt(at, at + out)
	VoxelKit.log(f, cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), 6, 0.7, 0.7, C.log)
	part(f, "Arm", cf * CFrame.new(0, 5.8, 0.8), Vector3.new(0.4, 0.4, 1.8), C.timber)
	VoxelKit.lantern(f, cf * CFrame.new(0, 5.6, 1.5), true, th.glow, true)
end

local function bench(f: Instance, cf: CFrame)
	VoxelKit.log(f, cf * CFrame.new(0, 1.1, 0), 5, 0.6, 1.4, C.log)
	VoxelKit.log(f, cf * CFrame.new(0, 1.9, 0.75) * CFrame.Angles(math.rad(-12), 0, 0), 5, 0.9, 0.35, C.log)
	for _, x in { -1.9, 1.9 } do
		part(f, "BenchLeg", cf * CFrame.new(x, 0.4, 0), Vector3.new(0.5, 0.8, 1.2), C.timber, nil, true)
	end
end

local function signboard(f: Instance, cf: CFrame, text: string)
	for _, x in { -2.8, 2.8 } do
		VoxelKit.log(f, cf * CFrame.new(x, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)), 4.8, 0.55, 0.55, C.log)
	end
	local board = part(f, "SignBoard", cf * CFrame.new(0, 4, 0), Vector3.new(6.6, 2.2, 0.4), C.board, Enum.Material.WoodPlanks, true)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 36
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -16, 1, -10)
		t.Position = UDim2.fromOffset(8, 5)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = Color3.fromRGB(255, 240, 200)
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = Color3.fromRGB(60, 36, 20)
		st.Parent = t
		t.Parent = gui
	end
end

-------------------------------------------------------------------------------------------------------------
-- each area's own corner (cf: its spot on the plaza, facing the pad)
-------------------------------------------------------------------------------------------------------------
local SPECIAL: { [string]: (Instance, CFrame, Theme, Random) -> () } = {}

SPECIAL.hayyard = function(f, cf, _th, rng)
	for i = 0, 4 do
		VoxelKit.hay(f, cf * CFrame.new((i % 3 - 1) * 2.6, 0.9 + math.floor(i / 3) * 1.8, math.floor(i / 3) * 0.6), rng)
	end
	VoxelKit.barrel(f, cf * CFrame.new(4.6, 0, 1), 2.4, rng)
	for k = 0, 2 do -- pumpkins
		local p = part(f, "Pumpkin", cf * CFrame.new(-4.4 + k * 1.3, 0.55, -2.4), Vector3.new(1.2, 1.1, 1.2), Color3.fromRGB(236, 128, 34))
		local _ = p
		part(f, "Stalk", cf * CFrame.new(-4.4 + k * 1.3, 1.25, -2.4), Vector3.new(0.2, 0.4, 0.2), Color3.fromRGB(90, 120, 50))
	end
end

SPECIAL.blossomtree = function(f, cf, th, rng)
	VoxelKit.log(f, cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), 7, 1.3, 1.3, C.log)
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		VoxelKit.bush(f, cf * CFrame.new(math.cos(a) * 2.6, 7.2 + (i % 3) * 0.8, math.sin(a) * 2.6), Color3.fromRGB(255, 170, 214), rng)
	end
	VoxelKit.bush(f, cf * CFrame.new(0, 9.2, 0), Color3.fromRGB(255, 196, 228), rng)
	VoxelKit.planter(f, cf * CFrame.new(0, 0, -3.4), 5, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 140, 190) }, rng)
	VoxelKit.lantern(f, cf * CFrame.new(2.4, 6.4, 0), true, th.glow, true)
	VoxelKit.lantern(f, cf * CFrame.new(-2.4, 6.6, 0.4), true, th.glow, true)
end

local function campfireRing(f: Instance, cf: CFrame, flame: Color3?, rng: Random, stoneTint: Color3)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(f, "RingStone", cf * CFrame.new(math.cos(a) * 1.8, 0.35, math.sin(a) * 1.8) * CFrame.Angles(0, -a, 0), Vector3.new(0.9, 0.7, 0.8), VoxelKit.jitter(rng, stoneTint, 0.08), "stone")
	end
	VoxelKit.log(f, cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.rad(30), 0), 2.4, 0.5, 0.5, C.log)
	VoxelKit.log(f, cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(-40), 0), 2.4, 0.5, 0.5, C.log)
	local core = part(f, "Embers", cf * CFrame.new(0, 0.5, 0), Vector3.new(1, 0.3, 1), flame or Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	VoxelKit.fire(core, flame, 1.2)
end

SPECIAL.campfire = function(f, cf, _th, rng)
	campfireRing(f, cf, nil, rng, C.stone)
	for _, a in { 0, 120, 240 } do
		local seat = cf * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -4)
		VoxelKit.log(f, seat * CFrame.new(0, 0.45, 0), 3.4, 0.9, 0.9, C.log)
	end
	-- a little tent
	local tent = cf * CFrame.new(5.5, 0, 2) * CFrame.Angles(0, math.rad(-30), 0)
	for _, s in { -1, 1 } do
		part(f, "Tent", tent * CFrame.new(s * 1.1, 1.5, 0) * CFrame.Angles(0, 0, math.rad(s * -38)), Vector3.new(0.25, 3.6, 4), Color3.fromRGB(200, 150, 90), Enum.Material.Fabric)
	end
	VoxelKit.crate(f, cf * CFrame.new(-5, 0.6, 2), 1.1, rng)
end

SPECIAL.mushrooms = function(f, cf, th, rng)
	for i = 1, 5 do
		local at = cf * CFrame.new((i - 3) * 2.2 + rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-1.5, 1.5))
		local h = rng:NextNumber(1.6, 3.6)
		part(f, "MushStem", at * CFrame.new(0, h / 2, 0), Vector3.new(0.7, h, 0.7), Color3.fromRGB(236, 226, 206))
		local cap = part(f, "MushCap", at * CFrame.new(0, h + 0.3, 0), Vector3.new(h * 0.9, 0.7, h * 0.9), if i % 2 == 0 then Color3.fromRGB(200, 60, 60) else Color3.fromRGB(150, 90, 200))
		local _ = cap
		part(f, "MushDot", at * CFrame.new(0.3, h + 0.68, 0.2), Vector3.new(0.35, 0.1, 0.35), Color3.fromRGB(255, 255, 255))
	end
	-- stilt lamps over the water-dark boards
	for _, x in { -6, 6 } do
		VoxelKit.log(f, cf * CFrame.new(x, 2.6, 2.6) * CFrame.Angles(0, 0, math.rad(90)), 5.2, 0.5, 0.5, C.log)
		VoxelKit.lantern(f, cf * CFrame.new(x, 5.2, 2.6), true, th.glow)
	end
	VoxelKit.barrel(f, cf * CFrame.new(0, 0, 3.2), 2, rng)
end

SPECIAL.icepit = function(f, cf, th, rng)
	campfireRing(f, cf, Color3.fromRGB(255, 170, 80), rng, Color3.fromRGB(210, 226, 240))
	for _, a in { 40, 160, 280 } do
		VoxelKit.crystals(f, cf * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -4.6), Color3.fromRGB(150, 210, 255), rng, 4, true)
	end
	VoxelKit.rocks(f, cf * CFrame.new(4.8, 0, 2.6), Color3.fromRGB(230, 240, 250), rng, 3)
	local _ = th
end

SPECIAL.forge = function(f, cf, th, rng)
	-- anvil on a stump, a brazier each side, basalt and glowing crystals
	VoxelKit.cylinder(f, "Stump", cf, 1.4, 2, C.log, "log")
	part(f, "Anvil", cf * CFrame.new(0, 1.8, 0), Vector3.new(2.2, 0.6, 1), C.iron, "metal")
	part(f, "AnvilHorn", cf * CFrame.new(1.4, 1.85, 0), Vector3.new(0.8, 0.35, 0.5), C.iron, "metal")
	for _, x in { -4, 4 } do
		local bowl = part(f, "Brazier", cf * CFrame.new(x, 2.6, 0), Vector3.new(1.8, 0.8, 1.8), C.iron, "metal")
		part(f, "BrazierLeg", cf * CFrame.new(x, 1.1, 0), Vector3.new(0.5, 2.2, 0.5), C.iron)
		VoxelKit.fire(bowl, th.glow, 1)
	end
	VoxelKit.crystals(f, cf * CFrame.new(0, 0, 3.6), Color3.fromRGB(255, 120, 40), rng, 3, true)
	VoxelKit.rocks(f, cf * CFrame.new(-2.4, 0, 3.2), Color3.fromRGB(60, 54, 56), rng, 3)
end

SPECIAL.starcrystals = function(f, cf, th, rng)
	VoxelKit.crystals(f, cf, Color3.fromRGB(170, 120, 255), rng, 7, true)
	VoxelKit.crystals(f, cf * CFrame.new(3, 0, 1.5), th.glow or Color3.fromRGB(150, 230, 255), rng, 4, true)
	VoxelKit.crystals(f, cf * CFrame.new(-3, 0, 1.2), th.glow or Color3.fromRGB(150, 230, 255), rng, 4, true)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		local star = part(f, "StarLamp", cf * CFrame.new(math.cos(a) * 4.5, 6 + (i % 2), math.sin(a) * 4.5) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(255, 240, 170), Enum.Material.Neon)
		VoxelKit.light(star, 10, 0.6, Color3.fromRGB(255, 230, 170))
	end
end

-------------------------------------------------------------------------------------------------------------
-- building one outpost
-------------------------------------------------------------------------------------------------------------
-- Take the run's copy of the scenery off the plaza: trees, bushes, rocks and the little ground cover.
local function clearSpot(w: Instance, c: Vector3)
	local visuals = w:FindFirstChild("Visuals")
	for _, area in (if visuals then visuals:GetChildren() else {}) do
		for _, d in area:GetChildren() do
			local p = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
			if p and flat(p - c).Magnitude < R + 3 and d.Name ~= "Blocker" and not string.find(d.Name, "Landmark", 1, true) then
				d:Destroy()
			end
		end
	end
end

local function build(w: Instance, pad: BasePart, z: number, info: any, gasPump: any)
	local def = Zones.list[z]
	local th = def and THEMES[def.id]
	if not th then
		return
	end
	local rng = Random.new(500 + z)
	local c = pad.Position
	local top = c.Y - pad.Size.X / 2 + 0.02
	local inward = Vector3.new(def.center.X - c.X, 0, def.center.Y - c.Z)
	local fwd = if inward.Magnitude > 1 then inward.Unit else Vector3.zAxis
	local right = fwd:Cross(UP)
	local base = Vector3.new(c.X, top, c.Z)
	clearSpot(w, c)
	local f = Instance.new("Model")
	f.Name = "Outpost" .. z
	local ground = { w:FindFirstChild("Ground") :: Instance }
	levelPlaza(w, base, top, 1.5)
	local arena = Config.BOSS_ARENAS and Config.BOSS_ARENAS[z]
	local avoid = if arena then { at = Vector2.new(arena.x, arena.z), r = (Config.BOSS_ARENA_RADIUS or 70) + 3 } else nil
	plaza(f, base, top, th, ground, rng, avoid)
	-- the two stalls behind the pad, facing it; the gas pump to one side; a bench either side. (29 Oct, owner: "why is
	-- the middle so close to the stores": they stood against the pad's 9-stud ring; now set back on the bigger plaza,
	-- an open ring round the pad.) All of it turns round the pad, as one, until none of it stands in the boss arena
	-- (the isles' camp has the arena right behind it).
	local PIECES = { { -7.5, -16, 6.5 }, { 7.5, -16, 6.5 }, { 16, -4, 2.5 }, { -16, 2, 3 }, { 16, 5, 3 } }
	local cosT, sinT = 1, 0
	if avoid then
		for _, deg in { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } do
			local a = math.rad(deg)
			local clear = true
			for _, pc in PIECES do
				local x, zz = pc[1] * math.cos(a) + pc[2] * math.sin(a), -pc[1] * math.sin(a) + pc[2] * math.cos(a)
				local p = base + right * x + fwd * zz
				if (Vector2.new(p.X, p.Z) - avoid.at).Magnitude < avoid.r + pc[3] + 2 then
					clear = false
				end
			end
			if clear then
				cosT, sinT = math.cos(a), math.sin(a)
				break
			end
		end
	end
	local function turned(v: Vector3): Vector3
		local x, zz = v:Dot(right), v:Dot(fwd)
		return right * (x * cosT + zz * sinT) + fwd * (-x * sinT + zz * cosT)
	end
	local function at(x: number, zz: number, face: Vector3?): CFrame
		local p = base + turned(right * x + fwd * zz)
		return CFrame.lookAt(p, p + turned(face or fwd))
	end
	stall(f, at(-7.5, -16), "SHOP", "Shop", th, rng, def.id)
	stall(f, at(7.5, -16), "UPGRADES", "Upgrades", th, rng, def.id)
	if gasPump then
		gasPump(f, at(16, -4).Position, info, turned(-right))
	end
	bench(f, at(-16, 2, right))
	bench(f, at(16, 5, -right))
	f.Parent = w
	-- (29 Oct) the rest of the camp: server/CampDress (the old name board is the arch's sign now)
	local CampDress = require(script.Parent.CampDress)
	local ok, err = pcall(CampDress.dress, {
		w = w,
		f = f,
		z = z,
		base = base,
		top = top,
		fwd = fwd,
		right = right,
		R = R,
		rng = rng,
		info = info,
		glow = th.glow,
		lanternPost = function(parent: Instance, p: Vector3, out: Vector3)
			lanternPost(parent, p, out, th)
		end,
	})
	if not ok then
		warn(("[Outposts] area %d dressing: %s"):format(z, tostring(err)))
	end
	w:SetAttribute("Hub" .. z, base)
	w:SetAttribute("HubR" .. z, CampDress.RADIUS)
end

-- Every area's outpost (area 1 has the camp). `gasPump`: RunBuilder's pump maker (adds to info.pumps).
function Outposts.build(w: Instance, info: any, gasPump: any)
	local pads = w:FindFirstChild("Pads")
	if not pads then
		return 0
	end
	local n = 0
	for z = 2, #Zones.list do
		local pad = pads:FindFirstChild("DropOff" .. z)
		if pad and pad:IsA("BasePart") then
			local ok, err = pcall(build, w, pad, z, info, gasPump)
			if ok then
				n += 1
			else
				warn(("[Outposts] area %d: %s"):format(z, tostring(err)))
			end
		end
	end
	return n
end

return Outposts
