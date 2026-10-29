local results = {}
do
	local ok, r = pcall(function()
local m = game.ServerScriptService.MowALawn.Run
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "44430 2142402418" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[						data.run.time = (data.run.time or 0) + 1
					end
]======], [======[						data.run.time = (data.run.time or 0) + 1
					end
					if data and data.run and beat % 4 == 0 then
						Net.send(p, "Fx", "runClock", { time = data.run.time or 0, held = watching })
					end
]======] },
	{ [======[			if started and not completing then
				local now = os.clock()
]======], [======[			if started and not completing then
				beat += 1
				local now = os.clock()
]======] },
	{ [======[	-- watch the opening film (filmUntil)
	task.spawn(function()
		while true do
			task.wait(1)
]======], [======[	-- watch the opening film (filmUntil)
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(1)
]======] },
	{ [======[	-- watch the opening film (filmUntil)
]======], [======[	-- watch the opening film (filmUntil). (29 Oct, the bug sweep: the HUD only heard the time when something else
	-- changed, so its timer stopped while you walked about.) Every few seconds each player's HUD hears it too.
]======] },
	{ [======[		boss = Boss.state(),
		sellPos = info and info.sellPos,
]======], [======[		boss = Boss.state(),
		-- (29 Oct, the bug sweep) the area is mowed and its boss waits on the summon pad (the HUD's card said "Mow it
		-- all to open ..." over a mowed area)
		bossWaiting = Boss.waiting(zone),
		sellPos = info and info.sellPos,
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "44975 1537369329" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
	end)
	table.insert(results, (if ok then r else "ERROR p_run.luau: " .. tostring(r)))
end
do
	local ok, r = pcall(function()
local m = game.ServerScriptService.MowALawn.Boss
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "60903 706757302" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[	Net.all("Fx", "bossReady", { z = z, pos = arena.padPos, name = Config.ZONES[z].boss.name })
	task.spawn(function()
]======], [======[	Net.all("Fx", "bossReady", { z = z, pos = arena.padPos, name = Config.ZONES[z].boss.name })
	changed() -- (29 Oct) the HUD's area card says the boss is waiting
	task.spawn(function()
]======] },
	{ [======[

-- Area z is mowed: its boss wakes and the summon pad lights up (once per run).
]======], [======[

-- (29 Oct, the bug sweep) Whether area z is mowed and its boss waits on the summon pad: awake and not fought yet, or
-- waiting again after the party went down. (server/Run's world state: the HUD's area card says so.)
function Boss.waiting(z: number): boolean
	return ready[z] == true and not beaten[z] and (current == nil or current.z ~= z)
end

-- Area z is mowed: its boss wakes and the summon pad lights up (once per run).
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "61319 178453170" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
	end)
	table.insert(results, (if ok then r else "ERROR p_boss.luau: " .. tostring(r)))
end
do
	local ok, r = pcall(function()
local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Hud
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "37827 1655588847" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[			timerText.Text = Format.clock(runTime + math.min(os.clock() - runTimeAt, 5))
]======], [======[			local t = runTime + (if runHeld then 0 else math.min(os.clock() - runTimeAt, 12))
			-- (never back by a second or two: the server's seconds run a touch long, so it waits for them instead)
			if t < shownTime and shownTime - t < 3 then
				t = shownTime
			end
			shownTime = t
			timerText.Text = Format.clock(t)
]======] },
	{ [======[		task.wait(0.5)
]======], [======[		task.wait(0.25)
]======] },
	{ [======[		trackText.Text = "BOSS FIGHT!"
	else
]======], [======[		trackText.Text = "BOSS FIGHT!"
	elseif w.bossWaiting then
		-- (29 Oct, the bug sweep) the area is mowed and its boss waits on the summon pad: the card said "100.0%
		-- cleared" and "Mow it all to open ..." with nothing left to mow
		local here = Config.ZONES[w.zone or 1]
		local bossName = if here and here.boss then here.boss.name else "boss"
		fill.BackgroundColor3 = C.orange
		fillGrad.Color = ColorSequence.new(UI.shade(C.orange, 1.15), UI.shade(C.orange, 0.85))
		fill.Size = UDim2.fromScale(1, 1)
		trackText.Text = "BOSS AWAKE!"
		nextText.Text = if nextZone and (w.zone or 1) < zones then ("Beat the %s to open %s"):format(bossName, nextZone.name) else ("Beat the %s!"):format(bossName)
	else
]======] },
	{ [======[		runTime, runTimeAt = d.run.time, os.clock()
]======], [======[		runTime, runTimeAt, runHeld = d.run.time, os.clock(), false
	elseif d.mode == "Run" and not d.run then
		runTime = -1 -- the run is over: the timer stops where it is
	end
end)
State.on("fx", function(kind: string, p: any)
	if kind == "runClock" and type(p) == "table" and type(p.time) == "number" then
		runTime, runTimeAt, runHeld = p.time, os.clock(), p.held == true
]======] },
	{ [======[-- the timer shows your own run time (server/Run counts it); it ticks here between updates
local runTime, runTimeAt = -1, 0
]======], [======[-- the timer shows your own run time (server/Run counts it); it ticks here between updates. (29 Oct, the bug sweep:
-- it stopped 5 s after the last update, and updates only came when something else changed, so it froze while you
-- walked about. server/Run now sends the time every few seconds, "held" while the opening film holds the clock.)
local runTime, runTimeAt, runHeld = -1, 0, false
local shownTime = -1
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "39348 151659687" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
	end)
	table.insert(results, (if ok then r else "ERROR p_hud.luau: " .. tostring(r)))
end
do
	local ok, r = pcall(function()
local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.RarityFx
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "58138 1195025023" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[			if shownFor ~= window and left > 20 then
]======], [======[			-- (29 Oct, the bug sweep) not over a new player's "YOUR FIRST LAWN IS READY!" card (client/FirstLawn): the
			-- banner waits until that card is gone
			local cardUp = require(script.Parent.UI).gui:FindFirstChild("FirstLawn") ~= nil
			if shownFor ~= window and left > 20 and not cardUp then
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "58390 688338957" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
	end)
	table.insert(results, (if ok then r else "ERROR p_rarity.luau: " .. tostring(r)))
end
do
	local ok, r = pcall(function()
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local OLD = [==[local last_id = 0

function utility.getRanomId()
  last_id += 1
  return tostring(last_id)
end]==]
local NEW = [==[local last_id = 0
-- (Mow A Lawn, 29 Oct) the place has two copies of this library (VFXLib.ForgeEmit and EmitModule) and each counted
-- from 1, so their render-step names ("1", "2", ...) collided: one copy could unbind the other's effects. Each copy's
-- ids now start with a prefix of its own.
local ID_PREFIX = game:GetService("HttpService"):GenerateGUID(false) .. "_"

function utility.getRanomId()
  last_id += 1
  return ID_PREFIX .. tostring(last_id)
end]==]
local out = {}
for _, row in {
	{ game.ReplicatedStorage.VFXLib.ForgeEmit.mod.utility, "14165 1900337891", "14536 2061431077", "\r\n" },
	{ game.ReplicatedStorage.EmitModule.mod.utility, "13540 84355585", "13907 1037940973", "\n" },
} do
	local m, before, after, nl = row[1], row[2], row[3], row[4]
	local s = m.Source
	if hashOf(s) ~= before then
		table.insert(out, "NOT CHANGED: " .. m:GetFullName() .. " is " .. hashOf(s))
		continue
	end
	local o = (string.gsub(OLD, "\n", nl))
	local n = (string.gsub(NEW, "\n", nl))
	local i, j = string.find(s, o, 1, true)
	if not i or string.find(s, o, j + 1, true) then
		table.insert(out, m:GetFullName() .. ": not found once")
		continue
	end
	s = string.sub(s, 1, i - 1) .. n .. string.sub(s, j + 1)
	if hashOf(s) ~= after then
		table.insert(out, "NOT CHANGED " .. m:GetFullName() .. " (result would be " .. hashOf(s) .. ")")
		continue
	end
	m.Source = s
	table.insert(out, m:GetFullName() .. " done: " .. hashOf(s))
end
return table.concat(out, "\n")
	end)
	table.insert(results, (if ok then r else "ERROR p_vfx.luau: " .. tostring(r)))
end
return table.concat(results, "\n")
