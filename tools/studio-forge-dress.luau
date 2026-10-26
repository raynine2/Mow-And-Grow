-- STUDIO, EDIT MODE: paste into the command bar (or run through the Studio MCP) after the scripts are synced.
-- Puts the ForgeGUI models into the run world saved in the place, so Edit mode shows what a run shows:
--   * the area archways at the gates and the grass-clippings bins on the drop-off pads (server/ForgeDress), the
--     old "MOW ALL OF ... TO OPEN" boards, posts and stone arches gone
--   * the ForgeGUI garden fountain in the camp (server/CampFountain), in place of the part-built one
-- The boss arenas and the lobby's party booths are built by the game at run / lobby start, so they get theirs then.
-- Copies of what it changes go to ServerStorage.MowALawnBackups first. Not part of the game (tools/ isn't synced).
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode only")
local w = workspace:FindFirstChild("World")
assert(w, "no Workspace.World")
local SS = game:GetService("ServerStorage")
local root = SS:FindFirstChild("MowALawnBackups") or Instance.new("Folder", SS)
root.Name = "MowALawnBackups"
local bk = Instance.new("Folder")
bk.Name = "Before ForgeGUI dress " .. os.date("%Y-%m-%d %H.%M")
bk.Parent = root
for _, name in { "Gates", "Pads" } do
	local f = w:FindFirstChild(name)
	if f then
		f:Clone().Parent = bk
	end
end
local decor = w:FindFirstChild("Hub") and w.Hub:FindFirstChild("CampDecor")
local oldFountain = decor and decor:FindFirstChild("camp_fountain")
-- (a fresh copy of the modules: the command bar keeps old requires)
local tmp = game.ServerScriptService.MowALawn:Clone()
tmp.Parent = SS
local out = {}
local ok, err = pcall(function()
	require(tmp.Models).loadAll(30)
	table.insert(out, ("%d gates / pads dressed"):format(require(tmp.ForgeDress).world(w)))
	if oldFountain and oldFountain:IsA("Model") then
		local at = oldFountain:GetPivot()
		local f = require(tmp.CampFountain).build(decor, CFrame.new(at.Position) * (at - at.Position))
		oldFountain.Parent = bk
		table.insert(out, "fountain: " .. (if f:GetAttribute("Forge") or f:FindFirstChild("Body", true) then "ForgeGUI" else "parts"))
	end
end)
tmp:Destroy()
assert(ok, err)
return table.concat(out, "\n") .. "\nold copies in " .. bk:GetFullName() .. ". Save the place (Ctrl+S)."
