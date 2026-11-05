local HttpService = game:GetService("HttpService")
local SHA = "c3d55356379504cc7352acda6033b2dec5200ffd"
-- { script, file, old {length, hash} (nil = a new script), new length, new hash }
local ROWS = {
	{ "shared/Config", "src/shared/Config.luau", { 128018, 866864018 }, 129620, 253017696 },
	{ "server/Quests", "src/server/Quests.luau", { 2335, 273154668 }, 3326, 1459032673 },
	{ "server/Run", "src/server/Run.luau", { 49453, 2125215747 }, 50418, 1600957999 },
	{ "server/Stats", "src/server/Stats.luau", { 4566, 1860508976 }, 4754, 114447007 },
	{ "server/Boss", "src/server/Boss.luau", { 62956, 645188433 }, 63180, 309252031 },
	{ "client/Guide", "src/client/Guide.luau", { 6996, 102375801 }, 7211, 849112650 },
	{ "client/FirstLawn", "src/client/FirstLawn.luau", { 6717, 1362773115 }, 6787, 457917269 },
}
local roots = {
	server = game:GetService("ServerScriptService"):FindFirstChild("MowALawn"),
	shared = game:GetService("ReplicatedStorage"):FindFirstChild("MowALawn"),
	client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("MowALawnClient"),
}
if not roots.server or not roots.client or not roots.shared then
	return "STOP: no MowALawn / MowALawnClient"
end
local function hash(s: string): number
	local h = 0
	local i = 1
	while i <= #s do
		local j = math.min(i + 3999, #s)
		for _, b in { string.byte(s, i, j) } do
			h = (h * 31 + b) % 2147483647
		end
		i = j + 1
	end
	return h
end
local function split(path: string): (Instance, string)
	local side, name = string.match(path, "^(%w+)/(%w+)$")
	return roots[side :: string], name :: string
end
local function find(path: string): Instance?
	local root, name = split(path)
	return root:FindFirstChild(name)
end
for _, r in ROWS do
	local inst = find(r[1])
	if r[3] == nil then
		if inst then
			return "STOP: " .. r[1] .. " is already there: merge by hand"
		end
	else
		if not inst or not inst:IsA("LuaSourceContainer") then
			return "STOP: " .. r[1] .. " is missing"
		end
		local src = (inst :: any).Source
		if #src ~= r[3][1] or hash(src) ~= r[3][2] then
			return "STOP: " .. r[1] .. " changed in Studio (" .. #src .. " " .. hash(src) .. "): merge by hand"
		end
	end
end
local new = {}
for _, r in ROWS do
	local ok, body = pcall(HttpService.GetAsync, HttpService, "https://raw.githubusercontent.com/raynine2/Mow-And-Grow/" .. SHA .. "/" .. r[2], true)
	if not ok then
		return "STOP: fetch failed for " .. r[2] .. ": " .. tostring(body)
	end
	if #body ~= r[4] or hash(body) ~= r[5] then
		return "STOP: " .. r[2] .. " came back different (" .. #body .. " " .. hash(body) .. ")"
	end
	new[r[1]] = body
end
local backups = game:GetService("ServerStorage"):FindFirstChild("MowALawnBackups")
if not backups then
	backups = Instance.new("Folder")
	backups.Name = "MowALawnBackups"
	backups.Parent = game:GetService("ServerStorage")
end
local folder = Instance.new("Folder")
folder.Name = "pre_gameloop_6nov"
folder.Parent = backups
for _, r in ROWS do
	local inst = find(r[1])
	if inst then
		local copy = inst:Clone()
		copy.Name = string.gsub(r[1], "/", ".")
		copy.Parent = folder
	end
end
for _, r in ROWS do
	local inst = find(r[1])
	if not inst then
		local root, name = split(r[1])
		local m = Instance.new("ModuleScript")
		m.Name = name
		m.Source = new[r[1]]
		m.Parent = root
	else
		(inst :: any).Source = new[r[1]]
	end
end
for _, r in ROWS do
	local inst = find(r[1])
	local src = if inst then (inst :: any).Source else ""
	if #src ~= r[4] or hash(src) ~= r[5] then
		return "CHECK FAILED after install: " .. r[1] .. " (old copies in " .. folder:GetFullName() .. ")"
	end
end
return "installed " .. #ROWS .. " scripts from " .. SHA .. "; old copies in " .. folder:GetFullName()
