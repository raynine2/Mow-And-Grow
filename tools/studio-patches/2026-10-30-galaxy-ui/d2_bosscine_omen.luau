local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossCine
local s = m.Source
if string.find(s, [======[local Omen = require(script.Parent.BossOmen)]======], 1, true) then
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
	{ [======[local BossAdds = require(script.Parent.BossAdds) -- the minions
]======], [======[local BossAdds = require(script.Parent.BossAdds) -- the minions
local Omen = require(script.Parent.BossOmen) -- (30 Oct) the scary wake-up, the roar's impact frames
]======] },
	{ [======[H.bossReady = function(d)
	beam(d.pos, zoneColor(d.z))
]======], [======[H.bossReady = function(d)
	-- (30 Oct, owner: "make better fx with boss spawning to make it feel more scary") client/BossOmen: the eye, the
	-- bleeding screen, the summoning circle and dark beam on the pad, the thorned banner (it plays the roar too); the old
	-- beam and card when it can't
	local ok, shown = pcall(Omen.awake, d)
	if ok and shown then
		clearBeam()
		return
	end
	beam(d.pos, zoneColor(d.z))
]======] },
	{ [======[H.bossIntro = function(d)
	clearBeam()
]======], [======[H.bossIntro = function(d)
	clearBeam()
	Omen.clear()
]======] },
	{ [======[			Sound.play("roar", 0.05, 1)
]======], [======[			Sound.play("roar", 0.05, 1)
			Omen.roar(d.z) -- (the impact frames)
]======] },
	{ [======[			Sound.play("roar", 0.05, 0.9)
]======], [======[			Sound.play("roar", 0.05, 0.9)
			Omen.roar(d.z, true)
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
