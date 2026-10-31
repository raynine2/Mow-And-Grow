-- SHOP SHELL VIEW (31 Oct; the owner kept the Tool Shop's room and wanted the house remade with ForgeGUI): the shop's
-- ForgeGUI cabin (server/ShopShell, a Model "ShopShell" in the TOOL SHOP) and the log lodge it stands on take turns:
--   * your camera outside the lodge's room: the cabin shows; of the lodge only its floor (the room and its tool boards
--     stay, so you see them through the cabin's doorway), its walls, roof, windows and door hidden
--   * your camera inside the room: the lodge as it was, the cabin hidden
-- Only this client's view changes (LocalTransparencyModifier): collisions, prompts and lights stay as they are.
-- Checked each frame right after the camera moves, so walking in through the door never shows the wrong one.
local RunService = game:GetService("RunService")

local ShopShellView = {}

local KEEP = { FloorBoard = true, FloorFill = true } -- (the lodge's floor shows from outside too)

local shell: Model? = nil
local lodge: Instance? = nil
local anchor: BasePart? = nil -- (the shop's "0Anchor": the lodge's own frame, wherever the saved map put the shop)
local inside: boolean? = nil
local conns: { RBXScriptConnection } = {}

local function setLodge(p: Instance, show: boolean)
	if p:IsA("BasePart") and not KEEP[p.Name] then
		p.LocalTransparencyModifier = if show then 0 else 1
	end
end

local function setShell(p: Instance, show: boolean)
	if p:IsA("BasePart") then
		p.LocalTransparencyModifier = if show then 0 else 1
	end
end

local function apply()
	if lodge then
		for _, p in lodge:GetDescendants() do
			setLodge(p, inside == true)
		end
	end
	if shell then
		for _, p in shell:GetDescendants() do
			setShell(p, inside ~= true)
		end
	end
end

-- the shop's cabin and lodge (they stream in, and a new run's world replaces them)
local function find()
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local shop = hub and hub:FindFirstChild("TOOL SHOP")
	local s = shop and shop:FindFirstChild("ShopShell") :: Model?
	anchor = shop and shop:FindFirstChild("0Anchor") :: BasePart?
	if s == shell then
		return
	end
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	shell = s
	lodge = if s and shop then shop:FindFirstChild("ShopBuilding") else nil
	inside = nil
	if s and lodge then
		-- parts streaming in later get the current view
		table.insert(conns, lodge.DescendantAdded:Connect(function(d)
			if inside ~= nil then
				setLodge(d, inside)
			end
		end))
		table.insert(conns, s.DescendantAdded:Connect(function(d)
			if inside ~= nil then
				setShell(d, not inside)
			end
		end))
	end
end

task.spawn(function()
	while true do
		find()
		task.wait(1)
	end
end)

RunService:BindToRenderStep("ShopShellView", Enum.RenderPriority.Camera.Value + 1, function()
	local s, a = shell, anchor
	if not s or not s.Parent or not a or not a.Parent then
		return
	end
	local mn, mx = s:GetAttribute("RoomMin"), s:GetAttribute("RoomMax")
	if typeof(mn) ~= "Vector3" or typeof(mx) ~= "Vector3" then
		return
	end
	local p = a.CFrame:PointToObjectSpace(workspace.CurrentCamera.CFrame.Position)
	local now = p.X > mn.X and p.X < mx.X and p.Y > mn.Y and p.Y < mx.Y and p.Z > mn.Z and p.Z < mx.Z
	if now ~= inside then
		inside = now
		apply()
	end
end)

return ShopShellView
