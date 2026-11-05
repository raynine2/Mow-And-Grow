-- The onboarding quest chain (Config.QUESTS), tracked per run in profile.run.quest = { i = index, p = progress }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local Quests = {}

local ABSOLUTE = { tool = true, bag = true, zone = true, boss = true } -- these report a level reached, not an amount gained
-- (6 Nov) areas cleared and bosses beaten are counted for the whole run (run.counts), so a quest that becomes active
-- after its area was already cleared (in a party, or while you were still on an earlier step) completes straight
-- away instead of waiting for the next area; "Mow the whole <area 2>" is goal 2 (shared/Config QUESTS)
local COUNTED = { zone = true, boss = true }

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
	if COUNTED[kind] and (amount or 1) > 0 and not (run.quest :: any).recheck then
		run.counts = run.counts or {}
		run.counts[kind] = (run.counts[kind] or 0) + (amount or 1)
		amount = run.counts[kind]
	end
	local q = Config.QUESTS[run.quest.i]
	if not q or q.event ~= kind then
		PlayerData.changed(player)
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
		elseif nextQ and COUNTED[nextQ.event] and run.counts and (run.counts[nextQ.event] or 0) > 0 then
			-- (a re-check with the run's count, not a new area or boss: don't count it again)
			(run.quest :: any).recheck = true
			Quests.event(player, nextQ.event, run.counts[nextQ.event])
			if run.quest then
				(run.quest :: any).recheck = nil
			end
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
