# The area camps bare again (29 Oct 2026, ~22:40)

Owner, 22:37: "remove houses and the dumb shit u added", then picked everything: the arch and lamp posts, the
landmarks and animals, the gnome villagers. `server/Outposts` no longer calls `server/CampDress` (the switch
`DRESS_CAMPS` at its top brings it all back) and the camp's radius (`HubR<z>`: no grass inside, third person) is the
plaza's again (24). A camp is now the paved plaza, the SHOP and UPGRADES stalls, the gas pump and the two benches.
`CampDress`, `CampProps` and `client/CampLife` stay in the code, unused.

| Step | Script | Before | After |
|---|---|---|---|
| `p1_outposts.luau` | `ServerScriptService.MowALawn.Outposts` | 26701 412766151 | 26961 421549389 |

Checked in a play test: every camp holds only the stalls, the pump, the benches and the plaza; nothing is tagged to
move; `HubR2..8` = 24.
