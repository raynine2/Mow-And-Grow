--!strict
-- THE BACK OF THE LOBBY (owner, 4 Nov, turning round at the spawn: "I DONT LIKE THE BACK AREA OF THE MAP VERY VERY
-- BLAND AND EMPTY"; then, of the vegetable patch and the picnic built here from loose blocks: "REMOVE ALL THIS
-- NONSENCE AND STUYFF"). So: only the game's own models here, nothing built from loose blocks (no fences, crops,
-- picnic, hen house, block pond, block flowers or crystals; they were in f91793b..228c256). server/LandsBuilder
-- calls LobbyGarden.dress after the lands; it lays the star walk's paving with the other walks and leaves a wider gap
-- in the hedge (now the voxel bushes) for its gate. Facing the observatory from the spawn:
--   * THE STAR WALK down the middle, from the spawn's plaza through the hedge to a round landing at the
--     observatory's steps: lamps in pairs, two of the isles' lit pillars as its gate, the voxel floating rocks
--     bobbing above the landing's sides (a taste of the Isles);
--   * either side of the walk, mirrored: little cherry trees (the voxel blossom trees) framing the observatory, and
--     further out a small grove (a meadow tree, bushes, a rock) where the lawn was bare;
--   * the golden MOWER STATUE between the rewards stall and the garage, turned to the spawn;
--   * past the hedge, all round the island between the hedge and the forest: the voxel bushes and rocks in the
--     nearest land's colours, so the ring of grass between the lands isn't bare either.
-- Lobby space as LandsBuilder's: y = 0 the ground, +Z north (the windmill), the observatory south of the spawn.
local CollectionService = game:GetService("CollectionService")

local Models = require(script.Parent.Models)
local VoxelKit = require(script.Parent.VoxelKit)
local VM = require(script.Parent.VoxelModels)

local LobbyGarden = {}

local C = Color3.fromRGB

export type Ctx = {
	spawn: Vector3,
	centre: Vector3, -- the hedge's (and the lands' ring's) middle
	hedgeR: number,
	backZ: number, -- the star walk's landing at the observatory's steps
	gateDeg: number, -- the gate pillars, this many degrees either side of the walk on the hedge
	lands: { { id: string, pos: Vector3 } },
	patchR: number, -- each land's own patch of ground
	forestR: number, -- the forest belt starts this far from the centre
	squareC: Vector3,
	squareR: number,
	covers: (x: number, z: number, grow: number) -> boolean, -- on (or within `grow` of) a walk
}

local rng = Random.new(5150)

