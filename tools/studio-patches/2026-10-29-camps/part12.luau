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

put("CampLife.2", [====[	local amp = math.rad(attr(r.model, "Amp", 10))
	local f = attr(r.model, "Freq", 0.7) * math.pi * 2
	for _, g in groupsOf(r) do
		turn(r, g, CFrame.Angles(0, 0, amp * math.max(0, math.sin(t * f))))
	end
end

UPDATE.CampBob = function(r, t, _)
	local amp = attr(r.model, "Amp", 0.3)
	local f = attr(r.model, "Freq", 0.3) * math.pi * 2
	local spin = math.rad(attr(r.model, "Spin", 0))
	local roll = math.rad(attr(r.model, "Roll", 0))
	r.root = r.base * CFrame.new(0, amp * math.sin(t * f), 0) * CFrame.Angles(0, spin * t, roll * math.sin(t * f * 0.8 + 1))
end

-- critters --------------------------------------------------------------------------------------------------
local function newTarget(r: Rig, home: Vector3, range: number)
	local a = r.rng:NextNumber(0, math.pi * 2)
	local d = math.sqrt(r.rng:NextNumber()) * range
	r.state.target = home + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

UPDATE.CampCritter = function(r, t, dt)
	local m = r.model
	local s = r.state
	local kind = attr(m, "Kind", "walk")
	local home: Vector3 = attr(m, "Home", r.base.Position)
	local range = attr(m, "Range", 4)
	local speed = attr(m, "Speed", 1.5)
	if not s.pos then
		s.pos = Vector3.new(r.base.Position.X, home.Y, r.base.Position.Z)
		local _, yaw = r.base:ToOrientation()
		s.yaw = yaw
		s.wait = r.rng:NextNumber(0, 2)
		s.hop = 0
	end
	if kind == "perch" then
		-- an owl: its head glances about, and at you when you're near
		local you = playerRoot()
		local want = s.look or 0
		if you and (you.Position - s.pos).Magnitude < 26 then
			local y = yawTo(s.pos, you.Position)
			if y then
				want = math.clamp(((y - s.yaw + math.pi) % (2 * math.pi)) - math.pi, -1.9, 1.9)
			end
		elseif t > (s.next or 0) then
			s.next = t + r.rng:NextNumber(1.5, 4)
			s.look = r.rng:NextNumber(-1.6, 1.6)
			want = s.look
		end
		s.head = lerpAngle(s.head or 0, want, dt * 6)
		turn(r, "Head", CFrame.Angles(0, s.head, 0))
		r.root = CFrame.new(s.pos) * CFrame.Angles(0, s.yaw, 0)
		return
	end
	if kind == "float" then
		local ph = (attr(m, "Seed", 1) % 97) * 0.37
		local p = home + Vector3.new(math.sin(t * 0.31 + ph) * range, math.sin(t * 0.9 + ph * 2) * 1.2, math.cos(t * 0.23 + ph * 1.3) * range)
		r.root = CFrame.new(p)
		return
	end
	if kind == "swim" then
		-- koi: a lazy loop round the pond, wiggling
		local ph = (attr(m, "Seed", 1) % 97) * 0.21
		local w = speed / math.max(range * 0.75, 0.5)
		local a = t * w + ph
		local p = home + Vector3.new(math.cos(a) * range * 0.75, 0, math.sin(a) * range * 0.55)
		local ahead = home + Vector3.new(math.cos(a + 0.1) * range * 0.75, 0, math.sin(a + 0.1) * range * 0.55)
		local y = yawTo(p, ahead) or 0
		r.root = CFrame.new(p) * CFrame.Angles(0, y + math.sin(t * 7) * 0.18, 0)
		return
	end
	-- walk / hop / waddle / crawl: to a spot, a pause, another spot
	if s.wait > 0 then
		s.wait -= dt
		if kind == "walk" then
			-- a chicken pecks while it stands
			local peck = math.max(0, math.sin(t * 9)) * (if math.sin(t * 0.9 + s.yaw) > 0 then 1 else 0)
			turn(r, "Head", CFrame.Angles(-peck * 0.7, 0, 0))
		end
		if s.wait <= 0 then
			newTarget(r, home, range)
		end
		r.root = CFrame.new(s.pos) * CFrame.Angles(0, s.yaw, 0)
		return
	end
	if not s.target then
		newTarget(r, home, range)
	end
	local to = s.target :: Vector3
	local d = flat(to - s.pos)
	local want = yawTo(s.pos, to) or s.yaw
	s.yaw = lerpAngle(s.yaw, want, dt * 5)
	local lift, roll = 0, 0
	if kind == "hop" then
		-- frogs move in hops
		s.hop += dt * 1.8
		local ph = s.hop % 1
		if ph < 0.5 and d.Magnitude > 0.01 then
			lift = math.sin(ph / 0.5 * math.pi) * 0.55
			s.pos += d.Unit * math.min(d.Magnitude, speed * 2.2 * dt)
		end
	else
		if d.Magnitude > 0.01 then
			s.pos += d.Unit * math.min(d.Magnitude, speed * dt)
		end
		if kind == "waddle" then
			roll = math.sin(t * 9) * 0.14
			turn(r, "armL", CFrame.Angles(0, 0, -0.25 - math.sin(t * 9) * 0.15))
			turn(r, "armR", CFrame.Angles(0, 0, 0.25 - math.sin(t * 9) * 0.15))
		elseif kind == "crawl" then
			s.yaw += math.sin(t * 11) * dt * 1.2
		elseif kind == "walk" then
			lift = math.abs(math.sin(t * 10)) * 0.08
			turn(r, "Head", CFrame.Angles(math.sin(t * 10) * 0.12, 0, 0))
		end
	end
	if d.Magnitude < 0.25 then
		s.wait = if kind == "hop" then r.rng:NextNumber(0.6, 2.5) else r.rng:NextNumber(1, 4.5)
		s.hop = 0
	end
	r.root = CFrame.new(s.pos + Vector3.new(0, lift, 0)) * CFrame.Angles(0, s.yaw, roll)
end

-- villagers -------------------------------------------------------------------------------------------------
local function parsePath(m: Model, y: number): { Vector3 }
	local out = {}
	local s = m:GetAttribute("Path")
	if type(s) ~= "string" then
		return out
	end
	for x, z in string.gmatch(s, "(-?[%d%.]+),(-?[%d%.]+)") do
		table.insert(out, Vector3.new(tonumber(x) :: number, y, tonumber(z) :: number))
	end
	return out
end

local function legs(r: Rig, swing: number)
	turn(r, "legL", CFrame.Angles(swing, 0, 0))
	turn(r, "legR", CFrame.Angles(-swing, 0, 0))
end

UPDATE.CampVillager = function(r, t, dt)
	local m = r.model
	local s = r.state
	local act = attr(m, "Act", "idle")
	local work = attr(m, "Work", "")
	if not s.pos then
		s.pos = r.base.Position
		local _, yaw = r.base:ToOrientation()
		s.yaw, s.home = yaw, yaw
		s.path = parsePath(m, r.base.Position.Y)
		s.i = 1
		s.wait = r.rng:NextNumber(0.5, 3)
		s.head = 0
	end
	local you = playerRoot()
	local dist = if you then (you.Position - s.pos).Magnitude else math.huge
	local walking = false
	local bob = 0
	-- walking the round
	if act == "walk" and #s.path > 1 then
		if s.wait > 0 then
			s.wait -= dt
		else
			local to = s.path[s.i]
			local d = flat(to - s.pos)
			if d.Magnitude < 0.3 then
				s.i = s.i % #s.path + 1
				s.wait = if r.rng:NextNumber() < 0.5 then r.rng:NextNumber(1.5, 4.5) else 0
			else
				walking = true
				local want = yawTo(s.pos, to) or s.yaw
				s.yaw = lerpAngle(s.yaw, want, dt * 6)
				s.pos += d.Unit * math.min(d.Magnitude, 3.4 * dt)
			end
		end
	end
	if walking then
		local w = t * 9
		legs(r, math.sin(w) * 0.5)
		turn(r, "armL", CFrame.Angles(-math.sin(w) * 0.4, 0, 0))
		turn(r, "armR", CFrame.Angles(math.sin(w) * 0.4, 0, 0))
		bob = math.abs(math.sin(w)) * 0.12
		s.head = lerpAngle(s.head, 0, dt * 4)
		turn(r, "Head", CFrame.Angles(0, s.head, 0))
	else
		-- standing (or sitting, or at work): turn to you when you're close, look at you, wave and say hello
		if act == "sit" then
			legs(r, 0)
			turn(r, "legL", CFrame.Angles(math.rad(85), 0, 0))
			turn(r, "legR", CFrame.Angles(math.rad(85), 0, 0))
		else
			legs(r, 0)
		end
		local want = 0
		if you and dist < 18 then
			local y = yawTo(s.pos, you.Position)
			if y then
				local rel = ((y - s.yaw + math.pi) % (2 * math.pi)) - math.pi
				want = math.clamp(rel, -1.2, 1.2)
				if act == "idle" and dist < 10 then
					-- the whole body turns toward you
					s.yaw = lerpAngle(s.yaw, y, dt * 2.5)
				end
			end
		elseif act == "idle" then
			s.yaw = lerpAngle(s.yaw, s.home, dt * 1.5)
			want = math.sin(t * 0.5) * 0.5
		end
		s.head = lerpAngle(s.head, want, dt * 5)
		local headPitch = if work == "gaze" and dist > 12 then 0.45 else 0
		turn(r, "Head", CFrame.Angles(headPitch, s.head, 0))
		-- the arms
		local waving = s.waveUntil and t < s.waveUntil
		if waving then
			turn(r, "armR", CFrame.Angles(0, 0, math.rad(150) + math.sin(t * 16) * 0.3))
			turn(r, "armL", CFrame.Angles(0, 0, 0))
		elseif act == "work" and dist > 7 then
			local k = t * 2 * math.pi
			if work == "chop" then
				local a = (t * 0.9) % 1
				local up = if a < 0.6 then a / 0.6 else 1 - (a - 0.6) / 0.4
				turn(r, "armR", CFrame.Angles(math.rad(40 + 110 * up), 0, 0))
				turn(r, "armL", CFrame.Angles(math.rad(30 + 60 * up), 0, 0))
			elseif work == "hammer" then
				local a = (t * 1.3) % 1
				local up = if a < 0.7 then a / 0.7 else 1 - (a - 0.7) / 0.3
				turn(r, "armR", CFrame.Angles(math.rad(45 + 90 * up), 0, 0))
				if a >= 0.97 and not s.struck then
					s.struck = true
					local hand = r.model:FindFirstChild("Hand") :: BasePart?
					if hand then
						sparks(hand.Position + Vector3.new(0, -0.6, 0))
					end
				elseif a < 0.9 then
					s.struck = false
				end
			elseif work == "rake" or work == "shovel" then
				local a = math.sin(k * 0.6)
				turn(r, "armR", CFrame.Angles(math.rad(35) + a * 0.35, 0, 0))
				turn(r, "armL", CFrame.Angles(math.rad(35) + a * 0.35, 0, 0))
				bob = math.abs(a) * 0.08
			elseif work == "water" then
				turn(r, "armR", CFrame.Angles(math.rad(65) + math.sin(k * 0.4) * 0.15, 0, 0))
			elseif work == "fish" then
				turn(r, "armR", CFrame.Angles(math.rad(40) + math.sin(k * 0.3) * 0.05 + (if (t % 9) < 0.4 then 0.35 else 0), 0, 0))
			elseif work == "gaze" then
				turn(r, "armR", CFrame.Angles(math.rad(20), 0, 0))
			end
		elseif act == "sit" then
			turn(r, "armL", CFrame.Angles(math.rad(25), 0, 0))
			turn(r, "armR", CFrame.Angles(math.rad(25) + math.max(0, math.sin(t * 0.7)) * 0.4, 0, 0))
		else
			-- breathing
			turn(r, "armL", CFrame.Angles(math.sin(t * 1.4) * 0.05, 0, -0.06))
]====], "8997 864555735")
return "part 12/13 (CampLife.2): " .. (if #bad == 0 then "ok" else table.concat(bad, ", "))
