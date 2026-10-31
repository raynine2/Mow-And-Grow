-- Installs ShopShellView (git's exact text, 4097 2024092036) into game.StarterPlayer.StarterPlayerScripts.MowALawnClient. Run in Edit mode.
local src = [======[
-- SHOP SHELL VIEW (31 Oct; the owner kept the Tool Shop's room and wanted the house remade with ForgeGUI): the shop's
-- ForgeGUI cabin (server/ShopShell, a Model "ShopShell" in the TOOL SHOP) and the log lodge it stands on take turns:
--   * your camera outside the lodge's room: the cabin shows; of the lodge only its floor (the room and its tool boards
--     stay, so you see them through the cabin's doorway), its walls, roof, windows and door hidden
--   * your camera inside the room: the lodge (dressed inside like the cabin, server/ShopShell), the cabin hidden
-- (31 Oct, owner: "also use this house for the garage model alike") The Garage the same way: its ForgeGUI garage
-- outside, the voxel garage inside.
-- Only this client's view changes (LocalTransparencyModifier): collisions, prompts and lights stay as they are.
-- Checked each frame right after the camera moves, so walking in through the door never shows the wrong one.
local RunService = game:GetService("RunService")

local ShopShellView = {}

-- each building: its folder in the hub, its voxel building, and what of that shows from outside too (its floor)
local UNITS = {
	{ unit = "TOOL SHOP", building = "ShopBuilding", keep = { FloorBoard = true, FloorFill = true } },
	{ unit = "Garage", building = "GarageBuilding", keep = { FloorSlab = true, FloorFill = true, BayLine = true, OilStain = true } },
}

type View = {
	keep: { [string]: boolean },
	shell: Model?,
	lodge: Instance?,
	anchor: BasePart?, -- (the unit's "0Anchor": the building's own frame, wherever the saved map put it)
	inside: boolean?,
	conns: { RBXScriptConnection },
}
local views: { View } = {}
for i, u in UNITS do
	views[i] = { keep = u.keep, shell = nil, lodge = nil, anchor = nil, inside = nil, conns = {} }
end

local function setLodge(v: View, p: Instance, show: boolean)
	if p:IsA("BasePart") and not v.keep[p.Name] then
		p.LocalTransparencyModifier = if show then 0 else 1
	end
end

local function setShell(p: Instance, show: boolean)
	if p:IsA("BasePart") then
		p.LocalTransparencyModifier = if show then 0 else 1
	end
end

local function apply(v: View)
	if v.lodge then
		for _, p in v.lodge:GetDescendants() do
			setLodge(v, p, v.inside == true)
		end
	end
	if v.shell then
		for _, p in v.shell:GetDescendants() do
			setShell(p, v.inside ~= true)
		end
	end
end

-- the shells and buildings (they stream in, and a new run's world replaces them)
local function find(v: View, u: { unit: string, building: string })
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local unit = hub and hub:FindFirstChild(u.unit)
	local s = unit and unit:FindFirstChild("ShopShell") :: Model?
	v.anchor = unit and unit:FindFirstChild("0Anchor") :: BasePart?
	if s == v.shell then
		return
	end
	for _, c in v.conns do
		c:Disconnect()
	end
	table.clear(v.conns)
	v.shell = s
	v.lodge = if s and unit then unit:FindFirstChild(u.building) else nil
	v.inside = nil
	if s and v.lodge then
		-- parts streaming in later get the current view
		table.insert(v.conns, v.lodge.DescendantAdded:Connect(function(d)
			if v.inside ~= nil then
				setLodge(v, d, v.inside)
			end
		end))
		table.insert(v.conns, s.DescendantAdded:Connect(function(d)
			if v.inside ~= nil then
				setShell(d, not v.inside)
			end
		end))
	end
end

task.spawn(function()
	while true do
		for i, u in UNITS do
			find(views[i], u)
		end
		task.wait(1)
	end
end)

RunService:BindToRenderStep("ShopShellView", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace.CurrentCamera.CFrame.Position
	for _, v in views do
		local s, a = v.shell, v.anchor
		if not s or not s.Parent or not a or not a.Parent then
			continue
		end
		local mn, mx = s:GetAttribute("RoomMin"), s:GetAttribute("RoomMax")
		if typeof(mn) ~= "Vector3" or typeof(mx) ~= "Vector3" then
			continue
		end
		local p = a.CFrame:PointToObjectSpace(cam)
		local now = p.X > mn.X and p.X < mx.X and p.Y > mn.Y and p.Y < mx.Y and p.Z > mn.Z and p.Z < mx.Z
		if now ~= v.inside then
			v.inside = now
			apply(v)
		end
	end
end)

return ShopShellView
]======]
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(src) ~= "4097 2024092036" then
	return "NOT INSTALLED: the pasted text is " .. hashOf(src)
end
local folder = game.StarterPlayer.StarterPlayerScripts.MowALawnClient
local old = folder:FindFirstChild("ShopShellView")
if old then
	local now = hashOf(old.Source)
	if now == "4097 2024092036" then
		return "ShopShellView is already this version: " .. now
	end
	local known = { ["3288 896470903"] = true }
	if not known[now] then
		return "NOT CHANGED: ShopShellView is there but is " .. now .. " (not a version this replaces)"
	end
	old.Source = src
	return "ShopShellView updated: " .. hashOf(old.Source)
end
local m = Instance.new("ModuleScript")
m.Name = "ShopShellView"
m.Source = src
m.Parent = folder
return "ShopShellView installed: " .. hashOf(m.Source)
