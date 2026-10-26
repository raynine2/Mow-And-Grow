-- The boss arenas dressed for the area they stand in (the owner, 26 Oct: "I meant the whole arena boss area and
-- not just the gate ... use forge gui to make the models fit with each other and the world"). The arenas were
-- themed after their bosses (hedge, golf bunker, pumpkin...), so a swamp ring stood in the snow of Frost Peaks and
-- a golf sand pit in Blossom Garden. Now each arena takes its area's look from shared/Zones:
--   * the floor, rim and skirt in the area's ground and rock colours and textures (like RunWorld.texturedGround)
--   * a ForgeGUI wall section on every wall segment, fitted to the segment's width so they join up, and a pillar
--     on every joint (none at the entrance: the gateway's own pillars stand there)
--   * the area's ForgeGUI props round the inside of the wall, clear of the entrance
--   * the area's gateway, fitted to the entrance gap (server/BossArena places it)
-- Every model is optional: when one isn't loaded, BossArena's old part-built wall / arch stays as the fallback.
-- The colliders, gate bars, summon pad and ramp are BossArena's and don't change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)
local Models = require(script.Parent.Models)

local ArenaDress = {}

export type Look = {
	id: string,
	floor: Color3,
	floorMat: Enum.Material,
	rim: Color3,
	rimMat: Enum.Material,
	accent: Color3,
	gate: string, -- ForgeGUI gateway (shared/ForgeModelIds)
	wall: string,
	post: string,
	props: { string },
}

-- the models for each area (by shared/Zones id); the gateways made for the boss themes are reused where they
-- suit the area (the barn posts for the wheat, the shrine gate for the blossom, the rune stones for the pines)
local SET: { [string]: { gate: string, n: string } } = {
	meadow = { gate = "arena_meadow", n = "meadow" },
	wheat = { gate = "arena_cornfield", n = "wheat" },
	blossom = { gate = "arena_sakura", n = "blossom" },
	pine = { gate = "arena_ruins", n = "pine" },
	swamp = { gate = "arena_swamp", n = "swamp" },
	frost = { gate = "arena_frost", n = "frost" },
	ember = { gate = "arena_ember", n = "ember" },
	isles = { gate = "arena_starlight", n = "starlight" },
}

local function dim(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

-- The look of area z's arena, or nil when the area has no set (BossArena then uses its boss themes).
function ArenaDress.look(z: number): Look?
	local zone = Zones.list[z]
	local set = zone and SET[zone.id]
	if not zone or not set then
		return nil
	end
	local p = zone.palette
	local n = set.n
	return {
		id = zone.id,
		floor = p.ground,
		floorMat = if zone.id == "frost" then Enum.Material.Snow elseif zone.id == "ember" then Enum.Material.Basalt else Enum.Material.Grass,
		rim = p.rock,
		rimMat = if zone.id == "frost" then Enum.Material.Glacier else Enum.Material.Slate,
		accent = p.accent,
		gate = set.gate,
		wall = "awall_" .. n,
		post = "apost_" .. n,
		props = { "aprop_" .. n .. "1", "aprop_" .. n .. "2" },
	}
end

-- The skirt under the floor: the area's ground, darker, with the dirt texture of the world's terrace sides.
function ArenaDress.skirtColor(look: Look): Color3
	return dim(look.floor, 0.28)
end

-- A ForgeGUI model stretched to exactly `size` (width, height, depth: the wall sections must meet end to end),
-- standing on `cf` with its front toward cf.LookVector. nil when it isn't loaded.
local function placeBox(name: string, parent: Instance, cf: CFrame, size: Vector3): Model?
	local m = Models.placeForge(name, parent, CFrame.new(), { width = size.X }, true)
	if not m then
		return nil
	end
	local body = m:FindFirstChildWhichIsA("MeshPart", true)
	if body then
		local have = m:GetExtentsSize()
		local k = Vector3.new(size.X / have.X, size.Y / have.Y, size.Z / have.Z)
		-- the mesh is turned about Y only (Models.prepareForge): its own X runs along the model's X or its Z
		local alongX = math.abs(body.CFrame.RightVector.X) > 0.7
		local kx, kz = if alongX then k.X else k.Z, if alongX then k.Z else k.X
		body.Size = Vector3.new(body.Size.X * kx, body.Size.Y * k.Y, body.Size.Z * kz)
		body.CFrame = CFrame.new(body.Position.X * k.X, body.Size.Y / 2, body.Position.Z * k.Z) * body.CFrame.Rotation
	end
	m:PivotTo(cf)
	return m
end

-- How tall / deep a wall section comes out when stretched to width w: its own shape, kept in sensible bounds.
local function wallSize(name: string, w: number): Vector3?
	local probe = Models.placeForge(name, workspace, CFrame.new(0, -500, 0), { width = w }, true)
	if not probe then
		return nil
	end
	local s = probe:GetExtentsSize()
	probe:Destroy()
	return Vector3.new(w, math.clamp(s.Y, 5.5, 8), math.clamp(s.Z, 1.6, 3.2))
end

export type Ctx = {
	model: Model,
	centre: Vector3,
	r: number,
	facing: Vector3,
	segs: number,
	segW: number,
	yaw0: number,
	look: Look,
}

-- The wall sections, the pillars between them and the props inside. Returns false (nothing placed) when the
-- area's wall model isn't loaded.
function ArenaDress.wall(ctx: Ctx): boolean
	local look = ctx.look
	local size = wallSize(look.wall, ctx.segW + 0.5)
	if not size then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = "Dress"
	folder.Parent = ctx.model
	local c = ctx.centre
	local function rimAt(a: number, rad: number): CFrame
		local pos = c + Vector3.new(math.sin(a), 0, math.cos(a)) * rad
		return CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
	end
	-- sections: every segment but the two either side of the entrance (BossArena's gap)
	for i = 1, ctx.segs - 2 do
		local a = ctx.yaw0 + (i + 0.5) / ctx.segs * 2 * math.pi
		local m = placeBox(look.wall, folder, rimAt(a, ctx.r), size)
		if m then
			m.Name = "WallSection"
		end
	end
	-- pillars on the joints between sections (the two at the entrance are the gateway's)
	local postH = size.Y * 1.45
	for j = 2, ctx.segs - 2 do
		local a = ctx.yaw0 + j / ctx.segs * 2 * math.pi
		local m = Models.placeForge(look.post, folder, rimAt(a, ctx.r), { height = postH, width = 4.2, depth = 4.2 }, true)
		if m then
			m.Name = "WallPillar"
		end
	end
	-- props inside the wall, in pairs between the pillars, none within 40 degrees of the entrance; no collisions
	-- (a knock back must never pin anyone against one)
	local rng = Random.new(ctx.segs * 7 + #look.id)
	local spots = 12
	for s = 0, spots - 1 do
		local t = (s + 0.5) / spots
		local a = ctx.yaw0 + t * 2 * math.pi
		local fromGate = math.min(t, 1 - t) * 360
		if fromGate < 40 then
			continue
		end
		local name = look.props[s % 2 + 1]
		local h = if s % 2 == 0 then rng:NextNumber(6.5, 8.5) else rng:NextNumber(4.5, 6)
		local at = rimAt(a + rng:NextNumber(-0.04, 0.04), ctx.r - 5.5) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
		local m = Models.placeForge(name, folder, at, { height = h, width = 9, depth = 9 }, true)
		if m then
			m.Name = "Prop"
		end
	end
	return true
end

return ArenaDress
