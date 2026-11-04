--!strict
-- WHERE EVERYTHING IN THE LOBBY STANDS (4 Nov remake; owner: "Remake heel de main lobby"). One table, read by
-- server/LobbyBuilder, server/LobbyArt and server/HubDressing, so moving a station is one edit here.
--
-- The plan (research brief of 4 Nov + the vault's "Level Design for Roblox" / "World Composition and Set
-- Dressing"):
--   * you spawn on the south side looking north at ONE tall landmark, the LAUNCH GATE (the tallest, brightest thing
--     in the lobby), with the vista of an unmown field through it: "this is what you'll mow"
--   * the four party pads stand in an arc 38 studs in front of the spawn (about 2.5 s walk at 16 studs/s), each
--     facing you; the gold CONTINUE pad (your saved run) closes the arc on the left, the SAVED RUNS board behind it
--   * the free REWARDS stall is a few steps off the walk on the left (about 15 studs from the spawn)
--   * the CLASSES cabin (with an aura mannequin) and the GARAGE line the plaza's west edge, 50-65 studs out
--   * GRASS CUT and BEST TIMES frame the gate on both sides
--   * a striped mown lawn with sandstone walks only where people go; trees dense at the edges, none in the middle;
--     one gap in the forest behind the gate
-- Coordinates: studs, lobby space (y = 0 is the ground), +Z is north (away from the spawn), +X is to your LEFT as
-- you look north from the spawn.
local LobbyLayout = {}

LobbyLayout.SPAWN = Vector3.new(0, 0, -66)

-- the flat mown plaza (a rectangle; the fence runs 2 studs inside it)
LobbyLayout.PLAZA = { x0 = -66, x1 = 64, z0 = -84, z1 = 34 }

-- the landmark: the launch gate, its middle and the way its front looks (toward the spawn)
LobbyLayout.GATE = { pos = Vector3.new(0, 0, 11), width = 62 }

-- the pads: on a circle round the spawn, at these angles (degrees from north, + to the left); 1 = SOLO
LobbyLayout.PAD_RADIUS = 38
LobbyLayout.PAD_SIZE = 10 -- each pad's glowing square (its deck is a little bigger)
LobbyLayout.PADS = {
	{ angle = 35, kind = "solo" },
	{ angle = 13, kind = "party" },
	{ angle = -13, kind = "party" },
	{ angle = -35, kind = "party" },
}
LobbyLayout.CONTINUE = { angle = 57 } -- the gold CONTINUE pad, with the SAVED RUNS board behind it

LobbyLayout.REWARDS = { pos = Vector3.new(15, 0, -61) } -- faces the walk (west)
LobbyLayout.CLASSES = { pos = Vector3.new(-52, 0, -50) } -- faces the plaza (east)
LobbyLayout.GARAGE = { pos = Vector3.new(-52, 0, -12) } -- faces the plaza (east)
LobbyLayout.GRASS_CUT = { pos = Vector3.new(41, 0, 14) } -- faces the spawn
LobbyLayout.BEST_TIMES = { pos = Vector3.new(-41, 0, 14) } -- faces the spawn

-- the sandstone walks (centre lines and widths, for server/HubPaths)
LobbyLayout.WALKS = {
	{ a = Vector2.new(0, -78), b = Vector2.new(0, 4), width = 7 }, -- spawn -> the gate, between the middle pads
	{ a = Vector2.new(-31, -50), b = Vector2.new(0, -58), width = 8 }, -- the classes porch -> the spawn
	{ a = Vector2.new(0, -58), b = Vector2.new(9, -61), width = 8 }, -- -> the rewards stall
	{ a = Vector2.new(-36, -12), b = Vector2.new(-2, -12), width = 8 }, -- the garage's turntable -> the main walk
	{ a = Vector2.new(-36, 0), b = Vector2.new(36, 0), width = 8 }, -- in front of the gate, out to both boards
}

-- A point on the pads' circle: `angle` degrees (from north, + to the left), `r` studs from the spawn.
function LobbyLayout.onArc(angle: number, r: number?): Vector3
	local a = math.rad(angle)
	local s = LobbyLayout.SPAWN
	local rr = r or LobbyLayout.PAD_RADIUS
	return Vector3.new(s.X + math.sin(a) * rr, 0, s.Z + math.cos(a) * rr)
end

-- A CFrame standing at `pos` looking at `toward` (level).
function LobbyLayout.facing(pos: Vector3, toward: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
end

return LobbyLayout
