# The windmill and everything else that moves in the camps (29 Oct 2026, ~22:05 to 22:35)

Owner, 22:03: "windmill bugged bro i told u to look at things and its still bugged ... dubbel check everything".

**The bug:** `client/CampLife` kept each part's group (its `G` attribute: Rotor, Head, armL ...) in a list filled with
`table.insert(group, if g then g else nil)`. Inserting nil adds nothing, so every later group name slid onto the wrong
part: 8 of the windmill's tower blocks turned with the sails while 8 sail parts stood still, and the same mix-up hit
the villagers (heads, arms, legs), the chickens' heads and the arch banners. Now each part's group is set by its index.

**Checked in a play test** with a test that doesn't trust CampLife: every part's move over a moment, grouped by its own
`G` attribute; each group has to move as one rigid piece. Before: every rig in the wheat camp split. After: all 7 camps,
53 rigs, none split (and the windmill's 26 tower parts stay still while its 17 rotor parts turn).

**Found while double checking:** a lamp post stood in the arch's gateway (wheat, blossom) or against its posts, and the
arch stood close to a stall or a bench. `server/CampDress` now puts the arch where it has the most room, moves a bench
in its way round the plaza (5 camps), and keeps the lamp posts and the standing villager out of the arch's way.

All applied in Studio (Edit mode, each guarded by the script's checksum before and after), in this order:

| Step | Script | Before | After |
|---|---|---|---|
| `p1_camplife.luau` | `StarterPlayer.StarterPlayerScripts.MowALawnClient.CampLife` (the group fix) | 20298 1059054880 | 20504 1082693149 |
| `p2_campdress.luau` | `ServerScriptService.MowALawn.CampDress` (arch room, lamps off the gateway) | 46639 415893255 | 47955 1234471113 |
| `p3_campdress.luau` | CampDress (the arch's spot by the most room) | 47955 1234471113 | 48860 915371797 |
| `p4_campdress.luau` | CampDress (exact gaps; a bench in the arch's way is moved) | 48860 915371797 | 51915 1212517591 |

Both scripts now equal git's `src/client/CampLife.luau` and `src/server/CampDress.luau`.
