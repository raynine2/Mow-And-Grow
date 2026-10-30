# mkanchor.py <target> <marker> <out.luau> <edits.json>
# An anchored Studio patch for a script whose Studio copy differs from git's: each edit is an exact old -> new
# replacement whose old text must occur exactly once in Studio's copy. Refuses if `marker` is already in the script.
import sys, json
target, marker, out, ej = sys.argv[1:5]
edits = json.load(open(ej))
def lb(s):
    eq = '=' * 6
    while (']' + eq + ']') in s:
        eq += '='
    return '[' + eq + '[' + ('\n' if s.startswith('\n') else '') + s + ']' + eq + ']'
L = ['local m = ' + target, 'local s = m.Source',
     'if string.find(s, %s, 1, true) then' % lb(marker), '\treturn m.Name .. " already has this patch"', 'end',
     'local function hashOf(t)', '\tlocal x = 0', '\tfor i = 1, #t do', '\t\tx = (x * 31 + string.byte(t, i)) % 2147483647', '\tend', '\treturn #t .. " " .. x', 'end',
     'local edits = {']
for o, n in edits:
    L.append('\t{ ' + lb(o) + ', ' + lb(n) + ' },')
L.append('}')
L.append('''for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "NOT CHANGED: edit " .. k .. " not found once in " .. m.Name
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)''')
open(out, 'w').write('\n'.join(L) + '\n')
print(out, len(edits), 'edits')
