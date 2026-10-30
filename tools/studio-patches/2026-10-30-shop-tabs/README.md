# Shop tabs fixed (30 Oct, owner: "fix broken ui")

The store's category tabs (FEATURED, PASSES, TOOLS, MOWERS, GEMS) looked broken: a seam across every tab, a
broken crimp on the left and steps at the right end. Cause: the seed-packet picture is drawn slanted, and its
9-slice middle row (rows 150-430) was squashed into the short tabs, so the top and bottom halves didn't meet.

Run in Edit mode (each refuses unless the script is the copy it was made for):
1. `p1_shopwindow_tabs` (ShopWindow 17020 880152127 -> 17239 1319058608): the tabs stand straight and in line
   (no longer tilted every other way), the open one slides out 12 studs instead of 16, every name one size (27).
2. `p2_skin_packet_slice` (Skin 23460 668338792 -> 23797 845675608): the packet's middle row is 5 rows thin
   (Rect 170, 285, 640, 290), so the whole height scales evenly and only the middle stretches wide.

3. `p3_shopwindow_packet_pieces` (ShopWindow 17239 1319058608 -> 19536 733977539): p2 took the seam away but on
   the real tabs (this small) Roblox's 9-slice still drew a step at the right end, the end piece higher than the
   rest (it drew fine at 3x). The tabs now draw the picture as three pieces of the one image cut with
   ImageRectOffset (crimped left end, middle stretched wide, right end), each scaled to the tab's height by the
   same amount, so they line up exactly. p2 stays (Skin's packet is only used here, as the stand-in path).

**In Studio (30 Oct): all three applied, Studio = git.** Checked twice in Play: FEATURED open and MOWERS open,
every tab one unbroken packet (no seam, no step at the right end), names one size, FEATURED on one line.
