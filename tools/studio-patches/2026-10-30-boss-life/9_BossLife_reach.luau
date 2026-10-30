local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossLife
local s = m.Source
if string.find(s, [======[F.reach or 0.6]======], 1, true) then
	return m.Name .. " already has this patch"
end
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local edits = {
	{ [======[--   voice: its growl's pitch (lower = bigger)
local DEFAULT = { fidgets = { look = 2, growl = 2, stomp = 1 }, waddle = 0.1, stride = 1.4, breath = 0.32, sway = 0.04, twitch = 0, voice = 0.9 }
local FEEL: { [string]: any } = {
]======], [======[--   voice: its growl's pitch (lower = bigger)
--   reach: how far a jointed boss's arms swing (1 = up over its head; less where the cut pieces would show a gap)
local DEFAULT = { fidgets = { look = 2, growl = 2, stomp = 1 }, waddle = 0.1, stride = 1.4, breath = 0.32, sway = 0.04, twitch = 0, voice = 0.9, reach = 0.6 }
local FEEL: { [string]: any } = {
]======] },
	{ [======[	-- the Dandelion King: proud, looks round his valley, a royal growl
	dandelion = { fidgets = { look = 3, growl = 2, shake = 1, stomp = 1 }, waddle = 0.09, stride = 1.5, breath = 0.32, sway = 0.035, twitch = 0, voice = 0.95 },
	-- the Harvest Reaper: a scarecrow that twitches and jerks its head round
]======], [======[	-- the Dandelion King: proud, looks round his valley, a royal growl
	dandelion = { fidgets = { look = 3, growl = 2, shake = 1, stomp = 1 }, waddle = 0.09, stride = 1.5, breath = 0.32, sway = 0.035, twitch = 0, voice = 0.95, reach = 0 },
	-- the Harvest Reaper: a scarecrow that twitches and jerks its head round
]======] },
	{ [======[	-- the Harvest Reaper: a scarecrow that twitches and jerks its head round
	harvest = { fidgets = { look = 3, shake = 2, growl = 1 }, waddle = 0.11, stride = 1.7, breath = 0.28, sway = 0.05, twitch = 0.7, voice = 1.1 },
	-- the sakura spirit: light on its feet, sways a lot
]======], [======[	-- the Harvest Reaper: a scarecrow that twitches and jerks its head round
	harvest = { fidgets = { look = 3, shake = 2, growl = 1 }, waddle = 0.11, stride = 1.7, breath = 0.28, sway = 0.05, twitch = 0.7, voice = 1.1, reach = 0.55 },
	-- the sakura spirit: light on its feet, sways a lot
]======] },
	{ [======[	-- the sakura spirit: light on its feet, sways a lot
	sakura = { fidgets = { look = 3, growl = 1, shake = 1, hop = 1 }, waddle = 0.07, stride = 1.5, breath = 0.27, sway = 0.045, twitch = 0, voice = 1.15 },
	-- the bramble golem: heavy, stomps
]======], [======[	-- the sakura spirit: light on its feet, sways a lot
	sakura = { fidgets = { look = 3, growl = 1, shake = 1, hop = 1 }, waddle = 0.07, stride = 1.5, breath = 0.27, sway = 0.045, twitch = 0, voice = 1.15, reach = 0.75 },
	-- the bramble golem: heavy, stomps
]======] },
	{ [======[	-- the bramble golem: heavy, stomps
	bramble = { fidgets = { stomp = 3, growl = 2, look = 1 }, waddle = 0.13, stride = 1.2, breath = 0.34, sway = 0.03, twitch = 0, voice = 0.8 },
	-- the bog slime: wobbles, hops
]======], [======[	-- the bramble golem: heavy, stomps
	bramble = { fidgets = { stomp = 3, growl = 2, look = 1 }, waddle = 0.13, stride = 1.2, breath = 0.34, sway = 0.03, twitch = 0, voice = 0.8, reach = 0.6 },
	-- the bog slime: wobbles, hops
]======] },
	{ [======[	-- the bog slime: wobbles, hops
	bog = { fidgets = { hop = 3, shake = 2, growl = 1 }, waddle = 0.05, stride = 1.6, hop = true, breath = 0.45, sway = 0.03, twitch = 0, voice = 0.75 },
	-- the bunker beast (the Frost Thornback): heavy, stomps and snorts
]======], [======[	-- the bog slime: wobbles, hops
	bog = { fidgets = { hop = 3, shake = 2, growl = 1 }, waddle = 0.05, stride = 1.6, hop = true, breath = 0.45, sway = 0.03, twitch = 0, voice = 0.75, reach = 0.5 },
	-- the bunker beast (the Frost Thornback): heavy, stomps and snorts
]======] },
	{ [======[	-- the bunker beast (the Frost Thornback): heavy, stomps and snorts
	bunker = { fidgets = { stomp = 2, growl = 2, shake = 1 }, waddle = 0.12, stride = 1.25, breath = 0.33, sway = 0.03, twitch = 0, voice = 0.85 },
	-- the hollow one: creepy, jerky
]======], [======[	-- the bunker beast (the Frost Thornback): heavy, stomps and snorts
	bunker = { fidgets = { stomp = 2, growl = 2, shake = 1 }, waddle = 0.12, stride = 1.25, breath = 0.33, sway = 0.03, twitch = 0, voice = 0.85, reach = 0.6 },
	-- the hollow one: creepy, jerky
]======] },
	{ [======[	-- the hollow one: creepy, jerky
	hollow = { fidgets = { shake = 2, look = 2, growl = 2 }, waddle = 0.1, stride = 1.4, breath = 0.3, sway = 0.05, twitch = 0.9, voice = 0.9 },
	-- the jungle titan: the biggest and slowest, the ground shakes
]======], [======[	-- the hollow one: creepy, jerky
	hollow = { fidgets = { shake = 2, look = 2, growl = 2 }, waddle = 0.1, stride = 1.4, breath = 0.3, sway = 0.05, twitch = 0.9, voice = 0.9, reach = 0.55 },
	-- the jungle titan: the biggest and slowest, the ground shakes
]======] },
	{ [======[	-- the jungle titan: the biggest and slowest, the ground shakes
	jungle = { fidgets = { stomp = 3, growl = 2, look = 1 }, waddle = 0.12, stride = 1.1, breath = 0.3, sway = 0.03, twitch = 0, voice = 0.7 },
}
]======], [======[	-- the jungle titan: the biggest and slowest, the ground shakes
	jungle = { fidgets = { stomp = 3, growl = 2, look = 1 }, waddle = 0.12, stride = 1.1, breath = 0.3, sway = 0.03, twitch = 0, voice = 0.7, reach = 1 },
}
]======] },
	{ [======[	local act = v.action and v.action.name
	local P = v.pitch.x -- the moves' lean (- = rearing back, + = thrown forward)
]======], [======[	local act = v.action and v.action.name
	-- (30 Oct evening, owner: "some things are very buggy and glitched", a picture of the Dandelion King's staff
	-- flying off its fist) every arm swing is scaled by the boss's reach and clamped, so a cut piece never swings so
	-- far that it parts from the body or a thing it holds leaves the hand
	local reach = F.reach or 0.6
	local P = v.pitch.x -- the moves' lean (- = rearing back, + = thrown forward)
]======] },
	{ [======[	local P = v.pitch.x -- the moves' lean (- = rearing back, + = thrown forward)
	local pose = if P < 0 then -P * 8.5 else P * 1.6
	local roar = math.max(0, v.squash.x - 1.06) * 4 -- stretched tall for a roar: arms thrown wide
	local swing = if F.hop then 0 else 0.55 * math.sin(L.phase) * math.min(g, 1)
	local dead = if act == "death" then 1 else 0
]======], [======[	local P = v.pitch.x -- the moves' lean (- = rearing back, + = thrown forward)
	local pose = (if P < 0 then -P * 8.5 else P * 1.6) * reach
	local roar = math.max(0, v.squash.x - 1.06) * 4 * reach -- stretched tall for a roar: arms thrown wide
	local swing = if F.hop then 0 else 0.5 * math.sin(L.phase) * math.min(g, 1) * reach
	local dead = if act == "death" then 1 else 0
]======] },
	{ [======[	local dead = if act == "death" then 1 else 0
	local armBase = 0.12 + 0.05 * b * idle
	local wantL = armBase + pose + swing + (L.fArmL or 0) - 0.3 * dead
	local wantR = armBase + pose - swing + (L.fArmR or 0) - 0.3 * dead
	local wantSpread = 0.06 + 0.04 * b * idle + roar + (L.fSpread or 0) + 0.35 * L.quake
	-- the head: the nearest fighter (a jointed boss turns its head more than its body), a nod per step, down when it dies
]======], [======[	local dead = if act == "death" then 1 else 0
	local armBase = (0.12 + 0.05 * b * idle) * reach
	local wantL = armBase + pose + swing + (L.fArmL or 0) * reach - 0.3 * dead * reach
	local wantR = armBase + pose - swing + (L.fArmR or 0) * reach - 0.3 * dead * reach
	local wantSpread = (0.06 + 0.04 * b * idle + (L.fSpread or 0) + 0.35 * L.quake) * reach + roar
	-- the head: the nearest fighter (a jointed boss turns its head more than its body), a nod per step, down when it dies
]======] },
	{ [======[	local wantYaw = L.lookWant * idle * alive * 0.75 + (L.fHeadYaw or 0) + (L.jerkT or 0) * 2
	local wantNod = 0.06 * math.sin(2 * L.phase) * math.min(g, 1) - P * 0.8 + (L.fHeadNod or 0) - 0.25 * L.quake + 0.6 * dead
	L.fArmL, L.fArmR, L.fSpread, L.fHeadYaw, L.fHeadNod = 0, 0, 0, 0, 0
]======], [======[	local wantYaw = L.lookWant * idle * alive * 0.75 + (L.fHeadYaw or 0) + (L.jerkT or 0) * 2
	local wantNod = 0.05 * math.sin(2 * L.phase) * math.min(g, 1) - P * 0.6 + (L.fHeadNod or 0) - 0.2 * L.quake + 0.4 * dead
	L.fArmL, L.fArmR, L.fSpread, L.fHeadYaw, L.fHeadNod = 0, 0, 0, 0, 0
]======] },
	{ [======[	L.fArmL, L.fArmR, L.fSpread, L.fHeadYaw, L.fHeadNod = 0, 0, 0, 0, 0
	local aL = follow(L.armL, math.clamp(wantL, -0.8, 2.9), dt, 2.6, 0.55)
	local aR = follow(L.armR, math.clamp(wantR, -0.8, 2.9), dt, 2.6, 0.55)
	local sp = follow(L.spread, math.clamp(wantSpread, -0.1, 1.2), dt, 2.2, 0.6)
	local hy = follow(L.headYaw, math.clamp(wantYaw, -0.9, 0.9), dt, 1.6, 0.6)
	local hn = follow(L.headNod, math.clamp(wantNod, -0.6, 0.7), dt, 2, 0.6)
	local T = L.turns
]======], [======[	L.fArmL, L.fArmR, L.fSpread, L.fHeadYaw, L.fHeadNod = 0, 0, 0, 0, 0
	local top = 2.7 * reach
	local aL = follow(L.armL, math.clamp(wantL, -0.5 * reach, top), dt, 2.6, 0.6)
	local aR = follow(L.armR, math.clamp(wantR, -0.5 * reach, top), dt, 2.6, 0.6)
	local sp = follow(L.spread, math.clamp(wantSpread, -0.05, 0.9 * reach), dt, 2.2, 0.65)
	local hy = follow(L.headYaw, math.clamp(wantYaw, -0.6, 0.6), dt, 1.6, 0.65)
	local hn = follow(L.headNod, math.clamp(wantNod, -0.35, 0.45), dt, 2, 0.65)
	local T = L.turns
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "NOT CHANGED: edit " .. k .. " not found once in " .. m.Name
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
