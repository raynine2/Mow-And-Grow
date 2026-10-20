-- The loading screen before a party teleport (shared/LoadingScreen): the lobby server says "loading" a moment
-- before it teleports your party, so the screen goes up over the dimmed lobby and is handed to the teleport
-- (TeleportService:SetTeleportGui), staying on screen until the run server's boot screen takes over. In Studio
-- the lobby turns into the run in place, so the screen stays until the run's world is ready.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LoadingScreen = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("LoadingScreen")) :: any
local State = require(script.Parent.State)

local Loading = {}
local player = Players.LocalPlayer
local current: ScreenGui? = nil
local shownAt = 0

function Loading.hide()
	local gui = current
	current = nil
	if gui then
		LoadingScreen.fadeOut(gui)
	end
end

function Loading.show()
	if current then
		return
	end
	local gui = LoadingScreen.build(player)
	LoadingScreen.dim(gui, 0.3)
	gui.Parent = player:WaitForChild("PlayerGui")
	current = gui
	shownAt = os.clock()
	pcall(function()
		TeleportService:SetTeleportGui(LoadingScreen.build(player))
	end)
	-- never leave it up forever (a teleport that failed without telling us)
	task.delay(45, function()
		if current == gui then
			Loading.hide()
		end
	end)
end

State.on("fx", function(kind)
	if kind == "loading" then
		Loading.show()
	elseif kind == "loadingDone" then
		Loading.hide()
	end
end)

-- Studio: the lobby becomes the run here; take the screen down once the run's world is built
State.on("world", function(w)
	if current and w.mode == "Run" and not w.loading and os.clock() - shownAt > 1 then
		task.delay(0.6, Loading.hide)
	end
end)

return Loading
