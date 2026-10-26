-- STUDIO, EDIT MODE: paste into the command bar (or run through the Studio MCP) after the scripts are synced.
-- Puts the CLASSES black hole (server/BlackHole) into the run world saved in the place (Workspace.World.Hub.CLASSES),
-- where the saved piece stands, so Edit mode shows what a run shows. A run builds it fresh anyway; this is only
-- for the view in Studio. The piece it replaces goes to ServerStorage.MowALawnBackups first.
-- Not part of the game (tools/ isn't synced by Rojo).
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode only")
local hub = workspace.World.Hub
local old = hub:FindFirstChild("CLASSES")
assert(old and old:FindFirstChild("0Anchor"), "no saved CLASSES piece with a 0Anchor")
local at = (old :: any)["0Anchor"].CFrame
local SS = game:GetService("ServerStorage")
local root = SS:FindFirstChild("MowALawnBackups") or Instance.new("Folder", SS)
root.Name = "MowALawnBackups"
local bk = Instance.new("Folder")
bk.Name = "Before black hole " .. os.date("%Y-%m-%d %H.%M")
bk.Parent = root
-- (a fresh copy of the modules: the command bar keeps old requires)
local tmp = game.ServerScriptService.MowALawn:Clone()
tmp.Parent = SS
local ok, err = pcall(function()
	local PropKit = require(tmp.PropKit)
	local k = Instance.new(old.ClassName)
	k.Name = "CLASSES"
	for n, v in old:GetAttributes() do
		k:SetAttribute(n, v)
	end
	local a = PropKit.part({ size = Vector3.new(2, 2, 2), cf = at, color = Color3.new(1, 1, 1), parent = k, transparency = 1, collide = false, name = "0Anchor" })
	a.CanQuery = false
	require(tmp.BlackHole).build(k, at)
	old.Parent = bk
	k.Parent = hub
end)
tmp:Destroy()
assert(ok, err)
return "black hole in place; old piece in " .. bk:GetFullName() .. ". Save the place (Ctrl+S)."
