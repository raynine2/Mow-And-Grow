# Bosses that move like living things (30 Oct, owner: "the bosses are very stiff and dont do alot they are just a statue fix it")

The eight bosses are one-piece ForgeGUI models (body and ground disc in one mesh, `rig.solid`) that belong to another
account, so Studio won't let us cut them into parts (EditableMesh, segment_mesh and CSG all refuse). The owner chose
to keep the models and move the whole body:

- **New `client/BossLife`**: every frame for a `rig.solid` boss it adds breathing, a slow sway, a rocking walk with a
  thud and dust on each step (the bog slime hops instead), turning to watch the nearest fighter, a fidget every few
  seconds between moves (growl, look round, stomp, shake, hop; each boss its own mix in `BossLife.FEEL`), a shudder
  when hit and a quicker, trembling breath in its rage. Every lean rocks the model on its disc's rim
  (`BossLife.rim`) so the disc never sinks or floats, and the moves' small crouch dips are dropped (`BossLife.dip`).
- **`client/BossView`**: calls BossLife in its per-frame pose, and the moves lean a one-piece boss much further
  (`BossLife.SOFT` 0.6, was 0.35; squash 0.7, was 0.5).
- **`server/Boss`**: between moves the boss prowls (`prowl`): it gets its breath back, then walks towards one of the
  fighters and stops short of them. Not while it's open, underground or while a mover still runs.
- **`shared/Config`**: `Config.BOSS_PROWL` (speed 7 studs/s for a 40-stud boss, keep 9, pause 0.35).

## In Studio (30 Oct, all applied, each reported "done")

Run in Edit mode, in this order (backups first: `ServerStorage.MowALawnBackups.pre_bosslife_30oct`):
1. `4_Config` (anchored on `Config.FILM_SOUNDS = {`), `3_Boss` (anchored), `1_install_BossLife`, `2_BossView` (Studio's
   BossView has the 29 Oct solid/skin work git lacks; this patch replaces its 29 Oct `soft` lines).
2. `5_BossLife_dip` and `6_BossView_dip`: the crouch-dip fix found in the first test (the disc sank up to 1.4 studs).

Checked in a Studio run (BossGod on, DevHook `clearZone`, `boss fight 5`, `boss rage`, `boss kill`): the Dandelion
King walked 50 studs in 10 s rocking on its rim (lowest point of the disc -0.15..+3.8 studs off the floor), the bog
hopped 36 studs in 8 s with squash and stretch, rage and death ran with no errors, and the life attachment goes
with the model. After this, Studio's BossLife is git's exact text (19003 62316987).
