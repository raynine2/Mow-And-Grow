-- STUDIO, EDIT MODE: paste into the command bar (or run through the Studio MCP) after the scripts are synced.
-- Swaps the camp fountain saved in the place (Workspace.World.Hub.CampDecor.camp_fountain, hand-placed) for the
-- garden fountain from server/CampFountain, at the same spot and turn. The old one goes to
-- ServerStorage.MowALawnBackups first. Not part of the game (tools/ isn't synced by Rojo).
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode only")
local decor = workspace.World.Hub.CampDecor
local old = decor:FindFirstChild("camp_fountain")
assert(old and old:IsA("Model"), "no camp_fountain in Workspace.World.Hub.CampDecor")
local at = old:GetPivot()
local SS = game:GetService("ServerStorage")
local root = SS:FindFirstChild("MowALawnBackups") or Instance.new("Folder", SS)
root.Name = "MowALawnBackups"
local bk = Instance.new("Folder")
bk.Name = "Before garden fountain " .. os.date("%Y-%m-%d %H.%M")
bk.Parent = root
-- (a fresh copy of the modules: the command bar keeps old requires)
local tmp = game.ServerScriptService.MowALawn:Clone()
tmp.Parent = SS
local ok, err = pcall(function()
	require(tmp.CampFountain).build(decor, CFrame.new(at.Position) * (at - at.Position))
	old.Parent = bk
end)
tmp:Destroy()
assert(ok, err)
return "garden fountain in place; old one in " .. bk:GetFullName() .. ". Save the place (Ctrl+S)."
