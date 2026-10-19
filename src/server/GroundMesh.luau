-- The ground as Blender meshes (Config.GROUND = "Blender"): the lobby, the run hub and each zone are layered
-- ground sheets (tools/blender/models/ground_*.py) over a huge horizon sheet. The sheets have no collisions;
-- players walk on invisible flat colliders whose top is at y = 0, like the Terrain version (server/Ground.luau).
-- Each function returns false when a model isn't uploaded, and the builder uses Terrain instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Models = require(script.Parent.Models)

local GroundMesh = {}

local ZONE_MODEL = { lawn = "ground_lawn", golf = "ground_golf", wheat = "ground_wheat", reeds = "ground_reeds", jungle = "ground_jungle" }

function GroundMesh.enabled(): boolean
	return Config.GROUND == "Blender"
end

-- Ground sheets are flat and everywhere: no shadows, no touch events, nothing to collide with.
local function sheet(name: string, parent: Instance, cf: CFrame): boolean
	local m = Models.place(name, parent, cf, 1, true)
	if not m then
		return false
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CastShadow = false
		end
	end
	return true
end

-- An invisible floor, `w` x `d` studs centred on (cx, cz), top at y = 0.
local function collider(parent: Instance, cx: number, cz: number, w: number, d: number)
	local p = Instance.new("Part")
	p.Name = "GroundCollider"
	p.Anchored = true
	p.Transparency = 1
	p.CastShadow = false
	p.Size = Vector3.new(w, 4, d)
	p.CFrame = CFrame.new(cx, -2, cz)
	p.Parent = parent
end

local function folder(parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = "Ground"
	f.Parent = parent
	return f
end

-- Every ground model this map needs, or nil if one is missing (so we never mix half a mesh ground with Terrain).
local function allLoaded(names: { string }): boolean
	for _, n in names do
		if not Models.has(n) then
			warn("[GroundMesh] " .. n .. " isn't uploaded; using the Terrain ground")
			return false
		end
	end
	return true
end

function GroundMesh.lobby(world: Instance): boolean
	if not GroundMesh.enabled() or not allLoaded({ "ground_lobby", "ground_far" }) then
		return false
	end
	local f = folder(world)
	sheet("ground_far", f, CFrame.new())
	sheet("ground_lobby", f, CFrame.new())
	collider(f, 0, 0, 200, 200) -- the lobby's walls stand at +-100
	return true
end

function GroundMesh.run(world: Instance, hubStart: number, halfWidth: number): boolean
	local names = { "ground_hub", "ground_far" }
	for _, def in Config.ZONES do
		table.insert(names, ZONE_MODEL[def.style] or "ground_lawn")
	end
	if not GroundMesh.enabled() or not allLoaded(names) then
		return false
	end
	local f = folder(world)
	sheet("ground_far", f, CFrame.new(0, 0, Config.zoneStartZ(3)))
	sheet("ground_hub", f, CFrame.new())
	for z, def in Config.ZONES do
		sheet(ZONE_MODEL[def.style] or "ground_lawn", f, CFrame.new(0, 0, Config.zoneStartZ(z)))
	end
	local lastZ = Config.zoneStartZ(#Config.ZONES) + Config.ZONE_SPACING
	collider(f, 0, (hubStart + lastZ) / 2, halfWidth * 2, lastZ - hubStart)
	return true
end

return GroundMesh
