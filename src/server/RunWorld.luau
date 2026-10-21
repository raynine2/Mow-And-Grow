-- A run in the generated world (Config.WORLD_GEN): server/WorldGen's village and eight valleys instead of
-- RunBuilder's 3 x 3 plots. Gives server/Run the same `info` RunBuilder.build does:
--   * the world: the one built in Studio and saved in the place (Workspace.World, set aside at server start by
--     RunWorld.stash so the lobby doesn't replace it), else built now with WorldGen.build (slower);
--   * the hub buildings (tool shop, bag stand, garage, shredder, spawn) in the village, from RunBuilder.hub;
--   * the gates (World.Gates.Gate<z>, closed until the area before is mowed bare; Run opens them);
--   * the drop-off pads in every valley as extra sell spots;
--   * where the grass grows (RunWorld.patches, read by server/Field): clumps scattered in World.Patches.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Zones = require(ReplicatedStorage.MowALawn.Zones)
local RunBuilder = require(script.Parent.RunBuilder)

local RunWorld = {}

local STASH = "GenWorld"
local world: Instance? = nil

-- At server start (before the lobby builds its own World): keep the generated world saved in the place.
function RunWorld.stash()
	local w = workspace:FindFirstChild("World")
	if w and w:GetAttribute("GatePos2") ~= nil and not ServerStorage:FindFirstChild(STASH) then
		w.Name = STASH
		w.Parent = ServerStorage
	end
end

-- A gate's closed look: blockers stand; a missing bridge (chasm gates) shows as a faint ghost you fall through.
local function closeGate(gate: Instance)
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Walkway" then
			p:SetAttribute("SolidTransparency", p.Transparency)
			p.Transparency = 0.8
			p.CanCollide = false
			p.CanQuery = false
		end
	end
end

-- Open it (server/Run calls this): blockers stop blocking and fade (after `hideAfter` s, while the client's
-- banner shows), the bridge becomes solid, the "mow all of ... to open" sign goes.
function RunWorld.openGate(gate: Instance, hideAfter: number?)
	for _, p in gate:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Walkway" then
				p.Transparency = p:GetAttribute("SolidTransparency") or 0
				p.CanCollide = true
				p.CanQuery = true
			elseif p.Name == "Blocker" then
				p.CanCollide = false
			end
		end
	end
	local function hide()
		for _, p in gate:GetDescendants() do
			if p:IsA("BasePart") and (p.Name == "Blocker" or string.sub(p.Name, 1, 4) == "Sign") then
				p.Transparency = 1
				p.CanCollide = false
			elseif p:IsA("SurfaceGui") then
				p.Enabled = false
			end
		end
	end
	if hideAfter then
		task.delay(hideAfter, hide)
	else
		hide()
	end
end

-- The village's blockout buildings make way for the real hub buildings.
local function clearVillage(w: Instance)
	local v = w:FindFirstChild("Village")
	if v then
		for _, c in v:GetChildren() do
			if c.Name ~= "Fountain" and c.Name ~= "FountainWater" then
				c:Destroy()
			end
		end
	end
	local spawn = w:FindFirstChild("Spawn")
	if spawn then
		spawn:Destroy()
	end
end

-- Cobblestone paths across the village between the hub buildings (like the lobby's: server/HubPaths).
local PATHS = {
	{ Vector2.new(0, -78), Vector2.new(0, 30) }, -- spawn -> fountain -> the way north to the meadow
	{ Vector2.new(-34, -40), Vector2.new(30, -40) }, -- shredder <-> tool shop
	{ Vector2.new(-30, -64), Vector2.new(28, -64) }, -- garage <-> bag stand
}
local SQUARE = { Vector2.new(0, -3), Vector2.new(0, 3), 30 } -- the paved square round the fountain
local function paths(w: Instance)
	local segments = {}
	for _, s in PATHS do
		table.insert(segments, { a = s[1], b = s[2], width = 11 })
	end
	table.insert(segments, { a = SQUARE[1], b = SQUARE[2], width = SQUARE[3] })
	require(script.Parent.HubPaths).lay(w, segments, 0, 5)
end

-- Players who fall into the sea, a gorge or lava come back at the way into the area they're working on.
local function safetyNet(info)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and root.Position.Y < Zones.SEA - 4 then
					local z = info.zone and info.zone() or 1
					local at = if z > 1 then Config.zoneEntry(z) else Config.zoneCentre(0) + Vector3.new(0, 0, -20)
					char:PivotTo(CFrame.new(at + Vector3.new(0, 5, 0)))
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

function RunWorld.build()
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	workspace.Terrain:Clear() -- the lobby's Terrain ground; this world is all parts
	local saved = ServerStorage:FindFirstChild(STASH)
	local w: Instance
	if saved then
		w = saved:Clone()
		w.Name = "World"
		w.Parent = workspace
	else
		w = require(script.Parent.WorldGen).build()
	end
	world = w
	require(script.Parent.WorldGen).lighting()
	clearVillage(w)

	local info = { world = w, gates = {}, pumps = {}, sellPads = {}, meshGround = true }
	paths(w)
	RunBuilder.hub(w, info)
	require(script.Parent.HubDressing).village(w)

	local gates = w:FindFirstChild("Gates")
	for _, g in (if gates then gates:GetChildren() else {}) do
		local z = g:GetAttribute("Zone")
		if typeof(z) == "number" then
			closeGate(g)
			g:SetAttribute("NewWorld", true)
			table.insert(info.gates, { b = z, model = g })
		end
	end

	local pads = w:FindFirstChild("Pads")
	for _, pad in (if pads then pads:GetChildren() else {}) do
		if pad:IsA("BasePart") and pad:GetAttribute("Sell") then
			local top = pad.Position + Vector3.new(0, pad.Size.X / 2, 0)
			table.insert(info.sellPads, { pos = top, radius = 7, mouth = top + Vector3.new(0, 5, 0), out = top })
		end
	end

	safetyNet(info)
	return info
end

-------------------------------------------------------------------------------------------------------------
-- where the grass grows
-------------------------------------------------------------------------------------------------------------
local cache: { [number]: { { cf: CFrame, scale: number } } } = {}

-- How big a zone's clumps are (the Blender clump is ~5.4 studs wide, ~7 tall): the zone's spacing sets it, so
-- clumps nearly touch, like the trees of a Chop A Forest wood.
function RunWorld.clumpScale(z: number): number
	local def = Config.ZONES[z]
	return math.clamp((def and def.spacing or 11) / 6, 1.5, 2.3)
end

-- Clump spots in zone z: a jittered grid inside every patch disc of World.Patches.Zone<z>, standing on the floor.
function RunWorld.patches(z: number): { { cf: CFrame, scale: number } }
	if cache[z] then
		return cache[z]
	end
	local list = {}
	local w = world or workspace:FindFirstChild("World")
	local folder = w and w:FindFirstChild("Patches")
	local discs = folder and folder:FindFirstChild("Zone" .. z)
	local ground = w and w:FindFirstChild("Ground")
	if not discs or not ground then
		cache[z] = list
		return list
	end
	local def = Config.ZONES[z]
	local spacing = math.clamp((def and def.spacing or 11) * 0.9, 7, 13)
	local scale = RunWorld.clumpScale(z)
	local rng = Random.new(z * 7919)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { ground }
	local placed: { Vector3 } = {}
	local function free(p: Vector3): boolean
		for _, q in placed do
			if (Vector3.new(q.X - p.X, 0, q.Z - p.Z)).Magnitude < spacing * 0.85 then
				return false
			end
		end
		return true
	end
	local kids = discs:GetChildren()
	table.sort(kids, function(a, b)
		return a.Name < b.Name
	end)
	for _, d in kids do
		if d:IsA("BasePart") then
			local c = d.Position
			local r = d.Size.Y / 2 - 2
			local n = math.ceil(r / spacing)
			for i = -n, n do
				for j = -n, n do
					local x = c.X + (i + (j % 2) * 0.5) * spacing + rng:NextNumber(-1.5, 1.5)
					local zz = c.Z + j * spacing * 0.87 + rng:NextNumber(-1.5, 1.5)
					local flatD = Vector2.new(x - c.X, zz - c.Z).Magnitude
					if flatD <= r then
						local hit = workspace:Raycast(Vector3.new(x, c.Y + 40, zz), Vector3.new(0, -80, 0), ray)
						if hit and hit.Normal.Y > 0.9 and math.abs(hit.Position.Y - (c.Y - 0.5)) < 6.5 then
							local p = hit.Position
							if free(p) then
								table.insert(placed, p)
								local yaw = rng:NextInteger(0, 3) * math.pi / 2
								table.insert(list, { cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0), scale = scale * rng:NextNumber(0.9, 1.1) })
							end
						end
					end
				end
			end
		end
	end
	cache[z] = list
	return list
end

return RunWorld
