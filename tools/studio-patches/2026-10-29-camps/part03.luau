local function hashOf(t)
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

put("CampProps.3", [====[B 2.35 .4 1.05 1.56 2.5 -1.56 0 -45 0 2
B 2.2 2.3 .85 2.15 1.15 0 0 -90 0 1
B 2.35 .4 1.05 2.2 2.5 0 0 -90 0 2
B 2.2 2.3 .85 1.52 1.15 1.52 0 -135 0 1
B 2.35 .4 1.05 1.56 2.5 1.56 0 -135 0 2
B 2.2 2.3 .85 0 1.15 2.15 0 180 0 1
B 2.35 .4 1.05 0 2.5 2.2 0 180 0 2
B 2.2 2.3 .85 -1.52 1.15 1.52 0 135 0 1
B 2.35 .4 1.05 -1.56 2.5 1.56 0 135 0 2
B 2.2 2.3 .85 -2.15 1.15 0 0 90 0 1
B 2.35 .4 1.05 -2.2 2.5 0 0 90 0 2
B 2.2 2.3 .85 -1.52 1.15 -1.52 0 45 0 1
B 2.35 .4 1.05 -1.56 2.5 -1.56 0 45 0 2
C .2 3.8 3.8 0 1.5 0 0 180 90 3
b .6 4.6 .6 -2.25 5 0 4
b .6 4.6 .6 2.25 5 0 4
B 5.8 .4 2.87 0 7.9 -1.21 -41.4 0 0 5
B 5.8 .4 2.87 0 7.9 1.21 41.4 0 0 5
b 6.05 .5 1 0 9.18 0 6
C 5.2 .4 .4 0 5.9 0 -90 0 0 4
b .25 1.1 .25 2.75 5.45 0 7
b .25 .25 .9 2.75 4.95 -.35 7
b .09 2.3 .09 .35 4.7 0 8
C .75 .96 .96 .35 3.2 0 0 180 90 7
C .12 1 1 .35 3.4 0 0 180 90 9
]=],
	camp_windmill = [=[
m VStone__@base Plaster__@tower WoodPlanks__@trim WoodPlanks__@door Glass__@glass VRoof__@roof VRoof__@roof2 Wood__5C402E Fabric__@sail
g Rotor 0 15 -3.5
b 8.6 .8 8.6 0 .4 0 1
b 7.4 4.4 7.4 0 3 0 2
B 6.36 4.4 6.36 0 3 0 0 45 0 2
b 7.7 .4 7.7 0 5.2 0 3
b 6.6 4 6.6 0 7.2 0 2
B 5.68 4 5.68 0 7.2 0 0 45 0 2
b 6.9 .4 6.9 0 9.2 0 3
b 5.8 3.8 5.8 0 11.1 0 2
B 4.99 3.8 4.99 0 11.1 0 0 45 0 2
b 6.1 .4 6.1 0 13 0 3
b 5 3.2 5 0 14.6 0 2
B 4.3 3.2 4.3 0 14.6 0 0 45 0 2
b 5.3 .4 5.3 0 16.2 0 3
b 2.7 4.4 .4 0 3 -3.65 3
b 2 3.8 .4 0 2.7 -3.8 4
b 1.6 1.9 .3 0 7.2 -3.35 3
b 1.1 1.4 .3 0 7.2 -3.45 5
b 1.6 1.9 .3 0 11 -2.95 3
b 1.1 1.4 .3 0 11 -3.05 5
B 6.8 .5 4.75 0 17.46 -1.83 -46 0 0 6
B 6.8 .5 4.75 0 17.46 1.83 46 0 0 6
b 7.05 .5 1 0 19.67 0 7
w .6 2.8 2.7 -2.6 17.6 -1.35 2
W .6 2.8 2.7 -2.6 17.6 1.35 0 -180 0 2
w .6 2.8 2.7 2.6 17.6 -1.35 2
W .6 2.8 2.7 2.6 17.6 1.35 0 -180 0 2
C 1.3 1.5 1.5 0 15 -3.6 -90 -90 0 8 1
B .45 .45 8.6 1.47 19.04 -4.2 70 -90 0 8 1
B .18 .2 6.4 2.01 19.8 -4.25 70 -90 0 8 1
B .18 .2 6.4 4.17 19.01 -4.25 70 -90 0 8 1
B 2.3 6.2 .12 3.09 19.41 -4.3 0 0 -20 9 1
B .45 .45 8.6 4.04 13.53 -4.2 -20 -90 0 8 1
B .18 .2 6.4 4.8 12.99 -4.25 -20 -90 0 8 1
B .18 .2 6.4 4.01 10.83 -4.25 -20 -90 0 8 1
B 2.3 6.2 .12 4.41 11.91 -4.3 0 0 -110 9 1
B .45 .45 8.6 -1.47 10.96 -4.2 -70 90 0 8 1
B .18 .2 6.4 -2.01 10.2 -4.25 -70 90 0 8 1
B .18 .2 6.4 -4.17 10.99 -4.25 -70 90 0 8 1
B 2.3 6.2 .12 -3.09 10.59 -4.3 0 0 160 9 1
B .45 .45 8.6 -4.04 16.47 -4.2 20 90 0 8 1
B .18 .2 6.4 -4.8 17.01 -4.25 20 90 0 8 1
B .18 .2 6.4 -4.01 19.17 -4.25 20 90 0 8 1
B 2.3 6.2 .12 -4.41 18.09 -4.3 0 0 70 9 1
]=],
	critter_chicken = [=[
m SmoothPlastic__FABE28 SmoothPlastic__E2DED6 SmoothPlastic__F8F6F0 SmoothPlastic__DC3228 SmoothPlastic__181616
g Head 0 1.1 -.35
b .12 .46 .12 -.18 .23 0 1
b .12 .46 .72 -.45 .82 .05 2
b .12 .46 .12 .18 .23 0 1
b .12 .46 .72 .45 .82 .05 2
b .8 .75 1.1 0 .82 0 3
W .55 .6 .5 0 1.12 .7 0 -180 0 3
b .5 .55 .5 0 1.42 -.5 3 1
w .2 .18 .3 0 1.38 -.88 1 1
b .12 .26 .38 0 1.8 -.48 4 1
b .12 .22 .12 0 1.2 -.8 4 1
b .06 .1 .1 -.26 1.5 -.6 5 1
b .06 .1 .1 .26 1.5 -.6 5 1
]=],
	critter_frog = [=[
m SmoothPlastic__5AB446 SmoothPlastic__C8E696 SmoothPlastic__FAFAF5 SmoothPlastic__181616
b 1 .55 1.1 0 .4 0 1
b .8 .1 .9 0 .12 -.05 2
b .9 .42 .6 0 .55 -.6 1
s .4 .4 .4 -.28 .82 -.65 3
b .12 .14 .06 -.28 .84 -.84 4
b .36 .3 .85 -.58 .18 .25 1
b .22 .35 .3 -.42 .18 -.55 1
s .4 .4 .4 .28 .82 -.65 3
b .12 .14 .06 .28 .84 -.84 4
b .36 .3 .85 .58 .18 .25 1
b .22 .35 .3 .42 .18 -.55 1
]=],
	critter_koi = [=[
m SmoothPlastic__FA7828 SmoothPlastic__FAF8F0 SmoothPlastic__181616
b .5 .4 1.2 0 .2 0 1
b .42 .36 .42 0 .2 -.78 2
W .08 .5 .6 -.14 .2 .85 0 160 0 1
W .08 .5 .6 .14 .2 .85 0 -160 0 1
B .35 .06 .22 -.38 .1 -.35 0 -25 0 1
b .05 .08 .08 -.22 .26 -.88 3
B .35 .06 .22 .38 .1 -.35 0 25 0 1
b .05 .08 .08 .22 .26 -.88 3
b .3 .05 .35 .06 .42 -.1 2
b .22 .05 .25 -.08 .42 .35 3
]=],
	critter_lizard = [=[
m SmoothPlastic__D64628 SmoothPlastic__FAB45A SmoothPlastic__181616 Neon__FFA03C
b .62 .36 1.25 0 .3 0 1
b .5 .08 1.1 0 .1 0 2
b .52 .32 .62 0 .32 -.88 1
b .4 .26 .8 0 .24 .98 1
b .24 .18 .8 0 .18 1.72 1
B .5 .16 .18 -.48 .14 -.4 0 -20 0 1
B .5 .16 .18 -.48 .14 .4 0 20 0 1
b .06 .1 .1 -.27 .42 -1 3
B .5 .16 .18 .48 .14 -.4 0 20 0 1
B .5 .16 .18 .48 .14 .4 0 -20 0 1
b .06 .1 .1 .27 .42 -1 3
b .2 .06 .2 -.05 .5 -.3 4
b .2 .06 .2 .05 .5 .15 4
b .2 .06 .2 -.05 .5 .6 4
]=],
	critter_owl = [=[
m SmoothPlastic__8C6446 SmoothPlastic__E8D6B0 SmoothPlastic__E29632 Neon__FFD23C SmoothPlastic__181616
g Head 0 1.35 0
b 1 1.2 .9 0 .75 0 1
b .7 .85 .1 0 .7 -.46 2
b .14 1 .8 -.55 .75 .05 1
b .25 .12 .3 -.22 .08 -.2 3
b .14 1 .8 .55 .75 .05 1
b .25 .12 .3 .22 .08 -.2 3
b 1.1 .8 .95 0 1.75 0 1 1
b .9 .62 .1 0 1.72 -.48 2 1
s .34 .34 .34 -.22 1.8 -.52 4 1
b .1 .12 .06 -.22 1.8 -.68 5 1
W .2 .22 .26 -.38 2.25 0 0 -180 0 1 1
s .34 .34 .34 .22 1.8 -.52 4 1
b .1 .12 .06 .22 1.8 -.68 5 1
w .2 .22 .26 .38 2.25 0 1 1
w .14 .2 .18 0 1.6 -.58 3 1
]=],
	critter_penguin = [=[
m SmoothPlastic__242630 SmoothPlastic__F6F6F4 SmoothPlastic__FA9628
g armL -.5 1.3 0
g armR .5 1.3 0
b 1 1.4 .9 0 .85 0 1
b .76 1.15 .1 0 .8 -.46 2
b .86 .66 .8 0 1.85 0 1
b .14 .14 .06 -.2 1.95 -.42 2
b .32 .12 .45 -.25 .06 -.2 3
B .14 .95 .5 -.57 .9 0 0 0 10 1 1
b .14 .14 .06 .2 1.95 -.42 2
b .32 .12 .45 .25 .06 -.2 3
B .14 .95 .5 .57 .9 0 0 0 -10 1 2
w .22 .2 .3 0 1.82 -.52 3
]=],
}

