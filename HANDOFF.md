# Handoff: where Mow And Grow is (22 Oct 2026, evening)

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
| _this commit_ | **Loading screen clean-up** (the owner: the text and glow looked generic): a drawn **MOW A LAWN logo** (ForgeGUI, `logo`, grass growing out of the letters, a mower under LAWN; the owner chose to keep the name "Mow A Lawn") pops in with a drop shadow on a soft warm glow (`glow_soft`, made in code) with twinkling `sparkle`s; the sunburst, daisies and pollen are gone; the line under the bar and your name sit on dark see-through pills. Falls back to the old text title if `logo` is missing. **Not tested in Studio yet.** |
| `dac7bf9` | **New loading screen** (`shared/LoadingScreen`): the meadow painting (`scene_lawn`) behind, the game's name (`Config.GAME_NAME`) big on a turning sunburst with daisies, and the progress bar is a strip of tall grass a push mower mows as the game loads (clippings fly, the mowed part striped, the % rides above the mower); a line under it changes every 2.6 s (tips and silly jobs), your face and name bottom-left, pollen drifting up. `LoadingScreen.setProgress(gui, p, cap)`: the boot script moves it on at each real step (world built, server ready, character in) and it creeps toward the cap in between; `fadeOut` fills it to 100% first. Same API otherwise. **Not tested in Studio yet.** |
| `980499c` | **Themed screens (the owner's picks): Upgrades = garden shed, Pets = critter burrow, Classes = Gardeners' Guild, Saved Runs = garden journal; plus phone size.**<br>• **New ForgeGUI art** (22, uploaded through @RayanPoepHoof, ids in `IconIds`): frames `ui_tag ui_soil ui_cork ui_parch ui_chalk ui_page` (measured into `Skin.FRAMES`), upgrade pictures `up_swing up_grasp up_power up_speed up_sell`, `blade hook burrow leaf_tile nest guild_crest wax_seal polaroid tape ring scene_lawn`. Two jobs got stuck (`up_hold`, `pushpin`); not regenerated: Hold keeps the hands picture and the pin is drawn.<br>• **Upgrades:** a pegboard wall; each upgrade is a wooden tool tag hanging on twine (swaying), level shown as grass blades (`Skin.blades`), green/grey/gold price.<br>• **Pets:** soil boxes with grass on top, burrows as the equipped slots (critter peeks out, rarity glow behind), critters on leaves tinted by rarity, eggs sit in straw nests.<br>• **Classes (`ClassDeal`):** cork boards, crest as the "A" in the title, FRESH STOCK IN chalkboard, the big card a pinned parchment with a rarity band and wax seal, odds on wax seals, kraft-envelope card backs, fireflies. Layout and animations untouched; the 3D room behind stays the space one (the owner likes the mix, 22 Oct: don't turn it into a guild hall).<br>• **Saved Runs (`PartyWindow`):** a ring-bound ruled journal page, the run as a taped instant photo of the meadow with handwritten notes, a NORMAL stamp, "Next up". The map card uses the meadow painting.<br>• **Phones:** touch-only devices draw the UI at full size (`Config.UI_SIZE_TOUCH = 1`, `UI.size`), since 0.82 made text too small there.<br>• Each piece falls back to the old look if its picture id is missing. **Not tested in Studio yet** (Studio wasn't linked). |
| `980c7a9` → `feaee41` | **UI remake, the rest of the windows + an overlap sweep** (the owner: "do every single UI that hasn't been remade, and fix overlapping bugs").<br>• **Smaller UI** (`980c7a9`): `Config.UI_SIZE = 0.82` scales the whole layout down; the class screen undoes it so it still fills the screen.<br>• **Windows remade in the kit** (`3e26715`): Gem Upgrades (perk + gem-pack cards on the wood-rimmed card with stripes, rays, LV ribbons), Upgrades/Bags/Garage cards (`UI.blueCard` on the wood-rimmed card), Rewards calendar + every popup (`UI.popupWindow` on the plank sign), Stats (stat cards, numbers count up), News (banner + tiles with NEW ribbons), Create Party board. Card titles pop in; all buttons use the tinted button art.<br>• **Overlaps fixed** (`705a877`, `feaee41`): HUD pieces an open window would cover (gem counter beside Pets, hotbar under Upgrades, run card) hide while it's open and come back after; code shows/hides them through `show()` in `Hud.luau` so they come back in the right state. The quest card sits under Roblox's top-left buttons and the run card steps left of Roblox's player list (both follow the UI scale). Window titles keep a gap before the first tab; popup titles clear the red X; no daisy hides under tabs or the gem box; three 250 px cards fit per row (Bags, Garage, Mowers); upgrade icons clear the level pips (`CARD` is 226 tall); the Shop's drive-by mower rides on the grass, not over the cards.<br>• **Small extras:** an empty pet card shows a glowing egg; the tool popup has the tool bobbing on a sunburst; the **Turbo Tractor** picture didn't load on Roblox, so it was re-uploaded through ForgeGUI (new id `85725044549764`).<br>• Checked in Studio tests, lobby and run (`Workspace` attribute `ForceMode = "Run"`, removed after). Screenshots shown to the owner. |
| `29100e4` | **UI remake: a garden look of our own + window 3 of 8 (Pets / Eggs / Index), and the paid-random policy check.**<br>• **Garden identity** (the owner asked for the Shop to be more unique): the Shop categories are tinted **seed packets** (`ui_packet`) instead of hanging signs, every banner/egg card has **mowed-lawn stripes** (`Skin.stripes`), every `UI.window` board grows a **grass strip** along its bottom (`ui_grass`) and swaying **daisies** on its corners (`daisy`, replacing the leaves), and in the Shop a little **mower drives along the grass** every 6–12 s spitting clippings.<br>• **New art** (ForgeGUI, uploaded through the @RayanPoepHoof connection): `ui_packet ui_grass daisy ui_rays egg_garden`. Two ForgeGUI GUI jobs with reference images got stuck (`f4285425…`, `ca926f93…`); they were redone as style icons, not regenerated.<br>• **Skin helpers:** `Skin.stripes`, `Skin.rays` (turning sunburst, tinted), `Skin.pill` (title pill on a box edge), `Skin.tile` (clickable tinted tile, ring + sparkles when picked); `Skin.sparkles` now waits a frame so it works on objects parented right after.<br>• **Pets window:** egg cards on the wood-rimmed card with the egg bobbing on rays and critter odds on rarity tiles; hotbar-tile equip slots that light up in the rarity colour; critter tiles (Legendary+ sparkle); the big card is the wood-rimmed collector card with rays behind the critter; the boxes no longer stick out past the board. Hatching uses the egg picture and turning rays. **Index:** rarity ribbons, tiles, egg pictures, boxes fit the board.<br>• **Policy (owner's rule, was missing):** new `shared/Policy` reads `PolicyService.ArePaidRandomItemsRestricted` (restricted if it can't be read). The **Golden Egg** card and the **class Restock / Lucky Restock** buttons only show where paid random items are allowed, and `Monetization` refuses to prompt a `paidRandom` product otherwise. |
| `e7ad0c8` | **UI remake, window 2 of 8: the Shop, plus the shared window kit.**<br>• **New art** (ForgeGUI, same style; uploaded through the @RayanPoepHoof connection, ids in `IconIds`/`assets/forgegui_icons.json`): kit frames `ui_button` (white, tinted per button), `ui_close`, `ui_inset`, `ui_pcard`, `ui_ribbon` (tinted), `ui_sign`; shop icons `star ticket gift crown x2coins x2clip x2gems hatchluck superhatch gempile gempouch gemchest gemmountain` and mowers `mower_rusty/tractor/zeroturn/mulcher/trial/rocket`.<br>• **Shared kit in `UI.luau`** (every window gets it): `UI.button`/tabs use the tinted button art (`setButton`/`rainbow` know about it), `UI.window`'s board is the plank-sign art (grown so the old 20 px panel layout is unchanged), the red X is the new close art, `UI.section`/`UI.heading` are the sunken wood box, `UI.ribbon` is the swallow-tail ribbon, the window gem box is the HUD plate. All of it falls back to the drawn look if a picture id is missing. Skin loads lazily from UI (it requires UI). Removed dead duplicate copies of `clicky/rainbow/robuxButton/ribbon/register` (the later copies were the live ones).<br>• **Shop** (`client/ShopWindow`): plank signs on ropes (open one glows orange, icon bobs), gem plate with a "+", wood-rimmed banner cards with the item's colour, picture bobbing on a glow, shine sweeps, sparkles on EXCLUSIVE/NEW/BEST/POPULAR/SUPER, ribbon tags, chunky price buttons (grey + "denied" sound if you can't afford), blue gift button (still a "coming soon" toast), banners pop in on open and on every tab switch.<br>• `GemUpgrades` only restyles the gem box when it is the drawn one.<br>• Checked in a Studio test (Featured, Passes, Mowers; Pets window still loads with the new kit). |
| `a0c4828` → `84c2751` + fixes | **UI remake, window 1 of 8: the HUD** (the owner's brief: remake the whole UI with ForgeGUI, window by window, in the style of the new icons; refs in `docs/ui-references`).<br>• **Art:** made with ForgeGUI using the saved style **"Mow And Grow UI — chunky cartoon"** (style id `3761ed73-ff85-4a52-b197-061fa8e516b4`, v2 has our coin/backpack/basket/upgrade icons as references). New PNGs in `assets/icons`: frames `ui_badge`, `ui_card`, `ui_plate`, `ui_bar`, `ui_banner`, `ui_tile`, `ui_tile_gold`; icons `clover hands lasermower moon newspaper pin pushmower quest scissors scythe sickle stopwatch sun whacker`.<br>• **Uploaded** (all 28, incl. the first 7 icons) through ForgeGUI's Roblox connection for @RayanPoepHoof; ids in `src/shared/IconIds.luau`, map in `assets/forgegui_icons.json`, and `assets/uploaded_icons.json` updated so `upload_models.ps1 --icons` won't re-upload them.<br>• **`client/Skin`** (new): 9-slice frames from that art (falls back to plain wood if an id is missing) + motion kit: shine sweeps, sparkles/bursts, hover tilt, idle bob, pulsing red dot, rising "+N". Works with UI's juice engine (own scales are named `Pop`).<br>• **HUD** (`client/Hud`): coin/gem plates (gems have a "+" to the shop), count-up + "+N" + icon pop on gains, bag plate (icon tints red when full), quest + area cards with candy bars, log-slice side buttons with key tags and `Hud.setDot(window, on)`, gold hotbar tile with sparkles, fuel/day bars on the wood bar.<br>• **Coach card:** hanging wooden sign with a picture per step and STEP n/5; keeps Studio's dock-under-the-quest.<br>• Checked in a Studio run test (screenshots shown to the owner). |
| `96bf05a`, merged in `cf5df89` | **Studio snapshot 22 Oct** (branch `studio-snapshot-2026-10-22`): 5 scripts had work in Studio that wasn't in git: UI (juice engine, windows slide up, click + hover on every button, Robux glyph, `UI.anyOpen`), Coach (docks under the quest), ClassDeal (reworked deal), ClassRoom (space edition; needs `ReplicatedStorage.VFXLib`, which lives in Studio outside the Rojo tree), Config (class stats rebalanced). Each copied byte-for-byte and merged with the owner's OK. |
| `7ae2ca7` + Studio edits | **The camp is in area 1** (like Chop A Forest's camp in its first wood).<br>• `RunWorld.moveVillageToCamp(Vector3.new(73, 0, 351), 34)` was run once in Studio, then the layout was hand-tuned so nothing overlaps (yard radius 42, `CampRadius` = 42). The tool shop, garage, bag stand, shredder, CLASSES stand and spawn now stand on a dirt yard in the middle of Sunny Meadow's grass.<br>• `World` attributes: `CampCenter`, `CampRadius`, `CampFacing`.<br>• What this changes: no grass grows in the camp, the boss arena keeps 90 studs away, falling players come back to the camp, and there's no separate area 1 drop-off.<br>• The village-yard grass from `688dbbd` was taken out again, and the trees and fence went back (backups in `MowALawnBackups/pre_village_22oct` and `pre_camp_22oct`).<br>• Runs handle class buys (`server/Classes`).<br>• The cutscene films the camp and got whip cuts, the party dropping in, slow-mo on the crate, and trailer music. |
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

**UI remake, still to do (window by window, show the owner each one):**
- Every window is now in the kit. Not given its own pass yet: the Classes card deal (kept its space theme, but has
  the new buttons and X), the Saved Runs list in the party board, and small screens (combo counter, sell FX, intro
  SKIP, boss HUD). The critter previews in the Eggs/Pets cards don't show in Studio screenshots (the parts are there;
  probably the capture tool), so check them by eye in a test. Shop leftovers: the Bottomless Sack picture (ForgeGUI job stuck, it shows the
  backpack) and real gifting (needs server work for the gifted player). Use `client/Skin` and generate new art with the saved ForgeGUI
  style (needs the host `azyjlkhpdgafuobyxoax.supabase.co` allowed in claude.ai Settings → Capabilities, which the
  owner did on 22 Oct). Our art must stay our own: no Chop A Forest art, names or characters.
- Small HUD leftovers: the Stats clipboard icon (ForgeGUI job stuck, the old one is used), new lock/leaf icons, the
  DEV button (Studio/admins only) touches the gem counter, and News should light `Hud.setDot("News", true)`.

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

**State on 22 Oct, late evening: the themed-screens commit (after `0b9b025`) is NOT in Studio yet.** It changes
`Skin`, `UI`, `Windows`, `PetsWindow`, `ClassDeal`, `PartyWindow`, `Config` and `IconIds`; the loading-screen
commit after it changes `shared/LoadingScreen`, `first/Loading.client` and `client/Loading`. Sync it (checksum Studio
against `0b9b025` first, back up) before testing.

**State on 22 Oct, evening (after `feaee41`): synced.** Every script changed by the UI remake was checked against
git before each sync and checked byte-for-byte after it, so Studio matches the branch. (The earlier note that the
garden + Pets sync was unfinished is out of date: it was finished and checked.) Backups from before each sync are in
`ServerStorage.MowALawnBackups`: `pre_pets_remake_22oct`, `pre_allwindows_22oct`, `pre_overlap_fix_22oct`,
`pre_runwindows_fix_22oct`. The owner still has to press Ctrl+S in Studio to save the place.

**Before that, after the Shop remake:** every script in the place matches the branch (all 102 others were checked
byte-for-byte earlier; UI, Skin, ShopWindow, GemUpgrades and IconIds were checked again after this sync). The copies
from before the syncs are in `ServerStorage.MowALawnBackups.pre_hud_remake_22oct` and `.pre_shop_remake_22oct`. If you edit in Studio, commit it soon: on 22 Oct five
scripts had Studio-only work that had to be rescued first.

Scripts were synced into Studio by hand: each file was fetched from GitHub at a commit and written in with
`ScriptEditorService:UpdateSourceAsync`, after a backup.

Earlier, some teammate work existed only in Studio and was almost overwritten. It was rescued and merged. So,
before syncing or using Rojo:
- make sure the branch has everyone's latest work, and save a backup of the place (File → Save to File As);
- if you edit scripts directly in Studio, commit them to the branch soon, or tell the other person.
