-- Funny moments (5 Nov, owner's TikTok: "simulate a kid trying to make their friends laugh ... add more opportunities
-- for funny moments"; he picked all four): TIMBER squash, bonk friends, the Shredder spit-out, the emote wheel (G).
-- Run in the EDIT datamodel. Every script must be exactly git's 58ed4aa (else stop and merge by hand); new sources
-- fetched by commit and checked; old copies to ServerStorage.MowALawnBackups.pre_funny_5nov.
local HttpService = game:GetService("HttpService")
local SHA = "31bb9fa209a30c9a2f73338c21db4e1384ab558d"
-- { script, file, old {length, hash} (nil = a new script), new length, new hash }
local ROWS = {
	{ "client/CameraView", "src/client/CameraView.luau", { 18927, 1426950059 }, 19930, 788279460 },
	{ "client/Client", "src/client/Client.client.luau", { 5470, 778857254 }, 5705, 511836640 },
	{ "client/Emotes", "src/client/Emotes.luau", nil, 28643, 1228555723 },
	{ "client/Funny", "src/client/Funny.luau", nil, 20819, 181982489 },
	{ "client/SellFx", "src/client/SellFx.luau", { 14066, 1046793726 }, 14158, 1830265076 },
	{ "server/Emotes", "src/server/Emotes.luau", nil, 2038, 852433702 },
	{ "server/Field", "src/server/Field.luau", { 36020, 1161330376 }, 36270, 172747272 },
	{ "server/Funny", "src/server/Funny.luau", nil, 13200, 238812199 },
	{ "server/Main", "src/server/Main.server.luau", { 15281, 1724107456 }, 15393, 767945056 },
	{ "server/Net", "src/server/Net.luau", { 4759, 763377159 }, 5084, 654439252 },
	{ "server/Run", "src/server/Run.luau", { 48912, 845131389 }, 49453, 2125215747 },
	{ "shared/Config", "src/shared/Config.luau", { 120782, 611162395 }, 127653, 912200100 },
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
folder.Name = "pre_funny_5nov"
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
