-- The hubs' "umph" (Config.WORLD_GEN): the voxel dressing round the buildings of the lobby plaza and the run's
-- village - a welcome arch with the game's name, a golden mower statue, benches, planters, crates and barrels and
-- hay, set out in mirrored pairs - plus strings of bunting flags over the paths (client/Life sways them), smoke
-- from the cabins' chimneys and a warm light in every lantern. Everything uses server/Models (the voxel props from
-- tools/blender/voxel/props.py); anything not imported is simply skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local Models = require(script.Parent.Models)
local PropKit = require(script.Parent.PropKit)

local HubDressing = {}

local yard: (Instance, Instance) -> ()

local FLAG_COLORS = {
	Color3.fromRGB(232, 72, 66),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(70, 140, 230),
	Color3.fromRGB(96, 182, 72),
	Color3.fromRGB(240, 110, 170),
	Color3.fromRGB(250, 246, 236),
}

local function face(from: Vector3, toward: Vector3): CFrame
	return CFrame.lookAt(from, Vector3.new(toward.X, from.Y, toward.Z))
end

local function put(parent: Instance, name: string, cf: CFrame, scale: number?)
	return Models.place(name, parent, cf, scale or 1, false)
end

-- A string of triangle flags from a to b, sagging in the middle (the client sways each flag in the wind).
local function bunting(parent: Instance, a: Vector3, b: Vector3, sag: number?)
	local f = Instance.new("Model")
	f.Name = "Bunting"
	local len = (b - a).Magnitude
	local n = math.max(2, math.floor(len / 2.2))
	local drop = sag or len * 0.08
	local prev = a
	for i = 1, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * drop, 0)
		-- the rope between this point and the last
		local mid = (prev + p) / 2
		local rope = Instance.new("Part")
		rope.Name = "Rope"
		rope.Anchored = true
		rope.CanCollide = false
		rope.CanQuery = false
		rope.CanTouch = false
		rope.CastShadow = false
		rope.Size = Vector3.new(0.12, 0.12, (p - prev).Magnitude + 0.05)
		rope.CFrame = CFrame.lookAt(mid, p)
		rope.Color = Color3.fromRGB(90, 70, 50)
		rope.Material = Enum.Material.SmoothPlastic
		rope.Parent = f
		if i < n then
			local flag = Instance.new("WedgePart")
			flag.Name = "BuntingFlag"
			flag.Anchored = true
			flag.CanCollide = false
			flag.CanQuery = false
			flag.CanTouch = false
			flag.CastShadow = false
			flag.Size = Vector3.new(0.1, 1.3, 1.1)
			-- a wedge pointing down: its slope faces down, its top edge on the rope
			local along = (b - a).Unit
			-- the wedge's triangle lies in its YZ plane: Z along the rope, flipped so its long edge is on top
			local c = p - Vector3.new(0, 0.65, 0)
			flag.CFrame = CFrame.lookAt(c, c + along) * CFrame.Angles(math.pi, 0, 0)
			flag.Color = FLAG_COLORS[(i % #FLAG_COLORS) + 1]
			flag.Material = Enum.Material.SmoothPlastic
			flag.Parent = f
		end
		prev = p
	end
	f.Parent = parent
	return f
end

-- The welcome arch with a line of text on its board.
local function arch(parent: Instance, cf: CFrame, text: string)
	if not Config.HUB_SIGNS then
		return -- the arches are mostly their sign board
	end
	if not put(parent, "welcome_arch", cf) then
		return
	end
	PropKit.facePanel(parent, cf, Vector3.new(0, 14.7, -0.72), Vector2.new(17, 3.6), text, PropKit.TITLE)
	-- the pillars are solid; the way under the arch stays open
	for _, x in { -11, 11 } do
		PropKit.collider(parent, cf, Vector3.new(x, 9, -0.5), Vector3.new(4, 18, 3))
	end
end

-- The wooden spawn slab doesn't fit the voxel plaza: keep it (players still spawn there) but unseen.
local function hideSpawn(world: Instance)
	for _, d in world:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Transparency = 1
			d.CanCollide = false
			local decal = d:FindFirstChildOfClass("Decal")
			if decal then
				decal.Transparency = 1
			end
		end
	end
end

-- Chimney smoke for every voxel cabin, warm light in every lantern (looked for by model name under `world`).
local function lifeFor(world: Instance)
	for _, m in world:GetDescendants() do
		if m:IsA("Model") and m.Name == "log_cabin" then
			local s = m:GetScale()
			local spot = PropKit.part({ size = Vector3.one, cf = m:GetPivot() * CFrame.new(Vector3.new(8.5, 23, 7) * s), color = Color3.new(1, 1, 1), parent = m, transparency = 1, collide = false, name = "ChimneySmoke" })
			spot.CanQuery = false
			local smoke = Instance.new("ParticleEmitter")
			smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
			smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235), Color3.fromRGB(190, 190, 195))
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			smoke.Lifetime = NumberRange.new(3, 5)
			smoke.Rate = 4
			smoke.Speed = NumberRange.new(2, 3)
			smoke.SpreadAngle = Vector2.new(10, 10)
			smoke.Acceleration = Vector3.new(1.2, 0.4, 0.8)
			smoke.RotSpeed = NumberRange.new(-30, 30)
			smoke.Parent = spot
		elseif m:IsA("Model") and m.Name == "lantern_post" then
			-- warm amber glass inside the lantern's open frame (no neon: the hubs' bloom blows neon up into a blob)
			-- and a soft light round it
			local s = m:GetScale()
			local core = PropKit.part({ size = Vector3.new(1.1, 1.6, 1.1) * s, cf = m:GetPivot() * CFrame.new(Vector3.new(0, 4.75, -2.5) * s), color = Color3.fromRGB(255, 178, 72), parent = m, collide = false, name = "LanternCore", material = Enum.Material.SmoothPlastic })
			core.CanQuery = false
			core.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 190, 110)
			light.Brightness = 1.2
			light.Range = 9
			light.Shadows = false
			light.Parent = core
		end
	end
