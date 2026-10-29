# A guarded Studio patch sent in parts: each part stores some of the edits (exact-text old/new pairs) in
# ServerStorage.ClaudePatchBuf after checking each text's checksum (so a garbled one is named and sent again);
# the last call applies them all to the script, checking its checksum before and after.
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from mkpatch import h, lb, edits_between

HASH = '''local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
'''

def hs(s):
    b = s.encode()
    return '%d %d' % (len(b), h(b))

def make(target, old, new, outdir, limit=14000):
    E = edits_between(old, new)
    os.makedirs(outdir, exist_ok=True)
    parts, cur, size = [], [], 0
    for k, (o, n) in enumerate(E, 1):
        sz = len(o) + len(n) + 200
        if cur and size + sz > limit:
            parts.append(cur)
            cur, size = [], 0
        cur.append((k, o, n))
        size += sz
    if cur:
        parts.append(cur)
    for pi, part in enumerate(parts, 1):
        L = [HASH, 'local ss = game:GetService("ServerStorage")',
             'local buf = ss:FindFirstChild("ClaudePatchBuf")',
             'if not buf then', '\tbuf = Instance.new("Folder")', '\tbuf.Name = "ClaudePatchBuf"', '\tbuf.Parent = ss', 'end',
             'local function put(name, text, want)', '\tif hashOf(text) ~= want then', '\t\treturn name .. " garbled"', '\tend',
             '\tlocal v = buf:FindFirstChild(name) or Instance.new("StringValue")', '\tv.Name = name', '\tv.Value = text', '\tv.Parent = buf', '\treturn nil', 'end',
             'local bad = {}', 'local function chk(r)', '\tif r then', '\t\ttable.insert(bad, r)', '\tend', 'end']
        for k, o, n in part:
            L.append('chk(put("o%d", %s, "%s"))' % (k, lb(o), hs(o)))
            L.append('chk(put("n%d", %s, "%s"))' % (k, lb(n), hs(n)))
        L.append('return "part %d/%d (edits %d-%d): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))' % (pi, len(parts), part[0][0], part[-1][0]))
        open(os.path.join(outdir, 'part%02d.luau' % pi), 'w').write('\n'.join(L) + '\n')
    A = [HASH, 'local m = ' + target, 'local s = m.Source',
         'if hashOf(s) ~= "%s" then' % hs(old), '\treturn "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)', 'end',
         'local buf = game:GetService("ServerStorage"):FindFirstChild("ClaudePatchBuf")',
         'if not buf then', '\treturn "no buffer"', 'end',
         'for k = 1, %d do' % len(E),
         '\tlocal o, n = buf:FindFirstChild("o" .. k), buf:FindFirstChild("n" .. k)',
         '\tif not o or not n then', '\t\treturn "edit " .. k .. " missing"', '\tend',
         '\tlocal i, j = string.find(s, o.Value, 1, true)',
         '\tif not i or string.find(s, o.Value, j + 1, true) then', '\t\treturn "edit " .. k .. ": not found once"', '\tend',
         '\ts = string.sub(s, 1, i - 1) .. n.Value .. string.sub(s, j + 1)', 'end',
         'if hashOf(s) ~= "%s" then' % hs(new), '\treturn "NOT CHANGED (result would be " .. hashOf(s) .. ")"', 'end',
         'm.Source = s', 'buf:Destroy()', 'return m.Name .. " done: " .. hashOf(s)']
    open(os.path.join(outdir, 'apply.luau'), 'w').write('\n'.join(A) + '\n')
    print(len(E), 'edits in', len(parts), 'parts; before', hs(old), 'after', hs(new))
    for pi in range(1, len(parts) + 1):
        print(' part%02d.luau' % pi, os.path.getsize(os.path.join(outdir, 'part%02d.luau' % pi)), 'bytes')

if __name__ == '__main__':
    target, oldp, newp, outdir = sys.argv[1:5]
    make(target, open(oldp).read(), open(newp).read(), outdir)
