-- Number formatting shared by server messages and the client UI.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 15000000 -> "15M"
function Format.short(n: number): string
	n = math.floor(n + 0.5)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local text
	if math.abs(v) >= 100 then
		text = string.format("%d", math.floor(v))
	elseif math.abs(v) >= 10 then
		text = string.format("%.1f", math.floor(v * 10) / 10)
	else
		text = string.format("%.2f", math.floor(v * 100) / 100)
	end
	-- drop trailing zeros after the point only ("1.50" -> "1.5", "2.00" -> "2"); "120" and "600" keep theirs
	-- (the old pattern turned 120K into "12K" and 600K into "6K")
	if string.find(text, ".", 1, true) then
		text = (text:gsub("0+$", ""):gsub("%.$", ""))
	end
	return text .. SUFFIXES[i]
end

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

-- 125 -> "2:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Format