end

-- Props stand in pairs, mirrored across the walk, square to it and off the paving: the plaza reads planned, not
-- scattered.
local function pair(parent: Instance, name: string, x: number, z: number)
	for _, sx in { -1, 1 } do
		put(parent, name, face(Vector3.new(x * sx, 0, z), Vector3.new(0, 0, z)))
	end
end

-- The lobby plaza (y = 0): spawn at (0, -46) looking north at the party pads (z 40); the walk runs up x = 0 (12 wide)
-- with lantern posts at x +-13; the garage (x 46) and the classes cabin (x -46) face it across z -22.
function HubDressing.lobby(world: Instance)
	if not Config.WORLD_GEN then
		return
	end
	local f = PropKit.folder("Dressing", world)
	arch(f, face(Vector3.new(0, 0, -38), Vector3.new(0, 0, -60)), string.upper(Config.GAME_NAME))
	-- just a bench on each side of the walk, between the lamp posts: the plaza stays open and calm
	pair(f, "bench", 9.5, -4)
	pair(f, "bench", 9.5, 15)
	lifeFor(world)
	hideSpawn(world)
end

-- The village yard: a wooden fence round the buildings (open at the north for the walk to the arch) and rows of
-- trees filling the floor between the fence and the stone walls, so the yard feels enclosed, like the lobby's.
local YARD = { minX = -54, maxX = 54, minZ = -90, maxZ = 28, gate = 12 }
function yard(world: Instance, f: Instance)
	local HubKit = require(script.Parent.HubKit)
	local y = 0
	local c = {
		Vector3.new(YARD.minX, y, YARD.minZ),
		Vector3.new(YARD.maxX, y, YARD.minZ),
		Vector3.new(YARD.maxX, y, YARD.maxZ),
		Vector3.new(YARD.gate, y, YARD.maxZ),
		Vector3.new(-YARD.gate, y, YARD.maxZ),
		Vector3.new(YARD.minX, y, YARD.maxZ),
	}
	HubKit.fence(f, c[1], c[2])
	HubKit.fence(f, c[2], c[3])
	HubKit.fence(f, c[3], c[4])
	HubKit.fence(f, c[5], c[6])
	HubKit.fence(f, c[6], c[1])
	-- trees on the village floor outside the fence (only where the ground is the floor's height)
	local ground = world:FindFirstChild("Ground")
	if not ground then
		return
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { ground }
	local rng = Random.new(9)
	local trees = PropKit.folder("YardTrees", f)
	for x = -150, 150, 14 do
		for z = -170, 80, 14 do
			local px, pz = x + rng:NextNumber(-2.5, 2.5), z + rng:NextNumber(-2.5, 2.5)
			local outside = px < YARD.minX - 6 or px > YARD.maxX + 6 or pz < YARD.minZ - 6 or pz > YARD.maxZ + 6
			local stairs = math.abs(px) < 16 and pz > YARD.maxZ - 4
			if outside and not stairs then
				local hit = workspace:Raycast(Vector3.new(px, 40, pz), Vector3.new(0, -60, 0), ray)
				-- on the floor, and not right against a wall (a wall shows as a higher hit close by)
				if hit and math.abs(hit.Position.Y) < 1 and hit.Normal.Y > 0.9 then
					local near = workspace:Raycast(Vector3.new(px + 5, 40, pz + 5), Vector3.new(0, -60, 0), ray)
					local near2 = workspace:Raycast(Vector3.new(px - 5, 40, pz - 5), Vector3.new(0, -60, 0), ray)
					if near and near2 and math.abs(near.Position.Y) < 1 and math.abs(near2.Position.Y) < 1 then
						HubKit.tree(trees, hit.Position, rng:NextNumber(1.3, 1.55), "meadow", rng)
					end
				end
			end
		end
	end
end

-- The run's village (y = 0): a main walk from the spawn (0, -74) north past the fountain (0, 0) to the arch; tool
-- shop and garage on its west side, bag stand and shredder on the east (server/RunBuilder SPOT).
function HubDressing.village(world: Instance)
	if not Config.WORLD_GEN then
		return
	end
	local f = PropKit.folder("Dressing", world)
	local first = Zones.list[1]
	arch(f, face(Vector3.new(0, 0, 22), Vector3.new(0, 0, 0)), string.upper(first.name))
	-- benches by the fountain, lamp posts in pairs down the main walk, hay either side of the bag stand: few
	-- things, each where you'd expect it (the buildings' spots: server/RunBuilder SPOT)
	pair(f, "bench", 11, 0)
	for _, z in { -62, -30 } do
		pair(f, "lantern_post", 6.5, z)
	end
	for _, z in { -60, -36 } do
		put(f, "hay_bale", face(Vector3.new(33, 0, z), Vector3.new(0, 0, z)))
	end
	yard(world, f)
	lifeFor(world)
	hideSpawn(world)
end

return HubDressing
