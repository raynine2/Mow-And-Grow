-- One place, two modes. A reserved server (made by a party pad) is a RUN; every other server is the LOBBY.
-- In Studio: Workspace attribute ForceMode ("Lobby" / "Run") or Config.STUDIO_MODE decides.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)

local Mode = {}

local function detect(): string
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("ForceMode")
		if forced == "Run" or forced == "Lobby" then
			return forced
		end
		return if Config.STUDIO_MODE == "Run" then "Run" else "Lobby"
	end
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Run"
	end
	return "Lobby"
end

Mode.current = detect()
Mode.isRun = Mode.current == "Run"
Mode.isLobby = not Mode.isRun

-- Clients read this to know which HUD to show.
ReplicatedStorage:SetAttribute("MowALawnMode", Mode.current)

-- Studio only: a party pad turns the lobby into a run in the same server (teleports don't work in Studio).
function Mode.set(mode: string)
	Mode.current = mode
	Mode.isRun = mode == "Run"
	Mode.isLobby = not Mode.isRun
	ReplicatedStorage:SetAttribute("MowALawnMode", mode)
end

return Mode
