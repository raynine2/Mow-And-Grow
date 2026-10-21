-- Grass feedback (client): a burst of clippings in the zone's grass colours on every cut, a star burst on rare
-- grass, and cut grass popping back up with a springy scale when it regrows. One pooled emitter per effect,
-- moved to the spot and fired with :Emit(), never an emitter per cluster.
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxIds = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("FxIds"))
local State = require(script.Parent.State)

local GrassFx = {}

local holder = Instance.new("Part")
holder.Name = "GrassFxHolder"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.one
holder.Parent = workspace

local att = Instance.new("Attachment")
att.Parent = holder


-- chunky clippings: little square bits that pop up and tumble down
local clips = Instance.new("ParticleEmitter")
clips.Name = "Clippings"
clips.Enabled = false
clips.Texture = FxIds.splinter or "rbxasset://textures/particles/sparkles_main.dds"
clips.LightEmission = 0.1
clips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.25) })
clips.Lifetime = NumberRange.new(0.5, 0.9)
clips.Speed = NumberRange.new(10, 18)
clips.SpreadAngle = Vector2.new(70, 70)
clips.Acceleration = Vector3.new(0, -40, 0)
clips.Drag = 2
clips.Rotation = NumberRange.new(0, 360)
clips.RotSpeed = NumberRange.new(-300, 300)
clips.EmissionDirection = Enum.NormalId.Top
clips.Parent = att

-- rare: a bright star burst
local stars = Instance.new("ParticleEmitter")
stars.Name = "Stars"
stars.Enabled = false
stars.Texture = FxIds.spark or "rbxasset://textures/particles/sparkles_main.dds"
stars.LightEmission = 1
stars.LightInfluence = 0
stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
stars.Lifetime = NumberRange.new(0.5, 0.8)
stars.Speed = NumberRange.new(8, 16)
stars.SpreadAngle = Vector2.new(180, 180)
stars.Drag = 4
stars.Parent = att

local function burst(pos: Vector3, colors: { Color3 }, rare: boolean, rareColor: Color3?)
	holder.CFrame = CFrame.new(pos)
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new(math.min(1, (i - 1) / math.max(1, #colors - 1)), c))
	end
	if #keys < 2 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colors[1]))
	end
	keys[1] = ColorSequenceKeypoint.new(0, keys[1].Value)
	keys[#keys] = ColorSequenceKeypoint.new(1, keys[#keys].Value)
	clips.Color = ColorSequence.new(keys)
	clips:Emit(if rare then 18 else 10)
	if rare then
		local c = rareColor or Color3.fromRGB(255, 220, 60)
		stars.Color = ColorSequence.new(c, Color3.new(1, 1, 1))
		stars:Emit(16)
	end
end

-- Regrow: every stick starts squashed into the ground and springs up to its size.
local springInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function popBack(model: Instance)
	if not model or not model:IsA("Model") then
		return
	end
	for i, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local size, cf = p.Size, p.CFrame
			local foot = cf * CFrame.new(0, -size.Y / 2, 0)
			p.Size = Vector3.new(size.X * 0.6, 0.2, size.Z * 0.6)
			p.CFrame = foot * CFrame.new(0, 0.1, 0)
			task.delay(i * 0.03, function()
				TweenService:Create(p, springInfo, { Size = size, CFrame = cf }):Play()
			end)
		end
	end
end

State.on("fx", function(kind, payload)
	if kind == "mow" then
		burst(payload.pos, payload.colors or { Color3.fromRGB(120, 210, 70) }, payload.rare == true, payload.rareColor)
	elseif kind == "regrow" then
		popBack(payload.model)
	end
end)

return GrassFx
