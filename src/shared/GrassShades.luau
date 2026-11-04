--!strict
-- Each area's grass stem shades, the same as its clumps' (tools/blender/voxel/models.py GRASS): [1] the stalk's main
-- shade, then the others. Used by what's made from the grass (server/Stubble's stumps, shared/BundleVoxel's bundles)
-- so it matches the clumps standing beside it.
local C = Color3.fromRGB

local GrassShades = {
	meadow = { C(48, 160, 64), C(62, 180, 74), C(38, 140, 58) },
	wheat = { C(232, 176, 58), C(246, 196, 80), C(214, 150, 44) },
	blossom = { C(86, 182, 96), C(70, 160, 84) },
	pine = { C(40, 150, 110), C(54, 170, 124), C(30, 126, 94) },
	swamp = { C(110, 146, 58), C(92, 128, 50) },
	frost = { C(244, 250, 255), C(220, 238, 255), C(200, 226, 250) },
	ember = { C(64, 52, 58), C(80, 64, 70) },
	isles = { C(180, 140, 255), C(150, 110, 240) },
}

return GrassShades
