-- Puts the tidied server/CampDress in (after part01..05): only over the first version (29 Oct 20:55, Studio
-- 46357 607222462), which is kept in ServerStorage.MowALawnBackups.pre_camps_tidy_29oct.
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	return "no buffer: run the parts first"
end
local bits = {}
for i = 1, 5 do
	local v = buf:FindFirstChild("CampDress." .. i)
	if not v then
		return "NOT CHANGED: chunk " .. i .. " missing"
	end
	bits[i] = v.Value
end
local text = table.concat(bits)
if hashOf(text) ~= "42967 834704693" then
	return "NOT CHANGED: joined text is " .. hashOf(text)
end
local m = game.ServerScriptService.MowALawn:FindFirstChild("CampDress")
if not m then
	return "NOT CHANGED: no CampDress"
end
if hashOf(m.Source) == "42967 834704693" then
	buf:Destroy()
	return "CampDress already the tidied one"
end
if hashOf(m.Source) ~= "46357 607222462" then
	return "NOT CHANGED: CampDress is " .. hashOf(m.Source)
end
local backups = ss:FindFirstChild("MowALawnBackups") or Instance.new("Folder")
backups.Name = "MowALawnBackups"
backups.Parent = ss
local slot = backups:FindFirstChild("pre_camps_tidy_29oct") or Instance.new("Folder")
slot.Name = "pre_camps_tidy_29oct"
slot.Parent = backups
if not slot:FindFirstChild("CampDress") then
	m:Clone().Parent = slot
end
m.Source = text
buf:Destroy()
return "CampDress replaced: " .. hashOf(m.Source)
