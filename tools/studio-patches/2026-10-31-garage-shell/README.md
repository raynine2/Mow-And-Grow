# The Garage in the new Tool Shop's style, and both insides restyled (31 Oct)

Owner: "the hiuse goes back to the old house when going in also use this house for the mgarage model alike"; asked,
picked "inside in new style": keep the boards, counter and rug, restyle the walls, beams, windows and door inside.

Applied in Studio on 31 Oct (Studio = git). Run in Edit mode; the installers check the checksum before writing.

1. `1_ShopShell.luau`: `server/ShopShell` (10570 457039605; doorway boxes added after the owner's "glitching both"). `restyle`: round orange-tan logs over the square ones,
   dark chinking, red beams, green window/door frames, plank ceiling, for the shop and the garage. `dressGarage`: the
   ForgeGUI garage (`garage_shell` 98540195381872) round the voxel garage, its outside bits removed.
2. `2_ShopShellView.luau`: `client/ShopShellView` (5107 1672187254; the doorway counts as inside, with 0.5 of give): the view swap for both buildings (the garage's floor and work deck show from outside too).
3. `server/RunBuilder` (57306 1568134339): `garageShed` calls `ShopShell.dressGarage(g, at)` after
   `CampBuildings.garage` (the same two lines as git).
4. `shared/ForgeModelIds` (4707 1214244341): `garage_shell = 98540195381872`.