local function tag(inst: Instance, name: string, attrs: { [string]: any })
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- an invisible spot client/LobbyFX dresses (its Kind)
local function fxSpot(parent: Instance, at: Vector3, size: Vector3, kind: string, color: Color3?)
	local p = VoxelKit.part(parent, kind .. "Spot", CFrame.new(at), size, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	tag(p, "LobbyFX", { Kind = kind, Color = color })
end

-- what already stands on the lawn, so the scatter keeps off it: { x, z, r }
local taken: { { number } } = {}
local function take(x: number, z: number, r: number)
	table.insert(taken, { x, z, r })
end
local function free(x: number, z: number, r: number): boolean
	for _, t in taken do
		local dx, dz = x - t[1], z - t[2]
		if dx * dx + dz * dz < (r + t[3]) ^ 2 then
			return false
		end
	end
	return true
end

local function quarter(): number
	return rng:NextInteger(0, 3) * math.pi / 2
end

-- a voxel tree (with the trunk's blocker, as LandsBuilder's trees)
local function tree(parent: Instance, name: string, p: Vector3, s: number)
	if VM.place(parent, name, p, { scale = s, yaw = quarter() }) then
		VM.blocker(parent, Vector3.new(4.8 * s, 20 * s, 4.8 * s), CFrame.new(p + Vector3.new(0, 10 * s, 0)))
	end
	take(p.X, p.Z, 34 * s / 2)
end

local function bush(parent: Instance, name: string, p: Vector3, s: number)
	VM.place(parent, name, p, { scale = s, yaw = quarter(), collide = true })
	take(p.X, p.Z, 5 * s)
end

local function rock(parent: Instance, name: string, p: Vector3, s: number)
	VM.place(parent, name, p + Vector3.new(0, -0.3, 0), { scale = s, yaw = rng:NextNumber(0, 6.28), collide = true })
	take(p.X, p.Z, 6 * s)
end

-------------------------------------------------------------------------------------------------------------
-- the star walk
-------------------------------------------------------------------------------------------------------------
local ISLE_GLOW = C(150, 230, 255)

local function floatingRock(parent: Instance, at: Vector3, s: number, seed: number)
	local m = Instance.new("Model")
	m.Name = "FloatingRock"
	if not VM.place(m, "Landmark_floatrock", at, { scale = s, yaw = rng:NextNumber(0, 6.28) }) then
		return
	end
	m.WorldPivot = CFrame.new(at)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	tag(m, "CampBob", { Amp = 0.9, Freq = 0.11 + seed * 0.02, Spin = (if seed % 2 == 0 then 3 else -3), Roll = 2 })
end

local function starWalk(world: Instance, ctx: Ctx)
	local f = folder(world, "StarWalk")
	local z0 = ctx.spawn.Z - 10
	-- lamps in pairs along the walk, turned to it
	for _, z in { z0 - 8, z0 - 20 } do
		for _, sx in { -1, 1 } do
			local p = Vector3.new(sx * 4.9, 0, z)
			if not Models.place("lantern_post", f, CFrame.lookAt(p, Vector3.new(0, 0, z)), 0.9, true) then
				VM.place(f, "S_lantern_post", p, { collide = true })
			end
			take(p.X, p.Z, 1.5)
		end
	end
	-- the gate: two of the isles' lit pillars on the hedge line either side of the walk (lit like the camps' plaza
	-- pillars: server/HubPlaza.frame)
	for _, sx in { -1, 1 } do
		local a = math.rad(ctx.gateDeg * sx)
		local p = ctx.centre + Vector3.new(math.sin(a) * ctx.hedgeR, 0, -math.cos(a) * ctx.hedgeR)
		local m = Models.placeForge("fa_pillar_isles", f, CFrame.lookAt(p, Vector3.new(0, 0, p.Z + 20)), { height = 11 }, false)
		if m then
			local box, size = m:GetBoundingBox()
			local lamp = VoxelKit.part(f, "PillarLight", CFrame.new(box.Position + Vector3.new(0, size.Y * 0.36, 0)), Vector3.one * 0.4, ISLE_GLOW)
			lamp.Transparency = 1
			lamp.CastShadow = false
			VoxelKit.light(lamp, 16, 1.4, ISLE_GLOW)
		end
		take(p.X, p.Z, 3)
	end
	-- the voxel floating rocks above the landing's sides (bobbing: client/CampLife)
	for i, p in { Vector3.new(-25, 17, ctx.backZ - 6), Vector3.new(27, 21, ctx.backZ - 12), Vector3.new(-9, 27, ctx.backZ - 30), Vector3.new(14, 15, ctx.backZ + 6) } do
		floatingRock(f, p, if i == 3 then 0.16 else 0.11, i)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the lawn behind the spawn: cherry trees and groves, mirrored about the walk
-------------------------------------------------------------------------------------------------------------
local function groves(world: Instance, ctx: Ctx)
	local f = folder(world, "BackGroves")
	local z = ctx.spawn.Z
	for _, sx in { -1, 1 } do
		-- two little cherry trees each side, framing the observatory
		tree(f, if sx < 0 then "Tree_blossom_1" else "Tree_blossom_2", Vector3.new(sx * 13, 0, z - 30), 0.3)
		tree(f, "Tree_blossom_3", Vector3.new(sx * 21, 0, z - 34), 0.26)
		-- further out a meadow tree with bushes and a rock round it
		tree(f, if sx < 0 then "Tree_meadow_2" else "Tree_meadow_1", Vector3.new(sx * 37, 0, z - 21), 0.38)
		bush(f, "Bush_blossom", Vector3.new(sx * 29, 0, z - 26), 0.55)
		bush(f, "Bush_meadow", Vector3.new(sx * 44, 0, z - 12), 0.5)
		rock(f, "Rock_meadow", Vector3.new(sx * 30, 0, z - 16), 0.3)
	end
	-- left of the fountain, mirroring the statue on the other side
	bush(f, "Bush_meadow", Vector3.new(-50, 0, z - 4), 0.55)
	rock(f, "Rock_meadow", Vector3.new(-45, 0, z - 9), 0.26)
	fxSpot(f, Vector3.new(0, 4, z - 32), Vector3.new(44, 5, 10), "butterflies", C(255, 170, 210))
