# Handoff: where Mow And Grow is (22 Oct 2026)

For the next person (and their Claude) picking this up. Read `CLAUDE.md` first for the rules, then this.

## Where everything is

- **Repo:** `raynine2/Mow-And-Grow`. Working branch: **`claude/nice-rubin-9w0359`**. It holds all the work
  below, and it includes the teammate's Studio work: pets, eggs, guns, night, classes, lobby kit and product ids
  were merged in commit `a4d8452`.
- **Other branches:**
  - `studio-snapshot-2026-10-21` and `studio-backup-2026-10-21` are snapshots of the Studio scripts from 21 Oct.
  - They are already merged into the working branch. Keep them, don't delete them.
- **The Studio place:** "RayanPoepHoof's Place: 10182026_1" (placeId 86945160031996). It is synced by hand from
  the branch, not through Rojo's live sync (see "Studio vs. git" below).
- **Backups inside the place:** `ServerStorage.MowALawnBackups.<name>`. Every time scripts or meshes were
  replaced, the old copies went here first:
  - `pre_chopfeel_22oct`
  - `pre_stalk_clumps_22oct` (the old clump meshes)
  - `pre_intro_22oct` (the old fly-over intro)
- **Code layout** (also in `README.md`):
  - `src/shared/Config.luau`: all tuning, sounds, zones, tools, daily rewards.
  - `src/server`: the server side, with RemoteEvents in `Net.luau`.
  - `src/client`: everything you see and hear.
- **Blender models:**
  - Source: `tools/blender/voxel/` (`models.py`, `build_clumps.py`).
  - Exported: `assets/models/MowClumps.fbx` plus its atlas.
  - Sizes: `src/shared/ModelSizes.luau`.

## Done (latest first)

| Commit | What |
|---|---|
| `688dbbd` + Studio edits | **Area 1 starts at the village** (like Chop A Forest's camp in the forest).<br>• Six `VillageYard` discs (attribute `Yard`) in `World.Patches.Zone1` grow ~80 area-1 clumps round the village; `RunWorld.patches` keeps them clear of buildings, paths and trees.<br>• The yard trees standing there and the village fence were taken out. They're kept in `MowALawnBackups/pre_village_22oct`.<br>• A **CLASSES** stand in the village. Runs handle class buys and equips (new `server/Classes`, shared with the lobby).<br>• The discs, the tree/fence removal and the baked stand exist **only in the place** (they are edits to the saved `Workspace.World`), not in git. |
| `1dafbe6` + `ba4239f` | **Village baked into the place.** It shows in Edit mode: the tool shop, bag stand, garage, shredder, spawn, paths, arch and area 1's drop-off are real parts in `Workspace.World` (attribute `VillageBaked`).<br>• Done once with `RunWorld.bakeVillage()`. A copy of the world from before is in `MowALawnBackups`.<br>• The buildings carry a `MapUnit` tag. Move or delete one as a whole and the game follows. Changes *inside* one are replaced by code at run start.<br>• **Code changes to village scenery (dressing, paths) won't show any more**, because the saved parts are used. Don't re-bake without asking the owner. |
| `4f136d3` → `a9b27d7` | **Pacing and look** (from the Chop A Forest teardown):<br>• Mowed ground turns into bright stripes that stay (`server/Lawn.luau`), and a cleared area is striped all over.<br>• Area 1 has its own drop-off sell pad (the village shredder was ~350 studs away).<br>• **Bosses are back on** (`Config.BOSSES = true`).<br>• Economy retuned toward a 60–90 min free clear; see the note above `Config.ZONES`.<br>• Free gems every 6 hours (`Config.FREE_GEMS`) on top of the daily ladder.<br>• Night was checked: the crawlers only stun and never undo progress. |
| `fd592e6` | **UI overlap fixes.** The coach card, combo counter and "locked" notice stack instead of covering each other (a RenderStepped stacker at the end of `client/UI.luau`). The fuel bar moved above the tool name. The P/R/TAB key badges moved to the top-right of the side buttons. Cutscene name tags are removed after the party shot. **Not in Studio yet, see below.** |
| `4075a42` + `aa47bf2` + `ea61399` | **New opening cutscene** (`client/Intro.luau` directs; actors and props are in `IntroCast.luau`; letterbox, speech, cards and SKIP are in `IntroUi.luau`). It plays on the first run (the server stores `run.introSeen` via the `Seen` remote). About 25 s, five shots:<br>1. Low dolly through the thickest patch of area 1, then a crane up.<br>2. The party's avatars cloned at the fountain, with emotes and name tags.<br>3. **Mayor Thistlewick**, our own brick NPC, speaks in typed lines, with a sepia "Long ago..." flashback (area 1's grass hidden on the client) and a dolly zoom on the grass.<br>4. A supply crate slams down and the title card appears.<br>5. Dip to black, into first person.<br>The map has StreamingEnabled on, so it calls `RequestStreamAroundAsync` first. |
| `6f360f2` | **Stalk clumps.** The grass clumps have a 3×3 stalk you chop like a tree trunk. The new meshes come from `models.py stalk_clump`. Server side, `Field.luau` adds an invisible `StalkCollider` and a `Stalk` attribute. The FBX is imported and swapped into `ServerStorage.VoxelModels` in Studio. |
| `60e9566` | **Chopping like Chop A Forest:**<br>• bigger, closer arms with wide fast swings (`ViewModel.luau`)<br>• chunks and slash marks that fly at the camera (`HitFx.luau`, `FxPresets.json`)<br>• calmer camera: less bob, no lean (`CameraView.luau`)<br>• a "TIMBER!" word when a clump falls |
| `cec1ffe` | **Daily reward streak.** A 7-day ladder `{50,75,100,150,200,300,600}` gems (`Config.DAILY_STREAK`) with a calendar window and a claim moment. Logic in `server/Daily.luau`. |
| `3246f81`, `b854d22` | **First-run coach** (`client/Coach.luau`). The steps are punch, collect, fill bag, sell and upgrade, each with a glow and a dotted trail to the target. |
| `fd42c2e` | **Big moments** (`client/Moments.luau`: rare grass reveal, area-cleared card) and a **soundscape** (`client/Soundscape.luau`: footsteps by material, birds and wind). |
| `a4d8452` | **Merge** of the teammate's Studio work with the generated world. |
| `f22e50a`, `72a609b` | **Chopping feel overhaul** and a smooth clump fall: it hinges on the near edge, and a ghost copy falls so you never see the underside. |

