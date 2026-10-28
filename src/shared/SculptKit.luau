--!strict
-- SculptKit: builds the voxel sculptures written by tools/blender/voxel/sculptkit.py (`write_luau`) out of parts.
-- A shape module holds a PALETTE ({ r, g, b, material, tag? }) and lists of GROUPS; each group has its voxel size,
-- its pivot (the joint, in its parent group's frame), its parent's name and its boxes, 8 characters per box: the
-- box's low corner x, y, z and its size x, y, z in cells, then its palette colour as two base-90 digits (each
-- character's value is its position in ALPHA). `origin` is the pivot's position in cells from the grid corner.
--
--   SculptKit.decode(group)                    the group's boxes: { { centre, size, colour } } in studs (pivot frame)
--   SculptKit.fill(holder, frame, group, palette, scale, opts)  makes the group's parts at `frame` (the pivot's CFrame)
--                                              welded to `holder` (a part) and returns them; yields every
--                                              opts.yieldEvery parts if given
local SculptKit = {}

local ALPHA: { [number]: number } = {}
do
	local i = 0
	for c = 35, 126 do
		if c ~= 92 and c ~= 93 then -- (no "\" or "]": the data sits in [[ ]] strings)
			ALPHA[c] = i
			i += 1
		end
	end
end
local BASE = 90

export type Group = {
	name: string,
	voxel: number,
	origin: Vector3,
	pivot: Vector3,
	parent: string?,
	boxes: string,
}
export type Palette = { { any } }
export type Box = { centre: Vector3, size: Vector3, colour: number }

local cache: { [string]: { Box } } = {}

-- The boxes of a group, in studs, centred in the group's pivot frame (cached by the box string).
function SculptKit.decode(group: Group): { Box }
	local hit = cache[group.boxes]
	if hit then
		return hit
	end
	local s = group.boxes
	local v = group.voxel
	local o = group.origin
	local out: { Box } = table.create(#s // 8)
	for i = 1, #s - 7, 8 do
		local x, y, z, sx, sy, sz, c1, c2 = string.byte(s, i, i + 7)
		local bx, by, bz = ALPHA[x], ALPHA[y], ALPHA[z]
		local wx, wy, wz = ALPHA[sx], ALPHA[sy], ALPHA[sz]
		table.insert(out, {
			centre = Vector3.new((bx + wx / 2 - o.X) * v, (by + wy / 2 - o.Y) * v, (bz + wz / 2 - o.Z) * v),
			size = Vector3.new(wx * v, wy * v, wz * v),
			colour = ALPHA[c1] * BASE + ALPHA[c2],
		})
	end
	cache[group.boxes] = out
	return out
end

local materials: { [string]: Enum.Material } = {}
local function material(name: string): Enum.Material
	local m = materials[name]
	if not m then
		local ok, res = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		m = if ok and res then res else Enum.Material.SmoothPlastic
		materials[name] = m :: Enum.Material
	end
	return m :: Enum.Material
end

export type FillOptions = {
	yieldEvery: number?, -- yield (task.wait) after this many parts
	shadowMin: number?, -- parts smaller than this (studs, largest side) cast no shadow (default 0.25)
	tags: { [string]: (part: BasePart) -> () }?, -- per palette tag: adjust the part (e.g. the monocle's glass)
}

-- Makes a group's parts at `frame` (its pivot's CFrame in the world) inside `holder`'s parent model, each welded to
-- `holder`. Returns the parts. Not parented to the world until the caller parents the model.
function SculptKit.fill(holder: BasePart, frame: CFrame, group: Group, palette: Palette, scale: number, opts: FillOptions?): { BasePart }
	local boxes = SculptKit.decode(group)
	local parts: { BasePart } = table.create(#boxes)
	local shadowMin = (opts and opts.shadowMin or 0.25)
	local every = opts and opts.yieldEvery
	local tags = opts and opts.tags
	local made = 0
	for _, b in boxes do
		local entry = palette[b.colour]
		local p = Instance.new("Part")
		p.Name = group.name
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local size = b.size * scale
		p.Size = size
		p.CastShadow = math.max(size.X, size.Y, size.Z) >= shadowMin
		if entry then
			p.Color = Color3.fromRGB(entry[1], entry[2], entry[3])
			p.Material = material(entry[4] or "SmoothPlastic")
		end
		p.CFrame = frame * CFrame.new(b.centre * scale)
		local w = Instance.new("WeldConstraint")
		w.Part0 = holder
		w.Part1 = p
		w.Parent = p
		p.Parent = holder
		if entry and entry[5] and tags then
			local f = tags[entry[5]]
			if f then
				f(p)
			end
		end
		table.insert(parts, p)
		made += 1
		if every and made % every == 0 then
			task.wait()
		end
	end
	return parts
end

return SculptKit
