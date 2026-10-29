# The area camps remade, 29 Oct (into Studio)

Owner: "now remake every zone hub except 1 to make it a bit bigger and ... make it feel more alive and not so
boring; if ur going to add or make stuff use blender". The models are Blender scripts (`tools/blender/camp`, built
with Blender's Python), turned into native parts in `src/server/CampProps.luau`; `server/CampDress` dresses each
area camp; `client/CampLife` animates it; `server/Outposts` makes the plaza 24 round and calls CampDress.

Studio, in Edit mode, one `execute_luau` call each (every text and script is checked by checksum, `#source .. " "
.. hash`, hash = (h*31+byte) % 2147483647):

1. `part01.luau` .. `part13.luau` (any order): the three new scripts in chunks, kept in
   `ServerStorage.ClaudePatchBuf`. A part answers "ok" or names a chunk that arrived garbled (send that part again).
2. `create.luau`: checks the chunks and creates `ServerScriptService.MowALawn.CampProps`, `.CampDress` and
   `StarterPlayer.StarterPlayerScripts.MowALawnClient.CampLife` (never overwrites a different script of that name),
   then removes the buffer.
3. `p_outposts.luau` (Outposts 21484 1601836981 -> 22170 1737268933), `p_config.luau` (Config 91277 128436136 +
   `CAMP_LINES`), `p_client.luau` (Client 3780 1361335942 + the `CampLife` line).

Then a play test: every camp prints `[CampDress] <area> camp: ...` (the spots it found for the house, landmark,
tents and animals, and their height against the plaza).
