-- Loot on the ground (server/Loot): new drops pop up out of the cut grass and land, gems spin and bob, and when
-- you pick something up it flies to the HUD (Hud "lootPicked") with a sound. A new Index entry gets a notice.
-- Everything here is only for looks; the server decides what's picked up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local UI = require(script.Parent.UI)

local LootFx = {}
local player = Players.LocalPlayer

type Pop = { model: Model | BasePart, target: CFrame, t: number }
local pops: { Pop } = {}
local spinners: { [Instance]: CFrame } = {}

local function pivotOf(m: Instance): CFrame?
	if m:IsA("Model") then
		return m:GetPivot()
	elseif m:IsA("BasePart") then
		return m.CFrame
	end
	return nil
end

local function setPivot(m: Instance, cf: CFrame)
	if m:IsA("Model") then
		m:PivotTo(cf)
	elseif m:IsA("BasePart") then
		m.CFrame = cf
	end
end

-- A new drop: hop up out of the grass and land on its spot (0.35 s). Gems float and spin after that.
local function onDrop(m: Instance)
	local target = pivotOf(m)
	if not target then
		return
	end
	if m:GetAttribute("Spin") then
		spinners[m] = target
	end
	table.insert(pops, { model = m :: any, target = target, t = 0 })
	setPivot(m, target * CFrame.new(0, -1, 0))
	m.Destroying:Connect(function()
		spinners[m] = nil
	end)
end

local function watch(folder: Instance)
	folder.ChildAdded:Connect(onDrop)
end

-- the Loot folder lives in the run's World folder
task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	if not world then
		return
	end
	local function check(c: Instance)
		if c.Name == "Loot" and c:IsA("Folder") then
			watch(c)
		end
	end
	world.ChildAdded:Connect(check)
	for _, c in world:GetChildren() do
		check(c)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	for i = #pops, 1, -1 do
		local p = pops[i]
		p.t += dt
		local k = math.min(p.t / 0.35, 1)
		if not p.model.Parent or k >= 1 then
			if p.model.Parent and not spinners[p.model] then
				setPivot(p.model, p.target)
			end
			table.remove(pops, i)
		else
			-- a little arc: up 1.6 studs and back down, with a tumble
			local h = -1 + 2.6 * math.sin(k * math.pi) + k
			setPivot(p.model, p.target * CFrame.new(0, h, 0) * CFrame.Angles(0, (1 - k) * 3, 0))
		end
	end
	local now = os.clock()
	for m, base in spinners do
		if m.Parent then
			setPivot(m, base * CFrame.new(0, math.sin(now * 2.4) * 0.35, 0) * CFrame.Angles(0, now * 2, 0))
		end
	end
end)

local lastPickSound = 0
State.on("fx", function(kind, d)
	if kind == "pickup" then
		State.emit("lootPicked", d.pos, d.kind, d.gems)
		local now = os.clock()
		if now - lastPickSound > 0.06 then
			lastPickSound = now
			Sound.play(if d.kind == "gem" then "reveal" else "chip", 0.1)
		end
	elseif kind == "indexNew" then
		local zone = Config.ZONES[d.z]
		local name = (if d.mut == "None" then "" else d.mut .. " ") .. (if zone then zone.grassName else "Grass")
		UI.notice("New in your Index!", ("%s   +%d gems"):format(name, d.gems or 0), "clover")
	end
end)

local _ = player
return LootFx
