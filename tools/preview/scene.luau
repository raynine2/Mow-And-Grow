-- Runs the game's real world builders outside Roblox (Lune + a small fake Instance tree) and writes every
-- visible part to JSON, so tools/preview/render.py can draw a picture of the map without Studio.
--   lune run tools/preview/scene.luau lobby /tmp/lobby.json
--   lune run tools/preview/scene.luau run   /tmp/run.json
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local mode = process.args[1] or "lobby"
local outPath = process.args[2] or "/tmp/scene.json"

-------------------------------------------------------------------------------------------------------------
-- fake Instances
-------------------------------------------------------------------------------------------------------------
local PART_CLASSES = { Part = true, SpawnLocation = true, VehicleSeat = true, WedgePart = true, Seat = true }
local EVENTS = {
	Triggered = true, Touched = true, Changed = true, Activated = true, Deactivated = true, Equipped = true,
	Unequipped = true, Destroying = true, OnServerEvent = true, ChildAdded = true, Heartbeat = true,
	PlayerAdded = true, PlayerRemoving = true, CharacterAdded = true, Completed = true,
}
local signal = { Connect = function() return { Disconnect = function() end } end, Wait = function() end }

local Instance = {}
local methods = {}
local meta = {}

local function newInstance(className: string)
	local self = setmetatable({ _props = { Name = className }, _children = {}, _attrs = {}, ClassName = className }, meta)
	if PART_CLASSES[className] then
		self._props.Size = roblox.Vector3.new(4, 1, 2)
		self._props.CFrame = roblox.CFrame.new()
		self._props.Color = roblox.Color3.fromRGB(163, 162, 165)
		self._props.Transparency = 0
		self._props.Material = roblox.Enum.Material.Plastic
		self._props.Shape = roblox.Enum.PartType.Block
	end
	return self
end
Instance.new = function(className: string, parent: any?)
	local i = newInstance(className)
	if parent then
		i.Parent = parent
	end
	return i
end

meta.__index = function(self, key)
	if key == "Position" and rawget(self, "_props").CFrame then
		return self._props.CFrame.Position
	end
	local v = rawget(self, "_props")[key]
	if v ~= nil then
		return v
	end
	if methods[key] then
		return methods[key]
	end
	if EVENTS[key] then
		return signal
	end
	for _, c in rawget(self, "_children") do
		if c._props.Name == key then
			return c
		end
	end
	return nil
end
meta.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = self._props.Parent
		if old then
			local list = old._children
			local idx = table.find(list, self)
			if idx then
				table.remove(list, idx)
			end
		end
		self._props.Parent = value
		if value then
			table.insert(value._children, self)
		end
	elseif key == "Position" and typeof(value) == "Vector3" and self._props.CFrame then
		self._props.CFrame = roblox.CFrame.new(value) * self._props.CFrame.Rotation
	else
		self._props[key] = value
	end
end
meta.__tostring = function(self)
	return self._props.Name
end

function methods.FindFirstChild(self, name, recursive)
	for _, c in self._children do
		if c._props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in self._children do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods.FindFirstChildOfClass(self, cls)
	for _, c in self._children do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end
