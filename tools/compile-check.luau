-- Compiles every .luau file given on the command line with Lune and fails if any doesn't compile.
-- Catches syntax errors and Luau's 200-local limit (TideboundClient sits close to it).
--   lune run tools/compile-check.luau $(find TideboundEggfall/src -name "*.luau")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failed = 0
for _, path in ipairs(process.args) do
	local ok, err = pcall(luau.compile, fs.readFile(path))
	if not ok then
		failed += 1
		print("FAILED " .. path .. "\n   " .. tostring(err))
	end
end
print(("%d file(s) checked, %d failed"):format(#process.args, failed))
process.exit(failed > 0 and 1 or 0)
