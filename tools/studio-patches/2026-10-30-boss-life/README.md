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

## Then: arms that move (30 Oct, owner: "ik heb het ook over de armen bv die bewegen niet")

The old models can't be cut (another account), so each boss was remade as a near-identical ForgeGUI copy on the
owner's account and cut into pieces with Studio's segment_mesh (how: `tools/bosses/joint_tool.luau`). A piece's
`Limb` attribute says what it is (head, armL, armR, body, base) and a `Joint` attachment where it turns.

- **`client/BossLife`**: a jointed boss swings its arms as it walks, raises its fists over its head when it rears
  back for a hit and slams them down, throws them wide to roar, flails them when it shakes, turns its head to watch
  you (the body only a little), nods as it steps, jolts when hit, droops when it dies; its disc stays flat
  (`BossLife.setup`, `turn`, `flatCf`, `attPoint`). The eyes and other effect points follow the head.
- **`client/BossView`**: builds the `Limb` pieces, turns them about their joints, carries the disc flat and leans
  the body about its hips.
- What each boss got: Jungle Titan, Sakura, Harvest Reaper and the pumpkin reaper (hollow): head and both arms
  (the reaper's scythe hand on its own). Bog: both sets of tentacles. Dandelion King: the staff swings from his fist
  (his head came out with the leaf skirt, so it stays with the body). Bramble and the Frost Thornback (bunker): the
  cut found no clean arms, so only the disc is separate (the body leans over a flat disc).
- In Studio: `7_update_BossLife_limbs` (whole module, replaces the two earlier versions), `8_BossView_limbs`, and
  the eight new models in `ReplicatedStorage.BossModels` (the old ones in `ServerStorage.MowALawnBackups.
  pre_jointed_30oct`). Checked in Studio fights: the Jungle Titan raises both fists and slams them down, the
  scarecrow swings its pitchfork arm, the reaper lifts its scythe; no errors.

## Then: glitch fixes (30 Oct, owner, with a picture of the Dandelion King's staff flying off his fist: "some things are very buggy and glitched like this please fix all")

- **`9_BossLife_reach`** (whole module; Studio = git 29996 2032289703): each boss has a `reach` in `BossLife.FEEL`
  (how far its arms may swing: dandelion 0 so the staff never leaves his fist, sakura 0.75, jungle 1, the rest
  0.5..0.6) and tighter limits on the arm raise, the roar spread and the head turn and nod.
- **Three bosses back on their old models.** Side by side, the ForgeGUI copies of the Sakura (purple, faceted, no
  eyes or lantern), the Frost Thornback (washed out, no face, sand bunker gone, its flag floating as a loose piece)
  and the Bramble (darker, less detail) looked clearly worse than the originals, and the bramble and frost turtle got
  no arms from the cut anyway. Their originals are back in `ReplicatedStorage.BossModels` (one piece, so the
  whole-body life from the first section); the copies are kept in `ServerStorage.MowALawnBackups.
  jointed_replaced_30oct`. Jungle Titan, Hollow, Bog, Harvest and Dandelion keep the jointed copies (close to the
  originals).
- Checked in Studio fights, one per boss: nothing came off, floated or sank; no errors from the game's scripts.
