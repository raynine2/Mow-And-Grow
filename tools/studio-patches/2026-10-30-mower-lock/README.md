# Mowers locked for the release (30 Oct)

Owner: "for game release i want to close of the mower system including gas etc and release it in a later update ...
a lock on it like holografic with high fx qaulity". One switch: `Config.MOWERS_LOCKED` (set false for the mower update).

Run in Edit mode, in order (each refuses if the script isn't the copy it was made for, or already has the lock):
1. `p1_config` (Studio 93131 925977069): the switch + its effects, added before Config's last line.
2. `p2_mowers` (16662 974742268), `p3_run` (44975 1537369329), `p4_gemshop` (1405 1150100285),
   `p5_monetization` (9006 601597384): the server refuses spawning, gas, coin/gem buys and Robux mower prompts.
3. `p6_shopwindow` (= git, exact): the store shows the mowers locked.
4. `p7_new_mowerlock` (new ModuleScript 19072 1052337618), then `p8_client` (one require line, anchored).
   (`all_patches_but_p7.luau` = p1-p6 + p8 in one go.)
5. After the first play test (each refuses unless MowerLock is the copy before it):
   - `p9_mowerlock_garage_out` (19072 1052337618 -> 19989 1536906607): the garage's lock stood half inside its door;
     it now stands 4.2 studs out in front (the side of the prompt with open air), its ring 3 wide.
   - `p10_mowerlock_sign_lower` (-> 20091 1943267726): the garage's COMING SOON covered the GARAGE board; the lock
     and its sign sit lower (the sign just clear of the shackle).
   - `p11_mowerlock_lobby_ring` (-> 20362 22597776): the lobby's ring hung through the middle of the mower (the
     ground under the prompt was the mower's roof); it now lies on the turntable's top.
   - `p12_mowerlock_lobby_ring_up` (-> 20440 10354439 = git): 0.2 studs higher, over the turntable's studs.

**In Studio (30 Oct): all of them, done.** Checked twice on screen: 6 locks in a run (the garage, the camp's pump
and the 4 area camps' pumps), every mower/gas prompt off, the store's Mowers tab "SOON", no rocket or trial mower
in Featured/Tools, no Mower section in UPGRADES, quest 7 "Beat the Backyard boss", walking up turns a lock red with
the note; in the lobby (ForceMode off for the test, then back to "Run") the garage's turntable has its lock.
Every patch was simulated on git's copies with `../patchsim.luau` (each gives git's exact text).
