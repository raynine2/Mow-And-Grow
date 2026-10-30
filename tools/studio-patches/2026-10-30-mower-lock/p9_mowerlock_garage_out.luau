local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.MowerLock
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if hashOf(s) ~= "19072 1052337618" then
	return "NOT CHANGED: " .. m.Name .. " is " .. hashOf(s)
end
local edits = {
	{ [======[		return floor + Vector3.new(0, (BODY.Y / 2 + 2.6) * s, 0), floor, 3.4, s
]======], [======[		return floor + Vector3.new(0, (BODY.Y / 2 + 2.6) * s, 0), floor, 3, s
]======] },
	{ [======[		-- in front of the garage's open door: a big lock over the bay
		local floor = ground(holder.Position)
]======], [======[		-- in front of the garage's door, clear of it as it turns (a big lock over the bay), the sign in front of the
		-- facade's beam
		local floor = ground(holder.Position + outward(holder) * 4.2)
]======] },
	{ [======[

local function placeFor(kind: string, holder: BasePart): (Vector3, Vector3, number, number)
]======], [======[

-- which way the garage's door looks out: of the prompt's front and back, the side with open air (the other side is the
-- shutter, right behind it)
local function outward(holder: BasePart): Vector3
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { folder, holder }
	if player.Character then
		table.insert(skip, player.Character)
	end
	rp.FilterDescendantsInstances = skip
	local look = holder.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return Vector3.zero
	end
	flat = flat.Unit
	local function free(d: Vector3): number
		local hit = workspace:Raycast(holder.Position + Vector3.new(0, 1.5, 0), d * 14, rp)
		return if hit then hit.Distance else 14
	end
	return if free(-flat) > free(flat) then -flat else flat
end

local function placeFor(kind: string, holder: BasePart): (Vector3, Vector3, number, number)
]======] },
}
for k, e in edits do
	local i, j = string.find(s, e[1], 1, true)
	if not i or string.find(s, e[1], j + 1, true) then
		return "edit " .. k .. ": not found once"
	end
	s = string.sub(s, 1, i - 1) .. e[2] .. string.sub(s, j + 1)
end
if hashOf(s) ~= "19989 1536906607" then
	return "NOT CHANGED (result would be " .. hashOf(s) .. ")"
end
m.Source = s
return m.Name .. " done: " .. hashOf(s)
