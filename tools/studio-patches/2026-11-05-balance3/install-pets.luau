-- Balance 3, part 2: the pet power cap in the pets window (its "Team boost" counts pets' power up to
-- Config.PET_POWER_CAP), applied to STUDIO'S OWN client/PetsWindow (38484 bytes, hash 1406418858: the hatch v3 work,
-- ahead of git). Three exact edits, the same ones git's copy got in f9c228c. Old copy in
-- ServerStorage.MowALawnBackups.pre_balance3_5nov.client.PetsWindow. Result: 38712 bytes, hash 1572997645.
local function hash(s)
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
local pw = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.PetsWindow
local src = pw.Source
if #src ~= 38484 or hash(src) ~= 1406418858 then
	return "STOP: changed"
end
local edits = {
	{ "\tlocal total = 0\n\tfor i, e in on do", "\tlocal total = 0\n\tlocal petPower = 0 -- (5 Nov) counted up to Config.PET_POWER_CAP, like server/Stats\n\tfor i, e in on do" },
	{
		"\t\t\tfor _, k in Config.PET_STATS do\n\t\t\t\ttotal += (p :: any)[k] or 0\n\t\t\tend\n\t\t\tlocal slot = slots[i]",
		"\t\t\tfor _, k in Config.PET_STATS do\n\t\t\t\tif k == \"power\" then\n\t\t\t\t\tpetPower += (p :: any)[k] or 0\n\t\t\t\telse\n\t\t\t\t\ttotal += (p :: any)[k] or 0\n\t\t\t\tend\n\t\t\tend\n\t\t\tlocal slot = slots[i]",
	},
	{ "\tboostText.Text = (\"+%d%%\"):format(math.floor(total * 100 + 0.5))", "\ttotal += math.min(petPower, Config.PET_POWER_CAP or math.huge)\n\tboostText.Text = (\"+%d%%\"):format(math.floor(total * 100 + 0.5))" },
}
local out = src
for i, e in edits do
	local a, b = string.find(out, e[1], 1, true)
	if not a then
		return "STOP: edit " .. i .. " not found"
	end
	out = string.sub(out, 1, a - 1) .. e[2] .. string.sub(out, b + 1)
end
local c = pw:Clone()
c.Name = "client.PetsWindow"
c.Parent = game.ServerStorage.MowALawnBackups.pre_balance3_5nov
pw.Source = out
return "ok " .. #out .. " " .. hash(out)
