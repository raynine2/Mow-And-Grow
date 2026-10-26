-- Boss guns, day and night, and the crawlers (client side):
--   * holding a boss-crate gun: hold the mouse (or the screen) to fire at the rate of the gun; each shot sends the
--     aim direction (server/Guns checks it) and draws a tracer + muzzle flash. The Minigun spins up first.
--   * crawler and crate effects, NIGHT FALLS / DAY BREAKS banners.
-- The day/night bar is client/Hud's and the night look client/ZoneMood's (both from server/DayNight's clock);
-- Peaceful Mode is picked in the Create Party window (client/PartyWindow).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.MowALawn:WaitForChild("Format"))
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local NightGun = {}
local C = UI.colors
local player = Players.LocalPlayer

-------------------------------------------------------------------------------------------------------------
-- guns
-------------------------------------------------------------------------------------------------------------
local function heldGun(): (any, Tool?)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("GunId")
	return if id then Config.gun(id) else nil, tool
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "GunFx"
fxFolder.Parent = workspace

local function beam(from: Vector3, to: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	local len = (to - from).Magnitude
	p.Size = Vector3.new(0.12, 0.12, len)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(0.08), { Transparency = 1, Size = Vector3.new(0.02, 0.02, len) }):Play()
	task.delay(0.1, function()
		p:Destroy()
	end)
end

local function flash(at: Vector3, size: number, color: Color3)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(at)
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.one * size * 1.8 }):Play()
	task.delay(0.14, function()
		p:Destroy()
	end)
end

-- Where the player aims: the mouse (or the screen centre on touch / first person) as a ray from the camera.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function aimPoint(): Vector3
	local cam = workspace.CurrentCamera
	local pos = UserInputService:GetMouseLocation()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or UserInputService.TouchEnabled then
		pos = cam.ViewportSize / 2
	end
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	rayParams.FilterDescendantsInstances = { player.Character :: any, fxFolder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, rayParams)
	return if hit then hit.Position else ray.Origin + ray.Direction * 300
end

local firing = false
local spinFrom = 0
local lastFire = 0
local function fire()
	local def, tool = heldGun()
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not def or not tool or not head then
		return
	end
	local now = os.clock()
	if now - lastFire > 0.4 then
		spinFrom = now
	end
	if now - lastFire < 1 / def.rate then
		return
	end
	lastFire = now
	local target = aimPoint()
	State.fire("Shoot", (target - head.Position).Unit)
	if def.spin and now - spinFrom < def.spin then
		-- still spinning up: just the whirr
		Sound.play("chip", 0.1)
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local muzzle = if handle then (handle.CFrame * CFrame.new(0, 0.6, -2.2)).Position else head.Position
	beam(muzzle, target, Color3.fromRGB(255, 220, 120))
	flash(muzzle, 0.6, Color3.fromRGB(255, 200, 80))
	flash(target, 0.8, Color3.fromRGB(255, 240, 200))
	Sound.play("hit", 0.15)
end

local fireInput: InputObject? = nil
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if heldGun() then
			firing = true
			fireInput = input
		end
	end
end)
-- (only the press that started firing stops it: on a phone, letting go of the move stick mustn't)
UserInputService.InputEnded:Connect(function(input)
	if input == fireInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
		fireInput = nil
	end
end)
RunService.Heartbeat:Connect(function()
	if firing then
		if heldGun() then
			fire()
		else
			firing = false
		end
	end
end)

-------------------------------------------------------------------------------------------------------------
-- banners + crawler / crate effects
-------------------------------------------------------------------------------------------------------------
local function banner(text: string, color: Color3)
	local t = UI.text(UI.gui, text, UDim2.fromOffset(700, 70), { pos = UDim2.new(0.5, 0, 0, 120), anchor = Vector2.new(0.5, 0), color = color, stroke = 5 })
	t.ZIndex = 40
	UI.bounce(t)
	task.delay(2.2, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then
			TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		t:Destroy()
	end)
end

local function puff(at: Vector3, color: Color3, n: number)
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = color
		p.Size = Vector3.one * math.random(6, 12) / 10
		p.CFrame = CFrame.new(at + Vector3.new(math.random(-10, 10) / 10, 0.5, math.random(-10, 10) / 10))
		p.Parent = fxFolder
		local to = p.Position + Vector3.new(math.random(-30, 30) / 10, math.random(15, 35) / 10, math.random(-30, 30) / 10)
		TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = to, Transparency = 1, Size = p.Size * 0.4 }):Play()
		task.delay(0.55, function()
			p:Destroy()
		end)
	end
end

State.on("fx", function(kind, d)
	if kind == "nightFalls" then
		banner("NIGHT FALLS", Color3.fromRGB(170, 185, 255))
		if not d.peaceful then
			UI.notice("Weed Crawlers are coming out!", "Cut them down - stay in the hub to be safe", "lock")
		end
		Sound.play("warn")
	elseif kind == "dayBreaks" then
		banner("DAY BREAKS", C.yellow)
	elseif kind == "crawlerSpawn" then
		puff(d.pos, Color3.fromRGB(110, 85, 60), 6)
	elseif kind == "crawlerHit" then
		puff(d.pos + Vector3.new(0, 1, 0), Color3.fromRGB(90, 160, 70), 3)
	elseif kind == "crawlerPop" then
		puff(d.pos, Config.CRAWLERS.color, 10)
	elseif kind == "crawlerDown" then
		UI.toast("Weed Crawler down!  +$" .. Format.short(d.coins or 0), "green")
		Sound.play("sell")
	elseif kind == "crateDrop" then
		UI.notice("A weapon crate is dropping!", "Grab a gun from it to fight the boss", "lock")
	elseif kind == "crateLand" then
		puff(d.pos, Color3.fromRGB(200, 180, 140), 12)
		Sound.play("slam")
	end
end)

return NightGun
