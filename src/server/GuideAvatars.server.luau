--!strict
-- (10 Nov) The tutorial guides' bodies: each Config.TUTOR_GUIDES avatar built once as an R15 model (the owner's and
-- brrbrr's own Roblox avatars) into ReplicatedStorage.MowALawnGuides, for client/TutorGuide to copy and walk.
-- Built on the server because only the server can turn a user id into a model. Scripts are stripped; a failed one
-- (Roblox down, an avatar it can't read) is just left out and the client falls back to the old step card.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))

local folder = Instance.new("Folder")
folder.Name = "MowALawnGuides"
folder.Parent = ReplicatedStorage

for _, g in (Config :: any).TUTOR_GUIDES or {} do
	task.spawn(function()
		local ok, model = pcall(function()
			local desc = Players:GetHumanoidDescriptionFromUserId(g.userId)
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok or not model then
			warn("[GuideAvatars] couldn't build " .. tostring(g.key) .. ": " .. tostring(model))
			return
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("ModuleScript") then
				d:Destroy()
			end
		end
		model.Name = g.key
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		model.Parent = folder
	end)
end
