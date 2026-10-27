-- STUDIO, EDIT MODE: paste into the command bar (or run through the Studio MCP) after the scripts are synced.
-- Puts the voxel Tool Shop and Garage (server/CampBuildings) into the run world saved in the place
-- (Workspace.World.Hub["TOOL SHOP"] and .Garage), where the saved pieces stand, so Edit mode shows what a run
-- shows. A run builds them fresh anyway; this is only for the view in Studio. Only the old Blender building and its
-- colliders, lamp, sign and lantern are taken out; the tool displays, prompts and the gas pump stay. A full copy of
-- each piece goes to ServerStorage.MowALawnBackups first.
-- Not part of the game (tools/ isn't synced by Rojo).
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode only")
local SS = game:GetService("ServerStorage")
local hub = workspace.World.Hub
local root = SS:FindFirstChild("MowALawnBackups") or Instance.new("Folder", SS)
root.Name = "MowALawnBackups"
local bk = Instance.new("Folder")
bk.Name = "Before voxel camp buildings " .. os.date("%Y-%m-%d %H.%M")
bk.Parent = root
local OLD = {
	["TOOL SHOP"] = { log_cabin = true, Collider = true, CabinLamp = true, lantern_post = true, CabinSign = true },
	Garage = { garage_shed = true, Collider = true, LampGlow = true, SignText = true },
}
-- (a fresh copy of the modules: the command bar keeps old requires)
local tmp = game.ServerScriptService.MowALawn:Clone()
tmp.Parent = SS
local ok, err = pcall(function()
	require(tmp.Models).loadAll(30)
	local CB = require(tmp.CampBuildings)
	for name, old in OLD do
		local unit = hub:FindFirstChild(name)
		local anchor = unit and unit:FindFirstChild("0Anchor")
		assert(anchor and anchor:IsA("BasePart"), "no saved " .. name .. " piece with a 0Anchor")
		if unit:FindFirstChild("DoorSensor") then
			continue -- already done
		end
		unit:Clone().Parent = bk
		for _, c in unit:GetChildren() do
			if old[c.Name] then
				c:Destroy()
			end
		end
		if name == "TOOL SHOP" then
			CB.shop(unit, anchor.CFrame, require(game.ReplicatedStorage.MowALawn.Config).HUB_SIGNS)
		else
			CB.garage(unit, anchor.CFrame)
		end
	end
end)
tmp:Destroy()
assert(ok, err)
return "voxel shop and garage in place; old pieces in " .. bk:GetFullName() .. ". Save the place (Ctrl+S)."