All of it passes `tools/compile-check.luau` and `rojo build`. Everything up to `ea61399` is in the Studio place
and was playtested there with no script errors.

## Not done yet / open items

**Do first:**
1. Everything up to `ba4239f` is in the Studio place, and the SKIP button was tested. Each script was checked
   against git first, and the old copies are in `MowALawnBackups/pre_pacing_22oct`.
2. **Playtest the new pacing for real**: time a full free run (target 60–90 min) and retune `Config.ZONES`.
3. **Watch a full clump fall with the new stalk clumps.** Punching, chunks and the cut were checked; the
   TIMBER fall itself wasn't seen on screen.
4. **Title name:** the cutscene title uses `Config.GAME_NAME`, which is still **"Mow A Lawn"**. The owner may
   want "Mow And Grow". Ask before changing it.

**Features from the owner's list, not started:**
- Golden grass rain: a timed event every ~30 minutes.
- Rebirth.
- Pets that help mow. Pets exist and follow you, but they don't mow yet.
- Phone check: test the HUD and cutscene on a small screen and on touch.
- Game passes: Auto-Collect and 2x Speed.
  - The owner's rules apply: no cash packs, and anything random must show its odds and be hidden where
    `PolicyService` restricts paid random items.
  - Never spend Robux or publish; the owner does that.

**Things to know:**
- **The click sound** (`Config.SOUNDS.click`) is a community upload, not a licensed Roblox / ProSoundEffects
  sound. Swap it before publishing.
- **The Halloween event** board counts down to 24 Oct 16:00 UTC (`Config.EVENT`).
- **Saved maps (`MapStore`):** if the place has `Workspace.Maps`, builder changes to scenery won't show. Never
  re-bake without asking.

## Studio vs. git: please read

Scripts were synced into Studio by hand: each file was fetched from GitHub at a commit and written in with
`ScriptEditorService:UpdateSourceAsync`, after a backup.

Earlier, some teammate work existed only in Studio and was almost overwritten. It was rescued and merged. So,
before syncing or using Rojo:
- make sure the branch has everyone's latest work, and save a backup of the place (File → Save to File As);
- if you edit scripts directly in Studio, commit them to the branch soon, or tell the other person.
