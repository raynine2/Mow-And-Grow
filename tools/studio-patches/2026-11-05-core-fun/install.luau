-- The no-rewards pass (5 Nov, owner's TikTok: "simulate an eight year old playing your roblox game with all coins, XP,
-- badges and rewards removed ... improve the core mechanics"): hold-to-cut from the start, the onboarding quests skip
-- the locked mower quest, sprint, and the grass toys (kicked/bouncy bundles, clumps that sway as you pass, trample
-- trails). Run in the EDIT datamodel. Every script must be exactly git's d87b849 (else stop and merge by hand); new
-- sources fetched by commit and checked; old copies to ServerStorage.MowALawnBackups.pre_core_fun_5nov.
local HttpService = game:GetService("HttpService")
local SHA = "b9cbf8a6ce22f3d85cb2041dba294da8cd00faaf"
-- { script, file, old {length, hash} (nil = a new script), new length, new hash }
local ROWS = {
	{ "client/Client", "src/client/Client.client.luau", { 5381, 491272563 }, 5470, 778857254 },
	{ "client/Coach", "src/client/Coach.luau", { 24501, 1037754977 }, 24688, 1484646629 },
	{ "client/HitFx", "src/client/HitFx.luau", { 45709, 604197980 }, 48518, 1583498235 },
	{ "client/Input", "src/client/Input.luau", { 10879, 38423430 }, 10786, 1740709369 },
	{ "client/LootFx", "src/client/LootFx.luau", { 10084, 729816960 }, 17304, 589990756 },
	{ "client/MowFx", "src/client/MowFx.luau", { 17465, 1331716659 }, 22224, 1294667672 },
	{ "client/Sprint", "src/client/Sprint.luau", nil, 4661, 44155360 },
	{ "client/Wind", "src/client/Wind.luau", { 8346, 264378287 }, 9926, 1307255441 },
	{ "server/Loot", "src/server/Loot.luau", { 6810, 963293220 }, 11569, 1691759831 },
	{ "server/Quests", "src/server/Quests.luau", { 1836, 1306034054 }, 2335, 273154668 },
	{ "shared/Config", "src/shared/Config.luau", { 117440, 560649664 }, 120782, 611162395 },
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
folder.Name = "pre_core_fun_5nov"
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
local dev = game:GetService("ServerStorage"):FindFirstChild("VoxelDev")
if dev then
	dev:Destroy()
end
return "installed " .. #ROWS .. " scripts from " .. SHA .. "; old copies in " .. folder:GetFullName()
