-- Films v2 round 2 into the Studio place (5 Nov, owner: "u cant really tell whats going on", "i didnt like how the boss
-- spawned", "change my model RAYAN to bbrrbrrbrbrb ... the co owner"). Run in the EDIT datamodel, with
-- raw.githubusercontent.com allowed for HTTP. Nothing is changed unless every check passes:
--   1. every script to replace still has the checksum the first install (2026-11-05-films-v2, from 3a78d4f) left it
--      with (else someone changed it in Studio since: stop and merge by hand);
--   2. every new source fetched from GitHub (by commit) has the expected length and checksum;
--   3. Config is not replaced: only its FILMS_V2 owner lines are edited (another session may have changed other parts
--      of it in Studio), and only if those exact lines are there.
-- Then the old copies go to ServerStorage.MowALawnBackups.pre_films_v2_round2_5nov, the sources are set, and every
-- script is checked again. Checksum: #source and hash = (h * 31 + byte) % 2147483647, as in HANDOFF.md.
-- Not touched: client/HatchFx and client/HatchSpace (another session's hatch work, only in Studio).
local HttpService = game:GetService("HttpService")
local SHA = "b639ce9d2e9432c4432ef465c5f29c1d9cdf12bf"
local ROWS = {
	-- studio path, git path, class, old {len, hash}, new len, new hash
	{ "client/Demon", "src/client/Demon.luau", "ModuleScript", { 20880, 1263055163 }, 22310, 1752655356 },
	{ "client/Opening", "src/client/Opening.luau", "ModuleScript", { 87149, 957855197 }, 103804, 630834917 },
	{ "client/Puppet", "src/client/Puppet.luau", "ModuleScript", { 31676, 150829716 }, 34424, 1314218439 },
	{ "client/Finale", "src/client/Finale.luau", "ModuleScript", { 74210, 1709053709 }, 75462, 746493900 },
	{ "server/FilmCast", "src/server/FilmCast.luau", "ModuleScript", { 1861, 1887841247 }, 1866, 2137358020 },
}
local CONFIG_OLD = '\towner = 1994267229, -- RayanPoepHoof: the valley\'s owner in the films (server/FilmCast builds his avatar)\n\townerName = "RAYAN",\n'
local CONFIG_NEW = '\t-- (5 Nov 13:54, owner: "change my model RAYAN to bbrrbrrbrbrb ... the co owner", and his name on the card)\n\towner = 9924995589, -- bbrrbrrbrbrb, the co-owner: the valley\'s owner in the films (server/FilmCast builds his avatar)\n\townerName = "BBRRBRRBRBRB",\n'
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

-- 1. the old copies are what we expect
for _, r in ROWS do
	local inst = find(r[1])
	if not inst or not inst:IsA("LuaSourceContainer") then
		return "STOP: " .. r[1] .. " is missing in Studio"
	end
	local src = (inst :: any).Source
	if #src ~= r[4][1] or hash(src) ~= r[4][2] then
		return "STOP: " .. r[1] .. " changed in Studio (" .. #src .. " " .. hash(src) .. "): merge by hand"
	end
end
local config = find("shared/Config")
if not config then
	return "STOP: shared/Config is missing in Studio"
end
local cfgSrc = (config :: any).Source
local at = string.find(cfgSrc, CONFIG_OLD, 1, true)
if not at or string.find(cfgSrc, CONFIG_OLD, at + 1, true) then
	return "STOP: Config's FILMS_V2 owner lines aren't there exactly once (changed in Studio?): edit by hand"
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
local cfgNew = string.sub(cfgSrc, 1, at - 1) .. CONFIG_NEW .. string.sub(cfgSrc, at + #CONFIG_OLD)
-- 3. back up the old copies
local backups = game:GetService("ServerStorage"):FindFirstChild("MowALawnBackups")
if not backups then
	backups = Instance.new("Folder")
	backups.Name = "MowALawnBackups"
	backups.Parent = game:GetService("ServerStorage")
end
local folder = Instance.new("Folder")
folder.Name = "pre_films_v2_round2_5nov"
folder.Parent = backups
for _, path in { "client/Demon", "client/Opening", "client/Puppet", "client/Finale", "server/FilmCast", "shared/Config" } do
	local inst = find(path)
	if inst then
		local copy = inst:Clone()
		copy.Name = string.gsub(path, "/", ".")
		copy.Parent = folder
	end
end
-- 4. set the sources
for _, r in ROWS do
	local inst = find(r[1]);
	(inst :: any).Source = new[r[1]]
end
(config :: any).Source = cfgNew
-- 5. check them all again
for _, r in ROWS do
	local inst = find(r[1])
	local src = inst and (inst :: any).Source or ""
	if #src ~= r[5] or hash(src) ~= r[6] then
		return "CHECK FAILED after install: " .. r[1] .. " (old copies are in " .. folder:GetFullName() .. ")"
	end
end
if (config :: any).Source ~= cfgNew then
	return "CHECK FAILED after install: shared/Config (old copy is in " .. folder:GetFullName() .. ")"
end
return "installed 5 scripts from " .. SHA .. " and Config's owner lines (Config now " .. #cfgNew .. " " .. hash(cfgNew) .. "); old copies in " .. folder:GetFullName()
