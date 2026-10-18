-- Custom character animations (idle, walk, run, jump, fall, cheer) made by tools/anim/make_anims.luau and
-- uploaded with tools/upload_models.py --anims, which fills shared/AnimIds.
--
-- Every R15 character gets Roblox's stock "Animate" script, which reads its animations from Animation objects
-- under it (Animate.walk.WalkAnim, Animate.idle.Animation1, ...). This swaps in our ids there, on the server, as
-- the character is created, so the player's own Animate script starts with them. Anything without an uploaded id
-- keeps Roblox's default, and R6 characters are left alone (these animations are for the R15 rig).
--
-- Speeds: Animate blends walk and run by speed and plays only RUN at WalkSpeed 16 and up (every speed this game
-- uses), sped up by speed / 12.8, so "run" is the everyday walking look; "walk" shows when moving slowly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimIds: { [string]: string } = require(ReplicatedStorage.MowALawn.AnimIds) :: any

local Anims = {}

-- { Animate's folder, the Animation inside it, our animation (and the one to use if that isn't uploaded) }
local SLOTS = {
	{ "idle", "Animation1", "idle" },
	{ "idle", "Animation2", "idle_look", "idle" }, -- now-and-then idle variant: a look around
	{ "walk", "WalkAnim", "walk" },
	{ "run", "RunAnim", "run" },
	{ "jump", "JumpAnim", "jump" },
	{ "fall", "FallAnim", "fall" },
	{ "cheer", "CheerAnim", "cheer" },
}
-- How often Animate picks each idle (it re-rolls whenever an idle loop ends): the look-around about 1 in 5.
local IDLE_WEIGHTS = { Animation1 = 4, Animation2 = 1 }

local function slotAnimation(animate: Instance, folder: string, child: string): Animation?
	local f = animate:FindFirstChild(folder)
	local a = f and f:FindFirstChild(child)
	return if a and a:IsA("Animation") then a else nil
end

-- Sets every slot we have an id for. Only writes changes, so it's safe to call again at any time.
local function apply(animate: Instance)
	for _, slot in SLOTS do
		local id = AnimIds[slot[3]] or (slot[4] and AnimIds[slot[4]])
		local anim = slotAnimation(animate, slot[1], slot[2])
		if id and anim and anim.AnimationId ~= id then
			anim.AnimationId = id
		end
	end
	if AnimIds.idle_look then
		for child, weight in IDLE_WEIGHTS do
			local anim = slotAnimation(animate, "idle", child)
			local w = anim and anim:FindFirstChild("Weight")
			if w and w:IsA("NumberValue") and w.Value ~= weight then
				w.Value = weight
			end
		end
	end
end

local function setup(animate: Instance)
	apply(animate)
	-- Avatar loading (an animation pack from the player's avatar) can write its own ids in later; put ours back.
	for _, slot in SLOTS do
		local anim = slotAnimation(animate, slot[1], slot[2])
		if anim then
			anim:GetPropertyChangedSignal("AnimationId"):Connect(function()
				apply(animate)
			end)
		end
	end
	animate.DescendantAdded:Connect(function()
		task.defer(apply, animate)
	end)
end

local function onCharacter(char: Model)
	-- The server's CharacterAdded fires before the character is in the Workspace: when Animate is already there,
	-- setting the ids right now (no waiting) means the client never starts with the old ones.
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not (hum and hum:IsA("Humanoid")) or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 10)
	if animate then
		setup(animate)
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function Anims.start()
	if next(AnimIds) == nil then
		return -- nothing uploaded yet: Roblox's default animations
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return Anims
