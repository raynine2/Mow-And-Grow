-- Boot loading screen (ReplicatedFirst): replaces Roblox's default one the moment the game starts, and stays up
-- until this server's world is built and your character is in it, then fades away. After a party teleport this
-- is what you see on arrival (the lobby handed the same screen to the teleport, see client/Loading).
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- a plain backdrop straight away, so there's no flash between Roblox's screen and ours
local cover = Instance.new("ScreenGui")
cover.Name = "MowALawnCover"
cover.IgnoreGuiInset = true
cover.ResetOnSpawn = false
cover.DisplayOrder = 999
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BorderSizePixel = 0
fill.BackgroundColor3 = Color3.fromRGB(36, 66, 72)
fill.Parent = cover
cover.Parent = playerGui
local arriving = TeleportService:GetArrivingTeleportGui()
if arriving then
	arriving.Parent = playerGui -- the lobby's screen, until ours is built
end
ReplicatedFirst:RemoveDefaultLoadingScreen()

local shared = ReplicatedStorage:WaitForChild("MowALawn")
local LoadingScreen = require(shared:WaitForChild("LoadingScreen")) :: any
local gui = LoadingScreen.build(player)
gui.Parent = playerGui
cover:Destroy()
if arriving then
	arriving:Destroy()
end

-- ready when the server says its world is built (mode set, not loading) and we have a character in it
local ready = false
local remotes = ReplicatedStorage:WaitForChild("MowALawnRemotes")
local worldEvent = remotes:WaitForChild("World") :: RemoteEvent
local conn = worldEvent.OnClientEvent:Connect(function(w)
	if type(w) == "table" and w.mode and not w.loading then
		ready = true
	end
end)
-- the client scripts may have asked for the world before we were listening: ask again (harmless)
local readyRemote = remotes:WaitForChild("Ready") :: RemoteEvent
task.delay(1, function()
	if not ready then
		readyRemote:FireServer()
	end
end)
local start = os.clock()
local dimmed = false
local lastAsk = os.clock()
while os.clock() - start < 60 do
	if not ready and os.clock() - lastAsk > 5 then
		lastAsk = os.clock()
		readyRemote:FireServer()
	end
	if not dimmed and workspace:FindFirstChild("World") then
		dimmed = true
		LoadingScreen.dim(gui)
	end
	local char = player.Character
	if ready and char and char:FindFirstChild("HumanoidRootPart") then
		break
	end
	task.wait(0.2)
end
conn:Disconnect()
task.wait(0.4)
LoadingScreen.fadeOut(gui)
