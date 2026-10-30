# mkinstall.py <parent path in Studio> <Name> <source file> <out.luau> [known old checksum ...]
# An installer for a whole ModuleScript: puts git's exact text in Studio if the module isn't there, replaces it if its
# checksum is one of the known older versions, and refuses anything else (someone's own changes).
import sys
parent, name, srcp, out = sys.argv[1:5]
olds = sys.argv[5:]
src = open(srcp).read()
def h(b):
    x = 0
    for c in b:
        x = (x * 31 + c) % 2147483647
    return f"{len(b)} {x}"
eq = '=' * 6
while (']' + eq + ']') in src:
    eq += '='
want = h(src.encode())
lines = [f"-- Installs {name} (git's exact text, {want}) into {parent}. Run in Edit mode.",
         f"local src = [{eq}[\n{src}]{eq}]",
         "local function hashOf(t)", "\tlocal x = 0", "\tfor i = 1, #t do", "\t\tx = (x * 31 + string.byte(t, i)) % 2147483647", "\tend", "\treturn #t .. \" \" .. x", "end",
         f'if hashOf(src) ~= "{want}" then', '\treturn "NOT INSTALLED: the pasted text is " .. hashOf(src)', "end",
         f"local folder = {parent}",
         f'local old = folder:FindFirstChild("{name}")',
         "if old then", "\tlocal now = hashOf(old.Source)",
         f'\tif now == "{want}" then', f'\t\treturn "{name} is already this version: " .. now', "\tend",
         "\tlocal known = { " + ", ".join(f'["{o}"] = true' for o in olds) + " }",
         "\tif not known[now] then", f'\t\treturn "NOT CHANGED: {name} is there but is " .. now .. " (not a version this replaces)"', "\tend",
         "\told.Source = src", f'\treturn "{name} updated: " .. hashOf(old.Source)', "end",
         'local m = Instance.new("ModuleScript")', f'm.Name = "{name}"', "m.Source = src", "m.Parent = folder",
         f'return "{name} installed: " .. hashOf(m.Source)']
open(out, 'w').write("\n".join(lines) + "\n")
print(out, want, len("\n".join(lines)))
