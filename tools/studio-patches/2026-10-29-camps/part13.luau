local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
local ss = game:GetService("ServerStorage")
local buf = ss:FindFirstChild("ClaudePatchBuf")
if not buf then
	buf = Instance.new("Folder")
	buf.Name = "ClaudePatchBuf"
	buf.Parent = ss
end
local bad = {}
local function put(name, text, want)
	if hashOf(text) ~= want then
		table.insert(bad, name .. " garbled")
		return
	end
	local v = buf:FindFirstChild(name) or Instance.new("StringValue")
	v.Name = name
	v.Value = text
	v.Parent = buf
end

put("CampLife.3", [====[			turn(r, "armR", CFrame.Angles(-math.sin(t * 1.4) * 0.05, 0, 0.06))
		end
		bob += math.sin(t * 1.4) * 0.02
	end
	-- hello: a wave and a line when you come near (one villager at a time)
	if you and dist < 11 then
		if not s.near and (s.saidAt == nil or os.clock() - s.saidAt > 25) and os.clock() - lastTalk > 5 then
			s.saidAt = os.clock()
			lastTalk = os.clock()
			s.waveUntil = t + 1.6
			local line = lineFor(r)
			if line then
				say(r, line)
			end
		end
		s.near = true
	elseif dist > 15 then
		s.near = false
	end
	r.root = CFrame.new(s.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, s.yaw, 0)
end

-------------------------------------------------------------------------------------------------------------
-- keeping track of what's streamed in, and the loop
-------------------------------------------------------------------------------------------------------------
local function add(m: Instance, kind: string)
	if not m:IsA("Model") or rigs[m] then
		return
	end
	task.spawn(function()
		for _ = 1, 8 do
			if not m.Parent then
				return
			end
			local r = build(m, kind)
			if r then
				rigs[m] = r
				return
			end
			task.wait(1)
		end
	end)
end

local function remove(m: Instance)
	if m:IsA("Model") and rigs[m] then
		rigs[m] = nil
	end
end

for _, tag in TAGS do
	for _, m in CollectionService:GetTagged(tag) do
		add(m, tag)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
		add(m, tag)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

-- which rigs are near the camera (every half second)
task.spawn(function()
	while true do
		task.wait(0.5)
		local cam = workspace.CurrentCamera
		local at = cam and cam.CFrame.Position or Vector3.zero
		table.clear(active)
		for m, r in rigs do
			if not m.Parent then
				rigs[m] = nil
			elseif (r.base.Position - at).Magnitude < NEAR then
				table.insert(active, r)
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, r in active do
		local f = UPDATE[r.kind]
		if f and not r.dead and r.model.Parent then
			local ok, err = pcall(f, r, now - r.t0, math.min(dt, 0.1))
			if ok then
				apply(r)
			else
				warn("[CampLife] " .. r.kind .. ": " .. tostring(err))
				r.dead = true
				rigs[r.model] = nil
			end
		end
	end
end)

return {}
]====], "2311 340293682")
return "part 13/13 (CampLife.3): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
