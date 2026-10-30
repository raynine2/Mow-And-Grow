local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.BossView
local s = m.Source
if string.find(s, [======[BossLife]======], 1, true) then
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
	{ [======[local BossMoves = require(Shared:WaitForChild("BossMoves"))
]======], [======[local BossMoves = require(Shared:WaitForChild("BossMoves"))
-- (30 Oct) a life of their own for the one-piece bosses: breathing, a rocking walk, watching you, fidgets
local BossLife = require(script.Parent:WaitForChild("BossLife"))
]======] },
	{ [======[	local base = placement(v, dt)
	-- the overlay: about the feet, squash keeps the volume
	-- (29 Oct) a one-piece ForgeGUI model (rig.solid) stands on its own ground disc: it leans and squashes less, so
	-- the disc doesn't lift off the floor
	local soft = if v.rig.solid then 0.35 else 1
	local sy = 1 + (v.squash.x - 1) * (if v.rig.solid then 0.5 else 1)
	local sxz = 1 / math.sqrt(math.max(0.3, sy))
	local sz = v.size.x
	local jitter = if v.shake > 0 then Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * v.shake * 2 else Vector3.zero
	local overlay = CFrame.new(Vector3.new(0, v.lift.x, -v.fwd.x) + jitter)
		* CFrame.Angles(-v.pitch.x * soft, v.twist.x, v.roll.x * soft)
]======], [======[	local base = placement(v, dt)
	-- the overlay: about the feet, squash keeps the volume
	-- (29 Oct) a one-piece ForgeGUI model (rig.solid) stands on its own ground disc: it leans and squashes less, so
	-- the disc doesn't lift off the floor
	-- (30 Oct, owner: "the bosses are very stiff and dont do alot they are just a statue") client/BossLife gives a
	-- one-piece model a life of its own on top of the moves (breathing, swaying, a rocking walk, watching you,
	-- growls and stomps between moves) and lets the moves lean it much further: it rocks on its disc's rim
	-- (BossLife.rim), so the disc never sinks into the floor or floats
	local life = if v.rig.solid then BossLife.step(v, dt) else nil
	local soft = if life then life.soft else 1
	local sy = (1 + (v.squash.x - 1) * (if life then life.squash else 1)) * (if life then life.sy else 1)
	local sxz = 1 / math.sqrt(math.max(0.3, sy))
	local sz = v.size.x
	local jitter = if v.shake > 0 then Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * v.shake * 2 else Vector3.zero
	local pitch = v.pitch.x * soft + (if life then life.pitch else 0)
	local roll = v.roll.x * soft + (if life then life.roll else 0)
	local lift = v.lift.x + (if life then life.lift + BossLife.rim(v, pitch, roll) else 0)
	local overlay = CFrame.new(Vector3.new(0, lift, -v.fwd.x) + jitter)
		* CFrame.Angles(-pitch, v.twist.x + (if life then life.twist else 0), roll)
]======] },
	{ [======[	v.pitch.v -= if big then 1.6 else 0.7
	v.squash.v -= if big then 1.2 else 0.5
	v.shake = math.max(v.shake, (if big then 0.2 else 0.08) * v.scale / 5)
end
]======], [======[	v.pitch.v -= if big then 1.6 else 0.7
	v.squash.v -= if big then 1.2 else 0.5
	v.shake = math.max(v.shake, (if big then 0.2 else 0.08) * v.scale / 5)
	BossLife.flinch(v, big) -- (30 Oct) a one-piece boss shudders too
end
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
