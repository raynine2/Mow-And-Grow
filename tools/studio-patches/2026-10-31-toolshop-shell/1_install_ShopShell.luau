-- Installs ShopShell (git's exact text, 4521 1662645359) into game.ServerScriptService.MowALawn. Run in Edit mode.
local src = [======[
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

-- The cabin round the lodge at `at` (server/RunBuilder's tool shop). Returns false (and changes nothing) when the
-- model isn't loaded.
function ShopShell.dress(shop: Instance, at: CFrame): boolean
	if not ShopShell.ON or not Models.has("forge_" .. NAME) then
		return false
	end
	-- (the 30 Oct ForgeGUI meshes face their -Z; server/Models turns templates for a -X front, so a quarter turn
	-- back here, and the template's Z is the width: like server/ArenaForge)
	local cf = at * CFrame.new(FIT.x, FIT.y, FIT.z) * CFrame.Angles(0, math.pi / 2, 0)
	local m = Models.placeForge(NAME, shop, cf, { depth = FIT.width }, true)
	if not m then
		return false
	end
	m.Name = "ShopShell"
	-- (in the lodge's frame: the shop's "0Anchor", which moves with the shop when the saved map places it)
	m:SetAttribute("RoomMin", ROOM_MIN)
	m:SetAttribute("RoomMax", ROOM_MAX)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	strip(shop, at)
	return true
end

return ShopShell
]======]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "4521 1662645359" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.ServerScriptService.MowALawn
local old = folder:FindFirstChild("ShopShell")
if old then
	local now = hashOf(old.Source)
	if now == "4521 1662645359" then
		return "ShopShell is already this version: " .. now
	end
	local known = { ["4447 1630140148"] = true }
	if not known[now] then
		return "NOT CHANGED: ShopShell is there but is " .. now .. " (not a version this replaces)"
	end
	old.Source = src
	return "ShopShell updated: " .. hashOf(old.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "ShopShell"
m.Source = src
m.Parent = folder
return "ShopShell installed: " .. hashOf(m.Source)
