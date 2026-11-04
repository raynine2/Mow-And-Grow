-- Grass bundles carried on your back. Stored in profile.run.carry so they survive a rejoin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local VoxelModels = require(script.Parent.VoxelModels)
local BundleVoxel = require(ReplicatedStorage.MowALawn.BundleVoxel)

local Carry = {}

local MAX_VISIBLE = 12
-- the voxel bundles (tools/blender/voxel/bundle.py: Bundle_<mutation>, owner 27 Oct "make it voxel like the game"),
-- drawn this much smaller than built (about 2.2 x 1.3 studs, so six stack a stud apart)
Carry.VOXEL_SCALE = 0.8
-- the ForgeGUI bundles (shared/BundleArt, 1 Nov: a different one per area and per mutation) are drawn at most this
-- long and this thick (rows are a stud apart, so they overlap a little like the voxel ones did)
Carry.BUNDLE_LENGTH = 2.3
Carry.BUNDLE_THICK = 1.3
-- the voxel bundles (shared/BundleVoxel, 4 Nov): this long across your back (about a stud thick)
Carry.VOXEL_LENGTH = 2.3

-- The voxel bundle mesh for a mutation (the plain one if that mutation has none), or nil before they're imported.
function Carry.voxelName(mut: string?): string?
	local name = "Bundle_" .. (mut or "None")
	if VoxelModels.has(name) then
		return name
	end
	return if VoxelModels.has("Bundle_None") then "Bundle_None" else nil
end

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

-- THE STACK ON YOUR BACK (owner, 4 Nov: "fix lag and optimize the game"). It used to be destroyed and built again
-- (up to 12 bundles of 9 welded parts, a copy sent to every player) on every bundle picked up: several a second while
-- mowing, sometimes several in one pickup tick. Now: at most one update per player per frame (Carry.refresh only
-- marks it), and when bundles were only added on top of the ones already drawn, just the new ones are added; past 12
-- only the "x N" label changes. The stack shows the first 12 carried, the oldest at the bottom.
local pending: { [Player]: boolean } = {}

local function key(b: any): string
	return tostring(b.z) .. ":" .. tostring(b.m or "")
end

-- One bundle at slot i (1..12) on the back, welded to the torso.
local function addBundle(stack: Model, torso: BasePart, i: number, b: any)
	local mut = Config.mutation(b.m or "None")
	local row = (i - 1) % 6
	local col = (i - 1) // 6
	-- (4 Nov, owner: "make it better ... it feels so bas and low qaulity") the game's own voxel bundle
	-- (shared/BundleVoxel; it was the ForgeGUI one, shared/BundleArt), stacked neatly up the middle of your back,
	-- each row turned the other way so cut ends and tips alternate like a hand-stacked pile; past six, a second
	-- stack right behind the first (it was a second column off to one side, the whole pile lopsided)
	local T = BundleVoxel.thickness(Carry.VOXEL_LENGTH)
	local turn = if row % 2 == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	local at = torso.CFrame * CFrame.new(if row % 2 == 1 then 0.08 else -0.08, -1.05 + row * (T + 0.03), 0.62 + T / 2 + col * (T + 0.05)) * turn
	local vb = BundleVoxel.make(b.z, mut.id, Carry.VOXEL_LENGTH)
	vb.Name = "Bundle" .. i
	vb:PivotTo(at)
	for _, p in vb:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = p
			w.Part1 = torso
			w.Parent = p
		end
	end
	vb.Parent = stack
end

-- The "x N" over the stack once it's past 12 (gone below).
local function setLabel(stack: Model, torso: BasePart, count: number)
	local gui = stack:FindFirstChild("CountLabel") :: BillboardGui?
	if count <= MAX_VISIBLE then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "CountLabel"
		g.Size = UDim2.fromScale(3, 1.2)
		g.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		g.Adornee = torso
		local label = Instance.new("TextLabel")
		label.Name = "Count"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Config.UI.font
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = g
		g.Parent = stack
		gui = g
	end
	((gui :: BillboardGui):FindFirstChild("Count") :: TextLabel).Text = "x" .. count
end

local function rebuild(player: Player)
	pending[player] = nil
	local char = player.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not char or not torso then
		return
	end
	local stack = char:FindFirstChild("BundleStack") :: Model?
	local data = PlayerData.get(player)
	local carry = data and data.run and data.run.carry
	if not carry or #carry == 0 then
		if stack then
			stack:Destroy()
		end
		return
	end
	local n = math.min(#carry, MAX_VISIBLE)
	local want = table.create(n)
	for i = 1, n do
		want[i] = key(carry[i])
	end
	-- what's drawn already: keep it when it's the start of what's wanted
	local from = 1
	if stack then
		local had = string.split(stack:GetAttribute("Keys") :: string? or "", "|")
		local k = if had[1] == "" then 0 else #had
		local keep = k <= n
		for i = 1, math.min(k, n) do
			if had[i] ~= want[i] then
				keep = false
				break
			end
		end
		if keep then
			from = k + 1
		else
			stack:Destroy()
			stack = nil
		end
	end
	if not stack then
		local m = Instance.new("Model")
		m.Name = "BundleStack"
		stack = m
	end
	local s = stack :: Model
	for i = from, n do
		addBundle(s, torso, i, carry[i])
	end
	s:SetAttribute("Keys", table.concat(want, "|"))
	setLabel(s, torso, #carry)
	s.Parent = char
end

-- Bring the stack on the character's back up to date (at the end of this frame: several changes in a row are one).
function Carry.refresh(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(rebuild, player)
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
