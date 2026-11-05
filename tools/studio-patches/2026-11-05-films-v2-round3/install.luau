-- Films v2 round 3 (5 Nov): the owner's notes on round 2 ("the text pop up ... very sloppy please take inspiration
-- from jjk", "the sciccors i dont like ... make some better model" + "voxel voor de schaar", "i dont feel like ur using
-- good fx on some parts like the slash"): the new type (serif names and lines, small spaced capitals, a stamped seal),
-- Rayan's shears in voxels (client/ShearsShape, new), and the cuts and hits remade and checked in Studio frame by frame
-- (they were BillboardGuis with AlwaysOnTop, which Studio doesn't draw at all: now drawn over the picture).
-- Run in the EDIT datamodel. Same checks as before: the scripts must be exactly what round 2 left (else stop and merge
-- by hand), the new sources are fetched by commit and checked, the old copies go to
-- ServerStorage.MowALawnBackups.pre_films_v2_round3_5nov. Nothing else is touched (HatchFx, HatchSpace, the maps).
local HttpService = game:GetService("HttpService")
local SHA = "16e9976c937530e01c46aad8df84d82c9b061fd3"
-- { script, file, old {length, hash} (nil = a new script), new length, new hash }
local ROWS = {
	{ "client/Opening", "src/client/Opening.luau", { 104254, 1690006837 }, 104834, 1370327202 },
	{ "client/Finale", "src/client/Finale.luau", { 75912, 813696797 }, 76659, 1665483150 },
	{ "client/AnimeFx", "src/client/AnimeFx.luau", { 24713, 653644677 }, 38622, 1195235525 },
	{ "client/Shears", "src/client/Shears.luau", { 9558, 518535867 }, 8678, 1395645995 },
	{ "client/ShearsShape", "src/client/ShearsShape.luau", nil, 3266, 26665112 },
}
local client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("MowALawnClient")
if not client then
	return "STOP: no MowALawnClient"
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
local function find(path: string): Instance?
	return client:FindFirstChild((string.gsub(path, "^client/", "")))
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
folder.Name = "pre_films_v2_round3_5nov"
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
		local m = Instance.new("ModuleScript")
		m.Name = (string.gsub(r[1], "^client/", ""))
		m.Source = new[r[1]]
		m.Parent = client
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
