--!strict
-- PackAmbience (4 Nov; owner picked "Lobby/zones sfeer" for the SoulShroud pack): a light weather layer around you,
-- from the pack's Glow Dust, Leaves and Fog (client/PackFx loops), picked by where you are: the lobby, the hub, or
-- each area's style. Off with Config.SOULSHROUD_VFX = false (or without ReplicatedStorage.PackVFX), in Potato Mode,
-- and during the films (Workspace attribute FilmPlaying). Phones get one layer, not two.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MowALawn"):WaitForChild("Config")) :: any
local PackFx = require(script.Parent.PackFx)
local State = require(script.Parent.State) :: any
local ZoneMood = require(script.Parent.ZoneMood) :: any
local Potato = require(script.Parent.Potato) :: any
local PhonePerf = require(script.Parent.PhonePerf) :: any

local PackAmbience = {}

type Layer = { name: string, color: Color3?, ahead: number?, rate: number? }

-- by area style (Config.ZONES[z].style); "lobby" and "hub" for the rest
local SETS: { [string]: { Layer } } = {
	lobby = { { name = "Dust", color = Color3.fromRGB(255, 240, 180) }, { name = "Leaves" } },
	hub = { { name = "Dust", color = Color3.fromRGB(255, 240, 180) } },
	lawn = { { name = "Leaves" } },
	meadow = { { name = "Dust", color = Color3.fromRGB(255, 245, 170) }, { name = "Leaves" } },
	golf = { { name = "Leaves" } },
	wheat = { { name = "Dust", color = Color3.fromRGB(255, 205, 110) }, { name = "Leaves", color = Color3.fromRGB(230, 170, 70) } },
	blossom = { { name = "Leaves", color = Color3.fromRGB(255, 165, 205) }, { name = "Dust", color = Color3.fromRGB(255, 200, 230) } },
	reeds = { { name = "Fog", color = Color3.fromRGB(170, 205, 160), ahead = 30 }, { name = "Dust", color = Color3.fromRGB(190, 255, 150) } },
	prairie = { { name = "Leaves", color = Color3.fromRGB(235, 130, 50) }, { name = "Dust", color = Color3.fromRGB(255, 190, 120) } },
	jungle = { { name = "Dust", color = Color3.fromRGB(170, 255, 140) }, { name = "Fog", color = Color3.fromRGB(180, 220, 170), ahead = 30 } },
}

local DEFAULT_RATE: { [string]: number } = { Dust = 0.06, Fog = 0.04, Leaves = 0.8 }

local current = ""
local loops: { { h: PackFx.Loop, ahead: number } } = {}

local function where(): string
	if workspace:GetAttribute("FilmPlaying") or Potato.on or not PackFx.on() or (Config :: any).PACK_AMBIENCE == false then
		return ""
	end
	if not State.isRun() then
		return "lobby"
	end
	local z = ZoneMood.zone or 0
	local def = Config.ZONES[z]
	return if def and def.style and SETS[def.style] then def.style else "hub"
end

local function spotFor(ahead: number): CFrame?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local p = cam.CFrame.Position + flat * ahead
	return CFrame.lookAt(p, p + flat)
end

local function switch(key: string)
	for _, l in loops do
		l.h.stop()
	end
	table.clear(loops)
	current = key
	local set = SETS[key]
	if not set then
		return
	end
	for i, layer in set do
		if PhonePerf.on and i > 1 then
			break
		end
		local ahead = layer.ahead or 12
		local cf = spotFor(ahead)
		if cf then
			-- (the pack's weather is made to fill a scene: Glow Dust 255 a second, the fog 200; here it's a light touch)
			table.insert(loops, { h = PackFx.loop(layer.name, cf, { color = layer.color, rate = layer.rate or DEFAULT_RATE[layer.name] or 1 }), ahead = ahead })
		end
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	local key = where()
	if key ~= current then
		switch(key)
	end
	for _, l in loops do
		local cf = spotFor(l.ahead)
		if cf then
			l.h.move(cf)
		end
	end
end)

-- (keeps players who join in a film from carrying a layer over)
Players.LocalPlayer.CharacterAdded:Connect(function()
	current = "?"
end)

return PackAmbience
