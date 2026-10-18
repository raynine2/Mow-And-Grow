-- Full-screen confetti: coloured paper bits burst up from the bottom corners, flutter (spin and sway) and fall.
-- Confetti.burst(amount) for big moments: run complete, boss defeated, big combos.
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local Confetti = {}

local COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 210, 90),
	Color3.fromRGB(70, 170, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 140, 210),
}

local layer = Instance.new("Frame")
layer.Name = "Confetti"
layer.BackgroundTransparency = 1
layer.Size = UDim2.fromScale(1, 1)
layer.ZIndex = 60
layer.Parent = UI.gui

type Bit = { f: Frame, x: number, y: number, vx: number, vy: number, rot: number, spin: number, sway: number, phase: number, life: number, age: number }
local bits: { Bit } = {}
local MAX = 220

local function spawnBit(x: number, y: number, vx: number, vy: number)
	if #bits >= MAX then
		return
	end
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
	f.BackgroundColor3 = COLORS[math.random(1, #COLORS)]
	f.ZIndex = 60
	f.Parent = layer
	table.insert(bits, {
		f = f, x = x, y = y, vx = vx, vy = vy,
		rot = math.random() * 360, spin = (math.random() - 0.5) * 900,
		sway = 40 + math.random() * 60, phase = math.random() * 6, life = 2.6 + math.random() * 1.2, age = 0,
	})
end

-- `amount`: roughly how many bits (default 120). Two cannons fire from the bottom corners.
function Confetti.burst(amount: number?)
	local n = amount or 120
	local size = layer.AbsoluteSize
	for i = 1, n do
		local left = i % 2 == 0
		local x = if left then size.X * 0.05 else size.X * 0.95
		local speed = 900 + math.random() * 700
		local angle = math.rad(if left then (60 + math.random() * 22) else (98 + math.random() * 22))
		spawnBit(x, size.Y + 10, math.cos(angle) * speed, -math.sin(angle) * speed)
	end
end

RunService.RenderStepped:Connect(function(dt)
	for i = #bits, 1, -1 do
		local b = bits[i]
		b.age += dt
		if b.age >= b.life then
			b.f:Destroy()
			table.remove(bits, i)
			continue
		end
		-- fast burst, then paper drag: falls slowly while swaying and flipping
		b.vy += 1500 * dt
		b.vx *= 1 - 2.2 * dt
		b.vy = math.min(b.vy, 260)
		b.x += (b.vx + math.sin(b.age * 5 + b.phase) * b.sway) * dt
		b.y += b.vy * dt
		b.rot += b.spin * dt
		b.f.Position = UDim2.fromOffset(b.x, b.y)
		b.f.Rotation = b.rot
		-- a flipping card: squash its width with a cosine
		local w = math.abs(math.cos(b.age * 8 + b.phase))
		b.f.Size = UDim2.fromOffset(math.max(2, 12 * w), 18)
		if b.life - b.age < 0.5 then
			b.f.BackgroundTransparency = 1 - (b.life - b.age) / 0.5
		end
	end
end)

return Confetti
