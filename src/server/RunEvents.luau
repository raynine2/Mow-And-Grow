-- The run's extras (owner, 29 Oct, after balance pass 2: "Elder Clump", "Golden Hour", "speed challenges per area",
-- "mower upgrades", "party bonus": build them). Tuning in Config.ELDER / GOLDEN_HOUR / AREA_CHALLENGE / PARTY_BONUS.
--   * ELDER CLUMP: one clump per area grows much bigger and tougher (server/Field picks and builds it). It doesn't
--     count toward clearing the area: it's a bonus to chop down together, and when it falls everyone in the run
--     gets coins and gems (here).
--   * GOLDEN HOUR: every few minutes, for 45 s, new clumps roll their mutation with x3 luck (server/Stats reads the
--     workspace attribute GoldenHourUntil, a server time).
--   * AREA SPEED CHALLENGE: an area cleared within its par time of opening pays everyone gems. The workspace
--     attribute Challenge = "zone|end server time|gems|on/won/late". Not for the run's first area: a first-timer is
--     still loading, learning and watching the opening there.
--   * (the mower upgrades are Config.UPGRADES' "Mower" section, applied in server/ClassPerks.mower; the party bonus
--     is in server/Stats)
-- client/RunEvents draws all of it. Server-only state; nothing here trusts a client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.MowALawn.Config)
local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local Field = require(script.Parent.Field)

local RunEvents = {}
local started = false

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Everyone in the run, with their profile.
local function inRun(): { { p: Player, data: any } }
	local out = {}
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data and data.run then
			table.insert(out, { p = p, data = data })
		end
	end
	return out
end

-------------------------------------------------------------------------------------------------------------
-- Elder Clump
-------------------------------------------------------------------------------------------------------------
-- server/Field calls this when an area's Elder Clump falls (`by` landed the last hit).
local function elderFelled(by: Player, patch: any)
	local E = Config.ELDER
	local z = patch.z
	local def = Config.ZONES[z]
	if not E or not def then
		return
	end
	for _, e in inRun() do
		local s = Stats.compute(e.p, e.data)
		local coins = math.floor(def.value * E.coins * s.sell + 0.5)
		local gems = math.floor((E.gems[z] or E.gems[#E.gems]) * s.gems + 0.5)
		e.data.run.coins += coins
		e.data.gems += gems
		e.data.stats.coinsEarned = (e.data.stats.coinsEarned or 0) + coins
		PlayerData.changed(e.p)
		Net.send(e.p, "Fx", "elderDown", {
			z = z,
			by = by.DisplayName,
			mine = e.p == by,
			coins = coins,
			gems = gems,
			pos = patch.part.Position,
		})
	end
end

-------------------------------------------------------------------------------------------------------------
-- Golden Hour
-------------------------------------------------------------------------------------------------------------
local function startGolden()
	local G = Config.GOLDEN_HOUR
	local untilT = now() + G.length
	workspace:SetAttribute("GoldenHourUntil", untilT)
	Net.all("Fx", "goldenHour", { untilT = untilT, luck = G.luck, length = G.length })
end

local function goldenLoop()
	local G = Config.GOLDEN_HOUR
	if not G then
		return
	end
	local nextAt = os.clock() + G.firstAfter
	while true do
		task.wait(1)
		-- (Studio: the Workspace attribute GoldenHourNow = true starts one now, for testing)
		local force = RunService:IsStudio() and workspace:GetAttribute("GoldenHourNow") == true
		if force then
			workspace:SetAttribute("GoldenHourNow", nil)
		end
		if force or os.clock() >= nextAt then
			nextAt = os.clock() + G.every
			startGolden()
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- area speed challenge
-------------------------------------------------------------------------------------------------------------
local function setChallenge(z: number, endsAt: number, gems: number, state: string)
	workspace:SetAttribute("Challenge", ("%d|%.2f|%d|%s"):format(z, endsAt, gems, state))
end

local function challengeLoop(firstZone: number)
	local C = Config.AREA_CHALLENGE
	if not C then
		return
	end
	local cur: number? = nil
	local endsAt, gems, state = 0, 0, ""
	while true do
		task.wait(0.5)
		local z = Field.unlocked
		if z ~= cur and z > firstZone and (Field.totals[z] or 0) > 0 then
			-- a new area just opened: its clock starts now (the walk there counts)
			cur = z
			endsAt = now() + (C.par[z] or 240)
			gems = C.gems[z] or 10
			state = "on"
			setChallenge(z, endsAt, gems, state)
		end
		if cur and state == "on" then
			if Field.remainingIn(cur) <= 0 then
				if now() <= endsAt then
					state = "won"
					for _, e in inRun() do
						local got = math.floor(gems * Stats.compute(e.p, e.data).gems + 0.5)
						e.data.gems += got
						PlayerData.changed(e.p)
						Net.send(e.p, "Fx", "challenge", { z = cur, won = true, gems = got })
					end
				else
					state = "late"
				end
				setChallenge(cur, endsAt, gems, state)
			elseif now() > endsAt then
				state = "late"
				setChallenge(cur, endsAt, gems, state)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- the Elder Clump of a newly opened area is announced
-------------------------------------------------------------------------------------------------------------
local function elderLoop(firstZone: number)
	-- (not the run's first area: a first-timer has enough to take in there; its beam still shows)
	local told: { [number]: boolean } = { [firstZone] = true }
	while true do
		task.wait(1)
		local z = Field.unlocked
		local e = Field.elders[z]
		if e and not e.cut and not told[z] then
			told[z] = true
			task.delay(4, function() -- (after the area's own "now open" banner)
				Net.all("Fx", "elderUp", { z = z, name = Config.ZONES[z].name, pos = e.part.Position })
			end)
		end
	end
end

-- Run.start calls this once its hooks are in (the field is built a moment later).
function RunEvents.start()
	if started then
		return
	end
	started = true
	workspace:SetAttribute("GoldenHourUntil", nil)
	workspace:SetAttribute("Challenge", nil)
	Field.onElder = elderFelled
	task.spawn(function()
		-- wait for the whole field (server/Run builds it once the host's save says where to start; the last area
		-- comes last and Field.unlocked is set right after it)
		while not Field.totals[#Config.ZONES] do
			task.wait(0.5)
		end
		task.wait(2)
		local firstZone = Field.unlocked
		for _, loop in { goldenLoop, elderLoop } do
			task.spawn(function()
				local ok, err = pcall(loop, firstZone)
				if not ok then
					warn("[RunEvents] " .. tostring(err))
				end
			end)
		end
		local ok, err = pcall(challengeLoop, firstZone)
		if not ok then
			warn("[RunEvents] challenge: " .. tostring(err))
		end
	end)
end

return RunEvents
