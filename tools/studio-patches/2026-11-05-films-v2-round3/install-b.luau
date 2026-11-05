-- Films v2 round 3, part b (5 Nov ~18:30): the films' words made simple (owner: "The text needs to be simple ... look up
-- a reference from anime ... what u have rn is very bad"): plain white words in one clean sans with a thin black
-- outline, like anime TV subtitles; names big and heavy low on the left with a small line under. Run in the EDIT
-- datamodel after install.luau; same checks: the scripts must be exactly what install.luau left (else stop), the new
-- sources are fetched by commit and checked, the old copies go to ServerStorage.MowALawnBackups.pre_films_v2_round3b_5nov.
local HttpService = game:GetService("HttpService")
local SHA = "d27174aeb9721f5de6b9ea7d4d6867a8d0cb7714"
local ROWS = {
	{ "client/AnimeFx", "src/client/AnimeFx.luau", { 38622, 1195235525 }, 34954, 1375350673 },
	{ "client/Opening", "src/client/Opening.luau", { 104834, 1370327202 }, 104717, 587122011 },
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
	if not inst or not inst:IsA("LuaSourceContainer") then
		return "STOP: " .. r[1] .. " is missing"
	end
	local src = (inst :: any).Source
	if #src ~= r[3][1] or hash(src) ~= r[3][2] then
		return "STOP: " .. r[1] .. " changed in Studio (" .. #src .. " " .. hash(src) .. "): merge by hand"
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
folder.Name = "pre_films_v2_round3b_5nov"
folder.Parent = backups
for _, r in ROWS do
	local copy = (find(r[1]) :: Instance):Clone()
	copy.Name = string.gsub(r[1], "/", ".")
	copy.Parent = folder
end
for _, r in ROWS do
	(find(r[1]) :: any).Source = new[r[1]]
end
for _, r in ROWS do
	local src = (find(r[1]) :: any).Source
	if #src ~= r[4] or hash(src) ~= r[5] then
		return "CHECK FAILED after install: " .. r[1] .. " (old copies in " .. folder:GetFullName() .. ")"
	end
end
local dev = game:GetService("ReplicatedStorage"):FindFirstChild("FilmDev")
if dev then
	dev:Destroy()
end
return "installed 2 scripts from " .. SHA .. "; old copies in " .. folder:GetFullName()
