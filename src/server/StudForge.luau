--!strict
-- STUD FORGE (7 Nov 2026; owner: "Probeer de forgegui dingen in stud style maar ... laat het eerst zien", then for each
-- one he OKs: "Top, zet hem erin en doe de rest", "Yes"). Swaps the ForgeGUI meshes in a world for their studded-brick
-- builds, each on its own switch in Config.STUD_FORGE:
--   windmill  forge_windmill (and the filler "Core" beside it)        -> server/StudWindmill
--   house     forge_house_blue / forge_house_red (and "HouseCore")    -> server/StudHouse
--   fountain  forge_fountain (the one by the lobby's spawn)            -> server/StudFountain
--   isles     forge_lm_<kind> (the landmarks on the lobby's isles)     -> server/StudIsles
-- The mesh stays in the world, out of sight and out of the way (its pivot is where the build goes). The maps saved in
-- the place are untouched: this runs on the server's copy (server/Lobby.start).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config) :: any

local StudForge = {}

local function hide(inst: Instance?)
	if not inst then
		return
	end
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
end

local function on(key: string): boolean
	local sf = Config.STUD_FORGE
	return type(sf) == "table" and sf[key] == true
end

-- Returns how many models it swapped.
function StudForge.apply(world: Instance): number
	local n = 0
	local list = {}
	for _, d in world:GetDescendants() do
		if d:IsA("Model") and string.sub(d.Name, 1, 6) == "forge_" then
			table.insert(list, d)
		end
	end
	for _, m in list do
		local holder = m.Parent
		if not holder then
			continue
		end
		local ok, err = pcall(function()
			if m.Name == "forge_windmill" and on("windmill") then
				hide(m)
				hide(holder:FindFirstChild("Core"))
				require(script.Parent.StudWindmill).build(holder, m:GetPivot())
				n += 1
			elseif string.sub(m.Name, 1, 9) == "forge_lm_" and on("isles") and require(script.Parent.StudIsles).has(string.sub(m.Name, 10)) then
				hide(m)
				require(script.Parent.StudIsles).build(string.sub(m.Name, 10), holder, m:GetPivot())
				n += 1
			elseif m.Name == "forge_fountain" and on("fountain") then
				hide(m)
				require(script.Parent.StudFountain).build(holder, m:GetPivot())
				n += 1
			elseif (m.Name == "forge_house_blue" or m.Name == "forge_house_red") and on("house") then
				hide(m)
				for _, c in holder:GetChildren() do
					if c.Name == "HouseCore" then
						hide(c)
					end
				end
				require(script.Parent.StudHouse).build(holder, m:GetPivot(), if m.Name == "forge_house_red" then "red" else "blue")
				n += 1
			end
		end)
		if not ok then
			warn(("[StudForge] %s: %s"):format(m:GetFullName(), tostring(err)))
		end
	end
	return n
end

return StudForge