function methods.GetChildren(self)
	return table.clone(self._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in n._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.IsA(self, cls)
	if cls == "Instance" or self.ClassName == cls then
		return true
	end
	if cls == "BasePart" then
		return PART_CLASSES[self.ClassName] == true
	end
	if cls == "Player" then
		return false
	end
	return false
end
function methods.SetAttribute(self, k, v)
	self._attrs[k] = v
end
function methods.GetAttribute(self, k)
	return self._attrs[k]
end
function methods.Destroy(self)
	self.Parent = nil
end
function methods.GetPropertyChangedSignal()
	return signal
end
function methods.GetAttributeChangedSignal()
	return signal
end
function methods.SetNetworkOwner() end
function methods.GetPlayers()
	return {}
end
function methods.IsStudio()
	return true
end
function methods.GetPivot(self)
	return if self._props.PrimaryPart then self._props.PrimaryPart.CFrame else roblox.CFrame.new()
end

-------------------------------------------------------------------------------------------------------------
-- services + module loading
-------------------------------------------------------------------------------------------------------------
local game = newInstance("DataModel")
local services = {}
local function service(name)
	if not services[name] then
		local s = newInstance(name)
		s.Parent = game
		services[name] = s
	end
	return services[name]
end
methods.GetService = function(_, name)
	return service(name)
end
local workspace = service("Workspace")
workspace.Name = "Workspace"

-- Terrain stand-in: every fill becomes a part (later fills sit a hair higher so they show on top, the way a
-- fill replaces the material underneath), so the preview shows the ground.
local terrainColors = {}
local fills = 0
local terrainFolder = newInstance("Folder")
terrainFolder.Name = "TerrainPreview"
terrainFolder.Parent = workspace
local function terrainPart(shape, size, cf, material)
	fills += 1
	local p = newInstance("Part")
	p.Name = "Terrain"
	p.Shape = roblox.Enum.PartType[shape]
	p.Size = size
	p.CFrame = cf + roblox.Vector3.new(0, fills * 0.003, 0)
	p.Material = if material.Name == "Water" then roblox.Enum.Material.Glass else material
	p.Color = terrainColors[material.Name] or roblox.Color3.fromRGB(100, 170, 60)
	if material.Name == "Water" then
		p.Color = roblox.Color3.fromRGB(46, 120, 110)
		p.Transparency = 0.25
	end
	p.Parent = terrainFolder
end
local terrain = newInstance("Terrain")
terrain.Name = "Terrain"
rawset(terrain, "_terrain", true)
terrain.Parent = workspace
methods.Clear = function() end
methods.SetMaterialColor = function(_, material, color)
	terrainColors[material.Name] = color
end
methods.FillBlock = function(_, cf, size, material)
	terrainPart("Block", size, cf, material)
end
methods.FillCylinder = function(_, cf, height, radius, material)
	terrainPart("Cylinder", roblox.Vector3.new(height, radius * 2, radius * 2), cf * roblox.CFrame.Angles(0, 0, math.rad(90)), material)
end
methods.FillBall = function(_, center, radius, material)
	terrainPart("Ball", roblox.Vector3.new(radius * 2, radius * 2, radius * 2), roblox.CFrame.new(center), material)
end

local sources: { [any]: string } = {}
local function moduleFolder(parent, name, dir)
	local folder = newInstance("Folder")
	folder.Name = name
	folder.Parent = parent
	for _, file in fs.readDir(dir) do
		local modName = file:gsub("%.server%.luau$", ""):gsub("%.client%.luau$", ""):gsub("%.luau$", "")
		if file:match("%.luau$") and not file:match("%.server%.luau$") and not file:match("%.client%.luau$") then
			local m = newInstance("ModuleScript")
			m.Name = modName
			m.Parent = folder
			sources[m] = dir .. "/" .. file
		end
	end
	return folder
end
moduleFolder(service("ReplicatedStorage"), "MowALawn", "src/shared")
local serverFolder = moduleFolder(service("ServerScriptService"), "MowALawn", "src/server")

-- Blender models: a stand-in for server/Models that records where each model goes. Their bounds come from
-- MODEL_BOUNDS (a JSON file of { name = { centre = {x,y,z}, size = {x,y,z} } }, see tools/preview/bounds.py);
-- blender_render.py then draws the real GLBs there.
local bounds = {}
local boundsPath = process.env.MODEL_BOUNDS
if boundsPath and fs.isFile(boundsPath) then
	bounds = serde.decode("json", fs.readFile(boundsPath))
end
local placedModels = {}
local function fakeModel(name, cf, scale)
	local m = newInstance("Model")
	m.Name = name
	rawset(m, "_glb", { name = name, pivot = cf, scale = scale or 1 })
	table.insert(placedModels, m)
	return m
end
methods.PivotTo = function(self, cf)
	local g = rawget(self, "_glb")
	if g then
		g.pivot = cf
	end
end
methods.ScaleTo = function(self, s)
	local g = rawget(self, "_glb")
	if g then
		g.scale = s
	end
end
methods.GetBoundingBox = function(self)
	local g = rawget(self, "_glb")
	local b = g and bounds[g.name]
	if not b then
		return if g then g.pivot else roblox.CFrame.new(), roblox.Vector3.new(4, 4, 4)
	end
	local c = roblox.Vector3.new(b.centre[1], b.centre[2], b.centre[3]) * g.scale
	return g.pivot * roblox.CFrame.new(c), roblox.Vector3.new(b.size[1], b.size[2], b.size[3]) * g.scale
end
local ModelsStub = {
	loadAll = function() end,
	has = function(name)
		return bounds[name] ~= nil
	end,
	place = function(name, parent, cf, scale)
		if not bounds[name] then
			return nil
		end
		local m = fakeModel(name, cf, scale)
		m.Parent = parent
		return m
	end,
	weldTo = function() end,
}

-- stand-ins for systems that talk to the network
local stubs = {
	Net = setmetatable({}, { __index = function() return function() end end }),
	Models = ModelsStub,
}

local Random = {}
Random.new = function(seed)
	local state = math.floor(seed or os.clock() * 1000) % 2147483647
	if state <= 0 then
		state = state + 2147483646
	end
	local function nextFloat()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_, a, b)
			a = a or 0
			b = b or 1
			return a + (b - a) * nextFloat()
		end,
		NextInteger = function(_, a, b)
			return math.floor(a + (b - a + 1) * nextFloat())
		end,
	}
