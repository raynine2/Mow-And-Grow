-- (11 Nov, owner: "if I press Ctrl+Shift+P I fly, pls fix") Roblox gives everyone who can edit the place a free camera
-- on Shift+P: its "Freecam" ScreenGui with FreecamScript in PlayerGui (normal players never get it). It's removed
-- here as soon as it shows up. Set Config.FREECAM = true to keep it (handy for screenshots).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
if (Config :: any).FREECAM == true then
	return
end

local gui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function remove(child: Instance)
	if child.Name == "Freecam" then
		task.defer(function()
			child:Destroy()
		end)
	end
end

gui.ChildAdded:Connect(remove)
for _, child in gui:GetChildren() do
	remove(child)
end
