"""Put NEW scripts into Studio in several execute_luau calls (each text is checksum-checked).

    python3 mkcreate_buf.py <outdir> <Name>=<Parent path>=<ClassName>=<local file> [...]

Writes <outdir>/partNN.luau (each stores chunks as StringValues in ServerStorage.ClaudePatchBuf, reporting any chunk
that arrived garbled) and <outdir>/create.luau, which checks every chunk and the whole text's checksum
(#text .. " " .. hash, hash = (h*31+byte) % 2147483647), then creates each script. A script that already exists is
left alone unless it already has exactly this text. Run the parts in any order, then create.luau.
"""
import os, sys

CHUNK = 9000


def h(bs):
    x = 0
    for c in bs:
        x = (x * 31 + c) % 2147483647
    return "%d %d" % (len(bs), x)


def lb(s):
    eq = "=" * 4
    while ("]" + eq + "]") in s:
        eq += "="
    return "[" + eq + "[" + ("\n" if s.startswith("\n") else "") + s + "]" + eq + "]"


HEAD = '''local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	buf = Instance.new("Folder")
	buf.Name = "ClaudePatchBuf"
	buf.Parent = ss
end
local bad = {}
local function put(name, text, want)
	if hashOf(text) ~= want then
		table.insert(bad, name .. " garbled")
		return
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
end
'''


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    specs = []
    chunks = []  # (chunk name, text)
    for arg in sys.argv[2:]:
        name, parent, cls, path = arg.split("=")
        text = open(path, "rb").read().decode("utf-8")
        assert "\r" not in text
        pieces = []
        start = 0
        while start < len(text):
            end = min(len(text), start + CHUNK)
            if end < len(text):
                nl = text.rfind("\n", start, end)
                if nl > start:
                    end = nl + 1
            pieces.append(text[start:end])
            start = end
        for i, p in enumerate(pieces, 1):
            chunks.append(("%s.%d" % (name, i), p))
        specs.append((name, parent, cls, len(pieces), h(text.encode("utf-8"))))
    # pack the chunks into part files of about CHUNK characters
    parts, cur, size = [], [], 0
    for c in chunks:
        if cur and size + len(c[1]) > CHUNK * 1.15:
            parts.append(cur)
            cur, size = [], 0
        cur.append(c)
        size += len(c[1])
    if cur:
        parts.append(cur)
    for k, group in enumerate(parts, 1):
        lines = [HEAD]
        for nm, text in group:
            lines.append('put("%s", %s, "%s")' % (nm, lb(text), h(text.encode("utf-8"))))
        lines.append('return "part %d/%d (%s): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))' % (k, len(parts), ", ".join(n for n, _ in group)))
        with open(os.path.join(out, "part%02d.luau" % k), "w", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
    cl = ['''local function hashOf(t)
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
for _, s in {''']
    for name, parent, cls, n, want in specs:
        cl.append('\t{ "%s", %s, "%s", %d, "%s" },' % (name, parent, cls, n, want))
    cl.append('''} do
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
	return "NOTHING CREATED\\n" .. table.concat(out, "\\n")
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
return table.concat(out, "\\n")''')
    with open(os.path.join(out, "create.luau"), "w", newline="\n") as f:
        f.write("\n".join(cl) + "\n")
    for name, parent, cls, n, want in specs:
        print("%-10s %d chunks  %s" % (name, n, want))
    print("%d part files" % len(parts))


main()
