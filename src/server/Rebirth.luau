-- (5 Nov, owner after the balance review: "Rebirth / prestige") REBIRTH STARS. Finishing a run (server/Run
-- completeRun) gives stars by the run's difficulty (Config.REBIRTH.starsByDifficulty), kept in the profile's `rebirth`
-- up to Config.REBIRTH.maxStars. Each star is a little more coins and gems for good (server/Stats.compute adds them
-- next to the gem perks; never power). Milestones (Config.REBIRTH.milestones) give a title and pay their gems once,
-- when the stars first reach them.
-- The player attribute "RebirthStars" (and "RebirthTitle") is for any UI that wants it; the client's own view is in
-- the state snapshot (Rebirth.view). A finished run leaves `rebirthShow` in the profile so the celebration card plays
-- in the lobby after the ending (client/QuestsWindow); the client says "starsSeen" (remote "Progress") to clear it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MowALawn.Config)
local PlayerData = require(script.Parent.PlayerData)

local Rebirth = {}

-- The profile's stars (old profiles have none; never past the cap).
function Rebirth.stars(data): number
	local n = tonumber(data and data.rebirth) or 0
	return math.clamp(math.floor(n), 0, Config.REBIRTH.maxStars)
end

-- What the client draws: stars, the bonus, the title and the next milestone.
function Rebirth.view(data)
	local R = Config.REBIRTH
	local stars = Rebirth.stars(data)
	local got, nextOne = Config.rebirthMilestone(stars)
	return {
		stars = stars,
		max = R.maxStars,
		coins = stars * R.coinsPer, -- +share of coins (0.15 = +15%)
		gems = stars * R.gemsPer,
		title = got and got.title,
		nextAt = nextOne and nextOne.at,
		nextTitle = nextOne and nextOne.title,
		nextGems = nextOne and nextOne.gems,
		show = data.rebirthShow, -- { got, stars, gems, titles }: the run-end card still to show
	}
end

-- Set the attributes other UI can read.
function Rebirth.publish(player: Player, data)
	local stars = Rebirth.stars(data)
	local got = Config.rebirthMilestone(stars)
	if player:GetAttribute("RebirthStars") ~= stars then
		player:SetAttribute("RebirthStars", stars)
	end
	local title = if got then got.title else nil
	if player:GetAttribute("RebirthTitle") ~= title then
		player:SetAttribute("RebirthTitle", title)
	end
end

-- A run was finished on difficulty `difficultyId`: add its stars (up to the cap) and pay any milestone reached on the
-- way. Returns what was given ({ got, stars, gems, titles }), or nil at the cap.
function Rebirth.award(player: Player, data, difficultyId: string)
	local R = Config.REBIRTH
	local before = Rebirth.stars(data)
	local add = R.starsByDifficulty[difficultyId] or R.starsByDifficulty.Normal or 1
	local after = math.min(R.maxStars, before + add)
	if after <= before then
		return nil
	end
	data.rebirth = after
	local gems = 0
	local titles = {}
	for _, m in R.milestones do
		if before < m.at and after >= m.at then
			gems += m.gems
			table.insert(titles, m.title)
		end
	end
	data.gems += gems -- flat, like the daily rewards
	local result = { got = after - before, stars = after, gems = gems, titles = titles, difficulty = difficultyId }
	data.rebirthShow = result
	Rebirth.publish(player, data)
	PlayerData.changed(player)
	return result
end

-- The card was shown: forget it.
function Rebirth.seen(player: Player, data)
	if data.rebirthShow ~= nil then
		data.rebirthShow = nil
		PlayerData.changed(player)
	end
end

local started = false
function Rebirth.start()
	if started then
		return
	end
	started = true
	PlayerData.onLoaded(Rebirth.publish)
end

return Rebirth
