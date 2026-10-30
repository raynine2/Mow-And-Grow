-- Installs ArenaForge (git's exact text, 12557 757417151) into game.ServerScriptService.MowALawn. Run in Edit mode.
local src = [======[
-- ARENA FORGE (30 Oct evening, owner: "revamp every arena remove unneccery stuff also use forge gui"; his picks: the
-- block stands with the gnome crowd, the boss statue and its ruins, the glitch cracks and pixels, the light towers and
-- the loose props all go, and ForgeGUI makes everything new). Each area has five ForgeGUI models of its own
-- (shared/ForgeModelIds "fa_<piece>_<area>": a gateway, a wall section, a grandstand, a pillar with a light on top and
-- the summon altar). server/BossArena still makes the floor, the invisible colliders, the gate bars (server/ArenaGrand's
-- glitch barrier) and the summon pad; this dresses it in place of server/ArenaDress / server/MeadowArena:
--   * WALL: the area's wall section repeated round the rim at its own proportions (each copy scaled as a whole, never
--     stretched), square to the middle, from one side of the gateway round to the other, decorated face inwards
--   * PILLARS: either side of the gateway and at a few joints spread round the ring, four of them lit
--   * GATEWAY: over the entrance, its opening over the gap in the colliders (the boss's name floats above it)
--   * STANDS: one on each side, outside the wall, facing the fight, on a block of the arena's skirt where the ground
--     drops away; moved round a little (or left out) where something of the world's stands (server/ArenaGrand.isBlocked)
--   * ALTAR: round the summon pad, sunk so its flat top is just over the floor (the pad is read by distance)
-- All decoration: no collisions (the colliders do that), no queries, no touches. About 40 meshes an arena, each area's
-- copies sharing one mesh (the old dressing was 2,000 to 4,400 blocks an arena).
-- If an area's gateway, wall or altar didn't load, server/BossArena falls back to the voxel dressing (ArenaForge.ready).
local Models = require(script.Parent.Models)
local ArenaGrand = require(script.Parent.ArenaGrand)
local ArenaDress = require(script.Parent.ArenaDress)

local ArenaForge = {}

local NEEDED = { "gate", "wall", "altar" } -- (the stands and pillars are left out when theirs aren't loaded)

-- Measured on the models in Studio (30 Oct): the gateway's opening as a share of its width (at walking height) and
-- the altar's flat top as a share of its height.
-- (From the meshes' vertices: the widest empty span round the middle between 8% and 42% of the gateway's height;
-- the highest point of the altar inside its decorated rim.)
local FIT: { [string]: { open: number, top: number } } = {
	meadow = { open = 0.36, top = 0.95 },
	wheat = { open = 0.43, top = 0.86 },
	blossom = { open = 0.37, top = 0.83 },
	pine = { open = 0.29, top = 0.47 },
	swamp = { open = 0.29, top = 0.4 },
	frost = { open = 0.36, top = 0.94 },
	ember = { open = 0.33, top = 0.6 },
	isles = { open = 0.35, top = 0.96 },
}

local WALL_H = 9 -- the height the wall sections aim for (the count round the ring follows from their shape)
local PILLAR_H = 19
local EXTRA_PILLARS = 6 -- pillars spread round the ring, besides the two at the gateway
local STAND_W = 42
local STAND_H = 24
local ALTAR_W = 22
local GATE_MAX_W = 60
local GATE_MAX_H = 44
local GATE_MAX_D = 24 -- (the gateways are deep: it stands half in the arena, half out)

local function key(piece: string, area: string): string
	return "fa_" .. piece .. "_" .. area
end

-- The 30 Oct meshes face their -Z (checked in Studio: the stands' seats, the walls' decorated side). server/Models
-- turns ForgeGUI templates for a -X front unless told otherwise, so they're turned a quarter back here, and the
-- template's Z is their width.
local TURN = CFrame.Angles(0, math.pi / 2, 0)

-- A copy of an area's piece at `cf` (feet there, front toward cf.LookVector), fitted into width / height / depth
-- (any may be nil). Returns the model and its mesh's size (X width, Y height, Z depth).
local function place(piece: string, area: string, parent: Instance, cf: CFrame, w: number?, h: number?, d: number?): (Model?, Vector3)
	local m = Models.placeForge(key(piece, area), parent, cf * TURN, { depth = w, height = h, width = d }, true)
	if not m then
		return nil, Vector3.zero
	end
	local body = m:FindFirstChildWhichIsA("MeshPart", true)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	m.Name = piece
	return m, if body then body.Size else Vector3.zero
end

-- An area's piece's own shape (X width, Y height, Z depth at scale 1)
local shapes: { [string]: Vector3 } = {}
local function shape(piece: string, area: string): Vector3
	local k = key(piece, area)
	if not shapes[k] then
		local m, size = place(piece, area, workspace, CFrame.new(0, -2000, 0), nil, nil, nil)
		if m then
			m:Destroy()
		end
		shapes[k] = size
	end
	return shapes[k]
end

-- Are this area's gateway, wall and altar loaded?
function ArenaForge.ready(look: any): boolean
	if not look then
		return false
	end
	for _, piece in NEEDED do
		if not Models.has("forge_" .. key(piece, look.id)) then
			return false
		end
	end
	return true
end

local function dir(a: number): Vector3
	return Vector3.new(math.sin(a), 0, math.cos(a))
end

-- the gateway's width (its opening over most of the gap in the colliders, kept to a sensible size)
local function gateWidth(ctx: any): number
	local area = ctx.look.id
	local s = shape("gate", area)
	if s.X <= 0 then
		return ctx.segW * 2 + 8
	end
	local gapW = ctx.segW * 2
	local fit = FIT[area] or FIT.meadow
	local w = math.clamp(gapW * 0.8 / fit.open, gapW + 6, GATE_MAX_W)
	-- no taller than GATE_MAX_H, no deeper than GATE_MAX_D
	return math.min(w, GATE_MAX_H * s.X / s.Y, GATE_MAX_D * s.X / math.max(s.Z, 0.01))
end

local function block(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3?, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	if color then
		p.Color = color
		p.Material = mat or Enum.Material.Ground
	else
		p.Transparency = 1
	end
	p.Parent = parent
	return p
end

local function light(model: Model, color: Color3, range: number)
	local body = model:FindFirstChildWhichIsA("MeshPart", true)
	if not body then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "Light"
	a.Position = Vector3.new(0, body.Size.Y / 2 - 1, 0)
	a.Parent = body
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.3
	l.Shadows = false
	l.Parent = a
end

-- The wall sections and pillars all round (server/BossArena calls it in place of ArenaDress.wall).
function ArenaForge.wall(ctx: any): boolean
	local area = ctx.look.id
	local folder = Instance.new("Folder")
	folder.Name = "Forge"
	folder.Parent = ctx.model
	local R = ctx.r + 1.4 -- on the rim, just outside the colliders
	local baseY = ctx.centre.Y - 0.3 -- the rim's top
	local gw = gateWidth(ctx)
	ctx.forgeGateW = gw
	local gHalf = math.asin(math.min(0.95, gw / 2 / R))
	local ws = shape("wall", area)
	local aspect = if ws.Y > 0 then ws.X / ws.Y else 3
	local arc = 2 * math.pi - 2 * gHalf
	local n = math.max(8, math.floor(arc * R / (WALL_H * aspect) + 0.5))
	local step = arc / n
	local chord = 2 * R * math.sin(step / 2)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder
	for k = 0, n - 1 do
		local a = ctx.yaw0 + gHalf + (k + 0.5) * step
		local pos = ctx.centre + dir(a) * R
		pos = Vector3.new(pos.X, baseY, pos.Z)
		local cf = CFrame.lookAt(pos, Vector3.new(ctx.centre.X, baseY, ctx.centre.Z))
		place("wall", area, walls, cf, chord * 1.03, nil, nil)
	end
	-- pillars: at the gateway's sides and spread round the joints
	local pillars = Instance.new("Folder")
	pillars.Name = "Pillars"
	pillars.Parent = folder
	local joints = { 0, n }
	for m = 1, EXTRA_PILLARS do
		local j = math.floor(n * m / (EXTRA_PILLARS + 1) + 0.5)
		if j > 0 and j < n and not table.find(joints, j) then
			table.insert(joints, j)
		end
	end
	local glow = ctx.look.theme and ctx.look.theme.glow or ctx.look.accent
	for i, j in joints do
		local a = ctx.yaw0 + gHalf + j * step
		local pos = ctx.centre + dir(a) * R
		pos = Vector3.new(pos.X, baseY, pos.Z)
		local p = place("pillar", area, pillars, CFrame.lookAt(pos, Vector3.new(ctx.centre.X, baseY, ctx.centre.Z)), nil, PILLAR_H, nil)
		if p and (i <= 2 or i == 4 or i == #joints - 1) then
			light(p, glow, 26)
		end
	end
	return true
end

-- The gateway over the entrance, its front to the outside (in place of ArenaDress.gate).
function ArenaForge.gate(ctx: any): Model?
	local area = ctx.look.id
	local R = ctx.r + 1.4
	local pos = ctx.centre + ctx.facing * R
	pos = Vector3.new(pos.X, ctx.centre.Y - 0.3, pos.Z)
	local cf = CFrame.lookAt(pos, pos + ctx.facing)
	local m, size = place("gate", area, ctx.model, cf, ctx.forgeGateW or gateWidth(ctx), nil, nil)
	if not m then
		return nil
	end
	m.Name = "ArenaGate"
	-- its towers reach over the ends of the gap in the colliders: invisible walls in them, so the way in is the
	-- arch's opening; and where the ground drops away outside, a block of the arena's skirt under each tower
	local fit = FIT[area] or FIT.meadow
	local openHalf = size.X * fit.open / 2
	local towerW = size.X / 2 - openHalf
	local floorY = ctx.centre.Y
	for _, side in { -1, 1 } do
		local tcf = cf * CFrame.new(side * (openHalf + towerW / 2), 0, 0)
		block(m, "TowerCollider", tcf * CFrame.new(0, 13, 0), Vector3.new(towerW, 26, size.Z * 0.8))
		if ctx.world then
			local low = floorY
			for _, dz in { -0.5, 0, 0.5 } do
				for _, dx in { -0.4, 0.4 } do
					local p = tcf * Vector3.new(dx * towerW, 0, dz * size.Z)
					low = math.min(low, ArenaGrand.groundY(ctx.world, p.X, p.Z, floorY))
				end
			end
			if low < floorY - 1 then
				local hgt = floorY - low + 2
				block(m, "TowerBase", tcf * CFrame.new(0, -hgt / 2 - 0.25, 0), Vector3.new(towerW * 0.9, hgt, size.Z * 0.9), ArenaDress.skirtColor(ctx.look))
			end
		end
	end
	return m
end

-- The summon altar round the pad, its flat top just over the floor (in place of ArenaDress.altar).
function ArenaForge.altar(ctx: any, padPos: Vector3): Model?
	local area = ctx.look.id
	local m, size = place("altar", area, ctx.model, CFrame.lookAt(padPos, padPos + ctx.facing), ALTAR_W, nil, ALTAR_W)
	if not m then
		return nil
	end
	m.Name = "SummonAltar"
	local fit = FIT[area] or FIT.meadow
	-- (its top 0.35 over the floor: above the floor's faint ring, LineCut, which is 0.13 up; under the pad's glow)
	local sink = math.max(0, size.Y * fit.top - 0.35)
	m:PivotTo(m:GetPivot() - Vector3.new(0, sink, 0))
	return m
end

-- The two grandstands, outside the wall on either side, facing the fight.
function ArenaForge.stands(ctx: any, world: Instance)
	local area = ctx.look.id
	local folder = ctx.model:FindFirstChild("Forge") or ctx.model
	local s = shape("stand", area)
	if s.X <= 0 then
		return
	end
	local k = math.min(STAND_W / s.X, STAND_H / s.Y)
	local w, h, d = s.X * k, s.Y * k, s.Z * k
	local floorY = ctx.centre.Y
	local reach = ctx.r + 3 + d
	for _, side in { -1, 1 } do
		for _, deg in { 90, 78, 102, 66, 114 } do
			local a = ctx.yaw0 + side * math.rad(deg)
			local mid = ctx.centre + dir(a) * (ctx.r + 3.5 + d / 2)
			local cf = CFrame.lookAt(Vector3.new(mid.X, floorY - 0.3, mid.Z), Vector3.new(ctx.centre.X, floorY - 0.3, ctx.centre.Z))
			local box = Vector3.new(w + 2, 30, d + 2)
			local g = ArenaGrand.groundY(world, mid.X, mid.Z, floorY - 4)
			if g > floorY + 3 or ArenaGrand.isBlocked(world, cf, box) then
				continue
			end
			ArenaGrand.clearBox(world, cf * CFrame.new(0, 15, 0), box)
			local m = place("stand", area, folder, cf, w, nil, nil)
			if m then
				-- the ground drops away: a block of the arena's skirt under it (the lowest of its corners)
				local low = g
				for _, dx in { -0.45, 0.45 } do
					for _, dz in { -0.45, 0.45 } do
						local p = cf * Vector3.new(dx * w, 0, dz * d)
						low = math.min(low, ArenaGrand.groundY(world, p.X, p.Z, floorY))
					end
				end
				if low < floorY - 1 then
					local hgt = floorY - low + 2
					block(m, "StandBase", cf * CFrame.new(0, -hgt / 2 - 0.05, 0), Vector3.new(w * 0.92, hgt, d * 0.92), ArenaDress.skirtColor(ctx.look))
				end
			end
			break
		end
	end
	-- no grass under the stands (server/RunWorld keeps grass ArenaRadius + 6 from every arena's middle; deferred:
	-- server/BossArena sets the plain radius after this)
	task.defer(function()
		world:SetAttribute("ArenaRadius", math.max(world:GetAttribute("ArenaRadius") or 0, reach + 2))
	end)
end

return ArenaForge
]======]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "12557 757417151" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.ServerScriptService.MowALawn
local old = folder:FindFirstChild("ArenaForge")
if old then
	local now = hashOf(old.Source)
	if now == "12557 757417151" then
		return "ArenaForge is already this version: " .. now
	end
	local known = { ["12446 871893835"] = true }
	if not known[now] then
		return "NOT CHANGED: ArenaForge is there but is " .. now .. " (not a version this replaces)"
	end
	old.Source = src
	return "ArenaForge updated: " .. hashOf(old.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "ArenaForge"
m.Source = src
m.Parent = folder
return "ArenaForge installed: " .. hashOf(m.Source)
