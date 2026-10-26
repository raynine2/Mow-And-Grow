-- The boss rigs (shared/BossRigs/<rig>, made by tools/bosses from the Blender GLBs): which MeshPart (P00, P01 ...)
-- belongs to which moving group, the attachment points (att_*), each material's normal and rage look, the
-- model's bounds, and the two idle clips ("idle", "rage") as per-group affine deltas D(t) (3x4, row-major, in
-- model units, applied to the rest pose: p' = D(t) * p). Decoded once per rig.
local HttpService = game:GetService("HttpService")

local BossRig = {}

export type Clip = { len: number, g: { [string]: { { number } } } }
export type Rig = {
	name: string,
	parts: { { n: string, g: string, mat: string, rage: boolean, c: { number }, s: { number } } },
	groups: { [string]: { number } },
	atts: { { n: string, g: string, p: { number } } },
	looks: { [string]: { n: { c: string, m: string, t: number? }, r: { c: string, m: string, t: number? } } },
	clips: { idle: Clip, rage: Clip },
	bounds: { { number } },
}

local cache: { [string]: Rig } = {}

function BossRig.load(name: string): Rig?
	if cache[name] then
		return cache[name]
	end
	local folder = script.Parent:FindFirstChild("BossRigs")
	local mod = folder and folder:FindFirstChild(name)
	if not mod then
		return nil
	end
	local ok, rig = pcall(function()
		return HttpService:JSONDecode((require :: any)(mod))
	end)
	if not ok then
		warn("[BossRig] " .. name .. ": " .. tostring(rig))
		return nil
	end
	cache[name] = rig
	return rig
end

-- The delta of `group` at time t (seconds, looped) of `clip`, written into `out` (12 numbers).
function BossRig.sample(clip: Clip, group: string, t: number, out: { number }): { number }
	local keys = clip.g[group]
	if not keys or #keys == 0 then
		out[1], out[2], out[3], out[4] = 1, 0, 0, 0
		out[5], out[6], out[7], out[8] = 0, 1, 0, 0
		out[9], out[10], out[11], out[12] = 0, 0, 1, 0
		return out
	end
	if #keys == 1 then
		local k = keys[1]
		for i = 1, 12 do
			out[i] = k[i + 1]
		end
		return out
	end
	local len = clip.len
	if len > 0 then
		t = t % len
	end
	-- binary search for the last key at or before t
	local lo, hi = 1, #keys
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if keys[mid][1] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = keys[lo], keys[hi]
	local span = b[1] - a[1]
	local f = if span > 1e-6 then math.clamp((t - a[1]) / span, 0, 1) else 0
	for i = 2, 13 do
		out[i - 1] = a[i] + (b[i] - a[i]) * f
	end
	return out
end

-- An affine delta as a CFrame (rotation part orthonormalised) plus its scale along the model's x, y, z.
function BossRig.toCFrame(d: { number }, scale: number): CFrame
	local x = Vector3.new(d[1], d[5], d[9])
	local y = Vector3.new(d[2], d[6], d[10])
	local z = Vector3.new(d[3], d[7], d[11])
	local pos = Vector3.new(d[4], d[8], d[12]) * scale
	x = x.Unit
	z = x:Cross(y).Unit
	y = z:Cross(x).Unit
	return CFrame.fromMatrix(pos, x, y, z)
end

return BossRig
