# Boss kill + summon pad pillar (29 Oct, applied in Studio)

- `client/BossKill` is a new ModuleScript in `StarterPlayerScripts.MowALawnClient`. It was installed with its full
  text (checksum 20066 1558143226, as first committed), then tuned with `p1_bosskill_tune.luau` to
  **20773 1742596366** (= git).
- `client/Client`: one line after the BossCine require, `require(modules:WaitForChild("BossKill"))`. Studio's copy
  went 3894 1121306497 -> 4015 1171987577 (Studio's Client differs from git's by its own earlier edits).
- Play-tested on screen: the pillar (golden, streaks scrolling up, motes), the impact frame (FINISH!), the pop
  (flash, halo rays), all through `BossKill.test(pos, z)` / `BossKill.testPillar(pos, z)` in a Studio play test.
