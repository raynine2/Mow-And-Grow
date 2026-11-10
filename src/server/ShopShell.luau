-- SHOP SHELL (30 Oct evening, owner: "the house at spawn feels a bit idk"; picked: remake it with ForgeGUI and keep
-- the room made earlier that day, server/ShopRoom). A ForgeGUI cabin (shared/ForgeModelIds "toolshop_shell") stands
-- where the log lodge server/CampBuildings builds stands, about its size (a cabin big enough to hide the lodge
-- whole wouldn't fit next to the bag stand). client/ShopShellView shows one or the other: with your camera outside
-- the cabin, and of the lodge only its floor and the room (seen through the doorway); with the camera inside the
-- lodge, the lodge and its room as before, the cabin hidden. The lodge's walls keep their collisions; the cabin has
-- none and no queries, so you (and the camera) go in through its doorway to the lodge's door.
-- The lodge's outside-only bits go (the cabin has its own, and hidden they'd be things to bump into): the porch (its
-- roof boards, posts, rails, sign, lanterns; the deck and steps stay, invisible, to walk on), the window boxes and
-- shutters, the chimney, the firewood and the medallion on the roof. The yard in front (fence, flower beds,
-- wheelbarrow, gnome, mailbox) stays.
-- Coordinates are the lodge's (server/CampBuildings): y 0 the ground, -Z out of the door, the walls x -22.2..22.2,
-- z -9.8..16.9, the main roof up to y 26.3 over z -11..18.6, the door x -6..6, y up to 13.
-- (31 Oct, owner: "the house goes back to the old house when going in"; picked: the inside in the new house's style)
-- Inside, the lodge is dressed like the cabin: round orange-tan logs (a cylinder over each square log, which stays,
-- unseen, for its collisions), dark chinking, red beams, green window and door frames, a warm plank ceiling (restyle).
-- (31 Oct, owner: "also use this house for the garage model alike") The Garage the same way: a ForgeGUI log garage
-- in the cabin's style ("garage_shell") round the voxel garage (server/CampBuildings), its inside restyled.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = require(script.Parent.Models)

local ShopShell = {}

ShopShell.ON = true
-- (10 Nov, owner: "in the main area of zone 1 the house is still bugged ... there are 2 houses in 1 please fix it") ONE
-- house: the ForgeGUI cabin (and garage) round the voxel lodge is no longer built, so nothing swaps when your camera
-- goes in or out (client/ShopShellView finds no shell and leaves the lodge alone). The lodge keeps its own porch,
-- chimney, window boxes and sign, and is dressed in the cabin's look inside AND out (restyle: round orange-tan logs,
-- red beams, green frames, a red roof). true brings the cabins back.
ShopShell.MODEL = false
-- (10 Nov 15:43, owner on the stud cabin: "de huis is echt kk lelijk", picked "the ForgeGUI house from my photo") the
-- ForgeGUI cabin is back (MODEL true below), and the reasons it read as "2 houses" are fixed: at 54 wide the lodge's
-- roof, barge boards and stone plinth poked out through it, so it's 57 wide and 1.8 further forward now (checked in
-- Studio by casting rays at every lodge part from outside: none is seen), the lodge's roof is cut back inside the
-- cabin's walls anyway, the door box starts at the cabin's door tunnel's mouth (measured: x -2.2..1.8, z -16..-7.5)
-- and invisible walls stand on the cabin's outside so you can't walk into its logs up to the lodge's.
ShopShell.MODEL = true
local ROOF_RED = Color3.fromRGB(176, 58, 42)
local NAME = "toolshop_shell"

-- what of the lodge's outside goes (part names in ShopBuilding)
local GONE: { [string]: boolean } = {}
for _, n in {
	"PorchBase", "PorchBeam", "PorchPost", "Baluster", "Rail", "Doormat", "Corbel", "KneeBrace", "SignBoard", "SignFrame",
	"SignChain", "Lantern", "LanternBar", "LanternBase", "LanternCap", "LanternCore", "LanternGlass", "Post", "PostFoot",
	"Chimney", "ChimneyCap", "ChimneySmoke", "BadgeBlade", "BadgeGrip", "BadgeHandle", "Planter", "Soil", "Flower",
	"Leaves", "Shutter", "ShutterBatten", "ShutterBrace", "SillBracket", "Firewood",
	-- (10 Nov) the lodge's door: the cabin's door tunnel leads straight in (its swing tween would also undo FIT_IN)
	"DoorPlank", "DoorBatten", "DoorStrap", "DoorHandle", "DoorSensor",
} do
	GONE[n] = true
end
local WALK_ON: { [string]: boolean } = { Deck = true, DeckFascia = true, Step = true }

