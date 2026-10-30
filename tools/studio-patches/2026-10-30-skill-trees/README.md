# Weapon skill trees into Studio (30 Oct, second version)

The second version: pips are bought with a run's coins and reset every run, MASTERED stays for good, and the trees
replace the Upgrades window's "Tool" section (its Power upgrade stays for ride-on mowers as "Mower Blades").

Save a backup of the place first (File > Save to File As). Run in Edit mode, in this order. Each script refuses to
change anything it doesn't recognise and says why ("NOT CHANGED: ..." / "NOT INSTALLED: ..."); a refused script
changes nothing, so it can be fixed and run again.

1. The new modules (exactly git's text, checked by checksum). Each installs the module if it isn't there, replaces the
   first version of 30 Oct if that is there (its checksum in brackets), and refuses anything else:
   - `p0_new_shared_skilltrees.luau`: ReplicatedStorage.MowALawn.SkillTrees, 13578 1048010790 (first version 13436 1485540072)
   - `p0_new_server_skilltrees.luau`: ServerScriptService.MowALawn.SkillTrees, 14573 299627822 (13889 1193936855)
   - `p0_new_client_skilltreewindow.luau`: MowALawnClient.SkillTreeWindow, 39964 1301547796 (35412 1950190517)
2. The edits to existing scripts, each guarded by Studio's checksum of 30 Oct and anchored on a short piece of a line
   that Studio's and git's copies both have (found exactly once, or nothing changes):
   - `p_config`: Config 93131 925977069. Adds the `Config.SKILL_TREES` line; takes `"Tool", ` out of
     `Config.UPGRADE_SECTIONS`; turns the one `section = "Tool"` line (it must be the Power upgrade, id "power") into
     the Mower section's "Mower Blades" (same id and numbers). The Tool section is found by its own lines, so if
     Studio's Config has more or other Tool upgrades it refuses with a message.
   - `p_stats`: Stats 3739 382049001. The tools' `s.power` loses the Power upgrade; a new `s.mowerPower` keeps it.
   - `p_run`: Run 44975 1537369329. Harvest in onCut; ride-on mowers cut with `stats.mowerPower or stats.power`;
     the class gimmicks' best-tool hit gets the tool's skills.
   - `p_playerdata`: PlayerData 11246 738900900. `skills = {}` in a new run.
   - `p_net`: Net 4430 710903267. The "Skill" remote.
   - `p_main`: Main 11787 1476303254. Starts the trees; the snapshot's `skills`.
   - `p_tools`: Tools 13779 1532520864. `Tools.equipped` returns the tool with its skills.
   - `p_windows`: Windows 40700 613362573. A line under the upgrades: "Weapon upgrades: SKILLS (K)".
   - `p_input`: Input 10426 528192117 (Studio = git): exact, -> 10519 1197181994.
3. `p_client` last (after the text-style patch's `p8_client`: it is anchored, not checksummed).

Not changed: Hud (the SKILLS badge and the hotbar's "★ MASTERED" tag are added from client/SkillTreeWindow),
ClassPerks (reads the Mower upgrades by id), Offline / WelcomeBack (a saved run's `upgrades.power` is Mower Blades
now; a saved run without `run.skills` gets one from server/SkillTrees).

The modules tolerate a half-done copy: without the Config line the trees are off with a warning; without the Net line
buying is off with a warning; without the Stats patch mowers use `stats.power` (Run's `or`); without the PlayerData
patch server/SkillTrees makes `run.skills` itself.

Simulated on git's own copies with `patchsim.luau` (each gives git's exact new text); the installers were run against
a fake folder that is empty, holds the first version, holds someone's own changes (refused), and holds this version.

Studio test hooks: `ServerStorage.DevHook:Invoke("coins", nil, 1e7)`, `ServerStorage.SkillTreeDev:Invoke("max", nil)`
(all but the last pip of the best weapon; or `("max", nil, "Sickle")`), `("master", nil, "Sickle")` (mastered for
good, no celebration), `("reset")` (this run's pips and every mastery).
