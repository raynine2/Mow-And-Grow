-- The Golden Gnome hunt's gnomes (Config.GNOMES): the golden gnome (shared/PartModels/pet_goldengnome) with its hat
-- in the area's colour, or the all-ice Diamond Gnome. The server stands them in the grass (server/Gnomes); the
-- client draws them in the Index window and the "found" banner (client/GnomeHunt).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local PartBuild = require(script.Parent:WaitForChild("PartBuild"))

local GnomeLook = {}

-- the model's parts are named after their materials (tools/blender/to_parts.py)
local HAT = "Foil__FFE482"
local POMPOM = "Neon__FFF096"
local DIAMOND = {
	Foil__C88C1E = Color3.fromRGB(120, 200, 235), -- boots
	Foil__FFC832 = Color3.fromRGB(175, 232, 255), -- coat and arms
	Foil__FFE482 = Color3.fromRGB(232, 250, 255), -- hat
	Neon__FFF096 = Color3.fromRGB(150, 236, 255), -- pompom
}

-- A fresh gnome model for Config.GNOMES id `id` (anchored, no collisions, pivot at its feet, ~3.3 studs tall).
function GnomeLook.build(id: string): Model?
	local def = Config.gnome(id)
	local m = PartBuild.get("pet_goldengnome")
	if not def or not m then
		return nil
	end
	m.Name = def.name
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if def.diamond then
				local c = DIAMOND[p.Name]
				if c then
					p.Color = c
					p.Reflectance = 0.35
				end
			elseif p.Name == HAT then
				p.Color = def.hat
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0
			elseif p.Name == POMPOM then
				p.Color = def.hat:Lerp(Color3.new(1, 1, 1), 0.55)
			end
		end
	end
	return m
end

return GnomeLook
