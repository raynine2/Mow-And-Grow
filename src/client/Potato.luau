-- Potato Mode: low graphics for slow phones and laptops (the potato button in the top-left corner, client/Hud).
-- Only this player's screen changes, and everything comes back when it's turned off. The choice is saved in the
-- profile (server/Main "Graphics") and comes back with the state on the next visit.
--   * no shadows, bloom, sun rays or depth of field
--   * no particles, trails, beams, fire, smoke or sparkles, and no lights
--   * smooth plastic instead of textured materials (grass, wood, slate, glass ...); the mowable grass is left alone
--   * trees, rocks and props far from you are hidden (big landmarks stay)
-- Other client systems can check Potato.on, or the LocalPlayer attribute "Potato", to skip extra effects.
--
-- How things are put back: each changed instance gets the tag "PotatoLow" and its original value as an attribute
-- (PotatoMat / PotatoOn). Tags and attributes travel with clones, so a copy made meanwhile is put back too, and an
-- instance that is out of the world when Potato Mode goes off is put back when it returns. While it's on, an
-- effect another script switches on or off is held off, and the value that script wanted is what comes back.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local State = require(script.Parent.State)

local Potato = {}
Potato.on = false

local player = Players.LocalPlayer
local TAG = "PotatoLow"
local FAR = 220 -- scenery further than this (studs, flat distance from the camera) is hidden
local NEAR = 190 -- and comes back inside this (the gap stops pieces flickering at the edge)
local BIG = 40 -- pieces this big or bigger (landmarks) always stay

local shadows: boolean? = nil

local KEEP = {
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Neon] = true, -- (glows mark rare grass and pads)
	[Enum.Material.ForceField] = true,
}
local SWITCHES = { "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight", "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect" }

local function isSwitch(inst: Instance): boolean
	for _, c in SWITCHES do
		if inst:IsA(c) then
			return true
		end
	end
	return false
end

-- the grass you mow changes its own materials (rare clumps, regrowth): leave it be
local function inGrass(inst: Instance): boolean
	local world = workspace:FindFirstChild("World")
	local g = world and world:FindFirstChild("Grass")
	return g ~= nil and inst:IsDescendantOf(g)
end

