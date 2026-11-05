-- Balance 3 + Rebirth Stars + daily/weekly quests (5 Nov, owner: "Wat mist nog in de game ... Zijn alle dingen wel
-- gebalanceerd ... Voelt progressie saai?" and his answers: early grass 2-3 hits, pet power capped, boss guns count
-- power with a smaller Robux gap, Rebirth / prestige, daily + weekly quests). Run in the EDIT datamodel. Every script
-- must be exactly what git had at ba77d30 (else stop and merge by hand); new sources fetched by commit and checked; the
-- old copies go to ServerStorage.MowALawnBackups.pre_balance3_5nov. Nothing else is touched.
-- client/PetsWindow is NOT in here: Studio's copy is ahead of git (the hatch v3 work, 38484 bytes); its pet power cap
-- (three small edits) goes in with install-pets.luau, on Studio's own copy.
local HttpService = game:GetService("HttpService")
local SHA = "d70af844c2f321f5f1fc5e7a6feec7a4cfbc6862"
-- { script, file, old {length, hash} (nil = a new script), new length, new hash }
local ROWS = {
	{ "client/Client", "src/client/Client.client.luau", { 5259, 1025236460 }, 5381, 491272563 },
	{ "client/DevPanel", "src/client/DevPanel.luau", { 5896, 638875714 }, 6139, 300731271 },
	{ "client/Hud", "src/client/Hud.luau", { 42278, 2099583754 }, 43100, 1612444683 },
	{ "client/Moments", "src/client/Moments.luau", { 15470, 2001815984 }, 19312, 1942574155 },
	{ "client/QuestsWindow", "src/client/QuestsWindow.luau", nil, 10806, 1885710407 },
	{ "client/StatsWindow", "src/client/StatsWindow.luau", { 7825, 654403405 }, 8264, 1109629841 },
	{ "server/BestTimes", "src/server/BestTimes.luau", { 5014, 428588773 }, 5580, 675857117 },
	{ "server/Guns", "src/server/Guns.luau", { 9380, 415592811 }, 9737, 510577204 },
	{ "server/Main", "src/server/Main.server.luau", { 14347, 964737058 }, 15281, 1724107456 },
	{ "server/Net", "src/server/Net.luau", { 4526, 1585155591 }, 4759, 763377159 },
	{ "server/Pets", "src/server/Pets.luau", { 7177, 906716105 }, 7331, 643741801 },
	{ "server/PlayerData", "src/server/PlayerData.luau", { 12371, 1282095747 }, 12916, 187161439 },
	{ "server/QuestBoard", "src/server/QuestBoard.luau", nil, 8286, 2034730071 },
	{ "server/Rebirth", "src/server/Rebirth.luau", nil, 3587, 1866506570 },
	{ "server/Run", "src/server/Run.luau", { 48078, 56689513 }, 48912, 845131389 },
	{ "server/RunEvents", "src/server/RunEvents.luau", { 7199, 1622434596 }, 7371, 466111953 },
	{ "server/Stats", "src/server/Stats.luau", { 3956, 1196722295 }, 4566, 1860508976 },
	{ "shared/Config", "src/shared/Config.luau", { 110672, 1372708943 }, 117440, 560649664 },
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
folder.Name = "pre_balance3_5nov"
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
