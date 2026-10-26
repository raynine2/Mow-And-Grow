-- STUDIO, EDIT MODE: paste into the command bar (or run through the Studio MCP) once, with the latest scripts synced.
-- Applies the code's lobby fixes (commits 804a0c3, 23b8a26 and the shorter far cross walk in LobbyArt PATHS) to the
-- lobby saved in the place (Workspace.Maps.Lobby), in place, without a re-bake: trees out of the roofs, bushes,
-- flower beds and lanterns off the walks, the walks relaid with stone paving, no classes vendor, the night-sky pad.
-- Copies what it touches to ServerStorage.MowALawnBackups first, and marks the lobby (attribute OverlapFix1).
-- Not part of the game (tools/ isn't synced by Rojo).
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "edit mode only")
local L = workspace.Maps.Lobby
assert(not L:GetAttribute("OverlapFix1"), "already done")
local O = Vector3.new(3000, 0, 0)
local SS = game:GetService("ServerStorage")
local root = SS:FindFirstChild("MowALawnBackups") or Instance.new("Folder", SS)
root.Name = "MowALawnBackups"
local bk = Instance.new("Folder")
bk.Name = "Before lobby overlap fixes " .. os.date("%Y-%m-%d %H.%M")
local town = L.Dressing.Town
for _, f in { town, L.Lanterns, L.Paths, L.Classes } do
	f:Clone().Parent = bk
end
bk.Parent = root

local out = {}
local function flat(inst: Instance): Vector3
	local p = if inst:IsA("Model") then inst:GetPivot().Position else (inst :: BasePart).Position
	return Vector3.new(p.X - O.X, 0, p.Z - O.Z)
end
local function near(parent: Instance, pattern: string, at: Vector3, tol: number): { Instance }
	local got = {}
	for _, c in parent:GetChildren() do
		if string.match(c.Name, pattern) and (c:IsA("Model") or c:IsA("BasePart")) and (flat(c) - at).Magnitude < tol then
			table.insert(got, c)
		end
	end
	return got
end
local function shift(inst: Instance, by: Vector3)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + by)
	else
		(inst :: BasePart).CFrame += by
	end
end

for _, sx in { -1, 1 } do
	-- trees (+ their invisible blockers) through the houses, lodge, barn and the west rewards stall: gone
	local drop = { Vector3.new(45 * sx, 0, 2), Vector3.new(44 * sx, 0, 15), Vector3.new(57 * sx, 0, -2) }
	if sx < 0 then
		table.insert(drop, Vector3.new(-56, 0, 12))
	end
	for _, at in drop do
		for _, c in near(town, "^Tree", at, 3) do
			c:Destroy()
			table.insert(out, "tree gone " .. tostring(at))
		end
		for _, c in near(town, "^Blocker", at, 3) do
			c:Destroy()
		end
	end
	-- trees behind the party signs: back past the fence
	for _, m in { { Vector3.new(30 * sx, 0, 56), Vector3.new(0, 0, 14) }, { Vector3.new(16 * sx, 0, 57), Vector3.new(0, 0, 13) } } do
		for _, c in near(town, "^Tree", m[1], 3) do
			shift(c, m[2])
			table.insert(out, "tree moved " .. tostring(m[1]))
		end
		for _, c in near(town, "^Blocker", m[1], 3) do
			shift(c, m[2])
		end
	end
	-- bushes off the house backs
	for _, at in { Vector3.new(38 * sx, 0, -1), Vector3.new(38 * sx, 0, 12) } do
		for _, c in near(town, "^Bush", at, 2.5) do
			shift(c, Vector3.new(3 * sx, 0, 0))
			table.insert(out, "bush moved " .. tostring(at))
		end
	end
	-- flower beds off the walks
	for _, m in { { Vector3.new(9 * sx, 0, -9.5), Vector3.new(1.5 * sx, 0, 0) }, { Vector3.new(9 * sx, 0, 17.5), Vector3.new(1.5 * sx, 0, -1) } } do
		for _, c in near(town, "flower_bed", m[1], 2) do
			shift(c, m[2])
			table.insert(out, "flower bed moved " .. tostring(m[1]))
		end
	end
	-- the z 24 lanterns out of the cross walk
	for _, c in near(L.Lanterns, ".", Vector3.new(13 * sx, 0, 24), 2) do
		shift(c, Vector3.new(3 * sx, 0, -5.6))
		table.insert(out, "lantern moved")
	end
end

-- classes lodge: no vendor, the night-sky pad instead of the purple frame
local tmp = game.ServerScriptService.MowALawn:Clone()
tmp.Parent = SS
local ok, err = pcall(function()
	local classes = L.Classes
	for _, c in classes:GetDescendants() do
		if c.Name == "Vendor" and c:IsA("Model") then
			c:Destroy()
			table.insert(out, "vendor gone")
		end
	end
	local fx = classes:FindFirstChild("ClassesFX", true)
	if fx and fx:GetAttribute("Color") ~= nil then
		fx:SetAttribute("Color", Color3.fromRGB(200, 225, 255))
	end
	local frame = classes:FindFirstChild("PadFrame", true)
	if frame and frame:IsA("Model") then
		local cf, size = frame:GetBoundingBox()
		local long = math.max(size.X, size.Z)
		local yaw = if size.X >= size.Z then 0 else math.pi / 2
		local base = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z) * CFrame.Angles(0, yaw, 0)
		local parent = frame.Parent :: Instance
		frame:Destroy()
		require(tmp.LobbyPads).space(parent, base, long, math.min(size.X, size.Z))
		table.insert(out, "space pad " .. tostring(base.Position))
	end
	-- the walks: laid again from the code's list (the far cross walk shortened), with the stone paving
	local HubPaths = require(tmp.HubPaths)
	L.Paths:Destroy()
	local segs = {}
	for _, s in { { Vector2.new(0, -52), Vector2.new(0, 34) }, { Vector2.new(-46, -22), Vector2.new(46, -22) }, { Vector2.new(-42, 26), Vector2.new(42, 26) }, { Vector2.new(-28, 42), Vector2.new(28, 42) } } do
		table.insert(segs, { a = s[1] + Vector2.new(O.X, O.Z), b = s[2] + Vector2.new(O.X, O.Z), width = 12 })
	end
	local paths = HubPaths.lay(L, segs, 0, 11, { { centre = Vector2.new(O.X, 4), radius = 13 } })
	HubPaths.pave(paths, O)
	table.insert(out, "paths relaid: " .. #paths.Stones:GetChildren() .. " stones")
end)
tmp:Destroy()
assert(ok, err)
L:SetAttribute("OverlapFix1", true)
return table.concat(out, "\n")
