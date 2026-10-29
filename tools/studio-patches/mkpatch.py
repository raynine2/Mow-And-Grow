# A guarded Studio patch made of exact-text edits (each must match once), checked before and after by checksum.
import sys, json
def h(bs):
    x = 0
    for c in bs:
        x = (x * 31 + c) % 2147483647
    return x
def lb(s):
    eq = '=' * 6
    while (']' + eq + ']') in s:
        eq += '='
    return '[' + eq + '[' + ('\n' if s.startswith('\n') else '') + s + ']' + eq + ']'
def edits_between(old, new):
    # line-based hunks, worked from the bottom of the file up, each widened (more context lines) until it matches
    # exactly once in the text as it stands when it is applied (so moved blocks and nearby hunks stay unambiguous)
    import difflib
    a, b = old.splitlines(keepends=True), new.splitlines(keepends=True)
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    tl = list(a)
    out = []
    for tag, i1, i2, j1, j2 in reversed(sm.get_opcodes()):
        if tag == 'equal':
            continue
        cur = ''.join(tl)
        c = 0
        while True:
            lo, hi = max(0, i1 - c), min(len(tl), i2 + c)
            old_s = ''.join(tl[lo:hi])
            if old_s and cur.count(old_s) == 1:
                break
            assert lo > 0 or hi < len(tl), 'no unique context'
            c += 1
        new_s = ''.join(tl[lo:i1]) + ''.join(b[j1:j2]) + ''.join(tl[i2:hi])
        out.append((old_s, new_s))
        tl[i1:i2] = b[j1:j2]
    # check they rebuild `new` applied in order
    t = old
    for o, n in out:
        assert t.count(o) == 1, o[:80]
        t = t.replace(o, n)
    assert t == new
    return out
def make(target, old, new, out_path):
    ob, nb = old.encode(), new.encode()
    E = edits_between(old, new)
    L = ['local m = ' + target, 'local s = m.Source',
         'local function hashOf(t)', '\tlocal x = 0', '\tfor i = 1, #t do', '\t\tx = (x * 31 + string.byte(t, i)) % 2147483647', '\tend', '\treturn #t .. " " .. x', 'end',
         'if hashOf(s) ~= "%d %d" then' % (len(ob), h(ob)), '\treturn "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)', 'end', 'local edits = {']
    for o, n in E:
        L.append('\t{ ' + lb(o) + ', ' + lb(n) + ' },')
    L.append('}')
    L.append('''for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "%d %d" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)''' % (len(nb), h(nb)))
    open(out_path, 'w').write('\n'.join(L) + '\n')
    print(out_path, len(E), 'edits', len('\n'.join(L)), 'bytes; before', len(ob), h(ob), 'after', len(nb), h(nb))
if __name__ == '__main__':
    target, oldp, newp, outp = sys.argv[1:5]
    make(target, open(oldp).read(), open(newp).read(), outp)