end

-- the golden mower statue (it has its own mossy stone base) between the rewards stall and the garage, turned to the
-- spawn
local function statue(world: Instance, ctx: Ctx)
	local f = folder(world, "MowerStatue")
	local at = Vector3.new(52, 0, ctx.spawn.Z - 3)
	local cf = CFrame.lookAt(at, Vector3.new(ctx.spawn.X, 0, ctx.spawn.Z))
	take(at.X, at.Z, 5.5)
	if VM.place(f, "Prop_mower_statue", at, { scale = 0.8, yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z), collide = true }) == nil then
		Models.place("mower_tractor", f, cf, 0.8, true)
	end
end

-------------------------------------------------------------------------------------------------------------
-- the ring past the hedge
-------------------------------------------------------------------------------------------------------------
local BUSH = { meadow = "Bush_meadow", wheat = "Bush_wheat", blossom = "Bush_blossom", pine = "Bush_pine", swamp = "Bush_swamp", frost = "Bush_frost", ember = "Bush_ember", isles = "Bush_isles" }

local function nearestLand(ctx: Ctx, x: number, z: number): (string, number)
	local best, bd = "meadow", math.huge
	for _, l in ctx.lands do
		local d = (Vector3.new(x, 0, z) - Vector3.new(l.pos.X, 0, l.pos.Z)).Magnitude
		if d < bd then
			best, bd = l.id, d
		end
	end
	return best, bd
end

local function ring(world: Instance, ctx: Ctx)
	local f = folder(world, "Meadows")
	local cx, cz = ctx.centre.X, ctx.centre.Z
	for gx = -150, 150, 14 do
		for gz = -170, 130, 14 do
			local x, z = gx + rng:NextNumber(-4, 4), gz + rng:NextNumber(-4, 4)
			local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
			local land, ld = nearestLand(ctx, x, z)
			local inSquare = (Vector3.new(x, 0, z) - Vector3.new(ctx.squareC.X, 0, ctx.squareC.Z)).Magnitude < ctx.squareR + 4
			local onHedge = d > ctx.hedgeR - 5 and d < ctx.hedgeR + 6
			if d < ctx.forestR - 6 and not inSquare and not onHedge and ld > ctx.patchR - 2 and free(x, z, 5) and not ctx.covers(x, z, 4) and rng:NextNumber() < 0.5 then
				if rng:NextNumber() < 0.72 then
					bush(f, BUSH[land] or "Bush_meadow", Vector3.new(x, 0, z), rng:NextNumber(0.42, 0.6))
				else
					rock(f, "Rock_" .. land, Vector3.new(x, 0, z), rng:NextNumber(0.24, 0.36))
				end
			end
		end
		task.wait()
	end
end

-------------------------------------------------------------------------------------------------------------
function LobbyGarden.dress(world: Instance, ctx: Ctx)
	table.clear(taken)
	-- (the fountain garden and the rewards stall, already standing behind the spawn's sides)
	take(-26, ctx.spawn.Z, 10)
	take(26, ctx.spawn.Z, 10)
	local steps: { { any } } = {
		{ "star walk", starWalk },
		{ "groves", groves },
		{ "statue", statue },
		{ "meadows", ring },
	}
	for _, s in steps do
		local ok, err = pcall(s[2], world, ctx)
		if not ok then
			warn("[LobbyGarden] " .. s[1] .. ": " .. tostring(err))
		end
		task.wait()
	end
end

return LobbyGarden
