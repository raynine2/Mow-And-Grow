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
local Models = require(script.Parent.Models)

local ShopShell = {}

ShopShell.ON = true
local NAME = "toolshop_shell"

-- what of the lodge's outside goes (part names in ShopBuilding)
local GONE: { [string]: boolean } = {}
for _, n in {
	"PorchBase", "PorchBeam", "PorchPost", "Baluster", "Rail", "Doormat", "Corbel", "KneeBrace", "SignBoard", "SignFrame",
	"SignChain", "Lantern", "LanternBar", "LanternBase", "LanternCap", "LanternCore", "LanternGlass", "Post", "PostFoot",
	"Chimney", "ChimneyCap", "ChimneySmoke", "BadgeBlade", "BadgeGrip", "BadgeHandle", "Planter", "Soil", "Flower",
	"Leaves", "Shutter", "ShutterBatten", "ShutterBrace", "SillBracket", "Firewood",
} do
	GONE[n] = true
end
local WALK_ON: { [string]: boolean } = { Deck = true, DeckFascia = true, Step = true }

-- How the cabin sits on the lodge (lodge coordinates; checked in Studio, 31 Oct): its middle (its porch steps in
-- front of the lodge's door, its back 10 studs behind the lodge's) and its width (the shape follows, never stretched).
local FIT = { x = -1, y = -0.6, z = 6.3, width = 54 }
-- the lodge's room (lodge coordinates): a camera in here sees the lodge, outside it the cabin (client/ShopShellView)
local ROOM_MIN, ROOM_MAX = Vector3.new(-21.4, 0, -9.3), Vector3.new(21.4, 25, 16.4)

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

local function restyle(building: Instance?)
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
		elseif CEILING[n] then
			wood(p, PLANK, Enum.Material.WoodPlanks)
		end
	end
end

-- A shell round `unit` (the shop's or the garage's folder) at `at`, `fit` in that frame. Returns the shell, or nil
-- (and changes nothing) when the model isn't loaded.
local function shell(unit: Instance, at: CFrame, forgeName: string, fit: { x: number, y: number, z: number, width: number }, roomMin: Vector3, roomMax: Vector3): Model?
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
	-- (in the building's frame: the unit's "0Anchor", which moves with it when the saved map places it)
	m:SetAttribute("RoomMin", roomMin)
	m:SetAttribute("RoomMax", roomMax)
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
function ShopShell.dress(shop: Instance, at: CFrame): boolean
	if not shell(shop, at, NAME, FIT, ROOM_MIN, ROOM_MAX) then
		return false
	end
	strip(shop, at)
	restyle(shop:FindFirstChild("ShopBuilding"))
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
local GARAGE_MIN, GARAGE_MAX = Vector3.new(-9.3, 0, -8.3), Vector3.new(9.3, 22, 9.3)
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
	if not shell(garage, at, GARAGE_NAME, GARAGE_FIT, GARAGE_MIN, GARAGE_MAX) then
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