-- while on: an effect someone switches back on is turned off again (and what they wanted is remembered)
local holds: { [Instance]: RBXScriptConnection } = {}
local function hold(inst: Instance)
	if holds[inst] then
		return
	end
	local e = inst :: any
	holds[inst] = e:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Potato.on and e.Enabled then
			inst:SetAttribute("PotatoOn", true)
			e.Enabled = false
		end
	end)
	-- (effects come and go all the time: forget one when it's destroyed)
	inst.Destroying:Once(function()
		local c = holds[inst]
		if c then
			c:Disconnect()
			holds[inst] = nil
		end
	end)
end

-- Make one instance potato (remembering how it was, on the instance).
local function lower(inst: Instance)
	if inst:IsA("Terrain") then
		return
	elseif inst:IsA("BasePart") then
		if not KEEP[inst.Material] and inst:GetAttribute("PotatoMat") == nil and not inGrass(inst) then
			inst:SetAttribute("PotatoMat", inst.Material.Name)
			CollectionService:AddTag(inst, TAG)
			inst.Material = Enum.Material.SmoothPlastic
		end
	elseif isSwitch(inst) then
		local e = inst :: any
		if inst:GetAttribute("PotatoOn") == nil then
			inst:SetAttribute("PotatoOn", e.Enabled)
			CollectionService:AddTag(inst, TAG)
		elseif e.Enabled then
			-- (a copy of an effect that's held off, switched on by whoever made it)
			inst:SetAttribute("PotatoOn", true)
		end
		e.Enabled = false
		hold(inst)
	end
end

-- Put one instance back as it was (and forget it).
local function restore(inst: Instance)
	local mat = inst:GetAttribute("PotatoMat")
	if mat ~= nil and inst:IsA("BasePart") then
		-- (not if something else changed it meanwhile)
		if inst.Material == Enum.Material.SmoothPlastic then
			pcall(function()
				inst.Material = (Enum.Material :: any)[mat]
			end)
		end
		inst:SetAttribute("PotatoMat", nil)
	end
	local was = inst:GetAttribute("PotatoOn")
	if was ~= nil then
		pcall(function()
			(inst :: any).Enabled = was
		end)
		inst:SetAttribute("PotatoOn", nil)
	end
	CollectionService:RemoveTag(inst, TAG)
end

-- anything still marked that comes (back) into the game while Potato Mode is off is put back then
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	if not Potato.on then
		restore(inst)
	end
end)

-------------------------------------------------------------------------------------------------------------
-- far scenery: World.Visuals and World.Dressing hold the trees, bushes, rocks and props
-------------------------------------------------------------------------------------------------------------
type Piece = { inst: Instance, parent: Instance, pos: Vector3 }
local pieces: { Piece } = {}
local hidden: { [Instance]: Piece } = {} -- the pieces taken out now
local gen = 0 -- bumped on every switch (stops the old loops)

-- the list of pieces, walked a slice at a time (a big world has thousands)
local function collect(myGen: number)
	local fresh: { Piece } = {}
	local world = workspace:FindFirstChild("World")
	if world then
		local count = 0
		local function walk(f: Instance)
			for _, c in f:GetChildren() do
				if gen ~= myGen then
					return
				end
				if c:IsA("Folder") then
					walk(c)
				elseif c:IsA("Model") or c:IsA("BasePart") then
					local cf, size
					if c:IsA("Model") then
						cf, size = c:GetBoundingBox()
					else
						cf, size = (c :: BasePart).CFrame, (c :: BasePart).Size
					end
					if math.max(size.X, size.Y, size.Z) < BIG then
						table.insert(fresh, { inst = c, parent = f, pos = cf.Position })
					end
					count += 1
					if count % 400 == 0 then
						task.wait()
					end
				end
			end
		end
		for _, name in { "Visuals", "Dressing" } do
			local f = world:FindFirstChild(name)
			if f then
				walk(f)
			end
		end
	end
	if gen ~= myGen then
		return
	end
	-- the hidden ones aren't in the world, so the walk can't find them: keep them (unless their world is gone)
	for inst, p in hidden do
		if p.parent:IsDescendantOf(workspace) then
			table.insert(fresh, p)
		else
			hidden[inst] = nil
		end
	end
	pieces = fresh
end

local function cull()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local at = cam.CFrame.Position
	for _, p in pieces do
		local d = Vector2.new(p.pos.X - at.X, p.pos.Z - at.Z).Magnitude
		if hidden[p.inst] then
			if d < NEAR then
				hidden[p.inst] = nil
				pcall(function()
					p.inst.Parent = p.parent
				end)
			end
		elseif d > FAR and p.inst.Parent == p.parent then
			hidden[p.inst] = p
			p.inst.Parent = nil
		end
	end
end

local function showAll()
	for inst, p in hidden do
		pcall(function()
			inst.Parent = p.parent
		end)
	end
	table.clear(hidden)
end

-------------------------------------------------------------------------------------------------------------
-- on / off
-------------------------------------------------------------------------------------------------------------
local conns: { RBXScriptConnection } = {}

local function turnOn()
	gen += 1
	local myGen = gen
	if shadows == nil then
		shadows = Lighting.GlobalShadows
	end
	Lighting.GlobalShadows = false
	for _, e in Lighting:GetDescendants() do
		lower(e)
	end
	table.insert(conns, Lighting.DescendantAdded:Connect(lower))
	-- (the server turns shadows back on when it sets up a run's lighting: keep them off, and back on later)
	table.insert(conns, Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
		if Lighting.GlobalShadows then
			shadows = true
			Lighting.GlobalShadows = false
		end
	end))
	table.insert(conns, workspace.DescendantAdded:Connect(lower))
	-- the whole world, a slice per frame so the switch doesn't freeze the game
	task.spawn(function()
		local all = workspace:GetDescendants()
		for i, inst in all do
			if gen ~= myGen then
				return
			end
			lower(inst)
			if i % 2500 == 0 then
				task.wait()
			end
		end
	end)
	-- far scenery: checked twice a second; the list is made again when the world is replaced (and, sliced so it
	-- never hitches, once a minute)
	task.spawn(function()
		local listedWorld: Instance? = nil
		local listedAt = -math.huge
		while gen == myGen do
			local world = workspace:FindFirstChild("World")
			if world ~= listedWorld or os.clock() - listedAt > 60 then
				listedWorld = world
				listedAt = os.clock()
				collect(myGen)
			end
			if gen ~= myGen then
				break
			end
			cull()
			task.wait(0.5)
		end
	end)
end

local function turnOff()
	gen += 1
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	for _, c in holds do
		c:Disconnect()
	end
	table.clear(holds)
	showAll()
	table.clear(pieces)
	if shadows ~= nil then
		Lighting.GlobalShadows = shadows
		shadows = nil
	end
	-- everything marked that's in the game now (the rest is put back when it returns: see above), a slice at a time
	local myGen = gen
	task.spawn(function()
		for i, inst in CollectionService:GetTagged(TAG) do
			if gen ~= myGen then
				return
			end
			restore(inst)
			if i % 2500 == 0 then
				task.wait()
			end
		end
	end)
end

local listeners: { (boolean) -> () } = {}
function Potato.changed(fn: (boolean) -> ())
	table.insert(listeners, fn)
end

-- Switch it (save = also tell the server, so it's remembered next time).
function Potato.set(on: boolean, save: boolean?)
	if on == Potato.on then
		return
	end
	Potato.on = on
	player:SetAttribute("Potato", on)
	if on then
		turnOn()
	else
		turnOff()
	end
	for _, fn in listeners do
		task.spawn(fn, on)
	end
	if save then
		State.fire("Graphics", on)
	end
end

function Potato.toggle()
	Potato.set(not Potato.on, true)
end

-- the saved choice, when the profile arrives (only the first time: after that the button decides)
local loaded = false
State.on("data", function(d)
	if not loaded and d then
		loaded = true
		Potato.set(d.potato == true)
	end
end)

return Potato
