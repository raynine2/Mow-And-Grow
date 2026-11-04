-- Lune dry run of server/ZoneConcepts: builds each concept on a stubbed world, counts its parts and dumps them
-- (relative to the concept's origin) for tools/concepts/render.py.
-- Run from the repo: lune run tools/concepts/dry_run.luau . <dump dir> [concept]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local process = require("@lune/process")

local ROOT = process.args[1]
local OUT = process.args[2] or "."
local ONLY = process.args[3]
local Instance = roblox.Instance

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

local services = { MaterialService = Instance.new("MaterialService") }
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
local UDim2 = setmetatable({ fromScale = function(x, y)
	return roblox.UDim2.new(x, 0, y, 0)
end }, { __index = roblox.UDim2 })
env = function(path)
	local dir = string.match(path, "^(.*)/[^/]+$")
	local script = { Parent = setmetatable({}, { __index = function(_, k)
		return { __module = dir .. "/" .. k .. ".luau" }
	end }) }
	return setmetatable({
		game = { GetService = function(_, n)
			return services[n] or error("no service " .. n)
		end },
		workspace = Instance.new("Model"),
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
		UDim2 = UDim2,
		UDim = roblox.UDim,
		Enum = roblox.Enum,
		Random = Random,
		task = task,
		warn = function(...)
			print("WARN", ...)
		end,
	}, { __index = _G })
end

local ZC = load("src/server/ZoneConcepts.luau")
local ok = true
for _, id in { "meadow", "frost", "ember" } do
	if (ONLY == nil or ONLY == id) and ZC[id] then
		local root = Instance.new("Folder")
		local origin = ZC.ORIGIN[id]
		local t0 = os.clock()
		local good, err = pcall(ZC[id], root, origin)
		local rows, n = {}, 0
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				if d.Transparency < 0.98 then
					local shape = if d.ClassName == "WedgePart" then "W" elseif d.Shape == roblox.Enum.PartType.Cylinder then "C" elseif d.Shape == roblox.Enum.PartType.Ball then "S" else "B"
					local c = { (d.CFrame - origin):GetComponents() }
					local o = {}
					for i, v in c do
						o[i] = string.format("%.3f", v)
					end
					local col = d.Color
					table.insert(rows, string.format('{"s":"%s","z":[%.3f,%.3f,%.3f],"cf":[%s],"c":[%.3f,%.3f,%.3f],"m":"%s","t":%.2f}', shape, d.Size.X, d.Size.Y, d.Size.Z, table.concat(o, ","), col.R, col.G, col.B, d.Material.Name, d.Transparency))
				end
			end
		end
		print(("%-8s ok=%s parts=%d (%.2fs) %s"):format(id, tostring(good), n, os.clock() - t0, if good then "" else tostring(err)))
		ok = ok and good
		fs.writeFile(string.format("%s/concept_%s.json", OUT, id), "[" .. table.concat(rows, ",\n") .. "]")
	end
end
process.exit(if ok then 0 else 1)
