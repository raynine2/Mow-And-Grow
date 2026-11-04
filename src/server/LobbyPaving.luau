--!strict
-- THE LOBBY'S PAVING (4 Nov; owner, on the windmill square: "make everythin a bit bette rwith more umph like the bricks
-- etc"). The walks were the hubs' generic paving (server/HubPaths): square stones on a fixed world grid, so on every
-- turned or curved walk they stood at a slant with ragged edges, flat orange on an orange bed. Here each walk is laid
-- like a real one:
--   * straight walks in running bond (bricks, every other row shifted half a stone), rows along the walk;
--   * the curved walk in curved rows, every stone turned along the curve;
--   * round plazas in rings of stones round a gold medallion (the spawn's), every second ring a lighter cream;
--   * every stone in the camp's tile look (server/CampGround.pave: four warm sandstone tones, a lighter rim, a thin
--     inset top), on a dark grout bed that shows in the joints;
--   * a kerb of raised darker stones along every edge, stopping where another walk or plaza joins;
--   * an invisible flat plate at the stones' tops to walk on (no bobbing over the joints: server/WalkPlates).
-- Where two walks meet, the one listed first keeps its stones.
-- LobbyPaving.lay(parent, areas) -> Folder. Areas (lobby space, y = 0 the ground; angles as server/LandsBuilder's arc:
-- degrees off the axis toward the spawn, + to the left):
--   { kind = "disc", c = Vector2, r = number, medallion = boolean? }
--   { kind = "seg", a = Vector2, b = Vector2, w = number }
--   { kind = "arc", c = Vector2, r = number, w = number, a0 = number, a1 = number }
local CampGround = require(script.Parent.CampGround)

local LobbyPaving = {}

local C = Color3.fromRGB
-- (warmer and deeper than the camp's tones: in the lobby's bright light those read nearly white)
local TONES = { C(214, 140, 72), C(200, 128, 66), C(226, 154, 84), C(190, 122, 64) }
local CREAM = C(232, 190, 124)
local GOLD = C(250, 196, 70)
local GOLD_DARK = C(214, 150, 50)
local GROUT = C(86, 62, 46)
local KERB = { C(150, 116, 84), C(138, 106, 76) }
local STONE = 3.5 -- a stone's length
local GAP = 0.32 -- the joints
local BED_TOP = 0.06
local STONE_H = 0.3
local KERB_H = 0.46

export type Area = { kind: string, c: Vector2?, r: number?, a: Vector2?, b: Vector2?, w: number?, a0: number?, a1: number?, medallion: boolean? }

local function hash(i: number, j: number, k: number): number
	local n = math.sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453
	return n - math.floor(n)
end

local count = 0
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = parent
	count += 1
	if count % 250 == 0 then
		task.wait()
	end
	return p
end

-- the angle of p about c, the way server/LandsBuilder measures it (0 toward -Z, + toward +X)
local function angleOf(c: Vector2, p: Vector2): number
	return math.deg(math.atan2(p.X - c.X, -(p.Y - c.Y)))
end

local function inside(area: Area, p: Vector2, grow: number): boolean
	if area.kind == "disc" then
		return (p - (area.c :: Vector2)).Magnitude < (area.r :: number) + grow
	elseif area.kind == "seg" then
		local a, b = area.a :: Vector2, area.b :: Vector2
		local len = (b - a).Magnitude
		local u = (b - a) / len
		local n = Vector2.new(-u.Y, u.X)
		local along, across = (p - a):Dot(u), (p - a):Dot(n)
		return along > -grow and along < len + grow and math.abs(across) < (area.w :: number) / 2 + grow
	else
		local d = (p - (area.c :: Vector2)).Magnitude
		if math.abs(d - (area.r :: number)) > (area.w :: number) / 2 + grow then
			return false
		end
		local t = angleOf(area.c :: Vector2, p)
		local g = math.deg(grow / math.max(d, 1))
		return t > (area.a0 :: number) - g and t < (area.a1 :: number) + g
	end
end

-- Is p in any of the areas but `own`, only counting those listed before it (`before`) or all of them?
local function taken(areas: { Area }, own: number, p: Vector2, grow: number, before: boolean): boolean
	for i, other in areas do
		if i ~= own and (not before or i < own) and inside(other, p, grow) then
			return true
		end
	end
	return false
end

