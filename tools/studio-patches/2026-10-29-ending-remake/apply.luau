local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end

local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Ending
local s = m.Source
if hashOf(s) ~= "76156 548698937" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local buf = game:GetService("ServerStorage"):FindFirstChild("ClaudePatchBuf")
if not buf then
	return "no buffer"
end
for k = 1, 78 do
	local o, n = buf:FindFirstChild("o" .. k), buf:FindFirstChild("n" .. k)
	if not o or not n then
		return "edit " .. k .. " missing"
	end
	local i, j = string.find(s, o.Value, 1, true)
	if not i or string.find(s, o.Value, j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. n.Value .. string.sub(s, j + 1)
end
if hashOf(s) ~= "87697 1189730999" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
buf:Destroy()
return m.Name .. " done: " .. hashOf(s)
