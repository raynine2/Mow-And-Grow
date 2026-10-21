-- Made by tools/blender/voxel/build_all.py: where each voxel prop's footprint middle (at its lowest point)
-- sits relative to the origin of the toy model it replaces, in studs (front = -Z). server/Models uses it.
return {
	Prop_log_cabin = Vector3.new(0.00, -0.50, -0.50),
	Prop_bag_stand = Vector3.new(0.00, 0.00, -1.25),
	Prop_rewards_stall = Vector3.new(0.00, 0.00, -0.25),
	Prop_lantern_post = Vector3.new(0.00, 0.00, -0.88),
	Prop_gas_pump = Vector3.new(0.12, 0.00, 0.00),
	Prop_leaderboard = Vector3.new(0.00, 0.00, 0.00),
	Prop_trophy_board = Vector3.new(0.00, 0.00, 0.25),
	Prop_party_booth = Vector3.new(0.00, 0.00, 0.50),
	Prop_shredder = Vector3.new(0.00, 0.00, 0.00),
	Prop_sell_pad = Vector3.new(0.00, 0.00, 0.00),
	Prop_turntable = Vector3.new(0.25, 0.00, 0.25),
}
