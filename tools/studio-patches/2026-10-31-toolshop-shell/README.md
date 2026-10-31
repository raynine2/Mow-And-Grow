# The Tool Shop's ForgeGUI cabin (31 Oct, owner: "the house at spawn feels a bit idk")

Asked: the Tool Shop in the run, "low quality, remake" with ForgeGUI; shown the room another session made the same day
(server/ShopRoom): keep the room. So the room stays and only the outside is new.

- **`server/ShopShell`** (new): a ForgeGUI log-cabin shop (`ForgeModelIds.toolshop_shell` = 140559480856788, variant A
  of two; B 122723594322982 unused) placed on the voxel lodge (`server/CampBuildings`) at about its size (54 wide; a
  cabin big enough to hide the lodge would hit the bag stand). The lodge's outside-only pieces go (porch roof, posts,
  rails, sign, lanterns, window boxes, shutters, chimney, firewood, roof medallion); the deck and steps stay invisible
  to walk on; the yard in front stays. `server/RunBuilder` calls it after ShopRoom.
- **`client/ShopShellView`** (new, required by `client/ShopDisplays`): camera outside the lodge's room (in the frame
  of the shop's `0Anchor`, which moves with the shop when the saved map places it) shows the cabin and of the lodge
  only its floor and the room; camera inside shows the lodge and room as before and hides the cabin
  (LocalTransparencyModifier only: collisions, prompts, lights unchanged). Bonus: ~1,000 fewer lodge parts drawn from
  outside.

## In Studio (31 Oct, applied; Studio = git)

Backups: `ServerStorage.MowALawnBackups.pre_toolshopshell_31oct` (RunBuilder, ShopDisplays, ForgeModelIds).
1. `1_install_ShopShell`, 2. `2_install_ShopShellView` (also replace their first versions 4447 1630140148 / 3124
   244905944, which read a frame that didn't move with the shop: the inside view never switched)
3. `3_RunBuilder` (replaces 56808 461202846), 4. `4_ShopDisplays` (replaces 10840 1645038683), 5. `5_ForgeModelIds`
   (replaces 4164 969735425)

Checked in Play: from the spawn the new cabin (bag stand clear), the room seen through its doorway; with the camera
in the room, the lodge and room exactly as before; switching back outside; no errors. Edit mode still shows the
saved world's old lodge until `RunWorld.refreshForge()` is run.