-- How the cabin sits on the lodge (lodge coordinates; checked in Studio, 31 Oct): its middle (its porch steps in
-- front of the lodge's door, its back 10 studs behind the lodge's) and its width (the shape follows, never stretched).
local FIT = { x = -1, y = -0.6, z = 4.5, width = 57 } -- (10 Nov: was z 6.3, width 54)
-- the lodge's room (lodge coordinates): a camera in here sees the lodge, outside it the cabin (client/ShopShellView)
local ROOM_MIN, ROOM_MAX = Vector3.new(-21.4, 0, -9.3), Vector3.new(21.4, 25, 16.4)
-- (31 Oct, owner: "its bugged still when i walk in i see like glitching both") and the doorway in front of the lodge's
-- door, from the cabin's front on: the cabin's door is a tunnel only ~4 studs wide (x -2.2..1.9, roof 12.1, from
-- z -12.4 to -6; measured in Studio) in the lodge's 12-wide door, its insides solid, so a camera in it saw both
local DOOR_MIN, DOOR_MAX = Vector3.new(-6.5, 0, -15.5), Vector3.new(6.5, 14, -9.3) -- (10 Nov: z was -12.6)
-- (10 Nov) the cabin's outside walls at 57 wide (measured in Studio, lodge frame): invisible walls there (ShellWalls)
local OUTER = { left = -29.3, right = 26.3, back = 25.2, front = -15, frontY = 20 }
-- (10 Nov) the shop inside the cabin: x0.88 (the room 39.2 -> 34.5 wide in the cabin's 35.7), its floor up on the
-- cabin's (0.75 -> 2.0), its front wall against the cabin's inside front (z -7.2)
-- (10 Nov 17:27, owner: "house ground is buggy") the cabin's own floor inside is uneven (y 1.93..2.23, measured in
-- Play) and its bottom logs bulge in at the floor (to x 13.8 / -15.5): the shop is x0.78 now (was 0.88) with its floor
-- at 2.35, clear over the cabin's floor, and its walls clear of the bulge (the fireplace and the bench were in it)
local FIT_IN = { on = true, k = 0.78, dy = 1.765, dz = -0.38 }
-- (10 Nov 17:40, owner: "make the house overall bigger") the whole house x SIZE: the cabin, the shop in it, its walls,
-- its door, round the cabin's middle on the ground (FIT x, y, z); every measurement here is for SIZE 1 and goes
-- through grow(). The yard's props in front move out with the porch.
ShopShell.SIZE = 1.15
-- (10 Nov 17:58, owner: "there is a house inside a house, also make the inside bigger") OPEN: no walls or ceiling of
-- our own inside (lineRoom); the cabin's own logs and its roof are the room, and the shop is fitted big into the
-- cabin's whole hollow at SIZE 1.15 (measured in Play, shop frame: its inside x -20.2..20.85, z -9..20.6, its floor
-- up to 2.6, its bottom logs bulging in to y 2.8 at x 16 / y 3.3 at x -18): the boards against its back wall, the
-- coats, notice board and barrel moved up against its front wall (`front`, lodge studs), floor and the runner on to
-- the door, warm lamps under the roof. `k` and `d` are absolute (the shop's scale and where its anchor goes).
ShopShell.OPEN = true
local OPEN_FIT = { k = 0.95, d = Vector3.new(0, 2.0, 5.0), front = -6.9, inside = { -20.2, 20.85, -8.96, 20.6 } }
local FRONT_SET: { [string]: boolean } = {}
for _, n in { "Barrel", "Hoop", "Handle", "RakeHead", "RakeTine", "BroomBind", "BroomStraw", "ShovelBlade" } do
	FRONT_SET[n] = true -- (the barrel of rakes in the front corner)
end
local GROW_C = Vector3.new(-1, -0.6, 4.5)
local function grow(x: number, y: number, z: number): Vector3
	return GROW_C + (Vector3.new(x, y, z) - GROW_C) * ShopShell.SIZE
end

local function strip(shop: Instance, at: CFrame)
	local building = shop:FindFirstChild("ShopBuilding")
	local inv = at:Inverse()
	for _, p in (if building then building:GetDescendants() else {}) do
		if not p:IsA("BasePart") then
			continue
		end
		local rel = inv * p.Position
		-- the porch's roof boards (in front of the lodge's own roof)
		local porchRoof = (p.Name == "Roof" or p.Name == "RoofEdge" or p.Name == "Barge") and rel.Z < -11.2
		if GONE[p.Name] or porchRoof then
			p:Destroy()
		elseif WALK_ON[p.Name] then
			p.Transparency = 1
			p.CastShadow = false
		end
	end
	-- (10 Nov) the lodge's roof stays inside the cabin's walls: its eaves past the walls go, long boards are cut back
	local LIM = 21.7
	for _, p in (if building then building:GetDescendants() else {}) do
		if p:IsA("BasePart") and p.Parent and (p.Name == "Roof" or p.Name == "RoofEdge" or p.Name == "Barge" or p.Name == "RidgeCap" or p.Name == "GableBoard") then
			local rel = inv * p.Position
			local ax = inv:VectorToWorldSpace(p.CFrame.XVector)
			if p.Name ~= "GableBoard" and (rel.Z < -8.6 or rel.Z > 16.9) then
				p:Destroy()
			elseif p.Name == "Barge" or math.abs(ax.X) < 0.9 then
				if math.abs(rel.X) > LIM then
					p:Destroy()
				end
			else
				local half = p.Size.X / 2
				local lo, hi = math.max(rel.X - half, -LIM), math.min(rel.X + half, LIM)
				if hi <= lo + 0.05 then
					p:Destroy()
				elseif lo > rel.X - half + 0.01 or hi < rel.X + half - 0.01 then
					p.Size = Vector3.new(hi - lo, p.Size.Y, p.Size.Z)
					p.CFrame = p.CFrame + at:VectorToWorldSpace(Vector3.new((lo + hi) / 2 - rel.X, 0, 0))
				end
			end
		end
	end
	-- the medallion on the roof (the yard's highest pieces)
	local yard = shop:FindFirstChild("ShopYard")
	for _, p in (if yard then yard:GetDescendants() else {}) do
		if p:IsA("BasePart") and (inv * p.Position).Y > 12 then
			p:Destroy()
		end
	end
end

-- The inside in the cabins' style (both buildings share CampBuildings' part names). Only seen from inside:
-- client/ShopShellView hides the building from outside.
local LOG = Color3.fromRGB(214, 140, 72)
local CHINK = Color3.fromRGB(110, 62, 32)
local BEAM = Color3.fromRGB(168, 58, 40)
local FRAME = Color3.fromRGB(78, 150, 60)
local PLANK = Color3.fromRGB(184, 108, 56)
local LOG_D = 1.62 -- a round log's thickness: a row (1.6) and a hair, so the rows touch
local BEAMS = { Purlin = true, TieBeam = true, RidgeBeam = true, ChandelierBar = true, Barge = true }
local FRAMES = {
	WindowPost = true, Mullion = true, Sill = true, Lintel = true, DoorPost = true, DoorLintel = true, DoorHeader = true,
	VentFrame = true,
}
local CEILING = { Roof = true, RoofEdge = true, RidgeCap = true }

