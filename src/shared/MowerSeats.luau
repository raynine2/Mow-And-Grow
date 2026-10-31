-- (owner, 29 Oct: "change the seat animation of the mowers to be organic and different so the player actually fits in
-- the mower aswell instead of bugging through the roof or floating instead of sitting") Where a rider sits on each
-- Blender mower and what they hold. Every number is in the model's own space (the Blender origin: the ground under the
-- middle, forward is -Z), measured from the models on 29 Oct.
--   server/Mowers: puts the seat on the cushion, lifts the Mulcher's roof and the Trial Mower's canopy so a rider's
--                  head fits under them, and hangs each steering wheel on a "Steer" motor so it can turn
--   client/RiderPose: poses everyone riding a mower from this (code keyframes, no uploads)
-- wheel: the steering wheel's middle `c`, rim radius `r` and `u`, the direction "up" along its face (it leans back
--        towards the rider); hands hold it at `grip` degrees (0 = 3 o'clock, 90 = 12 o'clock)
-- grips: (zero-turn) the two lap-bar handles instead of a wheel
-- lean: degrees the rider leans forward (negative: lounging back); feet: where the feet go, x out from the middle and z
--       along (the floor under them is found with a ray); knees: how far out the knees splay
-- roof: parts whose bottom is above `from` (and in front of `zMin`) move up by `raise`; the posts that reach `post`
--       stretch to meet them
local MowerSeats = {}

export type Spec = {
	cushion: number,
	seatZ: number,
	wheel: { c: Vector3, r: number, u: Vector3, grip: number }?,
	grips: { Vector3 }?,
	lean: number,
	feet: { x: number, z: number },
	knees: number,
	elbows: number,
	style: string,
	roof: { from: number, zMin: number, post: number, raise: number }?,
}

local function up(y: number, z: number): Vector3
	return Vector3.new(0, y, z).Unit
end

MowerSeats.byModel = {
	-- an old banger: hunched over a small wheel, knees up
	mower_rusty = {
		cushion = 3.0,
		seatZ = 1.0,
		wheel = { c = Vector3.new(0, 3.85, 0.15), r = 0.52, u = up(0.86, -0.6), grip = 30 },
		lean = 9,
		feet = { x = 0.55, z = -1.3 },
		knees = 0.35,
		elbows = 0.7,
		style = "hunch",
	},
	-- sits up proud on the big tractor, legs either side of the hood
	mower_tractor = {
		cushion = 3.0,
		seatZ = 1.05,
		wheel = { c = Vector3.new(0, 4.25, 0.35), r = 0.62, u = up(1.02, -0.72), grip = 35 },
		lean = 3,
		feet = { x = 0.85, z = -1.0 },
		knees = 0.45,
		elbows = 0.55,
		style = "proud",
	},
	-- laid back, one hand on each lap bar
	mower_zeroturn = {
		cushion = 3.0,
		seatZ = 1.0,
		grips = { Vector3.new(-0.72, 4.15, -0.52), Vector3.new(0.72, 4.15, -0.52) },
		lean = -7,
		feet = { x = 0.6, z = -1.35 },
		knees = 0.3,
		elbows = 0.45,
		style = "chill",
	},
	-- leaning into the wheel of a monster
	mower_mulcher = {
		cushion = 3.0,
		seatZ = 1.0,
		wheel = { c = Vector3.new(0, 4.45, 0.25), r = 0.59, u = up(0.96, -0.68), grip = 35 },
		lean = 11,
		feet = { x = 0.8, z = -1.0 },
		knees = 0.45,
		elbows = 0.75,
		style = "beast",
		roof = { from = 6.2, zMin = 0.3, post = 6.5, raise = 1.4 }, -- (a tall avatar, head scaled up, fits)
	},
	-- comfy under the canopy
	mower_trial = {
		cushion = 3.0,
		seatZ = 1.05,
		wheel = { c = Vector3.new(0, 4.1, 0.35), r = 0.57, u = up(0.94, -0.66), grip = 35 },
		lean = 2,
		feet = { x = 0.6, z = -1.2 },
		knees = 0.35,
		elbows = 0.55,
		style = "comfy",
		roof = { from = 5.85, zMin = -1.5, post = 6.15, raise = 1.6 },
	},
	-- tucked in like a racer, 9 and 3 on a low wheel
	mower_rocket = {
		cushion = 3.0,
		seatZ = 1.0,
		wheel = { c = Vector3.new(0, 3.35, 0.3), r = 0.475, u = up(0.82, -0.48), grip = 12 },
		lean = 17,
		feet = { x = 0.6, z = -1.45 },
		knees = 0.3,
		elbows = 0.85,
		style = "racer",
	},
} :: { [string]: Spec }

function MowerSeats.get(modelName: string?): Spec?
	return if modelName then MowerSeats.byModel[modelName] else nil
end

return MowerSeats
