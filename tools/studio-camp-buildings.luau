-- STUDIO, EDIT MODE: paste into the command bar (or run through the Studio MCP) after the scripts are synced.
-- Puts the voxel Tool Shop and Garage (server/CampBuildings) into the run world saved in the place
-- (Workspace.World.Hub["TOOL SHOP"] and .Garage), where the saved pieces stand, so Edit mode shows what a run
-- shows. A run builds them fresh anyway; this is only for the view in Studio. Everything in the two pieces except
-- RunBuilder's working bits (tool displays, prompts, the gas pump, the 0Anchor) is taken out and the building is
-- built again; the gas pump is moved to CampBuildings.PUMP. A full copy of each piece goes to
-- ServerStorage.MowALawnBackups first. Safe to run again after a change to CampBuildings.
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
local KEEP = {
	["TOOL SHOP"] = { ["0Anchor"] = true, Counter = true, ToolDisplay = true },
	Garage = { ["0Anchor"] = true, GaragePrompt = true, gas_pump = true, GasPump = true },
}
local OLD_PUMP = CFrame.new(10, 0, -6)
-- (a fresh copy of the modules: the command bar keeps old requires)
local tmp = game.ServerScriptService.MowALawn:Clone()
tmp.Parent = SS
local ok, err = pcall(function()
	require(tmp.Models).loadAll(30)
	local CB = require(tmp.CampBuildings)
	for name, keep in KEEP do
		local unit = hub:FindFirstChild(name)
		local anchor = unit and unit:FindFirstChild("0Anchor")
		assert(anchor and anchor:IsA("BasePart"), "no saved " .. name .. " piece with a 0Anchor")
		local at = anchor.CFrame
		unit:Clone().Parent = bk
		for _, c in unit:GetChildren() do
			if not keep[c.Name] then
				c:Destroy()
			end
		end
		if name == "TOOL SHOP" then
			CB.shop(unit, at, require(game.ReplicatedStorage.MowALawn.Config).HUB_SIGNS)
		else
			CB.garage(unit, at)
			-- the pump: from where the old garage had it to CampBuildings.PUMP (only if it is still at the old spot)
			local delta = (at * CB.PUMP).Position - (at * OLD_PUMP).Position
			for _, c in unit:GetChildren() do
				local p = if c:IsA("Model") then c:GetPivot().Position elseif c:IsA("BasePart") then c.Position else nil
				if p and (c.Name == "gas_pump" or c.Name == "GasPump") and (at:PointToObjectSpace(p) * Vector3.new(1, 0, 1) - OLD_PUMP.Position).Magnitude < 1 then
					if c:IsA("Model") then
						c:PivotTo(c:GetPivot() + delta)
					else
						(c :: BasePart).CFrame += delta
					end
				end
			end
		end
	end
end)
tmp:Destroy()
assert(ok, err)
return "voxel shop and garage in place; old pieces in " .. bk:GetFullName() .. ". Save the place (Ctrl+S)."