type Mat = { kind: string, col: string, t: number }
type Spec = { mats: { Mat }, groups: { { name: string, pivot: Vector3 } }, parts: { { any } } }
local specs: { [string]: Spec } = {}

local function decode(name: string): Spec?
	local cached = specs[name]
	if cached then
		return cached
	end
	local text = DATA[name]
	if not text then
		return nil
	end
	local s: Spec = { mats = {}, groups = {}, parts = {} }
	for line in string.gmatch(text, "[^\n]+") do
		local f = string.split(line, " ")
		local tag = f[1]
		if tag == "m" then
			for i = 2, #f do
				local bits = string.split(f[i], "__")
				table.insert(s.mats, { kind = bits[1], col = bits[2], t = if bits[3] then (tonumber(string.sub(bits[3], 2)) or 0) / 100 else 0 })
			end
		elseif tag == "g" then
			table.insert(s.groups, { name = f[2], pivot = Vector3.new(tonumber(f[3]) or 0, tonumber(f[4]) or 0, tonumber(f[5]) or 0) })
		else
			local n = table.create(#f - 1)
			for i = 2, #f do
				n[i - 1] = tonumber(f[i]) or 0
			end
			table.insert(s.parts, { tag, n })
		end
	end
	specs[name] = s
	return s
end

function CampProps.has(name: string): boolean
	return DATA[name] ~= nil
end

-- The materials of a model with `roles` filled in.
local function resolve(spec: Spec, roles: Roles): { any }
	local out = {}
	for i, mt in spec.mats do
		local kind, col = mt.kind, mt.col
		if kind == "Mark" then
			out[i] = { mark = col }
			continue
		end
		local color = Color3.new(1, 1, 1)
		if string.sub(col, 1, 1) == "@" then
			local r = roles[string.sub(col, 2)]
			if r then
				color = r[2] or color
				if r[1] then
					kind = r[1]
				end
			end
		else
			color = Color3.fromHex(col)
		end
		local material, variantName = nil, nil
		local v = VOXEL[kind]
		if v then
			material = v[2]
			variantName = if variant(v[1]) then v[1] else nil
		else
			local ok, m = pcall(function()
				return (Enum.Material :: any)[kind]
			end)
			material = if ok and m then m else Enum.Material.Plastic
		end
		out[i] = { material = material, variant = variantName, color = color, t = mt.t }
	end
	return out
end

local SHAPE = { b = Enum.PartType.Block, c = Enum.PartType.Cylinder, s = Enum.PartType.Ball }

-- Build model `name` at `cf` (its ground point, front toward cf.LookVector) into `parent`. Decoration (no
-- collisions) unless opts.collide. Parts of a group get the attribute G = the group's name; the model gets
-- "Pivot_<group>" (its pivot in the model's studs) and NParts. nil when there's no such model.
function CampProps.place(name: string, parent: Instance, cf: CFrame, opts: PlaceOpts?): Model?
	local o = opts or {}
	local spec = decode(name)
	if not spec then
		return nil
	end
	local k = o.scale or 1
	local mats = resolve(spec, o.roles or {})
	local model = Instance.new("Model")
	model.Name = o.name or name
	if o.atomic then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	local n = 0
	for _, p in spec.parts do
		local tag: string, v = p[1], p[2]
		local low = string.lower(tag)
		local rx, ry, rz, mi, gi = 0, 0, 0, v[7], v[8]
		if tag ~= low then
			rx, ry, rz, mi, gi = v[7], v[8], v[9], v[10], v[11]
		end
		local mt = mats[mi]
		local part: BasePart
		if low == "w" then
			part = Instance.new("WedgePart")
		else
			local pp = Instance.new("Part")
			pp.Shape = SHAPE[low] or Enum.PartType.Block
			part = pp
		end
		local size = Vector3.new(v[1], v[2], v[3]) * k
		part.Size = size
		part.CFrame = cf * CFrame.new(v[4] * k, v[5] * k, v[6] * k) * CFrame.fromOrientation(math.rad(rx), math.rad(ry), math.rad(rz))
		part.Anchored = true
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if mt and mt.mark then
			part.Name = mt.mark
			part.Transparency = 1
]====], "8975 1664558084")
return "part 3/13 (CampProps.3): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
