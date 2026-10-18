-- The onboarding quest chain (Config.QUESTS), tracked per run in profile.run.quest = { i = index, p = progress }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)

local Quests = {}

local ABSOLUTE = { tool = true } -- these report a level reached, not an amount gained

-- Something happened that quests may count. For "tool", amount is the new best tool index.
function Quests.event(player: Player, kind: string, amount: number?)
	local data = PlayerData.get(player)
	local run = data and data.run
	if not run then
		return
	end
	run.quest = run.quest or { i = 1, p = 0 }
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
		-- the next quest may already be done (e.g. you bought the scissors early)
		local nextQ = Config.QUESTS[run.quest.i]
		if nextQ and nextQ.event == "tool" then
			Quests.event(player, "tool", run.tool)
		end
	end
	PlayerData.changed(player)
end

-- What the HUD shows.
function Quests.view(run)
	local state = run.quest or { i = 1, p = 0 }
	local q = Config.QUESTS[state.i]
	if not q then
		return nil
	end
	return { index = state.i, total = #Config.QUESTS, title = q.title, hint = q.hint, progress = math.min(state.p, q.goal), goal = q.goal }
end

return Quests
