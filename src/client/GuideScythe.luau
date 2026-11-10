--!strict
-- GUIDE SCYTHE (10 Nov 2026, owner: "let brrbrr lend the scythe so let brrbrr have one in his hands and give it to
-- the player only for the tutorial ... only give it back when the player has taken down 2-3 grasses and animated
-- it"). The prop BRRBRR carries in the first-run tutorial (client/TutorGuide), and the two hand-overs:
--   give:     it leaves his hand in a little arc, spinning, sparkles, into yours (then the server hands you the real
--             Mega Scythe on loan: "Seen" "loanTaken", server/Run)
--   takeBack: after Config.FIRST_TIMER.loanCuts clumps the server takes the loan back (Fx "loanBack"): a copy flies
--             from your hand back into his, where it stays
-- The model is the same one you hold (ReplicatedStorage.MowALawnModels.tool_scythe), at the same grip as
-- server/Tools; a simple stick-and-blade stands in if it isn't loaded.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GuideScythe = {}

local SCALE = 0.85 -- server/Tools HELD_SCALE
-- server/Tools: the Mega Scythe's tool.Grip
local GRIP = CFrame.new(0, 0, 0.7, -0.983, -0.0246, -0.1818, 0.1833, -0.1761, -0.9672, -0.0082, -0.9841, 0.1776)
local FLY = 0.75 -- seconds in the air

local function plain(): Model
	local m = Instance.new("Model")
	m.Name = "GuideScythe"
	local function piece(size: Vector3, cf: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local shaft = piece(Vector3.new(0.3, 0.3, 5), CFrame.new(0, 0, -2.6), Color3.fromRGB(70, 50, 90))
	piece(Vector3.new(0.2, 0.6, 3.6), CFrame.new(1.6, 0, -5) * CFrame.Angles(0, math.rad(-80), 0), Color3.fromRGB(150, 90, 255))
	m.PrimaryPart = shaft
	m.WorldPivot = CFrame.new()
	return m
end

local function newProp(): Model
	local folder = ReplicatedStorage:FindFirstChild("MowALawnModels")
	local template = folder and folder:FindFirstChild("tool_scythe")
	local m: Model
	if template and template:IsA("Model") then
		m = template:Clone()
		pcall(function()
			m:ScaleTo(SCALE)
		end)
	else
		m = plain()
	end
	m.Name = "GuideScythe"
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Massless = true
		elseif p:IsA("Trail") or p:IsA("ParticleEmitter") then
			p.Enabled = false
		end
	end
	return m
end

-- where a hand holds it: the tool's handle frame for this hand (Roblox's RightGrip: hand * grip attachment * Grip^-1)
local function gripFrame(hand: BasePart): CFrame
	local att = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local at = if att then att.CFrame else CFrame.new(0, -hand.Size.Y / 2, 0)
	return hand.CFrame * at * GRIP:Inverse()
end

local function handOf(model: Instance?): BasePart?
	if not model then
		return nil
	end
	return (model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")) :: BasePart?
end

-- (10 Nov, seen in Play: with his arm down the tool grip held it out like a spear) BRRBRR carries it upright like a
-- staff: the shaft up from his fist, leaning a little forward and out, the blade at the top
local function carryFrame(hand: BasePart): CFrame
	local model = hand.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local att = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local gp = (hand.CFrame * (if att then att.CFrame else CFrame.new())).Position
	local base = if root then root.CFrame else hand.CFrame
	local up = (base.UpVector * 0.96 + base.LookVector * 0.18 + base.RightVector * 0.12).Unit
	return CFrame.lookAt(gp, gp + up, base.LookVector)
end

local function weldTo(m: Model, hand: BasePart)
	m:PivotTo(carryFrame(hand))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = hand
			w.Part1 = p
			w.Parent = p
		end
	end
	m.Parent = hand.Parent
end

-- the guide's own scythe in his hand (once)
function GuideScythe.attach(guide: Model): Model?
	local hand = handOf(guide)
	if not hand then
		return nil
	end
	local had = guide:FindFirstChild("GuideScythe")
	if had and had:IsA("Model") then
		return had
	end
	local m = newProp()
	weldTo(m, hand)
	return m
end

function GuideScythe.held(guide: Model): boolean
	return guide:FindFirstChild("GuideScythe") ~= nil
end

-- does `char` hold (or carry) the loaned tool?
function GuideScythe.playerHasLoan(player: Player): boolean
	for _, where in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if where then
			for _, t in where:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("Loaner") then
					return true
				end
			end
		end
	end
	return false
end

-- fly a free copy from one hand frame to another, spinning, then call done(prop) with it (anchored, at the end)
local function fly(m: Model, from: CFrame, toFn: () -> CFrame, done: (Model) -> ())
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		elseif p:IsA("WeldConstraint") then
			p:Destroy()
		end
	end
	m.Parent = workspace
	m:PivotTo(from)
	local v = Instance.new("NumberValue")
	v.Value = 0
	v.Changed:Connect(function(t: number)
		if not m.Parent then
			return
		end
		local to = toFn()
		local pos = from.Position:Lerp(to.Position, t) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
		local turn = CFrame.Angles(0, t * math.pi * 4, t * math.pi * 2)
		local rot = from.Rotation:Lerp(to.Rotation, t)
		m:PivotTo(CFrame.new(pos) * (if t < 0.95 then rot * turn else rot))
	end)
	local tw = TweenService:Create(v, TweenInfo.new(FLY, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
	tw.Completed:Connect(function()
		v:Destroy()
		done(m)
	end)
	tw:Play()
end

-- the guide hands his scythe to `player`: done() when it's in their hand (the prop is gone then)
function GuideScythe.give(guide: Model, player: Player, done: () -> ())
	local hand = handOf(guide)
	local m = guide:FindFirstChild("GuideScythe") :: Model?
	if not hand or not m then
		done()
		return
	end
	local from = m:GetPivot()
	fly(m, from, function(): CFrame
		local ph = handOf(player.Character)
		return if ph then gripFrame(ph) else from
	end, function(prop: Model)
		prop:Destroy()
		done()
	end)
end

-- the scythe comes back from `player`'s hand to the guide's, where it stays; done() when it's there
function GuideScythe.takeBack(guide: Model, player: Player, done: () -> ())
	local hand = handOf(guide)
	local ph = handOf(player.Character)
	if not hand then
		done()
		return
	end
	local old = guide:FindFirstChild("GuideScythe")
	if old then
		old:Destroy()
	end
	local m = newProp()
	local from = if ph then gripFrame(ph) else gripFrame(hand)
	fly(m, from, function(): CFrame
		return carryFrame(hand)
	end, function(prop: Model)
		if hand.Parent then
			for _, p in prop:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = false
				end
			end
			weldTo(prop, hand)
		else
			prop:Destroy()
		end
		done()
	end)
end

return GuideScythe
