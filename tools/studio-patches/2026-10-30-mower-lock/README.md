# Mowers locked for the release (30 Oct)

Owner: "for game release i want to close of the mower system including gas etc and release it in a later update ...
a lock on it like holografic with high fx qaulity". One switch: `Config.MOWERS_LOCKED` (set false for the mower update).

Run in Edit mode, in order (each refuses if the script isn't the copy it was made for, or already has the lock):
1. `p1_config` (Studio 93131 925977069): the switch + its effects, added before Config's last line.
2. `p2_mowers` (16662 974742268), `p3_run` (44975 1537369329), `p4_gemshop` (1405 1150100285),
   `p5_monetization` (9006 601597384): the server refuses spawning, gas, coin/gem buys and Robux mower prompts.
3. `p6_shopwindow` (= git, exact): the store shows the mowers locked.
4. `p7_new_mowerlock` (new ModuleScript 19021 1038508881), then `p8_client` (one require line, anchored).
Every patch was simulated on git's copies with `../patchsim.luau` (each gives git's exact text).
