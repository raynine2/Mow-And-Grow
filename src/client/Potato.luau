-- Potato Mode: low graphics for slow phones and laptops (the potato button in the top-left corner, client/Hud).
-- Only this player's screen changes, and everything comes back exactly as it was when it's turned off. The choice
-- is saved in the profile (server/Main "Graphics") and comes back with the state on the next visit.
--   * no shadows, bloom, sun rays or depth of field
--   * no particles, trails, beams, fire, smoke or sparkles, and no lights
--   * smooth plastic instead of textured materials (grass, wood, slate, glass ...)
--   * trees, rocks and props far from you are hidden (big landmarks stay)
-- Other client systems can check Potato.on, or the LocalPlayer attribute "Potato", to skip extra effects.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local State = require(script.Parent.State)

local Potato = {}
Potato.on = false

local player = Players.LocalPlayer
local FAR = 220 -- scenery further than this (studs, flat distance from the camera) is hidden
local NEAR = 190 -- and comes back inside this (the gap stops pieces flickering at the edge)
local BIG = 40 -- pieces this big or bigger (landmarks) always stay

-- what was changed, to put back: [instance] = old value
local material: { [BasePart]: Enum.Material } = setmetatable({}, { __mode = "k" }) :: any
local enabled: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local shadows: boolean? = nil

local KEEP = {
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Neon] = true, -- (glows mark rare grass and pads)
	[Enum.Material.ForceField] = true,
}
local SWITCHES = { "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight" }
local POST = { "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect" }

local function isSwitch(inst: Instance): boolean
	for _, c in SWITCHES do
		if inst:IsA(c) then
			return true
		end
	end
	return false
end

local function lowerPost(inst: Instance)
	for _, c in POST do
		if inst:IsA(c) then
			local e = inst :: any
			if enabled[inst] == nil then
				enabled[inst] = e.Enabled
			end
			e.Enabled = false
		end
	end
end

-- Make one instance potato (remembering how it was).
local function lower(inst: Instance)
	if inst:IsA("Terrain") then
		return
	elseif inst:IsA("BasePart") then
		if not KEEP[inst.Material] and material[inst] == nil then
			material[inst] = inst.Material
			inst.Material = Enum.Material.SmoothPlastic
		end
	elseif isSwitch(inst) then
		local e = inst :: any
		if enabled[inst] == nil then
			enabled[inst] = e.Enabled
		end
		e.Enabled = false
	else
		lowerPost(inst) -- (an effect under the camera)
	end
end

-------------------------------------------------------------------------------------------------------------
-- far scenery: World.Visuals and World.Dressing hold the trees, bushes, rocks and props
-------------------------------------------------------------------------------------------------------------
type Piece = { inst: Instance, parent: Instance, pos: Vector3 }
local pieces: { Piece } = {}
local hidden: { [Instance]: Piece } = {} -- the pieces taken out now

local function collect()
	table.clear(pieces)
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	local function walk(f: Instance)
		for _, c in f:GetChildren() do
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
					table.insert(pieces, { inst = c, parent = f, pos = cf.Position })
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
	-- (the hidden ones aren't in the world, so a walk can't find them: keep them on the list)
	for _, p in hidden do
		table.insert(pieces, p)
	end
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
				pcall(function()
					p.inst.Parent = p.parent
				end)
				hidden[p.inst] = nil
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
local generation = 0

local function turnOn()
	generation += 1
	local gen = generation
	if shadows == nil then
		shadows = Lighting.GlobalShadows
	end
	Lighting.GlobalShadows = false
	for _, e in Lighting:GetDescendants() do
		lowerPost(e)
	end
	table.insert(conns, Lighting.DescendantAdded:Connect(lowerPost))
	table.insert(conns, workspace.DescendantAdded:Connect(lower))
	-- the whole world, a slice per frame so the switch doesn't freeze the game
	task.spawn(function()
		local all = workspace:GetDescendants()
		for i, inst in all do
			if generation ~= gen then
				return
			end
			lower(inst)
			if i % 3000 == 0 then
				task.wait()
			end
		end
	end)
	-- far scenery, checked twice a second (the list is refreshed now and then: a run builds its world late)
	task.spawn(function()
		local sinceCollect = math.huge
		while generation == gen do
			if sinceCollect > 10 then
				collect()
				sinceCollect = 0
			end
			cull()
			sinceCollect += task.wait(0.5)
		end
	end)
end

local function turnOff()
	generation += 1
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	showAll()
	if shadows ~= nil then
		Lighting.GlobalShadows = shadows
		shadows = nil
	end
	for part, m in material do
		if part.Parent then
			part.Material = m
		end
	end
	table.clear(material)
	for inst, was in enabled do
		if inst.Parent then
			(inst :: any).Enabled = was
		end
	end
	table.clear(enabled)
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
