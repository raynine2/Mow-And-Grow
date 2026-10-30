# The grass-galaxy UI (30 Oct, owner: "remake the ui / revamp so its not an exact copy remake it to a grass galaxy theme mix dont make it look low qaulity use forge gui")

One switch: `Config.UI.theme = "galaxy"` (shared/Config). The ForgeGUI kit `assets/icons/gg_*.png` (a night sky with a
nebula inside a rim of grass and clovers: panel, card, button, plate, ribbon, round badge, section box, bar, close X,
grass tuft) is published to Roblox through ForgeGUI's connection for @RayanPoepHoof (ids in `src/shared/IconIds.luau`,
`assets/uploaded_icons.json`, `assets/forgegui_icons.json`). client/Skin swaps the garden kit's frames for the galaxy
ones (`Skin.THEMES.galaxy`), client/UI turns the wood palette into the night sky's (`WOOD`), headings into ribbons and
the close button into the candy X, and client/TextStyle turns dark ink light in the game's screen.

The Upgrades window is new (`client/UpgradesWindow`, owner's picture of Chop A Forest's upgrades as the layout, and:
the weapon skill trees go in here, a page a weapon): Hands and Gear on the left, the weapons' skills a page at a time
top right (the pager), the picked card big with BUY bottom right. client/SkillTreeWindow no longer opens its own
window (K and its notes open Upgrades on the best weapon's page; no SKILLS button).

## In Studio (30 Oct, all done, each script reported "done")

Run in Edit mode, in this order (each refuses a script it wasn't made for):
1. `a1_iconids` .. `a4_ui_close`: the first kit pieces, the theme switch (Config, anchored), the candy X (UI, anchored).
2. The skill trees (they were only in git): `../2026-10-30-skill-trees/p0_new_shared_skilltrees`,
   `p0_new_server_skilltrees`, then `s1_skilltrees_config_reguarded` (the same Config patch guarded on Studio's
   checksum after the mower lock and the theme, anchored on `Config.UPGRADE_SECTIONS = {` since the mower lock adds a
   second `Config.UPGRADE_SECTIONS = `), `p_stats`, `p_run` (Studio's Run: only its first two edits; Studio's Run has
   no ClassPerks.baseDamage hook for the third), `p_playerdata`, `p_net`, `p_main`, `p_tools`, `p_windows`, `p_input`.
3. `b1` .. `b5`: the section box and bar, the inset/bar mapping, light ink, the galaxy palette and ribbon headings,
   Client's require of UpgradesWindow.
4. `b6_install_upgradeswindow` (installs the first version), then `b7_upgradeswindow_fixes`, `b8_skin_soil`.

(Installed later on 30 Oct, byte-for-byte, with the Client require; K opens Upgrades on the skills page in a run, checked.) Was not in Studio at first: `i_skilltreewindow` (client/SkillTreeWindow with its window turned off: the MASTERED marks on the
hotbar and the first-mastery celebration). Use `../mkcreate_buf.py` to send it in parts (it's 41 KB), then
`../2026-10-30-skill-trees/p_client.luau`. Until then K does nothing in Studio; buying skills works (checked).

Checked on screen in a run: the HUD plates and round buttons, the Upgrades window (Hold bought: MAX and MAXED; Iron
Fists bought to 2/5 with the run's coins; the pager to Garden Scissors: LOCKED), the shop, the pets window.

## Round 2 (30 Oct, later): the other windows, and the boss waking up

Run in Edit mode, in this order. `c1`/`c2`, `c5`/`c7`, `c6`, `d2` are anchored (Studio's copies of PartyWindow,
ClassDeal, Windows and BossCine differ from git's: other sessions' work), the rest are guarded by checksum.
1. `c1_partywindow`, `c2_partywindow_sizes`: Create Party + Saved Runs in the galaxy kit (the owner's picture of Chop A
   Forest's, no event panel): a grass ribbon with each panel's name and a violet glow behind it, violet and night
   colours, SAVED RUNS a glass card (the area's picture with AREA n / N and the difficulty on it, your face, SOLO RUN,
   clumps cut and time played, LOAD GAME, "Next up: ...") or an empty card under the moon.
2. `c3_news_entry` (the updates list's other entries violet), `c4_skin_banner` (the hanging sign, CLASS IN STOCK and
   the first-run coach card, on the galaxy panel), `c5_classdeal_night` (the class stand is its night-sky edition under
   the galaxy theme: starfield, violet tabs, rocket timer; the guild's cork only in the garden theme),
   `c6_windows_index` (the Index's empty mutation and gnome cells violet), `c7_classdeal_seals` (the odds stay on the
   rarity-coloured wax seals).
3. The boss waking (owner: "make better fx with boss spawning to make it feel more scary etc use forge gui"):
   `d1_install_bossomen` (new client/BossOmen), `d2_bosscine_omen` (BossCine calls it: bossReady, the intro's roars;
   the old beam and card stay as the fallback), `d3_iconids_omen` (the pictures' ids), `d4_bossomen_kicker`.

Checked on screen in a lobby play test (the 3D view was black: the PC's screen was locked, so only the 2D could be
seen): the party window empty and with a run (Expert, area 5), News, the Index, the class stand; the boss wake-up's eye
over the bleeding screen, the BOSS AWAKE banner, the impact frame. **Not seen yet:** the circle and beam on the summon
pad (3D).
4. `e1_loading_night` (guarded): the loading screen at night under the galaxy theme (starry violet sky, nebula glows,
   the moon, night clouds, moonlit hills and trees, fireflies, the galaxy bar). Checked on screen (a preview built in
   a play test).
