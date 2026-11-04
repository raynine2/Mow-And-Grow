--!strict
-- THE STARTING CAMP ON GRASS (owner, 4 Nov, standing in the camp: "the main lobby that ur standing in feels so ass and
-- looks ass idk the bricks and the random lanterns and plants ... remove it or wtf"). In the run's copy of the world
-- (server/RunWorld.build, before server/WalkPlates lays its plates), the camp's golden brick paving (Hub.CampTiles: 0.3-
-- stud stones on 8 x 8 bed blocks) loses its stones and its beds become the meadow's grass floor: the Grass material in
-- the area's two ground greens by terrace height and a lighter or darker square here and there, like server/WorldGen and
-- WorldArt lay the rest of Sunny Meadow. The camp's loose lantern posts (Hub.CampDecor) go too; the buildings keep their
-- own lamps. The flower beds, lantern ring and bunting were server/HubSquare (now off). Studio's saved world is
-- untouched: CampGround.ON = false brings the paving back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.MowALawn.Zones)

local CampGround = {}

CampGround.ON = true

local function hash(x: number, z: number, seed: number): number
	local n = math.sin(x * 12.9898 + z * 78.233 + seed * 37.719) * 43758.5453
	return n - math.floor(n)
end

-- Returns how many beds became grass.
function CampGround.apply(w: Instance): number
	if not CampGround.ON then
		return 0
	end
	local hub = w:FindFirstChild("Hub")
	local tiles = hub and hub:FindFirstChild("CampTiles")
	if not hub or not tiles then
		return 0
	end
	local pal = (Zones.region(1) :: any).palette -- Sunny Meadow's
	local light: Color3 = pal.ground
	local dark: Color3 = pal.ground2
	local step: number = Zones.STEP
	local n = 0
	for _, p in tiles:GetDescendants() do
		if not p:IsA("BasePart") then
			continue
		end
		if p.Name == "Bed" then
			local top = math.floor(p.Position.Y + p.Size.Y / 2 + 0.5)
			local base = if (top // step) % 2 == 0 then light else dark
			local cx, cz = math.floor(p.Position.X / 8), math.floor(p.Position.Z / 8)
			local r = hash(cx, cz, 12)
			if r < 0.1 then
				base = base:Lerp(Color3.new(1, 1, 1), 0.06)
			elseif r < 0.2 then
				base = base:Lerp(Color3.new(0, 0, 0), 0.08)
			end
			p.Material = Enum.Material.Grass
			p.MaterialVariant = ""
			p.Color = base
			n += 1
		else
			p:Destroy() -- a stone of the paving
		end
	end
	local decor = hub:FindFirstChild("CampDecor")
	for _, d in (if decor then decor:GetChildren() else {}) do
		if d.Name == "lantern_post" then
			d:Destroy()
		end
	end
	return n
end

return CampGround