end

local cache = {}
local env
local function requireModule(m)
	if cache[m] then
		return cache[m]
	end
	if stubs[m.Name] then
		return stubs[m.Name]
	end
	local path = sources[m]
	assert(path, "no source for " .. tostring(m))
	local chunkEnv = table.clone(env)
	chunkEnv.script = m
	local fn = luau.load(luau.compile(fs.readFile(path)), { debugName = path, environment = chunkEnv })
	local result = fn()
	cache[m] = result
	return result
end

env = {
	game = game, workspace = workspace, script = nil, require = requireModule,
	Instance = Instance, Random = Random,
	Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	UDim = roblox.UDim, UDim2 = roblox.UDim2, Enum = roblox.Enum, ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange, PhysicalProperties = roblox.PhysicalProperties,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	math = math, string = string, table = table, os = os, pairs = pairs, ipairs = ipairs, next = next,
	type = type, typeof = typeof, tostring = tostring, tonumber = tonumber, select = select, error = error,
	assert = assert, pcall = pcall, print = print, warn = print, setmetatable = setmetatable, getmetatable = getmetatable,
	rawget = rawget, rawset = rawset, unpack = table.unpack,
	task = { wait = function() return 0 end, spawn = function(f, ...) f(...) end, delay = function() end, defer = function(f, ...) f(...) end },
}

-------------------------------------------------------------------------------------------------------------
-- build + export
-------------------------------------------------------------------------------------------------------------
if mode == "lobby" then
	requireModule(serverFolder.LobbyBuilder).build()
else
	local info = requireModule(serverFolder.RunBuilder).build()
	requireModule(serverFolder.Field).build(info.world, tonumber(process.args[3]) or 1)
end

local parts = {}
for _, d in workspace:GetDescendants() do
	if PART_CLASSES[d.ClassName] and (d._props.Transparency or 0) < 0.99 then
		local p = d._props
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
		table.insert(parts, {
			s = { p.Size.X, p.Size.Y, p.Size.Z },
			c = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			col = { p.Color.R, p.Color.G, p.Color.B },
			m = p.Material.Name,
			sh = p.Shape.Name,
			t = p.Transparency or 0,
			n = p.Name,
		})
	end
end
local function inWorkspace(i)
	local p = i._props.Parent
	while p do
		if p == workspace then
			return true
		end
		p = p._props.Parent
	end
	return false
end
local models = 0
local byName = {}
for _, m in placedModels do local n = rawget(m, "_glb").name byName[n] = (byName[n] or 0) + 1 end
if process.env.DEBUG_MODELS then
	for k, v in byName do
		print(k, v)
	end
end
for _, m in placedModels do
	if inWorkspace(m) then
		local g = rawget(m, "_glb")
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = g.pivot:GetComponents()
		table.insert(parts, { model = g.name, scale = g.scale, c = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 } })
		models += 1
	end
end
fs.writeFile(outPath, serde.encode("json", parts))
print(("%s: %d parts, %d models -> %s"):format(mode, #parts - models, models, outPath))
