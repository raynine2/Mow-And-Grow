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

Not in Studio yet: `i_skilltreewindow` (client/SkillTreeWindow with its window turned off: the MASTERED marks on the
hotbar and the first-mastery celebration). Use `../mkcreate_buf.py` to send it in parts (it's 41 KB), then
`../2026-10-30-skill-trees/p_client.luau`. Until then K does nothing in Studio; buying skills works (checked).

Checked on screen in a run: the HUD plates and round buttons, the Upgrades window (Hold bought: MAX and MAXED; Iron
Fists bought to 2/5 with the run's coins; the pager to Garden Scissors: LOCKED), the shop, the pets window.
