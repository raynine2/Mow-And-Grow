# Shop tabs fixed (30 Oct, owner: "fix broken ui")

The store's category tabs (FEATURED, PASSES, TOOLS, MOWERS, GEMS) looked broken: a seam across every tab, a
broken crimp on the left and steps at the right end. Cause: the seed-packet picture is drawn slanted, and its
9-slice middle row (rows 150-430) was squashed into the short tabs, so the top and bottom halves didn't meet.

Run in Edit mode (each refuses unless the script is the copy it was made for):
1. `p1_shopwindow_tabs` (ShopWindow 17020 880152127 -> 17239 1319058608): the tabs stand straight and in line
   (no longer tilted every other way), the open one slides out 12 studs instead of 16, every name one size (27).
2. `p2_skin_packet_slice` (Skin 23460 668338792 -> 23797 845675608): the packet's middle row is 5 rows thin
   (Rect 170, 285, 640, 290), so the whole height scales evenly and only the middle stretches wide.

**In Studio (30 Oct): both applied.** Checked on screen: p1 (straight tabs, names 22 px high on a 1560x793
view, FEATURED fits on one line). p2 was checked on a test image at the tabs' real size and at 3x (no seam,
the crimp and the right end whole); the real store with p2 still needs one look in Play.
