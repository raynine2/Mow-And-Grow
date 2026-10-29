-- A small zlib/DEFLATE decoder (RFC 1950/1951) and base64 decoder in plain Luau, so tools/vfx-import's data can go
-- into Studio compressed (it has no zlib of its own). Pasted into the Studio loader as is; tested with lune.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64map = {}
for i = 1, 64 do
	b64map[string.byte(B64, i)] = i - 1
end

local function unbase64(s: string): { number }
	local out = {}
	local acc, bits = 0, 0
	for i = 1, #s do
		local v = b64map[string.byte(s, i)]
		if v then
			acc = acc * 64 + v
			bits += 6
			if bits >= 8 then
				bits -= 8
				local b = acc // (2 ^ bits)
				table.insert(out, b)
				acc -= b * (2 ^ bits)
			end
		end
	end
	return out
end

local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DBASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CLORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local function inflate(bytes: { number }): string
	local pos, bitbuf, bitcnt = 3, 0, 0 -- (skip the 2-byte zlib header)
	local function need(n: number)
		while bitcnt < n do
			bitbuf += (bytes[pos] or 0) * (2 ^ bitcnt)
			pos += 1
			bitcnt += 8
		end
	end
	local function bits(n: number): number
		need(n)
		local p = 2 ^ n
		local v = bitbuf % p
		bitbuf = (bitbuf - v) / p
		bitcnt -= n
		return v
	end
	-- canonical Huffman: counts per length and symbols in order
	local function build(lengths: { number }, n: number)
		local counts, offs, syms = table.create(16, 0), {}, {}
		for i = 0, n - 1 do
			local l = lengths[i] or 0
			counts[l + 1] += 1
		end
		counts[1] = 0
		offs[2] = 0
		for l = 2, 16 do
			offs[l + 1] = offs[l] + counts[l]
		end
		for i = 0, n - 1 do
			local l = lengths[i] or 0
			if l > 0 then
				syms[offs[l + 1]] = i
				offs[l + 1] += 1
			end
		end
		return { counts = counts, syms = syms }
	end
	local function decode(h): number
		local code, first, index = 0, 0, 0
		for len = 1, 15 do
			code += bits(1)
			local count = h.counts[len + 1]
			if code - count < first then
				return h.syms[index + (code - first)]
			end
			index += count
			first = (first + count) * 2
			code *= 2
		end
		error("bad code")
	end
	local out = {}
	local outn = 0
	local fixedL, fixedD
	repeat
		local final = bits(1)
		local btype = bits(2)
		if btype == 0 then
			bitbuf, bitcnt = 0, 0
			local len = bytes[pos] + bytes[pos + 1] * 256
			pos += 4
			for _ = 1, len do
				outn += 1
				out[outn] = bytes[pos]
				pos += 1
			end
		else
			local lit, dist
			if btype == 1 then
				if not fixedL then
					local l = {}
					for i = 0, 143 do l[i] = 8 end
					for i = 144, 255 do l[i] = 9 end
					for i = 256, 279 do l[i] = 7 end
					for i = 280, 287 do l[i] = 8 end
					fixedL = build(l, 288)
					local d = {}
					for i = 0, 29 do d[i] = 5 end
					fixedD = build(d, 30)
				end
				lit, dist = fixedL, fixedD
			else
				local hlit, hdist, hclen = bits(5) + 257, bits(5) + 1, bits(4) + 4
				local cl = {}
				for i = 1, hclen do
					cl[CLORDER[i]] = bits(3)
				end
				local clh = build(cl, 19)
				local lens = {}
				local i = 0
				while i < hlit + hdist do
					local sym = decode(clh)
					if sym < 16 then
						lens[i] = sym
						i += 1
					elseif sym == 16 then
						local prev = lens[i - 1]
						for _ = 1, 3 + bits(2) do
							lens[i] = prev
							i += 1
						end
					elseif sym == 17 then
						for _ = 1, 3 + bits(3) do
							lens[i] = 0
							i += 1
						end
					else
						for _ = 1, 11 + bits(7) do
							lens[i] = 0
							i += 1
						end
					end
				end
				local ll, dl = {}, {}
				for k = 0, hlit - 1 do ll[k] = lens[k] end
				for k = 0, hdist - 1 do dl[k] = lens[hlit + k] end
				lit, dist = build(ll, hlit), build(dl, hdist)
			end
			while true do
				local sym = decode(lit)
				if sym < 256 then
					outn += 1
					out[outn] = sym
				elseif sym == 256 then
					break
				else
					sym -= 257
					local len = LBASE[sym + 1] + bits(LEXT[sym + 1])
					local ds = decode(dist)
					local d = DBASE[ds + 1] + bits(DEXT[ds + 1])
					for _ = 1, len do
						outn += 1
						out[outn] = out[outn - d]
					end
				end
			end
		end
	until final == 1
	-- bytes to a string, in slices (string.char takes a limited number of arguments)
	local parts = {}
	for k = 1, outn, 4096 do
		table.insert(parts, string.char(table.unpack(out, k, math.min(k + 4095, outn))))
	end
	return table.concat(parts)
end

return { unbase64 = unbase64, inflate = inflate }