local function wood(p: BasePart, color: Color3, material: Enum.Material)
	p.MaterialVariant = ""
	p.Material = material
	p.Color = color
end

local function roundLog(p: BasePart)
	-- along the square log's longest side
	local s = p.Size
	local turn = if s.X >= s.Y and s.X >= s.Z then CFrame.new()
		elseif s.Y >= s.Z then CFrame.Angles(0, 0, math.pi / 2)
		else CFrame.Angles(0, math.pi / 2, 0)
	local c = Instance.new("Part")
	c.Name = "RoundLog"
	c.Shape = Enum.PartType.Cylinder
	c.Size = Vector3.new(math.max(s.X, s.Y, s.Z), LOG_D, LOG_D)
	c.CFrame = p.CFrame * turn
	wood(c, LOG, Enum.Material.Wood)
	c.Anchored = true
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.TopSurface = Enum.SurfaceType.Smooth
	c.BottomSurface = Enum.SurfaceType.Smooth
	c.Parent = p.Parent
	p.Transparency = 1
end

local function restyle(building: Instance?, outside: boolean?)
	for _, p in (if building then building:GetDescendants() else {}) do
		if not p:IsA("BasePart") then
			continue
		end
		local n = p.Name
		if n == "Log" and p:IsA("Part") and p.Shape == Enum.PartType.Block then
			roundLog(p)
		elseif n == "LogEnd" or n == "GableBoard" then
			wood(p, LOG, Enum.Material.Wood)
		elseif n == "Chink" then
			p.Color = CHINK
		elseif BEAMS[n] then
			wood(p, BEAM, Enum.Material.Wood)
		elseif FRAMES[n] then
			wood(p, FRAME, Enum.Material.Wood)
		elseif n == "DoorPlank" then -- (10 Nov) seen down the cabin's door tunnel: its warm wood, not grey
			wood(p, Color3.fromRGB(158, 96, 52), Enum.Material.WoodPlanks)
		elseif n == "DoorBatten" or n == "DoorStrap" then
			wood(p, Color3.fromRGB(96, 56, 34), Enum.Material.Wood)
		elseif CEILING[n] then
			-- (10 Nov) with no cabin over it the roof is seen from outside too: the cabin's red
			wood(p, if outside then ROOF_RED else PLANK, Enum.Material.WoodPlanks)
		end
	end
end

type Fit = { x: number, y: number, z: number, width: number }
type Box = { Vector3 } -- min, max

-- A shell round `unit` (the shop's or the garage's folder) at `at`, `fit` in that frame; `room` and `door` the boxes
-- (that frame) where a camera sees the building, not the shell. Returns the shell, or nil (and changes nothing) when
-- the model isn't loaded.
local function shell(unit: Instance, at: CFrame, forgeName: string, fit: Fit, room: Box, door: Box): Model?
	if not ShopShell.ON or not Models.has("forge_" .. forgeName) then
		return nil
	end
	-- (the 30 Oct ForgeGUI meshes face their -Z; server/Models turns templates for a -X front, so a quarter turn
	-- back here, and the template's Z is the width: like server/ArenaForge)
	local cf = at * CFrame.new(fit.x, fit.y, fit.z) * CFrame.Angles(0, math.pi / 2, 0)
	local m = Models.placeForge(forgeName, unit, cf, { depth = fit.width }, true)
	if not m then
		return nil
	end
	m.Name = "ShopShell"
	-- (10 Nov) its middle exactly on the fit, whatever the mesh's own pivot (as checked in Studio)
	do
		local bcf, bs = m:GetBoundingBox()
		local c = cf:PointToObjectSpace(bcf.Position)
		m:PivotTo(m:GetPivot() + cf:VectorToWorldSpace(Vector3.new(-c.X, 0, -c.Z)))
		bcf, bs = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(0, cf.Position.Y - (bcf.Position.Y - bs.Y / 2), 0))
	end
	-- (in the building's frame: the unit's "0Anchor", which moves with it when the saved map places it)
	m:SetAttribute("RoomMin", room[1])
	m:SetAttribute("RoomMax", room[2])
	m:SetAttribute("DoorMin", door[1])
	m:SetAttribute("DoorMax", door[2])
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	return m
end

