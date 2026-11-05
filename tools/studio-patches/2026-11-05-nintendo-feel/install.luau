-- The Nintendo pass (5 Nov, owner's TikTok: "research how Nintendo uses animation timing, sound effects, and visual
-- feedback to make simple actions satisfying. Then improve the three most common actions"): chopping climbs the major
-- scale and the cut resolves it, the bundle that fills your bag gets a fanfare, selling rings up a run that doesn't
-- wrap. Run in the EDIT datamodel. The scripts must be exactly what git had before (else stop and merge by hand), the
-- new sources are fetched by commit and checked, the old copies go to
-- ServerStorage.MowALawnBackups.pre_nintendo_feel_5nov. Nothing else is touched.
local HttpService = game:GetService("HttpService")
local SHA = "a9ee1a7c95cee2aa024b747c0e30a345bbbb69dd"
-- { script, file, old {length, hash} (nil = a new script), new length, new hash }
local ROWS = {
	{ "client/HitFx", "src/client/HitFx.luau", { 44248, 1766038824 }, 45530, 119984077 },
	{ "client/Fx", "src/client/Fx.luau", { 39554, 1105390399 }, 39812, 1788584410 },
	{ "client/Hud", "src/client/Hud.luau", { 41427, 580262666 }, 42278, 2099583754 },
	{ "client/SellFx", "src/client/SellFx.luau", { 12447, 463297883 }, 13472, 1071408837 },
}
local roots = {
	server = game:GetService("ServerScriptService"):FindFirstChild("MowALawn"),
	client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("MowALawnClient"),
}
if not roots.server or not roots.client then
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
folder.Name = "pre_nintendo_feel_5nov"
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
