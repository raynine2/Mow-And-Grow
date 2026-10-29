-- Lune test: load server/CampProps with Lune's Roblox types and build every model.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local src = fs.readFile(process.args[1])
local ms = roblox.Instance.new("MaterialService")
local stubGame = {}
function stubGame:GetService(name)
	return ms
end
local env = setmetatable({
	game = stubGame,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	typeof = roblox.typeof or typeof,
}, { __index = _G })
local fn = luau.load(src, { debugName = "CampProps", environment = env })
local CampProps = fn()
local root = roblox.Instance.new("Folder")
local names = {}
for name in string.gmatch(src, "\n\t([%w_]+) = %[=+%[") do
	table.insert(names, name)
end
local total, bad = 0, 0
for _, name in names do
	local ok, m = pcall(CampProps.place, name, root, roblox.CFrame.new(0, 0, 0), { roles = { wall = { "Plaster", roblox.Color3.fromRGB(200, 100, 100) } } })
	if not ok then
		print("FAILED " .. name .. ": " .. tostring(m))
		bad += 1
	else
		local n = 0
		for _, p in m:GetChildren() do
			n += 1
			local s = p.Size
			if s.X ~= s.X or s.X <= 0 or s.Y <= 0 or s.Z <= 0 then
				print("bad size", name, p.Name, s)
				bad += 1
			end
			local c = p.CFrame
			if c.Position.X ~= c.Position.X then
				print("bad cframe", name)
				bad += 1
			end
		end
		total += n
		local groups = {}
		for k, v in m:GetAttributes() do
			if string.sub(k, 1, 6) == "Pivot_" then
				table.insert(groups, string.sub(k, 7))
			end
		end
		print(string.format("%-18s %3d parts  groups: %s", name, n, table.concat(groups, ",")))
	end
end
print(("%d models, %d parts, %d problems"):format(#names, total, bad))