-- The cabin round the lodge at `at` (server/RunBuilder's tool shop). Returns false (and changes nothing) when the
-- model isn't loaded.
-- (10 Nov, owner: "remake de huis helemaal beter naar de foto ... voxel stud style hoge kwaliteit") THE STUD CABIN: the
-- Blender stud-voxel model tool_shop (tools/blender/hub/hub_models.py -> shared/HubBrickData, built by shared/HubBricks)
-- after the ForgeGUI cabin in the owner's photo. Of the voxel lodge only what's inside the room stays (its floor, the
-- tie beams, the chandelier, whatever hangs inside): its walls, roof, porch, windows, door, chimney and lantern posts
-- go, and the yard's medallion on the roof (the cabin has its own). The room (server/ShopRoom) is untouched.
ShopShell.STUD_CABIN = false -- (10 Nov 15:43, owner: "lelijk": back to the ForgeGUI cabin)
local CABIN = "tool_shop"
local LODGE_WALLS: { [string]: boolean } = {}
for _, n in {
	"Log", "RoundLog", "LogEnd", "LogHeart", "LogRing", "Chink", "Plinth", "Roof", "RoofEdge", "RidgeCap", "RidgeBeam",
	"Barge", "GableBoard", "Vent", "VentFrame", "VentSlat", "WindowGlass", "WindowPost", "Mullion", "Sill", "SillBracket",
	"Lintel", "DoorPlank", "DoorBatten", "DoorStrap", "DoorHandle", "DoorPost", "DoorLintel", "Threshold", "Doormat",
} do
	LODGE_WALLS[n] = true
end
local ROOM_IN_MIN, ROOM_IN_MAX = Vector3.new(-19.9, 0.3, -7.7), Vector3.new(19.9, 15.6, 14.9)

-- the voxel lodge gutted: only what's inside its room stays (floor, tie beams, chandelier, what hangs inside)
local function gutLodge(shop: Instance, at: CFrame)
	local inv = at:Inverse()
	local lodge = shop:FindFirstChild("ShopBuilding")
	if lodge then
		for _, d in lodge:GetChildren() do
			if d:IsA("Model") and d.Name == "lantern_post" then
				d:Destroy()
			end
		end
		for _, p in lodge:GetDescendants() do
			if p:IsA("BasePart") and p.Parent then
				local l = inv * p.Position
				local inside = l.X > ROOM_IN_MIN.X and l.X < ROOM_IN_MAX.X and l.Y > ROOM_IN_MIN.Y and l.Y < ROOM_IN_MAX.Y
					and l.Z > ROOM_IN_MIN.Z and l.Z < ROOM_IN_MAX.Z
				local keep = p.Name == "FloorBoard" or p.Name == "FloorFill" -- (its DoorSensor goes too: no door to swing)
				if not keep and (LODGE_WALLS[p.Name] or p.Name == "Purlin" or not inside) then
					p:Destroy()
				end
			end
		end
	end
end

local function studCabin(shop: Instance, at: CFrame): boolean
	local HubBricks = require(ReplicatedStorage.MowALawn.HubBricks) :: any
	if not ShopShell.STUD_CABIN or not HubBricks.has(CABIN) then
		return false
	end
	local inv = at:Inverse()
	gutLodge(shop, at)
	local yard = shop:FindFirstChild("ShopYard")
	for _, p in (if yard then yard:GetDescendants() else {}) do
		if p:IsA("BasePart") and p.Parent and (inv * p.Position).Y > 12 then
			p:Destroy() -- the medallion and its shears on the roof
		end
	end
	local m = HubBricks.build(CABIN, at, shop)
	m.Name = "ShopCabin"
	return true
end

-- (10 Nov 17:06, owner: "remake je het helemaal ook de binnen kant, niet 2 huizen in 1") THE CABIN'S INSIDE: with
-- the lodge gone the shop's room stands in the cabin's bare, dark hollow, so the cabin gets its own inside: warm
-- plank walls right behind the tool boards (the cabin's own logs are just behind them), a plank ceiling over the
-- beams, dark posts in the corners, a skirting board, the beams and the chandelier in the cabin's wood, and warm
-- lamps. Shop frame after FIT_IN (measured in Play): the boards reach x -17.5..18.1 and z 14.3, the floor -5.9..12.9
-- at y 2, the beams' tops at 14.7; the cabin's inside x -17.7..18, z -7.2..18.5; its door tunnel x -2.2..1.8.
-- (17:30, at FIT_IN.k 0.78: the boards reach x -15.5..15.9 and z 12, the floor from z -5.9, the beams' tops 13.6)
local LINE = { left = -15.55, right = 15.9, back = 12.0, front = -6.0, floor = 1.6, top = 14.2, t = 0.4, door = { -2.2, 1.8, 11.4 } }
local LOG_IN = Color3.fromRGB(198, 116, 50) -- the cabin's orange logs
local CHINK_IN = Color3.fromRGB(70, 42, 26)
local POST_IN = Color3.fromRGB(96, 58, 32)
local CEIL_IN = Color3.fromRGB(122, 74, 40)

local function lineRoom(shop: Instance, at: CFrame)
	local S = ShopShell.SIZE
	local lo, hi = grow(LINE.left, LINE.floor, LINE.front), grow(LINE.right, LINE.top, LINE.back)
	local dl, dh = grow(LINE.door[1], LINE.door[3], 0), grow(LINE.door[2], 0, 0)
	local L = { left = lo.X, right = hi.X, front = lo.Z, back = hi.Z, floor = lo.Y, top = hi.Y, t = LINE.t, door = { dl.X, dh.X, dl.Y } }
	local f = Instance.new("Folder")
	f.Name = "CabinInside"
	local rng = Random.new(1110)
	local function piece(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, mat: Enum.Material, solid: boolean)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
		p.CFrame = at * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		local j = rng:NextNumber(-0.06, 0.06)
		p.Color = Color3.new(math.clamp(color.R + j, 0, 1), math.clamp(color.G + j * 0.8, 0, 1), math.clamp(color.B + j * 0.6, 0, 1))
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = solid
		p.CanQuery = solid
		p.CanTouch = false
		p.Parent = f
		return p
	end
	-- a plank wall along x (z fixed) or along z (x fixed), skipping the door's gap
	-- (10 Nov 17:15, owner picked "binnen als de buitenkant") the walls are round logs like the cabin's outside: a
	-- dark backing (the gaps between the logs, and what you bump into), the logs stacked on it, each its own shade
	local D = 1.3 * S -- a log's thickness
	local function log(x0: number, x1: number, y: number, z0: number, z1: number, alongX: boolean)
		local len = if alongX then x1 - x0 else z1 - z0
		local p = Instance.new("Part")
		p.Name = "Log"
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(len, D, D)
		local c = at * CFrame.new((x0 + x1) / 2, y, (z0 + z1) / 2)
		p.CFrame = if alongX then c else c * CFrame.Angles(0, math.pi / 2, 0)
		local j = rng:NextNumber(-0.07, 0.05)
		p.Color = Color3.new(math.clamp(LOG_IN.R + j, 0, 1), math.clamp(LOG_IN.G + j * 0.8, 0, 1), math.clamp(LOG_IN.B + j * 0.5, 0, 1))
		p.Material = Enum.Material.Wood
		p.Parent = f
	end
	-- a log wall along x at the wall face z (the logs bulge into the room by `inward`), with the door's gap
	local function wallX(z: number, inward: number, gap: { number }?)
		local zc = z - inward * 0.35 -- (the logs stand 0.3 into the room: the boards in front stay clear)
		piece("LogBacking", L.left, L.right, L.floor, L.top, zc - 0.3, zc + 0.3, CHINK_IN, Enum.Material.Wood, true)
		local y = L.floor + D / 2
		while y < L.top do
			if gap and y < gap[3] then
				log(L.left, gap[1], y, zc, zc, true)
				log(gap[2], L.right, y, zc, zc, true)
			else
				log(L.left, L.right, y, zc, zc, true)
			end
			y += D * 0.92
		end
	end
	local function wallZ(x: number, inward: number)
		local xc = x - inward * 0.35
		piece("LogBacking", xc - 0.3, xc + 0.3, L.floor, L.top, L.front, L.back, CHINK_IN, Enum.Material.Wood, true)
		local y = L.floor + D / 2 + D * 0.46 -- (half a log up from the walls along x, like a real cabin's corners)
		while y < L.top do
			log(xc, xc, y, L.front, L.back, false)
			y += D * 0.92
		end
	end
	-- the backing behind the front logs has the door's hole: two slabs and one over the top
	local gap = { L.door[1] - 1.6, L.door[2] + 1.0, L.door[3] }
	wallX(L.back, -1, nil) -- (inward: -1 the room is at -z, +1 at +z / +x)
	local fz = L.front - 0.35
	piece("LogBacking", L.left, gap[1], L.floor, L.top, fz - 0.3, fz + 0.3, CHINK_IN, Enum.Material.Wood, true)
	piece("LogBacking", gap[2], L.right, L.floor, L.top, fz - 0.3, fz + 0.3, CHINK_IN, Enum.Material.Wood, true)
	piece("LogBacking", gap[1], gap[2], gap[3], L.top, fz - 0.3, fz + 0.3, CHINK_IN, Enum.Material.Wood, true)
	do
		local zc = fz
		local y = L.floor + D / 2
		while y < L.top do
			if y < gap[3] + D / 2 then
				log(L.left, gap[1], y, zc, zc, true)
				log(gap[2], L.right, y, zc, zc, true)
			else
				log(L.left, L.right, y, zc, zc, true)
			end
			y += D * 0.92
		end
	end
	wallZ(L.left, 1)
	wallZ(L.right, -1)
	-- the door's frame, posts in the corners, the skirting and the top rail
	piece("DoorPost", L.door[1] - 1.6, L.door[1] - 0.1, L.floor, L.door[3], L.front - 0.5, L.front + 0.35, POST_IN, Enum.Material.Wood, true)
	piece("DoorPost", L.door[2] + 0.1, L.door[2] + 1.0, L.floor, L.door[3], L.front - 0.5, L.front + 0.35, POST_IN, Enum.Material.Wood, true)
	piece("DoorLintel", L.door[1] - 1.6, L.door[2] + 1.0, L.door[3], L.door[3] + 0.8, L.front - 0.1, L.front + 0.35, POST_IN, Enum.Material.Wood, false)
	-- (17:45, "better quality") the corners notched like a log cabin's: the log ends cross, every other one sticking
	-- out a little, a lighter cut face on each end
	for _, c in { { L.left, L.front, 1, 1 }, { L.right, L.front, -1, 1 }, { L.left, L.back, 1, -1 }, { L.right, L.back, -1, -1 } } do
		local y = L.floor + D / 2
		local n = 0
		while y < L.top do
			local alongX = n % 2 == 0
			local len = D * 1.6
			local e = Instance.new("Part")
			e.Name = "LogEnd"
			e.Shape = Enum.PartType.Cylinder
			e.Anchored = true
			e.CanCollide = false
			e.CanQuery = false
			e.CanTouch = false
			e.Size = Vector3.new(len, D * 1.04, D * 1.04)
			local cx = c[1] + (if alongX then c[3] * len * 0.3 else -c[3] * 0.1)
			local cz = c[2] + (if alongX then -c[4] * 0.1 else c[4] * len * 0.3)
			local cf = at * CFrame.new(cx, y, cz)
			e.CFrame = if alongX then cf else cf * CFrame.Angles(0, math.pi / 2, 0)
			local j = rng:NextNumber(-0.05, 0.04)
			e.Color = Color3.new(LOG_IN.R + j, LOG_IN.G + j * 0.8, LOG_IN.B + j * 0.5)
			e.Material = Enum.Material.Wood
			e.Parent = f
			y += D * 0.92
			n += 1
		end
	end
	for _, side in { L.left, L.right } do
		local x0 = if side < 0 then side else side - 0.6
		piece("WallPlate", x0, x0 + 0.6, L.top - 0.7, L.top, L.front, L.back, POST_IN, Enum.Material.Wood, false)
	end
	-- a stone plinth along the sides' feet, like the cabin's outside: it covers where the cabin's bottom logs bulge in
	-- (17:45, x1.15: the bulge measured in Play reaches y 3.7 at x 17, 3.3 at x -18) in blocks of stone, each its own
	-- grey, with a capstone on top
	local function plinth(x0: number, x1: number, top: number)
		local z = L.front
		while z < L.back - 0.01 do
			local w = math.min(rng:NextNumber(1.6, 2.6), L.back - z)
			piece("PlinthStone", x0, x1, L.floor, top - 0.25, z, z + w - 0.08, Color3.fromRGB(104, 108, 118), Enum.Material.Slate, true)
			z += w
		end
		piece("PlinthCap", x0 - 0.1, x1 + 0.1, top - 0.3, top, L.front, L.back, Color3.fromRGB(132, 134, 140), Enum.Material.Slate, true)
	end
	plinth(L.right - 1.6 * S, L.right, 5.2)
	plinth(L.left, L.left + 0.8 * S, 3.4)
	-- iron lanterns on the side walls, lit
	for _, x in { L.left, L.right } do
		local inward = if x < 0 then 1 else -1
		for _, zz in { L.front + (L.back - L.front) * 0.3, L.front + (L.back - L.front) * 0.62 } do
			local wx = x + inward * 0.35
			piece("SconceBack", wx - 0.15, wx + 0.15, 8.6, 10.2, zz - 0.45, zz + 0.45, POST_IN, Enum.Material.Wood, false)
			local ax = wx + inward * 0.55
			piece("SconceArm", math.min(wx, ax), math.max(wx, ax), 9.7, 9.9, zz - 0.08, zz + 0.08, Color3.fromRGB(46, 42, 40), Enum.Material.Metal, false)
			local lx = wx + inward * 0.9
			piece("SconceCap", lx - 0.45, lx + 0.45, 9.6, 9.85, zz - 0.45, zz + 0.45, Color3.fromRGB(46, 42, 40), Enum.Material.Metal, false)
			local glass = piece("SconceGlass", lx - 0.33, lx + 0.33, 8.5, 9.6, zz - 0.33, zz + 0.33, Color3.fromRGB(255, 196, 110), Enum.Material.Neon, false)
			glass.CastShadow = false
			piece("SconceBase", lx - 0.42, lx + 0.42, 8.35, 8.5, zz - 0.42, zz + 0.42, Color3.fromRGB(46, 42, 40), Enum.Material.Metal, false)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 186, 110)
			light.Brightness = 0.6
			light.Range = 12
			light.Parent = glass
		end
	end
	-- the ceiling: boards across, on joists
	local z = L.front - L.t
	while z < L.back + L.t - 0.01 do
		local w = math.min(1.8, L.back + L.t - z)
		piece("CeilingBoard", L.left - L.t, L.right + L.t, L.top, L.top + 0.3, z, z + w - 0.05, CEIL_IN, Enum.Material.WoodPlanks, false)
		z += w
	end
	for i = 0, 3 do
		local zz = L.front + 1.5 + i * (L.back - L.front - 3) / 3
		piece("Joist", L.left, L.right, L.top - 0.6, L.top, zz - 0.35, zz + 0.35, POST_IN, Enum.Material.Wood, false)
	end
	-- warm lamps under the ceiling (the room was lit by the fire alone: dark red)
	for _, x in { grow(-7.5, 0, 0).X, grow(7.5, 0, 0).X } do
		for _, zz in { grow(0, 0, 0).Z, grow(0, 0, 7).Z } do
			local holder = piece("CeilingLamp", x - 0.6, x + 0.6, L.top - 0.9, L.top - 0.6, zz - 0.6, zz + 0.6, Color3.fromRGB(255, 186, 104), Enum.Material.Neon, false)
			holder.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 196, 130)
			light.Brightness = 0.8
			light.Range = 18
			light.Shadows = false
			light.Parent = holder
		end
	end
	f.Parent = shop
	-- the lodge's leftovers in the cabin's wood (its beams came out roof-red)
	local lodge = shop:FindFirstChild("ShopBuilding")
	for _, p in (if lodge then lodge:GetDescendants() else {}) do
		if p:IsA("BasePart") and (p.Name == "TieBeam" or p.Name == "ChandelierBar") then
			p.Color = POST_IN
			p.Material = Enum.Material.Wood
		end
	end
end

local function openRoom(shop: Instance, at: CFrame, floorY: number, k: number, d: Vector3)
	local f = Instance.new("Folder")
	f.Name = "CabinInside"
	local I = OPEN_FIT.inside
	local function piece(name: string, cf: CFrame, size: Vector3, like: BasePart?, color: Color3, mat: Enum.Material, solid: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = at * cf
		p.Color = if like then like.Color else color
		p.Material = if like then like.Material else mat
		if like then
			p.MaterialVariant = like.MaterialVariant
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = solid
		p.CanQuery = solid
		p.CanTouch = false
		p.Parent = f
		return p
	end
	-- the floor on to the door and to the back wall, in the lodge's own floor boards' look
	local lodge = shop:FindFirstChild("ShopBuilding")
	local like = lodge and lodge:FindFirstChild("FloorBoard", true) :: BasePart?
	local front, back = -7.125 * k + d.Z, 14.24 * k + d.Z
	local rng = Random.new(1758)
	for _, span in { { I[3], front }, { back, I[4] } } do
		local z = span[1]
		while z < span[2] - 0.01 do
			local w = math.min(1.5, span[2] - z)
			local b = piece("FloorBoard", CFrame.new(0, floorY - 0.2, z + w / 2), Vector3.new(37, 0.4, w - 0.05), like, Color3.fromRGB(153, 117, 85), Enum.Material.WoodPlanks, true)
			local j = rng:NextNumber(-0.03, 0.03)
			b.Color = Color3.new(math.clamp(b.Color.R + j, 0, 1), math.clamp(b.Color.G + j, 0, 1), math.clamp(b.Color.B + j, 0, 1))
			z += w
		end
	end
	-- the runner on from the door to where it starts
	local runStart = -6.6 * k + d.Z
	local runLen = runStart - I[3]
	piece("Runner", CFrame.new(0, floorY + 0.03, I[3] + runLen / 2), Vector3.new(4.6 * k, 0.06, runLen), nil, Color3.fromRGB(150, 44, 40), Enum.Material.Fabric, false)
	for _, sx in { -1, 1 } do
		piece("RunnerBorder", CFrame.new(sx * 1.95 * k, floorY + 0.05, I[3] + runLen / 2 + 0.2), Vector3.new(0.3 * k, 0.06, runLen - 0.4), nil, Color3.fromRGB(234, 182, 58), Enum.Material.Fabric, false)
	end
	-- warm lamps under the roof (unseen: the light falls on the cabin's own logs)
	for _, x in { -9, 9 } do
		for _, z in { 0, 8, 16 } do
			local h = piece("RoomLight", CFrame.new(x, 13.5, z), Vector3.new(0.4, 0.4, 0.4), nil, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
			h.Transparency = 1
			h.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 212, 158)
			light.Brightness = 0.9
			light.Range = 22
			light.Shadows = false
			light.Parent = h
		end
	end
	f.Parent = shop
	for _, p in (if lodge then lodge:GetDescendants() else {}) do
		if p:IsA("BasePart") and (p.Name == "TieBeam" or p.Name == "ChandelierBar") then
			p.Color = POST_IN
			p.Material = Enum.Material.Wood
		end
	end
end

-- the yard's props round the porch (server/ShopRoom outside: the two picket fences, the gnome, the watering can, the
-- mailbox, the wheelbarrow, the bundles) move out with the bigger cabin, each group by its own spot
local YARD_SPOTS = { { 9.6, -17.7 }, { -9.6, -17.7 }, { -7.4, -19.2 }, { -8.9, -19.5 }, { 7.6, -19.4 }, { 18.6, -13.4 }, { -16.8, -10.6 } }
local function moveYard(shop: Instance, at: CFrame)
	local yard = shop:FindFirstChild("ShopYard")
	if ShopShell.SIZE == 1 or not yard then
		return
	end
	local inv = at:Inverse()
	for _, p in yard:GetDescendants() do
		if p:IsA("BasePart") then
			local l = inv * p.Position
			local best, bd = YARD_SPOTS[1], math.huge
			for _, sp in YARD_SPOTS do
				local dd = (l.X - sp[1]) ^ 2 + (l.Z - sp[2]) ^ 2
				if dd < bd then
					best, bd = sp, dd
				end
			end
			local g = grow(best[1], 0, best[2])
			p.CFrame = at * CFrame.new(g.X - best[1], 0, g.Z - best[2]) * (inv * p.CFrame)
		end
	end
end

function ShopShell.dress(shop: Instance, at: CFrame): boolean
	if not ShopShell.MODEL then
		if not studCabin(shop, at) then
			restyle(shop:FindFirstChild("ShopBuilding"), true)
		end
		return true
	end
	local fit = { x = FIT.x, y = FIT.y, z = FIT.z, width = FIT.width * ShopShell.SIZE }
	local m = shell(shop, at, NAME, fit, { ROOM_MIN, ROOM_MAX }, { DOOR_MIN, DOOR_MAX })
	if not m then
		return false
	end
	strip(shop, at)
	moveYard(shop, at)
	-- (10 Nov 17:01, owner: "remove the house inside the house") the lodge's log walls, roof and windows go: inside
	-- you see the cabin's own walls round the shop's room (tool boards, counter, fireplace, rugs)
	if FIT_IN.on then
		gutLodge(shop, at)
	end
	restyle(shop:FindFirstChild("ShopBuilding"))
	-- (10 Nov) invisible walls on the cabin's outside (it has no collisions; the lodge's walls are 4-7 studs inside it)
	local walls = Instance.new("Folder")
	walls.Name = "ShellWalls"
	local function wall(x0: number, x1: number, z0: number, z1: number)
		local p = Instance.new("Part")
		p.Name = "ShellWall"
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		local a0, a1 = grow(x0, 0, z0), grow(x1, OUTER.frontY, z1)
		p.Size = Vector3.new(a1.X - a0.X, OUTER.frontY * ShopShell.SIZE, a1.Z - a0.Z)
		p.CFrame = at * CFrame.new((a0.X + a1.X) / 2, OUTER.frontY * ShopShell.SIZE / 2, (a0.Z + a1.Z) / 2)
		p.Parent = walls
	end
	wall(OUTER.left, -22.2, -8.6, OUTER.back) -- left (the chimney side)
	wall(22.2, OUTER.right, -8.6, OUTER.back) -- right
	wall(-22.2, 22.2, 16.9, OUTER.back) -- back
	wall(OUTER.left + 5, DOOR_MIN.X - 1.4, OUTER.front, -7.3) -- front, left of the porch
	wall(DOOR_MAX.X + 1.4, OUTER.right, OUTER.front, -7.3) -- front, right of the porch
	wall(DOOR_MIN.X - 1.4, -2.2, OUTER.front - 1, -7.3) -- either side of the door tunnel (x -2.2..1.8)
	wall(1.8, DOOR_MAX.X + 1.4, OUTER.front - 1, -7.3)
	if FIT_IN.on and ShopShell.OPEN then -- (open: in front of the cabin's bulging bottom logs: x -18 / 17 at x1.15)
		wall(-22.2, -15.8, -8.6, 16.9)
		wall(14.65, 22.2, -8.6, 16.9)
	elseif FIT_IN.on then -- the lodge's side walls are gone: the cabin's inside walls (x -17.7..18; back and front above)
		wall(-22.2, -17.7, -8.6, 16.9)
		wall(18, 22.2, -8.6, 16.9)
	end
	walls.Parent = shop
	-- (10 Nov 16:42, owner: "de huis is weer bugged er zijn 2 huizen in 1") ONE HOUSE, inside and out: the whole shop
	-- (the lodge, its room, the tool boards, the counter spot) is scaled by FIT_IN.k round the anchor and moved into the
	-- cabin's own hollow inside (measured in Studio, lodge frame: x -17.7..18, z -7.2..18.5, floor 1.9, ceiling 31), so
	-- the cabin always shows and nothing swaps at the door (client/ShopShellView leaves the Tool Shop alone now).
	if FIT_IN.on then
		local box = Instance.new("Model")
		box.Name = "FitIn"
		local moved = {}
		for _, c in shop:GetChildren() do
			if c ~= m and c ~= walls and c.Name ~= "0Anchor" and c.Name ~= "ShopYard" then
				table.insert(moved, c)
				c.Parent = box
			end
		end
		box.WorldPivot = at
		box.Parent = shop
		local S = ShopShell.SIZE
		local k = FIT_IN.k * S
		local d = Vector3.new(0, FIT_IN.dy, FIT_IN.dz) * S + GROW_C * (1 - S)
		if ShopShell.OPEN then
			k, d = OPEN_FIT.k, OPEN_FIT.d
			-- the things on the front wall and the barrel in the front corner go to the cabin's front wall
			local inv = at:Inverse()
			local room = shop:FindFirstChild("ShopRoom")
			for _, p in (if room then room:GetDescendants() else {}) do
				if p:IsA("BasePart") and p.Name ~= "Runner" and p.Name ~= "RunnerBorder" and ((inv * p.Position).Z < -5.2 or FRONT_SET[p.Name]) then
					p.CFrame = at * CFrame.new(0, 0, OPEN_FIT.front) * (inv * p.CFrame)
				end
			end
		end
		box:ScaleTo(k)
		box:PivotTo(at * CFrame.new(d))
		for _, c in moved do
			c.Parent = shop
		end
		box:Destroy()
		shop:SetAttribute("FitIn", true)
		local floorY = 0.75 * k + d.Y
		if ShopShell.OPEN then
			openRoom(shop, at, floorY, k, d)
		else
			lineRoom(shop, at)
		end
		-- the lodge's invisible porch (deck, steps) came out of the scaling too high to step on (a 2.9-stud step):
		-- instead an invisible ramp up the cabin's porch steps and a floor through its door tunnel to the shop's floor
		local lodge = shop:FindFirstChild("ShopBuilding")
		for _, p in (if lodge then lodge:GetDescendants() else {}) do
			if p:IsA("BasePart") and WALK_ON[p.Name] then
				p:Destroy()
			end
		end
		local ramp = Instance.new("WedgePart")
		ramp.Name = "DoorRamp"
		local rz = grow(-0.2, 0, -16.5)
		ramp.Size = Vector3.new(4.4 * S, floorY, 4 * S)
		ramp.CFrame = at * CFrame.new(rz.X, floorY / 2, rz.Z) -- (a wedge is low at its -Z end, out of the door, high at +Z)
		local deck = Instance.new("Part")
		deck.Name = "DoorFloor"
		local z0, z1 = grow(-0.2, 0, -14.5), grow(0, 0, -5.9)
		if ShopShell.OPEN then
			z1 = Vector3.new(0, 0, -7.125 * k + d.Z + 0.5)
		end
		deck.Size = Vector3.new(4.4 * S, 1, z1.Z - z0.Z)
		deck.CFrame = at * CFrame.new(z0.X, floorY - 0.5, (z0.Z + z1.Z) / 2)
		for _, q in { ramp, deck } :: { BasePart } do
			q.Anchored = true
			q.Transparency = 1
			q.CanCollide = true
			q.CanQuery = false
			q.CanTouch = false
			q.CastShadow = false
			q.Parent = walls
		end
	end
	return true
end

-------------------------------------------------------------------------------------------------------------
-- the Garage
-------------------------------------------------------------------------------------------------------------
-- Garage coordinates (server/CampBuildings GARAGE): y 0 the ground, -Z out of the roll-up door, the walls x -10..10,
-- z -9..10, the roof up to y 22.5. The ForgeGUI garage (front fully open) stands 23.5 wide with its front 1.6 in
-- front of the voxel garage's (its log walls just outside the voxel ones; the pump at x 13.6 stays clear; checked in
-- Studio, 31 Oct).
local GARAGE_NAME = "garage_shell"
local GARAGE_FIT = { x = 0, y = -0.6, z = 2.92, width = 23.5 }
local GARAGE_ROOM = { Vector3.new(-9.3, 0, -8.3), Vector3.new(9.3, 22, 9.3) }
-- (the roll-up door's opening, x -7.4..7.4, through the ForgeGUI garage's front posts at x +-6 and z -9..-10.6)
local GARAGE_DOOR = { Vector3.new(-7.4, 0, -10.8), Vector3.new(7.4, 11, -8.3) }
-- the voxel garage's outside bits (the ForgeGUI garage has its own; hidden they'd be things to bump into): the GARAGE
-- board, the door's corbels, the window boxes and shutters, the oil drum, the crate and the tyre leaning outside
local GARAGE_GONE: { [string]: boolean } = {}
for _, n in {
	"SignBoard", "SignBracket", "SignFrame", "Corbel", "Planter", "Soil", "Flower", "Leaves", "Shutter", "ShutterBatten",
	"ShutterBrace", "SillBracket", "OilDrum", "Crate", "CrateBand", "CrateBrace",
} do
	GARAGE_GONE[n] = true
end

-- The ForgeGUI garage round the voxel garage at `at` (server/RunBuilder's garageShed).
function ShopShell.dressGarage(garage: Instance, at: CFrame): boolean
	if not ShopShell.MODEL then
		restyle(garage:FindFirstChild("GarageBuilding"), true)
		return true
	end
	if not shell(garage, at, GARAGE_NAME, GARAGE_FIT, GARAGE_ROOM, GARAGE_DOOR) then
		return false
	end
	local building = garage:FindFirstChild("GarageBuilding")
	local inv = at:Inverse()
	for _, p in (if building then building:GetDescendants() else {}) do
		if p:IsA("BasePart") and (GARAGE_GONE[p.Name] or ((p.Name == "Tyre" or p.Name == "TyreHub") and math.abs((inv * p.Position).X) > 10)) then
			p:Destroy()
		end
	end
	restyle(building)
	return true
end

return ShopShell
