# Mega Scythe remade with ForgeGUI (31 Oct)

Owner: "revamp the mega sytche model witth forgegui".

1. `1_Models.luau`: installs git's `server/Models` (29793 805048841) over Studio's (24821 1150832697 or the
   in-between versions of this change). FORGE_TOOLS puts the ForgeGUI mesh in the `tool_scythe` template; loadAll
   clears the `ReplicatedStorage.MowALawnModels` folder first (the place was saved with 7 stale copies of every
   template, so first person picked an old scythe).
2. `2_ForgeModelIds.luau`: adds `megascythe = 77652345413074` (4519 1255717925).

Both were applied in Studio on 31 Oct (Studio = git). Run in Edit mode; each checks the checksum before writing.
