-- The onboarding quest chain (Config.QUESTS), tracked per run in profile.run.quest = { i = index, p = progress }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local Quests = {}

local ABSOLUTE = { tool = true, bag = true } -- these report a level reached, not an amount gained

-- (5 Nov) a quest that can't be done right now is skipped: "Get a ride-on mower" while Config.MOWERS_LOCKED (every new
-- player's chain stopped there for good)
local function doable(q): boolean
	return not (q.event == "mower" and Config.MOWERS_LOCKED)
end
local function skipLocked(run)
	while Config.QUESTS[run.quest.i] and not doable(Config.QUESTS[run.quest.i]) do
		run.quest = { i = run.quest.i + 1, p = 0 }
	end
end

-- Something happened that quests may count. For "tool" / "bag", amount is the new best tool / bag tier.
function Quests.event(player: Player, kind: string, amount: number?)
	local data = PlayerData.get(player)
	local run = data and data.run
	if not run then
		return
	end
	run.quest = run.quest or { i = 1, p = 0 }
	skipLocked(run)
	local q = Config.QUESTS[run.quest.i]
	if not q or q.event ~= kind then
		return
	end
	if ABSOLUTE[kind] then
		run.quest.p = math.max(run.quest.p, amount or 0)
	else
		run.quest.p += amount or 1
	end
	if run.quest.p >= q.goal then
		run.coins += q.reward
		Net.send(player, "Fx", "quest", { title = q.title, reward = q.reward })
		run.quest = { i = run.quest.i + 1, p = 0 }
		skipLocked(run)
		-- the next quest may already be done (e.g. you bought the scissors early)
		local nextQ = Config.QUESTS[run.quest.i]
		if nextQ and nextQ.event == "tool" then
			Quests.event(player, "tool", Config.bestTool(run, data.tools))
		elseif nextQ and nextQ.event == "bag" and (run.bag or 0) > 0 then
			Quests.event(player, "bag", run.bag)
		end
	end
	PlayerData.changed(player)
end

-- What the HUD shows.
function Quests.view(run)
	run.quest = run.quest or { i = 1, p = 0 }
	skipLocked(run)
	local state = run.quest
	local q = Config.QUESTS[state.i]
	if not q then
		return nil
	end
	return { index = state.i, total = #Config.QUESTS, title = q.title, hint = q.hint, progress = math.min(state.p, q.goal), goal = q.goal }
end

return Quests