local function face(i: number, j: number, k: number): Color3
	return TONES[1 + math.floor(hash(i, j, k) * #TONES)]
end

-- One stone, its top-centre at `cf` (level), `sx` across x `sz` along.
local function stone(f: Instance, cf: CFrame, sx: number, sz: number, color: Color3, lift: number)
	if sx < 0.6 or sz < 0.6 then
		return
	end
	local s = part(f, "Stone", Vector3.new(sx, STONE_H, sz), cf * CFrame.new(0, BED_TOP + STONE_H / 2 + lift, 0), color)
	CampGround.pave(s, color)
	-- (matte: SmoothPlastic's shine washed the stones out to beige in the lobby's sun)
	s.Material = Enum.Material.Plastic
	local kids = f:GetChildren()
	local top = kids[#kids] -- (CampGround.pave's inset top, just added)
	if top and top.Name == "StoneTop" and top:IsA("BasePart") then
		top.Material = Enum.Material.Plastic
	end
end

local function kerbPiece(f: Instance, cf: CFrame, len: number, k: number)
	if len < 0.4 then
		return
	end
	part(f, "Kerb", Vector3.new(0.8, KERB_H, len), cf * CFrame.new(0, KERB_H / 2, 0), KERB[k % 2 + 1])
end

local function plate(f: Instance, size: Vector3, cf: CFrame)
	local p = part(f, "WalkPlate", Vector3.new(size.X, 0.2, size.Z), cf * CFrame.new(0, BED_TOP + STONE_H - 0.1, 0), Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = true
end

-------------------------------------------------------------------------------------------------------------
local function laySeg(f: Instance, areas: { Area }, idx: number, area: Area)
	local a, b, w = area.a :: Vector2, area.b :: Vector2, area.w :: number
	local len = (b - a).Magnitude
	local u = (b - a) / len
	local n = Vector2.new(-u.Y, u.X)
	local mid = (a + b) / 2
	local base = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Y), Vector3.new(b.X, 0, b.Y)) -- (-Z along the walk)
	local lift = idx * 0.003
	part(f, "Bed", Vector3.new(w + 0.4, BED_TOP, len), base * CFrame.new(0, BED_TOP / 2, 0), GROUT)
	plate(f, Vector3.new(w, 0, len), base)
	local rows = math.max(1, math.floor(w / STONE + 0.5))
	local rw = w / rows
	for k = 1, rows do
		local x = -w / 2 + (k - 0.5) * rw
		local shift = if k % 2 == 0 then STONE / 2 else 0
		local s0 = -shift
		local j = 0
		while s0 < len do
			local lo, hi = math.max(0, s0), math.min(len, s0 + STONE)
			local centreAlong = (lo + hi) / 2
			local p2 = a + u * centreAlong + n * x
			if not taken(areas, idx, p2, -0.2, true) then
				local col = face(idx * 7 + k, j, 3)
				if k == 1 or k == rows then
					col = col:Lerp(CampGround.BORDER, 0.18)
				end
				local cf = base * CFrame.new(x, 0, len / 2 - centreAlong) -- (base's -Z runs a -> b; its +X is n)
				stone(f, cf, rw - GAP, hi - lo - GAP, col, lift)
			end
			s0 += STONE
			j += 1
		end
	end
	-- kerbs down both sides, in short pieces, stopping where another walk joins
	for _, side in { -1, 1 } do
		local t = 0
		local k = 0
		while t < len do
			local l = math.min(2.4, len - t)
			local c = a + u * (t + l / 2) + n * side * (w / 2 + 0.4)
			if not taken(areas, idx, c, 0.2, false) then
				kerbPiece(f, base * CFrame.new(side * (w / 2 + 0.4), 0, len / 2 - (t + l / 2)), l - 0.08, k)
			end
			t += l
			k += 1
		end
	end
end

local function layArc(f: Instance, areas: { Area }, idx: number, area: Area)
	local c, R, w = area.c :: Vector2, area.r :: number, area.w :: number
	local a0, a1 = area.a0 :: number, area.a1 :: number
	local lift = idx * 0.003
	local function at(t: number, r: number): (Vector2, CFrame)
		local rad = math.rad(t)
		local p = c + Vector2.new(math.sin(rad) * r, -math.cos(rad) * r)
		local tangent = Vector2.new(math.cos(rad), math.sin(rad)) -- (the way t grows)
		local pos = Vector3.new(p.X, 0, p.Y)
		return p, CFrame.lookAt(pos, pos + Vector3.new(tangent.X, 0, tangent.Y))
	end
	-- the bed, the plate and the kerbs in short straight pieces
	local stepDeg = math.deg(2.4 / R)
	local nSteps = math.max(1, math.ceil((a1 - a0) / stepDeg))
	local dt = (a1 - a0) / nSteps
	for i = 0, nSteps - 1 do
		local tm = a0 + (i + 0.5) * dt
		local _, cf = at(tm, R)
		local chord = math.rad(dt) * R
		part(f, "Bed", Vector3.new(w + 0.4, BED_TOP, chord + 0.15), cf * CFrame.new(0, BED_TOP / 2, 0), GROUT)
		plate(f, Vector3.new(w, 0, chord + 0.1), cf)
		for _, side in { -1, 1 } do
			local rr = R + side * (w / 2 + 0.4)
			local p, kcf = at(tm, rr)
			if not taken(areas, idx, p, 0.2, false) then
				kerbPiece(f, kcf, math.rad(dt) * rr - 0.08, i)
			end
		end
	end
	-- the stones, row by row, each along the curve
	local rows = math.max(1, math.floor(w / STONE + 0.5))
	local rw = w / rows
	for k = 1, rows do
		local r = R - w / 2 + (k - 0.5) * rw
		local arcLen = math.rad(a1 - a0) * r
		local nStones = math.max(1, math.floor(arcLen / STONE + 0.5))
		local sd = (a1 - a0) / nStones
		local shift = if k % 2 == 0 then 0.5 else 0
		for j = 0, nStones - (if shift > 0 then 0 else 1) do
			local t0 = a0 + (j - shift) * sd
			local lo, hi = math.max(a0, t0), math.min(a1, t0 + sd)
			if hi - lo > 0.01 then
				local p, cf = at((lo + hi) / 2, r)
				if not taken(areas, idx, p, -0.2, true) then
					local col = face(idx * 7 + k, j, 4)
					if k == 1 or k == rows then
						col = col:Lerp(CampGround.BORDER, 0.18)
					end
					stone(f, cf, rw - GAP, math.rad(hi - lo) * r - GAP, col, lift)
				end
			end
		end
	end
end

local function layDisc(f: Instance, areas: { Area }, idx: number, area: Area)
	local c, R = area.c :: Vector2, area.r :: number
	local centre = CFrame.new(c.X, 0, c.Y)
	local lift = idx * 0.003
	local bed = part(f, "Bed", Vector3.new(BED_TOP, R * 2 + 0.8, R * 2 + 0.8), centre * CFrame.new(0, BED_TOP / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), GROUT)
	bed.Shape = Enum.PartType.Cylinder
	local pl = part(f, "WalkPlate", Vector3.new(0.2, R * 2, R * 2), centre * CFrame.new(0, BED_TOP + STONE_H - 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1))
	pl.Shape = Enum.PartType.Cylinder
	pl.Transparency = 1
	pl.CanCollide = true
	local r0 = 1.9
	if not area.medallion then
		-- a plain square stone in the middle, turned 45 degrees
		stone(f, centre * CFrame.Angles(0, math.rad(45), 0), 2.8, 2.8, TONES[3], lift)
	else
		-- a gold eight-pointed star: two squares, one turned 45 degrees, a darker one under, a round boss on top
		r0 = 2.6
		for i, a in { 0, 45 } do
			stone(f, centre * CFrame.Angles(0, math.rad(a), 0), 3.6, 3.6, if i == 1 then GOLD else GOLD_DARK, lift + i * 0.004)
		end
		local boss = part(f, "Boss", Vector3.new(0.12, 1.6, 1.6), centre * CFrame.new(0, BED_TOP + STONE_H + 0.06 + lift, 0) * CFrame.Angles(0, 0, math.rad(90)), C(255, 236, 160))
		boss.Shape = Enum.PartType.Cylinder
	end
	local ringW = 3.1
	local rings = math.max(1, math.floor((R - r0) / ringW + 0.5))
	ringW = (R - r0) / rings
	for k = 1, rings do
		local r = r0 + (k - 0.5) * ringW
		local nStones = math.max(4, math.floor(2 * math.pi * r / STONE + 0.5))
		local sd = 360 / nStones
		for j = 0, nStones - 1 do
			local t = (j + (if k % 2 == 0 then 0.5 else 0)) * sd
			local rad = math.rad(t)
			local p = c + Vector2.new(math.sin(rad) * r, -math.cos(rad) * r)
			if not taken(areas, idx, p, -0.2, true) then
				local pos = Vector3.new(p.X, 0, p.Y)
				local cf = CFrame.lookAt(pos, pos + Vector3.new(math.cos(rad), 0, math.sin(rad)))
				local col = if area.medallion and k % 2 == 1 and k < rings then CREAM else face(idx * 7 + k, j, 5)
				if k == rings then
					col = col:Lerp(CampGround.BORDER, 0.18)
				end
				stone(f, cf, ringW - GAP, 2 * math.pi * r / nStones - GAP, col, lift)
			end
		end
	end
	-- the kerb round it
	local rr = R + 0.4
	local nK = math.max(8, math.floor(2 * math.pi * rr / 2.4 + 0.5))
	for j = 0, nK - 1 do
		local t = (j + 0.5) * 360 / nK
		local rad = math.rad(t)
		local p = c + Vector2.new(math.sin(rad) * rr, -math.cos(rad) * rr)
		if not taken(areas, idx, p, 0.2, false) then
			local pos = Vector3.new(p.X, 0, p.Y)
			kerbPiece(f, CFrame.lookAt(pos, pos + Vector3.new(math.cos(rad), 0, math.sin(rad))), 2 * math.pi * rr / nK - 0.08, j)
		end
	end
end

function LobbyPaving.lay(parent: Instance, areas: { Area }): Folder
	local f = Instance.new("Folder")
	f.Name = "Paving"
	for i, area in areas do
		if area.kind == "disc" then
			layDisc(f, areas, i, area)
		elseif area.kind == "seg" then
			laySeg(f, areas, i, area)
		else
			layArc(f, areas, i, area)
		end
	end
	f.Parent = parent
	return f
end

-- Is the point (x, z) on any of the areas (grown by `grow`)?
function LobbyPaving.covers(areas: { Area }, p: Vector2, grow: number): boolean
	for _, a in areas do
		if inside(a, p, grow) then
			return true
		end
	end
	return false
end

return LobbyPaving
