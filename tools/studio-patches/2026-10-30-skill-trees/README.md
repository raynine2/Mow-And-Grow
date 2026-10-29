# Weapon skill trees into Studio (30 Oct)

Run in Edit mode, in this order (each refuses to change anything it doesn't recognise):

1. `p0_new_shared_skilltrees.luau` (ReplicatedStorage.MowALawn.SkillTrees, 13436 1485540072),
   `p0_new_server_skilltrees.luau` (ServerScriptService.MowALawn.SkillTrees, 13889 1193936855),
   `p0_new_client_skilltreewindow.luau` (MowALawnClient.SkillTreeWindow, 35412 1950190517).
2. `p_config`, `p_net`, `p_main`, `p_tools`, `p_run`: one line each (Main two), anchored on a short piece of a line
   both copies have; guarded by Studio's checksums of 29-30 Oct (Config 93131 925977069, Net 4430 710903267,
   Main 11787 1476303254, Tools 13779 1532520864, Run 44975 1537369329).
3. `p_input` (Studio = git: exact, 10426 528192117 -> 10519 1197181994).
4. `p_client` last (after the text-style patch's `p8_client`: it is anchored, not checksummed).

Simulated on git's own copies with `patchsim.luau` (each gives git's exact new text).
Studio test hook: `ServerStorage.SkillTreeDev:Invoke("mp", nil, 5000)`, `("max", nil, "Scissors")`, `("reset")`.
