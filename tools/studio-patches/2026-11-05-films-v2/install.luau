-- Films v2 into the Studio place (5 Nov). Run in the EDIT datamodel (execute_luau / the command bar), with
-- raw.githubusercontent.com allowed for HTTP. Nothing is changed unless every check passes:
--   1. every script to replace still has the checksum it had when this was written (else someone changed it in
--      Studio since: stop and merge by hand);
--   2. every new source fetched from GitHub (by commit) has the expected length and checksum;
-- then the old copies go to ServerStorage.MowALawnBackups.pre_films_v2_5nov, the sources are set, and every script
-- is checked again. Checksum: #source and hash = (h * 31 + byte) % 2147483647, as in HANDOFF.md.
-- Not touched: client/HatchFx and client/HatchSpace (another session's hatch work, only in Studio).
local HttpService = game:GetService("HttpService")
local SHA = "ce4593604c07952f766c293af7ec0373397c327f"
local ROWS = {
	-- studio path, git path, class, old {len, hash} (nil = new script), new len, new hash
	{ "client/Demon", "src/client/Demon.luau", "ModuleScript", { 16765, 2008863917 }, 20880, 1263055163 },
	{ "client/Ending", "src/client/Ending.luau", "ModuleScript", { 89904, 138518819 }, 91123, 982933106 },
	{ "client/Film", "src/client/Film.luau", "ModuleScript", { 27907, 784949653 }, 28538, 1954711534 },
	{ "client/FilmSheet", "src/client/FilmSheet.luau", "ModuleScript", { 8936, 3978950 }, 9267, 1828810865 },
	{ "client/Intro", "src/client/Intro.luau", "ModuleScript", { 68682, 546277695 }, 69408, 201922613 },
	{ "client/Life", "src/client/Life.luau", "ModuleScript", { 16112, 1014388094 }, 17202, 1533465536 },
	{ "client/PackFx", "src/client/PackFx.luau", "ModuleScript", { 31204, 619662781 }, 31611, 936743537 },
	{ "server/Main", "src/server/Main.server.luau", "Script", { 14240, 124357307 }, 14347, 964737058 },
	{ "shared/Config", "src/shared/Config.luau", "ModuleScript", { 109445, 1257112737 }, 110543, 170756471 },
	{ "client/AnimeFx", "src/client/AnimeFx.luau", "ModuleScript", nil, 24713, 653644677 },
	{ "client/FilmSet", "src/client/FilmSet.luau", "ModuleScript", nil, 26410, 1341512332 },
	{ "client/Finale", "src/client/Finale.luau", "ModuleScript", nil, 74210, 1709053709 },
	{ "client/Opening", "src/client/Opening.luau", "ModuleScript", nil, 87149, 957855197 },
	{ "client/Puppet", "src/client/Puppet.luau", "ModuleScript", nil, 31676, 150829716 },
	{ "client/Shears", "src/client/Shears.luau", "ModuleScript", nil, 9558, 518535867 },
	{ "server/FilmCast", "src/server/FilmCast.luau", "ModuleScript", nil, 1861, 1887841247 },
}
local ROOTS = {
	shared = game:GetService("ReplicatedStorage"):FindFirstChild("MowALawn"),
	server = game:GetService("ServerScriptService"):FindFirstChild("MowALawn"),
	client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("MowALawnClient"),
}

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
local function find(path: string): (Instance?, Instance?, string)
	local root, name = string.match(path, "^(%w+)/(.+)$")
	local parent = ROOTS[root :: string]
	return parent and parent:FindFirstChild(name :: string), parent, name :: string
end

local report = {}
-- 1. the old copies are what we expect
for _, r in ROWS do
	local inst, parent = find(r[1])
	if not parent then
		return "STOP: no root for " .. r[1]
	end
	if r[4] then
		if not inst or not inst:IsA("LuaSourceContainer") then
			return "STOP: " .. r[1] .. " is missing in Studio"
		end
		local src = (inst :: any).Source
		if #src ~= r[4][1] or hash(src) ~= r[4][2] then
			return "STOP: " .. r[1] .. " changed in Studio (" .. #src .. " " .. hash(src) .. "): merge by hand"
		end
	elseif inst then
		return "STOP: " .. r[1] .. " already exists in Studio"
	end
end
-- 2. fetch and check every new source
local new = {}
for _, r in ROWS do
	local ok, body = pcall(HttpService.GetAsync, HttpService, "https://raw.githubusercontent.com/raynine2/Mow-And-Grow/" .. SHA .. "/" .. r[2], true)
	if not ok then
		return "STOP: fetch failed for " .. r[2] .. ": " .. tostring(body)
	end
	if #body ~= r[5] or hash(body) ~= r[6] then
		return "STOP: " .. r[2] .. " came back different (" .. #body .. " " .. hash(body) .. ")"
	end
	new[r[1]] = body
end
-- 3. back up the old copies
local backups = game:GetService("ServerStorage"):FindFirstChild("MowALawnBackups")
if not backups then
	backups = Instance.new("Folder")
	backups.Name = "MowALawnBackups"
	backups.Parent = game:GetService("ServerStorage")
end
local folder = Instance.new("Folder")
folder.Name = "pre_films_v2_5nov"
folder.Parent = backups
for _, r in ROWS do
	local inst = find(r[1])
	if inst then
		local copy = inst:Clone()
		copy.Name = string.gsub(r[1], "/", ".")
		if copy:IsA("Script") then
			copy.Enabled = false
		end
		copy.Parent = folder
	end
end
-- 4. set the sources (new scripts made where Rojo would put them)
for _, r in ROWS do
	local inst, parent, name = find(r[1])
	if not inst then
		inst = Instance.new(r[3])
		inst.Name = name
		inst.Parent = parent
	end
	(inst :: any).Source = new[r[1]]
	table.insert(report, r[1])
end
-- 5. check them all again
for _, r in ROWS do
	local inst = find(r[1])
	local src = inst and (inst :: any).Source or ""
	if #src ~= r[5] or hash(src) ~= r[6] then
		return "CHECK FAILED after install: " .. r[1] .. " (old copies are in " .. folder:GetFullName() .. ")"
	end
end
return "installed " .. #report .. " scripts from " .. SHA .. "; old copies in " .. folder:GetFullName()
