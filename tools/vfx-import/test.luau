local fs = require("@lune/fs")
local process = require("@lune/process")
local inf = require("./inflate")
local dir = process.args[1]
for _, n in { "BigBeam", "EvilFloor", "LoveAura", "LoveSkill", "Explosion" } do
	local t = os.clock()
	local s = inf.inflate(inf.unbase64(fs.readFile(dir .. "/" .. n .. ".b64")))
	local want = fs.readFile(dir .. "/" .. n .. ".min.json")
	print(n, #s, s == want, string.format("%.2fs", os.clock() - t))
end
