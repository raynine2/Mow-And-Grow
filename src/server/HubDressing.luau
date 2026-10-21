-- The hubs' "umph" (Config.WORLD_GEN): the voxel dressing round the buildings of the lobby plaza and the run's
-- village - a welcome arch with the game's name, a golden mower statue, benches, planters, a signpost, crates,
-- barrels, a wheelbarrow and hay - plus strings of bunting flags over the paths (client/Life sways them), smoke
-- from the cabins' chimneys and a warm light in every lantern. Everything uses server/Models (the voxel props from
-- tools/blender/voxel/props.py); anything not imported is simply skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local Models = require(script.Parent.Models)
local PropKit = require(script.Parent.PropKit)

local HubDressing = {}

local GOLD = Color3.fromRGB(255, 214, 60)
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
	if not put(parent, "welcome_arch", cf) then
		return
	end
	PropKit.facePanel(parent, cf, Vector3.new(0, 15, -0.05), Vector2.new(17, 3.4), text, GOLD)
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

-- The lobby plaza (y = 0): spawn at (0, -46) looking north at the party pads (z 40); cabins at x +-46, z -22.
function HubDressing.lobby(world: Instance)
	if not Config.WORLD_GEN then
		return
	end
	local f = PropKit.folder("Dressing", world)
	arch(f, face(Vector3.new(0, 0, -38), Vector3.new(0, 0, -60)), string.upper(Config.GAME_NAME))
	put(f, "mower_statue", face(Vector3.new(26, 0, 4), Vector3.new(0, 0, 4)), 1)
	for _, p in { Vector3.new(-9.5, 0, -24), Vector3.new(9.5, 0, -24), Vector3.new(-9.5, 0, 16), Vector3.new(9.5, 0, 16) } do
		put(f, "bench", face(p, Vector3.new(0, 0, p.Z)))
	end
	for _, p in { Vector3.new(-9, 0, -4), Vector3.new(9, 0, -4), Vector3.new(-9, 0, 30), Vector3.new(9, 0, 30) } do
		put(f, "planter", face(p, Vector3.new(0, 0, p.Z)))
	end
	put(f, "signpost", face(Vector3.new(7, 0, -16), Vector3.new(0, 0, 0)))
	put(f, "wheelbarrow", face(Vector3.new(31, 0, -36), Vector3.new(20, 0, -30)))
	put(f, "hay_bale", face(Vector3.new(37, 0, -41), Vector3.new(30, 0, -30)))
	put(f, "crate_stack", face(Vector3.new(-31, 0, -37), Vector3.new(-20, 0, -30)))
	put(f, "barrel", face(Vector3.new(-35, 0, -40), Vector3.new(0, 0, 0)))
	put(f, "barrel", face(Vector3.new(-33, 0, -42), Vector3.new(0, 0, 0)))
	put(f, "crate_stack", face(Vector3.new(-38, 0, 30), Vector3.new(-30, 0, 20)))
	-- bunting over the main walk, from the lantern posts, and across the arch
	for _, z in { -14, 6, 24 } do
		bunting(f, Vector3.new(-13, 7.6, z), Vector3.new(13, 7.6, z), 1.4)
	end
	bunting(f, Vector3.new(-13, 7.6, -34), Vector3.new(-12, 17.5, -38), 0.6)
	bunting(f, Vector3.new(13, 7.6, -34), Vector3.new(12, 17.5, -38), 0.6)
	lifeFor(world)
	hideSpawn(world)
end

-- The run's village (y = 0): spawn at (0, -68) looking north, shredder (-24, -36), tool shop (24, -40), bag stand
-- (28, -68), garage (-30, -64), fountain (0, 0), the way to the first area north of it.
function HubDressing.village(world: Instance)
	if not Config.WORLD_GEN then
		return
	end
	local f = PropKit.folder("Dressing", world)
	local first = Zones.list[1]
	arch(f, face(Vector3.new(0, 0, 22), Vector3.new(0, 0, 0)), string.upper(first.name) .. "  >")
	put(f, "mower_statue", face(Vector3.new(16, 0, -20), Vector3.new(0, 0, -20)), 1)
	for _, p in { Vector3.new(-11, 0, 0), Vector3.new(11, 0, 0), Vector3.new(0, 0, -12) } do
		put(f, "bench", face(p, Vector3.new(0, 0, 0)))
	end
	for _, p in { Vector3.new(-7, 0, -56), Vector3.new(7, 0, -56), Vector3.new(-7, 0, -26), Vector3.new(7, 0, -26) } do
		put(f, "planter", face(p, Vector3.new(0, 0, p.Z)))
	end
	put(f, "signpost", face(Vector3.new(6, 0, -46), Vector3.new(0, 0, -40)))
	put(f, "crate_stack", face(Vector3.new(-36, 0, -27), Vector3.new(-24, 0, -36)))
	put(f, "barrel", face(Vector3.new(-38, 0, -31), Vector3.new(0, 0, 0)))
	put(f, "barrel", face(Vector3.new(-37, 0, -34), Vector3.new(0, 0, 0)))
	put(f, "wheelbarrow", face(Vector3.new(-12, 0, -52), Vector3.new(-24, 0, -40)))
	put(f, "hay_bale", face(Vector3.new(40, 0, -72), Vector3.new(28, 0, -68)))
	put(f, "hay_bale", face(Vector3.new(40, 0, -63), Vector3.new(28, 0, -68)))
	-- bunting over the main walk on log poles, and from the arch
	for _, z in { -52, -30 } do
		for _, x in { -8, 8 } do
			put(f, "lantern_post", face(Vector3.new(x, 0, z), Vector3.new(0, 0, z)))
		end
		bunting(f, Vector3.new(-8, 7.6, z), Vector3.new(8, 7.6, z), 1.2)
	end
	bunting(f, Vector3.new(-8, 7.6, -30), Vector3.new(-11, 17.5, 22), 2.5)
	bunting(f, Vector3.new(8, 7.6, -30), Vector3.new(11, 17.5, 22), 2.5)
	lifeFor(world)
	hideSpawn(world)
end

return HubDressing
