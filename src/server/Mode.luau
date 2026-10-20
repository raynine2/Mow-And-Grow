-- The game is ONE map now: every server is the ring world (a "Run"), its hub holding what the lobby used to
-- (party pads, classes, rewards, garage, boards). A party pad still takes a party to a private copy (a reserved
-- server). The old separate lobby only comes up in Studio with Workspace attribute ForceMode = "Lobby".
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
	return "Run"
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
