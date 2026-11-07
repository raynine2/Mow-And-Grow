--!strict
-- SPIN SAILS (7 Nov 2026, owner, of the stud windmill: "Wieken laten draaien"). Turns every model tagged "SpinSails"
-- (server/StudWindmill's sails) about its "SpinHub" CFrame (the axle along its Z) at "SpinSpeed" radians a second.
-- Each client turns its own copy (nothing goes over the network); the sails don't collide, so nothing can be pushed.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

type Spin = { base: CFrame, hub: CFrame, speed: number }
local live: { [Model]: Spin } = {}

local function add(inst: Instance)
	local hub = inst:GetAttribute("SpinHub")
	if inst:IsA("Model") and typeof(hub) == "CFrame" then
		live[inst] = { base = inst:GetPivot(), hub = hub, speed = tonumber(inst:GetAttribute("SpinSpeed")) or 0.35 }
	end
end

CollectionService:GetInstanceAddedSignal("SpinSails"):Connect(add)
CollectionService:GetInstanceRemovedSignal("SpinSails"):Connect(function(inst)
	live[inst :: Model] = nil
end)
for _, m in CollectionService:GetTagged("SpinSails") do
	add(m)
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	for m, s in live do
		if m.Parent then
			m:PivotTo(s.hub * CFrame.Angles(0, 0, -clock * s.speed) * s.hub:Inverse() * s.base)
		else
			live[m] = nil
		end
	end
end)

return {}
