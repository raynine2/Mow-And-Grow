# Mega Scythe remade with ForgeGUI (31 Oct)

Owner: "revamp the mega sytche model witth forgegui", then "old model stilkl in hands", "bugged" (a lavender slab in
first person) and "when i hit there are random white things above me and in my screen pls fix and make it better".

All applied in Studio on 31 Oct and checked in a play test (shop board, first person at rest and swinging, held in
third person). Run in Edit mode; each installer checks the checksum before writing.

1. `1_Models.luau`: git's `server/Models` (30078 946404422). FORGE_TOOLS puts the ForgeGUI mesh
   (`megascythe` 77652345413074) in the `tool_scythe` template, in the part model's own frame; lights, sparkles and
   the swing-trail spots ("TrailA", "TrailB") are attachments in the mesh. `loadAll` clears
   `ReplicatedStorage.MowALawnModels` first (the place was saved with 7 stale copies of every template, so first
   person picked an old scythe).
2. `2_ForgeModelIds.luau`: adds `megascythe` (4519 1255717925).
3. `server/Tools` (Studio's newer copy, not in git: it needs Studio's Config): the same few lines as git's
   `dressWithModel` change (the ReapTrail moves onto TrailA/TrailB of the held model). Studio = 14425 2110191054.
4. `client/ViewModel` (Studio-only newer copy, not in git; now 66878 1162799953), two edits:
   - `TRAIL.MegaScythe.atModel` = `Vector3.new(0, 2.65, -2.35)` (the middle of the crystal blade, template
     (0, 4.3, -3.8) at TOOL 0.62; was (0, 1.3, -3.35) on the old blade);
   - `realTools` also hides the real tool's own `ReapTrail` in first person (Transparency 1 on this client, put back
     in third person): it has no LocalTransparencyModifier, so it swept round your head ("white things above me").
