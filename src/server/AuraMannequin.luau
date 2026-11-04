--!strict
-- The aura mannequin on a pedestal by the classes cabin (research brief: "let other players' auras be the
-- advertisement" and "a mannequin in the classes cabin wearing the current stock's top aura"): a plain wooden R15
-- figure tagged "AuraMannequin"; client/Auras puts the class in its "AuraClass" attribute on it (server/Lobby sets
-- that to the best class in stock). A little sign under it names the class.
-- (Shared by server/LobbyBuilder and server/YardBuilder.)
local PropKit = require(script.Parent.PropKit)

local AuraMannequin = {}


function AuraMannequin.build(m: Instance, at: CFrame): Model?
	local ok, rig = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		return nil
	end
	local stand = at * CFrame.new(0, 0, 0)
	-- the pedestal: a dark wooden plinth, a lighter top and a thin gold trim round its top edge
	PropKit.brick(m, Vector3.new(5, 1.6, 5), stand * CFrame.new(0, 0.8, 0), Color3.fromRGB(70, 52, 40), "Plinth", Enum.Material.WoodPlanks)
	PropKit.brick(m, Vector3.new(4.6, 0.3, 4.6), stand * CFrame.new(0, 1.75, 0), Color3.fromRGB(150, 98, 58), "PlinthTop", Enum.Material.WoodPlanks)
	for _, e in { { 0, 2.4, 5.2, 0.25 }, { 0, -2.4, 5.2, 0.25 }, { 2.4, 0, 0.25, 5.2 }, { -2.4, 0, 0.25, 5.2 } } do
		PropKit.brick(m, Vector3.new(e[3], 0.25, e[4]), stand * CFrame.new(e[1], 1.6, e[2]), Color3.fromRGB(214, 160, 52), "PlinthTrim", Enum.Material.SmoothPlastic)
	end
	rig.Name = "AuraMannequin"
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Color = Color3.fromRGB(214, 172, 120) -- a tailor's dummy in light wood
			d.Material = Enum.Material.Wood
		elseif d:IsA("Decal") and d.Name == "face" then
			d:Destroy()
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lift = if hum and root then hum.HipHeight + root.Size.Y / 2 else 3
	rig:PivotTo(stand * CFrame.new(0, 1.9 + lift, 0))
	rig.Parent = m
	-- a tailor's dummy has no face (the head's face decal can arrive with the description, so look again now)
	for _, d in rig:GetDescendants() do
		if d:IsA("Decal") or d:IsA("FaceControls") then
			d:Destroy()
		elseif d:IsA("MeshPart") then
			pcall(function()
				d.TextureID = "" -- (the default head's face is painted into its texture)
			end)
		end
	end
	game:GetService("CollectionService"):AddTag(rig, "AuraMannequin")
	-- its sign: the class's name on the plinth's front
	local name = PropKit.facePanel(m, stand, Vector3.new(0, 0.85, -2.55), Vector2.new(4.6, 1.1), "", Color3.new(1, 1, 1))
	name.Name = "MannequinName"
	local ref = Instance.new("ObjectValue")
	ref.Name = "NameLabel"
	ref.Value = name
	ref.Parent = rig
	return rig
end

return AuraMannequin
