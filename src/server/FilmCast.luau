-- FILM CAST (Films v2, 5 Nov 2026; owner: "make my model rayan poep hoof the mayor. or the owner of town"): the films'
-- people who aren't players. The valley's owner is Config.FILMS_V2.owner's avatar (the co-owner's since 5 Nov), built here
-- once at server start (a character's model can only be made on the server) and put in
-- ReplicatedStorage.FilmCast.Owner for the clients' films to copy (client/Puppet). If Roblox can't make it (the
-- avatar service down), it tries again a few times; the films fall back to a plain blocky stand-in meanwhile.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config")) :: any

local FilmCast = {}

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild("FilmCast")
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "FilmCast"
	made.Parent = ReplicatedStorage
	return made
end

function FilmCast.start()
	local V2 = Config.FILMS_V2
	if not V2 or not V2.on or type(V2.owner) ~= "number" then
		return
	end
	task.spawn(function()
		local f = folder()
		for attempt = 1, 4 do
			local ok, m = pcall(function()
				return Players:CreateHumanoidModelFromUserIdAsync(V2.owner)
			end)
			if ok and m then
				m.Name = "Owner"
				-- (only its looks travel: nothing in it runs)
				for _, d in m:GetDescendants() do
					if d:IsA("BaseScript") then
						d:Destroy()
					end
				end
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
				m.Parent = f
				return
			end
			warn("[FilmCast] the owner's avatar couldn't be made (try " .. attempt .. "): " .. tostring(m))
			task.wait(4 * attempt)
		end
	end)
end

return FilmCast
