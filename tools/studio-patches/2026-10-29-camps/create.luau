local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local buf = game:GetService("ServerStorage"):FindFirstChild("ClaudePatchBuf")
if not buf then
	return "no buffer: run the parts first"
end
local out = {}
local ok = true
local made = {}
for _, s in {
	{ "CampProps", game.ServerScriptService.MowALawn, "ModuleScript", 4, "28534 58245688" },
	{ "CampDress", game.ServerScriptService.MowALawn, "ModuleScript", 6, "46357 607222462" },
	{ "CampLife", game.StarterPlayer.StarterPlayerScripts.MowALawnClient, "ModuleScript", 3, "20298 1059054880" },
} do
	local name, parent, cls, n, want = s[1], s[2], s[3], s[4], s[5]
	local bits = {}
	for i = 1, n do
		local v = buf:FindFirstChild(name .. "." .. i)
		if not v then
			table.insert(out, name .. ": chunk " .. i .. " missing")
			ok = false
			break
		end
		bits[i] = v.Value
	end
	if #bits == n then
		local text = table.concat(bits)
		if hashOf(text) ~= want then
			table.insert(out, name .. ": joined text is " .. hashOf(text) .. ", wanted " .. want)
			ok = false
		else
			made[name] = { parent, cls, text }
		end
	end
end
if not ok then
	return "NOTHING CREATED\n" .. table.concat(out, "\n")
end
for name, m in made do
	local parent, cls, text = m[1], m[2], m[3]
	local old = parent:FindFirstChild(name)
	if old then
		if old:IsA("LuaSourceContainer") and hashOf((old :: any).Source) == hashOf(text) then
			table.insert(out, name .. ": already there")
		else
			table.insert(out, name .. ": NOT CHANGED (a different " .. name .. " is already there)")
		end
	else
		local sc = Instance.new(cls)
		sc.Name = name
		;(sc :: any).Source = text
		sc.Parent = parent
		table.insert(out, name .. " created: " .. hashOf(text))
	end
end
buf:Destroy()
return table.concat(out, "\n")
