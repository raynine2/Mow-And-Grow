# Uploaded models kept in the place (31 Oct)

Owner: "some buildings like the grass collector is different in my friends game" (the friend plays this place in
Studio). `1_Models.luau` installs git's `server/Models` (32902 1807735271): `fetch` uses `ServerStorage.ModelCache`
while an entry's AssetId matches, and `Models.cache()` fills it. Applied in Studio on 31 Oct (Studio = git), then
`require(game.ServerScriptService.MowALawn.Models).cache()` ran in edit mode: 51 models + 94 ForgeGUI models stored,
none failed. The place has to be saved for the cache to stay.
