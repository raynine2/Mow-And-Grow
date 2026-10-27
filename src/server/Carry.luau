-- Grass bundles carried on your back. Stored in profile.run.carry so they survive a rejoin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local Models = require(script.Parent.Models)
local VoxelModels = require(script.Parent.VoxelModels)

local Carry = {}

local MAX_VISIBLE = 12
-- the voxel bundles (tools/blender/voxel/bundle.py: Bundle_<mutation>, owner 27 Oct "make it voxel like the game"),
-- drawn this much smaller than built (about 2.2 x 1.3 studs, so six stack a stud apart)
Carry.VOXEL_SCALE = 0.8

-- The voxel bundle mesh for a mutation (the plain one if that mutation has none), or nil before they're imported.
function Carry.voxelName(mut: string?): string?
	local name = "Bundle_" .. (mut or "None")
	if VoxelModels.has(name) then
		return name
	end
	return if VoxelModels.has("Bundle_None") then "Bundle_None" else nil
end
local BUNDLE_COLOR = Color3.fromRGB(150, 220, 80)
local TAPE = Color3.fromRGB(255, 205, 50)

function Carry.count(player: Player): number
	local data = PlayerData.get(player)
	return if data and data.run then #data.run.carry else 0
end

function Carry.capacity(player: Player): number
	local data = PlayerData.get(player)
	return if data then math.floor(Stats.compute(player, data).carry) else Config.BASE_CARRY
end

function Carry.isFull(player: Player): boolean
	return Carry.count(player) >= Carry.capacity(player)
end

-- Rebuild the stack model on the character's back.
function Carry.refresh(player: Player)
	local char = player.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local old = char:FindFirstChild("BundleStack")
	if old then
		old:Destroy()
	end
	local data = PlayerData.get(player)
	if not data or not data.run or #data.run.carry == 0 then
		return
	end
	local stack = Instance.new("Model")
	stack.Name = "BundleStack"
	local n = math.min(#data.run.carry, MAX_VISIBLE)
	for i = 1, n do
		local b = data.run.carry[#data.run.carry - n + i]
		local mut = Config.mutation(b.m or "None")
		local row = (i - 1) % 6
		local col = (i - 1) // 6
		local spot = torso.CFrame * CFrame.new(col * 2.4 - (if n > 6 then 1.2 else 0), -0.6 + row * 1.0, 1.3) * CFrame.new(0, -0.5, 0)
		local vname = Carry.voxelName(mut.id)
		local mesh = vname and VoxelModels.place(stack, vname, spot.Position, { scale = Carry.VOXEL_SCALE, shadow = false })
		if mesh then
			-- (its knot and daisy face out, away from the back, where the camera sees them)
			mesh.CFrame = spot * CFrame.new(0, mesh.Size.Y / 2, 0)
			mesh.Anchored = false
			mesh.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = mesh
			w.Part1 = torso
			w.Parent = mesh
			continue
		end
		local placed = Models.place("bundle", stack, spot, 0.9)
		if placed then
			Models.weldTo(placed, torso)
			if mut.color then
				for _, p in placed:GetDescendants() do
					if p:IsA("BasePart") and p.Material == Enum.Material.Grass then
						p.Color = mut.color
					end
				end
			end
			continue
		end
		local part = Instance.new("Part")
		part.Name = "Bundle"
		part.Size = Vector3.new(2.2, 0.9, 1.4)
		part.Color = mut.color or BUNDLE_COLOR
		part.Material = if mut.id == "None" then Enum.Material.Plastic else Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = torso.CFrame * CFrame.new(col * 2.3 - (if n > 6 then 1.15 else 0), -0.6 + row * 0.95, 1.3)
		local tape = Instance.new("Part")
		tape.Name = "Tape"
		tape.Size = Vector3.new(0.4, 0.95, 1.45)
		tape.Color = TAPE
		tape.CanCollide = false
		tape.CanQuery = false
		tape.CanTouch = false
		tape.Massless = true
		tape.CFrame = part.CFrame
		tape.Parent = stack
		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = tape
		w2.Part1 = torso
		w2.Parent = tape
		local w = Instance.new("WeldConstraint")
		w.Part0 = part
		w.Part1 = torso
		w.Parent = part
		part.Parent = stack
	end
	if #data.run.carry > MAX_VISIBLE then
		local top = stack:GetChildren()[1] :: BasePart
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(3, 1.2)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		gui.Adornee = torso
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Config.UI.font
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "x" .. #data.run.carry
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = top
	end
	stack.Parent = char
end

-- Add one bundle (picked up from the ground, see server/Loot). Returns false when the bag is full.
function Carry.add(player: Player, zone: number, mut: string?): boolean
	local data = PlayerData.get(player)
	if not data or not data.run then
		return false
	end
	local cap = Carry.capacity(player)
	if #data.run.carry >= cap then
		return false
	end
	local m = if mut and mut ~= "None" then mut else nil
	table.insert(data.run.carry, { z = zone, m = m })
	PlayerData.changed(player)
	Carry.refresh(player)
	return true
end

-- Value of everything carried, before the sell multiplier.
function Carry.value(data): number
	local total = 0
	for _, b in data.run.carry do
		local zone = Config.ZONES[b.z] or Config.ZONES[1]
		total += zone.value * Config.mutation(b.m or "None").mult
	end
	return total
end

function Carry.clear(player: Player)
	local data = PlayerData.get(player)
	if data and data.run then
		table.clear(data.run.carry)
		PlayerData.changed(player)
		Carry.refresh(player)
	end
end

return Carry
