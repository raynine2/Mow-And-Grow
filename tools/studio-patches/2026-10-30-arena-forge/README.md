# Boss arenas remade with ForgeGUI (30 Oct evening, owner: "revamp every arena remove unneccery stuff also use forge gui")

The owner's picks (asked in chat): everything the 30 Oct "Arena Grand" pass added goes (the block stands with the gnome
crowd, the boss statue with its ruins, the glitch cracks and floating pixels, the light towers and loose props), and
ForgeGUI makes everything new: per area a gateway, a wall section, a grandstand, a pillar with a light and the summon
altar (40 models, published on the owner's account; ids in `shared/ForgeModelIds` as `fa_<piece>_<area>`, jobs in
`assets/forgegui_models.json`).

- **New `server/ArenaForge`**: the wall section repeated round the rim at its own proportions (never stretched; the
  count follows from its shape), pillars at the gateway and six joints (four lit), the gateway over the entrance
  (invisible walls in its towers so the way in is the arch; a block of the arena's skirt under each tower where the
  ground drops), a grandstand either side outside the wall (moved round where camps, gates or paths stand; on a skirt
  block where the ground drops; no grass under them), the altar round the pad with its flat top 0.35 over the floor.
  All decoration, no collisions. Measured on the meshes in Studio: their front is -Z; the gateways' openings and the
  altars' tops (`FIT`).
- **`server/BossArena`**: uses ArenaForge when the area's gateway, wall and altar are loaded (`ArenaForge.ready`),
  else the voxel dressing (`ArenaDress` / `MeadowArena`) as before.
- **`server/ArenaGrand`**: `ArenaGrand.EXTRAS = false`: only the glitch barrier in the gate is built; true brings the
  stands, statue, towers and cracks back. Exports `isBlocked`, `clearBox`, `groundY` for the stands.
- Result: 85 to 120 parts an arena (was 2,000 to 4,400).

Not made yet: ForgeGUI ended 4 jobs `outcome_unknown` (frost pillar, ember stand, isles gate, isles wall). Those must not
be requested again without asking the owner. Until then the frost arena has no pillars, the ember arena no stands, and
the Starlight Isles arena (8) keeps the voxel wall and gate (without the removed extras).

## In Studio (30 Oct, all applied; Studio = git after each)

Backups first: `ServerStorage.MowALawnBackups.pre_arenaforge_30oct` (ArenaGrand, BossArena, ForgeModelIds).
1. `1_install_ArenaForge` (new module; also replaces its first version 12446 871893835)
2. `2_ArenaGrand` (replaces 30525 532994135, the Studio text rescued into git in `47070bb`)
3. `3_BossArena` (replaces 30605 1550285509, likewise)
4. `4_ForgeModelIds` (replaces 2616 1462963502)

Checked in a Studio run: all eight arenas built with no warnings (1-7 ForgeGUI, 8 voxel), looked at from above, inside
and outside the gate; a Dandelion King fight: the gate's glitch barrier closes inside the arch, kill clean.
