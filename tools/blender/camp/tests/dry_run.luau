-- Lune dry run of server/CampDress (with server/Outposts' context) on a stubbed world, then client/CampLife's
-- animations for 600 frames: catches runtime errors, counts what each camp gets, and dumps each camp's parts
-- (dump dir) for tests/render_camp.py. Run from the repo: lune run tools/blender/camp/tests/dry_run.luau . <dump dir>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local process = require("@lune/process")

local ROOT = process.args[1]
local Instance = roblox.Instance
roblox.implementMethod("Model", "GetPivot", function(self)
	return self.WorldPivot
end)

local tags = {}
local tagged = {}
local CollectionService = {}
function CollectionService:AddTag(inst, name)
	tags[name] = (tags[name] or 0) + 1
	tagged[name] = tagged[name] or {}
	if not table.find(tagged[name], inst) then
		table.insert(tagged[name], inst)
	end
end
function CollectionService:GetTagged(name)
	return tagged[name] or {}
end
local function signal()
	return { Connect = function(_, fn)
		return { Disconnect = function() end }
	end }
end
function CollectionService:GetInstanceAddedSignal()
	return signal()
end
function CollectionService:GetInstanceRemovedSignal()
	return signal()
end
local MaterialService = Instance.new("MaterialService")
local services = { MaterialService = MaterialService, CollectionService = CollectionService }

-- a simple Random
local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (seed or 1) % 2147483647 + 1 }, Random)
end
function Random:next01()
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:next01()
end
function Random:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:next01())
end

local groundY = function(x, z)
	return math.floor((math.sin(x * 0.05) * 3 + math.cos(z * 0.04) * 2)) * 2
end
local workspace = {}
local moved = 0
local badMove = 0
function workspace:BulkMoveTo(parts, cfs, mode)
	for i, p in parts do
		local c = cfs[i]
		local q = c.Position
		if q.X ~= q.X or q.Y ~= q.Y or q.Z ~= q.Z or math.abs(q.Y) > 1e5 then
			badMove += 1
		end
		p.CFrame = c
		moved += 1
	end
end
function workspace:Raycast(origin, dir, params)
	return { Position = roblox.Vector3.new(origin.X, groundY(origin.X, origin.Z), origin.Z) }
end
local RaycastParams = {}
function RaycastParams.new()
	return {}
end

local modules = {}
local env
local function load(path)
	if modules[path] ~= nil then
		return modules[path]
	end
	local src = fs.readFile(ROOT .. "/" .. path)
	local fn = luau.load(src, { debugName = path, environment = env(path) })
	modules[path] = fn()
	return modules[path]
end
local Shared = { MowALawn = setmetatable({}, { __index = function(_, k)
	return { __module = "src/shared/" .. k .. ".luau" }
end }) }
services.ReplicatedStorage = Shared

env = function(path)
	local dir = string.match(path, "^(.*)/[^/]+$")
	local script = { Parent = setmetatable({}, { __index = function(_, k)
		return { __module = dir .. "/" .. k .. ".luau" }
	end }) }
	return setmetatable({
		game = { GetService = function(_, n)
			return services[n] or error("no service " .. n)
		end },
		workspace = workspace,
		script = script,
		require = function(ref)
			return load(ref.__module)
		end,
		Instance = Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		TweenInfo = { new = function()
			return {}
		end },
		Enum = roblox.Enum,
		RaycastParams = RaycastParams,
		Random = Random,
		task = task,
		warn = function(...)
			print("WARN", ...)
		end,
	}, { __index = _G })
end

local CampDress = load("src/server/CampDress.luau")
local Zones = load("src/shared/Zones.luau")
local world = Instance.new("Model")
world.Name = "World"
for _, n in { "Ground", "Visuals", "Ways", "Gates" } do
	local f = Instance.new("Folder")
	f.Name = n
	f.Parent = world
end
local okAll = true
for z = 2, #Zones.list do
	local f = Instance.new("Model")
	f.Name = "Outpost" .. z
	f.Parent = world
	local base = roblox.Vector3.new(z * 300, 10, 0)
	local fwd = roblox.Vector3.new(0, 0, 1)
	local gate = Instance.new("Part")
	gate.Position = base + roblox.Vector3.new(60, 0, 40)
	local ok, err = pcall(CampDress.dress, {
		w = world, f = f, z = z, base = base, top = 10, fwd = fwd, right = fwd:Cross(roblox.Vector3.new(0, 1, 0)), R = 24,
		rng = Random.new(500 + z), info = { gates = { { b = z + 1, model = gate } } }, glow = roblox.Color3.new(1, 0.8, 0.5),
		lanternPost = function() end,
	})
	local n = 0
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	print(("area %d %-20s ok=%s parts=%d %s"):format(z, Zones.list[z].id, tostring(ok), n, if ok then "" else tostring(err)))
	-- dump the camp's parts (relative to its plaza centre) for a Blender preview
	local rows = {}
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local shape = if d.ClassName == "WedgePart" then "W" elseif d.Shape == roblox.Enum.PartType.Cylinder then "C" elseif d.Shape == roblox.Enum.PartType.Ball then "S" else "B"
			local c = { (d.CFrame - base):GetComponents() }
			local col = d.Color
			table.insert(rows, string.format('{"s":"%s","z":[%.3f,%.3f,%.3f],"cf":[%s],"c":[%.3f,%.3f,%.3f],"m":"%s","t":%.2f}', shape, d.Size.X, d.Size.Y, d.Size.Z, table.concat((function()
				local o = {}
				for i, v in c do
					o[i] = string.format("%.4f", v)
				end
				return o
			end)(), ","), col.R, col.G, col.B, d.Material.Name, d.Transparency))
		end
	end
	fs.writeFile(string.format("%s/camp_%d.json", process.args[2] or ".", z), "[" .. table.concat(rows, ",\n") .. "]")
	okAll = okAll and ok
end
local tl = {}
for k, v in tags do
	table.insert(tl, k .. "=" .. v)
end
print("tags: " .. table.concat(tl, " "))
-- CampLife: run its animations for 20 seconds of frames with the player standing by a villager of camp 2
local heartbeat
services.RunService = { Heartbeat = { Connect = function(_, fn)
	heartbeat = fn
	return {}
end } }
services.TweenService = { Create = function()
	return { Play = function() end }
end }
local char = Instance.new("Model")
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Parent = char
local v1 = tagged.CampVillager[1]
hrp.CFrame = v1.WorldPivot * roblox.CFrame.new(0, 2, -6)
hrp.Position = hrp.CFrame.Position
services.Players = { LocalPlayer = { Character = char } }
services.ReplicatedStorage = { WaitForChild = function(self, n)
	return { WaitForChild = function(_, m)
		return { __module = "STUB_CONFIG" }
	end }
end }
modules["STUB_CONFIG"] = { CAMP_LINES = { any = { "hello there" } } }
workspace.CurrentCamera = { CFrame = hrp.CFrame }
load("src/client/CampLife.luau")
task.wait(1.2) -- the rigs get built and the near list filled
local frames = 0
for i = 1, 600 do
	heartbeat(1 / 30)
	frames += 1
	if i % 30 == 0 then
		task.wait(0.05)
	end
end
print(("CampLife: %d frames, %d part moves, %d bad"):format(frames, moved, badMove))
local talk = 0
for _, d in v1:GetDescendants() do
	if d.Name == "Talk" then
		talk += 1
	end
end
print("speech bubbles on the first villager: " .. talk)
process.exit(if okAll and badMove == 0 and moved > 0 then 0 else 1)
