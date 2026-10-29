local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local patch, oldFile, newFile, guard = process.args[1], process.args[2], process.args[3], process.args[4]
local src = fs.readFile(patch)
local m = { Name = "Sim", Source = fs.readFile(oldFile) }
src = string.gsub(src, "local m = [^\n]+\n", "local m = ...\n", 1)
src = string.gsub(src, "local cl = [^\n]+\n", "local cl = ...\n", 1)
if guard then
	src = string.gsub(src, 'if hashOf%(s%) ~= "[0-9 ]+" then', 'if hashOf(s) ~= "' .. guard .. '" then', 1)
end
local fn = luau.load(src)
local res = fn(m)
print(res, if m.Source == fs.readFile(newFile) then "MATCHES git" else "DIFFERENT")
