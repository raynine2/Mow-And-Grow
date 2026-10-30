local m = game.ServerScriptService.MowALawn.Boss
local s = m.Source
if string.find(s, [======[local function prowl]======], 1, true) then
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
	{ [======[local function fightLoop(f: Fight)
]======], [======[-- (30 Oct, owner: "the bosses are very stiff and dont do alot they are just a statue") between moves the boss
-- doesn't stand there: it gets its breath back, then turns to one of the fighters and stalks towards them (stopping
-- short of them), so the next move comes from somewhere new. client/BossLife rocks it from side to side as it goes.
-- It stays put while it's open, underground, or while something it set going (a beam, a ring) still runs.
local function prowl(f: Fight, t: number): boolean
	local P = (Config :: any).BOSS_PROWL
	if not P then
		return hold(f, t)
	end
	local untilT = os.clock() + t
	if not hold(f, math.min(t, P.pause)) then
		return false
	end
	local list = targets(f)
	local prey: Player? = if #list > 0 then list[rng:NextInteger(1, #list)] else nil
	local speed = P.speed * f.moves.height / 40
	local last = os.clock()
	while os.clock() < untilT do
		task.wait(math.min(0.15, math.max(0.01, untilT - os.clock())))
		if not live(f) then
			return false
		end
		local dt = os.clock() - last
		last = os.clock()
		local root = prey and rootOf(prey)
		if root and f.state == "fight" and not f.hidden and #f.movers == 0 and os.clock() >= f.openUntil and BossFighters.standing(prey :: Player) then
			local pos = f.cf.Position
			local to = flat(root.Position - pos)
			local gap = to.Magnitude - (f.bodyR + P.keep)
			if gap > 0.5 then
				local dir = to.Unit
				local nextPos = onFloor(f, pos + dir * math.min(speed * dt, gap), f.bodyR * 0.7 + 4)
				f.cf = CFrame.lookAt(nextPos, nextPos + dir)
				mirror:SetAttribute("Cf", f.cf)
			else
				face(f, root.Position)
			end
		end
	end
	return live(f)
end

local function fightLoop(f: Fight)
]======] },
	{ [======[					hold(f, f.curve.gap * (if f.phase == 2 then 0.6 else 1) * rng:NextNumber(0.85, 1.25))]======], [======[					prowl(f, f.curve.gap * (if f.phase == 2 then 0.6 else 1) * rng:NextNumber(0.85, 1.25))]======] },
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
